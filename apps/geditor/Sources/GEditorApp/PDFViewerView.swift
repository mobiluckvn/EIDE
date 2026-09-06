import AppKit
import GEditorCore
import PDFKit
import UniformTypeIdentifiers

/// Khung xem và chú thích PDF.
///
/// **Dùng PDFKit chứ không tự viết bộ vẽ PDF.** Bên `mobiluck-reader` phải tự dựng cả engine
/// vì Android không có sẵn; macOS thì có, và nó là chính bộ vẽ mà Preview dùng — cùng chất
/// lượng chữ, cùng cách xử font nhúng, cùng khả năng chọn/chép chữ tiếng Việt. Tự viết lại là
/// bỏ ra hàng tháng để có một thứ tệ hơn.
///
/// **Chú thích ghi vào BẢN SAO, không đè bản gốc.** Đây là quyết định đã chốt bên
/// `mobiluck-reader` (§B) và nó đúng y nguyên ở đây: ghi đè là việc Cmd-Z không hoàn tác được,
/// và một lần ghi hỏng giữa chừng thì mất luôn tệp của người khác. Người dùng bấm "Lưu bản có
/// chú thích…" và chọn chỗ ghi — chủ động, có đường lui.
///
/// **Không nạp PDFKit lúc khởi động.** Xem `LINKED_FRAMEWORKS_ALLOWED` trong
/// `check-core-no-ui.sh`: framework này chỉ được đụng tới khi người dùng mở một tệp PDF, và giá
/// liên kết đã đo (ADR-14).
final class PDFViewerView: NSView {

    var onStatus: ((String) -> Void)?
    var onOpenTextInNewTab: ((String, String) -> Void)?

    private let pdfView = PDFView()
    private let thumbnails = PDFThumbnailView()
    private let toolbar = NSStackView()
    private let pageToolbar = NSStackView()
    private let searchField = NSSearchField()
    private let pageLabel = NSTextField(labelWithString: "")
    private var path: String?
    private var matches: [PDFSelection] = []
    private var matchIndex = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = Tokens.Color.editorBackground

