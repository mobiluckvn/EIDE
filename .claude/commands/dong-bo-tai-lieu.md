---
description: Gom các mục DEVIATIONS "Mở" thành bản nháp cập nhật tài liệu để chủ sản phẩm duyệt
---
Đồng bộ tài liệu định kỳ (CLAUDE.md §Đồng bộ):

1. Đọc `docs/DEVIATIONS.md`, lọc trạng thái `Mở` và `Đã duyệt`, nhóm theo tài liệu (PDA/URD/SRS/SAD/SDD/STP/BPD/KAD/APD/DPS/CXD/MEM/CDS/UXD/DDD/API/PRS/POL/TGT/SIM/BEN/PKG/GPI/SEC/DEP/CON/PLN).
2. Với mỗi nhóm, viết `docs/sync/<YYYY-MM-DD>-<DOC>.md`: mục bị ảnh hưởng, nội dung hiện tại (trích), nội dung đề xuất, tệp nguồn sinh phải sửa (`docs/ho-so/nguon/<ten>.js` hoặc `cds_data_*.py`, `capabilities/*.yaml`, `rules.yaml`…), phiên bản đích (v1.3).
3. **Không** tự sửa docx và **không** tự sửa `docs/spec/` trong lệnh này; chỉ tạo bản nháp. Khi chủ sản phẩm duyệt, mới sửa nguồn sinh, sinh lại (`node <ten>.js`, `python gen_cds.py`), chép kết quả vào `docs/spec/` và đổi trạng thái mục thành `Đã cập nhật tài liệu v1.3`.
4. In tóm tắt: số mục theo tài liệu, mục nào cần quyết định của người.
