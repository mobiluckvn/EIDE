import Foundation

/// Một đoạn liên tục trong một nguồn byte.
struct Piece {
    enum Source { case original, add }
    var source: Source
    var offset: Int
    var length: Int
    /// Số '\n' trong `[offset, offset+length)` của nguồn — tính sẵn để cây tổng hợp được.
    var newlines: Int
}

/// Nút của cây piece. Mỗi nút tổng hợp cả cây con bên dưới nó.
final class PieceNode {
    var piece: Piece
    let priority: UInt64
    var left: PieceNode?
    var right: PieceNode?

    /// Tổng số byte của cây con — khóa ngầm để định vị theo offset.
    var bytes: Int
    /// Tổng số '\n' của cây con — thứ khiến truy vấn dòng thành O(log n) thay vì O(n).
    var newlines: Int
    /// Số nút của cây con — chỉ số phân mảnh cho PoC-B.
    var nodes: Int

    init(piece: Piece, priority: UInt64) {
        self.piece = piece
        self.priority = priority
        self.bytes = piece.length
        self.newlines = piece.newlines
        self.nodes = 1
    }

    func update() {
        bytes = (left?.bytes ?? 0) + piece.length + (right?.bytes ?? 0)
        newlines = (left?.newlines ?? 0) + piece.newlines + (right?.newlines ?? 0)
        nodes = (left?.nodes ?? 0) + 1 + (right?.nodes ?? 0)
    }
}

/// Cây piece — thay cho mảng piece phẳng của bản dựng khung (ADR-02).
///
/// Vì sao phải bỏ mảng phẳng: định vị offset là quét tuyến tính và mỗi lần tách piece là một
/// `Array.insert` (memmove). Sau 10 000 lần sửa, tài liệu có ~20 000 piece và cả hai chi phí
/// đều tỉ lệ với con số đó → thời gian sửa tăng theo bình phương số lần sửa. PoC-B đo chính
/// điểm gãy này.
///
/// Cấu trúc: treap theo khóa NGẦM (vị trí, không phải giá trị), nên `split`/`join` là hai
/// nguyên thủy duy nhất — mọi phép sửa quy về `split · split · join · join`. Ưu tiên nút sinh
/// bằng splitmix64 trên bộ đếm tăng dần: PHÂN BỐ như ngẫu nhiên nhưng TẤT ĐỊNH, nên một chuỗi
/// thao tác luôn cho cùng một cây — điều kiện để benchmark và test tái lập được.
///
/// Kỳ vọng độ sâu ~1,39·log₂n (≈20 với 20 000 piece); đệ quy `split`/`join` an toàn ở mức đó.
final class PieceTree {
    private let original: OriginalSource
    private let add: AddBuffer
    private var root: PieceNode?
    private var priorityCounter: UInt64 = 0

    init(original: OriginalSource, add: AddBuffer) {
        self.original = original
        self.add = add
        if original.count > 0 {
            let piece = Piece(
                source: .original,
                offset: 0,
                length: original.count,
                newlines: original.newlineCount
            )
            root = makeNode(piece)
        }
    }

    // MARK: - Tổng hợp

    var byteCount: Int { root?.bytes ?? 0 }
    var newlineCount: Int { root?.newlines ?? 0 }
    var pieceCount: Int { root?.nodes ?? 0 }

    func source(of kind: Piece.Source) -> IndexedSource {
        switch kind {
        case .original: return original
        case .add: return add
        }
    }

    // MARK: - Nguyên thủy treap

    private func makeNode(_ piece: Piece) -> PieceNode {
        priorityCounter &+= 1
        // Băm tất định thay cho sinh số ngẫu nhiên — xem ghi chú ở đầu lớp. Bản chép riêng ở
        // đây đã gộp vào `SeededGenerator` ngày 26/08/2026: cùng một SplitMix64, và hai bản của
        // cùng một thuật toán sẽ trôi ra xa nhau khi ai đó sửa một bên.
        return PieceNode(
            piece: piece,
            priority: SeededGenerator.mix(priorityCounter &+ 0x9E37_79B9_7F4A_7C15))
    }

    /// Tách thành hai cây: cây trái giữ đúng `k` byte đầu.
    ///
    /// Khi `k` rơi vào GIỮA một piece thì piece đó bị chẻ đôi — đây là chỗ duy nhất sinh thêm
    /// piece, và là lý do `Piece.newlines` phải tính lại bằng chỉ mục khối chứ không quét lại
    /// cả đoạn (đoạn đầu tiên dài bằng cả file).
    private func split(_ node: PieceNode?, at k: Int) -> (PieceNode?, PieceNode?) {
        guard let node else { return (nil, nil) }
        let leftBytes = node.left?.bytes ?? 0

        if k <= leftBytes {
            let (a, b) = split(node.left, at: k)
            node.left = b
            node.update()
            return (a, node)
        }

        let afterPiece = leftBytes + node.piece.length
        if k >= afterPiece {
            let (a, b) = split(node.right, at: k - afterPiece)
            node.right = a
            node.update()
            return (node, b)
        }

        let local = k - leftBytes
        let p = node.piece
        let headNewlines = source(of: p.source).newlines(in: p.offset ..< (p.offset + local))
        let head = Piece(source: p.source, offset: p.offset, length: local, newlines: headNewlines)
        let tail = Piece(
            source: p.source,
            offset: p.offset + local,
            length: p.length - local,
            newlines: p.newlines - headNewlines
        )

        // CẢ HAI nửa đều là nút MỚI với ưu tiên mới, và được nối lại bằng `join` chứ không
        // gán thẳng vào cây con.
        //
        // Bản đầu dùng lại chính `node` cho nửa đầu — rẻ hơn một nút, nhưng nửa đầu khi đó
        // giữ nguyên ưu tiên cũ trong khi nửa sau nhận ưu tiên mới. Cắt đi cắt lại cùng một
        // piece (đúng thứ tự mà xóa hàng loạt sinh ra) làm mất tính ngẫu nhiên của ưu tiên và
        // cây suy biến thành danh sách: đo được độ sâu 6281 trên 20 001 piece, và một triệu
        // lần xóa trở thành O(n²). Với ưu tiên mới cho cả hai nửa, độ sâu về lại ~36.
        //
        // Phải qua `join`: gán `headNode.left = node.left` sẽ phá tính chất heap khi ưu tiên
        // mới nhỏ hơn ưu tiên gốc của cây con trái.
        let headPart = join(node.left, makeNode(head))
        let rightPart = join(makeNode(tail), node.right)
        return (headPart, rightPart)
    }

