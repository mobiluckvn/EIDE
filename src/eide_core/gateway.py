"""Gateway LLM — chọn mô hình theo vai trò, gọi, kiểm đầu ra, ghi ledger. WI-013.

Spec: PRS-16 §1 (sáu quy tắc prompt), §2 (bảng vai trò × mô hình), §4 (schema mẫu số chung);
SDD-04 §4.3 `Router.pick(role, need)` và §6 `models.yaml`; CXD-10 (lớp ngữ cảnh);
API-15 §5 sự kiện `model.call` {role, model_id, request_hash, prompt_hash, tokens_in,
tokens_out, cache_read_tokens, latency_ms, cost_usd, stop_reason, error_kind?}.

Ba điều đáng nói về thiết kế:

1. **Gọi REST bằng `urllib` của stdlib, không dùng SDK.** `pyproject.toml` có nhóm tùy chọn
   `llm = [anthropic, google-genai]`, nhưng bắt `make check` phụ thuộc hai SDK để chạy được
   một lớp mỏng chuyển JSON là trả giá sai chỗ — cùng lập luận đã chọn argparse thay typer
   (DEV-003). Hai API này đều là POST JSON; phần khó là schema và ngân sách, không phải HTTP.

2. **Đầu ra có cấu trúc là bắt buộc, không phải tùy chọn.** PRS-16 §1 quy tắc (2) nói mọi đầu
   ra theo schema mẫu số chung. Nên `generate()` luôn nhận `schema` và luôn kiểm — một mô hình
   trả văn xuôi thay vì JSON là một lỗi, không phải một biến thể.

3. **Ngân sách cưỡng chế TRƯỚC khi gọi.** `policy.daily_budget_usd` chỉ có nghĩa nếu nó chặn
   được lời gọi tiếp theo; kiểm sau khi gọi thì tiền đã tiêu rồi. Số đã tiêu đọc từ ledger
   (M3), không từ bộ đếm trong bộ nhớ — cùng lý do như `project.status`.
"""
from __future__ import annotations

import hashlib
import json
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

import yaml

from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir

TIMEOUT_S = 120


@dataclass
class ModelResponse:
    data: dict[str, Any]
    model_id: str
    tokens_in: int = 0
    tokens_out: int = 0
    latency_ms: int = 0
    cost_usd: float = 0.0
    stop_reason: str = "stop"
    raw: str = ""


class ModelPort:
    """Cổng tới một nhà cung cấp. `generate` trả JSON đã phân tích theo `schema`."""

    provider = "?"

    def generate(self, model: str, system: str, user: str, schema: dict[str, Any], *,
                 temperature: float = 0.0, max_output: int = 4096) -> ModelResponse:
        raise NotImplementedError


