# SPRINT-02 — "Tác tử hiểu lệnh và tự tạo công cụ" (2 tuần)

Nguồn: `docs/ho-so/EIDE-PLN-27_Ke_hoach_backlog.xlsx` (mốc M1). Sprint 1 đã dựng xong **xương
sống**: lệnh → PolicyGate → năng lực → ledger, chạy thật trên cả hai kiến trúc Mac. Sprint 2
đặt **tầng hiểu lệnh** lên trên nó, để người gõ một câu tiếng Việt và tác tử tự chọn chuỗi
năng lực — đó là điều biến EIDE từ "bộ khung có cổng" thành tác tử.

Mỗi dòng: `Chưa` → `Đang` → `Xong` (kèm nền tảng đã kiểm và mã DEV nếu có).

## Vào sprint này với gì

| | |
|---|---|
| Hạ tầng đã có | WI-001 kho · WI-002 store+migration · WI-003 Registry/Router · WI-004 PolicyGate (46 quy tắc, 45/45 tình huống) · WI-007 Memory M1/M2 · WI-008 ledger có bộ lọc bí mật · WI-009 sandbox (TC-SE-03 đạt thật) · WI-010 CLI+JSON-RPC · WI-013 Gateway LLM (Gemini chạy thật) |
| Năng lực đã có | 17: `project.*` (5), `env.*` (4), `policy.*` (5), `memory.*` (2), `report.progress` |
| Bằng chứng | `make check-ca-hai` 254 test xanh; `scripts/nghiem_thu_sprint1.sh` 17/17 bước ĐẠT |
| Nợ mang sang | DEV-008 (tái dựng KG — chờ `kg.*`), 14 mục DEVIATIONS `Mở` đã có bản nháp đồng bộ ở `docs/sync/` |

## A. Hạ tầng

| WI | Việc | Tài liệu | Phụ thuộc | Ước | Trạng thái |
|---|---|---|---|---|---|
| WI-005 | **Orchestrator**: intent → ground → defaults → clarify → report | DPS-09 §3–§5, PRS-16 intent.md, SDD-04 §4.6 | WI-003, WI-004, WI-013 | 6ng | **Xong** (①③④; ② lập chuỗi = CHAT-06, mốc M2) |
| WI-006 | Composer + Compressor: ContextBundle theo lớp C0–C7, ngân sách token, cache mark | CXD-10 §2–§7 | WI-003 | 4ng | **Xong** — 23 test; TC-59 giữ 100% sau khi chuyển sang Composer |
| WI-011 | MCP server sinh tool từ registry | API-15 §MCP, `mcp_tools.json` | WI-003 | 2ng | **Xong** — `eide mcp` qua stdio, dùng được từ Claude Code/Cursor; 12 test |
| WI-012 | RagIndex: chunk, embedding qua Gateway, FTS5, truy hồi lai | KAD-07, CXD-10 §4.5 | WI-002 (index.sqlite đã có) | 3ng | **Xong** — `memory.retrieve` + `view.rag_index/rag_ask/rag_trace`; 11 test. Thang điểm sửa ở [DEV-058](DEVIATIONS.md) |
| WI-020 | ToolForge `tool.*` (+ cổng G-TOOL đã có 6 quy tắc) | CDS-12.3 TOOL-01…07, SEC-25 | WI-009 ✓ | 4ng | **Xong** — 7 năng lực M1, 29 test; Gemini viết được công cụ CRC-16/MODBUS chạy đúng |
| WI-021 | Plugin/panel GEditor: RpcClient sinh từ `openrpc.json`, ChatPanel, AutonomyBar, QueuePanel | UXD-13, GPI-23 (xem DEV-004) | WI-010 ✓ | 6ng | **Xong (bản đầu)** — `EIDEKit`: client + mã sinh (RPC và token), panel ba vùng, **đã gắn vào GEditorApp** (tầng `.eide`, menu "EIDE: trợ lý nhúng…"), 19 test Swift gồm đo tương phản WCAG và tìm daemon. Còn: gợi ý `/` (U1), thẻ câu hỏi gộp (U3) |

## B. Năng lực

