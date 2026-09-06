import XCTest
@testable import GEditorCore

/// FR-DQR-003 — khối ```quality trong báo cáo.
final class QualityBlockSpecTests: XCTestCase {

    func testDUMOIKHOA() throws {
        let spec = try QualityBlockSpec.parse("""
            rules_file: .gquality.yaml
            source: ban-hang.csv
            title: Chất lượng tháng 8
            show_rules: false
            chart: dimensions
            now: 2026-08-26
            fail_under: 90
            """)
        XCTAssertEqual(spec.rulesFile, ".gquality.yaml")
        XCTAssertEqual(spec.source, "ban-hang.csv")
        XCTAssertEqual(spec.title, "Chất lượng tháng 8")
        XCTAssertFalse(spec.showRules)
        XCTAssertEqual(spec.chart, .dimensions)
        XCTAssertEqual(spec.failUnder, 90)
        XCTAssertEqual(spec.now, QualityCard.parseDay("2026-08-26"))
    }

    func testKHOALAThiBAOLOI() {
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("rules_file: a.yaml\nrule_file: b.yaml")
        ) { error in
            let message = (error as? QualityBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("«rule_file»"), message)
            XCTAssertTrue(message.contains("rules_file"), "phải liệt kê khoá đúng: \(message)")
        }
    }

    func testTHIEURULESFILEThiNoiNoNamODau() {
        XCTAssertThrowsError(try QualityBlockSpec.parse("title: X")) { error in
            let message = (error as? QualityBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("rules_file"), message)
            XCTAssertTrue(message.contains("tương đối"), "phải nói giải theo đâu: \(message)")
        }
    }

    /// `rules:` mang HAI nghĩa, và phân biệt chúng bằng KIỂU chứ không bằng tên.
    ///
    /// `rules: chuan.yaml` là đường dẫn; `rules: false` là tắt bảng luật. Nhầm hai thứ này
    /// nghĩa là một báo cáo khai `rules: false` sẽ đi tìm tệp luật tên "false".
    func testRULESLaDUONGDANKhiLaChuoi_LaCONGTACKhiLaBoolean() throws {
        let asPath = try QualityBlockSpec.parse("rules: chuan.yaml")
        XCTAssertEqual(asPath.rulesFile, "chuan.yaml")
        XCTAssertTrue(asPath.showRules, "mặc định vẫn hiện bảng luật")

        let asSwitch = try QualityBlockSpec.parse("rules_file: a.yaml\nrules: false")
        XCTAssertEqual(asSwitch.rulesFile, "a.yaml")
        XCTAssertFalse(asSwitch.showRules)
    }

    func testCHARTLaThiLietKeCaiCo() {
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("rules_file: a.yaml\nchart: pie")
        ) { error in
            let message = (error as? QualityBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("violations"), message)
            XCTAssertTrue(message.contains("dimensions"), message)
        }
    }

    func testNOWSaiDangThiNoiDangDung() {
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("rules_file: a.yaml\nnow: hôm qua")
        ) { error in
            XCTAssertTrue(
                ((error as? QualityBlockSpec.Failure)?.message ?? "").contains("YYYY-MM-DD"))
        }
    }

    func testFAILUNDERNgoaiKhoangThiTuChoi() {
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("rules_file: a.yaml\nfail_under: 140"))
    }
}

/// FR-DQR-003 — chạy khối và vẽ thẻ điểm.
final class QualityCardTests: XCTestCase {

    private var folder = ""

    /// Bảng thử: 5 hàng, `doanh_thu` có một ô rỗng, `tinh` có một ô ngoài danh sách.
    private let bang = """
        ma_don,doanh_thu,tinh
        KH01,100,Hà Nội
        KH02,,Huế
        KH03,300,Đà Nẵng
        KH04,400,Sài Gòn
        KH05,500,Cần Thơ

        """

