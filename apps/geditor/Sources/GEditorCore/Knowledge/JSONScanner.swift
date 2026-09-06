import Foundation

/// Đọc và kiểm tra JSON trên byte, KHÔNG dựng đối tượng — FR-KNW-901, FR-KNW-902.
///
/// ## Vì sao không dùng thẳng `JSONSerialization`
///
/// Ba việc mà cụm FR-KNW cần, và `JSONSerialization` làm được hai:
///
/// | Việc | `JSONSerialization` |
/// |---|---|
/// | Bản ghi này có hợp lệ không | được |
/// | HỎNG Ở ĐÂU và vì sao | trả `NSError` mô tả bằng tiếng Anh, vị trí không đáng tin |
/// | Trường mức trên cùng tên gì, kiểu gì | phải dựng cả `NSDictionary` rồi vứt đi |
///
/// Vế thứ hai là vế FR-KNW-901 đòi thẳng: *"danh sách record lỗi nhảy tới dòng"* — một danh
/// sách nói *"dòng 4.812: sai"* thì người dùng vẫn phải tự dò. Vế thứ ba là cách FR-KNW-902
/// nhận diện schema mà không phải dựng 700.000 `NSDictionary` để đọc tên khoá.
///
/// ## Ranh giới: bộ này PHẢI đồng ý với `JSONSerialization`
///
/// Một bộ kiểm tra viết tay mà rộng tay hơn bộ thật sẽ nói "hợp lệ" về bản ghi mà mọi công cụ
/// hạ nguồn từ chối; chặt tay hơn thì báo lỗi giả trên dữ liệu tốt. Cả hai đều tệ, và cái tệ
/// thứ nhất tệ hơn vì nó im lặng.
///
/// Nên có một bài kiểm đối chiếu: hàng trăm mẫu hợp lệ và không hợp lệ, hai bộ phải cho **cùng
/// một phán quyết**. Chỗ cố ý khác duy nhất là **độ sâu lồng nhau** — bộ này dừng ở
/// `maximumDepth` để không tràn ngăn xếp, và nói ra điều đó.
///
/// Luật áp dụng là RFC 8259 nghiêm ngặt: không dấu phẩy thừa, không chú thích, không `NaN`,
/// không số kiểu `.5` hay `01`, không ký tự điều khiển thô trong chuỗi.
public enum JSONScanner {

    /// Trần độ sâu lồng nhau. Vượt là báo lỗi chứ không đệ quy tiếp.
    ///
    /// Dữ liệu cào về có thể chứa một dòng `[[[[[…` dài vài MB — hoặc do lỗi sinh, hoặc do
    /// người khác cố ý. Đệ quy theo nó là cho một dòng văn bản quyền làm sập ứng dụng.
    public static let maximumDepth = 256

    public struct Failure: Equatable, Sendable {
        /// Vị trí byte TRONG dòng, 0-based.
        public var offset: Int
        public var message: String

        public init(offset: Int, message: String) {
            self.offset = offset
            self.message = message
        }
    }

    public enum Kind: String, Equatable, Sendable {
        case string, number, boolean, null, object, array

        public var vietnamese: String {
            switch self {
            case .string: return "chuỗi"
            case .number: return "số"
            case .boolean: return "luận lý"
            case .null: return "null"
            case .object: return "đối tượng"
            case .array: return "mảng"
            }
        }
    }

    public struct Field: Equatable, Sendable {
        public var name: String
        public var kind: Kind
        /// Dải byte của GIÁ TRỊ trong dòng — để tô sáng và để lấy chuỗi ra mà không phân tích lại.
        public var value: Range<Int>

        public init(name: String, kind: Kind, value: Range<Int>) {
            self.name = name
            self.kind = kind
            self.value = value
        }
    }

    /// Kiểm tra một giá trị JSON đầy đủ. `nil` = hợp lệ.
    public static func validate(_ bytes: UnsafeBufferPointer<UInt8>) -> Failure? {
        var cursor = Cursor(bytes: bytes)
        cursor.skipSpace()
        if cursor.index >= bytes.count {
            return Failure(offset: 0, message: "dòng rỗng, không có giá trị JSON nào")
        }
        if let failure = cursor.value(depth: 0) { return failure }
        cursor.skipSpace()
        if cursor.index < bytes.count {
            return Failure(offset: cursor.index,
                           message: "còn thừa chữ sau giá trị JSON đã kết thúc")
        }
        return nil
    }

