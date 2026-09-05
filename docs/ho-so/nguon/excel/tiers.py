# -*- coding: utf-8 -*-
"""Phân loại công việc EIDE theo 3 mức tự chủ (rút gọn từ bảng 4 nhóm của Bước 3).
T1 = AI làm trọn (người xem báo cáo định kỳ / có thể hoàn tác)
T2 = AI làm — người duyệt (AI làm toàn bộ, người có thẩm quyền ký trước khi có hiệu lực; gồm cả 'AI chuẩn bị phương án, người chọn')
T3 = Người làm (AI chỉ cung cấp đầu vào)
"""
TIERS = [
    ("T1", "AI làm trọn", "Lặp lại nhiều, quy tắc rõ, kết quả kiểm được bằng máy, sai sót nhỏ và hoàn tác được", "Giao AI; người xem báo cáo định kỳ và có nút hoàn tác. Tương đương APPROVE tự động trong EIDE-APD-08."),
    ("T2", "AI làm — người duyệt", "AI làm được toàn bộ nhưng kết quả ràng buộc trách nhiệm, tiền bạc, hoặc cần chuyên môn người để chọn giữa các phương án", "AI làm/chuẩn bị đủ, người có thẩm quyền ký duyệt hoặc chọn phương án trước khi có hiệu lực. Tương đương ASK."),
    ("T3", "Người làm", "Rủi ro vật lý, không hoàn tác, quyết định chiến lược, quan hệ, pháp lý; hoặc cần tay/mắt người trên phần cứng", "Người làm; AI chỉ cung cấp thông tin đầu vào, checklist, kịch bản."),
]

