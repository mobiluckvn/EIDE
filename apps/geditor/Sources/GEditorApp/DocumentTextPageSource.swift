import AppKit
import GEditorCore

/// Phân trang một tài liệu chữ, và vẽ từng trang.
///
/// ## Phân trang là việc TextKit KHÔNG làm
///
/// `NSLayoutManager` đổ chữ vào các `NSTextContainer` cho tới khi hết chỗ rồi sang cái tiếp
/// theo. Nó không biết "trang" là gì — nó chỉ biết ô chứa. Trang ở đây chính là *một ô chứa
/// bằng đúng vùng chữ của khổ giấy*, và bộ phân trang là vòng lặp thêm ô chứa cho tới khi hết
/// chữ.
///
/// ## Ngắt trang tường minh
///
/// `<w:br w:type="page"/>` và `w:pageBreakBefore` không phải "hết chỗ" — chúng là mệnh lệnh.
/// TextKit không có khái niệm ấy, nên tài liệu được **cắt thành đoạn ở mỗi chỗ ngắt**, mỗi đoạn
/// có bộ ô chứa riêng. Trang đầu của đoạn sau vì thế luôn bắt đầu ở một tờ giấy mới.
///
/// ## Bố cục tính MỘT LẦN, phóng to không tính lại
///
/// Chữ được dựng theo point của KHỔ GIẤY, không theo pixel màn hình. Nên kéo cửa sổ hay phóng to
/// chỉ đổi một con số nhân lúc vẽ — không dòng nào ngắt lại, không trang nào đổi số. Đó là lý do
/// cuộn một cuốn 300 trang vẫn mượt khi đang kéo giãn cửa sổ, và cũng là lý do số trang mà người
/// dùng thấy không nhảy loạn khi họ chỉ đang chỉnh cỡ.
/// Một chỗ trong tài liệu: đoạn thứ mấy, ký tự thứ mấy.
///
/// Không dùng một chỉ số phẳng vì tài liệu bị **cắt thành đoạn ở mỗi chỗ ngắt trang tường
/// minh**, mỗi đoạn một kho chữ riêng. Một chỉ số phẳng sẽ phải cộng dồn độ dài các kho, và mỗi
/// lần cộng nhầm là con nháy nhảy sang chỗ khác trong cùng tài liệu — kiểu lỗi trông như "chọn
/// chữ bị lệch một ít" và tốn nhiều giờ để lần ra.
struct PageLocation: Comparable, Equatable {
    var section: Int
    var character: Int

    static func < (lhs: PageLocation, rhs: PageLocation) -> Bool {
        lhs.section == rhs.section
            ? lhs.character < rhs.character
            : lhs.section < rhs.section
    }
}

final class DocumentTextPageSource: DocumentPageSource {

    private struct Section {
        let storage: NSTextStorage
        let layoutManager: NSLayoutManager
        var containers: [NSTextContainer]
    }

    private var sections: [Section] = []
    /// Trang thứ `i` là ô chứa thứ `containerIndex` của đoạn `sectionIndex`.
    private var pages: [(sectionIndex: Int, containerIndex: Int)] = []

    let pageSizePt: CGSize
    private let contentOrigin: CGPoint
    private let contentSize: CGSize
    /// Đầu và chân trang **theo PHẦN** — dựng lại ở mỗi tờ vì số trang đổi theo tờ.
    ///
    /// Một cuốn sách in chia phần ở mỗi chương, và mỗi phần có thể mang tên chương riêng trên
    /// đầu trang. Dùng một bản cho cả cuốn thì 34 trong 45 phần hiện sai chỗ người đọc nhìn để
    /// biết mình đang ở đâu.
    private var headers: [[DOCXLayout.Paragraph]] = []
    private var footers: [[DOCXLayout.Paragraph]] = []
    /// Trang thứ `i` thuộc phần Word thứ mấy.
    private var pageWordSection: [Int] = []

    var pageCount: Int { pages.count }

