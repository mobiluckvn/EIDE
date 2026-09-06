#!/bin/bash
# NFR-QRY-02 — biểu đồ từ 1 triệu điểm ≤ 2 giây (FR-QRY-004).
#
#   scripts/run-chart-kpi.sh
#   scripts/run-chart-kpi.sh --points 5000000
#
# ĐO BẢN RELEASE, và đó không phải chi tiết. Cùng phép đo chạy dưới `swift test` (bản debug)
# cho 1.671 ms cho riêng phép chia khoảng — sát trần 2 giây trước khi vẽ một điểm ảnh nào, và
# suýt dẫn tới một đợt tối ưu cho thứ không hề chậm. Bản release: 66 ms.
#
# Bài học chung, và nó đúng với mọi KPI trong kho này: đo bản KHÁC bản mình giao là đo một sản
# phẩm khác.
set -euo pipefail
cd "$(dirname "$0")/.."

POINTS=1000000
if [ "${1:-}" = "--points" ] && [ -n "${2:-}" ]; then POINTS="$2"; fi
ARCH="$(uname -m)"
OUT="benchmarks/results/chart-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Dựng bản release…" >&2
swift build -c release --product geditor-bench >/dev/null

.build/release/geditor-bench chart --points "$POINTS" > "$OUT"

python3 - "$OUT" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print()
print("  %s · %s" % (r["kpi"], r["architecture"]))
print("  %d điểm" % r["points"])
print()
print("    LTTB (đường · phân tán)   %7.0f ms   → %d điểm vẽ" % (r["downsampleMs"], r["sampledTo"]))
print("    chia khoảng (phân bố)     %7.0f ms" % r["histogramMs"])
print("    phân vị (hộp)             %7.0f ms" % r["boxMs"])
print()
worst = max(r["downsampleMs"], r["histogramMs"], r["boxMs"])
print("  %s — chậm nhất %.0f ms / trần %.0f ms"
      % ("✅ ĐẠT" if r["pass"] else "❌ KHÔNG ĐẠT", worst, r["budgetMs"]))
print()
print("  Phần VẼ không nằm trong con số này. Nó nhận tối đa %d điểm, nên chi phí của nó" % r["sampledTo"])
print("  KHÔNG phụ thuộc cỡ dữ liệu — đó chính là điều LTTB mua về.")
print()
print("  Ghi ở: %s" % sys.argv[1])
sys.exit(0 if r["pass"] else 1)
PY
