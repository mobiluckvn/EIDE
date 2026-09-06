import Foundation

/// Kiểm XML theo DTD và theo XSD — FR-FMT-505 (PoC-I, 25/08/2026).
///
/// ## Không vendor một byte nào, và đó là kết quả ĐO chứ không phải phỏng đoán
///
/// `docs/trang-thai.md` §4bis từng khoá mục này với lý do "cần vendor libxml2 — kích thước
/// bundle, ADR-08, đường ký". `scripts/run-poc-i.sh` đo lại và cả ba lý do đều không còn:
///
/// - **DTD** đi qua `Foundation.XMLDocument` với `.documentValidate`. Không thêm phụ thuộc nào,
///   và thông báo lỗi có sẵn số dòng.
/// - **XSD** đi qua libxml2 **HỆ THỐNG** (`/usr/lib/libxml2.2.dylib`), nạp lười bằng `dlopen`.
///   Nó đã nằm trong dyld shared cache nên `dlopen` tốn **0,07 ms** — ADR-08 không đụng tới.
/// - Hardened runtime **không chặn**, khác hẳn dylib bên thứ ba của ADR-12: đây là thư viện
///   Apple ký. Đã đo cả trong bundle sandbox đã ký.
///
/// ## Vì sao `dlopen` chứ không liên kết thẳng
///
/// Hai lý do, và lý do thứ hai mới là lý do chính:
///
/// 1. Khởi động không phải trả gì cho một tính năng phần lớn người dùng không bấm tới.
/// 2. **Hỏng MỀM.** Ngày Apple bỏ libxml2 khỏi hệ thống, tính năng này nói "máy này không có"
///    và app chạy tiếp bình thường. Liên kết cứng thì thiếu thư viện là app KHÔNG KHỞI ĐỘNG
///    NỔI — một tính năng phụ kéo cả sản phẩm xuống.
///
/// Và nó giữ cho quyết định ĐẢO NGƯỢC ĐƯỢC: đổi sang libxml2 vendor về sau chỉ là đổi đường
/// dẫn trong `libraryCandidates`, không chạm một dòng nào ở chỗ gọi.
public enum XMLSchemaValidator {

    /// Một lỗi kiểm, đã quy về dạng chung cho cả hai đường.
    public struct Issue: Equatable, Sendable {
        public let message: String
        /// Dòng 1-based, `nil` khi thư viện không nói.
        public let line: Int?

        public init(message: String, line: Int? = nil) {
            self.message = message
            self.line = line
        }

        public var describedForUser: String {
            line.map { "Dòng \($0): \(message)" } ?? message
        }
    }

    public enum Outcome: Equatable, Sendable {
        case valid
        case invalid([Issue])
        /// Không kiểm được — và **nói rõ vì sao**, vì "không kiểm được" với "hợp lệ" là hai
        /// câu trả lời khác hẳn nhau mà người dùng rất dễ đọc lẫn.
        case unavailable(String)
    }

    // MARK: - DTD (Foundation, không phụ thuộc gì thêm)

    /// Kiểm theo DTD **nội tuyến trong chính tài liệu** (`<!DOCTYPE … [ … ]>`).
    ///
    /// Chỉ nhận DTD nội tuyến, cố ý: một `<!DOCTYPE … SYSTEM "http://…">` sẽ khiến trình phân
    /// tích đi TẢI file ấy về. Đó là một lời gọi mạng do NỘI DUNG FILE quyết định — đúng loại
    /// cửa mà XXE khai thác — và một trình soạn thảo mở file của người lạ thì không được mở cửa
    /// ấy. Ai cần DTD ngoài thì trỏ nó bằng tham số `schema`, tức là một quyết định của NGƯỜI
    /// DÙNG chứ không của file.
    public static func validateAgainstInlineDTD(_ xml: String) -> Outcome {
        do {
            let document = try XMLDocument(
                xmlString: xml, options: [.documentValidate, .nodeLoadExternalEntitiesNever])
            try document.validate()
            return .valid
        } catch {
            return .invalid(parseFoundationErrors(error))
        }
    }

    /// Tách thông báo nhiều dòng của Foundation thành từng lỗi, giữ số dòng.
    ///
    /// Foundation gộp mọi lỗi vào một chuỗi, mỗi lỗi một dòng, dạng `Line 8: …`. Đọc số dòng ra
    /// chứ không để nguyên câu: chỗ hiện lỗi nhảy được tới dòng ấy, và một danh sách lỗi có số
    /// dòng thì bấm được.
    private static func parseFoundationErrors(_ error: Error) -> [Issue] {
        let text = (error as NSError).localizedDescription
        let issues = text.split(separator: "\n").map { raw -> Issue in
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("Line "),
                  let colon = line.firstIndex(of: ":"),
                  let number = Int(line[line.index(line.startIndex, offsetBy: 5) ..< colon])
            else { return Issue(message: line) }
            let message = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return Issue(message: message, line: number)
        }
        return issues.isEmpty ? [Issue(message: text)] : issues
    }

    // MARK: - XSD (libxml2 hệ thống, nạp lười)

    /// Những chỗ libxml2 có thể nằm, theo thứ tự.
    ///
    /// **Đây là chỗ DUY NHẤT phải sửa** nếu một ngày chuyển sang libxml2 vendor: thêm đường dẫn
    /// trong bundle lên đầu danh sách. Không chỗ gọi nào biết sự khác nhau.
    public static var libraryCandidates: [String] = [
        "/usr/lib/libxml2.2.dylib",
        "/usr/lib/libxml2.dylib",
        "libxml2.2.dylib",
    ]

    public static func validate(_ xml: String, againstXSD schema: String) -> Outcome {
        guard let library = LibXML2.shared else {
            return .unavailable(
                "Máy này không có libxml2 nên không kiểm được XSD. "
                    + "Phần kiểm well-formed và DTD vẫn dùng được.")
        }
        return library.validate(xml: xml, schema: schema)
    }

    /// Có kiểm được XSD trên máy này không — để giao diện nói TRƯỚC thay vì báo lỗi SAU.
    public static var isXSDAvailable: Bool { LibXML2.shared != nil }

    /// Phiên bản libxml2 đang dùng, nếu hỏi được.
    ///
    /// Hiện nó ra cho người dùng, vì đây là thư viện của HỆ THỐNG: hai máy hai bản macOS có thể
    /// cho verdict khác nhau ở những góc hiếm của XSD, và khi ấy con số này là thứ đầu tiên cần
    /// so.
    public static var libraryVersion: String? { LibXML2.shared?.version }
}
