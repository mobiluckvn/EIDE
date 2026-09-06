import XCTest
@testable import GEditorCore

/// FR-QRY-006 — xuất kết quả truy vấn ra CSV / JSON / Markdown.
final class QueryExportTests: XCTestCase {

    /// Kết quả có đủ ba thứ khó: `NULL`, dấu phẩy, và dấu nháy.
    private let result = CSVQueryEngine.Result(
        titles: ["ma", "ten", "ghi_chu"],
        rows: [
            ["KH01", "Nguyễn An", nil],
            ["KH02", "Lê Lợi, quận 1", "O'Brien \"đã gọi\""],
        ])

    func testCSVbocOcoDauPhayVaDauNhay() {
        let text = QueryExport.text(result, format: .csv)
        XCTAssertTrue(text.hasPrefix("ma,ten,ghi_chu\n"), text)
        XCTAssertTrue(text.contains("\"Lê Lợi, quận 1\""), text)
        XCTAssertTrue(text.contains("\"O'Brien \"\"đã gọi\"\"\""), text)
        // NULL thành ô RỖNG — quy ước CSV, và mất phân biệt với chuỗi rỗng.
        XCTAssertTrue(text.contains("KH01,Nguyễn An,\n"), text)
    }

    func testJSONgiuThuTuCOTvaGiuNULLthat() {
        let text = QueryExport.text(result, format: .json)
        // Thứ tự cột phải theo CÂU TRUY VẤN, không theo bảng chữ cái. `ghi_chu` đứng sau `ten`
        // trong câu, nên nó phải đứng sau trong JSON.
        let firstObject = text.components(separatedBy: "}").first ?? ""
        let maIndex = firstObject.range(of: "\"ma\"")?.lowerBound
        let tenIndex = firstObject.range(of: "\"ten\"")?.lowerBound
        let ghiChuIndex = firstObject.range(of: "\"ghi_chu\"")?.lowerBound
        XCTAssertNotNil(maIndex); XCTAssertNotNil(tenIndex); XCTAssertNotNil(ghiChuIndex)
        XCTAssertTrue(maIndex! < tenIndex!, firstObject)
        XCTAssertTrue(tenIndex! < ghiChuIndex!, firstObject)
        // JSON là định dạng DUY NHẤT trong ba cái giữ được phân biệt NULL / chuỗi rỗng.
        XCTAssertTrue(text.contains("\"ghi_chu\": null"), text)
    }

    func testJSONdocLaiDUOCbangBoDocChuan() throws {
        let text = QueryExport.text(result, format: .json)
        let parsed = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]]
        XCTAssertEqual(parsed?.count, 2)
        XCTAssertEqual(parsed?[1]["ten"] as? String, "Lê Lợi, quận 1")
        XCTAssertTrue(parsed?[0]["ghi_chu"] is NSNull)
    }

    func testJSONkhongThoatCHUTIENGVIET() {
        let text = QueryExport.text(result, format: .json)
        // Thoát `ế` thành `ế` là biến một tệp người đọc được thành tệp phải giải mã.
        XCTAssertTrue(text.contains("Nguyễn An"), text)
        XCTAssertFalse(text.contains("\\u1e"), text)
    }

    func testMarkdownTHOATdauGachDungVaXuongDong() {
        let withPipes = CSVQueryEngine.Result(
            titles: ["a|b"], rows: [["x|y"], ["hai\ndòng"]])
        let text = QueryExport.text(withPipes, format: .markdown)
        // Dấu `|` trong dữ liệu cắt bảng thành cột thừa; xuống dòng cắt cả HÀNG.
        XCTAssertTrue(text.contains("a\\|b"), text)
        XCTAssertTrue(text.contains("x\\|y"), text)
        XCTAssertFalse(text.contains("hai\ndòng"), text)
        XCTAssertTrue(text.contains("hai dòng"), text)
        // Đúng số dòng: tiêu đề + gạch ngăn + 2 hàng.
        XCTAssertEqual(text.split(separator: "\n").count, 4)
    }

    func testMarkdownHienNULLthanhCHU() {
        let text = QueryExport.text(result, format: .markdown)
        // Khác CSV: Markdown là để NGƯỜI ĐỌC, và ô trống giữa bảng trông như chưa điền.
        XCTAssertTrue(text.contains("| NULL |"), text)
    }

    func testDinhDangNhanCaMdLanMarkdown() {
        XCTAssertEqual(QueryExport.Format(argument: "md"), .markdown)
        XCTAssertEqual(QueryExport.Format(argument: "MARKDOWN"), .markdown)
        XCTAssertEqual(QueryExport.Format(argument: "csv"), .csv)
        XCTAssertNil(QueryExport.Format(argument: "xlsx"))
    }

    func testCHANghiDeChinhFileNGUON() {
        // NFR-QRY-03 là P0 trong phạm vi FR-QRY. Chạy `--query … --out . --overwrite *.csv`
        // trong chính thư mục dữ liệu là một lệnh gõ được, trông hợp lý, và phá sạch dữ liệu
        // gốc: kết quả gộp năm dòng đè lên bảng một triệu hàng.
        //
        // Bài này viết SAU khi chuyện ấy xảy ra thật trên fixture nháp trong lúc phát triển.
        XCTAssertTrue(QueryExport.wouldOverwriteSource(
            output: "/du/lieu/a.csv", source: "/du/lieu/a.csv"))
        // `./a.csv` và `a.csv` là cùng một file — người gõ vội thì gõ kiểu nào cũng có.
        XCTAssertTrue(QueryExport.wouldOverwriteSource(
            output: "/du/lieu/./a.csv", source: "/du/lieu/a.csv"))
        XCTAssertTrue(QueryExport.wouldOverwriteSource(
            output: "/du/lieu/x/../a.csv", source: "/du/lieu/a.csv"))
        // Và KHÔNG chặn nhầm đường ra hợp lệ — chặn hết thì tính năng chết.
        XCTAssertFalse(QueryExport.wouldOverwriteSource(
            output: "/du/lieu/ra/a.csv", source: "/du/lieu/a.csv"))
        XCTAssertFalse(QueryExport.wouldOverwriteSource(
            output: "/du/lieu/a.json", source: "/du/lieu/a.csv"))
    }

    func testKetQuaRONGvanRaTIEUDE() {
        let empty = CSVQueryEngine.Result(titles: ["a", "b"], rows: [])
        // Không hàng nào khớp là một câu trả lời ĐÚNG. Một tệp rỗng hoàn toàn thì người nhận
        // không biết truy vấn đã chạy hay chưa.
        XCTAssertEqual(QueryExport.text(empty, format: .csv), "a,b\n")
        XCTAssertTrue(QueryExport.text(empty, format: .markdown).contains("| a | b |"))
        XCTAssertEqual(QueryExport.text(empty, format: .json), "[\n]\n")
    }
}
