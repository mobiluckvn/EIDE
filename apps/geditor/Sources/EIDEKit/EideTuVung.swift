import AppKit

/// **Bộ từ vựng hiển thị** — bảng, cây, mã, diff, dải trạng thái.
///
/// ## Vì sao có tệp này
///
/// Tới 15/09/2026, `ManHinhCoSo` cho lớp con đúng ba thứ: `noiRong` (một đoạn văn),
/// `themDong(nhãn, giá trị)` (một dòng), `chuaNap` (một lời xin lỗi). Cả **23 màn** vì thế đều
/// là một danh sách dọc `nhãn: giá trị` — kể cả những màn mà tài liệu vẽ hẳn một hình dạng khác:
///
/// | Màn | UXD-13 vẽ | Dựng được bằng ba thứ kia |
/// |---|---|---|
/// | Mã nguồn | cây dự án + mã có chú thích fact ở lề + cột hộ chiếu | không |
/// | Kế hoạch & mã | diff trước/sau | không |
/// | Bản đồ tri thức | đồ thị / cây lân cận | không |
/// | Hộ chiếu chip | bảng fact có tầng, nguồn, độ tin | không |
/// | Mô phỏng | dòng thời gian tín hiệu | không |
///
/// Chủ sản phẩm nói thẳng ngày 15/09: *"mã nguồn là một thư mục mã nguồn có cấu trúc. Bạn đang
/// hiển thị là dạng một file text thì làm sao mà okay được"*. Đúng, và nó không phải lỗi của
/// màn Mã nguồn: **không màn nào dựng nổi hình dạng của nó bằng bộ từ vựng đang có.** Sửa từng
/// màn thì mỗi màn sẽ tự đẻ ra một bảng riêng, một cây riêng — 23 cách cuộn, 23 cỡ chữ, 23 lối
/// bàn phím. Nên bộ từ vựng phải nằm ở lớp cơ sở, một lần.
///
/// ## Một quyết định chung: KHÔNG lồng vùng cuộn
///
/// Thân màn (`cot`) đã nằm trong một `NSScrollView`. Nhét thêm một bảng có bộ cuộn riêng vào đó
/// tạo ra hai vùng cuộn lồng nhau, và con lăn chuột sẽ bị vùng TRONG nuốt — người dùng lăn giữa
/// màn thì nội dung ngoài đứng im, lăn lệch sang mép thì nó nhảy. Đây là lỗi giao diện kinh điển
/// và nó không tự lộ ra trên ảnh chụp.
///
/// Nên mọi khung nhìn trong tệp này **tự cao bằng nội dung** và để thân màn cuộn — *cho tới*
/// ngưỡng `caoToiDa`. Quá ngưỡng thì nó bật bộ cuộn riêng, VÀ nói ra là đang cắt bao nhiêu (xem
/// `_noiBiCat`). Một bảng 8.000 fact dựng hết 8.000 hàng view sẽ làm treo cửa sổ, nên ngưỡng là
/// bắt buộc; điều không bắt buộc — và là điều quan trọng — là nói cho người dùng biết.
public enum EideTuVung {

    /// Chiều cao tối đa của một khung nhìn nhúng, tính bằng điểm.
    ///
    /// 420 pt ≈ 17 hàng bảng. Chọn theo mockup 1440×900 của UXD-13: quá con số này thì một khung
    /// nhìn chiếm hết chỗ của mọi thứ dưới nó, và những thứ dưới nó là chỗ đặt các nút hành động.
    public static let caoToiDa: CGFloat = 420

    /// Số hàng dựng nhiều nhất trong một lần. Trên ngưỡng này thì cắt và nói ra.
    ///
    /// 2.000 hàng dựng mất khoảng 0,2 s và giữ cửa sổ mượt. `passport.query` trên một dự án thật
    /// trả hàng nghìn fact, nên ngưỡng này sẽ chạm tới — nó không phải trường hợp hiếm.
    public static let hangToiDa = 2000
}

