import XCTest
@testable import GEditorCore

/// Mô hình View / Code — nguồn sự thật duy nhất cho lệnh đổi chế độ và cho trang trợ giúp.
final class DisplayModeTests: XCTestCase {

    private func modes(_ path: String, _ kind: MediaKind? = nil, _ language: SyntaxLanguage? = nil)
        -> DisplayModes {
        DisplayModes.of(path: path, kind: kind, language: language)
    }

    // MARK: - Tệp nhị phân: Code là BYTE, không phải "không có"

    func testTEPnhiPHANcoCODEvaCODElaBYTE() {
        // Nói "loại này không có Code" thì tiện hơn nhưng sai: byte đúng là nguồn của chúng.
        for kind in [MediaKind.pdf, .image, .audio, .video, .archive] {
            XCTAssertEqual(modes("a.bin", kind).code, .binary, "\(kind)")
        }
    }

    func testPDFsuaDUOCngayOview() {
        // Chú thích, ô biểu mẫu, thao tác trang — tất cả xảy ra ở View.
        XCTAssertEqual(modes("a.pdf", .pdf), DisplayModes(view: .document, code: .binary, editing: .both))
    }

    func testANHvaNHACvaPHIMlaCHIdoc() {
        for kind in [MediaKind.image, .audio, .video, .archive] {
            XCTAssertEqual(modes("a", kind).editing, .readOnly, "\(kind)")
        }
    }

    // MARK: - Bảng

    func testCSVsuaDUOCcaHAIche() {
        let csv = modes("bang.csv")
        XCTAssertEqual(csv.view, .table)
        XCTAssertEqual(csv.code, .source)
        XCTAssertEqual(csv.editing, .both, "ô bảng CSV sửa thẳng được — đó là ngoại lệ có chủ ý")
    }

    func testEXCELraBANGvaCODElaCSVcuaSHEET() {
        let xlsx = modes("bang.xlsx", .excel)
        XCTAssertEqual(xlsx.view, .table)
        XCTAssertEqual(xlsx.code, .source, "Code của Excel là CSV của sheet, không phải byte")
        XCTAssertEqual(xlsx.editing, .both)
    }

    // MARK: - Loại media thắng đuôi tệp

    func testLOAImediaQUYETdinhTRUOCduoiTEP() {
        // Một tệp `.json` nằm trong tệp nén thì thứ đang xem là TỆP NÉN.
        XCTAssertEqual(modes("goi.json", .archive).view, .archiveList)
        XCTAssertEqual(modes("anh.csv", .image).view, .image)
    }

    // MARK: - Văn bản có cấu trúc

    func testMARKDOWNvaBAOCAOtachNHAU() {
        XCTAssertEqual(modes("ghi-chu.md").view, .renderedText)
        XCTAssertEqual(modes("thang-8.greport.md").view, .report,
                       "`.greport.md` chạy truy vấn và vẽ biểu đồ — khác hẳn Markdown thường")
    }

    func testJSONvaXMLvaYAMLdeuRAcay() {
        XCTAssertEqual(modes("a.json", nil, .json).view, .tree)
        XCTAssertEqual(modes("a.xml", nil, .xml).view, .tree)
        XCTAssertEqual(modes("a.yaml", nil, .yaml).view, .tree)
    }

    func testSOdoVAlogNHANdungCHEdo() {
        XCTAssertEqual(modes("so-do.mmd").view, .diagram)
        XCTAssertEqual(modes("do-thi.dot").view, .diagram)
        XCTAssertEqual(modes("nhat-ky.log").view, .logLevels)
    }

    // MARK: - Không có View là chuyện BÌNH THƯỜNG

    func testMAnguonKHONGcoVIEWvaDOlaDUNG() {
        // Một tệp Swift không có "bản dựng ra" nào đáng xem. Đây không phải thiếu sót.
        let swiftFile = modes("Main.swift", nil, .rust)
        XCTAssertEqual(swiftFile.view, .none)
        XCTAssertFalse(swiftFile.canToggle)
        XCTAssertEqual(modes("ghi-chu.txt").view, .none)
    }

    // MARK: - Danh sách "đã dựng được" phải THẬT

