import Foundation

/// Chỉ mục hàng LOGIC của một tài liệu CSV (FR-CSV-403).
///
/// Table view phải trả lời được "hàng thứ 812.394 nằm ở đâu" trong vài micro-giây, vì
/// `NSTableView` hỏi đúng những hàng đang nhìn thấy và hỏi lại mỗi lần cuộn. Phân tích lại từ
/// đầu file cho mỗi câu hỏi là bất khả thi; giữ sẵn mọi hàng trong RAM cũng vậy.
///
/// Cách giải: **chỉ mục thưa**. Chỉ ghi offset của mỗi hàng thứ 64; hàng nằm giữa thì phân
/// tích lại từ mốc gần nhất — nhiều nhất 63 hàng, tính bằng micro-giây. Chi phí bộ nhớ là
/// 8 byte cho mỗi 64 hàng: một file 10 triệu hàng tốn 1,25 MB thay vì 80 MB.
///
/// Vì sao không đánh chỉ mục theo DÒNG VẬT LÝ (thứ `TextBuffer` đã có sẵn): field bọc ngoặc
/// chứa được xuống dòng, nên một hàng CSV có thể trải trên nhiều dòng. Đánh theo dòng vật lý
/// thì mọi hàng sau field ấy đều lệch — và bảng lệch hàng là hỏng dữ liệu chứ không phải hỏng
/// hiển thị, vì người dùng sẽ sửa ô dựa vào cái mình nhìn thấy.
///
/// Chỉ mục KHÔNG giữ tham chiếu tới buffer: mọi hàm tra cứu nhận buffer làm tham số. Buffer
/// đổi thì mọi offset ở đây đều sai, và một tham chiếu giữ sẵn chỉ khiến cái sai ấy im lặng.
/// Sửa tài liệu thì dựng lại chỉ mục.
public final class CSVRowIndex {

    /// Số hàng giữa hai mốc. 64 là chỗ cân bằng: 8 byte cho 64 hàng, và tệ nhất phân tích lại
    /// 63 hàng cho một lần hỏi.
    public static let anchorStride = 64

    public let dialect: CSVDialect

    /// Số hàng LOGIC.
    public private(set) var rowCount = 0

    /// Số cột của hàng ĐẦU TIÊN — số cột "chuẩn" theo cách hiểu của FR-CSV-405.
    public private(set) var columnCount = 0

    /// Số cột LỚN NHẤT gặp trong cả file.
    ///
    /// Bảng phải dựng theo con số này chứ không theo `columnCount`. Một hàng thừa cột mà bảng
    /// chỉ có `columnCount` cột thì phần thừa BIẾN MẤT khỏi màn hình — người dùng không thấy
    /// dữ liệu ấy, và thứ họ không thấy thì họ sẽ vô tình xoá.
    public private(set) var widestRowColumnCount = 0

    /// Offset đầu hàng của hàng 0, 64, 128, …
    private var anchors: [Int] = []

    private init(dialect: CSVDialect) {
        self.dialect = dialect
    }

    // MARK: - Dựng chỉ mục

    /// Quét toàn tài liệu MỘT lần để dựng chỉ mục.
    ///
    /// Đây là chỗ tốn thời gian duy nhất; sau đó mọi câu hỏi đều rẻ. Gọi nó ở luồng nền —
    /// một file rất lớn mất vài giây, và làm việc ấy trên luồng chính là treo ứng dụng.
    public static func build(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        cancelToken: CancelToken = CancelToken()
    ) throws -> CSVRowIndex {
        let index = CSVRowIndex(dialect: dialect)
        var rowNumber = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            if rowNumber % anchorStride == 0 {
                index.anchors.append(row.first?.range.lowerBound ?? 0)
            }
            if rowNumber == 0 { index.columnCount = row.count }
            index.widestRowColumnCount = Swift.max(index.widestRowColumnCount, row.count)
            rowNumber += 1
            return true
        }

