import XCTest
@testable import GEditorCore

/// FR-DQR-004 — lịch sử `.gquality.history.jsonl` và so trôi dạt.
final class QualityHistoryTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-hist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    // MARK: - Tên tệp

    func testTENTEPLICHSUSuyTuTenTEPLUAT() {
        XCTAssertEqual(
            QualityHistory.historyPath(forRules: "/du/lieu/.gquality.yaml"),
            "/du/lieu/.gquality.history.jsonl")
        XCTAssertEqual(
            QualityHistory.historyPath(forRules: "/du/lieu/chuan-ban-hang.yml"),
            "/du/lieu/chuan-ban-hang.history.jsonl")
        // Tệp luật không có đuôi quen thuộc thì vẫn phải ra một tên đọc được.
        XCTAssertEqual(
            QualityHistory.historyPath(forRules: "/du/lieu/chuan"),
            "/du/lieu/chuan.history.jsonl")
    }

    // MARK: - Ghi và đọc

    private func snapshot(
        total: Double?, rows: Int = 100, at day: String = "2026-08-20",
        dimensions: [QualitySnapshot.DimensionEntry] = [],
        rules: [QualitySnapshot.RuleEntry] = [],
        columns: [QualitySnapshot.ColumnEntry] = [],
        hash: String = "abc"
    ) -> QualitySnapshot {
        QualitySnapshot(
            timestamp: day + "T08:00:00Z", sourcePath: "/du/lieu/ban-hang.csv",
            sourceHash: hash, rowCount: rows, total: total, dimensions: dimensions,
            rules: rules, columns: columns, milliseconds: 12)
    }

    func testGHINOIDUOI_KhongDeLenBanTruoc() throws {
        let path = folder + "/.gquality.history.jsonl"
        try QualityHistory.append(snapshot(total: 90, at: "2026-08-20"), to: path)
        try QualityHistory.append(snapshot(total: 80, at: "2026-08-21"), to: path)
        try QualityHistory.append(snapshot(total: 70, at: "2026-08-22"), to: path)

        let log = QualityHistory.read(path: path)
        XCTAssertEqual(log.snapshots.count, 3)
        XCTAssertEqual(log.snapshots.map(\.total), [90, 80, 70])
        XCTAssertEqual(log.last?.total, 70, "bản gần nhất là bản CUỐI")
        XCTAssertEqual(log.brokenLines, 0)
    }

    /// Một dòng hỏng chỉ mất một dòng — và số dòng hỏng phải NÓI RA.
    ///
    /// Một tệp lịch sử mất nửa số dòng mà vẫn vẽ ra đường xu hướng mượt mà là một đường xu hướng
    /// nói dối.
    func testDONGHONGChiMatMotDong_VaDuocDEM() throws {
        let path = folder + "/.gquality.history.jsonl"
        try QualityHistory.append(snapshot(total: 90), to: path)
        try "{ dòng này hỏng\n".write(
            toFile: folder + "/them.txt", atomically: true, encoding: .utf8)
        let handle = try XCTUnwrap(FileHandle(forWritingAtPath: path))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{ hỏng\n".utf8))
        try handle.close()
        try QualityHistory.append(snapshot(total: 80, at: "2026-08-21"), to: path)

        let log = QualityHistory.read(path: path)
        XCTAssertEqual(log.snapshots.count, 2)
        XCTAssertEqual(log.brokenLines, 1)
    }

    /// Chiều KHÔNG chấm được phải đi qua JSON mà vẫn là `null`, không thành 0.
    ///
    /// Đổi nó thành 0 ở đây sẽ sinh ra một dòng "tụt 87 điểm" trong bảng so sánh cho một chiều
    /// chưa bao giờ có điểm.
    func testCHIEUKHONGCHAMDUOCVanLaNULLSauKhiDiQuaJSON() throws {
        let path = folder + "/.gquality.history.jsonl"
        try QualityHistory.append(snapshot(
            total: 90,
            dimensions: [
                .init(name: "completeness", value: 98, weight: 1, note: nil),
                .init(name: "uniqueness", value: nil, weight: 1, note: "chưa khai khoá"),
            ]), to: path)
        let read = try XCTUnwrap(QualityHistory.read(path: path).last)
        XCTAssertEqual(read.dimension("completeness")?.value, 98)
        XCTAssertNil(read.dimension("uniqueness")?.value)
        XCTAssertEqual(read.dimension("uniqueness")?.note, "chưa khai khoá")
    }

    func testKHONGCOTEPThiLaLichSuRONG_KhongPhaiLoi() {
        let log = QualityHistory.read(path: folder + "/chua-co.jsonl")
        XCTAssertTrue(log.isEmpty)
        XCTAssertEqual(log.brokenLines, 0)
    }

    // MARK: - So sánh

    func testLANDAUThiKHONGCoGiDeSo() {
        let comparison = QualityDrift.compare(current: snapshot(total: 90), previous: nil)
        XCTAssertFalse(comparison.hasPrevious)
        XCTAssertTrue(comparison.alerts.isEmpty, "chưa có lần trước thì không cảnh báo gì")
        XCTAssertEqual(QualityDrift.html(comparison), "", "không vẽ bảng so sánh rỗng")
    }

    func testDIEMTONGTUTVuotNguongThiCANHBAO() {
        let comparison = QualityDrift.compare(
            current: snapshot(total: 82, at: "2026-08-21"),
            previous: snapshot(total: 90),
            thresholds: QualityRules.Drift(maxTotalDrop: 5))
        XCTAssertEqual(comparison.totalDelta, -8)
        XCTAssertEqual(comparison.alerts.count, 1)
        XCTAssertTrue(comparison.alerts[0].contains("tụt 8"), comparison.alerts[0])
    }

    /// Điểm TĂNG không cảnh báo — một cổng kêu khi chất lượng tốt lên là cổng sẽ bị tắt.
    func testDIEMTANGThiKHONGCanhBao() {
        let comparison = QualityDrift.compare(
            current: snapshot(total: 98, at: "2026-08-21"),
            previous: snapshot(total: 80),
            thresholds: QualityRules.Drift(maxTotalDrop: 5))
        XCTAssertTrue(comparison.alerts.isEmpty, "\(comparison.alerts)")
    }

    /// Số HÀNG thì ngược lại: đổi chiều nào cũng đáng ngờ — gấp đôi thường là chép trùng.
    func testSOHANGDoiHaiCHIEUDeuCanhBao() {
        let thresholds = QualityRules.Drift(maxRowChangePercent: 20)
        let tang = QualityDrift.compare(
            current: snapshot(total: 90, rows: 200, at: "2026-08-21"),
            previous: snapshot(total: 90, rows: 100), thresholds: thresholds)
        let giam = QualityDrift.compare(
            current: snapshot(total: 90, rows: 50, at: "2026-08-21"),
            previous: snapshot(total: 90, rows: 100), thresholds: thresholds)
        XCTAssertEqual(tang.alerts.count, 1, "\(tang.alerts)")
        XCTAssertEqual(giam.alerts.count, 1, "\(giam.alerts)")
        XCTAssertTrue(tang.alerts[0].contains("100 → 200"), tang.alerts[0])
    }

    func testCHIEUTUTVuotNguongThiNoiTENCHIEU() {
        let comparison = QualityDrift.compare(
            current: snapshot(total: 90, at: "2026-08-21", dimensions: [
                .init(name: "completeness", value: 70, weight: 1, note: nil),
            ]),
            previous: snapshot(total: 90, dimensions: [
                .init(name: "completeness", value: 99, weight: 1, note: nil),
            ]),
            thresholds: QualityRules.Drift(maxDimensionDrop: 10))
        XCTAssertEqual(comparison.alerts.count, 1)
        XCTAssertTrue(comparison.alerts[0].contains("Đầy đủ"), comparison.alerts[0])
    }

    func testNULLTANGVuotNguongThiNoiTENCOT() {
        let comparison = QualityDrift.compare(
            current: snapshot(total: 90, at: "2026-08-21", columns: [
                .init(column: "email", nullPercent: 12),
                .init(column: "tinh", nullPercent: 0),
            ]),
            previous: snapshot(total: 90, columns: [
                .init(column: "email", nullPercent: 1),
                .init(column: "tinh", nullPercent: 0),
            ]),
            thresholds: QualityRules.Drift(maxNullIncreasePercent: 2))
        XCTAssertEqual(comparison.columns.count, 1, "cột không đổi thì không vào bảng")
        XCTAssertEqual(comparison.alerts.count, 1)
        XCTAssertTrue(comparison.alerts[0].contains("email"), comparison.alerts[0])
    }

    /// Luật khoá theo TIÊU ĐỀ, không theo chỉ số.
    ///
    /// Chỉ số đổi ngay khi người dùng chèn một luật vào giữa tệp, và khi ấy bảng so sánh báo
    /// "mười luật mới trượt" trong khi không luật nào đổi trạng thái.
    func testLUATKhoaTheoTIEUDE_KhongTheoCHISO() {
        let cu = [
            QualitySnapshot.RuleEntry(title: "«a» không rỗng", column: "a", severity: "error",
                                      passed: true, violations: 0, failure: nil),
            QualitySnapshot.RuleEntry(title: "«b» không trùng", column: "b", severity: "error",
                                      passed: true, violations: 0, failure: nil),
        ]
        // Luật MỚI chèn vào GIỮA, và luật «b» nay trượt.
        let moi = [
            cu[0],
            QualitySnapshot.RuleEntry(title: "«x» đúng kiểu int", column: "x", severity: "error",
                                      passed: true, violations: 0, failure: nil),
            QualitySnapshot.RuleEntry(title: "«b» không trùng", column: "b", severity: "error",
                                      passed: false, violations: 3, failure: nil),
        ]
        let comparison = QualityDrift.compare(
            current: snapshot(total: 80, at: "2026-08-21", rules: moi),
            previous: snapshot(total: 90, rules: cu))
        XCTAssertEqual(comparison.newlyFailing, ["«b» không trùng"])
        XCTAssertTrue(comparison.newlyPassing.isEmpty)
        // `warn_on_new_failure` bật sẵn — nó là một SỰ KIỆN, không cần ngưỡng nào để chọn sai.
        XCTAssertEqual(comparison.alerts.count, 1)
        XCTAssertTrue(comparison.alerts[0].contains("nay TRƯỢT"), comparison.alerts[0])
    }

    func testLUATNAYDATCungHienRa() {
        let cu = [QualitySnapshot.RuleEntry(
            title: "«a» không rỗng", column: "a", severity: "error",
            passed: false, violations: 5, failure: nil)]
        let moi = [QualitySnapshot.RuleEntry(
            title: "«a» không rỗng", column: "a", severity: "error",
            passed: true, violations: 0, failure: nil)]
        let comparison = QualityDrift.compare(
            current: snapshot(total: 95, at: "2026-08-21", rules: moi),
            previous: snapshot(total: 80, rules: cu))
        XCTAssertEqual(comparison.newlyPassing, ["«a» không rỗng"])
        XCTAssertTrue(comparison.alerts.isEmpty, "tin tốt không phải cảnh báo")
    }

    func testMOINGUONGDEUTATTheoMacDinh_TruWARNONNEWFAILURE() {
        let thresholds = QualityRules.Drift()
        XCTAssertTrue(thresholds.warnOnNewFailure)
        let comparison = QualityDrift.compare(
            current: snapshot(total: 10, rows: 1, at: "2026-08-21"),
            previous: snapshot(total: 99, rows: 1000), thresholds: thresholds)
        XCTAssertTrue(comparison.alerts.isEmpty,
                      "ngưỡng chưa khai thì không được tự kêu: \(comparison.alerts)")
    }

    // MARK: - Bảng so sánh HTML

    func testBANGSOSANHNoiRoCUNGDULIEUHayKHACDULIEU() {
        let cungHash = QualityDrift.compare(
            current: snapshot(total: 80, at: "2026-08-21", hash: "abc"),
            previous: snapshot(total: 90, hash: "abc"))
        XCTAssertTrue(QualityDrift.html(cungHash).contains("do BỘ LUẬT đổi"),
                      QualityDrift.html(cungHash))

        let khacHash = QualityDrift.compare(
            current: snapshot(total: 80, at: "2026-08-21", hash: "xyz"),
            previous: snapshot(total: 90, hash: "abc"))
        XCTAssertTrue(QualityDrift.html(khacHash).contains("KHÁC nhau"))
    }

    func testBANGSOSANHKhongDoiCHIEUKHONGCHAMDUOCThanhSO() {
        let comparison = QualityDrift.compare(
            current: snapshot(total: 90, at: "2026-08-21", dimensions: [
                .init(name: "uniqueness", value: nil, weight: 1, note: "chưa khai khoá"),
            ]),
            previous: snapshot(total: 90, dimensions: [
                .init(name: "uniqueness", value: 100, weight: 1, note: nil),
            ]))
        let html = QualityDrift.html(comparison)
        XCTAssertTrue(html.contains("<td class=\"num\">—</td>"), html)
        XCTAssertFalse(html.contains("−100.0"), "không được biến `nil` thành 0 rồi trừ")
    }

    func testDUONGXUHUONGBoQuaBanKhongCoDIEM() throws {
        let path = folder + "/.gquality.history.jsonl"
        try QualityHistory.append(snapshot(total: 90, at: "2026-08-20"), to: path)
        try QualityHistory.append(snapshot(total: nil, at: "2026-08-21"), to: path)
        try QualityHistory.append(snapshot(total: 70, at: "2026-08-22"), to: path)
        let trend = QualityDrift.trend(QualityHistory.read(path: path))
        XCTAssertEqual(trend.map(\.total), [90, 70])
    }
}

