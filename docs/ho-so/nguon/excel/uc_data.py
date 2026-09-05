# -*- coding: utf-8 -*-
"""Dữ liệu use case chi tiết cho EIDE. Làn: N = người, T = tác tử, K = Knowledge Plane, H = công cụ/phần cứng."""

ACTORS = [
    ("Kỹ sư", "Người dùng chính", "Tạo dự án, nạp tài liệu, ra lệnh, phê duyệt tại mọi cổng, quan sát phần cứng"),
    ("Người phê duyệt", "Người dùng", "Có thể trùng kỹ sư; duyệt G-SRC/G-FACT/G1/G3/G4/G5; cấp quyền G-OPS"),
    ("Pack owner", "Người dùng", "Soạn skill, benchmark; kiểm định và phát hành gói"),
    ("Librarian", "Tác tử", "Phân loại, tìm nguồn, điều phối trích xuất, trả lời tra cứu có trích dẫn"),
    ("Cartographer", "Tác tử", "Dựng BoardPassport từ CAD/ảnh; kiểm xung đột chân"),
    ("Planner", "Tác tử", "Lập kế hoạch có trích dẫn; tự đánh giá đủ thông tin"),
    ("Coder", "Tác tử", "Sinh/sửa mã với hkw:fact cho mọi hằng số"),
    ("Reviewer", "Tác tử (khác hãng)", "Chấm CodePatch theo checklist Pack"),
    ("Tester", "Tác tử", "Sinh kịch bản, dựng mô phỏng, chạy SIL/HIL, benchmark, huy hiệu"),
    ("Debugger", "Tác tử", "Giả thuyết, thí nghiệm phân biệt, gói chứng cứ"),
    ("Knowledge Plane", "Hệ thống", "Store, đồ thị, cổng người, hooks, ledger, router mô hình"),
    ("Tool Layer / Phần cứng", "Hệ thống/vật lý", "Toolchain, flash, serial, probe, mô phỏng, thiết bị đo"),
    ("Nguồn ngoài", "Hệ thống ngoài", "Registry, kho hãng (SVD/ATDF), docs MCP, web"),
]

GATES = [
    ("G-SRC", "Chọn nguồn", "Trước khi tải/trích xuất bất kỳ tài liệu nào tìm được trên mạng hoặc registry"),
    ("G-FACT", "Duyệt fact", "Trước khi fact tầng bạc/đồng được dùng cho sinh mã; duyệt theo nhóm có ảnh cắt"),
    ("G1", "Duyệt kế hoạch", "Trước khi viết mã"),
    ("G3", "Duyệt merge", "Sau 4 cổng công cụ + reviewer khác hãng; trước khi mã vào nhánh chính"),
    ("G4", "Xác nhận vật lý", "Người quan sát board (LED, chuyển động, số đo) trước khi tính năng passing"),
    ("G5", "Duyệt bàn giao/phát hành", "Trước khi xuất báo cáo, đóng gói, publish"),
    ("G-OPS", "Cấp quyền thao tác nguy hiểm", "Nạp, xóa flash, ghi bộ nhớ, ghi fuse, cài phần mềm, tải tệp lớn — theo phiên"),
]

# (id, name, group, primary, secondary, goal, trigger, pre, post, gates, knowledge, priority, milestone, FR, UR, screen)
UCS = []
FLOWS = {}   # id -> list of (lane, action, input, output, gate_or_note)
ALTS = {}    # id -> list of (alt_id, condition, handling)

def uc(id, name, group, primary, secondary, goal, trigger, pre, post, gates, knowledge, prio, ms, fr, ur, screen, flow, alts=()):
    UCS.append((id, name, group, primary, secondary, goal, trigger, pre, post, gates, knowledge, prio, ms, fr, ur, screen))
    FLOWS[id] = flow
    ALTS[id] = list(alts)

# ---------------------------------------------------------------- A. Dự án & môi trường
uc("UC-A01", "Tạo dự án mới", "A. Dự án & môi trường", "Kỹ sư", "Knowledge Plane",
   "Có một thư mục dự án với .hkw/, tệp tiến độ, cấu hình mô hình, sẵn sàng nhận tài liệu",
   "Kỹ sư bấm 'Dự án mới' hoặc chạy eide init", "EIDE đã cài; eide doctor cơ bản đạt",
   "Thư mục .hkw/ (store.sqlite, FEATURES.json, PROGRESS.md, models.yaml, constraints.yaml) được tạo và commit Git",
   "—", "K6 (dự án): tên, mô tả, ISA/chip/board nếu đã biết", "M", "M0", "FR-GOV-03, FR-PSP-03", "UR-QT-03, UR-QT-04", "Tổng quan",
   [("N", "Ra lệnh bằng ngôn ngữ tự nhiên, ví dụ: 'Tạo dự án robot cân bằng từ thư mục ~/robot-kit, chip chưa rõ' (một câu; có thể kèm kéo thả)", "câu lệnh", "", "Lệnh"),
    ("T", "Librarian suy ra tên dự án, mô tả, chip/board (nếu nêu), đường dẫn tài liệu từ câu lệnh; điền mọi tham số mặc định (mức tự chủ A3, mô hình, ngân sách)", "câu lệnh", "tham số dự án", ""),
    ("K", "Tạo .hkw/ với schema store, tệp mặc định, .gitignore; ghi ledger 'project.init'", "tham số", ".hkw/", ""),
    ("K", "Nếu đã biết chip: pull hộ chiếu lõi từ registry/seed và ghim phiên bản vào constraints.yaml", "chip id", "pin", "UC-G04"),
    ("T", "Nếu câu lệnh có tài liệu: tự chuyển sang UC-B01 ngay; nếu không: hỏi đúng một câu 'anh có tài liệu board không?'", "", "", "")],
   [("A1", "Thư mục đã có .hkw/", "Hỏi: mở dự án hiện có (UC-A06) hay khởi tạo lại (cần xác nhận, không xóa store)"),
    ("A2", "Chưa có mô hình nào cấu hình khóa API", "Chuyển sang chế độ cục bộ nếu có Ollama; nếu không, vẫn tạo dự án nhưng tác tử tạm tắt (chỉ nhập tri thức tầng vàng bằng parser)")])

uc("UC-A02", "Khai báo hoặc suy ra chip / ISA / board của dự án", "A. Dự án & môi trường", "Kỹ sư", "Librarian, Knowledge Plane",
   "Dự án biết mình chạy trên tập lệnh nào, chip nào, mạch nào — hoặc biết là chưa biết và cần nhận tri thức",
   "Sau UC-A01 hoặc sau khi nhập tài liệu phát hiện chip", "Dự án đã tạo",
   "constraints.yaml có isa/chip/board (hoặc 'unknown' kèm AcquisitionRequest mở)",
   "G-FACT nếu suy ra từ tài liệu", "K1 ISA profile, K2 lõi (pin), K3 board (nếu có)", "M", "M0", "FR-PSP-01, FR-BRD-01", "UR-TT-02, UR-PK-03", "Tổng quan / Hộ chiếu chip",
   [("T", "Lấy mã chip từ câu lệnh nếu người nêu (ví dụ 'dùng STM32F411CE'); nếu không, suy ra từ tài liệu ở UC-B02", "câu lệnh/tài liệu", "mã chip (đề xuất)", ""),
    ("K", "Tra passport.list; nếu có lõi → ghim; nếu không → tìm registry/seed (UC-B08)", "mã", "pin hoặc yêu cầu", ""),
    ("T", "Nếu bỏ trống: Librarian sẽ suy ra chip từ tài liệu (SVD/schematic/ảnh) ở UC-B02 và đề xuất; người xác nhận", "tài liệu", "đề xuất chip", "G-FACT"),
    ("K", "Nạp ISA profile tương ứng (armv7e-m, avr8, rv32…) và toolchain manifest", "chip", "ISA", ""),
    ("K", "Ghi ledger; cập nhật thanh trạng thái 'Pin: …'", "", "", "")],
   [("A1", "Chip tùy chỉnh (không có SVD/ATDF)", "Tạo ISA profile 'custom' + hướng dẫn kỹ sư cung cấp bản đồ thanh ghi (SVD/CSV/YAML) → UC-B03 với nguồn do người cung cấp"),
    ("A2", "Tài liệu nêu 2 chip khác nhau", "Hỏi người: chip chính nào; chip còn lại là ngoại vi ngoài hay MCU phụ")])

