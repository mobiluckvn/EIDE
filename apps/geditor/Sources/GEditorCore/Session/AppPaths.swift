import Foundation

/// Vị trí dữ liệu ứng dụng trên đĩa (SAD §5.1).
///
/// Nguyên tắc (ADR-09): mọi dữ liệu CẤU HÌNH là file văn bản diff được — sao lưu,
/// so sánh, đồng bộ giữa máy đều dễ (NFR-PORT-03). Cache tách riêng và LUÔN tái tạo
/// được: xóa `~/Library/Caches/GEditor` bất kỳ lúc nào không được làm mất dữ liệu.
public enum AppPaths {
    public static let bundleName = "GEditor"

    /// Gốc dữ liệu THAY THẾ — chỉ dùng cho những lượt chạy không có người ngồi trước máy.
    ///
    /// Không có nó thì bộ tự kiểm ghi thẳng vào `~/Library/Application Support/GEditor` của
    /// người đang sửa mã. Chuyện ấy đã xảy ra thật: bài kiểm thanh kéo panel thả chuột, đường
    /// ghi nhớ chạy đúng như ở sản phẩm, và mỗi lượt chạy để lại `panelHeights: {"sql": 220}`
    /// trong cấu hình thật — ghim panel SQL của chính người ấy vào sàn 220 pt.
    ///
    /// Đối xứng là chỗ đáng nhớ: hồi đó ĐỌC lại không thấy khoá ấy (một lỗi khác, ở decoder
    /// viết tay), nên vết bẩn không làm bài kiểm nào đỏ. Một bộ kiểm ghi ra ngoài vùng của nó
    /// mà vẫn xanh sẽ cứ ghi mãi, và không ai biết cho tới khi nó ghi trúng thứ có giá.
    ///
    /// Đặt ở `AppPaths` chứ không chặn riêng ở chỗ ghi cấu hình: `settings.json` chỉ là tệp
    /// ĐẦU TIÊN bị bắt gặp, còn `session/`, `snapshots/`, `queries/` và `themes/` đều nằm cùng
    /// một gốc và đều ghi được. Bịt một tệp là bịt một lối trong năm lối.
    public static var applicationSupportOverride: URL?

    public static var applicationSupport: URL {
        if let applicationSupportOverride { return applicationSupportOverride }
        return base(for: .applicationSupportDirectory)
            .appendingPathComponent(bundleName, isDirectory: true)
    }

    public static var caches: URL {
        base(for: .cachesDirectory).appendingPathComponent(bundleName, isDirectory: true)
    }

    /// Cấu hình người dùng — JSON có `schemaVersion` để migrate được.
    public static var settingsFile: URL {
        applicationSupport.appendingPathComponent("settings.json")
    }

    /// Journal phiên: danh sách tab, caret, view state (FR-DOC-303).
    public static var sessionDirectory: URL {
        applicationSupport.appendingPathComponent("session", isDirectory: true)
    }

    /// Bản nháp chưa lưu (FR-DOC-304, NFR-REL-01).
    public static var snapshotsDirectory: URL {
        applicationSupport.appendingPathComponent("snapshots", isDirectory: true)
    }

    /// Báo cáo sự cố chờ người dùng quyết định — NFR-REL-03.
    ///
    /// Nằm trong Application Support chứ không trong Caches: Caches là nơi hệ điều hành được
    /// phép dọn bất cứ lúc nào, và một báo cáo sự cố biến mất trước khi người dùng kịp thấy thì
    /// đúng bằng không có.
    public static var crashDirectory: URL {
        applicationSupport.appendingPathComponent("crash", isDirectory: true)
    }

    public static var macrosDirectory: URL {
        applicationSupport.appendingPathComponent("macros", isDirectory: true)
    }

    public static var scriptsDirectory: URL {
        applicationSupport.appendingPathComponent("scripts", isDirectory: true)
    }

    public static var themesDirectory: URL {
        applicationSupport.appendingPathComponent("themes", isDirectory: true)
    }

    public static var grammarsDirectory: URL {
        applicationSupport.appendingPathComponent("grammars", isDirectory: true)
    }

    /// Plugin NATIVE (FR-PLUG-702, ADR-12) — chỉ có ở bản tải trực tiếp.
    ///
    /// Nằm cạnh `scripts/`, `themes/`, `grammars/` và theo cùng một luật: **cài là chép file,
    /// gỡ là xoá file, danh sách suy ra TỪ ĐĨA.** Không sổ đăng ký — người dùng xoá tay một
    /// file trong Finder thì một cuốn sổ nói khác đi là cuốn sổ nói dối.
    ///
    /// Khác ba thư mục kia ở một điểm phải nhớ: thứ nằm đây là MÃ MÁY của người khác, không
    /// phải dữ liệu. Đó là lý do nó chỉ được nạp ở tiến trình phụ (ADR-12 phương án C).
    /// Thư viện truy vấn (FR-QRY-001) — lịch sử và câu đã lưu, THEO WORKSPACE.
    ///
    /// Câu truy vấn dính chặt vào dữ liệu: `SELECT … WHERE tinh = 'Huế'` chỉ có nghĩa với bảng
    /// có cột `tinh`. Một thư viện toàn cục sẽ trộn câu của mọi bộ dữ liệu người dùng từng mở,
    /// và phần lớn chúng báo "không có cột ấy" khi bấm lại.
    ///
    /// Khoá theo băm đường dẫn workspace chứ không theo chính đường dẫn: tên thư mục của người
    /// dùng có dấu, dấu cách và dấu gạch chéo, và ghép nó vào tên file là sinh ra một đường dẫn
    /// khác thứ mình định. Băm thì luôn an toàn và luôn cùng độ dài — đổi lại là không đọc được
    /// bằng mắt, nên tệp tự ghi đường dẫn gốc vào bên trong.
    public static func queryLibraryFile(workspace: String?) -> URL {
        let directory = applicationSupport.appendingPathComponent("queries", isDirectory: true)
        guard let workspace, !workspace.isEmpty else {
            return directory.appendingPathComponent("chung.json")
        }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325       // FNV-1a, cùng lý do với CSVProfile:
        for byte in workspace.utf8 {                    // `Hasher` gieo hạt NGẪU NHIÊN mỗi lần
            hash ^= UInt64(byte)                        // chạy, nên cùng workspace sẽ ra hai
            hash = hash &* 0x0000_0100_0000_01b3        // tên tệp khác nhau ở hai phiên.
        }
        return directory.appendingPathComponent(String(format: "%016llx.json", hash))
    }

    public static var nativePluginsDirectory: URL {
        applicationSupport.appendingPathComponent("plugins", isDirectory: true)
    }

    /// Tạo toàn bộ cây thư mục dữ liệu nếu chưa có.
    public static func createDirectories() throws {
        for url in [
            applicationSupport, caches, sessionDirectory, snapshotsDirectory,
            macrosDirectory, scriptsDirectory, themesDirectory, grammarsDirectory,
            crashDirectory,
            nativePluginsDirectory,
        ] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func base(for directory: FileManager.SearchPathDirectory) -> URL {
        FileManager.default.urls(for: directory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
    }
}
