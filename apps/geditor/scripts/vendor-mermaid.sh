#!/bin/bash
# Nạp mermaid.js vào `vendor/mermaid/` — FR-MMD-001, NFR-MMD-02.
#
#   scripts/vendor-mermaid.sh            nạp phiên bản đang ghim
#   scripts/vendor-mermaid.sh 11.4.1     nạp phiên bản chỉ định
#
# VÌ SAO VENDOR CHỨ KHÔNG TẢI CDN. NFR-MMD-02 viết thẳng: *"mermaid.js nằm trong bundle app,
# không CDN, không network; phiên bản pin và ghi trong About"*. Một sơ đồ trong tài liệu của
# người dùng phải vẽ được trên máy bay và phải vẽ RA ĐÚNG THẾ sau ba năm nữa — cả hai điều đó
# đều mất nếu tệp JS đến từ một máy chủ ở xa.
#
# VÌ SAO COMMIT THẲNG, KHÔNG QUA GIT LFS (khác `libduckdb.dylib`). `.gitattributes` cân nhắc
# LFS theo cỡ: dylib 94 MB thì mỗi lần nâng cộng 94 MB vĩnh viễn vào mọi bản clone. Tệp này
# 3,4 MB — nâng vài lần một năm là vài MB, chấp nhận được. Đổi lại ta tránh đúng cái giá mà
# chính `.gitattributes` nêu ra: máy chưa cài `git lfs` clone ra một con trỏ 130 byte, và khi
# ấy MỌI sơ đồ trong app im lặng không vẽ được. Với một tệp mà thiếu nó là mất hẳn một cụm
# tính năng P1, tránh được cái bẫy ấy đáng giá hơn vài MB.
#
# KHÔNG TẢI LÚC DỰNG, đúng bất biến của `ci.yml`: *"vendor nằm trong kho mã, không tải về lúc
# dựng — NFR-SEC-03 chuỗi cung ứng"*. Script này chạy TAY khi nâng phiên bản, và kết quả của nó
# được commit.
set -euo pipefail

cd "$(dirname "$0")/.."

# Phiên bản GHIM. Đổi số này là một quyết định có hệ quả nhìn thấy được: NFR-MMD-02 đòi *"nâng
# cấp mermaid đi theo bản cập nhật app kèm ghi chú khác biệt render (tránh sơ đồ cũ vỡ bất
# ngờ)"* — nên sau khi đổi, chạy `scripts/run-mermaid-kpi.sh` và đọc lại vài sơ đồ mẫu.
VERSION="${1:-11.17.2}"
DEST="vendor/mermaid"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

URL="https://registry.npmjs.org/mermaid/-/mermaid-${VERSION}.tgz"

echo "▸ Tải mermaid ${VERSION} từ npm…"
curl -sSL --fail -o "$WORK/mermaid.tgz" "$URL"

# Chỉ lấy ĐÚNG hai tệp: bản dựng đã nén và giấy phép.
#
# Gói npm giải nén ra 84 MB (mã nguồn, sourcemap, .d.ts, ảnh tài liệu). Vendor cả gói là mang
# 84 MB vào kho để dùng một tệp — và làm việc rà soát giấy phép/chuỗi cung ứng nặng thêm gấp
# hai mươi lần mà không bảo vệ gì.
tar xzf "$WORK/mermaid.tgz" -C "$WORK" package/dist/mermaid.min.js package/LICENSE

mkdir -p "$DEST"
cp "$WORK/package/dist/mermaid.min.js" "$DEST/mermaid.min.js"
cp "$WORK/package/LICENSE" "$DEST/LICENSE"

SHA="$(shasum -a 256 "$DEST/mermaid.min.js" | cut -d' ' -f1)"
BYTES="$(stat -f%z "$DEST/mermaid.min.js")"

# Bản kê để About đọc (NFR-MMD-02: "phiên bản pin và ghi trong About") và để cổng chuỗi cung
# ứng đối chiếu. Ghi bằng máy chứ không gõ tay: một bản kê gõ tay sẽ lệch khỏi tệp thật đúng
# vào lần nâng cấp vội nhất.
cat > "$DEST/VERSION.json" <<EOF
{
  "name": "mermaid",
  "version": "${VERSION}",
  "license": "MIT",
  "file": "mermaid.min.js",
  "bytes": ${BYTES},
  "sha256": "${SHA}",
  "source": "${URL}",
  "note": "Vendor tay bằng scripts/vendor-mermaid.sh. KHÔNG tải lúc dựng, KHÔNG CDN lúc chạy (NFR-MMD-02)."
}
EOF

echo "✅ ${DEST}/mermaid.min.js — ${VERSION}, $((BYTES / 1024)) KB"
echo "   sha256 ${SHA}"
echo
echo "Việc còn lại sau khi nâng phiên bản:"
echo "  1. scripts/run-mermaid-kpi.sh   — NFR-MMD-01 (500 node ≤ 2 s)"
echo "  2. swift test --filter Mermaid  — bộ kiểm phân tích khối và mẫu sơ đồ"
echo "  3. Ghi khác biệt render vào CHANGELOG (NFR-MMD-02)"