    func testDANHsachCHUAdungDUOClaDUNGbaCAIayVAkhongTHEMcaiNAO() {
        // Bài này từng chứng minh cờ "đã dựng được" phải nằm ở TỪNG LOẠI TỆP chứ không nằm trên
        // kiểu View, bằng cặp JSON (đã dựng) và XML (chưa) — hai thứ cùng là `.tree`. Cặp ấy
        // KHÔNG CÒN: cả ba cây khoá–giá trị nay đều dựng xong. Không bịa một cặp khác cho có;
        // cờ vẫn nằm ở từng loại tệp vì chế độ View tiếp theo sẽ dựng lại đúng tình huống ấy.
        //
        // Thứ còn kiểm được, và đáng kiểm hơn: danh sách "chưa dựng" phải ĐÚNG BẰNG những cái
        // đang thiếu thật. Cả hai chiều — thêm một bộ dựng mà quên hạ cờ thì lệnh đổi chế độ
        // vẫn từ chối; hạ cờ mà chưa dựng thì người dùng bấm vào một khung trống.
        // Danh sách nay RỖNG: mọi loại tệp có chỗ cho một chế độ View đều đã dựng. Giữ bài lại
        // vì nó canh cả hai chiều — thêm một loại tệp mới mà quên dựng View thì phải thêm tên nó
        // vào đây, và cái tên ấy là lời nhắc rằng trang trợ giúp cũng phải nói ra.
        let chuaDung = Set<String>()
        let mau: [(String, MediaKind?, SyntaxLanguage?)] = [
            ("a.json", nil, .json), ("a.xml", nil, .xml), ("a.yaml", nil, .yaml),
            ("a.csv", nil, nil), ("a.md", nil, nil), ("a.log", nil, nil),
            ("a.pdf", .pdf, nil), ("a.png", .image, nil), ("a.mp4", .video, nil),
            ("a.zip", .archive, nil), ("a.xlsx", .excel, nil), ("a.docx", .word, nil),
            ("so-do.mmd", nil, nil), ("do-thi.dot", nil, nil), ("slide.pptx", .powerpoint, nil),
        ]
        for (path, kind, language) in mau {
            let m = modes(path, kind, language)
            XCTAssertEqual(m.canToggle, !chuaDung.contains(path),
                           "«\(path)» khai là \(m.canToggle ? "đổi được" : "chưa dựng") — sai")
        }
    }

    func testKHONGcoVIEWvaCHUAdungVIEWlaHAIchuyenKHACnhau() {
        // Hai lý do cùng cho `canToggle == false` nhưng nói hai điều khác hẳn nhau, và câu lệnh
        // từ chối phải phân biệt được: "loại này không có View" là bình thường, còn "View của
        // loại này chưa dựng" là một món nợ. Nay không còn món nợ nào — chỉ còn vế thứ nhất.
        let maNguon = modes("Main.swift")
        XCTAssertEqual(maNguon.view, .none, "mã nguồn không có View")
        XCTAssertFalse(maNguon.canToggle)

        for (path, kind) in [("so-do.mmd", nil), ("do-thi.dot", nil),
                             ("slide.pptx", MediaKind.powerpoint)] {
            let m = modes(path, kind)
            XCTAssertNotEqual(m.view, .none, "\(path) CÓ chỗ cho một chế độ View")
            XCTAssertTrue(m.canToggle, "\(path) đã dựng View rồi — phải đổi được")
        }
    }

    func testNHUNGcheDOdaCOthiPHAIdoiDUOC() {
        for (path, kind) in [("a.csv", nil), ("a.md", nil), ("a.log", nil),
                             ("a.pdf", MediaKind.pdf), ("a.png", .image),
                             ("a.mp4", .video), ("a.zip", .archive),
                             ("a.xlsx", .excel), ("a.docx", .word)] {
            XCTAssertTrue(modes(path, kind).canToggle, "\(path) đang khai là chưa đổi được")
        }
    }

    func testMOIloaiMEDIAdeuCOmotCAPcheDO() {
        // Thêm một `MediaKind` mà quên khai ở đây thì `switch` trong `of(path:kind:language:)`
        // không biên dịch được — nhưng bài này giữ thêm vế "không loại nào rơi vào .none".
        for kind in MediaKind.allCases {
            let m = modes("tep", kind)
            XCTAssertNotEqual(m.view, .none, "\(kind) không có chế độ View nào")
        }
    }
}
