import CryptoKit
import Foundation
import Security

/// Chuỗi cung ứng plugin — NFR-SEC-03.
///
/// Chỉ tiêu viết: *"Plugin trong danh mục chính thức phải ký số và khớp hash SHA-256; plugin
/// ngoài danh mục yêu cầu xác nhận rủi ro tường minh."*
///
/// Vế "cài từ đâu / gỡ thế nào" đã xong từ ADR-12 (danh sách suy từ đĩa, cài là chép file, gỡ
/// là xoá file). Đây là vế còn lại, và nó là vế nặng hơn: **plugin native là mã của người khác
/// chạy trong một tiến trình trên máy người dùng**, không sandbox, với quyền của người dùng ấy.
///
/// ## Chưa có danh mục chính thức — nên luật viết lại thế này
///
/// MOBILUCK chưa có danh mục plugin, nên "ký số bởi danh mục" chưa kiểm được với ai. Thứ kiểm
/// được ngay, và thật ra là thứ bảo vệ nhiều hơn:
///
/// 1. **Chưa duyệt bao giờ** → hỏi người dùng, và hỏi kèm dữ kiện thật: đường dẫn, SHA-256, và
///    plugin có chữ ký hay không. Đồng ý thì ghi lại hash ấy.
/// 2. **Hash khớp bản đã duyệt** → chạy, không hỏi lại. Hỏi mỗi lần chạy là cách chắc chắn
///    khiến người dùng bấm Đồng ý theo phản xạ, và khi ấy câu hỏi không còn bảo vệ gì.
/// 3. **Hash ĐÃ ĐỔI so với bản đã duyệt** → **từ chối**, không hỏi.
///
/// Trường hợp 3 là lý do chính để cả tệp này tồn tại. Một plugin được duyệt hôm nay rồi bị thay
/// nội dung ngày mai — bởi bản cập nhật của tác giả, bởi một script, hay bởi thứ gì khác — là
/// đúng hình dạng của một cuộc tấn công chuỗi cung ứng. Người dùng đã nói "tôi tin file này",
/// họ chưa nói "tôi tin mọi file sẽ nằm ở chỗ này về sau". Hỏi lại ở đây thì cũng là hỏi một
/// câu mà họ không có cách nào trả lời đúng; từ chối và nói rõ thì họ đi kiểm.
///
/// ## Sổ duyệt là một tệp JSON đọc được bằng mắt
///
/// Cùng luật ADR-09 với `settings.json`, theme và macro. Người dùng phải xoá được một dòng
/// trong đó bằng tay khi họ muốn duyệt lại — và phải ĐỌC được nó để biết mình đã duyệt cái gì.
public enum PluginTrust {

    /// Phán quyết cho một file plugin.
    public enum Verdict: Equatable, Sendable {
        /// Hash khớp bản người dùng đã duyệt.
        case trusted
        /// Chưa từng duyệt. Phải hỏi trước khi chạy.
        case unknown(sha256: String)
        /// Đã duyệt, nhưng nội dung file nay KHÁC. Từ chối.
        case changed(approved: String, now: String)
    }

    public enum Failure: Error, Equatable, Sendable {
        case unreadable(String)

        public var message: String {
            switch self {
            case .unreadable(let path):
                return "Không đọc được file plugin: \(path)"
            }
        }
    }

    // MARK: - Hash

