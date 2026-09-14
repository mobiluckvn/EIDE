# Usecase và thiết kế hệ thống — bản top-down

*Viết 14/09/2026 theo yêu cầu chủ sản phẩm: **"liệt kê một số usecase chính để từ đó chúng ta
xây dựng phần mềm cho phù hợp"**, **"làm chậm lại và bài bản"**, **"thiết kế mang tính hệ thống
cho toàn bộ từ top down"**.*

Mọi số liệu đo từ mã và spec, không gõ tay: `cds.json` (238 năng lực), `screens.json` (23 màn),
MEM-11 (7 tầng bộ nhớ), CXD-10 (8 lớp ngữ cảnh), DDD-14 (lược đồ store), một dự án thật trong
`~/eide/`.

---

## Phần 1 — Dự án là gì và nằm ở đâu

### 1.1. Một dự án = một thư mục + một tệp dự án

```
<thư mục dự án>/                    ← người dùng chọn, ví dụ ~/eide/doc-bme280-esp32c3
├── .eide/                          ← MỌI thứ EIDE biết về dự án này
│   ├── constraints.yaml            ← ★ TỆP DỰ ÁN (xem 1.2)
│   ├── FEATURES.json               ← danh sách tính năng và trạng thái passing/failing
│   ├── PROGRESS.md                 ← nhật ký tiến độ cho người đọc
│   ├── autonomy.yaml               ← mức tự chủ A0–A4 + ngưỡng của DỰ ÁN NÀY
│   ├── policy.sig                  ← niêm chữ ký chủ sản phẩm trên bốn danh sách trắng
│   ├── models.yaml                 ← hồ sơ mô hình và ngân sách token
│   ├── roles.yaml                  ← prompt vai trò ghi đè cho dự án
│   ├── tools.lock                  ← khoá phiên bản chuỗi công cụ đã dùng
│   ├── store/
│   │   ├── store.sqlite            ← M3 + M4: fact, hộ chiếu, run, decision_log…
│   │   ├── store.sqlite.seal.json  ← niêm nội dung tri thức
│   │   └── ledger.jsonl            ← sổ cái chuỗi băm, chỉ-thêm
│   ├── session/                    ← M2: phiên làm việc (không commit)
│   ├── index/                      ← chỉ mục RAG (index.sqlite + bản đồ khối)
│   ├── docs/                       ← tài liệu sinh ra (SRS, SAD, ma trận truy vết)
│   ├── diagrams/                   ← lược đồ đã vẽ
│   └── cache/
│       ├── downloads/              ← nguồn đã tải, đặt tên theo băm
│       ├── unpacked/               ← kho nén đã mở
│       └── sandbox/                ← log stdout/stderr của công cụ ngoài
├── src/ · Makefile · CMakeLists.txt ← MÃ NGUỒN — của người dùng, EIDE không sở hữu
├── build/                          ← artefact (fw.elf, .map)
├── sim/                            ← nền tảng và kịch bản mô phỏng
└── docs/                           ← tài liệu nguồn người dùng đưa vào (datasheet…)
```

**Ranh giới:** mọi thứ EIDE tự ghi nằm trong `.eide/`. Mã nguồn, `build/`, `docs/` là của dự án
và của người dùng — EIDE đọc, sinh, sửa qua cổng, nhưng không coi là kho riêng. Xoá `.eide/` thì
mất tri thức và lịch sử, **không mất mã**.

### 1.2. Tệp dự án — `.eide/constraints.yaml`

```yaml
project:
  id: doc-cam-bien-dht22-va-nhap-nhay-led-tren-arduino   # sinh từ câu mô tả
  name: Đọc cảm biến DHT22 và nhấp nháy LED trên Arduino Uno…
  created: '2026-09-14T05:37:45+00:00'
  text: <nguyên văn câu người dùng gõ khi tạo dự án>
target:
  chip: microchip.atmega328p      # ghim bằng project.set_target
  board: arduino-uno
  isa: avr8                       # SUY RA từ family_patterns, không gõ tay
  mcu: atmega328p
  f_cpu: 16000000
  pins: {…}
```

