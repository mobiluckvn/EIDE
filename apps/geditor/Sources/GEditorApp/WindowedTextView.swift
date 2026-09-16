import AppKit
import EIDEKit
import GEditorCore

/// Khung soạn thảo chạy trên CỬA SỔ nội dung — hiện thực quyết định ADR-01.
///
/// `NSTextView` chỉ giữ ~2 MB quanh chỗ đang xem; tài liệu nằm trong piece table trên mmap.
/// Đo trong PoC-A: 500 MB tốn 13,3 MB RAM (trần NFR là 1,5× cỡ file), gõ p95 3,3 ms.
///
/// Ba việc lớp này gánh, và cả ba đều là thứ `NSTextView` không tự làm được khi không giữ cả
/// tài liệu:
///
/// 1. **Thanh cuộn phải nói về CẢ TÀI LIỆU.** `NSTextView` chỉ biết 2 MB nó đang giữ, nên
///    documentView của scroll view là một khung rỗng cao bằng cả tài liệu, còn `NSTextView`
///    là một lớp con nằm đúng chỗ cửa sổ hiện tại bên trong khung ấy.
/// 2. **Cuộn ra ngoài cửa sổ thì nạp lại cửa sổ.** Đo được ~4,5 ms mỗi lần nạp.
/// 3. **Mọi API ra ngoài nói bằng OFFSET BYTE của tài liệu**, không phải offset UTF-16 của
///    view. Nhờ vậy phần còn lại của ứng dụng không phải biết cửa sổ tồn tại — và hai hàm quy
///    đổi O(n) cũ (`byteOffset(forUTF16Offset:)`) biến mất hẳn.
///
/// **Ngắt dòng mềm (FR-CORE-015)** phá giả định "chiều cao dòng đều nhau" mà lớp này từng đứng
/// lên. Cách giải: toàn bộ số học cuộn dọc chuyển sang `VerticalGeometry` của lõi — kiểm được
/// bằng test thay vì bằng mắt — với một tham số thêm là `rowsPerLine`. Số ấy ĐO trên cửa sổ
/// hiện tại rồi suy ra cả tài liệu, vì dựng bố cục đầy đủ 2 MB bằng TextKit 2 đo được 437 ms
/// trong khi mỗi lần nạp lại cửa sổ chỉ có 4,5 ms. Hệ quả và cách bù, xem `positionTextView`.
final class WindowedTextView: NSView {

    /// Chiều cao tối đa của khung cuộn, tính bằng point.
    ///
    /// 7,3 triệu dòng × 17 pt là 124 triệu point — AppKit không xử lý đúng ở cỡ ấy. Vượt ngưỡng
    /// thì khung bị NÉN lại và vị trí cuộn được quy đổi theo tỉ lệ: cuộn vẫn tới đúng chỗ, chỉ
    /// mất độ mịn khi kéo tay trên file rất lớn. Thà mất độ mịn còn hơn thanh cuộn hỏng.
    private static let maximumCanvasHeight: CGFloat = 4_000_000

    private let scrollView = NSScrollView()
    private let canvas = FlippedView()
    private let overlay = MultiCaretOverlay()
    let textView: NSTextView

    private(set) var buffer = TextBuffer(text: "")
    /// Tên là `textWindow` chứ không phải `window`: `NSView.window` đã chiếm tên ấy, và ghi
    /// đè nó là lỗi biên dịch — cùng kiểu va tên đã gặp với `NSWindowController.document`.
    private(set) var textWindow = TextWindowing.window(around: 0, in: TextBuffer(text: ""))

    /// Những vùng người dùng đang gấp lại (FR-CORE code folding).
    ///
    /// Giữ ở view chứ không ở tài liệu: gấp là một CÁCH NHÌN, không phải nội dung. Mở cùng một
    /// file ở hai khung thì mỗi khung gấp riêng, và lưu file không bao giờ ghi trạng thái gấp.
    private(set) var activeFolds: [FoldRange] = []

    /// Đang đồng bộ view từ buffer — mọi thay đổi lúc này KHÔNG phải do người dùng gõ.
    private var isSyncing = false

    var lineHeight: CGFloat = 17

    /// Cỡ chữ vùng soạn thảo (FR-CORE-016).
    ///
    /// Đây là chuyện của CÁCH NHÌN, không phải của tài liệu: đổi cỡ chữ không sinh một sửa đổi
    /// nào, không vào lịch sử hoàn tác, và không chạm một byte nào của file.
    ///
    /// Kẹp trong 8…32 pt. Dưới 8 pt thì con nháy nhỏ hơn một điểm ảnh vật lý ở màn hình thường
    /// và không thấy nó ở đâu; trên 32 pt thì một dòng 120 cột không còn lọt vào cửa sổ nào.
    var fontSize: CGFloat = 13 {
        didSet {
            fontSize = min(max(fontSize, 8), 32)
            guard fontSize != oldValue else { return }
            applyFontSize()
        }
    }

    static let defaultFontSize: CGFloat = 13

    private func applyFontSize() {
        let font = Tokens.Font.editor(size: fontSize)
        lineHeight = (font.ascender - font.descender + font.leading).rounded(.up)
        textView.font = font
        // Cỡ chữ đổi thì MỌI phép đo hình học đổi theo: bề rộng cột cho chế độ ngắt dòng tại
        // cột, chiều cao dòng cho thanh cuộn ảo, và hàng tiêu đề dính của bảng CSV. Đi đúng
        // đường mà `wrapMode` đã đi — dựng lại bố cục rồi đưa con nháy về chỗ cũ.
        let caret = selectedDocumentRange
        applyWrapMode()
        repaginate(around: caret.lowerBound)
        setSelectedDocumentRange(caret)
        reveal(documentOffset: caret.lowerBound)
        refreshCSVHeader()
        needsLayout = true
    }

    /// Số cột một ký tự TAB chiếm — cần cho thụt lề treo khi ngắt dòng. Chủ đặt theo status bar.
    var tabWidth: Int = 4

    /// Chữ ghép (ligature) — NFR-USE-05. Mặc định TẮT; xem `Settings.ligatures` để biết vì sao.
    var ligatures: Bool = false {
        didSet {
            guard ligatures != oldValue else { return }
            applyLigatures()
        }
    }

    /// Giá trị thuộc tính chữ ghép mà CHỮ ĐANG HIỆN mang, và mà chữ sắp gõ sẽ mang.
    ///
    /// Hai con số riêng vì chúng đến từ hai chỗ khác nhau và có thể lệch nhau — xem ghi chú ở
    /// `applyLigatures`.
    var ligatureInStorageForSelfTest: Int? {
        guard let storage = textView.textContentStorage?.textStorage, storage.length > 0
        else { return nil }
        return storage.attribute(.ligature, at: 0, effectiveRange: nil) as? Int
    }

    var ligatureWhenTypingForSelfTest: Int? {
        textView.typingAttributes[.ligature] as? Int
    }

    /// Đặt thuộc tính chữ ghép cho CẢ cửa sổ đang hiện và cho chữ sắp gõ.
    ///
    /// Hai chỗ chứ không một: `typingAttributes` chỉ áp cho ký tự người dùng gõ tiếp theo, còn
    /// chữ đã có trên màn hình nằm trong `NSTextStorage`. Đặt thiếu một chỗ thì công tắc có tác
    /// dụng với đúng nửa màn hình — nửa vừa gõ thì đổi, nửa nạp từ tệp thì không.
    ///
    /// Giá trị `0` là TẮT HẲN, `1` là mức mặc định của font (chỉ những cặp bắt buộc). Không
    /// dùng `2` (mọi chữ ghép, kể cả tuỳ chọn): mức ấy bật cả những cặp mà nhà thiết kế font
    /// coi là trang trí, và với một trình soạn thảo mã thì đó là thêm bất ngờ chứ không thêm
    /// giá trị.
    ///
    /// **Lượt nạp cửa sổ mới KHÔNG cần gọi lại hàm này**, và điều đó đáng ghi vì nó phản trực
    /// giác: `NSTextView.string = …` áp `typingAttributes` cho cả chuỗi mới, nên thuộc tính đi
    /// theo. Bản đầu có thêm một lời gọi ở chỗ nạp cửa sổ; nhát bẻ bỏ lời gọi ấy KHÔNG làm bài
    /// kiểm đỏ, tức nó là mã không ai chạm tới — nên nó bị bỏ. Hàng rào thật là bài tự kiểm
    /// cuộn qua mốc 2 MB rồi hỏi lại thuộc tính: nếu ngày nào đó chỗ nạp đổi sang
    /// `textStorage.replaceCharacters`, bài ấy đỏ.
    private func applyLigatures() {
        let value = ligatures ? 1 : 0
        textView.typingAttributes[.ligature] = value
        guard let storage = textView.textContentStorage?.textStorage else { return }
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttribute(.ligature, value: value, range: whole)
        storage.endEditing()
    }

    /// Số hàng màn hình trung bình cho mỗi dòng tài liệu; 1 khi tắt ngắt dòng mềm.
    ///
    /// Đo lại ở mỗi lần nạp cửa sổ. Đây là chỗ DUY NHẤT của lớp này còn là ước lượng.
    private var rowsPerLine: Double = 1

    /// Ba chế độ ngắt dòng mềm của FR-CORE-015.
    ///
    /// Mặc định TẮT, cùng nếp với Notepad++: người di cư sang không bị đổi hành vi dưới chân,
    /// và với file log hàng Gigabyte thì tắt wrap là chế độ đọc được duy nhất — một dòng 2 MB
    /// mà bật wrap sẽ thành mấy vạn hàng che kín màn hình.
    var wrapMode: WrapMode = .off {
        didSet {
            guard wrapMode != oldValue else { return }
            let caret = selectedDocumentRange
            let started = Date()
            applyWrapMode()
            repaginate(around: caret.lowerBound)
            setSelectedDocumentRange(caret)
            reveal(documentOffset: caret.lowerBound)
            if ProcessInfo.processInfo.environment["GEDITOR_TRACE_WRAP"] != nil {
                NSLog("[wrap] đổi sang %@: %.1f ms · %d dòng · %.2f hàng/dòng",
                      wrapMode.displayName, Date().timeIntervalSince(started) * 1000,
                      buffer.lineCount, rowsPerLine)
            }
        }
    }

    /// Số cột vừa một hàng ở chế độ hiện tại; 0 khi không ngắt.
    ///
    /// Font vùng soạn thảo là font ĐƠN CÁCH (SF Mono → Menlo), nên chia bề rộng cho bề rộng một
    /// ký tự là phép đúng chứ không phải phép xấp xỉ.
    private var columnsPerRow: Int {
        switch wrapMode {
        case .off:
            return 0
        case .column(let column):
            return Swift.max(1, column)
        case .window:
            let width = textContainerWidth
            let advance = characterWidth
            guard advance > 0 else { return 0 }
            return Swift.max(1, Int(width / advance))
        }
    }

    private var characterWidth: CGFloat {
        (textView.font ?? Tokens.Font.editor()).maximumAdvancement.width
    }

    /// Bề rộng dành cho chữ, đã trừ lề trái/phải.
    private var textContainerWidth: CGFloat {
        Swift.max(scrollView.contentSize.width - 2 * textView.textContainerInset.width, 1)
    }

    /// Chín tập đánh dấu dòng (FR-SRCH-107). Nền dòng vẽ ở lớp phủ, DƯỚI chữ.
    /// Dấu EIDE ở LỀ TRÁI — chú thích fact và vi phạm constant-guard.
    ///
    /// ## Vì sao không mượn `lineMarks`
    ///
    /// `lineMarks` là tính năng đánh dấu dòng CỦA NGƯỜI DÙNG: họ tự đặt, tự xoá, và có lệnh
    /// "xoá mọi dòng đã đánh dấu". Ghi dấu fact vào đó thì EIDE đè lên việc của họ, và một lệnh
    /// xoá dấu sẽ xoá luôn chú thích tri thức. Hai thứ khác chủ, hai kho riêng.
    ///
    /// ## Vì sao một vạch ở lề chứ không tô cả dòng
    ///
    /// Tô nền cả dòng là thứ `lineMarks` làm, và nó đúng cho "những dòng tôi đang quan tâm".
    /// Với chú thích tri thức thì nền màu trên mọi dòng có fact sẽ biến một tệp được trích dẫn
    /// tốt thành một tệp trông như đầy lỗi — ngược hẳn điều ta muốn nói. Một vạch 4 pt ở mép
    /// trái đủ để mắt quét dọc và không chạm vào chữ.
    enum DauEide: Equatable {
        /// Dòng mang `/* eide:fact f_… */` — có tri thức đứng sau.
        case coFact(String)
        /// Hằng số phần cứng KHÔNG trỏ fact nào; constant-guard chặn.
        case viPham(String)
    }

    /// Dòng (đếm từ 0) → dấu. Đặt lại cả bản đồ, không sửa từng phần.
    var dauEide: [Int: DauEide] = [:] {
        didSet {
            guard dauEide != oldValue else { return }
            overlay.needsDisplay = true
        }
    }

    var lineMarks = LineMarkBook() {
        didSet {
            guard lineMarks != oldValue else { return }
            overlay.needsDisplay = true
        }
    }

    // MARK: - Tô màu cú pháp (FR-FMT-501, ADR-04)

    private var asyncHighlighter: AsyncHighlighter?

    /// Số thứ tự của CỬA SỔ nội dung hiện tại.
    ///
    /// Khác với số thứ tự yêu cầu của `AsyncHighlighter`: cái kia chặn kết quả của một yêu cầu
    /// cũ, cái này chặn kết quả về đúng lúc nhưng cho một CỬA SỔ đã bị thay. Nạp lại cửa sổ
    /// thay hẳn chuỗi trong `NSTextView`, nên offset của kết quả cũ trỏ vào chữ khác.
    private var windowGeneration = 0
    private var highlightDebounce: Timer?

    /// Kết quả tô màu của CẢ cửa sổ, giữ lại để đặt thuộc tính dần theo tầm nhìn.
    ///
    /// Phân tích thì làm cho cả cửa sổ (rẻ, chạy nền, và cuộn trong cửa sổ là chuyện thường).
    /// ĐẶT THUỘC TÍNH thì chỉ làm cho phần nhìn thấy — đó là phần đắt, và đắt hơn nhiều so
    /// với tôi tưởng: đo được **5.170 ms** cho một cửa sổ 2 MB mã C, tức treo năm giây.
    private var pendingSpans: [HighlightSpan] = []
    /// Phần tài liệu đã đặt màu, để cuộn qua chỗ cũ không phải đặt lại.
    private var coloredRange: Range<Int>?

    /// Cùng vai trò, nhưng cho màu CỘT của CSV — xem `applyColumnColors`.
    ///
    /// Đi kèm `windowGeneration` chứ không tự xoá: `repaginate` thay hẳn chuỗi trong
    /// `NSTextStorage`, nên một phạm vi ghi nhớ từ cửa sổ trước không những vô nghĩa mà còn
    /// chặn mất lượt tô của cửa sổ mới. So thế hệ thì mọi đường nạp lại đều được bao, kể cả
    /// những đường thêm về sau mà người viết không nhớ tới chỗ này.
    private var columnColoredRange: Range<Int>?
    private var columnColoredGeneration = -1
    /// Dải cột ngang đã tô — cuộn NGANG cũng làm lộ ra ô chưa tô, không riêng cuộn dọc.
    private var columnColoredColumns: Range<Int>?

