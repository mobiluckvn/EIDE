"""Capability Registry — nạp hợp đồng năng lực từ docs/spec (chuẩn) và gắn hàm hiện thực.

Spec: SDD-04 §4 (CapabilityRegistry), CDS-12 (hợp đồng 13 trường + schema vào/ra), API-15 caps.list/describe/invoke.
Nguyên tắc: registry *không* cho phép khai báo năng lực ngoài spec (E1001 UNKNOWN_CAPABILITY); năng lực tự tạo
(tool.register) đi vào namespace `user.*` với hợp đồng do ToolSpec cung cấp (CDS-12.3, APD-08 §4.2).
"""
from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any

import jsonschema
import yaml

from eide_core.errors import EideError
from eide_core.paths import spec_dir

Handler = Callable[..., dict[str, Any]]

# Mức năng lực buộc phải khác hợp đồng — mỗi dòng là một mục DEVIATIONS đang Mở.
#
# RỖNG từ 07/09/2026, và rỗng ở đây có nghĩa: mức trong mã bằng đúng mức trong hợp đồng, không
# năng lực nào đang chạy khác điều CDS-12 khai. Mục duy nhất từng nằm đây là `chat.clarify`
# (khai T2 "cần người duyệt" trong khi nó CHÍNH LÀ cơ chế hỏi người — một vòng luẩn quẩn khiến
# D3 của DPS-09 không bao giờ chạy); CDS-12.6 v1.3 đã đổi nó thành T1, nên chỗ lệch biến mất
# thay vì được che. Giữ lại cơ chế vì lần lệch sau cần một nơi có tên để đặt, thay vì rải điều
# kiện trong PolicyGate. Xem DEVIATIONS DEV-020.
TIER_SUA: dict[str, str] = {}


@dataclass
class CapabilitySpec:
    code: str
    id: str
    ns: str
    desc: str
    risk: str
    tier: str
    grounding: str
    ask_when: str
    ref: str
    milestone: str
    input_schema: dict[str, Any]
    output_schema: dict[str, Any]
    steps: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    undo: str = "none"
    example: str = ""
    tc: str = ""
    volume: int = 0
    # DDD-14 bảng `capability` có hai cột này, và TOOL-06 bước 1 đòi khai `impl`/`ui` khi
    # đăng ký năng lực tạm. `cds.json` không mang chúng nên mặc định rỗng.
    impl: str = ""
    ui: str = ""

    @property
    def risk_class(self) -> str:
        return self.risk[:2]

    @property
    def tier_hieu_luc(self) -> str:
        """Mức thực dùng khi hỏi PolicyGate.

        Bằng `tier` của hợp đồng, TRỪ các năng lực trong `TIER_SUA` — xem DEVIATIONS DEV-020.
        Đặt ở đây chứ không rải trong PolicyGate để chỗ lệch spec có đúng MỘT nơi, và
        `tests/test_specs_consistency.py` soi được nó.
        """
        return TIER_SUA.get(self.id, self.tier)

    @property
    def gate(self) -> str:
        """Cổng mặc định theo nhóm năng lực (APD-08 §3.1; POL-17 §2).

        `cds.json` KHÔNG có trường `gate`, nên ánh xạ này là suy đoán của mã — và một suy đoán
        sai đã gây hậu quả thật: gán cả nhóm `tool.*` vào G-TOOL làm `tool.write` không bao giờ
        chạy được, vì mọi quy tắc G-TOOL đều hỏi `tool.tested`, và một công cụ CHƯA VIẾT thì
        đương nhiên chưa test. Xem DEVIATIONS DEV-026.

        CDS-12.3 chỉ nói `gate=G-TOOL` ở đúng MỘT chỗ: TOOL-05 bước 2, tức `tool.run`. Và
        `tool.run` tự hỏi cổng ấy với đặc trưng thật của công cụ, vì đó là nơi duy nhất các
        đặc trưng ấy tồn tại. Các `tool.*` còn lại là thao tác VỀ công cụ, không phải thực thi
        công cụ, nên chúng đi cổng chung.
        """
        return {
            "search": "G-SRC", "kg": "G-FACT", "passport": "G-FACT", "plan": "G1", "code": "G3",
            "target": "G-OPS", "discover": "G-OPS", "measure": "G4", "registry": "G5",
        }.get(self.ns, "*")


@dataclass
class Registered:
    spec: CapabilitySpec
    handler: Handler | None = None
    features_provided: list[str] = field(default_factory=list)

    @property
    def implemented(self) -> bool:
        return self.handler is not None


