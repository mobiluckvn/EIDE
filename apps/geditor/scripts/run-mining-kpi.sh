#!/bin/bash
# NFR-MIN-01 · NFR-MIN-05 · NFR-DQR-03 · NFR-QRY-01 (vế huỷ) — bốn chỉ tiêu chưa ai đo.
#
#   scripts/run-mining-kpi.sh                    đúng cỡ chỉ tiêu (1 triệu hàng, mất vài phút)
#   scripts/run-mining-kpi.sh 50000 200 50000    cỡ nhỏ: rows groups baskets
#
# VÌ SAO CÓ SCRIPT NÀY. Ba mã trên nằm trong ô ⛔ của bảng trạng thái suốt nhiều phiên với đúng
# một câu: *"CÓ mã, chưa có phép đo"*. Tính năng chạy được, có test, nhưng chưa ai chứng minh nó
# đạt chỉ tiêu — cùng họ với món nợ "hai panel 0% độ phủ": làm xong không có nghĩa là đã đo.
#
# Đo ở ĐÚNG cỡ chỉ tiêu nói tới, không đo cỡ nhỏ rồi nhân lên (bài học PoC-G).
set -euo pipefail
cd "$(dirname "$0")/.."

# Tham số theo VỊ TRÍ: rows, groups, baskets. Không cờ, không vòng lặp đọc tham số.
#
# Và tên biến mang tiền tố `KPI_`, không phải `ROWS`/`GROUPS`/`BASKETS` trần.
#
# Một lượt xin 1.000 nhóm chạy ra "20 nhóm", im lặng, suốt mấy vòng thử — vì môi trường của
# người chạy đã có sẵn một biến tên `GROUPS`, và nó đè lên biến của script. Tên càng phổ thông
# thì càng dễ va: `ROWS`, `GROUPS`, `COUNT`, `LIMIT` đều là tên mà công cụ khác cũng đặt. Một bộ
# đo đọc sai tham số của chính nó thì mọi con số nó in ra đều không dùng được — và cái sai ấy
# không đỏ ở đâu cả.
KPI_ROWS="${1:-1000000}"
KPI_GROUPS="${2:-1000}"
KPI_BASKETS="${3:-1000000}"

ARCH="$(uname -m)"
OUT="benchmarks/results/mining-kpi-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Dựng bản release…" >&2
swift build -c release --product geditor-bench >/dev/null

.build/release/geditor-bench mining --rows "$KPI_ROWS" --groups "$KPI_GROUPS" --baskets "$KPI_BASKETS" > "$OUT"

python3 - "$OUT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))
print()
print("  %s · %s" % (r["kpi"], r["architecture"]))
print("  %d hàng × %d cột · %d nhóm" % (r["rows"], r["columns"], r["groupCount"]))
print()

def line(name, got, budget):
    ok = "✅" if got is not None and got <= budget else "❌"
    shown = "không đo được" if got is None else "%,.0f ms".replace(",", "") % got
    print("    %s %-34s %14s   / trần %.0f ms" % (ok, name, shown, budget))

line("NFR-MIN-01 bất thường", r["anomalyMs"], r["anomalyBudgetMs"])
line("NFR-MIN-01 k-means (k=20)", r["kMeansMs"], r["kMeansBudgetMs"])
line("NFR-MIN-01 apriori", r["aprioriMs"], r["aprioriBudgetMs"])
# `cancelMs` VẮNG MẶT khi không đo được: `JSONEncoder` của Swift bỏ hẳn khoá có giá
# trị nil chứ không ghi `null`. Đọc bằng `[...]` thì script chết với KeyError đúng lúc
# nó cần in ra câu "không đo được" — tức bộ đo im lặng đúng chỗ nó phải nói.
line("NFR-MIN-01 huỷ", r.get("cancelMs"), r["cancelBudgetMs"])
line("NFR-MIN-05 group-by", r["groupMiningMs"], r["groupMiningBudgetMs"])
line("NFR-QRY-01 huỷ phép lọc", r.get("filterCancelMs"), r["filterCancelBudgetMs"])
print("    %s %-34s" % ("✅" if r["deterministic"] else "❌",
                        "NFR-DQR-03 tất định từng bit"))
print("    %s %-34s %d/%d nhóm giữ lại"
      % ("✅" if r["partialMeasured"] else "❌",
         "NFR-MIN-05 huỷ giữ phần đã xong", r["partialGroupsKept"], r["groupCount"]))
print()
print("  apriori sinh %d luật · k-means chạy %d vòng" % (r["aprioriRules"], r["kMeansIterations"]))
for note in r["notes"]:
    print("  · %s" % note)
print()
print("  %s" % ("✅ ĐẠT — cả sáu vế" if r["pass"] else "❌ KHÔNG ĐẠT"))
print()
print("  Hai vế dễ xanh giả, và bộ đo từ chối cả hai:")
print("  · apriori phải sinh ra LUẬT, không thì con số chỉ đo lượt quét rỗng.")
print("  · huỷ phải cắt được GIỮA CHỪNG (0 < giữ lại < tổng), không thì nó chưa huỷ gì cả.")
PY