    /// Kiểu CSV đang tô màu theo cột; `nil` = không ở chế độ CSV (FR-CSV-402).
    var csvDialect: CSVDialect? {
        didSet {
            guard csvDialect != oldValue else { return }
            // Đổi kiểu CSV thì ranh giới cột đổi theo, nên phần đã tô không còn dùng lại được.
            columnColoredRange = nil
            columnColoredColumns = nil
            clearHighlighting()
            applyColumnColors()
            applySearchHighlights()
            applyLogColors()
            applyUserLanguageColors()
            refreshCSVHeader()
        }
    }

    private let csvHeader = CSVHeaderView()
    private var csvHeaderHeight: NSLayoutConstraint!

    /// Ngôn ngữ đang tô; `nil` = văn bản thuần.
    var syntaxLanguage: SyntaxLanguage? {
        didSet {
            guard syntaxLanguage != oldValue else { return }
            asyncHighlighter?.cancel()
            asyncHighlighter = syntaxLanguage.flatMap { AsyncHighlighter(language: $0) }
            clearHighlighting()
            requestHighlighting()
        }
    }

    private let invisibleSettings = InvisibleSettings()

    /// Nhóm ký tự ẩn đang hiện (FR-ENC-205).
    var invisibles: InvisibleOptions {
        get { invisibleSettings.options }
        set {
            let oldValue = invisibleSettings.options
            invisibleSettings.options = newValue
            guard newValue != oldValue else { return }
            // Đổi cách vẽ thì phải dựng lại bố cục, không chỉ vẽ lại: `NSTextLayoutFragment`
            // đã dựng xong vẫn là lớp cũ.
            // NẠP LẠI cửa sổ, không chỉ invalidateLayout.
            //
            // TextKit 2 giữ lại `NSTextLayoutFragment` đã dựng; `invalidateLayout` +
            // `needsDisplay` không làm nó gọi lại delegate, nên đoạn cũ vẽ tiếp bằng trạng
            // thái cũ. Bộ đếm nói thẳng: bật xong vẫn "vẽ 4 đoạn · 0 ký hiệu", và cả bốn lần
            // vẽ đều xảy ra TRƯỚC khi bật.
            //
            // Dựng lại chuỗi cửa sổ tốn ~4,5 ms; bật/tắt ký tự ẩn là thao tác hiếm.
            let caret = selectedDocumentRange
            repaginate(around: caret.lowerBound)
            setSelectedDocumentRange(caret)
        }
    }

    /// Tập caret ghi lại lúc bộ gõ BẮT ĐẦU soạn; `nil` khi không soạn.
    private var composition: MultiSelection?

    /// Nhiều caret (FR-CORE-001). Chỉ có một phần tử = trạng thái thường.
    ///
    /// `NSTextView` giữ caret CHÍNH; các caret phụ do lớp này tự vẽ và tự xử lý phím.
    ///
    /// **Đọc ra là KẸP vào buffer hiện tại**, cùng lý do với `selectedDocumentRange`: vùng chọn
    /// và nội dung đổi ở hai nhịp khác nhau, và một vùng chọn lạc hậu làm app sập chứ không
    /// làm sai một con số. Kẹp ở đây thì mọi chỗ gọi khỏi phải nhớ chuyện ấy tồn tại.
    var selection: MultiSelection {
        get { storedSelection.clamped(to: buffer.count) }
        set { storedSelection = newValue }
    }

    private var storedSelection = MultiSelection()

    /// Người dùng vừa sửa nội dung. Trả `false` để từ chối (tài liệu chỉ đọc).
    var onEdit: ((Range<Int>, String) -> Bool)?

    /// Điểm dưới-trái của con nháy, theo tọa độ MÀN HÌNH.
    ///
    /// Dùng để đặt danh sách gợi ý ngay dưới chỗ đang gõ. Đi qua `firstRect(forCharacterRange:)`
    /// — chính hàm mà bộ gõ dùng để đặt cửa sổ chọn chữ — nên danh sách gợi ý và bảng chọn của
    /// bộ gõ luôn xuất hiện ở cùng một chỗ.
    var caretScreenOrigin: NSPoint? {
        let range = textView.selectedRange()
        var actual = NSRange()
        let rect = textView.firstRect(forCharacterRange: range, actualRange: &actual)
        guard rect.width.isFinite, rect.height.isFinite else { return nil }
        return NSPoint(x: rect.minX, y: rect.minY)
    }

    /// Người dùng vừa gõ xong một nhịp — chỗ gọi cập nhật gợi ý tự hoàn thành (FR-CORE-013).
    var onTypingPause: (() -> Void)?
    /// Phím dành cho danh sách gợi ý (mũi tên, Enter, Esc). Trả `true` nghĩa là đã nuốt.
    ///
    /// Đi qua vùng soạn thảo chứ không để popup tự nhận phím: cho một cửa sổ khác nhận bàn phím
    /// giữa lúc bộ gõ tiếng Việt đang soạn dở một từ sẽ làm nó mất ngữ cảnh và nuốt dấu.
    var onCompletionKey: ((NSEvent) -> Bool)?

    /// Người dùng gõ/xóa khi đang có NHIỀU caret — chỗ gọi tự sinh và áp `[TextEdit]`.
    var onMultiEdit: ((MultiSelection, MultiEditKind) -> Void)?

    /// Bộ gõ vừa chốt một đoạn ở caret chính; chỗ gọi nhân nó sang các caret còn lại.
    var onCompositionCommitted: ((MultiSelection, String) -> Void)?

    enum MultiEditKind: Equatable {
        case insert(String)
        case deleteBackward
        case deleteForward
    }
    var onSelectionChange: (() -> Void)?

    /// Khung này vừa nhận con trỏ gõ. Chủ dùng nó để biết pane nào đang hoạt động (FR-DOC-302).
    var onFocus: (() -> Void)?

    /// Người dùng vừa ra một LỆNH soạn thảo (mũi tên, Home/End, xóa…).
    ///
    /// Đây là cửa để ghi macro (FR-AUTO-601). Không bắt bằng `keyDown`: một phím có thể ra
    /// lệnh khác nhau tuỳ bố cục bàn phím và tuỳ bộ gõ, còn `doCommand(by:)` là chỗ AppKit đã
    /// dịch phím thành Ý ĐỊNH. Macro ghi ý định thì phát lại đúng trên máy khác.
    var onCommand: ((Selector) -> Void)?

    // MARK: - Dựng

    override init(frame frameRect: NSRect) {
        textView = MultiCaretTextView(frame: .zero)
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let font = Tokens.Font.editor()
        lineHeight = (font.ascender - font.descender + font.leading).rounded(.up)

        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        // Undo do `TextBuffer` giữ (FR-CORE-004): undo của NSTextView đếm theo từng lần gõ và
        // chỉ biết cửa sổ hiện tại — nó không thể hoàn tác một thao tác chạm cả triệu dòng.
        textView.allowsUndo = false
        textView.font = font
        textView.backgroundColor = Tokens.Color.editorBackground
        textView.textColor = Tokens.Color.editorInk
        textView.insertionPointColor = Tokens.Color.orange
        textView.selectedTextAttributes = [.backgroundColor: Tokens.Color.selection]
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = self
        textView.textLayoutManager?.delegate = self
        (textView as? MultiCaretTextView)?.host = self

        // KHÔNG đụng vào `textView.layoutManager`: view này chạy TextKit 2, và chỉ cần ĐỌC
        // thuộc tính TextKit 1 ấy là AppKit lặng lẽ hạ nó xuống TextKit 1. Đã suýt dính khi
        // viết một đoạn chẩn đoán chỉ để in ra xem đang chạy bản nào.

        // Lớp phủ nằm DƯỚI text view, và text view không tự vẽ nền.
        //
        // Để lớp phủ ở trên thì nó tô đè lên chữ: vùng chọn phụ hiện ra thành một ô đặc che
        // mất chính chữ đang được chọn — thấy ngay trên ảnh chụp. Nền do canvas vẽ.
        overlay.rectForOffset = { [weak self] offset in self?.rect(forDocumentOffset: offset) }
        overlay.markedBands = { [weak self] rect in self?.markedLineBands(in: rect) ?? [] }
        overlay.daiEide = { [weak self] rect in self?._daiEide(in: rect) ?? [] }
        overlay.foldMarkers = { [weak self] in self?.foldMarkerOffsets ?? [] }
        canvas.addSubview(overlay)
        textView.drawsBackground = false
        canvas.addSubview(textView)
        scrollView.documentView = canvas
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Tokens.Color.editorBackground
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Khung chữ TỰ NỚI khi TextKit dựng thêm bố cục — đó là cách một dòng 50.000 ký tự
        // cuối cùng cũng cao đủ. Nhưng khung cuộn thì không tự biết, và nếu nó không nới theo
        // thì phần chữ ấy có tồn tại mà người dùng không cuộn tới được. Đã thấy đúng như vậy
        // trong đối chứng âm: khung chữ 5.517 pt nằm trong khung cuộn 60 pt.
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(textViewFrameChanged),
            name: NSView.frameDidChangeNotification, object: textView
        )

        // Đặt cấu hình ngắt dòng NGAY từ đầu. Không gọi thì `wrapMode` nói ".off" trong khi
        // `NSTextView` mặc định vẫn bám bề rộng view và ngắt dòng — trạng thái khai báo một
        // đằng, hành vi một nẻo, đúng loại lỗi không ai nhìn ra khi đọc code.
        applyWrapMode()

