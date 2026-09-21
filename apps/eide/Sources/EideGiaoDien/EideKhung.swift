import AppKit
import EideLoi

/// **Khung cửa sổ EIDE — năm vùng.** Dựng thẳng từ `docs/EIDE_UI_Demo_v2.html`.
///
/// ```
/// ┌──────────────────────────────────────────────────────────────────┐
/// │ thanh trên  46 pt · viền dưới 2 pt đỏ                            │
/// ├──────────┬───────────────────────────────────────┬───────────────┤
/// │ cột trái │ thanh tab                             │ cột phải      │
/// │  198 pt  ├───────────────────────────────────────┤   236 pt      │
/// │          │ VÙNG LÀM VIỆC — nền trắng, giãn       │  ĐANG CHẠY    │
/// │  6 nhóm  │                                       │  CHỜ TÔI      │
/// │  25 màn  ├───────────────────────────────────────┤  HOÀN TÁC     │
/// │          │ DOCK 48 / 220 / 320 — viền trên       │               │
/// └──────────┴───────────────────────────────────────┴───────────────┘
/// ```
///
/// ## Vì sao ràng buộc tường minh chứ không `NSStackView` lồng nhau
///
/// Bản cũ thử dựng đúng hình này bằng stack lồng nhau và cửa sổ tụt xuống 70 pt. Hai lý do, ghi
/// lại vì cả hai đều im lặng: (1) `cotGiua.height == hangChinh.height` trong khi chiều cao
/// `hangChinh` lại suy từ `cotGiua` là một định nghĩa VÒNG TRÒN, Auto Layout giải nó ở giá trị
/// nhỏ nhất; (2) `NSStackView` phá ràng buộc nội bộ của CHÍNH NÓ ở ưu tiên ≤ 999 mà không ghi
/// log, nên mọi SÀN đặt bên trong stack đều bị nuốt không dấu vết.
///
/// Bố cục ở đây là một bảng ràng buộc phẳng, đọc từ trên xuống theo đúng thứ tự hình vẽ. Nó dài
/// hơn, và nó nói ra hình dạng của chính nó.
public final class EideKhung: NSView {

    // Kích thước LẤY TỪ bản demo, không đặt lại. Bốn con số này là hợp đồng với bản thiết kế.
    public static let CAO_THANH_TREN: CGFloat = 46
    public static let RONG_COT_TRAI: CGFloat = 198
    public static let RONG_COT_PHAI: CGFloat = 236

    /// Cỡ cửa sổ tối thiểu — §2.2.
    public static let CO_TOI_THIEU = NSSize(width: 1100, height: 700)
    /// Dải hẹp của cột phải khi cửa sổ chạm ngưỡng — §2.2.
    public static let RONG_COT_PHAI_HEP: CGFloat = 44

    /// Cột phải tự thu khi bề ngang xuống tới đây.
    ///
    /// **Bằng đúng bề ngang tối thiểu, không phải một con số thứ hai.** §2.2 nói "cửa sổ tối
    /// thiểu 1100 × 700; DƯỚI ngưỡng thì cột phải thu lại" — mà một bề ngang tối thiểu đã được
    /// `NSWindow` cưỡng chế thì không bao giờ xuống dưới được, nên "dưới ngưỡng" theo nghĩa đen
    /// là một trạng thái không tồn tại. Đọc là "TẠI ngưỡng" giữ được cả hai vế và không phải bịa
    /// thêm một con số không có trong tài liệu — xem [DEV-139].
    public static let NGUONG_HEP: CGFloat = CO_TOI_THIEU.width

    public let thanhTren = EideThanhTren()
    public let cotTrai = EideDieuHuong()
    public let thanhTab = EideThanhTab()
    public let vungLamViec = EideVungLamViec()
    public let dock = EideDock()
    public let cotPhai = EideCotPhai()

    private let vienDo = NSView()
    private let vachDock = NSBox()
    /// Dải "Dữ liệu cũ" — B6/N6. Cao 0 khi bình thường, 28 khi mất daemon.
    private let daiCu = NSView()
    private let nhanCu = NSTextField(labelWithString: "")
    /// "bấm để tải lại" — §7.2. Một dải chỉ báo mà không bấm được thì người đọc xong không có
    /// việc gì làm với nó ngoài việc lo.
    public let nutTaiLai = NSButton(title: "Tải lại", target: nil, action: nil)
    private lazy var caoDaiCu = daiCu.heightAnchor.constraint(equalToConstant: 0)
    private lazy var rongCotPhai =
        cotPhai.widthAnchor.constraint(equalToConstant: Self.RONG_COT_PHAI)
    /// Người đã tự bấm nút gấp: từ đó thôi tự động theo bề ngang. Một cột cứ tự bung ra mỗi lần
    /// kéo cửa sổ, sau khi người dùng vừa cố ý gấp nó lại, là một cuộc cãi nhau với chính họ.
    private var hepTay: Bool?

    /// Màn hình chào — chiếm TOÀN cửa sổ khi chưa có dự án (§3.1).
    public let manChao = EideManChao()

