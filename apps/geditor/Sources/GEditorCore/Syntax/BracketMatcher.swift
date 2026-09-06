import Foundation

/// Tìm dấu ngoặc khớp với dấu ngoặc ở con nháy (FR-CORE-012).
///
/// **Vì sao không dùng cây cú pháp như `FoldRangesTree`.** Gấp khối chạy khi người dùng ra
/// lệnh — vài lần một buổi, và phân tích cả tài liệu là chấp nhận được. Khớp ngoặc thì chạy
/// theo MỖI NHỊP con nháy đi. Dựng lại cây cho từng phím mũi tên là cách chắc chắn biến việc
/// di chuyển con nháy thành giật.
///
/// **Nhưng cũng không được đếm ngoặc trần.** Lý do đã viết ở `FoldRangesTree`: mọi ngôn ngữ
/// đều cho dấu ngoặc nằm trong chuỗi và chú thích.
///
/// ```c
/// printf("dùng { để mở khối");   // và } để đóng
/// ```
///
/// Nên ở đây là con đường thứ ba: một bộ quét TỪ VỰNG nhẹ, chỉ phân biệt bốn thứ — mã, chuỗi,
/// chú thích dòng, chú thích khối — và bỏ qua dấu ngoặc ở ba thứ sau.
///
/// **Biên phải nói rõ.** Phân loại chuỗi/chú thích chỉ đúng nếu bắt đầu quét từ một chỗ chắc
/// chắn là mã. Chỗ duy nhất chắc chắn như vậy là ĐẦU TÀI LIỆU. Nên:
///
/// - Tài liệu ≤ `fullScanLimit` (1 MB): quét từ đầu, kết quả luôn đúng.
/// - Tài liệu lớn hơn: **không khớp ngoặc**, và nói ra chứ không đoán bừa.
///
/// Đây là lựa chọn có chủ ý, không phải giới hạn kỹ thuật. Neo giữa chừng một file 500 MB có
/// thể rơi vào giữa một chuỗi, và khi ấy mọi dấu ngoặc sau đó bị phân loại ngược — bôi sáng
/// SAI cặp ngoặc còn tệ hơn không bôi sáng gì, vì người dùng tin vào nó. Khớp ngoặc là tính
/// năng của mã nguồn; file mã nguồn 1 MB đã là rất lớn, còn file 500 MB là dữ liệu.
///
/// **Chỉ đọc.** Không hàm nào ở đây sinh ra sửa đổi.
public enum BracketMatcher {

    /// Trần cỡ tài liệu còn khớp ngoặc được.
    public static let fullScanLimit = 1 << 20

    public struct Match: Equatable, Sendable {
        /// Vị trí byte của dấu mở và dấu đóng.
        public let open: Int
        public let close: Int
        /// Dấu nào đang ở dưới con nháy.
        public let caretOnOpen: Bool

        public init(open: Int, close: Int, caretOnOpen: Bool) {
            self.open = open
            self.close = close
            self.caretOnOpen = caretOnOpen
        }

        public var partner: Int { caretOnOpen ? close : open }
    }

    static let pairs: [UInt8: UInt8] = [
        UInt8(ascii: "("): UInt8(ascii: ")"),
        UInt8(ascii: "["): UInt8(ascii: "]"),
        UInt8(ascii: "{"): UInt8(ascii: "}"),
    ]
    static let closers: [UInt8: UInt8] = [
        UInt8(ascii: ")"): UInt8(ascii: "("),
        UInt8(ascii: "]"): UInt8(ascii: "["),
        UInt8(ascii: "}"): UInt8(ascii: "{"),
    ]

    /// Cặp ngoặc quanh con nháy, hoặc `nil`.
    ///
    /// Xét cả byte NGAY TRƯỚC con nháy lẫn byte ngay sau. Người dùng vừa gõ `}` thì con nháy
    /// đứng sau nó, và đó chính là lúc họ muốn biết nó đóng cho cái gì — chỉ xét byte sau con
    /// nháy sẽ bỏ lỡ đúng khoảnh khắc ấy.
    public static func match(
        in buffer: TextBuffer, at caret: Int, language: SyntaxLanguage?
    ) -> Match? {
        guard buffer.count > 0, buffer.count <= fullScanLimit else { return nil }
        let bytes = buffer.bytes(in: 0 ..< buffer.count)
        let code = classify(bytes, language: language)

        // Byte SAU con nháy trước, rồi mới tới byte trước nó: gõ `(` xong thì thứ đáng quan
        // tâm là dấu vừa gõ, và nó nằm ngay trước con nháy — nhưng khi con nháy đứng lên đầu
        // một dấu ngoặc bằng phím mũi tên thì dấu ấy nằm sau. Thử cả hai, ưu tiên phía sau.
        for at in [caret, caret - 1] where at >= 0 && at < bytes.count {
            guard code[at] else { continue }
            let byte = bytes[at]
            if let want = pairs[byte] {
                if let close = scanForward(bytes, code, from: at, open: byte, close: want) {
                    return Match(open: at, close: close, caretOnOpen: true)
                }
            } else if let want = closers[byte] {
                if let open = scanBackward(bytes, code, from: at, open: want, close: byte) {
                    return Match(open: open, close: at, caretOnOpen: false)
                }
            }
        }
        return nil
    }

