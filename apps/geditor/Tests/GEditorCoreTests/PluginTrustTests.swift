import CryptoKit
import XCTest
@testable import GEditorCore

/// Chuỗi cung ứng plugin — NFR-SEC-03.
final class PluginTrustTests: XCTestCase {

    private var thuMuc: URL!

    override func setUpWithError() throws {
        thuMuc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-trust-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: thuMuc)
    }

    private func viet(_ ten: String, _ noiDung: String) throws -> URL {
        let url = thuMuc.appendingPathComponent(ten)
        try Data(noiDung.utf8).write(to: url)
        return url
    }

    // MARK: - Hash

    func testSHA256KhopVectoChuan() throws {
        // Vector chuẩn của NIST cho chuỗi rỗng — đối chứng để chắc rằng ta đang tính SHA-256
        // chứ không phải một thứ na ná nó.
        let url = try viet("rong.dylib", "")
        XCTAssertEqual(
            try PluginTrust.sha256(ofFileAt: url.path),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testSHA256DoiKhiNoiDungDoiDuMOTBYTE() throws {
        let a = try viet("a.dylib", "xin chao")
        let b = try viet("b.dylib", "xin chaO")
        XCTAssertNotEqual(try PluginTrust.sha256(ofFileAt: a.path),
                          try PluginTrust.sha256(ofFileAt: b.path))
    }

    func testFileLonBamTheoLOKhongNapCaVaoRAM() throws {
        // 3 MB — vượt lô 1 MB, nên bài này đi qua vòng lặp nhiều lần. Không đo bộ nhớ ở đây;
        // thứ cần chốt là kết quả VẪN ĐÚNG khi phải ghép nhiều lô.
        let url = thuMuc.appendingPathComponent("lon.dylib")
        let khoi = Data(repeating: 0x41, count: 1 << 20)
        try Data().write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        for _ in 0 ..< 3 { handle.write(khoi) }
        try handle.close()

        var doiChung = SHA256Reference()
        for _ in 0 ..< 3 { doiChung.update(khoi) }
        XCTAssertEqual(try PluginTrust.sha256(ofFileAt: url.path), doiChung.hex())
    }

    func testFileKhongCoThiNemLoiCoDuongDan() {
        XCTAssertThrowsError(try PluginTrust.sha256(ofFileAt: "/khong/co/dau.dylib")) { error in
            guard case PluginTrust.Failure.unreadable(let path) = error else {
                return XCTFail("mong .unreadable, nhận \(error)")
            }
            XCTAssertTrue(path.contains("dau.dylib"))
        }
    }

    // MARK: - Ba phán quyết

    func testChuaDuyetThiUNKNOWNKemHash() throws {
        let url = try viet("moi.dylib", "ma cua nguoi khac")
        let verdict = try PluginTrust.verdict(forFileAt: url.path, in: PluginTrust.Store())
        guard case .unknown(let sha) = verdict else { return XCTFail("mong .unknown") }
        XCTAssertEqual(sha, try PluginTrust.sha256(ofFileAt: url.path))
    }

    func testDaDuyetVaKhongDoiThiTRUSTED() throws {
        let url = try viet("quen.dylib", "noi dung on dinh")
        var store = PluginTrust.Store()
        store.approve(.init(fileName: "quen.dylib",
                            sha256: try PluginTrust.sha256(ofFileAt: url.path),
                            approvedAt: "2026-08-26T00:00:00Z", signedBy: nil))
        XCTAssertEqual(try PluginTrust.verdict(forFileAt: url.path, in: store), .trusted)
    }

    func testDOIsauKhiDuyetThiCHANGEDchuKhongPhaiHoiLai() throws {
        // Đây là lý do chính cả tính năng này tồn tại: một plugin đã được duyệt rồi bị thay
        // nội dung là đúng hình dạng của một cuộc tấn công chuỗi cung ứng.
        let url = try viet("bi_thay.dylib", "ban goc")
        var store = PluginTrust.Store()
        let hashGoc = try PluginTrust.sha256(ofFileAt: url.path)
        store.approve(.init(fileName: "bi_thay.dylib", sha256: hashGoc,
                            approvedAt: "2026-08-26T00:00:00Z", signedBy: nil))

        try Data("ban da bi thay".utf8).write(to: url)

        let verdict = try PluginTrust.verdict(forFileAt: url.path, in: store)
        guard case .changed(let approved, let now) = verdict else {
            return XCTFail("mong .changed, nhận \(verdict)")
        }
        XCTAssertEqual(approved, hashGoc)
        XCTAssertNotEqual(now, hashGoc)
    }

    func testHaiPluginTrungNOIDUNGnhungKHACTENthiDocLap() throws {
        // Sổ khoá theo TÊN FILE. Duyệt `a.dylib` không được kéo theo `b.dylib` dù byte giống
        // hệt — người dùng duyệt một file, không duyệt một nội dung.
        let a = try viet("a.dylib", "cung mot noi dung")
        let b = try viet("b.dylib", "cung mot noi dung")
        var store = PluginTrust.Store()
        store.approve(.init(fileName: "a.dylib",
                            sha256: try PluginTrust.sha256(ofFileAt: a.path),
                            approvedAt: "2026-08-26T00:00:00Z", signedBy: nil))
        XCTAssertEqual(try PluginTrust.verdict(forFileAt: a.path, in: store), .trusted)
        guard case .unknown = try PluginTrust.verdict(forFileAt: b.path, in: store) else {
            return XCTFail("b.dylib chưa duyệt mà lại được tin")
        }
    }

    // MARK: - Sổ duyệt

    func testSoRongKhiChuaCoTepChuKhongPhaiLOI() throws {
        let store = try PluginTrust.Store.load(from: thuMuc.appendingPathComponent("chua-co.json"))
        XCTAssertTrue(store.approvals.isEmpty)
    }

    func testGhiRoiDocLaiNguyenVen() throws {
        let url = thuMuc.appendingPathComponent("trusted.json")
        var store = PluginTrust.Store()
        store.approve(.init(fileName: "x.dylib", sha256: "abc",
                            approvedAt: "2026-08-26T00:00:00Z", signedBy: "Developer ID: MOBILUCK"))
        try store.save(to: url)
        XCTAssertEqual(try PluginTrust.Store.load(from: url), store)
        // Đọc được bằng mắt (ADR-09): người dùng phải xoá được một dòng bằng tay.
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\n"), "JSON một dòng thì không ai sửa tay được")
        XCTAssertTrue(text.contains("x.dylib"))
    }

    func testTuChoiSoCuaBanMOIHONvaKHONGghiDe() throws {
        let url = thuMuc.appendingPathComponent("trusted.json")
        try Data("""
            {"schemaVersion": 99, "approvals": []}
            """.utf8).write(to: url)
        XCTAssertThrowsError(try PluginTrust.Store.load(from: url))
        // Và tệp phải còn NGUYÊN: ghi đè là xoá sạch quyết định của người dùng trên máy kia.
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("99"))
    }

    func testDuyetLaiThiTHAYchuKhongThemDongThuHai() throws {
        var store = PluginTrust.Store()
        store.approve(.init(fileName: "x.dylib", sha256: "cu",
                            approvedAt: "2026-08-26T00:00:00Z", signedBy: nil))
        store.approve(.init(fileName: "x.dylib", sha256: "moi",
                            approvedAt: "2026-08-27T00:00:00Z", signedBy: nil))
        XCTAssertEqual(store.approvals.count, 1)
        XCTAssertEqual(store.approval(for: "x.dylib")?.sha256, "moi")
    }

    func testQuenDiThiVeLaiUNKNOWN() throws {
        let url = try viet("q.dylib", "abc")
        var store = PluginTrust.Store()
        store.approve(.init(fileName: "q.dylib",
                            sha256: try PluginTrust.sha256(ofFileAt: url.path),
                            approvedAt: "2026-08-26T00:00:00Z", signedBy: nil))
        store.forget(fileName: "q.dylib")
        guard case .unknown = try PluginTrust.verdict(forFileAt: url.path, in: store) else {
            return XCTFail("quên rồi mà vẫn tin")
        }
    }

    // MARK: - Câu nói với người dùng

    func testCauGiaiThichNoiDuHAIhashKhiFileDOI() {
        let text = PluginTrust.explanation(
            .changed(approved: "aaa", now: "bbb"), fileName: "x.dylib")
        // Không có cả hai hash thì người dùng không kiểm được gì, và câu cảnh báo thành một câu
        // doạ suông.
        XCTAssertTrue(text.contains("aaa"), text)
        XCTAssertTrue(text.contains("bbb"), text)
        XCTAssertTrue(text.contains("ĐÃ ĐỔI"), text)
        // Và phải nói CÁCH THOÁT, không chỉ nói là không được.
        XCTAssertTrue(text.contains("gỡ nó khỏi sổ duyệt"), text)
    }

    func testCauHoiChoPluginMOInoiRoRuiRo() {
        let text = PluginTrust.explanation(.unknown(sha256: "deadbeef"), fileName: "x.dylib")
        XCTAssertTrue(text.contains("deadbeef"), text)
        // Người dùng phải biết mình đang đồng ý CÁI GÌ: không sandbox, chạy với quyền của họ.
        XCTAssertTrue(text.contains("quyền của anh"), text)
    }
}

