import Foundation

/// Ba chế độ tìm kiếm dùng thống nhất cho Find, Replace, Find in Files, Mark (FR-SRCH-101).
public enum SearchMode: String, Codable {
    /// Chuỗi thuần.
    case normal
    /// `\n` `\r` `\t` `\0` `\xNN` — không diễn giải cú pháp regex.
    case extended
    /// PCRE2 đầy đủ.
    case regex
}

public struct SearchOptions {
    public var mode: SearchMode
    public var matchCase: Bool
    public var wholeWord: Bool

    /// `^` và `$` khớp ở biên MỖI DÒNG chứ không chỉ đầu/cuối tài liệu.
    ///
    /// Mặc định bật: người dùng đến từ Notepad++ mong `^` là "đầu dòng". Tắt đi thì
    /// `^abc` chỉ khớp nếu tài liệu bắt đầu bằng "abc" — hầu như không ai muốn thế
    /// trong một trình soạn thảo.
    public var multiline: Bool

    /// `.` khớp cả ký tự xuống dòng (ô ". matches newline" của Notepad++).
    public var dotMatchesNewline: Bool

    public init(
        mode: SearchMode = .normal,
        matchCase: Bool = false,
        wholeWord: Bool = false,
        multiline: Bool = true,
        dotMatchesNewline: Bool = false
    ) {
        self.mode = mode
        self.matchCase = matchCase
        self.wholeWord = wholeWord
        self.multiline = multiline
        self.dotMatchesNewline = dotMatchesNewline
    }
}

/// Pattern không biên dịch được — lớp trình bày hiện `message` kèm con trỏ tại `offset`
/// (FR-SRCH-102: người dùng phải biết SAI Ở ĐÂU, không chỉ "regex không hợp lệ").
public struct RegexCompileError: Error, CustomStringConvertible {
    public let pattern: String
    public let message: String
    /// Offset byte trong pattern nơi engine bỏ cuộc.
    public let offset: Int

    public init(pattern: String, message: String, offset: Int) {
        self.pattern = pattern
        self.message = message
        self.offset = offset
    }

    public var description: String { "Lỗi regex tại vị trí \(offset): \(message)" }
}

/// Engine đã chạm trần công sức cho MỘT lần khớp (FR-SRCH-104, NFR-REL-05, TC-SRCH-03).
///
/// Khác `DeadlineExceeded` ở chỗ đây là trần TẤT ĐỊNH tính bằng số bước backtracking, do
/// engine tự cưỡng chế ngay giữa một lần khớp. Deadline theo đồng hồ chỉ kiểm tra được
/// GIỮA các kết quả, nên một mình nó không cứu được pattern backtracking độc.
public struct RegexBudgetExceeded: Error, CustomStringConvertible {
    public enum Kind: String {
        case matchLimit, depthLimit, heapLimit
    }

    public let kind: Kind
    public let limit: UInt32

    public init(kind: Kind, limit: UInt32) {
        self.kind = kind
        self.limit = limit
    }

    public var description: String {
        "Pattern quá tốn kém: chạm trần \(kind.rawValue) = \(limit)"
    }
}

/// Một kết quả khớp. MỌI offset tính bằng BYTE trong buffer nguồn — không phải ký tự,
/// không phải UTF-16. Đây là hợp đồng của toàn bộ lõi: piece table, line index và
/// chỉ mục CSV đều dùng offset byte.
public struct SearchMatch: Equatable {
    public var range: Range<Int>
    /// Phạm vi các nhóm bắt được ($1, $2...); phần tử `nil` = nhóm không tham gia khớp.
    public var groups: [Range<Int>?]

    public init(range: Range<Int>, groups: [Range<Int>?] = []) {
        self.range = range
        self.groups = groups
    }
}

/// Giao diện engine tìm kiếm — lớp trên chỉ thấy protocol này.
///
/// ADR-03 chốt PCRE2 + JIT với `match_limit`/`depth_limit` + deadline callout.
/// Mọi hiện thực BẮT BUỘC tôn trọng `CancelToken`: regex do người dùng nhập có thể
/// gây catastrophic backtracking, và UI không bao giờ được phép treo (FR-SRCH-104,
/// NFR-REL-05, TC-SRCH-03).
public protocol SearchEngine {
    /// Nguyên thủy: chạy thẳng trên vùng nhớ, KHÔNG dựng chuỗi trung gian.
    ///
    /// Nhận `UnsafeRawBufferPointer` chứ không phải `[UInt8]` là điều kiện để tìm kiếm
    /// trên file mmap hàng GB — sao chép nội dung ra mảng đã hỏng ngay từ đầu.
    func find(
        pattern: String,
        in buffer: UnsafeRawBufferPointer,
        options: SearchOptions,
        limit: Int,
        cancelToken: CancelToken
    ) throws -> [SearchMatch]
}

