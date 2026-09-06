import AppKit
import GEditorCore

/// Nhận văn bản và file từ ứng dụng KHÁC qua menu Services (FR-AUTO-606).
///
/// Bôi đen một đoạn trong Safari hoặc Mail rồi chọn `Services ▸ Mở trong GEditor` — đoạn ấy hiện
/// ra thành một tab mới. Đây là nửa dễ và hữu ích nhất của FR-AUTO-606, và là nửa duy nhất chạy
/// được ở **cả hai kênh phát hành**: Services đi qua pasteboard của hệ điều hành, không đòi
/// quyền nào mà App Sandbox từ chối.
///
/// **Không trả kết quả ngược lại.** `NSReturnTypes` trong Info.plist để rỗng, và hai hàm dưới
/// đây không đụng vào `pasteboard` đầu ra. Khai kiểu trả về mà không trả gì thì ứng dụng gọi sẽ
/// chờ một câu trả lời không bao giờ tới.
///
/// **Lỗi phải ghi vào `error`, không phải nuốt đi.** macOS hiện chuỗi ấy cho người dùng; im lặng
/// thì họ chọn Services, không có gì xảy ra, và không biết vì sao.
final class ServicesProvider: NSObject {

    private weak var controller: MainWindowController?

    init(controller: MainWindowController) {
        self.controller = controller
        super.init()
    }

    @objc func openSelectedTextInGEditor(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "Không có văn bản nào trong vùng chọn"
            return
        }
        guard let controller else {
            error.pointee = "GEditor chưa có cửa sổ nào"
            return
        }
        controller.openTextFromServices(text)
    }

    @objc func openSelectedFilesInGEditor(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        let files = urls.filter { $0.isFileURL }
        guard !files.isEmpty else {
            error.pointee = "Không có file nào được chọn"
            return
        }
        guard let controller else {
            error.pointee = "GEditor chưa có cửa sổ nào"
            return
        }
        // Mở TẤT CẢ, không chỉ file đầu: người dùng chọn năm file thì họ muốn năm tab. Đây là
        // chỗ khác với `application(_:openFiles:)`, nơi giới hạn cũ vẫn còn.
        for url in files { controller.openInNewTab(path: url.path) }
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
