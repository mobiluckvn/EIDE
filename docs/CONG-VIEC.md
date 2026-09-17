# Danh sách công việc EIDE

*Đo 17/09/2026 (lần 20) từ registry — không gõ tay. Còn **22/238** năng lực, và **cả 22 đều
cần một bo mạch, một công cụ ngoài, hay một thiết bị đo**. Xem [`TIEN-DO.md`](TIEN-DO.md) cho
bức tranh trạng thái; tệp này trả lời **làm gì tiếp**.*

> **17/09: việc của phần mềm nay nằm ở CHỖ NỐI, không ở năng lực.** Hai hạng mục vừa đóng đều
> không phải một năng lực mới: vùng trao đổi người ↔ tác tử thành bất biến ([DEV-120]), và nút
> của chuỗi nối được dữ liệu cho nhau ([DEV-121]). Cái thứ hai mở lại đường đi trung tâm của sản
> phẩm — trước nó, bốn trong năm chuỗi mẫu của DPS-09 §4.4 không bao giờ chạy được.
>
> **Một mục MỞ đang chờ anh**: [DEV-121] đề nghị mẫu chuỗi trong `dps.js` tự mang phần nối
> (`args` với tham chiếu `${nX.field}`). Hiện phép tự nối chỉ dựa vào trùng tên và giải được 3
> trong 20 chỗ; 17 chỗ còn lại đúng với mắt người đọc nhưng không tài liệu nào của kho nói thế,
> nên tôi để trống thay vì tự nghĩ ra. Đây là việc của tài liệu, không phải của mã.

> **13/09: danh sách này chỉ còn MỘT hạng mục.** Ngày 12/09 nó còn bốn nhóm chờ bốn thứ khác
> nhau. Nay registry đã dựng cục bộ ([DEV-091]) và đường ảnh đã mở, nên **29 năng lực còn lại
> đều chờ đúng một vật: một bo mạch.** Cùng với chúng là 7 phương thức JSON-RPC, 1 kiểu sự
> kiện sổ cái, 2 mã lỗi và phần lớn 27 mã TC còn lại.
>
> Không còn mục nào chờ thời gian, chờ một thư viện, hay chờ một quyết định.

Sắp theo **thứ tự nên làm**, không theo số hiệu. Nguyên tắc sắp xếp: cái gì mở khóa nhiều thứ
nhất và kiểm được ngay thì làm trước; cái gì cần phần cứng để lại **cuối cùng** (quyết định của
chủ sản phẩm 08/09).

---

## Việc chờ CHỦ SẢN PHẨM (không phải việc của tôi)

*Đợt đồng bộ 10/09 đã đóng **7 mục** (DEV-072, 073, 075, 077, 078, 080, 081): CDS-12 lên **v1.4**,
DDD-14 lên **v1.4**, API-15 lên **v1.7**. Phiên 11/09 thêm DEV-082…086, và đợt 2 cùng ngày đóng
**DEV-086** (TGT-19 **v1.2**, SIM-20 **v1.1**) cùng **DEV-087** (anh duyệt tại chỗ).*

**Không còn việc nào chờ anh ở mức chặn.** WI-257 và DEV-089 đã ký xong (12/09). Còn lại trong
bảng là việc dài hơi: [DEV-088] chờ anh xem để đưa vào SEC-25, đường ảnh cho Gateway, đỏ PTIT,
và một board thật.