// MARK: - Bảng

/// Một bảng có tiêu đề cột, sắp xếp được bằng cách bấm tiêu đề.
///
/// Sắp xếp KHÔNG phải trang trí: bảng fact và bảng cổng công cụ đều là thứ người ta đọc để tìm
/// cái tệ nhất, và "cái tệ nhất" nằm ở cột nào thì tuỳ lúc. Không sắp xếp được thì người dùng
/// phải đọc hết — mà bảng dài thì họ không đọc hết, họ đọc mười dòng đầu và kết luận.
public final class EideBangView: NSView {

    /// Người chọn một hàng (theo chỉ số trong dữ liệu GỐC, không phải sau khi sắp xếp).
    public var onChon: ((Int) -> Void)?

    private let bang = NSTableView()
    private let cuon = NSScrollView()
    private let tenCot: [String]
    private var hang: [[String]]
    /// Ánh xạ hàng-đang-hiện → hàng-gốc. Sắp xếp đổi thứ tự hiện, không đổi dữ liệu.
    private var thuTu: [Int]
    private let canPhai: Set<Int>
    private let mauO: ((Int, Int) -> NSColor?)?
    private var cotDangSap: Int?
    private var xuoi = true

    public init(cot: [String], hang: [[String]], canPhai: Set<Int> = [],
                mauO: ((Int, Int) -> NSColor?)? = nil) {
        self.tenCot = cot
        self.hang = hang
        self.thuTu = Array(hang.indices)
        self.canPhai = canPhai
        self.mauO = mauO
        super.init(frame: .zero)
        dung()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung() {
        bang.headerView = NSTableHeaderView()
        bang.rowHeight = 20
        bang.usesAlternatingRowBackgroundColors = true
        bang.backgroundColor = EideToken.Mau.surface
        bang.dataSource = self
        bang.delegate = self
        bang.gridStyleMask = []
        bang.allowsColumnResizing = true
        bang.target = self
        bang.action = #selector(bamHang)
        for (i, t) in tenCot.enumerated() {
            let c = NSTableColumn(identifier: .init("c\(i)"))
            c.title = t
            c.minWidth = 48
            // Bề rộng theo NỘI DUNG dài nhất của cột, trần 320. Chia đều thì cột "giá trị"
            // (0x40005400) bị cắt trong khi cột "đơn vị" (B) thừa chỗ — và cột bị cắt luôn là
            // cột người ta mở bảng ra để đọc.
            let dai = ([t] + hang.map { i < $0.count ? $0[i] : "" })
                .map { $0.count }.max() ?? 8
            c.width = min(320, max(56, CGFloat(dai) * 7 + 16))
            bang.addTableColumn(c)
        }

        cuon.documentView = bang
        cuon.drawsBackground = false
        cuon.borderType = .lineBorder
        cuon.translatesAutoresizingMaskIntoConstraints = false
        // Cuộn NGANG khi tổng bề rộng cột vượt khung. Bảng fact có tám cột và khung giữa của
        // panel rộng khoảng 1.000 pt — đo 15/09: ba cột cuối (`độ tin`, `cách trích`, `nguồn`)
        // nằm ngoài mép và không có cách nào tới được chúng. Một cột không tới được thì bằng
        // một cột không tồn tại, chỉ tệ hơn ở chỗ người dùng biết nó có ở đó.
        cuon.hasHorizontalScroller = true
        cuon.autohidesScrollers = true
        addSubview(cuon)

        // Chiều cao nội dung = các hàng + ĐẦU BẢNG THẬT + viền.
        //
        // Hằng số 24 trước đây là ước lượng cho đầu bảng, và nó thiếu vài điểm: hàng cuối bị cắt
        // ngang trên ảnh chụp 15/09. Một hàng bị cắt nửa dưới trông y như một hàng bình thường
        // nếu người ta không nhìn kỹ — và ở một bảng fact thì hàng cuối có thể là hàng XUNG ĐỘT.
        let caoDau = Self.caoDauBang(bang)
        let caoND = CGFloat(hang.count) * (bang.rowHeight + bang.intercellSpacing.height)
            + caoDau + 4
        let cao = min(caoND, EideTuVung.caoToiDa)
        // Bộ cuộn dọc riêng CHỈ khi nội dung thật sự bị cắt — xem ghi chú "không lồng vùng cuộn"
        // ở đầu tệp.
        cuon.hasVerticalScroller = caoND > EideTuVung.caoToiDa
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
            cuon.heightAnchor.constraint(equalToConstant: cao),
        ])
    }

    @objc private func bamHang() {
        let r = bang.selectedRow
        guard r >= 0, r < thuTu.count else { return }
        onChon?(thuTu[r])
    }

    /// Số hàng đang giữ — cho test.
    public var soHang: Int { hang.count }

    /// Nội dung một ô THEO THỨ TỰ ĐANG HIỆN — cho test kiểm phép sắp xếp.
    ///
    /// `nil` nghĩa là KHÔNG CÓ HÀNG ẤY. Một cột thiếu dữ liệu trả `""` — đúng bằng thứ ô ấy vẽ
    /// ra trên màn. Nếu cả hai cùng trả `nil` thì test không phân biệt được "bảng ngắn hơn ta
    /// tưởng" với "hàng này thiếu một trường", mà đó là hai lỗi khác nhau.
    public func oDeTest(hang h: Int, cot c: Int) -> String? {
        guard h >= 0, h < thuTu.count, c >= 0, c < tenCot.count else { return nil }
        let g = self.hang[thuTu[h]]
        return c < g.count ? g[c] : ""
    }

    /// Bấm tiêu đề cột bằng mã — cho test.
    public func sapDeTest(cot c: Int) { tableView(bang, didClick: bang.tableColumns[c]) }

    /// Có bộ cuộn riêng không — cho test canh quy tắc "không lồng vùng cuộn".
    public var coBoCuonDeTest: Bool { cuon.hasVerticalScroller }

    /// Cuộn ngang được không — cho test canh "cột nằm ngoài mép vẫn tới được".
    public var coCuonNgangDeTest: Bool { cuon.hasHorizontalScroller }

    /// Chiều cao một hàng kể cả khe giữa hàng — cho test tính chiều cao cần thiết.
    public var caoHangDeTest: CGFloat { bang.rowHeight + bang.intercellSpacing.height }

    /// Chiều cao đầu bảng — cho test.
    public var caoDauDeTest: CGFloat { Self.caoDauBang(bang) }

    /// Chiều cao đầu bảng, đo được cả TRƯỚC khi bố cục chạy.
    ///
    /// `headerView?.fittingSize.height` trả **0** khi khung nhìn chưa vào cây và chưa bố cục —
    /// đúng lúc ta cần nó, vì chiều cao khung được đặt ngay trong `init`. Dùng thẳng con số ấy
    /// thì khung thiếu đúng một đầu bảng, và hàng CUỐI bị cắt ngang: thấy rõ trên ảnh chụp
    /// 15/09/2026, và một hàng cắt nửa dưới trông y như hàng bình thường nếu không nhìn kỹ.
    ///
    /// Nên: lấy số đo thật khi có, rơi về 25 pt (chiều cao `NSTableHeaderView` chuẩn của aqua)
    /// khi nó chưa nói được gì.
    static func caoDauBang(_ b: NSTableView) -> CGFloat {
        guard b.headerView != nil else { return 0 }
        let d = b.headerView?.fittingSize.height ?? 0
        return d >= 20 ? d : 25
    }
}

