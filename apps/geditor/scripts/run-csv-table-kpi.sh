#!/bin/bash
# KPI Table view CSV (FR-CSV-403).
#
#   scripts/run-csv-table-kpi.sh                 quy mô chuẩn: 1 triệu hàng
#   scripts/run-csv-table-kpi.sh --rows 100000   bản nhanh khi phát triển
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
RESULT="benchmarks/results/csv-table-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Build release…"
swift build -c release --product geditor-bench >/dev/null

echo "▸ Đo trên ${ARCH}…"
.build/release/geditor-bench csv-table "$@" > "$RESULT"

echo "▸ Kết quả: $RESULT"
python3 - "$RESULT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
b, l, s = r["build"], r["lookup"], r["sort"]
print(f"\n  {r['architecture']}\n")

print(f"  Chỉ mục hàng logic — {b['rows']:,} hàng · {b['fixtureMB']:.0f} MB · {b['columnCount']} cột")
print(f"    dựng      {b['buildMs']:8.0f} ms   (một lần, chạy nền khi vào chế độ CSV)")
print(f"    bộ nhớ    {b['indexKB']:8.1f} KB   (chỉ mục dày đặc sẽ tốn {b['denseIndexKB']:,.0f} KB)")

mark = "✅ ĐẠT" if l["pass"] else "❌ KHÔNG ĐẠT"
print(f"\n  Chuyển chế độ Văn bản ↔ Bảng — trần {l['budgetMs']:.0f} ms, {l['samples']:,} phép đo")
print(f"    một màn hình 40 hàng   p50 {l['screenP50Ms']:6.3f} ms · p99 {l['screenP99Ms']:6.3f} ms · max {l['screenMaxMs']:6.3f} ms")
print(f"    offset → số hàng       p99 {l['offsetToRowP99Ms']:6.3f} ms")
print(f"    TỔNG một lần chuyển    p99 {l['switchP99Ms']:6.3f} ms   {mark}")

print(f"\n  Sắp xếp — {s['rows']:,} hàng")
print(f"    cột SỐ            {s['numericColumnMs']:8.0f} ms")
print(f"    cột CHỮ           {s['textColumnMs']:8.0f} ms   (mỗi hàng một giá trị khác nhau, có dấu)")
print(f"    ghi vào file      {s['applyToFileMs']:8.0f} ms   ({s['applyEditCount']} edit = 1 bước undo)")
print(f"    thứ tự: {'đúng' if s['orderCorrect'] else 'SAI'}")
print("\n  " + "\n  ".join(r["notes"]))
PY
