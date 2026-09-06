import Foundation

/// Một thao tác sửa: thay `range` (tọa độ byte trước khi sửa) bằng `bytes`.
public struct TextEdit: Equatable {
    public var range: Range<Int>
    public var bytes: [UInt8]

    public init(range: Range<Int>, bytes: [UInt8]) {
        self.range = range
        self.bytes = bytes
    }

    public init(range: Range<Int>, text: String) {
        self.init(range: range, bytes: Array(text.utf8))
    }

    /// Xóa vùng `range`.
    public static func delete(_ range: Range<Int>) -> TextEdit {
        TextEdit(range: range, bytes: [])
    }

    /// Chèn tại `offset`.
    public static func insert(at offset: Int, text: String) -> TextEdit {
        TextEdit(range: offset ..< offset, text: text)
    }
}

/// Nguồn sự thật duy nhất của một tài liệu (SAD §2.2).
///
/// Table View CSV, minimap, preview... đều là projection của buffer này — không được
/// giữ bản sao nội dung riêng.
///
/// FR-CORE-004: lịch sử undo không giới hạn trong phiên; MỘT lời gọi `applyEdits`
/// = MỘT bước undo, bất kể sửa bao nhiêu vị trí. Đây là bất biến của toàn bộ sản phẩm:
/// mọi thao tác hàng loạt (sort, dedup, replace-all, macro, script) phải đi qua đây.
public final class TextBuffer {
    private struct AppliedOp {
        let originalRange: Range<Int>
        let writtenRange: Range<Int>
        let oldBytes: [UInt8]
        let newBytes: [UInt8]
    }

    private struct UndoGroup {
        let label: String
        /// Theo đúng thứ tự đã áp dụng (giảm dần theo offset).
        let ops: [AppliedOp]
    }

    private let table: PieceTable
    private var undoStack: [UndoGroup] = []

    /// Số bước undo đang có — cùng với `historyBranch` xác định "tài liệu đã đổi so với lúc lưu".
    public var undoDepth: Int { undoStack.count }

    /// Tăng mỗi khi lịch sử RẼ NHÁNH: người dùng undo về một điểm rồi sửa theo hướng khác,
    /// làm mất phần redo cũ.
    ///
    /// Chỉ dùng độ sâu undo là không đủ: undo về độ sâu 3 rồi sửa một thứ KHÁC lại cho độ sâu
    /// 4 y như trước, và tài liệu sẽ bị coi là "chưa đổi" dù nội dung đã khác. Đếm thêm số lần
    /// rẽ nhánh thì hai lịch sử khác nhau không thể trùng cả hai con số.
    public private(set) var historyBranch: Int = 0

    /// Tăng lên MỘT LẦN cho mỗi lần nội dung đổi, kể cả undo và redo.
    ///
    /// Dành cho những thứ nhớ tạm kết quả đọc buffer — chỉ mục JSON, danh sách ký hiệu — để
    /// biết bản nhớ của mình còn dùng được không. Không dùng `undoStack.count` được: undo làm
    /// nó GIẢM về đúng con số cũ, nên một bản nhớ dựng trước khi sửa sẽ trông như còn mới sau
    /// khi undo, trong khi nội dung đã khác. Một bộ đếm chỉ tăng thì không có chỗ nào trùng lại.
    public private(set) var revision: Int = 0

    /// Số hiệu DUY NHẤT của buffer này, không trùng với bất kỳ buffer nào khác trong cả phiên.
    ///
    /// # Vì sao không dùng `ObjectIdentifier`
    ///
    /// `ObjectIdentifier` là ĐỊA CHỈ ô nhớ, và địa chỉ được CẤP LẠI. Đóng một tab rồi mở tab
    /// khác thì buffer mới hoàn toàn có thể rơi đúng vào chỗ buffer cũ vừa nhả ra. Khi ấy mọi
    /// bản nhớ tạm khoá theo `(địa chỉ, revision)` đều trúng nhầm: `revision` đếm từ 0 trong
    /// TỪNG buffer, nên hai tài liệu cùng vừa mở đều mang revision 0.
    ///
    /// Đây không phải chuyện lý thuyết. Bộ tự kiểm trượt chập chờn khoảng 5% số lượt, ở bài
    /// "xuất kết quả JSONPath ra TAB MỚI": truy vấn chạy trên chỉ mục của một tài liệu ĐÃ ĐÓNG
    /// và trả về 0 kết quả. Với người dùng thật thì đó là kết quả truy vấn của một file khác —
    /// im lặng, và không có cách nào nhận ra từ màn hình.
    ///
    /// Một bộ đếm chỉ tăng thì không có chỗ nào cấp lại được.
    public let id: Int = TextBuffer.nextID()

    private static let idLock = NSLock()
    private static var idCounter = 0
    private static func nextID() -> Int {
        idLock.lock()
        defer { idLock.unlock() }
        idCounter += 1
        return idCounter
    }

    private var redoStack: [UndoGroup] = []

    /// Nhóm undo đang mở, nếu có (FR-CORE-004 cho macro — xem `beginUndoGroup`).
    private var openGroup: (label: String, ops: [AppliedOp])?