/// FR-DQR-004 — vòng đầy đủ: chấm → ghi lịch sử → so.
final class QualityHistoryRecordTests: XCTestCase {

    private var folder = ""

    private let bang = """
        ma_don,doanh_thu
        KH01,100
        KH02,200

        """

    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-rec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try bang.write(toFile: folder + "/ban-hang.csv", atomically: true, encoding: .utf8)
        try """
            drift:
              max_total_drop: 1
            rules:
              - col: doanh_thu
                not_null: true
            """.write(toFile: folder + "/.gquality.yaml", atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func chay(record: Bool) throws -> ReportRenderer.Rendered {
        let source = folder + "/ban-hang.csv"
        let bytes = FileManager.default.contents(atPath: source) ?? Data()
        return try ReportRenderer.render(
            try ReportDocument.parse("```quality\nrules_file: .gquality.yaml\n```"),
            in: TextBuffer(original: MemoryByteSource([UInt8](bytes))), dialect: .comma,
            options: ReportRenderer.Options(
                sourcePath: source, basePath: folder, recordQualityHistory: record))
    }

    /// Preview KHÔNG được ghi lịch sử: dựng lại mỗi lần ngừng gõ mà lần nào cũng nối một dòng
    /// thì sau một buổi chiều tệp lịch sử có vài trăm bản ghi của cùng một dữ liệu.
    func testPREVIEWKhongGhiLichSu() throws {
        _ = try chay(record: false)
        _ = try chay(record: false)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: folder + "/.gquality.history.jsonl"))
    }

    func testGHIROISOVoiLANTRUOC() throws {
        _ = try chay(record: true)
        let path = folder + "/.gquality.history.jsonl"
        XCTAssertEqual(QualityHistory.read(path: path).snapshots.count, 1)
        XCTAssertEqual(QualityHistory.read(path: path).last?.sourcePath,
                       folder + "/ban-hang.csv")

        // Đợt dữ liệu thứ hai: thêm một hàng có ô rỗng → điểm tụt.
        try (bang + "KH03,\n").write(
            toFile: folder + "/ban-hang.csv", atomically: true, encoding: .utf8)
        let second = try chay(record: true)
        XCTAssertEqual(QualityHistory.read(path: path).snapshots.count, 2)
        XCTAssertFalse(second.qualityAlerts.isEmpty, "điểm tụt quá ngưỡng phải kêu")
        XCTAssertTrue(second.html.contains("So với lần chạy trước"), "phải có bảng so sánh")
    }

    /// %null từng cột phải có trong snapshot — FR-DQR-004 đòi đúng chữ ấy.
    func testSNAPSHOTCoNULLTungCot() throws {
        _ = try chay(record: true)
        let last = try XCTUnwrap(
            QualityHistory.read(path: folder + "/.gquality.history.jsonl").last)
        XCTAssertEqual(last.columns.map(\.column), ["ma_don", "doanh_thu"])
        XCTAssertEqual(last.columns.map(\.nullPercent), [0, 0])
        XCTAssertFalse(last.sourceHash.isEmpty, "bản GHI phải có hash nguồn")
        XCTAssertEqual(last.rowCount, 2)
    }
}
