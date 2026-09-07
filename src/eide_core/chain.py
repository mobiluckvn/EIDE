"""Chuỗi năng lực và phép kiểm deterministic — DPS-09 §4.4; CDS-12.6 CHAT-06. WI-CHAT-06.

    Orchestrator lập đồ thị chuỗi bằng mô hình lập kế hoạch (vai trò planner) có output_schema
    `Chain{nodes[]: {id, cap, args, when?, on_ask}}` và kiểm tra deterministic sau đó: mọi `cap`
    tồn tại trong registry; tham số khớp input schema; không có chu trình; số nút ≤ ngưỡng; ước
    lượng chi phí ≤ ngân sách.

## Vì sao phép kiểm nằm ở đây chứ không ở prompt

Mô hình lập kế hoạch có thể sinh ra một chuỗi trông hợp lý mà gọi một năng lực không tồn tại,
truyền sai tham số, hay tự vòng lại chính nó. Nhờ prompt dặn "đừng làm thế" là một biện pháp
không kiểm được; còn năm phép kiểm dưới đây thì hoặc đạt hoặc không, và khi không đạt thì nói
được HỎNG Ở NÚT NÀO.

Đây cũng là ranh giới mà DPS-09 §1 vạch ra: tầng hiểu lệnh là deterministic, phần sinh mới dùng
mô hình. Một chuỗi do mô hình đề xuất chỉ trở thành kế hoạch sau khi qua tầng deterministic.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any

from eide_core.errors import EideError
from eide_core.paths import spec_dir

# DPS-09 §4.4: `on_ask` quyết định nhánh làm gì khi một nút rơi vào ASK.
ON_ASK = ("wait", "parallel", "skip")
TRAN_NUT = 24          # "số nút ≤ ngưỡng" — xem `kiem()` về chỗ lấy con số này


@lru_cache(maxsize=1)
def mau() -> list[dict[str, Any]]:
    """Năm chuỗi mẫu của §4.4, sinh từ `dps.js` (`dialog/chains.json`)."""
    f = spec_dir() / "dialog" / "chains.json"
    return json.loads(f.read_text(encoding="utf-8")) if f.exists() else []


def chon_mau(intent: str) -> dict[str, Any] | None:
    """Chuỗi mẫu theo ý định — CHAT-06 bước 1 "theo trigger_intents".

    Bám mẫu TRƯỚC khi nhờ mô hình: rẻ hơn, đoán được hơn, và DPS-09 §4.4 nói thẳng lý do — "để
    mô hình bám theo thay vì sáng tác". Không có mẫu nào khớp thì mới tới lượt planner.
    """
    for c in mau():
        if intent in c.get("trigger_intents", []):
            return c
    return None


@dataclass
class Nut:
    """Một nút của Chain — DPS-09 §4.4 `{id, cap, args, when?, on_ask}`."""

    id: str
    cap: str
    args: dict[str, Any] = field(default_factory=dict)
    when: str | None = None            # id nút phải xong trước (rỗng = chạy ngay)
    on_ask: str = "wait"

    @classmethod
    def tu_dict(cls, d: dict[str, Any]) -> Nut:
        return cls(id=str(d.get("id", "")), cap=str(d.get("cap", "")),
                   args=d.get("args") or {}, when=d.get("when"),
                   on_ask=str(d.get("on_ask") or "wait"))

    def as_dict(self) -> dict[str, Any]:
        return {"id": self.id, "cap": self.cap, "args": self.args,
                "when": self.when, "on_ask": self.on_ask}


@dataclass
class Chain:
    nodes: list[Nut] = field(default_factory=list)

    @classmethod
    def tu_dict(cls, d: dict[str, Any]) -> Chain:
        return cls([Nut.tu_dict(n) for n in (d.get("nodes") or [])])

    def as_dict(self) -> dict[str, Any]:
        return {"nodes": [n.as_dict() for n in self.nodes]}


def kiem(chain: Chain, registry: Any, *, tran_nut: int = TRAN_NUT,
         chi_phi_uoc: float = 0.0, ngan_sach: float | None = None) -> None:
    """Năm phép kiểm của §4.4. Ném E5002 ở lỗi cấu trúc, E3003 ở lỗi ngân sách.

    Gom TẤT CẢ lỗi cấu trúc rồi mới ném, không dừng ở lỗi đầu: một chuỗi do mô hình sinh thường
    sai vài chỗ cùng lúc, và trả về từng lỗi một sẽ tốn đúng số lần gọi mô hình bằng số lỗi.
    """
    loi: list[str] = []
    if not chain.nodes:
        loi.append("chuỗi rỗng")

    ids = [n.id for n in chain.nodes]
    if len(set(ids)) != len(ids):
        trung = sorted({i for i in ids if ids.count(i) > 1})
        loi.append(f"id nút trùng: {trung}")
    if any(not i for i in ids):
        loi.append("có nút không có id")

    if len(chain.nodes) > tran_nut:
        loi.append(f"{len(chain.nodes)} nút vượt ngưỡng {tran_nut}")

    for n in chain.nodes:
        if n.cap not in registry:
            loi.append(f"{n.id}: năng lực `{n.cap}` không có trong registry")
            continue
        if not registry.get(n.cap).implemented:
            loi.append(f"{n.id}: năng lực `{n.cap}` chưa hiện thực")
        else:
            try:
                registry.validate_input(n.cap, n.args)
            except EideError as e:
                loi.append(f"{n.id}: tham số không khớp input_schema của `{n.cap}` — {e}")
        if n.on_ask not in ON_ASK:
            loi.append(f"{n.id}: on_ask=`{n.on_ask}` không thuộc {list(ON_ASK)}")
        if n.when and n.when not in ids:
            loi.append(f"{n.id}: phụ thuộc nút `{n.when}` không có trong chuỗi")

    if (chu_trinh := tim_chu_trinh(chain)):
        loi.append(f"chuỗi có chu trình: {' → '.join(chu_trinh)}")

    if loi:
        raise EideError("E5002", "Chuỗi không qua được phép kiểm deterministic (DPS-09 §4.4): "
                        + "; ".join(loi), loi=loi, so_loi=len(loi))
    if ngan_sach is not None and chi_phi_uoc > ngan_sach:
        raise EideError("E3003", f"Ước lượng chi phí {chi_phi_uoc:.2f} USD vượt ngân sách "
                        f"{ngan_sach:.2f} USD", uoc=chi_phi_uoc, ngan_sach=ngan_sach)


def tim_chu_trinh(chain: Chain) -> list[str]:
    """Trả về một chu trình nếu có, rỗng nếu không.

    Trả về ĐƯỜNG ĐI chứ không phải True/False: người đọc lỗi cần biết ba nút nào vòng vào nhau,
    không phải biết rằng "có chu trình ở đâu đó trong hai mươi nút".
    """
    cha = {n.id: n.when for n in chain.nodes if n.when}
    for bat_dau in cha:
        tham, cur = [], bat_dau
        while cur in cha:
            if cur in tham:
                return [*tham[tham.index(cur):], cur]
            tham.append(cur)
            cur = cha[cur]
    return []


def thu_tu_chay(chain: Chain) -> list[Nut]:
    """Sắp nút theo phụ thuộc `when` — sắp xếp tô-pô ổn định.

    Ổn định nghĩa là: cùng một chuỗi luôn cho cùng một thứ tự. Một bộ lập lịch chạy hai lần ra
    hai thứ tự khác nhau thì lỗi tái hiện được một lần rồi biến mất, và không ai gỡ được.
    """
    con_lai = list(chain.nodes)
    xong: set[str] = set()
    ra: list[Nut] = []
    while con_lai:
        san = [n for n in con_lai if not n.when or n.when in xong]
        if not san:
            break               # phần còn lại phụ thuộc vòng — `kiem()` đã bắt trước đó
        for n in san:
            ra.append(n)
            xong.add(n.id)
            con_lai.remove(n)
    return ra + con_lai
