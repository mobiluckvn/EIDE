# Tiến độ sản phẩm EIDE

*Cập nhật 16/09/2026 (lần 24). Số liệu **đo từ mã**, không gõ tay: `eide spec`,
`scripts/kiem_chuoi_chuan.py`, `pytest`. Tài liệu này sinh lại bằng cách chạy lại chúng —
đừng sửa số ở đây mà không chạy lại, vì con số gõ tay sẽ đúng đúng một ngày.*

> Đã xảy ra đúng như thế ngày 08/09: hai lần cập nhật liền nhau tôi CỘNG THÊM vào con số cũ thay
> vì đo lại, và tổng lệch 2 (ghi 122, thật là 124). Từ lần này mọi con số ở đây đều lấy từ một
> lượt đếm trên registry ngay trước khi ghi.

---

## 1. Một dòng

**216/238 năng lực (91%). M0 22/22; M1 74/75; M2 89/99; M3 22/29; M4 8/9; M5 1/4. 1602 test
Python + 3092 test Swift xanh (trong đó 27 test ĐẦU-CUỐI gọi daemon thật). Nghiệm thu Sprint 2: 18/18; Sprint 3: 13/13. Panel: 23 màn hình trên điều hướng, 201/201 năng lực hiện được kết quả, 10/10 phím tắt, 23 kiểu sự kiện sổ cái đẩy lên UI (API-15 khai 21 `event.*`). Thêm 7 bài `--self-test EIDE` đo trên CỬA SỔ THẬT: 7/7, trong đó một bài KIỂM KÊ cả 23 màn.**

**Từ 15/09, phần việc không nằm ở năng lực nữa mà ở GIAO DIỆN.** Con số năng lực không đổi
trong hai ngày này — 216/238 hôm 14/09 và 216/238 hôm nay — trong khi sáu màn được dựng lại
và mười một lỗi lộ ra. Đó không phải nghịch lý: một năng lực "xong" nghĩa là nó trả đúng dữ
liệu, còn một màn "xong" nghĩa là người dùng ĐỌC được dữ liệu ấy, và hai điều đó cách nhau
đúng bằng khoảng cách mà bộ test không đi qua.

**Từ 14/09, MỌI thứ còn thiếu quy về một nguyên nhân: chưa có bo mạch.** Rà lại 29 năng lực
chưa hiện thực thì **bảy cái không chặn bởi gì cả** — chúng chỉ HỎI máy tính xem đang thấy gì,
và câu trả lời "không thấy board nào" có giá trị đúng bằng câu "thấy một nucleo-f411". Bảy cái
ấy đã xong (14/09); 22 cái còn lại thì cần board, công cụ ngoài, hoặc thiết bị đo. Giao diện đã đủ 23
màn — số ấy đo lại mỗi lần chạy test (`EideManDayDuTests` đọc thẳng `docs/spec/ui/screens.json`),
không phải một dòng gõ tay. Không còn mục nào chờ thời gian, chờ một thư viện, hay chờ một
quyết định. Đo trên mười trục của
[`DOI-CHIEU-THIET-KE.md`](DOI-CHIEU-THIET-KE.md):

| Còn thiếu | Chặn bởi |
|---|---|
| 22 năng lực (`discover` 8 · `target` 8 · `measure` 3 · `bench.run` · `passport.verify_on_board` · `sim.compare_hil`) | board · công cụ ngoài (probe-rs/openocd) · thiết bị đo |
| 7 phương thức JSON-RPC (`serial.*`, `discover.status` và hai sự kiện của chúng) | board |
| 1 kiểu sự kiện sổ cái (`discover.result`) | board |
| 2 trong 3 mã lỗi chưa ném (`E4003` cần board; `E1003` cần một bề mặt REST chưa có) | board |
| phần lớn 27 mã TC còn lại | board / máy đo |
| 4 màn hình chỉ hiện được trạng thái rỗng (Discovery, Debug probe, Bench, phần `target.*` của LogAssist) | board — khung nhìn đã dựng đủ theo hợp đồng |

**21 trong 27 nhóm năng lực đã đủ.** Sáu nhóm chưa đủ: `passport` 7/8, `sim` 6/7, và bốn nhóm
phần cứng chưa bắt đầu.

Bốn trục đối chiếu đã **100%**: thực thể dữ liệu, schema JSON, quy tắc chính sách (49/49), vai
trò mô hình (9/9).

---|---|---|
| **Board thật** | 29 | `discover` 12 · `target` 9 · `bench` 3 · `measure` 3 · `passport` 2 |
| **Mô hình thị giác** | 5 | `extract.ocr`/`image_*` 4 · `diagram.from_image` |
| **Registry thật** | 6 | `registry.*` 4 · `search.registry`/`reference_projects` |
| **Báo cáo HIL thật** | 1 | `sim.compare_hil` |

Nói cách khác: phần mềm đã hết việc làm một mình. Mọi bước tiếp theo cần một vật ở ngoài —
một bo mạch, một khoá mô hình có thị giác, hay một registry.

**Mốc lớn nhất của ngày 11/09 nằm ở đợt 3: `code.build` dựng ra firmware THẬT.** Mắt xích trung
tâm của luận điểm đề án — *sinh mã có nối về fact* — nay đã thi hành đầu-cuối: lệnh dựng đọc từ
`docs/spec/isa/armv7e-m.yaml`, chạy trong sandbox không mạng, và thứ rơi ra là một ELF mà
`objdump` đọc là `architecture: armv7e-m`. Phải sửa **ba tầng** trong lõi sandbox mới chạy được,
và cả ba chưa ai chạm tới bao giờ vì **không test nào từng dựng THÀNH CÔNG** — xem §5 và
[DEV-088](DEVIATIONS.md).

**Phiên 11/09 mở khối F1 — nhóm `sim.*` đóng phần M3 (6/6; `compare_hil` là M4).** Chuỗi Z-05
"thêm tính năng" nhờ đó lên **14/16** và chỗ đứt dời từ `sim.run` sang `target.flash`, tức sang
phần cần phần cứng.

**Phiên 11/09 đợt 2 không thêm năng lực nào, và đó là chủ ý: cả ba việc đều là "thứ tưởng đã
đúng".** Số năng lực đứng yên ở 182, nhưng ba đường mã trước đó chưa ai chạy thì nay đã chạy:

- **`sim.*` chạy engine THẬT lần đầu** ([DEV-086](DEVIATIONS.md), chủ sản phẩm duyệt).
  `qemu-system-avr -M arduino-uno` chạy một ELF AVR qua chính `sim.run` và cho
  `captured.uart == ["E"]` — ký tự firmware ghi vào UDR0, không phải chuỗi một shim echo ra.
- **Phần Swift vào `make check`** (WI-260). Trước đó `make check` chỉ gọi phía Python, nên gói
  Swift đỏ hai bài suốt năm ngày mà "xanh" của dự án vẫn nói về toàn kho.
- **`search.rank` thôi dùng danh sách trắng TẢI VỀ làm thước đo chất lượng**
  ([DEV-087](DEVIATIONS.md)). Lộ ra khi ký WI-257.

Ba việc, cùng một hình dạng: **một cơ chế trông như đang có hiệu lực.** Cùng họ với ba hằng số
thời gian chờ của sandbox (lỗi im lặng số 7) và với ngưỡng cứng R4 (số 5).

Mốc M2 vẫn còn 19 mục và không mục nào làm được trên máy này: `discover.*` (8), `target.*` (5),
`bench.*` (3) cần **board thật**; `extract.ocr`/`image_*` (3) cần **đường ảnh cho Gateway**
(mục P4 trong [CONG-VIEC.md](CONG-VIEC.md)).

Điều này nghĩa là: **xương sống đã chạy thật đầu-cuối** — một câu tiếng Việt đi qua cổng
chính sách, tra tri thức có nguồn, ra kết luận truy nguyên được. Phần còn thiếu là **tay
chân**: nạp board, đo, gỡ lỗi trên phần cứng.

> **Bảng này đo MỘT trục: số năng lực.** Đối chiếu đầy đủ trên mười trục — RPC, MCP, mã
> lỗi, quy tắc cổng, mã TC, màn hình UI — ở [`DOI-CHIEU-THIET-KE.md`](DOI-CHIEU-THIET-KE.md),
> và bức tranh ở đó khác hẳn: **trục năng lực 83%, trục JSON-RPC 21%.**

---

## 2. Theo mốc

| Mốc | Xong | Ý nghĩa |
|---|---|---|
| **M0** | **22/22 · 100%** | Nền: dự án, store, chính sách, thu nhận tri thức |
| **M1** | **74/75 · 99%** | Tác tử hiểu lệnh, tra cứu, lập kế hoạch, viết tài liệu |
| M2 | 83/99 · 84% | Sinh mã, board, mô phỏng nền, tài liệu đầy đủ |
| M3 | **21/29 · 72%** | Mô phỏng và gỡ lỗi — `sim.*`, `debug.*`, đường ảnh đều xong |
| M4 | 2/9 | Registry chia sẻ, benchmark |
| M5 | 1/4 | ISA mở rộng — `extract.image_scope` xong; ba manifest ISA còn lại xem [DEV-055](DEVIATIONS.md) |

**M1 còn đúng 1 năng lực**: `passport.verify_on_board` (R3) — **cần board thật**, không mô
phỏng được phần "nạp firmware rồi đọc lại ID".

---

## 3. Theo nhóm năng lực

*Số đo từ registry, không gõ tay (`eide spec`).*

**Đủ (21/27 nhóm)** — `arch` 11/11 · `archive` 7/7 · `board` 5/5 · `chat` 8/8 · `code` 16/16 · `debug` 6/6 · `diagram` 14/14 · `doc` 12/12 · `env` 7/7 · `extract` 21/21 · `kg` 9/9 · `memory` 8/8 · `plan` 7/7 · `policy` 7/7 · `project` 9/9 · `registry` 5/5 · `report` 4/4 · `req` 8/8 · `search` 9/9 · `tool` 10/10 · `view` 13/13

**Gần đủ** — `passport` 7/8 · `sim` 6/7 — cả hai chỉ còn mục cần **board thật** (`passport.verify_on_board`, `sim.compare_hil`)

