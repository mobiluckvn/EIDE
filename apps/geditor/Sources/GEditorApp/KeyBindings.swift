import AppKit
import GEditorCore

/// Phím tắt đổi được, và preset Notepad++ (FR-UI-802).
///
/// **Khoá là TÊN SELECTOR**, ví dụ `duplicateLines:`. Không đặt một hệ mã lệnh riêng: selector
/// đã là định danh duy nhất của mỗi lệnh trong AppKit, và một bảng ánh xạ thứ hai giữa "mã lệnh"
/// và selector chỉ là thêm một chỗ để lệch nhau.
///
/// **Chỉ lưu phần KHÁC mặc định** (xem `Settings.keyBindings`). Lưu cả bảng thì mỗi lần sản phẩm
/// đổi một phím mặc định, người dùng cũ mắc kẹt ở bảng cũ mà không ai nói cho họ biết.
///
/// **Cú pháp phím giống hệt `AppDelegate.makeMenu`**: `^` = ⌃, `~` = ⌥, `+` = ⇧, `!` = BỎ ⌘,
/// chữ HOA = ⇧. Dùng chung một cú pháp để người dùng đọc mã và đọc file cấu hình thấy cùng một
/// thứ, và để không có hai bộ phân tích phím phải giữ cho khớp nhau.
enum KeyBindings {

    /// Preset phím của Notepad++, cho người mang trí nhớ cơ bắp từ Windows sang.
    ///
    /// **Không phải bản sao y nguyên.** `Ctrl` của Windows ánh xạ sang `⌘` của macOS, nhưng vài
    /// phím không dời được: `⌘L` trên macOS là "đi tới dòng" ở mọi ứng dụng, còn Notepad++ dùng
    /// `Ctrl+L` để xoá dòng. Preset này chọn phía Notepad++ cho những lệnh RIÊNG của trình soạn
    /// thảo, và giữ phía macOS cho những lệnh cả hệ điều hành đều có.
    static let notepadPlusPlusPreset: [String: String] = [
        "duplicateLines:": "d",          // Ctrl+D
        "deleteLines:": "l",             // Ctrl+L  — đổi chỗ với "Đi tới dòng"
        "goToLine:": "g",                // Ctrl+G
        "toggleComment:": "q",           // Ctrl+Q
        "findNextFromMenu:": "!\u{F706}",// F3
        "selectNextOccurrence:": "~d",   // ⌥⌘D, vì ⌘D đã nhường cho "Nhân đôi dòng"
    ]

    /// Tên hiển thị của những lệnh cho phép đổi phím.
    ///
    /// Cố ý là một danh sách CÓ CHỌN LỌC, không phải mọi selector: đổi phím của "Lưu" hay "Sao
    /// chép" thì người dùng tự làm hỏng những phím mà cả hệ điều hành dùng chung, và không có
    /// lý do chính đáng nào để mở cửa ấy.
    static let rebindable: [(selector: String, title: String)] = [
        ("duplicateLines:", "Nhân đôi dòng"),
        ("deleteLines:", "Xóa dòng"),
        ("toggleComment:", "Comment dòng"),
        ("goToLine:", "Đi tới dòng…"),
        ("goToMatchingBracket:", "Nhảy tới ngoặc khớp"),
        ("selectNextOccurrence:", "Chọn lần kế tiếp"),
        ("findNextFromMenu:", "Kết quả kế"),
        ("findPreviousFromMenu:", "Kết quả trước"),
        ("toggleDocumentMap:", "Ẩn/hiện bản đồ tài liệu"),
        ("toggleSidebar:", "Ẩn/hiện sidebar (Function List)"),
        ("showClipboardHistory:", "Lịch sử clipboard…"),
        ("increaseFontSize:", "Phóng to chữ"),
        ("decreaseFontSize:", "Thu nhỏ chữ"),
    ]

    /// Áp bảng phím của người dùng lên menu bar đã dựng.
    ///
    /// Chạy SAU khi menu dựng xong chứ không xen vào lúc dựng: `buildMenuBar` là nơi giữ phím
    /// MẶC ĐỊNH, và trộn hai nguồn vào một chỗ sẽ không còn đọc ra được phím gốc của một lệnh
    /// là gì. Ở đây thì rõ — mặc định trước, người dùng đè lên sau.
    ///
    /// Trả về danh sách lệnh KHÔNG áp được vì phím đã có chủ. Bỏ qua lặng lẽ thì người dùng đặt
    /// một phím trùng, thấy nó không chạy, và không có gì nói cho họ biết vì sao.
    @discardableResult
    static func apply(_ bindings: [String: String], to menu: NSMenu?) -> [String] {
        guard let menu else { return [] }
        var items: [String: NSMenuItem] = [:]
        var taken: [String: String] = [:]

        for group in menu.items {
            guard let submenu = group.submenu else { continue }
            for item in submenu.items where !item.isSeparatorItem {
                if let action = item.action { items[NSStringFromSelector(action)] = item }
                if !item.keyEquivalent.isEmpty {
                    taken[signature(item.keyEquivalent, item.keyEquivalentModifierMask)] = item.title
                }
            }
        }

        var rejected: [String] = []
        for (selector, key) in bindings.sorted(by: { $0.key < $1.key }) {
            guard let item = items[selector] else { continue }
            let (equivalent, modifiers) = parse(key)
            let wanted = signature(equivalent, modifiers)
            // Phím đang thuộc về CHÍNH lệnh này thì không tính là trùng.
            if let owner = taken[wanted], owner != item.title {
                rejected.append("\(item.title) ↔ \(owner)")
                continue
            }
            taken.removeValue(forKey: signature(item.keyEquivalent, item.keyEquivalentModifierMask))
            item.keyEquivalent = equivalent
            item.keyEquivalentModifierMask = modifiers
            taken[wanted] = item.title
        }
        return rejected
    }

    /// Cùng cú pháp với `AppDelegate.makeMenu`.
    static func parse(_ key: String) -> (String, NSEvent.ModifierFlags) {
        var modifiers: NSEvent.ModifierFlags = [.command]
        var key = key
        while let first = key.first, "^~+!".contains(first) {
            switch first {
            case "^": modifiers.insert(.control)
            case "~": modifiers.insert(.option)
            case "+": modifiers.insert(.shift)
            default: modifiers.remove(.command)
            }
            key.removeFirst()
        }
        if key.first?.isUppercase == true { modifiers.insert(.shift) }
        return (key, key.isEmpty ? [] : modifiers)
    }

    private static func signature(_ key: String, _ modifiers: NSEvent.ModifierFlags) -> String {
        "\(modifiers.rawValue)+\(key)"
    }
}
