#!/bin/bash
# Hai KPI tìm kiếm mức lõi theo tiêu chí STP §4.1 (TC-PERF-05, TC-PERF-06).
#
#   scripts/run-search-kpi.sh                 fixture chuẩn: 10.000 file × 10 KB
#   scripts/run-search-kpi.sh --kb 50         file lớn hơn, ít bị chi phối bởi chi phí mỗi file
#
# Cây fixture sinh NGOÀI repo tại GEDITOR_FIXTURE_DIR (mặc định thư mục tạm) và được dùng lại.
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
RESULT="benchmarks/results/search-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Build release…"
swift build -c release --product geditor-bench >/dev/null

echo "▸ Đo trên ${ARCH}…"
.build/release/geditor-bench search "$@" > "$RESULT"

echo "▸ Kết quả: $RESULT"
python3 - "$RESULT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
print(f"\n  {r['architecture']} · PCRE2 {r['pcre2Version']}")

x = r["replaceMillionMatches"]
mark = "✅ ĐẠT" if x["pass"] else "❌ KHÔNG ĐẠT"
print(f"\n  TC-PERF-06 · NFR-PERF-08 — thay {x['matches']:,} kết quả trên {x['fixtureMB']:.0f} MB")
print(f"    pattern {x['pattern']}   →   {x['template']}")
print(f"    kế hoạch {x['planMs']:8.0f} ms")
print(f"    áp dụng  {x['applyMs']:8.0f} ms")
print(f"    TỔNG     {x['totalMs']/1000:8.2f} s   (trần {x['budgetMs']/1000:.0f} s)   {mark}")
print(f"    undo     {x['undoMs']:8.0f} ms trong {x['undoSteps']} bước (FR-CORE-004 đòi đúng 1)")
print(f"    footprint đỉnh {x['footprintPeakMB']:.0f} MB")

s = r["findInFiles"]
print(f"\n  TC-PERF-05 · NFR-PERF-06 — {s['files']:,} file · {s['totalMB']:.0f} MB · máy {s['activeCores']} lõi")
if s["filesWithMatches"] != s["expectedFilesWithMatches"]:
    print(f"    ⚠️  SAI KẾT QUẢ: {s['filesWithMatches']} file khớp, kỳ vọng {s['expectedFilesWithMatches']}")
print(f"    {'luồng':>6s} {'thời gian':>12s} {'thông lượng':>14s} {'tăng tốc':>10s}")
for p in s["points"]:
    print(f"    {p['concurrency']:6d} {p['elapsedMs']:9.0f} ms {p['throughputMBps']:11.0f} MB/s "
          f"{p['speedupOverSingle']:9.2f}×")

print(f"\n    Cách nạp file (8 luồng):")
for p in s["ioStrategy"]:
    print(f"      {p['strategy']:>5s}  {p['elapsedMs']:7.0f} ms · {p['throughputMBps']:6.0f} MB/s")

mark = "✅ ĐẠT" if s["pass"] else "❌ CHƯA ĐẠT"
print(f"\n    8 luồng / 4 luồng = {s['ratioEightOverFour']:.2f}   (tiêu chí STP ≤ {s['threshold']:.2f})   {mark}")
print("    " + " ".join(s["caveat"].split()))
PY
