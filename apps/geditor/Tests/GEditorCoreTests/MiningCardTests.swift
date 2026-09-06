import XCTest
@testable import GEditorCore

/// FR-MIN-007 — khối ```mining trong báo cáo.
final class MiningBlockSpecTests: XCTestCase {

    func testDUMOIKHOA() throws {
        let spec = try MiningBlockSpec.parse("""
            group_by: tinh
            value: doanh_thu
            pair: chi_phi
            rank: forecast_error
            limit: 5
            horizon: 6
            iqr_k: 2.0
            min_rows: 12
            source: khac.csv
            title: Khai phá theo tỉnh
            chart: false
            """)
        XCTAssertEqual(spec.groupBy, "tinh")
        XCTAssertEqual(spec.value, "doanh_thu")
        XCTAssertEqual(spec.pair, "chi_phi")
        XCTAssertEqual(spec.rank, .forecastError)
        XCTAssertEqual(spec.limit, 5)
        XCTAssertEqual(spec.horizon, 6)
        XCTAssertEqual(spec.iqrK, 2)
        XCTAssertEqual(spec.minimumRows, 12)
        XCTAssertEqual(spec.source, "khac.csv")
        XCTAssertFalse(spec.chart)
    }

    func testKHOALAThiBAOLOI() {
        XCTAssertThrowsError(
            try MiningBlockSpec.parse("group_by: tinh\nvalue: x\ngroupby: tinh")
        ) { error in
            let message = (error as? MiningBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("«groupby»"), message)
            XCTAssertTrue(message.contains("group_by"), "phải liệt kê khoá đúng: \(message)")
        }
    }

    func testTHIEUGROUPBYThiNoiNoDeLamGi() {
        XCTAssertThrowsError(try MiningBlockSpec.parse("value: x")) { error in
            let message = (error as? MiningBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("group_by"), message)
            XCTAssertTrue(message.contains("từng nhóm") || message.contains("mỗi nhóm"), message)
        }
    }

    func testTHIEUVALUEThiTuChoi() {
        XCTAssertThrowsError(try MiningBlockSpec.parse("group_by: tinh")) { error in
            XCTAssertTrue(
                ((error as? MiningBlockSpec.Failure)?.message ?? "").contains("value"))
        }
    }

    /// Tự tương quan với chính mình luôn ra r = 1 ở mọi nhóm — một cột đầy số 1 trông như một
    /// kết quả. Nói ra thay vì âm thầm bỏ khoá `pair`.
    func testPAIRTrungVALUEThiTuChoi() {
        XCTAssertThrowsError(
            try MiningBlockSpec.parse("group_by: tinh\nvalue: x\npair: x")
        ) { error in
            XCTAssertTrue(
                ((error as? MiningBlockSpec.Failure)?.message ?? "").contains("luôn bằng 1"))
        }
    }

    /// Tên `rank` viết theo lối YAML, không theo lối Swift.
    func testRANKNhanTenGachDuoi_VaLietKeCaiCoKhiSai() throws {
        XCTAssertEqual(
            try MiningBlockSpec.parse("group_by: a\nvalue: b\nrank: correlation_gap").rank,
            .correlationGap)
        XCTAssertThrowsError(
            try MiningBlockSpec.parse("group_by: a\nvalue: b\nrank: forecastError")
        ) { error in
            let message = (error as? MiningBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("forecast_error"), message)
        }
    }

    func testSOAMHoacKHONGThiTuChoi() {
        for yaml in ["limit: 0", "horizon: 0", "iqr_k: 0", "min_rows: 1"] {
            XCTAssertThrowsError(
                try MiningBlockSpec.parse("group_by: a\nvalue: b\n" + yaml), yaml)
        }
    }

