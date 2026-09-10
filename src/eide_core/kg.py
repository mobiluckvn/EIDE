"""Đồ thị tri thức dựng từ store — KAD-07 §6.1 (định danh), §6.3 (cạnh). WI-kg.

Đồ thị ở đây là một **khung nhìn vật chất hóa** của `store.sqlite`, không phải nơi lưu trữ:
store là nguồn sự thật, đồ thị dựng lại được bất cứ lúc nào và được cache theo băm nội dung
store (`content_digest`). Vì thế không có thao tác ghi nào trên đồ thị — muốn đổi tri thức thì
đổi fact, rồi đồ thị dựng lại.

## Vì sao không dùng NetworkX

CDS-12.2 KG-01 bước 1 ghi "NetworkX từ store (M0)". Mọi phép toán mà chín năng lực `kg.*` cần
đều nông: đếm nút/cạnh (KG-01), gom fact cùng subject+predicate (KG-02), lần ngược một hoặc hai
bước (KG-03), và BFS **≤ 2 bước** có trần 500 nút (KG-04). Không phép nào cần đường đi ngắn
nhất, thành phần liên thông, độ trung tâm hay bố cục — tức không dùng gì của NetworkX ngoài một
cuốn từ điển kề. Thêm một phụ thuộc để dùng `dict` của nó thì SAD-03 ADR-16 ("ít phụ thuộc thì
chạy được trên cả ba nền tảng") không còn nghĩa gì. Xem DEVIATIONS DEV-039.

Nếu sau này `view.kg_map` hay `diagram.kg_view` cần thuật toán thật (bố cục, phân cụm), thêm
NetworkX lúc ấy — khi đã có lý do cụ thể chứ không phải vì tài liệu nhắc tên nó một lần.
"""
from __future__ import annotations

import json
import sqlite3
from collections import deque
from dataclasses import dataclass, field
from typing import Any

# KAD-07 §6.3. `ABOUT` KHÔNG có trong bảng ấy và là bổ sung của mã — xem DEVIATIONS DEV-038:
# chín cạnh tài liệu nêu nối Fact với Source, CodeUnit và Fact khác, nhưng không cạnh nào nối
# Fact với chính subject mà nó nói về. Thiếu nó thì "biết gì về periph:I2C1" không trả lời được
# bằng duyệt đồ thị, tức KG-04 mất đúng việc của nó.
CANH = ("HAS", "ABOUT", "CITES", "USES", "SUPERSEDES", "CONFLICTS_WITH", "EVIDENCED_BY")

TRAN_NUT = 500          # KG-04: "giới hạn 500 nút"
SAU_MAC_DINH = 2        # KG-04: "BFS ≤ 2 bước"


def to_tien(iri: str) -> list[str]:
    """Chuỗi tổ tiên của một IRI, gốc trước — KAD-07 §6.1.

    `chip:st.stm32f411ce/periph:I2C1/reg:CR1/field:PE` gồm bốn mức, nên nó sinh ba cạnh HAS.
    Cắt theo `/` chứ không theo `:`: phần sau dấu hai chấm là tên, và tên có thể chứa dấu chấm
    (`st.stm32f411ce`) nhưng không chứa `/`.
    """
    phan = [p for p in iri.split("/") if p]
    return ["/".join(phan[: i + 1]) for i in range(len(phan))]


def loai_nut(nid: str) -> str:
    """Loại của một nút suy từ tiền tố định danh (DDD-14 §2: `f_`, `src_`, `cu_`, `F-`)."""
    for tien, loai in (("f_", "fact"), ("src_", "source"), ("cu_", "code_unit"), ("F-", "feature")):
        if nid.startswith(tien):
            return loai
    return nid.split(":", 1)[0] if ":" in nid else "khac"


@dataclass
class DoThi:
    """Đồ thị vô hướng khi duyệt, có hướng khi đọc cạnh."""

    nut: dict[str, str] = field(default_factory=dict)                 # id → loại
    canh: list[tuple[str, str, str]] = field(default_factory=list)    # (nguồn, loại, đích)
    ke: dict[str, list[tuple[str, str, str]]] = field(default_factory=dict)
    digest: str = ""

    def them_nut(self, nid: str, loai: str | None = None) -> None:
        if nid and nid not in self.nut:
            self.nut[nid] = loai or loai_nut(nid)

    def them_canh(self, a: str, loai: str, b: str) -> None:
        if not a or not b:
            return
        self.them_nut(a)
        self.them_nut(b)
        self.canh.append((a, loai, b))
        # Kề hai chiều: KG-04 hỏi "lân cận", và một fact nói về I2C1 là lân cận của I2C1 bất kể
        # cạnh được lưu theo chiều nào. Chiều gốc vẫn giữ trong phần tử thứ ba để đọc lại được.
        self.ke.setdefault(a, []).append((loai, b, "ra"))
        self.ke.setdefault(b, []).append((loai, a, "vao"))

    def lan_can(self, nut: str, sau: int = SAU_MAC_DINH,
                tran: int = TRAN_NUT) -> dict[str, Any]:
        """BFS theo bước, dừng ở `sau` bước hoặc `tran` nút — KG-04.

        Cắt theo TỪNG BƯỚC chứ không cắt giữa một bước: dừng giữa chừng cho ra một tập lân cận
        phụ thuộc thứ tự duyệt, nên cùng một câu hỏi hai lần chạy có thể ra hai kết quả khác
        nhau. Thà trả về đủ vòng cuối cùng còn vừa trần, và ghi `cat: true` để bên gọi biết.
        """
        if nut not in self.nut:
            return {"nodes": [], "edges": [], "cat": False, "sau": sau}
        tham = {nut: 0}
        hang: deque[str] = deque([nut])
        cat = False
        while hang:
            cur = hang.popleft()
            d = tham[cur]
            if d >= sau:
                continue
            vong = [b for _, b, _ in self.ke.get(cur, []) if b not in tham]
            if len(tham) + len(set(vong)) > tran:
                cat = True
                break
            for b in vong:
                if b not in tham:
                    tham[b] = d + 1
                    hang.append(b)
        canh = [(a, k, b) for a, k, b in self.canh if a in tham and b in tham]
        return {"nodes": [{"id": n, "kind": self.nut[n], "buoc": d} for n, d in sorted(tham.items())],
                "edges": [{"from": a, "kind": k, "to": b} for a, k, b in canh],
                "cat": cat, "sau": sau}


