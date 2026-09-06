import XCTest
@testable import GEditorCore

/// Cửa sổ nội dung (ADR-01) — chỗ tài liệu gặp lớp hiển thị.
///
/// ADR-01 §4 gọi ánh xạ cửa sổ ↔ tài liệu là chỗ dễ sai nhất của hướng đã chốt, nên đây là
/// nơi test phải dày nhất.
final class TextWindowTests: XCTestCase {

    private let vietnamese = """
    Nguyễn Thị Hồng Nhung
    Trần Văn Đức
    Lê Hoàng Phương Uyên
    Đặng Thị Bích Ngọc
    """ + "\n"

    // MARK: - Cắt theo biên dòng

    func testWindowStartsAndEndsOnLineBoundary() {
        let buffer = TextBuffer(text: vietnamese)
        let window = TextWindowing.window(around: 30, in: buffer, size: 40)

        XCTAssertEqual(window.range.lowerBound, buffer.offset(ofLineStart:
            buffer.lineNumber(atOffset: window.range.lowerBound)))
        // Không cắt giữa ký tự nhiều byte: giải mã lại phải không có ký tự thay thế.
        XCTAssertFalse(window.text.unicodeScalars.contains("\u{FFFD}"),
                       "cửa sổ cắt giữa ký tự nhiều byte")
    }

    func testWindowCoveringWholeDocument() {
        let buffer = TextBuffer(text: vietnamese)
        let window = TextWindowing.window(around: 0, in: buffer, size: 1 << 20)
        XCTAssertEqual(window.range, 0 ..< buffer.count)
        XCTAssertEqual(window.text, vietnamese)
    }

    func testEmptyDocument() {
        let window = TextWindowing.window(around: 0, in: TextBuffer(text: ""))
        XCTAssertTrue(window.isEmpty)
        XCTAssertEqual(window.utf16Offset(forDocumentOffset: 0), 0)
        XCTAssertEqual(window.documentOffset(forUTF16Offset: 0), 0)
    }

    // MARK: - Quy đổi qua lại

    /// Bất biến quan trọng nhất: đi và về phải ra chính nó ở MỌI BIÊN KÝ TỰ.
    ///
    /// Chỉ ở biên ký tự, vì offset nằm giữa một ký tự nhiều byte không có ảnh UTF-16 nào để
    /// đi về — xem `testMidCharacterOffsetsSnapForward`.
    func testRoundTripAtEveryCharacterBoundary() {
        let buffer = TextBuffer(text: vietnamese)
        let window = TextWindowing.window(around: 0, in: buffer, size: 1 << 20)

        var offset = 0
        for scalar in vietnamese.unicodeScalars {
            let utf16 = window.utf16Offset(forDocumentOffset: offset)
            XCTAssertEqual(window.documentOffset(forUTF16Offset: utf16), offset,
                           "byte \(offset) → utf16 \(utf16) → byte")
            offset += UTF8.width(scalar)
        }
        XCTAssertEqual(offset, buffer.count)
    }

    /// Offset giữa một ký tự nhiều byte kẹp TIẾN tới biên kế tiếp, và kẹp một cách nhất quán.
    ///
    /// Kẹp lùi ở hàm này và kẹp tiến ở hàm kia là cách chắc chắn để hai phép quy đổi lệch nhau
    /// một ký tự — kiểu lỗi chỉ lộ ra với chữ có dấu, tức là với đúng người dùng của sản phẩm.
    func testMidCharacterOffsetsSnapForward() {
        // "Việt": V(1) i(1) ệ(3) t(1) → byte 2, 3, 4 đều nằm trong "ệ".
        let buffer = TextBuffer(text: "Việt\n")
        let window = TextWindowing.window(around: 0, in: buffer)

        let boundary = window.utf16Offset(forDocumentOffset: 5)   // ngay sau "ệ"
        for inside in 3 ... 4 {
            XCTAssertEqual(window.utf16Offset(forDocumentOffset: inside), boundary,
                           "byte \(inside) nằm giữa \"ệ\" phải kẹp tới cùng một biên")
        }
        // Kẹp rồi thì kẹp tiếp không đổi nữa.
        XCTAssertEqual(window.documentOffset(forUTF16Offset: boundary), 5)
    }