    func testOPTIONSChuyenDungSangGroupMining() throws {
        let spec = try MiningBlockSpec.parse("""
            group_by: tinh
            value: doanh_thu
            pair: chi_phi
            """)
        let options = spec.options
        XCTAssertEqual(options.anomalyColumn, "doanh_thu")
        XCTAssertEqual(options.forecastColumn, "doanh_thu")
        XCTAssertEqual(options.correlationPair?.0, "doanh_thu")
        XCTAssertEqual(options.correlationPair?.1, "chi_phi")

        // Không khai `pair` thì KHÔNG chạy phần tương quan, chứ không tự ghép bừa một cột.
        let ngan = try MiningBlockSpec.parse("group_by: tinh\nvalue: doanh_thu")
        XCTAssertNil(ngan.options.correlationPair)
    }
}

/// FR-MIN-007 — chạy khối và vẽ bảng xếp hạng nhóm.
final class MiningCardTests: XCTestCase {

    private var folder = ""

    /// Hai nhóm có PHÂN BỐ RẤT KHÁC NHAU, và mỗi nhóm có đúng một giá trị lệch của riêng nó.
    ///
    /// Đây là ca mà đặc tả gọi là "lỗi kinh điển": một hàng rào IQR chung sẽ bỏ sót giá trị 200
    /// của nhóm nhỏ (nó nằm gọn trong hàng rào của nhóm lớn) và có thể báo nhầm ở nhóm lớn.
    private func bang() -> String {
        var rows = ["tinh,doanh_thu,chi_phi"]
        for index in 0..<12 {
            let value = 1000 + (index % 3) * 10
            rows.append("Lớn,\(value),\(value / 2)")
        }
        rows.append("Lớn,1030,515")
        for index in 0..<12 {
            let value = 50 + (index % 3)
            rows.append("Nhỏ,\(value),\(value * 3)")
        }
        rows.append("Nhỏ,200,600")          // bất thường CỦA RIÊNG nhóm nhỏ
        rows.append("TíHon,7,3")            // nhóm quá ít hàng
        return rows.joined(separator: "\n") + "\n"
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-mining-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try bang().write(toFile: folder + "/nhom.csv", atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func render(_ text: String) throws -> ReportRenderer.Rendered {
        let source = folder + "/nhom.csv"
        let bytes = FileManager.default.contents(atPath: source) ?? Data()
        return try ReportRenderer.render(
            try ReportDocument.parse(text),
            in: TextBuffer(original: MemoryByteSource([UInt8](bytes))), dialect: .comma,
            options: ReportRenderer.Options(sourcePath: source, basePath: folder))
    }

    private let block = """
        ```mining
        group_by: tinh
        value: doanh_thu
        pair: chi_phi
        title: Khai phá theo tỉnh
        ```
        """

    func testBANGXEPHANGNhomVaKHOIPHUONGPHAP() throws {
        let rendered = try render(block)
        XCTAssertTrue(rendered.failures.isEmpty, "\(rendered.failures)")
        XCTAssertEqual(rendered.succeeded, 1)

        let html = rendered.html
        XCTAssertTrue(html.contains("Khai phá theo tỉnh"), html)
        XCTAssertTrue(html.contains("<td class=\"txt\">Nhỏ</td>"), html)
        XCTAssertTrue(html.contains("<td class=\"txt\">Lớn</td>"), html)
        // Khối Phương pháp là BẮT BUỘC (NFR-MIN-04) — không có khoá nào tắt nó.
        XCTAssertTrue(html.contains("Phương pháp"), html)
        XCTAssertTrue(html.contains("hàng rào tính RIÊNG cho từng nhóm"), html)
        XCTAssertTrue(html.contains("Tương quan không hàm ý nhân quả"), html)
    }

    /// Mỗi nhóm một hàng rào riêng — nhóm NHỎ phải bắt được bất thường của chính nó.
    ///
    /// Nếu một ngày nào đó mã quay về dùng hàng rào gộp, giá trị 200 của nhóm «Nhỏ» sẽ nằm gọn
    /// trong hàng rào dựng từ dữ liệu quanh 1000 và bảng sẽ báo 0 bất thường.
    func testNHOMNHOBatDuocBatThuongCuaRIENGNo() throws {
        let card = try MiningCard.run(
            try MiningBlockSpec.parse("group_by: tinh\nvalue: doanh_thu"),
            basePath: folder,
            fallbackBuffer: TextBuffer(text: bang()), fallbackSourcePath: folder + "/nhom.csv",
            dialect: .comma)
        let small = try XCTUnwrap(card.report.groups.first { $0.name == "Nhỏ" })
        XCTAssertGreaterThan(small.anomalies, 0, "hàng rào riêng phải bắt được giá trị 200")
        let big = try XCTUnwrap(card.report.groups.first { $0.name == "Lớn" })
        XCTAssertNotNil(big.fence)
        XCTAssertNotNil(small.fence)
        XCTAssertGreaterThan(
            big.fence?.high ?? 0, small.fence?.high ?? 0,
            "hai nhóm phải có hai hàng rào KHÁC nhau")
    }

    /// Nhóm quá ít hàng vẫn hiện ra, kèm lý do — không biến mất trong im lặng.
    func testNHOMKHONGCHAMDUOCVanNoiRa() throws {
        let html = try render(block).html
        XCTAssertTrue(html.contains("không chấm được"), html)
        XCTAssertTrue(html.contains("TíHon"), html)
    }

    func testKHONGKHAIPAIRThiKHONGCoCotTuongQuan() throws {
        let html = try render("```mining\ngroup_by: tinh\nvalue: doanh_thu\n```").html
        XCTAssertFalse(html.contains("<th>Lệch r</th>"), html)
        XCTAssertFalse(html.contains("Tương quan trên TOÀN BỘ"), html)
    }

    /// Số trong thẻ và số trong khối Phương pháp phải là MỘT.
    ///
    /// Bản đầu in 3 chữ số ở bảng và khối Phương pháp in 2 — tấm thẻ nói tương quan toàn bộ là
    /// 0,999 trong khi dòng ngay dưới nó nói 1,00.
    func testSOTrongBangVaTrongPHUONGPHAPGiongNhau() throws {
        let html = try render(block).html
        let pooled = try XCTUnwrap(
            MiningCard.run(
                try MiningBlockSpec.parse(
                    "group_by: tinh\nvalue: doanh_thu\npair: chi_phi"),
                basePath: folder, fallbackBuffer: TextBuffer(text: bang()),
                fallbackSourcePath: folder + "/nhom.csv", dialect: .comma
            ).report.pooledCorrelation)
        let text = ChartRender.number(pooled)
        // Con số ấy xuất hiện ở CẢ HAI chỗ, và phải viết giống nhau.
        XCTAssertTrue(
            html.contains("Tương quan trên TOÀN BỘ dữ liệu: " + text), "thiếu ở ghi chú bảng")
        XCTAssertTrue(html.contains("so với mốc toàn bộ " + text), "thiếu ở khối Phương pháp")
    }

    func testCOTKHONGTONTAIThiNoiTenCot() throws {
        let rendered = try render("```mining\ngroup_by: khong_co\nvalue: doanh_thu\n```")
        XCTAssertEqual(rendered.failures.count, 1)
        XCTAssertTrue(
            rendered.failures[0].message.contains("khong_co"), rendered.failures[0].message)
    }

    func testCOTNHOMTOANORONGThiNoiRa() throws {
        try "tinh,doanh_thu\n,10\n,20\n"
            .write(toFile: folder + "/rong.csv", atomically: true, encoding: .utf8)
        let rendered = try render("""
            ```mining
            group_by: tinh
            value: doanh_thu
            source: rong.csv
            ```
            """)
        XCTAssertEqual(rendered.failures.count, 1)
        XCTAssertTrue(
            rendered.failures[0].message.contains("mọi ô đều rỗng"),
            rendered.failures[0].message)
    }

    /// Khối chạy hai lần phải cho ra HTML giống hệt — NFR-MIN-02 (*"kết quả trong báo cáo
    /// `.greport.md` tái lập được"*).
    func testCHAYHAILANRaHTMLGiongHET() throws {
        XCTAssertEqual(try render(block).html, try render(block).html)
    }
}
