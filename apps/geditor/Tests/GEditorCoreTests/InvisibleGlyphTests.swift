import XCTest

/// Quy tắc chọn ký hiệu cho ký tự ẩn (FR-ENC-205).
///
/// Đây là bản SAO của bảng quy tắc trong `Sources/GEditorApp/Invisibles.swift`. Lớp thật sống
/// ở target UI nên test lõi không import được; bản sao này chốt HÀNH VI mong đợi, và nếu hai
/// bên lệch nhau thì đó là dấu hiệu quy tắc bị sửa một chỗ mà quên chỗ kia.
///
/// TODO: khi có target test cho UI thì kiểm thẳng lớp thật và bỏ bản sao này.
final class InvisibleGlyphTests: XCTestCase {

    private struct Options {
        var spaces = false, tabs = false, lineEndings = false, special = false
    }

    private func symbol(_ scalar: Unicode.Scalar, _ options: Options) -> String? {
        switch scalar {
        case " ": return options.spaces ? "·" : nil
        case "\t": return options.tabs ? "→" : nil
        case "\n": return options.lineEndings ? "¶" : nil
        case "\r": return options.lineEndings ? "␍" : nil
        case "\u{00A0}": return options.special ? "⍽" : nil
        case "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}": return options.special ? "▯" : nil
        default:
            if options.special, scalar.value < 0x20 || scalar.value == 0x7F { return "▯" }
            return nil
        }
    }

    private let all = Options(spaces: true, tabs: true, lineEndings: true, special: true)

    func testEachGroupIsIndependent() {
        XCTAssertEqual(symbol(" ", Options(spaces: true)), "·")
        XCTAssertNil(symbol("\t", Options(spaces: true)), "bật khoảng trắng không được kéo theo tab")
        XCTAssertNil(symbol(" ", Options(tabs: true)))
        XCTAssertEqual(symbol("\t", Options(tabs: true)), "→")
    }

    /// Chữ thật không bao giờ được vẽ đè ký hiệu — kể cả chữ có dấu.
    func testRealCharactersAreNeverMarked() {
        for scalar in "Nguyễn Thị Hồng ĐẮkLắk123".unicodeScalars where scalar != " " {
            XCTAssertNil(symbol(scalar, all), "\(scalar) bị coi là ký tự ẩn")
        }
    }

    /// NBSP phải phân biệt được với khoảng trắng thường.
    ///
    /// Đây là thủ phạm kinh điển của lỗi "trông giống hệt mà tìm không ra" khi dán từ web.
    func testNBSPHasItsOwnSymbol() {
        XCTAssertNotEqual(symbol("\u{00A0}", all), symbol(" ", all))
    }

    func testZeroWidthAndBOMAreVisible() {
        for scalar in ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"] {
            XCTAssertNotNil(symbol(Unicode.Scalar(scalar.unicodeScalars.first!), all),
                            "ký tự zero-width \(scalar.unicodeScalars.first!.value) phải hiện ra")
        }
    }

    func testControlCharactersAreVisible() {
        XCTAssertEqual(symbol(Unicode.Scalar(0x07)!, all), "▯")
        XCTAssertEqual(symbol(Unicode.Scalar(0x7F)!, all), "▯")
    }

    func testNothingIsMarkedWhenAllGroupsOff() {
        for scalar in " \t\n\r\u{00A0}\u{200B}".unicodeScalars {
            XCTAssertNil(symbol(scalar, Options()))
        }
    }
}