**Chưa bắt đầu** — `bench` (3) · `discover` (12) · `measure` (3) · `target` (9) — bốn nhóm phần cứng, đúng thứ tự chủ sản phẩm chốt 08/09.

Không nhóm nào còn chờ phần mềm.
---

## 4. Năm chuỗi chuẩn — chỗ đứt

Đo bằng `scripts/kiem_chuoi_chuan.py` (đối chiếu `dialog/chains.json` với registry):

| Chuỗi | Tiến độ | Đứt tại |
|---|---|---|
| **Z-07** dự án từ zip | **23/23** | ✓ **đủ năng lực cho mọi bước** |
| **Z-01** dự án từ ý tưởng | 12/14 | `search.reference_projects` (M4) |
| **Z-05** thêm tính năng | **14/16** | `target.flash` — **chỗ đứt nay ở phần cứng**, không còn ở mô phỏng |
| **P7** bộ tài liệu | **8/8** | ✓ **đủ năng lực cho mọi bước** |
| **Z-10** dò board và nạp | 1/10 | `discover.ports` (M2) — cần phần cứng |

**Hai chuỗi đã trọn vẹn.** Z-07 đủ năng lực cho cả 23 bước — chuỗi đầu tiên trọn vẹn: zip → trích → hộ chiếu board → yêu cầu → kế hoạch → sinh mã → dựng → merge → hướng dẫn bringup. `tests/test_board.py::test_chuoi_Z07_du_nang_luc` giữ điều đó khỏi tụt đi trong im lặng.
P7 đóng nốt bằng `diagram.architecture`, `diagram.state`, `doc.generate`, `doc.embed_diagram`
— sản phẩm nay TỰ SINH ĐƯỢC bộ tài liệu về chính nó, bảng số liệu dựng từ store và có mục
Nguồn truy ngược. Ba chuỗi còn lại đứt ở đúng chỗ dự kiến: chúng cần `target.*`, `discover.*`,
`search.reference_projects` — tức **phần cứng hoặc registry**, không còn thứ nào chờ mô phỏng.

**Z-05 là chuỗi đổi nhiều nhất trong phiên 11/09.** Trước đó nó dừng ở `sim.run`; nay nó đi
tiếp qua `sim.scenario → sim.run → code.merge` và chỉ dừng ở `target.flash`. Nói cách khác:
vòng *sinh mã → dựng → mô phỏng → ghép* đã liền, và cái còn thiếu là cắm board.

---

## 5. Cái gì chạy được THẬT hôm nay

`scripts/nghiem_thu_sprint2.sh` chạy 18 bước bằng CLI thật trên một dự án mới tinh, **18/18
ĐẠT trên cả hai kiến trúc Mac**:

```
eide project new "đo nhiệt độ bằng STM32F411 và BME280"
  → dự án + store + niêm + ledger
  → ghim ISA (suy từ docs/spec/isa/*.yaml, không từ bảng chép tay)
  → phân loại tệp theo CHỮ KÝ nội dung (tệp tên .xml vẫn nhận đúng là SVD)
  → trích SVD: 11 fact, derivedFrom giãn I2C2 kế thừa thanh ghi của I2C1
  → tra hộ chiếu: có trích dẫn, < 200 ms
  → đối chiếu yêu cầu với phần cứng: kết luận KÈM fact id
  → ngân sách thời gian: U = 0,15 so với cận Liu–Layland
  → cổng G-SRC chặn nguồn lạ → vào hàng đợi "chờ anh"
  → sổ cái băm liên tục; niêm store khớp
```

Ngoài ra: **MCP server** (dùng được từ Claude Code/Cursor), **plugin GEditor** (Swift, panel
ba vùng), **JSON-RPC daemon**, **CLI** đầy đủ.

**Và từ 15–16/09, GIAO DIỆN chạy được thật — có ảnh chụp trên dữ liệu thật.** Sáu màn dựng lại
trên một bộ từ vựng hiển thị chung (`EideTuVung`: bảng sắp xếp được, cây, khối mã, diff, dải
trạng thái), thay cho ba thứ cũ là một đoạn văn, một dòng `nhãn: giá trị`, và một lời xin lỗi:

| Màn | Đo được trên bản dựng release |
|---|---|
| Hộ chiếu chip | 8 fact thành bảng sắp xếp được; địa chỉ ra `0x3FC7C000` chứ không `1070055424`; `392 KiB (401408)`; hai fact XUNG ĐỘT tô đỏ |
| Bản đồ tri thức | 17 nút · 26 cạnh thành cây gốc `chip:*`, quan hệ `HAS`/`CITES`/`ABOUT` hiện ở lề phải |
| Mô phỏng | `qemu-system-avr` chạy 25 giây qua daemon, 6/6 kỳ vọng có TÊN, log UART 8 dòng hiện đủ |
| Mã nguồn | `main.c` 16 dòng · 2 dòng có fact (`•`) · 4 dòng vi phạm (`!`), cổng G-FACT chặn |
| Kế hoạch & mã | bản vá hiện thành diff/khối mã kèm `rationale` và `missing_facts` |
| Cây dự án | workspace trỏ đúng thư mục dự án, `.eide/` hiện thành nhóm riêng cuối cây |
| Mã nguồn (gộp) | mở `main.c`: cây + trình soạn thảo + vạch lề XANH LỤC ở 2 dòng có fact, ĐỎ ở 4 dòng vi phạm — tự chạy khi mở tệp |
| Môi trường | bảng cổng serial có cột "truy cập"; `driver_ok: false` ra ô đỏ |
| Nhật ký | 311 mốc thành bảng sắp xếp được, cột `ai` tô màu việc tác tử tự làm |

Ba việc nền đi kèm, mỗi việc đều là thứ không màn nào tự làm được: bỏ cửa sổ EIDE cũ (chọn dự
án từng mở ra một cửa sổ THỨ HAI với dự án khác), theo dõi việc nặng qua `job.status` thay vì
gọi `running` là lỗi, và ghim bảng màu sáng cho cả bề mặt EIDE (token PTIT cố định gặp control
AppKit theo chế độ hệ thống = ô nhập đen sì trên máy để chế độ tối).

Năm bài `--self-test EIDE` đo trên CỬA SỔ THẬT, vì `MainWindowController` nằm trong target thực
thi nên không bộ test nào import được — và đó đúng là lý do cả lớp lỗi cửa sổ sống lâu tới vậy.

**Và từ 11/09 đợt 2, một lượt mô phỏng THẬT** — `qemu-system-avr -M arduino-uno` (= ATmega328P)
chạy một ELF AVR qua chính `sim.run`, qua chính sandbox SEC-25, trả `captured.uart == ["E"]`.
ELF ấy dựng bằng tay trong test, 98 byte, năm lệnh mã máy (TXEN0 → UCSR0B, `'E'` → UDR0,
`rjmp .-2`): máy phát triển không có `avr-gcc`, và cả nhóm `sim.*` thì không được phép chờ một
chuỗi công cụ để có lấy một lượt chạy thật. Đổi lại bài chạy trong 4 giây và không cần cài gì.

Điều ấy đáng ghi vì nó đổi hạng của 44 test còn lại: trước hôm nay chúng đều đứng trên một shim
luôn ngoan, nên chúng kiểm được phần thuộc về EIDE mà không thể sai theo cách một engine thật
sai được. Nay nhánh `TU_DUNG["qemu"] = False` — *hết giờ LÀ cách lượt chạy kết thúc, không phải
E4004* — đã có một engine thật chứng minh.

**Và từ đợt 3, một bản dựng THẬT.** `code.build` chạy `cmake`/`ninja`/`arm-none-eabi-gcc` 16.2
trong sandbox không mạng và cho ra ELF `elf32-littlearm`, `architecture: armv7e-m` — đúng ISA
manifest khai, không phải kiến trúc của máy đang chạy test. `code.size` đọc số thật từ
`arm-none-eabi-size` (text 28 B, bss 4 B) và tính được `flash_pct` so với 512 KB của STM32F411RE.

**Ba tầng lỗi phải sửa mới tới được đó, và không tầng nào từng được thi hành:**

1. `execvp() of 'cmake' failed` — `code.build` truyền **tên trần** vào sandbox, mà `PATH` ở đó
   là bốn thư mục hệ thống (SEC-25 §3). `code.static` và `env.install` đều đã giải `which()`
   sẵn; `code.build` thì không — và nó là cái quan trọng nhất.
2. `does not appear to contain CMakeLists.txt` — sandbox chạy ở thư mục **tạm**, trong khi
   `build.cmd` viết `cmake -S . -B build` và `artifact: build/*.elf`, đều tương đối so với gốc
   dự án. Lõi nay nhận `cwd`, **ràng buộc phải nằm trong `allowed_dirs`** để tham số ấy không
   thành một lối vòng qua chính SEC-25 §2.
3. `unable to find a build program corresponding to Ninja` — **công cụ tự gọi công cụ.** Giải
   `argv[0]` chữa được lệnh đầu tiên, không chữa được `cmake → ninja` hay `make → gcc`. Lõi nay
   nhận `them_path`: đúng thư mục của những công cụ manifest ISA khai và `env.check` đã tìm
   thấy — khác với mở cả `PATH` của người dùng.

Tầng thứ ba là chỗ đáng nhớ nhất: hai tầng đầu còn có thể đoán ra khi đọc mã, tầng thứ ba thì
chỉ lộ khi một chương trình thật đi tìm một chương trình thật khác. Xem [DEV-088](DEVIATIONS.md).

**`scripts/nghiem_thu_sprint3.sh` — 13/13 ĐẠT.** Nếu Sprint 2 chứng minh chuỗi *tri thức*, kịch
bản này chứng minh nửa còn lại — **từ tri thức tới firmware chạy được** — và nó không dùng một
shim nào:

```
eide project new "điều khiển LED và đọc BME280 trên STM32F411"
  → ghim đích: ISA suy ra armv7e-m từ docs/spec/isa/*.yaml
  → env.check: cả năm công cụ sẵn sàng
  → code.build: ELF elf32-littlearm, architecture armv7e-m  ← KHÔNG phải kiến trúc máy chạy
  → code.size:  text 28 B · bss 4 B · flash_pct 0,01% của 512 KB
  → constant_guard: 0x76 không chú thích fact → BLOCK
  → sim.run trên qemu-system-avr -M arduino-uno → captured.uart khớp kỳ vọng
  → sổ cái 17 bản ghi liên tục (có tool.report của build/size/sim)
  → niêm store khớp sau khi dựng và đo
```

