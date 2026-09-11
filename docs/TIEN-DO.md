# Tiến độ sản phẩm EIDE

*Cập nhật 11/09/2026 (lần 19). Số liệu **đo từ mã**, không gõ tay: `eide spec`,
`scripts/kiem_chuoi_chuan.py`, `pytest`. Tài liệu này sinh lại bằng cách chạy lại chúng —
đừng sửa số ở đây mà không chạy lại, vì con số gõ tay sẽ đúng đúng một ngày.*

> Đã xảy ra đúng như thế ngày 08/09: hai lần cập nhật liền nhau tôi CỘNG THÊM vào con số cũ thay
> vì đo lại, và tổng lệch 2 (ghi 122, thật là 124). Từ lần này mọi con số ở đây đều lấy từ một
> lượt đếm trên registry ngay trước khi ghi.

---

## 1. Một dòng

**182/238 năng lực (76%). M0 đóng 22/22; M1 đạt 74/75 (99%); M2 giữ 80/99 (81%); M3 mở màn
6/29. 1346 test xanh trên cả arm64 lẫn x86_64. Nghiệm thu Sprint 2: 18/18 bước ĐẠT.**

**Phiên 11/09 mở khối F1 — nhóm `sim.*` đóng phần M3 (6/6; `compare_hil` là M4).** Chuỗi Z-05
"thêm tính năng" nhờ đó lên **14/16** và chỗ đứt dời từ `sim.run` sang `target.flash`, tức sang
phần cần phần cứng.

Mốc M2 vẫn còn 19 mục và không mục nào làm được trên máy này: `discover.*` (8), `target.*` (5),
`bench.*` (3) cần **board thật**; `extract.ocr`/`image_*` (3) cần **đường ảnh cho Gateway**
(mục P4 trong [CONG-VIEC.md](CONG-VIEC.md)).

Điều này nghĩa là: **xương sống đã chạy thật đầu-cuối** — một câu tiếng Việt đi qua cổng
chính sách, tra tri thức có nguồn, ra kết luận truy nguyên được. Phần còn thiếu là **tay
chân**: nạp board, đo, gỡ lỗi trên phần cứng.

---

## 2. Theo mốc

| Mốc | Xong | Ý nghĩa |
|---|---|---|
| **M0** | **22/22 · 100%** | Nền: dự án, store, chính sách, thu nhận tri thức |
| **M1** | **74/75 · 99%** | Tác tử hiểu lệnh, tra cứu, lập kế hoạch, viết tài liệu |
| M2 | 80/99 · 81% | Sinh mã, board, mô phỏng nền, tài liệu đầy đủ |
| M3 | 6/29 · 21% | Mô phỏng và gỡ lỗi — `sim.*` xong, `debug.*` kế tiếp |
| M4 | 0/9 | Registry chia sẻ, benchmark |
| M5 | 0/4 | ISA mở rộng (RISC-V, Xtensa, PIC) — xem [DEV-055](DEVIATIONS.md) |

**M1 còn đúng 1 năng lực**: `passport.verify_on_board` (R3) — **cần board thật**, không mô
phỏng được phần "nạp firmware rồi đọc lại ID".

---

## 3. Theo nhóm năng lực

*Số đo từ registry, không gõ tay (`eide spec`).*

**Đủ (11 nhóm)** — `arch` 11/11 · `archive` 7/7 (gồm `ingest.*`) · `board` 5/5 · `chat` 8/8 ·
`plan` 7/7 · `policy` 7/7 · `req` 8/8 · **`project` 9/9** · **`view` 13/13** · **`tool` 10/10** ·
**`memory` 8/8** · **`kg` 9/9** · **`env` 7/7**

**Gần đủ** — `diagram` 12/14 · `code` 13/16 · **`extract` 17/21** · `doc` 9/12 · `search` 7/9 ·
`passport` 6/8 · **`sim` 6/7** (phần M3 đóng trọn; `compare_hil` là M4, cần báo cáo HIL thật)

**Mới một phần** — `registry` 1/5 (M4) · `report` 2/4

