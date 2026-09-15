import XCTest
import AppKit
import GEditorCore

/// Màn "Mã nguồn" — cây tệp trỏ đúng dự án và thấy `.eide/`.
///
/// Chủ sản phẩm ngày 15/09/2026: *"mã nguồn là một thư mục mã nguồn có cấu trúc. Bạn đang hiển
/// thị là dạng một file text thì làm sao mà okay được"*. Nguyên nhân đo được: `openWorkspace(_:)`
/// tồn tại và KHÔNG một lời gọi nào chạm tới nó, nên cây tệp luôn rỗng.
///
/// Test ở đây canh phần logic thuần (`Workspace`), vì phần còn lại — "mở màn thì cây hiện ra" —
/// nằm trong `MainWindowController` và được canh bằng `EideUITests`.
final class EideManNguonTests: XCTestCase {

    private var goc: URL!

    override func setUpWithError() throws {
        goc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("eide-ws-\(UUID().uuidString)")
        let fm = FileManager.default
        for d in ["src", ".eide/store", ".git", "node_modules"] {
            try fm.createDirectory(at: goc.appendingPathComponent(d),
                                   withIntermediateDirectories: true)
        }
        for f in ["src/main.c", "CMakeLists.txt", ".eide/ledger.jsonl",
                  ".eide/autonomy.yaml", ".gitignore", ".DS_Store",
                  ".git/config", "node_modules/x.js"] {
            try Data("x".utf8).write(to: goc.appendingPathComponent(f))
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: goc)
    }

    private func ten(_ ds: [WorkspaceEntry]) -> [String] { ds.map(\.name) }

    /// Mặc định: `.eide/` bị giấu — đây là hành vi CŨ và nó đúng cho một trình soạn thảo thường.
    func testMACdinhKHONGhienEIDE() {
        let ds = Workspace.children(of: goc.path)
        XCTAssertFalse(ten(ds).contains(".eide"))
    }

    func testLUONhienCHOphepEIDEvaoCAY() {
        let ds = Workspace.children(of: goc.path, alwaysShow: [".eide"])
        XCTAssertTrue(ten(ds).contains(".eide"))
    }

    /// `alwaysShow` là một cái kim, không phải một cái búa.
    ///
    /// Nếu nó lỡ bật cả `showHidden` thì cây đầy `.DS_Store`, `.gitignore`, `.git` — tức đổi một
    /// thư mục thiếu lấy một cây đầy rác, và người dùng không tìm thấy `src/` giữa đống ấy.
    func testLUONhienKHONGkeoTHEOmoiTHUan() {
        let ds = ten(Workspace.children(of: goc.path, alwaysShow: [".eide"]))
        XCTAssertFalse(ds.contains(".DS_Store"))
        XCTAssertFalse(ds.contains(".gitignore"))
        XCTAssertFalse(ds.contains(".git"), "`.git` vẫn phải nằm trong danh sách bỏ qua")
        XCTAssertFalse(ds.contains("node_modules"))
        XCTAssertTrue(ds.contains("src"))
        XCTAssertTrue(ds.contains("CMakeLists.txt"))
    }

    /// Ô lọc phải tìm được thứ cây hiện ra.
    ///
    /// Cây hiện `ledger.jsonl` mà gõ tên nó vào ô lọc lại không ra gì là một mâu thuẫn người
    /// dùng gặp ngay lần gõ đầu tiên — và họ kết luận ô lọc hỏng.
    func testOLOCtimDUOCtepTRONGeideKHIcayHIENno() {
        let co = Workspace.find("ledger", under: goc.path, alwaysShow: [".eide"])
        XCTAssertEqual(ten(co), ["ledger.jsonl"])
        let khong = Workspace.find("ledger", under: goc.path)
        XCTAssertTrue(khong.isEmpty, "không bật `.eide` thì ô lọc cũng không được thấy")
    }

    /// Con của `.eide/` đọc được — bật thư mục lên mà bên trong rỗng thì bật để làm gì.
    func testDOCduocBENtrongEIDE() {
        let ds = ten(Workspace.children(of: goc.appendingPathComponent(".eide").path,
                                        alwaysShow: [".eide"]))
        XCTAssertTrue(ds.contains("ledger.jsonl"))
        XCTAssertTrue(ds.contains("autonomy.yaml"))
        XCTAssertTrue(ds.contains("store"))
    }
}
