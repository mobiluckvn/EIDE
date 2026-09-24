const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');

// ================= TGT-19 =================
{
const m = metaNew('EIDE-TGT-19', 'ISA, toolchain, adapter, discovery', 'ISA PROFILE, TOOLCHAIN, ADAPTER TARGET VÀ DISCOVERY (TGT)',
  'Đặc tả từng tập lệnh được hỗ trợ: schema ISA profile, manifest toolchain theo hệ điều hành, lệnh build/flash/serial/probe/sim, bảng VID/PID probe, cách đọc ID chip theo họ, thuật toán dò tốc độ kết nối, schema target.yaml, nguồn tài liệu hãng',
  [['Tài liệu trước', 'EIDE-SDD-04 §4.5, §4.8, §6; EIDE-CDS-12 tập 3–4 (env.*, target.*, discover.*); EIDE-SEC-25'], ['Tệp kèm', 'isa/armv7-m.yaml, isa/armv7e-m.yaml, isa/avr8.yaml, isa/rv32imac.yaml, isa/xtensa-esp32.yaml, isa/pic16.yaml (mẫu)'], ['Dùng khi', 'Hiện thực core.targets, eide.discover, eide-packs/isa; thêm ISA mới (NFR-08)']],
  'Phát hành lần đầu — bổ sung lĩnh vực L20/L21/L23',
  [['1.1', '07/09/2026', 'Vũ Trí Công',
    '§2 bảng ISA: rv32imac và xtensa-esp32 chuyển M2 → M5 kèm lý do — cả hai cần chuỗi công cụ và trình mô phỏng chưa cài được, nên "kiểm" ở M2 mà không có board lẫn toolchain chỉ là nạp YAML. Ghi gói ba việc của M5: schema manifest ISA, TC-48 ("ISA là dữ liệu, không phải mã"), manifest xtensa-esp32 và pic16. Nêu rõ avr8 ở mốc M0 đã có manifest từ Sprint 1 nhưng chưa test nào chạm tới. §8: bảng nguồn hãng sinh ra `sources/vendors.yaml` kèm giấy phép từng mục, để `search.vendor` đọc từ spec thay vì chép tay (DEV-055).'],
   ['1.2', '11/09/2026', 'Vũ Trí Công',
    '`isa/avr8.yaml` khối `sim` thêm `fallback: qemu`, cùng khuôn với `armv7e-m.yaml` vốn đã có từ đầu; §2 bảng ISA ghi đường lui ấy vào cột Sim. Lý do (DEV-086, chủ sản phẩm duyệt 11/09/2026): **không engine mô phỏng nào trong bộ hồ sơ chạy được trên máy phát triển** — `simavr` không có công thức brew, Renode không có cask, và `qemu-system-arm` tuy có nhưng không mang máy ảo nào cho họ STM32F4 (gần nhất là `netduinoplus2`, vốn là STM32F405). Trong khi đó `qemu-system-avr` có sẵn và mang đúng `arduino-uno` = ATmega328P, khớp `family_patterns: ["^ATmega", …]`. Không khai `fallback` thì EIDE không được phép dùng nó, nên cả nhóm `sim.*` hiện thực xong mà đường chạy engine THẬT chưa lần nào được thi hành. Tài liệu không giải thích được vì sao hai manifest khác nhau ở điểm này, nên đây là chỗ tài liệu thiếu chứ không phải hiện thực sai.'],
   ['1.3', '13/09/2026', 'Vũ Trí Công',
    '§1 schema và cả hai manifest thêm trường **`package`** cho `toolchain.compiler` và từng mục `toolchain.tools[]`: tên GÓI theo từng hệ điều hành, khai khi nó KHÁC tên chương trình (DEV-089, chủ sản phẩm duyệt 13/09/2026). Tới nay `env.install` dùng `tool` làm luôn tên gói, mà hai thứ ấy không phải một: `arm-none-eabi-size` và `arm-none-eabi-objcopy` là hai CHƯƠNG TRÌNH đến từ MỘT gói `arm-none-eabi-binutils` (brew) hay `binutils-arm-none-eabi` (apt) — `brew install arm-none-eabi-size` không tồn tại. Cùng chuyện với `avr-size` (đến từ `avr-gcc`). Hệ quả trước khi sửa: `env.install` cho ba công cụ ấy chắc chắn hỏng, và hỏng bằng một thông báo của trình quản lý gói chứ không bằng một câu EIDE giải thích được. Một danh sách phẳng dùng chung cho brew/apt/winget giả định ba hệ sinh thái đặt tên giống nhau — điều không đúng với bất kỳ gói nào có tiền tố.'],
   ['1.4', '22/09/2026', 'Vũ Trí Công',
    '`isa/avr8.yaml` mục `toolchain.install.macos` sửa thành `brew tap osx-cross/avr && brew trust osx-cross/avr && brew install avr-gcc@14 avrdude` (DEV-172). Ba chỗ hỏng trong MỘT dòng cũ: (1) tap `osx-cross/avr` nay chỉ còn formula ĐÁNH SỐ (`avr-gcc@8`…`@15`), nên `brew install avr-gcc` trả "No available formula"; (2) Homebrew từ chối nạp formula của tap bên thứ ba cho tới khi `brew trust`; (3) `avr-gcc@14` là **keg-only** — Homebrew cố ý không nối nó vào `bin/`, nên cài xong mà `which avr-gcc` vẫn không thấy. Riêng (3) không sửa được bằng tài liệu: `eide_core.tools.which()` nay tìm thêm trong `/opt/homebrew/opt/*/bin` và `/usr/local/opt/*/bin`, ưu tiên bản có số phiên bản cao nhất, PATH vẫn luôn thắng. Lời khuyên sửa `~/.zshrc` của Homebrew KHÔNG cứu được daemon: nó chạy với PATH của tiến trình cha. §4 `env.check`/`env.install` vì thế đọc đúng chuỗi công cụ đã cài, thay vì báo `E4001 TOOL_MISSING` cho một trình dịch vừa cài xong.']]);
const c = [];
c.push(H1('1. Schema ISA profile'));
c.push(...CODE([
  '# isa/<id>.yaml — JSON Schema data/json/yaml_isa.json',
  'id: armv7e-m                       # armv6-m | armv7-m | armv7e-m | armv8-m | avr8 | rv32imac | rv32imc | xtensa-esp32 | pic16 | pic18 | custom-<name>',
  'family_patterns: ["^STM32F[34]", "^STM32L4", "^nRF52", "^SAMD5", "^LPC55"]     # regex mã chip → ISA (project.set_target)',
  'abi: {endian: little, word: 32, fpu: optional, align: 8}',
  'interrupts: {model: nvic, vector_table: "0x00000000", priority_bits: 4}',
  'toolchain:',
  '  compiler: {name: arm-none-eabi-gcc, min: "13.2", check: "arm-none-eabi-gcc --version", version_regex: "\\\\b(\\\\d+\\\\.\\\\d+)"}',
  '  tools: [{name: cmake, min: "3.22"}, {name: ninja}, {name: arm-none-eabi-size, package: {macos: arm-none-eabi-binutils, linux: binutils-arm-none-eabi}}]   # `package` khi tên CHƯƠNG TRÌNH khác tên GÓI',
  '  install: {macos: ["brew install --cask gcc-arm-embedded", "brew install cmake ninja"], linux: ["apt install gcc-arm-none-eabi cmake ninja-build"], windows: ["winget install Arm.GnuArmEmbeddedToolchain", "winget install Kitware.CMake"]}',
  '  build: {cmd: "cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/arm.cmake && cmake --build build", artifact: "build/*.elf", map: "build/*.map", size: "arm-none-eabi-size -A {elf}"}',
  '  static: {cmd: "cppcheck --enable=warning,performance --inline-suppr src", rules: ["no_delay_in_isr", "no_malloc", "no_float_isr_without_fpu"]}',
  '  host_test: {cmd: "ctest --test-dir build-host", framework: unity}',
  'flash: {adapters: [probe-rs, openocd], default: probe-rs, cmd: {probe-rs: "probe-rs download --chip {chip} --probe {probe} {elf}", openocd: "openocd -f interface/{probe_cfg} -f target/{target_cfg} -c \\"program {elf} verify reset exit\\""}, verify: true}',
  'debug: {adapter: embedded-debugger-mcp, probes: [stlink, jlink, cmsis-dap], speed_khz: {min: 100, max: 8000, default: 4000, limit_fact_predicate: "swd_max_khz"}}',
  'id_read: {method: idcode, cmd: "probe-rs info --probe {probe}", regex: "IDCODE: (0x[0-9A-Fa-f]+)", secondary: {reg: "0xE0042000", name: DBGMCU_IDCODE, mask: "0xFFF"}, table: "id_tables/stm32.yaml"}',
  'serial: {default_baud: 115200, auto_baud_list: [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]}',
  'sim: {engine: renode, platform_template: "renode/cortex-m.repl.j2", fallback: qemu}',
  'skills: [skills/armv7e-m/interrupts.md, skills/armv7e-m/clock.md, skills/armv7e-m/i2c.md, skills/armv7e-m/dma.md]',
  'bench: bench/armv7e-m/tasks.yaml',
]));
c.push(SP());
c.push(H1('2. Bảng ISA khởi đầu'));
c.push(T([1300, 1700, 1500, 1500, 1500, 1800], ['ISA', 'Chip mẫu', 'Toolchain', 'Flash', 'Probe / ID', 'Sim'], [
  ['armv7e-m (M0)', 'STM32F411, nRF52840, LPC55', 'arm-none-eabi-gcc 13.2, cmake/ninja', 'probe-rs / OpenOCD', 'ST-Link, J-Link, CMSIS-DAP / IDCODE + DBGMCU', 'Renode (.repl), fallback QEMU'],
  ['armv7-m', 'STM32F103 (Blue Pill), STM32F205, LPC1768', 'arm-none-eabi-gcc 13.2, cmake/ninja', 'probe-rs / OpenOCD', 'ST-Link, J-Link, CMSIS-DAP / IDCODE + DBGMCU', 'QEMU (netduino2, stm32vldiscovery), Renode'],
  ['armv6-m', 'RP2040, STM32F0, SAMD21', 'như trên', 'probe-rs / picotool (RP2040 UF2)', 'CMSIS-DAP, picoprobe / IDCODE', 'Renode'],
  ['avr8 (M0)', 'ATmega328P, ATtiny1616', 'avr-gcc ≥7.3 (ATmega) / ≥8 cho ATtiny UPDI, avrdude 7', 'avrdude (arduino, usbasp, jtag2updi, pymcuprog UPDI)', 'AVRISP mkII, Arduino bootloader / signature bytes', 'simavr [52], fallback QEMU (qemu-system-avr)'],
  ['rv32imac', 'GD32VF103, ESP32-C3 (rv32imc), CH32V', 'riscv64-elf-gcc 13+ (multilib) hoặc riscv-none-elf-gcc', 'OpenOCD / esptool (ESP)', 'FTDI JTAG, ESP USB-JTAG / DTM IDCODE, esptool chip_id', 'QEMU riscv32 (-M virt) [53]'],
  ['xtensa-esp32 (M5)', 'ESP32, ESP32-S3', 'ESP-IDF 5.x (idf.py)', 'esptool / idf.py flash', 'ESP USB-JTAG / esptool chip_id', 'QEMU xtensa (esp32)'],
  ['pic16/pic18 (M5)', 'PIC16F18855', 'XC8 (đóng, guide_install)', 'pymcuprog (UPDI không), MPLAB IPECMD', 'PICkit 4/5 / Device ID', 'MPLAB sim (không tự động hóa)'],
]));
c.push(SP());
c.push(P('**rv32imac và xtensa-esp32 chuyển từ M2 sang M5** (quyết định 07/09/2026). Cả hai cần chuỗi công cụ và trình mô phỏng chưa cài được trong môi trường phát triển hiện tại (`riscv-none-elf-gcc`, ESP-IDF, QEMU riscv32/xtensa), nên “kiểm” chúng ở M2 mà không có board lẫn toolchain sẽ chỉ là nạp YAML — đúng việc mà schema manifest cộng TC-48 làm được rẻ hơn nhiều. Ở M5 làm một gói: (1) `docs/spec/isa/isa.schema.json` cùng test nạp MỌI tệp trong `docs/spec/isa/` qua schema — `avr8` (mốc M0, manifest đã có từ Sprint 1 nhưng chưa test nào chạm tới) tự có test từ đó; (2) TC-48 thả `rv32imac.yaml` vào rồi khẳng định `env.check` hiểu nó mà KHÔNG sửa dòng mã nào trong `src/`, tức chứng minh “ISA là dữ liệu, không phải mã”; (3) manifest `xtensa-esp32` và `pic16`. PIC giữ nguyên M5 vì lý do hệ sinh thái đã ghi ở bảng trên, không phải vì chưa làm: XC8 là trình dịch đóng và MPLAB sim không tự động hóa được, nên PIC không chạy được vòng “mô phỏng trước phần cứng” mà `defaults.sim_first` đòi. Xem DEVIATIONS DEV-055.'));
c.push(SP());
c.push(H1('3. Manifest toolchain và kiểm/cài'));
c.push(P('env.check chạy `check` của từng tool trong sandbox, so `min` theo semver, ghi `hash` của nhị phân khi có; env.install chọn lệnh theo OS và trình quản lý gói có sẵn (thứ tự: brew → pipx → winget/apt → tải chính hãng có băm), luôn không sudo trước; gói phải thuộc `trusted_packages` (POL-17) — danh sách mặc định: gcc-arm-none-eabi, avr-gcc, avrdude, riscv-none-elf-gcc, esp-idf, cmake, ninja, probe-rs, openocd, esptool, pymcuprog, picotool, renode, simavr, qemu, cppcheck, clang-tidy, mermaid-cli, plantuml, graphviz, d2, wavedrom-cli, sigrok-cli, docling. `tools.lock` ghi {tool, version, path, sha256?, installed_by, at}; env.lock phát hiện trôi phiên bản và đề nghị khóa lại.'));
// Bảng §4 là NGUỒN của cả hai: bảng in trong tài liệu và `isa/probes.yaml` mà
// `discover.ports` đọc. Một mảng, hai đầu ra — không có bản chép tay thứ hai để trôi đi
// (bài học DEV-043/DEV-046, và cùng khuôn với `sources/vendors.yaml` ở §8).
const PROBES = [
  { id: 'stlink-v2', ten: 'ST-Link V2', vid: '0483', pids: ['3748'],
    kind: 'swd', tools: ['probe-rs', 'openocd'],
    driver: 'macOS: không cần; Linux: udev 60-openocd; Windows: ST driver' },
  { id: 'stlink-v2-1', ten: 'ST-Link V2-1 / V3', vid: '0483',
    pids: ['374B', '374E', '374F', '3753'], kind: 'swd+vcp',
    tools: ['probe-rs', 'openocd'], driver: 'VCP xuất hiện như tty.usbmodem' },
  { id: 'jlink', ten: 'J-Link', vid: '1366', pids: ['0101', '0105', '1015'],
    kind: 'swd/jtag', tools: ['probe-rs', 'openocd'],
    driver: 'Driver SEGGER trên Windows' },
  { id: 'cmsis-dap', ten: 'CMSIS-DAP (DAPLink, picoprobe)', vid: '0D28', pids: ['0204'],
    vid2: '2E8A', pids2: ['000C'], kind: 'swd', tools: ['probe-rs'],
    driver: 'HID/bulk; không driver' },
  { id: 'esp-usb-jtag', ten: 'ESP USB-JTAG (ESP32-C3/S3)', vid: '303A', pids: ['1001'],
    kind: 'jtag+serial', tools: ['esptool', 'openocd'], driver: 'Linux udev' },
  { id: 'cp210x', ten: 'CP210x', vid: '10C4', pids: ['EA60'], kind: 'serial',
    tools: [], driver: '—' },
  { id: 'ch340', ten: 'CH340', vid: '1A86', pids: ['7523'], kind: 'serial',
    tools: [], driver: 'Driver CH340 macOS cũ' },
  { id: 'ftdi', ten: 'FTDI', vid: '0403', pids: ['6001'], kind: 'serial',
    tools: [], driver: '—' },
  { id: 'avrisp2', ten: 'AVRISP mkII', vid: '03EB', pids: ['2104'], kind: 'isp',
    tools: ['avrdude'], driver: 'libusb' },
  { id: 'arduino-uno', ten: 'Arduino Uno (16U2)', vid: '2341', pids: ['0043'],
    kind: 'serial+bootloader', tools: ['avrdude'], driver: '—' },
  { id: 'pickit4', ten: 'PICkit 4', vid: '04D8', pids: ['9012'], kind: 'icsp',
    tools: ['ipecmd'], driver: 'MPLAB' },
];

c.push(H1('4. Bảng VID/PID probe và cổng'));
c.push(T([1800, 1800, 2700, 3000], ['Thiết bị', 'VID:PID', 'Loại / công cụ', 'Ghi chú driver'],
  PROBES.map(p => [
    p.ten,
    p.vid + ':' + p.pids.join(', ') + (p.vid2 ? ', ' + p.vid2 + ':' + p.pids2.join(', ') : ''),
    p.kind + (p.tools.length ? ', ' + p.tools.join('/') : ''),
    p.driver,
  ])));
c.push(SP());
c.push(H1('5. Đọc ID chip theo họ'));
c.push(T([1600, 3400, 4300], ['Họ', 'Lệnh / thanh ghi', 'Đối chiếu'], [
  ['STM32', 'probe-rs info → DP IDCODE; đọc DBGMCU_IDCODE 0xE0042000 (F4) / 0x40015800 (F0/L0) → DEV_ID[11:0], REV_ID', 'id_tables/stm32.yaml: 0x431 → F411, 0x413 → F405/407…; rev → errata áp dụng (K2′)'],
  ['nRF52', 'FICR.INFO.PART 0x10000100, VARIANT 0x10000104', 'id_tables/nordic.yaml'], ['RP2040', 'picotool info; ROM ID', '—'],
  ['AVR', 'avrdude -c <prog> -p <part> -v → signature 0x1E 0x95 0x0F', 'id_tables/avr.yaml: 1E950F → ATmega328P'],
  ['ESP32', 'esptool --port … chip_id → chip type, revision, MAC', 'id_tables/esp.yaml'], ['RISC-V (GD32V)', 'OpenOCD dtmcs/idcode; JEDEC', 'id_tables/riscv.yaml'], ['PIC', 'ipecmd -P<part> -I (Device ID)', 'id_tables/pic.yaml'],
]));
c.push(SP());
c.push(P('ID không khớp hộ chiếu ghim → E4003, leo thang, không nạp (POL-17). ID khớp họ nhưng khác part → đề xuất project.set_target sang part đúng.'));
c.push(H1('6. Thuật toán dò tốc độ kết nối'));
c.push(...CODE([
  'def link_speed(kind, target, limit):                      # limit = fact có nguồn (swd_max_khz, uart_max_baud, i2c_max_khz) hoặc mặc định ISA',
  '    ladder = LADDER[kind]                                   # baud: [9600…921600]; swd/jtag: [100,500,1000,2000,4000,8000] kHz; spi: [1,2,4,8,16] MHz; i2c: [100,400,1000] kHz',
  '    best = None; tried = []',
  '    for s in ladder:',
  '        if s > limit: policy_ask("speed_over_limit", s, limit); break          # nấc vượt fact → ASK',
  '        err = probe(kind, target, s, frames=1000)          # baud: echo firmware kiểm định hoặc banner lặp; swd: đọc IDCODE ×1000; spi/i2c: đọc ID ngoại vi ×1000',
  '        tried.append((s, err))',
  '        if err == 0: best = s',
  '        elif err > 0.01: break                             # > 1% lỗi → dừng leo',
  '    chosen = best or ladder[0]; write_target_yaml(kind, chosen); return LinkSpeed(kind, chosen, tried, limit)',
]));
c.push(SP());
c.push(P('Baud thử qua firmware kiểm định (BEN-21 §2, chế độ echo) hoặc, khi board chạy firmware khác, qua banner lặp lại (discover.firmware_probe); mỗi nấc ≤ 3 s; tổng ≤ 25 s. SWD: probe-rs `--speed`; lỗi = số lần IDCODE sai/1.000. Kết quả ghi Discovery.link_speed và `target.yaml.speeds`.'));
c.push(H1('7. Schema target.yaml'));
c.push(...CODE([
  '{ "type": "object", "required": ["board", "isa", "adapter"], "properties": {',
  '  "board": {"type": "string"}, "isa": {"type": "string"}, "chip": {"type": "string"},',
  '  "adapter": {"type": "object", "required": ["kind"], "properties": {"kind": {"type": "string", "enum": ["probe-rs","openocd","avrdude","esptool","pymcuprog","picotool","ipecmd"]}, "probe": {"type": "string"}, "cfg": {"type": "string"}, "chip": {"type": "string"}}},',
  '  "port": {"type": "object", "properties": {"dev": {"type": "string"}, "baud": {"type": "integer"}}},',
  '  "speeds": {"type": "object", "properties": {"swd_khz": {"type": "integer"}, "jtag_khz": {"type": "integer"}, "spi_mhz": {"type": "number"}, "i2c_khz": {"type": "integer"}}},',
  '  "lab": {"type": "boolean"}, "has_actuator": {"type": "boolean"}, "last_discovery": {"type": "string"} }, "additionalProperties": false }',
]));
c.push(SP());
c.push(H1('8. Nguồn tài liệu hãng (search.vendor)'));
c.push(T([1600, 3800, 3900], ['Hãng / tiền tố', 'Mẫu URL', 'Loại và tầng'], [
  ['ST (STM32*)', 'github.com/cmsis-svd/cmsis-svd-data (SVD); st.com/resource/en/datasheet/<part>.pdf; st.com/resource/en/reference_manual/rm0383-*.pdf; errata es0287', 'SVD vàng; PDF chính hãng bạc'],
  ['Microchip (AT*, PIC*)', 'packs.download.microchip.com/<Family>_DFP (ATDF, EDC); ww1.microchip.com/downloads/…/DataSheet.pdf', 'ATDF/EDC vàng; PDF bạc'],
  ['Nordic (nRF*)', 'github.com/NordicSemiconductor/nrfx (SVD); docs.nordicsemi.com; docs MCP', 'SVD vàng; docs MCP bạc'],
  ['Espressif (ESP*)', 'github.com/espressif/svd; docs.espressif.com; ESP-IDF Docs MCP', 'SVD vàng; docs MCP bạc'],
  ['Raspberry Pi (RP2040)', 'datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf; pico-sdk SVD', 'SVD vàng; PDF bạc'],
  ['Bosch, InvenSense, Allegro… (cảm biến/driver)', 'bosch-sensortec.com/…/bst-bme280-ds002.pdf; invensense.tdk.com; allegromicro.com/…/a4988-datasheet.pdf', 'PDF chính hãng bạc (bảng thanh ghi cần duyệt/ngưỡng)'],
  ['Cộng đồng', 'cmsis-svd-data *-Community, GitHub repo, forum', 'SVD community bạc; forum đồng (chỉ ứng viên)'],
]));
c.push(SP());
c.push(H1('9. Kiểm thử'));
c.push(T([1000, 3400, 3700, 1200], ['TC', 'Mục tiêu', 'Kỳ vọng', 'Mức'], [
  ['TC-TG-01', 'ISA yaml hợp lệ', '5 profile nạp qua schema; thêm rv32 không sửa core (TC-48)', 'L1'],
  ['TC-TG-02', 'env.check/install theo OS', 'Máy sạch macOS/Linux/Windows → armv7e-m toolchain sẵn sàng không sudo; gói lạ → ASK', 'L2'],
  ['TC-TG-03', 'VID/PID và ID chip', 'Nucleo, Uno, ESP32-C3 cắm → kind đúng; ID khớp bảng; chip lạ → E4003', 'L3'],
  ['TC-TG-04', 'link_speed', 'Baud 921600 với 0 lỗi; SWD dừng ở nấc lỗi; nấc vượt fact → ASK', 'L3'],
  ['TC-TG-05', 'Flash theo 3 adapter', 'probe-rs (Nucleo), avrdude (Uno), esptool (C3) verify đạt; artifact sai băm → REJECT', 'L3'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-TGT-19_ISA_toolchain_adapter_discovery.docx');
// Bảng §8 sinh ra bản máy đọc được cho `search.vendor`. Cùng một nguồn với bảng in trong
// tài liệu, nên không có bản chép tay thứ hai để trôi (bài học DEV-043/DEV-046).
// Bảng §4 → bản máy đọc được cho `discover.ports`/`discover.probe`. Mỗi mục một dòng
// `vid:pid` đã tách sẵn, vì phía Python so khớp từng cặp chứ không phân tích lại chuỗi in.
fs.mkdirSync('isa', { recursive: true });
fs.writeFileSync('isa/probes.yaml',
  '# Sinh từ EIDE-TGT-19 §4 "Bảng VID/PID probe và cổng". KHÔNG sửa tay.\n'
  + '# Nguồn: docs/ho-so/nguon/tgt_sim.js (mảng PROBES) — sinh lại bằng `node tgt_sim.js`.\n'
  + 'probes:\n'
  + PROBES.map(p => {
      const cap = p.pids.map(x => p.vid + ':' + x)
        .concat(p.vid2 ? p.pids2.map(x => p.vid2 + ':' + x) : []);
      return '  - id: ' + p.id + '\n'
        + '    name: "' + p.ten + '"\n'
        + '    usb: [' + cap.map(x => '"' + x + '"').join(', ') + ']\n'
        + '    kind: ' + p.kind + '\n'
        + '    tools: [' + p.tools.join(', ') + ']\n'
        + '    driver_note: "' + p.driver + '"\n';
    }).join(''));

fs.mkdirSync('sources', { recursive: true });
fs.writeFileSync('sources/vendors.yaml', `# Sinh từ EIDE-TGT-19 §8 "Nguồn tài liệu hãng (search.vendor)". KHÔNG sửa tay.
vendors:
  - id: st
    name: STMicroelectronics
    prefixes: ["^STM32", "^STM8", "^LSM", "^L3G"]
    domains: [st.com, github.com/cmsis-svd, raw.githubusercontent.com]
    urls:
      - {kind: svd, tier: gold, license: Apache-2.0, template: "https://raw.githubusercontent.com/cmsis-svd/cmsis-svd-data/main/data/STMicro/{part_base}.svd", note: "SVD theo DIE, không theo mã vỏ: STM32F411CE và STM32F411RE dùng chung STM32F411.svd"}
      - {kind: pdf, tier: silver, license: vendor-doc, template: "https://www.st.com/resource/en/datasheet/{part_lower}.pdf"}
      - {kind: pdf, tier: silver, license: vendor-doc, template: "https://www.st.com/resource/en/reference_manual/rm0383-{part_lower}.pdf", note: "reference manual"}
  - id: microchip
    name: Microchip
    prefixes: ["^AT", "^PIC", "^SAM", "^dsPIC"]
    domains: [microchip.com, packs.download.microchip.com, ww1.microchip.com]
    urls:
      - {kind: atdf, tier: gold, license: Apache-2.0, template: "https://packs.download.microchip.com/Microchip.{family}_DFP.atpack", note: "ATDF/EDC trong gói DFP"}
      - {kind: pdf, tier: silver, license: vendor-doc, template: "https://ww1.microchip.com/downloads/en/DeviceDoc/{part}-DataSheet.pdf"}
  - id: nordic
    name: Nordic Semiconductor
    prefixes: ["^nRF"]
    domains: [nordicsemi.com, docs.nordicsemi.com, github.com/NordicSemiconductor, raw.githubusercontent.com]
    urls:
      - {kind: svd, tier: gold, license: Apache-2.0, template: "https://raw.githubusercontent.com/cmsis-svd/cmsis-svd-data/main/data/Nordic/{part_lower}.svd", note: "nrfx/mdk không còn tệp .svd — bản dùng được nằm trong cmsis-svd-data"}
  - id: espressif
    name: Espressif
    prefixes: ["^ESP"]
    domains: [espressif.com, docs.espressif.com, github.com/espressif, raw.githubusercontent.com]
    urls:
      - {kind: svd, tier: gold, license: Apache-2.0, template: "https://raw.githubusercontent.com/espressif/svd/main/svd/{part_lower}.svd"}
  - id: raspberrypi
    name: Raspberry Pi
    prefixes: ["^RP2"]
    domains: [datasheets.raspberrypi.com, raspberrypi.com]
    urls:
      - {kind: pdf, tier: silver, license: vendor-doc, template: "https://datasheets.raspberrypi.com/{part_lower}/{part_lower}-datasheet.pdf"}
  - id: bosch
    name: Bosch Sensortec
    prefixes: ["^BME", "^BMP", "^BMI", "^BMA"]
    domains: [bosch-sensortec.com]
    urls:
      - {kind: pdf, tier: silver, license: vendor-doc, template: "https://www.bosch-sensortec.com/media/boschsensortec/downloads/datasheets/bst-{part_lower}-ds002.pdf", note: "bảng thanh ghi cần duyệt"}
  - id: invensense
    name: InvenSense / TDK
    prefixes: ["^MPU", "^ICM"]
    domains: [invensense.tdk.com]
    urls:
      - {kind: pdf, tier: silver, license: vendor-doc, template: "https://invensense.tdk.com/wp-content/uploads/2015/02/{part_upper}-Datasheet1.pdf", note: "CHƯA KIỂM ĐƯỢC: TDK trả 404 cho mẫu này (đo 08/09/2026). Giữ nguyên mẫu của TGT-19 §8 thay vì đoán một đường dẫn khác — một mẫu đoán bừa trông giống một mẫu đã kiểm"}
  - id: allegro
    name: Allegro MicroSystems
    prefixes: ["^A4", "^ACS"]
    domains: [allegromicro.com]
    urls:
      - {kind: pdf, tier: silver, license: vendor-doc, template: "https://www.allegromicro.com/-/media/files/datasheets/{part_lower}-datasheet.pdf"}
  - id: community
    name: Cộng đồng
    prefixes: []
    domains: [github.com/cmsis-svd, raw.githubusercontent.com]
    urls:
      - {kind: svd, tier: silver, license: Apache-2.0, template: "https://raw.githubusercontent.com/cmsis-svd/cmsis-svd-data/main/data/{vendor}/{part_upper}-Community.svd", note: "SVD community: bạc, không phải vàng"}
`);
fs.mkdirSync('isa', { recursive: true });
// [DEV-237] Manifest armv7-m — Cortex-M3. Thiếu nó là nguyên nhân TC018.
//
// Đo 23/09/2026: người dùng nêu STM32F103 (Blue Pill), `env.check` trả E2000 "ISA 'armv7-m'
// chưa có manifest". Câu ấy ĐÚNG và đó mới là chỗ đáng chú ý — mã nói thật, kho thiếu dữ liệu.
// Trước bản này `armv7e-m` khai `^STM32F[2-4]`, tức nó nhận cả STM32F2 vốn là Cortex-M3: một
// con chip KHÔNG có FPU được gán vào ISA của chip CÓ FPU, và `no_float_isr_without_fpu` mất
// hiệu lực đúng chỗ nó cần nhất. Nay `armv7e-m` chỉ nhận F3/F4 (M4), F1/F2 về đây.
//
// `sim` khác `armv7e-m` ở một điểm có thật: QEMU CÓ máy ảo cho Cortex-M3 (`netduino2` =
// STM32F205, `stm32vldiscovery` = STM32F100), trong khi DEV-086 đo được QEMU không mang máy ảo
// nào cho họ F4. Nên ở đây `qemu` là đường lui thật, không phải một dòng cấu hình cho đủ.
fs.writeFileSync('isa/armv7-m.yaml', `id: armv7-m
family_patterns: ["^STM32F1", "^STM32F2", "^LPC17", "^LPC18", "^GD32F1"]
abi: {endian: little, word: 32, fpu: none, align: 8}
interrupts: {model: nvic, vector_table: "0x00000000", priority_bits: 4}
toolchain:
  compiler: {name: arm-none-eabi-gcc, min: "13.2", check: "arm-none-eabi-gcc --version", package: {macos: arm-none-eabi-gcc, linux: gcc-arm-none-eabi}}
  tools: [{name: cmake, min: "3.22"}, {name: ninja}, {name: arm-none-eabi-size, package: {macos: arm-none-eabi-binutils, linux: binutils-arm-none-eabi}}, {name: arm-none-eabi-objcopy, package: {macos: arm-none-eabi-binutils, linux: binutils-arm-none-eabi}}]
  install: {macos: ["brew install --cask gcc-arm-embedded", "brew install cmake ninja"], linux: ["apt install gcc-arm-none-eabi cmake ninja-build"], windows: ["winget install Arm.GnuArmEmbeddedToolchain", "winget install Kitware.CMake"]}
  build: {cmd: "cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/arm.cmake && cmake --build build", artifact: "build/*.elf", map: "build/*.map"}
  static: {cmd: "cppcheck --enable=warning,performance --inline-suppr src", rules: [no_delay_in_isr, no_malloc, no_float_isr_without_fpu]}
flash: {adapters: [probe-rs, openocd], default: probe-rs, verify: true}
debug: {adapter: embedded-debugger-mcp, probes: [stlink, jlink, cmsis-dap], speed_khz: {min: 100, max: 8000, default: 4000}}
id_read: {method: idcode, cmd: "probe-rs info --probe {probe}", secondary: {reg: "0xE0042000", name: DBGMCU_IDCODE, mask: "0xFFF"}, table: id_tables/stm32.yaml}
serial: {default_baud: 115200, auto_baud_list: [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]}
sim: {engine: qemu, cmd: "qemu-system-arm -M netduino2 -nographic -kernel {artifact}", machines: {STM32F2: netduino2, STM32F1: stm32vldiscovery}, platform_template: renode/cortex-m.repl.j2, fallback: renode}
skills: [skills/armv7-m/interrupts.md, skills/armv7-m/clock.md, skills/armv7-m/i2c.md]
`);
fs.writeFileSync('isa/armv7e-m.yaml', `id: armv7e-m\nfamily_patterns: ["^STM32F[34]", "^STM32L4", "^nRF52", "^SAMD5", "^LPC55"]\nabi: {endian: little, word: 32, fpu: optional, align: 8}\ninterrupts: {model: nvic, vector_table: "0x00000000", priority_bits: 4}\ntoolchain:\n  compiler: {name: arm-none-eabi-gcc, min: "13.2", check: "arm-none-eabi-gcc --version", package: {macos: arm-none-eabi-gcc, linux: gcc-arm-none-eabi}}\n  tools: [{name: cmake, min: "3.22"}, {name: ninja}, {name: arm-none-eabi-size, package: {macos: arm-none-eabi-binutils, linux: binutils-arm-none-eabi}}, {name: arm-none-eabi-objcopy, package: {macos: arm-none-eabi-binutils, linux: binutils-arm-none-eabi}}]\n  install: {macos: ["brew install --cask gcc-arm-embedded", "brew install cmake ninja"], linux: ["apt install gcc-arm-none-eabi cmake ninja-build"], windows: ["winget install Arm.GnuArmEmbeddedToolchain", "winget install Kitware.CMake"]}\n  build: {cmd: "cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/arm.cmake && cmake --build build", artifact: "build/*.elf", map: "build/*.map"}\n  static: {cmd: "cppcheck --enable=warning,performance --inline-suppr src", rules: [no_delay_in_isr, no_malloc, no_float_isr_without_fpu]}\nflash: {adapters: [probe-rs, openocd], default: probe-rs, verify: true}\ndebug: {adapter: embedded-debugger-mcp, probes: [stlink, jlink, cmsis-dap], speed_khz: {min: 100, max: 8000, default: 4000}}\nid_read: {method: idcode, cmd: "probe-rs info --probe {probe}", secondary: {reg: "0xE0042000", name: DBGMCU_IDCODE, mask: "0xFFF"}, table: id_tables/stm32.yaml}\nserial: {default_baud: 115200, auto_baud_list: [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]}\nsim: {engine: renode, platform_template: renode/cortex-m.repl.j2, fallback: qemu}\nskills: [skills/armv7e-m/interrupts.md, skills/armv7e-m/clock.md, skills/armv7e-m/i2c.md]\n`);
fs.writeFileSync('isa/avr8.yaml', `id: avr8\nfamily_patterns: ["^ATmega", "^ATtiny", "^AVR(64|128)"]\nabi: {endian: little, word: 8, fpu: none, align: 1}\ninterrupts: {model: vector_table, priority_bits: 0}\ntoolchain:\n  compiler: {name: avr-gcc, min: "7.3", check: "avr-gcc --version"}\n  tools: [{name: avrdude, min: "7.0"}, {name: avr-size, package: {macos: avr-gcc, linux: binutils-avr}}]\n  # [DEV-172] Ba chỗ hỏng trong dòng cũ "brew install avr-gcc avrdude": tap osx-cross/avr\n  # nay chỉ còn formula ĐÁNH SỐ (avr-gcc@8…@15) nên lệnh ấy trả "No available formula";\n  # Homebrew từ chối nạp formula của tap bên thứ ba cho tới khi "brew trust"; và\n  # avr-gcc@14 là KEG-ONLY nên cài xong "which avr-gcc" vẫn không thấy — chỗ ấy\n  # eide_core.tools.which() lo, bằng cách tìm thêm trong /opt/homebrew/opt/*/bin.\n  install: {macos: ["brew tap osx-cross/avr && brew trust osx-cross/avr && brew install avr-gcc@14 avrdude"], linux: ["apt install gcc-avr avr-libc avrdude"], windows: ["winget install AVRDudes.AVRDUDE"]}\n  build: {cmd: "make -C . MCU={mcu} F_CPU={f_cpu}", artifact: "build/*.elf"}\nflash: {adapters: [avrdude, pymcuprog], default: avrdude, cmd: {avrdude: "avrdude -c {programmer} -p {part} -P {port} -U flash:w:{hex}:i"}, verify: true}\ndebug: {adapter: none, probes: [avrisp2, arduino]}\nid_read: {method: signature, cmd: "avrdude -c {programmer} -p {part} -P {port} -v", regex: "signature = (0x[0-9a-f]+ 0x[0-9a-f]+ 0x[0-9a-f]+)", table: id_tables/avr.yaml}\nserial: {default_baud: 115200, auto_baud_list: [9600, 19200, 38400, 57600, 115200]}\nsim: {engine: simavr, fallback: qemu}\nskills: [skills/avr8/timers.md, skills/avr8/twi.md]\n`);

// rv32imac — mốc M5 mở phần đầu (14/09/2026). Manifest này KHÁC hai cái trên ở một điểm đáng
// nói ra: nó khai `riscv64-elf-gcc` (bản multilib của Homebrew) chứ không `riscv-none-elf-gcc`
// mà bảng §2 nêu trước đây. Lý do là thứ đo được: bản multilib CÓ trên máy phát triển và dựng
// được rv32imac bằng `-march=rv32imac_zicsr -mabi=ilp32`, còn `riscv-none-elf-gcc` thì không
// có công thức brew nào. Cùng hình dạng với DEV-086 (avr8 phải khai `fallback: qemu` mới dùng
// được engine duy nhất chạy được trên máy này).
//
// `build.cmd` dùng cmake cùng khuôn `armv7e-m`, KHÔNG phải một dòng `gcc` có placeholder:
// `code.build` chạy lệnh trong manifest NGUYÊN VĂN (nó chỉ giải `argv[0]` thành đường tuyệt
// đối), nên `{march}`/`{sources}` sẽ đi thẳng vào dòng lệnh dưới dạng chữ. `march`/`mabi` giữ
// lại làm dữ liệu cho tệp toolchain cmake đọc.
//
// `sim.platform` là `-M virt` — máy ảo RISC-V chung của QEMU, KHÔNG phải esp32c3. QEMU của
// Espressif có máy ảo ấy nhưng không nằm trong `qemu` của brew. Nên chuỗi dựng→mô phỏng chạy
// thật với mã rv32 chung; firmware ESP32-C3 dùng ESP-IDF thì cần `xtensa-esp32`/ESP-IDF, vẫn
// ở M5. Khai đúng thứ chạy được, không khai thứ mong muốn.
fs.writeFileSync('isa/rv32imac.yaml', `id: rv32imac
family_patterns: ["^ESP32-?C[0-9]", "^ESP32-?H[0-9]", "^GD32V", "^CH32V", "^RV32", "^FE310"]
abi: {endian: little, word: 32, fpu: none, align: 4}
interrupts: {model: clint, vector_table: "0x80000000", priority_bits: 0}
toolchain:
  compiler: {name: riscv64-elf-gcc, min: "13.0", check: "riscv64-elf-gcc --version", package: {macos: riscv64-elf-gcc, linux: gcc-riscv64-unknown-elf}}
  tools: [{name: cmake, min: "3.22"}, {name: ninja}, {name: riscv64-elf-size, package: {macos: riscv64-elf-binutils, linux: binutils-riscv64-unknown-elf}}, {name: riscv64-elf-objcopy, package: {macos: riscv64-elf-binutils, linux: binutils-riscv64-unknown-elf}}]
  install: {macos: ["brew tap riscv-software-src/riscv", "brew install riscv64-elf-gcc cmake ninja"], linux: ["apt install gcc-riscv64-unknown-elf cmake ninja-build"], windows: ["winget install Kitware.CMake"]}
  build: {cmd: "cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/riscv.cmake && cmake --build build", artifact: "build/*.elf", map: "build/*.map", march: "rv32imac_zicsr", mabi: ilp32}
  static: {cmd: "cppcheck --enable=warning,performance --inline-suppr src", rules: [no_delay_in_isr, no_malloc, no_float_isr_without_fpu]}
flash: {adapters: [esptool, openocd], default: esptool, verify: true, cmd: {esptool: "esptool.py --port {port} write_flash 0x0 {bin}"}}
debug: {adapter: openocd, probes: [esp-usb-jtag, ftdi, cmsis-dap], speed_khz: {min: 100, max: 8000, default: 4000}}
id_read: {method: chip_id, cmd: "esptool.py --port {port} chip_id", regex: "Chip is ([A-Za-z0-9-]+)", table: id_tables/esp.yaml}
serial: {default_baud: 115200, auto_baud_list: [9600, 115200, 230400, 460800, 921600]}
sim: {engine: qemu, cmd: "qemu-system-riscv32 -M virt -nographic -bios none -kernel {artifact}", uart: "0x10000000", platform_template: qemu/riscv32-virt.j2}
skills: [skills/rv32imac/interrupts.md, skills/rv32imac/uart.md]
`);
}

// ================= SIM-20 =================
{
const m = metaNew('EIDE-SIM-20', 'Thiết kế mô phỏng', 'THIẾT KẾ MÔ PHỎNG (SIL) VÀ MÔ HÌNH ĐỐI TƯỢNG (SIM)',
  'Kiến trúc mô phỏng của EIDE: khi nào dùng Renode/simavr/QEMU, khi nào dùng simulator tự dựng; sinh nền tảng từ hộ chiếu; mock ngoại vi từ fact; mô hình động lực học robot cân bằng và cảm biến; định dạng kịch bản; so sánh SIL/HIL; giao diện SimView',
  [['Tài liệu trước', 'EIDE-SRS-02 FR-VER-04, UC-E01…E04, EIDE-CDS-12 tập 4 (sim.*), đề án (quyết định tự dựng simulator)'], ['Dùng khi', 'Hiện thực eide.sim, adapter sim theo ISA, plant robot; viết Chương thực nghiệm']],
  'Phát hành lần đầu — bổ sung lĩnh vực L22',
  [['1.1', '11/09/2026', 'Vũ Trí Công',
    '§1 bảng chế độ: `qemu` ghi thêm vai trò **đường lui của AVR8 khi máy không có simavr**, kèm điều kiện dùng được — QEMU chỉ chạy bo mạch đã biên dịch sẵn vào chương trình, nên "có qemu" không có nghĩa là chạy được chip này; `arduino-uno` = ATmega328P là mục khớp. §7 TC-SM-06 nhận cả hai đường. Đi cùng TGT-19 v1.2 (`isa/avr8.yaml` thêm `fallback: qemu`), DEV-086 — chủ sản phẩm duyệt 11/09/2026.']]);
const c = [];
c.push(H1('1. Vai trò và quyết định kiến trúc'));
c.push(P('Mô phỏng là bước bắt buộc trước phần cứng (defaults.sim_first) và là cách duy nhất để tác tử tự xác minh ở mức A2 khi chưa có board lab. Hai lớp mô phỏng phối hợp: **mô phỏng chip** (chạy đúng firmware nhị phân: Renode cho Cortex-M/RISC-V [20], simavr cho AVR [52], QEMU cho Xtensa/RISC-V [53]) và **mô phỏng đối tượng** (plant + cảm biến + cơ cấu chấp hành, viết bằng Python, chạy đồng thời và trao đổi qua ngoại vi mô phỏng). Quyết định (ADR-16): dùng engine mở cho lõi chip vì bản đồ thanh ghi và ngoại vi chuẩn đã có mô hình kiểm chứng; **tự dựng** phần đối tượng và mock ngoại vi ngoài (BME280, MPU6050, A4988) vì chúng đặc thù dự án và cần tham số có nguồn từ hộ chiếu; chỉ tự dựng mô phỏng chip tối thiểu (native: firmware biên dịch host + HAL mock) khi engine không hỗ trợ chip và mục tiêu chỉ là kiểm logic (không timing).'));
c.push(T([1700, 2300, 2600, 2700], ['Chế độ', 'Khi nào', 'Chạy gì', 'Độ tin'], [
  ['renode', 'Cortex-M, RISC-V có .repl; mặc định', 'ELF thật; ngoại vi chuẩn của Renode; ngoại vi ngoài qua mock Python (Renode Python peripheral)', 'Cao cho logic/thanh ghi; timing gần đúng'],
  ['simavr', 'AVR8', 'ELF/HEX thật; mock ngoại vi qua IRQ hook C', 'Cao (chu kỳ chính xác)'],
  ['qemu', 'Xtensa ESP32, RISC-V không có .repl; **đường lui của AVR8 khi thiếu simavr** (v1.1)', 'ELF thật; ngoại vi hạn chế. QEMU chỉ chạy bo mạch đã biên dịch sẵn vào chương trình, nên chỉ dùng được khi họ chip có máy ảo khớp — `arduino-uno` = ATmega328P', 'Trung bình'],
  ['native', 'Chip không hỗ trợ / kiểm logic nhanh', 'Firmware biên dịch host với HAL mock (code.test_host mở rộng)', 'Chỉ logic; không timing'],
]));
c.push(SP());
c.push(H1('2. Sinh nền tảng từ hộ chiếu (sim.build_platform)'));
c.push(...CODE([
  '# renode/cortex-m.repl.j2 → sim/platform.repl',
  'cpu: CPU.CortexM @ sysbus',
  '    cpuType: "cortex-m4"                       # từ fact chip:…/core',
  '    nvic: nvic',
  'nvic: IRQControllers.NVIC @ sysbus 0xE000E000   # fact base_address',
  'flash: Memory.MappedMemory @ sysbus 0x08000000 { size: {{ flash_size }} }   # fact memory_size',
  'sram:  Memory.MappedMemory @ sysbus 0x20000000 { size: {{ ram_size }} }',
  '{% for p in peripherals %}{{ p.name }}: {{ p.renode_model }} @ sysbus {{ p.base }}{% if p.irq %} -> nvic@{{ p.irq }}{% endif %}{% endfor %}',
  '# ánh xạ periph → mô hình Renode: I2C→ I2C.STM32F4_I2C, USART→ UART.STM32_UART, GPIO→ GPIOPort.STM32_GPIOPort, TIM→ Timers.STM32_Timer, RCC→ Miscellaneous.STM32F4_RCC (bảng renode_models.yaml theo họ)',
  '# ngoại vi không có mô hình → coverage.unsupported[] và, nếu là ngoại vi ngoài (I2C/SPI slave), sinh mock Python gắn vào bus',
  'sim/run.resc: mach create; machine LoadPlatformDescription @sim/platform.repl; sysbus LoadELF @build/fw.elf; uart CreateFileBackend @sim/uart.log; emulation RunFor "5"',
]));
c.push(SP());
c.push(H1('3. Mock ngoại vi ngoài từ fact (sim.mock_peripheral)'));
c.push(P('Mock là lớp Python `I2CPeripheral`/`SPIPeripheral` của Renode: bảng thanh ghi lấy từ fact (địa chỉ, reset_value, bit_range, enum), ID trả đúng fact (BME280 0xD0 → 0x60), dữ liệu đo sinh từ **nguồn giá trị** (hằng, hàm thời gian, hoặc plant §4) qua công thức ngược của datasheet (extract.pdf_formula: từ nhiệt độ thật → thanh ghi ADC bù) cộng nhiễu Gauss cấu hình; hành vi lỗi có thể tiêm (NACK, timeout, bit lỗi) cho kịch bản gỡ lỗi. Tham số không có fact → `provisional` và nhãn "tham số tạm" trong SimView (Z-09).'));
c.push(...CODE([
  'class BME280Mock(I2CPeripheral):                      # sinh từ hộ chiếu part:bosch.bme280',
  '    REGS = load_regs("part:bosch.bme280")             # {0xD0: {"reset": 0x60, "ro": True}, 0xF4: {...}, 0xF7..0xFE: burst}',
  '    def __init__(self, source: ValueSource, noise=0.02): ...',
  '    def Read(self, count): return self.burst(self.ptr, count)   # ctrl_meas.mode forced → đo một lần; normal → theo t_sb',
  '    def Write(self, data): self.ptr = data[0]; self.write_regs(data[1:])',
  '    def encode_temperature(self, t_c): return inverse_compensation_T(t_c, self.calib)  # công thức trang 25 datasheet [src#p25]',
]));
c.push(SP());
c.push(H1('4. Mô hình đối tượng: robot hai bánh tự cân bằng'));
c.push(P('Plant là con lắc ngược trên xe hai bánh (wheeled inverted pendulum): trạng thái x = [θ, θ̇, φ, φ̇] (góc thân, tốc độ góc thân, góc bánh, tốc độ bánh); đầu vào là mô-men bánh τ (từ stepper: bước/giây × mô-men giữ ước lượng); phương trình chuyển động phi tuyến rút gọn với tham số M (khối lượng thân), m (bánh), l (tâm khối), r (bán kính bánh), I, J; tích phân RK4 bước 1 ms đồng bộ với tick mô phỏng chip; cảm biến: MPU6050 mock nhận θ, θ̇ + nhiễu + offset gyro drift; A4988 mock đếm STEP/DIR → tốc độ bánh → τ. Tham số mặc định từ mẫu tham chiếu K5′ (có nguồn: khối lượng 0,8 kg, bánh 65 mm, tâm khối 60 mm — nhãn tạm cho tới khi người đo). Kiểm mô hình: không điều khiển → đổ trong ~0,6 s; PID chuẩn tham chiếu → ổn định ≤ 1,5 s sau nhiễu 5°.'));
c.push(...CODE([
  'class BalancingRobotPlant(Plant):',
  '    params: {M: 0.8, m: 0.05, l: 0.06, r: 0.0325, I: 1.9e-3, J: 2.6e-5, g: 9.81, dt: 0.001}   # provisional=["M","l"] nếu từ template',
  '    def step(self, tau: float) -> State: ...            # RK4 trên f(x, tau)',
  '    def sensors(self) -> {"theta": θ, "gyro_y": θ̇, "accel": (ax, az)}',
  '    def actuator(self, step_rate: float, direction: int) -> tau',
  '# Nối: A4988Mock.on_step → plant.actuator; plant.sensors → MPU6050Mock.source; đồng bộ dt với Renode emulation time',
]));
c.push(SP());
c.push(H1('5. Định dạng kịch bản (sim.scenario)'));
c.push(...CODE([
  '# sim/f04.yaml — sinh từ expectation của Feature F-04',
  'id: F-04-basic', 'engine: renode', 'artifact: build/fw.elf', 'duration_s: 5',
  'init: {plant: balancing-robot, mocks: [bme280@0x76, mpu6050@0x68, a4988], uart: {port: USART2, baud: 115200}}',
  'inject:',
  '  - {t: 0.5, mock: mpu6050, set: {theta_deg: 5}}          # nhiễu 5°',
  '  - {t: 2.0, mock: bme280, fault: nack, count: 2}          # tiêm lỗi',
  'expect:',
  '  - {kind: uart, pattern: "IMU ok", within_s: 1.0}',
  '  - {kind: var, symbol: g_theta, abs_lt: 0.02, after_s: 2.0}   # ổn định (đọc biến qua GDB stub/monitor)',
  '  - {kind: gpio, pin: PC13, toggles_min: 4, window_s: 5}',
  '  - {kind: uart, pattern: "I2C NACK handled", within_s: 2.5}',
  'record: [uart, gpio.PC13, var.g_theta, plant.theta]',
]));
c.push(SP());
c.push(P('sim.run trả ToolReport với `captured` (uart.log, gpio.csv, vars.csv, plant.csv) và bảng expect ↔ kết quả; kịch bản dùng lại nguyên vẹn cho HIL (target.observe với kind uart/gpio/probe; `var` → probe đọc symbol; `plant` → không áp dụng) để so sánh (sim.compare_hil: lệch thời gian sự kiện > 20% hoặc kết quả khác → đề xuất cập nhật mock/plant).'));
c.push(H1('6. SimView và tương tác'));
c.push(P('Màn hình Sim (UXD-13): chọn kịch bản; dòng thời gian sự kiện (inject/expect) trên trục chung; đồ thị plant.theta và biến firmware; log UART; bảng expect với trạng thái; nút "Quét tham số" (sim.sweep) hiện bảng nhiệt; nút "So với HIL". Nhãn "tham số tạm" hiện khi provisional không rỗng và có ô nhập giá trị đo được (ghi thành fact K6 qua cổng ghi).'));
c.push(H1('7. Kiểm thử'));
c.push(T([1000, 3400, 3700, 1200], ['TC', 'Mục tiêu', 'Kỳ vọng', 'Mức'], [
  ['TC-SM-01', 'Sinh .repl từ hộ chiếu', 'STM32F411 → platform.repl nạp được; coverage liệt kê ngoại vi không mô hình', 'L2'],
  ['TC-SM-02', 'Mock BME280', 'Firmware đọc ID 0x60; nhiệt độ 25 °C ↔ thanh ghi đúng theo công thức bù (sai số < 0,1 °C)', 'L2'],
  ['TC-SM-03', 'Plant', 'Không điều khiển đổ < 1 s; PID tham chiếu ổn định ≤ 1,5 s', 'L1'],
  ['TC-SM-04', 'Kịch bản và expect', 'f04.yaml chạy; tiêm NACK → firmware xử lý; expect var qua monitor', 'L2'],
  ['TC-SM-05', 'SIL/HIL cùng kịch bản', 'Nucleo và Renode chạy F-01/F-03; báo cáo lệch < 20%', 'L3'],
  ['TC-SM-06', 'simavr/QEMU', 'Uno blink+UART trên simavr — hoặc trên `qemu-system-avr -M arduino-uno` theo `fallback` của manifest khi máy không có simavr (v1.1); ESP32-C3 hello trên QEMU', 'L2'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-SIM-20_Thiet_ke_mo_phong.docx');
}
