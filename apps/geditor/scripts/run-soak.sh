#!/bin/bash
# Chạy DÀI trên ứng dụng thật — NFR-REL-03 (ổn định).
#
# Vì sao có script riêng, thay vì gọi tay `GEditorApp --soak`: một lượt chạy đơn lẻ chỉ đi MỘT
# dãy thao tác. Dãy ấy tất định theo hạt giống, nên chạy lại nó mãi cũng chỉ kiểm lại đúng
# những gì đã kiểm. Cái tìm ra lỗi là QUÉT NHIỀU HẠT GIỐNG.
#
# Đã chứng minh: mười lăm hạt giống đầu tiên có hai hạt (11 và 13) làm app sập, ở một lỗi mà
# 1176 test lõi và 178 bài tự kiểm không thấy — quy đổi offset trôi trên tài liệu có byte UTF-8
# hỏng. Hai hạt trong mười lăm; một lượt chạy đơn lẻ có 87% cơ hội bỏ sót nó.
#
# CẦN MÀN HÌNH: không có phiên đồ họa thì NSApplication không dựng nổi cửa sổ.
#
# Dùng:
#   scripts/run-soak.sh                       # quét mặc định: 15 hạt × 10.000 thao tác
#   scripts/run-soak.sh 40000 3               # 3 hạt đầu, mỗi hạt 40.000 thao tác
#   scripts/run-soak.sh --bundle appstore     # chạy TRONG bundle đã ký, tức trong sandbox
#
# Muốn TRUY một lượt đỏ thì chạy thẳng binary, đừng qua script:
#   GEditorApp --soak 10000 --seed 11 --vet        # in từng thao tác kèm bộ nhớ
#   GEditorApp --soak 10000 --only type,newline    # chỉ một nhóm thao tác
#   GEditorApp --soak 10000 --hold 120             # giữ tiến trình để `heap`/`leaks` bám vào
set -uo pipefail

cd "$(dirname "$0")/.."

# Hạt giống viết THẲNG ra đây chứ không sinh ngẫu nhiên: một bộ hạt cố định thì lần chạy sau so
# được với lần chạy trước, và một hạt từng đỏ sẽ ở lại trong bộ mãi mãi.
SEEDS=(1 2 3 5 7 11 13 42 99 777 1234 4096 20260825 31337 65535)
OPERATIONS="${1:-10000}"
COUNT="${2:-${#SEEDS[@]}}"

# `--bundle [appstore|direct]`: chạy trong bundle ĐÃ KÝ, tức là TRONG SANDBOX.
#
# Cùng lý do với `run-self-test.sh --bundle`, và lý do ấy đã có tiền lệ đắt: `HeavyGrammars` suy
# đường dylib từ `argv[0]`, chạy đúng ở mọi bản dựng phát triển rồi chết trong sandbox. Bản
# binary trần KHÔNG có sandbox, nên một lượt chạy dài trên nó không nói gì về bản người dùng tải
# về — mà App Store là mục tiêu phát hành.
#
# Kiểm nhanh sandbox có thật bật không: `ls ~/Library/Containers/ai.code247.GEditor`.
if [ "${1:-}" = "--bundle" ]; then
    CHANNEL="${2:-appstore}"
    OPERATIONS="${3:-10000}"
    COUNT="${4:-${#SEEDS[@]}}"
    ./scripts/build-universal.sh --channel "$CHANNEL" >/dev/null || exit 1
    BIN="dist/$CHANNEL/GEditor.app/Contents/MacOS/GEditor"
    echo "▸ Chạy TRONG bundle đã ký, kênh ${CHANNEL}"
else
    swift build -c release --product GEditorApp >/dev/null || exit 1
    BIN="$(swift build -c release --product GEditorApp --show-bin-path)/GEditorApp"
fi

echo "▸ NFR-REL-03: $COUNT hạt giống × $OPERATIONS thao tác"
echo

FAILED=()
for ((i = 0; i < COUNT && i < ${#SEEDS[@]}; i++)); do
    SEED="${SEEDS[$i]}"
    # Chạy rồi mới lọc, KHÔNG lọc trong cùng một đường ống.
    #
    # `CODE=$?` ngay sau một đường ống đọc mã thoát của lệnh CUỐI — tức của `grep`, không phải
    # của app. Bản đầu của script này mắc đúng lỗi ấy, và triệu chứng là một lượt chạy SIGSEGV
    # (mã 139) được báo thành "mã thoát 1". Nó chỉ lộ ra vì con số 1 không khớp với thứ gì cả.
    OUT="$("$BIN" --soak "$OPERATIONS" --seed "$SEED" --hold 2 2>&1)"
    CODE=$?
    OUT="$(echo "$OUT" | grep -v "SIMD:" | grep -v "\[GEditor\]")"

    # Đọc CẢ mã thoát lẫn nội dung. Sập thì báo cáo không in ra dòng nào — "không thấy chữ ĐẠT"
    # là dấu hiệu, còn mã thoát 0 một mình thì không đủ: một lượt sập giữa chừng vẫn có thể để
    # lại mã thoát 0 nếu đi qua ống dẫn.
    VERDICT="$(echo "$OUT" | grep -E "ĐẠT" | head -1 | sed 's/^ *//')"
    IDLE="$(echo "$OUT" | grep "RẢNH" | sed 's/.*giây: //; s/ (.*//')"

    if [ "$CODE" != "0" ] || ! echo "$VERDICT" | grep -q "✅"; then
        FAILED+=("$SEED")
        printf "  ❌ hạt %-9s mã thoát %s\n" "$SEED" "$CODE"
        echo "$OUT" | tail -5 | sed 's/^/     /'
    else
        printf "  ✅ hạt %-9s rảnh %s\n" "$SEED" "$IDLE"
    fi
done

echo
if [ ${#FAILED[@]} -gt 0 ]; then
    echo "❌ NFR-REL-03: ${#FAILED[@]} hạt giống ĐỎ — ${FAILED[*]}"
    echo "   Tái hiện: $BIN --soak $OPERATIONS --seed ${FAILED[0]} --vet"
    exit 1
fi
echo "✅ NFR-REL-03: $COUNT hạt giống, không hạt nào sập"
