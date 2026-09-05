# -*- coding: utf-8 -*-
"""Chính sách hội thoại & các kịch bản 'đầu vào chưa có gì' (EIDE-DPS-09)."""

# Quy tắc chung của tầng hiểu lệnh (áp dụng cho MỌI use case)
RULES = [
    ("D1", "Đối chiếu trạng thái trước khi hành động", "Mọi lệnh tạo/nạp/sinh đều đi qua bước 'grounding': tra dự án, hộ chiếu, board, feature, registry để biết cái người nói ĐÃ TỒN TẠI chưa (khớp tên gần đúng, mã chip, đường dẫn, thời gian gần nhất).", "Tránh tạo trùng; cho phép 'dùng luôn' thay vì làm lại."),
    ("D2", "Điền ô trống bằng mặc định trước, hỏi sau", "Tham số thiếu được điền bằng mặc định có căn cứ (mức A3, mô hình mặc định, ngân sách 5 USD, tên dự án từ câu lệnh). Chỉ hỏi khi không có mặc định hợp lý hoặc lựa chọn không hoàn tác được.", "Giảm số câu hỏi; mọi mặc định ghi vào ledger và có thể đổi bằng một câu."),
    ("D3", "Tối đa MỘT câu hỏi gộp cho mỗi lượt", "Nếu cần hỏi, gộp các điểm mơ hồ thành một câu có phương án đánh số và phương án mặc định được đánh dấu; im lặng quá T (cấu hình, ví dụ 2 phút) ⇒ chọn mặc định và báo.", "Người không bị hỏi dồn dập."),
    ("D4", "Đề xuất trước, làm ngay phần chắc chắn", "Khi đầu vào trống, tác tử đề xuất một kế hoạch ngắn (3–6 dòng) và LÀM NGAY những việc T1 không phụ thuộc quyết định (tạo khung dự án, tìm tài liệu tham khảo), song song với việc chờ câu trả lời.", "Không có thời gian chết."),
    ("D5", "Ưu tiên nguồn theo thứ tự: người nói > dự án hiện có > registry/mẫu tham chiếu > web", "Khi suy ra chip/board/linh kiện cho một ý tưởng (ví dụ 'robot hai bánh tự cân bằng'), tác tử tra mẫu tham chiếu trong registry trước, rồi mới tìm web, và luôn trình bày là ĐỀ XUẤT có nguồn.", "Nhất quán với KAD: tri thức có nguồn, K9 chỉ đề xuất."),
    ("D6", "Xác nhận bằng cách nói lại ý hiểu", "Trước một chuỗi dài, tác tử nói lại ý hiểu trong 1–2 câu ('Tôi hiểu là… tôi sẽ…') rồi làm; người có thể sửa bất cứ lúc nào, không cần bấm xác nhận.", "Giảm hiểu sai mà không thêm cổng."),
    ("D7", "Hành động hoàn tác được thì làm, không hoàn tác được thì hỏi", "Nguyên tắc của APD-08 áp dụng ngay trong hội thoại: tạo/sửa/nạp board lab làm ngay; xóa dự án, ghi đè dự án đang có, xóa flash ⇒ hỏi.", "—"),
    ("D8", "Ghi nhớ lựa chọn để lần sau không hỏi lại", "Mỗi câu trả lời của người (ví dụ 'luôn tạo mới', 'dùng ST-Link') được ghi thành tùy chọn dự án/người dùng; lần sau tác tử áp dụng và chỉ nhắc 'áp dụng như lần trước'.", "Số câu hỏi giảm dần theo thời gian."),
]

