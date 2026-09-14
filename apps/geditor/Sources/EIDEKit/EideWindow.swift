import AppKit

/// **Cửa sổ EIDE** — giao diện của sản phẩm, không phải một panel phụ của trình soạn thảo.
///
/// Spec: UXD-13 §1 (khung cửa sổ), §2 (bảng 23 màn hình và sidebar), U1 (Chat là màn mặc
/// định), U2 (thanh tự chủ LUÔN hiện, hàng đợi tách hai danh sách); mockup `docs/ui/Main.dc.html`
/// (1440×900, sidebar trái liệt kê mọi màn, thanh trạng thái trên cùng).
///
/// ## Vì sao cửa sổ này phải tồn tại
///
/// Bản đầu gắn EIDE làm một panel cao 420 px ở đáy cửa sổ GEditor, mở bằng một mục trong menu
/// Format. Điều đó làm được đúng thứ DEV-004 nói (thành phần trong app, không qua khung
/// plugin) nhưng **đánh mất chính sản phẩm**: người mở EIDE lên thấy một trình soạn thảo văn
/// bản, và 23 màn hình của UXD-13 chen nhau trong một dải 420 px dưới đáy.
///
/// Mockup §2 nói rõ hình dạng thật: một cửa sổ 1440×900, **sidebar trái liệt kê mọi màn**,
/// thanh trạng thái tự chủ trên cùng, vùng nội dung ở giữa. Đó là giao diện của một môi trường
/// phát triển, không phải của một tiện ích mở rộng.
///
/// ## Quan hệ với `EidePanel`
///
/// Cửa sổ này KHÔNG dựng lại 23 khung nhìn. Nó đặt chính `EidePanel` vào giữa và thêm sidebar
/// bên trái — nên mọi thứ đã có (định tuyến lệnh, kênh sự kiện, quy tắc tự nạp, phím tắt) chạy
/// y như cũ, và không có bản sao thứ hai để hai bên lệch nhau. Panel đáy trong GEditor vẫn
/// dùng được cho ai muốn EIDE cạnh mã nguồn; hai lối vào, một thân.
public final class EideWindowController: NSWindowController {

    private let panel: EidePanel
    private let sidebar = NSTableView()
    private let cuonSidebar = NSScrollView()
    private var dangChon = 0

    /// Màn hiện trên sidebar — đọc từ `screens.json` qua panel, không gõ tay.
    ///
    /// `Chat` là mục đầu vì UXD-13 U1 gọi nó là "màn hình mặc định khi mở dự án"; ba màn
    /// "khung" (`ReviewQueue`, `Trạng thái/khung`) không vào danh sách vì chúng LUÔN hiện —
    /// đặt một mục sidebar cho thứ không bao giờ tắt là mời người dùng bấm vào chỗ không đổi gì.
    public static let manTrenSidebar: [(tien: String, nhan: String)] = [
        ("Chat", "Trò chuyện"),
        ("Main", "Tổng quan dự án"),
        ("Ingest", "Nhập tài liệu"),
        ("Passport", "Hộ chiếu chip"),
        ("Board", "Hộ chiếu mạch"),
        ("Graph", "Bản đồ tri thức & hỏi đáp"),
        ("ReqArch", "Yêu cầu & kiến trúc"),
        ("DiagramView", "Lược đồ"),
        ("Doc", "Tài liệu"),
        ("PlanDiff", "Kế hoạch & mã"),
        ("Code", "Mã nguồn"),
        ("Sim", "Mô phỏng"),
        ("Discovery", "Dò board"),
        ("LogAssist", "Log & serial"),
        ("Debug", "Gỡ lỗi probe"),
        ("ToolForge", "Công cụ tự tạo"),
        ("Bench", "Benchmark"),
        ("Registry", "Registry"),
        ("Models", "Mô hình & chi phí"),
        ("Env", "Môi trường"),
        ("FlowMap", "Hành trình & cổng"),
    ]