uc("UC-A03", "Khám phá, cài đặt và khóa toolchain (eide doctor)", "A. Dự án & môi trường", "Kỹ sư", "Knowledge Plane, Tool Layer",
   "Máy có đủ công cụ biên dịch/nạp/mô phỏng cho ISA của dự án, phiên bản được khóa để tái lập",
   "Sau UC-A02; hoặc khi một cổng công cụ báo thiếu công cụ; hoặc lệnh eide doctor",
   "ISA profile đã chọn (có toolchain manifest)",
   "tools.lock ghi tên/phiên bản/hash; báo cáo môi trường; công cụ tùy chọn được đánh dấu",
   "G-OPS cho mỗi lệnh cài", "K8 (môi trường), hồ sơ tái lập", "M", "M1", "FR-GOV-04", "UR-QT-05, UR-PK-05", "Môi trường & báo cáo",
   [("K", "Đọc toolchain manifest của ISA profile (tên, phiên bản tối thiểu, lệnh kiểm, cách cài theo hệ điều hành)", "manifest", "danh sách", ""),
    ("H", "Chạy lệnh kiểm từng công cụ (which/--version); phát hiện probe USB", "", "có/thiếu/phiên bản", ""),
    ("T", "Librarian tổng hợp: bắt buộc thiếu gì, tùy chọn thiếu gì, đề xuất lệnh cài theo hệ điều hành", "kết quả", "đề xuất", ""),
    ("T", "Công cụ mở trong danh sách tin cậy: tự cài (T1); công cụ đóng/có license: hướng dẫn người cài (T3)", "đề xuất", "quyết định", "G-OPS"),
    ("H", "Cài; kiểm lại phiên bản; tính hash nhị phân", "", "", ""),
    ("K", "Ghi tools.lock; ledger; cập nhật thanh trạng thái Toolchain", "", "tools.lock", "")],
   [("A1", "Toolchain đóng (XC8/IAR/Keil)", "Không tự cài; hướng dẫn tải từ hãng; chỉ kiểm sự có mặt và phiên bản"),
    ("A2", "Không có mạng (offline)", "Chỉ kiểm; liệt kê gói cần tải thủ công kèm hash mong đợi"),
    ("A3", "Phiên bản đã khóa khác phiên bản có trên máy", "Cảnh báo lệch; hỏi khóa lại hay cài đúng phiên bản cũ")])

uc("UC-A04", "Cấu hình mô hình ngôn ngữ và chế độ cục bộ", "A. Dự án & môi trường", "Kỹ sư", "Knowledge Plane",
   "Chọn mô hình theo vai trò, ngân sách ngày, chế độ cục bộ (không gửi tài liệu ra ngoài)",
   "Lần đầu tạo dự án; dự án nhạy cảm; đổi nhà cung cấp", "models.yaml mặc định tồn tại",
   "models.yaml hợp lệ; router kiểm được ứng viên; egress-guard bật/tắt theo cấu hình",
   "—", "K8 chính sách mô hình", "M", "M0", "FR-LLM-02, FR-AGT-04, FR-LLM-04", "UR-MH-01, UR-MH-02, UR-MH-03", "Mô hình & chi phí",
   [("T", "Áp cấu hình mặc định (Claude/Gemini theo vai trò, reviewer khác hãng, ngân sách 5 USD/ngày, online); chỉ hỏi khi người ra lệnh đổi ('dùng Gemini cho tất cả', 'ngân sách 2 USD')", "câu lệnh (tùy chọn)", "models.yaml", ""),
    ("K", "Kiểm quy tắc different_vendor_from(coder); kiểm khóa API theo biến môi trường; kiểm mô hình cục bộ (Ollama)", "models.yaml", "cảnh báo", ""),
    ("K", "Chạy bộ kiểm thử hợp đồng 5 ca trên các adapter khả dụng (không tốn nhiều token)", "", "báo cáo", ""),
    ("K", "Lưu; ghi ledger; cập nhật thanh trạng thái (offline/online, chi phí)", "", "", "")],
   [("A1", "offline_mode nhưng không có mô hình cục bộ", "Từ chối bật; đề nghị cài Ollama + qwen2.5-coder"),
    ("A2", "Chỉ có một nhà cung cấp", "Cho phép nhưng ghi cảnh báo 'reviewer cùng hãng' vào ledger và thanh trạng thái")])

uc("UC-A05", "Nhập dự án mã nguồn có sẵn", "A. Dự án & môi trường", "Kỹ sư", "Librarian, Coder",
   "EIDE hiểu repo hiện có: quy ước, cấu trúc, lệnh build, các hằng số phần cứng đang dùng",
   "Kỹ sư mở một repo có sẵn", "Repo có mã C/C++/Rust", "CONVENTIONS.md; CodeUnit với USES/CITES sơ bộ; danh sách hằng số chưa có nguồn",
   "—", "K6 quy ước; đồ thị USES", "S", "M2", "FR-PSP-05, FR-AGT-03", "UR-MA-04, UR-QT-04", "Mã nguồn",
   [("T", "Librarian khảo sát repo: build system, thư mục, định dạng mã, README", "repo", "CONVENTIONS.md (đề xuất)", ""),
    ("K", "Phân tích tĩnh: tìm địa chỉ/bit hằng số; ánh xạ vào hộ chiếu nếu có → CodeUnit CITES/USES", "mã", "đồ thị", ""),
    ("T", "Báo cáo: N hằng số khớp hộ chiếu, M hằng số không nguồn (đề xuất mở UC-B07)", "", "báo cáo", ""),
    ("N", "Xác nhận CONVENTIONS.md; quyết định có bổ sung hkw:fact vào mã cũ dần hay không", "", "", "")],
   [("A1", "Repo dùng hệ sinh thái chưa có Pack (ví dụ PIC)", "Tạo Pack khung 'custom' và chỉ bật kiểm tĩnh + build qua lệnh do người khai báo")])

uc("UC-A06", "Tiếp tục phiên làm việc", "A. Dự án & môi trường", "Kỹ sư", "Knowledge Plane",
   "Sau khi tắt máy/crash, mở lại dự án đúng trạng thái và biết việc tiếp theo",
   "Mở dự án", ".hkw/ tồn tại", "Trạng thái máy trạng thái, gate đang mở, FEATURES/PROGRESS được hiển thị; build known-good chạy lại", "—", "K7 (đọc)", "M", "M2", "FR-GOV-03, NFR-04", "UR-QT-03", "Tổng quan",
   [("K", "Kiểm hash store (phát hiện ghi ngoài cổng); nạp đồ thị từ cache hoặc tái dựng", "", "", ""),
    ("K", "Đọc PROGRESS.md, FEATURES.json, gate đang mở, quyền đã hết hạn", "", "tóm tắt", ""),
    ("H", "Chạy build known-good để xác nhận môi trường còn đúng", "", "ToolReport", ""),
    ("T", "Librarian tóm tắt 'lần trước dừng ở đâu, việc tiếp theo là gì'", "", "", "")],
   [("A1", "Hash store lệch", "Từ chối mở ở chế độ ghi; đề nghị tái dựng đồ thị và kiểm toán ledger"),
    ("A2", "Toolchain đổi so với tools.lock", "Chuyển sang UC-A03")])

# ---------------------------------------------------------------- B. Nhận tri thức
uc("UC-B01", "Nhập gói tài liệu hỗn hợp (zip có mạch, ảnh, PDF, tệp linh tinh)", "B. Nhận tri thức", "Kỹ sư", "Librarian, Knowledge Plane",
   "Mọi tệp trong gói được mở, phân loại theo nội dung, xếp đường đi theo tầng tin cậy; không tệp nào bị 'bịa' thành tri thức",
   "Kỹ sư kéo thả zip/thư mục vào EIDE hoặc eide ingest", "Dự án đã tạo", "Bảng phân loại; hàng đợi trích xuất; các AcquisitionRequest cho tệp cần duyệt",
   "G-SRC (ngầm định: tệp do người đưa vào = đã chọn nguồn); G-FACT cho tầng bạc", "Source (hash, kind, tier) cho từng tệp", "M", "M1", "FR-ACQ-01, FR-ACQ-05", "UR-TT-01", "Nhập tài liệu",
   [("N", "Đưa tài liệu: kéo thả zip/thư mục, hoặc nêu đường dẫn trong câu lệnh ('tài liệu ở ~/robot-kit')", "zip", "", "Lệnh"),
    ("K", "Mở nén đệ quy trong sandbox (≤ 5 cấp, ≤ 2 GB, chống zip-slip); tính sha256 từng tệp", "zip", "danh sách tệp", ""),
    ("K", "Phân loại theo chữ ký nội dung: SVD/ATDF/EDC/header/kicad → vàng; PDF/DOCX/HTML/ảnh → bạc; văn bản tự do/diễn đàn → đồng; khác → bỏ qua", "tệp", "bảng phân loại", ""),
    ("T", "Librarian tóm tắt: tệp nào sinh hộ chiếu ngay, tệp nào cần trích xuất + duyệt, tệp nào chỉ làm ngữ cảnh; phát hiện chip/board từ tên và nội dung", "bảng", "tóm tắt + đề xuất", ""),
    ("K", "Tệp vàng: chạy parser ngay → hộ chiếu (UC-B03/UC-B06). Tệp bạc: tạo AcquisitionRequest CONFIRMED → chờ trích xuất (UC-B04/B05)", "", "", ""),
    ("T", "Tự trích xuất mọi tệp bạc ngay (A3); người chỉ xem bảng và có thể loại tệp sau", "", "", ""),
    ("K", "Ghi ledger; cập nhật hàng đợi xác nhận", "", "", "")],
   [("A1", "Zip chứa zip lồng quá 5 cấp hoặc > 2 GB", "Dừng ở giới hạn, liệt kê phần chưa mở, hỏi người"),
    ("A2", "Tệp nén có mật khẩu", "Hỏi mật khẩu; không thử đoán"),
    ("A3", "Tệp đã có trong store (trùng hash)", "Bỏ qua và ghi 'trùng'; không tạo fact mới"),
    ("A4", "Không tệp nào sinh được hộ chiếu (toàn ảnh và văn bản)", "Librarian đề xuất tìm SVD/datasheet trên mạng (UC-B07/B08)")])

