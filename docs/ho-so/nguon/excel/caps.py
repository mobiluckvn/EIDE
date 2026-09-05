# -*- coding: utf-8 -*-
"""Danh mục năng lực đầy đủ của EIDE (capability catalog).
Mỗi dòng: (mã, nhóm, tên năng lực, mô tả, tham số vào, kết quả ra, lớp rủi ro R0–R4, mức T1/T2/T3, grounding/tiền điều kiện, hỏi kỹ sư khi, UC liên quan, mốc, trạng thái M0)
"""
C = []
def add(ns, rows):
    for i, r in enumerate(rows, 1):
        C.append((f"{ns.upper()}-{i:02d}", ns) + tuple(r))

add("project", [
 ("project.create", "Tạo dự án từ câu lệnh; suy ra tên/mô tả/đường dẫn/chip; áp mặc định", "text, docs_path?, chip?, autonomy?", "project_id, .hkw/", "R2", "T1", "Kiểm trùng tên/gần giống; mẫu tham chiếu", "Trùng tên đúng; ghi đè", "UC-A01", "M0", "có (init)"),
 ("project.open", "Mở dự án đã có; kiểm hash store; tái dựng đồ thị", "project_id|path", "state summary", "R0", "T1", "Hash store hợp lệ", "Hash lệch (ghi ngoài cổng)", "UC-A06", "M0", "có"),
 ("project.list", "Liệt kê dự án trong workspace với ngày, board, tiến độ", "—", "projects[]", "R0", "T1", "—", "—", "Z-02", "M1", "chưa"),
 ("project.clone", "Nhân bản dự án thành dự án mới (giữ tri thức, bỏ ledger)", "src, new_name", "project_id", "R2", "T1", "—", "—", "Z-02", "M2", "chưa"),
 ("project.archive", "Lưu trữ/đóng dự án (không xóa)", "project_id", "—", "R2", "T1", "—", "Xóa thật sự (R4)", "Z-08", "M2", "chưa"),
 ("project.set_target", "Đặt/suy ra ISA, chip, board; ghim phiên bản hộ chiếu", "chip?, isa?, board?", "pins", "R2", "T1", "Hộ chiếu có trong store/registry", "Tài liệu nêu >1 chip", "UC-A02", "M0", "một phần"),
 ("project.rollback", "Về known-good gần nhất hoặc tag chỉ định", "tag?", "state", "R2", "T1", "Có tag", "—", "UC-D06", "M2", "chưa"),
 ("project.status", "Tổng hợp tiến độ, feature, gate mở, chi phí", "—", "report", "R0", "T1", "—", "—", "UC-A06", "M1", "một phần"),
 ("project.preferences", "Ghi/đọc tùy chọn đã học từ câu trả lời của kỹ sư", "key, value?", "prefs", "R1", "T1", "—", "—", "D8", "M1", "chưa"),
])
add("memory", [
 ("memory.compose", "Ghép ngữ cảnh 7 lớp K1–K7 theo vai trò và tác vụ; kiểm ngân sách token", "role, task", "context ≤ budget", "R0", "T1", "—", "—", "FR-AGT-02", "M1", "thiết kế"),
 ("memory.compress", "Nén ngữ cảnh: tóm tắt lịch sử, lọc log theo mẫu, rút gọn fact", "context", "context'", "R0", "T1", "—", "—", "FR-AGT-02", "M1", "chưa"),
 ("memory.retrieve", "Truy hồi Graph-RAG: lan tỏa 2 bước từ subject rồi lấy văn bản", "subjects[], k", "facts, snippets", "R0", "T1", "—", "—", "FR-PSP-06", "M2", "một phần (KG)"),
 ("memory.progress", "Ghi/đọc PROGRESS.md, FEATURES.json (harness dài hạn)", "entry?", "progress", "R1", "T1", "—", "—", "FR-GOV-03", "M1", "chưa"),
 ("memory.ledger", "Ghi nhật ký bất biến: gate, tool, model call, quyết định tự động", "record", "—", "R1", "T1", "—", "—", "FR-LLM-04", "M0", "có"),
 ("memory.error_ledger", "Sổ lỗi: ghi lỗi ảo giác/từ chối; đưa vào prompt phủ định", "error", "—", "R1", "T1", "—", "—", "FR-KB-03 (EAA)", "M2", "chưa"),
 ("memory.forget", "Xóa mềm/hết hạn ngữ cảnh tạm, cache; không xóa fact", "scope", "—", "R1", "T1", "—", "Xóa tri thức đã duyệt (R4)", "KAD §6.7", "M2", "chưa"),
 ("memory.summarize_session", "Tóm tắt phiên: đã làm gì, chờ gì, bước tiếp", "—", "summary", "R0", "T1", "—", "—", "UC-A06", "M1", "chưa"),
])
add("archive", [
 ("archive.list", "Liệt kê nội dung zip/7z/rar/tar/gz không giải nén toàn bộ", "path", "entries[]", "R0", "T1", "—", "—", "UC-B01", "M0", "zip/tar có"),
 ("archive.unpack", "Giải nén đệ quy có giới hạn (≤5 cấp, ≤2 GB), chống zip-slip, sandbox", "path, limits", "files[]", "R1", "T1", "—", "Có mật khẩu; vượt giới hạn", "UC-B01", "M0", "zip/tar có; rar/7z chưa"),
 ("archive.extract_one", "Lấy một tệp bên trong theo đường dẫn/mẫu", "path, member", "file", "R0", "T1", "—", "—", "UC-B01", "M1", "chưa"),
 ("archive.query", "Tìm bên trong kho nén theo tên/kiểu/nội dung (grep, chữ ký)", "path, pattern", "matches[]", "R0", "T1", "—", "—", "UC-B01", "M1", "chưa"),
 ("ingest.classify", "Phân loại tệp theo chữ ký nội dung → loại, tầng, extractor", "files[]", "classification", "R0", "T1", "—", "—", "UC-B01", "M0", "có"),
 ("ingest.hash_dedupe", "sha256, phát hiện trùng với Source đã có", "files[]", "new/dup", "R0", "T1", "—", "—", "UC-B01", "M0", "có"),
 ("ingest.index_text", "Lập chỉ mục văn bản (BM25) cho tài liệu ngữ cảnh không sinh fact", "files[]", "index", "R1", "T1", "—", "—", "UC-B01", "M1", "chưa"),
])
add("search", [
 ("search.registry", "Tìm gói/hộ chiếu/mẫu tham chiếu trong registry", "query", "candidates[]", "R0", "T1", "—", "—", "UC-B08", "M4", "chưa"),
 ("search.vendor", "Tìm trong kho hãng theo mẫu URL đã biết (CMSIS pack, Microchip pack, ST, Bosch…)", "part", "candidates[]", "R0", "T1", "—", "—", "UC-B08", "M1", "chưa"),
 ("search.docs_mcp", "Hỏi docs MCP của hãng (Espressif, Nordic) → đoạn trích + URL + ngày", "query, vendor", "snippets[]", "R0", "T1", "—", "—", "UC-B08", "M2", "chưa"),
 ("search.web", "Tìm web nhiều nguồn (datasheet, SVD, repo, errata, forum); ưu tiên tên miền hãng; không tải", "query, kinds[]", "candidates[]", "R0", "T1", "Có Internet", "—", "UC-B08", "M1", "chưa"),
 ("search.rank", "Xếp hạng ứng viên theo tầng dự kiến, tên miền, hash/license, khớp mã linh kiện", "candidates[]", "ranked[]", "R0", "T1", "—", "—", "UC-B08", "M1", "chưa"),
 ("search.fetch", "Tải ứng viên (giới hạn dung lượng), hash, phát hiện license", "candidate", "Source", "R1", "T1", "Theo chính sách G-SRC", "Ngoài danh sách tin cậy; license không rõ; tệp lớn", "UC-B09", "M1", "chưa"),
 ("search.verify_match", "Tóm tắt tài liệu vừa tải và kiểm có đúng linh kiện/phiên bản không", "Source, part", "match score", "R0", "T1", "—", "Không khớp", "UC-B09", "M1", "chưa"),
 ("search.missing", "Từ tác vụ, liệt kê tri thức còn thiếu và tạo yêu cầu (sufficiency check)", "task", "requests[]", "R1", "T1", "—", "—", "UC-B07, UC-H02", "M1", "chưa"),
 ("search.reference_projects", "Tìm mẫu dự án tham chiếu cho một ý tưởng (robot cân bằng…) trong registry rồi web", "idea", "templates[]", "R0", "T1", "—", "—", "Z-01", "M4", "chưa"),
])
add("extract", [
 ("extract.svd", "SVD → hộ chiếu chip (derivedFrom, dim, cluster, enum)", "file", "facts", "R1", "T1", "—", "—", "UC-B03", "M0", "có"),
 ("extract.atdf", "ATDF (Microchip) → hộ chiếu", "file", "facts", "R1", "T1", "—", "—", "UC-B03", "M0", "có"),
 ("extract.edc", "EDC/.PIC → hộ chiếu", "file", "facts", "R1", "T1", "—", "—", "UC-B03", "M1", "chưa"),
 ("extract.header_c", "Header C chính hãng → địa chỉ/bit (đối chiếu SVD)", "file", "facts", "R1", "T1", "—", "—", "UC-B03", "M1", "chưa"),
 ("extract.dt_binding", "Devicetree binding YAML → thuộc tính bắt buộc", "file", "facts", "R1", "T1", "—", "—", "UC-B03", "M2", "chưa"),
 ("extract.pdf_layout", "Bố cục PDF: chương, bảng, hình, bbox (Docling/pdfplumber)", "pdf", "blocks[]", "R1", "T1", "—", "—", "UC-B04", "M1", "chưa"),
 ("extract.pdf_register_map", "Bảng thanh ghi/bit-field từ PDF → fact có trang/bbox", "pdf, blocks", "facts", "R1", "T1", "—", "confidence < ngưỡng", "UC-B04", "M1", "chưa"),
 ("extract.pdf_electrical", "Thông số điện, timing, nhiệt → fact (tầng bạc, luôn cần duyệt)", "pdf", "facts", "R1", "T2", "—", "Luôn (an toàn)", "UC-B04", "M1", "chưa"),
 ("extract.pdf_pinout", "Pinout/package từ bảng hoặc hình → pin function", "pdf", "facts", "R1", "T1", "—", "Từ hình", "UC-B04", "M2", "chưa"),
 ("extract.pdf_errata", "Errata → overlay K2′ với điều kiện áp dụng", "pdf", "facts", "R1", "T2", "—", "Luôn", "UC-B04", "M2", "chưa"),
 ("extract.pdf_formula", "Công thức/thuật toán (ví dụ bù nhiệt BME280) → skill dự án có trích dẫn", "pdf, section", "skill", "R1", "T1", "—", "—", "UC-B04", "M2", "chưa"),
 ("extract.ocr", "OCR PDF scan/ảnh chữ; giảm confidence 0,1", "file", "text+layout", "R1", "T1", "—", "—", "UC-B04", "M2", "chưa"),
 ("extract.image_schematic", "Ảnh schematic → net/linh kiện đề xuất (thị giác) kèm ảnh cắt", "image", "proposals", "R1", "T2", "Mô hình có thị giác", "Luôn (đề xuất)", "UC-B05", "M2", "chưa"),
 ("extract.image_board", "Ảnh board → nhãn chip/linh kiện, vị trí, cổng", "image", "parts[]", "R1", "T2", "—", "Luôn", "UC-B05, Z-04", "M2", "chưa"),
 ("extract.image_scope", "Ảnh màn hình oscilloscope/LA → giá trị đo, kết luận sơ bộ", "image", "measurement", "R1", "T2", "—", "Luôn", "UC-F06", "M5", "chưa"),
 ("extract.kicad_netlist", "kicad-cli → net/pin/part", "file", "BoardPassport", "R1", "T1", "kicad-cli", "—", "UC-B06", "M2", "chưa"),
 ("extract.bom", "Trích BOM từ schematic (KiCad/PDF/Excel/README) → bảng ref, MPN, giá trị, số lượng", "sources[]", "bom[]", "R1", "T1", "—", "Mâu thuẫn giữa nguồn", "UC-B06, Z-01", "M2", "chưa"),
 ("extract.bom_enrich", "Với mỗi MPN trong BOM: tìm hộ chiếu/datasheet (search.*) và gắn", "bom", "bom+links", "R1", "T1", "—", "Nguồn ngoài tin cậy", "UC-B08", "M2", "chưa"),
 ("extract.office", "DOCX/XLSX/HTML/MD → văn bản, bảng có vị trí", "file", "blocks", "R1", "T1", "—", "—", "UC-B01", "M1", "chưa"),
 ("extract.readme_goal", "Suy ra mục tiêu dự án, danh sách tính năng từ README/ghi chú", "text", "features[] đề xuất", "R0", "T1", "—", "—", "Z-07", "M2", "chưa"),
 ("extract.code_constants", "Quét mã sẵn có: hằng số địa chỉ/bit → ánh xạ fact; danh sách không nguồn", "repo", "code_units", "R1", "T1", "—", "—", "UC-A05", "M1", "chưa"),
])
add("passport", [
 ("passport.import", "Ghi FactBatch qua cổng ghi duy nhất (merge tier, conflict, ledger)", "batch", "WriteResult", "R1", "T1", "—", "—", "UC-B03", "M0", "có"),
 ("passport.query", "Tra fact theo part/periph/reg/field hoặc câu hỏi NL; kèm trích dẫn/tầng/trạng thái", "q", "facts+citations", "R0", "T1", "—", "—", "UC-B14", "M0", "có"),
 ("passport.list", "Liệt kê hộ chiếu, phiên bản, huy hiệu", "kind?", "passports[]", "R0", "T1", "—", "—", "—", "M0", "có"),
 ("passport.diff", "So hai phiên bản hộ chiếu: fact thêm/bớt/đổi", "a, b", "diff", "R0", "T1", "—", "—", "UC-B13", "M2", "chưa"),
 ("passport.upgrade", "Nâng ghim sang phiên bản mới; impact; đưa feature về failing", "id, ver", "impact", "R2", "T2", "—", "Luôn (ảnh hưởng mã)", "UC-B13", "M2", "chưa"),
 ("passport.verify_on_board", "Sinh firmware ID/GPIO/UART, nạp, so, gắn huy hiệu", "id, target", "badge", "R3", "T1", "Board lab", "Board không lab; ID lệch", "UC-B12", "M1", "chưa"),
 ("passport.export", "Xuất hộ chiếu YAML/JSON có nguồn", "id", "file", "R0", "T1", "—", "—", "UC-G04", "M1", "chưa"),
 ("passport.resolve_address", "Địa chỉ/hex → tên ngoại vi/thanh ghi (cho hover, .map)", "addr", "name", "R0", "T1", "—", "—", "UC-D05", "M3", "chưa"),
])
add("kg", [
 ("kg.build", "Dựng/tải đồ thị từ store (cache có hash)", "part?", "graph", "R0", "T1", "—", "—", "—", "M0", "có"),
 ("kg.conflicts", "Fact mâu thuẫn + tài nguyên bị dùng bởi >1 module", "project", "conflicts[]", "R0", "T1", "—", "—", "UC-C01", "M0", "có"),
 ("kg.impact", "Fact đổi → CodeUnit stale, Feature cần tái kiểm", "fact_id", "impact", "R0", "T1", "—", "—", "UC-B13", "M0", "có"),
 ("kg.neighborhood", "Lân cận ≤ 2 bước cho ngữ cảnh/hiển thị", "node, depth", "subgraph", "R0", "T1", "—", "—", "UC-B15", "M0", "có"),
 ("kg.review_facts", "Duyệt fact theo nhóm (tự theo chính sách hoặc người)", "group, decision", "—", "R1", "T1*", "—", "confidence thấp; mâu thuẫn", "UC-B10", "M1", "chưa"),
 ("kg.resolve_conflict", "Chọn fact hiện hành / cả hai theo điều kiện", "conflict_id, choice", "—", "R1", "T2", "—", "Luôn", "UC-B11", "M1", "chưa"),
 ("kg.supersede", "Fact mới thay fact cũ có lý do", "old, new", "—", "R1", "T1", "—", "—", "UC-B10", "M0", "có"),
 ("kg.request", "Tạo yêu cầu nhận tri thức", "need", "request_id", "R1", "T1", "—", "—", "UC-B07", "M1", "chưa"),
 ("kg.evidence", "Bằng chứng gắn với feature/fact (log hash, số đo, badge)", "id", "evidence[]", "R0", "T1", "—", "—", "UC-F03", "M2", "chưa"),
])
add("board", [
 ("board.build_passport", "Dựng BoardPassport từ netlist/ảnh/BOM; suy ra bus/địa chỉ/pull-up", "sources", "BoardPassport", "R1", "T1", "—", "Từ ảnh", "UC-B06", "M2", "chưa"),
 ("board.check_pins", "Xung đột chân/AF, reserved/boot, trùng địa chỉ bus", "board, plan?", "conflicts[]", "R0", "T1", "—", "—", "UC-C01", "M2", "chưa"),
 ("board.constraints", "Sinh ràng buộc điện/bus cho Coder", "board", "constraints", "R1", "T1", "—", "—", "UC-B06", "M2", "chưa"),
 ("board.propose_fix", "Đề xuất phương án cho xung đột (remap AF, đổi chân)", "conflict", "options[]", "R0", "T1", "—", "Chạm mã passing", "UC-C01", "M2", "chưa"),
 ("board.mark_lab", "Đánh dấu board là lab (không cơ cấu chấp hành) để tự nạp", "board", "—", "R1", "T2", "—", "Luôn (một lần)", "Z-10", "M2", "chưa"),
])
add("env", [
 ("env.detect", "Nhận diện HĐH, kiến trúc máy, cổng USB/serial, probe đang nối", "—", "EnvReport", "R0", "T1", "—", "—", "UC-A03", "M0", "một phần (doctor)"),
 ("env.check", "Kiểm từng công cụ theo manifest ISA: có/thiếu/phiên bản/hash", "isa", "report", "R0", "T1", "—", "—", "UC-A03", "M0", "có"),
 ("env.install", "Cài công cụ mở từ danh sách tin cậy (brew/apt/pip/cargo/tải chính hãng)", "tool", "ToolReport", "R4→T1 theo danh sách trắng", "T1", "Danh sách trắng", "Ngoài danh sách; cần sudo; toolchain đóng", "UC-A03", "M1", "chưa"),
 ("env.guide_install", "Hướng dẫn cài tay công cụ đóng/có license", "tool", "steps", "R0", "T3", "—", "—", "UC-A03", "M1", "chưa"),
 ("env.lock", "Khóa phiên bản (tools.lock) và phát hiện trôi", "—", "tools.lock", "R1", "T1", "—", "Trôi phiên bản", "UC-A03", "M1", "chưa"),
 ("env.install_pack", "Cài Platform Pack (skill, adapter, manifest) cho ISA", "isa", "—", "R1", "T1", "—", "—", "UC-A03", "M2", "chưa"),
 ("env.sandbox", "Chạy extractor/lệnh trong sandbox giới hạn CPU/RAM/thời gian/đường dẫn", "cmd", "result", "R1", "T1", "—", "—", "NFR-06", "M1", "chưa"),
])
add("plan", [
 ("plan.define_feature", "Chuẩn hóa yêu cầu → Feature có kỳ vọng quan sát được, ràng buộc", "text", "Feature", "R1", "T1", "—", "Mơ hồ (≤ 3 câu hỏi)", "UC-D01", "M2", "chưa"),
 ("plan.decompose", "Tách mục tiêu lớn thành module/feature theo kiến trúc (driver → HAL → app)", "goal", "features[]", "R1", "T1", "—", "—", "Z-07", "M2", "chưa"),
 ("plan.create", "Kế hoạch từng bước có trích dẫn fact; missing[]", "feature", "Plan", "R1", "T1*", "Đủ tri thức", "Đổi kiến trúc; tài nguyên mới", "UC-D02", "M2", "chưa"),
 ("plan.order", "Sắp thứ tự phụ thuộc giữa module (clock → GPIO → I2C → cảm biến → app)", "features[]", "order", "R0", "T1", "—", "—", "UC-D02", "M2", "chưa"),
 ("plan.estimate", "Ước lượng token/chi phí/thời gian; so ngân sách", "plan", "estimate", "R0", "T1", "—", "Vượt ngân sách", "UC-H03", "M2", "chưa"),
 ("plan.replan", "Lập lại khi thất bại/thiếu tri thức/xung đột", "plan, reason", "Plan'", "R1", "T1", "—", "Lần 3", "UC-D03", "M2", "chưa"),
 ("plan.sufficiency", "Tự đánh giá đủ thông tin trước khi làm", "task", "missing[]", "R0", "T1", "—", "—", "UC-H02", "M1", "chưa"),
])
add("code", [
 ("code.generate_module", "Sinh một module theo STEP + skill + fact; hkw:fact cho hằng số", "step", "CodePatch", "R2", "T1", "G1 approved", "—", "UC-D03", "M2", "chưa"),
 ("code.modify", "Sửa mã có sẵn theo yêu cầu/finding", "file, intent", "CodePatch", "R2", "T1", "—", "Chạm ISR/linker", "UC-D03", "M2", "chưa"),
 ("code.integrate", "Tích hợp module: wiring, init order, cấu hình build, kiểm tương thích giao diện", "modules[]", "CodePatch", "R2", "T1", "—", "Xung đột tài nguyên", "UC-D03", "M2", "chưa"),
 ("code.constant_guard", "Hook: mọi hằng số phần cứng phải trỏ fact reviewed/verified", "patch", "verdict", "R0", "T1", "—", "—", "UC-D03", "M1", "chưa"),
 ("code.build", "Biên dịch theo Pack; phân loại lỗi", "project", "ToolReport", "R0", "T1", "Toolchain", "—", "UC-D03", "M2", "chưa"),
 ("code.size", "Kiểm Flash/RAM so ràng buộc; phân tích .map", "artifact", "ToolReport", "R0", "T1", "—", "—", "UC-D03", "M2", "chưa"),
 ("code.static", "cppcheck/clang-tidy + quy tắc Pack (delay, malloc, float trong ISR)", "project", "ToolReport", "R0", "T1", "—", "—", "UC-D03", "M2", "chưa"),
 ("code.test_host", "Kiểm thử trên máy chủ với mock ngoại vi (ctypes)", "project", "ToolReport", "R0", "T1", "—", "—", "UC-D03", "M2", "chưa"),
 ("code.generate_tests", "Sinh unit test/kịch bản từ kỳ vọng Feature", "feature", "tests", "R2", "T1", "—", "—", "UC-D03", "M2", "chưa"),
 ("code.self_repair", "Tự sửa theo ToolReport ≤ 3 vòng", "report", "CodePatch'", "R2", "T1", "—", "Lần 3", "UC-D03", "M2", "chưa"),
 ("code.review", "Reviewer khác hãng chấm checklist", "patch", "Review", "R0", "T1", "≥ 2 hãng", "—", "UC-D04", "M2", "chưa"),
 ("code.merge", "Merge vào auto/ với commit truy vết; cửa sổ hoàn tác", "patch", "commit", "R2", "T1*", "4 cổng + review", "Blocker; chạm ISR/linker; ngoài phạm vi", "UC-D04", "M2", "chưa"),
 ("code.revert", "Hoàn tác merge", "commit", "—", "R2", "T1", "—", "—", "UC-D04", "M2", "chưa"),
 ("code.annotate", "Gợi ý/chèn hkw:fact cho mã người viết", "file", "suggestions", "R2", "T1", "—", "—", "UC-D05", "M3", "chưa"),
 ("code.docs", "Sinh tài liệu mã/README module có trích dẫn", "module", "docs", "R2", "T1", "—", "—", "UC-G04", "M3", "chưa"),
 ("code.refactor", "Tái cấu trúc theo quy ước repo, không đổi hành vi (kiểm bằng test)", "scope", "CodePatch", "R2", "T1", "—", "—", "UC-A05", "M3", "chưa"),
])
add("sim", [
 ("sim.build_platform", "Sinh mô tả nền tảng (Renode .repl / simavr / tự xây) từ hộ chiếu", "chip, board", "sim/", "R1", "T1", "Hộ chiếu vàng", "Chip không có trong Renode", "UC-E01", "M3", "chưa"),
 ("sim.mock_peripheral", "Mock ngoại vi ngoài theo datasheet (id, dữ liệu theo công thức)", "part", "mock", "R1", "T1*", "—", "Tham số không có nguồn", "UC-E01", "M3", "chưa"),
 ("sim.model_plant", "Mô hình động lực học (robot 2 bánh) với tham số có nguồn/tạm", "params", "model", "R1", "T2", "—", "Tham số thật", "UC-E02", "M3", "chưa"),
 ("sim.scenario", "Sinh kịch bản từ kỳ vọng Feature (init, inject, expect)", "feature", "yaml", "R1", "T1", "—", "—", "UC-E03", "M3", "chưa"),
 ("sim.run", "Chạy firmware trên mô phỏng; bắt UART/GPIO/biến", "artifact, scenario", "ToolReport", "R0", "T1", "—", "—", "UC-E03", "M3", "chưa"),
 ("sim.sweep", "Quét tham số (PID, tốc độ bus) trên mô phỏng", "ranges", "table", "R0", "T1", "—", "—", "UC-E03", "M3", "chưa"),
 ("sim.compare_hil", "So kết quả SIL/HIL; đề xuất cập nhật mô hình", "scenario", "diff", "R0", "T1", "—", "Cập nhật mô hình", "UC-E04", "M4", "chưa"),
])
add("target", [
 ("target.detect", "Phát hiện board/probe/cổng serial; đọc ID", "—", "targets[]", "R0", "T1", "—", "—", "UC-F02", "M2", "chưa"),
 ("target.flash", "Nạp + verify qua adapter ISA", "artifact, target", "ToolReport", "R3", "T1*", "Board lab; artifact qua G3", "Board không lab; động cơ", "UC-F02", "M2", "chưa"),
 ("target.reset", "Reset board", "target", "—", "R3", "T1", "Board lab", "—", "UC-F02", "M2", "chưa"),
 ("target.serial", "Mở/đọc/ghi/expect serial đa cổng; ghi JSONL", "port, cmd", "lines", "R0", "T1", "—", "—", "UC-F03", "M2", "chưa"),
 ("target.probe_read", "halt/step/read_memory/read_registers/breakpoint (đọc)", "op", "EvidencePack", "R0", "T1", "Probe", "—", "UC-F05", "M3", "chưa"),
 ("target.probe_write", "write_memory/RTT write", "op", "—", "R3", "T1*", "Board lab", "Không lab", "UC-F05", "M3", "chưa"),
 ("target.erase_fuse", "Xóa flash toàn bộ, ghi fuse/option byte", "op", "—", "R4", "T3", "—", "Luôn", "UC-F01", "M3", "chưa"),
 ("target.diagnose_fault", "Đọc thanh ghi lỗi, unwind stack, ánh xạ dòng mã", "—", "EvidencePack", "R0", "T1", "Probe", "—", "UC-F05", "M3", "chưa"),
 ("target.observe", "Chạy kỳ vọng quan sát bằng máy (serial expect, probe, LA, camera)", "expect[]", "evidence", "R0", "T1", "—", "Cần mắt/tay người", "UC-F03", "M2", "chưa"),
])
add("debug", [
 ("debug.log_stats", "Thống kê log lớn (GEditor): mẫu lặp, khoảng thời gian, mức", "file, range?", "stats", "R0", "T1", "—", "—", "UC-F04", "M3", "chưa"),
 ("debug.ask_at", "Hỏi tại dòng: ngữ cảnh = vùng log + stats + hộ chiếu + mã liên quan", "range, q", "Diagnosis", "R0", "T1", "—", "—", "UC-F04", "M3", "chưa"),
 ("debug.hypothesize", "Giả thuyết xếp hạng + thí nghiệm phân biệt", "evidence", "Diagnosis", "R0", "T1", "—", "—", "UC-F05", "M3", "chưa"),
 ("debug.experiment", "Chạy thí nghiệm (probe/test firmware) theo chính sách", "experiment", "evidence", "R3", "T1*", "Board lab", "Không lab", "UC-F05", "M3", "chưa"),
 ("debug.save_session", "Lưu DebugSession gắn fact/mã/log; ghi sổ lỗi", "—", "id", "R1", "T1", "—", "—", "UC-F05", "M3", "chưa"),
 ("debug.propose_fix", "Đề xuất sửa: mã (→ STEP), ràng buộc (→ K6), phần cứng (→ người)", "diagnosis", "proposal", "R0", "T1", "—", "Sửa phần cứng", "UC-F05", "M3", "chưa"),
])
add("measure", [
 ("measure.capture_signal", "sigrok: bắt và decode I2C/SPI/UART", "channels, dur", "dataset", "R0", "T1", "LA nối", "—", "UC-F06", "M5", "chưa"),
 ("measure.power", "INA2xx/PPK2: dòng/năng lượng theo mốc GPIO", "dur", "dataset", "R0", "T1", "—", "—", "UC-F06", "M5", "chưa"),
 ("measure.sync", "Đồng bộ thời gian log ↔ waveform ↔ số đo", "sets", "aligned", "R0", "T1", "—", "—", "UC-F06", "M5", "chưa"),
])
add("bench", [
 ("bench.run", "Chạy bộ tác vụ CF/BF/BC theo mô hình/skill", "isa, models", "report", "R3", "T1", "Board lab", "—", "UC-G01", "M2", "chưa"),
 ("bench.badge", "Gắn huy hiệu verified/bench cho gói", "id, result", "—", "R1", "T1", "—", "—", "UC-G01", "M2", "chưa"),
 ("bench.suggest_skill_fix", "Từ ca lỗi đề xuất sửa skill (chờ Pack owner)", "failures", "proposal", "R1", "T2", "—", "Luôn", "UC-G01", "M2", "chưa"),
])
add("registry", [
 ("registry.search", "Tìm gói theo id/mpn/từ khóa", "q", "packages[]", "R0", "T1", "—", "—", "UC-G03", "M4", "chưa"),
 ("registry.pull", "Kiểm chữ ký; nạp gói vào store; ghim", "id@ver", "—", "R1", "T1", "Chữ ký hợp lệ", "Chưa kiểm định + dự án nhạy cảm", "UC-G03", "M4", "chưa"),
 ("registry.pack", "Đóng gói .hkp (fact + con trỏ nguồn, skill, bench, badge); kiểm license", "id", "file", "R1", "T1", "—", "Thiếu license", "UC-G02", "M4", "chưa"),
 ("registry.publish", "Ký và phát hành (nội bộ tự động; công khai hỏi)", "pkg, scope", "—", "R2/R4", "T1*", "—", "Công khai; chứa K3/K6", "UC-G02", "M4", "chưa"),
 ("registry.seed", "Gieo hạt từ CMSIS-SVD / Microchip packs", "dir", "report", "R1", "T1", "—", "—", "—", "M0", "có"),
])
add("report", [
 ("report.progress", "Báo cáo tiến độ/ngày: việc tự làm, chờ người, chi phí", "—", "md", "R0", "T1", "—", "—", "APD §5", "M1", "chưa"),
 ("report.export", "docx/pdf/md có mục Nguồn", "type, scope", "file", "R1", "T1", "—", "—", "UC-G04", "M4", "chưa"),
 ("report.human_ai_matrix", "Ma trận Người–AI từ ledger", "—", "xlsx", "R0", "T1", "—", "—", "UC-G04", "M4", "chưa"),
 ("report.explain", "Giải thích một quyết định/mã (rationale có trích dẫn)", "id", "text", "R0", "T1", "—", "—", "UR-HT-03", "M2", "chưa"),
])
add("policy", [
 ("policy.decide", "Hàm quyết định theo cổng: APPROVE/ASK/REJECT có lý do", "action, ctx", "decision", "R0", "T1", "—", "—", "APD §4", "M1", "chưa"),
 ("policy.permit", "Quyền theo phiên cho thao tác R3/R4", "op, target", "permission", "R0", "T2", "—", "Luôn (R4)", "UC-F01", "M1", "chưa"),
 ("policy.undo_window", "Theo dõi việc đã tự làm còn trong cửa sổ hoàn tác", "—", "items[]", "R0", "T1", "—", "—", "APD §5", "M1", "chưa"),
 ("policy.escalate", "Leo thang lên người qua hàng đợi/chat/thông báo", "reason", "—", "R0", "T1", "—", "—", "APD §5", "M1", "chưa"),
 ("policy.emergency_stop", "Hạ về A0, hủy thao tác phần cứng đang chờ", "—", "—", "R0", "T3", "—", "—", "APD §5", "M1", "chưa"),
 ("policy.learn_thresholds", "Tổng hợp quyết định của người → đề xuất ngưỡng", "—", "proposal", "R0", "T2", "—", "Luôn", "APD §6", "M2", "chưa"),
 ("policy.set_autonomy", "Đặt mức tự chủ dự án/board", "level", "—", "R1", "T2", "—", "Nới lỏng", "APD §2", "M1", "chưa"),
])
add("chat", [
 ("chat.parse_intent", "Câu lệnh → ý định + tham số (slot); nhận diện lệnh lớn", "text", "intent", "R0", "T1", "—", "—", "DPS-09", "M1", "chưa"),
 ("chat.ground", "Đối chiếu ý định với trạng thái (dự án/hộ chiếu/board tồn tại?)", "intent", "grounded", "R0", "T1", "—", "—", "D1", "M1", "chưa"),
 ("chat.fill_defaults", "Điền ô trống bằng mặc định có căn cứ; ghi ledger", "intent", "intent'", "R0", "T1", "—", "—", "D2", "M1", "chưa"),
 ("chat.clarify", "Một câu hỏi gộp có phương án và mặc định; timeout", "gaps", "answer|default", "R0", "T2", "—", "Khi không có mặc định", "D3", "M1", "chưa"),
 ("chat.restate", "Nói lại ý hiểu 1–2 câu trước chuỗi dài", "plan", "text", "R0", "T1", "—", "—", "D6", "M1", "chưa"),
 ("chat.orchestrate", "Biến lệnh lớn thành chuỗi gọi năng lực có nhánh; chạy theo chính sách", "intent", "run", "R0", "T1", "—", "—", "UC-H01", "M2", "chưa"),
 ("chat.report_back", "Tóm tắt việc đã làm, đang chờ, hoàn tác được, chi phí", "run", "text", "R0", "T1", "—", "—", "APD §5", "M1", "chưa"),
 ("chat.decline", "Nói 'không có trong hộ chiếu'/'không làm được' có lý do và đề xuất", "reason", "text", "R0", "T1", "—", "—", "UC-H04", "M0", "một phần"),
])

