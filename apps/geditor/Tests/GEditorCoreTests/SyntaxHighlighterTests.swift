import XCTest
@testable import GEditorCore

/// Tô màu cú pháp (FR-FMT-501, ADR-04).
final class SyntaxHighlighterTests: XCTestCase {

    // MARK: - Cả hai mươi ngôn ngữ phải THẬT SỰ chạy

    /// Bài quan trọng nhất của cả nhóm.
    ///
    /// Grammar vendor vào rồi biên dịch sạch KHÔNG có nghĩa là nó chạy: hàm có thể lệch tên
    /// (C# đúng là đã lệch, và chỉ lộ ra ở bước liên kết), truy vấn có thể không biên dịch
    /// được với ABI của grammar, và cả hai chuyện ấy đều im lặng cho tới lúc người dùng mở file.
    func testEveryLanguageLoadsAndCompilesItsQuery() {
        var broken: [String] = []
        for language in SyntaxLanguage.allCases {
            guard language.handle != nil else {
                broken.append("\(language.rawValue): grammar không nạp được")
                continue
            }
            guard language.highlightQuerySource != nil else {
                broken.append("\(language.rawValue): không có truy vấn tô màu")
                continue
            }
            guard SyntaxHighlighter(language: language) != nil else {
                broken.append("\(language.rawValue): truy vấn không biên dịch được")
                continue
            }
        }
        XCTAssertEqual(SyntaxLanguage.allCases.count, 20, "Phase 1 đòi 20 ngôn ngữ")
        XCTAssertTrue(broken.isEmpty, "hỏng: \(broken.joined(separator: " · "))")
    }

    /// Và mỗi ngôn ngữ phải tô ra được ÍT NHẤT một đoạn trên mã mẫu của chính nó.
    ///
    /// Không có bài này thì một truy vấn rỗng, hay một truy vấn khớp sai grammar, vẫn "đạt":
    /// nó biên dịch được và trả về danh sách rỗng.
    func testEveryLanguageProducesSpansOnItsOwnSample() {
        var silent: [String] = []
        for (language, sample) in Self.samples {
            guard let highlighter = SyntaxHighlighter(language: language) else {
                silent.append("\(language.rawValue): không dựng được")
                continue
            }
            let buffer = TextBuffer(text: sample)
            let spans = highlighter.spans(in: buffer, range: 0 ..< buffer.count)
            if spans.isEmpty { silent.append(language.rawValue) }
        }
        XCTAssertTrue(silent.isEmpty, "không tô được đoạn nào: \(silent.joined(separator: ", "))")
    }

    // MARK: - Hành vi

    func testSpansAreInsideTheRequestedRangeAndNotEmpty() {
        let buffer = TextBuffer(text: "int main(void) { return 0; }\nint khac(void) { return 1; }\n")
        let highlighter = SyntaxHighlighter(language: .c)!
        let range = 0 ..< 28
        for span in highlighter.spans(in: buffer, range: range) {
            XCTAssertGreaterThanOrEqual(span.range.lowerBound, range.lowerBound, span.scope)
            XCTAssertLessThanOrEqual(span.range.upperBound, range.upperBound, span.scope)
            XCTAssertFalse(span.range.isEmpty, span.scope)
            XCTAssertFalse(span.scope.isEmpty)
        }
    }

    func testKeywordAndStringAreRecognisedInC() {
        let source = "int main(void) { const char *s = \"xin chao\"; return 0; }\n"
        let buffer = TextBuffer(text: source)
        let highlighter = SyntaxHighlighter(language: .c)!
        let spans = highlighter.spans(in: buffer, range: 0 ..< buffer.count)

        func text(_ span: HighlightSpan) -> String {
            String(decoding: buffer.bytes(in: span.range), as: UTF8.self)
        }
        XCTAssertTrue(spans.contains { $0.scope.contains("string") && text($0).contains("xin chao") },
                      "không nhận ra chuỗi: \(spans.map(\.scope))")
        XCTAssertTrue(spans.contains { text($0) == "return" },
                      "không nhận ra từ khoá return")
    }