    private static func scanForward(
        _ bytes: [UInt8], _ code: [Bool], from start: Int, open: UInt8, close: UInt8
    ) -> Int? {
        var depth = 0
        var index = start
        while index < bytes.count {
            if code[index] {
                if bytes[index] == open { depth += 1 }
                else if bytes[index] == close {
                    depth -= 1
                    if depth == 0 { return index }
                }
            }
            index += 1
        }
        return nil
    }

    private static func scanBackward(
        _ bytes: [UInt8], _ code: [Bool], from start: Int, open: UInt8, close: UInt8
    ) -> Int? {
        var depth = 0
        var index = start
        while index >= 0 {
            if code[index] {
                if bytes[index] == close { depth += 1 }
                else if bytes[index] == open {
                    depth -= 1
                    if depth == 0 { return index }
                }
            }
            index -= 1
        }
        return nil
    }

    // MARK: - Phân loại

    /// Byte nào là MÃ (không nằm trong chuỗi hay chú thích).
    ///
    /// Một lượt quét, một mảng `Bool` cùng cỡ tài liệu. Với trần 1 MB thì đó là 1 MB bộ nhớ
    /// tạm — đổi lấy việc hai phép quét ngoặc bên trên không phải tự hỏi lại "byte này có
    /// trong chuỗi không" ở mỗi bước.
    static func classify(_ bytes: [UInt8], language: SyntaxLanguage?) -> [Bool] {
        var code = [Bool](repeating: true, count: bytes.count)
        let lineToken = language?.lineCommentToken.map { Array($0.utf8) }
        let block = language?.blockCommentTokens.map { (Array($0.open.utf8), Array($0.close.utf8)) }
        // Ngôn ngữ không nhận ra được thì vẫn chạy: dấu nháy đơn/kép là quy ước gần như chung,
        // và bỏ qua chúng vẫn tốt hơn nhiều so với đếm ngoặc trần.
        let quotes: Set<UInt8> = [UInt8(ascii: "\""), UInt8(ascii: "'"), UInt8(ascii: "`")]

        var index = 0
        while index < bytes.count {
            let byte = bytes[index]

            if let lineToken, matches(bytes, at: index, lineToken) {
                while index < bytes.count, bytes[index] != 0x0A {
                    code[index] = false
                    index += 1
                }
                continue
            }
            if let block, matches(bytes, at: index, block.0) {
                let from = index
                index += block.0.count
                while index < bytes.count, !matches(bytes, at: index, block.1) { index += 1 }
                index = min(bytes.count, index + block.1.count)
                for at in from ..< index { code[at] = false }
                continue
            }
            if quotes.contains(byte) {
                let quote = byte
                let from = index
                index += 1
                while index < bytes.count {
                    // Dấu gạch chéo ngược nuốt ký tự kế: `"\""` là một chuỗi chứa dấu nháy,
                    // không phải hai chuỗi rỗng liền nhau.
                    if bytes[index] == UInt8(ascii: "\\") { index += 2; continue }
                    if bytes[index] == quote { index += 1; break }
                    // Chuỗi KHÔNG được vắt qua dòng trong hầu hết ngôn ngữ. Dừng ở xuống dòng
                    // để một dấu nháy lẻ — dấu phẩy trong tiếng Anh, `don't` — không nuốt sạch
                    // phần còn lại của file.
                    if bytes[index] == 0x0A { break }
                    index += 1
                }
                for at in from ..< min(index, bytes.count) { code[at] = false }
                continue
            }
            index += 1
        }
        return code
    }

    private static func matches(_ bytes: [UInt8], at index: Int, _ needle: [UInt8]) -> Bool {
        guard !needle.isEmpty, index + needle.count <= bytes.count else { return false }
        for offset in 0 ..< needle.count where bytes[index + offset] != needle[offset] {
            return false
        }
        return true
    }
}