    public init(original: ByteSource) {
        self.table = PieceTable(original: original)
    }

    public convenience init(text: String) {
        self.init(original: MemoryByteSource(text))
    }

    public convenience init(contentsOfFile path: String) throws {
        self.init(original: try MappedFile(path: path))
    }

    // MARK: - Đọc

    public var count: Int { table.count }

    public func bytes(in range: Range<Int>) -> [UInt8] { table.bytes(in: range) }

    public func forEachChunk(_ body: (UnsafeRawBufferPointer) -> Void) { table.forEachChunk(body) }

    /// Số dòng — O(log n), đọc thẳng từ tổng hợp newline của cây piece.
    ///
    /// Trước PoC-B chỗ này dựng lại toàn bộ `LineIndex` sau mỗi nhóm sửa (O(n) mỗi lần), nên
    /// mỗi phím gõ trên file GB đều quét lại cả tài liệu. Nay cây giữ sẵn số '\n' của từng
    /// cây con, còn `NewlineBlockIndex` quy việc định vị trong một piece về một khối 64 KB.
    public var lineCount: Int { table.lineCount }

    /// Offset byte bắt đầu của dòng `line`.
    public func offset(ofLineStart line: Int) -> Int { table.offset(ofLineStart: line) }

    /// Số dòng (0-based) chứa `offset`.
    public func lineNumber(atOffset offset: Int) -> Int { table.lineNumber(atOffset: offset) }

    /// Vị trí (dòng, cột) theo byte — cột 0-based tính bằng byte, không phải grapheme.
    /// Status bar hiển thị cột theo ký tự nên phải quy đổi ở lớp trình bày (FR-CORE-018).
    public func position(atOffset offset: Int) -> (line: Int, byteColumn: Int) {
        let line = table.lineNumber(atOffset: offset)
        return (line, offset - table.offset(ofLineStart: line))
    }

    /// Phạm vi byte của dòng, đã bỏ CR/LF cuối dòng.
    public func contentRange(ofLine line: Int) -> Range<Int> {
        var range = table.lineRange(ofLine: line)
        var end = range.upperBound
        if end > range.lowerBound {
            let tail = table.bytes(in: max(range.lowerBound, end - 2) ..< end)
            if tail.last == UInt8(ascii: "\n") {
                end -= 1
                if tail.count >= 2 && tail[tail.count - 2] == UInt8(ascii: "\r") { end -= 1 }
            } else if tail.last == UInt8(ascii: "\r") {
                end -= 1
            }
        }
        range = range.lowerBound ..< end
        return range
    }

    /// Nội dung một dòng dưới dạng chuỗi (không gồm EOL).
    public func line(_ index: Int) -> String {
        String(decoding: table.bytes(in: contentRange(ofLine: index)), as: UTF8.self)
    }

    /// Toàn bộ nội dung. Chỉ dùng cho tài liệu nhỏ và test — cấm trên đường file lớn.
    public var text: String { table.utf8String }

    // MARK: - Sửa

    /// Áp dụng một loạt sửa đổi như MỘT bước undo (FR-CORE-004).
    ///
    /// - Các `range` phải không giao nhau và tính theo tọa độ TRƯỚC khi sửa.
    /// - Thứ tự truyền vào không quan trọng: hàm tự sắp xếp giảm dần theo offset
    ///   để các sửa đổi phía trước không làm lệch tọa độ của sửa đổi phía sau.
    public func applyEdits(_ edits: [TextEdit], label: String) {
        guard !edits.isEmpty else { return }

        let sorted = edits.sorted { $0.range.lowerBound > $1.range.lowerBound }
        for i in 1 ..< sorted.count {
            precondition(
                sorted[i].range.upperBound <= sorted[i - 1].range.lowerBound,
                "applyEdits: các vùng sửa không được giao nhau"
            )
        }

        revision += 1

        var ops: [AppliedOp] = []
        ops.reserveCapacity(sorted.count)
        for edit in sorted {
            let old = table.bytes(in: edit.range)
            let written = table.replace(edit.range, with: edit.bytes)
            ops.append(AppliedOp(
                originalRange: edit.range,
                writtenRange: written,
                oldBytes: old,
                newBytes: edit.bytes
            ))
        }

        // Đang mở một nhóm thì DỒN vào đó thay vì đẩy một bước undo mới.
        if openGroup != nil {
            openGroup?.ops.append(contentsOf: ops)
        } else {
            undoStack.append(UndoGroup(label: label, ops: ops))
        }

        if !redoStack.isEmpty {
            redoStack.removeAll()
            historyBranch += 1
        }
    }

    // MARK: - Gộp nhiều lần sửa thành MỘT bước undo

