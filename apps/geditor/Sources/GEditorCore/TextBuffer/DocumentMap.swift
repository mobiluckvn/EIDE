import Foundation

/// Bản đồ thu nhỏ của CẢ tài liệu (FR-DOC-306).
///
/// **Bài toán thật nằm ở chữ "cả".** Một minimap thông thường vẽ chữ thu nhỏ, tức là phải đọc
/// toàn bộ nội dung. Với file 500 MB thì đó là 500 MB đọc mỗi lần vẽ lại — không làm được, và
/// cũng không được phép giả vờ: một bản đồ chỉ mô tả 2 MB đang mở mà trông như mô tả cả file
/// sẽ khiến người dùng kết luận sai về thứ họ không nhìn thấy.
///
/// **Cách làm ở đây: đọc CHỈ MỤC DÒNG, không đọc nội dung.** Piece tree đã giữ sẵn offset đầu
/// mỗi dòng, tra một dòng bất kỳ tốn `O(log n)`. Bản đồ cao vài trăm điểm ảnh, nên chỉ cần lấy
/// mẫu vài trăm dòng đại diện — vài trăm lần tra chỉ mục cho một file bất kỳ cỡ nào. Độ dài
/// dòng suy ra từ hiệu hai offset, hoàn toàn không chạm byte nội dung.
///
/// Phần thụt lề thì phải đọc, nhưng chỉ vài chục byte đầu mỗi dòng đã lấy mẫu — có trần cứng ở
/// `maximumIndentProbe`. Thụt lề là thứ làm bản đồ nhận ra được: một hàm dài trông khác một
/// khối dữ liệu phẳng.
///
/// **Điều bản đồ này KHÔNG làm:** nó không vẽ chữ, không tô màu cú pháp, không biết dòng nào là
/// chú thích. Nó vẽ HÌNH DÁNG tài liệu. Muốn màu cú pháp trong bản đồ thì phải phân tích cả
/// file — đúng thứ ADR-04 đã từ chối, và từ chối có lý do.
///
/// **Đã đo** (`geditor-bench document-map`, bản release):
///
/// | File | Dòng | 600 hàng |
/// |---|---|---|
/// | 0,19 MB | 2 335 | 4,72 ms |
/// | 245 MB | 3 000 000 | 4,93 ms |
///
/// Chi phí bám theo SỐ HÀNG của bản đồ, không bám theo cỡ file — đúng thứ lập luận trên nói,
/// và giờ có số. 1 200 hàng tốn 10 ms, vẫn trong ngân sách một khung hình 16 ms; nhưng đó là
/// chi phí mỗi lần DỰNG LẠI, nên chỗ gọi phải nhớ tạm bản đồ và chỉ dựng lại khi tài liệu đổi,
/// không dựng lại theo từng nhịp cuộn.
///
/// **Chỉ đọc.** Không hàm nào ở đây sinh ra sửa đổi.
public struct DocumentMap: Equatable, Sendable {

    /// Một hàng của bản đồ — đại diện cho một hoặc nhiều dòng thật.
    public struct Row: Equatable, Sendable {
        /// Dòng đại diện (0-based) trong tài liệu.
        public let line: Int
        /// Vị trí bắt đầu của vệt mực, tính theo tỉ lệ 0…1 của bề ngang bản đồ.
        public let inkStart: Double
        /// Vị trí kết thúc vệt mực. Bằng `inkStart` nghĩa là dòng trắng.
        public let inkEnd: Double

        public var isBlank: Bool { inkEnd <= inkStart }
    }

    public let rows: [Row]
    /// Tổng số dòng của tài liệu tại lúc dựng bản đồ.
    public let lineCount: Int
    /// Số dòng thật mà mỗi hàng đại diện. `1` nghĩa là bản đồ vẽ từng dòng một.
    public let linesPerRow: Double

    public var isEmpty: Bool { rows.isEmpty }

    // MARK: - Dựng

    /// Số byte nhiều nhất được đọc để đo thụt lề của một dòng.
    ///
    /// Có trần vì một file dữ liệu có thể có dòng dài hàng megabyte, và đọc hết chỉ để biết nó
    /// thụt bao nhiêu là trả giá vô ích. Thụt lề quá 64 cột thì vẽ ra cũng như nhau.
    public static let maximumIndentProbe = 64

    /// Bề rộng quy chiếu: dòng dài hơn ngần này thì vệt mực chạm mép phải.
    ///
    /// Cố định chứ không lấy theo dòng dài nhất tài liệu. Lấy theo dòng dài nhất thì một dòng
    /// 5 000 ký tự lạc vào sẽ bóp mọi dòng còn lại thành gần như vô hình — và bản đồ đang mô tả
    /// một file mã nguồn bình thường bỗng trắng trơn.
    public static let referenceWidth = 120.0

