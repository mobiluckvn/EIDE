import XCTest
@testable import GEditorCore

/// Bảng tra grammar nạp bằng `dlopen` (ADR-08 §2.13).
///
/// Bộ kiểm này canh một thứ dễ hỏng âm thầm: cách bố trí ở ba chỗ — `Package.swift`, script
/// vendor, và `GrammarLibrary.symbolNames` — phải khớp nhau. Lệch một chỗ thì ngôn ngữ ấy chỉ
/// đơn giản là mất màu, không có lỗi nào nổi lên.
final class GrammarLibraryTests: XCTestCase {

    /// MỌI ngôn ngữ đều nằm trong dylib — không sót ngôn ngữ nào ở lại binary chính.
    ///
    /// Không phải chuyện thẩm mỹ. Sót một ngôn ngữ là kéo cả bảng tra của nó (0,6–1,4 MB) trở
    /// lại đường khởi động, và triệu chứng duy nhất là app chậm đi vài chục mili-giây — thứ
    /// không ai thấy cho tới lúc đo lại KPI và không hiểu vì sao số xấu đi.
    ///
    /// Chiều ngược lại cũng chặn: một khóa thừa trong từ điển mà `sources` của target không có
    /// sẽ làm `dlsym` trả `nil` lúc chạy, và ngôn ngữ ấy mất màu.
    func testDylibHoldsEverySingleLanguage() {
        XCTAssertEqual(
            Set(GrammarLibrary.symbolNames.keys),
            Set(SyntaxLanguage.allCases.map(\.rawValue)),
            "danh sách trong GrammarLibrary lệch với SyntaxLanguage"
        )
    }

    /// Mọi khóa phải là một `SyntaxLanguage` thật.
    func testEverySymbolKeyIsARealLanguage() {
        for key in GrammarLibrary.symbolNames.keys {
            XCTAssertNotNil(SyntaxLanguage(rawValue: key), "\(key) không phải ngôn ngữ nào cả")
        }
    }

    /// CẢ HAI MƯƠI grammar nạp được thật, và trả về con trỏ dùng được.
    ///
    /// Đây là bài kiểm chứng minh cả đường đi: tìm dylib → `dlopen` → `dlsym` → gọi hàm. Nếu
    /// dylib không nằm cạnh binary kiểm thì bài này đỏ, và thông báo nói rõ đã tìm ở đâu — chứ
    /// không im lặng bỏ qua.
    ///
    /// Chạy trên TẤT CẢ chứ không trên một mẫu: chỗ lệch tên là `csharp` → `tree_sitter_c_sharp`,
    /// tức là đúng loại lỗi mà một danh sách mẫu sẽ bỏ sót.
    func testEveryGrammarActuallyLoads() {
        for language in SyntaxLanguage.allCases {
            XCTAssertNotNil(
                language.handle,
                "\(language.rawValue) không nạp được — \(GrammarLibrary.failureReason ?? "không rõ vì sao")"
            )
        }
        XCTAssertTrue(GrammarLibrary.isLoaded)
        XCTAssertNil(GrammarLibrary.failureReason)
    }

    /// Ngôn ngữ lạ trả `nil` chứ không sập.
    func testUnknownLanguageIsSafe() {
        XCTAssertNil(GrammarLibrary.handle("khong-ton-tai"))
    }

    /// Thứ tự tìm kiếm: bundle trước, cạnh binary sau.
    ///
    /// Bản phát hành và bản phát triển có hình dạng khác nhau, và cả hai đều phải chạy. Đảo thứ
    /// tự thì một bản `.app` đã cài sẽ vớ phải dylib trong thư mục build của máy lập trình viên
    /// nếu tình cờ có — sai lệch kiểu ấy chỉ lộ ra ở máy người dùng.
    func testSearchOrderPutsTheBundleFirst() {
        let paths = GrammarLibrary.candidatePaths()
        XCTAssertGreaterThanOrEqual(paths.count, 3)
        XCTAssertEqual(paths.last, GrammarLibrary.fileName)
        XCTAssertEqual(Set(paths).count, paths.count, "danh sách có đường trùng nhau")
    }

    /// Đường đi phải suy từ `Bundle`, KHÔNG từ `CommandLine.arguments[0]`.
    ///
    /// argv[0] có thể là đường tương đối, và thư mục hiện hành của một app sandbox nằm trong
    /// container — ghép ra một đường không tồn tại. Đó là cách C#/C++/Ruby mất màu trong bản
    /// App Store mà không báo gì.
    func testPathsDoNotDependOnTheWorkingDirectory() {
        let bundlePath = Bundle.main.privateFrameworksURL?.appendingPathComponent(
            GrammarLibrary.fileName
        ).path
        if let bundlePath {
            XCTAssertEqual(GrammarLibrary.candidatePaths().first, bundlePath)
        }
        for path in GrammarLibrary.candidatePaths().dropLast() {
            XCTAssertTrue(path.hasPrefix("/"), "đường không tuyệt đối: \(path)")
        }
    }

    /// Nạp lại nhiều lần dùng chung một handle — không `dlopen` mỗi lần gõ phím.
    func testRepeatedLoadsAreCached() {
        let first = SyntaxLanguage.cpp.handle
        let second = SyntaxLanguage.cpp.handle
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }
}
