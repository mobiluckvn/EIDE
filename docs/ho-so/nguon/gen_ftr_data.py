"""Dữ liệu đo được cho EIDE-FTR-30 — trạng thái hiện thực và ảnh màn hình thật.

Chạy trong thư mục dàn dựng của `scripts/sinh_tai_lieu.sh`, đọc kho qua `EIDE_GOC`.

## Vì sao tài liệu tính năng phải ĐO chứ không chép

Một tài liệu mô tả tính năng gửi cho người ngoài đọc là chỗ dễ nói quá nhất trong cả bộ hồ sơ:
nó liệt kê 238 năng lực, và người đọc mặc định cả 238 đều chạy. Con số "216/238" ở đây lấy
thẳng từ registry lúc sinh tài liệu, nên ngày nào tài liệu được sinh lại thì ngày ấy nó đúng —
khác với một dòng gõ tay, vốn đúng đúng một ngày.

Ảnh cũng vậy: ảnh trong tài liệu này là ảnh CHỤP TỪ CỬA SỔ THẬT trong một vòng chạy có nhật ký
(`--vong-giao-dien`), không phải mockup. Một mockup mô tả ý định; người duyệt cần thấy thứ đang
chạy được.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

#: Bề ngang ảnh trong tài liệu (px). Ảnh gốc chụp ở 2× của cửa sổ 1366 pt, tức ~2732 px —
#: nhúng nguyên thì riêng phần ảnh đã hơn 4 MB và tệp docx không gửi qua thư được.
RONG = 1400


def _trang_thai(goc: Path) -> dict[str, bool]:
    sys.path.insert(0, str(goc / "src"))
    from eide_core.registry import get_registry  # noqa: PLC0415 — cần sys.path ở trên

    reg = get_registry()
    ds = json.loads((goc / "docs" / "spec" / "cds.json").read_text(encoding="utf-8"))
    return {c["id"]: (c["id"] in reg and reg.get(c["id"]).implemented) for c in ds}


def _anh(goc: Path, ra: Path) -> list[str]:
    """Thu nhỏ ảnh vòng chạy vào `anh/`. Không có ảnh thì trả rỗng — tài liệu tự bỏ mục."""
    nguon = goc / "docs" / "nhat-ky" / "anh-vong-giao-dien"
    if not nguon.is_dir():
        return []
    try:
        from PIL import Image  # noqa: PLC0415 — chỉ việc soạn tài liệu mới cần Pillow
    except ImportError:
        return []
    ra.mkdir(parents=True, exist_ok=True)
    ten = []
    for f in sorted(nguon.glob("buoc-*.png")):
        anh = Image.open(f)
        if anh.width > RONG:
            anh = anh.resize((RONG, round(anh.height * RONG / anh.width)), Image.LANCZOS)
        anh.convert("RGB").save(ra / f.name, "PNG", optimize=True)
        ten.append(f.name)
    return ten


def main() -> None:
    goc = Path(os.environ.get("EIDE_GOC") or ".").resolve()
    dich = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    tt = _trang_thai(goc)
    anh = _anh(goc, dich / "anh")
    kich_thuoc = {}
    try:
        from PIL import Image  # noqa: PLC0415

        for t in anh:
            im = Image.open(dich / "anh" / t)
            kich_thuoc[t] = [im.width, im.height]
    except ImportError:
        pass
    (dich / "trang_thai.json").write_text(
        json.dumps({"caps": tt, "anh": anh, "co": kich_thuoc}, ensure_ascii=False, indent=1),
        encoding="utf-8")
    print(f"trang_thai.json: {sum(tt.values())}/{len(tt)} năng lực · {len(anh)} ảnh")


if __name__ == "__main__":
    main()
