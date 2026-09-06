"""Khôi phục `docs/ho-so/nguon/dialog.json` từ EIDE-DPS-09 docx — DEVIATIONS DEV-019.

`dps.js` mở đầu bằng `require('./dialog.json')` nhưng tệp ấy không có trong kho, nên DPS-09 chưa
từng sinh lại được — mọi mục DEVIATIONS chạm DPS-09 vì thế nằm `Mở` vĩnh viễn. Chủ sản phẩm xác
nhận 06/09/2026 rằng tệp gốc đã mất, và duyệt phương án dựng lại từ chính docx.

Đây là đường đi NGƯỢC (sản phẩm → nguồn), chỉ hợp lệ vì nguồn đã mất. Phép thử duy nhất cho biết
bản khôi phục có đúng hay không là **sinh lại docx rồi so với bản gốc**: kịch bản này chỉ ghi tệp
sau khi vòng đối chiếu ấy đạt (xem `--kiem` trong `scripts/sinh_tai_lieu.sh`).

Ba khóa, hình dạng suy từ chỗ dùng trong dps.js:
    WHERE      [Nội dung, Nơi mô tả, Lý do]                      — bảng docx [2]
    RULES      [Mã, Quy tắc, Nội dung, Vì sao]  D1–D8            — bảng docx [4]
    SCENARIOS  [id, tiêu đề, kiểm gì, kết quả, làm/hỏi, câu hỏi mẫu, mặc định, UC]
               id và tiêu đề lấy từ tiêu đề H2 `Z-01 — …` phía trên mỗi bảng [7]–[16]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

sys.path.insert(0, str(Path(__file__).parent))
from rut_bang_docx import W, _bo_dam_tu_dong, bang, doan_text  # noqa: E402

DOCX = Path("docs/ho-so/EIDE-DPS-09_Chinh_sach_hoi_thoai.docx")
RA = Path("docs/ho-so/nguon/dialog.json")

# Bảy dòng của bảng kịch bản, theo đúng thứ tự dps.js dựng ra (§5).
MUC_KICH_BAN = ["Tác tử kiểm tra gì (D1)", "Kết quả kiểm tra", "Tác tử làm / hỏi gì",
                "Câu hỏi mẫu", "Mặc định / timeout", "UC / năng lực"]


def _than(docx: Path) -> ET.Element:
    return ET.fromstring(zipfile.ZipFile(docx).read("word/document.xml")).find(f"{W}body")


def _tieu_de_kich_ban(than: ET.Element) -> list[tuple[str, str]]:
    """Đoạn dạng `Z-01 — Tiêu đề` đứng trước mỗi bảng kịch bản."""
    ra = []
    for p in than.iter(f"{W}p"):
        # H2 cũng tự in đậm cả dòng, nên chuỗi rút ra là `**Z-01 — …**`; bóc lớp ấy trước.
        t = _bo_dam_tu_dong(doan_text(p).strip())
        m = re.match(r"^(Z-\d{2})\s+—\s+(.+)$", t)
        if m:
            ra.append((m.group(1), m.group(2)))
    return ra


def _kiem_dang(b: list[list], cot: int, dau: list[str], ten: str) -> None:
    """Bảng phải đúng số cột và đúng tiêu đề — chọn nhầm bảng thì hỏng âm thầm."""
    if len(b[0]) != cot or [str(x) for x in b[0]] != dau:
        raise SystemExit(f"✗ {ten}: tiêu đề bảng là {b[0]!r}, chờ {dau!r}")


def dung() -> dict:
    than = _than(DOCX)
    bs = [bang(t) for t in than.iter(f"{W}tbl")]

    _kiem_dang(bs[2], 3, ["Nội dung", "Nơi mô tả", "Lý do"], "WHERE")
    _kiem_dang(bs[4], 4, ["Mã", "Quy tắc", "Nội dung", "Vì sao"], "RULES")

    where = [r for r in bs[2][1:]]
    rules = [r for r in bs[4][1:]]
    if [r[0] for r in rules] != [f"D{i}" for i in range(1, 9)]:
        raise SystemExit(f"✗ RULES: mã quy tắc là {[r[0] for r in rules]}, chờ D1…D8")

    tieu_de = _tieu_de_kich_ban(than)
    if len(tieu_de) != 10:
        raise SystemExit(f"✗ tìm được {len(tieu_de)} tiêu đề Z-xx, chờ 10")

    scen = []
    for k, (zid, ten) in enumerate(tieu_de):
        b = bs[7 + k]
        _kiem_dang(b, 2, ["Mục", "Nội dung"], f"kịch bản {zid}")
        if [r[0] for r in b[1:]] != MUC_KICH_BAN:
            raise SystemExit(f"✗ {zid}: các mục là {[r[0] for r in b[1:]]}")
        scen.append([zid, ten, *[r[1] for r in b[1:]]])

    return {"WHERE": where, "RULES": rules, "SCENARIOS": scen}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ghi", action="store_true", help="ghi docs/ho-so/nguon/dialog.json")
    a = ap.parse_args(argv)
    d = dung()
    print(f"WHERE {len(d['WHERE'])} dòng · RULES {len(d['RULES'])} dòng · "
          f"SCENARIOS {len(d['SCENARIOS'])} kịch bản ({d['SCENARIOS'][0][0]}…{d['SCENARIOS'][-1][0]})")
    if a.ghi:
        RA.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"đã ghi {RA}")
    else:
        json.dump(d, sys.stdout, ensure_ascii=False, indent=1)
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