Thứ tự bám theo cái gì mở khóa cái gì, không theo số hiệu.

| Mã | Năng lực | Tập CDS | Vì sao ở sprint này |
|---|---|---|---|
| CHAT-01…05, 07, 08 | `parse_intent`, `ground`, `fill_defaults`, `clarify`, `restate`, `report_back`, `decline` | 12.6 | **Xong** — TC-59 đo với Gemini thật: intent 96–100%. CHAT-06 `orchestrate` là M2 |
| POLICY-02/06 | `policy.explain`, `policy.queue` | 12.5 | Hàng đợi "chờ tôi" của UXD U2 — nay có `policy.escalate` và `undo_window` làm nền |
| TOOL-01…07 | `tool.need/search/write/test/run/register/repair` | 12.3 | **Xong** — bốn lớp bảo vệ (AST · audit hook · G-TOOL · đòi đã test). TOOL-08/09/10 là M2 |
| MEMORY-01/02 | `memory.compose`, `memory.compress` | 12.6 | **Xong**. MEMORY-03 `retrieve` đi cùng WI-012 RagIndex |
| KG-* | `kg.build`, `kg.query`, `kg.review_facts` | 12.2 | **Gỡ nốt DEV-008** (bước 3 của `project.open`) |
| REQ-01…08 | `elicit`, `classify`, `ground_hw`, `detect_conflict`, `prioritize`, `trace_matrix`, `acceptance`, `change_impact` | 12.1 | **Xong** — 34 test, cả 8 (5 ở mốc M1 + 3 M2 làm luôn vì chung bảng `requirement`). TC-67/TC-68 xanh. Đã kiểm cả arm64 lẫn x86_64 |
| ARCH-01…11 | `style_select`, `decompose`, `map_hw`, `memory_budget`, `timing_budget`, `interface_spec`, `state_machine`, `adr`, `review`, `compare`, `to_plan` | 12.1 | **Xong** — 60 test; TC-69/TC-70 xanh. Kèm migration `0004_m2_engineering_hw` (module, hw_map, adr, doc_artifact, discovery, measurement, `code_unit.module_id`) |
| ARCHIVE-05…07, EXTRACT-01/02, PASSPORT-01/02/03/07 | `ingest.classify/hash_dedupe/index_text`, `extract.svd/atdf`, `passport.import/query/list/export` | 12.2 | **Xong** — 47 test. Khép chuỗi thu nhận: tệp SVD/ATDF → `source` → `fact` → hộ chiếu → `passport.query`. **M0 từ 9/22 lên 17/22** |
| ARCHIVE-01/02, MEMORY-05, PROJECT-02, REGISTRY-01 | `archive.list/unpack`, `memory.ledger`, `project.set_target`, `registry.seed` | 12.2/12.6/12.3/12.5 | **Xong — mốc M0 đóng 22/22.** 36 test, phần lớn về việc KHÔNG làm gì |
| SEARCH-02/05/06/07/08 | `search.vendor`, `search.rank`, `search.fetch`, `search.verify_match`, `search.missing` | 12.2 | **Xong** — 39 test, **cổng G-SRC lần đầu có việc**. `search.web` hoãn theo quyết định chủ sản phẩm 07/09 (cần API tìm kiếm trả phí; `search.vendor` đã phủ phần lớn nhu cầu thật) |
| EXTRACT-03/04, 06/07/08, 19, 21 | `edc`, `header_c`, `pdf_layout`, `pdf_register_map`, `pdf_electrical`, `office`, `code_constants` | 12.2 | **Xong** — 38 test, PDF trong test là PDF THẬT (viết tay cú pháp PDF, có cả bảng kẻ khung). Mở khoá cảm biến/cơ cấu chấp hành: chúng chỉ có PDF, không có SVD/ATDF |
| VIEW-01…09 | `kg_map`, `kg_focus`, `provenance`, `conflict_board`, `rag_ask`, `rag_trace`, `rag_index`, `doc_side_by_side`, `export_map` | 12.4 | **Xong** — 38 test. Tầng trình bày: không sinh fact, không sửa store. Phát hiện [DEV-058](DEVIATIONS.md) — thang điểm FTS bị đảo từ Sprint 2 |
| DIAGRAM-01…04, DOC-05/07/08 | `diagram.lint/render/block/kg_view`, `doc.section/datasheet_summary/style_check` | 12.4 | **Xong** — 37 test. Bảng thuật ngữ CON-28 §6 nay sinh ra `doc/glossary.json` |
| SEARCH-09, ARCHIVE-03/04 | `search.web`, `archive.extract_one`, `archive.query` | 12.2 | **Xong 08/09** — `search.web` không buộc nhà cung cấp nào: `models.yaml → search.providers` xếp SearXNG đầu vì tự dựng được, không cần khóa |
| ENV-03/04 | `env.install`, `env.guide_install` | 12.3 | **Xong 08/09** — 20 test. Không `sudo` ở bất kỳ lệnh nào trong bảng; công cụ đóng → E4001 chỉ sang `guide_install`; lệnh cài chạy trong `env.sandbox` có mạng. Lộ ra một lỗi im lặng của sandbox (không ghi được vào chính `cwd` của nó) và một mâu thuẫn tài liệu ([DEV-060](DEVIATIONS.md)) |
| EXTRACT-09 | `extract.pdf_pinout` | 12.2 | **Xong 10/09** (M2, khối D) — 19 test, arm64 + x86_64. Số AF đọc từ **vị trí cột** trong bảng "Alternate function mapping", bằng mã chứ không gọi mô hình: hỏi mô hình một thứ đếm được là mở đường cho nó đếm sai. Nhánh hình package chưa có → [DEV-076](DEVIATIONS.md). Nối lại ba chỗ đang chờ `pin_function`: `board.propose_fix`, `diagram.pinmap`, `arch.map_hw` |
| EXTRACT-10 | `extract.pdf_errata` | 12.2 | **Xong 10/09** (M2, khối D) — 21 test, arm64 + x86_64. Lớp phủ **K2′** của KAD-07 §5.1: `fact.layer = "B"`, không đụng fact vàng của hãng (R1). Rev bị ảnh hưởng đọc từ **vị trí cột** `Rev A`/`Rev Z`, mô hình chỉ đọc văn xuôi (mô tả, workaround). T2 + ask "Luôn" ⇒ mọi lần đều qua người. Cạnh CONFLICTS_WITH → [DEV-077](DEVIATIONS.md) |
| EXTRACT-20 | `extract.readme_goal` | 12.2 | **Xong 10/09** (M2, khối D) — 7 test, arm64 + x86_64. README → mục tiêu + 5–10 feature có kỳ vọng MÁY quan sát được (lọc theo `plan.DANG_KY_VONG`, dùng chung hằng số với PLAN-01). R0 và `undo: none` vì nó ĐỀ XUẤT chứ không khẳng định — một câu trong README là ý định của người viết, không phải fact phần cứng |
| `code.constant_guard`, `passport.verify_on_board` | | | **M1 còn 2** — một cái làm cùng khối `code.*`, một cái chờ board thật |

