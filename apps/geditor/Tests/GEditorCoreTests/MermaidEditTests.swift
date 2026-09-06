import XCTest
@testable import GEditorCore

/// Soạn thảo sơ đồ Mermaid trực quan — FR-MMD-004.
final class MermaidEditTests: XCTestCase {

    private func apply(_ edits: [TextEdit], to text: String) -> String {
        var b = TextBuffer(text: text)
        b.applyEdits(edits, label: "t")
        return b.text
    }

    // MARK: - Mức hỗ trợ

    /// Đặc tả kê đích danh loại nào soạn được bằng thao tác nào; bảng này là chính câu ấy.
    func testMucHoTroDungTheoDacTa() {
        XCTAssertEqual(MermaidEdit.support(for: .flowchart), .nodesAndEdges)
        XCTAssertEqual(MermaidEdit.support(for: .state), .nodesAndEdges)
        XCTAssertEqual(MermaidEdit.support(for: .classDiagram), .nodesAndEdges)
        XCTAssertEqual(MermaidEdit.support(for: .entityRelationship), .nodesAndEdges)
        XCTAssertEqual(MermaidEdit.support(for: .sequence), .sequence)
        XCTAssertEqual(MermaidEdit.support(for: .gantt), .propertyTable)
        XCTAssertEqual(MermaidEdit.support(for: .pie), .propertyTable)
    }

    /// Loại chưa làm phải NÓI RA lý do — đặc tả đòi *"hiển thị rõ 'chỉ soạn text'"*.
    ///
    /// Một tính năng im lặng không làm gì khi người dùng kéo trên `mindmap` là cách chắc chắn
    /// nhất khiến họ nghĩ công cụ hỏng.
    func testLoaiChuaLamNOIRAlyDo() {
        for kind in [MermaidDiagramKind.mindmap, .timeline, .quadrant, .gitGraph,
                     .other("sankey")] {
            guard case let .textOnly(reason) = MermaidEdit.support(for: kind) else {
                return XCTFail("\(kind) đáng lẽ chỉ soạn text")
            }
            XCTAssertFalse(reason.isEmpty, "\(kind) không nói lý do")
            XCTAssertFalse(MermaidEdit.support(for: kind).isVisual)
        }
    }

    func testKeoTrenLoaiChuaLamThiTUCHOIkemLyDo() {
        let src = "mindmap\n  root((ý chính))\n    nhánh một\n"
        XCTAssertThrowsError(try MermaidEdit.addNode(id: "x", in: src)) { e in
            XCTAssertTrue("\(e)".contains("chỉ soạn text"), "\(e)")
        }
    }

    // MARK: - flowchart

    private let flow = """
    flowchart TD
        %% chú thích của người dùng
        A["Nhận hồ sơ"] --> B["Duyệt hồ sơ"]
        B --> C["Trả kết quả"]
    """

    func testDocFlowchart() {
        let m = MermaidEdit.parse(flow)
        XCTAssertEqual(m.kind, .flowchart)
        XCTAssertEqual(m.nodes.map(\.id), ["A", "B", "C"])
        XCTAssertEqual(m.node("A")?.label, "Nhận hồ sơ")
        XCTAssertEqual(m.node("B")?.label, "Duyệt hồ sơ")
        XCTAssertEqual(m.edges.count, 2)
    }

    /// Nhãn CÓ mũi tên bên trong không được cắt đôi dòng.
    func testMuiTenTRONGnhanKhongLamVoDong() {
        let m = MermaidEdit.parse("flowchart LR\n    A[\"a --> b\"]\n")
        XCTAssertTrue(m.edges.isEmpty, "\(m.edges)")
        XCTAssertEqual(m.node("A")?.label, "a --> b")
    }

    /// Dạng `A -- nhãn --> B`: nhãn nằm GIỮA hai mũi tên. Không xử riêng thì node đích thành
    /// «nhãn --> B».
    func testNhanNamGIUAhaiMuiTen() {
        let m = MermaidEdit.parse("flowchart LR\n    A -- đạt --> B\n")
        XCTAssertEqual(m.edges.first?.from, "A")
        XCTAssertEqual(m.edges.first?.to, "B")
        XCTAssertEqual(m.edges.first?.label, "đạt")
    }

