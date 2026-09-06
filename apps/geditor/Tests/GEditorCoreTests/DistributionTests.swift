import XCTest
@testable import GEditorCore

/// Truy vết: hai kênh phát hành (`docs/appstore-ra-soat.md`) · FR-AUTO-604 · FR-AUTO-605.
///
/// Hai file này từng ở **0% độ phủ** — và `Distribution` thì quyết định tính năng nào có ở kênh
/// nào, tức là nó load-bearing. Một chỗ như thế mà không có bài kiểm nào là chỗ dễ đổi nhầm
/// nhất: sửa một dòng, mọi test vẫn xanh, và bản App Store bỗng bật một tính năng sandbox cấm.
final class DistributionTests: XCTestCase {

    /// Cái gì có ở kênh nào — bảng này là hợp đồng, không phải chi tiết cài đặt.
    func testChannelCapabilities() {
        XCTAssertTrue(Distribution.direct.supportsCLIBridge)
        XCTAssertTrue(Distribution.direct.supportsTextFilter)

        // App Store chạy trong App Sandbox: không đặt được `geditor` vào PATH, và không tạo
        // được tiến trình con tuỳ ý. Hai điều này là giới hạn của hệ điều hành, không phải
        // lựa chọn — bật chúng lên sẽ bị từ chối lúc duyệt hoặc chết lúc chạy.
        XCTAssertFalse(Distribution.appStore.supportsCLIBridge)
        XCTAssertFalse(Distribution.appStore.supportsTextFilter)
    }

    func testDisplayNames() {
        XCTAssertEqual(Distribution.appStore.displayName, "App Store")
        XCTAssertEqual(Distribution.direct.displayName, "Bản tải trực tiếp")
    }

    /// Bài kiểm chạy ngoài sandbox, nên `current` phải là `.direct`. Nếu ngày nào đó nó ra
    /// `.appStore` thì phép nhận biết đã hỏng — và nó hỏng LẶNG LẼ, chỉ biểu hiện bằng việc
    /// CLI và lọc lệnh ngoài biến mất mà không ai báo gì.
    func testCurrentIsDirectWhenNotSandboxed() {
        XCTAssertEqual(Distribution.current, .direct)
        XCTAssertFalse(Distribution.isSandboxed())
    }

    func testRawValuesAreStableForPersistence() {
        // `rawValue` có thể lọt vào log chẩn đoán và báo cáo lỗi; đổi nó là đổi thứ người khác
        // đang đọc.
        XCTAssertEqual(Distribution.appStore.rawValue, "appStore")
        XCTAssertEqual(Distribution.direct.rawValue, "direct")
    }
}

/// Truy vết: SAD §5.1 · ADR-09 · NFR-PORT-03.
final class AppPathsTests: XCTestCase {

    /// Mọi thứ đều nằm DƯỚI Application Support/GEditor. Một đường lạc ra ngoài là một chỗ
    /// người dùng không tìm thấy, không sao lưu được, và trong sandbox thì không ghi nổi.
    func testEverythingLivesUnderApplicationSupport() {
        let root = AppPaths.applicationSupport.path
        for url in [
            AppPaths.settingsFile, AppPaths.sessionDirectory, AppPaths.snapshotsDirectory,
            AppPaths.macrosDirectory, AppPaths.scriptsDirectory, AppPaths.themesDirectory,
            AppPaths.grammarsDirectory,
        ] {
            XCTAssertTrue(url.path.hasPrefix(root), "\(url.lastPathComponent) nằm ngoài \(root)")
        }
        XCTAssertTrue(root.hasSuffix("/GEditor"))
    }

    /// Cache tách RIÊNG khỏi Application Support, và luôn tái tạo được: xoá
    /// `~/Library/Caches/GEditor` bất kỳ lúc nào không được làm mất dữ liệu.
    func testCachesAreSeparateFromData() {
        XCTAssertFalse(AppPaths.caches.path.hasPrefix(AppPaths.applicationSupport.path))
        XCTAssertTrue(AppPaths.caches.path.contains("Caches"))
    }

    func testEveryPathIsDistinct() {
        let paths = [
            AppPaths.settingsFile, AppPaths.sessionDirectory, AppPaths.snapshotsDirectory,
            AppPaths.macrosDirectory, AppPaths.scriptsDirectory, AppPaths.themesDirectory,
            AppPaths.grammarsDirectory, AppPaths.caches,
        ].map(\.path)
        XCTAssertEqual(Set(paths).count, paths.count, "hai thứ khác nhau dùng chung một đường dẫn")
    }

    /// Cấu hình là FILE, không phải thư mục — NFR-PORT-03 nói "chép một file là xong".
    func testSettingsIsAFileNotADirectory() {
        XCTAssertTrue(AppPaths.settingsFile.lastPathComponent.hasSuffix(".json"))
    }

    // MARK: - Tự cập nhật (NFR-SEC-01)

    /// Ba cổng theo kênh phát hành phải nhất quán: bản App Store không có cái nào trong ba.
    ///
    /// Kiểm CẢ BA cùng một chỗ chứ không kiểm riêng `supportsSelfUpdate`: chúng cùng một lý do
    /// (App Sandbox và quy định cửa hàng), nên một cái lệch khỏi hai cái kia gần như chắc chắn
    /// là nhầm chứ không phải chủ ý.
    func testAppStoreKhongCoBaTinhNangCuaBanTrucTiep() {
        XCTAssertFalse(Distribution.appStore.supportsSelfUpdate)
        XCTAssertFalse(Distribution.appStore.supportsCLIBridge)
        XCTAssertFalse(Distribution.appStore.supportsTextFilter)

        XCTAssertTrue(Distribution.direct.supportsSelfUpdate)
        XCTAssertTrue(Distribution.direct.supportsCLIBridge)
        XCTAssertTrue(Distribution.direct.supportsTextFilter)
    }

    /// Cổng tự cập nhật phải hỏi KÊNH, không hỏi thứ gì khác.
    ///
    /// Bài này tồn tại vì một hiện thực "tiện tay" hay gặp là đọc một cờ biên dịch hoặc một biến
    /// môi trường. Cả hai đều lệch pha được với chữ ký thật đang áp dụng — xem ghi chú đầu
    /// `Distribution`.
    func testTuCapNhatSuyTuKenhChuKhongTuThuGiKhac() {
        for kenh in [Distribution.appStore, .direct] {
            XCTAssertEqual(kenh.supportsSelfUpdate, kenh == .direct)
        }
    }

    func testCreateDirectoriesIsIdempotent() throws {
        try AppPaths.createDirectories()
        try AppPaths.createDirectories()   // gọi lần hai không được ném
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: AppPaths.themesDirectory.path, isDirectory: &isDirectory
        ))
        XCTAssertTrue(isDirectory.boolValue)
    }
}
