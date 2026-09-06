import Foundation
import TreeSitter
import TreeSitterHeavy

extension PoCD {

    /// Một ngôn ngữ trong PoC-D: grammar, truy vấn tô màu, và dữ liệu thử.
    struct Language {

        let name: String
        /// `const TSLanguage *` — Swift nhập nó thành `OpaquePointer` vì `TSLanguage` là
        /// struct khai báo trước, không có định nghĩa trong header công khai.
        let handle: OpaquePointer
        let highlightQuery: OpaquePointer?
        /// Ngôn ngữ này có cấu trúc nhiều dòng (chú thích khối, chuỗi nhiều dòng) hay không.
        ///
        /// Đây là biến quyết định phép đo cuối: chỉ ngôn ngữ có cấu trúc như vậy mới cho thấy
        /// cái giá của việc chỉ phân tích một cửa sổ.
        let cutsInsideMultilineConstruct: Bool

        private let makeFixture: (Int) -> [UInt8]

        func fixture(megabytes: Int) -> [UInt8] { makeFixture(megabytes) }

        /// Bốn ngôn ngữ thêm vào đều có BỘ QUÉT NGOÀI mang trạng thái — đúng nhóm mà ADR-04
        /// ghi là "phải đo riêng trước khi bật":
        ///
        ///   python — thụt lề là cú pháp; bộ quét giữ một NGĂN XẾP mức thụt lề.
        ///   bash   — heredoc: dấu kết thúc do chính người viết đặt, quét phải nhớ nó.
        ///   ruby   — `=begin`/`=end` và heredoc.
        ///   yaml   — khối theo thụt lề, chuỗi khối `|` và `>`.
        ///
        /// Nếu lề 64 KB không đủ cho nhóm này thì cả quyết định của ADR-04 phải đổi, nên phải
        /// biết TRƯỚC khi viết phần vẽ ra màn hình.
        static let all: [Language] = [json, c, python, bash, ruby, yaml].compactMap { $0 }

        // MARK: - JSON

        static let json: Language? = {
            guard let handle = tree_sitter_json() else { return nil }
            return Language(
                name: "json",
                handle: handle,
                highlightQuery: loadQuery(named: "json", language: handle),
                cutsInsideMultilineConstruct: false,
                makeFixture: { megabytes in
                    // Mảng object một dòng một phần tử — dạng file JSON lớn hay gặp nhất
                    // (export dữ liệu). Cắt ở biên dòng thì mỗi lát vẫn là JSON gần đúng.
                    var text = "[\n"
                    let row = #"  {"id": 1234, "ten": "Nguyễn Văn A", "gia_tri": 98.6, "hoat_dong": true},"# + "\n"
                    let target = megabytes * 1_048_576
                    text.reserveCapacity(target + row.utf8.count)
                    while text.utf8.count < target { text += row }
                    text += "  {\"id\": 0}\n]\n"
                    return Array(text.utf8)
                }
            )
        }()

        // MARK: - C

        static let c: Language? = {
            guard let handle = tree_sitter_c() else { return nil }
            return Language(
                name: "c",
                handle: handle,
                highlightQuery: loadQuery(named: "c", language: handle),
                cutsInsideMultilineConstruct: true,
                makeFixture: { megabytes in
                    // CỐ Ý rải chú thích khối `/* … */` DÀI, mỗi khối vài chục dòng.
                    //
                    // Đây là điểm của phép đo cuối, không phải chi tiết trang trí: cắt cửa sổ
                    // vào GIỮA một khối chú thích thì lát cắt bắt đầu bằng phần thân chú thích
                    // mà không có dấu mở, và tree-sitter sẽ đọc nó thành mã nguồn. Không có
                    // cấu trúc nhiều dòng trong dữ liệu thử thì phép đo luôn ra "0% sai" và
                    // chẳng chứng minh được gì.
                    var text = "#include <stdio.h>\n"
                    let target = megabytes * 1_048_576
                    text.reserveCapacity(target + 4096)
                    var index = 0
                    while text.utf8.count < target {
                        if index % 8 == 0 {
                            text += "/* khoi chu thich dai bat dau tu day\n"
                            for line in 0 ..< 30 {
                                text += " * dong chu thich \(line) — noi dung khong phai ma nguon\n"
                            }
                            text += " */\n"
                        }
                        text += """
                        static int ham_\(index)(int a, const char *ten) {
                            int tong = a * 2 + \(index);
                            printf("gia tri %d cua %s\\n", tong, ten);
                            return tong;
                        }

                        """
                        index += 1
                    }
                    return Array(text.utf8)
                }
            )
        }()

        // MARK: - Ngôn ngữ có bộ quét ngoài mang trạng thái

