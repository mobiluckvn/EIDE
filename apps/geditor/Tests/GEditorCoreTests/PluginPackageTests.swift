import XCTest
@testable import GEditorCore

/// Truy vết: FR-PLUG-701 plugin dạng script · FR-PLUG-705 gói theme/grammar.
final class PluginPackageTests: XCTestCase {

    private var root = URL(fileURLWithPath: "/dev/null")
    private var destinations: PluginPackage.Destinations!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-pkg-\(UUID().uuidString)")
        destinations = PluginPackage.Destinations(
            scripts: root.appendingPathComponent("scripts"),
            themes: root.appendingPathComponent("themes"),
            languages: root.appendingPathComponent("grammars")
        )
        for url in [destinations.scripts, destinations.themes, destinations.languages] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var samplePackage: PluginPackage {
        PluginPackage(
            name: "Gói của tôi",
            version: "1.0.0",
            author: "An",
            summary: "Ví dụ",
            scripts: ["đánh-số": "doc.replace(doc.text);"],
            themes: [Theme.than],
            languages: [UserDefinedLanguage.example]
        )
    }

    private func files(in url: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
    }

    // MARK: - Cài / gỡ

    func testInstallWritesEverything() throws {
        let installation = try samplePackage.install(into: destinations)
        XCTAssertEqual(installation.files.count, 3)
        XCTAssertEqual(files(in: destinations.scripts), ["goi-cua-toi.đánh-số.js"])
        XCTAssertEqual(files(in: destinations.themes), ["goi-cua-toi.than-chi.json"])
        XCTAssertEqual(files(in: destinations.languages).count, 1)
    }

    /// Nội dung phải đọc lại được bằng chính bộ đọc của sản phẩm, không chỉ "có file ở đó".
    func testInstalledContentIsReadableByItsOwnLoader() throws {
        try samplePackage.install(into: destinations)
        let themes = Theme.all(in: destinations.themes)
        XCTAssertTrue(themes.contains { $0.name == Theme.than.name })
        XCTAssertEqual(UserDefinedLanguage.all(in: destinations.languages).count, 1)
    }

    /// Hai gói cùng có script tên `format` — không có tiền tố thì gói cài sau nuốt gói trước mà
    /// không ai báo gì.
    func testTwoPackagesWithSameScriptNameCoexist() throws {
        try PluginPackage(name: "Gói A", version: "1", scripts: ["format": "a"]).install(into: destinations)
        try PluginPackage(name: "Gói B", version: "1", scripts: ["format": "b"]).install(into: destinations)
        XCTAssertEqual(files(in: destinations.scripts), ["goi-a.format.js", "goi-b.format.js"])
    }

    func testUninstallRemovesOnlyItsOwnFiles() throws {
        try PluginPackage(name: "Gói A", version: "1", scripts: ["x": "a"]).install(into: destinations)
        try PluginPackage(name: "Gói B", version: "1", scripts: ["y": "b"]).install(into: destinations)
        // Và một file người dùng tự đặt — gỡ gói KHÔNG được chạm vào nó.
        try "riêng".write(
            to: destinations.scripts.appendingPathComponent("cua-toi.js"),
            atomically: true, encoding: .utf8
        )

        let removed = PluginPackage.uninstall(name: "Gói A", from: destinations)
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(files(in: destinations.scripts), ["cua-toi.js", "goi-b.y.js"])
    }

    /// Gỡ một thứ đã không còn ở đó thì kết quả mong muốn đã đạt — không phải lỗi.
    func testUninstallingMissingPackageIsNotAnError() {
        XCTAssertTrue(PluginPackage.uninstall(name: "Không có", from: destinations).isEmpty)
    }

    /// Danh sách gói suy ra TỪ ĐĨA: người dùng xoá tay một file thì hiện trạng đã đổi, và một
    /// cuốn sổ nói khác đi là một cuốn sổ nói dối.
    func testInstalledNamesComeFromDisk() throws {
        try PluginPackage(name: "Gói A", version: "1", scripts: ["x": "a"]).install(into: destinations)
        try PluginPackage(name: "Gói B", version: "1", themes: [Theme.cam]).install(into: destinations)
        XCTAssertEqual(PluginPackage.installedNames(in: destinations), ["goi-a", "goi-b"])

        try FileManager.default.removeItem(at: destinations.scripts.appendingPathComponent("goi-a.x.js"))
        XCTAssertEqual(PluginPackage.installedNames(in: destinations), ["goi-b"])
    }

