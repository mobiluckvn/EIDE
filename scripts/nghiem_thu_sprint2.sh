#!/usr/bin/env bash
# Kịch bản nghiệm thu Sprint 2 — chạy chuỗi tri thức đầu-cuối trên một dự án MỚI TINH.
#
#   scripts/nghiem_thu_sprint2.sh [thư-mục-làm-việc]
#
# "Định nghĩa xong" của SPRINT-02 đòi một câu tiếng Việt đi qua Orchestrator ra một chuỗi năng
# lực CÓ TRÍCH DẪN, cổng đúng và báo cáo. Test dùng tmp_path và fixture; kịch bản này dùng CLI
# thật, dự án thật, store thật, ledger thật — nếu một mắt xích chỉ hoạt động trong pytest thì
# đây là chỗ lộ ra. Sprint 1 đã dính đúng chuyện ấy hai lần (actor lẫn lộn giữa hai tiến trình;
# daemon thấy hàng đợi mà không duyệt được).
#
# Phần A chạy thật chuỗi ĐÃ CÓ: dự án → hộ chiếu từ SVD → yêu cầu → kiến trúc → kế hoạch.
# Phần B báo cáo chỗ đứt của năm chuỗi chuẩn, suy từ spec (`scripts/kiem_chuoi_chuan.py`).
#
# KHÔNG bật `pipefail`: nhiều bước cố ý làm `eide` trả mã khác 0 rồi dùng `grep` xác nhận đúng
# mã lỗi ấy. Với `pipefail`, mã của `eide` nuốt mã của `grep` và một bước ĐẠT bị báo là hỏng.
set -u
cd "$(dirname "$0")/.."
PY="${PY:-./.venv-arm/bin/python}"
[ -x "$PY" ] || PY="./.venv-x86/bin/python"
[ -x "$PY" ] || PY="python3"
WS="${1:-${TMPDIR:-/tmp}/eide-nt2-$$}"
mkdir -p "$WS"

loi=0
buoc() { printf '\n\033[1m── %s\033[0m\n$ %s\n' "$1" "$2"; }
kiem() { if [ "$1" = 0 ]; then echo "   ✓ $2"; else echo "   ✗ $2"; loi=$((loi+1)); fi; }
inv() { $PY -m eide.cli caps invoke "$1" "$2" -p "$D" 2>&1; }

printf '\033[1mNGHIỆM THU SPRINT 2\033[0m — thư mục làm việc: %s\n' "$WS"

# ---------------------------------------------------------------- A. chuỗi tri thức thật

buoc "1. Tạo dự án" "eide project new \"đo nhiệt độ bằng STM32F411 và BME280\""
ID=$($PY -m eide.cli project new "đo nhiệt độ bằng STM32F411 và BME280" \
       --dir "$WS" --chip STM32F411 2>/dev/null | sed -n 's/.*"project_id": "\(.*\)",/\1/p')
D="$WS/$ID"
[ -n "$ID" ]; kiem $? "dự án: $ID"

buoc "2. Di trú store lên mốc M2" "eide migrate"
$PY -m eide.cli migrate -p "$D" >/dev/null 2>&1; kiem $? "migrate"
$PY - "$D" <<'PY'
import sys, sqlite3, pathlib
c = sqlite3.connect(pathlib.Path(sys.argv[1]) / ".eide" / "store" / "store.sqlite")
v = c.execute("PRAGMA user_version").fetchone()[0]
t = {r[0] for r in c.execute("SELECT name FROM sqlite_master WHERE type='table'")}
sys.exit(0 if v == 4 and {"module", "hw_map", "adr", "requirement"} <= t else 1)
PY
kiem $? "user_version=4, có module/hw_map/adr/requirement"

buoc "3. Ghim đích — ISA suy từ docs/spec/isa/*.yaml" "eide caps invoke project.set_target"
inv project.set_target '{"chip":"STM32F411CE"}' | tee "$WS/target.json" | head -8
grep -q '"isa": "armv7e-m"' "$WS/target.json"; kiem $? "ISA suy đúng armv7e-m"

