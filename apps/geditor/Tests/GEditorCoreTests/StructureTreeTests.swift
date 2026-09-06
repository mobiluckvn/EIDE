import XCTest
@testable import GEditorCore

final class StructureTreeTests: XCTestCase {

    private func tree(_ json: String) -> StructureTree { StructureTree.json(text: json) }

    // MARK: - Hình dạng cây

    func testDOIrongCUAmotTAIlieuDONgian() {
        let t = tree(#"{"ten":"An","tuoi":30}"#)
        XCTAssertNil(t.failure)
        XCTAssertEqual(t.roots.count, 1)
        let root = t.nodes[t.roots[0]]
        XCTAssertEqual(root.kind, .object)
        XCTAssertEqual(root.children.count, 2)
        XCTAssertEqual(t.nodes[root.children[0]].label, "ten")
        XCTAssertEqual(t.nodes[root.children[1]].label, "tuoi")
    }

    func testNUTgocMANGnhanLA$khongPHAI_am1() {
        // Nút gốc không có cha nên `indexInParent` là −1; bản đầu in ra đúng chuỗi `[-1]`.
        // `$` là ký hiệu gốc của JSONPath, thứ người dùng đã thấy ở panel truy vấn.
        XCTAssertEqual(tree(#"{"a":1}"#).nodes[0].label, "$")
        XCTAssertEqual(tree(#"[1,2]"#).nodes[0].label, "$")
        XCTAssertEqual(tree(#"42"#).nodes[0].label, "$")
    }

    func testPHANtuMANGlayCHIsoLAMnhan() {
        // Phần tử mảng không có khoá; chỉ số là thứ duy nhất giúp người đọc đếm được mình ở đâu.
        let t = tree(#"[10,20,30]"#)
        let root = t.nodes[t.roots[0]]
        XCTAssertEqual(root.kind, .array)
        XCTAssertEqual(root.children.map { t.nodes[$0].label }, ["[0]", "[1]", "[2]"],
                       "phần tử mảng vẫn phải mang chỉ số, chỉ nút GỐC mới là $")
    }

    func testNUTchuaHIENsoPHANtuCHUkhongHIENnoiDUNG() {
        // Cả điểm của cây gấp được là không phải nhìn nội dung khi chưa cần — nhưng số phần tử
        // phải thấy ngay, vì nó trả lời "có đáng mở ra không".
        let t = tree(#"{"a":[1,2,3],"b":{"c":1}}"#)
        let root = t.nodes[t.roots[0]]
        XCTAssertEqual(root.detail, "{2}")
        XCTAssertEqual(t.nodes[root.children[0]].detail, "[3]")
        XCTAssertEqual(t.nodes[root.children[1]].detail, "{1}")
    }

    func testTANGlongPHANanhDUNGdoSAU() {
        let t = tree(#"{"a":{"b":{"c":1}}}"#)
        let depths = t.nodes.map(\.depth)
        XCTAssertEqual(depths.max(), 3, "bốn tầng lồng phải cho độ sâu tối đa 3: \(depths)")
    }

    // MARK: - Nhảy về nguồn

    func testMOInutBIETminhNAMoDAUtrongNGUON() {
        // Đây là điều kiện để View và Code là hai cách nhìn CÙNG MỘT thứ.
        let json = #"{"ten":"An"}"#
        let t = tree(json)
        let bytes = Array(json.utf8)
        for node in t.nodes {
            XCTAssertTrue(node.canJumpToSource, "nút «\(node.label)» không có khoảng byte")
            XCTAssertLessThanOrEqual(node.range.upperBound, bytes.count)
        }
        // Khoảng byte phải trỏ ĐÚNG chỗ, không phải một chỗ hợp lệ bất kỳ.
        let value = t.nodes[t.nodes[t.roots[0]].children[0]]
        XCTAssertEqual(String(decoding: bytes[value.range], as: UTF8.self), "\"An\"")
    }

    // MARK: - Từ chối chứ không dựng nửa vời

    func testCUphapSAIthiKHONGdungCAYmotNUA() {
        // Một cây cụt trông như tài liệu chỉ có ngần ấy nội dung, và người dùng đi tìm phần
        // thiếu ở chỗ khác.
        let t = tree(#"{"a":1,"b":}"#)
        XCTAssertNotNil(t.failure, "JSON hỏng mà vẫn dựng được cây")
        XCTAssertTrue(t.isEmpty, "đã báo lỗi thì không được trả về nút nào")
    }

    func testTAIlieuRONGkhongPHAIloi() {
        let t = tree("")
        XCTAssertTrue(t.isEmpty)
    }

    // MARK: - Cắt giá trị dài

    func testCATgiaTRIdaiKHONGcatGIUAmotKYtuNHIEUbyte() {
        // Chữ tiếng Việt thì ký tự nào cũng nhiều byte; cắt giữa cho ra một chuỗi hỏng.
        let dai = String(repeating: "ế", count: 200)
        let bytes = Array(("\"" + dai + "\"").utf8)
        let detail = StructureTree.scalarDetail(bytes: bytes, range: 0 ..< bytes.count, limit: 51)
        XCTAssertTrue(detail.hasSuffix("…"))
        XCTAssertFalse(detail.contains("\u{FFFD}"), "có ký tự thay thế — đã cắt giữa một ký tự")
    }

    func testGIAtriNGANthiKHONGcat() {
        let bytes = Array(#""An""#.utf8)
        XCTAssertEqual(
            StructureTree.scalarDetail(bytes: bytes, range: 0 ..< bytes.count), "\"An\"")
    }

    // MARK: - Tài liệu lồng sâu

    func testLONGvaiNGHINtangKHONGlamTRANngamXEP() {
        // Đệ quy sẽ chết ở đây; mảng phẳng thì tầng lồng chỉ là một con số.
        let sau = 3000
        let json = String(repeating: #"{"a":"#, count: sau) + "1"
            + String(repeating: "}", count: sau)
        let t = tree(json)
        XCTAssertNil(t.failure)
        XCTAssertEqual(t.nodes.map(\.depth).max(), sau)
    }

    // MARK: - Đường dẫn tới một nút

    /// Nút đầu tiên có nhãn `label`.
    private func node(_ t: StructureTree, _ label: String) -> Int {
        t.nodes.firstIndex { $0.label == label } ?? -1
    }

    func testDUONGdanJSONkhopTUNGnutVOI_JSONIndex() {
        // Đây là bài neo: cây chỉ giữ NHÃN chứ không giữ khoá gốc, nên phép sinh đường dẫn của
        // nó là bản THỨ HAI của quy tắc đã có trong `JSONIndex.path(of:)`. Hai bản của một quy
        // tắc thì sẽ trôi khỏi nhau — trừ khi có một bài đòi chúng bằng nhau trên từng nút.
        let json = """
        {"ten":"An","dia_chi":{"tỉnh":"Huế","số nhà":12},
         "diem":[9,8,{"mon":"Toán"}],"khoá'lạ":true}
        """
        let t = tree(json)
        let index = JSONIndex(bytes: Array(json.utf8))
        XCTAssertNil(index.failure)
        XCTAssertEqual(t.count, index.nodes.count, "hai bên phải nói về cùng một tập nút")
        for position in t.nodes.indices {
            XCTAssertEqual(t.pathText(of: position), index.path(of: position),
                           "nút \(position) «\(t.nodes[position].label)» lệch")
        }
        // Và vài đường dẫn viết ra tay, để bài không chỉ nói "hai bên giống nhau" mà còn nói
        // "và cả hai đều đúng".
        XCTAssertEqual(t.pathText(of: node(t, "ten")), "$.ten")
        XCTAssertEqual(t.pathText(of: node(t, "tỉnh")), "$.dia_chi['tỉnh']")
        XCTAssertEqual(t.pathText(of: node(t, "mon")), "$.diem[2].mon")
    }

    func testKHOAtenGIONGchiSOmangVANlaKHOA() {
        // Một object hoàn toàn có thể có khoá tên `[0]`. Đọc theo HÌNH DẠNG của nhãn thì đường
        // dẫn in ra trỏ vào phần tử mảng thứ nhất — một chỗ khác hẳn, và im lặng.
        let json = #"{"[0]":"đây là khoá","ds":["đây là phần tử"]}"#
        let t = tree(json)
        XCTAssertEqual(t.pathText(of: node(t, "[0]")), "$['[0]']")
        let element = t.nodes[node(t, "ds")].children[0]
        XCTAssertEqual(t.pathText(of: element), "$.ds[0]")
    }

    func testDUONGdanXMLdungXPATHvaCHIdanhSOkhiCOanhEMtrungTEN() {
        let xml = """
        <don_hang ma="DH-01"><khach tinh="Huế">An</khach>\
        <hang>Bút</hang><hang>Vở</hang></don_hang>
        """
        let t = StructureTree.xml(text: xml)
        XCTAssertEqual(t.pathText(of: node(t, "don_hang")), "/don_hang")
        XCTAssertEqual(t.pathText(of: node(t, "@ma")), "/don_hang/@ma")
        XCTAssertEqual(t.pathText(of: node(t, "@tinh")), "/don_hang/khach/@tinh",
                       "thẻ khach chỉ có một, không được đánh số")
        XCTAssertEqual(t.pathText(of: node(t, "#text")), "/don_hang/khach/text()")
        // Hai thẻ `hang` trùng tên thì phải phân biệt được, và XPath đếm từ 1.
        let hang = t.nodes.indices.filter { t.nodes[$0].label == "hang" }
        XCTAssertEqual(hang.count, 2)
        XCTAssertEqual(t.pathText(of: hang[0]), "/don_hang/hang[1]")
        XCTAssertEqual(t.pathText(of: hang[1]), "/don_hang/hang[2]")
    }

    func testDUONGdanYAMLnoiBANGcuPHAP_JSONPATH() {
        // Vì thứ người ta dán vào — `yq`, ô truy vấn của chính sản phẩm — nói cú pháp ấy.
        let yaml = "máy_chủ:\n  tên: web-01\n  cổng:\n  - 80\n  - 443\n"
        let t = StructureTree.yaml(text: yaml)
        XCTAssertEqual(t.pathText(of: node(t, "tên")), "$['máy_chủ']['tên']")
        let ports = t.nodes[node(t, "cổng")].children
        XCTAssertEqual(t.pathText(of: ports[1]), "$['máy_chủ']['cổng'][1]")
    }

    func testDANyTRAveCHUcuaDONGchuKHONGbiaMOTcuPHAP() {
        let markdown = "## Mở đầu\n- Bối cảnh\n"
        let t = StructureTree.powerPoint(markdown: markdown)
        XCTAssertEqual(t.pathText(of: node(t, "Bối cảnh")), "Bối cảnh")
        XCTAssertEqual(t.dialect, .outline)
    }

    func testDUONGdanCUAchiSOsaiTHIrongCHUkhongSAP() {
        let t = tree(#"{"a":1}"#)
        XCTAssertEqual(t.pathText(of: -1), "")
        XCTAssertEqual(t.pathText(of: 99), "")
    }

    // MARK: - Bất biến của mảng phẳng

    func testCHAluonDUNGtruocCONtrongMANGphang() {
        // Phép lọc của khung nhìn kéo tổ tiên của nút khớp theo bằng MỘT lượt quét ngược, và nó
        // chỉ đúng nhờ bất biến này. Bất biến ấy hôm nay đúng ở cả bốn bộ dựng, nhưng nó là hệ
        // quả của cách viết chứ không phải của kiểu dữ liệu — nên phải có bài canh, không thì
        // một bộ dựng thứ năm làm khác đi sẽ để lọt nút mà không ai thấy.
        let cây: [(String, StructureTree)] = [
            ("json", StructureTree.json(text: #"{"a":{"b":[1,{"c":2}]},"d":3}"#)),
            ("xml", StructureTree.xml(text: "<a a1=\"x\"><b><c>1</c></b><d/></a>")),
            ("yaml", StructureTree.yaml(text: "a:\n  b:\n  - 1\n  - c: 2\nd: 3\n")),
            ("pptx", StructureTree.powerPoint(
                markdown: "## S1\n- x\n> **Ghi chú**\n> y\n## S2\n- z\n")),
        ]
        for (tên, t) in cây {
            XCTAssertFalse(t.nodes.isEmpty, "\(tên): cây rỗng thì bài này không kiểm gì")
            for (cha, node) in t.nodes.enumerated() {
                for con in node.children {
                    XCTAssertGreaterThan(con, cha,
                                         "\(tên): con \(con) đứng TRƯỚC cha \(cha) trong mảng")
                }
            }
        }
    }

    // MARK: - Chiều ngược: từ con nháy về nút

    /// Vị trí byte của lần xuất hiện đầu tiên của `needle` trong `haystack`.
    private func at(_ haystack: String, _ needle: String, offsetBy: Int = 0) -> Int {
        let range = haystack.range(of: needle)!
        return haystack.utf8.distance(
            from: haystack.utf8.startIndex, to: range.lowerBound.samePosition(in: haystack.utf8)!
        ) + offsetBy
    }

    private func label(_ t: StructureTree, at offset: Int) -> String {
        guard let index = t.nodeIndex(containing: offset) else { return "<không có>" }
        return t.nodes[index].label
    }

    func testCONnhayTRONGmotGIAtriTHIchonDUNGgiaTRIay() {
        let json = #"{"ten":"An","dia_chi":{"tinh":"Huế","huyen":"Phú Vang"}}"#
        let t = tree(json)
        XCTAssertEqual(label(t, at: at(json, "Huế")), "tinh")
        XCTAssertEqual(label(t, at: at(json, "Phú Vang")), "huyen")
        XCTAssertEqual(label(t, at: at(json, "An")), "ten")
    }

    func testCONnhayTRENkhoaTHIchonGIAtriCUAkhoaAY() {
        // Khoá nằm NGOÀI khoảng byte của giá trị — `JSONIndex` bao đúng giá trị. Nhưng con nháy
        // đặt trên khoá thì người dùng đang nói tới mục ấy, không tới cả object.
        let json = #"{"ten":"An","dia_chi":{"tinh":"Huế"}}"#
        let t = tree(json)
        XCTAssertEqual(label(t, at: at(json, #""dia_chi""#, offsetBy: 2)), "dia_chi",
                       "con nháy trên khoá phải chọn mục ấy, không chọn nút cha")
    }

    func testCONnhayoDAUobjectTHIchonCHINHobjectAY() {
        // Phần ĐẦU của một nút là chỗ của chính nó — trước con thứ nhất thì không đi xuống.
        let json = #"{"ten":"An"}"#
        let t = tree(json)
        XCTAssertEqual(label(t, at: 0), "$")
        XCTAssertEqual(label(t, at: at(json, #""ten""#, offsetBy: 1)), "$",
                       "khoá ĐẦU TIÊN vẫn thuộc phần đầu của object")
    }

    func testDUONGdiCHAYtuGOCxuongDUNGnutAY() {
        // Khung nhìn cần cả đường: một nút chỉ có hàng khi mọi tầng trên nó đã mở.
        let json = #"{"a":{"b":{"c":"đích"}}}"#
        let t = tree(json)
        let path = t.path(containing: at(json, "đích"))
        XCTAssertEqual(path.map { t.nodes[$0].label }, ["$", "a", "b", "c"])
        XCTAssertEqual(t.roots.first, path.first, "đường phải bắt đầu từ một GỐC")
    }

    func testCONnhayoKHOANGtrangCUOItepTHIlayNUTganNHATphiaTRUOC() {
        // "Gần nhất phía trước" là nút BẮT ĐẦU muộn nhất, tức lá cuối cùng — không phải nút gốc.
        // Con nháy đứng sau cả tài liệu thì thứ ở ngay trên nó là mục cuối, và đó cũng là chỗ
        // người ta vừa gõ xong.
        let json = "{\"a\":1}\n\n\n"
        let t = tree(json)
        XCTAssertEqual(label(t, at: Array(json.utf8).count), "a")
    }

    func testCAYrongTHIkhongCOnutNAO() {
        XCTAssertNil(tree("").nodeIndex(containing: 0))
        XCTAssertTrue(tree("").path(containing: 0).isEmpty)
        // Tệp hỏng cú pháp cũng vậy — cây rỗng thì không có gì để chọn.
        XCTAssertNil(tree("{\"a\":").nodeIndex(containing: 3))
    }

    func testXMLconNHAYtrenTENtheTHIchonTHEchuKHONGchonTHUOCtinh() {
        // Thuộc tính là CON của thẻ và nằm trong thẻ mở, nên nếu luật "đi xuống con kế tiếp" áp
        // vào cả phần đầu thì con nháy đặt trên tên thẻ sẽ chọn nhầm thuộc tính đầu tiên.
        let xml = #"<don_hang ma="DH-01"><tong>1200000</tong></don_hang>"#
        let t = StructureTree.xml(text: xml)
        XCTAssertEqual(label(t, at: 3), "don_hang")
        XCTAssertEqual(label(t, at: at(xml, "DH-01")), "@ma")
        XCTAssertEqual(label(t, at: at(xml, "<tong>", offsetBy: 2)), "tong")
        // Chữ trong thẻ là một nút RIÊNG của cây XML (`#text`), nên con nháy đặt giữa chữ phải
        // rơi vào nút ấy chứ không vào thẻ bao nó — cây hiện gì thì chọn đúng thứ ấy.
        XCTAssertEqual(label(t, at: at(xml, "1200000")), "#text")
    }

    func testHAItheDINHnhauTHIconNHAYoRANHgioiTHUOCveTHEsau() {
        // `<a/>|<b/>` — vị trí ấy vừa là CUỐI của `a` vừa là ĐẦU của `b`. Con nháy đứng TRƯỚC ký
        // tự ở vị trí nó, nên nó thuộc về `b`; chọn `a` là chọn thứ người dùng vừa rời khỏi.
        //
        // Bài này ra đời vì một nhát bẻ: bỏ vế "chứa THẬT thắng chỉ CHẠM" khỏi hiện thực mà cả
        // bộ kiểm vẫn xanh — không bài nào từng dựng ra hai nút dính nhau để hỏi.
        let xml = "<ds><a/><b/></ds>"
        let t = StructureTree.xml(text: xml)
        XCTAssertEqual(label(t, at: at(xml, "<b/>")), "b")
        XCTAssertEqual(label(t, at: at(xml, "<a/>")), "a")
    }

    func testXMLconNHAYoKHOANGtrangTRUOCmotTHEthiCHONtheAY() {
        // Chữ đứng ngay trước một nút thuộc về chính nút ấy: thụt lề trước `<tong>` là của
        // `<tong>`, không phải của thẻ bao ngoài.
        let xml = "<don_hang>\n  <khach>An</khach>\n  <tong>1200000</tong>\n</don_hang>"
        let t = StructureTree.xml(text: xml)
        XCTAssertEqual(label(t, at: at(xml, "  <tong>")), "tong")
    }

    func testYAMLconNHAYtrenKHOAcuaMOTkhoiTHIchonCHINHkhoiAY() {
        // Khoảng byte của một khối YAML bắt đầu ngay ở KHOÁ của nó, nên khoá thuộc phần đầu.
        let yaml = "máy_chủ:\n  tên: web-01\ncổng:\n- 80\n"
        let t = StructureTree.yaml(text: yaml)
        XCTAssertEqual(label(t, at: 2), "máy_chủ")
        XCTAssertEqual(label(t, at: at(yaml, "web-01")), "tên")
        XCTAssertEqual(label(t, at: at(yaml, "80")), "[0]")
    }

    func testDANyPOWERPOINTchonDUNGdongDANGdung() {
        // Ở dàn ý, khoảng byte của một slide chỉ là DÒNG tiêu đề — nó KHÔNG bao các gạch đầu
        // dòng bên dưới. Nên luật "nút chứa" một mình không đủ, và bài này giữ vế ấy.
        let markdown = "## Mở đầu\n- Bối cảnh\n- Mục tiêu\n\n## Kết quả\n- Doanh thu\n"
        let t = StructureTree.powerPoint(markdown: markdown)
        XCTAssertEqual(label(t, at: at(markdown, "Bối cảnh")), "Bối cảnh")
        XCTAssertEqual(label(t, at: at(markdown, "Mục tiêu")), "Mục tiêu")
        XCTAssertEqual(label(t, at: at(markdown, "## Kết quả", offsetBy: 4)), "Kết quả")
        XCTAssertEqual(label(t, at: at(markdown, "Doanh thu")), "Doanh thu")
        // Con nháy ở CUỐI dòng vẫn thuộc dòng ấy — chỗ nó hay đứng nhất.
        XCTAssertEqual(label(t, at: at(markdown, "\n- Mục tiêu")), "Bối cảnh")
        // Dòng trống giữa hai slide: không nút nào chứa, lấy nút gần nhất phía trước.
        XCTAssertEqual(label(t, at: at(markdown, "\n\n## Kết quả", offsetBy: 1)), "Mục tiêu")
    }

    func testDUONGdiTRENdanYchayQUAslideCHUA() {
        let markdown = "## Mở đầu\n- Bối cảnh\n> **Ghi chú**\n> Nói chậm\n"
        let t = StructureTree.powerPoint(markdown: markdown)
        let path = t.path(containing: at(markdown, "Nói chậm"))
        XCTAssertEqual(path.map { t.nodes[$0].label }, ["Mở đầu", "Ghi chú", "Nói chậm"])
    }
}
