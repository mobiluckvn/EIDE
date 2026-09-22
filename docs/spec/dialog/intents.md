# C0 — danh sách ý định cho vai trò `intent` (sinh từ DPS-09 §4.1)

- `project.create` — tạo dự án MỚI từ ý tưởng, tài liệu hoặc mã có sẵn
- `project.open` — mở hoặc TIẾP TỤC một dự án đã có ("tiếp tục việc hôm qua")
- `project.delete` — xóa hoặc ghi đè một dự án đã có
- `knowledge.build` — TÌM/TẢI hoặc nạp tài liệu, datasheet, zip, ảnh vào kho tri thức
- `env.setup` — cài, kiểm hoặc khóa toolchain và môi trường build
- `sim.run` — chạy firmware trên mô phỏng
- `code.feature` — viết hoặc sửa MÃ cho một tính năng, cấu hình ngoại vi
- `target.flash` — nạp firmware lên board thật
- `debug.ask` — hỏi về một LỖI ĐANG XẢY RA: log, HardFault, vì sao không chạy
- `req.analyze` — phân tích, làm rõ hoặc truy vết YÊU CẦU — làm việc TRÊN CHÍNH tập yêu cầu: rút ra, gán mã, tìm chỗ mơ hồ/mâu thuẫn, viết tiêu chí nghiệm thu
- `arch.design` — thiết kế kiến trúc: chia hệ thống thành MODULE/khối chức năng, chọn kiểu kiến trúc, ánh xạ phần cứng, kiểm xung đột chân, viết ADR
- `diagram.draw` — vẽ một lược đồ
- `doc.write` — viết MỘT tài liệu hoặc một mục tài liệu
- `view.ask` — hỏi TRI THỨC ĐÃ CÓ: thanh ghi, thông số, "X là gì", "vì sao đã chọn Y" (ADR)
- `discover.scan` — dò cổng, probe, chip đang cắm
- `policy.stop` — dừng khẩn, dừng mọi việc đang chạy (kể cả "dừng tự chủ")
- `policy.set` — đổi mức tự chủ, DUYỆT/từ chối mục chờ, HOÀN TÁC việc đã làm
- `big_command` — lệnh gồm NHIỀU bước thuộc nhiều nhóm: "làm hết đi", "dựng tri thức rồi viết firmware", "bộ tài liệu đầy đủ". CŨNG dùng tạm cho lệnh MỘT bước thuộc nhóm chưa có ý định riêng (registry, bench, measure, passport, kg, tool, search…) — khi ấy `is_big` vẫn là false
- `unknown` — không hiểu, hoặc mơ hồ tới mức đoán sẽ sai

Phân biệt:
- `view.ask` hỏi tri thức TĨNH đã có trong hộ chiếu; `debug.ask` hỏi về một hiện tượng ĐANG hỏng.
- `doc.write` là một tài liệu; cả BỘ tài liệu là `big_command`.
- `arch.design` gồm kiểm xung đột chân và ngân sách tài nguyên, không phải `debug.ask`.
- `req.analyze` làm việc TRÊN yêu cầu (rút ra, gán mã, tìm mâu thuẫn); `arch.design` làm việc TỪ yêu cầu ĐỂ RA module. Động từ quyết định, không phải danh từ: "chia hệ thống thành các khối", "thiết kế", "kiến trúc", "module" → `arch.design` — KỂ CẢ khi câu mở đầu bằng "từ các yêu cầu đã có". Một câu nhắc tới yêu cầu không có nghĩa là nó xin phân tích yêu cầu.
- `policy.set` gồm cả duyệt hàng đợi và hoàn tác, không phải `knowledge.build`.
- `big_command` KHÔNG kéo theo `is_big = true`: "đo dòng tiêu thụ khi ngủ" là một bước (measure.power) nhưng nhóm `measure` chưa có ý định riêng nên vẫn mang nhãn `big_command`.
- HƯỚNG ĐÃ CHỐT (DEV-035, 08/09/2026): nhóm năng lực nào còn thiếu thì thêm Ý ĐỊNH RIÊNG cho nhóm ấy, KHÔNG mở rộng nghĩa của `big_command`. `big_command` mô tả HÌNH DẠNG của lệnh (nhiều bước, nhiều nhóm), nên nhét thêm nghĩa "nhóm chưa có ý định" vào là trộn hai chiều phân loại khác nhau vào một nhãn. Việc thêm hoãn tới CHAT-06 `chat.orchestrate` vì lúc ấy Orchestrator phải chọn năng lực cho từng ý định nên bảng ánh xạ thiếu sẽ tự lộ ra; làm sớm thì phải gán nhãn lại cả 50 câu của TC-59 mà chưa có gì bắt buộc.

is_big:
- Phép thử: lệnh gọi TOÀN BỘ một chuỗi mẫu §4.4, hay chỉ MỘT NÚT của chuỗi ấy?
-   toàn bộ chuỗi → true · một nút → false.
- Cùng một nhóm năng lực có thể rơi vào cả hai phía: "viết SRS" là một nút (`doc.write`, false),
- "viết bộ tài liệu đầy đủ" là cả chuỗi P7 (true); "nạp lên board" là một nút (false),
- "dò board rồi nạp" là cả chuỗi Z-10 (true).
- Năm chuỗi mẫu: Z-01 dự án mới từ ý tưởng · Z-07 dự án mới từ tài liệu/zip · Z-05 thêm tính năng · P7 bộ tài liệu · Z-10 dò board rồi nạp.
- `big_command` KHÔNG kéo theo true: nhãn ấy còn dùng tạm cho lệnh một bước thuộc nhóm chưa có ý định riêng.
