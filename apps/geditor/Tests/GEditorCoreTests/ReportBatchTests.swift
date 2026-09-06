import XCTest
@testable import GEditorCore

/// FR-RPT-006 — sinh loạt báo cáo từ danh sách tham số; cũng là vế batch của FR-DQR-003.
final class ReportBatchTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-batch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func write(_ name: String, _ text: String) throws -> String {
        let path = (folder as NSString).appendingPathComponent(name)
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Đọc danh sách

    func testCSVLayHangTIEUDELamTenThamSo() throws {
        let path = try write("tinh.csv", "tinh,thang\nHà Nội,2026-08\nHuế,2026-09\n")
        let sets = try ReportBatch.parameterSets(fromFile: path)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets[0].values, ["tinh": "Hà Nội", "thang": "2026-08"])
        XCTAssertEqual(sets[0].order, ["tinh", "thang"], "giữ THỨ TỰ CỘT của tệp")
        XCTAssertEqual(sets[1].values["tinh"], "Huế")
    }

    func testCSVHangTRONGOCuoiTepThiBoQua() throws {
        let path = try write("tinh.csv", "tinh\nHuế\n\n\n")
        XCTAssertEqual(try ReportBatch.parameterSets(fromFile: path).count, 1)
    }

    func testCSVODUOCBOCNgoacGiuNguyenDauPhay() throws {
        let path = try write("tinh.csv", "tinh\n\"Bà Rịa, Vũng Tàu\"\n")
        XCTAssertEqual(
            try ReportBatch.parameterSets(fromFile: path)[0].values["tinh"],
            "Bà Rịa, Vũng Tàu")
    }

    func testCSVTIEUDECoOTrongThiTuChoi() throws {
        let path = try write("tinh.csv", "tinh,,thang\nHuế,x,2026-08\n")
        XCTAssertThrowsError(try ReportBatch.parameterSets(fromFile: path)) { error in
            XCTAssertTrue(
                ((error as? ReportBatch.Failure)?.message ?? "").contains("TÊN"),
                "\(error)")
        }
    }

    func testJSONMangObject() throws {
        let path = try write("tinh.json", """
            [{"tinh": "Huế", "nam": 2026}, {"tinh": "Hà Nội", "nam": 2027}]
            """)
        let sets = try ReportBatch.parameterSets(fromFile: path)
        XCTAssertEqual(sets.count, 2)
        // Số ra chuỗi KHÔNG kèm phần thập phân: `2026` chứ không `2026.0`.
        XCTAssertEqual(sets[0].values["nam"], "2026")
        XCTAssertEqual(sets[0].order, ["nam", "tinh"], "khoá JSON sắp theo bảng chữ cái")
    }

    /// Một object đơn cũng nhận: chạy thử một bộ trước khi chạy cả sáu mươi ba là thao tác đầu
    /// tiên người ta làm.
    func testJSONMOTOBJECTCungNhan() throws {
        let path = try write("mot.json", "{\"tinh\": \"Huế\"}")
        XCTAssertEqual(try ReportBatch.parameterSets(fromFile: path).count, 1)
    }

    func testJSONBOOLEANRaTrueFalseKhongRa1() throws {
        let path = try write("co.json", "[{\"gop\": true, \"so\": 1}]")
        let values = try ReportBatch.parameterSets(fromFile: path)[0].values
        XCTAssertEqual(values["gop"], "true")
        XCTAssertEqual(values["so"], "1")
    }

    func testJSONGIATRILONGNHAUThiTuChoi() throws {
        let path = try write("hong.json", "[{\"tinh\": {\"ten\": \"Huế\"}}]")
        XCTAssertThrowsError(try ReportBatch.parameterSets(fromFile: path))
    }

    func testDANHSACHRONGThiNOIRa() throws {
        let path = try write("rong.csv", "tinh\n")
        XCTAssertThrowsError(try ReportBatch.parameterSets(fromFile: path)) { error in
            XCTAssertTrue(
                ((error as? ReportBatch.Failure)?.message ?? "").contains("không có bộ tham số"))
        }
    }

    // MARK: - Tên tệp đầu ra

    func testTENMACDINHGhepTuThanTepVaGiaTri() {
        let set = ReportBatch.ParameterSet(
            order: ["tinh", "thang"], values: ["tinh": "Huế", "thang": "2026-08"])
        XCTAssertEqual(
            ReportBatch.outputName(
                template: nil, set: set, reportPath: "/bc/thang.greport.md"),
            "thang-Huế-2026-08.html")
    }

    func testMAUTENThayChoTrong() {
        let set = ReportBatch.ParameterSet(order: ["tinh"], values: ["tinh": "Hà Nội"])
        XCTAssertEqual(
            ReportBatch.outputName(
                template: "bao-cao-{tinh}.html", set: set, reportPath: "/bc/x.greport.md"),
            "bao-cao-Hà_Nội.html")
    }

    /// Giữ chữ có dấu, chỉ bỏ những ký tự thật sự phá đường dẫn.
    ///
    /// `bao-cao-Thừa Thiên Huế.html` đọc được hơn hẳn `bao-cao-thua-thien-hue.html`; nhưng một
    /// dấu `/` trong tên tỉnh sẽ ghi tệp vào một thư mục KHÁC, im lặng.
    func testTENTEPGiuDauTiengVietNhungBoDauGACHCHEO() {
        XCTAssertEqual(ReportBatch.slug("Thừa Thiên Huế"), "Thừa_Thiên_Huế")
        XCTAssertEqual(ReportBatch.slug("a/b"), "a-b")
        XCTAssertEqual(ReportBatch.slug("a:b"), "a-b")
        XCTAssertEqual(ReportBatch.slug("../../etc/passwd"), "..-..-etc-passwd")
        XCTAssertEqual(ReportBatch.slug(""), "khong-ten")
    }

    // MARK: - Bảng tổng kết

    func testBANGTONGKETDemDungThanhCongVaLoi() {
        var outcome = ReportBatch.Outcome()
        outcome.entries = [
            .init(label: "tinh=Huế", path: "/bc/a.html", failed: false, message: ""),
            .init(label: "tinh=Hà Nội", path: nil, failed: true, message: "thiếu tham số :thang"),
        ]
        XCTAssertEqual(outcome.succeededCount, 1)
        XCTAssertEqual(outcome.failedCount, 1)
        let report = outcome.report
        XCTAssertTrue(report.contains("✔ tinh=Huế"), report)
        XCTAssertTrue(report.contains("✖ tinh=Hà Nội"), report)
        XCTAssertTrue(report.contains("1 xong · 1 hỏng"), report)
    }
}
