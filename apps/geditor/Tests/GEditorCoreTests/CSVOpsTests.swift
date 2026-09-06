import XCTest
@testable import GEditorCore

/// Kiểm thử thao tác cấu trúc trên CSV (FR-CSV-404, FR-CSV-405, FR-CSV-406).
final class CSVOpsTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func apply(
        _ edits: [TextEdit], to buffer: TextBuffer, file: StaticString = #filePath, line: UInt = #line
    ) -> String {
        let before = buffer.text
        buffer.applyEdits(edits, label: "Kiểm thử")
        let after = buffer.text
        XCTAssertTrue(buffer.undo(), file: file, line: line)
        XCTAssertEqual(buffer.text, before, file: file, line: line)
        XCTAssertFalse(buffer.canUndo, "phải là ĐÚNG MỘT bước undo", file: file, line: line)
        buffer.redo()
        return after
    }

    // MARK: - Chèn cột (FR-CSV-404)

    func testInsertColumnInTheMiddle() throws {
        let target = buffer("a,b,c\n1,2,3\n")
        XCTAssertEqual(
            apply(try CSVOps.insertColumn(at: 1, in: target, dialect: .comma), to: target),
            "a,,b,c\n1,,2,3\n"
        )
    }

    func testInsertColumnAtTheStartAndEnd() throws {
        let head = buffer("a,b\n1,2\n")
        XCTAssertEqual(
            apply(try CSVOps.insertColumn(at: 0, in: head, dialect: .comma), to: head),
            ",a,b\n,1,2\n"
        )
        let tail = buffer("a,b\n1,2\n")
        XCTAssertEqual(
            apply(try CSVOps.insertColumn(at: 2, in: tail, dialect: .comma), to: tail),
            "a,b,\n1,2,\n"
        )
    }

    /// Chèn cột không được làm vỡ field bọc ngoặc.
    func testInsertColumnKeepsQuotedFieldsIntact() throws {
        let target = buffer("a,b\n\"x, y\",2\n")
        XCTAssertEqual(
            apply(try CSVOps.insertColumn(at: 1, in: target, dialect: .comma), to: target),
            "a,,b\n\"x, y\",,2\n"
        )
    }

    /// Mọi hàng tăng ĐÚNG MỘT field, kể cả hàng vốn thiếu cột.
    ///
    /// Hàng lệch cột vẫn lệch y như cũ chứ không lệch thêm — bỏ qua chúng sẽ làm số cột của
    /// chúng lệch một bậc so với phần còn lại của file.
    func testInsertColumnKeepsRaggedRowsEquallyRagged() throws {
        let target = buffer("a,b,c\n1\n2,3,4\n")
        let after = apply(try CSVOps.insertColumn(at: 2, in: target, dialect: .comma), to: target)
        XCTAssertEqual(after, "a,b,,c\n1,\n2,3,,4\n")

        let rows = CSVEngine.parse(Array(after.utf8), dialect: .comma)
        XCTAssertEqual(rows.map(\.count), [4, 2, 4], "mỗi hàng tăng đúng một field")
    }

    // MARK: - Đổi tên tiêu đề (FR-CSV-408)

    func testRenameHeaderTouchesOnlyTheFirstRow() throws {
        let target = buffer("ten,so\nten,1\n")
        XCTAssertEqual(
            apply(try CSVOps.renameHeader(0, to: "ho_ten", in: target, dialect: .comma), to: target),
            "ho_ten,so\nten,1\n",
            "chỉ hàng tiêu đề được đổi, dữ liệu trùng tên phải nguyên vẹn"
        )
    }

    /// Tên có dấu phân tách phải được bọc lại.
    ///
    /// Ghi thẳng thì hàng tiêu đề tách thành hai cột và lệch khỏi toàn bộ dữ liệu bên dưới.
    func testRenameHeaderEscapesTheNewName() throws {
        let target = buffer("a,b\n1,2\n")
        let after = apply(
            try CSVOps.renameHeader(0, to: "Doanh thu, VNĐ", in: target, dialect: .comma), to: target
        )
        XCTAssertEqual(after, "\"Doanh thu, VNĐ\",b\n1,2\n")
        XCTAssertEqual(CSVEngine.parse(Array(after.utf8), dialect: .comma)[0].count, 2,
                       "hàng tiêu đề vẫn phải có đúng hai cột")
    }

    func testRenameHeaderIgnoresColumnsThatDoNotExist() throws {
        let target = buffer("a,b\n1,2\n")
        XCTAssertTrue(try CSVOps.renameHeader(9, to: "x", in: target, dialect: .comma).isEmpty)
    }

    // MARK: - Hoán vị cột (FR-CSV-404)

    func testMoveColumnRightAndLeft() throws {
        let right = buffer("a,b,c\n1,2,3\n")
        XCTAssertEqual(
            apply(try CSVOps.moveColumn(from: 0, to: 2, in: right, dialect: .comma), to: right),
            "b,c,a\n2,3,1\n"
        )
        let left = buffer("a,b,c\n1,2,3\n")
        XCTAssertEqual(
            apply(try CSVOps.moveColumn(from: 2, to: 0, in: left, dialect: .comma), to: left),
            "c,a,b\n3,1,2\n"
        )
    }

    /// Field bọc ngoặc chứa dấu phẩy VÀ xuống dòng phải sang chỗ mới nguyên vẹn.
    func testMoveColumnCopiesRawBytesOfQuotedFields() throws {
        let target = buffer("ma,ghi_chu,so\nA,\"có phẩy, và\nxuống dòng\",7\n")
        let after = apply(
            try CSVOps.moveColumn(from: 1, to: 2, in: target, dialect: .comma), to: target
        )
        XCTAssertEqual(after, "ma,so,ghi_chu\nA,7,\"có phẩy, và\nxuống dòng\"\n")

        let rows = CSVEngine.parse(Array(after.utf8), dialect: .comma)
        XCTAssertEqual(rows.count, 2, "vẫn là hai hàng logic")
        XCTAssertEqual(rows[1].count, 3)
    }

    /// Field bọc dù KHÔNG CẦN bọc phải giữ nguyên cách bọc của người dùng.
    ///
    /// Đây là điều mà "bóc ra rồi bọc lại" làm sai — và bài kiểm này là bài duy nhất bắt được
    /// nó: đối chứng âm cho thấy mọi bài khác vẫn xanh khi đổi sang bóc-bọc, vì nội dung
    /// không đổi. Cái đổi là CÁCH BỌC, ở những hàng người dùng không hề đụng tới; với Git thì
    /// đó là cả file bị đánh dấu thay đổi chỉ vì một lần hoán vị cột.
    func testMoveColumnKeepsRedundantQuotingAsWritten() throws {
        let target = buffer("a,b\n\"abc\",2\n")
        XCTAssertEqual(
            apply(try CSVOps.moveColumn(from: 0, to: 1, in: target, dialect: .comma), to: target),
            "b,a\n2,\"abc\"\n",
            "dấu bọc thừa là của người dùng, không phải thứ để thao tác cột dọn dẹp"
        )
    }

    /// `""` bên trong field bọc phải giữ nguyên là hai dấu.
    func testMoveColumnKeepsDoubledQuotes() throws {
        let target = buffer("a,b\n\"nói \"\"xin chào\"\"\",2\n")
        XCTAssertEqual(
            apply(try CSVOps.moveColumn(from: 0, to: 1, in: target, dialect: .comma), to: target),
            "b,a\n2,\"nói \"\"xin chào\"\"\"\n"
        )
    }

    func testMoveColumnSkipsRowsWithoutThatColumn() throws {
        let target = buffer("a,b,c\n1,2,3\n4\n")
        XCTAssertEqual(
            apply(try CSVOps.moveColumn(from: 0, to: 2, in: target, dialect: .comma), to: target),
            "b,c,a\n2,3,1\n4\n",
            "hàng thiếu cột phải để nguyên"
        )
    }

    func testMoveColumnToItselfChangesNothing() throws {
        let target = buffer("a,b\n1,2\n")
        XCTAssertTrue(try CSVOps.moveColumn(from: 1, to: 1, in: target, dialect: .comma).isEmpty)
    }

    // MARK: - Xóa cột (TC-CSV-03)

    func testDeleteMiddleColumn() throws {
        let target = buffer("a,b,c\n1,2,3\n")
        let edits = try CSVOps.deleteColumn(1, in: target, dialect: .comma)
        XCTAssertEqual(apply(edits, to: target), "a,c\n1,3\n")
    }

    func testDeleteFirstColumn() throws {
        let target = buffer("a,b,c\n1,2,3\n")
        let edits = try CSVOps.deleteColumn(0, in: target, dialect: .comma)
        XCTAssertEqual(apply(edits, to: target), "b,c\n2,3\n")
    }

    func testDeleteLastColumnRemovesPrecedingDelimiter() throws {
        let target = buffer("a,b,c\n1,2,3\n")
        let edits = try CSVOps.deleteColumn(2, in: target, dialect: .comma)
        XCTAssertEqual(apply(edits, to: target), "a,b\n1,2\n", "không được để lại dấu phẩy thừa")
    }

    /// Yêu cầu cốt lõi của TC-CSV-03: quoted field ở các cột khác phải NGUYÊN VẸN.
    func testQuotedFieldsInOtherColumnsSurvive() throws {
        // Dấu phân cách mở rộng (#"""…"""#) vì nội dung CSV chứa chính chuỗi ba dấu kép:
        // một field bọc, kết thúc bằng dấu kép escape, rồi dấu kép đóng field.
        let source = #"""
        DH-01,"Anh Đào, CN Huế",300,"ghi chú ""đặc biệt"""
        DH-02,"Sông Hàn",100,"bình thường"

        """#
        let target = buffer(source)
        let edits = try CSVOps.deleteColumn(2, in: target, dialect: .comma)
        XCTAssertEqual(apply(edits, to: target), #"""
        DH-01,"Anh Đào, CN Huế","ghi chú ""đặc biệt"""
        DH-02,"Sông Hàn","bình thường"

        """#)
    }

    /// Xóa chính cột đang bọc ngoặc kép và chứa dấu phẩy — chỗ dễ cắt nhầm nhất.
    func testDeleteQuotedColumnContainingDelimiter() throws {
        let target = buffer("a,\"x, y\",c\n")
        let edits = try CSVOps.deleteColumn(1, in: target, dialect: .comma)
        XCTAssertEqual(apply(edits, to: target), "a,c\n")
    }

    /// Field bọc chứa XUỐNG DÒNG: một hàng logic trải trên hai dòng vật lý. Thao tác nào coi
    /// "dòng" là "hàng" sẽ cắt sai ngay tại đây.
    func testRowSpanningPhysicalLines() throws {
        let target = buffer("a,\"dòng 1\ndòng 2\",c\nd,e,f\n")
        let edits = try CSVOps.deleteColumn(1, in: target, dialect: .comma)
        XCTAssertEqual(apply(edits, to: target), "a,c\nd,f\n")
    }

    /// Dữ liệu thật có dòng thiếu cột. Xóa cột 3 không được đụng vào dòng chỉ có 2 cột.
    func testRowsWithoutThatColumnAreUntouched() throws {
        let target = buffer("a,b,c\nchỉ,hai\nd,e,f\n")
        let edits = try CSVOps.deleteColumn(2, in: target, dialect: .comma)
        XCTAssertEqual(apply(edits, to: target), "a,b\nchỉ,hai\nd,e\n")
    }

    func testDeleteColumnWithSemicolonDialect() throws {
        let target = buffer("a;b;c\n1;2;3\n")
        let edits = try CSVOps.deleteColumn(1, in: target, dialect: .semicolon)
        XCTAssertEqual(apply(edits, to: target), "a;c\n1;3\n")
    }

    func testDeleteColumnOutOfRangeIsNoOp() throws {
        let target = buffer("a,b\n")
        XCTAssertTrue(try CSVOps.deleteColumn(5, in: target, dialect: .comma).isEmpty)
    }

    // MARK: - CSV → JSON (TC-CSV-07)

    /// Đối chứng bằng `jq`, đúng như TC-CSV-07 mô tả: JSON của ta phải là JSON HỢP LỆ theo
    /// một bộ phân tích độc lập, không phải theo cách đọc của chính ta.
    func testJSONIsValidAccordingToJQ() throws {
        let source = #"""
        mã,tên,ghi chú
        DH-01,"Anh Đào, CN Huế","có dấu ""kép"" bên trong"
        DH-02,Sông Hàn,dòng thường

        """#
        let json = try CSVOps.toJSON(buffer(source), dialect: .comma)

        let parsed = try runJQ(json, filter: ".")
        XCTAssertFalse(parsed.isEmpty, "jq phải phân tích được")

        XCTAssertEqual(try runJQ(json, filter: "length"), "2", "số bản ghi phải khớp")
        XCTAssertEqual(try runJQ(json, filter: ".[0].\"tên\"", raw: true), "Anh Đào, CN Huế",
                       "dấu phẩy trong field bọc phải giữ nguyên")
        XCTAssertEqual(try runJQ(json, filter: ".[0].\"ghi chú\"", raw: true), "có dấu \"kép\" bên trong",
                       "\"\" của CSV phải thành một dấu kép, escape đúng trong JSON")
        XCTAssertEqual(try runJQ(json, filter: ".[1].\"mã\"", raw: true), "DH-02")
    }

    func testJSONEscapesControlCharacters() throws {
        let target = buffer("a\n\"dòng 1\ndòng 2\"\n")
        let json = try CSVOps.toJSON(target, dialect: .comma)
        XCTAssertTrue(json.contains("\\n"), "xuống dòng trong field phải được escape: \(json)")
        XCTAssertEqual(try runJQ(json, filter: ".[0].a", raw: true), "dòng 1\ndòng 2")
    }

    func testJSONWithoutHeaderUsesGeneratedKeys() throws {
        let json = try CSVOps.toJSON(buffer("1,2\n3,4\n"), dialect: .comma, hasHeader: false)
        XCTAssertEqual(try runJQ(json, filter: "length"), "2")
        XCTAssertEqual(try runJQ(json, filter: ".[0].\"cột1\"", raw: true), "1")
    }

    func testEmptyDocumentBecomesEmptyArray() throws {
        XCTAssertEqual(try CSVOps.toJSON(buffer(""), dialect: .comma), "[]")
    }

    // MARK: - Đọc theo cửa sổ (không dựng cả tài liệu trong RAM)

    /// Đọc theo cửa sổ phải cho ra kết quả GIỐNG HỆT đọc một lần, với MỌI kích thước cửa sổ.
    ///
    /// Đây là chỗ rủi ro của streaming: hàng bị cắt ở biên cửa sổ. Quét qua nhiều kích thước
    /// cửa sổ nhỏ đảm bảo biên rơi vào đủ mọi vị trí — giữa field, giữa dấu bọc, giữa CRLF.
    func testWindowedParseMatchesWholeParseAtEveryWindowSize() throws {
        let source = #"""
        mã,tên,số
        DH-01,"Anh Đào, CN Huế",300
        DH-02,"nhiều
        dòng",100
        DH-03,"dấu ""kép""",200
        DH-04,ngắn,1

        """#
        let target = buffer(source)
        let bytes = Array(source.utf8)
        let expected = CSVEngine.parse(bytes, dialect: .comma).map { row in
            row.map { $0.range }
        }

        for window in [8, 16, 32, 64, 128, 4096] {
            var actual: [[Range<Int>]] = []
            try CSVEngine.forEachRow(in: target, dialect: .comma, windowBytes: window) { row in
                actual.append(row.map { $0.range })
                return true
            }
            XCTAssertEqual(actual, expected, "cửa sổ \(window) byte cho kết quả khác")
        }
    }

    /// Một hàng dài hơn cả cửa sổ: phải NỚI cửa sổ chứ không kẹt tại chỗ hoặc bỏ sót hàng.
    func testRowLongerThanWindowStillParses() throws {
        let long = String(repeating: "x", count: 5_000)
        let target = buffer("a,b\n\"\(long)\",c\n")

        var rows = 0
        try CSVEngine.forEachRow(in: target, dialect: .comma, windowBytes: 64) { row in
            rows += 1
            return true
        }
        XCTAssertEqual(rows, 2)
    }

    /// Xóa cột phải ra kết quả như nhau dù cửa sổ nhỏ tới đâu — đường mà TC-CSV-03 đi.
    func testDeleteColumnIsIndependentOfWindowSize() throws {
        let source = "a,\"x, y\",c\nd,\"nhiều\ndòng\",f\ng,h,i\n"
        let expected: String = {
            let target = buffer(source)
            let edits = try! CSVOps.deleteColumn(1, in: target, dialect: .comma)
            target.applyEdits(edits, label: "x")
            return target.text
        }()

        for window in [8, 24, 100] {
            let target = buffer(source)
            var edits: [TextEdit] = []
            try CSVEngine.forEachRow(in: target, dialect: .comma, windowBytes: window) { row in
                guard row.count > 1 else { return true }
                edits.append(TextEdit(
                    range: row[1].range.lowerBound ..< row[2].range.lowerBound, bytes: []
                ))
                return true
            }
            target.applyEdits(edits, label: "x")
            XCTAssertEqual(target.text, expected, "cửa sổ \(window) byte cho kết quả khác")
        }
    }

    func testStreamingStopsEarlyWhenAsked() throws {
        let target = buffer(String(repeating: "a,b,c\n", count: 1_000))
        var seen = 0
        try CSVEngine.forEachRow(in: target, dialect: .comma, windowBytes: 16) { _ in
            seen += 1
            return seen < 5
        }
        XCTAssertEqual(seen, 5, "trả false phải dừng ngay, không quét nốt tài liệu")
    }

    // MARK: - Tiện ích

    /// Chạy `jq` với chương trình truyền qua FILE, không qua tham số dòng lệnh.
    ///
    /// Bẫy đã mất công truy: `Process.arguments` trên macOS chuyển tham số sang dạng biểu
    /// diễn của hệ thống file, tức CHUẨN HÓA VỀ NFD. Chuỗi `"cột1"` (4 điểm mã, NFC) gửi đi
    /// thì `jq` nhận được 6 điểm mã NFD, nên nó không khớp với khóa NFC trong JSON trên
    /// stdin — và trả `null` một cách hoàn toàn im lặng. Nội dung FILE thì không bị đụng tới.
    ///
    /// Điều này đúng với mọi chuỗi có dấu truyền qua argv, không riêng jq.
    private func runJQ(_ json: String, filter: String, raw: Bool = false) throws -> String {
        let jq = "/usr/bin/jq"
        guard FileManager.default.isExecutableFile(atPath: jq) else {
            throw XCTSkip("không có jq trên máy này")
        }

        let program = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-\(UUID().uuidString).jq")
        try Data(filter.utf8).write(to: program)
        defer { try? FileManager.default.removeItem(at: program) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: jq)
        process.arguments = (raw ? ["-r"] : []) + ["-f", program.path]

        let input = Pipe(), output = Pipe(), errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        input.fileHandleForWriting.write(Data(json.utf8))
        input.fileHandleForWriting.closeFile()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let problem = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            XCTFail("jq \(filter) thất bại: \(problem)\nJSON:\n\(json)")
            return ""
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