Ba tính chất đáng giữ:

1. **`text` giữ nguyên văn câu người dùng.** Đó là nguồn để suy lại mọi thứ khác, và là thứ
   người dùng nhận ra dự án của mình khi nhìn danh sách.
2. **`isa` suy ra, không nhập.** Người dùng nói chip; `family_patterns` trong `docs/spec/isa/`
   quyết ISA. Cho nhập tay là mở đường cho một dự án ATmega ghim ISA `armv7e-m`.
3. **Tệp này là thứ DUY NHẤT phải đọc để biết dự án nói về cái gì.** Mở dự án = đọc nó.

---

## Phần 2 — Usecase

Ký hiệu: **A** = tác tử tự làm · **N** = người làm · **A→N** = tác tử làm, người duyệt ·
**N→A** = người yêu cầu, tác tử thực hiện.

### Nhóm A — Vòng đời dự án

| # | Usecase | Ai | Đầu vào | Năng lực | Kết quả | Cổng |
|---|---|---|---|---|---|---|
| UC-A1 | **Tạo dự án từ một câu** | N→A | một câu tiếng Việt | `project.create` | thư mục + `.eide/` + tệp dự án | R2 |
| UC-A2 | **Mở dự án đã có** | N | chọn thư mục / dự án gần đây | `project.open` | daemon gắn vào dự án, 21 màn có dữ liệu | R0 |
| UC-A3 | **Chuyển sang dự án khác** | N | chọn từ menu dự án | (khởi động lại daemon) | panel dựng lại, không trộn hai dự án | — |
| UC-A4 | **Ghim đích phần cứng** | N→A | chip, board | `project.set_target` | `target` trong tệp dự án, ISA suy ra | R2 |
| UC-A5 | **Xem trạng thái dự án** | N | — | `project.status`, `report.progress` | tính năng, cổng mở, chi phí hôm nay | R0 |
| UC-A6 | **Nhân bản / lưu trữ dự án** | N→A | — | `project.clone`, `project.archive` | bản sao hoặc gói lưu trữ | R2 |
| UC-A7 | **Quay lại mốc trước** | N→A | mốc | `project.rollback` | store và mã về mốc ấy | R2 |
| UC-A8 | **Đặt tùy chọn dự án** | N | — | `project.preferences` | ghi M6 (`preferences.yaml`) | R1 |

**UC-A1 chi tiết** — đây là đường vào đầu tiên của sản phẩm:

1. Người gõ *"đọc cảm biến BME280 qua I2C trên ESP32-C3, in kết quả qua UART"*.
2. `project.create` suy ra `id` (slug), `name`, và **nếu câu có nhắc chip thì ghim luôn**.
3. Tạo thư mục, `.eide/`, tệp dự án, chạy migration store.
4. Tác tử nói lại cách nó hiểu (UC-B2) trước khi làm gì tiếp.

Điều **không** làm: không hỏi "tên dự án / đường dẫn / chip" thành ba ô. Bắt người quyết ba thứ
trước khi họ biết mình muốn gì là dựng rào ở đúng bước đầu tiên.

### Nhóm B — Làm rõ yêu cầu → chốt giải pháp → kiến trúc