# ---- Bổ sung 05/09: kỹ nghệ yêu cầu, kiến trúc, lược đồ, tài liệu ----
add("req", [
 ("req.elicit", "Thu thập yêu cầu từ lệnh NL, tài liệu, ảnh, chat cũ; sinh câu hỏi gộp cho ô trống", "text, sources[]", "RawRequirements", "R0", "T1", "—", "Ô trống không có mặc định", "UC-A01, DPS-09", "M1", "chưa"),
 ("req.classify", "Phân loại FR/NFR/ràng buộc phần cứng/an toàn/thời gian thực; gán mã UR-/FR-", "RawRequirements", "ReqSet", "R0", "T1", "—", "—", "EAA-URD-06", "M1", "chưa"),
 ("req.ground_hw", "Đối chiếu yêu cầu với hộ chiếu chip/board (chân, ngoại vi, RAM/Flash, tần số) → khả thi/không", "ReqSet, passport", "FeasibilityReport", "R0", "T1", "Có hộ chiếu", "Không khả thi trên board đã chọn", "UC-B08, UC-D01", "M1", "chưa"),
 ("req.detect_conflict", "Phát hiện yêu cầu mâu thuẫn/mơ hồ/thiếu định lượng; đề xuất câu chữ đo được", "ReqSet", "Issue[]", "R0", "T1", "—", "Mâu thuẫn không tự giải được", "URD", "M1", "chưa"),
 ("req.prioritize", "Ưu tiên MoSCoW theo mục tiêu dự án và rủi ro phần cứng", "ReqSet", "ReqSet'", "R0", "T1*", "—", "Đổi ưu tiên M↔S", "URD", "M1", "chưa"),
 ("req.trace_matrix", "Ma trận truy vết UR→FR→thiết kế→mã→test; phát hiện lỗ hổng", "project", "TraceMatrix (xlsx/md)", "R0", "T1", "—", "—", "STP-05", "M2", "chưa"),
 ("req.acceptance", "Sinh tiêu chí chấp nhận/kịch bản kiểm thử từ yêu cầu (Given-When-Then)", "ReqSet", "AC[]", "R0", "T1", "—", "—", "STP-05", "M2", "chưa"),
 ("req.change_impact", "Đánh giá tác động khi đổi yêu cầu: module, fact, test, tài liệu bị ảnh hưởng", "delta", "ImpactReport", "R0", "T1", "KG dự án", "Tác động > ngưỡng", "kg.impact", "M2", "chưa"),
])
add("arch", [
 ("arch.style_select", "Chọn kiểu kiến trúc firmware (super-loop, event-driven, RTOS, layered/HAL) theo yêu cầu và tài nguyên chip", "ReqSet, passport", "ArchDecision", "R1", "T1*", "Hộ chiếu + NFR", "Đổi kiểu kiến trúc dự án đã có", "SAD-03", "M2", "chưa"),
 ("arch.decompose", "Phân rã hệ thống thành module/lớp/thành phần với trách nhiệm, giao diện, phụ thuộc", "ReqSet, ArchDecision", "ModuleGraph", "R1", "T1", "—", "—", "SAD-03", "M2", "chưa"),
 ("arch.map_hw", "Gán module ↔ ngoại vi/chân/ngắt/DMA/timer; kiểm xung đột tài nguyên", "ModuleGraph, passport", "HwMap", "R1", "T1", "Hộ chiếu", "Xung đột chân/timer không tự giải", "board.pin_plan", "M2", "chưa"),
 ("arch.memory_budget", "Ngân sách RAM/Flash/stack/heap theo module; cảnh báo vượt", "ModuleGraph, passport", "MemBudget", "R0", "T1", "—", "Vượt ngân sách", "SDD-04", "M2", "chưa"),
 ("arch.timing_budget", "Ngân sách thời gian thực: chu kỳ, WCET ước lượng, ưu tiên ngắt/task", "ModuleGraph", "TimingBudget", "R0", "T1", "—", "Deadline không đạt", "SDD-04", "M2", "chưa"),
 ("arch.interface_spec", "Đặc tả API/giao thức giữa module (chữ ký, message, lỗi, trạng thái)", "ModuleGraph", "InterfaceSpec[]", "R0", "T1", "—", "—", "SDD-04", "M2", "chưa"),
 ("arch.state_machine", "Thiết kế máy trạng thái cho module/thiết bị; kiểm tính đầy đủ chuyển trạng thái", "module", "FSM", "R0", "T1", "—", "—", "SDD-04", "M2", "chưa"),
 ("arch.adr", "Ghi Architecture Decision Record: bối cảnh, phương án, quyết định, hệ quả, fact trích dẫn", "decision", "ADR (md)", "R0", "T1", "—", "—", "SAD-03", "M2", "chưa"),
 ("arch.review", "Rà kiến trúc theo checklist nhúng (coupling, ISR ngắn, lock, watchdog, bảo mật) → phát hiện", "ModuleGraph", "Findings[]", "R0", "T1", "—", "—", "BPD-06", "M2", "chưa"),
 ("arch.compare", "So sánh 2–3 phương án kiến trúc theo tiêu chí có trọng số; đề xuất có lý do", "options[]", "Comparison", "R0", "T1*", "—", "Chọn phương án cuối", "SAD-03", "M2", "chưa"),
 ("arch.to_plan", "Chuyển kiến trúc thành kế hoạch hiện thực theo mốc; nối plan.create", "ModuleGraph", "Plan", "R1", "T1", "—", "—", "plan.create", "M2", "chưa"),
])
add("diagram", [
 ("diagram.render", "Vẽ lược đồ từ ngôn ngữ GEditor đã hỗ trợ (Mermaid, PlantUML, Graphviz/DOT, D2, WaveDrom, SVG); xem trong GEditor", "src, lang", "svg/png", "R0", "T1", "—", "—", "FR-UI-*", "M1", "chưa"),
 ("diagram.block", "Sơ đồ khối hệ thống/board từ BOM + netlist (khối, bus, nguồn)", "board, BOM", "Mermaid/DOT", "R0", "T1", "Có BOM/netlist", "—", "extract.bom", "M1", "chưa"),
 ("diagram.pinmap", "Sơ đồ chân/kết nối module ↔ chip từ HwMap; bảng chân kèm theo", "HwMap", "svg + table", "R0", "T1", "Hộ chiếu", "—", "arch.map_hw", "M2", "chưa"),
 ("diagram.architecture", "Sơ đồ kiến trúc phần mềm (lớp, module, phụ thuộc, luồng dữ liệu) theo C4 hoặc layered", "ModuleGraph", "Mermaid/PlantUML/D2", "R0", "T1", "—", "—", "arch.decompose", "M2", "chưa"),
 ("diagram.sequence", "Sơ đồ tuần tự cho kịch bản/UC (ISR, task, giao tiếp ngoại vi)", "scenario", "Mermaid/PlantUML", "R0", "T1", "—", "—", "SDD-04", "M2", "chưa"),
 ("diagram.state", "Sơ đồ trạng thái từ FSM; đồng bộ hai chiều với mã máy trạng thái", "FSM", "Mermaid/PlantUML", "R0", "T1", "—", "—", "arch.state_machine", "M2", "chưa"),
 ("diagram.flow", "Lưu đồ thuật toán/luồng nghiệp vụ; sinh từ mã C hoặc từ mô tả", "code|text", "Mermaid/DOT", "R0", "T1", "—", "—", "SDD-04", "M2", "chưa"),
 ("diagram.timing", "Giản đồ thời gian/tín hiệu (WaveDrom) từ timing của datasheet hoặc capture logic", "timing facts|capture", "WaveDrom", "R0", "T1", "Fact có nguồn", "—", "extract.timing", "M2", "chưa"),
 ("diagram.memory_map", "Sơ đồ bản đồ bộ nhớ/thanh ghi từ hộ chiếu và linker script", "passport, ld", "svg", "R0", "T1", "Hộ chiếu", "—", "passport.query", "M2", "chưa"),
 ("diagram.kg_view", "Vẽ lát cắt đồ thị tri thức (fact, nguồn, mâu thuẫn, tác động) theo truy vấn", "query", "DOT/svg", "R0", "T1", "—", "—", "kg.neighborhood", "M1", "một phần"),
 ("diagram.gantt", "Sơ đồ Gantt/mốc từ Plan; cập nhật theo tiến độ", "Plan", "Mermaid gantt", "R0", "T1", "—", "—", "plan.create", "M2", "chưa"),
 ("diagram.from_image", "Nhận dạng sơ đồ trong ảnh (schematic, sơ đồ vẽ tay) → mã lược đồ chỉnh sửa được", "image", "Mermaid/DOT", "R0", "T1", "—", "Độ tin cậy thấp", "extract.image", "M3", "chưa"),
 ("diagram.lint", "Kiểm cú pháp/tính nhất quán lược đồ (nút mồ côi, tên không khớp mã)", "src", "Issue[]", "R0", "T1", "—", "—", "—", "M1", "chưa"),
 ("diagram.sync", "Đồng bộ lược đồ ↔ mã/kiến trúc khi một bên đổi; cảnh báo lệch", "src, code", "diff", "R0", "T1*", "—", "Lệch lớn", "arch.decompose", "M3", "chưa"),
])
add("doc", [
 ("doc.generate", "Sinh tài liệu theo chuẩn bộ EAA/EIDE (URD, SRS, SAD, SDD, STP, BPD…) từ tri thức dự án; thuộc tính, lịch sử, mục Nguồn", "type, scope", "docx/md", "R1", "T1", "Fact có nguồn", "Thiếu fact bắt buộc", "report.export", "M2", "chưa"),
 ("doc.section", "Viết/viết lại một mục (mô tả module, hướng dẫn cấu hình, ghi chú phát hành)", "target, style", "md", "R0", "T1", "—", "—", "—", "M1", "chưa"),
 ("doc.api_ref", "Sinh tham chiếu API từ header/Doxygen; ví dụ dùng theo hộ chiếu", "src", "md/html", "R0", "T1", "—", "—", "code.module", "M2", "chưa"),
 ("doc.datasheet_summary", "Tóm tắt datasheet/errata cho phần dự án dùng, có trích dẫn trang", "part, scope", "md", "R0", "T1", "Fact có nguồn", "—", "extract.pdf", "M1", "chưa"),
 ("doc.bringup_guide", "Hướng dẫn bring-up board: nguồn, nạp, kiểm tra bước đầu, lỗi thường gặp", "board", "md", "R0", "T1", "—", "—", "UC-F02", "M2", "chưa"),
 ("doc.test_report", "Báo cáo kiểm thử từ kết quả sim/target/bench với bằng chứng", "results", "docx/md", "R0", "T1", "—", "—", "STP-05", "M2", "chưa"),
 ("doc.embed_diagram", "Chèn lược đồ (diagram.*) vào tài liệu với chú thích, đánh số hình", "doc, diagram", "doc'", "R0", "T1", "—", "—", "diagram.render", "M2", "chưa"),
 ("doc.style_check", "Kiểm tài liệu theo chuẩn: tiếng Việt ưu tiên, thuật ngữ có giải nghĩa, mọi khẳng định có nguồn, định dạng bộ tài liệu", "doc", "Issue[]", "R0", "T1", "—", "—", "BPD-06", "M1", "chưa"),
 ("doc.translate", "Dịch tài liệu Việt↔Anh giữ thuật ngữ và bố cục", "doc, lang", "doc'", "R0", "T1", "—", "—", "—", "M3", "chưa"),
 ("doc.changelog", "Sinh changelog/ghi chú phát hành từ commit và ledger", "range", "md", "R0", "T1", "—", "—", "code.merge", "M2", "chưa"),
 ("doc.slides", "Sinh bộ slide trình bày dự án/đề án từ tài liệu và lược đồ", "scope", "pptx", "R0", "T1", "—", "—", "—", "M3", "chưa"),
 ("doc.sync", "Cập nhật tài liệu khi mã/kiến trúc/fact đổi; đánh dấu mục lỗi thời", "delta", "doc diff", "R0", "T1*", "—", "Thay đổi lớn", "req.change_impact", "M3", "chưa"),
])

