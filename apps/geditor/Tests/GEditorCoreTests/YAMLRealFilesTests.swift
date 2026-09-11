import XCTest
@testable import GEditorCore

/// Cây YAML chạy trên những tệp YAML THẬT của chính kho này.
///
/// Bài tự nghĩ ra dữ liệu chỉ kiểm được thứ mình đã nghĩ tới. Tệp workflow của GitHub Actions
/// thì không: nó có khối chữ `run: |`, dãy ánh xạ lồng nhau, chuỗi dài — những thứ người viết bộ
/// dựng không tự bịa ra để tự bắt mình.
final class YAMLRealFilesTests: XCTestCase {

    /// Gốc KHO, không phải gốc gói Swift.
    ///
    /// Bài này từng leo đúng ba cấp rồi dừng — hồi GEditor còn là kho riêng thì ba cấp ấy ra
    /// gốc kho. Từ 06/09/2026 GEditor nằm trong `apps/geditor` của kho EIDE, nên ba cấp ra
    /// **gốc gói**, nơi có đúng một tệp YAML. Bài đỏ vì HẾT NGỮ LIỆU chứ không vì cây YAML
    /// hỏng, và cái nó định giữ thì năm ngày qua không ai giữ.
    ///
    /// Mốc là `.git` — thứ chỉ có ở gốc kho. Leo theo mốc thay vì đếm cấp nên bài này sống
    /// được ở cả hai bố cục: GEditor tách riêng lại thì nó tự dừng ở gốc gói.
    private func repoRoot() -> URL {
        let goiSwift = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // GEditorCoreTests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // gốc gói Swift
        var d = goiSwift
        while d.path != "/" {
            if FileManager.default.fileExists(atPath: d.appendingPathComponent(".git").path) {
                return d
            }
            d = d.deletingLastPathComponent()
        }
        return goiSwift
    }

    func testMOItepYAMLtrongKHOdeuDUNGduocCAY() throws {
        let root = repoRoot()
        var paths: [URL] = []
        let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        while let url = walker?.nextObject() as? URL {
            if url.path.contains("/.build/") { continue }
            // Gói của người khác không phải "tệp YAML thật của kho này": một tệp gãy trong
            // `node_modules` thì đỏ ở đây cũng chẳng ai sửa được, và nó làm bài mất nghĩa.
            if url.path.contains("/node_modules/") { continue }
            if ["yml", "yaml"].contains(url.pathExtension) { paths.append(url) }
        }
        // Thư mục `.github` bị `.skipsHiddenFiles` bỏ qua — thêm tay, vì đó chính là tệp khó nhất.
        let workflow = root.appendingPathComponent(".github/workflows/ci.yml")
        if FileManager.default.fileExists(atPath: workflow.path) { paths.append(workflow) }
        let hidden = root.appendingPathComponent("data/.gquality.yaml")
        if FileManager.default.fileExists(atPath: hidden.path) { paths.append(hidden) }

        // Ngưỡng đặt cao hơn hẳn số tệp "có cũng như không" (kho này có ~35, phần lớn là hợp
        // đồng năng lực trong `docs/spec/capabilities`). Ngưỡng 2 cũ quá thấp để báo động: nó
        // vẫn xanh khi ngữ liệu tụt từ vài chục xuống hai, mà đó chính là lúc bài này hết việc.
        XCTAssertGreaterThanOrEqual(
            paths.count, 10,
            "chỉ thấy \(paths.count) tệp YAML — ngữ liệu thật đã mất, bài này không còn kiểm gì")
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
