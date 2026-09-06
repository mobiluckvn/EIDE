#!/bin/bash
# PoC-D — tô màu cú pháp bằng tree-sitter (SAD §8, ADR-04).
#
# Bộ nhớ đo trong TIẾN TRÌNH RIÊNG cho từng phép, không đo bằng hiệu số trong cùng một tiến
# trình: phép đo sau dùng lại vùng nhớ phép đo trước vừa trả, và con số báo về nhỏ hơn thật.
# Bản đầu của PoC này báo "cây C tốn 0,0 MB" — vô lý, mà vẫn suýt được ghi vào ADR.
set -euo pipefail
cd "$(dirname "$0")/.."

SIZES="${1:-1,8,64}"
OUT="${2:-benchmarks/poc-d.json}"

echo "▸ Dựng bản release…" >&2
swift build -c release --product geditor-bench >/dev/null

echo "▸ Tốc độ, tăng dần, truy vấn, độ chính xác cửa sổ…" >&2
MAIN=$(.build/release/geditor-bench poc-d --mb "$SIZES")

echo "▸ Bộ nhớ — mỗi phép một tiến trình…" >&2
MEM="["
first=1
for lang in json c; do
    for mb in ${SIZES//,/ }; do
        sample=$(.build/release/geditor-bench poc-d-mem --lang "$lang" --mb "$mb")
        [ $first -eq 0 ] && MEM="$MEM,"
        MEM="$MEM$sample"
        first=0
    done
done
MEM="$MEM]"

mkdir -p "$(dirname "$OUT")"
python3 - "$OUT" <<PY
import json, sys
main = json.loads('''$MAIN''')
main["memory"] = json.loads('''$MEM''')
json.dump(main, open(sys.argv[1], "w"), ensure_ascii=False, indent=2, sort_keys=True)
PY
echo "▸ Xong → $OUT" >&2
