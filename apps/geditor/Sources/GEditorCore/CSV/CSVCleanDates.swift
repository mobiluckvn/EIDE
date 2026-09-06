import Foundation

/// Quy ước đọc ngày khi hai số đầu đều ≤ 12 (FR-CLN-001).
public enum CSVDayMonthOrder: String, Equatable, Sendable {
    case dayFirst
    case monthFirst

    public var displayName: String {
        switch self {
        case .dayFirst: return "ngày trước (DD/MM)"
        case .monthFirst: return "tháng trước (MM/DD)"
        }
    }
}

/// Một ngày đã đọc ra được.
public struct CSVParsedDate: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Dạng ISO 8601 — đích của mọi phép chuẩn hóa ngày.
    public var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

/// Kết quả đọc MỘT ô ngày.
public enum CSVDateReading: Equatable, Sendable {
    /// Đọc được chắc chắn. `implies` là quy ước mà chính ô này chứng minh — chỉ có khi ô ở
    /// dạng số-số-số và một trong hai số đầu lớn hơn 12; ISO hay tên tháng thì không chứng
    /// minh gì về quy ước của cột.
    case certain(CSVParsedDate, implies: CSVDayMonthOrder?)
    /// Đọc được CẢ HAI cách và cả hai đều là ngày có thật. Phải hỏi, không được đoán.
    case needsOrder(dayFirst: CSVParsedDate, monthFirst: CSVParsedDate)
    case notADate
}

extension CSVClean {

    /// Khảo sát một cột ngày trước khi chuẩn hóa (vế (a) của NFR-CLN-02).
    public struct DateScan: Equatable, Sendable {
        /// Quy ước mà dữ liệu tự nó chỉ ra.
        public let evidence: Evidence<CSVDayMonthOrder>
        /// Số ô đọc được ngay, không cần quy ước.
        public let certainCells: Int
        /// Số ô phải có quy ước mới đọc được.
        public let ambiguousCells: Int
        /// Số ô đã đúng ISO sẵn.
        public let alreadyISO: Int
        /// Ô không phải ngày — sẽ để nguyên và đánh dấu.
        public let notDates: [CellRef]
        public let rowsScanned: Int
        public let partial: Bool

        /// Có cần hỏi người dùng quy ước không.
        ///
        /// Chỉ hỏi khi thật sự cần: có ô mơ hồ VÀ dữ liệu không tự chỉ ra quy ước. Cột mà mọi
        /// ô đều có ngày > 12 thì hỏi là hỏi thừa, và mỗi câu hỏi thừa làm người dùng bấm
        /// nhanh hơn cho xong ở câu hỏi thật.
        public var needsQuestion: Bool {
            guard ambiguousCells > 0 else { return false }
            switch evidence {
            case .certain: return false
            case .ambiguous, .conflicting, .none: return true
            }
        }
    }

