# docs/INDEX.md — đọc gì trước khi làm gì

Bộ hồ sơ v1.2 (05/09/2026). Tài liệu docx nằm trong `ho-so/`; đặc tả máy đọc được trong `spec/` (đây là bản chuẩn để test đối chiếu; docx là bản giải thích).

**Làm gì tiếp?** → [`CONG-VIEC.md`](CONG-VIEC.md) — danh sách công việc theo thứ tự nên làm, đo từ registry. Khối cần phần cứng để cuối cùng (quyết định 08/09).

**Đang ở đâu?** → [`TIEN-DO.md`](TIEN-DO.md) — tiến độ đo từ mã (năng lực theo mốc, chỗ đứt của năm chuỗi chuẩn, việc chờ chủ sản phẩm). Số liệu trong đó sinh lại bằng `eide spec`, `scripts/kiem_chuoi_chuan.py` và `pytest`, không gõ tay.

## Bản đồ nhanh: việc → tài liệu

| Việc | Đọc trước | Đặc tả máy đọc được |
|---|---|---|
| Hiểu sản phẩm, nguyên tắc P1–P9, lộ trình | EIDE-PDA-00 | — |
| Yêu cầu người dùng / chức năng | EIDE-URD-01, EIDE-SRS-02 (§3B: một FR cho mỗi năng lực) | `spec/caps.json` |
| Kiến trúc tổng thể, ADR | EIDE-SAD-03 | — |
| Thiết kế chi tiết mô-đun, cấu hình `.eide/*.yaml` | EIDE-SDD-04 | `spec/data/` |
| Hiện thực **một năng lực** | EIDE-CDS-12.x (tập theo bảng dưới) | `spec/capabilities/<ns>.yaml`, `spec/cds.json` |
| Cổng, mức tự chủ, quyết định APPROVE/ASK/REJECT | EIDE-APD-08, EIDE-POL-17 | `spec/policy/rules.yaml`, `spec/policy/situations.jsonl` |
| Hiểu lệnh, hỏi lại, điều phối chuỗi | EIDE-DPS-09, EIDE-PRS-16 | `spec/prompts/*.md` |
| Dựng ngữ cảnh cho LLM | EIDE-CXD-10 | — |
| Bộ nhớ tác tử M1–M6 | EIDE-MEM-11 | `spec/data/json/*.json` |
| Dữ liệu, SQLite, migration | EIDE-DDD-14 | `spec/data/schema.sql`, `spec/data/json/` |
| JSON-RPC / MCP / REST / CLI / mã lỗi | EIDE-API-15 | `spec/api/openrpc.json`, `mcp_tools.json`, `errors.json`, `ledger_events.json` |
| Giao diện | EIDE-UXD-13 | `ui/*.dc.html` |
| Chip/ISA/toolchain/dò board | EIDE-TGT-19 | `spec/isa/*.yaml` |
| Mô phỏng | EIDE-SIM-20 | — |
| Benchmark | EIDE-BEN-21 | — |
| Gói .hkp, registry | EIDE-PKG-22 | — |
| Plugin GEditor | EIDE-GPI-23 | — |
| Kiểm thử | EIDE-STP-05 | — |
| An toàn, sandbox công cụ tự viết | EIDE-SEC-25 | — |
| Cài đặt, phát hành đa nền tảng | EIDE-DEP-26, `PLATFORM.md` | — |
| Thuật ngữ | EIDE-CON-28 | — |
| Kế hoạch, backlog, truy vết | EIDE-PLN-27 (Excel), `SPRINT-01.md` | — |
| Quy trình làm việc với Claude Code | EIDE-DEV-29, `CLAUDE.md` | `.claude/commands/*.md` |
| Use case, sơ đồ tuần tự | EIDE_Use_Case_Chi_Tiet_v1.2.xlsx (sheet 10, 11) | — |

## Nhóm năng lực → tập CDS-12

| Tập | Nhóm |
|---|---|
| 12.1 Kỹ nghệ | req, arch, diagram, doc, plan |
| 12.2 Tri thức | archive, search, extract, passport, kg, board, view |
| 12.3 Hiện thực & tự tạo công cụ | env, code, project, **tool** |
| 12.4 Xác minh | discover, sim, target, debug, measure, bench |
| 12.5 Quản trị | policy, registry, report |
| 12.6 Hội thoại & bộ nhớ | chat, memory |

(Kiểm tra lại tập bằng `python scripts/spec_status.py --ns <ns>` — script đọc cds.json và in tập đúng.)

## Quy ước trích dẫn trong mã

Docstring của mỗi năng lực bắt đầu bằng dòng `Spec: <CAP-CODE> — CDS-12.x; POL-17 <rule ids>; DDD-14 <entity>`.

## Đối chiếu mã ↔ thiết kế

[`DOI-CHIEU-THIET-KE.md`](DOI-CHIEU-THIET-KE.md) — bộ hồ sơ mô tả bao nhiêu THỨ và mã đã
chạm tới bao nhiêu, trên **mười trục** chứ không riêng trục năng lực. Đọc cùng
[`TIEN-DO.md`](TIEN-DO.md): tệp kia trả lời "đi được bao xa", tệp này trả lời "còn
thiếu mặt nào".
