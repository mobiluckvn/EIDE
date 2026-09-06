#!/bin/bash
# KPI khởi động và RAM nhàn rỗi — NFR-PERF-01, NFR-PERF-05.
#
#   scripts/run-startup-kpi.sh            5 lần nguội + 5 lần ấm
#   scripts/run-startup-kpi.sh --runs 10
#
# NGUỘI và ẤM là hai con số khác hẳn nhau, và chỉ tiêu nói về NGUỘI:
#
#   - "nguội" = binary chưa nằm trong page cache. Mô phỏng bằng cách chạy một BẢN SAO mới mỗi
#     lần; không dùng `purge` vì nó cần sudo và xóa cache của cả máy.
#   - "ấm" = chạy lại chính binary ấy. Đây là thứ lập trình viên thấy khi thử đi thử lại, và
#     là lý do một chỉ tiêu khởi động dễ được tưởng là đạt trong khi nó không đạt.
#
# Mỗi lần đo tách làm hai phần: dyld (nạp + liên kết framework, trước cả `main()`) và app
# (dựng cửa sổ cho tới khi nhận được thao tác gõ). Biết phần nào lớn mới biết tối ưu chỗ nào.
set -uo pipefail

cd "$(dirname "$0")/.."

RUNS=5
if [ "${1:-}" = "--runs" ] && [ -n "${2:-}" ]; then RUNS="$2"; fi

ARCH="$(uname -m)"
RESULT="benchmarks/results/startup-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Build release…"
swift build -c release --product GEditorApp >/dev/null || exit 1
# Dựng cả dylib grammar nặng và ĐẶT NÓ CẠNH BINARY trong phép đo dưới đây.
#
# Đây là chỗ dễ tự lừa nhất: bỏ dylib đi thì khởi động nhanh hơn, nhưng ba ngôn ngữ mất màu —
# con số đẹp ấy đo một sản phẩm khác với sản phẩm ta giao. Có dylib nằm cạnh mới đúng hình dạng
# thật, và nó KHÔNG được cộng vào thời gian khởi động vì `dlopen` chỉ chạy khi mở file C++/C#/
# Ruby. Chính khác biệt ấy là thứ ADR-08 muốn đo.
swift build -c release --product TreeSitterHeavy >/dev/null || exit 1
RAW="$(swift build -c release --product GEditorApp --show-bin-path)/GEditorApp"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Đo bản ĐÃ STRIP, vì đó là thứ `build-universal.sh` giao (ADR-08 §2.12).
#
# Bảng ký hiệu cục bộ nặng 2,13 MB và đáng ~68 ms ở lần khởi động đầu tiên — bỏ bước này thì
# KPI báo một con số xấu hơn sản phẩm thật, đúng lỗi ngược với cái bẫy dylib nói ở trên, và
# cũng sai bằng ấy.
BIN="$TMP/GEditorApp"
cp "$RAW" "$BIN"
strip -x "$BIN"
codesign -f -s - "$BIN" 2>/dev/null || true

echo "▸ Đo trên ${ARCH} — ${RUNS} lần nguội, ${RUNS} lần ấm…"

COLD="[]"
WARM="[]"
HEAVY="$(dirname "$RAW")/libTreeSitterHeavy.dylib"
cp "$HEAVY" "$TMP/libTreeSitterHeavy.dylib"
# Sparkle liên kết LÚC NẠP (ADR-16), nên thiếu nó thì binary chép sang đây không chạy nổi và
# bản đo im lặng ra rỗng. Chép cạnh binary, cùng cách đã làm với dylib grammar — rpath
# `@loader_path` trong Package.swift có mặt đúng vì việc này.
cp -R vendor/sparkle/Sparkle.framework "$TMP/Sparkle.framework"

for i in $(seq 1 "$RUNS"); do
    cp "$BIN" "$TMP/G$i"
    COLD="$COLD $("$TMP/G$i" --measure-startup 2>/dev/null)"
