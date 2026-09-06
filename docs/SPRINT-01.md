# SPRINT-01 — "Xương sống chạy được trên Mac" (2 tuần)

Nguồn: `docs/ho-so/EIDE-PLN-27_Ke_hoach_backlog.xlsx` (mốc M1, 99 hạng mục). Sprint này lấy phần **hạ tầng lõi** và các năng lực M0/M1 cần để chứng minh vòng lặp *lệnh → PolicyGate → năng lực → ledger* chạy thật trên macOS Intel và Apple Silicon. Mỗi dòng: `Chưa` → `Đang` → `Xong` (kèm nền tảng đã kiểm và mã DEV nếu có). Claude Code cập nhật bảng này qua `/thuc-hien`.

Ghi chú về WI-001 (PLN-27): kho làm mới hoàn toàn, **không** đổi tên hkw-core → WI-001 đổi thành "khởi tạo kho eide theo CLAUDE.md" (đã ghi DEV-003).

## A. Hạ tầng (theo WI của PLN-27)

| WI | Việc | Tài liệu | Trạng thái | Nền tảng | DEV |
|---|---|---|---|---|---|
| WI-001 | Khởi tạo kho eide: CLAUDE.md, .claude/, docs/spec, pyproject, CI | CLAUDE.md, PLATFORM.md, DEP-26 | Xong | mac-arm ✓, mac-intel ✓ (Rosetta 2, 06/09/2026), linux | DEV-003, DEV-005 |
| WI-008 | Ledger chuỗi hash + api/errors.json (bộ lọc bí mật: Sprint 2) | SEC-25 §3, API-15 §3, §5 | Xong (phần hash + kiểu sự kiện) | mac-arm ✓, mac-intel ✓ | — |
| WI-003 | Capability Registry + Router (nạp cds.json, kiểm schema, invoke, ledger; grounding/undo: Sprint 2) | SDD-04 §4, CDS-12, API-15 caps.* | Xong (bản đầu) | mac-arm ✓, mac-intel ✓ | DEV-002 |
| WI-004 | PolicyGate + rules.yaml + defaults.yaml (UndoService, decision_log SQLite: Sprint 2) | APD-08, POL-17 | Xong (bản đầu, 46 quy tắc) | mac-arm ✓, mac-intel ✓ | DEV-001 |
| WI-010 | JSON-RPC stdio (9/55 phương thức) + CLI eide | API-15 §1, §CLI | Xong (bản đầu) | mac-arm ✓, mac-intel ✓ | — |
| WI-002 | SQLite store + migration 0001/0002 + index riêng (0003) + `eide migrate` | DDD-14 §5, schema.sql | Xong | mac-arm ✓, mac-intel ✓ | DEV-006 |
| WI-007 | Memory M1/M2 (WorkingMemory, SessionMemory), PROGRESS/FEATURES tự sinh, resume | MEM-11 §2–§4, DDD-14 | Chưa | — | — |
| WI-009 | Sandbox tiến trình con + giám sát hiệu ứng (nền cho tool.*) | SEC-25 §4, CDS-12.3 env.sandbox | Chưa | — | — |
| WI-013 | Prompt 9 vai trò + models.yaml + Gateway LLM (Claude/Gemini) | PRS-16, SDD-04 §6, CXD-10 | Chưa | — | — |
| WI-005 | Orchestrator: intent → ground → defaults → clarify → chain → runner → report | DPS-09, PRS-16 intent.md, SDD-04 §4.3 | Chưa (Sprint 2) | — | — |
| WI-011 | MCP server sinh tool từ registry | API-15 §MCP, mcp_tools.json | Chưa (Sprint 2) | — | — |
| WI-020 | ToolForge tool.need/search/write/test/run/register (+G-TOOL) | CDS-12.3 TOOL-01…07, APD-08 §4.2, SEC-25 | Chưa (Sprint 2; phụ thuộc WI-009) | — | — |

## B. Năng lực (mỗi dòng = một commit)

