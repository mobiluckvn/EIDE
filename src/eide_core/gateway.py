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
from pathlib import Path
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

    def co_khoa(self) -> bool:
        """Nhà cung cấp này đã được cấu hình chưa.

        KHÁC với "gọi bị lỗi": một nhà cung cấp không có khóa thì VẮNG MẶT, không phải hỏng.
        Phân biệt hai thứ ấy là lý do EIDE chạy được với một khóa Gemini duy nhất — nếu coi
        thiếu khóa là lỗi, mọi vai trò có Claude đứng đầu (planner, architect, reviewer…) đều
        chết, dù Gemini đứng ngay sau và dùng được.
        """
        return True

    def generate(self, model: str, system: str, user: str, schema: dict[str, Any], *,
                 temperature: float = 0.0, max_output: int = 4096,
                 anh: list[dict[str, str]] | None = None) -> ModelResponse:
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


class _KhongCo:
    """Cổng vắng mặt — coi như chưa cấu hình."""

    @staticmethod
    def co_khoa() -> bool:
        return False


class GatewayError(Exception):
    """Lỗi khi gọi mô hình. `kind` khớp từ vựng của `policy.fallback_on`."""

    def __init__(self, kind: str, message: str) -> None:
        self.kind = kind
        super().__init__(message)


#: Phần nghĩ không bao giờ được lấn quá tỉ lệ này của ngân sách đầu ra.
TI_LE_NGHI = 0.5
#: Dưới ngưỡng này thì phần nghĩ quá ngắn để mô hình suy luận làm được việc.
NGHI_TOI_THIEU = 512


def _han_nghi(max_output: int) -> int:
    """Trần token cho phần "nghĩ" của mô hình suy luận (Gemini 2.5+/3.x).

    Gemini tính token nghĩ VÀO `maxOutputTokens`. Không đặt trần thì mô hình nghĩ
    tuỳ ý rồi chạm trần TRƯỚC khi kịp viết xong câu trả lời — đo được 1037 token
    nghĩ cho 186 token trả lời ở một câu hỏi tầm thường, tức phần nghĩ gấp 5,5
    lần. Đó là lý do thật của lỗi "arch.adr bị cắt": không phải ADR dài, mà là
    phần nghĩ ăn hết ngân sách. Nới trần không cứu được vì phần nghĩ giãn theo.
    Chia đôi ngân sách để nửa còn lại LUÔN đủ chỗ cho JSON. [DEV-216]
    """
    return max(NGHI_TOI_THIEU, int(max_output * TI_LE_NGHI))


class GeminiPort(ModelPort):
    provider = "gemini"
    BASE = "https://generativelanguage.googleapis.com/v1beta/models"

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY", "")

    def co_khoa(self) -> bool:
        return bool(self.api_key)

    def generate(self, model, system, user, schema, *, temperature=0.0, max_output=4096,
                 anh: list[dict[str, str]] | None = None):
        if not self.api_key:
            raise GatewayError("no_key", "Thiếu GEMINI_API_KEY (xem .env.example)")
        phan: list[dict[str, Any]] = [{"text": user}]
        # Ảnh đi TRƯỚC văn bản. Cả hai hãng đều khuyến nghị thế, và lý do thực dụng: câu hỏi
        # nhắc tới "hình dưới đây" thì hình phải đã ở trong ngữ cảnh khi mô hình đọc tới câu ấy.
        for a in (anh or []):
            phan.insert(-1, {"inlineData": {"mimeType": a["media_type"], "data": a["data"]}})
        body = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": phan}],
            "generationConfig": {"temperature": temperature, "maxOutputTokens": max_output,
                                 "responseMimeType": "application/json",
                                 "responseSchema": _gemini_schema(schema),
                                 "thinkingConfig": {"thinkingBudget": _han_nghi(max_output)}},
        }
        t0 = time.perf_counter()
        d = _post(f"{self.BASE}/{model}:generateContent?key={self.api_key}", body, {})
        ms = int((time.perf_counter() - t0) * 1000)
        if "error" in d:
            raise GatewayError("refusal", str(d["error"].get("message"))[:300])
        cand = (d.get("candidates") or [{}])[0]
        text = "".join(p.get("text", "") for p in (cand.get("content") or {}).get("parts", []))
        u = d.get("usageMetadata") or {}
        stop = str(cand.get("finishReason", "stop")).lower()
        _kiem_cat(stop, model, max_output, u.get("thoughtsTokenCount", 0))   # [DEV-216]
        # Token nghĩ CÓ bị tính tiền. Bỏ nó khỏi `tokens_out` thì `cost_usd` —
        # và trần `daily_budget_usd` dựng trên nó — hụt đúng phần đắt nhất: ở phép
        # đo trên, 1037/1223 token đầu ra (85%) vô hình với ngân sách. [DEV-216]
        return ModelResponse(data=_doc_json(text), model_id=model, raw=text,
                             tokens_in=u.get("promptTokenCount", 0),
                             tokens_out=u.get("candidatesTokenCount", 0)
                             + u.get("thoughtsTokenCount", 0), latency_ms=ms,
                             stop_reason=stop)


