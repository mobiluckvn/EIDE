import AppKit
import GEditorCore
import JavaScriptCore

/// Chạy script JavaScript trên tài liệu (FR-AUTO-603), và là nền cho plugin dạng script
/// (FR-PLUG-701).
///
/// **Dùng `JavaScriptCore` của hệ thống.** Nó có sẵn trên mọi máy macOS và không thêm một byte
/// nào vào bundle.
///
/// Câu ở đây trước 26/08/2026 viết rằng `import JavaScriptCore` "chỉ nạp khi người dùng chạy
/// script lần đầu — đúng cùng lối với `GrammarLibrary`". **Câu ấy sai**, và `otool -L` trên
/// binary sản phẩm chứng minh: JavaScriptCore nằm trong danh sách liên kết LÚC NẠP, tức mọi
/// lần mở app đều nạp nó. `GrammarLibrary` đi lối khác hẳn — nó `dlopen` thật.
///
/// Đo rồi mới biết sai ấy không tốn gì đáng kể: liên kết JavaScriptCore đắt thêm **1,8 ms trên
/// sàn nhiễu 1,4 ms** (26/08/2026, cùng phương pháp PoC-L), vì framework hệ thống nằm trong dyld
/// shared cache. Thứ thật sự đắt là **dựng `JSContext`**, và việc ấy vẫn lười đúng như mô tả —
/// nay có `LazyLoadAudit.activate("JSContext")` gác, chứ không chỉ có lời hứa trong chú thích.
///
/// **API cố ý HẸP.** Script thấy đúng bốn thứ: đọc văn bản, đọc vùng chọn, thay văn bản, và
/// ghi một dòng nhật ký. Không truy cập file, không mạng, không tạo tiến trình.
///
/// Đó không phải một hàng rào an ninh — script chạy trong cùng tiến trình, và JavaScriptCore
/// không có cơ chế sandbox thật. Nó là một hàng rào THIẾT KẾ: mở rộng bề mặt API về sau thì
/// dễ, thu hẹp lại thì phá mọi script người dùng đã viết. Và mọi thứ script làm được đều đi
/// qua `TextBuffer`, nên vẫn là MỘT bước hoàn tác như mọi thao tác khác.
///
/// **Chạy ở LUỒNG NỀN, có hạn giờ — và giới hạn phải nói thẳng.**
///
/// `while(true){}` trong JavaScript sẽ chạy mãi. JavaScriptCore *có* cơ chế cắt
/// (`JSContextGroupSetExecutionTimeLimit`) nhưng nó nằm trong header riêng tư và Swift không
/// thấy; không có API công khai nào ngắt được một `JSContext` đang chạy.
///
/// Nên ở đây: script chạy trên một luồng nền, và luồng chính chỉ ĐỢI kết quả trong `timeout`
/// giây. Quá hạn thì người dùng nhận câu trả lời và ứng dụng vẫn dùng được — nhưng luồng kia
/// **vẫn quay cho tới khi thoát app**, ăn một lõi CPU. Đó là cái giá, và nó được nói ra ở
/// thông báo cho người dùng chứ không giấu đi.
///
/// Đổi lại được điều quan trọng nhất: một script hỏng không treo cửa sổ. Chạy thẳng ở luồng
/// chính thì người dùng chỉ còn cách Force Quit, và mọi tab chưa lưu đi theo.
enum ScriptRunner {

    static let timeout: TimeInterval = 5

    struct Outcome {
        /// Văn bản mới, hoặc `nil` khi script không thay gì.
        let replacement: String?
        /// Những dòng script gọi `log()`.
        let log: [String]
        /// Lỗi JavaScript, nếu có.
        let failure: String?
    }