    /// Bảng lệnh ⌘K — lớp phủ, đứng TRÊN cả màn chào.
    public let bangLenh = EideBangLenh()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        dung()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung() {
        // Ghim bảng màu SÁNG: UXD-13 khai đúng một bảng màu, nên "chế độ tối của EIDE" là thứ
        // chưa tồn tại, và để AppKit tự đổi màu control sẽ cho ra ô nhập ĐEN trên nền sáng.
        appearance = NSAppearance(named: .aqua)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.bg.cgColor

        vienDo.wantsLayer = true
        vienDo.layer?.backgroundColor = EideToken.Mau.brand.cgColor
        vachDock.boxType = .separator

        daiCu.wantsLayer = true
        daiCu.layer?.backgroundColor = EideToken.Mau.warnBg.cgColor
        nhanCu.font = EideToken.fontUI
        nhanCu.textColor = EideToken.Mau.warn
        nhanCu.translatesAutoresizingMaskIntoConstraints = false
        daiCu.addSubview(nhanCu)
        nutTaiLai.bezelStyle = .inline
        nutTaiLai.isHidden = true
        nutTaiLai.translatesAutoresizingMaskIntoConstraints = false
        daiCu.addSubview(nutTaiLai)
        daiCu.isHidden = true
        cotPhai.onDoiHep = { [weak self] h in self?.nguoiDoiCotPhai(h) }

        for v in [thanhTren, vienDo, cotTrai, thanhTab, daiCu, vungLamViec,
                  vachDock, dock, cotPhai, manChao, bangLenh] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            // ── hàng 1: thanh trên, suốt chiều ngang, viền dưới 2 pt
            thanhTren.topAnchor.constraint(equalTo: topAnchor),
            thanhTren.leadingAnchor.constraint(equalTo: leadingAnchor),
            thanhTren.trailingAnchor.constraint(equalTo: trailingAnchor),
            thanhTren.heightAnchor.constraint(equalToConstant: Self.CAO_THANH_TREN),
            vienDo.topAnchor.constraint(equalTo: thanhTren.bottomAnchor),
            vienDo.leadingAnchor.constraint(equalTo: leadingAnchor),
            vienDo.trailingAnchor.constraint(equalTo: trailingAnchor),
            vienDo.heightAnchor.constraint(equalToConstant: 2),

            // ── cột trái: từ dưới viền đỏ xuống đáy
            cotTrai.topAnchor.constraint(equalTo: vienDo.bottomAnchor),
            cotTrai.leadingAnchor.constraint(equalTo: leadingAnchor),
            cotTrai.bottomAnchor.constraint(equalTo: bottomAnchor),
            cotTrai.widthAnchor.constraint(equalToConstant: Self.RONG_COT_TRAI),

            // ── cột phải: từ dưới viền đỏ xuống đáy
            cotPhai.topAnchor.constraint(equalTo: vienDo.bottomAnchor),
            cotPhai.trailingAnchor.constraint(equalTo: trailingAnchor),
            cotPhai.bottomAnchor.constraint(equalTo: bottomAnchor),
            rongCotPhai,

            // ── cột giữa, hàng 1: thanh tab
            thanhTab.topAnchor.constraint(equalTo: vienDo.bottomAnchor),
            thanhTab.leadingAnchor.constraint(equalTo: cotTrai.trailingAnchor),
            thanhTab.trailingAnchor.constraint(equalTo: cotPhai.leadingAnchor),

            // ── dải "Dữ liệu cũ": giữa thanh tab và vùng làm việc, cao 0 khi bình thường
            daiCu.topAnchor.constraint(equalTo: thanhTab.bottomAnchor),
            daiCu.leadingAnchor.constraint(equalTo: cotTrai.trailingAnchor),
            daiCu.trailingAnchor.constraint(equalTo: cotPhai.leadingAnchor),
            caoDaiCu,
            nhanCu.leadingAnchor.constraint(equalTo: daiCu.leadingAnchor, constant: 12),
            nhanCu.centerYAnchor.constraint(equalTo: daiCu.centerYAnchor),
            nutTaiLai.leadingAnchor.constraint(equalTo: nhanCu.trailingAnchor, constant: 10),
            nutTaiLai.centerYAnchor.constraint(equalTo: daiCu.centerYAnchor),

            // ── màn hình chào: TOÀN cửa sổ, nổi trên mọi vùng
            manChao.topAnchor.constraint(equalTo: topAnchor),
            manChao.leadingAnchor.constraint(equalTo: leadingAnchor),
            manChao.trailingAnchor.constraint(equalTo: trailingAnchor),
            manChao.bottomAnchor.constraint(equalTo: bottomAnchor),

            // ── bảng lệnh: phủ TOÀN cửa sổ, thêm sau cùng nên nằm trên
            bangLenh.topAnchor.constraint(equalTo: topAnchor),
            bangLenh.leadingAnchor.constraint(equalTo: leadingAnchor),
            bangLenh.trailingAnchor.constraint(equalTo: trailingAnchor),
            bangLenh.bottomAnchor.constraint(equalTo: bottomAnchor),

            // ── cột giữa, hàng 2: VÙNG LÀM VIỆC — vùng giãn
            vungLamViec.topAnchor.constraint(equalTo: daiCu.bottomAnchor),
            vungLamViec.leadingAnchor.constraint(equalTo: cotTrai.trailingAnchor),
            vungLamViec.trailingAnchor.constraint(equalTo: cotPhai.leadingAnchor),
            vungLamViec.bottomAnchor.constraint(equalTo: vachDock.topAnchor),
            // SÀN đặt ở đây, trên một khung nhìn KHÔNG nằm trong stack nào — xem ghi chú lớp.
            vungLamViec.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            vachDock.leadingAnchor.constraint(equalTo: cotTrai.trailingAnchor),
            vachDock.trailingAnchor.constraint(equalTo: cotPhai.leadingAnchor),
            vachDock.bottomAnchor.constraint(equalTo: dock.topAnchor),
            vachDock.heightAnchor.constraint(equalToConstant: 1),

            // ── cột giữa, hàng 3: DOCK — chiều cao do `dock` tự giữ (48/220/320)
            dock.leadingAnchor.constraint(equalTo: cotTrai.trailingAnchor),
            dock.trailingAnchor.constraint(equalTo: cotPhai.leadingAnchor),
            dock.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Cột phải hẹp hay đầy đủ — §2.2.
    public func datCotPhaiHep(_ h: Bool) {
        guard h != cotPhai.hep || rongCotPhai.constant != (h ? Self.RONG_COT_PHAI_HEP
                                                             : Self.RONG_COT_PHAI) else { return }
        cotPhai.datHep(h)
        rongCotPhai.constant = h ? Self.RONG_COT_PHAI_HEP : Self.RONG_COT_PHAI
    }

    /// Tự thu cột phải khi cửa sổ chạm ngưỡng — §2.2.
    ///
    /// Trong `layout()` chứ không nghe `NSWindow.didResizeNotification`: khung nhìn này còn được
    /// dựng NGOÀI cửa sổ (bài kiểm, `--chup`), và một luật bố cục chỉ chạy khi có cửa sổ là một
    /// luật không bài nào đo được.
    public override func layout() {
        super.layout()
        if hepTay == nil { datCotPhaiHep(frame.width <= Self.NGUONG_HEP) }
    }

    /// Cùng luật, chạy TRƯỚC lượt bố cục.
    ///
    /// Chỉ đặt trong `layout()` thì không đủ: đổi hằng của một ràng buộc TRONG lượt bố cục chỉ
    /// đánh dấu cần bố cục lại, nên bề ngang cột vẫn là con số cũ cho tới lượt sau. Đo bằng
    /// `--tu-kiem` 17b trên cửa sổ thật: `hep` đã `true` mà cột vẫn 236 pt.
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if hepTay == nil { datCotPhaiHep(newSize.width <= Self.NGUONG_HEP) }
    }