# Kịch bản đầu vào trống: (mã, câu lệnh, tác tử kiểm tra gì, kết quả kiểm tra, tác tử làm/hỏi gì, câu hỏi mẫu (nếu có), mặc định, UC/năng lực)
SCENARIOS = [
    ("Z-01", "\"Tạo cho anh dự án robot hai bánh tự cân bằng\"", "Có dự án tên gần giống (robot, cân bằng, balance) trong workspace? Có mẫu tham chiếu (reference project) trong registry? Có board/hộ chiếu nào đang mở?",
     "Không có gì", "Nói lại ý hiểu; tạo khung dự án 'robot-2-banh-tu-can-bang'; tra registry mẫu 'self-balancing robot' → đề xuất kiến trúc phần cứng (MCU, IMU, driver động cơ, nguồn) có nguồn; liệt kê cần gì từ anh (board có sẵn? tài liệu?)",
     "\"Tôi đã tạo dự án và đề xuất BOM tham chiếu (STM32F411 + MPU6050 + A4988 + 2 stepper, nguồn 12 V). Anh có board/tài liệu sẵn không, hay tôi dựng theo mẫu tham chiếu để mô phỏng trước? [1] Mẫu tham chiếu (mặc định) [2] Tôi gửi tài liệu\"",
     "[1] dựng theo mẫu tham chiếu, mô phỏng trước", "UC-A01, UC-A02, UC-G03, UC-E01"),
    ("Z-02", "(như Z-01)", "(như Z-01)", "Có dự án 'robot-ctrl' tạo 3 ngày trước, 5/8 feature passing",
     "Không tạo mới ngay; nói rõ đã có gì; đề nghị dùng tiếp, nhân bản, hoặc tạo mới",
     "\"Đã có dự án robot-ctrl (03/09, 5/8 tính năng chạy được, board BlackPill F411). Anh muốn: [1] tiếp tục dự án đó (mặc định) [2] nhân bản thành dự án mới [3] tạo mới trống\"",
     "[1] tiếp tục; nếu im lặng 2 phút ⇒ mở dự án cũ", "UC-A06, UC-A01"),
    ("Z-03", "(như Z-01)", "(như Z-01)", "Có mẫu tham chiếu trong registry (ví dụ eide.ref.balancing-robot@1.2) đã kiểm định trên board",
     "Đề xuất khởi tạo từ mẫu: kéo hộ chiếu chip/board, skill, kịch bản mô phỏng, firmware mẫu; báo khác biệt nếu người nêu linh kiện khác",
     "\"Registry có mẫu robot cân bằng đã kiểm định (STM32F411 + MPU6050). Dùng mẫu này làm điểm xuất phát chứ? [1] Có (mặc định) [2] Không, tôi có thiết kế riêng\"",
     "[1] dùng mẫu", "UC-G03, UC-A01"),
    ("Z-04", "\"Tạo dự án cho board này\" (kèm 1 ảnh board, không tài liệu)", "Nhận diện linh kiện trên ảnh; tra hộ chiếu theo nhãn chip đọc được; tra registry",
     "Đọc được 'STM32F411CEU6', 'MPU-6050'; không có schematic",
     "Tạo dự án; pull hộ chiếu chip; tạo BoardPassport ĐỀ XUẤT từ ảnh (tầng bạc, chờ duyệt); tìm schematic board phổ biến (BlackPill) trên registry/web; nêu rõ những gì chưa chắc",
     "\"Tôi nhận ra STM32F411CEU6 (BlackPill) và MPU6050. Tôi dùng sơ đồ BlackPill chuẩn từ registry cho phần MCU; dây nối MPU6050 tôi đoán từ ảnh (SCL→PB6, SDA→PB7) — anh xác nhận hoặc gửi schematic sau cũng được.\"",
     "Dùng sơ đồ chuẩn + net đoán từ ảnh ở tầng bạc; không sinh mã chạm net đoán cho tới khi duyệt", "UC-B05, UC-B06, UC-B08"),
    ("Z-05", "\"Viết firmware đọc nhiệt độ\" (chưa có dự án nào mở)", "Có dự án nào trong workspace? Dự án mở gần nhất? Có cảm biến nhiệt nào trong hộ chiếu?",
     "Không có dự án mở; có 2 dự án cũ",
     "Hỏi một câu gộp: dự án nào / board nào; nếu chỉ có một dự án có cảm biến nhiệt ⇒ chọn luôn và báo",
     "\"Anh muốn làm trên dự án nào? [1] robot-ctrl (có BME280, mặc định) [2] weather-node [3] dự án mới\"",
     "[1] dự án gần nhất có cảm biến phù hợp", "UC-H01, UC-D01"),
    ("Z-06", "\"Bắt đầu với chip ESP32-C3\" (không board, không tài liệu)", "Hộ chiếu esp.esp32-c3 có trong store/registry? Pack rv32/ESP-IDF đã cài?",
     "Có hộ chiếu (seed), chưa cài ESP-IDF",
     "Tạo dự án; ghim hộ chiếu; chạy eide doctor cài ESP-IDF (T1, danh sách tin cậy); dựng mô phỏng QEMU/Renode; hỏi một câu về board devkit nếu cần chân cụ thể",
     "\"Đã ghim hộ chiếu ESP32-C3 và đang cài ESP-IDF (~5 phút). Anh dùng devkit nào? [1] ESP32-C3-DevKitM-1 (mặc định) [2] board khác — gửi schematic sau\"",
     "[1] devkit chính hãng", "UC-A02, UC-A03, UC-E01"),
    ("Z-07", "\"Làm hết đi\" (sau khi thả zip, không nói gì thêm)", "Zip có gì? Suy ra được mục tiêu dự án từ README/tên tệp không?",
     "Có schematic, datasheet, README ghi 'balancing robot'",
     "Suy ra mục tiêu; đề xuất danh sách Feature (F-01…F-08) từ README + BOM; làm ngay tri thức, môi trường, mô phỏng; bắt đầu Feature không cần quyết định của người; gửi báo cáo tiến độ",
     "\"Tôi hiểu mục tiêu là robot cân bằng. Tôi đề xuất 8 tính năng theo README và bắt đầu từ F-01 (clock/UART). PID (F-07) chạm động cơ nên tôi sẽ hỏi trước khi nạp lên board thật.\"",
     "Làm theo đề xuất; F-07 chờ G1", "UC-B01, UC-D01, UC-D02, UC-E01"),
    ("Z-08", "\"Tạo dự án X\" nhưng tên X trùng đúng một dự án đang có", "Dự án X tồn tại?", "Có, đang có mã và feature",
     "Không ghi đè (R4). Hỏi rõ.",
     "\"Dự án X đã tồn tại (12 tệp, 3 tính năng). [1] Mở dự án đó (mặc định) [2] Tạo X-2 [3] Xóa và tạo lại (cần xác nhận rõ)\"",
     "[1] mở; [3] chỉ khi người gõ đúng cụm 'xóa X'", "UC-A01, UC-A06"),
    ("Z-09", "\"Mô phỏng thử cái robot\" (chưa có mô hình plant, chưa có tham số)", "Có sim/ chưa? Có mô hình plant chưa? Có tham số vật lý (khối lượng, bánh) trong hộ chiếu/README?",
     "Có sim nền tảng, chưa có plant",
     "Dựng plant với tham số MẶC ĐỊNH của mẫu tham chiếu (có nguồn), gắn nhãn 'tham số tạm', chạy ngay; đề nghị người cho số thật khi có",
     "\"Tôi chạy với tham số của mẫu tham chiếu (0,8 kg, bánh 65 mm, tâm khối 60 mm). Kết quả chỉ định tính cho tới khi anh cho số thật của robot.\"",
     "Tham số mẫu, nhãn tạm", "UC-E02, UC-E03"),
    ("Z-10", "\"Nạp lên board\" (không biết board nào nối máy)", "Cổng serial/probe nào đang có? Board có được đánh dấu lab? Artifact đã qua G3?",
     "Phát hiện ST-Link + STM32F411; board chưa đánh dấu lab; artifact đạt",
     "Vì board chưa đánh dấu lab ⇒ hỏi một lần và đề nghị đánh dấu để lần sau tự động",
     "\"Tôi thấy ST-Link nối STM32F411. Board này có động cơ không? [1] Không — đánh dấu 'lab' và nạp tự động từ nay (mặc định) [2] Có động cơ — chỉ nạp khi anh cho phép từng lần\"",
     "[1] nếu BoardPassport không có driver động cơ; ngược lại [2]", "UC-F01, UC-F02"),
]

