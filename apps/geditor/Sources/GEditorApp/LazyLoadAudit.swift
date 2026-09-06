import Darwin
import Foundation

/// Bất biến "khởi động chỉ kích hoạt thứ THỰC SỰ CẦN" — anh chốt 26/08/2026, ADR-14.
///
/// Quyết định nhúng DuckDB đi kèm một điều kiện: **dung lượng bundle được phép tăng, thời gian
/// khởi động thì không**. Điều kiện ấy chỉ có nghĩa nếu máy kiểm được, vì nó là loại ràng buộc
/// bị phá bởi một dòng `import` vô hại của người chưa đọc ADR.
///
/// ## Hai vế, và vì sao phải tách chúng ra
///
/// Bản đầu của file này gộp mọi thứ vào một danh sách "thư viện nặng" rồi hỏi dyld xem có nạp
/// chưa. Chạy thử một lần là thấy sai: **WebKit, JavaScriptCore và libxml2 đã nằm sẵn trong
/// tiến trình ngay lúc cửa sổ hiện ra** — 1039 ảnh dyld, phần lớn do AppKit và Foundation kéo
/// vào, không phải do mã của ta. Một cổng chặn chúng sẽ đỏ vĩnh viễn vì một lý do ta không sửa
/// được, và cổng đỏ vĩnh viễn là cổng sẽ bị tắt.
///
/// Đo tiếp thì rõ vì sao nó không đáng chặn: framework hệ thống nằm trong **dyld shared cache**,
/// nên LIÊN KẾT chúng gần như miễn phí — WebKit +1,4 ms trên sàn nhiễu 0,9 ms (PoC-L),
/// JavaScriptCore +1,8 ms trên sàn nhiễu 1,4 ms (đo 26/08/2026, cùng phương pháp). Cả hai đều
/// không phân biệt được với nhiễu.
///
/// Thứ ĐẮT không phải "có mặt" mà là **"bị dựng lên"**: một `WKWebView` đầu tiên tốn 830 ms và
/// +35 MB RAM (PoC-L), một kết nối DuckDB kéo theo 94 MB dylib (PoC-K). Nên bất biến này có
/// hai vế, và chúng được kiểm bằng hai cơ chế khác hẳn nhau:
///
/// - **Vế A — dylib CỦA TA phải chưa nạp.** Hỏi nhân qua `_dyld_image_count`. Không ai quên
///   khai được, vì không có gì để khai. Đây là vế gác DuckDB.
/// - **Vế B — hệ thống con phải chưa KÍCH HOẠT.** Không có danh sách nào của nhân trả lời được
///   "đã ai dựng `JSContext` chưa", nên vế này dựa vào việc mỗi hệ thống con tự đóng dấu ở
///   **đúng một chỗ**: hàm khởi tạo của chính nó. Yếu hơn vế A, và tài liệu này nói thẳng ra
///   như thế thay vì để người đọc tưởng hai vế mạnh ngang nhau.
enum LazyLoadAudit {

    // MARK: - Vế A: dylib của ta, hỏi nhân

    struct BundledLibrary {
        /// Tên để in cho người đọc.
        let name: String
        /// Mẩu chuỗi tìm trong đường dẫn ảnh dyld. So bằng `contains` chứ không so đường dẫn
        /// đầy đủ: cùng một dylib nằm ở chỗ khác nhau giữa bản dev và bản `.app` đã ký.
        let imageMatch: String
        /// Vì sao nó phải lười — đi thẳng vào thông báo lỗi, để người làm vỡ cổng biết vỡ cái gì.
        let why: String
    }

    /// Chỉ những dylib **ta đóng gói và tự `dlopen`**. Framework hệ thống KHÔNG nằm ở đây: ta
    /// không quyết định được chúng, và đo rồi thì chúng cũng gần như miễn phí.
    static let bundled: [BundledLibrary] = [
        .init(name: "DuckDB", imageMatch: "libduckdb",
              why: "94 MB, dlopen 6,9 ms — chỉ nạp khi người dùng chạy truy vấn (ADR-14, PoC-K)"),
        .init(name: "bảng tra grammar nặng", imageMatch: "libTreeSitterHeavy",
              why: "tách nó ra là bước đưa khởi động ~520 → 465 ms (ADR-08 §2.13)"),
    ]