extension EideBangView: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int { thuTu.count }

    /// Sắp xếp SO SÁNH SỐ khi cả cột là số.
    ///
    /// So chuỗi thì `"1024"` đứng trước `"96"`, và một bảng kích thước bộ nhớ sắp xếp như thế
    /// tệ hơn là không sắp xếp: nó trông như đã sắp, nên người ta tin nó.
    public func tableView(_ tv: NSTableView, didClick col: NSTableColumn) {
        guard let i = tv.tableColumns.firstIndex(of: col) else { return }
        if cotDangSap == i { xuoi.toggle() } else { cotDangSap = i; xuoi = true }
        func o(_ r: Int) -> String { i < hang[r].count ? hang[r][i] : "" }
        let deuLaSo = thuTu.allSatisfy { Double(o($0).replacingOccurrences(of: ",", with: "")) != nil }
        thuTu.sort { a, b in
            let x = o(a), y = o(b)
            let nho: Bool
            if deuLaSo {
                nho = (Double(x.replacingOccurrences(of: ",", with: "")) ?? 0)
                    < (Double(y.replacingOccurrences(of: ",", with: "")) ?? 0)
            } else {
                nho = x.localizedStandardCompare(y) == .orderedAscending
            }
            return xuoi ? nho : !nho
        }
        tv.reloadData()
    }

    public func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        guard let col, let i = tv.tableColumns.firstIndex(of: col),
              row < thuTu.count else { return nil }
        let g = hang[thuTu[row]]
        let noiDung = i < g.count ? g[i] : ""
        let hop = NSTableCellView()
        let l = NSTextField(labelWithString: noiDung)
        l.font = canPhai.contains(i) ? EideToken.fontMono : EideToken.fontUI
        l.textColor = mauO?(thuTu[row], i) ?? EideToken.Mau.text
        l.lineBreakMode = .byTruncatingMiddle
        l.alignment = canPhai.contains(i) ? .right : .left
        // Tooltip mang giá trị ĐẦY ĐỦ: cột hẹp cắt chữ, và một đường dẫn hay một IRI bị cắt thì
        // không còn dùng được để đối chiếu.
        l.toolTip = noiDung
        hop.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 4),
            l.trailingAnchor.constraint(equalTo: hop.trailingAnchor, constant: -4),
            l.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
        ])
        return hop
    }
}

