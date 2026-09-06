import Foundation

/// Chạy macro trên một buffer (FR-AUTO-602).
///
/// Chạy ở LÕI chứ không ở lớp giao diện, vì ba lý do:
///
/// 1. **Kiểm được.** "Chạy 100 lần cho kết quả giống làm tay 100 lần" (TC-AUTO-01) là một câu
///    khẳng định về văn bản, không phải về màn hình.
/// 2. **Chạy được trên tab không hiển thị.** SRS đòi chạy macro trên MỌI tab đang mở; tab
///    không hiển thị thì không có khung soạn thảo nào để giả lập phím.
/// 3. **Sẽ dùng lại được cho batch theo thư mục** (FR-AUTO-602 Phase 2), nơi file còn chưa mở.
public final class MacroRunner {

    /// Vùng chọn hiện tại; rỗng nghĩa là chỉ có con trỏ.
    public private(set) var selection: Range<Int>
    /// Kết quả khớp gần nhất — để `$1` của bước thay thế còn biết nhóm bắt của regex nào.
    private var lastMatch: SearchMatch?
    private var lastPattern: PCRE2Pattern?

    private let buffer: TextBuffer

    public init(buffer: TextBuffer, caretOffset: Int = 0) {
        self.buffer = buffer
        let clamped = Swift.min(Swift.max(caretOffset, 0), buffer.count)
        selection = clamped ..< clamped
    }

    public var caretOffset: Int { selection.upperBound }

    /// Chạy macro `repetitions` lần. `repetitions == 0` nghĩa là CHẠY TỚI KHI DỪNG ĐƯỢC.
    ///
    /// "Tới khi dừng được" là cách FR-AUTO-602 gọi "chạy đến cuối file": macro tự dừng khi một
    /// bước `find` không còn tìm thấy gì, hoặc khi con trỏ hết đường đi.
    ///
    /// **Chặn vòng lặp vô hạn là bắt buộc, không phải phòng xa.** TC-AUTO-02 nêu đích danh
    /// "không lặp vô hạn". Một macro không sửa gì và không dời con trỏ sẽ chạy mãi, và người
    /// dùng chỉ thấy ứng dụng treo. Nên: một vòng không đổi CẢ nội dung lẫn vị trí con trỏ thì
    /// dừng ngay.
    ///
    /// Toàn bộ lần chạy là MỘT bước undo (FR-CORE-004) — xem `TextBuffer.beginUndoGroup`.
    @discardableResult
    public func run(
        _ macro: Macro,
        repetitions: Int,
        cancelToken: CancelToken = CancelToken(),
        undoLabel: String? = nil
    ) -> MacroResult {
        guard !macro.isEmpty else {
            return MacroResult(repetitions: 0, reason: .finished, caretOffset: caretOffset)
        }

        buffer.beginUndoGroup(label: undoLabel ?? "Macro «\(macro.name)»")
        defer { buffer.endUndoGroup() }

        var done = 0
        let unlimited = repetitions <= 0

        while unlimited || done < repetitions {
            if (try? cancelToken.check()) == nil {
                return MacroResult(repetitions: done, reason: .cancelled, caretOffset: caretOffset)
            }

            let byteCountBefore = buffer.count
            let caretBefore = caretOffset
            let versionBefore = buffer.undoDepth

            for step in macro.steps {
                switch perform(step, cancelToken: cancelToken) {
                case .ok:
                    continue
                case .stop(let reason):
                    return MacroResult(repetitions: done, reason: reason, caretOffset: caretOffset)
                }
            }
            done += 1

            guard unlimited else { continue }
            // Chỉ xét "có tiến triển không" khi chạy KHÔNG giới hạn: chạy đúng N lần thì người
            // dùng đã nói rõ họ muốn bao nhiêu lần, kể cả khi mỗi lần không đổi gì.
            let changedText = buffer.count != byteCountBefore || buffer.undoDepth != versionBefore
            if !changedText, caretOffset == caretBefore {
                return MacroResult(repetitions: done, reason: .madeNoProgress, caretOffset: caretOffset)
            }
        }

        return MacroResult(repetitions: done, reason: .finished, caretOffset: caretOffset)
    }

    // MARK: - Từng bước

    private enum Outcome {
        case ok
        case stop(MacroStopReason)
    }

    private func perform(_ step: MacroStep, cancelToken: CancelToken) -> Outcome {
        switch step {
        case .insert(let text):
            apply(TextEdit(range: selection, text: text), label: "Gõ")
            let end = selection.lowerBound + text.utf8.count
            selection = end ..< end
            return .ok

        case .deleteBackward:
            if !selection.isEmpty {
                apply(TextEdit(range: selection, bytes: []), label: "Xóa")
                selection = selection.lowerBound ..< selection.lowerBound
                return .ok
            }
            guard selection.lowerBound > 0 else { return .ok }
            let start = buffer.previousCharacterBoundary(before: selection.lowerBound)
            apply(TextEdit(range: start ..< selection.lowerBound, bytes: []), label: "Xóa")
            selection = start ..< start
            return .ok

        case .deleteForward:
            if !selection.isEmpty {
                apply(TextEdit(range: selection, bytes: []), label: "Xóa")
                selection = selection.lowerBound ..< selection.lowerBound
                return .ok
            }
            guard selection.lowerBound < buffer.count else { return .ok }
            let end = buffer.nextCharacterBoundary(after: selection.lowerBound)
            apply(TextEdit(range: selection.lowerBound ..< end, bytes: []), label: "Xóa")
            return .ok

        case .move(let move):
            return performMove(move)

        case .selectLine:
            let line = buffer.lineNumber(atOffset: Swift.min(caretOffset, Swift.max(buffer.count - 1, 0)))
            selection = buffer.contentRange(ofLine: line)
            return .ok

        case .find(let pattern, let mode, let matchCase, let wholeWord):
            return performFind(pattern, mode, matchCase, wholeWord, cancelToken)

        case .replaceSelection(let template):
            return performReplace(template)
        }
    }