buoc "4. Phân loại tệp theo CHỮ KÝ nội dung, không theo phần mở rộng" "ingest.classify"
cat > "$WS/stm32f411.xml" <<'SVD'
<?xml version="1.0"?>
<device><vendor>STMicroelectronics</vendor><name>STM32F411</name><peripherals>
<peripheral><name>SRAM</name><baseAddress>0x20000000</baseAddress>
<addressBlock><offset>0</offset><size>0x20000</size><usage>buffer</usage></addressBlock></peripheral>
<peripheral><name>I2C1</name><baseAddress>0x40005400</baseAddress>
<interrupt><name>I2C1_EV</name><value>31</value></interrupt>
<registers><register><name>CR1</name><addressOffset>0x00</addressOffset>
<resetValue>0x00000000</resetValue><fields><field><name>PE</name><bitRange>[0:0]</bitRange>
</field></fields></register></registers></peripheral>
<peripheral derivedFrom="I2C1"><name>I2C2</name><baseAddress>0x40005800</baseAddress></peripheral>
</peripherals></device>
SVD
inv ingest.classify "{\"files\":[\"$WS/stm32f411.xml\"]}" | tee "$WS/cls.json" | head -10
grep -q '"kind": "svd"' "$WS/cls.json"; kiem $? "tệp tên .xml nhận đúng là svd"
grep -q '"tier": "gold"' "$WS/cls.json"; kiem $? "tier gold theo bảng INGEST-01"

buoc "5. Trích SVD → fact → hộ chiếu" "extract.svd"
inv extract.svd "{\"file\":\"$WS/stm32f411.xml\"}" | tee "$WS/svd.json" | head -6
grep -q '"part": "chip:stmicroelectronics.stm32f411"' "$WS/svd.json"; kiem $? "IRI part đúng"
N=$(sed -n 's/.*"n_facts": \([0-9]*\).*/\1/p' "$WS/svd.json")
[ "${N:-0}" -ge 6 ]; kiem $? "sinh $N fact (derivedFrom giãn I2C2)"

buoc "6. Tra hộ chiếu — có trích dẫn và đo độ trễ" "passport.query"
inv passport.query '{"part":"stmicroelectronics.stm32f411"}' | grep -v '^-- run' > "$WS/pq.json"
$PY - "$WS/pq.json" <<'PY'
import json, sys
d = json.loads(open(sys.argv[1]).read())
ok = d["facts"] and d["citations"] and d["latency_ms"] < 200
print(f"   {len(d['facts'])} fact, {len(d['citations'])} trích dẫn, {d['latency_ms']} ms")
sys.exit(0 if ok else 1)
PY
kiem $? "trả fact + citations, < 200 ms (PASSPORT-02)"

buoc "7. I2C2 kế thừa thanh ghi của I2C1 qua derivedFrom" "passport.query --peripheral I2C2"
inv passport.query '{"part":"stmicroelectronics.stm32f411","peripheral":"I2C2"}' > "$WS/i2c2.json"
grep -q 'reg:CR1' "$WS/i2c2.json"; kiem $? "I2C2 có CR1 (không giải derivedFrom thì chỉ có base)"

buoc "8. Yêu cầu đo được → đối chiếu hộ chiếu" "req.ground_hw"
$PY - "$D" <<'PY'
import sys, pathlib
sys.path.insert(0, "src")
from eide.caps.req import _ghi_requirement
from eide_core import store
root = pathlib.Path(sys.argv[1])
_ghi_requirement(root, [{"id": "UR-SNS-01", "kind": "HW",
                         "text": "Bộ nhớ RAM tối thiểu 64 kb cho vùng đệm cảm biến"}])
with store.open_store(store.store_path(root)) as c:
    c.execute("UPDATE fact SET status='verified' WHERE predicate='memory_size'")
    c.commit()
# Khối này đóng vai `req.classify` (cần mô hình nên không gọi trong nghiệm thu). Năng lực thật
# ghi qua Router và Router niêm lại; scaffolding thì phải tự niêm, nếu không bước 12 báo lệch vì
# lỗi của kịch bản chứ không phải của sản phẩm.
store.write_seal(store.store_path(root))
PY
inv req.ground_hw '{"reqset_ids":["UR-SNS-01"],"passport":"stmicroelectronics.stm32f411@1.0.0"}' \
  > "$WS/gh.json"
