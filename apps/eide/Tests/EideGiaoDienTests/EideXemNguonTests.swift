import AppKit
import PDFKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Khung xem tài liệu gốc** — UXC-31 §8 S5 "bấm mở ĐÚNG TRANG PDF kèm bbox", [DEV-133].
@MainActor
final class EideXemNguonTests: XCTestCase {

    // MARK: - đọc bbox

    /// Hai quy ước cùng tồn tại trong các bộ trích, và VIEW-11 nói ra quy ước nào.
    func testDocDuocCaHaiQuyUocBbox() {
        XCTAssertEqual(EideXemNguon.hinhChuNhat([72, 530, 180, 14], dang: "rong-cao"),
                       NSRect(x: 72, y: 530, width: 180, height: 14))
        XCTAssertEqual(EideXemNguon.hinhChuNhat([72, 530, 252, 544], dang: "hai-goc"),
                       NSRect(x: 72, y: 530, width: 180, height: 14))
    }

    /// **`khong-ro` thì KHÔNG vẽ.** Một vùng bôi sáng lệch chỗ tệ hơn không bôi: người dùng sẽ
    /// đối chiếu con số với một vùng không phải nguồn của nó — và tin rằng mình vừa kiểm chứng.
    func testKhongRoQuyUocThiKhongVeVaNoiRaViSao() {
        XCTAssertNil(EideXemNguon.hinhChuNhat([72, 530, 180, 14], dang: "khong-ro"))
        let vi = EideXemNguon.viSaoKhongBoi([72, 530, 180, 14], dang: "khong-ro")
        XCTAssertTrue(vi.contains("lệch chỗ tệ hơn"), vi)
        XCTAssertTrue(EideXemNguon.viSaoKhongBoi(nil, dang: "khong-ro").contains("không ghi bbox"))
    }

    func testBboxHongThiTraNil() {
        XCTAssertNil(EideXemNguon.hinhChuNhat([1, 2, 3], dang: "rong-cao"))
        XCTAssertNil(EideXemNguon.hinhChuNhat(nil, dang: "rong-cao"))
        XCTAssertNil(EideXemNguon.hinhChuNhat("khong-phai-mang", dang: "rong-cao"))
    }

    // MARK: - mở tệp thật

    /// Mở ĐÚNG trang. `locator` đếm từ 1 như người đọc đếm, `PDFDocument` đếm từ 0 — lệch một
    /// trang là lỗi không ai thấy trên tài liệu dày, vì nó vẫn mở ra một trang trông hợp lý.
    func testMoDungTrangVaBoiSang() throws {
        let tep = try Self.taoPDF(soTrang: 5)
        defer { try? FileManager.default.removeItem(at: tep) }
        let v = EideXemNguon(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
        XCTAssertTrue(v.mo(["source": ["uri": tep.path], "page": 3,
                            "bbox": [72, 530, 180, 14], "bbox_dang": "rong-cao"]))
        XCTAssertEqual(v.trangDangMo, 3, "mở lệch trang")
        XCTAssertTrue(v.chuNhan.contains("trang 3"), v.chuNhan)
        XCTAssertTrue(v.chuNhan.contains("đã bôi sáng"), v.chuNhan)
    }

    /// Trang ngoài khoảng: vẫn MỞ tệp, nhưng nói rõ. Đóng hẳn thì người dùng mất luôn đường
    /// vào tài liệu chỉ vì một con số sai trong locator.
    func testTrangNgoaiKhoangThiVanMoTepVaNoiRa() throws {
        let tep = try Self.taoPDF(soTrang: 2)
        defer { try? FileManager.default.removeItem(at: tep) }
        let v = EideXemNguon(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
        XCTAssertTrue(v.mo(["source": ["uri": tep.path], "page": 99]))
        XCTAssertTrue(v.chuNhan.contains("ngoài khoảng"), v.chuNhan)
        XCTAssertTrue(v.chuNhan.contains("1…2"), v.chuNhan)
    }

    /// Bốn cách không mở được, và mỗi cách một câu KHÁC NHAU. Một khung trống không có lời là
    /// một khung người dùng đoán là sản phẩm hỏng.
    func testBonCachKhongMoDuocNoiBonCauKhacNhau() {
        let v = EideXemNguon(frame: NSRect(x: 0, y: 0, width: 600, height: 500))

        XCTAssertFalse(v.mo([:]))
        XCTAssertTrue(v.chuNhan.contains("không có nguồn nào"), v.chuNhan)

        XCTAssertFalse(v.mo(["source": ["uri": "https://st.com/rm0383.pdf"]]))
        XCTAssertTrue(v.chuNhan.contains("địa chỉ mạng"), v.chuNhan)

        XCTAssertFalse(v.mo(["source": ["uri": "/khong/co/\(UUID().uuidString).pdf"]]))
        XCTAssertTrue(v.chuNhan.contains("Không tìm thấy"), v.chuNhan)

        let txt = FileManager.default.temporaryDirectory
            .appendingPathComponent("x-\(UUID().uuidString).txt")
        try? "x".write(to: txt, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: txt) }
        XCTAssertFalse(v.mo(["source": ["uri": txt.path]]))
        XCTAssertTrue(v.chuNhan.contains("không phải PDF"), v.chuNhan)
    }

    /// Mở tệp thứ hai phải dọn sạch tệp thứ nhất — không thì vùng bôi sáng của fact trước còn
    /// nằm lại trên trang của fact sau.
    func testMoTepThuHaiThiDonSachTepThuNhat() throws {
        let a = try Self.taoPDF(soTrang: 3)
        let b = try Self.taoPDF(soTrang: 3)
        defer { for t in [a, b] { try? FileManager.default.removeItem(at: t) } }
        let v = EideXemNguon(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
        v.mo(["source": ["uri": a.path], "page": 2,
              "bbox": [10, 10, 50, 20], "bbox_dang": "rong-cao"])
        v.mo(["source": ["uri": b.path], "page": 1])
        XCTAssertEqual(v.trangDangMo, 1)
        XCTAssertTrue(v.chuNhan.contains((b.lastPathComponent as NSString).lastPathComponent),
                      v.chuNhan)
    }

    // MARK: - phụ

    /// PDF thật, sinh tại chỗ. Không nhúng một tệp mẫu vào kho: một tệp nhị phân trong git là
    /// thứ không ai đọc được diff, và bài kiểm này chỉ cần "một PDF có n trang".
    private static func taoPDF(soTrang: Int) throws -> URL {
        let d = PDFDocument()
        for i in 0..<soTrang {
            let t = PDFPage()
            t.setBounds(NSRect(x: 0, y: 0, width: 612, height: 792), for: .mediaBox)
            d.insert(t, at: i)
        }
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("eide-test-\(UUID().uuidString).pdf")
        guard d.write(to: u) else { throw NSError(domain: "test", code: 1) }
        return u
    }
}
