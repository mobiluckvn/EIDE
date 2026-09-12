# Tiến độ sản phẩm EIDE

*Cập nhật 13/09/2026 (lần 23). Số liệu **đo từ mã**, không gõ tay: `eide spec`,
`scripts/kiem_chuoi_chuan.py`, `pytest`. Tài liệu này sinh lại bằng cách chạy lại chúng —
đừng sửa số ở đây mà không chạy lại, vì con số gõ tay sẽ đúng đúng một ngày.*

> Đã xảy ra đúng như thế ngày 08/09: hai lần cập nhật liền nhau tôi CỘNG THÊM vào con số cũ thay
> vì đo lại, và tổng lệch 2 (ghi 122, thật là 124). Từ lần này mọi con số ở đây đều lấy từ một
> lượt đếm trên registry ngay trước khi ghi.

---

## 1. Một dòng

**209/238 năng lực (88%). M0 22/22; M1 74/75; M2 83/99; M3 21/29; M4 8/9. 1503 test Python +
2699 test Swift xanh. Nghiệm thu Sprint 2: 18/18; Sprint 3: 13/13.**

**Từ 13/09, MỌI thứ còn thiếu đều quy về một nguyên nhân: chưa có bo mạch.** Không còn mục nào
chờ thời gian, chờ một thư viện, hay chờ một quyết định. Đo trên mười trục của
[`DOI-CHIEU-THIET-KE.md`](DOI-CHIEU-THIET-KE.md):

| Còn thiếu | Chặn bởi |
|---|---|
| 29 năng lực (`discover` 12 · `target` 9 · `bench` 3 · `measure` 3 · `passport.verify_on_board` · `sim.compare_hil`) | board |
| 7 phương thức JSON-RPC (`serial.*`, `discover.status` và hai sự kiện của chúng) | board |
| 1 kiểu sự kiện sổ cái (`discover.result`) | board |
| 2 trong 3 mã lỗi chưa ném (`E4003` cần board; `E1003` cần một bề mặt REST chưa có) | board |
| phần lớn 27 mã TC còn lại | board / máy đo |

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
| Test Python | **1503** xanh, arm64 + x86_64 (`make check-py`) |
| Test Swift | **2699** xanh (`make check-swift`, nay nằm trong `make check` — WI-260). Trong đó **29** là EIDEKit, phần thuộc EIDE; còn lại là GEditor, ứng dụng chủ |
| Test GỌI THẬT | 10 mạng (`make check-net`) · 7 mô hình (`make check-llm`) · **1 engine mô phỏng** (`qemu-system-avr`) · **2 chuỗi công cụ ARM** (`arm-none-eabi-gcc` + `cmake`/`ninja`). Ba nhóm sau nằm trong `make check` và tự bỏ qua nếu máy không có công cụ |
| Nghiệm thu Sprint 1 / 2 / 3 | 17/17 · 18/18 · **13/13** |
| Mục DEVIATIONS | 89 tổng, **9 Mở** — 7 là nợ hiện thực chờ mốc/khối sau ([DEV-074] M5, [DEV-076] và [DEV-079] chờ D3 vision, [DEV-082]…[DEV-085] chờ kênh quan sát); **2 chờ chủ sản phẩm**: [DEV-088] (SEC-25 §2/§3) và [DEV-089] (ký lại `trusted_packages`) |
| Tài liệu | 35 tệp, khớp nguồn sinh từng khối (`make check`). Phiên này: **TGT-19 v1.2**, **SIM-20 v1.1** |

**Kiểm đột biến** dùng cho mọi nhóm năng lực: cố ý phá từng khẳng định rồi xác nhận test đỏ.
Nó đã bắt được nhiều test "xanh vì lý do khác với lý do nó được viết ra" — trong đó có test
SAFETY của `req.*`, ngưỡng 85% Flash của `arch.*`, hai lớp chặn DoS của `archive.unpack`, và
ngưỡng 0,35 của `view.rag_ask`.

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

**Mười một lỗi im lặng, mỗi cái tìm ra bằng một cách khác nhau:**

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

---

## 7. Việc chờ chủ sản phẩm

| Việc | Vì sao cần người |
|---|---|
| **WI-257** — chạy `eide policy sign` | **Dữ liệu đã sửa, chỉ còn chữ ký.** `defaults.yaml` nay có `raw.githubusercontent.com`; mã, test và [DEV-087](DEVIATIONS.md) đã xong. Nhưng `eide policy sign` **cố ý là LỆNH chứ không phải năng lực** — trong 238 năng lực không có `policy.sign`, vì năng lực thì Router gọi được, tức tác tử gọi được, tức tác tử tự cấp quyền cho chính nó. Tình huống S47 nói thẳng: *"tác tử tự thêm một tên miền vào `trusted_sources`" → REJECT G-WL-02*. Chưa ký thì PolicyGate **bỏ hẳn ba danh sách** và mọi thứ rơi về ASK — đo được: 19 test đỏ, tất cả cùng một nguyên nhân. Đã kiểm trên bản sao đã ký (`EIDE_SPEC_DIR`, không đụng niêm thật): **1352 xanh**. Lệnh: `.venv-arm/bin/python -m eide.cli policy sign --by "Vũ Trí Công"` |
| **[DEV-089]** ký lại `trusted_packages` | Danh sách ghi `gcc-arm-none-eabi` — tên gói **apt**. Homebrew và `armv7e-m.yaml` đều dùng `arm-none-eabi-gcc`, nên `env.install` cho trình dịch ARM rơi vào **ASK**, còn mục đang có thì APPROVE một gói không tồn tại trên máy nào. Đúng hình dạng WI-257, ở nhóm gói. Nằm trong niêm nên phải `eide policy sign` lại |
| **[DEV-088]** SEC-25 §2/§3 | Lõi sandbox nay nhận `cwd` và `them_path` — hai thứ SEC-25 không khai. Không có chúng thì `code.build` **không thể thành công trên bất kỳ máy nào**. Đề xuất §3 ghi rõ `PATH` gồm cả thư mục chuỗi công cụ đã khai trong manifest ISA |
| **WI-258** | Xác nhận đỏ PTIT chính thức (đang dùng `#B8121F` theo UXD-13 §7) |
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