    /// Số ảnh đã đưa vào bản dựng — bài tự kiểm dùng để chứng minh ảnh không bị rơi ở tầng vẽ.
    private(set) var imageCount = 0

    init(document: DOCXLayout.Document) {
        pageSizePt = CGSize(width: document.pageWidthPt, height: document.pageHeightPt)
        contentOrigin = CGPoint(x: document.marginLeftPt, y: document.marginTopPt)
        contentSize = CGSize(width: document.contentWidthPt, height: document.contentHeightPt)
        imageCount = document.imageCount

        headers = document.sections.map(\.header)
        footers = document.sections.map(\.footer)

        // Dựng chữ THEO TỪNG PHẦN, không dựng cả tài liệu một lượt.
        //
        // Chỉ như thế mới biết được tờ nào thuộc phần nào — và một phần Word luôn bắt đầu ở
        // trang mới, đúng thứ bộ phân trang ở đây vốn đã làm với mỗi chỗ ngắt trang.
        var cursor = 0
        for (index, wordSection) in document.sections.enumerated() {
            let end = min(document.blocks.count, cursor + wordSection.blockCount)
            guard cursor < end || document.sections.count == 1 else { continue }
            var part = document
            part.blocks = Array(document.blocks[cursor ..< end])
            cursor = end
            let text = DocumentPageBuilder.attributedString(for: part)
            for piece in Self.split(text) { appendSection(piece, wordSection: index) }
        }
        // Khối nằm sau phần cuối cùng (tệp hỏng, hoặc `sectPr` thiếu): vẫn phải hiện ra.
        if cursor < document.blocks.count {
            var rest = document
            rest.blocks = Array(document.blocks[cursor...])
            let text = DocumentPageBuilder.attributedString(for: rest)
            for piece in Self.split(text) {
                appendSection(piece, wordSection: max(0, document.sections.count - 1))
            }
        }
        if sections.isEmpty { appendSection(NSAttributedString(string: " "), wordSection: 0) }
    }

    /// Dựng từ một chuỗi đã có sẵn — dùng cho những định dạng mà lõi trả về chữ đã định dạng
    /// (RTF, ODT) chứ không trả mô hình trang.
    init(text: NSAttributedString, pageSize: CGSize, margins: NSEdgeInsets) {
        pageSizePt = pageSize
        contentOrigin = CGPoint(x: margins.left, y: margins.top)
        contentSize = CGSize(
            width: max(72, pageSize.width - margins.left - margins.right),
            height: max(72, pageSize.height - margins.top - margins.bottom)
        )
        for piece in Self.split(text) { appendSection(piece, wordSection: 0) }
        if sections.isEmpty { appendSection(NSAttributedString(string: " "), wordSection: 0) }
    }

    /// Cắt ở ký tự ngắt trang (form feed). Mảnh rỗng vẫn giữ — một chỗ ngắt kép trong tệp gốc
    /// nghĩa là một trang trắng, và bỏ nó đi là đánh số trang lệch so với bản in.
    private static func split(_ text: NSAttributedString) -> [NSAttributedString] {
        let string = text.string as NSString
        var result: [NSAttributedString] = []
        var start = 0
        while start <= string.length {
            let searchRange = NSRange(location: start, length: string.length - start)
            let found = string.range(of: "\u{000C}", options: [], range: searchRange)
            if found.location == NSNotFound {
                result.append(text.attributedSubstring(
                    from: NSRange(location: start, length: string.length - start)))
                break
            }
            result.append(text.attributedSubstring(
                from: NSRange(location: start, length: found.location - start)))
            start = found.location + found.length
        }
        return result.isEmpty ? [text] : result
    }