**Mốc M0 đã đóng.** `tests/test_archive_m0.py` có một test cho chính bất biến ấy, để lần sau ai
thêm một mục M0 vào spec thì biết ngay là còn nợ thay vì phải nhớ đi đếm.

`archive.unpack` là bề mặt tấn công thật của EIDE — người dùng tải một "SDK" từ diễn đàn rồi bảo
tác tử mở ra. Tám lớp phòng thủ, mỗi lớp một test, và **cả tám đều đã được chứng minh bằng kiểm
đột biến** (gỡ lớp nào ra thì test tương ứng đỏ):

| Lớp | Mối đe dọa |
|---|---|
| zip-slip (resolve rồi kiểm `is_relative_to`) | entry `../../.ssh/authorized_keys` ghi ra ngoài |
| đường dẫn tuyệt đối | `/etc/cron.d/x` — lọc chuỗi `../` bỏ sót hoàn toàn |
| symlink trong zip (bit `external_attr`) | liên kết trỏ ra `/etc`, entry sau ghi "qua" nó |
| symlink/hardlink trong tar | cùng mối đe dọa, đường khác |
| tổng dung lượng ≤ 2 GB | zip bomb theo kích thước |
| tỷ lệ nén ≤ 100:1 | 42 KB → 4,5 PB |
| độ sâu đệ quy ≤ 5 (unpack) | lồng sâu làm cạn ngăn xếp |
| trần cứng `depth` (list) | như trên, độc lập với `depth` người gọi truyền |