    /// Mọi ảnh dyld đang nạp trong tiến trình, tại đúng lúc gọi.
    static func loadedImages() -> [String] {
        var names: [String] = []
        names.reserveCapacity(Int(_dyld_image_count()))
        for index in 0 ..< _dyld_image_count() {
            if let raw = _dyld_get_image_name(index) {
                names.append(String(cString: raw))
            }
        }
        return names
    }

    static func loadedBundled(in images: [String]) -> [BundledLibrary] {
        bundled.filter { library in
            images.contains { $0.contains(library.imageMatch) }
        }
    }

    // MARK: - Vế B: hệ thống con đã kích hoạt

    /// Hệ thống con đắt tiền, đóng dấu ở đúng hàm khởi tạo của chính nó.
    ///
    /// Ghi bằng tên chuỗi chứ không bằng `enum` có sẵn mọi trường hợp: mục đích là thêm một hệ
    /// thống con mới KHÔNG phải sửa file này, để người thêm không có cơ hội "quên cập nhật danh
    /// sách" — họ chỉ cần gọi `activate(_:)` ở chỗ họ đang viết.
    private(set) static var activated: Set<String> = []

    /// Gọi ở dòng đầu của hàm dựng một hệ thống con đắt tiền.
    ///
    /// Ví dụ: `LazyLoadAudit.activate("JSContext")` trong `ScriptRunner`,
    /// `LazyLoadAudit.activate("WKWebView")` trong đường dựng preview.
    static func activate(_ subsystem: String) {
        activated.insert(subsystem)
    }

    // MARK: - Chụp tại mốc khởi động

    /// Ảnh dyld và hệ thống con đã kích hoạt, tại đúng lúc cửa sổ hiện ra.
    ///
    /// Chụp NGAY tại thời điểm ấy chứ không hỏi lúc bài kiểm chạy — cùng lý do với
    /// `StartupProbe.layersAtLaunch`: tới lúc bài kiểm chạy thì chính các bài khác đã mở panel
    /// SQL, chạy script và kiểm XSD, và câu trả lời không còn nói gì về khởi động nữa.
    private(set) static var imagesAtLaunch: [String] = []
    private(set) static var activatedAtLaunch: Set<String> = []

    static func captureAtLaunch() {
        imagesAtLaunch = loadedImages()
        activatedAtLaunch = activated
    }

    static var bundledLoadedAtLaunch: [BundledLibrary] {
        loadedBundled(in: imagesAtLaunch)
    }

    static var passesAtLaunch: Bool {
        bundledLoadedAtLaunch.isEmpty && activatedAtLaunch.isEmpty
    }

    /// Câu giải thích cho người làm vỡ cổng — nêu tên VÀ vì sao nó phải lười.
    static func failureMessage() -> String {
        var parts: [String] = []
        if !bundledLoadedAtLaunch.isEmpty {
            let lines = bundledLoadedAtLaunch
                .map { "  · \($0.name) — \($0.why)" }
                .joined(separator: "\n")
            parts.append("Dylib của ta đã NẠP ngay lúc cửa sổ hiện ra:\n" + lines)
        }
        if !activatedAtLaunch.isEmpty {
            parts.append("Hệ thống con đã KÍCH HOẠT ngay lúc cửa sổ hiện ra: "
                + activatedAtLaunch.sorted().joined(separator: ", "))
        }
        return parts.joined(separator: "\n") + """

            Mọi lần mở app đều trả tiền cho nó, kể cả lần người dùng chỉ mở một file text.
            Tìm chỗ chạm vào nó trên đường khởi động và hoãn lại tới lần dùng đầu tiên (ADR-14).
            """
    }
}
