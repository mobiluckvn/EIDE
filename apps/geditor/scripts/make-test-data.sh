#!/bin/bash
# Sinh bộ dữ liệu LỚN để đo đường mở tệp và đường cuộn.
#
# Vì sao là script chứ không phải tệp trong kho: `data/` nằm trong .gitignore (dữ liệu thi
# thật có số báo danh của người thật), và một tệp 60 MB trong git là thứ không ai gỡ ra được
# nữa. Sinh lại được thì không cần giữ.
#
# Vì sao NHIỀU HÌNH DẠNG chứ không một tệp to. Bốn tệp dưới đây làm app đau ở bốn chỗ khác
# nhau, và một bộ đo chỉ có "một tệp thật to" sẽ bỏ lọt ba trong bốn:
#
#   nhieu-dong.csv   nhiều DÒNG    → chỉ mục dòng, hình học cuộn, thanh cuộn
#   nhieu-cot.csv    nhiều CỘT     → tô màu cột (một đoạn cho mỗi Ô, không phải mỗi dòng)
#   dong-dai.txt     dòng RẤT DÀI  → ngắt dòng mềm, phép đo cột thị giác, cuộn ngang
#   tieng-viet.csv   nhiều BYTE/ký tự → quy đổi offset byte ↔ UTF-16, và mọi chỗ đếm ký tự
#   sau-lop.json     MỘT khối lồng sâu → cây JSON, gấp theo cấp, JSONPath — đi theo CẤU TRÚC
#   chunk.jsonl      mỗi dòng một bản ghi → bộ soi chunk, chỉ mục BM25
#   nhieu-the.xml    nhiều thẻ lồng nhau → kiểm cú pháp XML, định dạng lại
#
# Ba tệp cuối thêm về sau, vì bốn tệp đầu KHÔNG chạm tới ba đường ấy: chúng duyệt theo cây thẻ
# hoặc theo từng bản ghi, không theo dòng, nên một tệp CSV to đến mấy cũng không đo được.
#
#   scripts/make-test-data.sh                sinh vào data/kiem-tra/
#   scripts/make-test-data.sh <thư-mục>      sinh vào chỗ khác
#   ROWS=200000 scripts/make-test-data.sh    đổi cỡ
set -euo pipefail

cd "$(dirname "$0")/.."

DEST="${1:-data/kiem-tra}"
ROWS="${ROWS:-1000000}"        # số dòng của tệp "nhiều dòng"
WIDE_ROWS="${WIDE_ROWS:-50000}"
WIDE_COLS="${WIDE_COLS:-200}"
LONG_LINES="${LONG_LINES:-2000}"
LONG_WIDTH="${LONG_WIDTH:-20000}"
VN_ROWS="${VN_ROWS:-400000}"
JSON_NODES="${JSON_NODES:-300000}"     # một khối JSON lồng sâu
JSONL_ROWS="${JSONL_ROWS:-200000}"     # mỗi dòng một chunk
XML_NODES="${XML_NODES:-250000}"       # mỗi thí sinh 8 dòng thẻ

mkdir -p "$DEST"

python3 - "$DEST" "$ROWS" "$WIDE_ROWS" "$WIDE_COLS" "$LONG_LINES" "$LONG_WIDTH" "$VN_ROWS" \
        "$JSON_NODES" "$JSONL_ROWS" "$XML_NODES" <<'PY'
import os, sys, random

dest, rows, wide_rows, wide_cols, long_lines, long_width, vn_rows, json_nodes, \
    jsonl_rows, xml_nodes = (sys.argv[1], *map(int, sys.argv[2:11]))

# Hạt giống CỐ ĐỊNH: hai lần chạy phải ra hai tệp giống hệt nhau, nếu không thì một con số đo
# đổi đi mà không ai biết là do mã đổi hay do dữ liệu đổi.
random.seed(20260831)

def ghi(name, dong_iter):
    path = os.path.join(dest, name)
    with open(path, "w", encoding="utf-8") as handle:
        # Ghi theo lô: một lời gọi write cho mỗi dòng làm bước sinh chậm hơn cả bước đo.
        batch = []
        for line in dong_iter:
            batch.append(line)
            if len(batch) >= 8192:
                handle.write("\n".join(batch) + "\n")
                batch.clear()
        if batch:
            handle.write("\n".join(batch) + "\n")
    print(f"   {name:<22} {os.path.getsize(path) / 1048576:8.1f} MB")

TINH = ["Hà Nội", "TP HCM", "Đà Nẵng", "Hải Phòng", "Cần Thơ", "Huế", "Nha Trang",
        "Vũng Tàu", "Buôn Ma Thuột", "Quy Nhơn"]
HO = ["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Phan", "Vũ", "Đặng", "Bùi", "Đỗ"]

def nhieu_dong():
    yield "so_bao_danh,ho_ten,tinh,toan,van,ngoai_ngu,tong,ghi_chu"
    for index in range(rows):
        yield (f"{index:08d},{HO[index % 10]} Văn {index % 9999},"
               f"{TINH[index % 10]},{index % 101 / 10:.1f},{(index * 7) % 101 / 10:.1f},"
               f"{(index * 13) % 101 / 10:.1f},{(index * 3) % 301 / 10:.1f},")

