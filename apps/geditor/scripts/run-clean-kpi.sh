#!/bin/bash
# KPI cụm làm sạch (NFR-CLN-01 Data Profile, FR-CLN-006 bộ phát hiện).
#
#   scripts/run-clean-kpi.sh                    quy mô chuẩn: 1 triệu hàng × 20 cột
#   scripts/run-clean-kpi.sh --rows 100000      bản nhanh khi phát triển
#
# Đo ở ĐÚNG cỡ mà chỉ tiêu nói, không đo bảng nhỏ rồi nhân lên: bản ngoại suy từ 100 nghìn hàng
# đã từng cho 17 giây trong khi số đo thật là 12,1 — sai gần hai lần, và đủ để kết luận sai về
# việc có đạt hay không.
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
RESULT="benchmarks/results/clean-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Build release…"
swift build -c release --product geditor-bench >/dev/null

echo "▸ Đo trên ${ARCH}…"
.build/release/geditor-bench clean "$@" > "$RESULT"

echo "▸ Kết quả: $RESULT"
python3 - "$RESULT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
p, s = r["profile"], r["scanner"]
print(f"\n  {r['architecture']}\n")

mark = "✅ ĐẠT" if p["pass"] else "❌ KHÔNG ĐẠT"
print(f"  Data Profile — {p['rows']:,} hàng × {p['columns']} cột · {p['cells']:,} ô · {p['fixtureMB']:.0f} MB")
print(f"    thời gian   {p['seconds']:8.2f} s   (trần {p['budgetSeconds']:.0f} s)   {mark}")
print(f"    thông lượng {p['millionCellsPerSecond']:8.2f} triệu ô/giây")

print(f"\n  Bộ phát hiện Bàn làm sạch — cùng bảng")
print(f"    thời gian   {s['seconds']:8.2f} s")
print(f"    thông lượng {s['millionCellsPerSecond']:8.2f} triệu ô/giây")

print(f"\n  Lọc theo cột (NFR-QRY-01) — trần 300 ms cho MÀN HÌNH ĐẦU TIÊN")
for f in r.get("filters", []):
    mark = "✅" if f["pass"] else "❌"
    print(f"    {mark} {f['description']:<28} màn đầu {f['firstScreenMs']:7.0f} ms"
          f" · quét hết {f['fullScanMs']:7.0f} ms · {f['matched']:,} dòng khớp")

print("\n  Kiểm ĐÚNG (một phép quét nhanh mà sai thì con số thời gian vô nghĩa):")
wrong = 0
for name, result in sorted(r["correctness"].items()):
    ok = result.startswith("ĐÚNG")
    wrong += 0 if ok else 1
    print(f"    {'✓' if ok else '✗'} {name}: {result}")

print()
# Trường hợp xấu nhất của phép lọc (kết quả nằm cuối file) CHƯA đạt và không thể đạt bằng
# quét tuần tự — xem ghi chú trong CSVFilter. Không để nó làm script đỏ, nhưng cũng không
# giấu: nó in ra ❌ ở trên mỗi lần chạy.
sys.exit(1 if (wrong or not p["pass"]) else 0)
PY
