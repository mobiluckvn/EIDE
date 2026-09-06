import Foundation

/// Làm sạch và chuẩn hóa dữ liệu theo CỘT (FR-CLN).
///
/// Cùng quy ước với `CSVOps`: trả về `[TextEdit]`, không tự sửa buffer — một lượt chuẩn hóa là
/// MỘT bước undo (FR-CORE-004, NFR-CLN-02b).
///
/// Bất biến của cả cụm (NFR-CLN-02): mọi thao tác phải xem trước được, hoàn tác được một bước,
/// và báo cáo lại sau khi chạy. Không hàm nào ở đây tự áp; chúng dựng KẾ HOẠCH để người dùng
/// nhìn rồi mới quyết.
///
/// Nguyên tắc xuyên suốt: **không đoán**. Ô nào không đọc chắc chắn được thì đánh dấu và để
/// nguyên, chứ không suy diễn. Chuẩn hóa sai một cột ngày là hỏng dữ liệu ở dạng người dùng
/// gần như không thể phát hiện — con số vẫn đúng khuôn, chỉ là đã thành ngày khác.
public enum CSVClean {

    // MARK: - Kiểu chung

    /// Một ô đã định vị, đủ để bảng nhảy tới và tô đỏ.
    public struct CellRef: Equatable, Sendable {
        /// Số hàng LOGIC, đếm từ 0 — cùng hệ với `CSVRowIndex` và `CSVIssue.rowIndex`.
        public let rowIndex: Int
        public let column: Int
        /// Offset byte của ô — đủ để đưa con nháy tới nơi ở chế độ văn bản.
        public let offset: Int
        public let value: String

        public init(rowIndex: Int, column: Int, offset: Int, value: String) {
            self.rowIndex = rowIndex
            self.column = column
            self.offset = offset
            self.value = value
        }
    }

    /// Một dòng của bảng xem trước "trước → sau".
    public struct Sample: Equatable, Sendable {
        public let rowIndex: Int
        public let before: String
        /// `nil` = không suy luận được; UI đánh dấu đỏ chứ không hiện giá trị đoán.
        public let after: String?
    }

    /// Báo cáo sau (hoặc trước) khi chạy — vế (a) và (c) của NFR-CLN-02.
    public struct Report: Equatable, Sendable {
        /// Số ô sẽ đổi giá trị.
        public let cellsChanged: Int
        /// Số ô đã đúng dạng đích từ trước, không phải đụng tới.
        public let cellsAlreadyClean: Int
        /// Ô không suy luận được — để nguyên và đánh dấu.
        public let unparsable: [CellRef]
        /// Số hàng đã quét. Với bản xem trước, đây là số hàng của MẪU chứ không phải cả file.
        public let rowsScanned: Int
        /// Đã dừng sớm vì `maxRows`, nên các con số trên chỉ đúng trong phạm vi mẫu.
        public let partial: Bool

        public var summary: String {
            var parts = ["\(cellsChanged) ô đổi"]
            if cellsAlreadyClean > 0 { parts.append("\(cellsAlreadyClean) ô đã đúng dạng") }
            if !unparsable.isEmpty { parts.append("\(unparsable.count) ô không đọc được") }
            let scope = partial ? "trong \(rowsScanned) hàng đầu" : "trên \(rowsScanned) hàng"
            return parts.joined(separator: " · ") + " " + scope
        }
    }

    /// Kế hoạch chuẩn hóa: sửa gì, đổi bao nhiêu, mười dòng mẫu để nhìn.
    ///
    /// Bản xem trước và bản áp thật dùng CHUNG hàm sinh ra thứ này, chỉ khác `maxRows`. Viết
    /// riêng một đường rút gọn cho ô xem trước là cách chắc chắn để nó nói dối đúng vào lúc
    /// người dùng tin nó — đã bị đúng một lần ở sheet chuyển đổi (FR-CSV-406).
    /// Không khai `Sendable`: `TextEdit` chưa phải `Sendable`, và khai bừa ở đây chỉ đẩy lỗi
    /// sang chỗ khác. Kế hoạch dựng ở luồng nền rồi ÁP ở luồng chính là việc của chỗ gọi.
    public struct Plan: Equatable {
        public let edits: [TextEdit]
        public let report: Report
        public let samples: [Sample]

        public var isEmpty: Bool { edits.isEmpty }
    }

    /// Số dòng mẫu giữ lại cho bảng xem trước (UI/UX §6.2 — "bảng mẫu 10 dòng trước→sau").
    public static let sampleLimit = 10

    /// Kết quả đọc MỘT ô.
    public enum Outcome: Equatable, Sendable {
        /// Đã đúng dạng đích — không sinh sửa đổi nào.
        case alreadyClean
        case changed(String)
        /// Không đọc chắc chắn được: để nguyên, đánh dấu.
        case unparsable
        /// Không thuộc phạm vi thao tác (ô rỗng) — không đổi, cũng không phải lỗi.
        case skip
    }

