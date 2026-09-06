import AppKit

/// Kiểm marked-text tiếng Việt **bằng máy** — NFR-USE-02, **TC-IME-01** (STP §4).
///
/// Vì sao có cái này thay vì chỉ nhờ người gõ thử: bộ gõ tiếng Việt là tiêu chí CHẶN PHÁT
/// HÀNH. Một tiêu chí chặn phát hành mà chỉ kiểm được bằng tay thì trên thực tế chỉ được kiểm
/// vài lần trong đời dự án, và không lần nào trong số đó nằm ở CI.
///
/// Cách làm: gọi thẳng `NSTextInputClient` — đúng giao thức mà EVKey, OpenKey và bộ gõ
/// Vietnamese của macOS dùng để nói chuyện với ứng dụng. Bộ gõ chặn phím, tự ghép vần, rồi
/// gửi `setMarkedText:` cho từng bước soạn và `insertText:` khi chốt.
///
/// Cái này KHÔNG thay thế được người gõ thật, và ADR-01 phải nói rõ: nó kiểm phía ỨNG DỤNG xử
/// lý đúng giao thức hay không. Nó không kiểm được EVKey có gửi đúng chuỗi ấy hay không, cũng
/// không bắt được lỗi ở tầng phím tắt hay bàn phím vật lý. Cái nó bắt được — nuốt dấu, nhân
/// đôi ký tự, marked-text nhảy vị trí — lại đúng là những lỗi hay gặp nhất.
enum IMEHarness {

    struct Step {
        /// Chuỗi đang soạn mà bộ gõ gửi tới (nil = chốt bằng `insertText`).
        let marked: String?
        let commit: String?
    }

    struct Scenario {
        let name: String
        /// Người dùng gõ gì trên bàn phím (chỉ để ghi vào báo cáo).
        let keystrokes: String
        let steps: [Step]
        let expected: String
        /// Nội dung có sẵn quanh chỗ gõ.
        ///
        /// TC-IME-01 đòi gõ ở ĐẦU, GIỮA và CUỐI dòng, và trước một field CSV có ngoặc kép.
        /// Gõ vào tài liệu rỗng chỉ kiểm được trường hợp dễ nhất.
        var prefix: String = ""
        var suffix: String = ""
    }

    struct Outcome {
        let scenario: String
        let keystrokes: String
        let expected: String
        let actual: String
        let passed: Bool
        let note: String?
    }

    /// Chuỗi marked-text mà bộ gõ Telex gửi khi soạn một âm tiết.
    ///
    /// Từng bước là một trạng thái soạn HOÀN CHỈNH, không phải một ký tự thêm vào: đó chính là
    /// điểm mấu chốt của giao thức. Ứng dụng phải THAY THẾ vùng marked cũ chứ không nối thêm.
    /// Nối thêm là lỗi "nhân đôi ký tự" mà SRS gọi tên ở NFR-USE-02.
    static let scenarios: [Scenario] = [
        Scenario(
            name: "dấu nặng vào đúng nguyên âm",
            keystrokes: "vieejt",
            steps: [
                Step(marked: "v", commit: nil),
                Step(marked: "vi", commit: nil),
                Step(marked: "vie", commit: nil),
                Step(marked: "viê", commit: nil),      // ee → ê
                Step(marked: "viêt", commit: nil),
                Step(marked: "việt", commit: nil),     // j → dấu nặng, lùi vào giữa âm tiết
                Step(marked: nil, commit: "việt"),
            ],
            expected: "việt"
        ),
        Scenario(
            name: "đ ở đầu âm tiết",
            keystrokes: "ddaay",
            steps: [
                Step(marked: "d", commit: nil),
                Step(marked: "đ", commit: nil),        // dd → đ, thay thế chứ không nối
                Step(marked: "đa", commit: nil),
                Step(marked: "đâ", commit: nil),       // aa → â
                Step(marked: "đây", commit: nil),
                Step(marked: nil, commit: "đây"),
            ],
            expected: "đây"
        ),
        Scenario(
            name: "dấu trên nguyên âm chính của nguyên âm đôi",
            keystrokes: "toans",
            steps: [
                Step(marked: "t", commit: nil),
                Step(marked: "to", commit: nil),
                Step(marked: "toa", commit: nil),
                Step(marked: "toan", commit: nil),
                Step(marked: "toán", commit: nil),     // s → sắc, nhảy vào giữa
                Step(marked: nil, commit: "toán"),
            ],
            expected: "toán"
        ),
        Scenario(
            name: "bỏ soạn giữa chừng (Esc)",
            keystrokes: "vieej + Esc",
            steps: [
                Step(marked: "v", commit: nil),
                Step(marked: "vi", commit: nil),
                Step(marked: "viê", commit: nil),
                Step(marked: "việ", commit: nil),
                Step(marked: "", commit: nil),         // huỷ: marked rỗng
            ],
            expected: ""
        ),
        Scenario(
            name: "soạn tiếp sau một âm tiết đã chốt",
            keystrokes: "vieejt Nam",
            steps: [
                Step(marked: nil, commit: "việt "),
                Step(marked: "N", commit: nil),
                Step(marked: "Na", commit: nil),
                Step(marked: "Nam", commit: nil),
                Step(marked: nil, commit: "Nam"),
            ],
            expected: "việt Nam"
        ),
        Scenario(
            name: "gõ vào GIỮA dòng có sẵn",
            keystrokes: "vieejt",
            steps: [
                Step(marked: "v", commit: nil),
                Step(marked: "vi", commit: nil),
                Step(marked: "viê", commit: nil),
                Step(marked: "việt", commit: nil),
                Step(marked: nil, commit: "việt"),
            ],
            expected: "Tiếng việt Nam",
            prefix: "Tiếng ", suffix: " Nam"
        ),
        Scenario(
            name: "gõ trước field CSV có ngoặc kép",
            keystrokes: "hoaf",
            steps: [
                Step(marked: "h", commit: nil),
                Step(marked: "ho", commit: nil),
                Step(marked: "hoa", commit: nil),
                Step(marked: "hoà", commit: nil),
                Step(marked: nil, commit: "hoà"),
            ],
            expected: "mã,hoà,\"Công ty, CN Huế\"",
            prefix: "mã,", suffix: ",\"Công ty, CN Huế\""
        ),
    ]

