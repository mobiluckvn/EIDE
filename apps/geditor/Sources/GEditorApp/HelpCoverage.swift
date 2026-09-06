import AppKit
import GEditorCore

/// Vế "không phải một lệnh" của cổng phủ hướng dẫn.
///
/// `AppDelegate.appOwnedMenuTitles` chụp **cả nhan đề nhóm lẫn nhan đề mục** — nó sinh ra để
/// phục vụ bài kiểm bản dịch, và bài ấy cần cả hai. Cổng phủ hướng dẫn thì chỉ hỏi về mục.
///
/// **Danh sách này cố ý CHỈ chứa nhan đề nhóm.** Cám dỗ là thả thêm vào đây mọi lệnh chưa kịp
/// viết hướng dẫn, và mỗi lần thả là cổng lại xanh trở lại — đúng cơ chế đã làm trang trạng thái
/// trôi mất 87 commit. Nhóm menu thì khác: chúng không phải lệnh, chúng không làm gì khi bấm, và
/// số lượng của chúng cố định.
enum HelpCoverage {

    /// Nhan đề của mười nhóm trên thanh menu. Không phải lệnh, nên không cần trang hướng dẫn.
    ///
    /// Ghi bằng tiếng Việt lẫn tiếng Anh vì `makeMenu` gọi `L(title)`: bản gốc là chuỗi tiếng
    /// Anh (`"File"`, `"Edit"`…), còn khi giao diện chạy tiếng Việt thì nó đã được dịch trước
    /// khi vào thanh menu. Cổng phải đúng ở cả hai ngôn ngữ, nếu không nó lại là một bài kiểm
    /// đổi màu theo môi trường.
    static let notCommands: Set<String> = {
        let english = ["File", "Edit", "Search", "Lines", "CSV", "Format", "View", "Macro",
                       "Window", "Help"]
        // Nhóm menu ứng dụng có nhan đề RỖNG: macOS thay nó bằng tên ứng dụng lúc hiện ra, nên
        // `NSMenu(title:)` của nó không mang chữ nào. Nó vẫn lọt vào ảnh chụp nhan đề, và nếu
        // không trừ ở đây thì cổng đòi một trang hướng dẫn cho một chuỗi rỗng.
        return Set(english + english.map { L($0) } + [""])
    }()

    /// Lệnh trên menu chưa có trang hướng dẫn nào nhận.
    static func missingCommands(in book: HelpBook) -> [String] {
        AppDelegate.appOwnedMenuTitles
            .subtracting(notCommands)
            .subtracting(book.coveredCommands)
            .sorted()
    }
}