    func testRoundTripInsideOffsetWindow() {
        let big = String(repeating: "Nguyễn Thị Hồng Nhung, Quận Tân Bình\n", count: 2_000)
        let buffer = TextBuffer(text: big)
        let window = TextWindowing.window(around: buffer.count / 2, in: buffer, size: 8 * 1024)

        XCTAssertLessThan(window.range.count, buffer.count, "cửa sổ phải NHỎ HƠN tài liệu")
        // Đi theo BIÊN DÒNG (luôn là biên ký tự) để phép thử không rơi vào giữa chữ có dấu.
        for line in stride(from: window.firstLine, to: window.firstLine + 50, by: 3) {
            let offset = buffer.offset(ofLineStart: line)
            guard window.contains(documentOffset: offset) else { continue }
            let utf16 = window.utf16Offset(forDocumentOffset: offset)
            XCTAssertEqual(window.documentOffset(forUTF16Offset: utf16), offset, "dòng \(line)")
        }
    }

    /// Quy đổi phải tính theo cửa sổ, không phải theo đầu tài liệu.
    func testOffsetsAreRelativeToWindowNotDocument() {
        let big = String(repeating: "dòng dữ liệu\n", count: 5_000)
        let buffer = TextBuffer(text: big)
        let window = TextWindowing.window(around: buffer.count / 2, in: buffer, size: 4 * 1024)

        XCTAssertGreaterThan(window.range.lowerBound, 0)
        // Đầu cửa sổ là utf16 0, không phải một số lớn.
        XCTAssertEqual(window.utf16Offset(forDocumentOffset: window.range.lowerBound), 0)
        XCTAssertEqual(window.documentOffset(forUTF16Offset: 0), window.range.lowerBound)
    }

    /// Chữ có dấu: byte và UTF-16 lệch nhau, và đó là toàn bộ lý do lớp này tồn tại.
    func testByteAndUTF16DivergeOnVietnamese() {
        let buffer = TextBuffer(text: "Việt\n")
        let window = TextWindowing.window(around: 0, in: buffer)
        // "Việt" = 4 ký tự, 4 đơn vị UTF-16, nhưng 6 byte.
        XCTAssertEqual(window.utf16Offset(forDocumentOffset: 6), 4)
        XCTAssertEqual(window.documentOffset(forUTF16Offset: 4), 6)
    }

    /// Ngoài cửa sổ thì KẸP về biên, không được nhảy về 0.
    func testOffsetsOutsideWindowAreClamped() {
        let big = String(repeating: "dòng\n", count: 5_000)
        let buffer = TextBuffer(text: big)
        let window = TextWindowing.window(around: buffer.count / 2, in: buffer, size: 2 * 1024)

        XCTAssertEqual(window.utf16Offset(forDocumentOffset: 0), 0)
        XCTAssertEqual(window.utf16Offset(forDocumentOffset: buffer.count), window.utf16Count)
        XCTAssertFalse(window.contains(documentOffset: 0))
        XCTAssertTrue(window.contains(documentOffset: window.range.lowerBound))
    }

    // MARK: - Biên

    func testWindowAtEndOfDocument() {
        let big = String(repeating: "dòng dữ liệu\n", count: 3_000)
        let buffer = TextBuffer(text: big)
        let window = TextWindowing.window(around: buffer.count, in: buffer, size: 4 * 1024)

        XCTAssertEqual(window.range.upperBound, buffer.count)
        XCTAssertTrue(window.contains(documentOffset: buffer.count))
        XCTAssertEqual(window.documentOffset(forUTF16Offset: window.utf16Count), buffer.count)
    }