    private let luat = """
        uniqueness_key: [ma_don]
        rules:
          - col: ma_don
            unique: true
          - col: doanh_thu
            not_null: true
          - col: tinh
            in_set: [Hà Nội, Huế, Đà Nẵng, Sài Gòn]
        """

    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        // `appendingPathComponent` chứ không nối chuỗi: `NSTemporaryDirectory()` có sẵn dấu `/`
        // ở cuối, và một đường dẫn hai gạch chéo vẫn MỞ ĐƯỢC nhưng không SO khớp được với
        // đường dẫn mà mã sản phẩm dựng ra.
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-card-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try bang.write(toFile: folder + "/ban-hang.csv", atomically: true, encoding: .utf8)
        try luat.write(toFile: folder + "/.gquality.yaml", atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func render(
        _ text: String, cache: QualityCache? = nil, record: Bool = false
    ) throws -> ReportRenderer.Rendered {
        let source = folder + "/ban-hang.csv"
        let bytes = FileManager.default.contents(atPath: source) ?? Data()
        return try ReportRenderer.render(
            try ReportDocument.parse(text),
            in: TextBuffer(original: MemoryByteSource([UInt8](bytes))), dialect: .comma,
            options: ReportRenderer.Options(
                sourcePath: source, basePath: folder, qualityCache: cache,
                recordQualityHistory: record))
    }

    private let block = """
        ```quality
        rules_file: .gquality.yaml
        title: Chất lượng bán hàng
        now: 2026-08-26
        ```
        """

    func testTHEDIEMCoDIEMTONG_SAUTHANH_VaBANGLUAT() throws {
        let rendered = try render(block)
        XCTAssertTrue(rendered.failures.isEmpty, "\(rendered.failures)")
        XCTAssertEqual(rendered.succeeded, 1)
        XCTAssertEqual(rendered.qualityScores.count, 1)

        let html = rendered.html
        XCTAssertTrue(html.contains("g-score-value"), html)
        XCTAssertTrue(html.contains("Chất lượng bán hàng"), "tiêu đề khối phải lên trang")
        // Sáu chiều, đủ sáu thanh — kể cả chiều không chấm được.
        for dimension in QualityRules.Dimension.allCases {
            XCTAssertTrue(html.contains(dimension.vietnamese), "thiếu chiều \(dimension)")
        }
        // Đếm THẺ, không đếm chuỗi: `.g-dim-bar` cũng có trong phần CSS của trang, và đếm cả
        // nó thì con số này đúng vì lý do sai.
        XCTAssertEqual(
            html.components(separatedBy: "<span class=\"g-dim-bar\">").count - 1, 6)
        // Bảng luật pass/fail.
        XCTAssertTrue(html.contains("không trùng"), html)
        XCTAssertTrue(html.contains("g-rules"), html)
    }

    /// NFR-DQR-03 đòi công thức *"in trong kết quả"*. Panel trong app để nó ở tooltip vì ở đó có
    /// chuột; một báo cáo thì được IN ra, và trên giấy không hover được.
    func testCONGTHUCLaCHUTHATTrenTrang_KhongPhaiTooltip() throws {
        let html = try render(block).html
        XCTAssertTrue(html.contains("Công thức chấm điểm"), html)
        XCTAssertTrue(html.contains("100 × (1 − số ô rỗng / tổng số ô)"), html)
        // Và khi in, khối `<details>` phải mở ra — nếu không công thức không lên giấy.
        XCTAssertTrue(html.contains(".g-formulas > *:not(summary)"), "thiếu luật @media print")
    }

    /// Chiều KHÔNG chấm được phải nói ra LÝ DO thành chữ, không phải một ô trống.
    ///
    /// Cùng bài học của panel: ô trống thì người đọc hiểu là "không có vấn đề gì", và cả sự cẩn
    /// thận của `QualityScorer` mất sạch ở bước vẽ.
    func testCHIEUKHONGCHAMDUOCHienLYDO_KhongPhaiOTrong() throws {
        let html = try render(block).html
        XCTAssertTrue(html.contains("g-dim-unscored"), html)
        XCTAssertTrue(html.contains("KHÔNG chấm được"), html)
        XCTAssertTrue(html.contains("không được tính là 100"), html)
        // Bộ luật thử không khai `accuracy_columns` lẫn `freshness`.
        XCTAssertTrue(html.contains("accuracy_columns"), html)
    }

    /// Luật TRƯỢT lên đầu bảng — một bảng năm mươi dòng mà ba dòng đáng đọc nằm rải rác thì
    /// người đọc phải dò từng dòng.
    func testLUATTRUOTLenDauBang() throws {
        let html = try render(block).html
        guard let table = html.range(of: "g-rules") else { return XCTFail("không có bảng luật") }
        let body = String(html[table.lowerBound...])
        let failed = body.range(of: "«tinh» thuộc danh sách")
        let passed = body.range(of: "«ma_don» không trùng")
        XCTAssertNotNil(failed)
        XCTAssertNotNil(passed)
        if let failed, let passed {
            XCTAssertTrue(failed.lowerBound < passed.lowerBound,
                          "luật trượt phải đứng trên luật đạt")
        }
    }

    func testDIEMDUOINGUONGThiCANHBAO_NhungKHONGPhaiHopLOI() throws {
        let rendered = try render("""
            ```quality
            rules_file: .gquality.yaml
            now: 2026-08-26
            fail_under: 99
            ```
            """)
        XCTAssertTrue(rendered.failures.isEmpty, "khối vẫn CHẠY được: \(rendered.failures)")
        XCTAssertEqual(rendered.qualityAlerts.count, 1)
        XCTAssertTrue(rendered.qualityAlerts[0].message.contains("DƯỚI ngưỡng"))
        XCTAssertTrue(rendered.html.contains("<div class=\"g-alert\">"), "phải là hộp cảnh báo")
        XCTAssertFalse(rendered.html.contains("<div class=\"g-error\">"), "không phải hộp lỗi")
    }

    func testTEPLUATKHONGCOThiNoiDUONGDAN() throws {
        let rendered = try render("""
            ```quality
            rules_file: khong-co.yaml
            ```
            """)
        XCTAssertEqual(rendered.failures.count, 1)
        let message = rendered.failures[0].message
        XCTAssertTrue(message.contains("khong-co.yaml"), message)
        XCTAssertTrue(message.contains(folder), "phải nói đã tìm ở ĐÂU: \(message)")
    }

    func testTEPLUATHONGThiNoiLoiCuaTEPLUAT_KhongPhaiLoiDuLieu() throws {
        try "rules:\n  - col: a\n    khong_hieu: 1"
            .write(toFile: folder + "/hong.yaml", atomically: true, encoding: .utf8)
        let rendered = try render("```quality\nrules_file: hong.yaml\n```")
        let message = rendered.failures.first?.message ?? ""
        XCTAssertTrue(message.contains("hong.yaml"), message)
        XCTAssertTrue(message.contains("không nhận ra loại luật"), message)
    }

    /// Nguồn RIÊNG của khối: một báo cáo so hai tệp dữ liệu bằng hai khối quality.
    func testKHOICOTHEKhaiNGUONRieng() throws {
        try "ma_don,doanh_thu,tinh\nKH09,900,Huế\n"
            .write(toFile: folder + "/thang-9.csv", atomically: true, encoding: .utf8)
        let rendered = try render("""
            ```quality
            rules_file: .gquality.yaml
            source: thang-9.csv
            now: 2026-08-26
            ```
            """)
        XCTAssertTrue(rendered.failures.isEmpty, "\(rendered.failures)")
        XCTAssertEqual(rendered.qualityScores.first?.rowCount, 1, "phải chấm trên tệp tháng 9")
    }

    // MARK: - Cache (FR-DQR-003)

    /// Lượt thứ hai lấy lại kết quả cũ — thấy được qua `evaluatedAt` giữ nguyên.
    ///
    /// Không đo bằng thời gian chạy: một phép kiểm dựa vào "lần hai nhanh hơn" là phép kiểm sẽ
    /// chập chờn trên máy đang bận.
    func testCACHETRUNGThiKhongChamLai() throws {
        let cache = QualityCache()
        let khoi = """
            ```quality
            rules_file: .gquality.yaml
            ```
            """
        let first = try render(khoi, cache: cache)
        let second = try render(khoi, cache: cache)
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(
            first.qualityScores.first?.evaluatedAt,
            second.qualityScores.first?.evaluatedAt,
            "lượt hai phải dùng lại kết quả đã nhớ")
    }

    func testSUATEPLUATThiCACHEKhongTrungNua() throws {
        let cache = QualityCache()
        let khoi = "```quality\nrules_file: .gquality.yaml\n```"
        _ = try render(khoi, cache: cache)
        try (luat + "\n  - col: tinh\n    not_null: true\n")
            .write(toFile: folder + "/.gquality.yaml", atomically: true, encoding: .utf8)
        let second = try render(khoi, cache: cache)
        XCTAssertEqual(cache.count, 2, "hash bộ luật đổi thì phải chấm lại")
        XCTAssertEqual(second.qualityScores.first?.dimensions.count, 6)
    }

    func testSUANGUONThiCACHEKhongTrungNua() throws {
        let cache = QualityCache()
        let khoi = "```quality\nrules_file: .gquality.yaml\n```"
        let first = try render(khoi, cache: cache)
        // Đổi CẢ cỡ lẫn thời điểm sửa — `Fingerprint` so cả hai.
        try (bang + "KH06,600,Huế\n")
            .write(toFile: folder + "/ban-hang.csv", atomically: true, encoding: .utf8)
        let second = try render(khoi, cache: cache)
        XCTAssertEqual(first.qualityScores.first?.rowCount, 5)
        XCTAssertEqual(second.qualityScores.first?.rowCount, 6)
    }

    /// Tài liệu CHƯA LƯU không có dấu vân nào để so, nên KHÔNG nhớ.
    ///
    /// Thà chạy lại còn hơn hiện điểm số của phiên bản dữ liệu trước.
    func testNGUONCHUALUUThiKHONGNho() throws {
        let cache = QualityCache()
        XCTAssertNil(QualityCache.Key(rulesText: luat, sourcePath: nil, now: nil))
        _ = try ReportRenderer.render(
            try ReportDocument.parse("```quality\nrules_file: .gquality.yaml\n```"),
            in: TextBuffer(text: bang), dialect: .comma,
            options: ReportRenderer.Options(basePath: folder, qualityCache: cache))
        XCTAssertEqual(cache.count, 0)
    }

    /// Khoá cache chốt theo NGÀY khi khối không khai `now:` — đúng độ phân giải của
    /// `max_age_days`, chứ không phải một con số chọn bừa.
    func testKHOACACHEChotTheoNGAYKhiKhongKhaiNow() throws {
        let sang = QualityCache.Key(
            rulesText: luat, sourcePath: folder + "/ban-hang.csv", now: nil,
            today: Date(timeIntervalSince1970: 1_787_000_000))
        let toi = QualityCache.Key(
            rulesText: luat, sourcePath: folder + "/ban-hang.csv", now: nil,
            today: Date(timeIntervalSince1970: 1_787_000_000 + 3_600))
        let homSau = QualityCache.Key(
            rulesText: luat, sourcePath: folder + "/ban-hang.csv", now: nil,
            today: Date(timeIntervalSince1970: 1_787_000_000 + 86_400))
        XCTAssertEqual(sang, toi, "cùng ngày thì cùng khoá")
        XCTAssertNotEqual(sang, homSau, "sang ngày mới thì phải chấm lại")
    }

    func testTRANSOMUCNho() {
        let cache = QualityCache(capacity: 2)
        for index in 0..<5 {
            guard var key = QualityCache.Key(
                rulesText: luat, sourcePath: folder + "/ban-hang.csv", now: Date())
            else { return XCTFail("không dựng được khoá") }
            key.now = Double(index)
            cache.store(QualityCache.Entry(
                report: QualityEngine.Report(results: [], rowCount: index, milliseconds: 0),
                score: QualityScore(dimensions: [], rowCount: index, evaluatedAt: Date())),
                for: key)
        }
        XCTAssertEqual(cache.count, 2, "cache không được phình vô hạn")
    }
}