grep -q '"ok": true' "$WS/gh.json"; kiem $? "kết luận khả thi"
grep -q '"facts": \[' "$WS/gh.json"; kiem $? "kết luận KÈM fact id để truy nguyên"

buoc "9. Kiến trúc — quy tắc tiền kiểm quyết định, không phải mô hình" "arch.timing_budget"
$PY - "$D" <<'PY'
import sys, pathlib
sys.path.insert(0, "src")
from eide.caps.arch import _ghi_module
from eide_core import store
_ghi_module(pathlib.Path(sys.argv[1]), [
    {"id": "mod_driver_i2c", "name": "i2c", "depends": [], "interfaces": [],
     "status": "proposed", "budget": {"period_ms": 10, "wcet_us": 1000}},
    {"id": "mod_app_main", "name": "app", "depends": [], "interfaces": [],
     "status": "proposed", "budget": {"period_ms": 20, "wcet_us": 1000}}])
store.write_seal(store.store_path(pathlib.Path(sys.argv[1])))   # đóng vai arch.decompose
PY
inv arch.timing_budget '{"module_ids":["mod_driver_i2c","mod_app_main"]}' > "$WS/tb.json"
grep -q '"utilization": 0.15' "$WS/tb.json"; kiem $? "U = 0,15 tính đúng"
grep -q '"schedulable": true' "$WS/tb.json"; kiem $? "so với cận Liu–Layland"

buoc "10. Cổng G-SRC — tải từ tên miền lạ phải VÀO HÀNG ĐỢI, không tự chạy" "search.fetch"
inv search.fetch '{"candidate":{"uri":"https://vi-du-khong-tin-cay.test/a.svd","kind":"svd","size_est":100}}' \
  > "$WS/fetch.json" 2>&1
grep -qi 'pending\|chờ\|ASK' "$WS/fetch.json"; kiem $? "G-SRC chặn nguồn ngoài danh sách trắng"
$PY -m eide.cli queue list -p "$D" 2>&1 | tee "$WS/queue.txt" | head -5
grep -q 'search.fetch' "$WS/queue.txt"; kiem $? "mục chờ hiện trong hàng đợi người dùng"

buoc "11. Sổ cái — chuỗi băm liên tục sau cả chuỗi trên" "ledger verify"
$PY - "$D" <<'PY'
import sys, pathlib
sys.path.insert(0, "src")
from eide_core.ledger import Ledger
led = Ledger(pathlib.Path(sys.argv[1]) / ".eide" / "store" / "ledger.jsonl")
ok, n = led.verify()
kinds = sorted({r["kind"] for r in led.records()})
print(f"   {len(led.records())} bản ghi, loại: {', '.join(kinds)}")
sys.exit(0 if ok else 1)
PY
kiem $? "ledger.verify() liên tục"

buoc "12. Niêm store — băm nội dung LOGIC, không băm byte" "store seal"
$PY - "$D" <<'PY'
import sys, pathlib
sys.path.insert(0, "src")
from eide_core import store
p = store.store_path(pathlib.Path(sys.argv[1]))
ok, ly_do = store.verify_seal(p)
print(f"   {ly_do or 'niêm khớp'}")
sys.exit(0 if ok else 1)
PY
kiem $? "verify_seal đạt"

# ---------------------------------------------------------------- B. năm chuỗi chuẩn

buoc "13. Chỗ đứt của năm chuỗi chuẩn (suy từ spec)" "scripts/kiem_chuoi_chuan.py"
$PY scripts/kiem_chuoi_chuan.py
kiem $? "báo cáo chạy"

# ---------------------------------------------------------------- kết

printf '\n\033[1m── Kết quả\033[0m\n'
if [ "$loi" = 0 ]; then
  printf '\033[32m   ✓ %s\033[0m\n' "tất cả các bước ĐẠT"
else
  printf '\033[31m   ✗ %s bước KHÔNG đạt\033[0m\n' "$loi"
fi
echo "   thư mục làm việc giữ lại để xem: $WS"
exit $((loi > 0))