    /// Chữ tiếng Việt trong chuỗi KHÔNG được làm lệch offset.
    ///
    /// tree-sitter trả offset BYTE, và lõi GEditor cũng làm việc bằng offset byte — nhưng đây
    /// là chỗ hai hệ đếm gặp nhau, và dự án này đã có vài lỗi đúng ở kiểu quy đổi ấy.
    func testVietnameseTextDoesNotShiftOffsets() {
        let source = "const char *ten = \"Nguyễn Văn A\";\nint x = 1;\n"
        let buffer = TextBuffer(text: source)
        let highlighter = SyntaxHighlighter(language: .c)!
        let spans = highlighter.spans(in: buffer, range: 0 ..< buffer.count)

        guard let string = spans.first(where: { $0.scope.contains("string") }) else {
            return XCTFail("không thấy chuỗi trong \(spans.map(\.scope))")
        }
        let text = String(decoding: buffer.bytes(in: string.range), as: UTF8.self)
        XCTAssertTrue(text.contains("Nguyễn Văn A"), "đoạn tô ra là «\(text)»")
    }

    // MARK: - Lề (quyết định của ADR-04)

    func testAnalysisRangeAddsMarginOnBothSides() {
        let line = String(repeating: "x", count: 79) + "\n"
        let buffer = TextBuffer(text: String(repeating: line, count: 4_000))   // ~320 KB
        let highlighter = SyntaxHighlighter(language: .c)!

        let middle = 150_000 ..< 160_000
        let scope = highlighter.analysisRange(for: middle, in: buffer)

        XCTAssertLessThan(scope.lowerBound, middle.lowerBound, "phải nới về TRƯỚC")
        XCTAssertGreaterThan(scope.upperBound, middle.upperBound, "phải nới về SAU")
        XCTAssertGreaterThanOrEqual(middle.lowerBound - scope.lowerBound,
                                    SyntaxHighlighter.marginBytes - 100)
        XCTAssertGreaterThanOrEqual(scope.upperBound - middle.upperBound,
                                    SyntaxHighlighter.marginBytes - 100)
    }

    func testAnalysisRangeIsClampedAtBothEndsOfTheDocument() {
        let buffer = TextBuffer(text: "int a;\nint b;\n")
        let highlighter = SyntaxHighlighter(language: .c)!
        let scope = highlighter.analysisRange(for: 0 ..< buffer.count, in: buffer)
        XCTAssertEqual(scope.lowerBound, 0)
        XCTAssertEqual(scope.upperBound, buffer.count)
    }

    /// Đây là điều ADR-04 mua bằng cái lề: một khối `/* */` mở ra TRƯỚC vùng cần tô vẫn được
    /// hiểu đúng là chú thích.
    func testCommentOpenedBeforeTheRangeIsStillUnderstood() {
        var source = "/* khoi chu thich mo o day\n"
        for index in 0 ..< 200 { source += " * dong \(index) trong chu thich\n" }
        source += " */\nint sau_chu_thich = 1;\n"

        let buffer = TextBuffer(text: source)
        let highlighter = SyntaxHighlighter(language: .c)!

        // Chỉ hỏi phần GIỮA khối chú thích — nếu không có lề, tree-sitter sẽ đọc nó thành mã.
        let start = source.utf8.count / 2
        let spans = highlighter.spans(in: buffer, range: start ..< (start + 500))

        XCTAssertFalse(spans.isEmpty, "không tô được gì")
        XCTAssertTrue(spans.allSatisfy { $0.scope.contains("comment") },
                      "giữa khối chú thích mà tô ra: \(Set(spans.map(\.scope)))")
    }

    // MARK: - Nhận dạng ngôn ngữ theo đuôi file

