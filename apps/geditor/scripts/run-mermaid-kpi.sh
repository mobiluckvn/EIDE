#!/bin/bash
# NFR-MMD-01 — sơ đồ 500 node ≤ 2 giây, cập nhật preview ≤ 500 ms.
#
#   scripts/run-mermaid-kpi.sh
#
# Đo bằng CHÍNH `MermaidRenderer` mà bảng Mermaid Studio dùng (`GEditorApp --mermaid-kpi`), chứ
# không dựng một harness riêng — xem ghi chú đầu `MermaidKPI`. Bản dựng RELEASE, vì đó là bản
# người dùng chạy.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f vendor/mermaid/mermaid.min.js ]; then
    echo "❌ thiếu vendor/mermaid/mermaid.min.js — chạy scripts/vendor-mermaid.sh" >&2
    exit 1
fi

echo "▸ Dựng bản Release…"
swift build -c release --product GEditorApp >/dev/null

BIN=".build/release/GEditorApp"
[ -x "$BIN" ] || { echo "❌ không thấy $BIN" >&2; exit 1; }

echo "▸ Đo…"
echo
"$BIN" --mermaid-kpi