    func testNhanTrongCapGachDung() {
        let m = MermaidEdit.parse("flowchart LR\n    A -->|đạt| B\n")
        XCTAssertEqual(m.edges.first?.label, "đạt")
        XCTAssertEqual(m.edges.first?.to, "B")
    }

    func testThemNodeGiuThutLeVaChuThich() throws {
        let ra = apply(try MermaidEdit.addNode(id: "D", label: "Lưu trữ", in: flow), to: flow)
        XCTAssertTrue(ra.contains("    D[\"Lưu trữ\"]"), ra)
        XCTAssertTrue(ra.contains("%% chú thích của người dùng"), ra)
        XCTAssertEqual(MermaidEdit.parse(ra).nodes.count, 4)
    }

    func testThemCanh() throws {
        let sau = apply(try MermaidEdit.addNode(id: "D", in: flow), to: flow)
        let ra = apply(try MermaidEdit.addEdge(from: "C", to: "D", label: "xong", in: sau),
                       to: sau)
        let m = MermaidEdit.parse(ra)
        XCTAssertEqual(m.edges.count, 3)
        XCTAssertTrue(m.edges.contains { $0.from == "C" && $0.to == "D" && $0.label == "xong" })
    }

    func testThemCanhToiNodeKhongCoBiTUCHOI() {
        XCTAssertThrowsError(try MermaidEdit.addEdge(from: "A", to: "ZZZ", in: flow)) { e in
            XCTAssertTrue("\(e)".contains("ZZZ"), "\(e)")
        }
    }

    func testThemNodeTrungBiTUCHOI() {
        XCTAssertThrowsError(try MermaidEdit.addNode(id: "A", in: flow))
    }

    func testDinhDanhCoKyTuCoNghiaBiTUCHOI() {
        for id in ["a b", "a-b", "a[b", "a:b", ""] {
            XCTAssertThrowsError(try MermaidEdit.addNode(id: id, in: flow), id)
        }
    }

    func testDoiNhanFlowchartThayDUNGchoNhanCu() throws {
        let ra = apply(try MermaidEdit.setLabel(of: "A", to: "Tiếp nhận", in: flow), to: flow)
        XCTAssertTrue(ra.contains("A[\"Tiếp nhận\"]"), ra)
        XCTAssertFalse(ra.contains("Nhận hồ sơ"), ra)
        // Cạnh KHÔNG bị đụng.
        XCTAssertEqual(MermaidEdit.parse(ra).edges.count, 2)
    }

    /// Node chỉ xuất hiện trong cạnh và CHƯA có nhãn → thêm hẳn một dòng khai.
    func testDoiNhanNodeChuaCoNhan() throws {
        let src = "flowchart LR\n    A --> B\n"
        let ra = apply(try MermaidEdit.setLabel(of: "B", to: "Đích", in: src), to: src)
        XCTAssertEqual(MermaidEdit.parse(ra).node("B")?.label, "Đích", ra)
    }

    /// Bỏ sót phần cạnh là để lại cạnh treo — mermaid tự sinh lại node từ chính những cạnh ấy,
    /// nên node "đã xoá" hiện lại ngay lượt vẽ sau.
    func testXoaNodeXoaLuonMoiCanhChamToiNo() throws {
        let ra = apply(try MermaidEdit.removeNode("B", in: flow), to: flow)
        let m = MermaidEdit.parse(ra)
        XCTAssertFalse(m.nodes.contains { $0.id == "B" }, "node quay lại:\n\(ra)")
        XCTAssertTrue(m.edges.isEmpty, "còn cạnh treo:\n\(ra)")
        XCTAssertTrue(ra.contains("A["), "xoá nhầm node khác:\n\(ra)")
    }

    func testXoaCanhKhongDungNodeHaiDau() throws {
        let ra = apply(try MermaidEdit.removeEdge(from: "A", to: "B", in: flow), to: flow)
        let m = MermaidEdit.parse(ra)
        XCTAssertEqual(m.edges.count, 1)
        XCTAssertEqual(m.nodes.count, 3, "node hai đầu bị xoá theo:\n\(ra)")
    }

