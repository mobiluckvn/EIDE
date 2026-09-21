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
| I1 | **WI-253** — sinh test hợp đồng tự động cho 242 năng lực | `validate_specs.py` đã có; cần sinh test từ `input_schema`/`errors`. Bắt được lỗi E1000/E1004 mà không phải viết tay từng cái |
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

## Điểm dừng phiên 20/09/2026 — BẮT ĐẦU PHIÊN SAU TỪ ĐÂY

*Gói mới: **287 test Swift** xanh. `apps/eide --tu-kiem`: **70/70**. Python: **+20 bài** (hoàn tác ba mức, N4, N5, người sửa giữa chừng, tự lưu gộp). Checklist UXC-31:
**112 xong · 1 chưa · 5 chặn** (đầu phiên 20/09: 11 xong). **Mọi mục làm được đã xong** — 5 mục chặn vì chờ bo mạch, và 1 luật đọc tôi cố ý không tick. `make check` thoát 0. Màn
đã nối dữ liệu: **8/25** — và **nhóm TRI THỨC ĐÓNG TRỌN 5/5** (S4 Nhập tài liệu, S5 Hộ chiếu
chip, S6 Hộ chiếu mạch, S7 Bản đồ tri thức, S8 Xung đột tri thức; cả năm làm trong ngày). Cùng
với S1, S2, S25 của các nhóm khác. Danh mục năng lực lên **243** (thêm ARCHIVE-08).*

### Đã làm (21): DEV-133 nửa sau — **sổ DEVIATIONS về 0 mục `Mở`**

Khung xem tài liệu gốc dựng bằng **PDFKit** (framework của hệ, không thêm phụ thuộc): mở đúng
trang, bôi sáng bbox bằng `PDFAnnotation`. Annotation sống trong toạ độ TRANG nên nó đi theo
khi người dùng cuộn và phóng to; một lớp vẽ trên khung nhìn phải tự theo dõi hai thứ ấy và sẽ
trượt đúng lúc người ta nhìn kỹ nhất.

**Không đẩy sang Preview**: `NSWorkspace` không có đường mở PDF ở một trang cho trước, nên
người dùng sẽ nhận một tệp 400 trang mở ở trang 1 — và bbox mất hẳn. Hai thứ ấy chính là nội
dung của mục này.

**Tôi viết trùng một năng lực.** VIEW-11 hoá ra đã hiện thực từ trước; tôi viết một bản thứ hai
trước khi kiểm, và `ruff` bắt được (F811). Bản đã có nay thêm hai thứ giao diện không tự biết:
`uri` TUYỆT ĐỐI (đường tương đối mở từ thư mục làm việc của daemon trỏ vào chỗ khác chỗ người
dùng nghĩ), và `bbox_dang`/`origin`.

**Luật đọc bbox: khi cả hai cách đọc đều hợp lệ thì nói `khong-ro` chứ không chọn.** Bản đầu
của tôi trả lời chắc chắn cho một đầu vào mơ hồ — `[72,530,73,531]` ra "rong-cao" trong khi nó
gần như chắc chắn là hai góc. Bài kiểm bắt được, và phép sửa là siết LUẬT chứ không nới bài
kiểm: dùng trần khổ giấy để loại trừ, và dưới ngưỡng phân biệt thì trả "không rõ". Giao diện
gặp `khong-ro` thì **không vẽ** và nói vì sao.

### Đã làm (20): DEVIATIONS 15 → 1 trong một ngày

Mười bốn mục đóng. Ba nhóm, và mỗi nhóm một kiểu hỏng khác nhau.

**Nhóm 1 — TÀI LIỆU sai, mã đúng** (138, 139, 142, 143, 122, 137). UXC-31 lên v1.3: "San
Francisco / SF Mono 12,5" và "thẻ Run 9 pt" là ba con số **không có ở đâu trong bộ hồ sơ**;
"dưới ngưỡng 1100" là một trạng thái không tới được; "DENY" là một từ `PolicyGate` không bao
giờ phát ra. Đáng nhớ nhất là DEV-137: mã dùng 46/198 còn token nói 52/212, và vì mã không
đọc token nên hai con số ấy là **hằng chết** — không test nào đỏ. Nay `EideKhung` đọc thẳng
token, và `make check-gen` đỏ nếu ai sửa một bên.

**Nhóm 2 — đường ĐỌC còn thiếu** (135, 136). Cùng hình dạng, gặp lần thứ hai và thứ ba: một
mục §8 đòi màn hiện một thứ, tầng dưới có đường GHI đầy đủ, **không có đường đọc**.
`board.mark_lab` ghi `boards.<id>` mà không năng lực nào trong 244 cái đọc ra được.

**Nhóm 3 — hai mục lớn ở lõi** (121, 140).

DEV-121: mẫu chuỗi nay mang phần nối `${nX.field}`. Nhưng mắt xích thật nằm chỗ khác —
`_dung_chuoi` vẫn dựng nút từ `buoc`, **bản văn xuôi**, nên `when` thật, `on_ask` và `args`
đều bị bỏ. Đo lại Z-05: **14 nút thay vì 8**. Bản văn xuôi âm thầm nuốt 6 bước vì tên viết
tắt không phân giải được — đúng điều §4.4 nói mẫu sinh ra để tránh. Sáu chỗ nối phải đoán thì
để TRỐNG kèm lý do từng chỗ: viết bừa vào mẫu là biến một phỏng đoán thành đặc tả.

DEV-140: CHAT-06 nhận `plan_only`/`resume_of`, API-15 thêm `chat.resume`. `plan_only` **không
ghi `run.started`** — một thẻ Run cho lượt đang chờ người gật đầu là nói rằng tác tử đang làm
việc trong khi nó đang đợi. `resume_of` giữ nguyên `run_id` và đồ thị: lập lại kế hoạch ở bước
ấy có thể ra một chuỗi khác chuỗi người vừa gật đầu.

**Hai phép đo của tôi sai, cả hai theo kiểu "đếm nhầm thứ":** đếm tổng `cap.run.start` để đo
`plan_only` (chính lời gọi `chat.orchestrate` cũng ghi một bản), và đặt phép đo §2D.6 SAU dừng
khẩn nên cổng chặn mọi thứ. Và một phép đo **không đo được**: `chat.send` đi qua mô hình, tức
qua mạng và qua tiền — gỡ khỏi `--tu-kiem`, ghi rõ vì sao thay vì lặng lẽ bỏ.

