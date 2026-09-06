import XCTest
@testable import GEditorCore

/// Tệp prompt và thẩm định JSON Schema — FR-KNW-909.
final class PromptFileTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    // MARK: - Frontmatter

    private let prompt = """
    ---
    model: claude
    temperature: 0.2
    ---
    Xin chào {{ ten }}.
    """

    func testTimDuocKhoiFrontmatter() {
        let b = buffer(prompt)
        let r = PromptFile.frontmatterRange(in: b)
        let text = r.map { String(decoding: b.bytes(in: $0), as: UTF8.self) }
        XCTAssertEqual(text, "---\nmodel: claude\ntemperature: 0.2\n---\n")
    }

    func testDocDuocPhanYAMLbenTrong() {
        XCTAssertEqual(PromptFile.frontmatterYAML(in: buffer(prompt)),
                       "model: claude\ntemperature: 0.2")
    }

    /// Frontmatter PHẢI ở ngay đầu tệp: một khối `---` ở giữa tài liệu Markdown là đường kẻ
    /// ngang, và nhận nhầm nó sẽ gấp mất một đoạn chữ của người dùng.
    func testKhoiBaGachOGIUAtaiLieuKhongPhaiFrontmatter() {
        let b = buffer("Mở đầu\n\n---\n\nPhần sau\n")
        XCTAssertNil(PromptFile.frontmatterRange(in: b))
    }

    /// Mở mà không đóng thì KHÔNG đoán là "tới hết tệp" — gấp cả tệp lại là hỏng.
    func testMoMaKhongDongThiKhongPhaiFrontmatter() {
        XCTAssertNil(PromptFile.frontmatterRange(in: buffer("---\nmodel: x\nkhông có gạch đóng\n")))
    }

    func testVungGapGiuDongGachDauLamCHOBAM() {
        let b = buffer(prompt)
        let fold = PromptFile.foldRange(in: b)
        XCTAssertEqual(fold?.headerLine, 0, "dòng «---» đầu phải còn hiện để bấm mở lại")
        XCTAssertEqual(fold?.lastLine, 3)
        // Phần giấu bắt đầu từ đầu dòng KẾ, không nuốt ký tự xuống dòng của dòng đầu.
        XCTAssertEqual(fold?.hiddenBytes.lowerBound, b.offset(ofLineStart: 1))
    }

    func testTaiLieuKhongCoFrontmatterThiKhongCoVungGap() {
        XCTAssertNil(PromptFile.foldRange(in: buffer("chỉ là chữ\n")))
    }

    // MARK: - JSON Schema

    private let schema = """
    {
      "type": "object",
      "required": ["name", "parameters"],
      "additionalProperties": false,
      "properties": {
        "name": {"type": "string", "minLength": 1},
        "parameters": {"type": "object"},
        "retries": {"type": "integer", "minimum": 0, "maximum": 5}
      }
    }
    """

    func testToolHopLeThiKhongCoLoi() {
        let json = """
        {"name": "tra_cuu", "parameters": {}, "retries": 2}
        """
        XCTAssertTrue(JSONSchemaCheck.validate(json: json, schema: schema).isEmpty,
                      "\(JSONSchemaCheck.validate(json: json, schema: schema))")
    }

    func testThieuTruongBatBuoc() {
        let d = JSONSchemaCheck.validate(json: "{\"name\": \"x\"}", schema: schema)
        XCTAssertEqual(d.count, 1)
        XCTAssertTrue(d[0].message.contains("parameters"), d[0].message)
    }

    func testSaiKieu() {
        let json = "{\"name\": 5, \"parameters\": {}}"
        let d = JSONSchemaCheck.validate(json: json, schema: schema)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].path, "name")
        XCTAssertTrue(d[0].message.contains("string"), d[0].message)
    }

    /// `integer` khác `number`: schema đòi `integer` mà nhận `3.5` là sai, và bỏ qua khác biệt
    /// ấy là bỏ qua đúng loại lỗi hay gặp nhất trong định nghĩa tool.
    func testIntegerKhacNumber() {
        let json = "{\"name\": \"x\", \"parameters\": {}, \"retries\": 2.5}"
        let d = JSONSchemaCheck.validate(json: json, schema: schema)
        XCTAssertTrue(d.contains { $0.path == "retries" }, "\(d)")
    }

    func testNgoaiKhoangMinMax() {
        let json = "{\"name\": \"x\", \"parameters\": {}, \"retries\": 9}"
        XCTAssertTrue(JSONSchemaCheck.validate(json: json, schema: schema)
            .contains { $0.message.contains("≤ 5") })
    }

    func testTruongKhongKhaiBaoKhiAdditionalPropertiesFalse() {
        let json = "{\"name\": \"x\", \"parameters\": {}, \"la\": 1}"
        let d = JSONSchemaCheck.validate(json: json, schema: schema)
        XCTAssertTrue(d.contains { $0.path == "la" }, "\(d)")
    }

    /// Lỗi phải mang SỐ DÒNG thật, lấy từ `JSONIndex` — đặc tả đòi "lỗi chỉ đúng dòng".
    func testLoiMangSoDongThat() {
        let json = """
        {
          "name": "x",
          "parameters": {},
          "retries": 99
        }
        """
        let d = JSONSchemaCheck.validate(json: json, schema: schema)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].line, 3, "«retries» ở dòng thứ tư (0-based là 3)")
    }

    /// Khác biệt quan trọng nhất của bộ kiểm này: từ khoá NGOÀI tập con phải được BÁO RA. Im
    /// lặng bỏ qua `oneOf` sẽ cho «hợp lệ» với một tệp mà schema thật sự từ chối.
    func testTuKhoaCHUAHIEUthiBAORAchuKhongImLang() {
        let s = """
        {"type": "object", "oneOf": [{"required": ["a"]}]}
        """
        let d = JSONSchemaCheck.validate(json: "{}", schema: s)
        XCTAssertEqual(d.count, 1)
        XCTAssertTrue(d[0].unsupported, "phải đánh dấu là CHƯA HIỂU, không phải lỗi dữ liệu")
        XCTAssertTrue(d[0].message.contains("oneOf"), d[0].message)
    }

    /// `title`/`description` là hợp lệ và rất hay gặp — báo chúng là kêu oan.
    func testTuKhoaMOTAkhongBiBaoNham() {
        let s = """
        {"type": "string", "title": "Tên", "description": "tên công cụ"}
        """
        XCTAssertTrue(JSONSchemaCheck.validate(json: "\"x\"", schema: s).isEmpty)
    }

    /// Regex hỏng trong schema là lỗi của SCHEMA, không phải của dữ liệu — nói đúng bên nào sai,
    /// nếu không người dùng đi sửa nhầm tệp.
    func testRegexHongTrongSchemaLaLoiCuaSCHEMA() {
        let s = "{\"type\": \"string\", \"pattern\": \"[chưa đóng\"}"
        let d = JSONSchemaCheck.validate(json: "\"x\"", schema: s)
        XCTAssertEqual(d.count, 1)
        XCTAssertTrue(d[0].unsupported)
        XCTAssertTrue(d[0].message.contains("schema"), d[0].message)
    }

    func testSchemaKhongPhaiJSONthiNOIRA() {
        let d = JSONSchemaCheck.validate(json: "{}", schema: "không phải json")
        XCTAssertEqual(d.count, 1)
        XCTAssertTrue(d[0].message.contains("schema"))
    }

    func testTepKhongPhaiJSONthiNOIRA() {
        let d = JSONSchemaCheck.validate(json: "không phải json", schema: "{}")
        XCTAssertEqual(d.count, 1)
        XCTAssertTrue(d[0].message.contains("tệp"))
    }

    /// Kiểu đã sai thì KHÔNG kiểm sâu hơn — người sửa cần MỘT câu, không cần năm câu về cùng
    /// một chỗ.
    func testKieuSaiThiKhongDeThemNhieu() {
        let s = """
        {"type": "object", "required": ["a", "b"], "properties": {"a": {"type": "string"}}}
        """
        let d = JSONSchemaCheck.validate(json: "\"tôi là chuỗi\"", schema: s)
        XCTAssertEqual(d.count, 1, "\(d)")
    }

    func testMangKiemTungPhanTu() {
        let s = """
        {"type": "array", "items": {"type": "integer"}}
        """
        let d = JSONSchemaCheck.validate(json: "[1, \"hai\", 3]", schema: s)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].path, "[1]")
    }
}
