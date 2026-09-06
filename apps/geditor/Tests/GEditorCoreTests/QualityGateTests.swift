import XCTest
@testable import GEditorCore

/// FR-DQR-005 — cổng chất lượng cho pipeline/CI.
final class QualityGateTests: XCTestCase {

    private var folder = ""

    private let sach = """
        ma_don,doanh_thu
        KH01,100
        KH02,200
        KH03,300

        """

    private let ban = """
        ma_don,doanh_thu
        KH01,100
        KH01,
        KH03,300

        """

    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-gate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try sach.write(toFile: folder + "/sach.csv", atomically: true, encoding: .utf8)
        try ban.write(toFile: folder + "/ban.csv", atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func chay(
        _ yaml: String, files: [String], options: QualityGate.Options = .init(),
        prepare: ((TextBuffer, String) throws -> Bool)? = nil
    ) throws -> QualityGate.Outcome {
        let rulesPath = folder + "/chuan.yaml"
        try yaml.write(toFile: rulesPath, atomically: true, encoding: .utf8)
        return QualityGate.run(
            rules: try QualityRules.load(fromYAML: yaml), rulesPath: rulesPath,
            files: files.map { folder + "/" + $0 },
            options: options, prepare: prepare)
    }

    private let luat = """
        uniqueness_key: [ma_don]
        rules:
          - col: ma_don
            unique: true
          - col: doanh_thu
            not_null: true
        """

    // MARK: - Ba mã thoát

    func testDATThiMA0() throws {
        let outcome = try chay(luat, files: ["sach.csv"], options: .init(now: mocThoiGian))
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertEqual(outcome.files.first?.status, .pass)
        XCTAssertTrue(outcome.files.first?.reasons.isEmpty ?? false)
    }

    func testLUATMUCERRORTruotThiMA1() throws {
        let outcome = try chay(luat, files: ["ban.csv"], options: .init(now: mocThoiGian))
        XCTAssertEqual(outcome.exitCode, 1)
        XCTAssertTrue(outcome.files[0].reasons.joined().contains("mức `error` TRƯỢT"))
    }

    /// `severity: warn` KHÔNG làm trượt cổng — đặc tả nói rõ *"có rule error fail"*.
    ///
    /// Nếu `warn` cũng chặn thì hai mức nghiêm trọng chỉ là hai cái tên cho cùng một hành vi, và
    /// người dùng mất đường khai "chuyện này đáng biết nhưng chưa đáng chặn".
    func testLUATMUCWARNTruotThiVANDAT() throws {
        let outcome = try chay("""
            rules:
              - col: doanh_thu
                not_null: true
                severity: warn
            """, files: ["ban.csv"], options: .init(now: mocThoiGian))
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertEqual(outcome.files[0].report?.failedWarnings.count, 1)
    }

    /// Điểm dưới ngưỡng là ĐỦ để trượt, ngay cả khi không luật `error` nào trượt.
    ///
    /// Đây là hai vế RIÊNG của đặc tả (*"điểm dưới ngưỡng HOẶC có rule error fail"*), nên bài
    /// kiểm dựng đúng ca chỉ có vế đầu: bộ luật chỉ có một luật mức `warn`.
    func testDIEMDUOINGUONGThiMA1() throws {
        let outcome = try chay("""
            uniqueness_key: [ma_don]
            rules:
              - col: doanh_thu
                not_null: true
                severity: warn
            """, files: ["ban.csv"], options: .init(failUnder: 90, now: mocThoiGian))
        XCTAssertEqual(outcome.exitCode, 1)
        XCTAssertEqual(outcome.files[0].reasons.count, 1, "\(outcome.files[0].reasons)")
        XCTAssertTrue(outcome.files[0].reasons[0].contains("dưới ngưỡng"),
                      outcome.files[0].reasons[0])
    }

    /// Và ngược lại: điểm TRÊN ngưỡng thì đạt — bảng sạch được 100.
    func testDIEMTRENNGUONGThiMA0() throws {
        let outcome = try chay(
            luat, files: ["sach.csv"], options: .init(failUnder: 99, now: mocThoiGian))
        XCTAssertEqual(outcome.files[0].score?.total, 100)
        XCTAssertEqual(outcome.exitCode, 0)
    }

    func testKHONGDOCDUOCFILEThiMA2() throws {
        let outcome = try chay(luat, files: ["khong-co.csv"], options: .init(now: mocThoiGian))
        XCTAssertEqual(outcome.exitCode, 2)
        XCTAssertEqual(outcome.files[0].status, .error)
    }

    /// Luật gõ sai tên cột là TRƯỢT (mã 1), không phải lỗi chạy (mã 2).
    ///
    /// Lệnh đã chạy xong và đã đọc được dữ liệu; câu trả lời là "bộ luật này không áp được lên
    /// bảng này" — một câu trả lời về CHẤT LƯỢNG.
    func testLUATKHONGCHAYDUOCLaMA1_KhongPhaiMA2() throws {
        let outcome = try chay("""
            rules:
              - col: cot_khong_ton_tai
                not_null: true
            """, files: ["sach.csv"], options: .init(now: mocThoiGian))
        XCTAssertEqual(outcome.exitCode, 1)
        XCTAssertTrue(outcome.files[0].reasons.joined().contains("KHÔNG chạy được"),
                      "\(outcome.files[0].reasons)")
    }

    /// Không chấm được điểm mà lại có ngưỡng thì TRƯỢT.
    ///
    /// Coi "không biết" là "đạt" ở một cổng chặn là cách cổng ấy mở toang trong im lặng.
    func testKHONGCODIEMMaCoNGUONGThiTRUOT() throws {
        let outcome = try chay("""
            rules: []
            """, files: ["sach.csv"], options: .init(failUnder: 50, now: mocThoiGian))
        // Bộ luật rỗng vẫn chấm được COMPLETENESS, nên dựng ca thật: bảng RỖNG.
        XCTAssertNotNil(outcome.files.first)

        try "ma_don,doanh_thu\n".write(
            toFile: folder + "/rong.csv", atomically: true, encoding: .utf8)
        let empty = try chay("rules: []", files: ["rong.csv"],
                             options: .init(failUnder: 50, now: mocThoiGian))
        XCTAssertNil(empty.files[0].score?.total)
        XCTAssertEqual(empty.exitCode, 1)
        XCTAssertTrue(empty.files[0].reasons.joined().contains("không có điểm tổng"),
                      "\(empty.files[0].reasons)")
    }

    // MARK: - Batch

    /// Mã thoát GỘP lấy mã NẶNG NHẤT, không lấy mã của file cuối.
    func testBATCHLayMaNANGNHAT() throws {
        let outcome = try chay(
            luat, files: ["ban.csv", "khong-co.csv", "sach.csv"],
            options: .init(now: mocThoiGian))
        XCTAssertEqual(outcome.files.count, 3)
        XCTAssertEqual(outcome.exitCode, 2, "một file lỗi chạy phải thắng cả file đạt")
        XCTAssertEqual(outcome.passedCount, 1)
        XCTAssertEqual(outcome.failedCount, 1)
        XCTAssertEqual(outcome.errorCount, 1)

        let khongLoi = try chay(luat, files: ["ban.csv", "sach.csv"],
                                options: .init(now: mocThoiGian))
        XCTAssertEqual(khongLoi.exitCode, 1)
    }

    // MARK: - JSON

    func testJSONHopLeVaDuKHOADacTaDoi() throws {
        let outcome = try chay(
            luat, files: ["ban.csv"],
            options: .init(failUnder: 90, violationSamples: 5, now: mocThoiGian))
        let json = QualityGate.json(
            outcome, options: .init(failUnder: 90, violationSamples: 5))
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(object["exit_code"] as? Int, 1)
        XCTAssertEqual(object["fail_under"] as? Double, 90)

        let files = try XCTUnwrap(object["files"] as? [[String: Any]])
        let file = try XCTUnwrap(files.first)
        // Bốn khoá đặc tả gọi tên: score, dimensions{}, rules[], violations_sample[].
        XCTAssertNotNil(file["score"])
        XCTAssertNotNil(file["dimensions"] as? [String: Any])
        XCTAssertNotNil(file["rules"] as? [[String: Any]])
        let samples = try XCTUnwrap(file["violations_sample"] as? [[String: Any]])
        XCTAssertFalse(samples.isEmpty)
        XCTAssertNotNil(samples[0]["rows"] as? [Int])
    }

    /// Chiều KHÔNG chấm được đi vào JSON là `null`, không phải 0.
    ///
    /// Một pipeline đọc `dimensions.uniqueness.value == 0` rồi báo động là phản ứng đúng với một
    /// con số sai; `null` thì buộc nó phải xử lý "không biết" cho ra "không biết".
    func testJSONGiuNULLChoChieuKhongChamDuoc() throws {
        let outcome = try chay("""
            rules:
              - col: doanh_thu
                not_null: true
            """, files: ["sach.csv"], options: .init(now: mocThoiGian))
        let json = QualityGate.json(outcome)
        XCTAssertTrue(json.contains("\"value\": null"), json)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        let files = try XCTUnwrap(object?["files"] as? [[String: Any]])
        let dimensions = try XCTUnwrap(files[0]["dimensions"] as? [String: Any])
        let uniqueness = try XCTUnwrap(dimensions["uniqueness"] as? [String: Any])
        XCTAssertTrue(uniqueness["value"] is NSNull)
        XCTAssertNotNil(uniqueness["note"], "phải nói vì sao không chấm được")
    }

    /// Hàng ví dụ tốn một lượt quét cho mỗi luật trượt — không hỏi thì không lấy.
    func testKHONGXINVIDUThiKhongQuetThem() throws {
        let outcome = try chay(luat, files: ["ban.csv"], options: .init(now: mocThoiGian))
        XCTAssertTrue(outcome.files[0].samples.isEmpty)
        XCTAssertTrue(QualityGate.json(outcome).contains("\"violations_sample\": []"))
    }

    func testJSONTHOATKyTuDacBiet() {
        XCTAssertEqual(QualityGate.quote("a\"b\\c\nd"), "\"a\\\"b\\\\c\\nd\"")
        // Chữ tiếng Việt đi NGUYÊN VẸN — JSON là UTF-8.
        XCTAssertEqual(QualityGate.quote("doanh_thu ₫"), "\"doanh_thu ₫\"")
        XCTAssertEqual(QualityGate.quote("a\u{01}b"), "\"a\\u0001b\"")
    }

    // MARK: - Kết hợp --recipe

    /// *"Kết hợp --recipe: làm sạch xong tự chấm lại"* — và nói ra điểm TRƯỚC khi làm sạch.
    func testRECIPELamSachXongChamLai_VaGiuCaDiemTRUOC() throws {
        let recipe = CSVRecipe(name: "Điền 0", steps: [
            CSVRecipeStep(columnName: "doanh_thu", columnIndex: 1,
                          kind: .fillWithValue("0")),
        ])
        let outcome = try chay(luat, files: ["ban.csv"], options: .init(now: mocThoiGian)) {
            buffer, path in
            let run = try CSVRecipeRunner.run(
                recipe, on: buffer, dialect: .comma,
                fileName: (path as NSString).lastPathComponent)
            return run.appliedCount > 0
        }
        let file = outcome.files[0]
        let before = try XCTUnwrap(file.scoreBefore?.total)
        let after = try XCTUnwrap(file.score?.total)
        XCTAssertGreaterThan(after, before, "làm sạch xong điểm phải khá hơn")
        // Ô rỗng đã được điền → luật `not_null` nay ĐẠT.
        let notNull = try XCTUnwrap(
            file.report?.results.first { $0.rule.column == "doanh_thu" })
        XCTAssertTrue(notNull.passed)
        XCTAssertEqual(notNull.violations, 0)
    }

    /// Buffer đã sửa thì KHÔNG được chấm lại từ FILE trên đĩa.
    ///
    /// `CSVQueryEngine` đọc thẳng từ file khi có đường dẫn, nên nếu đường dẫn vẫn được truyền
    /// vào sau khi làm sạch thì cổng chấm bản CHƯA làm sạch mà vẫn ra một con số trông rất hợp
    /// lý — sai theo hướng khó phát hiện nhất.
    func testSAUKHILAMSACHKhongDocLaiFILEGoc() throws {
        let recipe = CSVRecipe(name: "Điền 0", steps: [
            CSVRecipeStep(columnName: "doanh_thu", columnIndex: 1,
                          kind: .fillWithValue("0")),
        ])
        let outcome = try chay("""
            rules:
              - col: doanh_thu
                not_null: true
            """, files: ["ban.csv"], options: .init(now: mocThoiGian)) { buffer, path in
            _ = try CSVRecipeRunner.run(
                recipe, on: buffer, dialect: .comma,
                fileName: (path as NSString).lastPathComponent)
            return true
        }
        XCTAssertEqual(outcome.exitCode, 0, "\(outcome.files[0].reasons)")
        // Và file trên đĩa KHÔNG bị đụng tới: cổng là để đọc.
        let onDisk = try String(contentsOfFile: folder + "/ban.csv", encoding: .utf8)
        XCTAssertEqual(onDisk, ban)
    }

    // MARK: - Lịch sử

    func testGHILICHSUKhiDuocXin() throws {
        let outcome = try chay(
            luat, files: ["sach.csv"], options: .init(now: mocThoiGian, recordHistory: true))
        let path = QualityHistory.historyPath(forRules: folder + "/chuan.yaml")
        XCTAssertEqual(QualityHistory.read(path: path).snapshots.count, 1)
        XCTAssertNotNil(outcome.files[0].drift)
        XCTAssertFalse(outcome.files[0].drift?.hasPrevious ?? true, "lần đầu chưa có gì để so")
    }

    func testKHONGXINThiKhongGhiLichSu() throws {
        _ = try chay(luat, files: ["sach.csv"], options: .init(now: mocThoiGian))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: QualityHistory.historyPath(forRules: folder + "/chuan.yaml")))
    }

    /// Trôi dạt vượt ngưỡng KHÔNG tự làm trượt cổng.
    ///
    /// Ngưỡng trôi dạt nói *"đợt này khác đợt trước"*; cổng nói *"đợt này có dùng được không"*.
    /// Trộn hai câu ấy thì một lần dữ liệu tốt lên rồi xấu đi trong ngưỡng cho phép cũng chặn
    /// merge.
    func testTROIDATKhongTuLamTRUOTCONG() throws {
        let yaml = """
            drift:
              max_row_change_pct: 10
            rules:
              - col: doanh_thu
                dtype: int
            """
        _ = try chay(yaml, files: ["sach.csv"],
                     options: .init(now: mocThoiGian, recordHistory: true))
        try (sach + "KH04,400\nKH05,500\n").write(
            toFile: folder + "/sach.csv", atomically: true, encoding: .utf8)
        let second = try chay(yaml, files: ["sach.csv"],
                              options: .init(now: mocThoiGian, recordHistory: true))
        XCTAssertEqual(second.exitCode, 0, "\(second.files[0].reasons)")
        XCTAssertTrue(second.files[0].reasons.joined().contains("Số hàng đổi"),
                      "vẫn phải NÓI RA: \(second.files[0].reasons)")
    }

    /// Mốc TIMELINESS đóng đinh được → hai lượt chạy cho cùng điểm, đúng NFR-DQR-03.
    func testDONGDINHMOCThiHaiLUOTCungDIEM() throws {
        let yaml = luat + """

            freshness:
              column: ma_don
              max_age_days: 30
            """
        let first = try chay(yaml, files: ["sach.csv"], options: .init(now: mocThoiGian))
        let second = try chay(yaml, files: ["sach.csv"], options: .init(now: mocThoiGian))
        XCTAssertEqual(first.files[0].score?.total, second.files[0].score?.total)
        XCTAssertEqual(first.files[0].score?.evaluatedAt, second.files[0].score?.evaluatedAt)
    }

    private let mocThoiGian = Date(timeIntervalSince1970: 1_787_000_000)
}