    /// Mermaid cho khai node NGAY TRONG câu lệnh cạnh, nên xoá cạnh có thể xoá luôn hai node ở
    /// hai đầu — trong khi người dùng chỉ bấm "xoá cạnh" và vẫn đang nhìn hai node ấy.
    ///
    /// Khác biệt thật so với DOT, nơi node hầu như luôn có câu lệnh khai riêng. Và **nhãn phải
    /// đi theo**: khai lại mà mất nhãn thì node "vẫn còn" nhưng đổi tên trước mắt người dùng.
    func testXoaCanhGiuLaiNodeChiKhaiTrongChinhDongAy() throws {
        let src = "flowchart LR\n    A[\"Nhận hồ sơ\"] --> B[\"Duyệt\"]\n"
        let ra = apply(try MermaidEdit.removeEdge(from: "A", to: "B", in: src), to: src)
        let m = MermaidEdit.parse(ra)
        XCTAssertTrue(m.edges.isEmpty, ra)
        XCTAssertEqual(Set(m.nodes.map(\.id)), ["A", "B"], "node hai đầu biến mất:\n\(ra)")
        XCTAssertEqual(m.node("A")?.label, "Nhận hồ sơ", "khai lại mà mất nhãn:\n\(ra)")
        XCTAssertEqual(m.node("B")?.label, "Duyệt", ra)
    }

    /// Nhưng node CÒN cạnh khác, hoặc đã có dòng khai riêng, thì KHÔNG được khai lại lần nữa.
    func testKhongKhaiLaiNodeVanConSong() throws {
        let ra = apply(try MermaidEdit.removeEdge(from: "A", to: "B", in: flow), to: flow)
        let m = MermaidEdit.parse(ra)
        XCTAssertEqual(m.nodes.count, 3, ra)
        XCTAssertEqual(ra.components(separatedBy: "B").count - 1,
                       flow.components(separatedBy: "B").count - 2, "B bị khai lại thừa:\n\(ra)")
    }

    /// Nội dung `subgraph` vẫn phải đọc được — nó là phần thân của lưu đồ, không phải chú thích.
    func testNodeTrongSubgraphVanDocDuoc() {
        let src = """
        flowchart TD
            subgraph Nhóm
                A --> B
            end
            B --> C
        """
        let m = MermaidEdit.parse(src)
        XCTAssertEqual(Set(m.nodes.map(\.id)), ["A", "B", "C"])
        XCTAssertEqual(m.edges.count, 2)
    }

    // MARK: - state

    private let state = """
    stateDiagram-v2
        [*] --> ChoDuyet
        ChoDuyet : Chờ duyệt
        ChoDuyet --> DaDuyet : đạt
    """

    func testDocState() {
        let m = MermaidEdit.parse(state)
        XCTAssertEqual(m.kind, .state)
        XCTAssertEqual(m.node("ChoDuyet")?.label, "Chờ duyệt")
        XCTAssertTrue(m.edges.contains { $0.from == "ChoDuyet" && $0.label == "đạt" })
    }

    func testDoiNhanState() throws {
        let ra = apply(try MermaidEdit.setLabel(of: "ChoDuyet", to: "Đang chờ", in: state),
                       to: state)
        XCTAssertEqual(MermaidEdit.parse(ra).node("ChoDuyet")?.label, "Đang chờ", ra)
        XCTAssertEqual(MermaidEdit.parse(ra).edges.count, 2, ra)
    }

    func testDocStateDangCoAs() {
        let m = MermaidEdit.parse("stateDiagram-v2\n    state \"Chờ duyệt\" as s1\n")
        XCTAssertEqual(m.node("s1")?.label, "Chờ duyệt")
    }

    // MARK: - classDiagram

    private let cls = """
    classDiagram
        class HoSo
        class NguoiDuyet
        HoSo --> NguoiDuyet : gửi tới
        HoSo : +String maSo
    """

    func testDocClass() {
        let m = MermaidEdit.parse(cls)
        XCTAssertEqual(m.kind, .classDiagram)
        XCTAssertEqual(Set(m.nodes.map(\.id)), ["HoSo", "NguoiDuyet"])
        XCTAssertEqual(m.edges.count, 1)
    }

    /// Dòng THÀNH VIÊN nhắc tên lớp nhưng không khai lớp — nhãn của nó không phải nhãn lớp.
    func testDongThanhVienKhongPhaiDongKhaiLop() {
        let m = MermaidEdit.parse(cls)
        XCTAssertEqual(m.node("HoSo")?.declLine, 1, "dòng khai phải là `class HoSo`")
        XCTAssertNil(m.node("HoSo")?.label)
    }