Nó **bỏ qua có báo** khi máy thiếu công cụ thay vì báo đỏ: một máy chưa cài `arm-none-eabi-gcc`
thì câu trả lời đúng là "chưa kiểm được", không phải "hỏng". Và nó **mang theo một dự án CMake
tối thiểu**, vì EIDE không sinh scaffold — `code.build` dựng theo `CMakeLists` CỦA DỰ ÁN.

---

## 6. Chất lượng

| Chỉ số | Giá trị |
|---|---|
| Test Python | **1555** xanh, arm64 + x86_64 (`make check-py`) |
| Test Swift | **2863** xanh (`make check-swift`, nay nằm trong `make check` — WI-260). Trong đó **193** là EIDEKit, phần thuộc EIDE; còn lại là GEditor, nay là màn "Mã nguồn" của EIDE ([DEV-098](DEVIATIONS.md)) |
| Test GỌI THẬT | 10 mạng (`make check-net`) · 7 mô hình (`make check-llm`) · **2 engine mô phỏng** (`qemu-system-avr`, `qemu-system-riscv32`) · **2 chuỗi công cụ ARM** (`arm-none-eabi-gcc` + `cmake`/`ninja`). Ba nhóm sau nằm trong `make check` và tự bỏ qua nếu máy không có công cụ |
| Nghiệm thu Sprint 1 / 2 / 3 | 17/17 · 18/18 · **13/13** |
| Mục DEVIATIONS | 102 tổng, **17 Mở** — 5 là nợ hiện thực chờ mốc/khối sau ([DEV-074] M5, [DEV-082]…[DEV-085] chờ kênh quan sát); còn lại chờ chủ sản phẩm, mới nhất là [DEV-099] (vùng nhớ từ header hãng), [DEV-100] (vòng lặp duyệt ở ngưỡng cứng R4), [DEV-101], [DEV-102] |
| Tài liệu | 35 tệp, khớp nguồn sinh từng khối (`make check`). Phiên này: **TGT-19 v1.2**, **SIM-20 v1.1** |

**Kiểm đột biến** dùng cho mọi nhóm năng lực: cố ý phá từng khẳng định rồi xác nhận test đỏ.
Nó đã bắt được nhiều test "xanh vì lý do khác với lý do nó được viết ra" — trong đó có test
SAFETY của `req.*`, ngưỡng 85% Flash của `arch.*`, hai lớp chặn DoS của `archive.unpack`, và
ngưỡng 0,35 của `view.rag_ask`.

**Một luồng thật, từ đầu đến cuối** (14/09/2026 — board ESP32-C3, không phần cứng). Đây là lần
đầu một dự án đi trọn từ câu hỏi của người tới firmware chạy trong mô phỏng, và mỗi con số dưới
đây là một lần gọi năng lực thật, không phải fixture:

| Bước | Năng lực | Đo được |
|---|---|---|
| Tạo dự án, tìm tài liệu | `project.create` → `search.vendor` → `search.fetch` | SVD Espressif (gold, 1,0) |
| Trích tri thức | `extract.svd` → `kg.build` | **8.169 fact** → **15.834 nút / 37.938 cạnh** |
| Tra hộ chiếu | `passport.query` | I2C0 base `0x60013000`, có trích dẫn |
| Ghim đích, kiểm môi trường | `project.set_target` → `env.check` | `isa: rv32imac`, **5/5** công cụ |
| Dịch | `code.build` | `passed: true`, exit 0, `build/fw.elf` |
| Duyệt fact | `kg.review_facts` | **8.125** tự duyệt · **44** hỏi người · 0 từ chối |
| Vùng nhớ | `extract.header_c` ([DEV-099](DEVIATIONS.md)) | **10 vùng, 20 fact vàng** — SRAM 400 KB, ROM 384 KB, RTC 8 KB, khớp datasheet tr.34 từng con số |
| Dựng nền tảng | `sim.build_platform` | qemu-system-riscv32, 10 vùng, 37 ngoại vi chưa mô hình |
| Chạy mô phỏng | `sim.run` | **5/5 expect đạt**, UART thật, 0 `unverified` |

Bốn lỗi im lặng (22–25) lộ ra trong chính buổi này, và không cái nào lộ được bằng một lời gọi
đơn lẻ. Hai chỗ luồng còn dựa vào tay người vì môi trường thiếu khoá mô hình, và phải nói ra:
`sim.scenario` (vai trò `planner`) không chạy được nên kịch bản `sim/bme280-khoi-dong.yaml` là
viết tay theo đúng `_SCHEMA_KICH_BAN`; mọi `extract.pdf_*` cũng đứng vì cùng lý do, nên vùng
nhớ đi đường header thay vì đường datasheet.

**Luồng thứ hai, họ chip thứ hai** (14/09/2026 — Arduino Uno / ATmega328P, vẫn không phần cứng).
Chạy lại đúng trình tự ấy trên một kiến trúc 8 bit để xem điều gì chỉ đúng với một nền tảng:

| Bước | Năng lực | Đo được |
|---|---|---|
| Tìm nguồn hãng | `search.vendor` → `search.fetch` | gói DFP Microchip 35,4 MB, Apache-2.0 — qua cổng sau khi **người duyệt** ([DEV-103](DEVIATIONS.md)) |
| Mở gói | `archive.query` → `archive.extract_one` | `atdf/ATmega328P.atdf` trong một kho 35 MB, không giải nén toàn bộ |
| Trích tri thức | `extract.atdf` → `kg.build` | **287 fact** → **587 nút / 1.340 cạnh** |
| Tra hộ chiếu | `passport.query` | `UBRR0` = 0xC4, `UCSR0A` = 0xC0, `UDRE0` bit 5 — khớp datasheet |
| Ghim đích, kiểm môi trường | `project.set_target` → `env.check` | `isa: avr8`, **3/3** công cụ (avr-gcc 7.3.0, avrdude 8.0) |
| Dịch | `code.build` | `passed: true`, `build/fw.elf` |
| Ngân sách bộ nhớ | `code.size` | 650 B / 32.768 (**1,98 %** flash) · 108 B / 2.304 (**4,69 %** RAM) — **giới hạn lấy thẳng từ fact ATDF** |
| Dựng nền tảng | `sim.build_platform` | `simavr` không có → **fallback qemu** ([DEV-086](DEVIATIONS.md)), 3 vùng nhớ |
| Chạy mô phỏng | `sim.run` | **6/6 expect đạt** trên `qemu-system-avr -M arduino-uno`, 0 `unverified` |

Khác biệt đáng kể nhất giữa hai luồng nằm ở **nguồn của `memory_size`**: ATDF của Microchip khai
sẵn ba vùng (FLASH 32 KB, RAM 2.304 B, EEPROM 1 KB), nên `code.size` và `sim.build_platform`
chạy được ngay — trong khi SVD của Espressif không khai vùng nào và phải đi đường header
([DEV-099](DEVIATIONS.md)). Cùng một hợp đồng, hai hãng, hai mức đầy đủ.

Bốn lỗi im lặng nữa (26–29) lộ ra ở buổi này. Và một chỗ dựa tay người y như lần trước:
`sim.scenario` vẫn cần khoá mô hình, nên `sim/blink-uart.yaml` là viết tay.

**Ba lớp test, ba loại câu hỏi khác nhau.** `make check` (1346 test, giả lập) hỏi *"mã có đúng
với giả định của tôi không"*. `make check-net` (10 test, không tốn tiền) và `make check-llm`
(6 test, tốn token) hỏi *"giả định của tôi có đúng với đời thật không"* — và câu hỏi thứ hai
đã tìm ra hai lỗi mà lớp thứ nhất không thể thấy:

- **4/11 mẫu URL hãng sai.** `STM32F411CE.svd` không tồn tại: tệp SVD mô tả một **die**, không
  mô tả một mã đóng gói — `STM32F411CE` (LQFP48) và `STM32F411RE` (LQFP64) dùng chung
  `STM32F411.svd`. `nrfx/mdk` cũng không còn tệp `.svd` nào. Cả hai trông hoàn toàn hợp lý
  trong YAML và `search.vendor` vẫn trả ứng viên — chỉ là mọi ứng viên đều 404.
- **`constant_guard` chặn coder ở tệp TEST.** Cho một fact vàng trong ngữ cảnh, mô hình chú
  thích `/* eide:fact f_… */` đúng dạng trong `src/` — tức prompt PRS-16 §3 làm được việc của
  nó. Rồi nó bị E5003 vì ba lần `0x76` trong tệp test do chính nó viết kèm. Mà một test khẳng
  định `dia_chi() == 0x76` đang **kiểm** giá trị chứ không **khai** nó: bắt nó trích dẫn cùng
  fact thì cả hai lấy số từ một chỗ và test không còn kiểm gì. [DEV-064](DEVIATIONS.md).
- **`doc.section` phạt mô hình vì nó trung thực.** Hỏi về một module chưa có fact, mô hình trả
  lời *"chưa có dữ liệu trong ngữ cảnh được cung cấp"* — đúng điều ta muốn — rồi bị E5002 vì
  không có trích dẫn. Một câu trung thực "không có dữ liệu" thì không thể có trích dẫn, và bắt
  nó phải có là **dạy mô hình bịa cho đủ**.

**Bốn mươi tám lỗi im lặng, mỗi cái tìm ra bằng một cách khác nhau:**

1. **Niêm store lệch sau mỗi phiên bình thường** — `req.*`/`arch.*`/`extract.*` ghi vào bảng
   có niêm mà không niêm lại. Cảnh báo "store bị sửa ngoài EIDE" luôn đỏ, và cảnh báo luôn đỏ
   thì người ta tắt đi. Tìm ra bằng `nghiem_thu_sprint2.sh`.
2. **Thang điểm FTS bị đảo ngược từ Sprint 2** ([DEV-058](DEVIATIONS.md)) — thứ hạng vẫn đúng
   nhờ `ORDER BY` nên không ai thấy, cho tới khi có ai dùng điểm làm *ngưỡng*.
