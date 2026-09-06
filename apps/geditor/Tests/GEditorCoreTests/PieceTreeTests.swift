import XCTest
@testable import GEditorCore

/// Đối chứng cây piece + chỉ mục newline thưa với mô hình ngây thơ (PoC-B, ADR-02).
///
/// Lý do bộ test này tồn tại: cây piece thay ĐỒNG THỜI hai thứ — cấu trúc lưu trữ và cách
/// trả lời truy vấn dòng. Sai sót ở đây không làm crash mà làm lệch số dòng/cột: kiểu lỗi
/// im lặng, chỉ lộ ra khi người dùng đã sửa nhầm dòng trên file thật. Nên mọi khẳng định ở
/// đây đều so với một hiện thực NGÂY THƠ, hiển nhiên đúng, chứ không so với chính nó.
final class PieceTreeTests: XCTestCase {

    // MARK: - Mô hình đối chứng

    /// Sinh số giả ngẫu nhiên TẤT ĐỊNH — cùng seed luôn cho cùng chuỗi thao tác, nên một
    /// lần fail là tái lập được y hệt.
    private struct Xorshift {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed == 0 ? 0x9E37_79B9 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
        mutating func int(_ upperBound: Int) -> Int {
            upperBound <= 0 ? 0 : Int(next() % UInt64(upperBound))
        }
    }

    /// Số dòng theo định nghĩa trần trụi: đếm '\n', newline cuối file không mở dòng mới.
    private func naiveLineCount(_ bytes: [UInt8]) -> Int {
        let newlines = bytes.filter { $0 == UInt8(ascii: "\n") }.count
        return max(1, newlines + (bytes.last == UInt8(ascii: "\n") ? 0 : 1))
    }

    /// Offset bắt đầu của từng dòng, quét tuyến tính.
    private func naiveLineStarts(_ bytes: [UInt8]) -> [Int] {
        var starts = [0]
        for (i, b) in bytes.enumerated() where b == UInt8(ascii: "\n") {
            starts.append(i + 1)
        }
        if starts.count > 1, starts.last == bytes.count { starts.removeLast() }
        return starts
    }

