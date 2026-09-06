import XCTest
@testable import GEditorCore

/// Cây YAML chạy trên những tệp YAML THẬT của chính kho này.
///
/// Bài tự nghĩ ra dữ liệu chỉ kiểm được thứ mình đã nghĩ tới. Tệp workflow của GitHub Actions
/// thì không: nó có khối chữ `run: |`, dãy ánh xạ lồng nhau, chuỗi dài — những thứ người viết bộ
/// dựng không tự bịa ra để tự bắt mình.
final class YAMLRealFilesTests: XCTestCase {

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // GEditorCoreTests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // gốc kho
    }

    func testMOItepYAMLtrongKHOdeuDUNGduocCAY() throws {
        let root = repoRoot()
        var paths: [URL] = []
        let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        while let url = walker?.nextObject() as? URL {
            if url.path.contains("/.build/") { continue }
            if ["yml", "yaml"].contains(url.pathExtension) { paths.append(url) }
        }
        // Thư mục `.github` bị `.skipsHiddenFiles` bỏ qua — thêm tay, vì đó chính là tệp khó nhất.
        let workflow = root.appendingPathComponent(".github/workflows/ci.yml")
        if FileManager.default.fileExists(atPath: workflow.path) { paths.append(workflow) }
        let hidden = root.appendingPathComponent("data/.gquality.yaml")
        if FileManager.default.fileExists(atPath: hidden.path) { paths.append(hidden) }

        XCTAssertGreaterThanOrEqual(paths.count, 2, "không tìm thấy tệp YAML thật nào để thử")
        for url in paths {
            let text = try String(contentsOf: url, encoding: .utf8)
            let tree = StructureTree.yaml(text: text)
            XCTAssertNil(tree.failure, "\(url.lastPathComponent): \(tree.failure ?? "")")
            XCTAssertFalse(tree.isEmpty, "\(url.lastPathComponent): cây rỗng")
            let bytes = Array(text.utf8).count
            for node in tree.nodes {
                XCTAssertLessThanOrEqual(
                    node.range.upperBound, bytes,
                    "\(url.lastPathComponent): nút «\(node.label)» trỏ ra ngoài tệp")
            }
        }
    }
}
