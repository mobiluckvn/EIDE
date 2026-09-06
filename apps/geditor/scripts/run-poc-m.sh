#!/bin/bash
# PoC-M — BM25 Retrieval Lab có đạt NFR-KNW-04 không, và điểm có ĐỐI CHỨNG được không?
#
#   scripts/run-poc-m.sh            corpus 1 GB (mặc định)
#   scripts/run-poc-m.sh 200        corpus 200 MB, cho vòng lặp sửa mã
#
# NFR-KNW-04 đặt bốn con số: dựng chỉ mục 1 GB ≤ 30 s · truy vấn top-k ≤ 500 ms · điểm tất định ·
# **và điểm đối chứng được với một cài đặt tham chiếu, sai số ≤ 1e-9**.
#
# VẾ THỨ TƯ LÀ VẾ ĐÁNG LÀM NHẤT, và nó là lý do script này tồn tại thay vì chỉ một KPI Swift.
# Ba vế đầu đo TỐC ĐỘ — chúng nói bộ máy có nhanh không, không nói nó có ĐÚNG không. Một cài đặt
# BM25 sai công thức vẫn chạy nhanh, vẫn tất định, và vẫn xếp hạng sai mà không có gì trong sản
# phẩm chỉ ra điều đó.
#
# Nên bước 2 dưới đây chấm lại bằng một cài đặt **viết độc lập bằng Python**, đọc thẳng công thức
# Robertson/Sparck-Jones. Hai bản, hai ngôn ngữ, một công thức: lệch nhau ở đâu là ở đó có người
# hiểu sai — và "người" ấy có thể là bản Swift.
#
# CỐ Ý KHÔNG vendor gì: corpus sinh vào `.build/poc-m/`, ngoài git.
set -uo pipefail
cd "$(dirname "$0")/.."

MB="${1:-1024}"
ARCH="$(uname -m)"
RESULT="benchmarks/results/poc-m-${ARCH}.json"

echo "▸ Dựng bản Release…"
swift build -c release --product geditor-bench >/dev/null || exit 1

echo "▸ Bước 1/2 — đo tốc độ và tất định (corpus ${MB} MB)"
echo
.build/release/geditor-bench poc-m --mb "$MB" >/dev/null
STATUS=$?

if [ ! -f "$RESULT" ]; then
    echo "❌ không thấy $RESULT" >&2
    exit 1
fi

python3 - "$RESULT" <<'PYTHON'
import json, sys
d = json.load(open(sys.argv[1]))
mb = d["corpusBytes"] / 1e6
print(f'  corpus        {mb:,.0f} MB · {d["documentCount"]:,} tài liệu · '
      f'{d["termCount"]:,} từ khoá · {d["totalTokens"]:,} token')
print(f'  dựng chỉ mục  {d["buildMs"]:,.0f} ms   / trần {d["buildBudgetMs"]:,} ms')
print(f'  chỉ mục       {d["indexBytes"]/1e6:,.0f} MB  ({d["indexRatio"]*100:.0f}% cỡ corpus)')
print(f'  truy vấn      {d["queryMedianMs"]:.1f} ms (trung vị) / trần {d["queryBudgetMs"]} ms')
# RAM in ra để BIẾT, không để CHẤM — xem chú thích ở cuối tệp.
print(f'  RAM           {d["rssBeforeMB"]:.0f} → {d["rssPeakMB"]:.0f} MB (chỉ báo, không lặp lại)')
print(f'  tất định      {"CÓ" if d["deterministic"] else "KHÔNG"}')
print(f'  lai (NFR-05)  {d["hybridRerankWorstMs"]:,.1f} ms xấu nhất / trần '
      f'{d["hybridRerankBudgetMs"]} ms   (trung vị {d["hybridRerankMedianMs"]:,.1f} ms · '
      f'{d["hybridEntityCount"]} entity)')
print(f'  golden 1.000  {d["goldenMs"]:,.0f} ms  / trần {d["goldenBudgetMs"]:,} ms   '
      f'(bản đồ id {d["goldenIdentifierMapMs"]:,.0f} ms · {d["goldenScoredCount"]} câu chấm được)')
PYTHON

echo
echo "▸ Bước 2/2 — chấm lại bằng cài đặt Python ĐỘC LẬP (đối chứng ≤ 1e-9)"
echo

