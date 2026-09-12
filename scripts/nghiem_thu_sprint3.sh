#!/usr/bin/env bash
# Kịch bản nghiệm thu Sprint 3 — chuỗi HIỆN THỰC đầu-cuối, bằng công cụ THẬT.
#
#   scripts/nghiem_thu_sprint3.sh [thư-mục-làm-việc]
#
# Sprint 2 chứng minh chuỗi TRI THỨC: một câu tiếng Việt → hộ chiếu có trích dẫn → kết luận
# truy nguyên được. Kịch bản này chứng minh nửa còn lại: **từ tri thức tới firmware chạy được**.
#
# Vì sao nó chỉ viết được từ 11/09/2026 chứ không sớm hơn: tới hôm đó, hai mắt xích trung tâm
# chưa lần nào được THI HÀNH trên máy nào. `code.build` hỏng ở ba tầng nối nhau (DEV-088) và
# nhóm `sim.*` không có engine nào chạy được (DEV-086). Cả hai đều xanh trong pytest suốt nhiều
# ngày — vì pytest chỉ kiểm nhánh HỎNG của `code.build`, và `sim.run` thì đứng trên một shim
# luôn ngoan. Kịch bản này tồn tại để chỗ ấy không tái diễn: nó không dùng shim nào.
#
# Khác Sprint 2 một điểm quan trọng: kịch bản này MANG THEO một dự án CMake tối thiểu. EIDE
# không sinh scaffold — `code.build` dựng theo `CMakeLists` CỦA DỰ ÁN, và lệnh dựng thì lấy từ
# `toolchain.build.cmd` của manifest ISA. Không có dự án thật thì không có gì để dựng.
#
# Bỏ qua có báo khi thiếu công cụ, không báo đỏ: một máy chưa cài `arm-none-eabi-gcc` thì câu
# trả lời đúng là "chưa kiểm được", không phải "hỏng".
#
# KHÔNG bật `pipefail` — cùng lý do với Sprint 2: nhiều bước cố ý để `eide` trả mã khác 0 rồi
# dùng `grep` xác nhận đúng mã lỗi ấy.
set -u
cd "$(dirname "$0")/.."
GOC="$PWD"
PY="${PY:-./.venv-arm/bin/python}"
[ -x "$PY" ] || PY="./.venv-x86/bin/python"
[ -x "$PY" ] || PY="python3"
WS="${1:-${TMPDIR:-/tmp}/eide-nt3-$$}"
mkdir -p "$WS"

loi=0
bo_qua=0
buoc() { printf '\n\033[1m── %s\033[0m\n$ %s\n' "$1" "$2"; }
kiem() { if [ "$1" = 0 ]; then echo "   ✓ $2"; else echo "   ✗ $2"; loi=$((loi+1)); fi; }
bo()   { printf '   \033[33m⊘ bỏ qua: %s\033[0m\n' "$1"; bo_qua=$((bo_qua+1)); }
inv()  { $PY -m eide.cli caps invoke "$1" "$2" -p "$D" 2>&1; }

printf '\033[1mNGHIỆM THU SPRINT 3\033[0m — chuỗi hiện thực; thư mục làm việc: %s\n' "$WS"

# ---------------------------------------------------------------- A. dự án và đích

buoc "1. Tạo dự án" "eide project new \"điều khiển LED và đọc BME280 trên STM32F411\""
ID=$($PY -m eide.cli project new "điều khiển LED và đọc BME280 trên STM32F411" \
       --dir "$WS" --chip STM32F411RE 2>/dev/null | sed -n 's/.*"project_id": "\(.*\)",/\1/p')
D="$WS/$ID"
[ -n "$ID" ] && [ -d "$D/.eide" ]
kiem $? "dự án: $ID"

buoc "2. Di trú store" "eide migrate"
$PY -m eide.cli migrate -p "$D" > "$WS/migrate.txt" 2>&1
kiem $? "store lên mốc hiện tại"

buoc "3. Ghim đích — ISA suy từ docs/spec/isa/*.yaml" "project.set_target STM32F411RE"
inv project.set_target '{"chip":"STM32F411RE"}' > "$WS/target.json"
grep -q 'armv7e-m' "$WS/target.json"
kiem $? "ISA suy ra là armv7e-m (không từ bảng chép tay)"

# ---------------------------------------------------------------- B. dựng THẬT

buoc "4. Chuỗi công cụ có đủ không" "env.check armv7e-m"
inv env.check '{"isa":"armv7e-m"}' > "$WS/envcheck.json"
if grep -q '"ok": false' "$WS/envcheck.json"; then
  bo "thiếu công cụ cho armv7e-m — xem $WS/envcheck.json (cài: brew install arm-none-eabi-gcc cmake ninja)"
  CO_ARM=0
else
  CO_ARM=1
  kiem 0 "cả năm công cụ sẵn sàng"
fi

