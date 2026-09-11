# Danh sách công việc EIDE

*Đo 11/09/2026 (lần 16) từ registry — không gõ tay. Còn **56/238** năng lực. Xem
[`TIEN-DO.md`](TIEN-DO.md) cho bức tranh trạng thái; tệp này trả lời **làm gì tiếp**.*

Sắp theo **thứ tự nên làm**, không theo số hiệu. Nguyên tắc sắp xếp: cái gì mở khóa nhiều thứ
nhất và kiểm được ngay thì làm trước; cái gì cần phần cứng để lại **cuối cùng** (quyết định của
chủ sản phẩm 08/09).

---

## Việc chờ CHỦ SẢN PHẨM (không phải việc của tôi)

*Đợt đồng bộ 10/09 đã đóng **7 mục** (DEV-072, 073, 075, 077, 078, 080, 081): CDS-12 lên **v1.4**,
DDD-14 lên **v1.4**, API-15 lên **v1.7**. Phiên 11/09 thêm **5 mục Mở** (DEV-082…086), bốn là nợ
hiện thực của khối mô phỏng và **một chờ anh** — mục P0 ngay dưới.*

| # | Việc | Vì sao chặn |
|---|---|---|
| **P0** | **[DEV-086](DEVIATIONS.md) — thêm `fallback: qemu` cho `isa/avr8.yaml`** | Sửa `docs/spec/` nên cần anh duyệt. Đo 11/09: **không engine mô phỏng nào trong bộ hồ sơ chạy được trên máy này**. `simavr` không có công thức brew, Renode không có cask, `qemu-system-arm` không mang máy ảo nào cho STM32F4. Nhưng `qemu-system-avr` đã có sẵn và mang đúng `arduino-uno` = ATmega328P — khớp `family_patterns: ["^ATmega", …]` của `avr8.yaml`. Một dòng trong `docs/ho-so/nguon/tgt_sim.js`, cùng khuôn với `armv7e-m.yaml` (vốn đã có `fallback: qemu`). Đổi lại: khối `sim.*` có đường chạy engine **thật** kiểm được, và đó là điều kiện để đóng DEV-083 + DEV-084 và để bắt đầu `debug.*` |
| **P1** | **WI-257 — ký danh sách trắng** | `trusted_sources` không có `raw.githubusercontent.com`, mà đó là nơi SVD tầng vàng thật sự nằm. **Mọi tải SVD hiện rơi vào ASK.** Sửa `defaults.yaml` rồi `eide policy sign` |
| ~~P2~~ | ~~[DEV-077](DEVIATIONS.md) — cạnh `CONFLICTS_WITH`~~ | **Anh chốt 10/09: thêm trường.** DDD-14 §2 Fact v1.4 có `conflicts_with`; migration `0006`; `kg.dung` dựng cạnh từ hai đường (suy + khai); `extract.pdf_errata` nối được cạnh mà hợp đồng đòi. Xong |
| ~~P3~~ | ~~Duyệt bản nháp đồng bộ~~ | **Anh duyệt 10/09.** Sáu mục đã đóng: CDS-12.1/12.2/12.4 lên **v1.4** (DEV-072, 073, 075, 078, 080), API-15 lên **v1.7** (DEV-081 — kiểu sự kiện `project.state`). Còn **3 mục Mở**, cả ba là nợ hiện thực chờ mốc/khối sau ([DEV-074] M5, [DEV-076] và [DEV-079] chờ D3 vision) |
| P4 | **Đường ảnh cho Gateway** | `models.yaml` khai vai trò `cartographer` với `inputs: [image]` nhưng `Gateway.run` chỉ nhận văn bản. Mở nó là việc hạ tầng + cần khoá mô hình có thị giác (tốn token) — xem §8 của [TIEN-DO.md](TIEN-DO.md) |
| P5 | WI-258 — xác nhận đỏ PTIT | Đang dùng `#B8121F` theo UXD-13 §7 |
| P6 | Chuẩn bị **một board** (Nucleo F411 / ESP32-C3) | Cho khối H cuối cùng |

---

## A. Dọn nốt M1 — 1 năng lực còn lại, và nó chờ board

