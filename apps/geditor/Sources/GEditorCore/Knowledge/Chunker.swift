import Foundation

/// Cắt văn bản thành chunk — FR-KNW-903.
///
/// ## Vì sao bộ cắt ở LÕI chứ không nằm trong panel
///
/// `ChunkInspector` (FR-KNW-902) SOI một corpus đã có; `ChunkQuality` (922) CHẤM nó. Cả hai đọc
/// chunk do công cụ khác sinh ra. Mã này là chiều ngược lại — sinh chunk từ văn bản — và nó phải
/// ở lõi vì hai chỗ cần nó: bản xem trước trong editor, và lệnh xuất JSONL. Hai bản hiện thực
/// cho ra hai cách cắt khác nhau là đúng mẫu lỗi dự án này đã gặp ba lần.
///
/// ## Chunk là KHOẢNG BYTE, không phải chuỗi đã cắt rời
///
/// Trả về `Range<Int>` trên buffer chứ không trả `[String]`. Lý do là vế "ranh giới chunk tô màu
/// trong editor" của đặc tả: tô màu cần biết chunk NẰM ĐÂU trong tài liệu gốc, mà một mảng chuỗi
/// đã mất thông tin ấy. Ai cần chữ thì cắt ra từ khoảng — rẻ và không mất mát.
///
/// ## Không bao giờ cắt giữa một ký tự
///
/// Mọi biên đều lùi về đầu ký tự UTF-8 gần nhất. Cắt giữa một ký tự tiếng Việt cho ra hai nửa vô
/// nghĩa ở hai chunk, và tệ hơn: chuỗi hỏng ấy đi thẳng vào JSONL rồi vào chỉ mục truy hồi, nơi
/// nó không khớp với gì cả và cũng không báo lỗi.
public enum Chunker {

    public enum Strategy: Equatable, Sendable {
        /// Cỡ cố định theo BYTE, kèm phần chồng lấn.
        case fixed(size: Int, overlap: Int)
        /// Theo câu, gộp cho tới khi chạm `maxSize`.
        case sentence(maxSize: Int)
        /// Theo heading Markdown ở mức `level` trở lên (1 = chỉ `#`, 2 = `#` và `##`…).
        case heading(level: Int)

        public var displayName: String {
            switch self {
            case let .fixed(size, overlap): return "Cỡ cố định \(size)B, chồng \(overlap)B"
            case let .sentence(maxSize): return "Theo câu (≤ \(maxSize)B)"
            case let .heading(level): return "Theo heading Markdown (tới mức \(level))"
            }
        }
    }

    public struct Chunk: Equatable, Sendable {
        /// Khoảng BYTE trong buffer gốc.
        public let range: Range<Int>
        /// Số thứ tự, 0-based.
        public let index: Int
        /// Heading bao chunk này, nếu cắt theo heading — để JSONL mang được ngữ cảnh.
        public let heading: String?

        public var byteCount: Int { range.count }
    }

    // MARK: - Cắt

    public static func chunks(
        in buffer: TextBuffer, strategy: Strategy, cancelToken: CancelToken = CancelToken()
    ) -> [Chunk] {
        switch strategy {
        case let .fixed(size, overlap):
            return coDinh(buffer, size: size, overlap: overlap, cancelToken: cancelToken)
        case let .sentence(maxSize):
            return theoCau(buffer, maxSize: maxSize, cancelToken: cancelToken)
        case let .heading(level):
            return theoHeading(buffer, level: level, cancelToken: cancelToken)
        }
    }

    /// Cỡ cố định + chồng lấn.
    ///
    /// **`overlap` bị kẹp xuống dưới `size`.** Không kẹp thì mỗi bước tiến `size − overlap ≤ 0`
    /// và vòng lặp chạy mãi — trên một tài liệu 100 MB thì triệu chứng là app đứng im, không phải
    /// một thông báo lỗi. Đây là loại tham số người dùng gõ vào ô nhập, nên "chắc không ai gõ
    /// thế" không phải một lời bảo đảm.
    static func coDinh(
        _ buffer: TextBuffer, size: Int, overlap: Int, cancelToken: CancelToken
    ) -> [Chunk] {
        let total = buffer.count
        guard total > 0, size > 0 else { return [] }
        let overlap = max(0, min(overlap, size - 1))
        let step = size - overlap

        var out: [Chunk] = []
        var start = 0
        while start < total {
            if cancelToken.isCancelled { break }
            let end = bienKyTu(buffer, min(start + size, total))
            guard end > start else { break }
            out.append(Chunk(range: start ..< end, index: out.count, heading: nil))
            if end >= total { break }
            start = bienKyTu(buffer, start + step)
            // Biên ký tự có thể kéo `start` lùi lại; nếu nó không tiến được thì dừng thay vì
            // quay vòng. Thà thiếu một chunk cuối còn hơn treo máy.
            if start <= out[out.count - 1].range.lowerBound { break }
        }
        return out
    }

    /// Theo câu, gộp cho tới khi chạm trần.
    ///
    /// Một câu DÀI hơn trần thì thành một chunk riêng, không bị chẻ đôi: chẻ giữa câu là mất đúng
    /// thứ chiến lược này sinh ra để giữ.
    static func theoCau(
        _ buffer: TextBuffer, maxSize: Int, cancelToken: CancelToken
    ) -> [Chunk] {
        let ranh = bienCau(buffer, cancelToken: cancelToken)
        guard !ranh.isEmpty else { return [] }

        var out: [Chunk] = []
        var start = ranh[0].lowerBound
        var end = start
        for cau in ranh {
            if cancelToken.isCancelled { break }
            if end > start, cau.upperBound - start > maxSize {
                out.append(Chunk(range: start ..< end, index: out.count, heading: nil))
                start = cau.lowerBound
            }
            end = cau.upperBound
        }
        if end > start { out.append(Chunk(range: start ..< end, index: out.count, heading: nil)) }
        return out
    }

