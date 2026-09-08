# Tiến độ sản phẩm EIDE

*Cập nhật 08/09/2026 (lần 2). Số liệu **đo từ mã**, không gõ tay: `eide spec`,
`scripts/kiem_chuoi_chuan.py`, `pytest`. Tài liệu này sinh lại bằng cách chạy lại chúng —
đừng sửa số ở đây mà không chạy lại, vì con số gõ tay sẽ đúng đúng một ngày.*

---

## 1. Một dòng

**116/238 năng lực (49%). Mốc M0 đóng 22/22; M1 đạt 71/75 (95%), còn 4. 839 test xanh trên
cả arm64 lẫn x86_64. Nghiệm thu Sprint 2: 18/18 bước ĐẠT.**

Điều này nghĩa là: **xương sống đã chạy thật đầu-cuối** — một câu tiếng Việt đi qua cổng
chính sách, tra tri thức có nguồn, ra kết luận truy nguyên được. Phần còn thiếu là **tay
chân**: sinh mã, nạp board, mô phỏng.

---

## 2. Theo mốc

| Mốc | Xong | Ý nghĩa |
|---|---|---|
| **M0** | **22/22 · 100%** | Nền: dự án, store, chính sách, thu nhận tri thức |
| **M1** | **71/75 · 95%** | Tác tử hiểu lệnh, tra cứu, lập kế hoạch, viết tài liệu |
| M2 | 23/99 · 23% | Sinh mã, board, mô phỏng nền, tài liệu đầy đủ |
| M3 | 0/29 | Gỡ lỗi trên phần cứng thật |
| M4 | 0/9 | Registry chia sẻ, benchmark |
| M5 | 0/4 | ISA mở rộng (RISC-V, Xtensa, PIC) — xem [DEV-055](DEVIATIONS.md) |

**M1 còn đúng 4 năng lực**, và phần lớn không chặn bởi công sức mà bởi thứ khác:

| Năng lực | Vì sao chưa |
|---|---|
| `env.install` (R4), `env.guide_install` | **R4** — cài phần mềm lên máy người dùng. Cần bàn kỹ về chính sách trước khi viết |
| `passport.verify_on_board` (R3) | **Cần board thật.** Không mô phỏng được phần "nạp firmware rồi đọc lại ID" |
| `code.constant_guard` | Hook cho `code.*`, hợp lý làm cùng nhóm `code` ở M2 |

---

## 3. Theo nhóm năng lực

**Đủ hoặc gần đủ** — `arch` 11/11 · `chat` 8/8 · `req` 8/8 · `plan` 7/7 · `policy` 7/7 ·
`ingest` 3/3 · `kg` 8/9 · `view` 9/13 · `tool` 7/10

**Mới một phần** — `extract` 9/21 · `project` 6/9 · `memory` 6/8 · `search` 6/9 ·
`env` 4/7 · `passport` 4/8 · `diagram` 4/14 · `doc` 3/12 · `archive` 4/4 · `registry` 1/5 ·
`report` 1/4

**Chưa bắt đầu** — `code` (16, M2) · `discover` (12, M2) · `target` (9, M2) · `sim` (7, M3) ·
`debug` (6, M3) · `board` (5, M2) · `bench` (3, M2) · `measure` (3, M5)

---

## 4. Năm chuỗi chuẩn — chỗ đứt

Đo bằng `scripts/kiem_chuoi_chuan.py` (đối chiếu `dialog/chains.json` với registry):

| Chuỗi | Tiến độ | Đứt tại |
|---|---|---|
| **Z-07** dự án từ zip | 20/23 | `board.build_passport` (M2) |
| **Z-01** dự án từ ý tưởng | 10/14 | `search.reference_projects` (M4) |
| **Z-05** thêm tính năng | 8/16 | `code.generate_module` (M2) |
| **P7** bộ tài liệu | 4/8 | `doc.generate` (M2) |
| **Z-10** dò board và nạp | 1/10 | `discover.ports` (M2) — cần phần cứng |

**Z-07 gần xong** vì nó là chuỗi tri thức thuần: zip → trích → hộ chiếu → yêu cầu → kế hoạch.
Bốn chuỗi còn lại đứt ở đúng chỗ dự kiến — chúng cần `code.*`, `board.*`, `discover.*`, tức
mốc M2 trở đi.

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
| Test Python | **839** xanh, arm64 + x86_64 (`make check`) |
| Test GỌI THẬT | 9 mạng (`make check-net`) · 6 mô hình (`make check-llm`) |
| Test Swift | 29 |
| Nghiệm thu Sprint 1 / Sprint 2 | 17/17 · 18/18 |
| Mục DEVIATIONS | 59 tổng, **3 Mở** |
| Tài liệu | 35 tệp, khớp nguồn sinh từng khối (`make check`) |

**Kiểm đột biến** dùng cho mọi nhóm năng lực: cố ý phá từng khẳng định rồi xác nhận test đỏ.
Nó đã bắt được nhiều test "xanh vì lý do khác với lý do nó được viết ra" — trong đó có test
SAFETY của `req.*`, ngưỡng 85% Flash của `arch.*`, hai lớp chặn DoS của `archive.unpack`, và
ngưỡng 0,35 của `view.rag_ask`.

