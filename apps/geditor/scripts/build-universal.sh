#!/bin/bash
# Dựng GEditor.app dưới dạng Universal Binary (arm64 + x86_64), theo KÊNH PHÁT HÀNH.
#
#   scripts/build-universal.sh                      bản App Store (mặc định)
#   scripts/build-universal.sh --channel direct     bản tải từ trang web, kèm CLI
#
# Hai kênh, chốt 22/08/2026 — xem docs/appstore-ra-soat.md và Distribution.swift:
#
#   appstore  App Sandbox · KHÔNG có geditor CLI · ký 3rd Party Mac Developer · đóng .pkg
#   direct    không sandbox · CÓ geditor CLI · ký Developer ID · công chứng qua Apple
#
# Mặc định là APP STORE, cố ý. Đó là bản khó hơn: sandbox giấu được lỗi mà bản kia không giấu
# (đã dính một lần — HeavyGrammars suy đường dylib từ argv[0], chết đúng trong sandbox). Ai
# dựng hằng ngày mà không nghĩ tới kênh thì nên nhận bản khắt khe hơn.
#
# NFR-PORT-01: MỘT bundle .app duy nhất chứa mã native cho cả hai kiến trúc, không
# phụ thuộc Rosetta 2 cho bất kỳ thành phần nào. Script này in `lipo -info` cho mọi
# artefact — CI so kết quả đó và fail nếu thiếu một kiến trúc.
set -euo pipefail

cd "$(dirname "$0")/.."

CHANNEL="appstore"
while [ $# -gt 0 ]; do
    case "$1" in
        --channel) CHANNEL="${2:-}"; shift 2 ;;
        *) echo "Tham số lạ: $1"; exit 2 ;;
    esac
done
case "$CHANNEL" in
    appstore)
        ENTITLEMENTS="Resources/GEditor-AppStore.entitlements"
        WITH_CLI=0
        IDENTITY="${GEDITOR_APPSTORE_IDENTITY:-}"
        ;;
    direct)
        ENTITLEMENTS="Resources/GEditor-Direct.entitlements"
        WITH_CLI=1
        IDENTITY="${GEDITOR_SIGN_IDENTITY:-}"
        ;;
    *) echo "--channel phải là appstore hoặc direct"; exit 2 ;;
esac

CONFIGURATION="${CONFIGURATION:-release}"
case "$CONFIGURATION" in
    release) PRODUCTS_SUBDIR="Release" ;;
    debug)   PRODUCTS_SUBDIR="Debug" ;;
    *) echo "CONFIGURATION phải là release hoặc debug"; exit 2 ;;
esac
BUILD_DIR=".build/apple/Products/${PRODUCTS_SUBDIR}"
DIST_DIR="dist/$CHANNEL"
APP="$DIST_DIR/GEditor.app"
mkdir -p "$DIST_DIR"

echo "▸ Build universal ($CONFIGURATION, kênh $CHANNEL)…"
swift build -c "$CONFIGURATION" --arch arm64 --arch x86_64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$BUILD_DIR/GEditorApp" "$APP/Contents/MacOS/GEditor"

# Ba grammar nặng nằm ngoài binary chính, nạp bằng `dlopen` khi cần (ADR-08 phương án C).
#
# Phải copy VÀO Contents/Frameworks — `HeavyGrammars.candidatePaths()` tìm ở đó trước tiên, và
# đó cũng là chỗ duy nhất codesign chấp nhận một dylib bên trong bundle. Đặt cạnh binary trong
# MacOS/ thì chữ ký của bundle hỏng.
cp "$BUILD_DIR/libTreeSitterHeavy.dylib" "$APP/Contents/Frameworks/libTreeSitterHeavy.dylib"

