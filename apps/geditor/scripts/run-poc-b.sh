#!/bin/bash
# PoC-B — piece table trên mmap với file 1 GB (SAD §8, ADR-02).
#
# Khác với run-benchmarks.sh: đây KHÔNG phải cổng chặn merge mà là phép đo một lần để
# chốt ADR-02. Kết quả ghi vào benchmarks/results/poc-b-<arch>.json và số liệu được chép
# vào docs/adr/ADR-02-piece-table.md.
#
#   scripts/run-poc-b.sh                chạy đủ 1 GB (mặc định)
#   scripts/run-poc-b.sh --mb 256       chạy nhanh khi phát triển
#
# Fixture 1 GB được sinh NGOÀI repo. Đặt GEDITOR_FIXTURE_DIR để chọn nơi chứa;
# mặc định là thư mục tạm của hệ thống.
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
RESULT="benchmarks/results/poc-b-${ARCH}.json"
FIXTURE_DIR="${GEDITOR_FIXTURE_DIR:-$TMPDIR}"

mkdir -p benchmarks/results

# 1 GB fixture + bản sao khi sinh: cần ~2 GB trống để chắc chắn.
AVAILABLE_KB="$(df -k "$FIXTURE_DIR" | awk 'NR==2 {print $4}')"
if [ "$AVAILABLE_KB" -lt 2097152 ]; then
    echo "❌ Cần ít nhất 2 GB trống tại $FIXTURE_DIR (còn $((AVAILABLE_KB / 1024)) MB)."
    echo "   Đặt GEDITOR_FIXTURE_DIR sang ổ khác, hoặc chạy với --mb nhỏ hơn."
    exit 1
fi

echo "▸ Build release…"
swift build -c release --product geditor-bench >/dev/null

echo "▸ Đo PoC-B trên ${ARCH} (fixture tại ${FIXTURE_DIR})…"
.build/release/geditor-bench poc-b "$@" > "$RESULT"

echo "▸ Kết quả: $RESULT"
python3 - "$RESULT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
print(f"\n  {r['architecture']} · SIMD {r['simdBackend']} · {r['fixture']['megabytes']:.0f} MB "
      f"· {r['fixture']['lineCount']:,} dòng")

o = r["open"]
print(f"\n  MỞ FILE")
print(f"    mmap                       {o['mmapMs']:8.1f} ms")
print(f"    dựng chỉ mục newline       {o['newlineIndexMs']:8.1f} ms")
print(f"    truy vấn dòng đầu tiên     {o['firstLineQueryMs']:8.3f} ms")
print(f"    TỔNG tới lúc tương tác     {o['totalMs']:8.1f} ms  ({o['throughputMBps']:.0f} MB/s)")

m = r["memory"]
print(f"\n  BỘ NHỚ")
print(f"    footprint nền              {m['baselineFootprintMB']:8.1f} MB")
print(f"    footprint sau khi mở       {m['afterOpenFootprintMB']:8.1f} MB   ← ràng buộc NFR-PERF-05")
print(f"    resident sau khi mở        {m['afterOpenResidentMB']:8.1f} MB   (gồm trang mmap sạch)")
print(f"    footprint sau khi sửa      {m['afterEditsFootprintMB']:8.1f} MB")
print(f"    bảng mốc chỉ mục newline   {m['newlineIndexKB']:8.1f} KB")

t = r["interactiveEdits"]
print(f"\n  GÕ PHÍM ({t['edits']:,} lần, mỗi lần gồm cả đọc lại vị trí con trỏ)")
print(f"    p50 {t['p50Us']:8.1f} µs   p95 {t['p95Us']:8.1f} µs   p99 {t['p99Us']:8.1f} µs   max {t['maxUs']:8.1f} µs")

b = r["batchEdit"]
print(f"\n  MỘT NHÓM {b['edits']:,} SỬA = MỘT BƯỚC UNDO (FR-CORE-004)")
print(f"    áp dụng {b['applyMs']:8.1f} ms · undo {b['undoMs']:8.1f} ms · redo {b['redoMs']:8.1f} ms")
print(f"    {b['pieceCountAfter']:,} piece · độ sâu cây {b['treeDepthAfter']}")

q = r["lineQuery"]
print(f"\n  TRA CỨU DÒNG trên tài liệu {q['pieceCount']:,} piece")
print(f"    offset→dòng p95 {q['offsetToLineP95Us']:7.1f} µs · dòng→offset p95 {q['lineToOffsetP95Us']:7.1f} µs")

print(f"\n  ĐIỂM GÃY — cây piece vs mảng piece phẳng (gõ {r['scaling'][0]['edits']:,} lần)")
for s in r["scaling"]:
    print(f"    {s['megabytes']:5d} MB   cây {s['pieceTreeMs']:9.1f} ms   phẳng {s['flatArrayMs']:11.1f} ms   ×{s['speedup']:.0f}")
PY
