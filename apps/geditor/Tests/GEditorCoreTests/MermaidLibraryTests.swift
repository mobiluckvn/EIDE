import XCTest
@testable import GEditorCore

/// FR-MMD-005 — thư viện mẫu, mẩu cú pháp và gợi ý.
final class MermaidLibraryTests: XCTestCase {

    // MARK: - Mẫu

    /// Mỗi loại FR-MMD-001 kê tên phải có ĐÚNG một mẫu đầy đủ.
    func testDUMOTMAUChoMoiLoaiDacTaKe() {
        for kind in MermaidDiagramKind.named {
            let full = MermaidLibrary.diagramTemplates.filter { $0.kind == kind }
            XCTAssertEqual(full.count, 1, "loại \(kind.keyword) có \(full.count) mẫu đầy đủ")
        }
        XCTAssertEqual(MermaidLibrary.diagramTemplates.count, 11)
    }

    /// Mẫu phải PHÂN TÍCH RA đúng loại nó khai.
    ///
    /// Đây là bài kiểm đáng giá nhất của thư viện: một mẫu gõ nhầm từ khoá vẫn trông đúng trong
    /// mã nguồn, và chỉ lộ ra khi người dùng chèn nó rồi thấy mermaid báo lỗi.
    func testMAUPhanTichRaDungLoaiNoKhai() {
        for template in MermaidLibrary.diagramTemplates {
            guard let declaration = MermaidDocument.declaration(in: template.source) else {
                return XCTFail("mẫu «\(template.title)» không có dòng khai báo")
            }
            XCTAssertEqual(
                MermaidDiagramKind.from(declaration: declaration), template.kind,
                "mẫu «\(template.title)» khai \(declaration)")
        }
    }

    /// Nhãn trong mẫu là TIẾNG VIỆT — đặc tả đòi "có bản tiếng Việt".
    ///
    /// Kiểm bằng dấu tiếng Việt: một mẫu toàn `Start`/`End` sẽ không có ký tự nào trong tập này.
    func testMAUCoNHANTiengViet() {
        let vietnamese = CharacterSet(charactersIn:
            "ăâđêôơưàảãạáằẳẵặắầẩẫậấèẻẽẹéềểễệếìỉĩịíòỏõọóồổỗộốờởỡợớùủũụúừửữựứỳỷỹỵý"
            + "ĂÂĐÊÔƠƯÀẢÃẠÁẰẲẴẶẮẦẨẪẬẤÈẺẼẸÉỀỂỄỆẾÌỈĨỊÍÒỎÕỌÓỒỔỖỘỐỜỞỠỢỚÙỦŨỤÚỪỬỮỰỨỲỶỸỴÝ")
        for template in MermaidLibrary.diagramTemplates {
            XCTAssertTrue(
                template.source.unicodeScalars.contains(where: vietnamese.contains),
                "mẫu «\(template.title)» không có nhãn tiếng Việt nào")
            XCTAssertFalse(template.title.isEmpty)
            XCTAssertFalse(template.summary.isEmpty, "mẫu «\(template.title)» thiếu mô tả")
        }
    }

    /// Từ khoá thì KHÔNG dịch — dịch chúng là sinh ra một tệp không chạy.
    func testTUKHOAKhongBiDich() {
        let flowchart = MermaidLibrary.diagramTemplates.first { $0.kind == .flowchart }
        XCTAssertTrue(flowchart?.source.hasPrefix("flowchart") ?? false)
        let sequence = MermaidLibrary.diagramTemplates.first { $0.kind == .sequence }
        XCTAssertTrue(sequence?.source.contains("participant") ?? false)
    }

    func testMAUCUPHAPLaMAU_KhongPhaiCaSoDo() {
        XCTAssertFalse(MermaidLibrary.fragments.isEmpty)
        for fragment in MermaidLibrary.fragments {
            XCTAssertEqual(fragment.scope, .fragment)
            // Mẩu KHÔNG được mang dòng khai báo: chèn nó vào giữa một sơ đồ đang có sẽ thành
            // hai dòng khai báo trong một khối, và mermaid từ chối cả khối.
            let first = fragment.source.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")[0]
            XCTAssertNotEqual(
                MermaidDiagramKind.from(declaration: first), fragment.kind,
                "mẩu «\(fragment.title)» mở đầu bằng một dòng khai báo")
        }
    }

