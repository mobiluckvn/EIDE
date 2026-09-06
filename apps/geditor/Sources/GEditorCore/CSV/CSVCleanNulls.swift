import Foundation

/// Thứ được coi là "không có dữ liệu" (FR-CLN-002).
///
/// Danh sách sửa được, và phải sửa được: `-` là giá trị thiếu trong bảng kế toán nhưng là dấu
/// trừ trong cột số, `0` là giá trị thật ở mọi nơi. Ứng dụng không có cách nào tự biết, nên nó
/// hỏi thay vì đoán.
public struct CSVNullSpec: Equatable, Sendable {
    /// So khớp KHÔNG phân biệt hoa thường, sau khi cắt khoảng trắng hai đầu.
    ///
    /// `private(set)`: `maxPlaceholderBytes` được tính một lần trong `init` và sẽ lệch nếu ai
    /// đó thêm chuỗi vào đây sau lưng. Muốn đổi danh sách thì dựng một spec mới.
    public private(set) var placeholders: Set<String>
    /// Ô rỗng có tính là thiếu không. Gần như luôn có, nhưng vẫn để mở.
    public var treatEmptyAsNull: Bool

    /// Độ dài chuỗi đại diện dài nhất, tính theo byte UTF-8 — cửa thoát sớm của `isNull`.
    private let maxPlaceholderBytes: Int

    public init(placeholders: Set<String>, treatEmptyAsNull: Bool = true) {
        let lowered = Set(placeholders.map { $0.lowercased() })
        self.placeholders = lowered
        self.treatEmptyAsNull = treatEmptyAsNull
        self.maxPlaceholderBytes = lowered.reduce(0) { max($0, $1.utf8.count) }
    }

    /// Những chuỗi mà công cụ xuất dữ liệu hay để lại khi không có giá trị.
    public static let `default` = CSVNullSpec(
        placeholders: ["n/a", "na", "null", "nil", "none", "-", "--", "?", "#n/a"]
    )

    public func isNull(_ value: String) -> Bool {
        // Ô dài hơn mọi chuỗi đại diện, lại không có gì giống khoảng trắng ở hai đầu, thì không
        // thể là ô thiếu — và đó là gần như mọi ô trong một file thật.
        //
        // Cửa thoát sớm này không phải tối ưu vặt: hàm chạy trên TỪNG Ô của cả bảng, mà
        // `trimmingCharacters` cộng `lowercased()` dựng hai chuỗi mới mỗi lần gọi. Đo trên
        // bảng 100k × 10 (bản release): riêng phép kiểm này tốn 0,16s trong tổng 1,02s — nhiều
        // gấp bốn lần việc phân tích CSV.
        let utf8 = value.utf8
        if utf8.count > maxPlaceholderBytes,
           let first = utf8.first, let last = utf8.last,
           !mayBeSpace(first), !mayBeSpace(last) {
            return false
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return treatEmptyAsNull }
        return placeholders.contains(trimmed.lowercased())
    }

    /// Bản đọc thẳng trên BYTE, cho những phép quét đi qua từng ô của cả bảng.
    ///
    /// Chuỗi chỉ được dựng khi ô NGẮN bằng cỡ một chuỗi đại diện — tức là gần như không bao
    /// giờ trong dữ liệu thật.
    public func isNull(_ bytes: UnsafeBufferPointer<UInt8>) -> Bool {
        if bytes.isEmpty { return treatEmptyAsNull }
        if bytes.count > maxPlaceholderBytes,
           !mayBeSpace(bytes[0]), !mayBeSpace(bytes[bytes.count - 1]) {
            return false
        }
        return isNull(String(decoding: bytes, as: UTF8.self))
    }

    /// Byte này có thể mở đầu (hoặc kết thúc) một ký tự trắng không.
    ///
    /// Bảo thủ có chủ ý: `0xC2` `0xE2` `0xEF` là byte dẫn của NBSP, của nhóm khoảng trắng
    /// `U+2000…206F` và của `U+FEFF`. Nhận nhầm vài ô chỉ tốn thêm một phép kiểm đầy đủ, còn
    /// bỏ sót thì "\u{00A0}N/A" lặng lẽ thôi được coi là ô thiếu — một thay đổi hành vi mà
    /// không ai đọc thấy trong một cửa thoát sớm.
    private func mayBeSpace(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x20, 0x09, 0x0A, 0x0D, 0xC2, 0xE2, 0xEF: return true
        default: return false
        }
    }
}

/// Hướng điền giá trị thiếu từ ô lân cận.
public enum CSVFillDirection: String, Equatable, Sendable {
    case forward
    case backward

