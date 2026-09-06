#!/bin/bash
# Chặn import framework UI vào target lõi — NFR-MNT-01, SAD §2.2.
#
# Vì sao là bước CHẶN MERGE chứ không phải quy ước: lõi phải test được không cần app,
# tái sử dụng được đa nền tảng, và chạy được trong XPC service. Một dòng `import AppKit`
# lọt vào Core sẽ kéo theo cả UI vào mọi nơi dùng lõi — và không ai phát hiện cho tới
# lúc đã quá muộn để gỡ.
set -uo pipefail

cd "$(dirname "$0")/.."

CORE_PATHS=("Sources/GEditorCore" "Sources/GEditorSIMD" "Sources/PCRE2")
FORBIDDEN=("AppKit" "SwiftUI" "UIKit" "Cocoa" "WebKit" "QuartzCore")

status=0

for framework in "${FORBIDDEN[@]}"; do
    for path in "${CORE_PATHS[@]}"; do
        [ -d "$path" ] || continue
        # Bỏ qua chú thích: chỉ bắt dòng import thật.
        hits=$(grep -rn --include='*.swift' --include='*.h' --include='*.c' \
            -E "^[[:space:]]*(@_exported[[:space:]]+)?import[[:space:]]+${framework}\b|^[[:space:]]*#import[[:space:]]+<${framework}/" \
            "$path" || true)
        if [ -n "$hits" ]; then
            echo "❌ VI PHẠM NFR-MNT-01 — lõi import ${framework}:"
            echo "$hits"
            status=1
        fi
    done
done

if [ $status -eq 0 ]; then
    echo "✅ NFR-MNT-01: lõi độc lập UI (không import ${FORBIDDEN[*]})"
fi

# FR-UI-804: bảng dịch KHÔNG được có khoá trùng.
#
# Swift không bắt lỗi này lúc biên dịch — một dictionary literal có khoá trùng chỉ chết khi
# CHẠY, ở đúng dòng đầu tiên đọc tới bảng. Với một bảng vài trăm dòng mà nhiều người thêm vào
# thì trùng là chuyện sớm muộn, và triệu chứng ("Fatal error: Dictionary literal contains
# duplicate keys") không nói cho ai biết khoá nào.
#
# Soát TỪNG bảng một. Trùng chỉ có nghĩa TRONG một bảng: cùng một khoá xuất hiện ở bảng tiếng
# Anh và bảng tiếng Nhật là chuyện đương nhiên, gộp hết lại rồi `uniq -d` thì mọi khoá đều "trùng".
#
# Và soát `Localization+*.swift` chứ không phải `Localization.swift`: bảng đã tách ra từng tệp
# theo mã ngôn ngữ, còn tệp cũ nay chỉ giữ phần lõi. Cổng vẫn chạy xanh sau lần tách ấy — vì nó
# soi một tệp KHÔNG CÒN bảng nào. Cổng chỉ canh được đúng thứ nó soi.
bang_dich=(Sources/GEditorApp/Localization+*.swift)
if [ ! -e "${bang_dich[0]}" ]; then
    echo "❌ FR-UI-804: không thấy tệp bảng dịch nào (Localization+*.swift)"
    exit 1
