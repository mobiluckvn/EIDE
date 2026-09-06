#!/bin/bash
# Đo đường MỞ TỆP và đường CUỘN trên bộ dữ liệu lớn — `OpenProbe`.
#
# Vì sao có script này bên cạnh `geditor-bench`: bộ benchmark kia đo LÕI (đọc, tách dòng, tìm
# kiếm) và chạy được không cần giao diện. Thứ đo ở đây thì ngược lại — nó chỉ tồn tại bên
# trong một `NSApplication` có cửa sổ thật, vì chỗ tốn thời gian nằm ở tầng bố cục và tô màu.
#
# Bộ dữ liệu do `scripts/make-test-data.sh` sinh, và có BỐN HÌNH DẠNG chứ không một tệp to:
# nhiều dòng · nhiều cột · dòng rất dài · nhiều byte trên mỗi ký tự. Chúng làm app đau ở bốn
# chỗ khác nhau. Lượt đo đầu tiên chỉ có "một tệp thật to" và nó cho 8,4 ms — xanh; thêm tệp
# 200 cột vào thì cùng bản mã ấy cho 44,9 ms.
#
#   scripts/run-perf.sh              sinh dữ liệu nếu chưa có, rồi đo
#   scripts/run-perf.sh --lai        sinh lại dữ liệu rồi đo
set -euo pipefail

cd "$(dirname "$0")/.."

DEST="data/kiem-tra"
if [ "${1:-}" = "--lai" ] || [ ! -f "$DEST/nhieu-cot.csv" ]; then
    ./scripts/make-test-data.sh "$DEST"
fi

echo "▸ Dựng bản release…"
swift build -c release --product GEditorApp >/dev/null

# Tệp dữ liệu THẬT của anh cũng đo cùng, nếu còn đó: nó là ca đã sinh ra cả lượt tối ưu này.
EXTRA=()
[ -f data/diem_thi_tuoitre.csv ] && EXTRA+=("data/diem_thi_tuoitre.csv")

exec ./.build/release/GEditorApp --measure-open \
    "$DEST/nhieu-dong.csv" "$DEST/nhieu-cot.csv" \
    "$DEST/dong-dai.txt" "$DEST/tieng-viet.csv" "${EXTRA[@]}"
