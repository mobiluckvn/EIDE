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


@lru_cache(maxsize=1)
def _gate_tu_spec() -> dict[str, str]:
    """id năng lực → cổng, rút từ chỗ hợp đồng NHẮC ĐÍCH DANH cổng ấy.

    Quét `steps` và `ask_when` của cds.json tìm tên cổng trong bảng quy tắc POL-17 §2. Quét chứ
    không chép tay: một bảng chép tay sẽ trôi khỏi đặc tả đúng lúc đặc tả đổi, và cả phiên làm
    việc này đã cho thấy chuyện ấy xảy ra ở đâu cũng được.

    Bỏ qua `*`: nó là dải quy tắc chung áp cho mọi hành động, không phải cổng của riêng ai.

    Bỏ qua `G-FACT` và `G1`, và đây là một khác biệt về BẢN CHẤT chứ không phải hai ngoại lệ.
    Mọi cổng đều xét một HIỆN VẬT — G-OPS xét `board`/`artifact`, G-SRC xét `source`, G3 xét
    `patch`, G5 xét `pkg`. Khác biệt nằm ở chỗ hiện vật ấy có TỒN TẠI TRƯỚC lời gọi hay không:

    · `target.flash` nhận `artifact` làm THAM SỐ, nên Router đánh giá G-OPS được trước khi gọi —
      đó là mô hình mà POL-17 §2 mô tả ("đặc trưng do năng lực cung cấp khi gọi Router");
    · `plan.create` SINH RA bản kế hoạch mà G1 xét (`plan.steps`, `plan.all_cited`,
      `plan.arch_change`), và `kg.review_facts` xét từng fact nó nạp lên. Hiện vật chưa tồn tại
      lúc Router quyết định, nên hỏi cổng ở cửa chỉ cho ra quy tắc bắt hết — luôn ASK.

    Hệ quả nếu để Router chặn: `kg.review_facts` bị chính cổng nó phục vụ chặn lại và không fact
    nào được duyệt bao giờ; `plan.create` không bao giờ chạy nên không bao giờ có kế hoạch để G1
    xét. Cùng vòng luẩn quẩn với `chat.clarify` (DEV-020) và `tool.write` (DEV-026), lần này ở
    tầng hiện vật. Hai năng lực ấy hỏi cổng BÊN TRONG, đúng như hợp đồng viết: CDS-12.2 KG-05
    "với mỗi fact chạy policy.decide(G-FACT)", CDS-12.1 PLAN-03 "policy.decide(G1) với đặc trưng
    steps/all_cited/…". Xem DEVIATIONS DEV-054.
    """
    import re

    from eide_core.paths import spec_dir

    caps = json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))
    ten_cong = sorted(
        {r["gate"] for r in yaml.safe_load(
            (spec_dir() / "policy" / "rules.yaml").read_text(encoding="utf-8"))["rules"]} - {"*"},
        key=len, reverse=True)          # dài trước: "G-OPS" phải khớp trước "G1"
    ten_cong = [g for g in ten_cong if g not in ("G-FACT", "G1")]
    mau = re.compile("|".join(re.escape(g) for g in ten_cong))
    ra: dict[str, str] = {}
    for c in caps:
        van = " ".join(c.get("steps", [])) + " " + str(c.get("ask_when", ""))
        if (m := mau.search(van)):
            ra[c["id"]] = m.group(0)
    return ra