    /// Chạy một kịch bản trên một `NSTextInputClient`.
    ///
    /// - Parameters:
    ///   - client: chỗ bộ gõ gửi vào.
    ///   - readText: đọc lại toàn bộ nội dung tài liệu.
    ///   - reset: đưa tài liệu về rỗng trước mỗi kịch bản.
    /// - Parameter placeCaret: đặt con trỏ ngay SAU đoạn văn bản truyền vào.
    ///
    ///   Do engine tự làm, không do bộ đo: Scintilla đếm byte còn `NSTextView` đếm đơn vị
    ///   UTF-16, và "Tiếng " là 6 ký tự nhưng 8 byte. Bản đầu tôi ép kiểu `client as? NSTextView`
    ///   nên với Scintilla phép ép hỏng, caret nằm nguyên ở cuối, và bộ đo báo Scintilla TRƯỢT
    ///   hai kịch bản mà lỗi hoàn toàn thuộc về bộ đo.
    static func run(
        _ scenario: Scenario,
        client: NSTextInputClient,
        readText: () -> String,
        reset: () -> Void,
        placeCaret: (String) -> Void
    ) -> Outcome {
        reset()

        // Dựng bối cảnh rồi đặt caret vào giữa: gõ ở đầu tài liệu rỗng là trường hợp dễ nhất
        // và không đại diện cho việc người dùng thật đang làm.
        if !scenario.prefix.isEmpty || !scenario.suffix.isEmpty {
            client.insertText(
                scenario.prefix + scenario.suffix,
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
            client.unmarkText()
            placeCaret(scenario.prefix)
        }

        for step in scenario.steps {
            if let marked = step.marked {
                // `replacementRange` là NSNotFound: bộ gõ nói "thay vùng marked hiện tại".
                client.setMarkedText(
                    marked,
                    selectedRange: NSRange(location: marked.utf16.count, length: 0),
                    replacementRange: NSRange(location: NSNotFound, length: 0)
                )
            }
            if let commit = step.commit {
                client.insertText(commit, replacementRange: NSRange(location: NSNotFound, length: 0))
                client.unmarkText()
            }
        }

        let actual = readText()
        // So sánh theo NFC: bộ gõ có thể gửi tổ hợp, và "việt" dựng sẵn với "việt" tổ hợp là
        // cùng một chữ với người dùng. Khác biệt NFC/NFD là việc của tầng lưu file, không phải
        // chỗ để đánh trượt engine hiển thị.
        let passed = actual.precomposedStringWithCanonicalMapping
            == scenario.expected.precomposedStringWithCanonicalMapping

        var note: String?
        if !passed {
            let expectedCount = scenario.expected.count
            if actual.count > expectedCount, actual.hasPrefix(scenario.expected) {
                note = "nội dung DÀI hơn mong đợi — nhiều khả năng nối thêm thay vì thay vùng marked"
            } else if actual.count < expectedCount {
                note = "nội dung NGẮN hơn mong đợi — nhiều khả năng nuốt dấu"
            }
        }

        return Outcome(
            scenario: scenario.name, keystrokes: scenario.keystrokes,
            expected: scenario.expected, actual: actual, passed: passed, note: note
        )
    }

    static func report(_ engine: String, _ outcomes: [Outcome]) -> String {
        var lines = ["── Bộ gõ tiếng Việt · \(engine) ──"]
        for outcome in outcomes {
            let mark = outcome.passed ? "✅" : "❌"
            lines.append("  \(mark) \(outcome.scenario)  [\(outcome.keystrokes)]")
            if !outcome.passed {
                lines.append("      mong đợi \(quoted(outcome.expected))  nhận \(quoted(outcome.actual))")
                if let note = outcome.note { lines.append("      \(note)") }
            }
        }
        let failed = outcomes.filter { !$0.passed }.count
        lines.append(failed == 0
            ? "  → \(outcomes.count)/\(outcomes.count) đạt"
            : "  → \(outcomes.count - failed)/\(outcomes.count) đạt, \(failed) TRƯỢT")
        return lines.joined(separator: "\n")
    }

    private static func quoted(_ text: String) -> String {
        "\"\(text)\" (\(text.count) ký tự)"
    }
}

/// Đối chứng âm: một `NSTextInputClient` mắc đúng lỗi kinh điển — NỐI THÊM chuỗi đang soạn
/// thay vì THAY THẾ vùng marked cũ.
///
/// Có mặt vì một phép kiểm luôn xanh thì không kiểm gì cả. Nếu `IMEHarness` không bắt được
/// lớp này thì mọi dấu ✅ ở trên đều vô nghĩa, và bản thân điều đó phải hiện trong báo cáo
/// chứ không nằm trong đầu người viết.
final class DeliberatelyBrokenInputClient: NSObject, NSTextInputClient {

    private(set) var text = ""

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        text += (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        text += (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
    }

    func unmarkText() {}
    func doCommand(by selector: Selector) {}
    func selectedRange() -> NSRange { NSRange(location: text.utf16.count, length: 0) }
    func markedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
    func hasMarkedText() -> Bool { false }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? { nil }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect { .zero }
    func characterIndex(for point: NSPoint) -> Int { 0 }

    func reset() { text = "" }
}
