"""N0 — chuẩn hoá đầu vào. Spec: AAD-33 §2.1; lược đồ `docs/spec/dialog/utterance.schema.json`.

Bốn bước của bảng §2.1, và bước nào cũng có một lý do cụ thể:

* **Unicode NFC** — cùng một câu gõ trên hai bàn phím ra hai chuỗi byte khác nhau. So chuỗi ở
  S0 (`in CAU_DUNG`) và tra bảng ở DX đều là phép so KHÍT, nên một chữ tổ hợp thay vì dựng sẵn
  làm lệnh dừng không khớp — đúng lúc người gõ vội nhất.
* **Kiểu dấu cũ/mới** (`hoà` ↔ `hòa`) — hai cách đặt dấu thanh đều hợp lệ và người dùng không
  chọn: bàn phím chọn hộ. Không chuẩn hoá thì `"khoá đọc"` khớp luật P-RDP còn `"khóa đọc"` thì
  không, và ngược lại — một cổng an toàn bật theo bàn phím là một cổng không tin được.
* **Bản không dấu** — để regex và từ điển bắt được `"ket noi"`, `"nap firmware"`. KHÔNG bao giờ
  dùng bản này để hiển thị: nó là bản làm việc, không phải lời của người.
* **Tách mệnh đề** — cần cho S1a (tách kênh, Đ4) và cho lệnh nhiều bước (*"đọc X rồi so với Y"*).

`raw` luôn được giữ nguyên để trích dẫn: mọi câu tác tử nói lại với người phải dùng `raw`, vì
đó là thứ người đã gõ. Ba bản còn lại là bản của máy.
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Any

#: Dấu thanh đặt kiểu CŨ → kiểu MỚI. Tiếng Việt có ba nguyên âm đôi mà dấu thanh đặt được ở
#: hai chỗ: `oa`, `oe`, `uy`. Kiểu mới (chuẩn hiện hành) đặt dấu ở nguyên âm THỨ HAI: `hòa`,
#: `khỏe`, `thùy`. Kiểu cũ đặt ở nguyên âm thứ nhất: `hoà`, `khoẻ`, `thuỳ`.
#:
#: Chỉ 15 cặp, và cố ý liệt kê hết thay vì dựng bằng thuật toán: một thuật toán tháo dấu rồi
#: đặt lại sẽ đụng tới `uy` trong `quý` (ở đó `u` là bán âm sau `q`, dấu đặt ở `y` theo cả hai
#: kiểu) và tới `oa` trong `xoong`. Một bảng 15 dòng đọc được bằng mắt thì không có chỗ ẩn.
DAU_CU_MOI: dict[str, str] = {
    "oà": "òa", "oá": "óa", "oả": "ỏa", "oã": "õa", "oạ": "ọa",
    "oè": "òe", "oé": "óe", "oẻ": "ỏe", "oẽ": "õe", "oẹ": "ọe",
    "uỳ": "ùy", "uý": "úy", "uỷ": "ủy", "uỹ": "ũy", "uỵ": "ụy",
}

#: Từ nối mở một mệnh đề MỚI trong cùng một câu. Dấu câu cũng tách, xem `_tach_menh_de`.
#:
#: `và` nằm trong danh sách vì §2.1 nêu nó, nhưng nó là từ nối nguy hiểm nhất: *"TV và USB"* là
#: một liệt kê, không phải hai mệnh đề. Phép tách vì thế đòi hai vế đều đủ dài (xem
#: `TOI_THIEU_TU`) — thà để nguyên một mệnh đề dài còn hơn cắt một danh từ ghép làm đôi và để
#: S1a phân kênh cho một nửa câu.
TU_NOI: tuple[str, ...] = ("rồi sau đó", "sau đó", "rồi", "xong thì", "và")

#: Số từ tối thiểu của mỗi vế để một từ nối được coi là ranh giới mệnh đề.
TOI_THIEU_TU = 3

_KHOANG = re.compile(r"\s+")

#: Dấu câu tách mệnh đề. Dấu CHẤM chỉ tách khi có khoảng trắng (hoặc hết câu) ngay sau — nếu
#: không thì `/docs/ds_v1.pdf` vỡ thành ba mệnh đề và mọi thứ dựng trên mệnh đề (tách kênh ở Đ4,
#: `product_text` của `req.elicit`) nhận một nửa đường dẫn làm một câu. Dấu PHẨY chỉ tách khi
#: sau nó là một từ nối, vì phẩy trong tiếng Việt còn là dấu thập phân (`3,0 V`) và dấu liệt kê.
_DAU_CAU = re.compile(r"[;!?]+|(?<!\d)\.(?=\s|$)|,(?=\s*(?:rồi|sau đó|xong)\b)")


@dataclass(slots=True)
class Utterance:
    """Câu người gõ sau N0. Lược đồ: `docs/spec/dialog/utterance.schema.json`."""

    raw: str
    normalized: str
    no_accent: str
    lang: str                                        # vi | en | mixed
    clauses: list[dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {"raw": self.raw, "normalized": self.normalized, "no_accent": self.no_accent,
                "lang": self.lang, "clauses": self.clauses}


def normalize(text: str) -> Utterance:
    """Câu thô → `Utterance`. Xác định, 0 token, không đọc tệp nào."""
    raw = text if text is not None else ""
    chuan = _KHOANG.sub(" ", _dau_kieu_moi(unicodedata.normalize("NFC", raw))).strip()
    return Utterance(raw=raw, normalized=chuan, no_accent=bo_dau(chuan),
                     lang=_ngon_ngu(chuan), clauses=_tach_menh_de(chuan))


def bo_dau(van: str) -> str:
    """Bản không dấu, chữ thường — để regex và từ điển bắt được câu gõ không dấu.

    Cùng phép biến đổi với `eide_core.request_ops._bo_dau` (S0 dùng bản ấy từ [DEV-200]). Giữ
    hai hàm vì hai lớp dùng hai đường nhập khác nhau và `request_ops` không được phụ thuộc vào
    `eide.*` — nhưng phép biến đổi phải giống nhau từng ký tự, và
    `tests/test_dx.py::test_bo_dau_giong_request_ops` canh chỗ đó.
    """
    t = unicodedata.normalize("NFD", (van or "").replace("đ", "d").replace("Đ", "D").lower())
    return _KHOANG.sub(" ", "".join(c for c in t if unicodedata.category(c) != "Mn")).strip()


def _dau_kieu_moi(van: str) -> str:
    for cu, moi in DAU_CU_MOI.items():
        if cu in van:
            van = van.replace(cu, moi)
        hoa = cu.capitalize()
        if hoa in van:
            van = van.replace(hoa, moi.capitalize())
    return van


#: Từ chỉ dấu cho phép nhận ngôn ngữ. Ngắn có chủ ý: §2.1 chỉ đòi nhận vi/en/hỗn hợp để chọn
#: prompt và để KHÔNG dịch — không đòi một bộ nhận ngôn ngữ tổng quát.
TU_VI = frozenset("""cho toi tôi anh minh mình hay va và roi rồi thi thì la là cua của
    voi với trong ngoai lam làm giup giúp hãy hay xem doc đọc viet viết chay chạy nap nạp
    kiem kiểm khong không co có duoc được nhe nhé di đi""".split())
TU_EN = frozenset("""the and for with please make build read write run flash into from this
    that then create check show help about should must need want use using""".split())


def _ngon_ngu(van: str) -> str:
    """vi | en | mixed. Dấu tiếng Việt là bằng chứng mạnh nhất; sau đó mới đếm từ chỉ dấu."""
    khong_dau = bo_dau(van)
    co_dau = khong_dau != van.lower()
    tu = set(re.findall(r"[a-z]+", khong_dau))
    vi, en = len(tu & TU_VI), len(tu & TU_EN)
    if co_dau or vi > en:
        return "mixed" if en and (co_dau or vi) and en >= max(1, vi) else "vi"
    if en:
        return "en"
    return "vi"


def _tach_menh_de(van: str) -> list[dict[str, Any]]:
    """Mệnh đề đánh số từ 1, giữ nguyên chữ. Câu rỗng → danh sách rỗng."""
    tho = [x.strip(" ,") for x in _DAU_CAU.split(van) if x and x.strip(" ,")]
    ra: list[str] = []
    for phan in tho:
        ra += _tach_theo_tu_noi(phan)
    return [{"id": i, "text": t} for i, t in enumerate(ra, start=1) if t]


def _tach_theo_tu_noi(phan: str) -> list[str]:
    """Tách một câu theo từ nối, chỉ khi HAI vế đều đủ dài (xem `TU_NOI`)."""
    for tu in TU_NOI:
        for m in re.finditer(rf"\s+{re.escape(tu)}\s+", phan, flags=re.IGNORECASE):
            trai, phai = phan[:m.start()].strip(), phan[m.end():].strip()
            if len(trai.split()) >= TOI_THIEU_TU and len(phai.split()) >= TOI_THIEU_TU:
                return [trai, *_tach_theo_tu_noi(phai)]
    return [phan.strip()]