Mốc M1 đang **74/75**. A1, A2, A3 xong 08/09; chỉ còn `passport.verify_on_board` (khối H).

| # | Năng lực | Ghi chú |
|---|---|---|
| ~~A1~~ | ~~`archive.extract_one`, `archive.query`~~ | **Xong 08/09** — 10 test. Tìm qua kho lồng; kho lồng là vật chứa nên không grep byte thô của nó |
| ~~A2~~ | ~~`env.install` (**R4**), `env.guide_install`~~ | **Xong 08/09** — 20 test. Không sudo ở bất kỳ lệnh nào; công cụ đóng (XC8/IAR/Keil) → E4001 chỉ sang `guide_install`; lệnh cài chạy trong sandbox có mạng. Thực tế cổng khác tài liệu → [DEV-060](DEVIATIONS.md), mục P4 |
| ~~A3~~ | ~~`code.constant_guard`~~ | **Xong 08/09** — 16 test. Bốn điều kiện của TC-04/TC-06; ranh giới "ngữ cảnh phần cứng" là chỗ quyết định guard dùng được hay bị tắt đi |

> **Làm A2 lộ một lỗi im lặng của sandbox** (đã sửa): hồ sơ `sandbox-exec` không giải liên kết
> mềm trong đường dẫn, nên tiến trình bên trong **không ghi được vào chính thư mục làm việc của
> nó**. Không test nào thấy vì chưa test nào ghi tệp trong sandbox. Xem mục I2 — nhiều khả năng
> đây cũng là lý do bốn bộ dựng lược đồ ngoài Graphviz chưa nhánh nào chạy được.

---

## B. `code.*` — 16 năng lực (M2/M3) · **ưu tiên cao nhất**

Đây là **mắt xích duy nhất** giữa "tác tử hiểu và lập kế hoạch" với "có firmware chạy được".
Không có nó, luận điểm của đề án dừng ở phần tri thức.

| # | Nhóm | Năng lực |
|---|---|---|
| ~~B1~~ | Sinh | ~~`generate_module`, `generate_tests`, `modify`~~ — **xong 08/09** |
| ~~B2~~ | Dựng và kiểm | ~~`build`, `test_host`, `static`, `size`~~ — **xong 08/09**. Lệnh dựng và ba quy tắc Pack (`no_delay_in_isr`, `no_malloc`, `no_float_isr_without_fpu`) lấy từ manifest ISA. Bố cục test máy chủ do hiện thực đặt → [DEV-063](DEVIATIONS.md) |
| ~~B3~~ | Ghép và soát | ~~`integrate`, `review`, `merge`, `revert`, `self_repair`~~ — **xong 08/09**. Bảy đặc trưng của `G3-01` tính lại ở merge; S23…S28 đều có test |
| B4 | Truy vết (M3) | `annotate`, `docs`, `refactor` — ~~`constant_guard`~~ xong. **Cả phần M2 của khối B đã xong; ba cái này ở mốc M3** |

**Mở khóa:** Z-05 "thêm tính năng" (hiện 8/16) chạy tới `code.merge`; và `code.build` là điều
kiện của mọi thứ sau đó.

**Bất biến phải giữ:** mọi hằng số phần cứng trong mã sinh ra phải trỏ về một fact `reviewed`
hoặc `verified` — đó là `code.constant_guard`, và nó là lý do cả tầng tri thức tồn tại. Sinh mã
mà không nối về fact thì EIDE chỉ là một trình sinh mã nữa.

---

## C. `doc.*` + `diagram.*` — **XONG phần M2**; còn 5 ở M3 (`slides`, `sync`, `translate`, `from_image`, `diagram.sync`)

