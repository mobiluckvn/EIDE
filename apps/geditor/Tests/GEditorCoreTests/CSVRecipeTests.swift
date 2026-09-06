import XCTest
@testable import GEditorCore

/// Công thức làm sạch: ghi JSON, đọc lại, chạy trên file khác (FR-CLN-005).
final class CSVRecipeTests: XCTestCase {

    private func document(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func sampleRecipe() -> CSVRecipe {
        CSVRecipe(name: "Làm sạch báo cáo tháng", sourceFile: "thang7.csv", steps: [
            CSVRecipeStep(columnName: "ngay", columnIndex: 1, kind: .normalizeDates(order: .dayFirst)),
            CSVRecipeStep(columnName: "ten", columnIndex: 2, kind: .trim(collapseInner: true)),
            CSVRecipeStep(columnName: "tinh", columnIndex: 3, kind: .fillWithValue("Chưa rõ")),
        ])
    }

    // MARK: - JSON

    /// Ghi ra rồi đọc lại phải ra đúng công thức cũ, không sót tham số nào.
    func testRoundTripsThroughJSON() throws {
        let recipe = CSVRecipe(name: "Đủ mọi bước", steps: [
            CSVRecipeStep(columnName: "a", columnIndex: 0, kind: .normalizeDates(order: nil)),
            CSVRecipeStep(columnName: "b", columnIndex: 1, kind: .normalizeDates(order: .monthFirst)),
            CSVRecipeStep(columnName: "c", columnIndex: 2,
                          kind: .normalizeNumbers(to: .anglo, source: .vietnamese, grouped: false)),
            CSVRecipeStep(columnName: "d", columnIndex: 3, kind: .trim(collapseInner: true)),
            CSVRecipeStep(columnName: "e", columnIndex: 4, kind: .changeCase(.title)),
            CSVRecipeStep(columnName: "f", columnIndex: 5, kind: .fillWithValue("x")),
            CSVRecipeStep(columnName: "g", columnIndex: 6, kind: .fill(.backward)),
            CSVRecipeStep(columnName: "h", columnIndex: 7, kind: .deleteRowsWithNull, enabled: false),
        ])
        let reloaded = try CSVRecipe.load(from: try recipe.jsonData())
        XCTAssertEqual(reloaded, recipe)
    }

    /// JSON phải ĐỌC ĐƯỢC BẰNG MẮT: người ta mở file này ra sửa tay và gửi cho nhau.
    func testJSONIsReadable() throws {
        let json = String(decoding: try sampleRecipe().jsonData(), as: UTF8.self)
        XCTAssertTrue(json.contains("\"action\" : \"normalizeDates\""), json)
        XCTAssertTrue(json.contains("\"order\" : \"dayFirst\""), json)
        XCTAssertTrue(json.contains("\"columnName\" : \"ngay\""), json)
        XCTAssertTrue(json.contains("\"version\" : 1"), json)
    }

    /// File của bản MỚI hơn thì từ chối, và nói rõ vì sao.
    ///
    /// Đọc bừa một schema chưa biết rồi áp lên dữ liệu người dùng là cách hỏng dữ liệu tệ
    /// nhất: im lặng và trông có vẻ đúng.
    func testRefusesNewerSchema() throws {
        let json = """
        {"version": 99, "name": "tương lai", "steps": []}
        """
        XCTAssertThrowsError(try CSVRecipe.load(from: Data(json.utf8))) { error in
            guard case let CSVRecipe.LoadError.tooNew(fileVersion, supported) = error else {
                return XCTFail("lỗi sai loại: \(error)")
            }
            XCTAssertEqual(fileVersion, 99)
            XCTAssertEqual(supported, CSVRecipe.currentVersion)
        }
    }

    func testRejectsMalformedFile() {
        XCTAssertThrowsError(try CSVRecipe.load(from: Data("{ không phải json".utf8)))
        XCTAssertThrowsError(try CSVRecipe.load(
            from: Data(#"{"version":1,"name":"x","steps":[{"columnIndex":0,"enabled":true,"kind":{"action":"bịa"}}]}"#.utf8)
        ))
    }

    // MARK: - Chạy trên file

    func testRunsEveryStepInOrder() throws {
        let buffer = document("""
        ma,ngay,ten,tinh
        A1,25/07/2026,"Cty  Anh Đào ",Huế
        A2,03/04/2026," Mai Lan Store",N/A

        """)
        let run = try CSVRecipeRunner.run(
            sampleRecipe(), on: buffer, dialect: .comma, fileName: "thang8.csv"
        )

        XCTAssertEqual(run.appliedCount, 3)
        XCTAssertFalse(run.hasProblems, run.report)
        XCTAssertEqual(buffer.text, """
        ma,ngay,ten,tinh
        A1,2026-07-25,Cty Anh Đào,Huế
        A2,2026-04-03,Mai Lan Store,Chưa rõ

        """)
    }

    /// Cả công thức là MỘT bước undo — chạy nhầm thì một lần ⌘Z là về nguyên trạng.
    func testWholeRecipeIsOneUndoStep() throws {
        let source = "ma,ngay,ten,tinh\nA1,25/07/2026,\"Cty  Anh Đào \",N/A\n"
        let buffer = document(source)
        let depth = buffer.undoDepth

        try CSVRecipeRunner.run(sampleRecipe(), on: buffer, dialect: .comma, fileName: "x.csv")
        XCTAssertEqual(buffer.undoDepth, depth + 1)
        XCTAssertNotEqual(buffer.text, source)

        _ = buffer.undo()
        XCTAssertEqual(buffer.text, source)
    }

    /// Cột tìm theo TÊN, nên thêm một cột ở giữa không làm công thức chạy nhầm chỗ.
    ///
    /// Đây là chỗ một công thức có thể phá dữ liệu mà không ai biết: theo chỉ số thì "cột thứ
    /// 1" của file mới là cột doanh thu, và chuẩn hóa ngày lên đó sẽ viết lại những con số
    /// thành ngày tháng.
    func testFindsColumnsByNameWhenLayoutChanges() throws {
        let buffer = document("""
        ma,doanh_so,ngay,ten,tinh
        A1,"1.234,56",25/07/2026,"Cty  Anh Đào ",Huế

        """)
        try CSVRecipeRunner.run(
            sampleRecipe(), on: buffer, dialect: .comma, fileName: "thang9.csv"
        )
        XCTAssertEqual(buffer.text, """
        ma,doanh_so,ngay,ten,tinh
        A1,"1.234,56",2026-07-25,Cty Anh Đào,Huế

        """)
    }

    /// File thiếu cột thì bước ấy KHÔNG chạy, và báo cáo nói rõ tại sao.
    func testMissingColumnIsReportedNotGuessed() throws {
        let source = "ma,ngay\nA1,25/07/2026\n"
        let buffer = document(source)
        let run = try CSVRecipeRunner.run(
            sampleRecipe(), on: buffer, dialect: .comma, fileName: "thieu-cot.csv"
        )

        XCTAssertEqual(run.appliedCount, 1, "chỉ bước «ngay» chạy được")
        XCTAssertTrue(run.hasProblems)
        let problems = run.results.compactMap(\.problem).joined(separator: " | ")
        XCTAssertTrue(problems.contains("không có cột «ten»"), problems)
        XCTAssertTrue(problems.contains("cột hiện có"), "phải nói ra file có những cột nào")
        XCTAssertEqual(buffer.text, "ma,ngay\nA1,2026-07-25\n")
    }

    /// Bước tắt vẫn nằm trong công thức nhưng không chạy.
    func testDisabledStepsAreSkipped() throws {
        var recipe = sampleRecipe()
        recipe.steps[0].enabled = false
        let buffer = document("ma,ngay,ten,tinh\nA1,25/07/2026,Huế,N/A\n")

        let run = try CSVRecipeRunner.run(
            recipe, on: buffer, dialect: .comma, fileName: "x.csv"
        )
        XCTAssertTrue(buffer.text.contains("25/07/2026"), "bước tắt mà vẫn chạy")
        XCTAssertEqual(recipe.enabledCount, 2)
        XCTAssertEqual(run.results.first?.problem, "bước đang tắt")
    }

    /// Bước chạy mà không đổi gì thì nói ra là không đổi gì — không nhận công.
    func testStepWithNothingToDoSaysSo() throws {
        let buffer = document("ma,ngay,ten,tinh\nA1,2026-07-25,Huế,Huế\n")
        let run = try CSVRecipeRunner.run(
            sampleRecipe(), on: buffer, dialect: .comma, fileName: "sach.csv"
        )
        XCTAssertEqual(run.appliedCount, 0)
        XCTAssertTrue(run.results.allSatisfy { $0.problem == "không có gì để đổi" }, run.report)
    }

    /// Báo cáo của MỖI file là một báo cáo riêng, kể cả khi chạy hàng loạt.
    func testReportNamesTheFileAndEveryStep() throws {
        let buffer = document("ma,ngay,ten,tinh\nA1,25/07/2026,\"Cty  Anh Đào \",N/A\n")
        let run = try CSVRecipeRunner.run(
            sampleRecipe(), on: buffer, dialect: .comma, fileName: "thang8.csv"
        )
        XCTAssertTrue(run.report.hasPrefix("## thang8.csv"))
        XCTAssertTrue(run.report.contains("Làm sạch báo cáo tháng"))
        XCTAssertEqual(run.report.filter { $0 == "✓" }.count, 3)
    }

    /// Bước sau chạy trên tài liệu ĐÃ CÓ bước trước — kể cả khi bước trước xóa hàng.
    func testStepsSeeThePreviousResult() throws {
        let recipe = CSVRecipe(name: "xóa rồi chuẩn hóa", steps: [
            CSVRecipeStep(columnName: "tinh", columnIndex: 2, kind: .deleteRowsWithNull),
            CSVRecipeStep(columnName: "ngay", columnIndex: 1, kind: .normalizeDates(order: .dayFirst)),
        ])
        let buffer = document("""
        ma,ngay,tinh
        A1,25/07/2026,Huế
        A2,26/07/2026,N/A
        A3,27/07/2026,Đà Nẵng

        """)
        try CSVRecipeRunner.run(recipe, on: buffer, dialect: .comma, fileName: "x.csv")

        XCTAssertEqual(buffer.text, """
        ma,ngay,tinh
        A1,2026-07-25,Huế
        A3,2026-07-27,Đà Nẵng

        """)
    }
}