Hai lớp cuối **thoát khỏi lượt kiểm đột biến đầu tiên**: cả hai test của tôi đều chạy dưới ngưỡng
nên chưa bao giờ chạm tới phép chặn. Cùng loại sai với test SAFETY ở `req.*` và ngưỡng 85% Flash
ở `arch.*` — test xanh vì lý do khác với lý do nó được viết ra.

Chuỗi thu nhận là vòng khép kín cuối cùng còn thiếu: trước nó, `req.ground_hw` và `arch.*` đọc
bảng `fact` mà không có đường nào đưa fact vào ngoài chèn tay — tức mọi kết luận "khả thi" đều
dựa trên dữ liệu do người gõ. Ba điểm:

- **Chữ ký nội dung đi trước phần mở rộng** (INGEST-01 bước 1, nguyên văn). Phần mở rộng là thứ
  người dùng gõ, không phải thứ tệp thật sự là. Một tệp tên `.atdf` mà ruột là trang lỗi 404, nếu
  tin cái tên, sẽ được gán `tier: gold` — và fact tầng vàng đi thẳng qua G-FACT không hỏi ai.
- **`passport.import` là cổng ghi duy nhất** vào bảng `fact` (SDD-04 §4.1). Ba dòng của bảng gộp
  KAD-07 §5.1 nằm ở đúng một chỗ, trong đó dòng khó nhất là dòng 3: fact mới **cùng tier**, giá
  trị khác thì thành `conflict`, KHÔNG ghi đè. Hai nguồn cùng tầng nói khác nhau về cùng một
  thanh ghi là thông tin — im lặng chọn cái mới thì quăng mất bằng chứng có gì đó không khớp.
- **Parser gold phải cẩn thận hơn parser bạc**, không phải ít hơn: fact vàng không bị chặn ở
  đâu cả. Nên `extract.svd`/`extract.atdf` thà bỏ sót còn hơn đoán — `_so()` trả `None` chứ
  không trả `0`, vì `0x00000000` là địa chỉ hợp lệ.

`extract.atdf` cũng là năng lực đầu tiên trong kho chạm tới AVR, khép một phần nợ nêu ở
[DEV-055](DEVIATIONS.md) (phần còn lại — schema manifest ISA và TC-48 — vẫn ở M5).

`arch.*` — ba chỗ phần deterministic quyết định hành vi:

- **Quy tắc tiền kiểm của ARCH-01 chạy TRƯỚC mô hình và thắng nó.** RAM 2 KB thì không nhét
  được kernel RTOS, bất kể lập luận hay đến đâu. Để mô hình quyết trước rồi kiểm sau nghĩa là
  thỉnh thoảng nó viết một lý do thuyết phục cho một phương án bất khả thi — và lý do thuyết
  phục thì khó cãi hơn là không có lý do.
- **`timing_budget` nói "chưa CHỨNG MINH được là lập lịch được", không nói "không lập lịch
  được".** Liu–Layland `U ≤ n(2^(1/n)−1)` là điều kiện đủ, không phải điều kiện cần. Báo sai một
  kiến trúc là bất khả thi sẽ đẩy người ta đi làm lại một thiết kế vốn đúng.
- **Chưa biết ≠ 0.** `ram_bytes = None` và `ok = None` là câu trả lời thứ ba, có thật: chưa nạp
  hộ chiếu thì `memory_budget` không được nói "đạt" (chưa so với gì cả) mà cũng không được chặn.

Migration `0004_m2_engineering_hw` làm lộ hai chỗ khác, cả hai đều là test cũ khoá đúng trạng
thái M1 — đó là việc của chúng: `plan.order`/`kg.conflicts` từng dựng bảng `module` giả, và
`kg.conflicts.resource_ready` nay là hằng số `True` vì `open_store` từ chối mọi store chưa di
trú (xem `tests/test_kg.py::test_resource_ready_khong_con_duong_nao_ra_False`).

