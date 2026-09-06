import Foundation

/// Nạp bảng tra grammar từ dylib khi cần, thay vì gánh chúng ở mọi lần khởi động (ADR-08).
///
/// **Vì sao phải có tệp này.** Bảng tra grammar chiếm **70,5 %** binary đã liên kết — 7,19 MB
/// trên 10,20 MB, trong khi cả GEditorCore chỉ 1,17 MB (ADR-08 §2.13, đo bằng link map của
/// `ld` chứ không bằng kích thước `.o`: ở bản release, `.o` còn mang debug info và nói dối
/// theo hướng rất dễ tin). Chúng nằm trong binary chính thì dyld phải ánh xạ và ta trả phí ấy
/// ở MỌI lần mở app, kể cả phiên chỉ mở một file `.txt`.
///
/// Đo trực tiếp: bỏ cả hai mươi bảng tra ra khiến binary tụt **11,20 → 3,47 MB** và khởi động
/// nguội **~520 → ~396 ms** — về dưới trần 500 ms của NFR-PERF-01 với khoảng dư ~100 ms.
///
/// **Vì sao MỘT dylib chứ không phải mỗi ngôn ngữ một dylib.** Vì `dlopen` gần như không phụ
/// thuộc kích thước: một dylib 0,63 MB tốn 449,6 ms, một dylib 1,39 MB tốn 451,2 ms, còn khối
/// 10,47 MB tốn 507,2 ms. Phí là ~440 ms CỐ ĐỊNH cho mỗi tệp mới cộng ~7 ms mỗi MB. Tách nhỏ
/// theo ngôn ngữ nghe hợp lý mà thật ra làm tệ đi — ai mở ba ngôn ngữ trả ba lần 440 ms thay
/// vì một lần. Số đo ở ADR-08 §2.13(b).
///
/// **Vì sao `dlopen` chứ không phải tải về từ mạng.** Dylib nằm ngay trong bundle, cạnh binary.
/// Không cần máy chủ, không cần chữ ký Developer ID, không có trạng thái "chưa tải xong" để
/// người dùng gặp — và App Store cấm tải mã lúc chạy, nên đây cũng là hình dạng duy nhất qua
/// được điều 2.5.2. Khi nào có hạ tầng phát hành thật thì chuyển tệp ấy ra ngoài bundle, và
/// chỗ duy nhất phải sửa là `candidatePaths` bên dưới.
///
/// **Chi phí thật, đã đo** (ADR-08 §2.8 và §2.13):
///
/// | | |
/// |---|---|
/// | `dlopen` lần đầu trong phiên (nguội) | ~500 ms |
/// | `dlopen` những lần sau (ấm) | 0,3 ms |
/// | `dlsym` | 0,0 ms |
/// | phân tích một file C# thật | 0,6 ms |
///
/// Nghĩa là phí chuyển từ "mọi người trả ở mọi lần khởi động" sang "chỉ người mở file CẦN TÔ
/// MÀU trả, một lần mỗi phiên". Ai chỉ mở `.txt`, `.csv`, `.log` thì không trả gì — và với một
/// trình soạn thảo hàng Gigabyte đó là phần lớn thời gian dùng. Người trả cũng không CẢM THẤY:
/// tô màu vốn chạy ở luồng nền (`AsyncHighlighter`), nên cửa sổ mở ngay, màu đến sau — đúng
/// thứ vẫn xảy ra với file lớn.
public enum GrammarLibrary {

    /// Hai mươi ngôn ngữ nằm trong dylib. Danh sách này phải khớp `sources` của target
    /// `TreeSitterHeavy` trong `Package.swift` và mảng `HEAVY` trong
    /// `scripts/vendor-tree-sitter.sh`. Có một bài kiểm canh chúng khớp nhau.
    ///
    /// Khóa là `SyntaxLanguage.rawValue`; giá trị là tên hàm THẬT trong dylib — `csharp` xuất ra
    /// `tree_sitter_c_sharp` vì tên do grammar quyết chứ không do thư mục.
    public static let symbolNames: [String: String] = [
        "bash": "tree_sitter_bash",
        "c": "tree_sitter_c",
        "cpp": "tree_sitter_cpp",
        "csharp": "tree_sitter_c_sharp",
        "css": "tree_sitter_css",
        "go": "tree_sitter_go",
        "html": "tree_sitter_html",
        "java": "tree_sitter_java",
        "javascript": "tree_sitter_javascript",
        "json": "tree_sitter_json",
        "lua": "tree_sitter_lua",
        "php": "tree_sitter_php",
        "python": "tree_sitter_python",
        "regex": "tree_sitter_regex",
        "ruby": "tree_sitter_ruby",
        "rust": "tree_sitter_rust",
        "toml": "tree_sitter_toml",
        "typescript": "tree_sitter_typescript",
        "xml": "tree_sitter_xml",
        "yaml": "tree_sitter_yaml",
    ]

    /// Tên tệp dylib do SwiftPM/`build-universal.sh` sinh ra.
    public static let fileName = "libTreeSitterHeavy.dylib"

    // MARK: - Nạp

    /// Khóa bảo vệ `cache` và `loadFailure`.
    ///
    /// Cần khóa thật vì `handle` được gọi từ luồng nền của `AsyncHighlighter`, và hai tab mở
    /// cùng lúc hai file C++ sẽ chạm vào đây song song. `dlopen` bản thân nó an toàn đa luồng
    /// và trả về cùng một handle, nhưng `cache` là từ điển Swift thì không.
    private static let lock = NSLock()
    private static var cache: [String: OpaquePointer] = [:]
    private static var libraryHandle: UnsafeMutableRawPointer?
    private static var loadFailure: String?