| # | Việc | Giá trị |
|---|---|---|
| ~~C1~~ | ~~`doc.generate`, `doc.embed_diagram`~~ | **Xong 08/09** — khép chuỗi **P7 (8/8)**. Bảng số liệu dựng bằng mã, văn xuôi do mô hình viết quanh bảng |
| ~~C2~~ | ~~`sequence`, `pinmap`, `memory_map`, `architecture`, `state`~~ | **Xong 09/09** — `pinmap` nối netlist ↔ hộ chiếu chân ↔ linh kiện; `memory_map` xếp section theo địa chỉ |
| ~~C3~~ | ~~`api_ref`, `test_report`, `changelog`, `bringup_guide`~~ | **Xong 09/09** — `doc.*` 9/12; ba loại còn lại (`translate`, `slides`, `sync`) đều ở M3 |
| ~~C4~~ | ~~`diagram.flow`, `gantt`, `timing`~~ | **Xong 09/09** — kèm một lỗi im lặng của `diagram.lint`: cạnh có nhãn và nút kèm nhãn đều vô hình với nó |

**Đã đạt điều đáng làm sớm:** `eide doc generate --type SRS` nay cho ra **chính bộ tài liệu
dùng làm phụ lục đề án** — sản phẩm tự viết tài liệu về mình, bảng số liệu dựng từ store, mục
Nguồn truy ngược về từng `source`. Đó là bằng chứng mạnh hơn bất kỳ mô tả nào.

---

## D. `extract.*` — **7/8 phần M2 xong 10/09**; còn D3 (ảnh) + `image_scope` (M5)

| # | Việc | Ghi chú |
|---|---|---|
| ~~D1a~~ | ~~`pdf_pinout`~~ | **Xong 10/09** — 19 test, PDF thật có bảng kẻ khung. Số AF đọc từ **vị trí cột**, không gọi mô hình. Nhánh hình package → [DEV-076](DEVIATIONS.md) |
| ~~D1b~~ | ~~`pdf_errata`~~ | **Xong 10/09** — 21 test. Lớp phủ K2′ (`layer = "B"`), rev từ vị trí cột `Rev A`/`Rev Z`; cạnh CONFLICTS_WITH → [DEV-077](DEVIATIONS.md) chờ anh chọn hướng |
| ~~D2a~~ | ~~`dt_binding`~~ | **Xong 10/09** — 8 test. Đọc CẢ HAI dạng binding (Zephyr `required: true` trong thuộc tính; dt-schema Linux `required: [...]` cấp cao) |
| ~~D2b~~ | ~~`bom`~~ | **Xong 10/09** — 10 test. Bốn đường vào (netlist · csv · xlsx · readme); gộp theo MPN đầy đủ → [DEV-078](DEVIATIONS.md); đường ảnh → [DEV-079](DEVIATIONS.md) |
| ~~D2c~~ | ~~`bom_enrich`~~ | **Xong 10/09** — 7 test. Hộ chiếu trong store thắng ứng viên tải về; `search.registry` (M4) chưa có nên chuỗi bắt đầu từ `search.vendor`; thiếu thì mở `kg.request`, một MPN một yêu cầu |
| D3 | `image_board`, `image_schematic`, `ocr` | đọc ảnh (cần mô hình vision). Mở khoá nốt nhánh hình của `pdf_pinout` — [DEV-076](DEVIATIONS.md) |
| ~~D4a~~ | ~~`readme_goal`~~ | **Xong 10/09** — 7 test. Lọc kỳ vọng theo `plan.DANG_KY_VONG` ngay tại chỗ; không ghi store (R0, `undo: none`) |
| ~~D4b~~ | ~~`pdf_formula`~~ | **Xong 10/09** — 7 test. Công thức → **K5 skill** (`.eide/skills/*.md`, front-matter `applies_to`), KHÔNG thành fact; E5002 khi mô hình không trả mã C → [DEV-080](DEVIATIONS.md) |

**Đã mở khóa:** `extract.pdf_pinout` sinh fact `pin_function`, nên `board.propose_fix` nay nêu
được ĐỔI SANG CHÂN NÀO thay vì "chưa tra được chân thay thế", `diagram.pinmap` điền được cột
`pin`, và `arch.map_hw` thôi phải gán ngoại vi theo tên module. `tests/test_extract_m2.py::
test_board_tra_duoc_chan_thay_the_sau_khi_trich` giữ đường nối ấy khỏi đứt trong im lặng.

---

## ~~E. `board.*`~~ — **5/5, xong 08/09**