    /// So toàn bộ trạng thái quan sát được của bảng với mô hình.
    private func assertMatchesModel(
        _ table: PieceTable,
        _ model: [UInt8],
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(table.count, model.count, "độ dài: \(message())", file: file, line: line)
        XCTAssertEqual(table.bytes(in: 0 ..< table.count), model, "nội dung: \(message())", file: file, line: line)

        let starts = naiveLineStarts(model)
        XCTAssertEqual(table.lineCount, naiveLineCount(model), "lineCount: \(message())", file: file, line: line)
        XCTAssertEqual(table.lineCount, starts.count, "lineCount vs mốc dòng: \(message())", file: file, line: line)

        for line in 0 ..< min(table.lineCount, starts.count) {
            XCTAssertEqual(
                table.offset(ofLineStart: line), starts[line],
                "offset dòng \(line): \(message())", file: file, line: UInt(#line)
            )
        }

        // lineNumber(atOffset:) phải khớp với "số '\n' đứng trước offset" ở MỌI offset,
        // kể cả ngay tại byte '\n' (nó thuộc về dòng phía trước).
        var expectedLine = 0
        for offset in 0 ... model.count {
            XCTAssertEqual(
                table.lineNumber(atOffset: offset), expectedLine,
                "lineNumber tại \(offset): \(message())", file: file, line: UInt(#line)
            )
            if offset < model.count, model[offset] == UInt8(ascii: "\n") { expectedLine += 1 }
        }
    }

    // MARK: - Biên

    func testEmptyBuffer() {
        let table = PieceTable(text: "")
        assertMatchesModel(table, [])
        XCTAssertEqual(table.lineCount, 1, "buffer rỗng vẫn là một dòng")
        XCTAssertEqual(table.pieceCount, 0)
        XCTAssertFalse(table.endsWithNewline)
    }

    func testBufferWithoutNewline() {
        let table = PieceTable(text: "chỉ một dòng")
        assertMatchesModel(table, Array("chỉ một dòng".utf8))
        XCTAssertEqual(table.lineCount, 1)
    }

    func testTrailingNewlineDoesNotOpenPhantomLine() {
        assertMatchesModel(PieceTable(text: "a\nb\n"), Array("a\nb\n".utf8))
        assertMatchesModel(PieceTable(text: "a\nb"), Array("a\nb".utf8))
        assertMatchesModel(PieceTable(text: "\n"), Array("\n".utf8))
        assertMatchesModel(PieceTable(text: "\n\n\n"), Array("\n\n\n".utf8))
    }

    func testInsertAtBoundaries() {
        let table = PieceTable(text: "giữa")
        var model = Array("giữa".utf8)

        table.replace(0 ..< 0, with: Array("đầu\n".utf8))
        model.insert(contentsOf: Array("đầu\n".utf8), at: 0)
        assertMatchesModel(table, model, "chèn đầu")

        table.replace(table.count ..< table.count, with: Array("\ncuối".utf8))
        model.append(contentsOf: Array("\ncuối".utf8))
        assertMatchesModel(table, model, "chèn cuối")
    }

    func testDeleteEverything() {
        let table = PieceTable(text: "một\nhai\nba\n")
        table.replace(0 ..< table.count, with: [])
        assertMatchesModel(table, [])
    }

    // MARK: - Đối chứng ngẫu nhiên

    func testRandomEditsMatchNaiveModel() {
        // 5 seed × 300 thao tác: đủ để piece bị chẻ nhiều tầng và cây phải join/split thật sự.
        for seed in UInt64(1) ... 5 {
            var rng = Xorshift(seed: seed)
            let initial = "dòng một\ndòng hai\r\ndòng ba\n\ndòng năm"
            let table = PieceTable(text: initial)
            var model = Array(initial.utf8)

            for step in 0 ..< 300 {
                let insertPool = ["x", "\n", "abc", "\r\n", "", "dài hơn một chút\nvới hai dòng"]
                let text = insertPool[rng.int(insertPool.count)]
                let lower = rng.int(model.count + 1)
                let upper = lower + rng.int(model.count - lower + 1)
                let newBytes = Array(text.utf8)

                table.replace(lower ..< upper, with: newBytes)
                model.replaceSubrange(lower ..< upper, with: newBytes)

                // So đầy đủ định kỳ (tốn O(n) mỗi lần) + so nội dung sau mỗi bước.
                XCTAssertEqual(
                    table.bytes(in: 0 ..< table.count), model,
                    "nội dung lệch ở seed \(seed) bước \(step)"
                )
                if step % 25 == 0 {
                    assertMatchesModel(table, model, "seed \(seed) bước \(step)")
                }
            }
            assertMatchesModel(table, model, "seed \(seed) kết thúc")
        }
    }

    func testLineQueriesAgreeWithLineIndexOracle() {
        var rng = Xorshift(seed: 42)
        let table = PieceTable(text: String(repeating: "cột1,cột2,cột3\n", count: 200))

        for _ in 0 ..< 400 {
            let lower = rng.int(table.count + 1)
            let upper = lower + rng.int(min(20, table.count - lower + 1))
            table.replace(lower ..< upper, with: Array((rng.int(2) == 0 ? "\n" : "z").utf8))
        }

        // `LineIndex(table:)` là hiện thực cũ, O(n), quét toàn bộ — dùng làm bên đối chứng.
        let oracle = LineIndex(table: table)
        XCTAssertEqual(table.lineCount, oracle.lineCount)
        for line in 0 ..< table.lineCount {
            XCTAssertEqual(table.offset(ofLineStart: line), oracle.range(ofLine: line).lowerBound,
                           "mốc dòng \(line)")
            XCTAssertEqual(table.lineRange(ofLine: line), oracle.range(ofLine: line),
                           "phạm vi dòng \(line)")
        }
        for offset in stride(from: 0, through: table.count, by: 7) {
            XCTAssertEqual(table.lineNumber(atOffset: offset), oracle.line(atOffset: offset),
                           "dòng chứa offset \(offset)")
        }
    }

    // MARK: - Chỉ mục newline thưa

    /// Chỉ mục chia khối 64 KB, nên mọi lỗi lệch mốc chỉ lộ ra khi buffer VƯỢT nhiều khối.
    /// Test này cố ý dựng buffer ~200 KB và đặt newline sát hai bên biên khối.
    func testNewlineBlockIndexAcrossBlockBoundaries() {
        let blockSize = NewlineBlockIndex.blockSize
        var bytes = [UInt8](repeating: UInt8(ascii: "a"), count: blockSize * 3 + 1234)
        for position in [0, 1, blockSize - 1, blockSize, blockSize + 1,
                         2 * blockSize - 1, 2 * blockSize, 3 * blockSize,
                         bytes.count - 1] {
            bytes[position] = UInt8(ascii: "\n")
        }
        // Thêm một cụm newline liên tiếp giữa khối 2 để phá giả định "mỗi khối vài dòng".
        for position in (blockSize + 100) ..< (blockSize + 400) {
            bytes[position] = UInt8(ascii: "\n")
        }

        let expectedOffsets = bytes.enumerated()
            .filter { $0.element == UInt8(ascii: "\n") }
            .map(\.offset)

        bytes.withUnsafeBytes { buffer in
            let index = NewlineBlockIndex(bytes: buffer)
            XCTAssertEqual(index.totalNewlines, expectedOffsets.count)

            for (n, expected) in expectedOffsets.enumerated() {
                XCTAssertEqual(index.offsetOfNewline(n, in: buffer), expected, "newline thứ \(n)")
            }
            XCTAssertNil(index.offsetOfNewline(expectedOffsets.count, in: buffer))
            XCTAssertNil(index.offsetOfNewline(-1, in: buffer))

            var cursor = 0
            for offset in stride(from: 0, through: bytes.count, by: 997) {
                while cursor < expectedOffsets.count, expectedOffsets[cursor] < offset { cursor += 1 }
                XCTAssertEqual(index.newlinesBefore(offset, in: buffer), cursor, "trước offset \(offset)")
            }
        }
    }

    /// Add buffer chỉ nối thêm, nên chỉ mục phải mở rộng được mà không dựng lại từ đầu.
    func testNewlineBlockIndexExtendsIncrementally() {
        var storage: [UInt8] = []
        var index = NewlineBlockIndex()
        var rng = Xorshift(seed: 7)

        for _ in 0 ..< 40 {
            let chunk = (0 ..< rng.int(9000) + 1000).map { _ -> UInt8 in
                rng.int(20) == 0 ? UInt8(ascii: "\n") : UInt8(ascii: "b")
            }
            storage.append(contentsOf: chunk)
            storage.withUnsafeBytes { index.extend(with: $0) }

            let expected = storage.filter { $0 == UInt8(ascii: "\n") }.count
            XCTAssertEqual(index.totalNewlines, expected)
            XCTAssertEqual(index.indexedBytes, storage.count)
        }

        let expectedOffsets = storage.enumerated()
            .filter { $0.element == UInt8(ascii: "\n") }
            .map(\.offset)
        storage.withUnsafeBytes { buffer in
            for n in stride(from: 0, to: expectedOffsets.count, by: 13) {
                XCTAssertEqual(index.offsetOfNewline(n, in: buffer), expectedOffsets[n])
            }
        }
    }

    // MARK: - Tương tác với undo (FR-CORE-004)

    func testUndoRedoAfterHeavyFragmentation() {
        let initial = String(repeating: "abcdefghij\n", count: 500)
        let buffer = TextBuffer(text: initial)
        let model = Array(initial.utf8)

        // 500 vị trí không giao nhau, sửa như MỘT bước undo.
        let edits = (0 ..< 500).map { i in
            TextEdit(range: (i * 11) ..< (i * 11 + 1), text: "\n")
        }
        buffer.applyEdits(edits, label: "Kiểm thử")

        var edited = model
        for i in (0 ..< 500).reversed() {
            edited.replaceSubrange((i * 11) ..< (i * 11 + 1), with: Array("\n".utf8))
        }
        XCTAssertEqual(buffer.bytes(in: 0 ..< buffer.count), edited)
        XCTAssertEqual(buffer.lineCount, naiveLineCount(edited))

        XCTAssertTrue(buffer.undo())
        XCTAssertEqual(buffer.bytes(in: 0 ..< buffer.count), model, "undo phải khôi phục nguyên trạng")
        XCTAssertEqual(buffer.lineCount, naiveLineCount(model), "undo phải khôi phục cả số dòng")

        XCTAssertTrue(buffer.redo())
        XCTAssertEqual(buffer.bytes(in: 0 ..< buffer.count), edited)
        XCTAssertEqual(buffer.lineCount, naiveLineCount(edited))
    }

    /// File gốc không bao giờ bị chạm tới, kể cả sau khi cây đã chẻ nát nó.
    func testOriginalSourceUntouchedAfterFragmentation() {
        let original = MemoryByteSource("một\nhai\nba\nbốn\n")
        let snapshot = original.withUnsafeBytes { Array($0) }
        let table = PieceTable(original: original)

        var rng = Xorshift(seed: 99)
        for _ in 0 ..< 200 {
            let lower = rng.int(table.count + 1)
            let upper = lower + rng.int(min(3, table.count - lower + 1))
            table.replace(lower ..< upper, with: Array("q\n".utf8))
        }

        XCTAssertEqual(original.withUnsafeBytes { Array($0) }, snapshot)
    }

    // MARK: - Cân bằng

    /// Treap với ưu tiên splitmix64 phải giữ độ sâu ở mức log, nếu không thì mọi lập luận
    /// O(log n) ở trên chỉ là lý thuyết.
    /// Xóa hàng loạt theo thứ tự GIẢM DẦN — đúng thứ tự mà `applyEdits` sinh ra.
    ///
    /// Test này tồn tại vì một lỗi đã lọt qua toàn bộ bộ đo PoC-B: khi cắt giữa một piece,
    /// `split` dùng lại nút cũ cho nửa đầu, nên nửa đầu giữ nguyên ưu tiên cũ trong khi nửa
    /// sau nhận ưu tiên mới. Cắt đi cắt lại cùng một piece làm mất tính ngẫu nhiên của ưu
    /// tiên và cây suy biến thành danh sách — đo được độ sâu 6281 trên 20 001 piece, biến
    /// xóa hàng loạt thành O(n²) (xóa cột trên 100 000 hàng mất 135 giây).
    ///
    /// PoC-B không bắt được vì nó chỉ đo CHÈN và THAY THẾ, hai đường luôn tạo nút mới cho
    /// nội dung thay vào nên ưu tiên vẫn ngẫu nhiên. Đường XÓA thì không.
    func testTreeStaysBalancedUnderBulkDescendingDeletions() {
        let lineLength = 20
        let count = 20_000
        let table = PieceTable(text: String(repeating: "0123456789abcdefghi\n", count: count))

        // Xóa 5 byte ở mỗi dòng, từ CUỐI về ĐẦU.
        for index in (0 ..< count).reversed() {
            let start = index * lineLength + 5
            table.replace(start ..< (start + 5), with: [])
        }

        XCTAssertEqual(table.pieceCount, count + 1)
        // Chặn rộng rãi quanh kỳ vọng ~1,39·log₂n ≈ 20; mục đích là bắt suy biến tuyến tính,
        // không phải chốt một hằng số cụ thể.
        XCTAssertLessThan(
            table.treeDepth, 120,
            "cây suy biến sau khi xóa hàng loạt: độ sâu \(table.treeDepth) trên \(table.pieceCount) piece"
        )
        XCTAssertEqual(table.lineCount, count)
    }

    /// Xen kẽ xóa và chèn, vị trí ngẫu nhiên — hình dạng gần với một phiên làm việc thật nhất.
    func testTreeStaysBalancedUnderMixedRandomEdits() {
        var rng = Xorshift(seed: 2026)
        let table = PieceTable(text: String(repeating: "dòng mẫu\n", count: 5_000))

        for step in 0 ..< 20_000 {
            let offset = rng.int(max(1, table.count))
            if step % 2 == 0, offset + 3 <= table.count {
                table.replace(offset ..< (offset + 3), with: [])
            } else {
                table.replace(offset ..< offset, with: Array("x".utf8))
            }
        }
        XCTAssertLessThan(table.treeDepth, 120, "độ sâu \(table.treeDepth) trên \(table.pieceCount) piece")
    }

    func testTreeStaysBalancedUnderSequentialAppends() {
        let table = PieceTable(text: "x")
        for _ in 0 ..< 5000 {
            table.replace(table.count ..< table.count, with: Array("y\n".utf8))
        }
        XCTAssertEqual(table.pieceCount, 5001)
        // Chặn rộng rãi (~3·log₂n ≈ 37) — mục đích là bắt trường hợp cây suy biến thành danh sách.
        XCTAssertLessThan(table.treeDepth, 40, "cây suy biến: độ sâu \(table.treeDepth)")
        // Nội dung là "x" + "y\n"×5000 → kết thúc bằng EOL nên không có dòng ảo cuối.
        XCTAssertEqual(table.lineCount, 5000)
    }
}
