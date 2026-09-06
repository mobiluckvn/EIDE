import Foundation

/// Sắp xếp theo cột cho Table view (FR-CSV-403).
///
/// Bản đặc tả tách bạch hai việc, và đó là điều quan trọng nhất ở đây:
///
///  - **Sắp xếp HIỂN THỊ** — bấm vào tiêu đề cột. Chỉ đổi thứ tự nhìn thấy, file không đổi
///    một byte. Đây là thứ người dùng làm hàng chục lần để dò dữ liệu.
///  - **Ghi vào file** — nút riêng, một bước undo.
///
/// Gộp hai việc ấy làm một là cách phá dữ liệu ngoài ý muốn (NT-5): người dùng bấm tiêu đề để
/// NHÌN, rồi lưu file, và thứ tự gốc — thứ tự nhập liệu, thứ tự chứng từ — mất vĩnh viễn.
public enum CSVSort {

    public enum Direction: Equatable, Sendable {
        case ascending
        case descending

        public var reversed: Direction { self == .ascending ? .descending : .ascending }

        /// Mũi tên hiển thị trên tiêu đề cột.
        public var arrow: String { self == .ascending ? "↑" : "↓" }
    }

    /// Thứ tự sắp xếp hiện hành: danh sách SỐ HÀNG theo trình tự hiển thị.
    public struct Order: Equatable {
        public let column: Int
        public let direction: Direction
        /// Số hàng trong file, theo đúng thứ tự cần hiển thị. Không chứa hàng tiêu đề.
        public let rows: [Int]

        public init(column: Int, direction: Direction, rows: [Int]) {
            self.column = column
            self.direction = direction
            self.rows = rows
        }
    }

    // MARK: - Sắp xếp hiển thị