# (nhóm quy trình, công việc, mức, đặc điểm nhận biết → lý do, cách giao cụ thể trong EIDE, UC liên quan, cổng cũ)
WORK = [
    # P0 Dự án & môi trường
    ("P0 Dự án & môi trường", "Tạo dự án, tệp tiến độ, cấu hình mặc định — theo một câu lệnh của kỹ sư", "T1", "Quy tắc rõ, hoàn tác được; tham số suy ra từ câu lệnh", "Kỹ sư ra lệnh; tác tử suy ra tên/mô tả/chip/đường dẫn và làm hết", "UC-A01, UC-H01", "—"),
    ("P0 Dự án & môi trường", "Suy ra chip/ISA/board từ tài liệu", "T1", "Kiểm được bằng đối chiếu 2 nguồn (SVD + KiCad + PDF)", "Tự xác nhận khi ≥ 2 nguồn khớp; báo cáo", "UC-A02, UC-B02", "G-FACT"),
    ("P0 Dự án & môi trường", "Chọn chip chính khi tài liệu nêu nhiều chip", "T2", "Cần chuyên môn người", "AI đề xuất kèm lý do; người chọn", "UC-A02", "G-FACT"),
    ("P0 Dự án & môi trường", "Kiểm và cài toolchain mở (gcc, probe-rs, Renode, kicad-cli)", "T1", "Danh sách gói tin cậy, hoàn tác được", "Tự cài từ danh sách trắng; khóa phiên bản; báo cáo", "UC-A03", "G-OPS"),
    ("P0 Dự án & môi trường", "Cài toolchain đóng/có license (XC8, IAR, Keil)", "T3", "Ràng buộc license, tài khoản hãng", "AI hướng dẫn từng bước; người tải và cài", "UC-A03", "G-OPS"),
    ("P0 Dự án & môi trường", "Cấu hình mô hình và ngân sách mặc định", "T1", "Mặc định an toàn (5 USD/ngày); đổi bằng một câu lệnh", "Tự áp; người chỉ nói khi muốn khác", "UC-A04", "—"),
    ("P0 Dự án & môi trường", "Tăng ngân sách vượt mặc định", "T2", "Ràng buộc tiền bạc", "AI hỏi khi sắp hết; người quyết", "UC-H03", "—"),
    ("P0 Dự án & môi trường", "Khảo sát repo có sẵn, sinh CONVENTIONS.md", "T1", "Quy tắc rõ, không phá hoại", "Tự làm; người xem", "UC-A05", "—"),
    ("P0 Dự án & môi trường", "Tiếp tục phiên, chạy build known-good", "T1", "Lặp lại", "Tự động khi mở dự án", "UC-A06", "—"),
    # P1 Nhận tri thức
    ("P1 Nhận tri thức", "Mở nén, phân loại tệp theo nội dung, tính hash", "T1", "Quy tắc rõ, sandbox", "Tự động", "UC-B01", "—"),
    ("P1 Nhận tri thức", "Nhập SVD/ATDF/EDC/header chính hãng", "T1", "Parser xác định, tầng vàng", "Tự động; báo số fact", "UC-B03", "—"),
    ("P1 Nhận tri thức", "Trích xuất PDF chính hãng thành fact", "T1", "Kiểm được: kiểu/dải hợp lý, đối chiếu nguồn 2", "Tự động; fact confidence ≥ 0,85 tự duyệt", "UC-B04", "G-FACT"),
    ("P1 Nhận tri thức", "Duyệt fact tin cậy thấp, fact từ ảnh/OCR, fact điện & timing an toàn", "T2", "Sai sót có thể hỏng board / sai điện áp", "AI trình nhóm + ảnh cắt; người duyệt theo nhóm", "UC-B10", "G-FACT"),
    ("P1 Nhận tri thức", "Giải quyết mâu thuẫn giữa nguồn", "T2", "Cần chuyên môn (phiên bản, biến thể chip)", "AI phân tích nguyên nhân và đề xuất; người chọn", "UC-B11", "G-FACT"),
    ("P1 Nhận tri thức", "Phát hiện thiếu tri thức, tạo yêu cầu", "T1", "Quy tắc rõ", "Tự động", "UC-B07, UC-H02", "—"),
    ("P1 Nhận tri thức", "Tìm nguồn trên registry / kho hãng / docs MCP", "T1", "Nguồn tin cậy, không tải trước", "Tự động; xếp hạng", "UC-B08", "—"),
    ("P1 Nhận tri thức", "Tải nguồn từ tên miền hãng trong danh sách tin cậy, hash/license rõ", "T1", "Hoàn tác được (xóa cache), rủi ro thấp", "Tự tải và tóm tắt; báo cáo", "UC-B09", "G-SRC"),
    ("P1 Nhận tri thức", "Chọn nguồn web ngoài danh sách tin cậy, license không rõ, tệp lớn", "T2", "Ràng buộc pháp lý (license), rủi ro tài liệu sai", "AI trình ứng viên có lý do; người chọn", "UC-B09", "G-SRC"),
    ("P1 Nhận tri thức", "Nhập KiCad, dựng BoardPassport", "T1", "Cấu trúc, kiểm được", "Tự động; báo cáo net/xung đột", "UC-B06", "G-FACT"),
    ("P1 Nhận tri thức", "Đọc ảnh schematic/board thành đề xuất net", "T2", "Tin cậy thấp bẩm sinh", "AI đề xuất kèm ảnh cắt; người xác nhận", "UC-B05", "G-FACT"),
    ("P1 Nhận tri thức", "Kiểm định hộ chiếu trên board lab (đọc ID, GPIO, UART)", "T1", "Board lab, hoàn tác bằng nạp lại", "Tự nạp và so; gắn huy hiệu", "UC-B12", "G-OPS"),
    ("P1 Nhận tri thức", "Nâng phiên bản tri thức (SVD mới) và ghim", "T2", "Ảnh hưởng mã đã passing", "AI báo diff + impact; người quyết định nâng", "UC-B13", "G1"),
    ("P1 Nhận tri thức", "Trả lời tra cứu có trích dẫn", "T1", "Đọc", "Tự động", "UC-B14", "—"),
    # P2–P3 Kế hoạch & mã
    ("P2 Lập kế hoạch", "Chuẩn hóa yêu cầu thành Feature/STEP; hỏi lại ≤ 3 câu khi mơ hồ", "T1", "Quy tắc rõ", "Tự động", "UC-D01", "—"),
    ("P2 Lập kế hoạch", "Kế hoạch không dùng tài nguyên mới, có trích dẫn đủ", "T1", "Kiểm được bằng validator + kg.conflicts", "Tự duyệt; báo cáo", "UC-D02", "G1"),
    ("P2 Lập kế hoạch", "Kế hoạch đổi kiến trúc (RTOS, clock, ISR, DMA) hoặc dùng tài nguyên mới", "T2", "Cần chuyên môn, ảnh hưởng rộng", "AI trình phương án; người chọn", "UC-D02, UC-C01", "G1"),
    ("P2 Lập kế hoạch", "Quyết định phương án xung đột chân khi chạm mã đã passing", "T2", "Ảnh hưởng phần cứng/mã", "AI đề xuất 2–3 phương án; người chọn", "UC-C01", "G1"),
    ("P3 Sinh mã", "Sinh mã với hkw:fact, 4 cổng công cụ, tự sửa ≤ 3 vòng", "T1", "Kiểm được bằng máy", "Tự động", "UC-D03", "—"),
    ("P3 Sinh mã", "Review khác hãng", "T1", "Kiểm được", "Tự động", "UC-D04", "—"),
    ("P3 Sinh mã", "Merge diff trong phạm vi Feature, reviewer PASS, không chạm ISR/linker/startup", "T1", "Hoàn tác được (git revert, known-good)", "Tự merge vào auto/; báo cáo; cửa sổ hoàn tác", "UC-D04", "G3"),
    ("P3 Sinh mã", "Merge diff chạm ISR/linker/startup, tăng kích thước > 5 điểm, reviewer có blocker", "T2", "Rủi ro cao, cần chuyên môn", "AI trình diff + bằng chứng; người duyệt", "UC-D04", "G3"),
    ("P3 Sinh mã", "Bổ sung hkw:fact cho mã cũ do người viết", "T1", "Gợi ý, không phá", "AI gợi ý một cú bấm; người chấp nhận hàng loạt", "UC-D05", "—"),
    ("P3 Sinh mã", "Hoàn tác về known-good", "T1", "Hoàn tác", "Tự động khi thất bại liên tiếp; báo cáo", "UC-D06", "—"),
    # P4 Mô phỏng & xác minh
    ("P4 Mô phỏng", "Dựng nền tảng mô phỏng (.repl) và mock ngoại vi chuẩn từ hộ chiếu", "T1", "Từ fact vàng, kiểm bằng firmware hello", "Tự động", "UC-E01", "—"),
    ("P4 Mô phỏng", "Tham số mock ngoại vi ngoài & mô hình plant (khối lượng, ma sát)", "T2", "Cần số liệu người có", "AI đề xuất + nguồn; người cung cấp/duyệt", "UC-E01, UC-E02", "G-FACT"),
    ("P4 Mô phỏng", "Sinh và chạy kịch bản SIL; so sánh với kỳ vọng", "T1", "Kiểm được", "Tự động", "UC-E03", "—"),
    ("P4 Mô phỏng", "Cập nhật mô hình từ chênh lệch SIL/HIL", "T2", "Ảnh hưởng mọi kết quả sau", "AI đề xuất tham số mới; người duyệt", "UC-E04", "G-FACT"),
    ("P4 Xác minh", "Nạp firmware đã qua G3 lên board lab; serial expect; probe đọc", "T1", "Board lab, hoàn tác được", "Tự động trong hạn mức nạp/giờ", "UC-F01, UC-F02", "G-OPS"),
    ("P4 Xác minh", "Xác nhận vật lý khi có cảm biến máy (serial, probe, logic analyzer, camera LED)", "T1", "Kiểm được bằng máy", "Tự động; badge 'auto-verified'", "UC-F03", "G4"),
    ("P4 Xác minh", "Xác nhận vật lý cần tay/mắt người (nghiêng board, nghe, sờ nhiệt)", "T3", "Cần người trên phần cứng", "AI đưa checklist quan sát; người xác nhận", "UC-F03", "G4"),
    ("P4 Xác minh", "Nạp lên board có cơ cấu chấp hành (động cơ, nguồn công suất)", "T2", "Rủi ro vật lý", "AI chuẩn bị firmware + kịch bản an toàn; người cấp quyền từng lần", "UC-F01", "G-OPS"),
    ("P4 Xác minh", "Xóa flash toàn bộ, ghi fuse/option byte, khóa đọc", "T3", "Không hoàn tác", "AI nêu lệnh và hậu quả; người thực hiện hoặc ký từng lần", "UC-F01", "G-OPS"),
    # P5 Gỡ lỗi
    ("P5 Gỡ lỗi", "Thống kê log, giả thuyết, thí nghiệm phân biệt trên board lab", "T1", "Đọc + board lab", "Tự động; báo cáo Diagnosis", "UC-F04, UC-F05", "G-OPS"),
    ("P5 Gỡ lỗi", "Đo tín hiệu/năng lượng bằng thiết bị đã nối", "T1", "Đọc", "Tự động", "UC-F06", "—"),
    ("P5 Gỡ lỗi", "Sửa ràng buộc phần mềm (giảm tốc độ bus, timeout)", "T1", "Hoàn tác được", "Tự áp dụng ở A3; báo cáo", "UC-F05, UC-D01", "—"),
    ("P5 Gỡ lỗi", "Sửa phần cứng (đổi điện trở, cắt mạch, hàn)", "T3", "Tay người, không hoàn tác", "AI nêu chẩn đoán, giá trị đề xuất; người làm", "UC-F05", "—"),
    ("P5 Gỡ lỗi", "Nối/đổi probe, cắm cáp, cấp nguồn", "T3", "Tay người", "AI hướng dẫn; người làm", "UC-F05", "—"),
    # P6 Chia sẻ & đánh giá
    ("P6 Chia sẻ", "Chạy benchmark, gắn huy hiệu, sửa skill từ ca lỗi (đề xuất)", "T1", "Kiểm được", "Tự động; đề xuất sửa skill chờ Pack owner", "UC-G01", "—"),
    ("P6 Chia sẻ", "Đóng gói và phát hành registry nội bộ (lớp/tổ chức)", "T1", "Hoàn tác được (rút gói)", "Tự động khi đủ huy hiệu và license rõ", "UC-G02", "G5"),
    ("P6 Chia sẻ", "Phát hành công khai; gói chứa dữ liệu mạch/dự án", "T2", "Pháp lý (license, IP)", "AI chuẩn bị; người ký", "UC-G02", "G5"),
    ("P6 Chia sẻ", "Xuất báo cáo, ma trận Người–AI", "T1", "Từ nhật ký", "Tự động", "UC-G04", "G5"),
    ("P6 Chia sẻ", "Nộp báo cáo, bảo vệ, trao đổi với giảng viên/khách hàng", "T3", "Quan hệ, trách nhiệm", "AI cung cấp số liệu; người làm", "UC-G04", "—"),
    # Quản trị chính sách
    ("Quản trị", "Đổi ngưỡng tự phê duyệt, mức tự chủ, danh sách trắng board/gói", "T2", "Chính sách không tự nới lỏng", "AI đề xuất từ lịch sử; người ký", "APD §6", "—"),
    ("Quản trị", "Dừng khẩn / hạ mức tự chủ", "T3", "Quyết định của người", "Lệnh 'dừng' ở bất kỳ đâu", "APD §5", "—"),
]