extension SearchEngine {
    /// Đường tiện lợi cho test và tài liệu nhỏ.
    public func find(
        pattern: String,
        in bytes: [UInt8],
        options: SearchOptions = SearchOptions(),
        limit: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [SearchMatch] {
        try bytes.withUnsafeBytes {
            try find(pattern: pattern, in: $0, options: options, limit: limit, cancelToken: cancelToken)
        }
    }
}

/// Hiện thực bằng `NSRegularExpression` — GIỮ LẠI LÀM ĐỐI CHỨNG, không phải engine sản phẩm.
///
/// Từ PoC-C (ADR-03), engine sản phẩm là `PCRE2SearchEngine`. Lớp này còn lại vì nó là một
/// hiện thực độc lập, viết bởi người khác, để test đối chiếu kết quả — cách rẻ nhất để phát
/// hiện lỗi trong vòng lặp khớp của chính chúng ta.
///
/// Ba lý do nó KHÔNG dùng được cho sản phẩm, đã đo và ghi trong ADR-03:
///  1. Cú pháp ICU ≠ PCRE: thiếu `\K`, khác ở inline modifier và một số lookbehind
///     (FR-SRCH-102 đòi PCRE2). Người dùng Notepad++ sẽ gặp pattern chạy khác.
///  2. KHÔNG có step-limit. Deadline ở đây chỉ kiểm tra GIỮA các kết quả khớp, nên một
///     lần khớp đơn lẻ bị backtracking vẫn giữ worker thread cho tới khi xong (TC-SRCH-03).
///  3. Phải dựng chuỗi Swift từ toàn bộ buffer → không dùng được trên file GB.
public struct FoundationSearchEngine: SearchEngine {

    public init() {}

    public func find(
        pattern: String,
        in buffer: UnsafeRawBufferPointer,
        options: SearchOptions = SearchOptions(),
        limit: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [SearchMatch] {
        let haystack = String(decoding: buffer, as: UTF8.self)

        let needle: String
        switch options.mode {
        case .normal:
            needle = NSRegularExpression.escapedPattern(for: pattern)
        case .extended:
            needle = NSRegularExpression.escapedPattern(for: ExtendedEscape.decode(pattern))
        case .regex:
            needle = pattern
        }

        var expressionOptions: NSRegularExpression.Options = []
        if !options.matchCase { expressionOptions.insert(.caseInsensitive) }
        if options.multiline { expressionOptions.insert(.anchorsMatchLines) }
        if options.dotMatchesNewline { expressionOptions.insert(.dotMatchesLineSeparators) }

        let finalPattern = options.wholeWord ? "\\b(?:\(needle))\\b" : needle
        let regex = try NSRegularExpression(pattern: finalPattern, options: expressionOptions)

        // NSRegularExpression trả offset UTF-16; hợp đồng của lõi là offset byte.
        let toByte = utf16ToByteOffsets(haystack)
        func byteRange(_ r: NSRange) -> Range<Int>? {
            guard r.location != NSNotFound, r.location + r.length <= toByte.count - 1 else { return nil }
            return toByte[r.location] ..< toByte[r.location + r.length]
        }

        var matches: [SearchMatch] = []
        var thrownError: Error?

        regex.enumerateMatches(
            in: haystack,
            range: NSRange(location: 0, length: (haystack as NSString).length)
        ) { result, _, stop in
            do {
                try cancelToken.check()
            } catch {
                thrownError = error
                stop.pointee = true
                return
            }
            guard let result, let range = byteRange(result.range) else { return }
            let groups = (1 ..< result.numberOfRanges).map { byteRange(result.range(at: $0)) }
            matches.append(SearchMatch(range: range, groups: groups))
            if limit > 0 && matches.count >= limit { stop.pointee = true }
        }

        if let thrownError { throw thrownError }
        return matches
    }

    /// Bảng quy đổi offset UTF-16 → offset byte UTF-8, kích thước utf16Count + 1.
    ///
    /// O(n) bộ nhớ — chấp nhận được vì engine này chỉ phục vụ tài liệu nhỏ và test.
    /// PCRE2 chạy thẳng trên byte nên bảng này biến mất khi thay engine.
    private func utf16ToByteOffsets(_ string: String) -> [Int] {
        var table: [Int] = []
        table.reserveCapacity(string.utf16.count + 1)
        var byteOffset = 0
        for scalar in string.unicodeScalars {
            for _ in 0 ..< UTF16.width(scalar) {
                table.append(byteOffset)
            }
            byteOffset += UTF8.width(scalar)
        }
        table.append(byteOffset)
        return table
    }
}

/// Giải mã escape của chế độ Extended (FR-SRCH-101).
public enum ExtendedEscape {
    public static func decode(_ pattern: String) -> String {
        let chars = Array(pattern)
        var out = ""
        var i = 0
        while i < chars.count {
            guard chars[i] == "\\", i + 1 < chars.count else {
                out.append(chars[i])
                i += 1
                continue
            }
            switch chars[i + 1] {
            case "n": out.append("\n"); i += 2
            case "r": out.append("\r"); i += 2
            case "t": out.append("\t"); i += 2
            case "0": out.append("\0"); i += 2
            case "\\": out.append("\\"); i += 2
            case "x":
                let hex = String(chars[(i + 2)...].prefix(2))
                if hex.count == 2, let value = UInt8(hex, radix: 16) {
                    out.append(Character(UnicodeScalar(value)))
                    i += 4
                } else {
                    out.append(chars[i])
                    i += 1
                }
            default:
                out.append(chars[i])
                i += 1
            }
        }
        return out
    }
}