uc("UC-B02", "Suy ra chip / linh kiện từ tài liệu và ảnh", "B. Nhận tri thức", "Librarian", "Cartographer, Kỹ sư",
   "Từ tên tệp, nội dung PDF, ảnh board/schematic, xác định MCU và các linh kiện chính để biết cần hộ chiếu nào",
   "Sau UC-B01 khi dự án chưa khai báo chip, hoặc gói có linh kiện mới", "Bảng phân loại", "Danh sách 'chip/linh kiện phát hiện' với mức tin cậy; người xác nhận; tạo yêu cầu hộ chiếu cho từng cái",
   "G-FACT", "Đề xuất K2/K4 (đồng → chờ)", "M", "M1", "FR-ACQ-04, FR-BRD-02", "UR-MC-02, UR-TT-02", "Nhập tài liệu / Hàng đợi xác nhận",
   [("T", "Đọc tiêu đề PDF, mã đặt hàng, chuỗi 'STM32F411', 'BME280'; đọc nhãn linh kiện trên ảnh bằng mô hình thị giác", "tệp", "ứng viên linh kiện", ""),
    ("K", "Đối chiếu với hộ chiếu có sẵn / registry", "", "có/chưa có", ""),
    ("T", "Trình bảng: linh kiện, vai trò dự đoán (MCU, cảm biến, driver), nguồn suy ra, tin cậy", "", "bảng", ""),
    ("N", "Xác nhận/sửa từng dòng (ví dụ: 'U3 là MPU6050 chứ không phải MPU9250')", "", "", "G-FACT"),
    ("K", "Tạo AcquisitionRequest cho hộ chiếu còn thiếu (UC-B07)", "", "", "")],
   [("A1", "Ảnh mờ, không đọc được nhãn", "Yêu cầu ảnh rõ hơn hoặc nhập tay mã linh kiện")])

uc("UC-B03", "Nhập nguồn cấu trúc chính hãng (SVD / ATDF / EDC / header)", "B. Nhận tri thức", "Knowledge Plane", "Kỹ sư",
   "Bản đồ thanh ghi tầng vàng vào Passport Store bằng parser xác định, không cần duyệt từng fact",
   "Tệp vàng trong UC-B01; pull registry; khai báo chip", "Tệp hợp lệ", "ChipPassport <ns.part@ver> với fact reviewed; ledger; nếu đã có phiên bản khác → báo diff",
   "G-SRC (chọn phiên bản) khi có nhiều bản", "K2 lõi", "M", "M0", "FR-ACQ-02, FR-PSP-01, FR-PSP-02", "UR-TT-02, UR-TT-03", "Hộ chiếu chip",
   [("K", "Sniff nội dung; chọn parser (SVD: derivedFrom, dim, cluster, enum; ATDF: module/instance/bitfield/value-group)", "tệp", "facts[]", ""),
    ("K", "Ghi qua cổng ghi duy nhất: hợp nhất theo tier; predicate nhiều giá trị (irq, enum) không gây mâu thuẫn", "facts", "WriteResult", ""),
    ("K", "Nếu tệp từ thư mục *-Community hoặc không rõ nguồn hãng → tầng bạc", "", "", ""),
    ("T", "Librarian báo: số ngoại vi/thanh ghi/bit-field, cảnh báo parser, mâu thuẫn với nguồn khác", "", "báo cáo", ""),
    ("N", "Nếu có mâu thuẫn hoặc phiên bản mới: quyết định ghim phiên bản (UC-B13)", "", "", "")],
   [("A1", "SVD lỗi cú pháp", "Báo dòng lỗi; đề nghị tìm bản khác (UC-B08)"),
    ("A2", "Chip đã có hộ chiếu cùng phiên bản, hash khác", "Nhập thành nguồn thứ hai; mâu thuẫn được liệt kê cho UC-B11")])

uc("UC-B04", "Trích xuất tri thức từ PDF (datasheet, reference manual, errata)", "B. Nhận tri thức", "Librarian", "Kỹ sư",
   "Bảng thanh ghi, thông số điện, timing, errata trở thành fact tầng bạc có trang/bbox/ảnh cắt, chờ duyệt",
   "Tệp PDF trong hàng đợi CONFIRMED", "PDF trích được văn bản (không phải ảnh scan) hoặc có OCR", "Fact NORMALIZED theo nhóm; ảnh cắt trong cache; AcquisitionRequest → EXTRACTED",
   "G-FACT (sau đó)", "K2′ (chip) hoặc K4 (ngoại vi ngoài)", "M", "M1", "FR-ACQ-03, FR-ACQ-07", "UR-TT-01, UR-TT-05", "Hàng đợi xác nhận",
   [("K", "Docling/pdfplumber: bố cục, bảng, tiêu đề; nhận diện chương 'Register map', 'Electrical characteristics', 'Errata'", "PDF", "bảng + bbox", ""),
    ("T", "Librarian dùng mô hình có schema chuyển từng bảng thành fact {subject, predicate, value, unit, confidence}; giữ trang/bbox", "bảng", "facts", ""),
    ("K", "Hợp nhất trùng lặp; phát hiện mâu thuẫn với nguồn khác; xếp nhóm (thanh ghi, chân, điện, errata)", "facts", "nhóm", ""),
    ("K", "Cắt ảnh vùng bảng làm bằng chứng; đưa vào hàng đợi G-FACT", "", "ảnh cắt", ""),
    ("N", "Duyệt theo nhóm (UC-B10)", "", "", "G-FACT")],
   [("A1", "PDF scan (ảnh)", "OCR rồi trích; confidence giảm 0,1; bắt buộc duyệt từng dòng thay vì theo nhóm"),
    ("A2", "Bảng trải nhiều trang / cột gộp", "Ghép bảng theo tiêu đề lặp; nếu không chắc → đánh dấu 'cần xem' cho người"),
    ("A3", "PDF là bản dịch/không chính hãng", "Tầng đồng; chỉ dùng làm gợi ý tìm bản gốc")])

uc("UC-B05", "Trích xuất từ ảnh (schematic chụp, ảnh board, ảnh màn hình đo)", "B. Nhận tri thức", "Cartographer", "Kỹ sư",
   "Ảnh trở thành đề xuất có cấu trúc (net, linh kiện, giá trị) để người xác nhận",
   "Ảnh trong hàng đợi", "Mô hình thị giác khả dụng (đám mây hoặc cục bộ)", "Đề xuất tầng bạc/đồng chờ duyệt; không bao giờ tự thành fact", "G-FACT", "K3 (mạch) đề xuất", "S", "M2", "FR-ACQ-04, FR-BRD-02", "UR-MC-02", "Hàng đợi xác nhận",
   [("T", "Gửi ảnh + schema 'nets[], parts[]' cho mô hình thị giác; nhận bảng đề xuất", "ảnh", "bảng", ""),
    ("K", "Đối chiếu với BoardPassport (nếu có) và hộ chiếu chip (tên chân hợp lệ?)", "", "cảnh báo", ""),
    ("T", "Trình bảng với ảnh cắt từng vùng; đánh dấu dòng tin cậy thấp", "", "", ""),
    ("N", "Sửa/duyệt", "", "", "G-FACT")],
   [("A1", "Mô hình cục bộ không có thị giác", "Báo không thể; đề nghị bật mô hình đám mây cho vai trò cartographer (tài liệu sẽ rời máy — cần xác nhận) hoặc nhập tay")])

uc("UC-B06", "Nhập schematic KiCad và dựng hộ chiếu mạch", "B. Nhận tri thức", "Cartographer", "Kỹ sư",
   "BoardPassport có net, chân, linh kiện, bus, địa chỉ suy ra; ràng buộc điện; xung đột được phát hiện",
   ".kicad_sch trong gói", "kicad-cli có trên máy (UC-A03)", "BoardPassport NORMALIZED chờ duyệt; kg.conflicts chạy; constraints cho Coder",
   "G-FACT", "K3", "M", "M2", "FR-BRD-01, FR-BRD-03, FR-BRD-04", "UR-MC-01, UR-MC-03, UR-MC-04", "Hộ chiếu mạch",
   [("H", "kicad-cli sch export netlist", ".kicad_sch", "netlist XML", ""),
    ("K", "Ánh xạ ref → MPN → hộ chiếu (U1 = st.stm32f411; U2 = bosch.bme280); pin → tên chân MCU", "netlist", "nets/pins/parts", ""),
    ("T", "Cartographer suy ra bus và địa chỉ (SDO→GND ⇒ 0x76), pull-up, chân reserved/boot; chức năng AF khả dĩ", "", "facts K3", ""),
    ("K", "kg.conflicts: chân hai chức năng, reserved bị dùng, trùng địa chỉ bus", "", "cảnh báo", ""),
    ("N", "Duyệt BoardPassport; chọn cách giải quyết xung đột", "", "", "G-FACT")],
   [("A1", "Linh kiện không có hộ chiếu", "Tạo AcquisitionRequest (UC-B07) cho MPN đó; net vẫn được lưu"),
    ("A2", "Schematic Altium/Eagle", "Đề nghị xuất netlist chuẩn (KiCad/Protel) hoặc dùng ảnh (UC-B05)")])

