import XCTest
@testable import GEditorCore

/// Chỉ mục JSON phẳng — nền của JSONPath (FR-FMT-504).
final class JSONIndexTests: XCTestCase {

    private let sample = """
    {
      "cua_hang": {
        "sach": [
          { "ten": "Truyện Kiều", "gia": 120000, "co_san": true },
          { "ten": "Số đỏ", "gia": 85000, "co_san": false }
        ],
        "dia chi": "Hà Nội"
      },
      "ghi_chu": null
    }
    """

    func testEveryValueBecomesANode() {
        let index = JSONIndex(text: sample)
        XCTAssertNil(index.failure)
        // gốc · cua_hang · sach · hai object sách · 6 trường của chúng · dia chi · ghi_chu = 13
        XCTAssertEqual(index.nodes.count, 13)
        XCTAssertEqual(index.nodes[0].kind, .object)
        XCTAssertEqual(index.nodes[0].parent, -1)
    }

    /// Khoảng byte phải trỏ đúng vào giá trị trong văn bản gốc — đây là lý do tồn tại của chỉ mục.
    func testRangesPointAtTheRealText() {
        let bytes = Array(sample.utf8)
        let index = JSONIndex(text: sample)
        for (i, node) in index.nodes.enumerated() where node.key == "ten" {
            let text = index.scalarText(of: i, in: bytes)
            XCTAssertTrue(text == "Truyện Kiều" || text == "Số đỏ", text)
        }
        // Container cũng phải có khoảng đúng: nút mảng bắt đầu bằng `[` và kết thúc bằng `]`.
        guard let arrayNode = index.nodes.firstIndex(where: { $0.kind == .array }) else {
            return XCTFail("không thấy mảng nào")
        }
        let range = index.nodes[arrayNode].range
        XCTAssertEqual(bytes[range.lowerBound], UInt8(ascii: "["))
        XCTAssertEqual(bytes[range.upperBound - 1], UInt8(ascii: "]"))
    }

    func testChildrenKeepDocumentOrder() {
        let index = JSONIndex(text: sample)
        guard let arrayNode = index.nodes.firstIndex(where: { $0.kind == .array }) else {
            return XCTFail("không thấy mảng nào")
        }
        let children = Array(index.childIndices(of: arrayNode))
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(index.nodes[children[0]].indexInParent, 0)
        XCTAssertEqual(index.nodes[children[1]].indexInParent, 1)
        XCTAssertLessThan(children[0], children[1])
    }

    /// Đường dẫn in ra phải dán ngược lại vào ô truy vấn được — kể cả khóa có dấu cách.
    func testPathIsWritable() {
        let index = JSONIndex(text: sample)
        let paths = index.nodes.indices.map { index.path(of: $0) }
        XCTAssertTrue(paths.contains("$.cua_hang.sach[0].ten"), paths.joined(separator: " "))
        XCTAssertTrue(paths.contains("$.cua_hang['dia chi']"), paths.joined(separator: " "))
        XCTAssertEqual(paths[0], "$")
    }

    // MARK: - Chỗ dễ vỡ

    /// Lồng sâu KHÔNG được làm tràn ngăn xếp. Đây là lý do bộ quét không đệ quy.
    func testDeepNestingDoesNotCrash() {
        let depth = 20_000
        let text = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        let index = JSONIndex(text: text)
        XCTAssertNil(index.failure)
        XCTAssertEqual(index.nodes.count, depth)
        XCTAssertEqual(index.nodes[depth - 1].depth, depth - 1)
    }

    func testEmptyContainersAreNodesToo() {
        let index = JSONIndex(text: #"{"a": {}, "b": []}"#)
        XCTAssertNil(index.failure)
        XCTAssertEqual(index.nodes.count, 3)
        XCTAssertEqual(index.nodes[1].kind, .object)
        XCTAssertEqual(index.nodes[2].kind, .array)
        XCTAssertTrue(index.childIndices(of: 1).isEmpty)
    }

    func testMalformedInputReportsWhereAndWhy() {
        let index = JSONIndex(text: "{\n  \"a\": 1,\n}")
        XCTAssertEqual(index.failure?.message, "Dấu phẩy thừa trước dấu }")
        XCTAssertEqual(index.failure?.line, 3)
        XCTAssertTrue(index.nodes.isEmpty)
    }

    func testTooLargeSaysSoInsteadOfWorking() {
        let bytes = [UInt8](repeating: UInt8(ascii: " "), count: JSONIndex.sizeLimit + 1)
        let index = JSONIndex(bytes: bytes)
        XCTAssertTrue(index.tooLarge)
        XCTAssertTrue(index.nodes.isEmpty)
    }

    /// Khóa có escape phải so sánh được với chuỗi người dùng gõ.
    func testEscapedKeysAreUnescaped() {
        let index = JSONIndex(text: #"{"co\ttab": 1}"#)
        XCTAssertNil(index.failure)
        XCTAssertEqual(index.nodes[1].key, "co\ttab")
    }

    /// Giá trị thì KHÔNG được đụng vào: `1.0` phải còn là `1.0`.
    func testNumbersKeepTheirExactText() {
        let text = #"{"a": 1.0, "b": 1e3, "c": -0.50}"#
        let bytes = Array(text.utf8)
        let index = JSONIndex(text: text)
        let values = index.nodes.indices.dropFirst().map { index.scalarText(of: $0, in: bytes) }
        XCTAssertEqual(values, ["1.0", "1e3", "-0.50"])
    }
}
