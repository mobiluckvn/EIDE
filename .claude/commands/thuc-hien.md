---
description: Hiện thực một năng lực theo đúng vòng lặp chuẩn (đọc spec → test trước → mã → check → ghi sai khác)
---
Hiện thực năng lực `$ARGUMENTS` theo vòng lặp chuẩn trong CLAUDE.md:

1. Chạy `/doc-nang-luc $ARGUMENTS` (đọc hợp đồng và tài liệu) — không bỏ qua.
2. Viết test trước trong `tests/test_<ns>.py`: mỗi câu trong trường `tc` và mỗi mã lỗi trong `errors` của hợp đồng là ít nhất một test; dùng `Router.invoke` (không gọi handler trực tiếp) để cổng và ledger được kiểm.
3. Viết handler trong `src/eide/caps/<ns>.py` với `@capability("<ns.name>", features=[...])`; docstring dòng đầu `Spec: <CODE> — CDS-12.x; POL-17 <rules>; DDD-14 <entity>`; kết quả phải khớp `output_schema` (Router kiểm — E6001 nếu sai).
4. Mọi đường dẫn `pathlib`, mọi tiến trình con dạng danh sách, mọi công cụ ngoài qua `eide_core.tools.which` (docs/PLATFORM.md).
5. `make check` phải xanh (ruff + pytest + check-spec). Nếu phải khác tài liệu: `/sai-khac` trước khi tiếp tục.
6. Cập nhật dòng tương ứng trong `docs/SPRINT-01.md` (trạng thái, nền tảng đã kiểm, mã DEV nếu có).
7. Commit: `[<CODE>] <ns.name>: <một dòng>` + phần thân ghi `Đọc: ...` và `Sai khác: DEV-xxx | không`.
