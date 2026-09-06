#!/bin/bash
# KPI thao tác tài liệu theo tiêu chí STP §4.1 (TC-CORE-08, TC-CSV-03).
#
#   scripts/run-ops-kpi.sh                    quy mô chuẩn: 1 triệu dòng / 1 triệu hàng
#   scripts/run-ops-kpi.sh --lines 100000     bản nhanh khi phát triển
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
RESULT="benchmarks/results/ops-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Build release…"
swift build -c release --product geditor-bench >/dev/null

echo "▸ Đo trên ${ARCH}…"
.build/release/geditor-bench ops "$@" > "$RESULT"

echo "▸ Kết quả: $RESULT"
python3 - "$RESULT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
print(f"\n  {r['architecture']}")

d = r["dedup"]
mark = "✅ ĐẠT" if d["pass"] else "❌ KHÔNG ĐẠT"
print(f"\n  TC-CORE-08 · FR-CORE-006 — khử trùng lặp")
print(f"    {d['lines']:,} dòng, {d['duplicateRatio']*100:.0f}% trùng → còn {d['linesAfter']:,} "
      f"(cần {d['uniqueLines']:,})")
print(f"    kế hoạch {d['planMs']:7.0f} ms   (quét dòng, băm nội dung)")
print(f"    áp dụng  {d['applyMs']:7.0f} ms   ({d['editCount']:,} edit sau khi gộp vùng liền nhau)")
print(f"    TỔNG     {d['totalMs']/1000:7.2f} s    (trần {d['budgetMs']/1000:.0f} s)   {mark}")
print(f"    thứ tự bản giữ: {'đúng' if d['orderPreserved'] else 'SAI'} · undo {d['undoSteps']} bước")

c = r["deleteColumn"]
mark = "✅ ĐẠT" if c["pass"] else "❌ KHÔNG ĐẠT"
print(f"\n  TC-CSV-03 · FR-CSV-404 — xóa cột {c['column'] + 1}")
print(f"    {c['rows']:,} hàng · {c['fixtureMB']:.0f} MB")
print(f"    kế hoạch {c['planMs']:7.0f} ms   (parse RFC 4180)")
print(f"    áp dụng  {c['applyMs']:7.0f} ms   ({c['editCount']:,} edit)")
print(f"    TỔNG     {c['totalMs']/1000:7.2f} s    (trần {c['budgetMs']/1000:.0f} s)   {mark}")
print(f"    quoted field: {'nguyên vẹn' if c['quotedFieldsIntact'] else 'BỊ VỠ'} · undo {c['undoSteps']} bước")
PY
