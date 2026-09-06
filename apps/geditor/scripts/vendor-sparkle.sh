#!/bin/bash
# Nạp Sparkle vào `vendor/sparkle/` — NFR-SEC-01 (kênh tự cập nhật ký EdDSA).
#
#   scripts/vendor-sparkle.sh          nạp phiên bản đang ghim
#   scripts/vendor-sparkle.sh 2.9.6    nạp phiên bản chỉ định
#
# VÌ SAO COMMIT THẲNG, KHÔNG QUA GIT LFS. Cùng lập luận với `vendor-mermaid.sh`: framework
# 3,0 MB thì mỗi lần nâng cộng vài MB vĩnh viễn — chấp nhận được — còn LFS mang theo cái bẫy mà
# `.gitattributes` tự nêu: máy chưa cài `git lfs` clone ra một con trỏ 130 byte. Với `libduckdb`
# 94 MB thì đánh đổi ấy đáng; với 3 MB thì không.
#
# KHÔNG TẢI LÚC DỰNG, đúng bất biến của `ci.yml`: *"vendor nằm trong kho mã, không tải về lúc
# dựng — NFR-SEC-03 chuỗi cung ứng"*. Script này chạy TAY khi nâng phiên bản, kết quả được commit.
#
# LẤY GÌ TỪ GÓI. Chỉ `Sparkle.framework`, giấy phép, và ba công cụ dòng lệnh (`generate_keys`,
# `sign_update`, `generate_appcast`). KHÔNG lấy `Sparkle Test App.app` và thư mục `Symbols` —
# chúng chỉ phục vụ việc phát triển chính Sparkle, và một app mẫu nằm trong bundle nộp lên App
# Store là đúng loại thứ khiến hồ sơ bị hỏi lại.
set -euo pipefail

cd "$(dirname "$0")/.."

# Phiên bản GHIM. Đổi số này là quyết định có hệ quả: đọc CHANGELOG của Sparkle trước, vì hành vi
# cập nhật đổi thì người dùng thấy ngay, và một bản Sparkle mới có thể đòi khoá hoặc appcast khác.
VERSION="${1:-2.9.6}"
DEST="vendor/sparkle"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

URL="https://github.com/sparkle-project/Sparkle/releases/download/${VERSION}/Sparkle-${VERSION}.tar.xz"

echo "▸ Tải Sparkle ${VERSION}…"
curl -sSL --fail -o "$WORK/sparkle.tar.xz" "$URL"
tar xf "$WORK/sparkle.tar.xz" -C "$WORK"

rm -rf "$DEST"
mkdir -p "$DEST/bin"
cp -R "$WORK/Sparkle.framework" "$DEST/Sparkle.framework"
cp "$WORK/LICENSE" "$DEST/LICENSE"
for tool in generate_keys sign_update generate_appcast; do
    cp "$WORK/bin/$tool" "$DEST/bin/$tool"
done

# Bản kê đọc được bằng mắt, cùng khuôn `vendor/mermaid/VERSION.json`. Có `sha256` vì đây là mã
# CHẠY ĐƯỢC tải từ mạng: NFR-SEC-03 nói về chuỗi cung ứng, và một dòng băm là thứ rẻ nhất cho
# phép người sau kiểm rằng thứ trong kho đúng là thứ upstream phát hành.
SHA="$(shasum -a 256 "$WORK/sparkle.tar.xz" | awk '{print $1}')"
cat > "$DEST/VERSION.json" <<JSON
{
  "ten": "Sparkle",
  "phienBan": "${VERSION}",
  "nguon": "${URL}",
  "sha256_goi": "${SHA}",
  "napNgay": "$(date +%Y-%m-%d)",
  "giayPhep": "MIT — xem LICENSE",
  "layGi": ["Sparkle.framework", "bin/generate_keys", "bin/sign_update", "bin/generate_appcast"],
  "khongLay": ["Sparkle Test App.app", "Symbols/", "old_dsa_scripts"]
}
JSON

echo "▸ Xong: $DEST"
du -sh "$DEST/Sparkle.framework" "$DEST/bin"
echo
echo "Bước tiếp theo, và nó cần NGƯỜI vì Keychain sẽ hỏi quyền:"
echo "  $DEST/bin/generate_keys              # sinh khoá, in khoá công khai"
echo "  $DEST/bin/generate_keys -x khoa.txt  # xuất khoá riêng để sao lưu"
echo "Rồi thay SUPublicEDKey trong Resources/Info.plist — xem docs/khoa-va-ky.md."
