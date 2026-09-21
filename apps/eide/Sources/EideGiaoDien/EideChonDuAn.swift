import AppKit
import EideLoi

/// **Bộ chuyển dự án** — popover của UXC-31 §2A.2.
///
/// Ba phần, đúng như §2A.2: ô lọc, danh sách `project.list`, nút "Dự án mới".
///
/// Popover chứ không menu: một `NSMenu` không chứa được ô nhập, và §2A.2 đòi ô lọc vì workspace
/// của một người làm nhúng lâu năm có hàng chục dự án tên gần giống nhau (`blink`, `blink-f4`,
/// `blink-f4-cu`). Không lọc được thì bộ chuyển thành một danh sách phải đọc từ đầu mỗi lần.
@MainActor
public final class EideChonDuAn: NSViewController {

    /// Một dự án trong workspace — các khoá `project.list` hứa trả (PROJECT-03).
    public struct DuAn {
        public let id: String
        public let duong: String
        public let board: String?
        public let dat: Int?
        public let tong: Int?
        public let mucTuChu: String?

        public init(id: String, duong: String, board: String? = nil,
                    dat: Int? = nil, tong: Int? = nil, mucTuChu: String? = nil) {
            self.id = id
            self.duong = duong
            self.board = board
            self.dat = dat
            self.tong = tong
            self.mucTuChu = mucTuChu
        }

        /// Đọc một phần tử `project.list`. **Thiếu khoá thì để `nil`, không điền 0.**
        /// `0/0 tính năng` và "chưa đọc được số tính năng" là hai câu khác nhau, và câu thứ nhất
        /// nói với người dùng rằng dự án của họ rỗng.
        public init(_ d: [String: Any]) {
            id = (d["id"] as? String) ?? (d["path"] as? String).map {
                ($0 as NSString).lastPathComponent
            } ?? "?"
            duong = (d["path"] as? String) ?? ""
            board = d["board"] as? String
            dat = d["passing"] as? Int
            tong = d["total"] as? Int
            mucTuChu = d["autonomy"] as? String
        }

        /// Dòng phụ dưới tên. Chỉ ghép những gì THẬT SỰ đọc được.
        public var dongPhu: String {
            var m: [String] = []
            if let b = board, !b.isEmpty { m.append(b) }
            if let d = dat, let t = tong { m.append("\(d)/\(t) tính năng") }
            if let a = mucTuChu, !a.isEmpty { m.append(a) }
            return m.isEmpty ? "chưa đọc được thông tin dự án" : m.joined(separator: " · ")
        }
    }

    public var onChon: ((DuAn) -> Void)?
    public var onTaoMoi: (() -> Void)?

    private let oLoc = NSTextField()
    private let coc = NSStackView()
    private let nhanRong = NSTextField(labelWithString: "")
    private var tatCa: [DuAn] = []