def nhieu_cot():
    yield ",".join(f"cot_{c:03d}" for c in range(wide_cols))
    for index in range(wide_rows):
        yield ",".join(str((index * (c + 1)) % 1000) for c in range(wide_cols))

def dong_dai():
    # Mỗi dòng là một câu tiếng Việt lặp lại tới đủ bề rộng — có dấu, có khoảng trắng, nên
    # phép ngắt dòng mềm có chỗ để gãy đúng biên từ.
    mau = "Đây là một dòng rất dài dùng để đo phép ngắt dòng mềm và phép cuộn ngang. "
    for index in range(long_lines):
        yield f"[{index:05d}] " + (mau * (long_width // len(mau) + 1))[:long_width]

def tieng_viet():
    yield "ma,ho_ten,dia_chi,ghi_chu"
    for index in range(vn_rows):
        yield (f"MA{index:07d},{HO[index % 10]} Thị Ngọc Ánh {index % 9999},"
               f"Số {index % 500} đường Nguyễn Huệ, phường {index % 30}, {TINH[index % 10]},"
               f"Ghi chú có dấu tiếng Việt — kèm gạch ngang và «ngoặc kép»")

def sau_lop_json():
    # JSON MỘT khối, lồng sâu và trải rộng — đường đau là cây JSON, phép gấp theo cấp và
    # JSONPath, cả ba đều đi theo CẤU TRÚC chứ không theo dòng. Một tệp CSV to không chạm tới
    # chúng dù có to đến đâu.
    yield "{"
    yield '  "meta": {"nguon": "sinh để đo", "phien_ban": 3},'
    yield '  "tinh": ['
    for index in range(json_nodes):
        dau = "    {"
        cuoi = "}," if index < json_nodes - 1 else "}"
        yield (f'{dau}"ma": "T{index:06d}", "ten": "{TINH[index % 10]}", '
               f'"diem": {{"toan": {index % 101 / 10:.1f}, "van": {(index * 7) % 101 / 10:.1f}, '
               f'"chi_tiet": {{"phong": {index % 40}, "ghi_chu": "có dấu tiếng Việt"}}}}{cuoi}')
    yield "  ]"
    yield "}"

def chunk_jsonl():
    # Mỗi dòng một bản ghi độc lập — đường đau là bộ soi chunk và chỉ mục BM25, cả hai đọc
    # TỪNG DÒNG như một tài liệu riêng.
    mau = ("Đoạn văn dùng để đo phép chia chunk và phép xếp hạng BM25. "
           "Nó có dấu tiếng Việt, có dấu chấm câu, và đủ dài để tính điểm có nghĩa. ")
    for index in range(jsonl_rows):
        than = (mau * (1 + index % 4)).replace('"', "'")
        yield ('{"chunk_id": "c%07d", "text": "%s", "meta": {"nguon": "%s", "trang": %d}}'
               % (index, than, TINH[index % 10], index % 500))

def nhieu_the_xml():
    # XML nhiều THẺ, lồng ba tầng — đường đau là phép kiểm cú pháp và phép định dạng lại, cả
    # hai duyệt cây thẻ chứ không duyệt dòng.
    yield '<?xml version="1.0" encoding="UTF-8"?>'
    yield "<danh_sach>"
    for index in range(xml_nodes):
        yield f'  <thi_sinh ma="TS{index:07d}">'
        yield f"    <ho_ten>{HO[index % 10]} Văn {index % 9999}</ho_ten>"
        yield f"    <tinh>{TINH[index % 10]}</tinh>"
        yield "    <diem>"
        yield f"      <toan>{index % 101 / 10:.1f}</toan>"
        yield f"      <van>{(index * 7) % 101 / 10:.1f}</van>"
        yield "    </diem>"
        yield "  </thi_sinh>"
    yield "</danh_sach>"

print("▸ Sinh dữ liệu đo…")
ghi("nhieu-dong.csv", nhieu_dong())
ghi("nhieu-cot.csv", nhieu_cot())
ghi("dong-dai.txt", dong_dai())
ghi("tieng-viet.csv", tieng_viet())
ghi("sau-lop.json", sau_lop_json())
ghi("chunk.jsonl", chunk_jsonl())
ghi("nhieu-the.xml", nhieu_the_xml())

# Tự chứng minh ba tệp mới ĐÚNG ĐỊNH DẠNG, bằng chính bộ phân tích của thư viện chuẩn.
#
# Vì sao cần: ba tệp này ghép bằng chuỗi, không qua `json.dumps` hay bộ ghi XML nào. Một dấu
# phẩy thừa ở phần tử cuối là tệp hỏng — và app sẽ báo "JSON hỏng" đúng như nó phải làm, nên
# phép đo trông như một lỗi của app trong khi lỗi nằm ở chính bộ sinh dữ liệu.
import json, xml.etree.ElementTree as ET

with open(os.path.join(dest, "sau-lop.json"), encoding="utf-8") as f:
    json.load(f)
with open(os.path.join(dest, "chunk.jsonl"), encoding="utf-8") as f:
    for so, dong in enumerate(f, 1):
        json.loads(dong)
ET.parse(os.path.join(dest, "nhieu-the.xml"))
print(f"   ✅ ba tệp mới đọc lại được bằng bộ phân tích chuẩn ({so} dòng JSONL)")
PY

echo
echo "✅ Xong. Đo bằng:"
echo "   ./.build/release/GEditorApp --measure-open $DEST/*"
