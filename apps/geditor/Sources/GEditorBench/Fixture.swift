import Foundation

/// Sinh file fixture lớn NGOÀI repo (STP §2.2: không đưa file lớn vào git).
///
/// File được tái sử dụng giữa các lần chạy nếu đã đúng kích thước — sinh 1 GB mất vài giây
/// nhưng lặp lại ở mỗi lần đo thì làm nhiễu số liệu I/O.
enum Fixture {

    /// Một dòng CSV tiếng Việt có dấu — cố ý nhiều byte UTF-8 nhiều byte để chỉ mục dòng
    /// không được phép giả định 1 byte = 1 ký tự.
    static let line = "DH-0091,\"Công ty Anh Đào, CN Huế\",Thừa Thiên Huế,128500000,2026-07-02\n"

    static var directory: String {
        ProcessInfo.processInfo.environment["GEDITOR_FIXTURE_DIR"] ?? NSTemporaryDirectory()
    }

    /// Trả về đường dẫn tới fixture xấp xỉ `megabytes` MB, sinh nếu chưa có.
    ///
    /// Kích thước là BỘI SỐ NGUYÊN của độ dài dòng nên file luôn kết thúc bằng EOL —
    /// tránh việc số dòng phụ thuộc vào chỗ cắt ngẫu nhiên.
    static func path(megabytes: Int) throws -> String {
        let templateBytes = Array(line.utf8)
        let target = megabytes * 1024 * 1024
        let lineCount = target / templateBytes.count
        let exactSize = lineCount * templateBytes.count

        let path = "\(directory)/geditor-fixture-\(megabytes)mb.csv"
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           (attributes[.size] as? NSNumber)?.intValue == exactSize {
            return path
        }

        FileManager.default.createFile(atPath: path, contents: nil)
        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw NSError(
                domain: "GEditorBench", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "không mở được fixture để ghi: \(path)"]
            )
        }
        defer { try? handle.close() }

        // Ghi theo khối ~8 MB: đủ lớn để chi phí syscall không đáng kể, đủ nhỏ để không
        // dựng cả 1 GB trong RAM trước khi ghi.
        let linesPerChunk = max(1, (8 * 1024 * 1024) / templateBytes.count)
        var chunk = [UInt8]()
        chunk.reserveCapacity(linesPerChunk * templateBytes.count)
        for _ in 0 ..< linesPerChunk { chunk.append(contentsOf: templateBytes) }

        var written = 0
        while written < exactSize {
            let remaining = exactSize - written
            let slice = remaining >= chunk.count ? chunk : Array(chunk[0 ..< remaining])
            try handle.write(contentsOf: Data(slice))
            written += slice.count
        }
        return path
    }

    /// Dựng cây thư mục fixture cho Find in Files (STP TC-PERF-05, TC-SRCH-06).
    ///
    /// Hình dạng cố ý giống một kho mã thật chứ không phải một thư mục phẳng: file rải trên
    /// 100 thư mục con, ba đuôi khác nhau, và một `node_modules` đầy mồi nhử để phép đo bao
    /// gồm cả chi phí lọc chứ không chỉ chi phí đọc.
    ///
    /// Cứ 5 file thì 1 file chứa chuỗi mục tiêu, nên số file khớp là một con số biết trước —
    /// benchmark tự kiểm được rằng nó đang đo một lần tìm ĐÚNG.
    static let targetNeedle = "MỤC-TIÊU-CẦN-TÌM"

    static func tree(files: Int, kilobytesPerFile: Int) throws -> (root: String, expectedMatches: Int) {
        let root = "\(directory)/geditor-tree-\(files)x\(kilobytesPerFile)kb"
        let marker = "\(root)/.complete"
        let expected = (files + 4) / 5

        if FileManager.default.fileExists(atPath: marker) {
            return (root, expected)
        }

        try? FileManager.default.removeItem(atPath: root)
        let extensions = ["csv", "log", "txt"]
        let templateBytes = Array(line.utf8)
        let targetBytes = kilobytesPerFile * 1024

        var body = [UInt8]()
        body.reserveCapacity(targetBytes + templateBytes.count)
        while body.count < targetBytes { body.append(contentsOf: templateBytes) }

        for bucket in 0 ..< 100 {
            try FileManager.default.createDirectory(
                atPath: "\(root)/mo-đun-\(bucket)", withIntermediateDirectories: true
            )
        }
        try FileManager.default.createDirectory(
            atPath: "\(root)/node_modules", withIntermediateDirectories: true
        )

        for index in 0 ..< files {
            var contents = body
            let carriesNeedle = index % 5 == 0
            if carriesNeedle {
                contents.append(contentsOf: Array("\(targetNeedle)-\(index)\n".utf8))
            }
            // File mang chuỗi mục tiêu luôn là .csv, tức luôn lọt qua bộ lọc chuẩn
            // "*.csv;*.log" của TC-SRCH-06. Nhờ vậy số kết quả kỳ vọng là files/5 bất kể
            // bộ lọc — nếu để đuôi file quay vòng thì fixture và bộ lọc lại phụ thuộc nhau,
            // và một con số lệch sẽ không nói được là do bên nào.
            let suffix = carriesNeedle ? "csv" : extensions[index % 3]
            let path = "\(root)/mo-đun-\(index % 100)/tệp-\(index).\(suffix)"
            try Data(contents).write(to: URL(fileURLWithPath: path))
        }

        // Mồi nhử: khớp chuỗi mục tiêu nhưng nằm trong thư mục bị loại theo mặc định. Nếu
        // bộ lọc hỏng, số kết quả sẽ lệch và benchmark báo sai ngay.
        for index in 0 ..< 200 {
            try Data(Array("\(targetNeedle)-mồi-\(index)\n".utf8))
                .write(to: URL(fileURLWithPath: "\(root)/node_modules/mồi-\(index).csv"))
        }

        FileManager.default.createFile(atPath: marker, contents: nil)
        return (root, expected)
    }

    /// Fixture trong RAM cho các phép đo không cần chạm đĩa.
    static func inMemory(megabytes: Int) -> [UInt8] {
        let templateBytes = Array(line.utf8)
        let target = megabytes * 1024 * 1024
        var bytes = [UInt8]()
        bytes.reserveCapacity(target + templateBytes.count)
        while bytes.count < target { bytes.append(contentsOf: templateBytes) }
        return bytes
    }
}