# ---- Bổ sung 05/09 (2): hiển thị bản đồ tri thức & RAG; dò tìm board/kết nối ----
add("view", [
 ("view.kg_map", "Hiển thị bản đồ tri thức toàn dự án: chip/board/module/fact/nguồn; tô màu theo tier, trạng thái, mâu thuẫn; zoom/lọc/tìm", "project, filter?", "interactive graph (GEditor panel)", "R0", "T1", "—", "—", "UC-B15, FR-UI-*", "M1", "một phần (kg CLI)"),
 ("view.kg_focus", "Bản đồ lân cận từ một nút (thanh ghi, chân, module) với đường dẫn tới nguồn và mã dùng nó", "node, depth", "subgraph view", "R0", "T1", "—", "—", "kg.neighborhood", "M1", "chưa"),
 ("view.provenance", "Xem chuỗi nguồn gốc của một fact: tài liệu → trang/locator → trích đoạn → supersede/conflict; mở đúng trang PDF", "fact_id", "provenance panel", "R0", "T1", "—", "—", "KAD-07", "M1", "chưa"),
 ("view.conflict_board", "Bảng mâu thuẫn/chờ duyệt/đã thay thế; thao tác duyệt ngay trên bảng", "project", "board view", "R0", "T1", "—", "—", "UC-B10, UC-C01", "M1", "chưa"),
 ("view.coverage_map", "Bản đồ độ phủ tri thức: ngoại vi/thanh ghi/chân nào đã có fact, đang thiếu, đang được yêu cầu", "passport", "heatmap", "R0", "T1", "—", "—", "search.missing", "M2", "chưa"),
 ("view.impact_map", "Bản đồ tác động khi fact/yêu cầu đổi: module, test, tài liệu bị ảnh hưởng", "delta", "graph view", "R0", "T1", "—", "—", "kg.impact, req.change_impact", "M2", "chưa"),
 ("view.rag_ask", "Hỏi–đáp RAG trên toàn kho tài liệu dự án (PDF, ảnh OCR, mã, chat); trả lời có trích dẫn nhấp mở nguồn", "question, scope", "answer + citations[]", "R0", "T1", "Chỉ nguồn trong phạm vi", "—", "memory.retrieve", "M1", "chưa"),
 ("view.rag_trace", "Hiển thị lý do trả lời: đoạn văn bản được truy hồi, điểm số, đường lan tỏa trên đồ thị (Graph-RAG)", "answer_id", "trace panel", "R0", "T1", "—", "—", "memory.retrieve", "M1", "chưa"),
 ("view.rag_index", "Xây/cập nhật chỉ mục RAG (chunk, embedding, chỉ mục từ khóa + đồ thị) cho tài liệu mới nạp; báo tiến độ", "sources[]", "index status", "R1", "T1", "—", "—", "archive.ingest", "M1", "chưa"),
 ("view.rag_compare", "So sánh câu trả lời theo nhiều nguồn (datasheet vs errata vs cộng đồng) và chỉ ra chỗ khác nhau", "question", "comparison", "R0", "T1", "—", "—", "kg.conflicts", "M2", "chưa"),
 ("view.doc_side_by_side", "Xem tài liệu gốc cạnh fact/mã đã trích: bôi sáng vùng nguồn trong PDF/ảnh", "fact_id|code_unit", "split view", "R0", "T1", "—", "—", "extract.pdf", "M1", "chưa"),
 ("view.timeline", "Dòng thời gian tri thức/quyết định: fact nhập, supersede, gate, merge, nạp — lọc theo ngày/người/AI", "range", "timeline", "R0", "T1", "—", "—", "memory.ledger", "M2", "chưa"),
 ("view.export_map", "Xuất bản đồ tri thức ra DOT/GraphML/SVG/PNG hoặc mã Mermaid để chèn tài liệu", "view, format", "file", "R0", "T1", "—", "—", "diagram.kg_view", "M1", "chưa"),
])
add("discover", [
 ("discover.ports", "Liệt kê cổng USB/serial/JTAG-SWD đang cắm; VID/PID, driver, quyền truy cập", "—", "ports[]", "R0", "T1", "—", "—", "UC-F02", "M2", "chưa"),
 ("discover.probe", "Dò debug probe (ST-Link, J-Link, CMSIS-DAP, PICkit, AVRISP, ESP USB-JTAG, FTDI); phiên bản firmware; đề xuất cập nhật", "—", "probes[]", "R0", "T1", "—", "—", "UC-F02", "M2", "chưa"),
 ("discover.chip_id", "Đọc ID chip qua probe/bootloader (IDCODE, DEVICE_ID, signature bytes, JEDEC); đối chiếu hộ chiếu", "probe", "chip identity", "R0", "T1", "Probe kết nối", "ID không khớp hộ chiếu", "target.detect", "M2", "chưa"),
 ("discover.board_match", "Nhận diện board từ chip ID + ngoại vi phản hồi (I2C scan, GPIO) + ảnh/BOM; xếp hạng ứng viên trong registry/web", "evidence", "candidates[]", "R0", "T1*", "—", "Nhiều ứng viên điểm gần nhau", "board.build_passport, search.web", "M2", "chưa"),
 ("discover.bus_scan", "Quét bus I2C/SPI/1-Wire/CAN tìm thiết bị đang có; đối chiếu địa chỉ với BOM", "bus", "devices[]", "R1", "T1", "Board lab", "Board không lab", "UC-F03", "M3", "chưa"),
 ("discover.link_speed", "Dò tốc độ kết nối tối ưu: baud serial (auto-baud), SWD/JTAG clock, SPI/I2C clock; thử nấc và đo lỗi", "port|probe", "speed + error rate", "R1", "T1", "—", "Thử nấc vượt datasheet", "target.serial", "M2", "chưa"),
 ("discover.clock_measure", "Đo tần số thực của chip/bus (qua probe timestamp, LA, hoặc firmware đo) để đối chiếu cấu hình clock", "target", "measured clocks", "R1", "T1", "Board lab", "—", "measure.*", "M3", "chưa"),
 ("discover.power", "Đọc điện áp/dòng cấp (nếu probe/board hỗ trợ) và cảnh báo bất thường trước khi nạp", "target", "power status", "R0", "T1", "—", "Bất thường", "UC-F02", "M3", "chưa"),
 ("discover.firmware_probe", "Nhận diện firmware đang chạy trên board (banner serial, bootloader, phiên bản) để quyết định nạp lại hay tái dùng", "port", "fw identity", "R0", "T1", "—", "—", "target.serial", "M2", "chưa"),
 ("discover.network", "Dò thiết bị nhúng trên mạng LAN (mDNS, OTA endpoint, IP cố định) cho board có Wi-Fi/Ethernet", "subnet?", "devices[]", "R0", "T1", "—", "Quét ngoài mạng lab", "UC-F02", "M3", "chưa"),
 ("discover.env_hw", "Tóm tắt phần cứng máy phát triển: OS, cổng, driver thiếu, quyền (udev/driver ký) → đề xuất sửa", "—", "report", "R0", "T1", "—", "Cài driver (R2)", "env.check", "M2", "chưa"),
 ("discover.auto_setup", "Từ kết quả dò: chọn adapter ISA, cấu hình openocd/probe-rs/esptool, tốc độ, cổng; ghi vào dự án", "discover results", "target config", "R1", "T1", "Có ID chip khớp", "ID không khớp", "target.detect", "M2", "chưa"),
])