3. **Một mục DEVIATIONS biến mất khỏi báo cáo đồng bộ** — nội dung chứa `|`, vốn là dấu ngăn
   cột Markdown. Chủ sản phẩm duyệt một danh sách và tin nó đầy đủ.
4. **`_doc_do_thi` mất một nửa số cạnh** — 305 dòng cạnh chỉ ra 153 cạnh, nên kiểm kích thước
   lược đồ không bao giờ nổ.
5. **Ngưỡng cứng R4 chặn cả lối danh sách trắng mà bốn tài liệu đều mô tả.** APD-08 ghi "hành
   động lớp R4 không tự động — *trừ danh sách trắng do người ký*"; POL-17 §2 viết
   `MIN_LEVEL["R4"] = 5  # chỉ whitelist`; POL-17 §8 S33 và CDS-12.3 ENV-03 nói cùng điều. Hiện
   thực chặn cứng mọi R4, nên `G-OPS-04` là quy tắc chết và không gói tin cậy nào cài được tự
   động. Nằm im vì `tests/situations.py` dịch S33 với `risk="R2"` — trong khi năng lực DUY NHẤT
   có `op=install` là R4. Fixture chọn một lớp rủi ro không xảy ra được, và S33 xanh nhờ thế.
6. **Sandbox không ghi được vào chính thư mục làm việc của nó** (tìm ra 08/09 khi cho `brew`
   chạy qua `env.sandbox`). Hồ sơ `sandbox-exec` ghi `(subpath "/var/folders/…")` trong khi
   `subpath` so khớp trên đường dẫn ĐÃ GIẢI liên kết mềm — mà `/var` là liên kết mềm tới
   `/private/var`. Hệ quả: với mọi `out_dir` dưới thư mục tạm, tiến trình trong sandbox không
   ghi được vào đâu cả, kể cả `./a.txt`. **Không test nào thấy vì chưa test nào GHI** — cả bộ
   chỉ xem mã thoát của lệnh chỉ-đọc. Đây gần như chắc chắn cũng là lý do bốn bộ dựng lược đồ
   ngoài Graphviz (mục I2 của [CONG-VIEC.md](CONG-VIEC.md)) chưa nhánh nào chạy được.
7. **Ba hằng số thời gian chờ của sandbox chưa bao giờ có hiệu lực** (11/09). Bảy chỗ gọi trong
   `code.*`, `env.install` và `extract.*` truyền `limits={"timeout_s": …}`, nhưng `Sandbox` đọc
   khóa `wall_s`; `{**MẶC_ĐỊNH, **limits}` nuốt khóa lạ không một lời. Nên `TIMEOUT_DUNG = 600`,
   `TIMEOUT_CAI = 900`, `TIMEOUT_TEST = 120` đều là số trang trí, và MỌI lệnh chạy dưới hạn mặc
   định 300 s — kể cả `brew install gcc-arm-embedded`, vốn tải vài trăm MB và bị giết ở phút thứ
   năm với thông báo "quá thời gian 300 s" cho một lệnh mà mã nguồn nói rõ là được 900 s. Không
   test nào thấy vì **không test nào chạy đủ lâu để chạm hạn**. Vá bằng cách để `Sandbox` từ
   chối khóa lạ (E1000) thay vì gộp im lặng — cùng hình dạng với lỗi số 5: một cấu hình trông
   như đang có hiệu lực.
8. **`project.set_target` mất ISA với chính dạng tên chip mà bộ hồ sơ dùng** (11/09).
   `family_patterns` neo đầu chuỗi (`^STM32F[2-4]`) nên nó khớp `STM32F411CE` — ví dụ của
   PROJECT-06 — nhưng không khớp `st.stm32f411ce`, vốn là dạng IRI mà `extract.svd` sinh ra cho
   **mọi** hộ chiếu chip và cũng là ví dụ của SIM-01. Ghim bằng dạng IRI cho ra `isa: null`
   trong `constraints.yaml` mà không báo gì, rồi `code.build` dừng ở "chưa ghim ISA" — một câu
   đúng về triệu chứng và sai về nguyên nhân. Test cũ có ghim đúng dạng ấy, nhưng chỉ khẳng
   định phần hộ chiếu nên nhánh ISA không ai nhìn.
9. **"Xanh" của dự án nói về nửa kho** (11/09 đợt 2). `make check` gọi lint + spec + pytest +
   secrets + gen — toàn phía Python. Gói Swift đứng ở `make geditor`, một lệnh phải nhớ gõ tay.
   Từ 06/09 (lần dọn GEditor vào `apps/`) tới 11/09, `swift test` đỏ **hai bài** mà cổng chính
   vẫn xanh. Cả hai là test mục rữa: một bài đòi sách trợ giúp rơi về tiếng Việt trong khi mã
   cố ý rơi về tiếng Anh kèm bốn dòng giải thích, và `de` thì nay đã có sách; một bài leo ba
   cấp thư mục để tìm tệp YAML thật, mà ba cấp ấy sau lần dọn chỉ còn **một** tệp. Bài thứ hai
   đáng nhớ hơn: nó không hỏng, nó **hết việc** — và một bài test hết ngữ liệu thì im lặng y
   như một bài test sai. Vá bằng cách đưa `check-swift` vào `check`, vì một cổng phải tự chạy
   thì mới là cổng.
10. **Danh sách trắng TẢI VỀ bị dùng làm thước đo CHẤT LƯỢNG** (11/09 đợt 2,
    [DEV-087](DEVIATIONS.md)). `search.rank` cộng "+2 domain tin cậy" bằng cách tra
    `trusted_sources` — danh sách bảy tên miền trả lời câu *"có được tải tự động không"*, cần
    chữ ký chủ sản phẩm để đổi. Xếp hạng thì hỏi câu khác hẳn: *"nguồn này đáng tin tới đâu"*,
    vốn là việc của bảng 12 hãng trong TGT-19 §8. Hệ quả: **một hãng vắng mặt trong danh sách
    tải-về thì vĩnh viễn không được +2, kể cả trên trang datasheet của chính nó.** Điều giữ nó
    im lặng là một biên MỘT điểm: `allegromicro.com` thắng diễn đàn nhờ +2 *khớp mã linh kiện*,
    trong khi docstring của cả `_tang_du_kien` lẫn bài test đều ghi "trang hãng thắng vì TẦNG
    khác nhau" — và tầng thì đang NGƯỢC (mirror gold, trang hãng silver, vì TGT-19 §8 xếp SVD
    trên PDF). Thêm đúng một tên miền vào danh sách trắng (WI-257) là biên ấy mất, và câu nói
    sai bốn ngày mới lộ. Cùng họ với [DEV-058] (thang điểm FTS đảo ngược mà thứ hạng vẫn đúng
    nhờ `ORDER BY`): một bài test xanh vì lý do khác với lý do nó được viết ra.
11. **`code.build` chưa bao giờ dựng được trên bất kỳ máy nào** (11/09 đợt 3,
    [DEV-088](DEVIATIONS.md)). Ba tầng nối nhau, và mỗi tầng chỉ lộ sau khi tầng trước được vá:
    tên trần trong sandbox `PATH` bốn thư mục → thư mục làm việc tạm trong khi `build.cmd` viết
    đường dẫn tương đối → và cuối cùng `cmake` đi tìm `ninja` qua `PATH`, thứ mà giải `argv[0]`
    không chạm tới được. Điều giữ cả ba im lặng là một chỗ trống rất cụ thể: **`test_code.py`
    kiểm đủ nhánh HỎNG của `code.build` — thiếu công cụ → E4001, chưa ghim ISA → E2000 — và
    không có nhánh THÀNH CÔNG.** Một bộ test chỉ biết nói "hỏng đúng cách" thì cũng nói thế trên
    một năng lực chưa bao giờ chạy đúng lần nào. Đây là lỗi đắt nhất trong mười một cái: nó nằm
    ở mắt xích trung tâm của luận điểm đề án, và nó sống sót qua cả Sprint 2 lẫn hai đợt trước
    của chính ngày 11/09.
12. **`gate.decision` không bao giờ được phát** (12/09). Router ghi quyết định vào bảng
    `decision_log`, và `store.py` loại bảng ấy khỏi niêm `content_digest` với lý do ghi thẳng
    trong chú thích: *"mọi quyết định cũng đi vào sổ cái"*. Nó không đi. Một bảng nằm ngoài
    niêm vì tin vào một đường ghi không tồn tại.
13–14. **`autonomy.change` và `stop` cũng vậy** (12/09). Hai hành động an toàn nhất trong cả
    sản phẩm — đổi mức tự chủ và dừng khẩn — không để lại vết nào trong chuỗi băm. Sau lần thứ
    ba của cùng một hình dạng lỗi, tôi thôi sửa từng cái và dựng một cổng cho cả lớp:
    `test_moi_kieu_su_kien_API15_deu_co_cho_phat_TRU_thu_can_board` bắt mọi `kind` khai trong
    API-15 §5 mà không có chỗ nào phát ra.
15. **Ô lệnh chưa bao giờ chạy một việc nào** (13/09). Panel gọi `chat.parse_intent` — bước 1
    trong 4 bước DPS-09 — nên người gõ "Tạo dự án robot" đọc được *"Tôi hiểu là: project.create
    (92%)"* rồi hết. Không chuỗi nào dựng, không việc nào chạy. UXD-13 §ô lệnh ghi hành động là
    `chat.send`, `chat.send` đã nằm sẵn trong daemon lẫn enum RPC sinh tự động, và panel chỉ
    đơn giản không gọi nó.

    Nhánh thứ hai của cùng lỗi ấy đo được bằng một con số: menu "/" liệt kê **199** năng lực có
    màn hình, người chọn một cái, rồi cú Enter ném `/passport.query st.stm32f411` vào bộ đoán ý
    — nơi enum DPS-09 §4.1 có 19 intent và đúng **một** (`sim.run`) trùng tên với một trong 199
    năng lực ấy. 198 cái còn lại không có đường nào tới đích.

    Điều giữ nó im lặng là một tính chất của chính bộ đoán ý: **`parse_intent` luôn trả về *một*
    intent với *một* độ tin cậy**, kể cả cho một chuỗi nó không hiểu. Nên màn hình luôn hiện
    "Tôi hiểu là: …", và một giao diện hiểu mọi thứ mà không làm gì trông giống hệt một giao
    diện đang làm việc. Bốn màn có từ trước không phát hiện ra vì cả bốn chỉ ĐỌC trạng thái;
    lỗi chỉ lộ khi có một màn phải GỌI một năng lực.
