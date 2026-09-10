# Danh sách công việc EIDE

*Đo 10/09/2026 (lần 13) từ registry — không gõ tay. Còn **80/238** năng lực. Xem
[`TIEN-DO.md`](TIEN-DO.md) cho bức tranh trạng thái; tệp này trả lời **làm gì tiếp**.*

Sắp theo **thứ tự nên làm**, không theo số hiệu. Nguyên tắc sắp xếp: cái gì mở khóa nhiều thứ
nhất và kiểm được ngay thì làm trước; cái gì cần phần cứng để lại **cuối cùng** (quyết định của
chủ sản phẩm 08/09).

---

## Việc chờ CHỦ SẢN PHẨM (không phải việc của tôi)

*Đợt đồng bộ 08/09 đã đóng 13 mục sai khác; bộ hồ sơ ở **v1.3**. Từ đó tới 10/09 mở thêm 9 mục:
`docs/DEVIATIONS.md` nay có **9 mục Mở** (5 đề nghị sửa tài liệu, 4 là nợ hiện thực). Đủ ngưỡng
chạy `/dong-bo-tai-lieu` theo CLAUDE.md (≥ 5 mục Mở).*

| # | Việc | Vì sao chặn |
|---|---|---|
| **P1** | **WI-257 — ký danh sách trắng** | `trusted_sources` không có `raw.githubusercontent.com`, mà đó là nơi SVD tầng vàng thật sự nằm. **Mọi tải SVD hiện rơi vào ASK.** Sửa `defaults.yaml` rồi `eide policy sign` |
| **P2** | **[DEV-077](DEVIATIONS.md) — cạnh `CONFLICTS_WITH` cho errata** | Hai vế của CDS-12.2 EXTRACT-10 loại trừ nhau: `predicate: other` thì không bao giờ trùng (subject, predicate) với fact datasheet, mà đó là điều kiện duy nhất để `kg.dung` sinh cạnh ấy. Chọn: thêm trường quan hệ vào DDD-14 (chạm store) hay sửa câu ở CDS-12.2 (tôi nghiêng phương án này) |
| P3 | `/dong-bo-tai-lieu` cho **9 mục Mở** | Đủ ngưỡng CLAUDE.md. Năm mục đề nghị sửa tài liệu ([DEV-072], [073], [075], [078], [080]) gộp được một đợt; bốn mục còn lại là nợ hiện thực, để nguyên |
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

## F. `sim.*` + `debug.*` — 12 năng lực (M3)

| # | Việc | Chặn bởi |
|---|---|---|
| F1 | `sim.build_platform`, `sim.run`, `mock_peripheral`, `model_plant` | Cần Renode/QEMU/simavr — **cài được, chưa cài** |
| F2 | `debug.hypothesize`, `experiment`, `ask_at`, `log_stats`, `propose_fix` | Cần F1 |

**`defaults.sim_first` bắt mô phỏng chạy TRƯỚC phần cứng**, nên khối này phải xong trước khi
board có ý nghĩa. Nó cũng là cách kiểm `code.*` mà không cần board.

---

## G. Còn lại — 20 năng lực (rải rác) · **ứng viên tiếp theo**

`view.*` 4 (M2) · `tool.*` 3 · `project.*` 3 · `registry.*` 4 (M4) · `report.*` 3 ·
`memory.*` 2 · `passport.diff/upgrade` 2 · `kg.evidence` · `env.install_pack` ·
`search.docs_mcp`/`reference_projects`/`registry`.

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

---

## Đề xuất thứ tự

```
A1+A2 (xong)  →  B1+B2 (xong)  →  E board.* (xong, Z-07 đóng)
              →  C1..C4 (xong, P7 đóng)  →  D phần không cần ảnh (xong 10/09)
              →  ??? ←  ĐANG Ở ĐÂY: G (rải rác, không bị chặn)  hoặc
                        D3 (cần đường ảnh cho Gateway — mục P4)  hoặc
                        F (mô phỏng, cần cài Renode/QEMU)
              →  H (phần cứng, cuối cùng)
```

**Lý do đặt B trước C:** `doc.generate` viết tài liệu *về* thiết kế và mã. Có `code.*` rồi thì
tài liệu sinh ra nói về một hệ thống có thật, chứ không phải về một kế hoạch.

**Lý do đặt E ngay sau B** (đã làm xong): `board.build_passport` là chỗ đứt duy nhất còn lại
của Z-07. Đóng được một chuỗi trọn vẹn là mốc đáng có — và nó đã đóng.

**Kế tiếp là C** (đã làm xong C1+C3): `doc.generate` là chỗ đứt của P7, và bộ tài liệu sinh ra
chính là phụ lục đề án — sản phẩm tự viết tài liệu về mình, có trích dẫn tới fact.

---

## Điểm dừng phiên 10/09/2026 — bắt đầu phiên sau từ đây

*Cây làm việc sạch, `make check` **1205 xanh trên cả arm64 lẫn x86_64**, DEVIATIONS 9 mục Mở.
Bảy commit, mỗi commit một năng lực:* `e52589d` EXTRACT-09 · `37b1380` EXTRACT-10 · `9e7d8c8`
EXTRACT-20 · `4940246` EXTRACT-05 · `4e781ff` EXTRACT-17 · EXTRACT-18 · EXTRACT-11.

**Khối D đóng phần không cần thị giác**: `extract.*` 17/21, **158/238 năng lực (66%)**, M2
62/99. Ba cái còn lại của nhóm (`ocr`, `image_schematic`, `image_board`) đều chờ đường ảnh.

### Việc đã xong trong phiên và điều mỗi cái dạy được

| Năng lực | Điều đáng nhớ |
|---|---|
| `pdf_pinout` | Số AF là **vị trí cột**, không phải thứ hỏi mô hình. Nối lại `board.propose_fix` ↔ `diagram.pinmap` ↔ `arch.map_hw` |
| `pdf_errata` | Errata là **lớp phủ K2′** (`layer = "B"`), không sửa lõi. T2 nên mọi lần đều qua người |
| `readme_goal` | README là **ý định**, không phải fact — R0, không ghi store |
| `dt_binding` | Hai dạng binding (Zephyr / dt-schema Linux) phải đọc được cả hai |
| `bom` | BOM là danh sách **mua**: hai dạng đóng gói là hai dòng, không gộp |
| `bom_enrich` | Hộ chiếu đã qua G-FACT thắng mọi URL chưa ai mở |
| `pdf_formula` | Một **thủ tục** không phải một fact — nó thành K5 skill |

**Kiểm đột biến bắt được 6 test "xanh vì lý do khác"** trong chính phiên này (bảng tiêu đề
pinout · `compatible` trong dt-schema · ba lỗ của BOM · undo của skill). Đó là lý do bước ấy
không bỏ được: một bộ test đủ màu xanh vẫn có thể không kiểm gì.

### Chỗ phải quyết trước khi làm tiếp

Ba hướng, xem §8 [TIEN-DO.md](TIEN-DO.md): **(1)** mở đường ảnh cho Gateway để đóng trọn khối D;
**(2)** khối G rải rác (~20 năng lực M2, không bị chặn bởi gì); **(3)** khối F mô phỏng (cần cài
Renode/QEMU). Tôi nghiêng **(2)** nếu mục tiêu là nâng M2 nhanh, **(1)** nếu muốn khối D trọn vẹn.

### Bẫy đã biết, đừng đạp lại

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