| # | Usecase | Ai | Năng lực | Điều quan trọng |
|---|---|---|---|---|
| UC-B1 | **Nêu yêu cầu bằng câu tiếng Việt** | N→A | `chat.parse_intent` | một ô lệnh luôn gõ được, không phải một màn |
| UC-B2 | **Tác tử nói lại cách nó hiểu** | A | `chat.restate` | người bấm **"Sửa ý hiểu"** để nắn trước khi nó làm |
| UC-B3 | **Tác tử hỏi lại cho rõ** | A→N | `chat.clarify` | câu hỏi GỘP, không hỏi lắt nhắt từng cái |
| UC-B4 | **Bóc tách thành yêu cầu** | A | `req.elicit` | mỗi yêu cầu có id, truy được về câu gốc |
| UC-B5 | **Phân loại F/NF, gán ưu tiên** | A→N | `req.classify`, `req.prioritize` | đổi M↔S là quyết định của người (T1*) |
| UC-B6 | **Phát hiện yêu cầu mâu thuẫn** | A | `req.detect_conflict` | hai yêu cầu chống nhau phải lộ ra TRƯỚC khi viết mã |
| UC-B7 | **Neo yêu cầu vào phần cứng** | A | `req.ground_hw` | "đọc nhiệt độ" → I2C0, chân, điện áp — từ hộ chiếu |
| UC-B8 | **Sinh tiêu chí chấp nhận** | A | `req.acceptance` | Given-When-Then, **máy quan sát được** |
| UC-B9 | **Chốt kiểu kiến trúc** | A→N | `arch.style_select` | super-loop / RTOS / event-driven, **kèm lý do** |
| UC-B10 | **So sánh phương án** | A→N | `arch.compare` | bảng đánh đổi; người chọn (T1*) |
| UC-B11 | **Ngân sách RAM/Flash/thời gian** | A | `arch.memory_budget`, `arch.timing_budget` | đọc `memory_size` từ hộ chiếu — **không đoán** |
| UC-B12 | **Phân rã module + ánh xạ phần cứng** | A | `arch.decompose`, `arch.map_hw` | phát hiện xung đột chân ngay ở bước này |
| UC-B13 | **Máy trạng thái, giao diện module** | A | `arch.state_machine`, `arch.interface_spec` | |
| UC-B14 | **Ghi quyết định kiến trúc (ADR)** | A→N | `arch.adr` | quyết định có lý do và có ngày, tra lại được |
| UC-B15 | **Vẽ lược đồ** | A | `diagram.block/state/sequence/…` | lược đồ còn lỗi thì **không cho chèn vào tài liệu** |
| UC-B16 | **Lập kế hoạch thực hiện** | A→N | `plan.create` | cổng **G1**: thiếu tri thức thì dừng, không đoán |
| UC-B17 | **Đánh giá tác động khi đổi yêu cầu** | A | `req.change_impact` | tính năng nào về failing, mã nào phải sửa |

**Luồng chuẩn của nhóm B** (đây là "chốt giải pháp" mà chủ sản phẩm hỏi):

```
câu tiếng Việt
   → B2 tác tử nói lại cách hiểu ──► người sửa nếu sai
   → B3 hỏi gộp những chỗ chưa rõ ──► người trả lời một lần
   → B4/B5 bóc thành yêu cầu có ưu tiên
   → B6 mâu thuẫn? ──► người quyết
   → B7 neo vào phần cứng (cần hộ chiếu — nếu thiếu thì nhảy sang nhóm C)
   → B9/B10 chốt kiến trúc ──► người chọn
   → B11 ngân sách: có đủ RAM không?
   → B16 kế hoạch ──► CỔNG G1 ──► người duyệt
   → sang nhóm D
```

### Nhóm C — Thu nhận tri thức