// MARK: - Cây

/// Một nút trong cây — thư mục, tệp, hay một nhóm bất kỳ.
///
/// `dau` là một chuỗi ngắn hiện BÊN PHẢI tên (số fact, số vi phạm, trạng thái dựng). Nó là chỗ
/// duy nhất trong cây để nói "tệp này có vấn đề" mà không phải mở tệp ra.
public final class EideNutCay {
    public let ten: String
    public let duong: String
    public let laThuMuc: Bool
    public var con: [EideNutCay]
    public var dau: String
    public var mauDau: NSColor?
    /// Mở sẵn khi dựng cây.
    public var moSan: Bool

    public init(ten: String, duong: String, laThuMuc: Bool, con: [EideNutCay] = [],
                dau: String = "", mauDau: NSColor? = nil, moSan: Bool = false) {
        self.ten = ten
        self.duong = duong
        self.laThuMuc = laThuMuc
        self.con = con
        self.dau = dau
        self.mauDau = mauDau
        self.moSan = moSan
    }
}

/// Cây thư mục / cây phân cấp.
public final class EideCayView: NSView {

    /// Người chọn một nút. Thư mục cũng gọi — bên nhận tự quyết có làm gì không.
    public var onChon: ((EideNutCay) -> Void)?

    private let cay = NSOutlineView()
    private let cuon = NSScrollView()
    private let goc: [EideNutCay]