    func testDetectByExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(path: "/a/b/main.swift"), nil, "Swift chưa có ở Phase 1")
        XCTAssertEqual(SyntaxLanguage.detect(path: "/a/b/main.c"), .c)
        XCTAssertEqual(SyntaxLanguage.detect(path: "du/lieu.JSON"), .json, "đuôi không phân biệt hoa thường")
        XCTAssertEqual(SyntaxLanguage.detect(path: "cau/hinh.yml"), .yaml)
        XCTAssertEqual(SyntaxLanguage.detect(path: "/x/Makefile"), .bash)
        XCTAssertNil(SyntaxLanguage.detect(path: "/x/ghi-chu"))
        XCTAssertNil(SyntaxLanguage.detect(path: "/x/nhat-ky.log"))
    }

    func testEmptyBufferIsSafe() {
        let highlighter = SyntaxHighlighter(language: .json)!
        XCTAssertTrue(highlighter.spans(in: TextBuffer(text: ""), range: 0 ..< 0).isEmpty)
    }

    // MARK: - Mã mẫu

    private static let samples: [(SyntaxLanguage, String)] = [
        (.bash, "#!/bin/bash\nif [ -f \"$1\" ]; then echo \"co\"; fi\n"),
        (.c, "#include <stdio.h>\nint main(void) { return 0; }\n"),
        (.cpp, "#include <vector>\nint main() { std::vector<int> v; return 0; }\n"),
        (.csharp, "using System;\nclass A { static void Main() { Console.Write(1); } }\n"),
        (.css, "body { color: #fff; margin: 0 auto; }\n"),
        (.go, "package main\nimport \"fmt\"\nfunc main() { fmt.Println(\"a\") }\n"),
        (.html, "<html><body><p class=\"x\">chao</p></body></html>\n"),
        (.java, "class A { public static void main(String[] a) { int x = 1; } }\n"),
        (.javascript, "const a = 1;\nfunction f(x) { return x + 1; }\n"),
        (.json, "{\"ten\": \"A\", \"so\": 12, \"co\": true}\n"),
        (.lua, "local x = 1\nfunction f(a) return a + 1 end\n"),
        (.php, "<?php\nfunction f($a) { return $a + 1; }\n"),
        (.python, "import os\ndef f(a):\n    return a + 1\n"),
        (.regex, "^[a-z]+\\\\d{2,3}$"),
        (.ruby, "class A\n  def f(a)\n    a + 1\n  end\nend\n"),
        (.rust, "fn main() { let x: i32 = 1; println!(\"{}\", x); }\n"),
        (.toml, "[muc]\nten = \"A\"\nso = 12\n"),
        (.typescript, "const a: number = 1;\nfunction f(x: string): string { return x; }\n"),
        (.xml, "<?xml version=\"1.0\"?>\n<goc><con ten=\"A\">noi dung</con></goc>\n"),
        (.yaml, "ten: A\nso: 12\nds:\n  - mot\n  - hai\n"),
    ]
}

/// Ngôn ngữ mà THỤT LỀ là cú pháp (ADR-04 §2.7).
final class IndentSensitiveLanguageTests: XCTestCase {

    /// Nội dung có khối thụt lề sâu, lặp lại — dạng làm lộ vấn đề.
    private func pythonSource(bytes: Int) -> String {
        var text = "import os\n"
        var index = 0
        while text.utf8.count < bytes {
            text += "class Lop\(index):\n"
            text += "    \"\"\"Tai lieu nhieu dong.\n"
            for line in 0 ..< 20 { text += "    dong \(line) van xuoi, khong phai ma nguon\n" }
            text += "    \"\"\"\n\n    def ham(self, a):\n        if a > 0:\n"
            text += "            return a + \(index)\n        return 0\n\n"
            index += 1
        }
        return text
    }

    private func yamlSource(bytes: Int) -> String {
        var text = "---\n"
        var index = 0
        while text.utf8.count < bytes {
            text += "muc_\(index):\n  ten: \"A\"\n  mo_ta: |\n"
            for line in 0 ..< 20 { text += "    dong \(line) trong chuoi khoi\n" }
            text += "  ds:\n    - mot\n    - hai\n"
            index += 1
        }
        return text
    }

