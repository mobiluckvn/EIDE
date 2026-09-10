# Danh sách công việc EIDE

*Đo 08/09/2026 (lần 12) từ registry — không gõ tay. Còn **96/238** năng lực. Xem
[`TIEN-DO.md`](TIEN-DO.md) cho bức tranh trạng thái; tệp này trả lời **làm gì tiếp**.*

Sắp theo **thứ tự nên làm**, không theo số hiệu. Nguyên tắc sắp xếp: cái gì mở khóa nhiều thứ
nhất và kiểm được ngay thì làm trước; cái gì cần phần cứng để lại **cuối cùng** (quyết định của
chủ sản phẩm 08/09).

---

## Việc chờ CHỦ SẢN PHẨM (không phải việc của tôi)

*Đợt đồng bộ 08/09 đã đóng **13 mục** sai khác (DEV-004, 035, 050, 054, 063…071) — bộ hồ sơ nay
ở **v1.3** và `docs/DEVIATIONS.md` còn **0 mục Mở**. Bảng dưới chỉ còn hai việc thật sự cần anh.*

| # | Việc | Vì sao chặn |
|---|---|---|
| **P1** | **WI-257 — ký danh sách trắng** | `trusted_sources` không có `raw.githubusercontent.com`, mà đó là nơi SVD tầng vàng thật sự nằm. **Mọi tải SVD hiện rơi vào ASK.** Sửa `defaults.yaml` rồi `eide policy sign` |
| P2 | WI-258 — xác nhận đỏ PTIT | Đang dùng `#B8121F` theo UXD-13 §7 |
| P3 | Chuẩn bị **một board** (Nucleo F411 / ESP32-C3) | Cho khối H cuối cùng |

---|---|---|
| **P1** | **WI-257 — ký danh sách trắng** | `trusted_sources` không có `raw.githubusercontent.com`, mà đó là nơi SVD tầng vàng thật sự nằm. **Mọi tải SVD hiện rơi vào ASK.** Sửa `defaults.yaml` rồi `eide policy sign` |
| P2 | [DEV-054](DEVIATIONS.md) — POL-17 phân biệt hai loại cổng | Chạm cách gác cổng của cả hệ; tôi có bản đề xuất, cần anh duyệt hướng |
| P3 | [DEV-050](DEVIATIONS.md) — duyệt hàng loạt trong hàng đợi | Đề nghị gom theo *cùng cổng + cùng quy tắc*; cần anh chốt |
| P4 | [DEV-065](DEVIATIONS.md) — git chạy ngoài sandbox; tag `known-good/<date>` | Ranh giới sandbox và dạng tag; cả hai đều nên vào tài liệu |
| P5 | [DEV-064](DEVIATIONS.md) — bỏ `tests/` khỏi phạm vi `constant_guard` | Quyết định thiết kế, tìm ra bằng gọi mô hình thật; cần anh xác nhận trước khi nó thành thói quen |
| P6 | [DEV-063](DEVIATIONS.md) — bố cục `tests/host` cho `code.test_host` | Quy ước do tôi đặt vì CODE-08 không nói; cần anh chốt trước khi `code.generate_tests` sinh test theo nó |
| P7 | [DEV-035](DEVIATIONS.md) — thêm ý định theo nhóm | Đã quyết hoãn tới CHAT-06; nhắc lại để không quên |
| P7b | [DEV-066](DEVIATIONS.md) — EXTRACT-16 thiếu `name` | Mã đã sửa cho khớp tài liệu (tên board = tên tệp). Chốt có thêm tham số hay giữ nguyên |
| P7c | [DEV-067](DEVIATIONS.md) — BOARD-04 gọi vai trò `architect` | Hiện thực sinh phương án bằng mã vì chân thay thế phải tra fact. Chốt bỏ tiền tố vai trò hay giữ |
| P7d | [DEV-068](DEVIATIONS.md) — bảng linh kiện chấp hành | Đang nằm trong mã; nên có tệp máy đọc được trong `docs/spec/` |
| **P7e** | **[DEV-069](DEVIATIONS.md) — DDD-14 Module thiếu `layer`** | Đáng chú ý nhất trong nhóm: `arch.decompose` kiểm bất biến "không phụ thuộc ngược lớp" rồi vứt lớp đi, nên bất biến ấy chỉ kiểm được ĐÚNG MỘT LẦN. Cần thêm cột + migration |
| P7f | [DEV-070](DEVIATIONS.md) — DOC-01 dựng docx? mục lục ở đâu? | Chốt ranh giới DOC-01 / REPORT-02, và sinh `docs/spec/doc/outlines.json` |
| P7g | [DEV-071](DEVIATIONS.md) — `DocArtifact.figures` không tồn tại | Bỏ khỏi DOC-07 hay thêm vào DDD-14 |
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