    /// Trường mức trên cùng, theo đúng THỨ TỰ trong dòng.
    ///
    /// Trả `nil` khi dòng không hợp lệ hoặc không phải một đối tượng. Khoá TRÙNG được giữ cả
    /// hai — JSON cho phép, và giấu bớt một khoá là giấu đúng thứ đáng ngờ.
    public static func topLevelFields(_ bytes: UnsafeBufferPointer<UInt8>) -> [Field]? {
        var cursor = Cursor(bytes: bytes, collectFields: true)
        cursor.skipSpace()
        guard cursor.index < bytes.count, bytes[cursor.index] == 0x7B else { return nil }
        guard cursor.value(depth: 0) == nil else { return nil }
        cursor.skipSpace()
        guard cursor.index >= bytes.count else { return nil }
        return cursor.fields
    }

    /// In đẹp — thẻ xem bản ghi của FR-KNW-901.
    ///
    /// Tự in chứ không nhờ `JSONSerialization.WritingOptions.prettyPrinted`, vì bản của hệ
    /// thống **sắp lại khoá** khi đi qua `NSDictionary` (thứ tự băm), và người đang soi một bản
    /// ghi JSONL cần thấy đúng thứ tự mà tệp viết ra. Nó cũng đổi số: `1.0` thành `1`,
    /// `1e3` thành `1000` — với dữ liệu số thực đó là mất thông tin về CÁCH GHI.
    public static func pretty(
        _ bytes: UnsafeBufferPointer<UInt8>, indent: Int = 2
    ) -> String? {
        guard validate(bytes) == nil else { return nil }
        var out = ""
        out.reserveCapacity(bytes.count * 2)
        var cursor = Cursor(bytes: bytes)
        cursor.skipSpace()
        cursor.print(into: &out, level: 0, indent: indent)
        return out
    }

    // MARK: - Con trỏ

    private struct Cursor {
        let bytes: UnsafeBufferPointer<UInt8>
        var index = 0
        var collectFields = false
        var fields: [Field] = []

        init(bytes: UnsafeBufferPointer<UInt8>, collectFields: Bool = false) {
            self.bytes = bytes
            self.collectFields = collectFields
        }

        mutating func skipSpace() {
            while index < bytes.count {
                switch bytes[index] {
                case 0x20, 0x09, 0x0A, 0x0D: index += 1
                default: return
                }
            }
        }

        func fail(_ message: String, at offset: Int? = nil) -> Failure {
            Failure(offset: offset ?? index, message: message)
        }

        /// Đọc một giá trị. Trả `nil` khi đọc được.
        mutating func value(depth: Int) -> Failure? {
            guard depth < maximumDepth else {
                return fail("JSON lồng sâu quá \(maximumDepth) cấp — bộ đọc dừng ở đây thay vì "
                    + "đệ quy tiếp")
            }
            guard index < bytes.count else { return fail("thiếu giá trị") }
            switch bytes[index] {
            case 0x7B: return object(depth: depth)
            case 0x5B: return array(depth: depth)
            case 0x22: return string().failure
            case 0x74: return literal("true")
            case 0x66: return literal("false")
            case 0x6E: return literal("null")
            default: return number()
            }
        }

        mutating func literal(_ word: String) -> Failure? {
            let expected = Array(word.utf8)
            guard index + expected.count <= bytes.count else {
                return fail("«\(word)» bị cắt cụt ở cuối dòng")
            }
            for (offset, byte) in expected.enumerated() where bytes[index + offset] != byte {
                return fail("chữ lạ — chỉ có true, false, null là từ khoá của JSON")
            }
            index += expected.count
            return nil
        }