    /// Nối hai cây; mọi vị trí trong `a` đứng trước mọi vị trí trong `b`.
    private func join(_ a: PieceNode?, _ b: PieceNode?) -> PieceNode? {
        guard let a else { return b }
        guard let b else { return a }
        if a.priority > b.priority {
            a.right = join(a.right, b)
            a.update()
            return a
        }
        b.left = join(a, b.left)
        b.update()
        return b
    }

    // MARK: - Sửa

    /// Thay `range` bằng `piece` (`nil` = xóa).
    func replace(_ range: Range<Int>, with piece: Piece?) {
        let (head, rest) = split(root, at: range.lowerBound)
        let (_, tail) = split(rest, at: range.count)
        var merged = head
        if let piece, piece.length > 0 {
            merged = join(merged, makeNode(piece))
        }
        root = join(merged, tail)
    }

    /// Nối `bytes` vào add buffer và trả về piece mô tả nó.
    func appendToAddBuffer(_ bytes: [UInt8]) -> Piece {
        let offset = add.append(bytes)
        return Piece(
            source: .add,
            offset: offset,
            length: bytes.count,
            newlines: add.newlines(in: offset ..< (offset + bytes.count))
        )
    }

    // MARK: - Đọc

    /// Duyệt `range` theo từng đoạn liên tục, không copy.
    func forEachChunk(in range: Range<Int>, _ body: (UnsafeRawBufferPointer) -> Void) {
        guard !range.isEmpty else { return }
        visit(root, start: 0, range: range, body)
    }

    private func visit(
        _ node: PieceNode?,
        start: Int,
        range: Range<Int>,
        _ body: (UnsafeRawBufferPointer) -> Void
    ) {
        // Cắt nhánh: cây con nằm trọn ngoài `range` thì không đi vào.
        guard let node, start < range.upperBound, start + node.bytes > range.lowerBound else {
            return
        }

        let pieceStart = start + (node.left?.bytes ?? 0)
        visit(node.left, start: start, range: range, body)

        let pieceEnd = pieceStart + node.piece.length
        if pieceStart < range.upperBound, pieceEnd > range.lowerBound {
            let lo = max(pieceStart, range.lowerBound) - pieceStart
            let hi = min(pieceEnd, range.upperBound) - pieceStart
            let piece = node.piece
            source(of: piece.source).withUnsafeBytes { buf in
                let base = buf.baseAddress!.advanced(by: piece.offset + lo)
                body(UnsafeRawBufferPointer(start: base, count: hi - lo))
            }
        }

        visit(node.right, start: pieceEnd, range: range, body)
    }

    // MARK: - Truy vấn dòng, O(log n)

    /// Số '\n' đứng trước `offset` — cũng chính là số dòng (0-based) chứa `offset`.
    func newlinesBefore(_ offset: Int) -> Int {
        var node = root
        var remaining = offset
        var accumulated = 0

        while let current = node {
            let leftBytes = current.left?.bytes ?? 0
            if remaining <= leftBytes {
                node = current.left
                continue
            }
            accumulated += current.left?.newlines ?? 0
            remaining -= leftBytes

            if remaining >= current.piece.length {
                accumulated += current.piece.newlines
                remaining -= current.piece.length
                node = current.right
                continue
            }

            let piece = current.piece
            accumulated += source(of: piece.source)
                .newlines(in: piece.offset ..< (piece.offset + remaining))
            return accumulated
        }
        return accumulated
    }

    /// Offset của '\n' thứ `n` (từ 0) trong tài liệu.
    func offsetOfNewline(_ n: Int) -> Int? {
        guard n >= 0, n < newlineCount else { return nil }

        var node = root
        var remaining = n
        var base = 0

        while let current = node {
            let leftNewlines = current.left?.newlines ?? 0
            if remaining < leftNewlines {
                node = current.left
                continue
            }
            base += current.left?.bytes ?? 0
            remaining -= leftNewlines

            if remaining < current.piece.newlines {
                let piece = current.piece
                let src = source(of: piece.source)
                let ordinal = src.newlinesBefore(piece.offset) + remaining
                guard let sourceOffset = src.offsetOfNewline(ordinal) else { return nil }
                return base + (sourceOffset - piece.offset)
            }

            remaining -= current.piece.newlines
            base += current.piece.length
            node = current.right
        }
        return nil
    }

    /// Độ sâu thực của cây — chỉ dùng cho benchmark/test, không nằm trên đường nóng.
    var depth: Int { Self.depth(of: root) }

    private static func depth(of node: PieceNode?) -> Int {
        guard let node else { return 0 }
        return 1 + max(depth(of: node.left), depth(of: node.right))
    }
}