    /// Thân `class Foo { … }` là THÀNH VIÊN, không phải node — không bỏ qua thì mỗi thuộc tính
    /// thành một node ma.
    func testThanhVienTrongKhoiKhongThanhNode() {
        let src = """
        classDiagram
            class HoSo {
                +String maSo
                +duyet()
            }
        """
        XCTAssertEqual(MermaidEdit.parse(src).nodes.map(\.id), ["HoSo"])
    }

    func testXoaNodeClassXoaLuonQuanHe() throws {
        let ra = apply(try MermaidEdit.removeNode("NguoiDuyet", in: cls), to: cls)
        let m = MermaidEdit.parse(ra)
        XCTAssertFalse(m.nodes.contains { $0.id == "NguoiDuyet" }, ra)
        XCTAssertTrue(m.edges.isEmpty, ra)
    }

    // MARK: - erDiagram

    private let er = """
    erDiagram
        KHACH ||--o{ DONHANG : "đặt"
        DONHANG {
            string maSo
        }
    """

    func testDocER() {
        let m = MermaidEdit.parse(er)
        XCTAssertEqual(m.kind, .entityRelationship)
        XCTAssertEqual(Set(m.nodes.map(\.id)), ["KHACH", "DONHANG"])
        XCTAssertEqual(m.edges.first?.from, "KHACH")
        XCTAssertEqual(m.edges.first?.to, "DONHANG")
        XCTAssertEqual(m.edges.first?.label, "đặt")
    }

    func testThuocTinhERkhongThanhThucThe() {
        XCTAssertEqual(Set(MermaidEdit.parse(er).nodes.map(\.id)), ["KHACH", "DONHANG"])
    }

    /// erDiagram đòi nhãn quan hệ — thiếu nó thì mermaid không vẽ.
    func testCanhERluonCoNhan() throws {
        let ra = apply(try MermaidEdit.addEdge(from: "DONHANG", to: "KHACH", in: er), to: er)
        XCTAssertNotNil(MermaidEdit.parse(ra).edges.last?.label, ra)
    }

    // MARK: - sequence

    private let seq = """
    sequenceDiagram
        participant A as Người gửi
        participant B as Người nhận
        A->>B: chào
        B-->>A: chào lại
    """

    func testDocSequence() {
        let m = MermaidEdit.parse(seq)
        XCTAssertEqual(m.kind, .sequence)
        XCTAssertEqual(m.node("A")?.label, "Người gửi")
        XCTAssertEqual(m.edges.count, 2)
        XCTAssertEqual(m.edges.first?.label, "chào")
    }

    func testThemParticipant() throws {
        let ra = apply(try MermaidEdit.addNode(id: "C", label: "Người thứ ba", in: seq), to: seq)
        XCTAssertTrue(ra.contains("participant C as Người thứ ba"), ra)
        XCTAssertEqual(MermaidEdit.parse(ra).nodes.count, 3)
    }

    func testThemMessage() throws {
        let ra = apply(try MermaidEdit.addEdge(from: "B", to: "A", label: "hỏi lại", in: seq),
                       to: seq)
        let m = MermaidEdit.parse(ra)
        XCTAssertEqual(m.edges.count, 3)
        XCTAssertEqual(m.edges.last?.label, "hỏi lại", ra)
    }

    /// ĐỔI CHỖ hai dòng, không chèn-rồi-xoá: chèn-rồi-xoá đi qua một trạng thái có hai bản của
    /// cùng một message.
    func testDoiThuTuMessage() throws {
        let m = MermaidEdit.parse(seq)
        let dong = m.edges.map(\.line).sorted()
        let ra = apply(try MermaidEdit.moveMessage(at: dong[1], .up, in: seq), to: seq)
        let sau = MermaidEdit.parse(ra)
        XCTAssertEqual(sau.edges.map(\.label), ["chào lại", "chào"], ra)
        XCTAssertEqual(sau.edges.count, 2, "message bị nhân bản:\n\(ra)")
    }

    func testDoiThuTuOBienBiTUCHOI() {
        let dong = MermaidEdit.parse(seq).edges.map(\.line).sorted()
        XCTAssertThrowsError(try MermaidEdit.moveMessage(at: dong[0], .up, in: seq))
        XCTAssertThrowsError(try MermaidEdit.moveMessage(at: dong[1], .down, in: seq))
    }

