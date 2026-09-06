import Foundation

/// Bảng mã GEditor đọc và ghi được (FR-ENC-201).
public enum TextEncoding: String, CaseIterable, Sendable {
    case utf8
    case utf8BOM
    case utf16LE
    case utf16BE
    case utf32LE
    case utf32BE
    case windows1258
    case viscii
    case tcvn3
    case vni

    // Bảng mã do HỆ ĐIỀU HÀNH chuyển đổi (FR-ENC-201).
    //
    // Không tự dựng bảng cho nhóm này. Bảng CP932/GB18030/Big5 là hàng nghìn tới hàng chục
    // nghìn ô, macOS đã có bộ chuyển đổi được bảo trì và kiểm chứng cho tất cả, và một bảng
    // tự gõ sai một ô là hỏng dữ liệu người dùng mà không ai biết. Chỉ ba bảng mã Việt legacy
    // ở trên mới phải tự dựng, vì hệ thống KHÔNG có.
    case windows1250, windows1251, windows1252, windows1253, windows1254
    case windows1255, windows1256, windows1257
    case isoLatin1, isoLatin2, isoLatin3, isoLatin4, isoCyrillic, isoArabic
    case isoGreek, isoHebrew, isoLatin5, isoLatin6, isoThai, isoLatin7
    case isoLatin8, isoLatin9, isoLatin10
    case shiftJIS, gb18030, eucKR, big5