    func testLOCTHEOLOAI() {
        let flowchart = MermaidLibrary.templates(for: .flowchart)
        XCTAssertTrue(flowchart.count >= 2, "phải có cả mẫu đầy đủ lẫn mẩu cú pháp")
        XCTAssertTrue(flowchart.allSatisfy { $0.kind == .flowchart })
        XCTAssertTrue(MermaidLibrary.templates(for: .other("sankey-beta")).isEmpty)
    }

    // MARK: - Từ khoá

    func testTUKHOATheoLoai() {
        XCTAssertTrue(MermaidLibrary.keywords(for: .sequence).contains("participant"))
        XCTAssertTrue(MermaidLibrary.keywords(for: .gantt).contains("dateFormat"))
        XCTAssertFalse(MermaidLibrary.keywords(for: .pie).contains("participant"))
        // Từ khoá CHUNG có ở mọi loại.
        for kind in MermaidDiagramKind.named {
            XCTAssertTrue(MermaidLibrary.keywords(for: kind).contains("title"), "\(kind)")
        }
    }

    /// Loại LẠ vẫn có phần chung — ít hơn, nhưng không phải không có gì.
    func testLOAILAVanCoTuKhoaChung() {
        let keywords = MermaidLibrary.keywords(for: .other("sankey-beta"))
        XCTAssertEqual(Set(keywords), Set(MermaidLibrary.commonKeywords))
    }

    // MARK: - Tên node

    func testTENNODECuaLuuDo() {
        let names = MermaidLibrary.nodeNames(in: """
            flowchart TD
              KhachHang[Khách hàng đặt hàng] --> KiemTra{Còn hàng?}
              KiemTra -->|Còn| GiaoHang[Giao hàng]
              KiemTra -->|Hết| BaoKhach[Báo khách]
            """)
        XCTAssertEqual(
            Set(names), ["KhachHang", "KiemTra", "GiaoHang", "BaoKhach"],
            "\(names)")
    }

    /// Chữ TRONG nhãn là văn xuôi, không phải tên node.
    ///
    /// Gợi ý tên node mà trả về "Khách" và "hàng" thì danh sách đầy những từ người dùng vừa gõ
    /// xong ở dòng trên — đúng thứ mà gợi ý theo TỪ trong tài liệu đã làm rồi.
    func testCHUTRONGNHANKhongPhaiTenNode() {
        let names = MermaidLibrary.nodeNames(in: """
            flowchart LR
              A[Nhận hồ sơ đầy đủ] --> B
            """)
        XCTAssertEqual(Set(names), ["A", "B"], "\(names)")
    }

    func testTENNODECuaTuanTu() {
        let names = MermaidLibrary.nodeNames(in: """
            sequenceDiagram
              actor ND as Người dùng
              participant App
              participant CSDL as Cơ sở dữ liệu
              ND->>App: Gửi yêu cầu rất dài
              App-->>ND: Trả kết quả
            """)
        // `as` là từ khoá nên bị loại; phần sau dấu `:` là chữ nên bị cắt.
        XCTAssertTrue(names.contains("ND"), "\(names)")
        XCTAssertTrue(names.contains("App"), "\(names)")
        XCTAssertTrue(names.contains("CSDL"), "\(names)")
        XCTAssertFalse(names.contains("as"), "\(names)")
        XCTAssertFalse(names.contains("Gửi"), "phần sau dấu hai chấm là chữ: \(names)")
    }

    func testTENTHUCTHECuaER() {
        let names = MermaidLibrary.nodeNames(in: """
            erDiagram
              KHACH_HANG ||--o{ DON_HANG : "đặt"
              DON_HANG ||--|{ DONG_HANG : "gồm"
            """)
        XCTAssertEqual(Set(names), ["KHACH_HANG", "DON_HANG", "DONG_HANG"], "\(names)")
    }

    func testMUITENKhongPhaiTenNode() {
        let names = MermaidLibrary.nodeNames(in: "flowchart TD\n  A-->B\n  B---C\n  C-.->D")
        XCTAssertEqual(Set(names), ["A", "B", "C", "D"], "\(names)")
    }

