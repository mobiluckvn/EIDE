// swift-tools-version: 5.9
import PackageDescription

// GEditor — trình soạn thảo text/CSV hàng Gigabyte cho macOS (Intel + Apple Silicon).
//
// Quy tắc phụ thuộc (SAD §2.2 · NFR-MNT-01):
//   GEditorApp ──┐                    ┌─▶ GEditorSIMD
//   GEditorCLI ──┴─▶ GEditorCore ─────┴─▶ PCRE2
// GEditorCore, GEditorSIMD và PCRE2 KHÔNG được import AppKit/SwiftUI/UIKit.
// scripts/check-core-no-ui.sh chặn vi phạm trong CI.

let package = Package(
    name: "GEditor",
    platforms: [
        // NFR-PORT-02: macOS 12 Monterey trở lên.
        .macOS(.v12)
    ],
    products: [
        .library(name: "GEditorCore", targets: ["GEditorCore"]),
        // EIDE (WI-021): client JSON-RPC thuần, không phụ thuộc AppKit — để test được
        // mà không cần dựng cửa sổ, và để CLI dùng lại nếu cần.
        .library(name: "EIDEKit", targets: ["EIDEKit"]),
        .executable(name: "geditor-poca", targets: ["GEditorPoCA"]),
        .executable(name: "geditor", targets: ["GEditorCLI"]),
        .executable(name: "GEditorApp", targets: ["GEditorApp"]),
        .executable(name: "geditor-bench", targets: ["GEditorBench"]),
        // Tiến trình phụ nạp plugin native (ADR-12 phương án C). CHỈ đi cùng bản tải trực
        // tiếp — bản App Store không được mang nó, vì một tiến trình biết `dlopen` mã lạ nằm
        // trong bundle nộp lên là mời từ chối, dù nó không bao giờ chạy.
        .executable(name: "geditor-plugin-host", targets: ["GEditorPluginHost"]),
        // ADR-08 phương án C: ba grammar nặng nhất tách khỏi binary chính, nạp bằng `dlopen`.
        // KIỂU ĐỘNG là cả điểm của nó — liên kết tĩnh sẽ kéo 10 MB bảng tra trở lại đường
        // khởi động, đúng thứ ADR-08 sinh ra để gỡ.
        .library(name: "TreeSitterHeavy", type: .dynamic, targets: ["TreeSitterHeavy"]),
    ],
    targets: [
        // Lớp 1 — Lõi: dispatch NEON/AVX2 tại runtime (SAD §2.3 SIMDDispatch, NFR-PORT-01).
        .target(
            name: "GEditorSIMD",
            path: "Sources/GEditorSIMD",
            publicHeadersPath: "include"
        ),

        // Lớp 1 — Engine regex (ADR-03). Mã nguồn nạp vào repo bằng scripts/vendor-pcre2.sh,
        // KHÔNG sửa một dòng nào của upstream: mọi lựa chọn build nằm ở đây để nhìn một chỗ
        // là biết đang bật gì.
        //
        // Vì sao vendor thay vì link libpcre2 của hệ thống hoặc Homebrew: /usr/lib có
        // libpcre2-8.dylib nhưng không kèm header công khai (phụ thuộc nội bộ của macOS),
        // còn bản Homebrew chỉ có kiến trúc của máy đang cài. NFR-PORT-01 đòi MỘT bundle
        // universal arm64 + x86_64, chỉ biên dịch từ nguồn mới đạt.
        .target(
            name: "PCRE2",
            path: "Sources/PCRE2",
            // Chỉ `vendor/src` được biên dịch. `vendor/deps/sljit` bị bỏ ngoài CHỦ Ý:
            // pcre2_jit_compile.c `#include` thẳng sljitLir.c, biên dịch riêng sẽ trùng ký hiệu.
            sources: ["vendor/src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("vendor/src"),
                .headerSearchPath("vendor/include"),
                .define("HAVE_CONFIG_H"),
                // Lõi GEditor làm việc trên byte UTF-8 → chỉ dựng bề rộng 8 bit.
                .define("PCRE2_CODE_UNIT_WIDTH", to: "8"),
                .define("SUPPORT_PCRE2_8"),
                // FR-SRCH-102 đòi cú pháp PCRE2 đầy đủ; tiếng Việt đòi \p{L} hoạt động đúng.
                .define("SUPPORT_UNICODE"),
                // ADR-03: JIT là lý do chọn PCRE2. Kéo theo entitlement
                // com.apple.security.cs.allow-jit khi bật hardened runtime (NFR-SEC-01).
                .define("SUPPORT_JIT"),
                // Liên kết tĩnh vào bundle — không có .dylib rời để ký và notarize riêng.
                .define("PCRE2_STATIC"),
            ]
        ),

        // Lớp 1 — LÕI tree-sitter (ADR-04 · PoC-D). Nguồn nạp bằng scripts/vendor-tree-sitter.sh,
        // KHÔNG sửa một dòng nào của upstream.
        //
        // Chỉ LÕI ở đây. Cả hai mươi bảng tra grammar nằm ở target `TreeSitterHeavy` bên dưới
        // (ADR-08 §2.13): lõi thì mọi phiên đều dùng, bảng tra thì chỉ khi mở file cần tô màu.
        .target(
            name: "TreeSitter",
            path: "Sources/TreeSitter",
            // Chỉ `lib/lib.c` được biên dịch: nó `#include` thẳng mọi đơn vị còn lại, biên dịch
            // riêng sẽ trùng ký hiệu — cùng cái bẫy đã gặp với sljit của PCRE2.
            sources: ["vendor/lib/src/lib.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("vendor/lib/src"),
                .headerSearchPath("vendor/lib/include"),
            ]
        ),

        // CẢ HAI MƯƠI bảng tra grammar, nạp lười bằng `dlopen` (ADR-08 §2.5–2.8 và §2.13).
        // Xem GEditorTreeSitterHeavy.h.
        .target(
            name: "TreeSitterHeavy",
            path: "Sources/TreeSitterHeavy",
            sources: [
                "grammars/bash", "grammars/c", "grammars/cpp", "grammars/csharp",
                "grammars/css", "grammars/go", "grammars/html", "grammars/java",
                "grammars/javascript", "grammars/json", "grammars/lua", "grammars/php",
                "grammars/python", "grammars/regex", "grammars/ruby", "grammars/rust",
                "grammars/toml", "grammars/typescript", "grammars/xml", "grammars/yaml",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../TreeSitter/vendor/lib/include"),
                // KHÔNG khai đường dẫn header chung cho ABI của grammar: mỗi grammar mang
                // `tree_sitter/parser.h` riêng đặt ngay cạnh `parser.c`, và include dạng ngoặc
                // kép tìm từ thư mục của chính file gọi trước. Khai một đường dẫn chung ở đây
                // sẽ ép mọi grammar dùng CÙNG một ABI, đúng cái đã làm hỏng bản dựng đầu tiên.
            ]
        ),

        // Lớp 2 — Engine hiển thị ứng viên của ADR-01 (PoC-A). Nguồn nạp bằng
        // scripts/vendor-scintilla.sh, KHÔNG sửa một dòng nào của upstream.
        //
        // Target này là UI: nó nằm ở lớp 2 và GEditorCore không được phụ thuộc vào nó.
        .target(
            name: "ScintillaCocoa",
            path: "Sources/ScintillaCocoa",
            // Bỏ vendor/include khỏi danh sách biên dịch: đó là header, không phải nguồn.
            sources: ["GEScintillaView.mm", "vendor/src", "vendor/cocoa"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("vendor/include"),
                .headerSearchPath("vendor/src"),
                .headerSearchPath("vendor/cocoa"),
            ]
        ),

        // Lớp 1 — Bộ giải nén LZMA/LZMA2, nạp bằng scripts/vendor-libarchive.sh.
        //
        // Không ai import target này từ Swift ngoài một bài kiểm phiên bản: nó có mặt để
        // `LibArchive` bên dưới đọc được `.7z`, thứ gần như luôn nén bằng LZMA2.
        //
        // CHỈ phần GIẢI MÃ được nạp — không một dòng mã nén nào. GEditor chỉ đọc kho nén.
        .target(
            name: "LZMA",
            path: "Sources/LZMA",
            sources: ["vendor/src"],
            publicHeadersPath: "include",
            cSettings: [
                // `config` nằm ngoài `vendor` vì nó là tệp của GEditor, không phải upstream.
                .headerSearchPath("config"),
                // liblzma include theo tên trần ("common.h", "lz_decoder.h"), không theo
                // đường dẫn có thư mục — nên mỗi thư mục con phải khai riêng một dòng.
                .headerSearchPath("vendor/src/common"),
                .headerSearchPath("vendor/src/liblzma/api"),
                .headerSearchPath("vendor/src/liblzma/common"),
                .headerSearchPath("vendor/src/liblzma/check"),
                .headerSearchPath("vendor/src/liblzma/lz"),
                .headerSearchPath("vendor/src/liblzma/lzma"),
                .headerSearchPath("vendor/src/liblzma/rangecoder"),
                .headerSearchPath("vendor/src/liblzma/delta"),
                .headerSearchPath("vendor/src/liblzma/simple"),
                .define("HAVE_CONFIG_H"),
            ]
        ),

        // Lớp 1 — Đọc .7z, .rar, .cab, .lha, .iso, .xar, .cpio, .ar (FR-ARC).
        //
        // Vì sao vendor khi macOS đã có sẵn libarchive: SDK CÓ `libarchive.tbd` để link,
        // nhưng KHÔNG có `archive.h`. Không header nghĩa là không có hợp đồng API — gọi được
        // thì phải tự khai nguyên mẫu, tức tự đoán một ABI Apple chưa từng hứa giữ. Cùng lý
        // do đã loại `/usr/lib/libpcre2-8.dylib` ở target PCRE2 bên trên.
        //
        // Chỉ nửa ĐỌC của thư viện được nạp, và bộ lọc "gọi chương trình ngoài" bị bỏ hẳn —
        // xem phần đầu scripts/vendor-libarchive.sh. Nhờ đó bản App Store trong sandbox mở
        // được đúng những định dạng bản tải trực tiếp mở được, không cần sinh tiến trình con.
        .target(
            name: "LibArchive",
            dependencies: ["LZMA"],
            path: "Sources/LibArchive",
            sources: ["vendor/src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("config"),
                .headerSearchPath("vendor/src"),
                // `archive_read_support_filter_xz.c` include <lzma.h>. SwiftPM không truyền
                // header search path của target phụ thuộc sang, nên phải khai thẳng — cùng
                // lối target TreeSitterHeavy đã dùng để với sang TreeSitter.
                .headerSearchPath("../LZMA/vendor/src/liblzma/api"),
                .define("HAVE_CONFIG_H"),
                .define("LIBARCHIVE_STATIC"),
            ],
            linkerSettings: [
                // zlib và bzip2 KHÔNG vendor: `zlib.h` và `bzlib.h` nằm sẵn trong SDK, tức
                // Apple khai chúng là API công khai. Đây đúng là thứ libarchive KHÔNG có.
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
                // iconv cũng vậy — `iconv.h` có trong SDK. Nó KHÔNG phải tuỳ chọn cho gọn:
                // thiếu nó thì tên tệp tiếng Việt trong kho .7z đọc ra chuỗi RỖNG, vì cả
                // `archive_entry_pathname_utf8()` lẫn `archive_entry_pathname()` đều trả NULL
                // khi không chuyển nổi bảng mã.
                .linkedLibrary("iconv"),
            ]
        ),

        // Lớp 1 — Lõi xử lý văn bản, độc lập UI, test được không cần app (NFR-MNT-01).
        .target(name: "EIDEKit"),
        .testTarget(name: "EIDEKitTests", dependencies: ["EIDEKit"]),

        .target(
            name: "GEditorCore",
            dependencies: ["GEditorSIMD", "PCRE2", "TreeSitter", "LibArchive"],
            path: "Sources/GEditorCore"
        ),

        // Lớp 2 — Trình bày: AppKit (ADR-10).
        .executableTarget(
            name: "GEditorApp",
            dependencies: ["GEditorCore", "EIDEKit"],
            path: "Sources/GEditorApp",
            // `-F` phải có ở CẢ hai chỗ: trình biên dịch cần nó để tìm module `Sparkle`, trình
            // liên kết cần nó để tìm framework. Thiếu vế đầu thì lỗi là "no such module", tức
            // trông như thiếu phụ thuộc chứ không như thiếu một cờ.
            swiftSettings: [
                .unsafeFlags(["-F", "vendor/sparkle"])
            ],
            linkerSettings: [
                // Sparkle — kênh tự cập nhật (NFR-SEC-01). Xem `docs/adr/ADR-16-sparkle.md`.
                //
                // LIÊN KẾT LÚC NẠP, không `dlopen` lười như `libduckdb`/`libTreeSitterHeavy` —
                // và đó là kết luận của một phép ĐO, không phải một giả định: hai binary giống
                // hệt nhau, một cái liên kết Sparkle và không gọi gì trong đó, chênh **1,3 ms**
                // (4,54 → 5,85 ms median, 20 lượt). ADR-08 còn 36 ms dư địa, nên 1,3 ms không
                // đáng đổi lấy sự phức tạp của một đường nạp lười. Cùng hình dạng PoC-L với
                // WebKit (1,4 ms): giá thật của loại thư viện này nằm ở lần DÙNG đầu tiên.
                //
                // `unsafeFlags` được phép vì đây là gói GỐC. Nếu có ngày GEditor thành thư viện
                // cho gói khác phụ thuộc, chỗ này phải đổi sang `.binaryTarget` với XCFramework.
                .unsafeFlags([
                    "-F", "vendor/sparkle",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                    // `swift run`/`swift test` chạy binary thẳng từ `.build`, không có bundle
                    // nào để `@executable_path/../Frameworks` trỏ tới. Đường thứ hai này giữ
                    // cho việc phát triển chạy được mà không phải dựng bundle mỗi lần.
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../vendor/sparkle",
                    // Framework nằm NGAY CẠNH binary. Cần cho `run-startup-kpi.sh`, vốn chép
                    // binary sang một thư mục tạm để ép khởi động NGUỘI — ở đó hai đường trên
                    // đều không giải được, và thiếu đường này thì bản đo im lặng không chạy.
                    // Cùng cách bộ đo ấy đã xử lý `libTreeSitterHeavy.dylib`.
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path",
                ]),
                .linkedFramework("Sparkle"),
            ]
        ),

        // CLI `geditor` — KHÔNG dùng tên `gedit` (trùng GNOME). FR-AUTO-605.
        .executableTarget(
            name: "GEditorCLI",
            dependencies: ["GEditorCore"],
            path: "Sources/GEditorCLI"
        ),

        // PoC-A (ADR-01): đo Scintilla-Cocoa và TextKit 2 song song. Là ỨNG DỤNG chứ không
        // phải benchmark dòng lệnh vì cả hai chỉ tiêu tiền khi có cửa sổ thật để vẽ vào.
        .executableTarget(
            name: "GEditorPoCA",
            dependencies: ["ScintillaCocoa", "GEditorCore"],
            path: "Sources/GEditorPoCA"
        ),

        // Tiến trình phụ nạp plugin native — xem `Sources/GEditorPluginHost/main.swift`.
        .executableTarget(
            name: "GEditorPluginHost",
            dependencies: ["GEditorCore"],
            path: "Sources/GEditorPluginHost"
        ),

        // Bộ đo KPI cho CI — benchmark là bước CHẶN MERGE (STP §4.1, SAD §7).
        .executableTarget(
            name: "GEditorBench",
            // TreeSitter chỉ vào bộ ĐO, chưa vào lõi: ADR-04 còn chưa ghi số liệu, và quy tắc
            // SAD §8 là PoC phải có số trước khi mã sản phẩm được viết.
            dependencies: ["GEditorCore", "TreeSitter", "TreeSitterHeavy"],
            path: "Sources/GEditorBench"
        ),

        .testTarget(
            name: "GEditorCoreTests",
            dependencies: ["GEditorCore"],
            path: "Tests/GEditorCoreTests"
        ),
    ],
    // Scintilla 5 đòi C++17 (upstream dựng bằng đúng mức này).
    cxxLanguageStandard: .cxx17
)
