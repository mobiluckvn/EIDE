import Foundation

/// Chế độ Log: nhận mức nghiêm trọng của từng dòng (FR-FMT-508).
///
/// **Vì sao không dùng regex.** File log là thứ người ta mở ở cỡ hàng GB, và chế độ này phải
/// chạy trên MỌI dòng đang hiện. Một regex cho mỗi dòng, mỗi lần cuộn, là chi phí không cần
/// thiết cho một việc chỉ là tìm một trong sáu từ khoá. Ở đây quét byte, không dựng `String`.
///
/// **Chỉ nhìn phần ĐẦU dòng.** Mức nghiêm trọng luôn nằm gần đầu — sau dấu thời gian và tên
/// tiến trình. Quét cả dòng thì một dòng nhắc tới chữ "error" trong nội dung sẽ bị tô đỏ, và
/// một file log bình thường hoá ra đỏ rực.
///
/// **Không nhận ra thì trả `nil`, không đoán.** Một dòng tiếp nối của stack trace không có mức
/// riêng, và gán bừa cho nó mức của dòng trước sẽ làm phép lọc theo mức trả về những dòng
/// không ai hỏi.
public enum LogFormat {

    public enum Level: String, CaseIterable, Sendable, Comparable {
        case trace, debug, info, notice, warning, error, critical

        /// Thứ tự nghiêm trọng, để lọc "từ mức này trở lên".
        public var severity: Int {
            switch self {
            case .trace: return 0
            case .debug: return 1
            case .info: return 2
            case .notice: return 3
            case .warning: return 4
            case .error: return 5
            case .critical: return 6
            }
        }

        public static func < (a: Level, b: Level) -> Bool { a.severity < b.severity }

        public var displayName: String {
            switch self {
            case .trace: return "TRACE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .notice: return "NOTICE"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "FATAL"
            }
        }
    }

    /// Số byte đầu dòng được soi.
    ///
    /// 120 byte đủ cho `2026-08-23T19:12:06.116+07:00 [geditor:20377687] WARNING` — dài hơn thế
    /// thì mức nghiêm trọng đã không còn ở "đầu dòng" theo nghĩa nào cả.
    public static let probeLimit = 120

    /// Từ khoá → mức. Nhiều tên cho cùng một mức vì mỗi thư viện log gọi một kiểu.
    static let keywords: [(bytes: [UInt8], level: Level)] = {
        let table: [(String, Level)] = [
            ("CRITICAL", .critical), ("FATAL", .critical), ("PANIC", .critical),
            ("ERROR", .error), ("SEVERE", .error), ("ERR", .error),
            ("WARNING", .warning), ("WARN", .warning),
            ("NOTICE", .notice),
            ("INFO", .info),
            ("DEBUG", .debug),
            ("TRACE", .trace), ("VERBOSE", .trace),
        ]
        return table.map { (Array($0.0.utf8), $0.1) }
    }()

    /// Mức của một dòng, hoặc `nil`.
    ///
    /// Thứ tự trong `keywords` quan trọng: `ERROR` phải xét TRƯỚC `ERR`, và `WARNING` trước
    /// `WARN`, không thì từ dài hơn không bao giờ khớp và mọi dòng `WARNING` bị đọc là `WARN` —
    /// vô hại ở đây vì cùng mức, nhưng cùng cái bẫy ấy với `CRITICAL`/`CRIT` thì không.
    public static func level(of line: [UInt8]) -> Level? {
        let limit = Swift.min(line.count, probeLimit)
        guard limit > 0 else { return nil }

        var index = 0
        while index < limit {
            // Chỉ thử khớp ở BIÊN TỪ: `terror` không được đọc là `error`, và `NO_ERROR` thì
            // ranh giới `_` vẫn tính là biên vì nó không phải chữ cái.
            if index == 0 || !isWordByte(line[index - 1]) {
                for (needle, level) in keywords where matches(line, at: index, needle, limit: limit) {
                    let after = index + needle.count
                    if after >= line.count || !isWordByte(line[after]) { return level }
                }
            }
            index += 1
        }
        return nil
    }

    private static func isWordByte(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
    }

    /// So khớp KHÔNG phân biệt hoa thường, chỉ trên ASCII.
    private static func matches(_ line: [UInt8], at index: Int, _ needle: [UInt8], limit: Int) -> Bool {
        guard index + needle.count <= limit else { return false }
        for offset in 0 ..< needle.count {
            let byte = line[index + offset]
            let upper = (byte >= 97 && byte <= 122) ? byte - 32 : byte
            if upper != needle[offset] { return false }
        }
        return true
    }

    /// Mức của từng dòng trong một vùng byte của tài liệu.
    ///
    /// Trả về theo CHỈ SỐ DÒNG tuyệt đối để chỗ vẽ tra thẳng, không phải đếm lại.
    public static func levels(
        in buffer: TextBuffer, lineRange: ClosedRange<Int>
    ) -> [Int: Level] {
        guard buffer.lineCount > 0 else { return [:] }
        let lower = Swift.max(0, lineRange.lowerBound)
        let upper = Swift.min(buffer.lineCount - 1, lineRange.upperBound)
        guard lower <= upper else { return [:] }

        var out: [Int: Level] = [:]
        for line in lower ... upper {
            let content = buffer.contentRange(ofLine: line)
            let end = Swift.min(content.upperBound, content.lowerBound + probeLimit)
            guard end > content.lowerBound else { continue }
            if let level = level(of: buffer.bytes(in: content.lowerBound ..< end)) {
                out[line] = level
            }
        }
        return out
    }

    /// Tài liệu này trông có phải log không.
    ///
    /// Dùng để tự bật chế độ Log. Ngưỡng là **một phần tư** số dòng đã lấy mẫu có mức nhận ra
    /// được: thấp hơn thì một file mã nguồn có vài chuỗi `"ERROR"` sẽ bị nhận nhầm, cao hơn thì
    /// log thật xen nhiều dòng stack trace sẽ trượt.
    public static func looksLikeLog(_ buffer: TextBuffer, sampleLines: Int = 200) -> Bool {
        guard buffer.lineCount >= 5 else { return false }
        let count = Swift.min(sampleLines, buffer.lineCount)
        var recognised = 0
        for index in 0 ..< count {
            let line = index * (buffer.lineCount / count)
            let content = buffer.contentRange(ofLine: Swift.min(line, buffer.lineCount - 1))
            let end = Swift.min(content.upperBound, content.lowerBound + probeLimit)
            guard end > content.lowerBound else { continue }
            if level(of: buffer.bytes(in: content.lowerBound ..< end)) != nil { recognised += 1 }
        }
        return recognised * 4 >= count
    }
}
