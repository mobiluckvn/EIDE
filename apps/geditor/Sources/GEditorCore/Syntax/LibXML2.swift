import Darwin
import Foundation

/// Lớp bọc HẸP quanh libxml2 của hệ thống — chỗ duy nhất trong sản phẩm chạm vào nó.
///
/// Xem `XMLSchemaValidator` để biết vì sao là thư viện hệ thống và vì sao nạp lười.
///
/// ## Vì sao gọi qua con trỏ hàm chứ không `import` một module
///
/// `import` bắt liên kết lúc dựng, và khi ấy thiếu thư viện là app không khởi động nổi. Ở đây
/// mọi lời gọi đi qua `dlsym`, nên "không có libxml2" là một giá trị (`nil`) chứ không phải
/// một tai nạn.
///
/// Cái giá: mất phần kiểm kiểu của trình biên dịch. Bù lại bằng cách **giữ bề mặt cực hẹp** —
/// đúng chín hàm, tất cả nằm trong tệp này, và mỗi chữ ký được viết ngay cạnh chỗ dùng.
final class LibXML2 {

    /// `nil` khi máy không có libxml2. Tính MỘT lần: `dlopen` rẻ (0,07 ms, đo ở PoC-I) nhưng
    /// không có lý do làm lại, và một `static let` cũng bảo đảm chỉ có một handle.
    static let shared: LibXML2? = LibXML2()

    private let handle: UnsafeMutableRawPointer
    let version: String

    // MARK: - Chữ ký C

