#!/bin/bash
# PoC-C — PCRE2 + JIT trên hai kiến trúc và hành vi deadline (SAD §8, ADR-03).
#
# Chạy trên CẢ arm64 lẫn x86_64 vì NFR-PORT-01 đòi một bundle universal không Rosetta cho
# người dùng cuối — nhưng để ĐO nhánh x86_64 trên máy Apple Silicon thì chính ta phải dùng
# Rosetta. Hai việc khác nhau: Rosetta ở đây là dụng cụ đo, không phải phụ thuộc phát hành.
# Nếu không có Rosetta, script bỏ qua phần x86_64 và nói rõ là đã bỏ qua.
#
#   scripts/run-poc-c.sh                 đủ 100 MB, cả hai kiến trúc
#   scripts/run-poc-c.sh --mb 32         bản nhanh khi phát triển
set -euo pipefail

cd "$(dirname "$0")/.."

HOST_ARCH="$(uname -m)"
mkdir -p benchmarks/results

run_arch() {
    local arch="$1"; shift
    local result="benchmarks/results/poc-c-${arch}.json"

    echo "▸ Build release cho ${arch}…"
    swift build -c release --arch "$arch" --product geditor-bench >/dev/null

    # Hỏi SwiftPM thư mục đích thay vì đoán: đường dẫn khác nhau giữa bản một kiến trúc và
    # bản đa kiến trúc, và đoán nhầm thì ta lặng lẽ đo lại NHỊ PHÂN CŨ.
    local binary
    binary="$(swift build -c release --arch "$arch" --show-bin-path)/geditor-bench"
    [ -x "$binary" ] || { echo "❌ Không tìm thấy nhị phân: $binary"; exit 1; }

    echo "▸ Đo trên ${arch}…"
    if [ "$arch" = "$HOST_ARCH" ]; then
        "$binary" poc-c "$@" > "$result"
    else
        arch -"$arch" "$binary" poc-c "$@" > "$result"
    fi
    echo "▸ Kết quả: $result"
    summarize "$result"
}

summarize() {
    python3 - "$1" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
b = r["build"]
print(f"\n  {r['architecture']} · PCRE2 {b['pcre2Version']}")
print(f"  JIT: {'CÓ' if b['jitAvailable'] else 'KHÔNG'} · target {b['jitTarget']}")

print(f"\n  THROUGHPUT trên {r['fixtureMB']:.0f} MB")
print(f"    {'pattern':20s} {'JIT':>12s} {'interpreter':>14s} {'×':>8s}  kết quả")
for p in r["patterns"]:
    flag = " ⏱" if p["interpreterTimedOut"] else "  "
    print(f"    {p['name']:20s} {p['jitThroughputMBps']:9.0f} MB/s "
          f"{p['interpreterThroughputMBps']:9.0f} MB/s{flag} {p['jitSpeedup']:7.0f}  {p['matches']:,}")
print("    ⏱ = nhánh interpreter bị cắt vì quá hạn; × là CẬN DƯỚI")

d = r["deadline"]
print(f"\n  HIỆU CHỈNH TRẦN BACKTRACKING — {d['pattern']} trên {d['subjectLength']} byte")
print(f"    {'match_limit':>12s} {'JIT':>10s} {'interpreter':>13s}   kết cục")
for c in d["calibration"]:
    print(f"    {c['matchLimit']:12,d} {c['jitElapsedMs']:8.2f} ms {c['interpreterElapsedMs']:10.2f} ms   {c['outcome']}")
print(f"    → ngân sách {d['budgetMs']:.0f} ms/lần khớp ⇒ match_limit = {d['recommendedMatchLimit']:,} "
      f"(xấu nhất {d['worstCaseMsAtRecommended']:.1f} ms)")

u = r["utfCheckCost"]
print(f"\n  GIÁ CỦA VIỆC KIỂM UTF-8 LẶP LẠI ({u['fixtureMB']:.0f} MB, {u['matches']:,} kết quả)")
print(f"    kiểm một lần        {u['validatedOnceMs']:10.1f} ms")
print(f"    kiểm mỗi lần khớp   {u['recheckedEveryMatchMs']:10.1f} ms   ← ×{u['slowdown']:.0f}")

m = r["bulkMatch"]
print(f"\n  GOM {m['targetMatches']:,} KẾT QUẢ: {m['elapsedMs']:.0f} ms ({m['matchesPerSecond']/1e6:.1f} triệu/s)")
PY
}

run_arch "$HOST_ARCH" "$@"

OTHER_ARCH="x86_64"
[ "$HOST_ARCH" = "x86_64" ] && OTHER_ARCH="arm64"

echo
if arch -"$OTHER_ARCH" /usr/bin/true 2>/dev/null; then
    run_arch "$OTHER_ARCH" "$@"
else
    echo "⚠️  BỎ QUA kiến trúc ${OTHER_ARCH}: không chạy được nhị phân ${OTHER_ARCH} trên máy này."
    if [ "$HOST_ARCH" = "arm64" ]; then
        echo "   Cài Rosetta 2: softwareupdate --install-rosetta"
    fi
    echo "   NFR-PORT-01 CHƯA được xác nhận cho ${OTHER_ARCH} — ADR-03 phải ghi rõ điều này."
fi
