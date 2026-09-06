#!/bin/bash
# Đo độ phủ test của LÕI (NFR-MNT-02: ≥ 70%).
#
#   scripts/run-coverage.sh            đo và áp cổng 70%
#   scripts/run-coverage.sh --report   in bảng theo từng file, không áp cổng
#
# **Chỉ đo GEditorCore.** Ba lý do, và đây là chỗ dễ tự lừa mình nhất:
#
#   1. Lớp app (`GEditorApp`) không chạy dưới `swift test` — nó cần một NSApplication thật, và
#      bộ tự kiểm giao diện chạy ở tiến trình riêng. Gộp nó vào phép đo sẽ ra một con số thấp
#      giả tạo mà không nói lên điều gì.
#   2. Vendor (PCRE2, tree-sitter, Scintilla) là mã của người khác. Đo nó là đo xem ta gọi tới
#      bao nhiêu phần của một thư viện, không phải đo ta đã kiểm mình kỹ tới đâu.
#   3. `GEditorBench` và `GEditorPoCA` là công cụ đo, không phải sản phẩm.
#
# Nói cách khác: con số này trả lời "phần LÕI — thứ mọi tính năng đứng lên trên — đã được kiểm
# tới đâu". Nó KHÔNG trả lời "cả sản phẩm đã được kiểm tới đâu"; câu ấy cần cả 159 bài tự kiểm
# giao diện, và chúng không đếm được bằng llvm-cov.
set -euo pipefail

cd "$(dirname "$0")/.."

THRESHOLD=70.0
REPORT_ONLY=false
[ "${1:-}" = "--report" ] && REPORT_ONLY=true

echo "▸ Chạy test kèm đo độ phủ…"
swift test --enable-code-coverage > /dev/null

BIN_PATH="$(swift build --show-bin-path)"
PROFDATA="$BIN_PATH/codecov/default.profdata"
XCTEST="$(find "$BIN_PATH" -name '*.xctest' -maxdepth 1 | head -1)"

if [ ! -f "$PROFDATA" ] || [ -z "$XCTEST" ]; then
    echo "❌ không tìm thấy dữ liệu độ phủ ở $BIN_PATH/codecov"
    exit 1
fi

BINARY="$XCTEST/Contents/MacOS/$(basename "$XCTEST" .xctest)"

# `llvm-cov` của Xcode, không phải bản trong PATH: bản hệ thống có thể lệch phiên bản với
# compiler đã sinh ra profdata, và khi lệch thì nó báo "malformed" chứ không báo lệch phiên bản.
COV="$(xcrun --find llvm-cov)"

# Lọc theo đường dẫn nguồn: chỉ giữ Sources/GEditorCore, bỏ vendor.
LINES="$("$COV" report "$BINARY" \
    -instr-profile="$PROFDATA" \
    -ignore-filename-regex='(vendor|Tests|GEditorApp|GEditorBench|GEditorPoCA|GEditorCLI|\.build)' \
    2>/dev/null | tail -1)"

# Dòng TOTAL của llvm-cov: Regions Missed Cover Functions Missed Exec Lines Missed Cover Branches…
COVERED="$(echo "$LINES" | awk '{for (i = 1; i <= NF; i++) if ($i ~ /%$/) print $i}' | sed -n '3p' | tr -d '%')"

if [ -z "$COVERED" ]; then
    echo "❌ không đọc được số độ phủ từ llvm-cov"
    echo "$LINES"
    exit 1
fi

if [ "$REPORT_ONLY" = true ]; then
    "$COV" report "$BINARY" \
        -instr-profile="$PROFDATA" \
        -ignore-filename-regex='(vendor|Tests|GEditorApp|GEditorBench|GEditorPoCA|GEditorCLI|\.build)' \
        2>/dev/null
    exit 0
fi

echo "▸ Độ phủ DÒNG của GEditorCore: ${COVERED}% (trần dưới ${THRESHOLD}%)"

if awk "BEGIN { exit !($COVERED >= $THRESHOLD) }"; then
    echo "✅ NFR-MNT-02: độ phủ ${COVERED}% ≥ ${THRESHOLD}%"
else
    echo "❌ NFR-MNT-02: độ phủ ${COVERED}% < ${THRESHOLD}%"
    echo "   Xem file nào thiếu: scripts/run-coverage.sh --report"
    exit 1
fi
