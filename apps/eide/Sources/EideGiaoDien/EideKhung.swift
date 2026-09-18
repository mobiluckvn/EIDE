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

    public let thanhTren = EideThanhTren()
    public let cotTrai = EideDieuHuong()
    public let thanhTab = EideThanhTab()
    public let vungLamViec = EideVungLamViec()
    public let dock = EideDock()
    public let cotPhai = EideCotPhai()

    private let vienDo = NSView()
    private let vachDock = NSBox()

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

        for v in [thanhTren, vienDo, cotTrai, thanhTab, vungLamViec,
                  vachDock, dock, cotPhai] as [NSView] {
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
            cotPhai.widthAnchor.constraint(equalToConstant: Self.RONG_COT_PHAI),

            // ── cột giữa, hàng 1: thanh tab
            thanhTab.topAnchor.constraint(equalTo: vienDo.bottomAnchor),
            thanhTab.leadingAnchor.constraint(equalTo: cotTrai.trailingAnchor),
            thanhTab.trailingAnchor.constraint(equalTo: cotPhai.leadingAnchor),

            // ── cột giữa, hàng 2: VÙNG LÀM VIỆC — vùng giãn
            vungLamViec.topAnchor.constraint(equalTo: thanhTab.bottomAnchor),
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
}
