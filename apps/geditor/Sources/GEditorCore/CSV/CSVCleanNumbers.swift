import Foundation

/// Quy ước viết số (FR-CLN-001).
public enum CSVNumberStyle: String, Equatable, Sendable {
    /// Việt Nam / phần lớn châu Âu: `1.234,56` — chấm nhóm nghìn, phẩy thập phân.
    case vietnamese
    /// Anh - Mỹ: `1,234.56` — phẩy nhóm nghìn, chấm thập phân.
    case anglo

    public var displayName: String {
        switch self {
        case .vietnamese: return "Việt/Âu (1.234,56)"
        case .anglo: return "Anh-Mỹ (1,234.56)"
        }
    }

    var groupMark: Character { self == .vietnamese ? "." : "," }
    var decimalMark: Character { self == .vietnamese ? "," : "." }
    public var opposite: CSVNumberStyle { self == .vietnamese ? .anglo : .vietnamese }
}

/// Một số đã đọc ra được, giữ nguyên từng chữ số.
///
/// Cố ý KHÔNG dùng `Double`: `Double` chỉ giữ được 15–17 chữ số nghĩa, nên một mã số thuế hay
/// một số tiền lớn sẽ bị làm tròn khi đi qua nó — và "1.234.567.890.123.456" thành
/// "1.23456789012346e+15" là mất dữ liệu, dưới danh nghĩa làm sạch. Ở đây chỉ đổi CHỖ của hai
/// dấu, không tính toán gì.
public struct CSVParsedNumber: Equatable, Sendable {
    /// Dấu âm, nếu có.
    public let negative: Bool
    /// Phần nguyên, chỉ chữ số, đã bỏ mọi dấu nhóm.
    public let integerDigits: String
    /// Phần thập phân, chỉ chữ số; rỗng nghĩa là số nguyên.
    public let fractionDigits: String

    /// Viết lại theo một quy ước, có nhóm nghìn ba chữ số.
    public func formatted(_ style: CSVNumberStyle, grouped: Bool) -> String {
        var out = grouped ? group(integerDigits, by: style.groupMark) : integerDigits
        if !fractionDigits.isEmpty { out += String(style.decimalMark) + fractionDigits }
        return (negative ? "-" : "") + out
    }

    private func group(_ digits: String, by mark: Character) -> String {
        guard digits.count > 3 else { return digits }
        var out = ""
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out.append(mark) }
            out.append(digit)
        }
        return out
    }
}

extension CSVClean {

    /// Khảo sát một cột số trước khi đổi quy ước (vế (a) của NFR-CLN-02).
    public struct NumberScan: Equatable, Sendable {
        /// Quy ước mà dữ liệu tự nó chỉ ra.
        public let evidence: Evidence<CSVNumberStyle>
        /// Số ô đọc được không cần đoán quy ước.
        public let certainCells: Int
        /// Số ô đọc được cả hai cách (`1.234` — một nghìn hai trăm ba tư, hay một phẩy hai ba tư?).
        public let ambiguousCells: Int
        /// Ô không phải số — sẽ để nguyên và đánh dấu.
        public let notNumbers: [CellRef]
        public let rowsScanned: Int
        public let partial: Bool

        /// Có cần hỏi người dùng quy ước nguồn không. Cùng luật với `DateScan.needsQuestion`.
        public var needsQuestion: Bool {
            guard ambiguousCells > 0 else { return false }
            switch evidence {
            case .certain: return false
            case .ambiguous, .conflicting, .none: return true
            }
        }
    }

