import AppKit
import GEditorCore

/// Sổ đăng ký các cửa sổ soạn thảo (FR-DOC-301 · FR-DOC-302 · FR-DOC-303).
///
/// **Vì sao cần một lớp riêng thay vì hỏi `NSApp.windows`.** `NSApp.windows` trả về cả cửa sổ
/// Cài đặt, xem trước Markdown, panel thử regex, và cả những cửa sổ AppKit tự dựng mà ta không
/// biết tên. Lọc chúng ra bằng cách thử ép kiểu `windowController` thì chạy được, nhưng thứ tự
/// lại do AppKit quyết định — mà thứ tự chính là thứ phiên làm việc phải khôi phục đúng.
///
/// **Cửa sổ đầu tiên không đặc biệt.** Bản trước có đúng một `MainWindowController` do
/// `AppDelegate` giữ, và mọi thứ đều đi qua nó. Nếp ấy phải bỏ hẳn: một "cửa sổ chính" ngầm định
/// sẽ lộ ra đúng lúc người dùng đóng nó và mở tiếp cửa sổ khác.
///
/// **Không phải singleton vì tiện, mà vì đúng.** Có đúng MỘT sổ đăng ký cửa sổ trong một tiến
/// trình; hai sổ thì hai bên nói hai điều khác nhau về việc phiên nào cần lưu.
final class WindowManager {

    static let shared = WindowManager()

    private(set) var controllers: [MainWindowController] = []

    /// Cửa sổ đang ở trước, hoặc cửa sổ đầu nếu không cửa sổ nào là key.
    ///
    /// `nil` chỉ khi chưa có cửa sổ nào — trạng thái tồn tại đúng một nhịp lúc khởi động.
    var active: MainWindowController? {
        controllers.first { $0.window?.isKeyWindow == true } ?? controllers.first
    }

    private init() {}

    // MARK: - Vòng đời

    @discardableResult
    func newWindow(at frame: NSRect? = nil) -> MainWindowController {
        let controller = MainWindowController()
        controller.loadSettings()
        register(controller)
        controller.showWindow(nil)

        if let frame {
            controller.window?.setFrame(frame, display: false)
        } else if controllers.count > 1, let previous = controllers[controllers.count - 2].window,
                  let window = controller.window {
            // Cửa sổ thứ hai trở đi đặt LỆCH khỏi cửa sổ trước, không chồng khít.
            //
            // Chồng khít thì người dùng vừa bấm "Cửa sổ mới" và thấy… đúng màn hình cũ. Họ
            // tưởng lệnh không chạy và bấm thêm vài lần nữa.
            let offset = CGFloat(24)
            var next = previous.frame
            next.origin.x += offset
            next.origin.y -= offset
            window.setFrame(next, display: false)
        }
        controller.window?.makeKeyAndOrderFront(nil)
        return controller
    }

    func register(_ controller: MainWindowController) {
        guard !controllers.contains(where: { $0 === controller }) else { return }
        controllers.append(controller)
        controller.onWindowClosed = { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.forget(controller)
        }
    }

    private func forget(_ controller: MainWindowController) {
        controllers.removeAll { $0 === controller }
        // Ghi phiên NGAY khi một cửa sổ đóng, không đợi lúc thoát app: đóng cửa sổ rồi tắt máy
        // đột ngột thì lần ghi lúc thoát không bao giờ chạy, và phiên vẫn giữ cửa sổ đã đóng.
        saveSession()
    }

    /// Cửa sổ soạn thảo nằm dưới một điểm trên MÀN HÌNH, trừ `excluding`.
    ///
    /// Dùng cho phép kéo tab: lúc thả, thứ duy nhất biết được là toạ độ màn hình. Duyệt theo
    /// thứ tự cửa sổ ĐANG Ở TRÊN trước (`orderedIndex` nhỏ hơn = ở trên), vì hai cửa sổ chồng
    /// nhau thì người dùng nhắm vào cái họ nhìn thấy.
    func controller(atScreenPoint point: NSPoint, excluding: MainWindowController?) -> MainWindowController? {
        controllers
            .filter { $0 !== excluding }
            .filter { $0.window?.frame.contains(point) == true }
            .min { ($0.window?.orderedIndex ?? .max) < ($1.window?.orderedIndex ?? .max) }
    }

    // MARK: - Phiên làm việc (FR-DOC-303)

    /// Phiên của TẤT CẢ cửa sổ, theo đúng thứ tự đăng ký.
    var currentSession: Session {
        Session(windows: controllers.flatMap { $0.currentSession.windows })
    }

    func saveSession() {
        guard let store = controllers.first?.sessionStore else { return }
        do {
            try store.save(currentSession.pruned())
        } catch {
            NSLog("[GEditor] không ghi được phiên: %@", String(describing: error))
        }
    }

    /// Mở lại mọi cửa sổ của phiên trước. Trả về tổng số tab đã khôi phục.
    ///
    /// Cửa sổ ĐẦU dùng lại controller đang có (nó đã hiện ra rồi); từ cửa sổ thứ hai mới dựng
    /// mới. Dựng mới cả cửa sổ đầu thì người dùng thấy một cửa sổ trống nháy lên rồi biến mất.
    @discardableResult
    func restoreSession() -> Int {
        guard let first = controllers.first,
              let store = first.sessionStore as SessionStore?,
              let session = try? store.load()
        else { return 0 }

        let windows = session.pruned().windows
        guard !windows.isEmpty else { return 0 }

        var restored = first.restoreSession(window: windows[0])
        for entry in windows.dropFirst() {
            let controller = newWindow(at: entry.frameRect)
            restored += controller.restoreSession(window: entry)
        }
        first.window?.makeKeyAndOrderFront(nil)
        return restored
    }
}

extension SessionWindow {
    /// `frame` của phiên đổi thành `NSRect`, hoặc `nil` khi phiên không ghi khung.
    var frameRect: NSRect? {
        guard let frame, frame.count == 4 else { return nil }
        return NSRect(x: frame[0], y: frame[1], width: frame[2], height: frame[3])
    }
}