### Đã làm (19): phần LÕI — 6.4, 6.5, 7.5, 7.6, 5.7, 10.1

**§6.4 bị chặn bởi BA lỗi cùng lúc, và cả ba đều im lặng** [DEV-144]:

1. `Router.undo_handlers` rỗng — mọi lần bấm Hoàn tác trả `applied: false` kèm lý do. Trung
   thực, và vẫn là một nút không làm gì.
2. `code.merge` commit **không truyền `ai=`**, nên cơ chế N4 mà `git.tac_gia` mô tả sẵn
   (`--author=^agent:run-<id>/`) chưa bao giờ có dữ liệu. Revert theo lượt luôn trả rỗng — và
   rỗng trông y hệt *"lượt này chưa ghi gì"*.
3. `project.rollback` coi tệp **chưa theo dõi** là cây bẩn. Mọi dự án EIDE đều có `.eide/` chưa
   theo dõi, nên lối thoát hiểm người ta tìm tới khi mọi thứ hỏng **từ chối chạy trên mọi dự án
   thật**.

**Phép sửa đầu tiên của tôi cho (3) rộng quá, và một bài kiểm cũ bắt được.** Tôi bỏ hẳn tệp chưa
theo dõi khỏi phép kiểm; `test_tep_moi_chua_commit_cung_chan_rollback` đỏ, và lý lẽ của nó đúng
— một tệp MỚI chưa commit không xung đột với tag nào, nên `checkout -B` mang nó sang nhánh vừa
quay lui, trộn mã dở dang vào một bản "đã về trạng thái tốt". Chỉ `.eide/` được bỏ qua.

**§7.5 — không bịa kiểu sự kiện mới.** Bản đầu tôi ghi `plan.replan_needed` vào sổ cái và nhận
E6001: API-15 khai 34 kiểu, không có kiểu ấy. Thêm một kiểu là sửa hợp đồng cho một dữ kiện vốn
thuộc về sự việc đã có — nên dấu `replan_for` nằm ngay trên bản ghi `human.file_save`. Lần lưu
LÀ sự việc; "nó trúng kế hoạch r_x" là một thuộc tính của nó.

**§5.7 — `git commit --amend` là chỗ DUY NHẤT trong cả kho viết lại lịch sử**, nên nó có bốn
điều kiện chặn: HEAD phải mang trailer `Eide-Autosave`, cùng tác giả, chạm đúng một tệp, và là
tệp này. *"Khi người rời tệp"* chính là lúc điều kiện thứ ba hỏng — mạch gộp tự kết thúc, không
sự kiện nào phải phát, không trạng thái nào phải nhớ giữa hai lời gọi. Gộp xong thì **huỷ mục
hoàn tác cũ**: nó trỏ vào một commit đã biến mất, và một nút lui bấm vào trả E7001 còn tệ hơn
không có nút.

**Một điều tôi KHÔNG xác nhận được:** job CI `eide-ui` thêm hôm qua chưa biết có chạy xanh trên
GitHub không — máy này không có `gh`. Hai chỗ có thể hỏng trên runner: `--tu-kiem` cần phiên đồ
hoạ để dựng `NSWindow`, và `python` trần (đã thêm `setup-python`). Ghi rõ trong chú thích §10.3.

### Đã làm (18): §10.3 CI, §11.1 bảng theo dõi, §11.2 luật tick — **§10, §11 đóng**

**Phát hiện đáng kể nhất của cả phiên: `apps/eide` chưa từng chạy trong CI.** Job `geditor` có
từ lâu cho gói CŨ; gói MỚI ra đời 18/09 và CI không hề đụng tới. 271 bài kiểm ấy chỉ chạy trên
máy tôi — một bộ kiểm không ai chạy ngoài tác giả là bộ kiểm hỏng vào đúng ngày tác giả quên
chạy. Nay có job `eide-ui`: bản sinh khớp spec → `swift build` → `swift test` → `--tu-kiem` trên
cửa sổ thật, **không** `continue-on-error`.

**Hai bộ sinh mới, và cả hai bắt lỗi ngay lần chạy đầu:**

- `bang_theo_doi_man.py` (§11.1) — bảng 25 màn sinh từ `EideManHinhDS` + `EidePhien.MAN` +
  `git log`. Bản đầu so **tên lớp** với **tiền tố** và in ra *"0 nối · 21 chưa"*: một bảng sai
  toàn tập mà đọc vẫn trôi chảy. Bắt được vì đọc bản in ra, không vì bài kiểm nào.
- `kiem_checklist.py` (§11.2) — luật "không tick nếu thiếu bằng chứng" nay là phép kiểm chứ
  không phải một câu trong tài liệu, vì để nó ở dạng câu là để nó phụ thuộc vào trí nhớ của
  chính cái nó ràng buộc. Lần chạy đầu bắt hai chỗ, trong đó **S18 bị để `[ ]` trong khi
  S17/S19/S20 đã là `[!]`**.

**Một luật tôi đã đi chệch, và không tick.** "Thứ tự hiện thực bắt buộc `3 → 4 → 5 → 6 → 8`":
đúng ở khúc đầu (§7 làm trước mục 8), sai ở khúc sau — 21 màn dựng xong rồi mới quay lại §3/§4.
Không hỏng gì, nhưng một luật không được tick bằng một lần đi chệch có hậu quả tốt.

### Đã làm (17): §6.1 modal ASK, §9 trợ năng, §10.2 — và **§0 đóng**

Tám mục: 6.1, 9.1–9.4, 10.2, B1, và một nửa 10.1.

**B1 đóng được là nhờ §10.2, không nhờ cố nghĩ thêm.** Hôm qua tôi để ngỏ B1 vì "không có đường
nào" phủ định *mọi* đường, mà bài kiểm chỉ đi được những đường nó biết. §10.2 chỉ đúng cách đo
gián tiếp: **cắt nguồn sự thật rồi khẳng định màn hình đứng yên**. Một widget giữ trạng thái
nguồn riêng sẽ tiếp tục nhúc nhích ở đó. Kèm vế ngược — nghe được sự kiện thật thì PHẢI đổi —
không thì bài trên xanh cho cả một giao diện chết hẳn.