16. **`as? Int` trả `nil` trong im lặng** (13/09, phía Swift). `debug.log_stats` trả
    `gaps: [{after_line: 128004, before_line: 128005, gap_s: 47.2}]`. Swift thấy một `Double`
    trong cùng object nên suy cả dictionary thành `[String: Double]`, và `as? Int` trên
    `after_line` trả `nil` — không lỗi, không cảnh báo, chỉ một số 0.

    Triệu chứng là thứ đáng sợ hơn một lần crash: màn hình hiện "khoảng lặng 47,2 giây giữa
    dòng 0 và dòng 0", và người dùng mở log ở dòng 0 — một chỗ không phải chỗ hệ thống treo.
    Con số 47,2 thì đúng, nên cả dòng đọc lên hoàn toàn đáng tin.

    Nguyên nhân gốc không phải Swift mà là **JSON không phân biệt số nguyên với số thực, còn
    các cầu nối thì có**: `JSONSerialization` trả `NSNumber`, một `47.2` đứng cạnh một
    `128004` đủ để kiểu của cả hai đổi. Sửa bằng `EideSo.nguyen`/`thuc` chịu được cả Int,
    Double, NSNumber lẫn String, và thay mọi chỗ đọc số từ kết quả `caps.invoke` trong cả sáu
    tệp khung nhìn. Bắt được vì một bài test dựng dữ liệu đúng hình dạng dữ liệu thật — chứ
    không phải hình dạng thuận tay người viết test.
17. **Màn mở ra khẳng định điều nó chưa kiểm** (13/09). `hienKhung` chỉ hiện khung nhìn, không
    hỏi daemon câu nào, nên gõ `/project.status` cho ra màn Tổng quan hiện *"Chưa mở dự án
    nào"* — trong khi dự án đang mở. Câu ấy không thiếu, nó **sai**. Chữa bằng một trạng thái
    thứ ba: U9 kể ba trạng thái rỗng/lỗi/chờ, nhưng một màn vừa mở không thuộc cái nào — nó
    *chưa hỏi*.
18. **Client nuốt mất mọi câu trả lời của `caps.invoke`** (13/09). `serve_stdio` phát `event.*`
    ngay trong lúc xử lý, trên cùng ống dẫn; `EideClient.goi` đọc đúng MỘT dòng rồi coi nó là
    câu trả lời. Nó nhận lấy thông báo đầu tiên, thấy không có `result`, và trả về `[:]`.

    Đây là lỗi đắt nhất trong bốn cái của ngày 13/09: **mọi lời gọi năng lực từ panel đều trả
    rỗng** — không lỗi, không treo, chỉ một từ điển trống, và mọi màn hình hiện "chưa có dữ
    liệu". Nó sống sót vì test client cũ chỉ gọi `plane.hello` và `caps.list`, hai phương thức
    duy nhất trong 57 cái **không sinh sự kiện nào**. Và trớ trêu nhất: chính chú thích của tôi
    trong `serve_stdio` viết *"panel thấy `event.run.progress` rồi mới thấy kết quả, và đó là
    thứ tự người dùng cần"* — mô tả đúng một hành vi mà phía kia không xử lý được.
19. **Kênh sự kiện chưa từng có người nghe** (13/09). `EidePanel.hienCauHoi` là `public`, có
    test, và không chỗ nào gọi nó. Daemon phát `event.chat.question` mỗi lần một năng lực cần
    người chọn, nên thẻ câu hỏi gộp của U3 không bao giờ hiện ra: người dùng thấy việc dừng lại
    mà không thấy câu hỏi.
20. **`caps.describe` và `caps.list` nói hai thứ khác nhau về cùng một năng lực** (13/09).
    `describe` trả `spec.__dict__`, tức trường `ui` THÔ — mà `cds.json` không khai `ui` cho năng
    lực nào (0/238, DEV-046) — nên nó trả `""` cho cả 238 cái, trong khi `caps.list` đọc
    `spec.man_hinh` và trả tên màn đầy đủ. Panel định tuyến theo `caps.list` nên vẫn chạy; ai
    hỏi `describe` — MCP, một IDE khác, một bài test E2E — đều được trả lời rằng năng lực này
    không thuộc màn hình nào.

21. **Màn tự nạp một thứ nó không đọc được** (13/09). Màn Hộ chiếu nạp mặc định bằng
    `passport.list`; năng lực ấy trả `{passports}`, còn `PassportView` đọc `{facts}`. Mở màn ra
    là hiện *"Không có fact nào cho mã này"* — **sau khi vừa nhận một danh sách hộ chiếu đầy
    đủ**. Màn Graph cũng thế: nạp `view.kg_map` (trả `{graph}`) rồi `RagAskView` kết luận
    "Không tìm thấy gì trong tri thức của dự án".

    Cùng hình dạng với lỗi 17, chỉ khác một điểm quan trọng: lần này khung nhìn **đã hỏi** — nó
    chỉ không hiểu câu trả lời. Và nguyên nhân là của tôi: `napMacDinh` chọn theo trực giác
    "màn này thì nạp năng lực kia" mà không kiểm khung nhìn đọc gì. Đo lại cả danh sách
    `napAnToan` 11 mục: **chỉ 4 dùng được**; 5 câm, 2 trỏ vào màn không có khung nhìn. Bảy mục
    ấy nay nằm trong `EidePanel.noUI` — một đơn đặt hàng UI, không phải rác cần dọn.

    `EideNapMacDinhTests` giữ điều này bằng cách **đọc chính mã nguồn khung nhìn** để lấy tập
    khoá nó dùng, rồi giao với `output_schema` do daemon phát ra. Một danh sách gõ tay sẽ lệch
    đi ngay lần đầu ai đó thêm một trường — và lệch theo hướng làm test xanh.

22. **Hàm dựng đặc trưng chưa bao giờ được gọi** (13/09). `@capability(..., dac_trung=fn)` cho
    một năng lực tự tính đặc trưng cổng từ tham số lời gọi — `search.fetch` khai nó để nói với
    G-SRC nguồn này là gì, `env.install` khai nó để nói với G-OPS gói nào sắp cài. Registry giữ
    hàm ấy tử tế trong `Registered.dac_trung`, và **Router không gọi**. Cổng vì thế luôn nhìn
    một `features` rỗng và luôn rơi xuống quy tắc bắt hết. Không test nào thấy vì mỗi bên đều
    được test riêng: registry có test giữ được hàm, PolicyGate có test quyết định đúng với
    đặc trưng cho sẵn — và không ai kiểm rằng đặc trưng đi được từ bên này sang bên kia.