| # | Việc | Vì sao chặn |
|---|---|---|
| ~~P0~~ | ~~[DEV-086](DEVIATIONS.md) — thêm `fallback: qemu` cho `isa/avr8.yaml`~~ | **Anh duyệt 11/09, đã xong.** TGT-19 lên **v1.2**, SIM-20 lên **v1.1**. Nhóm `sim.*` nay có lượt chạy engine THẬT: `qemu-system-avr -M arduino-uno` chạy một ELF AVR qua chính `sim.run` và trả `captured.uart == ["E"]` — ELF dựng bằng tay trong test (98 byte), nên không cần `avr-gcc` vốn không có trên máy |
| ~~P1~~ | ~~WI-257 — ký danh sách trắng~~ | **Xong 11/09, và ký lại 12/09 cho [DEV-089].** `trusted_sources` thêm `raw.githubusercontent.com`; `trusted_packages` từ 12 lên **26 gói** — đủ 24 mục TGT-19 §3 kể cộng `arm-none-eabi-gcc`/`-binutils`. Đo được trước khi sửa: **7/8** công cụ mà manifest ISA khai đều vắng khỏi danh sách trắng, nên `env.install` hỏi người ở gần như mọi công cụ của chuỗi dựng. Băm hiện tại `5c1f3da12712…` |
| ~~P2~~ | ~~[DEV-077](DEVIATIONS.md) — cạnh `CONFLICTS_WITH`~~ | **Anh chốt 10/09: thêm trường.** DDD-14 §2 Fact v1.4 có `conflicts_with`; migration `0006`; `kg.dung` dựng cạnh từ hai đường (suy + khai); `extract.pdf_errata` nối được cạnh mà hợp đồng đòi. Xong |
| ~~P3~~ | ~~Duyệt bản nháp đồng bộ~~ | **Anh duyệt 10/09.** Sáu mục đã đóng: CDS-12.1/12.2/12.4 lên **v1.4** (DEV-072, 073, 075, 078, 080), API-15 lên **v1.7** (DEV-081 — kiểu sự kiện `project.state`). Còn **3 mục Mở**, cả ba là nợ hiện thực chờ mốc/khối sau ([DEV-074] M5, [DEV-076] và [DEV-079] chờ D3 vision) |
| P4 | **Đường ảnh cho Gateway** | `models.yaml` khai vai trò `cartographer` với `inputs: [image]` nhưng `Gateway.run` chỉ nhận văn bản. Mở nó là việc hạ tầng + cần khoá mô hình có thị giác (tốn token) — xem §8 của [TIEN-DO.md](TIEN-DO.md) |
| **P7** | **[DEV-088](DEVIATIONS.md) — SEC-25 §2/§3** | Lõi sandbox nay nhận `cwd` và `them_path`; không có chúng thì `code.build` không thể thành công trên bất kỳ máy nào. Đề xuất §3 ghi rõ `PATH` gồm cả thư mục chuỗi công cụ đã khai trong manifest ISA, §2 ghi rõ thư mục làm việc có thể là gốc dự án khi năng lực đã khai `allowed_dirs` chứa nó |
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
| ~~F2~~ | ~~`debug.*` — 6 năng lực~~ | **Xong 12/09 — 6/6, và không cần [DEV-083] như đã tưởng.** Hoá ra chỉ `experiment` cần board (nó trả `pending` đúng như hợp đồng ghi), còn năm cái kia đứng trên log và store: `log_stats` tính bằng mã, `hypothesize`/`ask_at` gọi mô hình với ngữ cảnh ghép từ bốn nguồn, `save_session` lưu cả giả thuyết đã bị bác, `propose_fix` phân ba hướng sửa. Migration 0007 dựng bảng `debug_session` — bảng cuối cùng của bộ hồ sơ chưa có migration |

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
| I2 | Mở rộng `make check-net` cho `mmdc`/`plantuml`/`d2`/`7z` | Hiện chỉ Graphviz chạy thật; bốn bộ dựng còn lại vẫn chưa nhánh nào được thi hành (đo 11/09: cả bốn đều **chưa cài**). **Thử lại sau khi sửa sandbox 08/09** — chúng ghi tệp ra, mà đúng chỗ ấy trước đây bị chặn. Cùng hình dạng với [DEV-086], nay đã có tiền lệ gỡ được |
| ~~I7~~ | ~~**Chuỗi công cụ ARM — dựng thật một lần**~~ | **Xong 11/09 đợt 3.** `arm-none-eabi-gcc` 16.2.0 cài bằng **công thức** (không phải cask — cask là `.pkg` cần mật khẩu admin). `code.build` nay dựng ra firmware `armv7e-m` thật và `code.size` đọc số thật từ `arm-none-eabi-size`. Phải sửa **ba tầng** trong lõi mới chạy được — xem [DEV-088](DEVIATIONS.md) |
| I3 | Thêm test `llm` cho `plan.*`, `tool.write`, `extract.pdf_register_map` | Ba nhóm sinh còn lại chưa có test gọi thật |
| I4 | **M5**: schema manifest ISA + TC-48 + rv32imac/xtensa/pic16 | [DEV-055](DEVIATIONS.md). Kèm món nợ M0: `avr8.yaml` chưa test nào chạm tới |
| ~~I5~~ | ~~`scripts/nghiem_thu_sprint3.sh`~~ | **Xong 12/09 — 13/13 ĐẠT.** Chuỗi HIỆN THỰC bằng công cụ thật: ghim ISA → dựng ELF `armv7e-m` → đo ngân sách (flash_pct 0,01% của 512 KB) → chặn hằng số không nguồn → **mô phỏng thật trên `qemu-system-avr`** → sổ cái 17 bản ghi liên tục → niêm store khớp. Bỏ qua có báo khi máy thiếu công cụ, không báo đỏ |
| I8 | **Bộ đọc YAML của GEditor chưa hiểu dãy flow trải nhiều dòng** | Tìm ra 12/09 bởi chính `YAMLRealFilesTests` vừa sửa ở WI-260: một bản nháp `defaults.yaml` viết `trusted_packages` thành ba dòng làm nó đỏ ngay — dù YAML ấy hợp lệ và Python đọc được. Đã né bằng cách giữ một dòng (đúng quy ước của chính tệp), nhưng bộ đọc vẫn thiếu tính năng. **Không phải sai khác spec** — đây là khoảng trống của ứng dụng chủ. Đáng ghi vì nó là bằng chứng bài test ấy sống: nó bắt được một lỗi thật trong vòng một ngày kể từ lúc được nối lại ngữ liệu |
| ~~I6~~ | ~~**WI-260** — phần Swift vào `make check`~~ | **Xong 11/09.** `check-swift` nằm trong `check`; bỏ qua có báo khi máy không có `swift`. Hai bài đỏ từ 06/09 đã sửa: `HelpBookTests` đòi rơi về tiếng Việt trong khi mã cố ý rơi về **tiếng Anh** và `de` nay đã có sách; `YAMLRealFilesTests` leo ba cấp ra `apps/geditor` nên còn **1** tệp YAML — nay leo theo mốc `.git` và chạy trên **35** tệp thật của kho |

