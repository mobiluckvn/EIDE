import XCTest
@testable import GEditorCore

/// FR-SRCH-111 — ô «Đi tới» phải hiểu ba cách viết, và phải TỪ CHỐI những cách viết hỏng.
///
/// Phần từ chối quan trọng ngang phần nhận: một chuỗi không hiểu mà bị đọc thành "dòng 0" hay
/// "offset 0" sẽ ném con nháy về đầu tài liệu, và người dùng không biết vì sao.
final class GoToTargetTests: XCTestCase {

    func testChiSoDong() {
        XCTAssertEqual(GoToTarget.parse("42"), .line(42, column: nil))
        XCTAssertEqual(GoToTarget.parse("  42  "), .line(42, column: nil))
        XCTAssertEqual(GoToTarget.parse("1"), .line(1, column: nil))
    }

    func testDongVaCot() {
        XCTAssertEqual(GoToTarget.parse("42,7"), .line(42, column: 7))
        XCTAssertEqual(GoToTarget.parse("42:7"), .line(42, column: 7))
        XCTAssertEqual(GoToTarget.parse(" 42 , 7 "), .line(42, column: 7))
    }

    /// `dòng:cột` là cách trình biên dịch in lỗi ra, nên nó thường tới qua clipboard.
    func testDangTrinhBienDichInRa() {
        XCTAssertEqual(GoToTarget.parse("118:23"), .line(118, column: 23))
    }

    func testOffset() {
        XCTAssertEqual(GoToTarget.parse("@0"), .offset(0))
        XCTAssertEqual(GoToTarget.parse("@1024"), .offset(1024))
        XCTAssertEqual(GoToTarget.parse("@ 1024"), .offset(1024))
    }

    /// Offset 0 hợp lệ (đầu tài liệu) nhưng DÒNG 0 thì không — dòng đếm từ 1.
    func testDongDemTu1() {
        XCTAssertNil(GoToTarget.parse("0"))
        XCTAssertNil(GoToTarget.parse("-3"))
        XCTAssertNil(GoToTarget.parse("5,0"))
        XCTAssertEqual(GoToTarget.parse("@0"), .offset(0))
    }

    func testChuoiHong() {
        for hong in ["", "   ", "abc", "@", "@abc", "@-1", ",5", "5,", "1,2,3", "1:2:3", "1.5"] {
            XCTAssertNil(GoToTarget.parse(hong), "«\(hong)» đáng lẽ không đọc được")
        }
    }

    /// Đối chứng: chuỗi hợp lệ phải ra ĐÚNG thứ nó nói, không phải "một giá trị nào đó".
    ///
    /// Bài trên chỉ đòi `nil` cho chuỗi hỏng; nếu bộ phân tích trả `.line(1, column: nil)` cho
    /// mọi thứ nó không hiểu thì bài ấy đỏ, còn bài này mới nói được nó đã hiểu ĐÚNG.
    func testKhongTraVeGiaTriMacDinh() {
        XCTAssertNotEqual(GoToTarget.parse("7"), .line(1, column: nil))
        XCTAssertNotEqual(GoToTarget.parse("@7"), .line(7, column: nil))
    }
}