class ClaudePort(ModelPort):
    provider = "claude"
    URL = "https://api.anthropic.com/v1/messages"

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY", "")

    def co_khoa(self) -> bool:
        return bool(self.api_key)

    def generate(self, model, system, user, schema, *, temperature=0.0, max_output=4096,
                 anh: list[dict[str, str]] | None = None):
        if not self.api_key:
            raise GatewayError("no_key", "Thiếu ANTHROPIC_API_KEY (xem .env.example)")
        noi_dung: list[dict[str, Any]] = [
            {"type": "image", "source": {"type": "base64", "media_type": a["media_type"],
                                         "data": a["data"]}}
            for a in (anh or [])]
        noi_dung.append({"type": "text", "text": user})
        # Claude không có `responseSchema`; đầu ra có cấu trúc đi qua một tool bắt buộc.
        body = {
            "model": model, "max_tokens": max_output, "temperature": temperature,
            "system": system, "messages": [{"role": "user", "content": noi_dung}],
            "tools": [{"name": "tra_ket_qua", "description": "Trả kết quả đúng schema.",
                       "input_schema": schema}],
            "tool_choice": {"type": "tool", "name": "tra_ket_qua"},
        }
        t0 = time.perf_counter()
        d = _post(self.URL, body, {"x-api-key": self.api_key, "anthropic-version": "2023-06-01"})
        ms = int((time.perf_counter() - t0) * 1000)
        stop = str(d.get("stop_reason", "stop"))
        # [DEV-216] Kiểm CẮT trước. Claude trả `stop_reason: "max_tokens"` và một khối
        # `tool_use` DANG DỞ — không có khối nào, hoặc có mà thiếu trường. Báo "không gọi tool
        # bắt buộc" cho một mô hình đã gọi tool nhưng bị cắt giữa chừng là chỉ sai hướng.
        _kiem_cat(stop, model, max_output)
        khoi = next((c for c in d.get("content", []) if c.get("type") == "tool_use"), None)
        if khoi is None:
            raise GatewayError("refusal", "Mô hình không gọi tool bắt buộc")
        u = d.get("usage") or {}
        return ModelResponse(data=khoi.get("input") or {}, model_id=model,
                             raw=json.dumps(khoi.get("input"), ensure_ascii=False),
                             tokens_in=u.get("input_tokens", 0), tokens_out=u.get("output_tokens", 0),
                             latency_ms=ms, stop_reason=stop)


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

    def generate(self, model, system, user, schema, *, temperature=0.0, max_output=4096,
                 anh=None):
        # GHI LẠI `anh`: một cổng giả nuốt mất ảnh thì mọi test đường ảnh đều xanh mà không
        # test nào chứng minh được ảnh đã tới cổng.
        self.goi.append({"model": model, "system": system, "user": user, "schema": schema,
                         "anh": list(anh or [])})
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

    def hang_cua(self, model_id: str) -> str | None:
        """Nhà cung cấp của một `model_id` cụ thể, tra ngược qua `aliases` của models.yaml.

        `ModelResponse` mang `model_id` chứ không mang nhà cung cấp, mà hai hợp đồng cần đúng
        thông tin ấy: CODE-11 đòi grounding "≥ 2 hãng" và quy tắc `G3-01` so
        `reviewer.vendor != coder.vendor`. Tra ngược ở đây, một chỗ, thay vì mỗi năng lực tự
        đoán hãng từ tiền tố tên mô hình — `claude-sonnet-5` đoán được, `gpt-4o-2024` thì không.
        """
        for a in (self.config.get("aliases") or {}).values():
            if a.get("model") == model_id:
                return a.get("provider")
        return None

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
            system_extra: str = "", anh: list[dict[str, str]] | None = None) -> ModelResponse:
        """Chạy một vai trò. Thử từng ứng viên; chỉ lui khi lỗi thuộc `policy.fallback_on`.

        `anh` là danh sách `{media_type, data}` với `data` mã hoá base64 — dạng chung của cả
        Gemini (`inlineData`) lẫn Claude (`source.base64`), nên người gọi không phải biết đang
        nói chuyện với hãng nào.

        **Vai trò KHÔNG khai `inputs: [image]` mà lại được truyền ảnh là lỗi lập trình, không
        phải một yêu cầu để chiều.** `models.yaml` khai vai trò nào nhìn được — chỉ `cartographer`
        — và một vai trò văn bản nhận ảnh sẽ hoặc bị hãng từ chối, hoặc tệ hơn: lặng lẽ bỏ qua
        ảnh rồi trả lời như thể đã nhìn. Cái thứ hai là lý do phép kiểm này ném chứ không cảnh
        báo.
        """
        if anh:
            vao = ((self.config.get("roles") or {}).get(role) or {}).get("inputs") or ["text"]
            if "image" not in vao:
                raise GatewayError(
                    "bad_role", f"Vai trò `{role}` không khai `inputs: [image]` trong models.yaml "
                    f"(chỉ {vao}) — nhưng được truyền {len(anh)} ảnh. Dùng `cartographer`.")
        # Giải vai trò TRƯỚC mọi thứ khác: một vai trò lạ là lỗi lập trình, và báo nó bằng
        # "vượt ngân sách" hay "offline_mode" sẽ gửi người đi sai hướng.
        ds = self.ung_vien(role)
        cfg = (self.config.get("roles") or {})[role]
        # Bỏ qua nhà cung cấp CHƯA CẤU HÌNH, giữ nguyên thứ tự ưu tiên cho phần còn lại.
        # Đây không phải một đường lui: đường lui là khi một lời gọi THẤT BẠI. Ở đây ứng viên
        # ấy chưa từng có mặt.
        co_the = [uv for uv in ds if (self.ports.get(uv["provider"]) or _KhongCo()).co_khoa()]
        if not co_the:
            thieu = sorted({uv["provider"] for uv in ds})
            raise EideError("E5000", f"Vai trò {role} không có nhà cung cấp nào đã cấu hình "
                                     f"(cần khóa cho: {', '.join(thieu)}) — xem .env.example",
                            role=role, providers=thieu)
        ds = co_the
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
                                     max_output=int(cfg.get("max_output", 4096)),
                                     anh=anh)
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
        self._ghi_day_du(d, system, user, resp)

    def _ghi_day_du(self, d: dict[str, Any], system: str, user: str,
                    resp: ModelResponse | None) -> None:
        """Bản ghi ĐẦY ĐỦ câu nhắc và câu trả lời — chỉ khi `EIDE_LOG_LLM` bật. [DEV-217]

        Ledger cố tình chỉ giữ `request_hash`/`prompt_hash`: API-15 §5 liệt kê đúng các trường
        ấy, và câu nhắc mang nguyên nội dung dự án — yêu cầu, mã, trích datasheet. Đổ cả văn
        bản vào ledger là đổi schema của một sự kiện đã đặc tả, VÀ biến một tệp vốn chia sẻ
        được thành tệp không chia sẻ được.

        Nhưng băm thì không truy lỗi được. Cả đợt [DEV-216] mất nhiều vòng đo chỉ vì không ai
        đọc được mô hình đã NHẬN gì và TRẢ gì — thủ phạm thật (vòng lặp khuôn câu về radio
        FM/AM, DECT, PBX) chỉ lộ ra khi in thẳng đầu ra bị cắt ra xem, bằng một script rời
        nằm ngoài sản phẩm.

        Nên: tệp RIÊNG, cạnh ledger, TẮT theo mặc định. `EIDE_LOG_LLM` đã có sẵn trong
        `.env.example` từ đầu và chưa nối vào đâu — đây là chỗ nó thuộc về.
        """
        if not os.environ.get("EIDE_LOG_LLM") or self.ledger is None:
            return
        f = Path(self.ledger.path).parent / "llm-day-du.jsonl"
        ban = dict(d)
        ban["system"] = system
        ban["user"] = user
        ban["raw"] = resp.raw if resp else None
        ban["data"] = resp.data if resp else None
        ban["ts"] = datetime.now(UTC).isoformat()
        try:
            with f.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(ban, ensure_ascii=False) + "\n")
        except OSError:
            # Ghi log hỏng KHÔNG được làm hỏng lời gọi mô hình — đây là dụng cụ chẩn đoán,
            # không phải một phần của hợp đồng năng lực.
            pass


