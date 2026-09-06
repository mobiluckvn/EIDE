import XCTest
@testable import GEditorCore

/// Tính vùng gấp (FR-CORE code folding · FR-FMT-507).
final class FoldRangesTests: XCTestCase {

    private func folds(_ text: String, language: SyntaxLanguage) -> [FoldRange] {
        FoldRanges.compute(in: TextBuffer(text: text), language: language)
    }

    /// Mô tả gọn để so sánh: "dòng đầu→dòng cuối".
    private func shape(_ folds: [FoldRange]) -> [String] {
        folds.map { "\($0.headerLine)→\($0.lastLine)" }
    }

    // MARK: - Thụt lề (YAML)

    private let yaml = """
    ten: cua hang
    dia_chi:
      so: 12
      duong: Lê Lợi
      thanh_pho: Hà Nội

    nhan_vien:
      - ten: An
        tuoi: 30
      - ten: Bình
        tuoi: 25
    ghi_chu: xong
    """

    func testIndentationBlocks() {
        XCTAssertEqual(shape(folds(yaml, language: .yaml)), ["1→4", "6→10", "7→8", "9→10"])
    }

    /// Dòng trắng ở GIỮA không được cắt khối làm đôi.
    func testBlankLineInsideDoesNotCloseTheBlock() {
        let text = """
        a:
          x: 1

          y: 2
        b: 3
        """
        XCTAssertEqual(shape(folds(text, language: .yaml)), ["0→3"])
    }

    /// Dòng trắng ở CUỐI khối không thuộc về khối — gấp xong không được để lại dòng lơ lửng.
    func testTrailingBlankLinesAreNotSwallowed() {
        let text = "a:\n  x: 1\n\n\nb: 2\n"
        let result = folds(text, language: .yaml)
        XCTAssertEqual(shape(result), ["0→1"])
    }

    /// Phần bị giấu phải là TRỌN các dòng thân, không nuốt ký tự xuống dòng của dòng đầu.
    ///
    /// Đây là chỗ tôi làm sai lần đầu: cắt từ cuối NỘI DUNG dòng đầu thì mất luôn `\n` của nó,
    /// và hai dòng còn lại dính liền thành `a:b: 3`.
    func testHiddenRangeIsWholeBodyLines() {
        let text = "a:\n  x: 1\n  y: 2\nb: 3\n"
        let buffer = TextBuffer(text: text)
        guard let fold = FoldRanges.byIndentation(in: buffer).first else {
            return XCTFail("không tìm được vùng gấp")
        }
        XCTAssertEqual(fold.headerLine, 0)
        XCTAssertEqual(fold.lastLine, 2)
        XCTAssertEqual(String(decoding: buffer.bytes(in: fold.hiddenBytes), as: UTF8.self),
                       "  x: 1\n  y: 2\n")
        XCTAssertEqual(fold.caretHome, 2)          // ngay sau `a:`

        let remaining = String(decoding: buffer.bytes(in: 0 ..< fold.hiddenBytes.lowerBound), as: UTF8.self)
            + String(decoding: buffer.bytes(in: fold.hiddenBytes.upperBound ..< buffer.count), as: UTF8.self)
        XCTAssertEqual(remaining, "a:\nb: 3\n")
    }

    func testTabCountsAsEightColumns() {
        let buffer = TextBuffer(text: "a\n\tb\n        c\n")
        XCTAssertEqual(FoldRanges.indentWidth(of: 0, in: buffer), 0)
        XCTAssertEqual(FoldRanges.indentWidth(of: 1, in: buffer), 8)
        XCTAssertEqual(FoldRanges.indentWidth(of: 2, in: buffer), 8)
    }

    func testWhitespaceOnlyLineCountsAsBlank() {
        let buffer = TextBuffer(text: "a\n   \nb\n")
        XCTAssertEqual(FoldRanges.indentWidth(of: 1, in: buffer), -1)
    }

    func testSingleLineDocumentHasNoFolds() {
        XCTAssertTrue(folds("chi mot dong", language: .yaml).isEmpty)
        XCTAssertTrue(folds("", language: .yaml).isEmpty)
    }

    // MARK: - Mục (TOML)