class Registry:
    def __init__(self, cds_path=None) -> None:
        path = cds_path or spec_dir() / "cds.json"
        rows = json.loads(path.read_text(encoding="utf-8"))
        self._caps: dict[str, Registered] = {}
        for r in rows:
            spec = CapabilitySpec(**{k: r[k] for k in CapabilitySpec.__dataclass_fields__ if k in r})
            self._caps[spec.id] = Registered(spec)
        self._user: dict[str, Registered] = {}

    # ---- năng lực tạm do tác tử tự viết (CDS-12.3 TOOL-06)
    def dang_ky_tam(self, khai_bao: dict[str, Any], handler: Handler | None = None) -> Registered:
        """Nạp NÓNG một năng lực `user.*` — TOOL-06 bước 2.

        Giữ trong `_user` tách khỏi `_caps` chứ không trộn chung, và đó là điểm chính: `_caps`
        đến từ `cds.json`, tức là từ hợp đồng người viết và duyệt; `_user` đến từ mô hình. Hai
        nguồn ấy có mức tin cậy khác nhau, nên `caps.list` phân biệt được, `test_specs_
        consistency` chỉ soi `_caps`, và một lần dọn `.eide/tools/` là xóa sạch phần thứ hai
        mà không đụng phần thứ nhất.
        """
        if not str(khai_bao.get("id", "")).startswith("user."):
            raise EideError("E1000", "Năng lực tạm phải nằm trong namespace `user.` (TOOL-06)")
        spec = CapabilitySpec(**{k: khai_bao[k] for k in CapabilitySpec.__dataclass_fields__
                                 if k in khai_bao})
        r = Registered(spec, handler)
        self._user[spec.id] = r
        return r

    def bo_dang_ky_tam(self, cap_id: str) -> None:
        self._user.pop(cap_id, None)

    # ---- tra cứu
    def __contains__(self, cap_id: str) -> bool:
        return cap_id in self._caps or cap_id in self._user

    def get(self, cap_id: str) -> Registered:
        if cap_id in self._caps:
            return self._caps[cap_id]
        if cap_id in self._user:
            return self._user[cap_id]
        raise EideError("E1001", f"Năng lực không tồn tại: {cap_id}")

    def list(self, ns: str | None = None, implemented: bool | None = None) -> list[Registered]:
        items = list(self._caps.values()) + list(self._user.values())
        if ns:
            items = [c for c in items if c.spec.ns == ns]
        if implemented is not None:
            items = [c for c in items if c.implemented == implemented]
        return sorted(items, key=lambda c: c.spec.code)

    def namespaces(self) -> list[str]:
        seen: list[str] = []
        for c in self._caps.values():
            if c.spec.ns not in seen:
                seen.append(c.spec.ns)
        return seen

    # ---- gắn hiện thực
    def bind(self, cap_id: str, handler: Handler, features: list[str] | None = None) -> None:
        reg = self.get(cap_id)
        reg.handler = handler
        reg.features_provided = features or []

    def register_user_tool(self, spec: CapabilitySpec, handler: Handler) -> None:
        """tool.register (TOOL-06): năng lực tạm `user.<tên>`, mức T1*, cổng G-TOOL."""
        if not spec.id.startswith("user."):
            raise EideError("E1000", "Công cụ tự viết phải đăng ký trong namespace user.*")
        self._user[spec.id] = Registered(spec, handler)

    # ---- kiểm schema (API-15: E1000 khi vào sai; ra sai dùng E6001 — xem DEVIATIONS DEV-002)
    def validate_input(self, cap_id: str, params: dict[str, Any]) -> None:
        try:
            jsonschema.validate(params, self.get(cap_id).spec.input_schema)
        except jsonschema.ValidationError as e:
            raise EideError("E1000", f"{cap_id}: {e.message}", path=list(e.absolute_path)) from e

    def validate_output(self, cap_id: str, result: dict[str, Any]) -> None:
        try:
            jsonschema.validate(result, self.get(cap_id).spec.output_schema)
        except jsonschema.ValidationError as e:
            raise EideError("E6001", f"{cap_id}: kết quả không khớp output_schema: {e.message}") from e  # DEV-002

    # ---- chuyển spec sang YAML/MCP (API-15 §MCP: sinh từ registry)
    def describe(self, cap_id: str) -> dict[str, Any]:
        reg = self.get(cap_id)
        d = reg.spec.__dict__.copy()
        d["implemented"] = reg.implemented
        d["gate"] = reg.spec.gate
        return d

    @staticmethod
    def load_ns_yaml(ns: str) -> list[dict[str, Any]]:
        return yaml.safe_load((spec_dir() / "capabilities" / f"{ns}.yaml").read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def get_registry() -> Registry:
    reg = Registry()
    # nạp mọi mô-đun hiện thực để decorator chạy
    import importlib
    import pkgutil

    try:
        import eide.caps as caps_pkg

        for m in pkgutil.iter_modules(caps_pkg.__path__):
            importlib.import_module(f"eide.caps.{m.name}")
    except ModuleNotFoundError:
        pass
    for cap_id, (fn, feats) in _PENDING.items():
        reg.bind(cap_id, fn, feats)
    return reg


_PENDING: dict[str, tuple[Handler, list[str]]] = {}


def capability(cap_id: str, features: list[str] | None = None) -> Callable[[Handler], Handler]:
    """Gắn hàm hiện thực vào năng lực có trong spec.

    @capability("project.create", features=["name_conflict"])
    def create(params: dict, ctx: Context) -> dict: ...
    """

    def deco(fn: Handler) -> Handler:
        _PENDING[cap_id] = (fn, features or [])
        return fn

    return deco