    /// `cao: nil` nghĩa là **giãn theo khung chứa** — dùng khi cây là một CỘT của cửa sổ chứ
    /// không phải một khối nhúng trong thân màn.
    ///
    /// Bản đầu không có lựa chọn này và tôi truyền `cao: 4000` cho cột cây dự án để nó "đủ cao".
    /// Ràng buộc chiều cao là ràng buộc CỨNG, nên Auto Layout kéo cả cửa sổ lên 4000 pt: ảnh
    /// chụp ra 2200×8000, và trên máy thật thì thanh trạng thái bị đẩy xuống dưới đáy màn hình.
    /// Một con số "đủ lớn" trong một ràng buộc cứng luôn là một lỗi bố cục đang chờ ngày lộ.
    public init(goc: [EideNutCay], cao: CGFloat? = EideTuVung.caoToiDa) {
        self.goc = goc
        super.init(frame: .zero)
        dung(cao: cao)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung(cao: CGFloat?) {
        cay.headerView = nil
        cay.rowHeight = 20
        cay.backgroundColor = EideToken.Mau.surface
        cay.dataSource = self
        cay.delegate = self
        cay.indentationPerLevel = 14
        cay.autoresizesOutlineColumn = false
        cay.target = self
        cay.action = #selector(bamNut)
        let c = NSTableColumn(identifier: .init("ten"))
        c.width = 260
        cay.addTableColumn(c)
        cay.outlineTableColumn = c

        cuon.documentView = cay
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false
        cuon.borderType = .lineBorder
        cuon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        if let cao { cuon.heightAnchor.constraint(equalToConstant: cao).isActive = true }
        cay.reloadData()
        _moSan(goc)
    }

    private func _moSan(_ ds: [EideNutCay]) {
        for n in ds where n.laThuMuc {
            if n.moSan { cay.expandItem(n) }
            _moSan(n.con)
        }
    }

    @objc private func bamNut() {
        let r = cay.selectedRow
        guard r >= 0, let n = cay.item(atRow: r) as? EideNutCay else { return }
        onChon?(n)
    }

    /// Chọn nút theo đường dẫn, mở mọi nút cha trên đường đi. Trả false nếu không có.
    @discardableResult
    public func chon(duong: String) -> Bool {
        func tim(_ ds: [EideNutCay], _ duongDi: [EideNutCay]) -> [EideNutCay]? {
            for n in ds {
                if n.duong == duong { return duongDi + [n] }
                if let r = tim(n.con, duongDi + [n]) { return r }
            }
            return nil
        }
        guard let dd = tim(goc, []) else { return false }
        for n in dd.dropLast() { cay.expandItem(n) }
        let r = cay.row(forItem: dd.last!)
        guard r >= 0 else { return false }
        cay.selectRowIndexes([r], byExtendingSelection: false)
        cay.scrollRowToVisible(r)
        return true
    }

    /// Số hàng đang hiện (đã tính nút đang gấp) — cho test.
    public var soHangHien: Int { cay.numberOfRows }
}

extension EideCayView: NSOutlineViewDataSource, NSOutlineViewDelegate {

    public func outlineView(_ ov: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? EideNutCay)?.con.count ?? goc.count
    }

    public func outlineView(_ ov: NSOutlineView, child i: Int, ofItem item: Any?) -> Any {
        (item as? EideNutCay)?.con[i] ?? goc[i]
    }

    public func outlineView(_ ov: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // Thư mục RỖNG vẫn mở được — mở ra thấy trống là một câu trả lời, còn một thư mục không
        // có tam giác trông y như một tệp.
        (item as? EideNutCay)?.laThuMuc ?? false
    }

    public func outlineView(_ ov: NSOutlineView, viewFor col: NSTableColumn?,
                            item: Any) -> NSView? {
        guard let n = item as? EideNutCay else { return nil }
        let hop = NSTableCellView()
        let ten = NSTextField(labelWithString: n.ten)
        ten.font = EideToken.fontUI
        ten.textColor = EideToken.Mau.text
        ten.lineBreakMode = .byTruncatingMiddle
        ten.toolTip = n.duong

        let dau = NSTextField(labelWithString: n.dau)
        dau.font = EideToken.fontUI
        dau.textColor = n.mauDau ?? EideToken.Mau.muted
        dau.setContentHuggingPriority(.required, for: .horizontal)

        let hang = NSStackView(views: [ten, dau])
        hang.orientation = .horizontal
        hang.spacing = EideToken.space[1]
        hang.translatesAutoresizingMaskIntoConstraints = false
        hop.addSubview(hang)
        NSLayoutConstraint.activate([
            hang.leadingAnchor.constraint(equalTo: hop.leadingAnchor),
            hang.trailingAnchor.constraint(lessThanOrEqualTo: hop.trailingAnchor, constant: -4),
            hang.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
        ])
        return hop
    }
}

