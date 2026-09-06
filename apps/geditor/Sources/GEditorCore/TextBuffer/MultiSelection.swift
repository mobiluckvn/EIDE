import Foundation

/// Nhiều caret / nhiều vùng chọn cùng lúc (FR-CORE-001).
///
/// `NSTextView` chỉ có MỘT caret gõ được, nên toàn bộ mô hình này là của GEditor — đó chính là
/// cái giá đã được chấp nhận khi chốt ADR-01.
///
/// Ba bất biến, giữ ở mọi lúc:
///
/// 1. **Sắp tăng dần theo vị trí.** Mọi phép sinh `TextEdit` dựa vào thứ tự này.
/// 2. **Không chồng nhau.** Hai caret trùng chỗ thì gõ một ký tự sẽ chèn hai lần; hai vùng chọn
///    chồng nhau thì xóa sẽ xóa hai lần cùng một đoạn. Thêm vào là GỘP ngay.
/// 3. **Luôn có ít nhất một.** Không có caret nào thì không gõ được gì, và mọi chỗ gọi sẽ phải
///    xử lý một trạng thái rỗng vô nghĩa.
public struct MultiSelection: Equatable {

    /// Các vùng chọn, tính bằng offset byte của tài liệu. Vùng rỗng = một caret.
    public private(set) var ranges: [Range<Int>]

    /// Vùng "chính" — chỗ màn hình cuộn theo, và chỗ `NSTextView` đặt caret thật của nó.
    public private(set) var primaryIndex: Int

    public init(caretAt offset: Int = 0) {
        ranges = [offset ..< offset]
        primaryIndex = 0
    }

    public init(_ ranges: [Range<Int>], primaryIndex: Int = 0) {
        let normalized = Self.normalize(ranges)
        self.ranges = normalized.isEmpty ? [0 ..< 0] : normalized
        self.primaryIndex = Swift.min(Swift.max(primaryIndex, 0), self.ranges.count - 1)
    }

    /// Bản thu về nằm gọn trong một tài liệu dài `limit` byte.
    ///
    /// **Vì sao cần.** Vùng chọn sống trong tầng giao diện, nội dung sống trong buffer, và hai
    /// thứ ấy đổi ở hai nhịp khác nhau: ngay sau một lần sửa làm tài liệu ngắn đi — hoặc sau
    /// khi đổi sang tab có tài liệu ngắn hơn — vùng chọn còn trỏ vào tài liệu CŨ. Mọi hàm đọc
    /// buffer đều có `precondition`, nên một vùng chọn lạc hậu không làm hiện sai một con số:
    /// nó làm app SẬP.
    ///
    /// Bộ chạy dài `--soak` (NFR-REL-03) tìm ra ba lần sập thuộc đúng họ này.
    public func clamped(to limit: Int) -> MultiSelection {
        let bounded = ranges.map { range -> Range<Int> in
            let lower = Swift.min(Swift.max(range.lowerBound, 0), limit)
            let upper = Swift.min(Swift.max(range.upperBound, lower), limit)
            return lower ..< upper
        }
        return MultiSelection(bounded, primaryIndex: primaryIndex)
    }

    public var count: Int { ranges.count }
    public var isMultiple: Bool { ranges.count > 1 }
    public var primary: Range<Int> { ranges[primaryIndex] }

    /// Có vùng chọn thật (không phải chỉ là caret) hay không.
    public var hasSelection: Bool { ranges.contains { !$0.isEmpty } }

    // MARK: - Dựng

