"""Rút bảng từ .docx về dạng danh sách Python, dựng lại đánh dấu `**đậm**`/`*nghiêng*`.

Dùng để khôi phục `docs/ho-so/nguon/dialog.json` đã mất (DEVIATIONS DEV-019). Không phải công
cụ dùng thường xuyên: nguồn sinh là chuẩn, docx là sản phẩm; đây là đường đi NGƯỢC, chỉ hợp lệ
khi nguồn mất và docx là thứ duy nhất còn lại.

Vì sao phải dựng lại đánh dấu chứ không rút văn bản trơn: `eaa_doc.js::T()` đưa mọi ô qua
`inline()`, nên `**x**` trong nguồn thành run in đậm trong docx. Rút trơn rồi sinh lại sẽ ra một
tài liệu KHÁC bản gốc — mà cách duy nhất để biết bản khôi phục có đúng không là sinh lại rồi so
với bản gốc, nên mất đánh dấu là mất luôn phép thử.

    python scripts/rut_bang_docx.py <tệp.docx> [--bang N] [--liet-ke]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


def _bat(rpr: ET.Element | None, ten: str) -> bool:
    """`<w:b/>` là BẬT, `<w:b w:val="false"/>` là TẮT — thẻ có mặt không có nghĩa là bật.

    Bộ sinh phát ra 143 thẻ `w:val="false"` trong DPS-09, nên bỏ qua thuộc tính này thì mọi ô
    đều thành đậm và bản khôi phục sai từ đầu tới cuối.
    """
    if rpr is None:
        return False
    e = rpr.find(f"{W}{ten}")
    if e is None:
        return False
    return e.get(f"{W}val", "true") not in ("false", "0", "off")


def _run_text(r: ET.Element) -> tuple[str, bool, bool]:
    rpr = r.find(f"{W}rPr")
    dam = _bat(rpr, "b")
    ngh = _bat(rpr, "i")
    t = "".join(n.text or "" for n in r.iter(f"{W}t"))
    # <w:tab/> và <w:br/> trong run cũng là nội dung
    for n in r:
        if n.tag == f"{W}br":
            t += "\n"
    return t, dam, ngh


def doan_text(p: ET.Element) -> str:
    """Một <w:p> → chuỗi có đánh dấu, gộp các run liền kề cùng kiểu."""
    cum: list[tuple[str, bool, bool]] = []
    for r in p.findall(f"{W}r"):
        t, d, i = _run_text(r)
        if not t:
            continue
        if cum and cum[-1][1] == d and cum[-1][2] == i:
            cum[-1] = (cum[-1][0] + t, d, i)
        else:
            cum.append((t, d, i))
    ra = []
    for t, d, i in cum:
        # Đánh dấu bao quanh phần CÓ CHỮ; khoảng trắng ở rìa phải nằm ngoài, vì `**x **` không
        # phải cú pháp hợp lệ và `inline()` sẽ trả lại một chuỗi khác.
        m = re.match(r"^(\s*)(.*?)(\s*)$", t, re.S)
        dau, loi, cuoi = m.group(1), m.group(2), m.group(3)
        if loi and d:
            loi = f"**{loi}**"
        elif loi and i:
            loi = f"*{loi}*"
        ra.append(dau + loi + cuoi)
    return "".join(ra)


def o_text(tc: ET.Element) -> str | list[str]:
    """Một ô. Nhiều đoạn ⇒ nguồn truyền một mảng cho `T()`."""
    ds = [doan_text(p) for p in tc.findall(f"{W}p")]
    ds = [d for d in ds if d.strip()]
    if len(ds) == 1:
        return ds[0]
    return ds or ""


def _bo_dam_tu_dong(x: str | list[str]) -> str | list[str]:
    """Gỡ phần in đậm mà `T()` TỰ thêm, để còn lại đúng chuỗi nguồn.

    `eaa_doc.js::T()` dựng hàng tiêu đề với `bold: true` và mỗi hàng dữ liệu với
    `bold: i === 0`. Nghĩa là cột đầu và hàng tiêu đề đậm dù nguồn viết gì — giữ lại `**` ở đó
    là bịa ra đánh dấu mà nguồn không có, và bản khôi phục sẽ sinh ra `****D1****`.

    Chỉ gỡ khi CẢ ô là một khối đậm liền. Ô nửa đậm nửa thường ở cột đầu là chuyện không thể
    xảy ra với `T()`, nên nếu gặp thì để nguyên và cho vòng đối chiếu bắt.
    """
    if isinstance(x, list):
        return [_bo_dam_tu_dong(i) for i in x]  # type: ignore[misc]
    if x.startswith("**") and x.endswith("**") and "**" not in x[2:-2]:
        return x[2:-2]
    return x


def bang(tbl: ET.Element, *, bo_dam: bool = True) -> list[list]:
    ra = [[o_text(tc) for tc in tr.findall(f"{W}tc")] for tr in tbl.findall(f"{W}tr")]
    if not bo_dam:
        return ra
    for i, hang in enumerate(ra):
        for j in range(len(hang)):
            if i == 0 or j == 0:
                hang[j] = _bo_dam_tu_dong(hang[j])
    return ra


def doc_bang(docx: Path) -> list[list[list]]:
    xml = zipfile.ZipFile(docx).read("word/document.xml")
    root = ET.fromstring(xml)
    body = root.find(f"{W}body")
    return [bang(t) for t in body.iter(f"{W}tbl")]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("docx", type=Path)
    ap.add_argument("--bang", type=int, help="in một bảng dạng JSON")
    ap.add_argument("--liet-ke", action="store_true", help="liệt kê tiêu đề mọi bảng")
    a = ap.parse_args(argv)

    bs = doc_bang(a.docx)
    if a.bang is not None:
        json.dump(bs[a.bang], sys.stdout, ensure_ascii=False, indent=1)
        print()
        return 0
    for i, b in enumerate(bs):
        dau = " | ".join(str(x)[:22] for x in b[0]) if b else "(rỗng)"
        print(f"  [{i:2}] {len(b):3} dòng × {len(b[0]) if b else 0} cột   {dau}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
