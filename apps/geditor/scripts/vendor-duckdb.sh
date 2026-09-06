#!/bin/bash
# Nạp libduckdb vào vendor/duckdb (ADR-14 · PoC-K).
#
#   scripts/vendor-duckdb.sh              phiên bản đã ghim
#   scripts/vendor-duckdb.sh v1.5.6       phiên bản khác
#
# ## Vì sao BINARY dựng sẵn, khác hẳn PCRE2 và tree-sitter
#
# Ba thư viện kia được vendor MÃ NGUỒN, và `scripts/vendor-pcre2.sh` ghi rõ lý do: bản dựng sẵn
# của Homebrew chỉ có kiến trúc của máy đang cài, trong khi NFR-PORT-01 đòi MỘT bundle chứa
# native cho cả arm64 lẫn x86_64. Chỉ vendor mã nguồn mới cho `swift build --arch arm64
# --arch x86_64` ra universal.
#
# Lý do ấy KHÔNG áp dụng cho DuckDB: bản phát hành chính thức `libduckdb-osx-universal` **đã là
# universal**, và script này kiểm lại bằng `lipo` chứ không tin lời. Vế NFR-PORT-01 vì thế đạt
# mà không phải biên dịch gì.
#
# Đổi lại là hai khoản phải nói ra:
#   - Ta không dựng lại được nó từ nguồn, nên phải TIN bản phát hành của upstream. Bù bằng cách
#     ghim phiên bản và ghi lại SHA-256 của file đã tải.
#   - Nó là mã của người khác chạy trên máy người dùng — cùng loại nghĩa vụ theo dõi CVE mà
#     NFR-SEC-03 đặt ra cho plugin.
#
# ## Script này chạy khi NÂNG PHIÊN BẢN, không chạy trong CI
#
# `vendor/duckdb/libduckdb.dylib` nằm TRONG kho, qua **Git LFS** (`.gitattributes`, ADR-14 §6.1).
# CI lấy nó bằng `actions/checkout` với `lfs: true`, nên bất biến "không tải về lúc dựng"
# (NFR-SEC-03) vẫn nguyên.
#
# Nâng phiên bản: chạy script này, rồi `git add vendor/duckdb/` và commit — LFS tự thay nội
# dung bằng một con trỏ 133 byte.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-v1.5.5}"
DEST="vendor/duckdb"
URL="https://github.com/duckdb/duckdb/releases/download/${VERSION}/libduckdb-osx-universal.zip"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ Tải libduckdb ${VERSION} (universal)…"
curl -sSL --fail -o "$WORK/libduckdb.zip" "$URL"
unzip -o -q "$WORK/libduckdb.zip" -d "$WORK"

if [ ! -f "$WORK/libduckdb.dylib" ] || [ ! -f "$WORK/duckdb.h" ]; then
    echo "❌ gói tải về không có libduckdb.dylib hoặc duckdb.h"
    exit 1
fi

# Kiểm CẢ HAI kiến trúc, không tin cái tên file.
#
# `lipo` là bước không được bỏ: `swift build` trên máy Apple Silicon cho ra binary arm64 chạy
# tốt trên mọi máy CI, và không ai phát hiện phần x86_64 biến mất cho tới khi một người dùng
# Intel tải về. CI đã học bài ấy một lần (MNT-03) — đừng học lại ở đây.
ARCHS="$(lipo -info "$WORK/libduckdb.dylib" | sed 's/^.*are: //')"
for arch in arm64 x86_64; do
    case " $ARCHS " in
        *" $arch "*) ;;
        *) echo "❌ thiếu kiến trúc $arch (có: $ARCHS) — NFR-PORT-01 không đạt"; exit 1 ;;
    esac
done
echo "   kiến trúc: $ARCHS ✅"

RAW_SHA="$(shasum -a 256 "$WORK/libduckdb.dylib" | awk '{print $1}')"

# Strip rồi KÝ LẠI NGAY.
#
# `strip` sửa file nên nó phá chữ ký sẵn có, và một dylib chữ ký hỏng KHÔNG báo lỗi `dlopen` —
# nhân giết cả tiến trình bằng SIGKILL, không một dòng thông báo. PoC-K chết đúng như thế và
# triệu chứng trông y hệt hết bộ nhớ. Ký ad-hoc ở đây chỉ để file dùng được lúc phát triển;
# `build-universal.sh` ký lại bằng danh tính thật khi đóng bundle.
cp "$WORK/libduckdb.dylib" "$WORK/stripped.dylib"
strip -x -S "$WORK/stripped.dylib" 2>/dev/null || true
codesign --force --sign - "$WORK/stripped.dylib" >/dev/null 2>&1

mkdir -p "$DEST"
mv "$WORK/stripped.dylib" "$DEST/libduckdb.dylib"
cp "$WORK/duckdb.h" "$DEST/duckdb.h"

RAW_MB=$(( $(stat -f%z "$WORK/libduckdb.dylib") / 1048576 ))
OUT_MB=$(( $(stat -f%z "$DEST/libduckdb.dylib") / 1048576 ))

cat > "$DEST/VENDORED.md" <<EOF
# libduckdb — bản dựng sẵn của upstream

**Phiên bản:** ${VERSION}
**Nguồn:** ${URL}
**Kiến trúc:** ${ARCHS}
**SHA-256 (bản tải về, TRƯỚC khi strip):** ${RAW_SHA}
**Cỡ:** ${RAW_MB} MB tải về → ${OUT_MB} MB sau strip

Nạp lại: \`scripts/vendor-duckdb.sh ${VERSION}\`

Khác với PCRE2 / tree-sitter / Scintilla, thư mục này chứa **binary dựng sẵn**, không phải mã
nguồn. Nó NẰM TRONG kho nhưng đi qua **Git LFS** (\`.gitattributes\`), nên bản clone chỉ kéo
phiên bản đang dùng. Lý do và cái giá: xem đầu \`scripts/vendor-duckdb.sh\` và
\`docs/adr/ADR-14-duckdb-va-nap-luoi.md\` §6.1.

Máy chưa cài Git LFS sẽ thấy file này chỉ 133 byte — khi ấy chạy \`git lfs install && git lfs pull\`.

Không sửa một byte nào của upstream ngoài \`strip -x -S\` (bỏ ký hiệu cục bộ) và ký lại ad-hoc.
EOF

echo "   ${RAW_MB} MB → ${OUT_MB} MB sau strip"
echo "   sha256: ${RAW_SHA}"
echo "▸ Xong: $DEST/libduckdb.dylib"
