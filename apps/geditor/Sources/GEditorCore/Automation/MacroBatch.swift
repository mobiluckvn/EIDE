import Foundation

/// Chạy một macro lên NHIỀU file (FR-AUTO-602, phần batch theo thư mục).
///
/// Đây là phần mà `MacroRunner` đã lường trước từ đầu — chú thích ở đó ghi "sẽ dùng lại được
/// cho batch theo thư mục, nơi file còn chưa mở". Nhờ vậy ở đây không có bản hiện thực thứ hai
/// của phép chạy macro: cùng một `MacroRunner`, chỉ khác chỗ lấy buffer.
///
/// **Cùng luật an toàn với `CSVRecipeBatch`, và cùng một lý do.** Không có cửa sổ nào để nhìn,
/// không có ⌘Z nào để lùi, và người dùng có thể vừa chỉ vào hai trăm file bằng một cú bấm. Nên
/// mặc định **không ghi đè**: kết quả đi vào file mới cạnh file gốc.
///
/// Một macro viết cho một file, chạy nhầm lên cả thư mục, mà lại ghi đè — thì thứ duy nhất còn
/// lại là bản sao lưu, nếu có.
public enum MacroBatch {

    /// Nơi kết quả đi tới. Dùng lại kiểu của `CSVRecipeBatch` là cố ý: hai tính năng khác nhau
    /// mà cùng một câu hỏi "ghi ra đâu" thì không nên có hai câu trả lời khác nhau.
    public typealias Destination = CSVRecipeBatch.Destination

    public struct FileResult: Equatable {
        public let sourcePath: String
        /// Nơi đã ghi; `nil` khi file lỗi hoặc khi macro không đổi gì.
        public let outputPath: String?
        /// Số vòng macro đã chạy trên file này.
        public let repetitions: Int
        public let error: String?

        public var succeeded: Bool { error == nil }
    }

    public struct BatchResult: Equatable {
        public let macroName: String
        public let files: [FileResult]

        public var succeededCount: Int { files.filter(\.succeeded).count }
        public var failedCount: Int { files.count - succeededCount }
        /// File chạy xong mà macro không đổi gì — không phải lỗi, nhưng đáng nói: thường là
        /// dấu hiệu macro viết cho một định dạng khác.
        public var unchangedCount: Int {
            files.filter { $0.succeeded && $0.outputPath == nil }.count
        }

        public var report: String {
            var out = "# Chạy macro «\(macroName)» trên \(files.count) file\n\n"
            out += "- \(succeededCount) file xong"
            if failedCount > 0 { out += "\n- **\(failedCount) file lỗi**" }
            if unchangedCount > 0 { out += "\n- \(unchangedCount) file không đổi gì" }
            out += "\n\n"

            for file in files {
                let name = (file.sourcePath as NSString).lastPathComponent
                if let error = file.error {
                    out += "## ❌ \(name)\n\n\(error)\n\n"
                } else if let output = file.outputPath {
                    out += "## \(name)\n\n"
                    out += "- \(file.repetitions) vòng\n- ghi ra `\(output)`\n\n"
                } else {
                    out += "## \(name)\n\nMacro không đổi gì trong file này.\n\n"
                }
            }
            return out
        }
    }

    /// Trần cỡ file. Macro chạy trên `TextBuffer` dựng từ chuỗi, nên file lớn sẽ tốn RAM đúng
    /// bằng cỡ của nó — nhân với số file chạy song song. Batch là việc chạy trên hàng trăm file
    /// nhỏ; file 500 MB thì mở ra mà chạy tay.
    public static let fileSizeLimit = 64 << 20

    /// Chạy `macro` lên từng file.
    ///
    /// - Parameter repetitions: `0` nghĩa là chạy tới khi macro tự dừng — cùng quy ước với
    ///   `MacroRunner.run`.
    public static func run(
        _ macro: Macro,
        on paths: [String],
        repetitions: Int = 0,
        destination: Destination = .default,
        cancelToken: CancelToken = CancelToken()
    ) -> BatchResult {
        var results: [FileResult] = []
        for path in paths {
            if (try? cancelToken.check()) == nil { break }
            results.append(runOne(macro, path: path, repetitions: repetitions, destination: destination))
        }
        return BatchResult(macroName: macro.name, files: results)
    }

