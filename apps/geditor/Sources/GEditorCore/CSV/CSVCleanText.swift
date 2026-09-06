import Foundation

/// Cách đổi hoa thường cho một cột (FR-CLN-001).
public enum CSVLetterCase: String, Equatable, Sendable {
    case upper
    case lower
    /// Hoa chữ cái đầu mỗi từ: "nguyễn văn a" → "Nguyễn Văn A".
    case title

    public var displayName: String {
        switch self {
        case .upper: return "IN HOA"
        case .lower: return "in thường"
        case .title: return "Hoa Đầu Từ"
        }
    }
}

extension CSVClean {

    /// Cắt khoảng trắng thừa trong một cột (FR-CLN-001).
    ///
    /// Cắt hai đầu, và tùy chọn nén các khoảng trắng liên tiếp bên trong thành một.
    ///
    /// Xử lý cả khoảng trắng KHÔNG NGẮT (NBSP `U+00A0`, `U+202F`) và khoảng trắng zero-width
    /// (`U+200B`, `U+FEFF`): đó chính là thứ theo dữ liệu từ trang web và từ Excel vào, và là
    /// lý do "Hà Nội" ở hàng này không khớp với "Hà Nội" ở hàng kia dù nhìn hệt nhau. Cắt được
    /// chúng là một nửa lý do tồn tại của thao tác này.
    ///
    /// - Parameter collapseInner: nén khoảng trắng bên trong. Mặc định TẮT: "Cty  TNHH" thành
    ///   "Cty TNHH" là sửa dữ liệu chứ không chỉ cắt lề, và người dùng phải chủ động chọn.
    public static func trimCells(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        collapseInner: Bool = false,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Plan {
        try plan(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value in
            guard !value.isEmpty else { return .skip }
            let cleaned = trimmed(value, collapseInner: collapseInner)
            return cleaned == value ? .alreadyClean : .changed(cleaned)
        }
    }

    /// Ký tự bị coi là khoảng trắng khi làm sạch.
    ///
    /// Zero-width nằm trong danh sách vì chúng VÔ HÌNH: người dùng nhìn hai ô giống hệt nhau
    /// mà máy bảo khác nhau, và không có cách nào thấy được vì sao cho tới khi bật hiện ký tự
    /// ẩn lên.
    static func isCleanableSpace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case " ", "\t", "\n", "\r",
             "\u{00A0}", "\u{202F}", "\u{2007}",   // khoảng trắng không ngắt
             "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}":   // zero-width
            return true
        default:
            return scalar.properties.isWhitespace
        }
    }

    static func trimmed(_ value: String, collapseInner: Bool) -> String {
        collapseInner ? collapsed(value) : trimEndsOnly(value)
    }

    /// Cắt hai đầu VÀ nén mọi khoảng trắng bên trong thành một dấu cách thường.
    ///
    /// Nén là chỗ duy nhất NBSP giữa hai từ được đổi thành dấu cách thường — "Mai Lan⍽Store"
    /// thành "Mai Lan Store". Chỉ cắt hai đầu thì ô ấy vẫn khác "Mai Lan Store" ở giữa bảng,
    /// và người dùng không nhìn thấy vì sao.
    private static func collapsed(_ value: String) -> String {
        var out = String.UnicodeScalarView()
        var pendingSpace = false
        var wroteAny = false

        for scalar in value.unicodeScalars {
            if isCleanableSpace(scalar) {
                // Khoảng trắng chỉ được ghi ra khi biết chắc còn chữ phía sau — nhờ vậy phần
                // đuôi tự rụng mà không cần lượt cắt thứ hai.
                pendingSpace = wroteAny
                continue
            }
            if pendingSpace {
                out.append(" ")
                pendingSpace = false
            }
            out.append(scalar)
            wroteAny = true
        }

        return String(out)
    }

    private static func trimEndsOnly(_ value: String) -> String {
        // Không có lề thì trả lại chính chuỗi cũ, không dựng chuỗi mới. Đường này chạy trên
        // từng ô của cả bảng và phần lớn ô chẳng có gì để cắt.
        guard let first = value.unicodeScalars.first, let last = value.unicodeScalars.last,
              isCleanableSpace(first) || isCleanableSpace(last) else { return value }

        var scalars = Array(value.unicodeScalars)
        while let first = scalars.first, isCleanableSpace(first) { scalars.removeFirst() }
        while let last = scalars.last, isCleanableSpace(last) { scalars.removeLast() }
        var view = String.UnicodeScalarView()
        for scalar in scalars { view.append(scalar) }
        return String(view)
    }

    /// Đổi hoa thường cho một cột (FR-CLN-001).
    ///
    /// Dùng `uppercased()`/`lowercased()` của Swift chứ không tự đối chiếu bảng ASCII: tiếng
    /// Việt có "Đ"/"đ" và toàn bộ nguyên âm có dấu, và một bảng ASCII sẽ để nguyên chúng, cho
    /// ra "NGUYễN VăN A".
    public static func changeCase(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        to letterCase: CSVLetterCase,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Plan {
        try plan(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value in
            guard !value.isEmpty else { return .skip }
            let changed = applyCase(value, letterCase)
            return changed == value ? .alreadyClean : .changed(changed)
        }
    }

    static func applyCase(_ value: String, _ letterCase: CSVLetterCase) -> String {
        switch letterCase {
        case .upper: return value.uppercased()
        case .lower: return value.lowercased()
        case .title: return titleCased(value)
        }
    }

    /// Hoa chữ cái đầu mỗi từ, phần còn lại thành thường.
    ///
    /// Ranh giới từ tính theo khoảng trắng và dấu nối, KHÔNG theo `capitalized` của Foundation:
    /// `capitalized` cắt từ theo quy tắc ngôn ngữ và biến "TP.HCM" thành "Tp.Hcm". Ở đây chỉ
    /// làm đúng một việc đơn giản, có thể đoán trước được.
    static func titleCased(_ value: String) -> String {
        var out = ""
        var atWordStart = true
        for character in value {
            if character.isLetter || character.isNumber {
                out += atWordStart ? character.uppercased() : character.lowercased()
                atWordStart = false
            } else {
                out.append(character)
                atWordStart = character != "'" && character != "’"
            }
        }
        return out
    }
}
