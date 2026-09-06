import Foundation
import Security

/// GEditor phát hành qua HAI kênh, và app tự biết mình đang là bản nào.
///
/// **Vì sao hai bản** (chốt 22/08/2026, xem `docs/appstore-ra-soat.md`):
///
/// | | App Store | Trang web |
/// |---|---|---|
/// | App Sandbox | có (bắt buộc) | không |
/// | `geditor` CLI | **không có** | có |
/// | Ký bằng | 3rd Party Mac Developer | Developer ID + công chứng |
///
/// Mac App Store không cho app đặt tệp ra ngoài vùng chứa của nó, nên không có cách nào đưa
/// `geditor` vào `PATH`. Và ngay cả khi người dùng tự chép tay thì cầu nối cũng đứt: `CLIBridge`
/// dùng socket Unix trong Application Support, mà với app sandbox đường ấy trỏ vào container —
/// một tiến trình CLI không sandbox không mở được. Đó là lý do kỹ thuật, không phải lựa chọn.
///
/// **Nhận biết lúc CHẠY, không phải lúc biên dịch.** Một cờ `#if APPSTORE` sẽ đẻ ra hai binary,
/// hai ma trận kiểm thử, và một khả năng lệch pha: dựng bằng cờ này rồi ký bằng entitlement kia
/// thì app tin một đằng mà hệ điều hành cho phép một nẻo. Hỏi thẳng chữ ký của chính tiến trình
/// thì không lệch được — câu trả lời chính là thứ hệ điều hành đang áp dụng.
public enum Distribution: String, Sendable {

    /// Bản App Store: chạy trong App Sandbox.
    case appStore
    /// Bản tải từ trang web: Developer ID, đã công chứng, không sandbox.
    case direct

    public static let current: Distribution = isSandboxed() ? .appStore : .direct

    /// Cầu nối cho `geditor` chỉ dựng được ở bản trực tiếp.
    public var supportsCLIBridge: Bool { self == .direct }

    /// Lọc văn bản qua lệnh ngoài (FR-AUTO-604) — App Sandbox không cho tạo tiến trình con
    /// tuỳ ý, nên bản App Store không có tính năng này.
    public var supportsTextFilter: Bool { self == .direct }

    /// Tự cập nhật qua Sparkle (NFR-SEC-01) — chỉ bản tải trực tiếp.
    ///
    /// Bản App Store cập nhật qua Apple, và **nhúng một kênh cập nhật riêng vào bản nộp lên là
    /// lý do bị từ chối duyệt**: quy định của App Store cấm app tự tải và chạy mã mới ngoài
    /// kênh của Apple. Đây là giới hạn của cửa hàng, không phải giới hạn kỹ thuật — cùng họ với
    /// `supportsCLIBridge` và `supportsTextFilter`.
    ///
    /// Sparkle vẫn được LIÊN KẾT vào cả hai bản (một binary, một đường mã — xem `ADR-16`), chỉ
    /// là bản App Store không bao giờ khởi tạo bộ cập nhật. Tách binary theo cờ biên dịch sẽ đẻ
    /// ra hai ma trận kiểm thử và một khả năng lệch pha, đúng điều ghi ở đầu kiểu này.
    public var supportsSelfUpdate: Bool { self == .direct }

    public var displayName: String {
        switch self {
        case .appStore: return "App Store"
        case .direct: return "Bản tải trực tiếp"
        }
    }

    // MARK: - Nhận biết

    /// Tiến trình này có đang chạy trong App Sandbox không.
    ///
    /// Hỏi entitlement của CHÍNH chữ ký đang áp dụng. Cách hay gặp khác là dò biến môi trường
    /// `APP_SANDBOX_CONTAINER_ID` hoặc xem `HOME` có nằm trong `~/Library/Containers` không —
    /// cả hai đều là dấu hiệu gián tiếp và đều giả được. Giữ chúng làm dự phòng cho trường hợp
    /// không đọc nổi chữ ký, chứ không dùng làm câu trả lời chính.
    public static func isSandboxed() -> Bool {
        if let task = SecTaskCreateFromSelf(nil) {
            var error: Unmanaged<CFError>?
            let value = SecTaskCopyValueForEntitlement(
                task, "com.apple.security.app-sandbox" as CFString, &error
            )
            error?.release()
            if let number = value as? NSNumber {
                return number.boolValue
            }
            // Đọc được chữ ký mà không có entitlement ấy → chắc chắn KHÔNG sandbox.
            if error == nil { return false }
        }
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil { return true }
        return NSHomeDirectory().contains("/Library/Containers/")
    }
}
