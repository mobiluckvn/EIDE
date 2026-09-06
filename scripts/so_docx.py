"""So hai tệp .docx theo NỘI DUNG, không theo byte.

    python scripts/so_docx.py <a.docx> <b.docx> [--im]

Vì sao cần: docx là tệp zip, mỗi mục có dấu thời gian nén, nên hai lần sinh từ cùng một nguồn
cho ra hai tệp khác byte. `sinh_tai_lieu.sh --kiem` dùng `cmp` nên báo "LỆCH nguồn" cho MỌI tài
liệu, kể cả những tài liệu đang đồng bộ hoàn hảo — đo ngày 06/09/2026 trên pol, prs, cxd: cả ba
đều ✗. Một cổng luôn đỏ là một cổng không ai đọc, và nó che mất lần lệch thật.

So sánh ở mức khối (đoạn văn và bảng), giữ nguyên đánh dấu đậm/nghiêng, bỏ qua dấu thời gian,
id quan hệ và thứ tự thuộc tính XML — tức đúng những thứ người đọc tài liệu quan tâm.
"""
from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

sys.path.insert(0, str(Path(__file__).parent))
from rut_bang_docx import W, bang, doan_text  # noqa: E402


def khoi(p: Path) -> list[tuple[str, object]]:
    """Thân tài liệu thành danh sách khối: ("P", chuỗi) hoặc ("T", bảng)."""
    body = ET.fromstring(zipfile.ZipFile(p).read("word/document.xml")).find(f"{W}body")
    ra: list[tuple[str, object]] = []
    for el in body:
        if el.tag == f"{W}p":
            t = doan_text(el)
            if t.strip():
                ra.append(("P", t))
        elif el.tag == f"{W}tbl":
            ra.append(("T", bang(el, bo_dam=False)))
    return ra


def so(a: Path, b: Path) -> list[str]:
    ka, kb = khoi(a), khoi(b)
    loi = []
    for i, (x, y) in enumerate(zip(ka, kb, strict=False)):
        if x != y:
            loi.append(f"khối {i} ({x[0]}) lệch:\n    A: {str(x[1])[:160]}\n    B: {str(y[1])[:160]}")
    if len(ka) != len(kb):
        thua, ten = (ka[len(kb):], "A") if len(ka) > len(kb) else (kb[len(ka):], "B")
        loi.append(f"{ten} thừa {len(thua)} khối: " + " | ".join(str(t[1])[:90] for t in thua[:3]))
    return loi


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("a", type=Path)
    ap.add_argument("b", type=Path)
    ap.add_argument("--im", action="store_true", help="không in gì, chỉ trả mã thoát")
    o = ap.parse_args(argv)
    loi = so(o.a, o.b)
    if not o.im:
        for x in loi[:8]:
            print("  " + x)
    return 1 if loi else 0


if __name__ == "__main__":
    raise SystemExit(main())
