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
| WI-006 | Composer + Compressor: ContextBundle theo lớp C0–C7, ngân sách token, cache mark | CXD-10 §4–§7 | WI-003 | 4ng | Chưa |
| WI-011 | MCP server sinh tool từ registry | API-15 §MCP, `mcp_tools.json` | WI-003 | 2ng | Chưa |
| WI-012 | RagIndex: chunk, embedding qua Gateway, FTS5, truy hồi lai | KAD-07, CXD-10 §4.5 | WI-002 (index.sqlite đã có) | 3ng | Chưa |
| WI-020 | ToolForge `tool.*` (+ cổng G-TOOL đã có 6 quy tắc) | CDS-12.3 TOOL-01…07, SEC-25 | WI-009 ✓ | 4ng | Chưa |
| WI-021 | Plugin/panel GEditor: RpcClient sinh từ `openrpc.json`, ChatPanel, AutonomyBar, QueuePanel | UXD-13, GPI-23 (xem DEV-004) | WI-010 ✓ | 6ng | **Đang** — `EIDEKit` xong (client + mã sinh, 7 test nói chuyện thật với daemon); còn panel AppKit, chờ WI-258 |

## B. Năng lực

Thứ tự bám theo cái gì mở khóa cái gì, không theo số hiệu.

| Mã | Năng lực | Tập CDS | Vì sao ở sprint này |
|---|---|---|---|
| CHAT-01…05, 07, 08 | `parse_intent`, `ground`, `fill_defaults`, `clarify`, `restate`, `report_back`, `decline` | 12.6 | **Xong** — TC-59 đo với Gemini thật: intent 96–100%. CHAT-06 `orchestrate` là M2 |
| POLICY-02/06 | `policy.explain`, `policy.queue` | 12.5 | Hàng đợi "chờ tôi" của UXD U2 — nay có `policy.escalate` và `undo_window` làm nền |
| TOOL-01…07 | `tool.need/search/write/test/run/register/repair` | 12.3 | Sandbox đã đạt TC-SE-03; G-TOOL đã có quy tắc và 5/6 được tình huống phủ |
| MEMORY-01/02/03 | `memory.compose`, `compress`, `retrieve` | 12.6 | Đi cùng WI-006 và WI-012 |
| KG-* | `kg.build`, `kg.query`, `kg.review_facts` | 12.2 | **Gỡ nốt DEV-008** (bước 3 của `project.open`) |
| SEARCH/ARCHIVE/EXTRACT | `search.fetch`, `archive.explore`, `extract.pdf` | 12.2 | Cổng G-SRC và G-FACT đã có quy tắc nhưng chưa có năng lực nào đi qua |

## C. Kiểm thử và tài liệu

| WI | Việc | Ghi chú |
|---|---|---|
| WI-250 | TC-01…08 bất biến (STP-05) | Đang — phần tự chủ TC-51…57 đã xong ở Sprint 1 |
| WI-253 | TC hợp đồng sinh tự động cho 238 năng lực | Nay khả thi: `validate_specs.py` đã có, cần thêm sinh test từ `input_schema`/`errors` |
| — | Duyệt 14 bản nháp trong `docs/sync/`, sinh lại tài liệu lên v1.3 | `scripts/dong_bo_tai_lieu.py` → duyệt → `scripts/sinh_tai_lieu.sh <ten>` |
| **WI-257** | **Người:** ký danh sách trắng nguồn/gói/board lab | **Chặn**: PolicyGate đang chạy bằng `defaults.yaml` tạm (DEV-001), nên G-SRC/G-PKG mới là giả định |
| **WI-258** | **Người:** mã màu PTIT + ngôn ngữ lược đồ GEditor | **Chặn** WI-021 |

## Định nghĩa "xong" của sprint

1. Một câu tiếng Việt (`eide "nháy LED trên PB6 mỗi giây"`) đi qua Orchestrator ra một chuỗi
   năng lực có trích dẫn, cổng đúng, và báo cáo — kịch bản Z-01…Z-10 của PLN-27 mốc M1.
2. `make check-ca-hai` xanh; `scripts/nghiem_thu_sprint2.sh` chạy chuỗi ấy đầu-cuối.
3. Không mục DEVIATIONS `Mở` quá 7 ngày chưa duyệt; tài liệu đã đồng bộ lên v1.3.
4. `tool.*` viết được một công cụ nhỏ, chạy trong sandbox, và qua cổng G-TOOL.