## D. `extract.*` còn lại — **8 ở M2** (+1 ở M5: `image_scope`) · ĐANG LÀM

| # | Việc | Ghi chú |
|---|---|---|
| ~~D1a~~ | ~~`pdf_pinout`~~ | **Xong 10/09** — 19 test, PDF thật có bảng kẻ khung. Số AF đọc từ **vị trí cột**, không gọi mô hình. Nhánh hình package → [DEV-076](DEVIATIONS.md) |
| ~~D1b~~ | ~~`pdf_errata`~~ | **Xong 10/09** — 21 test. Lớp phủ K2′ (`layer = "B"`), rev từ vị trí cột `Rev A`/`Rev Z`; cạnh CONFLICTS_WITH → [DEV-077](DEVIATIONS.md) chờ anh chọn hướng |
| ~~D2a~~ | ~~`dt_binding`~~ | **Xong 10/09** — 8 test. Đọc CẢ HAI dạng binding (Zephyr `required: true` trong thuộc tính; dt-schema Linux `required: [...]` cấp cao) |
| D2b | `bom`, `bom_enrich` | ~~`kicad_netlist`~~ xong 08/09 |
| D3 | `image_board`, `image_schematic`, `ocr` | đọc ảnh (cần mô hình vision). Mở khoá nốt nhánh hình của `pdf_pinout` — [DEV-076](DEVIATIONS.md) |
| ~~D4a~~ | ~~`readme_goal`~~ | **Xong 10/09** — 7 test. Lọc kỳ vọng theo `plan.DANG_KY_VONG` ngay tại chỗ; không ghi store (R0, `undo: none`) |
| D4b | `pdf_formula` | công thức → skill dự án (K5), chạm `tool.*` |

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

## G. Còn lại — 20 năng lực (rải rác)

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
A1+A2 (xong)  →  B1+B2 (xong)  →  E board.* (xong, Z-07 đóng)
              →  C1+C2+C3+C4 (cả khối C phần M2 — xong, P7 đóng)
              →  D (extract còn lại)  ←  ĐANG Ở ĐÂY
              →  F (mô phỏng)  →  H (phần cứng, cuối cùng)
