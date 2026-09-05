# Nhật ký sai khác giữa mã và tài liệu (DEVIATIONS)

Quy tắc: mọi chỗ mã **buộc phải khác** bộ hồ sơ v1.2 đều ghi ở đây **trước khi commit**. Không sửa tài liệu trực tiếp trong docx; tài liệu được sinh lại từ `ho-so/nguon/` sau khi chủ sản phẩm duyệt. Thêm mục bằng `/sai-khac` hoặc `python scripts/new_deviation.py`.

Trạng thái: `Mở` → `Đã duyệt` (chủ sản phẩm đồng ý sửa tài liệu) | `Bác` (sửa mã cho khớp tài liệu) → `Đã cập nhật tài liệu vX.Y`.

| Mã | Ngày | Tài liệu / mục | Mã nguồn | Sai khác | Lý do | Đề xuất | Trạng thái |
|---|---|---|---|---|---|---|---|
| DEV-001 | 2026-09-05 | POL-17 §2 rules.yaml (`thresholds.*`, `trusted_sources`, `allowed_licenses`) | `src/eide_core/policy.py`, `docs/spec/policy/defaults.yaml` | rules.yaml tham chiếu ngưỡng nhưng giá trị mặc định chỉ có trong schema autonomy.json (POL-17 §5) và ví dụ SDD-04 §6; `allowed_licenses` không có giá trị mặc định ở đâu | Cần tệp mặc định để PolicyGate chạy được khi dự án chưa có `.eide/autonomy.yaml` | Thêm `spec/policy/defaults.yaml` (ngưỡng theo schema; `allowed_licenses` = MIT, BSD-2/3, Apache-2.0, CC-BY-4.0, vendor-doc) và ghi vào POL-17 §5 ở v1.3 | Mở |
| DEV-002 | 2026-09-05 | API-15 §3 errors.json | `src/eide_core/registry.py::validate_output` | Không có mã lỗi cho trường hợp *kết quả năng lực* không khớp `output_schema` (E5002 chỉ dành cho đầu ra mô hình) | Registry kiểm output mọi lời gọi để bắt lỗi hiện thực sớm (STP-05) | Tạm dùng E6001 SCHEMA_VIOLATION; đề xuất thêm E1004 OUTPUT_SCHEMA ở API-15 v1.3 | Mở |
| DEV-003 | 2026-09-05 | PLN-27 WI-001; SAD-03 ADR (kế thừa hkw-core) | `toàn kho` | Kho eide viết mới hoàn toàn, không đổi tên/kế thừa mã hkw-core M0; lõi tách package eide_core/ ngay từ đầu; CLI dùng argparse thay vì typer/rich | Quyết định của chủ sản phẩm 05/09/2026: làm mới hoàn toàn; giảm phụ thuộc để chạy trên 3 nền tảng | Sửa PLN-27 WI-001 thành 'khởi tạo kho eide'; ghi ADR-16 trong SAD-03 v1.3; DEP-26 bỏ bước migrate .hkw→.eide | Mở |
