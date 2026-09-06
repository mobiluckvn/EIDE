import Foundation

/// Codec một byte cho các bảng mã tiếng Việt legacy (FR-ENC-201).
///
/// Làm việc trên BYTE, không dựng `String`: hợp đồng của lõi là offset byte, và một file
/// TCVN3 hàng trăm MB không thể đi qua `String` được.
///
/// Hai điều khiến codec này không chỉ là một bảng tra:
///
/// 1. **Kết hợp lúc giải mã.** TCVN3 và CP1258 viết "ế" thành hai byte — chữ nền rồi dấu
///    thanh. Nếu giải mã thô, tài liệu ra dạng tổ hợp trong khi người dùng gõ ra dạng dựng
///    sẵn: hai dạng khác byte nhau nên tìm kiếm trượt, diff báo khác, khóa CSV so sai. Codec
///    kết hợp ngay trong lúc giải mã để phía trên chỉ thấy một dạng duy nhất (FR-ENC-206).
///
/// 2. **Tách lúc mã hóa.** Chiều ngược lại: "ế" dựng sẵn không có trong bảng TCVN3, phải
///    tách thành chữ nền + dấu rồi mới tra. Không làm thì mọi chữ có dấu đều "không biểu
///    diễn được" và việc lưu về TCVN3 phá nát tài liệu.
public struct SingleByteCodec {

    /// byte → điểm mã Unicode.
    private let table: [UInt32]
    /// điểm mã → byte.
    private let reverse: [UInt32: UInt8]
    /// (chữ nền, dấu) → chữ dựng sẵn.
    private let composition: [UInt64: UInt32]
    /// chữ dựng sẵn → (chữ nền, dấu).
    private let decomposition: [UInt32: (base: UInt32, mark: UInt32)]
    /// Điểm mã là dấu tổ hợp.
    private let combiningMarks: Set<UInt32>

    public let name: String

    /// Ký tự thay khi byte không có nghĩa trong bảng mã.
    public static let replacementScalar: UInt32 = 0xFFFD

    init(name: String, table: [UInt32]) {
        precondition(table.count == 256, "bảng mã một byte phải đủ 256 mục")
        self.name = name
        self.table = table

        var reverse: [UInt32: UInt8] = [:]
        reverse.reserveCapacity(256)
        for (byte, scalar) in table.enumerated() where scalar != LegacyEncodingTables.unassigned {
            // Byte nhỏ nhất thắng nếu hai byte cùng nghĩa — giữ cho chiều mã hóa tất định.
            if reverse[scalar] == nil { reverse[scalar] = UInt8(byte) }
        }
        self.reverse = reverse

        var composition: [UInt64: UInt32] = [:]
        var decomposition: [UInt32: (UInt32, UInt32)] = [:]
        var marks: Set<UInt32> = []
        for entry in LegacyEncodingTables.composition {
            // Chỉ giữ cặp mà CẢ chữ nền lẫn dấu đều có trong bảng mã này; cặp của bảng khác
            // lọt vào đây sẽ tạo ra kết hợp không bao giờ xảy ra, chỉ tốn chỗ tra cứu.
            guard reverse[entry.base] != nil, reverse[entry.mark] != nil else { continue }
            composition[Self.key(entry.base, entry.mark)] = entry.composed
            decomposition[entry.composed] = (entry.base, entry.mark)
            marks.insert(entry.mark)
        }
        self.composition = composition
        self.decomposition = decomposition
        self.combiningMarks = marks
    }

    private static func key(_ base: UInt32, _ mark: UInt32) -> UInt64 {
        (UInt64(base) << 32) | UInt64(mark)
    }

    // MARK: - Giải mã