python3 - "$RESULT" <<'PYTHON'
"""Cài đặt BM25 tham chiếu, viết từ công thức chứ không đọc mã Swift.

    idf(t) = ln( 1 + (N − df + 0,5) / (df + 0,5) )
    score  = Σ idf(t) · tf · (k1 + 1) / ( tf + k1 · (1 − b + b · |d| / avgdl) )

Bộ tách token phải khớp `BM25Tokenizer`: cắt theo ranh giới chữ/số, hạ chữ thường, GIỮ dấu.
Đây cũng là một phép kiểm: nếu hai bên hiểu "ranh giới token" khác nhau thì điểm lệch ngay,
và đó là thứ đáng biết trước khi có một corpus thật.
"""
import json, math, sys, unicodedata

result = json.load(open(sys.argv[1]))
corpus_path, rows = result["checkCorpus"], result["checkRows"]
K1, B = 1.2, 0.75

def tokens(text):
    out, current = [], []
    for ch in text:
        if ch.isalnum():
            current.append(ch.lower())
        elif current:
            out.append("".join(current)); current = []
    if current: out.append("".join(current))
    return out

docs = []
for line in open(corpus_path, encoding="utf8"):
    line = line.strip()
    if not line:
        docs.append([]); continue
    try:
        docs.append(tokens(json.loads(line).get("text", "")))
    except Exception:
        docs.append([])

N = len(docs)
avgdl = sum(len(d) for d in docs) / N if N else 0
df = {}
for d in docs:
    for term in set(d):
        df[term] = df.get(term, 0) + 1

def score(query, doc):
    total = 0.0
    for term in dict.fromkeys(tokens(query)):
        n = df.get(term, 0)
        if n == 0: continue
        tf = docs[doc].count(term)
        if tf == 0: continue
        idf = math.log(1 + (N - n + 0.5) / (n + 0.5))
        total += idf * tf * (K1 + 1) / (tf + K1 * (1 - B + B * len(docs[doc]) / avgdl))
    return total

worst, checked = 0.0, 0
for row in rows:
    mine = score(row["query"], row["doc"])
    delta = abs(mine - row["score"])
    worst = max(worst, delta)
    checked += 1

print(f"  đối chứng     {checked} cặp (câu hỏi × tài liệu) trên {N} tài liệu")
print(f"  lệch lớn nhất {worst:.3e}   / trần 1e-9")
if worst > 1e-9:
    print("\n❌ ĐỐI CHỨNG TRƯỢT — hai cài đặt không cùng một công thức.")
    sys.exit(1)
print("\n✅ hai cài đặt độc lập cho cùng một điểm số")
PYTHON
CHECK=$?

echo
if [ "$STATUS" = "0" ] && [ "$CHECK" = "0" ]; then
    echo "✅ PoC-M ĐẠT — kết quả ở $RESULT"
    exit 0
fi
echo "❌ PoC-M TRƯỢT — xem số ở trên và $RESULT" >&2
exit 1

# ---------------------------------------------------------------------------------------------
# Hai điều đã đo và KHÔNG có trong bốn con số trên, ghi lại để lần sau khỏi đo lại:
#
# 1. **Cỡ khối không phải núm chỉnh tốc độ.** Dò `--block-mb` từ 4 tới 1024 trên corpus 1 GB cho
#    ra 19–22 giây ở MỌI mức — kể cả mức 1024 MB, tức là gom cả corpus vào một khối và không
#    trộn lần nào. Nói cách khác bước trộn k đường gần như miễn phí, và chỗ tốn nằm ở đường cắt
#    token + ghi posting. Ai định tối ưu tiếp thì bắt đầu từ đó, đừng bắt đầu từ cỡ khối.
#
# 2. **Con số RAM ở trên không lặp lại, đừng quyết định gì từ nó.** Nó từng là RSS *tại thời
#    điểm gọi* nhưng mang tên `rssPeak` — sai, đã sửa sang `resident_size_max`. Bản đã sửa vẫn
#    lệch tới 40% giữa hai lượt chạy cùng cấu hình (khối 8 MB: 934 rồi 752 MB; khối 16 MB: 1473
#    rồi 1562 MB), vì số trang còn nằm lại trong RSS phụ thuộc áp lực bộ nhớ của CẢ MÁY chứ
#    không chỉ của tiến trình này. Suýt nữa nó thành căn cứ để đổi cỡ khối mặc định.
#
#    NFR-KNW-04 không đặt trần RAM, nên đây là ghi chú chứ không phải cổng. Muốn biến nó thành
#    cổng thì phải đo bằng thứ khác — `phys_footprint` với máy ở trạng thái chuẩn STP §2.1.
