import Foundation

/// Ba chế độ ngắt dòng mềm mà SRS đòi ở FR-CORE-015.
///
/// Là kiểu của LÕI chứ không phải của view vì nó là thuộc tính của tài liệu: phiên làm việc
/// (FR-DOC-303) phải ghi lại được, và dòng lệnh phải đặt được.
public enum WrapMode: Equatable, Sendable {

    /// Không ngắt: dòng dài chạy ngang, có thanh cuộn ngang.
    case off
    /// Ngắt theo chiều rộng cửa sổ — đổi cỡ cửa sổ thì ngắt lại.
    case window
    /// Ngắt tại một cột cố định, không phụ thuộc cửa sổ.
    ///
    /// Dùng khi soạn thứ có quy ước độ rộng (commit message 72 cột, thư RFC 80 cột): người
    /// dùng cần thấy ĐÚNG chỗ dòng sẽ bị gãy ở nơi khác, không phải chỗ cửa sổ đang gãy.
    case column(Int)

    /// Vòng qua ba chế độ — một mục menu, một phím tắt.
    ///
    /// Cột mặc định là 80: đó là cột mà mọi quy ước còn sống đều bám vào.
    public func next(defaultColumn: Int = 80) -> WrapMode {
        switch self {
        case .off: return .window
        case .window: return .column(defaultColumn)
        case .column: return .off
        }
    }

    public var displayName: String {
        switch self {
        case .off: return "Tắt"
        case .window: return "Theo cửa sổ"
        case .column(let column): return "Tại cột \(column)"
        }
    }

    public var isOn: Bool { self != .off }
}