# DuckDB — engine truy vấn của FR-CSV-407 và cả tầng phân tích (ADR-14).
#
# Cùng chỗ và cùng lý do với dylib grammar: `DuckDB.libraryCandidates` tìm ở
# `Contents/Frameworks` trước tiên, và đó là chỗ duy nhất codesign chấp nhận một dylib bên
# trong bundle. Nó KHÔNG được nạp lúc khởi động — `LazyLoadAudit` hỏi thẳng nhân để canh điều
# đó, và cổng ấy đã được xác nhận đỏ được.
#
# Thiếu file này thì app vẫn chạy, chỉ mất tính năng truy vấn và nói ra lý do (`DuckDB.shared`
# trả nil). Đó là lựa chọn có ý thức: một dylib 94 MB không được phép là thứ chặn app khởi động.
if [ -f "vendor/duckdb/libduckdb.dylib" ]; then
    cp "vendor/duckdb/libduckdb.dylib" "$APP/Contents/Frameworks/libduckdb.dylib"
else
    echo "⚠️  KHÔNG có vendor/duckdb/libduckdb.dylib — bundle này sẽ KHÔNG truy vấn được."
    echo "   Chạy scripts/vendor-duckdb.sh rồi dựng lại."
fi

# mermaid.min.js — NFR-MMD-02 đòi nó "nằm trong bundle app, không CDN, không network".
#
# BƯỚC NÀY TỪNG BỊ BỎ SÓT, và kiểu hỏng của nó đáng ghi lại. `MermaidAsset.candidates` tìm
# `Contents/Resources/mermaid/` trước, rồi LÙI về `vendor/mermaid/` trong cây làm việc. Trên
# máy dev đường lùi luôn có, nên mọi thứ chạy đúng và không ai thấy gì. Trong bundle App Store
# thì cây làm việc không tồn tại — mà kể cả tồn tại, sandbox cũng chặn — nên toàn bộ cụm
# FR-MMD chết lặng ở tay người dùng: sơ đồ không vẽ, Mermaid Studio không mở, báo cáo mất hình.
#
# Đúng lớp lỗi mà `HeavyGrammars` đã mắc với `argv[0]`: một đường lùi tiện lúc phát triển che
# mất việc đường chính chưa bao giờ được nối. `./scripts/run-self-test.sh --bundle appstore`
# là chỗ bắt được — nó báo đỏ 20 bài khi thiếu tệp này.
if [ -f "vendor/mermaid/mermaid.min.js" ]; then
    mkdir -p "$APP/Contents/Resources/mermaid"
    # Chép cả LICENSE và VERSION.json: giấy phép phải đi cùng mã đã đóng gói, còn VERSION.json
    # là thứ hộp About đọc để hiện số phiên bản mà NFR-MMD-02 đòi.
    cp vendor/mermaid/mermaid.min.js vendor/mermaid/LICENSE vendor/mermaid/VERSION.json \
       "$APP/Contents/Resources/mermaid/"
else
    echo "⚠️  KHÔNG có vendor/mermaid/mermaid.min.js — bundle này sẽ KHÔNG vẽ được sơ đồ nào."
    echo "   Chạy scripts/vendor-mermaid.sh rồi dựng lại."
fi
# CLI chỉ đi cùng bản trực tiếp. App Store không cho đặt tệp ra ngoài vùng chứa, và cầu nối
# socket cũng đứt khi app bị giam trong container — xem Distribution.swift.
if [ "$WITH_CLI" = "1" ]; then
    cp "$BUILD_DIR/geditor" "$DIST_DIR/geditor"
else
    rm -f "$DIST_DIR/geditor"
fi
# Sparkle — kênh tự cập nhật (NFR-SEC-01, ADR-16). LIÊN KẾT lúc nạp, khác `libduckdb`: giá đo
# được chỉ 1,3 ms, không đáng đổi lấy một đường nạp lười. Nhưng nó vẫn phải nằm trong
# `Contents/Frameworks` vì `@rpath` trỏ tới đó và vì đó là chỗ duy nhất codesign chấp nhận.
#
# Ở đây KHÔNG có nhánh "thiếu thì bỏ qua" như DuckDB: thiếu `libduckdb` là mất một tính năng và
# app nói ra được; thiếu Sparkle là app KHÔNG CHẠY, vì nó liên kết lúc nạp. Hỏng sớm và hỏng to
# đúng hơn hỏng lúc người dùng mở app.
if [ ! -d "vendor/sparkle/Sparkle.framework" ]; then
    echo "❌ Thiếu vendor/sparkle/Sparkle.framework — chạy scripts/vendor-sparkle.sh"
    exit 1