    /// Giải mã byte của bảng mã này thành UTF-8.
    ///
    /// Byte không có nghĩa thành U+FFFD chứ không bị bỏ đi: giữ được số ký tự thì người dùng
    /// còn nhìn ra chỗ hỏng, còn bỏ im lặng thì họ chỉ thấy văn bản ngắn đi một cách khó hiểu.
    public func decode(_ bytes: UnsafeRawBufferPointer) -> [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(bytes.count * 2)

        var pending: UInt32?
        for index in 0 ..< bytes.count {
            var scalar = table[Int(bytes[index])]
            if scalar == LegacyEncodingTables.unassigned { scalar = Self.replacementScalar }

            if combiningMarks.contains(scalar), let base = pending,
               let composed = composition[Self.key(base, scalar)] {
                pending = composed
                continue
            }

            if let base = pending { Self.appendUTF8(base, to: &out) }
            pending = scalar
        }
        if let base = pending { Self.appendUTF8(base, to: &out) }
        return out
    }

    public func decode(_ bytes: [UInt8]) -> [UInt8] {
        bytes.withUnsafeBytes { decode($0) }
    }

    /// Giải mã ra điểm mã thay vì byte UTF-8 — dùng cho bộ nhận diện, nơi cần XÉT từng ký tự
    /// chứ không cần dựng nội dung.
    func decodeScalars(_ bytes: [UInt8], limit: Int) -> [UInt32] {
        var out = [UInt32]()
        out.reserveCapacity(min(bytes.count, limit))
        var pending: UInt32?

        for byte in bytes.prefix(limit) {
            var scalar = table[Int(byte)]
            if scalar == LegacyEncodingTables.unassigned { scalar = Self.replacementScalar }

            if combiningMarks.contains(scalar), let base = pending,
               let composed = composition[Self.key(base, scalar)] {
                pending = composed
                continue
            }
            if let base = pending { out.append(base) }
            pending = scalar
        }
        if let base = pending { out.append(base) }
        return out
    }

    // MARK: - Mã hóa

    public struct EncodeResult {
        public let bytes: [UInt8]
        /// Số ký tự KHÔNG biểu diễn được, đã bị thay bằng `replacement`.
        public let unrepresentable: Int
        /// Điểm mã đầu tiên không biểu diễn được — đủ để lớp trên chỉ đúng chỗ cho người dùng.
        public let firstUnrepresentable: UInt32?

        public var isLossless: Bool { unrepresentable == 0 }
    }

    /// Mã hóa UTF-8 sang bảng mã này.
    ///
    /// KHÔNG bao giờ ném lỗi và KHÔNG bao giờ im lặng: ký tự ngoài kho của bảng mã bị thay
    /// bằng `replacement` và được ĐẾM. Lớp trên dùng con số đó để hỏi lại người dùng trước
    /// khi ghi đè bản gốc (FR-ENC-203) — đây là chỗ dữ liệu dễ mất nhất trong cả sản phẩm.
    public func encode(
        _ utf8: UnsafeRawBufferPointer, replacement: UInt8 = UInt8(ascii: "?")
    ) -> EncodeResult {
        var out = [UInt8]()
        out.reserveCapacity(utf8.count)
        var unrepresentable = 0
        var firstBad: UInt32?

        UTF8Scalars.forEach(utf8) { scalar in
            if let byte = reverse[scalar] {
                out.append(byte)
                return
            }
            // Chữ dựng sẵn không có trong bảng: tách ra chữ nền + dấu rồi ghi hai byte.
            if let parts = decomposition[scalar],
               let baseByte = reverse[parts.base], let markByte = reverse[parts.mark] {
                out.append(baseByte)
                out.append(markByte)
                return
            }
            unrepresentable += 1
            if firstBad == nil { firstBad = scalar }
            out.append(replacement)
        }

        return EncodeResult(
            bytes: out, unrepresentable: unrepresentable, firstUnrepresentable: firstBad
        )
    }

    public func encode(_ utf8: [UInt8], replacement: UInt8 = UInt8(ascii: "?")) -> EncodeResult {
        utf8.withUnsafeBytes { encode($0, replacement: replacement) }
    }

    /// Byte có nằm trong kho ký tự của bảng mã này không — dùng cho nhận diện (FR-ENC-202).
    public func isAssigned(_ byte: UInt8) -> Bool {
        table[Int(byte)] != LegacyEncodingTables.unassigned
    }

