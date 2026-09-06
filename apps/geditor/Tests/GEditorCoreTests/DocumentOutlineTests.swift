import XCTest
@testable import GEditorCore

/// Function List dựng từ cây cú pháp (FR-DOC-307).
final class DocumentOutlineTests: XCTestCase {

    private func symbols(_ source: String, _ language: SyntaxLanguage) -> [DocumentSymbol] {
        DocumentOutline.symbols(in: Array(source.utf8), language: language)
    }

    private func names(_ source: String, _ language: SyntaxLanguage) -> [String] {
        symbols(source, language).map(\.name)
    }

    // MARK: - Từng ngôn ngữ

    func testPython() {
        let source = """
        import os

        def tinh_tong(a, b):
            return a + b

        class KhachHang:
            def __init__(self, ten):
                self.ten = ten

            def chao(self):
                return f"Xin chào {self.ten}"

        def main():
            pass
        """
        XCTAssertEqual(names(source, .python), ["tinh_tong", "KhachHang", "__init__", "chao", "main"])

        // Phương thức nằm TRONG lớp thì lồng sâu hơn — danh sách phải giữ được cấu trúc ấy.
        let list = symbols(source, .python)
        let khachHang = list.first { $0.name == "KhachHang" }!
        let chao = list.first { $0.name == "chao" }!
        XCTAssertEqual(khachHang.kind, .type)
        XCTAssertEqual(chao.kind, .function)
        XCTAssertGreaterThan(chao.depth, khachHang.depth)
    }

    func testJavaScriptIncludingArrowFunctions() {
        let source = """
        function chao(ten) { return "hi " + ten; }

        const tinhThue = (tien) => tien * 0.1;

        class GioHang {
            themMon(mon) {}
        }
        """
        let found = names(source, .javascript)
        XCTAssertTrue(found.contains("chao"), "\(found)")
        // `const foo = () => {}` là cách viết hàm phổ biến nhất trong mã hiện đại; thiếu nó
        // thì Function List của một file React gần như rỗng.
        XCTAssertTrue(found.contains("tinhThue"), "\(found)")
        XCTAssertTrue(found.contains("GioHang"), "\(found)")
        XCTAssertTrue(found.contains("themMon"), "\(found)")
    }

    func testGo() {
        let source = """
        package main

        type KhachHang struct {
            Ten string
        }

        func (k KhachHang) Chao() string { return k.Ten }

        func main() {}
        """
        let found = names(source, .go)
        XCTAssertTrue(found.contains("KhachHang"), "\(found)")
        XCTAssertTrue(found.contains("Chao"), "\(found)")
        XCTAssertTrue(found.contains("main"), "\(found)")
    }

    /// Trong C, tên hàm nằm lẫn với danh sách tham số — danh sách phải hiện đúng cái TÊN.
    func testCAndCPlusPlus() {
        let c = """
        #include <stdio.h>

        struct KhachHang { int id; };

        static int tinh_tong(int a, int b) { return a + b; }

        int main(void) { return 0; }
        """
        let found = names(c, .c)
        XCTAssertTrue(found.contains("tinh_tong"), "\(found)")
        XCTAssertTrue(found.contains("main"), "\(found)")
        XCTAssertTrue(found.contains("KhachHang"), "\(found)")
        XCTAssertFalse(found.contains { $0.contains("(") }, "tên còn dính tham số: \(found)")

        let cpp = """
        namespace bao {
        class KhachHang {
        public:
            void chao();
        };
        }
        void bao::KhachHang::chao() {}
        """
        let cppNames = names(cpp, .cpp)
        XCTAssertTrue(cppNames.contains("bao"), "\(cppNames)")
        XCTAssertTrue(cppNames.contains("KhachHang"), "\(cppNames)")
    }

    func testRust() {
        let source = """
        struct KhachHang { ten: String }

        impl KhachHang {
            fn chao(&self) -> String { self.ten.clone() }
        }

        fn main() {}
        """
        let found = names(source, .rust)
        XCTAssertTrue(found.contains("KhachHang"), "\(found)")
        XCTAssertTrue(found.contains("chao"), "\(found)")
        XCTAssertTrue(found.contains("main"), "\(found)")
    }

    func testRuby() {
        let source = """
        module Bao
          class KhachHang
            def chao
              "hi"
            end
          end
        end
        """
        XCTAssertEqual(names(source, .ruby), ["Bao", "KhachHang", "chao"])
    }

    func testBash() {
        let source = """
        #!/bin/bash
        chuan_bi() { echo ok; }
        function don_dep { echo done; }
        """
        let found = names(source, .bash)
        XCTAssertTrue(found.contains("chuan_bi"), "\(found)")
        XCTAssertTrue(found.contains("don_dep"), "\(found)")
    }

