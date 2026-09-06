import AppKit
import GEditorCore
import Sparkle

/// Kênh tự cập nhật — NFR-SEC-01, `docs/adr/ADR-16-sparkle.md`.
///
/// **Chỉ bản tải trực tiếp.** Bản App Store cập nhật qua Apple; nhúng một kênh riêng vào bản nộp
/// lên là lý do bị từ chối duyệt. Cổng đặt ở `Distribution.current.supportsSelfUpdate`, và nó
/// hỏi chữ ký của chính tiến trình chứ không hỏi một cờ biên dịch — xem `Distribution`.
///
/// **Khởi tạo LƯỜI, và đó là chỗ tốn tiền.** Liên kết Sparkle chỉ tốn ~1,3 ms (đo ở ADR-16 §3),
/// nhưng `SPUStandardUpdaterController` thì dựng cả bộ đệm cấu hình và một `NSBundle` phụ, rồi
/// lên lịch kiểm tra nền. Ngân sách khởi động ADR-08 còn 36 ms, nên bộ cập nhật chỉ ra đời ở
/// lần đầu ai đó cần tới nó — đúng khuôn `LazyLoadAudit` đã áp cho `libduckdb`.
///
/// **Không tự kiểm tra khi khởi động.** `startsUpdaterOnAppLaunch` để `false`: một lượt mạng
/// ngay lúc mở app là thứ người dùng không yêu cầu, và nó rơi đúng vào đoạn mà ADR-08 đang đếm
/// từng mili-giây. Sparkle vẫn tự lên lịch kiểm tra định kỳ sau khi bộ cập nhật được dựng.
@MainActor
final class UpdateController: NSObject {

    static let shared = UpdateController()

    /// Khoá công khai còn là chỗ giữ chỗ — chưa ai ký được bản cập nhật nào bằng nó.
    ///
    /// Giá trị thật sinh bằng `vendor/sparkle/bin/generate_keys`, cần người chạy vì Keychain
    /// hỏi quyền (`docs/khoa-va-ky.md` §2bis). `build-universal.sh` **từ chối dựng bản đã ký**
    /// khi `Info.plist` còn mang chuỗi này — một kênh cập nhật giả mà trông như thật là thứ
    /// tệ hơn không có kênh nào.
    static let placeholderPublicKey = "CHUA-CO-KHOA-THAT-xem-docs/khoa-va-ky.md"

    private var updater: SPUStandardUpdaterController?

    private override init() { super.init() }

    /// Bộ cập nhật có dùng được trong bản đang chạy không.
    var isAvailable: Bool {
        Distribution.current.supportsSelfUpdate && !hasPlaceholderKey
    }

    /// `Info.plist` còn mang khoá giữ chỗ — tức bản dựng này không thẩm định được chữ ký nào.
    var hasPlaceholderKey: Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        return key == nil || key == Self.placeholderPublicKey
    }

    /// Vì sao không cập nhật được — nói THẲNG ra, đừng để mục menu mờ đi không lý do.
    ///
    /// Một mục menu bị vô hiệu hoá mà không nói vì sao là câu hỏi hỗ trợ, không phải câu trả lời.
    var unavailableReason: String? {
        if !Distribution.current.supportsSelfUpdate {
            return L("Bản App Store cập nhật qua Mac App Store, không qua GEditor.")
        }
        if hasPlaceholderKey {
            return L("Bản dựng này chưa có khoá ký cập nhật nên không kiểm tra được.")
        }
        return nil
    }

    /// Dựng bộ cập nhật ở lần đầu cần tới. Trả `nil` nếu kênh này không dùng được.
    private func makeUpdaterIfNeeded() -> SPUStandardUpdaterController? {
        guard isAvailable else { return nil }
        if let updater { return updater }
        let made = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        updater = made
        return made
    }

    /// Người dùng bấm "Kiểm tra bản cập nhật…".
    func checkForUpdates(_ sender: Any?) {
        guard let updater = makeUpdaterIfNeeded() else { return }
        updater.checkForUpdates(sender)
    }

    /// Chỉ để bài tự kiểm soi — KHÔNG dựng bộ cập nhật, nên nó không kéo theo lượt mạng nào.
    ///
    /// Nhãn viết bằng ASCII có chủ ý: chuỗi này không bao giờ đến mắt người dùng, và một chuỗi
    /// tiếng Việt ở đây sẽ vào bộ đếm "chưa dịch" của FR-UI-804 — làm mốc nợ dịch trông xấu đi
    /// vì một dòng chẩn đoán không ai đọc.
    var diagnosticForSelfTest: String {
        "channel=\(Distribution.current.rawValue) available=\(isAvailable)"
            + " placeholderKey=\(hasPlaceholderKey) built=\(updater != nil)"
    }
}