uc("UC-B07", "Phát hiện thiếu tri thức và tạo yêu cầu nhận tri thức", "B. Nhận tri thức", "Librarian / Planner", "Knowledge Plane",
   "Mọi 'thiếu' đều thành một yêu cầu có thể theo dõi, thay vì tác tử đoán",
   "passport.query không khớp; Planner tự đánh giá thiếu; constant-guard chặn; UC-B02 phát hiện linh kiện mới; người tạo tay",
   "—", "AcquisitionRequest REQUESTED với need/part/peripheral; xuất hiện trong hàng đợi", "—", "Yêu cầu (K6)", "M", "M1", "FR-ACQ-05", "UR-TT-04, UR-TT-02", "Hàng đợi xác nhận / Trò chuyện",
   [("T", "Tác tử mô tả cần gì và vì sao (ví dụ 'công thức bù nhiệt BME280 tr.25 để viết bước 5')", "", "need", ""),
    ("K", "Tạo yêu cầu; liên kết với Feature/STEP đang làm", "", "request", ""),
    ("T", "Thông báo trong chat và hàng đợi; đề nghị tìm (UC-B08) hoặc người cung cấp tệp", "", "", ""),
    ("N", "Chọn: tìm tự động / tôi có tệp / bỏ qua (ghi lý do)", "", "", "")],
   [("A1", "Yêu cầu trùng với yêu cầu đang mở", "Gộp; tăng mức ưu tiên")])

uc("UC-B08", "Tìm nguồn tri thức (registry → kho hãng → docs MCP → web)", "B. Nhận tri thức", "Librarian", "Nguồn ngoài, Kỹ sư",
   "Đưa ra danh sách ứng viên nguồn có đủ thông tin để người quyết định, KHÔNG tải và KHÔNG trích xuất trước khi được chọn",
   "Yêu cầu ở REQUESTED và người chọn 'tìm tự động'", "Chế độ online (hoặc registry nội bộ trong offline)", "Yêu cầu → CANDIDATES với ứng viên {uri, kind, size, license?, hash?, ngày}",
   "G-SRC (bước tiếp)", "Candidate (chưa phải fact)", "M", "M1", "FR-ACQ-06, FR-ACQ-09", "UR-TT-04", "Hàng đợi xác nhận",
   [("T", "Tìm registry nội bộ theo part/MPN", "", "ứng viên", ""),
    ("T", "Tìm kho hãng theo mẫu URL đã biết (CMSIS pack, Microchip pack, Bosch, ST) và docs MCP (Espressif/Nordic)", "", "ứng viên", ""),
    ("T", "Tìm web (chỉ khi cho phép): ưu tiên tên miền hãng; lấy kích thước, ngày, license nếu đọc được; hash nếu HEAD/tải nhỏ", "", "ứng viên", ""),
    ("K", "Xếp hạng theo tầng dự kiến (vàng > bạc > đồng) và tên miền; loại trùng", "", "danh sách", ""),
    ("T", "Trình bày cho người kèm lý do chọn từng ứng viên (UC-B09)", "", "", "")],
   [("A1", "offline_mode", "Chỉ registry và kho cục bộ; báo 'không tìm web vì chế độ cục bộ'"),
    ("A2", "Không có ứng viên", "Giữ REQUESTED; gợi ý người cung cấp tệp"),
    ("A3", "Ứng viên quá lớn (> ngưỡng)", "Đánh dấu; chỉ tải khi người xác nhận riêng (G-OPS)")])

uc("UC-B09", "Xác nhận nguồn (G-SRC): xem thông tin, chọn, tải", "B. Nhận tri thức", "Người phê duyệt", "Librarian, Knowledge Plane",
   "Chỉ nguồn được người chọn mới được tải và trích xuất; quyết định có nhật ký",
   "Yêu cầu ở CANDIDATES", "Danh sách ứng viên", "Yêu cầu → CONFIRMED; tệp tải về cache với hash; Source được tạo; ledger ghi ai/khi/lý do",
   "G-SRC", "Source", "M", "M1", "FR-ACQ-05, FR-ACQ-06", "UR-TT-04", "Hàng đợi xác nhận",
   [("N", "Mở mục G-SRC; xem từng ứng viên: nguồn, tên miền, ngày, kích thước, license, tầng dự kiến, lý do của Librarian", "", "", ""),
    ("N", "Chọn một hoặc nhiều; loại; hoặc 'tôi tự đưa tệp'", "", "quyết định", "G-SRC"),
    ("K", "Tải (trong sandbox, giới hạn dung lượng); tính sha256; kiểm khớp hash nếu ứng viên có hash", "", "tệp", ""),
    ("K", "Tạo Source {uri, sha256, kind, tier, license}; yêu cầu → CONFIRMED; xếp hàng trích xuất", "", "", ""),
    ("T", "Librarian tóm tắt nội dung nguồn đã tải (mục lục, số trang, có bảng thanh ghi?) để người biết đã đúng tài liệu chưa", "", "tóm tắt", ""),
    ("N", "Xác nhận 'đúng tài liệu' → trích xuất; hoặc 'sai' → REJECTED và tìm lại", "", "", "")],
   [("A1", "Tải thất bại / hash lệch", "Báo; không tạo Source; quay về CANDIDATES"),
    ("A2", "License cấm phân phối lại", "Vẫn dùng cục bộ; gói .hkp sau này chỉ chứa con trỏ + hash")])

uc("UC-B10", "Duyệt fact (G-FACT) theo nhóm với ảnh cắt", "B. Nhận tri thức", "Người phê duyệt", "Knowledge Plane",
   "Fact tầng bạc được người kiểm với bằng chứng trực quan, theo nhóm để nhanh, vào đồ thị tri thức của dự án",
   "Yêu cầu ở NORMALIZED", "Fact có locator/ảnh cắt", "Fact → reviewed (confirmed_by/at); yêu cầu → REVIEWED; đồ thị cập nhật; kg.impact nếu thay fact cũ",
   "G-FACT", "K2′/K3/K4 reviewed", "M", "M1", "FR-ACQ-08, FR-PSP-05", "UR-TT-05, UR-TT-06", "Hàng đợi xác nhận",
   [("N", "Mở nhóm (thanh ghi / chân / điện / errata); xem bảng fact + ảnh cắt trang tương ứng", "", "", ""),
    ("N", "Chấp nhận cả nhóm, hoặc bỏ chọn/sửa từng fact (sửa = fact mới supersedes)", "", "", "G-FACT"),
    ("K", "Ghi status reviewed, confirmed_by; cập nhật đồ thị; chạy kg.impact cho fact bị thay", "", "", ""),
    ("K", "Fact bị loại → REJECTED kèm ghi chú; extractor có thể chạy lại với gợi ý", "", "", ""),
    ("T", "Librarian báo tổng kết và bước tiếp (kiểm định trên board UC-B12 nếu có board)", "", "", "")],
   [("A1", "Nhóm có mâu thuẫn với nguồn khác", "Hiển thị cặp giá trị; người chọn (UC-B11)"),
    ("A2", "Người sửa giá trị tay", "Tạo fact method=manual, source = 'manual by <user>', tier bạc")])

uc("UC-B11", "Giải quyết mâu thuẫn giữa các nguồn", "B. Nhận tri thức", "Người phê duyệt", "Librarian",
   "Không tồn tại hai giá trị 'hiện hành' cho cùng subject/predicate mà không ai quyết",
   "conflict table có mục chưa giải quyết", "Hai fact cùng tier khác giá trị", "Một fact hiện hành, fact kia superseded hoặc cả hai 'đúng theo điều kiện' (ghi chú); ledger",
   "G-FACT", "Quyết định + lý do", "M", "M1", "FR-ACQ-07", "UR-TT-03", "Hàng đợi xác nhận / Hộ chiếu chip",
   [("K", "Liệt kê cặp mâu thuẫn: giá trị, nguồn, tier, ngày, ảnh cắt", "", "", ""),
    ("T", "Librarian phân tích: khác phiên bản tài liệu? lỗi trích xuất? khác biến thể chip?", "", "nhận định", ""),
    ("N", "Chọn: giữ A / giữ B / cả hai theo điều kiện (ví dụ theo revision) / kiểm định trên board", "", "", "G-FACT"),
    ("K", "Áp dụng: supersedes hoặc thêm điều kiện; đóng conflict; kg.impact", "", "", "")],
   [("A1", "Mâu thuẫn giữa SVD chính hãng và SVD cộng đồng", "Mặc định ưu tiên chính hãng; cộng đồng xuống tầng bạc; vẫn cần người xác nhận nếu mã đang trích dẫn")])