    public override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 360))
        v.appearance = NSAppearance(named: .aqua)

        oLoc.placeholderString = "Lọc theo tên…"
        oLoc.font = EideToken.fontUI
        oLoc.target = self
        oLoc.action = #selector(_loc)
        // `continuous`: lọc theo TỪNG PHÍM. Chờ Enter thì ô lọc chỉ nhanh hơn việc đọc bằng mắt
        // khi người dùng đã biết chính xác tên mình cần — tức đúng lúc họ ít cần nó nhất.
        oLoc.isContinuous = true
        oLoc.delegate = self

        nhanRong.font = EideToken.fontUI
        nhanRong.textColor = EideToken.Mau.faint
        nhanRong.isHidden = true

        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 2

        let cuon = NSScrollView()
        cuon.contentView = EideKhungLat()
        cuon.documentView = coc
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false

        let moi = NSButton(title: "+ Dự án mới", target: self, action: #selector(_moi))
        moi.bezelStyle = .rounded
        moi.font = NSFont.boldSystemFont(ofSize: 12)

        for s in [oLoc, nhanRong, cuon, moi] as [NSView] {
            s.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(s)
        }
        coc.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            oLoc.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
            oLoc.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
            oLoc.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
            nhanRong.topAnchor.constraint(equalTo: oLoc.bottomAnchor, constant: 8),
            nhanRong.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            nhanRong.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            cuon.topAnchor.constraint(equalTo: nhanRong.bottomAnchor, constant: 6),
            cuon.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
            cuon.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6),
            cuon.bottomAnchor.constraint(equalTo: moi.topAnchor, constant: -8),
            moi.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
            moi.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -10),
            coc.leadingAnchor.constraint(equalTo: cuon.contentView.leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: cuon.contentView.trailingAnchor),
            coc.topAnchor.constraint(equalTo: cuon.contentView.topAnchor),
            coc.widthAnchor.constraint(equalTo: cuon.contentView.widthAnchor),
        ])
        view = v
    }

    /// Nạp danh sách. Gọi được trước khi popover hiện.
    public func dat(_ ds: [DuAn]) {
        tatCa = ds
        _ = view          // ép `loadView` chạy, để nạp trước khi hiện cũng vẽ được
        _ve(loc: oLoc.stringValue)
    }

    /// Kết quả lọc hiện tại — cho bài đo đọc, và cũng là phép lọc THẬT (một hàm, một hành vi).
    public func loc(_ tu: String) -> [DuAn] {
        let t = EideBangLenh.bo(tu)
        guard !t.isEmpty else { return tatCa }
        return tatCa.filter {
            EideBangLenh.bo($0.id).contains(t) || EideBangLenh.bo($0.duong).contains(t)
        }
    }

    private func _ve(loc tu: String) {
        for v in coc.arrangedSubviews { coc.removeArrangedSubview(v); v.removeFromSuperview() }
        let ds = loc(tu)
        // Rỗng vì CHƯA NẠP khác rỗng vì LỌC HẾT. Gộp hai câu lại thì người gõ nhầm một chữ sẽ
        // kết luận workspace của mình trống.
        // Xoá HẲN chữ khi không dùng, không chỉ ẩn đi: một nhãn ẩn vẫn nằm trong cây khung
        // nhìn, nên trình đọc màn hình và mọi bài đo quét chữ đều đọc được nó — và đọc thấy
        // "Không dự án nào khớp" ngay trên một danh sách đang đầy.
        nhanRong.isHidden = !ds.isEmpty
        nhanRong.stringValue = !ds.isEmpty ? ""
            : (tatCa.isEmpty
               ? "Chưa đọc được dự án nào — `project.list` chưa trả về gì."
               : "Không dự án nào khớp “\(tu)” trong \(tatCa.count) dự án.")
        for d in ds {
            let ten = NSTextField(labelWithString: d.id)
            ten.font = NSFont.boldSystemFont(ofSize: 12)
            let phu = NSTextField(labelWithString: d.dongPhu)
            phu.font = EideToken.fontUI
            phu.textColor = EideToken.Mau.muted
            let o = NSStackView(views: [ten, phu])
            o.orientation = .vertical
            o.alignment = .leading
            o.spacing = 0
            let b = EideNutHang(o)
            b.identifier = NSUserInterfaceItemIdentifier(d.duong)
            b.target = self
            b.action = #selector(_chon(_:))
            b.toolTip = d.duong
            coc.addArrangedSubview(b)
            b.widthAnchor.constraint(equalTo: coc.widthAnchor).isActive = true
        }
    }

    /// Gõ vào ô lọc — cho bài đo đi đúng đường người dùng đi.
    public func locDeTest(_ tu: String) {
        _ = view
        oLoc.stringValue = tu
        _ve(loc: tu)
    }

    @objc private func _loc() { _ve(loc: oLoc.stringValue) }
    @objc private func _moi() { onTaoMoi?() }

    @objc private func _chon(_ n: NSButton) {
        guard let duong = n.identifier?.rawValue,
              let d = tatCa.first(where: { $0.duong == duong }) else { return }
        onChon?(d)
    }
}

extension EideChonDuAn: NSTextFieldDelegate {
    public func controlTextDidChange(_ obj: Notification) { _ve(loc: oLoc.stringValue) }
}

/// Một hàng bấm được chứa hai dòng chữ.
///
/// `NSButton` chỉ nhận MỘT tiêu đề, nên tên dự án và dòng phụ phải là hai khung nhìn — và khi ấy
/// vùng bấm phải là cả hàng, không phải riêng chữ. Bản đầu dùng nút trơn với `\n` trong tiêu đề:
/// dòng phụ mất hẳn cỡ chữ riêng và cả hai dòng cùng đậm.
public final class EideNutHang: NSButton {

    public init(_ trong: NSView) {
        super.init(frame: .zero)
        isBordered = false
        title = ""
        trong.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trong)
        NSLayoutConstraint.activate([
            trong.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            trong.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            trong.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            trong.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Chữ của hàng — cho bài đo đọc, vì `title` rỗng.
    public var chuHang: String {
        subviews.flatMap(\.subviews).compactMap { ($0 as? NSTextField)?.stringValue }
            .joined(separator: " · ")
    }
}
