# Prompt dán vào Claude Code (chạy trong repo EIDE)

Gói thiết kế v1.4 nằm ở `docs/review-v1.4/`. Hãy:

1. Đọc `docs/review-v1.4/README_REVIEW_BRIEF.md` toàn bộ, rồi đọc ba tài liệu trong `docs/review-v1.4/docs/md/` theo thứ tự ghi ở §2 của brief (AGD-32 → AAD-33 → UIP-34), và `docs/review-v1.4/test/Usecase_Test_23-09-2026.md`.
2. Rà soát mã hiện tại (`rpc.py`, `src/eide/**`, `caps.json`, `intent.schema.json`, `chains.yaml`, cầu giao diện) so với thiết kế. Viết gap report `docs/md/EIDE-GAP-35_Ra_soat_ma_v1.4.md` đúng mẫu §7 của brief — mỗi mục thiết kế: CÓ / MỘT PHẦN / KHÔNG / KHÁC, tệp:dòng, ca đo liên quan, hành động, đợt. Đừng tin các dự đoán vị trí trong brief; xác minh bằng cách đọc mã.
3. Dừng lại, tóm tắt gap report cho tôi (số mục theo trạng thái, 10 sai lệch quan trọng nhất). Chờ tôi gật rồi mới sửa.
4. Khi tôi gật: sửa theo thứ tự Đ1 → Đ6 của brief §5, mỗi Đ một commit, có unit test cho phần xác định, chạy hồi quy 16 ca đang đạt, chạy các ca "mở khoá" ×5 lần, cập nhật `docs/review-v1.4/test/Usecase_Test_Agent_Ky_Su_Nhung.xlsx` (cột vàng). Mọi chỗ mã phải khác tài liệu → ghi `docs/md/EIDE-DEV-LOG.md` dạng [DEV-2xx].
5. Kết thúc: báo cáo thống kê 76 TC (trước/sau), danh sách DEV-2xx mới, đề xuất Đợt 2. Không làm UC15, TC071, Đợt 2–4 khi chưa được gật.

Ngôn ngữ: mã tiếng Anh; thông điệp cho người dùng và tài liệu tiếng Việt.