    func testCRLFDocument() {
        let text = "một\r\nhai\r\nba\r\n"
        let buffer = TextBuffer(text: text)
        let window = TextWindowing.window(around: 0, in: buffer)

        var offset = 0
        for scalar in text.unicodeScalars {
            let utf16 = window.utf16Offset(forDocumentOffset: offset)
            XCTAssertEqual(window.documentOffset(forUTF16Offset: utf16), offset, "offset \(offset)")
            offset += UTF8.width(scalar)
        }
    }

    /// Cửa sổ nhỏ hơn một dòng: vẫn phải cho ra một cửa sổ dùng được, không rỗng.
    func testWindowSmallerThanOneLine() {
        let buffer = TextBuffer(text: String(repeating: "x", count: 10_000) + "\n")
        let window = TextWindowing.window(around: 5_000, in: buffer, size: 100)
        XCTAssertFalse(window.isEmpty)
        XCTAssertEqual(window.documentOffset(forUTF16Offset: 0), window.range.lowerBound)
    }
}

/// Ước lượng số hàng khi bật ngắt dòng mềm (FR-CORE-015).
final class TextWindowWrapTests: XCTestCase {

    private func window(_ text: String) -> TextWindow {
        TextWindowing.window(around: 0, in: TextBuffer(text: text))
    }

    func testShortLinesAreOneRowEach() {
        XCTAssertEqual(window("a\nbb\nccc\n").rowsPerLine(columnsPerRow: 80), 1)
    }

    func testEmptyLineStillTakesARow() {
        XCTAssertEqual(window("\n\n\n").rowsPerLine(columnsPerRow: 80), 1)
    }

    func testLineLengthExcludesTheNewline() {
        let w = window("abc\nde\n")
        XCTAssertEqual(w.utf16Length(ofLine: 0), 3)
        XCTAssertEqual(w.utf16Length(ofLine: 1), 2)
    }

    /// Bốn dòng: một dòng 30 ký tự (3 hàng ở cột 10) và ba dòng ngắn (1 hàng).
    func testLongLineRaisesTheAverage() {
        let w = window(String(repeating: "x", count: 30) + "\na\nb\nc\n")
        // 4 dòng nội dung + dòng rỗng cuối = 5 mốc; (3+1+1+1+1)/5 = 1,4
        XCTAssertEqual(w.rowsPerLine(columnsPerRow: 10), 7.0 / 5.0, accuracy: 0.0001)
    }

    /// Đếm theo Ô HIỂN THỊ, không theo byte: "Nguyễn" là 9 byte nhưng chỉ 6 ô.
    ///
    /// Đếm nhầm theo byte thì dòng tiếng Việt bị tưởng dài gấp rưỡi và số hàng phồng lên —
    /// đúng loại lỗi chỉ lộ ra với người dùng thật của sản phẩm này.
    func testVietnameseCountsCellsNotBytes() {
        let line = String(repeating: "ễ", count: 20)          // 20 ô, 60 byte
        XCTAssertEqual(line.utf8.count, 60)
        let w = window(line + "\n")
        XCTAssertEqual(w.utf16Length(ofLine: 0), 20)
        // 20 ô ở cột 10 là ĐÚNG 2 hàng. Nếu đếm byte sẽ ra 6 hàng.
        XCTAssertEqual(w.rowsPerLine(columnsPerRow: 10), (2.0 + 1.0) / 2.0, accuracy: 0.0001)
    }

    // MARK: - Dòng dài nhất (bề rộng khung chữ khi TẮT ngắt dòng)

    func testLongestLineIgnoresTheNewline() {
        XCTAssertEqual(window("abc\nde\n").longestLineUTF16Length, 3)
        XCTAssertEqual(window("a\nbbbbb\ncc\n").longestLineUTF16Length, 5)
    }

