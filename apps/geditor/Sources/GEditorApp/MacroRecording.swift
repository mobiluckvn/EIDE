import AppKit
import GEditorCore

/// Dịch lệnh soạn thảo của AppKit sang bước macro (FR-AUTO-601).
///
/// Tách khỏi controller để kiểm được bằng test, và vì bảng ánh xạ này sẽ còn dài ra: mỗi lệnh
/// soạn thảo mới muốn ghi được vào macro thì thêm một dòng ở đây, không phải sửa controller.
enum MacroCommandMapping {

    /// Bước macro tương ứng với một selector của `NSResponder`, hoặc `nil` nếu lệnh ấy không
    /// ghi được.
    ///
    /// Trả `nil` là chuyện thường và KHÔNG phải lỗi: người dùng bấm ⌘F giữa lúc ghi macro thì
    /// lệnh mở thanh Tìm không thuộc về nội dung macro. Cái được ghi là thao tác Find, ghi ở
    /// chỗ khác.
    static func step(for selector: Selector) -> MacroStep? {
        switch selector {
        case #selector(NSResponder.moveLeft(_:)), #selector(NSResponder.moveBackward(_:)):
            return .move(.left)
        case #selector(NSResponder.moveRight(_:)), #selector(NSResponder.moveForward(_:)):
            return .move(.right)
        case #selector(NSResponder.moveUp(_:)):
            return .move(.up)
        case #selector(NSResponder.moveDown(_:)):
            return .move(.down)
        case #selector(NSResponder.moveToBeginningOfLine(_:)),
             #selector(NSResponder.moveToLeftEndOfLine(_:)):
            return .move(.lineStart)
        case #selector(NSResponder.moveToEndOfLine(_:)),
             #selector(NSResponder.moveToRightEndOfLine(_:)):
            return .move(.lineEnd)
        case #selector(NSResponder.moveToBeginningOfDocument(_:)):
            return .move(.documentStart)
        case #selector(NSResponder.moveToEndOfDocument(_:)):
            return .move(.documentEnd)
        case #selector(NSResponder.deleteBackward(_:)):
            return .deleteBackward
        case #selector(NSResponder.deleteForward(_:)):
            return .deleteForward
        case #selector(NSResponder.insertNewline(_:)):
            return .insert("\n")
        case #selector(NSResponder.insertTab(_:)):
            return .insert("\t")
        default:
            return nil
        }
    }
}

/// Trạng thái ghi macro.
///
/// Gộp các bước GÕ liền nhau thành một bước: gõ "WARN" là bốn lần `insertText` nhưng chỉ nên
/// là một bước macro. Không gộp thì một macro ghi vài câu sẽ dài hàng trăm bước, đọc không
/// được và phát lại chậm hơn nhiều lần vì mỗi bước là một lần sửa buffer riêng.
final class MacroRecorder {

    private(set) var steps: [MacroStep] = []
    private(set) var isRecording = false

    func start() {
        steps = []
        isRecording = true
    }

    func stop() -> [MacroStep] {
        isRecording = false
        return steps
    }

    func record(_ step: MacroStep) {
        guard isRecording else { return }
        if case .insert(let text) = step, case .insert(let previous)? = steps.last {
            steps[steps.count - 1] = .insert(previous + text)
            return
        }
        steps.append(step)
    }

    func record(command selector: Selector) {
        guard isRecording, let step = MacroCommandMapping.step(for: selector) else { return }
        record(step)
    }
}