    /// Con trỏ grammar cho một ngôn ngữ nặng; `nil` nếu không nạp được.
    ///
    /// KHÔNG BAO GIỜ ném hay sập: dylib thiếu chỉ có nghĩa là file ấy hiện ra không màu, và một
    /// trình soạn thảo mở được file là quan trọng hơn nhiều so với việc tô đúng cú pháp.
    static func handle(_ language: String) -> OpaquePointer? {
        guard let symbol = symbolNames[language] else { return nil }

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[language] { return cached }
        guard let library = loadLibraryLocked() else { return nil }

        guard let address = dlsym(library, symbol) else {
            loadFailure = "không tìm thấy \(symbol) trong \(fileName)"
            return nil
        }
        // Chữ ký thật là `const TSLanguage *(*)(void)`. Bên Swift chỉ cần con trỏ mờ vì
        // `ts_parser_set_language` cũng nhận con trỏ mờ; khai đúng kiểu ở đây đòi import
        // TreeSitterHeavy, và import ấy là thứ kéo dylib trở lại đường liên kết.
        let function = unsafeBitCast(address, to: (@convention(c) () -> OpaquePointer?).self)
        guard let pointer = function() else {
            loadFailure = "\(symbol) trả về con trỏ rỗng"
            return nil
        }
        cache[language] = pointer
        return pointer
    }

    /// Mở dylib một lần cho cả tiến trình. Gọi khi đang giữ `lock`.
    private static func loadLibraryLocked() -> UnsafeMutableRawPointer? {
        if let libraryHandle { return libraryHandle }
        if loadFailure != nil { return nil }   // đã thử và hỏng — đừng thử lại mỗi lần gõ phím

        for path in candidatePaths() {
            // RTLD_LAZY: chỉ giải quyết ký hiệu khi gọi tới. Grammar không gọi hàm ngoài nào
            // nên thực tế chẳng có gì để giải quyết, nhưng LAZY thì rẻ hơn và đo được ở PoC-E.
            if let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
                libraryHandle = handle
                return handle
            }
        }
        loadFailure = "không mở được \(fileName) ở: " + candidatePaths().joined(separator: ", ")
        return nil
    }

    /// Những chỗ dylib có thể nằm, theo thứ tự.
    ///
    /// Hỏi `Bundle`, KHÔNG suy ra từ `CommandLine.arguments[0]`. Bản đầu suy từ argv[0] và nó
    /// chạy đúng ở mọi bản dựng phát triển — rồi chết trong App Sandbox: argv[0] là đường
    /// TƯƠNG ĐỐI theo chỗ gọi, mà thư mục hiện hành của một app sandbox lại nằm trong container,
    /// nên nó ghép ra
    /// `~/Library/Containers/ai.code247.GEditor/Data/dist/GEditor.app/Contents/Frameworks/…`
    /// — một đường không tồn tại. Hậu quả: C#, C++ và Ruby mất màu, im lặng, chỉ trong bản
    /// phát hành. Bộ tự kiểm chạy trên bundle đã ký bắt được; chạy trên binary trần thì không.
    ///
    /// Bốn chỗ, vì app chạy ở nhiều hình dạng và tất cả đều phải hoạt động:
    ///
    /// 1. `Contents/Frameworks/` của bundle — hình dạng của bản phát hành.
    /// 2. Cạnh chính binary — `swift build` để mọi sản phẩm chung một thư mục, nên đây là hình
    ///    dạng lúc phát triển và lúc chạy tự kiểm.
    /// 3. Suy từ argv[0] — giữ lại cho những cách chạy không có bundle hợp lệ.
    /// 4. Tên trần — để dyld tự tra, lối thoát cho ai đóng gói khác.
    public static func candidatePaths() -> [String] {
        var paths: [String] = []

        if let frameworks = Bundle.main.privateFrameworksURL {
            paths.append(frameworks.appendingPathComponent(fileName).path)
        }
        if let executable = Bundle.main.executableURL?.deletingLastPathComponent() {
            paths.append(executable.appendingPathComponent(fileName).path)
        }

        let fromArgv = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        paths.append(
            fromArgv.deletingLastPathComponent()
                .appendingPathComponent("Frameworks/\(fileName)").path
        )
        paths.append(fromArgv.appendingPathComponent(fileName).path)
        paths.append(fileName)

        // Bỏ trùng, giữ thứ tự: hai nguồn trên trả về cùng một đường khi chạy bằng
        // `swift build`, và một danh sách có mục lặp làm thông báo lỗi khó đọc.
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    // MARK: - Móc chẩn đoán

    /// Vì sao lần nạp gần nhất hỏng; `nil` nghĩa là chưa hỏng lần nào.
    ///
    /// Có mặt để bộ tự kiểm nói được "không tô màu vì THIẾU DYLIB" thay vì im lặng đưa ra một
    /// file trắng trơn và để người sửa lỗi tự đoán.
    public static var failureReason: String? {
        lock.lock()
        defer { lock.unlock() }
        return loadFailure
    }

    /// Dylib đã nạp chưa. Dùng để kiểm chứng rằng nó nạp LƯỜI thật, chứ không phải bị kéo vào
    /// ngay lúc khởi động bởi một `import` nào đó lọt lưới.
    public static var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return libraryHandle != nil
    }
}
