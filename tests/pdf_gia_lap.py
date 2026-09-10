"""Dựng PDF THẬT cho test — dữ liệu kiểm thử dùng chung, không phải một test.

Cùng vai trò với `tests/situations.py`: được import bằng tên chứ không do pytest thu gom.

Vì sao PDF thật chứ không giả lập khối: phần dễ sai nhất của nhóm `extract.pdf_*` nằm đúng ở
chỗ đọc bố cục — số cột, ô rỗng, chữ dính nhau. Giả lập `blocks` rồi kiểm sẽ chỉ chứng minh cái
giả lập đúng.

Tự viết cú pháp PDF thay vì thêm reportlab: cần đúng một trang có chữ và đường kẻ ở toạ độ biết
trước, và một thư viện sinh PDF là một phụ thuộc nữa cho việc mà 40 dòng làm được. Toạ độ PDF
gốc ở góc dưới trái, nên y lớn là ở trên.
"""
from __future__ import annotations

from pathlib import Path


def pdf_tho(p: Path, noi: bytes) -> Path:
    """Bọc một luồng nội dung PDF thành tệp hợp lệ."""
    obj = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(noi)).encode() + b" >>\nstream\n" + noi + b"\nendstream",
    ]
    ra = bytearray(b"%PDF-1.4\n")
    vi = []
    for i, o in enumerate(obj, 1):
        vi.append(len(ra))
        ra += f"{i} 0 obj\n".encode() + o + b"\nendobj\n"
    xref = len(ra)
    ra += f"xref\n0 {len(obj) + 1}\n0000000000 65535 f \n".encode()
    for v in vi:
        ra += f"{v:010d} 00000 n \n".encode()
    ra += (f"trailer\n<< /Size {len(obj) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n"
           .encode())
    p.write_bytes(bytes(ra))
    return p


def _an(chu: str) -> str:
    return chu.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")


def pdf_toi_thieu(p: Path, dong: list[tuple[float, float, str, float]]) -> Path:
    """Một trang chỉ có chữ. `dong` = [(x, y, chữ, cỡ)]."""
    lenh = [f"BT /F1 {co} Tf {x} {y} Td ({_an(chu)}) Tj ET" for x, y, chu, co in dong]
    return pdf_tho(p, "\n".join(lenh).encode("latin-1"))


def pdf_bang_ke(p: Path, bang: list[list[str]], *, tieu_de: str | None = None,
                co: float = 6.0, x0: float = 40.0, x1: float = 580.0,
                y_dau: float = 700.0, cao: float = 16.0) -> Path:
    """Một trang có bảng KẺ KHUNG dựng từ ma trận chuỗi — dạng phổ biến nhất của bảng pinout và
    bảng chức năng thay thế trong datasheet hãng.

    Bảng có khung mới là thứ `find_tables()` nhận ra bằng chiến lược mặc định (đường kẻ). Bảng
    chỉ căn cột bằng khoảng trắng đi qua nhánh dự phòng, và nhánh ấy đã có test riêng ở
    `test_extract_m1.py` — ở đây cần đúng cái mà bảng "Alternate function mapping" thật là.
    """
    n = max(len(h) for h in bang)
    rong = (x1 - x0) / n
    cot = [x0 + i * rong for i in range(n + 1)]
    y = [y_dau - i * cao for i in range(len(bang) + 1)]

    lenh = ["0.5 w"]
    for x in cot:
        lenh.append(f"{x} {y[-1]} m {x} {y[0]} l S")
    for yy in y:
        lenh.append(f"{cot[0]} {yy} m {cot[-1]} {yy} l S")
    for i, hang in enumerate(bang):
        for j, o in enumerate(hang):
            if o:
                lenh.append(f"BT /F1 {co} Tf {cot[j] + 2} {y[i] - cao + 4} Td "
                            f"({_an(str(o))}) Tj ET")
    if tieu_de:
        lenh.append(f"BT /F1 14 Tf {x0} {y_dau + 30} Td ({_an(tieu_de)}) Tj ET")
    return pdf_tho(p, "\n".join(lenh).encode("latin-1"))