uc("UC-B12", "Kiểm định hộ chiếu trên board thật", "B. Nhận tri thức", "Tester", "Kỹ sư, Tool Layer",
   "Bằng chứng vật lý rằng hộ chiếu đúng với chip/mạch trước mặt; gắn huy hiệu",
   "Người bấm 'Kiểm định trên board'; sau UC-B10; trước phát hành", "Board nối máy (probe hoặc bootloader/serial); toolchain đã khóa",
   "Badge verified_on_board {board, date, by, log hash}; fact liên quan → verified", "G-OPS (nạp)", "K7 (Measurement), badge", "M", "M1", "FR-BEN-02, FR-VER-02", "UR-TT-06", "Hộ chiếu chip / Gỡ lỗi probe",
   [("T", "Tester sinh firmware kiểm định từ hộ chiếu: đọc ID chip (DBGMCU_IDCODE / signature), toggle GPIO có LED theo BoardPassport, UART echo", "hộ chiếu", "firmware", ""),
    ("H", "Build (4 cổng)", "", "ToolReport", ""),
    ("N", "Cấp quyền nạp", "", "", "G-OPS"),
    ("H", "Nạp; đọc serial/RTT; probe đọc thanh ghi ID nếu có", "", "log", ""),
    ("K", "So sánh với hộ chiếu; gắn badge; fact khớp → verified; fact sai → conflict + DebugSession", "", "badge", ""),
    ("N", "Xác nhận quan sát (LED nháy) nếu kịch bản có", "", "", "G4")],
   [("A1", "AVR/PIC không có probe", "Chỉ kiểm bằng firmware + serial (signature bytes qua bootloader nếu có)"),
    ("A2", "ID không khớp", "Không hạ tier; mở DebugSession; đề xuất: sai chip? sai hộ chiếu? kết nối?")])

uc("UC-B13", "Cập nhật phiên bản tri thức (SVD/datasheet mới) và phân tích ảnh hưởng", "B. Nhận tri thức", "Kỹ sư", "Knowledge Plane, Librarian",
   "Nâng phiên bản lõi/overlay có kiểm soát: biết fact nào đổi, mã nào bị ảnh hưởng, tính năng nào phải kiểm lại",
   "Registry/hãng có phiên bản mới; người nhập tệp mới", "Hộ chiếu phiên bản cũ đang ghim", "Hộ chiếu phiên bản mới nhập; báo cáo diff; quyết định ghim; backlog kiểm lại",
   "G1 (quyết định nâng)", "K2 phiên bản mới; stale list", "M", "M2", "FR-PSP-02, FR-PSP-05", "UR-TT-08", "Hộ chiếu chip",
   [("K", "Nhập phiên bản mới thành hộ chiếu riêng (không đụng bản ghim)", "", "", ""),
    ("K", "Diff: fact thêm/bớt/đổi; kg.impact cho fact đổi → CodeUnit stale, Feature cần tái kiểm", "", "báo cáo", ""),
    ("T", "Librarian tóm tắt rủi ro: 'CR1.SWRST đổi mô tả; 2 module trích dẫn'", "", "", ""),
    ("N", "Quyết định nâng ghim hay giữ", "", "", "G1"),
    ("K", "Nếu nâng: cập nhật constraints.yaml pins; đưa Feature bị ảnh hưởng về failing để chạy lại P4", "", "", "")],
   [("A1", "Phiên bản mới thiếu ngoại vi bản cũ có", "Cảnh báo mạnh; đề nghị giữ hoặc dùng overlay")])

uc("UC-B14", "Hỏi đáp tra cứu hộ chiếu (ngôn ngữ tự nhiên có trích dẫn)", "B. Nhận tri thức", "Kỹ sư", "Librarian, Knowledge Plane",
   "Trả lời câu hỏi về thanh ghi/chân/timing/điện kèm nguồn, tầng, trạng thái; nói 'không có' khi không có",
   "Người gõ câu hỏi ở thanh tìm hoặc chat", "Hộ chiếu tồn tại", "Câu trả lời + fact id + nguồn; nếu thiếu → UC-B07", "—", "—", "M", "M0", "FR-PSP-04, FR-PSP-06", "UR-TT-07", "Mọi màn hình (thanh tìm) / Trò chuyện",
   [("T", "Hiểu câu hỏi → subject/predicate dự kiến (ví dụ 'tốc độ I2C1' → I2C1/CCR)", "câu hỏi", "truy vấn", ""),
    ("K", "passport.query + kg.neighborhood; Graph-RAG lấy fact liên quan", "", "facts", ""),
    ("T", "Soạn câu trả lời ngắn có trích dẫn [fact id · nguồn · trang]; nêu tầng và trạng thái (chưa duyệt → cảnh báo)", "", "", ""),
    ("K", "Ghi ledger; nếu người bấm 'đúng/sai' → phản hồi vào K7", "", "", "")],
   [("A1", "Không có fact", "Trả lời 'không có trong hộ chiếu' và đề nghị UC-B07; không suy đoán giá trị")])

# ---------------------------------------------------------------- C. Mạch (bổ sung ngoài B06)
uc("UC-C01", "Kiểm xung đột tài nguyên trước khi sinh mã", "C. Mạch & tài nguyên", "Knowledge Plane", "Planner, Kỹ sư",
   "Không có hai module dùng một chân/ngoại vi trái nhau; chân reserved không bị dùng",
   "Trước G1 và trước G3; khi BoardPassport thay đổi", "BoardPassport + đồ thị USES", "Danh sách xung đột với gợi ý; chặn G1/G3 nếu xung đột chưa giải quyết", "G1", "Cảnh báo", "M", "M2", "FR-BRD-03, FR-PSP-05", "UR-MC-03", "Hộ chiếu mạch / Kế hoạch",
   [("K", "Tập tài nguyên kế hoạch sẽ dùng ∩ tập đã USES; chân reserved/boot", "", "xung đột", ""),
    ("T", "Cartographer đề xuất phương án (remap AF, đổi chân, đổi ngoại vi)", "", "", ""),
    ("N", "Chọn phương án hoặc 'bỏ qua có lý do'", "", "", "G1"),
    ("K", "Ghi quyết định vào K6 (constraints) và ledger", "", "", "")])

# ---------------------------------------------------------------- D. Kế hoạch & mã
uc("UC-D01", "Mô tả tính năng và tạo STEP", "D. Kế hoạch & sinh mã", "Kỹ sư", "Planner",
   "Ý định của người được ghi thành STEP.md/FEATURES.json để tác tử làm việc từng bước nhỏ",
   "Người mô tả trong chat hoặc bấm '+ Tính năng mới'", "Dự án có hộ chiếu chip (ít nhất lõi)", "Feature failing + STEP.md; ARCHITECTURE/PLAN cập nhật nếu cần", "—", "K6", "M", "M2", "FR-GOV-03", "UR-SM-05 (EAA-URD)", "Trò chuyện / Tổng quan",
   [("N", "Ra lệnh: 'viết firmware đọc nhiệt độ BME280 qua I2C1, phát UART2 mỗi 500 ms, không float trong ISR' (hoặc lệnh lớn: 'làm toàn bộ firmware cho board này theo tài liệu')", "", "", "Lệnh"),
    ("T", "Planner chuẩn hóa thành Feature (tiêu đề, kỳ vọng quan sát được, ràng buộc) và hỏi lại điểm mơ hồ (tối đa 3 câu)", "", "Feature", ""),
    ("K", "Ghi FEATURES.json (failing) và STEP.md", "", "", "")])

uc("UC-D02", "Lập kế hoạch có trích dẫn và duyệt G1", "D. Kế hoạch & sinh mã", "Planner", "Người phê duyệt, Knowledge Plane",
   "Kế hoạch từng bước, mỗi bước có fact id; thiếu tri thức được phát hiện trước khi viết mã",
   "Feature failing được chọn", "Hộ chiếu chip+mạch; skill Pack", "Plan approved; Feature con; hoặc AcquisitionRequest nếu thiếu", "G1", "K6 (kế hoạch)", "M", "M2", "FR-AGT-01, FR-AGT-02, FR-PSP-06", "UR-MA-03", "Kế hoạch & mã",
   [("K", "Composer: ràng buộc + skill (≤3) + fact Graph-RAG 2 bước + STEP", "", "ngữ cảnh ≤ 8k", ""),
    ("T", "Planner sinh Plan{steps[], citations[], missing[]}", "", "Plan", ""),
    ("K", "Validator: schema + fact id tồn tại + UC-C01 xung đột", "", "verdict", ""),
    ("T", "Nếu missing → UC-B07; nếu ok → trình G1 với trích dẫn và cảnh báo", "", "", ""),
    ("N", "Duyệt/sửa thứ tự/ràng buộc", "", "", "G1"),
    ("K", "Tách Feature con; ledger", "", "", "")],
   [("A1", "Validator thất bại 2 lần", "Bàn giao người kèm lý do; không tự lặp thêm")])