**Ba lần đo của chính tôi sai, cả ba theo kiểu khác nhau:**

1. **Bài kiểm nhãn trợ năng xanh giả.** `accessibilityLabel()` của AppKit **mặc định trả về
   chính `title`**, nên `▁` có nhãn `▁` và phép kiểm "nhãn có rỗng không" mù đúng với nhóm nút
   nó sinh ra để bắt. Siết lại thì lộ 4 nút × 21 màn.
2. **Bảng N1…N10 điền từ trí nhớ sai hai ô** — `EideDieuHuongTests` không tồn tại, và tên hàm
   N3 tôi nhớ nhầm. Bảng ấy nay là MÃ đối chiếu runtime, nên nó tự bắt được.
3. **Rồi chính bảng ấy nói sai theo chiều ngược lại**: hàm kiểm `async` lộ ra ObjC dưới tên
   `…WithCompletionHandler:`, nên hỏi mỗi tên trần sẽ báo THIẾU cho một bài đang chạy tốt.

**Một lỗi thật ở §9.4:** `EideDock.datCao` không theo cờ "Giảm chuyển động". Hai chỗ nhấp nháy
nhỏ đã theo từ đầu, còn chỗ này — khối 272 pt trượt lên xuống, hoạt ảnh **lớn nhất** cửa sổ —
thì không. Người bật cờ ấy vì chuyển động làm họ chóng mặt vẫn nhận đúng chuyển động mạnh nhất.

**10.1 để MỘT PHẦN, 8/10.** N4 (6.4) và N5 (6.5) ghi `nil` kèm lý do chứ không trỏ bừa vào một
bài gần đúng: `Router.undo_handlers` rỗng theo thiết kế đã ghi, nên viết bài kiểm đòi revert
chọn lọc bây giờ là ép lõi hứa thứ nó đang nói thẳng là chưa làm.

### Đã làm (16): §3 Luồng làm quen và §4 Bảng lệnh — **cả hai đóng**

Tám mục. Hai thứ dựng mới: `EideToast` (§4.3) và `EideFormThamSo` (§4.4 — sinh từ
`caps.describe`, không từ bảng chép tay; 244 năng lực thì một bảng chép tay lệch ngay ở lần sửa
hợp đồng đầu tiên, và lệch im lặng).

**Ba lỗi thật, cả ba do bài kiểm ép ra — và một cái tôi vừa tự viết doc-comment cảnh báo:**

1. **`NSPopUpButton` LÀ một `NSButton`.** Nhánh boolean đứng trước nên nuốt mọi ô enum:
   `conThieu()` thấy chúng luôn có giá trị → nút Chạy sống ngay từ lúc mở form → tham số gửi đi
   là `true`/`false` thay cho lựa chọn. Với `passport.query` thì `predicate: false`.
2. **Popup bắt buộc tự chọn hộ người dùng.** Tôi bỏ mục rỗng cho ô bắt buộc với lý do "kiểu gì
   cũng phải chọn" — đúng cái lỗi mà đoạn tài liệu ngay trên nó vừa cảnh báo: form gửi đi lựa
   chọn ĐẦU TIÊN trong enum như thể người dùng đã chọn nó.
3. **Esc chỉ đóng bảng lệnh khi con trỏ CÒN trong ô tìm.** Nhánh `cancelOperation` nằm trong
   `control(_:textView:doCommandBy:)`; bấm vào một kết quả rồi đổi ý là Esc chết.