# Nơi mô tả (trả lời câu hỏi 'những thứ như thế này mô tả ở đâu?')
WHERE = [
    ("Quy tắc chung của hội thoại (D1–D8)", "Tài liệu riêng: EIDE-DPS-09 'Chính sách hội thoại và suy luận ý định' (mới) — là phần 'tầng hiểu lệnh' của Agent Runtime; SRS-02 thêm nhóm FR-DLG", "Vì áp dụng xuyên suốt mọi UC, không thuộc riêng UC nào"),
    ("Kiểm tra tồn tại / dùng luôn hay tạo mới", "Trong từng use case: cột 'Tiền điều kiện' + 'Luồng thay thế' (sheet 4) — mỗi UC tạo/sửa đều có luồng 'đã tồn tại'; và trong hợp đồng năng lực (sheet 8): mục 'grounding' của từng capability", "Là hành vi cụ thể của năng lực đó"),
    ("Kịch bản đầu vào trống (Z-01…Z-10)", "Sheet 9 này (kịch bản hội thoại) + BPD-06 quy trình P0 'Tiếp nhận lệnh' (mới) + STP-05 test case hội thoại (TC-DLG)", "Là ca kiểm thử hành vi, cần chạy lại khi đổi mô hình/prompt"),
    ("Câu hỏi mẫu, mặc định, thời gian chờ", "autonomy.yaml (defaults, ask_timeout) + prompts/ của vai trò Librarian/Planner (K5 thủ tục) + tùy chọn đã ghi nhớ trong .hkw/preferences.yaml", "Là tham số vận hành, đổi không cần sửa mã"),
    ("Mẫu tham chiếu (reference project) như 'robot cân bằng'", "Registry: gói kind=template (hộ chiếu + BOM + skill + kịch bản mô phỏng + firmware mẫu) — KAD-07 thêm loại tri thức K5′ 'mẫu dự án'", "Để 'đầu vào trống' vẫn có điểm xuất phát có nguồn"),
]