    private let toml = """
    tieu_de = "cau hinh"

    [may_chu]
    dia_chi = "127.0.0.1"
    cong = 8080

    [co_so_du_lieu]
    ten = "geditor"

    [may_chu.tls]
    bat = true
    """

    func testTOMLSections() {
        XCTAssertEqual(shape(folds(toml, language: .toml)), ["2→4", "6→7", "9→10"])
    }

    /// `[a.b]` là bảng ĐỘC LẬP, không phải bảng con — gấp `[a]` không được nuốt nó.
    func testDottedTableIsNotNested() {
        let result = folds(toml, language: .toml)
        guard let first = result.first else { return XCTFail("không có vùng nào") }
        XCTAssertEqual(first.lastLine, 4, "gấp [may_chu] mà nuốt luôn [may_chu.tls] ở cuối file")
    }

    func testSectionlessFileHasNoFolds() {
        XCTAssertTrue(folds("a = 1\nb = 2\n", language: .toml).isEmpty)
    }

    // MARK: - JSON

    private let json = """
    {
      "cua_hang": {
        "sach": [
          { "ten": "Truyện Kiều" },
          { "ten": "Số đỏ" }
        ]
      },
      "ghi_chu": "dùng { để mở khối"
    }
    """

    func testJSONContainers() {
        // gốc 0→8 · cua_hang 1→6 · sach 2→5. Hai object sách nằm gọn một dòng nên không gấp.
        //
        // Dòng cuối của mỗi vùng là dòng chứa dấu ĐÓNG, và nó cũng bị giấu — gấp theo dòng thì
        // `},` không thể vừa bị giấu vừa hiện ra. Dòng đầu vẫn đọc được là `"cua_hang": {`.
        XCTAssertEqual(shape(folds(json, language: .json)), ["0→8", "1→6", "2→5"])
    }

    /// Dấu ngoặc nằm trong CHUỖI không được coi là mở khối — đây là lý do dùng JSONIndex chứ
    /// không đếm ngoặc bằng byte.
    func testBraceInsideStringIsNotAFold() {
        let text = "{\n  \"a\": \"co { trong chuoi\",\n  \"b\": 1\n}\n"
        XCTAssertEqual(shape(folds(text, language: .json)), ["0→3"])
    }

    func testInvalidJSONFoldsNothingInsteadOfGuessing() {
        XCTAssertTrue(folds("{ \"a\": 1,\n}\n", language: .json).isEmpty)
    }