`req.*` bám hợp đồng ở ba chỗ đáng ghi lại:

- **Chuẩn hóa đơn vị trước khi so ngưỡng.** Bảng `DON_VI` ghi tường minh `đơn vị → (đại lượng,
  hệ số)`. Suy hệ số từ tiền tố là bẫy: "M" trong `MHz`/`MSPS` là mega, "m" trong `ms`/`mA` là
  milli — cùng chữ cái, lệch 10⁹ lần. Không có bảng này thì REQ-04 báo "400 kHz ≠ 0,4 MHz".
- **`ground_hw` lọc fact theo hộ chiếu** (`fact.subject` khớp phần trước `@` của `passport.id`).
  Fact của chip khác dùng để kết luận "khả thi" còn tệ hơn không có fact nào — nó sai một cách
  tự tin. Không có fact ⇒ `ok=None` + đề nghị `kg.request`, không bao giờ đoán.
- **`req.prioritize` tính lại ưu tiên từ đầu**, không `cu or mặc_định`. Nếu đã có ưu tiên là bỏ
  qua thì ask "Đổi ưu tiên M↔S" của REQ-05 không có đường nào chạm tới — một quy tắc chết.
  SAFETY→M là quy tắc cứng đứng TRƯỚC mọi điều chỉnh, nên yêu cầu an toàn khó làm trên board
  hiện tại không tự tụt xuống S.

Thêm `openpyxl` vào phụ thuộc chạy (trước chỉ có ở `dev`): REQ-06 khai `format ∈ {xlsx, md}`, và
trả `.md` khi người dùng xin `.xlsx` là nói dối về đầu ra. Import trễ nên ai chỉ dùng `md` không
phải trả giá.

## C. Kiểm thử và tài liệu

| WI | Việc | Ghi chú |
|---|---|---|
| WI-250 | TC-01…08 bất biến (STP-05) | Đang — phần tự chủ TC-51…57 đã xong ở Sprint 1 |
| WI-253 | TC hợp đồng sinh tự động cho 238 năng lực | Nay khả thi: `validate_specs.py` đã có, cần thêm sinh test từ `input_schema`/`errors` |
| — | Duyệt 14 bản nháp trong `docs/sync/`, sinh lại tài liệu lên v1.3 | `scripts/dong_bo_tai_lieu.py` → duyệt → `scripts/sinh_tai_lieu.sh <ten>` |
| **WI-257** | **Người:** ký danh sách trắng nguồn/gói/board lab | **Chặn**: PolicyGate đang chạy bằng `defaults.yaml` tạm (DEV-001), nên G-SRC/G-PKG mới là giả định |
| **WI-259** | **Hoãn sang M5:** ISA rv32imac, xtensa-esp32, pic16/18 + schema manifest + TC-48 | **DEV-055.** Chủ sản phẩm quyết 07/09/2026 gộp về một mốc. ⚠️ Trong gói này có một món **nợ M0 chứ không phải việc tương lai**: `avr8.yaml` đã nằm trong kho từ Sprint 1 nhưng **không test nào chạm tới** — sai cú pháp hay thiếu khóa đều không ai báo. Cùng loại hỏng im lặng với DEV-052/053. Việc (1) của gói M5 (schema + nạp mọi tệp trong `docs/spec/isa/`) đóng luôn nợ này |
| **WI-258** | **Người:** XÁC NHẬN đỏ PTIT chính thức + ngôn ngữ lược đồ GEditor | Không còn chặn: dùng `#B8121F` theo UXD-13 §7 (tài liệu tự ghi "gần đúng, xác nhận với bộ nhận diện chính thức"). Đổi một chỗ ở `uxd.js` là cả mockup lẫn Swift theo |

## Định nghĩa "xong" của sprint

1. Một câu tiếng Việt (`eide "nháy LED trên PB6 mỗi giây"`) đi qua Orchestrator ra một chuỗi
   năng lực có trích dẫn, cổng đúng, và báo cáo — kịch bản Z-01…Z-10 của PLN-27 mốc M1.
