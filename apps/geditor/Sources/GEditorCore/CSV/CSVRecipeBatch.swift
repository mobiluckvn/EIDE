import Foundation

/// Chạy một công thức lên NHIỀU file (FR-CLN-005).
///
/// Khác hẳn chạy trên tài liệu đang mở: ở đây không có cửa sổ nào để nhìn, không có ⌘Z nào để
/// lùi, và người dùng có thể vừa chỉ vào hai trăm file bằng một dòng lệnh. Nên mặc định là
/// **không ghi đè**: kết quả đi vào file mới cạnh file gốc. Muốn ghi đè thì phải nói ra.
///
/// Đó không phải sự thận trọng thừa. Một công thức viết cho báo cáo tháng Bảy, chạy nhầm lên
/// thư mục chứa dữ liệu gốc của cả năm, mà lại ghi đè — thì thứ duy nhất còn lại là bản sao
/// lưu, nếu có.
public enum CSVRecipeBatch {

    /// Nơi kết quả đi tới.
    public enum Destination: Equatable, Sendable {
        /// File mới cạnh file gốc, thêm hậu tố vào tên: `thang7.csv` → `thang7-sach.csv`.
        case suffix(String)
        /// File cùng tên trong một thư mục khác.
        case directory(String)
        /// Ghi đè chính file gốc. Người gọi phải chọn tường minh.
        case inPlace

        public static let `default` = Destination.suffix("-sach")
    }

    /// Kết quả trên MỘT file.
    public struct FileResult: Equatable {
        public let sourcePath: String
        /// Nơi đã ghi ra; `nil` khi file không xử lý được, hoặc khi không có gì để đổi.
        public let outputPath: String?
        public let run: CSVRecipeRun?
        /// Lý do file này không xong — `nil` nghĩa là xong.
        public let error: String?

        public var succeeded: Bool { error == nil }
    }

    public struct BatchResult: Equatable {
        public let recipeName: String
        public let files: [FileResult]

        public var succeededCount: Int { files.filter(\.succeeded).count }
        public var failedCount: Int { files.count - succeededCount }
        /// File chạy xong nhưng có bước bị bỏ qua — không phải lỗi, nhưng phải nói ra.
        public var withProblems: [FileResult] {
            files.filter { $0.succeeded && ($0.run?.hasProblems ?? false) }
        }

        /// Báo cáo Markdown: phần TÓM TẮT trước, rồi từng file một.
        ///
        /// Tóm tắt đứng đầu vì với hai trăm file thì cái người ta cần biết trước tiên là "có
        /// cái nào hỏng không", chứ không phải file thứ nhất đã làm gì. Mỗi file vẫn giữ mục
        /// riêng: gộp chung thì một file hỏng chìm nghỉm giữa hai trăm file trôi chảy.
        public var report: String {
            var out = "# Chạy công thức «\(recipeName)» trên \(files.count) file\n\n"
            out += "- \(succeededCount) file xong"
            out += failedCount > 0 ? "\n- **\(failedCount) file lỗi**" : ""
            let problems = withProblems
            out += problems.isEmpty ? "" : "\n- \(problems.count) file có bước bị bỏ qua"
            out += "\n\n"

            if failedCount > 0 {
                out += "## File lỗi\n\n"
                for file in files where !file.succeeded {
                    out += "- `\(file.sourcePath)` — \(file.error ?? "")\n"
                }
                out += "\n"
            }

            for file in files where file.succeeded {
                out += (file.run?.report ?? "")
                if let output = file.outputPath {
                    out += "   → ghi ra `\(output)`\n"
                } else {
                    out += "   → không có gì để đổi, không ghi file nào\n"
                }
                out += "\n"
            }
            return out
        }
    }

