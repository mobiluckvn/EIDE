import CryptoKit
import Foundation

/// Tệp `mermaid.min.js` đã vendor — NFR-MMD-02 (*"nằm trong bundle app, không CDN, không
/// network; phiên bản pin và ghi trong About"*).
///
/// ## Nạp LƯỜI, và đó là một chỉ tiêu chứ không phải một tối ưu
///
/// Tệp nặng 3,4 MB. NFR-PERF-05 đòi *"≤ 80 MB RAM khi idle với 1 tab văn bản nhỏ"*, và NFR-MMD-01
/// đòi *"WKWebView CHỈ khởi tạo khi mở preview lần đầu — khởi động app và RAM nghỉ không đổi"*.
/// Một `static let` đọc tệp lúc nạp lớp sẽ phá cả hai, và phá theo kiểu không ai nhận ra: app
/// vẫn chạy đúng, chỉ nặng thêm 3,4 MB mãi mãi kể cả với người không bao giờ mở một sơ đồ nào.
///
/// Nên `source` là `lazy` thật sự: chỉ đọc ở lần gọi đầu tiên, và chỉ có ai đó mở preview mới
/// gọi tới.
public enum MermaidAsset {

    public struct Manifest: Codable, Equatable, Sendable {
        public var name: String
        public var version: String
        public var license: String
        public var file: String
        public var bytes: Int
        public var sha256: String
        public var source: String

        /// Dòng cho hộp About — NFR-MMD-02 đòi phiên bản hiện ở đó.
        public var aboutLine: String {
            "\(name) \(version) (\(license)) — đóng gói offline, không tải từ mạng"
        }
    }

    /// Nơi đi tìm, theo thứ tự. Cùng khuôn `DuckDB.libraryCandidates`.
    public static var candidates: [String] = {
        var paths: [String] = []
        // 1. Ép bằng biến môi trường — cho CI và cho lúc thử một phiên bản khác.
        if let forced = ProcessInfo.processInfo.environment["GEDITOR_MERMAID_JS"] {
            paths.append(forced)
        }
        // 2. Trong bundle đã ký — đường của bản phát hành.
        if let resources = Bundle.main.resourcePath {
            paths.append(resources + "/mermaid/mermaid.min.js")
        }
        // 3. Cây làm việc — để `swift test` và bộ đo chạy được mà không cần dựng bundle.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Mermaid
            .deletingLastPathComponent()   // GEditorCore
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // gốc kho
        paths.append(root.appendingPathComponent("vendor/mermaid/mermaid.min.js").path)
        return paths
    }()

    /// Đường dẫn tệp thật, `nil` khi không máy nào có.
    public static var path: String? {
        candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Vì sao không dùng được — để giao diện nói được câu tử tế thay vì im lặng.
    public static var failureReason: String {
        "không tìm thấy mermaid.min.js — đã thử: " + candidates.joined(separator: ", ")
            + ". Chạy scripts/vendor-mermaid.sh."
    }

    public static var isAvailable: Bool { path != nil }

    /// Bản kê cạnh tệp. `nil` khi thiếu tệp hoặc bản kê hỏng.
    public static var manifest: Manifest? {
        guard let path else { return nil }
        let json = (path as NSString).deletingLastPathComponent + "/VERSION.json"
        guard let data = FileManager.default.contents(atPath: json) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    /// Nội dung `mermaid.min.js`. Đọc MỘT lần cho cả tiến trình.
    ///
    /// Không ném lỗi mà trả `nil`: chỗ gọi luôn là một panel, và panel cần một câu để hiện ra
    /// chứ không cần một `Error` để bọc lại.
    public static func source() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        guard let path, let data = FileManager.default.contents(atPath: path) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        cached = text
        return text
    }

    /// Quên nội dung đã nhớ. Có mặt cho bài kiểm và cho lúc đổi phiên bản khi đang chạy.
    public static func forgetCache() {
        lock.lock()
        defer { lock.unlock() }
        cached = nil
    }

    /// Tệp trên đĩa có ĐÚNG là bản đã ghi trong bản kê không — NFR-SEC-03 (chuỗi cung ứng).
    ///
    /// Không gọi trong đường chạy bình thường: băm 3,4 MB tốn vài chục mili-giây, và làm việc ấy
    /// mỗi lần mở preview là trả một khoản đều đặn cho một câu hỏi chỉ đáng hỏi khi nghi ngờ.
    /// Cổng CI gọi nó.
    public static func verifyChecksum() -> Bool {
        guard let path, let manifest,
              let data = FileManager.default.contents(atPath: path) else { return false }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == manifest.sha256
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var cached: String?
}