    /// Bằng chứng về quy ước của một cột, rút từ chính dữ liệu của nó.
    ///
    /// Có bốn kết cục chứ không phải hai, vì "chắc chắn" và "không biết" chưa đủ: một cột có
    /// thể chứa lẫn hai quy ước (`conflicting`), và khi ấy áp một quy ước cho cả cột sẽ làm
    /// hỏng đúng những ô thuộc quy ước kia.
    public enum Evidence<Convention: Equatable & Sendable>: Equatable, Sendable {
        /// Dữ liệu tự nó chỉ ra quy ước — có ô chỉ đọc được một cách.
        case certain(Convention)
        /// Mọi ô đều đọc được cả hai cách. Phải HỎI, đúng một lần cho cả cột.
        case ambiguous
        /// Có ô chỉ đọc được cách này, ô khác chỉ đọc được cách kia.
        case conflicting
        /// Không có ô nào thuộc dạng đang xét.
        case none
    }

    // MARK: - Đường chung: áp một phép biến đổi lên một cột

    /// Dựng kế hoạch chuẩn hóa cho cột `column` bằng phép biến đổi `transform`.
    ///
    /// Mọi thao tác theo cột của FR-CLN đi qua đây, nên ba luật chung được giữ ở MỘT chỗ:
    /// bỏ qua hàng tiêu đề, bỏ qua hàng không có cột ấy, và chỉ sinh sửa đổi khi giá trị THỰC
    /// SỰ đổi. Luật thứ ba không phải chuyện nhỏ: viết lại một ô bằng đúng nội dung cũ vẫn
    /// chuẩn hóa cách bọc của nó, và với Git thì đó là cả file bị đánh dấu thay đổi ở những
    /// hàng người dùng không hề đụng tới (cùng bài học với `CSVOps.moveColumn`).
    ///
    /// - Parameter maxRows: 0 = cả tài liệu; số dương = chỉ bấy nhiêu hàng DỮ LIỆU, cho bản xem
    ///   trước. Khi dừng sớm, `report.partial` bật lên — "8.412 ô" và "8.412 ô trong mười hàng
    ///   đầu" là hai kết luận khác hẳn nhau.
    public static func plan(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken(),
        transform: (String) -> Outcome
    ) throws -> Plan {
        guard column >= 0 else { return emptyPlan }

        var edits: [TextEdit] = []
        var samples: [Sample] = []
        var unparsable: [CellRef] = []
        var changed = 0
        var alreadyClean = 0
        var rowNumber = 0
        var dataRows = 0
        var partial = false

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }
            if hasHeader, rowNumber == 0 { return true }
            guard column < row.count else { return true }

            let field = row[column]
            let value = String(
                decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
                as: UTF8.self
            )
            let rowIndex = rowNumber

            switch transform(value) {
            case .skip:
                break
            case .alreadyClean:
                alreadyClean += 1
            case .unparsable:
                unparsable.append(CellRef(
                    rowIndex: rowIndex, column: column,
                    offset: field.range.lowerBound, value: value
                ))
                if samples.count < sampleLimit {
                    samples.append(Sample(rowIndex: rowIndex, before: value, after: nil))
                }
            case let .changed(newValue):
                // Bọc lại khi cần: giá trị mới có thể chứa dấu phân tách (số kiểu Anh-Mỹ trong
                // file dùng dấu phẩy là đúng trường hợp ấy). Ghi thẳng sẽ tách ô thành hai và
                // làm lệch cả hàng.
                let escaped = CSVEngine.escape(newValue, dialect: dialect)
                edits.append(TextEdit(range: field.range, text: escaped))
                changed += 1
                if samples.count < sampleLimit {
                    samples.append(Sample(rowIndex: rowIndex, before: value, after: newValue))
                }
            }

            dataRows += 1
            if maxRows > 0, dataRows >= maxRows { partial = true; return false }
            return true
        }

        return Plan(
            edits: edits,
            report: Report(
                cellsChanged: changed, cellsAlreadyClean: alreadyClean,
                unparsable: unparsable, rowsScanned: dataRows, partial: partial
            ),
            samples: samples
        )
    }

    /// Duyệt giá trị từng ô của một cột, theo THỨ TỰ hàng.
    ///
    /// Dùng cho các bước khảo sát (đoán quy ước, đếm) và cho những thao tác mà khuôn `plan`
    /// không ôm được — điền xuôi/ngược cần biết ô lân cận, xóa hàng cần cả biên hàng.
    ///
    /// - Parameter body: nhận (giá trị, số hàng logic, phạm vi byte của ô); trả `false` để dừng.
    static func forEachCell(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool,
        maxRows: Int,
        cancelToken: CancelToken = CancelToken(),
        _ body: (String, Int, Range<Int>) throws -> Bool
    ) throws {
        var rowNumber = 0
        var dataRows = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }
            if hasHeader, rowNumber == 0 { return true }
            guard column < row.count else { return true }

            let field = row[column]
            let value = String(
                decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
                as: UTF8.self
            )
            guard try body(value, rowNumber, field.range) else { return false }

            dataRows += 1
            return maxRows <= 0 || dataRows < maxRows
        }
    }

    static let emptyPlan = Plan(
        edits: [],
        report: Report(
            cellsChanged: 0, cellsAlreadyClean: 0, unparsable: [], rowsScanned: 0, partial: false
        ),
        samples: []
    )
}