    /// Giữ nguyên thụt lề của TỪNG dòng: hai message trong một khối `alt` thụt sâu hơn message
    /// ngoài khối, và đổi cả phần thụt sẽ làm hỏng cấu trúc.
    func testDoiThuTuGiuThutLeCuaTUNGdong() throws {
        let src = """
        sequenceDiagram
            A->>B: một
            alt có
                A->>B: hai
                A->>B: ba
            end
        """
        let m = MermaidEdit.parse(src)
        let hai = m.edges.first { $0.label == "hai" }!.line
        let ra = apply(try MermaidEdit.moveMessage(at: hai, .down, in: src), to: src)
        XCTAssertTrue(ra.contains("        A->>B: ba\n        A->>B: hai"), ra)
    }

    func testDoiThuTuChiCoOSequence() {
        XCTAssertThrowsError(try MermaidEdit.moveMessage(at: 2, .up, in: flow))
    }

    // MARK: - gantt · pie

    private let pie = """
    pie showData
        title Tỉ lệ hồ sơ
        "Đạt" : 386
        "Trượt" : 85
    """

    func testDocPie() {
        let m = MermaidEdit.parse(pie)
        XCTAssertEqual(m.rows.map(\.label), ["Đạt", "Trượt"])
        XCTAssertEqual(m.rows.first?.value, "386")
    }

    /// `title` là cấu hình, không phải một lát bánh.
    func testKhoaCauHinhKhongVaoBang() {
        XCTAssertFalse(MermaidEdit.parse(pie).rows.contains { $0.label.hasPrefix("title") })
    }

    func testSuaDongBangThuocTinh() throws {
        let m = MermaidEdit.parse(pie)
        let ra = apply(
            try MermaidEdit.setRow(at: m.rows[0].line, label: "Đạt yêu cầu", value: "400",
                                   in: pie), to: pie)
        let sau = MermaidEdit.parse(ra)
        XCTAssertEqual(sau.rows[0].label, "Đạt yêu cầu", ra)
        XCTAssertEqual(sau.rows[0].value, "400", ra)
        XCTAssertEqual(sau.rows.count, 2, ra)
    }

    func testThemVaXoaDongBang() throws {
        var ra = apply(try MermaidEdit.addRow(label: "Chờ", value: "12", in: pie), to: pie)
        XCTAssertEqual(MermaidEdit.parse(ra).rows.count, 3, ra)
        let dong = MermaidEdit.parse(ra).rows[1].line
        ra = apply(try MermaidEdit.removeRow(at: dong, in: ra), to: ra)
        XCTAssertEqual(MermaidEdit.parse(ra).rows.map(\.label), ["Đạt", "Chờ"], ra)
    }

    func testGanttGiuSectionCuaTungMuc() {
        let src = """
        gantt
            title Kế hoạch
            dateFormat YYYY-MM-DD
            section Chuẩn bị
            Khảo sát :a1, 2026-01-01, 10d
            section Thi công
            Dựng khung :a2, 2026-02-01, 20d
        """
        let m = MermaidEdit.parse(src)
        XCTAssertEqual(m.rows.map(\.label), ["Khảo sát", "Dựng khung"])
        XCTAssertEqual(m.rows.map(\.section), ["Chuẩn bị", "Thi công"])
        XCTAssertFalse(m.rows.contains { $0.label.lowercased().hasPrefix("dateformat") })
    }

    func testBangThuocTinhKhongApChoFlowchart() {
        XCTAssertThrowsError(try MermaidEdit.addRow(label: "x", value: "1", in: flow))
    }

    // MARK: - Từ hình về định danh

    func testPhanGiaiTheoNhanVaTheoDinhDanh() throws {
        let m = MermaidEdit.parse(flow)
        XCTAssertEqual(try MermaidEdit.resolveNode("Nhận hồ sơ", in: m), "A")
        XCTAssertEqual(try MermaidEdit.resolveNode("A", in: m), "A")
    }