    /// Đọc bằng chứng về quy ước ngày của một cột.
    ///
    /// - Parameter maxRows: 0 = cả cột. Khảo sát trên MẪU thì nhanh, nhưng bằng chứng nằm ở
    ///   một ô duy nhất có ngày > 12 và ô ấy có thể nằm ở hàng thứ chín trăm nghìn — nên chỗ
    ///   gọi phải cân nhắc, và `partial` nói ra là đã dừng sớm.
    public static func scanDates(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> DateScan {
        var certain = 0, ambiguous = 0, alreadyISO = 0, rows = 0
        var notDates: [CellRef] = []
        var sawDayFirst = false, sawMonthFirst = false
        var stopped = false

        try forEachCell(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value, rowIndex, range in
            rows += 1
            guard !value.isEmpty else { return true }

            switch readDate(value) {
            case let .certain(date, implies):
                certain += 1
                if date.iso == value { alreadyISO += 1 }
                switch implies {
                case .dayFirst: sawDayFirst = true
                case .monthFirst: sawMonthFirst = true
                case nil: break
                }
            case .needsOrder:
                ambiguous += 1
            case .notADate:
                notDates.append(CellRef(
                    rowIndex: rowIndex, column: column, offset: range.lowerBound, value: value
                ))
            }
            return true
        }
        if maxRows > 0, rows >= maxRows { stopped = true }

        let evidence: Evidence<CSVDayMonthOrder>
        switch (sawDayFirst, sawMonthFirst) {
        case (true, true): evidence = .conflicting
        case (true, false): evidence = .certain(.dayFirst)
        case (false, true): evidence = .certain(.monthFirst)
        case (false, false): evidence = ambiguous > 0 ? .ambiguous : .none
        }

        return DateScan(
            evidence: evidence, certainCells: certain, ambiguousCells: ambiguous,
            alreadyISO: alreadyISO, notDates: notDates, rowsScanned: rows, partial: stopped
        )
    }

    /// Dựng kế hoạch chuẩn hóa cột ngày về ISO 8601 (FR-CLN-001).
    ///
    /// - Parameter order: quy ước cho những ô mơ hồ. `nil` = CHƯA hỏi, và khi ấy ô mơ hồ được
    ///   xếp vào "không đọc được" chứ không đoán. Đây là điểm mấu chốt của cả yêu cầu: đoán
    ///   sai dd/MM thành MM/dd cho ra một ngày vẫn hợp lệ, nên người dùng không có cách nào
    ///   phát hiện ra sai lầm về sau.
    public static func normalizeDates(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        order: CSVDayMonthOrder? = nil,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Plan {
        try plan(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value in
            guard !value.isEmpty else { return .skip }
            switch readDate(value) {
            case let .certain(date, _):
                return date.iso == value ? .alreadyClean : .changed(date.iso)
            case let .needsOrder(dayFirst, monthFirst):
                switch order {
                case .dayFirst: return .changed(dayFirst.iso)
                case .monthFirst: return .changed(monthFirst.iso)
                case nil: return .unparsable
                }
            case .notADate:
                return .unparsable
            }
        }
    }

    // MARK: - Đọc một ô ngày

    /// Cửa sổ năm hai chữ số: 00–69 là 2000–2069, 70–99 là 1970–1999.
    ///
    /// Mọi cách chọn cửa sổ đều sai với một ai đó; cách này khớp với POSIX và với bảng tính,
    /// tức là khớp với thứ người dùng vừa xuất dữ liệu ra từ đó.
    static let twoDigitYearPivot = 70

    /// Đọc một ô thành ngày, KHÔNG đoán.
    ///
    /// Nhận: `yyyy-MM-dd`, `yyyy/MM/dd`, `d/M/yyyy`, `d-M-yy`, `d.M.yyyy`, `5-Jul-26`,
    /// `5 Jul 2026`, `Jul 5, 2026` — dấu phân tách `/ - . khoảng trắng`, tên tháng tiếng Anh
    /// (viết tắt hoặc đầy đủ).
    ///
    /// KHÔNG nhận, và đây là chủ ý:
    /// - Chuỗi có kèm giờ (`2026-07-02 10:30`). Chuẩn hóa nó thành ngày trần là VỨT BỎ phần
    ///   giờ — mất dữ liệu, dưới danh nghĩa làm sạch.
    /// - Năm một chữ số (`1.2.3`). Nếu nhận, mọi số hiệu phiên bản trong file sẽ thành ngày.
    /// - Ngày không có thật (`31/02/2026`): đúng khuôn nhưng không tồn tại.
    /// - Tên tháng tiếng Việt (`5-Th7-26`). Chưa gặp trong dữ liệu xuất ra từ bảng tính; thêm
    ///   khi có ví dụ thật, đừng thêm theo phỏng đoán.
    ///
    /// Tự tách byte thay vì `DateFormatter`: hàm này chạy trên từng ô của cả tài liệu, và
    /// `DateFormatter` tốn hàng chục micro-giây mỗi lần gọi — nhân với một triệu hàng là hàng
    /// chục giây cho việc mà đọc mươi ký tự là xong (cùng lý do với `CSVValidator.dateFormat`).
    public static func readDate(_ value: String) -> CSVDateReading {
        var bytes = Array(value.utf8)
        return bytes.withUnsafeBufferPointer { readDate($0) }
    }

    /// Bản đọc thẳng trên BYTE — đường mà hồ sơ dữ liệu và bộ phát hiện đi.
    ///
    /// Một bản logic duy nhất cho cả hai đường vào: bản `String` chỉ là lớp vỏ gọi vào đây.
    /// Hai bản kiểm "cái gì là ngày" chạy song song là cách chắc chắn để một hôm nào đó hồ sơ
    /// nói "cột ngày" còn nút chuẩn hóa bảo "ô này không phải ngày".
    public static func readDate(_ bytes: UnsafeBufferPointer<UInt8>) -> CSVDateReading {
        var storage = TokenTriple()
        guard dateTokens(of: bytes, into: &storage), storage.count == 3 else { return .notADate }
        let tokens = storage

        // Năm đứng đầu: dạng ISO và họ hàng. Bốn chữ số là dấu hiệu không thể nhầm.
        if tokens[0].isNumber, tokens[0].digits == 4 {
            let year = tokens[0].value
            guard let month = monthValue(tokens[1], in: bytes), tokens[2].isNumber,
                  CSVValidator.isRealDate(year: year, month: month, day: tokens[2].value)
            else { return .notADate }
            return .certain(
                CSVParsedDate(year: year, month: month, day: tokens[2].value), implies: nil
            )
        }

        // Năm đứng cuối: mọi dạng còn lại.
        guard tokens[2].isNumber else { return .notADate }
        let yearRaw = tokens[2].value
        let year: Int
        switch tokens[2].digits {
        case 4: year = yearRaw
        case 2: year = yearRaw < twoDigitYearPivot ? 2000 + yearRaw : 1900 + yearRaw
        default: return .notADate
        }

        // Có tên tháng thì không còn gì để nhập nhằng.
        if !tokens[0].isNumber {
            guard let month = monthValue(tokens[0], in: bytes), tokens[1].isNumber,
                  CSVValidator.isRealDate(year: year, month: month, day: tokens[1].value)
            else { return .notADate }
            return .certain(
                CSVParsedDate(year: year, month: month, day: tokens[1].value), implies: nil
            )
        }
        if !tokens[1].isNumber {
            guard let month = monthValue(tokens[1], in: bytes), tokens[0].isNumber,
                  CSVValidator.isRealDate(year: year, month: month, day: tokens[0].value)
            else { return .notADate }
            return .certain(
                CSVParsedDate(year: year, month: month, day: tokens[0].value), implies: nil
            )
        }

        let first = tokens[0].value
        let second = tokens[1].value

        let asDayFirst = CSVValidator.isRealDate(year: year, month: second, day: first)
            ? CSVParsedDate(year: year, month: second, day: first) : nil
        let asMonthFirst = CSVValidator.isRealDate(year: year, month: first, day: second)
            ? CSVParsedDate(year: year, month: first, day: second) : nil

        switch (asDayFirst, asMonthFirst) {
        case let (.some(dayFirst), .some(monthFirst)):
            return .needsOrder(dayFirst: dayFirst, monthFirst: monthFirst)
        case let (.some(dayFirst), nil):
            // Chỉ đọc được một cách: chính ô này là bằng chứng về quy ước của cột.
            return .certain(dayFirst, implies: .dayFirst)
        case let (nil, .some(monthFirst)):
            return .certain(monthFirst, implies: .monthFirst)
        case (nil, nil):
            return .notADate
        }
    }

    // MARK: - Tách token

    /// Một token: hoặc một số (kèm số chữ số), hoặc một dải chữ cái trong chính ô ấy.
    ///
    /// Giữ VỊ TRÍ chứ không giữ chuỗi: token chữ chỉ xuất hiện ở ô có tên tháng, và dựng một
    /// `String` cho nó ở mỗi ô của một cột triệu hàng là hàng triệu lần cấp phát cho một phép
    /// so sánh mười hai khả năng.
    struct DateToken {
        var isNumber = true
        var value = 0
        var digits = 0
        var start = 0
        var end = 0
    }

    /// Ba token, nằm thẳng trên ngăn xếp — không mảng, không cấp phát.
    struct TokenTriple {
        var count = 0
        private var a = DateToken()
        private var b = DateToken()
        private var c = DateToken()

        subscript(index: Int) -> DateToken {
            switch index {
            case 0: return a
            case 1: return b
            default: return c
            }
        }

        /// Trả `false` khi đã quá ba token — ô ấy không phải ngày.
        mutating func append(_ token: DateToken) -> Bool {
            switch count {
            case 0: a = token
            case 1: b = token
            case 2: c = token
            default: return false
            }
            count += 1
            return true
        }
    }

    /// Tách ô thành token, `false` nếu có ký tự không thuộc về một ngày.
    ///
    /// Dấu phẩy chỉ được coi là dấu phân tách khi ô CÓ chữ cái (`Jul 5, 2026`). Trong ô toàn
    /// số, dấu phẩy là dấu thập phân hoặc dấu nhóm nghìn — nhận nó làm phân tách sẽ biến ô
    /// `1,2,3` của một cột danh sách thành ngày mồng 1 tháng 2 năm 2003.
    static func dateTokens(
        of bytes: UnsafeBufferPointer<UInt8>, into tokens: inout TokenTriple
    ) -> Bool {
        guard bytes.count >= 6, bytes.count <= 32 else { return false }

        var hasLetter = false
        for byte in bytes where isLetter(byte) { hasLetter = true; break }

        var current = DateToken()
        var open = false

        func flush() -> Bool {
            guard open else { return true }
            open = false
            return tokens.append(current)
        }

        for (index, byte) in bytes.enumerated() {
            switch byte {
            case 0x30 ... 0x39:
                if open, !current.isNumber { return false }   // "Jul5" — không tách rõ được
                if !open { current = DateToken(); current.start = index; open = true }
                current.isNumber = true
                current.value = current.value * 10 + Int(byte - 0x30)
                current.digits += 1
                current.end = index + 1
            case UInt8(ascii: "/"), UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: " "):
                guard flush() else { return false }
            case UInt8(ascii: ","):
                guard hasLetter, flush() else { return false }
            default:
                guard isLetter(byte) else { return false }
                if open, current.isNumber { return false }    // "12abc"
                if !open { current = DateToken(); current.start = index; current.isNumber = false; open = true }
                current.end = index + 1
            }
        }
        return flush()
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }

    static let monthNames = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]

    /// Số tháng của một token — chấp nhận cả số và tên tiếng Anh (`7`, `Jul`, `July`, `Sept`).
    ///
    /// So sánh thẳng trên byte, không hạ hoa-thường cả chuỗi: mười hai cái tên là một bảng cố
    /// định, và một phép so byte không cấp phát gì.
    static func monthValue(_ token: DateToken, in bytes: UnsafeBufferPointer<UInt8>) -> Int? {
        if token.isNumber {
            return (1 ... 12).contains(token.value) ? token.value : nil
        }
        let length = token.end - token.start
        guard length >= 3 else { return nil }

        for (index, name) in monthNames.enumerated() {
            let nameBytes = Array(name.utf8)
            guard length <= nameBytes.count else { continue }
            var matched = true
            for offset in 0 ..< length where lowered(bytes[token.start + offset]) != nameBytes[offset] {
                matched = false
                break
            }
            // "sept" là cách viết tắt duy nhất dài hơn ba chữ mà người ta thật sự dùng.
            if matched { return index + 1 }
        }
        return nil
    }

    private static func lowered(_ byte: UInt8) -> UInt8 {
        (byte >= 0x41 && byte <= 0x5A) ? byte + 32 : byte
    }
}
