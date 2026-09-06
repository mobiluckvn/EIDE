#!/bin/bash
# Chạy các bài tự kiểm GIAO DIỆN (`GEditorApp --self-test`).
#
# Vì sao có script riêng: những bài này KHÔNG chạy được trong `swift test`. Chúng cần một
# NSApplication thật với cửa sổ thật, vì thứ chúng kiểm là đường AppKit đưa chữ vào view —
# `NSTextView.insertText` → `shouldChangeTextIn` → delegate của ta.
#
# Giới hạn phải nói rõ: bài này bỏ qua tầng bàn phím và bộ gõ. Nó KHÔNG thay được người gõ tay
# cho TC-IME-02 (Telex + multi-caret), vì bộ gõ tiếng Việt đánh dấu mọi phím và đường đó chỉ
# người thật mới đi được.
#
# CẦN MÀN HÌNH: không có phiên đồ họa thì NSApplication không dựng nổi cửa sổ.
set -euo pipefail

cd "$(dirname "$0")/.."

# `--bundle [appstore|direct]`: dựng bundle universal ĐÃ KÝ rồi chạy bài kiểm bên trong nó.
#
# Không phải cầu kỳ. Bản binary trần chạy KHÔNG có sandbox, còn bản người dùng tải về thì có —
# và khác biệt ấy đã giấu một lỗi thật: `HeavyGrammars` suy đường dylib từ `argv[0]`, chạy đúng
# ở mọi bản dựng phát triển rồi chết trong sandbox, làm C#/C++/Ruby mất màu mà không báo gì.
# Mục tiêu phát hành là App Store (docs/appstore-ra-soat.md), nên đường này phải chạy được.
if [ "${1:-}" = "--bundle" ]; then
    CHANNEL="${2:-appstore}"
    ./scripts/build-universal.sh --channel "$CHANNEL" >/dev/null || exit 1
    echo "▸ Chạy bài tự kiểm TRONG bundle đã ký, kênh ${CHANNEL}…"
    exec "dist/$CHANNEL/GEditor.app/Contents/MacOS/GEditor" --self-test
fi

swift build --product GEditorApp
# Dylib grammar nặng là sản phẩm RIÊNG (ADR-08 phương án C) — `--product GEditorApp` không kéo
# nó theo, vì đúng ý đồ là app không liên kết tới nó. Không dựng ở đây thì C++/C#/Ruby hiện ra
# không màu và bộ tự kiểm bắt được ngay.
swift build --product TreeSitterHeavy
BIN="$(swift build --product GEditorApp --show-bin-path)/GEditorApp"

# App KHÔNG được liên kết tới dylib grammar nặng (ADR-08 phương án C).
#
# Một dòng `import TreeSitterHeavy` lọt vào lớp app là đủ để trình liên kết ghi dylib ấy vào
# đường phụ thuộc, và dyld sẽ nạp nó ở MỌI lần khởi động — mất sạch phần tiết kiệm, trong khi
# mọi bài kiểm khác vẫn xanh vì tính năng chẳng hỏng gì. Chỉ `otool` bắt được.
if otool -L "$BIN" | grep -q "TreeSitterHeavy"; then
    echo "❌ GEditorApp liên kết thẳng vào libTreeSitterHeavy — ADR-08 phương án C mất tác dụng"
    otool -L "$BIN" | grep "TreeSitterHeavy"
    exit 1
fi
echo "✅ App không liên kết dylib grammar nặng (nạp lười, ADR-08)"

echo "▸ Tự kiểm giao diện"
"$BIN" --self-test 2>&1 | grep -v "SIMD:" || true
"$BIN" --self-test >/dev/null 2>&1
