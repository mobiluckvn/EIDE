"""Nhận ra THAO TÁC NGUY HIỂM mà câu của người dùng gọi tên — trước khi mô hình phân loại.

## Vì sao phải có lớp này [BB3]

POL-17 §2 đã có quy tắc đúng cho thao tác không đảo ngược::

    G-OPS-02  gate=G-OPS  ASK  priority=1
      when: op in ["erase_all", "fuse", "option_bytes", "readout_protect"]

Quy tắc ấy viết đúng, có bài kiểm riêng, và **chưa một lần nào chạy trong sản phẩm**. Đo
23/09/2026: chuỗi ``op`` chỉ xuất hiện trong ``tests/``; không một đường nào ở ``src/`` cấp đặc
trưng ``op`` cho cổng. DEV-012 từng lo đúng chuyện này — *"G-OPS-02 không còn là quy tắc chết"*
— nhưng lo ở tầng dưới, tầng PolicyGate chọn mã lý do. Nó chết ở tầng trên: **không ai gọi**.

Bộ kiểm thử usecase cho thấy hậu quả. Người dùng gõ *"Ghi option bytes bật khoá đọc RDP mức 2"*
— thao tác khoá chip **vĩnh viễn** — và tác tử xử lý y hệt một lệnh nạp firmware thường: bảng
19 ý định không có giá trị nào diễn đạt được việc ấy, nên nó rơi vào ``target.flash`` (R3), và
cổng R3 duyệt đúng theo luật của nó. Không ai viết sai một dòng. Ba tầng an toàn — lớp rủi ro
R4, tier T3, quy tắc G-OPS-02 — đều đúng và đều bị đi vòng qua, vì **mọi bảo đảm của EIDE gắn
vào NĂNG LỰC, còn việc chọn đúng năng lực thì không có bảo đảm nào**.

## Vì sao đặt TRƯỚC `chat.parse_intent`

Cùng lý lẽ với DEV-196 (`la_cau_tro_nguoc`): để mô hình phân loại thì tốt nhất nó trả về một ý
định sai vô hại, tệ nhất nó ĐOÁN ra một việc khác rồi chạy. Một phép tra bảng xác định cho câu
trả lời chắc chắn và không tốn token — và với thao tác không đảo ngược, "chắc chắn" là điều kiện
tối thiểu.

Đây là **phòng thủ lớp hai**: nó vẫn nổ kể cả khi định tuyến sai, vì nó không đọc ý định mà đọc
chính câu người dùng gõ.

## Ranh giới: cái gì của đặc tả, cái gì của mã

Tên thao tác (``erase_all``, ``fuse``, ``option_bytes``, ``readout_protect``) **đọc ra từ
`policy/rules.yaml`**, không chép tay — thêm một thao tác vào quy tắc là bộ nhận diện thấy ngay,
và không có bản sao thứ hai để lệch.

Phần mã tự mang là *cách người Việt gọi những thao tác ấy*. Đó là tri thức về ngôn ngữ, không
phải về chính sách, nên nó nằm ở mã; và vì nó do người viết đặt ra chứ không có trong tài liệu
nào, nó được ghi vào DEVIATIONS.
"""

from __future__ import annotations

import re
import unicodedata
from functools import lru_cache
from pathlib import Path
from typing import Any

#: Chỉ xét quy tắc trong DẢI CHẶN. POL-17 §2: ưu tiên ≤ 5 là dải "chặn thật"; quy tắc ưu tiên
#: lớn hơn là lời khuyên chung, và mượn nó để chặn một câu là nói to lên mức nghiêm trọng.
UU_TIEN_CHAN = 5

#: Cách gọi những thao tác ấy bằng tiếng Việt và tiếng Anh, đã bỏ dấu.
#:
#: Viết ở dạng KHÔNG DẤU vì `_bo_dau` chuẩn hoá cả hai vế trước khi so — nếu không thì "xoá"
#: và "xóa" là hai chuỗi khác nhau, và người dùng gõ kiểu nào cũng đúng.
DAU_HIEU: dict[str, tuple[str, ...]] = {
    "erase_all": ("xoa toan bo flash", "xoa sach flash", "xoa het flash", "xoa toan bo chip",
                  "mass erase", "erase all", "chip erase", "xoa trang chip"),
    "fuse": ("ghi fuse", "dot fuse", "fuse bit", "efuse", "burn fuse", "set fuse"),
    "option_bytes": ("option byte", "ghi option", "write option"),
    "readout_protect": ("rdp", "khoa doc", "readout protect", "read protection",
                        "readout protection", "khoa bao ve doc"),
}


def _bo_dau(s: str) -> str:
    """Chuẩn hoá để so: thường hoá, bỏ dấu tiếng Việt, gộp khoảng trắng."""
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", s.replace("đ", "d")).strip()


