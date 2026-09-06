import Foundation

/// Chèn văn bản, dãy số hoặc dãy ngày vào MỌI dòng của vùng chọn cột (FR-CORE-003).
///
/// Việc thật mà nó giải: đánh số 5.000 dòng, sinh mã `SP-0001…SP-5000`, điền ngày tăng dần cho
/// một cột trong CSV. Làm tay thì không xong, làm bằng regex thì không đánh số được.
///
/// Chỉ sinh ra CHUỖI, không tự sửa buffer: chỗ gọi ghép với `MultiSelection` rồi áp một lần,
/// nên chèn vào 5.000 dòng vẫn là MỘT bước undo (FR-CORE-004).
public enum ColumnEditor {

    public enum Radix: Int, CaseIterable, Sendable {
        case binary = 2
        case octal = 8
        case decimal = 10
        case hexadecimal = 16

        public var displayName: String {
            switch self {
            case .binary: return "Nhị phân"
            case .octal: return "Bát phân"
            case .decimal: return "Thập phân"
            case .hexadecimal: return "Thập lục phân"
            }
        }
    }

    public enum Content {
        /// Cùng một chuỗi cho mọi dòng.
        case text(String)
        /// Dãy số tăng dần.
        case number(start: Int, step: Int, radix: Radix, padding: Int, uppercase: Bool)
        /// Dãy ngày tăng dần, `step` tính bằng NGÀY.
        case date(start: Date, stepDays: Int, format: String)
    }

    /// Sinh `count` giá trị.
    public static func values(_ content: Content, count: Int, calendar: Calendar = .current) -> [String] {
        guard count > 0 else { return [] }

        switch content {
        case .text(let text):
            return Array(repeating: text, count: count)

        case .number(let start, let step, let radix, let padding, let uppercase):
            return (0 ..< count).map { index in
                let value = start + step * index
                // Số ÂM: dấu trừ đứng trước phần đệm 0, không bị đệm chen vào giữa.
                let magnitude = String(abs(value), radix: radix.rawValue, uppercase: uppercase)
                let padded = magnitude.count >= padding
                    ? magnitude
                    : String(repeating: "0", count: padding - magnitude.count) + magnitude
                return value < 0 ? "-" + padded : padded
            }

        case .date(let start, let stepDays, let format):
            let formatter = DateFormatter()
            formatter.dateFormat = format
            // Lịch và múi giờ của MÁY, không phải UTC: người dùng điền ngày theo lịch họ đang
            // nhìn. Dùng UTC sẽ lệch một ngày với nửa số múi giờ.
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            return (0 ..< count).map { index in
                let date = calendar.date(byAdding: .day, value: stepDays * index, to: start) ?? start
                return formatter.string(from: date)
            }
        }
    }
}

public extension MultiSelection {

    /// Chèn giá trị thứ i vào vùng chọn thứ i (Column Editor).
    ///
    /// Thiếu giá trị thì các vùng còn lại KHÔNG bị đụng tới — thà chèn thiếu còn hơn chèn bừa
    /// một giá trị lặp lại mà người dùng không yêu cầu.
    func edits(insertingEach values: [String]) -> [TextEdit] {
        zip(ranges, values).map { TextEdit(range: $0, text: $1) }
    }
}