    func testSingleLineJSONHasNoFolds() {
        XCTAssertTrue(folds(#"{"a": {"b": 1}}"#, language: .json).isEmpty)
    }

    // MARK: - Thẻ (XML, HTML)

    private let xml = """
    <?xml version="1.0"?>
    <cua_hang>
      <sach ten="Truyện Kiều">
        <gia>120000</gia>
      </sach>
      <ghi_chu title="a > b">một dòng</ghi_chu>
    </cua_hang>
    """

    func testTagFolds() {
        XCTAssertEqual(shape(folds(xml, language: .xml)), ["1→6", "2→4"])
    }

    /// Dấu `>` trong giá trị thuộc tính KHÔNG đóng thẻ. Bỏ qua chuyện này là gấp sai, không
    /// phải gấp thiếu.
    func testAngleBracketInsideAttributeIsNotATagEnd() {
        let text = "<a>\n  <b title=\"x > y\">\n    <c/>\n  </b>\n</a>\n"
        XCTAssertEqual(shape(folds(text, language: .xml)), ["0→4", "1→3"])
    }

    func testCommentsAndCDATAAreSkipped() {
        let text = "<a>\n  <!-- <b> trong chú thích -->\n  <![CDATA[ <c> ]]>\n</a>\n"
        XCTAssertEqual(shape(folds(text, language: .xml)), ["0→3"])
    }

    /// File đang SỬA DỞ vẫn phải gấp được phần lành lặn — người ta gấp giữa lúc đang gõ.
    func testBrokenDocumentStillFoldsWhatItCan() {
        let text = "<a>\n  <b>\n    <c>\n  </b>\n</a>\n"        // `<c>` không đóng
        XCTAssertEqual(shape(folds(text, language: .xml)), ["0→4", "1→3"])
    }

    /// `<br>` không có thẻ đóng; coi nó là thẻ mở thì nó nuốt cả phần còn lại của tài liệu.
    func testVoidHTMLTagsDoNotOpenAFold() {
        let text = "<div>\n  <br>\n  <img src=\"a.png\">\n  <p>chào</p>\n</div>\n"
        XCTAssertEqual(shape(folds(text, language: .html)), ["0→4"])
    }

    func testSelfClosingTagIsNotAFold() {
        XCTAssertEqual(shape(folds("<a>\n  <b/>\n</a>\n", language: .xml)), ["0→2"])
    }

    func testSingleLineTagHasNoFold() {
        XCTAssertTrue(folds("<a><b/></a>\n", language: .xml).isEmpty)
    }

    // MARK: - Cây cú pháp (C và họ hàng)

    func testCBlocksFold() {
        let text = """
        int main(void) {
          if (x) {
            return 1;
          }
          return 0;
        }
        """
        XCTAssertEqual(shape(folds(text, language: .c)), ["0→5", "1→3"])
    }

    /// **Đây là lý do dùng cây cú pháp thay vì đếm ngoặc.** Ba dấu ngoặc trong dòng dưới không
    /// mở hay đóng khối nào; bộ đếm byte sẽ lệch từ đó tới hết file và gấp NHẦM CHỖ.
    func testBracesInsideStringsAndCommentsDoNotCount() {
        let text = """
        int main(void) {
          printf("dùng { để mở khối");   // và } để đóng
          return 0;
        }
        """
        XCTAssertEqual(shape(folds(text, language: .c)), ["0→3"])
    }

    func testMultiLineCommentFolds() {
        let text = """
        /*
         * Giấy phép
         */
        int x = 1;
        """
        XCTAssertEqual(shape(folds(text, language: .c)), ["0→2"])
    }

    func testSingleLineCommentsDoNotFold() {
        XCTAssertTrue(folds("// một\n// hai\nint x = 1;\n", language: .c).isEmpty)
    }

    /// Nhiều nút lồng nhau bắt đầu ở CÙNG một dòng chỉ được sinh ra MỘT vùng gấp.
    ///
    /// `if (x) {` cho ra cả nút `if_statement` lẫn nút khối, và hai mục trùng nhau làm lệnh
    /// "gấp/mở tại con nháy" phải bấm hai lần mới thấy đổi.
    func testOnlyOneFoldPerHeaderLine() {
        let text = "void f(void) {\n  if (x) {\n    g();\n  }\n}\n"
        let result = folds(text, language: .c)
        XCTAssertEqual(result.count, Set(result.map(\.headerLine)).count)
    }

    func testGoAndRustFoldToo() {
        let go = "package main\n\nfunc main() {\n\tx := 1\n\t_ = x\n}\n"
        XCTAssertEqual(shape(folds(go, language: .go)), ["2→5"])

        let rust = "fn main() {\n    let x = 1;\n    let _ = x;\n}\n"
        XCTAssertEqual(shape(folds(rust, language: .rust)), ["0→3"])
    }

    /// Mảng và danh sách tham số trải nhiều dòng cũng gấp được — chúng là cặp ngoặc thật.
    func testMultiLineArrayFolds() {
        let text = "int a[] = {\n  1,\n  2,\n};\n"
        XCTAssertFalse(folds(text, language: .c).isEmpty)
    }

    /// Ngôn ngữ chưa nhận ra thì không gấp gì, và KHÔNG được sập.
    func testUnknownLanguageFoldsNothing() {
        XCTAssertTrue(FoldRanges.compute(in: TextBuffer(text: yaml), language: nil).isEmpty)
    }

    /// File hỏng cú pháp vẫn phải gấp được phần lành lặn — người ta gấp giữa lúc đang gõ.
    func testBrokenCodeStillFoldsWhatItCan() {
        let text = "void f(void) {\n  g(;\n}\n"
        XCTAssertFalse(folds(text, language: .c).isEmpty)
    }

    // MARK: - Giới hạn đã nói ra

    func testOversizeDocumentFoldsNothing() {
        // Không dựng file 16 MB thật trong bài kiểm; kiểm ngay điều kiện trần.
        XCTAssertEqual(FoldRanges.sizeLimit, DocumentOutline.sizeLimit)
    }

    // MARK: - Cấp lồng (FR-FMT-503 — "fold theo cấp")

    /// Cấp đếm theo SỐ VÙNG BAO, và cấp 1 phải trùng đúng khái niệm "ngoài cùng" mà `foldAll` dùng.
    func testLevelsCountEnclosingRangesNotIndentDepth() {
        let result = folds(yaml, language: .yaml)
        XCTAssertEqual(shape(result), ["1→4", "6→10", "7→8", "9→10"])
        XCTAssertEqual(FoldRanges.levels(of: result), [0, 0, 1, 1])

        XCTAssertEqual(shape(FoldRanges.ranges(atLevel: 1, in: result)), ["1→4", "6→10"])
        XCTAssertEqual(shape(FoldRanges.ranges(atLevel: 2, in: result)), ["7→8", "9→10"])
        XCTAssertEqual(shape(FoldRanges.outermost(in: result)),
                       shape(FoldRanges.ranges(atLevel: 1, in: result)))
        XCTAssertEqual(FoldRanges.levelCount(of: result), 2)
    }

    /// Cấp 2 trả về ĐÚNG cấp 2, không kèm cấp 3 — nếu không thì mở một khối phải bấm nhiều lần.
    func testLevelReturnsThatLevelOnlyNotEverythingInside() {
        let text = """
        a:
          b:
            c:
              d: 1
        """
        let result = folds(text, language: .yaml)
        XCTAssertEqual(FoldRanges.levels(of: result), [0, 1, 2])
        XCTAssertEqual(shape(FoldRanges.ranges(atLevel: 2, in: result)), ["1→3"])
        XCTAssertEqual(FoldRanges.levelCount(of: result), 3)
    }

    /// Cấp sâu hơn tài liệu, và cấp không hợp lệ, đều trả RỖNG — chỗ gọi dựa vào đó để báo ra.
    func testLevelOutOfRangeIsEmptyNotACrash() {
        let result = folds(yaml, language: .yaml)
        XCTAssertTrue(FoldRanges.ranges(atLevel: 3, in: result).isEmpty)
        XCTAssertTrue(FoldRanges.ranges(atLevel: 0, in: result).isEmpty)
        XCTAssertTrue(FoldRanges.ranges(atLevel: -1, in: result).isEmpty)
        XCTAssertTrue(FoldRanges.ranges(atLevel: 1, in: []).isEmpty)
        XCTAssertEqual(FoldRanges.levelCount(of: []), 0)
    }

    /// Cấp tính được trên mọi bộ tính, không riêng bộ thụt lề — JSON lồng sâu là ca thật nhất.
    func testLevelsWorkForBracketFoldsToo() {
        let text = """
        {
          "a": {
            "b": [
              1
            ]
          }
        }
        """
        let result = folds(text, language: .json)
        let depths = FoldRanges.levels(of: result)
        XCTAssertEqual(depths, Array(0..<result.count), "JSON lồng thẳng: mỗi vùng sâu hơn vùng trước một cấp")
        XCTAssertEqual(FoldRanges.ranges(atLevel: 1, in: result).count, 1)
    }

    // MARK: - Bất biến chung

    /// Vùng gấp phải sắp theo dòng đầu, và vùng lồng nhau phải LỒNG THẬT chứ không cắt chéo.
    func testFoldsAreSortedAndProperlyNested() {
        for (text, language) in [(yaml, SyntaxLanguage.yaml), (toml, .toml), (json, .json), (xml, .xml)] {
            let result = folds(text, language: language)
            XCTAssertEqual(shape(result), shape(result.sorted { $0.headerLine < $1.headerLine }))
            for a in result {
                for b in result where b.headerLine > a.headerLine && b.headerLine <= a.lastLine {
                    XCTAssertLessThanOrEqual(
                        b.lastLine, a.lastLine,
                        "\(language.rawValue): vùng \(b.headerLine)→\(b.lastLine) cắt chéo "
                            + "vùng \(a.headerLine)→\(a.lastLine)"
                    )
                }
            }
        }
    }
}