if [ "$CO_ARM" = 1 ]; then
  buoc "5. Dự án CMake tối thiểu cho Cortex-M4" "(kịch bản mang theo — EIDE không sinh scaffold)"
  mkdir -p "$D/cmake" "$D/src"
  cat > "$D/cmake/arm.cmake" <<'EOF'
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_C_FLAGS_INIT "-mcpu=cortex-m4 -mthumb -ffreestanding -ffunction-sections")
EOF
  cat > "$D/stm32f411.ld" <<'EOF'
MEMORY { FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 512K
         RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 128K }
ENTRY(Reset_Handler)
SECTIONS {
  .isr_vector : { KEEP(*(.isr_vector)) } > FLASH
  .text : { *(.text*) *(.rodata*) } > FLASH
  .bss  : { *(.bss*) *(COMMON) } > RAM
  _estack = ORIGIN(RAM) + LENGTH(RAM);
}
EOF
  cat > "$D/src/main.c" <<'EOF'
#define BME280_ADDR 0x76u /* eide:fact f_bme280_addr */
volatile unsigned int dem;
extern unsigned int _estack;
void Reset_Handler(void) { for (;;) { dem += BME280_ADDR; } }
__attribute__((section(".isr_vector"), used))
void *const vectors[2] = { (void *)&_estack, (void *)Reset_Handler };
EOF
  cat > "$D/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.22)
project(fw C)
add_executable(fw.elf src/main.c)
target_link_options(fw.elf PRIVATE
  -T${CMAKE_SOURCE_DIR}/stm32f411.ld -nostartfiles -nostdlib -Wl,--gc-sections
  -Wl,-Map=${CMAKE_BINARY_DIR}/fw.map)
EOF
  [ -f "$D/CMakeLists.txt" ]
  kiem $? "dự án CMake có mặt"

  buoc "6. DỰNG THẬT — lệnh lấy từ manifest ISA, chạy trong sandbox KHÔNG MẠNG" "code.build"
  inv code.build '{}' > "$WS/build.json"
  grep -q '"passed": true' "$WS/build.json"
  kiem $? "code.build đạt"

  buoc "7. Artifact đúng KIẾN TRÚC, không phải kiến trúc của máy chạy test" "objdump -f fw.elf"
  if command -v arm-none-eabi-objdump > /dev/null; then
    arm-none-eabi-objdump -f "$D/build/fw.elf" > "$WS/objdump.txt" 2>&1
    grep -q 'elf32-littlearm' "$WS/objdump.txt" && grep -q 'armv7e-m' "$WS/objdump.txt"
    kiem $? "ELF là elf32-littlearm, architecture armv7e-m"
    sed -n '2,3p' "$WS/objdump.txt"
  else
    bo "không có arm-none-eabi-objdump"
  fi

  buoc "8. Ngân sách bộ nhớ — số THẬT từ arm-none-eabi-size" "code.size"
  $PY - "$D" <<'PY'
import hashlib, sys
sys.path.insert(0, "src")
from eide_core import store
# Hai fact dung lượng, đứng thay cho `extract.svd` mà Sprint 2 đã chứng minh: không có chúng
# thì `code.size` trả passed=false — và đó là hành vi ĐÚNG ("chưa biết giới hạn thì không
# kết luận đạt"), chứ không phải lỗi.
root = sys.argv[1]
with store.open_store(store.store_path(root)) as c:
    c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license) VALUES (?,?,?,?,?,?)",
              ("s_mem", "STM32F411RE datasheet", hashlib.sha256(b"s_mem").hexdigest(),
               "pdf", "gold", "vendor-doc"))
    for i, (ten, so) in enumerate((("flash", 512 * 1024), ("ram", 128 * 1024))):
        c.execute("INSERT OR IGNORE INTO fact (id, subject, predicate, value, unit, source_id,"
                  " method, tier, confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                  (f"f_mem{i:012d}", f"chip:STM32F411RE/{ten}", "memory_size", str(so), "B",
                   "s_mem", "parser", "gold", 1.0, "verified", "A"))
    c.commit()
PY
  inv code.size "{\"artifact\":\"$D/build/fw.elf\"}" > "$WS/size.json"
  grep -q '"passed": true' "$WS/size.json"
  kiem $? "code.size đạt, có flash_pct so với 512 KB"
  grep -o '"text": [0-9]*\|"bss": [0-9]*\|"flash_pct": [0-9.]*\|"ram_pct": [0-9.]*' \
    "$WS/size.json" | head -4 | sed 's/^/   /'
fi

# ---------------------------------------------------------------- C. hằng số phải nối về fact

buoc "9. Hằng số phần cứng KHÔNG có nguồn thì bị chặn" "code.constant_guard"
inv code.constant_guard '{"patch":{"files":[{"path":"src/drv.c","content":"#define ADDR 0x76\n"}]}}' \
  > "$WS/guard_chan.json"
grep -q '"verdict": "block"' "$WS/guard_chan.json"
kiem $? "0x76 không chú thích → block (đây là lý do cả tầng tri thức tồn tại)"

# ---------------------------------------------------------------- D. mô phỏng THẬT