def _post(url: str, body: dict[str, Any], headers: dict[str, str]) -> dict[str, Any]:
    req = urllib.request.Request(url, data=json.dumps(body).encode("utf-8"),
                                 headers={"Content-Type": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as r:   # noqa: S310 — URL từ cấu hình
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        chi_tiet = e.read().decode("utf-8", "replace")[:400]
        loai = {429: "rate_limit", 408: "timeout"}.get(e.code, "http")
        raise GatewayError(loai, f"HTTP {e.code}: {chi_tiet}") from e
    except TimeoutError as e:
        raise GatewayError("timeout", "hết thời gian chờ") from e
    except urllib.error.URLError as e:
        raise GatewayError("network", str(e.reason)) from e


class GatewayError(Exception):
    """Lỗi khi gọi mô hình. `kind` khớp từ vựng của `policy.fallback_on`."""

    def __init__(self, kind: str, message: str) -> None:
        self.kind = kind
        super().__init__(message)


class GeminiPort(ModelPort):
    provider = "gemini"
    BASE = "https://generativelanguage.googleapis.com/v1beta/models"

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY", "")

    def generate(self, model, system, user, schema, *, temperature=0.0, max_output=4096):
        if not self.api_key:
            raise GatewayError("no_key", "Thiếu GEMINI_API_KEY (xem .env.example)")
        body = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
            "generationConfig": {"temperature": temperature, "maxOutputTokens": max_output,
                                 "responseMimeType": "application/json",
                                 "responseSchema": _gemini_schema(schema)},
        }
        t0 = time.perf_counter()
        d = _post(f"{self.BASE}/{model}:generateContent?key={self.api_key}", body, {})
        ms = int((time.perf_counter() - t0) * 1000)
        if "error" in d:
            raise GatewayError("refusal", str(d["error"].get("message"))[:300])
        cand = (d.get("candidates") or [{}])[0]
        text = "".join(p.get("text", "") for p in (cand.get("content") or {}).get("parts", []))
        u = d.get("usageMetadata") or {}
        return ModelResponse(data=_doc_json(text), model_id=model, raw=text,
                             tokens_in=u.get("promptTokenCount", 0),
                             tokens_out=u.get("candidatesTokenCount", 0), latency_ms=ms,
                             stop_reason=str(cand.get("finishReason", "stop")).lower())


class ClaudePort(ModelPort):
    provider = "claude"
    URL = "https://api.anthropic.com/v1/messages"

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY", "")

    def generate(self, model, system, user, schema, *, temperature=0.0, max_output=4096):
        if not self.api_key:
            raise GatewayError("no_key", "Thiếu ANTHROPIC_API_KEY (xem .env.example)")
        # Claude không có `responseSchema`; đầu ra có cấu trúc đi qua một tool bắt buộc.
        body = {
            "model": model, "max_tokens": max_output, "temperature": temperature,
            "system": system, "messages": [{"role": "user", "content": user}],
            "tools": [{"name": "tra_ket_qua", "description": "Trả kết quả đúng schema.",
                       "input_schema": schema}],
            "tool_choice": {"type": "tool", "name": "tra_ket_qua"},
        }
        t0 = time.perf_counter()
        d = _post(self.URL, body, {"x-api-key": self.api_key, "anthropic-version": "2023-06-01"})
        ms = int((time.perf_counter() - t0) * 1000)
        khoi = next((c for c in d.get("content", []) if c.get("type") == "tool_use"), None)
        if khoi is None:
            raise GatewayError("refusal", "Mô hình không gọi tool bắt buộc")
        u = d.get("usage") or {}
        return ModelResponse(data=khoi.get("input") or {}, model_id=model,
                             raw=json.dumps(khoi.get("input"), ensure_ascii=False),
                             tokens_in=u.get("input_tokens", 0), tokens_out=u.get("output_tokens", 0),
                             latency_ms=ms, stop_reason=str(d.get("stop_reason", "stop")))


class EchoPort(ModelPort):
    """Cổng giả cho test: không ra mạng, trả sẵn theo hàng đợi.

    DEP-26 §5 gọi job này là `contract` — "adapter LLM với bản ghi/phát lại". Test hằng ngày
    phải chạy được khi không có mạng và không tốn tiền; gọi mô hình thật là việc của job
    `dialog` chạy ban đêm.
    """

    provider = "echo"

    def __init__(self, tra_loi: list[Any] | None = None) -> None:
        self.tra_loi = list(tra_loi or [])
        self.goi: list[dict[str, Any]] = []

    def generate(self, model, system, user, schema, *, temperature=0.0, max_output=4096):
        self.goi.append({"model": model, "system": system, "user": user, "schema": schema})
        if not self.tra_loi:
            raise GatewayError("refusal", "EchoPort hết câu trả lời đã nạp")
        x = self.tra_loi.pop(0)
        if isinstance(x, GatewayError):
            raise x
        return ModelResponse(data=x, model_id=model, tokens_in=10, tokens_out=20, latency_ms=1,
                             raw=json.dumps(x, ensure_ascii=False))


# ---------------------------------------------------------------- Gateway

@dataclass
class Gateway:
    """SDD-04 §4.3 `Router.pick(role, need)` — chọn mô hình theo vai trò và ghi lý do vào ledger."""

    config: dict[str, Any] = field(default_factory=dict)
    ledger: Ledger | None = None
    ports: dict[str, ModelPort] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.config:
            self.config = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
        self.ports.setdefault("gemini", GeminiPort())
        self.ports.setdefault("claude", ClaudePort())

    # ---- prompt vai trò (PRS-16 §3)
    def prompt(self, role: str) -> str:
        f = spec_dir() / "prompts" / f"{role}.md"
        if not f.exists():
            raise EideError("E1001", f"Không có prompt cho vai trò {role} (PRS-16 §3)")
        return f.read_text(encoding="utf-8").strip()

    def ung_vien(self, role: str) -> list[dict[str, Any]]:
        """Danh sách ứng viên đã giải bí danh, theo thứ tự trong models.yaml."""
        r = (self.config.get("roles") or {}).get(role)
        if not r:
            raise EideError("E1001", f"Vai trò {role} không có trong models.yaml (SDD-04 §6)")
        out = []
        for bi_danh in r.get("candidates", []):
            a = (self.config.get("aliases") or {}).get(bi_danh)
            if a:
                out.append({"alias": bi_danh, **a})
        return out

    # ---- ngân sách
    def da_tieu_hom_nay(self) -> float:
        if self.ledger is None:
            return 0.0
        hom_nay = datetime.now(UTC).date().isoformat()
        return sum(float((r.get("data") or {}).get("cost_usd") or 0)
                   for r in self.ledger.records()
                   if r["kind"] == "model.call" and str(r["ts"]).startswith(hom_nay))

    def _gia(self, model: str, tin: int, tout: int) -> float:
        p = (self.config.get("pricing") or {}).get(model)
        if not p:
            return 0.0
        return round(tin / 1e6 * p.get("input", 0) + tout / 1e6 * p.get("output", 0), 6)

    # ---- API chính
    def run(self, role: str, user: str, schema: dict[str, Any], *,
            system_extra: str = "") -> ModelResponse:
        """Chạy một vai trò. Thử từng ứng viên; chỉ lui khi lỗi thuộc `policy.fallback_on`."""
        # Giải vai trò TRƯỚC mọi thứ khác: một vai trò lạ là lỗi lập trình, và báo nó bằng
        # "vượt ngân sách" hay "offline_mode" sẽ gửi người đi sai hướng.
        ds = self.ung_vien(role)
        cfg = (self.config.get("roles") or {})[role]
        pol = self.config.get("policy") or {}
        if pol.get("offline_mode"):
            raise EideError("E5000", "offline_mode đang bật — không gọi mô hình (SDD-04 §6)")
        tran = float(pol.get("daily_budget_usd") or 0)
        da = self.da_tieu_hom_nay()
        if tran and da >= tran:
            # E3003 BUDGET_EXCEEDED, không phải E5001 (đó là CONTEXT_OVERFLOW của CXD-10 §7).
            # Ngân sách là một quyết định CHÍNH SÁCH (nhóm E3xxx) chứ không phải lỗi mô hình.
            raise EideError("E3003", f"Vượt ngân sách ngày: đã tiêu {da:.4f} / {tran} USD",
                            spent=da, budget=tran)

        system = self.prompt(role) + (("\n\n" + system_extra) if system_extra else "")
        lui = set(pol.get("fallback_on") or [])
        loi: GatewayError | None = None
        for i, uv in enumerate(ds):
            port = self.ports.get(uv["provider"])
            if port is None:
                continue
            try:
                resp = port.generate(uv["model"], system, user, schema,
                                     temperature=float(cfg.get("temperature", 0.0)),
                                     max_output=int(cfg.get("max_output", 4096)))
            except GatewayError as e:
                loi = e
                self._log(role, uv["model"], system, user, None, error_kind=e.kind)
                if e.kind in lui and i + 1 < len(ds):
                    continue          # còn đường lui thì thử ứng viên sau
                break
            resp.cost_usd = self._gia(uv["model"], resp.tokens_in, resp.tokens_out)
            _kiem_schema(resp.data, schema)
            self._log(role, uv["model"], system, user, resp)
            return resp
        raise EideError("E5000", f"Gọi mô hình cho vai trò {role} không thành: {loi}",
                        kind=getattr(loi, "kind", "unknown"))

    def _log(self, role: str, model: str, system: str, user: str,
             resp: ModelResponse | None, error_kind: str | None = None) -> None:
        if self.ledger is None:
            return
        d: dict[str, Any] = {
            "role": role, "model_id": model,
            "request_hash": _h(user), "prompt_hash": _h(system),
            "tokens_in": resp.tokens_in if resp else 0,
            "tokens_out": resp.tokens_out if resp else 0,
            "cache_read_tokens": 0,
            "latency_ms": resp.latency_ms if resp else 0,
            "cost_usd": resp.cost_usd if resp else 0.0,
            "stop_reason": resp.stop_reason if resp else "error",
        }
        if error_kind:
            d["error_kind"] = error_kind
        self.ledger.append("model.call", d)


# ---------------------------------------------------------------- phụ trợ

def _h(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]


def _doc_json(text: str) -> dict[str, Any]:
    """Đọc JSON từ đầu ra mô hình; bọc ```json cũng chấp nhận."""
    t = text.strip()
    if t.startswith("```"):
        t = t.split("\n", 1)[-1].rsplit("```", 1)[0]
    try:
        return json.loads(t)
    except json.JSONDecodeError as e:
        raise GatewayError("refusal", f"Đầu ra không phải JSON: {t[:200]}") from e


def _gemini_schema(schema: dict[str, Any]) -> dict[str, Any]:
    """Bỏ các khóa Gemini không nhận.

    PRS-16 §1 quy tắc (2) đã giới hạn schema ở mẫu số chung (không anyOf/$ref, sâu ≤ 3) đúng
    để ba nhà cung cấp dùng chung được; hàm này chỉ dọn phần metadata còn lại.
    """
    bo = {"additionalProperties", "$schema", "title", "default", "examples"}
    if not isinstance(schema, dict):
        return schema
    ra = {k: v for k, v in schema.items() if k not in bo}
    if "properties" in ra:
        ra["properties"] = {k: _gemini_schema(v) for k, v in ra["properties"].items()}
    if "items" in ra:
        ra["items"] = _gemini_schema(ra["items"])
    return ra


def _kiem_schema(data: Any, schema: dict[str, Any]) -> None:
    """PRS-16 §1 (2): đầu ra phải đúng schema. Sai schema là LỖI, không phải biến thể.

    Dùng E5002 — API-15 dành mã ấy cho "đầu ra mô hình sai schema", khác với E6001 dùng cho
    kết quả năng lực (xem DEV-002).
    """
    import jsonschema
    try:
        jsonschema.validate(data, schema)
    except jsonschema.ValidationError as e:
        raise EideError("E5002", f"Đầu ra mô hình sai schema: {e.message}",
                        path=list(e.absolute_path)) from e