~~`build_passport`, `check_pins`, `constraints`, `propose_fix`, `mark_lab`~~ — cùng
`extract.kicad_netlist` và `doc.bringup_guide`. **Chuỗi Z-07 nay đủ năng lực cho cả 23 bước**;
`board.*` là nhóm M2 đầu tiên đóng trọn.

`mark_lab` ghi `boards.<id>.lab` vào danh sách **đã ký**, nên nó phải ký lại niêm — và làm việc
ấy lộ ra một lỗ hổng của `PolicyGate`: `boards` nằm trong `whitelist.KHOA_NIEM` nhưng `_env`
vẫn nạp nó kể cả khi niêm vỡ. Sửa tay `.eide/autonomy.yaml` thêm `lab: true`, không ký, là đủ
để `G-OPS-01` cho tự nạp firmware — đúng đường mà POL-17 §3 niêm `boards` để bịt. Đã vá, có
test đối chứng hai chiều (`test_boards_KHONG_duoc_nap_khi_niem_vo`).

---

## ~~F1. `sim.*`~~ — **6/6 phần M3, xong 11/09**; còn F2 `debug.*` (6, M3)

| # | Việc | Trạng thái |
|---|---|---|
| ~~F1~~ | ~~`build_platform`, `mock_peripheral`, `model_plant`, `scenario`, `run`, `sweep`~~ | **Xong 11/09** — 44 test. `compare_hil` là M4 (cần báo cáo HIL thật). Chuỗi Z-05 lên **14/16**, chỗ đứt dời sang `target.flash` |
| F2 | `debug.hypothesize`, `experiment`, `ask_at`, `log_stats`, `propose_fix`, `summarize` | Cần một lượt chạy mô phỏng **quan sát được** — tức cần [DEV-086](DEVIATIONS.md) (mục P0) rồi [DEV-083](DEVIATIONS.md) |

**Bất biến của khối F1, và nó là phần đáng nhớ hơn cả sáu năng lực**: không kỳ vọng nào được coi
là ĐẠT nếu không có kênh quan sát cho nó. Một `expect` mà engine hiện có không nhìn thấy được
(`var` qua monitor, `gpio`, tín hiệu plant) trả `unverified` kèm lý do, và một kịch bản có dù một
dòng `unverified` thì `report.passed = false`. Ba trạng thái chứ không phải hai, vì "firmware làm
sai" và "EIDE chưa nhìn thấy được" là hai câu khác nhau: gộp thành `failed` thì người ta đi sửa
một chỗ không hỏng, gộp thành `passed` thì một firmware chưa ai quan sát đi thẳng lên board.

**Điều khối này chưa làm được, và vì sao.** Không engine nào trong bộ hồ sơ chạy được trên máy
phát triển (xem P0), nên **đường chạy engine thật chưa lần nào được thi hành** — cùng hình dạng
với mục I2. Bốn nợ hiện thực đã ghi: [DEV-082] (bảng tên chương trình và máy ảo nằm trong mã),
[DEV-083] (kênh `var`/`gpio`), [DEV-084] (đồng mô phỏng plant ↔ chip), [DEV-085] (UART ra console
nên `within_s` chỉ kết luận được khi `within_s ≥ duration_s`).

**Nền tảng (PLATFORM.md quy tắc 7): mac — kiểm thật trên arm64.** Phần mã của nhóm là đa nền
tảng theo đúng ba quy tắc đầu (`pathlib`, argv dạng danh sách, `tools.which` cho mọi engine, và
`tools.which` đã tự thử `.exe`/`.cmd` trên Windows). Hai chỗ còn phụ thuộc nền tảng đều KHÔNG
thuộc nhóm này: (a) mọi lượt chạy engine đi qua `eide_core.sandbox`, mà `sandbox.py` `import
resource` và dùng `preexec_fn` — cả hai chỉ có trên Unix, nên `sim.run`/`sim.sweep` chưa chạy
được trên Windows cho tới khi lõi sandbox có nhánh Windows (nợ sẵn có, không phải của F1);
(b) tên tệp thi hành của engine trên Windows chưa ai kiểm vì chưa máy nào có engine.

