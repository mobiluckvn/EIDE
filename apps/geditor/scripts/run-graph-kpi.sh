#!/bin/bash
# NFR-KNW-03 — năm thuật toán đồ thị có chạy nổi một triệu cạnh không?
#
#   scripts/run-graph-kpi.sh              1.000.000 cạnh (mặc định)
#   scripts/run-graph-kpi.sh 100000       nhỏ hơn, cho vòng lặp sửa mã
#
# Chỉ tiêu đặt bốn con số: 2-hop ≤ 2 s · liên thông ≤ 10 s · PageRank ≤ 30 s · Louvain ≤ 60 s.
# Bộ đo chấm cả ba vế còn lại của chỉ tiêu mà một bảng thời gian dễ bỏ sót:
#
#   * CSR dựng MỘT lần và tái dùng — nên thời gian dựng đo riêng, không cộng vào từng thuật toán;
#   * mọi tác vụ có tiến trình + hủy — nên đếm số nhịp tiến độ và khoảng cách lớn nhất giữa hai
#     nhịp (khoảng ấy chính là độ trễ tệ nhất của nút Huỷ);
#   * tất định theo NFR-MIN-02 — nên Louvain chạy hai lượt và hai kết quả phải bằng nhau.
#
# ĐỒ THỊ MẪU CÓ CẤU TRÚC CỤM VÀ MỘT NODE TRUNG TÂM, và đó không phải chi tiết trang trí. Bản đầu
# sinh đồ thị đều tăm tắp: mọi node bậc 8, nên "2-hop" chỉ chạm hơn trăm node và đo được 0 ms —
# một con số đúng cho một câu hỏi mà chỉ tiêu 2 giây rõ ràng không hỏi. Cùng bài học đã trả giá ở
# PoC-M: một chỉ tiêu tốc độ chỉ đáng tin bằng ĐẦU VÀO dùng để đo nó.
set -uo pipefail
cd "$(dirname "$0")/.."

EDGES="${1:-1000000}"
ARCH="$(uname -m)"
RESULT="benchmarks/results/graph-${ARCH}.json"

echo "▸ Dựng bản Release…"
swift build -c release --product geditor-bench >/dev/null || exit 1

.build/release/geditor-bench graph --edges "$EDGES"
STATUS=$?

if [ ! -f "$RESULT" ]; then
    echo "❌ không thấy $RESULT" >&2
    exit 1
fi

echo
python3 - "$RESULT" <<'PYTHON'
import json, sys
d = json.load(open(sys.argv[1]))
# Vế "mọi tác vụ có tiến trình + hủy ≤ 200 ms" của NFR-KNW-03: khoảng cách lớn nhất giữa hai
# nhịp tiến độ CHÍNH LÀ độ trễ tệ nhất của nút Huỷ.
problems = []
for name, step in sorted(d["steps"].items()):
    if step["ticks"] == 0 and step["ms"] > 200:
        problems.append(f'{name}: chạy {step["ms"]:.0f} ms mà KHÔNG có nhịp tiến độ nào')
    if step["worstGapMs"] > 200:
        problems.append(f'{name}: {step["worstGapMs"]:.0f} ms giữa hai nhịp — nút Huỷ trễ quá 200 ms')
if problems:
    print("❌ " + "\n❌ ".join(problems))
    sys.exit(1)
print("✅ tiến trình + huỷ: mọi tác vụ đều dưới 200 ms giữa hai nhịp")
PYTHON
CHECK=$?

echo
if [ "$STATUS" = "0" ] && [ "$CHECK" = "0" ]; then
    echo "✅ NFR-KNW-03 ĐẠT — kết quả ở $RESULT"
    exit 0
fi
echo "❌ NFR-KNW-03 TRƯỢT — xem số ở trên và $RESULT" >&2
exit 1
