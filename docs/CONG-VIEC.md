# Danh sách công việc EIDE

*Đo 08/09/2026 (lần 8) từ registry — không gõ tay. Còn **107/238** năng lực. Xem
[`TIEN-DO.md`](TIEN-DO.md) cho bức tranh trạng thái; tệp này trả lời **làm gì tiếp**.*

Sắp theo **thứ tự nên làm**, không theo số hiệu. Nguyên tắc sắp xếp: cái gì mở khóa nhiều thứ
nhất và kiểm được ngay thì làm trước; cái gì cần phần cứng để lại **cuối cùng** (quyết định của
chủ sản phẩm 08/09).

---

## Việc chờ CHỦ SẢN PHẨM (không phải việc của tôi)

| # | Việc | Vì sao chặn |
|---|---|---|
| **P1** | **WI-257 — ký danh sách trắng** | `trusted_sources` không có `raw.githubusercontent.com`, mà đó là nơi SVD tầng vàng thật sự nằm. **Mọi tải SVD hiện rơi vào ASK.** Sửa `defaults.yaml` rồi `eide policy sign` |
| P2 | [DEV-054](DEVIATIONS.md) — POL-17 phân biệt hai loại cổng | Chạm cách gác cổng của cả hệ; tôi có bản đề xuất, cần anh duyệt hướng |
| P3 | [DEV-050](DEVIATIONS.md) — duyệt hàng loạt trong hàng đợi | Đề nghị gom theo *cùng cổng + cùng quy tắc*; cần anh chốt |
| P4 | [DEV-065](DEVIATIONS.md) — git chạy ngoài sandbox; tag `known-good/<date>` | Ranh giới sandbox và dạng tag; cả hai đều nên vào tài liệu |
| P5 | [DEV-064](DEVIATIONS.md) — bỏ `tests/` khỏi phạm vi `constant_guard` | Quyết định thiết kế, tìm ra bằng gọi mô hình thật; cần anh xác nhận trước khi nó thành thói quen |
| P6 | [DEV-063](DEVIATIONS.md) — bố cục `tests/host` cho `code.test_host` | Quy ước do tôi đặt vì CODE-08 không nói; cần anh chốt trước khi `code.generate_tests` sinh test theo nó |
| P7 | [DEV-035](DEVIATIONS.md) — thêm ý định theo nhóm | Đã quyết hoãn tới CHAT-06; nhắc lại để không quên |
| P8 | WI-258 — xác nhận đỏ PTIT | Đang dùng `#B8121F` theo UXD-13 §7 |
| P9 | Chuẩn bị **một board** (Nucleo F411 / ESP32-C3) | Cho khối H cuối cùng |

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

## C. `doc.*` + `diagram.*` còn lại — 14 ở M2 (+5 ở M3: `slides`, `sync`, `translate`, `from_image`, `diagram.sync`)

| # | Việc | Giá trị |
|---|---|---|
| C1 | `doc.generate` (URD/SRS/SAD/SDD/STP), `doc.embed_diagram` | Khép chuỗi **P7** (hiện 4/8) |
| C2 | `diagram.architecture`, `state`, `sequence`, `pinmap`, `memory_map` | Lược đồ cho chính bộ tài liệu ấy |
| C3 | `doc.bringup_guide`, `api_ref`, `test_report`, `changelog` | Tài liệu vận hành |
| C4 | `diagram.flow`, `gantt`, `timing` | Còn lại |

**Vì sao đáng làm sớm:** nó cho ra **chính bộ tài liệu dùng làm phụ lục đề án** — sản phẩm tự
viết tài liệu về mình, có trích dẫn tới fact. Đó là bằng chứng mạnh hơn bất kỳ mô tả nào.

---

## D. `extract.*` còn lại — 11 ở M2 (+1 ở M5: `image_scope`)

| # | Việc |
|---|---|
| D1 | `pdf_errata`, `pdf_pinout` — hai loại bảng còn thiếu của datasheet |
| D2 | `bom`, `bom_enrich`, `kicad_netlist`, `dt_binding` — đọc thiết kế mạch |
| D3 | `image_board`, `image_schematic`, `ocr` — đọc ảnh (cần mô hình vision) |

**Mở khóa:** `board.build_passport` (chỗ đứt của Z-07, hiện 20/23).

---

## E. `board.*` — 5 năng lực (M2)

`build_passport`, `check_pins`, `constraints`, `mark_lab`, `propose_fix`.

Chỗ đứt hiện tại của **Z-07**. Không cần phần cứng — nó làm việc trên BOM và netlist, chứ chưa
chạm board. `check_pins` dùng lại phép phát hiện xung đột đã có trong `arch.map_hw`.

---

## F. `sim.*` + `debug.*` — 12 năng lực (M3)

| # | Việc | Chặn bởi |
|---|---|---|
| F1 | `sim.build_platform`, `sim.run`, `mock_peripheral`, `model_plant` | Cần Renode/QEMU/simavr — **cài được, chưa cài** |
| F2 | `debug.hypothesize`, `experiment`, `ask_at`, `log_stats`, `propose_fix` | Cần F1 |

**`defaults.sim_first` bắt mô phỏng chạy TRƯỚC phần cứng**, nên khối này phải xong trước khi
board có ý nghĩa. Nó cũng là cách kiểm `code.*` mà không cần board.

---

## G. Còn lại — 20 năng lực

`view.*` 4 (M2) · `tool.*` 3 · `project.*` 3 · `registry.*` 4 (M4) · `report.*` 3 ·
`memory.*` 2 · `passport.diff/upgrade` 2 · `kg.evidence` · `env.install_pack` ·
`search.docs_mcp`/`reference_projects`/`registry`.

Rải rác, làm kèm khi chạm tới nhóm liên quan.

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

---

## Đề xuất thứ tự

```
A1 + A2 (xong)  →  B1+B2 (sinh + dựng mã)  →  E (board.*, mở Z-07)
                   →  C1+C2 (bộ tài liệu tự sinh)  →  D (extract còn lại)
                   →  F (mô phỏng)  →  H (phần cứng, cuối cùng)
```

**Lý do đặt B trước C:** `doc.generate` viết tài liệu *về* thiết kế và mã. Có `code.*` rồi thì
tài liệu sinh ra nói về một hệ thống có thật, chứ không phải về một kế hoạch.

**Lý do đặt E ngay sau B:** `board.build_passport` là chỗ đứt duy nhất còn lại của Z-07, và
Z-07 đang 20/23 — gần nhất trong năm chuỗi. Đóng được một chuỗi trọn vẹn là mốc đáng có.