fi
cp -R "vendor/sparkle/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

# Tiến trình phụ nạp plugin native (ADR-12 phương án C) — CHỈ bản tải trực tiếp.
#
# THIẾU BƯỚC NÀY LÀ MỘT LỖI THẬT, SỐNG TỚI 28/08/2026: `NativePluginBridge.hostCandidates()`
# tìm ở `Contents/SharedSupport` rồi `Contents/MacOS`, còn script này chưa bao giờ chép nó vào
# đâu cả. Hậu quả: FR-PLUG-702/703/704 chạy khi khởi động từ `.build` (tiến trình phụ nằm cạnh
# binary) và IM LẶNG BIẾN MẤT trong mọi bundle người dùng nhận được.
#
# Không ai bắt được vì `run-self-test.sh` mặc định chạy binary trần; sáu bài tự kiểm plugin chỉ
# đỏ khi chạy `--bundle`, và CI chưa từng chạy đường ấy. Nay CI chạy cả hai.
if [ "$WITH_CLI" = "1" ]; then
    cp "$BUILD_DIR/geditor-plugin-host" "$APP/Contents/MacOS/geditor-plugin-host"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"

# Icon ứng dụng — biểu tượng PTIT chính thức.
#
# `Info.plist` khai `CFBundleIconFile = AppIcon` từ đầu, nhưng tệp `AppIcon.icns` thì KHÔNG có
# trong kho cho tới 16/09/2026: bản dựng chạy với icon trắng mặc định của macOS, và không gì
# báo — `CFBundleIconFile` trỏ vào một tệp không tồn tại là chuyện Finder im lặng bỏ qua.
#
# Dựng lại icon: `python3 scripts/sinh_icon_ptit.py` (tách biểu tượng khỏi wordmark, chừa lề,
# rsvg-convert + iconutil). Nguồn là `docs/logo-ptit-1.svg`.
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
    echo "⚠ thiếu Resources/AppIcon.icns — bản dựng sẽ mang icon trắng mặc định"
fi

# NFR-SEC-01 — KHÔNG ĐƯỢC KÝ một bản mang khoá cập nhật giữ chỗ.
#
# Bản chưa ký thì cho qua: người ta dựng nó hàng chục lần một ngày để thử. Bản ĐÃ KÝ thì khác —
# nó là thứ đi ra ngoài, và một kênh cập nhật trỏ tới khoá không tồn tại sẽ hỏng đúng lúc nó
# quan trọng nhất: khi có bản vá cần đẩy đi. Cổng đặt ở đây vì đây là chỗ hẹp duy nhất mà mọi
# bản giao đều đi qua.
if grep -q "CHUA-CO-KHOA-THAT" "$APP/Contents/Info.plist"; then
    if [ -n "${GEDITOR_SIGN_IDENTITY:-}" ]; then
        echo "❌ NFR-SEC-01: Info.plist còn mang SUPublicEDKey GIỮ CHỖ, không ký được."
        echo "   Sinh khoá thật: vendor/sparkle/bin/generate_keys (Keychain sẽ hỏi quyền),"
        echo "   rồi thay SUPublicEDKey trong Resources/Info.plist. Xem docs/khoa-va-ky.md."
        exit 1
    fi
    echo "⚠️  SUPublicEDKey còn là chỗ giữ chỗ — bản này KHÔNG tự cập nhật được."
    echo "   Không sao với bản dựng thử; bản ký thật sẽ bị chặn."