# ---------------------------------------------------------------- phụ trợ

def _h(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]


#: Lý do dừng mà nhà cung cấp trả khi ĐẦU RA BỊ CẮT vì chạm trần token. Mỗi hãng một chữ.
LY_DO_CAT = {"max_tokens", "length", "maxtokens", "max_output_tokens"}


def _kiem_cat(stop: str, model: str, max_output: int, nghi: int = 0) -> None:
    """Đầu ra bị cắt thì NÓI ĐÚNG LÀ BỊ CẮT, và nói đúng AI đã ăn hết chỗ. [DEV-216]

    Cả hai cổng đều ĐỌC `finishReason`/`stop_reason` — nhưng chúng đọc nó ở vị trí đối số đứng
    SAU `_doc_json(text)`, mà Python tính đối số từ trái sang phải. Nên khi đầu ra bị cắt giữa
    chừng, `_doc_json` ném trước và thông tin "bị cắt" đang nằm ngay đó bị vứt đi.

    Người dùng nhận: *"Đầu ra không phải JSON: {\"title\":\"ADR: Chọn kiến trúc…"* — một câu
    lỗi nói rằng mô hình trả sai định dạng, trong khi phần in ra BẮT ĐẦU BẰNG JSON HỢP LỆ. Đo
    24/09/2026 trên TC002/TC008/TC048: `arch.adr` hỏng như thế mọi lần, không ngẫu nhiên, vì
    vai trò `architect` không khai `max_output` nên rơi về mặc định 4096 — mà ADR thì dài theo
    bản chất (title, context, options, choice, consequences).

    Câu lỗi sai hướng đắt hơn câu lỗi cộc lốc: nó đẩy người đọc đi tìm lỗi định dạng ở một chỗ
    không có lỗi nào. Cùng bài học với [DEV-202] và [DEV-210].

    Loại lỗi là `truncated`, KHÔNG phải `refusal`: `policy.fallback_on` có `refusal`, nên gọi
    nó là refusal sẽ lặng lẽ thử ứng viên kế — mà ứng viên kế cũng chạm đúng trần ấy. Lui sang
    một mô hình khác không chữa được một cái trần đặt quá thấp.

    Nới trần lên 12288 vẫn cắt, và ràng buộc độ dài trong prompt cũng không cứu. Đo thẳng
    `usageMetadata` mới ra thủ phạm thật: `thoughtsTokenCount` — phần NGHĨ của mô hình suy
    luận cũng tính vào `maxOutputTokens`. Một câu hỏi tầm thường tiêu 1037 token nghĩ cho
    186 token trả lời. Trần nào cũng không an toàn khi phần nghĩ giãn tự do, nên chỗ sửa
    thật nằm ở `thinkingBudget` (xem `_han_nghi`), không phải ở `max_output`.

    Hai nguyên nhân ấy đòi hai cách chữa ngược nhau — nới trần, hay siết phần nghĩ — nên câu
    lỗi phải phân biệt được chúng, thay vì khuyên nới trần trong đúng trường hợp nới trần vô ích.
    """
    if stop.lower() not in LY_DO_CAT:
        return
    if nghi and nghi >= max_output * TI_LE_NGHI:
        raise GatewayError(
            "truncated",
            f"Đầu ra của `{model}` BỊ CẮT: phần NGHĨ tiêu {nghi}/{max_output} token nên "
            f"không còn chỗ viết câu trả lời. Nới `max_output` KHÔNG cứu được vì phần nghĩ "
            f"giãn theo — hạ `thinkingBudget`, hoặc chọn mô hình không suy luận cho vai trò này.")
    raise GatewayError(
        "truncated",
        f"Đầu ra của `{model}` BỊ CẮT vì chạm trần {max_output} token "
        f"(lý do dừng: {stop}). Không phải mô hình trả sai định dạng — nới "
        f"`max_output` của vai trò này trong `models.yaml`, hoặc hỏi ngắn lại.")


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