    public var displayName: String {
        self == .forward ? "điền xuôi (lấy giá trị phía trên)" : "điền ngược (lấy giá trị phía dưới)"
    }
}

extension CSVClean {

    /// Kết quả khảo sát giá trị thiếu của một cột.
    public struct NullScan: Equatable, Sendable {
        public let nullCells: Int
        /// Đếm theo từng chuỗi đại diện, để người dùng nhìn thấy danh sách thật của FILE này
        /// chứ không phải danh sách mặc định của ứng dụng. Ô rỗng đếm dưới khóa `""`.
        public let byPlaceholder: [String: Int]
        /// Mười ô thiếu đầu tiên, đủ để bấm tới xem.
        public let firstCells: [CellRef]
        public let rowsScanned: Int
        public let partial: Bool

        public var summary: String {
            guard nullCells > 0 else { return "Không có ô thiếu trong \(rowsScanned) hàng" }
            let kinds = byPlaceholder
                .sorted { $0.value > $1.value }
                .prefix(4)
                .map { "\($0.key.isEmpty ? "ô rỗng" : "«\($0.key)»") \($0.value)" }
                .joined(separator: " · ")
            return "\(nullCells) ô thiếu — \(kinds)"
        }
    }

    /// Đếm giá trị thiếu trong một cột (vế (a) của NFR-CLN-02: số liệu TRƯỚC khi chạy).
    public static func scanNulls(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> NullScan {
        var count = 0, rows = 0
        var byPlaceholder: [String: Int] = [:]
        var firstCells: [CellRef] = []

        try forEachCell(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value, rowIndex, range in
            rows += 1
            guard spec.isNull(value) else { return true }
            count += 1
            let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            byPlaceholder[key, default: 0] += 1
            if firstCells.count < sampleLimit {
                firstCells.append(CellRef(
                    rowIndex: rowIndex, column: column, offset: range.lowerBound, value: value
                ))
            }
            return true
        }

        return NullScan(
            nullCells: count, byPlaceholder: byPlaceholder, firstCells: firstCells,
            rowsScanned: rows, partial: maxRows > 0 && rows >= maxRows
        )
    }

    /// Điền một giá trị mặc định vào mọi ô thiếu của cột (FR-CLN-002).
    public static func fillNulls(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        with replacement: String,
        spec: CSVNullSpec = .default,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Plan {
        try plan(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value in
            guard spec.isNull(value) else { return .skip }
            return value == replacement ? .alreadyClean : .changed(replacement)
        }
    }

    /// Điền ô thiếu bằng giá trị của ô lân cận, xuôi hoặc ngược (FR-CLN-002).
    ///
    /// Không đi qua khuôn `plan(column:transform:)` được: điền XUÔI cần nhớ ô trước, còn điền
    /// NGƯỢC thì lúc đọc tới ô thiếu vẫn chưa biết giá trị sẽ điền. Bản này giữ danh sách ô
    /// thiếu đang chờ và chốt chúng khi gặp giá trị thật — một lượt quét, và bộ nhớ chỉ bằng
    /// chuỗi ô thiếu LIÊN TIẾP dài nhất chứ không phải cả cột.
    ///
    /// Ô thiếu ở đầu cột (điền xuôi) hoặc ở cuối cột (điền ngược) không có gì để lấy, nên
    /// chúng được để nguyên và vào danh sách `unparsable` — điền bừa một giá trị vào đó là bịa
    /// dữ liệu.
    public static func fillNulls(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        direction: CSVFillDirection,
        spec: CSVNullSpec = .default,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Plan {
        guard column >= 0 else { return emptyPlan }

        var edits: [TextEdit] = []
        var samples: [Sample] = []
        var unparsable: [CellRef] = []
        var changed = 0
        var rows = 0

        /// Ô thiếu đang chờ một giá trị (chỉ dùng khi điền ngược).
        var pending: [(CellRef, Range<Int>)] = []
        var lastValue: String?

        func fill(_ cell: CellRef, _ range: Range<Int>, with value: String) {
            edits.append(TextEdit(range: range, text: CSVEngine.escape(value, dialect: dialect)))
            changed += 1
            if samples.count < sampleLimit {
                samples.append(Sample(rowIndex: cell.rowIndex, before: cell.value, after: value))
            }
        }

        try forEachCell(
            column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
            maxRows: maxRows, cancelToken: cancelToken
        ) { value, rowIndex, range in
            rows += 1
            let cell = CellRef(
                rowIndex: rowIndex, column: column, offset: range.lowerBound, value: value
            )

            guard spec.isNull(value) else {
                lastValue = value
                // Điền ngược: giá trị vừa gặp là thứ mà cả chuỗi ô thiếu phía trên đang chờ.
                for (waiting, waitingRange) in pending { fill(waiting, waitingRange, with: value) }
                pending.removeAll(keepingCapacity: true)
                return true
            }

            switch direction {
            case .forward:
                if let lastValue {
                    fill(cell, range, with: lastValue)
                } else {
                    unparsable.append(cell)   // đầu cột, không có gì phía trên
                    if samples.count < sampleLimit {
                        samples.append(Sample(rowIndex: rowIndex, before: value, after: nil))
                    }
                }
            case .backward:
                pending.append((cell, range))
            }
            return true
        }

        // Điền ngược mà tới cuối cột vẫn còn ô chờ: không có gì phía dưới để lấy.
        for (waiting, _) in pending {
            unparsable.append(waiting)
            if samples.count < sampleLimit {
                samples.append(Sample(rowIndex: waiting.rowIndex, before: waiting.value, after: nil))
            }
        }

        return Plan(
            edits: edits,
            report: Report(
                cellsChanged: changed, cellsAlreadyClean: 0, unparsable: unparsable,
                rowsScanned: rows, partial: maxRows > 0 && rows >= maxRows
            ),
            samples: samples
        )
    }

    // MARK: - Xóa hàng

    /// Kế hoạch xóa HÀNG — khác kế hoạch sửa ô, nên có kiểu riêng.
    public struct RowPlan: Equatable {
        public let edits: [TextEdit]
        public let rowsAffected: Int
        public let rowsScanned: Int
        public let partial: Bool
        /// Chỉ số các hàng đầu tiên sẽ biến mất, để bảng đánh dấu trước khi người dùng đồng ý.
        public let sampleRows: [Int]

        public var summary: String {
            let scope = partial ? "trong \(rowsScanned) hàng đầu" : "trên \(rowsScanned) hàng"
            return "\(rowsAffected) hàng bị xóa \(scope)"
        }
    }

    /// Xóa những hàng có ô thiếu ở cột `column` (FR-CLN-002).
    ///
    /// Phạm vi xóa của mỗi hàng là từ đầu hàng ấy tới ĐẦU hàng kế tiếp, nên ký tự xuống dòng đi
    /// theo hàng bị xóa và các hàng còn lại không dính vào nhau. Hàng CUỐI tài liệu xóa tới hết
    /// buffer — dấu xuống dòng của hàng trước nó nằm ngoài phạm vi ấy, nên file vẫn kết thúc
    /// bằng một dấu xuống dòng như trước.
    public static func deleteRowsWithNull(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> RowPlan {
        guard column >= 0 else {
            return RowPlan(edits: [], rowsAffected: 0, rowsScanned: 0, partial: false, sampleRows: [])
        }

        var edits: [TextEdit] = []
        var sampleRows: [Int] = []
        var rowNumber = 0
        var dataRows = 0
        var affected = 0
        var partial = false
        /// Hàng đang chờ biết biên phải của nó: (đầu hàng, số hàng).
        var doomed: (start: Int, index: Int)?

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }
            let start = row.first?.range.lowerBound ?? 0

            // Hàng trước đã bị kết án: giờ mới biết nó kết thúc ở đâu.
            if let pending = doomed {
                edits.append(TextEdit(range: pending.start ..< start, bytes: []))
                doomed = nil
            }

            if hasHeader, rowNumber == 0 { return true }
            dataRows += 1

            if column < row.count {
                let value = String(
                    decoding: CSVEngine.unescape(buffer.bytes(in: row[column].range), dialect: dialect),
                    as: UTF8.self
                )
                if spec.isNull(value) {
                    doomed = (start, rowNumber)
                    affected += 1
                    if sampleRows.count < sampleLimit { sampleRows.append(rowNumber) }
                }
            } else {
                // Hàng ngắn hơn cả cột đang xét: ô ấy KHÔNG TỒN TẠI, mà không tồn tại thì cũng
                // là không có dữ liệu. Xóa nó, đúng như ô rỗng.
                doomed = (start, rowNumber)
                affected += 1
                if sampleRows.count < sampleLimit { sampleRows.append(rowNumber) }
            }

            if maxRows > 0, dataRows >= maxRows { partial = true; return false }
            return true
        }

        // Dừng sớm thì hàng bị kết án cuối cùng CHƯA biết biên phải, nên nó được đếm mà không
        // sinh sửa đổi. Bản xem trước chỉ đọc số liệu; `edits` của một kế hoạch `partial`
        // không phải thứ để áp.
        if let pending = doomed, !partial {
            edits.append(TextEdit(range: pending.start ..< buffer.count, bytes: []))
        }

        return RowPlan(
            edits: edits, rowsAffected: affected, rowsScanned: dataRows,
            partial: partial, sampleRows: sampleRows
        )
    }
}