fi
# Từ điển AppleScript (FR-AUTO-606). `OSAScriptingDefinition` trong Info.plist trỏ tới file này
# theo tên; thiếu nó thì Script Editor thấy ứng dụng nhưng từ điển RỖNG, và người dùng kết luận
# GEditor không hỗ trợ AppleScript.
mkdir -p "$APP/Contents/Resources"
cp Resources/GEditor.sdef "$APP/Contents/Resources/GEditor.sdef"

# Biểu tượng ứng dụng — sinh từ ảnh nguồn, không commit bản .icns (xem `scripts/make-icon.sh`).
#
# DỪNG khi hỏng thay vì dựng tiếp: một bản giao thiếu biểu tượng vẫn chạy được, nên lỗi này
# không lộ ra ở bất kỳ bài kiểm nào — nó chỉ lộ ra khi người dùng đã tải app về và thấy một ô
# trắng trong Dock.
if ! ./scripts/make-icon.sh "$APP/Contents/Resources/AppIcon.icns" >/dev/null; then
    echo "❌ không dựng được biểu tượng ứng dụng"
    exit 1
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Bỏ bảng ký hiệu cục bộ khỏi bản GIAO (ADR-08 §2.12).
#
# Bảng ấy không được dùng một lần nào lúc chạy, nhưng nó nằm trong cùng file mà dyld phải đọc
# và nhân phải kiểm chữ ký từng trang ở lần khởi động đầu tiên. Đo được: 2,13 MB bỏ đi đổi
# lấy ~68 ms khởi động nguội — đúng cái khoản làm NFR-PERF-01 trượt trần 500 ms.
#
# `-x` chứ không phải `strip` trần: `-x` chỉ bỏ ký hiệu CỤC BỘ, giữ nguyên ký hiệu toàn cục và
# metadata mà Swift runtime cần. Strip trần một binary Swift là cách làm hỏng reflection theo
# kiểu chỉ lộ ra lúc chạy.
#
# Phải đứng TRƯỚC codesign: strip sửa file, nên ký trước rồi strip là tự phá chữ ký của mình.
#
# Bản CHƯA strip được giữ lại. Không có nó thì một crash report từ người dùng chỉ còn dãy địa
# chỉ, và ký hiệu cục bộ — tức mọi hàm `private` — không dựng lại được nữa.
echo
echo "▸ Bỏ bảng ký hiệu khỏi bản giao (ADR-08 §2.12), giữ bản đầy đủ để giải mã crash:"
mkdir -p "$DIST_DIR/symbols"
STRIPPABLE=("$APP/Contents/MacOS/GEditor" "$APP/Contents/Frameworks/libTreeSitterHeavy.dylib")
[ "$WITH_CLI" = "1" ] && STRIPPABLE+=("$DIST_DIR/geditor")
for binary in "${STRIPPABLE[@]}"; do
    cp "$binary" "$DIST_DIR/symbols/$(basename "$binary")"
    before=$(stat -f %z "$binary")
    strip -x "$binary"
    after=$(stat -f %z "$binary")
    printf '  %-28s %5.2f → %5.2f MB\n' "$(basename "$binary")" \
        "$(echo "$before" | awk '{print $1/1048576}')" \
        "$(echo "$after" | awk '{print $1/1048576}')"
done

echo
echo "▸ Kiểm tra kiến trúc (NFR-PORT-01):"
status=0
BINARIES=("$APP/Contents/MacOS/GEditor" "$APP/Contents/Frameworks/libTreeSitterHeavy.dylib")
[ "$WITH_CLI" = "1" ] && BINARIES+=("$DIST_DIR/geditor")
for binary in "${BINARIES[@]}"; do
    info=$(lipo -info "$binary")
    echo "  $info"
    for arch in arm64 x86_64; do
        if ! echo "$info" | grep -q "$arch"; then
            echo "  ❌ THIẾU kiến trúc $arch trong $binary"
            status=1
        fi
    done
done
[ $status -eq 0 ] && echo "  ✅ Cả hai kiến trúc có mặt trong mọi artefact"