fi
for bang in "${bang_dich[@]}"; do
    DUPES="$(grep -oE '^\s+"[^"]+":' "$bang" | sed 's/^ *//;s/:$//' | sort | uniq -d)"
    if [ -n "$DUPES" ]; then
        echo "❌ FR-UI-804: $bang có khoá trùng:"
        echo "$DUPES" | sed 's/^/   /'
        exit 1
    fi
done
echo "✅ FR-UI-804: ${#bang_dich[@]} bảng dịch, không bảng nào có khoá trùng"

# FR-AUTO-606: từ điển AppleScript phải hợp lệ theo DTD của hệ thống.
#
# Một `.sdef` sai cú pháp KHÔNG làm ứng dụng chết — macOS chỉ lặng lẽ nạp một từ điển rỗng, và
# triệu chứng là Script Editor mở ra thấy trắng trơn. Không ai phát hiện cho tới khi có người
# thật ngồi viết script.
if [ -f /System/Library/DTDs/sdef.dtd ]; then
    if xmllint --noout --dtdvalid /System/Library/DTDs/sdef.dtd Resources/GEditor.sdef 2>/dev/null; then
        echo "✅ FR-AUTO-606: GEditor.sdef hợp lệ theo DTD hệ thống"
    else
        echo "❌ FR-AUTO-606: GEditor.sdef không hợp lệ"
        xmllint --noout --dtdvalid /System/Library/DTDs/sdef.dtd Resources/GEditor.sdef
        exit 1
    fi
fi

# FR-UI-801 — nền vẽ bằng layer phải đi qua `applyLayerBackground`.
#
# `.cgColor` là một ảnh chụp: gán thẳng vào `layer.backgroundColor` thì màu đứng nguyên khi
# người dùng đổi theme, trong khi phần vẽ bằng `draw(_:)` đổi theo. Kiểu hỏng ấy không làm tính
# năng nào sai — cửa sổ chỉ thành hai nửa hai màu, và chỉ ai đổi theme mới thấy.
#
# Chừa `DesignTokens.swift`: chính nó là chỗ gán duy nhất được phép.
layers=$(grep -rn "backgroundColor = .*\.cgColor" Sources/GEditorApp/*.swift \
    | grep -v "DesignTokens.swift" | wc -l | tr -d ' ')
if [ "$layers" != "0" ]; then
    echo "❌ FR-UI-801: $layers chỗ gán thẳng layer.backgroundColor bằng .cgColor —"
    echo "   dùng applyLayerBackground(_:) và override viewDidChangeEffectiveAppearance()."
    grep -rn "backgroundColor = .*\.cgColor" Sources/GEditorApp/*.swift | grep -v DesignTokens
    status=1
else
    echo "✅ FR-UI-801: nền layer đi qua applyLayerBackground, theo được theme"
fi

# NFR-PERF-07 — KHÔNG polling nền.
#
# Chỉ tiêu viết rõ: "không polling nền; dùng FSEvents/Dispatch Source thay vì vòng lặp kiểm
# tra". Vế ấy kiểm được bằng mắt máy, khác hẳn vế "Energy Impact: Low" của Activity Monitor —
# cái nhãn ấy không có API nào trả về, và `GEditorApp --measure-idle` chỉ đo được SỐ THAY THẾ.
#
# Vì sao cần cả cổng tĩnh này khi đã có phép đo: phép đo chỉ thấy thứ đang chạy lúc nhàn rỗi
# với MỘT tab văn bản nhỏ. Một vòng hỏi chỉ bật lên khi mở thư mục, khi bật theo dõi file, hay
# khi cửa sổ thứ hai xuất hiện thì phép đo không chạm tới — còn `grep` thì thấy ngay.
#
# Danh sách dưới đây TỰ DỌN: cổng đỏ cả khi có chỗ MỚI lẫn khi một chỗ đã khai biến mất. Chỉ
# chặn chiều thêm vào thì danh sách sẽ thành nơi giấu nợ, đúng bài học của
# `SelfTest.menuItemsPendingImplementation`.
#
# Khai theo "tệp|mẫu|lý do". Phân tách bằng `|` chứ không phải `:` — chính các mẫu có chứa dấu
# hai chấm ("repeats: true"), và bản đầu tách bằng `:` đã cắt mẫu thành "repeats" rồi báo đỏ
# nhầm cho đúng dòng đã khai.
declare -a POLLING_ALLOWED=(
    "Sources/GEditorApp/MainWindowController.swift|repeats: true|nhịp tự lưu FR-DOC-304 — hẹn giờ để GHI, không phải để hỏi xem có gì đổi"
    "Sources/GEditorCore/Automation/TextFilter.swift|usleep(|chờ tiến trình lọc chạy xong; chỉ sống trong lúc người dùng đang chạy bộ lọc, không phải nền"
    "Sources/GEditorCore/CSV/CSVQueryEngine.swift|Thread.sleep|luồng canh nút Hủy của truy vấn DuckDB; CancelToken là kiểu HỎI chứ không gọi lại, mà duckdb_interrupt phải gọi từ luồng khác. Chỉ sống trong lúc câu truy vấn đang chạy — chết ngay khi xong, không phải vòng hỏi NỀN"
    "Sources/GEditorCore/Knowledge/CorpusSQL.swift|Thread.sleep|CÙNG luồng canh Hủy ấy, cho đường vào corpus (FR-KNW-907). Hai bản của một vòng canh là điều đáng tiếc, nhưng gộp chúng đòi CSVQueryEngine phơi ra phần nội bộ của nó — và cổng này chính là thứ giữ cho bản thứ hai không nhân lên thành bản thứ ba mà không ai để ý"
)

polling_status=0
# Đếm mọi chỗ có mẫu, rồi trừ đi những chỗ đã khai.
for pattern in "repeats: true" "usleep(" "Thread.sleep"; do
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        file="${hit%%:*}"
        declared=0
        for entry in "${POLLING_ALLOWED[@]}"; do
            entry_file="${entry%%|*}"
            entry_rest="${entry#*|}"
            entry_pattern="${entry_rest%%|*}"
            if [ "$file" = "$entry_file" ] && [ "$entry_pattern" = "$pattern" ]; then
                declared=1
                break
            fi
        done
        if [ "$declared" = "0" ]; then
            echo "❌ NFR-PERF-07: vòng hỏi/hẹn giờ CHƯA KHAI — $hit"
            echo "   Sửa cho nó thành hướng sự kiện (FSEvents / DispatchSource), hoặc khai vào"
            echo "   POLLING_ALLOWED trong scripts/check-core-no-ui.sh kèm lý do."
            polling_status=1
        fi
    done <<< "$(grep -rn --include='*.swift' -F "$pattern" Sources/GEditorApp Sources/GEditorCore \
        | grep -v -E '^[^:]+:[0-9]+: *//' || true)"
done

# Chiều ngược lại: chỗ đã khai mà không còn thì phải xoá khỏi danh sách.
for entry in "${POLLING_ALLOWED[@]}"; do
    entry_file="${entry%%|*}"
    entry_rest="${entry#*|}"
    entry_pattern="${entry_rest%%|*}"
    if ! grep -q -F "$entry_pattern" "$entry_file" 2>/dev/null; then
        echo "❌ NFR-PERF-07: đã khai \"$entry_pattern\" ở $entry_file nhưng chỗ ấy không còn —"
        echo "   xoá dòng tương ứng khỏi POLLING_ALLOWED."
        polling_status=1
    fi
done

if [ "$polling_status" = "0" ]; then
    echo "✅ NFR-PERF-07: không có vòng hỏi nền nào ngoài ${#POLLING_ALLOWED[@]} chỗ đã khai"
else
    status=1
fi

# FR-UI-804 — nợ bản dịch KHÔNG được phình thêm.
#
# 558 chuỗi tiếng Việt trong tầng giao diện chưa có bản tiếng Anh. Con số ấy quá lớn để bắt
# phải về 0 hôm nay, nhưng để nó tự do lớn lên thì mục FR-UI-804 sẽ mãi mãi "gần xong".
#
# Cổng chốt HAI CHIỀU: đỏ khi tăng, và cũng đỏ khi giảm mà quên hạ mốc. Chỉ chặn chiều tăng thì
# mốc đứng yên kể cả khi nợ đã trả bớt, và một con số không còn đúng thì không ai tin nó nữa.
if ! python3 scripts/scan-untranslated.py --tran 359; then
    status=1
fi

# Info.plist phải khai ĐỦ những kiểu tệp app mở được.
#
# Vì sao là cổng chứ không phải một lần soát: hai danh sách này sống ở hai chỗ và không có gì
# buộc chúng đi cùng nhau. Thêm một `MediaKind` mà quên khai vào plist thì app vẫn mở được tệp
# khi kéo thả — nhưng Finder KHÔNG hiện GEditor ở "Mở bằng", và nó vắng mặt một cách im lặng.
# Không ai báo lỗi, không bài kiểm nào đỏ; chỉ là người dùng không tìm thấy đường mở.
#
# Cổng đi theo chiều "mã → plist": mỗi loại trong `MediaKind` phải có ít nhất một UTI đại diện
# được khai. Chiều ngược lại (plist khai thừa) vô hại nên không chặn.
declare -a UTI_REQUIRED=(
    "image|public.image"
    "pdf|com.adobe.pdf"
    "word|org.openxmlformats.wordprocessingml.document"
    "excel|org.openxmlformats.spreadsheetml.sheet"
    "powerpoint|org.openxmlformats.presentationml.presentation"
    "archive|public.zip-archive"
    "audio|public.audio"
    "video|public.movie"
)
uti_status=0
for entry in "${UTI_REQUIRED[@]}"; do
    kind="${entry%%|*}"
    uti="${entry#*|}"
    if ! grep -q "case ${kind}$" Sources/GEditorCore/Archive/MediaKind.swift; then
        echo "❌ Info.plist: cổng khai «${kind}» nhưng MediaKind không còn loại ấy —"
        echo "   xoá dòng tương ứng khỏi UTI_REQUIRED trong scripts/check-core-no-ui.sh."
        uti_status=1
    elif ! grep -q "<string>${uti}</string>" Resources/Info.plist; then
        echo "❌ Info.plist: mở được «${kind}» mà chưa khai UTI «${uti}» —"
        echo "   Finder sẽ không hiện GEditor ở «Mở bằng» cho loại tệp này."
        uti_status=1
    fi
done
# Ba kiểu macOS không biết sẵn phải được KHAI NHẬP, nếu không thì `LSItemContentTypes` trỏ vào
# một UTI không tồn tại và dòng khai ấy thành vô nghĩa.
for uti in org.7-zip.7-zip-archive com.rarlab.rar-archive org.tukaani.xz-archive; do
    if grep -q "<string>${uti}</string>" Resources/Info.plist; then
        if ! plutil -extract UTImportedTypeDeclarations raw Resources/Info.plist >/dev/null 2>&1; then
            echo "❌ Info.plist: dùng «${uti}» mà không có UTImportedTypeDeclarations."
            uti_status=1
        fi
    fi
done
if [ "$uti_status" = "0" ]; then
    echo "✅ Info.plist: ${#UTI_REQUIRED[@]} loại tệp mở được đều đã khai với hệ điều hành"
else
    status=1
fi

# ADR-14 — framework hệ thống liên kết LÚC NẠP phải được KHAI, không được lẻn vào.
#
# Anh chốt 26/08/2026: bundle được phép to ra, khởi động thì không. Vế "dylib của ta phải chưa
# nạp" đã có cổng chạy lúc khởi động (`LazyLoadAudit`, hỏi thẳng nhân). Vế còn lại là thứ cổng
# ấy KHÔNG bắt được: một `import WebKit` mới thêm không nạp gì thêm lúc chạy — WebKit vốn đã
# nằm sẵn trong tiến trình do AppKit kéo vào — nhưng nó là dấu hiệu có người sắp dựng một
# `WKWebView` ở đâu đó, và chỗ ấy phải lười.
#
# Nên cổng này không cấm; nó bắt KHAI. Thêm một framework vào đây là một hành động có chủ ý, và
# người thêm phải viết ra vì sao — đúng khuôn POLLING_ALLOWED ở trên.
#
# Con số đi kèm mỗi dòng là giá liên kết ĐÃ ĐO (phương pháp PoC-L: hai binary khác nhau đúng một
# cờ -framework, 15 lần mỗi bên, có sàn nhiễu). Không đo thì đừng thêm.
LINKED_FRAMEWORKS_ALLOWED=(
    "JavaScriptCore|FR-AUTO-603 chạy script; +1,8 ms trên sàn nhiễu 1,4 ms — JSContext vẫn lười"
    "WebKit|FR-RPT-001 xem trước báo cáo; +1,4 ms trên sàn nhiễu 0,9 ms (PoC-L) — WKWebView vẫn lười"
    "Sparkle|NFR-SEC-01 tự cập nhật; +1,3 ms trên sàn nhiễu ~1 ms (ADR-16 §3) — SPUStandardUpdaterController vẫn lười"
    "PDFKit|khung xem/chú thích PDF; +0,31 ms trên sàn nhiễu 8,3 ms (PoC-N) — PDFView vẫn lười"
    "AVFoundation|khung phát nhạc·phim; AppKit đã kéo nó vào tiến trình dù KHÔNG liên kết (PoC-O đo được avfoundationLoaded=1 ở cả bản không liên kết)"
    "AVKit|khung phát nhạc·phim; +4,08 ms trên sàn nhiễu 6,88 ms (PoC-O) — AVPlayerView vẫn lười"
)

linked_status=0
APP_BIN="$(swift build -c release --product GEditorApp --show-bin-path 2>/dev/null)/GEditorApp"
if [ -f "$APP_BIN" ]; then
    # Chỉ soi framework NẶNG. Danh sách này là thứ có engine riêng bên trong — chúng là thứ
    # đáng hỏi "sao lại liên kết lúc nạp"; AppKit hay Foundation thì không.
    # `Sparkle` không phải framework hệ thống nhưng thuộc đúng loại đáng hỏi: nó có engine
    # riêng (mạng, phân tích XML, sinh tiến trình cài đặt). Vendor hay không vendor không
    # đổi được câu hỏi "sao lại liên kết lúc nạp".
    for heavy in JavaScriptCore WebKit CoreML Metal SceneKit AVFoundation Sparkle PDFKit; do
        if otool -L "$APP_BIN" 2>/dev/null | grep -q "/$heavy.framework/"; then
            declared=0
            for entry in "${LINKED_FRAMEWORKS_ALLOWED[@]}"; do
                [ "${entry%%|*}" = "$heavy" ] && declared=1
            done
            if [ "$declared" = "0" ]; then
                echo "❌ ADR-14: GEditorApp liên kết $heavy LÚC NẠP mà chưa khai."
                echo "   Hoặc bỏ 'import $heavy' và nạp lười bằng dlopen, hoặc đo giá liên kết"
                echo "   rồi khai vào LINKED_FRAMEWORKS_ALLOWED kèm con số."
                linked_status=1
            fi
        fi
    done
    # Chiều ngược lại: khai rồi mà không còn liên kết thì phải xoá, để danh sách không nói dối.
    for entry in "${LINKED_FRAMEWORKS_ALLOWED[@]}"; do
        name="${entry%%|*}"
        if ! otool -L "$APP_BIN" 2>/dev/null | grep -q "/$name.framework/"; then
            echo "❌ ADR-14: đã khai $name nhưng binary không còn liên kết nó —"
            echo "   xoá dòng tương ứng khỏi LINKED_FRAMEWORKS_ALLOWED."
            linked_status=1
        fi
    done
    if [ "$linked_status" = "0" ]; then
        echo "✅ ADR-14: ${#LINKED_FRAMEWORKS_ALLOWED[@]} framework nặng liên kết lúc nạp, đều đã khai"
    else
        status=1
    fi
else
    # Nói ra thay vì im lặng bỏ qua: một cổng không chạy được mà không kêu là một cổng đã tắt.
    echo "⚠️  ADR-14: chưa có bản dựng release để soi liên kết — chạy 'swift build -c release' trước"
fi

# ============================================================================================
# libarchive nạp từ nguồn KHÔNG được mang theo mã sinh tiến trình con.
#
# VÌ SAO CỔNG NÀY LÀ CỔNG QUAN TRỌNG NHẤT CỦA CẢ LƯỢT VENDOR. libarchive có một bộ lọc tên là
# `program`: gặp định dạng nó không tự giải được, nó `fork` + `exec` một chương trình ngoài
# (`gzip -d`, `unlzma`, `zstd -d`…). Đó chính xác là hành vi mà cả lượt vendor này sinh ra để
# loại bỏ — bản App Store chạy trong sandbox, và một ứng dụng sinh tiến trình con để đọc file
# nén là thứ người duyệt sẽ hỏi.
#
# Mã ấy không bị TẮT bằng cờ; nó KHÔNG ĐƯỢC CHÉP vào repo. Cổng này canh đúng điều đó, vì một
# lần chạy lại scripts/vendor-libarchive.sh với danh sách sửa nhầm sẽ kéo nó về mà không có gì
# báo: bản dựng vẫn xanh, mọi bài kiểm vẫn xanh, và khác biệt duy nhất nằm trong bundle đã nộp.
#
# Ba mẫu, ba tầng: hàm gọi chương trình, lớp fork bên dưới nó, và bộ phân tích dòng lệnh mà chỉ
# nó dùng. Chỉ chặn một mẫu thì hai mẫu kia vẫn đủ để mã quay lại.
vendor_status=0
LIBARCHIVE_VENDOR="$(dirname "$0")/../Sources/LibArchive/vendor/src"
if [ -d "$LIBARCHIVE_VENDOR" ]; then
    # Ba đơn vị biên dịch HIỆN THỰC đường ấy. Canh sự VẮNG MẶT của tệp, chứ không `grep` tên
    # hàm: `filter_gzip.c` và `filter_xz.c` có NHẮC `__archive_read_program` trong một nhánh
    # `#else` chỉ dùng khi thiếu zlib/liblzma — nhánh ấy không bao giờ được biên dịch ở đây, và
    # bắt lỗi nó là bắt nhầm một dòng vô hại rồi dạy người sau bỏ qua cổng này.
    for unit in archive_read_support_filter_program.c filter_fork_posix.c archive_cmdline.c; do
        if [ -f "$LIBARCHIVE_VENDOR/$unit" ]; then
            echo "❌ libarchive: đã vendor «${unit}» — đơn vị này SINH TIẾN TRÌNH CON để giải nén."
            echo "   Bản App Store chạy trong sandbox; xem danh sách LA_UNITS trong"
            echo "   scripts/vendor-libarchive.sh."
            vendor_status=1
        fi
    done

    # Nửa GHI của thư viện cũng không được có mặt: GEditor không tạo kho nén, và nửa ấy kéo
    # theo cả bộ mã nén LZMA lẫn `archive_write_disk` — thứ tự ghi tệp ra đĩa với quyền và ACL
    # lấy thẳng từ kho, tức từ một tệp người khác tạo ra.
    if ls "$LIBARCHIVE_VENDOR"/archive_write*.c >/dev/null 2>&1; then
        echo "❌ libarchive: nguồn đã vendor có nửa GHI (archive_write*.c) — GEditor chỉ đọc."
        vendor_status=1
    fi

    # `format_raw` nhận BẤT KỲ chuỗi byte nào là một kho có đúng một mục. Có nó thì một tệp
    # hỏng mở ra thành "kho hợp lệ" thay vì báo lỗi, và MediaKind mất đường phân biệt file nén
    # với văn bản — xem bài kiểm testTEPVANBANthuongKHONGnhanNHAMthanhKHO.
    if [ -f "$LIBARCHIVE_VENDOR/archive_read_support_format_raw.c" ]; then
        echo "❌ libarchive: đã vendor format_raw — nó nhận mọi tệp là kho nén hợp lệ."
        vendor_status=1
    fi

    # ------------------------------------------------------------------------------------
    # Và bằng chứng ở tầng KÝ HIỆU, thứ mà việc đọc mã nguồn không thay thế được.
    #
    # Ba phép kiểm trên nói "ta không chép mã ấy vào". Phép kiểm này nói mạnh hơn: trong 45
    # object đã biên dịch thật, KHÔNG object nào tham chiếu tới một lời gọi tạo tiến trình của
    # hệ điều hành. Nó đúng kể cả khi upstream đổi cách gọi, đổi tên hàm, hay chèn đường spawn
    # vào một tệp hoàn toàn khác trong một phiên bản sau.
    LA_OBJ="$(ls -d .build/*/debug/LibArchive.build/vendor/src 2>/dev/null | head -1)"
    if [ -n "$LA_OBJ" ] && command -v nm >/dev/null 2>&1; then
        spawn_hits=""
        for object in "$LA_OBJ"/*.o; do
            found="$(nm -u "$object" 2>/dev/null \
                | grep -E "_(fork|vfork|posix_spawn[a-z_]*|exec[lv]p?e?|system|popen)$" || true)"
            [ -n "$found" ] && spawn_hits="$spawn_hits$(basename "$object"): $found"$'\n'
        done
        if [ -n "$spawn_hits" ]; then
            echo "❌ libarchive: object đã biên dịch có tham chiếu lời gọi tạo tiến trình:"
            echo "$spawn_hits" | sed 's/^/   /'
            vendor_status=1
        else
            echo "   ✓ $(ls "$LA_OBJ"/*.o | wc -l | tr -d ' ') object, không cái nào gọi được fork/exec/spawn"
        fi
    else
        # Nói ra thay vì im lặng bỏ qua: một cổng không chạy được mà không kêu là cổng đã tắt.
        echo "⚠️  libarchive: chưa có object debug để soi ký hiệu — chạy 'swift build' trước"
    fi

    if [ "$vendor_status" = "0" ]; then
        echo "✅ libarchive: không có đường sinh tiến trình con, không có nửa ghi, không có format_raw"
    else
        status=1
    fi
fi

# NFR-REL-03 — bộ bắt sự cố phải GHI ĐƯỢC báo cáo trên đường tín hiệu.
#
# Chạy script riêng vì phép kiểm này phải LÀM SẬP một tiến trình: nó không thể là một bài trong
# `--self-test` (bộ kiểm sẽ chết giữa chừng), và nó là phần duy nhất của `CrashReporter` mà một
# bài kiểm thường không chạm tới được.
if [ -x scripts/check-crash-reporter.sh ]; then
    if ! bash scripts/check-crash-reporter.sh | tail -3; then
        status=1
    fi
fi

# ============================================================================================
# NFR-SEC-05 — QUYỀN TỐI THIỂU: không đường nào đòi Accessibility hay Full Disk Access.
#
# VÌ SAO CÓ CỔNG NÀY. Bảng trạng thái ghi mục này là ◐ với đúng lý do: *"luồng cơ bản không đụng
# Accessibility/Full Disk Access — đúng. Nhưng chưa có bài kiểm nào chốt điều đó, nên nó là quan
# sát chứ không phải bất biến"*. Một `AXUIElement` thêm vào ngày mai sẽ phá mà không ai biết:
# macOS không từ chối lúc biên dịch, nó chỉ hiện một hộp xin quyền ở tay người dùng — và với bản
# App Store thì hộp ấy là lý do bị từ chối duyệt.
#
# Cổng đi theo hai hướng, vì hai kiểu đòi quyền khác nhau hẳn:
#
#   1. API Accessibility (`AXIsProcessTrusted`, `AXUIElement*`, `CGEvent` tap, `CGWindowList`)
#      — dùng là bật hộp xin quyền Accessibility / Screen Recording.
#   2. Đường vào thư mục hệ thống của người dùng viết CỨNG trong mã (`~/Library/Mail`,
#      `/Library/Application Support` của người khác…) — đường của Full Disk Access.
#
# `WindowCapture.swift` được miễn: nó chỉ chạy dưới cờ `--capture` của người sửa mã, và chính
# nó nói ra điều đó trong tài liệu của mình.
SEC05_FORBIDDEN='AXIsProcessTrusted|AXUIElementCreate|AXUIElementCopy|CGEventTapCreate|CGWindowListCreateImage|CGRequestScreenCaptureAccess|IOHIDRequestAccess'
sec05_hits="$(grep -REn "$SEC05_FORBIDDEN" Sources/GEditorApp Sources/GEditorCore Sources/GEditorCLI \
    --include='*.swift' 2>/dev/null | grep -v 'WindowCapture.swift' || true)"
# Thư mục nhạy cảm: chỉ soi CHUỖI trong mã, không soi chú thích tiếng Việt nói về chúng.
#
# Danh sách là những thư mục ĐƯỢC BẢO VỆ THẬT của macOS, không phải mọi đường dưới `/Library`.
# Bản đầu của cổng này bắt luôn `NSHomeDirectory().contains("/Library/Containers/")` — chính là
# phép NHẬN RA mình đang trong sandbox, tức đúng thứ ngược lại với một vi phạm.
sec05_paths="$(grep -REn '"(~?/Library/(Mail|Messages|Safari|Cookies|Application Support/(AddressBook|CallHistory|com.apple))|/private/var/db/(dslocal|TimeMachine))' \
    Sources/GEditorApp Sources/GEditorCore Sources/GEditorCLI --include='*.swift' 2>/dev/null || true)"
if [ -n "$sec05_hits" ] || [ -n "$sec05_paths" ]; then
    echo "❌ NFR-SEC-05: có mã đòi quyền ngoài phạm vi tối thiểu:"
    [ -n "$sec05_hits" ] && echo "$sec05_hits" | sed 's/^/   /'
    [ -n "$sec05_paths" ] && echo "$sec05_paths" | sed 's/^/   /'
    echo "   Nếu đây là chủ ý thì phải sửa NFR-SEC-05 trong docs/trang-thai.md TRƯỚC,"
    echo "   và nói rõ hộp xin quyền nào sẽ hiện ra ở tay người dùng."
    status=1
else
    echo "✅ NFR-SEC-05: không có API Accessibility/Screen Recording, không có đường Full Disk Access"
fi

# ============================================================================================
# Bảng tiến độ theo Phase (§5.3 `trang-thai.md`) có khớp SRS không.
#
# VÌ SAO CÓ CỔNG NÀY. §5.3 tự nói rằng nó "sinh bằng máy, không gõ tay" — nhưng suốt nhiều
# phiên KHÔNG có script nào làm việc ấy, và bảng trôi mất 5 mã mà không ai nhìn ra: từng dòng
# đều hợp lý, chỉ có TỔNG là sai. Một con số tiến độ sai là thứ đi thẳng vào quyết định phạm vi.
if command -v python3 >/dev/null 2>&1; then
    if python3 "$(dirname "$0")/phase-table.py" --kiem; then
        :
    else
        status=1
    fi
fi

exit $status