        // Hàng tiêu đề dính nằm TRÊN scroll view, trong cùng khung soạn thảo.
        csvHeader.translatesAutoresizingMaskIntoConstraints = false
        csvHeader.isHidden = true
        addSubview(csvHeader)
        csvHeaderHeight = csvHeader.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            csvHeader.topAnchor.constraint(equalTo: topAnchor),
            csvHeader.leadingAnchor.constraint(equalTo: leadingAnchor),
            csvHeader.trailingAnchor.constraint(equalTo: trailingAnchor),
            csvHeaderHeight,
        ])

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(viewportMoved),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
    }

    // MARK: - Nạp tài liệu

    /// Trỏ view vào một buffer khác mà chưa vẽ lại.
    ///
    /// Tách khỏi `repaginate` vì hai chuyện khác nhau: mở tài liệu MỚI thì phải đổi buffer,
    /// còn sắp xếp hay lọc thì vẫn là buffer cũ vừa bị sửa. Quên đổi buffer thì view nạp lại
    /// cửa sổ trên tài liệu đã đóng — và nó im lặng cho ra nội dung cũ.
    func attach(_ buffer: TextBuffer) {
        self.buffer = buffer
    }

    func load(_ buffer: TextBuffer, caretAt offset: Int = 0) {
        self.buffer = buffer
        repaginate(around: offset)
        setCaret(documentOffset: offset)
        reveal(documentOffset: offset)
    }

    /// Nạp lại cửa sổ quanh một offset và vẽ lại.
    ///
    /// Gọi sau MỌI thay đổi buffer không đến từ việc gõ (sắp xếp, lọc, đổi bảng mã…): cửa sổ
    /// cũ nói về một tài liệu đã khác.
    func repaginate(around offset: Int) {
        let started = ProcessInfo.processInfo.environment["GEDITOR_TRACE_WRAP"] != nil ? Date() : nil
        defer {
            if let started {
                NSLog("[wrap] nạp cửa sổ (%@): %.1f ms", wrapMode.displayName,
                      Date().timeIntervalSince(started) * 1000)
            }
        }
        textWindow = TextWindowing.window(around: offset, in: buffer, folds: activeFolds)

        isSyncing = true
        textView.string = textWindow.text
        // Đo lại TRƯỚC khi đặt khung: mọi phép tính bên dưới đều dựa vào số này.
        rowsPerLine = textWindow.rowsPerLine(columnsPerRow: columnsPerRow)
        applyHangingIndent()
        positionTextView()
        resizeCanvas()
        isSyncing = false

        // Chuỗi trong view vừa bị thay hẳn, nên mọi kết quả tô màu đang bay đều vô nghĩa.
        windowGeneration += 1
        requestHighlighting()
        applyColumnColors()
        applySearchHighlights()
        applyLogColors()
        applyUserLanguageColors()
        refreshCSVHeader()
    }

    /// Số học cuộn dọc — của LÕI, kiểm được bằng test (`VerticalGeometryTests`).
    private var geometry: VerticalGeometry {
        VerticalGeometry(
            lineCount: buffer.lineCount,
            lineHeight: Double(lineHeight),
            rowsPerLine: rowsPerLine,
            insetHeight: Double(2 * textView.textContainerInset.height),
            maximumHeight: Double(Self.maximumCanvasHeight)
        )
    }

    /// Khung cuộn phải LUÔN chứa nổi khung chữ.
    ///
    /// Đây là chỗ tự sửa cho phần ước lượng: `rowsPerLine` là số ước lượng THẤP (ngắt thật gãy
    /// ở biên từ), nên chiều cao suy ra có thể thiếu. Lấy `max` với đáy khung chữ — mà khung
    /// chữ thì tự nới theo bố cục THẬT — nên phần chữ không bao giờ bị cắt mất, dù thanh cuộn
    /// có hơi ngắn ở tài liệu lớn.
    /// Chặn vòng lặp: nới khung cuộn có thể làm khung chữ đổi cỡ (chế độ bám bề rộng), rồi
    /// khung chữ đổi cỡ lại gọi về đây.
    private var isResizingCanvas = false

    @objc private func textViewFrameChanged() {
        guard !isResizingCanvas else { return }
        overlay.frame = textView.frame
        resizeCanvas()
    }

    private func resizeCanvas() {
        isResizingCanvas = true
        defer { isResizingCanvas = false }
        let height = Swift.max(CGFloat(geometry.canvasHeight), textView.frame.maxY)
        let width = Swift.max(scrollView.contentSize.width, textView.frame.maxX)
        canvas.frame = NSRect(x: 0, y: 0, width: width, height: Swift.max(height, 1))
    }

    private func positionTextView() {
        let geometry = self.geometry
        let top = CGFloat(geometry.y(ofLine: textWindow.firstLine))

        let estimated = CGFloat(Double(textWindow.lineCount) * geometry.unscaledLineHeight)
            + 2 * textView.textContainerInset.height
        // Chiều cao THẬT của phần TextKit đã dựng xong. Chỉ ĐỌC, không ép dựng thêm: ép dựng cả
        // cửa sổ 2 MB đo được 437 ms.
        let laidOut = (textView.textLayoutManager?.usageBoundsForTextContainer.height ?? 0)
            + 2 * textView.textContainerInset.height
        let height = Swift.max(estimated, laidOut)

        let width: CGFloat
        switch wrapMode {
        case .off:
            // Không ngắt: rộng ít nhất bằng cửa sổ, rồi nới theo DÒNG DÀI NHẤT của cửa sổ.
            //
            // Hai lần sai ở đúng dòng này, và cả hai đều chỉ lộ ra khi chạy thật:
            //
            // 1. Bản đầu lấy `max(khung hiện tại, bề rộng bố cục)`. Lúc vừa nạp cửa sổ thì cả
            //    hai đều bằng 0 — khung chữ rộng 1 pt, mỗi dòng hiện đúng MỘT chữ cái.
            // 2. Bản sau hỏi `usageBoundsForTextContainer.width`. Với thùng chữ rộng vô hạn,
            //    hỏi bề rộng là buộc TextKit dựng bố cục cả cửa sổ để tìm dòng dài nhất: nạp
            //    cửa sổ trên file 100 MB tốn **490 ms** thay vì vài ms.
            //
            // Font đơn cách nên số ô × bề rộng một ký tự là ra đúng, và lõi đếm ô sẵn rồi.
            // Cộng dư vài ký tự. Đặt bề rộng ĐÚNG BẰNG dòng dài nhất thì làm tròn dấu phẩy
            // động đủ để đẩy hai ký tự cuối xuống hàng dưới — nghĩa là "tắt ngắt dòng" vẫn ngắt.
            // Thấy được vì bài kiểm caret: bấm mũi tên xuống dừng ở 49.998 thay vì sang dòng sau.
            width = Swift.max(scrollView.contentSize.width,
                              (CGFloat(textWindow.longestLineUTF16Length) + 4) * characterWidth
                                  + 2 * textView.textContainerInset.width)
            textView.textContainer?.size = NSSize(
                width: width - 2 * textView.textContainerInset.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        case .window:
            width = scrollView.contentSize.width
        case .column:
            width = Swift.min(scrollView.contentSize.width,
                              CGFloat(columnsPerRow) * characterWidth
                                  + 2 * textView.textContainerInset.width)
        }

        textView.frame = NSRect(x: 0, y: top, width: Swift.max(width, 1), height: height)
        if ProcessInfo.processInfo.environment["GEDITOR_TRACE_WRAP"] != nil {
            NSLog("[wrap] position(%@): dài nhất=%d ô · charW=%.2f · width=%.0f · thùng=%.0f",
                  wrapMode.displayName, textWindow.longestLineUTF16Length, characterWidth,
                  width, textView.textContainer?.size.width ?? -1)
        }
        overlay.frame = textView.frame
        overlay.needsDisplay = true
    }

    // MARK: - Gấp mã (FR-CORE code folding · FR-FMT-507)

    /// Đặt lại tập vùng đang gấp và vẽ lại.
    func setFolds(_ folds: [FoldRange], caretAt offset: Int) {
        activeFolds = folds.sorted { $0.hiddenBytes.lowerBound < $1.hiddenBytes.lowerBound }
        // Con nháy có thể đang đứng trong chỗ vừa bị giấu; đưa nó về chỗ còn nhìn thấy TRƯỚC
        // khi vẽ, nếu không nó biến mất và phím mũi tên tiếp theo đi từ một vị trí vô hình.
        var caret = offset
        for fold in activeFolds where fold.hiddenBytes.contains(caret) { caret = fold.caretHome }
        repaginate(around: caret)
        setCaret(documentOffset: caret)
        reveal(documentOffset: caret)
    }

    /// Vùng đang gấp có dòng đầu tại `line` không.
    func activeFold(headerLine line: Int) -> FoldRange? {
        activeFolds.first { $0.headerLine == line }
    }

    /// Khung của từng phù hiệu gấp trên màn hình — rỗng nghĩa là người dùng KHÔNG thấy dấu
    /// hiệu nào, dù chữ đang bị giấu.
    var foldMarkerRectsForSelfTest: [NSRect] {
        foldMarkerOffsets.compactMap { rect(forDocumentOffset: $0) }
    }

    /// Offset của dấu hiệu "chỗ này có chữ bị giấu", để lớp vẽ đặt phù hiệu.
    var foldMarkerOffsets: [Int] {
        activeFolds.filter { textWindow.contains(documentOffset: $0.caretHome) }.map(\.caretHome)
    }

    // MARK: - Ngắt dòng mềm (FR-CORE-015)

    /// Bề rộng đã dựng bố cục lần gần nhất — để biết cửa sổ có thật sự đổi cỡ hay không.
    private var lastLaidOutWidth: CGFloat = 0

    /// Đổi cỡ cửa sổ thì phải NGẮT LẠI.
    ///
    /// Thiếu hàm này là lỗ hổng đúng ngay giữa tính năng: chế độ "ngắt theo chiều rộng cửa sổ"
    /// mà không nghe cửa sổ đổi bề rộng thì nó chỉ đúng ở đúng cỡ lúc mở. Thấy được bằng mắt:
    /// kéo cho cửa sổ hẹp lại rồi vùng soạn thảo TRẮNG TRƠN, trong khi thanh trạng thái vẫn
    /// báo tài liệu có 981 ký tự — chữ còn nguyên trong buffer, chỉ là khung chữ giữ số đo cũ.
    ///
    /// Không nạp lại cửa sổ ở đây: nội dung không đổi, chỉ có hình học đổi. Nạp lại sẽ tốn
    /// 4,5 ms cho MỖI bước kéo chuột.
    override func layout() {
        super.layout()
        let width = scrollView.contentSize.width
        guard abs(width - lastLaidOutWidth) > 0.5 else { return }
        lastLaidOutWidth = width

        applyWrapMode()
        rowsPerLine = textWindow.rowsPerLine(columnsPerRow: columnsPerRow)
        applyHangingIndent()
        positionTextView()
        resizeCanvas()
    }

    private func applyWrapMode() {
        guard let container = textView.textContainer else { return }
        invisibleSettings.showsWrapMarker = wrapMode.isOn

        // KHÔNG dùng autoresizing cho khung chữ ở bất kỳ chế độ nào.
        //
        // Đây là con đường ẩn đã làm hỏng chế độ "theo cửa sổ": khung chữ để `.width` thì mỗi
        // lần `resizeCanvas` thu khung cuộn lại, AppKit lặng lẽ trừ đúng chừng ấy vào bề rộng
        // khung chữ. Kéo cửa sổ 1100 → 900 thì khung cuộn giảm 200 và khung chữ tụt từ 900
        // xuống 700 — chữ chỉ chiếm hai phần ba cửa sổ, ngắt sai chỗ, và không có dòng code nào
        // nói ra điều đó. Frame khung chữ do `positionTextView` đặt, và chỉ một mình nó.
        textView.autoresizingMask = []

        let unlimited = CGFloat.greatestFiniteMagnitude
        switch wrapMode {
        case .off:
            // Thùng chữ KHÔNG rộng vô hạn, mà rộng đúng bằng dòng dài nhất của cửa sổ.
            //
            // Đây là chỗ đắt nhất đã tìm ra, và nó phản trực giác: "rộng vô hạn" nghe như bảo
            // TextKit khỏi phải nghĩ, nhưng thật ra là bắt nó dựng bố cục CẢ cửa sổ mới biết
            // mình rộng bao nhiêu. Đo trên file 100 MB, bản release: nạp cửa sổ tốn **480 ms**
            // ở chế độ tắt ngắt dòng, so với 11–21 ms ở chế độ ngắt theo cửa sổ. Cho sẵn một
            // con số hữu hạn thì nó không phải đi tìm.
            //
            // Bề rộng thật đặt ở `positionTextView`, vì lúc này cửa sổ nội dung có thể còn là
            // cửa sổ CŨ (hàm này được gọi trước `repaginate`).
            container.widthTracksTextView = false
            textView.isHorizontallyResizable = false
            scrollView.hasHorizontalScroller = true

        case .window:
            container.widthTracksTextView = true
            container.size = NSSize(width: textContainerWidth, height: unlimited)
            textView.isHorizontallyResizable = false
            scrollView.hasHorizontalScroller = false

        case .column(let column):
            // Ngắt tại cột cố định: bề rộng KHÔNG bám cửa sổ nữa, vì cả điểm của chế độ này là
            // thấy đúng chỗ dòng sẽ gãy ở nơi khác — cột 72 của commit, cột 80 của thư RFC.
            container.widthTracksTextView = false
            container.size = NSSize(width: CGFloat(Swift.max(1, column)) * characterWidth, height: unlimited)
            textView.isHorizontallyResizable = false
            // Cửa sổ hẹp hơn cột đã chọn thì vẫn phải với tới được cột ấy.
            scrollView.hasHorizontalScroller = true
        }
    }

    /// Giữ thụt lề cho phần bị ngắt xuống hàng dưới — SRS FR-CORE-015: "giữ indent phần wrap".
    ///
    /// Không có nó thì một dòng JSON hay log thụt sâu bị ngắt sẽ đổ phần đuôi về sát mép trái,
    /// và cấu trúc thụt lề — thứ duy nhất giúp đọc được file như vậy — biến mất.
    ///
    /// Chỉ đụng tới những dòng ĐỦ DÀI để có thể bị ngắt. Đó không phải mẹo tối ưu mà là đúng
    /// định nghĩa: thụt lề treo chỉ có nghĩa với dòng bị ngắt. Nhờ vậy một cửa sổ 2 MB mã nguồn
    /// thường không phải đặt thuộc tính nào cả, thay vì phải đặt cho mấy vạn dòng.
    private func applyHangingIndent() {
        guard wrapMode.isOn,
              let storage = (textView.textContentStorage)?.textStorage
        else { return }

        let columns = columnsPerRow
        guard columns > 0 else { return }

        // MỘT lượt quét UTF-16, không cắt chuỗi.
        //
        // Bản đầu dùng `text.split(separator: "\n")` cho gọn. Đo trên cửa sổ 2 MB: **29,5 ms**,
        // trong khi cả lần nạp cửa sổ chỉ có ngân sách 4,5 ms — cuộn trong chế độ ngắt dòng sẽ
        // chậm gấp bảy. Cùng việc ấy quét thẳng utf16 tốn 4,9 ms, vì không phải cấp phát mấy
        // vạn chuỗi con chỉ để rồi bỏ đi gần hết.
        let text = textWindow.text
        var styles: [Int: NSParagraphStyle] = [:]     // dùng lại theo mức thụt lề
        var offset = 0
        var lineStart = 0
        var indentWidth = 0
        var stillInIndent = true

        storage.beginEditing()
        defer { storage.endEditing() }

        func finishLine(end: Int) {
            let length = end - lineStart
            guard length > columns, indentWidth > 0 else { return }
            let style = styles[indentWidth] ?? {
                let made = NSMutableParagraphStyle()
                // `headIndent` chỉ áp cho các hàng SAU hàng đầu — đúng nghĩa "thụt lề treo".
                made.headIndent = CGFloat(indentWidth) * characterWidth
                styles[indentWidth] = made
                return made
            }()
            let range = NSRange(location: lineStart, length: length)
            guard NSMaxRange(range) <= storage.length else { return }
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }

        for unit in text.utf16 {
            if unit == 0x0A {                       // "\n"
                finishLine(end: offset)
                lineStart = offset + 1
                indentWidth = 0
                stillInIndent = true
            } else if stillInIndent {
                switch unit {
                case 0x20: indentWidth += 1         // dấu cách
                case 0x09: indentWidth += tabWidth   // TAB
                default: stillInIndent = false
                }
            }
            offset += 1
        }
        finishLine(end: offset)                     // dòng cuối có thể không kết thúc bằng "\n"
    }

    /// Khung màn hình của một offset tài liệu — dùng để vẽ caret phụ.
    private func rect(forDocumentOffset offset: Int) -> NSRect? {
        guard textWindow.contains(documentOffset: offset),
              let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return nil }

        let utf16 = textWindow.utf16Offset(forDocumentOffset: offset)
        guard let location = contentManager.location(contentManager.documentRange.location, offsetBy: utf16),
              let fragment = layoutManager.textLayoutFragment(for: location)
        else { return nil }

        for lineFragment in fragment.textLineFragments {
            let start = fragment.rangeInElement.location
            guard let startOffset = contentManager.offset(from: contentManager.documentRange.location, to: start) as Int?
            else { continue }
            let localIndex = utf16 - startOffset
            guard lineFragment.characterRange.contains(localIndex)
                    || localIndex == lineFragment.characterRange.upperBound else { continue }
            let point = lineFragment.locationForCharacter(at: localIndex)
            let origin = fragment.layoutFragmentFrame.origin
            // CỘNG textContainerInset: khung fragment tính trong hệ toạ độ của text container,
            // còn lớp phủ nằm trên hệ toạ độ của view. Thiếu nó thì mọi caret phụ và vùng chọn
            // phụ lệch đúng bằng phần lề — nhìn thấy ngay là tô trượt lên trên dòng chữ.
            let inset = textView.textContainerInset
            return NSRect(
                x: origin.x + lineFragment.typographicBounds.origin.x + point.x + inset.width,
                y: origin.y + lineFragment.typographicBounds.origin.y + inset.height,
                width: 2, height: lineFragment.typographicBounds.height
            )
        }
        return nil
    }

    /// Các dải nền của dòng đã đánh dấu, giới hạn trong `rect` cần vẽ (FR-SRCH-107).
    ///
    /// Hỏi TextKit từng đoạn bố cục thay vì tự nhân số dòng với chiều cao dòng. Bật ngắt dòng
    /// mềm thì một dòng tài liệu chiếm nhiều hàng, và tô sai một hàng nghĩa là tô nhầm dòng —
    /// với thao tác "xóa mọi dòng đã đánh dấu" thì tô nhầm là mất dữ liệu.
    ///
    /// Chỉ duyệt các đoạn CHẠM vùng cần vẽ, nên chi phí theo màn hình chứ không theo tài liệu:
    /// đánh dấu một triệu dòng vẫn chỉ vẽ vài chục dải.
    /// Dải lề cho dấu EIDE — cùng phép duyệt đoạn bố cục với `markedLineBands`.
    ///
    /// Phải hỏi TextKit chứ không nhân số dòng với chiều cao dòng, vì đúng lý do đã ghi ở
    /// `markedLineBands`: ngắt dòng mềm làm một dòng tài liệu chiếm nhiều hàng, và vạch lệch một
    /// hàng là vạch chỉ vào dòng khác. Ở đây hậu quả nhẹ hơn mất dữ liệu nhưng nặng về nghĩa:
    /// một vạch "có fact" chỉ nhầm sang dòng bên cạnh là một lời khẳng định sai về tri thức.
    private func _daiEide(in rect: NSRect) -> [(rect: NSRect, viPham: Bool)] {
        guard !dauEide.isEmpty,
              let manager = textView.textLayoutManager,
              let content = manager.textContentManager
        else { return [] }

        let inset = textView.textContainerInset
        let top = Swift.max(0, rect.minY - inset.height)
        let from = manager.textLayoutFragment(for: CGPoint(x: 0, y: top))?.rangeInElement.location

        var ra: [(rect: NSRect, viPham: Bool)] = []
        manager.enumerateTextLayoutFragments(
            from: from ?? content.documentRange.location, options: [.ensuresLayout]
        ) { fragment in
            let frame = fragment.layoutFragmentFrame
            guard frame.minY + inset.height <= rect.maxY else { return false }
            let utf16 = content.offset(
                from: content.documentRange.location, to: fragment.rangeInElement.location)
            let line = buffer.lineNumber(atOffset: documentOffset(forUTF16: utf16))
            if let d = dauEide[line] {
                let vp: Bool
                if case .viPham = d { vp = true } else { vp = false }
                ra.append((NSRect(x: 0, y: frame.minY + inset.height,
                                  width: Self.RONG_VACH_EIDE, height: frame.height), vp))
            }
            return true
        }
        return ra
    }

    /// Bề rộng vạch lề EIDE. 4 pt: thấy được khi quét dọc, không ăn vào chỗ của chữ.
    static let RONG_VACH_EIDE: CGFloat = 4

    /// Toàn văn tài liệu — để chấm chú thích fact lên lề.
    ///
    /// Đọc từ `buffer` chứ không từ `textView.string`: `textView` chỉ giữ CỬA SỔ đang hiện
    /// (xem `TextWindowing`), nên chấm theo nó sẽ bỏ sót mọi dòng ngoài màn hình — và tệp dài
    /// thì phần ngoài màn hình là gần hết tệp.
    var noiDungDeChamDeTest: String { buffer.text }

    /// Dấu EIDE đang hiện, theo dòng — cho test.
    func dauEideDeTest() -> [Int: DauEide] { dauEide }

    private func markedLineBands(in rect: NSRect) -> [(rect: NSRect, color: Int)] {
        guard !lineMarks.isEmpty,
              let manager = textView.textLayoutManager,
              let content = manager.textContentManager
        else { return [] }

        let inset = textView.textContainerInset
        let top = Swift.max(0, rect.minY - inset.height)
        let from = manager.textLayoutFragment(for: CGPoint(x: 0, y: top))?.rangeInElement.location

        var bands: [(rect: NSRect, color: Int)] = []
        manager.enumerateTextLayoutFragments(
            from: from ?? content.documentRange.location, options: [.ensuresLayout]
        ) { fragment in
            let frame = fragment.layoutFragmentFrame
            guard frame.minY + inset.height <= rect.maxY else { return false }

            let utf16 = content.offset(
                from: content.documentRange.location, to: fragment.rangeInElement.location
            )
            let line = buffer.lineNumber(
                atOffset: documentOffset(forUTF16: utf16)
            )
            if let color = lineMarks.displayColor(at: line) {
                bands.append((
                    NSRect(x: 0, y: frame.minY + inset.height,
                           width: bounds.width, height: frame.height),
                    color
                ))
            }
            return true
        }
        return bands
    }

    // MARK: - Cuộn

    @objc private func viewportMoved() {
        guard !isSyncing, buffer.count > 0 else { return }

        let visible = scrollView.contentView.bounds
        let offset = buffer.offset(ofLineStart: geometry.line(atY: Double(visible.minY)))

        // Chỉ nạp lại khi ĐÃ RA NGOÀI cửa sổ, không nạp mỗi lần cuộn một chút: nạp lại tốn
        // ~4,5 ms và làm mất vùng chọn, nên nó phải là chuyện hiếm.
        guard !textWindow.contains(documentOffset: offset) else {
            // Cuộn TRONG cửa sổ: không nạp lại nội dung, nhưng phải tô tiếp phần vừa lộ ra.
            applyVisibleColors()
            applyColumnColors()
            applySearchHighlights()
            applyLogColors()
            applyUserLanguageColors()
            refreshCSVHeader()
            if let colored = coloredRange {
                let visible = visibleDocumentRange()
                // Ra ngoài vùng đã phân tích thì xin phân tích tiếp — hoãn một nhịp để cuộn
                // liên tục không đẻ ra một loạt yêu cầu.
                if visible.lowerBound < colored.lowerBound || visible.upperBound > colored.upperBound {
                    scheduleHighlighting()
                }
            }
            return
        }
        let caret = selectedDocumentRange
        repaginate(around: offset)
        setSelectedDocumentRange(caret)
    }

    /// Cuộn để `offset` nằm trong tầm nhìn, nạp lại cửa sổ nếu cần.
    func reveal(documentOffset offset: Int) {
        if !textWindow.contains(documentOffset: offset) { repaginate(around: offset) }

        let line = buffer.lineNumber(atOffset: Swift.min(offset, Swift.max(buffer.count - 1, 0)))
        let y = CGFloat(geometry.y(ofLine: line))
        let visible = scrollView.contentView.bounds
        // Chỉ cuộn khi thật sự nằm ngoài: cuộn lại mỗi lần gõ làm màn hình nhảy.
        guard y < visible.minY || y > visible.maxY - lineHeight else { return }
        let target = Swift.max(0, y - visible.height / 3)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: target))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - Con trỏ và vùng chọn, tính bằng OFFSET BYTE của tài liệu

    /// Chuỗi thụt lề cho dòng mới, hoặc `nil` khi không nên thụt (FR-CORE-011).
    ///
    /// Trả `nil` khi đang chọn NHIỀU caret hoặc một khối cột: ở đó "dòng đang đứng" không có
    /// nghĩa duy nhất, và chèn thụt lề khác nhau vào mỗi caret là đoán thay người dùng.
    func indentForNewLine() -> String? {
        guard !selection.isMultiple, !selection.hasSelection else { return nil }
        let caret = selectedDocumentRange.lowerBound
        guard buffer.count > 0 else { return nil }
        let line = buffer.lineNumber(atOffset: caret)
        let start = buffer.offset(ofLineStart: line)
        // Chỉ phần dòng nằm TRƯỚC con nháy. Xuống dòng ở giữa `if x { y }` thì phần sau con
        // nháy thuộc về dòng mới, và tính cả nó vào sẽ hỏi sai câu hỏi "dòng này có mở khối".
        guard caret >= start else { return nil }
        let head = String(decoding: buffer.bytes(in: start ..< caret), as: UTF8.self)
        return SmartIndent.indent(
            afterLine: head, language: syntaxLanguage, tabWidth: tabWidth
        )
    }

    /// Vùng chọn theo offset TÀI LIỆU, luôn nằm trong buffer hiện tại.
    ///
    /// **Kẹp ở đây, không kẹp ở chỗ gọi.** Vùng chọn sống trong `NSTextView`, còn nội dung sống
    /// trong buffer, và hai thứ ấy đổi ở hai nhịp khác nhau: ngay sau một lần sửa làm tài liệu
    /// ngắn đi, view vẫn giữ vùng chọn của tài liệu CŨ cho tới khi được đồng bộ. Mọi hàm đọc
    /// buffer đều có `precondition`, nên một vùng chọn lạc hậu không làm hiện sai một con số —
    /// nó làm app SẬP.
    ///
    /// Bộ chạy dài `--soak` tìm ra hai lần sập kiểu này (NFR-REL-03). Kẹp ở từng chỗ gọi thì
    /// phải nhớ kẹp ở mọi chỗ, mãi mãi; kẹp ở đây thì chỗ gọi không cần biết chuyện ấy tồn tại.
    /// Offset TÀI LIỆU từ một offset UTF-16 của view — **luôn nằm trong buffer hiện tại**.
    ///
    /// Mọi chỗ trong lớp này phải đi qua đây, không gọi thẳng `textWindow.documentOffset(…)`.
    ///
    /// **Vì sao.** Cửa sổ nội dung và buffer đổi ở hai nhịp khác nhau: ngay sau một lần sửa làm
    /// tài liệu ngắn đi, `NSTextLayoutManager` vẫn còn giữ bố cục của nội dung CŨ và hỏi ta vị
    /// trí của những đoạn không còn tồn tại. Mọi hàm đọc buffer đều có `precondition`, nên một
    /// offset lạc hậu không làm hiện sai một con số — nó làm app SẬP.
    ///
    /// Tệp này vốn đã ghi đúng luật ấy ở `selectedDocumentRange` ("kẹp ở đây, không kẹp ở chỗ
    /// gọi") nhưng chỉ kẹp ở MỘT chỗ, trong khi có tám chỗ quy đổi. Bộ chạy dài `--soak` tìm ra
    /// chỗ thứ hai ở `markedLineBands` (hạt giống 1, bước 3600) — đúng như lời cảnh báo đã
    /// viết sẵn ngay trên đầu hàm ấy.
    private func documentOffset(forUTF16 utf16: Int) -> Int {
        Swift.min(textWindow.documentOffset(forUTF16Offset: utf16), buffer.count)
    }

    var selectedDocumentRange: Range<Int> {
        let selected = textView.selectedRange()
        let lower = documentOffset(forUTF16: selected.location)
        let upper = documentOffset(forUTF16: selected.location + selected.length)
        return lower ..< Swift.max(lower, upper)
    }

    func setCaret(documentOffset offset: Int) {
        setSelectedDocumentRange(offset ..< offset)
    }

    /// Đặt lại toàn bộ tập caret và vẽ lại.
    func setSelection(_ newValue: MultiSelection) {
        selection = newValue
        setSelectedDocumentRange(newValue.primary)
        overlay.selection = newValue
        overlay.needsDisplay = true
    }

    func setSelectedDocumentRange(_ range: Range<Int>) {
        // Đích ngoài cửa sổ thì NẠP LẠI, đừng im lặng bỏ qua.
        //
        // Bản đầu `guard ... else { return }` và nó hỏng đúng ở việc quan trọng nhất: "Đi tới
        // dòng 5.000.000" trên file 500 MB đặt caret không thành, rồi thanh trạng thái đọc ra
        // vị trí của cửa sổ mới và báo dòng 5.014.364. Sai 14 nghìn dòng, im lặng.
        //
        // Sửa ở ĐÂY chứ không ở chỗ gọi: bắt mọi chỗ gọi nhớ "cuộn trước, chọn sau" là một cái
        // bẫy, và nó đã sập một lần.
        if !textWindow.contains(documentOffset: range.lowerBound) {
            repaginate(around: range.lowerBound)
        }
        guard textWindow.contains(documentOffset: range.lowerBound) else { return }
        let location = textWindow.utf16Offset(forDocumentOffset: range.lowerBound)
        let end = textWindow.utf16Offset(forDocumentOffset: range.upperBound)
        textView.setSelectedRange(NSRange(location: location, length: Swift.max(0, end - location)))
    }

    /// Bắt đầu chọn khối chữ nhật từ một điểm, chạy vòng kéo tới khi thả chuột.
    ///
    /// Tự chạy vòng sự kiện thay vì dựa vào `mouseDragged`: `NSTextView` đã có vòng kéo riêng
    /// của nó cho việc chọn thường, và hai vòng cùng chạy thì tranh nhau vùng chọn.
    func beginColumnSelection(at point: NSPoint) {
        let anchor = columnPosition(atViewPoint: point)
        var current = anchor
        applyColumnSelection(from: anchor, to: current)

        while let event = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if event.type == .leftMouseUp { break }
            let dragged = textView.convert(event.locationInWindow, from: nil)
            let position = columnPosition(atViewPoint: dragged)
            guard position != current else { continue }
            current = position
            applyColumnSelection(from: anchor, to: current)
        }
    }

    /// Tệp đang mở có phải loại mà tự đóng thẻ CÓ NGHĨA không (FR-FMT-505).
    ///
    /// Chỉ XML và HTML. Trong mọi ngôn ngữ khác, `>` là toán tử so sánh hoặc mũi tên, và tự
    /// chèn `</…>` sau `a > b` là sửa mã người dùng thành thứ không biên dịch nổi.
    var autoClosesTags: Bool {
        syntaxLanguage == .xml || syntaxLanguage == .html
    }

    /// Neo của khối đang chọn BẰNG BÀN PHÍM — `nil` khi chưa bắt đầu khối nào.
    ///
    /// Chuột có sự kiện "nhả nút" để biết khối đã xong; bàn phím thì không, nên phải nhớ neo
    /// giữa các lần nhấn. Mọi thao tác khác (gõ chữ, bấm chuột, Escape) xoá neo — nếu không
    /// thì lần nhấn Option+Cmd+mũi tên sau đó sẽ kéo khối từ một chỗ người dùng đã rời đi từ
    /// lâu, và họ không có cách nào biết cái neo ấy còn nằm đâu.
    private var columnKeyboardAnchor: (line: Int, column: Int)?

    /// GÓC ĐANG KÉO của khối bàn phím — góc đối diện với neo.
    ///
    /// Phải nhớ riêng, không đọc lại từ con nháy: sau mỗi lượt chọn khối, con nháy đứng ở một
    /// góc của khối, nên lần nhấn sau tính từ đó sẽ ra một khối khác hẳn. Bài kiểm bắt được
    /// đúng chuyện này — ba dòng được chọn nhưng cả ba đều RỖNG, vì mỗi lượt lại đo từ đầu.
    private var columnKeyboardCurrent: (line: Int, column: Int)?

    /// Hướng nới khối chọn bằng bàn phím.
    enum ColumnKeyDirection { case left, right, up, down }

    /// Option+Cmd+mũi tên — chọn khối chữ nhật KHÔNG cần chuột (FR-CORE-002).
    ///
    /// Vế bàn phím của đặc tả, và nó không thừa: chọn một khối 40 dòng bằng chuột nghĩa là kéo
    /// qua một vùng cuộn, còn bàn phím thì giữ được độ chính xác từng cột. Với người dùng chỉ
    /// dùng bàn phím (NFR-USE-03) thì đây là đường DUY NHẤT tới Column Editor.
    func extendColumnSelection(_ direction: ColumnKeyDirection) {
        let caret = selectedDocumentRange.lowerBound
        let line = Swift.min(buffer.lineNumber(atOffset: caret), Swift.max(buffer.lineCount - 1, 0))
        let column = ColumnSelection.column(ofOffset: caret, in: buffer, tabWidth: tabWidth)

        let anchor = columnKeyboardAnchor ?? (line, column)
        columnKeyboardAnchor = anchor

        var end = columnKeyboardCurrent ?? (line: line, column: column)
        switch direction {
        case .left: end.column = Swift.max(0, end.column - 1)
        case .right: end.column += 1
        case .up: end.line = Swift.max(0, end.line - 1)
        case .down: end.line = Swift.min(buffer.lineCount - 1, end.line + 1)
        }
        columnKeyboardCurrent = end
        applyColumnSelection(from: anchor, to: end)

        // Con nháy đi theo GÓC ĐANG KÉO, không đứng lại ở neo: lần nhấn tiếp theo tính từ đây,
        // và nếu nó đứng yên thì khối không bao giờ rộng quá một cột.
        //
        // `selection.primary` chính là góc ấy — `ColumnSelection.selection` đã đặt caret chính
        // vào dòng cuối của khối. Đọc lại từ đó thay vì tự tính offset lần nữa: hai phép tính
        // song song cho cùng một thứ là hai cơ hội lệch nhau.
        if let primary = selection.ranges.last {
            reveal(documentOffset: primary.upperBound)
        }
    }

    /// Bỏ neo khối bàn phím — gọi khi người dùng làm bất kỳ việc gì khác.
    func endColumnKeyboardSelection() {
        columnKeyboardAnchor = nil
        columnKeyboardCurrent = nil
    }

    var columnKeyboardAnchorForSelfTest: (line: Int, column: Int)? { columnKeyboardAnchor }

    private func applyColumnSelection(from start: (line: Int, column: Int), to end: (line: Int, column: Int)) {
        setSelection(ColumnSelection.selection(
            in: buffer, from: start, to: end, tabWidth: tabWidth))
    }

    /// (dòng, cột) của một điểm trên view.
    private func columnPosition(atViewPoint point: NSPoint) -> (line: Int, column: Int) {
        let inText = convert(point, to: textView)
        let utf16 = textView.characterIndexForInsertion(at: inText)
        let offset = documentOffset(forUTF16: utf16)
        let line = Swift.min(buffer.lineNumber(atOffset: offset), Swift.max(buffer.lineCount - 1, 0))
        return (line, ColumnSelection.column(ofOffset: offset, in: buffer, tabWidth: tabWidth))
    }

    /// Thêm một caret tại điểm vừa Cmd+Click.
    func addCaret(atViewPoint point: NSPoint) {
        let utf16 = textView.characterIndexForInsertion(at: convert(point, to: textView))
        let offset = documentOffset(forUTF16: utf16)
        var updated = selection
        updated.add(offset ..< offset)
        setSelection(updated)
    }

    /// Thu về một caret (Esc).
    func collapseSelection() {
        var updated = selection
        updated.collapseToPrimary()
        setSelection(updated)
    }

    func applyMultiEdit(_ kind: MultiEditKind) {
        onMultiEdit?(selection, kind)
    }

    /// Số đo hình học cho bài tự kiểm — xem `SelfTest`.
    ///
    /// `usageBoundsForTextContainer` là chiều cao TextKit thật sự cần cho phần đã dựng bố cục.
    /// Khung chữ thấp hơn số ấy nghĩa là chữ bị cắt mất — thứ không đọc code nào ra được.
    var geometryProbeForSelfTest: (textViewHeight: Double, laidOutHeight: Double, canvasBottom: Double) {
        (
            Double(textView.frame.height),
            Double(textView.textLayoutManager?.usageBoundsForTextContainer.height ?? 0)
                + Double(2 * textView.textContainerInset.height),
            Double(canvas.frame.height)
        )
    }

    /// Bề rộng thùng chữ hiện tại — bài tự kiểm dùng để phân biệt ba chế độ.
    var textContainerWidthForSelfTest: Double {
        Double(textView.textContainer?.size.width ?? 0)
    }

    var tracksViewWidthForSelfTest: Bool {
        textView.textContainer?.widthTracksTextView ?? false
    }

    var textViewWidthForSelfTest: Double { Double(textView.frame.width) }
    var csvHeaderVisibleForSelfTest: Bool { !csvHeader.isHidden && csvHeaderHeight.constant > 0 }
    var csvHeaderTextForSelfTest: String { csvHeader.headerTextForSelfTest }
    var csvHeaderColumnsForSelfTest: Int { csvHeader.columnCountForSelfTest }
    func csvHeaderColorForSelfTest(_ index: Int) -> NSColor? {
        csvHeader.columnColorForSelfTest(index)
    }
    func scrollToDocumentOffsetForSelfTest(_ offset: Int) {
        reveal(documentOffset: offset)
        viewportMoved()
        refreshCSVHeader()
    }

    /// Màu chữ THẬT SỰ đang nằm trên `NSTextStorage` tại một offset TÀI LIỆU.
    ///
    /// Đọc từ kho chữ chứ không từ danh sách span: danh sách đúng mà đặt sai chỗ thì bài kiểm
    /// vẫn xanh, còn màn hình vẫn sai.
    /// Vị trí cuộn hiện tại — để bài tự kiểm phân biệt "đã cuộn" với "chưa cuộn".
    var scrollOffsetForSelfTest: Double { Double(scrollView.contentView.bounds.minY) }
    /// Chiều cao khung nhìn — bài kiểm cần biết cửa sổ có được bố cục thật chưa.
    var viewportHeightForSelfTest: Double { Double(scrollView.contentView.bounds.height) }

    func syntaxColorForSelfTest(atDocumentOffset offset: Int) -> NSColor? {
        guard let storage = textView.textContentStorage?.textStorage,
              textWindow.contains(documentOffset: offset)
        else { return nil }
        let utf16 = textWindow.utf16Offset(forDocumentOffset: offset)
        guard utf16 < storage.length else { return nil }
        return storage.attribute(.foregroundColor, at: utf16, effectiveRange: nil) as? NSColor
    }

    /// Chờ luồng nền tô xong. Trả `false` nếu quá hạn.
    func waitForHighlightingForSelfTest(timeout: TimeInterval = 5) -> Bool {
        guard asyncHighlighter != nil else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Quay vòng sự kiện: kết quả tô màu về trên hàng đợi CHÍNH, nên ngủ suông ở đây
            // là khoá cứng — chính cái bẫy đã gặp ở test cầu nối CLI.
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            if hasSyntaxColorsForSelfTest { return true }
        }
        return false
    }

    var hasSyntaxColorsForSelfTest: Bool {
        guard let storage = textView.textContentStorage?.textStorage, storage.length > 0 else {
            return false
        }
        var found = false
        storage.enumerateAttribute(
            .foregroundColor, in: NSRange(location: 0, length: storage.length)
        ) { value, _, stop in
            if let color = value as? NSColor, color != Tokens.Color.editorInk {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
    var visibleTextForSelfTest: String { textView.string }
    var scrollOriginForSelfTest: Double { Double(scrollView.contentView.bounds.origin.y) }
    func scrollToForSelfTest(_ y: Double) {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: CGFloat(y)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Các dải nền đánh dấu đang THẬT SỰ được vẽ trong vùng nhìn thấy (FR-SRCH-107).
    ///
    /// Trả về (số dòng tài liệu, chỉ số màu) chứ không trả toạ độ: bài kiểm quan tâm "tô đúng
    /// dòng nào, màu nào", còn toạ độ pixel thì đổi theo cỡ cửa sổ.
    func markedBandsForSelfTest() -> [(line: Int, color: Int)] {
        let visible = NSRect(x: 0, y: 0, width: bounds.width, height: 100_000)
        guard let manager = textView.textLayoutManager,
              let content = manager.textContentManager
        else { return [] }
        return markedLineBands(in: visible).map { band in
            let y = band.rect.minY - textView.textContainerInset.height
            let utf16 = manager.textLayoutFragment(for: CGPoint(x: 0, y: y))
                .map { content.offset(from: content.documentRange.location, to: $0.rangeInElement.location) } ?? 0
            return (buffer.lineNumber(atOffset: documentOffset(forUTF16: utf16)), band.color)
        }
    }
    var characterWidthForSelfTest: Double { Double(characterWidth) }
    var editorWidthForSelfTest: Double { Double(scrollView.contentSize.width) }

    /// ÉP dựng bố cục toàn bộ cửa sổ rồi trả chiều cao thật.
    ///
    /// Chỉ dùng trong bài tự kiểm, và chỉ với tài liệu nhỏ: ép dựng 2 MB đo được 437 ms. Cần
    /// nó vì `usageBoundsForTextContainer` chỉ nói về phần ĐÃ dựng, mà TextKit thì ngừng dựng
    /// khi hết khung chữ — so khung chữ với số ấy là so vòng tròn, khung càng thấp thì số càng
    /// nhỏ và bài kiểm luôn xanh.
    func fullyLaidOutHeightForSelfTest() -> Double {
        guard let manager = textView.textLayoutManager else { return 0 }
        manager.ensureLayout(for: manager.documentRange)
        return Double(manager.usageBoundsForTextContainer.height)
            + Double(2 * textView.textContainerInset.height)
    }


    /// Xin tô màu cho cửa sổ đang hiện.
    ///
    /// Tô CẢ cửa sổ chứ không riêng phần nhìn thấy: người dùng cuộn trong một cửa sổ 2 MB rất
    /// nhiều lần, còn nạp cửa sổ mới thì hiếm. Tô theo tầm nhìn nghĩa là mỗi cú cuộn một lần
    /// phân tích — mà một lần tốn tới 190 ms.
    /// Xin tô lại SAU khi người dùng ngừng gõ một nhịp.
    ///
    /// Không tô lại ngay mỗi phím: một lần phân tích tốn tới 190 ms, còn người gõ nhanh ra
    /// mười phím một giây. Hoãn 150 ms nghĩa là trong lúc gõ liên tục thì không phân tích lần
    /// nào, và vừa dừng tay là có màu.
    ///
    /// Màu CŨ vẫn nằm nguyên trong lúc chờ. Xoá nó đi sẽ làm chữ nhấp nháy đen mỗi lần gõ —
    /// màu hơi lệch một nhịp thì dễ chịu hơn nhiều so với màn hình chớp.
    private func scheduleHighlighting() {
        guard asyncHighlighter != nil else { return }
        highlightDebounce?.invalidate()
        highlightDebounce = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) {
            [weak self] _ in self?.requestHighlighting()
        }
    }

    /// Xin tô cho phần ĐANG NHÌN THẤY cộng lề, không phải cho cả cửa sổ.
    ///
    /// Bản đầu xin cho cả cửa sổ 2 MB với lý lẽ nghe hợp lý: cuộn trong cửa sổ là chuyện
    /// thường, nạp cửa sổ mới thì hiếm. Đo ra 2.030 ms và 687.500 đoạn cho một cửa sổ mã C.
    ///
    /// Chỗ tôi đọc sai số liệu của CHÍNH MÌNH: PoC-D ghi truy vấn tô màu tốn 0,26 ms, nhưng
    /// đó là truy vấn trên MỘT MÀN HÌNH 8 KB. Bảng số ấy không hề nói nó rẻ ở cỡ 2 MB — tôi
    /// tự suy ra và không đo lại.
    private func requestHighlighting() {
        guard let asyncHighlighter, !textWindow.isEmpty else { return }
        let generation = windowGeneration
        let range = colorTargetRange()
        guard !range.isEmpty else { return }

        let trace = ProcessInfo.processInfo.environment["GEDITOR_TRACE_HL"] != nil
        let asked = Date()
        asyncHighlighter.request(buffer: buffer, range: range) { [weak self] result in
            guard let self, self.windowGeneration == generation else { return }
            let arrived = Date()
            self.applyHighlighting(result.spans)
            if trace {
                NSLog("[hl] vùng %d KB · %d đoạn · nền %.0f ms · đặt màu %.0f ms",
                      range.count / 1024, result.spans.count,
                      arrived.timeIntervalSince(asked) * 1000,
                      Date().timeIntervalSince(arrived) * 1000)
            }
        }
        if trace {
            NSLog("[hl] chụp yêu cầu: %.0f ms · vùng %d KB",
                  Date().timeIntervalSince(asked) * 1000, range.count / 1024)
        }
    }

    /// Tô mỗi cột một màu (FR-CSV-402).
    ///
    /// Chạy THẲNG trên luồng chính, khác hẳn tô màu cú pháp. Lý do là số đo: phân tích CSV là
    /// một lượt quét byte, không dựng cây — bài tự kiểm đo trên cửa sổ 2 MB và chặn ở 50 ms.
    /// Tô cú pháp tốn 110–190 ms nên bắt buộc phải ra luồng nền; ở đây thì thêm một tầng
    /// luồng chỉ là thêm chỗ để sai.
    ///
    /// Màu theo CHỈ SỐ CỘT LOGIC sau khi parse RFC 4180, không theo vị trí ký tự — nên field
    /// bọc ngoặc chứa dấu phẩy không làm lệch màu.
    /// Ngôn ngữ do người dùng tự định nghĩa, khi file không thuộc 20 ngôn ngữ dựng sẵn
    /// (FR-FMT-502).
    var userLanguage: UserDefinedLanguage? {
        didSet {
            guard userLanguage != oldValue else { return }
            clearHighlighting()
            applyUserLanguageColors()
        }
    }

    /// Tô theo bảng từ khoá của UDL, cho phần đang nhìn thấy.
    ///
    /// Cùng luật với mọi phép tô khác: chỉ chạm phần NHÌN THẤY. UDL là bộ quét từ vựng chạy
    /// trên `String`, nên quét cả cửa sổ 2 MB ở mỗi nhịp cuộn sẽ đắt hơn nhiều so với những
    /// phép tô dựa trên byte.
    private func applyUserLanguageColors() {
        guard let language = userLanguage,
              let storage = textView.textContentStorage?.textStorage, !textWindow.isEmpty
        else { return }
        let target = colorTargetRange()
        guard !target.isEmpty else { return }

        let text = String(decoding: buffer.bytes(in: target), as: UTF8.self)
        storage.beginEditing()
        for span in language.spans(in: text, offset: target.lowerBound) {
            guard textWindow.contains(documentOffset: span.range.lowerBound) else { continue }
            let start = textWindow.utf16Offset(forDocumentOffset: span.range.lowerBound)
            let end = textWindow.utf16Offset(forDocumentOffset: span.range.upperBound)
            guard end > start, end <= storage.length else { continue }
            // Dùng chung bảng màu cú pháp: một ngôn ngữ tự định nghĩa phải trông như mọi ngôn
            // ngữ khác, không phải như một chế độ lạ.
            let color = Tokens.Color.syntax(span.scope) ?? Tokens.Color.editorInk
            storage.addAttribute(
                .foregroundColor, value: color,
                range: NSRange(location: start, length: end - start)
            )
        }
        storage.endEditing()
        needsDisplay = true
    }

    /// Chế độ Log: tô chữ theo mức nghiêm trọng của từng dòng (FR-FMT-508).
    var isLogMode = false {
        didSet {
            guard isLogMode != oldValue else { return }
            clearHighlighting()
            if isLogMode { applyLogColors() } else { requestHighlighting() }
        }
    }

    /// Tô mức nghiêm trọng cho phần đang nhìn thấy.
    ///
    /// Thay cho tô cú pháp chứ không chồng lên: một file log không có cú pháp để tô, và hai
    /// nguồn màu cùng ghi lên một khoảng byte thì cái nào thắng phụ thuộc thứ tự chạy — thứ
    /// không ai đoán được khi đọc mã.
    private func applyLogColors() {
        guard isLogMode, let storage = textView.textContentStorage?.textStorage, !textWindow.isEmpty
        else { return }
        let target = colorTargetRange()
        guard !target.isEmpty, buffer.lineCount > 0 else { return }

        let first = buffer.lineNumber(atOffset: target.lowerBound)
        let last = Swift.min(buffer.lineCount - 1, buffer.lineNumber(atOffset: Swift.max(target.upperBound - 1, 0)))
        guard first <= last else { return }
        let levels = LogFormat.levels(in: buffer, lineRange: first ... last)

        storage.beginEditing()
        for (line, level) in levels {
            let content = buffer.contentRange(ofLine: line)
            guard textWindow.contains(documentOffset: content.lowerBound) else { continue }
            let start = textWindow.utf16Offset(forDocumentOffset: content.lowerBound)
            let end = textWindow.utf16Offset(forDocumentOffset: content.upperBound)
            guard end > start, end <= storage.length else { continue }
            storage.addAttribute(
                .foregroundColor, value: Tokens.Color.logLevel(level),
                range: NSRange(location: start, length: end - start)
            )
        }
        storage.endEditing()
        needsDisplay = true
    }

    /// Mọi kết quả tìm kiếm, tính bằng offset TÀI LIỆU (FR-SRCH-109).
    ///
    /// Giữ CẢ danh sách chứ không chỉ phần nhìn thấy: chỗ gọi đã có sẵn nó từ `refreshMatches`,
    /// và cắt lại theo tầm nhìn ở mỗi nhịp cuộn rẻ hơn nhiều so với tìm lại.
    var searchHighlights: [Range<Int>] = [] {
        didSet {
            guard searchHighlights != oldValue else { return }
            applySearchHighlights()
        }
    }

    /// Những dòng có lỗi cú pháp, gạch dưới màu lỗi — FR-MMD-006.
    ///
    /// ## Gạch DƯỚI CHẤM, không phải gạch sóng — và nói ra là có chủ ý
    ///
    /// Đặc tả viết *"lỗi gạch sóng"*. TextKit 2 không có kiểu gạch sóng: `NSUnderlineStyle` chỉ
    /// có đơn/đôi/dày kèm mẫu chấm hoặc gạch. Vẽ một đường sóng thật thì phải tự lấy hình học
    /// từng mảnh bố cục rồi vẽ tay trong `draw(_:)` — làm được, nhưng nó là một hệ vẽ riêng phải
    /// nuôi, cho một khác biệt thị giác mà cả hai đều nói đúng một điều: *dòng này sai*.
    ///
    /// Nên ở đây là **gạch dưới CHẤM màu lỗi**, và giới hạn ấy được ghi ra thay vì giấu đi.
    var problemRanges: [Range<Int>] = [] {
        didSet {
            guard problemRanges != oldValue else { return }
            // Xoá dấu cũ trước khi vẽ dấu mới: thuộc tính gạch dưới nằm trên `textStorage` của
            // CỬA SỔ đang hiện, và không xoá thì một dòng đã sửa xong vẫn còn gạch đỏ — đúng
            // loại lỗi làm người dùng đi sửa một chỗ không sai.
            clearProblemMarks()
            applyProblemMarks()
        }
    }

    private func clearProblemMarks() {
        guard let storage = textView.textContentStorage?.textStorage else { return }
        storage.beginEditing()
        let whole = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.underlineStyle, range: whole)
        storage.removeAttribute(.underlineColor, range: whole)
        storage.endEditing()
    }

    private func applyProblemMarks() {
        guard !problemRanges.isEmpty,
              let storage = textView.textContentStorage?.textStorage, !textWindow.isEmpty
        else { return }
        storage.beginEditing()
        for range in problemRanges {
            guard textWindow.contains(documentOffset: range.lowerBound) else { continue }
            let start = textWindow.utf16Offset(forDocumentOffset: range.lowerBound)
            let end = textWindow.utf16Offset(forDocumentOffset: range.upperBound)
            guard end > start, end <= storage.length else { continue }
            let target = NSRange(location: start, length: end - start)
            storage.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue,
                range: target)
            storage.addAttribute(.underlineColor, value: Tokens.Color.error, range: target)
        }
        storage.endEditing()
        needsDisplay = true
    }

    /// Tô nền mọi kết quả đang nằm trong tầm nhìn.
    ///
    /// Cùng luật với tô cú pháp và tô cột: chỉ chạm phần NHÌN THẤY. Một pattern khớp 400 000
    /// lần trong file 200 MB mà tô hết là 400 000 lần `addAttribute` cho thứ không ai thấy.
    ///
    /// Tìm nhị phân để lấy phần cần tô: danh sách kết quả đã tăng dần theo offset, nên không
    /// cần duyệt cả mảng ở mỗi nhịp cuộn.
    private func applySearchHighlights() {
        guard let storage = textView.textContentStorage?.textStorage, !textWindow.isEmpty
        else { return }
        let target = colorTargetRange()
        guard !target.isEmpty else { return }

        var low = 0
        var high = searchHighlights.count
        while low < high {
            let mid = (low + high) / 2
            if searchHighlights[mid].upperBound <= target.lowerBound { low = mid + 1 } else { high = mid }
        }

        storage.beginEditing()
        var index = low
        while index < searchHighlights.count, searchHighlights[index].lowerBound < target.upperBound {
            let range = searchHighlights[index]
            index += 1
            guard textWindow.contains(documentOffset: range.lowerBound) else { continue }
            let start = textWindow.utf16Offset(forDocumentOffset: range.lowerBound)
            let end = textWindow.utf16Offset(forDocumentOffset: range.upperBound)
            guard end > start, end <= storage.length else { continue }
            storage.addAttribute(
                .backgroundColor, value: Tokens.Color.searchHighlight,
                range: NSRange(location: start, length: end - start)
            )
        }
        storage.endEditing()
        needsDisplay = true
    }

    private func applyColumnColors() {
        guard let dialect = csvDialect,
              let storage = textView.textContentStorage?.textStorage,
              !textWindow.isEmpty
        else { return }

        // Cuộn quanh quẩn trong vùng ĐÃ TÔ thì không làm gì.
        //
        // Đúng phép chặn mà `applyVisibleColors` ngay dưới đây đã có, và chỗ này thì thiếu.
        // Không có nó, mỗi lần khung nhìn nhích một pixel là tô lại cả vùng: `viewportMoved`
        // gọi thẳng hàm này, và một lượt tô CSV là hàng chục nghìn lời gọi `addAttribute`.
        //
        // Hai chỗ tô màu nằm cạnh nhau, một chỗ nhớ và một chỗ không — kiểu lệch ấy không hiện
        // ra ở bất kỳ bài kiểm nào, vì cả hai đều cho ra MÀU ĐÚNG. Khác biệt duy nhất là thời
        // gian, và chỉ trên file đủ lớn.
        let visible = visibleDocumentRange()
        let columnsNow = visibleCharacterColumns
        if columnColoredGeneration == windowGeneration, let colored = columnColoredRange,
           let coloredColumns = columnColoredColumns,
           colored.lowerBound <= visible.lowerBound, colored.upperBound >= visible.upperBound,
           coloredColumns.lowerBound <= columnsNow.lowerBound,
           coloredColumns.upperBound >= columnsNow.upperBound {
            return
        }

        // Chỉ tô phần NHÌN THẤY, cùng lý do như tô cú pháp: chi phí nằm ở `addAttribute`, và
        // cả cửa sổ 2 MB đo được 859 ms.
        let target = columnColorTargetRange()
        guard !target.isEmpty else { return }

        let spans = CSVColumns.spans(in: buffer, range: target, dialect: dialect)
        if ProcessInfo.processInfo.environment["GEDITOR_TRACE_CSVCOLOR"] != nil {
            NSLog("[csvcolor] visible=%d..<%d target=%d..<%d cửa sổ=%d..<%d đoạn=%d",
                  visible.lowerBound, visible.upperBound, target.lowerBound, target.upperBound,
                  textWindow.range.lowerBound, textWindow.range.upperBound, spans.count)
        }
        let palette = Tokens.Color.rainbow

        // Quy đổi CẢ LOẠT trong một lượt đi, không quy đổi từng đoạn một.
        //
        // `utf16Offset(forDocumentOffset:)` dựng lại vị trí từ đầu dòng ở mỗi lần gọi. Một
        // hàng CSV 200 ô gọi nó 400 lần, mỗi lần đi trung bình nửa hàng — bậc hai theo số cột.
        // Đo trên tệp 200 cột: **quy đổi 37,8 ms, đặt thuộc tính 4,1 ms**. Chín phần mười thời
        // gian nằm ở chỗ mà chú thích của chính tệp này vẫn ghi là rẻ.
        //
        // `CSVColumns.spans` trả về theo thứ tự tăng dần, nên mảng phẳng dưới đây cũng tăng
        // dần — điều kiện của `utf16Offsets(forSortedDocumentOffsets:)`.
        let inWindow = spans.filter { textWindow.contains(documentOffset: $0.range.lowerBound) }
        var flat: [Int] = []
        flat.reserveCapacity(inWindow.count * 2)
        for span in inWindow {
            flat.append(span.range.lowerBound)
            flat.append(span.range.upperBound)
        }
        let converted = textWindow.utf16Offsets(forSortedDocumentOffsets: flat)

        // Và bỏ qua những ô nằm ngoài tầm nhìn theo chiều NGANG.
        //
        // Một màn hình của CSV 200 cột chứa khoảng 9.200 ô, nhưng khung chỉ rộng chừng 140 ký
        // tự — tức chỉ vài chục cột đầu thật sự nhìn thấy được, phần còn lại nằm bên phải mép
        // màn hình. Tô chúng là tô cho không ai xem, và đó là 44,9 ms mỗi nhịp cuộn.
        //
        // Phép cắt này chỉ đúng vì hai điều kiện đã có sẵn: font vùng soạn thảo là ĐƠN CÁCH
        // (nên vị trí ngang = số ký tự × bề rộng một ký tự, phép đúng chứ không xấp xỉ), và ô
        // đầu của mỗi hàng bắt đầu ngay tại đầu dòng (nên mốc dòng lấy được từ chính danh sách
        // ô, không phải tra thêm).
        let columns = columnsNow
        storage.beginEditing()
        var rowStartUTF16 = 0
        var currentRow = -1
        for (index, span) in inWindow.enumerated() {
            let start = converted[index * 2]
            let end = converted[index * 2 + 1]
            if span.row != currentRow {
                currentRow = span.row
                rowStartUTF16 = start
            }
            // Cột tính bằng đơn vị UTF-16 kể từ đầu dòng — cùng đơn vị mà bố cục dùng để đặt
            // chữ, nên không có bước xấp xỉ nào ở giữa.
            guard end - rowStartUTF16 >= columns.lowerBound,
                  start - rowStartUTF16 <= columns.upperBound else { continue }
            guard end > start, end <= storage.length else { continue }
            storage.addAttribute(
                .foregroundColor, value: palette(span.column),
                range: NSRange(location: start, length: end - start)
            )
        }
        storage.endEditing()
        columnColoredRange = target
        columnColoredColumns = columns
        columnColoredGeneration = windowGeneration
        needsDisplay = true
    }

    /// Dải CỘT KÝ TỰ đang nhìn thấy theo chiều ngang.
    ///
    /// Chỉ có nghĩa khi TẮT ngắt dòng mềm — đó cũng là chế độ CSV mở ra mặc định, và là chế độ
    /// duy nhất có thanh cuộn ngang. Bật ngắt dòng thì mọi ký tự của một dòng đều nằm trong
    /// khung (chỉ xuống hàng), nên không có gì để cắt và hàm trả về dải vô hạn.
    ///
    /// Lề 40 cột mỗi bên để một cú cuộn ngang nhỏ không phải tô lại ngay.
    private var visibleCharacterColumns: Range<Int> {
        guard case .off = wrapMode, characterWidth > 0 else { return 0 ..< Int.max }
        let bounds = scrollView.contentView.bounds
        let inset = textView.textContainerInset.width
        let first = Int(Swift.max(0, bounds.minX - inset) / characterWidth)
        let onScreen = Int(bounds.width / characterWidth) + 2
        let margin = 40
        return Swift.max(0, first - margin) ..< (first + onScreen + margin)
    }

    /// Lề quanh tầm nhìn cho tô màu CỘT — hẹp hơn hẳn lề của tô cú pháp, và có lý do đo được.
    ///
    /// Số đoạn trên mỗi KB của hai đường lệch nhau cả bậc. Tô cú pháp sinh một đoạn cho mỗi
    /// **token** đáng màu, và phần lớn mã nguồn là khoảng trắng với tên biến không màu. Tô cột
    /// CSV sinh một đoạn cho mỗi **ô** — đo trên file điểm thi: **159 đoạn mỗi KB**. Cùng một
    /// con số lề, hai đường trả hai cái giá khác nhau mười lần.
    ///
    /// 8 KB cho khoảng 1.300 đoạn, tức ~5 ms — nằm trong ngân sách một khung hình 16,7 ms, kể
    /// cả khi cộng phần tô cú pháp chạy cùng lượt.
    private static let columnColorPaddingLimit = 8 * 1024

    /// Phạm vi cần tô màu cột.
    private func columnColorTargetRange() -> Range<Int> {
        let visible = visibleDocumentRange()
        let padding = Swift.min(Swift.max(visible.count, 2 * 1024), Self.columnColorPaddingLimit)
        return Swift.max(textWindow.range.lowerBound, visible.lowerBound - padding)
            ..< Swift.min(textWindow.range.upperBound, visible.upperBound + padding)
    }

    /// Dựng lại hàng tiêu đề dính, và quyết định có hiện nó không.
    ///
    /// Chỉ hiện khi ĐÃ cuộn qua hàng đầu. Hiện lúc hàng đầu vẫn còn trong tầm nhìn là vẽ hai
    /// lần cùng một dòng chồng lên nhau — người dùng tưởng file có hai dòng tiêu đề.
    func refreshCSVHeader() {
        guard let dialect = csvDialect, buffer.count > 0 else {
            csvHeader.isHidden = true
            csvHeaderHeight.constant = 0
            return
        }

        // Hàng tiêu đề LUÔN là hàng đầu tài liệu, đọc thẳng từ buffer chứ không từ cửa sổ:
        // cuộn tới dòng 40.000 thì cửa sổ không còn chứa nó nữa.
        let firstLineEnd = buffer.lineCount > 0
            ? buffer.contentRange(ofLine: 0).upperBound
            : buffer.count
        let rows = CSVColumns.spans(in: buffer, range: 0 ..< Swift.max(firstLineEnd, 1), dialect: dialect)
        let headerFields = rows.filter { $0.row == 0 }
            .sorted { $0.column < $1.column }
            .map { String(decoding: buffer.bytes(in: $0.range), as: UTF8.self) }

        guard headerFields.count > 1 else {
            csvHeader.isHidden = true
            csvHeaderHeight.constant = 0
            return
        }

        csvHeader.leftInset = textView.textContainerInset.width
        csvHeader.setHeader(
            fields: headerFields,
            delimiter: Character(UnicodeScalar(dialect.delimiter)),
            font: textView.font ?? Tokens.Font.editor()
        )

        // "Đã cuộn qua hàng tiêu đề chưa" là HÌNH HỌC THUẦN — so vị trí cuộn với đáy hàng
        // đầu. Bản đầu hỏi `visibleDocumentRange()`, thứ phụ thuộc viewport của TextKit và
        // không cập nhật kịp sau khi cuộn bằng lệnh: hàng tiêu đề không bao giờ hiện.
        let headerLines = Swift.max(1, buffer.lineNumber(atOffset: Swift.max(firstLineEnd - 1, 0)) + 1)
        let headerBottom = CGFloat(geometry.y(ofLine: headerLines))
        let scrolledPast = scrollView.contentView.bounds.minY > headerBottom
        csvHeader.isHidden = !scrolledPast
        csvHeaderHeight.constant = scrolledPast ? lineHeight + 2 * CSVHeaderView.padding : 0
        csvHeader.horizontalOffset = scrollView.contentView.bounds.origin.x
    }

    private func clearHighlighting() {
        guard let storage = textView.textContentStorage?.textStorage else { return }
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: whole)
        storage.addAttribute(.foregroundColor, value: Tokens.Color.editorInk, range: whole)
        storage.endEditing()
    }

    /// Đặt màu cho các đoạn đã phân tích.
    ///
    /// Offset của `spans` là offset TÀI LIỆU; `NSTextStorage` đếm bằng đơn vị UTF-16 của cửa
    /// sổ. Quy đổi qua `textWindow` — đúng chỗ mà dự án này đã có vài lỗi, nên mọi đoạn đều
    /// được kẹp và kiểm biên trước khi đặt.
    private func applyHighlighting(_ spans: [HighlightSpan]) {
        pendingSpans = spans
        coloredRange = nil
        applyVisibleColors()
    }

    /// Đặt màu cho phần ĐANG NHÌN THẤY (cộng lề vài màn hình).
    ///
    /// Đây là chỗ tôi đã sai và bài tự kiểm bắt được: bản đầu đặt thuộc tính cho cả cửa sổ
    /// 2 MB, đo ra **5.170 ms** với mã C và **859 ms** với CSV. Chi phí không nằm ở phân tích
    /// mà ở `NSTextStorage.addAttribute` — mỗi đoạn một lần, và một cửa sổ 2 MB có hàng chục
    /// nghìn đoạn.
    ///
    /// Phân tích vẫn làm cho cả cửa sổ; chỉ phần ĐẶT MÀU mới bám theo tầm nhìn.
    private func applyVisibleColors() {
        guard let storage = textView.textContentStorage?.textStorage, storage.length > 0 else {
            return
        }
        let visible = visibleDocumentRange()
        // Cuộn quanh quẩn trong vùng đã tô thì không làm gì.
        if let colored = coloredRange,
           colored.lowerBound <= visible.lowerBound, colored.upperBound >= visible.upperBound {
            return
        }

        let target = colorTargetRange()
        guard !target.isEmpty else { return }

        storage.beginEditing()
        let from = textWindow.utf16Offset(forDocumentOffset: target.lowerBound)
        let to = textWindow.utf16Offset(forDocumentOffset: target.upperBound)
        if to > from, to <= storage.length {
            storage.addAttribute(
                .foregroundColor, value: Tokens.Color.editorInk,
                range: NSRange(location: from, length: to - from)
            )
        }

        for span in pendingSpans {
            guard span.range.upperBound > target.lowerBound,
                  span.range.lowerBound < target.upperBound,
                  let color = Tokens.Color.syntax(span.scope),
                  textWindow.contains(documentOffset: span.range.lowerBound)
            else { continue }
            let start = textWindow.utf16Offset(forDocumentOffset: span.range.lowerBound)
            let end = textWindow.utf16Offset(forDocumentOffset: span.range.upperBound)
            guard end > start, end <= storage.length else { continue }
            storage.addAttribute(
                .foregroundColor, value: color, range: NSRange(location: start, length: end - start)
            )
        }
        storage.endEditing()
        coloredRange = target
        needsDisplay = true
    }

    /// Trần cho phần lề quanh tầm nhìn.
    ///
    /// Không phải tinh chỉnh mà là LƯỚI CHẶN. Bản đầu lấy lề bằng `tầm nhìn × 2` mà không có
    /// trần; khi phép ước lượng tầm nhìn trả về cả cửa sổ, lề nhân theo và vùng xin tô thành
    /// 1953 KB — truy vấn trả 687.500 đoạn và mất 2,1 giây. Có trần thì ước lượng sai vẫn chỉ
    /// hỏng trong một biên đã biết.
    private static let colorPaddingLimit = 128 * 1024

    /// Phạm vi cần tô: tầm nhìn cộng lề, đã chặn trần.
    private func colorTargetRange() -> Range<Int> {
        let visible = visibleDocumentRange()
        let padding = Swift.min(Swift.max(visible.count, 16 * 1024), Self.colorPaddingLimit)
        return Swift.max(textWindow.range.lowerBound, visible.lowerBound - padding)
            ..< Swift.min(textWindow.range.upperBound, visible.upperBound + padding)
    }

    /// Phần tài liệu đang nằm trong tầm nhìn, tính bằng offset TÀI LIỆU.
    ///
    /// Hỏi `textViewportLayoutController.viewportRange` — thứ TextKit ĐANG hiển thị — thay vì
    /// tự dò theo toạ độ y. Bản đầu dò bằng `textLayoutFragment(for:)` ở mép trên và mép dưới;
    /// mép dưới nằm ngoài phần đã dựng bố cục nên nó trả về đoạn cuối cùng, và "tầm nhìn" hoá
    /// ra bằng cả cửa sổ. Sai lặng lẽ: không lỗi, chỉ chậm gấp bốn mươi lần.
    /// Dải DÒNG đang hiện trên màn hình — cho bản đồ tài liệu vẽ khung tầm nhìn.
    var visibleLineRange: Range<Int> {
        let range = visibleDocumentRange()
        let first = buffer.lineNumber(atOffset: Swift.min(range.lowerBound, Swift.max(buffer.count - 1, 0)))
        let last = buffer.lineNumber(atOffset: Swift.min(range.upperBound, Swift.max(buffer.count - 1, 0)))
        return first ..< Swift.max(first + 1, last + 1)
    }

    private func visibleDocumentRange() -> Range<Int> {
        guard let manager = textView.textLayoutManager,
              let content = manager.textContentManager
        else { return fallbackVisibleRange() }

        guard let viewport = manager.textViewportLayoutController.viewportRange else {
            return fallbackVisibleRange()
        }
        let lower = content.offset(from: content.documentRange.location, to: viewport.location)
        let upper = content.offset(from: content.documentRange.location, to: viewport.endLocation)
        let start = documentOffset(forUTF16: Swift.min(lower, upper))
        let end = documentOffset(forUTF16: Swift.max(lower, upper))
        guard end > start else { return fallbackVisibleRange() }

        // ĐỐI CHIẾU VỚI VỊ TRÍ CUỘN THẬT TRƯỚC KHI TIN.
        //
        // `viewportRange` là thứ TextKit ĐÃ dựng bố cục, không phải thứ khung cuộn ĐANG chỉ
        // vào. Ngay sau một cú `scroll(to:)` bằng mã, hai thứ ấy lệch nhau: thông báo
        // `boundsDidChange` phát ngay trong lời gọi ấy, còn TextKit thì chưa chạy lượt bố cục
        // nào — nên `viewportRange` vẫn trỏ vào chỗ CŨ.
        //
        // Hậu quả không phải một con số sai mà là màu SAI CHỖ: `viewportMoved` tô lại đúng
        // vùng vừa rời đi, còn vùng vừa hiện ra thì không ai tô. Và vì không có cú cuộn nào
        // nữa, nó ở nguyên như thế. Triệu chứng người dùng thấy: kéo xuống một file CSV lớn
        // thì màu cột biến mất, kéo tay từng chút thì lại có — vì cuộn tay phát ra hàng chục
        // thông báo và những cái sau đã kịp thấy bố cục mới.
        //
        // Không bỏ hẳn đường TextKit: khi nó đúng thì nó CHÍNH XÁC, còn phép suy từ hình học
        // chỉ xấp xỉ ở chế độ ngắt dòng mềm (`rowsPerLine` là số ước lượng). Nên giữ nó, và
        // chỉ hạ xuống dùng hình học khi hai bên không giao nhau — tức khi nó chắc chắn cũ.
        let byGeometry = fallbackVisibleRange()
        if !byGeometry.isEmpty, start >= byGeometry.upperBound || end <= byGeometry.lowerBound {
            return byGeometry
        }
        return start ..< end
    }

    /// Chưa biết tầm nhìn thì lấy một quãng quanh con trỏ — có biên, không lấy cả cửa sổ.
    /// Tầm nhìn suy từ HÌNH HỌC của khung cuộn, dùng khi TextKit chưa trả lời được.
    ///
    /// **Nhánh này chạy thường xuyên hơn nhiều so với tên gọi "dự phòng".** `viewportRange` của
    /// TextKit là `nil` trong suốt khoảng giữa lúc ta cuộn và lúc nó dựng xong bố cục — tức
    /// đúng lúc `viewportMoved` chạy. Đo trên file 46 MB: 9 lần mỗi cú nhảy.
    ///
    /// Bản đầu trả về **con nháy ± 32 KB**, một hằng số không liên quan gì tới màn hình. Trên
    /// CSV, 64 KB là khoảng 1.600 dòng — gấp ba mươi lần số dòng thật sự nhìn thấy — và vì
    /// `colorTargetRange` cộng thêm lề tỉ lệ với chính con số ấy, vùng xin tô phồng lên 227 KB.
    /// Tô 227 KB CSV là 36.148 lời gọi `NSTextStorage.addAttribute`, đo được **132 ms mỗi lần
    /// cuộn**: tám khung hình bị bỏ, và đó chính là cảm giác giật khi kéo một file lớn.
    ///
    /// Nó không sai theo kiểu báo lỗi — nó sai theo kiểu chậm, đúng cùng một cách mà chú thích
    /// ở `visibleDocumentRange` đã ghi lại cho một lần trước ("sai lặng lẽ: không lỗi, chỉ chậm
    /// gấp bốn mươi lần"). Cùng một cái bẫy, cùng một tệp, lần thứ hai.
    ///
    /// Bản này hỏi khung cuộn cao bao nhiêu và một dòng cao bao nhiêu — hai con số luôn có sẵn
    /// và không cần TextKit — rồi quy ra dải DÒNG. Kết quả bám sát màn hình thật, và nó đúng ở
    /// cả chế độ ngắt dòng mềm vì `geometry` đã tính `rowsPerLine` vào.
    private func fallbackVisibleRange() -> Range<Int> {
        guard buffer.lineCount > 0 else {
            return textWindow.range.lowerBound ..< textWindow.range.lowerBound
        }
        let bounds = scrollView.contentView.bounds
        let firstLine = geometry.line(atY: Double(bounds.minY))
        // Cộng hai dòng đệm: mép trên và mép dưới thường cắt ngang một dòng.
        let rowsOnScreen = Int((Double(bounds.height) / Swift.max(Double(lineHeight), 1)).rounded(.up)) + 2
        let lastLine = Swift.min(buffer.lineCount - 1, firstLine + Swift.max(rowsOnScreen, 1))

        let start = buffer.offset(ofLineStart: firstLine)
        let end = buffer.contentRange(ofLine: lastLine).upperBound
        // Kẹp vào cửa sổ: mọi chỗ gọi đều quy đổi qua `textWindow`, và một offset ngoài cửa sổ
        // sẽ bị bỏ im lặng ở đó — tức tô thiếu mà không ai biết.
        let lower = Swift.min(Swift.max(start, textWindow.range.lowerBound),
                              textWindow.range.upperBound)
        let upper = Swift.min(Swift.max(end, lower), textWindow.range.upperBound)
        return lower ..< upper
    }

    /// Nạp lại nội dung từ buffer mà KHÔNG dời chỗ đang xem (FR-DOC-302).
    ///
    /// Dùng khi buffer bị sửa ở pane KHÁC. Hai pane cùng một tài liệu phải thấy cùng nội dung
    /// tức thời (TC-DOC-05), nhưng vị trí cuộn của chúng phải độc lập — nên ở đây nạp lại đúng
    /// cửa sổ cũ và trả con trỏ về chỗ cũ, thay vì `load` (nhảy về đầu) hay `reveal` (kéo màn
    /// hình theo con trỏ của pane bên kia).
    ///
    /// Con trỏ bị KẸP vào cỡ mới: pane kia có thể vừa xóa mất đoạn mà con trỏ này đang đứng.
    func refreshFromBuffer() {
        let caret = Swift.min(selectedDocumentRange.lowerBound, buffer.count)
        let anchor = Swift.min(textWindow.range.lowerBound, buffer.count)
        let scroll = scrollView.contentView.bounds.origin

        repaginate(around: anchor)
        setSelectedDocumentRange(caret ..< caret)
        scrollView.contentView.scroll(to: scroll)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Nội dung đang chọn, đọc thẳng từ buffer chứ không từ view.
    var selectedText: String {
        let range = selectedDocumentRange
        guard !range.isEmpty else { return "" }
        return String(decoding: buffer.bytes(in: range), as: UTF8.self)
    }
}