**Điều khối này làm được thật:** `sim.model_plant` sinh ra một mô hình con lắc ngược RK4 và
TC-SM-03 **đo trên chính mô-đun ấy** — không điều khiển đổ sau 0,21 s; PID tham chiếu đưa nhiễu
5° về dưới 1° trong 0,10 s. `sim.sweep` quét lưới trên cùng mô hình ấy, đúng ví dụ
`{"kp": [1,10,1]}` của SIM-06. `sim.mock_peripheral` sinh mock BME280 từ fact và test **nạp mô-đun
sinh ra rồi nói chuyện I2C với nó**: `Write([0xD0])` → `Read(1) == [0x60]`, đúng TC-SM-02.

---

## ~~G. Rải rác~~ — **XONG phần M2** (còn 6 mục M4: `registry.*` 4 · `search.registry`/`reference_projects`)

| # | Nhóm | Trạng thái |
|---|---|---|
| ~~G1~~ | ~~`project.clone`, `project.archive`, `project.rollback`~~ | **Xong 10/09** — 19 test. Bản sao KHÔNG mang theo ledger/decision_log/run; rollback chặn working tree bẩn trước khi đụng git. Kiểu sự kiện ledger còn thiếu → [DEV-081](DEVIATIONS.md) |
| ~~G2~~ | ~~`view.*` 4 (M2)~~ | **Xong 10/09** — 15 test. `view.*` đóng **13/13**. `impact_map` gọi `kg.impact`/`req.change_impact` chứ không tính lại; `rag_compare` bỏ nhóm nguồn im lặng khỏi bảng; `timeline` gom bốn nguồn |
| ~~G3~~ | ~~`tool.*` 3~~ | **Xong 10/09** — 16 test. `tool.*` đóng **10/10**. `compose` hợp hiệu ứng (hardware → R3) và gọi `ctx.invoke`, không nhúng mã; `promote` chỉ ĐỀ XUẤT — `docs/spec/` không đổi một byte; `deprecate` giữ mã, chỉ lấy đi chỗ trong danh sách gợi ý |
| ~~G4~~ | ~~`memory.*` 2 · `passport.diff/upgrade` 2~~ | **Xong 10/09** — 16 test. `error_ledger` khép vòng *lỗi → negative_prompt → C1 lần sau*; `forget` không chạm M4; `diff` so theo (subject, predicate) chứ không theo fact id; `upgrade` hạ feature dùng fact đổi xuống `failing` |
| ~~G5~~ | ~~lẻ~~ | **Xong 10/09** — 17 test. `kg.evidence` bỏ id treo; `report.explain` ép trích dẫn có mặt và cắt 150 từ; `env.install_pack` kiểm chữ ký, ISA mới vào bằng GÓI không sửa core; `search.docs_mcp` 5 đoạn, E8002 khi sensitive + query chứa nội dung dự án |
| G6 | `registry.*` 4 (M4) · `search.registry`/`reference_projects` (M4) | để sau — mốc M4 |

Sau khi khối D đóng phần không cần thị giác, đây là **nhóm không bị chặn bởi gì cả**: không cần
board, không cần trình mô phỏng, không cần khoá mô hình mới. Nó cũng là đường nâng M2 nhanh
nhất (20 năng lực).

---

## H. Cần PHẦN CỨNG THẬT — 28 năng lực · **để cuối cùng**

Quyết định của chủ sản phẩm 08/09: board thật test sau cùng.

| Nhóm | Số | Việc |
|---|---|---|
| `discover.*` | 12 | Dò cổng, probe, ID chip, tốc độ liên kết |
| `target.*` | 9 | Nạp, reset, serial, đọc/ghi thanh ghi qua probe |
| `measure.*` | 3 | Đo tín hiệu, dòng (M5) |
| `bench.*` | 3 | Benchmark trên board |
| `passport.verify_on_board` | 1 | Huy hiệu "đã kiểm trên board" (M1 — cái duy nhất của M1 phải chờ) |

**Chuỗi Z-10 hiện 1/10** và sẽ ở đó tới lúc có board. Đó là đúng lịch, không phải chậm.

---

## I. Hạ tầng và chất lượng