uc("UC-D03", "Sinh mã với hằng số có nguồn (constant-guard)", "D. Kế hoạch & sinh mã", "Coder", "Knowledge Plane, Tool Layer",
   "CodePatch mà mọi hằng số phần cứng trỏ fact id hợp lệ, qua 4 cổng công cụ, tự sửa ≤ 3 vòng",
   "Bước kế hoạch được chọn", "G1 approved", "CodePatch + 4 ToolReport đạt → chờ Reviewer; hoặc bàn giao người", "—", "CodeUnit CITES/USES", "M", "M2", "FR-AGT-03, FR-VER-01, FR-LLM-03", "UR-MA-02, UR-MA-04", "Mã nguồn",
   [("T", "Coder sinh mã theo skill + fact; chú thích /* hkw:fact f_… */ cạnh mỗi hằng số", "", "CodePatch", ""),
    ("K", "Hook pre_write: constant-guard quét hằng số; quy ước repo; thư mục cho phép", "", "chấp nhận/chặn", ""),
    ("H", "build → size → static → host-test", "", "ToolReport ×4", ""),
    ("T", "Nếu lỗi: sửa theo ToolReport (≤ 3 vòng)", "", "", ""),
    ("K", "Đăng ký CodeUnit với cites/uses; ledger", "", "", "")],
   [("A1", "Constant-guard chặn hằng số không nguồn", "Tạo AcquisitionRequest (UC-B07) và tạm dừng bước; không được 'bịa' fact"),
    ("A2", "Quá 3 vòng", "Bàn giao người kèm toàn bộ log; Feature giữ failing"),
    ("A3", "Ngân sách token/ngày vượt", "Dừng; mở gate hỏi tăng ngân sách (UC-H03)")])

uc("UC-D04", "Review khác hãng và duyệt merge (G3)", "D. Kế hoạch & sinh mã", "Người phê duyệt", "Reviewer, Knowledge Plane",
   "Mã chỉ vào nhánh chính khi có ý kiến độc lập và người duyệt với đầy đủ bằng chứng",
   "CodePatch qua 4 cổng", "Reviewer cấu hình khác hãng", "Merge với commit có fact ids/model/prompt hash; hoặc reject → sổ lỗi", "G3", "K7 (lý do reject)", "M", "M2", "FR-AGT-06, FR-AGT-07", "UR-MA-03", "Kế hoạch & mã",
   [("T", "Reviewer chấm theo checklist Pack (ISR, volatile, timeout, kích thước); không sửa mã", "", "Review", ""),
    ("K", "Trình G3: diff, rationale, citations, 4 ToolReport, Review", "", "", ""),
    ("N", "Duyệt & merge / từ chối kèm lý do", "", "", "G3"),
    ("K", "Merge; commit; cập nhật đồ thị; hoặc ghi sổ lỗi và đưa lý do vào prompt phủ định cho vòng sau", "", "", "")],
   [("A1", "Chỉ có một hãng", "Vẫn review nhưng nhãn 'cùng hãng' hiển thị ở G3")])

uc("UC-D05", "Kỹ sư sửa mã tay và đối chiếu hộ chiếu", "D. Kế hoạch & sinh mã", "Kỹ sư", "Knowledge Plane",
   "Mã do người viết cũng được kiểm hằng số và giữ truy vết",
   "Lưu tệp trong trình soạn thảo", "—", "Cảnh báo hằng số không nguồn; gợi ý fact; CodeUnit cập nhật", "—", "USES/CITES", "S", "M3", "FR-AGT-03, FR-UI-05", "UR-QS-04", "Mã nguồn",
   [("K", "Khi lưu: quét hằng số; hover địa chỉ → giải nghĩa theo hộ chiếu", "", "", ""),
    ("T", "Gợi ý fact id cho hằng số (một cú bấm để chèn chú thích)", "", "", ""),
    ("N", "Chấp nhận/bỏ qua", "", "", "")])

uc("UC-D06", "Hoàn tác về phiên bản known-good", "D. Kế hoạch & sinh mã", "Kỹ sư", "Knowledge Plane, Tool Layer",
   "Một lệnh đưa dự án về trạng thái đã chứng minh chạy trên board", "Người bấm rollback", "Có tag known-good", "Mã và FEATURES về tag; build đạt; ledger", "—", "—", "M", "M2", "FR-GOV-02", "UR-QT-02", "Tổng quan",
   [("N", "Chọn known-good (danh sách có ngày, Feature passing)", "", "", ""),
    ("K", "Checkout tag; đặt Feature sau tag về failing", "", "", ""),
    ("H", "Build để xác nhận", "", "ToolReport", "")])

# ---------------------------------------------------------------- E. Mô phỏng
uc("UC-E01", "Tác tử dựng môi trường mô phỏng cho chip/mạch (SIL)", "E. Mô phỏng", "Tester", "Kỹ sư, Tool Layer, Knowledge Plane",
   "Có một nền tảng mô phỏng (Renode .repl / simavr / mô phỏng tự xây) khớp hộ chiếu chip và mạch để chạy firmware thật trước khi có board",
   "Sau khi có hộ chiếu chip (+ mạch); người bấm 'Tạo mô phỏng' hoặc Planner cần cổng SIL", "ISA profile có sim manifest; toolchain mô phỏng đã cài (UC-A03)",
   "Thư mục sim/ với mô tả nền tảng, mock ngoại vi, kịch bản khói; ToolReport sim đạt cho firmware 'hello'", "G-FACT cho tham số mô hình suy ra; G-OPS cho cài Renode/QEMU", "K5 (mô hình mô phỏng như skill của dự án), K7", "M", "M3", "FR-VER-04", "UR-XM-03", "Mô phỏng",
   [("T", "Tester đọc hộ chiếu: CPU, bộ nhớ, ngoại vi có địa chỉ; chọn nền: Renode (Cortex-M/RISC-V), simavr (AVR), hoặc tự xây khi không có", "hộ chiếu", "lựa chọn", ""),
    ("T", "Sinh mô tả nền tảng (.repl) từ fact: bộ nhớ, ngoại vi chuẩn (UART, GPIO, I2C, TIM) với địa chỉ/IRQ; đánh dấu ngoại vi chưa có mô hình", "fact", ".repl", ""),
    ("T", "Từ BoardPassport: nối ngoại vi ngoài bằng mock (BME280 mock trả id 0x60, dữ liệu theo công thức), LED trên PB3, UART2 ra console", "K3", "mock", ""),
    ("H", "Chạy firmware 'hello' (UART in chuỗi + LED) trên mô phỏng", "", "ToolReport", ""),
    ("T", "Nếu thiếu mô hình ngoại vi quan trọng: đề xuất viết mock đơn giản (hành vi theo datasheet) → cần người duyệt tham số (G-FACT)", "", "", "G-FACT"),
    ("K", "Lưu sim/ vào dự án; ghi K5 'mô hình mô phỏng dự án' với nguồn là fact đã dùng", "", "", "")],
   [("A1", "Chip không có trong Renode/QEMU", "Mô phỏng tự xây theo mô hình EAA (MIL/SIL với HAL giả lập bằng ctypes); mức tin cậy ghi rõ"),
    ("A2", "Renode chưa cài", "UC-A03 (cài có hỏi)"),
    ("A3", "Firmware 'hello' không chạy trên mô phỏng", "DebugSession; phổ biến nhất là địa chỉ ngoại vi/IRQ sai → kiểm lại fact hoặc lỗi .repl")])

uc("UC-E02", "Mô hình hóa đối tượng điều khiển (plant) và cảm biến", "E. Mô phỏng", "Tester", "Kỹ sư",
   "Mô hình động lực học (ví dụ robot 2 bánh) và mock cảm biến/động cơ để kiểm thuật toán (MIL/SIL)",
   "Tính năng điều khiển (PID, bộ lọc) cần kiểm", "UC-E01", "Mô hình plant có tham số nguồn; kịch bản kiểm; đối chiếu nghiệm giải tích", "G-FACT (tham số vật lý)", "K5/K6", "S", "M3", "FR-VER-04", "UR-XM-03", "Mô phỏng",
   [("T", "Đề xuất mô hình (phương trình, tham số: khối lượng, chiều dài, hệ số ma sát) với nguồn (người cung cấp/đo)", "", "", ""),
    ("N", "Cung cấp/duyệt tham số", "", "", "G-FACT"),
    ("T", "Kiểm mô hình bằng nghiệm giải tích/trường hợp đơn giản", "", "", ""),
    ("K", "Lưu; gắn với kịch bản", "", "", "")])

uc("UC-E03", "Sinh và chạy kịch bản kiểm thử SIL", "E. Mô phỏng", "Tester", "Kỹ sư, Tool Layer",
   "Mỗi Feature có kịch bản kiểm chạy được trên mô phỏng với kỳ vọng định lượng",
   "Sau merge (G3) hoặc yêu cầu người", "sim/ sẵn sàng", "ToolReport(sim) + bằng chứng; chênh lệch → P3/P5", "—", "K7", "M", "M3", "FR-VER-04, FR-VER-05", "UR-XM-03", "Mô phỏng",
   [("T", "Từ kỳ vọng của Feature sinh bench/*.yaml (init, inject, expect)", "", "kịch bản", ""),
    ("H", "Chạy trên mô phỏng; bắt UART/GPIO/biến", "", "log", ""),
    ("K", "So với expect → ToolReport; lưu số đo", "", "", ""),
    ("T", "Nếu lệch: đề xuất nguyên nhân (mã / mô hình / fact)", "", "", "")])