    /// Hai node cùng nhãn thì NÓI RA, không lấy cái đầu tiên — đoán sai ở đây là sửa nhầm node.
    func testHaiNodeCungNhanThiTUCHOIkemTenCaHai() {
        let src = "flowchart LR\n    A[\"Duyệt\"]\n    B[\"Duyệt\"]\n"
        let m = MermaidEdit.parse(src)
        XCTAssertThrowsError(try MermaidEdit.resolveNode("Duyệt", in: m)) { e in
            XCTAssertTrue("\(e)".contains("A"), "\(e)")
            XCTAssertTrue("\(e)".contains("B"), "\(e)")
        }
    }

    // MARK: - Bất biến

    /// Không hàm nào ở đây sửa gì — chúng chỉ TRẢ VỀ sửa đổi. Buffer vẫn là nguồn sự thật duy
    /// nhất, đúng SAD Hình 4.
    func testKhongHamNaoTuSuaVanBan() throws {
        let goc = flow
        _ = try MermaidEdit.addNode(id: "Z", in: flow)
        _ = try MermaidEdit.setLabel(of: "A", to: "X", in: flow)
        _ = try MermaidEdit.removeNode("B", in: flow)
        XCTAssertEqual(flow, goc)
    }

    func testMoiThaoTacLaMOTbuocHoanTac() throws {
        var b = TextBuffer(text: flow)
        b.applyEdits(try MermaidEdit.removeNode("B", in: flow), label: "xoá")
        XCTAssertNotEqual(b.text, flow)
        b.undo()
        XCTAssertEqual(b.text, flow)
    }

    /// Khối chưa đóng thì TỪ CHỐI: chèn vào cuối sẽ rơi VÀO TRONG khối, và câu lệnh mới hiện ra
    /// ở một chỗ người dùng không ngờ.
    func testKhoiChuaDongThiTUCHOI() {
        let src = "classDiagram\n    class Foo {\n        +a()\n"
        XCTAssertThrowsError(try MermaidEdit.addNode(id: "Bar", in: src)) { e in
            XCTAssertTrue("\(e)".contains("chưa đóng"), "\(e)")
        }
    }

    /// Sửa đổi tính theo NGUỒN SƠ ĐỒ, còn buffer chứa cả tài liệu — chỗ đã làm lệch số dòng ở
    /// FR-KNW-905.
    func testDoiSuaDoiVeToaDoTaiLieu() throws {
        let doc = "# Tiêu đề\n\n```mermaid\n" + flow + "\n```\n"
        let block = MermaidDocument.blocks(in: doc)[0]
        let buffer = TextBuffer(text: doc)
        let delta = buffer.offset(ofLineStart: block.firstContentLine)
        let edits = MermaidEdit.shift(
            try MermaidEdit.addNode(id: "D", label: "Lưu", in: block.source), by: delta)
        let ra = apply(edits, to: doc)
        XCTAssertTrue(ra.hasPrefix("# Tiêu đề\n"), ra)
        XCTAssertTrue(ra.hasSuffix("```\n"), ra)
        XCTAssertEqual(MermaidEdit.parse(MermaidDocument.blocks(in: ra)[0].source).nodes.count, 4,
                       ra)
    }

    /// Thụt lề đọc từ CHÍNH sơ đồ, và bỏ qua dòng khai báo loại (luôn sát mép).
    func testThutLeLayTuChinhSoDo() throws {
        let tab = "flowchart LR\n\tA\n\tB\n"
        let ra = apply(try MermaidEdit.addNode(id: "C", in: tab), to: tab)
        XCTAssertTrue(ra.contains("\tC"), ra)
    }

    /// Nguồn không kết thúc bằng xuống dòng thì câu lệnh mới không được dính vào dòng cuối.
    func testNguonKhongKetThucBangXuongDong() throws {
        let src = "flowchart LR\n    A"
        let ra = apply(try MermaidEdit.addNode(id: "B", in: src), to: src)
        XCTAssertEqual(MermaidEdit.parse(ra).nodes.map(\.id), ["A", "B"], ra)
    }

    /// Dấu nháy trong nhãn làm vỡ chính cặp nháy bọc nó, và mermaid không có ký tự thoát.
    func testNhanCoDauNhayKhongLamVoSoDo() throws {
        let ra = apply(try MermaidEdit.addNode(id: "D", label: "cái \"hộp\"", in: flow), to: flow)
        let m = MermaidEdit.parse(ra)
        XCTAssertEqual(m.nodes.count, 4, ra)
        XCTAssertFalse(m.node("D")?.label?.contains("\"") ?? true, ra)
    }
}