| # | Việc | Ghi chú |
|---|---|---|
| I1 | **WI-253** — sinh test hợp đồng tự động cho 238 năng lực | `validate_specs.py` đã có; cần sinh test từ `input_schema`/`errors`. Bắt được lỗi E1000/E1004 mà không phải viết tay từng cái |
| I2 | Mở rộng `make check-net` cho `mmdc`/`plantuml`/`d2`/`7z` | Hiện chỉ Graphviz chạy thật; bốn bộ dựng còn lại vẫn chưa nhánh nào được thi hành. **Thử lại sau khi sửa sandbox 08/09** — chúng ghi tệp ra, mà đúng chỗ ấy trước đây bị chặn |
| I3 | Thêm test `llm` cho `plan.*`, `tool.write`, `extract.pdf_register_map` | Ba nhóm sinh còn lại chưa có test gọi thật |
| I4 | **M5**: schema manifest ISA + TC-48 + rv32imac/xtensa/pic16 | [DEV-055](DEVIATIONS.md). Kèm món nợ M0: `avr8.yaml` chưa test nào chạm tới |
| I5 | `scripts/nghiem_thu_sprint3.sh` | Khi khối B xong |
| ~~I6~~ | ~~**WI-260** — phần Swift vào `make check`~~ | **Xong 11/09.** `check-swift` nằm trong `check`; bỏ qua có báo khi máy không có `swift`. Hai bài đỏ từ 06/09 đã sửa: `HelpBookTests` đòi rơi về tiếng Việt trong khi mã cố ý rơi về **tiếng Anh** và `de` nay đã có sách; `YAMLRealFilesTests` leo ba cấp ra `apps/geditor` nên còn **1** tệp YAML — nay leo theo mốc `.git` và chạy trên **35** tệp thật của kho |

---

## Đề xuất thứ tự

```
A1+A2 (xong)  →  B1+B2 (xong)  →  E board.* (xong, Z-07 đóng)
              →  C1..C4 (xong, P7 đóng)  →  D phần không cần ảnh (xong 10/09)
              →  G rải rác (xong 10/09, M2 đóng phần làm được)
              →  F1 sim.* (xong 11/09, Z-05 lên 14/16)
              →  ??? ←  ĐANG Ở ĐÂY: P0 [DEV-086] anh duyệt → F2 debug.*  hoặc
                        D3 (cần đường ảnh cho Gateway — mục P4)  hoặc
                        B4 code.* phần M3 (không bị chặn, giá trị thấp hơn)
              →  H (phần cứng, cuối cùng)
```

**Lý do đặt B trước C:** `doc.generate` viết tài liệu *về* thiết kế và mã. Có `code.*` rồi thì
tài liệu sinh ra nói về một hệ thống có thật, chứ không phải về một kế hoạch.

**Lý do đặt E ngay sau B** (đã làm xong): `board.build_passport` là chỗ đứt duy nhất còn lại
của Z-07. Đóng được một chuỗi trọn vẹn là mốc đáng có — và nó đã đóng.

**Kế tiếp là C** (đã làm xong C1+C3): `doc.generate` là chỗ đứt của P7, và bộ tài liệu sinh ra
chính là phụ lục đề án — sản phẩm tự viết tài liệu về mình, có trích dẫn tới fact.

---

## Điểm dừng phiên 11/09/2026 — bắt đầu phiên sau từ đây

*Cây làm việc sạch, `make check` **1346 xanh**, DEVIATIONS còn **8 mục Mở** — 7 là nợ hiện thực,
**1 chờ chủ sản phẩm** ([DEV-086], mục P0).*

**182/238 (76%), M3 mở màn 6/29.** Sáu năng lực `sim.*` trong phiên, cộng hai lỗi im lặng.

### Mốc đạt được: vòng sinh mã → dựng → mô phỏng → ghép đã liền

Chuỗi Z-05 "thêm tính năng" lên **14/16** và chỗ đứt dời từ `sim.run` sang `target.flash`. Không
chuỗi chuẩn nào còn chờ mô phỏng nữa — ba chuỗi dở dang đều đứt ở phần cứng hoặc registry.

### Đã xong trong phiên

