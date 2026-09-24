"""S0 nhóm STOP và BACKREF — nhận câu ngắn xác định. Spec: AAD-33 §2.3; [DEV-155], [DEV-196].

Hai nhóm luật của bảng §2.3 mà mã đã có từ trước v1.4, chuyển từ `eide.daemon.rpc` sang đây
([DEV-230]) vì ba lý do:

* AAD-33 §2.3 đặt STOP/BACKREF ở lớp L2, không ở cầu giao diện — một lệnh dừng phải nhận được
  kể cả khi lượt đến từ CLI hay từ bộ chạy kịch bản, không chỉ từ daemon;
* DX (§2.2) cần BACKREF để điền `back_refs[]`, và L2 không được nhập từ tầng bridge;
* hai bảng từ khoá là dữ liệu ngôn ngữ, cùng loại với `eide_core.request_ops.DAU_HIEU`.

`eide.daemon.rpc` nhập lại hai hàm này để đường sống và các bài kiểm cũ không đổi.
"""
from __future__ import annotations

import unicodedata

#: Câu người gõ khi muốn CẮT việc đang chạy. So sau khi bỏ dấu câu và hạ chữ thường.
#:
#: Chỉ những câu ĐỨNG MỘT MÌNH — xem `la_cau_dung`. Danh sách cố ý ngắn: mỗi mục thêm vào là
#: một câu có thể bị hiểu nhầm, và một lần dừng nhầm giữa lúc tác tử đang làm đúng cũng là một
#: lần người dùng mất công.
CAU_DUNG = frozenset({
    "dung", "dung khan", "dung ngay", "dung lai", "dung het", "dung tat ca",
    "dung di", "dung het di", "thoi", "thoi dung", "dung tay",
    "stop", "stop ngay", "halt", "abort", "emergency stop",
})

# Câu TRỎ NGƯỢC về lượt trước — [DEV-196]. Hai nhóm, và chúng dẫn tới hai việc khác nhau:
# LÀM LẠI chạy lại từ đầu câu cũ; TIẾP TỤC chỉ gỡ chỗ đang chờ rồi đi tiếp.
CAU_LAM_LAI = frozenset({
    "lam lai", "lam lai di", "chay lai", "chay lai di", "thu lai", "thu lai di",
    "lam lai viec do", "lam lai viec vua roi", "chay lai viec do", "retry", "lam lai lan nua",
})
CAU_TIEP_TUC = frozenset({
    "tiep tuc", "tiep tuc di", "tiep di", "lam tiep", "lam tiep di", "chay tiep",
    "chay tiep di", "continue", "tiep", "di tiep",
})

#: Trần độ dài của một câu ngắn. Xem `la_cau_dung` về việc vì sao có trần.
TRAN_KY_TU = 24


def _chuan(van: str) -> str:
    """Bỏ dấu, hạ chữ thường, gộp khoảng trắng — dùng chung cho mọi phép nhận câu ngắn."""
    t = van.strip().strip(".!?,;:").lower().replace("đ", "d")
    t = unicodedata.normalize("NFD", t).encode("ascii", "ignore").decode()
    return " ".join(t.split())


def la_cau_tro_nguoc(van: str) -> str | None:
    """`"lam_lai"` / `"tiep_tuc"` / `None` — câu này có TRỎ NGƯỢC về lượt trước không.

    ## Vì sao xác định, không nhờ mô hình

    Chủ sản phẩm gặp đúng chuyện này 23/09/2026: một việc hỏng, bảo *"làm lại"*, và tác tử
    **không biết làm lại việc gì**. Nguyên nhân gốc là ngữ cảnh (xem [DEV-196] về C6/C7), nhưng
    kể cả khi mô hình có ngữ cảnh thì vẫn không nên để nó ĐOÁN tham chiếu: đoán sai ở đây nghĩa
    là chạy lại một việc KHÁC việc người đang nói tới — và việc ấy có thể ghi tệp, có thể nạp
    firmware. Sai im lặng, tốn tiền, khó lần.

    Cùng khuôn `la_cau_dung` của [DEV-155] và cùng lý do: câu NGẮN, khớp TRỌN. "làm lại phần
    giao tiếp I2C thôi" là một yêu cầu MỚI có chữ "làm lại" trong đó, không phải lệnh trỏ ngược
    — để `in` bắt nó là biến một câu cụ thể thành một lệnh mơ hồ.
    """
    t = _chuan(van)
    if len(t) > TRAN_KY_TU:
        return None
    if t in CAU_LAM_LAI:
        return "lam_lai"
    if t in CAU_TIEP_TUC:
        return "tiep_tuc"
    return None


def la_cau_dung(van: str) -> bool:
    """Câu này có phải một lệnh DỪNG đứng một mình không.

    Bỏ dấu tiếng Việt trước khi so: người gõ vội hay gõ không dấu, và "dừng" với "dung" phải ra
    cùng một kết quả — đúng lúc họ gõ vội nhất là lúc cần nó chạy nhất.

    Đòi câu NGẮN và khớp TRỌN: "không dừng lại ở đó" hay "dừng khi nào xong thì báo tôi" là câu
    nói về việc dừng, không phải lệnh dừng. So bằng `in` sẽ bắt cả hai, và một lệnh dừng nhầm
    giữa chừng làm hỏng đúng thứ người ta đang chờ.
    """
    t = van.strip().strip(".!?,;:").lower()
    if len(t) > TRAN_KY_TU:
        return False
    return _chuan(t) in CAU_DUNG