        /// Chuỗi. Trả cả dải BÊN TRONG hai dấu nháy để chỗ gọi lấy tên khoá.
        mutating func string() -> (failure: Failure?, range: Range<Int>) {
            let opening = index
            index += 1
            let start = index
            while index < bytes.count {
                let byte = bytes[index]
                if byte == 0x22 {
                    let range = start ..< index
                    index += 1
                    return (nil, range)
                }
                if byte == 0x5C {
                    index += 1
                    guard index < bytes.count else {
                        return (fail("dấu thoát «\\» ở cuối dòng, thiếu ký tự đi kèm"), 0 ..< 0)
                    }
                    switch bytes[index] {
                    case 0x22, 0x5C, 0x2F, 0x62, 0x66, 0x6E, 0x72, 0x74:
                        index += 1
                    case 0x75:
                        index += 1
                        for _ in 0 ..< 4 {
                            guard index < bytes.count, isHex(bytes[index]) else {
                                return (fail("«\\u» phải theo sau đúng 4 chữ số thập lục"),
                                        0 ..< 0)
                            }
                            index += 1
                        }
                    default:
                        return (fail("«\\» đứng trước ký tự không phải dấu thoát hợp lệ "
                            + "(chỉ có \" \\ / b f n r t u)"), 0 ..< 0)
                    }
                    continue
                }
                if byte < 0x20 {
                    return (fail("ký tự điều khiển thô trong chuỗi — JSON đòi viết dạng "
                        + "\\u00XX"), 0 ..< 0)
                }
                if byte >= 0x80 {
                    guard let width = utf8Width(at: index) else {
                        return (fail("byte không phải UTF-8 hợp lệ"), 0 ..< 0)
                    }
                    index += width
                    continue
                }
                index += 1
            }
            return (fail("chuỗi mở bằng « \" » mà không có dấu nháy đóng", at: opening), 0 ..< 0)
        }

        mutating func number() -> Failure? {
            let start = index
            if index < bytes.count, bytes[index] == 0x2D { index += 1 }
            guard index < bytes.count, isDigit(bytes[index]) else {
                return fail("không đọc được giá trị — JSON không nhận chữ trần, dấu nháy đơn, "
                    + "hay số bắt đầu bằng dấu chấm", at: start)
            }
            // `0` không được có chữ số đứng sau: `01` không phải JSON.
            if bytes[index] == 0x30 {
                index += 1
                if index < bytes.count, isDigit(bytes[index]) {
                    return fail("số không được bắt đầu bằng số 0 thừa", at: start)
                }
            } else {
                while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            }
            if index < bytes.count, bytes[index] == 0x2E {
                index += 1
                guard index < bytes.count, isDigit(bytes[index]) else {
                    return fail("sau dấu chấm thập phân phải có chữ số")
                }
                while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            }
            if index < bytes.count, bytes[index] == 0x65 || bytes[index] == 0x45 {
                index += 1
                if index < bytes.count, bytes[index] == 0x2B || bytes[index] == 0x2D {
                    index += 1
                }
                guard index < bytes.count, isDigit(bytes[index]) else {
                    return fail("sau «e» của số mũ phải có chữ số")
                }
                while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            }
            return nil
        }

        mutating func object(depth: Int) -> Failure? {
            let opening = index
            index += 1
            skipSpace()
            if index < bytes.count, bytes[index] == 0x7D { index += 1; return nil }
            while true {
                skipSpace()
                guard index < bytes.count else {
                    return fail("đối tượng «{» chưa đóng", at: opening)
                }
                guard bytes[index] == 0x22 else {
                    return fail("tên khoá phải nằm trong dấu nháy kép")
                }
                let key = string()
                if let failure = key.failure { return failure }
                let name = collectFields && depth == 0
                    ? String(decoding: bytes[key.range], as: UTF8.self) : ""
                skipSpace()
                guard index < bytes.count, bytes[index] == 0x3A else {
                    return fail("thiếu dấu «:» sau tên khoá")
                }
                index += 1
                skipSpace()
                let valueStart = index
                let kind = kindAt(index)
                if let failure = value(depth: depth + 1) { return failure }
                if collectFields, depth == 0, let kind {
                    fields.append(Field(name: name, kind: kind, value: valueStart ..< index))
                }
                skipSpace()
                guard index < bytes.count else {
                    return fail("đối tượng «{» chưa đóng", at: opening)
                }
                if bytes[index] == 0x2C {
                    index += 1
                    skipSpace()
                    if index < bytes.count, bytes[index] == 0x7D {
                        return fail("dấu phẩy thừa trước «}»")
                    }
                    continue
                }
                if bytes[index] == 0x7D { index += 1; return nil }
                return fail("thiếu dấu «,» hoặc «}» sau một cặp khoá–giá trị")
            }
        }

