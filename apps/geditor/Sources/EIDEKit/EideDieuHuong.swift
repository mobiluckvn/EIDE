import AppKit

/// **Điều hướng bên trái** — 21 màn gộp 5 nhóm theo giai đoạn công việc.
///
/// THIET-KE-UI sheet 2, chủ sản phẩm duyệt 14/09/2026.
///
/// ## Vì sao gộp nhóm
///
/// Bản cũ liệt kê 22 mục phẳng theo đúng thứ tự bảng UXD-13 §2. Thứ tự ấy là thứ tự TÀI LIỆU,
/// không phải thứ tự làm việc: "Dò board" đứng giữa "Mô phỏng" và "Log & serial", còn "Nhật ký
/// hoạt động" ở cuối cùng. Người mới mở sản phẩm không biết bắt đầu từ đâu, và người quen thì
/// phải đếm để tìm đúng mục.
///
/// Năm nhóm là năm giai đoạn: **thu tri thức → thiết kế → viết mã và chạy → chạm phần cứng →
/// xem hệ thống**. Đúng thứ tự một dự án đi qua, và đúng thứ tự hai luồng thật (ESP32-C3, AVR)
/// đã chạy.
///
/// ## Màn cần board vẫn hiện
///
/// Chủ sản phẩm chốt: *"vẫn hiện, nói rõ cần gì"*. Lý do là EIDE dùng cho **nhiều board**, nên
/// "chưa cắm board" là một trạng thái đổi được trong vài giây, không phải một cấu hình. Ẩn đi
/// thì người dùng không biết sản phẩm làm được gì; làm xám thì trông như hỏng. Hiện bình thường
/// và nói rõ khi mở ra là cách duy nhất vừa trung thực vừa không giấu tính năng.
public final class EideDieuHuong: NSView {

    /// Một dòng trong danh sách: tiêu đề nhóm, hoặc một màn.
    public enum Muc: Equatable {
        case nhom(String)
        case man(tien: String, nhan: String, canBoard: Bool)
    }

    /// Người chọn một màn.
    public var onChon: ((String) -> Void)?

    private let bang = NSTableView()
    private let cuon = NSScrollView()
    private var muc: [Muc] = []
    /// **Sáu nhóm, hai mươi lăm màn** — đúng bản demo UX v2.0 và UXC-31 §8.
    ///
    /// Nhóm theo CÂU HỎI người dùng tự hỏi trong vòng đời công việc, không theo namespace năng
    /// lực. Bản trước nhóm theo giai đoạn kỹ thuật (TRI THỨC / THIẾT KẾ / MÃ & CHẠY / PHẦN CỨNG
    /// / HỆ THỐNG) — đúng với cách người viết mã nghĩ, và lệch với cách người DÙNG nghĩ: họ tìm
    /// "dự án tôi thế nào" chứ không tìm "tầng tri thức".
    ///
    /// Hai chỗ đổi vai đáng ghi. `PlanDiff` TÁCH ĐÔI: kế hoạch thuộc câu hỏi "làm cái gì" (nhóm
    /// Thiết kế), còn diff và bốn cổng thuộc câu hỏi "merge được chưa" (nhóm Mã nguồn) — hai lối
    /// vào, MỘT nguồn dữ liệu. Và `Env` rời nhóm chạy thử sang nhóm Hệ thống: công cụ trên máy
    /// là chuyện hạ tầng, không phải chuyện của một lượt chạy thử.
    ///
    /// Nguồn duy nhất — mọi nơi khác đọc từ đây thay vì giữ một bản sao thứ hai.
    public static let NHOM: [(ten: String, man: [(tien: String, nhan: String, board: Bool)])] = [
        ("DỰ ÁN", [
            ("Main", "Tổng quan", false),
            ("NhatKy", "Nhật ký", false),
            ("FlowMap", "Bản đồ luồng", false),
        ]),
        ("TRI THỨC", [
            ("Ingest", "Nhập tài liệu", false),
            ("Passport", "Hộ chiếu chip", false),
            ("Board", "Hộ chiếu mạch", false),
            ("Graph", "Bản đồ tri thức & hỏi đáp", false),
            ("XungDot", "Xung đột tri thức", false),
        ]),
        ("THIẾT KẾ", [
            ("LamRo", "Làm rõ yêu cầu", false),
            ("ReqArch", "Yêu cầu & kiến trúc", false),
            ("DiagramView", "Lược đồ", false),
            ("PlanDiff", "Kế hoạch", false),
            ("Doc", "Tài liệu", false),
        ]),
        ("MÃ NGUỒN", [
            ("Code", "Trình soạn thảo", false),
            ("DiffMerge", "Diff & cổng merge", false),
        ]),
        ("CHẠY THỬ", [
            ("Sim", "Mô phỏng", false),
            ("Discovery", "Dò board", true),
            ("LogAssist", "Log & serial", true),
            ("Debug", "Gỡ lỗi probe", true),
            ("Bench", "Bench", true),
        ]),
        ("HỆ THỐNG", [
            ("Env", "Môi trường", false),
            ("Models", "Mô hình & chi phí", false),
            ("ToolForge", "Công cụ tự tạo", false),
            ("Registry", "Registry", false),
            ("ChinhSach", "Chính sách tự chủ", false),
        ]),
    ]

