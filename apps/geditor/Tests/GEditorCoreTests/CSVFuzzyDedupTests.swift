import XCTest
@testable import GEditorCore

/// Trùng lặp mờ trên cột CSV — FR-CLN-004.
final class CSVFuzzyDedupTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private let khachHang = """
    ma,ten,tinh
    1,Công ty TNHH An Phát,Hà Nội
    2,Cty TNHH An Phát,Hà Nội
    3,CÔNG TY TNHH AN PHAT,Hà Nội
    4,Công ty CP Bình Minh,Đà Nẵng
    5,Xưởng gỗ Trường Sơn,Huế
    """

    // MARK: - Tìm cụm

    func testGomBienTheViettatVaThieuDauVeMotCum() throws {
        let clusters = try CSVFuzzyDedup.scan(
            column: 1, in: buffer(khachHang), dialect: .comma)

        XCTAssertEqual(clusters.count, 1, "chỉ có đúng một cụm ứng viên")
        let cum = clusters[0]
        XCTAssertEqual(cum.rowIndices, [1, 2, 3], "ba hàng đầu, tính cả dòng tiêu đề")
        XCTAssertEqual(Set(cum.values), [
            "Công ty TNHH An Phát", "Cty TNHH An Phát", "CÔNG TY TNHH AN PHAT",
        ])
    }

    /// «Cty» và «Công ty» lệch 5 ký tự trên 20 — trượt mọi ngưỡng hợp lý. Chỉ bảng viết tắt cứu
    /// được, nên bài này canh đúng vế ấy của đặc tả.
    func testBangViettatLaThuDuyNhatKeoDuocCtyVeCongTy() {
        let raw = TextDistance.similarity("Cty TNHH An Phát", "Công ty TNHH An Phát",
                                          threshold: 0)
        XCTAssertLessThan(raw, CSVFuzzyDedup.defaultThreshold,
                          "nếu khoảng cách chuỗi trần đã đủ thì bảng viết tắt là thừa")

        let sau = TextDistance.similarity(
            CSVFuzzyDedup.normalize("Cty TNHH An Phát"),
            CSVFuzzyDedup.normalize("Công ty TNHH An Phát"),
            threshold: 0)
        XCTAssertEqual(sau, 1.0, accuracy: 0.001, "sau khi quy viết tắt thì hai chuỗi trùng khít")
    }

    /// Viết tắt chỉ đổi khi đứng thành TỪ RIÊNG — thay theo chuỗi con sẽ phá tên riêng.
    func testViettatKhongDoiKhiNamTrongMotTuKhac() {
        XCTAssertEqual(CSVFuzzyDedup.normalize("Quang Cty"), "quang cong ty")
        XCTAssertEqual(CSVFuzzyDedup.normalize("Quang"), "quang",
                       "«q» nằm trong «Quang» KHÔNG được thành «quan»")
        XCTAssertEqual(CSVFuzzyDedup.normalize("Xuan Hoa"), "xuan hoa",
                       "«x» nằm trong «Xuan» KHÔNG được thành «xa»")
    }

    /// Hai công ty THẬT khác nhau không được dính vào nhau.
    func testKhongGomHaiTenThucSuKhacNhau() throws {
        let clusters = try CSVFuzzyDedup.scan(
            column: 1, in: buffer(khachHang), dialect: .comma)
        let phang = clusters.flatMap(\.values)
        XCTAssertFalse(phang.contains("Công ty CP Bình Minh"))
        XCTAssertFalse(phang.contains("Xưởng gỗ Trường Sơn"))
    }

    /// Ô TRỐNG là việc của FR-CLN-002, không phải của phép so mờ — gom chúng vào đây sẽ đẻ ra
    /// một cụm khổng lồ nuốt mọi cụm thật.
    func testOTrongKhongThanhMotCum() throws {
        let text = "ten\n\n\n\n  \nAn Phát\n"
        XCTAssertTrue(try CSVFuzzyDedup.scan(column: 0, in: buffer(text), dialect: .comma).isEmpty)
    }

    func testDiemTuongDongLaCANDUOIcuaCum() throws {
        let cum = try CSVFuzzyDedup.scan(column: 1, in: buffer(khachHang), dialect: .comma)[0]
        XCTAssertLessThanOrEqual(cum.lowestSimilarity, 1.0)
        XCTAssertGreaterThan(cum.lowestSimilarity, 0.0)
    }

    // MARK: - Đề nghị

    func testDeNghiLayDangPhoBienNhat() {
        XCTAssertEqual(CSVFuzzyDedup.deNghi(["An Phát", "An Phat", "An Phát"]), "An Phát")
    }

    /// Hoà số lần thì lấy bản DÀI hơn: viết tắt là thứ người ta gõ khi vội.
    func testHoaThiLayBanDayDuHon() {
        XCTAssertEqual(CSVFuzzyDedup.deNghi(["Cty An Phát", "Công ty An Phát"]),
                       "Công ty An Phát")
    }

    func testDeNghiTatDinh() {
        let values = ["Bê", "Bế", "Be"]
        XCTAssertEqual(CSVFuzzyDedup.deNghi(values), CSVFuzzyDedup.deNghi(values))
    }

    // MARK: - Bất biến: KHÔNG BAO GIỜ tự gộp

    /// Bài quan trọng nhất của tệp này. Đặc tả viết thẳng *"không bao giờ tự merge"*, và cách
    /// duy nhất giữ được điều đó qua tầng giao diện là: không có quyết định thì không có sửa đổi.
    func testKhongCoQuyetDinhThiKHONGcoSuaDoiNao() throws {
        let doc = buffer(khachHang)
        let clusters = try CSVFuzzyDedup.scan(column: 1, in: doc, dialect: .comma)
        XCTAssertFalse(clusters.isEmpty, "phải có cụm thì bài kiểm mới có nghĩa")

        let edits = try CSVFuzzyDedup.edits(
            applying: [:], to: clusters, column: 1, in: doc, dialect: .comma)
        XCTAssertTrue(edits.isEmpty, "quét xong mà chưa ai duyệt thì tuyệt đối không sửa gì")
    }

    func testQuyetDinhGIUcungKHONGsuaGi() throws {
        let doc = buffer(khachHang)
        let clusters = try CSVFuzzyDedup.scan(column: 1, in: doc, dialect: .comma)
        let edits = try CSVFuzzyDedup.edits(
            applying: [0: .keep], to: clusters, column: 1, in: doc, dialect: .comma)
        XCTAssertTrue(edits.isEmpty)
    }

    func testChiCumDuocDUYETmoiDoi() throws {
        let doc = buffer(khachHang)
        let clusters = try CSVFuzzyDedup.scan(column: 1, in: doc, dialect: .comma)
        let edits = try CSVFuzzyDedup.edits(
            applying: [0: .unify(to: "Công ty TNHH An Phát")],
            to: clusters, column: 1, in: doc, dialect: .comma)

        // Ba hàng trong cụm, một hàng ĐÃ đúng giá trị đích nên không cần sửa.
        XCTAssertEqual(edits.count, 2)

        var sua = doc
        sua.applyEdits(edits, label: "khử trùng lặp mờ")
        let text = sua.text
        XCTAssertEqual(text.components(separatedBy: "Công ty TNHH An Phát").count - 1, 3)
        // Hàng ngoài cụm KHÔNG được đụng tới.
        XCTAssertTrue(text.contains("Công ty CP Bình Minh"))
        XCTAssertTrue(text.contains("Xưởng gỗ Trường Sơn"))
    }

    /// Cột khác không bị đụng — phép sửa phải nhắm đúng ô, không nhắm cả hàng.
    func testChiSuaDUNGCOTdaChon() throws {
        let doc = buffer(khachHang)
        let clusters = try CSVFuzzyDedup.scan(column: 1, in: doc, dialect: .comma)
        let edits = try CSVFuzzyDedup.edits(
            applying: [0: .unify(to: "X")], to: clusters, column: 1, in: doc, dialect: .comma)
        var sua = doc
        sua.applyEdits(edits, label: "t")
        for dong in sua.text.split(separator: "\n").dropFirst() {
            let o = dong.split(separator: ",", omittingEmptySubsequences: false)
            XCTAssertEqual(o.count, 3, "số cột phải giữ nguyên: \(dong)")
        }
        XCTAssertTrue(sua.text.contains("1,X,Hà Nội"))
    }

    /// Giá trị đích chứa dấu phân tách thì phải được bọc — nếu không, một lần "gộp" làm vỡ cấu
    /// trúc file, và đó là hỏng nặng hơn hẳn thứ nó định sửa.
    func testGiaTriDichCoDauPhayThiDuocBOC() throws {
        let doc = buffer(khachHang)
        let clusters = try CSVFuzzyDedup.scan(column: 1, in: doc, dialect: .comma)
        let edits = try CSVFuzzyDedup.edits(
            applying: [0: .unify(to: "An Phát, JSC")],
            to: clusters, column: 1, in: doc, dialect: .comma)
        var sua = doc
        sua.applyEdits(edits, label: "t")
        XCTAssertTrue(sua.text.contains("\"An Phát, JSC\""), "thiếu dấu bọc: \(sua.text)")
        // Và cấu trúc file vẫn đọc được: mọi hàng vẫn đúng ba cột.
        var soCot: [Int] = []
        try CSVEngine.forEachRow(in: sua, dialect: .comma) { row in
            soCot.append(row.count); return true
        }
        XCTAssertEqual(Set(soCot), [3], "số cột vỡ sau khi gộp: \(soCot)")
    }
}