uc("UC-E04", "So sánh SIL với HIL và cập nhật mô hình", "E. Mô phỏng", "Tester", "Kỹ sư",
   "Biết khoảng cách giữa mô phỏng và board thật; cải thiện mô hình có kiểm soát",
   "Cùng kịch bản đã chạy hai nơi", "UC-E03 + UC-F03", "Bảng chênh lệch; đề xuất cập nhật tham số mô hình (chờ duyệt)", "G-FACT", "K7 → đề xuất K5", "S", "M4", "FR-VER-04", "UR-XM-03", "Mô phỏng",
   [("K", "Ghép kết quả theo chỉ số (ổn định, latency, góc dư)", "", "bảng", ""),
    ("T", "Giải thích lệch; đề xuất tham số mới (ví dụ ma sát)", "", "", ""),
    ("N", "Duyệt cập nhật mô hình", "", "", "G-FACT")])

# ---------------------------------------------------------------- F. Xác minh & gỡ lỗi
uc("UC-F01", "Cấp quyền thao tác nguy hiểm (G-OPS)", "F. Xác minh & gỡ lỗi", "Người phê duyệt", "Knowledge Plane",
   "Không thao tác không đảo ngược nào xảy ra ngoài ý muốn; quyền hết hạn khi đóng phiên",
   "Tác tử/công cụ yêu cầu flash, erase, write_mem, fuse, install, tải tệp lớn", "—", "Permission theo phiên; ledger", "G-OPS", "—", "M", "M1", "FR-GOV-01, FR-MCP-02", "UR-QT-01", "Hàng đợi / Chat / mọi màn hình",
   [("K", "Tool nguy hiểm trả needs_permission và mở mục G-OPS: thao tác cụ thể, target, artifact hash, lý do", "", "", ""),
    ("N", "Cấp quyền cho lần này / cho phiên / từ chối", "", "", "G-OPS"),
    ("K", "Ghi Permission (expires_at); thực thi; ledger", "", "", "")],
   [("A1", "Người vắng mặt", "Thao tác chờ; tác tử tiếp tục việc khác không cần quyền")])

uc("UC-F02", "Nạp firmware và xác minh", "F. Xác minh & gỡ lỗi", "Tool Layer", "Kỹ sư",
   "Firmware lên board đúng artifact, có verify", "Sau G3 hoặc kiểm định", "Permission flash; adapter theo ISA", "ToolReport(flash); serial mở", "G-OPS", "K7", "M", "M2", "FR-VER-02", "UR-XM-02", "Log & serial",
   [("H", "Adapter theo ISA (probe-rs / avrdude / idf.py / west); verify sau nạp", "", "ToolReport", ""),
    ("K", "Mở serial; ghi log JSONL", "", "", "")],
   [("A1", "Verify thất bại", "Không đánh dấu nạp thành công; DebugSession")])

uc("UC-F03", "Quan sát serial, xác nhận vật lý (G4) và gắn bằng chứng", "F. Xác minh & gỡ lỗi", "Kỹ sư", "Tester, Knowledge Plane",
   "Tính năng chỉ passing khi người xác nhận quan sát thật; bằng chứng nối vào đồ thị", "Sau nạp", "Serial/log", "Feature passing; EVIDENCED_BY log hash/Measurement; known-good mới", "G4", "K7", "M", "M2", "FR-VER-03, FR-VER-05", "UR-XM-04", "Log & serial",
   [("H", "serial.expect theo kịch bản; ghi log", "", "", ""),
    ("T", "Tester so kết quả với kỳ vọng; trình bày cho người", "", "", ""),
    ("N", "Xác nhận quan sát (LED, chuyển động, số đo) hoặc từ chối", "", "", "G4"),
    ("K", "passing + evidence; tag known-good", "", "", "")])

uc("UC-F04", "Hỏi tác tử tại dòng log (log gigabyte)", "F. Xác minh & gỡ lỗi", "Kỹ sư", "Debugger, Knowledge Plane",
   "Từ một vùng log lớn đến giả thuyết có chứng cứ mà không gửi cả tệp", "Người chọn vùng log và bấm hỏi", "Log mở trong GEditor", "Diagnosis neo dòng; DebugSession", "—", "K7", "M", "M3", "FR-UI-03, FR-DBG-04", "UR-QS-02", "Log & serial",
   [("K", "GEditor tính thống kê toàn tệp (mẫu lặp, khoảng thời gian)", "", "stats", ""),
    ("K", "Lấy ngữ cảnh: fact thanh ghi liên quan, CodeUnit USES, DebugSession trước", "", "", ""),
    ("T", "Debugger: giả thuyết xếp hạng + thí nghiệm phân biệt", "", "Diagnosis", ""),
    ("N", "Chọn thí nghiệm / lưu DebugSession", "", "", "")])

uc("UC-F05", "Gỡ lỗi mức probe và gói chứng cứ", "F. Xác minh & gỡ lỗi", "Debugger", "Kỹ sư, Tool Layer",
   "Thu chứng cứ từ probe (thanh ghi, ngăn xếp, RTT) và đối chiếu hộ chiếu", "Thí nghiệm cần probe; HardFault", "Probe nối; Permission cho write nếu cần", "EvidencePack; Diagnosis cập nhật; DebugSession", "G-OPS (write/erase)", "K7", "M", "M3", "FR-DBG-01, FR-DBG-02, FR-DBG-03", "UR-GL-01, UR-GL-02", "Gỡ lỗi probe",
   [("H", "connect/halt/read_memory/diagnose_fault/unwind (probe-rs/OpenOCD)", "", "EvidencePack", ""),
    ("K", "Giải nghĩa thanh ghi theo hộ chiếu (SR1.AF=1)", "", "", ""),
    ("T", "Cập nhật giả thuyết; đề xuất sửa → STEP mới (UC-D01)", "", "", ""),
    ("K", "Lưu DebugSession gắn fact/mã/log", "", "", "")],
   [("A1", "Không có probe (AVR/PIC)", "Sinh firmware kiểm tra + serial + đo tín hiệu")])

uc("UC-F06", "Đo tín hiệu và năng lượng làm bằng chứng", "F. Xác minh & gỡ lỗi", "Tester", "Kỹ sư, Tool Layer",
   "Số đo vật lý (waveform, dòng) gắn vào Feature/Diagnosis", "Kịch bản yêu cầu; gỡ lỗi giao thức", "sigrok / INA2xx / PPK2", "Measurement; waveform đồng bộ log", "—", "K7", "S", "M5", "FR-UI-07", "UR-QS-06", "Gỡ lỗi probe",
   [("H", "sigrok-cli decode I2C/SPI; đo dòng theo mốc GPIO", "", "dataset", ""),
    ("K", "Đồng bộ thời gian với log; lưu Measurement", "", "", ""),
    ("T", "Đối chiếu giao dịch với kỳ vọng", "", "", "")])

# ---------------------------------------------------------------- G. Chia sẻ & đánh giá
uc("UC-G01", "Chạy benchmark Pack/skill trên board", "G. Chia sẻ & đánh giá", "Pack owner", "Tester",
   "Đo BC/BF/CF theo mô hình để kiểm định skill và so sánh mô hình", "Đổi skill/mô hình; trước phát hành", "Bộ tác vụ; board", "Báo cáo; badges bench", "G-OPS", "K7, badge", "M", "M2", "FR-BEN-01, FR-BEN-03", "UR-HT-01", "Benchmark",
   [("T", "Chạy từng tác vụ qua P2–P4 tự động (gate người thay bằng kỳ vọng quan sát tự động)", "", "", ""),
    ("K", "Chấm CF/BF/BC; ghi token/thời gian", "", "báo cáo", ""),
    ("T", "Phân tích ca lỗi → đề xuất sửa skill (K5) chờ duyệt", "", "", "")])

uc("UC-G02", "Đóng gói và phát hành hộ chiếu/skill (.hkp) — G5", "G. Chia sẻ & đánh giá", "Pack owner", "Knowledge Plane, Nguồn ngoài",
   "Gói có chữ ký, huy hiệu, license; không chứa tài liệu hãng", "Người bấm phát hành", "Hộ chiếu reviewed/verified", "Gói trên registry; ghi công", "G5", "—", "M", "M4", "FR-REG-01, FR-REG-02, FR-REG-03", "UR-RG-01", "Registry",
   [("K", "Đóng gói fact + con trỏ nguồn + skills + bench + badges; kiểm license", "", ".hkp", ""),
    ("N", "Duyệt; ký", "", "", "G5"),
    ("K", "Publish; index", "", "", "")],
   [("A1", "Thiếu license ở Source", "Từ chối đóng gói cho tới khi bổ sung")])

uc("UC-G03", "Pull gói từ registry vào dự án", "G. Chia sẻ & đánh giá", "Kỹ sư", "Knowledge Plane",
   "Tin dùng gói có huy hiệu; nạp vào lớp lõi/overlay", "Tìm gói; UC-A02", "Registry", "Hộ chiếu trong store; ghim phiên bản", "G-SRC", "K2/K2′/K4/K5", "M", "M4", "FR-REG-04", "UR-RG-02", "Registry",
   [("N", "Xem huy hiệu, benchmark, chữ ký; chọn phiên bản", "", "", "G-SRC"),
    ("K", "Kiểm chữ ký; nạp; ghim", "", "", "")])

