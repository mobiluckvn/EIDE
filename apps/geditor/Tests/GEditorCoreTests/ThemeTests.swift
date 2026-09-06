import XCTest
@testable import GEditorCore

/// Truy vết: FR-UI-801 theme + style configurator.
final class ThemeTests: XCTestCase {

    private var directory = URL(fileURLWithPath: "/dev/null")

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-themes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testHexParsing() {
        let white = Theme.components("#FFFFFF")
        XCTAssertEqual(white?.r, 1)
        XCTAssertEqual(white?.g, 1)
        XCTAssertEqual(white?.b, 1)
        XCTAssertEqual(Theme.components("000000")?.r, 0, "bỏ dấu # cũng đọc được")
        XCTAssertEqual(Theme.components("#ED6A1F")?.r ?? 0, 0xED / 255, accuracy: 0.001)
    }

    /// Màu gõ sai trả `nil` chứ không rơi về đen: đen trông như một lựa chọn thiết kế, và
    /// người dùng đi tìm lỗi ở chỗ khác.
    func testInvalidHexIsRejectedNotSilentlyBlack() {
        XCTAssertNil(Theme.components("#GGGGGG"))
        XCTAssertNil(Theme.components("#FFF"), "ba ký tự chưa hỗ trợ — nói không thay vì đoán")
        XCTAssertNil(Theme.components(""))
        XCTAssertNil(Theme.components("#FFFFFFFF"))
    }

    func testRoundTrip() throws {
        let url = directory.appendingPathComponent("cam.json")
        try Theme.cam.save(to: url)
        XCTAssertEqual(try Theme.load(from: url), Theme.cam)
    }

    func testBuiltInThemesAreListedWithoutAnyFiles() {
        let all = Theme.all(in: directory)
        XCTAssertEqual(all.map(\.name), Theme.builtIn.map(\.name))
    }

    func testCustomThemeIsAppended() throws {
        var mine = Theme.cam
        mine.name = "Của tôi"
        try mine.save(to: directory.appendingPathComponent("cua-toi.json"))
        XCTAssertEqual(Theme.all(in: directory).map(\.name), ["GEditor Cam", "Than chì", "Của tôi"])
    }

    /// Người dùng ghi đè một theme dựng sẵn thì bản của HỌ thắng — họ sửa ra để dùng bản sửa.
    func testCustomThemeOverridesBuiltInWithSameName() throws {
        var mine = Theme.cam
        mine.accent = Theme.Pair(light: "#123456", dark: "#123456")
        try mine.save(to: directory.appendingPathComponent("cam.json"))
        let all = Theme.all(in: directory)
        XCTAssertEqual(all.count, Theme.builtIn.count, "không thêm mục trùng tên")
        XCTAssertEqual(all.first { $0.name == Theme.cam.name }?.accent.light, "#123456")
    }

    /// Một theme gõ sai dấu phẩy không được làm biến mất cả danh sách, cũng không được chặn
    /// app khởi động.
    func testBrokenThemeFileIsSkipped() throws {
        try "{ hỏng".write(
            to: directory.appendingPathComponent("hong.json"), atomically: true, encoding: .utf8
        )
        var good = Theme.than
        good.name = "Tốt"
        try good.save(to: directory.appendingPathComponent("tot.json"))

        let names = Theme.all(in: directory).map(\.name)
        XCTAssertTrue(names.contains("Tốt"))
        XCTAssertEqual(names.count, Theme.builtIn.count + 1)
    }

    /// Mỗi màu phải có CẢ hai bản sáng và tối: thiếu một bản là có nửa số lần chữ đen trên nền
    /// đen, tuỳ theo hệ thống đang ở chế độ nào.
    func testBuiltInThemesDefineBothAppearances() {
        for theme in Theme.builtIn {
            for pair in [
                theme.accent, theme.editorBackground, theme.editorInk,
                theme.selection, theme.searchHighlight,
            ] {
                XCTAssertNotNil(Theme.components(pair.light), "\(theme.name): thiếu bản sáng hợp lệ")
                XCTAssertNotNil(Theme.components(pair.dark), "\(theme.name): thiếu bản tối hợp lệ")
            }
        }
    }

    /// Chữ phải ĐỌC ĐƯỢC trên nền. Không phải phép đo tương phản WCAG đầy đủ, chỉ là hàng rào
    /// thô bắt lỗi rõ ràng nhất: chữ và nền không được cùng phía sáng/tối.
    func testInkAndBackgroundAreOnOppositeSides() {
        func luminance(_ hex: String) -> Double {
            guard let c = Theme.components(hex) else { return 0.5 }
            return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        }
        for theme in Theme.builtIn {
            XCTAssertGreaterThan(
                abs(luminance(theme.editorInk.light) - luminance(theme.editorBackground.light)), 0.4,
                "\(theme.name) nền sáng: chữ và nền quá gần nhau"
            )
            XCTAssertGreaterThan(
                abs(luminance(theme.editorInk.dark) - luminance(theme.editorBackground.dark)), 0.4,
                "\(theme.name) nền tối: chữ và nền quá gần nhau"
            )
        }
    }
}