// MARK: - Đồng bộ view → buffer

extension WindowedTextView: NSTextViewDelegate {

    func textView(
        _ view: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        // Sửa nội dung làm neo khối bàn phím vô nghĩa: nó là một cặp (dòng, cột), và mọi thứ
        // sau chỗ vừa sửa đã dịch đi. Xoá ở ĐÂY chứ không chỉ ở `keyDown`, vì đây là chỗ duy
        // nhất mọi phép sửa đều đi qua — kể cả dán, macro và script.
        if !isSyncing { endColumnKeyboardSelection() }
        guard !isSyncing, let replacementString, let onEdit else { return true }

        // NHIỀU CARET: tự sinh và áp tất cả sửa đổi, rồi trả `false` để `NSTextView` đừng tự
        // sửa nữa. Trả `true` sẽ thành sửa hai lần ở caret chính.
        //
        // Đây là chỗ DUY NHẤT chặn được cả gõ lẫn xóa: xóa cũng đi qua đây với chuỗi thay thế
        // rỗng, nên không cần bắt riêng từng phím.
        // ĐANG SOẠN bằng bộ gõ (TC-IME-02).
        //
        // Bộ gõ tiếng Việt đánh dấu MỌI phím, nên nếu chặn ở đây thì nhiều caret thành vô dụng
        // với đúng người dùng của sản phẩm này. Cũng không thể áp từng bước soạn dở dang lên
        // mọi caret — "hoaf" đang gõ sẽ hiện ra nguyên xi ở các caret phụ.
        //
        // Cách làm: để bộ gõ soạn ở caret CHÍNH như thường, nhớ chỗ bắt đầu, và khi soạn xong
        // thì lấy đúng phần vừa chốt áp sang các caret còn lại.
        if selection.isMultiple, view.hasMarkedText() {
            if composition == nil { composition = selection }
            return true
        }

        if selection.isMultiple {
            let lower = documentOffset(forUTF16: affectedCharRange.location)
            let upper = documentOffset(
                forUTF16: affectedCharRange.location + affectedCharRange.length
            )
            let kind: MultiEditKind
            if !replacementString.isEmpty {
                kind = .insert(replacementString)
            } else if selection.hasSelection {
                kind = .insert("")                       // xóa vùng đang chọn ở mọi caret
            } else if upper <= selection.primary.lowerBound {
                kind = .deleteBackward                   // AppKit nới vùng về phía TRƯỚC caret
            } else {
                kind = .deleteForward
            }
            _ = lower
            onMultiEdit?(selection, kind)
            return false
        }

        let lower = documentOffset(forUTF16: affectedCharRange.location)
        let upper = documentOffset(
            forUTF16: affectedCharRange.location + affectedCharRange.length
        )
        guard onEdit(lower ..< Swift.max(lower, upper), replacementString) else { return false }

        // Buffer đã đổi, nên bảng quy đổi của cửa sổ cũ hết đúng. Dựng lại NGAY, đừng đợi:
        // lần gõ kế tiếp sẽ hỏi quy đổi và sẽ nhận số sai.
        //
        // View tự áp thay đổi sau khi hàm này trả `true`, nên ở đây chỉ dựng lại BẢNG quy đổi
        // trên đúng phạm vi mới, không đụng tới `textView.string`.
        let delta = replacementString.utf8.count - (upper - lower)

        // Vùng gấp nằm SAU chỗ vừa sửa phải dời đi đúng `delta` byte.
        //
        // Không dời thì chúng trỏ vào chỗ cũ, và mỗi ký tự gõ thêm làm phần bị giấu lệch thêm
        // một byte — chữ hiện ra bắt đầu cụt đầu hoặc thừa đuôi. Không xóa hết vùng gấp ở đây
        // được: `textView` đang giữ chuỗi ĐÃ GẤP và sắp tự áp thay đổi lên chính chuỗi ấy, nên
        // cửa sổ phải tiếp tục là cửa sổ có gấp.
        if !activeFolds.isEmpty, delta != 0 {
            activeFolds = activeFolds.map { fold in
                guard fold.hiddenBytes.lowerBound >= upper else { return fold }
                return FoldRange(
                    headerLine: fold.headerLine, lastLine: fold.lastLine,
                    hiddenBytes: (fold.hiddenBytes.lowerBound + delta)
                        ..< (fold.hiddenBytes.upperBound + delta),
                    caretHome: fold.caretHome + delta, kind: fold.kind
                )
            }
        }

        let end = Swift.min(buffer.count, textWindow.range.upperBound + delta)
        textWindow = TextWindowing.window(range: textWindow.range.lowerBound ..< Swift.max(textWindow.range.lowerBound, end),
                                      in: buffer, folds: activeFolds)
        return true
    }