    /// Dòng cuối KHÔNG kết thúc bằng xuống dòng vẫn phải được tính.
    ///
    /// Bỏ sót nó thì file không có "\n" cuối — rất phổ biến — sẽ ra bề rộng khung chữ thiếu,
    /// và dòng dài nhất bị ngắt ngay cả khi người dùng đã tắt ngắt dòng.
    func testLongestLineCountsAnUnterminatedLastLine() {
        XCTAssertEqual(window("a\nbbbbbbb").longestLineUTF16Length, 7)
    }

    func testLongestLineCountsCellsNotBytes() {
        XCTAssertEqual(window(String(repeating: "ễ", count: 30) + "\nx\n").longestLineUTF16Length, 30)
    }

    func testLongestLineOfEmptyWindowIsZero() {
        XCTAssertEqual(window("").longestLineUTF16Length, 0)
        XCTAssertEqual(window("\n\n").longestLineUTF16Length, 0)
    }

    func testZeroColumnsMeansNoWrap() {
        XCTAssertEqual(window(String(repeating: "x", count: 500) + "\n").rowsPerLine(columnsPerRow: 0), 1)
    }

    func testEmptyWindowIsSafe() {
        let w = window("")
        XCTAssertEqual(w.rowsPerLine(columnsPerRow: 80), 1)
        XCTAssertEqual(w.utf16Length(ofLine: 0), 0)
        XCTAssertEqual(w.utf16Length(ofLine: 999), 0)
    }

    /// Dòng 50.000 ký tự của TC-CORE-13.
    func testFiftyThousandCharacterLine() {
        let w = window(String(repeating: "x", count: 50_000) + "\n")
        XCTAssertEqual(w.utf16Length(ofLine: 0), 50_000)
        // 50.000 ô ở cột 85 = 589 hàng; cộng dòng rỗng cuối rồi chia 2.
        XCTAssertEqual(w.rowsPerLine(columnsPerRow: 85), (589.0 + 1.0) / 2.0, accuracy: 0.0001)
    }
}

/// Tài liệu có byte UTF-8 HỎNG — quy đổi cửa sổ ↔ tài liệu phải vẫn đúng.
final class TextWindowBrokenBytesTests: XCTestCase {

    //
    // Không phải trường hợp bịa. `Document.open` có đường nhanh cho UTF-8: byte trên đĩa vào
    // thẳng buffer qua mmap, KHÔNG kiểm tính hợp lệ — nên chỉ cần mở một file tải dở, một log
    // trộn bảng mã, hay một file Latin-1 bị đoán nhầm là UTF-8 thì buffer đã có byte hỏng.
    //
    // Bộ chạy dài `--soak` tìm ra (hạt giống 11, bước 443): app SẬP ở `PieceTable.bytes(in:)`
    // vì phép quy đổi trả offset 148 trên tài liệu 147 byte. Nguyên nhân: cả `makeWindow` lẫn
    // hai hàm quy đổi đều dựng lại offset byte bằng cách MÃ HOÁ LẠI các scalar đã giải mã, mà
    // một byte hỏng giải mã thành `U+FFFD` rộng 3 byte. Mỗi byte hỏng làm offset trôi thêm 2.
    //
    // Sập chỉ là triệu chứng dễ thấy nhất. Cái đáng sợ hơn là mọi mốc dòng SAU chỗ hỏng cũng
    // lệch, nên một cú bấm chuột hay một lần gõ rơi vào đúng chỗ khác — sai trong im lặng.

    /// Bytes hợp lệ, một byte hỏng (`0xC3` cụt), rồi lại hợp lệ.
    private func brokenBuffer() -> TextBuffer {
        var bytes = Array("Nguyễn\n".utf8)
        bytes.append(0xC3)                       // mở đầu một ký tự 2 byte rồi bỏ dở
        bytes.append(contentsOf: Array("\nTrần Đà Nẵng\n".utf8))
        return TextBuffer(original: MemoryByteSource(bytes))
    }