    /// SHA-256 của một file, đọc theo lô.
    ///
    /// Theo lô chứ không `Data(contentsOf:)`: một plugin không có lý do gì để lớn, nhưng hàm
    /// này nhận đường dẫn từ bên ngoài và "không có lý do gì" không phải một hàng rào. Đọc cả
    /// file vào RAM để băm nó là cách biến một file 4 GB thành một cú treo máy.
    public static func sha256(ofFileAt path: String) throws -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw Failure.unreadable(path)
        }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1 << 20)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Chữ ký

    /// Ai đã ký file này — `nil` khi nó không có chữ ký nào.
    ///
    /// **Chỉ để HIỆN RA, không để quyết định.** Quyết định nằm ở hash, và lý do là chữ ký trả
    /// lời một câu hỏi khác: "ai làm ra nó", chứ không phải "nó có đổi kể từ lần tôi duyệt
    /// không". Một plugin ký hợp lệ vẫn có thể được thay bằng một plugin ký hợp lệ khác của
    /// cùng tác giả — hash bắt được chuyện ấy, chữ ký thì không.
    ///
    /// Nhưng chữ ký là dữ kiện DUY NHẤT nói được nguồn gốc, nên nó phải nằm trong câu hỏi lúc
    /// duyệt: "chưa ký" và "ký bởi MOBILUCK" là hai câu trả lời rất khác nhau cho cùng một
    /// SHA-256 mà người dùng không có cách nào tự tra.
    public static func signer(ofFileAt path: String) -> String? {
        var staticCode: SecStaticCode?
        let url = URL(fileURLWithPath: path) as CFURL
        guard SecStaticCodeCreateWithPath(url, [], &staticCode) == errSecSuccess,
              let code = staticCode
        else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &info) == errSecSuccess,
              let dictionary = info as? [String: Any]
        else { return nil }

        // Danh tính người ký, nếu có chuỗi chứng chỉ. Ký AD-HOC thì không có chuỗi ấy — và đó
        // là thông tin đáng nói ra, không phải một khoảng trống.
        if let certificates = dictionary[kSecCodeInfoCertificates as String] as? [SecCertificate],
           let leaf = certificates.first {
            var common: CFString?
            if SecCertificateCopyCommonName(leaf, &common) == errSecSuccess,
               let name = common as String? {
                return name
            }
        }
        if dictionary[kSecCodeInfoIdentifier as String] != nil {
            return "ký ad-hoc (không có chứng chỉ)"
        }
        return nil
    }

    // MARK: - Sổ duyệt

    /// Một mục đã duyệt.
    public struct Approval: Codable, Equatable, Sendable {
        /// Tên file trong thư mục plugin. Không lưu đường dẫn tuyệt đối: nó chứa tên người dùng
        /// và đổi theo máy, nên một sổ chép sang máy khác sẽ không khớp một dòng nào.
        public var fileName: String
        public var sha256: String
        /// Ngày duyệt, dạng ISO 8601 — để người đọc sổ biết mình duyệt cái này khi nào.
        public var approvedAt: String
        /// Chữ ký (nếu có) tại thời điểm duyệt. Chỉ để GHI LẠI, không dùng để quyết định —
        /// quyết định nằm ở hash.
        public var signedBy: String?

        public init(fileName: String, sha256: String, approvedAt: String, signedBy: String?) {
            self.fileName = fileName
            self.sha256 = sha256
            self.approvedAt = approvedAt
            self.signedBy = signedBy
        }
    }

    /// Sổ duyệt — đọc và ghi một tệp JSON.
    public struct Store: Codable, Equatable, Sendable {
        public var schemaVersion: Int
        public var approvals: [Approval]

        public static let currentSchemaVersion = 1

        public init(schemaVersion: Int = Store.currentSchemaVersion, approvals: [Approval] = []) {
            self.schemaVersion = schemaVersion
            self.approvals = approvals
        }

        /// Đọc sổ. Không có tệp = sổ rỗng, KHÔNG phải lỗi — người chưa duyệt plugin nào là
        /// trạng thái bình thường nhất.
        ///
        /// Tệp của bản MỚI HƠN thì từ chối và không ghi đè, đúng luật `Settings` đã đặt: ghi đè
        /// là xoá sạch quyết định của người dùng trên một máy khác.
        public static func load(from url: URL) throws -> Store {
            guard let data = try? Data(contentsOf: url) else { return Store() }
            let decoded = try JSONDecoder().decode(Store.self, from: data)
            guard decoded.schemaVersion <= Store.currentSchemaVersion else {
                throw Failure.unreadable(
                    "sổ duyệt plugin thuộc bản GEditor mới hơn (schema \(decoded.schemaVersion))")
            }
            return decoded
        }

        public func save(to url: URL) throws {
            let encoder = JSONEncoder()
            // Đọc được bằng mắt và diff được — người dùng phải xoá được một dòng bằng tay.
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(self).write(to: url, options: .atomic)
        }

        public func approval(for fileName: String) -> Approval? {
            approvals.first { $0.fileName == fileName }
        }

        public mutating func approve(_ approval: Approval) {
            approvals.removeAll { $0.fileName == approval.fileName }
            approvals.append(approval)
            approvals.sort { $0.fileName < $1.fileName }
        }

        public mutating func forget(fileName: String) {
            approvals.removeAll { $0.fileName == fileName }
        }
    }

    // MARK: - Phán quyết

    public static func verdict(forFileAt path: String, in store: Store) throws -> Verdict {
        let fileName = (path as NSString).lastPathComponent
        let now = try sha256(ofFileAt: path)
        guard let approval = store.approval(for: fileName) else {
            return .unknown(sha256: now)
        }
        return approval.sha256 == now
            ? .trusted
            : .changed(approved: approval.sha256, now: now)
    }

    /// Câu nói với người dùng cho từng phán quyết.
    ///
    /// Ở lõi chứ không ở tầng giao diện, vì đây là nội dung của một quyết định an ninh — nó
    /// phải kiểm được bằng test, và phải giống nhau ở mọi chỗ hỏi.
    public static func explanation(_ verdict: Verdict, fileName: String) -> String {
        switch verdict {
        case .trusted:
            return "Đã duyệt trước đó và nội dung không đổi."
        case .unknown(let sha):
            return """
                «\(fileName)» là mã của người khác, chạy với quyền của anh và KHÔNG bị giới hạn \
                như script. GEditor chưa từng chạy file này.
                SHA-256: \(sha)
                Chỉ đồng ý nếu anh biết file này từ đâu ra.
                """
        case .changed(let approved, let now):
            return """
                «\(fileName)» ĐÃ ĐỔI NỘI DUNG kể từ lần anh duyệt. GEditor từ chối chạy nó.
                Đã duyệt: \(approved)
                Bây giờ:  \(now)
                Nếu chính anh vừa cập nhật plugin thì gỡ nó khỏi sổ duyệt rồi chạy lại để duyệt \
                lần nữa. Nếu không, đừng chạy — hãy tìm hiểu vì sao file đổi.
                """
        }
    }
}
