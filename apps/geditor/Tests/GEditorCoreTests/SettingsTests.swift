import XCTest
@testable import GEditorCore

/// Truy vết: FR-UI-803 Preferences · NFR-PORT-03 cấu hình di động dạng file text.
final class SettingsTests: XCTestCase {

    private var url = URL(fileURLWithPath: "/dev/null")

    override func setUpWithError() throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-settings-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url)
    }

    /// Lần chạy ĐẦU chưa có file — đó là trạng thái bình thường, không phải lỗi.
    func testMissingFileGivesDefaults() throws {
        XCTAssertEqual(try Settings.load(from: url), Settings())
    }

    func testRoundTrip() throws {
        var written = Settings()
        written.fontSize = 17
        written.tabWidth = 2
        written.language = "en"
        written.keyBindings = ["duplicateLines": "^d"]
        try written.save(to: url)
        XCTAssertEqual(try Settings.load(from: url), written)
    }

    /// NFR-PORT-03: phải là văn bản người đọc và sửa tay được, không phải plist nhị phân.
    func testFileIsHumanReadableJSON() throws {
        try Settings().save(to: url)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"fontSize\""))
        XCTAssertTrue(text.contains("\n"), "phải xuống dòng, không phải một dòng dài")
        // Khoá sắp xếp: hai lần ghi cùng nội dung phải ra cùng một file, nếu không thì mỗi lần
        // mở app lại là một thay đổi giả trong git của người dùng.
        let again = try String(contentsOf: url, encoding: .utf8)
        try Settings().save(to: url)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), again)
    }

    /// Sửa tay là chuyện được khuyến khích, nên gõ thiếu một khoá không được làm app chết.
    func testMissingKeysFallBackToDefaults() throws {
        try #"{ "schemaVersion": 1, "fontSize": 20 }"#.write(to: url, atomically: true, encoding: .utf8)
        let loaded = try Settings.load(from: url)
        XCTAssertEqual(loaded.fontSize, 20)
        XCTAssertEqual(loaded.tabWidth, Settings().tabWidth)
        XCTAssertEqual(loaded.language, Settings().language)
    }

    func testEmptyObjectIsAllDefaults() throws {
        try "{}".write(to: url, atomically: true, encoding: .utf8)
        var expected = Settings()
        expected.schemaVersion = 0        // khoá vắng mặt, rơi về mặc định của `SchemaProbe`
        XCTAssertEqual(try Settings.load(from: url).tabWidth, expected.tabWidth)
    }

    /// File của bản MỚI HƠN thì từ chối. Bản cũ đọc rồi ghi đè sẽ xoá những khoá nó không hiểu
    /// — người dùng đồng bộ hai máy mất cấu hình mà không cách nào biết vì sao.
    func testNewerSchemaIsRejected() throws {
        var future = Settings()
        future.schemaVersion = Settings.currentSchemaVersion + 1
        try future.save(to: url)

        XCTAssertThrowsError(try Settings.load(from: url)) { error in
            XCTAssertEqual(
                error as? Settings.Failure,
                .newerSchema(found: Settings.currentSchemaVersion + 1,
                             supported: Settings.currentSchemaVersion)
            )
        }
    }

    func testCorruptFileThrowsInsteadOfCrashing() throws {
        try "{ không phải JSON".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Settings.load(from: url))
    }

    /// Khoá nào GHI ra được thì phải ĐỌC lại được — không sót khoá nào.
    ///
    /// `init(from:)` viết tay (xem chú thích của nó: để khoá vắng mặt rơi về mặc định). Cái giá
    /// là encoder do `Codable` sinh còn decoder thì do người viết, nên thêm một thuộc tính mà
    /// quên thêm dòng đọc là chuyện xảy ra HOÀN TOÀN im lặng: khoá vẫn ra tệp, chỉ không bao
    /// giờ quay lại. Người dùng đổi cấu hình, thấy có hiệu lực, khởi động lại thì mất — và
    /// `testRoundTrip` không thấy gì, vì nó chỉ đụng bốn khoá nó tự chọn.
    ///
    /// `panelHeights` đã đi đúng đường ấy: ghi xuống đĩa hai tuần, đọc lên không lần nào.
    ///
    /// Bài kiểm này canh cả LỚP lỗi chứ không canh một khoá. Hai vế:
    ///
    /// - **Vế một** đòi mọi khoá trong tệp đều khác mặc định. Thêm thuộc tính mới mà quên đổi
    ///   nó ở đây là đỏ ngay — nên vế hai không bao giờ kiểm một khoá đang mang giá trị mặc
    ///   định, thứ khiến phép so bằng đúng vì lý do sai.
    /// - **Vế hai** ghi → đọc → so. Khoá nào decoder không đọc thì quay về mặc định, khác giá
    ///   trị đã ghi, và phép so bắt được.
    func testEveryWrittenKeyIsAlsoRead() throws {
        var mutated = Settings()
        mutated.schemaVersion = Settings.currentSchemaVersion
        mutated.fontSize = 19
        mutated.tabWidth = 7
        mutated.usesTabsForIndent = true
        mutated.trimTrailingWhitespaceOnSave = true
        mutated.normalizeToNFCOnSave = true
        mutated.smartIndent = false
        mutated.highlightAllMatches = false
        mutated.ligatures = true
        mutated.openInViewMode = false
        mutated.defaultEncoding = "utf-16"
        mutated.defaultEOL = "crlf"
        mutated.language = "en"
        mutated.appearance = "dark"
        mutated.themeName = "than"
        mutated.panelHeights = ["sql": 512]
        mutated.showWelcomeOnLaunch = false
        mutated.keyBindings = ["duplicateLines": "^d"]
        mutated.languageIndent = [
            "go": Settings.IndentStyle(width: 4, usesTabs: true),
            "javascript": Settings.IndentStyle(width: 2, usesTabs: false),
        ]

        // VẾ MỘT — mọi khoá phải khác mặc định.
        //
        // So theo BỘ KHOÁ mà encoder sinh ra, không theo một danh sách viết tay: danh sách viết
        // tay chính là thứ vừa quên `panelHeights`, và nó sẽ quên khoá sau y như vậy.
        let asDictionary = { (settings: Settings) throws -> [String: Any] in
            let data = try JSONEncoder().encode(settings)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        }
        let defaults = try asDictionary(Settings())
        let changed = try asDictionary(mutated)
        XCTAssertEqual(Set(defaults.keys), Set(changed.keys))
        XCTAssertFalse(changed.isEmpty, "không đọc nổi khoá nào — phép so dưới sẽ đúng rỗng")
        for key in changed.keys where key != "schemaVersion" {
            XCTAssertNotEqual(
                String(describing: defaults[key]), String(describing: changed[key]),
                "khoá \(key) vẫn mang giá trị mặc định — hãy đổi nó trong bài kiểm này, "
                    + "nếu không vế hai sẽ xanh cả khi decoder bỏ qua nó"
            )
        }

        // VẾ HAI — ghi rồi đọc phải ra đúng cái đã ghi.
        try mutated.save(to: url)
        XCTAssertEqual(try Settings.load(from: url), mutated)
    }

    /// Ghi vào thư mục chưa tồn tại phải tự tạo — lần chạy đầu chưa có Application Support.
    func testSaveCreatesParentDirectory() throws {
        let nested = url.deletingLastPathComponent()
            .appendingPathComponent("chưa-có-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: nested.deletingLastPathComponent()) }
        try Settings().save(to: nested)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }
}