    func testConversionStaysInsideDocumentWhenBytesAreBroken() {
        let buffer = brokenBuffer()
        let w = TextWindowing.window(range: 0 ..< buffer.count, in: buffer)
        for utf16 in 0 ... w.utf16Count {
            let byte = w.documentOffset(forUTF16Offset: utf16)
            XCTAssertTrue(
                (w.range.lowerBound ... w.range.upperBound).contains(byte),
                "offset UTF-16 \(utf16) cho ra byte \(byte), ngoài cửa sổ \(w.range)")
        }
        XCTAssertEqual(
            w.documentOffset(forUTF16Offset: w.utf16Count), buffer.count,
            "cuối cửa sổ phải là cuối tài liệu")
    }

    /// Hai chiều quy đổi phải khớp nhau, kể cả khi có byte hỏng.
    ///
    /// Đây mới là mệnh đề đáng giữ: chỉ kẹp cho khỏi sập thì hết crash mà offset vẫn sai, và
    /// cái sai ấy đi thẳng vào nội dung người dùng.
    func testConversionRoundTripsWhenBytesAreBroken() {
        let buffer = brokenBuffer()
        let w = TextWindowing.window(range: 0 ..< buffer.count, in: buffer)
        for utf16 in 0 ... w.utf16Count {
            let byte = w.documentOffset(forUTF16Offset: utf16)
            XCTAssertEqual(
                w.utf16Offset(forDocumentOffset: byte), utf16,
                "UTF-16 \(utf16) → byte \(byte) → UTF-16 \(w.utf16Offset(forDocumentOffset: byte))")
        }
    }

    /// Mốc dòng SAU chỗ hỏng vẫn phải trỏ đúng đầu dòng trong tài liệu.
    func testLineStartsStayCorrectAfterBrokenByte() {
        let buffer = brokenBuffer()
        let w = TextWindowing.window(range: 0 ..< buffer.count, in: buffer)
        // Dòng 2 của tài liệu bắt đầu ngay sau "Nguyễn\n" (9 byte) + byte hỏng + "\n" = 11.
        let lineStart = buffer.offset(ofLineStart: 2)
        XCTAssertEqual(lineStart, 11, "mốc của chính buffer — đây là số đối chứng")
        // Quy đổi qua cửa sổ rồi quy đổi ngược phải ra đúng mốc ấy.
        XCTAssertEqual(w.documentOffset(forUTF16Offset: w.utf16Offset(forDocumentOffset: lineStart)),
                       lineStart)
    }

}

/// Quy đổi THEO LÔ — `utf16Offsets(forSortedDocumentOffsets:)`.
///
/// Hàm này sinh ra vì lý do tốc độ (tô màu cột CSV: 37,8 ms → dưới 1 ms), nhưng cái phải canh
/// là TÍNH ĐÚNG: nó giữ một con trỏ đi một chiều, tức nó có trạng thái, tức nó có một lớp lỗi
/// mà bản đơn lẻ không có. Mọi bài dưới đây đối chiếu với chính bản đơn lẻ — thứ đã có bài
/// kiểm riêng từ trước.
extension TextWindowTests {

    private var mixed: String {
        """
        ma,ho_ten,dia_chi
        MA001,Nguyễn Thị Hồng,Số 12 đường Lê Lợi
        MA002,Trần Văn Đức,Phường Bến Nghé
        MA003,Lê Hoàng Phương Uyên,Quận 1

        MA004,Đặng Thị Bích Ngọc,Thành phố Huế
        """ + "\n"
    }

    func testTHEOLOkhopVOIbanDONle() {
        let buffer = TextBuffer(text: mixed)
        let window = TextWindowing.window(around: 0, in: buffer, size: 1 << 20)

        // MỌI offset trong tài liệu, không phải vài chỗ chọn tay: hàm đi theo scalar, nên chỗ
        // hỏng sẽ là một offset rơi vào giữa ký tự nhiều byte — và tiếng Việt thì đầy chỗ ấy.
        let offsets = Array(0 ... buffer.count)
        let batch = window.utf16Offsets(forSortedDocumentOffsets: offsets)
        XCTAssertEqual(batch.count, offsets.count)
        for (index, offset) in offsets.enumerated() {
            XCTAssertEqual(batch[index], window.utf16Offset(forDocumentOffset: offset),
                           "lệch ở offset \(offset)")
        }
    }

