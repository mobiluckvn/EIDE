"""Sinh `docs/spec/ui/man_can_hien.json` — HỢP ĐỒNG NỘI DUNG của từng màn.

Nguồn: cột "DỮ LIỆU PHẢI HIỆN" trong `docs/EIDE-VUNG-MAN-HINH.xlsx`, bản chủ sản phẩm đã duyệt
22/09/2026.

## Vì sao phải sinh ra một tệp máy đọc được

Chủ sản phẩm dặn: *"cần kiểm soát để không sai và không thiếu"*. Một danh sách nằm trong file
Excel là lời hứa; một danh sách máy đọc được, có bộ dò mở cửa sổ thật ra so, mới là phép đo.

Bộ dò `EideApp --do-noi-dung` đọc tệp này, mở từng màn trên một dự án CÓ DỮ LIỆU THẬT, rồi so
`dau_hieu` với chữ hiển thị trong cây khung nhìn. Thiếu thì `exit 1`.

## `dau_hieu` là gì, và vì sao không dùng nguyên văn dòng mô tả

Dòng trong Excel viết cho người đọc ("Tính năng: n passing / n tổng, cái đang làm dở"). Máy
không so được câu ấy. `dau_hieu` là các mẩu chữ NGẮN, ổn định, mà màn buộc phải in ra nếu nó
thật sự hiện mục ấy — nhãn cột, tiêu đề khối, đơn vị. Chọn mẩu nào là một quyết định, nên nó
nằm ở `DAU_HIEU` bên dưới để sửa được, không suy tự động từ câu tiếng Việt.

Mục CHƯA có `dau_hieu` vẫn vào tệp với `dau_hieu: []` và `do_duoc: false` — bộ dò bỏ qua nhưng
ĐẾM chúng và in ra. Một mục không đo được mà im lặng biến mất khỏi báo cáo là đúng thứ khiến
"xanh" mất nghĩa.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from openpyxl import load_workbook

GOC = Path(__file__).resolve().parent.parent
XLSX = GOC / "docs" / "EIDE-VUNG-MAN-HINH.xlsx"
RA = GOC / "docs" / "spec" / "ui" / "man_can_hien.json"

# Mã màn (cột "Mã", dạng S<n>) → tiền tố dùng trong mã Swift.
THEO_SO = {
    "S2": "Main", "S4": "Ingest", "S5": "Passport", "S6": "Board", "S7": "Graph",
    "S8": "NhatKy", "S9": "XungDot", "S10": "LamRo", "S11": "ReqArch", "S12": "DiagramView",
    "S13": "Doc", "S14": "PlanDiff", "S15": "Code", "S16": "Sim", "S17": "Discovery",
    "S18": "LogAssist", "S19": "Debug", "S20": "ToolForge", "S21": "Bench", "S22": "Registry",
    "S23": "Models", "S24": "Env", "S25": "FlowMap", "S26": "DiffMerge", "S27": "ChinhSach",
}

# Mẩu chữ ổn định cho từng mục. Khoá = (tiền tố màn, 12 ký tự đầu của dòng mô tả đã chuẩn hoá).
# Giá trị = các mẩu chữ; màn PHẢI in ra ÍT NHẤT MỘT mẩu thì mới tính là đã hiện mục ấy.
#
# Dùng "ít nhất một" chứ không "tất cả": một khối có thể diễn đạt vài cách (bảng hay câu), và
# bắt khớp hết mọi mẩu sẽ biến bộ dò thành phép so giao diện từng pixel — thứ đỏ mỗi lần đổi
# chữ và vì thế bị tắt đi.
DAU_HIEU: dict[tuple[str, str], list[str]] = {
    ("Main", "tính năng:"): ["passing"],
    ("Main", "đang chờ tô"): ["Đang chờ", "chờ tôi"],
    ("Main", "hoàn tác đư"): ["Hoàn tác"],
    ("Main", "chip/board"): ["Chip", "ISA"],
    ("Main", "chi phí mô"): ["Chi phí", "USD"],
    ("NhatKy", "thời điểm ·"): ["Năng lực", "Kết quả"],
    ("NhatKy", "lọc: chỉ vi"): ["Lọc", "Chỉ lỗi"],
    ("FlowMap", "bản đồ p0–"): ["P0", "P7"],
    ("FlowMap", "mỗi bước: c"): ["Cổng"],
    ("Ingest", "danh mục ng"): ["NGUỒN", "Tầng"],
    ("Passport", "bộ nhớ (fla"): ["FLASH", "RAM"],
    ("Passport", "mỗi con số"): ["Nguồn", "Tầng"],
    ("Passport", "số fact chư"): ["chưa duyệt"],
    ("Board", "bảng net/pi"): ["Net", "Pin"],
    ("Board", "xung đột ch"): ["Xung đột"],
    ("Graph", "ô hỏi + câu"): ["Hỏi"],
    ("XungDot", "hai bên đặt"): ["Nguồn", "Tầng"],
    ("LamRo", "từng câu hỏ"): ["Câu hỏi", "Bước"],
    ("LamRo", "ô trả lời n"): ["Trả lời"],
    ("ReqArch", "reqset: mã"): ["Mã", "Ưu tiên"],
    ("ReqArch", "ma trận tru"): ["truy vết"],
    ("DiagramView", "hình + mã n"): ["Lược đồ"],
    ("DiagramView", "cờ lệch khi"): ["LỆCH"],
    ("PlanDiff", "khối còn th"): ["CÒN THIẾU"],
    ("PlanDiff", "từng bước:"): ["Bước", "Năng lực"],
    ("PlanDiff", "quyết định"): ["Cổng", "G1"],
    ("Doc", "danh sách t"): ["Tài liệu"],
    ("Code", "cây tệp + n"): ["Tệp"],
    ("DiffMerge", "g1/g3/g4/g5"): ["G3", "G5"],
    ("Sim", "nền tảng mô"): ["engine", "FLASH"],
    ("Sim", "kịch bản +"): ["Kịch bản"],
    ("Env", "từng công c"): ["Công cụ", "Phiên bản"],
    ("Models", "vai trò → m"): ["Vai trò"],
    ("Models", "chi phí hôm"): ["Chi phí", "USD"],
    ("ToolForge", "danh sách c"): ["Công cụ"],
    ("Registry", "gói có sẵn"): ["Gói"],
    ("ChinhSach", "mức tự chủ"): ["Tự chủ", "A2"],
    ("ChinhSach", "bảng quy tắ"): ["Quy tắc"],
    # ---- 39 mục còn lại, bổ sung để KHÔNG mục nào lọt lưới. Một bảng tra bỏ sót một nửa thì
    # bộ dò xanh cho những màn nó chưa hề nhìn tới.
    ("FlowMap", "bước đang b"): ["CÁCH GỠ", "đang chặn"],
    ("Main", "3 việc tác"): ["vừa làm xong", "Vừa xong"],
    ("NhatKy", "mỗi dòng nó"): ["Việc"],
    ("Board", "board đã đá"): ["lab"],
    ("Graph", "bản đồ lân"): ["lân cận"],
    ("Graph", "đường truy"): ["truy nguồn", "trang"],
    ("Ingest", "lượt nhập g"): ["Lượt nhập"],
    ("Ingest", "tài liệu tá"): ["tự tải", "Giấy phép"],
    ("Passport", "phiên bản h"): ["@", "đã ghim"],
    ("XungDot", "vì sao máy"): ["suy ra", "được khai"],
    ("XungDot", "hệ quả: mã"): ["Hệ quả", "đang dùng"],
    ("DiagramView", "lược đồ nào"): ["Dùng trong", "Tài liệu"],
    ("Doc", "xem trước n"): ["style"],
    ("Doc", "lược đồ đã"): ["Lược đồ"],
    ("LamRo", "câu đã trả"): ["Đã trả lời"],
    ("PlanDiff", "ước lượng c"): ["Ước", "USD"],
    ("ReqArch", "yêu cầu khô"): ["không đo được"],
    ("ReqArch", "adr: quyết"): ["ADR"],
    ("Code", "vi phạm con"): ["constant-guard", "Vi phạm"],
    # Dấu hiệu là NHÃN KHỐI, không phải GIÁ TRỊ dữ liệu. [DEV-193] "tác tử viết" chỉ xuất hiện
    # khi sổ cái có bản ghi mang đường dẫn tệp; trên một dự án chưa có bản ghi nào thì cả cột
    # in "chưa rõ ai" — đúng, và mục vẫn bị báo thiếu. Nhãn cột thì có mặt ở cả ba trạng thái.
    ("Code", "tệp nào do"): ["AI VIẾT"],
    ("DiffMerge", "diff hai cộ"): ["Diff"],
    ("DiffMerge", "kết quả 4 c"): ["reviewer", "Công cụ"],
    ("Bench", "bài cf/bf/b"): ["CF", "BC"],
    ("Bench", "huy hiệu đạ"): ["Huy hiệu"],
    ("Debug", "giả thuyết"): ["Giả thuyết"],
    ("Debug", "evidencepac"): ["EvidencePack", "Bằng chứng"],
    ("Debug", "thí nghiệm"): ["Thí nghiệm"],
    ("Discovery", "cổng/probe"): ["Cổng", "probe"],
    ("Discovery", "đối chiếu v"): ["KHỚP", "LỆCH"],
    ("Discovery", "bus quét đư"): ["Bus"],
    ("LogAssist", "log có lọc"): ["Lọc", "serial"],
    ("LogAssist", "hỏi tại dòn"): ["Hỏi tại dòng"],
    ("Sim", "ngoại vi nà"): ["Ngoại vi", "unsupported"],
    ("ChinhSach", "trạng thái"): ["Niêm"],
    ("Env", "isa của dự"): ["ISA"],
    ("Env", "lệnh cài ch"): ["brew", "Lệnh cài"],
    ("Models", "lượt gọi gầ"): ["token"],
    ("Registry", "chữ ký + gi"): ["Chữ ký", "Giấy phép"],
    ("ToolForge", "mã công cụ"): ["test"],
}


def _chuan(s: str) -> str:
    return re.sub(r"^[•\s]+", "", s).strip().lower()


def _dau_hieu(tien: str, dong: str) -> list[str]:
    """Khớp theo TIỀN TỐ, không theo độ dài cố định.

    Bản đầu cắt 12 ký tự rồi so bằng, còn khoá trong `DAU_HIEU` viết tay dài ngắn khác nhau —
    0/77 mục khớp. Một bảng tra mà không tra được gì thì bộ dò xanh vì rỗng, đúng kiểu "xanh"
    vô nghĩa mà cả cơ chế này sinh ra để chặn.
    """
    c = _chuan(dong)
    for (t, dau), dh in DAU_HIEU.items():
        if t == tien and c.startswith(dau):
            return dh
    return []


def main() -> int:
    if not XLSX.exists():
        print(f"chưa có {XLSX} — chạy scripts/bang_vung_man_hinh.py trước")
        return 2
    ws = load_workbook(XLSX)["Vùng màn hình"]
    cot = {c.value: i for i, c in enumerate(ws[1])}
    ra, tong, do_duoc = {}, 0, 0
    for r in ws.iter_rows(min_row=2, values_only=True):
        ma = r[cot["Mã"]]
        tien = THEO_SO.get(ma)
        if not tien:
            continue
        muc = []
        for dong in str(r[cot["DỮ LIỆU PHẢI HIỆN"]] or "").splitlines():
            if not dong.strip():
                continue
            dh = _dau_hieu(tien, dong)
            muc.append({"mo_ta": re.sub(r"^[•\s]+", "", dong).strip(),
                        "dau_hieu": dh, "do_duoc": bool(dh)})
            tong += 1
            do_duoc += bool(dh)
        ra[tien] = {"ma": ma, "ten": r[cot["Màn"]], "muc": muc}
    van = json.dumps(ra, ensure_ascii=False, indent=1) + "\n"
    tom = (f"{len(ra)} màn, {tong} mục, {do_duoc} đo được, {tong - do_duoc} CHƯA có dấu hiệu")

    # `--kiem`: bản sinh còn khớp nguồn không — cùng khuôn với mọi bộ sinh khác trong
    # `make check-gen`. Không có cổng này thì một lần sửa Excel sống sót im lặng cho tới lần
    # sinh kế tiếp, và cổng nội dung đo theo một bảng đã cũ.
    if "--kiem" in sys.argv:
        if not RA.exists():
            print(f"✗ {RA.name} CHƯA CÓ trong kho — chạy scripts/gen_man_can_hien.py")
            return 1
        if RA.read_text(encoding="utf-8") != van:
            print(f"✗ {RA.name} LỆCH khỏi {XLSX.name} — chạy lại không có `--kiem`")
            return 1
        print(f"✓ {RA.name} khớp {XLSX.name} ({tom})")
        return 0

    RA.parent.mkdir(parents=True, exist_ok=True)
    RA.write_text(van, encoding="utf-8")
    print(f"đã sinh {RA} — {tom}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