# Grammar nặng phải nạp LƯỜI, không nằm trên đường khởi động (ADR-08 phương án C).
if otool -L "$APP/Contents/MacOS/GEditor" | grep -q "TreeSitterHeavy"; then
    echo "  ❌ Binary chính liên kết thẳng vào libTreeSitterHeavy — dyld sẽ nạp nó ở mọi lần"
    echo "     khởi động, và phần tiết kiệm của ADR-08 biến mất mà không tính năng nào hỏng."
    status=1
else
    echo "  ✅ Grammar nặng nạp lười qua dlopen, không nằm trên đường khởi động"
fi

# Chốt chặn cho bước strip ở trên (ADR-08 §2.12).
#
# Kiểu hỏng ở đây không làm tính năng nào sai — nó chỉ làm app chậm đi ~68 ms ở lần khởi động
# đầu, tức là không ai thấy cho tới lúc đo lại KPI và không hiểu vì sao số xấu đi. Nên hỏi
# thẳng bản giao: còn ký hiệu cục bộ nào không.
# Chốt chặn cho ADR-12: app CHÍNH không được nới library validation.
#
# Plugin native chạy ở TIẾN TRÌNH RIÊNG chính là để app chính giữ nguyên hàng rào này. Nếu một
# ngày entitlement mọc thêm `disable-library-validation`, đó là dấu hiệu ai đó đã bỏ phương án
# C mà không sửa ADR — và hậu quả là mọi người dùng, kể cả người không cài plugin nào, chạy một
# app đã tắt mất phép kiểm chữ ký thư viện.
#
# Hỏi KHOÁ trong plist, không `grep` văn bản — và hỏi bằng PlistBuddy, không bằng plutil.
#
# Chốt chặn này sai hai lần trước khi đúng, cả hai lần đều đáng ghi lại:
#
#   1. `grep -q "disable-library-validation"` → ĐỎ ngay lần chạy đầu, vì chính file entitlement
#      có một dòng CHÚ THÍCH liệt kê tên ấy trong danh sách "cố ý KHÔNG có ở đây".
#   2. `plutil -extract "com.apple.security.cs.disable-library-validation"` → XANH vĩnh viễn,
#      vì plutil coi dấu CHẤM là dấu phân cấp: nó đi tìm khoá `com` rồi `apple` rồi `security`.
#      Kiểm thử: cùng lệnh ấy cũng không thấy nổi `com.apple.security.app-sandbox` trong bản
#      App Store, một khoá chắc chắn có thật.
#
# Cái sai thứ hai tệ hơn hẳn cái thứ nhất: cổng đỏ nhầm thì có người tới sửa, cổng xanh nhầm
# thì không ai biết nó đã ngừng canh gì. PlistBuddy dùng `:` làm dấu phân cấp nên dấu chấm
# trong tên khoá không thành vấn đề. Đã kiểm CẢ HAI CHIỀU.
if /usr/libexec/PlistBuddy -c \
        "Print :com.apple.security.cs.disable-library-validation" \
        "$ENTITLEMENTS" >/dev/null 2>&1; then
    echo "  ❌ $ENTITLEMENTS xin disable-library-validation — ADR-12 §4 cấm với app CHÍNH."
    echo "     Plugin native phải chạy ở tiến trình riêng; chỉ tiến trình ấy mới được xin."
    status=1
else
    echo "  ✅ App chính giữ nguyên library validation (ADR-12)"
fi

locals=$(nm "$APP/Contents/MacOS/GEditor" 2>/dev/null | awk '$2 ~ /^[a-z]$/' | wc -l | tr -d ' ')
if [ "$locals" != "0" ]; then
    echo "  ❌ Binary giao còn $locals ký hiệu cục bộ — bước strip không chạy."
    status=1
else
    echo "  ✅ Bản giao đã bỏ bảng ký hiệu cục bộ"
fi