**Ba lớp test, ba loại câu hỏi khác nhau.** `make check` (837 test, giả lập) hỏi *"mã có đúng
với giả định của tôi không"*. `make check-net` (9 test, không tốn tiền) và `make check-llm`
(6 test, tốn token) hỏi *"giả định của tôi có đúng với đời thật không"* — và câu hỏi thứ hai
đã tìm ra hai lỗi mà lớp thứ nhất không thể thấy:

- **4/11 mẫu URL hãng sai.** `STM32F411CE.svd` không tồn tại: tệp SVD mô tả một **die**, không
  mô tả một mã đóng gói — `STM32F411CE` (LQFP48) và `STM32F411RE` (LQFP64) dùng chung
  `STM32F411.svd`. `nrfx/mdk` cũng không còn tệp `.svd` nào. Cả hai trông hoàn toàn hợp lý
  trong YAML và `search.vendor` vẫn trả ứng viên — chỉ là mọi ứng viên đều 404.
- **`doc.section` phạt mô hình vì nó trung thực.** Hỏi về một module chưa có fact, mô hình trả
  lời *"chưa có dữ liệu trong ngữ cảnh được cung cấp"* — đúng điều ta muốn — rồi bị E5002 vì
  không có trích dẫn. Một câu trung thực "không có dữ liệu" thì không thể có trích dẫn, và bắt
  nó phải có là **dạy mô hình bịa cho đủ**.

**Bốn lỗi im lặng tìm được nhờ chạy thật thay vì chỉ chạy test:**

1. **Niêm store lệch sau mỗi phiên bình thường** — `req.*`/`arch.*`/`extract.*` ghi vào bảng
   có niêm mà không niêm lại. Cảnh báo "store bị sửa ngoài EIDE" luôn đỏ, và cảnh báo luôn đỏ
   thì người ta tắt đi. Tìm ra bằng `nghiem_thu_sprint2.sh`.
2. **Thang điểm FTS bị đảo ngược từ Sprint 2** ([DEV-058](DEVIATIONS.md)) — thứ hạng vẫn đúng
   nhờ `ORDER BY` nên không ai thấy, cho tới khi có ai dùng điểm làm *ngưỡng*.
3. **Một mục DEVIATIONS biến mất khỏi báo cáo đồng bộ** — nội dung chứa `|`, vốn là dấu ngăn
   cột Markdown. Chủ sản phẩm duyệt một danh sách và tin nó đầy đủ.
4. **`_doc_do_thi` mất một nửa số cạnh** — 305 dòng cạnh chỉ ra 153 cạnh, nên kiểm kích thước
   lược đồ không bao giờ nổ.

---

## 7. Việc chờ chủ sản phẩm

| Việc | Vì sao cần người |
|---|---|
| **WI-257** ký danh sách trắng | `trusted_sources` (POL-17, ĐÃ KÝ) ghi `github.com/cmsis-svd` nhưng SVD thật phục vụ từ `raw.githubusercontent.com` — **nguồn SVD tầng vàng phổ biến nhất vẫn rơi vào ASK ở cổng G-SRC**. Bảng nguồn hãng TGT-19 §8 đã thêm tên miền ấy (nó mô tả *nơi tài liệu thật sự nằm*), nhưng danh sách trắng thì khác: nó quyết định *cho tải hay không*, và sửa nó cần chữ ký của chủ sản phẩm |
| [DEV-054](DEVIATIONS.md) | POL-17 phân biệt hai loại cổng — chạm cách gác cổng của cả hệ |
| [DEV-050](DEVIATIONS.md) | "Duyệt hàng loạt" trong hàng đợi — đề nghị gom theo *cùng cổng + cùng quy tắc* |
| [DEV-035](DEVIATIONS.md) | Thêm ý định theo nhóm năng lực — đã quyết hoãn tới CHAT-06 |
| **WI-258** | Xác nhận đỏ PTIT chính thức (đang dùng `#B8121F` theo UXD-13 §7) |

---

## 8. Việc tiếp theo đề xuất

**Ưu tiên 1 — `code.*` (16 năng lực, M2).** Đây là mắt xích duy nhất giữa "tác tử hiểu và lập
kế hoạch" với "có firmware chạy được". Nó mở khóa Z-05 (thêm tính năng) và là phần lõi nhất
còn thiếu của luận điểm đề án.

**Ưu tiên 2 — `doc.generate` + `diagram.*` còn lại.** Khép chuỗi P7, và cho ra chính bộ tài
liệu dùng làm phụ lục đề án — tức sản phẩm tự viết tài liệu về mình.

**Ưu tiên 3 — dọn nốt M1** (3 năng lực làm được ngay: `archive.extract_one/query`,
`code.constant_guard`; `env.*` chờ bàn chính sách R4, `passport.verify_on_board` chờ board).

`search.web` đã xong 08/09 — hiện thực **không buộc nhà cung cấp nào**: `models.yaml →
search.providers` liệt kê ứng viên theo thứ tự và dùng cái đầu tiên có đủ cấu hình. SearXNG
đứng đầu vì tự dựng được, **không cần khóa và không tốn tiền** — hoàn thiện M1 không buộc phải
mua gì. Chưa cấu hình gì thì E4001 liệt kê từng lựa chọn kèm biến môi trường, và chỉ sang
`search.vendor` như đường đi được ngay.

`discover.*`/`target.*`/`sim.*` để sau: chúng cần board thật hoặc trình mô phỏng chưa cài, nên
làm sớm cũng không kiểm được.