    private static func runOne(
        _ macro: Macro, path: String, repetitions: Int, destination: Destination
    ) -> FileResult {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attributes?[.size] as? Int) ?? 0
        guard size <= fileSizeLimit else {
            return FileResult(
                sourcePath: path, outputPath: nil, repetitions: 0,
                error: "File \(size / (1 << 20)) MB vượt trần \(fileSizeLimit / (1 << 20)) MB của batch"
            )
        }
        guard let original = try? String(contentsOfFile: path, encoding: .utf8) else {
            // Đọc bằng UTF-8 mà hỏng thì rất có thể là file bảng mã khác. Nói ra chứ không im
            // lặng bỏ qua — người dùng cần biết file nào không được chạm tới.
            return FileResult(
                sourcePath: path, outputPath: nil, repetitions: 0,
                error: "Không đọc được bằng UTF-8 (có thể là bảng mã khác)"
            )
        }

        let buffer = TextBuffer(text: original)
        let runner = MacroRunner(buffer: buffer)
        let result = runner.run(macro, repetitions: repetitions)
        let updated = buffer.text

        guard updated != original else {
            return FileResult(sourcePath: path, outputPath: nil, repetitions: result.repetitions, error: nil)
        }

        let output = outputPath(for: path, destination: destination)
        do {
            try AtomicFileWriter.write(Array(updated.utf8), to: output)
            return FileResult(
                sourcePath: path, outputPath: output, repetitions: result.repetitions, error: nil
            )
        } catch {
            return FileResult(
                sourcePath: path, outputPath: nil, repetitions: result.repetitions,
                error: "Không ghi được: \(error)"
            )
        }
    }

    /// File văn bản trong một thư mục, KHÔNG đệ quy.
    ///
    /// Không đệ quy là chủ ý: người dùng chỉ vào `~/Documents` mà ta đi xuống mọi thư mục con
    /// thì họ vừa chạy macro lên cả kho mã, cả thư mục ảnh, cả bản sao lưu. Muốn đệ quy thì
    /// chỉ vào đúng thư mục con ấy.
    ///
    /// Bỏ file ĐÃ MANG hậu tố kết quả: chạy batch hai lần trong cùng thư mục mà không lọc thì
    /// lần hai sẽ xử lý cả kết quả của lần một, đẻ ra `a-macro-macro.txt`.
    /// - Parameter mask: mẫu tên file kiểu `*.csv;*.log`, để trống thì lấy mọi file văn bản.
    ///
    ///   SRS FR-AUTO-602 đòi *"chạy batch trên toàn thư mục theo file mask"*, và vế ấy có lý do
    ///   thật: bảng đuôi cứng bên dưới nói được "tệp nào ĐỌC ĐƯỢC", nhưng không nói được "tệp
    ///   nào tôi MUỐN đụng tới". Một thư mục có 400 tệp `.json` và 12 tệp `.log` thì người dùng
    ///   chạy macro dọn log không có cách nào bảo ta đừng chạm vào 400 tệp kia — và batch này
    ///   ghi ra file mới, nên nhầm là để lại 400 file rác.
    ///
    ///   Dùng `Glob` của Find in Files chứ không viết bộ khớp thứ hai: cùng một cú pháp mask
    ///   người dùng đã học ở đó, và cùng một chỗ để sửa khi nó sai.
    public static func textFiles(
        in directory: String, mask: String = "", skippingSuffix suffix: String = "-macro"
    ) -> [String] {
        let extensions: Set<String> = [
            "txt", "csv", "tsv", "log", "md", "json", "yaml", "yml", "xml", "html",
            "css", "js", "ts", "py", "rb", "go", "rs", "java", "c", "h", "cpp", "sh", "toml", "ini",
        ]
        let patterns = mask
            .split(whereSeparator: { $0 == ";" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        return names
            // Mask lọc THAY cho bảng đuôi, không lọc thêm sau nó: gõ `*.bak` mà vẫn bị bảng đuôi
            // chặn thì mask trở thành một ô nhập không làm gì trong đúng ca người dùng cần nó.
            .filter { name in
                patterns.isEmpty
                    ? extensions.contains((name as NSString).pathExtension.lowercased())
                    : Glob.matchesAny(name, patterns: patterns)
            }
            .filter { !($0 as NSString).deletingPathExtension.hasSuffix(suffix) }
            .sorted()
            .map { (directory as NSString).appendingPathComponent($0) }
    }

    static func outputPath(for path: String, destination: Destination) -> String {
        switch destination {
        case .inPlace:
            return path
        case .suffix(let suffix):
            let url = URL(fileURLWithPath: path)
            let ext = url.pathExtension
            let stem = url.deletingPathExtension().lastPathComponent
            let name = ext.isEmpty ? stem + suffix : "\(stem)\(suffix).\(ext)"
            return url.deletingLastPathComponent().appendingPathComponent(name).path
        case .directory(let directory):
            return URL(fileURLWithPath: directory)
                .appendingPathComponent((path as NSString).lastPathComponent).path
        }
    }
}