---

## Đề xuất thứ tự

```
A1+A2 (xong)  →  B1+B2 (xong)  →  E board.* (xong, Z-07 đóng)
              →  C1..C4 (xong, P7 đóng)  →  D phần không cần ảnh (xong 10/09)
              →  G rải rác (xong 10/09, M2 đóng phần làm được)
              →  F1 sim.* (xong 11/09, Z-05 lên 14/16)
              →  P0 [DEV-086] (xong 11/09 đợt 2 — sim.* chạy engine THẬT)
              →  ??? ←  ĐANG Ở ĐÂY: I7 chuỗi công cụ ARM (mắt xích trung tâm
                        DUY NHẤT còn chưa chạy thật)  hoặc
                        F2 debug.* qua [DEV-083] (nay làm được: QEMU có gdbstub)  hoặc
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

## Điểm dừng phiên 13/09/2026 — BẮT ĐẦU PHIÊN SAU TỪ ĐÂY

*Cây làm việc SẠCH. `make check`: **1503 test Python + 2699 test Swift** xanh. DEVIATIONS **9
Mở** — 7 nợ hiện thực, **2 chờ chủ sản phẩm** ([DEV-088] SEC-25 §2/§3, [DEV-089] trường
`package` cho `toolchain.tools[]`).*

### Trạng thái: 209/238 (88%), 21/27 nhóm đủ

| Trục (xem [`DOI-CHIEU-THIET-KE.md`](DOI-CHIEU-THIET-KE.md)) | |
|---|---|
| Năng lực | 209/238 · **88%** |
| JSON-RPC | 50/57 · 88% |
| Kiểu sự kiện sổ cái | 25/26 · 96% |
| Mã lỗi | 26/29 · 90% |
| **Quy tắc chính sách** | **49/49 · 100%** |
| **Vai trò mô hình** | **9/9 · 100%** |
| Công cụ MCP | 11/15 · 73% |
| Mã kiểm thử TC | 45/72 · 63% |

### Ba phiên vừa qua đóng những gì

| Phiên | Đóng |
|---|---|
| 11/09 | `sim.*` chạy engine thật; `code.build` dựng firmware thật; Swift vào `make check` |
| 12/09 | `debug.*` 6/6 · `doc.*` 12/12 · `report.*` 4/4 · `registry.*` 5/5 cục bộ · đường ảnh 5 năng lực · JSON-RPC 12→50 |
| 13/09 | 10 quy tắc chính sách chưa ai chạm · E7000 · ba món nợ (`roles.yaml`, `autonomy.change`, `stop`) |

### Việc phiên sau

| # | Việc | Cần |
|---|---|---|
| 1 | **Anh xem [DEV-088] và [DEV-089]** | duyệt / ký |
| 2 | **Cắm một bo mạch** (Nucleo F411 / ESP32-C3) rồi làm khối H | **board** |
| 3 | `make check-llm` với `GEMINI_API_KEY` — bài `test_duong_anh_di_toi_HANG_va_ve` đã viết, chưa lần nào chạy | khoá mô hình |
| 4 | [DEV-090] `diagram.sync to_code` | `tree-sitter` (phụ thuộc mới) |
| 5 | 22 màn hình UI còn lại của UXD-13 | việc Swift, không chặn gì |

### Bẫy mới, đừng đạp lại

- **`board` là tham số riêng của `PolicyGate.decide`, KHÔNG phải một đặc trưng.** Truyền nhầm
  vào `features` thì `_env` ném `TypeError: 'str' object is not a mapping`.
- **`GEN-01` không bao giờ khớp ở R0** — APD-08 §4.1 tầng 2 cho R0 tự chạy trước khi bảng quy
  tắc được hỏi. Không phải lỗ hổng; xem test.
- **`TOOL-04` bị `TOOL-03` (ưu tiên 1) chặn** khi thiếu `tested`/`effects_ok`.
- **Đếm bằng grep thì đo được cái VIẾT RA, không đo được cái CHẠY.** `mcp/server.py` ánh xạ
  generic nên không tên tool nào xuất hiện nguyên văn — tôi đã báo sai 4/15 thay vì 11/15.

## Điểm dừng phiên 12/09/2026 (lịch sử)

*Cây làm việc SẠCH. `make check`: **1414 test Python + 2699 test Swift** xanh. DEVIATIONS **10
Mở** — 8 là nợ hiện thực, **2 chờ chủ sản phẩm** ([DEV-088] SEC-25 §2/§3, [DEV-089] phần sai
tầng của `env.install`).*

### Đã xong: 15 năng lực, và đó là MỌI thứ còn làm được ở đây

**197/238 (83%).** `code` 16/16 · `debug` 6/6 · `doc` 12/12 · `report` 4/4 — **17 nhóm đủ**.

| Khối | Năng lực | Bất biến đáng nhớ |
|---|---|---|
| `debug.*` | 6/6 | Ba trạng thái chứ không hai: `experiment` không có board lab thì **pending**, không đoán. Và lớp rủi ro xét theo năng lực BÊN TRONG — `probe_read` R0, `flash` R3 |
| `report.*` | `export`, `human_ai_matrix` | Mục Nguồn kiểm trên chính tệp SẮP GIAO; ma trận đếm từ `capability_run` chứ không `decision_log`, vì R0 chạy thẳng không qua cổng nào |
| `code.*` | `annotate`, `docs`, `refactor` | `refactor` KIỂM "không đổi hành vi" bằng cách chạy test trước/sau và so TỪNG BÀI — so tổng thì hai bài đổi ngược chiều giữ nguyên tổng |
| `doc.*` | `sync`, `translate`, `slides` | Bản dịch mất một hàng bảng là bản dịch không giao được — `tc` ấy kiểm bằng mã sau khi dịch |
| `diagram.sync` | 1 | Lệch LỚN thì E3000, ranh giới đo bằng **tỉ lệ** — ngưỡng tuyệt đối đúng ở một cỡ FSM và sai ở cỡ kia |

### Việc phiên sau — không còn việc nào chỉ cần thời gian

| # | Việc | Chặn bởi |
|---|---|---|
| 1 | **Anh xem [DEV-088]** (SEC-25 §2/§3) và **[DEV-089]** (thêm trường `package` cho `toolchain.tools[]`) | chữ ký / duyệt |
| 2 | `discover.*` 12 · `target.*` 9 · `bench.*` 3 · `measure.*` 3 · `passport.verify_on_board` | **một bo mạch** (Nucleo F411 / ESP32-C3) |
| 3 | `extract.ocr`/`image_*` 4 · `diagram.from_image` | **khoá mô hình có thị giác** + đường ảnh cho Gateway (mục P4) |
| 4 | `registry.*` 4 · `search.registry`/`reference_projects` | **một registry thật** — hạ tầng ngoài phạm vi đề án |
| 5 | [DEV-090] `diagram.sync` hai hướng GHI | `tree-sitter` (phụ thuộc mới, cần ghi lý do vào `pyproject.toml`) |
| 6 | [DEV-083] kênh `var`/`gpio` qua gdbstub | không chặn gì nữa — `debug.*` đã xong mà không cần nó; giờ nó chỉ làm `sim.run` quan sát được nhiều hơn |

### Bẫy mới, đừng đạp lại

- **Ledger chỉ nhận 26 kiểu sự kiện của API-15 §5.** `debug.session` không có trong đó — dùng
  `store.write`. Thêm kiểu mới là sửa `docs/spec/`, cần DEVIATIONS và chữ ký.
- **`memory.error_ledger` có `additionalProperties: false` và KHÔNG nhận `negative_prompt`** —
  trường ấy do chính nó sinh. Nhét sẵn vào là hai nơi cùng viết một trường.
- **Một bài test có thể đỏ vì TIỀN ĐỀ hết hạn.** `test_planner_vao_cuoc_khi_khong_mau_nao_khop`
  dùng `code.refactor` làm ví dụ "ý định không khớp năng lực nào" — đúng cho tới lúc nó được
  hiện thực. Khi thêm một năng lực, hãy nghĩ xem có bài nào đang dùng tên nó làm ví dụ cho
  "không tồn tại" không.

## Điểm dừng phiên 11/09/2026 **đợt 3** (lịch sử)

*Cây làm việc SẠCH. `make check`: **1354 test Python + 2699 test Swift** xanh. DEVIATIONS **9 Mở**
— trong đó **2 mục mới cần anh xem**: [DEV-088] (sửa SEC-25 §2/§3) và [DEV-089] (cần ký lại
`trusted_packages`).*

### Đã xong trong đợt 3: `code.build` dựng ra firmware THẬT

Mắt xích trung tâm của đề án — *sinh mã có nối về fact* — nay đã chạy đầu-cuối:
`code.build` → ELF `elf32-littlearm`, `architecture: armv7e-m` → `code.size` đọc số thật
(text 28 B, bss 4 B, flash_pct < 1% của 512 KB). Lệnh dựng lấy từ `docs/spec/isa/armv7e-m.yaml`,
chạy trong sandbox KHÔNG MẠNG.

**Phải sửa ba tầng trong lõi mới chạy được, và cả ba đều chưa ai chạm tới bao giờ** — vì không
test nào từng dựng THÀNH CÔNG (`test_code.py` chỉ kiểm nhánh hỏng). Xem [DEV-088](DEVIATIONS.md):

1. `execvp() of 'cmake' failed` — `code.build` truyền **tên trần** vào sandbox, mà `PATH` ở đó là
   bốn thư mục hệ thống. `code.static` và `env.install` đã giải `which()` sẵn; `code.build` thì
   không, và nó là cái quan trọng nhất.
2. `does not appear to contain CMakeLists.txt` — sandbox chạy ở thư mục **tạm**, trong khi
   `build.cmd` viết `-S .` và `artifact: build/*.elf`, đều tương đối so với gốc dự án. Thêm tham
   số `cwd` cho `Sandbox.run`, **ràng buộc phải nằm trong `allowed_dirs`** để không thành lối
   vòng qua SEC-25 §2.
3. `unable to find a build program corresponding to Ninja` — **công cụ tự gọi công cụ**. Giải
   `argv[0]` chữa được lệnh đầu tiên, không chữa được `cmake → ninja` hay `make → gcc`. Thêm
   `them_path`: đúng thư mục của những công cụ manifest ISA khai, không mở cả `PATH` người dùng.

### Việc ĐẦU TIÊN của phiên sau

| # | Việc | Ghi chú |
|---|---|---|
| ~~1~~ | ~~[DEV-089] ký lại `trusted_packages`~~ | **Xong 12/09.** Hoá ra lớn hơn một cái tên: `defaults.yaml` chỉ có **12/24** gói mà TGT-19 §3 kể — thiếu cả `cmake`, `ninja`, `cppcheck`, `avrdude`. Đo được: **7/8** công cụ mà manifest ISA khai đều vắng, chỉ `avr-gcc` khớp. Nay đủ 24 + `arm-none-eabi-gcc`/`-binutils`, đã ký (`5c1f3da12712…`), và **hai bài test giữ cả hai chiều** khỏi trôi lại |
| ~~2~~ | ~~`nghiem_thu_sprint3.sh`~~ | **Xong 12/09 — 13/13 ĐẠT.** Xem mục I5 |
| **1** | **Anh xem [DEV-088]** | Đề xuất SEC-25 v1.x nói rõ hai điều lõi đã làm: `PATH` gồm cả thư mục chuỗi công cụ đã khai, và thư mục làm việc có thể là gốc dự án khi năng lực đã khai `allowed_dirs` chứa nó |
| **2** | **[DEV-089] phần còn Mở** | `env.install` dùng `tool` làm luôn tên GÓI, nhưng `arm-none-eabi-size`/`objcopy` là **chương trình** đến từ gói `arm-none-eabi-binutils`. Đề xuất TGT-19 v1.x thêm trường `package` cho `toolchain.tools[]` |
| **3** | [DEV-083] kênh `var`/`gpio` → mở khoá `debug.*` (6 năng lực) | QEMU có gdbstub (`-s -S`); không cần `avr-gdb` |

### Bẫy mới, đừng đạp lại

- **Công thức `arm-none-eabi-gcc` của Homebrew KHÔNG kèm newlib.** `<stdint.h>` sẽ
  `include_next` sang một libc không tồn tại, và `ld` đi tìm `-lc`. Firmware bare-metal phải
  dịch với `-ffreestanding` và liên kết với `-nostdlib`. Cask `gcc-arm-embedded` có newlib nhưng
  là `.pkg` — **cần mật khẩu admin**, nên `env.install` (cấm sudo) không dùng được nó.
- **`CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY`** là bắt buộc cho toolchain bare-metal: phép
  thử trình dịch của CMake mặc định LINK một chương trình, việc không làm được khi không có libc.
- **Test có hạn giờ ngắn thì đua với bộ lập lịch.**
  `test_engine_khong_tu_dung_thi_het_gio_la_ket_thuc_binh_thuong` cho cả lượt chạy đúng 1 giây và
  đỏ rải rác khi chạy cùng cả bộ — dưới tải, shim chưa kịp in thì đã bị giết. Nay để 3 giây.

---

## Điểm dừng phiên 11/09/2026 **đợt 2**

*`make check`: **1352 test Python + 2699 test Swift** xanh (sau khi anh ký — xem P1). DEVIATIONS
còn **7 mục Mở**, tất cả là nợ hiện thực; **không còn mục nào chờ chủ sản phẩm**.*

**182/238 (76%) — số năng lực ĐỨNG YÊN, và đó là chủ ý.** Đợt 2 không thêm năng lực nào; nó làm
cho ba đường mã đã có chạy được thật, cộng hai lỗi im lặng (số 9 và 10).

### Mốc đạt được: `sim.*` chạy engine thật, và cổng kiểm nay phủ cả kho

`qemu-system-avr -M arduino-uno` chạy một ELF AVR qua chính `sim.run`, qua chính sandbox, trả
`captured.uart == ["E"]`. Trước hôm nay cả 44 test của nhóm đều đứng trên một shim luôn ngoan.

`make check` nay gọi cả phần Swift. Trước hôm nay nó chỉ gọi phía Python, và gói Swift đỏ hai
bài suốt năm ngày trong im lặng.

### Đã xong trong đợt 2

| Khối | Việc | Điều đáng nhớ |
|---|---|---|
| [DEV-086] | `fallback: qemu` cho `avr8.yaml`; TGT-19 **v1.2**, SIM-20 **v1.1** | ELF AVR **dựng bằng tay** trong test — 98 byte, năm lệnh mã máy — nên đường engine thật kiểm được mà không cần `avr-gcc`. Nhánh `TU_DUNG["qemu"] = False` lần đầu có engine thật chứng minh |
| WI-260 | `check-swift` vào `make check`; sửa 2 bài Swift mục rữa | `check-ca-hai` tách thành `check-py` ×2 kiến trúc + `check-swift` ×1 |
| WI-257 | `raw.githubusercontent.com` vào `trusted_sources` | Dữ liệu + mã + test xong; **chữ ký là việc của anh** — S47 nói thẳng tác tử tự thêm tên miền là REJECT G-WL-02 |
| [DEV-087] | `search.rank` đọc bảng nguồn hãng, không đọc danh sách trắng tải về | Xóa `_domain_tin_cay` và `_trusted` (mã chết); phép canh biên dấu chấm chuyển sang `_la_trang_hang`, nơi lỗ hổng nay thật sự nằm |

### Điều đợt 2 dạy được

- **Một cổng phải tự chạy thì mới là cổng.** `make geditor` tồn tại, đúng, và vô dụng — vì nó
  phải nhớ gõ. Cùng bài học với ba hằng số `timeout_s` của đợt 1: thứ trông như đang có hiệu lực.
- **Một bài test hết ngữ liệu im lặng y như một bài test sai.** `YAMLRealFilesTests` không hỏng,
  nó *hết việc*: ba cấp thư mục sau lần dọn chỉ còn một tệp YAML. Ngưỡng cũ `>= 2` quá thấp để
  báo động — nó vẫn xanh khi ngữ liệu tụt từ vài chục xuống hai.
- **Sửa một thứ đúng làm lộ một thứ sai.** Thêm một tên miền vào danh sách trắng làm mất một
  biên MỘT điểm, và biên ấy là thứ duy nhất giữ cho tc SEARCH-04 xanh suốt bốn ngày *vì lý do
  khác với lý do nó được viết ra*. Không thêm tên miền ấy thì không ai biết.
- **Ranh giới "tác tử không tự cấp quyền" là thật, không phải trang trí.** Tôi làm được mọi phần
  của WI-257 trừ đúng một lệnh, và đó là thiết kế đang hoạt động đúng.

---

## Điểm dừng phiên 11/09/2026 **đợt 1** (giữ lại làm lịch sử)

### Mốc đạt được: vòng sinh mã → dựng → mô phỏng → ghép đã liền

Chuỗi Z-05 "thêm tính năng" lên **14/16** và chỗ đứt dời từ `sim.run` sang `target.flash`. Không
chuỗi chuẩn nào còn chờ mô phỏng nữa — ba chuỗi dở dang đều đứt ở phần cứng hoặc registry.

> **Đọc lại sau đợt 2:** câu "vòng đã liền" đúng ở mức **phủ năng lực**, chưa đúng ở mức **đã
> thi hành**. Đợt 2 cho `sim.*` chạy engine thật, nhưng `code.build` thì `arm-none-eabi-gcc`
> vẫn chưa có trên máy — xem mục I7.

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
- ~~**Engine mô phỏng chưa lần nào chạy thật trên máy này**~~ — **hết đúng từ 11/09 đợt 2.**
  `qemu-system-avr` + `arduino-uno` chạy được; xem `test_duong_engine_THAT_chay_firmware_AVR_that`.
  Phần còn lại của nhóm vẫn dùng shim, và điều đó vẫn ổn: shim kiểm phần thuộc về EIDE, engine
  thật kiểm phần thuộc về engine.
- **`qemu-system-arm` KHÔNG có máy ảo cho họ STM32F4.** Đừng gán tạm `netduinoplus2` (STM32F405)
  để "cho chạy" — đó là chạy firmware trên một con chip khác chip nó được dịch cho, rồi báo ĐẠT.
- **`BIEN_THOI_GIAN_S = 20` cộng vào MỌI lượt chạy engine**, mà QEMU không tự dừng nên hết giờ
  chính là cách lượt chạy kết thúc. Một test engine thật để nguyên hằng số ấy sẽ một mình chiếm
  21 giây của `make check`; hạ nó bằng `monkeypatch` không đổi thứ đang kiểm.
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

## Bug đang mở — ghi 14/09/2026, chờ thiết kế lại usecase

| # | Bug | Đo được | Vì sao hoãn |
|---|---|---|---|
| ~~B1~~ | ~~`AutonomyBar` mất phím tắt ⌘⇧. của nút Dừng khẩn~~ | — | **Xong 15/09.** Test xanh trở lại |
| ~~B2~~ | ~~Màn Hộ chiếu từng hiện "không cần tham số"~~ | Ảnh chụp 15/09 và 16/09 trên bản dựng release: màn ra đủ biểu mẫu 6 ô rồi tới bảng 8 fact | **Xong 15/09**, do bản sửa đua `_manDangHoi`. Đã KIỂM BẰNG MẮT, không chỉ bằng test — đó là điều còn thiếu hôm 14/09 |

Cả hai đóng trong đợt dựng lại giao diện 15–16/09. Đợt ấy mở ra chín lỗi im lặng mới (số 36–44
trong [`TIEN-DO.md`](TIEN-DO.md) §6) và sáu mục sai khác [DEV-112]…[DEV-117] đang chờ chủ sản
phẩm. Ba lỗi nặng nhất trong chín cái **không phải lỗi giao diện**: một lỗ sandbox (tiến trình
con thừa kế stdin của daemon, tức ống JSON-RPC), một lỗi múi giờ trong bộ đếm ngân sách (bảy
tiếng đầu mỗi ngày không được tính), và một hiểu sai về Auto Layout (khung nhìn ẩn vẫn giữ chỗ).
Chúng lộ ra ở giao diện vì giao diện là chỗ duy nhất chạy cả hệ thống cùng lúc.