| # | Usecase | Ai | Năng lực | Cổng |
|---|---|---|---|---|
| UC-C1 | **Tìm nguồn tài liệu hãng** | A | `search.vendor`, `search.rank` | — |
| UC-C2 | **Tải nguồn** | A→N | `search.fetch` | **G-SRC** |
| UC-C3 | **Nhập tài liệu người dùng đưa** | N→A | `ingest.classify`, `archive.*` | — |
| UC-C4 | **Trích fact máy đọc được** | A | `extract.svd/atdf/header_c/edc` | — |
| UC-C5 | **Trích fact từ PDF** | A→N | `extract.pdf_*` | tier bạc, **luôn duyệt** |
| UC-C6 | **Trích từ ảnh/schematic** | A→N | `extract.image_*`, `extract.ocr` | confidence −0,1 |
| UC-C7 | **Dựng đồ thị tri thức** | A | `kg.build` | — |
| UC-C8 | **Duyệt fact** | A→N | `kg.review_facts` | **G-FACT** |
| UC-C9 | **Xử lý xung đột tri thức** | N | `kg.conflicts`, `kg.resolve_conflict` | T3 — người quyết |
| UC-C10 | **Tra cứu hộ chiếu** | N | `passport.query`, `passport.resolve_address` | trả lời kèm **trích dẫn** |
| UC-C11 | **Hỏi đáp ngôn ngữ tự nhiên** | N | `view.rag_ask`, `view.rag_trace` | **không trích dẫn thì không trả lời** |
| UC-C12 | **Xem độ phủ tri thức** | N | `view.coverage_map` | ngoại vi nào chưa có fact |
| UC-C13 | **Nâng phiên bản hộ chiếu** | A→N | `passport.upgrade`, `passport.diff` | tính năng về failing |

### Nhóm D — Viết mã

| # | Usecase | Ai | Năng lực | Điều quan trọng |
|---|---|---|---|---|
| UC-D1 | **Sinh mã từ kế hoạch** | A→N | `code.generate` | mỗi hằng số phần cứng **trỏ về một fact** |
| UC-D2 | **Người tự viết/sửa mã** | N | *(màn Mã nguồn)* | EIDE không chiếm quyền — đây là trình soạn thảo thật |
| UC-D3 | **Gác hằng số không nguồn** | A | `code.constant_guard` | cổng G-FACT chặn merge nếu có hằng số lạ |
| UC-D4 | **Chú giải mã bằng fact** | A | `code.annotate` | hover một địa chỉ → biết ai nói thế |
| UC-D5 | **Dựng firmware** | A | `code.build` | việc NẶNG → chạy nền, huỷ được |
| UC-D6 | **Đo kích thước so với chip** | A | `code.size` | giới hạn lấy **từ fact `memory_size`** |
| UC-D7 | **Kiểm tĩnh + test host** | A | `code.static`, `code.test_host` | |
| UC-D8 | **Rà soát bản vá** | A→N | `code.review` | reviewer **khác hãng** với coder |
| UC-D9 | **Merge** | A→N | `code.merge` | **G3** + hạn hoàn tác |
| UC-D10 | **Tự sửa khi dựng hỏng** | A | `code.self_repair` | tối đa N vòng rồi leo thang |
| UC-D11 | **Giải thích một đoạn mã** | N→A | `code.explain` | |

### Nhóm E — Mô phỏng và phần cứng

| # | Usecase | Ai | Năng lực | Cần board |
|---|---|---|---|---|
| UC-E1 | **Dựng nền tảng mô phỏng** | A | `sim.build_platform` | không |
| UC-E2 | **Mock ngoại vi chưa có mô hình** | A→N | `sim.mock_peripheral` | không |
| UC-E3 | **Sinh kịch bản từ kỳ vọng** | A | `sim.scenario` | không |
| UC-E4 | **Chạy mô phỏng** | A | `sim.run` | không |
| UC-E5 | **Quét tham số** | A | `sim.sweep` | không |
| UC-E6 | **Dò board đang cắm** | A | `discover.*` | **CÓ** |
| UC-E7 | **Nhận diện chip trên board** | A | `target.detect`, `discover.chip_id` | **CÓ** |
| UC-E8 | **Nạp firmware** | A→N | `target.flash` | **CÓ** · **G-OPS** |
| UC-E9 | **Đọc serial / log** | N | `serial.*`, `debug.log_stats` | **CÓ** |
| UC-E10 | **Gỡ lỗi qua probe** | N→A | `debug.attach`, `debug.read_var` | **CÓ** |
| UC-E11 | **So mô phỏng với board thật** | A | `sim.compare_hil` | **CÓ** |
| UC-E12 | **Kiểm định hộ chiếu trên board** | A→N | `passport.verify_on_board` | **CÓ** |