23. **Duyệt xong bị hỏi lại chính câu vừa trả lời** ([DEV-100](DEVIATIONS.md), 14/09). Nhánh
    nhường cho `actor == "human"` nằm ở tầng 5 của `PolicyGate.decide`, mà tầng 5 chỉ tới khi
    KHÔNG quy tắc nào khớp — trong khi một mục vào hàng đợi thì gần như luôn vì một quy tắc ASK
    ở tầng 3/4 vừa khớp. `eide queue approve` vì thế chạy lại lời gọi, gặp lại đúng quy tắc ấy,
    và trả về "CHỜ NGƯỜI" với một run_id mới. **Hàng đợi U2 không đóng được mục nào.**

    Docstring của `Router.quyet_dinh` mô tả đúng hành vi mong muốn — "lời gọi không quay lại
    hàng đợi một lần nữa" — nên đọc mã thì thấy yên tâm. Và test giữ điều ấy (`test_hang_doi::
    test_duyet_thi_chay_tiep_khong_hoi_lai`) xanh suốt vì nó dùng `kg.resolve_conflict`, một T2
    gắn cổng `*`: **đúng ca duy nhất rơi xuống tầng 5**. Cùng khuôn với lỗi số 5 — fixture chọn
    trúng trường hợp ngoại lệ, rồi chứng minh cho một tình huống không xảy ra trong đời thật.

24. **`sim.cmd` của manifest ISA chưa bao giờ tới engine** ([DEV-101](DEVIATIONS.md), 14/09).
    `_argv` dựng dòng lệnh qemu bằng tay; `docs/spec/isa/rv32imac.yaml` khai
    `qemu-system-riscv32 -M virt -nographic -bios none -kernel {artifact}` và không ai đọc.
    Thiếu `-bios none`, máy `virt` nạp OpenSBI ở 0x80000000 — đúng chỗ linker script đặt
    firmware — nên lượt chạy chết bằng *"Some ROM regions are overlapping"*, một thông báo trỏ
    thẳng vào người viết firmware. Nằm im vì armv7e-m và avr8 **không khai `sim.cmd`**: với
    chúng hai đường trùng nhau, và manifest thứ ba là lần đầu tiên chúng tách ra.

25. **`-p .` làm sandbox không thấy tệp có thật** ([DEV-102](DEVIATIONS.md), 14/09). CLI không
    tuyệt đối hoá `--project`, nên `project_dir = Path(".")` và mọi đường dẫn dựng từ đó cũng
    tương đối. Trong tiến trình thì không sao — thư mục hiện hành đúng là dự án. Nhưng sandbox
    của SEC-25 §2 đổi thư mục làm việc, nên `qemu … -kernel ./build/fw.elf` báo *"No such file
    or directory"* cho một tệp có thật, và câu ấy đổ lỗi cho tệp chứ không cho đường dẫn. Đi
    đúng ví dụ đường dẫn mà hợp đồng SIM-05 viết, và đúng cách gõ tự nhiên nhất từ trong dự án.

26. **Danh sách trắng nguồn cho phép đúng bốn thứ, và không thứ nào là trang hãng**
    ([DEV-103](DEVIATIONS.md), 14/09). `trusted_sources` khớp CHÍNH XÁC chuỗi tên miền và chứa
    tên miền trần (`st.com`, `microchip.com`); bảng nguồn hãng TGT-19 §8 thì dùng subdomain
    thật (`www.st.com`, `packs.download.microchip.com`). Đối chiếu hai tệp: **4/12 mẫu URL tải
    tự động được, cả bốn đều là `raw.githubusercontent.com`**. `microchip.com` và
    `nordicsemi.com` là mục CHẾT — không mẫu nào dùng tên miền trần ấy, nên chữ ký của chủ sản
    phẩm trên hai dòng đó chưa bao giờ cho phép tải được gì.

    Sống được qua **ba lần ký danh sách** vì hai luồng đã chạy trước đó (STM32, ESP32-C3) đều
    đi qua `raw.githubusercontent.com` — đúng bốn mục xanh. Luồng AVR là luồng đầu tiên cần một
    trang hãng thật, và nó dừng ngay ở nguồn đầu tiên.

27. **`build.cmd` của manifest chạy nguyên văn, placeholder thành chữ** ([DEV-104](DEVIATIONS.md),
    14/09). `avr8` khai `make -C . MCU={mcu} F_CPU={f_cpu}`, và `code.build` truyền cho `make`
    một biến `MCU` mang đúng năm ký tự `{mcu}`. TGT-19 dùng placeholder ở khắp nơi — `flash.cmd`,
    `id_read.cmd`, `sim.cmd` — và mọi chỗ dùng đều tự giải; `build.cmd` là chỗ duy nhất không.
    Cùng bẫy đã gặp 13/09 với `{march}` của rv32imac, lần ấy chữa bằng cách bỏ placeholder khỏi
    manifest — tức chữa triệu chứng, nên bẫy còn nguyên cho manifest tiếp theo.

28. **Ngưỡng phiên bản loại đúng chuỗi công cụ mà người dùng thật sự có**
    ([DEV-105](DEVIATIONS.md), 14/09). `avr-gcc.min = 12.0` trên macOS chỉ đạt được qua tap
    `osx-cross/avr`, mà Homebrew mới đòi `brew trust` — một quyết định bảo mật về máy người
    dùng. Chuỗi công cụ chính thức của Arduino (avr-gcc 7.3.0, avrdude 8.0, không cần trust)
    dựng ATmega328P hoàn toàn tốt: 650 B flash, 6/6 dòng expect đạt trong qemu. Ngưỡng ấy đổi
    một tính chất không dùng tới lấy việc loại cả nền tảng. Gốc rễ: TGT-19 §2 ghi MỘT ngưỡng
    cho cả ISA, mà avr8 gồm cả ATtiny1616 (AVRxt/UPDI, cần ≥8) lẫn ATmega328P (7.3 là đủ) —
    một ngưỡng chung buộc phải lấy con số của chip khó nhất.

29. **`env.check` đọc phiên bản từ TÊN THƯ MỤC CÀI ĐẶT** ([DEV-106](DEVIATIONS.md), 14/09).
    `avrdude --version` trả mã thoát **0** nhưng in `"…/avrdude/8.0.0-arduino1/bin/avrdude:
    illegal option -- -"`; `avrdude -v` trả mã **1** nhưng in đúng dòng phiên bản. `version_of`
    lấy dòng đầu bất kể lệnh có chạy được không, rồi `_ver_ok` tìm `(\d+)\.(\d+)` trên cả chuỗi
    và thấy `8.0.0` — **trong đường dẫn nằm trong chính thông báo lỗi**. Kết luận: `ok: true`,
    `version` là một câu báo lỗi.

    Lần này con số tình cờ đúng vì Arduino đặt tên thư mục theo phiên bản. Lần sau ai cài một
    avrdude 6.3 vào thư mục tên `8.0.0` thì EIDE vẫn khẳng định đạt — và ENV-02 nói nó "so `min`
    theo semver" trong khi thứ được so không phải semver của công cụ. Cũng đáng ghi: mã thoát
    **không dùng làm tín hiệu được**, lọc theo nó thì nhận chuỗi rác và bỏ chuỗi thật.

30. **Phát lại sổ cái làm TREO chính daemon** (14/09). Tính năng giám sát bản đầu cho daemon
    tự phát 200 bản ghi cuối ngay trong `__init__`. stdio là một ống có đệm hữu hạn — 64 KB
    trên macOS — còn client chỉ đọc khi đang chờ câu trả lời của một lời gọi. Phát một khối lớn
    trước khi client gửi gì là ghi vào một ống không ai đọc, và `write` chặn vĩnh viễn ở đó.

    Đo: dự án AVR 108 sự kiện ≈ 55,7 KB (sát ngưỡng); ESP32-C3 ≈ 82 KB — **vượt**. Triệu chứng
    nhìn từ ngoài là một cửa sổ mở lên rồi đứng im: không lỗi, không thông báo, và nhãn tự chủ
    đứng ở giá trị khởi tạo `…`. Tôi mất một lúc đi tìm trong phía Swift trước khi nghĩ tới ống.

    Bài học không phải "đừng đẩy nhiều": kênh đẩy và kênh hỏi-đáp có **ràng buộc khác nhau**, và
    một khối lớn phải đi bằng đường hỏi-đáp. Lịch sử nay đi qua `view.timeline` — năng lực vốn
    đã có sẵn cho đúng việc ấy (VIEW-12, `ref: memory.ledger`).

31. **Giao diện chạy một chính sách KHÁC CLI trên cùng một dự án**
    ([DEV-108](DEVIATIONS.md), 14/09). `Daemon` dựng `PolicyGate()` trần: không đọc
    `.eide/autonomy.yaml`, không đọc niêm `.eide/policy.sig`. `cli._router` đọc cả hai từ đầu.
    Đo trên dự án AVR: tệp ghi `autonomy: A2`, CLI áp A2, cửa sổ EIDE hiện "—" và quyết định
    theo mặc định toàn cục.

    Hai nguồn sự thật cho cùng một câu hỏi, và cái người dùng **nhìn thấy** là cái sai. Nặng
    hơn ở phần niêm: `eide policy sign -p <dự án>` ghi ra `.eide/policy.sig`, mà daemon đọc
    `defaults.sig` — nên chữ ký của chủ sản phẩm trên dự án ấy chưa bao giờ có hiệu lực trong
    giao diện.

32. **Mở màn từ sidebar thì màn nào cũng rỗng** ([DEV-108](DEVIATIONS.md), 14/09).
    `_moTheoTenMan` không hỏi `napMacDinh`; nó chỉ xử lý `FlowMap` và `Models`, còn 20 màn kia
    nhận câu "Màn X chưa có nguồn dữ liệu" — một câu vừa sai vừa nghe như lỗi của người dùng.

    `napMacDinh` thêm ngày 13/09 để sửa lỗi im lặng số 21, và nó ĐÚNG — chỉ là nó chạy ở đường
    `_napLaiManDangMo`, tức chỉ khi một sự kiện `knowledge.changed` tới. Hai đường vào cùng một
    màn, một đường nạp dữ liệu, một đường không; và đường người dùng thật sự đi là đường thứ
    hai. Cùng họ với 22–25: **một bên khai, bên kia không đọc** — lần này hai bên đều là mã của
    chính tôi, cách nhau một ngày.

33. **Dòng "xong" trên nhật ký không nói xong CÁI GÌ** (14/09). `cap.run.start` mang `cap`,
    `cap.run.finish` thì không — nên dòng thời gian hiện "kg.conflicts bắt đầu" rồi "? xong".
    Ghép theo `run_id` ở phía giao diện cũng không cứu được, vì lịch sử chỉ nạp 200 bản ghi
    cuối và dòng `start` tương ứng có thể đã bị cắt. Sửa ở nguồn: cả bốn nhánh kết thúc —
    done, failed, pending, rejected — nay đều mang tên năng lực, và có test quét mã để không
    nhánh nào bị bỏ sót lần sau.
34. **`undo.list` chết vì một bản ghi do CHÍNH nó ghi ra tháng trước** (15/09). Sổ cái là
    append-only, nên nó chứa bản ghi của mọi phiên bản mã từng chạy — kể cả các bản ghi ra
    trước khi trường `cap` được thêm vào. `undo.list` đọc `m["cap"]`, gặp một bản ghi cũ thì
    nổ `KeyError` và người dùng nhận E1000 "lỗi nội bộ". Không test nào thấy vì test nào cũng
    chạy trên một sổ cái vừa tạo — tức một sổ cái chỉ có bản ghi của phiên bản mã hiện tại.
    **Sổ cái càng sống lâu càng dễ hỏng, và test thì luôn trẻ.** Sửa bằng `.get()` cho mọi
    trường thêm sau, và khoá sắp xếp `x["at"] or ""` để một bản ghi thiếu mốc thời gian không
    kéo cả lời gọi xuống theo.
35. **Hai lời gọi song song làm TREO client, vĩnh viễn** (15/09). `EideClient` là `actor`, và
    tôi đã tin rằng actor tuần tự hoá cả hàm. Nó không: actor tuần tự hoá phần mã **giữa các
    điểm treo** — tới `await` là nó nhả quyền cho lời gọi khác vào. Nên hai lời gọi cùng lúc
    đều ghi vào stdin rồi cùng đọc stdout, mỗi bên nhận câu trả lời của bên kia; cả hai chờ
    một phản hồi không bao giờ tới. Trong giao diện thì đây là một màn đứng im mãi mãi, không
    lỗi, không xoay. Bản sửa ĐẦU của tôi cũng sai — nối các lời gọi bằng `Task`, trong khi
    `Task` hoàn tất khi thân nó **chờ xong**, không phải khi việc xong. Bản đúng là một mutex
    bất đồng bộ dựng bằng `CheckedContinuation`. Test bắt được: 0,314 giây thay cho 10 phút
    treo.

**Số 18–21 có chung một đặc điểm:** chúng đều nằm ở **chỗ nối giữa hai phần đã được test kỹ**.
Khung nhìn có test, client có test, daemon có test, hợp đồng có test — và cả bốn lỗi sống trong
khoảng giữa chúng, nơi không bài test đơn vị nào đi qua. Đó là lý do bộ E2E (`EideE2ETests`) ra
đời ngày 13/09: nó gọi daemon thật, chạy năng lực thật, rồi đưa kết quả thật vào khung nhìn
thật — và nó bắt được cả bốn trong một buổi.

