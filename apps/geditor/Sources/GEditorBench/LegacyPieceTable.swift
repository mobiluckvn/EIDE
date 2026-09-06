import Foundation
import GEditorCore

/// Bản dựng khung TRƯỚC PoC-B, giữ lại NGUYÊN VẸN để đo đối chứng.
///
/// Đây không phải mã sản phẩm và không được dùng lại ở đâu khác. Nó tồn tại vì ADR-02 cần
/// con số chứ không cần lập luận: "mảng piece phẳng + dựng lại chỉ mục dòng sau mỗi lần sửa"
/// hỏng ở kích thước nào, hỏng nhanh đến đâu.
///
/// Hai đặc điểm được tái hiện đúng như bản cũ:
///  1. `splitPieces` quét tuyến tính rồi `Array.insert` → O(số piece) mỗi lần tách.
///  2. Số dòng lấy bằng cách quét LẠI toàn bộ tài liệu sau mỗi nhóm sửa → O(số byte).
final class LegacyPieceTable {
    private struct Piece {
        enum Source { case original, add }
        var source: Source
        var offset: Int
        var length: Int
    }

    private let original: ByteSource
    private var addBuffer: [UInt8] = []
    private var pieces: [Piece] = []
    private(set) var count: Int

    init(original: ByteSource) {
        self.original = original
        self.count = original.count
        if original.count > 0 {
            pieces.append(Piece(source: .original, offset: 0, length: original.count))
        }
    }

    var pieceCount: Int { pieces.count }

    private func withSourceBytes(_ source: Piece.Source, _ body: (UnsafeRawBufferPointer) -> Void) {
        switch source {
        case .original: original.withUnsafeBytes(body)
        case .add: addBuffer.withUnsafeBytes(body)
        }
    }

    func forEachChunk(_ body: (UnsafeRawBufferPointer) -> Void) {
        for piece in pieces {
            withSourceBytes(piece.source) { buf in
                let start = buf.baseAddress!.advanced(by: piece.offset)
                body(UnsafeRawBufferPointer(start: start, count: piece.length))
            }
        }
    }

    @discardableResult
    func replace(_ range: Range<Int>, with newBytes: [UInt8]) -> Range<Int> {
        let start = splitPieces(at: range.lowerBound)
        let end = splitPieces(at: range.upperBound)

        var replacement: [Piece] = []
        if !newBytes.isEmpty {
            replacement.append(Piece(source: .add, offset: addBuffer.count, length: newBytes.count))
            addBuffer.append(contentsOf: newBytes)
        }
        pieces.replaceSubrange(start ..< end, with: replacement)
        count += newBytes.count - range.count
        return range.lowerBound ..< (range.lowerBound + newBytes.count)
    }

    private func splitPieces(at offset: Int) -> Int {
        if offset == 0 { return 0 }
        var pos = 0
        for i in pieces.indices {
            let piece = pieces[i]
            if pos == offset { return i }
            if offset < pos + piece.length {
                let head = offset - pos
                pieces[i] = Piece(source: piece.source, offset: piece.offset, length: head)
                pieces.insert(
                    Piece(source: piece.source, offset: piece.offset + head, length: piece.length - head),
                    at: i + 1
                )
                return i + 1
            }
            pos += piece.length
        }
        return pieces.count
    }

    /// Đúng cách bản cũ trả lời "tài liệu có bao nhiêu dòng": quét lại từ đầu.
    func rebuiltLineCount() -> Int {
        var newlines = 0
        var lastByte: UInt8 = 0
        forEachChunk { chunk in
            newlines += ByteScan.countNewlines(in: chunk)
            if chunk.count > 0 { lastByte = chunk[chunk.count - 1] }
        }
        return max(1, newlines + (lastByte == UInt8(ascii: "\n") ? 0 : 1))
    }
}