    /// Mở một nhóm: mọi `applyEdits` cho tới `endUndoGroup` gộp thành một bước undo duy nhất.
    ///
    /// Cần cho việc phát macro (FR-AUTO-602). Chạy macro 100 lần là MỘT thao tác hàng loạt
    /// theo nghĩa của FR-CORE-004, nên phải hoàn tác bằng một lần Cmd+Z — bắt người dùng bấm
    /// 100 lần là biến undo thành thứ không dùng được.
    ///
    /// Không dùng `applyEdits` một phát cho cả macro được: bước sau của macro phụ thuộc vào
    /// văn bản SAU bước trước ("tìm chuỗi kế tiếp" sau khi vừa thay thế), nên phải áp từng
    /// bước rồi mới biết bước kế đụng vào đâu.
    ///
    /// Lồng nhau KHÔNG được hỗ trợ và cố ý không im lặng bỏ qua: nhóm lồng nhóm là dấu hiệu
    /// hai chỗ gọi cùng tưởng mình sở hữu bước undo, và cái sai ấy chỉ lộ ra khi người dùng
    /// bấm hoàn tác.
    public func beginUndoGroup(label: String) {
        precondition(openGroup == nil, "beginUndoGroup: nhóm undo không lồng nhau được")
        openGroup = (label, [])
    }

    /// Đóng nhóm. Nhóm rỗng thì KHÔNG đẩy bước undo nào — macro chạy mà không sửa gì thì
    /// không được để lại một bước hoàn tác không làm gì.
    public func endUndoGroup() {
        guard let group = openGroup else { return }
        openGroup = nil
        guard !group.ops.isEmpty else { return }
        undoStack.append(UndoGroup(label: group.label, ops: group.ops))
    }

    public var isUndoGroupOpen: Bool { openGroup != nil }

    /// Đường sửa đổi một-vị-trí; vẫn là một bước undo.
    public func replace(_ range: Range<Int>, with text: String, label: String) {
        applyEdits([TextEdit(range: range, text: text)], label: label)
    }

    // MARK: - Undo / Redo

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Nhãn của bước undo kế tiếp — hiển thị trong menu Edit ("Hoàn tác Sắp xếp dòng").
    public var undoLabel: String? { undoStack.last?.label }
    public var redoLabel: String? { redoStack.last?.label }

    @discardableResult
    public func undo() -> Bool {
        guard let group = undoStack.popLast() else { return false }
        revision += 1
        // Đảo ngược theo thứ tự áp dụng: vùng đã ghi của op trước còn hiệu lực
        // đúng vào thời điểm ta hoàn tác op sau nó.
        for op in group.ops.reversed() {
            table.replace(op.writtenRange, with: op.oldBytes)
        }
        redoStack.append(group)
        return true
    }

    @discardableResult
    public func redo() -> Bool {
        guard let group = redoStack.popLast() else { return false }
        revision += 1
        for op in group.ops {
            table.replace(op.originalRange, with: op.newBytes)
        }
        undoStack.append(group)
        return true
    }

    // MARK: - Nhật ký sửa đổi (bản nháp delta — FR-DOC-304)

    /// Một nhóm sửa đổi đã áp dụng, ở dạng ghi ra đĩa được.
    ///
    /// Toạ độ là toạ độ TRƯỚC KHI áp nhóm đó — đúng như `applyEdits` nhận. Nhờ vậy phát lại
    /// nhật ký theo thứ tự trên chính file gốc sẽ dựng lại đúng trạng thái hiện tại.
    public struct EditRecord: Codable, Equatable {
        public struct Entry: Codable, Equatable {
            public let lower: Int
            public let upper: Int
            public let bytes: [UInt8]
        }

        public let label: String
        public let entries: [Entry]

        /// Ước lượng chỗ chiếm khi ghi ra đĩa — dùng để chọn giữa bản nháp delta và bản đầy đủ.
        public var estimatedByteCount: Int {
            entries.reduce(0) { $0 + $1.bytes.count + 24 }
        }
    }

    /// Các nhóm ĐANG được áp dụng, theo đúng thứ tự áp dụng.
    ///
    /// Bằng đúng ngăn xếp undo: những nhóm đã bị hoàn tác nằm ở ngăn redo và không có mặt ở
    /// đây, nên phát lại nhật ký này cho ra trạng thái người dùng đang thấy, không phải trạng
    /// thái họ đã lùi khỏi.
    public func editLog() -> [EditRecord] {
        undoStack.map { group in
            EditRecord(
                label: group.label,
                entries: group.ops.map {
                    EditRecord.Entry(
                        lower: $0.originalRange.lowerBound,
                        upper: $0.originalRange.upperBound,
                        bytes: $0.newBytes
                    )
                }
            )
        }
    }

    /// Áp lại một nhật ký. Mỗi bản ghi vẫn là MỘT bước undo như lúc đầu (FR-CORE-004).
    public func replay(_ log: [EditRecord]) {
        for record in log {
            applyEdits(
                record.entries.map { TextEdit(range: $0.lower ..< $0.upper, bytes: $0.bytes) },
                label: record.label
            )
        }
    }

    // MARK: - Số liệu cấu trúc (benchmark PoC-B, không dùng trong đường nóng)

    /// Số piece — phân mảnh tăng theo số lần sửa; PoC-B đo ảnh hưởng của nó.
    public var pieceCount: Int { table.pieceCount }
    public var treeDepth: Int { table.treeDepth }
    public var addBufferByteCount: Int { table.addBufferByteCount }
    public var originalIndexMilliseconds: Double { table.originalIndexMilliseconds }
}