@lru_cache(maxsize=1)
def _ui_tu_spec() -> dict[str, str]:
    """id năng lực → tên màn hình, suy từ bảng §2 của UXD-13 (`ui/screens.json`).

    UXD-13 U1 nói ô lệnh gợi ý "/" liệt kê "năng lực có `ui`", nhưng KHÔNG năng lực nào trong
    `cds.json` có trường ấy (0/238) — nên quy tắc U1 không áp dụng được như viết. Nguồn duy nhất
    nói năng lực nào thuộc màn hình nào là bảng §2, dạng `chat.*` (cả nhóm) hoặc `project.status`
    (một năng lực). Xem DEVIATIONS DEV-046.

    Một năng lực xuất hiện ở nhiều màn hình thì lấy màn hình ĐẦU TIÊN: bảng §2 xếp theo thứ tự
    màn hình, và màn hình số nhỏ là màn hình chính của năng lực ấy (Chat là số 1).
    """
    f = spec_dir() / "ui" / "screens.json"
    if not f.exists():
        return {}
    ra: dict[str, str] = {}
    caps = [c["id"] for c in json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))]
    for man in json.loads(f.read_text(encoding="utf-8")):
        for mau in man["nang_luc"]:
            khop = ([c for c in caps if c.startswith(mau[:-1])] if mau.endswith("*")
                    else [c for c in caps if c == mau])
            for c in khop:
                ra.setdefault(c, man["man_hinh"])
    return ra


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
    # đăng ký năng lực tạm. `cds.json` không mang chúng nên mặc định rỗng — `ui` được suy từ
    # bảng màn hình UXD-13 §2 qua thuộc tính `man_hinh` bên dưới (DEV-046).
    impl: str = ""
    ui: str = ""

    @property
    def man_hinh(self) -> str:
        """Màn hình của năng lực: `ui` nếu hợp đồng có khai (năng lực `user.*` tự tạo), không
        thì suy từ bảng UXD-13 §2. Rỗng = không xuất hiện trên màn hình nào."""
        return self.ui or _ui_tu_spec().get(self.id, "")

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
        """Cổng của năng lực, SUY TỪ ĐẶC TẢ chứ không đoán theo nhóm (APD-08 §3.1; POL-17 §2).

        `cds.json` không có trường `gate` riêng, nhưng các hợp đồng CÓ nhắc đích danh cổng trong
        `steps` hoặc `ask_when` — ví dụ TOOL-05 bước 2 nói `gate=G-TOOL`, KG-05 nói "với mỗi
        fact chạy policy.decide(G-FACT)". `_GATE_TU_SPEC` rút chính những chỗ ấy ra.

        Bản trước ánh xạ theo NHÓM, và đó là một suy đoán sai với hậu quả đo được. Lần đầu:
        gán cả `tool.*` vào G-TOOL làm `tool.write` không bao giờ chạy được, vì mọi quy tắc
        G-TOOL đều hỏi `tool.tested` mà một công cụ CHƯA VIẾT thì đương nhiên chưa test
        (DEV-026). Lần thứ hai, khi nhóm `kg.*` được hiện thực: ánh xạ theo nhóm áp cổng cho
        **73 năng lực** trong khi tài liệu chỉ nêu cổng cho **10**, và ba nhóm nguyên vẹn
        (`passport` 8 năng lực, `discover` 12, `measure` 3) nhận một cổng mà không hợp đồng nào
        trong đó từng nhắc tới. Hệ quả: `kg.request` — tạo một yêu cầu nhận tri thức — bị hỏi
        bằng quy tắc `G-FACT-99` "bạc dưới ngưỡng / OCR / thiếu nguồn hai", một câu chẳng liên
        quan gì tới việc nó làm. Xem DEVIATIONS DEV-041.

        Năng lực không được đặc tả gán cổng nào thì đi dải quy tắc chung `*`, nơi tầng năng lực
        (APD-08 §4.1 tầng 5) quyết theo mức T1/T2/T3 — đúng thứ dành cho chúng.
        """
        return _gate_tu_spec().get(self.id, "*")


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
            # API-15 §3 v1.5 `E1004 OUTPUT_SCHEMA`. Trước đó phải mượn E6001 SCHEMA_VIOLATION,
            # vốn dành cho ghi sai schema dữ liệu DDD-14 — một lỗi của DỮ LIỆU, không phải của
            # mã. Lẫn hai thứ vào một mã làm người đọc nhật ký đi soi store trong khi chỗ hỏng
            # là một hàm trả sai hình dạng. Xem DEVIATIONS DEV-002.
            raise EideError("E1004", f"{cap_id}: kết quả không khớp output_schema: {e.message}") from e

    # ---- chuyển spec sang YAML/MCP (API-15 §MCP: sinh từ registry)
    def describe(self, cap_id: str) -> dict[str, Any]:
        """Hợp đồng đầy đủ của một năng lực — `caps.describe` của API-15 §1.

        `ui` lấy từ thuộc tính SUY ra (`man_hinh`), không lấy trường thô. `spec.__dict__` chỉ
        có `ui` như đã khai trong hợp đồng, mà `cds.json` không khai cho năng lực nào (0/238,
        DEV-046) — nên bản đầu trả `ui: ""` cho cả 238 năng lực, trong khi `caps.list` cùng lúc
        trả tên màn đầy đủ vì nó đọc `c.spec.man_hinh`.

        Hai phương thức nói hai thứ khác nhau về cùng một năng lực là thứ không ai nghi cho tới
        lúc một bên được dùng để quyết định điều gì: panel định tuyến theo `caps.list` nên vẫn
        chạy, còn bất cứ ai hỏi `caps.describe` — MCP, một IDE khác, một bài test — đều nhận
        được câu trả lời rằng năng lực này không thuộc màn hình nào.
        """
        reg = self.get(cap_id)
        d = reg.spec.__dict__.copy()
        d["implemented"] = reg.implemented
        d["gate"] = reg.spec.gate
        d["ui"] = reg.spec.man_hinh
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
