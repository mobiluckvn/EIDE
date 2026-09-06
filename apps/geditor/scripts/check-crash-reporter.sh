#!/bin/bash
# NFR-REL-03 — chứng minh bộ bắt sự cố GHI ĐƯỢC báo cáo trên đường TÍN HIỆU.
#
#   scripts/check-crash-reporter.sh
#
# ## Vì sao không nằm trong bộ tự kiểm
#
# Bài tự kiểm chỉ đi được đường `NSException`. Đường tín hiệu — đường mà một sự cố THẬT đi qua —
# thì giết tiến trình, nên nó không thể là một `Case` trong `--self-test`: bộ kiểm sẽ chết giữa
# chừng và mọi bài sau đó không chạy.
#
# Không có script này thì phần quan trọng nhất của `CrashReporter` là một hàng rào chỉ có trên
# giấy: biên dịch được, trông đúng, và chưa ai từng thấy nó ghi ra một byte nào.
#
# ## Cách kiểm
#
# Chạy app với `--crash-signal SIGSEGV` trong một thư mục dữ liệu TẠM, rồi đòi ba điều:
#   1. tiến trình phải CHẾT vì đúng tín hiệu ấy (handler không được nuốt tín hiệu),
#   2. có đúng một tệp báo cáo,
#   3. báo cáo mang ngữ cảnh tối thiểu và KHÔNG mang đường dẫn nào của người dùng.
set -uo pipefail
cd "$(dirname "$0")/.."

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
status=0

echo "▸ Dựng bản debug…"
swift build --product GEditorApp >/dev/null 2>&1 || { echo "❌ build hỏng"; exit 1; }
BIN="$(swift build --product GEditorApp --show-bin-path)/GEditorApp"

for SIGNAL in SIGSEGV SIGABRT; do
    "$BIN" --crash-signal "$SIGNAL" --crash-root "$ROOT" >/dev/null 2>&1
    code=$?

    # Tiến trình chết vì tín hiệu thì shell trả 128 + số hiệu. Mã 3 nghĩa là handler đã NUỐT
    # tín hiệu — app sống tiếp trong một trạng thái đã hỏng, và đó là điều tệ hơn một lần đóng
    # đột ngột.
    if [ "$code" -lt 128 ]; then
        echo "❌ ${SIGNAL}: tiến trình KHÔNG chết vì tín hiệu (mã thoát $code)"
        status=1
        continue
    fi

    # `--crash-root` LÀ thư mục dữ liệu, không phải thư mục cha của nó:
    # `applicationSupportOverride` được dùng thẳng làm gốc.
    report="$(ls -t "$ROOT/crash/"*.txt 2>/dev/null | head -1)"
    if [ -z "$report" ]; then
        echo "❌ ${SIGNAL}: không có báo cáo nào được ghi ra"
        status=1
        continue
    fi

    if ! grep -q "GEditor" "$report" || ! grep -q "macOS:" "$report"; then
        echo "❌ ${SIGNAL}: báo cáo thiếu ngữ cảnh tối thiểu"
        status=1
        continue
    fi
    if ! grep -q "$SIGNAL" "$report"; then
        echo "❌ ${SIGNAL}: báo cáo không nói tên tín hiệu"
        status=1
        continue
    fi
    # Ngăn xếp lời gọi: `backtrace_symbols_fd` in mỗi khung một dòng có số hiệu và địa chỉ.
    frames="$(grep -c "0x" "$report" || true)"
    if [ "$frames" -lt 5 ]; then
        echo "❌ ${SIGNAL}: chỉ $frames khung ngăn xếp — báo cáo không đủ để lần ra gì"
        status=1
        continue
    fi
    # Không được có đường dẫn của người dùng. `$HOME` là thứ dễ lọt nhất.
    if grep -q "$HOME/Desktop\|$HOME/Documents\|$HOME/Downloads" "$report"; then
        echo "❌ ${SIGNAL}: báo cáo mang đường dẫn tài liệu của người dùng"
        status=1
        continue
    fi
    echo "   ✓ ${SIGNAL}: chết đúng tín hiệu · $frames khung · $(wc -c < "$report" | tr -d ' ') byte"
done

if [ "$status" = "0" ]; then
    echo "✅ NFR-REL-03: bộ bắt sự cố ghi được báo cáo trên đường tín hiệu, và không nuốt tín hiệu"
fi
exit $status