echo
# Ký số (NFR-SEC-01).
#
# Entitlement được áp NGAY TỪ BẢN AD-HOC, không đợi tới lúc phát hành: PCRE2 JIT (ADR-03)
# cần com.apple.security.cs.allow-jit khi có hardened runtime. Nếu chỉ thêm ở bước phát hành
# thì lỗi thiếu entitlement chỉ lộ ra SAU KHI đã notarize — quá muộn để sửa rẻ.
#
# Có GEDITOR_SIGN_IDENTITY thì ký thật kèm hardened runtime; không có thì ký ad-hoc để bản
# dựng hằng ngày vẫn chạy được. Cùng MỘT đường mã, khác đúng một biến môi trường — đường phát
# hành không được là một nhánh chỉ chạy vài lần trong đời dự án.
# KÝ TỪ TRONG RA NGOÀI, và KHÔNG dùng `--deep`.
#
# `--deep` ký mọi thứ lồng bên trong bằng CÙNG một entitlement với app — mà tiến trình phụ nạp
# plugin cần `disable-library-validation` còn app chính thì tuyệt đối không được có (ADR-12).
# Với `--deep` thì hoặc app được nới hàng rào, hoặc tiến trình phụ mất quyền nó cần; không có
# đường thứ ba. Apple cũng khuyến nghị không dùng `--deep` cho bản phát hành vì đúng lý do này.
#
# Thứ tự bắt buộc là TỪ TRONG RA: ký thứ lồng bên trong trước, rồi mới ký bundle. Ký ngược lại
# thì chữ ký của bundle niêm phong nội dung cũ, và mỗi lần ký một thứ bên trong là một lần phá
# con dấu vừa đóng.
ky_mot() {
    local muc="$1" ent="$2"
    local co=(--force --sign "$IDENTITY_OR_ADHOC")
    [ -n "$IDENTITY" ] && co+=(--options runtime --timestamp)
    [ -n "$ent" ] && co+=(--entitlements "$ent")
    if ! output=$(codesign "${co[@]}" "$muc" 2>&1); then
        echo "$output" | sed 's/^/  /'
        echo "  ❌ Ký số THẤT BẠI ở $muc — dừng, không dựng ra bản không ký được."
        exit 1
    fi
    [ -n "$output" ] && echo "$output" | sed 's/^/  /'
    return 0
}

if [ -n "$IDENTITY" ]; then
  IDENTITY_OR_ADHOC="$IDENTITY"
  echo "▸ Ký số ($CHANNEL): $IDENTITY"
else
  IDENTITY_OR_ADHOC="-"
  case "$CHANNEL" in
      appstore) echo "▸ Ký số (ad-hoc — đặt GEDITOR_APPSTORE_IDENTITY để ký thật, NFR-SEC-01):" ;;
      direct)   echo "▸ Ký số (ad-hoc — đặt GEDITOR_SIGN_IDENTITY để ký thật, NFR-SEC-01):" ;;
  esac
fi

# 1. Thư viện lồng bên trong — không entitlement, chúng không phải tiến trình.
for muc in "$APP/Contents/Frameworks/"*; do
    [ -e "$muc" ] || continue
    ky_mot "$muc" ""
done

# 2. Tiến trình phụ — entitlement RIÊNG của nó (ADR-12).
if [ -f "$APP/Contents/MacOS/geditor-plugin-host" ]; then
    ky_mot "$APP/Contents/MacOS/geditor-plugin-host" "Resources/GEditorPluginHost.entitlements"
fi

# 3. Sau cùng mới tới bundle.
ky_mot "$APP" "$ENTITLEMENTS"

if [ -n "$IDENTITY" ]; then
  # Kiểm ngay tại chỗ: chữ ký hỏng mà tới bước notarize mới biết là mất một vòng chờ Apple.
  if ! output=$(codesign --verify --strict --verbose=2 "$APP" 2>&1); then
    echo "$output" | sed 's/^/  /'
    echo "  ❌ Chữ ký không qua kiểm."
    exit 1
  fi
  echo "$output" | sed 's/^/  /'
  spctl --assess --type execute --verbose "$APP" 2>&1 | sed 's/^/  /' || true