// MARK: - Mã nguồn

/// Một dòng mã kèm những gì EIDE biết về nó.
public struct EideDongMa {
    public let so: Int
    public let chu: String
    /// Chú thích fact ở lề (`eide:fact f_b1c2…` → "BME280 addr 0x76, BoardPassport").
    public let fact: String?
    /// Dòng này vi phạm constant-guard.
    public let viPham: Bool
    /// Màu riêng — dùng cho diff (`+` xanh, `-` đỏ).
    public let mau: NSColor?

    public init(so: Int, chu: String, fact: String? = nil, viPham: Bool = false,
                mau: NSColor? = nil) {
        self.so = so
        self.chu = chu
        self.fact = fact
        self.viPham = viPham
        self.mau = mau
    }
}

/// Khối mã có số dòng, dấu fact ở lề, và dòng vi phạm tô đỏ.
///
/// Dựng bằng `NSTableView` chứ không phải một `NSTextView`, vì ba lý do đo được: bảng tái dùng
/// hàng (một tệp 4.000 dòng không dựng 4.000 view), mỗi dòng gắn được dữ liệu riêng (fact,
/// vi phạm), và chọn một dòng là một sự kiện — mà "bấm vào dòng vi phạm để mở cổng G-FACT" là
/// đúng việc mockup `Code.dc.html` vẽ.
public final class EideMaView: NSView {

    /// Người chọn một dòng (số dòng 1-based).
    public var onChonDong: ((Int) -> Void)?

    private let bang = NSTableView()
    private let cuon = NSScrollView()
    private let dong: [EideDongMa]

    public init(dong: [EideDongMa], cao: CGFloat = EideTuVung.caoToiDa) {
        self.dong = Array(dong.prefix(EideTuVung.hangToiDa))
        super.init(frame: .zero)
        dung(cao: cao)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung(cao: CGFloat) {
        bang.headerView = nil
        bang.rowHeight = 17
        bang.backgroundColor = EideToken.Mau.surface
        bang.dataSource = self
        bang.delegate = self
        bang.gridStyleMask = []
        bang.target = self
        bang.action = #selector(bamDong)
        for (id, w) in [("so", CGFloat(44)), ("dau", 16), ("ma", 2000)] {
            let c = NSTableColumn(identifier: .init(id))
            c.width = w
            bang.addTableColumn(c)
        }
        cuon.documentView = bang
        cuon.hasVerticalScroller = true
        cuon.hasHorizontalScroller = true
        cuon.drawsBackground = false
        cuon.borderType = .lineBorder
        cuon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
            cuon.heightAnchor.constraint(equalToConstant: cao),
        ])
    }

    @objc private func bamDong() {
        let r = bang.selectedRow
        guard r >= 0, r < dong.count else { return }
        onChonDong?(dong[r].so)
    }

    /// Đưa một dòng vào tầm nhìn và chọn nó.
    public func toiDong(_ so: Int) {
        guard let i = dong.firstIndex(where: { $0.so == so }) else { return }
        bang.selectRowIndexes([i], byExtendingSelection: false)
        bang.scrollRowToVisible(i)
    }

    public var soDongMa: Int { dong.count }

    /// Số dòng đang bị đánh dấu vi phạm — cho test.
    public var soViPham: Int { dong.filter { $0.viPham }.count }

    /// Màu của một dòng theo chỉ số — cho test canh phép tô diff.
    public func mauDongDeTest(_ i: Int) -> NSColor? { i < dong.count ? dong[i].mau : nil }
}