        static let python: Language? = make("python", tree_sitter_python(), multiline: true) { mb in
            var text = "import os\n"
            let target = mb * 1_048_576
            var index = 0
            while text.utf8.count < target {
                // Chuỗi ba nháy DÀI + thụt lề nhiều tầng: hai thứ mà bộ quét phải mang trạng
                // thái mới hiểu đúng.
                text += """
                class Lop\(index):
                    \"\"\"Tai lieu nhieu dong bat dau tu day.

                """
                for line in 0 ..< 25 {
                    text += "    dong \(line) trong chuoi ba nhay — khong phai ma nguon\n"
                }
                text += """
                    \"\"\"

                    def ham(self, a):
                        if a > 0:
                            for i in range(a):
                                if i % 2 == 0:
                                    print(\"gia tri\", i)
                        return a + \(index)

                """
                index += 1
            }
            return Array(text.utf8)
        }

        static let bash: Language? = make("bash", tree_sitter_bash(), multiline: true) { mb in
            var text = "#!/bin/bash\n"
            let target = mb * 1_048_576
            var index = 0
            while text.utf8.count < target {
                // Heredoc: dấu kết thúc do người viết đặt, nên bộ quét phải NHỚ nó qua nhiều
                // dòng. Đây là ca khó nhất của việc cắt cửa sổ.
                text += "cat <<KETTHUC_\(index)\n"
                for line in 0 ..< 25 {
                    text += "  dong \(line) trong heredoc — khong phai lenh shell\n"
                }
                text += "KETTHUC_\(index)\n"
                text += "if [ -f \"$HOME/file_\(index)\" ]; then\n  echo \"co \(index)\"\nfi\n"
                index += 1
            }
            return Array(text.utf8)
        }

        static let ruby: Language? = make("ruby", tree_sitter_ruby(), multiline: true) { mb in
            var text = "require 'json'\n"
            let target = mb * 1_048_576
            var index = 0
            while text.utf8.count < target {
                text += "=begin\n"
                for line in 0 ..< 25 {
                    text += "dong \(line) trong khoi chu thich ruby\n"
                }
                text += "=end\n"
                text += "class Lop\(index)\n  def ham(a)\n    a + \(index)\n  end\nend\n"
                index += 1
            }
            return Array(text.utf8)
        }

        static let yaml: Language? = make("yaml", tree_sitter_yaml(), multiline: true) { mb in
            var text = "---\n"
            let target = mb * 1_048_576
            var index = 0
            while text.utf8.count < target {
                text += "muc_\(index):\n  ten: \"A\"\n  mo_ta: |\n"
                for line in 0 ..< 25 {
                    text += "    dong \(line) trong chuoi khoi — khong phai khoa yaml\n"
                }
                text += "  danh_sach:\n    - mot\n    - hai\n"
                index += 1
            }
            return Array(text.utf8)
        }

        /// Dựng một `Language` từ con trỏ grammar; `nil` nếu grammar không nạp được.
        private static func make(
            _ name: String, _ handle: OpaquePointer?, multiline: Bool,
            _ fixture: @escaping (Int) -> [UInt8]
        ) -> Language? {
            guard let handle else { return nil }
            return Language(
                name: name, handle: handle,
                highlightQuery: loadQuery(named: name, language: handle),
                cutsInsideMultilineConstruct: multiline,
                makeFixture: fixture
            )
        }

        // MARK: - Truy vấn

        /// Nạp `highlights.scm` mà upstream phát hành cùng grammar.
        ///
        /// Không tự viết truy vấn: chúng là một phần của grammar, upstream cập nhật cùng nhau,
        /// và tự viết là tự nhận việc bảo trì hai mươi file cho hai mươi ngôn ngữ.
        private static func loadQuery(named name: String, language: OpaquePointer) -> OpaquePointer? {
            guard let source = querySource(named: name) else { return nil }
            var errorOffset: UInt32 = 0
            var errorType = TSQueryErrorNone
            return source.withCString { pointer in
                ts_query_new(language, pointer, UInt32(strlen(pointer)), &errorOffset, &errorType)
            }
        }

        /// Đọc file truy vấn từ thư mục vendor.
        ///
        /// PoC đọc thẳng từ repo. Mã sản phẩm sau này phải NHÚNG chúng vào bundle — đọc từ
        /// đường dẫn nguồn thì bản phát hành trên máy người dùng sẽ không tìm thấy gì.
        private static func querySource(named name: String) -> String? {
            let candidates = [
                URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()      // GEditorBench
                    .deletingLastPathComponent()      // Sources
                    .appendingPathComponent("TreeSitter/vendor/queries/\(name).scm"),
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("Sources/TreeSitter/vendor/queries/\(name).scm"),
            ]
            for url in candidates {
                if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
            }
            return nil
        }
    }
}