@lru_cache(maxsize=1)
def _op_bi_chan(duong: str) -> frozenset[str]:
    """Tên thao tác mà một quy tắc trong dải chặn KẾT TỘI TỰ THÂN THAO TÁC.

    Đọc từ đặc tả thay vì chép tay: quy tắc là nguồn sự thật, và một bản sao trong mã là một
    chỗ sẽ lệch lặng lẽ khi quy tắc đổi.

    **Chỉ nhận quy tắc mà điều kiện CHỈ nói về `op`.** Phân biệt này là bắt buộc, và tôi phát
    hiện ra nó bằng cách chạy bài kiểm chứ không bằng cách đọc::

        G-OPS-02  op in ["erase_all", "fuse", "option_bytes", "readout_protect"]
        G-OPS-03  op == "actuator" or board.has_actuator and op in ["flash", "experiment"]

    Bản đầu gom cả hai, nên `flash` và `experiment` lọt vào danh sách "không đảo ngược". Nhưng
    G-OPS-03 chặn chúng **chỉ khi board có cơ cấu chấp hành** — một điều kiện về hoàn cảnh, chứ
    không phải về bản chất thao tác. Gom chúng vào đây là chặn mọi câu có chữ "nạp firmware",
    tức là dựng ra một cảnh báo bật sai gần như mọi lần — và một cảnh báo như thế thì người ta
    bấm qua mà không đọc ([DEV-198] đã đo được đúng điều đó với luật tên gần giống).
    """
    import yaml

    d = yaml.safe_load(Path(duong).read_text(encoding="utf-8")) or {}
    ra: set[str] = set()
    for r in d.get("rules") or []:
        if int(r.get("priority") or 99) > UU_TIEN_CHAN:
            continue
        khi = str(r.get("when") or "")
        tim: set[str] = set()
        con = khi
        for m in re.finditer(r"\bop\s+in\s+\[([^\]]*)\]", khi):
            tim |= {x.strip().strip("\"'") for x in m.group(1).split(",") if x.strip()}
            con = con.replace(m.group(0), "")
        for m in re.finditer(r"\bop\s*==\s*[\"']([^\"']+)[\"']", khi):
            tim.add(m.group(1))
            con = con.replace(m.group(0), "")
        # Bỏ hết mệnh đề về `op` rồi mà còn sót điều kiện nào thì quy tắc ấy nói về HOÀN CẢNH,
        # không phải về thao tác — không phải việc của bộ nhận diện này.
        if tim and not re.sub(r"\b(and|or|not)\b|\s+|\(|\)", "", con):
            ra |= tim
    return frozenset(ra)


def thao_tac_trong_cau(van: str, rules_yaml: Path | str) -> list[str]:
    """Những thao tác bị chặn mà câu này gọi đích danh, theo thứ tự xuất hiện.

    Chỉ trả về thao tác VỪA có trong dải chặn của `rules.yaml` VỪA có dấu hiệu ngôn ngữ ở đây.
    Một thao tác có dấu hiệu nhưng không quy tắc nào chặn thì không phải việc của hàm này —
    quyết định là của chính sách, không của bộ nhận diện.
    """
    bi_chan = _op_bi_chan(str(rules_yaml))
    v = _bo_dau(van)
    thay: list[tuple[int, str]] = []
    for op, ds in DAU_HIEU.items():
        if op not in bi_chan:
            continue
        vi = min((v.find(_bo_dau(d)) for d in ds if _bo_dau(d) in v), default=-1)
        if vi >= 0:
            thay.append((vi, op))
    return [op for _, op in sorted(thay)]


def mo_ta_hau_qua(op: str) -> str:
    """Nói HẬU QUẢ bằng tiếng người, không bằng tên thao tác.

    POL-17 §2 quyết định *có hỏi hay không*; nó không nói *hỏi thế nào*. Một câu hỏi xác nhận
    chỉ có nghĩa nếu người đọc hiểu mình đang đồng ý với điều gì — "op = readout_protect" thì
    không ai hiểu, "chip sẽ bị khoá vĩnh viễn, không đọc lại được" thì ai cũng hiểu.
    """
    return {
        "erase_all": "xoá sạch toàn bộ Flash của chip — mọi firmware và dữ liệu trên đó mất, "
                     "không khôi phục được",
        "fuse": "ghi fuse bit — phần lớn fuse chỉ ghi được MỘT LẦN, ghi sai là hỏng vĩnh viễn",
        "option_bytes": "ghi option bytes — đổi cấu hình khởi động và bảo vệ ở mức nạp lại "
                        "cũng không sửa được",
        "readout_protect": "bật khoá đọc (RDP) — ở mức cao nhất thì chip KHÔNG BAO GIỜ đọc "
                           "hay gỡ lỗi lại được, kể cả bằng bộ nạp",
    }.get(op, f"thao tác `{op}` không đảo ngược được")


def nang_luc_cho(op: str, registry: Any) -> tuple[str, bool]:
    """Năng lực làm việc ấy, và nó đã được hiện thực chưa.

    Trả về cả hai vì hai câu trả lời khác hẳn nhau với người dùng: *"tôi sẽ làm sau khi anh xác
    nhận"* và *"bản này chưa làm được việc ấy"*. Đo 23/09/2026: không một năng lực `target.*`
    ghi nào được hiện thực, nên câu thứ hai mới là câu đúng — và nói câu thứ nhất sẽ là hứa một
    việc không có thật.
    """
    ten = "target.erase_fuse"
    try:
        return ten, bool(registry.get(ten).implemented)
    except Exception:                                            # noqa: BLE001
        return ten, False
