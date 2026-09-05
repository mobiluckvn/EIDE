# EIDE — hướng dẫn làm việc cho Claude Code

EIDE (Embedded IDE) là môi trường phát triển nhúng có tác tử (agent), sản phẩm của Đề án tốt nghiệp Thạc sĩ Kỹ thuật Điện tử — PTIT (học viên Vũ Trí Công, GVHD TS. Nguyễn Trung Hiếu). Kho này là **mã nguồn viết mới hoàn toàn** theo bộ hồ sơ thiết kế v1.2 trong `docs/`.

## Nguyên tắc số 1: đọc tài liệu rồi mới phát triển

1. **Tài liệu là nguồn sự thật.** Mọi hành vi của mã phải truy vết được về một tài liệu trong `docs/ho-so/` hoặc một tệp đặc tả máy đọc được trong `docs/spec/`. Không tự nghĩ ra hành vi, tên, schema, mã lỗi.
2. **Trước khi viết mã**, đọc theo thứ tự trong `docs/INDEX.md`: (a) hợp đồng năng lực trong `docs/spec/capabilities/<ns>.yaml` và `docs/spec/cds.json`; (b) mục tương ứng trong CDS-12 (tập nào ghi trong INDEX); (c) quy tắc chính sách `docs/spec/policy/rules.yaml`; (d) schema dữ liệu `docs/spec/data/`; (e) API `docs/spec/api/openrpc.json`. Ghi vào đầu mô tả PR/commit các tài liệu đã đọc (ví dụ `Đọc: CDS-12.3 §tool.write, POL-17 TOOL-01..05, DDD-14 capability_run`).
3. **Khi mã buộc phải khác tài liệu** (tài liệu sai, thiếu, mâu thuẫn, hoặc không khả thi trên nền tảng): *không sửa im lặng*. Ghi một mục vào `docs/DEVIATIONS.md` bằng lệnh `/sai-khac` (hoặc `python scripts/new_deviation.py`), trạng thái `Mở`, nêu tài liệu + mục bị ảnh hưởng, mã bị ảnh hưởng, cách xử lý đề xuất. Chủ sản phẩm sẽ duyệt và cập nhật tài liệu định kỳ (mục "Đồng bộ tài liệu" bên dưới).
4. **Không được làm**: đổi tên/mã năng lực, mã lỗi E1000–E8002, tên phương thức JSON-RPC, lớp rủi ro/mức tự chủ của năng lực, hoặc schema trong `docs/spec/` mà không có mục DEVIATIONS đi kèm. Kiểm tra bằng `make check-spec`.

## Cách làm một việc (vòng lặp chuẩn)

`/bat-dau` → chọn việc trong `docs/SPRINT-01.md` (nguồn: `docs/ho-so/EIDE-PLN-27_Ke_hoach_backlog.xlsx`) → `/doc-nang-luc <ns.name>` để in hợp đồng + tài liệu cần đọc → viết test trước từ `acceptance`/`errors` trong cds.json → hiện thực trong `src/eide/caps/<ns>.py` → `make check` (ruff, pytest, check-spec) → nếu có sai khác: `/sai-khac` → cập nhật trạng thái trong SPRINT-01.md → commit với tiền tố `[<CAP-CODE>]`.

Một commit = một năng lực hoặc một hạng mục WI của backlog. Không gộp.

## Cấu trúc kho

- `src/eide_core/` — lõi dùng chung (registry năng lực, PolicyGate, ledger, cấu hình, lỗi). Không phụ thuộc UI. Sau này có thể tách package dùng chung với EAA-U.
- `src/eide/` — sản phẩm: `cli.py` (lệnh `eide`), `daemon/` (JSON-RPC theo `openrpc.json`), `caps/<ns>.py` (hiện thực năng lực; mỗi hàm được đăng ký bằng `@capability("ns.name")`).
- `docs/spec/` — đặc tả máy đọc được (chuẩn để test đối chiếu). `docs/ho-so/` — 31 tài liệu docx + 4 Excel. `docs/ui/` — 23 mockup.
- `tests/` — pytest. `tests/test_specs_consistency.py` bảo đảm mã ≡ spec.
- `plugins/geditor/` — plugin GEditor (Swift), theo GPI-23; chưa bắt đầu ở Sprint 1.

## Nền tảng

Thứ tự: **macOS (Intel x86_64 và Apple Silicon arm64) trước**, sau đó Windows, Linux. Quy tắc viết mã đa nền tảng ở `docs/PLATFORM.md`: dùng `pathlib`, không hard-code `/`, không gọi lệnh shell dạng chuỗi, mọi công cụ ngoài (toolchain, probe) đi qua `eide_core.tools.which()` và bảng `docs/spec/isa/*.yaml`; mã riêng nền tảng đặt trong `src/eide_core/platform/<os>.py`. Không đánh dấu một năng lực "xong" nếu chỉ chạy trên Mac mà chưa có ghi chú nền tảng trong SPRINT-01.md.

## Chuẩn mã

Python ≥ 3.11, kiểu tĩnh (`from __future__ import annotations`, pydantic v2 cho schema), ruff (cấu hình trong `pyproject.toml`), pytest. Tên định danh tiếng Anh; docstring và thông điệp cho người dùng tiếng Việt (thuật ngữ Anh giữ nguyên kèm giải thích lần đầu). Không thêm thư viện mới nếu chưa ghi vào `pyproject.toml` kèm lý do trong commit.

## Đồng bộ tài liệu (định kỳ)

Cuối mỗi sprint hoặc khi `docs/DEVIATIONS.md` có ≥ 5 mục `Mở`: chạy `/dong-bo-tai-lieu` — lệnh liệt kê các mục Mở, nhóm theo tài liệu, sinh bản nháp thay đổi; chủ sản phẩm duyệt rồi cập nhật nguồn sinh trong `docs/ho-so/nguon/` (tài liệu = mã, sinh lại bằng `node <ten>.js`). Sau khi tài liệu cập nhật, đổi trạng thái mục thành `Đã cập nhật tài liệu vX.Y`.

## Điều Claude Code phải hỏi người

Chỉ hỏi khi: tài liệu mâu thuẫn nhau và không có mục DEVIATIONS trước đó về điểm này; việc cần thư viện/dịch vụ trả phí; thay đổi ảnh hưởng ≥ 3 nhóm năng lực. Mọi trường hợp khác: chọn phương án bám tài liệu nhất, ghi giả định vào DEVIATIONS nếu cần, và tiếp tục.