**Chưa bắt đầu** — `discover` (12, M2) · `target` (9, M2) · `debug` (6, M3) · `bench` (3, M2) ·
`measure` (3, M5). Tất cả đều cần **board thật** — đúng thứ tự chủ sản phẩm đã chốt 08/09.
`debug.*` thì cần một engine mô phỏng chạy được, xem [DEV-086](DEVIATIONS.md).

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

---

## 6. Chất lượng

| Chỉ số | Giá trị |
|---|---|
| Test Python | **1346** xanh, arm64 + x86_64 (`make check`) |
| Test GỌI THẬT | 10 mạng (`make check-net`) · 7 mô hình (`make check-llm`) |
| Test Swift | 29 |
| Nghiệm thu Sprint 1 / Sprint 2 | 17/17 · 18/18 |
| Mục DEVIATIONS | 86 tổng, **8 Mở** — 7 là nợ hiện thực chờ mốc/khối sau ([DEV-074] M5, [DEV-076] và [DEV-079] chờ D3 vision, [DEV-082]…[DEV-085] chờ engine mô phỏng chạy được); **1 chờ chủ sản phẩm** ([DEV-086] — thêm `fallback: qemu` cho `avr8.yaml`) |
| Tài liệu | 35 tệp ở **v1.3**, khớp nguồn sinh từng khối (`make check`) |

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

**Tám lỗi im lặng, mỗi cái tìm ra bằng một cách khác nhau:**

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

---

## 7. Việc chờ chủ sản phẩm

| Việc | Vì sao cần người |
|---|---|
| **WI-257** ký danh sách trắng | `trusted_sources` (POL-17, ĐÃ KÝ) ghi `github.com/cmsis-svd` nhưng SVD thật phục vụ từ `raw.githubusercontent.com` — **nguồn SVD tầng vàng phổ biến nhất vẫn rơi vào ASK ở cổng G-SRC**. Bảng nguồn hãng TGT-19 §8 đã thêm tên miền ấy (nó mô tả *nơi tài liệu thật sự nằm*), nhưng danh sách trắng thì khác: nó quyết định *cho tải hay không*, và sửa nó cần chữ ký của chủ sản phẩm |
| **WI-258** | Xác nhận đỏ PTIT chính thức (đang dùng `#B8121F` theo UXD-13 §7) |
| **[DEV-086]** thêm `fallback: qemu` cho `avr8.yaml` | Sửa `docs/spec/` nên cần anh duyệt. Đo 11/09: **không engine mô phỏng nào trong bộ hồ sơ chạy được trên máy này** — `simavr` không có công thức brew, Renode không có cask, và `qemu-system-arm` thì không mang máy ảo nào cho họ STM32F4. Nhưng `qemu-system-avr` **đã có sẵn** và mang đúng `arduino-uno` = ATmega328P, khớp `family_patterns` của `avr8.yaml`. Một dòng trong `tgt_sim.js`, cùng khuôn với `armv7e-m.yaml`, là đủ để cả nhóm `sim.*` có một đường chạy engine THẬT kiểm được |

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

Ba hướng đi tiếp, theo thứ tự tôi đề xuất:

1. **[DEV-086] rồi chạy engine thật** → một dòng anh duyệt, rồi khối `sim.*` có đường chạy engine
   thi hành được trên máy này (ATmega328P trên `qemu-system-avr`). Đó là điều kiện để đóng
   [DEV-083] (kênh `var`/`gpio`) và [DEV-084] (đồng mô phỏng plant), và cũng là thứ mở đường cho
   `debug.*` — cả sáu năng lực `debug.*` đều đứng trên một lượt chạy mô phỏng quan sát được.
2. **Đường ảnh cho Gateway** → đóng nốt 3 năng lực M2 cuối cùng làm được trên máy, và gỡ hai
   nhánh đang treo. Chạm lõi, cần khoá mô hình có thị giác để kiểm đường thật.
3. **`code.*` phần M3** (`annotate`, `docs`, `refactor`) và `doc.*`/`diagram.*` phần M3 — không
   bị chặn bởi gì, nhưng giá trị thấp hơn hai hướng trên.

`registry.*` và `search.registry/reference_projects` (mốc M4) để sau: chúng cần một registry
thật để pull, và đó là hạ tầng ngoài phạm vi đề án.