    /// Câu nói cho màn cần board — hiện khi mở màn ấy mà chưa có thiết bị nào.
    ///
    /// Nói VIỆC CẦN LÀM, không nói tình trạng: "chưa có board" là điều người dùng đã biết, còn
    /// "cắm board qua USB rồi bấm Dò lại" là điều họ cần.
    public static func loiCanBoard(_ tien: String) -> String {
        switch tien {
        case "Discovery":
            return "Cắm board qua USB rồi bấm \"Dò lại\" — EIDE đọc cổng, VID/PID và quyền truy cập."
        case "Debug":
            return "Màn này nạp firmware và gỡ lỗi qua probe. Cắm board và probe (ST-Link, "
                 + "J-Link, CMSIS-DAP hoặc bootloader Arduino) rồi dò lại."
        case "LogAssist":
            return "Cắm board rồi chọn cổng serial để xem log thời gian thực."
        case "Bench":
            return "Benchmark đo trên board thật (CF/BF/BC theo BEN-24). Cắm board lab rồi chạy lại."
        default:
            return "Màn này cần một board đang cắm."
        }
    }

    public override init(frame: NSRect) {
        super.init(frame: frame)
        dung()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung() {
        muc = Self.NHOM.flatMap { n in
            [Muc.nhom(n.ten)] + n.man.map { Muc.man(tien: $0.tien, nhan: $0.nhan, canBoard: $0.board) }
        }
        bang.headerView = nil
        bang.rowHeight = 24
        bang.backgroundColor = EideToken.Mau.surface
        bang.dataSource = self
        bang.delegate = self
        bang.selectionHighlightStyle = .regular
        bang.setAccessibilityLabel("Điều hướng màn hình EIDE")
        let cot = NSTableColumn(identifier: .init("man"))
        cot.width = 200
        bang.addTableColumn(cot)

        cuon.documentView = bang
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        bang.reloadData()
    }

    /// Chọn màn theo tiền tố. Trả về false nếu không có màn ấy.
    @discardableResult
    @MainActor
    public func chon(_ tien: String) -> Bool {
        guard let i = muc.firstIndex(where: {
            if case let .man(t, _, _) = $0 { return t == tien }
            return false
        }) else { return false }
        bang.selectRowIndexes([i], byExtendingSelection: false)
        bang.scrollRowToVisible(i)
        return true
    }

    /// Số màn (không tính tiêu đề nhóm) — để test đối chiếu với bảng màn của panel.
    public var soMan: Int {
        muc.filter { if case .man = $0 { return true }; return false }.count
    }
}

extension EideDieuHuong: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int { muc.count }

    /// Tiêu đề nhóm KHÔNG chọn được. Bấm vào nó mà thấy vùng nội dung đổi là một lời hứa sai.
    public func tableView(_ tv: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .nhom = muc[row] { return false }
        return true
    }

    public func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let hop = NSTableCellView()
        let l = NSTextField(labelWithString: "")
        l.font = EideToken.fontUI
        switch muc[row] {
        case let .nhom(ten):
            l.stringValue = ten
            l.font = NSFont.boldSystemFont(ofSize: 10)
            l.textColor = EideToken.Mau.muted
        case let .man(_, nhan, canBoard):
            // Màn cần board hiện BÌNH THƯỜNG — không xám, không dấu khoá. Dấu hiệu duy nhất là
            // một chấm nhỏ, và câu giải thích đợi tới lúc người dùng thật sự mở màn ra.
            l.stringValue = (canBoard ? "  ○ " : "  ") + nhan
            l.textColor = EideToken.Mau.text
            l.toolTip = canBoard ? "Cần một board đang cắm" : nil
        }
        l.setAccessibilityLabel(l.stringValue.trimmingCharacters(in: .whitespaces))
        hop.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: EideToken.space[1]),
            l.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            l.trailingAnchor.constraint(lessThanOrEqualTo: hop.trailingAnchor, constant: -4),
        ])
        return hop
    }

    public func tableViewSelectionDidChange(_ n: Notification) {
        let r = bang.selectedRow
        guard r >= 0, r < muc.count, case let .man(tien, _, _) = muc[r] else { return }
        onChon?(tien)
    }
}
