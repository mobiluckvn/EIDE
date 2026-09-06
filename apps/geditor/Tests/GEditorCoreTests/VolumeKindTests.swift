import XCTest
@testable import GEditorCore

/// Truy vết: NFR-REL-04 ổ mạng & iCloud.
///
/// **Giới hạn phải nói rõ ngay đây:** bài này KHÔNG kiểm được đường iCloud và đường ổ mạng
/// thật, vì máy chạy test không có sẵn hai loại ổ ấy và giả lập chúng thì chỉ kiểm lại chính
/// đoạn giả lập. Nó kiểm phần kiểm được: nhận đúng ổ cục bộ, không đoán bừa, và phép ghi qua
/// `AtomicFileWriter` vẫn nguyên vẹn sau khi thêm nhánh điều phối.
///
/// Phần còn lại thuộc về một lần kiểm TAY trên máy có iCloud Drive — ghi ở `docs/trang-thai.md`.
final class VolumeKindTests: XCTestCase {

    func testTemporaryDirectoryIsLocal() {
        XCTAssertEqual(VolumeKind.of(path: NSTemporaryDirectory() + "a.txt"), .local)
    }

    /// File CHƯA TỒN TẠI vẫn phải trả lời được: lúc "Lưu thành…" thì file đích chưa có, và đó
    /// đúng là lúc cần biết ổ loại gì.
    func testMissingFileFallsBackToItsDirectory() {
        let path = NSTemporaryDirectory() + "chưa-có-\(UUID().uuidString).txt"
        XCTAssertEqual(VolumeKind.of(path: path), .local)
    }

    /// Đường dẫn vô nghĩa thì coi là cục bộ, không ném và không đoán là mạng: đoán mạng sẽ bắt
    /// mọi phép lưu bình thường trả giá điều phối vô ích.
    func testNonsensePathIsTreatedAsLocal() {
        XCTAssertEqual(VolumeKind.of(path: "/không/có/đường/này/x.txt"), .local)
    }

    func testLocalNeedsNoCoordination() {
        XCTAssertFalse(VolumeKind.local.needsCoordination)
        XCTAssertTrue(VolumeKind.iCloud.needsCoordination)
        XCTAssertTrue(VolumeKind.network.needsCoordination)
    }

    /// Chỉ nói khi có điều đáng nói: một cảnh báo hiện ở mọi lần mở file cục bộ sẽ bị bỏ qua,
    /// và khi ấy nó không còn là cảnh báo nữa.
    func testOnlyNonLocalVolumesHaveAdvisory() {
        XCTAssertNil(VolumeKind.local.advisory)
        XCTAssertNotNil(VolumeKind.iCloud.advisory)
        XCTAssertNotNil(VolumeKind.network.advisory)
    }

    /// Nhánh điều phối mới thêm không được làm hỏng đường ghi cục bộ — đường mà 100% phép lưu
    /// hôm nay đi qua.
    func testLocalWriteStillWorksAfterCoordinationBranch() throws {
        let path = NSTemporaryDirectory() + "geditor-vol-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try AtomicFileWriter.write(Array("một dòng tiếng Việt\n".utf8), to: path)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "một dòng tiếng Việt\n")
    }
}