    func textDidChange(_ notification: Notification) {
        guard !isSyncing else { return }
        // Thứ tự QUAN TRỌNG: khung cuộn được nới theo đáy khung chữ, nên khung chữ phải đặt
        // xong trước. Đảo lại thì khung cuộn dùng số của lần vẽ trước và thiếu đúng một nhịp.
        positionTextView()
        resizeCanvas()
        scheduleHighlighting()
        finishCompositionIfNeeded()
        // Không gợi ý giữa lúc bộ gõ đang soạn dở: danh sách sẽ nhảy theo từng dấu thanh, và
        // Enter để chốt dấu sẽ bị hiểu thành "chọn gợi ý".
        if !textView.hasMarkedText() { onTypingPause?() }
    }

    /// Bộ gõ vừa chốt xong: nhân phần vừa chốt sang các caret phụ.
    ///
    /// Phần vừa chốt = đoạn nằm giữa chỗ caret chính lúc bắt đầu soạn và chỗ nó đang đứng.
    private func finishCompositionIfNeeded() {
        guard let started = composition, !textView.hasMarkedText() else { return }
        composition = nil

        let caretNow = selectedDocumentRange.lowerBound
        let from = started.primary.lowerBound
        guard caretNow > from else {
            // Soạn bị huỷ hoặc không sinh ra chữ nào — giữ nguyên tập caret cũ, chỉ dời theo.
            setSelection(started)
            return
        }

        let committed = String(decoding: buffer.bytes(in: from ..< caretNow), as: UTF8.self)
        onCompositionCommitted?(started, committed)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isSyncing else { return }
        // Người dùng click/kéo bình thường: tập caret thu về đúng vùng ấy. Không đồng bộ thì
        // caret phụ cũ còn treo lại sau khi người dùng đã click đi chỗ khác.
        if !selection.isMultiple {
            selection.setSingle(selectedDocumentRange)
            overlay.selection = selection
        }
        onSelectionChange?()
    }
}

