#!/bin/bash
# Chạy benchmark và áp cổng chặn merge (STP §4.1 · SAD §7).
#
# Luật: suy giảm > 10% so với baseline trên BẤT KỲ KPI nào = fail = chặn merge.
# Baseline lưu theo kiến trúc vì ngưỡng Intel và Apple Silicon khác nhau (SRS §3.3).
#
#   scripts/run-benchmarks.sh              đo và so với baseline
#   scripts/run-benchmarks.sh --update     ghi kết quả hiện tại thành baseline mới
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
BASELINE="benchmarks/baseline-${ARCH}.json"
RESULT="benchmarks/results/${ARCH}.json"
TOLERANCE=0.10   # 10% — khớp STP §4.1

mkdir -p benchmarks/results

echo "▸ Build release và đo KPI trên ${ARCH}…"
swift build -c release --product geditor-bench >/dev/null
.build/release/geditor-bench > "$RESULT"

echo "▸ Kết quả: $RESULT"
python3 - "$RESULT" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
print(f"  {report['architecture']} · SIMD {report['simdBackend']} · fixture {report['fixtureMB']:.0f} MB")
for name, value in sorted(report["metrics"].items()):
    print(f"    {name:32s} {value:12.2f}")
PY

if [ "${1:-}" = "--update" ]; then
    cp "$RESULT" "$BASELINE"
    echo "✅ Đã ghi baseline mới: $BASELINE"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    echo "⚠️  Chưa có baseline cho $ARCH."
    echo "   Chạy: scripts/run-benchmarks.sh --update trên MÁY CHUẨN của kiến trúc này"
    echo "   (STP §2.1: MacBook Air M1 8 GB · MacBook Pro 13\" 2019 i5 8 GB)."
    exit 0
fi

python3 - "$RESULT" "$BASELINE" "$TOLERANCE" <<'PY'
import json, sys

result = json.load(open(sys.argv[1]))["metrics"]
baseline = json.load(open(sys.argv[2]))["metrics"]
tolerance = float(sys.argv[3])

# Chỉ số kết thúc bằng "Ms" là THỜI GIAN (thấp hơn = tốt hơn);
# còn lại là THÔNG LƯỢNG (cao hơn = tốt hơn).
failures = []
for name, base in sorted(baseline.items()):
    if name not in result:
        failures.append(f"{name}: thiếu trong kết quả đo")
        continue
    current = result[name]
    lower_is_better = name.endswith("Ms")
    if lower_is_better:
        delta = (current - base) / base
        ok = delta <= tolerance
        arrow = f"{base:.2f} → {current:.2f} ms"
    else:
        delta = (base - current) / base
        ok = delta <= tolerance
        arrow = f"{base:.2f} → {current:.2f} MB/s"
    mark = "✅" if ok else "❌"
    print(f"  {mark} {name:32s} {arrow}  ({delta*100:+.1f}% xấu đi)")
    if not ok:
        failures.append(f"{name}: suy giảm {delta*100:.1f}% > {tolerance*100:.0f}%")

if failures:
    print("\n❌ CHẶN MERGE — KPI suy giảm quá ngưỡng (STP §4.1):")
    for failure in failures:
        print(f"   · {failure}")
    sys.exit(1)

print("\n✅ Mọi KPI trong ngưỡng cho phép")
PY