        mutating func array(depth: Int) -> Failure? {
            let opening = index
            index += 1
            skipSpace()
            if index < bytes.count, bytes[index] == 0x5D { index += 1; return nil }
            while true {
                skipSpace()
                if let failure = value(depth: depth + 1) { return failure }
                skipSpace()
                guard index < bytes.count else {
                    return fail("mảng «[» chưa đóng", at: opening)
                }
                if bytes[index] == 0x2C {
                    index += 1
                    skipSpace()
                    if index < bytes.count, bytes[index] == 0x5D {
                        return fail("dấu phẩy thừa trước «]»")
                    }
                    continue
                }
                if bytes[index] == 0x5D { index += 1; return nil }
                return fail("thiếu dấu «,» hoặc «]» sau một phần tử mảng")
            }
        }

        func kindAt(_ position: Int) -> Kind? {
            guard position < bytes.count else { return nil }
            switch bytes[position] {
            case 0x7B: return .object
            case 0x5B: return .array
            case 0x22: return .string
            case 0x74, 0x66: return .boolean
            case 0x6E: return .null
            default: return .number
            }
        }

        func utf8Width(at position: Int) -> Int? {
            let first = bytes[position]
            let width: Int
            if first >= 0xF0, first <= 0xF4 { width = 4 }
            else if first >= 0xE0, first <= 0xEF { width = 3 }
            else if first >= 0xC2, first <= 0xDF { width = 2 }
            else { return nil }
            guard position + width <= bytes.count else { return nil }
            for offset in 1 ..< width {
                let byte = bytes[position + offset]
                guard byte >= 0x80, byte <= 0xBF else { return nil }
            }
            return width
        }

        // MARK: - In đẹp

        mutating func print(into out: inout String, level: Int, indent: Int) {
            skipSpace()
            guard index < bytes.count else { return }
            let pad = String(repeating: " ", count: level * indent)
            let inner = String(repeating: " ", count: (level + 1) * indent)
            switch bytes[index] {
            case 0x7B:
                index += 1
                skipSpace()
                if index < bytes.count, bytes[index] == 0x7D { index += 1; out += "{}"; return }
                out += "{\n"
                var first = true
                while index < bytes.count {
                    if !first { out += ",\n" }
                    first = false
                    skipSpace()
                    let key = string()
                    out += inner + "\"" + String(decoding: bytes[key.range], as: UTF8.self) + "\": "
                    skipSpace()
                    index += 1                      // dấu «:»
                    print(into: &out, level: level + 1, indent: indent)
                    skipSpace()
                    if index < bytes.count, bytes[index] == 0x2C { index += 1; continue }
                    break
                }
                if index < bytes.count, bytes[index] == 0x7D { index += 1 }
                out += "\n" + pad + "}"
            case 0x5B:
                index += 1
                skipSpace()
                if index < bytes.count, bytes[index] == 0x5D { index += 1; out += "[]"; return }
                out += "[\n"
                var first = true
                while index < bytes.count {
                    if !first { out += ",\n" }
                    first = false
                    out += inner
                    print(into: &out, level: level + 1, indent: indent)
                    skipSpace()
                    if index < bytes.count, bytes[index] == 0x2C { index += 1; continue }
                    break
                }
                if index < bytes.count, bytes[index] == 0x5D { index += 1 }
                out += "\n" + pad + "]"
            default:
                // Giá trị nguyên tử: chép NGUYÊN VĂN byte của nó, không diễn giải rồi in lại.
                let start = index
                _ = value(depth: 0)
                out += String(decoding: bytes[start ..< index], as: UTF8.self)
            }
        }
    }

    private static func isDigit(_ byte: UInt8) -> Bool { byte >= 0x30 && byte <= 0x39 }

    private static func isHex(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x46)
            || (byte >= 0x61 && byte <= 0x66)
    }
}
