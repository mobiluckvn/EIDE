import Foundation

/// Tìm và khởi chạy `eide daemon` — WI-021, DEP-26 §2–§3.
///
/// GEditor không đóng gói EIDE bên trong: DEP-26 §1 xếp chúng là hai thành phần phát hành
/// khác nhau (`eide` là gói pip, `eide-geditor` là bundle plugin). Nên panel phải TÌM `eide`
/// trên máy, và phải nói rõ khi không tìm thấy thay vì im lặng — U9.
public enum EideDaemonLauncher {

    /// Thứ tự tìm, từ rõ ràng nhất tới đoán nhiều nhất:
    ///
    /// 1. `EIDE_PYTHON` — người dùng chỉ đích danh; luôn thắng.
    /// 2. venv trong kho EIDE cạnh GEditor (`../../.venv-arm`) — cách chạy khi đang phát triển.
    /// 3. `eide` trong PATH — cách chạy sau khi `pipx install eide` (DEP-26 §2).
    ///
    /// Không đoán thêm. Một đường dẫn đoán sai sẽ mở nhầm một Python khác và lỗi hiện ra ở
    /// chỗ chẳng liên quan gì.
    public static func timEide() -> [String]? {
        let fm = FileManager.default

        if let p = ProcessInfo.processInfo.environment["EIDE_PYTHON"],
           fm.isExecutableFile(atPath: p) {
            return [p, "-m", "eide.cli"]
        }

        // Kho EIDE là ông của apps/geditor. `#filePath` trỏ vào nguồn, nên cách này chỉ đúng
        // khi chạy từ bản dựng phát triển — và đó chính là lúc cần nó.
        let kho = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // EIDEKit
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // geditor
            .deletingLastPathComponent()   // apps
            .deletingLastPathComponent()   // EIDE
        for venv in [".venv-arm", ".venv-x86", ".venv"] {
            let p = kho.appendingPathComponent("\(venv)/bin/python").path
            if fm.isExecutableFile(atPath: p) { return [p, "-m", "eide.cli"] }
        }

        for thu_muc in ["/opt/homebrew/bin", "/usr/local/bin",
                        NSHomeDirectory() + "/.local/bin"] {
            let p = thu_muc + "/eide"
            if fm.isExecutableFile(atPath: p) { return [p] }
        }
        return nil
    }

    /// Thư mục kho EIDE, nếu chạy từ bản dựng phát triển — daemon cần nó để đọc `docs/spec/`.
    public static func gocKho() -> String? {
        let kho = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let dau = kho.appendingPathComponent("CLAUDE.md").path
        return FileManager.default.fileExists(atPath: dau) ? kho.path : nil
    }

    /// Mở một client, hoặc `nil` nếu không tìm thấy `eide`.
    public static func moClient(duAn: String? = nil) -> EideClient? {
        guard let eide = timEide() else { return nil }
        if let goc = gocKho() {
            // Registry nạp `docs/spec/cds.json` theo `repo_root()`, tìm ngược từ CLAUDE.md.
            // Chạy từ thư mục khác thì nó không thấy — nên đặt cwd đúng trước khi mở.
            FileManager.default.changeCurrentDirectoryPath(goc)
        }
        guard let t = try? EideStdioTransport(eide: eide, duAn: duAn) else { return nil }
        return EideClient(transport: t)
    }
}