extension EideMaView: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int { dong.count }

    public func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let d = dong[row]
        let hop = NSTableCellView()
        let l = NSTextField(labelWithString: "")
        l.font = EideToken.fontMono
        switch col?.identifier.rawValue {
        case "so":
            l.stringValue = "\(d.so)"
            l.alignment = .right
            l.textColor = EideToken.Mau.muted
        case "dau":
            // Một ký tự ở lề, không phải một chữ: lề là chỗ hẹp nhất màn hình và người đọc quét
            // nó bằng mắt chứ không đọc. `!` là vi phạm, `•` là có fact.
            l.stringValue = d.viPham ? "!" : (d.fact != nil ? "•" : "")
            l.textColor = d.viPham ? EideToken.Mau.bad : EideToken.Mau.info
            l.toolTip = d.viPham ? "constant-guard: hằng số không có fact" : d.fact
        default:
            l.stringValue = d.chu
            l.textColor = d.mau ?? (d.viPham ? EideToken.Mau.bad : EideToken.Mau.text)
            l.toolTip = d.fact
        }
        hop.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 2),
            l.trailingAnchor.constraint(equalTo: hop.trailingAnchor, constant: -2),
            l.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
        ])
        return hop
    }
}

// MARK: - Dải trạng thái

/// Dải ngang các ô `nhãn: giá trị` có màu — cổng công cụ khi lưu, tóm tắt dựng.
///
/// Ngang chứ không dọc là chủ ý: mockup `Code.dc.html` đặt `build 3,1 s · size Flash 38% ·
/// static 0 vi phạm · host-test 12/12 · constant-guard 1 vi phạm → chặn G3` thành MỘT dòng đáy.
/// Xếp dọc thì năm con số ấy chiếm năm dòng của vùng đọc mã, và chúng là thứ người ta liếc chứ
/// không đọc.
public final class EideDaiTrangThai: NSView {

    public struct O {
        public let nhan: String
        public let gia: String
        public let mau: NSColor?
        public init(_ nhan: String, _ gia: String, mau: NSColor? = nil) {
            self.nhan = nhan
            self.gia = gia
            self.mau = mau
        }
    }

    private let hang = NSStackView()

    public init(o: [O]) {
        super.init(frame: .zero)
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = EideToken.space[2]
        hang.translatesAutoresizingMaskIntoConstraints = false
        for x in o {
            let n = NSTextField(labelWithString: x.nhan)
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.muted
            let g = NSTextField(labelWithString: x.gia)
            g.font = EideToken.fontUI
            g.textColor = x.mau ?? EideToken.Mau.text
            let cum = NSStackView(views: [n, g])
            cum.orientation = .horizontal
            cum.spacing = 4
            hang.addArrangedSubview(cum)
        }
        addSubview(hang)
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: topAnchor),
            hang.leadingAnchor.constraint(equalTo: leadingAnchor),
            hang.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            hang.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public var soO: Int { hang.arrangedSubviews.count }
}

// MARK: - Gắn vào ManHinhCoSo

extension ManHinhCoSo {