    private func appendSection(_ text: NSAttributedString, wordSection: Int) {
        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        // **Không cộng thêm khoảng dẫn của font.**
        //
        // Word tính "giãn dòng đơn" theo phần TRÊN + DƯỚI của chữ, không cộng `lineGap` mà bảng
        // OS/2 của font khai. Bật `usesFontLeading` là cộng khoảng ấy vào mỗi dòng, và trên một
        // cuốn sách 350 trang nó dồn lại thành hàng chục trang thừa.
        //
        // Đo được, không phải đoán: đối chiếu 10 cuốn sách có SẴN BẢN IN PDF trong cùng thư mục
        // (`--doc-sweep` in bảng ấy ra), lệch tuyệt đối trung bình **5,5% → 4,7%**.
        layoutManager.usesFontLeading = false
        storage.addLayoutManager(layoutManager)

        var containers: [NSTextContainer] = []
        // Trần 4000 trang: một tệp hỏng có thể sinh ra ô chứa không bao giờ nhận được chữ nào, và
        // vòng lặp này khi ấy chạy mãi mãi. Trần là thứ biến một lần treo vĩnh viễn thành một
        // tài liệu bị cắt ngắn mà người dùng còn thấy được phần đầu.
        while containers.count < 4000 {
            let container = NSTextContainer(size: contentSize)
            container.lineFragmentPadding = 0
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)
            containers.append(container)

            let laid = layoutManager.glyphRange(for: container)
            if NSMaxRange(laid) >= layoutManager.numberOfGlyphs { break }
            // Ô chứa không nhận được chữ nào mà vẫn còn chữ: có một thứ cao hơn cả trang (ảnh
            // quá khổ, hàng bảng quá cao). Thêm ô chứa nữa cũng vô ích — dừng lại thay vì quay
            // vòng, và phần còn lại chấp nhận bị cắt.
            if laid.length == 0 && containers.count > 1 { break }
        }

