import Foundation

/// Bảng dịch tiếng Anh. Xem `Localization.swift` để biết vì sao khoá là chính chuỗi tiếng Việt.
///
/// Mỗi ngôn ngữ MỘT tệp. Không phải để cho gọn mắt: 1010 mục kiểm kiểu hết 0,68 s, và ba mươi
/// bảng nằm chung một tệp là hai mươi giây cộng vào mọi lượt biên dịch, không chia được cho
/// nhiều nhân. Tách ra thì mỗi tệp là một đơn vị biên dịch, chạy song song, và sửa một ngôn ngữ
/// không bắt hai mươi chín bảng kia dịch lại.
extension L10n {

    static let en: [String: String] = [
        // --- Menu ứng dụng ---
        // Bản đã lưu (FR-DOC-305)
        "Bản đã lưu…": "Saved versions…",
        "Tài liệu chưa lưu lần nào — chưa có lịch sử": "This document has never been saved — no history yet",
        "Chưa có bản đã lưu nào trước đó": "No earlier saved versions",
        "Không đọc được bản ấy": "Cannot read that version",
        "Khôi phục bản đã lưu": "Restore saved version",

        // XML: kiểm theo DTD/XSD (FR-FMT-505)
        "XML: kiểm theo DTD/XSD…": "XML: validate against DTD/XSD…",
        "Máy này không có libxml2 nên không kiểm được XSD.":
            "This Mac has no libxml2, so XSD validation is unavailable.",
        "Chọn lược đồ XSD để kiểm": "Choose an XSD schema to validate against",
        "Hợp lệ theo": "Valid against",

        // Plugin native (FR-PLUG-702/703/704)
        "Plugin chạy xong, không đổi gì": "The plug-in finished without changing anything",
        "Chưa cài plugin native nào": "No native plug-ins installed",
        "Gỡ plugin này": "Remove this plug-in",
        "Gỡ plugin này?": "Remove this plug-in?",
        "Gỡ": "Remove",
        "Cài plugin native…": "Install a native plug-in…",
        "Mở thư mục plugin": "Open the plug-in folder",
        "Chọn file .dylib của plugin native": "Choose the plug-in's .dylib file",
        "Đã cài:": "Installed:",
        "Đã gỡ:": "Removed:",
        "Plugin native…": "Native plug-ins…",
        "Chỉ nhận file .dylib.": "Only .dylib files are accepted.",
        "Đã có một plugin trùng tên:": "A plug-in with the same name is already installed:",
        "Không chép được plugin:": "Cannot copy the plug-in:",
        "Plugin native chỉ có ở bản tải trực tiếp, không có ở bản App Store.":
            "Native plug-ins are available only in the direct download, not in the App Store build.",
        "Không tìm thấy tiến trình phụ chạy plugin.": "Cannot find the plug-in helper process.",
        "Không khởi động được tiến trình phụ:": "Cannot start the plug-in helper process:",
        "Tiến trình plugin đã dừng giữa chừng.": "The plug-in process stopped unexpectedly.",
        "Plugin không trả lời kịp — đã dừng nó.": "The plug-in did not answer in time — it was stopped.",
        "Plugin trả lời sai giao thức:": "The plug-in replied with a malformed message:",
        "Plugin báo lỗi:": "The plug-in reported an error:",

        "Về GEditor": "About GEditor",
        "Cài đặt…": "Settings…",
        "Thoát GEditor": "Quit GEditor",

        // --- File ---
        "File": "File",
        "Tab mới": "New Tab",
        "Đóng tab": "Close Tab",
        "Tab kế": "Next Tab",
        "Tab trước": "Previous Tab",
        "Tài liệu mới": "New Document",
        "Mở…": "Open…",
        "Mở thư mục làm Workspace…": "Open Folder as Workspace…",
        "Mở gần đây": "Open Recent",
        "Lưu": "Save",
        "Lưu thành…": "Save As…",
        "Cắt khoảng trắng cuối dòng khi lưu": "Trim Trailing Whitespace on Save",
        "Theo dõi file (tail -f)": "Follow File (tail -f)",
        "In…": "Print…",
        "Mở lại tab vừa đóng": "Reopen Last Closed Tab",
        "Chưa có file nào": "No recent files",
        "Xoá danh sách": "Clear Menu",

        // --- Edit ---
        "Edit": "Edit",
        "Hoàn tác": "Undo",
        "Làm lại": "Redo",
        "Cắt": "Cut",
        "Sao chép": "Copy",
        "Dán": "Paste",
        "Lịch sử clipboard…": "Clipboard History…",
        "Column Editor…": "Column Editor…",
        "Chọn lần kế tiếp": "Select Next Occurrence",
        "Chọn tất cả": "Select All",
        "Nhân đôi dòng": "Duplicate Line",
        "Xóa dòng": "Delete Line",
        "Comment dòng": "Toggle Comment",
        "Chưa chép gì trong phiên này": "Nothing copied yet",
        "Xoá lịch sử": "Clear History",

        // --- Search ---
        "Search": "Search",
        "Tìm…": "Find…",
        "Tìm và thay…": "Find and Replace…",
        "Tìm trong thư mục…": "Find in Folder…",
        "Thay trong thư mục…": "Replace in Folder…",
        "Kết quả kế": "Next Result",
        "Kết quả trước": "Previous Result",
        "Đi tới dòng…": "Go to Line…",
        "Nhảy tới ngoặc khớp": "Jump to Matching Bracket",
        "Đánh dấu mọi dòng khớp…": "Mark All Matching Lines…",
        "Đảo dấu": "Invert Marks",
        "Bỏ mọi dấu": "Clear All Marks",
        "Chép dòng đã đánh dấu": "Copy Marked Lines",
        "Xóa dòng đã đánh dấu": "Delete Marked Lines",
        "Chỉ giữ dòng đã đánh dấu": "Keep Only Marked Lines",

        // --- Lines ---
        "Lines": "Lines",
        "Sắp xếp A→Z": "Sort A→Z",
        "Sắp xếp Z→A": "Sort Z→A",
        "Sắp xếp tự nhiên": "Natural Sort",
        "Khử trùng lặp": "Remove Duplicates",
        "Đảo thứ tự dòng": "Reverse Lines",
        "Dời dòng lên": "Move Lines Up",
        "Dời dòng xuống": "Move Lines Down",
        "Ghép dòng": "Join Lines",
        "Tách dòng theo độ dài…": "Split Lines by Length…",
        "Tách dòng theo ký tự…": "Split Lines by Character…",
        "Xóa dòng rỗng": "Remove Blank Lines",
        "Nén dòng trống liên tiếp": "Squeeze Blank Lines",
        "Cắt khoảng trắng cuối dòng": "Trim Trailing Whitespace",
        "Tab → Space": "Tab → Space",
        "Space → Tab": "Space → Tab",
        "HOA": "UPPERCASE",
        "thường": "lowercase",
        "Chữ Hoa Đầu Từ": "Title Case",
        "Chữ hoa đầu câu": "Sentence case",
        "Đảo hoa/thường": "iNVERT cASE",
        "camelCase": "camelCase",
        "snake_case": "snake_case",
        "kebab-case": "kebab-case",

        // --- CSV ---
        "CSV": "CSV",
        "CSV: chọn sheet…": "CSV: Choose Sheet…",
        "Xem dạng bảng / văn bản": "Toggle Table / Text View",
        "Xóa cột…": "Delete Column…",
        "Kiểm tra dữ liệu (số cột · kiểu)": "Validate Data (columns · types)",
        "Bàn làm sạch dữ liệu…": "Data Clean-up Bench…",
        "Chạy công thức làm sạch…": "Run Cleaning Recipe…",
        "Chuyển đổi…": "Convert…",
        "Đổi dấu phân tách…": "Change Delimiter…",
        "Xuất sang JSON…": "Export to JSON…",

        // --- Format ---
        "Format": "Format",
        "Bảng mã…": "Encoding…",
        "Xuống dòng…": "Line Endings…",
        "Chuẩn hóa Unicode…": "Normalize Unicode…",
        "JSON: định dạng lại": "JSON: Format",
        "JSON: thu gọn một dòng": "JSON: Minify",
        "JSON: sắp xếp khóa": "JSON: Sort Keys",
        "JSON: truy vấn JSONPath…": "JSON: JSONPath Query…",
        "CSV: truy vấn SQL…": "CSV: SQL Query…",
        "Truy vấn SQL": "SQL Query",
        "Đang chạy…": "Running…",
        "Xuất ra tab mới": "Export to New Tab",
        "Tài liệu rỗng — không có bảng để truy vấn": "Empty document — no table to query",
        "Không nhận ra bảng CSV — dòng đầu chỉ có một cột":
            "Not a CSV table — the first row has only one column",
        "Không đọc được câu truy vấn": "Could not read the query",
        "Không kiểm được câu truy vấn": "Could not check the query",
        // Panel CSV, Column Editor, script (FR-UI-804).
        "Vàng (mặc định)": "Yellow (default)",
        "Xanh dương": "Blue",
        "Xanh lá": "Green",
        "Vàng đất": "Ochre",
        "Tím": "Purple",
        "Hồng": "Pink",
        "Xanh ngọc": "Teal",
        "Cam": "Orange",
        "Xám lam": "Slate",
        "Văn bản": "Text",
        "Dãy số": "Number series",
        "Dãy ngày": "Date series",
        "Chữ HOA (hex)": "Uppercase (hex)",
        "Bắt đầu": "Start",
        "Bước": "Step",
        "Đệm 0 tới": "Pad zeros to",
        "Hệ": "Base",
        "Ngày đầu": "First date",
        "Định dạng": "Format",
        "Chèn": "Insert",
        "Huỷ": "Cancel",
        "Chuyển đổi định dạng": "Convert format",
        "Xem trước 5 hàng đầu": "Preview first 5 rows",
        "Tạo tab mới": "Open in new tab",
        "Lưu ra file…": "Save to file…",
        "Kết quả mở thành tab mới, chưa lưu. Tài liệu gốc không đổi.": "The result opens in a new, unsaved tab. The original document is untouched.",
        "Chạy trên tài liệu này": "Run on this document",
        "Chạy trên thư mục…": "Run on a folder…",
        "Cả công thức là MỘT bước undo. Tài liệu gốc trên đĩa không đổi cho tới khi anh lưu.": "The whole recipe is ONE undo step. The file on disk is untouched until you save.",
        "tắt": "off",
        "không thấy cột": "column not found",
        "sẵn sàng": "ready",
        "nó vẫn chiếm một lõi CPU cho tới khi thoát ứng dụng.": "it keeps using a CPU core until the app quits.",
        "Script không trả về gì": "The script returned nothing",
        "Không dựng được máy JavaScript": "Could not create the JavaScript engine",
        "Lỗi JavaScript không rõ": "Unknown JavaScript error",
        "Bảng": "Table",
        "Áp sắp xếp vào file": "Apply sort to file",
        "Chuyển đổi ▾": "Convert ▾",
        "Xuất dòng khớp": "Export matching rows",
        "Ẩn cột này": "Hide this column",
        "Đổi tên tiêu đề…": "Rename header…",
        "Chèn cột trống bên trái": "Insert empty column on the left",
        "Chèn cột trống bên phải": "Insert empty column on the right",
        "Xóa cột này khỏi file…": "Delete this column from the file…",
        "Phải còn ít nhất một cột đang hiện": "At least one column must stay visible",
        "Đang sắp xếp…": "Sorting…",
        "Trở về thứ tự trong file": "Back to file order",
        // Menu cú pháp của panel SQL (FR-CSV-407).
        "trăm hàng đầu": "first hundred rows",
        "chọn cột": "pick columns",
        "đặt tên cột kết quả": "name a result column",
        "lọc theo chữ": "filter by text",
        "ô rỗng": "empty cells",
        "ghép điều kiện": "combine conditions",
        "đếm hàng": "count rows",
        "gộp nhóm": "group and aggregate",
        "nhỏ nhất, lớn nhất": "minimum, maximum",
        "sắp xếp và cắt": "sort and limit",
        "tên cột có dấu cách": "column name with spaces",
        "Truy vấn bị dừng giữa chừng": "Query was interrupted",
        "Chưa làm: JOIN · truy vấn con · HAVING · DISTINCT · LIKE · IN · BETWEEN · UNION · cửa sổ hàm":
            "Not supported: JOIN · subquery · HAVING · DISTINCT · LIKE · IN · BETWEEN · UNION · window functions",
        "XML: định dạng lại": "XML: Format",
        "XML: thu gọn một dòng": "XML: Minify",
        "XML: kiểm cú pháp": "XML: Check Syntax",
        "YAML: kiểm khóa trùng và thụt lề": "YAML: Lint Keys and Indentation",

        // --- View ---
        "View": "View",
        "Ẩn/hiện sidebar (Function List)": "Toggle Sidebar (Function List)",
        "Ẩn/hiện bản đồ tài liệu": "Toggle Document Map",
        "Gấp / mở khối tại con nháy": "Fold / Unfold at Cursor",
        "Gấp tất cả": "Fold All",
        "Bỏ gấp tất cả": "Unfold All",
        // FR-FMT-503 vế "fold theo cấp". "Cấp %d" là chuỗi ĐỊNH DẠNG: nhan đề mục menu dựng
        // bằng `String(format:)` nên bài kiểm dịch (vốn tra ngược NGUYÊN nhan đề) không thấy
        // được nó — chỗ giữ nó là dòng này.
        "Gấp theo cấp": "Fold Level",
        "Cấp %d": "Level %d",
        "Đã gấp %d khối ở cấp %d": "Folded %d {one=block|other=blocks} at level %d",
        "Tài liệu này chỉ sâu %d cấp": "This document is only %d {one=level|other=levels} deep",
        "mermaid: không đọc được bản kê": "mermaid: manifest unreadable",
        // NFR-SEC-01 — kênh tự cập nhật.
        "Kiểm tra bản cập nhật…": "Check for Updates…",
        "Kiểm tra bản cập nhật": "Check for Updates",
        // "Đóng" đã có sẵn ở bảng trên — cổng tĩnh `check-core-no-ui.sh` bắt khoá trùng, nhưng
        // ở lần này chính `Dictionary` literal sập trước lúc chạy tới cổng. Cả hai đều bắt được;
        // cái sập nhanh hơn.
        "Bản App Store cập nhật qua Mac App Store, không qua GEditor.":
            "App Store builds update through the Mac App Store, not through GEditor.",
        "Bản dựng này chưa có khoá ký cập nhật nên không kiểm tra được.":
            "This build has no update signing key, so it cannot check for updates.",
        "Phóng to chữ": "Zoom In",
        "Thu nhỏ chữ": "Zoom Out",
        "Cỡ chữ gốc": "Actual Size",
        "Chia đôi theo chiều dọc": "Split Vertically",
        "Chia đôi theo chiều ngang": "Split Horizontally",
        "Bỏ chia đôi": "Close Split",
        "Mở tab này ở nửa kia": "Open Tab in Other Pane",
        "Nhảy sang nửa kia": "Focus Other Pane",
        "Ngắt dòng (tắt / cửa sổ / cột)": "Word Wrap (off / window / column)",
        "Ngắt dòng tại cột…": "Wrap at Column…",
        "Đánh dấu dòng này": "Toggle Bookmark",
        "Dấu kế tiếp": "Next Bookmark",
        "Dấu trước đó": "Previous Bookmark",
        "Màu đánh dấu…": "Bookmark Color…",
        "Hiện tất cả ký tự ẩn": "Show All Invisibles",
        "  Khoảng trắng": "  Spaces",
        "  Tab": "  Tabs",
        "  Xuống dòng": "  Line Endings",
        "  NBSP · zero-width · điều khiển": "  NBSP · zero-width · control",
        "Xem nhị phân": "Binary View",
        "Chế độ CSV (tô màu theo cột)": "CSV Mode (rainbow columns)",

        // --- Macro ---
        "Macro": "Macro",
        "Bắt đầu / dừng ghi": "Start / Stop Recording",
        "Phát lại": "Play",
        "Phát nhiều lần…": "Play Multiple Times…",
        "Phát đến cuối tài liệu": "Play to End of Document",
        "Chạy trên mọi tab": "Run on All Tabs",
        "Hủy macro đang chạy": "Cancel Running Macro",
        "Lưu macro…": "Save Macro…",
        "Macro đã lưu…": "Saved Macros…",

        // --- Help ---
        "Help": "Help",
        "Trợ giúp GEditor": "GEditor Help",
        "Giới thiệu tính năng": "Feature Tour",
        "Di cư từ Notepad++": "Migrating from Notepad++",

        // --- Panel Tìm ---
        "Tìm": "Find",
        "Thay bằng": "Replace with",
        "Kế": "Next",
        "Trước": "Previous",
        "Đếm": "Count",
        "Đóng": "Close",

        // --- Kiểm theo JSON Schema (FR-KNW-909) ---
        "Kiểm theo JSON Schema…": "Validate against a JSON Schema…",
        "Chọn tệp JSON Schema": "Choose a JSON Schema file",
        "Không thấy lỗi nào theo schema này.": "No problems found against this schema.",
        "JSON Schema": "JSON Schema",

        // --- Kiểm cú pháp đồ thị (FR-KNW-904) ---
        "Kiểm cú pháp đồ thị": "Check graph syntax",
        "Chưa nhận ra định dạng đồ thị — cần đuôi .dot, .gv, .cypher, .ttl hoặc .graphml.":
            "Unrecognised graph format — needs a .dot, .gv, .cypher, .ttl or .graphml extension.",
        "Không thấy lỗi cú pháp %@ nào (phép kiểm không đầy đủ).":
            "No %@ syntax errors found (the check is not exhaustive).",
        "Cú pháp %@": "%@ syntax",

        // --- API script tri thức (FR-KNW-912) ---
        "không phải một đối tượng JSON": "not a JSON object",

        // --- Khai phá văn bản (FR-MIN-006) ---
        "Khai phá văn bản (n-gram, TF-IDF)": "Text mining (n-grams, TF-IDF)",
        "Tài liệu rỗng.": "The document is empty.",
        "Không rút được từ khoá nào.": "No keywords could be extracted.",
        "Từ khoá": "Keywords",
        "%d từ khoá · %d token · %d tài liệu": "%d {one=keyword|other=keywords} · %d {one=token|other=tokens} · %d {one=document|other=documents}",
        "Tô lên tài liệu": "Mark in the document",

        // --- Đánh dấu entity (FR-KNW-908) ---
        "Đánh dấu entity từ danh sách…": "Mark entities from a list…",
        "Chọn danh sách entity (CSV hoặc JSON)": "Choose an entity list (CSV or JSON)",
        "Không đọc được danh sách entity.": "Could not read the entity list.",
        "Danh sách entity rỗng.": "The entity list is empty.",
        "Không thấy entity nào trong tài liệu (%d mục đã nạp).":
            "No entities found in the document (%d loaded).",
        "%d lần xuất hiện · %@": "%d {one=occurrence|other=occurrences} · %@",

        // --- Chuyển đổi tri thức (FR-KNW-910) ---
        "Chuyển đổi tri thức…": "Convert knowledge…",
        "Chuyển đổi: %@ → %@": "Convert: %@ → %@",
        // "Tạo tab mới" đã có sẵn ở bảng trên — cùng chữ, cùng nghĩa, nên dùng lại thay vì
        // khai một khoá thứ hai. `Dictionary` literal sập trước khi cổng tĩnh kịp kêu.
        "Không chuyển đổi được.": "Could not convert.",

        // --- Xem trước cắt chunk (FR-KNW-903) ---
        "Xem trước cắt chunk…": "Preview chunking…",
        "Cỡ cố định 800B, chồng 100B": "Fixed 800 B, 100 B overlap",
        "Theo câu (≤ 800B)": "By sentence (≤ 800 B)",
        "Theo heading Markdown": "By Markdown heading",
        "Tài liệu rỗng — không có chunk nào.": "Empty document — no chunks.",
        "%d chunk · trung bình %d B · %@": "%d {one=chunk|other=chunks} · %d B average · %@",
        "Xuất JSONL": "Export JSONL",
        "Chunk JSONL": "Chunk JSONL",

        // --- Bảng triple/edge (FR-KNW-906) ---
        "Mở triple/edge dạng bảng": "Open triples/edges as a table",
        "Bảng triple": "Triple table",
        "Tài liệu này không có dòng triple nào.": "This document has no triple lines.",
        "Không đọc được triple nào — dòng %d: %@": "No triples could be read — line %d: %@",
        "Đã đọc %d triple · %d dòng hỏng bị bỏ qua (dòng đầu: %d)":
            "Read %d {one=triple|other=triples} · skipped %d malformed {one=line|other=lines} (first: line %d)",

        // --- Trùng lặp mờ (FR-CLN-004) ---
        "Trùng lặp mờ theo cột…": "Fuzzy duplicates by column…",
        "Trùng lặp mờ — cột «%@»: %d cụm ứng viên": "Fuzzy duplicates — column «%@»: %d candidate {one=group|other=groups}",
        "Gộp": "Merge",
        "Giống": "Match",
        "Các giá trị trong cụm": "Values in group",
        "Gộp về": "Merge into",
        "Gộp các cụm đã chọn": "Merge selected groups",
        "Chưa chọn cụm nào — bấm Gộp thì KHÔNG có gì thay đổi. Máy không tự gộp bao giờ.":
            "No groups selected — Merge will change nothing. The app never merges on its own.",
        "Đã chọn %d cụm · %d hàng sẽ đổi giá trị · MỘT bước hoàn tác":
            "%d {one=group|other=groups} selected · %d {one=row|other=rows} will change · ONE undo step",
        "Không quét được cột này.": "Could not scan this column.",
        "Cột «%@» không có cụm trùng lặp mờ nào.": "Column «%@» has no fuzzy duplicate groups.",
        "Không cụm nào được gộp — tài liệu giữ nguyên.":
            "No groups merged — the document is unchanged.",
        "Khử trùng lặp mờ · cột %@": "Fuzzy dedup · column %@",
        "Đã gộp %d cụm · %d ô đổi giá trị": "Merged %d {one=group|other=groups} · %d {one=cell|other=cells} changed",

        // --- Báo cáo làm sạch (FR-CLN-006) ---
        //
        // Anh chốt 28/08/2026: báo cáo ĐI THEO ngôn ngữ giao diện. Đây là quyết định về SẢN
        // PHẨM chứ không phải về mã — một báo cáo là tài liệu người dùng gửi đi, nên nó phải
        // cùng thứ tiếng với người nhận, và người dùng chọn thứ tiếng ấy bằng giao diện.
        //
        // Hệ quả phải biết: bài tự kiểm đọc lại báo cáo cũng phải đi qua `L()`, nếu không nó sẽ
        // đỏ ở máy chạy tiếng Anh — đỏ đúng chỗ không có gì hỏng. Đã sửa cùng lượt.
        "Báo cáo làm sạch": "Cleaning report",
        "# Báo cáo làm sạch — %@\n\n": "# Cleaning report — %@\n\n",
        "## Đã áp dụng (%d)\n\n": "## Applied (%d)\n\n",
        "_Chưa áp dụng bước nào._\n": "_No steps applied yet._\n",
        "\n## Hồ sơ dữ liệu\n\n": "\n## Data profile\n\n",
        "_%d cột · %d hàng · quét %.1f s_\n\n": "_%d {one=column|other=columns} · %d {one=row|other=rows} · scanned in %.1f s_\n\n",
        "| Cột | Kiểu | Null | Distinct | Nhỏ nhất | Lớn nhất | Trung bình |\n":
            "| Column | Type | Null | Distinct | Min | Max | Mean |\n",
        "\n### Giá trị bất thường\n\n": "\n### Outliers\n\n",
        "hàng %d: %@": "row %d: %@",
        "- cột «%@» — %d ô: %@\n": "- column «%@» — %d {one=cell|other=cells}: %@\n",
        "\n## Còn lại (%d)\n\n": "\n## Remaining (%d)\n\n",
        "_Không còn phát hiện nào._\n": "_No findings left._\n",
        "- cột «%@»: %@\n": "- column «%@»: %@\n",

        // Khối "Phương pháp" giữ nguyên là MỘT chuỗi ở cả hai ngôn ngữ — chẻ nhỏ thì người dịch
        // nhận được mấy câu cụt và bản dịch vỡ nhịp. Và vì nó là chuỗi NHIỀU DÒNG, khoá ở đây
        // phải giống chỗ gọi TỪNG BYTE: lệch một dấu cách thì `L()` im lặng trả về nguyên bản
        // tiếng Việt. Có bài tự kiểm hỏi thẳng bảng dịch để bắt đúng điều đó, và nó đã được xác
        // nhận đỏ được bằng cách thêm một dấu cách.
        """
        \n**Phương pháp.** Một lượt quét, chỉ đọc. Trung bình và độ lệch chuẩn tính \
        bằng Welford. Distinct đếm chính xác tới %d giá trị; vượt ngưỡng thì con số là \
        CẬN DƯỚI và bảng «hay gặp» bị bỏ. Giá trị bất thường chấm bằng |z| > 3 — thước \
        này bị chính outlier kéo lệch khi phân bố lệch, nên hãy đọc nó như một gợi ý để \
        nhìn, không phải một phán quyết. Ô thiếu không tính vào distinct. Cột chữ lấy \
        nhỏ nhất/lớn nhất theo thứ tự BYTE, không phải thứ tự chữ cái tiếng Việt.\n
        """: """
        \n**Method.** One read-only pass. Mean and standard deviation use Welford. Distinct \
        is counted exactly up to %d values; beyond that the number is a LOWER BOUND and the \
        «most common» table is dropped. Outliers are flagged at |z| > 3 — a measure the \
        outliers themselves skew when the distribution is skewed, so read it as a hint to look, \
        not as a verdict. Blank cells do not count toward distinct. Text columns take min/max \
        in BYTE order, not Vietnamese alphabetical order.\n
        """,

        // --- Lệnh File · phiên làm việc · bảng mã và EOL ---
        //
        // Hai chuỗi ở đây là NHÃN HOÀN TÁC (`applyEdits(label:)`), không phải thông báo: chúng
        // hiện trong menu Edit thành "Undo Cắt khoảng trắng khi lưu". Dịch chúng ở tầng app là
        // đúng chỗ — lõi không được biết ngôn ngữ giao diện (NFR-MNT-01).
        "Cắt khoảng trắng khi lưu": "Trim whitespace on save",
        "Chuẩn hóa xuống dòng": "Normalise line endings",

        "trước đó": "previous",
        "Không mở lại được thư mục «%@» của phiên trước":
            "Could not reopen the folder «%@» from the previous session",
        " (và %d file khác)": " (and %d more {one=file|other=files})",
        "Không mở lại được %d tab: %@%@ — file không còn ở chỗ cũ.":
            "Could not reopen %d {one=tab|other=tabs}: %@%@ — the files are no longer where they were.",
        "Không đọc được nội dung từ ống dẫn": "Could not read input from the pipe",
        "Sẽ cắt khoảng trắng cuối dòng mỗi lần lưu":
            "Trailing whitespace will be trimmed on every save",
        "Không cắt khoảng trắng khi lưu nữa": "No longer trimming whitespace on save",
        "Chưa đặt tên.txt": "Untitled.txt",
        "Chuyển đổi bảng mã sẽ làm mất ký tự": "Converting the encoding will lose characters",
        "Vẫn lưu": "Save anyway",
        "Tài liệu có thay đổi chưa lưu": "The document has unsaved changes",
        "Đóng mà không lưu thì phần chưa lưu sẽ mất.":
            "Closing without saving will discard them.",
        "Bỏ thay đổi": "Discard changes",
        "Đi tới dòng": "Go to line",
        "Tài liệu có %d dòng.": "The document has %d {one=line|other=lines}.",
        "Số dòng": "Line number",
        "Đi tới": "Go",
        "Diễn giải lại theo…": "Reinterpret as…",
        "Chuyển đổi sang…": "Convert to…",
        "Không diễn giải lại được": "Could not reinterpret",
        "Bảng mã %@ không chứa hết ký tự": "%@ cannot represent every character",
        "Vẫn chọn": "Choose anyway",

        // --- Bảng CSV, kiểm dữ liệu, Column Editor ---
        //
        // Chuỗi ĐỊNH DẠNG, không phải nhãn: gốc là chuỗi nội suy `"Cột \(i)"`, đã tách thành
        // `LF("Cột %d", i)`. Thứ tự tham số phải giữ NGUYÊN giữa hai ngôn ngữ —
        // tiếng Anh ở đây không cần đảo, nhưng nếu ngày nào đó có ngôn ngữ cần đảo thì dùng
        // `%1$@`/`%2$@` chứ đừng đổi thứ tự ở chỗ gọi.
        "Cột %d": "Column %d",
        "Cột %d: %@": "Column %d: %@",
        "Cột ẩn: %@ (%d) — hiện lại từ menu ngữ cảnh trên hàng tiêu đề":
            "Hidden columns: %@ (%d) — restore from the header row context menu",
        "Hiện lại: %@": "Show again: %@",
        "Đã ẩn cột %@ — cột vẫn còn nguyên trong file":
            "Hid column %@ — the column is still intact in the file",
        "Sắp xếp theo %@ %@ · chỉ hiển thị": "Sorted by %@ %@ · display only",
        "Sắp xếp: %@ %@ (chỉ hiển thị)": "Sorted: %@ %@ (display only)",
        "%d+ dòng khớp — đang tìm tiếp…": "%d+ rows matched — still searching…",
        "%d / %d dòng khớp": "%d / %d {one=row|other=rows} matched",

        "Không tìm thấy lỗi trong %d hàng": "No problems found in %d {one=row|other=rows}",
        "%d hàng lệch số cột": "%d {one=row|other=rows} with the wrong column count",
        "%d ô sai kiểu dữ liệu": "%d {one=cell|other=cells} with the wrong data type",
        " (đã dừng ở %d lỗi đầu)": " (stopped at the first %d {one=problem|other=problems})",
        "   —   kiểu nhận ra: ": "   —   detected types: ",
        "Hàng %d, cột %@: «%@» không phải %@": "Row %d, column %@: «%@» is not %@",

        "Column Editor — %d dòng": "Column Editor — %d {one=line|other=lines}",

        // --- Bàn làm sạch (FR-CLN) ---
        //
        // Dịch TRỌN cụm, không nhặt từng chuỗi script chỉ ra. Chính `scan-untranslated.py` cảnh
        // báo điều này: con số nó đưa ra là CẬN DƯỚI (từ không dấu như "Cam" lọt qua), nên dịch
        // theo danh sách của nó sẽ để lại một mặt giao diện nửa Anh nửa Việt — tệ hơn một mặt
        // giao diện toàn tiếng Việt.
        "Phát hiện": "Findings",
        "Hồ sơ dữ liệu": "Data profile",
        "Hồ sơ dữ liệu — đang quét…": "Data profile — scanning…",
        "Lưu công thức…": "Save recipe…",
        "Xuất báo cáo": "Export report",
        "Chưa áp dụng nhóm nào · mỗi nhóm là một bước undo":
            "No groups applied yet · each group is one undo step",
        "quá nhiều giá trị": "too many values",
        "hay gặp: ": "most common: ",

        // Hộp thoại một bước làm sạch. Mỗi mục là một lựa chọn đã đủ tham số để chạy — nên câu
        // chữ phải nói ra HỆ QUẢ, không chỉ tên thao tác.
        "Giá trị điền vào ô thiếu": "Value to fill blanks with",
        "Áp dụng": "Apply",
        "Không dựng được bản xem trước": "Could not build a preview",
        "· giữ nguyên, không đọc được ·": "· kept as-is, unparseable ·",
        "Đưa cột về ISO 8601 (YYYY-MM-DD)": "Convert column to ISO 8601 (YYYY-MM-DD)",
        "Quy ước số cho cả cột": "Number convention for the whole column",
        "Làm gì với ô thiếu": "What to do with blanks",
        "Chuẩn hóa về ISO 8601": "Normalise to ISO 8601",
        "Ô mơ hồ đọc là NGÀY trước (31/12)": "Read ambiguous cells as DAY first (31/12)",
        "Ô mơ hồ đọc là THÁNG trước (12/31)": "Read ambiguous cells as MONTH first (12/31)",
        "Bỏ qua ô mơ hồ, chỉ sửa ô chắc chắn": "Skip ambiguous cells, fix only the certain ones",
        "Về Việt/Âu (1.234,56)": "To Vietnamese/European (1.234,56)",
        "Về Anh-Mỹ (1,234.56)": "To Anglo-American (1,234.56)",
        "Về Anh-Mỹ, bỏ dấu nhóm (1234.56)": "To Anglo-American, no grouping (1234.56)",
        "Điền một giá trị mặc định…": "Fill with a default value…",
        "Điền xuôi — lấy giá trị phía trên": "Fill forward — take the value above",
        "Điền ngược — lấy giá trị phía dưới": "Fill backward — take the value below",
        "Xóa hàng có ô thiếu ở cột này": "Delete rows with a blank in this column",
        "Cắt khoảng trắng hai đầu": "Trim whitespace at both ends",
        "Cắt hai đầu và nén khoảng trắng bên trong":
            "Trim both ends and collapse inner whitespace",

        // Pivot (FR-QRY-003) và danh mục bảng ảo (FR-QRY-005).
        "Pivot…": "Pivot…",
        "Nguồn…": "Sources…",
        "Pivot — gộp theo cột": "Pivot — group by column",
        "Hàng (gộp nhóm)": "Rows (group by)",
        "Giá trị": "Values",
        "+ Hàng": "+ Row",
        "+ Giá trị": "+ Value",
        "Xoá hết": "Clear all",
        "Đưa vào ô truy vấn": "Put into the query box",
        "Chọn cột để dựng câu truy vấn.": "Pick columns to build the query.",
        "Không đọc được tên cột của bảng này.": "Could not read this table's column names.",
        "Nguồn dữ liệu của truy vấn": "Query data sources",
        "«%@» — tài liệu đang mở": "“%@” — the open document",
        "  ⚠️ file đã đổi kể từ khi đăng ký": "  ⚠️ file changed since it was registered",
        "Thêm file…": "Add file…",
        "Bỏ hết": "Remove all",
        "Không suy được tên bảng từ «%@» — hãy đổi tên file.":
            "Could not derive a table name from “%@” — rename the file.",
        "Tổng": "Sum",
        // "Đếm" đã có ở nhóm panel Tìm — bảng này là một `Dictionary` literal, và khoá trùng
        // làm app CHẾT LÚC CHẠY ở dòng đầu tiên đọc tới bảng, không phải lúc biên dịch.
        "Trung bình": "Average",
        "Nhỏ nhất": "Min",
        "Lớn nhất": "Max",
        "Đếm khác nhau": "Distinct count",

        // Biểu đồ (FR-QRY-004).
        "Biểu đồ": "Chart",
        "Xuất PNG": "Export PNG",
        "Xuất SVG": "Export SVG",
        "Bảng này không có cột số nào để vẽ.": "This table has no numeric column to chart.",
        "Không dựng được ảnh PNG.": "Could not build the PNG image.",
        "Kết quả truy vấn": "Query result",
        "Đã lưu %@": "Saved %@",
        "Biểu đồ %@ của «%@» — %d điểm, giá trị từ %@ đến %@":
            "%@ chart of “%@” — %d {one=point|other=points}, values from %@ to %@",
        "Cột": "Bar",
        "Đường": "Line",
        "Phân bố": "Histogram",
        "Phân tán": "Scatter",
        "Hộp": "Box",

        // Bảng chất lượng dữ liệu (FR-DQR-001 · FR-DQR-002).
        "CSV: chất lượng dữ liệu…": "CSV: Data quality…",
        "Chất lượng dữ liệu": "Data quality",
        "Xuất vi phạm ra tab mới": "Export violations to a new tab",
        // Mỗi cặp MỘT DÒNG. `scan-untranslated.py` chỉ đọc khoá đầu tiên của mỗi dòng, nên
        // gộp nhiều cặp vào một dòng là giấu chúng khỏi chính cái cổng đang đếm nợ dịch.
        "Mức": "Level",
        "Luật": "Rule",
        "Vi phạm": "Violations",
        "Tỷ lệ": "Rate",
        "đạt": "pass",
        "lỗi": "error",
        "cảnh báo": "warning",
        "hỏng": "broken",
        "Đã đánh dấu %d dòng vi phạm": "Marked %d violating {one=line|other=lines}",
        // FR-DQR-004 — theo dõi trôi dạt.
        "Xu hướng": "Trend",
        "Lúc chấm": "Scored at",
        "Số hàng": "Rows",
        "Lệch": "Delta",
        "Luật trượt": "Failing rules",
        "Điểm chất lượng": "Quality score",
        "Điểm theo thời gian": "Score over time",
        "Chưa có mốc nào trong lịch sử — mỗi lần chấm sẽ ghi thêm ": "No history yet \u{2014} every scoring run appends ",
        "một dòng vào tệp «.history.jsonl» cạnh bộ luật.": "one line to the \u{201C}.history.jsonl\u{201D} file next to the rules.",
        "%d mốc trong lịch sử": "%d {one=point|other=points} in history",
        " · %d dòng KHÔNG đọc được": " \u{00B7} %d unreadable {one=line|other=lines}",
        " · chọn hai dòng để so": " \u{00B7} select two rows to compare",
        "điểm %+.1f": "score %+.1f",
        "không chiều nào tụt": "no dimension dropped",
        "tụt: ": "dropped: ",
        "%d luật mới trượt: %@": "%d newly failing {one=rule|other=rules}: %@",
        "số hàng %+d": "rows %+d",
        " (và %d cảnh báo nữa ở tab Xu hướng)": " (and %d more {one=warning|other=warnings} in the Trend tab)",
        // FR-DQR-006 — vòng khép kín với Bàn làm sạch.
        "Không sửa tự động được: ": "No automatic fix: ",
        "Mở đúng công cụ trong Bàn làm sạch, xong thì chấm lại ngay.": "Opens the matching Cleaning Bench tool, then scores again right away.",
        "Xử lý giá trị thiếu…": "Handle missing values\u{2026}",
        "Chuẩn hóa ngày…": "Normalize dates\u{2026}",
        "Khử trùng lặp…": "Remove duplicates\u{2026}",
        "Thay thế…": "Replace\u{2026}",
        "Xem các dòng sai": "Show the offending rows",
        "Không tìm thấy cột «%@» trong bảng này.": "Column \u{201C}%@\u{201D} is not in this table.",
        "Đã khử trùng lặp — «%@» nay không còn trùng. Điểm: %.0f/100": "Duplicates removed \u{2014} \u{201C}%@\u{201D} is unique now. Score: %.0f/100",
        "Khử trùng lặp xong nhưng «%@» vẫn còn %d hàng trùng (trước: %d) — ": "Duplicates removed, but \u{201C}%@\u{201D} still has %d duplicate {one=row|other=rows} (was %d) \u{2014} ",
        "những hàng ấy trùng KHOÁ chứ không trùng cả dòng, nên phải xem và chọn ": "those rows share the KEY but not the whole line, so you must look and choose ",
        "giữ hàng nào.": "which one to keep.",
        "Không đọc được giá trị nào đang vi phạm luật này.": "Could not read any value violating this rule.",
        "%d giá trị sai ở cột «%@» — sửa ô Thay rồi bấm Xem trước": "%d bad {one=value|other=values} in column \u{201C}%@\u{201D} \u{2014} fill in Replace, then preview",
        "Đã chấm lại: %.0f/100": "Scored again: %.0f/100",
        // FR-RPT — báo cáo .greport.md.
        "Xem trước báo cáo": "Report preview",
        "Tham số…": "Parameters\u{2026}",
        "Xuất HTML…": "Export HTML\u{2026}",
        "In / PDF…": "Print / PDF\u{2026}",
        "%d khối chạy được · %d khối HỎNG": "%d {one=block|other=blocks} ran \u{00B7} %d {one=block|other=blocks} FAILED",
        "%d khối chạy được": "%d {one=block|other=blocks} ran",
        " · DỮ LIỆU CŨ — file nguồn đã đổi, bấm dựng lại": " \u{00B7} STALE DATA \u{2014} the source file changed; rebuild",
        "Xem trước báo cáo cần tài liệu đuôi .%@": "Report preview needs a .%@ document",
        "Chưa tìm được dữ liệu — khai «source: tên-file.csv» ở frontmatter.": "No data source found \u{2014} declare \u{201C}source: file.csv\u{201D} in the frontmatter.",
        "Không dựng được báo cáo.": "Could not build the report.",
        "Báo cáo này chưa khai tham số nào ở frontmatter.": "This report declares no parameters in its frontmatter.",
        "Tham số báo cáo": "Report parameters",
        "Dựng lại": "Rebuild",
        "Đã xuất %@": "Exported %@",
        "Báo cáo: xem trước": "Report: Preview",
        // FR-MMD — Mermaid Studio.
        "Báo cáo: sinh loạt…": "Report: Batch generate\u{2026}",
        "không phải tài liệu .greport.md": "not a .greport.md document",
        "không phân tích được báo cáo": "could not parse the report",
        "không tìm được dữ liệu nguồn": "could not find the source data",
        "không đọc được danh sách tham số": "could not read the parameter list",
        "Sinh loạt cần tài liệu đuôi .%@": "Batch generation needs a .%@ document",
        "Chọn danh sách tham số (CSV hoặc JSON)": "Choose a parameter list (CSV or JSON)",
        "Chọn thư mục để ghi %d báo cáo": "Choose a folder for %d {one=report|other=reports}",
        "[%d/%d] %@": "[%d/%d] %@",
        "thiếu tham số ": "missing parameters ",
        "trỏ vào chính tệp nguồn — từ chối ghi đè": "points at the source file itself \u{2014} refusing to overwrite",
        "%d khối HỎNG": "%d {one=block|other=blocks} FAILED",
        "Sinh loạt xong: %d tệp · %d hỏng": "Batch done: %d {one=file|other=files} \u{00B7} %d failed",
        "%d bộ tham số KHÔNG dựng được — xem bảng tổng kết": "%d parameter {one=set|other=sets} could not be built \u{2014} see the summary",
        "Sơ đồ Mermaid: xem trước": "Mermaid diagram: Preview",
        "Sơ đồ Mermaid: chèn mẫu…": "Mermaid diagram: Insert template\u{2026}",
        "Sơ đồ Mermaid: định dạng lại": "Mermaid diagram: Reformat",
        "Nền trong suốt": "Transparent background",
        "Máy này không dựng được ảnh PNG từ sơ đồ — cần macOS 13. Xuất SVG vẫn dùng được.": "This Mac cannot rasterize the diagram to PNG \u{2014} macOS 13 is required. SVG export still works.",
        "Lưu PNG %@…": "Save PNG %@\u{2026}",
        "Lưu SVG…": "Save SVG\u{2026}",
        "Chép ảnh vào clipboard": "Copy image to clipboard",
        "Màu thương hiệu…": "Brand colors\u{2026}",
        "Màu thương hiệu cho sơ đồ": "Brand colors for diagrams",
        "Mỗi ô là một mã màu dạng #rrggbb. Lưu vào «themes/mermaid-brand.json» — chép sang máy khác được.": "Each field is an #rrggbb color. Saved to \u{201C}themes/mermaid-brand.json\u{201D} \u{2014} copy it to another Mac.",
        "Màu chính": "Primary color",
        "Chữ trên nút": "Text on nodes",
        "Viền": "Border",
        "Đường nối": "Links",
        "Nền khi xuất ảnh": "Background when exporting",
        "Lưu và chèn %%{init}%% vào tài liệu": "Save and insert %%{init}%% into the document",
        "Đã lưu màu thương hiệu": "Brand colors saved",
        "Đã chép ảnh sơ đồ vào clipboard": "Diagram image copied to the clipboard",
        "Đã lưu %@ — %@": "Saved %@ \u{2014} %@",
        "Sơ đồ này đã có sẵn một chỉ thị %%{init}%% — giữ nguyên bản của anh.": "This diagram already has an %%{init}%% directive \u{2014} yours is left untouched.",
        "Đã chèn %%{init}%% — sơ đồ nay tự mang màu của nó": "Inserted %%{init}%% \u{2014} the diagram now carries its own colors",
        "Chèn màu thương hiệu vào sơ đồ": "Insert brand colors into the diagram",

        "Định dạng sơ đồ Mermaid": "Reformat Mermaid diagram",
        "Mã sơ đồ đã đúng khuôn — không có gì để sửa": "The diagram source is already tidy \u{2014} nothing to change",
        "Đã định dạng lại sơ đồ": "Diagram reformatted",
        "Đã định dạng lại %d sơ đồ": "Reformatted %d {one=diagram|other=diagrams}",
        "Thư viện mẫu sơ đồ": "Diagram template library",
        "Mẫu sơ đồ đầy đủ": "Full diagram templates",
        "Mẩu cú pháp": "Syntax snippets",
        "Đang soạn: %@": "Editing: %@",
        "Đã chèn mẫu «%@»": "Inserted template \u{201C}%@\u{201D}",
        "Tài liệu đang ở chế độ chỉ đọc.": "This document is read-only.",
        "Sơ đồ Mermaid": "Mermaid diagram",
        "Tài liệu chưa có khối mermaid nào.": "This document has no mermaid block.",
        "Thương hiệu": "Brand",
        "Xuất…": "Export\u{2026}",
        "Chưa có sơ đồ nào": "No diagrams yet",
        "%d sơ đồ · %@": "%d {one=diagram|other=diagrams} \u{00B7} %@",
        "%d/%d sơ đồ HỎNG — sơ đồ thứ %d%@": "%d/%d {one=diagram|other=diagrams} FAILED \u{2014} diagram %d%@",
        ", dòng %d": ", line %d",
        "Tài liệu này chưa có khối ```mermaid nào, và cũng không phải tệp .mmd.": "This document has no ```mermaid block and is not a .mmd file.",
        "Chưa có sơ đồ nào vẽ xong để xuất.": "No diagram has finished rendering yet.",
        "Không tìm thấy «%@» trong mã sơ đồ": "Could not find \u{201C}%@\u{201D} in the diagram source",
        "không dựng được hàng rào chặn mạng cho WKWebView": "could not build the network blocker for WKWebView",
        // FR-MIN-003 — luật kết hợp.
        "Luật kết hợp": "Association rules",
        "Mỗi dòng một giỏ": "One basket per row",
        "Hai cột: mã · item": "Two columns: id \u{00B7} item",
        "Dạng dữ liệu giao dịch": "Transaction data shape",
        "Cột giỏ hàng hoặc mã giao dịch": "Basket column or transaction id column",
        "Cột item": "Item column",
        "Ký tự phân tách item": "Item separator character",
        "Support tối thiểu, phần trăm": "Minimum support, percent",
        "Confidence tối thiểu, phần trăm": "Minimum confidence, percent",
        "Tách bởi:": "Split by:",
        "Support \u{2265}": "Support \u{2265}",
        "% · Confidence \u{2265}": "% \u{00B7} Confidence \u{2265}",
        "Bảng luật kết hợp": "Association rule table",
        "Support": "Support",
        "Confidence": "Confidence",
        "Lift": "Lift",
        "Leverage": "Leverage",
        "Cảnh báo": "Caution",
        "%d giao dịch · %d item · %d luật": "%d {one=transaction|other=transactions} \u{00B7} %d {one=item|other=items} \u{00B7} %d {one=rule|other=rules}",
        " — không luật nào đạt ngưỡng; hạ support hoặc confidence xuống": " \u{2014} no rule met the thresholds; lower support or confidence",
        " — ĐÃ DỪNG SỚM, bảng KHÔNG đầy đủ": " \u{2014} STOPPED EARLY, the table is INCOMPLETE",
        "%d / %d giao dịch chứa cả hai vế": "%d / %d {one=transaction contains|other=transactions contain} both sides",
        "Dạng hai cột cần chọn hai cột KHÁC nhau.": "The two-column shape needs two DIFFERENT columns.",
        "Đã đánh dấu %d dòng của %d giao dịch chứa «%@»": "Marked %d {one=row|other=rows} across %d {one=transaction|other=transactions} containing \u{201C}%@\u{201D}",
        "CSV: luật kết hợp…": "CSV: Association Rules\u{2026}",
        // FR-MIN-007 — khai phá theo nhóm.
        "Khai phá theo nhóm": "Group mining",
        "Cột nhóm": "Group column",
        "Cột giá trị": "Value column",
        "Cột thứ hai cho tương quan": "Second column for correlation",
        "Cách xếp hạng": "Ranking",
        "Nhóm theo:": "Group by:",
        "Giá trị:": "Value:",
        "Xếp theo:": "Rank by:",
        "Bảng xếp hạng nhóm": "Group ranking table",
        "Nhóm": "Group",
        "Hàng": "Rows",
        "Hàng rào riêng": "Own fence",
        "MAPE": "MAPE",
        "r": "r",
        "Lệch r": "r gap",
        "Ghi chú": "Note",
        "không đo được": "not measurable",
        "%d nhóm · mốc tương quan toàn bộ %@": "%d {one=group|other=groups} \u{00B7} pooled correlation %@",
        " · ĐÃ CẮT %d nhóm": " \u{00B7} %d {one=GROUP|other=GROUPS} DROPPED",
        "Bảng này không có cột chữ nào để gom nhóm.": "This table has no text column to group by.",
        "Bảng này không có cột số nào để khai phá.": "This table has no numeric column to mine.",
        "Đã đánh dấu %d dòng của nhóm «%@»": "Marked %d {one=row|other=rows} of group \u{201C}%@\u{201D}",
        "CSV: khai phá theo nhóm…": "CSV: Group Mining\u{2026}",
        // Ký hiệu, không phải chữ tiếng Việt bị bỏ sót.
        "\u{2194}": "\u{2194}",
        // FR-MIN-004 — dự báo chuỗi thời gian.
        "Dự báo": "Forecast",
        "Cột giá trị theo thời gian": "Value column over time",
        "Mô hình dự báo": "Forecast model",
        "Số kỳ dự báo": "Number of periods to forecast",
        "Kết luận so với baseline": "Verdict against the baselines",
        "Mô hình:": "Model:",
        "Số kỳ:": "Periods:",
        "Chu kỳ:": "Season:",
        "tự": "auto",
        "Chu kỳ mùa vụ, để trống thì tự phát hiện": "Seasonal period; leave blank to detect automatically",
        "Bảng giá trị dự báo": "Forecast value table",
        "Kỳ": "Period",
        "Dải 80%": "80% band",
        "Dải 95%": "95% band",
        "MAE %@ · MAPE %@": "MAE %@ \u{00B7} MAPE %@",
        "không tính được": "not computable",
        "Bảng này không có cột số nào để dự báo.": "This table has no numeric column to forecast.",
        "Không dựng được dự báo cho cột này.": "Could not build a forecast for this column.",
        "Cột «%@» chỉ có %d giá trị số — cần ít nhất 4 để dự báo.": "Column \u{201C}%@\u{201D} has only %d numeric {one=value|other=values} \u{2014} at least 4 are needed to forecast.",
        "# Chuỗi đọc theo ĐÚNG thứ tự hàng trong file — không sắp lại, không suy ra cột thời gian.\n": "# The series is read in the file\u{2019}s row order \u{2014} not re-sorted, no time column inferred.\n",
        "Sai số huấn luyện": "Training error",
        "CSV: dự báo chuỗi thời gian…": "CSV: Forecast Time Series\u{2026}",
        // Bốn tên mô hình giữ nguyên — thuật ngữ, không phải chữ tiếng Việt bị bỏ sót.
        "Holt-Winters cộng": "Holt-Winters additive",
        "Holt-Winters nhân": "Holt-Winters multiplicative",
        "seasonal-naive": "seasonal-naive",
        "naive": "naive",
        // FR-MIN-002 — phân cụm.
        "Cột đưa vào phân cụm": "Columns fed into clustering",
        "Đường cong WCSS": "WCSS curve",
        "Phân cụm": "Cluster",
        "Chuẩn hoá:": "Scaling:",
        "k:": "k:",
        "eps:": "eps:",
        "minPts:": "minPts:",
        "Chọn ít nhất một cột.": "Select at least one column.",
        "Không đủ dữ liệu để dựng đường cong.": "Not enough data to build the curve.",
        "Elbow gợi ý k = %d. WCSS LUÔN giảm khi k tăng, nên đây là mẹo đọc đồ thị chứ không phải tiêu chí thống kê — nhìn đường cong xem chỗ gãy có rõ không.": "Elbow suggests k = %d. WCSS ALWAYS falls as k grows, so this is a chart-reading heuristic rather than a statistical criterion \u{2014} look at the curve and judge whether the bend is clear.",
        "WCSS theo k": "WCSS by k",
        "k-distance gợi ý eps = %@ (minPts mặc định 2 × số cột = %d). %@": "k-distance suggests eps = %@ (minPts defaults to 2 \u{00D7} column count = %d). %@",
        "Khoảng cách tới hàng xóm thứ k": "Distance to the k-th neighbour",
        "Cần ít nhất 2 cột số để phân cụm.": "At least 2 numeric columns are needed for clustering.",
        "Cụm theo %@ và %@": "Clusters by %@ and %@",
        " — cụm tìm trên %d chiều, hình chỉ vẽ 2 chiều đầu": " \u{2014} clusters found in %d {one=dimension|other=dimensions}; the plot shows only the first 2",
        "# nhiễu (cluster_id = -1): %d dòng\n": "# noise (cluster_id = -1): %d {one=row|other=rows}\n",
        "CSV: phân cụm…": "CSV: Cluster\u{2026}",
        "# --- Tâm cụm (thang gốc) ---\n": "# --- Cluster centres (original units) ---\n",
        // Hai tên thuật toán giữ nguyên — thuật ngữ, không phải chữ tiếng Việt bị bỏ sót.
        "k-means": "k-means",
        "DBSCAN": "DBSCAN",
        // FR-MIN-005 — ma trận tương quan.
        "Ma trận tương quan": "Correlation matrix",
        "Phương pháp tương quan": "Correlation method",
        "Tương quan không hàm ý nhân quả.": "Correlation does not imply causation.",
        "Cặp mạnh nhất: %@ ↔ %@ = %@ (n = %d). Bấm một ô để xem biểu đồ phân tán.": "Strongest pair: %@ ↔ %@ = %@ (n = %d). Click a cell for a scatter plot.",
        "Không cặp nào đo được.": "No pair could be measured.",
        "%@ ↔ %@: %@ trên %d hàng": "%@ ↔ %@: %@ over %d {one=row|other=rows}",
        "Cần ít nhất 2 cột số để tính tương quan.": "At least 2 numeric columns are needed for correlation.",
        "Không đọc được cột «%@».": "Could not read column \u{201C}%@\u{201D}.",
        "CSV: ma trận tương quan…": "CSV: Correlation Matrix…",
        // FR-MIN-001 — bảng bất thường.
        "Bất thường": "Anomalies",
        "Danh sách bất thường": "Anomaly list",
        "Cột:": "Column:",
        "Cột số cần xét": "Numeric column to examine",
        "Cách:": "Method:",
        "Phương pháp phát hiện": "Detection method",
        "Phương pháp đã dùng": "Method used",
        "Ngưỡng": "Threshold",
        "Đánh dấu": "Mark",
        "Xuất tab mới": "Export to new tab",
        "Dòng": "Line",
        "Điểm": "Score",
        "Vì sao": "Why",
        "nhẹ": "mild",
        "vừa": "moderate",
        "nặng": "severe",
        // Ba tên phương pháp giữ nguyên: chúng là thuật ngữ thống kê, không phải chữ tiếng Việt
        // bị bỏ sót. Có mặt ở đây để bộ đếm nợ dịch không đếm nhầm chúng là chưa dịch.
        "z-score": "z-score",
        "IQR": "IQR",
        "MAD": "MAD",
        "%d / %d dòng (%.2f%%)": "%d / %d {one=row|other=rows} (%.2f%%)",
        "Bảng này không có cột số nào để tìm bất thường.": "This table has no numeric column to scan for anomalies.",
        "Đã đánh dấu %d dòng bất thường": "Marked %d anomalous {one=line|other=lines}",
        "CSV: tìm bất thường…": "CSV: Find Anomalies…",
        "%d luật, tất cả ĐẠT · %d hàng · %.0f ms":
            "%d {one=rule|other=rules}, all PASS · %d {one=row|other=rows} · %.0f ms",
        "%d lỗi · %d cảnh báo trên %d luật · %d hàng · %.0f ms":
            "%d {one=error|other=errors} · %d {one=warning|other=warnings} across %d {one=rule|other=rules} · %d {one=row|other=rows} · %.0f ms",
        "Lưu tài liệu trước — bộ quy tắc chất lượng nằm cạnh file dữ liệu.":
            "Save the document first — the quality rules live next to the data file.",
        "Chưa có bộ quy tắc. Tạo tệp %@ rồi mở lại.":
            "No rule set yet. Create %@ then reopen.",

        // Query Workbench (FR-QRY-001).
        "Lịch sử": "History",
        "Câu đã lưu": "Saved queries",
        "Lưu câu này…": "Save this query…",
        "Lưu câu truy vấn": "Save query",
        "Đặt tên để tìm lại sau. Trùng tên sẽ ghi đè.":
            "Give it a name so you can find it later. Same name overwrites.",
        "Ví dụ: Doanh thu theo tỉnh": "For example: Revenue by province",
        "Chưa nhập giá trị cho tham số: %@": "No value entered for parameter: %@",

        // Chuỗi cung ứng plugin (NFR-SEC-03) — hộp thoại duyệt plugin native.
        "Plugin đã đổi nội dung — GEditor từ chối chạy":
            "Plugin changed since you approved it — GEditor refuses to run it",
        "Chạy plugin chưa duyệt?": "Run an unapproved plugin?",
        "Tôi tin file này — chạy": "I trust this file — run it",
        "KHÔNG có chữ ký": "NOT signed",
        "Chữ ký: %@": "Signature: %@",
        "Đường dẫn: %@": "Path: %@",
        "Thay": "Replace",
        "Thay tất cả": "Replace All",
        "Chuỗi thuần": "Plain text",
        "Extended (\\n \\t \\xNN)": "Extended (\\n \\t \\xNN)",
        "Biểu thức chính quy": "Regular expression",
        "Phân biệt hoa thường": "Match case",
        "Cả từ": "Whole word",
        "Không có kết quả": "No results",

        // --- Mục menu thêm sau (bài tự kiểm bắt được vì quên dịch) ---
        "Thử biểu thức chính quy…": "Test Regular Expression…",
        "Chế độ Log (tô theo mức)": "Log Mode (colour by level)",
        "Lọc log theo mức…": "Filter Log by Level…",
        "Chạy trên cả thư mục…": "Run on Whole Folder…",
        "Lọc qua lệnh ngoài…": "Filter Through Command…",
        "Script…": "Scripts…",
        "Gói mở rộng…": "Extension Packages…",
        "Cửa sổ mới": "New Window",
        "Tách tab ra cửa sổ mới": "Move Tab to New Window",

        // --- Sidebar: cây thư mục & Function List ---
        "Chưa mở thư mục nào": "No folder open",
        "Tìm file trong thư mục": "Find file in folder",
        "Lọc theo tên": "Filter by name",
        "File mới…": "New File…",
        "Thư mục mới…": "New Folder…",
        "Đổi tên…": "Rename…",
        "Chuyển vào Thùng rác": "Move to Trash",
        "Hiện trong Finder": "Reveal in Finder",
        "Đang đọc cấu trúc tài liệu…": "Reading document structure…",
        "file này không có hàm nào": "no functions in this file",
        "Không có gì khớp": "Nothing matches",
        "Văn bản thuần": "Plain text",

        // --- Thanh trạng thái ---
        "🔒 Chỉ đọc": "🔒 Read-only",
        "Đang theo dõi": "Following",
        "ngắt tại cột": "wrap at column",

        // --- Panel JSONPath ---
        "Cú pháp": "Syntax",
        "Bấm để chèn vào ô truy vấn": "Click to insert into the query field",
        "truy vấn không hợp lệ": "invalid query",
        "khóa `ten` ở gốc": "key `ten` at the root",
        "khóa có dấu cách": "key containing a space",
        "phần tử đầu": "first element",
        "mọi phần tử": "every element",
        "lát cắt": "slice",
        "hợp nhiều chỉ số": "union of indices",
        "mọi khóa `gia` ở mọi tầng": "every `gia` key at any depth",
        "mọi nút": "every node",
        "lọc theo số": "filter by number",
        "lọc theo có mặt": "filter by presence",

        // --- Panel kiểm dữ liệu & lọc CSV ---
        "Tới lỗi đầu tiên": "Go to first issue",
        "Cột doanh_thu là số": "Column doanh_thu is numeric",
        "lọc…": "filter…",

        // --- Nút chung ---
        "Hủy": "Cancel",
        "Thực hiện thay": "Replace",
        "xem trước": "preview",
        "tương tác": "interactive",

        // --- Cài đặt ---
        "Soạn thảo": "Editing",
        "Giao diện": "Appearance",
        "Phím tắt": "Keyboard Shortcuts",
        "Cỡ chữ": "Font size",
        "Bề rộng TAB": "Tab width",
        "Thụt lề bằng TAB": "Indent with tabs",
        "Tự động thụt lề khi xuống dòng": "Auto-indent on new line",
        "Tô mọi kết quả tìm kiếm": "Highlight all search results",
        " · ĐÃ HUỶ giữa chừng — bảng chưa đầy đủ":
            " \u{00B7} CANCELLED midway \u{2014} table is incomplete",
        // --- Khung chung của tài liệu (NFR-USE-01) ---
        "Chế độ hiển thị": "Display mode",
        "Đổi giữa View và Code (⌥⌘V)":
            "Switch between View and Code (\u{2325}\u{2318}V)",
        "Trang tài liệu": "Document pages",
        "Chữ đã dựng": "Rendered text",
        "Trang bảng tính": "Spreadsheet pages",
        "Sơ đồ": "Diagram",
        "Cây khoá–giá trị": "Key\u{2013}value tree",
        "Bộ phát": "Player",
        "Danh sách mục": "Entry list",
        "Báo cáo đã dựng": "Rendered report",
        "Tô theo mức": "Coloured by level",
        "Trang slide": "Slide pages",
        "Dàn ý": "Outline",
        // --- Khung xem tài liệu Office (NFR-USE-01) ---
        "Lưu rồi dựng lại": "Save and re-render",
        "Đang xem bản TRÊN ĐĨA — những sửa đổi chưa lưu không có ở đây.":
            "Showing the copy ON DISK \u{2014} unsaved edits are not in here.",
        "Hệ thống không dựng được bộ xem tài liệu — dùng chế độ Code.":
            "The system could not build the document viewer \u{2014} use Code mode.",
        "Lưu tệp trước khi xem trang.": "Save the file before viewing its pages.",
        // --- Mục View/Code trên thanh trạng thái (NFR-USE-01) ---
        "Đang ở chế độ Code": "Currently in Code mode",
        "Đang ở chế độ View": "Currently in View mode",
        "Đang xem mã nguồn — bấm để sang chế độ View (⌥⌘V)":
            "Viewing the source \u{2014} click to switch to View mode (\u{2325}\u{2318}V)",
        "Đang ở chế độ View — bấm để quay về mã nguồn (⌥⌘V)":
            "In View mode \u{2014} click to go back to the source (\u{2325}\u{2318}V)",
        // --- Báo cáo sự cố (NFR-REL-03) ---
        "Tín hiệu: %@": "Signal: %@",
        "Lý do: %@": "Reason: %@",
        "Chi tiết: %@": "Detail: %@",
        "Mở báo cáo": "Open report",
        "GEditor đã đóng đột ngột lúc %@ — mở báo cáo để xem, không có gì được gửi đi.":
            "GEditor quit unexpectedly at %@ \u{2014} open the report to read it; nothing is sent anywhere.",
        """
        GEditor đã đóng đột ngột %d lần. Báo cáo gần nhất: %@ — mở để xem, \
        không có gì được gửi đi.
        """:
            """
            GEditor quit unexpectedly %d times. Latest report: %@ \u{2014} open it to read; \
            nothing is sent anywhere.
            """,
        "Chữ ghép (ligature) — tắt thì mỗi ký tự một ô":
            "Ligatures \u{2014} off keeps one cell per character",
        "Chuẩn hóa về NFC khi lưu": "Normalize to NFC on save",
        "Ngôn ngữ": "Language",
        "Nền": "Background",
        "Theo hệ thống": "Follow system",
        "Sáng": "Light",
        "Tối": "Dark",
        "Theme": "Theme",
        "Dùng preset Notepad++": "Use Notepad++ preset",
        "Về phím mặc định": "Reset to default keys",
        "Mở file cấu hình": "Open config file",
        "Xuất theme hiện tại": "Export current theme",
        "Đổi ngôn ngữ áp dụng đầy đủ ở lần mở app kế tiếp.":
            "Language change fully applies the next time the app opens.",
        "Phím mặc định trở lại ở lần mở app kế tiếp.":
            "Default keys return the next time the app opens.",

        // --- Panel phụ ---
        "Xem trước Markdown": "Markdown Preview",
        "Xem trước dựng bằng bộ Markdown của hệ thống: chưa dựng bảng và chưa tô màu khối mã.":
            "Rendered with the system Markdown engine: tables and code-block colouring are not supported yet.",
        "Thử biểu thức chính quy": "Regular Expression Tester",
        "Biểu thức": "Expression",
        "Văn bản thử": "Sample text",
        "Kết quả": "Results",
        "Kết quả khớp": "Match results",
        "Biểu thức này làm gì": "What this expression does",
        "Giải thích biểu thức": "Expression explanation",
        "Chế độ tìm kiếm": "Search mode",
        "Kết quả tìm kiếm": "Search results",
        "Không khớp chỗ nào": "No matches",
        " (đã cắt bớt)": " (truncated)",

        // --- Nhãn VoiceOver cho nhóm và view tự vẽ (NFR-USE-03) ---
        "Bản đồ tài liệu": "Document map",
        "Thanh tab": "Tab bar",
        "Hàng tiêu đề cột": "Column header row",
        "Không có cột nào": "No columns",
        "Cây thư mục workspace": "Workspace file tree",
        "Danh sách hàm và lớp": "Function and class list",
        "Kết quả tìm trong thư mục": "Find-in-folder results",
        "Bảng dữ liệu CSV": "CSV data table",
        "Bàn làm sạch dữ liệu": "Data clean-up bench",
        "Truy vấn JSONPath": "JSONPath query",
        "Danh sách lỗi dữ liệu": "Data issue list",

        // FR-KNW-921 — nhập & so điểm retrieval ngoài.
        "Bộ đánh giá golden set…": "Golden set\u{2026}",
        "So với điểm ngoài (JSONL)…": "Compare with external scores (JSONL)\u{2026}",
        "Chọn tệp điểm ngoài (JSONL: query, chunk_id, score)": "Choose the external score file (JSONL: query, chunk_id, score)",

        // FR-KNW-916 — tái cấu trúc đồ thị.
        "Đổi tên node đang chọn": "Rename the selected node",
        "Gộp các node đang chọn": "Merge the selected nodes",
        "Tách node đang chọn": "Split the selected node",
        "Trích subgraph đang chọn ra tab mới": "Extract the selected subgraph to a new tab",
        "Không có gì để đổi": "Nothing to change",
        "%@ — áp %d thay đổi?": "%@ \u{2014} apply %d {one=change|other=changes}?",
        "%@: %d thay đổi · Cmd-Z hoàn tác cả cụm": "%@: %d {one=change|other=changes} \u{00B7} Cmd-Z undoes the whole set",
        "Đặt con nháy lên ĐÚNG MỘT node rồi chạy lại": "Put the caret on EXACTLY ONE node, then run again",
        "Đổi tên «%@»": "Rename \u{201C}%@\u{201D}",
        "Mọi cạnh và nhãn tham chiếu node này sẽ đổi theo.": "Every edge and label referring to this node changes with it.",
        "Đổi tên node": "Rename node",
        "Bôi đen từ HAI node trở lên rồi chạy lại": "Select TWO or more nodes, then run again",
        "Dạng chuẩn «%@» — hay gặp nhất, dài nhất, còn dấu": "Canonical form \u{201C}%@\u{201D} \u{2014} most frequent, longest, keeps diacritics",
        "Gộp node": "Merge nodes",
        "Bôi đen những DÒNG CẠNH muốn chuyển rồi chạy lại": "Select the EDGE LINES to move, then run again",
        "Mọi dòng đã chọn phải cùng chạm ĐÚNG MỘT node — bôi đen thêm dòng cạnh": "Every selected line must touch EXACTLY ONE common node \u{2014} select more edge lines",
        "Tách «%@» — chuyển %d cạnh": "Split \u{201C}%@\u{201D} \u{2014} move %d {one=edge|other=edges}",
        "Cạnh tới: %@": "Edges to: %@",
        "Tách node": "Split node",
        "Tài liệu chưa lưu — tệp trích cần chỗ để nằm cạnh": "Unsaved document \u{2014} the extracted file needs a place to sit next to",
        "Bôi đen phần đồ thị muốn trích rồi chạy lại": "Select the part of the graph to extract, then run again",

        // FR-KNW-923 — gom biến thể entity.
        "Gom biến thể entity → bảng duyệt": "Cluster entity variants \u{2192} review table",
        "Áp bảng duyệt đã sửa": "Apply the edited review table",
        "Tài liệu chưa lưu — bảng duyệt cần nằm cạnh tệp đồ thị": "Unsaved document \u{2014} the review table must sit next to the graph file",
        "Không tìm thấy biến thể nào để gom": "No variants found to cluster",
        "%d cụm biến thể — sửa cột «canonical» rồi chạy «Áp bảng duyệt»": "%d variant {one=cluster|other=clusters} \u{2014} edit the \u{201C}canonical\u{201D} column, then run \u{201C}Apply\u{201D}",
        "Chưa có bảng duyệt «%@» — chạy «Gom biến thể entity» trước": "No review table \u{201C}%@\u{201D} yet \u{2014} run \u{201C}Cluster entity variants\u{201D} first",
        "Bảng duyệt không đọc được: %@": "Could not read the review table: %@",
        "Bảng duyệt không có dòng nào cần đổi": "The review table has no row to change",
        "Không có chỗ nào trên đồ thị khớp bảng duyệt": "Nothing in the graph matches the review table",
        "Gom biến thể entity": "Cluster entity variants",
        "Đã áp %d thay đổi · bảng alias và danh sách marker ghi cạnh tệp": "Applied %d {one=change|other=changes} \u{00B7} alias table and marker list written next to the file",
        "Áp %d thay đổi lên đồ thị?": "Apply %d {one=change|other=changes} to the graph?",
        "%d alias → dạng chuẩn.": "%d {one=alias|other=aliases} \u{2192} canonical form.",
        "GỘP node (không hoàn tác được bằng cách gõ lại):": "MERGES nodes (cannot be undone by retyping):",
        "%d alias không có trên đồ thị, bị bỏ qua.": "%d {one=alias is|other=aliases are} not in the graph and skipped.",

        // FR-KNW-920 — Chunk \u{2194} Entity \u{2194} Graph.
        "GraphRAG…": "GraphRAG\u{2026}",
        "Phân tích phủ Chunk ↔ Entity": "Chunk \u{2194} entity coverage",
        "Xuất gói ngữ cảnh (JSONL)": "Export context package (JSONL)",
        "Phủ Chunk ↔ Entity ↔ Graph": "Chunk \u{2194} entity \u{2194} graph coverage",
        "- %d entity · %d chunk · %.0f%% entity được nhắc · %.0f%% chunk có entity": "- %d {one=entity|other=entities} \u{00B7} %d {one=chunk|other=chunks} \u{00B7} %.0f%% entities mentioned \u{00B7} %.0f%% chunks carry an entity",
        "Entity không chunk nào nhắc tới": "Entities no chunk mentions",
        "Chunk mồ côi (không chứa entity nào)": "Orphan chunks (no entity inside)",
        "Node đồ thị không có entity đối ứng": "Graph nodes with no matching entity",
        "không có": "none",
        "Phương pháp": "Method",
        "Không dựng được ánh xạ Chunk ↔ Entity": "Could not build the chunk \u{2194} entity map",

        // FR-KNW-924 — Graph Quality Report.
        "Chấm sức khoẻ đồ thị": "Score graph health",
        "sức khoẻ đồ thị": "graph health",
        "Sức khoẻ %@/100 · %d lỗi · %d đảo · %d mồ côi": "Health %@/100 \u{00B7} %d {one=issue|other=issues} \u{00B7} %d {one=island|other=islands} \u{00B7} %d isolated",

        // FR-KNW-925 — truy hồi lai BM25 × đồ thị.
        "Lai với đồ thị": "Hybrid with graph",
        "α = 1: bỏ hẳn tín hiệu đồ thị, kết quả trùng BM25 thuần": "\u{03B1} = 1: graph signal off entirely, results match plain BM25",
        "α cao: đồ thị chỉ chỉnh nhẹ thứ hạng của BM25": "high \u{03B1}: the graph only nudges BM25\u{2019}s ranking",
        "α quanh mặc định 0,7: BM25 dẫn, đồ thị chỉnh": "\u{03B1} near the 0.7 default: BM25 leads, the graph adjusts",
        "α thấp: đồ thị dẫn, BM25 chỉ phá hoà": "low \u{03B1}: the graph leads, BM25 only breaks ties",
        "α = 0: chỉ tín hiệu đồ thị; chunk không entity nào đều bằng điểm": "\u{03B1} = 0: graph signal only; chunks with no entity all tie",
        "Tài liệu chưa lưu — phép lai cần một tệp đồ thị đặt cạnh corpus": "Unsaved document \u{2014} the hybrid needs a graph file next to the corpus",
        "Không thấy tệp đồ thị «%@» — phép lai cần nó để có tín hiệu": "No graph file \u{201C}%@\u{201D} \u{2014} the hybrid needs it to have any signal",
        "lai %.1f ms · %@": "hybrid %.1f ms \u{00B7} %@",

        // FR-KNW-914 — thuật toán đồ thị.
        "Thuật toán…": "Algorithm\u{2026}",
        "PageRank (độ dày viền)": "PageRank (border thickness)",
        "Cộng đồng (màu nền)": "Communities (fill colour)",
        "Thành phần liên thông": "Connected components",
        "Xuất bảng node ra tab mới": "Export node table to a new tab",
        "%d thành phần · lớn nhất %d node · %d node mồ côi": "%d {one=component|other=components} \u{00B7} largest %d {one=node|other=nodes} \u{00B7} %d isolated",

        // FR-KNW-913 — thực thi openCypher tập con.
        "Tài liệu này không phải đồ thị DOT": "This document is not a DOT graph",
        "Không dựng được bảng node/cạnh: %@": "Could not build the node/edge tables: %@",
        "%d hàng · %@": "%d {one=row|other=rows} \u{00B7} %@",

        // FR-KNW-926 — Golden Set Builder.
        "Gán nhãn": "Label",
        "Ghi chú (tuỳ chọn)": "Note (optional)",
        "Lưu record": "Save record",
        "Xuất CSV": "Export CSV",
        "Tài liệu chưa lưu — bộ đánh giá cần nằm cạnh tệp corpus": "Unsaved document \u{2014} the evaluation set must sit next to the corpus file",
        "Không nạp được bộ đánh giá: %@": "Could not load the evaluation set: %@",
        "Không lưu được: %@": "Could not save: %@",
        "Bộ đánh giá chưa có record nào": "The evaluation set has no records yet",
        "Không ghi được: %@": "Could not write: %@",

        // FR-KNW-905 — Graph Preview cho DOT.
        "Tài liệu này không phải tệp .mmd, không phải DOT, và chưa có khối mermaid.": "This document is not a .mmd file, not DOT, and has no mermaid block.",
        "%d node · %d cạnh · ⚠ %@": "%d {one=node|other=nodes} \u{00B7} %d {one=edge|other=edges} \u{00B7} \u{26A0} %@",

        // FR-MMD-004 — soạn thảo sơ đồ Mermaid trực quan.
        "Sơ đồ Mermaid: thêm phần tử…": "Mermaid diagram: add element\u{2026}",
        "Sơ đồ Mermaid: nối hai phần tử đang chọn": "Mermaid diagram: connect the two selected elements",
        "Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…": "Mermaid diagram: edit the selected element\u{2019}s label\u{2026}",
        "Sơ đồ Mermaid: xoá phần tử đang chọn": "Mermaid diagram: delete the selected element",
        "Sơ đồ Mermaid: đưa message lên trên": "Mermaid diagram: move message up",
        "Sơ đồ Mermaid: đưa message xuống dưới": "Mermaid diagram: move message down",
        "Thêm phần tử": "Add element",
        "Thêm participant": "Add participant",
        "Thêm mục": "Add item",
        "Thêm mục sơ đồ": "Add diagram item",
        "Sửa mục sơ đồ": "Edit diagram item",
        "Xoá mục sơ đồ": "Delete diagram item",
        "Xoá phần tử": "Delete element",
        "Sửa nhãn": "Edit label",
        "Đổi thứ tự message": "Reorder message",
        "Tên mục": "Item name",
        "Mục mới": "New item",
        "Tên mục hiện trên sơ đồ.": "The item name shown on the diagram.",
        "Bảng thuộc tính sơ đồ": "Diagram property table",
        "Tài liệu này không có khối mermaid nào": "This document has no mermaid block",
        "Định danh trong mã sơ đồ — không dấu cách. Nhãn sửa sau bằng double-click.": "The identifier in the diagram source \u{2014} no spaces. Edit the label later by double-clicking.",
        "Để trống thì hiện chính định danh.": "Leave empty to show the identifier itself.",
        "Chỉ đổi NHÃN hiện trên hình; định danh phần tử giữ nguyên.": "Changes only the LABEL shown on the diagram; the element identifier stays the same.",
        "Không rõ «%@» là phần tử nào": "Cannot tell which element \u{201C}%@\u{201D} is",
        "Bôi đen ĐÚNG HAI phần tử rồi chạy lại": "Select EXACTLY TWO elements, then run again",
        "Đặt con nháy lên ĐÚNG MỘT phần tử rồi chạy lại": "Put the caret on EXACTLY ONE element, then run again",
        "Chọn MỘT phần tử để xoá, hoặc hai phần tử có cạnh nối": "Select ONE element to delete, or two elements joined by an edge",
        "Xoá «%@» và %d cạnh chạm nó?": "Delete \u{201C}%@\u{201D} and the %d {one=edge|other=edges} touching it?",
        "Node ở đầu kia của những cạnh ấy được giữ lại — chúng được khai lại kèm nhãn nếu câu lệnh cạnh là chỗ duy nhất khai chúng.": "Nodes at the far end of those edges are kept \u{2014} they are re-declared with their labels if the edge statement was the only place declaring them.",
        "Sơ đồ «%@» chỉ soạn text — %@": "The \u{201C}%@\u{201D} diagram is text-only \u{2014} %@",
        "%@: kéo giữa hai phần tử để nối, double-click để sửa nhãn": "%@: drag between two elements to connect them, double-click to edit a label",
        "%@: kéo giữa hai participant để thêm message; đổi thứ tự bằng menu Công cụ": "%@: drag between two participants to add a message; reorder from the Tools menu",
        "%@: sửa trong bảng thuộc tính bên dưới": "%@: edit in the property table below",
        "Soạn trực quan đã bật": "Visual editing is on",
        "%@ · %d mục — sửa thẳng trong bảng, mỗi ô một bước hoàn tác": "%@ \u{00B7} %d {one=item|other=items} \u{2014} edit in place; each cell is one undo step",
        "Với pie là một con số; với gantt là phần sau dấu hai chấm.": "For pie, a number; for gantt, everything after the colon.",

        // FR-MMD-008 — tách khối sơ đồ ra tệp riêng và nhúng ngược.
        "Sơ đồ Mermaid: tách khối ra tệp .mmd…": "Mermaid diagram: split block into a .mmd file\u{2026}",
        "Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại": "Mermaid diagram: embed the referenced file back",
        "Tách khối sơ đồ": "Split diagram block",
        "Nhúng khối sơ đồ": "Embed diagram block",
        "Tách khối sơ đồ ra tệp riêng": "Split the diagram block into its own file",
        "Tệp đặt CẠNH tài liệu; khối trong tài liệu giữ một dòng tham chiếu để sửa một nơi.": "The file sits NEXT TO the document; the block keeps a one-line reference so it is edited in one place.",
        "Tài liệu chưa lưu — tệp sơ đồ cần chỗ để nằm cạnh": "Unsaved document \u{2014} the diagram file needs somewhere to sit next to",
        "Đã có tệp «%@» — chọn tên khác": "The file \u{201C}%@\u{201D} already exists \u{2014} pick another name",
        "Đã tách ra «%@» — khối giữ một dòng tham chiếu": "Split into \u{201C}%@\u{201D} \u{2014} the block keeps a one-line reference",
        "Mở tệp": "Open file",
        "Đã nhúng «%@» trở lại; tệp vẫn còn trên đĩa": "Embedded \u{201C}%@\u{201D} back; the file is still on disk",
        "Khối này chứa sơ đồ thật, không phải một tham chiếu": "This block holds a real diagram, not a reference",
        "Khối này tham chiếu «%@» — mở tệp ấy để sửa": "This block references \u{201C}%@\u{201D} \u{2014} open that file to edit it",
        "Không đọc được tệp sơ đồ %@": "Could not read the diagram file %@",

        // FR-KNW-915 — soạn thảo Graph trực quan.
        "Soạn trực quan": "Visual editing",
        "Kéo từ node này sang node kia để thêm cạnh; double-click để sửa nhãn. Mỗi thao tác một bước hoàn tác.": "Drag from one node to another to add an edge; double-click to edit a label. Each action is one undo step.",
        "Soạn trực quan: kéo giữa hai node để thêm cạnh, double-click để sửa nhãn": "Visual editing: drag between two nodes to add an edge, double-click to edit a label",
        "Soạn trực quan đã tắt": "Visual editing is off",
        "Thêm node…": "Add node\u{2026}",
        "Thêm cạnh giữa hai node đang chọn…": "Add an edge between the two selected nodes\u{2026}",
        "Sửa nhãn node đang chọn…": "Edit the selected node\u{2019}s label\u{2026}",
        "Xoá node/cạnh đang chọn": "Delete the selected node or edge",
        "Thêm node": "Add node",
        "Thêm cạnh": "Add edge",
        "Sửa nhãn node": "Edit node label",
        "Xoá node": "Delete node",
        "Xoá cạnh": "Delete edge",
        "Cmd-Z hoàn tác": "Cmd-Z to undo",
        "Tài liệu đang ở chế độ chỉ đọc": "The document is read-only",
        "Nhãn của «%@»": "Label of \u{201C}%@\u{201D}",
        "Chỉ đổi NHÃN hiện trên hình; định danh node giữ nguyên.": "Changes only the LABEL shown on the diagram; the node identifier stays the same.",
        "Không rõ «%@» là node nào": "Cannot tell which node \u{201C}%@\u{201D} is",
        "Định danh node trong tệp DOT. Nhãn sửa sau bằng double-click trên hình.": "The node identifier in the DOT file. Edit the label later by double-clicking on the diagram.",
        "Bôi đen ĐÚNG HAI node rồi chạy lại": "Select EXACTLY TWO nodes, then run again",
        "Chọn MỘT node để xoá node, hoặc hai node có cạnh nối": "Select ONE node to delete a node, or two nodes joined by an edge",
        "Xoá node «%@» và %d cạnh chạm nó?": "Delete node \u{201C}%@\u{201D} and the %d {one=edge|other=edges} touching it?",
        "Giữ lại cạnh treo thì DOT tự sinh lại node từ chính những cạnh ấy — node vừa xoá sẽ hiện lại ở lần vẽ sau.": "Leaving dangling edges makes DOT re-create the node from those very edges \u{2014} the node you just deleted would reappear on the next render.",

        // FR-KNW-918 · FR-KNW-919 — Retrieval Lab và đánh giá golden set.
        "Phòng thí nghiệm truy hồi BM25": "BM25 retrieval lab",
        "Câu hỏi — Enter để tìm": "Question \u{2014} press Return to search",
        "Đánh giá…": "Evaluate\u{2026}",
        "Đang dựng chỉ mục": "Building the index",
        "Không chunk nào khớp": "No chunk matches",
        "kết quả trên": "results out of",
        "k1 = 0: mỗi từ chỉ tính MỘT lần dù xuất hiện bao nhiêu lần": "k1 = 0: each term counts ONCE no matter how often it appears",
        "k1 thấp: lặp từ nhiều lần gần như không cộng thêm điểm": "low k1: repeating a term adds almost nothing",
        "k1 quanh mặc định 1,2: lặp từ có cộng điểm nhưng giảm dần": "k1 near the 1.2 default: repeats add score with diminishing returns",
        "k1 cao: chunk lặp một từ nhiều lần được thưởng mạnh": "high k1: chunks that repeat a term are rewarded strongly",
        "b = 0: bỏ qua độ dài, chunk dài không bị phạt": "b = 0: length is ignored, long chunks are not penalised",
        "b thấp: chunk dài chỉ bị phạt nhẹ": "low b: long chunks are only lightly penalised",
        "b quanh mặc định 0,75: chunk dài bị phạt vừa phải": "b near the 0.75 default: long chunks are moderately penalised",
        "b = 1: phạt tối đa theo độ dài, chunk ngắn được ưu ái": "b = 1: maximum length penalty, short chunks are favoured",
        "JSONL: phòng thí nghiệm truy hồi…": "JSONL: retrieval lab\u{2026}",
        "Tài liệu chưa lưu — chỉ mục BM25 nằm cạnh tệp corpus nên cần một đường dẫn": "Unsaved document \u{2014} the BM25 index lives next to the corpus file, so it needs a path",
        "Tệp này không phải JSONL — Retrieval Lab chạy trên corpus chunk": "This file is not JSONL \u{2014} the Retrieval Lab works on chunk corpora",
        "Không dựng được chỉ mục BM25 cho tệp này": "Could not build a BM25 index for this file",
        "Tài liệu chưa lưu — cần đường dẫn corpus để sinh báo cáo": "Unsaved document \u{2014} a corpus path is needed to generate the report",
        "Chọn bộ đánh giá (CSV hoặc JSONL: câu hỏi + id chunk kỳ vọng)": "Choose an evaluation set (CSV or JSONL: question + expected chunk ids)",
        "Đánh giá truy hồi": "Retrieval evaluation",
        "Sửa k1, b hoặc k ở trên rồi xem lại để so hai cấu hình; thêm khối «compare» để chạy song song hai bộ tham số trên cùng bộ đánh giá.": "Change k1, b or k above and re-render to compare two configurations; add a \u{201C}compare\u{201D} block to run two parameter sets side by side on the same evaluation set.",

        // FR-KNW-901 · FR-KNW-902 — chế độ JSONL và Chunk Inspector.
        "Lỗi": "Errors",
        "   (%d…%d, trung bình %.0f)": "   (%d\u{2026}%d, mean %.0f)",
        "Chế độ JSONL": "JSONL mode",
        "Bản ghi": "Record",
        "Chi tiết": "Detail",
        "Bản ghi ở dòng": "Record at line",
        "không phải JSON hợp lệ": "is not valid JSON",
        "bản ghi": "records",
        "dòng trắng": "blank lines",
        "không phải đối tượng": "not objects",
        "bảng hiện": "table shows",
        "ĐÃ HUỶ giữa chừng": "CANCELLED part-way",
        "Không lọc": "No filter",
        "bản ghi khớp bộ lọc": "records match the filter",
        "Đưa con nháy tới một dòng để xem bản ghi": "Move the caret to a line to see its record",
        "Không có bản ghi nào hỏng": "No malformed records",
        "Chưa soi. Chạy lại lệnh «JSONL: soi chunk» sau khi kiểm xong.": "Not inspected yet. Run \u{201C}JSONL: inspect chunks\u{201D} once the check finishes.",
        "trường văn bản": "text field",
        "SCHEMA (đoán — sửa được bằng cách chọn trường khác)": "SCHEMA (a guess \u{2014} pick another field to change it)",
        "văn bản": "text",
        "định danh": "identifier",
        "metadata lồng": "nested metadata",
        "TRƯỜNG": "FIELDS",
        "phủ": "present in",
        "nhiều kiểu": "mixed types",
        "ĐỘ DÀI — ký tự": "LENGTH \u{2014} characters",
        "ĐỘ DÀI — từ": "LENGTH \u{2014} words",
        "ĐỘ DÀI — token ước lượng": "LENGTH \u{2014} estimated tokens",
        "RỖNG VÀ TRÙNG": "EMPTY AND DUPLICATE",
        "chunk rỗng": "empty chunks",
        "dòng": "lines",
        "nhóm trùng chính xác": "exact-duplicate groups",
        "dòng không đọc được, không vào thống kê": "unreadable lines, left out of the statistics",
        "PHƯƠNG PHÁP": "METHOD",
        "«ký tự» đếm theo ký tự Unicode (scalar), không theo cụm hiển thị": "\u{201C}characters\u{201D} counts Unicode scalars, not display clusters",
        "«từ» tách theo khoảng trắng ASCII": "\u{201C}words\u{201D} split on ASCII whitespace",
        "«token» đếm bằng bộ tách âm tiết — KHÔNG phải bộ tách của model": "\u{201C}tokens\u{201D} uses the syllable tokenizer \u{2014} NOT the model\u{2019}s",
        "«trùng» là trùng CHÍNH XÁC; trùng GẦN nằm ở khối ```quality": "\u{201C}duplicate\u{201D} means EXACT; NEAR-duplicates live in the ```quality block",
        "chunk": "chunks",
        "JSONL: kiểm và soi chunk…": "JSONL: check and inspect chunks\u{2026}",

        // --- Khung xem ảnh · PDF · Office · file nén ---
        // Tên loại tệp (`MediaKind.displayName`, nằm ở lõi nên bộ đếm nợ dịch không thấy chúng
        // — vẫn phải có mặt ở đây, vì chỗ dùng có bọc `L()`).
        "Ảnh": "Image",
        "PDF": "PDF",
        "Tài liệu Word": "Word document",
        "Bảng tính Excel": "Excel spreadsheet",
        "Bản trình chiếu PowerPoint": "PowerPoint presentation",
        "File nén": "Archive",

        // Chung cho khung ảnh và khung PDF.
        "Vừa khung": "Fit",

        // Ảnh.
        "Chép ảnh": "Copy image",
        "Xoay": "Rotate",
        "Không đọc được ảnh «%@»": "Cannot read image \u{201C}%@\u{201D}",
        "Đã chép ảnh vào clipboard": "Image copied to the clipboard",

        // PDF.
        "Bôi vàng": "Highlight",
        "Gạch chân": "Underline",
        "Ghi chú…": "Note\u{2026}",
        "Bỏ chú thích": "Clear annotations",
        "Lấy chữ ra tab mới": "Extract text to a new tab",
        "Lưu bản có chú thích…": "Save annotated copy\u{2026}",
        "Tìm trong PDF": "Find in PDF",
        "Thêm": "Add",
        "Trang %d/%d": "Page %d of %d",
        "Trang %d": "Page %d",
        "Kết quả %d/%d": "Match %d of %d",
        "0 kết quả": "No matches",
        "Không đọc được PDF «%@»": "Cannot read PDF \u{201C}%@\u{201D}",
        "PDF này có mật khẩu — chưa mở được nội dung":
            "This PDF is password-protected \u{2014} its contents cannot be opened",
        "Không thấy «%@» trong tài liệu": "\u{201C}%@\u{201D} is not in this document",
        "Đã bôi vàng": "Highlighted",
        "Đã gạch chân": "Underlined",
        "Hãy bôi đen một đoạn chữ trước": "Select some text first",
        "Đã thêm ghi chú": "Note added",
        "Trang này chưa có chú thích nào": "This page has no annotations",
        "Đã bỏ %d chú thích trên trang này": "Removed %d {one=annotation|other=annotations} from this page",
        "PDF này không có tầng chữ — nhiều khả năng là bản quét ảnh":
            "This PDF has no text layer \u{2014} it is most likely a scan",
        "Không ghi được tệp": "Cannot write the file",
        "Tệp vừa ghi mở lại KHÔNG đúng — đừng dùng bản này":
            "The file just written does NOT reopen correctly \u{2014} do not use this copy",
        "Đã lưu %@ · %d trang": "Saved %@ \u{00B7} %d {one=page|other=pages}",

        // File nén.
        "Tên": "Name",
        "Kích thước": "Size",
        "Đã nén": "Compressed",
        "Tỉ lệ": "Ratio",
        "Sửa lúc": "Modified",
        "Mở mục đang chọn": "Open selected entry",
        "Bung ra thư mục…": "Extract to folder\u{2026}",
        "Bung vào đây": "Extract here",
        "%d mục": "%d {one=entry|other=entries}",
        "giải nén ra %@": "expands to %@",
        "— ruột của tệp Office là file nén, đây là các phần bên trong":
            "\u{2014} an Office file is an archive; these are the parts inside it",
        "Đã bung %d mục": "Extracted %d {one=entry|other=entries}",
        "%d mục hỏng": "%d {one=entry|other=entries} failed",
        "%d mục bị TỪ CHỐI vì đường dẫn thoát ra ngoài":
            "%d {one=entry|other=entries} REFUSED \u{2014} their paths escape the destination folder",
        "Không mở được mục này": "Cannot open this entry",

        // Ghi ngược vào tệp Office.
        "Chưa ghi ngược được vào tệp %@ — hãy dùng «Lưu thành…»":
            "Cannot write back into a %@ yet \u{2014} use \u{201C}Save As\u{2026}\u{201D}",
        "Không có gì đổi": "Nothing changed",
        "Đã ghi %d ô vào %@": "Wrote %d {one=cell|other=cells} into %@",
        "Đã ghi %d đoạn vào %@": "Wrote %d {one=paragraph|other=paragraphs} into %@",
        "Không ghi được vào tệp — bản gốc còn nguyên":
            "Cannot write into the file \u{2014} the original is untouched",

        // Nhãn hoàn tác của bài tự kiểm. Nó KHÔNG chỉ nằm trong bài kiểm: mọi nhãn hoàn tác đều
        // hiện trên menu Sửa ("Hoàn tác …"), nên nó là chữ người dùng đọc được.
        "dựng bài": "set up test case",

        "Không ghi được settings.json": "Cannot write settings.json",

        // --- Công cụ trang PDF · sheet Excel · bộ phát · xem nhị phân (03/09/2026) ---
        "Xoay trái": "Rotate Left",
        "Xoay phải": "Rotate Right",
        "Trang lên": "Move Page Up",
        "Trang xuống": "Move Page Down",
        "Xoá trang…": "Delete Pages…",
        "Xoá trang": "Delete Pages",
        "Trích trang…": "Extract Pages…",
        "Trích trang ra tệp mới": "Extract Pages to New File",
        "Gộp tệp PDF…": "Merge PDF File…",
        "Tách tệp…": "Split File…",
        "Tách tệp PDF": "Split PDF File",
        "Xuất ảnh…": "Export Images…",
        "Xuất trang ra ảnh PNG": "Export Pages as PNG Images",
        "Hoàn tác trang": "Undo Page Edit",
        "Lưu bản đã sửa…": "Save Edited Copy…",
        "Phát": "Play",
        "Tạm dừng": "Pause",
        "Xem bình thường": "Normal View",
        "Chọn sheet": "Choose Sheet",
        "Mở sheet": "Open Sheet",
        "Bỏ và đổi sheet": "Discard and Switch Sheet",
        "Bảng tính có %d sheet.": "The workbook has %d sheets.",
        "Bảng tính này chỉ có một sheet: «%@»": "This workbook has only one sheet: “%@”",
        "Bỏ phần chưa lưu của sheet này?": "Discard unsaved changes in this sheet?",
        "Đổi sheet sẽ thay toàn bộ nội dung tab. Phần vừa sửa mà chưa ⌘S sẽ mất.": "Switching sheets replaces the whole tab. Anything edited but not saved with ⌘S is lost.",
        "Chọn tệp PDF cần gộp vào": "Choose a PDF file to merge in",
        "Chọn thư mục ghi ảnh": "Choose a folder for the images",
        "Chọn chỗ ghi. Tệp thứ hai ghi cạnh tệp này.": "Choose where to save. The second file is written next to this one.",
        "Tài liệu có %d trang. Nhập trang cần xoá, ví dụ 2-4,7": "The document has %d pages. Enter the pages to delete, e.g. 2-4,7",
        "Tài liệu có %d trang. Nhập trang cần trích, ví dụ 1-3,8": "The document has %d pages. Enter the pages to extract, e.g. 1-3,8",
        "Tài liệu có %d trang. Nhập trang cần xuất, ví dụ 1-3": "The document has %d pages. Enter the pages to export, e.g. 1-3",
        "Tài liệu có %d trang. Nhập phần tách ra, ví dụ 1-5; phần còn lại ghi thành tệp thứ hai.": "The document has %d pages. Enter the part to split off, e.g. 1-5; the rest becomes a second file.",
        "Đã xoay trang %d": "Rotated page %d",
        "Đã xoá trang %@ · còn %d trang": "Deleted pages %@ · %d pages left",
        "Đã gộp %d trang từ «%@»": "Merged %d pages from “%@”",
        "Đã tách thành %@ (%d trang) và %@ (%d trang)": "Split into %@ (%d pages) and %@ (%d pages)",
        "Đã ghi %@ — %@ · %d trang": "Wrote %@ — %@ · %d pages",
        "Đã xuất %d ảnh vào %@": "Exported %d images to %@",
        "Chỉ xuất được %d/%d ảnh": "Only %d of %d images were exported",
        "Đã hoàn tác một thao tác trang": "Undid one page operation",
        "Không còn thao tác trang nào để hoàn tác": "No page operations left to undo",
        "Không xoá được TẤT CẢ trang — một PDF phải còn ít nhất một trang": "Cannot delete ALL pages — a PDF must keep at least one page",
        "Phần tách ra là toàn bộ tài liệu — không có gì để tách": "That range is the whole document — nothing to split off",
        "«%@» có mật khẩu — chưa gộp được": "“%@” is password-protected — cannot merge it",
        "«%@» không có trang nào": "“%@” has no pages",
        "Đã ở trang đầu": "Already at the first page",
        "Đã ở trang cuối": "Already at the last page",
        "· đã sửa, chưa lưu": "· edited, not saved",
        "Ảnh động · %d khung": "Animated image · %d frames",
        "Tài liệu chưa lưu — không có tệp trên đĩa để xem nhị phân": "Unsaved document — there is no file on disk to view in binary",
        "Lệnh này chỉ dùng cho bảng tính Excel": "This command only works with Excel workbooks",
        "Không đọc được danh sách sheet": "Could not read the list of sheets",
        "Không có sheet «%@»": "There is no sheet named “%@”",
        "Không đọc được sheet «%@»": "Could not read sheet “%@”",
        "Sheet «%@» · %d hàng": "Sheet “%@” · %d rows",
        "phần còn lại": "the remainder",

        // --- Cửa sổ trợ giúp · khung nhị phân · bộ phát (03/09/2026) ---
        "Lưu ý": "Note",
        "Cẩn thận": "Caution",
        "Xem thêm": "See also",
        "Chép": "Copy",
        "Đã chép": "Copied",
        "Chép đoạn mã mẫu": "Copy the sample code",
        "Tìm trong trợ giúp": "Search help",
        "Lùi": "Back",
        "Bắt đầu dùng": "Get Started",
        "Không mở cửa sổ này khi khởi động nữa": "Don't show this window at startup",
        "Bản dịch trợ giúp cho ngôn ngữ này chưa có — đang hiện bản tiếng Việt.": "Help is not translated into this language yet — showing the Vietnamese text.",
        "Tới offset (vd 1F400 hoặc 0x1F400)": "Go to offset (e.g. 1F400 or 0x1F400)",
        "Chép dòng đã chọn": "Copy selected rows",
        "Đã chép %d dòng": "Copied %d rows",
        "Không đọc được «%@»": "Could not read “%@”",
        "Tệp rỗng": "Empty file",
        "Không đọc được offset «%@»": "Could not read the offset “%@”",
        "Offset 0x%@ vượt quá cỡ tệp": "Offset 0x%@ is past the end of the file",
        "Mở bằng ứng dụng khác…": "Open with Another App…",
        "%d kênh": "%d channels",
        "Không phát được «%@»": "Cannot play “%@”",
        "Không phát được — %@": "Cannot play — %@",
        "macOS không có bộ giải mã sẵn cho định dạng %@ — đây là giới hạn của hệ điều hành, không phải tệp hỏng.": "macOS has no built-in decoder for the %@ format — that is an operating-system limit, not a broken file.",
        "Nội dung tệp vẫn xem được ở chế độ nhị phân, hoặc mở bằng một ứng dụng có bộ giải mã riêng.": "You can still view the bytes in binary mode, or open it with an app that has its own decoder.",

        // --- Ký · sửa chữ · biểu mẫu AcroForm (03/09/2026) ---
        "Ký…": "Sign…",
        "Sửa chữ…": "Edit Text…",
        "Sửa chữ": "Edit Text",
        "Vẽ đè": "Draw Over",
        "Ô chưa điền": "Next Empty Field",
        "Xoá nội dung đã điền": "Clear Filled Values",
        "Tệp này không có ô biểu mẫu nào": "This file has no form fields",
        "Đã xoá nội dung của %d ô biểu mẫu": "Cleared %d form fields",
        "Mọi ô biểu mẫu đều đã có nội dung": "Every form field already has a value",
        "Còn %d ô chưa điền": "%d fields still empty",
        "Biểu mẫu điền được: %d ô. Gõ thẳng vào ô, rồi «Lưu bản đã sửa…»": "Fillable form: %d fields. Type straight into them, then “Save Edited Copy…”",
        "Chọn ảnh chữ ký (nền trong suốt thì đẹp nhất)": "Choose a signature image (transparent background looks best)",
        "Không dựng được trang có chữ ký": "Could not build the signed page",
        "Đã chèn chữ ký vào trang %d": "Inserted the signature on page %d",
        "Hãy bôi chọn phần chữ cần sửa trước": "Select the text you want to change first",
        "Vùng chọn quá nhỏ": "The selection is too small",
        "Chữ mới được VẼ ĐÈ lên vùng đã chọn bằng font hệ thống. Chữ cũ bị che chứ không bị xoá — nó vẫn trích ra được, nên đây không phải cách bôi đen.": "The new text is DRAWN OVER the selection using the system font. The old text is covered, not removed — it can still be extracted, so this is not redaction.",
        "Không dựng được trang đã sửa": "Could not build the edited page",
        "Đã vẽ đè chữ mới lên trang %d": "Drew the new text over page %d",

        // --- Chế độ View / Code (03/09/2026) ---
        "Đổi chế độ View / Code": "Switch View / Code",
        "Chưa có chế độ View dạng cây cho JSON · XML · YAML": "No tree View yet for JSON · XML · YAML",
        "Chưa có chế độ View dạng sơ đồ trong tab": "No in-tab diagram View yet",
        "Chưa có chế độ View dạng dàn ý cho PowerPoint": "No outline View yet for PowerPoint",
        "Tệp này chỉ có một chế độ hiển thị": "This file has only one display mode",

        // --- Cây cấu trúc JSON (03/09/2026) ---
        "%d nút": "%d nodes",
        "Không dựng được cây: %@": "Could not build the tree: %@",
        "Tài liệu quá lớn để dựng cây — dùng chế độ Code": "The document is too large to build a tree — use Code mode",

        // --- Trang tài liệu tự dựng (04/09/2026) ---
        "Không dựng được trang của tệp này — dùng chế độ Code.":
            "Could not build pages for this file \u{2014} use Code mode.",
        "Slide dựng từ chữ; hình và bố cục gốc chưa được vẽ lại.":
            "Slides are built from text; original images and layout are not redrawn yet.",
        "Vừa ngang": "Fit Width",
        "Thu nhỏ trang": "Zoom Out Page",
        "Phóng to trang": "Zoom In Page",

        // --- Tìm chữ trong trang đã dựng (04/09/2026) ---
        "Không tìm thấy «%@» trong tài liệu":
            "Could not find \u{201C}%@\u{201D} in this document",
        "Chỗ khớp %d/%d": "Match %d of %d",

        // --- Chọn và chép chữ trên trang (04/09/2026) ---
        "Chưa chọn chữ nào trên trang.": "No text is selected on the page.",
        "%d ký tự": "%d {one=character|other=characters}",
        "Mở tệp là vào thẳng chế độ View nếu tệp ấy có":
            "Open files straight into View mode when they have one",

        // --- Bốn mục cuối của thanh trạng thái được nối vào (05/09/2026) ---
        "Chế độ CSV": "CSV mode",
        "Dấu phân tách": "Delimiter",
        "Tự nhận diện": "Detect automatically",
        "Dấu phân tách: %@": "Delimiter: %@",
        "Theo đuôi tệp": "From file extension",
        "%d dấu cách": "%d {one=space|other=spaces}",
        "Tài liệu đang sửa được": "This document is editable",
        "Chỉ đọc vì đang theo dõi file — tắt theo dõi để sửa lại":
            "Read-only because the file is being followed — stop following to edit",
        "Chỉ đọc vì tệp trên đĩa không cho ghi":
            "Read-only because the file on disk is not writable",
        "Đã mở khoá — tài liệu sửa được": "Unlocked — the document is editable again",

        // Nhãn trợ năng của popup chọn ngôn ngữ sách (05/09/2026). VoiceOver đọc nó, nên nó
        // phải theo ngôn ngữ giao diện chứ không theo ngôn ngữ đang chọn trong popup.
        "Ngôn ngữ của sách trợ giúp": "Help book language",

        // Tên MỤC MENU của bốn lệnh mới. Menu là chỗ nợ dịch lộ ra rõ nhất — một dòng tiếng
        // Việt giữa menu tiếng Anh thì ai cũng thấy.
        "Nhân bản tệp": "Duplicate File",
        "Đổi tên tệp…": "Rename File…",
        "Chuyển tệp tới…": "Move File To…",
        "XML: đánh giá XPath…": "XML: Evaluate XPath…",

        // --- XPath và tự đóng thẻ (FR-FMT-505, 05/09/2026) ---
        "Đánh giá XPath": "Evaluate XPath",
        "Ví dụ: //don_hang/hang[2]/@ma · //*[@loai='A'] · count(//hang)":
            "For example: //order/item[2]/@code · //*[@kind='A'] · count(//item)",
        "Đánh giá": "Evaluate",
        "XPath không đọc được: %@": "Cannot read that XPath: %@",
        "XPath «%@» không khớp node nào": "XPath \u{201C}%@\u{201D} matched no nodes",
        "XPath «%@» — %d node": "XPath \u{201C}%@\u{201D} — %d {one=node|other=nodes}",
        "XPath «%@»: %d node": "XPath \u{201C}%@\u{201D}: %d {one=node|other=nodes}",

        // --- Nhân bản · đổi tên · chuyển tệp (FR-DOC-314, 05/09/2026) ---
        "Lưu tệp trước khi nhân bản.": "Save the file before duplicating it.",
        "Không nhân bản được": "Could not duplicate",
        "Đã nhân bản thành %@": "Duplicated as %@",
        "Lưu tệp trước khi đổi tên.": "Save the file before renaming it.",
        "Đổi tên tệp": "Rename File",
        "Tên hiện tại: %@": "Current name: %@",
        "Đổi tên": "Rename",
        "Tên tệp không hợp lệ": "That file name is not valid",
        "Đã có tệp tên %@ ở đó": "There is already a file named %@ there",
        "Lưu tệp trước khi chuyển.": "Save the file before moving it.",
        "Chuyển tới": "Move Here",
        "Thư mục đích đã có tệp tên %@": "The destination folder already has a file named %@",
        "Không chuyển được tệp": "Could not move the file",
        "Đã chuyển tới %@": "Moved to %@",
        "Bảng mã:": "Encoding:",
        "Xuống dòng:": "Line endings:",

        // --- Thụt lề theo ngôn ngữ (FR-CORE-009, 05/09/2026) ---
        "Riêng cho %@": "Just for %@",
        "    %d — dùng TAB": "    %d — use tabs",
        "    %d — dùng dấu cách": "    %d — use spaces",
        "    Bỏ khai riêng, dùng cài đặt chung": "    Remove override, use the global setting",
        "%@: thụt lề %d %@": "%@: indent %d %@",
        "TAB": "tabs",
        "dấu cách": "spaces",

        // --- Lịch sử lượt tìm và xuất kết quả (FR-SRCH-105, 05/09/2026) ---
        "Xuất": "Export",
        "Mở kết quả thành một tab văn bản — lưu lại bằng ⌘S":
            "Open the results as a text tab — save it with ⌘S",
        "Lượt tìm trước đó": "Earlier searches",
        "«%@» — %d kết quả": "\u{201C}%@\u{201D} — %d {one=result|other=results}",
        "Kết quả tìm «%@»": "Search results for \u{201C}%@\u{201D}",

        // --- Batch macro theo file mask (FR-AUTO-602, 05/09/2026) ---
        "Lọc tên tệp — ví dụ *.csv;*.log (để trống: mọi tệp văn bản)":
            "Filter file names — e.g. *.csv;*.log (empty: every text file)",
        "Thư mục %@ không có file văn bản nào": "Folder %@ has no text files",
        "Không tệp nào trong %@ khớp «%@»":
            "No file in %@ matches \u{201C}%@\u{201D}",

        // --- Cỡ tài liệu trên thanh trạng thái (FR-CORE-018, 05/09/2026) ---
        "%d byte · %d dòng": "%d bytes · %d {one=line|other=lines}",
        "%d byte · %d dòng — tệp quá lớn để đếm ký tự và từ":
            "%d bytes · %d {one=line|other=lines} — too large to count characters and words",
        "%d byte · %d ký tự · %d từ · %d dòng":
            "%d bytes · %d {one=character|other=characters} · %d {one=word|other=words} · "
            + "%d {one=line|other=lines}",

        // --- Đi tới dòng · cột · offset (FR-SRCH-111, 05/09/2026) ---
        // «Đi tới» đã có khoá ở trên (dòng nút của chính hộp này) — bảng dịch cấm khoá trùng,
        // và cổng trong `check-core-no-ui.sh` bắt được ngay.
        "Tài liệu có %d dòng, %d byte. Gõ số dòng, «dòng,cột», hoặc «@vị trí byte».":
            "This document has %d {one=line|other=lines}, %d bytes. "
            + "Type a line number, \u{201C}line,column\u{201D}, or \u{201C}@byte\u{201D}.",
        "12 · 12,5 · @1024": "12 · 12,5 · @1024",
        "Không hiểu «%@» — gõ số dòng, «dòng,cột», hoặc «@vị trí byte»":
            "Cannot read \u{201C}%@\u{201D} — type a line number, "
            + "\u{201C}line,column\u{201D}, or \u{201C}@byte\u{201D}",
    ]
}
