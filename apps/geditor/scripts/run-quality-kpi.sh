#!/bin/bash
# NFR-DQR-01 — chấm 1 triệu dòng theo 50 luật (FR-DQR-001).
#
#   scripts/run-quality-kpi.sh              đúng cỡ chỉ tiêu
#   scripts/run-quality-kpi.sh --rows 200000
#
# Đo ở ĐÚNG cỡ chỉ tiêu nói tới, không đo cỡ nhỏ rồi nhân lên — bài học PoC-G: chi phí mỗi ô
# không phải hằng số, và cùng một phép so ở hai cỡ đã một lần cho hai kết luận trái ngược.
set -euo pipefail
cd "$(dirname "$0")/.."

ROWS=1000000
if [ "${1:-}" = "--rows" ] && [ -n "${2:-}" ]; then ROWS="$2"; fi
ARCH="$(uname -m)"
OUT="benchmarks/results/quality-kpi-${ARCH}.json"
mkdir -p benchmarks/results

if [ ! -f vendor/duckdb/libduckdb.dylib ]; then
    echo "❌ thiếu vendor/duckdb/libduckdb.dylib — chạy scripts/vendor-duckdb.sh (hoặc git lfs pull)"
    exit 1
fi

echo "▸ Dựng bản release…" >&2
swift build -c release --product geditor-bench >/dev/null

.build/release/geditor-bench quality --rows "$ROWS" > "$OUT"

python3 - "$OUT" <<'PY'
import json, sys

report = json.load(open(sys.argv[1]))
print()
print("  %s · %s" % (report["kpi"], report["architecture"]))
print("  %d hàng × %d cột · %d luật" % (report["rows"], report["columns"], report["ruleCount"]))
print()
print("    GOM một lượt quét   %8.0f ms   ← thứ sản phẩm chạy" % report["batchedMs"])
print("    từng câu một        %8.0f ms   ← đối chứng, cùng engine chạy %d lần"
      % (report["oneByOneMs"], report["ruleCount"]))
print("    nhanh hơn           %8.1f×" % report["speedup"])
print()
print("  Cột đối chứng không phải một bản hiện thực khác — nó là CHÍNH engine ấy chạy mỗi lần")
print("  một luật. Chênh lệch vì thế đo đúng một thứ: giá của việc gom nhiều luật vào một lượt.")
print()
verdict = "✅ ĐẠT" if report["pass"] else "❌ KHÔNG ĐẠT"
print("  %s — %.0f ms / trần %.0f ms" % (verdict, report["batchedMs"], report["budgetMs"]))
print()
print("  Ghi ở: %s" % sys.argv[1])
sys.exit(0 if report["pass"] else 1)
PY