    /// Theo heading Markdown. Mỗi khối = một heading cộng phần thân tới heading kế cùng mức
    /// hoặc cao hơn.
    static func theoHeading(
        _ buffer: TextBuffer, level: Int, cancelToken: CancelToken
    ) -> [Chunk] {
        var moc: [(offset: Int, text: String)] = []
        let lines = buffer.lineCount
        for line in 0 ..< lines {
            if cancelToken.isCancelled { break }
            let start = buffer.offset(ofLineStart: line)
            let end = line + 1 < lines ? buffer.offset(ofLineStart: line + 1) : buffer.count
            let bytes = buffer.bytes(in: start ..< min(end, start + 512))
            var dau = 0
            while dau < bytes.count, bytes[dau] == UInt8(ascii: "#") { dau += 1 }
            guard dau >= 1, dau <= level,
                  dau < bytes.count, bytes[dau] == 0x20 else { continue }
            moc.append((start, String(decoding: bytes, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        guard !moc.isEmpty else {
            // Không có heading nào là kết quả HỢP LỆ: cả tài liệu thành một chunk. Trả rỗng sẽ
            // làm người dùng tưởng tính năng hỏng.
            return buffer.count > 0
                ? [Chunk(range: 0 ..< buffer.count, index: 0, heading: nil)] : []
        }

        var out: [Chunk] = []
        // Phần TRƯỚC heading đầu tiên không bị bỏ — nó thường là phần mở đầu của tài liệu.
        if moc[0].offset > 0 {
            out.append(Chunk(range: 0 ..< moc[0].offset, index: 0, heading: nil))
        }
        for (i, m) in moc.enumerated() {
            let end = i + 1 < moc.count ? moc[i + 1].offset : buffer.count
            guard end > m.offset else { continue }
            out.append(Chunk(range: m.offset ..< end, index: out.count, heading: m.text))
        }
        return out
    }

    // MARK: - Biên

    /// Lùi về đầu ký tự UTF-8 gần nhất — byte tiếp diễn có dạng `10xxxxxx`.
    static func bienKyTu(_ buffer: TextBuffer, _ offset: Int) -> Int {
        var o = min(max(offset, 0), buffer.count)
        while o > 0, o < buffer.count {
            let b = buffer.bytes(in: o ..< o + 1)[0]
            if b & 0xC0 != 0x80 { break }
            o -= 1
        }
        return o
    }

    /// Biên câu. Dấu `.` `!` `?` theo sau bởi khoảng trắng hoặc hết dòng.
    ///
    /// KHÔNG cắt sau một chữ số (`3.14`, `mục 2.1`) — đó là ca hay gặp nhất trong tài liệu kỹ
    /// thuật tiếng Việt, và cắt nhầm ở đó sinh ra hàng loạt chunk một chữ.
    static func bienCau(_ buffer: TextBuffer, cancelToken: CancelToken) -> [Range<Int>] {
        let bytes = buffer.bytes(in: 0 ..< buffer.count)
        var out: [Range<Int>] = []
        var start = 0
        var i = 0
        while i < bytes.count {
            if cancelToken.isCancelled { break }
            let b = bytes[i]
            let ketCau = b == UInt8(ascii: ".") || b == UInt8(ascii: "!") || b == UInt8(ascii: "?")
            if ketCau {
                let truoc: UInt8? = i > 0 ? bytes[i - 1] : nil
                let sau: UInt8? = i + 1 < bytes.count ? bytes[i + 1] : nil
                let soTruoc = truoc.map { $0 >= 0x30 && $0 <= 0x39 } ?? false
                let soSau = sau.map { $0 >= 0x30 && $0 <= 0x39 } ?? false
                let trangSau = sau.map { $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }
                    ?? true
                if trangSau, !(b == UInt8(ascii: ".") && soTruoc && soSau) {
                    var end = i + 1
                    while end < bytes.count,
                          bytes[end] == 0x20 || bytes[end] == 0x0A || bytes[end] == 0x0D
                        || bytes[end] == 0x09 { end += 1 }
                    if end > start { out.append(start ..< end) }
                    start = end
                    i = end
                    continue
                }
            }
            i += 1
        }
        if start < bytes.count { out.append(start ..< bytes.count) }
        return out
    }

    // MARK: - Xuất JSONL

    /// Xuất chunk ra JSONL — cùng hình dạng mà `ChunkInspector` đọc vào.
    ///
    /// Giữ `start`/`end` theo BYTE để một corpus xuất ra còn truy ngược về tài liệu gốc được.
    /// Bỏ chúng đi là biến corpus thành một đống chữ không quay về đâu được.
    public static func jsonl(
        _ chunks: [Chunk], in buffer: TextBuffer, source: String? = nil
    ) -> String {
        var out = ""
        for chunk in chunks {
            let text = String(decoding: buffer.bytes(in: chunk.range), as: UTF8.self)
            var doi: [(String, String)] = [
                ("id", JSONText.quoted("chunk-\(chunk.index)")),
                ("text", JSONText.quoted(text)),
                ("start", String(chunk.range.lowerBound)),
                ("end", String(chunk.range.upperBound)),
            ]
            if let heading = chunk.heading { doi.append(("heading", JSONText.quoted(heading))) }
            if let source { doi.append(("source", JSONText.quoted(source))) }
            out += "{" + doi.map { "\"\($0.0)\":\($0.1)" }.joined(separator: ",") + "}\n"
        }
        return out
    }
}