// MARK: - Ký tự ẩn (FR-ENC-205)

extension WindowedTextView: NSTextLayoutManagerDelegate {

    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        let fragment = InvisiblesLayoutFragment(textElement: textElement, range: textElement.elementRange)
        fragment.settings = invisibleSettings
        return fragment
    }
}

/// `NSTextView` biết hỏi ý kiến chủ về nhiều caret (FR-CORE-001).
///
/// Chỉ chặn đúng HAI đường: Cmd+Click để thêm caret, và Esc để thu về một. Việc gõ/xóa đi qua
/// `textView(_:shouldChangeTextIn:replacementString:)` — xem ghi chú ở đó.
///
/// Bản đầu tôi override `insertText(_:replacementRange:)`, `deleteBackward` và `deleteForward`.
/// Đo ra thì `keyDown` có chạy mà `insertText` KHÔNG hề được gọi: AppKit đưa chữ vào bằng đường
/// khác. Thay vì đoán tiếp đường nào, dùng con đường đã chứng minh là chạy.
final class MultiCaretTextView: NSTextView {

    weak var host: WindowedTextView?

    /// Xuống dòng có thụt lề theo dòng đang đứng (FR-CORE-011).
    ///
    /// Chèn `"\n" + thụt lề` bằng `insertText` chứ không tự sửa buffer: đường ấy đi qua đúng
    /// `shouldChangeTextIn`, nên nhiều caret, bộ gõ và lịch sử hoàn tác đều cư xử như khi
    /// người dùng gõ tay — thứ mà một đường tắt riêng sẽ phá.
    override func insertNewline(_ sender: Any?) {
        guard let host, let indent = host.indentForNewLine(), !indent.isEmpty else {
            return super.insertNewline(sender)
        }
        insertText("\n" + indent, replacementRange: selectedRange())
    }

