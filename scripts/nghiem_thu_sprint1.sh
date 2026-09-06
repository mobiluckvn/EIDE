#!/usr/bin/env bash
# Kịch bản nghiệm thu Sprint 1 — chạy trọn vòng trên một dự án MỚI TINH.
#
#   scripts/nghiem_thu_sprint1.sh [thư-mục-làm-việc]
#
# "Định nghĩa xong" của SPRINT-01 đòi chuỗi thật `project new` → `migrate` → `project.open`
# → `project list` chạy được, chứ không chỉ test xanh. Test dùng tmp_path và fixture; kịch
# bản này dùng CLI thật, dự án thật, ledger thật — nếu một mắt xích chỉ hoạt động trong
# pytest thì đây là chỗ lộ ra.
#
# Mỗi bước in lệnh trước khi chạy, để bản ghi màn hình dùng được làm phụ lục đề án.
# KHÔNG bật `pipefail`: nhiều bước ở đây cố ý làm `eide` trả mã khác 0 (E6003, E1000) rồi
# dùng `grep` xác nhận đúng mã lỗi ấy. Với `pipefail`, mã của `eide` sẽ nuốt mã của `grep` và
# một bước ĐẠT bị báo là hỏng — đúng lỗi đã dính lần chạy đầu.
set -u
cd "$(dirname "$0")/.."
PY="${PY:-./.venv-arm/bin/python}"
[ -x "$PY" ] || PY="./.venv-x86/bin/python"
[ -x "$PY" ] || PY="python3"
WS="${1:-${TMPDIR:-/tmp}/eide-nghiem-thu-$$}"
mkdir -p "$WS"

loi=0
buoc() { printf '\n\033[1m── %s\033[0m\n$ %s\n' "$1" "$2"; }
kiem() { if [ "$1" = 0 ]; then echo "   ✓ $2"; else echo "   ✗ $2"; loi=$((loi+1)); fi; }

buoc "1. Môi trường" "eide doctor"
$PY -m eide.cli doctor; kiem $? "doctor chạy"

buoc "2. Tạo dự án từ câu lệnh tiếng Việt" "eide project new \"máy đo nhiệt độ dùng STM32F411\""
ID=$($PY -m eide.cli project new "máy đo nhiệt độ dùng STM32F411" --dir "$WS" --chip STM32F411 2>/dev/null \
     | sed -n 's/.*"project_id": "\(.*\)",/\1/p')
D="$WS/$ID"
echo "   dự án: $ID"
# Chữ `đ` phải còn — DEV: slug là định danh, mất `đ` thì hai tên khác nhau va chạm
case "$ID" in *do-nhiet-do*) kiem 0 "slug giữ chữ đ ($ID)";; *) kiem 1 "slug MẤT chữ đ ($ID)";; esac

buoc "3. Mở khi CHƯA di trú → phải từ chối bằng E6003" "eide caps invoke project.open"
out=$($PY -m eide.cli caps invoke project.open "{\"project\":\"$D\"}" -p "$D" 2>&1)
case "$out" in *E6003*) kiem 0 "E6003 MIGRATION_REQUIRED";; *) kiem 1 "E6003 MIGRATION_REQUIRED";; esac

buoc "4. Di trú store" "eide migrate"
$PY -m eide.cli migrate -p "$D"; kiem $? "migrate"

buoc "5. Mở dự án → phiên mới" "eide caps invoke project.open"
$PY -m eide.cli caps invoke project.open "{\"project\":\"$D\"}" -p "$D" 2>/dev/null | tee /tmp/eide-open.$$ | head -14
grep -q '"session_id": "s_' /tmp/eide-open.$$; kiem $? "SessionMemory mở (MEM-11 §5)"

buoc "6. Ghi tùy chọn (D8) — và thử ghi một chuỗi giống khóa API" "eide caps invoke project.preferences"
$PY -m eide.cli caps invoke project.preferences \
   '{"op":"set","key":"probe","scope":"project","value":{"value":"stlink"}}' -p "$D" >/dev/null 2>&1
kiem $? "ghi tùy chọn hợp lệ"
out=$($PY -m eide.cli caps invoke project.preferences \
   '{"op":"set","key":"k","scope":"user","value":{"value":"AIzaSyD-gia-lam-khoa-0123456789abcd"}}' \
   -p "$D" 2>&1)
case "$out" in *E1000*) kiem 0 "chuỗi giống khóa API bị chặn (SEC-25 §3)";; *) kiem 1 "chuỗi giống khóa API bị chặn";; esac
case "$out" in *AIzaSyD-gia-lam-khoa*) kiem 1 "khóa KHÔNG được in lại trong thông báo lỗi";; *) kiem 0 "khóa không bị in lại";; esac

buoc "7. Cửa sổ hoàn tác" "eide caps invoke policy.undo_window"
$PY -m eide.cli caps invoke policy.undo_window '{}' -p "$D" 2>/dev/null | grep -q restore_config
kiem $? "việc vừa làm còn hoàn tác được (UXD U2)"

buoc "8. Sandbox: không mạng, không khóa" "eide caps invoke env.sandbox"
$PY -m eide.cli caps invoke env.sandbox \
  "{\"cmd\":[\"$PY\",\"-c\",\"import socket,os;\\nexec('try:\\\\n socket.create_connection((\\\\'8.8.8.8\\\\',53),timeout=4);print(\\\\'MO\\\\')\\\\nexcept Exception as e: print(\\\\'CHAN\\\\')');print('KEYS',[k for k in os.environ if 'KEY' in k])\"]}" \
  -p "$D" >/dev/null 2>&1
kiem $? "env.sandbox chạy"

buoc "9. Chính sách: 45 tình huống + dừng khẩn" "eide caps invoke policy.decide"
$PY -m eide.cli caps invoke policy.decide \
  '{"action":{"gate":"G-SRC","risk":"R1","features":{"source":{"domain":"bosch-sensortec.com","kind":"pdf_vendor","size_mb":4,"license":"vendor-doc","hash_match":true,"match_score":0.4}}}}' \
  -p "$D" 2>/dev/null | grep -q "G-SRC-06"
kiem $? "S06 ra ASK G-SRC-06 (DEV-011 đã sửa)"

buoc "10. Tiến độ và báo cáo" "eide caps invoke memory.progress / report.progress"
$PY -m eide.cli caps invoke memory.progress '{}' -p "$D" >/dev/null 2>&1; kiem $? "memory.progress"
$PY -m eide.cli caps invoke report.progress '{"period":"day"}' -p "$D" 2>/dev/null \
  | $PY -c "import json,sys; print(json.load(sys.stdin)['md'])"
kiem $? "report.progress"

buoc "11. Liệt kê dự án" "eide project list"
$PY -m eide.cli project list "$WS" 2>/dev/null | grep -q "$ID"; kiem $? "project list"

buoc "12. Chuỗi hash ledger còn nguyên" "verify"
$PY -c "
import sys; sys.path.insert(0,'src')
from eide_core.ledger import Ledger
from pathlib import Path
ok, seq = Ledger(Path('$D/.eide/store/ledger.jsonl')).verify()
print('   ledger:', 'liền mạch' if ok else f'ĐỨT ở seq {seq}')
sys.exit(0 if ok else 1)"
kiem $? "ledger chống sửa (SEC-25 §3)"

echo
if [ $loi -eq 0 ]; then echo "NGHIỆM THU SPRINT 1: ĐẠT — dự án tại $D"; else echo "NGHIỆM THU: $loi bước KHÔNG đạt"; fi
exit $loi