fi

echo
echo "▸ Entitlement đã ký vào bundle:"
codesign -d --entitlements - --xml "$APP" 2>/dev/null \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | grep -E "com\.apple\.security" | sed 's/^/  /' || echo "  (không đọc được)"

# Công chứng (notarization). Chỉ chạy khi có ĐỦ thông tin đăng nhập — thiếu một cái là bỏ
# qua chứ không hỏi tương tác: script này còn chạy trong CI, nơi không ai gõ được gì.
#
#   GEDITOR_SIGN_IDENTITY  "Developer ID Application: TÊN (TEAMID)"
#   GEDITOR_NOTARY_PROFILE hồ sơ đã lưu bằng `xcrun notarytool store-credentials`
if [ "$CHANNEL" = "direct" ] && [ -n "$IDENTITY" ] && [ -n "${GEDITOR_NOTARY_PROFILE:-}" ]; then
  echo
  echo "▸ Công chứng qua Apple (notarytool)"
  ZIP="$(dirname "$APP")/GEditor-notarize.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  if output=$(xcrun notarytool submit "$ZIP" --keychain-profile "$GEDITOR_NOTARY_PROFILE" --wait 2>&1); then
    echo "$output" | sed 's/^/  /'
    # Đóng dấu vào chính bundle: máy người dùng phải xác minh được kể cả khi ngoại tuyến.
    xcrun stapler staple "$APP" 2>&1 | sed 's/^/  /'
    xcrun stapler validate "$APP" 2>&1 | sed 's/^/  /'
  else
    echo "$output" | sed 's/^/  /'
    echo "  ❌ Công chứng thất bại — xem \`xcrun notarytool log\` với id ở trên"
    rm -f "$ZIP"
    exit 1
  fi
  rm -f "$ZIP"
elif [ "$CHANNEL" = "direct" ] && [ -n "$IDENTITY" ]; then
  echo
  echo "▸ Bỏ qua công chứng: chưa có GEDITOR_NOTARY_PROFILE"
  echo "  Tạo một lần bằng:"
  echo "    xcrun notarytool store-credentials geditor \\"
  echo "      --apple-id <email> --team-id <TEAMID> --password <app-specific-password>"
fi

# Bản App Store nộp dưới dạng .pkg, không phải .app hay .zip.
#
# Công chứng KHÔNG áp dụng ở kênh này: App Store tự kiểm khi nhận, và `notarytool` trên một
# bundle ký bằng 3rd Party Mac Developer sẽ bị từ chối.
if [ "$CHANNEL" = "appstore" ]; then
  INSTALLER="${GEDITOR_APPSTORE_INSTALLER_IDENTITY:-}"
  if [ -n "$IDENTITY" ] && [ -n "$INSTALLER" ]; then
    echo
    echo "▸ Đóng gói .pkg để nộp App Store"
    PKG="$DIST_DIR/GEditor.pkg"
    if ! output=$(productbuild --component "$APP" /Applications --sign "$INSTALLER" "$PKG" 2>&1); then
      echo "$output" | sed 's/^/  /'
      echo "  ❌ Đóng gói .pkg THẤT BẠI"
      exit 1
    fi
    echo "$output" | sed 's/^/  /'
    echo "  Nộp bằng: xcrun altool --upload-app -f $PKG -t macos ..."
  else
    echo
    echo "▸ Bỏ qua .pkg: cần CẢ HAI danh tính"
    echo "    GEDITOR_APPSTORE_IDENTITY            \"3rd Party Mac Developer Application: … (TEAMID)\""
    echo "    GEDITOR_APPSTORE_INSTALLER_IDENTITY  \"3rd Party Mac Developer Installer: … (TEAMID)\""
  fi
fi

echo
echo "▸ Xong: $APP"
[ "$WITH_CLI" = "1" ] && echo "▸ CLI:  $DIST_DIR/geditor"
exit $status