    /// Gõ `>` xong một thẻ mở thì tự chèn thẻ đóng, con nháy ở GIỮA (FR-FMT-505).
    ///
    /// Đi qua `insertText` hai lần chứ không ghép một chuỗi: lần thứ hai phải là một bước
    /// riêng để ⌘Z gỡ được thẻ đóng mà giữ lại thẻ mở người dùng vừa gõ. Ghép chung thì một
    /// lần hoàn tác xoá cả hai, và người dùng mất luôn thứ họ tự viết ra.
    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        guard (string as? String) == ">", let host, host.autoClosesTags else { return }

        // Chỉ cần phần NGAY TRƯỚC con nháy, và chỉ vài chục byte: tên thẻ dài nhất người ta
        // gõ cũng không tới thế. Đọc cả tài liệu ở mỗi dấu `>` là một lượt quét trên tệp có
        // thể lớn hàng trăm MB.
        let caret = host.selectedDocumentRange.lowerBound
        let start = Swift.max(0, caret - 256)
        let prefix = String(decoding: host.buffer.bytes(in: start ..< caret), as: UTF8.self)
        guard let closing = XMLTool.closingTag(afterTyping: prefix) else { return }

        super.insertText(closing, replacementRange: selectedRange())
        // Con nháy về GIỮA hai thẻ — chỗ người dùng sẽ gõ tiếp.
        host.setCaret(documentOffset: caret)
    }

    override func mouseDown(with event: NSEvent) {
        guard let host else { return super.mouseDown(with: event) }

        // Option+kéo = chọn khối chữ nhật (FR-CORE-002). Phải bắt ở `mouseDown` và tự chạy
        // vòng kéo: để `NSTextView` xử lý thì nó chọn theo dòng như thường và không có đường
        // nào can thiệp giữa chừng.
        if event.modifierFlags.contains(.option) {
            host.beginColumnSelection(at: convert(event.locationInWindow, from: nil))
            return
        }
        if event.modifierFlags.contains(.command) {
            host.addCaret(atViewPoint: convert(event.locationInWindow, from: nil))
            return
        }
        super.mouseDown(with: event)
    }

    /// Danh sách gợi ý được ngó phím TRƯỚC.
    ///
    /// Mũi tên và Enter khi danh sách đang mở thuộc về nó; mọi phím khác đi tiếp như thường.
    /// Chặn ở đây chứ không ở `doCommand` vì `doCommand` chạy sau khi AppKit đã diễn giải phím
    /// thành lệnh di chuyển con nháy — lúc ấy con nháy đã nhảy đi rồi.
    override func keyDown(with event: NSEvent) {
        if host?.onCompletionKey?(event) == true { return }

        // Option+Cmd+mũi tên = nới khối chữ nhật bằng bàn phím (FR-CORE-002).
        //
        // Bắt ở `keyDown` chứ không ở `doCommand`: AppKit diễn giải Option+mũi tên thành
        // "nhảy theo từ" và Cmd+mũi tên thành "về đầu/cuối dòng" TRƯỚC khi `doCommand` chạy,
        // nên tới đó thì con nháy đã đi mất và neo khối tính từ một chỗ khác.
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.option), modifiers.contains(.command),
           let direction = Self.columnDirection(forKeyCode: event.keyCode) {
            host?.extendColumnSelection(direction)
            return
        }
        // Mọi phím KHÁC kết thúc khối đang kéo — xem `columnKeyboardAnchor`.
        host?.endColumnKeyboardSelection()
        super.keyDown(with: event)
    }

    private static func columnDirection(
        forKeyCode code: UInt16
    ) -> WindowedTextView.ColumnKeyDirection? {
        switch code {
        case 123: return .left
        case 124: return .right
        case 125: return .down
        case 126: return .up
        default: return nil
        }
    }

    override func doCommand(by selector: Selector) {
        host?.onCommand?(selector)
        super.doCommand(by: selector)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { host?.onFocus?() }
        return became
    }

    override func cancelOperation(_ sender: Any?) {
        guard let host, host.selection.isMultiple else { return super.cancelOperation(sender) }
        host.collapseSelection()
    }
}