    /// Chạy công thức trên danh sách file.
    ///
    /// - Parameter progress: gọi trước mỗi file; trả `false` để dừng. Hai trăm file có thể mất
    ///   vài phút, và một tiến trình không hủy được là một tiến trình bị treo dưới mắt người dùng.
    public static func run(
        _ recipe: CSVRecipe,
        files: [String],
        destination: Destination = .default,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        cancelToken: CancelToken = CancelToken(),
        progress: ((Int, String) -> Bool)? = nil
    ) -> BatchResult {
        var results: [FileResult] = []

        for (index, path) in files.enumerated() {
            if let progress, !progress(index, path) { break }
            if (try? cancelToken.check()) == nil { break }
            results.append(runOne(recipe, path: path, destination: destination,
                                  hasHeader: hasHeader, spec: spec, cancelToken: cancelToken))
        }
        return BatchResult(recipeName: recipe.name, files: results)
    }

    static func runOne(
        _ recipe: CSVRecipe,
        path: String,
        destination: Destination,
        hasHeader: Bool,
        spec: CSVNullSpec,
        cancelToken: CancelToken
    ) -> FileResult {
        let document: Document
        do {
            document = try Document.open(path: path)
        } catch {
            return FileResult(sourcePath: path, outputPath: nil, run: nil,
                              error: "không mở được: \(error)")
        }

        // Dò dấu phân tách của TỪNG file. Một thư mục hay lẫn cả file xuất từ Excel bản Việt
        // (chấm phẩy) lẫn file xuất từ công cụ khác (dấu phẩy); áp một dialect cho cả thư mục
        // sẽ đọc nửa số file thành một cột duy nhất và "chạy xong" mà chẳng sửa gì.
        let sample = document.buffer.bytes(in: 0 ..< min(document.buffer.count, 64 * 1024))
        let dialect = CSVEngine.detectDialect(sample: sample)

        let run: CSVRecipeRun
        do {
            run = try CSVRecipeRunner.run(
                recipe, on: document.buffer, dialect: dialect,
                fileName: (path as NSString).lastPathComponent,
                hasHeader: hasHeader, spec: spec, cancelToken: cancelToken
            )
        } catch {
            return FileResult(sourcePath: path, outputPath: nil, run: nil,
                              error: "không chạy được công thức: \(error)")
        }

        // Không đổi gì thì KHÔNG ghi file nào. Ghi ra một bản sao y hệt chỉ để chứng minh đã
        // chạy là rác — và với `.inPlace` thì đó còn là một lần chạm vào file người dùng mà
        // không có lý do.
        guard run.appliedCount > 0 else {
            return FileResult(sourcePath: path, outputPath: nil, run: run, error: nil)
        }

        let output = outputPath(for: path, destination: destination)
        do {
            try document.save(to: output)
        } catch {
            return FileResult(sourcePath: path, outputPath: nil, run: run,
                              error: "không ghi được \(output): \(error)")
        }
        return FileResult(sourcePath: path, outputPath: output, run: run, error: nil)
    }

    public static func outputPath(for path: String, destination: Destination) -> String {
        switch destination {
        case .inPlace:
            return path
        case let .suffix(suffix):
            let base = (path as NSString).deletingPathExtension
            let ext = (path as NSString).pathExtension
            return ext.isEmpty ? base + suffix : "\(base)\(suffix).\(ext)"
        case let .directory(folder):
            return (folder as NSString)
                .appendingPathComponent((path as NSString).lastPathComponent)
        }
    }

    /// Tìm file CSV trong một thư mục (không đệ quy).
    ///
    /// Không đệ quy, và đó là chủ ý: chỉ vào thư mục Documents rồi quét cả cây con là cách
    /// chạm tới hàng nghìn file mà người dùng không hình dung được. Muốn sâu hơn thì chỉ đúng
    /// thư mục ấy.
    public static func csvFiles(in directory: String) -> [String] {
        let extensions: Set<String> = ["csv", "tsv", "txt"]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        return names
            .filter { extensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
            .map { (directory as NSString).appendingPathComponent($0) }
    }
}