    private func performMove(_ move: MacroMove) -> Outcome {
        let count = buffer.count
        let line = buffer.lineNumber(atOffset: Swift.min(caretOffset, Swift.max(count - 1, 0)))

        switch move {
        case .left:
            let target = selection.isEmpty
                ? buffer.previousCharacterBoundary(before: selection.lowerBound)
                : selection.lowerBound
            selection = target ..< target
        case .right:
            let target = selection.isEmpty
                ? buffer.nextCharacterBoundary(after: selection.upperBound)
                : selection.upperBound
            selection = target ..< target
        case .lineStart:
            let target = buffer.offset(ofLineStart: line)
            selection = target ..< target
        case .lineEnd:
            let target = buffer.contentRange(ofLine: line).upperBound
            selection = target ..< target
        case .up, .previousLine:
            guard line > 0 else { return .ok }
            let target = buffer.offset(ofLineStart: line - 1)
            selection = target ..< target
        case .down, .nextLine:
            // Cuối tài liệu thì DỪNG macro, không đứng im: đây là cách một macro "xử lý từng
            // dòng" biết mình đã hết việc (TC-AUTO-02).
            guard line + 1 < buffer.lineCount else { return .stop(.endOfDocument) }
            let target = buffer.offset(ofLineStart: line + 1)
            selection = target ..< target
        case .documentStart:
            selection = 0 ..< 0
        case .documentEnd:
            selection = count ..< count
        }
        return .ok
    }

    private func performFind(
        _ pattern: String, _ mode: SearchMode, _ matchCase: Bool, _ wholeWord: Bool,
        _ cancelToken: CancelToken
    ) -> Outcome {
        let options = SearchOptions(mode: mode, matchCase: matchCase, wholeWord: wholeWord)
        do {
            let compiled = try PCRE2Pattern(pattern: pattern, options: options)
            // KHÔNG quay vòng khi chạy trong macro.
            //
            // Quay vòng là đúng cho ⌘D (người dùng bấm và nhìn), nhưng trong macro nó biến
            // "chạy đến cuối file" thành chạy mãi: tới cuối thì quay về đầu và làm lại từ đầu.
            guard let match = try DocumentSearch.findNext(
                pattern: compiled, in: buffer, from: caretOffset,
                wrap: false, cancelToken: cancelToken
            ) else {
                return .stop(.notFound)
            }
            lastMatch = match
            lastPattern = compiled
            selection = match.range
            return .ok
        } catch is CancellationError {
            return .stop(.cancelled)
        } catch {
            return .stop(.error(String(describing: error)))
        }
    }

    private func performReplace(_ template: String) -> Outcome {
        let text: String
        if let match = lastMatch, match.range == selection, let pattern = lastPattern {
            text = expand(template, match: match, pattern: pattern)
        } else {
            text = template
        }
        apply(TextEdit(range: selection, text: text), label: "Thay thế")
        let end = selection.lowerBound + text.utf8.count
        selection = end ..< end
        lastMatch = nil
        return .ok
    }

    /// Thay `$0`…`$9` bằng nhóm bắt của lần khớp vừa rồi.
    ///
    /// Chỉ xử lý `$n`, không xử lý `\U \L` như ô Thay thế của FR-SRCH-103: bộ biến đổi ấy nằm
    /// trong engine PCRE2 và chỉ dùng được khi thay hàng loạt. Nói rõ giới hạn thay vì làm một
    /// nửa rồi để người dùng đoán.
    private func expand(_ template: String, match: SearchMatch, pattern: PCRE2Pattern) -> String {
        guard template.contains("$") else { return template }
        var result = ""
        var iterator = template.makeIterator()
        var pending: Character?

        while let character = pending ?? iterator.next() {
            pending = nil
            guard character == "$" else {
                result.append(character)
                continue
            }
            guard let next = iterator.next() else {
                result.append("$")
                break
            }
            // `$0` là CẢ chỗ khớp; `$1` là nhóm bắt thứ nhất, tức `groups[0]`.
            //
            // Lệch một ở đây là loại sai im lặng nhất có thể: `$1` lấy nhầm `$2`, và chỉ lộ ra
            // khi regex có từ hai nhóm trở lên. Bài kiểm bắt được vì nó dùng đúng một nhóm và
            // ra "name[$1]" nguyên xi.
            guard let index = next.wholeNumberValue, index >= 0 else {
                result.append("$")
                pending = next
                continue
            }
            let range: Range<Int>?
            if index == 0 {
                range = match.range
            } else {
                range = index - 1 < match.groups.count ? match.groups[index - 1] : nil
            }
            guard let range else {
                result.append("$")
                pending = next
                continue
            }
            result += String(decoding: buffer.bytes(in: range), as: UTF8.self)
        }
        return result
    }

    private func apply(_ edit: TextEdit, label: String) {
        buffer.applyEdits([edit], label: label)
    }
}
