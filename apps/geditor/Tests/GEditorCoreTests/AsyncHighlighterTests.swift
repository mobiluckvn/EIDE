import XCTest
@testable import GEditorCore

/// Tô màu chạy ngoài luồng chính (ADR-04 §3).
final class AsyncHighlighterTests: XCTestCase {

    private func waitForResult(
        _ highlighter: AsyncHighlighter, buffer: TextBuffer, range: Range<Int>,
        timeout: TimeInterval = 10
    ) -> AsyncHighlighter.Result? {
        let done = DispatchSemaphore(value: 0)
        var result: AsyncHighlighter.Result?
        // Trả về hàng đợi RIÊNG, không phải `.main`: test chạy trên luồng chính và chặn nó,
        // nên giao kết quả về `.main` sẽ khoá cứng. Đã dính đúng kiểu này ở test cầu nối CLI.
        let delivery = DispatchQueue(label: "test.delivery")
        highlighter.request(buffer: buffer, range: range, deliverOn: delivery) {
            result = $0
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout)
        return result
    }

    func testDeliversSpansOffTheCallingThread() {
        let buffer = TextBuffer(text: "int main(void) { return 0; }\n")
        let highlighter = AsyncHighlighter(language: .c)!
        let result = waitForResult(highlighter, buffer: buffer, range: 0 ..< buffer.count)

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.spans.isEmpty ?? true)
        XCTAssertEqual(result?.range, 0 ..< buffer.count)
    }

    func testResultMatchesTheSynchronousPath() {
        let buffer = TextBuffer(text: "int a = 1;\nconst char *s = \"chao\";\nint b = 2;\n")
        let sync = SyntaxHighlighter(language: .c)!.spans(in: buffer, range: 0 ..< buffer.count)
        let async = waitForResult(
            AsyncHighlighter(language: .c)!, buffer: buffer, range: 0 ..< buffer.count
        )
        XCTAssertEqual(async?.spans, sync, "đường nền phải cho ĐÚNG kết quả như đường đồng bộ")
    }

    /// Kết quả CŨ phải bị bỏ.
    ///
    /// Người dùng cuộn nhanh thì nhiều yêu cầu chồng nhau. Kết quả về muộn của một cửa sổ đã
    /// trôi qua sẽ tô lên nội dung khác hẳn — màu đúng, chỗ sai.
    func testStaleResultsAreDropped() {
        var text = ""
        while text.utf8.count < 600_000 { text += "int ham_x(int a) { return a + 1; }\n" }
        let buffer = TextBuffer(text: text)
        let highlighter = AsyncHighlighter(language: .c)!

        let delivery = DispatchQueue(label: "test.delivery")
        let lock = NSLock()
        var delivered: [Int] = []
        let done = DispatchSemaphore(value: 0)

        var lastGeneration = 0
        for index in 0 ..< 8 {
            let start = index * 50_000
            lastGeneration = highlighter.request(
                buffer: buffer, range: start ..< (start + 20_000), deliverOn: delivery
            ) { result in
                lock.lock()
                delivered.append(result.generation)
                lock.unlock()
                done.signal()
            }
        }

        _ = done.wait(timeout: .now() + 20)
        // Chờ thêm một nhịp để bắt được kết quả cũ nào lỡ về muộn.
        Thread.sleep(forTimeInterval: 1.0)

        lock.lock()
        let seen = delivered
        lock.unlock()

        XCTAssertFalse(seen.isEmpty, "phải có ít nhất một kết quả về")
        XCTAssertTrue(seen.allSatisfy { $0 == lastGeneration },
                      "có kết quả CŨ lọt về: \(seen), mới nhất là \(lastGeneration)")
    }

    func testCancelStopsDelivery() {
        var text = ""
        while text.utf8.count < 600_000 { text += "int ham_y(int a) { return a + 1; }\n" }
        let buffer = TextBuffer(text: text)
        let highlighter = AsyncHighlighter(language: .c)!

        let delivery = DispatchQueue(label: "test.delivery")
        var delivered = false
        highlighter.request(buffer: buffer, range: 0 ..< 200_000, deliverOn: delivery) { _ in
            delivered = true
        }
        highlighter.cancel()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertFalse(delivered, "đã huỷ mà vẫn giao kết quả")
    }

    /// Sửa buffer NGAY SAU khi phát yêu cầu không được làm sập gì.
    ///
    /// Đây là lý do yêu cầu phải mang BẢN SAO byte. Nếu nó giữ tham chiếu tới buffer, luồng
    /// nền sẽ đọc vào vùng nhớ mà luồng chính vừa dời đi — và kiểu hỏng ấy không phải "sai
    /// màu", nó là sập ứng dụng hoặc rác.
    func testEditingRightAfterRequestingIsSafe() {
        var text = ""
        while text.utf8.count < 300_000 { text += "int ham_z(int a) { return a + 1; }\n" }
        let buffer = TextBuffer(text: text)
        let highlighter = AsyncHighlighter(language: .c)!
        let delivery = DispatchQueue(label: "test.delivery")

        for round in 0 ..< 30 {
            highlighter.request(buffer: buffer, range: 100_000 ..< 140_000, deliverOn: delivery) { _ in }
            // Sửa ngay, y như người dùng gõ trong lúc màn hình đang chờ tô.
            buffer.applyEdits(
                [TextEdit(range: 1_000 ..< 1_000, text: "x")], label: "gõ \(round)"
            )
        }
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertGreaterThan(buffer.count, 300_000, "buffer vẫn còn nguyên vẹn")
    }

    /// YAML file LỚN giờ tô được qua đường nền.
    ///
    /// Bài này trước đây khẳng định điều NGƯỢC LẠI — "trả về rỗng thay vì đoán" — và đó là
    /// hành vi đúng khi chưa biết vì sao lát cắt YAML hỏng. Khi đã truy ra nguyên nhân (thiếu
    /// gốc toạ độ thụt lề, ADR-04 §2.6) thì cách sửa tốt hơn hẳn là dóng biên về cột 0, và
    /// bài kiểm phải đi theo hành vi mới chứ không giữ hành vi cũ cho khỏi phải sửa.
    func testYamlHighlightsLargeDocumentsThroughTheBackgroundPath() {
        var text = ""
        while text.utf8.count < 400_000 { text += "muc:\n  ten: A\n  so: 1\n" }
        let buffer = TextBuffer(text: text)
        let highlighter = AsyncHighlighter(language: .yaml)!
        let result = waitForResult(highlighter, buffer: buffer, range: 200_000 ..< 210_000)

        XCTAssertNotNil(result, "phải trả lời")
        XCTAssertFalse(result?.spans.isEmpty ?? true, "YAML file lớn phải tô được")
    }

    /// Tài liệu rỗng vẫn phải TRẢ LỜI, không im lặng.
    ///
    /// Im lặng thì chỗ gọi không có dịp xoá màu của cửa sổ trước, và màu cũ nằm lại trên chữ
    /// mới — tệ hơn hẳn so với không tô gì.
    func testEmptyDocumentStillAnswers() {
        let highlighter = AsyncHighlighter(language: .yaml)!
        let result = waitForResult(highlighter, buffer: TextBuffer(text: ""), range: 0 ..< 0)
        XCTAssertNotNil(result, "phải trả lời, dù là rỗng")
        XCTAssertTrue(result?.spans.isEmpty ?? false)
    }

    func testEmptyBufferAnswers() {
        let highlighter = AsyncHighlighter(language: .json)!
        let result = waitForResult(highlighter, buffer: TextBuffer(text: ""), range: 0 ..< 0)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.spans.isEmpty ?? false)
    }
}
