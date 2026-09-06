#!/bin/bash
#
# Dựng `AppIcon.icns` từ ảnh nguồn 1024×1024.
#
# ## Vì sao SINH lúc dựng chứ không commit file .icns
#
# `.icns` là một tệp nhị phân 650 KB chứa đúng cùng nội dung với `geditor_sunset_C_lockup.png`
# (174 KB) — mười bản cùng một ảnh ở mười kích thước. Commit cả hai là commit cùng một thứ hai
# lần, và lần thứ hai không ai đọc được để biết nó có còn khớp với lần thứ nhất hay không.
#
# `iconutil` và `sips` đều nằm sẵn trong macOS, không phải thứ phải tải về, nên điều này không
# vi phạm bất biến "vendor nằm trong kho mã, không tải lúc dựng" của dự án.
#
# ## Mười kích thước, không phải một
#
# macOS lấy đúng bản khớp với ngữ cảnh: 16pt cho danh sách trong Finder, 32pt cho Cmd-Tab,
# 128pt cho Dock, 512pt cho cửa sổ Giới thiệu. Thiếu một cỡ thì hệ thống tự co bản gần nhất, và
# ảnh co bằng máy trông mờ hơn hẳn ảnh làm sẵn ở đúng cỡ.
set -uo pipefail
cd "$(dirname "$0")/.."

SRC="Resources/geditor_sunset_C_lockup.png"
OUT="${1:-Resources/AppIcon.icns}"

if [ ! -f "$SRC" ]; then
    echo "❌ không có ảnh nguồn: $SRC"
    exit 1
fi

# Ảnh nguồn phải VUÔNG và đúng 1024 — cỡ lớn nhất mà `.icns` dùng (512pt @2x).
#
# Kiểm chứ không tự co: một ảnh 800×600 co lên 1024×1024 sẽ méo, và nó méo trong im lặng ở mọi
# kích thước sau đó. Nói ra để người đưa ảnh vào sửa ảnh, không phải để script đoán ý.
WIDTH="$(sips -g pixelWidth "$SRC" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
HEIGHT="$(sips -g pixelHeight "$SRC" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
    echo "❌ ảnh nguồn là ${WIDTH}×${HEIGHT}, cần đúng 1024×1024"
    exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/geditor-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

# Tên tệp trong `.iconset` là GIAO ƯỚC của `iconutil`, không phải tên tuỳ ý: sai một chữ thì nó
# báo "Failed to generate ICNS" mà không nói tệp nào sai.
#
# Cỡ 1024 chép thẳng ảnh gốc thay vì cho `sips` co về đúng kích thước cũ — một lượt co thừa vẫn
# lấy mẫu lại và làm mềm biên, dù tỷ lệ không đổi.
sips -z 16 16   "$SRC" --out "$ICONSET/icon_16x16.png"      >/dev/null 2>&1
sips -z 32 32   "$SRC" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null 2>&1
sips -z 32 32   "$SRC" --out "$ICONSET/icon_32x32.png"      >/dev/null 2>&1
sips -z 64 64   "$SRC" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null 2>&1
sips -z 128 128 "$SRC" --out "$ICONSET/icon_128x128.png"    >/dev/null 2>&1
sips -z 256 256 "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null 2>&1
sips -z 256 256 "$SRC" --out "$ICONSET/icon_256x256.png"    >/dev/null 2>&1
sips -z 512 512 "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null 2>&1
sips -z 512 512 "$SRC" --out "$ICONSET/icon_512x512.png"    >/dev/null 2>&1
cp "$SRC" "$ICONSET/icon_512x512@2x.png"

COUNT="$(ls "$ICONSET" | wc -l | tr -d ' ')"
if [ "$COUNT" != "10" ]; then
    # `sips` báo lỗi ra stdout rồi trả về 0, nên kiểm mã thoát của nó là vô ích. Đếm tệp là
    # cách duy nhất chắc chắn — và chỗ này từng im lặng cho ra 0 tệp khi thư mục đích nằm ngoài
    # vùng ghi được.
    echo "❌ chỉ dựng được $COUNT/10 kích thước"
    exit 1
fi

mkdir -p "$(dirname "$OUT")"
if ! iconutil -c icns "$ICONSET" -o "$OUT"; then
    echo "❌ iconutil không dựng được $OUT"
    exit 1
fi

echo "✅ $OUT ($(du -h "$OUT" | cut -f1)) từ $SRC"
