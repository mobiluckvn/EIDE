import XCTest
@testable import GEditorCore

/// Sắp xếp theo cột ở Table view (FR-CSV-403).
final class CSVSortTests: XCTestCase {

    private func prepare(_ text: String) throws -> (CSVRowIndex, TextBuffer) {
        let buffer = TextBuffer(text: text)
        return (try CSVRowIndex.build(in: buffer, dialect: .comma), buffer)
    }

    private func column(
        _ index: CSVRowIndex, _ buffer: TextBuffer, _ order: CSVSort.Order, _ column: Int
    ) -> [String] {
        order.rows.map { index.values(ofRow: $0, in: buffer)[column] }
    }

    // MARK: - Sắp xếp hiển thị

    func testSortsTextAscendingAndDescending() throws {
        let (index, buffer) = try prepare("ten,so\nCam,3\nAn,1\nBưởi,2\n")

        let up = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, up, 0), ["An", "Bưởi", "Cam"])

        let down = try CSVSort.order(
            column: 0, direction: .descending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, down, 0), ["Cam", "Bưởi", "An"])
    }

    /// Hàng tiêu đề KHÔNG được tham gia sắp xếp.
    func testHeaderStaysOut() throws {
        let (index, buffer) = try prepare("zzz_ten,so\nCam,3\nAn,1\n")
        let up = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(up.rows, [2, 1], "chỉ hai hàng dữ liệu, hàng 0 đứng ngoài")
    }

    /// Cột số phải so theo SỐ, không theo chuỗi.
    ///
    /// Đối chứng: so theo chuỗi sẽ cho "1000" đứng trước "9".
    func testNumericColumnSortsNumerically() throws {
        let (index, buffer) = try prepare("ma,so\nA,9\nB,1000\nC,80\n")
        let up = try CSVSort.order(
            column: 1, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, up, 1), ["9", "80", "1000"])
        XCTAssertNotEqual(column(index, buffer, up, 1), ["1000", "80", "9"])
    }

    /// Số THẬP PHÂN — chỗ mà so sánh "thông minh theo cụm chữ số" sai.
    ///
    /// `localizedStandardCompare` tách "1.5" thành (1, 5) và "1.25" thành (1, 25), rồi kết
    /// luận 1,5 < 1,25. Đúng cho tên file, sai cho tiền. Bài này chốt rằng cột số đi đường
    /// khác hẳn.
    func testDecimalNumbersAreNotComparedByDigitGroups() throws {
        let (index, buffer) = try prepare("ma,tien\nA,1.5\nB,1.25\nC,1.100\n")
        let up = try CSVSort.order(
            column: 1, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, up, 1), ["1.100", "1.25", "1.5"])

        // Đối chứng: đúng bộ dữ liệu này, cách so theo cụm chữ số cho thứ tự KHÁC.
        let byDigitGroups = ["1.5", "1.25", "1.100"].sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        XCTAssertNotEqual(byDigitGroups, ["1.100", "1.25", "1.5"],
                          "nếu hai cách cho cùng kết quả thì bài này không chứng minh được gì")
    }

    /// Mã chứng từ có số ở cuối phải xếp theo SỐ của phần đuôi.
    ///
    /// Đây là thứ người dùng mong đợi ("M9" trước "M10") và là thứ so chuỗi thuần làm sai.
    func testCodesSortNaturally() throws {
        let (index, buffer) = try prepare("ma,x\nM10,1\nM9,2\nM100,3\nM2,4\n")
        let up = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, up, 0), ["M2", "M9", "M10", "M100"])

        // Đối chứng: so chuỗi thuần cho thứ tự KHÁC — nếu không thì bài này chẳng chứng minh gì.
        XCTAssertEqual(["M10", "M9", "M100", "M2"].sorted(), ["M10", "M100", "M2", "M9"])
    }

    /// Số 0 ở đầu không đổi thứ tự, và hoa/thường không đổi thứ tự.
    func testLeadingZerosAndLetterCaseDoNotChangeOrder() throws {
        let (index, buffer) = try prepare("ma,x\nb007,1\nB7,2\na0009,3\n")
        let up = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, up, 0).first, "a0009")
        // "b007" và "B7" cùng khóa nên hòa, và hòa thì giữ thứ tự file.
        XCTAssertEqual(Array(column(index, buffer, up, 0).suffix(2)), ["b007", "B7"])
    }

    /// Tên tiếng Việt có dấu phải nằm đúng chỗ theo chữ cái gốc, không rơi xuống cuối bảng.
    func testVietnameseNamesSortByBaseLetter() throws {
        let (index, buffer) = try prepare("ten,x\nDương,1\nÂn,2\nBình,3\nAnh,4\n")
        let up = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, up, 0), ["Ân", "Anh", "Bình", "Dương"])

        // Đối chứng: so theo mã Unicode thô đẩy "Ân" và "Bình" xuống sau "Dương".
        XCTAssertEqual(["Dương", "Ân", "Bình", "Anh"].sorted().last, "Ân")
    }

    /// Cột trộn số và chữ thì so theo VĂN BẢN — một kiểu cho cả cột.
    func testMixedColumnFallsBackToText() throws {
        let (index, buffer) = try prepare("ma,gt\nA,10\nB,abc\nC,9\n")
        let up = try CSVSort.order(
            column: 1, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        // Theo văn bản có nhận biết cụm số: 9 < 10 < abc.
        XCTAssertEqual(column(index, buffer, up, 1), ["9", "10", "abc"])
    }

    /// Ô rỗng xuống cuối, cả khi tăng lẫn khi giảm.
    func testEmptyCellsSinkToTheBottomBothWays() throws {
        let (index, buffer) = try prepare("ma,so\nA,5\nB,\nC,1\nD,\n")
        for direction in [CSVSort.Direction.ascending, .descending] {
            let order = try CSVSort.order(
                column: 1, direction: direction, hasHeader: true, index: index, in: buffer
            )
            let values = column(index, buffer, order, 1)
            XCTAssertEqual(Array(values.suffix(2)), ["", ""], "hướng \(direction)")
        }
    }

    /// Hàng thiếu cột không làm lệch bảng.
    func testShortRowsAreTreatedAsEmpty() throws {
        let (index, buffer) = try prepare("a,b,c\n1,2,3\n4\n5,6,7\n")
        let order = try CSVSort.order(
            column: 2, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(order.rows.count, 3)
        XCTAssertEqual(order.rows.last, 2, "hàng thiếu cột coi như rỗng nên xuống cuối")
    }

    /// Giá trị bằng nhau thì giữ nguyên thứ tự file, và giữ ổn định qua nhiều lần sắp.
    func testTiesKeepFileOrderAndAreStable() throws {
        var text = "ma,nhom\n"
        for row in 1 ... 200 { text += "M\(row),X\n" }
        let (index, buffer) = try prepare(text)

        let first = try CSVSort.order(
            column: 1, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(first.rows, Array(1 ... 200), "hòa hết thì phải y nguyên thứ tự file")

        let again = try CSVSort.order(
            column: 1, direction: .descending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(again.rows, first.rows, "đổi hướng khi hòa hết vẫn phải cho cùng thứ tự")
    }

    /// Field bọc ngoặc chứa dấu phân tách phải so theo GIÁ TRỊ THẬT, không so cả dấu bọc.
    func testQuotedValuesCompareByRealValue() throws {
        let (index, buffer) = try prepare("ten,x\n\"Bê, Cê\",1\nAn,2\n\"Ất\",3\n")
        let up = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(column(index, buffer, up, 0), ["An", "Ất", "Bê, Cê"])
    }

    // MARK: - Ghi thứ tự vào file

    func testApplyRewritesTheFileInOneUndoStep() throws {
        let (index, buffer) = try prepare("ten,so\nCam,3\nAn,1\nBưởi,2\n")
        let order = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        let edits = try CSVSort.applyEdits(order, hasHeader: true, index: index, in: buffer)

        XCTAssertEqual(edits.count, 1, "một thao tác hàng loạt = MỘT bước undo (FR-CORE-004)")
        buffer.applyEdits(edits, label: "sắp xếp")
        XCTAssertEqual(
            String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self),
            "ten,so\nAn,1\nBưởi,2\nCam,3\n"
        )

        buffer.undo()
        XCTAssertEqual(
            String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self),
            "ten,so\nCam,3\nAn,1\nBưởi,2\n",
            "một lần undo phải trả về nguyên trạng"
        )
    }

    /// File CRLF giữ nguyên CRLF sau khi ghi thứ tự.
    ///
    /// Đổi cả file sang LF khi người dùng chỉ bấm "sắp xếp" là sửa thứ họ không yêu cầu — và
    /// với Git thì đó là toàn bộ file bị đánh dấu thay đổi.
    func testApplyPreservesCRLF() throws {
        let (index, buffer) = try prepare("ten,so\r\nCam,3\r\nAn,1\r\n")
        let order = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        let edits = try CSVSort.applyEdits(order, hasHeader: true, index: index, in: buffer)
        buffer.applyEdits(edits, label: "sắp xếp")

        let text = String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self)
        XCTAssertEqual(text, "ten,so\r\nAn,1\r\nCam,3\r\n")
        XCTAssertFalse(text.contains("\n\n"), "không được sinh dòng trống")
    }

    /// File không có xuống dòng cuối thì bản đã sắp cũng không được thêm.
    func testApplyDoesNotAddATrailingNewline() throws {
        let (index, buffer) = try prepare("ten,so\nCam,3\nAn,1")
        let order = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        buffer.applyEdits(
            try CSVSort.applyEdits(order, hasHeader: true, index: index, in: buffer),
            label: "sắp xếp"
        )
        XCTAssertEqual(
            String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self),
            "ten,so\nAn,1\nCam,3"
        )
    }

    /// Ghi thứ tự KHÔNG được làm hỏng field bọc ngoặc có xuống dòng bên trong.
    func testApplyKeepsQuotedMultilineFieldsIntact() throws {
        let source = "ten,ghi_chu\nCam,\"dòng 1\ndòng 2\"\nAn,ngắn\n"
        let (index, buffer) = try prepare(source)
        let order = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        buffer.applyEdits(
            try CSVSort.applyEdits(order, hasHeader: true, index: index, in: buffer),
            label: "sắp xếp"
        )
        XCTAssertEqual(
            String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self),
            "ten,ghi_chu\nAn,ngắn\nCam,\"dòng 1\ndòng 2\"\n"
        )

        // Và bảng đọc lại vẫn thấy đúng hai hàng dữ liệu.
        let rebuilt = try CSVRowIndex.build(in: buffer, dialect: .comma)
        XCTAssertEqual(rebuilt.rowCount, 3)
        XCTAssertEqual(rebuilt.values(ofRow: 2, in: buffer), ["Cam", "dòng 1\ndòng 2"])
    }

    /// Sắp xếp hiển thị KHÔNG đụng vào file.
    ///
    /// Đây là bất biến quan trọng nhất của FR-CSV-403 (NT-5): bấm tiêu đề để nhìn, không phải
    /// để sửa.
    func testDisplaySortLeavesTheDocumentUntouched() throws {
        let source = "ten,so\nCam,3\nAn,1\n"
        let (index, buffer) = try prepare(source)
        _ = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
        )
        XCTAssertEqual(String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self), source)
        XCTAssertFalse(buffer.canUndo, "sắp xếp hiển thị không được sinh bước undo nào")
    }

    /// File không có hàng tiêu đề: mọi hàng đều tham gia.
    func testWithoutHeaderEveryRowSorts() throws {
        let (index, buffer) = try prepare("Cam,3\nAn,1\n")
        let order = try CSVSort.order(
            column: 0, direction: .ascending, hasHeader: false, index: index, in: buffer
        )
        XCTAssertEqual(order.rows, [1, 0])

        buffer.applyEdits(
            try CSVSort.applyEdits(order, hasHeader: false, index: index, in: buffer),
            label: "sắp xếp"
        )
        XCTAssertEqual(
            String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self), "An,1\nCam,3\n"
        )
    }

    func testEmptyAndSingleRowDocuments() throws {
        for text in ["", "chỉ,tiêu,đề\n"] {
            let (index, buffer) = try prepare(text)
            let order = try CSVSort.order(
                column: 0, direction: .ascending, hasHeader: true, index: index, in: buffer
            )
            XCTAssertTrue(order.rows.isEmpty)
            XCTAssertTrue(try CSVSort.applyEdits(
                order, hasHeader: true, index: index, in: buffer
            ).isEmpty, "không có gì để ghi thì không sinh sửa đổi")
        }
    }
}
