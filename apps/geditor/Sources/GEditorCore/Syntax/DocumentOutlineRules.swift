import Foundation

extension DocumentOutline {

    /// Một loại node đáng đưa vào Function List, và cách lấy tên của nó.
    struct Rule {
        let kind: DocumentSymbol.Kind
        /// Tên các TRƯỜNG của grammar có thể chứa tên định nghĩa, thử theo thứ tự.
        let nameFields: [String]
        /// Khi grammar không khai trường nào: lấy node con đầu tiên thuộc kiểu này.
        let fallbackChildType: String?

        init(
            _ kind: DocumentSymbol.Kind,
            fields: [String] = ["name"],
            fallback: String? = nil
        ) {
            self.kind = kind
            self.nameFields = fields
            self.fallbackChildType = fallback
        }
    }

    /// Luật cho từng ngôn ngữ: node kiểu gì thì thành một mục.
    ///
    /// Bảng này là chỗ quyết định "cái gì đáng vào danh sách", và nó cố ý HẸP. Function List
    /// có ích khi nó là mục lục — liệt kê thêm biến, hằng, import sẽ cho ra một danh sách dài
    /// bằng chính file, và khi ấy người dùng quay về cuộn tay.
    ///
    /// Ngôn ngữ nào không có khái niệm hàm (JSON, YAML, TOML, CSS) thì lấy mục CẤP CAO NHẤT
    /// làm mục lục — đúng thứ người ta cần khi mở một file cấu hình dài.
    enum Rules {

        static func forLanguage(_ language: SyntaxLanguage) -> [String: Rule] {
            switch language {
            case .python:
                return [
                    "function_definition": Rule(.function),
                    "class_definition": Rule(.type),
                ]

            case .javascript, .typescript:
                return [
                    "function_declaration": Rule(.function),
                    "generator_function_declaration": Rule(.function),
                    "class_declaration": Rule(.type),
                    "method_definition": Rule(.method),
                    // `const foo = () => {}` là cách viết hàm phổ biến nhất trong mã hiện đại;
                    // bỏ nó ra ngoài thì Function List của một file React gần như rỗng.
                    "variable_declarator": Rule(.function, fields: ["name"]),
                    "interface_declaration": Rule(.type),
                    "type_alias_declaration": Rule(.type),
                ]

            case .go:
                return [
                    "function_declaration": Rule(.function),
                    "method_declaration": Rule(.method),
                    // Lấy `type_spec` chứ không lấy `type_declaration`: node bao ngoài chứa
                    // cả thân struct, nên tên sẽ thành "KhachHang struct {\n Ten string\n}".
                    "type_spec": Rule(.type),
                ]

            case .rust:
                return [
                    "function_item": Rule(.function),
                    "struct_item": Rule(.type),
                    "enum_item": Rule(.type),
                    "trait_item": Rule(.type),
                    "impl_item": Rule(.type, fields: ["type"]),
                    "mod_item": Rule(.type),
                ]

            case .c, .cpp:
                return [
                    // Trong C, tên hàm nằm trong `declarator`, có thể lồng vài lớp (con trỏ,
                    // mảng). Lấy nguyên `declarator` rồi cắt ở dấu ngoặc đơn đầu tiên là cách
                    // đọc được và không cần đệ quy qua mọi biến thể khai báo của C.
                    "function_definition": Rule(.function, fields: ["declarator"]),
                    "class_specifier": Rule(.type),
                    "struct_specifier": Rule(.type),
                    "enum_specifier": Rule(.type),
                    "namespace_definition": Rule(.type),
                ]

            case .java, .csharp:
                return [
                    "class_declaration": Rule(.type),
                    "interface_declaration": Rule(.type),
                    "enum_declaration": Rule(.type),
                    "record_declaration": Rule(.type),
                    "method_declaration": Rule(.method),
                    "constructor_declaration": Rule(.method),
                ]

            case .ruby:
                return [
                    "method": Rule(.method),
                    "singleton_method": Rule(.method),
                    "class": Rule(.type),
                    "module": Rule(.type),
                ]

            case .php:
                return [
                    "function_definition": Rule(.function),
                    "method_declaration": Rule(.method),
                    "class_declaration": Rule(.type),
                    "interface_declaration": Rule(.type),
                    "trait_declaration": Rule(.type),
                ]

            case .lua:
                return [
                    "function_declaration": Rule(.function),
                ]

            case .bash:
                return [
                    "function_definition": Rule(.function),
                ]

            case .css:
                // Mục lục của một file style là danh sách SELECTOR.
                return [
                    "rule_set": Rule(.section, fields: [], fallback: "selectors"),
                    "keyframes_statement": Rule(.section),
                ]

            case .json:
                // Khóa cấp cao của một file cấu hình. Cây JSON lồng sâu, nên `depth` lo phần
                // phân cấp còn UI quyết hiện tới mức nào.
                return ["pair": Rule(.section, fields: ["key"])]

            case .yaml:
                return ["block_mapping_pair": Rule(.section, fields: ["key"])]

            case .toml:
                return [
                    "table": Rule(.section, fields: [], fallback: "bare_key"),
                    "table_array_element": Rule(.section, fields: [], fallback: "bare_key"),
                ]

            case .html, .xml, .regex:
                // Không có khái niệm mục lục nào đủ chắc để đáng hiện. Một danh sách mọi thẻ
                // `<div>` là tiếng ồn, không phải mục lục.
                return [:]
            }
        }
    }
}
