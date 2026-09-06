// Header bọc tree-sitter cho GEditor — điểm vào DUY NHẤT của phía Swift (ADR-04).
//
// Grammar được biên dịch TĨNH vào bundle, không nạp động từ .dylib. SAD ADR-04 ghi hệ quả
// phải quản là "ABI grammar .dylib universal"; dựng tĩnh làm hệ quả ấy biến mất — không có
// thư viện rời để ký, để công chứng, hay để lệch ABI với lõi. Cái mất là người dùng không
// thả thêm grammar vào được lúc chạy; đó là việc của FR-FMT-502 (Phase 2) và sẽ đi đường
// tmLanguage, không đi đường nạp mã máy.

#ifndef GEDITOR_TREE_SITTER_H
#define GEDITOR_TREE_SITTER_H

// Đường dẫn tương đối chứ không phải <tree_sitter/api.h>: `headerSearchPath` trong
// Package.swift chỉ áp khi biên dịch chính target này, KHÔNG áp lúc Swift dựng module cho
// bên nhập. Thư mục header công khai vì thế phải tự đủ. (Cùng lý do đã ghi ở GEditorPCRE2.h.)
#include "../vendor/lib/include/tree_sitter/api.h"

// Hàm do trình sinh parser tạo ra, một hàm cho mỗi grammar. Khai báo tay ở đây vì upstream
// không phát hành header nào cho chúng.
const TSLanguage *tree_sitter_bash(void);
const TSLanguage *tree_sitter_c(void);
// csharp, cpp, ruby KHÔNG khai ở đây: chúng nằm trong dylib `TreeSitterHeavy`, nạp bằng
// `dlopen` khi cần (ADR-08 phương án C). Khai ở đây là mời trình liên kết kéo 10 MB bảng tra
// trở lại đường khởi động.
//
// (Ghi lại một chi tiết dễ mất: hàm của C# mang tên `tree_sitter_c_sharp`, KHÔNG theo tên thư
// mục — tên do trường `name` trong grammar quyết. Đó là chỗ duy nhất trong hai mươi grammar
// lệch tên, và nó chỉ lộ ra ở bước LIÊN KẾT.)
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
const TSLanguage *tree_sitter_rust(void);
const TSLanguage *tree_sitter_toml(void);
const TSLanguage *tree_sitter_typescript(void);
const TSLanguage *tree_sitter_xml(void);
const TSLanguage *tree_sitter_yaml(void);

#endif /* GEDITOR_TREE_SITTER_H */
