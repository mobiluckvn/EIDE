import Foundation

/// Piece table trên nền file mmap + add-buffer (ADR-02).
///
/// Bất biến:
///  - File gốc KHÔNG bao giờ bị sửa; mọi nội dung mới nằm trong add buffer.
///  - Nội dung logic = nối tuần tự các piece theo thứ tự trong `PieceTree`.
///  - Không tồn tại piece rỗng.
///
/// Lớp này chỉ còn phần NGỮ NGHĨA (phạm vi, dòng, chuỗi); cơ chế cân bằng và tổng hợp nằm
/// trong `PieceTree`, chỉ mục newline nằm trong `NewlineBlockIndex`.
public final class PieceTable {
    private let originalSource: OriginalSource
    private let addBuffer: AddBuffer
    private let tree: PieceTree

    public init(original: ByteSource) {
        let originalSource = OriginalSource(original)
        let addBuffer = AddBuffer()
        self.originalSource = originalSource
        self.addBuffer = addBuffer
        self.tree = PieceTree(original: originalSource, add: addBuffer)
    }

    public convenience init(text: String) {
        self.init(original: MemoryByteSource(text))
    }

    public var count: Int { tree.byteCount }

    /// Số piece hiện tại — chỉ số phân mảnh, dùng cho benchmark PoC-B.
    public var pieceCount: Int { tree.pieceCount }

    /// Độ sâu cây piece — PoC-B kiểm chứng cân bằng thực tế so với kỳ vọng ~1,39·log₂n.
    public var treeDepth: Int { tree.depth }

    /// Số byte add buffer đã cấp — RAM thực sự do việc sửa sinh ra (PoC-B).
    public var addBufferByteCount: Int { addBuffer.count }

    /// Thời gian dựng chỉ mục newline của file gốc lúc mở, tính bằng ms (PoC-B).
    public var originalIndexMilliseconds: Double { originalSource.indexBuildMilliseconds }

    // MARK: - Đọc

    /// Sao chép byte trong `range` ra mảng mới.
    ///
    /// Đường đọc-hiển thị của editor nên dùng `forEachChunk` để tránh copy;
    /// hàm này dành cho thao tác trên đoạn ngắn (dòng, field CSV, vùng chọn).
    public func bytes(in range: Range<Int>) -> [UInt8] {
        precondition(range.lowerBound >= 0 && range.upperBound <= count, "range ngoài phạm vi buffer")
        guard !range.isEmpty else { return [] }
        var out = [UInt8]()
        out.reserveCapacity(range.count)
        forEachChunk(in: range) { chunk in
            out.append(contentsOf: chunk)
        }
        return out
    }

    /// Duyệt `range` theo từng đoạn liên tục, không copy.
    public func forEachChunk(in range: Range<Int>, _ body: (UnsafeRawBufferPointer) -> Void) {
        tree.forEachChunk(in: range, body)
    }

    /// Duyệt toàn bộ nội dung theo từng đoạn liên tục.
    public func forEachChunk(_ body: (UnsafeRawBufferPointer) -> Void) {
        forEachChunk(in: 0 ..< count, body)
    }

    // MARK: - Dòng (O(log n), không dựng lại chỉ mục sau khi sửa)

    /// Tổng số byte '\n' trong tài liệu.
    public var newlineCount: Int { tree.newlineCount }

    /// Tài liệu kết thúc bằng EOL hay không — quyết định có "dòng ảo" cuối file hay không.
    public var endsWithNewline: Bool {
        guard count > 0 else { return false }
        var last: UInt8 = 0
        forEachChunk(in: (count - 1) ..< count) { last = $0[0] }
        return last == UInt8(ascii: "\n")
    }

    /// Số dòng. Newline cuối file KHÔNG mở thêm một dòng rỗng (cùng quy ước `LineIndex`).
    public var lineCount: Int {
        max(1, newlineCount + (endsWithNewline ? 0 : 1))
    }

    /// Offset byte bắt đầu của dòng `line` (0-based).
    ///
    /// Nhận cả `line == lineCount`, và trả về `count`. Nghe như nhận một dòng không tồn tại,
    /// nhưng nó là chỗ ĐỨNG THẬT của con trỏ: trong file kết thúc bằng newline, bấm Cmd+A rồi
    /// mũi tên phải là con trỏ nằm ngay sau newline cuối — `lineNumber` khi ấy trả về đúng
    /// `lineCount`, và cặp hai hàm này đi liền nhau ở khắp nơi (`position(atOffset:)`, thanh
    /// trạng thái, thao tác dòng).
    ///
    /// Không nhận thì ỨNG DỤNG CHẾT bằng một thao tác tầm thường trên gần như mọi file văn bản.
    /// Đã bắt được bằng cách gõ thật vào app, không phải bằng đọc mã.
    ///
    /// Quy ước `lineCount` (newline cuối không mở thêm dòng) giữ NGUYÊN — thay nó sẽ kéo theo
    /// mọi thao tác dòng, mọi vòng lặp `0 ..< lineCount` và toàn bộ CSV.
    public func offset(ofLineStart line: Int) -> Int {
        precondition(line >= 0 && line <= lineCount, "số dòng ngoài phạm vi")
        if line == lineCount { return count }
        guard line > 0 else { return 0 }
        guard let newlineOffset = tree.offsetOfNewline(line - 1) else {
            preconditionFailure("chỉ mục newline không khớp số dòng")
        }
        return newlineOffset + 1
    }

    /// Phạm vi byte của dòng `line`, GỒM ký tự EOL cuối dòng (nếu có).
    public func lineRange(ofLine line: Int) -> Range<Int> {
        let start = offset(ofLineStart: line)
        let end = line + 1 < lineCount ? offset(ofLineStart: line + 1) : count
        return start ..< end
    }

    /// Số dòng (0-based) chứa `offset`.
    ///
    /// Luôn bằng "số ký tự '\n' đứng trước `offset`" — kể cả ở `offset == count`, nơi giá trị
    /// trả về có thể là `lineCount` (con trỏ đứng sau newline cuối cùng). Xem
    /// `offset(ofLineStart:)` về vì sao con số ấy hợp lệ.
    public func lineNumber(atOffset offset: Int) -> Int {
        precondition(offset >= 0 && offset <= count, "offset ngoài phạm vi buffer")
        return tree.newlinesBefore(offset)
    }

    // MARK: - Sửa

    /// Thay `range` bằng `newBytes`. Trả về vùng đã ghi (tọa độ sau khi sửa).
    @discardableResult
    public func replace(_ range: Range<Int>, with newBytes: [UInt8]) -> Range<Int> {
        precondition(range.lowerBound >= 0 && range.upperBound <= count, "range ngoài phạm vi buffer")

        let piece = newBytes.isEmpty ? nil : tree.appendToAddBuffer(newBytes)
        tree.replace(range, with: piece)

        return range.lowerBound ..< (range.lowerBound + newBytes.count)
    }
}

extension PieceTable {
    /// Tiện ích cho test và thao tác trên tài liệu nhỏ. KHÔNG dùng trên file lớn.
    public var utf8String: String {
        String(decoding: bytes(in: 0 ..< count), as: UTF8.self)
    }
}
