import Foundation

/// Một bước trong macro (FR-AUTO-601).
///
/// Ghi lại LỆNH chứ không ghi lại phím thô. Ghi phím thô thì macro phụ thuộc bố cục bàn phím,
/// phụ thuộc bộ gõ đang bật, và không đọc được khi mở file macro ra xem. Quan trọng hơn: SRS
/// đòi ghi cả "lệnh menu và thao tác Find/Replace (kể cả regex)" — những thứ không có phím thô
/// tương ứng.
public enum MacroStep: Equatable, Codable {

    /// Gõ văn bản tại con trỏ; có vùng chọn thì thay vùng ấy.
    case insert(String)
    case deleteBackward
    case deleteForward
    case move(MacroMove)
    /// Chọn cả dòng hiện tại, KHÔNG kể ký tự xuống dòng.
    case selectLine
    /// Tìm và CHỌN chỗ khớp kế tiếp; không tìm thấy thì macro dừng.
    case find(pattern: String, mode: SearchMode, matchCase: Bool, wholeWord: Bool)
    /// Thay vùng đang chọn. `$1`… dùng được nếu bước ngay trước là `find` bằng regex.
    case replaceSelection(String)
}

public enum MacroMove: String, Equatable, Codable {
    case left, right, up, down
    case lineStart, lineEnd
    case nextLine, previousLine
    case documentStart, documentEnd
}

/// Macro đã ghi, có tên và lưu được (FR-AUTO-601: "lưu macro có tên vĩnh viễn").
public struct Macro: Equatable, Codable {
    public var name: String
    public var steps: [MacroStep]

    public init(name: String, steps: [MacroStep]) {
        self.name = name
        self.steps = steps
    }

    public var isEmpty: Bool { steps.isEmpty }
}

/// Vì sao macro dừng.
public enum MacroStopReason: Equatable {
    /// Chạy hết số lần yêu cầu.
    case finished
    /// Một bước `find` không tìm thấy gì — đây là cách macro "chạy đến cuối file" tự dừng.
    case notFound
    /// Con trỏ tới cuối tài liệu và không đi tiếp được.
    case endOfDocument
    /// Người dùng hủy.
    case cancelled
    /// Một vòng lặp không làm gì và không dịch chuyển — dừng để khỏi chạy mãi.
    case madeNoProgress
    case error(String)
}

public struct MacroResult: Equatable {
    public let repetitions: Int
    public let reason: MacroStopReason
    public let caretOffset: Int
}