    /// Người bấm nút gấp. Từ đây bề ngang cửa sổ thôi quyết định thay họ.
    func nguoiDoiCotPhai(_ h: Bool) {
        hepTay = h
        datCotPhaiHep(h)
    }

    /// Bật/tắt dải "Dữ liệu cũ" — B6. Nói rõ CŨ BAO LÂU: người cần con số ấy để quyết có tin
    /// những gì màn hình đang hiện hay không.
    public func datDuLieuCu(_ cu: Bool, tre: TimeInterval) {
        daiCu.isHidden = !cu
        caoDaiCu.constant = cu ? 28 : 0
        nutTaiLai.isHidden = !cu
        nhanCu.stringValue = cu
            ? "Dữ liệu cũ — không nghe được daemon \(Int(tre)) giây qua."
            : ""
    }

    /// Dải "Dữ liệu cũ" vì **NHẢY QUÃNG `seq`** — UXC-31 §7.2, khác hẳn mất daemon.
    ///
    /// Mất daemon là "không nghe thấy gì"; nhảy quãng là "nghe thấy, nhưng thiếu mất mấy bản
    /// ghi ở giữa" — và cái thứ hai nguy hơn, vì màn hình vẫn đang cập nhật nên trông như đang
    /// đúng. Hai câu phải khác nhau, nếu không thì người dùng học được đúng một phản xạ cho hai
    /// tình huống cần hai phản xạ.
    public func datNhayQuang(_ tu: Int, _ den: Int) {
        daiCu.isHidden = false
        caoDaiCu.constant = 28
        nutTaiLai.isHidden = false
        nhanCu.stringValue = "Dữ liệu cũ — thiếu \(den - tu - 1) bản ghi sổ cái "
                           + "(seq \(tu + 1)…\(den - 1)). Màn đang hiện một trạng thái chưa đủ."
    }

    /// Chữ đang hiện trong dải "Dữ liệu cũ" — cho bài kiểm đọc.
    public var chuDaiCu: String { daiCu.isHidden ? "" : nhanCu.stringValue }

    /// Ẩn màn hình chào khi đã có dự án. Bốn vùng kia lộ ra nguyên vẹn phía dưới.
    public func anManChao() { manChao.isHidden = true }

    /// Đang ở trạng thái chưa có dự án hay không — cho bài kiểm đọc.
    public var dangChao: Bool { !manChao.isHidden }
}
