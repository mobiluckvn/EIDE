import AppKit
import GEditorCore

/// Vị trí trong tài liệu, tính bằng **offset byte UTF-8** — cùng đơn vị với `TextBuffer`.
///
/// Đây là canh bạc chính của PoC-A2. `NSTextContentStorage` của Apple dùng offset ký tự
/// UTF-16 vì nó đứng trên `NSTextStorage`. Ta thì đứng trên piece table đánh chỉ số theo byte,
/// và đổi byte ↔ UTF-16 cho cả tài liệu đòi thêm một chỉ mục tích lũy nữa (≈58 MB cho 500 MB).
/// Nếu TextKit 2 chịu được một không gian vị trí do ta định nghĩa thì bỏ được chỉ mục ấy.
///
/// `NSTextContentManager` được thiết kế để lớp con tự định nghĩa không gian vị trí — nhưng
/// "được thiết kế để" và "chạy thật" là hai chuyện, nên PoC này tồn tại.
final class ByteLocation: NSObject, NSTextLocation {
    let offset: Int

    init(_ offset: Int) { self.offset = offset }

    func compare(_ other: NSTextLocation) -> ComparisonResult {
        guard let other = other as? ByteLocation else { return .orderedAscending }
        if offset < other.offset { return .orderedAscending }
        if offset > other.offset { return .orderedDescending }
        return .orderedSame
    }

    override var description: String { "byte \(offset)" }
}

/// Cấp nội dung cho TextKit 2 **theo yêu cầu** từ piece table trên mmap (ADR-01 §4).
///
/// Không giữ bản sao nào của tài liệu: mỗi lần TextKit hỏi một đoạn, ta đọc đúng dòng đó từ
/// buffer và dựng `NSTextParagraph`. Đây là thứ ADR-01 §6 nói là "chưa đo" và là mắt xích yếu
/// nhất trong đề xuất của chính nó.
final class PieceTableContentManager: NSTextContentManager {

    let buffer: TextBuffer
    /// Thuộc tính chữ dùng chung cho mọi đoạn — dựng lại `NSDictionary` cho từng dòng trong
    /// lúc cuộn là tự thêm chi phí vào đúng chỗ đang đo.
    private let attributes: [NSAttributedString.Key: Any]
    /// Đếm số lần TextKit HỎI nội dung. 0 nghĩa là nó không hỏi, và mọi phép đo khác vô nghĩa.
    private(set) var enumerationCalls = 0
    private(set) var elementsHandedOut = 0

    init(buffer: TextBuffer, font: NSFont) {
        self.buffer = buffer
        self.attributes = [.font: font, .foregroundColor: NSColor.textColor]
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var documentRange: NSTextRange {
        NSTextRange(location: ByteLocation(0), end: ByteLocation(buffer.count))!
    }

    /// Dựng một đoạn cho dòng `line`.
    ///
    /// Kèm cả ký tự xuống dòng: TextKit 2 coi đoạn là "văn bản tới hết dấu ngắt đoạn", bỏ nó
    /// ra thì hai dòng liền nhau dính vào nhau khi vẽ.
    private func paragraph(forLine line: Int) -> NSTextParagraph? {
        guard line >= 0, line < buffer.lineCount else { return nil }
        let start = buffer.offset(ofLineStart: line)
        let end = line + 1 < buffer.lineCount ? buffer.offset(ofLineStart: line + 1) : buffer.count
        guard start <= end else { return nil }

        let text = String(decoding: buffer.bytes(in: start ..< end), as: UTF8.self)
        let paragraph = NSTextParagraph(attributedString: NSAttributedString(string: text, attributes: attributes))
        paragraph.textContentManager = self
        paragraph.elementRange = NSTextRange(location: ByteLocation(start), end: ByteLocation(end))
        return paragraph
    }

    override func enumerateTextElements(
        from location: NSTextLocation?,
        options: NSTextContentManager.EnumerationOptions = [],
        using block: (NSTextElement) -> Bool
    ) -> NSTextLocation? {
        enumerationCalls += 1
        let startOffset = (location as? ByteLocation)?.offset
            ?? (options.contains(.reverse) ? buffer.count : 0)
        var line = buffer.lineNumber(atOffset: Swift.min(Swift.max(startOffset, 0),
                                                        Swift.max(buffer.count - 1, 0)))
        let step = options.contains(.reverse) ? -1 : 1
        var last: NSTextLocation?

        while line >= 0, line < buffer.lineCount {
            guard let element = paragraph(forLine: line) else { break }
            elementsHandedOut += 1
            last = element.elementRange?.endLocation
            if !block(element) { break }
            line += step
        }
        return last
    }

    /// Khoảng cách giữa hai vị trí, tính bằng byte.
    override func offset(from: NSTextLocation, to: NSTextLocation) -> Int {
        guard let from = from as? ByteLocation, let to = to as? ByteLocation else { return 0 }
        return to.offset - from.offset
    }

    /// Dời vị trí đi `offset` byte.
    ///
    /// Kẹp vào [0, count] chứ không trả `nil` khi ra ngoài: TextKit hỏi vị trí quá biên khá
    /// thường xuyên lúc dựng bố cục ở đầu và cuối tài liệu, và trả `nil` ở đó làm nó bỏ dở.
    override func location(_ location: NSTextLocation, offsetBy offset: Int) -> NSTextLocation? {
        guard let location = location as? ByteLocation else { return nil }
        let target = location.offset + offset
        guard target >= 0, target <= buffer.count else { return nil }
        return ByteLocation(target)
    }

    /// Ta KHÔNG hiện thực đường sửa nội dung của TextKit.
    ///
    /// Nguồn sự thật là `TextBuffer`, và mọi sửa đổi đi qua `TextBuffer.applyEdits` để giữ
    /// FR-CORE-004 (một thao tác hàng loạt = MỘT bước undo). Cho TextKit sửa nội dung ở đây sẽ
    /// mở đường thứ hai vào cùng một tài liệu, và hai đường thì sớm muộn cũng lệch nhau.
    override func replaceContents(in range: NSTextRange, with textElements: [NSTextElement]?) {
        assertionFailure("nội dung chỉ được sửa qua TextBuffer")
    }

    /// Báo cho TextKit rằng một khoảng byte vừa đổi, để nó bỏ bố cục cũ của khoảng đó.
    func noteEdit(oldRange: Range<Int>, newLength: Int) {
        guard let old = NSTextRange(location: ByteLocation(oldRange.lowerBound),
                                    end: ByteLocation(oldRange.upperBound)),
              let new = NSTextRange(location: ByteLocation(oldRange.lowerBound),
                                   end: ByteLocation(oldRange.lowerBound + newLength))
        else { return }
        recordEditAction(in: old, newTextRange: new)
    }
}
