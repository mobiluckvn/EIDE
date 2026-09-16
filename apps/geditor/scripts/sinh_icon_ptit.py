"""Tách biểu tượng PTIT khỏi wordmark và dựng bản icon có lề."""
import pathlib
import re

GOC = pathlib.Path(__file__).resolve().parents[3] / "docs" / "logo-ptit-1.svg"
# SVG là NGUỒN, nằm cùng mã thư viện để SwiftPM đóng gói được (`Bundle.module`).
# `.icns` là SẢN PHẨM DỰNG, nằm ở `Resources/` cạnh Info.plist vì script đóng gói lấy từ đó.
RES = pathlib.Path(__file__).resolve().parents[1] / "Sources" / "EIDEKit" / "Resources"
ICNS = pathlib.Path(__file__).resolve().parents[1] / "Resources" / "AppIcon.icns"

goc = GOC.read_text(encoding="utf-8", errors="replace")
paths = re.findall(r"<path[^>]*>", goc)


def tu_dong(p: str) -> str:
    """Tệp gốc dùng dạng `<path …></path>`; phép trích chỉ lấy thẻ MỞ.

    Không tự đóng lại thì rsvg báo `premature end of data in tag path` và từ chối cả tệp — một
    lỗi im lặng nếu ai đó chỉ nhìn kích thước tệp rồi tưởng đã xong.
    """
    return p if p.rstrip().endswith("/>") else p.rstrip()[:-1].rstrip() + "/>"


# Hai path chữ nằm ở x ≥ 45 trong tệp gốc; chúng không vào được một icon vuông.
bt = [tu_dong(p) for p in paths
      if 'fill="#BC2626"' not in p and 'fill="#373D4E"' not in p]
assert len(bt) == 15, f"mong 15 path biểu tượng, nhận {len(bt)}"

GHI = """  <!-- Biểu tượng PTIT, tách từ docs/logo-ptit-1.svg (bản chính thức chủ sản phẩm cung cấp
       16/09/2026). CHỈ phần hình. Màu giữ NGUYÊN bản gốc, không chỉnh. -->"""
mark = ('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" '
        'viewBox="0 0 40 40" fill="none">\n' + GHI + "\n  "
        + "\n  ".join(bt) + "\n</svg>\n")
(RES / "ptit-mark.svg").write_text(mark, encoding="utf-8")

LE = 0.12
vb = 40 / (1 - 2 * LE)
off = (vb - 40) / 2
icon = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{vb:.2f}" height="{vb:.2f}" '
        f'viewBox="0 0 {vb:.2f} {vb:.2f}" fill="none">\n'
        f'  <!-- Bản dựng ICON: biểu tượng đặt giữa, chừa lề {LE:.0%} mỗi bên. Icon macOS không\n'
        f'       chạm mép — hình chạm mép trông to hơn hẳn các icon cạnh nó trong Dock. -->\n'
        f'  <g transform="translate({off:.2f} {off:.2f})">\n  '
        + "\n  ".join(bt) + "\n  </g>\n</svg>\n")
(RES / "ptit-icon.svg").write_text(icon, encoding="utf-8")
print("ok — 15 path biểu tượng, đã tự đóng thẻ")


# --- dựng .icns -------------------------------------------------------------------------
#
# Tách khỏi phần trên để chạy được riêng: phần trên chỉ cần Python, phần này cần
# `rsvg-convert` (homebrew librsvg) và `iconutil` (có sẵn trên macOS).
if __name__ == "__main__":
    import shutil
    import subprocess
    import tempfile

    if shutil.which("rsvg-convert") is None:
        raise SystemExit("cần `rsvg-convert` — `brew install librsvg`")
    with tempfile.TemporaryDirectory() as tam:
        bo = pathlib.Path(tam) / "AppIcon.iconset"
        bo.mkdir()
        for s in (16, 32, 128, 256, 512):
            for hau, px in ((f"{s}x{s}", s), (f"{s}x{s}@2x", s * 2)):
                subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px),
                                str(RES / "ptit-icon.svg"), "-o", str(bo / f"icon_{hau}.png")],
                               check=True)
        subprocess.run(["iconutil", "-c", "icns", str(bo),
                        "-o", str(ICNS)], check=True)
    print("đã ghi", ICNS)
