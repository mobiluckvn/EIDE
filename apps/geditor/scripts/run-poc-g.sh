#!/bin/bash
# PoC-G — tập con SQL trên CSVEngine (FR-CSV-407, ADR-11).
#
#   scripts/run-poc-g.sh              1 triệu hàng × 20 cột — đúng cỡ NFR-CLN-01 nói tới
#   scripts/run-poc-g.sh 200000       cỡ khác
#
# Đo ĐÚNG cỡ chỉ tiêu chứ không đo cỡ nhỏ rồi nhân lên. Chi phí mỗi ô không phải hằng số: bảng
# băm đầy dần, bộ nhớ đệm trượt khác đi. Cùng bài này ở 100 nghìn hàng cho "so byte nhanh gấp
# đôi so String"; ở 1 triệu hàng thì chênh lệch ấy còn 5,6 % — cùng một mã, hai kết luận trái
# ngược, và chỉ con số ở cỡ thật mới dùng được.
set -euo pipefail
cd "$(dirname "$0")/.."

ROWS="${1:-1000000}"
ARCH="$(uname -m)"
OUT="benchmarks/results/poc-g-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Dựng bản release…" >&2
swift build -c release --product geditor-bench >/dev/null

.build/release/geditor-bench poc-g --rows "$ROWS" > "$OUT"

python3 - "$OUT" <<'PY'
import json, sys

report = json.load(open(sys.argv[1]))
fixture = report["fixture"]
print()
print("  %s · %s" % (report["poc"], report["architecture"]))
print("  %d hàng × %d cột · %.0f MB · %d ô"
      % (fixture["rows"], fixture["columns"], fixture["megabytes"], fixture["cells"]))
print()
print("  SÀN QUÉT — mọi câu truy vấn đều trả khoản này")
for scan in report["scan"]:
    print("    %8.0f ms   %5.1f triệu ô/giây   %s"
          % (scan["milliseconds"], scan["millionCellsPerSecond"], scan["path"]))
print()
print("  TRUY VẤN")
for query in report["queries"]:
    print("    %8.0f ms   %s" % (query["milliseconds"], query["sql"]))
print()
print("  MÃ SẢN PHẨM — CSVQueryRunner chạy chính câu SQL ấy")
for entry in report["product"]:
    if entry["prototypeMs"] is None:
        delta = "         "
    else:
        delta = "%+6.0f ms" % (entry["milliseconds"] - entry["prototypeMs"])
    print("    %8.0f ms %s  %s" % (entry["milliseconds"], delta, entry["sql"]))
    print("               quét %d hàng · %d hàng ra · %s"
          % (entry["rowsScanned"], entry["rowsOut"], entry["note"]))
print()
print("  BỘ NHỚ")
for entry in report["memory"]:
    print("    %s: %d nhóm · Δ %.1f MB · %d byte mỗi nhóm"
          % (entry["description"], entry["groups"], entry["deltaMB"], entry["bytesPerGroup"]))
print()
print("  ĐÚNG-SAI — số nhanh mà sai thì vô nghĩa")
wrong = 0
for name, verdict in sorted(report["correctness"].items()):
    bad = verdict.startswith("SAI") or "≠" in verdict
    wrong += bad
    print("    %s %s → %s" % ("❌" if bad else "✅", name, verdict))
print()
print("  %s" % report["verdict"])
print()
sys.exit(1 if wrong else 0)
PY

STATUS=$?
echo "▸ Kết quả: $OUT" >&2
exit $STATUS