### Nhóm F — Giám sát và điều khiển *(xuyên suốt mọi nhóm trên)*

| # | Usecase | Ai | Hiện ở đâu |
|---|---|---|---|
| UC-F1 | **Thấy tác tử đang làm gì** | N | vùng phải — dòng thời gian sổ cái |
| UC-F2 | **Duyệt / từ chối một mục chờ** | N | vùng phải — "Chờ anh", kèm cổng + quy tắc + lý do |
| UC-F3 | **Hoàn tác việc tác tử đã tự làm** | N | vùng phải — "Hoàn tác được", kèm hạn |
| UC-F4 | **Đổi mức tự chủ A0–A4** | N | thanh trên — ô chọn |
| UC-F5 | **Dừng khẩn** | N | thanh trên — nút đỏ, ⌘⇧. |
| UC-F6 | **Huỷ một việc đang chạy** | N | thẻ tiến trình — nút Huỷ |
| UC-F7 | **Xem chi phí token** | N | màn Mô hình & chi phí |
| UC-F8 | **Xem toàn bộ nhật ký, có lọc** | N | màn Nhật ký đầy đủ |
| UC-F9 | **Nhận leo thang** | N | thanh trên — băng "ĐANG CHỜ ANH" |

### Nhóm G — Tài liệu và chia sẻ

| # | Usecase | Ai | Năng lực |
|---|---|---|---|
| UC-G1 | **Sinh bộ tài liệu** (SRS, SAD, STP…) | A→N | `doc.generate` |
| UC-G2 | **Kiểm văn phong, chèn lược đồ** | A | `doc.style_check`, `doc.embed_diagram` |
| UC-G3 | **Đồng bộ tài liệu khi mã đổi** | A | `doc.sync` — báo mục nào **lỗi thời** |
| UC-G4 | **Ma trận truy vết yêu cầu → mã → test** | A | `req.trace_matrix` |
| UC-G5 | **Đóng gói tri thức thành pack** | A→N | `registry.pack`, `bench.badge` |
| UC-G6 | **Công bố / tải pack** | A→N | `registry.publish` (**G5**, R4), `registry.pull` |
| UC-G7 | **Tác tử tự viết công cụ còn thiếu** | A→N | `tool.*` (**G-TOOL**) |

---

## Phần 3 — Bộ nhớ, ngữ cảnh và nén

*Nguồn: MEM-11 §2–§6, CXD-10 §2–§7. Đây là phần trả lời câu hỏi "toàn bộ quá trình lưu bộ nhớ
context, lưu thông tin dự án nằm ở đâu, kỹ thuật nén bộ nhớ".*

### 3.1. Bảy tầng bộ nhớ

| Tầng | Nội dung | Sống bao lâu | **Lưu ở** | Ai ghi | Quên thế nào |
|---|---|---|---|---|---|
| **M0** Ngữ cảnh lượt | Gói gửi cho mô hình một lượt | một lời gọi | RAM; băm ghi vào sổ cái | Composer | mất ngay sau lượt; băm còn lại để tái tạo |
| **M1** Làm việc | Chuỗi đang chạy: intent, nút đang chạy, kết quả trung gian, câu hỏi đang chờ | một Run, tối đa vài giờ | RAM + `run.working` trong `store.sqlite` | Orchestrator, Router | xoá khi Run xong; **giữ tóm tắt vào M3** |
| **M2** Phiên | Lịch sử chat, quyền theo phiên (R4), board đang cắm, mức tự chủ hiệu lực, việc hoàn tác được | một phiên mở → đóng | `.eide/session/` (không commit) | ChatPanel, PolicyGate | đóng phiên: lịch sử → **1 tóm tắt** vào M3 |
| **M3** Tình tiết | Chuyện đã xảy ra CÓ BẰNG CHỨNG: Run, DecisionLog, ToolReport, Measurement, sổ lỗi, supersede | lâu dài, **chỉ-thêm** | `store.sqlite` + `ledger.jsonl` | mọi thành phần **qua Ledger** | không xoá; log lớn TTL 90 ngày, **giữ hash + 200 dòng đầu/cuối** |
| **M4** Ngữ nghĩa | Fact, hộ chiếu chip/mạch, ràng buộc, ReqSet, ModuleGraph, ADR | lâu dài, **phiên bản hoá** | `store.sqlite`, `.eide/docs` | **chỉ qua `passport.import`** + cổng | supersede, không xoá |
| **M5** Thủ tục | Cách làm: prompt vai trò, skill, chuỗi mẫu, quy tắc chính sách, ngưỡng | lâu dài, có phiên bản | `.eide/roles.yaml`, `autonomy.yaml`, `eide-packs/` | **người / Pack owner** | thay bằng phiên bản mới |
| **M6** Tùy chọn | Lựa chọn đã trả lời: tạo-khi-trùng, probe ưa thích, ngôn ngữ, sim-trước-nạp | tới khi người đổi | `.eide/preferences.yaml` + `~/.eide/preferences.yaml` | Orchestrator sau câu trả lời | người nói "hỏi lại tôi mỗi lần" |