**[DEV-143] — §4.3 dùng một từ cổng không bao giờ phát ra.** Tài liệu viết "APPROVE/ASK/**DENY**";
`PolicyGate` phát `APPROVE`/`ASK`/**`REJECT`**. Phát hiện bằng chính phép đo viết theo tài liệu:
nó HỎNG với chuỗi thật `REJECT · project.status · cổng * · STOP — Phiên đang dừng khẩn (E3002)`.
Toast nay tô màu theo NGHĨA chứ không theo danh sách tên, nên một quyết định thứ tư sau này cũng
không lọt qua thành màu trung tính.

**Và một phép đo vô nghĩa tôi suýt để lại:** bài tự kiểm §4.4 ban đầu dùng `passport.query`, mà
hợp đồng của nó khai `required: []` — xanh hay đỏ đều không nói gì về §4.4. Đổi sang
`kg.neighborhood` (R0, `node` bắt buộc).

### Đã làm (15): §0 bất biến và §1 hệ thống thiết kế

Bảy mục nữa: B3, B6, B7, B8, 1.2, 1.3, 1.4. Cả bảy **xanh ngay lần chạy đầu** — mã vốn đã đúng;
việc ở đây là dựng bài kiểm để nó không trôi đi.

**§1.2 và §1.3 hoá ra là CHECKLIST sai, không phải mã sai** [DEV-142]. §1.2 nói "San Francisco,
SF Mono 12,5 pt", §1.3 nói "thẻ Run 9 pt". UXD-13 v2.0 nói IBM Plex Sans 13 / IBM Plex Mono 12
và bộ bán kính `[6, 8, 10]` — không có 9. Ba con số ấy không có chỗ nào trong bộ hồ sơ sinh ra
chúng, và quy tắc đọc in ngay đầu UXC-31 ghi rõ *"mâu thuẫn thì UXD-13 v2.0 thắng"*. Nên tick
theo mã là đúng luật. Bài kiểm chốt mã vào **token** chứ không vào con số chép tay, để lần sau
tài liệu đổi thì nó đỏ — chứ không lặng lẽ lệch đi như [DEV-137].

**B1 để ngỏ, có chủ ý.** Phần đo được thì đã đo. Phần chưa đo được là mệnh đề tổng quát "không
có đường nào" — nó phủ định *mọi* đường, mà một bài kiểm chỉ đi được những đường nó biết. Dòng
đầu tài liệu ghi: không đánh dấu mục chưa có bài kiểm chứng minh.

### Đã làm (14): bảy mục cuối của §2 — **§2 đóng**

2.2 cỡ tối thiểu + dải hẹp 44 pt · 2.3 bài kiểm N7 · 2A.2 popover chuyển dự án · 2D.4 placeholder
theo pha · 2D.6 thẻ Ý hiểu · 2E.6 báo cáo khi run xong · 2F.5 hoàn tác của người.

**Ba mục hoá ra là lỗi ở tầng dưới, không phải việc của giao diện:**

1. **§2.2 tự mâu thuẫn** [DEV-139]. "Cửa sổ tối thiểu 1100 × 700; **dưới ngưỡng** thì cột phải
   thu lại" — mà một bề ngang tối thiểu đã được `NSWindow` cưỡng chế thì không bao giờ xuống
   dưới được, nên dải icon 44 pt là mã chết theo nghĩa đen. Đọc là *tại* ngưỡng: giữ được cả
   hai vế, không phải bịa thêm con số nào.
2. **§2D.6 bị chặn một nửa** [DEV-140]. `chat.orchestrate` dựng chuỗi VÀ chạy nó trong cùng một
   lời gọi, nên không có chỗ dừng để người gật đầu. Thẻ Ý hiểu in được câu và danh sách bước;
   hai nút thì **không hiện**, và thẻ nói thẳng vì sao. Một nút "Đúng — làm đi" đặt trên việc đã
   làm xong dạy người dùng rằng bấm hay không đều thế, rồi họ thôi đọc cả thẻ.
3. **§2F.5 đo được, và lần đầu đo là KHÔNG ĐẠT** [DEV-141]. `code.human_save` ghi sổ cái mà
   không gọi `undo.register`, nên khối "Hoàn tác được" chỉ chứa việc của MÁY — đúng sự phân biệt
   §2F.5 cấm. Mục này trước ghi "chưa đo được"; *chưa đo* khác hẳn *đã đo và trượt*.

**Ba lỗi thật khác, cả ba do phép đo ép ra:**

- `_dang_ky_undo` ghim cứng `cap="code.merge"` cho mọi người gọi → nhãn cột phải sẽ dán tên một
  lần merge lên một lần người bấm Lưu.
- Đổi hằng ràng buộc TRONG `layout()` chỉ đánh dấu cần bố cục lại, nên cột phải báo `hep = true`
  mà bề ngang vẫn 236 pt. Bắt được bằng `--tu-kiem` 17b trên cửa sổ thật.
- `_chuTrong` của bài tự kiểm chỉ đọc `stringValue`, nên nó **mù** với placeholder và tiêu đề
  nút — tức mù với hai trong ba phần của popover §2A.2, và báo HỎNG cho một popover dựng đúng.

Và một bài kiểm tôi viết sai theo chiều ngược lại: đòi `undo.apply` đảo được nội dung tệp.
`Router.undo_handlers` rỗng **theo thiết kế đã ghi** — mọi lần bấm trả `applied: false` kèm lý
do. Đòi hệ thống hứa một thứ nó đang nói thẳng là chưa làm là ép mã đi nói dối cho bài xanh.

### Đã làm (13): bảy chỗ bấm của §2 — và hai ghi chú hôm qua tôi viết sai

2A.3 huy hiệu tự chủ → S25 · 2A.4/2A.5 hai bộ đếm → cuộn tới khối ở cột phải · 2C.1 kéo đổi thứ
tự tab · 2C.3 "không cướp màn" · 2D.2 ba luật tự chuyển chiều cao · 2D.3 ease-out.

**Luật đáng nhớ nhất là 2C.3.** Người vừa tự chọn một màn thì trong 20 giây họ đang ĐỌC nó; kéo
màn hình đi lúc ấy làm mất chỗ đang đọc và không có nút quay lại. Nên `moMan` nay trả về *có
chiếm được vùng làm việc hay không*, và vùng trao đổi nói hai câu khác nhau cho hai trường hợp.
Tab vẫn được thêm, cột trái vẫn nháy, badge vẫn lên — giấu hẳn việc của tác tử còn tệ hơn cướp
màn.

**Hai ghi chú 20/09 của tôi sai theo chiều "chưa làm":** 2D.2(a) và (c) đã có trong mã từ trước,
2D.3 cũng thế. Tôi đã ghi "chưa" cho cả ba. Cùng một lỗi đo với vụ `grep -c "doan"` hôm qua, và
lần này nó suýt làm tôi viết lại thứ đã chạy.

**Ba lỗi thật, cả ba do bài kiểm ép ra:**

1. `window?.firstResponder === oGo.currentEditor()` cho `nil === nil` → **`true`**, nên luật
   §2D.2(c) chặn đúng những lần đổi chiều cao lẽ ra phải cho qua. Đúng trong ứng dụng thật (cửa
   sổ luôn có), sai ở mọi đường không có cửa sổ — và sai im lặng.
2. Cột phải cuộn NGƯỢC: `NSStackView` không lật còn `EideKhungLat` thì có, nên lấy thẳng `minY`
   đưa khối đầu tiên xuống đáy.
3. Bài kiểm "gõ liên tục 5 giây" của chính tôi nhảy 5 giây trong một bước — mà đó chính là một
   lần ngắt tay. Bài sai, không phải mã.

Thêm hai phép đo vào `--tu-kiem` (nay **61/61**) cho đúng hai nhánh `swift test` không chạm tới:
§2D.2(c) cần `firstResponder` thật, §2C.3 cần cả phiên. [DEV-138] ghi con số `NGAT_GO = 1,5` s —
UXC-31 nói "liên tục" mà không định nghĩa, và không định nghĩa được thì không đo được.

### Đã làm (12): đối chiếu UXC-31 với mã — 11 → 62 mục xong

Checklist là §11 Definition of Done của giao diện và nó đã thôi đo được. Đây là đối chiếu VỚI
MÃ: mỗi mục kiểm bằng một lần đọc mã hoặc một phép đo `--tu-kiem`; mục chưa làm ghi RÕ còn
thiếu gì. §8 trước đó mới tick 6 màn trong khi 21 màn đã chạy — chính thứ trôi mà việc này sửa.

**Hai lần suýt ghi sai, cả hai là bài học về cách đo:** `grep -c "doan"` trả 0 cho thanh tiến
độ chia đoạn vì mã dùng `_mauDoan` (grep phân biệt hoa thường) — một phép đo sai hướng tệ hơn
không đo, vì nó đẻ ra một dòng tài liệu sai. Và §2.1 lộ ra [DEV-137].

*(Số trong commit `1151141` ghi "47 chưa" — đo lại là **51**. Tôi viết con số ấy trước khi
chạy phép đếm.)*

### Đã làm (11): nhóm HỆ THỐNG S21–S24

### Đã làm (10): S3 Bản đồ luồng + S16 Mô phỏng — 21/25 màn

### Đã làm (9): S14 Trình soạn thảo + S15 Diff & cổng merge — nhóm MÃ NGUỒN đóng

UXC-31 mục 5 trọn (6/7 — xem ghi chú 5.7) và §6.3.

**Đọc từ ĐĨA, ghi qua CỔNG.** Không RPC nào đọc mã nguồn, và đó là chủ ý: `code.human_save`
nhận `base_content`, tức hợp đồng giả định bên gọi đã tự đọc tệp. Đọc một tệp không phải hành
động cần chính sách; ghi thì có.

**Lề hai dấu là luận điểm của cả sản phẩm trên một cột 26 pt**: ● xanh = hằng số trỏ về fact đã
duyệt, ▎đỏ = hằng số phần cứng không nguồn và `G-FACT` sẽ chặn merge. Hai dấu khác nhau cả HÌNH
lẫn MÀU — bản in đen trắng và mắt mù màu vẫn phải phân biệt được hai trạng thái trái ngược.

**S14 KHÔNG có nút "ghi đè"** (§5.5). Không phải vì quên: một nút như thế biến cả cơ chế merge
ba bên thành tuỳ chọn.

**S15 dựng lại đúng `EideTheXungDot` của S8** (§6.3), có bài kiểm tìm đúng lớp ấy trong cây
khung nhìn. Nút thứ ba là *Soạn tay* và nó KHÔNG gọi năng lực — nó đưa người về S14.

### Đã làm (8): nhóm THIẾT KẾ S10–S13 + `view.artifacts` (VIEW-14)

Chủ sản phẩm chốt hướng 2: MỘT năng lực cho mọi loại hiện vật thay vì bốn năng lực riêng.
Danh mục lên **244**. Trước nó, **không cái nào trong 243** liệt kê được một hiện vật kỹ nghệ
đã lưu — nên bốn màn hoặc không dựng được, hoặc mỗi lần mở là một lần tiêu tiền mô hình.

`R0` **không** có nghĩa là "chỉ đọc trạng thái có sẵn": `req.elicit` là R0 nhưng gọi mô hình,
`arch.adr` là R0 nhưng ghi tệp. Có một bài kiểm chạy cả bốn màn và cấm chín năng lực sinh.

### Đã làm (7): S9 Làm rõ yêu cầu

### Đã làm (6): §7 Đồng bộ sự kiện — nền mà ta làm sau tám màn

`EideDangKySuKien` (§7.1) · mốc `seq` + nhảy quãng + nút Tải lại (§7.2) · badge cho màn đóng
(§7.3 nửa đầu). Checklist UXC-31 nay tick được 7.1 và 7.2; 7.3 đánh dấu **nửa**.

**Bảng đăng ký là chỗ DUY NHẤT** trả lời "sự kiện này đi tới những màn nào" — nên nó là dữ
liệu tĩnh chứ không phải mỗi màn tự gắn tay nghe. 22 tên sự kiện lấy từ `EideMethod` (sinh từ
`openrpc.json`), không chép tay.

*"Không màn nào subscribe tất cả"* (§7.1) kéo ngược với *"Nhật ký — nghe: mọi loại"* (§8 S2).
Hoà bằng `TAT_CA` — một hằng số **có tên** thay vì chuỗi `"*"`: bảng vẫn đọc được, và một sự
kiện mới vẫn phải được ai đó quyết cho chảy vào đâu. Có bài kiểm đòi đúng một màn được dùng nó.

**Hai lỗi tôi tự tạo ra rồi tự bắt, cả hai đều là vòng lặp:**

| # | Lỗi | Đo được |
|---|---|---|
| 1 | Màn nạp dữ liệu → sinh sự kiện → **tự nạp lại** → vô tận | `--tu-kiem` treo ở màn đầu. Cùng hình dạng lỗi NT2 sáng cùng ngày, ở chỗ khác — nên phép phân biệt "đổi trạng thái" / "tiếng vọng của lời gọi đọc" nay có MỘT tên và MỘT chỗ. Bản đầu chỉ lọc `run.progress`, còn `gate.decided` của cùng lời gọi vẫn lọt: mỗi lời gọi sinh ba bản ghi sổ cái |
| 2 | Nạp lại NGAY ở mỗi sự kiện — đúng thứ §7.3 cấm | Màn Nhật ký (nghe mọi loại) mất **7,68 s** thay vì 0,35 s. Nay gộp trong cửa sổ 0,4 s |

**Chưa làm:** §7.3 nửa sau — *diff render*. Cách lùi là nạp lại chính màn ấy qua điểm mở rộng
`EideManCoSo.apDung`; mặc định trả `false` để **đếm được** còn bao nhiêu màn chưa làm, và có
một bài kiểm giữ con số đó khỏi trôi trong im lặng.

### Đã làm (5): S6 Hộ chiếu mạch — đóng nhóm TRI THỨC

`diagram.pinmap` · `board.check_pins` · `board.constraints` · `board.propose_fix` ·
`board.mark_lab`. S5 nói *con chip* biết gì; S6 nói *tấm mạch trước mặt* nối những gì vào đâu —
và mọi xung đột chân đều sinh ra ở chỗ hai nguồn ấy giao nhau.

**Khai báo mạch lab là một lời khai về AN TOÀN**, nên màn không có nút "đánh dấu lab": nó có
hai ô xác nhận và nút chỉ sống khi cả hai được tích. BOARD-05 trả E1000 khi thiếu một — một nút
bấm được rồi mới báo lỗi là một nút dạy người dùng bỏ qua thông báo.

**Ba lỗi chạy thật trên netlist bắt được:**

| # | Lỗi | |
|---|---|---|
| 1 | Bảng chân rỗng **kết thúc cả màn** — mất luôn khối ràng buộc và khối khai báo lab | `diagram.pinmap` cần fact `pin_function` của hộ chiếu CHIP, trong khi `check_pins` và `constraints` chạy được trên chính netlist ấy. Đo thật: bảng 0 hàng, mà `check_pins` tìm ra một net I2C thiếu điện trở kéo lên |
| 2 | `bus_limits · {1 khoá}` giấu mất câu `why` | Câu ấy — *"kéo lên 4700 Ω ≤ 4700 Ω — đủ nhanh cho Fast-mode 400 kHz"* — nói giới hạn đến TỪ ĐÂU, nên người đọc kiểm lại được thay vì phải tin. Nay trải phẳng tới lá |
| 3 | Từ điển rỗng hiện `{0 khoá}` | Đếm thay vì nói. `voltage.rails` rỗng nay đọc là "chưa có" |

Lỗi 2 còn lộ ra hai câu lõi **tự thú nhận nó chưa biết** (`current.why`, `voltage.why`) — trước
đó bị giấu sau một con số.

**Một mục chờ chủ sản phẩm:** [DEV-135] — UXC-31 đòi hiện *trạng thái khai báo mạch lab*, nhưng
`board.mark_lab` ghi `boards.<id>` vào `autonomy.yaml` mà **không năng lực nào trong 243 cái đọc
ra khóa ấy**. Cùng hình dạng [DEV-134]. Đề xuất mở rộng `policy.rules` trả thêm `boards` — nó
vốn đã là "bảng quy tắc đang có hiệu lực + trạng thái niêm", không thêm năng lực mới.

### Đã làm (4): S7 Bản đồ tri thức & hỏi đáp

`view.kg_map` (VIEW-01) · `view.rag_ask` (VIEW-07) · `view.rag_trace` (VIEW-08).

**Đồ thị bố cục theo CỘT, không lực đẩy.** Đồ thị tri thức của EIDE có hướng đọc tự nhiên —
nguồn → fact → chủ thể → mã — và đó là hướng người ta lần một con số về tới trang datasheet đẻ
ra nó. Bố cục lực đẩy đặt nút ở chỗ khác nhau sau mỗi lần mở: đẹp hơn, và không so được hai lần
mở, không chụp ảnh đối chiếu được, không viết được phép kiểm. Bố cục cột thì **tất định** — có
một bài kiểm đảo ngược thứ tự đầu vào và đòi ra đúng cùng một hình.

**Ràng buộc nặng nhất của cả sản phẩm nằm ở màn này**, và màn giữ nó tới điểm ảnh cuối cùng:
lõi trả câu trả lời mà `citations` rỗng thì màn **không hiện câu trả lời** — có bài kiểm cho
đúng điều đó. `not_found` KHÔNG hiện như lỗi: nó là kết quả đúng, và là chỗ duy nhất trong sản
phẩm mà trả về rỗng nghĩa là làm đúng việc.

**Một lỗi lõi ảnh chụp bắt được:** sáu trong mười một nút hiện ra là **mã băm**
(`f_0b8108e3143a10f9`). Id của fact không phải IRI, nên nhãn "đoạn cuối của IRI" trả nguyên mã
băm — và cả màn ấy tồn tại để trả lời "máy biết những gì". Đã sửa `view._thuoc_tinh_nut` để nút
fact mang nhãn `subject·predicate` (`periph:I2C1·base_address`); nút chủ thể giữ nguyên IRI, vì
gán nhãn một fact cho chủ thể sẽ chọn tên theo thứ tự dòng SQL.

### Đã làm (3): S4 Nhập tài liệu — và một lỗi lõi mà việc ĐỌC lôi ra trước khi viết mã

Vùng kéo-thả + đường ống `ingest.classify` → `ingest.hash_dedupe` → extractor của từng tệp MỚI
→ `ingest.index_text` cho README/md. Khử trùng chạy TRƯỚC khi trích, vì cả điểm của nó là tránh
chạy lại một lượt trích đắt tiền. Đã kiểm đầu-cuối trên lõi thật: `.svd` → `extract.svd` → 2
fact → `store.write`; `README.md` → không extractor → chỉ mục toàn văn.

**Lỗi lõi tìm được TRƯỚC khi viết dòng giao diện đầu tiên.** `ingest.classify` sinh trường
`extractor` để bên gọi dispatch — và **7 trong 16 dòng của `BANG_KIND` trỏ tới năng lực KHÔNG
TỒN TẠI**: `extract.binding`, `extract.header`, `extract.image`, `extract.kicad`,
`extract.netlist`, `extract.csv`, `extract.html`. Chúng là tên rút gọn của `kind` chứ không phải
tên năng lực, và gồm những loại tệp thường gặp nhất: header C, netlist KiCad, CSV. Không test
nào thấy vì **chưa bên gọi nào từng dispatch trên trường ấy** — S4 là bên gọi đầu tiên. Đã sửa,
và `test_extractor_deu_la_nang_luc_co_that` giữ bảng khỏi rữa lại.

Bẫy thứ hai cùng chỗ: biết gọi cái gì chưa đủ, còn phải biết truyền tệp vào ĐÂU. Bảy extractor
nhận `file`, nhưng `archive.list` nhận `path` và `extract.bom` nhận `sources` (một MẢNG) — nên
một vòng dispatch ngây thơ trả E1000 cho đúng hai loại tệp. `test_extractor_nhan_tep_qua_dung_
ten_tham_so` đọc thẳng `input_schema` để phía Python đỏ trước khi giao diện kịp câm.

**Hai lỗi hiển thị chỉ ảnh chụp bắt được:** `reason` của `store.write` là chuỗi RỖNG trong đường
thường gặp nhất (`passport.import` không nhận `reason`), nên `?? "…"` không cứu được và cả cột
trống trơn — nay nhận dạng bằng `batch_id`. Và cột `FACT` đổi thành **FACT MỚI**: `store.write`
đếm fact GHI RA, nên một lô gộp hết cho số 0, đúng mà đọc thành "lần nhập này hỏng".

**Một mục chờ chủ sản phẩm:** [DEV-134] — UXC-31 đòi *bảng nguồn thường trực kèm trạng thái
duyệt*, nhưng **không năng lực nào trong 242 cái đọc ra bảng `source`**. S4 hiện hai bảng thật
thà hơn (lượt nhập vừa chạy · lịch sử nhập từ sổ cái) và tiêu đề nói thẳng nó không phải danh
mục nguồn. Đề xuất thêm `archive.sources` — S6 và S13 rồi cũng sẽ cần.

### Đã làm (2): S8 Xung đột tri thức — và thẻ dùng chung mà §6.3 bắt buộc

`view.conflict_board` (VIEW-04) cho hàng hai vế · `kg.conflicts` (KG-02) cho `resource_ready` ·
`kg.resolve_conflict` (KG-06) cho hành động. Thẻ nằm trong `EideTheXungDot` và **không biết gì
về fact** — nó nhận một nhãn, một giá trị, vài dòng phụ và một khoá — nên S15 dùng lại nguyên
nó cho xung đột MÃ, đúng điều §6.3 cấm viết màn riêng. Có một bài kiểm dựng thẻ ấy bằng dữ liệu
MÃ để ràng buộc này không mục đi trong im lặng.

**Ba điều màn này phải nói mà dữ liệu không tự nói**, mỗi điều một bài kiểm: `resource_ready =
false` KHÁC "sạch" (thiếu `hw_map` thì phần tài nguyên chưa hề được kiểm) · bấm nút **không** áp
dụng ngay (KG-06 là T2, lời gọi dừng ở `pending` và rơi vào *Chờ tôi*) · rỗng phải kèm quyết
định gần nhất, đọc từ **sổ cái** chứ không từ một bảng riêng.

**Bốn thứ ảnh chụp và lõi thật bắt được mà test giả không bắt:**

| # | Lỗi | Ghi chú |
|---|---|---|
| 1 | Câu `detail` của lõi in giá trị **hệ 10** và nguồn bằng **mã băm**, nằm ngay trên hai cột in đúng hai con số ấy ở hệ 16 kèm tên tệp | Chính docstring `kg._hai_ben` đã ghi `detail` là câu cho sổ cái, "vô dụng cho một màn quyết định". Đã bỏ khỏi thẻ |
| 2 | Hai vế **bất đối xứng**: lõi chỉ đánh `status=conflict` cho fact ĐẾN SAU, fact đến trước giữ `normalized` — nên A hiện "vàng · chưa duyệt" còn B hiện "⚠ XUNG ĐỘT" | Đọc như chỉ một bên bị tranh chấp. Trong thẻ xung đột, cả hai nhãn ấy đúng mà không phân biệt → bỏ cả hai, giữ tầng |
| 3 | Bản đầu viết cứng *"cổng G-FACT hỏi người"*. Lõi thật trả `rule: DEFAULT, gate: "*"` — quy tắc bắt hết theo mức tự chủ | Một câu nghe có thẩm quyền, khớp tài liệu, không khớp máy. Nay dựng từ chính `decision` |
| 4 | `--tu-kiem` 6c chấm **ĐẠT** cho một màn rỗng vì **E2000** | Đúng chỗ yếu của bản nới lỏng 6c hôm nay: câu "không đọc được…" cũng có đủ hai phần. Nay 6c trượt khi lý do là lỗi; và S8 nhận ra E2000-thiếu-store là "chưa có tri thức", không phải sự cố |

**Chưa làm trong S8:** UXC-31 đòi *"đã quyết → dòng lịch sử ghi tên người + thời điểm"* dưới mỗi
xung đột đã giải. Hiện xung đột đã giải chỉ rời khỏi danh sách; lịch sử mới hiện ở trạng thái
rỗng. Sổ cái đã có đủ dữ liệu (`gate.human` kèm `note`), nên đây là việc vẽ, không phải việc nối.

### Đã làm (1): S5 Hộ chiếu chip — màn đầu của nhóm TRI THỨC

`passport.query` (PASSPORT-02) + `view.provenance` (VIEW-03). Chip đọc từ mục tiêu đã ghim của
dự án, nên trạng thái rỗng đúng câu UXC-31 §8 S5 quy định. Bảng có địa chỉ hệ 16, kích thước
kèm KiB, tầng, và nguồn kèm `tr.<trang> [bbox]`. Kiểm bằng MẮT trên hộ chiếu ATmega328P thật
(287 fact), không chỉ bằng test.

**Năm lỗi im lặng mà màn này lôi ra — bốn cái KHÔNG phải của nó:**

| # | Lỗi | Vì sao không test nào thấy |
|---|---|---|
| 1 | **NT2 đẩy một màn ra khỏi chính nó.** Mở S5 → S5 gọi `project.status` để biết chip đã ghim → NT2 thấy năng lực ấy thuộc màn Tổng quan → nhảy sang Tổng quan. Ảnh `man-Passport.png` ra một màn Tổng quan thân trống | Cả hai màn đều đúng ở mức đơn vị; chỗ hỏng nằm GIỮA chúng. `_theoRun` đã có đúng bộ lọc cần dùng từ 18/09, NT2 ngay trên nó thì chưa |
| 2 | **`bit_range [0, 1]` hiện thành `[false, true]`.** `(0 as NSNumber) as? Bool` THÀNH CÔNG trên Darwin, nên một nhánh Bool đứng trước nhánh số nuốt mọi 0/1 | Giá trị vẫn là mảng hai phần tử, vẫn đúng kiểu. Chỉ là nó nói khác datasheet |
| 3 | **Ô dài hơn cột đẩy cả đuôi hàng lệch một cột.** Điểm dừng tab là mốc tuyệt đối. Hàng `field:AIN0D` hiện "vàng · chưa duyệt" nằm dưới tiêu đề NGUỒN | Đọc như một fact có nguồn tên "vàng" — sai, mà trông như một lựa chọn trình bày xấu |
| 4 | **Cột TẦNG mâu thuẫn với chính cổng hằng số.** 287 fact đều `gold`+`normalized`: tóm tắt nói "vàng 287", mọi hàng nói "chưa duyệt", còn `code.constant_guard` thì CHO cả 287 đi qua (vàng thì qua kể cả chưa duyệt) | Ba câu về cùng một thứ, không câu nào sai riêng lẻ. Nay ghép thành `vàng · chưa duyệt` |
| 5 | **`--tu-kiem` 6c coi mọi màn rỗng là hỏng.** Một dự án vừa tạo KHÔNG có tri thức, nên S5 rỗng ở đó là ĐÚNG | Nó từng "ĐẠT" chỉ vì lỗi số 1 khiến phép đo đo nhầm màn khác. Nay 6c đòi rỗng ĐÚNG HAI PHẦN (B5) và IN RA lý do |

**Một mục chờ chủ sản phẩm:** [DEV-133] — UXC-31 đòi *ô nguồn bấm được*; bảng của gói mới là
MỘT `NSTextField` (có chủ ý, vì hai bản dựng-nhiều-khung-nhìn trước đều hỏng bố cục) nên chỗ
bấm tạm nằm dưới bảng. Trang và bbox vẫn hiện đủ.

**Một con số đáng nhớ:** trong `bang()`, dựng chuỗi có thuộc tính cho 287 hàng mất **6 ms**;
dựng `NSTextField` từ chuỗi ấy mất **~200 ms**. Tôi đã đi tối ưu nhầm chỗ một vòng trước khi đo.

**Làm tiếp — không cần phần cứng:**

1. **Hết việc tồn.** UXC-31 còn 5 mục chặn vì chờ bo mạch (S17–S20) và 1 luật đọc cố ý
   không tick; **sổ DEVIATIONS về 0 mục `Mở`** lần đầu kể từ 05/09. Việc kế tiếp là việc MỚI,
   không phải việc dọn: bốn màn chờ phần cứng, và §7.3 diff render cho 20 màn còn lại.
2. **§7.3 nửa sau** — diff render. S14 là màn DUY NHẤT đã hiện thực `apDung`; 20 màn còn lại
   dùng cách lùi (nạp lại, gộp 0,4 s).
3. **§3 Luồng làm quen** (4 mục) và **§4 Bảng lệnh** (4 mục) — chưa chạm.
4. **7 mục DEVIATIONS `Mở`**, trong đó [DEV-134]/[135]/[136] cùng một hình dạng.
**Rồi §7 Đồng bộ sự kiện** — chủ sản phẩm chốt 20/09 làm nó ngay sau nhóm TRI THỨC, trong khi còn
5 màn phải sửa thay vì 21. Sau đó S14 Trình soạn thảo. Ba thứ CHƯA nối vẫn nguyên: `chat.answer`,
phím tắt ngoài ⌘K/⌘⇧., bộ chuyển dự án.

> **Bẫy đã biết:** `kg.conflicts`/`kg.resolve_conflict` **KHÔNG có alias JSON-RPC** (ghi chú
> 18/09 nói có là nhầm) — S8 phải đi qua `caps.invoke`. Và `predicate` của fact là enum ĐÓNG 16
> giá trị trong `docs/spec/data/json/fact.json`: fixture giao diện mang vị từ ngoài enum là
> fixture không bao giờ gặp lại ngoài đời.

---

## Điểm dừng phiên 18/09/2026 (lịch sử)

*Cây làm việc SẠCH, 4 commit trong ngày. **1628 test Python · 3116 Swift gói cũ · 29 Swift gói
mới** đều xanh. `check-spec`: 242 năng lực. `apps/eide --tu-kiem`: **22/22** trên một dự án tạm
rồi tự xoá.*

### Đang làm gì: viết lại giao diện trong `apps/eide/`

Chủ sản phẩm quyết ngày 18/09 ([DEV-131](DEVIATIONS.md)): giao diện dựng lại từ đầu trong một
gói Swift RIÊNG, chỉ tham khảo mã cũ. `apps/geditor` giữ nguyên làm bản chạy được cho tới khi
gói mới phủ đủ 25 màn. Hai bộ sinh (token màu, hợp đồng JSON-RPC) nay ghi cho CẢ HAI gói.

**Đã xong trong gói mới:** khung năm vùng (ràng buộc tường minh, không stack lồng nhau) · màn
chào §3.1 · `EidePhien` nối daemon (lớp DUY NHẤT hai bên biết nhau) · nhịp tim + dải "Dữ liệu
cũ" · cột phải ba khối bấm được · thẻ Run có thanh tiến độ chia đoạn · bảng lệnh ⌘K qua thanh
menu thật · **3/25 màn** đọc dữ liệu thật (S1 Tổng quan, S2 Nhật ký, S25 Chính sách).

**Làm tiếp — theo mục 8 của UXC-31, thứ tự đề xuất:**

1. **Nhóm TRI THỨC** (S5 Hộ chiếu chip, S8 Xung đột tri thức, S4 Nhập tài liệu, S7 Bản đồ tri
   thức). Ưu tiên vì đây là chỗ luận điểm trung tâm của đề án hiện ra: mọi hằng số phần cứng
   truy về một fact đã duyệt. `passport.query`/`passport.browse`, `kg.conflicts`, `view.kg_map`
   đều đã có alias JSON-RPC sẵn.
2. **S14 Trình soạn thảo** — nặng nhất và chưa bắt đầu: cần `code.human_save`, hai băng cảnh báo
   (§5.3, §5.6), và ⌘S đi qua Router. Gói cũ đã làm, đọc `apps/geditor/Sources/EIDEKit/EideCodeViews.swift` trước khi viết.
3. **S12 Kế hoạch / S15 Diff & cổng merge** — cần thẻ diff và cổng G-FACT.
4. Ô lệnh gửi `chat.send` THẬT (hôm nay chỉ gửi chuỗi và hiện `run_id`; chưa nối `chat.answer`
   cho câu hỏi gộp).

**Ba thứ CHƯA nối trong gói mới, đừng tưởng là xong:** `chat.answer` (trả lời câu hỏi gộp) ·
phím tắt ngoài ⌘K/⌘⇧. · bộ chuyển dự án ở thanh trên (nút có, menu chưa có).

**Cách đo, chạy trước khi tin bất cứ điều gì:**

```bash
cd apps/eide && swift test                 # 29 bài bố cục + logic
.build/debug/EideApp --tu-kiem             # 22 phép đo trên CỬA SỔ THẬT, dự án tạm
.build/debug/EideApp --chup /tmp/anh       # 7 ảnh: màn chào, khung, 3 màn, thẻ Run, bảng lệnh
```

`--tu-kiem` in cả CỠ CỬA SỔ và thời gian mở từng màn. Hai con số ấy bắt được lớp lỗi mà không
phép kiểm nội dung nào thấy — xem lỗi im lặng 83, 84, 89 trong [TIEN-DO.md](TIEN-DO.md) §6.

### Hai mục chờ chủ sản phẩm

- **[DEV-131]** — ghi nhận `apps/eide/` là bề mặt giao diện đích trong UXD-13/UXC-31.
- **[DEV-132]** — `view.timeline` nhận thêm `limit`/`total`; `range.days` nay chạy thật (nó nằm
  trong ví dụ của chính hợp đồng mà chưa bao giờ có mã đọc tới).

---

## Điểm dừng phiên 13/09/2026 (lịch sử)

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