| Mã | Năng lực | Tập CDS | tc (tiêu chí xong, rút gọn) | Trạng thái | Nền tảng | DEV |
|---|---|---|---|---|---|---|
| PROJECT-01 | project.create | 12.3 | cấu trúc .eide đúng; lần 2 cùng tên → E2001; gần giống → existing[] | Xong | mac-arm ✓, mac-intel ✓ | — |
| PROJECT-03 | project.list | 12.3 | 3 dự án mẫu đúng thứ tự | Xong | mac-arm ✓, mac-intel ✓ | — |
| ENV-01 | env.detect | 12.3 | macOS/Linux/Windows nhận đúng (ports/probes: Sprint 2) | Xong | mac-arm ✓, mac-intel ✓ | — |
| ENV-02 | env.check | 12.3 | thiếu gcc → ok=false kèm install hint; ISA lạ → E2000 | Xong | mac-arm ✓, mac-intel ✓ | — |
| POLICY-05 | policy.emergency_stop | 12.5 | TC-53: stopped=true, năng lực sau đó bị REJECT | Xong | mac-arm ✓, mac-intel ✓ | — |
| POLICY-07 | policy.set_autonomy | 12.5 | TC-56: nới lỏng cần by=human; siết tức thì; ghi autonomy.yaml | Xong | mac-arm ✓, mac-intel ✓ | — |
| PROJECT-02 | project.open | 12.3 | store hợp lệ → summary; ghi ngoài cổng → E6000; user_version cũ → E6003 | Xong (bước 3 và nửa bước 4 chờ WI-007) | mac-arm ✓, mac-intel ✓ | DEV-007, DEV-008 |
| PROJECT-08 | project.status | 12.3 | số liệu khớp ledger | Xong | mac-arm ✓, mac-intel ✓ | — |
| PROJECT-09 | project.preferences | 12.3 | D8: ghi/đọc preferences.yaml | Chưa | — | — |
| MEMORY-* | memory.progress, memory.summarize_session | 12.6 | theo MEM-11 | Chưa (cần WI-007) | — | — |
| POLICY-01 | policy.decide | 12.5 | 45 tình huống situations.jsonl đúng kỳ vọng | Chưa (đã có PolicyGate; cần bọc thành năng lực + test situations đầy đủ) | — | — |
| POLICY-03 | policy.undo_window | 12.5 | cửa sổ theo undo_window; E7000 khi hết hạn | Chưa | — | — |
| POLICY-04 | policy.escalate | 12.5 | leo thang theo kênh queue/chat/notify | Chưa | — | — |
| ENV-05 | env.lock | 12.3 | tools.lock ghi hash/phiên bản; trôi → cảnh báo | Chưa | — | — |
| ENV-07 | env.sandbox | 12.3 | giới hạn CPU/thời gian/tệp; vượt → E8000 | Chưa (= WI-009) | — | — |
| REPORT-01 | report.progress | 12.5 | PROGRESS.md sinh từ ledger/FEATURES | Chưa | — | — |

## C. Kiểm thử và tài liệu

| WI | Việc | Trạng thái |
|---|---|---|
| WI-250 | TC-01…08 bất biến + TC-66 registry + TC-51…57 tự chủ (STP-05) — đã có một phần trong tests/ | Đang |
| WI-253 | TC hợp đồng sinh tự động cho 238 năng lực (schema vào/ra, mã lỗi khai báo tồn tại) | Chưa |
| WI-257 | **Người:** ký danh sách trắng nguồn/gói/board lab, đặt autonomy.yaml ban đầu (defaults.yaml tạm dùng) | Chưa |
| WI-258 | **Người:** xác nhận mã màu PTIT chính thức và ngôn ngữ lược đồ GEditor hỗ trợ | Chưa |
| — | Chạy `make check` trên Mac Intel và Mac Apple Silicon thật; ghi nền tảng vào các dòng ở trên | **Xong** 06/09/2026 — arm64 gốc + x86_64 qua Rosetta 2, cả hai: ruff + spec + 36/36 test xanh |

## Định nghĩa "xong" của sprint

`make check` xanh trên macos-13 và macos-14 (CI) và trên máy Mac của chủ sản phẩm; `eide project new` → `eide caps invoke project.open` → `eide project list` chạy thật; DEVIATIONS không có mục `Mở` quá 7 ngày chưa được duyệt; SPRINT-02 được lập từ PLN-27 (Orchestrator + ToolForge + MCP).