        thumbnails.translatesAutoresizingMaskIntoConstraints = false
        thumbnails.pdfView = pdfView
        thumbnails.thumbnailSize = NSSize(width: 88, height: 110)
        thumbnails.backgroundColor = Tokens.Color.chrome

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.spacing = 6
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        for (title, action) in [
            ("−", #selector(zoomOut)), ("+", #selector(zoomIn)),
            (L("Vừa khung"), #selector(zoomToFit)),
            (L("Bôi vàng"), #selector(highlightSelection)),
            (L("Gạch chân"), #selector(underlineSelection)),
            (L("Ghi chú…"), #selector(addNote)),
            (L("Bỏ chú thích"), #selector(removeAnnotationsOnPage)),
            (L("Lấy chữ ra tab mới"), #selector(extractText)),
        ] {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            toolbar.addArrangedSubview(button)
        }

        // Hàng thứ hai: tầng công cụ TRANG. Tách hàng chứ không nhét chung, vì hai hàng trả lời
        // hai câu khác nhau — hàng trên làm việc với nội dung một trang, hàng dưới với tập hợp
        // trang. Trộn chúng lại thì "Bỏ chú thích" đứng cạnh "Xoá trang", và hai nút ấy khác
        // nhau một trời một vực về mức độ không lùi lại được.
        pageToolbar.translatesAutoresizingMaskIntoConstraints = false
        pageToolbar.orientation = .horizontal
        pageToolbar.spacing = 6
        pageToolbar.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 4, right: 8)
        for (title, action) in [
            (L("Xoay trái"), #selector(rotateLeft)),
            (L("Xoay phải"), #selector(rotateRight)),
            (L("Trang lên"), #selector(movePageUp)),
            (L("Trang xuống"), #selector(movePageDown)),
            (L("Xoá trang…"), #selector(deletePages)),
            (L("Trích trang…"), #selector(extractPages)),
            (L("Gộp tệp PDF…"), #selector(mergePDFFromPanel)),
            (L("Tách tệp…"), #selector(splitPDF)),
            (L("Xuất ảnh…"), #selector(exportPagesAsImages)),
            (L("Ký…"), #selector(insertSignatureFromPanel)),
            (L("Sửa chữ…"), #selector(replaceSelectedText)),
            (L("Ô chưa điền"), #selector(goToNextEmptyField)),
            (L("Xoá nội dung đã điền"), #selector(resetFormFields)),
            (L("Hoàn tác trang"), #selector(undoPageEdit)),
            (L("Lưu bản đã sửa…"), #selector(saveCopy)),
        ] {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            pageToolbar.addArrangedSubview(button)
        }

        searchField.placeholderString = L("Tìm trong PDF")
        searchField.font = Tokens.Font.caption
        searchField.target = self
        searchField.action = #selector(runSearch)
        searchField.widthAnchor.constraint(equalToConstant: 170).isActive = true
        toolbar.addArrangedSubview(searchField)

        pageLabel.font = Tokens.Font.caption
        pageLabel.textColor = Tokens.Color.secondaryInk
        toolbar.addArrangedSubview(pageLabel)

        addSubview(toolbar)
        addSubview(pageToolbar)
        addSubview(thumbnails)
        addSubview(pdfView)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            pageToolbar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            pageToolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            pageToolbar.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            thumbnails.topAnchor.constraint(equalTo: pageToolbar.bottomAnchor),
            thumbnails.leadingAnchor.constraint(equalTo: leadingAnchor),
            thumbnails.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbnails.widthAnchor.constraint(equalToConstant: 108),
            pdfView.topAnchor.constraint(equalTo: pageToolbar.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: thumbnails.trailingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(pageChanged),
            name: .PDFViewPageChanged, object: pdfView)
    }

    // MARK: - Nạp

    func load(path: String) {
        self.path = path
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
            onStatus?(LF("Không đọc được PDF «%@»",
                             (path as NSString).lastPathComponent))
            return
        }
        // Tệp có mật khẩu: PDFKit mở được cấu trúc nhưng khoá nội dung. Nói ra thay vì hiện
        // một khung trắng.
        if document.isLocked {
            onStatus?(L("PDF này có mật khẩu — chưa mở được nội dung"))
        }
        pdfView.document = document
        // Ngăn xếp hoàn tác thuộc về TÀI LIỆU, không thuộc về khung. Giữ lại khi mở tệp khác thì
        // một phép ngược sẽ chèn trang của tệp cũ vào tệp mới.
        pageUndoStack.removeAll()
        hasUnsavedPageEdits = false
        updatePageLabel()
        announceFormFieldsIfAny()
    }

    @objc private func pageChanged(_ note: Notification) { updatePageLabel() }

    private func updatePageLabel() {
        guard let document = pdfView.document else { return }
        let current = pdfView.currentPage.map { document.index(for: $0) + 1 } ?? 1
        pageLabel.stringValue = LF("Trang %d/%d", current, document.pageCount)
            + (hasUnsavedPageEdits ? " " + L("· đã sửa, chưa lưu") : "")
    }

    // MARK: - Phóng

    @objc private func zoomIn(_ sender: Any?) { pdfView.zoomIn(nil) }
    @objc private func zoomOut(_ sender: Any?) { pdfView.zoomOut(nil) }
    @objc private func zoomToFit(_ sender: Any?) {
        pdfView.autoScales = true
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
    }

    // MARK: - Tìm

    @objc private func runSearch(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        let needle = searchField.stringValue
        guard !needle.isEmpty else {
            pdfView.setCurrentSelection(nil, animate: false)
            matches = []
            updatePageLabel()
            return
        }
        // Tìm KHÔNG phân biệt hoa thường và không phân biệt dấu — cùng thói quen với ô tìm của
        // chính GEditor, nơi "gõ không dấu vẫn ra chữ có dấu" là một tính năng đã hứa.
        matches = document.findString(needle, withOptions: [.caseInsensitive, .diacriticInsensitive])
        matchIndex = 0
        guard !matches.isEmpty else {
            onStatus?(LF("Không thấy «%@» trong tài liệu", needle))
            pageLabel.stringValue = L("0 kết quả")
            return
        }
        showMatch()
    }

    private func showMatch() {
        guard matches.indices.contains(matchIndex) else { return }
        let match = matches[matchIndex]
        match.color = Tokens.Color.searchHighlight
        pdfView.setCurrentSelection(match, animate: true)
        pdfView.scrollSelectionToVisible(nil)
        pageLabel.stringValue = LF("Kết quả %d/%d", matchIndex + 1, matches.count)
    }

    /// ⌘G — kết quả kế tiếp, cùng phím với phần còn lại của ứng dụng.
    func findNext() {
        guard !matches.isEmpty else { return }
        matchIndex = (matchIndex + 1) % matches.count
        showMatch()
    }

    // MARK: - Chú thích

    /// Bôi vàng phần đang chọn.
    ///
    /// Một vùng chọn trải qua nhiều dòng cho ra NHIỀU hình chữ nhật, và mỗi hình phải là một
    /// annotation riêng. Gộp thành một hình bao là bôi cả những khoảng trắng ở đầu và cuối
    /// dòng — đúng thứ trông như lỗi hiển thị.
    @objc private func highlightSelection(_ sender: Any?) {
        addMarkup(.highlight, color: Tokens.Color.gold, label: L("Đã bôi vàng"))
    }

    @objc private func underlineSelection(_ sender: Any?) {
        addMarkup(.underline, color: Tokens.Color.orange, label: L("Đã gạch chân"))
    }

    private func addMarkup(_ subtype: PDFAnnotationSubtype, color: NSColor, label: String) {
        guard let selection = pdfView.currentSelection, !selection.string.isNilOrEmpty else {
            onStatus?(L("Hãy bôi đen một đoạn chữ trước"))
            return
        }
        var count = 0
        for page in selection.pages {
            for bounds in selection.selectionsByLine()
                .filter({ $0.pages.contains(page) })
                .map({ $0.bounds(for: page) }) {
                let annotation = PDFAnnotation(bounds: bounds, forType: subtype, withProperties: nil)
                annotation.color = color
                page.addAnnotation(annotation)
                count += 1
            }
        }
        pdfView.setCurrentSelection(nil, animate: false)
        onStatus?("\(label) · \(count)")
    }

    @objc private func addNote(_ sender: Any?) {
        guard let page = pdfView.currentPage else { return }
        let alert = NSAlert()
        alert.messageText = L("Ghi chú")
        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: L("Thêm"))
        alert.addButton(withTitle: "Huỷ")
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        let text = field.stringValue
        guard !text.isEmpty else { return }

        // Đặt ghi chú ở góc trên bên trái vùng chọn nếu có, không thì góc trên trang. Thả vào
        // giữa trang sẽ che mất chữ mà người dùng vừa đọc.
        let anchor = pdfView.currentSelection?.bounds(for: page) ?? page.bounds(for: .mediaBox)
        let bounds = NSRect(x: anchor.minX, y: anchor.maxY - 20, width: 20, height: 20)
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.contents = text
        annotation.color = Tokens.Color.gold
        page.addAnnotation(annotation)
        onStatus?(L("Đã thêm ghi chú"))
    }

    @objc private func removeAnnotationsOnPage(_ sender: Any?) {
        guard let page = pdfView.currentPage else { return }
        let annotations = page.annotations
        guard !annotations.isEmpty else {
            onStatus?(L("Trang này chưa có chú thích nào"))
            return
        }
        for annotation in annotations { page.removeAnnotation(annotation) }
        onStatus?(LF("Đã bỏ %d chú thích trên trang này", annotations.count))
    }

    // MARK: - Lấy chữ ra

    /// Đưa toàn văn PDF thành một tab văn bản.
    ///
    /// Đây là cây cầu giữa hai nửa của ứng dụng: chữ trong PDF vốn không tìm được bằng ⌘F,
    /// không grep được, không chạy được qua bộ khai phá. Đưa ra tab thì tất cả những thứ ấy
    /// dùng được ngay.
    @objc private func extractText(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        var out: [String] = []
        for index in 0 ..< document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = page.string ?? ""
            out.append("──── " + LF("Trang %d", index + 1) + " ────\n" + text)
        }
        let joined = out.joined(separator: "\n\n")
        guard !joined.replacingOccurrences(of: "─", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // PDF quét từ giấy không có tầng chữ. Nói ra, đừng mở một tab trống rồi để người
            // dùng tự đoán.
            onStatus?(L("PDF này không có tầng chữ — nhiều khả năng là bản quét ảnh"))
            return
        }
        let name = (path.map { ($0 as NSString).lastPathComponent } ?? "PDF")
        onOpenTextInNewTab?(joined, name + ".txt")
    }

    // MARK: - Lưu

    @objc private func saveCopy(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        let panel = NSSavePanel()
        let base = (path.map { ($0 as NSString).lastPathComponent } ?? "tai-lieu.pdf")
        panel.nameFieldStringValue = (base as NSString).deletingPathExtension + "-chu-thich.pdf"
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }

        guard document.write(to: url) else {
            onStatus?(L("Không ghi được tệp"))
            return
        }
        // ĐỐI CHỨNG: mở lại chính tệp vừa ghi và đòi nó còn đủ số trang. Cùng luật với
        // `mobiluck-reader` §B — một tệp ghi hỏng vẫn nằm trên đĩa trông như một tệp bình
        // thường, và người dùng chỉ phát hiện ra khi đã gửi nó đi.
        guard let again = PDFDocument(url: url), again.pageCount == document.pageCount else {
            onStatus?(L("Tệp vừa ghi mở lại KHÔNG đúng — đừng dùng bản này"))
            return
        }
        onStatus?(LF("Đã lưu %@ · %d trang", url.lastPathComponent, again.pageCount))
    }

    // MARK: - Tầng công cụ TRANG (xoay · xoá · dời · trích · gộp)
    //
    // Tách khỏi phần đọc và phần chú thích vì chúng trả lời hai câu khác nhau. Đọc và chú thích
    // làm việc với NỘI DUNG một trang; nhóm dưới đây làm việc với TẬP HỢP trang — thứ tự, số
    // lượng, hướng xoay. Quy tắc phân tầng lấy từ `mobiluck-reader` §A: cái gì chỉ cần "hộp chữ
    // và hộp ảnh" thì thuộc lõi đọc; cái gì cần cấu trúc riêng của định dạng thì thuộc tầng
    // công cụ của định dạng ấy.
    //
    // ## Sửa trong bộ nhớ, KHÔNG đụng tệp gốc
    //
    // Giữ nguyên luật đã chốt cho chú thích: mọi thao tác ở đây đổi tài liệu đang mở, và chỉ ghi
    // ra đĩa khi người dùng chủ động bấm "Lưu bản đã sửa…" rồi chọn chỗ. Xoá nhầm một trang rồi
    // tệp gốc bị đè là việc `⌘Z` không cứu được.
    //
    // ## Hoàn tác bằng phép NGƯỢC, không bằng ảnh chụp tài liệu
    //
    // Cách hiển nhiên là chụp lại cả tài liệu trước mỗi thao tác. Nó tốn `dataRepresentation()`
    // — tức tuần tự hoá cả tệp — cho MỘT lần xoay trang, và trên một PDF vài trăm MB thì mỗi
    // lần bấm nút là một quãng đứng hình. Ở đây mỗi thao tác tự khai phép ngược của nó, và phép
    // ngược thì rẻ ngang phép thuận.

    /// Ngăn xếp phép NGƯỢC. Mỗi phần tử hoàn tác đúng một thao tác trang.
    private var pageUndoStack: [() -> Void] = []

    /// Tài liệu đã đổi so với tệp trên đĩa chưa.
    private(set) var hasUnsavedPageEdits = false

    /// Ghi nhận một thao tác vừa làm, kèm phép ngược của nó.
    private func recordPageEdit(undo: @escaping () -> Void) {
        pageUndoStack.append(undo)
        hasUnsavedPageEdits = true
        refreshAfterPageEdit()
    }

    /// Dựng lại khung nhìn sau khi tập trang đổi.
    ///
    /// Gán lại `document` là cách DUY NHẤT bắt `PDFThumbnailView` vẽ lại: nó không theo dõi việc
    /// thêm/bớt trang. Không có dòng ấy thì cột ảnh nhỏ vẫn hiện trang đã xoá, và người dùng
    /// bấm vào một trang không còn tồn tại.
    private func refreshAfterPageEdit() {
        guard let document = pdfView.document else { return }
        let index = pdfView.currentPage.map { document.index(for: $0) } ?? 0
        pdfView.document = document
        if let page = document.page(at: min(index, max(document.pageCount - 1, 0))) {
            pdfView.go(to: page)
        }
        updatePageLabel()
    }

    /// Trang đang xem, hoặc `nil` khi chưa mở tài liệu nào.
    private var currentPageIndex: Int? {
        guard let document = pdfView.document, let page = pdfView.currentPage else { return nil }
        return document.index(for: page)
    }

    // MARK: - Phủ rồi vẽ: nền của cả ký lẫn sửa chữ
    //
    // ## Vì sao KHÔNG sửa luồng nội dung
    //
    // Sửa một dòng chữ trong PDF theo lối "đọc luồng nội dung, tìm chuỗi, ghi đè" mở ra cả một
    // hộp Pandora: font con có mã hoá riêng, một câu bị cắt làm ba mảnh vì kerning, bảng độ rộng
    // ký tự phải tính lại. Làm đúng cho MỌI tệp là một dự án riêng, và làm sai thì hỏng tệp của
    // người khác. `mobiluck-reader` §K đã chốt đúng lối này và lý do vẫn nguyên giá trị ở đây.
    //
    // Ở đây làm ngược lại và làm ít hơn: **vẽ lại nguyên trang cũ, rồi vẽ đè thứ mới lên**.
    //
    // ## Vẽ lại trang KHÔNG biến nó thành ảnh
    //
    // Đây là chỗ dễ hiểu nhầm nhất. `page.draw(with:to:)` vào một `CGPDFContext` phát lại các
    // toán tử của trang gốc, nên chữ vẫn là CHỮ: vẫn chọn được, vẫn chép được, vẫn tìm được.
    // Rasterise trang rồi dán ảnh thì mới mất tất cả những thứ ấy — và đó chính là thứ không làm.
    //
    // ## Ba cái giá, nói ra chứ không giấu
    //
    // 1. **Chữ cũ bị PHỦ, không bị XOÁ.** Nó vẫn nằm trong luồng nội dung và vẫn trích ra được
    //    bằng lệnh "Lấy chữ ra tab mới" hay bất kỳ công cụ nào khác. Đây KHÔNG phải công cụ bôi
    //    đen: che một số căn cước bằng lối này là che với mắt người, không che với máy.
    // 2. **Không nhận diện font gốc.** Chữ mới vẽ bằng font hệ thống — cố ý, vì font trong tệp
    //    thường không có dấu tiếng Việt, và "Nguyễn" sẽ thành "Nguy?n" trên máy người nhận.
    //    Cái giá là chữ sửa khác kiểu với phần còn lại của dòng.
    // 3. **Màu phủ lấy MẪU từ trang.** Nền có hoa văn hay ảnh chạy qua ô thì vết vá lộ ra.
    //
    // Và MỘT khoản được, đo bằng bài kiểm chứ không đoán: **chữ mới vẫn nằm trong tầng chữ.**
    // `NSString.draw` vào `CGPDFContext` phát ra toán tử chữ thật, nên ⌘F vẫn tìm thấy nó và
    // chép ra được. Bản đầu của chú thích này khẳng định ngược lại — chép theo `mobiluck-reader`
    // §K, nơi Android buộc phải vẽ ảnh một bit. Bài kiểm bác bỏ, và mô tả sửa theo phép đo.

    /// Một thứ vẽ đè lên trang. Toạ độ theo hệ của trang PDF.
    private enum OverlayItem {
        case image(NSImage, rect: CGRect)
        case text(String, rect: CGRect)
    }

    /// Dựng một trang MỚI: trang cũ vẽ lại nguyên vẹn, rồi vẽ đè các mục lên.
    ///
    /// Trả `nil` khi không dựng nổi ngữ cảnh PDF — chỗ gọi phải coi đó là thất bại và KHÔNG
    /// đụng tới tài liệu, chứ không thay bằng một trang trống.
    private func overlaid(page: PDFPage, items: [OverlayItem]) -> PDFPage? {
        var box = page.bounds(for: .mediaBox)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return nil }

        context.beginPDFPage(nil)
        page.draw(with: .mediaBox, to: context)

        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        for item in items {
            switch item {
            case let .image(image, rect):
                image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            case let .text(text, rect):
                draw(text: text, in: rect)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: data as Data)?.page(at: 0)
    }

    /// Vẽ chữ vừa khít trong `rect`, co cỡ chữ cho tới khi lọt.
    ///
    /// Co cỡ thay vì cắt bớt chữ: một số liệu bị cắt mất chữ số cuối là một số liệu SAI mà trông
    /// vẫn hợp lệ, còn chữ nhỏ hơn một chút thì chỉ khó đọc hơn một chút.
    private func draw(text: String, in rect: CGRect) {
        var size = min(rect.height * 0.8, 24)
        var attributes: [NSAttributedString.Key: Any] = [:]
        var measured = CGSize.zero
        while size > 4 {
            attributes = [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black]
            measured = (text as NSString).size(withAttributes: attributes)
            if measured.width <= rect.width { break }
            size -= 0.5
        }
        let origin = CGPoint(x: rect.minX, y: rect.midY - measured.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    /// Thay một trang trong tài liệu, có ghi phép ngược.
    private func replacePage(at index: Int, with new: PDFPage) {
        guard let document = pdfView.document, let old = document.page(at: index) else { return }
        document.removePage(at: index)
        document.insert(new, at: index)
        recordPageEdit { [weak document] in
            document?.removePage(at: index)
            document?.insert(old, at: index)
        }
    }

    /// Màu nền lấy mẫu ngay bên TRÁI vùng cần phủ.
    ///
    /// Lấy mẫu thay vì tô trắng cứng: rất nhiều biểu mẫu có nền kem hoặc ô xám nhạt, và một vệt
    /// trắng giữa nền kem lộ hơn hẳn chữ cũ. Không lấy được thì lùi về trắng.
    private func sampledBackground(of page: PDFPage, near rect: CGRect) -> NSColor {
        let probe = CGRect(x: max(rect.minX - 6, 0), y: rect.midY - 1, width: 2, height: 2)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return .white }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        context.cgContext.translateBy(x: -probe.minX, y: -probe.minY)
        page.draw(with: .mediaBox, to: context.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        return rep.colorAt(x: 0, y: 0) ?? .white
    }

    // MARK: Ký

    /// Chèn ảnh chữ ký lên trang đang xem.
    ///
    /// **Chỗ đặt lấy từ VÙNG ĐANG CHỌN nếu có.** Người ta ký vào chỗ có chữ "Ký tên" hoặc một
    /// dòng kẻ; bôi chọn đúng chỗ ấy rồi bấm là chữ ký rơi vào đó. Không chọn gì thì đặt ở góc
    /// dưới bên phải — chỗ mặc định của gần như mọi văn bản.
    @objc private func insertSignatureFromPanel(_ sender: Any?) {
        guard let document = pdfView.document, let index = currentPageIndex,
              let page = document.page(at: index) else { return }

        let panel = NSOpenPanel()
        panel.message = L("Chọn ảnh chữ ký (nền trong suốt thì đẹp nhất)")
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url,
              let image = NSImage(contentsOf: url) else { return }

        insertSignature(image: image, on: page, at: index)
    }

    private func insertSignature(image: NSImage, on page: PDFPage, at index: Int) {
        let rect = signatureRect(on: page, imageSize: image.size)
        guard let new = overlaid(page: page, items: [.image(image, rect: rect)]) else {
            onStatus?(L("Không dựng được trang có chữ ký"))
            return
        }
        replacePage(at: index, with: new)
        onStatus?(LF("Đã chèn chữ ký vào trang %d", index + 1))
    }

    /// Khung đặt chữ ký, giữ đúng tỉ lệ ảnh.
    private func signatureRect(on page: PDFPage, imageSize: NSSize) -> CGRect {
        let box = page.bounds(for: .mediaBox)
        var target: CGRect
        if let selection = pdfView.currentSelection, !selection.pages.isEmpty,
           selection.pages.contains(page) {
            target = selection.bounds(for: page)
        } else {
            let width = box.width * 0.3
            target = CGRect(x: box.maxX - width - box.width * 0.08,
                            y: box.minY + box.height * 0.08,
                            width: width, height: box.height * 0.1)
        }
        guard imageSize.width > 0, imageSize.height > 0 else { return target }
        // Giữ tỉ lệ ảnh: một chữ ký bị kéo dẹt hay kéo dài trông giả ngay lập tức.
        let scale = min(target.width / imageSize.width, target.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: target.midX - size.width / 2, y: target.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    // MARK: Sửa chữ

    /// Phủ vùng đang chọn rồi vẽ chữ mới lên.
    @objc private func replaceSelectedText(_ sender: Any?) {
        guard let document = pdfView.document, let index = currentPageIndex,
              let page = document.page(at: index) else { return }
        guard let selection = pdfView.currentSelection, selection.pages.contains(page) else {
            onStatus?(L("Hãy bôi chọn phần chữ cần sửa trước"))
            return
        }
        let rect = selection.bounds(for: page)
        guard rect.width > 1, rect.height > 1 else {
            onStatus?(L("Vùng chọn quá nhỏ"))
            return
        }

        let alert = NSAlert()
        alert.messageText = L("Sửa chữ")
        alert.informativeText = L("Chữ mới được VẼ ĐÈ lên vùng đã chọn bằng font hệ thống. Chữ cũ bị che chứ không bị xoá — nó vẫn trích ra được, nên đây không phải cách bôi đen.")
        alert.addButton(withTitle: L("Vẽ đè"))
        alert.addButton(withTitle: L("Huỷ"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = selection.string ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }

        replaceText(with: field.stringValue, in: rect, on: page, at: index)
    }

    private func replaceText(with text: String, in rect: CGRect, on page: PDFPage, at index: Int) {
        // Nới vùng phủ ra một chút: hộp bao của phần chọn ôm sát nét chữ, và phủ đúng sát sẽ để
        // lại viền chân chữ cũ ở mép trên dưới.
        let cover = rect.insetBy(dx: -1.5, dy: -1.5)
        let background = sampledBackground(of: page, near: cover)
        guard let new = overlaid(page: page, items: [
            .image(solidImage(colour: background, size: cover.size), rect: cover),
            .text(text, rect: rect),
        ]) else {
            onStatus?(L("Không dựng được trang đã sửa"))
            return
        }
        replacePage(at: index, with: new)
        onStatus?(LF("Đã vẽ đè chữ mới lên trang %d", index + 1))
    }

    /// Một ảnh đặc một màu — dùng làm miếng vá nền.
    private func solidImage(colour: NSColor, size: CGSize) -> NSImage {
        let image = NSImage(size: NSSize(width: max(size.width, 1), height: max(size.height, 1)))
        image.lockFocus()
        colour.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - Biểu mẫu (AcroForm)
    //
    // ## Ô có sẵn thì ghi thành GIÁ TRỊ FORM, không làm phẳng
    //
    // Đây là chỗ khác `mobiluck-reader` §I, và khác có lý do. Bên ấy phải làm phẳng vì Android
    // không có bộ dựng form; ở đây PDFKit dựng widget và nhận gõ ngay trong khung xem, và
    // `PDFDocument.write` giữ lại giá trị. Ghi thành form sống có cái được thật: Acrobat của bên
    // nhận biết tờ khai đã điền, và người ta sửa lại được ô mình gõ sai.
    //
    // Làm phẳng vẫn còn chỗ của nó — chữ ký, và điền tay lên tờ đã scan không có ô nào. Hai thứ
    // ấy đi lối `PDFOverlay`, không đi lối này.
    //
    // ## Nói RA khi tệp có ô điền được
    //
    // Một biểu mẫu mở ra trông y hệt một PDF thường, và người dùng không có cách nào biết mình
    // gõ được vào đấy nếu không thử bấm. Câu thông báo lúc mở là thứ rẻ nhất giải quyết chuyện đó.

    /// Mọi ô biểu mẫu trong tài liệu, theo thứ tự trang.
    private var formFields: [PDFAnnotation] {
        guard let document = pdfView.document else { return [] }
        // Lọc theo `type == "Widget"`, KHÔNG theo `widgetFieldType`: thuộc tính ấy không phải
        // optional, nên nó trả một giá trị cho cả chú thích bôi vàng — và bộ lọc `!= nil` sẽ
        // đếm mọi chú thích thành ô biểu mẫu. Trình biên dịch cảnh báo đúng chỗ ấy.
        return (0 ..< document.pageCount).flatMap { index in
            document.page(at: index)?.annotations.filter { $0.type == "Widget" } ?? []
        }
    }

    /// Xoá mọi giá trị người dùng đã điền, đưa biểu mẫu về trạng thái trắng.
    ///
    /// Không đụng tới cấu trúc ô — chỉ xoá giá trị. Gỡ hẳn widget đi là biến một biểu mẫu điền
    /// được thành một tờ giấy chết, và người dùng không lấy lại được bằng `⌘Z` nào.
    @objc private func resetFormFields(_ sender: Any?) {
        let fields = formFields
        guard !fields.isEmpty else {
            onStatus?(L("Tệp này không có ô biểu mẫu nào"))
            return
        }
        var previous: [(field: PDFAnnotation, text: String?, state: String?)] = []
        for field in fields {
            previous.append((field, field.widgetStringValue, field.buttonWidgetStateString))
            switch field.widgetFieldType {
            case .button:
                field.buttonWidgetState = .offState
            default:
                field.widgetStringValue = ""
            }
        }
        recordPageEdit {
            for item in previous {
                if item.field.widgetFieldType == .button {
                    item.field.buttonWidgetStateString = item.state ?? ""
                } else {
                    item.field.widgetStringValue = item.text ?? ""
                }
            }
        }
        onStatus?(LF("Đã xoá nội dung của %d ô biểu mẫu", fields.count))
    }

    /// Nhảy tới ô biểu mẫu chưa điền đầu tiên — đường đi tự nhiên khi khai một tờ dài.
    @objc private func goToNextEmptyField(_ sender: Any?) {
        let fields = formFields
        guard !fields.isEmpty else {
            onStatus?(L("Tệp này không có ô biểu mẫu nào"))
            return
        }
        let empty = fields.filter {
            $0.widgetFieldType != .button && (($0.widgetStringValue ?? "").isEmpty)
        }
        guard let next = empty.first, let page = next.page else {
            onStatus?(L("Mọi ô biểu mẫu đều đã có nội dung"))
            return
        }
        pdfView.go(to: page)
        pdfView.go(to: next.bounds, on: page)
        onStatus?(LF("Còn %d ô chưa điền", empty.count))
    }

    /// Câu thông báo lúc mở, khi tệp có ô điền được.
    private func announceFormFieldsIfAny() {
        let fields = formFields
        guard !fields.isEmpty else { return }
        onStatus?(LF("Biểu mẫu điền được: %d ô. Gõ thẳng vào ô, rồi «Lưu bản đã sửa…»",
                     fields.count))
    }

    // MARK: Xoay

    @objc private func rotateLeft(_ sender: Any?) { rotateCurrentPage(by: -90) }
    @objc private func rotateRight(_ sender: Any?) { rotateCurrentPage(by: 90) }

    private func rotateCurrentPage(by degrees: Int) {
        guard let document = pdfView.document, let index = currentPageIndex,
              let page = document.page(at: index) else { return }
        page.rotation += degrees
        recordPageEdit { [weak page] in page?.rotation -= degrees }
        onStatus?(LF("Đã xoay trang %d", index + 1))
    }

    // MARK: Xoá

    @objc private func deletePages(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        guard let text = askPageRange(
            title: L("Xoá trang"),
            message: LF("Tài liệu có %d trang. Nhập trang cần xoá, ví dụ 2-4,7", document.pageCount)
        ) else { return }

        let indices: IndexSet
        do {
            indices = try PageRange.parse(text, pageCount: document.pageCount)
        } catch {
            onStatus?("\(error)")
            return
        }
        guard indices.count < document.pageCount else {
            // Xoá hết trang cho ra một PDF không có trang nào — thứ nhiều trình đọc từ chối mở.
            // Người muốn bỏ cả tệp thì xoá tệp, không xoá từng trang.
            onStatus?(L("Không xoá được TẤT CẢ trang — một PDF phải còn ít nhất một trang"))
            return
        }

        // Xoá từ CHỈ SỐ LỚN xuống nhỏ: xoá xuôi thì mỗi lần xoá làm mọi chỉ số phía sau tụt một,
        // và tập chỉ số người dùng nhập lập tức trỏ sai chỗ.
        var removed: [(index: Int, page: PDFPage)] = []
        for index in indices.sorted(by: >) {
            guard let page = document.page(at: index) else { continue }
            removed.append((index, page))
            document.removePage(at: index)
        }
        let mo_ta = PageRange.describe(indices)
        recordPageEdit { [weak document] in
            // Chèn lại theo chiều NGƯỢC lại lúc xoá, tức từ chỉ số nhỏ lên lớn.
            for item in removed.reversed() { document?.insert(item.page, at: item.index) }
        }
        onStatus?(LF("Đã xoá trang %@ · còn %d trang", mo_ta, document.pageCount))
    }

    // MARK: Dời

    @objc private func movePageUp(_ sender: Any?) { moveCurrentPage(by: -1) }
    @objc private func movePageDown(_ sender: Any?) { moveCurrentPage(by: 1) }

    private func moveCurrentPage(by offset: Int) {
        guard let document = pdfView.document, let from = currentPageIndex else { return }
        let to = from + offset
        guard to >= 0, to < document.pageCount else {
            onStatus?(offset < 0 ? L("Đã ở trang đầu") : L("Đã ở trang cuối"))
            return
        }
        // `exchangePage` đổi chỗ HAI trang. Với bước ±1 thì đổi chỗ đúng bằng dời, và nó rẻ hơn
        // remove+insert; phép ngược của nó là chính nó.
        document.exchangePage(at: from, withPageAt: to)
        recordPageEdit { [weak document] in document?.exchangePage(at: to, withPageAt: from) }
        if let page = document.page(at: to) { pdfView.go(to: page) }
        onStatus?(LF("Trang %d → %d", from + 1, to + 1))
    }

    // MARK: Trích

    /// Trích một dãy trang ra tệp PDF mới. KHÔNG đụng tài liệu đang mở.
    @objc private func extractPages(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        guard let text = askPageRange(
            title: L("Trích trang ra tệp mới"),
            message: LF("Tài liệu có %d trang. Nhập trang cần trích, ví dụ 1-3,8", document.pageCount)
        ) else { return }

        let indices: IndexSet
        do {
            indices = try PageRange.parse(text, pageCount: document.pageCount)
        } catch {
            onStatus?("\(error)")
            return
        }

        // Đi qua `pages(of:at:)` — CÙNG hàm mà phép tách dùng, và cùng hàm mà bài tự kiểm gọi.
        // Trước đây chỗ này có vòng lặp riêng còn bài tự kiểm có vòng lặp thứ ba: ba bản của
        // một quy tắc, và bài kiểm khi ấy chứng minh bản CỦA NÓ đúng chứ không chứng minh gì về
        // lệnh người dùng bấm.
        let out = pages(of: document, at: indices)
        guard out.pageCount > 0 else { return }

        let base = (path.map { ($0 as NSString).lastPathComponent } ?? "tai-lieu.pdf")
        let suggested = (base as NSString).deletingPathExtension + "-trich.pdf"
        writeVerified(out, suggestedName: suggested, what: LF("trang %@", PageRange.describe(indices)))
    }

    // MARK: Tách

    /// Tách tài liệu thành HAI tệp tại một dãy trang: phần đã chọn, và phần còn lại.
    ///
    /// Hai tệp chứ không phải một, và cả hai đều được ghi trong cùng một lần hỏi. Cắt ra một
    /// nửa rồi bỏ nửa kia là bắt người dùng chạy lại lệnh với dãy bù — mà tính dãy bù bằng tay
    /// chính là chỗ người ta gõ nhầm.
    @objc private func splitPDF(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        guard let text = askPageRange(
            title: L("Tách tệp PDF"),
            message: LF("Tài liệu có %d trang. Nhập phần tách ra, ví dụ 1-5; phần còn lại ghi thành tệp thứ hai.",
                        document.pageCount)
        ) else { return }

        let indices: IndexSet
        do {
            indices = try PageRange.parse(text, pageCount: document.pageCount)
        } catch {
            onStatus?("\(error)")
            return
        }
        guard indices.count < document.pageCount else {
            onStatus?(L("Phần tách ra là toàn bộ tài liệu — không có gì để tách"))
            return
        }

        let base = (path.map { ($0 as NSString).lastPathComponent } ?? "tai-lieu.pdf")
        let stem = (base as NSString).deletingPathExtension

        // Hỏi chỗ ghi MỘT lần, rồi ghi hai tệp cạnh nhau. Hai hộp thoại liên tiếp cho một lệnh
        // là chỗ người dùng bấm Huỷ ở hộp thứ hai và còn lại đúng một nửa kết quả.
        let panel = NSSavePanel()
        panel.nameFieldStringValue = stem + "-phan-1.pdf"
        panel.message = L("Chọn chỗ ghi. Tệp thứ hai ghi cạnh tệp này.")
        guard Unattended.chooseFile(panel) == .OK, let first = panel.url else { return }
        _ = split(document, at: indices, to: first)
    }

    /// Ghi hai tệp: phần đã chọn ra `first`, phần còn lại ra tệp cạnh nó.
    ///
    /// Tách khỏi phần HỎI vì hộp chọn file luôn trả `.abort` trong lượt chạy không người — xem
    /// `Unattended.chooseFile`. Gộp thì cả phép tách không có đường nào chạy được dưới bộ tự
    /// kiểm, mà nó lại là phép ghi RA HAI TỆP: hỏng nửa chừng là để lại đúng một nửa kết quả.
    @discardableResult
    private func split(_ document: PDFDocument, at indices: IndexSet, to first: URL) -> Bool {
        let second = first.deletingLastPathComponent()
            .appendingPathComponent(
                first.deletingPathExtension().lastPathComponent + "-con-lai.pdf")

        let chosen = pages(of: document, at: indices)
        let rest = pages(of: document, at: IndexSet(0 ..< document.pageCount).subtracting(indices))
        guard writeVerified(chosen, to: first, what: LF("trang %@", PageRange.describe(indices))),
              writeVerified(rest, to: second, what: L("phần còn lại"))
        else { return false }
        onStatus?(LF("Đã tách thành %@ (%d trang) và %@ (%d trang)",
                     first.lastPathComponent, chosen.pageCount,
                     second.lastPathComponent, rest.pageCount))
        return true
    }

    /// Một tài liệu mới gồm các trang đã chọn, chép ra chứ không mượn.
    private func pages(of document: PDFDocument, at indices: IndexSet) -> PDFDocument {
        let out = PDFDocument()
        for (slot, index) in indices.sorted().enumerated() {
            guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
            out.insert(page, at: slot)
        }
        return out
    }

    // MARK: Xuất ảnh

    /// Xuất một dãy trang thành ảnh PNG, mỗi trang một tệp.
    @objc private func exportPagesAsImages(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        guard let text = askPageRange(
            title: L("Xuất trang ra ảnh PNG"),
            message: LF("Tài liệu có %d trang. Nhập trang cần xuất, ví dụ 1-3", document.pageCount)
        ) else { return }

        let indices: IndexSet
        do {
            indices = try PageRange.parse(text, pageCount: document.pageCount)
        } catch {
            onStatus?("\(error)")
            return
        }

        let panel = NSOpenPanel()
        panel.message = L("Chọn thư mục ghi ảnh")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard Unattended.chooseFile(panel) == .OK, let folder = panel.url else { return }
        _ = exportImages(document, at: indices, into: folder)
    }

    /// Ghi từng trang trong `indices` thành một PNG trong `folder`; trả về số ảnh đã ghi.
    ///
    /// Tách khỏi phần hỏi, cùng lý do với `split(_:at:to:)`.
    @discardableResult
    private func exportImages(
        _ document: PDFDocument, at indices: IndexSet, into folder: URL
    ) -> Int {
        var written = 0
        for index in indices.sorted() {
            guard let page = document.page(at: index) else { continue }
            let name = String(format: "trang-%03d.png", index + 1)
            if writePageImage(page, to: folder.appendingPathComponent(name)) { written += 1 }
        }
        onStatus?(written == indices.count
            ? LF("Đã xuất %d ảnh vào %@", written, folder.lastPathComponent)
            : LF("Chỉ xuất được %d/%d ảnh", written, indices.count))
        return written
    }

    /// Vẽ một trang ra PNG.
    ///
    /// **Vẽ ở tỉ lệ 2× chứ không dùng `thumbnail(of:for:)`.** Ảnh thu nhỏ sinh ra để hiện trong
    /// cột bên trái, cỡ trăm điểm; xuất nó ra tệp cho một trang A4 thì chữ nhoè không đọc nổi.
    /// Ở đây vẽ lại trang vào một bitmap theo đúng cỡ trang nhân đôi.
    private func writePageImage(_ page: PDFPage, to url: URL) -> Bool {
        let box = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let width = Int(box.width * scale), height = Int(box.height * scale)
        guard width > 0, height > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return false }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // Nền TRẮNG, không để trong suốt: PDF không có nền, và một PNG nền trong suốt dán vào
        // slide nền tối sẽ ra chữ đen trên nền đen.
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)).fill()
        context.cgContext.scaleBy(x: scale, y: scale)
        context.cgContext.translateBy(x: -box.origin.x, y: -box.origin.y)
        page.draw(with: .mediaBox, to: context.cgContext)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }

    // MARK: Gộp

    /// Chèn toàn bộ một tệp PDF khác vào NGAY SAU trang đang xem.
    @objc private func mergePDFFromPanel(_ sender: Any?) {
        guard let document = pdfView.document else { return }
        let panel = NSOpenPanel()
        panel.message = L("Chọn tệp PDF cần gộp vào")
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        mergePDF(at: url, into: document)
    }

    private func mergePDF(at url: URL, into document: PDFDocument) {
        guard let other = PDFDocument(url: url) else {
            onStatus?(LF("Không đọc được PDF «%@»", url.lastPathComponent))
            return
        }
        guard !other.isLocked else {
            onStatus?(LF("«%@» có mật khẩu — chưa gộp được", url.lastPathComponent))
            return
        }
        guard other.pageCount > 0 else {
            onStatus?(LF("«%@» không có trang nào", url.lastPathComponent))
            return
        }

        let insertAt = (currentPageIndex ?? document.pageCount - 1) + 1
        for offset in 0 ..< other.pageCount {
            guard let page = other.page(at: offset)?.copy() as? PDFPage else { continue }
            document.insert(page, at: insertAt + offset)
        }
        let added = other.pageCount
        recordPageEdit { [weak document] in
            for _ in 0 ..< added { document?.removePage(at: insertAt) }
        }
        onStatus?(LF("Đã gộp %d trang từ «%@»", added, url.lastPathComponent))
    }

    // MARK: Hoàn tác

    @objc private func undoPageEdit(_ sender: Any?) {
        guard let undo = pageUndoStack.popLast() else {
            onStatus?(L("Không còn thao tác trang nào để hoàn tác"))
            return
        }
        undo()
        hasUnsavedPageEdits = !pageUndoStack.isEmpty
        refreshAfterPageEdit()
        onStatus?(L("Đã hoàn tác một thao tác trang"))
    }

    // MARK: Hộp nhập dãy trang

    /// Hỏi một dãy trang. Trả `nil` khi người dùng huỷ hoặc khi đang chạy không người lái.
    private func askPageRange(title: String, message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("Áp dụng"))
        alert.addButton(withTitle: L("Huỷ"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "1-3,5"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        // `Unattended.ask` chứ không `runModal` thẳng: lượt chạy không người lái phải BỎ QUA
        // hộp thoại và ghi lại là đã bỏ qua, chứ không treo ở một hộp không ai bấm.
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    /// Ghi một tài liệu ra tệp người dùng chọn, rồi MỞ LẠI kiểm chứng.
    ///
    /// Tách thành hàm riêng vì cả `saveCopy` lẫn `extractPages` cần đúng vòng ấy — và vòng kiểm
    /// chứng là phần dễ bị bỏ qua nhất khi viết lần thứ hai.
    @discardableResult
    private func writeVerified(_ document: PDFDocument, suggestedName: String, what: String) -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return false }
        return writeVerified(document, to: url, what: what)
    }

    private func writeVerified(_ document: PDFDocument, to url: URL, what: String) -> Bool {
        guard document.write(to: url) else {
            onStatus?(L("Không ghi được tệp"))
            return false
        }
        // ĐỐI CHỨNG: mở lại chính tệp vừa ghi và đòi nó còn đủ số trang — cùng luật với
        // `saveCopy`. Một tệp ghi hỏng vẫn nằm trên đĩa trông như một tệp bình thường.
        guard let again = PDFDocument(url: url), again.pageCount == document.pageCount else {
            onStatus?(L("Tệp vừa ghi mở lại KHÔNG đúng — đừng dùng bản này"))
            return false
        }
        onStatus?(LF("Đã ghi %@ — %@ · %d trang", url.lastPathComponent, what, again.pageCount))
        return true
    }

    // MARK: - Cho bài tự kiểm

    var pageCountForSelfTest: Int { pdfView.document?.pageCount ?? 0 }
    var hasDocumentForSelfTest: Bool { pdfView.document != nil }
    var pageLabelForSelfTest: String { pageLabel.stringValue }
    var annotationCountForSelfTest: Int {
        guard let document = pdfView.document else { return 0 }
        return (0 ..< document.pageCount)
            .compactMap { document.page(at: $0)?.annotations.count }
            .reduce(0, +)
    }
    func searchForSelfTest(_ needle: String) -> Int {
        searchField.stringValue = needle
        runSearch(nil)
        return matches.count
    }
    func selectAllTextOnFirstPageForSelfTest() {
        guard let page = pdfView.document?.page(at: 0),
              let selection = page.selection(for: page.bounds(for: .mediaBox)) else { return }
        pdfView.setCurrentSelection(selection, animate: false)
    }
    func highlightForSelfTest() { highlightSelection(nil) }

    // --- Ký và sửa chữ ---
    func insertSignatureForSelfTest(_ image: NSImage) {
        guard let document = pdfView.document, let index = currentPageIndex,
              let page = document.page(at: index) else { return }
        insertSignature(image: image, on: page, at: index)
    }
    func replaceTextForSelfTest(_ text: String, rect: CGRect) {
        guard let document = pdfView.document, let index = currentPageIndex,
              let page = document.page(at: index) else { return }
        replaceText(with: text, in: rect, on: page, at: index)
    }
    /// Vùng bao của trang, để bài kiểm chọn một ô nằm trong trang.
    func pageBoundsForSelfTest(_ index: Int) -> CGRect {
        pdfView.document?.page(at: index)?.bounds(for: .mediaBox) ?? .zero
    }

    // --- Biểu mẫu ---
    /// Dựng một ô văn bản trong trang đang xem, để bài kiểm có biểu mẫu mà thử.
    ///
    /// Dựng bằng chính API của PDFKit chứ không kèm một tệp AcroForm mẫu trong kho: tệp mẫu thì
    /// bài kiểm chạy được ở bản dựng phát triển và bị sandbox chặn trong bundle App Store — đúng
    /// cái bẫy đã làm ba bài Office xanh giả.
    @discardableResult
    func addTextFieldForSelfTest(name: String) -> Bool {
        guard let page = pdfView.document?.page(at: 0) else { return false }
        let box = page.bounds(for: .mediaBox)
        let widget = PDFAnnotation(
            bounds: CGRect(x: box.minX + 20, y: box.minY + 40, width: 200, height: 22),
            forType: .widget, withProperties: nil)
        widget.widgetFieldType = .text
        widget.fieldName = name
        page.addAnnotation(widget)
        return true
    }

    var formFieldCountForSelfTest: Int { formFields.count }
    func formValueForSelfTest(_ index: Int) -> String? {
        let fields = formFields
        guard index < fields.count else { return nil }
        return fields[index].widgetStringValue
    }
    func setFormValueForSelfTest(_ index: Int, _ text: String) {
        let fields = formFields
        guard index < fields.count else { return }
        fields[index].widgetStringValue = text
    }
    func resetFormForSelfTest() { resetFormFields(nil) }

    /// Đọc LẠI một tệp trên đĩa và trả giá trị các ô biểu mẫu — để bài kiểm hỏi tệp, không hỏi
    /// biến trong bộ nhớ.
    static func formValuesForSelfTest(_ path: String) -> [String] {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else { return [] }
        return (0 ..< document.pageCount).flatMap { index in
            document.page(at: index)?.annotations
                .filter { $0.type == "Widget" }
                .map { $0.widgetStringValue ?? "" } ?? []
        }
    }

    // --- Tầng công cụ trang ---
    var hasUnsavedPageEditsForSelfTest: Bool { hasUnsavedPageEdits }
    var undoDepthForSelfTest: Int { pageUndoStack.count }
    func rotationForSelfTest(page: Int) -> Int { pdfView.document?.page(at: page)?.rotation ?? 0 }
    /// Chữ của trang thứ `page`, để bài kiểm biết trang nào đang đứng ở đâu sau khi dời/xoá.
    func textForSelfTest(page: Int) -> String {
        (pdfView.document?.page(at: page)?.string ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func goToPageForSelfTest(_ index: Int) {
        guard let page = pdfView.document?.page(at: index) else { return }
        pdfView.go(to: page)
    }
    func rotateForSelfTest(_ degrees: Int) { rotateCurrentPage(by: degrees) }
    func movePageForSelfTest(by offset: Int) { moveCurrentPage(by: offset) }
    func undoPageEditForSelfTest() { undoPageEdit(nil) }
    func mergeForSelfTest(path: String) {
        guard let document = pdfView.document else { return }
        mergePDF(at: URL(fileURLWithPath: path), into: document)
    }
    /// Xoá theo dãy trang, bỏ qua hộp nhập — bài kiểm cần đường đi CHUNG với nút bấm, nên hàm
    /// này gọi đúng phần việc, chỉ thay chỗ lấy chuỗi.
    /// Trả `false` khi phép xoá bị từ chối — câu chữ giải thích thuộc về bài kiểm, không thuộc
    /// về khung nhìn. Để view tự viết câu chẩn đoán là nhét chữ của người sửa mã vào một tệp mà
    /// mọi chuỗi khác đều là chữ cho người dùng.
    func deletePagesForSelfTest(_ spec: String) -> Bool {
        guard let document = pdfView.document else { return false }
        do {
            let indices = try PageRange.parse(spec, pageCount: document.pageCount)
            guard indices.count < document.pageCount else { return false }
            var removed: [(index: Int, page: PDFPage)] = []
            for index in indices.sorted(by: >) {
                guard let page = document.page(at: index) else { continue }
                removed.append((index, page))
                document.removePage(at: index)
            }
            recordPageEdit { [weak document] in
                for item in removed.reversed() { document?.insert(item.page, at: item.index) }
            }
            return true
        } catch {
            return false
        }
    }
    /// Trích ra tệp mới — đi qua CHÍNH `pages(of:at:)` mà lệnh trên menu dùng.
    ///
    /// Bản trước của hàm này có vòng lặp chép trang RIÊNG, nên nó chứng minh bản của nó đúng
    /// chứ không nói được gì về lệnh người dùng bấm.
    func extractForSelfTest(_ spec: String, to path: String) -> Bool {
        guard let document = pdfView.document,
              let indices = try? PageRange.parse(spec, pageCount: document.pageCount)
        else { return false }
        return writeVerified(pages(of: document, at: indices),
                             to: URL(fileURLWithPath: path), what: "")
    }

    /// Tách làm hai tệp — bỏ qua đúng hộp chọn chỗ ghi, phần còn lại đi đường thật.
    func splitForSelfTest(_ spec: String, to path: String) -> Bool {
        guard let document = pdfView.document,
              let indices = try? PageRange.parse(spec, pageCount: document.pageCount),
              indices.count < document.pageCount
        else { return false }
        return split(document, at: indices, to: URL(fileURLWithPath: path))
    }

    /// Xuất trang ra PNG — trả về số ảnh đã ghi.
    func exportImagesForSelfTest(_ spec: String, into folder: String) -> Int {
        guard let document = pdfView.document,
              let indices = try? PageRange.parse(spec, pageCount: document.pageCount)
        else { return 0 }
        return exportImages(document, at: indices, into: URL(fileURLWithPath: folder))
    }
    func extractTextForSelfTest() { extractText(nil) }
    func writeCopyForSelfTest(to path: String) -> Bool {
        guard let document = pdfView.document else { return false }
        return document.write(to: URL(fileURLWithPath: path))
    }

    /// Đọc LẠI một tệp PDF trên đĩa và đếm chú thích trong đó.
    ///
    /// Ở đây chứ không ở `SelfTest`: giữ mọi chỗ chạm tới PDFKit trong đúng một tệp, để câu
    /// "framework này chỉ được đụng khi người dùng mở PDF" còn kiểm được bằng mắt.
    /// Trả `(số trang, số chú thích)`, hoặc `nil` khi tệp mở lại không được.
    static func inspectForSelfTest(_ path: String) -> (pages: Int, annotations: Int)? {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else { return nil }
        let annotations = (0 ..< document.pageCount)
            .compactMap { document.page(at: $0)?.annotations.count }
            .reduce(0, +)
        return (document.pageCount, annotations)
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}