/// Bộ băm đối chứng — cố ý viết TÁCH khỏi bản đang kiểm.
///
/// Nếu bài kiểm gọi lại chính `PluginTrust.sha256` để so thì nó chỉ chứng minh hàm ấy tất định,
/// không chứng minh nó tính đúng.
private struct SHA256Reference {
    private var hasher = CryptoKit.SHA256()
    mutating func update(_ data: Data) { hasher.update(data: data) }
    func hex() -> String { hasher.finalize().map { String(format: "%02x", $0) }.joined() }
}

/// Đọc chữ ký — tách riêng vì nó chạm vào Security framework, không phải logic thuần.
extension PluginTrustTests {

    func testFileKhongKyThiTraNil() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-khong-ky-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("chi la van ban".utf8).write(to: url)
        XCTAssertNil(PluginTrust.signer(ofFileAt: url.path))
    }

    func testDylibDaKyThiDOCduocDanhTinh() throws {
        // Dùng chính libduckdb đã vendor: `vendor-duckdb.sh` ký ad-hoc sau khi strip, nên nó là
        // một file ĐÃ KÝ có thật nằm sẵn trong cây làm việc.
        let path = DuckDB.libraryCandidates.first {
            FileManager.default.fileExists(atPath: $0)
                && (((try? FileManager.default.attributesOfItem(atPath: $0)[.size]) as? Int) ?? 0) > 1_000_000
        }
        guard let path else { throw XCTSkip("chưa có dylib đã ký để đối chứng") }
        // Đối chứng cho chính hàm này: nếu nó trả `nil` cho MỌI đầu vào thì bài trên xanh vô
        // nghĩa. Một file đã ký phải cho ra thứ gì đó.
        XCTAssertNotNil(PluginTrust.signer(ofFileAt: path),
                        "đọc chữ ký trả nil cho một dylib đã ký — hàm này không đo được gì")
    }
}