**Số 30–33 đến từ việc BẬT GIAO DIỆN LÊN và bấm thử.** Cả bốn đều nằm ngoài tầm của mọi bộ
test đang có — không phải vì test yếu, mà vì chúng sống ở những chỗ chỉ tồn tại khi sản phẩm
chạy thật: một ống stdio có đệm hữu hạn, một tiến trình con đọc cấu hình của dự án, một cú bấm
chuột vào hàng thứ 22 của sidebar. Ba lượt `make check` xanh liên tiếp ngay trước đó.

36. **`kg.conflicts` không phát ra khoá mà `kg.resolve_conflict` bắt buộc phải có** (15/09).
    KG-06 nhận `conflict_id` dạng `<fact_a>:<fact_b>`, và docstring của nó còn ghi "cặp mà
    `kg.conflicts` trả về" — trong khi `kg.conflicts` không trả. Nút "Chọn A" trên giao diện gửi
    `"?"` và luôn hỏng; `view.conflict_board` thì tự đánh số `c_001`, một khoá không truyền vào
    đâu được. **Mỗi bên có test riêng và cả hai cùng xanh** — không bài nào hỏi câu "hai cái này
    có khớp nhau không". [DEV-112](DEVIATIONS.md).
37. **Tiến trình con trong sandbox ĂN MẤT ống JSON-RPC của daemon** (16/09). `subprocess.Popen`
    chuyển hướng stdout và stderr vào tệp nhưng KHÔNG chuyển hướng stdin, nên
    `qemu-system-avr` — vốn đọc stdin như console nối tiếp — thừa kế stdin của daemon, tức chính
    ống lệnh từ giao diện. Triệu chứng: `sim.run` qua daemon không bao giờ xong, trong khi cùng
    lời gọi ấy qua CLI mất 25 giây. Đây còn là một lỗ SEC-25: stdin thừa kế là một kênh vào
    KHÔNG khai báo, và bất kỳ công cụ nào đọc stdin đều rút được lưu lượng RPC của tiến trình
    cha. [DEV-116](DEVIATIONS.md).
38. **Ngân sách ngày không tính bảy tiếng đầu mỗi ngày** (16/09). Sổ cái đóng dấu `ts` bằng UTC;
    `budget_state` so với `date.today()` — giờ ĐỊA PHƯƠNG. Ở +07, mọi `model.call` từ nửa đêm
    tới 7 giờ sáng rơi vào ngày UTC hôm trước và **không được cộng vào chi tiêu hôm nay**. Không
    phải chuyện hiển thị: APD-08 §5 leo thang khi còn dưới 20% ngân sách, nên bộ đếm đọc 0 suốt
    bảy tiếng là bộ đếm không bao giờ chạm ngưỡng trong bảy tiếng ấy. Tìm ra vì buổi làm việc
    này kéo qua nửa đêm và bốn bài test đỏ lúc 06:55.
39. **Hội thoại BỊ ẨN vẫn giữ nguyên chiều cao** (16/09). `isHidden = true` không lấy lại chỗ
    trong Auto Layout, mà mép dưới của MỌI màn chuyên đề buộc vào mép trên hội thoại — nên mỗi
    màn mất phần dưới đúng bằng chiều cao hội thoại, trong khi nửa dưới cửa sổ trống trơn. Thấy
    ra ở màn Mô phỏng (khối log bị cắt ngang dòng đầu) nhưng nó đúng với cả 23 màn.
40. **Kết quả việc nặng bị bọc hai lớp** (16/09). `job.status` trả `result` là CẢ CapabilityRun
    (`asdict(run)`), client bọc thêm một lớp nữa, nên màn nhận `{status, result}` thay cho
    `{report}` và kết luận *"Mô phỏng không trả về kỳ vọng nào để hiện"* — sau một lượt chạy
    qemu 25 giây ĐẠT 6/6. Hợp đồng API-15 không nói `job.status.result` là phong bì hay thân,
    nên mỗi bên gọi tự đoán một kiểu.
41. **Đường nạp mặc định đổ kết quả vào khung nhìn SAI** (15/09). Nó chọn khung nhìn theo TIỀN
    TỐ MÀN, trong khi màn 7 có hai khung nhìn và phép định tuyến theo NĂNG LỰC mới là cái đúng.
    Hệ quả: `view.kg_map` rơi vào `RagAskView`, và màn hỏi đáp kết luận *"Không tìm thấy gì
    trong tri thức của dự án"* ngay sau khi hệ thống trả về 17 nút và 26 cạnh.
42. **Lệnh chọn màn mặc định hoãn lại ĐÈ LÊN lựa chọn thật** (15/09). `dungKhungEide` xếp một
    `DispatchQueue.main.async { chon("Code") }`; mọi lời gọi `chonManEide` đặt trước vòng run
    loop kế tiếp đều bị nó ghi đè. Bộ chụp ảnh gọi `chonManEide("Passport")` rồi chụp ra màn Mã
    nguồn, và không có gì trong log nói vì sao.
43. **`chayTuONhap` bỏ qua trong im lặng khi chưa có màn nào mở** (16/09). Đúng cho một ô nhập
    (ô nhập chỉ tồn tại khi có màn), sai cho một lời gọi bằng mã: lời gọi rơi vào hư không và
    ảnh chụp ra một màn trống. Nay `chayNhuNguoiDung` trả `false` để bên gọi biết.
44. **`/* eide:fact */` thành một fact tên `*/`** (16/09). Phép lấy "từ kế tiếp" ngây thơ trong
    trình đọc chú thích không kiểm dạng id, nên một chú thích viết dở sinh ra một id rác — và cú
    bấm vào dòng ấy gửi nó thẳng vào `passport.query`. Chú thích viết dở là chuyện thường; biến
    nó thành một lời gọi vô nghĩa thì không.

45. **Màn Tổng quan đọc `features` và `gates_open` sai hình dạng** (16/09). `project.status`
    trả `features: {total, passing, failing}` (đếm sẵn) và `gates_open: 0` (một số); màn đọc cả
    hai như MẢNG, nhận `nil`, gán 0. Hợp đồng PROJECT-04 để `report` là object tự do với một
    dòng mô tả liệt kê tên trường — không nói trường nào là mảng — nên **không bên nào sai**;
    chúng chỉ không khớp nhau, và màn là bên thua. Cùng khuôn với 36.
46. **`env.detect` trả cổng serial và probe, màn Môi trường chưa bao giờ hiện chúng** (16/09).
    Màn rút đúng hai chữ `Darwin arm64` từ payload rồi bỏ phần còn lại — trong khi đó đúng là
    chỗ người dùng vào để hỏi *"máy có thấy board của tôi không"*. Riêng `driver_ok: false`
    (cổng CÓ mặt nhưng hệ điều hành chưa cho truy cập) là thứ đắt nhất bị giấu: người dùng nhìn
    thấy tên cổng trong Finder và không hiểu vì sao EIDE nói không nạp được.
47. **Nhật ký cắt còn 40 mốc trong 311** (16/09). Và phần bị cắt là phần CŨ — tức phần chứa lý
    do một thứ hôm nay đang sai. Cùng lúc ấy cột `by` (`human` hay `agent`) không hiện, trong
    khi *"cái này do tôi hay do nó làm"* là câu hỏi trung tâm của một công cụ tác tử.
48. **`Đích ?` trên một dự án đã ghim chip** (16/09). `project.status` gọi trường ấy là `chip`,
    `target.detect` gọi là `chip_id`/`id`; màn hỏi hai cái sau rồi rơi về `"?"`. Con chip mà mọi
    thứ khác trong dự án dựa vào hiện ra thành một dấu hỏi.

**Số 45–48 tìm ra bằng MỘT bài kiểm kê, không phải bằng mắt.** `--self-test EIDE` mở cả 23 màn
trên một dự án thật, đếm số dòng và số khối của từng màn, rồi in ra một bảng. Bốn màn có dữ liệu
mà vẫn hiện ít hoặc hiện sai lộ ra ngay trên bảng ấy. Bài kiểm kê chỉ khẳng định MỘT điều —
không màn nào được vừa rỗng vừa im — còn lại nó để người đọc bảng tự thấy. Đó là cách rẻ nhất
tìm ra chuyện "màn có dữ liệu nhưng hiện sai": một khẳng định cứng cho từng màn sẽ phải viết 23
lần và sai 23 kiểu.

**Số 36–44 đều đến từ MỘT việc: dựng lại sáu màn hình trên dữ liệu thật rồi NHÌN.** Không cái
nào lộ ra trong `make check`, và bốn cái (37, 39, 41, 44) sống ở chỗ hai phần đều đúng theo test
của riêng chúng. Đáng chú ý là ba cái nặng nhất — 37, 38, 39 — không phải lỗi giao diện: một
lỗ sandbox, một lỗi múi giờ trong bộ đếm ngân sách, và một hiểu sai về Auto Layout. Chúng lộ ra
ở giao diện vì giao diện là chỗ duy nhất chạy cả hệ thống cùng lúc.

**Số 34 và 35 nói hai điều về TUỔI và về ĐỒNG THỜI.** Cả hai đều bất khả thi với một bài test
đơn luồng trên dữ liệu mới: 34 cần một sổ cái già hơn mã đang chạy, 35 cần hai lời gọi chồng
lên nhau. Cả hai nay đều có test — một test ghi thẳng bản ghi kiểu cũ vào sổ, một test bắn hai
lời gọi song song và đặt hạn giờ. Điểm chung với 30–33: không cái nào lộ ra nếu chỉ chạy
`make check`.

**Số 22–25 nói thêm một điều nữa, và nó khó chịu hơn:** bốn cái này đều nằm ở chỗ **một bên
khai, bên kia không đọc**. Registry giữ `dac_trung` mà Router không gọi; manifest ISA khai
`sim.cmd` mà `_argv` không đọc; APD-08 khai người duyệt được ưu tiên mà `decide` xét nó quá
muộn; hợp đồng SIM-05 viết đường dẫn tương đối mà CLI không chuẩn hoá gốc. Không cái nào lộ ra
bằng một lời gọi đơn lẻ — cả bốn chỉ lộ khi **chạy hết một luồng thật từ đầu đến cuối**, và cả
bốn lộ trong cùng một buổi làm luồng ESP32-C3 (§6). Test đơn vị và test E2E trong-tiến-trình
đều không bắt được, vì cả hai vẫn hỏi "phần này có làm đúng việc của nó không" chứ không hỏi
"thứ phần này khai ra có tới được nơi cần dùng không".

