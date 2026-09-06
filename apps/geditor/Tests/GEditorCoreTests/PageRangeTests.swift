import XCTest
@testable import GEditorCore

final class PageRangeTests: XCTestCase {

    private func parse(_ text: String, _ pageCount: Int = 10) throws -> [Int] {
        Array(try PageRange.parse(text, pageCount: pageCount)).sorted()
    }

    // MARK: - Dạng đúng

    func testMOTtrang() throws {
        XCTAssertEqual(try parse("5"), [4], "vào 1-based, ra 0-based")
    }

    func testKHOANGtrang() throws {
        XCTAssertEqual(try parse("2-4"), [1, 2, 3])
    }

    func testNHIEUmucNGANcachBANGphay() throws {
        XCTAssertEqual(try parse("1,3-4,7"), [0, 2, 3, 6])
    }

    func testDAUgachOdauLAtuTRANGmot() throws {
        XCTAssertEqual(try parse("-3"), [0, 1, 2])
    }

    func testDAUgachOcuoiLAtoiTRANGcuoi() throws {
        XCTAssertEqual(try parse("8-"), [7, 8, 9])
    }

    func testKHOANGtrangTHUAvanDOCduoc() throws {
        XCTAssertEqual(try parse(" 1 - 2 , 5 "), [0, 1, 4])
    }

    func testCACmucTRUNGnhauGOPlaiKHONGnhanDOI() throws {
        XCTAssertEqual(try parse("1-3,2-4"), [0, 1, 2, 3])
    }

    func testMOTtrangDUYnhatTRONGtaiLIEUmotTRANG() throws {
        XCTAssertEqual(try parse("1", 1), [0])
    }

    // MARK: - Từ chối chứ không đoán

    func testCHUOIrongBIchanCHUkhongHIEUngamLAtatCA() {
        // Một lệnh XOÁ chạy trên "tất cả" vì người dùng quên gõ gì là cách hỏng tệ nhất.
        XCTAssertThrowsError(try parse("")) { error in
            XCTAssertTrue("\(error)".contains("Chưa nhập trang nào"), "\(error)")
        }
        XCTAssertThrowsError(try parse("   "))
    }

    func testDAYnguocBItuCHOIchuKHONGtuDAO() {
        XCTAssertThrowsError(try parse("5-2")) { error in
            XCTAssertTrue("\(error)".contains("viết ngược"), "\(error)")
        }
    }

    func testVUOTsoTRANGbiTUchoiCHUkhongCATbot() {
        // Cắt bớt biến một câu SAI thành một câu chạy được, và người dùng không bao giờ biết.
        XCTAssertThrowsError(try parse("1-999")) { error in
            XCTAssertTrue("\(error)".contains("10 trang"), "phải nói tài liệu có mấy trang: \(error)")
        }
        XCTAssertThrowsError(try parse("11"))
    }

    func testTRANGkhongBIchanTUso0hoacSOam() {
        XCTAssertThrowsError(try parse("0")) { error in
            XCTAssertTrue("\(error)".contains("đếm từ 1"), "\(error)")
        }
    }

    func testCHUkhongPHAIsoBIchan() {
        XCTAssertThrowsError(try parse("abc"))
        XCTAssertThrowsError(try parse("1-x"))
    }

    func testTHUAdauPHAYbiCHAN() {
        XCTAssertThrowsError(try parse("1,,3")) { error in
            XCTAssertTrue("\(error)".contains("thừa dấu phẩy"), "\(error)")
        }
    }

    func testTAIlieuKHONGtrangTHIchanNGAY() {
        XCTAssertThrowsError(try PageRange.parse("1", pageCount: 0))
    }

    // MARK: - Viết ngược ra chữ

    func testMOtaLAIthanhCHUgopDOANlienNHAU() {
        var set = IndexSet()
        set.insert(integersIn: 1 ..< 4)      // trang 2,3,4
        set.insert(8)                        // trang 9
        XCTAssertEqual(PageRange.describe(set), "2-4, 9")
    }

    func testMOtaMOTtrangLEkhongVIETthanhKHOANG() {
        XCTAssertEqual(PageRange.describe(IndexSet(integer: 0)), "1")
    }

    func testDOCroiMOtaLAIvanRAdungCAUbanDAU() throws {
        // Vòng khép kín: chuỗi → tập → chuỗi phải về đúng dạng chuẩn hoá.
        let set = try PageRange.parse("3-5,1", pageCount: 10)
        XCTAssertEqual(PageRange.describe(set), "1, 3-5")
    }
}