    func testDAUVAOSAIthuTUvanCHOketQUAdung() {
        // Điều kiện của hàm là "không giảm", nhưng một chỗ gọi sai thứ tự thì phải ra kết quả
        // ĐÚNG chứ không ra rác — nó chỉ được phép chậm. Không có tính chất này thì mỗi chỗ
        // gọi mới là một cơ hội sinh lỗi im lặng.
        let buffer = TextBuffer(text: mixed)
        let window = TextWindowing.window(around: 0, in: buffer, size: 1 << 20)
        let offsets = [40, 5, 60, 0, 25, 100, 12]
        let batch = window.utf16Offsets(forSortedDocumentOffsets: offsets)
        for (index, offset) in offsets.enumerated() {
            XCTAssertEqual(batch[index], window.utf16Offset(forDocumentOffset: offset),
                           "lệch ở offset \(offset)")
        }
    }

    func testOFFSETngoaiCUASObiKEPnhuBANdonLE() {
        let buffer = TextBuffer(text: mixed)
        // Cửa sổ chỉ ôm phần GIỮA tài liệu, để có cả offset trước và sau nó.
        let window = TextWindowing.window(around: buffer.count / 2, in: buffer, size: 48)
        XCTAssertGreaterThan(window.range.lowerBound, 0, "cửa sổ chưa nằm ở giữa")

        let offsets = [0, 1, window.range.lowerBound, window.range.upperBound, buffer.count]
        let batch = window.utf16Offsets(forSortedDocumentOffsets: offsets.sorted())
        for (index, offset) in offsets.sorted().enumerated() {
            XCTAssertEqual(batch[index], window.utf16Offset(forDocumentOffset: offset),
                           "lệch ở offset \(offset)")
        }
    }

    func testDONGRONGvaMANGRONG() {
        let buffer = TextBuffer(text: mixed)
        let window = TextWindowing.window(around: 0, in: buffer, size: 1 << 20)
        XCTAssertEqual(window.utf16Offsets(forSortedDocumentOffsets: []), [])

        // Dòng rỗng ở giữa tài liệu: hai offset liên tiếp cùng trỏ vào một chỗ, và con trỏ
        // không được nhích.
        let emptyLine = mixed.range(of: "\n\n")!
        let offset = mixed.utf8.distance(from: mixed.utf8.startIndex,
                                         to: emptyLine.lowerBound.samePosition(in: mixed.utf8)!)
        let batch = window.utf16Offsets(forSortedDocumentOffsets: [offset, offset, offset + 1])
        XCTAssertEqual(batch[0], batch[1])
        XCTAssertEqual(batch[2], window.utf16Offset(forDocumentOffset: offset + 1))
    }

    func testTOANBOtaiLIEUmotLUOTdiKHOPtungByte() {
        // Bài này là lý do cả hàm tồn tại: một lượt đi qua cả cửa sổ. Nếu con trỏ trượt một
        // scalar ở đâu đó, mọi offset SAU chỗ ấy đều lệch — và chỉ bài chạy hết mới thấy.
        let buffer = TextBuffer(text: mixed)
        let window = TextWindowing.window(around: 0, in: buffer, size: 1 << 20)
        let batch = window.utf16Offsets(forSortedDocumentOffsets: Array(0 ... buffer.count))
        XCTAssertEqual(batch.last, window.utf16Count,
                       "đi hết tài liệu mà không tới cuối chuỗi")
        // Đơn điệu: offset byte tăng thì offset UTF-16 không được giảm.
        for index in 1 ..< batch.count {
            XCTAssertGreaterThanOrEqual(batch[index], batch[index - 1], "tụt ở chỉ số \(index)")
        }
    }
}