    func testCHUTHICHBiBoQua() {
        let names = MermaidLibrary.nodeNames(in: """
            %% ThuVienBiMat không phải node
            flowchart TD
              A --> B
            """)
        XCTAssertFalse(names.contains("ThuVienBiMat"), "\(names)")
    }

    /// Gợi ý = tên node TRƯỚC, từ khoá SAU.
    ///
    /// `CompletionEngine` giữ thứ tự khi điểm bằng nhau, nên thứ tự ở đây quyết định thứ người
    /// dùng thấy trước: tên của chính tài liệu đáng hiện trên một từ khoá của loại sơ đồ khác.
    func testGOIYDatTenNodeTruocTuKhoa() {
        let words = MermaidLibrary.completionWords(in: """
            flowchart TD
              KhachHang --> KiemTra
            """)
        guard let node = words.firstIndex(of: "KhachHang"),
              let keyword = words.firstIndex(of: "subgraph") else {
            return XCTFail("thiếu tên node hoặc từ khoá: \(words)")
        }
        XCTAssertTrue(node < keyword)
        // Và từ khoá phải là của ĐÚNG loại sơ đồ ấy.
        XCTAssertFalse(words.contains("participant"), "\(words)")
    }

    func testGOIYKhuTrung() {
        let words = MermaidLibrary.completionWords(in: "flowchart TD\n  title --> title")
        XCTAssertEqual(words.filter { $0 == "title" }.count, 1)
    }
}

/// FR-MMD-002 — chữ đại diện cho phần tử mà một dòng mã nói tới.
final class MermaidFocusTests: XCTestCase {

    /// `A[Nhận hồ sơ]` vẽ ra chữ «Nhận hồ sơ», nên nhãn phải đứng TRƯỚC định danh: khớp được
    /// nhãn là khớp đúng phần tử.
    func testNHANDungTruocDinhDanh() {
        let words = MermaidLibrary.focusWords(
            inLine: "  A[Nhận hồ sơ] --> B{Đủ giấy tờ?}", kind: .flowchart)
        XCTAssertEqual(words.prefix(2).sorted(), ["Nhận hồ sơ", "Đủ giấy tờ?"].sorted())
        XCTAssertTrue(words.contains("A"))
        XCTAssertTrue(words.contains("B"))
        guard let label = words.firstIndex(of: "Nhận hồ sơ"),
              let name = words.firstIndex(of: "A") else { return XCTFail("\(words)") }
        XCTAssertTrue(label < name)
    }

    /// Dòng KHÔNG có nhãn thì chính định danh là chữ hiện trên hình.
    func testDONGKHONGCoNhanThiLayDinhDanh() {
        XCTAssertEqual(
            MermaidLibrary.focusWords(inLine: "  A --> B", kind: .flowchart), ["A", "B"])
    }

    func testNHANTrongNhayKep() {
        XCTAssertTrue(
            MermaidLibrary.focusWords(inLine: "  A[\"Nhãn có, dấu phẩy\"]", kind: .flowchart)
                .contains("Nhãn có, dấu phẩy"))
    }

    /// Nhãn trên CẠNH (`-->|đúng|`) cũng là chữ hiện trên hình.
    func testNHANTrenCanh() {
        XCTAssertTrue(
            MermaidLibrary.focusWords(inLine: "  B -->|đúng| C", kind: .flowchart)
                .contains("đúng"))
    }

    func testDONGCHUTHICHKhongCoGiDeToSang() {
        XCTAssertTrue(MermaidLibrary.focusWords(inLine: "  %% ghi chú", kind: .flowchart).isEmpty)
        XCTAssertTrue(MermaidLibrary.focusWords(inLine: "   ", kind: .flowchart).isEmpty)
    }

    /// Thông điệp của sequence là CHỮ trên mũi tên, và tên hai bên là chữ trên hai cột.
    func testDONGTUANTU() {
        let words = MermaidLibrary.focusWords(
            inLine: "  ND->>App: Gửi yêu cầu", kind: .sequence)
        XCTAssertTrue(words.contains("ND"), "\(words)")
        XCTAssertTrue(words.contains("App"), "\(words)")
    }

    func testKHUTRUNG() {
        XCTAssertEqual(
            MermaidLibrary.focusWords(inLine: "  A --> A", kind: .flowchart), ["A"])
    }
}