**Ba bất biến của MEM-11** — chúng là lý do kiến trúc này khác một "chatbot có lịch sử":

1. **M1–M3 và M6 KHÔNG BAO GIỜ chứa fact phần cứng mới.** Một giá trị thanh ghi xuất hiện trong
   chat chỉ thành tri thức khi đi qua cổng ghi của KAD. Nói cách khác: *tác tử không thể tự
   thuyết phục mình về một địa chỉ nó vừa đoán.*
2. **Mọi bản ghi M3 có bằng chứng máy kiểm được** (hash, id, log_ref). Bộ nhớ tình tiết không
   lưu "cảm nhận".
3. **Đề xuất thay đổi M5 sinh từ M3 phải qua người.** Chính sách không tự nới lỏng.

### 3.2. Tám lớp ngữ cảnh cho mỗi lượt gọi mô hình

| Lớp | Nội dung | Nguồn | Cắt được? |
|---|---|---|---|
| **C0** | Mô tả top-k năng lực liên quan (≤ 60 token/năng lực) | Registry | thứ 6 |
| **C1** | Prompt vai trò, quy tắc trích dẫn, định dạng ra, **prompt phủ định từ sổ lỗi** | M5 | **KHÔNG** |
| **C2** | Ràng buộc dự án nén: chip, ISA, toolchain, mức tự chủ, chân cấm, ngân sách RAM/Flash | tệp dự án | **KHÔNG** |
| **C3** | Skill áp dụng được | M5 | thứ 5 |
| **C4** | **Fact có nguồn** quanh chủ đề | M4 | thứ 4 (xa 2 bước) rồi thứ 8 (1 bước) |
| **C5** | Mã liên quan | kho mã | thứ 3 rồi thứ 7 |
| **C6** | Tình tiết liên quan: lần hỏng trước, quyết định cũ | M3 | thứ 2 |
| **C7** | Tối đa **2 lượt gần nhất đã tóm tắt** | M1/M2 | **thứ 1 — cắt trước tiên** |

Thứ tự cắt là thứ tự **ngược với mức quan trọng**: lịch sử chat đi trước, ràng buộc dự án và
vai trò không bao giờ đi. Một mô hình quên lượt trước còn cứu được; một mô hình quên rằng chip
này chỉ có 2 KB RAM thì sinh ra mã không chạy.

### 3.3. Kỹ thuật nén