    /// File cấu hình không có hàm — mục lục là các khóa/mục cấp cao.
    func testConfigFilesGetSections() {
        let json = """
        {
          "ten": "GEditor",
          "phien_ban": "2.0",
          "tac_gia": { "ten": "Mobiluck" }
        }
        """
        let jsonNames = names(json, .json)
        XCTAssertTrue(jsonNames.contains("ten"), "\(jsonNames)")
        XCTAssertTrue(jsonNames.contains("phien_ban"), "\(jsonNames)")

        let yaml = """
        ten: GEditor
        phien_ban: "2.0"
        tac_gia:
          ten: Mobiluck
        """
        let yamlNames = names(yaml, .yaml)
        XCTAssertTrue(yamlNames.contains("ten"), "\(yamlNames)")
        XCTAssertTrue(yamlNames.contains("tac_gia"), "\(yamlNames)")

        let toml = """
        [thu_muc]
        goc = "/tmp"

        [[may_chu]]
        ten = "a"
        """
        let tomlNames = names(toml, .toml)
        XCTAssertTrue(tomlNames.contains("thu_muc"), "\(tomlNames)")
        XCTAssertTrue(tomlNames.contains("may_chu"), "\(tomlNames)")
    }

    func testCSSSelectors() {
        let source = """
        .khach-hang { color: red; }
        #tieu-de span { font-weight: bold; }
        """
        let found = names(source, .css)
        XCTAssertTrue(found.contains(".khach-hang"), "\(found)")
        XCTAssertTrue(found.contains("#tieu-de span"), "\(found)")
    }

    /// Ngôn ngữ không có mục lục đáng tin thì trả RỖNG, không bịa.
    ///
    /// Một danh sách mọi thẻ `<div>` là tiếng ồn, không phải mục lục — và tiếng ồn làm người
    /// dùng tắt hẳn Function List, kể cả cho những file mà nó có ích.
    func testLanguagesWithoutAMeaningfulOutlineStaySilent() {
        XCTAssertTrue(names("<div><p>xin chào</p></div>", .html).isEmpty)
        XCTAssertTrue(names("<a><b>x</b></a>", .xml).isEmpty)
    }

    // MARK: - Thứ tự, dòng, phạm vi

    /// Thứ tự FILE, không phải thứ tự abc: người dùng nhớ "khoảng giữa file", không nhớ tên.
    func testKeepsFileOrder() {
        let source = """
        def zeta(): pass
        def alpha(): pass
        def mid(): pass
        """
        XCTAssertEqual(names(source, .python), ["zeta", "alpha", "mid"])
    }

    /// Số dòng phải đúng — đó là thứ người dùng đối chiếu bằng mắt trước khi bấm.
    func testLineNumbers() {
        let source = """
        # dòng 1
        def mot(): pass

        def hai(): pass


        def ba(): pass
        """
        let list = symbols(source, .python)
        XCTAssertEqual(list.map(\.line), [2, 4, 7])
    }

    /// Offset trỏ đúng đầu định nghĩa để con nháy nhảy tới nơi.
    func testOffsetPointsAtTheDefinition() {
        let source = "def mot(): pass\ndef hai(): pass\n"
        let list = symbols(source, .python)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].offset, 0)
        XCTAssertEqual(list[1].offset, source.distance(
            from: source.startIndex, to: source.range(of: "def hai")!.lowerBound
        ))
    }

    /// File quá lớn thì NÓI RA là không dựng, không để người dùng chờ vô hạn.
    func testTooLargeFileSaysSo() {
        var text = ""
        while text.utf8.count <= DocumentOutline.sizeLimit { text += "def f(): pass\n" }
        let result = DocumentOutline.symbols(in: TextBuffer(text: text), language: .python)
        XCTAssertTrue(result.tooLarge)
        XCTAssertTrue(result.symbols.isEmpty)
        XCTAssertTrue(result.summary.contains("không dựng danh sách"), result.summary)
    }

    /// Không nhận ra ngôn ngữ thì im lặng, và nói rõ là vì thế.
    func testUnknownLanguage() {
        let result = DocumentOutline.symbols(in: TextBuffer(text: "xin chào"), language: nil)
        XCTAssertTrue(result.symbols.isEmpty)
        XCTAssertFalse(result.tooLarge)
        XCTAssertTrue(result.summary.contains("Không nhận ra"), result.summary)
    }

    /// Function List là cách NHÌN: nó không đụng vào tài liệu.
    func testNeverTouchesTheDocument() {
        let source = "def mot(): pass\n"
        let buffer = TextBuffer(text: source)
        let depth = buffer.undoDepth
        _ = DocumentOutline.symbols(in: buffer, language: .python)
        XCTAssertEqual(buffer.text, source)
        XCTAssertEqual(buffer.undoDepth, depth)
    }

    /// File hỏng cú pháp vẫn phải ra được phần đọc được — tree-sitter phục hồi lỗi.
    ///
    /// Người dùng mở Function List ĐÚNG LÚC mã đang dở dang; im lặng vì một dấu ngoặc thiếu
    /// là bỏ rơi họ ở chỗ cần nhất.
    func testBrokenSyntaxStillYieldsWhatItCan() {
        let source = """
        def mot():
            return 1

        def hai(:
        """
        let found = names(source, .python)
        XCTAssertTrue(found.contains("mot"), "\(found)")
    }
}