done
for i in $(seq 1 "$RUNS"); do
    WARM="$WARM $("$BIN" --measure-startup 2>/dev/null)"
done

python3 - "$RESULT" <<PY
import json, re, sys, statistics

cold_raw = """$COLD"""
warm_raw = """$WARM"""

def parse(raw):
    # Tìm từng đối tượng JSON LỒNG NHAU được, không dùng regex "{ không chứa {".
    #
    # Regex ấy từng đúng, rồi im lặng sai khi bản đo mọc thêm mảng "marks": mỗi mốc là một
    # đối tượng CON, nên regex bắt đúng những đối tượng con ấy và bỏ qua đối tượng thật bao
    # ngoài. Nó không báo lỗi — chỉ ném KeyError ở tận bước thống kê.
    #
    # (Đừng đặt dấu nháy ngược trong khối này: heredoc của script không được trích dẫn, nên
    # shell coi chúng là thay thế lệnh và chạy thứ nằm giữa.)
    decoder = json.JSONDecoder()
    runs, i = [], 0
    while True:
        i = raw.find("{", i)
        if i < 0:
            return runs
        try:
            value, end = decoder.raw_decode(raw, i)
        except ValueError:
            i += 1
            continue
        if isinstance(value, dict) and "startupMs" in value:
            runs.append(value)
            i = end
        else:
            i += 1

cold, warm = parse(cold_raw), parse(warm_raw)
if not cold or not warm:
    print("Không đọc được kết quả đo"); sys.exit(2)

def stats(runs, key):
    values = sorted(r[key] for r in runs)
    return {
        "min": values[0], "median": statistics.median(values), "max": values[-1],
    }

report = {
    "kpi": ["NFR-PERF-01 (khởi động nguội)", "NFR-PERF-05 (RAM nhàn rỗi)"],
    "architecture": "$ARCH",
    "budgetMs": 500,
    "budgetMB": 80,
    "cold": {k: stats(cold, k) for k in ("startupMs", "preMainMs", "appLaunchMs")},
    "warm": {k: stats(warm, k) for k in ("startupMs", "preMainMs", "appLaunchMs")},
    "idleFootprintMB": stats(cold + warm, "idleFootprintMB"),
    "startupPass": stats(cold, "startupMs")["median"] <= 500,
    "memoryPass": stats(cold + warm, "idleFootprintMB")["median"] <= 80,
}
json.dump(report, open(sys.argv[1], "w"), ensure_ascii=False, indent=2, sort_keys=True)

c, w, mem = report["cold"], report["warm"], report["idleFootprintMB"]
mark = "✅ ĐẠT" if report["startupPass"] else "❌ KHÔNG ĐẠT"
print()
print(f"  {report['architecture']}")
print()
print(f"  Khởi động NGUỘI — trần 500 ms   {mark}")
print(f"    tổng      {c['startupMs']['median']:7.0f} ms   (min {c['startupMs']['min']:.0f} · max {c['startupMs']['max']:.0f})")
print(f"      dyld    {c['preMainMs']['median']:7.0f} ms   nạp và liên kết, TRƯỚC main()")
print(f"      app     {c['appLaunchMs']['median']:7.0f} ms   dựng cửa sổ tới lúc nhận gõ")
print()
print(f"  Khởi động ẤM (không phải chỉ tiêu, để so sánh)")
print(f"    tổng      {w['startupMs']['median']:7.0f} ms")
print()
memMark = "✅ ĐẠT" if report["memoryPass"] else "❌ KHÔNG ĐẠT"
print(f"  RAM nhàn rỗi — trần 80 MB       {memMark}")
print(f"    phys_footprint {mem['median']:5.1f} MB   (min {mem['min']:.1f} · max {mem['max']:.1f})")
print()
sys.exit(0 if (report["startupPass"] and report["memoryPass"]) else 1)
PY

STATUS=$?
echo "▸ Kết quả: $RESULT"
exit $STATUS
