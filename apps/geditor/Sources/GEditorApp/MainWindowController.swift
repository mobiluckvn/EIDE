import AppKit
import UniformTypeIdentifiers
import EIDEKit
import GEditorCore

/// Cửa sổ chính — một cửa sổ = một phiên làm việc (UI/UX §3).
///
/// Skeleton hiện có: vùng soạn thảo + status bar tương tác + banner cảnh báo, nối vào
/// `Document` của lõi. Còn thiếu theo UI/UX §3:
/// TODO(FR-DOC-301) thanh tab · TODO(FR-DOC-302) split 2 pane + clone
/// TODO(FR-DOC-307/308) sidebar Workspace + Function List · TODO(FR-SRCH-105) panel dưới.
///
/// TODO(ADR-01): `NSTextView` ở đây CHỈ là chỗ dựng khung. Engine hiển thị thật do PoC-A
/// chốt (Scintilla-Cocoa mặc định, đối chứng TextKit 2) — NSTextView thuần không đạt
/// NFR-PERF-04 trên file 500 MB và không có sẵn multi-caret/column mode.
final class MainWindowController: NSWindowController {

    // MARK: - Hai pane (FR-DOC-302)
    //
    // Dựng SẴN cả hai khung ngay từ đầu, chỉ khung thứ hai chưa gắn vào cây view. Dựng muộn
    // thì lúc chia đôi phải nối lại toàn bộ callback, và mỗi callback quên nối là một tính
    // năng im lặng không chạy ở nửa màn hình bên kia.
    private let paneViews = [WindowedTextView(), WindowedTextView()]
    private let splitView = NSSplitView()

    /// Khung chứa toàn bộ nội dung cửa sổ.
    private let container = NSView()

    // Khung EIDE (DEV-098) — sidebar trái và vùng nội dung đổi giữa trình soạn thảo với màn.
    var sidebarEide: NSTableView?
    private var nguonSidebar: NguonSidebarEide?
    private var dieuHuongEide: EideDieuHuong?
    private var khungEideGoc: NSView?
    /// Dự án mà cây tệp đang trỏ tới — để không trỏ lại workspace ở mỗi lần mở màn Mã nguồn.
    private var cayDangTro: String?
    private var vungSoanThao: NSView?
    private var vachEide: NSBox?

    /// Hàng giữa: cây thư mục (nếu đã mở) bên trái, vùng soạn thảo bên phải.
    private let middleRow = NSView()

    /// Mép trái của vùng soạn thảo — dán vào `middleRow` khi chưa có sidebar, vào sidebar khi
    /// đã có. Giữ tham chiếu vì phải THAY nó, không phải chỉ đổi hằng số.
    private var splitViewLeading: NSLayoutConstraint!
    private var splitViewTrailing: NSLayoutConstraint!

    /// Chỉ số tab mà mỗi pane đang hiện. Hai pane trỏ vào CÙNG một danh sách tab.
    ///
    /// Cách này khác Notepad++ (mỗi view một danh sách tab riêng), và đổi lại được đúng thứ
    /// SRS đòi mà không phải xẻ đôi mô hình tab: hai pane cùng mở một tài liệu là chuyện chỉ
    /// cần hai chỉ số bằng nhau, nên "clone sang pane kia" thành một phép gán.
    private var paneTabIndices = [0, 0]
    private var activePaneIndex = 0

    /// Khung soạn thảo của pane ĐANG hoạt động.
    ///
    /// Là thuộc tính tính toán vì lý do đã dùng hai lần trước đó (tài liệu của tab, rồi tab
    /// của cửa sổ): bốn chục chỗ gọi cũ không phải sửa dòng nào, và không chỗ nào lỡ giữ lại
    /// khung của pane cũ.
    var editorView: WindowedTextView { paneViews[activePaneIndex] }

    /// Pane còn lại; `nil` khi chưa chia đôi.
    private var otherPane: WindowedTextView? {
        isSplit ? paneViews[1 - activePaneIndex] : nil
    }

    private(set) var isSplit = false
    /// Bảng CSV — bản chiếu thứ hai của cùng tài liệu (FR-CSV-403).
    /// Bản đồ tài liệu — dựng khi người dùng bật lần đầu (FR-DOC-306).
    lazy var documentMapView: DocumentMapView = {
        let view = DocumentMapView()
        view.isHidden = true
        return view
    }()

    private var documentMapWidth: NSLayoutConstraint!
    private var reportPreviewWidth: NSLayoutConstraint!
    private var reportParameters: [String: String] = [:]
    private(set) var lastReportRender: ReportRenderer.Rendered?
    private(set) var lastReportSource: String?
    private var documentMapAttached = false
    private var reportPreviewAttached = false
    /// Bản ghi tài liệu mà bản đồ đang mô tả, để không dựng lại khi chưa có gì đổi.
    private var documentMapRevision: (buffer: Int, revision: Int, rows: Int)?

    /// Cấu hình người dùng, đọc từ `settings.json` lúc khởi động (FR-UI-803 · NFR-PORT-03).
    var settings = Settings()

    /// Câu thông báo ngắn gần nhất — để bài kiểm đọc được đúng thứ người dùng vừa thấy, thay vì
    /// đoán qua trạng thái nội bộ.
    private(set) var lastTransient = ""

    /// File cấu hình thuộc về một bản GEditor MỚI HƠN, hoặc không đọc được.
    ///
    /// Khi ấy app chạy bằng mặc định nhưng TUYỆT ĐỐI không ghi đè: người dùng đồng bộ Application
    /// Support giữa hai máy sẽ mất sạch cấu hình mà không có cách nào biết vì sao.
    var settingsAreReadOnly = false

    var preferencesPanel: PreferencesPanel?
    /// Ngôn ngữ tự định nghĩa, đọc từ `grammars/` một lần lúc khởi động (FR-FMT-502).
    ///
    /// Đọc một lần chứ không quét thư mục ở mỗi lần mở file: người dùng thêm một UDL rồi mở
    /// lại app là đủ, và quét đĩa trên đường mở file thì mọi lần ⌘O đều trả giá.
    var userLanguages: [UserDefinedLanguage] = []

    var markdownPreview: MarkdownPreview?
    /// Cửa sổ xem trước Markdown đang hiện tài liệu NÀO.
    ///
    /// Cần vì preview là một CỬA SỔ RIÊNG, không phải khung đè lên vùng soạn thảo: nó sống qua
    /// mọi lần đổi tab. Không nhớ chủ của nó thì mở preview cho tệp A rồi sang tab B sẽ làm
    /// thanh trạng thái của B nói "đang ở chế độ View" — bài kiểm bắt được đúng chuyện đó.
    private var markdownPreviewDocumentID: String?
    var regexTesterPanel: RegexTesterPanel?

    /// Bộ theo dõi file đang chạy Ở TAB ĐANG MỞ, hoặc `nil` (FR-DOC-309).
    ///
    /// Trước đây nó là một biến của CỬA SỔ, và mỗi dòng log mới của tab đang theo dõi rơi vào
    /// tab người dùng đang nhìn: `handleTailChange` nạp lại `editorDocument` — tức tài liệu
    /// ĐANG HIỆN — từ đĩa rồi đặt nó thành chỉ đọc. Đang gõ dở ở một tab khác thì phần chưa lưu
    /// biến mất, và không có thông báo nào. Xem `handleTailChange`.
    var tailWatcher: FileTailWatcher? {
        get { tabs[activeIndex].tailWatcher }
        set { tabs[activeIndex].tailWatcher = newValue }
    }

    /// Số hiệu cấp cho bộ theo dõi kế tiếp — chỉ tăng, không dùng lại.
    private var tailToken = 0

    /// Menu vừa dựng để bung ra. Chỉ có giá trị ở lượt chạy không người — xem `present(_:from:)`.
    private var lastPresentedMenu: NSMenu?

    /// Lịch sử sao chép của phiên làm việc (FR-CORE-017).
    ///
    /// Sống trong bộ nhớ, không ghi ra đĩa. Người dùng chép mật khẩu hay khoá API vào trình
    /// soạn thảo là chuyện thường; ghi lịch sử ấy xuống đĩa là biến một tiện ích nhỏ thành
    /// một chỗ rò rỉ mà không ai yêu cầu.
    var clipboardRing = ClipboardRing()

    /// Cắt khoảng trắng cuối dòng mỗi khi lưu (FR-CORE-008).
    ///
    /// MẶC ĐỊNH TẮT, và đó là lựa chọn có chủ ý: nó sửa những dòng người dùng không hề chạm
    /// tới, nên bật sẵn sẽ biến một lần lưu thành một diff hàng nghìn dòng trong kho mã của
    /// người khác.
    var trimsTrailingWhitespaceOnSave = false

    /// Ngăn xếp đường dẫn của những tab vừa đóng, mới nhất ở cuối (FR-DOC-312).
    ///
    /// Ngăn xếp chứ không phải một ô nhớ: đóng nhầm ba tab liên tiếp rồi bấm ⇧⌘T ba lần phải
    /// lấy lại đủ ba, theo thứ tự ngược. Chỉ giữ đường dẫn — nội dung đọc lại từ đĩa, và tab
    /// chưa lưu thì không vào đây vì nó thuộc về bản nháp tự động (FR-DOC-304).
    var closedTabPaths: [String] = []

    /// Bảng CSV — dựng khi người dùng chuyển sang Table view lần đầu (ADR-08 §2.10).
    lazy var csvTable: CSVTableView = {
        let view = CSVTableView()
        // Giấu NGAY trong hàm dựng, không đợi `attachCSVTable()`. Một view mới sinh ra có
        // `isHidden == false`, nên chỗ nào lỡ đọc trạng thái trước khi gắn sẽ nhận "đang hiện"
        // cho một panel còn chưa nằm trong cửa sổ.
        view.isHidden = true
        return view
    }()
    /// Khung xem ảnh / PDF / file nén — dựng khi người dùng mở tài liệu media lần đầu.
    ///
    /// Lười vì cùng lý do với `csvTable`, và ở đây lý do còn nặng hơn: khung PDF kéo theo
    /// PDFKit. Người chỉ soạn văn bản không phải trả giá cho nó (ADR-14).
    lazy var mediaViewer: MediaViewerView = {
        let view = MediaViewerView()
        view.isHidden = true
        return view
    }()

    private let tabBar = TabBarView()
    private var columnEditorPanel: ColumnEditorPanel?
    /// Sheet duyệt cụm trùng lặp mờ (FR-CLN-004); giữ lại kẻo nó biến mất cùng lúc với biến cục bộ.
    private var fuzzyDedupSheet: CSVFuzzyDedupSheet?
    /// Chunk của lượt xem trước gần nhất (FR-KNW-903) — nút «Xuất JSONL» dùng lại chính nó,
    /// không cắt lần thứ hai: cắt lại có thể ra kết quả khác nếu tài liệu vừa đổi, và khi ấy tệp
    /// xuất ra không khớp thứ người dùng vừa nhìn.
    private var lastChunks: [Chunker.Chunk] = []
    private var knowledgeConvertPairs: [(KnowledgeConvert.Format, KnowledgeConvert.Format)] = []
    private var pendingConvert: (String, KnowledgeConvert.Format, KnowledgeConvert.Format)?
    private(set) var lastEntityReport: EntityMarker.Report?
    /// Nhật ký của lượt chạy script gần nhất — bài tự kiểm đọc TOÀN BỘ, còn banner chỉ hiện
    /// ba dòng đầu. Không có nó thì bài kiểm chỉ soi được phần đã bị cắt.
    private(set) var scriptLogForSelfTest: [String] = []
    private(set) var lastGraphDiagnostics: [GraphGrammars.Diagnostic] = []
    private(set) var lastSchemaDiagnostics: [JSONSchemaCheck.Diagnostic] = []
    private(set) var lastMiningReport: TextMining.Report?
    /// `internal` chứ không `private`: bài tự kiểm bấm vào chính các mục trên thanh này,
    /// và bấm qua một cửa riêng thì nó không còn kiểm cái người dùng chạm tới.
    let statusBar = StatusBarView()
    /// Khung chung của mọi tài liệu, ngay dưới thanh tab — xem `DocumentToolbar`.
    let documentToolbar = DocumentToolbar()
    /// Dải thông báo trên cùng — dựng khi có thông báo đầu tiên.
    private lazy var banner = BannerView()
    private var bannerHeight: NSLayoutConstraint!
    /// Bảng tìm/thay — dựng khi mở Tìm lần đầu.
    private lazy var findPanel: FindPanelView = {
        let view = FindPanelView()
        view.isHidden = true
        return view
    }()
    private var findPanelHeight: NSLayoutConstraint!
    /// Bảng kết quả tìm trong nhiều file — dựng khi chạy lần đầu.
    private lazy var resultsView: SearchResultsView = {
        let view = SearchResultsView()
        view.isHidden = true
        return view
    }()
    private var resultsHeight: NSLayoutConstraint!
    /// Token của lần tìm trong thư mục đang chạy — nút Hủy và lần tìm mới đều dùng tới.
    private var searchToken: CancelToken?

    /// Các lượt tìm trong thư mục của phiên này, mới nhất đứng đầu — FR-SRCH-105.
    ///
    /// Giữ trong BỘ NHỚ, không ghi ra đĩa: kết quả tìm mang theo nội dung dòng của tệp người
    /// dùng, và đó là cùng loại dữ liệu mà lịch sử clipboard đã cố ý không ghi xuống.
    private var searchHistory: [(pattern: String, summary: FindInFiles.Summary)] = []
    /// Lượt đang hiện trong panel.
    private var searchHistoryIndex = 0
    /// Trần lịch sử. Mỗi lượt giữ cả nội dung dòng của mọi kết quả, nên nó tốn bộ nhớ thật.
    private static let searchHistoryLimit = 10
    /// Ngữ cảnh của bản xem trước Replace in Files đang chờ xác nhận.
    private var pendingReplacement: (root: String, query: FindPanelView.Query, filters: String)?
    /// Cầu nối tới lệnh `geditor`; do `AppDelegate` gắn vào sau khi lắng nghe thành công.
    weak var cliBridge: CLIBridgeServer?

    /// Kết quả của lần tìm gần nhất, theo offset BYTE. Giữ lại để "Kết quả kế/trước" không
    /// phải khớp lại cả tài liệu mỗi lần nhấn ⌘G.
    private var matches: [SearchMatch] = []
    private var currentMatch: Int = -1

    /// Nguồn sự thật của cửa sổ. `NSTextView` chỉ là bản chiếu của nó.
    /// Một tab: tài liệu CỘNG trạng thái xem của riêng nó (FR-DOC-301).
    ///
    /// Vị trí con trỏ và dấu dòng thuộc về TAB chứ không thuộc về tài liệu: chuyển qua tab
    /// khác rồi quay lại mà con trỏ nhảy về đầu file là mất chỗ đang làm.
    struct EditorTab {
        var document: Document
        var caretOffset = 0
        var marks = LineMarkBook()
        var isPinned = false
        var colorIndex: Int?
        /// Chế độ CSV người dùng bật/tắt TAY cho riêng tab này (FR-CSV-401/402).
        ///
        /// `nil` = tự nhận diện theo đuôi file. Ở đây chứ không ở controller: một cửa sổ mở
        /// nhiều tab, mà "tệp này là bảng" là tính chất của TỆP.
        var csvModeOverride: Bool?
        /// Bộ theo dõi `tail -f` đang chạy cho riêng tab này (FR-DOC-309).
        ///
        /// Cùng lý do với `csvModeOverride`, nhưng hậu quả nặng hơn hẳn: xem
        /// `handleTailChange`.
        var tailWatcher: FileTailWatcher?
        /// Số hiệu của bộ theo dõi ấy — thứ lời gọi ngược mang theo để tìm đúng tab này.
        var tailToken: Int?
        /// Dấu phân tách người dùng CHỌN TAY, đè lên phép đoán theo nội dung (FR-CSV-401).
        var csvDialectOverride: CSVDialect?
        /// Ngôn ngữ tô màu người dùng CHỌN TAY, đè lên phép đoán theo đuôi tệp (FR-FMT-501).
        ///
        /// Ba trạng thái, không hai: «chưa chọn gì» khác hẳn «chọn Văn bản thuần». Viết bằng
        /// `SyntaxLanguage??` thì đúng kiểu nhưng chỗ đọc nào cũng phải nhớ tầng optional nào
        /// mang nghĩa gì.
        var languageChoice = LanguageChoice.auto
    }

    /// Ngôn ngữ tô màu của một tab đến từ đâu.
    enum LanguageChoice: Equatable {
        /// Theo đuôi tệp — mặc định.
        case auto
        /// Người dùng tắt hẳn tô màu.
        case plain
        /// Người dùng chỉ định.
        case language(SyntaxLanguage)
    }

    private var tabs: [EditorTab] = [EditorTab(document: .untitled())]

    /// Cửa sổ này vừa đóng — `WindowManager` gỡ nó khỏi sổ đăng ký (FR-DOC-302).
    var onWindowClosed: (() -> Void)?

    /// Tab đang mở Ở PANE ĐANG HOẠT ĐỘNG.
    private var activeIndex: Int {
        get { Swift.min(paneTabIndices[activePaneIndex], Swift.max(tabs.count - 1, 0)) }
        set { paneTabIndices[activePaneIndex] = Swift.min(Swift.max(newValue, 0), Swift.max(tabs.count - 1, 0)) }
    }

    /// Tài liệu của tab đang mở.
    ///
    /// Là thuộc tính TÍNH TOÁN nên gần trăm chỗ gọi cũ không phải sửa một dòng nào khi thêm
    /// tab — và quan trọng hơn, không có chỗ nào lỡ giữ lại tài liệu của tab cũ.
    private(set) var editorDocument: Document {
        get { tabs[activeIndex].document }
        set { tabs[activeIndex].document = newValue }
    }

    /// Chu kỳ autosave bản nháp (FR-DOC-304). TC-DOC-01 cho phép mất tối đa MỘT chu kỳ,
    /// nên đây trực tiếp là mức mất mát tối đa khi bị `kill -9`.
    private static let autosaveInterval: TimeInterval = 20
    private var autosaveTimer: Timer?

    /// Chặn vòng lặp: cập nhật view từ buffer sẽ làm view báo "đã đổi" ngược lại.
    private var isSyncingFromBuffer = false

    /// Dòng đang được đánh dấu ở tab hiện tại (FR-SRCH-107).
    /// Chín tập đánh dấu của tab đang mở (FR-SRCH-107).
    ///
    /// Ghi vào đây là ĐỒNG BỘ luôn xuống khung soạn thảo: trước đây phần dấu chỉ sống trong
    /// controller nên không có gì hiện ra, và mọi thao tác đánh dấu trông như không chạy.
    private var marks: LineMarkBook {
        get { tabs[activeIndex].marks }
        set {
            tabs[activeIndex].marks = newValue
            editorView.lineMarks = newValue
        }
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        // Thanh tab đã hiện tên file; để thêm tiêu đề cửa sổ thì chữ chồng lên tab đầu tiên.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // Cửa sổ KHÔNG tự dời được; việc dời do thanh tab quyết định từng cú nhấn.
        //
        // Cửa sổ dùng `.fullSizeContentView` nên thanh tab nằm đúng vùng macOS dành để kéo cửa
        // sổ, và cú kéo ấy nuốt luôn sự kiện chuột trước khi thanh tab kịp làm gì — kéo tab thì
        // cửa sổ chạy ra ngoài màn hình còn thứ tự tab không đổi. Xem `TabBarView.mouseDown`:
        // nhấn trúng tab thì đổi chỗ tab, nhấn chỗ trống thì gọi `performDrag` để dời cửa sổ.
        window.isMovable = false
        StartupProbe.mark("windowCreated")
        // KHÔNG đặt `setFrameAutosaveName`: nhiều cửa sổ dùng chung một tên sẽ chồng khít lên
        // nhau và ghi đè khung của nhau ở mỗi lần dời. Khung của TỪNG cửa sổ do phiên làm việc
        // giữ (`SessionWindow.frame`) — đúng chỗ nó thuộc về, và khôi phục được cả vị trí.
        self.init(window: window)
        // Mốc này đo phần KHỞI TẠO THUỘC TÍNH của controller: `self.init` chạy chúng, và
        // chúng dựng view thật (hai khung soạn thảo, thanh tab, thanh trạng thái).
        StartupProbe.mark("controllerProps")
        window.delegate = self
        buildContent()
        loadDocument(.untitled())
        startAutosave()
    }

    deinit { autosaveTimer?.invalidate() }

    // MARK: - Cột dọc của cửa sổ (ADR-08 §2.10)
    //
    // Cửa sổ là MỘT CỘT xếp chồng: thanh tab, banner, hàng giữa, bốn panel, thanh trạng thái.
    // Trước đây cả tám tầng đều nằm sẵn trong cây view ngay lúc khởi động, sáu tầng trong số
    // đó ẩn với chiều cao 0. Ẩn không cứu được gì: lần giải Auto Layout đầu tiên vẫn phải đi
    // hết cây con bên trong mỗi panel, và số đo cho thấy nó tốn ~96 ms trong khi cùng phép
    // giải ấy với cây chỉ gồm ba tầng luôn hiện tốn 7 ms.
    //
    // Nên panel chỉ vào cột khi người dùng mở nó lần đầu. Ai không bao giờ mở Bàn làm sạch thì
    // không bao giờ trả tiền dựng nó.
    //
    // Panel đã vào thì Ở LẠI, kể cả khi bị giấu đi. Gỡ ra rồi gắn lại là bắt trả phí bố cục
    // mỗi lần bật/tắt panel — đúng thứ vừa gỡ bỏ, chỉ là dời sang chỗ khó chịu hơn.

    /// Thứ tự các tầng từ trên xuống. Số nhỏ nằm trên.
    private enum Layer: Int, CaseIterable {
        case tabBar, docBar, banner, middle, results, validation, quality, chart, anomaly, correlation, forecast, groupMining, association, clean, jsonPath, jsonl, retrieval, sql, eide, find, status
    }

    /// Những tầng đã có mặt trong cột, giữ đúng thứ tự của `Layer`.
    private var attachedLayers: [(layer: Layer, view: NSView)] = []

    /// Tầng ấy đã dựng chưa — hỏi được mà KHÔNG chạm vào panel.
    ///
    /// Quan trọng hơn vẻ ngoài của nó: `!cleanPanel.isHidden` là một phép ĐỌC, nhưng với một
    /// `lazy var` thì đọc cũng là dựng. Vài vị từ kiểu "panel đang hiện không" chạy ngay lúc
    /// khởi động, và chúng sẽ dựng đúng những panel mà cả việc này sinh ra để đừng dựng.
    private func isAttached(_ layer: Layer) -> Bool {
        attachedLayers.contains { $0.layer == layer }
    }

    /// Hai panel không thuộc cột dọc nên không có `Layer`.
    private var sidebarAttached = false
    private var csvTableAttached = false
    private var structureTreeAttached = false

    /// Chế độ View dạng cây cho JSON · XML · YAML.
    lazy var structureTree = StructureTreeView()
    /// Chế độ View của tệp Office — trang do sản phẩm tự dựng, xem `OfficeDocumentView`.
    lazy var officePreview = OfficeDocumentView()
    private var officePreviewAttached = false
    private var mediaViewerAttached = false

    /// Tên những tầng đang có trong cửa sổ.
    ///
    /// Có mặt để canh việc dựng lười: nếu một ngày nào đó có mã chạm vào `cleanPanel` ngay lúc
    /// khởi động, panel ấy sẽ hiện ra ở đây và bài tự kiểm đỏ. Không có phép canh này thì việc
    /// hỏng chỉ biểu hiện thành "app chậm đi mươi mili-giây", tức là không ai thấy.
    var attachedLayerNamesForSelfTest: [String] {
        attachedLayers.map { "\($0.layer)" }
            + (sidebarAttached ? ["sidebar"] : [])
            + (csvTableAttached ? ["csvTable"] : [])
            + (mediaViewerAttached ? ["mediaViewer"] : [])
    }

    /// Ràng buộc nối các tầng, dựng lại mỗi lần có tầng mới vào.
    private var columnChain: [NSLayoutConstraint] = []

    /// Đưa một tầng vào cột nếu nó chưa ở đó.
    ///
    /// Trả `true` nếu lần này mới gắn — chỗ gọi dùng nó để tạo ràng buộc chiều cao đúng một
    /// lần, thay vì tạo lại mỗi lần mở panel.
    @discardableResult
    private func attach(_ view: NSView, as layer: Layer) -> Bool {
        guard !isAttached(layer) else { return false }
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        attachedLayers.append((layer, view))
        attachedLayers.sort { $0.layer.rawValue < $1.layer.rawValue }
        rebuildColumn()
        return true
    }

    /// Nối lại cột từ trên xuống dưới theo đúng những tầng đang có mặt.
    ///
    /// Dựng lại TOÀN BỘ chuỗi chứ không vá chỗ chèn: một tầng mới xen vào giữa làm hai ràng
    /// buộc cũ sai, và việc tìm đúng hai cái ấy để gỡ là chỗ dễ sót. Chuỗi này nhiều nhất tám
    /// tầng nên dựng lại chẳng tốn gì.
    private func rebuildColumn() {
        NSLayoutConstraint.deactivate(columnChain)
        columnChain = []
        var previous = container.topAnchor
        for (_, view) in attachedLayers {
            columnChain.append(view.topAnchor.constraint(equalTo: previous))
            columnChain.append(view.leadingAnchor.constraint(equalTo: container.leadingAnchor))
            columnChain.append(view.trailingAnchor.constraint(equalTo: container.trailingAnchor))
            previous = view.bottomAnchor
        }
        columnChain.append(previous.constraint(equalTo: container.bottomAnchor))
        NSLayoutConstraint.activate(columnChain)
    }

    // MARK: - Chiều cao panel: theo cửa sổ, và kéo được

    /// Ràng buộc chiều cao của từng panel, để thanh kéo tìm lại được.
    private var panelHeightConstraints: [Layer: NSLayoutConstraint] = [:]
    /// Chiều cao tối thiểu từng panel tự khai — sàn khi kéo, và sàn khi tính theo tỉ lệ.
    private var panelMinimumHeights: [Layer: CGFloat] = [:]

    /// Panel mở ra cao bao nhiêu.
    ///
    /// Ba nguồn, theo thứ tự:
    ///
    /// 1. **Người dùng đã kéo** → dùng đúng con số ấy. Đã chọn rồi thì đừng chọn lại giúp họ.
    /// 2. **Chưa kéo** → một TỈ LỆ của cửa sổ, không phải hằng số cứng. Đây là chỗ bố cục cũ
    ///    sai: 220 pt là con số hợp lý trên cửa sổ 720 pt và lố bịch trên cửa sổ 1400 pt, mà
    ///    mã thì không có cách nào biết mình đang ở cái nào.
    /// 3. Và **không bao giờ nhỏ hơn** chiều cao tối thiểu panel tự khai, cũng không quá nửa
    ///    cửa sổ — panel là thứ phụ trợ, nó không được nuốt chỗ của chính văn bản.
    private func panelOpenHeight(_ layer: Layer) -> CGFloat {
        let minimum = panelMinimumHeights[layer] ?? 160
        let available = panelAvailableHeight

        if let remembered = settings.panelHeights["\(layer)"] {
            // Trần NỚI cho con số người dùng tự kéo, không phải trần mặc định 0,6.
            //
            // Dùng chung một trần thì cú kéo tới 0,75 bị âm thầm bóp về 0,6 ngay lần đóng-mở
            // panel kế tiếp, và người dùng không có cách nào giữ lựa chọn của mình — thanh kéo
            // cho họ một con số rồi lấy lại sau lưng họ.
            return Swift.min(Swift.max(CGFloat(remembered), minimum), panelCeiling(layer))
        }
        return Swift.min(Swift.max(minimum, available * 0.32),
                         Swift.min(Swift.max(minimum, available * 0.6), panelCeiling(layer)))
    }

    /// Panel cao nhất được bao nhiêu. Hai trần, lấy cái chặt hơn.
    ///
    /// - **`0,6 × cửa sổ`** là lựa chọn sản phẩm: panel là thứ phụ trợ, chiếm quá 60% cột thì
    ///   vùng soạn thảo không còn đọc được.
    /// - **`cửa sổ − chỗ mọi thứ khác cần`** là ràng buộc vật lý, và không có nó thì cửa sổ tự
    ///   phồng. `rebuildColumn()` xâu cả cột thành một chuỗi bắt buộc khớp đúng chiều cao khung,
    ///   nên khi tổng vượt quá cửa sổ, AppKit lấy cỡ vừa vặn của `contentView` làm cỡ TỐI THIỂU
    ///   của cửa sổ rồi phóng to cửa sổ cho vừa. Đo được: kéo panel kết quả trên khung 1292 pt
    ///   làm cửa sổ nhảy lên 1951.
    ///
    /// # `container.fittingSize` đọc đúng — nhưng chỉ khi ràng buộc chiều cao BẮT BUỘC
    ///
    /// Đây là chỗ dễ mất buổi chiều, nên viết ra: cùng một dòng `fittingSize` ấy từng cho số
    /// rác, vì lúc thử nó tôi đang để ràng buộc ở ưu tiên 999. Panel ĐÓNG có ràng buộc
    /// `height == 0`; ở 999 nó thua chiều cao nội tại (bắt buộc) của đám nút và nhãn bên trong,
    /// nên mười bốn panel đóng mỗi cái khai vài trăm điểm và trần tụt xuống sát sàn. Ở mức bắt
    /// buộc thì `height == 0` thắng, panel đóng đóng góp đúng 0, và hiệu số ra đúng.
    ///
    /// Tức là ưu tiên ràng buộc và phép tính trần KHÔNG độc lập nhau. Đổi cái này phải đo lại
    /// cái kia.
    ///
    /// # Ba cách tính khác đã thử và bỏ
    ///
    /// Ghi lại vì cả ba đều chạy được, và hai trong ba trông như đã sửa xong:
    ///
    /// 1. Cộng `frame.height` các tầng khác. Panel đang ĐÓNG có `frame` bằng chiều cao lần cuối
    ///    nó mở, nên mười ba panel đóng khai khống 1400 pt trên cửa sổ 1698 pt: trần tụt xuống
    ///    sàn và mọi panel mở ra đúng chiều cao tối thiểu.
    /// 2. Đọc hằng số ràng buộc thay cho `frame`, chừa 120 pt cho vùng soạn thảo. Con số 120 là
    ///    đoán từ `splitView(_:constrainMinCoordinate:…)`; hỏi `fittingSize` thì hàng giữa cần
    ///    **333**. Cửa sổ vẫn phồng, chỉ phồng ít hơn — tức trông như đã sửa.
    /// 3. Thay 120 bằng 333 đo được, vẫn cộng tay từng tầng. Còn hụt 113 pt nữa, và tôi đã sắp
    ///    đi tìm số hạng thứ ba để vá.
    ///
    /// Cái chung của cả ba: một tổng cộng tay, mỗi số hạng một nguồn, và không cách nào nhìn mã
    /// mà biết đã đủ số hạng chưa. Hiệu với `fittingSize` thì không có số hạng nào để quên —
    /// thêm một tầng vào cột mai sau, nó tự tính vào.
    private func panelCeiling(_ layer: Layer) -> CGFloat {
        let minimum = panelMinimumHeights[layer] ?? 160
        let current = panelHeightConstraints[layer]?.constant ?? 0
        let others = container.fittingSize.height - current
        return Swift.max(minimum, Swift.min(panelAvailableHeight * 0.6,
                                            panelAvailableHeight - others))
    }

    /// Chiều cao dùng làm mốc cho mọi phép tính tỉ lệ.
    ///
    /// Hỏi CỬA SỔ chứ không hỏi `container.bounds`. Hai thứ này bằng nhau ở trạng thái nghỉ,
    /// nhưng `bounds` là kết quả của lượt bố trí GẦN NHẤT: gọi ngay sau khi cửa sổ đổi cỡ, hay
    /// ngay sau `attach()` — tức đúng lúc mở panel — thì nó còn trả về con số của lượt trước.
    ///
    /// Đo được: mở panel trên cửa sổ 1206 pt, `bounds` khai 1047, và panel ra 335 pt thay vì
    /// 386. Sai mười lăm phần trăm, luôn theo cùng một chiều, và không bao giờ đủ sai để ai đó
    /// nhìn màn hình mà nghi. `contentLayoutRect` suy thẳng từ khung cửa sổ nên không có độ trễ
    /// ấy.
    ///
    /// Mốc dự phòng 720 pt cho lúc chưa có cửa sổ: nhân tỉ lệ với 0 sẽ ra một panel cao bằng
    /// đúng chiều cao tối thiểu ở MỌI cỡ màn hình — vừa đúng thứ việc này sinh ra để bỏ.
    private var panelAvailableHeight: CGFloat {
        if let height = window?.contentLayoutRect.height, height > 100 { return height }
        return container.bounds.height > 100 ? container.bounds.height : 720
    }

    /// Tính lại chiều cao mọi panel ĐANG MỞ theo cỡ khung hiện tại.
    ///
    /// Chỉ đụng panel đang mở: panel đóng có hằng số 0, và đặt lại nó là mở toang một panel mà
    /// người dùng đã tắt.
    ///
    /// Panel người dùng đã kéo cũng đi qua đây, nhưng `panelOpenHeight` trả về con số họ đã
    /// chọn (chỉ kẹp lại khi cửa sổ co nhỏ tới mức không chứa nổi) — và `settings` KHÔNG bị ghi
    /// đè, nên phóng cửa sổ to lại là lựa chọn cũ quay về nguyên vẹn.
    ///
    /// **Chốt chống tự gọi lại.** Hàm này chạy từ `windowDidResize`, và nó đặt chiều cao panel —
    /// thứ có thể làm cửa sổ đổi cỡ, tức gọi lại chính nó. Vòng ấy đã chạy thật khi trần còn
    /// tính sai: mỗi vòng panel to thêm một ít, cửa sổ nở theo, và bộ tự kiểm kết thúc với một
    /// cửa sổ cao **336.020 pt**. Không treo, không đỏ, không ai thấy — mọi bài vẫn xanh dưới
    /// một cửa sổ cao gấp ba trăm lần màn hình.
    ///
    /// `panelCeiling` nay chừa đủ chỗ nên vòng lặp không còn nguồn nuôi, và chốt này là thứ giữ
    /// cho một sai số nhỏ ở phép trừ ấy về sau không leo thang thành như thế nữa.
    private func reflowPanelHeights() {
        guard !isReflowingPanels else { return }
        isReflowingPanels = true
        defer { isReflowingPanels = false }
        for (layer, constraint) in panelHeightConstraints where constraint.constant > 0 {
            constraint.constant = panelOpenHeight(layer)
        }
    }

    private var isReflowingPanels = false

    /// Dựng ràng buộc chiều cao cho một panel, kèm thanh kéo ở mép trên.
    ///
    /// Gom vào một chỗ thay vì lặp ở mười bốn `attach…Panel()`: thanh kéo, sàn, trần và phép
    /// ghi nhớ đều là cùng một luật, và mười bốn bản sao của một luật thì sớm muộn có bản lệch.
    private func makePanelHeight(
        _ view: NSView, _ layer: Layer, minimum: CGFloat
    ) -> NSLayoutConstraint {
        panelMinimumHeights[layer] = minimum
        let constraint = view.heightAnchor.constraint(equalToConstant: 0)
        // Ràng buộc này để ưu tiên BẮT BUỘC, và lựa chọn ấy có giá — đọc cùng `panelCeiling`.
        //
        // Bắt buộc nghĩa là chiều cao đặt sao thì hiện đúng vậy. Đổi lại, nó tham gia vào cỡ
        // tối thiểu của cửa sổ: `rebuildColumn()` xâu cả cột thành chuỗi bắt buộc khớp đúng
        // chiều cao khung, nên tổng vượt quá cửa sổ là AppKit PHÓNG TO CỬA SỔ cho vừa. Vì thế
        // `panelCeiling` phải chừa đủ chỗ — hai chỗ ấy phụ thuộc nhau, đổi một phải đo lại hai.
        //
        // **Đã thử hạ ưu tiên, và cả hai mức đều hỏng.** Ghi ra để không ai thử lại:
        //
        // - **999**: không đổi gì. `fittingSize` — thứ AppKit suy cỡ tối thiểu cửa sổ từ đó —
        //   tính mọi ràng buộc trên `fittingSizeCompression` (50), không riêng mức bắt buộc.
        // - **49** (dưới ngưỡng ấy): cửa sổ thôi phồng thật, nhưng chiều cao panel thành một
        //   ĐỀ NGHỊ mà không ai nghe. Đặt 320 pt, trên màn hình panel cao **28**. Hằng số vẫn
        //   đúng y như ta ghi, nên bài kiểm nào chỉ đọc hằng số vẫn xanh — đó là lý do bài kiểm
        //   panel kết quả so KHUNG THẬT chứ không so hằng số với chính nó.
        constraint.isActive = true
        panelHeightConstraints[layer] = constraint

        let handle = PanelResizeHandle()
        view.addSubview(handle)
        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: view.topAnchor),
            handle.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            handle.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            handle.heightAnchor.constraint(equalToConstant: PanelResizeHandle.thickness),
        ])
        handle.onDrag = { [weak self] delta in
            self?.resizePanel(layer, by: delta)
        }
        handle.onFinish = { [weak self] in
            guard let self, let height = self.panelHeightConstraints[layer]?.constant else { return }
            self.settings.panelHeights["\(layer)"] = Double(height)
            self.saveSettings()
        }
        panelHandles[layer] = handle
        return constraint
    }

    private var panelHandles: [Layer: PanelResizeHandle] = [:]

    /// Kéo panel cao thêm/thấp đi, kẹp trong khoảng cho phép.
    private func resizePanel(_ layer: Layer, by delta: CGFloat) {
        guard let constraint = panelHeightConstraints[layer], constraint.constant > 0 else {
            return
        }
        let minimum = panelMinimumHeights[layer] ?? 160
        // Trần rộng hơn lúc mở (`panelCeiling` chừa đúng phần cột đang dùng, thay vì 0,6 cửa
        // sổ): người dùng KÉO thì họ đang cố ý xin chỗ, và chặn họ ở mức mặc định là không cho
        // họ làm đúng việc thanh kéo sinh ra để làm. Vẫn phải có trần, nếu không vùng soạn thảo
        // biến mất hẳn và không có đường quay lại.
        constraint.constant = Swift.min(Swift.max(constraint.constant + delta, minimum),
                                        panelCeiling(layer))
    }

    /// Kéo panel trong bài tự kiểm — đi đúng đường mà chuột đi.
    func dragPanelForSelfTest(_ name: String, by delta: Double) -> Bool {
        guard let layer = Layer.allCases.first(where: { "\($0)" == name }),
              let handle = panelHandles[layer] else { return false }
        handle.dragForSelfTest(by: CGFloat(delta))
        return true
    }

    /// Chiều cao vùng nội dung cửa sổ — mốc để bài kiểm so tỉ lệ panel.
    ///
    /// Trả về ĐÚNG đại lượng sản phẩm dùng (`panelAvailableHeight`), không phải một phép đo
    /// gần đúng khác. Bài kiểm đo `container.bounds` còn mã tính theo cửa sổ là hai con số lệch
    /// nhau đúng lúc bố trí chưa kịp chạy — và bài kiểm khi ấy đỏ mà chẳng chỉ ra lỗi nào.
    var contentHeightForSelfTest: Double { Double(panelAvailableHeight) }

    /// Trần chiều cao của một panel — bài kiểm cần nó để biết luật 0,32 có bị trần cắt không.
    ///
    /// Không có nó thì bài kiểm phải ĐOÁN, và nó đã đoán sai ngay lần đầu có thêm một tầng cố
    /// định trong cột: 0,32 × khung ra 220 pt trong khi trần chỉ còn 218.
    func panelCeilingForSelfTest(_ name: String) -> Double? {
        guard let layer = Layer.allCases.first(where: { String(describing: $0) == name })
        else { return nil }
        return Double(panelCeiling(layer))
    }

    /// Bảng Cài đặt, dựng nếu chưa có — cho bài kiểm bấm vào nó như người dùng.
    func preferencesPanelForSelfTest() -> PreferencesPanel {
        showPreferences(nil)
        return preferencesPanel!
    }

    /// Mã ngôn ngữ mà cấu hình ĐANG giữ. Bài kiểm hỏi cái này chứ không hỏi bộ chọn: câu hỏi là
    /// "chọn xong thì ghi được đúng chưa", và hỏi lại chính bộ chọn thì nó tự xác nhận nó.
    var settingsLanguageForSelfTest: String { settings.language }

    /// Chiều viết của khung và của vùng soạn thảo, cho bài kiểm — `"phai"` hoặc `"trai"`.
    func layoutDirectionForSelfTest() -> (khung: String, soanThao: String) {
        func ten(_ view: NSView) -> String {
            view.userInterfaceLayoutDirection == .rightToLeft ? "phai" : "trai"
        }
        return (ten(container), ten(editorView))
    }

    /// Thu mọi panel về 0 pt, cho bài kiểm bắt đầu từ một cột trống.
    ///
    /// Trần chiều cao của một panel phụ thuộc vào những panel KHÁC đang mở (xem `panelCeiling`),
    /// nên một bài kiểm tỉ lệ sẽ ra con số khác nhau tuỳ bài nào chạy trước nó và để lại cái gì.
    /// Đã xảy ra: panel mở ra 245 pt thay vì 329, và lời tố "không theo tỉ lệ" chỉ vào sản phẩm
    /// trong khi lỗi nằm ở thứ tự chạy.
    func collapseAllPanelsForSelfTest() {
        for constraint in panelHeightConstraints.values { constraint.constant = 0 }
        settleForSelfTest()
    }

    /// Đổi cỡ cửa sổ rồi bố trí lại ngay, cho bài kiểm.
    ///
    /// Đi qua `setFrame` thật để `windowDidResize` được gọi đúng như khi người dùng kéo góc
    /// cửa sổ — gọi thẳng `reflowPanelHeights()` sẽ kiểm được phép tính mà bỏ qua đúng câu hỏi
    /// đang cần trả lời: móc đổi cỡ có được nối vào hay không.
    /// Trả về phần chiều cao THẬT SỰ nở ra, không phải phần đã xin.
    ///
    /// Cửa sổ không vượt quá màn hình, nên xin 400 pt có khi chỉ được 298. Bài kiểm nào hoàn
    /// nguyên bằng cách trừ đúng con số đã xin sẽ làm cửa sổ TEO đi sau mỗi lượt — và bài chạy
    /// sau đó đỏ vì hết chỗ, một lý do không dính gì tới thứ nó kiểm. Đã xảy ra đúng vậy.
    @discardableResult
    func resizeWindowForSelfTest(byHeight delta: Double) -> Double {
        guard let window else { return 0 }
        let before = window.contentLayoutRect.height
        var frame = window.frame
        frame.size.height += CGFloat(delta)
        window.setFrame(frame, display: true)
        window.layoutIfNeeded()
        return Double(window.contentLayoutRect.height - before)
    }

    /// Chiều cao THẬT của panel trên màn hình, không phải hằng số ta đặt.
    ///
    /// Hai con số này khác nhau đúng ở kiểu hỏng đáng sợ nhất của cách làm hiện tại: ràng buộc
    /// chiều cao panel để ưu tiên thấp hơn `fittingSizeCompression`, nên nó là ĐỀ NGHỊ. Hạ nhầm
    /// xuống quá thấp, hay thêm một ràng buộc mạnh hơn ở chỗ khác, thì hằng số vẫn đúng y như
    /// ta đặt còn panel trên màn hình thì bẹp — và bài kiểm nào chỉ đọc hằng số vẫn xanh.
    func panelFrameHeightForSelfTest(_ name: String) -> Double? {
        guard let layer = Layer.allCases.first(where: { "\($0)" == name }),
              let view = attachedLayers.first(where: { $0.layer == layer })?.view
        else { return nil }
        return Double(view.frame.height)
    }

    func panelHeightForSelfTest(_ name: String) -> Double? {
        guard let layer = Layer.allCases.first(where: { "\($0)" == name }) else { return nil }
        return panelHeightConstraints[layer].map { Double($0.constant) }
    }

    private func buildContent() {
        StartupProbe.mark("buildContent.start")
        guard let window else { return }

        for pane in paneViews { configure(pane) }

        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.onSegmentClick = { [weak self] segment in
            self?.handleStatusBarClick(segment)
        }

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.onSelect = { [weak self] in self?.activateTab($0) }
        tabBar.onClose = { [weak self] in self?.closeTab(at: $0) }
        tabBar.onContextMenu = { [weak self] index, point in self?.showTabMenu(index, at: point) }
        tabBar.onReorder = { [weak self] from, to in self?.moveTab(from: from, to: to) }
        tabBar.onDropOnScreen = { [weak self] index, point in self?.dropTab(index, atScreenPoint: point) }

        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.dividerStyle = .thin
        splitView.isVertical = true                       // chia DỌC = hai cột, mặc định
        splitView.addArrangedSubview(paneViews[0])

        middleRow.translatesAutoresizingMaskIntoConstraints = false
        middleRow.addSubview(splitView)
        // Không có cây thư mục thì vùng soạn thảo ăn hết bề ngang. Ràng buộc này bị THAY khi
        // sidebar vào cửa sổ — xem `attachSidebar()`.
        splitViewLeading = splitView.leadingAnchor.constraint(equalTo: middleRow.leadingAnchor)
        splitViewTrailing = splitView.trailingAnchor.constraint(equalTo: middleRow.trailingAnchor)

        completionPopup.onCommit = { [weak self] candidate in self?.insertCompletion(candidate) }

        documentToolbar.onSwitch = { [weak self] wantsView in
            guard let self else { return }
            // Bấm vào nửa đang bật thì không làm gì: `toggleViewCode` là một CÔNG TẮC, nên gọi
            // nó ở đây sẽ tắt đúng chế độ người dùng vừa xác nhận là muốn giữ.
            guard wantsView != self.isAnyViewModeVisible else { return }
            self.toggleViewCode(nil)
        }

        attach(tabBar, as: .tabBar)
        attach(documentToolbar, as: .docBar)
        attach(middleRow, as: .middle)
        attach(statusBar, as: .status)

        NSLayoutConstraint.activate([
            tabBar.heightAnchor.constraint(equalToConstant: TabBarView.height),
            documentToolbar.heightAnchor.constraint(equalToConstant: DocumentToolbar.height),
            splitView.topAnchor.constraint(equalTo: middleRow.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: middleRow.bottomAnchor),
            splitViewLeading,
            splitViewTrailing,
        ])

        // KHUNG EIDE bọc ngoài trình soạn thảo — quyết định của chủ sản phẩm 14/09/2026:
        // GEditor và EIDE là MỘT sản phẩm, tên EIDE, và trình soạn thảo là màn "Mã nguồn".
        // Xem DEV-098.
        window.contentView = dungKhungEide(quanh: container)
        window.title = "EIDE"
    }

    // MARK: - Khung EIDE (DEV-098)

    /// Sidebar 21 màn của UXD-13 §2, với trình soạn thảo làm màn "Mã nguồn".
    ///
    /// ## Vì sao bọc thay vì dựng cửa sổ thứ hai
    ///
    /// Bản trước có hai cửa sổ: một của trình soạn thảo, một của EIDE. Người mở sản phẩm lên
    /// thấy trình soạn thảo, và EIDE là thứ phải đi tìm trong menu. Chủ sản phẩm chốt ngày
    /// 14/09: **một giao diện, tên EIDE**, và mockup UXD-13 §2 vốn đã vẽ đúng thế — "Mã nguồn"
    /// là màn số 11 trong sidebar, không phải chủ nhà.
    ///
    /// Bọc `container` thay vì bóc view soạn thảo ra: mọi ràng buộc, mọi panel, mọi đường
    /// `attach` của trình soạn thảo giữ nguyên chỗ đứng. Thứ duy nhất đổi là có một cột 220 px
    /// bên trái, và vùng còn lại đổi giữa *trình soạn thảo* với *màn EIDE đang chọn*.
    private func dungKhungEide(quanh soanThao: NSView) -> NSView {
        let goc = NSView()
        // Điều hướng gộp 5 NHÓM theo giai đoạn công việc (THIET-KE-UI sheet 2), thay danh sách
        // 22 mục phẳng theo thứ tự bảng UXD-13 §2. Thứ tự tài liệu không phải thứ tự làm việc:
        // "Dò board" từng đứng giữa "Mô phỏng" và "Log & serial", "Nhật ký" ở cuối cùng.
        let dh = EideDieuHuong(frame: .zero)
        dh.onChon = { [weak self] tien in self?.chonManEide(tien: tien) }
        dieuHuongEide = dh
        // Mã nguồn là MỘT MÀN của EIDE (DEV-098), và nó nằm trong nhóm "MÃ & CHẠY".
        let cuon = dh
        cuon.translatesAutoresizingMaskIntoConstraints = false

        let vach = NSBox()
        vach.boxType = .separator
        vach.translatesAutoresizingMaskIntoConstraints = false

        soanThao.translatesAutoresizingMaskIntoConstraints = false

        goc.addSubview(cuon)
        goc.addSubview(vach)
        goc.addSubview(soanThao)

        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: goc.topAnchor),
            cuon.leadingAnchor.constraint(equalTo: goc.leadingAnchor),
            cuon.bottomAnchor.constraint(equalTo: goc.bottomAnchor),
            cuon.widthAnchor.constraint(equalToConstant: 220),

            vach.leadingAnchor.constraint(equalTo: cuon.trailingAnchor),
            vach.topAnchor.constraint(equalTo: goc.topAnchor),
            vach.bottomAnchor.constraint(equalTo: goc.bottomAnchor),
            vach.widthAnchor.constraint(equalToConstant: 1),

            soanThao.leadingAnchor.constraint(equalTo: vach.trailingAnchor),
            soanThao.topAnchor.constraint(equalTo: goc.topAnchor),
            soanThao.trailingAnchor.constraint(equalTo: goc.trailingAnchor),
            soanThao.bottomAnchor.constraint(equalTo: goc.bottomAnchor),
        ])
        khungEideGoc = goc
        vungSoanThao = soanThao
        vachEide = vach

        DispatchQueue.main.async { [weak self] in
            // Mở ra ở màn "Mã nguồn": người dùng vừa mở một tệp, và đưa họ tới một màn khác là
            // làm mất chính thứ họ vừa bấm vào.
            self?.dieuHuongEide?.chon("Code")
        }
        return goc
    }

    /// Bề rộng cột cây. 240 pt vừa đủ cho `drivers/uart_stm32.c` ở tầng thứ hai không bị cắt —
    /// tên tệp bị cắt trong một cây là thứ buộc người dùng phải bấm vào mới biết mình bấm gì.
    /// Chuẩn bị màn "Mã nguồn": trỏ cây tệp vào dự án và hiện nó ra.
    ///
    /// ## Vì sao KHÔNG dựng một cây thứ hai
    ///
    /// Bản đầu của tôi thêm hẳn một cột `EideCayView` cạnh trình soạn thảo, đúng như mockup
    /// `Code.dc.html` vẽ. Ảnh chụp cho thấy ngay vấn đề: **hai cây cạnh nhau**, cùng nói về một
    /// thư mục — cây EIDE mới và cây tệp vốn có của trình soạn thảo. Đó đúng là "hai câu trả lời
    /// cho cùng một câu hỏi" mà chính ghi chú của tôi vừa cảnh báo.
    ///
    /// Cây vốn có lại tốt hơn cây tôi viết ở mọi mặt đo được: nạp TỪNG CẤP (một `node_modules`
    /// hai trăm nghìn tệp không làm treo), có ô lọc tìm tệp trong cả cây, có menu chuột phải
    /// (tạo, đổi tên, bỏ vào Thùng rác, hiện trong Finder), bấm đúp mở tệp. Thứ nó thiếu là
    /// `.eide/` — một thư mục ẩn nên bị luật "bỏ tên bắt đầu bằng dấu chấm" giấu đi.
    ///
    /// Nên: giữ một cây, dạy nó hiện `.eide/`. Ít mã hơn, và người dùng có một chỗ để nhìn.
    @MainActor
    func hienCayDuAn(_ hien: Bool) {
        guard hien, let duAn = AppDelegate.duAnMoSan() else { return }

        // Trỏ workspace vào thư mục dự án.
        //
        // Trước 15/09/2026 KHÔNG chỗ nào làm việc này: `openWorkspace(_:)` có sẵn và không một
        // lời gọi nào trong `AppDelegate` hay `EIDEKit` chạm tới nó. Hệ quả là mở dự án bằng bất
        // kỳ đường nào thì cây tệp vẫn nói "Chưa mở thư mục nào", tìm-trong-thư-mục không có gì
        // để tìm, và màn Mã nguồn chỉ có thể là một bộ đệm trống tên "Chưa đặt tên".
        if cayDangTro != duAn || workspaceRoot != duAn {
            // `.eide/` hiện RIÊNG trong cây — chủ sản phẩm chốt 15/09. Nó không phải mã nguồn,
            // nhưng giấu nó đi thì store, sổ cái và chính sách — bằng chứng của cả luận điểm đề
            // án — biến mất khỏi tầm mắt người dùng.
            workspaceView.luonHien = EideDuAn.kiem(duAn).loi == nil ? [".eide"] : []
            openWorkspace(duAn)
            cayDangTro = duAn
        }
        // Hiện cây ra. Vào màn Mã nguồn mà phải tự bấm ⌘0 mới thấy tệp thì màn ấy vẫn là một bộ
        // đệm trống với đa số người dùng — họ không biết có phím tắt.
        if !isSidebarVisible { toggleSidebar(nil) }
    }

    /// Mở một tệp từ cây vào trình soạn thảo.
    ///
    /// Tệp NHỊ PHÂN (store.sqlite, .elf, .hex) không mở ra như văn bản: một cửa sổ đầy ký tự rác
    /// không nói gì, và với `store.sqlite` thì nó còn mời người dùng sửa tay đúng cái tệp mà cả
    /// cơ chế niêm của POL-17 §3 dựng lên để phát hiện sửa tay.
    @MainActor
    func moTepTuCay(_ duong: String) {
        let duoi = (duong as NSString).pathExtension.lowercased()
        let nhiPhan: Set<String> = ["sqlite", "db", "elf", "hex", "bin", "o", "a", "so",
                                    "dylib", "png", "jpg", "pdf", "zip", "sig"]
        guard !nhiPhan.contains(duoi) else {
            let a = NSAlert()
            a.messageText = "Không mở được dưới dạng văn bản"
            a.informativeText = "`\((duong as NSString).lastPathComponent)` là tệp nhị phân. "
                + (duoi == "sqlite"
                   ? "Store đọc qua các màn Hộ chiếu, Bản đồ tri thức và Nhật ký — sửa tay vào "
                     + "đây sẽ làm lệch niêm store (POL-17 §3)."
                   : "Dùng màn chuyên đề tương ứng để xem nội dung.")
            a.runModal()
            return
        }
        openInNewTab(path: duong)
    }

    /// Có dựng được panel EIDE không — tức có chạy được `eide daemon` không.
    ///
    /// Đọc thuộc tính này DỰNG panel (nó `lazy`), nên đừng gọi ở đường khởi động. Nó có mặt để
    /// bên gọi hỏi được câu "mở màn EIDE bây giờ có ra gì không" mà KHÔNG phải chịu hộp thoại
    /// `runModal` của `chonManEide` — hộp thoại ấy đúng cho người đang ngồi trước máy và là một
    /// cú treo vĩnh viễn cho mọi tiến trình không có ai bấm.
    var coPanelEide: Bool { eidePanel != nil }

    /// Chọn một màn theo TIỀN TỐ, không theo chỉ số hàng.
    ///
    /// Bản cũ nhận `hang: Int` và tra `EideWindowController.manTrenSidebar[hang]`. Chỉ số hàng
    /// là thứ đổi mỗi lần thêm một màn hoặc một tiêu đề nhóm — và khi nó đổi, cú bấm vào "Mô
    /// phỏng" mở ra "Dò board" mà không ai báo gì. Tên màn thì không đổi.
    func chonManEide(tien: String) {
        guard let goc = khungEideGoc, let soanThao = vungSoanThao, let vach = vachEide else {
            return
        }
        // "Mã nguồn" là MỘT MÀN của EIDE (DEV-098) và nội dung của nó là **cây dự án + trình
        // soạn thảo** — mockup `Code.dc.html`, không phải một bộ đệm trống.
        if tien == "Code" {
            eidePanel?.isHidden = true
            soanThao.isHidden = false
            hienCayDuAn(true)
            return
        }
        // Màn chuyên đề: panel che cả vùng soạn thảo (kể cả cây tệp nằm trong đó), nên không
        // phải ẩn gì thêm. Gọi `hienCayDuAn(false)` ở đây từng có mặt và nó không làm gì —
        // một lời gọi không làm gì là một lời gọi người đọc sau phải tự chứng minh là vô hại.
        guard let p = eidePanel else {
            // Không tìm thấy `eide` — nói ra ngay tại chỗ người vừa bấm, và quay về Mã nguồn để
            // cửa sổ không đứng trắng.
            dieuHuongEide?.chon("Code")
            soanThao.isHidden = false
            let a = NSAlert()
            a.messageText = "Chưa chạy được EIDE"
            a.informativeText = "Không tìm thấy `eide`. Chạy `make setup` trong kho, hoặc đặt "
                + "EIDE_PYTHON trỏ tới python của venv."
            a.runModal()
            return
        }
        soanThao.isHidden = true
        if p.superview !== goc {
            p.translatesAutoresizingMaskIntoConstraints = false
            goc.addSubview(p)
            NSLayoutConstraint.activate([
                p.leadingAnchor.constraint(equalTo: vach.trailingAnchor),
                p.topAnchor.constraint(equalTo: goc.topAnchor),
                p.trailingAnchor.constraint(equalTo: goc.trailingAnchor),
                p.bottomAnchor.constraint(equalTo: goc.bottomAnchor),
            ])
        }
        p.isHidden = false
        p.moMan(tien)
    }

    // MARK: - Gắn từng panel khi người dùng mở nó lần đầu

    private func attachBanner() {
        guard attach(banner, as: .banner) else { return }
        bannerHeight = banner.heightAnchor.constraint(equalToConstant: 0)
        bannerHeight.isActive = true
    }

    private func attachResultsPanel() {
        guard attach(resultsView, as: .results) else { return }
        resultsView.onClose = { [weak self] in self?.hideResultsPanel() }
        resultsView.onCancel = { [weak self] in self?.cancelFindInFiles() }
        resultsView.onOpenHit = { [weak self] path, hit in self?.openHit(path: path, hit: hit) }
        resultsView.onExport = { [weak self] in self?.exportSearchResults() }
        resultsView.onSelectHistory = { [weak self] index in self?.showSearchHistoryEntry(index) }
        resultsView.onCommitReplacement = { [weak self] paths in
            self?.commitReplacement(selectedPaths: paths)
        }
        // Trần "nhiều nhất 40% chiều cao" từng là một ràng buộc BẮT BUỘC riêng ở đây. Nay trần
        // nằm trong `panelOpenHeight`/`resizePanel` cùng mười ba panel kia, và hai cái không
        // sống chung được: hằng số do thanh kéo đặt cũng bắt buộc, nên khi người dùng kéo quá
        // 40% thì Auto Layout có hai ràng buộc không cùng đúng được.
        //
        // Nó KHÔNG kẹp panel lại như người viết ràng buộc ấy tưởng. Đo được: kéo panel kết quả
        // trên khung cao 720 pt, hằng số thành 576, và Auto Layout gỡ mâu thuẫn bằng cách cho
        // `container` phồng lên 1440 — kéo một panel làm nở cả khung nội dung.
        resultsHeight = makePanelHeight(resultsView, .results, minimum: 180)
    }

    private func attachValidationPanel() {
        guard attach(validationPanel, as: .validation) else { return }
        validationPanel.onClose = { [weak self] in self?.hideValidationPanel() }
        validationPanel.onSelectIssue = { [weak self] issue in self?.revealIssue(issue) }
        validationHeight = makePanelHeight(validationPanel, .validation, minimum: CSVValidationPanel.height)
        validationHeight.isActive = true
    }

    private func attachCleanPanel() {
        guard attach(cleanPanel, as: .clean) else { return }
        cleanPanel.onClose = { [weak self] in self?.hideCleanPanel() }
        cleanPanel.onSelectFinding = { [weak self] finding in self?.revealFinding(finding) }
        cleanPanel.onAct = { [weak self] finding in self?.showCleanSheet(for: finding) }
        cleanPanel.onExportReport = { [weak self] in self?.exportCleanReport() }
        cleanPanel.onNeedProfile = { [weak self] in self?.runProfile() }
        cleanPanel.onSaveRecipe = { [weak self] in self?.saveRecipe() }
        cleanPanel.onSelectProfileColumn = { [weak self] entry in self?.revealOutlier(entry) }
        cleanHeight = makePanelHeight(cleanPanel, .clean, minimum: CSVCleanPanel.height)
        cleanHeight.isActive = true
    }

    private func attachJSONPathPanel() {
        guard attach(jsonPathPanel, as: .jsonPath) else { return }
        jsonPathPanel.onClose = { [weak self] in self?.hideJSONPathPanel() }
        jsonPathPanel.onQuery = { [weak self] query in self?.runJSONPathQuery(query) }
        jsonPathPanel.onSelect = { [weak self] match in self?.revealJSONPathMatch(match) }
        jsonPathPanel.onExport = { [weak self] matches in self?.exportJSONPathMatches(matches) }
        jsonPathHeight = makePanelHeight(jsonPathPanel, .jsonPath, minimum: JSONPathPanel.height)
        jsonPathHeight.isActive = true
    }

    private func attachJSONLPanel() {
        guard attach(jsonlPanel, as: .jsonl) else { return }
        jsonlPanel.onClose = { [weak self] in self?.hideJSONLPanel() }
        jsonlPanel.onSelectLine = { [weak self] line in self?.revealJSONLLine(line) }
        jsonlPanel.onCancelScan = { [weak self] in self?.jsonlCancelToken?.cancel() }
        jsonlPanel.onFilter = { [weak self] field, value in
            self?.runJSONLFilter(field: field, value: value)
        }
        jsonlHeight = makePanelHeight(jsonlPanel, .jsonl, minimum: JSONLPanel.height)
        jsonlHeight.isActive = true
    }

    // MARK: - EIDE (WI-021)

    /// Panel trợ lý nhúng EIDE — DEVIATIONS DEV-004 (thành phần trong app, không qua khung plugin).
    ///
    /// `lazy` là cố ý: dựng panel nghĩa là mở một tiến trình `eide daemon`, và người không dùng
    /// EIDE không nên phải trả giá ấy chỉ vì mở GEditor.
    lazy var eidePanel: EidePanel? = {
        // Mở KÈM dự án. `ctx.project_dir` của daemon quyết lúc nó khởi động, nên một panel dựng
        // không dự án sẽ hiện màn trống cho tới khi ai đó dựng lại nó — và trước 14/09/2026 thì
        // không có đường nào dựng lại (GIAM-SAT-UI §0.2).
        let duAn = AppDelegate.duAnMoSan()
        guard let c = EideDaemonLauncher.moClient(duAn: duAn) else { return nil }
        if let duAn { EideDuAn.nhoDaMo(duAn) }
        let p = EidePanel(client: c)
        p.datTenDuAn(duAn.map { ($0 as NSString).lastPathComponent })
        p.onChonDuAn = { [weak self] in self?.moMenuDuAn() }
        return p
    }()

    /// Menu dự án — bấm vào tên dự án trên thanh trên.
    ///
    /// Ba nhóm mục, theo đúng thứ tự người dùng cần: **dự án gần đây** (một cú bấm), **mở thư
    /// mục khác**, **tạo dự án mới**. Tạo đặt cuối vì nó là việc hiếm nhất — nhưng vẫn phải có
    /// mặt ở đây, vì người mới mở EIDE lần đầu không có dự án nào để chọn.
    @MainActor
    func moMenuDuAn() {
        let m = NSMenu()
        let ds = EideDuAn.ganDay()
        if ds.isEmpty {
            let x = m.addItem(withTitle: "Chưa có dự án nào", action: nil, keyEquivalent: "")
            x.isEnabled = false
        }
        for d in ds {
            let it = m.addItem(withTitle: EideDuAn.nhan(d, trong: ds),
                               action: #selector(chonDuAnTuMenu(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = d
            it.toolTip = d
        }
        m.addItem(.separator())
        let mo = m.addItem(withTitle: "Mở dự án khác…", action: #selector(moDuAnKhac),
                           keyEquivalent: "")
        mo.target = self
        let tao = m.addItem(withTitle: "Tạo dự án mới…", action: #selector(taoDuAnMoi),
                            keyEquivalent: "")
        tao.target = self

        // UC-A6/A7 — ba việc vòng đời dự án. Đặt sau một vạch ngăn và chỉ bật khi CÓ dự án
        // đang mở: "nhân bản" khi chưa mở dự án nào là một mục bấm vào rồi mới biết không làm
        // gì được.
        if eidePanel != nil, AppDelegate.duAnMoSan() != nil {
            m.addItem(.separator())
            for (nhan, sel) in [("Nhân bản dự án…", #selector(nhanBanDuAn)),
                                ("Lưu trữ dự án…", #selector(luuTruDuAn)),
                                ("Quay lại mốc…", #selector(quayLaiMoc))] {
                let it = m.addItem(withTitle: nhan, action: sel, keyEquivalent: "")
                it.target = self
            }
        }
        m.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// UC-A6 — nhân bản dự án. `project.clone` cần `src` + `new_name`, R2 → qua cổng.
    @MainActor
    @objc private func nhanBanDuAn() {
        guard let p = eidePanel, let goc = AppDelegate.duAnMoSan() else { return }
        guard let ten = hoiMotDong(
            tieu: "Nhân bản dự án",
            mo: "Bản sao giữ nguyên tri thức, hộ chiếu và lịch sử. Đặt tên cho bản mới:",
            goiY: (goc as NSString).lastPathComponent + "-ban-sao") else { return }
        p.chayVaBao("project.clone", ["src": goc, "new_name": ten])
    }

    /// UC-A6 — lưu trữ. Không hỏi gì thêm: `project` là dự án đang mở.
    @MainActor
    @objc private func luuTruDuAn() {
        guard let p = eidePanel, let goc = AppDelegate.duAnMoSan() else { return }
        let a = NSAlert()
        a.messageText = "Lưu trữ dự án?"
        a.informativeText = "Dự án được đóng gói lại. Tri thức và lịch sử giữ nguyên trong gói; "
            + "thư mục làm việc thì thôi được cập nhật."
        a.addButton(withTitle: "Lưu trữ")
        a.addButton(withTitle: "Huỷ")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        p.chayVaBao("project.archive", ["project": goc])
    }

    /// UC-A7 — quay lại mốc. `tag` để trống nghĩa là mốc gần nhất (hợp đồng cho phép).
    @MainActor
    @objc private func quayLaiMoc() {
        guard let p = eidePanel else { return }
        let ten = hoiMotDong(
            tieu: "Quay lại một mốc",
            mo: "Store và mã quay về mốc ấy. Để trống = mốc gần nhất.",
            goiY: "") ?? ""
        p.chayVaBao("project.rollback", ten.isEmpty ? [:] : ["tag": ten])
    }

    /// Hộp thoại một dòng. Trả nil khi người huỷ, và trả nil cả khi họ để TRỐNG một ô bắt buộc
    /// — người gọi quyết ô nào bắt buộc bằng cách truyền `goiY` rỗng hay không.
    @MainActor
    private func hoiMotDong(tieu: String, mo: String, goiY: String) -> String? {
        let a = NSAlert()
        a.messageText = tieu
        a.informativeText = mo
        let o = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
        o.stringValue = goiY
        a.accessoryView = o
        a.addButton(withTitle: "Tiếp")
        a.addButton(withTitle: "Huỷ")
        a.window.initialFirstResponder = o
        guard a.runModal() == .alertFirstButtonReturn else { return nil }
        return o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    @objc private func chonDuAnTuMenu(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? String else { return }
        (NSApp.delegate as? AppDelegate)?.moDuAnEide(duong: d)
    }

    @MainActor
    @objc private func moDuAnKhac() {
        (NSApp.delegate as? AppDelegate)?.moDuAnEide(nil)
    }

    /// **Tạo dự án mới** — PROJECT-01, từ MỘT CÂU tiếng Việt.
    ///
    /// Không phải biểu mẫu "tên / đường dẫn / chip": hợp đồng nhận `{text}` và tự suy ra cả ba
    /// nếu câu có nhắc. Bắt người dùng quyết ba thứ trước khi biết mình muốn gì là dựng một rào
    /// ở đúng bước đầu tiên.
    @MainActor
    @objc private func taoDuAnMoi() {
        guard let p = eidePanel else { return }
        let a = NSAlert()
        a.messageText = "Tạo dự án EIDE mới"
        a.informativeText = "Mô tả việc anh muốn làm, bằng một câu tiếng Việt. "
            + "EIDE suy ra tên dự án và chip từ câu ấy."
        let o = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        o.placeholderString = "ví dụ: đọc cảm biến BME280 qua I2C trên ESP32-C3"
        a.accessoryView = o
        a.addButton(withTitle: "Tạo")
        a.addButton(withTitle: "Huỷ")
        a.window.initialFirstResponder = o
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let cau = o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cau.isEmpty else {
            // Câu rỗng thì KHÔNG gọi: `project.create` sẽ tạo một dự án tên "" ở đâu đó, và
            // người dùng có một thư mục rác mà không biết vì sao.
            let b = NSAlert()
            b.messageText = "Chưa có mô tả"
            b.informativeText = "Gõ một câu mô tả việc anh muốn làm rồi thử lại."
            b.runModal()
            return
        }
        p.taoDuAn(cau) { [weak self] duong, loi in
            Task { @MainActor in
                if let loi {
                    let b = NSAlert()
                    b.messageText = "Không tạo được dự án"
                    b.informativeText = loi
                    b.runModal()
                    return
                }
                guard let duong else { return }
                // Dự án mới CHƯA có store — `project.create` không chạy migration. Mở ngay thì
                // hàng đợi không lưu được và mục ASK đầu tiên biến mất (đo 14/09 trên luồng AVR).
                (NSApp.delegate as? AppDelegate)?.moDuAnEide(duong: duong, diTru: true)
            }
        }
    }
    private var eideHeight: NSLayoutConstraint!

    private func attachEidePanel() -> Bool {
        guard let panel = eidePanel else { return false }
        guard attach(panel, as: .eide) else { return true }
        eideHeight = makePanelHeight(panel, .eide, minimum: EidePanel.height)
        eideHeight.isActive = true
        return true
    }

    @objc func showEidePanel(_ sender: Any?) {
        guard attachEidePanel(), let panel = eidePanel else {
            // U9: trạng thái lỗi phải NÓI RA. Không tìm thấy `eide` là chuyện thường gặp
            // (chưa `make setup`), và im lặng thì người dùng bấm menu rồi không thấy gì.
            let a = NSAlert()
            a.messageText = "Chưa chạy được EIDE"
            a.informativeText = "Không tìm thấy `eide`. Chạy `make setup` trong kho EIDE, "
                + "hoặc đặt biến môi trường EIDE_PYTHON trỏ tới python của venv."
            a.runModal()
            return
        }
        panel.isHidden = false
        eideHeight.constant = panelOpenHeight(.eide)
    }

    private func hideEidePanel() {
        eidePanel?.isHidden = true
        eideHeight?.constant = 0
    }

    var isEidePanelVisible: Bool { isAttached(.eide) && !(eidePanel?.isHidden ?? true) }

    private func attachRetrievalPanel() {
        guard attach(retrievalPanel, as: .retrieval) else { return }
        retrievalPanel.onClose = { [weak self] in self?.hideRetrievalPanel() }
        retrievalPanel.onQuery = { [weak self] query in self?.runRetrievalQuery(query) }
        retrievalPanel.onTuning = { [weak self] k1, b in self?.retuneRetrieval(k1: k1, b: b) }
        retrievalPanel.onEvaluate = { [weak self] action in
            switch action {
            case .goldenSet: self?.chooseGoldenSet()
            case .externalScores: self?.chooseExternalScores()
            }
        }
        retrievalPanel.onToggleLabelling = { [weak self] on in self?.startLabelling(on) }
        retrievalPanel.onSaveLabel = { [weak self] question, ids, note in
            self?.saveGoldenSetRecord(question: question, ids: ids, note: note)
        }
        retrievalPanel.onExportGoldenSet = { [weak self] in self?.exportGoldenSetCSV() }
        retrievalPanel.onHybrid = { [weak self] enabled, alpha in
            self?.setHybridRetrieval(enabled: enabled, alpha: alpha)
        }
        retrievalPanel.onGraphRAG = { [weak self] action in self?.runGraphRAG(action) }
        retrievalHeight = makePanelHeight(retrievalPanel, .retrieval, minimum: RetrievalPanel.height)
        retrievalHeight.isActive = true
    }

    private func attachSQLPanel() {
        guard attach(sqlPanel, as: .sql) else { return }
        sqlPanel.onClose = { [weak self] in self?.hideSQLPanel() }
        sqlPanel.onQuery = { [weak self] query in self?.runSQLQuery(query) }
        sqlPanel.onExport = { [weak self] result in self?.exportSQLResult(result) }
        sqlPanel.onSaveQuery = { [weak self] sql in self?.saveNamedQuery(sql) }
        sqlPanel.onChart = { [weak self] result in
            self?.showChart(for: result, title: L("Kết quả truy vấn"))
        }
        sqlPanel.onPivot = { [weak self] in self?.showPivotSheet() }
        sqlPanel.onCatalog = { [weak self] in self?.showCatalogSheet() }
        sqlHeight = makePanelHeight(sqlPanel, .sql, minimum: SQLPanel.height)
        sqlHeight.isActive = true
    }

    private func attachQualityPanel() {
        guard attach(qualityPanel, as: .quality) else { return }
        qualityPanel.onClose = { [weak self] in self?.hideQualityPanel() }
        qualityPanel.onSelectRule = { [weak self] result in self?.revealViolations(of: result) }
        qualityPanel.onFixRule = { [weak self] result in self?.fixWithCleanBench(result) }
        qualityPanel.onExport = { [weak self] in self?.exportViolations() }
        qualityHeight = makePanelHeight(qualityPanel, .quality, minimum: QualityPanel.height)
        qualityHeight.isActive = true
    }

    private func attachAnomalyPanel() {
        guard attach(anomalyPanel, as: .anomaly) else { return }
        anomalyPanel.onClose = { [weak self] in self?.hideAnomalyPanel() }
        anomalyPanel.onPickColumn = { [weak self] column in self?.findAnomalies(in: column) }
        anomalyPanel.onReveal = { [weak self] finding, severity in
            self?.markAnomalies([(finding, severity)], reveal: true)
        }
        anomalyPanel.onMarkAll = { [weak self] items in
            self?.markAnomalies(items, reveal: true)
        }
        anomalyPanel.onExport = { [weak self] report in self?.exportAnomalies(report) }
        anomalyHeight = makePanelHeight(anomalyPanel, .anomaly, minimum: AnomalyPanel.height)
        anomalyHeight.isActive = true
    }

    private func attachCorrelationPanel() {
        guard attach(correlationPanel, as: .correlation) else { return }
        correlationPanel.onClose = { [weak self] in self?.hideCorrelationPanel() }
        correlationPanel.onChangeMethod = { [weak self] method in
            self?.recomputeCorrelation(method: method)
        }
        correlationPanel.onPickPair = { [weak self] row, column in
            self?.showScatter(row: row, column: column)
        }
        correlationPanel.onExport = { [weak self] matrix in self?.exportCorrelation(matrix) }
        correlationHeight = makePanelHeight(correlationPanel, .correlation, minimum: CorrelationPanel.height)
        correlationHeight.isActive = true
    }

    private func attachForecastPanel() {
        guard attach(forecastPanel, as: .forecast) else { return }
        forecastPanel.onClose = { [weak self] in self?.hideForecastPanel() }
        forecastPanel.onPickColumn = { [weak self] column in self?.runForecast(on: column) }
        forecastPanel.onChangeSettings = { [weak self] in
            guard let self else { return }
            self.runForecast(on: self.forecastColumn)
        }
        forecastPanel.onExport = { [weak self] comparison in
            self?.exportForecast(comparison)
        }
        forecastHeight = makePanelHeight(forecastPanel, .forecast, minimum: ForecastPanel.height)
        forecastHeight.isActive = true
    }

    private func attachGroupMiningPanel() {
        guard attach(groupMiningPanel, as: .groupMining) else { return }
        groupMiningPanel.onClose = { [weak self] in self?.hideGroupMiningPanel() }
        groupMiningPanel.onChangeSettings = { [weak self] in self?.runGroupMining() }
        groupMiningPanel.onDrill = { [weak self] group in self?.drillIntoGroup(group) }
        groupMiningPanel.onExport = { [weak self] report in self?.exportGroupMining(report) }
        groupMiningHeight = makePanelHeight(groupMiningPanel, .groupMining, minimum: GroupMiningPanel.height)
        groupMiningHeight.isActive = true
    }

    private func attachAssociationPanel() {
        guard attach(associationPanel, as: .association) else { return }
        associationPanel.onClose = { [weak self] in self?.hideAssociationPanel() }
        associationPanel.onChangeSettings = { [weak self] in self?.runAssociation() }
        associationPanel.onPickRule = { [weak self] rule in self?.markRule(rule) }
        associationPanel.onExport = { [weak self] result in self?.exportAssociation(result) }
        associationHeight = makePanelHeight(associationPanel, .association, minimum: AssociationPanel.height)
        associationHeight.isActive = true
    }

    private func attachChartPanel() {
        guard attach(chartPanel, as: .chart) else { return }
        chartPanel.onClose = { [weak self] in self?.hideChartPanel() }
        chartPanel.onExportPNG = { [weak self] in self?.exportChart(asPNG: true) }
        chartPanel.onExportSVG = { [weak self] in self?.exportChart(asPNG: false) }
        chartHeight = makePanelHeight(chartPanel, .chart, minimum: ChartPanel.height)
        chartHeight.isActive = true
    }

    private func attachFindPanel() {
        guard attach(findPanel, as: .find) else { return }
        findPanel.onAction = { [weak self] action, query in
            self?.handleFindAction(action, query)
        }
        findPanelHeight = findPanel.heightAnchor.constraint(equalToConstant: 0)
        findPanelHeight?.isActive = true
    }

    /// Cây thư mục + mục lục, nằm NGANG bên trái vùng soạn thảo nên không thuộc cột dọc.
    private func attachSidebar() {
        guard !sidebarAttached else { return }
        sidebarAttached = true
        // Sidebar gồm HAI phần chồng dọc, đúng như UI/UX §quy tắc cửa sổ đặt: cây thư mục ở
        // trên, mục lục tài liệu đang mở ở dưới. Người dùng chọn file ở nửa trên rồi đi tới
        // đúng hàm ở nửa dưới — hai bước của cùng một việc, nên chúng nằm cạnh nhau.
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.isVertical = false
        sidebar.dividerStyle = .thin
        sidebar.delegate = self
        // Qua `moTepTuCay` chứ không thẳng `openInNewTab`: cây nay hiện cả `.eide/`, và trong
        // đó có `store.sqlite` — mở một tệp SQLite ra khung soạn thảo là vài nghìn dòng ký tự
        // rác cộng một lời mời sửa tay đúng cái tệp mà niêm store dựng lên để phát hiện sửa tay.
        workspaceView.onOpenFile = { [weak self] path in self?.moTepTuCay(path) }
        workspaceView.onCommand = { [weak self] command in self?.runWorkspaceCommand(command) }
        functionList.onSelect = { [weak self] symbol in self?.revealSymbol(symbol) }
        sidebar.addArrangedSubview(workspaceView)
        sidebar.addArrangedSubview(functionList)
        middleRow.addSubview(sidebar)

        sidebarWidth = sidebar.widthAnchor.constraint(equalToConstant: 0)
        splitViewLeading.isActive = false
        splitViewLeading = splitView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor)
        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: middleRow.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: middleRow.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: middleRow.leadingAnchor),
            sidebarWidth,
            splitViewLeading,
        ])
    }

    /// Bản đồ nằm sát mép PHẢI của hàng giữa, cạnh vùng soạn thảo chứ không đè lên nó.
    private func attachDocumentMap() {
        guard !documentMapAttached else { return }
        documentMapAttached = true
        documentMapView.translatesAutoresizingMaskIntoConstraints = false
        documentMapView.onSelectLine = { [weak self] line in self?.goTo(line: line + 1, column: nil) }
        documentMapView.onHeightChanged = { [weak self] in self?.refreshDocumentMap() }
        middleRow.addSubview(documentMapView)

        documentMapWidth = documentMapView.widthAnchor.constraint(equalToConstant: 0)
        // Vùng soạn thảo phải NHƯỜNG CHỖ, không bị bản đồ che. Che thì cột chữ cuối cùng biến
        // mất mà không ai hiểu vì sao.
        splitViewTrailing.isActive = false
        splitViewTrailing = splitView.trailingAnchor.constraint(
            equalTo: documentMapView.leadingAnchor
        )
        NSLayoutConstraint.activate([
            documentMapView.topAnchor.constraint(equalTo: middleRow.topAnchor),
            documentMapView.bottomAnchor.constraint(equalTo: middleRow.bottomAnchor),
            documentMapView.trailingAnchor.constraint(equalTo: middleRow.trailingAnchor),
            documentMapWidth,
            splitViewTrailing,
        ])
    }

    /// Khung xem trước báo cáo nằm sát mép PHẢI hàng giữa — FR-RPT-001 (*"soạn bên trái,
    /// preview bên phải"*). Cùng khuôn với bản đồ tài liệu: vùng soạn thảo NHƯỜNG CHỖ chứ không
    /// bị che.
    private func attachReportPreview() {
        guard !reportPreviewAttached else { return }
        reportPreviewAttached = true
        reportPreview.translatesAutoresizingMaskIntoConstraints = false
        reportPreview.onClose = { [weak self] in self?.hideReportPreview() }
        reportPreview.onExport = { [weak self] in self?.exportReportHTML() }
        reportPreview.onPrint = { [weak self] in self?.printReport() }
        reportPreview.onEditParameters = { [weak self] in self?.editReportParameters() }
        middleRow.addSubview(reportPreview)

        reportPreviewWidth = reportPreview.widthAnchor.constraint(equalToConstant: 0)
        splitViewTrailing.isActive = false
        splitViewTrailing = splitView.trailingAnchor.constraint(
            equalTo: reportPreview.leadingAnchor)
        NSLayoutConstraint.activate([
            reportPreview.topAnchor.constraint(equalTo: middleRow.topAnchor),
            reportPreview.bottomAnchor.constraint(equalTo: middleRow.bottomAnchor),
            reportPreview.trailingAnchor.constraint(equalTo: middleRow.trailingAnchor),
            reportPreviewWidth,
            splitViewTrailing,
        ])
    }

    /// Bảng Mermaid Studio dùng CHUNG một chỗ với khung xem trước báo cáo — FR-MMD-002.
    ///
    /// Hai khung này là cùng một thứ: cột xem trước của tài liệu đang mở. Cho chúng hai cột
    /// riêng thì trên một cửa sổ 1200 px, mở cả hai còn lại 400 px để soạn — và không có tài
    /// liệu nào cần cả hai, vì một tệp `.greport.md` không đồng thời là một tệp `.mmd`. Nên mở
    /// cái này thì đóng cái kia, và `splitViewTrailing` trỏ sang khung đang mở.
    private func attachMermaidPanel() {
        guard !mermaidPanelAttached else { return }
        mermaidPanelAttached = true
        mermaidPanel.translatesAutoresizingMaskIntoConstraints = false
        mermaidPanel.onClose = { [weak self] in self?.hideMermaidPanel() }
        mermaidPanel.onExport = { [weak self] choice in self?.exportMermaid(choice) }
        mermaidPanel.onChangeTheme = { [weak self] _ in self?.refreshMermaidPreview() }
        middleRow.addSubview(mermaidPanel)

        mermaidPanelWidth = mermaidPanel.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            mermaidPanel.topAnchor.constraint(equalTo: middleRow.topAnchor),
            mermaidPanel.bottomAnchor.constraint(equalTo: middleRow.bottomAnchor),
            mermaidPanel.trailingAnchor.constraint(equalTo: middleRow.trailingAnchor),
            mermaidPanelWidth,
        ])
    }

    /// Cho mép phải của vùng soạn thảo bám vào khung xem trước ĐANG mở.
    private func bindSplitTrailing(to anchor: NSLayoutXAxisAnchor) {
        splitViewTrailing.isActive = false
        splitViewTrailing = splitView.trailingAnchor.constraint(equalTo: anchor)
        splitViewTrailing.isActive = true
    }

    /// Bảng CSV nằm ĐÈ lên đúng vùng của khung soạn thảo, không phải cạnh nó: hai chế độ xem
    /// của CÙNG một tài liệu thì chỉ một cái được hiện tại một thời điểm (UI/UX §6).
    private func attachCSVTable() {
        guard !csvTableAttached else { return }
        csvTableAttached = true
        csvTable.translatesAutoresizingMaskIntoConstraints = false
        csvTable.onSwitchToText = { [weak self] in self?.showTextView() }
        // Thông báo của BẢNG đi vào dải băng chung, KHÔNG đi vào ô kết quả của panel Tìm.
        //
        // Bản trước nối thẳng vào `findPanel.showStatus`, nên người dùng sắp một cột rồi nhìn
        // sang panel Tìm thấy «Sắp xếp theo tuoi tăng dần» đứng đúng chỗ đáng lẽ ghi «3/17».
        // Một ô có tên «Kết quả tìm kiếm» mà mang chữ của tính năng khác thì nó nói dối, và
        // người đọc không có cách nào biết. `mediaViewer.onStatus` vốn đã đi đường này.
        csvTable.onStatus = { [weak self] message in self?.showTransient(message) }
        csvTable.onEditCell = { [weak self] row, column, value in
            self?.applyCellEdit(row: row, column: column, value: value)
        }
        csvTable.onApplySort = { [weak self] order in self?.applySortToFile(order) }
        csvTable.onColumnCommand = { [weak self] command in self?.runColumnCommand(command) }
        csvTable.onValidate = { [weak self] in self?.validateCSV(nil) }
        csvTable.onConvert = { [weak self] in self?.showConvertSheet(nil) }
        csvTable.onExportFiltered = { [weak self] rows in self?.exportFilteredRows(rows) }
        middleRow.addSubview(csvTable)
        NSLayoutConstraint.activate([
            csvTable.topAnchor.constraint(equalTo: splitView.topAnchor),
            csvTable.leadingAnchor.constraint(equalTo: splitView.leadingAnchor),
            csvTable.trailingAnchor.constraint(equalTo: splitView.trailingAnchor),
            csvTable.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
        ])
    }

    /// Khung xem media nằm ĐÈ lên vùng soạn thảo, đúng chỗ và đúng luật của bảng CSV.
    private func attachMediaViewer() {
        guard !mediaViewerAttached else { return }
        mediaViewerAttached = true
        mediaViewer.translatesAutoresizingMaskIntoConstraints = false
        mediaViewer.onStatus = { [weak self] message in self?.showTransient(message) }
        mediaViewer.onOpenTextInNewTab = { [weak self] text, label in
            self?.openTextInNewTab(text, label: label)
        }
        mediaViewer.onOpenFile = { [weak self] path in
            self?.openInNewTab(path: path)
        }
        middleRow.addSubview(mediaViewer)
        NSLayoutConstraint.activate([
            mediaViewer.topAnchor.constraint(equalTo: splitView.topAnchor),
            mediaViewer.leadingAnchor.constraint(equalTo: splitView.leadingAnchor),
            mediaViewer.trailingAnchor.constraint(equalTo: splitView.trailingAnchor),
            mediaViewer.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
        ])
    }

    /// Tab đang mở có phải tài liệu media không.
    var isMediaDocument: Bool { editorDocument.mediaKind != nil }

    /// Khung xem media có đang hiện không — bài tự kiểm hỏi đúng thứ trên màn hình.
    var isMediaViewerVisibleForSelfTest: Bool { mediaViewerAttached && !mediaViewer.isHidden }

    func newTabForSelfTest() { newTab(nil) }

    /// Thay toàn bộ nội dung tài liệu đang mở, đi qua `apply` như một lần sửa thật.
    ///
    /// Khác `prepareSelfTestDocument` ở chỗ nó KHÔNG tráo tài liệu mới — đường dẫn và
    /// `mediaKind` giữ nguyên, đúng thứ bài kiểm ghi ngược Office cần.
    func prepareSelfTestEditToDocument(_ text: String) {
        // Dùng lại nhãn của `prepareSelfTestDocument` thay vì đặt nhãn mới: một chuỗi tiếng
        // Việt mới ở tầng app sẽ vào bộ đếm nợ dịch FR-UI-804, và nợ dịch không nên phình lên
        // vì một nhãn chỉ bài tự kiểm nhìn thấy.
        apply([TextEdit(range: 0 ..< editorDocument.buffer.count, text: text)],
              label: "dựng bài")
        syncViewFromBuffer()
    }

    func saveDocumentForSelfTest() { saveDocument(nil) }

    /// Bật hoặc tắt khung xem media cho tab đang mở.
    ///
    /// Gọi từ `applyActiveTab` và `loadDocument` — hai chỗ DUY NHẤT tài liệu đang hiện đổi.
    /// Quên một trong hai thì chuyển tab từ ảnh sang văn bản sẽ để lại khung ảnh nằm đè lên
    /// chữ, và người dùng thấy một tab văn bản mở ra thành ảnh của tab trước.
    /// Mở một tệp media, chọn giữa "khung xem riêng" và "đưa về bảng CSV".
    ///
    /// Bảng tính đi đường thứ hai. Đường thứ nhất — một khung xem Excel riêng — sẽ phải dựng
    /// lại lọc, sắp, thống kê, biểu đồ… tức chép lại thứ sản phẩm này đã có và làm tốt.
    ///
    /// Đọc hỏng thì LÙI về khung file nén chứ không báo lỗi rồi bỏ đấy: ruột `.xlsx` là ZIP, và
    /// mở được từng phần vẫn hơn hẳn một hộp thoại "không đọc được".
    /// Mở một tệp bất kỳ — ĐÚNG MỘT cửa cho mọi đường vào.
    ///
    /// Ba chỗ từng gọi thẳng `Document.open(path:)` và vì thế bỏ qua phép nhận diện media:
    /// **khôi phục phiên**, **nạp lại khi tệp đổi trên đĩa**, và **chế độ theo dõi log**. Hậu
    /// quả thấy được ngay trên màn hình: mở một tệp `.docx` rồi thoát và mở lại app thì tab ấy
    /// quay về thành **byte ZIP thô** — `PK`, `word/_rels/document.xml.rels` — kèm một bảng mã
    /// đoán bừa, và khung chung nói "tệp này chỉ có một chế độ hiển thị".
    ///
    /// Người dùng gặp đúng lỗi ấy khi thử bản dựng, còn `--doc-sweep` thì không thấy gì: nó mở
    /// tệp LẦN ĐẦU, không bao giờ đi qua đường khôi phục.
    static func openAnyDocument(path: String) throws -> Document {
        if let kind = MediaKind.of(path: path) {
            return openMedia(path: path, kind: kind)
        }
        return try Document.open(path: path)
    }

    /// Mở qua BOOKMARK — đường mà bản App Store luôn đi khi khôi phục phiên.
    ///
    /// Bookmark giữ QUYỀN đọc, còn phép nhận diện media thì đọc theo ĐƯỜNG DẪN. Nên đường này
    /// mở quyền trước, rồi giao lại cho `openAnyDocument`; thiếu bước ấy thì mọi tệp Office
    /// khôi phục từ phiên trước quay về thành byte thô — và ở bản App Store thì đó là ca THƯỜNG,
    /// vì đường dẫn trần không mở được tệp của phiên trước.
    static func openAnyDocument(bookmark: Data, path: String?) -> Document? {
        // Mở bằng bookmark trước để có quyền; nếu đó là tệp media thì dựng lại bằng đường media
        // trên đúng đường dẫn vừa giải ra.
        guard let opened = Document.open(bookmark: bookmark, preferredPath: path) else {
            return nil
        }
        guard let resolved = opened.path, let kind = MediaKind.of(path: resolved) else {
            return opened
        }
        let media = openMedia(path: resolved, kind: kind)
        // Giữ nguyên quyền truy cập đã mở: tài liệu media dựng lại từ đường dẫn không mang theo
        // `heldAccess`, và mất nó thì lần ⌘S sau bị sandbox từ chối.
        media.adoptAccess(from: opened)
        return media
    }

    static func openMedia(path: String, kind: MediaKind) -> Document {
        do {
            switch kind {
            case .excel:
                let reader = try XLSXReader(path: path)
                guard let sheet = reader.sheets.first else { throw XLSXReader.Failure.noSheets }
                let grid = try reader.grid(of: sheet)
                return Document.forSpreadsheet(
                    path: path, csv: XLSXReader.csv(from: grid), sheet: sheet.name
                )
            case .word:
                let text = try DOCXReader.read(path: path).markdown
                return Document.forSpreadsheet(path: path, csv: text, kind: .word)
            case .powerpoint:
                let text = try PPTXReader.read(path: path).markdown
                return Document.forSpreadsheet(path: path, csv: text, kind: .powerpoint)
            default:
                return Document.forMedia(path: path, kind: kind)
            }
        } catch {
            return Document.forMedia(path: path, kind: .archive)
        }
    }

    private func syncMediaViewer() {
        // Ba định dạng Office đã có nội dung trong buffer — chúng dùng chính khung soạn thảo
        // và bảng CSV, không dùng khung media.
        let kindInBuffer = editorDocument.mediaKind
        if kindInBuffer == .excel || kindInBuffer == .word || kindInBuffer == .powerpoint {
            if mediaViewerAttached, !mediaViewer.isHidden {
                mediaViewer.isHidden = true
                mediaViewer.clear()
                splitView.isHidden = false
            }
            // Chỉ BẢNG TÍNH mới bật bảng CSV. Word và PowerPoint ra Markdown — chúng thuộc về
            // khung soạn thảo, nơi đã có xem trước Markdown, gấp theo cấp và danh sách hàm.
            guard kindInBuffer == .excel else { return }
            // Hoãn một nhịp: `showTableView` dựng chỉ mục hàng ở luồng nền và đụng vào giao
            // diện, mà lúc này ta còn đang ở giữa lượt tráo tài liệu.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.editorDocument.mediaKind == .excel,
                      !self.isTableViewVisible else { return }
                self.showTableView()
            }
            return
        }
        guard let kind = editorDocument.mediaKind, let path = editorDocument.path else {
            if mediaViewerAttached, !mediaViewer.isHidden {
                mediaViewer.isHidden = true
                mediaViewer.clear()
                splitView.isHidden = false
            }
            return
        }
        // Bảng CSV và khung media không bao giờ cùng hiện — chúng cùng chiếm một chỗ.
        if csvTableAttached { csvTable.isHidden = true }
        attachMediaViewer()
        mediaViewer.show(path: path, kind: kind)
        mediaViewer.isHidden = false
        splitView.isHidden = true
    }

    // MARK: - Nạp tài liệu

    func loadDocument(_ newDocument: Document) {
        // Tài liệu cũ coi như đã đóng: `geditor -w` đang chờ nó phải được giải phóng, nếu
        // không thì git ngồi chờ mãi một file mà người dùng đã chuyển đi từ lâu.
        if let previous = editorDocument.path, previous != newDocument.path {
            cliBridge?.documentClosed(path: previous)
        }
        editorDocument = newDocument
        // Bỏ hết dấu dòng: dấu là tập SỐ DÒNG, nên giữ lại khi đổi tài liệu là trỏ vào những
        // dòng hoàn toàn khác. Hậu quả không phải chỉ xấu mặt — "xóa mọi dòng đã đánh dấu" sẽ
        // xóa đúng những dòng ấy trong file MỚI. Cùng lý do với việc đưa con trỏ về đầu ngay
        // dưới đây, và cùng loại lỗi.
        var cleared = marks
        cleared.clearAll()
        marks = cleared
        // Dấu gạch lỗi cũng là tập VỊ TRÍ của tài liệu cũ — cùng loại lỗi với dấu dòng, và
        // nặng hơn một bậc: chúng là offset BYTE, nên giữ lại thì chúng vừa gạch nhầm dòng vừa
        // trỏ RA NGOÀI tài liệu mới khi tệp mới ngắn hơn. Bài tự kiểm FR-MMD-006 sập ở đúng đó.
        editorView.problemRanges = []
        mermaidBlocks = []
        // Và mọi khung View của tài liệu CŨ phải tắt — cùng một lý do với dấu dòng và dấu lỗi
        // ngay trên: chúng mô tả một tài liệu không còn mở.
        //
        // Lỗi này sống cho tới khi khung chung ra đời và buộc câu hỏi "đang ở chế độ nào" phải
        // có một câu trả lời đúng ở mọi lúc: mở một tệp CSV rồi sang tab JSON thì bảng CSV VẪN
        // nằm trên màn hình, che tài liệu mới, và công tắc thì nói "đang ở View" về một chế độ
        // thuộc tệp khác.
        hideAllViewModes()
        hideDocumentPanels()

        // Chỉ mục hàng CSV cũng thuộc về tài liệu cũ, và nó là bảng OFFSET BYTE — thứ sai lệch
        // nguy hiểm nhất trong ba thứ dọn ở đây, vì nó không sai "một chút" mà trỏ vào giữa ký
        // tự, hoặc ra ngoài hẳn tài liệu mới.
        forgetCSVIndex()

        // Con trỏ về ĐẦU tài liệu mới, không giữ vị trí của tài liệu cũ.
        //
        // `syncViewFromBuffer` cố ý giữ vị trí con trỏ — đúng khi buffer vừa bị sửa tại chỗ,
        // sai khi đổi sang file khác: mở file 8 byte sau khi đang ở dòng 3 triệu thì vị trí cũ
        // bị kẹp về CUỐI file mới, và ký tự gõ tiếp theo rơi xuống đó.
        editorView.load(newDocument.buffer, caretAt: 0)
        syncMediaViewer()
        refreshChrome()
        showOpeningWarnings()
    }

    /// Chiếu nội dung buffer lên view.
    ///
    /// TODO(ADR-01): dựng lại CẢ chuỗi — chấp nhận được với chỗ dựng khung, KHÔNG chấp nhận
    /// được với engine thật. Engine do PoC-A chốt phải đọc buffer theo vùng hiển thị.
    /// Chiếu buffer lên view.
    ///
    /// Chỉ nạp lại CỬA SỔ quanh con trỏ, không dựng lại cả chuỗi: đó là toàn bộ điểm của
    /// ADR-01. Với file 500 MB, bản cũ dựng một chuỗi 500 MB ở mỗi thao tác.
    private func syncViewFromBuffer() {
        editorView.attach(editorDocument.buffer)
        let caret = min(editorView.selectedDocumentRange.lowerBound, editorDocument.buffer.count)
        editorView.repaginate(around: caret)
        editorView.setCaret(documentOffset: caret)
        // Mọi thao tác hàng loạt (sắp xếp, lọc, đổi bảng mã…) cũng phải hiện ra ở pane kia.
        // Không dội sang thì nửa màn hình bên kia hiển thị nội dung ĐÃ CHẾT, và người dùng
        // sửa tiếp trên cái họ đang nhìn.
        mirrorEdit(from: editorView, in: editorDocument)
    }

    private func refreshChrome() {
        // Giữ bất biến "pane hiện đúng tài liệu của nó" ở ĐÂY, vì gần như mọi lệnh đều đi qua
        // `refreshChrome()`. Xem `syncPanesToTheirTabs`.
        syncPanesToTheirTabs()

        var state = statusBar.state
        state.encoding = editorDocument.encoding.displayName
        state.eol = editorDocument.eol ?? .lf
        state.isReadOnly = editorDocument.isReadOnly
        // Chế độ CSV (FR-CSV-401): nói ra cả DẤU PHÂN TÁCH đã nhận diện, không chỉ "CSV".
        // Nhận nhầm delimiter là lỗi im lặng nhất của cả nhóm CSV — mọi thao tác cột sau đó
        // đều sai, và người dùng không có cách nào biết cho tới khi dữ liệu hỏng.
        var modeParts: [String] = []
        if isCSVMode {
            let dialect = csvDialect
            editorView.csvDialect = dialect
            modeParts.append("CSV · \(dialect.displayName)")
        } else {
            editorView.csvDialect = nil
            if editorDocument.isLargeFileMode { modeParts.append("Large File Mode") }
        }
        // Theo dõi file (FR-DOC-309) là trạng thái BỀN, không phải một sự kiện.
        //
        // Trước nay nó chỉ hiện ra trong một dải băng thoáng qua, nên vài giây sau người dùng
        // chỉ còn thấy một tài liệu không gõ được và không có gì nói vì sao. Chú thích của
        // `StatusBarView.State.mode` đã ghi "LFM/CSV/Monitoring" ngay từ đầu — vế thứ ba là vế
        // duy nhất chưa bao giờ được nối.
        if isFollowingTail { modeParts.append(L("Đang theo dõi")) }
        state.mode = modeParts.isEmpty ? nil : modeParts.joined(separator: " · ")
        // Ngôn ngữ tô màu theo ĐUÔI FILE (FR-FMT-501), trừ khi người dùng đã tự chọn ở thanh
        // trạng thái. Đặt cả cho khung soạn thảo lẫn thanh trạng thái từ một chỗ, để hai nơi
        // không bao giờ nói hai điều khác nhau.
        let language: SyntaxLanguage?
        switch tabs[activeIndex].languageChoice {
        case .auto: language = editorDocument.path.flatMap { SyntaxLanguage.detect(path: $0) }
        case .plain: language = nil
        case .language(let chosen): language = chosen
        }
        editorView.syntaxLanguage = language

        // FR-FMT-502: chỉ hỏi tới ngôn ngữ tự định nghĩa khi không ngôn ngữ DỰNG SẴN nào nhận.
        // Ngược lại thì người dùng khai một UDL cho `.py` sẽ mất tô màu Python đầy đủ — một cú
        // đổi chác họ không hề yêu cầu.
        let custom = language == nil
            ? editorDocument.path.flatMap {
                UserDefinedLanguage.matching(path: $0, in: userLanguages)
            }
            : nil
        editorView.userLanguage = custom
        state.language = language?.displayName ?? custom?.name ?? "Văn bản thuần"
        // Thụt lề đi theo NGÔN NGỮ (FR-CORE-009), nên nó phải được tính lại ở đây — chỗ ngôn
        // ngữ vừa được quyết định — chứ không phải chỉ khi người dùng bấm vào menu.
        let indent = language.flatMap { settings.languageIndent[$0.rawValue] }
            ?? Settings.IndentStyle(width: settings.tabWidth, usesTabs: settings.usesTabsForIndent)
        state.tabWidth = indent.width
        editorView.tabWidth = indent.width
        state.displayMode = currentDisplayModeLabel()
        statusBar.state = state
        refreshDocumentToolbar()
        updateCaretStatus()

        // Mục lục nói về tài liệu ĐANG mở; đổi tab hay sửa nội dung thì nó phải theo kịp.
        refreshFunctionList()

        let name = editorDocument.path.map { ($0 as NSString).lastPathComponent } ?? "Chưa đặt tên"
        // Chấm chưa lưu dùng màu GOLD theo bảng màu (README §màu sắc).
        window?.title = editorDocument.isModified ? "\(name) •" : name
        window?.representedFilename = editorDocument.path ?? ""
        window?.isDocumentEdited = editorDocument.isModified
        refreshTabBar()
    }

    /// Mở báo cáo sự cố gần nhất thành một TAB — NFR-REL-03.
    ///
    /// Mở thành tab chứ không hiện hộp thoại, và điều đó có lý do: sản phẩm này LÀ trình soạn
    /// thảo văn bản. Báo cáo là một tệp chữ; đưa nó vào đúng công cụ mà người dùng đang có sẵn
    /// thì họ đọc được, cuộn được, chép được, tìm được — còn một hộp thoại chỉ cho nhìn.
    ///
    /// Sau khi mở thì XOÁ khỏi hàng chờ: đã đưa cho người dùng rồi thì lần khởi động sau không
    /// nhắc lại nữa. Tệp vẫn còn trên đĩa dưới dạng tab đang mở, và họ tự quyết lưu hay bỏ.
    @objc func openCrashReport(_ sender: Any?) {
        guard let latest = CrashReporter.pendingReports().first else { return }
        openInNewTab(path: latest.path)
        CrashReporter.discardReports()
        hideBanner()
    }

    private func showOpeningWarnings() {
        if editorDocument.hasMixedEOL {
            // TC-ENC-04: file trộn EOL phải được cảnh báo kèm nút chuẩn hóa một chạm.
            showBanner(
                "File trộn nhiều kiểu xuống dòng (CRLF/LF/CR).",
                actionTitle: "Chuẩn hóa về \((editorDocument.eol ?? .lf).rawValue)",
                action: #selector(normalizeEOLFromBanner)
            )
        } else if let best = editorDocument.detection.first, best.confidence < 0.9,
                  editorDocument.detection.count > 1 {
            // FR-ENC-202: nhận diện không chắc thì NÓI RA kèm phần trăm, đừng giả vờ chắc.
            let alternatives = editorDocument.detection.dropFirst().prefix(2)
                .map { "\($0.encoding.displayName) \(Int($0.confidence * 100))%" }
                .joined(separator: ", ")
            showBanner(
                "Đoán bảng mã \(best.encoding.displayName) (\(Int(best.confidence * 100))%)."
                    + (alternatives.isEmpty ? "" : " Cũng có thể: \(alternatives)."),
                actionTitle: "Chọn lại…",
                action: #selector(showEncodingMenu)
            )
        } else {
            hideBanner()
        }
    }

    private func showBanner(_ message: String, actionTitle: String?, action: Selector?) {
        attachBanner()
        banner.configure(message: message, actionTitle: actionTitle, target: self, action: action)
        bannerHeight.constant = BannerView.height
    }

    func showRestoreBanner(_ message: String) {
        showBanner(message, actionTitle: nil, action: nil)
    }

    func showBannerPublic(_ message: String, actionTitle: String?, action: Selector?) {
        showBanner(message, actionTitle: actionTitle, action: action)
    }

    func hideBannerPublic() { hideBanner() }

    private func hideBanner() {
        bannerHeight?.constant = 0
    }

    // MARK: - Autosave (FR-DOC-304, NFR-REL-01)

    private func startAutosave() {
        autosaveTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autosaveInterval, repeats: true
        ) { [weak self] _ in
            self?.writeSnapshotIfNeeded()
        }
    }

    /// Chụp bản nháp của MỌI tab đã sửa, không riêng tab đang mở.
    ///
    /// Bản đầu chỉ chụp `editorDocument`. Lúc viết nó thì app chỉ có một tài liệu, nhưng tab
    /// (FR-DOC-301) ra đời sau và không ai quay lại sửa chỗ này: mở năm tab, sửa cả năm, bị
    /// `kill -9` thì bốn tab không mở lên mất sạch. NFR-REL-01 nói "không mất dữ liệu chưa
    /// lưu", không nói "không mất dữ liệu của tab đang mở".
    private func writeSnapshotIfNeeded() {
        for (index, tab) in tabs.enumerated() where tab.document.isModified {
            // Con trỏ của tab đang mở nằm ở VIEW, của tab khác nằm ở trạng thái đã cất.
            let caret = index == activeIndex
                ? editorView.selectedDocumentRange.lowerBound
                : tab.caretOffset
            do {
                try tab.document.writeSnapshot(caretOffset: caret, store: snapshotStore)
            } catch {
                NSLog("[GEditor] không ghi được bản nháp: %@", String(describing: error))
            }
        }
        saveSession()
    }

    // MARK: - Phiên làm việc (FR-DOC-303)

    var sessionStore = SessionStore()

    /// Chế độ CSV đang bật hay không (FR-CSV-401/402) — của TAB ĐANG MỞ.
    ///
    /// `nil` = tự nhận diện theo đuôi file; người dùng bật/tắt tay thì ghi đè.
    ///
    /// Trước đây đây là một biến của CỬA SỔ, và nó rò sang tab khác: bật chế độ CSV (hoặc chỉ
    /// cần bấm ⌥⌘T xem bảng, vì lệnh ấy tự bật giúp) rồi mở một tệp `.json` ở tab mới thì thanh
    /// trạng thái ghi «CSV · dấu phẩy» cho tệp JSON và khung soạn thảo tô màu cột lên nó. Một
    /// bài kiểm hỏi «đổi tab thì thanh trạng thái có theo tab mới không» bắt được.
    private var csvModeOverride: Bool? {
        get { tabs[activeIndex].csvModeOverride }
        set { tabs[activeIndex].csvModeOverride = newValue }
    }

    /// Chỉ mục hàng của tài liệu đang hiện trong bảng (FR-CSV-403).
    ///
    /// Chỉ mục gắn với NỘI DUNG buffer tại một thời điểm; mọi lần sửa đều phải dựng lại. Giữ
    /// một chỉ mục cũ thì bảng đọc vào những offset không còn đúng nữa — và cái sai ấy không
    /// báo lỗi, nó chỉ hiện chữ lệch.
    private var csvIndex: CSVRowIndex?
    private var csvIndexToken: CancelToken?

    /// Bỏ chỉ mục hàng đang giữ, và huỷ lượt dựng đang chạy dở.
    ///
    /// Gọi ở MỌI chỗ tài liệu đang hiện đổi sang tài liệu khác. Huỷ lượt dựng cũng quan trọng
    /// ngang việc xoá: một lượt dựng của tài liệu cũ về đích sau khi đã đổi tab sẽ gán chỉ mục
    /// của nó vào chỗ này và dựng lại đúng cái vừa dọn đi.
    private func forgetCSVIndex() {
        csvIndexToken?.cancel()
        csvIndexToken = nil
        csvIndex = nil
    }

    // MARK: - Bộ đếm "lượt yêu cầu đã XONG" cho bài tự kiểm
    //
    // Ba bộ đếm dưới đây tồn tại vì cùng MỘT mẫu lỗi, đã mắc ba lần:
    //
    //   Một hàm mở panel chạy việc nặng ở luồng nền, và bài tự kiểm chờ bằng cách hỏi "panel
    //   đã hiện chưa". Nhưng hàm ấy có nhánh TỪ CHỐI — tài liệu rỗng, dữ liệu không hợp lệ —
    //   và khi đi nhánh ấy thì panel KHÔNG BAO GIỜ hiện. Câu hỏi để chờ không bao giờ thành
    //   đúng, nên lượt chờ đốt trọn hạn 30 giây. Bộ tự kiểm không ĐỎ, chỉ CHẬM; và bộ chạy dài
    //   `--soak` bấm cùng một nút vài trăm lần thì 30 giây thành nhiều giờ.
    //
    // Luật: đếm LƯỢT YÊU CẦU ĐÃ KẾT THÚC, không đếm trạng thái panel và cũng không đếm số lượt
    // việc-nặng-đã-chạy. Bộ đếm phải nhích ở MỌI nhánh thoát, kể cả nhánh không làm gì —
    // chính hai nhánh ấy là thứ người chờ cần biết nhất.
    //
    // `cleanPanel.scanCount` từng bị nhầm là đủ: nó đếm số lượt QUÉT, nên nhánh "tài liệu rỗng"
    // (chưa quét lần nào) vẫn treo.

    /// Số lượt mở Bàn làm sạch đã KẾT THÚC — kể cả lượt bị từ chối vì tài liệu rỗng.
    private var cleanBenchRequests = 0

    /// Số lượt kiểm tra dữ liệu đã CHẠY XONG — kể cả lượt không hiện được panel.
    ///
    /// Cùng lý do và cùng luật với `csvTableRequests`: `validateCSV` trả về ngay khi tài liệu
    /// rỗng, nên "panel đã hiện chưa" là câu hỏi có thể KHÔNG BAO GIỜ thành đúng. Chờ theo nó
    /// thì mỗi lần gọi đốt trọn hạn 30 giây và bộ chạy dài kéo thành hàng giờ — đúng lỗi đã
    /// mắc một lần ở đường bảng CSV.
    private var validationRequests = 0

    /// Số lượt dựng chỉ mục bảng đã CHẠY XONG — kể cả lượt không hiện được bảng.
    ///
    /// Chỉ dùng cho bài tự kiểm, và có mặt vì "bảng đã hiện chưa" là câu hỏi SAI để chờ: yêu
    /// cầu dựng bảng có thể kết thúc mà không hiện gì (tài liệu rỗng thì `showTableView` báo
    /// "không có gì để hiện" rồi thôi). Chờ theo câu hỏi ấy thì lượt chờ đốt trọn hạn 30 giây
    /// mỗi lần, và bộ chạy dài `--soak` biến thành nhiều giờ. Chờ theo SỐ LƯỢT ĐÃ XONG thì
    /// đúng cả hai đường. Cùng luật với `cleanPanel.scanCount`.
    private var csvTableRequests = 0

    /// Panel kết quả kiểm tra dữ liệu (FR-CSV-405).
    /// Bảng lỗi dữ liệu CSV — dựng khi kiểm tra lần đầu.
    lazy var validationPanel: CSVValidationPanel = {
        let view = CSVValidationPanel()
        view.isHidden = true
        return view
    }()
    private var validationHeight: NSLayoutConstraint!
    private var validationToken: CancelToken?
    /// Sheet chuyển đổi đang mở — giữ lại để nó không bị giải phóng giữa chừng.
    private var convertSheet: CSVConvertSheet?

    /// Sidebar: cây thư mục (FR-DOC-308) trên, Function List (FR-DOC-307) dưới.
    /// Cây thư mục + mục lục — dựng khi bật sidebar lần đầu.
    private lazy var sidebar: NSSplitView = {
        let view = NSSplitView()
        view.isHidden = true
        return view
    }()
    lazy var workspaceView = WorkspaceView()
    lazy var qualityPanel = QualityPanel()
    lazy var reportPreview = ReportPreviewView()
    lazy var anomalyPanel = AnomalyPanel()
    lazy var correlationPanel = CorrelationPanel()
    lazy var forecastPanel = ForecastPanel()
    lazy var groupMiningPanel = GroupMiningPanel()
    lazy var associationPanel = AssociationPanel()
    lazy var chartPanel = ChartPanel()
    /// Danh mục bảng ảo của workspace (FR-QRY-005).
    var queryCatalog = QueryCatalog()
    var pivotSheet: PivotSheet?
    private var chartHeight = NSLayoutConstraint()
    private var qualityHeight = NSLayoutConstraint()
    private var anomalyHeight = NSLayoutConstraint()
    private var anomalyColumns: [String] = []
    private var correlationHeight = NSLayoutConstraint()
    private var correlationColumns: [String] = []
    private var correlationValues: [[Double]] = []
    private var clusterSheet: ClusterSheet?
    private(set) var lastClusterResult: Clustering.Result?
    private var forecastHeight = NSLayoutConstraint()
    private var forecastColumns: [String] = []
    private var forecastColumn = ""
    private var groupMiningHeight = NSLayoutConstraint()
    private var associationHeight = NSLayoutConstraint()
    /// Giỏ hàng đã dựng, kèm chỉ số hàng GỐC của từng giỏ — để bấm luật rồi tô dòng nguồn.
    private var associationBaskets: [[String]] = []
    private var associationRows: [[Int]] = []
    /// Báo cáo chất lượng gần nhất — giữ để bấm luật và xuất vi phạm không phải chấm lại.
    private var qualityReport: QualityEngine.Report?
    /// Nhớ kết quả chấm điểm của khối ```quality giữa các lần dựng preview (FR-DQR-003).
    let reportQualityCache = QualityCache()
    /// Nhớ kết quả từng khối ```query giữa các lần dựng preview — NFR-RPT-01.
    ///
    /// Preview dựng lại mỗi khi người dùng ngừng gõ. Không có nó thì sửa MỘT dòng văn xuôi cũng
    /// chạy lại cả mười khối truy vấn trên nguồn một triệu dòng: đo được **1.294 ms** mỗi lần
    /// gõ, và với cache là **1 ms** (`scripts/run-report-kpi.sh`).
    ///
    /// Khoá đã gồm trạng thái nguồn, nên tệp dữ liệu đổi thì khối tự chạy lại — không cần ai
    /// nhớ xoá bộ nhớ tạm này.
    let reportBlockCache = ReportBlockCache()

    // --- Mermaid Studio (FR-MMD) ---
    lazy var mermaidPanel = MermaidPanel()

    /// Bản thứ hai của cùng khung sơ đồ, chiếm TRỌN vùng soạn thảo — chế độ View của tệp sơ đồ.
    ///
    /// Dùng lại `MermaidPanel` chứ không dựng khung mới: hai thứ hiện y hệt nhau, chỉ khác chỗ
    /// ngồi và bề rộng. Khác biệt duy nhất là bộ vẽ chỉ có MỘT `WKWebView`, nên hai khung không
    /// bao giờ được hiện cùng lúc — `attach` tự gỡ khung kia ra, và luật ấy được viết thẳng vào
    /// hai hàm bật/tắt dưới đây.
    lazy var diagramTab = MermaidPanel()
    /// Dựng LƯỜI: `MermaidRenderer` chỉ tạo WKWebView ở lần vẽ đầu tiên, nên biến này tồn tại
    /// mà chưa tốn gì — NFR-MMD-01 (*"khởi động app và RAM nghỉ không đổi"*).
    lazy var mermaidRenderer: MermaidRenderer = {
        let renderer = MermaidRenderer()
        renderer.brand = mermaidBrand
        renderer.onClickElement = { [weak self] index, text in
            self?.jumpToMermaidElement(diagram: index, text: text)
        }
        return renderer
    }()
    private var mermaidPanelAttached = false
    private var diagramTabAttached = false
    private var mermaidPanelWidth: NSLayoutConstraint!
    private var mermaidRefreshWork: DispatchWorkItem?
    /// Khối sơ đồ của lần dựng gần nhất — để bấm sơ đồ tìm ngược về dòng.
    private var mermaidBlocks: [MermaidBlock] = []
    /// Giữ sheet thư viện mẫu sống trong lúc nó đang mở (FR-MMD-005).
    private var mermaidTemplateSheet: MermaidTemplateSheet?
    /// Preset màu thương hiệu, đọc một lần rồi giữ (FR-MMD-007).
    lazy var mermaidBrand = MermaidBrand.load()
    /// Kết quả lượt sinh loạt gần nhất — bài tự kiểm FR-RPT-006 đọc.
    private(set) var lastReportBatch: ReportBatch.Outcome?
    /// Bộ luật của lần chấm gần nhất — vòng khép kín FR-DQR-006 chấm lại bằng ĐÚNG bộ này.
    ///
    /// Đọc lại tệp cũng được, nhưng khi ấy một lần sửa tệp luật giữa chừng sẽ làm điểm "sau khi
    /// sửa" không so được với điểm "trước khi sửa" — mà cả vòng detect → clean → verify chỉ có
    /// nghĩa khi hai đầu đo bằng cùng một thước.
    private var qualityRules: QualityRules?
    lazy var functionList = FunctionListView()
    private var sidebarWidth: NSLayoutConstraint!
    private var outlineToken: CancelToken?
    /// Cảnh báo YAML của lần kiểm gần nhất — bài tự kiểm đọc để biết đã tìm ra gì.
    private(set) var lastYAMLIssues: [YAMLIssue] = []

    /// Danh sách gợi ý tự hoàn thành (FR-CORE-013).
    let completionPopup = CompletionPopup()
    /// Bật/tắt tự hoàn thành. Đặc tả đòi cấu hình được; đây là công tắc, Preferences sẽ nối vào.
    var completionEnabled = true

    /// Bàn làm sạch dữ liệu (FR-CLN-006).
    /// Truy vấn JSONPath — dựng khi mở lần đầu.
    /// Lượt kiểm JSONL đang chạy — để nút Huỷ có thứ để bấm vào.
    var jsonlCancelToken: CancelToken?
    var jsonlHeight: NSLayoutConstraint!
    /// Dòng đã hiện trên thẻ, để không dựng lại thẻ ở mỗi nhịp con nháy nhúc nhích.
    var jsonlShownLine = -1

    var retrievalHeight: NSLayoutConstraint!
    /// Chỉ mục đang mở, kèm tham số đã dùng để dựng nó.
    var retrievalIndex: (index: BM25Index, corpus: String, k1: Double, b: Double)?
    /// Corpus mà Retrieval Lab đã gắn vào lúc mở — xem `retrievalCorpusPath`.
    var retrievalBoundCorpus: String?
    /// Đồ thị dùng cho phép lai — FR-KNW-925. Nạp từ `<corpus>.dot`.
    var hybridGraph: GraphCSR?
    var hybridDictionary: HybridRetrieval.EntityDictionary?
    /// Corpus mà `hybridGraph` thuộc về.
    ///
    /// Thiếu nó thì mở một corpus khác vẫn dùng đồ thị của corpus trước — tín hiệu đồ thị khi
    /// ấy trỏ vào những entity không có trong tệp đang xem, và kết quả trông vẫn như một bảng
    /// xếp hạng. Một bài tự kiểm bắt được đúng chỗ này.
    var hybridGraphCorpus: String?
    var hybridConfig = HybridRetrieval.Config()
    var isHybridOn = false

    /// Đồ thị DOT đang xem, `nil` khi tài liệu không phải DOT — FR-KNW-905.
    var dotGraph: DOTGraph?
    /// CSR của đồ thị ấy, dựng MỘT lần và tái dùng — NFR-KNW-03 đòi thẳng.
    var graphCSR: GraphCSR?
    /// Kết quả phép soạn trực quan gần nhất — bài tự kiểm đọc để biết đường đi đã tới đâu
    /// (FR-KNW-915 · FR-MMD-004).
    var lastGraphEditForSelfTest: String?
    /// Câu nói ra khi bật công tắc soạn trực quan — bài tự kiểm đọc để chấm vế *"loại chưa hỗ
    /// trợ visual: hiển thị rõ chỉ soạn text"* (FR-MMD-004).
    var lastVisualEditNoticeForSelfTest: String?
    /// Tệp `.mmd` vừa tách ra — để nút «Mở tệp» trên banner có chỗ đi tới (FR-MMD-008).
    var lastSplitMermaidPath: String?
    /// Kiểu vẽ đang áp lên sơ đồ (màu cộng đồng, độ dày viền PageRank).
    var graphStyles: DOTToMermaid.NodeStyles = [:]
    var graphPageRank: GraphAlgorithms.PageRank?
    /// Kết quả chấm sức khoẻ gần nhất — FR-KNW-924.
    var graphQualityReport: GraphQuality.Report?
    var graphCommunities: GraphAlgorithms.Communities?
    var graphComponents: GraphAlgorithms.Components?

    /// Bộ đánh giá đang dựng — FR-KNW-926.
    var goldenBuilder: GoldenSetBuilder?
    /// id chunk → nguồn, để đếm phủ. Dựng MỘT lần khi bật chế độ gán nhãn.
    var goldenSourceMap: [String: String] = [:]
    var goldenDeclaredSources: [String] = []

    lazy var retrievalPanel: RetrievalPanel = {
        let view = RetrievalPanel()
        view.isHidden = true
        return view
    }()

    lazy var jsonlPanel: JSONLPanel = {
        let view = JSONLPanel()
        view.isHidden = true
        return view
    }()

    lazy var jsonPathPanel: JSONPathPanel = {
        let view = JSONPathPanel()
        view.isHidden = true
        return view
    }()

    private var jsonPathHeight: NSLayoutConstraint!

    /// Truy vấn SQL trên bảng CSV (FR-CSV-407) — dựng khi mở lần đầu.
    lazy var sqlPanel: SQLPanel = {
        let view = SQLPanel()
        view.isHidden = true
        return view
    }()

    private var sqlHeight: NSLayoutConstraint!
    /// Huỷ lượt truy vấn trước khi người dùng gõ câu mới.
    private var sqlToken: CancelToken?

    /// Đếm số lần hiện banner tạm, để lần hiện sau hủy hẹn giờ tắt của lần trước.
    private var transientBannerToken = 0

    /// Thư mục đang mở làm workspace, và quyền truy cập đang giữ cho nó.
    ///
    /// Giữ URL riêng chứ không suy lại từ đường dẫn: `SandboxAccess` phải được thả bằng ĐÚNG
    /// lượt đã mở, và thư mục mở từ bookmark có URL khác với chuỗi đường dẫn hiển thị.
    private(set) var workspaceRoot: String?

    /// Thư viện truy vấn của workspace đang mở (FR-QRY-001) — lịch sử và câu đã lưu.
    var queryLibrary = QueryLibrary()

    private var workspaceBookmark: Data?
    private var workspaceAccess: URL?

    /// Chỉ mục JSON của tài liệu hiện tại, dựng lười và bỏ đi khi văn bản đổi.
    ///
    /// Giữ lại giữa hai lần truy vấn vì người dùng gõ đi gõ lại nhiều truy vấn trên CÙNG một
    /// file; dựng lại chỉ mục cho mỗi lần nhấn Enter là trả giá phân tích cả file mỗi lần.
    /// Nhưng phải bỏ đi khi văn bản đổi, nếu không mọi khoảng byte đều trỏ lệch — và một cú
    /// nhảy tới SAI CHỖ thì tệ hơn không nhảy.
    ///
    /// Khóa gồm CẢ danh tính buffer, không riêng số revision. `revision` đếm từ 0 trong từng
    /// buffer, nên hai tài liệu khác nhau vẫn có thể cùng mang revision 1 — và bản nhớ của tài
    /// liệu này sẽ được dùng cho tài liệu kia. Bộ tự kiểm bắt được đúng ca ấy: mở panel trên
    /// một file, rồi mở file khác cũng vừa sửa một lần.
    private var cachedJSONIndex:
        (buffer: Int, revision: Int, index: JSONIndex, bytes: [UInt8])?

    /// Bàn làm sạch CSV — dựng khi mở lần đầu.
    lazy var cleanPanel: CSVCleanPanel = {
        let view = CSVCleanPanel()
        view.isHidden = true
        return view
    }()
    private var cleanHeight: NSLayoutConstraint!
    private var cleanToken: CancelToken?
    private var profileToken: CancelToken?
    private var recipeSheet: CSVRecipeSheet?
    /// Lần chạy công thức gần nhất — bài tự kiểm đọc để biết chuyện gì đã xảy ra.
    private(set) var lastRecipeRun: CSVRecipeRun?
    private(set) var lastBatchResult: CSVRecipeBatch.BatchResult?
    private var recipeToken: CancelToken?
    private var cleanSheet: CSVCleanSheet?
    /// Chuỗi đại diện cho ô thiếu, dùng chung cho cả phiên làm sạch của tài liệu này.
    private var nullSpec = CSVNullSpec.default

    // MARK: - Macro (FR-AUTO-601/602)
    private let macroRecorder = MacroRecorder()
    private var macroStore = MacroStore()
    /// Macro vừa ghi hoặc vừa chọn — thứ mà "Phát lại" sẽ chạy.
    private var currentMacro: Macro?
    private var macroCancelToken: CancelToken?
    private var snapshotStore = SnapshotStore()

    /// `documentID` của những tài liệu chưa lưu mà phiên vừa mở lại.
    ///
    /// Để chỗ hỏi "còn N bản nháp" đừng hỏi lại đúng những thứ đã mở — hỏi lại là mời người
    /// dùng mở trùng cùng một nội dung thành hai tab.
    private(set) var restoredDocumentIDs: Set<String> = []

    /// Ảnh chụp trạng thái phiên hiện tại.
    var currentSession: Session {
        let entries = tabs.enumerated().map { index, tab in
            SessionTab(
                path: tab.document.path,
                documentID: tab.document.id,
                caretOffset: index == activeIndex
                    ? editorView.selectedDocumentRange.lowerBound
                    : tab.caretOffset,
                isPinned: tab.isPinned,
                colorIndex: tab.colorIndex,
                isModified: tab.document.isModified,
                bookmark: tab.document.accessBookmark
            )
        }
        let frame = window.map { [Double($0.frame.minX), Double($0.frame.minY),
                                  Double($0.frame.width), Double($0.frame.height)] }
        return Session(windows: [
            SessionWindow(
                tabs: entries, activeTabIndex: activeIndex, frame: frame,
                split: isSplit
                    ? SessionSplit(isVertical: splitView.isVertical,
                                   secondTabIndex: paneTabIndices[1])
                    : nil,
                workspacePath: workspaceRoot,
                workspaceBookmark: workspaceBookmark
            ),
        ])
    }

    /// Ghi phiên ra đĩa.
    ///
    /// Lỗi ghi chỉ ghi log chứ không quấy người dùng: phiên là tiện lợi, không phải dữ liệu
    /// của họ. Dữ liệu của họ nằm ở bản nháp và ở file đã lưu, cả hai đều có đường riêng và
    /// đều báo lỗi ra mặt khi hỏng.
    func saveSession() {
        do {
            try sessionStore.save(currentSession.pruned())
        } catch {
            NSLog("[GEditor] không ghi được phiên: %@", String(describing: error))
        }
    }

    /// Mở lại phiên trước. Trả về số tab đã khôi phục.
    ///
    /// Thứ tự quan trọng: mở theo đúng thứ tự tab cũ, rồi mới đặt tab đang mở — người dùng
    /// nhớ vị trí tab bằng mắt, và xáo thứ tự là bắt họ tìm lại từ đầu.
    @discardableResult
    func restoreSession() -> Int {
        guard let session = try? sessionStore.load(), !session.isEmpty,
              let window = session.pruned().windows.first
        else { return 0 }
        return restoreSession(window: window)
    }

    /// Khôi phục MỘT cửa sổ của phiên (FR-DOC-302: phiên có thể có nhiều cửa sổ).
    ///
    /// Tách khỏi `restoreSession()` vì `WindowManager` cần khôi phục từng cửa sổ vào từng
    /// controller — mỗi controller chỉ biết về tab của CHÍNH nó, và trộn hai việc lại thì cửa
    /// sổ thứ hai sẽ đọc lại phiên từ đĩa và mở trùng tab của cửa sổ thứ nhất.
    @discardableResult
    func restoreSession(window: SessionWindow) -> Int {
        let snapshots = snapshotStore

        // Workspace trước tài liệu: cây thư mục là bối cảnh, và nó nên có mặt sẵn khi các tab
        // hiện ra chứ không nhảy vào sau một nhịp.
        if let bookmark = window.workspaceBookmark {
            if !restoreWorkspace(bookmark: bookmark, path: window.workspacePath) {
                // Thư mục đã biến mất. NÓI RA — một cây thư mục rỗng trông giống hệt một thư
                // mục thật sự không có file nào, và người dùng sẽ đi tìm lỗi ở chỗ khác.
                let name = (window.workspacePath as NSString?)?.lastPathComponent ?? L("trước đó")
                showTransient(LF("Không mở lại được thư mục «%@» của phiên trước", name))
            }
        }

        let pending = (try? snapshots.pendingSnapshots()) ?? []
        var restored: [EditorTab] = []
        var missing: [String] = []

        for entry in window.tabs {
            // Ưu tiên BẢN NHÁP: nếu tab ấy có nội dung chưa lưu thì bản trên đĩa là bản CŨ.
            if entry.isModified,
               let snapshot = pending.first(where: { $0.documentID == entry.documentID }),
               let document = try? Document.restore(snapshot, store: snapshots) {
                restoredDocumentIDs.insert(entry.documentID)
                restored.append(EditorTab(document: document, caretOffset: entry.caretOffset,
                                          isPinned: entry.isPinned, colorIndex: entry.colorIndex))
                continue
            }
            // BOOKMARK TRƯỚC, đường dẫn sau.
            //
            // Trong App Sandbox, đường dẫn trần không mở được file người dùng đã chọn ở phiên
            // TRƯỚC — quyền chết theo lần chạy app. Thử đường dẫn trước rồi mới tới bookmark thì
            // ở bản App Store mọi tab đều rơi vào nhánh "không mở được", im lặng.
            if let bookmark = entry.bookmark,
               let document = Self.openAnyDocument(bookmark: bookmark, path: entry.path) {
                restored.append(EditorTab(document: document, caretOffset: entry.caretOffset,
                                          isPinned: entry.isPinned, colorIndex: entry.colorIndex))
                continue
            }

            guard let path = entry.path else { continue }
            guard FileManager.default.fileExists(atPath: path) else {
                // File đã bị xóa hoặc đổi tên từ phiên trước. Bỏ qua tab ấy và NÓI RA — mở
                // lại thiếu một tab mà im lặng thì người dùng tưởng mình nhớ nhầm.
                missing.append((path as NSString).lastPathComponent)
                continue
            }
            guard let document = try? Self.openAnyDocument(path: path) else {
                missing.append((path as NSString).lastPathComponent)
                continue
            }
            restored.append(EditorTab(document: document, caretOffset: entry.caretOffset,
                                      isPinned: entry.isPinned, colorIndex: entry.colorIndex))
        }

        guard !restored.isEmpty else {
            if !missing.isEmpty { reportMissingFromSession(missing) }
            return 0
        }

        tabs = restored
        activePaneIndex = 0
        paneTabIndices = [min(window.activeTabIndex, restored.count - 1), 0]
        applyActiveTab()

        // Chia đôi cũng là "trạng thái phiên làm việc" (FR-DOC-303): mở lại mà mất nó thì
        // người dùng phải dựng lại bố cục màn hình mỗi sáng.
        if let split = window.split {
            openSplit(vertical: split.isVertical)
            paneTabIndices[1] = min(max(split.secondTabIndex, 0), restored.count - 1)
            showPane(1)
        }
        refreshTabBar()
        if !missing.isEmpty { reportMissingFromSession(missing) }
        return restored.count
    }

    private func reportMissingFromSession(_ names: [String]) {
        let list = names.prefix(3).joined(separator: ", ")
        let extra = names.count > 3
            ? LF(" (và %d file khác)", names.count - 3) : ""
        showRestoreBanner(LF("Không mở lại được %d tab: %@%@ — file không còn ở chỗ cũ.",
                                 names.count, list, extra))
    }

    // MARK: - Lệnh File

    @objc func newDocument(_ sender: Any?) {
        guard confirmDiscardChanges() else { return }
        loadDocument(.untitled())
    }

    @objc func openDocument(_ sender: Any?) {
        guard confirmDiscardChanges() else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        open(path: url.path)
    }

    func open(path: String, line: Int? = nil, column: Int? = nil, readOnly: Bool = false) {
        openInNewTab(path: path, line: line, column: column, readOnly: readOnly)
    }

    /// Mở nội dung từ ống dẫn thành tab chưa có tên (`ps aux | geditor`).
    func openPipedContent(temporaryPath: String) {
        do {
            loadDocument(try Document.fromPipe(temporaryPath: temporaryPath))
        } catch {
            unlink(temporaryPath)   // không mở được thì cũng không để lại rác trong /tmp
            presentError(L("Không đọc được nội dung từ ống dẫn"), error)
        }
    }

    /// Đặt con trỏ vào dòng/cột (1-based) — dùng cho `geditor file:120:5`.
    func goTo(line: Int, column: Int?) {
        let target = min(max(1, line), editorDocument.buffer.lineCount) - 1
        var offset = editorDocument.buffer.offset(ofLineStart: target)
        if let column, column > 1 {
            let lineEnd = editorDocument.buffer.contentRange(ofLine: target).upperBound
            offset = min(offset + column - 1, lineEnd)
        }
        editorView.setCaret(documentOffset: offset)
        editorView.reveal(documentOffset: offset)
        updateCaretStatus()
    }

    @objc func saveDocument(_ sender: Any?) {
        // Tài liệu Office: buffer là CSV/Markdown còn tệp trên đĩa là OOXML. Đường lưu chung sẽ
        // ghi buffer đè lên tệp và xoá sạch mọi thứ bộ đọc không hiểu, nên nó phải rẽ ở đây —
        // TRƯỚC mọi thứ khác, không phải trong một nhánh nào đó sâu bên dưới.
        if let kind = editorDocument.mediaKind {
            return saveOfficeDocument(kind: kind)
        }
        guard editorDocument.path != nil else { return saveDocumentAs(sender) }
        performSave { try self.editorDocument.save(allowLossy: $0) }
    }

    /// ⌘S cho tài liệu Office.
    ///
    /// Excel đi được cả đường: so lưới cũ với lưới đang hiện, rồi sửa ĐÚNG những ô đã đổi trong
    /// XML gốc. Word và PowerPoint thì chưa — và chúng phải NÓI RA điều đó kèm đường lui, chứ
    /// không im lặng không làm gì.
    private func saveOfficeDocument(kind: MediaKind) {
        guard let path = editorDocument.path, kind.isOfficeOpenXML else {
            showBanner(
                LF("Chưa ghi ngược được vào tệp %@ — hãy dùng «Lưu thành…»",
                       kind.displayName),
                actionTitle: L("Lưu thành…"), action: #selector(saveDocumentAs(_:)))
            return
        }
        do {
            let count: Int
            let unit: String
            switch kind {
            case .excel:
                count = try saveSpreadsheet(path: path)
                unit = L("Đã ghi %d ô vào %@")
            case .word:
                count = try saveWordDocument(path: path)
                unit = L("Đã ghi %d đoạn vào %@")
            default:
                count = try savePresentation(path: path)
                unit = L("Đã ghi %d đoạn vào %@")
            }
            guard count > 0 else { return showTransient(L("Không có gì đổi")) }
            editorDocument.markSavedForOffice()
            refreshChrome()
            showTransient(String(format: unit, count, (path as NSString).lastPathComponent))
        } catch {
            // Ghi hỏng thì tệp gốc CÒN NGUYÊN — `writeInPlace` chỉ thay tệp sau khi bản mới đã
            // đọc lại đúng. Nói cả hai vế, vì "không lưu được" một mình sẽ khiến người dùng
            // tưởng họ vừa mất tệp.
            presentError(L("Không ghi được vào tệp — bản gốc còn nguyên"), error)
        }
    }

    /// Ghi ô đã sửa ngược vào `.xlsx`. Trả về số ô đã ghi.
    private func saveSpreadsheet(path: String) throws -> Int {
        let reader = try XLSXReader(path: path)
        // Nhắm vào sheet ĐANG XEM, không phải sheet đầu.
        //
        // Tên không còn trong tệp — người dùng vừa đổi tên hay xoá sheet ấy trong Excel — thì
        // TỪ CHỐI ghi. Rơi về sheet đầu nghĩa là đổ nội dung của một sheet lên một sheet khác,
        // và cách hỏng ấy im lặng: tệp vẫn ghi được, vẫn mở lại được, chỉ là sai chỗ.
        let sheet: XLSXReader.Sheet
        if let wanted = editorDocument.spreadsheetSheet {
            guard let found = reader.sheets.first(where: { $0.name == wanted }) else {
                throw XLSXReader.Failure.sheetNotFound(wanted)
            }
            sheet = found
        } else {
            guard let first = reader.sheets.first else { throw XLSXReader.Failure.noSheets }
            sheet = first
        }
        let before = try reader.grid(of: sheet).rows
        let after = Self.grid(fromCSV: editorDocument.buffer.text, dialect: csvDialect)

        // Ba loại sửa, và chúng phải đi ba đường khác nhau:
        //
        //   1. Cùng số hàng          → chỉ vài ô đổi, không đụng tham chiếu nào.
        //   2. Thêm/bớt ở CUỐI       → không hàng nào đang có bị dịch số hiệu.
        //   3. Chèn/xoá ở GIỮA       → phải dịch lại MỌI tham chiếu A1 trong tệp.
        //
        // Gộp cả ba vào một đường nghĩa là chạy phép dịch tham chiếu cho cả những lượt không
        // cần — mỗi lượt chạy thừa là một cơ hội làm hỏng một tệp không có gì phải sửa.
        if before.count == after.count {
            let diff = try XLSXWriter.diff(from: before, to: after)
            try XLSXWriter.writeInPlace(source: path, sheet: sheet, diff: diff)
            return diff.changes.count
        }

        let plan = XLSXRowEditor.plan(from: before, to: after)
        if plan.shift.at + plan.shift.deleted >= before.count, plan.shift.deleted >= 0,
           plan.shift.at >= before.count - plan.shift.deleted {
            // Phép sửa nằm trọn ở CUỐI bảng — đường rẻ, không cần dịch tham chiếu.
            let diff = try XLSXWriter.diff(from: before, to: after)
            try XLSXWriter.writeInPlace(source: path, sheet: sheet, diff: diff)
            return diff.changes.count + diff.appended.count + diff.truncated
        }

        try XLSXWriter.writeRowEditInPlace(
            source: path, sheet: sheet, shift: plan.shift, insertedRows: plan.inserted)
        return plan.shift.inserted + plan.shift.deleted
    }

    /// Ghi đoạn đã sửa ngược vào `.pptx`. Trả về số đoạn đã ghi.
    private func savePresentation(path: String) throws -> Int {
        let original = try PPTXReader.read(path: path)
        let text = editorDocument.buffer.text

        // Số dòng đổi nghĩa là thêm/xoá dòng chữ trong slide — đường riêng, cùng lối với Word.
        if let plan = try PPTXParagraphEditor.plan(from: original, to: text) {
            try PPTXParagraphEditor.writeInPlace(source: path, plan: plan)
            return plan.deletedParagraphs.count + plan.insertedTexts.count
        }

        let changes = try PPTXWriter.changes(from: original, to: text)
        try PPTXWriter.writeInPlace(source: path, changes: changes)
        return changes.count
    }

    /// Ghi đoạn đã sửa ngược vào `.docx`. Trả về số đoạn đã ghi.
    ///
    /// Đọc LẠI tệp gốc để lấy bản Markdown ban đầu thay vì nhớ nó từ lúc mở: nhớ thì phải giữ
    /// đồng bộ qua mọi đường (mở lại khi file đổi ngoài, khôi phục phiên, hoàn tác), và một
    /// bản gốc lỗi thời sẽ sinh ra danh sách thay đổi sai. Đọc lại là vài mili-giây.
    private func saveWordDocument(path: String) throws -> Int {
        let original = try DOCXReader.read(path: path)
        let text = editorDocument.buffer.text

        // Số dòng đổi nghĩa là THÊM hoặc XOÁ đoạn — một phép sửa khác hẳn với sửa chữ, và nó
        // đi đường riêng. Gộp hai đường thì phép sửa chữ sẽ phải mang theo cả bộ máy dựng đoạn
        // mới, tức chạy thừa cho lượt lưu thường gặp nhất.
        if original.markdown.components(separatedBy: "\n").count
            != text.components(separatedBy: "\n").count {
            let plan = try DOCXParagraphEditor.plan(from: original, to: text)
            try DOCXParagraphEditor.writeInPlace(source: path, plan: plan)
            return plan.deletedParagraphs.count + plan.insertedTexts.count
        }

        let changes = try DOCXWriter.changes(from: original, to: text)
        try DOCXWriter.writeInPlace(source: path, changes: changes)
        return changes.count
    }

    /// Đọc văn bản CSV thành lưới, dùng chính bộ phân tích CSV của lõi.
    ///
    /// Không tự tách theo dấu phẩy: ô có dấu phẩy trong ngoặc kép sẽ vỡ, và bảng lệch cột từ
    /// đó trở đi. `CSVEngine` đã có luật ấy và đã có bài kiểm.
    static func grid(fromCSV text: String, dialect: CSVDialect) -> [[String]] {
        let buffer = TextBuffer(text: text)
        var rows: [[String]] = []
        try? CSVEngine.forEachRow(in: buffer, dialect: dialect) { fields in
            rows.append(fields.map { field in
                let raw = buffer.bytes(in: field.range)
                return String(decoding: CSVEngine.unescape(raw, dialect: dialect), as: UTF8.self)
            })
            return true
        }
        return rows
    }

    /// Cắt khoảng trắng cuối dòng ngay trước khi ghi, nếu tuỳ chọn đang bật (FR-CORE-008).
    ///
    /// Là một bước hoàn tác RIÊNG, đứng trước phép ghi. Gộp nó vào thao tác cuối cùng của
    /// người dùng thì ⌘Z sau khi lưu sẽ gỡ luôn cả thứ họ vừa gõ; tách ra thì họ gỡ đúng phần
    /// máy tự làm.
    private func applyTrimOnSaveIfEnabled() {
        guard trimsTrailingWhitespaceOnSave, !editorDocument.isReadOnly else { return }
        guard let edits = try? DocumentOps.trimLines(in: editorDocument.buffer, side: .trailing),
              !edits.isEmpty else { return }
        apply(edits, label: L("Cắt khoảng trắng khi lưu"))
    }

    @objc func toggleTrimOnSave(_ sender: Any?) {
        trimsTrailingWhitespaceOnSave.toggle()
        showTransient(
            trimsTrailingWhitespaceOnSave
                ? L("Sẽ cắt khoảng trắng cuối dòng mỗi lần lưu")
                : L("Không cắt khoảng trắng khi lưu nữa")
        )
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = editorDocument.path.map { ($0 as NSString).lastPathComponent }
            ?? L("Chưa đặt tên.txt")

        // Bảng mã và kiểu xuống dòng chọn NGAY TRONG hộp lưu — SRS FR-DOC-314.
        //
        // Trước đây chúng chỉ đổi được qua thanh trạng thái TRƯỚC khi lưu, nên "lưu một bản
        // UTF-16 cho máy Windows" là ba thao tác ở ba chỗ, và sau đó tài liệu đang mở bị đổi
        // theo — người dùng phải nhớ đổi ngược lại. Ở đây thì lựa chọn chỉ áp cho LẦN LƯU NÀY.
        let encodingPopUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        let encodings = TextEncoding.allCases.filter(\.isAvailable)
        encodingPopUp.addItems(withTitles: encodings.map(\.displayName))
        encodingPopUp.selectItem(at: encodings.firstIndex(of: editorDocument.targetEncoding) ?? 0)

        let eolPopUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        let eols: [EOL] = [.lf, .crlf, .cr]
        eolPopUp.addItems(withTitles: eols.map(\.rawValue))
        eolPopUp.selectItem(at: eols.firstIndex(of: editorDocument.eol ?? .lf) ?? 0)

        let row = NSStackView(views: [
            NSTextField(labelWithString: L("Bảng mã:")), encodingPopUp,
            NSTextField(labelWithString: L("Xuống dòng:")), eolPopUp,
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Tokens.Metrics.spacing(2)
        row.frame = NSRect(x: 0, y: 0, width: 560, height: 40)
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        panel.accessoryView = row

        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        let encoding = encodings[max(0, min(encodingPopUp.indexOfSelectedItem, encodings.count - 1))]
        let eol = eols[max(0, min(eolPopUp.indexOfSelectedItem, eols.count - 1))]
        saveDocumentAsForSelfTest(path: url.path, encoding: encoding, eol: eol)
    }

    /// Phần LÀM VIỆC của `saveDocumentAs`, tách khỏi hộp chọn tệp.
    func saveDocumentAsForSelfTest(path: String, encoding: TextEncoding, eol: EOL) {
        // Đổi EOL đi qua ĐÚNG đường mà nút «chuẩn hoá» trên dải băng đi: một bước hoàn tác,
        // báo cáo EOL dựng lại, view đồng bộ. Tự sửa buffer ở đây là đường thứ hai cho cùng
        // một việc, và hai đường thì có ngày lệch nhau.
        if eol != (editorDocument.eol ?? .lf) { applyNormalizeEOL(to: eol) }
        editorDocument.setTargetEncoding(encoding)
        performSave { try self.editorDocument.save(to: path, allowLossy: $0) }
    }

    // MARK: - Nhân bản · đổi tên · chuyển tệp (FR-DOC-314)

    /// Nhân bản tệp đang mở, rồi MỞ bản sao thành tab mới.
    ///
    /// Mở bản sao chứ không im lặng tạo tệp: người ta nhân bản để sửa bản sao. Để họ tự đi tìm
    /// nó trong Finder là bắt họ làm nốt phần việc của lệnh.
    ///
    /// Tên bản sao theo lối Finder — `bao-cao 2.txt` — và tăng số tới khi không đụng tệp nào.
    /// Ghi đè một tệp có sẵn ở đây là mất dữ liệu do một lệnh không hề hứa sẽ ghi gì.
    @objc func duplicateDocument(_ sender: Any?) {
        guard let path = editorDocument.path else {
            return showTransient(L("Lưu tệp trước khi nhân bản."))
        }
        let target = Self.duplicatePath(for: path)
        do {
            try FileManager.default.copyItem(atPath: path, toPath: target)
        } catch {
            return presentError(L("Không nhân bản được"), error)
        }
        openInNewTab(path: target)
        showTransient(LF("Đã nhân bản thành %@", (target as NSString).lastPathComponent))
    }

    /// Đường dẫn bản sao đầu tiên chưa bị chiếm.
    static func duplicatePath(for path: String) -> String {
        let ns = path as NSString
        let folder = ns.deletingLastPathComponent
        let ext = ns.pathExtension
        let base = (ns.lastPathComponent as NSString).deletingPathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            let candidate = (folder as NSString).appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: candidate) { return candidate }
            index += 1
        }
    }

    /// Đổi tên tệp trên đĩa, giữ nguyên tab đang mở.
    @objc func renameDocument(_ sender: Any?) {
        guard let path = editorDocument.path else {
            return showTransient(L("Lưu tệp trước khi đổi tên."))
        }
        let alert = NSAlert()
        alert.messageText = L("Đổi tên tệp")
        alert.informativeText = LF("Tên hiện tại: %@", (path as NSString).lastPathComponent)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = (path as NSString).lastPathComponent
        alert.accessoryView = field
        alert.addButton(withTitle: L("Đổi tên"))
        alert.addButton(withTitle: "Hủy")
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        renameDocumentForSelfTest(to: field.stringValue)
    }

    /// Phần LÀM VIỆC của `renameDocument`. Trả `false` khi không đổi được.
    @discardableResult
    func renameDocumentForSelfTest(to name: String) -> Bool {
        guard let path = editorDocument.path else { return false }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Tên rỗng hoặc có dấu `/` là đường dẫn, không phải tên: `FileManager` sẽ hiểu nó
        // thành "chuyển sang thư mục khác", tức một việc KHÁC hẳn việc người dùng vừa gọi.
        guard !clean.isEmpty, !clean.contains("/") else {
            showTransient(L("Tên tệp không hợp lệ"))
            return false
        }
        let target = ((path as NSString).deletingLastPathComponent as NSString)
            .appendingPathComponent(clean)
        guard target != path else { return true }
        guard !FileManager.default.fileExists(atPath: target) else {
            showTransient(LF("Đã có tệp tên %@ ở đó", clean))
            return false
        }
        return moveDocumentFile(from: path, to: target)
    }

    /// Chuyển tệp sang thư mục khác, giữ nguyên tab đang mở.
    @objc func moveDocument(_ sender: Any?) {
        guard let path = editorDocument.path else {
            return showTransient(L("Lưu tệp trước khi chuyển."))
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L("Chuyển tới")
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        moveDocumentForSelfTest(toFolder: url.path)
    }

    @discardableResult
    func moveDocumentForSelfTest(toFolder folder: String) -> Bool {
        guard let path = editorDocument.path else { return false }
        let target = (folder as NSString)
            .appendingPathComponent((path as NSString).lastPathComponent)
        guard target != path else { return true }
        guard !FileManager.default.fileExists(atPath: target) else {
            showTransient(LF("Thư mục đích đã có tệp tên %@",
                             (path as NSString).lastPathComponent))
            return false
        }
        return moveDocumentFile(from: path, to: target)
    }

    /// Dời tệp trên đĩa RỒI trỏ tài liệu đang mở sang chỗ mới.
    ///
    /// Thứ tự ấy bắt buộc: đổi đường dẫn của tài liệu trước rồi dời hỏng giữa chừng thì tab
    /// đang mở trỏ vào một tệp không tồn tại, và lần ⌘S sau đó ghi ra một tệp mới ở chỗ không
    /// ai chờ. Cùng lối "ghi tệp TRƯỚC, sửa tài liệu SAU" của FR-MMD-008.
    ///
    /// Bản nháp tự động bị bỏ đi sau khi dời: nó khoá theo đường dẫn CŨ, nên giữ lại là để sẵn
    /// một bản khôi phục trỏ vào chỗ không còn gì.
    private func moveDocumentFile(from path: String, to target: String) -> Bool {
        do {
            try FileManager.default.moveItem(atPath: path, toPath: target)
        } catch {
            presentError(L("Không chuyển được tệp"), error)
            return false
        }
        try? editorDocument.discardSnapshot()
        cliBridge?.documentClosed(path: path)
        editorDocument.retarget(to: target)
        noteRecentDocument(target)
        refreshChrome()
        refreshTabBar()
        saveSession()
        showTransient(LF("Đã chuyển tới %@", target))
        return true
    }

    /// Chạy một phép lưu, hỏi lại khi bảng mã đích làm mất ký tự.
    ///
    /// Lõi TỪ CHỐI lưu mất dữ liệu trừ khi được truyền `allowLossy: true`, nên chỗ duy nhất
    /// quyết định là ở đây — và nó phải là một câu hỏi hiện ra trước mắt người dùng, kèm số
    /// ký tự sẽ mất (FR-ENC-203).
    private func performSave(_ save: (Bool) throws -> Document.SaveResult) {
        applyTrimOnSaveIfEnabled()
        do {
            _ = try save(false)
            refreshChrome()
            try? editorDocument.discardSnapshot()
        } catch Document.Failure.lossyConversion(let preview) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L("Chuyển đổi bảng mã sẽ làm mất ký tự")
            alert.informativeText = preview.warning ?? ""
            alert.addButton(withTitle: "Hủy")
            alert.addButton(withTitle: L("Vẫn lưu"))
            guard Unattended.ask(alert) == .alertSecondButtonReturn else { return }
            do {
                _ = try save(true)
                refreshChrome()
                try? editorDocument.discardSnapshot()
            } catch {
                presentError("Không lưu được", error)
            }
        } catch {
            presentError("Không lưu được", error)
        }
    }

    /// Hỏi trước khi bỏ thay đổi chưa lưu. Trả `false` = người dùng hủy thao tác.
    private func confirmDiscardChanges() -> Bool {
        guard editorDocument.isModified else { return true }
        let alert = NSAlert()
        alert.messageText = L("Tài liệu có thay đổi chưa lưu")
        alert.informativeText = L("Đóng mà không lưu thì phần chưa lưu sẽ mất.")
        alert.addButton(withTitle: "Hủy")
        alert.addButton(withTitle: L("Bỏ thay đổi"))
        return Unattended.ask(alert) == .alertSecondButtonReturn
    }

    // MARK: - Lệnh Edit

    @objc func undoDocument(_ sender: Any?) {
        guard editorDocument.buffer.undo() else { return }
        syncViewFromBuffer()
        refreshChrome()
    }

    @objc func redoDocument(_ sender: Any?) {
        guard editorDocument.buffer.redo() else { return }
        syncViewFromBuffer()
        refreshChrome()
    }

    // MARK: - Lệnh Search

    /// FR-SRCH-111 — Đi tới dòng (⌘L).
    ///
    /// Ba cách viết, phân biệt bằng chính chuỗi đã gõ — xem `GoToTarget`.
    @objc func goToLine(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = L("Đi tới")
        alert.informativeText = LF("Tài liệu có %d dòng, %d byte. Gõ số dòng, «dòng,cột», "
            + "hoặc «@vị trí byte».", editorDocument.buffer.lineCount, editorDocument.buffer.count)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = L("12 · 12,5 · @1024")
        alert.accessoryView = field
        alert.addButton(withTitle: L("Đi tới"))
        alert.addButton(withTitle: "Hủy")
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        goToForSelfTest(field.stringValue)
    }

    /// Đi tới một vị trí theo chuỗi người dùng gõ. Trả `false` khi không hiểu chuỗi ấy.
    ///
    /// Tách khỏi phần hỏi vì đúng lý do đã ghi ở `buildModeMenu`: `NSAlert` không chạy được
    /// trong lượt kiểm không người, mà phần đáng kiểm là phép ĐI TỚI chứ không phải cái hộp.
    @discardableResult
    func goToForSelfTest(_ text: String) -> Bool {
        guard let target = GoToTarget.parse(text) else {
            showTransient(LF("Không hiểu «%@» — gõ số dòng, «dòng,cột», hoặc «@vị trí byte»",
                             text))
            return false
        }

        let buffer = editorDocument.buffer
        let offset: Int
        switch target {
        case .offset(let byte):
            // Kẹp vào tài liệu thay vì từ chối: người dùng chép offset từ một log của lần chạy
            // trước, và tệp có thể đã ngắn đi. Đưa họ tới cuối tệp là câu trả lời hữu ích hơn
            // một lời từ chối.
            offset = min(byte, buffer.count)
        case .line(let line, let column):
            let target = min(line, buffer.lineCount) - 1
            let start = buffer.offset(ofLineStart: target)
            guard let column, column > 1 else {
                offset = start
                break
            }
            // Cột đếm theo KÝ TỰ, offset đếm theo BYTE — với tiếng Việt hai con số ấy khác
            // nhau. Đi từ đầu dòng và bước theo ký tự, rồi kẹp trong đúng dòng ấy: gõ cột 500
            // trên một dòng 20 ký tự phải dừng ở cuối dòng, không tràn sang dòng sau.
            let text = buffer.line(target)
            let index = text.index(text.startIndex, offsetBy: column - 1,
                                   limitedBy: text.endIndex) ?? text.endIndex
            offset = start + text[text.startIndex ..< index].utf8.count
        }

        editorView.repaginate(around: offset)
        // Offset của lõi là BYTE; NSTextView đếm theo UTF-16 nên phải quy đổi (FR-CORE-018).
        editorView.setCaret(documentOffset: offset)
        editorView.reveal(documentOffset: offset)
        updateCaretStatus()
        return true
    }

    // MARK: - Bảng mã và EOL (FR-ENC-203, FR-ENC-204, FR-UI-805)

    /// Menu đổi bảng mã — HAI NHÓM TÁCH BẠCH.
    ///
    /// Đây là chỗ dễ mất dữ liệu nhất trong cả sản phẩm, nên hai nhóm không được trộn:
    ///  · "Diễn giải lại theo…" đọc lại BYTE GỐC — chữ trên màn hình đổi, file không đổi.
    ///  · "Chuyển đổi sang…" giữ chữ, đổi byte khi lưu — có thể mất ký tự.
    @objc func showEncodingMenu(_ sender: Any?) {
        let menu = NSMenu()

        addEncodingSection(
            to: menu, title: L("Diễn giải lại theo…"),
            action: #selector(reinterpretEncoding(_:)), current: editorDocument.encoding
        )
        menu.addItem(.separator())
        addEncodingSection(
            to: menu, title: L("Chuyển đổi sang…"),
            action: #selector(convertEncoding(_:)), current: editorDocument.targetEncoding
        )

        present(menu, from: sender)
    }

    /// Bung menu NEO VÀO NÚT đã bấm, không neo vào vị trí chuột.
    ///
    /// Neo vào chuột thì menu bung xuống dưới và bị cắt cụt khi nút nằm sát đáy màn hình —
    /// mà thanh trạng thái thì LUÔN nằm sát đáy. Neo vào view để AppKit tự lật lên trên.
    private func present(_ menu: NSMenu, from sender: Any?) {
        // Không có ai bấm được thì đừng bung ra: `popUp` chạy một vòng lặp modal và cả lượt
        // chạy đứng im — cùng đúng cái bẫy `Unattended` sinh ra để chặn, chỉ khác là ở
        // `NSMenu` chứ không ở `NSAlert`. Menu vẫn được DỰNG đầy đủ và cất lại, nên bài kiểm
        // bấm đúng đường con chuột đi rồi soi thứ đáng lẽ bung ra.
        if Unattended.isActive {
            lastPresentedMenu = menu
            return
        }
        if let view = sender as? NSView {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    /// Một nhóm trong menu bảng mã: Unicode và tiếng Việt hiện thẳng, phần còn lại vào menu con.
    ///
    /// 36 bảng mã × 2 nhóm = 72 dòng phẳng thì không ai tìm nổi. Menu con giữ danh sách ngắn
    /// mà vẫn không giấu mất bảng mã nào.
    private func addEncodingSection(
        to menu: NSMenu, title: String, action: Selector, current: TextEncoding
    ) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        func makeItem(_ encoding: TextEncoding, indented: Bool) -> NSMenuItem {
            let item = NSMenuItem(
                title: indented ? "    \(encoding.displayName)" : encoding.displayName,
                action: action, keyEquivalent: ""
            )
            item.target = self
            item.representedObject = encoding.rawValue
            item.state = encoding == current ? .on : .off
            return item
        }

        for family in TextEncoding.Family.allCases {
            // Bảng mã máy không có bộ chuyển đổi thì KHÔNG hiện: một mục bấm vào không làm gì
            // còn tệ hơn một mục không có.
            let encodings = TextEncoding.allCases.filter { $0.family == family && $0.isAvailable }
            guard !encodings.isEmpty else { continue }

            if family.isPrimary {
                encodings.forEach { menu.addItem(makeItem($0, indented: true)) }
            } else {
                let submenu = NSMenu()
                encodings.forEach { submenu.addItem(makeItem($0, indented: false)) }
                let item = NSMenuItem(title: "    \(family.displayName)", action: nil, keyEquivalent: "")
                item.submenu = submenu
                // Dấu tích phải nổi lên tận mục cha, nếu không thì bảng mã đang dùng bị giấu
                // sau một menu con và người dùng không biết mình đang ở đâu.
                if encodings.contains(current) { item.state = .on }
                menu.addItem(item)
            }
        }
    }

    @objc private func reinterpretEncoding(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let encoding = TextEncoding(rawValue: raw) else { return }
        do {
            try editorDocument.reinterpret(as: encoding)
            syncViewFromBuffer()
            refreshChrome()
            hideBanner()
        } catch {
            presentError(L("Không diễn giải lại được"), error)
        }
    }

    @objc private func convertEncoding(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let encoding = TextEncoding(rawValue: raw) else { return }
        let preview = editorDocument.previewConversion(to: encoding)
        if preview.isLossy {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = LF("Bảng mã %@ không chứa hết ký tự",
                                       encoding.displayName)
            alert.informativeText = preview.warning ?? ""
            alert.addButton(withTitle: "Hủy")
            alert.addButton(withTitle: L("Vẫn chọn"))
            guard Unattended.ask(alert) == .alertSecondButtonReturn else { return }
        }
        editorDocument.setTargetEncoding(encoding)
        refreshChrome()
    }

    @objc func showEOLMenu(_ sender: Any?) {
        let menu = NSMenu()
        for eol in EOL.allCases {
            let item = NSMenuItem(
                title: eol.rawValue, action: #selector(setEOL(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = eol.rawValue
            item.state = eol == editorDocument.eol ? .on : .off
            menu.addItem(item)
        }
        present(menu, from: sender)
    }

    @objc private func setEOL(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let eol = EOL(rawValue: raw) else { return }
        applyNormalizeEOL(to: eol)
    }

    @objc private func normalizeEOLFromBanner() {
        applyNormalizeEOL(to: editorDocument.eol ?? .lf)
    }

    private func applyNormalizeEOL(to eol: EOL) {
        let edits = editorDocument.normalizeEOL(to: eol)
        guard !edits.isEmpty else { return hideBanner() }
        editorDocument.buffer.applyEdits(edits, label: L("Chuẩn hóa xuống dòng"))
        editorDocument.refreshEOLReport()
        syncViewFromBuffer()
        refreshChrome()
        hideBanner()
    }

    // MARK: - Status bar

    /// Bấm một mục trên thanh trạng thái.
    ///
    /// Lời hứa của UI/UX §3 là **mọi** mục đổi được bằng một cú bấm — đó là điểm khác biệt so
    /// với status bar chỉ-đọc của editor khác. Bốn mục cuối (`mode`, `language`, `tabWidth`,
    /// `readOnly`) từng rơi vào `default: break`, tức bấm vào không có gì xảy ra: người dùng
    /// không phân biệt được "chưa làm" với "hỏng", và họ thử lại vài lần trước khi bỏ cuộc.
    ///
    /// **Và `default` đã bị bỏ hẳn khỏi `switch` này, có chủ ý.** Thêm một mục mới vào
    /// `StatusBarView.Segment` mà quên nối thì lỗi biên dịch — rẻ hơn và chắc hơn mọi bài kiểm
    /// viết ra để canh cùng chuyện ấy. Đừng thêm `default` lại.
    private func handleStatusBarClick(_ segment: StatusBarView.Segment) {
        switch segment {
        case .encoding: showEncodingMenu(nil)
        case .eol: showEOLMenu(nil)
        case .caret: goToLine(nil)
        case .wrap: cycleWrapMode(nil)
        case .viewCode: toggleViewCode(nil)
        case .mode: showModeMenu(nil)
        case .language: showLanguageMenu(nil)
        case .tabWidth: showTabWidthMenu(nil)
        case .readOnly: explainReadOnly()
        case .docSize: showDocumentSummary()
        }
    }

    /// Menu của mục «CSV · …» — bật/tắt chế độ CSV và CHỌN LẠI dấu phân tách.
    ///
    /// Phần chọn lại là phần quan trọng: `CSVEngine.detectDialect` đoán theo nội dung, và một
    /// tệp có nhiều dấu chấm phẩy trong phần chữ vẫn có thể bị đoán thành tệp chấm phẩy. Không
    /// có đường nói lại thì mọi thao tác cột đều lệch và người dùng không có cách nào sửa.
    @objc func showModeMenu(_ sender: Any?) { present(buildModeMenu(), from: sender) }

    /// Dựng menu, KHÔNG bung nó ra.
    ///
    /// Tách làm hai vì `NSMenu.popUp` chạy một vòng lặp modal: bài tự kiểm gọi thẳng
    /// `showModeMenu` sẽ đứng im giữa chừng, không đỏ, không lỗi — đúng cái bẫy mà `Unattended`
    /// ghi lại. Phần đáng kiểm là DANH SÁCH: có đủ dấu phân tách không, dấu đang dùng có được
    /// tích không.
    func buildModeMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: L("Chế độ CSV"), action: #selector(toggleCSVMode(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = isCSVMode ? .on : .off
        menu.addItem(toggle)

        if isCSVMode {
            // ĐỌC LẠI theo dấu khác — KHÔNG phải chuyển đổi tệp.
            //
            // Đây đúng cặp mà bảng mã đã có: menu bảng mã chia hai nhóm «Diễn giải lại theo…»
            // và «Chuyển đổi sang…», vì hai việc ấy khác nhau ở chỗ có ghi vào tệp hay không.
            // `CSV ▸ Đổi dấu phân tách…` là vế THỨ HAI — nó ghi lại cả tệp và bọc lại những ô
            // chứa dấu mới. Vế thứ nhất, tức "tôi đoán sai, đọc lại giùm", trước nay không có.
            menu.addItem(.separator())
            let header = NSMenuItem(title: L("Dấu phân tách"), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            let current = csvDialect
            for dialect in [CSVDialect.comma, .semicolon, .tab, .pipe] {
                let item = NSMenuItem(
                    title: "    \(dialect.displayName)",
                    action: #selector(chooseCSVDialect(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = Int(dialect.delimiter)
                item.state = dialect.delimiter == current.delimiter ? .on : .off
                menu.addItem(item)
            }

            let auto = NSMenuItem(
                title: L("Tự nhận diện"), action: #selector(clearCSVDialect(_:)), keyEquivalent: "")
            auto.target = self
            auto.state = tabs[activeIndex].csvDialectOverride == nil ? .on : .off
            menu.addItem(.separator())
            menu.addItem(auto)
        }

        return menu
    }

    @objc private func chooseCSVDialect(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let delimiter = UInt8(exactly: raw) else { return }
        tabs[activeIndex].csvDialectOverride = CSVDialect(delimiter: delimiter)
        applyDialectChange()
    }

    @objc private func clearCSVDialect(_ sender: Any?) {
        tabs[activeIndex].csvDialectOverride = nil
        applyDialectChange()
    }

    /// Dựng lại mọi thứ đang đọc theo dấu phân tách cũ.
    ///
    /// Chỉ gọi `refreshChrome` là đổi được cái NHÃN mà không đổi cái BẢNG — và một cái bảng chia
    /// cột theo dấu cũ nằm dưới một cái nhãn nói dấu mới là tình trạng tệ hơn cả trước khi sửa.
    private func applyDialectChange() {
        csvIndex = nil
        refreshChrome()
        if isTableViewVisible { showTableView() }
        showTransient(LF("Dấu phân tách: %@", csvDialect.displayName))
    }

    /// Menu chọn ngôn ngữ tô màu — Notepad++ có nó ở đúng chỗ này.
    ///
    /// Cần cho hai trường hợp có thật: tệp KHÔNG đuôi (`Makefile.local`, tệp cấu hình chép từ
    /// máy khác) và tệp mang đuôi nói dối (`.txt` chứa JSON).
    @objc func showLanguageMenu(_ sender: Any?) { present(buildLanguageMenu(), from: sender) }

    /// Dựng menu ngôn ngữ — xem `buildModeMenu` để biết vì sao tách khỏi phần bung ra.
    func buildLanguageMenu() -> NSMenu {
        let menu = NSMenu()
        let choice = tabs[activeIndex].languageChoice

        let auto = NSMenuItem(
            title: L("Theo đuôi tệp"), action: #selector(chooseLanguageAuto(_:)), keyEquivalent: "")
        auto.target = self
        auto.state = choice == .auto ? .on : .off
        menu.addItem(auto)

        let plain = NSMenuItem(
            title: L("Văn bản thuần"), action: #selector(chooseLanguagePlain(_:)), keyEquivalent: "")
        plain.target = self
        plain.state = choice == .plain ? .on : .off
        menu.addItem(plain)

        menu.addItem(.separator())
        for language in SyntaxLanguage.allCases {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(chooseLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = choice == .language(language) ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    @objc private func chooseLanguageAuto(_ sender: Any?) {
        tabs[activeIndex].languageChoice = .auto
        refreshChrome()
    }

    @objc private func chooseLanguagePlain(_ sender: Any?) {
        tabs[activeIndex].languageChoice = .plain
        refreshChrome()
    }

    @objc private func chooseLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = SyntaxLanguage(rawValue: raw) else { return }
        tabs[activeIndex].languageChoice = .language(language)
        refreshChrome()
    }

    /// Thụt lề ĐANG HIỆU LỰC — của ngôn ngữ đang mở nếu có khai riêng, không thì của cả app.
    ///
    /// SRS FR-CORE-009 đòi cấu hình "theo từng ngôn ngữ", và lý do nằm ở chỗ người ta không
    /// chọn thụt lề theo sở thích mà theo quy ước từng cộng đồng — xem `Settings.languageIndent`.
    var effectiveIndent: Settings.IndentStyle {
        if let language = editorView.syntaxLanguage,
           let style = settings.languageIndent[language.rawValue] {
            return style
        }
        return Settings.IndentStyle(width: settings.tabWidth, usesTabs: settings.usesTabsForIndent)
    }

    /// Menu độ rộng tab — đổi cho CẢ APP, hoặc chỉ cho ngôn ngữ đang mở.
    @objc func showTabWidthMenu(_ sender: Any?) { present(buildTabWidthMenu(), from: sender) }

    /// Dựng menu độ rộng tab — xem `buildModeMenu` để biết vì sao tách khỏi phần bung ra.
    func buildTabWidthMenu() -> NSMenu {
        let menu = NSMenu()
        for width in [2, 4, 8] {
            let item = NSMenuItem(
                title: LF("%d dấu cách", width),
                action: #selector(chooseTabWidth(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = width
            item.state = statusBar.state.tabWidth == width ? .on : .off
            menu.addItem(item)
        }

        // Nhánh riêng cho ngôn ngữ đang mở. Chỉ hiện khi CÓ ngôn ngữ: một mục "chỉ cho ngôn
        // ngữ này" trên tệp văn bản thuần thì không nói được nó sẽ áp cho cái gì.
        guard let language = editorView.syntaxLanguage else { return menu }
        menu.addItem(.separator())
        let header = NSMenuItem(
            title: LF("Riêng cho %@", language.displayName), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let riengCua = settings.languageIndent[language.rawValue]
        for width in [2, 4, 8] {
            for usesTabs in [false, true] {
                let item = NSMenuItem(
                    title: usesTabs
                        ? LF("    %d — dùng TAB", width)
                        : LF("    %d — dùng dấu cách", width),
                    action: #selector(chooseLanguageIndent(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = [width, usesTabs ? 1 : 0]
                item.state = riengCua == Settings.IndentStyle(width: width, usesTabs: usesTabs)
                    ? .on : .off
                menu.addItem(item)
            }
        }
        if riengCua != nil {
            let clear = NSMenuItem(
                title: L("    Bỏ khai riêng, dùng cài đặt chung"),
                action: #selector(clearLanguageIndent(_:)), keyEquivalent: "")
            clear.target = self
            menu.addItem(clear)
        }
        return menu
    }

    @objc private func chooseTabWidth(_ sender: NSMenuItem) {
        guard let width = sender.representedObject as? Int else { return }
        settings.tabWidth = width
        saveSettings()
        applyIndentToPanes()
    }

    @objc private func chooseLanguageIndent(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [Int], pair.count == 2,
              let language = editorView.syntaxLanguage else { return }
        settings.languageIndent[language.rawValue] =
            Settings.IndentStyle(width: pair[0], usesTabs: pair[1] == 1)
        saveSettings()
        applyIndentToPanes()
        showTransient(LF("%@: thụt lề %d %@", language.displayName, pair[0],
                         pair[1] == 1 ? L("TAB") : L("dấu cách")))
    }

    @objc private func clearLanguageIndent(_ sender: Any?) {
        guard let language = editorView.syntaxLanguage else { return }
        settings.languageIndent.removeValue(forKey: language.rawValue)
        saveSettings()
        applyIndentToPanes()
    }

    /// Đổ thụt lề đang hiệu lực xuống thanh trạng thái và cả hai nửa màn hình.
    private func applyIndentToPanes() {
        let indent = effectiveIndent
        var state = statusBar.state
        state.tabWidth = indent.width
        statusBar.state = state
        editorView.tabWidth = indent.width
        otherPane?.tabWidth = indent.width
    }

    /// Bấm mục cỡ tài liệu — đếm đủ byte · ký tự · từ · dòng.
    ///
    /// Đếm KÝ TỰ và TỪ không nằm sẵn trên thanh, và đó là chủ ý: cả hai phải đọc toàn bộ tài
    /// liệu, mà nhãn trên thanh cập nhật ở MỖI lần con nháy nhúc nhích. Trên tệp 200 MB thì
    /// mỗi phím mũi tên sẽ kéo theo một lượt quét — nên hai con số ấy chỉ tính khi người dùng
    /// hỏi, và với tệp lớn thì nói thẳng là không đếm thay vì làm treo cửa sổ.
    private func showDocumentSummary() {
        let buffer = editorDocument.buffer
        let bytes = buffer.count
        guard bytes <= Self.summaryCountLimit else {
            showTransient(LF("%d byte · %d dòng — tệp quá lớn để đếm ký tự và từ",
                             bytes, buffer.lineCount))
            return
        }
        let text = buffer.text
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        showTransient(LF("%d byte · %d ký tự · %d từ · %d dòng",
                         bytes, text.count, words, buffer.lineCount))
    }

    /// Trần cho phép đếm ký tự và từ — cùng bậc với trần cột thị giác, và cùng lý do.
    static let summaryCountLimit = 8 << 20

    // MARK: - Kết quả tìm: lịch sử và xuất ra (FR-SRCH-105)

    /// Đưa một lượt tìm lên panel VÀ ghi nó vào lịch sử.
    ///
    /// Mọi chỗ hiện kết quả đều đi qua đây — ba chỗ, và trước đây cả ba gọi thẳng vào panel nên
    /// lượt sau ghi đè lượt trước không để lại dấu vết nào.
    private func presentSearchResults(_ summary: FindInFiles.Summary, pattern: String) {
        searchHistory.insert((pattern, summary), at: 0)
        if searchHistory.count > Self.searchHistoryLimit { searchHistory.removeLast() }
        searchHistoryIndex = 0
        resultsView.showResults(summary, pattern: pattern)
        refreshSearchHistoryMenu()
    }

    private func refreshSearchHistoryMenu() {
        resultsView.setHistory(
            searchHistory.map { LF("«%@» — %d kết quả", $0.pattern, $0.summary.totalHits) },
            selected: searchHistoryIndex)
    }

    /// Xem lại một lượt CŨ. Không ghi lịch sử lần nữa — nó đã ở trong đó.
    private func showSearchHistoryEntry(_ index: Int) {
        guard searchHistory.indices.contains(index) else { return }
        searchHistoryIndex = index
        let entry = searchHistory[index]
        resultsView.showResults(entry.summary, pattern: entry.pattern)
        refreshSearchHistoryMenu()
    }

    /// Xuất lượt đang xem thành một TAB MỚI.
    ///
    /// Tab chứ không phải hộp chọn nơi lưu, và đó là cùng lựa chọn đã làm với báo cáo macro và
    /// kết quả SQL: sản phẩm này LÀ trình soạn thảo, nên thứ đưa cho người dùng nên là một tài
    /// liệu họ đọc được, tìm được, sửa được, rồi tự ⌘S vào đúng chỗ họ muốn. Một hộp chọn nơi
    /// lưu bắt họ quyết định chỗ cất trước khi kịp nhìn nội dung.
    private func exportSearchResults() {
        guard searchHistory.indices.contains(searchHistoryIndex) else { return }
        let entry = searchHistory[searchHistoryIndex]
        openTextInNewTab(entry.summary.exportText(pattern: entry.pattern),
                         label: LF("Kết quả tìm «%@»", entry.pattern))
    }

    /// Mục «chỉ đọc» nói ra VÌ SAO, và mở khoá khi mở khoá được.
    ///
    /// Ba nguồn khoá khác nhau và người dùng không phân biệt được: đang theo dõi file, tệp
    /// không có quyền ghi trên đĩa, hoặc chính họ đã mở tệp ở chế độ chỉ đọc. Chỉ có nguồn thứ
    /// ba là thứ bấm một cái mở ra được; hai nguồn kia phải nói thẳng chứ không im lặng.
    private func explainReadOnly() {
        guard editorDocument.isReadOnly else {
            showTransient(L("Tài liệu đang sửa được"))
            return
        }
        if isFollowingTail {
            showTransient(L("Chỉ đọc vì đang theo dõi file — tắt theo dõi để sửa lại"))
            return
        }
        if let path = editorDocument.path,
           !FileManager.default.isWritableFile(atPath: path) {
            showTransient(L("Chỉ đọc vì tệp trên đĩa không cho ghi"))
            return
        }
        editorDocument.unlockForEditing()
        refreshChrome()
        showTransient(L("Đã mở khoá — tài liệu sửa được"))
    }

    /// Mở thẳng chế độ View khi tệp có — `Settings.openInViewMode`, mặc định BẬT.
    ///
    /// **Chỉ những chế độ dựng NGAY TRONG TAB.** Xem trước Markdown mở một cửa sổ riêng và xem
    /// trước báo cáo mở một panel bên cạnh; bật sẵn chúng nghĩa là mỗi tệp `.md` người dùng mở
    /// đều bung thêm một cửa sổ họ không xin. Danh sách vì thế liệt kê TƯỜNG MINH, không viết
    /// theo kiểu "mọi thứ trừ hai cái kia" — thêm một chế độ View mới thì người thêm phải tự
    /// quyết định nó có đáng bật sẵn không.
    /// Cửa cho bài tự kiểm: chạy ĐÚNG hàm ấy, bỏ qua đúng một hàng rào.
    ///
    /// Hàng rào `Unattended.isActive` có mặt vì hàng chục bài kiểm mở tệp rồi soi buffer, và
    /// một chế độ View bật sẵn sẽ che vùng soạn thảo trong tất cả. Nhưng bỏ qua nó thì chính
    /// tính năng này thành mã không bài nào chạm tới — nên có cửa này, và có một bài đi qua nó.
    func openDefaultViewModeForSelfTest() { openDefaultViewMode() }

    private func openDefaultViewModeIfWanted() {
        guard settings.openInViewMode, !Unattended.isActive else { return }
        openDefaultViewMode()
    }

    private func openDefaultViewMode() {
        guard !isAnyViewModeVisible else { return }
        let modes = DisplayModes.of(
            path: editorDocument.path ?? "",
            kind: editorDocument.mediaKind,
            language: editorView.syntaxLanguage
        )
        guard modes.canToggle else { return }
        switch modes.view {
        case .tree, .diagram, .table, .document, .image, .player, .archiveList, .logLevels,
             .outline:
            toggleViewCode(nil)
        case .renderedText where editorDocument.mediaKind?.isOfficeOpenXML == true:
            toggleViewCode(nil)
        default:
            break
        }
    }

    /// Tên chế độ View của tệp đang mở, viết cho người đọc — «Trang PDF», «Bảng tính»…
    ///
    /// Nói RA cái tên vì công tắc một mình chưa đủ: «View» của một tệp `.docx` và «View» của một
    /// tệp `.json` là hai thứ khác hẳn, và người dùng cần biết mình sắp sang đâu trước khi bấm.
    func currentViewKindName() -> String {
        let modes = DisplayModes.of(
            path: editorDocument.path ?? "",
            kind: editorDocument.mediaKind,
            language: editorView.syntaxLanguage
        )
        switch modes.view {
        case .renderedText:
            return editorDocument.mediaKind == .word ? L("Trang tài liệu") : L("Chữ đã dựng")
        case .table:
            return editorDocument.mediaKind == .excel ? L("Trang bảng tính") : L("Bảng")
        case .diagram: return L("Sơ đồ")
        case .tree: return L("Cây khoá–giá trị")
        case .document: return L("Trang tài liệu")
        case .image: return L("Ảnh")
        case .player: return L("Bộ phát")
        case .archiveList: return L("Danh sách mục")
        case .report: return L("Báo cáo đã dựng")
        case .logLevels: return L("Tô theo mức")
        case .outline: return L("Trang slide")
        case .none: return visibleViewModeName()
        }
    }

    /// Đổ trạng thái vào khung chung trên đầu cửa sổ.
    func refreshDocumentToolbar() {
        let label = currentDisplayModeLabel()
        documentToolbar.present(
            kind: currentViewKindName(),
            inView: label == .view,
            canToggle: label.canToggle)
        documentToolbar.setActions(documentActions())
    }

    /// Tên của khung View ĐANG HIỆN, khi bảng tra không gọi ra được tên nào.
    ///
    /// Xảy ra với tài liệu chưa lưu: không đuôi tệp thì `DisplayModes` không biết đây là CSV.
    /// Để trống thì khung chung có một công tắc bật mà không nói nó dẫn đi đâu.
    private func visibleViewModeName() -> String {
        if isTableViewVisible { return L("Bảng") }
        if isStructureTreeVisible { return L("Cây khoá–giá trị") }
        if isOfficePreviewVisible { return L("Trang tài liệu") }
        if isDiagramTabVisible { return L("Sơ đồ") }
        return ""
    }

    /// Nút riêng của loại tệp đang mở — nằm ở mép phải khung chung.
    ///
    /// Đây là chỗ những cách nhìn KHÁC của cùng một tệp đi về, sau khi View được dành cho trang
    /// tài liệu dựng ra. Với `.xlsx` thì đó là **bảng sửa được**, với `.pptx` là **dàn ý**: cả
    /// hai đều sửa được và ghi ngược vào tệp, nên mất chúng là mất tính năng chứ không phải đổi
    /// cách hiển thị.
    private func documentActions() -> [NSView] {
        var actions: [NSView] = []
        // Bộ điều khiển TRANG chỉ có nghĩa khi đang nhìn trang. Hiện nút "Vừa ngang" trong lúc
        // người dùng đang ở chế độ Code là mời họ bấm một thứ không làm gì.
        if isOfficePreviewVisible {
            actions.append(pageSearchField)
            actions.append(pageIndicator)
            actions.append(toolbarButton(L("Vừa ngang"), #selector(zoomPagesToWidth(_:)),
                                         on: officePreview.pages.zoom == .fitWidth))
            actions.append(toolbarButton(L("Vừa khung"), #selector(zoomPagesToFit(_:)),
                                         on: officePreview.pages.zoom == .fitPage))
            actions.append(toolbarButton("\u{2212}", #selector(zoomPagesOut(_:)), on: false,
                                         label: L("Thu nhỏ trang")))
            actions.append(toolbarButton("+", #selector(zoomPagesIn(_:)), on: false,
                                         label: L("Phóng to trang")))
        }
        switch editorDocument.mediaKind {
        case .excel:
            actions.append(toolbarButton(L("Bảng"), #selector(toggleTableView(_:)),
                                         on: isTableViewVisible))
        case .powerpoint:
            actions.append(toolbarButton(L("Dàn ý"), #selector(toggleOutlineTree(_:)),
                                         on: isStructureTreeVisible))
        default:
            break
        }
        return actions
    }

    // MARK: - Phóng trang

    @objc func zoomPagesToWidth(_ sender: Any?) {
        officePreview.pages.zoom = .fitWidth
        refreshDocumentToolbar()
    }

    @objc func zoomPagesToFit(_ sender: Any?) {
        officePreview.pages.zoom = .fitPage
        refreshDocumentToolbar()
    }

    @objc func zoomPagesIn(_ sender: Any?) {
        officePreview.pages.zoomIn()
        refreshDocumentToolbar()
    }

    @objc func zoomPagesOut(_ sender: Any?) {
        officePreview.pages.zoomOut()
        refreshDocumentToolbar()
    }

    private func toolbarButton(
        _ title: String, _ action: Selector, on: Bool, label: String? = nil
    ) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .inline
        button.controlSize = .small
        button.font = Tokens.Font.caption
        // Nút đang BẬT phải trông khác nút đang tắt: nó là công tắc, không phải lệnh một chiều.
        button.contentTintColor = on ? Tokens.Color.action : nil
        // Nút mang KÝ HIỆU («+», «−») cần một cái tên đọc được: trình đọc màn hình đọc nhãn, và
        // "cộng" thì không nói lên nó cộng cái gì.
        button.setAccessibilityLabel(label ?? title)
        button.toolTip = label
        return button
    }

    /// «Trang 3/24» của bản dựng trang — cập nhật khi cuộn, không dựng lại cả khung công cụ.
    let pageIndicator: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = Tokens.Font.caption
        label.textColor = Tokens.Color.secondaryInk
        return label
    }()

    /// Ô tìm chữ TRONG TRANG đang dựng.
    ///
    /// Không dùng lại panel Tìm chung được: panel ấy tìm trong buffer văn bản và tô kết quả lên
    /// vùng soạn thảo — thứ đang bị khung trang che kín. Một cuốn 383 trang mà không tìm được
    /// chữ thì phần lớn công dụng của nó nằm ngoài tầm với.
    lazy var pageSearchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = L("Tìm")
        field.font = Tokens.Font.caption
        field.controlSize = .small
        field.target = self
        field.action = #selector(searchInPages(_:))
        field.sendsWholeSearchString = true
        field.widthAnchor.constraint(equalToConstant: 180).isActive = true
        return field
    }()

    /// Chỗ khớp đang đứng — bấm Enter lần nữa là sang chỗ tiếp theo.
    private var pageSearchOrdinal = 0
    private var pageSearchNeedle = ""

    @objc func searchInPages(_ sender: Any?) {
        let needle = pageSearchField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else {
            officePreview.clearSearchHighlight()
            pageSearchNeedle = ""
            return
        }
        // Gõ chữ KHÁC thì về chỗ khớp đầu; gõ lại đúng chữ cũ (bấm Enter) thì đi tiếp.
        if needle != pageSearchNeedle {
            pageSearchNeedle = needle
            pageSearchOrdinal = 0
        } else {
            pageSearchOrdinal += 1
        }
        let total = officePreview.matchCount(for: needle)
        guard total > 0, let page = officePreview.showMatch(needle, ordinal: pageSearchOrdinal)
        else {
            return showTransient(LF("Không tìm thấy «%@» trong tài liệu", needle))
        }
        pageIndicator.stringValue = LF(
            "Trang %d/%d", page + 1, officePreview.pages.pageCountForSelfTest)
        showTransient(LF("Chỗ khớp %d/%d", pageSearchOrdinal % total + 1, total))
    }

    /// Bộ đếm chỗ khớp cho bài tự kiểm — trả về (trang đã nhảy tới, tổng số chỗ khớp).
    func searchPagesForSelfTest(_ needle: String) -> (page: Int, total: Int)? {
        pageSearchField.stringValue = needle
        searchInPages(nil)
        let total = officePreview.matchCount(for: needle)
        guard total > 0, let page = officePreview.page(containing: needle) else { return nil }
        return (page, total)
    }

    /// Dàn ý slide — cách nhìn thứ hai của `.pptx`, mở từ khung chung.
    @objc func toggleOutlineTree(_ sender: Any?) {
        if isStructureTreeVisible {
            hideStructureTree()
        } else {
            if isOfficePreviewVisible { hideOfficePreview() }
            showStructureTree()
        }
        refreshChrome()
    }

    /// Chế độ hiển thị hiện tại, dạng nhãn cho thanh trạng thái — NFR-USE-01.
    ///
    /// Hỏi CHÍNH `DisplayModes` mà lệnh ⌥⌘V hỏi, và hỏi CHÍNH các khung đang hiện. Dựng một
    /// bảng tra thứ hai ở đây là mời hai chỗ nói hai điều khác nhau — và người dùng sẽ tin cái
    /// nhãn, không tin cái lệnh.
    func currentDisplayModeLabel() -> DisplayViewLabel {
        // Hỏi MÀN HÌNH trước, hỏi bảng tra sau.
        //
        // `DisplayModes` nhận loại theo ĐƯỜNG DẪN, mà một tài liệu chưa lưu thì không có đường
        // dẫn — nên nó trả "chỉ một chế độ" cho một tab đang hiện bảng CSV rành rành. Khung
        // chung khi ấy tắt công tắc và ghi «Tệp này chỉ có một chế độ hiển thị» ngay phía trên
        // cái bảng. Ảnh chụp màn hình bắt được, không bài kiểm nào bắt được, vì mọi bài đều hỏi
        // bảng tra chứ không hỏi thứ đang hiện.
        if isAnyViewModeVisible { return .view }
        let modes = DisplayModes.of(
            path: editorDocument.path ?? "",
            kind: editorDocument.mediaKind,
            language: editorView.syntaxLanguage
        )
        guard modes.canToggle else { return .codeOnly }
        return .code
    }

    /// Có khung View nào đang che vùng soạn thảo không.
    ///
    /// Liệt kê ĐỦ mọi khung, và đó là chỗ dễ sót: thêm một chế độ View mới mà quên thêm vào đây
    /// thì nhãn nói "Code" trong khi màn hình đang hiện View — một cái nhãn nói sai còn tệ hơn
    /// không có nhãn.
    /// Từng khung View một, dạng cờ — bài kiểm ghép chúng thành câu chẩn đoán của nó.
    ///
    /// Chỉ trả về CỜ, không trả về chữ: nhãn chẩn đoán là việc của bài kiểm, và một chuỗi tiếng
    /// Việt nằm trong mã sản phẩm sẽ đi thẳng vào bảng nợ dịch dù không ai đọc nó.
    var viewModeFlagsForSelfTest: [(name: String, on: Bool)] {
        [("tree", isStructureTreeVisible), ("diagram", isDiagramTabVisible),
         ("office", isOfficePreviewVisible),
         ("csv", isTableViewVisible), ("media", isMediaViewerVisibleForSelfTest),
         ("report", isReportPreviewVisible), ("markdown", isMarkdownPreviewForCurrentDocument)]
    }

    var isMarkdownPreviewForCurrentDocument: Bool {
        (markdownPreview?.window?.isVisible ?? false)
            && markdownPreviewDocumentID == editorDocument.id
    }

    var isAnyViewModeVisible: Bool {
        isStructureTreeVisible || isDiagramTabVisible || isTableViewVisible
            || isOfficePreviewVisible
            || isMediaViewerVisibleForSelfTest || isReportPreviewVisible
            || isMarkdownPreviewForCurrentDocument
    }

    /// Quá độ dài này thì thôi đếm cột thị giác — xem `updateCaretStatus`.
    private static let visualColumnLimit = 200 * 1024

    /// Cửa cho `OpenProbe` gọi thẳng nhịp cập nhật thanh trạng thái.
    ///
    /// Phép đo phải chạm ĐÚNG hàm sản phẩm chạy, không phải một bản mô phỏng: nhịp này là ứng
    /// viên hàng đầu cho việc cuộn giật, vì nó chạy ở MỌI lần dời con nháy.
    func updateCaretStatusForProbe() { updateCaretStatus() }

    private func updateCaretStatus() {
        // KẸP một lần, rồi chỉ dùng bản đã kẹp.
        //
        // Vùng chọn của view có thể còn trỏ vào tài liệu TRƯỚC khi vừa bị xoá ngắn đi — nhịp
        // cập nhật này chạy ngay sau mỗi lần sửa, trước khi view kịp thu vùng chọn về. Bản đầu
        // giữ hai biến: `position` tính từ offset đã kẹp, nhưng phép đo cột lại nhận offset
        // THÔ, và `lineNumber(atOffset:)` có `precondition` — tức là app SẬP, không phải hiện
        // sai một con số.
        //
        // Bộ chạy dài `--soak` tìm ra chỗ này ở bước 78; 1168 test lõi và 176 bài tự kiểm thì
        // không, vì mỗi bài dựng trạng thái sạch rồi làm đúng một việc.
        let byteOffset = min(
            editorView.selectedDocumentRange.lowerBound, editorDocument.buffer.count)
        let position = editorDocument.buffer.position(atOffset: byteOffset)

        var state = statusBar.state
        state.caretLine = position.line + 1
        state.caretOffset = byteOffset
        state.documentBytes = editorDocument.buffer.count
        state.documentLines = editorDocument.buffer.lineCount

        // Cột THỊ GIÁC, cùng luật với chọn khối cột (FR-CORE-002) và với tự động thụt lề
        // (FR-CORE-011): TAB nở tới nấc, ký tự nhiều byte vẫn là một cột.
        //
        // Trước 24/08/2026 chỗ này hiện `byteColumn`, tức số BYTE. Nhãn ghi "Cột" mà gõ
        // "Nguyễn" xong thì nó báo 9 trong khi người dùng đếm được 7 — và ngay dưới đây đã có
        // sẵn một chú thích cẩn thận về việc phải đếm ký tự cho phần vùng chọn.
        //
        // Phép đo phải đi từ ĐẦU DÒNG nên nó tỉ lệ với độ dài dòng. Đã đo sau khi cho nó đọc
        // byte theo lô: 0,08 ms cho 1000 ký tự, 7,8 ms cho 100 nghìn, 78 ms cho 1 triệu. Nhịp
        // này chạy ở MỖI lần dời con nháy, nên chặn lại ở 200 KB — quá đó thì quay về đếm byte
        // và NÓI RA bằng dấu `~`, đúng lối FR-CORE-012 từ chối khớp ngoặc trên file > 1 MB.
        let lineStart = editorDocument.buffer.contentRange(ofLine: position.line).lowerBound
        if byteOffset - lineStart <= Self.visualColumnLimit {
            state.caretColumn = ColumnSelection.column(
                ofOffset: byteOffset, in: editorDocument.buffer, tabWidth: effectiveIndent.width) + 1
            state.caretColumnIsApproximate = false
        } else {
            state.caretColumn = position.byteColumn + 1
            state.caretColumnIsApproximate = true
        }
        // Đếm KÝ TỰ chứ không đếm đơn vị UTF-16: "🇻🇳" là một ký tự nhưng bốn đơn vị UTF-16,
        // và "ế" dạng tổ hợp là một ký tự nhưng hai điểm mã. Nhãn nói "ký tự" thì phải đúng.
        let selectedText = editorView.selectedText
        if !selectedText.isEmpty {
            state.selectionSummary = "\(selectedText.count) ký tự"
        } else {
            state.selectionSummary = nil
        }
        statusBar.state = state
    }

    // MARK: - Quy đổi offset
    /// Báo cho người dùng biết một thao tác đã hỏng.
    ///
    /// Hộp thoại này chỉ BÁO TIN — nó không hỏi gì, nên ở lượt chạy không có ai ngồi trước máy
    /// thì ghi lại rồi đi tiếp là đủ. Không làm thế thì `runModal()` chờ một cú bấm không bao
    /// giờ tới và cả bộ tự kiểm treo, im lặng. Xem `Unattended` để biết vì sao chặn ở đây chứ
    /// không vá từng chỗ gọi.
    private func presentError(_ title: String, _ error: Error) {
        let detail = String(describing: error)
        guard !Unattended.isActive else {
            Unattended.recordError(title, detail)
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }
}

/// Banner cảnh báo trên đầu vùng soạn thảo (UI/UX §4.2, §7.1).
final class BannerView: NSView {
    static let height: CGFloat = 34

    var messageForSelfTest: String { label.stringValue }

    private let label = NSTextField(labelWithString: "")
    private let button = NSButton(title: "", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    /// Nền layer KHÔNG tự theo appearance — xem `NSView.applyLayerBackground`.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Self.background)
    }

    /// GOLD là màu phụ trợ dành riêng cho banner và chấm chưa lưu (bảng màu ở README).
    private static var background: NSColor { Tokens.Color.gold.withAlphaComponent(0.18) }

    private func setUp() {
        applyLayerBackground(Self.background)

        label.font = Tokens.Font.caption
        label.lineBreakMode = .byTruncatingTail
        button.bezelStyle = .rounded
        button.font = Tokens.Font.caption

        let stack = NSStackView(views: [label, NSView(), button])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = Tokens.Metrics.spacing(2)
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Tokens.Metrics.spacing(3), bottom: 0, right: Tokens.Metrics.spacing(3)
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(message: String, actionTitle: String?, target: AnyObject?, action: Selector?) {
        label.stringValue = message
        button.title = actionTitle ?? ""
        button.isHidden = actionTitle == nil
        button.target = target
        button.action = action
    }
}

extension MainWindowController {

    /// Khôi phục bản nháp chưa lưu của phiên trước (NFR-REL-01, TC-DOC-01).
    ///
    /// Nội dung bản nháp là UTF-8 — nó do ta ghi ra, không phải file của người dùng. Tài liệu
    /// khôi phục được đánh dấu ĐÃ SỬA và KHÔNG tự ghi đè file gốc: người dùng phải chủ động
    /// lưu, vì có thể họ muốn giữ bản trên đĩa.
    func restoreFirstSnapshot(_ snapshots: [Snapshot], store: SnapshotStore) {
        guard let snapshot = snapshots.first else { return }
        guard let restored = try? Document.restore(snapshot, store: store) else {
            return showRestoreBanner("Không đọc được bản nháp của phiên trước.")
        }
        loadDocument(restored)

        let extra = snapshots.count > 1 ? " (còn \(snapshots.count - 1) bản nháp khác)" : ""
        showRestoreBanner(
            "Đã khôi phục nội dung chưa lưu từ phiên trước\(extra). Kiểm tra rồi lưu lại."
        )
    }
}

// MARK: - Tìm và thay (FR-SRCH-101…104)

extension MainWindowController {

    @objc func showFindPanel(_ sender: Any?) {
        // Đang xem trang thì ⌘F phải tìm TRONG TRANG. Mở panel Tìm ở đây là mở một ô tìm cho
        // vùng soạn thảo đang bị che kín — người dùng gõ vào đó và không thấy gì xảy ra.
        if isOfficePreviewVisible {
            window?.makeFirstResponder(pageSearchField)
            return
        }
        attachFindPanel()
        // Tắt ràng buộc chiều cao 0 để nội dung tự quyết định — xem ghi chú ở `FindPanelView`.
        findPanelHeight?.isActive = false
        findPanel.isHidden = false
        findPanel.focusFindField()
    }

    func handleFindActionForSelfTest(_ action: FindPanelView.Action) {
        handleFindAction(action, FindPanelView.Query())
    }

    private func hideFindPanel() {
        findPanel.isHidden = true
        findPanelHeight.isActive = true
        matches = []
        currentMatch = -1
        // Đóng panel phải xoá cả phần tô: để lại thì tài liệu đầy nền vàng của một phép tìm
        // người dùng đã kết thúc, và không còn chỗ nào để tắt nó đi.
        editorView.searchHighlights = []
    }

    private func handleFindAction(_ action: FindPanelView.Action, _ query: FindPanelView.Query) {
        switch action {
        case .close: hideFindPanel()
        case .countAll:
            refreshMatches(query, announce: true)
            editorView.searchHighlights = matches.map(\.range)
        case .findNext: step(query, forward: true)
        case .findPrevious: step(query, forward: false)
        case .replaceCurrent: replaceCurrentMatch(query)
        case .replaceAll: replaceAllMatches(query)
        case .incremental: searchIncrementally(query)
        }
    }

    /// Gõ tới đâu tìm tới đó (FR-SRCH-108) và tô hết kết quả (FR-SRCH-109).
    ///
    /// Nhảy tới kết quả đầu tiên TỪ CHỖ ĐANG ĐỨNG, không phải từ đầu tài liệu: người dùng đang
    /// đọc ở dòng 40 000 mà gõ vào ô Tìm thì họ muốn tìm quanh chỗ ấy, và ném họ về đầu file
    /// là mất chỗ đang đọc.
    ///
    /// KHÔNG đụng vào `currentMatch` khi không tìm thấy gì: pattern đang gõ dở luôn có những
    /// nhịp không khớp gì cả, và mỗi nhịp như thế mà xoá vị trí đang đứng thì gõ xong một từ
    /// là con nháy đã đi đâu mất.
    private func searchIncrementally(_ query: FindPanelView.Query) {
        guard !query.pattern.isEmpty else {
            matches = []
            currentMatch = -1
            editorView.searchHighlights = []
            findPanel.showStatus("")
            return
        }
        guard refreshMatches(query, announce: false) else {
            editorView.searchHighlights = []
            return
        }
        editorView.searchHighlights = matches.map(\.range)
        guard !matches.isEmpty else {
            findPanel.showStatus("Không có kết quả")
            return
        }
        let from = editorView.selectedDocumentRange.lowerBound
        let index = matches.firstIndex { $0.range.lowerBound >= from } ?? 0
        currentMatch = index
        selectMatch(matches[index])
        findPanel.showStatus("\(index + 1)/\(matches.count)")
    }

    /// Chạy lại phép tìm trên toàn tài liệu.
    @discardableResult
    private func refreshMatches(_ query: FindPanelView.Query, announce: Bool) -> Bool {
        guard !query.pattern.isEmpty else {
            matches = []
            currentMatch = -1
            findPanel.showStatus("")
            return false
        }

        do {
            let (pattern, jitWarning) = try compiledPattern(for: query)
            // Không dựng cả tài liệu nữa: `DocumentSearch` khớp thẳng trên vùng mmap khi tài
            // liệu chưa phân mảnh, và quét theo cửa sổ khi đã phân mảnh.
            matches = try DocumentSearch.find(
                pattern: pattern, in: editorDocument.buffer, cancelToken: CancelToken(timeout: 5)
            )
            if announce {
                let found = matches.isEmpty ? "Không có kết quả" : "\(matches.count) kết quả"
                findPanel.showStatus(found + jitWarning, isError: !jitWarning.isEmpty)
            }
            return true
        } catch let error as RegexCompileError {
            // FR-SRCH-102 — người dùng phải biết SAI Ở ĐÂU, không chỉ "regex không hợp lệ".
            matches = []
            findPanel.showStatus("Lỗi tại vị trí \(error.offset): \(error.message)", isError: true)
            return false
        } catch let error as RegexBudgetExceeded {
            // FR-SRCH-104 — pattern độc bị trần chặn, và ta NÓI RA thay vì im lặng trả 0 kết quả.
            matches = []
            findPanel.showStatus("\(error.description). Hãy làm pattern chặt hơn.", isError: true)
            return false
        } catch {
            matches = []
            findPanel.showStatus("Tìm kiếm bị dừng: \(error)", isError: true)
            return false
        }
    }

    /// Biên dịch pattern, và HẠ TRẦN khi JIT không nhận nó.
    ///
    /// ADR-03 §3.4: nhánh interpreter không phải lưới an toàn — với vài pattern nó chậm hơn
    /// 10⁴ lần, và không đoán trước được từ hình dạng pattern. Rơi về interpreter mà vẫn giữ
    /// nguyên trần backtracking nghĩa là mỗi lần khớp có thể tốn tới ~100 ms thay vì ~2 ms.
    /// Nên khi JIT hỏng: hạ trần xuống một phần mười và NÓI RA, thay vì để người dùng ngồi
    /// nhìn con trỏ quay mà không hiểu vì sao.
    private func compiledPattern(
        for query: FindPanelView.Query
    ) throws -> (PCRE2Pattern, warning: String) {
        let pattern = try PCRE2Pattern(pattern: query.pattern, options: query.options)
        guard !pattern.isJITCompiled else { return (pattern, "") }

        var limits = PCRE2Pattern.Limits()
        limits.matchLimit /= 10
        limits.depthLimit /= 10
        let limited = try PCRE2Pattern(pattern: query.pattern, options: query.options, limits: limits)
        return (limited, " · pattern này JIT không nhận, tìm kiếm bị giới hạn để không treo")
    }

    private func step(_ query: FindPanelView.Query, forward: Bool) {
        guard refreshMatches(query, announce: false), !matches.isEmpty else {
            if matches.isEmpty { findPanel.showStatus("Không có kết quả") }
            return
        }

        // Tiếp tục từ vị trí con trỏ chứ không từ kết quả trước: người dùng có thể đã click
        // đi chỗ khác giữa hai lần nhấn ⌘G.
        let caret = editorView.selectedDocumentRange.lowerBound
        if forward {
            currentMatch = matches.firstIndex { $0.range.lowerBound > caret } ?? 0
        } else {
            currentMatch = matches.lastIndex { $0.range.lowerBound < caret } ?? (matches.count - 1)
        }
        selectMatch(matches[currentMatch])
        findPanel.showStatus("\(currentMatch + 1)/\(matches.count)")
    }

    private func selectMatch(_ match: SearchMatch) {
        editorView.reveal(documentOffset: match.range.lowerBound)
        editorView.setSelectedDocumentRange(match.range)
        updateCaretStatus()
    }

    private func replaceCurrentMatch(_ query: FindPanelView.Query) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        guard refreshMatches(query, announce: false), !matches.isEmpty else { return }

        let caret = editorView.selectedDocumentRange.lowerBound
        guard let index = matches.firstIndex(where: { $0.range.lowerBound >= caret })
            ?? matches.indices.last
        else { return }

        // Thay một kết quả vẫn đi qua `replacementEdits` để chuỗi thay thế được giãn đúng
        // ngữ nghĩa PCRE2 ($1, \U…) — chứ không phải dán chuỗi thô.
        do {
            let pattern = try PCRE2Pattern(pattern: query.pattern, options: query.options)
            let content = editorDocument.buffer.bytes(in: matches[index].range)
            let plan = try content.withUnsafeBytes {
                try pattern.replacementEdits(in: $0, template: query.replacement)
            }
            guard let local = plan.edits.first else { return }
            let base = matches[index].range.lowerBound
            editorDocument.buffer.applyEdits(
                [TextEdit(range: (base + local.range.lowerBound) ..< (base + local.range.upperBound),
                          bytes: local.bytes)],
                label: "Thay thế"
            )
            syncViewFromBuffer()
            refreshChrome()
            refreshMatches(query, announce: true)
        } catch {
            findPanel.showStatus("Không thay được: \(error)", isError: true)
        }
    }

    /// FR-SRCH-103 — thay tất cả là MỘT bước undo, dù có một triệu kết quả (FR-CORE-004).
    private func replaceAllMatches(_ query: FindPanelView.Query) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        guard !query.pattern.isEmpty else { return }

        do {
            let pattern = try PCRE2Pattern(pattern: query.pattern, options: query.options)
            let plan = try DocumentSearch.replacementEdits(
                pattern: pattern, template: query.replacement,
                in: editorDocument.buffer, cancelToken: CancelToken(timeout: 30)
            )
            guard !plan.isEmpty else { return findPanel.showStatus("Không có kết quả") }

            editorDocument.buffer.applyEdits(plan.edits, label: "Thay thế tất cả")
            syncViewFromBuffer()
            refreshChrome()
            findPanel.showStatus("Đã thay \(plan.matchCount) kết quả")
            matches = []
            currentMatch = -1
        } catch let error as ReplacementTemplateError {
            findPanel.showStatus("Chuỗi thay thế sai: \(error.message)", isError: true)
        } catch {
            findPanel.showStatus("Không thay được: \(error)", isError: true)
        }
    }

    @objc func findNextFromMenu(_ sender: Any?) { step(findPanel.query, forward: true) }
    @objc func findPreviousFromMenu(_ sender: Any?) { step(findPanel.query, forward: false) }
}

// MARK: - Thao tác dòng và CSV (FR-CORE-005…010, FR-CSV-404…406)

extension MainWindowController {

    /// Áp một nhóm sửa đổi rồi cập nhật giao diện.
    ///
    /// MỌI thao tác hàng loạt đi qua đây, nên tất cả đều là một bước undo (FR-CORE-004) mà
    /// không chỗ gọi nào phải tự nhớ điều đó.
    private func apply(_ edits: [TextEdit], label: String) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        guard !edits.isEmpty else { return }
        editorDocument.buffer.applyEdits(edits, label: label)
        editorDocument.refreshEOLReport()
        syncViewFromBuffer()
        refreshChrome()
    }

    private func runOperation(_ label: String, _ body: () throws -> [TextEdit]) {
        do {
            apply(try body(), label: label)
        } catch {
            presentError("Không thực hiện được: \(label)", error)
        }
    }

    @objc func sortLinesAscending(_ sender: Any?) {
        apply(DocumentOps.sortLines(in: editorDocument.buffer), label: "Sắp xếp dòng A→Z")
    }

    @objc func sortLinesDescending(_ sender: Any?) {
        apply(
            DocumentOps.sortLines(in: editorDocument.buffer, ascending: false),
            label: "Sắp xếp dòng Z→A"
        )
    }

    @objc func sortLinesNatural(_ sender: Any?) {
        apply(
            DocumentOps.sortLines(in: editorDocument.buffer, kind: .natural),
            label: "Sắp xếp tự nhiên"
        )
    }

    @objc func removeDuplicateLines(_ sender: Any?) {
        runOperation("Khử trùng lặp") {
            try DocumentOps.removeDuplicateLines(in: editorDocument.buffer)
        }
    }

    @objc func trimTrailingWhitespace(_ sender: Any?) {
        runOperation("Cắt khoảng trắng cuối dòng") {
            try DocumentOps.trimLines(in: editorDocument.buffer)
        }
    }

    /// Vùng dòng đang chọn; `nil` khi không chọn gì.
    ///
    /// Thao tác dòng phải theo vùng chọn khi có — người dùng bôi đen ba dòng rồi bấm "Đảo thứ
    /// tự" thì muốn đảo ba dòng ấy, không phải cả tài liệu 7 triệu dòng.
    private func selectedLineRange() -> ClosedRange<Int>? {
        let selection = editorView.selectedDocumentRange
        guard !selection.isEmpty, editorDocument.buffer.lineCount > 0 else { return nil }
        let buffer = editorDocument.buffer
        // `lineNumber` trả về `lineCount` khi con trỏ đứng sau newline cuối — đó là DÒNG ẢO,
        // không có nội dung để thao tác. Kẹp về dòng thật cuối cùng.
        let last = buffer.lineCount - 1
        let start = min(last, buffer.lineNumber(atOffset: selection.lowerBound))
        // Vùng chọn kết thúc ngay đầu một dòng (bôi đen trọn dòng cuối) thì KHÔNG tính dòng đó:
        // ngược lại "chọn 3 dòng" hoá ra là 4.
        let endOffset = selection.upperBound
        var end = min(last, buffer.lineNumber(atOffset: endOffset))
        if end > start, endOffset == buffer.offset(ofLineStart: end) { end -= 1 }
        return start ... end
    }

    /// Dòng đang đặt con trỏ.
    private func caretLine() -> Int {
        let buffer = editorDocument.buffer
        let line = buffer.lineNumber(atOffset: editorView.selectedDocumentRange.lowerBound)
        return min(line, max(buffer.lineCount - 1, 0))
    }

    // MARK: - Móc cho bài tự kiểm (`--self-test`)
    //
    // Đi qua ĐÚNG các đường mà giao diện đi, không có đường tắt nào: đặt tài liệu bằng
    // `loadDocument`, chọn bằng chính hàm ⌘D, và gõ bằng `NSTextView.insertText` để AppKit
    // gọi lại `shouldChangeTextIn` của ta như khi người dùng gõ thật.

    func prepareSelfTestDocument(_ text: String) {
        loadDocument(.untitled())
        editorDocument.buffer.applyEdits(
            [TextEdit(range: 0 ..< editorDocument.buffer.count, text: text)], label: "dựng bài"
        )
        syncViewFromBuffer()
        editorView.setSelection(MultiSelection(caretAt: 0))
    }

    /// Chọn mọi lần xuất hiện của `needle` bằng chính đường ⌘D.
    func selectAllOccurrencesForSelfTest(_ needle: String) {
        let buffer = editorDocument.buffer
        var selection = MultiSelection(caretAt: 0)
        var found: [Range<Int>] = []
        var cursor = 0
        while let next = OccurrenceSearch.next(Array(needle.utf8), in: buffer, after: cursor),
              !found.contains(next) {
            found.append(next)
            cursor = next.upperBound
        }
        guard !found.isEmpty else { return }
        selection.setSingle(found[0])
        for range in found.dropFirst() { selection.add(range) }
        editorView.setSelection(selection)
    }

    func selectColumnBlockForSelfTest(from start: (line: Int, column: Int), to end: (line: Int, column: Int)) {
        editorView.setSelection(
            ColumnSelection.selection(
                in: editorDocument.buffer, from: start, to: end, tabWidth: effectiveIndent.width)
        )
    }

    /// Áp Column Editor mà không mở hộp thoại — đi qua đúng phần sinh giá trị và áp sửa đổi.
    func applyColumnEditorForSelfTest(_ content: ColumnEditor.Content) {
        let selection = editorView.selection
        let values = ColumnEditor.values(content, count: selection.count)
        let edits = selection.edits(insertingEach: values)
        guard !edits.isEmpty else { return }
        editorDocument.buffer.applyEdits(edits, label: "Column Editor")
        let moved = selection.afterApplying(edits)
        syncViewFromBuffer()
        editorView.setSelection(moved)
        refreshChrome()
    }

    func setCaretForSelfTest(documentOffset offset: Int) {
        editorView.setSelection(MultiSelection(caretAt: offset))
    }

    var editorFontSizeForSelfTest: CGFloat { editorView.fontSize }
    var searchHighlightsForSelfTest: [Range<Int>] { editorView.searchHighlights }

    var isLogModeForSelfTest: Bool { editorView.isLogMode }

    /// Lọc log mà không phải bung menu — đi qua đúng hàm mà mục menu gọi tới.
    func filterLogLevelForSelfTest(_ level: LogFormat.Level) {
        let item = NSMenuItem()
        item.representedObject = level.rawValue
        applyLogLevelFilter(item)
    }

    /// Những view TỰ VẼ có tương tác — thứ VoiceOver không tự suy ra được (NFR-USE-03).
    var selfDrawnViewsForSelfTest: [(String, NSView)] {
        // Hai view TỰ VẼ, cộng những NHÓM mà bảng bên trong thì AppKit mô tả được nhưng bản
        // thân nhóm thì không — VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
        // CHỈ những panel đã dựng. Chạm vào một panel `lazy` chưa ai mở là dựng nó ra sớm —
        // đúng thứ ADR-08 đã gỡ khỏi đường khởi động, và một bài kiểm không được tự tay làm
        // hỏng cái nó đang đo.
        var views: [(String, NSView)] = [
            ("bản đồ tài liệu", documentMapView),
            ("thanh tab", tabBar),
        ]
        if isSidebarVisible {
            views.append(("cây thư mục", workspaceView))
            views.append(("danh sách hàm", functionList))
        }
        if isTableViewVisible { views.append(("bảng CSV", csvTable)) }
        return views
    }

    /// Hỏi bộ theo dõi một lần thay vì chờ hệ điều hành báo — bài kiểm không được phụ thuộc
    /// vào lúc nào FSEvents thấy vừa.
    func pollTailForSelfTest() { tailWatcher?.poll() }

    /// Thúc MỌI bộ theo dõi đang chạy, kể cả của tab đang bị che.
    ///
    /// Bài kiểm "dòng log rơi đúng tab" cần đúng điều này: tab đang hiện KHÔNG có bộ theo dõi
    /// nào, nên `pollTailForSelfTest` ở trên sẽ không làm gì và bài kiểm sẽ xanh vì không có gì
    /// xảy ra cả.
    func pollTailForSelfTestInAnyTab() { for tab in tabs { tab.tailWatcher?.poll() } }

    /// Gõ vào ô Tìm đúng như người dùng gõ, kể cả nhịp tìm tăng dần.
    func typeIntoFindFieldForSelfTest(_ text: String) {
        findPanel.typeIntoFindFieldForSelfTest(text)
    }

    /// Enter đi qua ĐÚNG đường của phím Enter — `insertNewline` của `NSTextView`.
    func insertNewlineForSelfTest() {
        editorView.textView.insertNewline(nil)
    }

    func setTrimOnSaveForSelfTest(_ on: Bool) { trimsTrailingWhitespaceOnSave = on }

    /// Lưu vào một đường dẫn cho trước, không mở hộp thoại — nhưng vẫn qua `performSave`, nên
    /// bước cắt khoảng trắng khi lưu vẫn nằm trên đường đi.
    func saveDocumentToPathForSelfTest(_ path: String) {
        performSave { try self.editorDocument.save(to: path, allowLossy: $0) }
    }

    func setSelectionForSelfTest(documentRange range: Range<Int>) {
        var selection = MultiSelection(caretAt: range.lowerBound)
        selection.setSingle(range)
        editorView.setSelection(selection)
    }

    /// Dán qua ĐÚNG đường của lệnh Dán, kể cả bước đọc clipboard.
    func pasteForSelfTest(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        pasteSelection(nil)
    }

    func typeForSelfTest(_ text: String) {
        editorView.textView.insertText(text, replacementRange: editorView.textView.selectedRange())
    }

    func deleteBackwardForSelfTest() {
        editorView.textView.deleteBackward(nil)
    }

    // MARK: - Móc tự kiểm cho ngắt dòng mềm (FR-CORE-015 / TC-CORE-13)

    func setWrapModeForSelfTest(_ mode: WrapMode) {
        editorView.tabWidth = statusBar.state.tabWidth
        editorView.wrapMode = mode
    }

    var wrapModeForSelfTest: WrapMode { editorView.wrapMode }

    /// Vòng chế độ đi đúng đường người dùng đi (mục menu), không đặt thẳng thuộc tính.
    func cycleWrapModeForSelfTest() { cycleWrapMode(nil) }

    /// Ép vẽ xong rồi mới đo.
    ///
    /// `display()` không đủ với view có layer: nó chỉ đánh dấu bẩn rồi trả về, còn nét vẽ thật
    /// xảy ra ở chu kỳ sau. Đúng cái bẫy này từng làm PoC-A đo ra "Scintilla nhanh gấp 30 lần"
    /// khi thật ra nó chưa vẽ lần nào.
    /// Bơm vòng lặp sự kiện cho tới khi các thông báo hoãn được gửi xong.
    ///
    /// `flushDrawingForSelfTest` chỉ VẼ LẠI — nó không gửi thông báo nào. Mà
    /// `NSView.boundsDidChangeNotification`, thứ đánh thức `viewportMoved` sau mỗi lần cuộn,
    /// đi qua vòng lặp sự kiện chứ không phát ngay tại chỗ gọi `scroll(to:)`.
    ///
    /// Không có bước này thì một bài tự kiểm "cuộn rồi kiểm màu" sẽ đo trạng thái TRƯỚC khi
    /// cuộn có tác dụng — và nó báo đỏ cho một sản phẩm hoàn toàn đúng, hoặc tệ hơn, báo xanh
    /// cho một sản phẩm đã hỏng vì nó chưa từng chạm tới nhánh cần kiểm.
    func settleForSelfTest(_ seconds: TimeInterval = 0.05) {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(seconds))
        flushDrawingForSelfTest()
    }

    func flushDrawingForSelfTest() {
        CATransaction.begin()
        editorView.displayIfNeeded()
        CATransaction.flush()
        CATransaction.commit()
    }

    /// Số đo hình học để bài tự kiểm khẳng định chữ KHÔNG bị cắt.
    var wrapGeometryForSelfTest: (textViewHeight: Double, laidOutHeight: Double, canvasBottom: Double) {
        editorView.geometryProbeForSelfTest
    }

    var textContainerWidthForSelfTest: Double { editorView.textContainerWidthForSelfTest }
    /// Kéo CỬA SỔ hẹp lại — đúng thao tác người dùng làm, không phải đặt thẳng frame khung con.
    ///
    /// Bản đầu của móc này đặt `frame` của khung soạn thảo rồi gọi `layoutSubtreeIfNeeded()`.
    /// Nó chạy, nhưng ràng buộc autolayout giữa khung soạn thảo và scroll view chưa được giải,
    /// nên bề rộng thùng chữ không đổi và bài kiểm đo mãi một bố cục đứng yên.
    /// Trả về bề rộng THẬT SỰ đạt được: cửa sổ có bề rộng tối thiểu, nên đòi 380 chưa chắc
    /// được 380. Bài kiểm phải so theo số này, nếu không nó sẽ tố cáo nhầm phần ngắt dòng.
    @discardableResult
    func setWindowWidthForSelfTest(_ width: Double) -> Double {
        guard let window else { return 0 }
        var frame = window.frame
        frame.size.width = CGFloat(width)
        window.setFrame(frame, display: true)
        window.layoutIfNeeded()
        editorView.layoutSubtreeIfNeeded()
        return Double(window.frame.width)
    }
    var windowHeightForSelfTest: Double { Double(window?.frame.height ?? 0) }

    /// Đổi bề cao cửa sổ. Trả về bề cao THẬT đạt được — cửa sổ có bề cao tối thiểu.
    @discardableResult
    func setWindowHeightForSelfTest(_ height: Double) -> Double {
        guard let window else { return 0 }
        var frame = window.frame
        frame.size.height = CGFloat(height)
        window.setFrame(frame, display: true)
        window.layoutIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()
        return Double(window.frame.height)
    }

    var tracksViewWidthForSelfTest: Bool { editorView.tracksViewWidthForSelfTest }
    var textViewWidthForSelfTest: Double { editorView.textViewWidthForSelfTest }

    // MARK: - Móc tự kiểm cho đánh dấu dòng (FR-SRCH-107)

    func markLinesForSelfTest(_ lines: [Int], color: Int) {
        var updated = marks
        updated.setActiveColor(color)
        for line in lines { updated.toggle(line) }
        marks = updated
    }

    func markedBandsForSelfTest() -> [(line: Int, color: Int)] {
        editorView.markedBandsForSelfTest()
    }

    var markCountForSelfTest: Int { marks.count }
    func setCaretLineForSelfTest(_ line: Int) {
        editorView.setCaret(documentOffset: editorDocument.buffer.offset(ofLineStart: line))
    }
    func caretLineForSelfTest() -> Int {
        editorDocument.buffer.lineNumber(
            atOffset: min(editorView.selectedDocumentRange.lowerBound, editorDocument.buffer.count)
        )
    }
    func goToNextMarkForSelfTest() { goToNextMark(nil) }

    // MARK: - Móc tự kiểm cho tô màu cú pháp (FR-FMT-501)

    // MARK: - Móc tự kiểm cho chế độ CSV (FR-CSV-401/402)

    func setCSVModeForSelfTest(_ on: Bool) {
        csvModeOverride = on
        refreshChrome()
    }
    var isCSVModeForSelfTest: Bool { isCSVMode }

    // --- Table view (FR-CSV-403) ---

    /// Chờ tới khi `done()` đúng, và **NÓI RA nếu hết hạn**.
    ///
    /// Mọi vòng chờ của bài tự kiểm đi qua đây. Trước đó mỗi chỗ tự viết một vòng `while … Date()
    /// < deadline`, và khi hết hạn thì chúng lặng lẽ đi tiếp — bài kiểm sau đó đọc một panel còn
    /// rỗng rồi đỏ với một thông báo chẳng liên quan gì tới nguyên nhân, hoặc tệ hơn là vẫn xanh.
    ///
    /// Ba lần trong dự án này một vòng chờ như thế đốt trọn 30 giây mà không ai biết, và triệu
    /// chứng duy nhất là "hôm nay chạy lâu thế". Một dòng cảnh báo mang TÊN chỗ chờ biến ba
    /// tiếng truy thành ba giây đọc.
    @discardableResult
    private func waitForSelfTest(
        _ name: String, seconds: Double = 30, until done: () -> Bool
    ) -> Bool {
        if done() { return true }
        let deadline = Date().addingTimeInterval(seconds)
        while !done(), Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        let ok = done()
        if !ok {
            FileHandle.standardError.write(Data("⚠️  \(name): hết hạn \(Int(seconds))s mà điều kiện chờ vẫn chưa đúng — mọi kết luận sau đây đều đáng ngờ\n".utf8))
        }
        return ok
    }

    /// Bật bảng và CHỜ lượt dựng chỉ mục xong.
    ///
    /// Chỉ mục dựng ở luồng nền, nên bài tự kiểm phải chờ. Không chờ thì bài nào cũng kiểm một
    /// cái bảng còn rỗng và xanh vì lý do sai.
    ///
    /// **Chờ theo SỐ LƯỢT ĐÃ XONG, không theo "bảng đã hiện chưa".** Yêu cầu dựng bảng kết
    /// thúc mà không hiện gì là chuyện bình thường — tài liệu rỗng thì `showTableView` nói
    /// "không có gì để hiện" rồi thôi. Chờ theo trạng thái hiện/ẩn thì lượt ấy đốt trọn hạn 30
    /// giây, và hàm này KHÔNG đỏ, chỉ chậm. Bộ chạy dài `--soak` bấm bảng vài trăm lần trên
    /// tài liệu đủ mọi hình dạng, nên nó biến 30 giây thành hàng giờ — đó là cách chỗ này lộ
    /// ra. Cùng luật với `openCleanBenchForSelfTest`.
    func showTableViewForSelfTest() {
        guard !isTableViewVisible else { return }
        let before = csvTableRequests
        toggleTableView(nil)
        waitForSelfTest("showTableViewForSelfTest") { self.csvTableRequests != before }
        csvTable.layoutSubtreeIfNeeded()
    }

    func showTextViewForSelfTest() { if isTableViewVisible { toggleTableView(nil) } }
    var isTableViewVisibleForSelfTest: Bool { isTableViewVisible }
    var csvIndexRowCountForSelfTest: Int { csvIndex?.rowCount ?? 0 }
    func runColumnCommandForSelfTest(_ command: CSVTableView.ColumnCommand) {
        runColumnCommand(command)
    }

    /// Tên cột mà panel kiểm tra dữ liệu đang dùng.
    var validationColumnNamesForSelfTest: [String] { validationPanel.columnNamesForSelfTest }

    /// Chạy kiểm tra dữ liệu và CHỜ kết quả về.
    ///
    /// Kiểm tra chạy ở luồng nền; không chờ thì bài tự kiểm đọc một panel còn rỗng.
    func validateForSelfTest() {
        let before = validationRequests
        validateCSV(nil)
        waitForSelfTest("validateForSelfTest") { self.validationRequests != before }
    }

    /// Mở Bàn làm sạch và CHỜ lượt quét nền xong.
    ///
    /// Chờ theo SỐ LƯỢT QUÉT, không theo "panel đã hiện chưa": panel còn mở sẵn từ tài liệu
    /// trước thì điều kiện "đã hiện" đúng ngay lập tức, và bài kiểm đọc danh mục của file cũ.
    /// Đúng lỗi ấy đã làm bốn bài kiểm đỏ với những thông báo chẳng liên quan gì tới nguyên
    /// nhân ("không có phát hiện nào").
    func openCleanBenchForSelfTest() {
        let before = cleanBenchRequests
        showCleanBench(nil)
        waitForSelfTest("openCleanBenchForSelfTest") { self.cleanBenchRequests != before }
    }

    /// Dựng sheet xem trước cho một phát hiện, không mở nó ra.
    func makeCleanSheetForSelfTest(_ finding: CSVCleanFinding) -> CSVCleanSheet {
        CSVCleanSheet(
            finding: finding, buffer: editorDocument.buffer, dialect: csvDialect, spec: nullSpec
        )
    }

    /// Chạy một bước làm sạch và CHỜ nó áp xong, kể cả lượt quét lại sau đó.
    func runCleanStepForSelfTest(_ step: CSVCleanStep, finding: CSVCleanFinding) {
        let appliedBefore = cleanPanel.applied.count
        let scansBefore = cleanPanel.scanCount
        runCleanStep(step, for: finding)

        waitForSelfTest("runCleanStepForSelfTest/apply") {
            self.cleanPanel.applied.count != appliedBefore
        }
        // Lượt quét lại chạy sau khi áp; chờ nốt để danh mục trên panel là danh mục MỚI, chứ
        // không phải danh mục nói về một file không còn tồn tại.
        waitForSelfTest("runCleanStepForSelfTest/rescan") {
            self.cleanPanel.scanCount != scansBefore
        }
    }

    func exportCleanReportForSelfTest() { exportCleanReport() }

    /// Ghi một file tạm rồi MỞ nó như người dùng vẫn mở.
    ///
    /// Function List nhận ngôn ngữ theo ĐUÔI FILE, nên bài kiểm phải đi qua một đường dẫn
    /// thật. Dựng tài liệu chưa đặt tên rồi gán đuôi sau lưng sẽ kiểm một đường mà sản phẩm
    /// không có.
    @discardableResult
    func openSelfTestFile(_ text: String, extension ext: String) -> String? {
        let path = NSTemporaryDirectory()
            + "geditor-selftest-\(UUID().uuidString).\(ext)"
        guard (try? Data(text.utf8).write(to: URL(fileURLWithPath: path))) != nil else { return nil }
        open(path: path)
        return path
    }

    /// Mở sidebar và CHỜ mục lục dựng xong.
    func openFunctionListForSelfTest() {
        if functionList.isHidden { toggleSidebar(nil) } else { refreshFunctionList() }
        waitForSelfTest("openFunctionListForSelfTest") {
            !self.functionList.titleForSelfTest.contains("Đang đọc")
        }
    }

    func closeFunctionListForSelfTest() { if isSidebarVisible { toggleSidebar(nil) } }
    var functionListVisibleForSelfTest: Bool { isSidebarVisible }

    func formatJSONForSelfTest() { formatJSON(nil) }
    func minifyJSONForSelfTest() { minifyJSON(nil) }
    func sortJSONKeysForSelfTest() { sortJSONKeys(nil) }
    func lintYAMLForSelfTest() { lintYAML(nil) }

    func refreshCompletionForSelfTest() { refreshCompletion() }
    /// Đưa con nháy về cuối tài liệu — bài kiểm gợi ý cần đứng ngay sau từ đang gõ dở.
    func editorViewSetCaretToEndForSelfTest() {
        let end = editorDocument.buffer.count
        editorView.repaginate(around: end)
        editorView.setCaret(documentOffset: end)
    }
    func setCompletionEnabledForSelfTest(_ on: Bool) {
        completionEnabled = on
        if !on { completionPopup.hide() }
    }

    /// Mở workspace và chờ cây hiện ra.
    func openWorkspaceForSelfTest(_ path: String) {
        openWorkspace(path)
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }

    func runWorkspaceCommandForSelfTest(_ command: WorkspaceView.Command) {
        runWorkspaceCommand(command)
    }

    /// Dựng sheet công thức mà không mở ra.
    func makeRecipeSheetForSelfTest(_ recipe: CSVRecipe) -> CSVRecipeSheet {
        CSVRecipeSheet(
            recipe: recipe,
            columnNames: CSVRecipeRunner.headerNames(
                in: editorDocument.buffer, dialect: csvDialect, hasHeader: true
            )
        )
    }

    func applyRecipeForSelfTest(_ recipe: CSVRecipe) { applyRecipe(recipe) }
    func showRecipeSheetForSelfTest(_ recipe: CSVRecipe) { presentRecipeSheet(recipe) }

    /// Công thức dựng từ nhật ký các bước đã áp — đúng thứ nút "Lưu công thức…" sẽ ghi ra.
    func recipeFromLogForSelfTest(name: String) -> CSVRecipe {
        CSVRecipe(name: name, sourceFile: nil, steps: cleanPanel.applied.map {
            CSVRecipeStep(
                columnName: $0.columnName, columnIndex: $0.step.column, kind: $0.step.kind
            )
        })
    }

    /// Mở tab Hồ sơ và CHỜ phép quét nền xong.
    func openProfileForSelfTest() {
        cleanPanel.selectModeForSelfTest(.profile)
        waitForSelfTest("openProfileForSelfTest") { self.cleanPanel.profileForSelfTest != nil }
    }
    func showCleanSheetForSelfTest(_ finding: CSVCleanFinding) { showCleanSheet(for: finding) }
    func closeCleanPanelForSelfTest() { hideCleanPanel() }
    var cleanPanelVisibleForSelfTest: Bool { isAttached(.clean) && !cleanPanel.isHidden }

    /// Dựng sheet chuyển đổi mà KHÔNG mở nó ra — bài tự kiểm không bấm được nút trong sheet.
    func makeConvertSheetForSelfTest() -> CSVConvertSheet {
        CSVConvertSheet(
            buffer: editorDocument.buffer, dialect: csvDialect, tableName: "du_lieu"
        )
    }

    /// Chạy chuyển đổi ĐỒNG BỘ rồi mở thành tab mới, bỏ qua sheet.
    func convertForSelfTest(_ format: CSVExport.Format) {
        guard let text = try? CSVExport.convert(
            editorDocument.buffer, dialect: csvDialect, to: format, tableName: "du_lieu"
        ) else { return }
        openConverted(text, format: format, name: "du_lieu")
    }

    func changeDelimiterForSelfTest(_ delimiter: UInt8) {
        let item = NSMenuItem()
        item.representedObject = delimiter
        applyDelimiterChange(item)
    }

    var validationPanelVisibleForSelfTest: Bool { isAttached(.validation) && !validationPanel.isHidden }
    func closeValidationPanelForSelfTest() { hideValidationPanel() }
    var csvTypeIssueRowsForSelfTest: Set<Int> { Set(csvTable.typeIssues.keys) }
    var csvHeaderVisibleForSelfTest: Bool { editorView.csvHeaderVisibleForSelfTest }
    var csvHeaderTextForSelfTest: String { editorView.csvHeaderTextForSelfTest }
    var csvHeaderColumnsForSelfTest: Int { editorView.csvHeaderColumnsForSelfTest }
    func csvHeaderColorForSelfTest(_ index: Int) -> NSColor? {
        editorView.csvHeaderColorForSelfTest(index)
    }
    func scrollToForSelfTest(_ offset: Int) { editorView.scrollToDocumentOffsetForSelfTest(offset) }
    var csvDialectForSelfTest: CSVDialect { csvDialect }
    var statusModeForSelfTest: String? { statusBar.state.mode }
    var tabWidthForSelfTest: Int { statusBar.state.tabWidth }
    var settingsTabWidthForSelfTest: Int { settings.tabWidth }
    /// Khai (hoặc bỏ khai) thụt lề riêng cho một ngôn ngữ, KHÔNG ghi xuống đĩa.
    ///
    /// Bài kiểm không được để lại vết trong `settings.json` thật của người đang ngồi máy —
    /// cùng lý do với cờ `--crash-root` mà `check-crash-reporter.sh` đã phải sửa.
    func setLanguageIndentForSelfTest(_ language: String, _ style: Settings.IndentStyle?) {
        settings.languageIndent[language] = style
        refreshChrome()
    }
    /// Chữ ĐANG HIỆN trên hai mục vị trí và cỡ tài liệu.
    ///
    /// Hỏi cái NHÃN chứ không hỏi `state`: bài kiểm phải thấy đúng thứ người dùng đọc được, và
    /// một trường trong `State` mà `apply()` quên vẽ ra thì vẫn đúng khi hỏi `state`.
    var statusCaretTitleForSelfTest: String { statusBar.titleForSelfTest(.caret) }
    var statusDocSizeTitleForSelfTest: String { statusBar.titleForSelfTest(.docSize) }
    /// Menu vừa được bung ra — xem `present(_:from:)`.
    var lastPresentedMenuForSelfTest: NSMenu? { lastPresentedMenu }
    /// Bấm một mục của thanh trạng thái đúng đường mà con chuột đi.
    func clickStatusSegmentForSelfTest(_ segment: StatusBarView.Segment) {
        statusBar.clickSegmentForSelfTest(segment)
    }
    /// Xoá dải băng để phép hỏi tiếp theo không đọc trúng tin của lần trước.
    func clearTransientForSelfTest() { lastTransient = "" }
    /// Vùng chọn hiện tại theo offset tài liệu — dùng cho vết của bộ chạy dài.
    var selectedRangeForSelfTest: Range<Int> { editorView.selectedDocumentRange }
    /// Danh tính các nút của thanh tab — xem `TabBarView.buttonIdentitiesForSelfTest`.
    var tabButtonIdentitiesForSelfTest: [ObjectIdentifier] { tabBar.buttonIdentitiesForSelfTest }
    /// Từng mục của thanh trạng thái — xem `StatusBarView.segmentsForSelfTest`.
    var statusSegmentsForSelfTest: [(name: String, identity: ObjectIdentifier, title: String, hidden: Bool)] {
        statusBar.segmentsForSelfTest
    }
    /// Cột đang hiện trên thanh trạng thái, và nó có phải con số ước lượng không.
    var statusCaretColumnForSelfTest: (column: Int, approximate: Bool) {
        (statusBar.state.caretColumn, statusBar.state.caretColumnIsApproximate)
    }
    func columnColorForSelfTest(at offset: Int) -> NSColor? {
        editorView.syntaxColorForSelfTest(atDocumentOffset: offset)
    }

    func setSyntaxLanguageForSelfTest(_ language: SyntaxLanguage?) {
        editorView.syntaxLanguage = language
    }
    var syntaxLanguageForSelfTest: SyntaxLanguage? { editorView.syntaxLanguage }
    func waitForHighlightingForSelfTest() -> Bool { editorView.waitForHighlightingForSelfTest() }
    func syntaxColorForSelfTest(at offset: Int) -> NSColor? {
        editorView.syntaxColorForSelfTest(atDocumentOffset: offset)
    }
    var hasSyntaxColorsForSelfTest: Bool { editorView.hasSyntaxColorsForSelfTest }
    var statusLanguageForSelfTest: String { statusBar.state.language }

    // MARK: - Móc tự kiểm cho macro (FR-AUTO-601/602)

    func toggleMacroRecordingForSelfTest() { toggleMacroRecording(nil) }
    var recordedMacroStepsForSelfTest: [MacroStep] { currentMacro?.steps ?? [] }
    func setMacroForSelfTest(_ steps: [MacroStep]) {
        currentMacro = Macro(name: "tự kiểm", steps: steps)
    }
    func runMacroForSelfTest(repetitions: Int) { runMacro(repetitions: repetitions) }
    func runMacroOnAllTabsForSelfTest() { playMacroOnAllTabs(nil) }
    /// Gửi một lệnh soạn thảo đúng đường AppKit thật (`doCommand(by:)`).
    func sendCommandForSelfTest(_ selector: Selector) {
        editorView.textView.doCommand(by: selector)
    }
    func useTemporaryMacroStoreForSelfTest() -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-macro-\(UUID().uuidString)")
        macroStore = MacroStore(root: root)
        Unattended.registerTemporaryRoot(root)
        return root
    }
    func saveCurrentMacroForSelfTest(named name: String) -> Bool {
        guard let macro = currentMacro else { return false }
        do {
            try macroStore.save(Macro(name: name, steps: macro.steps))
            return true
        } catch {
            return false
        }
    }
    var savedMacroNamesForSelfTest: [String] { ((try? macroStore.all()) ?? []).map(\.name) }
    var savedMacroMenuTitlesForSelfTest: [String] { makeSavedMacroMenu().items.map(\.title) }

    // MARK: - Móc tự kiểm cho chia đôi màn hình (FR-DOC-302 · TC-DOC-05)

    func splitForSelfTest(vertical: Bool) { openSplit(vertical: vertical) }
    func closeSplitForSelfTest() { closeSplit() }
    var isSplitForSelfTest: Bool { isSplit }
    func paneTextForSelfTest(_ index: Int) -> String { paneViews[index].visibleTextForSelfTest }
    func paneDocumentIsSameForSelfTest() -> Bool {
        document(shownIn: paneViews[0]) === document(shownIn: paneViews[1])
    }
    /// Chuyển con trỏ gõ sang một nửa màn hình — **chỉ khi nửa ấy có thật**.
    ///
    /// `guard isSplit` không phải phòng thủ thừa, nó là điều kiện mà SẢN PHẨM có: `focusOtherPane`
    /// mở đầu bằng đúng dòng ấy, và `onFocus` chỉ nổ cho pane đang nằm trong cây view. Bỏ nó
    /// đi thì móc này dựng được một trạng thái ứng dụng KHÔNG BAO GIỜ tới được: nửa thứ hai
    /// đang ẩn lại là nửa đang gõ, nên `editorView` trỏ vào một view giữ buffer cũ trong khi
    /// `editorDocument` đã là tài liệu khác.
    ///
    /// Bộ chạy dài `--soak` sập vì đúng chỗ này, và mất một vòng truy mới rõ thủ phạm là bộ đo
    /// chứ không phải app. **Một móc tự kiểm dựng được trạng thái mà người dùng không dựng được
    /// thì mọi lỗi nó tìm ra đều phải nghi ngờ** — nó tiêu thời gian của người sửa vào những
    /// thứ không ai gặp, và tệ hơn, nó làm người ta mất tin vào cả bộ đo.
    func focusPaneForSelfTest(_ index: Int) {
        guard isSplit || index == 0 else { return }
        activePaneIndex = index
        refreshChrome()
    }
    func paneScrollForSelfTest(_ index: Int) -> Double { paneViews[index].scrollOriginForSelfTest }
    func paneSizeForSelfTest(_ index: Int) -> (width: Double, height: Double) {
        let frame = paneViews[index].frame
        return (Double(frame.width), Double(frame.height))
    }
    func showTabInOtherPaneForSelfTest() { showTabInOtherPane(nil) }
    func moveTabForSelfTest(from: Int, to: Int) { moveTab(from: from, to: to) }
    var paneTabIndicesForSelfTest: [Int] { paneTabIndices }

    /// Nửa đang gõ có đang hiện ĐÚNG tài liệu mà lệnh sửa sẽ nhắm tới không.
    ///
    /// Bất biến này không hiện ra trên màn hình, nên chỉ có bài kiểm mới canh được nó. Xem
    /// `syncPanesToTheirTabs` để biết vì sao nó đáng canh: hai bên lệch nhau thì mọi phím gõ
    /// tính trên tài liệu này và áp lên tài liệu kia.
    var panesInSyncForSelfTest: Bool { editorView.buffer === editorDocument.buffer }
    /// Tài liệu mà CHỈ SỐ của mỗi nửa đang trỏ tới — khác với chữ đang hiện trên màn hình.
    var paneTargetPathsForSelfTest: [String?] {
        paneTabIndices.map { tabs.indices.contains($0) ? tabs[$0].document.path : nil }
    }
    func dropTabForSelfTest(_ index: Int, intoPane pane: Int) -> Bool {
        // Điểm GIỮA pane đích, quy về toạ độ MÀN HÌNH — đúng thứ vòng kéo thật truyền vào.
        let view = paneViews[pane]
        let center = NSPoint(x: view.bounds.midX, y: view.bounds.midY)
        let inWindow = view.convert(center, to: nil)
        dropTab(index, atScreenPoint: window?.convertPoint(toScreen: inWindow) ?? inWindow)
        return paneTabIndices[pane] == index
    }
    /// Thả tab ở một điểm MÀN HÌNH — đúng thứ vòng kéo thật truyền vào (FR-DOC-302).
    ///
    /// Bài kiểm gọi thẳng hàm này thay vì giả lập chuỗi sự kiện chuột: chuỗi ấy đòi một vòng
    /// `nextEvent` thật, và bơm sự kiện giả vào hàng đợi của AppKit là kiểm chính đoạn bơm chứ
    /// không kiểm phép quyết định. Phép quyết định — "điểm này rơi vào cửa sổ nào" — mới là
    /// thứ có thể sai.
    func dropTabAtScreenPointForSelfTest(_ index: Int, _ point: NSPoint) {
        dropTab(index, atScreenPoint: point)
    }

    /// Ghim/bỏ ghim đi qua ĐÚNG hàm mà menu ngữ cảnh gọi.
    func togglePinForSelfTest(_ index: Int) {
        let item = NSMenuItem()
        item.representedObject = index
        menuTogglePin(item)
    }

    func detachTabForSelfTest(_ index: Int) -> EditorTab? { detachTab(at: index) }

    func activateTabForSelfTest(_ index: Int) { activateTab(index) }

    /// Chuyển tới tab của một đường dẫn — bài tự kiểm nào mở ra tab mới rồi cần quay lại.
    func activateTabForSelfTest(path: String) {
        guard let index = tabs.firstIndex(where: { $0.document.path == path }) else { return }
        activateTab(index)
    }

    func undoForSelfTest() { undoDocument(nil) }

    /// Áp bảng duyệt BỎ QUA hộp hỏi — chỉ dành cho bài tự kiểm.
    ///
    /// Đường thật luôn hỏi, và trong lượt chạy không người thì `Unattended.ask` trả `.abort`
    /// nên không gì được áp. Bài kiểm cần cả hai vế: vế "hỏi mà không ai bấm thì KHÔNG áp" đi
    /// qua đường thật, còn phần còn lại của chu trình đi qua đường này.
    func applyEntityResolutionForSelfTest() { applyEntityResolution(confirmed: true) }
    /// Bốn phép FR-KNW-916, bỏ qua ĐÚNG hai chốt mà lượt chạy không người vốn chặn: ô nhập
    /// tên và hộp hỏi. Đường không-người vẫn được kiểm riêng ở chính bài kiểm ấy.
    func renameGraphNodeForSelfTest(to name: String) {
        renameGraphNode(newName: name, confirmed: true)
    }
    func splitGraphNodeForSelfTest(to name: String) {
        splitGraphNode(newName: name, confirmed: true)
    }
    func mergeGraphNodesForSelfTest() { mergeGraphNodes(confirmed: true) }
    var isSplitVerticalForSelfTest: Bool { splitView.isVertical }
    func layoutWindowForSelfTest() {
        window?.layoutIfNeeded()
        window?.contentView?.layoutSubtreeIfNeeded()
    }
    func scrollPaneForSelfTest(_ index: Int, to y: Double) { paneViews[index].scrollToForSelfTest(y) }

    // MARK: - Móc tự kiểm cho phiên làm việc (FR-DOC-303)

    /// Trỏ hai kho (phiên và bản nháp) vào thư mục TẠM.
    ///
    /// Bắt buộc: không có nó thì bài tự kiểm ghi thẳng vào phiên và bản nháp THẬT của người
    /// đang chạy máy — chạy một lần là mất danh sách tab của họ.
    @discardableResult
    func useTemporaryStoresForSelfTest() -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-selftest-\(UUID().uuidString)")
        sessionStore = SessionStore(root: root.appendingPathComponent("session"))
        snapshotStore = SnapshotStore(root: root.appendingPathComponent("snapshots"))
        Unattended.registerTemporaryRoot(root)
        return root
    }

    func writeSnapshotsForSelfTest() { writeSnapshotIfNeeded() }
    func openInNewTabForSelfTest(path: String) { openInNewTab(path: path) }

    var findPanelStatusForSelfTest: String { findPanel.statusForSelfTest }
    func findPanelSetStatusForSelfTest(_ text: String) { findPanel.showStatus(text) }

    /// Phát một tin của BẢNG — bài kiểm hỏi tin ấy rơi vào đâu.
    func emitTableStatusForSelfTest(_ text: String) { csvTable.emitStatusForSelfTest(text) }
    func resetTabsForSelfTest() {
        tabs = [EditorTab(document: .untitled())]
        activeIndex = 0
        restoredDocumentIDs = []
        applyActiveTab()
        refreshTabBar()
    }
    var tabPathsForSelfTest: [String?] { tabs.map(\.document.path) }
    var tabCountForSelfTest: Int { tabs.count }
    func closeCurrentTabForSelfTest() { closeTab(at: activeIndex, force: true) }
    /// Đóng tab đi qua đường HỎI, đúng như khi người dùng bấm nút đóng.
    ///
    /// Khác `closeCurrentTabForSelfTest` ở chỗ nó KHÔNG ép: tài liệu đã sửa thì hộp thoại được
    /// dựng và đi qua `Unattended.ask`, tức là nhánh "người dùng bấm Huỷ" thật sự được chạy.
    /// Bộ chạy dài cần cả hai đường — ép mãi thì nửa còn lại của `closeTab` không ai đụng tới.
    func closeCurrentTabAskingForSelfTest() { closeTab(at: activeIndex) }
    var activeDocumentIsModifiedForSelfTest: Bool { editorDocument.isModified }

    /// Toàn văn tài liệu đang mở.
    var documentTextForSelfTest: String { editorDocument.buffer.text }

    /// Văn bản đang được BÔI SÁNG, không phải vị trí con nháy.
    ///
    /// Hai thứ khác nhau và bài kiểm cần đúng cái đầu: một cú nhảy đặt con nháy đúng chỗ vẫn có
    /// thể bôi sáng sai vùng, và người dùng nhìn thấy vùng bôi sáng chứ không nhìn con nháy.
    var selectedTextForSelfTest: String {
        let ranges = editorView.selection.ranges.filter { !$0.isEmpty }
        guard let range = ranges.first else { return "" }
        return String(decoding: editorDocument.buffer.bytes(in: range), as: UTF8.self)
    }
    var tabCaretsForSelfTest: [Int] { tabs.map(\.caretOffset) }
    var tabTextsForSelfTest: [String] { tabs.map(\.document.buffer.text) }
    var activeTabIndexForSelfTest: Int { activeIndex }
    func setTabPinnedForSelfTest(_ index: Int, _ pinned: Bool) { tabs[index].isPinned = pinned }
    var tabPinnedForSelfTest: [Bool] { tabs.map(\.isPinned) }

    /// Bấm một mục của menu màu, đi đúng đường `target/action` thật.
    func pickMarkColorFromMenuForSelfTest(_ index: Int) -> Bool {
        let menu = makeMarkColorMenu()
        guard let item = menu.item(at: index), let action = item.action, let target = item.target
        else { return false }
        _ = (target as AnyObject).perform(action, with: item)
        return true
    }

    var markMenuTitlesForSelfTest: [String] { makeMarkColorMenu().items.map(\.title) }
    var activeMarkColorForSelfTest: Int { marks.activeColor }
    func deleteMarkedLinesForSelfTest() { deleteMarkedLines(nil) }
    var characterWidthForSelfTest: Double { editorView.characterWidthForSelfTest }
    var editorWidthForSelfTest: Double { editorView.editorWidthForSelfTest }
    func fullyLaidOutHeightForSelfTest() -> Double { editorView.fullyLaidOutHeightForSelfTest() }

    /// Bấm mũi tên xuống — dùng để kiểm caret đi theo HÀNG MÀN HÌNH chứ không theo dòng tài liệu.
    func moveDownForSelfTest() { editorView.textView.moveDown(nil) }
    var caretOffsetForSelfTest: Int { editorView.selectedDocumentRange.lowerBound }

    // MARK: - Nhiều caret (FR-CORE-001)

    /// Gõ hoặc xóa khi đang có nhiều caret.
    ///
    /// Sinh tất cả sửa đổi rồi áp bằng MỘT `applyEdits`: 1.000 caret vẫn là MỘT bước undo
    /// (FR-CORE-004). Sau đó phải TÍNH LẠI vị trí caret — chèn "x" vào ba caret thì caret thứ
    /// hai đã dịch 1 byte, và không tính lại thì ký tự thứ hai rơi sai chỗ.
    private func applyMultiCaretEdit(_ selection: MultiSelection, _ kind: WindowedTextView.MultiEditKind) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }

        let buffer = editorDocument.buffer
        let edits: [TextEdit]
        let label: String
        switch kind {
        case .insert(let text):
            edits = selection.edits(inserting: text)
            label = "Gõ trên \(selection.count) caret"
        case .deleteBackward:
            edits = selection.editsDeletingBackward(in: buffer)
            label = "Xóa trên \(selection.count) caret"
        case .deleteForward:
            edits = selection.editsDeletingForward(in: buffer)
            label = "Xóa trên \(selection.count) caret"
        }
        guard !edits.isEmpty else { return }

        buffer.applyEdits(edits, label: label)
        let moved = selection.afterApplying(edits)
        editorDocument.refreshEOLReport()
        syncViewFromBuffer()
        editorView.setSelection(moved)
        refreshChrome()
    }

    /// Bộ gõ vừa chốt `text` ở caret chính — nhân nó sang các caret còn lại (TC-IME-02).
    ///
    /// Caret chính đã có chữ rồi (bộ gõ tự chèn), nên ở đây CHỈ chèn vào những caret khác. Áp
    /// một lần để cả cụm vẫn là một bước undo cùng với phần bộ gõ vừa làm thì không được —
    /// bộ gõ đã đóng bước của nó — nên đây là bước undo thứ hai, và nhãn nói rõ điều đó.
    private func mirrorCompositionToOtherCarets(_ selection: MultiSelection, _ text: String) {
        guard selection.isMultiple, !text.isEmpty, !editorDocument.isReadOnly else { return }

        let committedLength = text.utf8.count
        var edits: [TextEdit] = []
        var carets: [Range<Int>] = []
        var shift = 0

        for (index, range) in selection.ranges.enumerated() {
            if index == selection.primaryIndex {
                // Caret chính: chữ đã nằm sẵn, chỉ dời theo phần đã chèn trước nó.
                let position = range.lowerBound + shift + committedLength
                carets.append(position ..< position)
                shift += committedLength - range.count
                continue
            }
            let start = range.lowerBound + shift
            edits.append(TextEdit(range: start ..< start + range.count, text: text))
            let position = start + committedLength
            carets.append(position ..< position)
            shift += committedLength - range.count
        }

        guard !edits.isEmpty else { return }
        editorDocument.buffer.applyEdits(edits, label: "Nhân bản chữ vừa gõ ra \(selection.count) caret")
        syncViewFromBuffer()
        editorView.setSelection(MultiSelection(carets, primaryIndex: selection.primaryIndex))
        refreshChrome()
    }

    /// Column Editor (FR-CORE-003) — chèn văn bản / dãy số / dãy ngày vào mọi dòng của khối.
    @objc func showColumnEditor(_ sender: Any?) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        let selection = editorView.selection
        guard selection.isMultiple else {
            showBanner("Chọn một khối cột trước (giữ Option rồi kéo chuột), hoặc đặt nhiều caret bằng ⌘D",
                       actionTitle: nil, action: nil)
            return NSSound.beep()
        }

        guard let window else { return }
        let panel = ColumnEditorPanel(lineCount: selection.count)
        columnEditorPanel = panel          // giữ lại, nếu không sheet biến mất cùng lúc với nó
        panel.present(over: window) { [weak self] content in
            self?.columnEditorPanel = nil
            guard let self, let content else { return }
            let values = ColumnEditor.values(content, count: selection.count)
            let edits = selection.edits(insertingEach: values)
            guard !edits.isEmpty else { return }

            editorDocument.buffer.applyEdits(edits, label: "Column Editor · \(selection.count) dòng")
            let moved = selection.afterApplying(edits)
            editorDocument.refreshEOLReport()
            syncViewFromBuffer()
            editorView.setSelection(moved)
            refreshChrome()
        }
    }

    /// ⌘C — chép; khi đang chọn khối thì chép thành nhiều DÒNG (FR-CORE-002).
    @objc func copySelection(_ sender: Any?) {
        // Cây cấu trúc đang che vùng soạn thảo thì ⌘C chép ĐƯỜNG DẪN của nút đang chọn.
        //
        // Cùng lỗi với cú bấm trong sơ đồ chiếm trọn tab, chỉ khác chiều: một lệnh chung tác
        // động lên thứ đang bị che, nên người dùng bấm ⌘C trên một nút và dán ra được một đoạn
        // văn bản họ không nhìn thấy — không có gì báo là đã chép nhầm thứ.
        //
        // Và đường dẫn là thứ đáng chép nhất ở đây: nó dán thẳng vào ô truy vấn JSONPath ngay
        // trong sản phẩm này, vào `yq`, vào một bài kiểm. Chép cái NHÃN thì người ta vẫn phải
        // tự lần lại đường đi.
        // Trang tài liệu cũng nằm ĐÈ lên vùng soạn thảo — cùng luật với cây cấu trúc và bảng
        // CSV: ⌘C phải chép thứ đang bôi đen TRÊN TRANG, không phải thứ đang chọn ở một vùng
        // soạn thảo mà người dùng không nhìn thấy.
        if isOfficePreviewVisible {
            let text = officePreview.pages.selectedText
            guard !text.isEmpty else {
                return showTransient(L("Chưa chọn chữ nào trên trang."))
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            clipboardRing.record(text)
            showTransient(L("Đã chép") + " " + LF("%d ký tự", text.count))
            return
        }
        if isStructureTreeVisible {
            guard let path = structureTree.selectedPathText else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
            clipboardRing.record(path)
            showTransient(L("Đã chép") + ": " + path)
            return
        }
        // Bảng CSV cũng nằm ĐÈ lên vùng soạn thảo, nên cùng luật: ⌘C chép HÀNG đang chọn.
        if isTableViewVisible {
            guard let row = csvTable.selectedRowForCopy else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(row, forType: .string)
            clipboardRing.record(row)
            showTransient(LF("Đã chép %d dòng", 1))
            return
        }
        let selection = editorView.selection
        let text = selection.isMultiple
            ? selection.blockText(in: editorDocument.buffer)
            : editorView.selectedText
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        clipboardRing.record(text)
    }

    // MARK: - Lịch sử clipboard (FR-CORE-017)

    /// ⇧⌘V — chọn một mục đã chép trước đó để dán.
    @objc func showClipboardHistory(_ sender: Any?) {
        let menu = NSMenu(title: "Lịch sử clipboard")
        guard !clipboardRing.isEmpty else {
            menu.addItem(
                withTitle: "Chưa chép gì trong phiên này", action: nil, keyEquivalent: ""
            ).isEnabled = false
            present(menu, from: sender)
            return
        }
        for (index, entry) in clipboardRing.entries.enumerated() {
            let item = menu.addItem(
                withTitle: ClipboardRing.label(for: entry),
                action: #selector(pasteFromClipboardHistory(_:)),
                // Chín mục đầu có ⌘1…⌘9 NGAY TRONG menu bật lên — chỉ có tác dụng khi menu
                // đang mở, nên không giành phím với bất kỳ lệnh nào của menu bar.
                keyEquivalent: index < 9 ? "\(index + 1)" : ""
            )
            item.target = self
            item.representedObject = index
        }
        menu.addItem(.separator())
        let clear = menu.addItem(
            withTitle: "Xoá lịch sử", action: #selector(clearClipboardHistory(_:)), keyEquivalent: ""
        )
        clear.target = self
        present(menu, from: sender)
    }

    @objc private func pasteFromClipboardHistory(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int,
              let text = clipboardRing.entry(at: index) else { return }
        // Đưa lên clipboard hệ điều hành TRƯỚC rồi mới dán, để ⌘V lần sau vẫn ra đúng thứ vừa
        // chọn — người dùng chọn một mục cũ nghĩa là họ muốn nó thành mục đang dùng.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        clipboardRing.record(text)
        pasteSelection(nil)
    }

    @objc private func clearClipboardHistory(_ sender: Any?) {
        clipboardRing.clear()
    }

    // MARK: - Khớp ngoặc (FR-CORE-012)

    /// ⌃⌘B — nhảy tới dấu ngoặc khớp với dấu ở con nháy.
    @objc func goToMatchingBracket(_ sender: Any?) {
        guard let match = currentBracketMatch() else {
            showTransient(
                editorDocument.buffer.count > BracketMatcher.fullScanLimit
                    ? "Tài liệu quá lớn để khớp ngoặc chắc chắn đúng"
                    : "Con nháy không đứng ở dấu ngoặc nào có cặp"
            )
            return
        }
        editorView.setSelectedDocumentRange(match.partner ..< match.partner)
        editorView.reveal(documentOffset: match.partner)
    }

    /// Cặp ngoặc quanh con nháy hiện tại.
    func currentBracketMatch() -> BracketMatcher.Match? {
        BracketMatcher.match(
            in: editorDocument.buffer,
            at: editorView.selectedDocumentRange.lowerBound,
            language: editorView.syntaxLanguage
        )
    }

    /// ⌘V — dán; khối nhiều dòng vào một caret thì GIỮ HÌNH CHỮ NHẬT (FR-CORE-002).
    @objc func pasteSelection(_ sender: Any?) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }

        let selection = editorView.selection
        let lines = text.components(separatedBy: "\n")

        // Dán một dòng vào một caret là việc thường — để NSTextView làm, nó lo cả undo của nó.
        guard selection.isMultiple || lines.count > 1 else {
            editorView.textView.paste(sender)
            return
        }

        let edits = selection.edits(
            pastingBlock: lines, in: editorDocument.buffer, tabWidth: effectiveIndent.width)
        guard !edits.isEmpty else { return }
        editorDocument.buffer.applyEdits(edits, label: "Dán khối \(lines.count) dòng")
        let moved = selection.afterApplying(edits)
        editorDocument.refreshEOLReport()
        syncViewFromBuffer()
        editorView.setSelection(moved)
        refreshChrome()
    }

    /// ⌘D — chọn lần xuất hiện kế tiếp của vùng đang chọn, hoặc của từ dưới con trỏ.
    @objc func selectNextOccurrence(_ sender: Any?) {
        let buffer = editorDocument.buffer
        var selection = editorView.selection

        // Chưa chọn gì thì chọn TỪ dưới con trỏ trước — bấm ⌘D lần đầu là "chọn từ này".
        if !selection.hasSelection {
            let word = OccurrenceSearch.word(at: selection.primary.lowerBound, in: buffer)
            guard !word.isEmpty else { return NSSound.beep() }
            selection.setSingle(word)
            editorView.setSelection(selection)
            return
        }

        let needle = buffer.bytes(in: selection.primary)
        guard let next = OccurrenceSearch.next(needle, in: buffer, after: selection.primary.upperBound)
        else { return NSSound.beep() }

        selection.add(next)
        editorView.setSelection(selection)
        editorView.reveal(documentOffset: next.lowerBound)
        findPanel.showStatus("\(selection.count) vùng chọn")
    }

    // MARK: - Tab (FR-DOC-301)

    /// Mở file trong TAB MỚI, hoặc nhảy tới tab đang mở file đó.
    ///
    /// Mở lại file đang mở thành tab thứ hai là cách chắc chắn để hai tab ghi đè lên nhau —
    /// và người dùng gõ `geditor file.txt` lần thứ hai chỉ muốn quay lại chỗ cũ.
    func openInNewTab(path: String, line: Int? = nil, column: Int? = nil, readOnly: Bool = false) {
        if let existing = tabs.firstIndex(where: { $0.document.path == path }) {
            activateTab(existing)

            // File đã đổi trên đĩa từ lần mở trước: nạp lại, nhưng chỉ khi bản trong app CHƯA
            // sửa gì. Có sửa thì giữ nguyên và để đường cảnh báo "đổi bên ngoài" lo — nạp đè
            // lên phần người dùng đang làm là mất dữ liệu.
            if !editorDocument.isModified, editorDocument.externalChange() == .modified,
               let reloaded = try? Self.openAnyDocument(path: path) {
                loadDocument(reloaded)
            }
            if let line { goTo(line: line, column: column) }
            return
        }

        do {
            // Ảnh, PDF, Office, file nén: KHÔNG giải mã nhị phân thành văn bản. Đường cũ vẫn
            // "mở được" chúng — nó dựng một buffer đầy ký tự rác rồi chỉ mục dòng trên đó — và
            // đó đúng là thứ người dùng đang phàn nàn.
            let document = try Self.openAnyDocument(path: path)
            if readOnly { document.lockForReading() }
            saveActiveTabState()

            // Tab "Chưa đặt tên" chưa ai đụng vào thì THAY nó, đừng để lại một tab rỗng.
            if tabs.count == 1, tabs[0].document.path == nil, !tabs[0].document.isModified {
                tabs[0] = EditorTab(document: document)
            } else {
                tabs.insert(EditorTab(document: document), at: activeIndex + 1)
                activeIndex += 1
            }
            applyActiveTab()
            if let line { goTo(line: line, column: column) }
            saveSession()
        } catch {
            presentError("Không mở được file", error)
        }
    }

    @objc func newTab(_ sender: Any?) {
        saveActiveTabState()
        tabs.insert(EditorTab(document: .untitled()), at: activeIndex + 1)
        activeIndex += 1
        applyActiveTab()
    }

    @objc func closeCurrentTab(_ sender: Any?) { closeTab(at: activeIndex) }

    /// Đóng một tab.
    ///
    /// `force` bỏ qua câu hỏi "có thay đổi chưa lưu". CHỈ bộ tự kiểm dùng nó, và nó tồn tại vì
    /// một lý do cụ thể: `NSAlert.runModal()` trong một lượt chạy không người ngồi trước máy sẽ
    /// đứng mãi mãi, và cả bộ tự kiểm treo theo — không đỏ, không lỗi, chỉ treo. Đã xảy ra thật.
    func closeTab(at index: Int, force: Bool = false) {
        guard tabs.indices.contains(index) else { return }
        if !force, tabs[index].document.isModified {
            let name = tabs[index].document.path.map { ($0 as NSString).lastPathComponent } ?? "Chưa đặt tên"
            let alert = NSAlert()
            alert.messageText = "\(name) có thay đổi chưa lưu"
            alert.informativeText = "Đóng tab sẽ mất phần chưa lưu. Bản nháp tự động vẫn còn để khôi phục."
            alert.addButton(withTitle: "Đóng")
            alert.addButton(withTitle: "Huỷ")
            guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        }

        if let path = tabs[index].document.path {
            cliBridge?.documentClosed(path: path)
            noteRecentDocument(path)
            rememberClosedTab(path)
        }
        // Tab đi thì bộ theo dõi của nó cũng đi. Bỏ quên thì một `DispatchSource` cứ đọc tiếp
        // một file không còn ai xem, cho tới khi đóng cửa sổ.
        stopFollowingTail(inTab: index)
        tabs.remove(at: index)
        if tabs.isEmpty { tabs = [EditorTab(document: .untitled())] }
        activeIndex = min(activeIndex, tabs.count - 1)
        applyActiveTab()
    }

    func activateTab(_ index: Int) {
        guard tabs.indices.contains(index), index != activeIndex else { return }
        saveActiveTabState()
        activeIndex = index
        applyActiveTab()
    }

    // MARK: - File gần đây · mở lại tab vừa đóng (FR-DOC-312)

    private func rememberClosedTab(_ path: String) {
        closedTabPaths.removeAll { $0 == path }
        closedTabPaths.append(path)
        if closedTabPaths.count > 32 { closedTabPaths.removeFirst() }
    }

    /// Ghi vào danh sách file gần đây của hệ điều hành.
    ///
    /// Dùng `NSDocumentController` chứ không tự giữ danh sách: menu ▸ File gần đây và cả mục
    /// trong Dock đều lấy từ đó, nên tự làm một danh sách riêng sẽ ra hai danh sách không khớp.
    private func noteRecentDocument(_ path: String) {
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: path))
    }

    @objc func reopenLastClosedTab(_ sender: Any?) {
        while let path = closedTabPaths.popLast() {
            // File đã bị xoá trong lúc ấy thì bỏ qua và thử tiếp cái trước — mở ra một tab lỗi
            // là câu trả lời tệ hơn cho một phím tắt nghĩa là "lấy lại cái tôi vừa đóng".
            guard FileManager.default.fileExists(atPath: path) else { continue }
            open(path: path)
            return
        }
        showTransient("Không còn tab nào vừa đóng để mở lại")
    }

    /// Mở một file từ menu ▸ File gần đây.
    @objc func openRecentDocument(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        open(path: path)
    }

    /// Bung danh sách file gần đây.
    ///
    /// Bung ra khi bấm chứ không gắn sẵn làm menu con: danh sách phải dựng LẠI mỗi lần, và
    /// một menu con gắn cứng lúc dựng menu bar sẽ đứng yên ở nội dung của lần khởi động.
    @objc func showRecentDocumentsMenu(_ sender: Any?) {
        present(makeRecentDocumentsMenu(), from: sender)
    }

    /// Menu con "Mở gần đây", dựng lại mỗi lần bung ra.
    func makeRecentDocumentsMenu() -> NSMenu {
        let menu = NSMenu(title: "Mở gần đây")
        let urls = NSDocumentController.shared.recentDocumentURLs
        guard !urls.isEmpty else {
            menu.addItem(withTitle: "Chưa có file nào", action: nil, keyEquivalent: "").isEnabled = false
            return menu
        }
        for url in urls.prefix(15) {
            let item = menu.addItem(
                withTitle: url.lastPathComponent,
                action: #selector(openRecentDocument(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = url.path
            // Đường dẫn đầy đủ ở tooltip: hai file cùng tên ở hai thư mục khác nhau là chuyện
            // thường, và chỉ hiện tên thì không phân biệt được.
            item.toolTip = url.path
        }
        menu.addItem(.separator())
        let clear = menu.addItem(
            withTitle: "Xoá danh sách", action: #selector(clearRecentDocuments(_:)), keyEquivalent: ""
        )
        clear.target = self
        return menu
    }

    @objc func clearRecentDocuments(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(sender)
    }

    /// Thay toàn văn tài liệu từ AppleScript (FR-AUTO-606).
    ///
    /// Đi qua `apply` như mọi lệnh khác, nên là MỘT bước hoàn tác và người dùng ⌘Z được thứ
    /// script vừa làm. Một đường tắt ghi thẳng vào buffer sẽ lấy mất khả năng ấy — và script
    /// chạy khi người dùng không nhìn, nên đó đúng là lúc họ cần lùi được nhất.
    func replaceDocumentTextFromScripting(_ text: String) {
        guard text != editorDocument.buffer.text else { return }
        apply(
            [TextEdit(range: 0 ..< editorDocument.buffer.count, text: text)],
            label: "AppleScript"
        )
    }

    // MARK: - Gói mở rộng (FR-PLUG-701 · FR-PLUG-705)

    /// Thư mục đích của mọi gói.
    var pluginDestinations: PluginPackage.Destinations {
        PluginPackage.Destinations(
            scripts: AppPaths.scriptsDirectory,
            themes: AppPaths.themesDirectory,
            languages: AppPaths.grammarsDirectory
        )
    }

    @objc func showPluginManager(_ sender: Any?) {
        let menu = NSMenu(title: "Gói mở rộng")
        let installed = PluginPackage.installedNames(in: pluginDestinations)

        if installed.isEmpty {
            menu.addItem(
                withTitle: "Chưa cài gói nào", action: nil, keyEquivalent: ""
            ).isEnabled = false
        } else {
            for name in installed {
                let item = menu.addItem(
                    withTitle: "Gỡ «\(name)»", action: #selector(uninstallPlugin(_:)), keyEquivalent: ""
                )
                item.target = self
                item.representedObject = name
            }
        }
        menu.addItem(.separator())
        for (title, action) in [
            ("Cài gói…", #selector(installPlugin(_:))),
            ("Đóng gói script + theme hiện có…", #selector(exportPlugin(_:))),
        ] {
            menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self
        }
        present(menu, from: sender)
    }

    @objc private func installPlugin(_ sender: Any?) {
        let panel = NSOpenPanel()
        // `allowedContentTypes` chứ không phải `allowedFileTypes` (bỏ từ macOS 12) — và đuôi
        // `.geditorpkg` không có UTI đăng ký nên phải dựng một UTI tạm từ chính đuôi ấy.
        panel.allowedContentTypes = [
            UTType(filenameExtension: PluginPackage.fileExtension), .json,
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }

        do {
            let package = try PluginPackage.load(from: url)
            // Hỏi lại kèm NỘI DUNG gói. "Cài plugin?" một mình không cho người dùng cơ sở nào
            // để quyết định; "3 script, 1 theme, tác giả An" thì có.
            let alert = NSAlert()
            alert.messageText = "Cài «\(package.name)» v\(package.version)?"
            alert.informativeText = [package.summary, package.author.map { "Tác giả: \($0)" },
                                     package.subtitle]
                .compactMap { $0 }.joined(separator: "\n")
                + "\n\nScript trong gói chạy với quyền của GEditor. Chỉ cài gói bạn tin."
            alert.addButton(withTitle: "Cài")
            alert.addButton(withTitle: "Huỷ")
            guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }

            let installation = try package.install(into: pluginDestinations)
            // Nạp lại ngay: người dùng vừa cài một theme thì họ muốn thấy nó trong danh sách,
            // không phải khởi động lại app.
            userLanguages = MainWindowController.loadGrammars()
            showTransient("Đã cài «\(package.name)» — \(installation.files.count) file")
        } catch {
            presentError("Không cài được gói", error)
        }
    }

    @objc private func uninstallPlugin(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let removed = PluginPackage.uninstall(name: name, from: pluginDestinations)
        userLanguages = MainWindowController.loadGrammars()
        showTransient(
            removed.isEmpty ? "Gói «\(name)» đã không còn ở đó" : "Đã gỡ \(removed.count) file của «\(name)»"
        )
    }

    /// Gom script và theme người dùng ĐANG có thành một gói chia sẻ được.
    ///
    /// Chỉ lấy những thứ họ tự đặt, không lấy file của gói khác: đóng gói lại thứ mình vừa cài
    /// từ nơi khác là cách vô tình phát tán lại công của người ta dưới tên mình.
    @objc private func exportPlugin(_ sender: Any?) {
        guard let name = askForText(
            title: "Đóng gói mở rộng", message: "Tên gói", placeholder: "Gói của tôi"
        ), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        var package = PluginPackage(name: name, version: "1.0.0")
        for url in ScriptRunner.availableScripts()
        where !url.lastPathComponent.contains(".") || url.lastPathComponent.split(separator: ".").count == 2 {
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            package.scripts[url.deletingPathExtension().lastPathComponent] = source
        }
        package.themes = Theme.all(in: AppPaths.themesDirectory)
            .filter { theme in !Theme.builtIn.contains { $0.name == theme.name } }
        package.languages = userLanguages

        guard !package.isEmpty else {
            showBanner(
                "Chưa có script, theme hay ngôn ngữ tự định nghĩa nào của riêng bạn để đóng gói",
                actionTitle: nil, action: nil
            )
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(PluginPackage.slug(name)).\(PluginPackage.fileExtension)"
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        do {
            try package.save(to: url)
            showTransient("Đã đóng gói: \(package.subtitle)")
        } catch {
            presentError("Không ghi được gói", error)
        }
    }

    // MARK: - Services (FR-AUTO-606)

    /// Mở một đoạn văn bản đến từ ứng dụng khác thành tab mới.
    ///
    /// Thành tab CHƯA LƯU chứ không ghi ra file tạm: người dùng bôi đen một đoạn trong Safari
    /// thì họ chưa quyết định lưu nó ở đâu, và tạo sẵn một file trong `/tmp` là quyết định thay
    /// họ — rồi để lại rác không ai dọn.
    func openTextFromServices(_ text: String) {
        openTextInNewTab(text, label: "Từ Services")
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Script (FR-AUTO-603 · FR-PLUG-701)

    /// Menu những script trong `scripts/`, dựng lại mỗi lần bung.
    @objc func showScriptMenu(_ sender: Any?) {
        let menu = NSMenu(title: "Script")
        let scripts = ScriptRunner.availableScripts()
        if scripts.isEmpty {
            let item = menu.addItem(
                withTitle: "Chưa có script nào — tạo một ví dụ",
                action: #selector(createExampleScript(_:)), keyEquivalent: ""
            )
            item.target = self
        } else {
            for url in scripts {
                let item = menu.addItem(
                    withTitle: url.deletingPathExtension().lastPathComponent,
                    action: #selector(runScriptFromMenu(_:)), keyEquivalent: ""
                )
                item.target = self
                item.representedObject = url.path
                item.toolTip = url.path
            }
            menu.addItem(.separator())
            let reveal = menu.addItem(
                withTitle: "Mở thư mục script", action: #selector(revealScriptsFolder(_:)),
                keyEquivalent: ""
            )
            reveal.target = self
        }
        present(menu, from: sender)
    }

    @objc private func createExampleScript(_ sender: Any?) {
        let url = AppPaths.scriptsDirectory.appendingPathComponent("danh-so-dong.js")
        do {
            try FileManager.default.createDirectory(
                at: AppPaths.scriptsDirectory, withIntermediateDirectories: true
            )
            try ScriptRunner.example.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            presentError("Không tạo được script ví dụ", error)
        }
    }

    @objc private func revealScriptsFolder(_ sender: Any?) {
        try? FileManager.default.createDirectory(
            at: AppPaths.scriptsDirectory, withIntermediateDirectories: true
        )
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.scriptsDirectory])
    }

    @objc private func runScriptFromMenu(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String,
              let source = try? String(contentsOfFile: path, encoding: .utf8) else {
            showTransient("Không đọc được script")
            return
        }
        runScript(source: source, name: (path as NSString).lastPathComponent)
    }

    /// Chạy một script và áp kết quả.
    func runScript(source: String, name: String) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        let text = editorDocument.buffer.text
        let outcome = ScriptRunner.run(
            source: source, text: text, selection: editorView.selectedDocumentRange
        )

        scriptLogForSelfTest = outcome.log
        if let failure = outcome.failure {
            showBanner("Script «\(name)» lỗi: \(failure)", actionTitle: nil, action: nil)
            return
        }
        // Nhật ký hiện TRƯỚC khi áp sửa đổi: script báo "đã bỏ qua 3 dòng" thì người dùng cần
        // đọc câu ấy, và nếu phần áp sửa đổi làm màn hình nhảy đi thì họ mất nó.
        if !outcome.log.isEmpty {
            showTransient(outcome.log.prefix(3).joined(separator: " · "))
        }
        guard let replacement = outcome.replacement, replacement != text else {
            if outcome.log.isEmpty { showTransient("Script «\(name)» chạy xong, không đổi gì") }
            return
        }
        apply(
            [TextEdit(range: 0 ..< editorDocument.buffer.count, text: replacement)],
            label: "Script «\(name)»"
        )
    }

    // MARK: - Plugin native (FR-PLUG-702/704, ADR-12)

    /// Chạy một lệnh của plugin native và áp kết quả — MỘT bước hoàn tác, như mọi thao tác khác.
    ///
    /// Đi đúng đường mà script JavaScript đã đi (`runScript`), và cố ý giống nhau tới mức có thể:
    /// với người dùng thì "chạy một phép biến đổi văn bản" là một việc, không phải hai việc chỉ
    /// vì bên dưới một cái chạy trong tiến trình còn cái kia chạy ngoài.
    ///
    /// Khác một chỗ, và chỗ ấy phải nói ra: lỗi của plugin là **lời của plugin**, nên nó hiện
    /// kèm tên plugin. Trộn giọng GEditor với giọng mã của người khác làm người dùng đổ lỗi
    /// nhầm chỗ.
    func runNativePlugin(_ plugin: NativePluginRegistry.Installed, command: String, label: String) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        let text = editorDocument.buffer.text
        // Vùng chọn RỖNG là "không bôi đen gì", không phải "bôi đen một khoảng rỗng".
        //
        // Truyền thẳng `0..<0` xuống thì plugin biến đổi đúng khoảng rỗng ấy và trả về nguyên
        // văn bản cũ — người dùng bấm menu, không có gì xảy ra, không có lỗi nào. Đúng cùng
        // kiểu phân biệt mà giao thức đã cẩn thận ở chỗ khác ("không đổi gì" ≠ chuỗi rỗng).
        let selected = editorView.selectedDocumentRange
        let selection: Range<Int>? = selected.isEmpty ? nil : selected

        // Cổng chuỗi cung ứng (NFR-SEC-03) chạy TRƯỚC khi chạm tới mã của plugin.
        guard authorizeNativePlugin(plugin, label: label) else { return }

        do {
            let replacement = try NativePluginRegistry.shared
                .bridge(for: plugin.url)
                .run(command: command, text: text, selection: selection)
            guard let replacement, replacement != text else {
                return showTransient(L("Plugin chạy xong, không đổi gì"))
            }
            apply(
                [TextEdit(range: 0 ..< editorDocument.buffer.count, text: replacement)],
                label: label
            )
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showBanner("\(label): \(reason)", actionTitle: nil, action: nil)
        }
    }

    // MARK: - Bảng quản lý plugin native (FR-PLUG-704)

    /// Menu quản lý plugin native: chạy lệnh, cài, gỡ, và mở thư mục.
    ///
    /// Dựng theo cùng lối với `showPluginManager` (gói dữ liệu) và `showScriptMenu`, vì với
    /// người dùng thì cả ba là một loại việc. Khác một chỗ **cố ý**: mỗi mục kèm đường dẫn ở
    /// tooltip, và có mục mở thẳng thư mục. Đó là câu trả lời cho SEC-03 — *cài từ đâu, gỡ thế
    /// nào* — và nó phải nhìn thấy được chứ không nằm trong tài liệu.
    @objc func showNativePluginMenu(_ sender: Any?) {
        present(makeNativePluginMenu(), from: sender)
    }

    /// Dựng menu, KHÔNG bung nó ra.
    ///
    /// Tách hai việc vì `NSMenu.popUp` chạy một vòng theo dõi chuột — thứ không có ai bấm
    /// trong lượt chạy không người, và là đúng họ với `NSAlert.runModal()` đã treo bộ tự kiểm
    /// hai lần (xem `Unattended`). Bài kiểm soi menu ĐÃ DỰNG; không bài nào cần bung nó ra.
    func makeNativePluginMenu() -> NSMenu {
        let menu = NSMenu(title: "Plugin")
        let registry = NativePluginRegistry.shared

        guard registry.isSupported else {
            // Nói RÕ vì sao không có, đúng lối `geditor` CLI và lọc lệnh ngoài đã làm. Một mục
            // menu mờ đi không lý do là chỗ người dùng nghĩ app hỏng.
            menu.addItem(
                withTitle: L("Plugin native chỉ có ở bản tải trực tiếp, không có ở bản App Store."),
                action: nil, keyEquivalent: ""
            ).isEnabled = false
            return menu
        }

        let described = registry.describeAll()
        if described.isEmpty {
            menu.addItem(withTitle: L("Chưa cài plugin native nào"), action: nil, keyEquivalent: "")
                .isEnabled = false
        }
        for plugin in described {
            if let manifest = plugin.manifest {
                let header = menu.addItem(
                    withTitle: "\(manifest.name) \(manifest.version)", action: nil, keyEquivalent: "")
                header.isEnabled = false
                header.toolTip = plugin.installed.url.path
                // Lệnh sắp theo TÊN, không theo thứ tự từ điển trả về: thứ tự của một
                // `Dictionary` đổi giữa các lần chạy, và một menu tự xáo chỗ là menu không nhớ
                // được bằng tay.
                for (command, label) in manifest.commands.sorted(by: { $0.key < $1.key }) {
                    let item = menu.addItem(
                        withTitle: "    \(label)", action: #selector(runNativePluginFromMenu(_:)),
                        keyEquivalent: "")
                    item.target = self
                    item.representedObject = [plugin.installed.url.path, command, manifest.name]
                    item.toolTip = plugin.installed.url.path
                }
            } else {
                // Plugin hỏng vẫn hiện — biến mất vì lỗi là cách chắc chắn để người dùng không
                // hiểu chuyện gì và cũng không biết đường gỡ nó ra.
                let item = menu.addItem(
                    withTitle: "⚠️ \(plugin.installed.fileName)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.toolTip = plugin.failure
            }
            let remove = menu.addItem(
                withTitle: "    " + L("Gỡ plugin này"), action: #selector(removeNativePlugin(_:)),
                keyEquivalent: "")
            remove.target = self
            remove.representedObject = plugin.installed.url.path
            menu.addItem(.separator())
        }

        for (title, action) in [
            (L("Cài plugin native…"), #selector(installNativePlugin(_:))),
            (L("Mở thư mục plugin"), #selector(revealNativePluginFolder(_:))),
        ] {
            menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self
        }
        return menu
    }

    /// Hỏi người dùng trước khi chạy một plugin CHƯA DUYỆT; từ chối thẳng nếu nó ĐÃ ĐỔI.
    ///
    /// Hai phán quyết, hai cách xử lý khác hẳn nhau — và đó là chủ ý:
    ///
    /// - **Chưa duyệt** là một câu hỏi hợp lệ: người dùng vừa tự chép file ấy vào, họ biết nó
    ///   từ đâu ra. Hỏi một lần, ghi lại, không hỏi nữa. Hỏi mỗi lần chạy là cách chắc chắn
    ///   khiến họ bấm Đồng ý theo phản xạ, và khi ấy câu hỏi thôi bảo vệ.
    /// - **Đã đổi kể từ lần duyệt** KHÔNG phải một câu hỏi: người dùng không có cách nào trả
    ///   lời đúng, vì họ không biết vì sao file đổi. Từ chối và nói rõ hai hash để họ đi kiểm.
    private func authorizeNativePlugin(
        _ plugin: NativePluginRegistry.Installed, label: String
    ) -> Bool {
        let registry = NativePluginRegistry.shared
        let verdict: PluginTrust.Verdict
        do {
            verdict = try registry.verdict(for: plugin.url)
        } catch {
            showBanner("\(label): \(error.localizedDescription)", actionTitle: nil, action: nil)
            return false
        }

        switch verdict {
        case .trusted:
            return true

        case .changed:
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = L("Plugin đã đổi nội dung — GEditor từ chối chạy")
            alert.informativeText = PluginTrust.explanation(
                verdict, fileName: plugin.fileName)
            alert.addButton(withTitle: L("Đóng"))
            _ = Unattended.ask(alert)
            return false

        case .unknown:
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L("Chạy plugin chưa duyệt?")
            var detail = PluginTrust.explanation(verdict, fileName: plugin.fileName)
            // Chữ ký là dữ kiện DUY NHẤT nói được nguồn gốc, và người dùng không có cách nào
            // tự tra nó. "Chưa ký" phải hiện ra thành chữ, không phải thành một dòng vắng mặt.
            //
            // Dùng chuỗi ĐỊNH DẠNG chứ không nối mảnh: "\nChữ ký: " là một mảnh không dịch
            // nổi — bảng dịch không có khoá nào cho nửa câu, và người dịch không đoán được nó
            // đứng ở đâu.
            let signer = PluginTrust.signer(ofFileAt: plugin.url.path) ?? L("KHÔNG có chữ ký")
            detail += "\n" + LF("Chữ ký: %@", signer)
            detail += "\n" + LF("Đường dẫn: %@", plugin.url.path)
            alert.informativeText = detail
            alert.addButton(withTitle: L("Huỷ"))
            alert.addButton(withTitle: L("Tôi tin file này — chạy"))
            guard Unattended.ask(alert) == .alertSecondButtonReturn else { return false }
            do {
                try registry.approve(plugin.url)
            } catch {
                showBanner("\(label): \(error.localizedDescription)",
                           actionTitle: nil, action: nil)
                return false
            }
            return true
        }
    }

    @objc private func runNativePluginFromMenu(_ sender: NSMenuItem) {
        guard let parts = sender.representedObject as? [String], parts.count == 3 else { return }
        runNativePlugin(
            NativePluginRegistry.Installed(url: URL(fileURLWithPath: parts[0])),
            command: parts[1], label: parts[2])
    }

    @objc private func installNativePlugin(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "dylib")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.message = L("Chọn file .dylib của plugin native")
        guard Unattended.chooseFile(panel) == .OK, let source = panel.url else { return }
        do {
            let installed = try NativePluginRegistry.shared.install(from: source)
            showTransient(L("Đã cài:") + " \(installed.fileName)")
        } catch {
            presentError(error)
        }
    }

    @objc private func removeNativePlugin(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        let plugin = NativePluginRegistry.Installed(url: URL(fileURLWithPath: path))

        // HỎI trước khi xoá: gỡ là xoá file thật, không hoàn tác được. Câu hỏi đi qua
        // `Unattended.ask` nên lượt chạy không người không treo và cũng không tự bấm hộ.
        let alert = NSAlert()
        alert.messageText = L("Gỡ plugin này?")
        alert.informativeText = plugin.url.path
        alert.addButton(withTitle: L("Gỡ"))
        alert.addButton(withTitle: L("Huỷ"))
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }

        do {
            try NativePluginRegistry.shared.remove(plugin)
            showTransient(L("Đã gỡ:") + " \(plugin.fileName)")
        } catch {
            presentError(error)
        }
    }

    @objc private func revealNativePluginFolder(_ sender: Any?) {
        let directory = NativePluginRegistry.shared.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    // MARK: - Duyệt bản đã lưu (FR-DOC-305, hướng A của PoC-J)

    /// Menu các bản đã lưu trước đó của file đang mở.
    ///
    /// **Không phải giao diện lịch sử nguyên bản của macOS**, và chỗ này nói ra điều đó: giao
    /// diện ấy (`NSDocument.browseVersions`) chỉ có khi dùng `NSDocument`, mà chuyển sang
    /// `NSDocument` là 413 chỗ chạm tài liệu và 29 chỗ chỉ mục `tabs[]` — xung đột mô hình
    /// "một tài liệu một cửa sổ" với tab (PoC-J). Đây là kho phiên bản CỦA HỆ ĐIỀU HÀNH với
    /// bảng duyệt của GEditor.
    @objc func showDocumentVersions(_ sender: Any?) {
        present(makeDocumentVersionsMenu(), from: sender)
    }

    /// Dựng menu, KHÔNG bung ra — cùng lý do với menu plugin: `popUp` chạy vòng theo dõi chuột.
    func makeDocumentVersionsMenu() -> NSMenu {
        let menu = NSMenu(title: "versions")
        guard let path = editorDocument.path else {
            menu.addItem(
                withTitle: L("Tài liệu chưa lưu lần nào — chưa có lịch sử"),
                action: nil, keyEquivalent: ""
            ).isEnabled = false
            return menu
        }

        let versions = DocumentVersions.versions(of: path)
        if versions.isEmpty {
            menu.addItem(
                withTitle: L("Chưa có bản đã lưu nào trước đó"), action: nil, keyEquivalent: ""
            ).isEnabled = false
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        for (index, version) in versions.enumerated() {
            let when = version.date.map { formatter.string(from: $0) } ?? "?"
            let size = version.byteCount.map { " · \($0) byte" } ?? ""
            let item = menu.addItem(
                withTitle: "\(when)\(size)", action: #selector(restoreDocumentVersion(_:)),
                keyEquivalent: "")
            item.target = self
            item.representedObject = index
            item.toolTip = version.url.path
        }
        return menu
    }

    @objc private func restoreDocumentVersion(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int,
              let path = editorDocument.path else { return }
        let versions = DocumentVersions.versions(of: path)
        guard index < versions.count,
              let bytes = DocumentVersions.contents(of: versions[index]) else {
            return showTransient(L("Không đọc được bản ấy"))
        }
        guard !editorDocument.isReadOnly else { return NSSound.beep() }

        // Khôi phục là một SỬA ĐỔI BÌNH THƯỜNG trên buffer, không phải ghi đè file sau lưng.
        //
        // Hai điều được cùng lúc: người dùng ⌘Z về lại được nếu chọn nhầm bản, và file trên đĩa
        // chỉ đổi khi họ thật sự bấm lưu. Ghi thẳng ra đĩa thì "khôi phục" thành một thao tác
        // không hoàn tác được — trên chính thứ mà tính năng này sinh ra để cứu.
        apply(
            [TextEdit(range: 0 ..< editorDocument.buffer.count, bytes: bytes)],
            label: L("Khôi phục bản đã lưu")
        )
    }

    // MARK: - Xem trước Markdown (FR-FMT-506)

    @objc func showMarkdownPreview(_ sender: Any?) {
        let preview = markdownPreview ?? MarkdownPreview()
        markdownPreview = preview
        let text = editorDocument.buffer.text
        if let refusal = preview.present(markdown: text) {
            showTransient(refusal)
            return
        }
        preview.showWindow(nil)
        markdownPreviewDocumentID = editorDocument.id
        renderMarkdownMermaid(in: text, into: preview)
        refreshChrome()
    }

    /// Vẽ các khối ```mermaid rồi chèn vào cửa sổ xem trước Markdown — FR-MMD-003.
    ///
    /// Chèn SAU khi cửa sổ đã hiện, không chờ: phần văn bản đã dựng xong trong vài mili-giây,
    /// còn sơ đồ đầu tiên tốn khoảng một giây (dựng WKWebView + nạp mermaid). Chờ cả hai rồi
    /// mới hiện là bắt người đọc nhìn màn hình trắng cho một tài liệu đã sẵn sàng.
    private func renderMarkdownMermaid(in text: String, into preview: MarkdownPreview) {
        let blocks = MermaidDocument.blocks(in: text).filter { !$0.isEmpty }
        guard !blocks.isEmpty, MermaidAsset.isAvailable else { return }
        mermaidRenderer.render(
            blocks.map { MermaidRenderer.Diagram(index: $0.index, source: $0.source) }
        ) { [weak preview] results in
            guard let preview else { return }
            var images: [Int: NSImage] = [:]
            for result in results {
                // Sơ đồ hỏng thì GIỮ NGUYÊN khối mã trong bản xem trước: người dùng cần thấy
                // mã để sửa, và một ô trống không nói được gì.
                guard let svg = result.svg,
                      let image = NSImage(data: Data(svg.utf8)) else { continue }
                images[result.index] = image
            }
            preview.insert(diagrams: images)
        }
    }

    // MARK: - Thử biểu thức chính quy (FR-SRCH-110)

    @objc func showRegexTester(_ sender: Any?) {
        let panel = regexTesterPanel ?? RegexTesterPanel()
        regexTesterPanel = panel
        panel.showWindow(nil)
        // Điền sẵn bằng vùng chọn: đó đúng là đoạn người dùng vừa nhìn thấy và muốn khớp.
        panel.present(sample: editorView.selectedText)
    }

    // MARK: - Lọc qua lệnh ngoài (FR-AUTO-604)

    /// Đưa vùng chọn (hoặc cả tài liệu) qua một lệnh, thay bằng kết quả.
    @objc func runTextFilter(_ sender: Any?) {
        guard Distribution.current.supportsTextFilter else {
            // Nói THẲNG vì sao, không để mục menu im lặng không làm gì. Đây là khác biệt giữa
            // hai kênh phát hành, và người dùng bản App Store xứng đáng biết lý do.
            showBanner(
                "Bản App Store không chạy được lệnh ngoài — App Sandbox không cho tạo tiến trình con. "
                    + "Bản tải trực tiếp thì có.",
                actionTitle: nil, action: nil
            )
            return
        }
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        guard let command = askForText(
            title: "Lọc qua lệnh",
            message: "Vùng chọn (hoặc cả tài liệu) sẽ được đưa vào stdin, và thay bằng stdout.",
            placeholder: "sort -u"
        ), !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let selection = editorView.selectedDocumentRange
        let target = selection.isEmpty ? 0 ..< editorDocument.buffer.count : selection
        let input = String(decoding: editorDocument.buffer.bytes(in: target), as: UTF8.self)

        do {
            let output = try TextFilter.run(command: command, input: input)
            apply([TextEdit(range: target, text: output)], label: "Lọc qua «\(command)»")
            showTransient("Đã lọc \(target.count) byte qua «\(command)»")
        } catch {
            presentError("Lệnh không chạy được", error)
        }
    }

    // MARK: - Chế độ Log (FR-FMT-508)

    @objc func toggleLogMode(_ sender: Any?) {
        editorView.isLogMode.toggle()
        showTransient(
            editorView.isLogMode
                ? "Chế độ Log: tô theo mức nghiêm trọng"
                : "Đã tắt chế độ Log"
        )
    }

    /// Chỉ giữ những dòng từ một mức trở lên — ra TAB MỚI, không đụng tài liệu gốc.
    @objc func filterLogLevel(_ sender: Any?) {
        let menu = NSMenu(title: "Lọc theo mức")
        for level in LogFormat.Level.allCases.reversed() {
            let item = menu.addItem(
                withTitle: "\(level.displayName) trở lên",
                action: #selector(applyLogLevelFilter(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = level.rawValue
        }
        present(menu, from: sender)
    }

    @objc private func applyLogLevelFilter(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let minimum = LogFormat.Level(rawValue: raw) else { return }
        let buffer = editorDocument.buffer
        guard buffer.lineCount > 0 else { return }

        let levels = LogFormat.levels(in: buffer, lineRange: 0 ... (buffer.lineCount - 1))
        var kept: [String] = []
        // Dòng KHÔNG nhận ra mức đi THEO dòng có mức gần nhất phía trên: đó là dòng tiếp nối
        // của một stack trace, và cắt nó ra khỏi dòng lỗi sinh ra nó là bỏ đi phần hữu ích
        // nhất của cả khối.
        var keepingBlock = false
        for line in 0 ..< buffer.lineCount {
            if let level = levels[line] { keepingBlock = level >= minimum }
            guard keepingBlock else { continue }
            let content = buffer.contentRange(ofLine: line)
            kept.append(String(decoding: buffer.bytes(in: content), as: UTF8.self))
        }
        guard !kept.isEmpty else {
            showTransient("Không có dòng nào từ mức \(minimum.displayName) trở lên")
            return
        }
        openTextInNewTab(
            kept.joined(separator: "\n") + "\n", label: "Lọc log \(minimum.displayName)"
        )
        showTransient("\(kept.count) dòng từ mức \(minimum.displayName) trở lên, ra tab mới")
    }

    // MARK: - Cài đặt (FR-UI-803 · NFR-PORT-03)

    @objc func showPreferences(_ sender: Any?) {
        if preferencesPanel == nil {
            let panel = PreferencesPanel(
                settings: settings, themeNames: availableThemeNames()
            ) { [weak self] updated in
                self?.applySettings(updated, persist: true)
            }
            panel.onExportTheme = { [weak self] in
                guard let url = self?.exportCurrentTheme() else { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            preferencesPanel = panel
        }
        preferencesPanel?.showWindow(nil)
        preferencesPanel?.window?.center()
    }

    /// Áp chiều viết của ngôn ngữ đang dùng lên cửa sổ.
    ///
    /// Đặt MỘT lần ở `container` — `userInterfaceLayoutDirection` di truyền xuống cả cây, kể cả
    /// những panel chưa ra đời (mười bốn panel của GEditor dựng lười, xem `attach`).
    ///
    /// Rồi ép ngược vùng NỘI DUNG về trái-sang-phải. Chiều viết giao diện và chiều viết dữ liệu
    /// là hai chuyện: người Ai Cập đọc menu từ phải, nhưng tệp CSV họ đang mở, câu SQL họ đang
    /// gõ và đường dẫn `/Users/…` thì không đảo — đảo là hỏng nghĩa, không phải bản địa hoá.
    ///
    /// **Hỏi `…Attached` trước khi chạm.** `csvTable` và `sqlPanel` là `lazy var`, nên một phép
    /// ĐỌC ở đây cũng là một phép DỰNG — và hàm này chạy trong `applySettings`, tức ngay lúc
    /// khởi động. Chạm thẳng vào chúng là kéo bảng CSV và panel SQL vào đường khởi động của mọi
    /// phiên, kể cả phiên chỉ mở một tệp .txt. Đó đúng là thứ ADR-14 gỡ ra, và bài tự kiểm
    /// "tầng nào đã dựng" sẽ bắt được — nhưng chỉ khi người viết nhớ rằng nó có ở đó.
    func applyLayoutDirection() {
        LayoutDirection.apply(to: container)
        for pane in paneViews { LayoutDirection.forceLeftToRight(pane) }
        if csvTableAttached { LayoutDirection.forceLeftToRight(csvTable) }
        if isAttached(.sql) { LayoutDirection.forceLeftToRight(sqlPanel) }
        container.needsLayout = true
    }

    /// Đọc cấu hình lúc khởi động và áp lên cửa sổ.
    ///
    /// File hỏng hoặc do bản MỚI HƠN ghi thì KHÔNG ghi đè: nói ra rồi chạy bằng mặc định. Ghi
    /// đè là cách chắc chắn xoá mất cấu hình của người dùng đang đồng bộ hai máy — và họ sẽ
    /// không bao giờ biết vì sao.
    func loadSettings() {
        // FR-FMT-502: nạp ngôn ngữ tự định nghĩa cùng lúc với cấu hình — cả hai đều là dữ liệu
        // người dùng đặt trong Application Support, và cả hai chỉ đọc một lần lúc khởi động.
        userLanguages = MainWindowController.loadGrammars()
        do {
            applySettings(try Settings.load(from: AppPaths.settingsFile), persist: false)
        } catch let failure as Settings.Failure {
            settingsAreReadOnly = true
            if case .newerSchema(let found, let supported) = failure {
                showTransient(
                    "settings.json là của bản GEditor mới hơn (lược đồ \(found) > \(supported))"
                        + " — dùng mặc định và KHÔNG ghi đè"
                )
            }
        } catch {
            settingsAreReadOnly = true
            showTransient("Không đọc được settings.json — dùng mặc định và KHÔNG ghi đè")
        }
    }

    func applySettings(_ updated: Settings, persist: Bool) {
        settings = updated
        if !L10n.isLocked {
            L10n.language = L10n.Language(rawValue: updated.language) ?? .system
        }

        editorView.fontSize = CGFloat(updated.fontSize)
        editorView.tabWidth = updated.tabWidth
        editorView.ligatures = updated.ligatures
        trimsTrailingWhitespaceOnSave = updated.trimTrailingWhitespaceOnSave
        applyLayoutDirection()
        applyAppearance(updated.appearance)
        applyTheme(named: updated.themeName)
        applyKeyBindings(updated.keyBindings)
        refreshChrome()

        // Không ghi đè khi file thuộc về một bản mới hơn — xem `loadSettings`.
        guard persist, !settingsAreReadOnly else { return }
        do {
            try updated.save(to: AppPaths.settingsFile)
        } catch {
            showTransient(L("Không ghi được settings.json"))
        }
    }

    /// Ghi `settings` xuống đĩa mà KHÔNG áp lại gì.
    ///
    /// Khác `applySettings(_:persist:)`: hàm kia dựng lại theme, font, phím tắt và cả thanh
    /// công cụ. Đúng khi người dùng vừa đổi cấu hình trong hộp thoại, nhưng sai khi họ chỉ vừa
    /// thả chuột sau một cú kéo panel — lúc ấy mọi thứ khác đang đúng, và dựng lại chúng là
    /// một nháy hình không ai xin.
    ///
    /// Vẫn tôn trọng `settingsAreReadOnly`: file cấu hình thuộc về một bản GEditor mới hơn thì
    /// KHÔNG ghi đè, kể cả một khoá nhỏ như chiều cao panel.
    func saveSettings() {
        guard !settingsAreReadOnly else { return }
        do {
            try settings.save(to: AppPaths.settingsFile)
        } catch {
            showTransient(L("Không ghi được settings.json"))
        }
    }

    /// Đặt theme đang dùng (FR-UI-801).
    ///
    /// Theme không tìm thấy thì về mặc định VÀ nói ra: người dùng xoá một file theme rồi thấy
    /// màu đổi mà không hiểu vì sao là tệ hơn nhiều so với một dòng thông báo.
    func applyTheme(named name: String) {
        let available = Theme.all(in: AppPaths.themesDirectory)
        if let theme = available.first(where: { $0.name == name }) {
            Tokens.theme = theme
        } else {
            Tokens.theme = .cam
            if name != Theme.cam.name { showTransient("Không tìm thấy theme «\(name)» — dùng mặc định") }
        }
        // Màu đọc `Tokens.theme` ở thời điểm VẼ, nên chỉ cần bảo mọi thứ vẽ lại.
        window?.contentView?.setNeedsDisplay(window?.contentView?.bounds ?? .zero)
        editorView.refreshFromBuffer()
    }

    func applyKeyBindings(_ bindings: [String: String]) {
        let rejected = KeyBindings.apply(bindings, to: NSApp.mainMenu)
        guard !rejected.isEmpty else { return }
        showTransient("Phím tắt trùng, đã bỏ qua: \(rejected.joined(separator: ", "))")
    }

    /// Danh sách theme cho cửa sổ Cài đặt.
    func availableThemeNames() -> [String] {
        Theme.all(in: AppPaths.themesDirectory).map(\.name)
    }

    /// Ghi theme đang dùng ra `themes/` để người dùng sửa một màu rồi dùng tiếp.
    ///
    /// Đây là câu trả lời cho "làm sao tôi đổi được màu X": không phải một bộ chọn màu với hai
    /// mươi ô, mà là một file JSON năm dòng có sẵn giá trị hiện tại để sửa đè.
    @discardableResult
    func exportCurrentTheme() -> URL? {
        var copy = Tokens.theme
        copy.name = Tokens.theme.name + " (bản sửa)"
        let url = AppPaths.themesDirectory
            .appendingPathComponent(copy.name.replacingOccurrences(of: " ", with: "-") + ".json")
        do {
            try copy.save(to: url)
            return url
        } catch {
            showTransient("Không ghi được theme")
            return nil
        }
    }

    private func applyAppearance(_ name: String) {
        switch name {
        case "light": window?.appearance = NSAppearance(named: .aqua)
        case "dark": window?.appearance = NSAppearance(named: .darkAqua)
        default: window?.appearance = nil          // theo hệ thống
        }
    }

    // MARK: - Theo dõi file (FR-DOC-309)

    @objc func toggleFollowTail(_ sender: Any?) {
        if tailWatcher != nil { return stopFollowingTail(reason: "Đã ngừng theo dõi file") }
        guard let path = editorDocument.path else {
            showTransient("Chỉ theo dõi được file đã lưu trên đĩa")
            return
        }
        // Theo dõi là CHỈ ĐỌC. Vừa để người dùng gõ vừa nạp thêm phần mới từ đĩa là hai nguồn
        // sửa đổi tranh nhau một tài liệu, và bên thua là phần người dùng vừa gõ.
        editorDocument.markReadOnlyForFollowMode()
        // Lời gọi ngược mang theo một CON SỐ chỉ ra tab nào đặt nó.
        //
        // Không bắt giữ chỉ số tab: người dùng đóng một tab đứng trước là chỉ số dịch đi. Không
        // bắt giữ chính `watcher`: closure nằm bên trong nó, nên bắt nó là dựng một vòng giữ
        // nhau mà `--soak` sẽ đếm được. Không bắt giữ `Document`: mỗi lượt nạp lại sinh một đối
        // tượng mới, nên phép so danh tính chỉ đúng đúng một lần.
        tailToken += 1
        let token = tailToken
        tabs[activeIndex].tailToken = token
        let watcher = FileTailWatcher(path: path, queue: .main) { [weak self] change in
            self?.handleTailChange(change, token: token)
        }
        guard watcher.start() else {
            showTransient("Không mở được «\((path as NSString).lastPathComponent)» để theo dõi")
            return
        }
        tailWatcher = watcher
        scrollToDocumentEnd()
        showTransient("Đang theo dõi file — vùng soạn thảo chuyển sang chỉ đọc")
        refreshChrome()
    }

    var isFollowingTail: Bool { tailWatcher != nil }

    /// Đưa màn hình về cuối tài liệu — chỗ dòng log mới nhất vừa được ghi.
    private func scrollToDocumentEnd() {
        let end = max(editorDocument.buffer.count - 1, 0)
        editorView.setSelectedDocumentRange(end ..< end)
        editorView.reveal(documentOffset: end)
    }

    private func stopFollowingTail(reason: String) {
        tailWatcher?.stop()
        tailWatcher = nil
        tabs[activeIndex].tailToken = nil
        editorDocument.clearReadOnlyForFollowMode()
        showTransient(reason)
        refreshChrome()
    }

    /// Dừng bộ theo dõi của MỘT tab — dùng khi tab ấy đóng hoặc rời sang cửa sổ khác.
    ///
    /// Không gọi `clearReadOnlyForFollowMode`: tài liệu đi cùng tab, và tab đã không còn ở đây.
    private func stopFollowingTail(inTab index: Int) {
        guard tabs.indices.contains(index) else { return }
        tabs[index].tailWatcher?.stop()
        tabs[index].tailWatcher = nil
        tabs[index].tailToken = nil
    }

    /// Một thay đổi trên đĩa vừa tới — của TAB đã đặt bộ theo dõi, không phải của tab đang nhìn.
    ///
    /// Bản trước nhận đúng một tham số `change` rồi làm việc trên `editorDocument`, tức trên tài
    /// liệu ĐANG HIỆN. Người dùng bật theo dõi một file log ở tab 1, chuyển sang tab 2 gõ dở một
    /// đoạn, và dòng log kế tiếp nạp lại tab 2 từ đĩa rồi đặt nó thành chỉ đọc: phần vừa gõ mất,
    /// không có thông báo nào, và nguyên nhân thì nằm ở một tab họ không nhìn thấy.
    private func handleTailChange(_ change: FileTailWatcher.Change, token: Int) {
        guard let index = tabs.firstIndex(where: { $0.tailToken == token }) else { return }
        let isVisible = index == activeIndex
        switch change {
        case .appended, .replaced:
            // Nạp lại từ đĩa qua đúng đường mở file. Không vá phần đuôi vào buffer: tài liệu
            // đang chỉ đọc nên không có gì để giữ, và nạp lại thì mọi chỉ mục dòng, bảng mã
            // và phần tô màu đều đúng theo mà không phải tự đồng bộ từng thứ.
            guard let path = tabs[index].document.path,
                  let reloaded = try? Document.open(path: path) else { return }
            reloaded.markReadOnlyForFollowMode()
            if isVisible {
                loadDocument(reloaded)
                scrollToDocumentEnd()
            } else {
                // Tab đang bị che: đổi tài liệu của NÓ và không đụng gì tới khung soạn thảo.
                // Con nháy đặt ở cuối để lần người dùng quay lại là thấy dòng mới nhất — đúng
                // thứ `scrollToDocumentEnd` làm cho tab đang hiện.
                tabs[index].document = reloaded
                tabs[index].caretOffset = max(reloaded.buffer.count - 1, 0)
                refreshTabBar()
            }
        case .vanished:
            // Thoáng qua là chuyện thường: xoay vòng log và ghi nguyên tử đều có khoảnh khắc
            // đường dẫn trống. Nói ra nhưng KHÔNG dừng theo dõi.
            //
            // Tab đang bị che thì kèm TÊN FILE: một dải băng nói "file không còn ở đường dẫn cũ"
            // trong lúc người dùng đang nhìn một file khác chỉ làm họ đi kiểm nhầm chỗ.
            //
            // Tên tệp ghép ở tầng mã chứ không đẻ thêm một khoá dịch thứ hai gần giống khoá cũ:
            // hai chuỗi chỉ khác nhau một tiền tố là hai chuỗi người dịch phải đọc kỹ mới thấy
            // khác, và nợ dịch thì phình thêm một dòng cho mỗi thứ tiếng.
            let text = L("File tạm thời không có ở đường dẫn cũ — vẫn đang chờ")
            if isVisible {
                showTransient(text)
            } else {
                let name = tabs[index].document.path.map { ($0 as NSString).lastPathComponent }
                    ?? L("Chưa đặt tên")
                showTransient("«\(name)» · \(text)")
            }
        }
    }

    // MARK: - In ấn (FR-DOC-313)

    @objc func printDocument(_ sender: Any?) {
        let info = NSPrintInfo.shared
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36

        // In từ một `NSTextView` DỰNG RIÊNG, không in `editorView`: view trên màn hình chỉ giữ
        // CỬA SỔ 2 MB của tài liệu (ADR-01), nên in nó ra sẽ được đúng phần đang xem và người
        // dùng tưởng đã in cả file.
        let printable = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
        printable.string = printableText()
        printable.font = Tokens.Font.editor(size: 10)
        printable.isEditable = false

        let operation = NSPrintOperation(view: printable, printInfo: info)
        operation.jobTitle = editorDocument.path.map { ($0 as NSString).lastPathComponent }
            ?? "Chưa đặt tên"
        operation.printPanel.options.insert([.showsPaperSize, .showsOrientation])
        operation.run()
    }

    /// Trần cỡ tài liệu còn in được.
    ///
    /// In đòi dựng CẢ tài liệu thành `NSTextView` — đúng thứ cả kiến trúc này sinh ra để tránh.
    /// Với 20 MB thì đó đã là hàng nghìn trang giấy; nói thẳng là quá lớn thì trung thực hơn
    /// nhiều so với treo app vài phút rồi đổ ra một chồng giấy không ai muốn.
    static let printSizeLimit = 20 << 20

    private func printableText() -> String {
        guard editorDocument.buffer.count <= Self.printSizeLimit else {
            let megabytes = Double(editorDocument.buffer.count) / 1_048_576
            showTransient(String(format: "Tài liệu %.0f MB quá lớn để in", megabytes))
            return ""
        }
        return editorDocument.buffer.text
    }

    // MARK: - Thu phóng (FR-CORE-016)

    @objc func increaseFontSize(_ sender: Any?) { stepFontSize(by: 1) }
    @objc func decreaseFontSize(_ sender: Any?) { stepFontSize(by: -1) }

    @objc func resetFontSize(_ sender: Any?) {
        editorView.fontSize = WindowedTextView.defaultFontSize
        showTransient("Cỡ chữ \(Int(editorView.fontSize)) pt")
    }

    private func stepFontSize(by delta: CGFloat) {
        let before = editorView.fontSize
        editorView.fontSize = before + delta
        if editorView.fontSize == before {
            // Đã chạm trần hoặc sàn. Nói ra, vì bấm một phím tắt mà không có gì đổi thì trông
            // giống hệt phím tắt hỏng.
            showTransient("Cỡ chữ đã ở mức \(delta > 0 ? "lớn" : "nhỏ") nhất (\(Int(before)) pt)")
        } else {
            showTransient("Cỡ chữ \(Int(editorView.fontSize)) pt")
        }
    }

    // MARK: - Bảng tính nhiều sheet

    /// Chuyển sang một sheet khác của `.xlsx` đang mở.
    ///
    /// **Thay nội dung tab hiện tại, không mở tab thứ hai.** Hai tab cùng trỏ vào một tệp là hai
    /// chỗ cùng theo dõi một dấu vân tay và cùng có quyền ghi — và khi tệp đổi trên đĩa thì hai
    /// tab hỏi người dùng hai lần cùng một câu.
    ///
    /// **Có sửa chưa lưu thì HỎI.** Đổi sheet là thay toàn bộ nội dung buffer; làm im lặng nghĩa
    /// là nuốt mất phần người dùng vừa gõ, và `⌘Z` không lấy lại được vì cả tài liệu đã bị tráo.
    @objc func showSheetPicker(_ sender: Any?) {
        guard editorDocument.mediaKind == .excel, let path = editorDocument.path else {
            showTransient(L("Lệnh này chỉ dùng cho bảng tính Excel"))
            return
        }
        guard let reader = try? XLSXReader(path: path), !reader.sheets.isEmpty else {
            showTransient(L("Không đọc được danh sách sheet"))
            return
        }
        guard reader.sheets.count > 1 else {
            showTransient(LF("Bảng tính này chỉ có một sheet: «%@»", reader.sheets[0].name))
            return
        }

        if editorDocument.isModified {
            let warn = NSAlert()
            warn.messageText = L("Bỏ phần chưa lưu của sheet này?")
            warn.informativeText = L(
                "Đổi sheet sẽ thay toàn bộ nội dung tab. Phần vừa sửa mà chưa ⌘S sẽ mất."
            )
            warn.alertStyle = .warning
            warn.addButton(withTitle: L("Bỏ và đổi sheet"))
            warn.addButton(withTitle: L("Huỷ"))
            guard Unattended.ask(warn) == .alertFirstButtonReturn else { return }
        }

        let alert = NSAlert()
        alert.messageText = L("Chọn sheet")
        alert.informativeText = LF("Bảng tính có %d sheet.", reader.sheets.count)
        alert.addButton(withTitle: L("Mở sheet"))
        alert.addButton(withTitle: L("Huỷ"))
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26))
        for sheet in reader.sheets { popup.addItem(withTitle: sheet.name) }
        if let current = editorDocument.spreadsheetSheet { popup.selectItem(withTitle: current) }
        alert.accessoryView = popup
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        openSheet(named: popup.titleOfSelectedItem ?? "", at: path, reader: reader)
    }

    /// Nạp một sheet vào tab hiện tại.
    func openSheet(named name: String, at path: String, reader: XLSXReader) {
        guard let sheet = reader.sheets.first(where: { $0.name == name }) else {
            showTransient(LF("Không có sheet «%@»", name))
            return
        }
        do {
            let grid = try reader.grid(of: sheet)
            let document = Document.forSpreadsheet(
                path: path, csv: XLSXReader.csv(from: grid), sheet: sheet.name
            )
            loadDocument(document)
            showTransient(LF("Sheet «%@» · %d hàng", sheet.name, grid.rows.count))
        } catch {
            presentError(LF("Không đọc được sheet «%@»", name), error)
        }
    }

    // MARK: - Cây cấu trúc (chế độ View của JSON · XML · YAML)

    /// Cây nằm ĐÈ lên vùng soạn thảo, không nằm cạnh — cùng luật với bảng CSV: hai cách xem của
    /// cùng một tài liệu thì chỉ một cái được hiện.
    private func attachStructureTree() {
        guard !structureTreeAttached else { return }
        structureTreeAttached = true
        structureTree.translatesAutoresizingMaskIntoConstraints = false
        structureTree.onStatus = { [weak self] in self?.showTransient($0) }
        // Bấm một nút là con nháy nhảy về đúng byte ấy — và về luôn chế độ Code, vì thứ người
        // dùng muốn tiếp theo gần như luôn là SỬA chỗ vừa bấm.
        structureTree.onSelectRange = { [weak self] range in
            guard let self else { return }
            self.hideStructureTree()
            self.revealOffset(range.lowerBound)
        }
        // Esc là đường lui: quay về Code mà KHÔNG dời con nháy. Nó khác hẳn Enter — một bên là
        // "đi tới chỗ vừa tìm ra", một bên là "tôi xem xong rồi, trả tôi về chỗ cũ".
        structureTree.onDismiss = { [weak self] in self?.hideStructureTree() }
        middleRow.addSubview(structureTree)
        NSLayoutConstraint.activate([
            structureTree.topAnchor.constraint(equalTo: splitView.topAnchor),
            structureTree.leadingAnchor.constraint(equalTo: splitView.leadingAnchor),
            structureTree.trailingAnchor.constraint(equalTo: splitView.trailingAnchor),
            structureTree.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
        ])
    }

    // MARK: - Xem tài liệu Office (Word · Excel · PowerPoint)

    private func attachOfficePreview() {
        guard !officePreviewAttached else { return }
        officePreviewAttached = true
        officePreview.translatesAutoresizingMaskIntoConstraints = false
        officePreview.onSaveAndReload = { [weak self] in
            guard let self else { return }
            self.saveDocument(nil)
            self.showOfficePreview()
        }
        officePreview.onPageChanged = { [weak self] page, total in
            // Chỉ đổi CHỮ trên nhãn, không gọi `refreshDocumentToolbar`: dựng lại cả hàng nút ở
            // mỗi nhịp cuộn là cách chắc chắn làm giật đúng thứ vừa được sửa cho mượt.
            self?.pageIndicator.stringValue = LF("Trang %d/%d", page, total)
        }
        middleRow.addSubview(officePreview)
        NSLayoutConstraint.activate([
            officePreview.topAnchor.constraint(equalTo: splitView.topAnchor),
            officePreview.leadingAnchor.constraint(equalTo: splitView.leadingAnchor),
            officePreview.trailingAnchor.constraint(equalTo: splitView.trailingAnchor),
            officePreview.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
        ])
    }

    /// Tắt mọi khung View đang che vùng soạn thảo.
    ///
    /// Gọi khi ĐỔI tài liệu. Không gọi ở `refreshChrome`: hàm ấy chạy cả sau khi vừa MỞ một
    /// khung View, nên dọn ở đó là tắt đúng thứ người dùng vừa bật.
    func hideAllViewModes() {
        if isStructureTreeVisible { hideStructureTree() }
        if isDiagramTabVisible { hideDiagramTab() }
        if isOfficePreviewVisible { hideOfficePreview() }
        if isTableViewVisible { showTextViewPublic() }
    }

    /// Đóng mọi panel đang trưng KẾT QUẢ TÍNH TỪ MỘT TÀI LIỆU cụ thể.
    ///
    /// Gọi khi tài liệu đang hiện đổi sang tài liệu khác — cùng lý do và cùng chỗ với
    /// `hideAllViewModes`, chỉ khác là những thứ này nằm ở cột panel chứ không che vùng soạn
    /// thảo. Bỏ quên thì bảng «Kiểm tra dữ liệu: 2 lỗi ở cột y» nằm nguyên đó trong lúc người
    /// dùng đang mở một tệp `.txt` không có cột nào, và những ô tô đỏ trên bảng CSV được đánh
    /// theo SỐ HÀNG của tài liệu cũ.
    ///
    /// **Ba panel cố ý KHÔNG nằm trong danh sách này**, vì chúng không mô tả tài liệu đang mở:
    /// kết quả Tìm trong nhiều file (`results` — nói về một THƯ MỤC, và đóng nó là phá đúng
    /// luồng «bấm kết quả → xem → quay lại danh sách»), panel Tìm, và Mermaid Studio (nó tự
    /// theo tài liệu ở `refreshMermaidPreview`).
    private func hideDocumentPanels() {
        hideValidationPanel()
        hideCleanPanel()
        hideQualityPanel()
        hideChartPanel()
        hideAnomalyPanel()
        hideCorrelationPanel()
        hideForecastPanel()
        hideGroupMiningPanel()
        hideAssociationPanel()
        hideJSONPathPanel()
        hideJSONLPanel()
        hideRetrievalPanel()
        hideSQLPanel()
    }

    var isOfficePreviewVisible: Bool { officePreviewAttached && !officePreview.isHidden }

    func showOfficePreview() {
        guard let path = editorDocument.path else {
            return showTransient(L("Lưu tệp trước khi xem trang."))
        }
        attachOfficePreview()
        if csvTableAttached { csvTable.isHidden = true }
        if structureTreeAttached { structureTree.isHidden = true }
        // Buffer đã sửa mà chưa lưu thì trang bên này là bản CŨ — nói ra ngay trên khung.
        guard officePreview.present(
            path: path, kind: editorDocument.mediaKind, isStale: editorDocument.isModified)
        else {
            // Không dựng nổi trang thì Ở LẠI chế độ Code. Hiện một khung trống rồi để người dùng
            // tự đoán là cách chắc chắn nhất khiến họ nghĩ tệp của mình hỏng.
            return showTransient(L("Không dựng được trang của tệp này — dùng chế độ Code."))
        }
        officePreview.isHidden = false
        splitView.isHidden = true
        // Mỗi lần mở lại là về VỪA BỀ NGANG. Nhớ phép phóng của tệp trước rồi áp cho tệp sau là
        // nhớ nhầm chỗ: hai tệp có thể khác khổ giấy, và người dùng mở một tài liệu mới thì
        // trông đợi nó vừa khung, không trông đợi con số họ đặt cho một tài liệu khác.
        officePreview.pages.zoom = .fitWidth
        // Bàn phím về khung trang: Page Up/Down, mũi tên, ⌘A và ⌘C đều phải chạm tới TRANG chứ
        // không chạm vào vùng soạn thảo đang bị che.
        window?.makeFirstResponder(officePreview.pages)
        // Đồng bộ CẢ khung công tắc lẫn thanh trạng thái NGAY: một cái nhãn nói "Code" trong
        // khi màn hình đang hiện trang thì tệ hơn không có nhãn — và nó đã nói sai thật, ở góc
        // phải dưới. Đường gọi từ `--capture` và từ bộ quét không đi qua `toggleViewCode`, nên
        // không thể trông chờ chỗ ấy làm hộ.
        refreshChrome()
    }

    func hideOfficePreview() {
        guard officePreviewAttached else { return }
        officePreview.isHidden = true
        splitView.isHidden = false
        refreshChrome()
        window?.makeFirstResponder(editorView.textView)
    }

    var isStructureTreeVisible: Bool { structureTreeAttached && !structureTree.isHidden }

    private func hideStructureTree() {
        guard structureTreeAttached else { return }
        structureTree.isHidden = true
        splitView.isHidden = false
        // Trả bàn phím về vùng soạn thảo, đúng như bảng CSV làm khi nó nhường chỗ.
        window?.makeFirstResponder(editorView.textView)
    }

    /// Bật cây cho tài liệu đang mở.
    ///
    /// Dựng lại cây ở MỖI lần bật chứ không nhớ bản cũ: văn bản có thể vừa được sửa, và một cây
    /// cũ trông y hệt cây mới — người dùng bấm vào một nút không còn tồn tại.
    ///
    /// **Cây mở ra ở chỗ con nháy đang đứng.** Bấm một nút thì nhảy về nguồn; chiều này là chiều
    /// còn lại của cùng một lời hứa — sang View từ giữa một tệp lớn mà cây bắt đầu từ dòng đầu
    /// thì người dùng phải đi tìm lại chỗ mình vừa rời khỏi, và chỗ ấy chính là thứ họ mở View để
    /// nhìn cho ra bối cảnh.
    private func showStructureTree() {
        attachStructureTree()
        if csvTableAttached { csvTable.isHidden = true }
        structureTree.show(structureTreeForCurrentDocument())
        structureTree.reveal(offset: editorView.selectedDocumentRange.lowerBound)
        structureTree.isHidden = false
        splitView.isHidden = true
        structureTree.takeFocus()
    }

    /// Chọn bộ dựng cây theo NGÔN NGỮ đang tô màu, không theo đuôi tệp.
    ///
    /// Đuôi tệp và ngôn ngữ có thể lệch nhau — một tệp `.txt` vẫn được đặt tay sang XML, và một
    /// tệp `.xhtml` không nằm trong bảng đuôi nào. Ngôn ngữ là thứ người dùng nhìn thấy trên
    /// thanh trạng thái, nên cây phải bám vào đúng thứ ấy.
    private func structureTreeForCurrentDocument() -> StructureTree {
        let text = editorDocument.buffer.text
        if editorDocument.mediaKind == .powerpoint {
            return StructureTree.powerPoint(markdown: text)
        }
        switch editorView.syntaxLanguage {
        case .xml, .html: return StructureTree.xml(text: text)
        case .yaml: return StructureTree.yaml(text: text)
        default: return StructureTree.json(text: text)
        }
    }

    // MARK: - View / Code — một lệnh cho mọi loại tệp

    /// Đổi giữa hai chế độ hiển thị của tệp đang mở.
    ///
    /// **Một phím cho tất cả.** Trước lệnh này, sản phẩm có sáu cặp "xem / sửa" với sáu cái tên
    /// và sáu phím khác nhau — bảng CSV, xem trước Markdown, xem nhị phân, sơ đồ Mermaid, xem
    /// trước báo cáo, chế độ log. Cùng một ý niệm, sáu lối vào, và người dùng phải học lại ở mỗi
    /// loại tệp. Sáu lệnh cũ vẫn còn nguyên cho ai đã quen; lệnh này là lối vào chung.
    ///
    /// **Loại nào chưa có View thì NÓI RA, kèm tên thứ còn thiếu.** Mở một khung trống là một
    /// lời hứa suông; một câu từ chối có tên gọi là thông tin — người dùng biết chờ cái gì.
    @objc func toggleViewCode(_ sender: Any?) {
        let modes = DisplayModes.of(
            path: editorDocument.path ?? "",
            kind: editorDocument.mediaKind,
            language: editorView.syntaxLanguage
        )
        guard modes.canToggle else {
            showTransient(reasonCannotToggle(modes.view))
            return
        }
        // Word · Excel · PowerPoint: View là TRANG TÀI LIỆU dựng ra, không phải bản rút gọn.
        //
        // Trước đây View của chúng là Markdown / bảng CSV / dàn ý — đúng nội dung nhưng mất bố
        // cục, mất phông, mất hình. Người dùng nói thẳng là phải xem được như một trình đọc
        // Office. Ba đường cũ KHÔNG mất: chúng nằm ở vùng hành động của khung chung («Bảng»,
        // «Dàn ý»), vì chúng là thứ SỬA ĐƯỢC còn trang dựng ra thì chỉ đọc.
        // Excel là ngoại lệ có chủ ý: View của nó là **bảng tính sửa được**, không phải một
        // ảnh chụp trang. Một bảng tính không có "khổ giấy" cho tới lúc in, và cái người ta mở
        // `.xlsx` để làm là ĐỌC SỐ THEO Ô — thứ mà lưới ô làm tốt hơn mọi bản dựng trang, và nó
        // vốn đã chiếm hết bề ngang cửa sổ.
        if editorDocument.mediaKind == .word || editorDocument.mediaKind == .powerpoint {
            if isOfficePreviewVisible { hideOfficePreview() } else { showOfficePreview() }
            refreshChrome()
            return
        }

        switch modes.view {
        case .table:
            toggleTableView(sender)
        case .document, .image, .player, .archiveList:
            // Bốn loại này dùng chung khung media, và Code của chúng là byte.
            toggleBinaryView(sender)
        case .renderedText:
            showMarkdownPreview(sender)
        case .report:
            toggleReportPreview(sender)
        case .logLevels:
            toggleLogMode(sender)
        case .tree, .outline:
            // Dàn ý PowerPoint dùng CHUNG khung cây: nó cũng là "nút có con, bấm thì nhảy về
            // nguồn". Dựng một khung riêng cho nó là chép lại lần thứ tư cùng một `NSOutlineView`.
            if isStructureTreeVisible { hideStructureTree() } else { showStructureTree() }
        case .diagram:
            if isDiagramTabVisible { hideDiagramTab() } else { showDiagramTab() }
        case .none:
            // `canToggle` đã chặn ở trên; nhánh này chỉ để `switch` đủ vế.
            showTransient(reasonCannotToggle(modes.view))
        }
        // Nhãn trên thanh trạng thái phải đổi theo NGAY. Nó là chỗ duy nhất người dùng nhìn
        // thấy mình đang ở chế độ nào — mà một chỉ dẫn chậm một nhịp thì đúng lúc cần nhất nó
        // lại nói sai.
        refreshChrome()
    }

    /// Vì sao loại này chưa đổi chế độ được — nói tên thứ còn thiếu, không nói chung chung.
    /// Vì sao loại tệp này chưa đổi chế độ được.
    ///
    /// Ba nhánh đầu HÔM NAY không chạy tới: mọi loại tệp có chỗ cho một chế độ View đều đã dựng
    /// xong, nên `canToggle` không còn chặn ai vì lý do "chưa dựng". Giữ chúng lại là giữ hợp
    /// đồng cho chế độ View tiếp theo — ai thêm một loại tệp mới với `viewImplemented: false`
    /// thì đã có sẵn câu nói ra tên thứ còn thiếu, thay vì rơi vào câu chung chung ở cuối.
    private func reasonCannotToggle(_ view: DisplayView) -> String {
        switch view {
        case .tree: return L("Chưa có chế độ View dạng cây cho JSON · XML · YAML")
        case .diagram: return L("Chưa có chế độ View dạng sơ đồ trong tab")
        case .outline: return L("Chưa có chế độ View dạng dàn ý cho PowerPoint")
        default: return L("Tệp này chỉ có một chế độ hiển thị")
        }
    }

    // MARK: - Xem nhị phân

    /// Bật/tắt chế độ xem nhị phân cho tab đang mở.
    ///
    /// Chạy được với **mọi** tệp có đường dẫn, không riêng media: một trình soạn thảo hạng
    /// Notepad++ phải mở được thứ người dùng kéo vào, kể cả khi phần văn bản của nó vô nghĩa.
    ///
    /// Tài liệu CHƯA LƯU thì không có gì trên đĩa để mà đọc — nói ra thay vì hiện một bảng rỗng.
    @objc func toggleBinaryView(_ sender: Any?) {
        guard let path = editorDocument.path else {
            showTransient(L("Tài liệu chưa lưu — không có tệp trên đĩa để xem nhị phân"))
            return
        }
        // Đã ở trong khung media thì chỉ việc lật chế độ — khung ấy tự lo phần dừng nhạc.
        if mediaViewerAttached, !mediaViewer.isHidden {
            // `false` nghĩa là tệp văn bản đang xem nhị phân: trả lại vùng soạn thảo.
            if !mediaViewer.toggleBinaryMode() { closeBinaryViewForTextDocument() }
            return
        }
        // Tệp văn bản: mượn chính khung media làm chỗ chứa, và truyền `kind: nil` để nó biết
        // đây là đường một chiều — đường về là bấm lại lệnh này.
        if csvTableAttached { csvTable.isHidden = true }
        attachMediaViewer()
        mediaViewer.isHidden = false
        splitView.isHidden = true
        mediaViewer.show(path: path, kind: nil)
    }

    /// Đóng chế độ nhị phân của một tệp VĂN BẢN và trả lại vùng soạn thảo.
    private func closeBinaryViewForTextDocument() {
        mediaViewer.isHidden = true
        mediaViewer.clear()
        splitView.isHidden = false
    }

    // MARK: - Trợ giúp (NFR-USE-04)

    @objc func showHelpPage(_ sender: Any?) {
        HelpWindowController.show(settings: self)
    }

    @objc func showMigrationPage(_ sender: Any?) {
        HelpWindowController.show(topicID: "di-cu-notepadpp", settings: self)
    }

    /// Mở lại trang chào — cùng cửa sổ, chỉ khác là có chân trang với ô tích.
    ///
    /// Có mục menu này vì ô tích kia là đường một chiều nếu không có nó: tắt rồi thì không còn
    /// cách nào bật lại ngoài việc sửa tay `settings.json`, và người vừa tắt nhầm không biết
    /// tệp ấy tồn tại.
    @objc func showWelcomeTour(_ sender: Any?) {
        HelpWindowController.show(
            topicID: HelpContent.entryTopicID, welcome: true, settings: self
        )
    }

    // MARK: - Tab đi giữa các cửa sổ (FR-DOC-302)

    /// Gỡ một tab RA KHỎI cửa sổ này và trả nó về cho chỗ gọi.
    ///
    /// Trả `nil` khi không gỡ được. Có đúng một lý do từ chối, và nó quan trọng: **tab đang ghim
    /// thì không đi đâu cả.** Ghim nghĩa là "giữ tab này ở đây", nên để một cú kéo vô tình mang
    /// nó sang cửa sổ khác là làm hỏng chính lời hứa của việc ghim.
    ///
    /// Gỡ tab CUỐI CÙNG thì cửa sổ này còn lại một tab chưa đặt tên, không tự đóng. Tự đóng thì
    /// mất luôn cây thư mục workspace và cách chia đôi màn hình người dùng vừa dựng — và họ chỉ
    /// định dời một tab.
    func detachTab(at index: Int) -> EditorTab? {
        guard tabs.indices.contains(index), !tabs[index].isPinned else { return nil }

        // Cất trạng thái xem TRƯỚC khi gỡ: vị trí con nháy của tab đang mở chỉ nằm ở khung soạn
        // thảo, và gỡ xong mới hỏi thì nó đã trỏ sang tab khác.
        saveActiveTabState()
        var tab = tabs[index]
        if index == activeIndex { tab.caretOffset = editorView.selectedDocumentRange.lowerBound }

        if let path = tab.document.path { cliBridge?.documentClosed(path: path) }
        // Bộ theo dõi KHÔNG đi theo tab sang cửa sổ mới: lời gọi ngược của nó trỏ về controller
        // này, nên ở cửa sổ kia nó sẽ im lặng không làm gì — một tính năng chết mà vẫn trông
        // như đang bật. Dừng hẳn, và tab mang theo tài liệu ở trạng thái chỉ đọc thì người dùng
        // bấm lại ⌥⌘F ở cửa sổ mới.
        stopFollowingTail(inTab: index)
        tab.tailWatcher = nil
        tab.tailToken = nil
        tabs.remove(at: index)
        if tabs.isEmpty { tabs = [EditorTab(document: .untitled())] }
        activeIndex = min(activeIndex, tabs.count - 1)
        clampPaneIndices()
        applyActiveTab()
        refreshTabBar()
        refreshChrome()
        return tab
    }

    /// Nhận một tab từ cửa sổ khác và mở nó ra.
    ///
    /// Đặt nó thành tab ĐANG MỞ: người dùng vừa kéo nó sang đây, nên thứ họ muốn nhìn thấy
    /// chính là nó — chứ không phải tab cũ của cửa sổ này vẫn đứng nguyên.
    func adoptTab(_ tab: EditorTab) {
        saveActiveTabState()

        // Cửa sổ chỉ có một tab CHƯA ĐẶT TÊN và chưa ai đụng vào thì THAY nó, đừng để lại một
        // tab rỗng — cùng luật với `openInNewTab`.
        if tabs.count == 1, tabs[0].document.path == nil, !tabs[0].document.isModified {
            tabs[0] = tab
            activeIndex = 0
        } else {
            tabs.append(tab)
            activeIndex = tabs.count - 1
        }
        applyActiveTab()
        refreshTabBar()
        refreshChrome()
        window?.makeKeyAndOrderFront(nil)
    }

    /// ⌃⌘N — tách tab đang mở ra một cửa sổ mới.
    ///
    /// Có lệnh bàn phím chứ không chỉ có cú kéo: một tính năng chỉ dùng được bằng chuột là một
    /// tính năng người dùng VoiceOver và người dùng bàn phím không có (NFR-USE-03).
    @objc func moveTabToNewWindow(_ sender: Any?) {
        moveTab(at: activeIndex, to: nil)
    }

    /// Dời tab sang `target`; `nil` nghĩa là sang một cửa sổ MỚI.
    func moveTab(at index: Int, to target: MainWindowController?) {
        guard tabs.indices.contains(index) else { return }
        guard !tabs[index].isPinned else {
            showTransient("Tab đang ghim — bỏ ghim trước rồi mới dời sang cửa sổ khác")
            return
        }
        // Cửa sổ chỉ có MỘT tab thì dời nó đi là để lại một cửa sổ trống. Nói ra thay vì làm.
        guard tabs.count > 1 || target != nil else {
            showTransient("Cửa sổ chỉ có một tab — không tách ra được")
            return
        }
        guard let tab = detachTab(at: index) else { return }
        let destination = target ?? WindowManager.shared.newWindow()
        destination.adoptTab(tab)
        WindowManager.shared.saveSession()
    }

    @objc func nextTab(_ sender: Any?) { activateTab((activeIndex + 1) % tabs.count) }
    @objc func previousTab(_ sender: Any?) { activateTab((activeIndex - 1 + tabs.count) % tabs.count) }

    /// Cất trạng thái xem của tab đang mở trước khi rời nó.
    private func saveActiveTabState() {
        tabs[activeIndex].caretOffset = editorView.selectedDocumentRange.lowerBound
    }

    /// Nối toàn bộ callback cho MỘT pane.
    ///
    /// Không viết thẳng cho `editorView`: `editorView` chỉ là pane đang hoạt động, nên viết
    /// thẳng nghĩa là pane thứ hai im lặng không có gì cả — gõ được nhưng không lưu, không cập
    /// nhật thanh trạng thái, không đồng bộ sang pane kia.
    private func configure(_ pane: WindowedTextView) {
        pane.onEdit = { [weak self, weak pane] range, replacement in
            guard let self, let pane else { return false }
            // Sửa ở pane NÀO thì tính trên tài liệu của pane ấy, không phải của pane đang
            // hoạt động — gõ vào pane chưa focus vẫn phải vào đúng tài liệu của nó.
            guard let document = self.document(shownIn: pane) else { return false }
            guard !document.isReadOnly else {
                NSSound.beep()
                return false
            }
            document.buffer.applyEdits(
                [TextEdit(range: range, text: replacement)],
                label: replacement.isEmpty ? "Xóa" : "Gõ"
            )
            // Chỉ ghi phần GÕ ở đây. Xóa đã được ghi qua `onCommand` — ghi cả hai chỗ thì mỗi
            // lần bấm Backspace vào macro hai lần.
            if !replacement.isEmpty { self.macroRecorder.record(.insert(replacement)) }
            self.mirrorEdit(from: pane, in: document)
            self.refreshChrome()
            return true
        }
        pane.onSelectionChange = { [weak self] in
            self?.updateCaretStatus()
            // Khung tầm nhìn của bản đồ đi theo con nháy và theo cuộn. Rẻ: nó KHÔNG dựng lại
            // bản đồ, chỉ dời khung — xem `refreshDocumentMap`.
            self?.refreshDocumentMap()
            // FR-MMD-002 vế hai: chọn vùng văn bản → phần tử tương ứng sáng trên sơ đồ.
            self?.focusMermaidElementAtCaret()
            // FR-KNW-901: thẻ bản ghi đi theo con nháy — «song song văn bản thô».
            self?.updateJSONLRecord()
        }
        pane.onMultiEdit = { [weak self] selection, kind in
            self?.applyMultiCaretEdit(selection, kind)
        }
        pane.onCompositionCommitted = { [weak self] selection, text in
            self?.mirrorCompositionToOtherCarets(selection, text)
        }
        pane.onCommand = { [weak self] selector in
            self?.macroRecorder.record(command: selector)
        }
        // Gợi ý tự hoàn thành chỉ theo pane ĐANG gõ; pane kia không được bung danh sách.
        pane.onTypingPause = { [weak self, weak pane] in
            guard let self, let pane, pane === self.editorView else { return }
            self.refreshCompletion()
            // FR-MMD-002: *"sửa văn bản → preview cập nhật ≤ 500 ms (debounce 300 ms)"*.
            // `onTypingPause` báo MỖI lần văn bản đổi, nên nhịp hoãn nằm ở chỗ nhận.
            self.scheduleMermaidRefresh()
        }
        pane.onCompletionKey = { [weak self, weak pane] event in
            guard let self, let pane, pane === self.editorView else { return false }
            return self.completionPopup.handleKey(event)
        }
        pane.onFocus = { [weak self, weak pane] in
            guard let self, let pane, let index = self.paneViews.firstIndex(of: pane) else { return }
            guard index != self.activePaneIndex else { return }
            self.activePaneIndex = index
            self.refreshChrome()
            self.refreshTabBar()
            self.updateCaretStatus()
        }
    }

    /// Kẹp chỉ số tab của MỌI pane sau khi danh sách tab ngắn lại.
    ///
    /// Chỉ kẹp pane đang hoạt động là để pane kia trỏ ra ngoài mảng — và chỗ nào đọc nó sẽ
    /// hoặc sập, hoặc lặng lẽ hiện nhầm tài liệu.
    private func clampPaneIndices() {
        let last = Swift.max(tabs.count - 1, 0)
        for index in paneTabIndices.indices {
            paneTabIndices[index] = Swift.min(Swift.max(paneTabIndices[index], 0), last)
        }

        syncPanesToTheirTabs()
    }

    /// Mỗi nửa màn hình phải đang hiện ĐÚNG tài liệu mà chỉ số của nó trỏ tới.
    ///
    /// **Đây là một BẤT BIẾN, nên nó được giữ ở một chỗ chứ không ở từng lệnh.** Chỉ số của
    /// pane (`paneTabIndices`) và buffer mà view đang hiện là hai thứ đổi ở hai chỗ khác nhau:
    /// đóng tab làm chỉ số tụt xuống, đổi tab ghi vào chỉ số, mở tài liệu thay `Document` trong
    /// `tabs`. Chỉ cần một trong số ấy quên nạp lại view là hai thứ rời nhau.
    ///
    /// Hậu quả KHÔNG phải là hiện sai chữ. `onEdit` tính vùng sửa trên buffer của VIEW rồi áp
    /// lên buffer của TÀI LIỆU, nên khi hai buffer khác nhau, mọi phím gõ đều tính trên tài
    /// liệu này và áp lên tài liệu kia — hoặc sập ở `precondition`, hoặc sửa im lặng vào một
    /// file người dùng không nhìn thấy.
    ///
    /// Bộ chạy dài `--soak` bắt được cả hai triệu chứng (hạt giống 5 và 1). Vá ở từng lệnh thì
    /// phải nhớ vá ở mọi lệnh, mãi mãi; gọi từ `refreshChrome()` thì mọi lệnh đã đi qua đây rồi.
    ///
    /// So sánh BUFFER, không so sánh chỉ số: chỉ số nói pane *nên* hiện gì, chỉ buffer mới nói
    /// nó *đang* hiện gì. Và chỉ nạp lại khi thật sự lệch — `showPane` đặt lại con nháy, nên
    /// gọi vô cớ là làm người dùng mất chỗ đang đọc.
    private func syncPanesToTheirTabs() {
        // Nạp lại MỌI pane đang hiện sai buffer — không chỉ pane kia.
        //
        // Bản đầu chỉ gọi `showPane(1 - activePaneIndex)`, tức chỉ chữa nửa không được focus.
        // Nhưng chính chỉ số của nửa ĐANG hoạt động cũng bị kẹp ở vòng trên: đóng cái tab mà
        // nó đang trỏ tới thì chỉ số tụt xuống một tab khác, trong khi màn hình vẫn hiện nội
        // dung cũ. Từ lúc ấy `editorView.buffer` và `editorDocument.buffer` là HAI buffer khác
        // nhau, và mọi lệnh trộn hai thứ đó — dán khối, chọn cột, đánh dấu — tính toán trên
        // một tài liệu rồi áp lên một tài liệu khác.
        //
        // Bộ chạy dài `--soak` tìm ra qua đường dán (hạt giống 1, bước 3600): vùng chọn `1..<1`
        // trên một tài liệu 0 byte. Người dùng đi tới đây được: chia đôi, mở vài tab, đóng bớt,
        // bấm sang nửa kia, rồi dán.
        //
        // So sánh BUFFER chứ không so sánh chỉ số: chỉ số nói pane ấy *nên* hiện gì, chỉ có
        // buffer mới nói nó *đang* hiện gì. Và chỉ nạp lại khi thật sự lệch — `showPane` đặt
        // lại con nháy, nên gọi nó vô cớ là làm người dùng mất chỗ đang đọc.
        guard !tabs.isEmpty else { return }
        for index in paneViews.indices where index == 0 || isSplit {
            // KẸP chỉ số tại đây, không bỏ qua khi nó nằm ngoài mảng.
            //
            // Bản đầu viết `guard tabs.indices.contains(…) else { continue }` — nghe như phòng
            // thủ, thật ra là chỗ hở duy nhất còn lại. `paneTabIndices` được phép giữ giá trị
            // quá tầm sau khi danh sách tab ngắn lại; chỉ có getter `activeIndex` là tự kẹp khi
            // ĐỌC. Nên khi `paneTabIndices[1] == 1` mà chỉ còn một tab, `editorDocument` đọc ra
            // tab 0 (đã kẹp) trong khi vòng lặp này bỏ qua pane 1 (chưa kẹp) — đúng cái lệch
            // mà nó sinh ra để chặn.
            //
            // Ghi giá trị đã kẹp NGƯỢC lại, để trạng thái quá tầm không sống thêm một nhịp nào.
            let target = Swift.min(Swift.max(paneTabIndices[index], 0), tabs.count - 1)
            paneTabIndices[index] = target
            if paneViews[index].buffer !== tabs[target].document.buffer {
                showPane(index)
            }
        }
    }

    private func document(shownIn pane: WindowedTextView) -> Document? {
        guard let index = paneViews.firstIndex(of: pane),
              tabs.indices.contains(paneTabIndices[index])
        else { return nil }
        return tabs[paneTabIndices[index]].document
    }

    /// Pane kia đang mở CÙNG tài liệu thì phải thấy nội dung mới ngay (TC-DOC-05).
    ///
    /// Chỉ nạp lại, KHÔNG cuộn theo: "đồng bộ nội dung, độc lập vị trí cuộn" là đúng câu chữ
    /// của FR-DOC-302, và cũng là cả lý do người ta chia đôi màn hình — xem hai chỗ xa nhau
    /// trong cùng một file.
    private func mirrorEdit(from pane: WindowedTextView, in document: Document) {
        guard isSplit else { return }
        for other in paneViews where other !== pane {
            guard self.document(shownIn: other) === document else { continue }
            other.refreshFromBuffer()
        }
    }

    // MARK: - Chia đôi màn hình (FR-DOC-302)

    /// Chia đôi / bỏ chia đôi. Pane mới mở CÙNG tài liệu đang xem.
    @objc func toggleSplitView(_ sender: Any?) {
        isSplit ? closeSplit() : openSplit(vertical: splitView.isVertical)
    }

    @objc func splitVertically(_ sender: Any?) { openSplit(vertical: true) }

    /// Mục menu riêng cho việc BỎ chia đôi.
    ///
    /// Không dùng chung `toggleSplitView`: mục ghi "Bỏ chia đôi" mà bấm lúc chưa chia lại đi
    /// chia ra là nhãn nói một đằng, việc làm một nẻo.
    @objc func closeSplitView(_ sender: Any?) { closeSplit() }

    /// Mở tab đang xem Ở NỬA KIA, rồi chuyển con trỏ gõ sang đó.
    ///
    /// Tên là "mở ở nửa kia" chứ không phải "chuyển sang nửa kia", vì đó đúng là việc nó làm:
    /// hai nửa dùng chung một danh sách tab, nên nửa này vẫn giữ tab ấy. Đặt tên "chuyển" sẽ
    /// hứa một việc không xảy ra.
    ///
    /// Đây là phần "kéo thả tab giữa các pane" của FR-DOC-302 làm bằng LỆNH — đường bàn phím,
    /// đứng cạnh cử chỉ kéo thả.
    ///
    /// *(Chú thích cũ ở đây ghi "cử chỉ kéo thả chưa có". Câu ấy đúng vào ngày nó được viết và
    /// đã TRÔI: `dropTab(_:atScreenPoint:)` nhánh 3 làm đúng việc ấy, và bài tự kiểm "thả vào
    /// nửa phải" đi qua nó. Một dòng chú thích tự khai còn nợ, sau khi nợ đã trả, đọc lên
    /// giống hệt một khoản nợ thật — và nó đã suýt khiến tôi viết lại tính năng lần thứ hai,
    /// đúng chuyện đã xảy ra với `FR-MIN-006` hôm 04/09.)*
    @objc func showTabInOtherPane(_ sender: Any?) {
        let tab = activeIndex
        if !isSplit { openSplit(vertical: splitView.isVertical) }
        let other = 1 - activePaneIndex
        paneTabIndices[other] = tab
        showPane(other)
        activePaneIndex = other
        applyActiveTab()
        refreshTabBar()
        refreshChrome()
    }

    /// Nhảy con trỏ gõ sang pane kia mà không đổi tab nào.
    @objc func focusOtherPane(_ sender: Any?) {
        guard isSplit else { return }
        activePaneIndex = 1 - activePaneIndex
        window?.makeFirstResponder(editorView.textView)
        refreshChrome()
        refreshTabBar()
        updateCaretStatus()
    }
    @objc func splitHorizontally(_ sender: Any?) { openSplit(vertical: false) }

    private func openSplit(vertical: Bool) {
        splitView.isVertical = vertical
        guard !isSplit else {
            centerDivider()          // đổi hướng thì chia lại đều
            return
        }

        // Pane mới mở đúng tài liệu đang xem — đó là "clone" mà SRS nói tới, và cũng là thứ
        // người dùng mong đợi khi bấm chia đôi: so hai chỗ trong CÙNG một file.
        paneTabIndices[1] = paneTabIndices[0]
        splitView.addArrangedSubview(paneViews[1])
        isSplit = true
        centerDivider()
        showPane(1)
        showPane(0)
        activePaneIndex = 0
        refreshChrome()
        refreshTabBar()
    }

    /// Kéo thanh chia về GIỮA.
    ///
    /// `adjustSubviews()` một mình không đủ, và lý do phản trực giác: nó chia lại theo TỈ LỆ
    /// hiện có của các nửa. Nửa vừa thêm vào có bề rộng 0, nên tỉ lệ của nó là 0 và nó ở lại 0.
    /// Kết quả: biến `isSplit` bằng true trong khi người dùng vẫn nhìn thấy đúng một khung —
    /// thấy trên ảnh chụp, rồi bài tự kiểm đo ra "nửa thứ hai 0×666".
    private func centerDivider() {
        // Giải bố cục TRƯỚC khi hỏi bề rộng. Không ép thì `splitView.bounds` còn là số của
        // lần bố trí trước (thường là 0 hoặc 1 ngay sau khi thêm khung), nên "một nửa" tính ra
        // gần 0 — và `NSSplitView` giữ TỈ LỆ ấy khi cửa sổ giãn ra sau đó. Kết quả đo được:
        // hai nửa là 0 và 649.
        window?.contentView?.layoutSubtreeIfNeeded()
        splitView.layoutSubtreeIfNeeded()
        splitView.adjustSubviews()

        let total = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard total > 1 else { return }
        splitView.setPosition(total / 2, ofDividerAt: 0)
    }

    private func closeSplit() {
        guard isSplit else { return }
        splitView.removeArrangedSubview(paneViews[1])
        paneViews[1].removeFromSuperview()
        isSplit = false
        activePaneIndex = 0
        applyActiveTab()
        refreshTabBar()
    }

    // MARK: - Macro (FR-AUTO-601 · FR-AUTO-602)

    @objc func toggleMacroRecording(_ sender: Any?) {
        if macroRecorder.isRecording {
            let steps = macroRecorder.stop()
            guard !steps.isEmpty else {
                return showBanner("Macro rỗng — không ghi được thao tác nào.", actionTitle: nil, action: nil)
            }
            currentMacro = Macro(name: "Chưa đặt tên", steps: steps)
            showBanner("Đã ghi macro \(steps.count) bước. Phát lại bằng menu Macro.",
                       actionTitle: "Lưu…", action: #selector(saveMacro(_:)))
        } else {
            macroRecorder.start()
            showBanner("Đang ghi macro… bấm lại để dừng.",
                       actionTitle: "Dừng", action: #selector(toggleMacroRecording(_:)))
        }
    }

    @objc func playMacro(_ sender: Any?) { runMacro(repetitions: 1) }

    @objc func playMacroTimes(_ sender: Any?) {
        guard let text = askForText(
            title: "Phát macro nhiều lần",
            message: "Số lần chạy.",
            placeholder: "100"
        ), let times = Int(text.trimmingCharacters(in: .whitespaces)), times > 0 else { return }
        runMacro(repetitions: times)
    }

    @objc func playMacroToEndOfFile(_ sender: Any?) { runMacro(repetitions: 0) }

    /// Chạy macro trên MỌI tab đang mở (FR-AUTO-602).
    ///
    /// Chạy trên buffer của từng tab chứ không mở từng tab lên rồi giả lập phím: tab không hiển
    /// thị thì không có khung soạn thảo nào để giả lập, và mở lần lượt 30 tab chỉ để chạy macro
    /// là bắt người dùng xem một màn hình nhấp nháy.
    /// Chạy macro trên MỌI file văn bản trong một thư mục (FR-AUTO-602).
    ///
    /// Khác hẳn "chạy trên mọi tab": ở đó mọi file đều đang mở, người dùng nhìn thấy kết quả và
    /// ⌘Z lùi được. Ở đây file còn chưa mở, không có gì để nhìn, và không có bước lùi nào —
    /// nên mặc định ghi ra file MỚI cạnh file gốc, và hỏi lại trước khi chạy.
    @objc func playMacroOnFolder(_ sender: Any?) {
        guard let macro = currentMacro, !macro.isEmpty else { return reportNoMacro() }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Chạy"
        // Ô mask nằm NGAY TRONG hộp chọn thư mục, không phải một hộp thoại thứ hai: chọn thư
        // mục nào và chạy trên tệp nào là một quyết định, hỏi làm hai lần là bắt người dùng
        // nhớ lại chỗ họ vừa chọn.
        let maskField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        maskField.placeholderString = L("Lọc tên tệp — ví dụ *.csv;*.log (để trống: mọi tệp văn bản)")
        let holder = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 44))
        maskField.frame.origin = NSPoint(x: 10, y: 10)
        holder.addSubview(maskField)
        panel.accessoryView = holder
        panel.isAccessoryViewDisclosed = true
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        playMacroOnFolderForSelfTest(path: url.path, mask: maskField.stringValue)
    }

    /// Phần LÀM VIỆC của `playMacroOnFolder`, tách khỏi phần HỎI.
    ///
    /// `Unattended.chooseFile` luôn trả `.abort` trong lượt chạy không người, nên mọi thứ gộp
    /// chung với hộp chọn tệp là mã không bài kiểm nào chạm tới được — đúng chỗ hở mà cổng độ
    /// phủ tầng app đã lộ ra hồi 04/09.
    func playMacroOnFolderForSelfTest(path: String, mask: String, force: Bool = false) {
        guard let macro = currentMacro, !macro.isEmpty else { return reportNoMacro() }
        let url = URL(fileURLWithPath: path)

        let files = MacroBatch.textFiles(in: path, mask: mask)
        guard !files.isEmpty else {
            // Nói ra CẢ mask khi có: "không có file văn bản nào" là câu trả lời sai khi thư mục
            // đầy tệp mà mask không khớp cái nào — người dùng sẽ đi tìm lỗi ở thư mục.
            showBanner(
                mask.isEmpty
                    ? LF("Thư mục %@ không có file văn bản nào", url.lastPathComponent)
                    : LF("Không tệp nào trong %@ khớp «%@»", url.lastPathComponent, mask),
                actionTitle: nil, action: nil
            )
            return
        }

        // Hỏi lại kèm SỐ FILE. Người dùng chỉ vào một thư mục thì họ biết tên nó, chứ chưa chắc
        // biết trong đó có hai trăm file — và đó đúng là con số quyết định họ có bấm hay không.
        let alert = NSAlert()
        alert.messageText = "Chạy macro «\(macro.name)» trên \(files.count) file?"
        alert.informativeText = "Kết quả ghi ra file MỚI cạnh file gốc, thêm hậu tố «-macro». "
            + "File gốc không bị đụng tới."
        alert.addButton(withTitle: "Chạy")
        alert.addButton(withTitle: "Huỷ")
        // `force` chỉ bỏ qua CÂU HỎI, không bỏ qua việc gì khác — xem `Unattended`: bài kiểm
        // chạy trên một câu trả lời do chính nó bịa ra thì không kiểm được gì, nên chỗ nào
        // thật sự muốn chạy tới cùng phải nói ra bằng tham số.
        guard force || Unattended.ask(alert) == .alertFirstButtonReturn else { return }

        let token = CancelToken()
        macroCancelToken = token
        showTransient("Đang chạy macro trên \(files.count) file…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = MacroBatch.run(
                macro, on: files, repetitions: 0,
                destination: .suffix("-macro"), cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.macroCancelToken = nil
                self.openTextInNewTab(result.report, label: "Báo cáo macro")
                self.showTransient(
                    "\(result.succeededCount)/\(result.files.count) file xong"
                        + (result.failedCount > 0 ? " · \(result.failedCount) lỗi" : "")
                )
            }
        }
    }

    @objc func playMacroOnAllTabs(_ sender: Any?) {
        guard let macro = currentMacro, !macro.isEmpty else { return reportNoMacro() }
        let token = CancelToken()
        macroCancelToken = token

        var touched = 0
        var lines: [String] = []
        for tab in tabs {
            guard !tab.document.isReadOnly else {
                lines.append("\(tabTitle(tab)): chỉ đọc, bỏ qua")
                continue
            }
            let runner = MacroRunner(buffer: tab.document.buffer, caretOffset: 0)
            let result = runner.run(macro, repetitions: 0, cancelToken: token)
            if result.repetitions > 0 { touched += 1 }
            lines.append("\(tabTitle(tab)): \(result.repetitions) lần")
            tab.document.refreshEOLReport()
        }
        macroCancelToken = nil
        syncViewFromBuffer()
        refreshChrome()
        refreshTabBar()
        showBanner("Macro chạy trên \(touched)/\(tabs.count) tab · " + lines.prefix(4).joined(separator: " · "), actionTitle: nil, action: nil)
    }

    private func tabTitle(_ tab: EditorTab) -> String {
        tab.document.path.map { ($0 as NSString).lastPathComponent } ?? "Chưa đặt tên"
    }

    private func runMacro(repetitions: Int) {
        guard let macro = currentMacro, !macro.isEmpty else { return reportNoMacro() }
        guard !editorDocument.isReadOnly else { return NSSound.beep() }

        let token = CancelToken()
        macroCancelToken = token
        let runner = MacroRunner(
            buffer: editorDocument.buffer,
            caretOffset: editorView.selectedDocumentRange.lowerBound
        )
        let result = runner.run(macro, repetitions: repetitions, cancelToken: token)
        macroCancelToken = nil

        editorDocument.refreshEOLReport()
        syncViewFromBuffer()
        editorView.setSelectedDocumentRange(runner.selection)
        editorView.reveal(documentOffset: runner.selection.lowerBound)
        refreshChrome()
        updateCaretStatus()

        // NÓI RA vì sao dừng. "Chạy 3 lần rồi thôi" mà không giải thích thì người dùng không
        // biết là macro sai, tài liệu hết chỗ khớp, hay ứng dụng hỏng.
        let why: String
        switch result.reason {
        case .finished: why = "xong"
        case .notFound: why = "hết chỗ khớp"
        case .endOfDocument: why = "tới cuối tài liệu"
        case .cancelled: why = "đã hủy"
        case .madeNoProgress: why = "macro không làm thay đổi gì nên dừng để khỏi chạy mãi"
        case .error(let message): why = "lỗi: \(message)"
        }
        showBanner("Macro «\(macro.name)» chạy \(result.repetitions) lần — \(why).", actionTitle: nil, action: nil)
    }

    @objc func cancelMacro(_ sender: Any?) { macroCancelToken?.cancel() }

    @objc func saveMacro(_ sender: Any?) {
        guard let macro = currentMacro, !macro.isEmpty else { return reportNoMacro() }
        guard let name = askForText(
            title: "Lưu macro",
            message: "Tên macro — hiện trong menu Macro ở những lần mở sau.",
            placeholder: "Đổi ERROR thành WARN"
        ), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let named = Macro(name: name, steps: macro.steps)
        do {
            try macroStore.save(named)
            currentMacro = named
            showBanner("Đã lưu macro «\(name)».", actionTitle: nil, action: nil)
        } catch {
            presentError("Không lưu được macro", error)
        }
    }

    /// Menu các macro đã lưu.
    func makeSavedMacroMenu() -> NSMenu {
        let menu = NSMenu(title: "Macro đã lưu")
        let saved = (try? macroStore.all()) ?? []
        guard !saved.isEmpty else {
            menu.addItem(withTitle: "(chưa có macro nào)", action: nil, keyEquivalent: "")
            return menu
        }
        for (index, macro) in saved.enumerated() {
            let item = menu.addItem(
                withTitle: "\(macro.name) — \(macro.steps.count) bước",
                action: #selector(pickSavedMacro(_:)),
                // Chín macro đầu được phím tắt ⌃⌘1…⌃⌘9. FR-AUTO-601 đòi "gán phím tắt cho
                // macro đã lưu"; gán TỰ ĐỘNG theo thứ tự tên là phần làm được ở Phase 1, còn
                // cho người dùng tự chọn phím là việc của Shortcut Mapper (FR-UI-802, Phase 2).
                keyEquivalent: index < 9 ? String(index + 1) : ""
            )
            item.keyEquivalentModifierMask = [.command, .control]
            item.target = self
            item.tag = index
        }
        return menu
    }

    @objc func showSavedMacroMenu(_ sender: Any?) {
        makeSavedMacroMenu().popUp(positioning: nil, at: NSPoint(x: 24, y: 24), in: editorView)
    }

    @objc private func pickSavedMacro(_ sender: NSMenuItem) {
        let saved = (try? macroStore.all()) ?? []
        guard saved.indices.contains(sender.tag) else { return }
        currentMacro = saved[sender.tag]
        showBanner("Macro «\(saved[sender.tag].name)» đã sẵn sàng. Phát lại bằng menu Macro.", actionTitle: nil, action: nil)
    }

    private func reportNoMacro() {
        showBanner("Chưa có macro nào. Ghi một macro trước, hoặc chọn macro đã lưu.", actionTitle: nil, action: nil)
    }

    // MARK: - Kéo thả tab (FR-DOC-301 · FR-DOC-302)

    /// Đổi vị trí một tab trong danh sách.
    ///
    /// Phần dễ sai không phải là dời phần tử mà là dời MỌI chỉ số đang trỏ vào danh sách: tab
    /// đang mở của từng nửa màn hình. Quên một chỗ thì kéo một tab sang trái là nửa kia lặng
    /// lẽ nhảy sang tài liệu khác. Phép dời chỉ số nằm ở lõi và có test (`TabReorderTests`).
    private func moveTab(from: Int, to: Int) {
        guard tabs.indices.contains(from), from != to else { return }
        let count = tabs.count
        tabs = TabReorder.apply(tabs, from: from, to: to)
        for pane in paneTabIndices.indices {
            paneTabIndices[pane] = TabReorder.track(
                paneTabIndices[pane], from: from, to: to, count: count
            )
        }
        refreshTabBar()
        saveSession()
    }

    /// Thả một tab ra ngoài thanh tab.
    ///
    /// Thả vào NỬA KIA của màn hình thì nửa ấy mở tab đó — đây là "kéo thả tab giữa các pane"
    /// của FR-DOC-302. Thả vào chỗ khác thì không làm gì: thả nhầm là chuyện thường, và một cú
    /// thả nhầm không được đổi bố cục màn hình của người dùng.
    /// Thả tab ra ngoài thanh tab: sang cửa sổ khác, sang nửa kia, hoặc ra cửa sổ mới.
    private func dropTab(_ index: Int, atScreenPoint screen: NSPoint) {
        guard tabs.indices.contains(index) else { return }

        // 1. Rơi vào một CỬA SỔ KHÁC → dời tab sang đó (FR-DOC-302).
        if let target = WindowManager.shared.controller(atScreenPoint: screen, excluding: self) {
            moveTab(at: index, to: target)
            return
        }
        // 2. Rơi RA NGOÀI mọi cửa sổ → tách ra cửa sổ mới, đúng lối Safari và Chrome.
        //
        // Chỉ khi cửa sổ này còn tab khác: kéo tab duy nhất ra ngoài rồi tạo cửa sổ mới là dời
        // một cửa sổ trống sang chỗ khác, không phải điều ai muốn.
        guard let window, window.frame.contains(screen) else {
            if tabs.count > 1 { moveTab(at: index, to: nil) }
            return
        }
        // 3. Rơi vào chính cửa sổ này → chia đôi màn hình, như trước.
        let point = window.convertPoint(fromScreen: screen)
        guard isSplit else { return }
        let other = 1 - activePaneIndex
        let view = paneViews[other]
        let local = view.convert(point, from: nil)
        guard view.bounds.contains(local) else { return }

        paneTabIndices[other] = index
        showPane(other)
        activePaneIndex = other
        applyActiveTab()
        refreshTabBar()
        refreshChrome()
        saveSession()
    }

    /// Nạp tài liệu của một pane lên chính pane ấy.
    private func showPane(_ index: Int) {
        guard tabs.indices.contains(paneTabIndices[index]) else { return }
        let tab = tabs[paneTabIndices[index]]
        paneViews[index].lineMarks = tab.marks
        paneViews[index].load(tab.document.buffer,
                              caretAt: min(tab.caretOffset, tab.document.buffer.count))
    }

    /// Đưa tab đang mở lên màn hình.
    private func applyActiveTab() {
        let tab = tabs[activeIndex]
        // Dấu đi THEO TÀI LIỆU, nên phải đổi cùng lúc với buffer. Quên chỗ này thì tab mới hiện
        // ra với các dòng tô nền của tab cũ — số dòng trùng nhau nhưng nội dung thì không.
        editorView.lineMarks = tab.marks
        // Dấu gạch lỗi KHÔNG đi theo tài liệu như dấu dòng — nó được dựng lại sau mỗi lượt vẽ
        // sơ đồ, nên chỗ đúng để xoá là ĐÂY. Giữ lại thì tab mới hiện ra với những dòng gạch đỏ
        // của tab cũ, và tệ hơn: chúng là offset BYTE, nên trên một tab ngắn hơn chúng trỏ RA
        // NGOÀI tài liệu. Bài tự kiểm FR-MMD-006 sập ở đúng chỗ ấy, không phải đỏ — sập.
        editorView.problemRanges = []
        mermaidBlocks = []
        // Khung View của tab CŨ phải tắt — cùng lý do với hai dòng ngay trên: nó mô tả một tài
        // liệu không còn được hiện. Mở một tệp CSV rồi sang tab JSON thì bảng CSV vẫn nằm đó,
        // che tài liệu mới; lỗi ấy sống tới khi khung chung buộc câu hỏi "đang ở chế độ nào"
        // phải có câu trả lời đúng ở mọi lúc.
        hideAllViewModes()
        hideDocumentPanels()
        forgetCSVIndex()
        editorView.load(tab.document.buffer, caretAt: min(tab.caretOffset, tab.document.buffer.count))
        syncMediaViewer()
        openDefaultViewModeIfWanted()
        refreshChrome()
        refreshTabBar()
        // Tab mới có sơ đồ thì vẽ lại; không có thì `refreshMermaidPreview` tự dọn trang.
        if isMermaidPanelVisible { refreshMermaidPreview() }
    }

    private func refreshTabBar() {
        if ProcessInfo.processInfo.environment["GEDITOR_TRACE_TABS"] != nil {
            NSLog("[GEditor] tab: %d cái, đang mở #%d — %@", tabs.count, activeIndex,
                  tabs.map { $0.document.path ?? "chưa tên" }.joined(separator: ", "))
        }
        tabBar.items = tabs.map { tab in
            TabBarView.Item(
                title: tab.document.path.map { ($0 as NSString).lastPathComponent } ?? "Chưa đặt tên",
                isModified: tab.document.isModified,
                isPinned: tab.isPinned,
                colorIndex: tab.colorIndex,
                tooltip: tab.document.path
            )
        }
        tabBar.activeIndex = activeIndex
    }

    /// Menu ngữ cảnh của tab — SRS gọi tên từng mục.
    private func showTabMenu(_ index: Int, at point: NSPoint) {
        guard tabs.indices.contains(index) else { return }
        let menu = NSMenu()

        func add(_ title: String, _ action: Selector, enabled: Bool = true) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = index
            item.isEnabled = enabled
            menu.addItem(item)
        }

        add("Đóng tab", #selector(menuCloseTab(_:)))
        add("Đóng các tab khác", #selector(menuCloseOthers(_:)), enabled: tabs.count > 1)
        add("Đóng các tab bên trái", #selector(menuCloseLeft(_:)), enabled: index > 0)
        add("Đóng các tab bên phải", #selector(menuCloseRight(_:)), enabled: index < tabs.count - 1)
        menu.addItem(.separator())
        add(tabs[index].isPinned ? "Bỏ ghim" : "Ghim tab", #selector(menuTogglePin(_:)))

        let colorMenu = NSMenu()
        let none = NSMenuItem(title: "Không màu", action: #selector(menuSetColor(_:)), keyEquivalent: "")
        none.target = self
        none.representedObject = [index, -1]
        colorMenu.addItem(none)
        for (colorIndex, color) in TabBarView.colors.enumerated() {
            let item = NSMenuItem(title: "Màu \(colorIndex + 1)", action: #selector(menuSetColor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [index, colorIndex]
            item.image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
                color.setFill(); rect.fill(); return true
            }
            colorMenu.addItem(item)
        }
        let colorItem = NSMenuItem(title: "Tô màu tab", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        menu.addItem(.separator())
        add("Chép đường dẫn", #selector(menuCopyPath(_:)), enabled: tabs[index].document.path != nil)
        add("Hiện trong Finder", #selector(menuRevealInFinder(_:)), enabled: tabs[index].document.path != nil)

        menu.popUp(positioning: nil, at: tabBar.convert(point, to: nil), in: tabBar)
    }

    @objc private func menuCloseTab(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        closeTab(at: index)
    }

    @objc private func menuCloseOthers(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        // Tab GHIM không bị đóng theo — đó là toàn bộ ý nghĩa của việc ghim.
        activateTab(index)
        closeTabs { _ in true }
    }

    @objc private func menuCloseLeft(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, index > 0 else { return }
        closeTabs(where: { $0 < index })
    }

    @objc private func menuCloseRight(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, index < tabs.count - 1 else { return }
        closeTabs(where: { $0 > index })
    }

    /// Đóng các tab theo VỊ TRÍ, giữ nguyên tab ghim và tab đang mở.
    ///
    /// Đi theo `Document` (là class, so được bằng ===) chứ không theo chỉ số: chỉ số dịch ngay
    /// sau lần xóa đầu tiên, và bám theo chỉ số cũ là đóng nhầm tab.
    private func closeTabs(where shouldClose: (Int) -> Bool) {
        let survivor = tabs[activeIndex].document
        let doomed = tabs.enumerated()
            .filter { shouldClose($0.offset) && !$0.element.isPinned && $0.element.document !== survivor }
            .map(\.element.document)
        guard !doomed.isEmpty else { return }

        for document in doomed {
            if let path = document.path { cliBridge?.documentClosed(path: path) }
        }
        for index in tabs.indices where doomed.contains(where: { $0 === tabs[index].document }) {
            stopFollowingTail(inTab: index)
        }
        tabs.removeAll { tab in doomed.contains { $0 === tab.document } }
        activeIndex = tabs.firstIndex { $0.document === survivor } ?? 0
        clampPaneIndices()
        applyActiveTab()
        // Ghi phiên ngay khi DANH SÁCH tab đổi, không đợi nhịp 20 giây: nội dung có bản nháp
        // đỡ, còn danh sách tab thì chỉ phiên giữ. Ghi một file JSON vài trăm byte.
        saveSession()
    }

    @objc private func menuTogglePin(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        tabs[index].isPinned.toggle()
        refreshTabBar()
    }

    @objc private func menuSetColor(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [Int], pair.count == 2 else { return }
        tabs[pair[0]].colorIndex = pair[1] < 0 ? nil : pair[1]
        refreshTabBar()
    }

    @objc private func menuCopyPath(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, let path = tabs[index].document.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    @objc private func menuRevealInFinder(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, let path = tabs[index].document.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    // MARK: - Ngắt dòng mềm (FR-CORE-015)

    /// Vòng qua ba chế độ: tắt → theo cửa sổ → tại cột → tắt.
    ///
    /// Một mục menu thay vì ba, vì đây là thứ người ta bật/tắt liên tục trong lúc đọc một file
    /// lạ. Có nói ra chế độ vừa chuyển sang: ở tài liệu không có dòng nào đủ dài, ba chế độ
    /// trông giống hệt nhau và người dùng sẽ tưởng lệnh hỏng.
    @objc func cycleWrapMode(_ sender: Any?) {
        editorView.wrapMode = editorView.wrapMode.next(defaultColumn: statusBar.state.wrapColumn)
        findPanel.showStatus("Ngắt dòng: \(editorView.wrapMode.displayName)")
        statusBar.state.wrapMode = editorView.wrapMode
    }

    /// Đặt cột ngắt cho chế độ "tại cột" và chuyển sang chế độ ấy luôn.
    @objc func setWrapColumn(_ sender: Any?) {
        guard let text = askForText(
            title: "Ngắt dòng tại cột",
            message: "Số cột — 72 cho commit message, 80 cho thư và mã nguồn theo lối cũ.",
            placeholder: String(statusBar.state.wrapColumn)
        ), let column = Int(text.trimmingCharacters(in: .whitespaces)), column > 0 else { return }

        statusBar.state.wrapColumn = column
        editorView.wrapMode = .column(column)
        statusBar.state.wrapMode = editorView.wrapMode
        findPanel.showStatus("Ngắt dòng: \(editorView.wrapMode.displayName)")
    }

    // MARK: - Hiện ký tự ẩn (FR-ENC-205)

    @objc func toggleAllInvisibles(_ sender: Any?) {
        editorView.invisibles = editorView.invisibles.isAnyOn ? InvisibleOptions() : .allOn
        reportInvisibles()
    }

    @objc func toggleInvisibleSpaces(_ sender: Any?) {
        editorView.invisibles.spaces.toggle()
        reportInvisibles()
    }

    @objc func toggleInvisibleTabs(_ sender: Any?) {
        editorView.invisibles.tabs.toggle()
        reportInvisibles()
    }

    @objc func toggleInvisibleLineEndings(_ sender: Any?) {
        editorView.invisibles.lineEndings.toggle()
        reportInvisibles()
    }

    @objc func toggleInvisibleSpecial(_ sender: Any?) {
        editorView.invisibles.special.toggle()
        reportInvisibles()
    }

    /// Nói ra nhóm nào đang hiện.
    ///
    /// Bật một nhóm mà tài liệu không có ký tự nhóm đó thì màn hình KHÔNG đổi gì — không nói
    /// ra thì người dùng tưởng lệnh hỏng.
    private func reportInvisibles() {
        let options = editorView.invisibles
        let names = [
            options.spaces ? "khoảng trắng" : nil,
            options.tabs ? "tab" : nil,
            options.lineEndings ? "xuống dòng" : nil,
            options.special ? "NBSP/zero-width/điều khiển" : nil,
        ].compactMap { $0 }
        let message = names.isEmpty ? "Đã tắt ký tự ẩn" : "Hiện: " + names.joined(separator: ", ")
        findPanel.showStatus(message)
        if ProcessInfo.processInfo.environment["GEDITOR_TRACE_INVISIBLES"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSLog("[GEditor] %@ · vẽ %d đoạn · %d ký hiệu",
                      message, InvisiblesLayoutFragment.drawCount, InvisiblesLayoutFragment.symbolCount)
            }
        }
    }

    // MARK: - Đánh dấu & lọc dòng (FR-SRCH-107)

    @objc func markAllMatchingLines(_ sender: Any?) {
        guard let text = askForText(
            title: "Đánh dấu mọi dòng khớp",
            message: "Dùng đúng chế độ tìm đang chọn ở thanh Tìm (thường / regex).",
            placeholder: "ERROR"
        ), !text.isEmpty else { return }

        do {
            // Dùng đúng chế độ (thường/regex/khớp hoa thường) mà người dùng đang đặt ở thanh
            // Tìm: hai chỗ tìm kiếm trong cùng một cửa sổ mà hiểu pattern khác nhau là cách
            // chắc chắn làm người dùng mất lòng tin vào kết quả.
            var query = findPanel.query
            query.pattern = text
            let found = try LineMarks.marking(
                pattern: text, in: editorDocument.buffer,
                engine: PCRE2SearchEngine(), options: query.options
            )
            // Đánh dấu vào MÀU ĐANG CHỌN và không đụng tám màu kia — đó là cả điểm của "9 màu
            // độc lập": đánh dấu ERROR màu đỏ, timeout màu xanh, rồi nhìn cả hai cùng lúc.
            var updated = marks
            updated.active = found
            marks = updated
            // Nhắc lại pattern trong thông báo: "0 dòng" mà không biết đã tìm CHUỖI NÀO thì
            // người dùng không đoán nổi là sai pattern hay sai chế độ tìm.
            reportMarks("«\(text)» → \(found.count) / \(editorDocument.buffer.lineCount) dòng"
                        + " · chế độ \(query.mode) · \(activeMarkColorName)")
        } catch {
            presentError("Không đánh dấu được", error)
        }
    }

    @objc func invertLineMarks(_ sender: Any?) {
        var updated = marks
        updated.invertActive(lineCount: editorDocument.buffer.lineCount)
        marks = updated
        reportMarks("Đã đảo dấu \(activeMarkColorName) — còn \(marks.count) dòng")
    }

    @objc func clearLineMarks(_ sender: Any?) {
        var updated = marks
        updated.clearAll()
        marks = updated
        reportMarks("Đã bỏ dấu")
    }

    // MARK: - Chín màu bookmark (FR-SRCH-107)

    private var activeMarkColorName: String {
        Tokens.Color.markColorNames[marks.activeColor]
    }

    /// ⌘F2 — bật/tắt dấu ở dòng đang đứng, theo đúng phím của Notepad++ (UI/UX §9.1).
    @objc func toggleLineMark(_ sender: Any?) {
        let line = editorDocument.buffer.lineNumber(
            atOffset: min(editorView.selectedDocumentRange.lowerBound, editorDocument.buffer.count)
        )
        var updated = marks
        updated.toggle(line)
        marks = updated
        findPanel.showStatus(
            (updated.colors(at: line).isEmpty ? "Bỏ dấu dòng " : "Đánh dấu dòng ")
                + "\(line + 1) · \(activeMarkColorName)"
        )
    }

    /// F2 / ⇧F2 — nhảy tới dấu kế / trước, quay vòng.
    @objc func goToNextMark(_ sender: Any?) { jumpToMark(forward: true) }
    @objc func goToPreviousMark(_ sender: Any?) { jumpToMark(forward: false) }

    private func jumpToMark(forward: Bool) {
        guard !marks.isEmpty else { return reportNoMarks() }
        let buffer = editorDocument.buffer
        let current = buffer.lineNumber(
            atOffset: min(editorView.selectedDocumentRange.lowerBound, buffer.count)
        )
        // Chỉ nhảy tới dấu còn TỒN TẠI: tài liệu co lại thì dấu cũ trỏ vào dòng đã biến mất,
        // và `offset(ofLineStart:)` có `precondition` — sập, chứ không phải hiện sai.
        guard let line = forward
            ? marks.nextMarkedLine(after: current, withinLineCount: buffer.lineCount)
            : marks.previousMarkedLine(before: current, withinLineCount: buffer.lineCount)
        else { return reportNoMarks() }

        let offset = buffer.offset(ofLineStart: line)
        editorView.setCaret(documentOffset: offset)
        editorView.reveal(documentOffset: offset)
        updateCaretStatus()
        findPanel.showStatus("Dòng \(line + 1) / \(marks.count) dấu")
    }

    /// Menu đổi màu — chín màu, có chấm màu để nhìn thấy chứ không chỉ đọc tên.
    @objc func showMarkColorMenu(_ sender: Any?) {
        let menu = makeMarkColorMenu()
        // Bung ra trên KHUNG SOẠN THẢO, không phải trên thanh Tìm.
        //
        // Bản đầu neo vào `findPanel`, mà thanh Tìm thường đang ẩn: menu hiện ra ở một chỗ vô
        // nghĩa và lần chọn màu đầu tiên không ăn. Thấy trên ảnh chụp — hai dòng lẽ ra khác
        // màu thì cùng một màu.
        menu.popUp(positioning: menu.item(at: marks.activeColor),
                   at: NSPoint(x: 24, y: 24), in: editorView)
    }

    /// Dựng menu chín màu.
    ///
    /// Tách khỏi `showMarkColorMenu` để KIỂM ĐƯỢC. Menu bung ra là modal, nên bài tự kiểm
    /// không mở nó được, và kịch bản AppleScript thì với không tới — đường đổi màu vì thế rơi
    /// đúng vào trạng thái "đã viết nhưng chưa ai kiểm". Giờ bài kiểm dựng menu này rồi gọi
    /// thẳng hành động của một mục, tức là đi qua đúng đoạn mã người dùng đi qua trừ cú bấm.
    func makeMarkColorMenu() -> NSMenu {
        let menu = NSMenu(title: "Màu đánh dấu")
        for (index, name) in Tokens.Color.markColorNames.enumerated() {
            let item = menu.addItem(
                withTitle: "\(name) — \(marks[index].count) dòng",
                action: #selector(pickMarkColor(_:)), keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.state = index == marks.activeColor ? .on : .off
            item.image = markSwatch(Tokens.Color.markColors[index])
        }
        return menu
    }

    @objc private func pickMarkColor(_ sender: NSMenuItem) {
        var updated = marks
        updated.setActiveColor(sender.tag)
        marks = updated
        findPanel.showStatus("Màu đánh dấu: \(activeMarkColorName)")
    }

    /// Chấm màu cho menu. Vẽ trên nền vùng soạn thảo vì màu đánh dấu là màu NỀN có alpha —
    /// vẽ trên nền trong suốt thì chín ô trông gần như giống nhau.
    private func markSwatch(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        Tokens.Color.editorBackground.setFill()
        NSRect(origin: .zero, size: size).fill()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        Tokens.Color.separator.setStroke()
        NSBezierPath(rect: NSRect(x: 0.5, y: 0.5, width: 13, height: 13)).stroke()
        image.unlockFocus()
        return image
    }

    /// Báo kết quả đánh dấu ở chỗ NHÌN THẤY ĐƯỢC.
    ///
    /// Trước đây chỉ gọi `findPanel.showStatus`, mà thanh Tìm thường đang đóng — người dùng
    /// bấm "Đánh dấu" rồi không thấy gì xảy ra và không biết là 0 dòng hay 500 dòng. Chính
    /// tôi cũng mất một lúc mới biết thao tác có chạy hay không.
    private func reportMarks(_ message: String) {
        findPanel.showStatus(message)
        statusBar.state.selectionSummary = marks.isEmpty ? nil : "\(marks.count) dòng đánh dấu"
        showBanner(message, actionTitle: marks.isEmpty ? nil : "Bỏ dấu",
                   action: marks.isEmpty ? nil : #selector(clearLineMarks(_:)))
    }

    @objc func copyMarkedLines(_ sender: Any?) {
        guard !marks.isEmpty else { return reportNoMarks() }
        let text = LineMarks.text(of: marks.union, in: editorDocument.buffer)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        findPanel.showStatus("Đã chép \(marks.count) dòng")
    }

    @objc func deleteMarkedLines(_ sender: Any?) {
        guard !marks.isEmpty else { return reportNoMarks() }
        applyMarkFilter(LineMarks.deleteEdits(marked: marks.union, in: editorDocument.buffer),
                        label: "Xóa \(marks.count) dòng đã đánh dấu")
    }

    @objc func keepOnlyMarkedLines(_ sender: Any?) {
        guard !marks.isEmpty else { return reportNoMarks() }
        applyMarkFilter(LineMarks.keepOnlyEdits(marked: marks.union, in: editorDocument.buffer),
                        label: "Chỉ giữ \(marks.count) dòng đã đánh dấu")
    }

    /// Chưa đánh dấu dòng nào mà bấm lọc: nói ra, đừng chỉ kêu bíp.
    ///
    /// Tiếng bíp không phân biệt được "không có dòng nào đánh dấu" với "lệnh không tồn tại",
    /// và trên máy tắt tiếng thì nó là không có gì cả.
    private func reportNoMarks() {
        showBanner("Chưa đánh dấu dòng nào — dùng Search ▸ Đánh dấu mọi dòng khớp… trước",
                   actionTitle: nil, action: nil)
        NSSound.beep()
    }

    /// Áp một phép lọc rồi BỎ DẤU.
    ///
    /// Sau khi xóa dòng thì số dòng dịch hết, nên tập dấu cũ trỏ vào những dòng khác — giữ nó
    /// lại là mời người dùng xóa nhầm ở lần bấm sau. Bỏ dấu và nói ra rõ ràng.
    private func applyMarkFilter(_ edits: [TextEdit], label: String) {
        apply(edits, label: label)
        var cleared = marks
        cleared.clearAll()
        marks = cleared
        // Đi qua cùng một đường báo cáo: banner cũ nói "đã đánh dấu 2 dòng" mà dấu vừa bị bỏ
        // thì nó đang nói dối người dùng.
        reportMarks(label + " · đã bỏ dấu vì số dòng đã đổi")
    }

    // MARK: - Thao tác dòng (FR-CORE-007)

    @objc func joinLines(_ sender: Any?) {
        // Không chọn gì thì ghép dòng hiện tại với dòng kế — đúng thói quen của Notepad++.
        // Không chọn gì thì ghép dòng hiện tại với dòng kế. Ở dòng CUỐI thì không có gì để
        // ghép — `line ... line - 1` là một ClosedRange ngược và Swift bắn ngay tại chỗ.
        let line = caretLine()
        let last = max(editorDocument.buffer.lineCount - 1, 0)
        guard let range = selectedLineRange() ?? (line < last ? line ... line + 1 : nil) else { return }
        apply(DocumentOps.joinLines(in: editorDocument.buffer, lineRange: range), label: "Ghép dòng")
    }

    @objc func moveLinesUp(_ sender: Any?) { moveLines(by: -1) }
    @objc func moveLinesDown(_ sender: Any?) { moveLines(by: 1) }

    private func moveLines(by offset: Int) {
        let line = caretLine()
        let range = selectedLineRange() ?? line ... line
        apply(
            DocumentOps.moveLines(in: editorDocument.buffer, lineRange: range, by: offset),
            label: offset < 0 ? "Dời dòng lên" : "Dời dòng xuống"
        )
    }

    @objc func reverseLines(_ sender: Any?) {
        apply(
            DocumentOps.reverseLines(in: editorDocument.buffer, lineRange: selectedLineRange()),
            label: "Đảo thứ tự dòng"
        )
    }

    @objc func duplicateLines(_ sender: Any?) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        let line = caretLine()
        apply(
            DocumentOps.duplicateLines(
                in: editorDocument.buffer, lineRange: selectedLineRange() ?? line ... line
            ),
            label: "Nhân đôi dòng"
        )
    }

    @objc func deleteLines(_ sender: Any?) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        let line = caretLine()
        apply(
            DocumentOps.deleteLines(
                in: editorDocument.buffer, lineRange: selectedLineRange() ?? line ... line
            ),
            label: "Xóa dòng"
        )
    }

    // MARK: - Comment nhanh (FR-CORE-014)

    /// ⌘/ — bật/tắt comment cho dòng hiện tại hoặc khối đang chọn.
    ///
    /// Ngôn ngữ không có comment MỘT DÒNG (XML, HTML, CSS, JSON) thì dùng cặp dấu khối bọc
    /// quanh cả khối. Ngôn ngữ không có kiểu nào — JSON đúng theo chuẩn là vậy — thì nói ra
    /// chứ không im lặng: bấm một phím tắt mà không có gì xảy ra trông y hệt app treo.
    @objc func toggleComment(_ sender: Any?) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        let line = caretLine()
        let range = selectedLineRange() ?? line ... line
        let language = editorView.syntaxLanguage

        if let token = language?.lineCommentToken {
            apply(
                DocumentOps.toggleLineComment(
                    in: editorDocument.buffer, lineRange: range, token: token
                ),
                label: "Comment dòng"
            )
            return
        }
        if let pair = language?.blockCommentTokens {
            apply(
                DocumentOps.toggleBlockComment(
                    in: editorDocument.buffer, lineRange: range, open: pair.open, close: pair.close
                ),
                label: "Comment khối"
            )
            return
        }
        // Văn bản thuần cũng rơi vào đây. `#` là quy ước rộng nhất cho file cấu hình không rõ
        // kiểu, và người dùng bấm ⌘/ trong một file .txt thì đang muốn đánh dấu một dòng.
        guard language != nil else {
            apply(
                DocumentOps.toggleLineComment(
                    in: editorDocument.buffer, lineRange: range, token: "#"
                ),
                label: "Comment dòng"
            )
            return
        }
        showTransient("⚠ \(language!.displayName) không có cú pháp comment")
    }

    @objc func splitLinesByLength(_ sender: Any?) {
        guard let text = askForText(
            title: "Tách dòng theo độ dài",
            message: "Số KÝ TỰ tối đa mỗi dòng. Cắt tại khoảng trắng gần nhất để không đứt giữa từ.",
            placeholder: "80"
        ), let length = Int(text), length > 0 else { return }

        let range = selectedLineRange()
        runOperation("Tách dòng ở \(length) ký tự") {
            try DocumentOps.splitLines(in: editorDocument.buffer, lineRange: range, atLength: length)
        }
    }

    @objc func splitLinesByCharacter(_ sender: Any?) {
        guard let text = askForText(
            title: "Tách dòng theo ký tự",
            message: "Mỗi lần gặp ký tự này thì xuống dòng. Bản thân ký tự bị bỏ đi.",
            placeholder: ","
        ), let character = text.first else { return }

        let range = selectedLineRange()
        runOperation("Tách dòng tại \"\(character)\"") {
            try DocumentOps.splitLines(in: editorDocument.buffer, lineRange: range, atCharacter: character)
        }
    }

    @objc func squeezeBlankLines(_ sender: Any?) {
        apply(
            DocumentOps.squeezeBlankLines(in: editorDocument.buffer),
            label: "Nén dòng trống liên tiếp"
        )
    }

    @objc func removeBlankLines(_ sender: Any?) {
        apply(DocumentOps.removeBlankLines(in: editorDocument.buffer), label: "Xóa dòng rỗng")
    }

    @objc func tabsToSpaces(_ sender: Any?) {
        runOperation("Tab → Space") {
            try DocumentOps.tabsToSpaces(in: editorDocument.buffer, tabWidth: statusBar.state.tabWidth)
        }
    }

    @objc func spacesToTabs(_ sender: Any?) {
        runOperation("Space → Tab") {
            try DocumentOps.spacesToTabs(in: editorDocument.buffer, tabWidth: statusBar.state.tabWidth)
        }
    }

    @objc func convertToUppercase(_ sender: Any?) {
        runOperation("Chuyển HOA") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .upper)
        }
    }

    @objc func convertToLowercase(_ sender: Any?) {
        runOperation("Chuyển thường") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .lower)
        }
    }

    @objc func convertToSnakeCase(_ sender: Any?) {
        runOperation("Chuyển snake_case") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .snake)
        }
    }

    // Năm kiểu còn lại của FR-CORE-010. Lõi đã có đủ tám từ đầu; thiếu ở đây thì người dùng
    // không chạm tới được, và một tính năng không có đường vào là một tính năng không tồn tại.
    @objc func convertToTitleCase(_ sender: Any?) {
        runOperation("Chuyển Chữ Hoa Đầu Từ") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .proper)
        }
    }

    @objc func convertToSentenceCase(_ sender: Any?) {
        runOperation("Chuyển Chữ hoa đầu câu") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .sentence)
        }
    }

    @objc func invertCase(_ sender: Any?) {
        runOperation("Đảo hoa/thường") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .invert)
        }
    }

    @objc func convertToCamelCase(_ sender: Any?) {
        runOperation("Chuyển camelCase") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .camel)
        }
    }

    @objc func convertToKebabCase(_ sender: Any?) {
        runOperation("Chuyển kebab-case") {
            try DocumentOps.convertCase(in: editorDocument.buffer, to: .kebab)
        }
    }

    // MARK: - Chuẩn hóa Unicode (FR-ENC-206)

    /// NFC/NFD/NFKC/NFKD trên cả tài liệu hoặc vùng dòng đang chọn.
    ///
    /// Việc này QUAN TRỌNG với tiếng Việt hơn là với phần lớn ngôn ngữ khác: cùng một chữ "ế"
    /// có thể là một điểm mã (NFC) hay ba (NFD), hai file trông giống hệt nhau vẫn khác từng
    /// byte, và mọi phép so sánh, tìm kiếm, khử trùng lặp đều trượt mà không ai hiểu vì sao.
    @objc func normalizeUnicode(_ sender: Any?) {
        guard !editorDocument.isReadOnly else { return NSSound.beep() }
        let menu = NSMenu(title: "Chuẩn hóa Unicode")
        let forms: [(String, EncodingEngine.NormalizationForm)] = [
            ("NFC — dựng sẵn (khuyên dùng cho tiếng Việt)", .nfc),
            ("NFD — tách dấu", .nfd),
            ("NFKC — dựng sẵn, gộp cả dạng tương thích", .nfkc),
            ("NFKD — tách dấu, gộp cả dạng tương thích", .nfkd),
        ]
        for (title, form) in forms {
            let item = menu.addItem(
                withTitle: title, action: #selector(applyNormalization(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = form.rawValue
        }
        present(menu, from: sender)
    }

    @objc private func applyNormalization(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let form = EncodingEngine.NormalizationForm(rawValue: raw) else { return }
        normalizeDocument(to: form)
    }

    func normalizeDocument(to form: EncodingEngine.NormalizationForm) {
        let range = selectedLineRange()
        runOperation("Chuẩn hóa \(form.rawValue.uppercased())") {
            try DocumentOps.transformLines(in: editorDocument.buffer, lineRange: range) {
                EncodingEngine.normalize($0, to: form)
            }
        }
    }

    // MARK: - CSV

    /// Tài liệu này có nên ở chế độ CSV không.
    private var isCSVMode: Bool {
        if let csvModeOverride { return csvModeOverride }
        guard let path = editorDocument.path else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        return ["csv", "tsv", "psv", "tab"].contains(ext)
    }

    @objc func toggleCSVMode(_ sender: Any?) {
        csvModeOverride = !isCSVMode
        refreshChrome()
        findPanel.showStatus(isCSVMode
            ? "Chế độ CSV: bật · \(csvDialect.displayName)"
            : "Chế độ CSV: tắt")
    }

    /// Dấu phân tách đang dùng: người dùng chọn tay nếu có, không thì đoán từ đầu tài liệu.
    ///
    /// Phép đoán sai là lỗi im lặng nhất của cả nhóm CSV — mọi thao tác cột sau đó đều lệch mà
    /// không có gì báo. Vì thế phải có đường cho người dùng nói lại, và đường ấy là mục
    /// «CSV · …» trên thanh trạng thái.
    private var csvDialect: CSVDialect {
        if let chosen = tabs[activeIndex].csvDialectOverride { return chosen }
        let sample = editorDocument.buffer.bytes(in: 0 ..< min(editorDocument.buffer.count, 64 * 1024))
        return CSVEngine.detectDialect(sample: sample)
    }

    // MARK: - Table view (FR-CSV-403)

    /// ⌥⌘T — đổi giữa Văn bản và Bảng.
    @objc func toggleTableView(_ sender: Any?) {
        isTableViewVisible ? showTextView() : showTableView()
    }

    private var isTableViewVisible: Bool { csvTableAttached && !csvTable.isHidden }

    private func showTableView() {
        // Bảng chỉ có nghĩa với dữ liệu có cột. Bật giúp chế độ CSV thay vì báo lỗi: người
        // dùng bấm "xem dạng bảng" là đã nói rõ họ muốn gì.
        if !isCSVMode {
            csvModeOverride = true
            refreshChrome()
        }

        let buffer = editorDocument.buffer
        let dialect = csvDialect
        let caret = editorView.selectedDocumentRange.lowerBound

        csvIndexToken?.cancel()
        let token = CancelToken()
        csvIndexToken = token
        findPanel.showStatus("Đang dựng chỉ mục hàng…")

        // Dựng chỉ mục ở luồng NỀN. Một triệu hàng mất khoảng một phần ba giây (đo ở
        // `scripts/run-csv-table-kpi.sh`) — quá lâu để đứng chắn ngay lúc người dùng vừa bấm.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let index = try? CSVRowIndex.build(in: buffer, dialect: dialect, cancelToken: token)
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                // Đếm TRƯỚC mọi nhánh thoát: lượt này đã chạy xong, dù có hiện được bảng hay
                // không. Đếm ở cuối thì hai nhánh "không hiện gì" lại không đếm — đúng hai
                // nhánh mà người chờ cần biết nhất.
                self.csvTableRequests += 1
                guard let index else { return }
                guard index.rowCount > 0 else {
                    return self.findPanel.showStatus("Tài liệu rỗng — không có gì để hiện", isError: true)
                }
                self.csvIndex = index
                self.csvTable.present(buffer: buffer, index: index, dialect: dialect)
                // Giữ CHỖ ĐANG LÀM khi đổi cách nhìn. Nhảy về đầu file thì với tài liệu một
                // triệu hàng, tìm lại chỗ cũ là việc của vài phút.
                self.csvTable.select(fileRow: index.rowNumber(containingOffset: caret, in: buffer))
                self.attachCSVTable()
                self.csvTable.isHidden = false
                self.splitView.isHidden = true
                self.window?.makeFirstResponder(self.csvTable)
                // Bảng dựng chỉ mục ở luồng nền, nên nó hiện SAU cú bấm một nhịp — khung chung
                // phải được báo ở đây, không phải ở chỗ bấm. Thiếu dòng này thì công tắc vẫn
                // chỉ vào Code trong khi màn hình đã là bảng.
                self.refreshDocumentToolbar()
                self.findPanel.showStatus("Bảng: \(index.rowCount) hàng · \(index.widestRowColumnCount) cột")
            }
        }
    }

    func showTextViewPublic() { showTextView() }

    private func showTextView() {
        csvIndexToken?.cancel()
        // Con nháy về đúng hàng đang chọn ở bảng — chiều ngược lại của phép giữ chỗ ở trên.
        if let row = csvTable.selectedFileRow, let index = csvIndex,
           let offset = index.rowStart(row, in: editorDocument.buffer) {
            editorView.repaginate(around: offset)
            editorView.setCaret(documentOffset: offset)
            editorView.reveal(documentOffset: offset)
        }
        csvTable.isHidden = true
        splitView.isHidden = false
        window?.makeFirstResponder(editorView.textView)
        updateCaretStatus()
        refreshDocumentToolbar()
    }

    /// Sửa một ô ở bảng → một `TextEdit` trên chính buffer (FR-CSV-403).
    private func applyCellEdit(row: Int, column: Int, value: String) {
        guard let index = csvIndex else { return }
        let buffer = editorDocument.buffer
        let fields = index.fields(ofRow: row, in: buffer)
        guard column < fields.count else {
            return findPanel.showStatus("Hàng \(row + 1) không có cột \(column + 1)", isError: true)
        }

        // Bọc lại khi cần: giá trị chứa dấu phân tách, dấu ngoặc kép hay xuống dòng mà ghi
        // thẳng vào văn bản sẽ tách thành nhiều cột và làm lệch toàn bộ hàng.
        //
        // Đi qua `apply` như mọi thao tác khác, không tự gọi `applyEdits`: ở đó có chốt chặn
        // tài liệu chỉ-đọc. Sửa ô mà bỏ qua chốt ấy thì bảng thành đường vòng ghi được vào
        // file mà chế độ văn bản từ chối ghi.
        let escaped = CSVEngine.escape(value, dialect: index.dialect)
        apply(
            [TextEdit(range: fields[column].range, text: escaped)],
            label: "Sửa ô hàng \(row + 1) cột \(column + 1)"
        )
        rebuildCSVIndexAfterEdit()
    }

    /// Ghi thứ tự đang hiển thị vào văn bản — MỘT bước undo (FR-CORE-004).
    private func applySortToFile(_ order: CSVSort.Order) {
        guard let index = csvIndex else { return }
        let buffer = editorDocument.buffer
        do {
            let edits = try CSVSort.applyEdits(order, hasHeader: true, index: index, in: buffer)
            guard !edits.isEmpty else { return }
            apply(edits, label: "Áp sắp xếp vào file")
            rebuildCSVIndexAfterEdit()
            findPanel.showStatus("Đã ghi thứ tự vào văn bản — hoàn tác được bằng một bước")
        } catch {
            presentError("Không ghi được thứ tự", error)
        }
    }

    /// Thao tác cột phát ra từ menu ngữ cảnh của hàng tiêu đề (FR-CSV-404/408).
    ///
    /// Bốn lệnh này SỬA FILE, nên tất cả đi qua `apply` — một bước undo cho mỗi lệnh, và chốt
    /// chặn tài liệu chỉ-đọc. Lệnh "ẩn cột" không có ở đây vì nó không đụng vào file.
    private func runColumnCommand(_ command: CSVTableView.ColumnCommand) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect

        do {
            switch command {
            case let .rename(column):
                guard let name = askForText(
                    title: "Đổi tên cột \(column + 1)",
                    message: "Tên mới cho cột ở hàng tiêu đề.",
                    placeholder: "ten_cot"
                ), !name.isEmpty else { return }
                apply(
                    try CSVOps.renameHeader(column, to: name, in: buffer, dialect: dialect),
                    label: "Đổi tên cột \(column + 1)"
                )

            case let .insertLeft(column):
                apply(
                    try CSVOps.insertColumn(at: column, in: buffer, dialect: dialect),
                    label: "Chèn cột trước cột \(column + 1)"
                )

            case let .insertRight(column):
                apply(
                    try CSVOps.insertColumn(at: column + 1, in: buffer, dialect: dialect),
                    label: "Chèn cột sau cột \(column + 1)"
                )

            case let .delete(column):
                // Hỏi lại trước khi xóa: đây là lệnh duy nhất trong menu ấy làm mất dữ liệu,
                // và nó chạy trên MỌI hàng của file.
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Xóa cột \(column + 1) khỏi file?"
                alert.informativeText =
                    "Cột này sẽ bị xóa ở mọi hàng. Hoàn tác được bằng một bước ⌘Z. "
                    + "Nếu chỉ muốn tạm giấu nó đi thì dùng «Ẩn cột này»."
                alert.addButton(withTitle: "Xóa cột")
                alert.addButton(withTitle: "Hủy")
                guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
                apply(
                    try CSVOps.deleteColumn(column, in: buffer, dialect: dialect),
                    label: "Xóa cột \(column + 1)"
                )

            case let .move(from, to):
                apply(
                    try CSVOps.moveColumn(from: from, to: to, in: buffer, dialect: dialect),
                    label: "Chuyển cột \(from + 1) tới vị trí \(to + 1)"
                )
            }
        } catch {
            return presentError("Không thực hiện được thao tác cột", error)
        }

        rebuildCSVIndexAfterEdit()
    }

    /// Dựng lại chỉ mục sau khi buffer đổi, rồi nạp lại bảng.
    ///
    /// Đồng bộ, không chạy nền: sau một lần sửa ô, bảng phải hiện ngay giá trị mới. Với tài
    /// liệu rất lớn thì đây là chỗ đáng chuyển sang cập nhật tăng dần — ghi ra đây để lần sau
    /// không phải đi tìm lại.
    private func rebuildCSVIndexAfterEdit() {
        let buffer = editorDocument.buffer
        guard let index = try? CSVRowIndex.build(in: buffer, dialect: csvDialect) else { return }
        csvIndex = index
        let selected = csvTable.selectedFileRow
        csvTable.present(buffer: buffer, index: index, dialect: csvDialect)
        if let selected { csvTable.select(fileRow: selected) }
    }

    @objc func deleteCSVColumn(_ sender: Any?) {
        guard let text = askForText(
            title: "Xóa cột CSV", message: "Số thứ tự cột, đếm từ 1.", placeholder: "3"
        ), let column = Int(text), column >= 1 else { return }

        runOperation("Xóa cột \(column)") {
            try CSVOps.deleteColumn(column - 1, in: editorDocument.buffer, dialect: csvDialect)
        }
    }

    /// Kiểm tra dữ liệu: số cột và kiểu theo cột (FR-CSV-405).
    ///
    /// Chạy ở luồng NỀN và trả kết quả vào một panel bấm được. Bản trước chạy thẳng trên luồng
    /// chính rồi đổ vào một hộp thoại: với file lớn thì ứng dụng đứng hình, và sau khi bấm OK
    /// thì danh sách biến mất — người dùng phải nhớ thuộc lòng số dòng rồi tự đi tìm.
    @objc func validateCSV(_ sender: Any?) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        guard buffer.count > 0 else {
            // Đếm cả nhánh KHÔNG làm gì: người chờ cần biết "lượt này đã xong", không phải
            // "panel đã hiện". Xem `validationRequests`.
            validationRequests += 1
            return findPanel.showStatus("Tài liệu rỗng — không có gì để kiểm", isError: true)
        }

        validationToken?.cancel()
        let token = CancelToken()
        validationToken = token
        findPanel.showStatus("Đang kiểm tra dữ liệu…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let report = try? CSVValidator.validate(
                in: buffer, dialect: dialect, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                self.validationRequests += 1
                guard let report else { return }
                self.showValidationPanel(report, buffer: buffer, dialect: dialect)
            }
        }
    }

    private func showValidationPanel(
        _ report: CSVValidationReport, buffer: TextBuffer, dialect: CSVDialect
    ) {
        var names: [String] = []
        if let index = csvIndex ?? (try? CSVRowIndex.build(in: buffer, dialect: dialect)) {
            names = index.rowCount > 0 ? index.values(ofRow: 0, in: buffer) : []
        }
        validationPanel.present(report, columnNames: names)
        attachValidationPanel()
        validationHeight.constant = panelOpenHeight(.validation)
        validationPanel.isHidden = false

        // Ô sai kiểu được tô đỏ ngay trên bảng — danh sách nói "hàng 1204 cột 5", còn màu nói
        // "chỗ này đây" khi người dùng đã ở đúng hàng ấy.
        var byRow: [Int: Set<Int>] = [:]
        for issue in report.issues {
            if case let .wrongType(column, _, _) = issue.kind {
                byRow[issue.rowIndex, default: []].insert(column)
            }
        }
        csvTable.typeIssues = byRow
        findPanel.showStatus(
            report.issues.isEmpty
                ? "Không tìm thấy lỗi trong \(report.rowsChecked) hàng"
                : "Tìm thấy \(report.issues.count) lỗi"
        )
    }

    private func hideValidationPanel() {
        validationToken?.cancel()
        validationHeight?.constant = 0
        validationPanel.isHidden = true
        csvTable.typeIssues = [:]
    }

    /// Đưa màn hình tới một lỗi — ở bảng thì chọn hàng, ở văn bản thì đưa con nháy tới.
    private func revealIssue(_ issue: CSVIssue) {
        if isTableViewVisible {
            csvTable.select(fileRow: issue.rowIndex)
        } else {
            editorView.repaginate(around: issue.offset)
            editorView.setCaret(documentOffset: issue.offset)
            editorView.reveal(documentOffset: issue.offset)
            updateCaretStatus()
        }
    }

    /// Mở tập dòng khớp bộ lọc thành TAB MỚI (FR-QRY-002, NFR-QRY-03).
    ///
    /// Ra tab mới chứ không sửa tài liệu: lọc là cách nhìn, và mọi kết quả truy vấn đều đi vào
    /// chỗ mới. File nguồn không bị chạm dù chỉ một byte.
    private func exportFilteredRows(_ rows: [Int]) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        guard !rows.isEmpty else { return }

        findPanel.showStatus("Đang trích \(rows.count) dòng khớp…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let text = try? CSVFilter.extract(rows: rows, from: buffer, dialect: dialect)
            DispatchQueue.main.async {
                guard let self, let text else { return }
                self.openTextInNewTab(text, label: "Dòng khớp bộ lọc")
                self.findPanel.showStatus("Đã mở \(rows.count) dòng khớp thành tab mới (chưa lưu)")
            }
        }
    }

    // MARK: - Bàn làm sạch dữ liệu (FR-CLN-006)

    // MARK: - Tự hoàn thành (FR-CORE-013)

    /// Cập nhật danh sách gợi ý sau mỗi nhịp gõ.
    ///
    /// Chạy ĐỒNG BỘ trên luồng chính: cửa sổ quét chỉ một megabyte quanh con nháy và phép khớp
    /// mờ chạy trên vài nghìn từ, nên nó ở mức micro-giây. Đẩy sang luồng nền sẽ đổi lấy một
    /// danh sách đến CHẬM hơn phím tiếp theo — và một gợi ý hiện ra sau khi người dùng đã gõ
    /// tiếp thì tệ hơn không có gợi ý nào.
    private func refreshCompletion() {
        guard completionEnabled, !editorDocument.isReadOnly else { return completionPopup.hide() }
        let buffer = editorDocument.buffer
        let caret = editorView.selectedDocumentRange
        guard caret.isEmpty else { return completionPopup.hide() }

        let query = CompletionEngine.prefix(in: buffer, before: caret.lowerBound)
        let candidates = CompletionEngine.suggestions(
            prefix: query, in: buffer, around: caret.lowerBound,
            symbols: completionSymbols
        )
        guard !candidates.isEmpty, let origin = editorView.caretScreenOrigin else {
            return completionPopup.hide()
        }
        completionPopup.show(candidates, at: origin, parent: window)
    }

    /// Tên hàm/lớp của tài liệu, lấy từ Function List nếu nó đã dựng.
    ///
    /// Không tự dựng ở đây: phân tích cả tài liệu sau mỗi phím gõ là việc không đời nào làm
    /// nổi. Sidebar mở thì gợi ý giàu hơn; sidebar đóng thì vẫn còn từ trong tài liệu.
    private var completionSymbols: [String] {
        var out = isSidebarVisible ? functionList.namesForSelfTest : []
        // Con nháy đang trong một sơ đồ thì từ khoá Mermaid và TÊN NODE đã khai lên trước
        // (FR-MMD-005). Đứng trước vì `CompletionEngine` giữ thứ tự khi điểm bằng nhau, và
        // giữa một sơ đồ thì `participant` đáng hiện trên một tên hàm Swift của tệp khác.
        if let source = mermaidSourceAtCaret() {
            out = MermaidLibrary.completionWords(in: source) + out
        }
        return out
    }

    /// Mã sơ đồ chứa con nháy, hoặc `nil` nếu con nháy không nằm trong sơ đồ nào.
    ///
    /// ## Có TRẦN CỠ, và trần ấy là lý do hàm này an toàn để gọi mỗi phím gõ
    ///
    /// Tìm khối là một lượt quét cả tài liệu. Trên tệp một gigabyte, làm việc ấy sau mỗi phím
    /// là đúng thứ mà `CompletionEngine.defaultWindow` sinh ra để tránh — nên dùng chung đúng
    /// con số ấy làm trần. Tệp lớn hơn thì rơi về danh sách khối của lần dựng preview gần nhất:
    /// vẫn đúng khi người dùng đang mở Mermaid Studio, và không có gì khi họ không mở — mất một
    /// tiện nghi, không mất tính đúng.
    private func mermaidSourceAtCaret() -> String? {
        let buffer = editorDocument.buffer
        // KẸP vị trí con nháy vào phạm vi buffer trước khi hỏi số dòng.
        //
        // `lineNumber(atOffset:)` có `precondition`, nên một vị trí cũ là một cú SẬP chứ không
        // phải một kết quả sai — và vị trí cũ xảy ra thật: định dạng lại cả tệp làm nó NGẮN đi,
        // và mọi thứ đọc con nháy trước khi view kịp đồng bộ đều thấy số cũ. Bài tự kiểm
        // FR-MMD-006 bắt được đúng cú ấy.
        let caret = min(max(0, editorView.selectedDocumentRange.lowerBound), buffer.count)
        let caretLine = buffer.lineNumber(atOffset: caret)
        if (editorDocument.path ?? "").hasSuffix("." + MermaidDocument.fileExtension) {
            return buffer.count <= CompletionEngine.defaultWindow ? buffer.text : nil
        }
        let blocks = buffer.count <= CompletionEngine.defaultWindow
            ? MermaidDocument.blocks(in: buffer.text)
            : mermaidBlocks
        for block in blocks {
            let lineCount = block.source.isEmpty
                ? 0 : block.source.components(separatedBy: "\n").count
            if caretLine >= block.firstContentLine,
               caretLine < block.firstContentLine + max(1, lineCount) {
                return block.source
            }
        }
        return nil
    }

    /// Thay từ đang gõ dở bằng gợi ý đã chọn — MỘT bước undo.
    private func insertCompletion(_ candidate: CompletionCandidate) {
        let buffer = editorDocument.buffer
        let caret = editorView.selectedDocumentRange.lowerBound
        let query = CompletionEngine.prefix(in: buffer, before: caret)
        let start = caret - query.utf8.count
        guard start >= 0 else { return }

        apply(
            [TextEdit(range: start ..< caret, text: candidate.word)],
            label: "Tự hoàn thành «\(candidate.word)»"
        )
        editorView.setCaret(documentOffset: start + candidate.word.utf8.count)
        updateCaretStatus()
    }

    // MARK: - Công cụ JSON và YAML (FR-FMT-504, FR-FMT-507)

    @objc func formatJSON(_ sender: Any?) { runJSONTool { JSONTool.format($0) } }
    @objc func minifyJSON(_ sender: Any?) { runJSONTool { JSONTool.minify($0) } }
    @objc func sortJSONKeys(_ sender: Any?) { runJSONTool { JSONTool.sortKeys($0) } }

    /// Chạy một phép biến đổi JSON lên cả tài liệu, thành MỘT bước undo.
    ///
    /// File hỏng cú pháp thì KHÔNG đụng vào gì và đưa con nháy tới đúng chỗ lỗi: người bấm nút
    /// "Định dạng" trên một file hỏng đang cần biết hỏng ở đâu, chứ không cần một hộp thoại
    /// nói "thất bại".
    private func runJSONTool(_ body: (String) -> JSONTool.Outcome) {
        let buffer = editorDocument.buffer
        guard buffer.count > 0 else { return }
        guard buffer.count <= JSONToolSizeLimit else {
            return showTransient(
                "File lớn hơn \(JSONToolSizeLimit / 1024 / 1024) MB — công cụ JSON cần đọc cả file vào bộ nhớ"
            )
        }

        switch body(buffer.text) {
        case let .changed(out):
            apply([TextEdit(range: 0 ..< buffer.count, text: out)], label: "Công cụ JSON")
            showTransient("Đã định dạng lại JSON")
        case .unchanged:
            showTransient("JSON đã đúng dạng — không có gì để đổi")
        case let .invalid(issue):
            revealOffset(issue.offset)
            showTransient("⚠ " + issue.description)
        }
    }

    /// Trần kích thước cho công cụ JSON.
    ///
    /// Khác với tô màu hay Table view (đọc theo cửa sổ), phép định dạng phải dựng CẢ cây trong
    /// bộ nhớ rồi viết lại cả file. Trên file hàng trăm MB thì đó là vài lần kích thước file
    /// trong RAM — nói thẳng là không làm thì trung thực hơn là để ứng dụng chết giữa chừng.
    private var JSONToolSizeLimit: Int { 64 * 1024 * 1024 }

    // MARK: - Công cụ XML (FR-FMT-505)

    @objc func formatXML(_ sender: Any?) { runXMLTool { XMLTool.format($0) } }
    @objc func minifyXML(_ sender: Any?) { runXMLTool { XMLTool.minify($0) } }

    /// Kiểm well-formed và đưa con nháy tới chỗ sai đầu tiên.
    @objc func validateXML(_ sender: Any?) {
        let buffer = editorDocument.buffer
        guard buffer.count > 0 else { return }
        guard let issue = XMLTool.validate(buffer.text) else {
            return showTransient("XML well-formed — không có lỗi cú pháp")
        }
        revealOffset(issue.offset)
        showTransient("⚠ " + issue.description)
    }

    /// Đánh giá một biểu thức XPath trên tài liệu đang mở (FR-FMT-505).
    @objc func evaluateXPath(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = L("Đánh giá XPath")
        alert.informativeText = L("Ví dụ: //don_hang/hang[2]/@ma · //*[@loai='A'] · count(//hang)")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "//hang/@ma"
        alert.accessoryView = field
        alert.addButton(withTitle: L("Đánh giá"))
        alert.addButton(withTitle: "Hủy")
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        evaluateXPathForSelfTest(field.stringValue)
    }

    /// Phần LÀM VIỆC của `evaluateXPath` — xem `playMacroOnFolderForSelfTest` về vì sao tách.
    @discardableResult
    func evaluateXPathForSelfTest(_ query: String) -> Bool {
        let text = editorDocument.buffer.text
        switch XMLTool.evaluateXPath(query, in: text) {
        case .invalidDocument(let issue):
            revealOffset(issue.offset)
            showTransient("⚠ " + issue.description)
            return false
        case .badQuery(let message):
            // Nói ra nguyên văn lời của bộ đánh giá, không dịch lại thành "biểu thức sai": lỗi
            // XPath thường chỉ đúng ký tự hỏng, và đó là thứ người dùng cần.
            showTransient(LF("XPath không đọc được: %@", message))
            return false
        case .nodes(let nodes):
            guard !nodes.isEmpty else {
                showTransient(LF("XPath «%@» không khớp node nào", query))
                return true
            }
            // Kết quả ra TAB MỚI, cùng lối với kết quả tìm và báo cáo macro. Không nhảy tới
            // được vị trí trong tài liệu gốc — `XMLDocument` không giữ offset, và điều đó được
            // nói thẳng trong `XMLTool.evaluateXPath` cùng trong sách trợ giúp.
            openTextInNewTab(
                nodes.joined(separator: "\n") + "\n",
                label: LF("XPath «%@» — %d node", query, nodes.count))
            showTransient(LF("XPath «%@»: %d node", query, nodes.count))
            return true
        }
    }

    /// Kiểm theo DTD nội tuyến hoặc theo một lược đồ XSD người dùng chọn (FR-FMT-505).
    ///
    /// **Một mục menu, hai đường** — vì với người dùng thì "file này có đúng chuẩn không" là
    /// một câu hỏi, không phải hai. Có `<!DOCTYPE` trong file thì kiểm DTD ngay; không có thì
    /// hỏi lược đồ XSD.
    ///
    /// DTD chỉ nhận loại NỘI TUYẾN — xem `XMLSchemaValidator.validateAgainstInlineDTD`: một
    /// `<!DOCTYPE … SYSTEM "http://…">` sẽ khiến trình phân tích đi tải file ấy về, tức là một
    /// lời gọi mạng do NỘI DUNG FILE quyết định.
    @objc func validateXMLAgainstSchema(_ sender: Any?) {
        let text = editorDocument.buffer.text
        guard !text.isEmpty else { return }

        if text.contains("<!DOCTYPE") {
            return reportSchemaOutcome(
                XMLSchemaValidator.validateAgainstInlineDTD(text), what: "DTD")
        }

        guard XMLSchemaValidator.isXSDAvailable else {
            return showBanner(
                L("Máy này không có libxml2 nên không kiểm được XSD."),
                actionTitle: nil, action: nil)
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.message = L("Chọn lược đồ XSD để kiểm")
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url,
              let schema = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        reportSchemaOutcome(
            XMLSchemaValidator.validate(text, againstXSD: schema),
            what: "XSD (libxml2 \(XMLSchemaValidator.libraryVersion ?? "?"))")
    }

    /// Hiện kết quả, và **nhảy tới lỗi đầu tiên** — một danh sách lỗi có số dòng mà không bấm
    /// được thì người dùng vẫn phải tự đi tìm.
    ///
    /// Nói rõ ĐANG KIỂM THEO GÌ trong mọi câu trả lời, kèm phiên bản libxml2 khi là XSD: đây là
    /// thư viện của HỆ THỐNG, nên hai máy hai bản macOS có thể cho verdict khác nhau ở những góc
    /// hiếm, và con số ấy là thứ đầu tiên cần so khi hai người không đồng ý với nhau.
    private func reportSchemaOutcome(_ outcome: XMLSchemaValidator.Outcome, what: String) {
        switch outcome {
        case .valid:
            showTransient("✓ " + L("Hợp lệ theo") + " \(what)")
        case let .unavailable(reason):
            showBanner(reason, actionTitle: nil, action: nil)
        case let .invalid(issues):
            if let line = issues.compactMap(\.line).first, line >= 1 {
                let offset = editorDocument.buffer.offset(
                    ofLineStart: min(line - 1, max(editorDocument.buffer.lineCount - 1, 0)))
                revealOffset(offset)
            }
            let first = issues.first?.describedForUser ?? ""
            let more = issues.count > 1 ? " (+\(issues.count - 1))" : ""
            showBanner("⚠ \(what): \(first)\(more)", actionTitle: nil, action: nil)
        }
    }

    /// Chạy một phép biến đổi XML lên cả tài liệu, thành MỘT bước undo.
    ///
    /// Cùng luật với `runJSONTool`, và cố ý giống: hai công cụ đứng cạnh nhau trong menu nên
    /// chúng phải cư xử như nhau. File hỏng thì KHÔNG đụng vào gì và đưa con nháy tới chỗ lỗi.
    private func runXMLTool(_ body: (String) -> XMLTool.Outcome) {
        let buffer = editorDocument.buffer
        guard buffer.count > 0 else { return }
        guard buffer.count <= JSONToolSizeLimit else {
            return showTransient(
                "File lớn hơn \(JSONToolSizeLimit / 1024 / 1024) MB — công cụ XML cần đọc cả file vào bộ nhớ"
            )
        }

        switch body(buffer.text) {
        case let .changed(out):
            apply([TextEdit(range: 0 ..< buffer.count, text: out)], label: "Công cụ XML")
            showTransient("Đã định dạng lại XML")
        case .unchanged:
            showTransient("XML đã đúng dạng — không có gì để đổi")
        case let .invalid(issue):
            revealOffset(issue.offset)
            showTransient("⚠ " + issue.description)
        }
    }

    /// Kiểm YAML: khóa trùng và thụt lề sai (FR-FMT-507).
    @objc func lintYAML(_ sender: Any?) {
        let issues = YAMLLint.check(editorDocument.buffer.text)
        guard !issues.isEmpty else {
            return showTransient("YAML không có khóa trùng hay thụt lề lạ")
        }
        lastYAMLIssues = issues
        revealOffset(issues[0].offset)
        showTransient("⚠ \(issues.count) cảnh báo YAML · \(issues[0].description)")
    }

    // MARK: - Bản đồ tài liệu (FR-DOC-306)

    @objc func toggleDocumentMap(_ sender: Any?) {
        attachDocumentMap()
        let showing = documentMapView.isHidden
        documentMapView.isHidden = !showing
        documentMapWidth.constant = showing ? DocumentMapView.width : 0
        if showing { refreshDocumentMap(force: true) }
    }

    var isDocumentMapVisible: Bool { documentMapAttached && !documentMapView.isHidden }

    /// Dựng lại bản đồ nếu tài liệu đã đổi, và luôn cập nhật khung tầm nhìn.
    ///
    /// Tách hai việc vì chúng khác nhau cả trăm lần về giá: dựng bản đồ tốn 5–10 ms (đo ở
    /// `geditor-bench document-map`), còn dời khung tầm nhìn thì gần như miễn phí. Cuộn một
    /// file lớn mà dựng lại bản đồ theo từng nhịp là tự tay biến việc cuộn thành giật.
    func refreshDocumentMap(force: Bool = false) {
        guard isDocumentMapVisible else { return }

        let rows = documentMapView.desiredRowCount
        let buffer = editorDocument.buffer.id
        let revision = editorDocument.buffer.revision
        // Số hàng nằm TRONG khóa nhớ tạm, không chỉ tài liệu. Thiếu nó thì bản đồ dựng lúc bố
        // cục chưa áp — đúng một hàng, vì bề cao còn 0 — sẽ được giữ lại mãi vì tài liệu có đổi
        // đâu; và ảnh ra một vệt mực cao hết view. Đó là lỗi đã mất một buổi để tìm.
        let stale = documentMapRevision.map { built in
            built.buffer != buffer || built.revision != revision
                // Lệch bề cao quá 1/8 mới dựng lại: giữa hai lần dựng, bản đồ vẫn vẽ đúng tỉ lệ
                // (chỉ thô hơn), còn dựng lại theo từng điểm ảnh của một cú kéo cửa sổ là trả
                // 5–10 ms mỗi khung hình cho thứ mắt không phân biệt được.
                || abs(built.rows - rows) * 8 > rows
        } ?? true

        if force || stale {
            documentMapRevision = (buffer, revision, rows)
            documentMapView.present(DocumentMap(buffer: editorDocument.buffer, rowCount: rows))
        }
        documentMapView.setVisibleLines(editorView.visibleLineRange)
        documentMapView.setMarkedLines(markedLineColors())
    }

    /// Dòng nào đang có dấu, và màu nào — dạng bản đồ cần.
    private func markedLineColors() -> [Int: Int] {
        var out: [Int: Int] = [:]
        for line in marks.union.lines {
            if let color = marks.displayColor(at: line) { out[line] = color }
        }
        return out
    }

    // MARK: - Gấp mã (FR-CORE code folding · FR-FMT-507)

    /// Gấp hoặc mở khối chứa con nháy (⌥⌘←).
    @objc func toggleFold(_ sender: Any?) {
        let buffer = editorDocument.buffer
        let caret = editorView.selectedDocumentRange.lowerBound

        // Nếu con nháy đang ở dòng đầu của một vùng ĐANG gấp thì mở nó ra, kể cả khi phép tính
        // lại không còn sinh ra đúng vùng ấy nữa (tài liệu đã sửa từ lúc gấp).
        let caretLine = buffer.lineNumber(atOffset: caret)
        if let open = editorView.activeFold(headerLine: caretLine) {
            setFolds(editorView.activeFolds.filter { $0.hiddenBytes != open.hiddenBytes })
            return
        }

        let available = FoldRanges.compute(in: buffer, language: editorView.syntaxLanguage)
        guard !available.isEmpty else {
            return showTransient(foldUnavailableMessage())
        }
        // Khối TRONG CÙNG chứa con nháy: người dùng gấp thứ họ đang đứng trong, không phải cả
        // file. Chọn vùng có dòng đầu lớn nhất mà vẫn bao con nháy.
        guard let target = available
            .filter({ $0.headerLine <= caretLine && caretLine <= $0.lastLine })
            .max(by: { $0.headerLine < $1.headerLine })
        else {
            return showTransient("Dòng này không nằm trong khối nào gấp được")
        }
        setFolds(editorView.activeFolds + [target])
    }

    /// Gấp mọi khối cấp cao nhất (⌥⇧⌘←).
    @objc func foldAll(_ sender: Any?) {
        let available = foldRangesIncludingFrontmatter()
        guard !available.isEmpty else { return showTransient(foldUnavailableMessage()) }
        // Chỉ khối NGOÀI CÙNG: gấp cả khối lồng bên trong thì mở ra phải bấm hai lần cho mỗi
        // khối, mà phần bị giấu thì y hệt.
        let outermost = FoldRanges.outermost(in: available)
        setFolds(outermost)
        showTransient("Đã gấp \(outermost.count) khối")
    }

    /// Gấp mọi khối ở ĐÚNG một cấp lồng — vế thứ ba của FR-FMT-503 (⌥⌘1…⌥⌘8).
    ///
    /// Cấp lấy từ `tag` của mục menu. Đọc `tag` chứ không phân tích nhan đề: nhan đề đi qua
    /// `L()` nên nó đổi theo ngôn ngữ giao diện, và một lệnh hỏng khi người dùng chuyển sang
    /// tiếng Anh là loại lỗi không ai gặp trong lúc phát triển.
    @objc func foldToLevel(_ sender: Any?) {
        guard let level = (sender as? NSMenuItem)?.tag, level >= 1 else { return }
        let available = foldRangesIncludingFrontmatter()
        guard !available.isEmpty else { return showTransient(foldUnavailableMessage()) }

        let target = FoldRanges.ranges(atLevel: level, in: available)
        guard !target.isEmpty else {
            // NÓI RA thay vì im lặng không làm gì. Tài liệu chỉ sâu 2 cấp mà người dùng bấm cấp
            // 5 thì màn hình không đổi, và một lệnh không đổi gì trông y hệt một lệnh hỏng.
            let depth = FoldRanges.levelCount(of: available)
            return showTransient(depth == 0
                ? foldUnavailableMessage()
                : LF("Tài liệu này chỉ sâu %d cấp", depth))
        }
        // Gấp cấp N thay thế hẳn trạng thái đang gấp chứ không cộng dồn: người dùng bấm cấp 1
        // rồi cấp 2 là đang ĐỔI CÁCH NHÌN, không phải gấp thêm.
        setFolds(target)
        showTransient(LF("Đã gấp %d khối ở cấp %d", target.count, level))
    }

    /// Mở lại tất cả (⌥⌘→).
    @objc func unfoldAll(_ sender: Any?) {
        guard !editorView.activeFolds.isEmpty else { return }
        setFolds([])
    }

    private func setFolds(_ folds: [FoldRange]) {
        editorView.setFolds(folds, caretAt: editorView.selectedDocumentRange.lowerBound)
        updateCaretStatus()
    }

    /// Báo một câu ngắn rồi tự tắt.
    ///
    /// Dùng banner chứ KHÔNG dùng `findPanel.showStatus`: bảng Tìm chỉ hiện khi người dùng mở
    /// nó, nên một thông báo gửi vào đó lúc bảng đang đóng là gửi vào hư không.
    ///
    /// Mọi công cụ JSON/XML/YAML đã chuyển sang đây. Còn sót vài chỗ khác (`exportFilteredRows`,
    /// trạng thái lọc CSV) vẫn nói qua bảng Tìm — chúng chỉ chạy khi người dùng đang mở bảng
    /// hoặc đang ở Table view, nên tạm chấp nhận được; rà nốt là một việc riêng.
    var lastTransientForSelfTest: String { lastTransient }

    private func showTransient(_ message: String) {
        lastTransient = message
        showBannerPublic(message, actionTitle: nil, action: nil)
        transientBannerToken += 1
        let token = transientBannerToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.transientBannerToken == token else { return }
            self.hideBannerPublic()
        }
    }

    /// Vì sao không gấp được — nói ra tên ngôn ngữ, đừng để người dùng bấm phím rồi không thấy gì.
    private func foldUnavailableMessage() -> String {
        guard let language = editorView.syntaxLanguage else {
            return "Chưa nhận ra ngôn ngữ nên chưa biết gấp theo gì"
        }
        if editorDocument.buffer.count > FoldRanges.sizeLimit {
            return "File lớn hơn \(FoldRanges.sizeLimit / 1024 / 1024) MB — không tính vùng gấp"
        }
        // Tới đây nghĩa là ngôn ngữ có nhận ra nhưng KHÔNG sinh ra vùng gấp nào. Với ngôn ngữ
        // đi qua cây cú pháp thì đó thường là file quá ngắn hoặc mọi khối nằm gọn một dòng —
        // nói đúng thứ ấy chứ đừng đổ cho "chưa hỗ trợ".
        return "Không có khối nào gấp được trong file \(language.displayName) này"
    }

    // MARK: - Móc tự kiểm gấp mã

    var activeBookmarkForSelfTest: Data? { editorDocument.accessBookmark }
    var workspaceRootForSelfTest: String? { workspaceRoot }

    /// Đóng workspace và thả quyền — để bài kiểm dựng lại từ trạng thái sạch.
    func closeWorkspaceForSelfTest() {
        if let access = workspaceAccess { SandboxAccess.end(access) }
        workspaceAccess = nil
        workspaceRoot = nil
        workspaceBookmark = nil
    }
    var sessionWorkspaceForSelfTest: (path: String?, hasBookmark: Bool) {
        let window = currentSession.windows.first
        return (window?.workspacePath, window?.workspaceBookmark != nil)
    }

    /// Nhận một tài liệu đã mở sẵn vào tab hiện tại — để bài kiểm giữ được vòng đời tài liệu.
    func adoptDocumentForSelfTest(_ document: Document) { loadDocument(document) }

    /// Phiên hiện tại có mang theo bookmark cho từng tab đã lưu file không.
    var sessionBookmarksForSelfTest: [Bool] {
        currentSession.windows.first?.tabs.map { $0.bookmark != nil } ?? []
    }

    var foldedHeaderLinesForSelfTest: [Int] { editorView.activeFolds.map(\.headerLine).sorted() }
    var visibleWindowTextForSelfTest: String { editorView.textWindow.text }
    var bannerMessageForSelfTest: String { banner.messageForSelfTest }
    var foldMarkerRectsForSelfTest: [NSRect] { editorView.foldMarkerRectsForSelfTest }

    // MARK: - Truy vấn JSONPath (FR-FMT-504)

    // MARK: - BM25 Retrieval Lab (FR-KNW-918, FR-KNW-919)

    @objc func showRetrievalPanel(_ sender: Any?) {
        // Gắn panel vào corpus ĐANG MỞ, một lần, ngay lúc mở.
        //
        // Từ đây mọi lệnh của panel dùng corpus ấy chứ không dùng tài liệu đang hoạt động —
        // chính panel này xuất báo cáo và gói ngữ cảnh ra tab mới, nên "tài liệu đang hoạt
        // động" đổi ngay sau lệnh đầu tiên. Mở panel trên một corpus KHÁC thì bỏ hết trạng thái
        // cũ: chỉ mục, đồ thị và ánh xạ đều thuộc về corpus trước.
        if retrievalBoundCorpus != editorDocument.path {
            retrievalBoundCorpus = editorDocument.path
            retrievalIndex = nil
            hybridGraph = nil
            hybridDictionary = nil
            hybridGraphCorpus = nil
            isHybridOn = false
            goldenBuilder = nil
        }
        attachRetrievalPanel()
        retrievalPanel.isHidden = false
        retrievalHeight.constant = panelOpenHeight(.retrieval)
        retrievalPanel.focusField()
        prepareRetrievalIndex()
    }

    private func hideRetrievalPanel() {
        retrievalPanel.isHidden = true
        retrievalHeight?.constant = 0
    }

    var isRetrievalPanelVisible: Bool { isAttached(.retrieval) && !retrievalPanel.isHidden }

    /// Mở (hoặc dựng) chỉ mục cho corpus đang mở.
    ///
    /// Chỉ mục nằm CẠNH corpus và tự vô hiệu theo cỡ + mtime, nên mở lại một tệp đã đánh chỉ
    /// mục là gần như tức thì. Lần đầu trên một corpus lớn thì tốn — và đó là lúc thanh tiến độ
    /// có mặt để nói ra.
    /// Corpus mà Retrieval Lab đang làm việc trên đó.
    ///
    /// KHÔNG phải `editorDocument.path`: chính panel này xuất báo cáo và gói ngữ cảnh ra TAB
    /// MỚI, nên sau một lần xuất thì tài liệu đang hoạt động là bản xuất chứ không còn là
    /// corpus. Không có vế này thì mọi lệnh tiếp theo của panel im lặng ngừng chạy — một bài tự
    /// kiểm bắt được đúng chỗ ấy.
    var retrievalCorpusPath: String? { retrievalBoundCorpus ?? editorDocument.path }

    @discardableResult
    private func prepareRetrievalIndex(k1: Double? = nil, b: Double? = nil) -> BM25Index? {
        guard let path = retrievalCorpusPath else {
            retrievalPanel.presentUnusable(
                L("Tài liệu chưa lưu — chỉ mục BM25 nằm cạnh tệp corpus nên cần một đường dẫn"))
            return nil
        }
        // Đã dựng chỉ mục cho corpus này rồi thì khỏi ngửi lại — và quan trọng hơn, khỏi ngửi
        // NHẦM tài liệu đang hoạt động (có thể là một bản xuất vừa mở ra tab mới).
        if retrievalIndex == nil,
           !JSONLScan.looksLikeJSONL(buffer: editorDocument.buffer, path: path) {
            retrievalPanel.presentUnusable(
                L("Tệp này không phải JSONL — Retrieval Lab chạy trên corpus chunk"))
            return nil
        }
        let wantedK1 = k1 ?? retrievalPanel.k1
        let wantedB = b ?? retrievalPanel.b
        if let current = retrievalIndex, current.corpus == path,
           current.k1 == wantedK1, current.b == wantedB {
            return current.index
        }
        var options = BM25Index.Options()
        options.k1 = wantedK1
        options.b = wantedB
        // Trường văn bản lấy từ phép đoán của Chunk Inspector — nó đã đọc corpus rồi, và bắt
        // người dùng gõ lại tên trường mà công cụ vừa đoán ra là bắt làm việc thừa.
        if retrievalIndex == nil,
           let guessed = ChunkInspector.inspect(
            buffer: editorDocument.buffer, config: .init(sampleSize: 200)).textField {
            options.textField = guessed
        } else if let existing = retrievalIndex?.index.options.textField {
            options.textField = existing
        }
        retrievalPanel.presentBuilding(0)
        // NFR-KNW-01 — đóng dấu cửa vào của Knowledge Pack. Chỉ tiêu đòi *"khi Pack không cài
        // hoặc bị tắt, KPI khởi động/RAM/latency không đổi"*; ADR-15 chọn để Pack TRONG LÕI,
        // nên trạng thái "không cài" không tồn tại — thứ đo được là **Pack không tốn gì khi
        // chưa ai dùng tới nó**, và dấu này làm `--measure-startup` chứng minh được điều đó.
        LazyLoadAudit.activate("BM25Index")
        let index = try? BM25Index.open(corpus: path, options: options) { [weak self] fraction in
            self?.retrievalPanel.presentBuilding(fraction)
            RunLoop.current.run(mode: .default, before: Date())
            return true
        }
        guard let index else {
            retrievalPanel.presentUnusable(L("Không dựng được chỉ mục BM25 cho tệp này"))
            return nil
        }
        retrievalIndex = (index, path, wantedK1, wantedB)
        retrievalPanel.present(
            query: "", hits: [], texts: [], identifiers: [], highlights: [],
            elapsedMs: 0, documentCount: index.documentCount)
        return index
    }

    private func runRetrievalQuery(_ query: String) {
        guard let index = prepareRetrievalIndex() else { return }
        let started = DispatchTime.now().uptimeNanoseconds
        var hits = index.search(query, k: 10)
        var note: String?

        // --- Phép lai BM25 × đồ thị — FR-KNW-925 ---
        if isHybridOn, let graph = hybridGraph, let dictionary = hybridDictionary {
            let result = HybridRetrieval.search(
                query, k: 10, index: index, graph: graph, dictionary: dictionary,
                config: hybridConfig)
            // Giữ nguyên `matchedTerms` của BM25 để đường TÔ SÁNG không đổi: phép lai xếp lại
            // thứ tự, nó không đổi từ nào khớp.
            let terms = Dictionary(
                uniqueKeysWithValues: index.search(query, k: hybridConfig.candidateCount)
                    .map { ($0.document, $0.matchedTerms) })
            hits = result.hits.map {
                BM25Index.Hit(document: $0.document, score: $0.score,
                              matchedTerms: terms[$0.document] ?? [])
            }
            note = LF("lai %.1f ms · %@", result.rerankMilliseconds,
                          result.methodology)
        }

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        var texts: [String] = []
        var identifiers: [String] = []
        var highlights: [[Range<Int>]] = []
        for hit in hits {
            let text = index.text(of: hit.document) ?? ""
            texts.append(text)
            highlights.append(index.highlights(in: text, terms: hit.matchedTerms))
            identifiers.append(identifier(of: hit.document, in: index))
        }
        retrievalPanel.present(
            query: query, hits: hits, texts: texts, identifiers: identifiers,
            highlights: highlights, elapsedMs: elapsed, documentCount: index.documentCount)
        if let note { retrievalPanel.presentCoverage(note) }
    }

    // MARK: - Liên kết Chunk ↔ Entity ↔ Graph (FR-KNW-920)

    /// Ánh xạ ba chiều đã dựng, kèm corpus nó thuộc về.
    ///
    /// Giữ lại giữa hai lệnh vì cả phân tích phủ lẫn xuất gói ngữ cảnh đều dùng nó, và dựng nó
    /// là một lượt quét TOÀN corpus — trả hai lần cho một việc là điều đáng tránh nhất ở đây.
    private static var graphLinksCache:
        (corpus: String, links: ContextPackage.Links)?

    func runGraphRAG(_ action: RetrievalPanel.GraphRAGAction) {
        guard action != .none else { return }
        guard let index = prepareRetrievalIndex() else { return }
        // Dùng chung đúng đồ thị mà phép lai dùng — cùng quy ước `<corpus>.dot`.
        setHybridRetrieval(enabled: true, alpha: hybridConfig.alpha)
        guard let graph = hybridGraph, let dictionary = hybridDictionary,
              let corpus = retrievalCorpusPath else { return }

        let links: ContextPackage.Links
        if let cached = MainWindowController.graphLinksCache, cached.corpus == corpus {
            links = cached.links
        } else {
            let token = CancelToken()
            guard let built = try? ContextPackage.link(
                index: index, graph: graph, dictionary: dictionary, cancelToken: token,
                progress: { [weak self] fraction in
                    self?.retrievalPanel.presentBuilding(fraction)
                    RunLoop.current.run(mode: .default, before: Date())
                    return true
                }) else {
                return retrievalPanel.presentUnusable(L("Không dựng được ánh xạ Chunk ↔ Entity"))
            }
            links = built
            MainWindowController.graphLinksCache = (corpus, built)
        }

        switch action {
        case .none:
            return
        case .coverage:
            let coverage = ContextPackage.coverage(
                links, graph: graph, dictionary: dictionary)
            openTextInNewTab(graphRAGCoverageText(coverage), label: "phu-chunk-entity.md")
        case .contextPackage:
            // Seed = mọi node của đồ thị, mỗi node một dòng JSONL. Đó là "sản phẩm trung gian
            // chuẩn" mà đặc tả nói tới: pipeline bên ngoài lọc lấy seed nó cần, chứ không phải
            // chạy lại công cụ này cho từng seed.
            var out = ""
            for node in 0 ..< graph.nodeCount {
                let package = ContextPackage.extract(
                    seed: graph.displays[node], index: index, graph: graph,
                    dictionary: dictionary, links: links, config: .init(hops: 2))
                guard package.seedFound else { continue }
                out += ContextPackage.jsonl(package) + "\n"
            }
            openTextInNewTab(out, label: "goi-ngu-canh.jsonl")
        }
    }

    /// Báo cáo phủ dạng Markdown — đọc được, diff được, dán vào issue được.
    private func graphRAGCoverageText(_ coverage: ContextPackage.Coverage) -> String {
        var lines = ["# " + L("Phủ Chunk ↔ Entity ↔ Graph"), ""]
        lines.append(String(
            format: L("- %d entity · %d chunk · %.0f%% entity được nhắc · %.0f%% chunk có entity"),
            coverage.entityCount, coverage.chunkCount,
            coverage.mentionedRatio * 100, coverage.linkedChunkRatio * 100))
        lines.append("")
        lines.append("## " + L("Entity không chunk nào nhắc tới")
            + " (\(coverage.unmentionedEntities.count))")
        lines.append(coverage.unmentionedEntities.isEmpty
            ? "_" + L("không có") + "_"
            : coverage.unmentionedEntities.map { "- \($0)" }.joined(separator: "\n"))
        lines.append("")
        lines.append("## " + L("Chunk mồ côi (không chứa entity nào)")
            + " (\(coverage.orphanChunkCount))")
        lines.append(coverage.orphanChunks.isEmpty
            ? "_" + L("không có") + "_"
            : coverage.orphanChunks.map { "- " + L("dòng") + " \($0 + 1)" }
                .joined(separator: "\n"))
        lines.append("")
        lines.append("## " + L("Node đồ thị không có entity đối ứng")
            + " (\(coverage.unmappedNodes.count))")
        lines.append(coverage.unmappedNodes.isEmpty
            ? "_" + L("không có") + "_"
            : coverage.unmappedNodes.map { "- \($0)" }.joined(separator: "\n"))
        lines.append("")
        lines.append("## " + L("Phương pháp"))
        lines.append(coverage.methodology)
        return lines.joined(separator: "\n") + "\n"
    }

    /// Bật/tắt phép lai và chỉnh α — FR-KNW-925.
    ///
    /// Đồ thị lấy từ `<tên corpus>.dot` đặt CẠNH corpus, cùng quy ước với bộ đánh giá golden
    /// set. Không có tệp ấy thì NÓI RA — chứ không lặng lẽ chạy BM25 thuần rồi để người dùng
    /// tưởng phép lai đang hoạt động và kết luận "đồ thị chẳng giúp gì".
    func setHybridRetrieval(enabled: Bool, alpha: Double) {
        hybridConfig = HybridRetrieval.Config(alpha: alpha)
        isHybridOn = enabled
        guard enabled else { return }
        guard let corpus = retrievalCorpusPath else {
            isHybridOn = false
            return retrievalPanel.presentUnusable(
                L("Tài liệu chưa lưu — phép lai cần một tệp đồ thị đặt cạnh corpus"))
        }
        let base = (corpus as NSString).deletingPathExtension
        let path = base + ".dot"
        if hybridGraphCorpus != corpus {
            hybridGraph = nil
            hybridDictionary = nil
        }
        if hybridGraph == nil {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8),
                  DOTGraph.looksLikeDOT(text, path: path) else {
                isHybridOn = false
                return retrievalPanel.presentUnusable(String(
                    format: L("Không thấy tệp đồ thị «%@» — phép lai cần nó để có tín hiệu"),
                    (path as NSString).lastPathComponent))
            }
            let graph = GraphCSR(DOTGraph.parse(text))
            hybridGraph = graph
            hybridDictionary = HybridRetrieval.dictionary(for: graph)
            hybridGraphCorpus = corpus
        }
        let query = retrievalPanel.query.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty { runRetrievalQuery(query) }
    }

    private func identifier(of document: Int, in index: BM25Index) -> String {
        guard let line = index.record(document),
              let object = try? JSONSerialization.jsonObject(with: Data(line.utf8))
                as? [String: Any] else { return "" }
        return object[index.options.idField] as? String ?? ""
    }

    private func retuneRetrieval(k1: Double, b: Double) {
        guard prepareRetrievalIndex(k1: k1, b: b) != nil else { return }
        let query = retrievalPanel.query.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty { runRetrievalQuery(query) }
    }

    // MARK: - Golden Set Builder (FR-KNW-926)

    /// Bật/tắt chế độ gán nhãn.
    ///
    /// Bật thì nạp (hoặc tạo) bộ đánh giá đặt CẠNH corpus, và quét corpus MỘT lần để dựng bảng
    /// id → nguồn. Quét ở đây chứ không quét ở mỗi lần lưu: người dùng gán nhãn hàng chục
    /// record liên tiếp, và một lượt quét corpus cho mỗi lần bấm Lưu sẽ biến thao tác một giây
    /// thành thao tác vài giây.
    private func startLabelling(_ on: Bool) {
        guard on else { goldenBuilder = nil; return }
        guard let corpus = retrievalCorpusPath else {
            retrievalPanel.presentUnusable(
                L("Tài liệu chưa lưu — bộ đánh giá cần nằm cạnh tệp corpus"))
            return
        }
        let path = GoldenSetBuilder.defaultPath(forCorpus: corpus)
        do {
            goldenBuilder = try GoldenSetBuilder.load(path: path)
        } catch {
            retrievalPanel.presentUnusable(
                LF("Không nạp được bộ đánh giá: %@", "\(error)"))
            return
        }
        let inspection = ChunkInspector.inspect(buffer: editorDocument.buffer)
        goldenSourceMap = [:]
        goldenDeclaredSources = []
        if let identifier = inspection.schema.id,
           let sourceField = inspection.schema.metadataFields.first(where: {
               $0 != identifier && $0 != inspection.textField
           }) {
            goldenDeclaredSources = (inspection.fields.first { $0.name == sourceField }?
                .topValues.map { $0.value.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) })
                ?? []
            goldenSourceMap = ChunkInspector.map(
                buffer: editorDocument.buffer, from: identifier, to: sourceField)
        }
        refreshGoldenCoverage()
    }

    private func refreshGoldenCoverage() {
        guard let builder = goldenBuilder else { return }
        let coverage = builder.coverage(
            sourceOf: { [weak self] in self?.goldenSourceMap[$0] },
            declaredSources: goldenDeclaredSources)
        retrievalPanel.presentCoverage(builder.summary(coverage))
    }

    private func saveGoldenSetRecord(question: String, ids: [String], note: String) {
        guard var builder = goldenBuilder else { return }
        do {
            try builder.append(question: question, relevantIDs: ids, note: note)
        } catch {
            return showTransient(LF("Không lưu được: %@", "\(error)"))
        }
        goldenBuilder = builder
        retrievalPanel.clearLabelSelection()
        refreshGoldenCoverage()
    }

    private func exportGoldenSetCSV() {
        guard let builder = goldenBuilder, !builder.queries.isEmpty else {
            return showTransient(L("Bộ đánh giá chưa có record nào"))
        }
        let path = (builder.path as NSString).deletingPathExtension + ".csv"
        do {
            try AtomicFileWriter.write(Array(builder.csv().utf8), to: path)
        } catch {
            return showTransient(LF("Không ghi được: %@", "\(error)"))
        }
        openInNewTab(path: path)
    }

    // MARK: - Thuật toán đồ thị (FR-KNW-914)

    /// CSR của đồ thị đang xem, dựng MỘT lần.
    ///
    /// NFR-KNW-03: *"Adjacency dựng dạng CSR một lần, tái dùng giữa các lần chạy"*. Người dùng
    /// chạy PageRank rồi Louvain rồi k-hop trên cùng một đồ thị; dựng lại ở mỗi lần là trả ba
    /// lần cho một việc, và trên một triệu cạnh đó là 200 ms mỗi lần bấm.
    private func currentGraphCSR() -> GraphCSR? {
        LazyLoadAudit.activate("GraphCSR")
        guard let graph = dotGraph else { return nil }
        if let existing = graphCSR { return existing }
        let csr = GraphCSR(graph)
        graphCSR = csr
        return csr
    }

    func runGraphAlgorithm(_ choice: MermaidPanel.Algorithm) {
        guard let csr = currentGraphCSR() else {
            return showTransient(L("Tài liệu này không phải đồ thị DOT"))
        }
        let token = CancelToken()
        func pump(_ fraction: Double) -> Bool {
            RunLoop.current.run(mode: .default, before: Date())
            return !token.isCancelled
        }

        switch choice {
        case .none:
            return
        case .pageRank:
            let result = GraphAlgorithms.pageRank(in: csr, cancelToken: token, progress: pump)
            graphPageRank = result
            applyGraphStyles(csr)
            let top = GraphOverlay.ranking(result, in: csr, limit: 5)
                .map { "\($0.rank). \($0.name)" }.joined(separator: " · ")
            mermaidPanel.showNote(top + " — " + result.methodology)
        case .communities:
            let result = GraphAlgorithms.louvain(in: csr, cancelToken: token, progress: pump)
            graphCommunities = result
            applyGraphStyles(csr)
            mermaidPanel.showNote(result.methodology)
        case .components:
            let result = GraphAlgorithms.connectedComponents(
                in: csr, cancelToken: token, progress: pump)
            graphComponents = result
            mermaidPanel.showNote(
                LF("%d thành phần · lớn nhất %d node · %d node mồ côi",
                       result.count, result.sizes.first ?? 0, result.isolatedCount)
                + " — " + result.methodology)
        case .quality:
            runGraphQuality()
        case .resolveEntities:
            proposeEntityResolution(csr)
        case .applyResolution:
            applyEntityResolution()
        case .exportTable:
            exportGraphNodeTable(csr)
        case .renameNode:
            renameGraphNode()
        case .mergeNodes:
            mergeGraphNodes()
        case .splitNode:
            splitGraphNode()
        case .extractSubgraph:
            extractSubgraph()
        case .addNode:
            addGraphNode()
        case .addEdge:
            addGraphEdgeFromSelection()
        case .editLabel:
            editGraphLabelFromSelection()
        case .removeElement:
            removeGraphElementFromSelection()
        }
    }

    // MARK: - Soạn thảo đồ thị trực quan (FR-KNW-915)

    /// Đường ÁP duy nhất của mọi phép soạn trực quan.
    ///
    /// Khác `applyGraphRefactor` ở một điểm có chủ ý: **không hỏi**. FR-KNW-916 sửa hàng chục
    /// dòng một lúc nên phải có diff để duyệt; ở đây mỗi thao tác đụng một node hay một cạnh,
    /// và một hộp thoại xác nhận sau mỗi cú kéo sẽ biến "soạn trực quan" thành "bấm OK trực
    /// quan". Cái thay cho hộp thoại là một bước hoàn tác: mỗi thao tác đúng một lần Cmd-Z,
    /// đúng như đặc tả đòi.
    private func applyGraphEdit(_ label: String, _ body: () throws -> [TextEdit]) {
        guard !editorDocument.isReadOnly else {
            return refuseGraphEdit(L("Tài liệu đang ở chế độ chỉ đọc"))
        }
        do {
            let edits = try body()
            guard !edits.isEmpty else {
                return refuseGraphEdit(L("Không có gì để đổi"))
            }
            editorDocument.buffer.applyEdits(edits, label: label)
            editorDocument.refreshEOLReport()
            syncViewFromBuffer()
            refreshChrome()
            refreshMermaidPreview()
            lastGraphEditForSelfTest = label
            showTransient(label + " · " + L("Cmd-Z hoàn tác"))
        } catch let failure as GraphEdit.Failure {
            // Xem ghi chú ở `refuseGraphEdit`: câu người dùng đọc và câu bài kiểm đọc là MỘT.
            // Lý do NÓI RA, không nuốt. Mọi lối từ chối của `GraphEdit` đều mang một câu giải
            // thích cụ thể ("có 2 node cùng mang nhãn «An»"), và câu ấy là thứ duy nhất cho
            // người dùng biết phải sửa gì.
            refuseGraphEdit(failure.reason)
        } catch {
            refuseGraphEdit("\(error)")
        }
    }

    /// Từ chối một phép soạn: nói ra lý do, và ghi ĐÚNG câu ấy làm dấu vết.
    ///
    /// Một câu cho cả hai phía có chủ ý. Bản đầu giữ hai vốn từ song song — người dùng đọc
    /// "Tài liệu đang ở chế độ chỉ đọc" còn bài kiểm đọc "tài liệu chỉ đọc" — và hai bảng chữ
    /// cho cùng một trạng thái là hai chỗ để lệch nhau, cộng thêm một khoản nợ dịch cho những
    /// câu không ai đọc.
    private func refuseGraphEdit(_ reason: String) {
        lastGraphEditForSelfTest = reason
        showTransient(reason)
    }

    /// Cử chỉ trên hình → phép sửa văn bản. Chữ đi vào đây là CHỮ TRÊN HÌNH, chưa phải tên node.
    func handleGraphEditGesture(_ op: String, from: String, to: String) {
        guard mermaidPanel.isVisualEditing else { return }
        guard let graph = freshGraph() else {
            lastGraphEditForSelfTest = nil
            return
        }
        switch op {
        case "edge":
            applyGraphEdit(L("Thêm cạnh")) {
                let a = try GraphEdit.resolveNode(from, in: graph)
                let b = try GraphEdit.resolveNode(to, in: graph)
                return try GraphEdit.addEdge(from: a, to: b, in: editorDocument.buffer.text)
            }
        case "label":
            // Hỏi nhãn MỚI, điền sẵn nhãn cũ. Không điền sẵn thì thao tác "sửa" biến thành
            // "gõ lại từ đầu", và người dùng sửa một chữ trong nhãn mười từ phải gõ cả mười.
            guard let name = try? GraphEdit.resolveNode(from, in: graph) else {
                return refuseGraphEdit(LF("Không rõ «%@» là node nào", from))
            }
            let cu = graph.nodes.first { $0.name == name }?.display ?? name
            // Ghi dấu TRƯỚC khi hỏi: `Unattended.ask` cố tình không tự bấm OK, nên bài tự kiểm
            // không đi qua được hộp thoại. Không có dấu này thì nửa "cử chỉ đã tới đúng node"
            // của đường đi không có gì chấm được.
            lastGraphEditForSelfTest = "ask-label: \(name)"
            guard let moi = askForText(
                title: LF("Nhãn của «%@»", name),
                message: L("Chỉ đổi NHÃN hiện trên hình; định danh node giữ nguyên."),
                placeholder: cu, initial: cu), !moi.isEmpty, moi != cu else { return }
            setGraphLabel(node: name, to: moi)
        default:
            break
        }
    }

    /// Đổi nhãn — tách riêng để bài tự kiểm gọi được mà không phải qua hộp thoại.
    func setGraphLabel(node: String, to label: String) {
        applyGraphEdit(L("Sửa nhãn node")) {
            try GraphEdit.setLabel(of: node, to: label, in: editorDocument.buffer.text)
        }
    }

    func addGraphNode(name suggested: String? = nil, label: String? = nil) {
        guard let name = suggested ?? askForText(
            title: L("Thêm node"),
            message: L("Định danh node trong tệp DOT. Nhãn sửa sau bằng double-click trên hình."),
            placeholder: "node_moi"), !name.isEmpty else { return }
        applyGraphEdit(L("Thêm node")) {
            try GraphEdit.addNode(name: name, label: label, in: editorDocument.buffer.text)
        }
    }

    /// Thêm cạnh bằng BÀN PHÍM: bôi đen hai node trong văn bản rồi chạy lệnh.
    ///
    /// Cùng một phép với cú kéo trên hình, nhưng tới được mà không cần chuột — NFR-USE-03.
    func addGraphEdgeFromSelection() {
        let selected = selectedGraphNodes()
        guard selected.names.count == 2 else {
            return refuseGraphEdit(L("Bôi đen ĐÚNG HAI node rồi chạy lại"))
        }
        // Thứ tự = thứ tự XUẤT HIỆN trong văn bản. Đồ thị có hướng thì chiều cạnh có nghĩa, và
        // đọc từ trên xuống là quy ước duy nhất mà người dùng đoán được từ thứ họ đang nhìn.
        applyGraphEdit(L("Thêm cạnh")) {
            try GraphEdit.addEdge(from: selected.names[0], to: selected.names[1],
                                  in: editorDocument.buffer.text)
        }
    }

    func editGraphLabelFromSelection() {
        guard let graph = freshGraph() else { return }
        let selected = selectedGraphNodes()
        guard selected.names.count == 1, let name = selected.names.first else {
            return refuseGraphEdit(L("Đặt con nháy lên ĐÚNG MỘT node rồi chạy lại"))
        }
        let cu = graph.nodes.first { $0.name == name }?.display ?? name
        guard let moi = askForText(
            title: LF("Nhãn của «%@»", name),
            message: L("Chỉ đổi NHÃN hiện trên hình; định danh node giữ nguyên."),
            placeholder: cu, initial: cu), !moi.isEmpty else { return }
        setGraphLabel(node: name, to: moi)
    }

    /// Xoá thứ đang chọn: một node thì xoá node (và mọi cạnh chạm nó), hai node có cạnh nối thì
    /// xoá riêng CẠNH ấy.
    ///
    /// Không đoán khi vùng chọn không nói rõ. Xoá nhầm ở đây khác xoá nhầm một dòng chữ: người
    /// dùng chỉ thấy hình vẽ đổi, và họ không biết cái gì vừa biến mất khỏi tệp.
    func removeGraphElementFromSelection(confirmed: Bool = false) {
        guard let graph = freshGraph() else { return }
        let selected = selectedGraphNodes()
        if selected.names.count == 2,
           graph.edges.contains(where: {
               $0.from == selected.names[0] && $0.to == selected.names[1]
           }) {
            return applyGraphEdit(L("Xoá cạnh")) {
                try GraphEdit.removeEdge(from: selected.names[0], to: selected.names[1],
                                         in: editorDocument.buffer.text)
            }
        }
        guard selected.names.count == 1, let name = selected.names.first else {
            return refuseGraphEdit(L("Chọn MỘT node để xoá node, hoặc hai node có cạnh nối"))
        }
        // Xoá node kéo theo cạnh, nên đây là phép DUY NHẤT ở FR-KNW-915 đụng tới nhiều dòng
        // người dùng không nhìn thấy — và nó có hỏi.
        let cham = graph.edges.filter { $0.from == name || $0.to == name }.count
        if cham > 0, !confirmed {
            let alert = NSAlert()
            alert.messageText = LF("Xoá node «%@» và %d cạnh chạm nó?", name, cham)
            alert.informativeText = L("Giữ lại cạnh treo thì DOT tự sinh lại node từ chính "
                + "những cạnh ấy — node vừa xoá sẽ hiện lại ở lần vẽ sau.")
            alert.addButton(withTitle: L("Huỷ"))
            alert.addButton(withTitle: L("Xoá node"))
            guard Unattended.ask(alert) == .alertSecondButtonReturn else { return }
        }
        applyGraphEdit(L("Xoá node")) {
            try GraphEdit.removeNode(name, in: editorDocument.buffer.text)
        }
    }

    // MARK: - Soạn thảo sơ đồ Mermaid trực quan (FR-MMD-004)

    /// Khối sơ đồ mà một thao tác đang nói tới, ĐỌC LẠI từ buffer ngay lúc bấm.
    ///
    /// Cùng cái bẫy `freshGraph()` đã ghi: `mermaidBlocks` do lượt vẽ cập nhật, mà lượt vẽ hoãn
    /// 300 ms sau phím cuối. Mọi phép ở đây sửa theo SỐ DÒNG trong khối, nên chạy trên bản đọc
    /// cũ là sửa theo số dòng của một văn bản đã không còn.
    ///
    /// `index` là số hiệu khối do cử chỉ trên hình gửi về; `nil` thì lấy khối đang có con nháy.
    func freshMermaidBlock(index: Int? = nil) -> MermaidBlock? {
        let text = editorDocument.buffer.text
        guard !DOTGraph.looksLikeDOT(text, path: editorDocument.path) else { return nil }
        let blocks = (editorDocument.path ?? "")
            .hasSuffix("." + MermaidDocument.fileExtension)
            ? [MermaidDocument.wholeFile(text)]
            : MermaidDocument.blocks(in: text)
        if let index { return blocks.first { $0.index == index } }
        let caret = editorView.selectedDocumentRange.lowerBound
        let line = editorDocument.buffer.lineNumber(
            atOffset: min(max(0, caret), editorDocument.buffer.count))
        return blocks.first {
            let last = $0.firstContentLine + $0.source.components(separatedBy: "\n").count - 1
            return $0.firstContentLine <= line && line <= last
        } ?? blocks.first
    }

    /// Đường ÁP duy nhất của mọi phép soạn mermaid.
    ///
    /// Chỗ khác `applyGraphEdit` đúng một việc, và việc ấy là chỗ dễ sai nhất của cả tính năng:
    /// `MermaidEdit` tính theo NGUỒN SƠ ĐỒ, còn buffer chứa cả tài liệu. Một khối ` ```mermaid `
    /// nằm giữa tệp Markdown lệch đi đúng bằng vị trí của nó, và quên phép dời ấy thì sửa đổi
    /// rơi vào một đoạn văn bản chẳng liên quan.
    func applyMermaidEdit(
        _ label: String, block: MermaidBlock, _ body: (String) throws -> [TextEdit]
    ) {
        guard !editorDocument.isReadOnly else {
            return refuseGraphEdit(L("Tài liệu đang ở chế độ chỉ đọc"))
        }
        // Khối THAM CHIẾU (FR-MMD-008) không soạn tại chỗ được: "giữ tham chiếu để sửa một nơi"
        // nghĩa là nơi ấy — sửa ở đây sẽ ghi đè dòng tham chiếu bằng một sơ đồ, tức âm thầm bỏ
        // liên kết mà người dùng vừa cố ý tạo ra.
        if let path = MermaidLink.reference(in: block.source) {
            return refuseGraphEdit(String(
                format: L("Khối này tham chiếu «%@» — mở tệp ấy để sửa"), path))
        }
        do {
            let delta = editorDocument.buffer.offset(ofLineStart: block.firstContentLine)
            let edits = MermaidEdit.shift(try body(block.source), by: delta)
            guard !edits.isEmpty else { return refuseGraphEdit(L("Không có gì để đổi")) }
            editorDocument.buffer.applyEdits(edits, label: label)
            editorDocument.refreshEOLReport()
            syncViewFromBuffer()
            refreshChrome()
            refreshMermaidPreview()
            lastGraphEditForSelfTest = label
            showTransient(label + " · " + L("Cmd-Z hoàn tác"))
        } catch let failure as MermaidEdit.Failure {
            refuseGraphEdit(failure.reason)
        } catch {
            refuseGraphEdit("\(error)")
        }
    }

    /// Cử chỉ trên hình → phép sửa mã mermaid.
    func handleMermaidGesture(_ op: String, from: String, to: String, index: Int) {
        guard let block = freshMermaidBlock(index: index) else { return }
        let model = MermaidEdit.parse(block.source)
        // Loại chưa soạn được thì NÓI RA, kèm lý do — đặc tả đòi *"hiển thị rõ 'chỉ soạn text'"*.
        // Im lặng không làm gì là cách chắc chắn nhất khiến người dùng nghĩ công cụ hỏng.
        if case let .textOnly(reason) = MermaidEdit.support(for: model.kind) {
            return refuseGraphEdit(String(
                format: L("Sơ đồ «%@» chỉ soạn text — %@"), model.kind.vietnamese, reason))
        }
        switch op {
        case "edge":
            applyMermaidEdit(L("Thêm cạnh"), block: block) { source in
                let a = try MermaidEdit.resolveNode(from, in: model)
                let b = try MermaidEdit.resolveNode(to, in: model)
                return try MermaidEdit.addEdge(from: a, to: b, in: source)
            }
        case "label":
            guard let id = try? MermaidEdit.resolveNode(from, in: model) else {
                return refuseGraphEdit(LF("Không rõ «%@» là phần tử nào", from))
            }
            lastGraphEditForSelfTest = "ask-label: \(id)"
            let cu = model.node(id)?.display ?? id
            guard let moi = askForText(
                title: LF("Nhãn của «%@»", id),
                message: L("Chỉ đổi NHÃN hiện trên hình; định danh phần tử giữ nguyên."),
                placeholder: cu, initial: cu), !moi.isEmpty, moi != cu else { return }
            setMermaidLabel(id, to: moi, in: block)
        default:
            break
        }
    }

    /// Tách riêng để bài tự kiểm gọi được mà không phải qua hộp thoại.
    func setMermaidLabel(_ id: String, to label: String, in block: MermaidBlock) {
        applyMermaidEdit(L("Sửa nhãn"), block: block) {
            try MermaidEdit.setLabel(of: id, to: label, in: $0)
        }
    }

    /// Phần tử mà VÙNG CHỌN trong văn bản đang nói tới — đường không cần chuột (NFR-USE-03).
    ///
    /// Theo đúng thứ tự XUẤT HIỆN trong văn bản: đồ thị có hướng thì chiều cạnh có nghĩa, và
    /// đọc từ trên xuống là quy ước duy nhất người dùng đoán được từ thứ họ đang nhìn.
    func selectedMermaidNodes(in block: MermaidBlock) -> [String] {
        let model = MermaidEdit.parse(block.source)
        let buffer = editorDocument.buffer
        let selection = editorView.selectedDocumentRange
        let first = buffer.lineNumber(atOffset: min(max(0, selection.lowerBound), buffer.count))
            - block.firstContentLine
        let last = buffer.lineNumber(atOffset: min(max(0, selection.upperBound), buffer.count))
            - block.firstContentLine
        var out: [String] = []
        func them(_ id: String) { if !out.contains(id), id != "[*]" { out.append(id) } }
        for line in first ... max(first, last) {
            for node in model.nodes where node.declLine == line || node.labelLine == line {
                them(node.id)
            }
            for edge in model.edges where edge.line == line {
                them(edge.from)
                them(edge.to)
            }
        }
        return out
    }

    @objc func addMermaidNode(_ sender: Any?) {
        guard let block = freshMermaidBlock() else {
            return showTransient(L("Tài liệu này không có khối mermaid nào"))
        }
        let kind = MermaidEdit.parse(block.source).kind
        let laSequence = MermaidEdit.support(for: kind) == .sequence
        guard let id = askForText(
            title: laSequence ? L("Thêm participant") : L("Thêm phần tử"),
            message: L("Định danh trong mã sơ đồ — không dấu cách. Nhãn sửa sau bằng double-click."),
            placeholder: laSequence ? "NguoiDung" : "phan_tu_moi"), !id.isEmpty else { return }
        let label = askForText(
            title: LF("Nhãn của «%@»", id),
            message: L("Để trống thì hiện chính định danh."), placeholder: id)
        applyMermaidEdit(laSequence ? L("Thêm participant") : L("Thêm phần tử"), block: block) {
            try MermaidEdit.addNode(id: id, label: (label?.isEmpty ?? true) ? nil : label, in: $0)
        }
    }

    @objc func addMermaidEdge(_ sender: Any?) {
        guard let block = freshMermaidBlock() else { return }
        let chon = selectedMermaidNodes(in: block)
        guard chon.count == 2 else {
            return refuseGraphEdit(L("Bôi đen ĐÚNG HAI phần tử rồi chạy lại"))
        }
        applyMermaidEdit(L("Thêm cạnh"), block: block) {
            try MermaidEdit.addEdge(from: chon[0], to: chon[1], in: $0)
        }
    }

    @objc func editMermaidLabel(_ sender: Any?) {
        guard let block = freshMermaidBlock() else { return }
        let model = MermaidEdit.parse(block.source)
        let chon = selectedMermaidNodes(in: block)
        guard chon.count == 1, let id = chon.first else {
            return refuseGraphEdit(L("Đặt con nháy lên ĐÚNG MỘT phần tử rồi chạy lại"))
        }
        let cu = model.node(id)?.display ?? id
        guard let moi = askForText(
            title: LF("Nhãn của «%@»", id),
            message: L("Chỉ đổi NHÃN hiện trên hình; định danh phần tử giữ nguyên."),
            placeholder: cu, initial: cu), !moi.isEmpty else { return }
        setMermaidLabel(id, to: moi, in: block)
    }

    @objc func removeMermaidElement(_ sender: Any?) {
        removeMermaidElement(confirmed: false)
    }

    func removeMermaidElement(confirmed: Bool) {
        guard let block = freshMermaidBlock() else { return }
        let model = MermaidEdit.parse(block.source)
        let chon = selectedMermaidNodes(in: block)
        if chon.count == 2,
           model.edges.contains(where: { $0.from == chon[0] && $0.to == chon[1] }) {
            return applyMermaidEdit(L("Xoá cạnh"), block: block) {
                try MermaidEdit.removeEdge(from: chon[0], to: chon[1], in: $0)
            }
        }
        guard chon.count == 1, let id = chon.first else {
            return refuseGraphEdit(L("Chọn MỘT phần tử để xoá, hoặc hai phần tử có cạnh nối"))
        }
        let cham = model.edges.filter { $0.from == id || $0.to == id }.count
        if cham > 0, !confirmed {
            let alert = NSAlert()
            alert.messageText = String(
                format: L("Xoá «%@» và %d cạnh chạm nó?"), id, cham)
            alert.informativeText = L("Node ở đầu kia của những cạnh ấy được giữ lại — chúng "
                + "được khai lại kèm nhãn nếu câu lệnh cạnh là chỗ duy nhất khai chúng.")
            alert.addButton(withTitle: L("Huỷ"))
            alert.addButton(withTitle: L("Xoá node"))
            guard Unattended.ask(alert) == .alertSecondButtonReturn else { return }
        }
        applyMermaidEdit(L("Xoá phần tử"), block: block) {
            try MermaidEdit.removeNode(id, in: $0)
        }
    }

    @objc func moveMermaidMessageUp(_ sender: Any?) { moveMermaidMessage(.up) }
    @objc func moveMermaidMessageDown(_ sender: Any?) { moveMermaidMessage(.down) }

    func moveMermaidMessage(_ direction: MermaidEdit.Direction) {
        guard let block = freshMermaidBlock() else { return }
        let caret = editorView.selectedDocumentRange.lowerBound
        let line = editorDocument.buffer.lineNumber(
            atOffset: min(max(0, caret), editorDocument.buffer.count)) - block.firstContentLine
        applyMermaidEdit(L("Đổi thứ tự message"), block: block) {
            try MermaidEdit.moveMessage(at: line, direction, in: $0)
        }
    }

    /// Đổ bảng thuộc tính (gantt · pie) sau mỗi lượt vẽ, và nối ba nút của nó vào buffer.
    func refreshMermaidPropertyTable(for block: MermaidBlock?) {
        guard let block, mermaidPanel.isVisualEditing else {
            return mermaidPanel.showPropertyTable(false)
        }
        let model = MermaidEdit.parse(block.source)
        guard case .propertyTable = MermaidEdit.support(for: model.kind) else {
            return mermaidPanel.showPropertyTable(false)
        }
        mermaidPanel.showPropertyTable(true)
        mermaidPanel.propertyTable.present(model.rows, kind: model.kind)
        mermaidPanel.propertyTable.onEdit = { [weak self] line, label, value in
            guard let self, let fresh = self.freshMermaidBlock(index: block.index) else { return }
            self.applyMermaidEdit(L("Sửa mục sơ đồ"), block: fresh) {
                try MermaidEdit.setRow(at: line, label: label, value: value, in: $0)
            }
        }
        mermaidPanel.propertyTable.onAdd = { [weak self] in
            guard let self, let fresh = self.freshMermaidBlock(index: block.index) else { return }
            guard let label = self.askForText(
                title: L("Thêm mục"), message: L("Tên mục hiện trên sơ đồ."),
                placeholder: L("Mục mới")), !label.isEmpty else { return }
            let value = self.askForText(
                title: L("Giá trị"),
                message: L("Với pie là một con số; với gantt là phần sau dấu hai chấm."),
                placeholder: "0") ?? "0"
            self.applyMermaidEdit(L("Thêm mục sơ đồ"), block: fresh) {
                try MermaidEdit.addRow(label: label, value: value, in: $0)
            }
        }
        mermaidPanel.propertyTable.onRemove = { [weak self] line in
            guard let self, let fresh = self.freshMermaidBlock(index: block.index) else { return }
            self.applyMermaidEdit(L("Xoá mục sơ đồ"), block: fresh) {
                try MermaidEdit.removeRow(at: line, in: $0)
            }
        }
    }

    // MARK: - Tách và nhúng khối sơ đồ (FR-MMD-008)

    /// Đường dẫn tuyệt đối của một tham chiếu, giải theo THƯ MỤC CHỨA tài liệu.
    ///
    /// Tương đối chứ không tuyệt đối, cùng lý do đã ghi ở FR-KNW-919: một đường dẫn tuyệt đối
    /// trong tệp làm cả thư mục báo cáo chết khi đem sang máy khác — mà "đem sang máy khác" là
    /// đúng việc người ta làm với một tệp Markdown.
    func resolveMermaidReference(_ path: String) -> String? {
        guard let doc = editorDocument.path else { return nil }
        if path.hasPrefix("/") { return path }
        return ((doc as NSString).deletingLastPathComponent as NSString)
            .appendingPathComponent(path)
    }

    /// Đổi mọi khối THAM CHIẾU thành nội dung thật, để vẽ.
    ///
    /// Không đọc được tệp thì thay bằng một sơ đồ nói ra lý do, chứ không bỏ khối đi. Một khối
    /// biến mất trông y hệt "tài liệu vốn không có sơ đồ ở đây", và người dùng sẽ đi tìm lỗi ở
    /// chỗ khác.
    func resolvedMermaidBlocks(_ blocks: [MermaidBlock]) -> [MermaidBlock] {
        blocks.map { block in
            guard let path = MermaidLink.reference(in: block.source) else { return block }
            var out = block
            if let full = resolveMermaidReference(path),
               let text = try? String(contentsOfFile: full, encoding: .utf8) {
                out.source = text
            } else {
                out.source = "flowchart TD\n  loi[\""
                    + LF("Không đọc được tệp sơ đồ %@", path)
                    + "\"]"
            }
            return out
        }
    }

    /// Khối mà con nháy đang đứng trong, KỂ CẢ khi nó chỉ là một dòng tham chiếu.
    ///
    /// Khác `freshMermaidBlock()` một chỗ: hàm kia bỏ tài liệu DOT, còn hàm này cũng thế, nhưng
    /// nó KHÔNG giải tham chiếu — hai lệnh tách/nhúng cần thấy đúng khối như nó nằm trên đĩa.
    @objc func splitMermaidBlock(_ sender: Any?) {
        guard let doc = editorDocument.path else {
            return showTransient(L("Tài liệu chưa lưu — tệp sơ đồ cần chỗ để nằm cạnh"))
        }
        guard let block = freshMermaidBlock() else {
            return showTransient(L("Tài liệu này không có khối mermaid nào"))
        }
        let base = ((doc as NSString).lastPathComponent as NSString).deletingPathExtension
        let goiY = "\(base)-so-do-\(block.index + 1).\(MermaidDocument.fileExtension)"
        guard let ten = askForText(
            title: L("Tách khối sơ đồ ra tệp riêng"),
            message: L("Tệp đặt CẠNH tài liệu; khối trong tài liệu giữ một dòng tham chiếu để "
                + "sửa một nơi."),
            placeholder: goiY, initial: goiY), !ten.isEmpty else { return }
        splitMermaidBlock(block, to: ten)
    }

    /// Tách khỏi phần hộp thoại để bài tự kiểm gọi được.
    func splitMermaidBlock(_ block: MermaidBlock, to name: String) {
        guard !editorDocument.isReadOnly else {
            return refuseGraphEdit(L("Tài liệu đang ở chế độ chỉ đọc"))
        }
        guard let target = resolveMermaidReference(name) else { return }
        do {
            let ket_qua = try MermaidLink.extract(
                block, in: editorDocument.buffer.text, to: name)
            // Ghi tệp TRƯỚC, sửa tài liệu SAU. Ngược lại thì một lần ghi hỏng (đĩa đầy, không có
            // quyền) để lại một tài liệu trỏ vào tệp không tồn tại — và sơ đồ vừa biến mất.
            guard !FileManager.default.fileExists(atPath: target) else {
                return refuseGraphEdit(LF("Đã có tệp «%@» — chọn tên khác", name))
            }
            try AtomicFileWriter.write(Array(ket_qua.file.utf8), to: target)
            editorDocument.buffer.applyEdits(ket_qua.edits, label: L("Tách khối sơ đồ"))
            editorDocument.refreshEOLReport()
            syncViewFromBuffer()
            refreshChrome()
            refreshMermaidPreview()
            lastGraphEditForSelfTest = L("Tách khối sơ đồ")
            showBanner(LF("Đã tách ra «%@» — khối giữ một dòng tham chiếu", name),
                       actionTitle: L("Mở tệp"), action: #selector(openSplitMermaidFile))
            lastSplitMermaidPath = target
        } catch let failure as MermaidLink.Failure {
            refuseGraphEdit(failure.reason)
        } catch {
            refuseGraphEdit(LF("Không ghi được: %@", "\(error)"))
        }
    }

    @objc func openSplitMermaidFile() {
        guard let path = lastSplitMermaidPath else { return }
        openInNewTab(path: path)
    }

    @objc func embedMermaidBlock(_ sender: Any?) {
        guard let block = freshMermaidBlock() else {
            return showTransient(L("Tài liệu này không có khối mermaid nào"))
        }
        guard let path = MermaidLink.reference(in: block.source) else {
            return refuseGraphEdit(L("Khối này chứa sơ đồ thật, không phải một tham chiếu"))
        }
        guard let full = resolveMermaidReference(path),
              let content = try? String(contentsOfFile: full, encoding: .utf8) else {
            return refuseGraphEdit(LF("Không đọc được tệp sơ đồ %@", path))
        }
        guard !editorDocument.isReadOnly else {
            return refuseGraphEdit(L("Tài liệu đang ở chế độ chỉ đọc"))
        }
        do {
            let edits = try MermaidLink.embed(
                block, in: editorDocument.buffer.text, content: content)
            editorDocument.buffer.applyEdits(edits, label: L("Nhúng khối sơ đồ"))
            editorDocument.refreshEOLReport()
            syncViewFromBuffer()
            refreshChrome()
            refreshMermaidPreview()
            lastGraphEditForSelfTest = L("Nhúng khối sơ đồ")
            // Tệp `.mmd` KHÔNG bị xoá: xoá nó là một hành động không hoàn tác được bằng Cmd-Z,
            // trong khi phép nhúng thì có. Người dùng tự dọn khi họ chắc.
            showBanner(LF("Đã nhúng «%@» trở lại; tệp vẫn còn trên đĩa", path),
                       actionTitle: nil, action: nil)
        } catch let failure as MermaidLink.Failure {
            refuseGraphEdit(failure.reason)
        } catch {
            refuseGraphEdit("\(error)")
        }
    }

    /// Câu nói ra khi bật công tắc: loại nào soạn được bằng thao tác nào, loại nào chỉ soạn text.
    func visualEditingNotice() -> String {
        if dotGraph != nil {
            return L("Soạn trực quan: kéo giữa hai node để thêm cạnh, double-click để sửa nhãn")
        }
        guard let block = freshMermaidBlock() else { return L("Soạn trực quan đã bật") }
        let kind = MermaidEdit.parse(block.source).kind
        switch MermaidEdit.support(for: kind) {
        case .nodesAndEdges:
            return LF("%@: kéo giữa hai phần tử để nối, double-click để sửa nhãn",
                          kind.vietnamese)
        case .sequence:
            return LF("%@: kéo giữa hai participant để thêm message; đổi thứ tự "
                + "bằng menu Công cụ", kind.vietnamese)
        case .propertyTable:
            return LF("%@: sửa trong bảng thuộc tính bên dưới", kind.vietnamese)
        case let .textOnly(reason):
            return LF("Sơ đồ «%@» chỉ soạn text — %@", kind.vietnamese, reason)
        }
    }

    // MARK: - Tái cấu trúc đồ thị (FR-KNW-916)

    /// Tên node mà VÙNG CHỌN đang nói tới, kèm số dòng mỗi tên xuất hiện.
    ///
    /// Lấy `name` chứ không lấy `display`: mọi phép ở `GraphRefactor` sửa ĐỊNH DANH trong văn
    /// bản, còn `display` là nhãn. Trộn hai thứ thì một lệnh "đổi tên node" lại đi sửa nhãn và
    /// để nguyên node.
    ///
    /// Số dòng đi kèm là thứ phép TÁCH cần: chọn ba dòng cạnh cùng chạm một node thì node ấy
    /// xuất hiện trên cả ba, các node kia mỗi cái một dòng — nên "cái xuất hiện nhiều nhất" là
    /// node bị tách, phần còn lại là hàng xóm chuyển đi. Không phải đoán, mà là đọc đúng thứ
    /// người dùng vừa bôi đen.
    private func selectedGraphNodes() -> (names: [String], lines: [String: Int]) {
        guard let graph = dotGraph else { return ([], [:]) }
        let buffer = editorDocument.buffer
        let selection = editorView.selectedDocumentRange
        let first = buffer.lineNumber(atOffset: min(max(0, selection.lowerBound), buffer.count))
        let last = buffer.lineNumber(atOffset: min(max(0, selection.upperBound), buffer.count))
        var names: [String] = []
        var lines: [String: Int] = [:]
        for line in first ... max(first, last) {
            var here = Set<String>()
            for node in graph.nodes where node.line == line { here.insert(node.name) }
            for edge in graph.edges where edge.line == line {
                here.insert(edge.from)
                here.insert(edge.to)
            }
            for name in here.sorted() {
                if lines[name] == nil { names.append(name) }
                lines[name, default: 0] += 1
            }
        }
        return (names, lines)
    }

    /// Đồ thị ĐỌC LẠI từ buffer ngay lúc bấm, chứ không dùng bản đã đọc.
    ///
    /// `dotGraph` do lượt vẽ cập nhật, mà lượt vẽ **hoãn 300 ms** sau lần gõ cuối
    /// (`scheduleMermaidRefresh`). Bốn phép ở đây sửa văn bản theo SỐ DÒNG của đồ thị, nên
    /// chạy trên bản đọc cũ là sửa theo số dòng của một văn bản đã không còn — sai và im lặng.
    /// Một bài tự kiểm bắt được đúng chỗ này: sau `undo`, `dotGraph` còn giữ đồ thị TRƯỚC khi
    /// hoàn tác, và phép tách chạy vào chỗ trống.
    ///
    /// Đọc lại một lần cho mỗi lần bấm rẻ hơn hẳn cái sai ấy; và nếu đồ thị đã đổi thì bỏ luôn
    /// CSR cùng mọi kết quả cũ, đúng như lượt vẽ vẫn làm.
    private func freshGraph() -> DOTGraph? {
        let text = editorDocument.buffer.text
        guard DOTGraph.looksLikeDOT(text, path: editorDocument.path) else { return nil }
        let graph = DOTGraph.parse(text)
        if graph != dotGraph {
            dotGraph = graph
            graphCSR = nil
            graphStyles = [:]
            graphPageRank = nil
            graphCommunities = nil
            graphComponents = nil
        }
        return graph
    }

    /// Đường ÁP duy nhất của cả bốn phép: hỏi, rồi ghi MỘT bước undo.
    ///
    /// Bốn phép đi chung một cửa để cái hàng rào chỉ phải đúng ở một chỗ. Ba điều kiện của đặc
    /// tả nằm cả ở đây: không phép nào ghi thẳng, hộp hỏi có DIFF chứ không chỉ có con số, và
    /// cả changeset vào buffer bằng một lần thay — nửa vời thì Cmd-Z trả về một đồ thị chưa ai
    /// khai bao giờ.
    private func applyGraphRefactor(
        _ result: GraphRefactor.Result, label: String, confirmed: Bool = false
    ) {
        guard !result.edits.isEmpty else {
            return showTransient(result.warnings.first ?? L("Không có gì để đổi"))
        }
        let text = editorDocument.buffer.text
        let alert = NSAlert()
        alert.messageText = LF("%@ — áp %d thay đổi?", label, result.edits.count)
        var detail = result.report
        detail.append(contentsOf: result.warnings.map { "⚠ " + $0 })
        detail.append("")
        detail.append(contentsOf: GraphRefactor.diff(result.edits, in: text))
        alert.informativeText = detail.joined(separator: "\n")
        alert.addButton(withTitle: L("Huỷ"))
        alert.addButton(withTitle: L("Áp"))
        guard confirmed || Unattended.ask(alert) == .alertSecondButtonReturn else { return }

        let updated = EntityResolution.apply(result.edits, to: text)
        editorDocument.buffer.replace(0 ..< editorDocument.buffer.count, with: updated, label: label)
        syncViewFromBuffer()
        refreshMermaidPreview()
        showBanner(LF("%@: %d thay đổi · Cmd-Z hoàn tác cả cụm",
                          label, result.edits.count),
                   actionTitle: nil, action: nil)
    }

    private func renameGraphNode(newName suggested: String? = nil, confirmed: Bool = false) {
        guard let graph = freshGraph() else { return }
        let selected = selectedGraphNodes()
        guard selected.names.count == 1, let node = selected.names.first else {
            return showTransient(L("Đặt con nháy lên ĐÚNG MỘT node rồi chạy lại"))
        }
        guard let newName = suggested ?? askForText(
            title: LF("Đổi tên «%@»", node),
            message: L("Mọi cạnh và nhãn tham chiếu node này sẽ đổi theo."),
            placeholder: node), !newName.isEmpty else { return }
        applyGraphRefactor(
            GraphRefactor.rename(node, to: newName, in: editorDocument.buffer.text, graph: graph),
            label: L("Đổi tên node"), confirmed: confirmed)
    }

    private func mergeGraphNodes(confirmed: Bool = false) {
        guard let graph = freshGraph(), let csr = currentGraphCSR() else { return }
        let selected = selectedGraphNodes()
        guard selected.names.count >= 2 else {
            return showTransient(L("Bôi đen từ HAI node trở lên rồi chạy lại"))
        }
        // Dạng chuẩn chọn bằng ĐÚNG luật của FR-KNW-923: hay gặp nhất → dài nhất → CÒN DẤU →
        // thứ tự chữ. Viết luật thứ hai ở đây thì cùng một câu hỏi "bản nào là bản chuẩn" có
        // hai câu trả lời khác nhau tuỳ người dùng bấm vào lệnh nào — và bản không dấu sẽ
        // thắng ở một trong hai, đúng cái bẫy mà 923 đã vấp.
        var counts: [String: Int] = [:]
        for name in selected.names {
            counts[name] = csr.index(of: name).map { csr.degree($0) } ?? 0
        }
        let canonical = EntityResolution.suggest(selected.names, counts: counts)
        var result = GraphRefactor.merge(
            selected.names, into: canonical, in: editorDocument.buffer.text, graph: graph)
        result.report.insert(
            LF("Dạng chuẩn «%@» — hay gặp nhất, dài nhất, còn dấu", canonical),
            at: 0)
        applyGraphRefactor(result, label: L("Gộp node"), confirmed: confirmed)
    }

    private func splitGraphNode(newName suggested: String? = nil, confirmed: Bool = false) {
        guard let graph = freshGraph() else { return }
        let selected = selectedGraphNodes()
        guard selected.names.count >= 2 else {
            return showTransient(L("Bôi đen những DÒNG CẠNH muốn chuyển rồi chạy lại"))
        }
        // Node bị tách = node có mặt trên NHIỀU dòng đã chọn nhất. Hoà thì KHÔNG đoán: hai
        // ứng viên ngang nhau nghĩa là vùng chọn chưa nói ra ai bị tách, và đoán sai ở đây làm
        // hỏng đúng những cạnh người dùng vừa chỉ vào.
        let most = selected.names.map { selected.lines[$0] ?? 0 }.max() ?? 0
        let candidates = selected.names.filter { (selected.lines[$0] ?? 0) == most }
        guard candidates.count == 1, let node = candidates.first else {
            return showTransient(
                L("Mọi dòng đã chọn phải cùng chạm ĐÚNG MỘT node — bôi đen thêm dòng cạnh"))
        }
        let neighbours = selected.names.filter { $0 != node }
        guard let newName = suggested ?? askForText(
            title: LF("Tách «%@» — chuyển %d cạnh", node, neighbours.count),
            message: LF("Cạnh tới: %@", neighbours.joined(separator: ", ")),
            placeholder: node + "_2"), !newName.isEmpty else { return }
        applyGraphRefactor(
            GraphRefactor.split(node, movingNeighbours: neighbours, to: newName,
                                in: editorDocument.buffer.text, graph: graph),
            label: L("Tách node"), confirmed: confirmed)
    }

    /// TRÍCH không sửa tài liệu đang mở — nó sinh một tệp mới, nên không đi qua `applyGraphRefactor`.
    private func extractSubgraph() {
        guard let graph = freshGraph(), let path = editorDocument.path else {
            return showTransient(L("Tài liệu chưa lưu — tệp trích cần chỗ để nằm cạnh"))
        }
        let selected = selectedGraphNodes()
        guard !selected.names.isEmpty else {
            return showTransient(L("Bôi đen phần đồ thị muốn trích rồi chạy lại"))
        }
        let base = (path as NSString).deletingPathExtension
        let target = base + ".trich.dot"
        let extracted = GraphRefactor.extract(
            selected.names, from: graph, name: (base as NSString).lastPathComponent + "_trich")
        do {
            try AtomicFileWriter.write(Array(extracted.text.utf8), to: target)
        } catch {
            return showTransient(LF("Không ghi được: %@", "\(error)"))
        }
        openInNewTab(path: target)
        showBanner(extracted.report.joined(separator: " · "), actionTitle: nil, action: nil)
    }

    // MARK: - Gom biến thể entity (FR-KNW-923)

    /// Tệp bảng duyệt, đặt CẠNH tệp đồ thị — cùng quy ước với bộ đánh giá golden set.
    static func resolutionReviewPath(forGraph path: String) -> String {
        (path as NSString).deletingPathExtension + ".gom-entity.csv"
    }

    /// Bước 1: đề xuất cụm và sinh bảng duyệt. KHÔNG sửa gì cả.
    ///
    /// "Không sửa gì cả" là vế cứng của đặc tả — *"Không bao giờ tự merge — mọi thứ qua duyệt"*
    /// — và nó có một bài tự kiểm so tệp đồ thị trên đĩa trước và sau bước này.
    private func proposeEntityResolution(_ csr: GraphCSR) {
        guard let graph = dotGraph, let path = editorDocument.path else {
            return showTransient(L("Tài liệu chưa lưu — bảng duyệt cần nằm cạnh tệp đồ thị"))
        }
        // Số lần xuất hiện = bậc của node. Một entity có nhiều quan hệ hơn thì thường là dạng
        // người ta dùng nhiều hơn, và đó là đề xuất hợp lý cho dạng chuẩn.
        var counts: [String: Int] = [:]
        for node in 0 ..< csr.nodeCount { counts[csr.displays[node]] = csr.degree(node) }

        let clusters = EntityResolution.clusters(graph.nodes.map(\.display), counts: counts)
        guard !clusters.isEmpty else {
            return showTransient(L("Không tìm thấy biến thể nào để gom"))
        }
        let review = MainWindowController.resolutionReviewPath(forGraph: path)
        do {
            try AtomicFileWriter.write(
                Array(EntityResolution.reviewCSV(clusters).utf8), to: review)
        } catch {
            return showTransient(LF("Không ghi được: %@", "\(error)"))
        }
        openInNewTab(path: review)
        showBanner(
            LF("%d cụm biến thể — sửa cột «canonical» rồi chạy «Áp bảng duyệt»",
                   clusters.count),
            actionTitle: nil, action: nil)
    }

    /// Bước 3: đọc bảng ĐÃ DUYỆT và áp — MỘT bước undo.
    ///
    /// Hỏi trước khi ghi, và câu hỏi nói ra PHÉP GỘP. Lượt chạy không người thì `Unattended.ask`
    /// trả `.abort` và không gì được áp — đúng như phải thế: một phép gộp node không hoàn tác
    /// được bằng cách gõ lại.
    private func applyEntityResolution(confirmed: Bool = false) {
        guard let graph = dotGraph, let path = editorDocument.path else { return }
        let review = MainWindowController.resolutionReviewPath(forGraph: path)
        guard let csv = try? String(contentsOfFile: review, encoding: .utf8) else {
            return showTransient(String(
                format: L("Chưa có bảng duyệt «%@» — chạy «Gom biến thể entity» trước"),
                (review as NSString).lastPathComponent))
        }
        let mapping: [String: String]
        do {
            mapping = try EntityResolution.parseReview(csv)
        } catch {
            let reason = (error as? EntityResolution.Failure)?.message ?? "\(error)"
            return showTransient(LF("Bảng duyệt không đọc được: %@", reason))
        }
        guard !mapping.isEmpty else {
            return showTransient(L("Bảng duyệt không có dòng nào cần đổi"))
        }
        let text = editorDocument.buffer.text
        let changeset = EntityResolution.changeset(
            mapping: mapping, dotText: text, graph: graph)
        guard !changeset.edits.isEmpty else {
            return showTransient(L("Không có chỗ nào trên đồ thị khớp bảng duyệt"))
        }
        guard confirmed || confirmResolution(changeset, mapping: mapping) else { return }

        // MỘT bước undo cho cả changeset — nửa vời thì tệp đồ thị thành một trạng thái không ai
        // khai bao giờ.
        let updated = EntityResolution.apply(changeset.edits, to: text)
        editorDocument.buffer.replace(
            0 ..< editorDocument.buffer.count, with: updated, label: L("Gom biến thể entity"))
        syncViewFromBuffer()
        refreshMermaidPreview()

        // Đầu ra thứ hai và thứ ba, sinh CÙNG LÚC với đầu ra thứ nhất.
        let base = (path as NSString).deletingPathExtension
        try? AtomicFileWriter.write(Array(changeset.aliasCSV.utf8), to: base + ".alias.csv")
        try? AtomicFileWriter.write(
            Array((changeset.markers.joined(separator: "\n") + "\n").utf8),
            to: base + ".markers.txt")
        showBanner(
            LF("Đã áp %d thay đổi · bảng alias và danh sách marker ghi cạnh tệp",
                   changeset.edits.count),
            actionTitle: nil, action: nil)
    }

    /// Hộp hỏi, và nó KỂ TÊN từng phép gộp.
    private func confirmResolution(
        _ changeset: EntityResolution.Changeset, mapping: [String: String]
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(
            format: L("Áp %d thay đổi lên đồ thị?"), changeset.edits.count)
        var detail = [LF("%d alias → dạng chuẩn.", mapping.count)]
        if !changeset.merges.isEmpty {
            detail.append(L("GỘP node (không hoàn tác được bằng cách gõ lại):"))
            detail.append(contentsOf: changeset.merges.prefix(8))
        }
        if !changeset.unknownAliases.isEmpty {
            detail.append(String(
                format: L("%d alias không có trên đồ thị, bị bỏ qua."),
                changeset.unknownAliases.count))
        }
        alert.informativeText = detail.joined(separator: "\n")
        alert.addButton(withTitle: L("Huỷ"))
        alert.addButton(withTitle: L("Áp"))
        return Unattended.ask(alert) == .alertSecondButtonReturn
    }

    /// Chấm sức khoẻ đồ thị và ĐƯA LỖI VÀO DANH SÁCH BẤM-NHẢY — FR-KNW-924.
    ///
    /// Lỗi đi vào chính danh sách kết quả tìm kiếm trong thư mục, chứ không vào một bảng mới:
    /// người dùng đã biết bấm một dòng ở đó thì con nháy nhảy tới, và một bảng thứ hai với cùng
    /// hành vi là một thứ nữa phải học.
    private func runGraphQuality() {
        guard let graph = dotGraph else { return }
        let report = GraphQuality.run(graph)
        graphQualityReport = report

        // Dùng LẠI panel kết quả tìm-trong-thư-mục thay vì dựng bảng thứ hai.
        //
        // Ngữ nghĩa khớp hẳn: đây là "một danh sách vị trí trong tệp, bấm để nhảy tới", đúng
        // thứ panel ấy làm. Người dùng đã học hành vi của nó rồi; một bảng thứ hai với cùng
        // hành vi là một thứ nữa phải học và một chỗ nữa để hai bên trôi khỏi nhau.
        let path = editorDocument.path ?? ""
        let buffer = editorDocument.buffer
        let hits = report.problems.map { problem -> FindInFiles.Hit in
            let line = min(max(0, problem.line), max(0, buffer.lineCount - 1))
            let range = buffer.contentRange(ofLine: line)
            return FindInFiles.Hit(
                byteRange: range.lowerBound ..< range.lowerBound, line: line + 1,
                byteColumn: 1,
                lineText: problem.kind.vietnamese + " — " + problem.detail)
        }
        attachResultsPanel()
        resultsView.isHidden = false
        resultsHeight.constant = panelOpenHeight(.results)
        presentSearchResults(
            FindInFiles.Summary(
                results: hits.isEmpty ? [] : [FindInFiles.FileResult(path: path, hits: hits)],
                filesScanned: 1),
            pattern: L("sức khoẻ đồ thị"))

        let total = report.score.total.map { String(format: "%.0f", $0) } ?? "—"
        mermaidPanel.showNote(
            LF("Sức khoẻ %@/100 · %d lỗi · %d đảo · %d mồ côi",
                   total, report.problems.count, report.islands, report.orphans.count)
            + " — " + GraphQuality.methodology(report))
    }

    /// Áp màu và viền lên sơ đồ, rồi vẽ lại.
    ///
    /// Chú giải hiện CÙNG hình, không nằm ở một chỗ khác: một bản đồ màu mà người xem phải đi
    /// tìm chú giải là một bản đồ họ sẽ đoán bừa.
    private func applyGraphStyles(_ csr: GraphCSR) {
        let result = GraphOverlay.styles(
            for: csr, communities: graphCommunities?.labels, pageRank: graphPageRank?.scores)
        graphStyles = result.styles
        refreshMermaidPreview()
        if !result.legend.lines.isEmpty {
            mermaidPanel.showNote(result.legend.lines.joined(separator: " · "))
        }
    }

    private func exportGraphNodeTable(_ csr: GraphCSR) {
        let csv = GraphOverlay.nodeTableCSV(
            for: csr, pageRank: graphPageRank, communities: graphCommunities,
            components: graphComponents)
        openTextInNewTab(csv, label: "bang-node.csv")
    }

    // MARK: - Truy vấn Cypher trên đồ thị (FR-KNW-913)

    /// Thư mục chứa `node.csv` và `edge.csv` của lượt truy vấn gần nhất.
    ///
    /// Giữ lại giữa các lượt để người dùng SỬA TIẾP câu SQL trong Query Workbench mà bảng vẫn
    /// còn — đó là cả điểm của "vừa dùng vừa học". Dọn khi tài liệu đổi.
    private static var graphTablesFolder: String?

    /// Chạy một truy vấn Cypher: dịch → hiện SQL → chạy → tô sáng.
    ///
    /// Bốn bước ấy đều phải thấy được. Đặc tả đòi *"câu SQL sinh ra LUÔN hiển thị và sửa tiếp
    /// được"*, nên SQL vào thẳng ô của Query Workbench chứ không chỉ chạy ngầm; và kết quả tô
    /// sáng ngược lên sơ đồ, vì một bảng tên node cạnh một hình vẽ mà không nối với nhau thì
    /// người đọc phải tự dò.
    func runCypherQuery(_ text: String) {
        guard let graph = dotGraph else {
            return showTransient(L("Tài liệu này không phải đồ thị DOT"))
        }
        let query: CypherQuery
        let translation: CypherSQL.Translation
        do {
            query = try CypherQuery.parse(text)
            translation = try CypherSQL.translate(query)
        } catch let failure as CypherQuery.Failure {
            return mermaidPanel.showFailure("Cypher: " + failure.message)
        } catch let failure as CypherSQL.Failure {
            return mermaidPanel.showFailure("Cypher: " + failure.message)
        } catch {
            return mermaidPanel.showFailure("Cypher: \(error)")
        }

        // SQL vào ô truy vấn TRƯỚC khi chạy — nếu lượt chạy hỏng, người dùng vẫn có câu SQL
        // trong tay để sửa. Đưa sau thì một lỗi DuckDB sẽ để lại ô trống.
        attachSQLPanel()
        sqlPanel.isHidden = false
        sqlHeight.constant = panelOpenHeight(.sql)
        sqlPanel.setQuery(translation.sql)

        let folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("geditor-graph-\(editorDocument.id)")
        let sources: [String: String]
        do {
            sources = try CypherSQL.materialize(graph, in: folder)
        } catch {
            return mermaidPanel.showFailure(
                LF("Không dựng được bảng node/cạnh: %@", "\(error)"))
        }
        MainWindowController.graphTablesFolder = folder

        do {
            let result = try CSVQueryEngine.run(
                translation.sql,
                in: TextBuffer(original: MemoryByteSource(Array("x\n1\n".utf8))),
                dialect: .comma, extraSources: sources)
            sqlPanel.present(result, milliseconds: result.milliseconds)
            highlightGraphResult(result, translation: translation)
            mermaidPanel.showNote(
                LF("%d hàng · %@", result.rows.count,
                       translation.plan.joined(separator: " · ")))
        } catch let failure as CSVQueryEngine.Failure {
            sqlPanel.presentFailure(failure.message, query: translation.sql)
            mermaidPanel.showFailure(failure.message)
        } catch {
            mermaidPanel.showFailure("\(error)")
        }
    }

    /// Tô sáng node/cạnh khớp ngay trên sơ đồ.
    ///
    /// Tô theo CHỮ hiện trên phần tử, cùng đường mà FR-MMD-002 đã dùng — nên nó chịu đúng giới
    /// hạn đã biết ở đó (hai node cùng nhãn thì cùng sáng), chứ không sinh ra một giới hạn mới.
    private func highlightGraphResult(
        _ result: CSVQueryEngine.Result, translation: CypherSQL.Translation
    ) {
        var words: [String] = []
        var seen = Set<String>()
        for (column, title) in result.titles.enumerated() {
            // Chỉ những cột trả về TÊN node mới dùng để tô sáng. Cột đếm, cột nhãn cạnh thì
            // không — tô sáng theo một con số sẽ làm sáng bừa những node có tên trùng con số ấy.
            let isNodeColumn = translation.nodeVariables.contains {
                title == $0 || title == "\($0).name"
            }
            guard isNodeColumn else { continue }
            for row in result.rows where column < row.count {
                guard let value = row[column], !value.isEmpty,
                      seen.insert(value).inserted else { continue }
                words.append(value)
            }
        }
        mermaidRenderer.focus(on: words)
    }

    /// Chọn bộ đánh giá rồi sinh một **báo cáo `.greport.md`** — FR-KNW-919.
    ///
    /// Sinh báo cáo chứ không hiện một bảng dùng một lần, và đó là đúng chữ trong đặc tả:
    /// *"báo cáo đánh giá **tái lập được**"*. Một bảng trên màn hình biến mất khi đóng panel;
    /// một tệp `.greport.md` thì nằm cạnh corpus, vào được git, và chạy lại bằng `geditor
    /// --report` để so với lần trước. Người dùng cũng sửa được k1/b/k ngay trong tệp ấy.
    /// Chọn tệp điểm ngoài rồi đi tiếp đúng đường của bộ đánh giá — FR-KNW-921.
    ///
    /// Hỏi tệp điểm TRƯỚC, bộ đánh giá SAU, vì bộ đánh giá thường đã có sẵn (builder đang mở
    /// hoặc tệp cạnh corpus) còn tệp điểm là thứ người dùng vừa sinh ra ở đâu đó.
    private func chooseExternalScores() {
        guard retrievalCorpusPath != nil else {
            return retrievalPanel.presentUnusable(
                L("Tài liệu chưa lưu — cần đường dẫn corpus để sinh báo cáo"))
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = L("Chọn tệp điểm ngoài (JSONL: query, chunk_id, score)")
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        chooseGoldenSet(external: url.path)
    }

    private func chooseGoldenSet(external: String? = nil) {
        guard let corpus = retrievalCorpusPath else {
            retrievalPanel.presentUnusable(
                L("Tài liệu chưa lưu — cần đường dẫn corpus để sinh báo cáo"))
            return
        }
        // Đang dựng bộ đánh giá thì DÙNG LUÔN nó — đúng câu «nút Chạy đánh giá ngay từ
        // builder» của FR-KNW-926. Hỏi lại đường dẫn ở đây là hỏi một câu mà người dùng vừa
        // trả lời bằng chính việc họ đang làm.
        if let builder = goldenBuilder, !builder.queries.isEmpty {
            return makeRetrievalReport(
                corpus: corpus, golden: builder.path, external: external)
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = L("Chọn bộ đánh giá (CSV hoặc JSONL: câu hỏi + id chunk kỳ vọng)")
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        makeRetrievalReport(corpus: corpus, golden: url.path, external: external)
    }

    func makeRetrievalReport(corpus: String, golden: String, external: String? = nil) {
        // Chuẩn hoá TRƯỚC khi so tiền tố. `deletingLastPathComponent` đã gộp `//` thành `/`,
        // nên so một đường dẫn chưa chuẩn hoá với thư mục đã chuẩn hoá sẽ không khớp và mọi
        // đường dẫn rơi về dạng tuyệt đối — báo cáo khi ấy chỉ chạy được trên đúng máy này.
        let corpus = (corpus as NSString).standardizingPath
        let golden = (golden as NSString).standardizingPath
        let folder = (corpus as NSString).deletingLastPathComponent
        func relative(_ path: String) -> String {
            path.hasPrefix(folder + "/")
                ? String(path.dropFirst(folder.count + 1)) : path
        }
        let name = (corpus as NSString).lastPathComponent
        // Khối so hai HỆ (FR-KNW-921) hay so hai CẤU HÌNH — không bao giờ cả hai, vì một khối
        // chỉ có hai cột.
        let externalLine = external.map { "external: " + relative(($0 as NSString).standardizingPath) + "\n" } ?? ""
        let text = """
            # \(L("Đánh giá truy hồi")) — \(name)

            ```retrieval
            corpus: \(relative(corpus))
            golden: \(relative(golden))
            k: 10
            k1: \(RetrievalEval.trim(retrievalPanel.k1))
            b: \(RetrievalEval.trim(retrievalPanel.b))
            \(externalLine)worst: 15
            title: \(L("Đánh giá truy hồi")) — \(name)
            ```

            \(L("Sửa k1, b hoặc k ở trên rồi xem lại để so hai cấu hình; thêm khối «compare» để chạy song song hai bộ tham số trên cùng bộ đánh giá."))

            """
        openTextInNewTab(text, label: "danh-gia-truy-hoi." + ReportDocument.fileExtension)
    }

    // MARK: - Chế độ JSONL (FR-KNW-901, FR-KNW-902)

    @objc func showJSONLPanel(_ sender: Any?) {
        attachJSONLPanel()
        jsonlPanel.isHidden = false
        jsonlHeight.constant = panelOpenHeight(.jsonl)
        jsonlShownLine = -1
        updateJSONLRecord()
        runJSONLScan()
    }

    private func hideJSONLPanel() {
        jsonlCancelToken?.cancel()
        jsonlPanel.isHidden = true
        jsonlHeight?.constant = 0
    }

    var isJSONLPanelVisible: Bool { isAttached(.jsonl) && !jsonlPanel.isHidden }

    /// Kiểm cả tệp — chạy TRÊN LUỒNG CHÍNH, nhả nhịp giữa các lát.
    ///
    /// Không đẩy sang luồng nền, và đó là một quyết định chứ không phải sự lười: `TextBuffer`
    /// là cây piece của tài liệu đang mở, và người dùng gõ được vào nó bất cứ lúc nào. Quét nó
    /// từ luồng khác là mở ra một họ lỗi tranh chấp không tái hiện được — cùng lý do
    /// `runReportBatch` chạy ở luồng chính.
    ///
    /// Cái giá là phải tự nhả nhịp: bộ quét gọi lại mỗi 4 MB, và mỗi nhịp ấy vừa vẽ tiến độ
    /// vừa cho vòng lặp sự kiện chạy. Trên 1 GB đo được 244 nhịp cho 850 ms, tức khoảng 3,5 ms
    /// một nhịp — nút Huỷ ăn ngay.
    private func runJSONLScan() {
        let token = CancelToken()
        jsonlCancelToken = token
        jsonlPanel.presentScanning(0)
        let buffer = editorDocument.buffer
        let result = JSONLScan.scan(buffer: buffer, cancelToken: token) { [weak self] fraction in
            guard let self, !token.isCancelled else { return false }
            self.jsonlPanel.presentScanning(fraction)
            RunLoop.current.run(mode: .default, before: Date())
            return true
        }
        jsonlCancelToken = nil
        jsonlPanel.presentScan(result)
        guard !result.wasCancelled else { return }
        let inspection = ChunkInspector.inspect(buffer: buffer, cancelToken: token) {
            [weak self] fraction in
            guard let self, !token.isCancelled else { return false }
            self.jsonlPanel.presentScanning(fraction)
            RunLoop.current.run(mode: .default, before: Date())
            return true
        }
        jsonlPanel.presentInspection(inspection)
    }

    /// Con nháy đổi dòng thì đổi thẻ — FR-KNW-901 «xem record dạng thẻ song song văn bản thô».
    func updateJSONLRecord() {
        guard isJSONLPanelVisible, jsonlPanel.selectedTab == .record else { return }
        let line = editorDocument.buffer.lineNumber(
            atOffset: min(editorView.selectedDocumentRange.lowerBound,
                          max(0, editorDocument.buffer.count - 1)))
        guard line != jsonlShownLine else { return }
        jsonlShownLine = line
        let range = editorDocument.buffer.contentRange(ofLine: line)
        let raw = String(decoding: editorDocument.buffer.bytes(in: range), as: UTF8.self)
        jsonlPanel.presentRecord(
            line: line,
            pretty: JSONLScan.prettyRecord(buffer: editorDocument.buffer, line: line),
            raw: raw)
    }

    private func revealJSONLLine(_ line: Int) {
        guard line >= 0, line < editorDocument.buffer.lineCount else { return }
        let offset = editorDocument.buffer.offset(ofLineStart: line)
        editorView.repaginate(around: offset)
        editorView.setCaret(documentOffset: offset)
        editorView.reveal(documentOffset: offset)
        jsonlShownLine = -1
        updateJSONLRecord()
    }

    // MARK: - Móc cho bài tự kiểm

    var retrievalResultTextForSelfTest: String { retrievalPanel.resultTextForSelfTest }
    var retrievalSummaryForSelfTest: String { retrievalPanel.summaryForSelfTest }
    var retrievalTuningNoteForSelfTest: String { retrievalPanel.tuningNoteForSelfTest }
    var retrievalHighlightsForSelfTest: [NSRange] { retrievalPanel.highlightRangesForSelfTest }
    var goldenQueriesForSelfTest: [RetrievalEval.Query] { goldenBuilder?.queries ?? [] }
    var goldenPathForSelfTest: String { goldenBuilder?.path ?? "" }
    var goldenCoverageForSelfTest: String { retrievalPanel.coverageForSelfTest }
    var canSaveGoldenRecordForSelfTest: Bool { retrievalPanel.canSaveForSelfTest }

    func setLabellingForSelfTest(_ on: Bool) { retrievalPanel.setLabellingForSelfTest(on) }
    func clickRetrievalHitForSelfTest(rank: Int) { retrievalPanel.clickHitForSelfTest(rank: rank) }
    func setGoldenNoteForSelfTest(_ text: String) { retrievalPanel.setNoteForSelfTest(text) }
    func saveGoldenRecordForSelfTest() { retrievalPanel.saveLabelForSelfTest() }
    func evaluateFromBuilderForSelfTest() { chooseGoldenSet() }
    /// FR-KNW-921 — bỏ qua ĐÚNG hộp chọn tệp; phần còn lại đi đường thật.
    func makeExternalReportForSelfTest(corpus: String, golden: String, external: String) {
        makeRetrievalReport(corpus: corpus, golden: golden, external: external)
    }
    func evaluateForSelfTest(_ action: RetrievalPanel.EvaluateAction) {
        retrievalPanel.evaluateForSelfTest(action)
    }

    // FR-KNW-913
    func runCypherForSelfTest(_ text: String) { mermaidPanel.setCypherForSelfTest(text) }
    var sqlQueryForSelfTest: String { sqlPanel.query }
    var isCypherBarVisibleForSelfTest: Bool { mermaidPanel.isCypherBarVisibleForSelfTest }
    var sqlRowCountForSelfTest: Int? { sqlPanel.optionalRowCountForSelfTest }

    // FR-KNW-914
    func runGraphAlgorithmForSelfTest(_ choice: MermaidPanel.Algorithm) {
        mermaidPanel.runAlgorithmForSelfTest(choice)
    }
    var graphStylesForSelfTest: DOTToMermaid.NodeStyles { graphStyles }
    var graphCSRNodeCountForSelfTest: Int { graphCSR?.nodeCount ?? -1 }
    var graphQualityProblemsForSelfTest: [GraphQuality.Problem] {
        graphQualityReport?.problems ?? []
    }
    var graphQualityScoreForSelfTest: Double? { graphQualityReport?.score.total }
    var searchResultRowsForSelfTest: [String] { resultsView.rowTextsForSelfTest }
    var searchResultsVisibleForSelfTest: Bool { !resultsView.isHidden }
    /// Panel Column Editor đang mở — bài tự kiểm điền vào nó rồi bấm OK.
    var columnEditorPanelForSelfTest: ColumnEditorPanel? { columnEditorPanel }
    /// Đẩy thẳng một kết quả tìm dựng sẵn vào panel, không phải quét đĩa.
    ///
    /// Có mặt vì đường thật (`startFindInFiles`) đi qua một hộp chọn thư mục và một tác vụ nền;
    /// bài kiểm cần vế HIỂN THỊ, và trộn hai thứ ấy vào một bài thì lúc nó đỏ không biết đỏ vì
    /// bên nào. Đường quét đĩa đã có bài kiểm riêng ở lõi (`FindInFiles`).
    func showSearchResultsForSelfTest(_ summary: FindInFiles.Summary, pattern: String) {
        showResultsPanel()
        presentSearchResults(summary, pattern: pattern)
    }
    /// Lịch sử lượt tìm như người dùng thấy nó trong popup.
    var searchHistoryTitlesForSelfTest: [String] { resultsView.historyTitlesForSelfTest }
    /// Bấm một mục trong popup lịch sử — đi qua đúng đường con chuột đi.
    func selectSearchHistoryForSelfTest(_ index: Int) {
        resultsView.selectHistoryForSelfTest(index)
    }
    /// Bấm nút «Xuất».
    func exportSearchResultsForSelfTest() { resultsView.exportForSelfTest() }
    /// Dòng tóm tắt đang hiện trên panel kết quả.
    var searchResultsSummaryForSelfTest: String { resultsView.summaryForSelfTest }

    func showSearchRunningForSelfTest(_ message: String) {
        showResultsPanel()
        resultsView.showRunning(message)
    }
    func showSearchMessageForSelfTest(_ message: String, isError: Bool) {
        showResultsPanel()
        resultsView.showMessage(message, isError: isError)
    }

    func askRetrievalForSelfTest(_ query: String) {
        retrievalPanel.setQueryForSelfTest(query)
    }

    func setHybridForSelfTest(_ on: Bool, alpha: Double) {
        retrievalPanel.setHybridForSelfTest(on, alpha: alpha)
    }
    var isHybridOnForSelfTest: Bool { isHybridOn }
    func runGraphRAGForSelfTest(_ action: RetrievalPanel.GraphRAGAction) {
        retrievalPanel.runGraphRAGForSelfTest(action)
    }

    func tuneRetrievalForSelfTest(k1: Double, b: Double) {
        retrievalPanel.setTuningForSelfTest(k1: k1, b: b)
    }

    /// Chữ đang hiện trên thẻ bản ghi.
    var jsonlCardTextForSelfTest: String { jsonlPanel.cardTextForSelfTest }
    /// Những dòng đang nằm trong danh sách bấm-để-nhảy.
    var jsonlListedLinesForSelfTest: [Int] { jsonlPanel.listedLinesForSelfTest }
    var jsonlSummaryForSelfTest: String { jsonlPanel.summaryForSelfTest }

    func selectJSONLTabForSelfTest(_ tab: JSONLPanel.Tab) {
        jsonlPanel.selectTabForSelfTest(tab)
    }

    func selectJSONLLineForSelfTest(_ line: Int) { revealJSONLLine(line) }

    func runJSONLFilterForSelfTest(field: String, value: String) {
        runJSONLFilter(field: field, value: value)
    }

    private func runJSONLFilter(field: String, value: String) {
        let lines = ChunkInspector.lines(
            buffer: editorDocument.buffer, field: field, equals: value)
        jsonlPanel.presentFilter(field: field, value: value, lines: lines)
    }

    @objc func showJSONPathPanel(_ sender: Any?) {
        attachJSONPathPanel()
        jsonPathPanel.isHidden = false
        jsonPathHeight.constant = panelOpenHeight(.jsonPath)
        jsonPathPanel.focusField()

        // Nói ngay nếu tài liệu không dùng được, thay vì đợi người dùng gõ một truy vấn rồi mới
        // báo. Họ sẽ tưởng truy vấn của mình sai.
        if let reason = jsonIndexFailureReason() {
            jsonPathPanel.presentUnusable(reason)
        }
    }

    private func hideJSONPathPanel() {
        jsonPathPanel.isHidden = true
        jsonPathHeight?.constant = 0
    }

    /// Chỉ mục dùng được, hoặc `nil` kèm lý do đã hiện lên panel.
    private func currentJSONIndex() -> (index: JSONIndex, bytes: [UInt8])? {
        let identity = editorDocument.buffer.id
        let revision = editorDocument.buffer.revision
        if let cached = cachedJSONIndex, cached.buffer == identity, cached.revision == revision {
            return (cached.index, cached.bytes)
        }
        let bytes = Array(editorDocument.buffer.text.utf8)
        let index = JSONIndex(bytes: bytes)
        guard index.failure == nil, !index.tooLarge else { return nil }
        cachedJSONIndex = (identity, revision, index, bytes)
        return (index, bytes)
    }

    private func jsonIndexFailureReason() -> String? {
        let bytes = Array(editorDocument.buffer.text.utf8)
        let index = JSONIndex(bytes: bytes)
        if index.tooLarge {
            return "File lớn hơn \(JSONIndex.sizeLimit / 1024 / 1024) MB — không dựng chỉ mục JSON"
        }
        if let failure = index.failure {
            return "Không phải JSON hợp lệ — dòng \(failure.line): \(failure.message)"
        }
        return nil
    }

    private func runJSONPathQuery(_ query: String) {
        guard let (index, bytes) = currentJSONIndex() else {
            jsonPathPanel.presentUnusable(jsonIndexFailureReason() ?? "Không đọc được tài liệu")
            return
        }
        do {
            jsonPathPanel.present(try JSONPath.run(query, on: index, bytes: bytes), query: query)
        } catch let failure as JSONPath.Failure {
            jsonPathPanel.presentFailure(failure, query: query)
        } catch {
            jsonPathPanel.presentUnusable("Không chạy được truy vấn")
        }
    }

    private func revealJSONPathMatch(_ match: JSONPath.Match) {
        revealOffset(match.range.lowerBound)
        // Bôi sáng cả giá trị chứ không chỉ đặt con nháy: một object khớp có thể dài mấy chục
        // dòng, và con nháy ở dòng đầu không nói được nó kéo tới đâu.
        editorView.setSelection(MultiSelection([match.range]))
        updateCaretStatus()
    }

    /// Xuất kết quả ra TAB MỚI (NFR-QRY-03 — truy vấn không bao giờ sửa file nguồn).
    private func exportJSONPathMatches(_ matches: [JSONPath.Match]) {
        guard let (_, bytes) = currentJSONIndex(), !matches.isEmpty else { return }
        var out = "[\n"
        for (i, match) in matches.enumerated() {
            let value = String(decoding: bytes[match.range], as: UTF8.self)
            // Giữ NGUYÊN VĂN từng giá trị, kể cả `1.0` và thứ tự khóa — cùng nguyên tắc với
            // `JSONTool`, và cùng lý do: người dùng muốn thấy đúng thứ có trong file.
            out += "  " + value + (i == matches.count - 1 ? "" : ",") + "\n"
        }
        out += "]\n"
        openTextInNewTab(out, label: "ketqua.json")
    }

    // MARK: - Truy vấn SQL trên bảng CSV (FR-CSV-407 · ADR-11)

    @objc func showSQLPanel(_ sender: Any?) {
        attachSQLPanel()
        // Nạp thư viện của workspace MỖI LẦN mở panel, không nạp một lần lúc khởi động: người
        // dùng đổi workspace giữa phiên, và một thư viện nạp sẵn sẽ là thư viện của thư mục cũ.
        // Cũng đúng lối "nạp lười" của ADR-08 — đọc một tệp JSON lúc khởi động cho một panel
        // phần lớn phiên không ai mở là đúng thứ ADR ấy gỡ ra.
        loadQueryLibrary()
        sqlPanel.isHidden = false
        sqlHeight.constant = panelOpenHeight(.sql)
        sqlPanel.focusField()
        if let reason = sqlUnusableReason() {
            sqlPanel.presentUnusable(reason)
        }
    }

    private func hideSQLPanel() {
        sqlToken?.cancel()
        sqlPanel.isHidden = true
        sqlHeight?.constant = 0
    }

    /// Vì sao tài liệu này không truy vấn được — `nil` nghĩa là được.
    ///
    /// Nói TRƯỚC khi người dùng gõ, không đợi họ viết xong một câu rồi mới báo: họ sẽ tưởng
    /// câu của mình sai. Cùng lối với panel JSONPath.
    private func sqlUnusableReason() -> String? {
        let buffer = editorDocument.buffer
        guard buffer.count > 0 else { return L("Tài liệu rỗng — không có bảng để truy vấn") }
        // Một dòng tiêu đề có ít nhất hai cột thì coi là bảng. Không đòi hơn: file CSV thật đủ
        // kiểu, và từ chối dựa trên phỏng đoán chặt hơn sẽ chặn nhầm file dùng được.
        let sample = buffer.bytes(in: 0 ..< Swift.min(buffer.count, 64 * 1024))
        let rows = CSVEngine.parse(sample, dialect: csvDialect, maxRows: 1)
        guard let header = rows.first, header.count >= 2 else {
            return L("Không nhận ra bảng CSV — dòng đầu chỉ có một cột")
        }
        return nil
    }

    private var queryLibraryURL: URL { AppPaths.queryLibraryFile(workspace: workspaceRoot) }

    func loadQueryLibrary() {
        queryLibrary = (try? QueryLibrary.load(from: queryLibraryURL)) ?? QueryLibrary()
        sqlPanel.setLibrary(queryLibrary)
    }

    /// Các tab CSV khác đang mở, đăng ký làm bảng phụ (FR-QRY-001 "mọi nguồn đang mở").
    ///
    /// Tên bảng suy từ TÊN FILE, nên phải lọc qua `isValidTableName` — tên file đặt được tuỳ ý,
    /// kể cả có dấu nháy. File nào không cho ra tên hợp lệ thì **bỏ qua trong im lặng**: bắt
    /// người dùng đổi tên file để mở được panel truy vấn là đòi hỏi vô lý, và một câu cảnh báo
    /// cho mỗi tab lạ sẽ thành tiếng ồn.
    private func openTabsAsSources() -> [String: String] {
        // Danh mục đăng ký tay ĐỨNG TRƯỚC: người dùng đặt tên nó, nên tên ấy thắng một tab tình
        // cờ trùng tên.
        var sources: [String: String] = queryCatalog.sources
        for case let path? in tabPathsForSelfTest where path != editorDocument.path {
            let name = ((path as NSString).lastPathComponent as NSString)
                .deletingPathExtension
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "-", with: "_")
            guard CSVQueryEngine.isValidTableName(name), sources[name] == nil else { continue }
            sources[name] = path
        }
        return sources
    }

    private func runSQLQuery(_ text: String) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        let sourcePath = editorDocument.path
        let sources = openTabsAsSources()

        // Thay tham số TRƯỚC khi kiểm: `:thang` không phải cú pháp SQL, nên kiểm câu còn nguyên
        // tham số sẽ luôn báo sai cú pháp.
        let values = sqlPanel.parameterValues
        let resolved = QueryParameters.substitute(text, values: values)
        let missing = QueryParameters.missing(in: text, values: values)
        if !missing.isEmpty {
            // Nói ra thay vì lặng lẽ chạy với NULL. Một câu `WHERE thang = NULL` không trả hàng
            // nào, và người dùng sẽ đi tìm lỗi trong dữ liệu.
            sqlPanel.presentFailure(
                LF("Chưa nhập giá trị cho tham số: %@",
                       missing.map { ":" + $0 }.joined(separator: ", ")),
                query: text)
            return
        }

        // Kiểm câu TRƯỚC khi ra luồng nền. `CSVQueryEngine.validate` bọc câu vào `LIMIT 0` nên
        // DuckDB vẫn giải hết tên cột mà không đọc hàng nào: câu sai cú pháp hoặc sai tên cột
        // được báo tức thì, thay vì bắt người dùng nhìn "Đang chạy…" rồi mới biết mình gõ nhầm.
        do {
            try CSVQueryEngine.validate(
                resolved, in: buffer, dialect: dialect, sourcePath: sourcePath,
                extraSources: sources)
        } catch let failure as CSVQueryEngine.Failure {
            return sqlPanel.presentFailure(failure.message, query: text)
        } catch {
            return sqlPanel.presentUnusable(L("Không kiểm được câu truy vấn"))
        }

        sqlToken?.cancel()
        let token = CancelToken()
        sqlToken = token
        sqlPanel.presentRunning()
        // Ra LUỒNG NỀN. Câu GROUP BY trên bảng lớn vẫn tốn hàng trăm mili-giây kể cả với
        // DuckDB, và một lượt chép buffer đã sửa ra file tạm thì lâu hơn thế nhiều.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome: Result<CSVQueryEngine.Result, Error>
            do {
                outcome = .success(try CSVQueryEngine.run(
                    resolved, in: buffer, dialect: dialect,
                    sourcePath: sourcePath, extraSources: sources, cancelToken: token))
            } catch {
                outcome = .failure(error)
            }
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                switch outcome {
                case .success(let result):
                    // Lấy giờ TỪ ENGINE chứ không bấm đồng hồ quanh lời gọi: khoản chép buffer
                    // ra file tạm không phải thời gian truy vấn, và gộp chúng lại sẽ báo một
                    // câu SQL 20 ms là "1,8 giây".
                    self.sqlPanel.present(result, milliseconds: result.milliseconds)
                    // Ghi lịch sử câu NGUYÊN BẢN, còn nguyên `:tham_số` — bấm lại một câu đã
                    // thay giá trị thì mất luôn tính tham số, và lịch sử thành hai chục bản sao
                    // của cùng một câu chỉ khác con số.
                    self.recordQuery(text)
                case .failure(let failure as CSVQueryEngine.Failure):
                    self.sqlPanel.presentFailure(failure.message, query: text)
                case .failure:
                    self.sqlPanel.presentUnusable(L("Truy vấn bị dừng giữa chừng"))
                }
            }
        }
    }

    private func recordQuery(_ sql: String) {
        queryLibrary.record(sql, at: ISO8601DateFormatter().string(from: Date()))
        try? queryLibrary.save(to: queryLibraryURL)
        sqlPanel.setLibrary(queryLibrary)
    }

    /// "Lưu câu này…" — hỏi tên rồi ghi vào thư viện của workspace.
    func saveNamedQuery(_ sql: String) {
        let alert = NSAlert()
        alert.messageText = L("Lưu câu truy vấn")
        alert.informativeText = L("Đặt tên để tìm lại sau. Trùng tên sẽ ghi đè.")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = L("Ví dụ: Doanh thu theo tỉnh")
        alert.accessoryView = input
        alert.addButton(withTitle: L("Huỷ"))
        alert.addButton(withTitle: L("Lưu"))
        guard Unattended.ask(alert) == .alertSecondButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        queryLibrary.save(name: name, sql: sql)
        try? queryLibrary.save(to: queryLibraryURL)
        sqlPanel.setLibrary(queryLibrary)
    }

    // MARK: - Pivot (FR-QRY-003) và danh mục bảng ảo (FR-QRY-005)

    /// Tên cột của tài liệu đang mở — nguồn cho pivot.
    private func currentColumnNames() -> [String] {
        (try? CSVQueryEngine.run(
            "SELECT * FROM \(CSVQueryEngine.tableName) LIMIT 0",
            in: editorDocument.buffer, dialect: csvDialect,
            sourcePath: editorDocument.path).titles) ?? []
    }

    func showPivotSheet() {
        let columns = currentColumnNames()
        guard !columns.isEmpty else {
            return showBanner(L("Không đọc được tên cột của bảng này."),
                              actionTitle: nil, action: nil)
        }
        let sheet = PivotSheet(columns: columns)
        pivotSheet = sheet
        sheet.present(in: window) { [weak self] sql in
            // Đưa câu vào ô, KHÔNG chạy. Người dùng đọc và sửa trước — đó là cả điểm của
            // "vừa dùng vừa học". Chạy ngay cũng lấy đi cơ hội sửa một câu sắp quét bảng lớn.
            self?.sqlPanel.setQuery(sql)
            self?.sqlPanel.focusField()
        }
    }

    func showCatalogSheet() {
        let alert = NSAlert()
        alert.messageText = L("Nguồn dữ liệu của truy vấn")
        var lines: [String] = [
            LF("«%@» — tài liệu đang mở", CSVQueryEngine.tableName),
        ]
        for table in queryCatalog.tables {
            let schema = table.columns.isEmpty
                ? ""
                : " (" + table.columns.prefix(6).map(\.name).joined(separator: ", ")
                    + (table.columns.count > 6 ? "…" : "") + ")"
            // Bảng CŨ phải hiện ra — một danh mục nói dối về schema tệ hơn một danh mục rỗng.
            let stale = table.isStale ? L("  ⚠️ file đã đổi kể từ khi đăng ký") : ""
            lines.append("«\(table.name)» — \((table.path as NSString).lastPathComponent)"
                + schema + stale)
        }
        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: L("Đóng"))
        alert.addButton(withTitle: L("Thêm file…"))
        if !queryCatalog.tables.isEmpty { alert.addButton(withTitle: L("Bỏ hết")) }
        let response = Unattended.ask(alert)
        if response == .alertSecondButtonReturn {
            addCatalogSource()
        } else if response == .alertThirdButtonReturn {
            for table in queryCatalog.tables { queryCatalog.remove(name: table.name) }
        }
    }

    private func addCatalogSource() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard Unattended.chooseFile(panel) == .OK else { return }
        for url in panel.urls {
            registerCatalogSource(path: url.path)
        }
    }

    @discardableResult
    func registerCatalogSource(path: String) -> Bool {
        guard let name = QueryCatalog.defaultName(forPath: path) else {
            showBanner(LF("Không suy được tên bảng từ «%@» — hãy đổi tên file.",
                              (path as NSString).lastPathComponent),
                       actionTitle: nil, action: nil)
            return false
        }
        // Suy schema NGAY lúc đăng ký: danh mục không có schema là một danh sách đường dẫn.
        let columns = (try? CSVQueryEngine.run(
            QueryCatalog.describeSQL(forPath: path),
            in: editorDocument.buffer, dialect: csvDialect))
            .map(QueryCatalog.columns(fromDescribe:)) ?? []
        do {
            try queryCatalog.register(path: path, name: name, columns: columns)
            return true
        } catch let failure as QueryCatalog.Failure {
            showBanner(failure.message, actionTitle: nil, action: nil)
            return false
        } catch {
            showBanner(error.localizedDescription, actionTitle: nil, action: nil)
            return false
        }
    }

    // MARK: - Biểu đồ (FR-QRY-004)

    /// Vẽ biểu đồ từ kết quả truy vấn ĐANG HIỆN.
    ///
    /// Từ kết quả chứ không từ tài liệu: đặc tả nói *"từ kết quả query hoặc cột đang chọn"*, và
    /// kết quả query là thứ người ta vừa nhìn — vẽ lại cả bảng gốc sau khi họ vừa lọc xuống năm
    /// dòng là vẽ thứ họ không hỏi.
    func showChart(for result: CSVQueryEngine.Result, title: String) {
        attachChartPanel()
        chartPanel.isHidden = false
        chartHeight.constant = panelOpenHeight(.chart)
        if !chartPanel.present(result, title: title) {
            showBanner(L("Bảng này không có cột số nào để vẽ."), actionTitle: nil, action: nil)
        }
    }

    func hideChartPanel() {
        chartHeight.constant = 0
        chartPanel.isHidden = true
    }

    private func exportChart(asPNG: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = asPNG ? "bieu-do.png" : "bieu-do.svg"
        panel.allowedContentTypes = []
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        do {
            if asPNG {
                guard let data = chartPanel.chart.pngData() else {
                    return showBanner(L("Không dựng được ảnh PNG."), actionTitle: nil, action: nil)
                }
                try data.write(to: url, options: .atomic)
            } else {
                try Data(chartPanel.chart.svgText().utf8).write(to: url, options: .atomic)
            }
            showTransient(LF("Đã lưu %@", url.lastPathComponent))
        } catch {
            showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
    }

    // MARK: - Bảng chất lượng dữ liệu (FR-DQR-001 · FR-DQR-002)

    /// Tệp quy tắc đặt CẠNH dữ liệu, cùng luật ADR-09 với theme và Cleaning Recipe.
    private var qualityRulesPath: String? {
        guard let path = editorDocument.path else { return nil }
        return (path as NSString).deletingLastPathComponent + "/.gquality.yaml"
    }

    @objc func showQualityReport(_ sender: Any?) {
        guard let rulesPath = qualityRulesPath else {
            return showBanner(
                L("Lưu tài liệu trước — bộ quy tắc chất lượng nằm cạnh file dữ liệu."),
                actionTitle: nil, action: nil)
        }
        guard let text = try? String(contentsOfFile: rulesPath, encoding: .utf8) else {
            // NÓI RÕ đường dẫn. "Không tìm thấy tệp quy tắc" mà không nói tìm ở đâu thì người
            // dùng không biết đặt nó vào chỗ nào.
            return showBanner(
                LF("Chưa có bộ quy tắc. Tạo tệp %@ rồi mở lại.", rulesPath),
                actionTitle: nil, action: nil)
        }

        let rules: QualityRules
        do {
            rules = try QualityRules.load(fromYAML: text)
        } catch let failure as QualityRules.Failure {
            return showBanner(failure.message, actionTitle: nil, action: nil)
        } catch {
            return showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }

        attachQualityPanel()
        qualityPanel.isHidden = false
        qualityHeight.constant = panelOpenHeight(.quality)

        qualityRules = rules
        scoreQuality(rules)
    }

    /// Chấm và đổ vào panel. Dùng chung cho lần mở đầu và cho mỗi vòng chấm lại của FR-DQR-006.
    ///
    /// Mỗi lượt chấm cũng **ghi một mốc vào lịch sử** — FR-DQR-004 nói *"mỗi lần chạy tự ghi
    /// snapshot"*. Kể cả lượt chấm lại sau một bước làm sạch: chuỗi mốc dày lên trong một buổi
    /// làm sạch chính là dấu vết của chu trình detect → clean → verify, và đó là thứ đáng giữ.
    @discardableResult
    private func scoreQuality(_ rules: QualityRules) -> QualityScore? {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        let sourcePath = editorDocument.path
        do {
            let report = try QualityEngine.evaluate(
                rules, in: buffer, dialect: dialect, sourcePath: sourcePath)
            let score = try QualityScorer.score(
                report, rules: rules, in: buffer, dialect: dialect, sourcePath: sourcePath)
            qualityReport = report
            qualityPanel.present(report, score: score)
            recordQualityHistory(report: report, score: score, rules: rules)
            return score
        } catch let failure as CSVQueryEngine.Failure {
            showBanner(failure.message, actionTitle: nil, action: nil)
        } catch {
            showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
        return nil
    }

    /// Ghi mốc vào `.gquality.history.jsonl` và nạp lại bảng xu hướng — FR-DQR-004.
    private func recordQualityHistory(
        report: QualityEngine.Report, score: QualityScore, rules: QualityRules
    ) {
        guard let rulesPath = qualityRulesPath else { return }
        let card = QualityCard.Result(
            report: report, score: score, rules: rules, rulesPath: rulesPath,
            sourcePath: editorDocument.path)
        // Buffer đang sửa dở thì KHÔNG băm tệp trên đĩa: nó là dấu vân của dữ liệu KHÁC với dữ
        // liệu vừa cho ra điểm số này.
        let drift = QualityHistory.record(
            card, rulesPath: rulesPath, hashSource: !editorDocument.isModified)
        qualityPanel.present(
            history: QualityHistory.read(path: QualityHistory.historyPath(forRules: rulesPath)))
        // Trôi dạt vượt ngưỡng thì NÓI RA ngay, không đợi người dùng mở sang tab xu hướng —
        // một cảnh báo chỉ hiện ở chỗ phải đi tìm mới thấy là một cảnh báo không tồn tại.
        if let first = drift.alerts.first {
            showBanner(
                drift.alerts.count > 1
                    ? first + LF(" (và %d cảnh báo nữa ở tab Xu hướng)",
                                     drift.alerts.count - 1)
                    : first,
                actionTitle: nil, action: nil)
        }
    }

    // MARK: - Vòng khép kín với Bàn làm sạch (FR-DQR-006)

    /// Bấm nút sửa của một luật TRƯỢT → mở ĐÚNG công cụ tương ứng.
    ///
    /// Bảng ánh xạ nằm ở `QualityFix` trong lõi, không ở đây: nó là quyết định về ý nghĩa
    /// (*"luật này hỏng thì công cụ nào sửa được"*), và ở lõi thì bài kiểm chạm được vào nó mà
    /// không phải dựng một cửa sổ.
    private func fixWithCleanBench(_ result: QualityEngine.RuleResult) {
        let tool = QualityFix.tool(for: result.rule)
        guard tool.isAutomatic else {
            // Không sửa tự động được thì làm việc DUY NHẤT còn giúp được: chỉ ra các dòng sai.
            if case let .manual(reason) = tool {
                showBanner(reason, actionTitle: nil, action: nil)
            }
            return revealViolations(of: result)
        }
        guard let column = tool.column else { return }
        let names = currentColumnNames()
        guard let index = names.firstIndex(of: column) else {
            return showBanner(
                LF("Không tìm thấy cột «%@» trong bảng này.", column),
                actionTitle: nil, action: nil)
        }

        switch tool {
        case .missingValues:
            // FR-CLN-002 — cùng một sheet mà Bàn làm sạch dùng, nên mọi thứ đã có: xem trước,
            // một bước undo, và ghi vào nhật ký công thức.
            showCleanBenchPanel()
            showCleanSheet(for: CSVCleanFinding(
                column: index, columnName: column,
                kind: .nulls(byPlaceholder: [:]), cells: result.violations,
                sampleCells: []))

        case .normalizeDates:
            showCleanBenchPanel()
            showCleanSheet(for: CSVCleanFinding(
                column: index, columnName: column,
                kind: .mixedDates(shapes: 2), cells: result.violations, sampleCells: []))

        case .deduplicate:
            deduplicateForQuality(result, column: column)

        case .replace:
            replaceForQuality(result, column: column)

        case .manual:
            break
        }
    }

    /// Mở Bàn làm sạch mà KHÔNG quét lại từ đầu nếu nó đang mở.
    private func showCleanBenchPanel() {
        guard !cleanPanelVisibleForSelfTest else { return }
        showCleanBench(nil)
    }

    /// `unique` trượt → khử trùng lặp (FR-CORE-006), rồi chấm lại.
    ///
    /// Khử trùng lặp làm việc trên DÒNG giống hệt nhau, còn luật `unique` nói về MỘT cột. Hai
    /// phạm vi ấy không trùng nhau: hai hàng cùng `ma_don` mà khác `doanh_thu` sẽ không bị xoá.
    /// Nên sau khi chạy, vòng verify nói thẳng còn bao nhiêu vi phạm — im lặng ở đây là để người
    /// dùng tin rằng đã sạch.
    private func deduplicateForQuality(_ result: QualityEngine.RuleResult, column: String) {
        let before = result.violations
        runOperation("Khử trùng lặp") {
            try DocumentOps.removeDuplicateLines(in: editorDocument.buffer)
        }
        guard let rules = qualityRules, let score = rescoreAfterFix(rules) else { return }
        let after = qualityReport?.results.first {
            $0.rule == result.rule
        }?.violations ?? 0
        if after == 0 {
            showTransient(String(
                format: L("Đã khử trùng lặp — «%@» nay không còn trùng. Điểm: %.0f/100"),
                column, score.total ?? 0))
        } else {
            showBanner(String(
                format: L("Khử trùng lặp xong nhưng «%@» vẫn còn %d hàng trùng (trước: %d) — "
                    + "những hàng ấy trùng KHOÁ chứ không trùng cả dòng, nên phải xem và chọn "
                    + "giữ hàng nào."), column, after, before),
                actionTitle: nil, action: nil)
            // Và TÔ luôn những hàng ấy: một câu "vẫn còn 3 hàng" mà không chỉ ra ba hàng nào
            // thì người dùng phải tự đi tìm thứ máy vừa đếm xong.
            if let latest = qualityReport?.results.first(where: { $0.rule == result.rule }) {
                revealViolations(of: latest)
            }
        }
    }

    /// `regex` / `in_set` trượt → hộp Thay thế có xem trước, nạp sẵn các GIÁ TRỊ đang sai.
    ///
    /// Nạp giá trị THẬT chứ không nạp mẫu của luật: mẫu `regex` mô tả cái ĐÚNG, nên muốn tìm cái
    /// sai bằng chính nó thì phải bọc một phủ định lồng nhau — thứ người dùng không đọc được và
    /// không sửa được.
    private func replaceForQuality(_ result: QualityEngine.RuleResult, column: String) {
        let values = (try? QualityEngine.violatingValues(
            for: result.rule, in: editorDocument.buffer, dialect: csvDialect,
            sourcePath: editorDocument.path, limit: 30)) ?? []
        guard !values.isEmpty else {
            return showBanner(
                L("Không đọc được giá trị nào đang vi phạm luật này."),
                actionTitle: nil, action: nil)
        }
        showFindPanel(nil)
        // Một giá trị thì tìm chữ THƯỜNG; nhiều giá trị thì mới cần regex. Bật regex cho một
        // chuỗi có dấu chấm hay dấu ngoặc là biến một phép tìm đúng thành một phép tìm khác.
        if values.count == 1 {
            findPanel.prefill(pattern: values[0], mode: .normal)
        } else {
            findPanel.prefill(
                pattern: values.map(escapedForRegex).joined(separator: "|"), mode: .regex)
        }
        revealViolations(of: result)
        findPanel.showStatus(String(
            format: L("%d giá trị sai ở cột «%@» — sửa ô Thay rồi bấm Xem trước"),
            values.count, column))
    }

    private func escapedForRegex(_ text: String) -> String {
        var out = ""
        for character in text {
            if "\\^$.|?*+()[]{}".contains(character) { out.append("\\") }
            out.append(character)
        }
        return out
    }

    /// Chấm lại sau một bước sửa — vế *"các rule liên quan TỰ CHẠY LẠI và điểm cập nhật ngay"*.
    ///
    /// Chấm lại TOÀN BỘ bộ luật chứ không chỉ những luật đụng tới cột vừa sửa. Lý do: điểm sáu
    /// chiều tính trên cả bảng, nên một lượt chấm bộ phận cho ra một điểm số không thuộc về bộ
    /// dữ liệu nào. Giá của nó nằm trong ngân sách — NFR-DQR-01 đo 312 ms cho 50 luật trên một
    /// triệu hàng, và một lần sửa là một thao tác của người, không phải một vòng lặp.
    @discardableResult
    private func rescoreAfterFix(_ rules: QualityRules) -> QualityScore? {
        guard qualityPanelVisibleForSelfTest else { return nil }
        return scoreQuality(rules)
    }

    /// Số luật sẽ được chấm lại khi sửa một cột — chỉ để nói ra, không để chấm bộ phận.
    func rulesTouchingForSelfTest(column: String) -> Int {
        guard let qualityRules else { return 0 }
        return QualityFix.rulesTouching(column: column, in: qualityRules).count
    }

    /// Chuỗi đang nằm trong ô Tìm — bài tự kiểm FR-DQR-006 đọc để biết hộp thay thế đã được
    /// nạp sẵn giá trị SAI hay chưa.
    var findFieldTextForSelfTest: String { findPanel.query.pattern }
    var findFieldModeIsRegexForSelfTest: Bool { findPanel.query.mode == .regex }

    func hideQualityPanel() {
        qualityHeight.constant = 0
        qualityPanel.isHidden = true
    }

    /// Bấm một luật → TÔ các dòng vi phạm và nhảy tới dòng đầu (FR-DQR-001).
    private func revealViolations(of result: QualityEngine.RuleResult) {
        guard result.failure == nil, result.violations > 0 else { return }
        let rows: [Int]
        do {
            rows = try QualityEngine.violatingRowNumbers(
                for: result.rule, in: editorDocument.buffer, dialect: csvDialect,
                sourcePath: editorDocument.path)
        } catch {
            return showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
        guard !rows.isEmpty else { return }

        // Số hàng DỮ LIỆU → số dòng TÀI LIỆU. Không cộng 1 cho dòng tiêu đề rồi thôi: một ô
        // bọc ngoặc có thể chứa xuống dòng, và khi ấy hàng thứ n KHÔNG nằm ở dòng thứ n+1.
        // `CSVRowIndex` biết chỗ thật vì nó đã quét theo luật CSV.
        guard let index = try? CSVRowIndex.build(
            in: editorDocument.buffer, dialect: csvDialect) else { return }
        var lines: [Int] = []
        var firstOffset: Int?
        for row in rows {
            guard let offset = index.rowStart(row, in: editorDocument.buffer) else { continue }
            if firstOffset == nil { firstOffset = offset }
            lines.append(editorDocument.buffer.lineNumber(atOffset: offset))
        }
        guard !lines.isEmpty else { return }

        var updated = marks
        updated.setActiveColor(0)
        for line in lines where updated.colors(at: line).isEmpty { updated.toggle(line) }
        marks = updated
        if let firstOffset { revealOffset(firstOffset) }
        showTransient(LF("Đã đánh dấu %d dòng vi phạm", lines.count))
    }

    // MARK: - Bất thường (FR-MIN-001)

    @objc func showAnomalies(_ sender: Any?) {
        let columns = currentColumnNames()
        guard !columns.isEmpty else {
            return showBanner(L("Không đọc được tên cột của bảng này."),
                              actionTitle: nil, action: nil)
        }
        let numeric = numericColumnNames()
        guard let first = numeric.first else {
            // Nói rõ vì sao KHÔNG làm được, chứ không mở một panel rỗng. Bảng toàn cột chữ là
            // trường hợp hợp lệ và thường gặp, không phải lỗi.
            return showBanner(
                L("Bảng này không có cột số nào để tìm bất thường."),
                actionTitle: nil, action: nil)
        }
        attachAnomalyPanel()
        anomalyPanel.isHidden = false
        anomalyHeight.constant = panelOpenHeight(.anomaly)
        anomalyColumns = numeric
        findAnomalies(in: first)
    }

    func hideAnomalyPanel() {
        anomalyHeight.constant = 0
        anomalyPanel.isHidden = true
    }

    /// Tên các cột KIỂU SỐ, hỏi thẳng DuckDB thay vì đoán từ nội dung.
    ///
    /// `DESCRIBE` cho ra kiểu mà chính engine sẽ dùng khi chạy truy vấn. Tự đoán bằng cách thử
    /// ép kiểu vài dòng đầu là cách sai kinh điển: một cột mã bưu chính `01234` trông như số ở
    /// mười dòng đầu và là chữ ở dòng thứ mười một.
    private func numericColumnNames() -> [String] {
        guard let described = try? CSVQueryEngine.run(
            "SELECT * FROM (DESCRIBE SELECT * FROM \(CSVQueryEngine.tableName))",
            in: editorDocument.buffer, dialect: csvDialect, sourcePath: editorDocument.path)
        else { return [] }
        let columns = QueryCatalog.columns(fromDescribe: described)
        return columns.filter { column in
            let type = column.type.uppercased()
            return type.contains("INT") || type.contains("DECIMAL") || type.contains("DOUBLE")
                || type.contains("FLOAT") || type.contains("REAL") || type.contains("HUGEINT")
        }.map(\.name)
    }

    /// Đọc một cột ra mảng `Double` — ĐÚNG MỘT LẦN cho mỗi lần đổi cột.
    ///
    /// Mọi lần kéo thanh trượt sau đó chạy lại phép thống kê trên mảng này, không chạm đĩa. Xem
    /// ghi chú đầu `AnomalyPanel` về vì sao đó là điều kiện của yêu cầu "xem trước ngay lập tức".
    private func findAnomalies(in column: String) {
        let values = readNumericColumn(column)
        guard !values.isEmpty else {
            return showBanner(
                LF("Không đọc được cột «%@».", column),
                actionTitle: nil, action: nil)
        }
        anomalyPanel.present(values: values, column: column, allColumns: anomalyColumns)
    }

    /// Đọc một cột thành mảng `Double`. Ô không phải số thành `nan` và bị các tầng trên bỏ qua.
    ///
    /// `TRY_CAST` chứ không `CAST`: một ô lạ trong cột số làm cả câu truy vấn hỏng, và khi ấy
    /// người dùng mất luôn cả tính năng vì một ô.
    private func readNumericColumn(_ column: String) -> [Double] {
        let quoted = "\"" + column.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        let sql = "SELECT TRY_CAST(\(quoted) AS DOUBLE) FROM \(CSVQueryEngine.tableName)"
        guard let result = try? CSVQueryEngine.run(
            sql, in: editorDocument.buffer, dialect: csvDialect,
            sourcePath: editorDocument.path) else { return [] }
        return result.rows.map { row -> Double in
            guard let text = row.first ?? nil, let value = Double(text) else { return .nan }
            return value
        }
    }

    /// Tô các dòng bất thường, MÀU THEO MỨC NẶNG (FR-MIN-001 vế b).
    private func markAnomalies(
        _ items: [(AnomalyDetector.Finding, AnomalyPanel.Severity)], reveal: Bool
    ) {
        guard !items.isEmpty else { return }
        guard let index = try? CSVRowIndex.build(
            in: editorDocument.buffer, dialect: csvDialect) else { return }
        var updated = marks
        var firstOffset: Int?
        var marked = 0
        for (finding, severity) in items {
            guard let offset = index.rowStart(finding.row, in: editorDocument.buffer)
            else { continue }
            if firstOffset == nil { firstOffset = offset }
            let line = editorDocument.buffer.lineNumber(atOffset: offset)
            updated.setActiveColor(severity.markColor)
            if updated.colors(at: line).isEmpty { updated.toggle(line) }
            marked += 1
        }
        marks = updated
        if reveal, let firstOffset { revealOffset(firstOffset) }
        showTransient(LF("Đã đánh dấu %d dòng bất thường", marked))
    }

    /// Xuất bảng bất thường ra TAB MỚI, kèm khối "Phương pháp" (FR-MIN-001 vế d, NFR-MIN-04).
    private func exportAnomalies(_ report: AnomalyDetector.Report) {
        // Khối phương pháp đi thành chú thích `#` ở đầu: người nhận tệp này phải đọc được cách
        // các con số ra đời, và DuckDB lẫn Excel đều bỏ qua dòng bắt đầu bằng `#`.
        var out = report.methodology
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "# " + $0 }.joined(separator: "\n") + "\n"
        out += "dong,gia_tri,diem,muc,vi_sao\n"
        for finding in report.findings {
            out += [String(finding.row + 2), ChartRender.number(finding.value),
                    ChartRender.number(finding.score),
                    anomalyPanel.severityForSelfTest(finding).vietnamese,
                    finding.explanation]
                .map(Self.csvEscaped).joined(separator: ",") + "\n"
        }
        openTextInNewTab(out, label: "bat-thuong.csv")
    }

    // MARK: - Báo cáo (FR-RPT-001 · 003 · 004 · 005)

    /// Tài liệu đang mở có phải một báo cáo không.
    ///
    /// Theo ĐUÔI TỆP chứ không theo nội dung: `.greport.md` là một hợp đồng, và đoán bằng cách
    /// dò khối ```query sẽ bật preview lên giữa một tài liệu Markdown bình thường có ví dụ SQL.
    var isReportDocument: Bool {
        (editorDocument.path ?? "").hasSuffix(ReportDocument.fileExtension)
    }

    @objc func toggleReportPreview(_ sender: Any?) {
        if reportPreviewAttached, reportPreviewWidth.constant > 0 {
            return hideReportPreview()
        }
        guard isReportDocument else {
            return showBanner(
                LF("Xem trước báo cáo cần tài liệu đuôi .%@",
                       ReportDocument.fileExtension),
                actionTitle: nil, action: nil)
        }
        hideMermaidPanel()
        attachReportPreview()
        bindSplitTrailing(to: reportPreview.leadingAnchor)
        reportPreview.isHidden = false
        // Một phần ba bề ngang, tối thiểu 360: hẹp hơn thì bảng trong báo cáo cuộn ngang liên
        // tục và preview không nói được gì về bố cục thật.
        reportPreviewWidth.constant = max(360, (window?.frame.width ?? 1200) / 3)
        refreshReportPreview()
    }

    func hideReportPreview() {
        reportPreviewWidth?.constant = 0
        reportPreview.isHidden = true
    }

    var isReportPreviewVisible: Bool {
        reportPreviewAttached && (reportPreviewWidth?.constant ?? 0) > 0
    }

    // MARK: - Mermaid Studio (FR-MMD-001 · FR-MMD-002)

    /// Tài liệu có sơ đồ để vẽ không: tệp `.mmd`, hoặc tệp bất kỳ có khối ` ```mermaid `.
    var hasMermaidContent: Bool {
        if (editorDocument.path ?? "").hasSuffix("." + MermaidDocument.fileExtension) {
            return true
        }
        // FR-KNW-905: tệp DOT/Graphviz cũng xem được trên chính bảng này — nó được chuyển sang
        // Mermaid rồi vẽ bằng cùng bộ vẽ (ADR-15 §7). Thiếu vế này thì bảng từ chối mở và câu
        // từ chối («chưa có khối ```mermaid nào») nói sai nguyên nhân.
        if DOTGraph.looksLikeDOT(editorDocument.buffer.text, path: editorDocument.path) {
            return true
        }
        return !MermaidDocument.blocks(in: editorDocument.buffer.text).isEmpty
    }

    @objc func toggleMermaidStudio(_ sender: Any?) {
        if mermaidPanelAttached, mermaidPanelWidth.constant > 0 {
            return hideMermaidPanel()
        }
        guard MermaidAsset.isAvailable else {
            // Thiếu tệp vendor thì NÓI RA và nói cả cách sửa. Mở một bảng trắng ở đây là cách
            // chắc chắn để người dùng đi tìm lỗi trong sơ đồ của họ.
            return showBanner(MermaidAsset.failureReason, actionTitle: nil, action: nil)
        }
        guard hasMermaidContent else {
            return showBanner(
                L("Tài liệu này không phải tệp .mmd, không phải DOT, và chưa có khối mermaid."),
                actionTitle: nil, action: nil)
        }
        hideReportPreview()
        hideDiagramTab()
        attachMermaidPanel()
        bindSplitTrailing(to: mermaidPanel.leadingAnchor)
        mermaidPanel.isHidden = false
        mermaidPanelWidth.constant = max(360, (window?.frame.width ?? 1200) / 3)
        if let view = mermaidRenderer.displayView { mermaidPanel.attach(view) }
        mermaidPanel.onCypher = { [weak self] text in self?.runCypherQuery(text) }
        mermaidPanel.onAlgorithm = { [weak self] choice in self?.runGraphAlgorithm(choice) }
        mermaidPanel.onVisualEditing = { [weak self] on in
            guard let self else { return }
            self.mermaidRenderer.isVisualEditing = on
            // Câu nói ra phụ thuộc LOẠI sơ đồ: kéo được thì bảo kéo, chỉ soạn text thì nói
            // thẳng là chỉ soạn text (FR-MMD-004 đòi đúng vế ấy).
            let notice = on ? self.visualEditingNotice() : L("Soạn trực quan đã tắt")
            self.lastVisualEditNoticeForSelfTest = notice
            self.showTransient(notice)
            self.refreshMermaidPropertyTable(for: on ? self.freshMermaidBlock() : nil)
        }
        mermaidRenderer.onGraphEdit = { [weak self] op, from, to, index in
            guard let self, self.mermaidPanel.isVisualEditing else { return }
            // Một cửa cho hai phương ngữ: tài liệu DOT đi `GraphEdit`, còn lại đi `MermaidEdit`.
            // Cùng cử chỉ, cùng luật "một thao tác một bước hoàn tác", khác đúng bộ sinh câu lệnh.
            if self.dotGraph != nil {
                self.handleGraphEditGesture(op, from: from, to: to)
            } else {
                self.handleMermaidGesture(op, from: from, to: to, index: index)
            }
        }
        refreshMermaidPreview()
    }

    func hideMermaidPanel() {
        mermaidPanelWidth?.constant = 0
        mermaidPanel.isHidden = true
    }

    // MARK: - Sơ đồ TRONG TAB — chế độ View của tệp `.mmd` và `.dot`

    /// Khung sơ đồ đang hiện, nếu có. Mọi lượt vẽ đi qua đây thay vì gọi thẳng `mermaidPanel`.
    ///
    /// Không nhân đôi đường vẽ cho tab: `refreshMermaidPreview` đã cõng cả nhánh DOT, nhánh khối
    /// mermaid trong Markdown, phép giải khối tham chiếu và phép gạch lỗi lên văn bản. Chép nó
    /// ra làm hai bản là chép cả bốn thứ ấy, rồi hai bản trôi khỏi nhau.
    var mermaidSurface: MermaidPanel? {
        if isDiagramTabVisible { return diagramTab }
        if isMermaidPanelVisible { return mermaidPanel }
        return nil
    }

    var isDiagramTabVisible: Bool { diagramTabAttached && !diagramTab.isHidden }

    private func attachDiagramTab() {
        guard !diagramTabAttached else { return }
        diagramTabAttached = true
        diagramTab.translatesAutoresizingMaskIntoConstraints = false
        diagramTab.onClose = { [weak self] in self?.hideDiagramTab() }
        diagramTab.onExport = { [weak self] choice in self?.exportMermaid(choice) }
        diagramTab.onChangeTheme = { [weak self] _ in self?.refreshMermaidPreview() }
        middleRow.addSubview(diagramTab)
        NSLayoutConstraint.activate([
            diagramTab.topAnchor.constraint(equalTo: splitView.topAnchor),
            diagramTab.leadingAnchor.constraint(equalTo: splitView.leadingAnchor),
            diagramTab.trailingAnchor.constraint(equalTo: splitView.trailingAnchor),
            diagramTab.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
        ])
    }

    func showDiagramTab() {
        guard MermaidAsset.isAvailable else {
            // Thiếu tệp vendor thì NÓI RA và nói cả cách sửa. Mở một khung trắng ở đây là cách
            // chắc chắn để người dùng đi tìm lỗi trong sơ đồ của họ.
            return showBanner(MermaidAsset.failureReason, actionTitle: nil, action: nil)
        }
        // Bộ vẽ chỉ có một `WKWebView`. Bảng bên cạnh phải tắt TRƯỚC, không thì hai khung tranh
        // nhau cùng một view và cái thua hiện ra trống trơn.
        hideMermaidPanel()
        hideReportPreview()
        if csvTableAttached { csvTable.isHidden = true }
        attachDiagramTab()
        diagramTab.isHidden = false
        if let view = mermaidRenderer.displayView { diagramTab.attach(view) }
        splitView.isHidden = true
        refreshMermaidPreview()
    }

    func hideDiagramTab() {
        guard diagramTabAttached else { return }
        diagramTab.isHidden = true
        splitView.isHidden = false
    }

    var isMermaidPanelVisible: Bool {
        mermaidPanelAttached && (mermaidPanelWidth?.constant ?? 0) > 0
    }

    /// Ngôn ngữ tự định nghĩa: của NGƯỜI DÙNG trước, DỰNG SẴN sau.
    ///
    /// Thứ tự ấy là quyết định, không phải tình cờ: `UserDefinedLanguage.matching` lấy cái khớp
    /// ĐẦU TIÊN, nên một tệp `grammars/mermaid.json` do người dùng tự viết sẽ thắng bản dựng
    /// sẵn. Cùng luật với mọi thứ khác trong `grammars/` — tệp của họ là của họ, kể cả khi ta
    /// nghĩ bản của mình tốt hơn.
    static func loadGrammars() -> [UserDefinedLanguage] {
        // FR-KNW-904 nối thêm bốn grammar đồ thị SAU cùng, đúng luật ấy: tệp của người dùng
        // đứng trước và thắng.
        UserDefinedLanguage.all(in: AppPaths.grammarsDirectory)
            + [MermaidGrammar.language] + GraphGrammars.languages + [PromptFile.jinjaLanguage]
    }

    /// Vùng gấp của tài liệu, CỘNG khối frontmatter nếu có — FR-KNW-909.
    ///
    /// Frontmatter đi qua đây chứ không qua `FoldRanges.compute`: lõi tính vùng gấp theo NGÔN
    /// NGỮ, mà frontmatter là một quy ước của TỆP chứ không của ngôn ngữ — cùng một khối `---`
    /// hợp lệ trong `.md`, `.j2` và `.prompt`. Nhét nó vào `FoldRanges` sẽ bắt lõi biết về
    /// Markdown frontmatter ở mọi ngôn ngữ.
    func foldRangesIncludingFrontmatter() -> [FoldRange] {
        let base = FoldRanges.compute(in: editorDocument.buffer,
                                      language: editorView.syntaxLanguage)
        guard let fm = PromptFile.foldRange(in: editorDocument.buffer) else { return base }
        // Frontmatter đứng ĐẦU danh sách để nó là vùng ngoài cùng đầu tiên — `foldAll` và
        // "gấp theo cấp" đều đọc thứ tự này.
        return [fm] + base
    }

    /// Thẩm định tệp JSON đang mở theo một JSON Schema người dùng chọn — FR-KNW-909.
    ///
    /// Schema là một tệp RIÊNG người dùng chỉ ra, đúng câu chữ đặc tả: *"validate theo JSON
    /// Schema do người dùng chỉ định"*. Không đoán schema từ tên tệp — đoán sai nghĩa là báo một
    /// tràng lỗi cho một tệp vốn đúng.
    @objc func validateAgainstJSONSchema(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.message = L("Chọn tệp JSON Schema")
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url,
              let schema = try? String(contentsOf: url, encoding: .utf8) else { return }
        kiemTheoSchema(schema)
    }

    func kiemTheoSchema(_ schema: String) {
        let chan_doan = JSONSchemaCheck.validate(json: editorDocument.buffer.text, schema: schema)
        lastSchemaDiagnostics = chan_doan
        guard !chan_doan.isEmpty else {
            return showBanner(L("Không thấy lỗi nào theo schema này."), actionTitle: nil, action: nil)
        }
        let path = editorDocument.path ?? ""
        let hits = chan_doan.map {
            // Lỗi "schema dùng từ khoá chưa hiểu" được ĐÁNH DẤU RIÊNG: nó nói về SCHEMA, không
            // về dữ liệu, và trộn hai loại lại là dẫn người dùng đi sửa nhầm tệp.
            FindInFiles.Hit(byteRange: 0 ..< 0, line: $0.line + 1, byteColumn: 1,
                            lineText: ($0.unsupported ? "⚠ " : "") + "\($0.path): \($0.message)")
        }
        showSearchResultsForSelfTest(
            FindInFiles.Summary(results: [FindInFiles.FileResult(path: path, hits: hits)],
                                filesScanned: 1),
            pattern: L("JSON Schema"))
    }

    /// Thẩm định cú pháp tệp đồ thị đang mở — FR-KNW-904.
    ///
    /// Nhận loại theo ĐUÔI FILE và trả `nil` khi không biết: đoán bừa nghĩa là một tệp `.txt` bị
    /// thẩm định theo luật Cypher rồi báo hàng loạt lỗi vô nghĩa.
    ///
    /// Lỗi đổ vào **danh sách kết quả tìm** (`SearchResultsView`) chứ không dựng bảng thứ hai:
    /// ngữ nghĩa khớp hẳn — *"một danh sách vị trí trong tệp, bấm để nhảy tới"* — và đó cũng
    /// đúng lập luận FR-KNW-924 đã dùng khi đổ lỗi đồ thị vào chính panel ấy.
    @objc func validateGraphSyntax(_ sender: Any?) {
        guard let kind = GraphGrammars.Kind.forPath(editorDocument.path ?? "") else {
            return showBanner(
                L("Chưa nhận ra định dạng đồ thị — cần đuôi .dot, .gv, .cypher, .ttl hoặc .graphml."),
                actionTitle: nil, action: nil)
        }
        let chan_doan = GraphGrammars.validate(editorDocument.buffer.text, kind: kind)
        lastGraphDiagnostics = chan_doan
        guard !chan_doan.isEmpty else {
            // "Không thấy lỗi" KHÔNG phải "tệp hợp lệ" — với Turtle thì bộ kiểm là bộ kiểm NHẸ,
            // và nói quá ở đây là cho người dùng một lời bảo đảm ta không có.
            return showBanner(
                LF("Không thấy lỗi cú pháp %@ nào (phép kiểm không đầy đủ).",
                       kind.rawValue),
                actionTitle: nil, action: nil)
        }

        let path = editorDocument.path ?? ""
        let hits = chan_doan.map {
            FindInFiles.Hit(byteRange: 0 ..< 0, line: $0.line + 1, byteColumn: 1,
                            lineText: $0.message)
        }
        showSearchResultsForSelfTest(
            FindInFiles.Summary(results: [FindInFiles.FileResult(path: path, hits: hits)],
                                filesScanned: 1),
            pattern: LF("Cú pháp %@", kind.rawValue))
    }

    /// Định dạng lại mã sơ đồ — FR-MMD-006, MỘT bước undo như mọi lệnh format khác.
    @objc func formatMermaid(_ sender: Any?) {
        guard !editorDocument.isReadOnly else {
            return showBanner(L("Tài liệu đang ở chế độ chỉ đọc."), actionTitle: nil, action: nil)
        }
        let buffer = editorDocument.buffer
        let isDiagramFile = (editorDocument.path ?? "")
            .hasSuffix("." + MermaidDocument.fileExtension)
        let options = MermaidFormatter.Options()

        if isDiagramFile {
            let source = buffer.text
            let formatted = MermaidFormatter.format(source, options: options)
            guard formatted != source else {
                return showTransient(L("Mã sơ đồ đã đúng khuôn — không có gì để sửa"))
            }
            apply([TextEdit(range: 0 ..< buffer.count, text: formatted)],
                  label: "Định dạng sơ đồ Mermaid")
            return showTransient(L("Đã định dạng lại sơ đồ"))
        }

        // Tệp Markdown: chỉ đụng vào PHẦN TRONG hàng rào, không đụng một byte nào của văn xuôi.
        //
        // Sửa từ khối CUỐI lên khối đầu: mỗi lần thay làm mọi offset phía sau dịch đi, và đi
        // xuôi thì khối thứ hai trở đi bị áp vào chỗ sai.
        let blocks = MermaidDocument.blocks(in: buffer.text).filter { !$0.isEmpty }
        guard !blocks.isEmpty else {
            return showBanner(
                L("Tài liệu này không phải tệp .mmd, không phải DOT, và chưa có khối mermaid."),
                actionTitle: nil, action: nil)
        }
        var edits: [TextEdit] = []
        for block in blocks.reversed() {
            let formatted = MermaidFormatter.format(block.source, options: options)
            guard formatted != block.source else { continue }
            let lineCount = block.source.components(separatedBy: "\n").count
            let start = buffer.contentRange(ofLine: block.firstContentLine).lowerBound
            let lastLine = min(buffer.lineCount - 1, block.firstContentLine + lineCount - 1)
            let end = buffer.contentRange(ofLine: lastLine).upperBound
            guard start <= end else { continue }
            edits.append(TextEdit(range: start ..< end, text: formatted))
        }
        guard !edits.isEmpty else {
            return showTransient(L("Mã sơ đồ đã đúng khuôn — không có gì để sửa"))
        }
        // MỘT bước undo cho cả tệp, đúng như đặc tả đòi: "chạy như mọi lệnh format khác".
        apply(edits, label: "Định dạng sơ đồ Mermaid")
        showTransient(LF("Đã định dạng lại %d sơ đồ", edits.count))
        if isMermaidPanelVisible { refreshMermaidPreview() }
    }

    /// Thư viện mẫu sơ đồ — FR-MMD-005.
    @objc func showMermaidTemplates(_ sender: Any?) {
        guard !editorDocument.isReadOnly else {
            return showBanner(L("Tài liệu đang ở chế độ chỉ đọc."), actionTitle: nil, action: nil)
        }
        let sheet = MermaidTemplateSheet(preferring: mermaidKindAtCaret())
        mermaidTemplateSheet = sheet
        sheet.present(in: window) { [weak self] template in
            self?.insertMermaidTemplate(template)
        }
    }

    /// Loại sơ đồ mà con nháy đang đứng trong, để thư viện đưa mẫu của loại ấy lên đầu.
    private func mermaidKindAtCaret() -> MermaidDiagramKind? {
        guard let source = mermaidSourceAtCaret(),
              let declaration = MermaidDocument.declaration(in: source) else { return nil }
        return MermaidDiagramKind.from(declaration: declaration)
    }

    /// Chèn mẫu tại con nháy — MỘT bước undo.
    ///
    /// ## Mẫu ĐẦY ĐỦ tự bọc hàng rào ```mermaid, mẩu cú pháp thì KHÔNG
    ///
    /// Người dùng chèn một mẫu đầy đủ vào giữa một tệp Markdown thì thứ họ muốn là một sơ đồ
    /// hiện ra, mà không có hàng rào thì nó chỉ là mấy dòng chữ. Còn mẩu cú pháp luôn được chèn
    /// vào GIỮA một sơ đồ đang có — bọc hàng rào ở đó là tạo một khối lồng trong khối, và cả
    /// hai cùng hỏng.
    ///
    /// Tệp `.mmd` là ngoại lệ: cả tệp đã là một sơ đồ nên không có hàng rào nào cả.
    private func insertMermaidTemplate(_ template: MermaidTemplate) {
        let isDiagramFile = (editorDocument.path ?? "")
            .hasSuffix("." + MermaidDocument.fileExtension)
        let insideDiagram = mermaidSourceAtCaret() != nil
        var text = template.source
        if template.scope == .diagram, !isDiagramFile, !insideDiagram {
            text = "```mermaid\n" + text + "\n```"
        }
        let caret = editorView.selectedDocumentRange
        // Chèn ở ĐẦU DÒNG chứa con nháy khi dòng ấy đang có chữ: một mẫu chèn vào giữa dòng
        // làm hỏng cả dòng cũ lẫn mẫu.
        let line = editorDocument.buffer.lineNumber(atOffset: caret.lowerBound)
        let lineStart = editorDocument.buffer.contentRange(ofLine: line).lowerBound
        let prefixIsBlank = editorDocument.buffer
            .line(line).prefix(caret.lowerBound - lineStart)
            .allSatisfy { $0 == " " || $0 == "\t" }
        let at = prefixIsBlank ? caret.lowerBound : lineStart
        let body = prefixIsBlank ? text + "\n" : text + "\n"

        apply([TextEdit(range: at ..< max(at, caret.upperBound), text: body)],
              label: "Chèn mẫu «\(template.title)»")
        editorView.setCaret(documentOffset: at + body.utf8.count)
        updateCaretStatus()
        showTransient(LF("Đã chèn mẫu «%@»", template.title))
        // Mermaid Studio đang mở thì vẽ lại NGAY, không đợi người dùng gõ thêm một phím.
        if isMermaidPanelVisible { refreshMermaidPreview() }
    }

    // MARK: - Móc tự kiểm Mermaid

    func toggleMermaidStudioForSelfTest() { toggleMermaidStudio(nil) }

    /// Chờ tới khi lượt vẽ thứ `count` xong.
    ///
    /// Chờ theo SỐ LƯỢT ĐÃ XONG chứ không ngủ một khoảng cố định: mermaid vẽ mất vài chục
    /// mili-giây trên máy rảnh và vài trăm trên máy bận, nên một giấc ngủ cố định vừa làm bài
    /// kiểm chậm vừa thỉnh thoảng đỏ.
    @discardableResult
    func waitForMermaidRenderForSelfTest(atLeast count: Int, seconds: Double = 30) -> Bool {
        waitForSelfTest("mermaid render", seconds: seconds) {
            self.mermaidRenderer.renderCount >= count
                || self.mermaidRenderer.failureReason != nil
        }
    }

    /// Số lượt vẽ đã xong tính từ đầu phiên.
    ///
    /// Có mặt vì `waitForMermaidRenderForSelfTest(atLeast:)` đếm LUỸ KẾ: với bài chạy sau, một
    /// ngưỡng tuyệt đối như `atLeast: 1` đã thoả từ trước và phép chờ trả về ngay — bài kiểm
    /// khi ấy đọc trạng thái của lượt vẽ TRƯỚC. Bài mới chờ theo CHÊNH LỆCH.
    var mermaidRenderCountForSelfTest: Int { mermaidRenderer.renderCount }

    /// Mở Mermaid Studio, KHÔNG bật/tắt.
    ///
    /// `toggleMermaidStudioForSelfTest` lật trạng thái, nên một bài chạy sau một bài đã mở
    /// panel sẽ ĐÓNG nó — và thất bại với lý do "không mở được", một câu nói sai về nguyên nhân.
    func openMermaidStudioForSelfTest() {
        if !isMermaidPanelVisible { toggleMermaidStudio(nil) }
    }

    var mermaidFailureReasonForSelfTest: String? { mermaidRenderer.failureReason }
    var markdownPreviewForSelfTest: MarkdownPreview? { markdownPreview }

    /// Dựng sheet thư viện mẫu mà KHÔNG mở ra — cùng khuôn `makeRecipeSheetForSelfTest`.
    ///
    /// Bài tự kiểm chạy không người, và `beginSheet` treo một sheet lên cửa sổ rồi không ai
    /// đóng nó: mọi bài sau đó gõ vào một cửa sổ đã bị chặn.
    func makeMermaidTemplateSheetForSelfTest() -> MermaidTemplateSheet {
        let sheet = MermaidTemplateSheet(preferring: mermaidKindAtCaret())
        sheet.present(in: nil) { [weak self] template in
            self?.insertMermaidTemplate(template)
        }
        return sheet
    }

    /// Danh sách gợi ý đang hiện — bài kiểm FR-MMD-005 đọc để biết gợi ý có đúng không.
    var completionWordsForSelfTest: [String] { completionPopup.candidates.map(\.word) }

    /// Chữ của lần tô sáng gần nhất — FR-MMD-002.
    var mermaidFocusForSelfTest: [String] { mermaidRenderer.lastFocus }

    /// Đếm phần tử đang được tô sáng TRONG TRANG VẼ.
    ///
    /// Hỏi thẳng DOM chứ không tin lời gọi: `focus(on:)` gửi đi một danh sách chữ, còn việc có
    /// phần tử nào mang chữ ấy hay không thì chỉ trang vẽ biết. Một bài kiểm chỉ đọc danh sách
    /// đã gửi sẽ xanh kể cả khi phép so khớp trong JavaScript hỏng hoàn toàn.
    func waitForMermaidHitsForSelfTest(expected: Int, seconds: Double = 20) -> Int? {
        var count: Int?
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            var answered = false
            mermaidRenderer.countHighlighted { value in
                count = value
                answered = true
            }
            let wait = Date().addingTimeInterval(0.2)
            while !answered, Date() < wait {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            if let count, count == expected { return count }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return count
    }

    /// Chữ của những phần tử đang sáng trong trang vẽ — xem `MermaidRenderer.highlightedTexts`.
    func highlightedTextsForSelfTest(seconds: Double = 5) -> [String] {
        var texts: [String]?
        var answered = false
        mermaidRenderer.highlightedTexts { value in
            texts = value
            answered = true
        }
        let deadline = Date().addingTimeInterval(seconds)
        while !answered, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        return texts ?? []
    }

    /// Diễn một cú KÉO thật trên trang vẽ rồi chờ nó chạy xong — FR-KNW-915.
    ///
    /// Trả về câu mà trang báo lại ("đã gửi", "không thấy node nguồn"), để bài kiểm phân biệt
    /// "cử chỉ không tới nơi" với "cử chỉ tới nơi nhưng chỗ nhận bỏ qua". Hai thứ ấy hỏng vì
    /// hai lý do khác hẳn nhau.
    func dragOnGraphForSelfTest(from: String, to: String, seconds: Double = 10) -> String? {
        var answer: String?
        mermaidRenderer.dispatchDragForSelfTest(from: from, to: to) { answer = $0 }
        waitForSelfTest("graph drag", seconds: seconds) { answer != nil }
        // Tin đi từ trang về Swift qua `postMessage` — một chuyến nữa qua vòng lặp sự kiện sau
        // khi JavaScript trả lời. Không quay vòng lặp ở đây thì bài kiểm đọc trạng thái trước
        // khi tin kịp tới.
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, lastGraphEditForSelfTest == nil {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        return answer
    }

    /// Diễn một cú DOUBLE-CLICK thật trên trang vẽ — cùng khuôn với `dragOnGraphForSelfTest`.
    func doubleClickOnGraphForSelfTest(_ text: String, seconds: Double = 10) -> String? {
        var answer: String?
        mermaidRenderer.dispatchDoubleClickForSelfTest(on: text) { answer = $0 }
        waitForSelfTest("graph dblclick", seconds: seconds) { answer != nil }
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, lastGraphEditForSelfTest == nil {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        return answer
    }

    func insertMermaidInitDirectiveForSelfTest(_ brand: MermaidBrand) {
        insertMermaidInitDirective(brand)
    }

    /// Những dòng đang bị gạch lỗi — bài kiểm FR-MMD-006.
    var problemRangesForSelfTest: [Range<Int>] { editorView.problemRanges }
    func documentLineForSelfTest(offset: Int) -> Int {
        editorDocument.buffer.lineNumber(atOffset: offset)
    }

    /// Bản công khai của vòng chờ — bài tự kiểm ngoài lớp này cần nó.
    @discardableResult
    func waitForSelfTestPublic(
        _ name: String, seconds: Double = 30, until done: () -> Bool
    ) -> Bool {
        waitForSelfTest(name, seconds: seconds, until: done)
    }
    var mermaidVersionForSelfTest: String? { mermaidRenderer.version }
    func clickMermaidElementForSelfTest(diagram index: Int, text: String) {
        jumpToMermaidElement(diagram: index, text: text)
    }

    /// Dựng lại sơ đồ từ nội dung ĐANG GÕ.
    ///
    /// Vế *"sửa văn bản → preview cập nhật ≤ 500 ms (debounce 300 ms)"* của FR-MMD-002 nằm ở
    /// `scheduleMermaidRefresh`; hàm này là phần chạy thật.
    func refreshMermaidPreview() {
        // `surface` chứ không phải `self.mermaidPanel`: khung sơ đồ có thể là bảng bên cạnh
        // HOẶC tab chiếm trọn. Bản đầu chỉ đổi tên biến ở đầu hàm, còn trong closure vẽ xong vẫn
        // gọi `self.mermaidPanel` — nó vượt qua biến cục bộ, nên tab vẽ ra hình mà dòng trạng
        // thái của nó rỗng, còn bảng đang ẩn thì lặng lẽ nhận kết quả.
        guard let surface = mermaidSurface else { return }
        let mermaidPanel = surface
        let text = editorDocument.buffer.text

        // --- Đường DOT/Graphviz — FR-KNW-905 ------------------------------------------------
        //
        // Vẽ bằng CHÍNH bộ vẽ mermaid, theo ADR-15 §7. Chỗ tinh tế nằm ở hai nguồn khác nhau:
        // thứ ĐƯA CHO MERMAID là bản đã chuyển, còn thứ dùng để ÁNH XẠ NGƯỢC (bấm node → nhảy
        // tới dòng, con nháy → tô sáng node) phải là văn bản DOT GỐC mà người dùng đang nhìn.
        // Lẫn hai thứ ấy thì mọi số dòng lệch đi đúng bằng độ dài phần đầu của bản chuyển.
        if DOTGraph.looksLikeDOT(text, path: editorDocument.path) {
            let graph = DOTGraph.parse(text)
            let converted = DOTToMermaid.convert(graph, styles: graphStyles)
            if dotGraph != graph {
                // Đồ thị đổi thì CSR và mọi kết quả cũ hết hiệu lực. Giữ lại là tô màu theo một
                // phân hoạch của một đồ thị đã không còn.
                graphCSR = nil
                graphStyles = [:]
                graphPageRank = nil
                graphCommunities = nil
                graphComponents = nil
            }
            dotGraph = graph
            mermaidPanel.showCypherBar(true)
            mermaidPanel.showVisualEditToggle(true)
            mermaidPanel.showPropertyTable(false)
            mermaidBlocks = [MermaidDocument.wholeFile(text)]
            mermaidRenderer.render(
                [MermaidRenderer.Diagram(index: 0, source: converted.mermaid)],
                theme: mermaidPanel.theme, display: true
            ) { [weak self] results in
                guard let self, !results.isEmpty else { return }
                surface.present(results, kinds: [.flowchart])
                if let reason = self.mermaidRenderer.failureReason {
                    surface.showFailure(reason)
                } else if !converted.warnings.isEmpty {
                    // Phần DOT bị bỏ phải hiện ra. Một sơ đồ vẽ thiếu ba cạnh mà không có gì
                    // báo là tệ hơn hẳn một sơ đồ không vẽ.
                    surface.showNote(
                        LF("%d node · %d cạnh · ⚠ %@",
                               graph.nodes.count, graph.edges.count,
                               converted.warnings.prefix(2).joined(separator: " · ")
                                   + (converted.warnings.count > 2
                                       ? " (+\(converted.warnings.count - 2))" : "")))
                }
                // KHÔNG gạch lỗi lên văn bản ở chế độ DOT: số dòng mermaid báo là số dòng của
                // BẢN CHUYỂN, và gạch nó lên tệp DOT là chỉ vào một dòng chẳng liên quan.
                self.editorView.problemRanges = []
                self.focusMermaidElementAtCaret()
            }
            return
        }
        dotGraph = nil
        graphCSR = nil
        graphStyles = [:]
        mermaidPanel.showCypherBar(false)

        let blocks = (editorDocument.path ?? "")
            .hasSuffix("." + MermaidDocument.fileExtension)
            ? [MermaidDocument.wholeFile(text)]
            : MermaidDocument.blocks(in: text)
        mermaidBlocks = blocks
        // FR-MMD-008: khối tham chiếu được thay bằng nội dung tệp TRƯỚC khi vẽ. Không giải thì
        // sơ đồ đã tách ra hiện thành một ô trống ngay trong chính tài liệu vừa tách nó.
        let resolved = resolvedMermaidBlocks(blocks)
        // FR-MMD-004: công tắc soạn trực quan có mặt với MỌI tài liệu có sơ đồ. Loại nào chưa
        // soạn được thì nói ra lúc bật, chứ không phải giấu công tắc đi — giấu thì người dùng
        // không biết tính năng có tồn tại hay không.
        mermaidPanel.showVisualEditToggle(!blocks.filter { !$0.isEmpty }.isEmpty)
        refreshMermaidPropertyTable(for: freshMermaidBlock())
        let diagrams = resolved
            .filter { !$0.isEmpty }
            .map { MermaidRenderer.Diagram(index: $0.index, source: $0.source) }
        guard !diagrams.isEmpty else {
            mermaidPanel.present([], kinds: [])
            mermaidRenderer.render([], display: true) { _ in }
            return
        }
        mermaidRenderer.render(
            diagrams, theme: mermaidPanel.theme, display: true
        ) { [weak self] results in
            guard let self, !results.isEmpty else { return }
            surface.present(results, kinds: blocks.map(\.kind))
            if let reason = self.mermaidRenderer.failureReason {
                surface.showFailure(reason)
            }
            self.markMermaidProblems(results, blocks: blocks)
            // Vẽ xong thì tô sáng lại chỗ con nháy. Mỗi lượt vẽ dựng SVG mới, nên lớp tô sáng
            // của lượt trước biến mất cùng SVG cũ — không đặt lại thì viền cam tắt ngay ở lần
            // gõ kế, và tab thì không bao giờ có nó vì tab không có sự kiện dời con nháy nào
            // để bám vào.
            self.focusMermaidElementAtCaret()
        }
    }

    /// Gõ tới đâu vẽ tới đó, nhưng KHÔNG mỗi phím một lượt vẽ.
    ///
    /// FR-MMD-002 tự đặt con số: *"debounce 300 ms"*. Không hoãn thì mỗi phím gõ là một lượt
    /// `mermaid.render` — PoC-L đo một sơ đồ nhỏ mất 29 ms, nên gõ nhanh sẽ xếp hàng những lượt
    /// vẽ mà không ai còn muốn xem (bộ render tự bỏ lượt cũ, nhưng vẫn tốn một chuyến qua
    /// JavaScript cho mỗi phím).
    func scheduleMermaidRefresh() {
        guard isMermaidPanelVisible else { return }
        mermaidRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshMermaidPreview() }
        mermaidRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Con nháy đang ở dòng nào thì phần tử ấy sáng lên trên sơ đồ — FR-MMD-002.
    ///
    /// Chỉ chạy khi CÓ một khung sơ đồ đang hiện: không có thì không có gì để tô sáng, và một
    /// lượt phân tích khối cho mỗi lần dời con nháy là cái giá trả cho không.
    ///
    /// **Khung ấy là bảng bên cạnh HOẶC tab chiếm trọn.** Bản đầu chỉ hỏi bảng, nên sơ đồ mở
    /// trong tab luôn mở ra không có gì sáng — đúng cái khoảng trống mà cây cấu trúc vừa được
    /// lấp: sang View từ giữa tài liệu thì View phải nói được "chỗ anh đang đứng là chỗ này".
    func focusMermaidElementAtCaret() {
        guard mermaidSurface != nil else { return }
        let buffer = editorDocument.buffer
        let selection = editorView.selectedDocumentRange
        let caret = min(max(0, selection.lowerBound), buffer.count)
        let line = buffer.lineNumber(atOffset: caret)
        guard line < buffer.lineCount else { return mermaidRenderer.focus(on: []) }

        // Chế độ DOT: tên node lấy từ chính đồ thị đã đọc, không lấy bằng bộ tách của Mermaid —
        // cú pháp hai bên khác nhau, và tách nhầm thì tô sáng nhầm node.
        if let graph = dotGraph {
            let last = min(buffer.lineCount - 1, buffer.lineNumber(atOffset:
                min(max(0, selection.upperBound), buffer.count)))
            var words: [String] = []
            var seen = Set<String>()
            for index in line...max(line, last) {
                for word in graph.names(onLine: index) where seen.insert(word).inserted {
                    words.append(word)
                }
            }
            return mermaidRenderer.focus(on: words)
        }

        guard let block = mermaidBlocks.first(where: {
            let lines = $0.source.isEmpty
                ? 0 : $0.source.components(separatedBy: "\n").count
            return line >= $0.firstContentLine && line < $0.firstContentLine + max(1, lines)
        }) else {
            // Con nháy ra khỏi mọi sơ đồ thì XOÁ tô sáng, chứ không để nguyên: một viền cam
            // đứng mãi trên một node mà người dùng đã rời đi từ lâu là một chỉ dẫn nói sai.
            return mermaidRenderer.focus(on: [])
        }
        // Vùng chọn trải nhiều dòng thì lấy chữ của MỌI dòng trong vùng — người dùng bôi đen
        // một khối ba dòng là đang nói về ba phần tử ấy.
        let last = min(buffer.lineCount - 1, buffer.lineNumber(atOffset:
            min(max(0, selection.upperBound), buffer.count)))
        var words: [String] = []
        var seen = Set<String>()
        for index in line...max(line, last) {
            for word in MermaidLibrary.focusWords(inLine: buffer.line(index), kind: block.kind)
            where !seen.contains(word) {
                seen.insert(word)
                words.append(word)
            }
        }
        mermaidRenderer.focus(on: words)
    }

    /// Gạch dưới dòng có lỗi cú pháp — FR-MMD-006 (*"lỗi gạch sóng đúng dòng"*).
    ///
    /// Số dòng mermaid báo là số dòng TRONG SƠ ĐỒ; `MermaidBlock.documentLine` quy nó về dòng
    /// của tài liệu. Không quy đổi thì với một khối nằm ở dòng 200, dấu lỗi rơi vào dòng 3 —
    /// một chỗ chẳng liên quan gì, và người dùng sẽ đi sửa đúng chỗ ấy.
    ///
    /// Sơ đồ hỏng mà mermaid KHÔNG nói được dòng thì gạch dòng KHAI BÁO của khối: nó vẫn chỉ
    /// đúng khối, và đó là thứ nhiều nhất ta biết chắc.
    private func markMermaidProblems(
        _ results: [MermaidRenderer.Rendered], blocks: [MermaidBlock]
    ) {
        var ranges: [Range<Int>] = []
        let buffer = editorDocument.buffer
        for result in results where result.isFailure {
            guard let block = blocks.first(where: { $0.index == result.index }) else { continue }
            let line = result.line.map { block.documentLine(forDiagramLine: $0) }
                ?? block.firstContentLine
            guard line >= 0, line < buffer.lineCount else { continue }
            let range = buffer.contentRange(ofLine: line)
            guard !range.isEmpty else { continue }
            ranges.append(range)
        }
        editorView.problemRanges = ranges.sorted { $0.lowerBound < $1.lowerBound }
    }

    /// Bấm một phần tử trên sơ đồ → đưa con nháy tới đúng dòng định nghĩa nó (FR-MMD-002).
    ///
    /// ## Tìm theo NHÃN, không theo `id` của mermaid
    ///
    /// Cách "đúng" theo đặc tả là dựng bản đồ `element-id ↔ text-range` từ cây phân tích. Nhưng
    /// cây phân tích ấy nằm bên trong mermaid.js và không có API nào trả nó ra; `id` trên SVG
    /// thì mỗi loại sơ đồ đặt một kiểu (`flowchart-A-0`, `actor0`, `section-2`) và đổi giữa các
    /// bản mermaid. Dựa vào chúng là dựng một tính năng lên trên chi tiết nội bộ của thư viện,
    /// và nó sẽ hỏng im lặng ở lần nâng cấp đầu tiên.
    ///
    /// Nên ở đây tìm theo **chữ hiện trên phần tử** — thứ người dùng nhìn thấy và thứ chắc chắn
    /// có trong mã nguồn sơ đồ. Cái giá phải nói ra: hai node cùng nhãn thì nhảy tới cái ĐẦU
    /// TIÊN. Đó là một giới hạn thấy được và đoán được, khác hẳn một tính năng chết lặng.
    private func jumpToMermaidElement(diagram index: Int, text: String) {
        guard let block = mermaidBlocks.first(where: { $0.index == index }) else { return }
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return }

        // Sơ đồ đang chiếm TRỌN tab thì phải nhường chỗ trước khi dời con nháy.
        //
        // Đường nhảy này dùng chung cho hai khung, và ở bảng Mermaid Studio thì không có gì để
        // làm: vùng soạn thảo nằm ngay bên cạnh, con nháy dời là thấy. Ở tab thì vùng soạn thảo
        // bị che, nên con nháy dời sau lưng một bức tranh — bấm xong không thấy gì xảy ra, và
        // người dùng kết luận là bấm không ăn.
        //
        // Cùng luật với cây cấu trúc: bấm một thứ trong View là về Code, vì việc tiếp theo gần
        // như luôn là SỬA chỗ vừa bấm.
        if isDiagramTabVisible { hideDiagramTab() }

        // Chế độ DOT: hỏi thẳng đồ thị đã đọc thay vì dò chuỗi trong văn bản.
        //
        // Khác biệt có nghĩa: `DOTGraph.line(ofNode:)` trả dòng KHAI node, còn dò chuỗi trả
        // dòng NHẮC TÊN đầu tiên. Bấm một node thì người dùng muốn tới chỗ định nghĩa nó.
        if let graph = dotGraph {
            guard let line = graph.line(ofNode: needle),
                  line < editorDocument.buffer.lineCount else {
                return showTransient(String(
                    format: L("Không tìm thấy «%@» trong mã sơ đồ"), needle))
            }
            let offset = editorDocument.buffer.contentRange(ofLine: line).lowerBound
            revealOffset(offset)
            editorView.setSelection(MultiSelection(caretAt: offset))
            return
        }
        let lines = block.source.components(separatedBy: "\n")
        var found: Int?
        for (offset, line) in lines.enumerated() where line.contains(needle) {
            found = offset
            break
        }
        guard let found else {
            return showTransient(String(
                format: L("Không tìm thấy «%@» trong mã sơ đồ"), needle))
        }
        let documentLine = min(
            max(0, editorDocument.buffer.lineCount - 1), block.firstContentLine + found)
        let offset = editorDocument.buffer.contentRange(ofLine: documentLine).lowerBound
        revealOffset(offset)
        editorView.setSelection(MultiSelection(caretAt: offset))
    }

    /// Xuất sơ đồ — FR-MMD-007.
    ///
    /// ## Xuất sơ đồ NÀO khi tài liệu có nhiều sơ đồ
    ///
    /// Sơ đồ **đầu tiên vẽ được**. Ba cách khác đều tệ hơn: xuất hết thành nhiều tệp thì một
    /// lần bấm nhầm rải bảy tệp vào thư mục người dùng; hỏi "sơ đồ nào" mỗi lần là một hộp thoại
    /// giữa một thao tác lẽ ra chỉ một bấm; còn xuất sơ đồ đang cuộn tới thì phụ thuộc vị trí
    /// cuộn — thứ không ai đoán được. Tệp `.mmd` chỉ có một sơ đồ, và đó là ca chính.
    private func exportMermaid(_ choice: MermaidPanel.ExportChoice) {
        if case .brandPreset = choice { return editMermaidBrand() }
        guard let svg = mermaidPanel.lastResults.compactMap(\.svg).first else {
            return showBanner(L("Chưa có sơ đồ nào vẽ xong để xuất."),
                              actionTitle: nil, action: nil)
        }
        let background = MermaidExport.background(
            for: mermaidPanel.theme, transparent: mermaidPanel.isTransparent)

        switch choice {
        case .svg:
            let text = MermaidExport.svgFile(from: svg, background: background)
            guard let url = askSaveURL(name: "so-do.svg") else { return }
            write(Data(text.utf8), to: url, what: "SVG")

        case let .png(scale):
            guard let data = MermaidExport.png(
                from: svg, scale: scale, background: background) else {
                return showBanner(pngFailureReason(), actionTitle: nil, action: nil)
            }
            guard let url = askSaveURL(name: "so-do@\(scale.label).png") else { return }
            write(data, to: url, what: "PNG \(scale.label)")

        case .copyImage:
            // Chép ở 2x: dán vào Keynote hay Slack thì ảnh còn nét trên màn hình Retina, mà
            // không nặng gấp chín lần như 3x.
            guard let data = MermaidExport.png(
                from: svg, scale: .twoX, background: background),
                MermaidExport.copyToPasteboard(png: data) else {
                return showBanner(pngFailureReason(), actionTitle: nil, action: nil)
            }
            showTransient(L("Đã chép ảnh sơ đồ vào clipboard"))

        case .brandPreset:
            break   // đã xử lý ở trên
        }
    }

    /// `NSImage` đọc được SVG từ macOS 13; NFR-PORT-02 đòi chạy từ macOS 12.
    private func pngFailureReason() -> String {
        L("Máy này không dựng được ảnh PNG từ sơ đồ — cần macOS 13. Xuất SVG vẫn dùng được.")
    }

    private func askSaveURL(name: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        guard Unattended.chooseFile(panel) == .OK else { return nil }
        return panel.url
    }

    private func write(_ data: Data, to url: URL, what: String) {
        do {
            try data.write(to: url, options: .atomic)
            showTransient(String(
                format: L("Đã lưu %@ — %@"), what, url.lastPathComponent))
        } catch {
            showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
    }

    /// Sửa preset màu thương hiệu và chèn `%%{init}%%` vào tài liệu — FR-MMD-007.
    private func editMermaidBrand() {
        let brand = MermaidBrand.load()
        let alert = NSAlert()
        alert.messageText = L("Màu thương hiệu cho sơ đồ")
        alert.informativeText = L("Mỗi ô là một mã màu dạng #rrggbb. Lưu vào "
            + "«themes/mermaid-brand.json» — chép sang máy khác được.")

        let fields: [(String, String, (inout MermaidBrand, String) -> Void)] = [
            (L("Màu chính"), brand.primaryColor, { $0.primaryColor = $1 }),
            (L("Chữ trên nút"), brand.primaryTextColor, { $0.primaryTextColor = $1 }),
            (L("Viền"), brand.primaryBorderColor, { $0.primaryBorderColor = $1 }),
            (L("Đường nối"), brand.lineColor, { $0.lineColor = $1 }),
            (L("Nền khi xuất ảnh"), brand.background, { $0.background = $1 }),
        ]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        var inputs: [NSTextField] = []
        for (label, value, _) in fields {
            let input = NSTextField(string: value)
            input.widthAnchor.constraint(equalToConstant: 160).isActive = true
            inputs.append(input)
            let row = NSStackView(views: [NSTextField(labelWithString: label + ":"), input])
            row.orientation = .horizontal
            row.spacing = 6
            stack.addArrangedSubview(row)
        }
        stack.frame = NSRect(x: 0, y: 0, width: 360, height: CGFloat(fields.count) * 30)
        alert.accessoryView = stack
        alert.addButton(withTitle: L("Lưu"))
        alert.addButton(withTitle: L("Lưu và chèn %%{init}%% vào tài liệu"))
        alert.addButton(withTitle: L("Huỷ"))

        let answer = Unattended.ask(alert)
        guard answer != .alertThirdButtonReturn else { return }
        var updated = brand
        for (index, entry) in fields.enumerated() {
            entry.2(&updated, inputs[index].stringValue.trimmingCharacters(in: .whitespaces))
        }
        do {
            try updated.save()
        } catch {
            return showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
        mermaidBrand = updated
        mermaidRenderer.brand = updated
        showTransient(L("Đã lưu màu thương hiệu"))
        // Đang xem theme thương hiệu thì vẽ lại ngay để thấy màu mới.
        if mermaidPanel.theme == .brand, isMermaidPanelVisible { refreshMermaidPreview() }
        guard answer == .alertSecondButtonReturn else { return }
        insertMermaidInitDirective(updated)
    }

    /// Chèn `%%{init}%%` vào đầu sơ đồ chứa con nháy — để sơ đồ TỰ MANG màu của nó khi rời khỏi
    /// GEditor (dán vào GitHub, Confluence…).
    private func insertMermaidInitDirective(_ brand: MermaidBrand) {
        guard !editorDocument.isReadOnly else {
            return showBanner(L("Tài liệu đang ở chế độ chỉ đọc."), actionTitle: nil, action: nil)
        }
        let buffer = editorDocument.buffer
        let isDiagramFile = (editorDocument.path ?? "")
            .hasSuffix("." + MermaidDocument.fileExtension)
        let blocks = isDiagramFile
            ? [MermaidDocument.wholeFile(buffer.text)]
            : MermaidDocument.blocks(in: buffer.text)
        let caretLine = buffer.lineNumber(
            atOffset: min(max(0, editorView.selectedDocumentRange.lowerBound), buffer.count))
        let target = blocks.first {
            let lines = $0.source.components(separatedBy: "\n").count
            return caretLine >= $0.firstContentLine
                && caretLine < $0.firstContentLine + max(1, lines)
        } ?? blocks.first
        guard let target else {
            return showBanner(
                L("Tài liệu này không phải tệp .mmd, không phải DOT, và chưa có khối mermaid."),
                actionTitle: nil, action: nil)
        }
        // Sơ đồ ĐÃ có chỉ thị của người dùng thì KHÔNG chèn chồng lên.
        //
        // Hai chỉ thị `%%{init}%%` trong một sơ đồ là một tổ hợp mermaid xử lý theo cách không
        // ai đoán được, và cái người dùng tự viết là cái đáng giữ.
        guard !target.source.contains("%%{init") else {
            return showBanner(
                L("Sơ đồ này đã có sẵn một chỉ thị %%{init}%% — giữ nguyên bản của anh."),
                actionTitle: nil, action: nil)
        }
        let line = min(max(0, target.firstContentLine), max(0, buffer.lineCount - 1))
        let at = buffer.contentRange(ofLine: line).lowerBound
        apply([TextEdit(range: at ..< at, text: brand.initDirective + "\n")],
              label: "Chèn màu thương hiệu vào sơ đồ")
        showTransient(L("Đã chèn %%{init}%% — sơ đồ nay tự mang màu của nó"))
        if isMermaidPanelVisible { refreshMermaidPreview() }
    }

    /// Dựng lại preview từ nội dung ĐANG GÕ.
    ///
    /// Chạy đồng bộ trên luồng chính, và đó là lựa chọn có cân nhắc: phân tích tài liệu là vài
    /// chục micro-giây (`ReportDocument` không chạy gì), còn phần đắt là các câu truy vấn. Trên
    /// bảng lớn nó sẽ vượt 16 ms — nên preview chỉ dựng lại khi người dùng NGỪNG gõ, không phải
    /// mỗi phím.
    func refreshReportPreview() {
        guard isReportPreviewVisible else { return }
        let text = editorDocument.buffer.text
        let document: ReportDocument
        do {
            document = try ReportDocument.parse(text)
        } catch let failure as ReportDocument.Failure {
            return reportPreview.showParseFailure(failure.description)
        } catch {
            return reportPreview.showParseFailure(error.localizedDescription)
        }

        // Nguồn dữ liệu: khoá `source` trong frontmatter, giải TƯƠNG ĐỐI với chính tệp báo cáo.
        var sourcePath: String?
        if let declared = document.frontmatter?["source"]?.stringValue,
           let reportPath = editorDocument.path {
            sourcePath = (declared as NSString).isAbsolutePath
                ? declared
                : ((reportPath as NSString).deletingLastPathComponent as NSString)
                    .appendingPathComponent(declared)
        }
        guard let sourcePath, let bytes = FileManager.default.contents(atPath: sourcePath) else {
            return reportPreview.showParseFailure(
                L("Chưa tìm được dữ liệu — khai «source: tên-file.csv» ở frontmatter."))
        }

        let declared = (try? ReportParameters.declared(in: document.frontmatter)) ?? []
        let values = ReportParameters.resolve(
            declared: declared, supplied: reportParameters)
        let buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
        // `basePath` là thư mục của chính tệp báo cáo: khối ```quality giải `rules_file` và khối
        // ```mining giải `source` tương đối với nó. Thiếu nó thì hai khối ấy đi tìm tệp trong
        // thư mục ĐANG ĐỨNG của tiến trình app — một chỗ người dùng không biết là ở đâu.
        //
        // Cache dùng chung giữa các lần dựng: preview dựng lại mỗi khi người dùng ngừng gõ, và
        // chấm lại cả bộ luật cho mỗi dấu phẩy vừa gõ vào phần văn xuôi là cái giá không ai
        // trả. Xem `QualityCache`.
        guard let rendered = try? ReportRenderer.render(
            document, in: buffer, dialect: .comma,
            options: ReportRenderer.Options(
                values: values, sourcePath: sourcePath,
                basePath: (editorDocument.path as NSString?)?.deletingLastPathComponent,
                qualityCache: reportQualityCache, blockCache: reportBlockCache))
        else {
            return reportPreview.showParseFailure(L("Không dựng được báo cáo."))
        }
        lastReportRender = rendered
        lastReportSource = sourcePath
        reportPreview.show(rendered, stale: false)
        renderReportMermaid(rendered)
    }

    /// Vẽ các khối ```mermaid của báo cáo rồi ĐIỀN vào trang — FR-MMD-003.
    ///
    /// Trang được hiện NGAY với chỗ trống, rồi hiện lại khi sơ đồ vẽ xong. Cách khác — chờ vẽ
    /// xong mới hiện gì cả — bắt người dùng nhìn màn hình trắng thêm một giây cho một báo cáo
    /// mà phần bảng biểu đã sẵn sàng, và nó biến mọi lần gõ thành một nhịp giật.
    private func renderReportMermaid(_ rendered: ReportRenderer.Rendered) {
        guard !rendered.mermaid.isEmpty else { return }
        guard MermaidAsset.isAvailable else { return }
        // Khối tham chiếu của báo cáo cũng phải giải ra — đặc tả FR-MMD-008 kê cả `.greport.md`.
        let diagrams = rendered.mermaid.map { item -> MermaidRenderer.Diagram in
            guard let path = MermaidLink.reference(in: item.source),
                  let full = resolveMermaidReference(path),
                  let text = try? String(contentsOfFile: full, encoding: .utf8) else {
                return MermaidRenderer.Diagram(index: item.blockIndex, source: item.source)
            }
            return MermaidRenderer.Diagram(index: item.blockIndex, source: text)
        }
        mermaidRenderer.render(diagrams) { [weak self] results in
            guard let self, !results.isEmpty else { return }
            var svgs: [Int: String] = [:]
            for result in results {
                guard let svg = result.svg else { continue }
                svgs[result.index] = svg
            }
            guard !svgs.isEmpty else { return }
            var filled = rendered
            filled.html = ReportRenderer.spliceMermaid(into: rendered.html, svgs: svgs)
            self.lastReportRender = filled
            guard self.isReportPreviewVisible else { return }
            self.reportPreview.show(filled, stale: false)
        }
    }

    /// Hộp nhập tham số — FR-RPT-004 (*"hộp nhập tham số khi chạy từ UI"*).
    private func editReportParameters() {
        guard let document = try? ReportDocument.parse(editorDocument.buffer.text),
              let declared = try? ReportParameters.declared(in: document.frontmatter),
              !declared.isEmpty else {
            return showBanner(
                L("Báo cáo này chưa khai tham số nào ở frontmatter."),
                actionTitle: nil, action: nil)
        }
        let alert = NSAlert()
        alert.messageText = L("Tham số báo cáo")
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        var fields: [String: NSTextField] = [:]
        for parameter in declared {
            let field = NSTextField(string: reportParameters[parameter.name]
                ?? parameter.defaultValue)
            field.widthAnchor.constraint(equalToConstant: 220).isActive = true
            fields[parameter.name] = field
            let row = NSStackView(views: [
                NSTextField(labelWithString: parameter.displayLabel + ":"), field,
            ])
            row.orientation = .horizontal
            row.spacing = 6
            stack.addArrangedSubview(row)
        }
        stack.frame = NSRect(x: 0, y: 0, width: 340, height: CGFloat(declared.count) * 30)
        alert.accessoryView = stack
        alert.addButton(withTitle: L("Dựng lại"))
        alert.addButton(withTitle: L("Huỷ"))
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        for (name, field) in fields { reportParameters[name] = field.stringValue }
        refreshReportPreview()
    }

    /// Xuất HTML tự chứa — FR-RPT-005 vế (a).
    private func exportReportHTML() {
        guard let rendered = lastReportRender else { return }
        let suggested = ((editorDocument.path ?? "bao-cao") as NSString)
            .deletingPathExtension
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (suggested as NSString).lastPathComponent + ".html"
        panel.allowedContentTypes = [.html]
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        do {
            try rendered.html.write(to: url, atomically: true, encoding: .utf8)
            showTransient(String(
                format: L("Đã xuất %@"), url.lastPathComponent))
        } catch {
            showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
    }

    // MARK: - Sinh loạt báo cáo (FR-RPT-006)

    /// `Báo cáo: sinh loạt…` — mỗi bộ tham số một tệp HTML.
    ///
    /// ## Chạy trên LUỒNG CHÍNH, nhả nhịp giữa các bộ
    ///
    /// Nghe ngược đời, nhưng nó là lựa chọn có cân nhắc. Một lượt dựng báo cáo chạm ba thứ chỉ
    /// sống ở luồng chính: `WKWebView` của bộ vẽ sơ đồ, `QualityCache` dùng chung, và chính
    /// `editorDocument`. Đẩy chúng sang luồng nền là mở ra một họ lỗi tranh chấp mà bộ chạy dài
    /// `--soak` phải đi tìm sau này.
    ///
    /// Thay vào đó, mỗi bộ tham số là một lượt `DispatchQueue.main.async` riêng: cửa sổ vẫn vẽ
    /// lại và vẫn nhận thao tác giữa hai bộ, và người dùng thấy tiến độ chạy. Cái giá: cả loạt
    /// chậm hơn một chút so với chạy liền mạch — chấp nhận được cho một thao tác người ta bấm
    /// vài lần một tháng.
    @objc func showReportBatch(_ sender: Any?) {
        guard isReportDocument else {
            return showBanner(
                LF("Sinh loạt cần tài liệu đuôi .%@",
                       ReportDocument.fileExtension),
                actionTitle: nil, action: nil)
        }
        let document: ReportDocument
        do {
            document = try ReportDocument.parse(editorDocument.buffer.text)
        } catch let failure as ReportDocument.Failure {
            return showBanner(failure.description, actionTitle: nil, action: nil)
        } catch {
            return showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
        guard let sourcePath = reportSourcePath(for: document),
              let bytes = FileManager.default.contents(atPath: sourcePath) else {
            return showBanner(
                L("Chưa tìm được dữ liệu — khai «source: tên-file.csv» ở frontmatter."),
                actionTitle: nil, action: nil)
        }

        let listPanel = NSOpenPanel()
        listPanel.message = L("Chọn danh sách tham số (CSV hoặc JSON)")
        listPanel.allowedContentTypes = [.commaSeparatedText, .json]
        listPanel.allowsMultipleSelection = false
        guard Unattended.chooseFile(listPanel) == .OK, let listURL = listPanel.url else { return }

        let sets: [ReportBatch.ParameterSet]
        do {
            sets = try ReportBatch.parameterSets(fromFile: listURL.path)
        } catch let failure as ReportBatch.Failure {
            return showBanner(failure.message, actionTitle: nil, action: nil)
        } catch {
            return showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }

        let folderPanel = NSOpenPanel()
        folderPanel.message = String(
            format: L("Chọn thư mục để ghi %d báo cáo"), sets.count)
        folderPanel.canChooseDirectories = true
        folderPanel.canChooseFiles = false
        folderPanel.canCreateDirectories = true
        guard Unattended.chooseFile(folderPanel) == .OK,
              let folder = folderPanel.url else { return }

        runReportBatch(
            document: document, sets: sets, sourcePath: sourcePath,
            bytes: bytes, folder: folder)
    }

    /// Nguồn dữ liệu của báo cáo — dùng chung với `refreshReportPreview`.
    private func reportSourcePath(for document: ReportDocument) -> String? {
        guard let declared = document.frontmatter?["source"]?.stringValue,
              let reportPath = editorDocument.path else { return nil }
        return (declared as NSString).isAbsolutePath
            ? declared
            : ((reportPath as NSString).deletingLastPathComponent as NSString)
                .appendingPathComponent(declared)
    }

    private func runReportBatch(
        document: ReportDocument, sets: [ReportBatch.ParameterSet],
        sourcePath: String, bytes: Data, folder: URL
    ) {
        let reportPath = editorDocument.path ?? ""
        // Tạo thư mục đích nếu chưa có: hộp chọn thư mục thường bảo đảm nó tồn tại, nhưng
        // không phải mọi đường vào đều đi qua hộp ấy — và mất cả loạt vì một thư mục trống là
        // một cái giá vô lý.
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true)
        let declared = (try? ReportParameters.declared(in: document.frontmatter)) ?? []
        var outcome = ReportBatch.Outcome()
        // Cache dùng chung cả loạt: 63 tỉnh chấm cùng một bộ luật trên cùng một tệp nguồn thì
        // khối ```quality của chúng cho ra đúng một kết quả. Cùng lý do đã ghi ở CLI.
        let cache = QualityCache()

        func step(_ index: Int) {
            guard index < sets.count else { return finishReportBatch(outcome, folder: folder) }
            let set = sets[index]
            showTransient(String(
                format: L("[%d/%d] %@"), index + 1, sets.count, set.label))

            let values = ReportParameters.resolve(
                declared: declared, supplied: set.values)
            let missing = ReportParameters.missing(in: document, values: values)
            guard missing.isEmpty else {
                outcome.entries.append(.init(
                    label: set.label, path: nil, failed: true,
                    message: L("thiếu tham số ") + missing.joined(separator: ", ")))
                return DispatchQueue.main.async { step(index + 1) }
            }
            let name = ReportBatch.outputName(
                template: nil, set: set, reportPath: reportPath)
            let destination = folder.appendingPathComponent(name)
            // Cùng hàng rào của lượt chạy đơn: không bao giờ ghi đè tệp báo cáo hay tệp dữ liệu.
            if [reportPath, sourcePath].contains(where: {
                QueryExport.wouldOverwriteSource(output: destination.path, source: $0)
            }) {
                outcome.entries.append(.init(
                    label: set.label, path: destination.path, failed: true,
                    message: L("trỏ vào chính tệp nguồn — từ chối ghi đè")))
                return DispatchQueue.main.async { step(index + 1) }
            }

            let buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
            let rendered: ReportRenderer.Rendered
            do {
                rendered = try ReportRenderer.render(
                    document, in: buffer, dialect: .comma,
                    options: ReportRenderer.Options(
                        values: values, sourcePath: sourcePath,
                        basePath: (reportPath as NSString).deletingLastPathComponent,
                        qualityCache: cache))
            } catch {
                outcome.entries.append(.init(
                    label: set.label, path: destination.path, failed: true,
                    message: error.localizedDescription))
                return DispatchQueue.main.async { step(index + 1) }
            }

            // Sơ đồ được vẽ và ĐIỀN vào trước khi ghi — bản xuất từ UI phải bằng chất lượng
            // bản xuất một tệp, không phải một bản rút gọn.
            renderAndWrite(rendered, set: set, destination: destination) { entry in
                outcome.entries.append(entry)
                DispatchQueue.main.async { step(index + 1) }
            }
        }
        step(0)
    }

    /// Vẽ nốt sơ đồ (nếu có) rồi ghi tệp, và trả về MỘT dòng của bảng tổng kết.
    ///
    /// Trả kết quả qua lời gọi lại chứ không qua `inout`: nhánh có sơ đồ chạy bất đồng bộ, và
    /// một tham số `inout` trong một hàm có nhánh bất đồng bộ là chỗ mà kết quả bị ghi vào một
    /// bản sao đã chết — nhìn thì đúng, chạy thì mất dòng.
    private func renderAndWrite(
        _ rendered: ReportRenderer.Rendered, set: ReportBatch.ParameterSet,
        destination: URL, then next: @escaping (ReportBatch.Outcome.Entry) -> Void
    ) {
        func write(_ html: String) {
            do {
                try html.write(to: destination, atomically: true, encoding: .utf8)
                next(.init(
                    label: set.label, path: destination.path,
                    failed: rendered.hasFailures,
                    message: rendered.hasFailures
                        ? LF("%d khối HỎNG", rendered.failures.count)
                        : (rendered.qualityAlerts.first?.message ?? "")))
            } catch {
                next(.init(
                    label: set.label, path: destination.path, failed: true,
                    message: error.localizedDescription))
            }
        }

        guard !rendered.mermaid.isEmpty, MermaidAsset.isAvailable else {
            return write(rendered.html)
        }
        // Khối tham chiếu của báo cáo cũng phải giải ra — đặc tả FR-MMD-008 kê cả `.greport.md`.
        let diagrams = rendered.mermaid.map { item -> MermaidRenderer.Diagram in
            guard let path = MermaidLink.reference(in: item.source),
                  let full = resolveMermaidReference(path),
                  let text = try? String(contentsOfFile: full, encoding: .utf8) else {
                return MermaidRenderer.Diagram(index: item.blockIndex, source: item.source)
            }
            return MermaidRenderer.Diagram(index: item.blockIndex, source: text)
        }
        mermaidRenderer.render(diagrams) { results in
            var svgs: [Int: String] = [:]
            for entry in results {
                guard let svg = entry.svg else { continue }
                svgs[entry.index] = svg
            }
            write(ReportRenderer.spliceMermaid(into: rendered.html, svgs: svgs))
        }
    }

    private func finishReportBatch(_ final: ReportBatch.Outcome, folder: URL) {
        // Bảng tổng kết ra TAB MỚI, không ra một hộp thoại: đặc tả đòi *"báo cáo tổng kết
        // thành công/lỗi TỪNG FILE"*, và một danh sách 63 dòng trong `NSAlert` thì cuộn không
        // được, chép không được, lưu không được.
        lastReportBatch = final
        openTextInNewTab(final.report + "\n", label: "tong-ket-bao-cao.txt")
        showTransient(String(
            format: L("Sinh loạt xong: %d tệp · %d hỏng"),
            final.succeededCount, final.failedCount))
        if final.failedCount > 0 {
            showBanner(
                LF("%d bộ tham số KHÔNG dựng được — xem bảng tổng kết",
                       final.failedCount),
                actionTitle: nil, action: nil)
        }
    }

    /// Chạy sinh loạt mà KHÔNG qua hai hộp chọn tệp — móc cho bài tự kiểm.
    ///
    /// Hộp chọn tệp bị `Unattended` chặn trong lượt chạy không người (đúng như nó phải thế),
    /// nên bài kiểm gọi thẳng vào phần LÀM VIỆC. Mọi thứ sau hai hộp thoại vẫn đi đúng đường
    /// sản phẩm — nếu không thì bài kiểm chỉ kiểm chính nó.
    @discardableResult
    func runReportBatchForSelfTest(listPath: String, folder: URL) -> String? {
        guard isReportDocument else { return "không phải tài liệu .greport.md" }
        guard let document = try? ReportDocument.parse(editorDocument.buffer.text) else {
            return "không phân tích được báo cáo"
        }
        guard let sourcePath = reportSourcePath(for: document),
              let bytes = FileManager.default.contents(atPath: sourcePath) else {
            return "không tìm được dữ liệu nguồn"
        }
        guard let sets = try? ReportBatch.parameterSets(fromFile: listPath) else {
            return "không đọc được danh sách tham số"
        }
        runReportBatch(
            document: document, sets: sets, sourcePath: sourcePath,
            bytes: bytes, folder: folder)
        return nil
    }

    /// In / PDF qua đường in hệ thống — FR-RPT-005 vế (b), đóng luôn FR-DOC-313.
    private func printReport() {
        guard lastReportRender != nil else { return }
        let info = NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.isHorizontallyCentered = false
        let operation = reportPreview.printOperation(with: info)
        operation.showsPrintPanel = !Unattended.isActive
        operation.showsProgressPanel = !Unattended.isActive
        guard !Unattended.isActive else { return }
        operation.run()
    }

    // MARK: - Luật kết hợp (FR-MIN-003)

    @objc func showAssociation(_ sender: Any?) {
        let columns = currentColumnNames()
        guard !columns.isEmpty else {
            return showBanner(L("Không đọc được tên cột của bảng này."),
                              actionTitle: nil, action: nil)
        }
        attachAssociationPanel()
        associationPanel.isHidden = false
        associationHeight.constant = panelOpenHeight(.association)
        associationPanel.setColumns(columns)
        runAssociation()
    }

    func hideAssociationPanel() {
        associationHeight.constant = 0
        associationPanel.isHidden = true
    }

    private func runAssociation() {
        guard let first = associationPanel.firstColumn else { return }
        switch associationPanel.shape {
        case .basket:
            let rows = readTextColumn(first).map { $0 ?? "" }
            associationBaskets = Apriori.baskets(
                from: rows, delimiter: associationPanel.delimiter)
            // Dạng (a): giỏ thứ i CHÍNH LÀ hàng thứ i, nên ánh xạ là một-một.
            associationRows = associationBaskets.indices.map { [$0] }
        case .long:
            guard let second = associationPanel.secondColumn, second != first else {
                return showBanner(
                    L("Dạng hai cột cần chọn hai cột KHÁC nhau."), actionTitle: nil, action: nil)
            }
            let built = Apriori.baskets(
                transactionIDs: readTextColumn(first), items: readTextColumn(second))
            associationBaskets = built.baskets
            associationRows = built.rows
        }
        guard let result = try? Apriori.run(
            baskets: associationBaskets,
            minimumSupport: associationPanel.minimumSupport,
            minimumConfidence: associationPanel.minimumConfidence) else { return }
        associationPanel.present(result)
    }

    /// Bấm một luật → TÔ mọi giao dịch chứa trọn luật ấy trong file nguồn (FR-MIN-003).
    private func markRule(_ rule: Apriori.Rule) {
        let hits = Apriori.Result.transactions(
            containing: rule, in: associationBaskets)
        guard !hits.isEmpty else { return }
        guard let index = try? CSVRowIndex.build(
            in: editorDocument.buffer, dialect: csvDialect) else { return }
        var updated = marks
        updated.setActiveColor(4)
        var firstOffset: Int?
        var marked = 0
        for basket in hits {
            // Một giao dịch ở dạng hai cột trải trên NHIỀU hàng — phải tô hết, không chỉ hàng
            // đầu, nếu không người dùng thấy nửa giao dịch.
            for row in (basket < associationRows.count ? associationRows[basket] : []) {
                guard let offset = index.rowStart(row, in: editorDocument.buffer) else { continue }
                if firstOffset == nil { firstOffset = offset }
                let line = editorDocument.buffer.lineNumber(atOffset: offset)
                if updated.colors(at: line).isEmpty { updated.toggle(line) }
                marked += 1
            }
        }
        marks = updated
        if let firstOffset { revealOffset(firstOffset) }
        showTransient(String(
            format: L("Đã đánh dấu %d dòng của %d giao dịch chứa «%@»"),
            marked, hits.count, rule.text))
    }

    private func exportAssociation(_ result: Apriori.Result) {
        var out = result.methodology
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "# " + $0 }.joined(separator: "\n") + "\n"
        out += "ve_trai,ve_phai,support,confidence,lift,leverage,so_giao_dich,canh_bao\n"
        for rule in result.rules {
            out += [rule.antecedent.joined(separator: " + "),
                    rule.consequent.joined(separator: " + "),
                    ChartRender.number(rule.support * 100),
                    ChartRender.number(rule.confidence * 100),
                    ChartRender.number(rule.lift),
                    ChartRender.number(rule.leverage),
                    String(rule.count), rule.caution]
                .map(Self.csvEscaped).joined(separator: ",") + "\n"
        }
        openTextInNewTab(out, label: "luat-ket-hop.csv")
    }

    // MARK: - Khai phá theo nhóm (FR-MIN-007)

    @objc func showGroupMining(_ sender: Any?) {
        let all = currentColumnNames()
        let numeric = numericColumnNames()
        // Cột nhóm là cột KHÔNG phải số. Một cột số cũng gom nhóm được về mặt kỹ thuật, nhưng
        // "nhóm theo doanh thu" thì mỗi giá trị một nhóm — đúng tình huống mà trần 1.000 nhóm
        // sinh ra để bắt. Chỉ đưa cột chữ vào danh sách là chặn nó từ đầu.
        let text = all.filter { !numeric.contains($0) }
        guard !text.isEmpty else {
            return showBanner(
                L("Bảng này không có cột chữ nào để gom nhóm."), actionTitle: nil, action: nil)
        }
        guard !numeric.isEmpty else {
            return showBanner(
                L("Bảng này không có cột số nào để khai phá."), actionTitle: nil, action: nil)
        }
        attachGroupMiningPanel()
        groupMiningPanel.isHidden = false
        groupMiningHeight.constant = panelOpenHeight(.groupMining)
        groupMiningPanel.setColumns(text: text, numeric: numeric)
        runGroupMining()
    }

    func hideGroupMiningPanel() {
        groupMiningHeight.constant = 0
        groupMiningPanel.isHidden = true
    }

    private func runGroupMining() {
        guard let groupColumn = groupMiningPanel.groupColumn,
              let valueColumn = groupMiningPanel.valueColumn else { return }
        let labels = readTextColumn(groupColumn)
        let numeric = numericColumnNames()
        let values = numeric.map { readNumericColumn($0) }
        guard !labels.isEmpty, !values.isEmpty else { return }

        var options = GroupMining.Options(
            anomalyColumn: valueColumn, forecastColumn: valueColumn)
        if let pair = groupMiningPanel.pairColumn, pair != valueColumn {
            options.correlationPair = (valueColumn, pair)
        }
        guard let report = try? GroupMining.run(
            labels: labels, columns: numeric, values: values, options: options) else { return }
        groupMiningPanel.present(report)
    }

    /// Đọc một cột thành chuỗi. Ô rỗng thành `nil` — chúng không tạo ra một nhóm "rỗng".
    private func readTextColumn(_ column: String) -> [String?] {
        let quoted = "\"" + column.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        guard let result = try? CSVQueryEngine.run(
            "SELECT \(quoted) FROM \(CSVQueryEngine.tableName)",
            in: editorDocument.buffer, dialect: csvDialect,
            sourcePath: editorDocument.path) else { return [] }
        return result.rows.map { row in
            guard let text = row.first ?? nil, !text.isEmpty else { return nil }
            return text
        }
    }

    /// Drill = TÔ các dòng của nhóm ngay trong tài liệu và nhảy tới dòng đầu.
    private func drillIntoGroup(_ group: GroupMining.GroupResult) {
        guard !group.rowIndices.isEmpty else { return }
        guard let index = try? CSVRowIndex.build(
            in: editorDocument.buffer, dialect: csvDialect) else { return }
        var updated = marks
        updated.setActiveColor(2)
        var firstOffset: Int?
        var marked = 0
        for row in group.rowIndices {
            guard let offset = index.rowStart(row, in: editorDocument.buffer) else { continue }
            if firstOffset == nil { firstOffset = offset }
            let line = editorDocument.buffer.lineNumber(atOffset: offset)
            if updated.colors(at: line).isEmpty { updated.toggle(line) }
            marked += 1
        }
        marks = updated
        if let firstOffset { revealOffset(firstOffset) }
        showTransient(String(
            format: L("Đã đánh dấu %d dòng của nhóm «%@»"), marked, group.name))
    }

    private func exportGroupMining(_ report: GroupMining.Report) {
        var out = report.methodology
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "# " + $0 }.joined(separator: "\n") + "\n"
        for ranking in GroupMining.Ranking.allCases {
            let top = report.ranked(by: ranking, limit: 5)
            guard !top.isEmpty else { continue }
            out += "# --- " + ranking.vietnamese + " ---\n"
            for group in top { out += "# \(group.name)\n" }
        }
        out += "nhom,so_hang,bat_thuong,ty_le,hang_rao_thap,hang_rao_cao,mape,r,lech_r,ghi_chu\n"
        for group in report.groups {
            out += [group.name, String(group.rowCount), String(group.anomalies),
                    ChartRender.number(group.anomalyRate),
                    group.fence.map { ChartRender.number($0.low) } ?? "",
                    group.fence.map { ChartRender.number($0.high) } ?? "",
                    group.mape.map { ChartRender.number($0) } ?? "",
                    group.correlation.map { ChartRender.number($0) } ?? "",
                    group.correlationGap.map { ChartRender.number($0) } ?? "",
                    group.note]
                .map(Self.csvEscaped).joined(separator: ",") + "\n"
        }
        openTextInNewTab(out, label: "khai-pha-nhom.csv")
    }

    // MARK: - Chuỗi thời gian (FR-MIN-004)

    @objc func showForecast(_ sender: Any?) {
        let numeric = numericColumnNames()
        guard let first = numeric.first else {
            return showBanner(
                L("Bảng này không có cột số nào để dự báo."), actionTitle: nil, action: nil)
        }
        attachForecastPanel()
        forecastPanel.isHidden = false
        forecastHeight.constant = panelOpenHeight(.forecast)
        forecastColumns = numeric
        runForecast(on: first)
    }

    func hideForecastPanel() {
        forecastHeight.constant = 0
        forecastPanel.isHidden = true
    }

    /// Chuỗi được đọc theo ĐÚNG thứ tự hàng trong file.
    ///
    /// Không sắp lại, và không hỏi cột thời gian. Đây là một giả định, nên nó phải hiện ra: dự
    /// báo chỉ có nghĩa khi các hàng đã theo thứ tự thời gian, và một bảng đã sắp theo doanh thu
    /// sẽ cho ra một "chuỗi" tăng dần hoàn hảo cùng một dự báo vô nghĩa. Khối Phương pháp nói
    /// điều này trong tệp xuất.
    private func runForecast(on column: String) {
        forecastColumn = column
        let values = readNumericColumn(column).filter { $0.isFinite }
        guard values.count >= 4 else {
            return showBanner(
                LF("Cột «%@» chỉ có %d giá trị số — cần ít nhất 4 để dự báo.",
                       column, values.count),
                actionTitle: nil, action: nil)
        }
        let model = forecastPanel.selectedModel
        guard let comparison = try? TimeSeries.forecast(
            values, horizon: forecastPanel.horizon, model: model,
            period: forecastPanel.period) else {
            return showBanner(
                L("Không dựng được dự báo cho cột này."), actionTitle: nil, action: nil)
        }
        forecastPanel.present(
            comparison, history: values, column: column, allColumns: forecastColumns)
    }

    private func exportForecast(_ comparison: TimeSeries.Comparison) {
        var out = comparison.methodology
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "# " + $0 }.joined(separator: "\n") + "\n"
        out += L("# Chuỗi đọc theo ĐÚNG thứ tự hàng trong file — không sắp lại, không suy ra cột thời gian.\n")
        out += "# --- " + L("Sai số huấn luyện") + " ---\n"
        for forecast in [comparison.chosen] + comparison.baselines {
            let accuracy = forecast.accuracy
            out += "# \(forecast.model.vietnamese): MAE "
                + "\(ChartRender.number(accuracy?.mae ?? .nan)) · MAPE "
                + (accuracy?.mape.map { ChartRender.number($0) + "%" } ?? "—") + "\n"
        }
        out += "ky,du_bao,thap_80,cao_80,thap_95,cao_95\n"
        let forecast = comparison.chosen
        for step in forecast.future.indices {
            out += [String(step + 1), ChartRender.number(forecast.future[step]),
                    ChartRender.number(forecast.lower80[step]),
                    ChartRender.number(forecast.upper80[step]),
                    ChartRender.number(forecast.lower95[step]),
                    ChartRender.number(forecast.upper95[step])]
                .joined(separator: ",") + "\n"
        }
        openTextInNewTab(out, label: "du-bao.csv")
    }

    // MARK: - Phân cụm (FR-MIN-002)

    @objc func showClusterSheet(_ sender: Any?) {
        let numeric = numericColumnNames()
        guard numeric.count >= 2 else {
            return showBanner(
                L("Cần ít nhất 2 cột số để phân cụm."), actionTitle: nil, action: nil)
        }
        let values = numeric.map { readNumericColumn($0) }
        let sheet = ClusterSheet(columns: numeric, values: values)
        clusterSheet = sheet
        sheet.present(in: window) { [weak self] choice in
            self?.runClustering(choice, allColumns: numeric, values: values)
        }
    }

    /// Chạy phân cụm rồi dựng CẢ BA đầu ra mà đặc tả đòi: tab mới có `cluster_id`, bảng tâm
    /// cụm, và scatter tô màu theo cụm.
    private func runClustering(
        _ choice: ClusterSheet.Choice, allColumns: [String], values: [[Double]]
    ) {
        let indices = choice.columns.compactMap { allColumns.firstIndex(of: $0) }
        guard !indices.isEmpty else { return }
        let rowCount = values.first?.count ?? 0
        let rows = (0..<rowCount).map { row in indices.map { values[$0][row] } }

        let result: Clustering.Result
        do {
            switch choice.algorithm {
            case .kMeans:
                result = try Clustering.kMeans(
                    rows: rows, columns: choice.columns, k: choice.k, scaling: choice.scaling)
            case .dbscan:
                result = try Clustering.dbscan(
                    rows: rows, columns: choice.columns, eps: choice.eps,
                    minPoints: choice.minPoints, scaling: choice.scaling)
            }
        } catch let failure as Clustering.Failure {
            return showBanner(failure.message, actionTitle: nil, action: nil)
        } catch {
            return showBanner(error.localizedDescription, actionTitle: nil, action: nil)
        }
        lastClusterResult = result

        // Tab kết quả mở TRƯỚC, biểu đồ vẽ SAU — thứ tự này có nghĩa, không phải tuỳ tiện.
        //
        // Đổi tài liệu là đóng mọi panel trưng kết quả của tài liệu cũ (`hideDocumentPanels`),
        // nên vẽ biểu đồ rồi mới mở tab thì chính cú mở tab ấy dọn mất biểu đồ vừa vẽ. Và chỗ
        // đúng của nó vốn là cạnh BẢNG KẾT QUẢ: người dùng đọc `cluster_id` ở tab mới rồi nhìn
        // sang hình để thấy ba cụm nằm đâu.
        exportClusters(result, rows: rowCount)

        // Scatter tô màu theo cụm — chỉ vẽ được khi có đúng hai chiều để đặt lên hai trục.
        // Nhiều hơn thì lấy hai cột ĐẦU và nói ra, chứ không im lặng vẽ một hình đúng về kỹ
        // thuật mà sai về ý nghĩa (người xem sẽ tưởng cụm được tìm trên hai chiều ấy).
        if indices.count >= 2 {
            var points: [ChartData.Point] = []
            var groups: [Int] = []
            for row in 0..<rowCount {
                guard let label = result.labels[row] else { continue }
                let x = values[indices[0]][row], y = values[indices[1]][row]
                guard x.isFinite, y.isFinite else { continue }
                points.append(ChartData.Point(x: x, y: y))
                groups.append(label)
            }
            var title = String(
                format: L("Cụm theo %@ và %@"), choice.columns[0], choice.columns[1])
            if indices.count > 2 {
                title += String(
                    format: L(" — cụm tìm trên %d chiều, hình chỉ vẽ 2 chiều đầu"),
                    indices.count)
            }
            attachChartPanel()
            chartPanel.isHidden = false
            chartHeight.constant = panelOpenHeight(.chart)
            chartPanel.showClusters(
                points: points, groups: groups, title: title,
                note: result.silhouetteNote)
        }
    }

    /// Tab mới: khối Phương pháp, bảng tâm cụm, rồi dữ liệu gốc + `cluster_id`.
    private func exportClusters(_ result: Clustering.Result, rows: Int) {
        var out = result.methodology
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "# " + $0 }.joined(separator: "\n") + "\n"
        out += L("# --- Tâm cụm (thang gốc) ---\n")
        out += "# cluster_id,kich_thuoc," + result.columns.joined(separator: ",") + "\n"
        for cluster in result.clusters {
            out += "# " + ([String(cluster.id), String(cluster.size)]
                + cluster.centreInOriginalUnits.map { ChartRender.number($0) })
                .joined(separator: ",") + "\n"
        }
        if result.noiseCount > 0 {
            out += String(
                format: L("# nhiễu (cluster_id = -1): %d dòng\n"), result.noiseCount)
        }
        out += "dong,cluster_id\n"
        for row in 0..<rows {
            // Dòng thiếu số để TRỐNG chứ không gán 0 — 0 là một cụm thật, và nhét dòng hỏng vào
            // đó là bịa ra thành viên cho nó.
            let label = result.labels[row].map(String.init) ?? ""
            out += "\(row + 2),\(label)\n"
        }
        openTextInNewTab(out, label: "phan-cum.csv")
    }

    // MARK: - Ma trận tương quan (FR-MIN-005)

    @objc func showCorrelation(_ sender: Any?) {
        let numeric = numericColumnNames()
        guard numeric.count >= 2 else {
            return showBanner(
                L("Cần ít nhất 2 cột số để tính tương quan."), actionTitle: nil, action: nil)
        }
        attachCorrelationPanel()
        correlationPanel.isHidden = false
        correlationHeight.constant = panelOpenHeight(.correlation)
        correlationColumns = numeric
        correlationValues = numeric.map { readNumericColumn($0) }
        recomputeCorrelation(method: .pearson)
    }

    func hideCorrelationPanel() {
        correlationHeight.constant = 0
        correlationPanel.isHidden = true
    }

    /// Đổi phương pháp chạy lại trên ẢNH CHỤP sẵn có, không đọc lại đĩa — cùng lý do với thanh
    /// trượt của bảng bất thường.
    private func recomputeCorrelation(method: Correlation.Method) {
        guard !correlationValues.isEmpty else { return }
        guard let matrix = try? Correlation.matrix(
            correlationValues, names: correlationColumns, method: method) else { return }
        correlationPanel.present(matrix, columns: correlationValues)
    }

    /// Bấm một ô → biểu đồ phân tán hai cột kèm đường hồi quy và R² (FR-MIN-005).
    private func showScatter(row: Int, column: Int) {
        guard row < correlationValues.count, column < correlationValues.count else { return }
        let xs = correlationValues[column]
        let ys = correlationValues[row]
        var points: [ChartData.Point] = []
        for index in 0..<min(xs.count, ys.count) where xs[index].isFinite && ys[index].isFinite {
            points.append(ChartData.Point(x: xs[index], y: ys[index]))
        }
        guard !points.isEmpty else { return }

        let xName = correlationColumns[column]
        let yName = correlationColumns[row]
        let fit = Correlation.fit(x: xs, y: ys)
        // Tiêu đề mang R² và phương trình: xuất ảnh ra thì hai con số ấy đi theo, chứ không ở
        // lại trong một dòng trạng thái của cửa sổ.
        var title = "\(yName) theo \(xName)"
        if let fit {
            title += " — \(fit.equation(x: xName, y: yName)) · R² = \(ChartRender.number(fit.r2))"
        }
        attachChartPanel()
        chartPanel.isHidden = false
        chartHeight.constant = panelOpenHeight(.chart)
        chartPanel.showScatter(
            points: points, title: title,
            trendLine: fit.map { (slope: $0.slope, intercept: $0.intercept) },
            caveat: Correlation.caveat)
    }

    private func exportCorrelation(_ matrix: Correlation.Matrix) {
        var out = matrix.methodology
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "# " + $0 }.joined(separator: "\n") + "\n"
        out += "cot_1,cot_2,he_so,n,ghi_chu\n"
        for cell in matrix.cells where cell.row != cell.column {
            out += [matrix.columns[cell.row], matrix.columns[cell.column],
                    cell.value.map { ChartRender.number($0) } ?? "",
                    String(cell.count), cell.note ?? ""]
                .map(Self.csvEscaped).joined(separator: ",") + "\n"
        }
        openTextInNewTab(out, label: "tuong-quan.csv")
    }

    /// Xuất danh sách vi phạm ra TAB MỚI (FR-DQR-001).
    private func exportViolations() {
        guard let report = qualityReport else { return }
        var out = "muc,luat,vi_pham,ty_le\n"
        for result in report.results where !result.passed {
            let severity = result.failure != nil
                ? "hỏng" : (result.rule.severity == .error ? "lỗi" : "cảnh báo")
            let title = result.failure ?? result.rule.title
            out += [severity, title, String(result.violations),
                    String(format: "%.2f%%", result.violationPercent)]
                .map(Self.csvEscaped).joined(separator: ",") + "\n"
        }
        openTextInNewTab(out, label: "vi-pham.csv")
    }

    // MARK: - Móc tự kiểm cho pivot và danh mục

    func columnNamesForSelfTest() -> [String] { currentColumnNames() }
    func makePivotSheetForSelfTest() -> PivotSheet {
        let sheet = PivotSheet(columns: currentColumnNames())
        pivotSheet = sheet
        return sheet
    }
    func applyPivotSQLForSelfTest(_ sql: String) {
        sqlPanel.setQuery(sql)
    }
    var catalogTableNamesForSelfTest: [String] { queryCatalog.tables.map(\.name) }
    var catalogStaleCountForSelfTest: Int { queryCatalog.staleTables.count }

    // MARK: - Móc tự kiểm cho biểu đồ

    var chartPanelVisibleForSelfTest: Bool { isAttached(.chart) && !chartPanel.isHidden }
    func closeChartPanelForSelfTest() { hideChartPanel() }

    // MARK: - Móc tự kiểm cho bảng chất lượng

    var qualityPanelVisibleForSelfTest: Bool { isAttached(.quality) && !qualityPanel.isHidden }
    var anomalyPanelVisibleForSelfTest: Bool { isAttached(.anomaly) && !anomalyPanel.isHidden }
    var anomalyColumnsForSelfTest: [String] { anomalyColumns }
    var correlationPanelVisibleForSelfTest: Bool {
        isAttached(.correlation) && !correlationPanel.isHidden
    }
    func showCorrelationForSelfTest() { showCorrelation(nil) }
    var forecastPanelVisibleForSelfTest: Bool {
        isAttached(.forecast) && !forecastPanel.isHidden
    }
    func showForecastForSelfTest() { showForecast(nil) }
    var groupMiningPanelVisibleForSelfTest: Bool {
        isAttached(.groupMining) && !groupMiningPanel.isHidden
    }
    func showGroupMiningForSelfTest() { showGroupMining(nil) }
    var associationPanelVisibleForSelfTest: Bool {
        isAttached(.association) && !associationPanel.isHidden
    }
    func showAssociationForSelfTest() { showAssociation(nil) }
    func setReportParameterForSelfTest(_ name: String, _ value: String) {
        reportParameters[name] = value
    }
    func exportAssociationForSelfTest() {
        guard let result = associationPanel.result else { return }
        exportAssociation(result)
    }
    func exportGroupMiningForSelfTest() {
        guard let report = groupMiningPanel.report else { return }
        exportGroupMining(report)
    }
    func exportForecastForSelfTest() {
        guard let comparison = forecastPanel.comparison else { return }
        exportForecast(comparison)
    }
    /// Dựng sheet phân cụm mà KHÔNG mở nó — sheet mở ra sẽ treo lượt chạy không người.
    func makeClusterSheetForSelfTest() -> ClusterSheet? {
        let numeric = numericColumnNames()
        guard numeric.count >= 2 else { return nil }
        let values = numeric.map { readNumericColumn($0) }
        let sheet = ClusterSheet(columns: numeric, values: values)
        clusterSheet = sheet
        sheet.buildForSelfTest { [weak self] choice in
            self?.runClustering(choice, allColumns: numeric, values: values)
        }
        return sheet
    }
    func exportCorrelationForSelfTest() {
        guard let matrix = correlationPanel.matrix else { return }
        exportCorrelation(matrix)
    }
    /// Các màu Mark đang dùng trên tài liệu hiện tại — để kiểm vế "màu theo mức nặng".
    func markColorsForSelfTest() -> [Int] {
        let lineCount = editorDocument.buffer.lineCount
        var out: [Int] = []
        for line in 0...max(0, lineCount) { out += marks.colors(at: line) }
        return out
    }
    func showAnomaliesForSelfTest() { showAnomalies(nil) }
    func exportAnomaliesForSelfTest() {
        guard let report = anomalyPanel.report else { return }
        exportAnomalies(report)
    }
    func markAllAnomaliesForSelfTest() {
        guard let report = anomalyPanel.report else { return }
        markAnomalies(
            report.findings.map { ($0, anomalyPanel.severityForSelfTest($0)) }, reveal: false)
    }
    func showQualityReportForSelfTest() { showQualityReport(nil) }
    func closeQualityPanelForSelfTest() { hideQualityPanel() }
    func exportViolationsForSelfTest() { exportViolations() }

    /// Xuất kết quả ra TAB MỚI dạng CSV — không đụng vào file gốc (NFR-QRY-03).
    private func exportSQLResult(_ result: CSVQueryEngine.Result) {
        var out = ""
        // `NULL` thành ô RỖNG. Đó là quy ước CSV, và nó có mất mát: xuất ra rồi thì "chưa có
        // giá trị" và "chuỗi rỗng" không phân biệt được nữa. Chấp nhận vì mọi công cụ khác đọc
        // CSV đều hiểu ô rỗng theo nghĩa ấy; muốn giữ phân biệt thì phải xuất JSON.
        for row in [result.titles.map { Optional($0) }] + result.rows {
            out += row.map { Self.csvEscaped($0 ?? "") }.joined(separator: ",") + "\n"
        }
        openTextInNewTab(out, label: "ketqua.csv")
    }

    /// Bọc một ô theo luật CSV khi cần.
    ///
    /// Kết quả truy vấn chứa dữ liệu của người dùng, và dữ liệu ấy có dấu phẩy, dấu nháy, xuống
    /// dòng. Ghép thẳng bằng dấu phẩy là sinh ra một file CSV hỏng mang đúng hình dạng đúng.
    private static func csvEscaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n")
                || value.contains("\r")
        else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Móc tự kiểm SQL

    var sqlPanelVisibleForSelfTest: Bool { isAttached(.sql) && !sqlPanel.isHidden }
    func openSQLPanelForSelfTest() { showSQLPanel(nil) }
    func closeSQLPanelForSelfTest() { hideSQLPanel() }
    /// Chạy ĐỒNG BỘ, không qua luồng nền — bài tự kiểm không có run loop để đợi.
    func runSQLForSelfTest(_ text: String) throws -> CSVQueryEngine.Result {
        try CSVQueryEngine.run(
            text, in: editorDocument.buffer, dialect: csvDialect, sourcePath: editorDocument.path)
    }
    func exportSQLForSelfTest(_ result: CSVQueryEngine.Result) { exportSQLResult(result) }

    /// Đợi truy vấn chạy xong — panel chạy ở LUỒNG NỀN nên bài kiểm phải quay vòng sự kiện.
    ///
    /// Ngủ suông ở đây là khoá cứng: kết quả về trên hàng đợi CHÍNH. Cùng cái bẫy mà
    /// `waitForHighlightingForSelfTest` đã ghi.
    ///
    /// Không có hàm này thì bài kiểm đọc "Đang chạy…" rồi kết luận — hoặc tệ hơn, ĐÔI KHI đọc
    /// đúng kết quả và xanh do may. Một bài kiểm xanh do may là bài kiểm sẽ đỏ vào lúc bất tiện
    /// nhất, trên máy của người khác.
    @discardableResult
    func waitForSQLResultForSelfTest(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            if sqlPanel.summaryForSelfTest != L("Đang chạy…") { return true }
        }
        return false
    }

    private func revealOffset(_ offset: Int) {
        if isTableViewVisible { toggleTableView(nil) }
        editorView.repaginate(around: offset)
        editorView.setCaret(documentOffset: offset)
        editorView.reveal(documentOffset: offset)
        updateCaretStatus()
    }

    // MARK: - Móc tự kiểm JSONPath

    func toggleDocumentMapForSelfTest() { toggleDocumentMap(nil) }

    /// Bố cục xong rồi VẼ bản đồ, rồi mới cho đo.
    ///
    /// `flushDrawingForSelfTest` không thay được: nó ép vẽ vùng soạn thảo, còn bản đồ là view khác.
    ///
    /// **Cố ý KHÔNG gọi `refreshDocumentMap` ở đây.** Gọi thì móc này tự tay sửa đúng thứ nó
    /// sắp đo: bản đồ dựng hụt vẫn được dựng lại ngay trước lúc đo và bài kiểm xanh trong khi
    /// người dùng thật vẫn thấy cột xám. Người dùng không gọi refresh bằng tay — bản đồ phải tự
    /// đúng qua đường của nó (`onHeightChanged`), và bài kiểm phải đi đúng đường ấy.
    func drawDocumentMapForSelfTest() {
        window?.layoutIfNeeded()
        window?.contentView?.layoutSubtreeIfNeeded()
        CATransaction.begin()
        documentMapView.display()
        CATransaction.flush()
        CATransaction.commit()
    }

    var documentMapVisibleForSelfTest: Bool { isDocumentMapVisible }

    var jsonPathPanelVisibleForSelfTest: Bool {
        isAttached(.jsonPath) && !jsonPathPanel.isHidden
    }
    func openJSONPathForSelfTest() { showJSONPathPanel(nil) }
    func closeJSONPathForSelfTest() { hideJSONPathPanel() }

    /// Đưa cửa sổ về trạng thái sạch: đóng mọi panel, về chế độ văn bản.
    ///
    /// Bộ chụp ảnh cần cái này. Không có nó thì mỗi cảnh chụp lẫn cả những panel cảnh trước để
    /// lại, và ảnh "cảnh bản đồ" hóa ra là ảnh bản đồ + bảng CSV + JSONPath + Tìm + Bàn làm sạch
    /// chồng lên nhau — một công cụ sinh ra để NHÌN mà lại tự làm cho ảnh không đọc được.
    /// Chỉ đụng tới panel ĐÃ gắn — ràng buộc bề cao khác `nil` là dấu hiệu ấy. Gọi thẳng hàm
    /// `hide…` cho một panel chưa gắn sẽ dựng nó ra (chúng đều `lazy`) và làm bố cục cảnh đầu
    /// tiên khác đi, hoặc chết ngay vì ràng buộc chưa có.
    func resetWindowForSelfTest() {
        if findPanelHeight != nil { hideFindPanel() }
        if jsonPathHeight != nil { hideJSONPathPanel() }
        if cleanHeight != nil { hideCleanPanel() }
        if validationHeight != nil { hideValidationPanel() }
        if isTableViewVisible { toggleTableView(nil) }
        if isSidebarVisible { toggleSidebar(nil) }
        if isDocumentMapVisible { toggleDocumentMap(nil) }
    }

    // MARK: - Function List (FR-DOC-307)

    /// Ẩn/hiện sidebar (⌘0 theo UI/UX §quy tắc cửa sổ).
    @objc func toggleSidebar(_ sender: Any?) {
        let showing = !isSidebarVisible
        attachSidebar()
        sidebar.isHidden = !showing
        sidebarWidth.constant = showing ? FunctionListView.width : 0
        if showing {
            refreshFunctionList()
            // Chia lại hai nửa SAU khi sidebar có kích thước thật. Không đặt thì `NSSplitView`
            // dồn gần hết chiều cao cho khung đầu tiên, và Function List còn đúng một dòng
            // tiêu đề nằm sát đáy — thấy rõ trên ảnh chụp.
            DispatchQueue.main.async { [weak self] in self?.balanceSidebar() }
        }
    }

    /// Cây thư mục ~60%, mục lục ~40%.
    ///
    /// Cây thường dài hơn (một dự án có hàng chục file, một file có mươi hàm), nhưng mục lục
    /// phải đủ cao để đọc được — nếu không thì nó chỉ còn là một cái nhãn.
    private func balanceSidebar() {
        let height = sidebar.bounds.height
        guard height > 120 else { return }
        sidebar.setPosition(height * 0.6, ofDividerAt: 0)
    }

    var isSidebarVisible: Bool { sidebarAttached && !sidebar.isHidden }

    /// Mở một thư mục làm workspace (FR-DOC-308).
    @objc func openFolderAsWorkspace(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Mở"
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        // Bookmark tạo NGAY, lúc người dùng vừa cấp quyền qua panel. Đợi tới lúc mở lại app thì
        // không còn gì để tạo bookmark từ đó nữa.
        openWorkspace(url.path, bookmark: SandboxAccess.makeBookmark(for: url), access: nil)
    }

    func openWorkspace(_ path: String) {
        openWorkspace(path, bookmark: SandboxAccess.makeBookmark(for: URL(fileURLWithPath: path)),
                      access: nil)
    }

    /// Mở lại workspace của phiên trước từ bookmark (FR-DOC-308 trong sandbox).
    ///
    /// Trả `false` khi thư mục đã biến mất hoặc quyền không giải mã được — chỗ gọi phải NÓI RA,
    /// vì một cây thư mục rỗng trông giống hệt một thư mục thật sự không có file nào.
    @discardableResult
    func restoreWorkspace(bookmark: Data, path: String?) -> Bool {
        guard let resolved = SandboxAccess.open(bookmark) else { return false }
        guard FileManager.default.fileExists(atPath: resolved.url.path) else {
            SandboxAccess.end(resolved.url)
            return false
        }
        // Giữ tên người dùng đã thấy hôm qua; bookmark giải mã ra đường đã đi qua symlink.
        let display = path ?? resolved.url.path
        openWorkspace(
            display,
            bookmark: resolved.isStale ? SandboxAccess.makeBookmark(for: resolved.url) ?? bookmark
                                       : bookmark,
            access: resolved.url
        )
        return true
    }

    private func openWorkspace(_ path: String, bookmark: Data?, access: URL?) {
        // Thả quyền của workspace CŨ trước khi nhận cái mới. Không thả thì mỗi lần đổi thư mục
        // lại giữ thêm một quyền cho tới khi thoát app.
        if let previous = workspaceAccess { SandboxAccess.end(previous) }
        workspaceAccess = access
        workspaceRoot = path
        workspaceBookmark = bookmark

        if !isSidebarVisible { toggleSidebar(nil) }
        workspaceView.open(root: path)
        balanceSidebar()
        showTransient("Workspace: \((path as NSString).lastPathComponent)")
        saveSession()
    }

    /// Lệnh từ menu ngữ cảnh của cây thư mục.
    ///
    /// Mọi lệnh sửa đĩa đều đi qua đây chứ không nằm trong view: view hỏi, controller làm và
    /// chịu trách nhiệm báo lỗi. Hỏi tên bằng hộp thoại vì đây là thao tác hiếm và cần chính
    /// xác — sửa tên ngay trên cây thì một phím Escape lỡ tay là mất tên vừa gõ.
    private func runWorkspaceCommand(_ command: WorkspaceView.Command) {
        do {
            switch command {
            case let .newFile(directory):
                guard let name = askForName(title: "File mới", suggestion: "moi.txt") else { return }
                let path = try Workspace.createFile(named: name, in: directory)
                workspaceView.refreshNow()
                openInNewTab(path: path)

            case let .newFolder(directory):
                guard let name = askForName(title: "Thư mục mới", suggestion: "thu_muc") else { return }
                _ = try Workspace.createDirectory(named: name, in: directory)
                workspaceView.refreshNow()

            case let .rename(path):
                let current = (path as NSString).lastPathComponent
                guard let name = askForName(title: "Đổi tên", suggestion: current), name != current
                else { return }
                _ = try Workspace.rename(path, to: name)
                workspaceView.refreshNow()

            case let .moveToTrash(path):
                // Hỏi lại: sidebar là chỗ bấm nhanh, và một cú bấm nhầm vào thư mục dự án là
                // chuyện khác hẳn một cú bấm nhầm vào một file.
                let alert = NSAlert()
                alert.messageText = "Chuyển «\((path as NSString).lastPathComponent)» vào Thùng rác?"
                alert.informativeText = "Lấy lại được từ Thùng rác."
                alert.addButton(withTitle: "Chuyển vào Thùng rác")
                alert.addButton(withTitle: "Hủy")
                guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
                try Workspace.moveToTrash(path)
                workspaceView.refreshNow()

            case let .revealInFinder(path):
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
        } catch let error as Workspace.FileError {
            findPanel.showStatus(error.message, isError: true)
        } catch {
            presentError("Không thực hiện được", error)
        }
    }

    /// Hộp thoại một dòng để hỏi tên.
    private func askForName(title: String, suggestion: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Hủy")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = suggestion
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    /// Dựng lại mục lục ở luồng nền.
    ///
    /// Chỉ chạy khi sidebar đang mở: phân tích cả tài liệu tốn tiền, và tiêu nó cho một khung
    /// nhìn đang đóng là tiêu vô ích. Mở ra thì dựng ngay, đóng lại thì thôi.
    func refreshFunctionList() {
        guard !functionList.isHidden else { return }
        outlineToken?.cancel()
        let token = CancelToken()
        outlineToken = token

        let buffer = editorDocument.buffer
        let language = editorDocument.path.flatMap { SyntaxLanguage.detect(path: $0) }
        functionList.showScanning()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = DocumentOutline.symbols(
                in: buffer, language: language, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                self.functionList.present(result)
                self.functionList.highlight(offset: self.editorView.selectedDocumentRange.lowerBound)
            }
        }
    }

    /// Đưa con nháy tới một định nghĩa.
    private func revealSymbol(_ symbol: DocumentSymbol) {
        if isTableViewVisible { toggleTableView(nil) }
        editorView.repaginate(around: symbol.offset)
        editorView.setCaret(documentOffset: symbol.offset)
        editorView.reveal(documentOffset: symbol.offset)
        updateCaretStatus()
        findPanel.showStatus("\(symbol.name) — dòng \(symbol.line)")
    }

    /// Mở Bàn làm sạch: quét nền rồi hiện danh mục phát hiện.
    ///
    /// Quét ở luồng NỀN và hủy được, cùng lý do với kiểm dữ liệu: một lượt quét bảng một triệu
    /// hàng mất hàng chục giây, và ứng dụng đứng hình trong lúc đó thì người dùng chỉ biết là
    /// nó hỏng.
    /// Xem trước cắt chunk — FR-KNW-903.
    ///
    /// Ranh giới tô bằng chính DẤU DÒNG (`LineMarkBook`) chứ không bằng một lớp tô riêng: dấu
    /// dòng đã có sẵn ở bản đồ tài liệu, ở thanh cuộn, và ở lệnh "nhảy dấu kế tiếp". Dựng một
    /// cơ chế tô thứ hai nghĩa là ba chỗ ấy không thấy chunk, và người dùng phải học một cách
    /// điều hướng riêng cho đúng một tính năng.
    @objc func showChunkPreview(_ sender: Any?) {
        let menu = NSMenu()
        for (ten, tag) in [(L("Cỡ cố định 800B, chồng 100B"), 0),
                           (L("Theo câu (≤ 800B)"), 1),
                           (L("Theo heading Markdown"), 2)] {
            let muc = menu.addItem(withTitle: ten, action: #selector(catChunk(_:)),
                                   keyEquivalent: "")
            muc.target = self
            muc.tag = tag
        }
        guard let anchor = window?.contentView else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 40, y: anchor.bounds.height - 40), in: anchor)
    }

    @objc private func catChunk(_ sender: NSMenuItem) {
        let chien_luoc: Chunker.Strategy
        switch sender.tag {
        case 1: chien_luoc = .sentence(maxSize: 800)
        case 2: chien_luoc = .heading(level: 3)
        default: chien_luoc = .fixed(size: 800, overlap: 100)
        }

        let buffer = editorDocument.buffer
        let chunks = Chunker.chunks(in: buffer, strategy: chien_luoc)
        guard !chunks.isEmpty else {
            return showBanner(L("Tài liệu rỗng — không có chunk nào."), actionTitle: nil, action: nil)
        }
        lastChunks = chunks

        // Tô dòng ĐẦU của mỗi chunk. Tô cả khối thì cả tài liệu sáng lên và ranh giới biến mất —
        // thứ người dùng cần thấy ở đây là chỗ CẮT, không phải chỗ có chữ.
        var sach = LineMarkBook()
        sach.setActiveColor(2)
        for chunk in chunks { sach.toggle(buffer.lineNumber(atOffset: chunk.range.lowerBound)) }
        marks = sach
        refreshChrome()

        let trungBinh = chunks.reduce(0) { $0 + $1.byteCount } / chunks.count
        showBanner(
            LF("%d chunk · trung bình %d B · %@",
                   chunks.count, trungBinh, chien_luoc.displayName),
            actionTitle: L("Xuất JSONL"), action: #selector(xuatChunkJSONL))
    }

    /// Xuất chunk vừa xem trước ra JSONL, ở TAB MỚI.
    @objc func xuatChunkJSONL() {
        guard !lastChunks.isEmpty else { return }
        let jsonl = Chunker.jsonl(lastChunks, in: editorDocument.buffer,
                                  source: editorDocument.path)
        openTextInNewTab(jsonl, label: L("Chunk JSONL"))
    }

    /// Khai phá văn bản — FR-MIN-006.
    ///
    /// Kết quả ra một TAB MỚI dạng CSV, không dựng panel thứ mười lăm: bảng ấy đã là một bảng
    /// CSV thật, nên Table view, sắp xếp, lọc và xuất file đều chạy sẵn trên nó. Một panel riêng
    /// sẽ phải dựng lại cả bốn thứ đó, tệ hơn ở mọi mặt.
    ///
    /// Vế *"click từ → Mark mọi occurrence"* của đặc tả đi qua FR-KNW-908: kết quả chuyển thành
    /// danh sách entity rồi tô bằng chính cơ chế Mark. Đó cũng là điều đặc tả đòi — *"kết quả
    /// dùng được làm đầu vào cho entity marker"*.
    @objc func showTextMining(_ sender: Any?) {
        let text = editorDocument.buffer.text
        guard !text.isEmpty else {
            return showBanner(L("Tài liệu rỗng."), actionTitle: nil, action: nil)
        }
        // Corpus JSONL thì khai phá trên TRƯỜNG TEXT, không trên cả dòng JSON: đếm tần suất trên
        // chữ `"id"` và `"text"` của chính cú pháp JSON là đếm nhiễu.
        let documents: [String]
        if let doi = try? KnowledgeConvert.chunkObjects(text, skippingBadLines: true), !doi.isEmpty {
            documents = doi.compactMap { $0["text"] }
        } else {
            documents = [text]
        }

        let report = TextMining.run(documents: documents, config: .init())
        lastMiningReport = report
        guard !report.terms.isEmpty else {
            return showBanner(L("Không rút được từ khoá nào."), actionTitle: nil, action: nil)
        }

        openTextInNewTab(TextMining.csv(report), label: L("Từ khoá"))
        csvModeOverride = true
        refreshChrome()
        showBanner(
            LF("%d từ khoá · %d token · %d tài liệu",
                   report.terms.count, report.tokenCount, report.documentCount),
            actionTitle: L("Tô lên tài liệu"), action: #selector(toTuKhoaLenTaiLieu))
    }

    /// Tô mọi từ khoá lên tài liệu NGUỒN — đi qua FR-KNW-908, không dựng đường tô thứ hai.
    @objc func toTuKhoaLenTaiLieu() {
        guard let report = lastMiningReport else { return }
        // Quay về tab nguồn trước: bảng từ khoá là một tài liệu KHÁC, tô lên nó thì vô nghĩa.
        closeCurrentTabForSelfTest()
        danhDauEntities(TextMining.entities(report))
    }

    /// Đánh dấu entity — FR-KNW-908.
    ///
    /// Dùng lại cơ chế Mark NHIỀU MÀU đúng như đặc tả đòi, không dựng lớp tô riêng: nhờ vậy bản
    /// đồ tài liệu, thanh cuộn và lệnh "nhảy dấu kế tiếp" thấy entity luôn.
    ///
    /// Giới hạn phải nói ra: Mark tô theo DÒNG, nên một dòng chứa hai loại entity chỉ hiện được
    /// màu của loại đầu. Bảng thống kê thì đếm đủ cả hai — nên con số luôn đúng kể cả khi màu
    /// không kể hết. Tô theo KHOẢNG cần một lớp tô thứ hai, và đó là đánh đổi lớn hơn giá trị nó
    /// mang lại ở đây.
    @objc func showEntityMarking(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.message = L("Chọn danh sách entity (CSV hoặc JSON)")
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        napVaDanhDauEntity(path: url.path)
    }

    func napVaDanhDauEntity(path: String) {
        guard let noi_dung = try? String(contentsOfFile: path, encoding: .utf8) else {
            return showBanner(L("Không đọc được danh sách entity."), actionTitle: nil, action: nil)
        }
        let entities: [EntityMarker.Entity]
        do {
            entities = (path as NSString).pathExtension.lowercased() == "json"
                ? try EntityMarker.loadJSON(noi_dung)
                : try EntityMarker.loadCSV(noi_dung)
        } catch let failure as EntityMarker.Failure {
            return showBanner(failure.reason, actionTitle: nil, action: nil)
        } catch {
            return showBanner(L("Không đọc được danh sách entity."), actionTitle: nil, action: nil)
        }
        guard !entities.isEmpty else {
            return showBanner(L("Danh sách entity rỗng."), actionTitle: nil, action: nil)
        }

        danhDauEntities(entities)
    }

    /// Tô một danh sách entity lên tài liệu đang mở. Tách riêng để FR-MIN-006 gọi lại — hai
    /// đường tô là hai chỗ để lệch nhau.
    func danhDauEntities(_ entities: [EntityMarker.Entity]) {
        let report = EntityMarker.find(entities, in: editorDocument.buffer)
        lastEntityReport = report
        guard !report.occurrences.isEmpty else {
            return showBanner(
                LF("Không thấy entity nào trong tài liệu (%d mục đã nạp).",
                       entities.count),
                actionTitle: nil, action: nil)
        }

        var sach = LineMarkBook()
        for o in report.occurrences {
            sach.setActiveColor(report.colorOfType[entities[o.entity].type] ?? 0)
            if !sach.colors(at: o.line).contains(report.colorOfType[entities[o.entity].type] ?? 0) {
                sach.toggle(o.line)
            }
        }
        marks = sach
        refreshChrome()

        let doanh_muc = report.byType.sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }.joined(separator: " · ")
        showBanner(LF("%d lần xuất hiện · %@", report.occurrences.count, doanh_muc),
                   actionTitle: nil, action: nil)
    }

    /// Chuyển đổi tri thức — FR-KNW-910.
    ///
    /// XEM TRƯỚC trước khi tạo tab, đúng khuôn FR-CSV-406: người dùng nhìn năm dòng đầu của kết
    /// quả THẬT rồi mới quyết. Bản xem trước đi qua chính hàm chuyển đổi, không đi đường riêng —
    /// đường riêng là cách chắc chắn để nó nói dối đúng lúc người dùng tin nó.
    @objc func showKnowledgeConvert(_ sender: Any?) {
        let menu = NSMenu()
        // Chỉ kê những cặp CÓ đường đi. Kê hết rồi để người dùng bấm vào một cặp không hỗ trợ
        // là biến một giới hạn đã biết thành một lỗi họ phải tự phát hiện.
        let cap: [(KnowledgeConvert.Format, KnowledgeConvert.Format)] = [
            (.chunksJSONL, .chunksCSV), (.chunksJSONL, .chunksMarkdown),
            (.chunksCSV, .chunksJSONL),
            (.graphDOT, .graphMermaid), (.graphDOT, .graphEdgeList),
            (.graphEdgeList, .graphDOT), (.graphMermaid, .graphDOT),
            // FR-MMD-008 — hai chiều còn thiếu của tam giác Mermaid ↔ DOT ↔ edge list.
            (.graphMermaid, .graphEdgeList), (.graphEdgeList, .graphMermaid),
        ]
        for (i, (tu, den)) in cap.enumerated() {
            let muc = menu.addItem(
                withTitle: "\(tu.displayName)  →  \(den.displayName)",
                action: #selector(chuyenDoiTriThuc(_:)), keyEquivalent: "")
            muc.target = self
            muc.tag = i
        }
        knowledgeConvertPairs = cap
        guard let anchor = window?.contentView else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 40, y: anchor.bounds.height - 40), in: anchor)
    }

    @objc private func chuyenDoiTriThuc(_ sender: NSMenuItem) {
        guard sender.tag < knowledgeConvertPairs.count else { return }
        let (tu, den) = knowledgeConvertPairs[sender.tag]
        chuyenDoiTriThucForSelfTest(from: tu, to: den)
    }

    /// Tách khỏi phần menu để bài tự kiểm gọi thẳng được.
    func chuyenDoiTriThucForSelfTest(
        from tu: KnowledgeConvert.Format, to den: KnowledgeConvert.Format
    ) {
        let nguon = editorDocument.buffer.text
        let xem: String
        do {
            xem = try KnowledgeConvert.preview(nguon, from: tu, to: den)
        } catch let failure as KnowledgeConvert.Failure {
            // Nói NGUYÊN VĂN lý do — mọi lỗi ở đây đều là câu dẫn người dùng đi đâu tiếp.
            return showBanner(failure.reason, actionTitle: nil, action: nil)
        } catch {
            return showBanner(L("Không chuyển đổi được."), actionTitle: nil, action: nil)
        }

        pendingConvert = (nguon, tu, den)
        let alert = NSAlert()
        alert.messageText = LF("Chuyển đổi: %@ → %@", tu.displayName, den.displayName)
        alert.informativeText = xem
        alert.addButton(withTitle: L("Tạo tab mới"))
        alert.addButton(withTitle: L("Huỷ"))
        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return }
        apChuyenDoiTriThuc()
    }

    /// Áp phép chuyển đổi đang chờ. Tách khỏi hộp thoại có chủ ý: bài tự kiểm KHÔNG được tự
    /// bấm đồng ý — `Unattended.ask` trả `.abort` để giữ đúng điều đó — nên nó kiểm hai nửa
    /// riêng: bản xem trước có đúng không, và phép áp có ra đúng tab mới không.
    func apChuyenDoiTriThuc() {
        guard let (nguon, tu, den) = pendingConvert,
              let ket_qua = try? KnowledgeConvert.convert(nguon, from: tu, to: den) else { return }
        pendingConvert = nil
        openTextInNewTab(ket_qua, label: den.displayName)
    }

    /// Cắt chunk theo một chiến lược, không qua menu — cho bài tự kiểm.
    func catChunkForSelfTest(_ strategy: Chunker.Strategy) {
        let muc = NSMenuItem()
        switch strategy {
        case .fixed: muc.tag = 0
        case .sentence: muc.tag = 1
        case .heading: muc.tag = 2
        }
        catChunk(muc)
    }

    /// Mở file triple/edge dạng BẢNG — FR-KNW-906.
    ///
    /// Ra tab MỚI chứ không đổi tài liệu đang mở: file `.nt` là dữ liệu nguồn, và một lệnh "xem
    /// dạng bảng" không được phép viết đè lên nó. Cùng khuôn với mọi phép chuyển đổi khác của
    /// FR-CSV-406 và FR-KNW-910.
    @objc func showTripleTable(_ sender: Any?) {
        let (triples, errors) = NTriples.parse(editorDocument.buffer.text)
        guard !triples.isEmpty else {
            return showBanner(
                errors.isEmpty
                    ? L("Tài liệu này không có dòng triple nào.")
                    // Nói ĐÚNG DÒNG đầu tiên hỏng: "file sai định dạng" không giúp ai sửa được gì.
                    : LF("Không đọc được triple nào — dòng %d: %@",
                             errors[0].line, errors[0].reason),
                actionTitle: nil, action: nil)
        }

        openTextInNewTab(NTriples.table(triples), label: L("Bảng triple"))
        // Bảng ra ở dạng TSV nên Table view mở được ngay; bật sẵn để người dùng khỏi phải tìm.
        // Dialect KHÔNG ép: `csvDialect` tự dò từ nội dung, và với một bảng toàn dấu TAB thì nó
        // dò ra `.tab`. Ép tay ở đây sẽ tạo một đường thứ hai quyết định dialect, và hai đường
        // là hai chỗ để lệch nhau.
        csvModeOverride = true
        refreshChrome()

        // ĐẾM dòng hỏng và nói ra. Im lặng bỏ qua là cách một file mất nửa nội dung mà không ai
        // biết — và ở đây "nửa nội dung" là nửa số quan hệ trong một đồ thị tri thức.
        if !errors.isEmpty {
            showBanner(LF("Đã đọc %d triple · %d dòng hỏng bị bỏ qua (dòng đầu: %d)",
                              triples.count, errors.count, errors[0].line),
                       actionTitle: nil, action: nil)
        }
    }

    /// Trùng lặp mờ (FR-CLN-004) — chọn cột, quét cụm, rồi DUYỆT từng cụm.
    ///
    /// Ba chỗ nói ra thay vì im lặng, vì cả ba đều là kết quả hợp lệ mà người dùng dễ đọc thành
    /// "hỏng": bảng không có cột nào, cột chọn xong không có cụm nào, và người duyệt bỏ hết.
    @objc func showFuzzyDedup(_ sender: Any?) {
        let columns = currentColumnNames()
        guard !columns.isEmpty else {
            return showBanner(L("Không đọc được tên cột của bảng này."),
                              actionTitle: nil, action: nil)
        }
        let menu = NSMenu()
        for (index, name) in columns.enumerated() {
            let muc = menu.addItem(withTitle: name, action: #selector(quetTrungLapMo(_:)),
                                   keyEquivalent: "")
            muc.target = self
            muc.tag = index
        }
        // Menu ngay tại con trỏ: chọn cột là bước phụ, không đáng một hộp thoại riêng.
        guard let anchor = window?.contentView else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 40, y: anchor.bounds.height - 40), in: anchor)
    }

    @objc private func quetTrungLapMo(_ sender: NSMenuItem) {
        chayTrungLapMo(column: sender.tag, name: sender.title)
    }

    func chayTrungLapMo(column: Int, name: String) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        guard let clusters = try? CSVFuzzyDedup.scan(
            column: column, in: buffer, dialect: dialect) else {
            return showBanner(L("Không quét được cột này."), actionTitle: nil, action: nil)
        }
        guard !clusters.isEmpty else {
            return showBanner(
                LF("Cột «%@» không có cụm trùng lặp mờ nào.", name),
                actionTitle: nil, action: nil)
        }

        let sheet = CSVFuzzyDedupSheet(clusters: clusters, columnName: name)
        fuzzyDedupSheet = sheet
        sheet.onApply = { [weak self] decisions in
            guard let self else { return }
            self.fuzzyDedupSheet = nil
            guard !decisions.isEmpty,
                  let edits = try? CSVFuzzyDedup.edits(
                      applying: decisions, to: clusters, column: column,
                      in: buffer, dialect: dialect),
                  !edits.isEmpty
            else {
                // Không chọn cụm nào là một câu trả lời HỢP LỆ, không phải một lỗi.
                return self.showBanner(L("Không cụm nào được gộp — tài liệu giữ nguyên."),
                                       actionTitle: nil, action: nil)
            }
            // MỘT bước hoàn tác cho cả lượt duyệt: người dùng đã quyết một lần, họ phải rút lại
            // được bằng một lần.
            self.editorDocument.buffer.applyEdits(
                edits, label: LF("Khử trùng lặp mờ · cột %@", name))
            self.syncViewFromBuffer()
            self.refreshChrome()
            self.showBanner(
                LF("Đã gộp %d cụm · %d ô đổi giá trị", decisions.count, edits.count),
                actionTitle: nil, action: nil)
        }
        guard let window else { return }
        let sheetWindow = NSWindow(contentViewController: sheet)
        sheetWindow.styleMask = [.titled]
        window.beginSheet(sheetWindow)
    }

    @objc func showCleanBench(_ sender: Any?) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        guard buffer.count > 0 else {
            cleanBenchRequests += 1
            return findPanel.showStatus("Tài liệu rỗng — không có gì để làm sạch", isError: true)
        }

        cleanToken?.cancel()
        let token = CancelToken()
        cleanToken = token
        let spec = nullSpec
        // Mở bàn là bắt đầu một phiên mới: nhật ký của tài liệu trước không được theo sang.
        cleanPanel.resetLog()
        findPanel.showStatus("Đang quét để tìm chỗ cần làm sạch…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let findings = try? CSVCleanScanner.scan(
                in: buffer, dialect: dialect, spec: spec, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                self.cleanBenchRequests += 1
                guard let findings else { return }
                self.showCleanPanel(findings, rows: buffer.lineCount)
            }
        }
    }

    private func showCleanPanel(_ findings: [CSVCleanFinding], rows: Int) {
        cleanPanel.present(findings, rowsScanned: rows, partial: false)
        attachCleanPanel()
        cleanHeight.constant = panelOpenHeight(.clean)
        cleanPanel.isHidden = false
        // Cùng lý do với `csvTable.onStatus`: đây là tin của Bàn làm sạch, không phải kết quả
        // tìm kiếm. Và chính bảng làm sạch đã hiện con số ấy ngay trên đầu nó rồi.
        showTransient(findings.isEmpty
            ? L("Không phát hiện gì cần làm sạch")
            : LF("Bàn làm sạch: %d nhóm phát hiện", findings.count))
    }

    private func hideCleanPanel() {
        cleanToken?.cancel()
        profileToken?.cancel()
        cleanHeight?.constant = 0
        cleanPanel.isHidden = true
        csvTable.typeIssues = [:]
    }

    /// Đưa màn hình tới ô đầu tiên của một phát hiện.
    private func revealFinding(_ finding: CSVCleanFinding) {
        guard let cell = finding.sampleCells.first else { return }
        if isTableViewVisible {
            csvTable.select(fileRow: cell.rowIndex)
        } else {
            editorView.repaginate(around: cell.offset)
            editorView.setCaret(documentOffset: cell.offset)
            editorView.reveal(documentOffset: cell.offset)
            updateCaretStatus()
        }
        // Tô đỏ những ô của phát hiện này trên bảng: danh mục nói "42 ô", còn màu nói "chỗ này
        // đây" khi người dùng đã tới đúng hàng.
        var byRow: [Int: Set<Int>] = [:]
        for sample in finding.sampleCells { byRow[sample.rowIndex, default: []].insert(sample.column) }
        csvTable.typeIssues = byRow
    }

    private func showCleanSheet(for finding: CSVCleanFinding) {
        guard let window else { return }
        let sheet = CSVCleanSheet(
            finding: finding, buffer: editorDocument.buffer, dialect: csvDialect, spec: nullSpec
        )
        sheet.onApply = { [weak self] step in self?.runCleanStep(step, for: finding) }
        cleanSheet = sheet

        let sheetWindow = NSWindow(contentViewController: sheet)
        sheetWindow.styleMask = [.titled]
        window.beginSheet(sheetWindow)
    }

    /// Chạy một bước làm sạch trên CẢ tài liệu và áp thành MỘT bước undo (NFR-CLN-02b).
    ///
    /// Dựng kế hoạch ở luồng nền, áp ở luồng chính. Kế hoạch là dữ liệu thuần nên đi qua được;
    /// buffer thì chỉ luồng chính mới đụng vào.
    private func runCleanStep(_ step: CSVCleanStep, for finding: CSVCleanFinding) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        let spec = nullSpec
        let label = step.displayName(columnName: finding.columnName)

        cleanToken?.cancel()
        let token = CancelToken()
        cleanToken = token
        findPanel.showStatus("Đang \(label.lowercased())…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = try? step.run(
                in: buffer, dialect: dialect, spec: spec, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled, let outcome else { return }
                self.apply(outcome.edits, label: label)
                self.cleanPanel.recordApplied(
                    step, columnName: finding.columnName, summary: outcome.summary
                )
                // Quét lại: sau khi sửa, danh mục cũ nói về một file không còn tồn tại. Để
                // nguyên nó là mời người dùng bấm vào những con số đã sai.
                self.findPanel.showStatus("\(label) — \(outcome.summary)")
                self.rescanForCleaning()
                // Vòng khép kín FR-DQR-006: bảng chất lượng đang mở thì chấm lại NGAY, không
                // đợi người dùng bấm lại. Chu trình detect → clean → verify chỉ khép khi vế
                // verify tự chạy — bắt bấm lại là để người ta quên bấm.
                if let rules = self.qualityRules, let score = self.rescoreAfterFix(rules) {
                    self.showTransient(String(
                        format: L("Đã chấm lại: %.0f/100"), score.total ?? 0))
                }
            }
        }
    }

    /// Quét lại danh mục sau khi vừa sửa, giữ nguyên nhật ký đã áp.
    private func rescanForCleaning() {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        let spec = nullSpec
        let token = CancelToken()
        cleanToken = token

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let findings = try? CSVCleanScanner.scan(
                in: buffer, dialect: dialect, spec: spec, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled, let findings else { return }
                self.cleanPanel.present(findings, rowsScanned: buffer.lineCount, partial: false)
            }
        }
    }

    // MARK: - Công thức làm sạch (FR-CLN-005)

    /// Gom các bước đã áp trong phiên này thành một công thức và ghi ra JSON.
    ///
    /// Cột ghi theo TÊN, không theo số thứ tự: công thức sinh ra để chạy trên file KHÁC, và
    /// file tháng sau rất hay thêm bớt cột. Chi tiết ở `CSVRecipeRunner.resolve`.
    private func saveRecipe() {
        let steps = cleanPanel.applied.map {
            CSVRecipeStep(
                columnName: $0.columnName, columnIndex: $0.step.column, kind: $0.step.kind
            )
        }
        guard !steps.isEmpty else {
            return findPanel.showStatus("Chưa áp bước nào để lưu thành công thức", isError: true)
        }

        let sourceName = editorDocument.path.map { ($0 as NSString).lastPathComponent }
        let base = sourceName.map { ($0 as NSString).deletingPathExtension } ?? "lam_sach"

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(base)-cong-thuc.json"
        panel.allowedContentTypes = [.json]
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }

        let name = (url.lastPathComponent as NSString).deletingPathExtension
        let recipe = CSVRecipe(name: name, sourceFile: sourceName, steps: steps)
        do {
            // Qua `AtomicFileWriter` như mọi đường ghi khác (NFR-REL-02).
            try AtomicFileWriter.write(Array(try recipe.jsonData()), to: url.path)
            findPanel.showStatus("Đã lưu công thức \(url.lastPathComponent) — \(steps.count) bước")
        } catch {
            presentError("Không ghi được công thức", error)
        }
    }

    /// Mở một công thức và cho xem TRƯỚC khi chạy (FR-CLN-005).
    @objc func runCleaningRecipe(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }

        do {
            let recipe = try CSVRecipe.load(from: try Data(contentsOf: url))
            presentRecipeSheet(recipe)
        } catch let error as CSVRecipe.LoadError {
            // Nói RÕ vì sao, nhất là khi file đến từ bản mới hơn: "không đọc được" khiến người
            // dùng đi sửa file, còn "ghi bằng schema v2" khiến họ đi cập nhật ứng dụng.
            findPanel.showStatus(error.message, isError: true)
        } catch {
            presentError("Không đọc được công thức", error)
        }
    }

    private func presentRecipeSheet(_ recipe: CSVRecipe) {
        guard let window else { return }
        let names = CSVRecipeRunner.headerNames(
            in: editorDocument.buffer, dialect: csvDialect, hasHeader: true
        )
        let sheet = CSVRecipeSheet(recipe: recipe, columnNames: names)
        sheet.onRun = { [weak self] chosen in self?.applyRecipe(chosen) }
        sheet.onRunFolder = { [weak self] chosen in self?.runRecipeOnFolder(chosen) }
        recipeSheet = sheet

        let sheetWindow = NSWindow(contentViewController: sheet)
        sheetWindow.styleMask = [.titled]
        window.beginSheet(sheetWindow)
    }

    /// Chạy công thức trên tài liệu đang mở và mở báo cáo thành tab mới.
    private func applyRecipe(_ recipe: CSVRecipe) {
        let fileName = editorDocument.path.map { ($0 as NSString).lastPathComponent }
            ?? "Chưa đặt tên"
        do {
            let run = try CSVRecipeRunner.run(
                recipe, on: editorDocument.buffer, dialect: csvDialect,
                fileName: fileName, spec: nullSpec
            )
            editorDocument.refreshEOLReport()
            syncViewFromBuffer()
            refreshChrome()

            lastRecipeRun = run
            findPanel.showStatus(
                run.hasProblems
                    ? "Công thức «\(recipe.name)»: \(run.appliedCount) bước chạy, \(run.skippedCount) bỏ qua — xem báo cáo"
                    : "Công thức «\(recipe.name)»: \(run.appliedCount) bước đã chạy",
                isError: run.hasProblems
            )
            openRecipeReport(run)
        } catch {
            presentError("Không chạy được công thức", error)
        }
    }

    /// Chạy công thức trên cả một thư mục (FR-CLN-005).
    ///
    /// Đường này KHÔNG ghi đè — kết quả ra «tên-sach.csv» cạnh file gốc. Từ giao diện, người
    /// dùng chỉ vào một thư mục bằng hai cú bấm mà không thấy bên trong có bao nhiêu file; ghi
    /// đè ở đây là đánh cược dữ liệu của họ vào một hộp thoại chọn thư mục. Ai cần ghi đè thì
    /// có `geditor --recipe … --overwrite`, nơi phải gõ ra chữ ấy.
    private func runRecipeOnFolder(_ recipe: CSVRecipe) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Chạy"
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }

        let files = CSVRecipeBatch.csvFiles(in: url.path)
        guard !files.isEmpty else {
            return findPanel.showStatus(
                "Thư mục \(url.lastPathComponent) không có file CSV nào", isError: true
            )
        }

        let token = CancelToken()
        recipeToken?.cancel()
        recipeToken = token
        findPanel.showStatus("Đang chạy công thức trên \(files.count) file…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = CSVRecipeBatch.run(
                recipe, files: files, cancelToken: token
            ) { index, path in
                DispatchQueue.main.async {
                    self?.findPanel.showStatus(
                        "[\(index + 1)/\(files.count)] \((path as NSString).lastPathComponent)"
                    )
                }
                return true
            }
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                self.lastBatchResult = result
                self.openTextInNewTab(result.report, label: "Báo cáo công thức")
                self.findPanel.showStatus(
                    "\(result.succeededCount)/\(result.files.count) file xong"
                        + (result.failedCount > 0 ? " · \(result.failedCount) lỗi" : ""),
                    isError: result.failedCount > 0
                )
            }
        }
    }

    /// Báo cáo ra TAB MỚI, kể cả khi mọi bước đều trôi chảy.
    ///
    /// Vế (c) của NFR-CLN-02: chạy xong phải có báo cáo. Một công thức chạy im lặng trên dữ
    /// liệu người khác là đúng thứ mà bất biến ấy sinh ra để chặn.
    private func openRecipeReport(_ run: CSVRecipeRun) {
        openTextInNewTab(run.report, label: "Báo cáo công thức")
    }

    /// Mở một đoạn văn bản thành tab mới, chưa lưu.
    private func openTextInNewTab(_ text: String, label: String) {
        newTab(nil)
        editorDocument.buffer.applyEdits(
            [TextEdit(range: 0 ..< editorDocument.buffer.count, text: text)], label: label
        )
        syncViewFromBuffer()
        refreshChrome()
    }

    /// Dựng hồ sơ dữ liệu ở luồng nền (FR-CLN-003).
    ///
    /// Chỉ chạy khi người dùng mở sang tab Hồ sơ. Trên bảng một triệu hàng × 20 cột nó mất gần
    /// năm giây (`scripts/run-clean-kpi.sh`), và tiêu chừng ấy cho một câu hỏi chưa ai đặt là
    /// cách chắc chắn để Bàn làm sạch mang tiếng chậm.
    private func runProfile() {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        let spec = nullSpec
        guard buffer.count > 0 else { return }

        profileToken?.cancel()
        let token = CancelToken()
        profileToken = token
        findPanel.showStatus("Đang dựng hồ sơ dữ liệu…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let report = try? CSVProfiler.profile(
                in: buffer, dialect: dialect, spec: spec, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled, let report else { return }
                self.cleanPanel.present(profile: report)
                self.findPanel.showStatus(String(
                    format: "Hồ sơ dữ liệu: %d cột · %d hàng · %.1f s",
                    report.columns.count, report.rowsScanned, report.seconds
                ))
            }
        }
    }

    /// Đưa màn hình tới ô bất thường đầu tiên của một cột, và tô đỏ những ô còn lại.
    private func revealOutlier(_ entry: CSVColumnProfile) {
        guard let first = entry.outliers.first else { return }
        if isTableViewVisible {
            csvTable.select(fileRow: first.rowIndex)
        } else {
            editorView.repaginate(around: first.offset)
            editorView.setCaret(documentOffset: first.offset)
            editorView.reveal(documentOffset: first.offset)
            updateCaretStatus()
        }
        var byRow: [Int: Set<Int>] = [:]
        for cell in entry.outliers { byRow[cell.rowIndex, default: []].insert(cell.column) }
        csvTable.typeIssues = byRow
        findPanel.showStatus(
            "Cột «\(entry.name)»: \(entry.outliers.count) giá trị bất thường (|z| > 3)"
        )
    }

    /// Xuất báo cáo Markdown thành TAB MỚI (NFR-CLN-02c).
    ///
    /// Tab mới chứ không phải hộp thoại: báo cáo là thứ người ta lưu lại, dán vào email, hoặc
    /// đính kèm khi bàn giao dữ liệu — một hộp thoại bấm OK là xong thì không làm được gì cả.
    private func exportCleanReport() {
        let name = editorDocument.path.map { ($0 as NSString).lastPathComponent } ?? "Chưa đặt tên"
        let report = cleanPanel.makeReport(fileName: name)

        newTab(nil)
        editorDocument.buffer.applyEdits(
            [TextEdit(range: 0 ..< editorDocument.buffer.count, text: report)],
            label: L("Báo cáo làm sạch")
        )
        syncViewFromBuffer()
        refreshChrome()
        findPanel.showStatus("Đã tạo tab mới: báo cáo làm sạch (chưa lưu)")
    }

    // MARK: - Chuyển đổi định dạng (FR-CSV-406)

    /// Mở sheet chuyển đổi, có xem trước năm hàng đầu.
    @objc func showConvertSheet(_ sender: Any?) {
        guard let window, editorDocument.buffer.count > 0 else {
            return findPanel.showStatus("Tài liệu rỗng — không có gì để chuyển", isError: true)
        }
        let name = editorDocument.path
            .map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
            ?? "du_lieu"

        let sheet = CSVConvertSheet(
            buffer: editorDocument.buffer, dialect: csvDialect, tableName: name
        )
        sheet.onConvert = { [weak self] format, destination in
            self?.runConversion(format: format, destination: destination, tableName: name)
        }
        convertSheet = sheet

        let sheetWindow = NSWindow(contentViewController: sheet)
        sheetWindow.styleMask = [.titled]
        window.beginSheet(sheetWindow)
    }

    private func runConversion(
        format: CSVExport.Format, destination: CSVConvertSheet.Destination, tableName: String
    ) {
        let buffer = editorDocument.buffer
        let dialect = csvDialect
        findPanel.showStatus("Đang chuyển sang \(format.displayName)…")

        // Chuyển cả tài liệu ở luồng NỀN: một file lớn mất vài giây, và làm việc ấy trên luồng
        // chính là đứng hình ngay sau khi người dùng bấm nút.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = try? CSVExport.convert(
                buffer, dialect: dialect, to: format, tableName: tableName
            )
            DispatchQueue.main.async {
                guard let self, let result else {
                    return self?.findPanel.showStatus("Không chuyển đổi được", isError: true) ?? ()
                }
                switch destination {
                case .newTab: self.openConverted(result, format: format, name: tableName)
                case .file: self.saveConverted(result, format: format, name: tableName)
                }
            }
        }
    }

    /// Mở kết quả thành tab MỚI, chưa lưu — tài liệu gốc không đụng tới.
    private func openConverted(_ text: String, format: CSVExport.Format, name: String) {
        newTab(nil)
        editorDocument.buffer.applyEdits(
            [TextEdit(range: 0 ..< editorDocument.buffer.count, text: text)],
            label: "Chuyển sang \(format.displayName)"
        )
        syncViewFromBuffer()
        refreshChrome()
        findPanel.showStatus("Đã tạo tab mới: \(name).\(format.fileExtension) (chưa lưu)")
    }

    private func saveConverted(_ text: String, format: CSVExport.Format, name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(name).\(format.fileExtension)"
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }
        do {
            // Qua `AtomicFileWriter` như mọi đường ghi khác (NFR-REL-02).
            try AtomicFileWriter.write(Array(text.utf8), to: url.path)
            findPanel.showStatus("Đã ghi \(url.lastPathComponent)")
        } catch {
            presentError("Không ghi được file", error)
        }
    }

    /// Đổi dấu phân tách của chính tài liệu này (FR-CSV-406).
    @objc func changeCSVDelimiter(_ sender: Any?) {
        let options: [(String, CSVDialect)] = [
            ("Dấu phẩy  ,", .comma), ("Chấm phẩy  ;", .semicolon),
            ("Tab", .tab), ("Gạch đứng  |", .pipe),
        ]
        let menu = NSMenu()
        for (title, target) in options {
            let item = NSMenuItem(
                title: title, action: #selector(applyDelimiterChange(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = target.delimiter
            item.state = target.delimiter == csvDialect.delimiter ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 20, y: 20), in: editorView)
    }

    @objc private func applyDelimiterChange(_ sender: NSMenuItem) {
        guard let delimiter = sender.representedObject as? UInt8 else { return }
        let source = csvDialect
        guard delimiter != source.delimiter else { return }

        let buffer = editorDocument.buffer
        do {
            // Viết lại CẢ tài liệu thành MỘT `TextEdit`: đổi dấu phân tách chạm vào mọi hàng,
            // nên chia nhỏ chỉ làm lịch sử hoàn tác dài ra mà không cho thêm khả năng nào.
            let converted = try CSVExport.changeDialect(
                buffer, from: source, to: CSVDialect(delimiter: delimiter)
            )
            apply(
                [TextEdit(range: 0 ..< buffer.count, text: converted)],
                label: "Đổi dấu phân tách"
            )
            // Chế độ CSV đoán lại dialect từ nội dung mới, nên chỉ cần vẽ lại.
            rebuildCSVIndexAfterEdit()
            refreshChrome()
            findPanel.showStatus("Đã đổi sang dấu phân tách «\(csvDialect.displayName)»")
        } catch {
            presentError("Không đổi được dấu phân tách", error)
        }
    }

    @objc func exportCSVToJSON(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (editorDocument.path.map {
            ($0 as NSString).deletingPathExtension as NSString
        }?.lastPathComponent ?? "du-lieu") + ".json"
        guard Unattended.chooseFile(panel) == .OK, let url = panel.url else { return }

        do {
            let json = try CSVOps.toJSON(editorDocument.buffer, dialect: csvDialect)
            // Ghi qua AtomicFileWriter như mọi đường ghi khác (NFR-REL-02).
            try AtomicFileWriter.write(Array(json.utf8), to: url.path)
        } catch {
            presentError("Không xuất được JSON", error)
        }
    }

    private func askForText(
        title: String, message: String, placeholder: String, initial: String? = nil
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = placeholder
        // `initial` là giá trị ĐANG có, điền sẵn để sửa; `placeholder` chỉ là chữ mờ gợi ý.
        // Sửa một chữ trong nhãn mười từ mà không điền sẵn thì phải gõ lại cả mười.
        if let initial { field.stringValue = initial }
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Hủy")

        // Con trỏ phải nằm sẵn trong ô nhập. Không đặt thì hộp thoại mở ra với ô KHÔNG được
        // focus: người dùng gõ mà chẳng có gì hiện ra, bấm Enter là OK với chuỗi rỗng và thao
        // tác im lặng không làm gì. Mọi hộp thoại nhập liệu của app đều đi qua đây.
        alert.window.initialFirstResponder = field

        guard Unattended.ask(alert) == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }
}

// MARK: - Tìm trong thư mục (FR-SRCH-105, FR-SRCH-106)

extension MainWindowController {

    /// ⇧⌘F — chọn thư mục rồi tìm, chạy NGOÀI main thread.
    ///
    /// SAD §4.1 cấm main thread làm I/O. Tìm trong 10 000 file là hàng nghìn lần mở file; làm
    /// trên main thread thì con trỏ chuột đứng hình và nút Hủy không bấm được — đúng thứ
    /// TC-SRCH-06 kiểm (hủy phải đáp ứng ≤ 200 ms).
    @objc func findInFiles(_ sender: Any?) {
        let query = findPanel.query
        guard !query.pattern.isEmpty else {
            showFindPanel(nil)
            return findPanel.showStatus("Nhập chuỗi cần tìm trước", isError: true)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Tìm trong đây"
        panel.directoryURL = editorDocument.path.map {
            URL(fileURLWithPath: ($0 as NSString).deletingLastPathComponent)
        }
        guard Unattended.chooseFile(panel) == .OK, let root = panel.url else { return }

        guard let filters = askForText(
            title: "Lọc theo tên file",
            message: "Cách nhau bằng dấu chấm phẩy. Để trống = mọi file.",
            placeholder: "*.csv;*.log"
        ) else { return }

        startFindInFiles(root: root.path, query: query, filters: filters)
    }

    private func startFindInFiles(root: String, query: FindPanelView.Query, filters: String) {
        showResultsPanel()
        resultsView.showRunning("Đang tìm \"\(query.pattern)\" trong \(root)…")

        // Token giữ ở controller để nút Hủy chạm tới được.
        let token = CancelToken()
        searchToken = token

        let globs = filters
            .split(whereSeparator: { $0 == ";" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<FindInFiles.Summary, Error>
            do {
                result = .success(try FindInFiles.search(
                    root: root,
                    pattern: query.pattern,
                    searchOptions: query.options,
                    options: FindInFiles.Options(includeGlobs: globs),
                    cancelToken: token
                ))
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                guard self?.searchToken === token else { return }  // đã có lần tìm mới
                self?.searchToken = nil
                switch result {
                case .success(let summary):
                    self?.presentSearchResults(summary, pattern: query.pattern)
                case .failure(let error):
                    if error is OperationCancelled {
                        self?.resultsView.showMessage("Đã hủy")
                    } else {
                        self?.resultsView.showMessage("Tìm thất bại: \(error)", isError: true)
                    }
                }
            }
        }
    }

    private func showResultsPanel() {
        // Chiều cao đặt tường minh, KHÔNG để nội dung quyết định như thanh Tìm.
        //
        // Khác biệt: thanh Tìm chứa toàn điều khiển có kích thước nội tại, còn panel này chứa
        // một `NSScrollView` — mà scroll view thì KHÔNG có chiều cao nội tại (nó cuộn, nên
        // nội dung bao nhiêu cũng được). Để nội dung quyết định thì nó co về 0 và người dùng
        // chỉ thấy dòng tóm tắt, không thấy kết quả nào.
        attachResultsPanel()
        resultsHeight.constant = panelOpenHeight(.results)
        resultsView.isHidden = false
    }

    func hideResultsPanel() {
        resultsView.isHidden = true
        resultsHeight?.constant = 0
    }

    func cancelFindInFiles() {
        searchToken?.cancel()
        searchToken = nil
    }

    /// Mở file chứa kết quả và nhảy tới đúng vị trí.
    func openHit(path: String, hit: FindInFiles.Hit) {
        if editorDocument.path != path {
            guard confirmDiscardChanges() else { return }
            open(path: path)
        }

        // Cuộn TRƯỚC rồi mới chọn: `reveal` có thể phải nạp lại cửa sổ, mà chọn trên cửa sổ
        // cũ xong mới nạp lại là mất vùng chọn.
        editorView.reveal(documentOffset: hit.byteRange.lowerBound)
        editorView.setSelectedDocumentRange(hit.byteRange)
        updateCaretStatus()
    }
}

// MARK: - Thay trong thư mục (FR-SRCH-106, TC-SRCH-07)

extension MainWindowController {

    /// Luôn CHẠY THỬ trước, không bao giờ ghi thẳng.
    ///
    /// Thay trong thư mục sửa hàng trăm file cùng lúc và undo của tài liệu đang mở không với
    /// tới chúng. Bản xem trước là cơ hội duy nhất để người dùng nhận ra mình gõ nhầm pattern
    /// — nên nó bắt buộc, không phải tùy chọn.
    @objc func replaceInFiles(_ sender: Any?) {
        let query = findPanel.query
        guard !query.pattern.isEmpty else {
            showFindPanel(nil)
            return findPanel.showStatus("Nhập chuỗi cần tìm trước", isError: true)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Thay trong đây"
        panel.directoryURL = editorDocument.path.map {
            URL(fileURLWithPath: ($0 as NSString).deletingLastPathComponent)
        }
        guard Unattended.chooseFile(panel) == .OK, let root = panel.url else { return }

        guard let filters = askForText(
            title: "Lọc theo tên file",
            message: "Cách nhau bằng dấu chấm phẩy. Để trống = mọi file.",
            placeholder: "*.csv;*.log"
        ) else { return }

        runReplacementDryRun(root: root.path, query: query, filters: filters)
    }

    private func globs(from filters: String) -> [String] {
        filters
            .split(whereSeparator: { $0 == ";" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func runReplacementDryRun(root: String, query: FindPanelView.Query, filters: String) {
        showResultsPanel()
        resultsView.showRunning("Đang chạy thử trong \(root)…")

        let token = CancelToken()
        searchToken = token
        let options = FindInFiles.Options(includeGlobs: globs(from: filters))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome: Result<[FindInFiles.FileReplacement], Error>
            do {
                let pattern = try PCRE2Pattern(pattern: query.pattern, options: query.options)
                let files = FindInFiles.collectFiles(root: root, options: options)
                outcome = .success(try FindInFiles.replace(
                    files: files, pattern: pattern, template: query.replacement,
                    options: options, dryRun: true, cancelToken: token
                ))
            } catch {
                outcome = .failure(error)
            }

            DispatchQueue.main.async {
                guard self?.searchToken === token else { return }
                self?.searchToken = nil
                switch outcome {
                case .success(let plans) where plans.isEmpty:
                    self?.resultsView.showMessage("Không có file nào khớp")
                case .success(let plans):
                    self?.pendingReplacement = (root, query, filters)
                    self?.resultsView.showReplacementPreview(
                        plans, pattern: query.pattern, template: query.replacement
                    )
                case .failure(let error):
                    self?.resultsView.showMessage("Chạy thử thất bại: \(error)", isError: true)
                }
            }
        }
    }

    /// Ghi thật, CHỈ vào những file người dùng còn để chọn (TC-SRCH-07).
    func commitReplacement(selectedPaths: [String]) {
        guard let (root, query, filters) = pendingReplacement else { return }
        guard !selectedPaths.isEmpty else {
            return resultsView.showMessage("Không còn file nào được chọn")
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Ghi vào \(selectedPaths.count) file?"
        alert.informativeText = "Thao tác này KHÔNG hoàn tác được từ trong ứng dụng. "
            + "Mỗi file được ghi nguyên tử nên không có file nào hỏng dở."
        alert.addButton(withTitle: "Hủy")
        alert.addButton(withTitle: "Ghi")
        guard Unattended.ask(alert) == .alertSecondButtonReturn else { return }

        resultsView.showRunning("Đang ghi \(selectedPaths.count) file…")
        let token = CancelToken()
        searchToken = token
        let options = FindInFiles.Options(includeGlobs: globs(from: filters))
        _ = root

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome: Result<[FindInFiles.FileReplacement], Error>
            do {
                let pattern = try PCRE2Pattern(pattern: query.pattern, options: query.options)
                outcome = .success(try FindInFiles.replace(
                    files: selectedPaths, pattern: pattern, template: query.replacement,
                    options: options, dryRun: false, cancelToken: token
                ))
            } catch {
                outcome = .failure(error)
            }

            DispatchQueue.main.async {
                guard self?.searchToken === token else { return }
                self?.searchToken = nil
                self?.pendingReplacement = nil
                switch outcome {
                case .success(let done):
                    let total = done.reduce(0) { $0 + $1.matchCount }
                    self?.resultsView.showMessage("Đã thay \(total) kết quả trong \(done.count) file")
                    // File đang mở có thể vừa bị ghi đè — kiểm và báo cho người dùng.
                    self?.warnIfCurrentDocumentChangedOnDisk()
                case .failure(let error):
                    self?.resultsView.showMessage("Ghi thất bại: \(error)", isError: true)
                }
            }
        }
    }

    private func warnIfCurrentDocumentChangedOnDisk() {
        guard editorDocument.externalChange() == .modified else { return }
        if editorDocument.isModified {
            showBannerPublic(
                "File đang mở vừa bị thay trên đĩa, nhưng bản trong cửa sổ có thay đổi chưa lưu.",
                actionTitle: nil, action: nil
            )
        } else {
            do {
                try editorDocument.revert()
                syncViewFromBuffer()
                refreshChrome()
                showBannerPublic("Đã nạp lại file sau khi thay.", actionTitle: nil, action: nil)
            } catch {
                presentError("Không nạp lại được file", error)
            }
        }
    }
}

// MARK: - Sidebar (FR-DOC-307/308)

extension MainWindowController: NSWindowDelegate {

    /// Cửa sổ đóng — báo cho `WindowManager` gỡ khỏi sổ đăng ký (FR-DOC-302).
    ///
    /// Ghi phiên TRƯỚC khi báo: lúc này tab của cửa sổ này còn nguyên, và phiên phải phản ánh
    /// trạng thái ngay trước khi đóng chứ không phải trạng thái sau khi đã mất.
    func windowWillClose(_ notification: Notification) {
        autosaveTimer?.invalidate()
        // MỌI tab, không riêng tab đang mở: từ khi bộ theo dõi thuộc về tab, một cửa sổ có thể
        // đang theo dõi vài file cùng lúc.
        for tab in tabs { tab.tailWatcher?.stop() }
        onWindowClosed?()
    }

    /// Cửa sổ đổi cỡ — tính lại chiều cao những panel đang mở.
    ///
    /// Không có hàm này thì tỉ lệ chỉ đúng tại ĐÚNG khoảnh khắc mở panel, và cái tên "cao theo
    /// cửa sổ" thành nói quá: mở panel trên cửa sổ 720 pt được 230, phóng lên 1440 thì nó vẫn
    /// đứng ở 230 — đúng thứ hằng số cứng ngày trước làm, chỉ khác con số.
    func windowDidResize(_ notification: Notification) {
        reflowPanelHeights()
    }
}

extension MainWindowController: NSSplitViewDelegate {

    /// Không nửa nào được bóp nhỏ hơn mức còn đọc được.
    ///
    /// Kéo hết cỡ để một nửa biến mất thì người dùng tưởng tính năng hỏng — và không có cách
    /// nào rõ ràng để lấy lại ngoài việc đóng mở sidebar.
    func splitView(
        _ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        max(proposedMinimumPosition, 120)
    }

    func splitView(
        _ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        min(proposedMaximumPosition, splitView.bounds.height - 120)
    }
}

/// Cửa sổ trợ giúp đọc và ghi đúng hai khoá cấu hình, không nhìn thấy phần còn lại.
///
/// Truyền cả `MainWindowController` vào cửa sổ trợ giúp thì nó chạm được tới tài liệu, tới phiên,
/// tới mọi panel — và một cửa sổ chỉ để đọc chữ thì không nên có ngần ấy tầm với.
extension MainWindowController: HelpWelcomeSettings {

    func showWelcomeOnLaunch() -> Bool { settings.showWelcomeOnLaunch }

    func setShowWelcomeOnLaunch(_ value: Bool) {
        guard settings.showWelcomeOnLaunch != value else { return }
        settings.showWelcomeOnLaunch = value
        // `saveSettings()` chứ không phải `applySettings(_:persist:)`: khoá này không đổi font,
        // theme hay phím tắt, nên dựng lại toàn bộ chrome chỉ để ghi một dấu tích là một nháy
        // hình không ai xin.
        saveSettings()
    }
}


/// Nguồn dữ liệu cho sidebar EIDE — 21 màn của UXD-13 §2.
///
/// Tách khỏi `MainWindowController` vì lớp ấy đã là delegate của hàng chục thứ; thêm hai
/// protocol bảng vào đó buộc mọi bảng khác trong cửa sổ phải tự phân biệt bằng `===`, và cái
/// quên phân biệt là cái hiện nhầm nội dung.
final class NguonSidebarEide: NSObject, NSTableViewDataSource, NSTableViewDelegate {

    private let khiChon: (Int) -> Void

    init(khiChon: @escaping (Int) -> Void) {
        self.khiChon = khiChon
        super.init()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        EideWindowController.manTrenSidebar.count
    }

    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let m = EideWindowController.manTrenSidebar[row]
        let l = NSTextField(labelWithString: "\(row + 1). \(m.nhan)")
        l.font = NSFont.systemFont(ofSize: 12)
        l.setAccessibilityLabel("Màn \(m.nhan)")
        let hop = NSTableCellView()
        hop.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 10),
            l.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            l.trailingAnchor.constraint(lessThanOrEqualTo: hop.trailingAnchor, constant: -4),
        ])
        return hop
    }

    func tableViewSelectionDidChange(_ n: Notification) {
        guard let tv = n.object as? NSTableView else { return }
        khiChon(tv.selectedRow)
    }
}