    public var displayName: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf8BOM: return "UTF-8 BOM"
        case .utf16LE: return "UTF-16 LE"
        case .utf16BE: return "UTF-16 BE"
        case .utf32LE: return "UTF-32 LE"
        case .utf32BE: return "UTF-32 BE"
        case .windows1258: return "Windows-1258"
        case .viscii: return "VISCII"
        case .tcvn3: return "TCVN3 (ABC)"
        case .vni: return "VNI-Windows"
        default: return ianaName ?? rawValue
        }
    }

    /// Tên IANA của bảng mã do hệ thống chuyển đổi.
    ///
    /// Tra theo TÊN chứ không theo hằng số `kCFStringEncoding…`: tên IANA là thứ đứng trong
    /// chuẩn và trong header HTTP, còn hằng số thì phải nhớ đúng và không kiểm chứng được khi
    /// đọc mã. Tra sai tên sẽ lộ ra ngay ở `foundationEncoding` trả `nil`.
    public var ianaName: String? {
        switch self {
        case .windows1250: return "windows-1250"
        case .windows1251: return "windows-1251"
        case .windows1252: return "windows-1252"
        case .windows1253: return "windows-1253"
        case .windows1254: return "windows-1254"
        case .windows1255: return "windows-1255"
        case .windows1256: return "windows-1256"
        case .windows1257: return "windows-1257"
        case .isoLatin1: return "ISO-8859-1"
        case .isoLatin2: return "ISO-8859-2"
        case .isoLatin3: return "ISO-8859-3"
        case .isoLatin4: return "ISO-8859-4"
        case .isoCyrillic: return "ISO-8859-5"
        case .isoArabic: return "ISO-8859-6"
        case .isoGreek: return "ISO-8859-7"
        case .isoHebrew: return "ISO-8859-8"
        case .isoLatin5: return "ISO-8859-9"
        case .isoLatin6: return "ISO-8859-10"
        case .isoThai: return "ISO-8859-11"
        case .isoLatin7: return "ISO-8859-13"
        case .isoLatin8: return "ISO-8859-14"
        case .isoLatin9: return "ISO-8859-15"
        case .isoLatin10: return "ISO-8859-16"
        case .shiftJIS: return "Shift_JIS"
        case .gb18030: return "GB18030"
        case .eucKR: return "EUC-KR"
        case .big5: return "Big5"
        default: return nil
        }
    }

    /// Bảng mã hệ thống có thật sự dùng được trên máy đang chạy hay không.
    ///
    /// macOS có thể bỏ một bảng mã ở phiên bản sau. Hỏi hệ thống thay vì tin là có, và menu
    /// chỉ hiện những gì hỏi ra được — thà thiếu một mục còn hơn hiện một mục bấm vào không
    /// làm gì.
    public var isAvailable: Bool {
        ianaName == nil || foundationEncoding != nil
    }

    /// Nhóm bảng mã, để menu không thành một danh sách phẳng 36 dòng.
    ///
    /// Thuộc về LÕI chứ không thuộc về menu: "bảng mã này thuộc họ nào" là tính chất của bảng
    /// mã, không phải của giao diện. Đặt ở đây thì CLI, báo cáo và menu cùng nhóm giống nhau.
    public enum Family: String, CaseIterable, Sendable {
        case unicode, vietnamese, windows, iso8859, cjk

        public var displayName: String {
            switch self {
            case .unicode: return "Unicode"
            case .vietnamese: return "Tiếng Việt"
            case .windows: return "Windows"
            case .iso8859: return "ISO 8859"
            case .cjk: return "Trung · Nhật · Hàn"
            }
        }

        /// Hai nhóm đầu hiện thẳng trong menu; phần còn lại vào menu con.
        ///
        /// Người dùng của GEditor mở file Unicode và file Việt legacy hằng ngày, còn Big5 thì
        /// vài năm một lần. Bắt họ đi qua một menu con cho việc thường làm là sai thứ tự.
        public var isPrimary: Bool { self == .unicode || self == .vietnamese }
    }

    public var family: Family {
        switch self {
        case .utf8, .utf8BOM, .utf16LE, .utf16BE, .utf32LE, .utf32BE: return .unicode
        case .windows1258, .viscii, .tcvn3, .vni: return .vietnamese
        case .shiftJIS, .gb18030, .eucKR, .big5: return .cjk
        default: return ianaName?.hasPrefix("ISO") == true ? .iso8859 : .windows
        }
    }

    /// Bảng mã tiếng Việt cũ — thứ FR-ENC-201 gọi là "Việt legacy".
    public var isVietnameseLegacy: Bool {
        switch self {
        case .windows1258, .viscii, .tcvn3, .vni: return true
        default: return false
        }
    }

    /// Codec một byte tương ứng; `nil` với các bảng mã Unicode.
    public var singleByteCodec: SingleByteCodec? {
        switch self {
        case .windows1258: return .windows1258
        case .viscii: return .viscii
        case .tcvn3: return .tcvn3
        default: return nil
        }
    }

    /// BOM phải ghi ở đầu file khi lưu bằng bảng mã này.
    public var byteOrderMark: [UInt8] {
        switch self {
        case .utf8BOM: return [0xEF, 0xBB, 0xBF]
        case .utf16LE: return [0xFF, 0xFE]
        case .utf16BE: return [0xFE, 0xFF]
        case .utf32LE: return [0xFF, 0xFE, 0x00, 0x00]
        case .utf32BE: return [0x00, 0x00, 0xFE, 0xFF]
        default: return []
        }
    }

    var foundationEncoding: String.Encoding? {
        switch self {
        case .utf8, .utf8BOM: return .utf8
        case .utf16LE: return .utf16LittleEndian
        case .utf16BE: return .utf16BigEndian
        case .utf32LE: return .utf32LittleEndian
        case .utf32BE: return .utf32BigEndian
        default: break
        }
        guard let iana = ianaName else { return nil }
        let cf = CFStringConvertIANACharSetNameToEncoding(iana as CFString)
        guard cf != kCFStringEncodingInvalidId else { return nil }
        let raw = CFStringConvertEncodingToNSStringEncoding(cf)
        guard raw != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: raw)
    }
}

/// Chuyển đổi giữa byte trên đĩa và biểu diễn trong bộ nhớ.
///
/// **Biểu diễn trong bộ nhớ của GEditor luôn là UTF-8.** Mọi thứ khác chỉ tồn tại ở hai đầu:
/// lúc đọc file và lúc ghi file. Nhờ vậy piece table, chỉ mục dòng, engine regex và parser CSV
/// chỉ phải biết một bảng mã duy nhất.
public enum EncodingConverter {

    public enum Failure: Error, CustomStringConvertible {
        case cannotDecode(TextEncoding)

        public var description: String {
            switch self {
            case .cannotDecode(let encoding):
                return "Không giải mã được nội dung theo \(encoding.displayName)"
            }
        }
    }