uc("UC-G04", "Xuất báo cáo và ma trận Người–AI", "G. Chia sẻ & đánh giá", "Kỹ sư", "Knowledge Plane",
   "Báo cáo dự án có nguồn; ma trận điền tự động từ ledger", "Người bấm xuất", "Ledger", "docx/pdf/md + Excel", "G5", "—", "S", "M4", "FR-GOV-06", "UR-HT-03 (EAA)", "Môi trường & báo cáo",
   [("K", "Tổng hợp gate, lượt gọi, ToolReport, Feature, benchmark", "", "", ""),
    ("K", "Sinh tài liệu có mục Nguồn", "", "", ""),
    ("N", "Duyệt", "", "", "G5")])

# ---------------------------------------------------------------- H. Tương tác tác tử
uc("UC-H01", "Ra lệnh / hỏi trong cửa sổ trò chuyện", "H. Tương tác tác tử", "Kỹ sư", "Librarian, Planner, Coder, Debugger",
   "Một hội thoại điều phối nhiều vai trò; mọi hành động có nhật ký và gate", "Người gõ", "Dự án mở", "Phản hồi có trích dẫn; hành động được thực hiện hoặc chờ gate", "Theo hành động", "—", "M", "M2", "FR-AGT-01, FR-MCP-01", "UR-MA-01", "Trò chuyện",
   [("N", "Một câu lệnh, có thể là lệnh lớn bao trùm nhiều UC ('từ zip này dựng tri thức, môi trường, mô phỏng rồi viết firmware')", "", "", "Lệnh"),
    ("T", "Router phân loại ý định → vai trò; lệnh lớn được tách thành chuỗi UC và chạy theo chính sách A3", "", "", ""),
    ("T", "Vai trò trả lời; nếu cần hành động nguy hiểm → G-OPS; nếu thiếu tri thức → UC-B07", "", "", ""),
    ("K", "Ledger; panel 'hành động đã làm'", "", "", "")])

uc("UC-H02", "Tác tử tự đánh giá đủ thông tin trước khi làm", "H. Tương tác tác tử", "Planner / Librarian", "Kỹ sư",
   "Không có bước nào bắt đầu với tri thức thiếu mà tác tử 'đoán'", "Trước mọi kế hoạch/sinh mã", "—", "Danh sách thiếu → UC-B07 hoặc xác nhận đủ", "—", "—", "M", "M2", "FR-ACQ-05", "UR-TT-02 (KT-02 EAA)", "Trò chuyện",
   [("T", "Liệt kê fact cần cho tác vụ; kiểm tồn tại và trạng thái (reviewed?)", "", "", ""),
    ("T", "Nếu thiếu/chưa duyệt → nêu rõ và dừng chờ", "", "", "")])

uc("UC-H03", "Vượt ngân sách hoặc mô hình không khả dụng", "H. Tương tác tác tử", "Knowledge Plane", "Kỹ sư",
   "Dừng có kiểm soát; fallback đúng chính sách; người quyết định tăng ngân sách", "Router báo BudgetExceeded / lỗi 429 / timeout", "models.yaml", "Fallback hoặc gate 'tăng ngân sách'", "—", "Ledger", "M", "M0", "FR-LLM-02, FR-LLM-04", "UR-MH-03", "Mô hình & chi phí",
   [("K", "Thử ứng viên kế tiếp theo fallback_on", "", "", ""),
    ("K", "Nếu vượt ngân sách ngày → mở mục hỏi người", "", "", ""),
    ("N", "Tăng ngân sách / chuyển cục bộ / dừng", "", "", "")])

uc("UC-H04", "Tác tử từ chối hoặc trả lời 'không biết'", "H. Tương tác tác tử", "Librarian", "Kỹ sư",
   "Trung thực: không có nguồn thì nói không có; refusal của mô hình được chuẩn hóa", "Không tìm thấy fact; mô hình từ chối", "—", "Câu trả lời 'không có trong hộ chiếu' + đề nghị UC-B07; ledger", "—", "—", "M", "M0", "NFR-02", "UQ-01", "Trò chuyện",
   [("T", "Trả lời rõ 'không có trong hộ chiếu' và đề nghị tìm/nạp", "", "", ""),
    ("K", "stop_reason refusal → fallback theo chính sách; ghi ledger", "", "", "")])

# ---------------------------------------------------------------- Kịch bản mẫu của anh Công
SCENARIO = [
    ("1", "Tạo dự án 'robot-ctrl', chưa biết chip", "UC-A01, UC-A02 (bỏ trống chip)", "Kỹ sư", "—", ".hkw/ tạo; trạng thái 'chưa biết chip'"),
    ("2", "Kéo thả robot-kit.zip (schematic PDF + KiCad, ảnh board, datasheet BME280/MPU6050, README, vài tệp linh tinh)", "UC-B01", "Kỹ sư, Librarian", "—", "Bảng phân loại: 1 KiCad (vàng-cấu trúc), 2 PDF (bạc), 3 ảnh (bạc), 4 tệp bỏ qua"),
    ("3", "Librarian suy ra MCU STM32F411CE và các linh kiện từ KiCad + PDF; người xác nhận", "UC-B02", "Librarian, Kỹ sư", "G-FACT", "Danh sách linh kiện đã xác nhận; yêu cầu hộ chiếu cho STM32F411, BME280, MPU6050, A4988"),
    ("4", "Pull hộ chiếu lõi STM32F411 từ registry/seed (SVD chính hãng); ghim phiên bản", "UC-G03, UC-B03", "Knowledge Plane", "G-SRC (chọn phiên bản)", "13.439 fact vàng; pin st.stm32f411@1.1.0; ISA armv7e-m"),
    ("5", "Dựng BoardPassport từ KiCad; phát hiện xung đột PB3", "UC-B06, UC-C01", "Cartographer, Kỹ sư", "G-FACT", "31 net; 1 xung đột được người chọn phương án"),
    ("6", "Trích xuất 2 PDF cảm biến; duyệt theo nhóm với ảnh cắt", "UC-B04, UC-B10", "Librarian, Kỹ sư", "G-FACT", "58 fact bạc reviewed cho BME280; 44 cho MPU6050"),
    ("7", "Thiếu: datasheet A4988 và công thức bù nhiệt tr.25 → yêu cầu; Librarian tìm registry → hãng → web; người chọn nguồn; tải; trích; duyệt", "UC-B07, UC-B08, UC-B09, UC-B04, UC-B10", "Librarian, Kỹ sư", "G-SRC, G-FACT", "Nguồn A4988 (Allegro) tầng bạc; 12 fact reviewed; yêu cầu đóng"),
    ("8", "eide doctor: phát hiện thiếu Renode và probe-rs; người duyệt cài; khóa phiên bản", "UC-A03", "Kỹ sư, Tool Layer", "G-OPS", "tools.lock"),
    ("9", "Cấu hình mô hình: coder gemini-flash, reviewer claude-sonnet; ngân sách 5 USD; chưa bật offline", "UC-A04", "Kỹ sư", "—", "models.yaml"),
    ("10", "Tester dựng mô phỏng: .repl từ hộ chiếu, mock BME280/MPU6050/A4988, LED PB3, UART2 → console; firmware hello chạy", "UC-E01", "Tester, Kỹ sư", "G-FACT (tham số mock), G-OPS (cài)", "sim/ sẵn sàng; ToolReport sim đạt"),
    ("11", "Mô hình plant robot 2 bánh với tham số người cung cấp", "UC-E02", "Tester, Kỹ sư", "G-FACT", "Mô hình đã kiểm bằng nghiệm giải tích"),
    ("12", "Mô tả tính năng F-01…F-08; Planner lập kế hoạch có trích dẫn; duyệt G1", "UC-D01, UC-D02, UC-H02", "Kỹ sư, Planner", "G1", "FEATURES.json; kế hoạch"),
    ("13", "Sinh mã từng Feature; constant-guard; 4 cổng; reviewer; duyệt G3", "UC-D03, UC-D04", "Coder, Reviewer, Kỹ sư", "G3", "Mã merge có fact id"),
    ("14", "Chạy kịch bản SIL cho từng Feature; lệch → sửa", "UC-E03", "Tester", "—", "ToolReport sim; bằng chứng"),
    ("15", "(Khi có board) kiểm định hộ chiếu, nạp, quan sát, G4; so sánh SIL/HIL", "UC-B12, UC-F01, UC-F02, UC-F03, UC-E04", "Kỹ sư, Tester", "G-OPS, G4, G-FACT", "Badge verified; Feature passing; cập nhật mô hình"),
    ("16", "Lỗi NACK trong log 3 GB → hỏi tại dòng → probe → chứng cứ → sửa mạch/ràng buộc", "UC-F04, UC-F05, UC-F06, UC-D01", "Kỹ sư, Debugger", "G-OPS, G-FACT", "DebugSession; STEP mới"),
    ("17", "Benchmark; đóng gói hộ chiếu BME280/A4988 + skill; phát hành nội bộ; xuất báo cáo và ma trận Người–AI", "UC-G01, UC-G02, UC-G04", "Pack owner, Kỹ sư", "G5", "Gói .hkp; báo cáo"),
]