2. `make check-ca-hai` xanh; `scripts/nghiem_thu_sprint2.sh` chạy chuỗi ấy đầu-cuối.
3. Không mục DEVIATIONS `Mở` quá 7 ngày chưa duyệt; tài liệu đã đồng bộ lên v1.3.
4. `tool.*` viết được một công cụ nhỏ, chạy trong sandbox, và qua cổng G-TOOL.


## Nhóm `search.*` — ba điều học được

**Bảng nguồn hãng TGT-19 §8 nay sinh ra `docs/spec/sources/vendors.yaml`.** Bảng ấy đã in trong
tài liệu; chép tay sang Python là tạo bản thứ hai sẽ trôi ngay lần hãng đổi đường dẫn. Đây là
lần thứ ba gặp đúng khuôn ấy (DEV-043 `PRED_W`, DEV-046 bản đồ màn hình UI), nên lần này làm
đúng ngay từ đầu: sửa `tgt_sim.js`, sinh lại, và mã đọc từ spec.

**G-SRC là cổng do Router áp, không phải do năng lực tự gọi.** Bản đầu tôi gọi `gate.decide`
ngay trong `search.fetch` — thành gác hai lần, và lần của Router chạy trước với đặc trưng rỗng
nên mọi lời gọi rơi vào G-SRC-99. Quy tắc phân loại đã có từ trước: cổng canh hiện vật TỒN TẠI
TRƯỚC lời gọi (`source`, `artifact`, `patch`, `pkg`) thì Router áp; cổng canh hiện vật năng lực
SINH RA (`fact`, `plan`) thì hỏi bên trong. `dac_trung_nguon()` là chỗ duy nhất dựng đặc trưng
`source.*`, để hai bên gọi không map thiếu trường mỗi bên một kiểu.

**Hai bộ từ vựng `kind` — [DEV-057](DEVIATIONS.md).** `Source.kind` của DDD-14 là ĐỊNH DẠNG
(`pdf`); `G-SRC-01` chờ `pdf_vendor`, một PHÁN XÉT ("PDF từ chính trang hãng"). Truyền thẳng
enum DDD-14 vào cổng thì mọi datasheet hãng trượt G-SRC-01 và rơi xuống ASK. Mất khá lâu mới
tìm ra vì mọi đặc trưng đều trông đúng — chỉ một từ lệch, và quy tắc không khớp thì im lặng rơi
xuống mặc định chứ không báo gì.


## Nhóm `extract.*` M1 — ba ranh giới

**Bố cục và ý nghĩa là hai việc, tách ra mới đúng.** `pdf_layout` chỉ chuyển PDF thành khối có
`bbox` và KHÔNG sinh fact; `pdf_register_map` mới hiểu bảng. Gộp lại thì không phân biệt được
"đọc sai trang" với "hiểu sai bảng" — hai lỗi sửa bằng hai cách khác nhau.

**Ba việc quanh mô hình vẫn là của mã.** *Chọn bảng* theo tiêu đề cột (một datasheet 900 trang
có hàng trăm bảng; đưa hết cho mô hình vừa tốn vừa làm nó lẫn bảng đặt hàng với bảng thanh ghi).
*`locator`* lấy từ khối, không hỏi mô hình — mô hình bịa số trang là chuyện thường, và một trích
dẫn sai tệ hơn không trích dẫn vì nó tạo vẻ đã kiểm chứng. *`confidence`* tính từ điểm bảng ×
độ khớp kiểu; mô hình tự chấm điểm tin cậy cho chính nó thì con số ấy không mang thông tin.

**`extract.pdf_electrical` là T2 và hỏi người MỌI LẦN** — đúng hợp đồng, không phải trở ngại
của test. Fact `voltage_range` sai là con đường ngắn nhất tới một board cháy.

Ghim `cryptography<44` trong `pyproject.toml` có lý do nền tảng: từ bản 44 PyPI không còn bánh
xe x86_64 cho macOS, pip dịch từ nguồn, và phần Rust dưới Rosetta sinh mã arm64 — tạo ra một
`.so` arm64 nằm trong venv x86 rồi hỏng lúc import. Bỏ trần này thì `make check-ca-hai` gãy ở
nhánh Intel.


