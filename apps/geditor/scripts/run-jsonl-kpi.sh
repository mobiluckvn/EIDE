#!/bin/bash
# NFR-KNW-02 — chế độ JSONL có mở nổi 1 GB không, và soi chunk có kịp không?
#
#   scripts/run-jsonl-kpi.sh          corpus 1 GB (mặc định)
#   scripts/run-jsonl-kpi.sh 200      corpus 200 MB, cho vòng lặp sửa mã
#
# NFR-KNW-02 đặt HAI con số, và chúng đo hai việc khác nhau:
#
#   1. "mở và index file JSONL 1 GB tới TRẠNG THÁI DUYỆT RECORD ĐƯỢC ≤ 10 giây"
#   2. "thống kê chunk 1 triệu record ≤ 15 giây"
#
# Vế 1 KHÔNG bao gồm việc kiểm từng bản ghi. Gộp chúng lại là tự đặt cho mình một chỉ tiêu khác
# với chỉ tiêu đã ký — và tệ hơn, là ép người dùng ngồi chờ trước một cửa sổ trống khi mở một
# tệp lớn. Nên: mở thì mmap + chỉ mục dòng (duyệt được ngay), còn kiểm là việc nền có tiến độ
# và huỷ. Bộ đo in cả hai để không ai nhầm con số này với con số kia.
#
# Corpus dùng LẠI của PoC-M (`.build/poc-m/`, ngoài git) — cùng bộ sinh có seed cố định, nên số
# liệu của hai bộ đo so được với nhau.
set -uo pipefail
cd "$(dirname "$0")/.."

MB="${1:-1024}"
ARCH="$(uname -m)"
RESULT="benchmarks/results/jsonl-${ARCH}.json"

echo "▸ Dựng bản Release…"
swift build -c release --product geditor-bench >/dev/null || exit 1

.build/release/geditor-bench jsonl --mb "$MB"
STATUS=$?

if [ ! -f "$RESULT" ]; then
    echo "❌ không thấy $RESULT" >&2
    exit 1
fi

echo
python3 - "$RESULT" <<'PYTHON'
import json, sys
d = json.load(open(sys.argv[1]))
# Ba tính chất KHÔNG nằm trong hai con số của chỉ tiêu, nhưng thiếu thì "duyệt được" là chữ suông.
problems = []
if d["jumpWorstMs"] > 50:
    problems.append(f'nhảy tới một bản ghi mất tới {d["jumpWorstMs"]:.1f} ms — '
                    '"duyệt được" phải là duyệt MƯỢT')
if not d["recognized"]:
    problems.append("không nhận ra tệp là JSONL")
if d["progressReports"] < 10:
    problems.append(f'chỉ {d["progressReports"]} nhịp tiến độ trên cả tệp — '
                    "nút Huỷ sẽ không ăn kịp")
if problems:
    print("❌ " + "\n❌ ".join(problems))
    sys.exit(1)
print(f'✅ nhảy tới bản ghi ≤ {d["jumpWorstMs"]:.2f} ms · '
      f'{d["progressReports"]} nhịp tiến độ · nhận diện CÓ')
PYTHON
CHECK=$?

echo
if [ "$STATUS" = "0" ] && [ "$CHECK" = "0" ]; then
    echo "✅ NFR-KNW-02 ĐẠT — kết quả ở $RESULT"
    exit 0
fi
echo "❌ NFR-KNW-02 TRƯỢT — xem số ở trên và $RESULT" >&2
exit 1