        index.rowCount = rowNumber
        return index
    }

    // MARK: - Tra cứu

    /// Offset byte đầu hàng `row`, hoặc `nil` nếu ngoài phạm vi.
    ///
    /// Dùng để đưa con nháy về đúng chỗ khi chuyển Bảng → Văn bản.
    public func rowStart(_ row: Int, in buffer: TextBuffer) -> Int? {
        fields(ofRow: row, in: buffer).first?.range.lowerBound
    }

    /// Các field của một hàng.
    public func fields(ofRow row: Int, in buffer: TextBuffer) -> [CSVField] {
        rows(row ..< (row + 1), in: buffer).first ?? []
    }

    /// Các field của một DÃY hàng liên tiếp — một lần phân tích cho cả khối.
    ///
    /// Đây là đường mà bảng thực sự dùng: `NSTableView` hỏi khoảng bốn mươi hàng đang nhìn
    /// thấy. Hỏi từng hàng một sẽ phân tích lại cùng một khối bốn mươi lần.
    public func rows(_ range: Range<Int>, in buffer: TextBuffer) -> [[CSVField]] {
        let lower = Swift.min(Swift.max(0, range.lowerBound), rowCount)
        let upper = Swift.min(Swift.max(lower, range.upperBound), rowCount)
        guard upper > lower else { return [] }

        var out: [[CSVField]] = []
        var row = lower
        while row < upper {
            let block = row / Self.anchorStride
            guard block < anchors.count else { break }
            let blockFirst = block * Self.anchorStride
            let need = Swift.min(upper, blockFirst + Self.anchorStride) - blockFirst
            let parsed = parseRows(from: anchors[block], count: need, in: buffer)
            let skip = row - blockFirst
            guard parsed.count > skip else { break }
            out.append(contentsOf: parsed[skip...])
            row = blockFirst + parsed.count
        }
        return out
    }

    /// Giá trị THẬT của từng ô trên một hàng (đã bỏ dấu bọc, đã giải `""`).
    public func values(ofRow row: Int, in buffer: TextBuffer) -> [String] {
        values(of: fields(ofRow: row, in: buffer), in: buffer)
    }

    /// Giá trị thật của một dãy field đã định vị.
    public func values(of fields: [CSVField], in buffer: TextBuffer) -> [String] {
        fields.map { field in
            String(
                decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
                as: UTF8.self
            )
        }
    }

    /// Hàng chứa offset byte này — dùng để giữ vị trí khi chuyển Văn bản → Bảng.
    ///
    /// Chuyển chế độ mà nhảy về đầu file thì người dùng mất chỗ đang làm; với file một triệu
    /// hàng, tìm lại chỗ ấy là việc của vài phút.
    public func rowNumber(containingOffset offset: Int, in buffer: TextBuffer) -> Int {
        guard rowCount > 0, !anchors.isEmpty else { return 0 }
        guard offset > anchors[0] else { return 0 }

        // Mốc cuối cùng nằm tại hoặc trước `offset`.
        var low = 0
        var high = anchors.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if anchors[mid] <= offset { low = mid } else { high = mid - 1 }
        }

        let blockFirst = low * Self.anchorStride
        let parsed = parseRows(from: anchors[low], count: Self.anchorStride, in: buffer)
        var answer = blockFirst
        for (step, row) in parsed.enumerated() {
            guard let start = row.first?.range.lowerBound, start <= offset else { break }
            answer = blockFirst + step
        }
        return Swift.min(answer, rowCount - 1)
    }

    // MARK: - Phân tích lại một khối

    /// Phân tích `count` hàng TRỌN VẸN kể từ `offset`, trả về offset TOÀN CỤC.
    private func parseRows(from offset: Int, count: Int, in buffer: TextBuffer) -> [[CSVField]] {
        guard count > 0, offset < buffer.count else { return [] }

        var window = 1 << 16
        while true {
            let end = Swift.min(offset + window, buffer.count)
            let bytes = buffer.bytes(in: offset ..< end)
            // Xin THỪA một hàng. `parse` đóng một hàng vì hai lý do khác hẳn nhau: gặp ký tự
            // xuống dòng (hàng trọn vẹn), hoặc hết byte (hàng bị cắt). Từ số hàng trả về không
            // phân biệt được hai lý do ấy — nên xin n+1 và chỉ tin n hàng đầu.
            //
            // Bản đầu tin luôn `parsed.count >= count`. Bài "hàng dài hơn cửa sổ" bắt được:
            // một ô 200.000 ký tự trả về cụt còn 65.530, và cụt lặng lẽ ở tầng này thì Table
            // view hiện dữ liệu thiếu mà không có dấu hiệu gì.
            let parsed = CSVEngine.parse(bytes, dialect: dialect, maxRows: count + 1)
            let reachedEnd = end == buffer.count
            let complete = reachedEnd ? parsed.count : Swift.max(0, parsed.count - 1)

            if complete >= count || reachedEnd {
                return parsed.prefix(count).map { row in
                    row.map {
                        CSVField(
                            range: ($0.range.lowerBound + offset) ..< ($0.range.upperBound + offset),
                            isQuoted: $0.isQuoted
                        )
                    }
                }
            }
            window *= 2
        }
    }
}