## Nhóm `view.*` — và một lỗi im lặng từ Sprint 2

Bất biến của cả nhóm: **không có gì không có nguồn**. `view.kg_map` giữ `tier`/`status` nguyên
văn cho từng nút (trả mã màu mà bỏ trạng thái thì bản mù màu, bản in đen trắng và bản xuất
`graphml` đều mất thông tin); `view.provenance` dựng cả chuỗi supersede tới `Source`;
`view.rag_ask` **từ chối trả lời** khi không đủ đoạn có điểm.

Hai chỗ chọn "gom" thay vì "cắt": đồ thị quá lớn thì **gom cụm và ghi rõ `n`**, không cắt bớt —
cắt thì người xem thấy một đồ thị trông đầy đủ nhưng thiếu, và không có gì báo cho họ biết.

**[DEV-058] — thang điểm FTS bị đảo ngược từ Sprint 2 và không ai thấy.** `bm25()` của SQLite
trả số âm, càng âm càng khớp; bản đầu chuẩn hóa `1/(1+|bm25|)` nên đoạn khớp *mạnh* ra điểm gần
0 còn đoạn khớp *yếu* ra 1,0. Thứ hạng vẫn đúng nhờ `ORDER BY` trong SQL, nên lỗi im lặng hoàn
toàn suốt thời gian `memory.retrieve` là bên dùng duy nhất — nó chỉ cần thứ tự. Chỉ khi VIEW-05
dùng điểm làm **ngưỡng** thì hậu quả mới lộ: quy tắc "< 0,35 → not_found" thoái hóa thành phép
kiểm "có đoạn nào không".

Sửa xong lại lộ ra vấn đề thứ hai: **bm25 suy biến trên kho nhỏ** (từ có mặt trong mọi tài liệu
thì IDF = 0, nên kho một tài liệu luôn cho bm25 = 0). Nay điểm là trung bình của bm25 đồng biến
và **độ phủ** — tỷ lệ từ khóa câu hỏi xuất hiện trong đoạn: không suy biến, và giải thích được
cho người dùng.


## `diagram.*` + `doc.*` — hai bất biến, cùng một chữ

**Lược đồ là VĂN BẢN, ảnh chỉ là sản phẩm phụ.** CON-28 §6 định nghĩa "lược đồ" đúng một câu:
*"Sơ đồ ở dạng ngôn ngữ văn bản"*. `diagram.block` và `diagram.kg_view` trả **mã**, không trả
ảnh; muốn ảnh thì gọi `diagram.render`. Hệ quả: lược đồ vào Git dưới dạng khác biệt đọc được,
xem lại được lịch sử "vì sao cạnh này đổi", và `diagram.lint` kiểm được nội dung — một PNG thì
cả ba đều mất.

**Không có số nào không có trang.** `doc.datasheet_summary` KHÔNG gọi mô hình: nó xếp lại fact
và gắn `[src#page]` từ `locator`. Bản tóm tắt vì thế THIẾU so với datasheet gốc, và điều đó
đúng — một bản đầy đủ hơn dữ liệu là bản có phần bịa, mà người đọc không phân biệt được phần
nào. `doc.style_check` cưỡng chế chiều ngược lại: câu có số liệu kỹ thuật mà không trích dẫn thì
bị báo. Hai năng lực là hai nửa của một quy tắc.

Phép kiểm đáng giá nhất của `diagram.lint` là **nút lạ so với ModuleGraph**, không phải cú pháp:
lược đồ sai cú pháp thì renderer báo ngay, còn lược đồ đúng cú pháp mà vẽ sai hệ thống thì không
ai báo — nó được dán vào tài liệu và trở thành mô tả chính thức của một kiến trúc không tồn tại.

Bảng thuật ngữ CON-28 §6 nay sinh ra `docs/spec/doc/glossary.json` — lần thứ tư gặp khuôn
DEV-025/029/043/046, nên lần này đặt tên literal và sinh spec ngay từ đầu thay vì chép 34 dòng.
