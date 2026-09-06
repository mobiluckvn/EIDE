// CẢ HAI MƯƠI bảng tra grammar, tách khỏi binary chính (ADR-08 §2.13).
//
// Trước 24/08/2026 ở đây chỉ có ba grammar nặng nhất (cpp, csharp, ruby) và tên "Heavy" nói
// đúng. Rồi link map cho thấy grammar chiếm **70,5 %** binary đã liên kết — 7,19 MB trên 10,20
// MB — trong khi GEditorCore chỉ 1,17 MB. Và `dlopen` hoá ra gần như KHÔNG phụ thuộc kích
// thước: một dylib 0,63 MB tốn 450 ms, một dylib 10,47 MB tốn 507 ms, vì phí là ~440 ms cố
// định cho mỗi tệp mới cộng ~7 ms mỗi MB.
//
// Hai số ấy cộng lại chỉ ra đúng một hình dạng đúng: **tất cả bảng tra vào MỘT dylib**. Tách
// nhỏ theo ngôn ngữ là làm tệ đi — ai mở ba ngôn ngữ trả ba lần 440 ms thay vì một lần.
//
// Kết quả đo (ADR-08 §2.13): binary chính 11,20 → 3,47 MB, khởi động nguội ~520 → ~396 ms.
//
// Cái giá, nói thẳng: ai mở một file CẦN TÔ MÀU trả một lần `dlopen` mỗi phiên. Ai chỉ mở
// `.txt`, `.csv`, `.log` thì không trả gì — và đó là phần lớn thời gian dùng một trình soạn
// thảo hàng Gigabyte. Người dùng không đứng nhìn khoản ấy: `AsyncHighlighter` chạy ở luồng
// nền, nên cửa sổ mở ngay và màu đến sau, đúng thứ vẫn xảy ra với file lớn hôm nay.
//
// Grammar KHÔNG gọi hàm nào của lõi tree-sitter (chúng chỉ include `parser.h` và trả về một
// `TSLanguage` tĩnh), nên dylib này đứng độc lập, không cần liên kết ngược vào lõi.
//
// AI ĐƯỢC PHÉP KHAI BÁO PHỤ THUỘC VÀO TARGET NÀY: chỉ những thứ KHÔNG phải app phát hành —
// bộ đo, bộ kiểm. `GEditorApp` và `GEditorCore` phải lấy con trỏ qua `dlsym`
// (`GrammarLibrary.swift`); liên kết thẳng sẽ kéo cả 7 MB bảng tra trở lại đường khởi động,
// đúng thứ ADR-08 sinh ra để gỡ. `build-universal.sh` có một chốt chặn hỏi `otool -L`.

#ifndef GEDITOR_TREE_SITTER_HEAVY_H
#define GEDITOR_TREE_SITTER_HEAVY_H

typedef struct TSLanguage TSLanguage;

const TSLanguage *tree_sitter_bash(void);
const TSLanguage *tree_sitter_c(void);
const TSLanguage *tree_sitter_cpp(void);
const TSLanguage *tree_sitter_css(void);
const TSLanguage *tree_sitter_go(void);
const TSLanguage *tree_sitter_html(void);
const TSLanguage *tree_sitter_java(void);
const TSLanguage *tree_sitter_javascript(void);
const TSLanguage *tree_sitter_json(void);
const TSLanguage *tree_sitter_lua(void);
const TSLanguage *tree_sitter_php(void);
const TSLanguage *tree_sitter_python(void);
const TSLanguage *tree_sitter_regex(void);
const TSLanguage *tree_sitter_ruby(void);
const TSLanguage *tree_sitter_rust(void);
const TSLanguage *tree_sitter_toml(void);
const TSLanguage *tree_sitter_typescript(void);
const TSLanguage *tree_sitter_xml(void);
const TSLanguage *tree_sitter_yaml(void);

// C#: hàm mang tên `tree_sitter_c_sharp`, KHÔNG theo tên thư mục. Tên do trường `name` trong
// grammar quyết, không do chỗ ta đặt file. Đây là chỗ duy nhất trong hai mươi grammar lệch
// tên, và nó chỉ lộ ra ở bước LIÊN KẾT — biên dịch sạch trơn.
const TSLanguage *tree_sitter_c_sharp(void);

#endif
