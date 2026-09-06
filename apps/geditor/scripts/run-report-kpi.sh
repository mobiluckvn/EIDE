#!/bin/bash
# NFR-RPT-01 — *"Báo cáo 10 block trên nguồn 1 triệu dòng render ≤ 5 giây; kết quả block được
# cache theo hash(query + trạng thái nguồn)"*.
#
#   scripts/run-report-kpi.sh            đúng cỡ chỉ tiêu
#   scripts/run-report-kpi.sh 50000      cỡ nhỏ để thử nhanh đường chạy
#
# Chỉ tiêu có HAI vế và script này hỏi cả hai. Vế cache đo bằng cách dựng LẠI đúng tài liệu ấy
# trên đúng nguồn ấy: một bộ đo chỉ hỏi vế thời gian sẽ báo ĐẠT cho một hiện thực không có cache
# nào cả — và đó đúng là tình trạng của sản phẩm này cho tới 04/09/2026.
#
# Tên biến mang tiền tố `KPI_`: xem ghi chú ở `run-mining-kpi.sh`, một biến `GROUPS` có sẵn
# trong môi trường đã từng làm bộ đo chạy sai tham số mà không ai biết.
set -euo pipefail
cd "$(dirname "$0")/.."

KPI_ROWS="${1:-1000000}"
ARCH="$(uname -m)"
OUT="benchmarks/results/report-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Dựng bản release…" >&2
swift build -c release --product geditor-bench >/dev/null

.build/release/geditor-bench report --rows "$KPI_ROWS" > "$OUT"

python3 - "$OUT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
print()
print("  %s · %s" % (r["kpi"], r["architecture"]))
print("  %d hàng · %d khối (%d chạy được)" % (r["rows"], r["blocks"], r["succeeded"]))
print()
ok = "✅" if r["firstRenderMs"] <= r["budgetMs"] else "❌"
print("    %s lượt dựng ĐẦU          %10.0f ms   / trần %.0f ms"
      % (ok, r["firstRenderMs"], r["budgetMs"]))
print("    %s lượt dựng LẠI          %10.0f ms   ← cache theo khối"
      % ("✅" if r["cacheHelps"] else "❌", r["secondRenderMs"]))
print()
for note in r["notes"]:
    print("  · %s" % note)
print()
print("  %s" % ("✅ ĐẠT — cả hai vế" if r["pass"] else "❌ KHÔNG ĐẠT"))
print()
print("  Lượt dựng LẠI là thứ người dùng gặp nhiều nhất: preview dựng lại sau mỗi lần ngừng gõ,")
print("  nên một dòng văn xuôi vừa sửa không được kéo theo mười lượt quét dữ liệu.")
PY