    /// Bài quyết định: kết quả trên CỬA SỔ phải khớp kết quả trên CẢ TÀI LIỆU.
    ///
    /// Đây là điều PoC-D đo được và là lý do có phép dóng cột 0. Không dóng thì Python cho
    /// 41.808 capture ở chỗ đúng ra chỉ có 4.699 — văn xuôi trong docstring bị đọc thành mã.
    private func assertWindowMatchesWholeDocument(
        _ language: SyntaxLanguage, source: String, line: UInt = #line
    ) {
        let buffer = TextBuffer(text: source)
        let highlighter = SyntaxHighlighter(language: language)!

        var start = buffer.count / 2
        let all = buffer.bytes(in: 0 ..< buffer.count)
        while start > 0, all[start - 1] != UInt8(ascii: "\n") { start -= 1 }
        let end = Swift.min(buffer.count, start + 64 * 1024)
        let window = start ..< end

        // So các đoạn nằm TRỌN trong cửa sổ.
        //
        // Đoạn vắt qua biên bị cắt cụt theo đúng thiết kế — cửa sổ chỉ báo được phần nó thấy.
        // Bản đầu của bài này so cả những đoạn chạm biên và lệch đúng 2 đoạn ở hai mép; đó là
        // bài kiểm khắt khe sai chỗ, không phải mã sai.
        func inside(_ span: HighlightSpan) -> Bool {
            span.range.lowerBound > start && span.range.upperBound < end
        }
        let whole = Set(
            highlighter.spans(in: buffer, range: 0 ..< buffer.count)
                .filter(inside)
                .map { "\($0.range.lowerBound)-\($0.range.upperBound)-\($0.scope)" }
        )
        let windowed = Set(
            highlighter.spans(in: buffer, range: window)
                .filter(inside)
                .map { "\($0.range.lowerBound)-\($0.range.upperBound)-\($0.scope)" }
        )

        XCTAssertFalse(whole.isEmpty, "phân tích cả tài liệu không ra gì", line: line)
        XCTAssertEqual(
            windowed.count, whole.count,
            "cửa sổ ra \(windowed.count) đoạn, cả tài liệu ra \(whole.count)",
            line: line
        )
        XCTAssertTrue(windowed == whole, "cửa sổ và cả tài liệu cho kết quả KHÁC nhau", line: line)
    }

    func testPythonWindowMatchesWholeDocument() {
        assertWindowMatchesWholeDocument(.python, source: pythonSource(bytes: 400_000))
    }

    func testYamlWindowMatchesWholeDocument() {
        assertWindowMatchesWholeDocument(.yaml, source: yamlSource(bytes: 400_000))
    }

    func testCStillMatches() {
        var text = ""
        while text.utf8.count < 300_000 {
            text += "/* chu thich */\nstatic int ham(int a) { return a + 1; }\n"
        }
        assertWindowMatchesWholeDocument(.c, source: text)
    }

    /// Phép dóng phải LÙI, không được nhảy tới.
    func testColumnZeroAlignmentMovesBackwards() {
        let source = "khong_thut_le:\n    thut le 1\n    thut le 2\n    thut le 3\n"
        let buffer = TextBuffer(text: source)
        let highlighter = SyntaxHighlighter(language: .yaml)!

        let insideBlock = source.utf8.count - 12
        let aligned = highlighter.columnZeroLineStart(before: insideBlock, in: buffer)
        XCTAssertEqual(aligned, 0, "phải lùi về dòng cột 0 đầu tiên")
        XCTAssertLessThanOrEqual(aligned, insideBlock)
    }

    /// File mà MỌI dòng đều thụt lề: phải dừng ở trần tìm kiếm, không quét mãi.
    func testGivesUpAtTheSearchLimit() {
        var text = "    dong dau thut le\n"
        while text.utf8.count < 200_000 { text += "    dong thut le tiep theo\n" }
        let buffer = TextBuffer(text: text)
        let highlighter = SyntaxHighlighter(language: .python)!

        let aligned = highlighter.columnZeroLineStart(before: buffer.count - 100, in: buffer)
        XCTAssertGreaterThanOrEqual(aligned, 0)
        XCTAssertLessThan(aligned, buffer.count, "không được trả về quá cuối")
    }
}

final class OldWholeDocumentTests: XCTestCase {
    /// YAML file LỚN giờ tô được — trước đây phải bỏ qua.
    ///
    /// Hành vi cũ ("file lớn thì không tô") là cách xử lý đúng khi chưa biết vì sao lát cắt
    /// hỏng. Khi đã biết — thiếu gốc toạ độ thụt lề — thì cách sửa tốt hơn hẳn là dóng cột 0,
    /// và cái ngoại lệ ấy biến mất.
    func testYamlHighlightsLargeDocumentsNow() {
        var text = ""
        while text.utf8.count < 400_000 { text += "muc:\n  ten: A\n  so: 1\n" }
        let buffer = TextBuffer(text: text)
        let highlighter = SyntaxHighlighter(language: .yaml)!
        XCTAssertFalse(highlighter.spans(in: buffer, range: 200_000 ..< 210_000).isEmpty,
                       "YAML file lớn phải tô được")
    }
}