    /// Đọc bằng chứng về quy ước số của một cột.
    public static func scanNumbers(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> NumberScan {
        var certain = 0, ambiguous = 0, rows = 0
        var notNumbers: [CellRef] = []
        var sawVietnamese = false, sawAnglo = false
        var stopped = false

        try forEachCell(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value, rowIndex, range in
            rows += 1
            guard !value.isEmpty else { return true }

            switch readNumber(value) {
            case let .certain(_, implies):
                certain += 1
                switch implies {
                case .vietnamese: sawVietnamese = true
                case .anglo: sawAnglo = true
                case nil: break
                }
            case .needsStyle:
                ambiguous += 1
            case .notANumber:
                notNumbers.append(CellRef(
                    rowIndex: rowIndex, column: column, offset: range.lowerBound, value: value
                ))
            }
            return true
        }
        if maxRows > 0, rows >= maxRows { stopped = true }

        let evidence: Evidence<CSVNumberStyle>
        switch (sawVietnamese, sawAnglo) {
        case (true, true): evidence = .conflicting
        case (true, false): evidence = .certain(.vietnamese)
        case (false, true): evidence = .certain(.anglo)
        case (false, false): evidence = ambiguous > 0 ? .ambiguous : .none
        }

        return NumberScan(
            evidence: evidence, certainCells: certain, ambiguousCells: ambiguous,
            notNumbers: notNumbers, rowsScanned: rows, partial: stopped
        )
    }

    /// Dựng kế hoạch đổi quy ước số của một cột (FR-CLN-001).
    ///
    /// - Parameters:
    ///   - to: quy ước đích.
    ///   - sourceStyle: quy ước NGUỒN cho những ô mơ hồ. `nil` = chưa hỏi, và khi ấy ô mơ hồ
    ///     bị xếp vào "không đọc được" chứ không đoán — "1.234" đọc sai một cách sẽ thành số
    ///     lệch một nghìn lần, và nó vẫn là một con số trông hoàn toàn bình thường.
    ///   - grouped: có giữ dấu nhóm nghìn ở đầu ra không. Bỏ nhóm cho ra thứ mà mọi công cụ
    ///     khác đọc được; giữ nhóm cho ra thứ người đọc dễ nhìn.
    public static func normalizeNumbers(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        to style: CSVNumberStyle,
        sourceStyle: CSVNumberStyle? = nil,
        grouped: Bool = true,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Plan {
        try plan(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value in
            guard !value.isEmpty else { return .skip }
            // Ô không có dấu nào thì để NGUYÊN. Đổi quy ước là đổi chỗ hai dấu, không phải dịp
            // để định dạng lại thứ chưa từng có dấu: thêm dấu nhóm vào "1234567" sẽ làm hỏng
            // cả một cột mã số hay số điện thoại mà người dùng tưởng chỉ đang đổi dấu phẩy.
            if value.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "-" || $0 == "+") }) {
                return .alreadyClean
            }

            let number: CSVParsedNumber
            switch readNumber(value) {
            case let .certain(parsed, _):
                number = parsed
            case let .needsStyle(asVietnamese, asAnglo):
                switch sourceStyle {
                case .vietnamese: number = asVietnamese
                case .anglo: number = asAnglo
                case nil: return .unparsable
                }
            case .notANumber:
                return .unparsable
            }
            let written = number.formatted(style, grouped: grouped)
            return written == value ? .alreadyClean : .changed(written)
        }
    }

    // MARK: - Đọc một ô số

    /// Kết quả đọc MỘT ô số.
    public enum NumberReading: Equatable, Sendable {
        /// `implies` là quy ước mà chính ô này chứng minh — chỉ có khi ô đủ dấu hiệu để loại
        /// trừ cách đọc kia.
        case certain(CSVParsedNumber, implies: CSVNumberStyle?)
        /// Đọc được cả hai cách và cho hai con số KHÁC NHAU. Phải hỏi.
        case needsStyle(vietnamese: CSVParsedNumber, anglo: CSVParsedNumber)
        case notANumber
    }

    /// Đọc một ô thành số, KHÔNG đoán.
    ///
    /// Nhận: dấu `+`/`-` đầu, chữ số, dấu nhóm nghìn (`.` `,` khoảng trắng thường hoặc NBSP)
    /// và một dấu thập phân. Bỏ qua khoảng trắng đầu/cuối.
    ///
    /// KHÔNG nhận, và đây là chủ ý:
    /// - Nhóm nghìn sai cỡ (`12.34.567`). Nhận nó là mở cửa cho mọi chuỗi có dấu chấm.
    /// - Ký hiệu tiền tệ hay đơn vị (`1.234 đ`, `$5`). Bỏ ký hiệu đi là ĐỔI Ý NGHĨA của ô —
    ///   nếu muốn tách đơn vị thì đó là một thao tác khác, có tên khác.
    /// - Ký pháp mũ (`1.2e5`). Hiếm trong dữ liệu bảng tính và dễ đọc nhầm.
    ///
    /// Ô mơ hồ là ô có ĐÚNG MỘT dấu và sau dấu ấy đúng ba chữ số: `1.234` vừa là một nghìn hai
    /// trăm ba mươi tư (dấu nhóm), vừa là một phẩy hai ba tư (dấu thập phân). Hai cách đọc lệch
    /// nhau một nghìn lần mà cả hai đều ra một con số trông hoàn toàn bình thường.
    public static func readNumber(_ value: String) -> NumberReading {
        var bytes = Array(value.utf8)
        return bytes.withUnsafeBufferPointer { buffer in
            switch numberShape(of: buffer) {
            case .invalid:
                return .notANumber
            case let .certain(shape, implies):
                return .certain(digits(of: buffer, shape: shape), implies: implies)
            case let .ambiguous(asDecimal, asGroup, decimalStyle):
                let decimal = digits(of: buffer, shape: asDecimal)
                let group = digits(of: buffer, shape: asGroup)
                return decimalStyle == .vietnamese
                    ? .needsStyle(vietnamese: decimal, anglo: group)
                    : .needsStyle(vietnamese: group, anglo: decimal)
            }
        }
    }

    /// Giá trị số của một ô, đọc thẳng trên BYTE.
    ///
    /// Đi qua chính `numberShape` mà `readNumber` dùng, nên hồ sơ dữ liệu và nút chuẩn hóa
    /// không bao giờ bất đồng về "cái gì là số". Ô mơ hồ (`1.234`) lấy cách đọc Anh-Mỹ — hồ sơ
    /// chỉ đọc chứ không sửa gì, nên chọn ở đây không làm hỏng dữ liệu.
    public static func numericValue(of bytes: UnsafeBufferPointer<UInt8>) -> Double? {
        let shape: NumberShape
        switch numberShape(of: bytes) {
        case .invalid: return nil
        case let .certain(certain, _): shape = certain
        case let .ambiguous(asDecimal, asGroup, decimalStyle):
            shape = decimalStyle == .anglo ? asDecimal : asGroup
        }

        var whole = 0.0
        var fraction = 0.0
        var scale = 1.0
        var afterDecimal = false
        for index in shape.start ..< bytes.count {
            let byte = bytes[index]
            if let decimalAt = shape.decimalAt, index == decimalAt { afterDecimal = true; continue }
            guard byte >= 0x30, byte <= 0x39 else { continue }
            if afterDecimal {
                scale /= 10
                fraction += Double(byte - 0x30) * scale
            } else {
                whole = whole * 10 + Double(byte - 0x30)
            }
        }
        let magnitude = whole + fraction
        return shape.negative ? -magnitude : magnitude
    }

    /// Hình dạng của một ô số: dấu, vị trí dấu thập phân, chỗ bắt đầu phần thân.
    ///
    /// Giữ VỊ TRÍ chứ không giữ chuỗi. Cùng một hình dạng vừa dựng được `CSVParsedNumber`
    /// (giữ nguyên từng chữ số để đổi quy ước), vừa tính được `Double` (cho thống kê) — nên
    /// luật "cái gì là số" chỉ được viết MỘT lần.
    struct NumberShape {
        var negative = false
        /// Chỉ số byte đầu tiên của phần thân (sau dấu `+`/`-` và lề trắng).
        var start = 0
        /// Chỉ số byte của dấu thập phân; `nil` nghĩa là số nguyên.
        var decimalAt: Int?
    }

    enum NumberShapeReading {
        case certain(NumberShape, implies: CSVNumberStyle?)
        /// Đọc được hai cách: dấu ấy là thập phân (theo quy ước `decimalStyle`) hoặc là dấu nhóm.
        case ambiguous(decimal: NumberShape, group: NumberShape, decimalStyle: CSVNumberStyle)
        case invalid
    }

    static func numberShape(of bytes: UnsafeBufferPointer<UInt8>) -> NumberShapeReading {
        // Cắt lề bằng chỉ số, không dựng chuỗi mới.
        var lower = 0
        var upper = bytes.count
        while lower < upper, bytes[lower] == 0x20 { lower += 1 }
        while upper > lower, bytes[upper - 1] == 0x20 { upper -= 1 }
        guard lower < upper else { return .invalid }

        var negative = false
        if bytes[lower] == UInt8(ascii: "-") || bytes[lower] == UInt8(ascii: "+") {
            negative = bytes[lower] == UInt8(ascii: "-")
            lower += 1
        }
        guard lower < upper else { return .invalid }

        // Duyệt một lượt: đếm chữ số mỗi nhóm, ghi vị trí và loại của từng dấu.
        var groupSizes: [Int] = []
        var markPositions: [Int] = []
        var markKinds: [UInt8] = []          // '.', ',' hoặc ' ' (mọi khoảng trắng quy về ' ')
        var digitsInGroup = 0

        var index = lower
        while index < upper {
            let byte = bytes[index]
            switch byte {
            case 0x30 ... 0x39:
                digitsInGroup += 1
                index += 1
            case UInt8(ascii: "."), UInt8(ascii: ","), 0x20:
                groupSizes.append(digitsInGroup); digitsInGroup = 0
                markPositions.append(index); markKinds.append(byte == 0x20 ? 0x20 : byte)
                index += 1
            case 0xC2, 0xE2:
                // NBSP (U+00A0) và khoảng trắng hẹp (U+202F): dấu NHÓM ở cả hai quy ước.
                let length = byte == 0xC2 ? 2 : 3
                guard index + length <= upper, isUnicodeSpace(bytes, at: index, length: length)
                else { return .invalid }
                groupSizes.append(digitsInGroup); digitsInGroup = 0
                markPositions.append(index); markKinds.append(0x20)
                index += length
            default:
                return .invalid
            }
        }
        groupSizes.append(digitsInGroup)
        guard groupSizes.allSatisfy({ $0 > 0 }) else { return .invalid }

        func shape(decimalAt: Int?) -> NumberShape {
            NumberShape(negative: negative, start: lower, decimalAt: decimalAt)
        }
        /// Mọi nhóm nghìn đúng ba chữ số, nhóm đầu một tới ba. Không kiểm thì "12.34.567"
        /// thành 1234567 và mọi chuỗi có dấu chấm đều lọt qua thành số.
        func sizesOK(dropLast: Bool) -> Bool {
            var sizes = groupSizes
            if dropLast { sizes.removeLast() }
            guard let first = sizes.first, sizes.count == 1 || (1 ... 3).contains(first)
            else { return false }
            return sizes.dropFirst().allSatisfy { $0 == 3 }
        }

        // Không dấu nào: số nguyên trần, không nói gì về quy ước.
        guard !markKinds.isEmpty else { return .certain(shape(decimalAt: nil), implies: nil) }

        let kinds = Set(markKinds)
        // Khoảng trắng chỉ có thể là dấu NHÓM, ở cả hai quy ước — nó không chứng minh gì.
        if kinds == [0x20] {
            guard sizesOK(dropLast: false) else { return .invalid }
            return .certain(shape(decimalAt: nil), implies: nil)
        }

        // Có cả `.` và `,`: dấu xuất hiện SAU là dấu thập phân — không còn gì nhập nhằng.
        if kinds.contains(UInt8(ascii: ".")), kinds.contains(UInt8(ascii: ",")) {
            guard let last = markKinds.last, last != 0x20, sizesOK(dropLast: true) else { return .invalid }
            return .certain(
                shape(decimalAt: markPositions[markPositions.count - 1]),
                implies: last == UInt8(ascii: ",") ? .vietnamese : .anglo
            )
        }

        guard let mark = markKinds.first(where: { $0 != 0x20 }) else { return .invalid }
        let styleIfDecimal: CSVNumberStyle = mark == UInt8(ascii: ",") ? .vietnamese : .anglo

        // Dấu ấy xuất hiện NHIỀU lần thì nó là dấu nhóm, không thể là dấu thập phân.
        if markKinds.filter({ $0 == mark }).count > 1 {
            guard sizesOK(dropLast: false) else { return .invalid }
            return .certain(shape(decimalAt: nil), implies: styleIfDecimal.opposite)
        }

        // Một dấu duy nhất. Phần sau dấu KHÔNG phải ba chữ số → chắc chắn là dấu thập phân.
        guard markKinds.last == mark else { return .invalid }
        let decimalPosition = markPositions[markPositions.count - 1]
        if groupSizes[groupSizes.count - 1] != 3 {
            guard sizesOK(dropLast: true) else { return .invalid }
            return .certain(shape(decimalAt: decimalPosition), implies: styleIfDecimal)
        }

        // Một dấu, đúng ba chữ số phía sau: đọc được cả hai cách.
        guard sizesOK(dropLast: true), sizesOK(dropLast: false) else { return .invalid }
        return .ambiguous(
            decimal: shape(decimalAt: decimalPosition),
            group: shape(decimalAt: nil),
            decimalStyle: styleIfDecimal
        )
    }

    private static func isUnicodeSpace(
        _ bytes: UnsafeBufferPointer<UInt8>, at index: Int, length: Int
    ) -> Bool {
        if length == 2 { return bytes[index] == 0xC2 && bytes[index + 1] == 0xA0 }
        // U+202F NARROW NO-BREAK SPACE = E2 80 AF
        return bytes[index] == 0xE2 && bytes[index + 1] == 0x80 && bytes[index + 2] == 0xAF
    }

    /// Dựng chuỗi chữ số từ một hình dạng — chỉ gọi khi thật sự cần giữ từng chữ số.
    private static func digits(
        of bytes: UnsafeBufferPointer<UInt8>, shape: NumberShape
    ) -> CSVParsedNumber {
        var integerDigits = ""
        var fractionDigits = ""
        var afterDecimal = false
        for index in shape.start ..< bytes.count {
            if let decimalAt = shape.decimalAt, index == decimalAt { afterDecimal = true; continue }
            let byte = bytes[index]
            guard byte >= 0x30, byte <= 0x39 else { continue }
            let character = Character(UnicodeScalar(byte))
            if afterDecimal { fractionDigits.append(character) } else { integerDigits.append(character) }
        }
        return CSVParsedNumber(
            negative: shape.negative, integerDigits: integerDigits, fractionDigits: fractionDigits
        )
    }
}