def _json_list(x: Any) -> list[str]:
    if not x:
        return []
    if isinstance(x, str):
        try:
            x = json.loads(x)
        except json.JSONDecodeError:
            return []
    return [str(i) for i in x] if isinstance(x, list) else []


def dung(conn: sqlite3.Connection, digest: str = "") -> DoThi:
    """Dựng đồ thị từ store — KAD-07 §6.3.

    Chỉ đọc fact `status` hiện hành: fact đã bị thay (`superseded`) vẫn ở lại store để truy
    nguyên, nhưng đưa chúng vào đồ thị thì `kg.conflicts` sẽ báo mâu thuẫn giữa một fact và
    chính bản cũ của nó — mâu thuẫn giả, và là loại làm người ta ngừng đọc cảnh báo.

    **Cạnh `CONFLICTS_WITH` đến từ hai đường** (DDD-14 §2 v1.4, DEV-077). Đường SUY —
    `mau_thuan()` ghép fact cùng (subject, predicate) khác giá trị — bắt loại mâu thuẫn không ai
    nhận ra. Đường KHAI — cột `fact.conflicts_with` — bắt loại mà chỉ người đọc tài liệu mới
    biết: errata phủ định datasheet có subject và predicate khác hẳn fact nó phủ định, nên phép
    suy mù trước nó.
    """
    g = DoThi(digest=digest)
    facts = conn.execute(
        "SELECT id, subject, predicate, value, source_id, supersedes, tier, status,"
        " conflicts_with FROM fact"
    ).fetchall()
    hien_hanh = [r for r in facts if (r[7] or "current") not in ("superseded", "rejected")]

    for fid, subject, _pred, _val, source_id, supersedes, _tier, _st, _cw in hien_hanh:
        g.them_nut(fid, "fact")
        # HAS: chuỗi tổ tiên của subject
        chuoi = to_tien(subject)
        for cha, con in zip(chuoi, chuoi[1:], strict=False):
            g.them_canh(cha, "HAS", con)
        if chuoi:
            g.them_nut(chuoi[-1])
            g.them_canh(fid, "ABOUT", chuoi[-1])
        if source_id:
            g.them_canh(fid, "CITES", source_id)
        if supersedes:
            g.them_canh(fid, "SUPERSEDES", supersedes)

    for cid, cites, uses in conn.execute("SELECT id, cites, uses FROM code_unit").fetchall():
        g.them_nut(cid, "code_unit")
        for f in _json_list(cites):
            g.them_canh(cid, "CITES", f)
        for iri in _json_list(uses):
            chuoi = to_tien(iri)
            for cha, con in zip(chuoi, chuoi[1:], strict=False):
                g.them_canh(cha, "HAS", con)
            g.them_canh(cid, "USES", iri)

    for fid, evidence in conn.execute("SELECT id, evidence FROM feature").fetchall():
        g.them_nut(fid, "feature")
        for e in _json_list(evidence):
            g.them_canh(fid, "EVIDENCED_BY", e)

    for a, b in mau_thuan(hien_hanh):
        g.them_canh(a, "CONFLICTS_WITH", b)

    # Đường KHAI. Chỉ nối tới fact CÓ THẬT và đang hiện hành: một cạnh trỏ vào id không tồn tại
    # (hoặc vào bản đã bị thay) làm `kg.conflicts` báo một xung đột không tra được — tệ hơn hẳn
    # việc thiếu cạnh, vì người ta phải đi tìm một thứ không có ở đâu cả.
    co_that = {r[0] for r in hien_hanh}
    for fid, *_rest in hien_hanh:
        for b in _json_list(_rest[7]):
            if b in co_that and b != fid:
                g.them_canh(fid, "CONFLICTS_WITH", b)
    return g


def mau_thuan(rows: list[tuple]) -> list[tuple[str, str]]:
    """Cặp fact CÙNG subject + predicate nhưng KHÁC giá trị — KAD-07 §6.3, POL-17 G-FACT-04.

    So `value` dạng chuẩn tắc chứ không so chuỗi thô: `{"a":1,"b":2}` và `{"b":2,"a":1}` là cùng
    một giá trị, và báo chúng mâu thuẫn là báo động giả ngay ở lần trích xuất thứ hai của cùng
    một tài liệu.
    """
    nhom: dict[tuple[str, str], list[tuple[str, str]]] = {}
    for fid, subject, pred, value, *_ in rows:
        try:
            chuan = json.dumps(json.loads(value) if isinstance(value, str) else value,
                               sort_keys=True, ensure_ascii=False)
        except (json.JSONDecodeError, TypeError):
            chuan = str(value)
        nhom.setdefault((subject, pred), []).append((fid, chuan))
    ra: list[tuple[str, str]] = []
    for muc in nhom.values():
        for i in range(len(muc)):
            for j in range(i + 1, len(muc)):
                if muc[i][1] != muc[j][1]:
                    ra.append((muc[i][0], muc[j][0]))
    return ra