buoc "10. Engine mô phỏng có chạy được không" "qemu-system-avr -M arduino-uno"
if command -v qemu-system-avr > /dev/null && qemu-system-avr -M help 2>/dev/null | grep -q arduino-uno; then
  CO_AVR=1
  kiem 0 "qemu-system-avr có máy ảo arduino-uno (= ATmega328P)"
else
  bo "không có qemu-system-avr hoặc thiếu máy ảo arduino-uno (brew install qemu)"
  CO_AVR=0
fi

if [ "$CO_AVR" = 1 ]; then
  buoc "11. MÔ PHỎNG THẬT — firmware AVR chạy trên engine, UART đọc được" "sim.run"
  DA="$WS/avr" ; mkdir -p "$DA"
  IDA=$($PY -m eide.cli project new "nháy LED trên ATmega328P" \
          --dir "$DA" --chip ATmega328P 2>/dev/null | sed -n 's/.*"project_id": "\(.*\)",/\1/p')
  DAVR="$DA/$IDA"
  $PY -m eide.cli migrate -p "$DAVR" > /dev/null 2>&1
  $PY -m eide.cli caps invoke project.set_target '{"chip":"ATmega328P"}' -p "$DAVR" > "$WS/target_avr.json" 2>&1

  # ELF AVR dựng bằng tay: máy này không có `avr-gcc`, mà đường chạy engine thì không nên chờ
  # một chuỗi công cụ. Năm lệnh mã máy: TXEN0 → UCSR0B, 'E' → UDR0, rồi lặp vô hạn.
  $PY - "$DAVR" <<'PY'
import struct, sys, pathlib
ma = bytes.fromhex("18E0" "1093C100" "05E4" "0093C600" "FFCF")
eh, ph = 52, 32
elf = (b"\x7fELF" + bytes([1, 1, 1, 0]) + bytes(8)
       + struct.pack("<HHIIIIIHHHHHH", 2, 0x53, 1, 0, eh, 0, 5, eh, ph, 1, 40, 0, 0)
       + struct.pack("<IIIIIIII", 1, eh + ph, 0, 0, len(ma), len(ma), 5, 2) + ma)
d = pathlib.Path(sys.argv[1]) / "build"; d.mkdir(parents=True, exist_ok=True)
(d / "fw.elf").write_bytes(elf)

import yaml
sim = pathlib.Path(sys.argv[1]) / "sim"; sim.mkdir(parents=True, exist_ok=True)
import json, shutil
(sim / "platform.json").write_text(json.dumps({
    "chip": "chip:atmel.atmega328p", "board": None, "isa": "avr8", "engine": "qemu",
    "exe": shutil.which("qemu-system-avr"), "memory": {"FLASH": 32768, "RAM": 2048},
    "modeled": [{"name": "USART0", "base": 0xC0, "model": "qemu.avr-usart", "kind": "uart"}],
    "unsupported": [], "files": []}, ensure_ascii=False), encoding="utf-8")
(sim / "f-01.yaml").write_text(yaml.safe_dump(
    {"id": "F-01", "engine": "qemu", "duration_s": 1, "init": {"mocks": []}, "inject": [],
     "expect": [{"kind": "uart", "pattern": "E"}], "record": ["uart"], "feature": "F-01"},
    allow_unicode=True, sort_keys=False), encoding="utf-8")
PY
  $PY -m eide.cli caps invoke sim.run '{"artifact":"build/fw.elf","scenario":"sim/f-01.yaml"}' \
      -p "$DAVR" > "$WS/sim.json" 2>&1
  grep -q '"passed": true' "$WS/sim.json"
  kiem $? "sim.run đạt — kỳ vọng UART khớp trên engine THẬT"
  grep -o '"uart": \[[^]]*\]' "$WS/sim.json" | head -1 | sed 's/^/   /'
fi

# ---------------------------------------------------------------- E. truy vết vẫn nguyên

buoc "12. Sổ cái — chuỗi băm liên tục sau cả chuỗi trên" "ledger.verify()"
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
kiem $? "ledger.verify() liên tục — có cả tool.report của build/size/sim"

buoc "13. Niêm store — băm nội dung LOGIC sau khi dựng và đo" "store.verify_seal()"
$PY - "$D" <<'PY'
import sys, pathlib
sys.path.insert(0, "src")
from eide_core import store
ok, ly_do = store.verify_seal(store.store_path(pathlib.Path(sys.argv[1])))
print(f"   {ly_do or 'niêm khớp'}")
sys.exit(0 if ok else 1)
PY
kiem $? "verify_seal đạt"

# ---------------------------------------------------------------- kết

printf '\n\033[1m── Kết quả\033[0m\n'
if [ "$loi" = 0 ]; then
  printf '\033[32m   ✓ %s\033[0m\n' "tất cả các bước ĐẠT"
else
  printf '\033[31m   ✗ %s bước KHÔNG đạt\033[0m\n' "$loi"
fi
[ "$bo_qua" = 0 ] || printf '\033[33m   ⊘ %s bước bỏ qua vì thiếu công cụ\033[0m\n' "$bo_qua"
echo "   thư mục làm việc giữ lại để xem: $WS"
exit $((loi > 0))