    /// File người dùng tự đặt (`a.js` — hai phần) không được nhận nhầm là một gói.
    func testUserOwnScriptIsNotMistakenForAPackage() throws {
        try "x".write(
            to: destinations.scripts.appendingPathComponent("cua-toi.js"),
            atomically: true, encoding: .utf8
        )
        XCTAssertTrue(PluginPackage.installedNames(in: destinations).isEmpty)
    }

    // MARK: - An toàn tên — hàng rào quan trọng nhất

    /// Một gói tải từ internet đặt tên script là `../../../../etc/passwd`. Ghép thẳng vào đường
    /// dẫn thì "cài đặt" trở thành ghi đè file hệ thống.
    func testPathTraversalInScriptNameIsRefused() {
        let evil = PluginPackage(
            name: "Ác", version: "1", scripts: ["../../../../tmp/geditor-bi-ghi-de": "x"]
        )
        XCTAssertThrowsError(try evil.install(into: destinations)) { error in
            guard case .unsafeName = error as? PluginPackage.Failure else {
                return XCTFail("mong .unsafeName, nhận \(error)")
            }
        }
        XCTAssertTrue(files(in: destinations.scripts).isEmpty, "không được ghi gì cả")
    }

    func testUnsafeNamesAreRejected() {
        XCTAssertFalse(PluginPackage.isSafe(""))
        XCTAssertFalse(PluginPackage.isSafe(".."))
        XCTAssertFalse(PluginPackage.isSafe("."))
        XCTAssertFalse(PluginPackage.isSafe(".ẩn"))
        XCTAssertFalse(PluginPackage.isSafe("a/b"))
        XCTAssertFalse(PluginPackage.isSafe("a\\b"))
        XCTAssertFalse(PluginPackage.isSafe("a:b"))
        XCTAssertFalse(PluginPackage.isSafe(String(repeating: "x", count: 65)))
        XCTAssertTrue(PluginPackage.isSafe("đánh-số dòng"))
    }

    /// Tên gói chỉ toàn ký tự đặc biệt cho ra tiền tố rỗng — khi ấy mọi file sẽ bắt đầu bằng
    /// dấu chấm và biến thành file ẩn.
    func testPackageNameThatSlugsToNothingIsRefused() {
        let bad = PluginPackage(name: "!!!", version: "1", scripts: ["x": "y"])
        XCTAssertThrowsError(try bad.install(into: destinations))
    }

    func testSlugRemovesDiacriticsAndCollapsesSeparators() {
        XCTAssertEqual(PluginPackage.slug("Gói của tôi"), "goi-cua-toi")
        XCTAssertEqual(PluginPackage.slug("Thừa   Thiên!!!Huế"), "thua-thien-hue")
        XCTAssertEqual(PluginPackage.slug("---"), "")
    }

    func testEmptyPackageIsRefused() {
        XCTAssertThrowsError(
            try PluginPackage(name: "Rỗng", version: "1").install(into: destinations)
        ) { error in
            XCTAssertEqual(error as? PluginPackage.Failure, .emptyPackage)
        }
    }

    // MARK: - Đọc / ghi

    func testRoundTrip() throws {
        let url = root.appendingPathComponent("goi.geditorpkg")
        try samplePackage.save(to: url)
        XCTAssertEqual(try PluginPackage.load(from: url), samplePackage)
    }

    /// Gói của bản MỚI HƠN thì từ chối và nói rõ — cài một nửa rồi hỏng giữa chừng là trạng thái
    /// tệ nhất, vì người dùng không biết cái gì đã lên đĩa.
    func testNewerFormatIsRefused() throws {
        var future = samplePackage
        future.formatVersion = PluginPackage.currentFormatVersion + 1
        let url = root.appendingPathComponent("tuong-lai.geditorpkg")
        try future.save(to: url)

        XCTAssertThrowsError(try PluginPackage.load(from: url)) { error in
            XCTAssertEqual(
                error as? PluginPackage.Failure,
                .newerFormat(found: PluginPackage.currentFormatVersion + 1,
                             supported: PluginPackage.currentFormatVersion)
            )
        }
    }

    func testSubtitleDescribesContents() {
        XCTAssertEqual(samplePackage.subtitle, "1 script · 1 theme · 1 ngôn ngữ")
        XCTAssertEqual(PluginPackage(name: "R", version: "1").subtitle, "gói rỗng")
    }
}