# ---- Bổ sung 05/09 (3): năng lực tự tạo công cụ (self-tooling) — năng lực gốc sinh ra năng lực khác ----
add("tool", [
 ("tool.need", "Nhận diện nhu cầu công cụ mới: khi chuỗi thiếu năng lực phù hợp hoặc năng lực hiện có không đủ, mô tả nhu cầu thành đặc tả công cụ (vào/ra/hiệu ứng)", "gap, context", "ToolSpec", "R0", "T1", "Không có năng lực nào khớp ≥ ngưỡng", "—", "DPS-09 §4.4", "M1", "chưa"),
 ("tool.search", "Tìm công cụ đã có (do tác tử tự viết trước đó, trong dự án/người dùng/registry) khớp đặc tả để tái dùng thay vì viết mới", "ToolSpec", "tools[]", "R0", "T1", "—", "—", "memory M5", "M1", "chưa"),
 ("tool.write", "Tự viết công cụ bằng Python theo ToolSpec: hàm thuần có chữ ký, docstring, kiểm tham số, xử lý lỗi, không tác dụng phụ ngoài hiệu ứng khai báo; kèm test", "ToolSpec", "ToolCode + tests", "R2", "T1", "ToolSpec đầy đủ", "Hiệu ứng khai báo gồm mạng/phần cứng/sudo", "PRS-16 coder", "M1", "chưa"),
 ("tool.test", "Chạy test của công cụ trong sandbox (không mạng, không phần cứng); kiểm hiệu ứng thực tế khớp khai báo (giám sát syscall/ghi tệp)", "ToolCode", "ToolReport", "R0", "T1", "—", "—", "SEC-25 §2", "M1", "chưa"),
 ("tool.run", "Thực thi công cụ trong sandbox với giới hạn theo hiệu ứng khai báo; chính sách quyết định theo lớp rủi ro suy ra từ hiệu ứng (đọc R0, ghi dự án R2, mạng R1, phần cứng R3, hệ thống R4)", "tool_id, args", "result + ToolReport", "R2", "T1*", "Đã test đạt", "Hiệu ứng ngoài khai báo; R3/R4", "POL-17 TOOL-*", "M1", "chưa"),
 ("tool.register", "Đăng ký công cụ thành năng lực tạm (namespace user.*) trong Capability Registry với hợp đồng 13 trường suy ra từ ToolSpec; gọi được từ chuỗi/UI/MCP như mọi năng lực", "tool_id", "capability code", "R1", "T1", "test đạt", "—", "SDD-04 §4.0", "M1", "chưa"),
 ("tool.repair", "Sửa công cụ khi thất bại (ToolReport/lỗi runtime) ≤ 3 vòng; ghi sổ lỗi", "tool_id, report", "ToolCode'", "R2", "T1", "—", "—", "code.self_repair", "M1", "chưa"),
 ("tool.promote", "Thăng công cụ tạm thành năng lực chính thức (namespace chuẩn) sau khi dùng ≥ n lần thành công và benchmark; đóng gói vào registry (K5 thủ tục); Pack owner duyệt", "tool_id", "PR/pack", "R1", "T2", "Dùng ≥ 3 lần, 0 lỗi", "Luôn", "registry.pack", "M2", "chưa"),
 ("tool.compose", "Ghép nhiều công cụ/năng lực thành công cụ mới (pipeline) không cần viết mã; khai báo hiệu ứng = hợp hiệu ứng thành phần", "tool_ids[], wiring", "ToolSpec + code", "R1", "T1", "—", "—", "chat.orchestrate", "M2", "chưa"),
 ("tool.deprecate", "Vô hiệu hóa công cụ lỗi/không dùng; giữ lịch sử; thay thế bằng năng lực chính thức khi có", "tool_id, reason", "—", "R1", "T1", "—", "—", "—", "M2", "chưa"),
])
