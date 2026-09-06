#!/bin/bash
# PoC-A (ADR-01) — đo Scintilla-Cocoa và TextKit 2 (SAD §8).
#
# MỖI cặp (engine, cỡ) chạy trong MỘT tiến trình riêng. Hai lý do, cả hai đều đã gặp thật:
#   - Bộ nhớ: hai engine chung tiến trình thì phys_footprint của engine sau bị trừ phần engine
#     trước vừa trả lại — có lần ra số âm.
#   - Sống sót: cỡ 500 MB có thể làm hệ điều hành giết tiến trình. Tiến trình riêng thì phần
#     đã đo được vẫn nằm trong báo cáo.
#
# Ba engine: scintilla, textkit (NSTextView giữ cả tài liệu), paged (NSTextView giữ một cửa
# sổ 2 MB, tài liệu nằm trong piece table). Ứng viên thứ tư — NSTextContentManager tùy biến —
# bị loại vì TextKit 2 không lái được nó; xem ADR-01 §6.1. Nó vẫn chạy được bằng tay với
# `--engine lazy` để ai muốn tự kiểm chứng.
#
# CẦN MÀN HÌNH: engine chỉ tiêu tiền khi có cửa sổ thật để vẽ. Chạy qua ssh không có phiên
# đồ họa sẽ ra số vô nghĩa.
set -uo pipefail

cd "$(dirname "$0")/.."

SIZES="${SIZES:-1 10 50 100 250 500}"
SAMPLES="${SAMPLES:-300}"
OUT="${OUT:-benchmarks/poc-a-$(date +%Y%m%d-%H%M%S).txt}"

mkdir -p "$(dirname "$OUT")"
swift build -c release --product geditor-poca || exit 1
BIN="$(swift build -c release --product geditor-poca --show-bin-path)/geditor-poca"

{
  echo "PoC-A · ADR-01"
  echo "ngày $(date '+%Y-%m-%d %H:%M:%S')"
  echo "macOS $(sw_vers -productVersion) · $(sysctl -n machdep.cpu.brand_string)"
  echo "kiến trúc chạy: $(uname -m)"
  echo
} > "$OUT"

for size in $SIZES; do
  for engine in scintilla textkit paged; do
    echo "▸ $engine · ${size} MB"
    "$BIN" --auto --engine "$engine" --sizes "$size" --samples "$SAMPLES" --out "$OUT" \
      >/dev/null 2>&1
    status=$?
    if [ $status -ne 0 ]; then
      echo "  ⚠️  tiến trình thoát với mã $status (nhiều khả năng hết RAM)"
      echo "── $engine · ${size} MB — TIẾN TRÌNH CHẾT (mã $status), nhiều khả năng hết RAM" >> "$OUT"
    fi
  done
done

echo
echo "▸ Báo cáo: $OUT"
echo "▸ Phần IME (Telex/EVKey) phải gõ tay: $BIN  rồi bấm 'Nạp 1 MB để gõ thử IME'"
