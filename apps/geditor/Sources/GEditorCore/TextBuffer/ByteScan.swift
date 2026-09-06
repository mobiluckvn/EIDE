import Foundation
import GEditorSIMD

/// Lớp bọc Swift cho các hàm quét byte trong `GEditorSIMD`.
///
/// Lý do tồn tại: API C trả `SIZE_MAX` làm sentinel "không tìm thấy". Kiểu đó khi
/// import sang Swift dễ bị so sánh nhầm (Int vs UInt) và im lặng cho kết quả sai.
/// Mọi mã Swift dùng qua đây, không gọi thẳng hàm C.
public enum ByteScan {

    /// Offset của byte `needle` đầu tiên trong buffer, hoặc `nil`.
    public static func firstIndex(
        of needle: UInt8,
        in buffer: UnsafeRawBufferPointer,
        from start: Int = 0
    ) -> Int? {
        guard start < buffer.count,
              let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
        else { return nil }

        let found = geditor_find_byte(base.advanced(by: start), buffer.count - start, needle)
        guard found >= 0 else { return nil }
        return start + Int(found)
    }

    /// Số byte `\n` trong buffer — dùng nhánh NEON/AVX2 theo kiến trúc.
    public static func countNewlines(in buffer: UnsafeRawBufferPointer) -> Int {
        guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        return Int(geditor_count_newlines(base, buffer.count))
    }

    public static func countNewlines(in bytes: [UInt8]) -> Int {
        bytes.withUnsafeBytes { countNewlines(in: $0) }
    }

    /// Buffer có phải UTF-8 hợp lệ hay không.
    ///
    /// Vì sao lõi cần hàm này (ADR-03): PCRE2 tự kiểm tra tính hợp lệ UTF-8 của subject ở
    /// MỖI lời gọi `pcre2_match`. Trong một lần tìm toàn cục có hàng trăm nghìn kết quả,
    /// điều đó biến O(n) thành O(n²) — đo được 34 000 lần chậm hơn trên 4 MB. Kiểm tra MỘT
    /// LẦN ở đây rồi truyền `PCRE2_NO_UTF_CHECK` cho mọi lần khớp là cách thoát ra.
    ///
    /// Kiểm đúng theo bảng của chuẩn Unicode: bắt cả chuỗi mã hóa dài dư (overlong), nửa
    /// cặp thay thế (surrogate) và điểm mã vượt U+10FFFF — không chỉ đếm byte tiếp nối.
    /// Offset của byte không phải ASCII đầu tiên kể từ `start`, hoặc `nil`.
    public static func firstNonASCII(in buffer: UnsafeRawBufferPointer, from start: Int = 0) -> Int? {
        guard start < buffer.count,
              let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
        else { return nil }

        let found = geditor_find_non_ascii(base.advanced(by: start), buffer.count - start)
        guard found >= 0 else { return nil }
        return start + Int(found)
    }

    public static func isValidUTF8(_ buffer: UnsafeRawBufferPointer) -> Bool {
        var index = 0
        let count = buffer.count

        while index < count {
            // Nhảy qua cả vùng ASCII bằng một lượt quét vector. Văn bản mã nguồn, log và CSV
            // gần như toàn ASCII, nên gần như toàn bộ chi phí biến mất ở đây; tiếng Việt có
            // dấu thì mỗi lần nhảy dừng đúng ở ký tự nhiều byte tiếp theo.
            guard let nonASCII = firstNonASCII(in: buffer, from: index) else { return true }
            index = nonASCII

            let byte = buffer[index]
            let length: Int
            let secondRange: ClosedRange<UInt8>

            switch byte {
            case 0xC2 ... 0xDF: length = 2; secondRange = 0x80 ... 0xBF
            // 0xE0 0x80..0x9F là mã hóa dài dư của điểm mã < U+0800.
            case 0xE0:          length = 3; secondRange = 0xA0 ... 0xBF
            case 0xE1 ... 0xEC: length = 3; secondRange = 0x80 ... 0xBF
            // 0xED 0xA0..0xBF là nửa cặp thay thế U+D800…U+DFFF — cấm trong UTF-8.
            case 0xED:          length = 3; secondRange = 0x80 ... 0x9F
            case 0xEE ... 0xEF: length = 3; secondRange = 0x80 ... 0xBF
            // 0xF0 0x80..0x8F là mã hóa dài dư của điểm mã < U+10000.
            case 0xF0:          length = 4; secondRange = 0x90 ... 0xBF
            case 0xF1 ... 0xF3: length = 4; secondRange = 0x80 ... 0xBF
            // 0xF4 0x90.. vượt U+10FFFF.
            case 0xF4:          length = 4; secondRange = 0x80 ... 0x8F
            // 0x80…0xC1 (byte tiếp nối lạc chỗ, hoặc mở đầu dài dư) và 0xF5…0xFF: không hợp lệ.
            default: return false
            }

            guard index + length <= count else { return false }
            guard secondRange.contains(buffer[index + 1]) else { return false }
            for offset in 2 ..< length where (buffer[index + offset] & 0xC0) != 0x80 {
                return false
            }
            index += length
        }
        return true
    }

    public static func isValidUTF8(_ bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBytes { isValidUTF8($0) }
    }

    /// Số byte `\n` trong `range` của buffer.
    ///
    /// Cắt `range` về trong phạm vi buffer thay vì precondition: người gọi chính là
    /// `NewlineBlockIndex`, nơi khối cuối luôn ngắn hơn `blockSize`.
    public static func countNewlines(in buffer: UnsafeRawBufferPointer, range: Range<Int>) -> Int {
        let lo = max(0, range.lowerBound)
        let hi = min(buffer.count, range.upperBound)
        guard lo < hi, let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return 0
        }
        return Int(geditor_count_newlines(base.advanced(by: lo), hi - lo))
    }
}
