import XCTest
@testable import GEditorCore

/// Bài kiểm cho bộ đọc `.xlsx`.
///
/// **Fixture do một hiện thực ĐỘC LẬP ghi ra**, đúng luật đã học ở `ZipArchiveTests`: tệp
/// `.xlsx` thật trong `docs/` (Excel ghi), và tệp do LibreOffice chuyển từ CSV. Tự dựng XML
/// theo hiểu biết của chính người viết bộ đọc thì bài kiểm chỉ xác nhận lại hiểu biết ấy —
/// hiểu sai chỗ nào sẽ dựng fixture sai đúng chỗ ấy và vẫn xanh.
final class XLSXReaderTests: XCTestCase {

    // MARK: - Tệp Excel THẬT trong kho

    func testDOCXLSXthatTrongKhoDocRaSheetVaHang() throws {
        let path = kho("docs/TongHop_TinhNang_GEditor_v2.0.xlsx")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path), "không có xlsx mẫu")

        let reader = try XLSXReader(path: path)
        XCTAssertFalse(reader.sheets.isEmpty, "không thấy sheet nào")
        // Tên sheet phải là tên THẬT, không phải "Sheet1" bịa ra.
        XCTAssertFalse(reader.sheets[0].name.isEmpty)

        let grid = try reader.firstGrid()
        XCTAssertFalse(grid.rows.isEmpty, "sheet đầu không có hàng nào")
        XCTAssertGreaterThan(grid.columnCount, 1, "chỉ đọc ra một cột — nhiều khả năng ô thưa bị dồn")
        // Mọi hàng phải cùng bề rộng: bảng răng cưa làm mọi thứ phía sau phải tự đoán.
        XCTAssertTrue(grid.rows.allSatisfy { $0.count == grid.columnCount },
                      "hàng không được đệm về cùng bề rộng")
        XCTAssertFalse(grid.truncated)

        // Có chữ thật, không phải toàn ô rỗng.
        let text = grid.rows.flatMap { $0 }.joined()
        XCTAssertGreaterThan(text.count, 50, "đọc ra gần như không có nội dung")
    }

    // MARK: - Tệp do LibreOffice ghi

    func testTEPdoLIBREOFFICEghiRaDocDungGiaTri() throws {
        let path = try dungXLSX("""
            ten,ngay,so,ghi chu
            An,2025-01-15,3.5,binh thuong
            "Bình, Nguyễn",2024-12-31,-2,"có dấu phẩy"
            """)
        defer { try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent) }

        let grid = try XLSXReader(path: path).firstGrid()
        XCTAssertEqual(grid.rows.count, 3, "số hàng sai: \(grid.rows)")
        XCTAssertEqual(grid.rows[0], ["ten", "ngay", "so", "ghi chu"])

        // Ô có dấu phẩy: giá trị phải NGUYÊN VẸN, việc trích dẫn là chuyện của lúc ghi CSV.
        XCTAssertEqual(grid.rows[2][0], "Bình, Nguyễn")
        XCTAssertEqual(grid.rows[1][0], "An")

        // Ngày: LibreOffice nhận `2025-01-15` thành NGÀY, nên ô lưu số sê-ri kèm định dạng
        // ngày. Đọc ra phải là ngày, không phải "45672".
        XCTAssertEqual(grid.rows[1][1], "2025-01-15",
                       "ngày ra «\(grid.rows[1][1])» — số sê-ri chưa được đổi")
        XCTAssertEqual(grid.rows[2][1], "2024-12-31")

        // Số âm và số thập phân giữ nguyên.
        XCTAssertEqual(Double(grid.rows[1][2]), 3.5)
        XCTAssertEqual(Double(grid.rows[2][2]), -2)
    }

    func testOTHUAKHONGbiDonCot() throws {
        // Cột B của hàng 2 để trống hoàn toàn — trong XLSX ô ấy VẮNG MẶT, không phải rỗng.
        // Bỏ qua thuộc tính `r` của ô thì "z" sẽ nhảy lên cột B.
        let path = try dungXLSX("""
            a,b,c
            x,,z
            """)
        defer { try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent) }

        let grid = try XLSXReader(path: path).firstGrid()
        XCTAssertEqual(grid.rows.count, 2)
        XCTAssertEqual(grid.rows[1], ["x", "", "z"], "ô trống bị dồn cột")
    }

    // MARK: - Nhánh thuần tính toán

    func testTHAMCHIEUOdoiRaChiSoCot() {
        XCTAssertEqual(XLSXReader.columnIndex(ofReference: "A1"), 0)
        XCTAssertEqual(XLSXReader.columnIndex(ofReference: "B12"), 1)
        XCTAssertEqual(XLSXReader.columnIndex(ofReference: "Z9"), 25)
        XCTAssertEqual(XLSXReader.columnIndex(ofReference: "AA1"), 26)
        XCTAssertEqual(XLSXReader.columnIndex(ofReference: "AB1"), 27)
        XCTAssertEqual(XLSXReader.columnIndex(ofReference: "BA1"), 52)
        // Chữ thường vẫn phải nhận — không phải công cụ nào cũng viết hoa.
        XCTAssertEqual(XLSXReader.columnIndex(ofReference: "c3"), 2)
        XCTAssertNil(XLSXReader.columnIndex(ofReference: "12"))
        XCTAssertNil(XLSXReader.columnIndex(ofReference: ""))
    }

    func testMOCNGAYla30_12_1899chuKhongPhai01_01_1900() {
        // Excel cố ý giữ lỗi của Lotus: nó tin 1900 là năm nhuận. Lấy mốc 01/01/1900 sẽ đúng
        // cho mọi ngày từ 01/03/1900 và LỆCH MỘT NGÀY cho hai tháng đầu năm ấy.
        XCTAssertEqual(XLSXReader.date(fromSerial: 1, uses1904: false), "1899-12-31")
        XCTAssertEqual(XLSXReader.date(fromSerial: 59, uses1904: false), "1900-02-27")
        XCTAssertEqual(XLSXReader.date(fromSerial: 61, uses1904: false), "1900-03-01")
        // Một ngày ai cũng kiểm được: 45.672 là 15/01/2025.
        XCTAssertEqual(XLSXReader.date(fromSerial: 45_672, uses1904: false), "2025-01-15")
        // Phần lẻ thành giờ; ngày tròn thì KHÔNG in "00:00:00".
        XCTAssertEqual(XLSXReader.date(fromSerial: 45_672.5, uses1904: false), "2025-01-15 12:00:00")
        // Hệ 1904 của Mac cũ lệch đúng 1.462 ngày.
        XCTAssertEqual(XLSXReader.date(fromSerial: 45_672 - 1_462, uses1904: true), "2025-01-15")
        XCTAssertNil(XLSXReader.date(fromSerial: -1, uses1904: false))
    }

    func testDINHDANGtuDatNhanRaNgayNhungKHONGnhanNhamTIENTE() {
        XCTAssertTrue(XLSXStyleParser.looksLikeDate("dd/mm/yyyy"))
        XCTAssertTrue(XLSXStyleParser.looksLikeDate("yyyy-mm-dd hh:mm"))
        // Ký tự ngày nằm trong CHUỖI HIỂN THỊ thì không tính — đây là chỗ dễ sai nhất.
        XCTAssertFalse(XLSXStyleParser.looksLikeDate("#,##0\" đ\""))
        XCTAssertFalse(XLSXStyleParser.looksLikeDate("0.00"))
        XCTAssertFalse(XLSXStyleParser.looksLikeDate("\"Ngày\"0"))
        // Phần trong ngoặc vuông (mã ngôn ngữ, màu) cũng phải bỏ qua.
        XCTAssertFalse(XLSXStyleParser.looksLikeDate("[$-409]#,##0"))
        XCTAssertTrue(XLSXStyleParser.looksLikeDate("[$-409]dd-mmm-yy"))
    }

    func testGHIRAcsvTHIOCODAUPHAYduocTRICHDAN() {
        let grid = XLSXReader.Grid(
            rows: [["a", "b,c"], ["d\"e", "f\ng"]], truncated: false, columnCount: 2)
        XCTAssertEqual(XLSXReader.csv(from: grid), "a,\"b,c\"\n\"d\"\"e\",\"f\ng\"\n")
    }

    func testOCOKHOANGTRANGdauCuoiCUNGphaiDuocBOC() {
        // Ca này là chỗ bản `quote` tự viết đã lệch với `CSVEngine.escape` của lõi: không bọc
        // thì đọc lại mất khoảng trắng, và ô " An " thành "An" một cách hoàn toàn im lặng.
        let grid = XLSXReader.Grid(
            rows: [[" An ", "x"]], truncated: false, columnCount: 2)
        XCTAssertEqual(XLSXReader.csv(from: grid), "\" An \",x\n")
    }

    // MARK: - Trợ giúp

    /// Dựng `.xlsx` bằng LibreOffice — một hiện thực hoàn toàn độc lập với bộ đọc này.
    private func dungXLSX(_ csv: String) throws -> String {
        let soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: soffice),
                          "không có LibreOffice trên máy này")

        let root = NSTemporaryDirectory() + "/geditor-xlsx-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        let source = root + "/bang.csv"
        try Data((csv + "\n").utf8).write(to: URL(fileURLWithPath: source))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: soffice)
        process.arguments = ["--headless", "--convert-to", "xlsx", "--outdir", root, source]
        // LibreOffice dùng chung một hồ sơ người dùng; hai lần chạy song song sẽ tranh nhau.
        process.environment = ProcessInfo.processInfo.environment
            .merging(["HOME": root]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let out = root + "/bang.xlsx"
        guard FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("LibreOffice không chuyển được tệp")
        }
        return out
    }

    private func kho(_ relative: String) -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent(relative).path
    }
}