    /// Thêm một bảng. `canPhai` là chỉ số các cột canh phải và dùng phông đơn cách (số, địa chỉ).
    @discardableResult
    public func themBang(cot tenCot: [String], hang: [[String]], canPhai: Set<Int> = [],
                         mauO: ((Int, Int) -> NSColor?)? = nil,
                         chon: ((Int) -> Void)? = nil) -> EideBangView {
        let bi = hang.count > EideTuVung.hangToiDa
        let v = EideBangView(cot: tenCot, hang: bi ? Array(hang.prefix(EideTuVung.hangToiDa)) : hang,
                             canPhai: canPhai, mauO: mauO)
        v.onChon = chon
        v.translatesAutoresizingMaskIntoConstraints = false
        cot.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: cot.widthAnchor).isActive = true
        if bi { _noiBiCat(hien: EideTuVung.hangToiDa, tong: hang.count, thu: "hàng") }
        return v
    }

    /// Thêm một cây.
    @discardableResult
    public func themCay(goc: [EideNutCay], cao: CGFloat? = EideTuVung.caoToiDa,
                        chon: ((EideNutCay) -> Void)? = nil) -> EideCayView {
        let v = EideCayView(goc: goc, cao: cao)
        v.onChon = chon
        v.translatesAutoresizingMaskIntoConstraints = false
        cot.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: cot.widthAnchor).isActive = true
        return v
    }

    /// Thêm một khối mã.
    ///
    /// `viSaoCat` đổi CÂU nói khi nội dung bị cắt. Mặc định là câu chung ("để cửa sổ không
    /// treo"); màn duyệt mã truyền câu của nó vào, vì ở đó phần bị cắt không phải "phần còn
    /// lại của một danh sách" mà là **mã người dùng sắp duyệt mà không nhìn thấy**.
    @discardableResult
    public func themMa(dong ds: [EideDongMa], cao: CGFloat = EideTuVung.caoToiDa,
                       viSaoCat: String? = nil,
                       chonDong: ((Int) -> Void)? = nil) -> EideMaView {
        let v = EideMaView(dong: ds, cao: cao)
        v.onChonDong = chonDong
        v.translatesAutoresizingMaskIntoConstraints = false
        cot.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: cot.widthAnchor).isActive = true
        if ds.count > EideTuVung.hangToiDa {
            _noiBiCat(hien: EideTuVung.hangToiDa, tong: ds.count, thu: "dòng", viSao: viSaoCat)
        }
        return v
    }

    /// Thêm một diff hợp nhất (unified diff) — `+` xanh, `-` đỏ, `@@` mờ.
    ///
    /// Nhận thẳng chuỗi diff vì đó là thứ `plan.diff`/`code.modify` trả về. Tự dựng diff từ hai
    /// bản văn là việc của bên sinh ra chúng: hai thuật toán diff khác nhau cho hai kết quả khác
    /// nhau, và màn hình phải hiện ĐÚNG cái đã được duyệt, không phải cái nó tự tính lại.
    @discardableResult
    public func themDiff(_ diff: String, cao: CGFloat = EideTuVung.caoToiDa,
                         viSaoCat: String? = nil) -> EideMaView {
        let ds = diff.components(separatedBy: .newlines).enumerated().map { i, d -> EideDongMa in
            let mau: NSColor?
            if d.hasPrefix("+++") || d.hasPrefix("---") { mau = EideToken.Mau.muted }
            else if d.hasPrefix("+") { mau = EideToken.Mau.ok }
            else if d.hasPrefix("-") { mau = EideToken.Mau.bad }
            else if d.hasPrefix("@@") { mau = EideToken.Mau.info }
            else { mau = nil }
            return EideDongMa(so: i + 1, chu: d, mau: mau)
        }
        return themMa(dong: ds, cao: cao, viSaoCat: viSaoCat)
    }

    /// Thêm một dải trạng thái ngang.
    @discardableResult
    public func themDaiTrangThai(_ o: [EideDaiTrangThai.O]) -> EideDaiTrangThai {
        let v = EideDaiTrangThai(o: o)
        v.translatesAutoresizingMaskIntoConstraints = false
        cot.addArrangedSubview(v)
        return v
    }

    /// Nói ra phần bị cắt. Im lặng cắt là cách chắc chắn nhất để một bảng thiếu bị đọc như đủ.
    private func _noiBiCat(hien: Int, tong: Int, thu: String, viSao: String? = nil) {
        let v = noiRong("Hiện \(hien)/\(tong) \(thu) — "
                        + (viSao ?? "cắt bớt để cửa sổ không treo. "
                                  + "Lọc bớt rồi chạy lại để thấy phần còn lại."))
        v.textColor = viSao == nil ? EideToken.Mau.warn : EideToken.Mau.bad
    }
}