    /// Tính thứ tự hiển thị khi sắp theo `column`.
    ///
    /// Kiểu so sánh do CẢ CỘT quyết định, không phải từng ô: nếu mọi ô không rỗng đều là số
    /// thì so theo số, còn lại so theo văn bản. Quyết định theo từng ô sẽ cho một quan hệ
    /// thứ tự không nhất quán ("10" < "9" khi so chuỗi nhưng > khi so số), và `sort` với quan
    /// hệ không nhất quán không chỉ cho kết quả lạ — nó có thể sập.
    ///
    /// Ô rỗng luôn xuống CUỐI, dù tăng hay giảm. Cột doanh thu sắp giảm dần mà ba chục dòng
    /// trống chiếm đầu bảng thì lần sắp xếp ấy vô dụng.
    public static func order(
        column: Int,
        direction: Direction,
        hasHeader: Bool,
        index: CSVRowIndex,
        in buffer: TextBuffer,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Order {
        let firstRow = hasHeader ? 1 : 0
        guard index.rowCount > firstRow else {
            return Order(column: column, direction: direction, rows: [])
        }

        var keys: [String] = []
        keys.reserveCapacity(index.rowCount - firstRow)

        var row = firstRow
        while row < index.rowCount {
            try cancelToken.check()
            let end = Swift.min(row + CSVRowIndex.anchorStride, index.rowCount)
            for fields in index.rows(row ..< end, in: buffer) {
                guard column < fields.count else { keys.append(""); continue }
                let raw = buffer.bytes(in: fields[column].range)
                keys.append(String(
                    decoding: CSVEngine.unescape(raw, dialect: index.dialect), as: UTF8.self
                ))
            }
            // Khối trả về thiếu hàng (tài liệu đã đổi dưới chân chỉ mục) thì bù chuỗi rỗng để
            // `keys` luôn khớp một-một với số hàng — lệch một bậc ở đây là sắp nhầm cả bảng.
            while keys.count < end - firstRow { keys.append("") }
            row = end
        }

        let numbers = numericKeys(keys)
        // Cột chữ: bẻ khóa thành cụm MỘT lần cho mỗi hàng, thay vì so sánh theo locale ở mỗi
        // lần đối chiếu. Sắp một triệu hàng là khoảng hai chục triệu lần đối chiếu, và
        // `localizedStandardCompare` ở mỗi lần đo được **9,8 giây**. Bẻ trước là n lần thay vì
        // n·log n lần.
        let chunked = numbers == nil ? keys.map(textKey) : []
        let ascending = direction == .ascending

        let sorted = Array(0 ..< keys.count).sorted { left, right in
            let emptyLeft = keys[left].isEmpty
            let emptyRight = keys[right].isEmpty
            if emptyLeft != emptyRight { return emptyRight }
            if emptyLeft { return left < right }

            var comparison: ComparisonResult
            if let numbers {
                comparison = numbers[left] == numbers[right]
                    ? .orderedSame
                    : (numbers[left] < numbers[right] ? .orderedAscending : .orderedDescending)
            } else {
                comparison = chunked[left] == chunked[right]
                    ? .orderedSame
                    : (chunked[left] < chunked[right] ? .orderedAscending : .orderedDescending)
                // Khóa đã bỏ dấu và bỏ hoa/thường, nên "Ất" và "At" hòa nhau ở bước trên. Chỉ
                // những cặp hòa ấy mới cần so theo locale — hiếm, nên không ảnh hưởng thời gian.
                if comparison == .orderedSame {
                    comparison = keys[left].localizedStandardCompare(keys[right])
                }
            }
            // Hòa thì giữ THỨ TỰ FILE. `sort` của Swift không hứa ổn định, nên phải tự chốt:
            // sắp lại cùng một cột hai lần mà bảng nhảy lung tung thì người dùng tưởng dữ
            // liệu đổi.
            if comparison == .orderedSame { return left < right }
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        return Order(
            column: column, direction: direction, rows: sorted.map { $0 + firstRow }
        )
    }

    // MARK: - Khóa sắp xếp văn bản

    private static let vietnamese = Locale(identifier: "vi_VN")

    /// Bề rộng đệm cho một cụm chữ số. Đủ cho mọi số nguyên 64 bit.
    private static let digitPadding = 19

    /// Biến một giá trị thành khóa mà phép so CHUỖI THUẦN cho ra đúng thứ tự mong đợi.
    ///
    /// Hai việc, gộp vào một chuỗi:
    ///
    ///  - **Bỏ dấu, bỏ hoa/thường theo tiếng Việt**, để "Ất" xếp cạnh "An" chứ không rơi xuống
    ///    sau chữ z. So theo mã Unicode thô sẽ đẩy mọi tên có dấu xuống cuối bảng — trên một
    ///    sản phẩm dùng tiếng Việt thì đó là lỗi ai cũng thấy ngay.
    ///  - **Đệm 0 cho cụm chữ số**, để "M9" đứng trước "M10". So nguyên chuỗi sẽ cho "M10"
    ///    trước "M9" vì '1' < '9'.
    ///
    /// Vì sao là MỘT chuỗi chứ không phải mảng cụm: bản trước dựng cho mỗi hàng một mảng enum
    /// chứa String, tức vài triệu lần cấp phát, và đo được 5,2 giây cho một triệu hàng — trong
    /// khi bản thân phép bỏ dấu chỉ tốn 845 ms. Chi phí nằm ở cấu trúc dữ liệu, không nằm ở
    /// công việc thật.
    ///
    /// Giới hạn đã biết: cụm chữ số dài hơn 19 chữ số không được đệm, nên hai cụm như thế so
    /// với nhau theo văn bản. Số thật thì đi đường cột số, nên chỗ này chỉ ảnh hưởng mã chứng
    /// từ dài bất thường.
    private static func textKey(_ value: String) -> String {
        // Đường tắt ASCII: mã chứng từ, mã khách hàng — thứ hay gặp nhất ở cột có nhiều giá
        // trị khác nhau. `lowercased()` trên ASCII nhanh hơn `folding` khoảng năm mươi lần.
        let base: String = value.utf8.allSatisfy { $0 < 0x80 }
            ? value.lowercased()
            : value.folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: vietnamese
            )

        guard base.utf8.contains(where: { $0 >= 0x30 && $0 <= 0x39 }) else { return base }

        var out = ""
        out.reserveCapacity(base.utf8.count + digitPadding)
        var digits = ""

        func flushDigits() {
            guard !digits.isEmpty else { return }
            let trimmed = digits.drop { $0 == "0" }
            if trimmed.count <= digitPadding {
                out += String(repeating: "0", count: digitPadding - trimmed.count)
                out += trimmed
            } else {
                out += trimmed
            }
            digits = ""
        }

        for character in base {
            if character.isASCII, character.isNumber {
                digits.append(character)
            } else {
                flushDigits()
                out.append(character)
            }
        }
        flushDigits()
        return out
    }

    /// Cột là số khi MỌI ô không rỗng đều đọc được thành số; ngược lại `nil`.
    ///
    /// Vì sao không dùng `localizedStandardCompare` cho tất cả: nó so theo từng cụm chữ số,
    /// nên "1.5" thành (1, 5) và "1.25" thành (1, 25), rồi kết luận 1,5 < 1,25. Đúng cho tên
    /// file, sai cho tiền.
    private static func numericKeys(_ keys: [String]) -> [Double]? {
        var out = [Double](repeating: 0, count: keys.count)
        var sawNumber = false
        for (index, key) in keys.enumerated() {
            if key.isEmpty { continue }
            guard let value = Double(key.trimmingCharacters(in: .whitespaces)) else { return nil }
            out[index] = value
            sawNumber = true
        }
        return sawNumber ? out : nil
    }

    // MARK: - Ghi thứ tự vào file

    /// Viết lại vùng dữ liệu theo `order` — MỘT `TextEdit`, tức một bước undo (FR-CORE-004).
    ///
    /// Chi phí bộ nhớ là một bản sao vùng dữ liệu. Không tránh được: sắp xếp vật lý là hoán vị
    /// mọi hàng, nên không có phép sửa tại chỗ nào rẻ hơn.
    ///
    /// Hàng tiêu đề giữ NGUYÊN CHỖ. Ký tự xuống dòng lấy theo đúng thứ file đang dùng, chứ
    /// không mặc định `\n`: đổi cả file CRLF sang LF khi người dùng chỉ bấm "sắp xếp" là sửa
    /// thứ họ không yêu cầu, và với Git thì đó là toàn bộ file bị đánh dấu thay đổi.
    public static func applyEdits(
        _ order: Order,
        hasHeader: Bool,
        index: CSVRowIndex,
        in buffer: TextBuffer,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [TextEdit] {
        guard !order.rows.isEmpty else { return [] }
        let firstRow = hasHeader ? 1 : 0
        guard let regionStart = index.rowStart(firstRow, in: buffer) else { return [] }

        let terminator = lineTerminator(index: index, in: buffer)
        // Vùng dữ liệu gốc có kết thúc bằng ký tự xuống dòng không? Nếu không thì bản mới cũng
        // không được thêm — thêm một dòng trống vào cuối file là thay đổi ngoài yêu cầu.
        let endsWithNewline = buffer.count > 0
            && buffer.bytes(in: (buffer.count - 1) ..< buffer.count)[0] == UInt8(ascii: "\n")

        // Định vị MỌI hàng bằng một lượt quét tuần tự, rồi mới ghép theo thứ tự mới.
        //
        // Bản đầu hỏi chỉ mục từng hàng một trong vòng lặp hoán vị. Chỉ mục là chỉ mục THƯA,
        // nên mỗi câu hỏi phân tích lại tới 64 hàng — với một triệu hàng, đo được **16,9
        // giây**. Thứ tự mới là hoán vị nên không thể hỏi theo khối; đường ra là quét một lượt
        // và nhớ sẵn hai đầu của từng hàng. Tốn 16 MB tạm cho một triệu hàng, chỉ trong lúc ghi.
        var lowerBounds = [Int](); var upperBounds = [Int]()
        lowerBounds.reserveCapacity(index.rowCount)
        upperBounds.reserveCapacity(index.rowCount)
        try CSVEngine.forEachRow(in: buffer, dialect: index.dialect, cancelToken: cancelToken) { row in
            lowerBounds.append(row.first?.range.lowerBound ?? 0)
            upperBounds.append(row.last?.range.upperBound ?? 0)
            return true
        }

        var out: [UInt8] = []
        out.reserveCapacity(buffer.count - regionStart)

        for (position, row) in order.rows.enumerated() {
            if position % 4_096 == 0 { try cancelToken.check() }
            // Hàng rỗng (dòng trắng giữa dữ liệu) vẫn phải giữ chỗ: bỏ nó đi là xóa một dòng
            // của người dùng nhân danh việc sắp xếp.
            guard row < lowerBounds.count, upperBounds[row] >= lowerBounds[row] else { continue }
            out.append(contentsOf: buffer.bytes(in: lowerBounds[row] ..< upperBounds[row]))
            if position < order.rows.count - 1 || endsWithNewline {
                out.append(contentsOf: terminator)
            }
        }

        return [TextEdit(range: regionStart ..< buffer.count, bytes: out)]
    }

    /// Ký tự xuống dòng mà file đang dùng, đọc từ khoảng giữa hai hàng đầu.
    private static func lineTerminator(index: CSVRowIndex, in buffer: TextBuffer) -> [UInt8] {
        let lf: [UInt8] = [0x0A]
        guard index.rowCount > 1 else { return lf }
        let first = index.fields(ofRow: 0, in: buffer)
        guard let end = first.last?.range.upperBound,
              let next = index.rowStart(1, in: buffer), next > end else { return lf }
        let gap = buffer.bytes(in: end ..< Swift.min(next, end + 2))
        return gap == [0x0D, 0x0A] ? [0x0D, 0x0A] : lf
    }
}