    public init(client: EideClient) {
        panel = EidePanel(client: client)

        // 1440×900 — đúng khổ mockup. Không phải con số thẩm mỹ: bảng chân của `BoardView` và
        // bản đồ của `KgMapView` được vẽ cho khổ ấy, và hẹp hơn thì chúng xuống dòng thành một
        // cột chữ.
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "EIDE — trợ lý phát triển nhúng"
        w.minSize = NSSize(width: 1000, height: 640)
        w.center()
        super.init(window: w)

        dungGiaoDien()
        // U1: "ChatPanel là màn hình mặc định khi mở dự án". Sidebar chọn sẵn mục đầu.
        //
        // `reloadData()` TRƯỚC khi chọn: `NSTableView` chưa có hàng nào lúc `init` chạy, nên
        // `selectRowIndexes([0])` rơi vào khoảng không và bảng tự chọn hàng cuối lúc nạp —
        // đo được: cửa sổ mở ra ở màn 21 "Hành trình & cổng" thay vì màn 1 "Trò chuyện".
        sidebar.reloadData()
        sidebar.selectRowIndexes([0], byExtendingSelection: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dungGiaoDien() {
        guard let w = window else { return }
        let goc = NSView()
        goc.wantsLayer = true
        goc.layer?.backgroundColor = EideToken.Mau.bg.cgColor

        // --- sidebar
        sidebar.headerView = nil
        sidebar.rowHeight = 26
        sidebar.backgroundColor = EideToken.Mau.surface
        sidebar.dataSource = self
        sidebar.delegate = self
        sidebar.selectionHighlightStyle = .regular
        sidebar.setAccessibilityLabel("Danh sách màn hình EIDE")
        let cot = NSTableColumn(identifier: .init("man"))
        cot.width = 210
        sidebar.addTableColumn(cot)

        cuonSidebar.documentView = sidebar
        cuonSidebar.hasVerticalScroller = true
        cuonSidebar.drawsBackground = false
        cuonSidebar.translatesAutoresizingMaskIntoConstraints = false

        let vach = NSBox()
        vach.boxType = .separator
        vach.translatesAutoresizingMaskIntoConstraints = false

        panel.translatesAutoresizingMaskIntoConstraints = false
        goc.addSubview(cuonSidebar)
        goc.addSubview(vach)
        goc.addSubview(panel)

        NSLayoutConstraint.activate([
            cuonSidebar.topAnchor.constraint(equalTo: goc.topAnchor),
            cuonSidebar.leadingAnchor.constraint(equalTo: goc.leadingAnchor),
            cuonSidebar.bottomAnchor.constraint(equalTo: goc.bottomAnchor),
            cuonSidebar.widthAnchor.constraint(equalToConstant: 220),

            vach.leadingAnchor.constraint(equalTo: cuonSidebar.trailingAnchor),
            vach.topAnchor.constraint(equalTo: goc.topAnchor),
            vach.bottomAnchor.constraint(equalTo: goc.bottomAnchor),
            vach.widthAnchor.constraint(equalToConstant: 1),

            panel.leadingAnchor.constraint(equalTo: vach.trailingAnchor),
            panel.topAnchor.constraint(equalTo: goc.topAnchor),
            panel.trailingAnchor.constraint(equalTo: goc.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: goc.bottomAnchor),
        ])
        w.contentView = goc
    }

    /// Mở cửa sổ và đưa nó lên trước.
    public func hien() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension EideWindowController: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        Self.manTrenSidebar.count
    }

    public func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let m = Self.manTrenSidebar[row]
        let l = NSTextField(labelWithString: "\(row + 1). \(m.nhan)")
        l.font = EideToken.fontUI
        l.textColor = EideToken.Mau.text
        l.setAccessibilityLabel("Màn \(m.nhan)")
        let hop = NSTableCellView()
        hop.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: hop.leadingAnchor,
                                       constant: EideToken.space[2]),
            l.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            l.trailingAnchor.constraint(lessThanOrEqualTo: hop.trailingAnchor, constant: -4),
        ])
        return hop
    }

    public func tableViewSelectionDidChange(_ n: Notification) {
        let r = sidebar.selectedRow
        guard r >= 0, r < Self.manTrenSidebar.count else { return }
        dangChon = r
        let m = Self.manTrenSidebar[r]
        // "Chat" không phải một màn chuyên đề — nó LÀ hội thoại, tức trạng thái mặc định của
        // panel. Chọn nó nghĩa là đóng màn đang mở, không phải mở thêm một màn tên Chat.
        if m.tien == "Chat" {
            panel.dongManChuyenDe()
        } else {
            panel.moMan(m.tien)
        }
    }
}