    /// Byte của file → UTF-8. BOM bị cắt bỏ nếu có.
    public static func decode(_ bytes: [UInt8], from encoding: TextEncoding) throws -> [UInt8] {
        let body = stripBOM(bytes, for: encoding)

        if encoding == .vni {
            return VNICodec.decode(body)
        }
        if let codec = encoding.singleByteCodec {
            return codec.decode(body)
        }
        if encoding == .utf8 || encoding == .utf8BOM {
            return body
        }
        // UTF-16/32 phải đi qua `String`: chúng không phải bảng mã một byte nên không có
        // đường tra bảng, và file dạng này trong thực tế nhỏ hơn nhiều. Nếu sau này cần mở
        // UTF-16 hàng GB thì phải viết bộ giải mã theo khối riêng.
        guard let foundation = encoding.foundationEncoding,
              let text = String(bytes: body, encoding: foundation)
        else { throw Failure.cannotDecode(encoding) }
        return Array(text.utf8)
    }

    /// UTF-8 → byte của file, kèm BOM nếu bảng mã đòi.
    ///
    /// KHÔNG ném lỗi khi mất ký tự: trả về số ký tự không biểu diễn được để lớp trên hỏi lại
    /// người dùng. Ném lỗi ở đây sẽ đẩy lập trình viên phía trên vào chỗ nuốt lỗi cho xong.
    public static func encode(
        _ utf8: [UInt8], to encoding: TextEncoding
    ) -> SingleByteCodec.EncodeResult {
        var out = encoding.byteOrderMark

        if encoding == .vni {
            let result = VNICodec.encode(utf8)
            out.append(contentsOf: result.bytes)
            return SingleByteCodec.EncodeResult(
                bytes: out,
                unrepresentable: result.unrepresentable,
                firstUnrepresentable: result.firstUnrepresentable
            )
        }

        if let codec = encoding.singleByteCodec {
            let result = codec.encode(utf8)
            out.append(contentsOf: result.bytes)
            return SingleByteCodec.EncodeResult(
                bytes: out,
                unrepresentable: result.unrepresentable,
                firstUnrepresentable: result.firstUnrepresentable
            )
        }

        if encoding == .utf8 || encoding == .utf8BOM {
            out.append(contentsOf: utf8)
            return SingleByteCodec.EncodeResult(bytes: out, unrepresentable: 0, firstUnrepresentable: nil)
        }

        let text = String(decoding: utf8, as: UTF8.self)
        guard let foundation = encoding.foundationEncoding else {
            return SingleByteCodec.EncodeResult(bytes: out, unrepresentable: 0, firstUnrepresentable: nil)
        }

        // Đường nhanh: chuyển được trọn vẹn thì không phải đếm gì.
        if let data = text.data(using: foundation, allowLossyConversion: false) {
            out.append(contentsOf: data)
            return SingleByteCodec.EncodeResult(bytes: out, unrepresentable: 0, firstUnrepresentable: nil)
        }

        // Có ký tự không biểu diễn được. Phải ĐẾM và chỉ ra ký tự đầu tiên, vì lớp trên dựa
        // vào con số này để hỏi lại người dùng trước khi lưu (FR-ENC-203).
        //
        // Bản trước ở đây trả `unrepresentable: 0` kể cả khi `data(using:)` trả nil — tức là
        // chuyển đổi hỏng hoàn toàn mà vẫn báo "không mất gì", và người dùng lưu ra file RỖNG
        // sau một hộp thoại nói mọi thứ ổn.
        var lost = 0
        var firstLost: UInt32?
        for character in text {
            if let data = String(character).data(using: foundation, allowLossyConversion: false) {
                out.append(contentsOf: data)
            } else {
                lost += 1
                if firstLost == nil { firstLost = character.unicodeScalars.first?.value }
                // Ký tự thay thế, giống hành vi của codec một byte.
                if let fallback = "?".data(using: foundation) { out.append(contentsOf: fallback) }
            }
        }
        return SingleByteCodec.EncodeResult(
            bytes: out, unrepresentable: lost, firstUnrepresentable: firstLost
        )
    }