| Kỹ thuật | Áp cho lớp | Cách làm |
|---|---|---|
| **Tóm tắt lượt** | C7 | Lượt thứ 3 trở đi → tóm tắt bằng mô hình rẻ; giữ nguyên văn 2 lượt cuối |
| **Nén ràng buộc** | C2 | `constraints.yaml` → bảng khoá-giá trị một dòng mỗi mục, bỏ mô tả |
| **Lọc theo khoảng cách đồ thị** | C4 | Fact cách chủ đề > 2 bước bị bỏ trước |
| **Cắt theo phạm vi** | C5 | Chỉ mã trong module đang sửa; phần còn lại thành con trỏ |
| **Xếp hạng tình tiết** | C6 | `0,5·relevance + 0,3·recency + 0,2·importance`; top-5 ≤ 300 token |
| **Thay bằng con trỏ** | mọi lớp | `"xem <ref>, gọi tool X để lấy"` khi vẫn tràn |
| **Bộ đệm tiền tố** | C1→C2→C3 | `cacheable=true`; mục tiêu **≥ 60 %** trúng cache trong một tác vụ |

Công thức xếp hạng M3 (Generative Agents): `recency = e^(−Δngày/14)`; `importance = 1` nếu bản
ghi là *người từ chối* / *hoàn tác* / *kết luận gỡ lỗi*, `0,6` nếu ToolReport thất bại, `0,3`
nếu thành công thường. **Thất bại được nhớ kỹ hơn thành công** — đúng thứ một kỹ sư cần.

### 3.4. Khi vẫn tràn ngân sách

1. Orchestrator **chia nhỏ tác vụ** theo ModuleGraph (Feature → sub-feature).
2. Không được thì **nâng mô hình cửa sổ lớn hơn**, nếu chi phí còn trong ngân sách.
3. Vẫn không được thì **leo thang lên người**, kèm báo cáo *lớp nào chiếm bao nhiêu token* và
   gợi ý thu hẹp phạm vi. Không âm thầm cắt tới khi vừa.

### 3.5. Ngân sách đầu ra

`coder ≤ 16.000` · `writer ≤ 12.000` · các vai trò khác `≤ 4.000` token (đầu ra JSON có schema).

---

## Phần 4 — Điều thiết kế hiện tại còn thiếu so với usecase

*Đo 14/09/2026, sau khi đã dựng bố cục ba vùng và ô nhập sinh từ hợp đồng.*

| # | Thiếu | Usecase bị chặn | Ưu tiên |
|---|---|---|---|
| ~~1~~ | ~~Không có màn cho **UC-B2/B3**~~ — **XONG 15/09**: màn "Làm rõ yêu cầu", nhóm THIẾT KẾ ([DEV-109]) | B2, B3 | ~~1~~ |
| ~~2~~ | ~~**UC-C9** xung đột tri thức chưa có màn~~ — **XONG 15/09**: màn "Xung đột tri thức", hai cột song song ([DEV-109]) | C9 | ~~1~~ |
| ~~3~~ | ~~**UC-F7** chi phí đọc cấu hình thay vì sổ cái~~ — **XONG 15/09**: `ModelsView` gom `model.call` từ `view.timeline`; [DEV-093] đóng | F7 | ~~1~~ |
| ~~4~~ | ~~Ô nhập chưa có gợi ý~~ — **XONG 15/09**: `passport.list`/`project.status` nạp gợi ý; một giá trị duy nhất thì điền sẵn, nhiều thì gợi ý chứ không chọn hộ | C10, E4 | ~~2~~ |
| 5 | **UC-A6/A7** nhân bản, lưu trữ, rollback chưa có đường vào UI | A6, A7 | 3 |
| ~~6~~ | ~~**UC-B10** chưa có bảng đánh đổi~~ — **XONG 15/09**: ma trận + điểm + đánh dấu khuyến nghị, nói rõ người quyết (T1*) | B10 | ~~2~~ |
| ~~7~~ | ~~Chưa hiện **M2 phiên**~~ — **XONG 15/09**: `session.state` + màn Tổng quan; hai trường lõi chưa lưu được NÓI RA ([DEV-110]) | F1 | ~~2~~ |
| 8 | Chưa có chỗ xem **ngân sách token còn lại** trước khi chạy việc nặng | F7 | 3 |