**Số 26–29 đến từ luồng AVR ngày hôm sau, và chúng nói một điều khác nữa:** bốn cái này chỉ lộ
khi đi một luồng **trên nền tảng thứ hai**. Ba cái đầu (26, 27, 28) là những chỗ mà toàn bộ
công việc trước đó đi vòng qua mà không biết: hai luồng đã chạy đều tải nguồn từ
`raw.githubusercontent.com`, đều dùng manifest không placeholder, đều dùng chuỗi công cụ ARM.
Không phải chúng khó tìm — chúng nằm ngay trên đường, chỉ là chưa ai đi con đường ấy. Điều đáng
rút ra không phải "cần thêm test" mà **"cần thêm một luồng thật, trên một họ chip khác"**: mỗi
luồng mới đi qua một tập nhánh mà không luồng nào trước đó chạm tới, và nó tìm ra lỗi với tốc
độ mà không bộ test đơn vị nào sánh được — bốn cái trong một buổi, lần thứ hai liên tiếp.

---

## 7. Việc chờ chủ sản phẩm

**Chủ sản phẩm xác nhận toàn bộ ngày 16/09/2026.** Ba mươi mốt mục DEVIATIONS chuyển từ `Mở`
sang `Đã duyệt`; hai quyết định thiết kế đã chốt (DEV-114 giữ bảng màu sáng; DEV-117 GỘP chú
thích fact vào trình soạn thảo — đã hiện thực cùng ngày). Board chưa lắp, nên 22 năng lực và
bốn màn phần cứng vẫn chờ. Bảng dưới là phần CÒN LẠI sau lần duyệt ấy.


| Việc | Vì sao cần người |
|---|---|
| **WI-257** — chạy `eide policy sign` | **Dữ liệu đã sửa, chỉ còn chữ ký.** `defaults.yaml` nay có `raw.githubusercontent.com`; mã, test và [DEV-087](DEVIATIONS.md) đã xong. Nhưng `eide policy sign` **cố ý là LỆNH chứ không phải năng lực** — trong 238 năng lực không có `policy.sign`, vì năng lực thì Router gọi được, tức tác tử gọi được, tức tác tử tự cấp quyền cho chính nó. Tình huống S47 nói thẳng: *"tác tử tự thêm một tên miền vào `trusted_sources`" → REJECT G-WL-02*. Chưa ký thì PolicyGate **bỏ hẳn ba danh sách** và mọi thứ rơi về ASK — đo được: 19 test đỏ, tất cả cùng một nguyên nhân. Đã kiểm trên bản sao đã ký (`EIDE_SPEC_DIR`, không đụng niêm thật): **1352 xanh**. Lệnh: `.venv-arm/bin/python -m eide.cli policy sign --by "Vũ Trí Công"` |
| **[DEV-089]** ký lại `trusted_packages` | Danh sách ghi `gcc-arm-none-eabi` — tên gói **apt**. Homebrew và `armv7e-m.yaml` đều dùng `arm-none-eabi-gcc`, nên `env.install` cho trình dịch ARM rơi vào **ASK**, còn mục đang có thì APPROVE một gói không tồn tại trên máy nào. Đúng hình dạng WI-257, ở nhóm gói. Nằm trong niêm nên phải `eide policy sign` lại |
| **[DEV-088]** SEC-25 §2/§3 | Lõi sandbox nay nhận `cwd` và `them_path` — hai thứ SEC-25 không khai. Không có chúng thì `code.build` **không thể thành công trên bất kỳ máy nào**. Đề xuất §3 ghi rõ `PATH` gồm cả thư mục chuỗi công cụ đã khai trong manifest ISA |
| ~~**WI-258**~~ | ~~Xác nhận đỏ PTIT chính thức~~ — **xong 16/09**: chủ sản phẩm đưa `docs/logo-ptit-1.svg`, bảng màu nay lấy từ chính tệp ấy. `primary` `#BC2626` (đỏ CHỮ của logo, tương phản 5,63), `brand` `#DE221A` (đỏ hình, 4,46 — chỉ cho mảng lớn), `secondary` `#373D4E`. Biểu tượng vào icon ứng dụng, thanh trên và hộp Giới thiệu. [DEV-118](DEVIATIONS.md) |
| **[DEV-114]** bảng màu TỐI | EIDE ghim `.aqua` từ 15/09 vì token PTIT là hằng số sáng cố định còn control AppKit đổi theo hệ thống — trên máy để chế độ tối thì ô nhập và hàng xen kẽ là những khối đen đặc. Ghim là cách đúng với tài liệu ĐANG CÓ (UXD-13 khai đúng một bảng màu), nhưng "EIDE không có chế độ tối" là một quyết định thương hiệu, không phải quyết định kỹ thuật |
| **[DEV-117]** hai bề mặt cùng tên "Mã nguồn" | Trong cửa sổ gộp, mục sidebar "Mã nguồn" là TRÌNH SOẠN THẢO (DEV-098), còn khung nhìn có chú thích fact ở lề chỉ tới được bằng cách gõ một năng lực `code.*`. Cần chốt một trong hai: gộp chú thích fact vào chính trình soạn thảo (đúng mockup, nhưng đụng vào lõi soạn thảo), hay tách tên hai màn |
| **[DEV-112]…[DEV-117]** sáu mục giao diện | Sinh ra từ đợt dựng lại 15–16/09. Không mục nào chặn việc đang chạy; chúng chờ duyệt để đồng bộ UXD-13, API-15 và SEC-25 §2 với thứ mã đang làm |
| ~~**[DEV-086]**~~ | ~~thêm `fallback: qemu` cho `avr8.yaml`~~ — **anh duyệt 11/09, đã xong.** TGT-19 lên v1.2, SIM-20 lên v1.1, và nhóm `sim.*` có lượt chạy engine thật đầu tiên (§5) |

---

## 8. Việc tiếp theo đề xuất

**Khối F1 đã đóng phần M3 của `sim.*`** (11/09): `build_platform`, `mock_peripheral`,
`model_plant`, `scenario`, `run`, `sweep` — 44 test. `compare_hil` là M4 vì nó cần một báo cáo
HIL thật, tức cần board.

Điều đáng nói nhất của khối này không phải sáu năng lực mà là **một bất biến**: không kỳ vọng
nào được coi là ĐẠT nếu không có kênh quan sát cho nó. Một dòng `expect` mà engine hiện có không
nhìn thấy được trả `unverified` kèm lý do, và một kịch bản có dù một dòng `unverified` thì
`passed = false`. Cái giá phải trả là nhiều kịch bản hôm nay sẽ không bao giờ xanh. Đổi lại:
`sim_first` dùng chính con số ấy để cho phép nạp firmware lên board, nên một `passed=true` dựa
trên những dòng chưa ai kiểm là đúng thứ cơ chế ấy sinh ra để chặn.

Mười chín mục M2 còn lại vẫn chia làm đúng hai nhóm, cả hai chờ điều kiện bên ngoài:

| Nhóm | Số | Chặn bởi |
|---|---|---|
| `discover.*` 8 · `target.*` 5 · `bench.*` 3 | 16 | **Board thật** — quyết định chủ sản phẩm 08/09 là để cuối cùng |
| `extract.ocr` · `image_schematic` · `image_board` | 3 | **Đường ảnh cho Gateway** — `models.yaml` khai vai trò `cartographer` với `inputs: [image]` nhưng `Gateway.run` chỉ nhận văn bản. Mở nó cũng gỡ nốt [DEV-076] và [DEV-079] |

Bốn hướng đi tiếp, theo thứ tự tôi đề xuất:

1. ~~**Chuỗi công cụ ARM, rồi dựng thật một lần.**~~ **XONG 11/09 đợt 3** — xem §5. Việc kế
   thừa từ nó: **`scripts/nghiem_thu_sprint3.sh`** (mục I5 của [CONG-VIEC.md](CONG-VIEC.md)), nay
   viết được lần đầu vì đã có cả `code.build` thật lẫn `sim.*` engine thật — một kịch bản nghiệm
   thu đi hết từ một câu tiếng Việt tới một firmware chạy được trên máy ảo.
2. **[DEV-083] kênh `var`/`gpio`** → nay là việc làm được, không còn là việc chờ. Trước 11/09 nó
   chặn vì *không engine nào chạy được*; giờ `qemu-system-avr` chạy và QEMU có sẵn gdbstub
   (`-s -S`), nên đọc biến là nối một client giao thức GDB-remote — không cần `avr-gdb`, vốn cũng
   không có trên máy. Đóng được nó là mở đường cho cả sáu năng lực `debug.*`, vốn đều đứng trên
   một lượt chạy mô phỏng **quan sát được**.
3. **Đường ảnh cho Gateway** → đóng nốt 3 năng lực M2 cuối cùng làm được trên máy, và gỡ hai
   nhánh đang treo ([DEV-076], [DEV-079]). Chạm lõi, cần khoá mô hình có thị giác để kiểm đường
   thật.
4. **`code.*` phần M3** (`annotate`, `docs`, `refactor`) và `doc.*`/`diagram.*` phần M3 — không
   bị chặn bởi gì, nhưng giá trị thấp hơn ba hướng trên.

Còn một món nợ cùng hình dạng với cả ba lỗi của phiên này, đã ghi ở mục I2 của
[CONG-VIEC.md](CONG-VIEC.md): **bốn bộ dựng lược đồ ngoài Graphviz chưa nhánh nào được thi
hành** (`mmdc`, `plantuml`, `d2`, `7z` đều chưa cài). Một đường mã chưa lần nào chạy thật là một
đường mã chưa ai biết có đúng không, bất kể bao nhiêu test giả lập xanh — đó chính là câu đã
đúng với `sim.*` cho tới hôm nay.

`registry.*` và `search.registry/reference_projects` (mốc M4) để sau: chúng cần một registry
thật để pull, và đó là hạ tầng ngoài phạm vi đề án.