    static func stripBOM(_ bytes: [UInt8], for encoding: TextEncoding) -> [UInt8] {
        let mark = encoding.byteOrderMark
        guard !mark.isEmpty, bytes.count >= mark.count,
              Array(bytes.prefix(mark.count)) == mark
        else { return bytes }
        return Array(bytes.dropFirst(mark.count))
    }
}

// MARK: - FR-ENC-203: "Diễn giải lại" khác "Chuyển đổi sang"

/// Hai thao tác đổi bảng mã, và chúng làm hai việc NGƯỢC NHAU.
///
/// Đây là chỗ dễ mất dữ liệu nhất trong cả sản phẩm, nên hai thao tác được tách thành hai
/// kiểu riêng chứ không phải hai giá trị của một tham số — lẫn chúng phải là lỗi biên dịch,
/// không phải lỗi lúc chạy trên máy người dùng.
///
/// | | Diễn giải lại | Chuyển đổi sang |
/// |---|---|---|
/// | Ý định của người dùng | "Mở ra bị sai chữ, chắc file này là TCVN3" | "Chữ đúng rồi, giờ lưu thành UTF-8" |
/// | Byte trên đĩa | không đổi (đến khi lưu) | sẽ đổi khi lưu |
/// | Chữ trên màn hình | ĐỔI | không đổi |
/// | Rủi ro | không có, đảo lại được | mất ký tự ngoài kho bảng mã đích |
///
/// Menu trên status bar phải hiện chúng thành HAI NHÓM TÁCH BẠCH (FR-UI-805).
public enum EncodingChange {

    /// Đọc lại byte GỐC bằng một bảng mã khác.
    ///
    /// Cần byte gốc chứ không phải nội dung đang hiển thị — đó là toàn bộ ý nghĩa của thao
    /// tác. Với piece table trên mmap thì byte gốc luôn còn (file gốc không bao giờ bị sửa),
    /// nên đây là thao tác rẻ và đảo lại được.
    public struct Reinterpretation {
        public let utf8: [UInt8]
        public let encoding: TextEncoding
    }

    /// - Parameter originalBytes: nội dung NGUYÊN VẸN của file như đọc từ đĩa.
    public static func reinterpret(
        originalBytes: [UInt8], as encoding: TextEncoding
    ) throws -> Reinterpretation {
        Reinterpretation(utf8: try EncodingConverter.decode(originalBytes, from: encoding), encoding: encoding)
    }

    /// Kết quả xem trước của việc chuyển đổi — dùng để hỏi người dùng TRƯỚC khi ghi.
    public struct ConversionPreview {
        public let encoding: TextEncoding
        public let bytes: [UInt8]
        /// Số ký tự không biểu diễn được trong bảng mã đích.
        public let unrepresentable: Int
        public let firstUnrepresentable: UInt32?

        /// Chuyển đổi này có mất dữ liệu không.
        public var isLossy: Bool { unrepresentable > 0 }

        /// Câu cảnh báo dựng sẵn cho hộp thoại xác nhận.
        public var warning: String? {
            guard isLossy else { return nil }
            let sample = firstUnrepresentable
                .flatMap { Unicode.Scalar($0) }
                .map { " (ví dụ \"\(Character($0))\")" } ?? ""
            return "\(unrepresentable) ký tự không có trong \(encoding.displayName)\(sample) "
                + "sẽ bị thay bằng dấu ?. Thao tác này KHÔNG hoàn tác được sau khi lưu."
        }
    }

    /// Giữ nguyên văn bản, dựng byte cho bảng mã đích.
    ///
    /// Luôn trả về bản xem trước chứ không tự ghi: người dùng phải thấy con số "mất bao nhiêu
    /// ký tự" trước khi đồng ý.
    public static func convert(utf8: [UInt8], to encoding: TextEncoding) -> ConversionPreview {
        let result = EncodingConverter.encode(utf8, to: encoding)
        return ConversionPreview(
            encoding: encoding,
            bytes: result.bytes,
            unrepresentable: result.unrepresentable,
            firstUnrepresentable: result.firstUnrepresentable
        )
    }
}
