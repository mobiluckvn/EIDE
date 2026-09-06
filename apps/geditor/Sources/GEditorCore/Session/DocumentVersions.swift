import Foundation

/// Duyệt và khôi phục các bản đã lưu trước đó — FR-DOC-305, hướng (A) của PoC-J.
///
/// ## Vì sao KHÔNG chuyển sang `NSDocument`
///
/// `scripts/run-poc-j.sh` đo hai thứ. Một: `NSFileVersion` giữ và khôi phục bản cũ mà **không
/// cần `NSDocument`** — kho phiên bản là của hệ điều hành, và API vào kho ấy là công khai. Hai:
/// giá của việc chuyển sang `NSDocument` — 413 chỗ chạm tài liệu, **29 chỗ chỉ mục `tabs[]`**,
/// 657 dòng phiên/bản nháp/CLI phải hoà lại, 203 chỗ trong bộ tự kiểm.
///
/// Con số 29 mới là con số quyết định: `NSDocument` giả định **một tài liệu — một cửa sổ**, còn
/// GEditor có tab, tức nhiều tài liệu trong một cửa sổ. Đó không phải công sức, đó là xung đột
/// mô hình.
///
/// **Điều tệp này KHÔNG làm, và phải nói ra:** giao diện lịch sử NGUYÊN BẢN của macOS
/// (`NSDocument.browseVersions`) chỉ có khi dùng `NSDocument`. Ở đây là kho phiên bản của hệ
/// điều hành với bảng duyệt của GEditor. Ai đọc FR-DOC-305 theo đúng câu chữ *"theo giao diện
/// lịch sử của hệ điều hành"* thì đây chưa phải câu trả lời đủ — và chuyện ấy là quyết định
/// phạm vi, không phải chuyện kỹ thuật.
public enum DocumentVersions {

    /// Một bản đã lưu trước đó.
    public struct Version: Equatable, Sendable {
        public let url: URL
        public let date: Date?
        /// Cỡ file của bản ấy, để bảng duyệt nói được "bản này to bao nhiêu".
        public let byteCount: Int?

        public init(url: URL, date: Date?, byteCount: Int?) {
            self.url = url
            self.date = date
            self.byteCount = byteCount
        }
    }

    /// Trần cỡ file được ghi bản mới mỗi lần lưu.
    ///
    /// **Có trần vì ghi một bản là CHÉP CẢ FILE vào kho phiên bản của hệ điều hành.** Với một
    /// file log 2 GB thì mỗi lần ⌘S là hai gigabyte đi vào đĩa, và người dùng không hề yêu cầu
    /// điều đó — họ chỉ bấm lưu. Thà không có lịch sử cho file khổng lồ còn hơn biến ⌘S thành
    /// thao tác chờ hàng chục giây và ăn hết đĩa.
    ///
    /// 64 MB: rộng hơn mọi file mã nguồn và cấu hình, hẹp hơn hẳn loại file mà sản phẩm này tự
    /// hào mở được (hàng GB). Đúng ranh giới giữa "tài liệu người ta sửa" và "dữ liệu người ta
    /// xem".
    public static let versioningLimit = 64 << 20

    /// Ghi lại bản HIỆN TẠI trên đĩa trước khi nó bị đè.
    ///
    /// Gọi NGAY TRƯỚC khi ghi đè, không phải sau: kho phiên bản giữ nội dung của file tại thời
    /// điểm gọi, nên gọi sau thì bản được giữ chính là bản vừa ghi — một lịch sử toàn bản mới,
    /// không có bản cũ nào.
    ///
    /// Trả `false` khi bỏ qua (file quá lớn, chưa tồn tại, hoặc hệ thống từ chối). Bỏ qua KHÔNG
    /// phải lỗi: lưu file vẫn phải thành công dù lịch sử không ghi được. Lịch sử là tiện nghi,
    /// nội dung mới là thứ người dùng đang giữ trong tay.
    @discardableResult
    public static func recordVersion(of path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int, size <= versioningLimit
        else { return false }
        return (try? NSFileVersion.addOfItem(at: url, withContentsOf: url)) != nil
    }

    /// Các bản đã lưu trước đó, MỚI NHẤT trước.
    ///
    /// Sắp theo ngày chứ không theo thứ tự hệ thống trả về: người dùng đọc lịch sử từ gần tới
    /// xa, và một danh sách không sắp thì mỗi lần mở lại một thứ tự.
    public static func versions(of path: String) -> [Version] {
        let url = URL(fileURLWithPath: path)
        let all = NSFileVersion.otherVersionsOfItem(at: url) ?? []
        return all
            .map { version in
                Version(
                    url: version.url,
                    date: version.modificationDate,
                    byteCount: (try? FileManager.default
                        .attributesOfItem(atPath: version.url.path))?[.size] as? Int
                )
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Nội dung của một bản cũ, dưới dạng byte.
    ///
    /// Trả BYTE chứ không trả `String`: bảng mã của file là chuyện của tầng trên, và giải mã
    /// sớm ở đây sẽ làm hỏng đúng những file mà sản phẩm này sinh ra để cứu — file TCVN3, file
    /// UTF-8 có byte hỏng.
    public static func contents(of version: Version) -> [UInt8]? {
        (try? Data(contentsOf: version.url)).map { Array($0) }
    }
}
