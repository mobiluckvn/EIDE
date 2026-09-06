#!/bin/bash
# Nạp mã nguồn Scintilla vào Sources/ScintillaCocoa/vendor (ADR-01 · PoC-A).
#
# Vì sao vendor mã nguồn:
#   - Scintilla không phát hành framework nhị phân cho macOS; bản dựng chính thức là một
#     Xcode project, mà SwiftPM không gọi được.
#   - NFR-PORT-01 đòi MỘT bundle universal arm64 + x86_64. Chỉ biên dịch từ nguồn trong
#     cùng lệnh `swift build --arch arm64 --arch x86_64` mới ra được.
#
# Không sửa một dòng nào của upstream. Mọi lựa chọn build nằm trong Package.swift.
# Giấy phép: HPND (License.txt của upstream được giữ nguyên trong vendor/).
#
#   scripts/vendor-scintilla.sh          nạp phiên bản mặc định
#   scripts/vendor-scintilla.sh 555      nạp phiên bản chỉ định (không có dấu chấm: 5.5.5 → 555)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-555}"
URL="https://www.scintilla.org/scintilla${VERSION}.tgz"
# Chỉ `vendor/` là mã upstream. `Sources/ScintillaCocoa/include/` và facade .mm là mã của
# GEditor và KHÔNG bị script này đụng tới.
DEST="Sources/ScintillaCocoa/vendor"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ Tải Scintilla ${VERSION}"
curl -fsSL "$URL" -o "$WORK/scintilla.tgz"
tar xzf "$WORK/scintilla.tgz" -C "$WORK"

echo "▸ Chép nguồn cần dùng"
rm -rf "$DEST"
mkdir -p "$DEST"
# Chỉ ba thư mục: core C++, header công khai, lớp Cocoa. Bỏ gtk/qt/win32, doc, test —
# repo không cần mang theo thứ không biên dịch.
cp -R "$WORK/scintilla/src" "$DEST/src"
cp -R "$WORK/scintilla/include" "$DEST/include"
cp -R "$WORK/scintilla/cocoa" "$DEST/cocoa"
cp "$WORK/scintilla/License.txt" "$DEST/License.txt"
cp "$WORK/scintilla/version.txt" "$DEST/version.txt"

# InfoBar là thanh trạng thái mẫu của bộ demo upstream, không phải phần của engine hiển thị —
# nó kéo theo nib và ảnh trong res/. PoC dùng thanh trạng thái của GEditor.
rm -rf "$DEST/cocoa/ScintillaTest" "$DEST/cocoa/Scintilla" "$DEST/cocoa/res"
rm -f "$DEST/cocoa/InfoBar.mm" "$DEST/cocoa/InfoBar.h" "$DEST/cocoa/checkbuildosx.sh"

# Rác không biên dịch được lẫn trong tarball upstream: file cấu hình SciTE và một bản .orig
# sót lại từ lần vá của upstream. SwiftPM coi MỌI file trong thư mục nguồn là nguồn, nên
# chúng làm hỏng build. Không phải sửa mã upstream — chỉ là không mang theo thứ không dùng.
rm -f "$DEST/src/SciTE.properties" "$DEST/src/PositionCache.cxx.orig"

echo "▸ Xong: $(find "$DEST" -name '*.cxx' -o -name '*.mm' | wc -l | tr -d ' ') file nguồn, $(du -sh "$DEST" | cut -f1)"