    /// Gộp các vùng chồng nhau hoặc chạm nhau, rồi sắp tăng dần.
    ///
    /// Chạm nhau cũng gộp: hai caret liền kề ở cùng một chỗ là một caret, và giữ cả hai chỉ
    /// làm mọi thao tác nhân đôi.
    private static func normalize(_ input: [Range<Int>]) -> [Range<Int>] {
        let sorted = input.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [Range<Int>] = []
        for range in sorted {
            guard let last = merged.last else { merged.append(range); continue }
            if range.lowerBound <= last.upperBound {
                // Hai caret RỖNG ở đúng cùng một offset mới gộp; caret rỗng nằm ở biên một
                // vùng chọn thì vẫn là hai thứ khác nhau với người dùng.
                if range.isEmpty && last.isEmpty && range.lowerBound == last.lowerBound { continue }
                merged[merged.count - 1] = last.lowerBound ..< Swift.max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    /// Thêm một caret hoặc vùng chọn (Cmd+Click, Cmd+D).
    ///
    /// Vùng mới thành vùng CHÍNH: người dùng vừa trỏ vào đó, nên màn hình phải theo nó.
    public mutating func add(_ range: Range<Int>) {
        let combined = Self.normalize(ranges + [range])
        // Tìm lại vùng chứa chỗ vừa thêm — sau khi gộp, chỉ số cũ không còn nghĩa.
        primaryIndex = combined.firstIndex { $0.lowerBound <= range.lowerBound && range.upperBound <= $0.upperBound }
            ?? combined.firstIndex { $0.contains(range.lowerBound) }
            ?? 0
        ranges = combined
    }

    /// Bỏ mọi caret trừ vùng chính (Esc).
    public mutating func collapseToPrimary() {
        ranges = [ranges[primaryIndex]]
        primaryIndex = 0
    }

    public mutating func setSingle(_ range: Range<Int>) {
        ranges = [range]
        primaryIndex = 0
    }

    // MARK: - Sinh sửa đổi

    /// Chèn `text` tại MỌI caret, thay thế vùng đang chọn nếu có.
    ///
    /// Trả về `[TextEdit]` để chỗ gọi áp bằng MỘT `applyEdits` — gõ một ký tự với 1.000 caret
    /// vẫn phải là MỘT bước undo (FR-CORE-004).
    public func edits(inserting text: String) -> [TextEdit] {
        ranges.map { TextEdit(range: $0, text: text) }
    }

    /// Xóa lùi (Backspace) tại mọi caret.
    ///
    /// Có vùng chọn thì xóa vùng; chỉ có caret thì xóa MỘT KÝ TỰ phía trước — không phải một
    /// byte. Xóa một byte sẽ cắt đôi chữ có dấu và tạo ra byte rác.
    /// **Vùng xoá của một caret không được thò vào vùng chọn đứng trước nó.**
    ///
    /// Các vùng chọn không chồng nhau (bất biến 2), nhưng chúng CHẠM nhau được: `[5,8)` rồi
    /// caret `[8,8)`. Caret ấy xoá lùi một ký tự thành `[7,8)` — nằm gọn trong `[5,8)`. Hai
    /// vùng sửa giao nhau, mà `applyEdits` có `precondition` cho bất biến ấy: app SẬP.
    ///
    /// Người dùng tới đây dễ: ⌘D chọn một từ, Cmd+Click thêm caret ngay sau từ đó, rồi
    /// Backspace. Bộ chạy dài `--soak` bắt được ở hạt giống 3 (NFR-REL-03).
    ///
    /// Kẹp bằng mép phải của vùng sửa TRƯỚC ĐÓ. Caret không còn gì để xoá thì bỏ hẳn nó ra —
    /// vùng chọn đứng trước đã xoá phần ấy rồi.
    public func editsDeletingBackward(in buffer: TextBuffer) -> [TextEdit] {
        var edits: [TextEdit] = []
        var previousUpper = 0
        for range in ranges {
            if !range.isEmpty {
                edits.append(TextEdit(range: range, bytes: []))
                previousUpper = range.upperBound
                continue
            }
            guard range.lowerBound > 0 else { continue }
            let start = Swift.max(
                buffer.previousCharacterBoundary(before: range.lowerBound), previousUpper)
            guard start < range.lowerBound else { continue }
            edits.append(TextEdit(range: start ..< range.lowerBound, bytes: []))
            previousUpper = range.lowerBound
        }
        return edits
    }

    /// Xóa tới (Delete) tại mọi caret.
    /// Chiều ngược lại của `editsDeletingBackward`, và cùng cái bẫy: caret `[8,8)` đứng ngay
    /// TRƯỚC vùng chọn `[8,12)` thì phép xoá tới của nó thò vào chính vùng ấy.
    public func editsDeletingForward(in buffer: TextBuffer) -> [TextEdit] {
        var edits: [TextEdit] = []
        for (index, range) in ranges.enumerated() {
            if !range.isEmpty {
                edits.append(TextEdit(range: range, bytes: []))
                continue
            }
            guard range.lowerBound < buffer.count else { continue }
            let nextLower = index + 1 < ranges.count ? ranges[index + 1].lowerBound : buffer.count
            let end = Swift.min(buffer.nextCharacterBoundary(after: range.lowerBound), nextLower)
            guard end > range.lowerBound else { continue }
            edits.append(TextEdit(range: range.lowerBound ..< end, bytes: []))
        }
        return edits
    }

    /// Vị trí các caret SAU khi áp một loạt sửa đổi.
    ///
    /// Phải tính lại chứ không giữ nguyên: chèn "x" vào ba caret thì caret thứ hai và thứ ba
    /// đã dịch đi 1 và 2 byte. Không tính lại thì caret trôi dần và lần gõ sau rơi sai chỗ —
    /// lỗi chỉ lộ ra từ ký tự thứ hai trở đi.
    public func afterApplying(_ edits: [TextEdit]) -> MultiSelection {
        guard !edits.isEmpty else { return self }

        // Suy vị trí caret TỪ CHÍNH các sửa đổi, không từ vùng chọn cũ.
        //
        // Bản đầu cộng dồn chênh lệch của mọi sửa đổi có `lowerBound <= range.lowerBound`, tức
        // là cộng cả chênh lệch của sửa đổi ĐANG THAY chính vùng ấy — caret lùi về đầu vùng
        // thay vì nhảy tới cuối phần vừa gõ. Hậu quả: ký tự ĐẦU thay đúng cả ba caret, ký tự
        // thứ hai trở đi dồn hết vào một chỗ. Chỉ lộ ra khi gõ từ hai ký tự trở lên.
        let sorted = edits.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var shift = 0
        var carets: [Range<Int>] = []
        for edit in sorted {
            let position = edit.range.lowerBound + shift + edit.bytes.count
            carets.append(position ..< position)
            shift += edit.bytes.count - edit.range.count
        }
        return MultiSelection(carets, primaryIndex: Swift.min(primaryIndex, carets.count - 1))
    }
}

public enum OccurrenceSearch {

    /// Lần xuất hiện KẾ TIẾP của `needle`, tính từ `offset`, quay vòng về đầu tài liệu.
    ///
    /// Quay vòng là chủ ý: Cmd+D tới kết quả cuối rồi bấm tiếp phải quay lại từ đầu, nếu không
    /// người dùng tưởng lệnh hỏng. Trả `nil` chỉ khi tài liệu KHÔNG có lần nào.
    public static func next(
        _ needle: [UInt8], in buffer: TextBuffer, after offset: Int
    ) -> Range<Int>? {
        guard !needle.isEmpty, needle.count <= buffer.count else { return nil }
        if let found = find(needle, in: buffer, from: offset) { return found }
        return find(needle, in: buffer, from: 0)
    }

    /// Vùng "từ" quanh `offset` — dùng khi bấm Cmd+D lúc chưa chọn gì.
    public static func word(at offset: Int, in buffer: TextBuffer) -> Range<Int> {
        func isWordByte(_ byte: UInt8) -> Bool {
            // Byte ngoài ASCII đều tính là chữ: đó là cách rẻ và đúng để "Nguyễn" thành MỘT từ
            // mà không phải giải mã UTF-8 ở đây.
            byte >= 0x80 || (byte | 0x20) >= 0x61 && (byte | 0x20) <= 0x7A
                || (byte >= 0x30 && byte <= 0x39) || byte == UInt8(ascii: "_")
        }

        // Đi theo LÔ, không theo từng byte.
        //
        // `buffer.bytes(in:)` cấp phát một mảng ở mỗi lần gọi, nên hỏi từng byte là một lần cấp
        // phát mỗi byte — và vòng lặp ở đây KHÔNG có trần: nó chạy tới hết từ. Đo được: ⌘D
        // giữa một từ dài 1 MB (một chuỗi base64, một token JSON thu gọn) tốn **463 ms**, tức
        // app đứng hình nửa giây ở một phím tắt người ta bấm liên tục.
        let position = Swift.min(Swift.max(offset, 0), buffer.count)
        return wordStart(before: position, in: buffer, isWordByte)
            ..< wordEnd(after: position, in: buffer, isWordByte)
    }

    /// Bao nhiêu byte đọc một lần khi dò biên từ. Đủ lớn để một từ thật nằm gọn trong một lô.
    private static let wordChunk = 4096

    private static func wordStart(
        before offset: Int, in buffer: TextBuffer, _ isWordByte: (UInt8) -> Bool
    ) -> Int {
        var lower = offset
        while lower > 0 {
            let chunkStart = Swift.max(0, lower - wordChunk)
            let chunk = buffer.bytes(in: chunkStart ..< lower)
            var index = chunk.count - 1
            while index >= 0, isWordByte(chunk[index]) { index -= 1 }
            // `index < 0` nghĩa là cả lô đều là chữ — từ còn dài hơn lô, đi tiếp sang lô trước.
            if index >= 0 { return chunkStart + index + 1 }
            lower = chunkStart
        }
        return 0
    }

    private static func wordEnd(
        after offset: Int, in buffer: TextBuffer, _ isWordByte: (UInt8) -> Bool
    ) -> Int {
        var upper = offset
        while upper < buffer.count {
            let chunkEnd = Swift.min(buffer.count, upper + wordChunk)
            let chunk = buffer.bytes(in: upper ..< chunkEnd)
            var index = 0
            while index < chunk.count, isWordByte(chunk[index]) { index += 1 }
            if index < chunk.count { return upper + index }
            upper = chunkEnd
        }
        return buffer.count
    }

    private static func find(_ needle: [UInt8], in buffer: TextBuffer, from start: Int) -> Range<Int>? {
        // Quét theo cửa sổ có phần chồng bằng độ dài chuỗi tìm — cùng lý do như `DocumentSearch`:
        // không dựng cả tài liệu chỉ để tìm một từ.
        let window = 1 << 20
        var position = Swift.max(0, start)
        while position < buffer.count {
            let end = Swift.min(buffer.count, position + window)
            let chunk = buffer.bytes(in: position ..< end)
            if let index = chunk.firstRange(of: needle)?.lowerBound {
                return (position + index) ..< (position + index + needle.count)
            }
            if end >= buffer.count { break }
            position = end - (needle.count - 1)
        }
        return nil
    }
}

public extension TextBuffer {

    /// Một ký tự UTF-8 dài nhiều nhất bốn byte, nên đọc ngần ấy một lần là đủ cho mọi ca.
    ///
    /// Bản đầu đọc TỪNG BYTE bằng `bytes(in: i ..< i+1)`, tức một lần cấp phát mảng cho mỗi
    /// byte tiếp nối. Với tiếng Việt thì mỗi ký tự ba byte, nên mỗi lần gọi là ba lần cấp phát:
    /// đi hết một dòng 200 nghìn chữ `ệ` tốn **293 ms**.
    private static var characterBytes: Int { 4 }

    /// Biên ký tự đứng ngay trước `offset`.
    ///
    /// Lùi qua các byte tiếp nối UTF-8 (`10xxxxxx`). Xóa một byte thay vì một ký tự sẽ cắt đôi
    /// "ệ" và để lại byte rác — với tiếng Việt thì đó là hầu hết các lần bấm Backspace.
    func previousCharacterBoundary(before offset: Int) -> Int {
        let end = Swift.min(offset, count)
        guard end > 0 else { return 0 }
        let start = Swift.max(0, end - Self.characterBytes)
        let window = bytes(in: start ..< end)
        var index = window.count - 1
        while index > 0, window[index] & 0xC0 == 0x80 { index -= 1 }
        return Swift.max(0, start + index)
    }

    /// Biên ký tự đứng ngay sau `offset`.
    func nextCharacterBoundary(after offset: Int) -> Int {
        let start = Swift.max(0, offset) + 1
        guard start < count else { return Swift.min(start, count) }
        let end = Swift.min(count, start + Self.characterBytes)
        let window = bytes(in: start ..< end)
        var index = 0
        while index < window.count, window[index] & 0xC0 == 0x80 { index += 1 }
        return Swift.min(start + index, count)
    }
}