/// Lớp phủ vẽ các caret PHỤ và vùng chọn phụ (FR-CORE-001).
///
/// Vẽ đè lên `NSTextView` thay vì nhờ nó: nó chỉ biết một caret, và mọi cách "mượn" vùng chọn
/// phụ của nó (`selectedRanges`) đều không gõ được — xem ADR-01 §3.3.
final class MultiCaretOverlay: NSView {

    var selection = MultiSelection()
    /// Quy đổi offset tài liệu → khung trên màn hình; `nil` nếu nằm ngoài cửa sổ đang giữ.
    var rectForOffset: ((Int) -> NSRect?)?
    /// Dải nền của các dòng đã đánh dấu, chỉ trong vùng cần vẽ (FR-SRCH-107).
    var markedBands: ((NSRect) -> [(rect: NSRect, color: Int)])?
    /// Offset cuối những dòng đang gấp — chỗ đặt phù hiệu `⋯`.
    var foldMarkers: (() -> [Int])?
    /// Vạch lề EIDE: dòng có chú thích fact, và dòng vi phạm constant-guard.
    var daiEide: ((NSRect) -> [(rect: NSRect, viPham: Bool)])?

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // chuột vẫn đi thẳng xuống text view

    override func draw(_ dirtyRect: NSRect) {
        // Nền dòng đánh dấu vẽ TRƯỚC vùng chọn: vùng chọn phải thắng khi hai thứ chồng nhau,
        // vì vùng chọn là cái người dùng vừa tạo ra bằng tay.
        for band in markedBands?(dirtyRect) ?? [] {
            let palette = Tokens.Color.markColors
            palette[Swift.min(Swift.max(band.color, 0), palette.count - 1)].setFill()
            band.rect.fill()
        }

        // Vạch lề EIDE vẽ SAU nền dòng đánh dấu và TRƯỚC vùng chọn: nó là chú thích của hệ
        // thống, nên nó không được che dấu người dùng tự đặt, và cũng không được bị vùng chọn
        // xoá đi — vạch ở mép trái, vùng chọn bắt đầu sau đó.
        for d in daiEide?(dirtyRect) ?? [] {
            // ĐỎ = vi phạm, XANH LỤC = có fact.
            //
            // Bản đầu dùng `action` cho "có fact", và `action` là một màu cam-đỏ của bảng PTIT:
            // trên ảnh chụp 16/09, bốn dòng 4–7 (fact · vi phạm · fact · vi phạm xen kẽ) hiện
            // ra thành MỘT vệt liền, không phân biệt được hai nghĩa ngược nhau. Xanh lục
            // `EideToken.Mau.ok` là màu EIDE vẫn dùng cho "đã duyệt, dùng được" ở mọi màn khác,
            // nên nó nói đúng điều cần nói và không dạy thêm một nghĩa mới.
            (d.viPham ? Tokens.Color.error : EideToken.Mau.ok).setFill()
            d.rect.fill()
        }

        // Phù hiệu `⋯` cuối dòng đã gấp.
        //
        // Vẽ ở đây chứ không chèn ký tự vào chuỗi: chèn chữ vào `textView.string` sẽ làm mọi
        // phép quy đổi vị trí lệch đi đúng bằng độ dài phù hiệu, và đó là cái giá quá đắt cho
        // một dấu hiệu thị giác. Vẽ đè thì chuỗi vẫn khớp từng byte với tài liệu.
        //
        // KHÔNG có dấu hiệu nào thì người dùng không biết chữ đang bị giấu — họ sẽ tưởng file
        // mất nội dung. Đây là chỗ duy nhất nói ra điều ấy, vì bản này chưa có lề số dòng.
        if let rectForOffset, let markers = foldMarkers?(), !markers.isEmpty {
            let font = Tokens.Font.monoInline()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: Tokens.Color.chrome,
            ]
            for offset in markers {
                guard let rect = rectForOffset(offset), rect.intersects(dirtyRect) else { continue }
                let badge = NSRect(
                    x: rect.maxX + 4, y: rect.minY + 1, width: 24, height: max(rect.height - 2, 4)
                )
                Tokens.Color.orange.setFill()
                NSBezierPath(roundedRect: badge, xRadius: 3, yRadius: 3).fill()
                let label = "⋯" as NSString
                let size = label.size(withAttributes: attributes)
                label.draw(
                    at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2),
                    withAttributes: attributes
                )
            }
        }

        guard selection.isMultiple, let rectForOffset else { return }

        for (index, range) in selection.ranges.enumerated() {
            // Caret chính do NSTextView tự vẽ — vẽ thêm ở đây là thành hai vạch chồng nhau.
            guard index != selection.primaryIndex else { continue }

            if range.isEmpty {
                guard let rect = rectForOffset(range.lowerBound) else { continue }
                Tokens.Color.orange.setFill()
                NSRect(x: rect.minX, y: rect.minY, width: 2, height: rect.height).fill()
            } else {
                guard let start = rectForOffset(range.lowerBound),
                      let end = rectForOffset(range.upperBound) else { continue }
                Tokens.Color.selection.setFill()
                if abs(start.minY - end.minY) < 1 {
                    NSRect(x: start.minX, y: start.minY,
                           width: end.minX - start.minX, height: start.height).fill()
                } else {
                    // Vùng chọn vắt nhiều dòng: tô từ đầu vùng tới hết dòng, rồi các dòng giữa.
                    NSRect(x: start.minX, y: start.minY,
                           width: bounds.width - start.minX, height: start.height).fill()
                    NSRect(x: 0, y: start.maxY, width: bounds.width,
                           height: max(0, end.minY - start.maxY)).fill()
                    NSRect(x: 0, y: end.minY, width: end.minX, height: end.height).fill()
                }
            }
        }
    }
}

/// Khung cuộn tọa độ gốc ở TRÊN — cùng chiều với số dòng, đỡ một phép đảo ở mọi phép tính.
///
/// Nó cũng là chỗ vẽ NỀN, vì text view đã tắt nền để lớp phủ vùng chọn nhìn thấy được.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Tokens.Color.editorBackground.setFill()
        bounds.fill()
    }
}