    private typealias NewMemParserCtxt = @convention(c) (UnsafePointer<CChar>?, Int32)
        -> UnsafeMutableRawPointer?
    private typealias SchemaParse = @convention(c) (UnsafeMutableRawPointer?)
        -> UnsafeMutableRawPointer?
    private typealias FreePointer = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias ReadMemory = @convention(c) (
        UnsafePointer<CChar>?, Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?, Int32
    ) -> UnsafeMutableRawPointer?
    private typealias NewValidCtxt = @convention(c) (UnsafeMutableRawPointer?)
        -> UnsafeMutableRawPointer?
    private typealias ValidateDoc = @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
    ) -> Int32
    private typealias SetStructuredErrors = @convention(c) (
        UnsafeMutableRawPointer?,
        (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void)?,
        UnsafeMutableRawPointer?
    ) -> Void

    private let newMemParserCtxt: NewMemParserCtxt
    private let schemaParse: SchemaParse
    private let freeParserCtxt: FreePointer
    private let schemaFree: FreePointer
    private let readMemory: ReadMemory
    private let newValidCtxt: NewValidCtxt
    private let validateDoc: ValidateDoc
    private let freeValidCtxt: FreePointer
    private let freeDoc: FreePointer
    private let setStructuredErrors: SetStructuredErrors?

    private init?() {
        var opened: UnsafeMutableRawPointer?
        for path in XMLSchemaValidator.libraryCandidates {
            if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) { opened = handle; break }
        }
        guard let handle = opened else { return nil }
        self.handle = handle

        func symbol<T>(_ name: String, _ type: T.Type) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: type) }
        }
        // Thiếu MỘT hàm là coi như không có thư viện. Nạp nửa vời rồi sập giữa chừng thì tệ hơn
        // hẳn so với nói "máy này không có" ngay từ đầu.
        guard let newMemParserCtxt = symbol("xmlSchemaNewMemParserCtxt", NewMemParserCtxt.self),
              let schemaParse = symbol("xmlSchemaParse", SchemaParse.self),
              let freeParserCtxt = symbol("xmlSchemaFreeParserCtxt", FreePointer.self),
              let schemaFree = symbol("xmlSchemaFree", FreePointer.self),
              let readMemory = symbol("xmlReadMemory", ReadMemory.self),
              let newValidCtxt = symbol("xmlSchemaNewValidCtxt", NewValidCtxt.self),
              let validateDoc = symbol("xmlSchemaValidateDoc", ValidateDoc.self),
              let freeValidCtxt = symbol("xmlSchemaFreeValidCtxt", FreePointer.self),
              let freeDoc = symbol("xmlFreeDoc", FreePointer.self)
        else {
            dlclose(handle)
            return nil
        }
        self.newMemParserCtxt = newMemParserCtxt
        self.schemaParse = schemaParse
        self.freeParserCtxt = freeParserCtxt
        self.schemaFree = schemaFree
        self.readMemory = readMemory
        self.newValidCtxt = newValidCtxt
        self.validateDoc = validateDoc
        self.freeValidCtxt = freeValidCtxt
        self.freeDoc = freeDoc
        // Không bắt buộc: thiếu nó thì mất phần CHI TIẾT lỗi, không mất phần verdict.
        self.setStructuredErrors = symbol(
            "xmlSchemaSetValidStructuredErrors", SetStructuredErrors.self)

        // `xmlParserVersion` là dạng SỐ ("20913"), không phải "2.9.13". Đổi ngay tại đây chứ
        // không để chỗ gọi tự đoán: con số này hiện ra cho người dùng, và "20913" thì không nói
        // với ai điều gì.
        if let raw = dlsym(handle, "xmlParserVersion")?
            .assumingMemoryBound(to: UnsafePointer<CChar>?.self).pointee,
           let packed = Int(String(cString: raw)), packed > 0 {
            version = "\(packed / 10000).\(packed / 100 % 100).\(packed % 100)"
        } else {
            version = "?"
        }
    }

    // MARK: - Kiểm

    /// Gom lỗi của lượt kiểm đang chạy.
    ///
    /// `static` vì hàm callback của C không mang được ngữ cảnh Swift qua `@convention(c)` một
    /// cách an toàn nếu ta muốn giữ chữ ký đơn giản. Có khoá vì `xmlSchemaValidateDoc` gọi
    /// callback ĐỒNG BỘ trên chính luồng gọi — nên một khoá quanh cả lượt kiểm là đủ, và nó
    /// cũng chính là thứ giữ cho hai lượt kiểm song song không trộn lỗi vào nhau.
    private static let lock = NSLock()
    private static var collected: [XMLSchemaValidator.Issue] = []

    func validate(xml: String, schema: String) -> XMLSchemaValidator.Outcome {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        Self.collected = []

        let schemaBytes = Array(schema.utf8CString)
        guard let parserCtxt = schemaBytes.withUnsafeBufferPointer({
            newMemParserCtxt($0.baseAddress, Int32(schema.utf8.count))
        }) else {
            return .unavailable("Không đọc được lược đồ XSD.")
        }
        guard let parsed = schemaParse(parserCtxt) else {
            freeParserCtxt(parserCtxt)
            // Lược đồ SAI là lỗi của người dùng, không phải "không kiểm được" — nói đúng tên nó.
            return .invalid([.init(message: "Lược đồ XSD không hợp lệ, không dùng để kiểm được.")])
        }
        freeParserCtxt(parserCtxt)
        defer { schemaFree(parsed) }

        let xmlBytes = Array(xml.utf8CString)
        guard let document = xmlBytes.withUnsafeBufferPointer({ buffer in
            "trong-bo-nho.xml".withCString { name in
                readMemory(buffer.baseAddress, Int32(xml.utf8.count), name, nil, 0)
            }
        }) else {
            return .invalid([.init(message: "Tài liệu XML không phân tích được.")])
        }
        defer { freeDoc(document) }

        guard let validCtxt = newValidCtxt(parsed) else {
            return .unavailable("Không dựng được ngữ cảnh kiểm XSD.")
        }
        defer { freeValidCtxt(validCtxt) }

        setStructuredErrors?(validCtxt, { _, raw in
            LibXML2.collected.append(LibXML2.issue(from: raw))
        }, nil)

        let code = validateDoc(validCtxt, document)
        if code == 0 { return .valid }
        if Self.collected.isEmpty {
            return .invalid([.init(message: "Tài liệu không khớp lược đồ XSD (mã \(code)).")])
        }
        return .invalid(Self.collected)
    }

    /// Đọc thông điệp và số dòng ra khỏi `xmlError` của libxml2.
    ///
    /// **Đây là chỗ mong manh nhất của cả tệp, và nó được viết để hỏng NHẸ.** `xmlError` là một
    /// struct C mà ta đọc bằng offset chứ không bằng header, nên một ngày libxml2 đổi bố cục
    /// thì những offset này trỏ sai. Nên: mọi trường đều được kiểm tỉnh táo trước khi tin, và
    /// khi nghi ngờ thì trả về một câu chung chung — mất chi tiết, KHÔNG mất verdict và không sập.
    ///
    /// Bố cục (ổn định suốt libxml2 2.x):
    ///     int domain; int code; char *message; int level; char *file; int line; …
    private static func issue(from raw: UnsafeMutableRawPointer?) -> XMLSchemaValidator.Issue {
        let fallback = XMLSchemaValidator.Issue(message: "Không khớp lược đồ XSD.")
        guard let raw else { return fallback }

        let messagePointer = raw.advanced(by: 8)
            .assumingMemoryBound(to: UnsafePointer<CChar>?.self).pointee
        guard let messagePointer else { return fallback }
        let message = String(cString: messagePointer)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, message.count < 4096 else { return fallback }

        // `line` nằm sau `file` (con trỏ 8 byte) ở offset 8+8+4(level)+4(đệm)+8 = 32.
        let line = raw.advanced(by: 32).assumingMemoryBound(to: Int32.self).pointee
        return XMLSchemaValidator.Issue(
            message: message, line: (line > 0 && line < 100_000_000) ? Int(line) : nil)
    }
}
