import XCTest
@testable import GEditorCore

/// Đánh dấu entity — FR-KNW-908.
final class EntityMarkerTests: XCTestCase {

    private func find(_ entities: [(String, String)], in text: String) -> EntityMarker.Report {
        EntityMarker.find(entities.map { EntityMarker.Entity(text: $0.0, type: $0.1) },
                          in: TextBuffer(text: text))
    }

    private func matched(_ r: EntityMarker.Report, _ text: String) -> [String] {
        let b = TextBuffer(text: text)
        return r.occurrences.map { String(decoding: b.bytes(in: $0.range), as: UTF8.self) }
    }

    // MARK: - Ba luật khớp

    /// Có cả «An Phát» lẫn «Công ty An Phát» thì cụm DÀI phải thắng. Khớp ngắn trước sẽ cắt cụm
    /// dài làm đôi và đếm thành hai entity — con số thống kê sai theo hướng phóng đại.
    func testKhopDAINHATthang() {
        let text = "Công ty An Phát ký hợp đồng."
        let r = find([("An Phát", "ORG"), ("Công ty An Phát", "ORG")], in: text)
        XCTAssertEqual(matched(r, text), ["Công ty An Phát"])
        XCTAssertEqual(r.occurrences.count, 1, "cụm dài bị cắt làm đôi")
    }

    /// «An» không được khớp bên trong «Anh» — tên riêng tiếng Việt ngắn và trùng âm tiết với vô
    /// số từ thường, nên đây không phải ca hiếm.
    func testPhaiDungBIENTU() {
        XCTAssertTrue(find([("An", "PER")], in: "Anh ấy tên Hoàn.").occurrences.isEmpty)
        XCTAssertEqual(find([("An", "PER")], in: "Anh gọi An.").occurrences.count, 1)
    }

    func testKhongPhanBietHoaThuong() {
        let text = "CÔNG TY AN PHÁT và Công ty An Phát"
        XCTAssertEqual(find([("công ty an phát", "ORG")], in: text).occurrences.count, 2)
    }

    /// GIỮ dấu: «má» và «ma» là hai từ khác nhau. Ngược với `TextDistance.normalize`, và hai chỗ
    /// hỏi hai câu khác nhau.
    func testGIUdauTiengViet() {
        XCTAssertTrue(find([("má", "PER")], in: "con ma").occurrences.isEmpty)
        XCTAssertEqual(find([("má", "PER")], in: "con má").occurrences.count, 1)
    }

    /// Biên rơi vào GIỮA một ký tự nhiều byte là lỗi khó thấy nhất của nhóm này.
    func testBienKhongRoiVaoGIUAmotKyTu() {
        let text = "Nguyễnnn"
        XCTAssertTrue(find([("Nguyễn", "PER")], in: text).occurrences.isEmpty,
                      "khớp bên trong một từ dài hơn")
    }

    // MARK: - Thống kê

    func testThongKeTheoLoaiVaTheoEntity() {
        let text = "An gặp Bình. An về."
        let r = find([("An", "PER"), ("Bình", "PER")], in: text)
        XCTAssertEqual(r.byType["PER"], 3)
        XCTAssertEqual(r.byEntity[0], 2)
        XCTAssertEqual(r.byEntity[1], 1)
    }

    /// Màu gán TẤT ĐỊNH theo thứ tự bảng chữ cái — màu đổi giữa hai lần chạy trên cùng một file
    /// làm người dùng tưởng dữ liệu đổi.
    func testMauTATDINHtheoTenLoai() {
        let a = find([("x", "ORG"), ("y", "PER")], in: "x y")
        let b = find([("y", "PER"), ("x", "ORG")], in: "x y")
        XCTAssertEqual(a.colorOfType, b.colorOfType)
        XCTAssertEqual(a.colorOfType["ORG"], 0)
        XCTAssertEqual(a.colorOfType["PER"], 1)
    }

    func testSoDongDungCho() {
        let text = "dòng một\nAn ở đây\n"
        let r = find([("An", "PER")], in: text)
        XCTAssertEqual(r.occurrences.first?.line, 1)
    }

    func testDanhSachRONGthiKhongNemLoi() {
        XCTAssertTrue(find([], in: "bất kỳ").occurrences.isEmpty)
    }

    // MARK: - Nạp danh sách

    func testNapCSVvaBoDongTieuDe() throws {
        let e = try EntityMarker.loadCSV("text,type\nAn,PER\nAn Phát,ORG\n")
        XCTAssertEqual(e.count, 2)
        XCTAssertEqual(e[0].text, "An")
        XCTAssertEqual(e[1].type, "ORG")
    }

    /// Nhận ra tiêu đề bằng NỘI DUNG, không bằng vị trí: danh sách xuất từ công cụ khác có thể
    /// không có tiêu đề, và bỏ dòng đầu vô điều kiện là mất một entity mà không ai biết.
    func testKHONGcoTieuDeThiKhongMatDongDau() throws {
        let e = try EntityMarker.loadCSV("An,PER\nBình,PER\n")
        XCTAssertEqual(e.count, 2, "dòng đầu bị nuốt: \(e)")
        XCTAssertEqual(e[0].text, "An")
    }

    func testCotLoaiRONGthiVeKHAC() throws {
        let e = try EntityMarker.loadCSV("An,\n")
        XCTAssertEqual(e.first?.type, "khác")
    }

    func testNapJSON() throws {
        let e = try EntityMarker.loadJSON("""
        [{"text":"An","type":"PER"},{"text":"An Phát"}]
        """)
        XCTAssertEqual(e.count, 2)
        XCTAssertEqual(e[1].type, "khác")
    }

    func testJSONkhongPhaiMangThiNOIRA() {
        XCTAssertThrowsError(try EntityMarker.loadJSON("{\"text\":\"An\"}")) { error in
            XCTAssertTrue("\(error)".contains("MẢNG"), "\(error)")
        }
    }

    // MARK: - Quy mô

    /// Quét MỘT LƯỢT: 2.000 entity trên một tài liệu vừa phải không được thành 2.000 lượt quét.
    func testMotLuotQuetVoiNhieuEntity() {
        let entities = (0 ..< 2000).map { ("thucthe\($0)", "T\($0 % 5)") }
        let text = (0 ..< 500).map { "câu số \($0) có thucthe\($0)." }.joined(separator: "\n")
        let batDau = Date()
        let r = find(entities, in: text)
        XCTAssertEqual(r.occurrences.count, 500)
        XCTAssertLessThan(Date().timeIntervalSince(batDau), 2.0,
                          "quét lâu bất thường — có thể đã thành N lượt quét toàn văn")
    }
}