```

**Lý do đặt B trước C:** `doc.generate` viết tài liệu *về* thiết kế và mã. Có `code.*` rồi thì
tài liệu sinh ra nói về một hệ thống có thật, chứ không phải về một kế hoạch.

**Lý do đặt E ngay sau B** (đã làm xong): `board.build_passport` là chỗ đứt duy nhất còn lại
của Z-07. Đóng được một chuỗi trọn vẹn là mốc đáng có — và nó đã đóng.

**Kế tiếp là C** (đã làm xong C1+C3): `doc.generate` là chỗ đứt của P7, và bộ tài liệu sinh ra
chính là phụ lục đề án — sản phẩm tự viết tài liệu về mình, có trích dẫn tới fact.

---

## Điểm dừng phiên 09/09/2026 — bắt đầu phiên sau từ đây

*Cây làm việc sạch, `make check` 1121 xanh, DEVIATIONS 4 mục Mở. Tám commit:*
`59c07e0`→`883aaca` *(doc.api_ref · doc.test_report · doc.changelog · diagram.pinmap ·
diagram.memory_map · diagram.sequence · khối C4 · hai lần cập nhật tiến độ).*

**Cả khối C phần M2 đã đóng**: `doc.*` 9/12, `diagram.*` 12/14 — số còn lại của cả hai nhóm đều
ở M3. 151/238 năng lực (63%), M2 55/99.

**Quyết định chủ sản phẩm 09/09:** làm tiếp **khối D**; bốn mục DEVIATIONS để `Mở`, gộp vào đợt
đồng bộ tài liệu sau (không chạy `/dong-bo-tai-lieu` bây giờ).

---

### Làm gì đầu tiên: `extract.pdf_pinout` (EXTRACT-09)

Đã đọc hợp đồng và khảo sát mã ở cuối phiên 09/09 — chép lại đây để phiên sau vào việc ngay,
**chưa viết dòng mã nào**.

**Vì sao nó trước:** nó sinh fact `pin_function`, thứ mà ba năng lực vừa dựng đang cùng chờ —
`board.propose_fix` hiện trả *"chưa tra được chân thay thế"*, `diagram.pinmap` để trống cột
`pin` khi không tra được tên chân, `arch.map_hw` gán ngoại vi mò theo tên module. Làm xong là ba
chỗ ấy có dữ liệu thật cùng lúc.

**Hợp đồng:** vào `{file, part}` (cả hai bắt buộc), ra `{batch_id}`; `errors: []`; undo
`supersede_facts`; R1/T1; ask_when *"Từ hình"*; tc **"PB6 có I2C1_SCL AF4"**.
Bước 1: *"Bảng pinout (Pin, Name, Type) hoặc hình package (vision) → pin_function; package"*.

**Thiết kế đã chốt qua khảo sát:**

- **Đường bảng làm bằng MÃ, không gọi mô hình.** Khác `extract.pdf_register_map` (ở đó cột
  "Bits" có mười cách viết nên mô hình là đúng chỗ). Ở đây số AF đến từ **vị trí cột** trong
  bảng "Alternate function mapping" (AF0…AF15) — đọc chỉ số cột là việc xác định, và chính tc
  của hợp đồng ("AF4") kiểm cái đó. Hỏi mô hình một thứ đếm được là mở đường cho nó đếm sai.
- **Hai loại bảng, hai bộ nhận dạng theo tiêu đề cột** (cùng khuôn `_diem_bang`/`COT_THANH_GHI`
  của EXTRACT-07): (a) bảng định nghĩa chân — Pin/Pin number/Name/Signal/Type/I/O; (b) bảng ánh
  xạ chức năng thay thế — hàng tiêu đề có `AF0`…`AF15`. Không nhận ra tiêu đề thì **bỏ bảng**,
  không đoán.
- **Hình dạng fact:** `pin_function`, subject `chip:<part>/pin:PB6`,
  value `{"pin": "PB6", "functions": [...], "af": {"I2C1_SCL": 4}, "type": "I/O"}`.
  Giữ `functions` là **mảng chuỗi** — `board._chan_thay_the` và `diagram._chan_chuc_nang` đều
  đọc `v.get("functions") or v.get("af")`, nên đổi kiểu của `functions` là làm hỏng hai chỗ ấy
  trong im lặng. Số AF đi vào khóa `af` riêng.
- Thêm fact `package` (subject `chip:<part>`) khi đọc được tên vỏ (LQFP/QFN/TSSOP/BGA + số
  chân). `pin_function` và `package` đều nằm trong enum `VI_TU` của `passport.py` — không phải
  xin thêm vị từ.
- `tier: silver`, `locator` = `{page, bbox}` lấy từ khối (KHÔNG hỏi mô hình), rồi
  `passport.import` trả `batch_id`.
- Không thấy bảng pinout nào → **E2000** kèm `candidates`, nói rõ đường hình cần vision. E2000
  là lỗi tiền điều kiện của khung, không phải mã mới, nên không cần mục sai khác cho nó.
- **Đường "hình package (vision)" chưa làm được** → dự kiến mở [DEV-076] dạng *nợ hiện thực*,
  cùng hình dạng DEV-074: nó cần `extract.ocr`/`extract.image_*` (M2, chưa hiện thực), và
  `ask_when: "Từ hình"` chỉ có nghĩa khi đường ấy tồn tại.

**Chỗ còn phải quyết ở phiên sau:** test dùng PDF THẬT có bảng kẻ khung (đúng chuẩn của kho —
xem `pdf_toi_thieu`/`_pdf_tho` trong `tests/test_extract_m1.py`, phần vẽ đường kẻ `m`/`l`/`S`),
hay giả lập `pdf_layout` như test của `extract.pdf_electrical`. Nên thử đường PDF thật trước:
`extract.pdf_layout` đã có, và một bảng AF thật là thứ duy nhất chứng minh được tc.

---

### Bẫy đã biết, đừng đạp lại

- **Chạy test bằng `.venv-arm/bin/python`, không phải `python` trên PATH.** Venv là 3.11 còn
  `python` hệ thống mới hơn: một f-string lồng dùng lại dấu nháy (`f"{d["k"]}"`) chạy được ở
  ngoài và là LỖI CÚ PHÁP trong venv — pytest xanh, `make check` đỏ ở bước ruff.
- `Router.invoke` biến `EideError` của handler thành run `failed` (`run.error["eide_code"]`);
  chỉ E1000 từ lớp kiểm `input_schema` mới ném ra ngoài.
- Bảng đơn vị của kho (`req.DON_VI`) đọc `kb` là **1000** byte, `kib` là 1024.
- Nhãn lấy từ dữ liệu phải qua bộ lọc trước khi vào mã lược đồ: `:` cắt đôi một dòng gantt,
  ngoặc lệch làm `diagram.lint` báo lỗi trên chính lược đồ mình vừa sinh, và nhãn bị CẮT giữa
  chừng là nguồn ngoặc lệch phổ biến nhất (cắt trước, cân bằng sau).
- Ba cổng chặn trong `tests/test_specs_consistency.py` vẫn nguyên: docstring nêu ĐÚNG mã hợp
  đồng; không đọc tham số ngoài `input_schema`; không định nghĩa trùng tên hàm ở mức cao nhất.

**Sau D là F (mô phỏng)**, rồi H (phần cứng, cuối cùng). Chuỗi Z-10 vẫn 1/10 và sẽ ở đó tới lúc
có board — đúng lịch, không phải chậm.
