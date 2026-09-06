import XCTest
@testable import GEditorCore

final class A1ReferenceTests: XCTestCase {

    private func chen(_ at: Int, _ count: Int) -> A1Reference.Shift {
        .init(at: at, deleted: 0, inserted: count)
    }

    private func xoa(_ at: Int, _ count: Int) -> A1Reference.Shift {
        .init(at: at, deleted: count, inserted: 0)
    }

    // MARK: - Số hiệu hàng

    func testCHENhangDAYcacHANGduoiXUONG() {
        let shift = chen(2, 1)                 // chèn 1 hàng trước hàng 3
        XCTAssertEqual(shift.newRowNumber(for: 1), 1)
        XCTAssertEqual(shift.newRowNumber(for: 2), 2)
        XCTAssertEqual(shift.newRowNumber(for: 3), 4)
        XCTAssertEqual(shift.newRowNumber(for: 10), 11)
    }

    func testXOAhangKEOcacHANGduoiLEN_vaHANGbiXOAtraNIL() {
        let shift = xoa(2, 2)                  // xoá hàng 3 và 4
        XCTAssertEqual(shift.newRowNumber(for: 2), 2)
        XCTAssertNil(shift.newRowNumber(for: 3))
        XCTAssertNil(shift.newRowNumber(for: 4))
        XCTAssertEqual(shift.newRowNumber(for: 5), 3)
    }

    // MARK: - Tham chiếu ô

    func testDAUDOLAkhongMIENnhiemVOIchenHANG() {
        // `$A$5` nghĩa là "đừng đổi khi CHÉP công thức đi chỗ khác", không phải "đừng đổi khi
        // có hàng chèn vào trên". Excel dịch cả hai loại. Bỏ qua vế này là sai theo đúng cách
        // khó nhận ra nhất — phần lớn công thức trong tệp thật là tương đối và trông vẫn đúng.
        let shift = chen(0, 1)
        XCTAssertEqual(A1Reference.shiftCell("A5", by: shift), "A6")
        XCTAssertEqual(A1Reference.shiftCell("$A$5", by: shift), "$A$6")
        XCTAssertEqual(A1Reference.shiftCell("$A5", by: shift), "$A6")
        XCTAssertEqual(A1Reference.shiftCell("A$5", by: shift), "A$6")
        XCTAssertEqual(A1Reference.shiftCell("AB100", by: shift), "AB101")
    }

    func testOnamTRONGphanBIXOAthiTraNIL() {
        XCTAssertNil(A1Reference.shiftCell("A3", by: xoa(2, 1)))
        XCTAssertEqual(A1Reference.shiftCell("A2", by: xoa(2, 1)), "A2")
    }

    // MARK: - Vùng

    func testVUNGbiXOAmotPHANthiCOlaiChuKhongBienMat() {
        // Xoá hàng 3 trong vùng A2:A5 → vùng còn A2:A4. Đây là điều Excel làm với ô gộp.
        XCTAssertEqual(A1Reference.shiftRange("A2:A5", by: xoa(2, 1)), "A2:A4")
        // Xoá TRỌN vùng thì vùng biến mất.
        XCTAssertNil(A1Reference.shiftRange("A3:A4", by: xoa(2, 2)))
        // Chèn thì vùng giãn ra.
        XCTAssertEqual(A1Reference.shiftRange("A2:A5", by: chen(2, 2)), "A2:A7")
        XCTAssertEqual(A1Reference.shiftRange("$B$1:$D$9", by: chen(0, 1)), "$B$2:$D$10")
    }

    func testSQREFnhieuVUNGdichHET() {
        XCTAssertEqual(A1Reference.shiftSqref("A1:A5 C1:C5", by: chen(0, 1)), "A2:A6 C2:C6")
    }

    // MARK: - Công thức

    func testDICHthamCHIEUtrongCONGTHUC() {
        let shift = chen(1, 1)                 // chèn 1 hàng trước hàng 2
        XCTAssertEqual(A1Reference.shiftFormula("A2+B3", by: shift), "A3+B4")
        XCTAssertEqual(A1Reference.shiftFormula("SUM(A2:A9)", by: shift), "SUM(A3:A10)")
        XCTAssertEqual(A1Reference.shiftFormula("IF($A$2>0,B2,C2)", by: shift), "IF($A$3>0,B3,C3)")
    }

    func testCHUOItrongCONGTHUCkhongBIdich() {
        // `=IF(A1>0,"B2 hỏng","")` có chuỗi `B2` không phải tham chiếu. Dịch nó là sửa chữ
        // hiển thị cho người dùng.
        let shift = chen(0, 1)
        XCTAssertEqual(
            A1Reference.shiftFormula("IF(A1>0,\"B2 hong\",\"\")", by: shift),
            "IF(A2>0,\"B2 hong\",\"\")")
    }

    func testTENHAMvaTENDATkhongBInhamLAthamCHIEU() {
        let shift = chen(0, 1)
        // `LOG10(` là tên hàm — có chữ, có số, nhưng theo sau là dấu mở ngoặc.
        XCTAssertEqual(A1Reference.shiftFormula("LOG10(A1)", by: shift), "LOG10(A2)")
        // Bốn chữ cái trở lên không phải cột hợp lệ trong Excel (tối đa XFD).
        XCTAssertEqual(A1Reference.shiftFormula("ABCD1", by: shift), "ABCD1")
        // Tên có gạch dưới.
        XCTAssertEqual(A1Reference.shiftFormula("Thang_1+A1", by: shift), "Thang_1+A2")
    }

    func testOtrongCONGTHUCbiXOAthanhREF() {
        // Đúng như Excel: công thức trỏ vào hàng vừa bị xoá thành `#REF!`, không phải trỏ nhầm
        // sang hàng khác — trỏ nhầm là kiểu hỏng im lặng.
        XCTAssertEqual(A1Reference.shiftFormula("A3+1", by: xoa(2, 1)), "#REF!+1")
    }
}
