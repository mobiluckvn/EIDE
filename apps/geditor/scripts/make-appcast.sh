#!/usr/bin/env bash
#
# Đóng gói bản đã dựng thành gói cập nhật và sinh `appcast.xml` — NFR-SEC-01, ADR-16.
#
#   scripts/make-appcast.sh                 dùng dist/direct/GEditor.app
#   scripts/make-appcast.sh --kiem          chỉ KIỂM chữ ký trong appcast rồi thoát
#
# VÌ SAO TÁCH KHỎI `build-universal.sh`. Dựng là việc làm hàng chục lần một ngày; sinh appcast là
# việc làm MỘT LẦN cho mỗi bản phát hành, và nó ghi đè một tệp mà mọi bản đã cài ngoài kia đang
# hỏi tới. Trộn hai nhịp ấy vào một script là mời một lần `--channel direct` lúc nửa đêm đẩy
# nhầm một bản dở lên feed.
#
# KHOÁ LẤY TỪ ĐÂU. Mặc định `generate_appcast` đọc Keychain — đúng chỗ khoá nên ở. Có
# `GEDITOR_SPARKLE_KEY_FILE` thì dùng tệp ấy, cho máy CI không có Keychain của người ký.
#
# GÓI LÀ .ZIP CHỨ KHÔNG PHẢI .DMG: Sparkle cài .zip bằng cách bung và thay thư mục, không cần
# mount, không cần người dùng kéo thả. Với một bản cập nhật tự động thì ít bước hơn là an toàn
# hơn — mỗi bước thêm là một chỗ hỏng giữa chừng.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/direct/GEditor.app"
OUT="dist/appcast"
FEED_PREFIX="https://geditor.code247.ai/"

# BƯỚC KIỂM NÀY LÀ THỨ DUY NHẤT CHẶN MỘT BẢN PHÁT HÀNH HỎNG ĐI RA, và đây là lý do cụ thể,
# đã kiểm bằng vật thật ngày 28/08/2026:
#
#   Đưa `generate_appcast` một khoá KHÔNG khớp `SUPublicEDKey` của bản giao, nó in đúng một dòng
#   `Warning:` ra stdout, ghi ra một appcast **KHÔNG có `edSignature` nào**, rồi **thoát 0**.
#
# Nghĩa là đường phát hành mặc định — chạy script, thấy "Wrote 1 new update", đẩy lên máy chủ —
# cho ra một feed mà MỌI bản đã cài sẽ từ chối, và không bước nào trong đường ấy kêu lên. Một
# `Warning` giữa dòng chảy log không phải một cổng; mã thoát mới là.
#
# Nên script này KHÔNG tin mã thoát của `generate_appcast`. Nó đọc lại chữ ký và tự thẩm định,
# và thoát 1 nếu thiếu hoặc sai. Đã xác nhận: cùng tình huống ấy, Sparkle thoát 0, script này
# thoát 1.
kiem_chu_ky() {
    # Đọc `edSignature` trong appcast rồi thẩm định lại bằng SUPublicEDKey trong Info.plist.
    #
    # Bước này KHÔNG thừa dù `generate_appcast` vừa tự ký: nó trả lời một câu khác hẳn — "chữ ký
    # trong feed có khớp với khoá công khai mà BẢN ĐÃ CÀI đang mang không". Ký bằng một khoá và
    # giao một khoá khác là cách hỏng im lặng nhất của cả cơ chế: feed hợp lệ, app từ chối, và
    # không bên nào nói ra vì sao.
    python3 - "$OUT/appcast.xml" "$APP/Contents/Info.plist" "$OUT" <<'PY'
import base64, plistlib, re, sys, os
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.exceptions import InvalidSignature

appcast, info_plist, thu_muc = sys.argv[1], sys.argv[2], sys.argv[3]
xml = open(appcast, encoding="utf8").read()
pub_b64 = plistlib.load(open(info_plist, "rb"))["SUPublicEDKey"]
pub = Ed25519PublicKey.from_public_bytes(base64.b64decode(pub_b64))

items = re.findall(r'<enclosure[^>]*?url="([^"]+)"[^>]*?edSignature="([^"]+)"', xml)
if not items:
    print("❌ appcast không có enclosure nào kèm edSignature"); sys.exit(1)

for url, sig_b64 in items:
    ten = os.path.basename(url)
    goi = os.path.join(thu_muc, ten)
    if not os.path.exists(goi):
        print(f"❌ appcast trỏ tới {ten} nhưng tệp ấy không có trong {thu_muc}"); sys.exit(1)
    du_lieu = open(goi, "rb").read()
    try:
        pub.verify(base64.b64decode(sig_b64), du_lieu)
    except InvalidSignature:
        print(f"❌ {ten}: chữ ký KHÔNG khớp SUPublicEDKey của bản giao — bản đã cài sẽ TỪ CHỐI")
        sys.exit(1)
    # Đối chứng âm: cùng chữ ký ấy phải TỪ CHỐI một gói đã sửa. Không có bước này thì một hàm
    # `verify` luôn trả về True cũng cho ra đúng dòng ✅ ở trên.
    try:
        pub.verify(base64.b64decode(sig_b64), du_lieu + b"\x00")
        print(f"❌ {ten}: ĐỐI CHỨNG ÂM HỎNG — gói đã sửa vẫn được chấp nhận"); sys.exit(1)
    except InvalidSignature:
        pass
    print(f"  ✅ {ten}: chữ ký khớp khoá trong bản giao, và gói sửa một byte thì bị TỪ CHỐI")
print(f"✅ NFR-SEC-01: {len(items)} gói trong appcast đều ký đúng khoá")
PY
}

if [ "${1:-}" = "--kiem" ]; then
    [ -f "$OUT/appcast.xml" ] || { echo "❌ chưa có $OUT/appcast.xml — chạy script này không kèm --kiem trước"; exit 1; }
    kiem_chu_ky
    exit 0
fi

[ -d "$APP" ] || { echo "❌ chưa có $APP — chạy scripts/build-universal.sh --channel direct trước"; exit 1; }

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
mkdir -p "$OUT"

echo "▸ Đóng gói GEditor $VERSION"
# `ditto -c -k --keepParent` giữ nguyên quyền và cờ mở rộng của bundle. `zip` thường làm mất
# symlink trong framework, và một bản cập nhật bung ra thiếu symlink thì hỏng lúc CHẠY chứ
# không hỏng lúc bung — tức người dùng đã thay app rồi mới biết.
ditto -c -k --keepParent "$APP" "$OUT/GEditor-$VERSION.zip"

echo "▸ Sinh appcast"
ARGS=(--download-url-prefix "$FEED_PREFIX" --link "https://geditor.code247.ai/")
if [ -n "${GEDITOR_SPARKLE_KEY_FILE:-}" ]; then
    ARGS+=(--ed-key-file "$GEDITOR_SPARKLE_KEY_FILE")
fi
vendor/sparkle/bin/generate_appcast "${ARGS[@]}" "$OUT"

echo
echo "▸ Kiểm chữ ký trong appcast"
kiem_chu_ky

echo
echo "▸ Xong. Đưa LÊN $FEED_PREFIX:"
echo "    $OUT/appcast.xml"
echo "    $OUT/GEditor-$VERSION.zip"
echo
echo "  Thứ tự QUAN TRỌNG: tải gói .zip lên TRƯỚC, appcast.xml SAU. Ngược lại thì có một khoảng"
echo "  thời gian feed đã báo có bản mới trong khi gói chưa tồn tại — và người dùng gặp lỗi tải."