    public init(buffer: TextBuffer, rowCount: Int) {
        let lines = buffer.lineCount
        guard lines > 0, rowCount > 0 else {
            rows = []
            lineCount = lines
            linesPerRow = 1
            return
        }

        let count = Swift.min(rowCount, lines)
        let step = Double(lines) / Double(count)
        var out: [Row] = []
        out.reserveCapacity(count)

        for index in 0 ..< count {
            let line = Swift.min(lines - 1, Int((Double(index) + 0.5) * step))
            // `contentRange` bỏ CR/LF cuối dòng. Dùng hiệu hai offset đầu dòng thì dòng TRẮNG
            // vẫn dài 1 byte (chính ký tự xuống dòng) và vẽ ra một vệt mực — bản đồ của một file
            // có nhiều dòng trắng sẽ trông đặc kín. Cái giá là một phép đọc 2 byte ở cuối dòng.
            let content = buffer.contentRange(ofLine: line)
            let start = content.lowerBound
            let length = Swift.max(0, content.upperBound - content.lowerBound)

            let indent = Self.indentWidth(of: buffer, start: start, length: length)
            // Cột kết thúc tính theo BYTE, không theo ký tự. Với tiếng Việt thì một dòng chữ
            // trông ngắn hơn số byte của nó, nên vệt mực dài hơn thực tế một chút. Chấp nhận:
            // đo cho đúng thì phải giải mã UTF-8 cả dòng, tức là đọc nội dung — đúng thứ bản đồ
            // này sinh ra để tránh. Đây là bản đồ hình dáng, không phải thước đo.
            let inkStart = Swift.min(Double(indent) / Self.referenceWidth, 1)
            let inkEnd = Swift.min(Double(length) / Self.referenceWidth, 1)
            out.append(Row(line: line, inkStart: inkStart, inkEnd: Swift.max(inkStart, inkEnd)))
        }

        rows = out
        lineCount = lines
        linesPerRow = step
    }

    /// Đọc thụt lề, giới hạn ở `maximumIndentProbe` byte.
    private static func indentWidth(of buffer: TextBuffer, start: Int, length: Int) -> Int {
        guard length > 0 else { return 0 }
        let probe = Swift.min(length, maximumIndentProbe)
        let bytes = buffer.bytes(in: start ..< (start + probe))
        var width = 0
        for byte in bytes {
            if byte == UInt8(ascii: " ") {
                width += 1
            } else if byte == 0x09 {
                width += 8 - (width % 8)
            } else if byte == 0x0A || byte == 0x0D {
                return 0                      // dòng trắng: không có mực, cũng không có thụt lề
            } else {
                return width
            }
        }
        return width
    }

    // MARK: - Quy đổi

    /// Hàng nào của bản đồ chứa dòng `line`.
    public func row(forLine line: Int) -> Int {
        guard !rows.isEmpty, linesPerRow > 0 else { return 0 }
        let index = Int(Double(line) / linesPerRow)
        return Swift.min(Swift.max(index, 0), rows.count - 1)
    }

    /// Dòng tương ứng với một vị trí dọc trên bản đồ, tính theo tỉ lệ 0…1.
    ///
    /// Dùng khi người dùng bấm vào bản đồ. Kẹp về trong khoảng hợp lệ chứ không trả `nil`:
    /// bấm hụt một điểm ảnh ở mép dưới là chuyện thường, và đưa họ về cuối tài liệu là hành vi
    /// đúng — còn không làm gì cả thì trông như app treo.
    public func line(atFraction fraction: Double) -> Int {
        guard lineCount > 0 else { return 0 }
        let clamped = Swift.min(Swift.max(fraction, 0), 1)
        return Swift.min(lineCount - 1, Int(clamped * Double(lineCount)))
    }

    /// Khoảng tỉ lệ 0…1 mà một dải dòng chiếm trên bản đồ — để vẽ khung tầm nhìn.
    public func fractionRange(forLines range: Range<Int>) -> ClosedRange<Double> {
        guard lineCount > 0 else { return 0 ... 0 }
        let total = Double(lineCount)
        let low = Swift.min(Swift.max(Double(range.lowerBound) / total, 0), 1)
        let high = Swift.min(Swift.max(Double(range.upperBound) / total, 0), 1)
        return low ... Swift.max(low, high)
    }
}
