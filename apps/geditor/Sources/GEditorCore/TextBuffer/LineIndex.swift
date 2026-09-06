import Foundation
import GEditorSIMD

/// Chỉ mục dòng: offset byte bắt đầu của từng dòng.
///
/// Dựng bằng quét SIMD (`geditor_find_byte`) trên vùng nhớ mmap — SAD §4.2 bước 2.
/// Luôn có ít nhất một dòng (dòng 0 bắt đầu tại offset 0), kể cả với buffer rỗng.
public struct LineIndex {
    public private(set) var lineStarts: [Int]
    public private(set) var byteCount: Int

    public init(lineStarts: [Int], byteCount: Int) {
        self.lineStarts = lineStarts.isEmpty ? [0] : lineStarts
        self.byteCount = byteCount
    }

    /// Dựng chỉ mục từ một buffer liên tục.
    public init(bytes: UnsafeRawBufferPointer) {
        var starts: [Int] = [0]
        let total = bytes.count
        var pos = 0
        while pos < total, let at = ByteScan.firstIndex(of: UInt8(ascii: "\n"), in: bytes, from: pos) {
            starts.append(at + 1)
            pos = at + 1
        }
        // Offset == byteCount chỉ là "dòng ảo" sau EOL cuối; không tính là dòng thật.
        if let last = starts.last, last == total, starts.count > 1 {
            starts.removeLast()
        }
        self.lineStarts = starts
        self.byteCount = total
    }

    /// Dựng chỉ mục từ piece table bằng cách quét TOÀN BỘ nội dung — O(n).
    ///
    /// KHÔNG dùng trên đường nóng: từ PoC-B (ADR-02) truy vấn dòng do `PieceTable` trả lời
    /// trực tiếp trong O(log n) mà không dựng lại gì cả. Hàm này còn lại vì hai lý do:
    /// nó là hiện thực đối chứng hiển nhiên đúng cho `PieceTreeTests`, và nó tiện cho tài
    /// liệu nhỏ khi cần cả mảng mốc dòng một lần.
    public init(table: PieceTable) {
        var starts: [Int] = [0]
        var globalOffset = 0
        table.forEachChunk { chunk in
            var pos = 0
            while pos < chunk.count,
                  let at = ByteScan.firstIndex(of: UInt8(ascii: "\n"), in: chunk, from: pos) {
                starts.append(globalOffset + at + 1)
                pos = at + 1
            }
            globalOffset += chunk.count
        }
        if let last = starts.last, last == globalOffset, starts.count > 1 {
            starts.removeLast()
        }
        self.lineStarts = starts
        self.byteCount = globalOffset
    }

    public var lineCount: Int { lineStarts.count }

    /// Phạm vi byte của dòng `line`, GỒM ký tự EOL cuối dòng (nếu có).
    /// Dùng `TextBuffer.contentRange(ofLine:)` khi cần phạm vi đã bỏ CR/LF.
    public func range(ofLine line: Int) -> Range<Int> {
        precondition(line >= 0 && line < lineCount, "số dòng ngoài phạm vi")
        let start = lineStarts[line]
        let end = line + 1 < lineCount ? lineStarts[line + 1] : byteCount
        return start ..< end
    }

    /// Số dòng (0-based) chứa `offset`.
    public func line(atOffset offset: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    /// Vị trí (dòng, cột) theo byte — cột 0-based tính bằng byte, không phải grapheme.
    /// Status bar hiển thị cột theo ký tự nên phải quy đổi ở lớp trình bày (FR-CORE-018).
    public func position(atOffset offset: Int) -> (line: Int, byteColumn: Int) {
        let l = line(atOffset: offset)
        return (l, offset - lineStarts[l])
    }
}
