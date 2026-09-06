import AppKit
import GEditorCore

/// Thuộc tính AppleScript của ứng dụng (FR-AUTO-606).
///
/// **Vì sao đặt trên `NSApplication` chứ không trên một lớp tài liệu riêng.** Bộ máy scripting
/// của Cocoa tìm thuộc tính theo tên khoá mà `.sdef` khai, và `application` là lớp duy nhất
/// luôn tồn tại. Dựng một cây `document` đầy đủ đòi chuyển cả kiến trúc sang `NSDocument` — đó
/// là FR-DOC-305, một yêu cầu riêng.
///
/// **Ba thuộc tính, và cố ý dừng ở đó.** Cùng nguyên tắc với API script JavaScript: mở rộng bề
/// mặt về sau thì dễ, thu hẹp lại thì phá mọi script người dùng đã viết. Script cần DỮ LIỆU,
/// không cần giả làm người dùng bấm menu.
///
/// **`document text` ghi được, và mỗi lần ghi là MỘT bước hoàn tác** — đi qua `TextBuffer` như
/// mọi thao tác khác, nên người dùng ⌘Z được thứ script vừa làm.
extension NSApplication {

    /// Controller đang hoạt động, hoặc `nil` khi chưa có cửa sổ nào.
    ///
    /// `AppDelegate` giữ nó ở một thuộc tính riêng; ở đây đi qua `windows` để không phải mở
    /// rộng giao diện của delegate chỉ vì scripting.
    private var scriptingController: MainWindowController? {
        windows.compactMap { $0.windowController as? MainWindowController }.first
    }

    @objc var scriptingDocumentText: String {
        get { scriptingController?.editorDocument.buffer.text ?? "" }
        set {
            guard let controller = scriptingController else { return }
            guard !controller.editorDocument.isReadOnly else {
                // Nói ra qua đường lỗi của AppleScript. Im lặng thì script chạy xong, tài liệu
                // không đổi, và người viết script đi tìm lỗi trong chính script của họ.
                NSScriptCommand.current()?.scriptErrorString = "Tài liệu đang ở chế độ chỉ đọc"
                return
            }
            controller.replaceDocumentTextFromScripting(newValue)
        }
    }

    @objc var scriptingSelectedText: String {
        scriptingController?.selectedTextForSelfTest ?? ""
    }

    @objc var scriptingDocumentPath: String {
        scriptingController?.editorDocument.path ?? ""
    }
}