        sections.append(Section(
            storage: storage, layoutManager: layoutManager, containers: containers))
        let sectionIndex = sections.count - 1
        for containerIndex in containers.indices {
            pages.append((sectionIndex, containerIndex))
            pageWordSection.append(wordSection)
        }
    }

    // MARK: - Vẽ

    func draw(page index: Int, dirtyRect: CGRect) {
        guard pages.indices.contains(index) else { return }
        let (sectionIndex, containerIndex) = pages[index]
        let section = sections[sectionIndex]
        guard section.containers.indices.contains(containerIndex) else { return }

        let container = section.containers[containerIndex]
        let range = section.layoutManager.glyphRange(for: container)
        guard range.length > 0 else { return }
        section.layoutManager.drawBackground(forGlyphRange: range, at: contentOrigin)
        // Tô TRƯỚC khi vẽ chữ: tô sau là phủ một lớp vàng lên chính chữ vừa vẽ.
        if let highlight, highlight.page == index {
            NSColor.systemYellow.withAlphaComponent(0.45).setFill()
            for rect in highlight.rects { rect.insetBy(dx: -1, dy: -1).fill() }
        }
        for rect in selectionRects(page: index) {
            NSColor.selectedTextBackgroundColor.withAlphaComponent(0.55).setFill()
            rect.fill()
        }
        section.layoutManager.drawGlyphs(forGlyphRange: range, at: contentOrigin)
        drawHeaderAndFooter(page: index)
    }

    /// Vẽ đầu và chân trang trong VÙNG LỀ.
    ///
    /// Chúng nằm ngoài vùng chữ, nên chúng không đi qua bộ phân trang — nếu đi qua thì mỗi tờ
    /// mất thêm hai dòng của phần thân, và số trang sẽ khác bản in.
    ///
    /// Vị trí lấy theo BĂNG LỀ chứ không theo `w:header`/`w:footer` của tệp: hai con số ấy đo từ
    /// mép giấy tới đầu/chân trang, và một tài liệu đặt chúng lớn hơn lề sẽ đẩy chân trang chồng
    /// lên chữ. Đặt vào giữa băng lề thì không bao giờ chồng, và lệch nhiều nhất vài point.
    private func drawHeaderAndFooter(page index: Int) {
        let wordSection = pageWordSection.indices.contains(index) ? pageWordSection[index] : 0
        let header = headers.indices.contains(wordSection) ? headers[wordSection] : []
        let footer = footers.indices.contains(wordSection) ? footers[wordSection] : []
        guard !header.isEmpty || !footer.isEmpty else { return }
        let width = contentSize.width
        let topBand = contentOrigin.y
        let bottomBand = pageSizePt.height - (contentOrigin.y + contentSize.height)

        if !header.isEmpty, topBand > 12 {
            let text = DocumentPageBuilder.attributed(
                headerOrFooter: header, page: index + 1, of: pageCount, width: width)
            text.draw(in: CGRect(
                x: contentOrigin.x, y: max(4, topBand * 0.25),
                width: width, height: topBand * 0.7))
        }
        if !footer.isEmpty, bottomBand > 12 {
            let text = DocumentPageBuilder.attributed(
                headerOrFooter: footer, page: index + 1, of: pageCount, width: width)
            let height = min(bottomBand * 0.7, text.size().height + 2)
            text.draw(in: CGRect(
                x: contentOrigin.x,
                y: pageSizePt.height - bottomBand * 0.35 - height,
                width: width, height: height))
        }
    }

    /// Chữ của chân trang sẽ vẽ trên trang `index` — cửa cho bài tự kiểm.
    ///
    /// Bài kiểm cần biết trang này lấy chân trang của PHẦN NÀO. Đọc từ ảnh chụp thì chỉ nói được
    /// "có mực hay không", không nói được "mực ấy là chữ nào".
    func footerTextForSelfTest(page index: Int) -> String {
        let wordSection = pageWordSection.indices.contains(index) ? pageWordSection[index] : 0
        guard footers.indices.contains(wordSection) else { return "" }
        return footers[wordSection].map(\.plainText).joined(separator: " ")
    }

    // MARK: - Chọn chữ

    /// Chỗ trong tài liệu ứng với một điểm trên trang. `nil` = điểm nằm ngoài vùng chữ.
    func location(page index: Int, point: CGPoint) -> PageLocation? {
        guard pages.indices.contains(index) else { return nil }
        let (sectionIndex, containerIndex) = pages[index]
        let section = sections[sectionIndex]
        guard section.containers.indices.contains(containerIndex) else { return nil }
        let container = section.containers[containerIndex]

        // Điểm đang ở hệ toạ độ TRANG; ô chứa bắt đầu ở lề, nên phải trừ đi.
        let inContainer = CGPoint(
            x: point.x - contentOrigin.x, y: point.y - contentOrigin.y)
        let glyph = section.layoutManager.glyphIndex(
            for: inContainer, in: container, fractionOfDistanceThroughGlyph: nil)
        // `glyphIndex(for:in:)` trả về glyph GẦN NHẤT, kể cả khi bấm ra ngoài — đó là hành vi
        // đúng cho việc kéo chọn: người dùng kéo quá mép dòng vẫn phải chọn tới hết dòng.
        let character = section.layoutManager.characterIndexForGlyph(at: glyph)
        return PageLocation(section: sectionIndex, character: character)
    }

    func setSelection(from: PageLocation, to: PageLocation) {
        selection = from <= to ? (from, to) : (to, from)
    }

    func clearSelection() { selection = nil }

    /// Bấm hai lần chọn cả TỪ, ba lần chọn cả ĐOẠN.
    func selectUnit(at location: PageLocation, whole paragraph: Bool) {
        guard sections.indices.contains(location.section) else { return }
        let text = sections[location.section].storage.string as NSString
        guard location.character < text.length else { return }
        let range = paragraph
            ? text.paragraphRange(for: NSRange(location: location.character, length: 0))
            : text.rangeOfWord(at: location.character)
        selection = (
            PageLocation(section: location.section, character: range.location),
            PageLocation(section: location.section, character: NSMaxRange(range))
        )
    }

    var hasSelection: Bool {
        guard let selection else { return false }
        return selection.from != selection.to
    }

    func selectAll() {
        guard let last = sections.indices.last else { return }
        selection = (
            PageLocation(section: 0, character: 0),
            PageLocation(section: last, character: sections[last].storage.length)
        )
    }

    /// Chữ đang được bôi đen, nối qua cả những chỗ ngắt trang.
    var selectedText: String {
        guard let selection, selection.from != selection.to else { return "" }
        var pieces: [String] = []
        for index in selection.from.section ... selection.to.section {
            guard sections.indices.contains(index) else { continue }
            let text = sections[index].storage.string as NSString
            let start = index == selection.from.section ? selection.from.character : 0
            let end = index == selection.to.section ? selection.to.character : text.length
            guard start < end, start >= 0, end <= text.length else { continue }
            pieces.append(text.substring(with: NSRange(location: start, length: end - start)))
        }
        // Chỗ ngắt trang tường minh là một chỗ XUỐNG DÒNG khi dán ra, không phải chỗ dính liền.
        return pieces.joined(separator: "\n")
    }

    /// Ô chữ nhật của vùng chọn trên một trang, hệ toạ độ TRANG.
    private func selectionRects(page index: Int) -> [CGRect] {
        guard let selection, selection.from != selection.to,
              pages.indices.contains(index)
        else { return [] }
        let (sectionIndex, containerIndex) = pages[index]
        guard sectionIndex >= selection.from.section, sectionIndex <= selection.to.section,
              sections.indices.contains(sectionIndex)
        else { return [] }

        let section = sections[sectionIndex]
        guard section.containers.indices.contains(containerIndex) else { return [] }
        let container = section.containers[containerIndex]
        let length = section.storage.length
        let start = sectionIndex == selection.from.section ? selection.from.character : 0
        let end = sectionIndex == selection.to.section ? selection.to.character : length
        guard start < end, start >= 0, end <= length else { return [] }

        let glyphs = section.layoutManager.glyphRange(
            forCharacterRange: NSRange(location: start, length: end - start),
            actualCharacterRange: nil)
        let onPage = NSIntersectionRange(section.layoutManager.glyphRange(for: container), glyphs)
        guard onPage.length > 0 else { return [] }

        var rects: [CGRect] = []
        section.layoutManager.enumerateEnclosingRects(
            forGlyphRange: onPage,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: container
        ) { rect, _ in
            rects.append(rect.offsetBy(dx: self.contentOrigin.x, dy: self.contentOrigin.y))
        }
        return rects
    }

    // MARK: - Tìm chữ

    /// Chữ thuần của cả tài liệu, nối theo thứ tự trang. Dùng cho ô tìm kiếm của khung chung.
    var plainText: String {
        sections.map { $0.storage.string }.joined(separator: "\n")
    }

    /// Chỗ đang được tô vàng: trang nào, và những ô chữ nhật nào TRONG hệ toạ độ trang.
    private var highlight: (page: Int, rects: [CGRect])?

    /// Vùng người dùng đang bôi đen. `nil` = không chọn gì.
    private var selection: (from: PageLocation, to: PageLocation)?

    /// Mọi lần xuất hiện của `needle`, theo thứ tự trang.
    ///
    /// Trả về danh sách trang (đếm từ 0) — cùng một trang có thể xuất hiện nhiều lần nếu có
    /// nhiều chỗ khớp trên đó, vì người dùng bấm "tiếp" là đi tới CHỖ KHỚP chứ không đi tới
    /// trang.
    func matches(for needle: String) -> [Int] {
        locate(needle).map(\.page)
    }

    /// Tô chỗ khớp thứ `ordinal` (đếm từ 0) và trả về trang chứa nó.
    @discardableResult
    func highlightMatch(_ needle: String, ordinal: Int) -> Int? {
        let found = locate(needle)
        guard !found.isEmpty else {
            highlight = nil
            return nil
        }
        let hit = found[((ordinal % found.count) + found.count) % found.count]
        highlight = (hit.page, hit.rects)
        return hit.page
    }

    func clearHighlight() { highlight = nil }

    /// Trang chứa lần xuất hiện đầu tiên của `needle`, đếm từ 0. `nil` = không có.
    func page(containing needle: String) -> Int? {
        locate(needle).first?.page
    }

    private struct Hit {
        var page: Int
        var rects: [CGRect]
    }

    /// Tìm mọi chỗ khớp và quy chúng về (trang, ô chữ nhật).
    ///
    /// Bỏ dấu và bỏ hoa thường: người Việt gõ "tri thuc" phải tìm ra "Tri Thức". Đây là lựa chọn
    /// có giá — nó cũng khớp "trí thúc" — nhưng cái giá của chiều ngược lại đắt hơn nhiều: gõ
    /// đúng dấu trên bàn phím tiếng Anh là chuyện không phải ai cũng làm được.
    private func locate(_ needle: String) -> [Hit] {
        guard !needle.isEmpty else { return [] }
        var result: [Hit] = []
        for (sectionIndex, section) in sections.enumerated() {
            let text = section.storage.string as NSString
            var searchFrom = 0
            while searchFrom < text.length {
                let found = text.range(
                    of: needle, options: [.caseInsensitive, .diacriticInsensitive],
                    range: NSRange(location: searchFrom, length: text.length - searchFrom))
                guard found.location != NSNotFound else { break }
                searchFrom = found.location + max(1, found.length)

                let glyphs = section.layoutManager.glyphRange(
                    forCharacterRange: found, actualCharacterRange: nil)
                for (containerIndex, container) in section.containers.enumerated() {
                    let pageGlyphs = section.layoutManager.glyphRange(for: container)
                    guard NSIntersectionRange(pageGlyphs, glyphs).length > 0 else { continue }
                    guard let page = pages.firstIndex(where: {
                        $0.sectionIndex == sectionIndex && $0.containerIndex == containerIndex
                    }) else { continue }

                    // Một chỗ khớp có thể nằm trên hai dòng, nên nó là NHIỀU ô chữ nhật chứ
                    // không phải một. Vẽ một ô bao trùm sẽ tô cả khoảng trắng cuối dòng trên.
                    var rects: [CGRect] = []
                    section.layoutManager.enumerateEnclosingRects(
                        forGlyphRange: NSIntersectionRange(pageGlyphs, glyphs),
                        withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                        in: container
                    ) { rect, _ in
                        rects.append(rect.offsetBy(
                            dx: self.contentOrigin.x, dy: self.contentOrigin.y))
                    }
                    if !rects.isEmpty { result.append(Hit(page: page, rects: rects)) }
                    break
                }
            }
        }
        return result
    }
}


extension NSString {
    /// Khoảng của TỪ chứa ký tự thứ `index`.
    ///
    /// Tự tìm chứ không dùng `NSSpellChecker`: bộ kiểm chính tả cần một ngôn ngữ, và một tài
    /// liệu tiếng Việt lẫn tiếng Anh sẽ cho ra ranh giới từ khác nhau tuỳ đoán ngôn ngữ nào.
    /// Ở đây "từ" là dãy ký tự không phải khoảng trắng và không phải dấu câu — đủ đúng cho việc
    /// bấm hai lần rồi ⌘C.
    func rangeOfWord(at index: Int) -> NSRange {
        let breaks = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        var start = index
        while start > 0 {
            let scalar = character(at: start - 1)
            guard let unicode = Unicode.Scalar(scalar), !breaks.contains(unicode) else { break }
            start -= 1
        }
        var end = index
        while end < length {
            let scalar = character(at: end)
            guard let unicode = Unicode.Scalar(scalar), !breaks.contains(unicode) else { break }
            end += 1
        }
        return NSRange(location: start, length: max(1, end - start))
    }
}