    /// Chạy `source` với `text` làm đầu vào.
    ///
    /// - Parameter selection: khoảng byte đang chọn; rỗng nghĩa là không chọn gì.
    static func run(source: String, text: String, selection: Range<Int>) -> Outcome {
        let finished = DispatchSemaphore(value: 0)
        // `nonisolated(unsafe)` không dùng được ở đây vì đây là biến cục bộ; dùng một hộp khoá
        // để luồng nền ghi và luồng chính đọc mà không đua nhau.
        let box = ResultBox()

        Thread.detachNewThread {
            let outcome = evaluate(source: source, text: text, selection: selection)
            box.store(outcome)
            finished.signal()
        }

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            return Outcome(
                replacement: nil, log: [],
                failure: "Script chạy quá \(Int(timeout)) giây. Đã bỏ kết quả; "
                    + L("nó vẫn chiếm một lõi CPU cho tới khi thoát ứng dụng.")
            )
        }
        return box.take() ?? Outcome(replacement: nil, log: [], failure: L("Script không trả về gì"))
    }

    /// Hộp chuyển kết quả giữa hai luồng.
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var outcome: Outcome?

        func store(_ value: Outcome) {
            lock.lock(); defer { lock.unlock() }
            outcome = value
        }

        func take() -> Outcome? {
            lock.lock(); defer { lock.unlock() }
            return outcome
        }
    }

    private static func evaluate(source: String, text: String, selection: Range<Int>) -> Outcome {
        // Bất biến ADR-14: đây là chỗ DUY NHẤT dựng máy JavaScript, nên đóng dấu ở đây là đủ.
        LazyLoadAudit.activate("JSContext")
        guard let context = JSContext() else {
            return Outcome(replacement: nil, log: [], failure: L("Không dựng được máy JavaScript"))
        }

        var log: [String] = []
        var replacement: String?
        var failure: String?

        context.exceptionHandler = { _, exception in
            failure = exception?.toString() ?? L("Lỗi JavaScript không rõ")
        }

        let api = JSValue(newObjectIn: context)
        api?.setObject(text, forKeyedSubscript: "text" as NSString)
        api?.setObject(
            selection.isEmpty ? "" : String(decoding: Array(text.utf8)[selection], as: UTF8.self),
            forKeyedSubscript: "selection" as NSString
        )

        let replace: @convention(block) (String) -> Void = { value in replacement = value }
        api?.setObject(replace, forKeyedSubscript: "replace" as NSString)

        let write: @convention(block) (String) -> Void = { message in
            // Trần số dòng: một script gọi `log()` trong vòng lặp triệu lần sẽ ăn hết RAM
            // trước khi kịp hiện ra chỗ nào.
            if log.count < 1000 { log.append(message) }
        }
        api?.setObject(write, forKeyedSubscript: "log" as NSString)

        context.setObject(api, forKeyedSubscript: "doc" as NSString)
        // FR-KNW-912. Cùng một `JSContext`, nên cùng một hàng rào: hai namespace này cũng chỉ
        // nhận VĂN BẢN và trả DỮ LIỆU — xem ghi chú ở `ScriptKnowledgeAPI`.
        ScriptKnowledgeAPI.install(into: context)
        context.evaluateScript(source)
        return Outcome(replacement: replacement, log: log, failure: failure)
    }

    /// Những script người dùng đặt trong `scripts/`.
    static func availableScripts() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(
            atPath: AppPaths.scriptsDirectory.path
        )) ?? []
        return names.filter { $0.hasSuffix(".js") }.sorted()
            .map { AppPaths.scriptsDirectory.appendingPathComponent($0) }
    }

    /// Script mẫu, ghi ra khi thư mục còn trống.
    ///
    /// Có sẵn một ví dụ chạy được là khác biệt giữa "tính năng có tồn tại" và "tính năng có
    /// người dùng": không ai đọc tài liệu API để viết dòng đầu tiên.
    static let example = """
    // Ví dụ script GEditor (FR-AUTO-603).
    //
    // Những gì script thấy:
    //   doc.text        — toàn văn tài liệu
    //   doc.selection   — phần đang chọn (chuỗi rỗng nếu không chọn gì)
    //   doc.replace(s)  — thay TOÀN VĂN bằng s; một bước hoàn tác
    //   doc.log(s)      — ghi một dòng ra bảng kết quả
    //
    // Ví dụ này đánh số thứ tự cho từng dòng.

    var lines = doc.text.split("\\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
        out.push((i + 1) + ". " + lines[i]);
    }
    doc.log("Đã đánh số " + (lines.length - 1) + " dòng");
    doc.replace(out.join("\\n"));
    \(ScriptKnowledgeAPI.exampleAppendix)
    """
}