| Khối | Năng lực | Điều đáng nhớ |
|---|---|---|
| F1 `sim.*` | `build_platform`, `mock_peripheral`, `model_plant`, `scenario`, `run`, `sweep` → **6/6 phần M3** | Bất biến: **không expect nào ĐẠT nếu không có kênh quan sát cho nó** — ba trạng thái `passed`/`failed`/`unverified`, và một dòng `unverified` kéo cả lượt chạy xuống `passed=false` |
| Lõi | `Sandbox` từ chối khóa `limits` lạ | Ba hằng số thời gian chờ (600/900/120 s) chưa bao giờ có hiệu lực — xem lỗi im lặng số 7 trong [TIEN-DO.md](TIEN-DO.md) |
| `project.*` | `_isa_tu_chip` nhận cả dạng IRI hộ chiếu | Ghim `st.stm32f411ce` từng cho `isa: null` im lặng — lỗi im lặng số 8 |
| Tài liệu | DEV-082…DEV-086 | Bốn nợ hiện thực của khối mô phỏng, một mục chờ anh duyệt |

### Điều phiên này dạy được

- **Có `qemu` không có nghĩa là chạy được chip này.** QEMU chỉ chạy những bo mạch đã biên dịch
  sẵn vào nó; máy gần nhất với STM32F411 là `netduinoplus2`, vốn là STM32F405. Gán tạm nó thì
  firmware chạy trên một con chip khác chip nó được dịch cho — rồi báo ĐẠT. Nên "engine dùng
  được" là kết luận về **cặp (engine, chip)**, không phải về engine.
- **Một hằng số trông như đang có hiệu lực là thứ chỉ lộ ra ở lần chạy thật đầu tiên.**
  `timeout_s` vs `wall_s`: bảy chỗ gọi, ba hằng số, không test nào chạy đủ lâu để chạm hạn. Vá
  bằng cách để lớp dưới TỪ CHỐI khóa lạ, không phải bằng cách sửa bảy chỗ gọi — sửa bảy chỗ thì
  chỗ thứ tám vẫn im lặng như cũ.
- **Hai dạng tên cho cùng một con chip sống cạnh nhau trong cùng bộ hồ sơ.** SIM-01 viết
  `st.stm32f411ce`, PROJECT-06 viết `STM32F411CE`, và `family_patterns` chỉ khớp dạng thứ hai.
  Test cũ có ghim đúng dạng thứ nhất nhưng chỉ khẳng định phần hộ chiếu, nên nhánh ISA không ai
  nhìn suốt năm ngày.

### Bẫy đã biết, đừng đạp lại

- **`limits` của sandbox dùng khóa `wall_s`, không phải `timeout_s`.** Nay truyền sai tên là
  E1000 ngay, nhưng nhớ tên đúng vẫn rẻ hơn đọc lỗi.
- **Engine mô phỏng chưa lần nào chạy thật trên máy này** (P0). Test của `sim.run`/`sim.sweep`
  dùng shim; đường engine thật vẫn chờ [DEV-086].
- **Chạy test bằng `.venv-arm/bin/python`, không phải `python` trên PATH.** Venv là 3.11 còn
  `python` hệ thống mới hơn: một f-string lồng dùng lại dấu nháy chạy được ở ngoài và là LỖI CÚ
  PHÁP trong venv — pytest xanh, `make check` đỏ ở bước ruff.
- `Router.invoke` biến `EideError` của handler thành run `failed` (`run.error["eide_code"]`);
  chỉ E1000 từ lớp kiểm `input_schema` mới ném ra ngoài. **Năng lực T2 trả `status="pending"`**,
  phải `r.quyet_dinh(run_id, "approve")` rồi mới có kết quả — `pdf_errata` và `pdf_electrical`
  đều thế.
- `passport._gop_mot` gộp theo **(subject, predicate)**: hai bản ghi khác nhau mà chung một
  subject sẽ thành `conflict` giả. Mỗi thực thể một subject riêng.
- Ba cổng chặn trong `tests/test_specs_consistency.py` vẫn nguyên: docstring nêu ĐÚNG mã hợp
  đồng; không đọc tham số ngoài `input_schema`; không định nghĩa trùng tên hàm ở mức cao nhất.