    public func scalar(for byte: UInt8) -> UInt32? {
        let scalar = table[Int(byte)]
        return scalar == LegacyEncodingTables.unassigned ? nil : scalar
    }

    private static func appendUTF8(_ scalar: UInt32, to out: inout [UInt8]) {
        switch scalar {
        case 0 ..< 0x80:
            out.append(UInt8(scalar))
        case 0x80 ..< 0x800:
            out.append(0xC0 | UInt8(scalar >> 6))
            out.append(0x80 | UInt8(scalar & 0x3F))
        case 0x800 ..< 0x1_0000:
            out.append(0xE0 | UInt8(scalar >> 12))
            out.append(0x80 | UInt8((scalar >> 6) & 0x3F))
            out.append(0x80 | UInt8(scalar & 0x3F))
        default:
            out.append(0xF0 | UInt8(scalar >> 18))
            out.append(0x80 | UInt8((scalar >> 12) & 0x3F))
            out.append(0x80 | UInt8((scalar >> 6) & 0x3F))
            out.append(0x80 | UInt8(scalar & 0x3F))
        }
    }
}

/// Duyệt điểm mã của một chuỗi UTF-8 mà không dựng `String`.
enum UTF8Scalars {
    /// Byte hỏng được trả về như U+FFFD và nhích một byte — cùng quy ước với `String(decoding:)`,
    /// nên mã hóa lại một tài liệu đã hỏng cho kết quả đoán trước được thay vì mất đồng bộ.
    static func forEach(_ bytes: UnsafeRawBufferPointer, _ body: (UInt32) -> Void) {
        var index = 0
        let count = bytes.count

        while index < count {
            let byte = bytes[index]
            if byte < 0x80 {
                body(UInt32(byte))
                index += 1
                continue
            }

            let length: Int
            var scalar: UInt32
            switch byte {
            case 0xC2 ... 0xDF: length = 2; scalar = UInt32(byte & 0x1F)
            case 0xE0 ... 0xEF: length = 3; scalar = UInt32(byte & 0x0F)
            case 0xF0 ... 0xF4: length = 4; scalar = UInt32(byte & 0x07)
            default:
                body(SingleByteCodec.replacementScalar)
                index += 1
                continue
            }

            guard index + length <= count else {
                body(SingleByteCodec.replacementScalar)
                index += 1
                continue
            }
            var valid = true
            for offset in 1 ..< length {
                let continuation = bytes[index + offset]
                guard (continuation & 0xC0) == 0x80 else { valid = false; break }
                scalar = (scalar << 6) | UInt32(continuation & 0x3F)
            }
            guard valid else {
                body(SingleByteCodec.replacementScalar)
                index += 1
                continue
            }

            body(scalar)
            index += length
        }
    }
}

extension SingleByteCodec {
    /// TCVN3 (TCVN 5712 VN3, quen gọi là "bảng mã ABC").
    ///
    /// Đặc sản cần biết: 12 chữ HOA có dấu nằm trong vùng ĐIỀU KHIỂN C0 (0x01–0x17). Nó né
    /// đúng 0x00, 0x09, 0x0A, 0x0D nên tách dòng và tab vẫn chạy — bộ sinh bảng khẳng định
    /// điều đó ở mỗi lần chạy chứ không coi là hiển nhiên.
    public static let tcvn3 = SingleByteCodec(name: "TCVN3", table: LegacyEncodingTables.tcvn3)

    /// VISCII — bảng mã một byte phủ trọn chữ Việt, dùng cả vùng C1 (0x80–0x9F) cho chữ.
    public static let viscii = SingleByteCodec(name: "VISCII", table: LegacyEncodingTables.viscii)

    /// Windows-1258 — bảng mã Việt của Windows, dùng dấu tổ hợp cho phần lớn chữ có dấu.
    public static let windows1258 = SingleByteCodec(
        name: "Windows-1258", table: LegacyEncodingTables.windows1258
    )
}
