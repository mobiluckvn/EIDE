import AppKit
import EideLoi

/// **Thẻ Run** — UXC-31 §2E.3, `runCardHTML()` của bản demo.
///
/// MỘT thẻ cho MỘT lượt chạy, dù lượt ấy gồm mười sáu bước. Trước khi có nó, mỗi bước sinh một
/// bong bóng riêng và người dùng không đọc được "còn bao nhiêu bước" ở bất cứ đâu — đúng phát
/// hiện R3 của bản rà soát v2.0.
///
/// Thẻ KHÔNG hỏi lõi. Nó nhận từng sự kiện `event.run.progress` và tự cập nhật; nguồn sự thật
/// là sổ cái, thẻ chỉ là bản chiếu (B7).
public final class EideTheRun: NSView {

    public var onChiTiet: ((String) -> Void)?
    public var onDung: (() -> Void)?

    public enum TrangThai: String { case chay, chan, xong, huy }

    public let ma: String
    public private(set) var trangThai: TrangThai = .chay
    public private(set) var buoc = 0        // số bước ĐÃ XONG
    public private(set) var tong = 0
    private var nhanBuoc: [String] = []

    private let tieuDe = NSTextField(labelWithString: "")
    private let demBuoc = NSTextField(labelWithString: "")
    private let dongHienTai = NSTextField(wrappingLabelWithString: "")
    private let thanh = NSStackView()
    private let nutDung = NSButton()

    /// Cao 5 pt, bo 3 — đúng `.seg` của bản demo.
    private static let CAO_DOAN: CGFloat = 5

    public init(ma: String, van: String) {
        self.ma = ma
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = EideToken.Mau.border.cgColor

        tieuDe.font = NSFont.boldSystemFont(ofSize: 12)
        tieuDe.stringValue = van
        tieuDe.lineBreakMode = .byTruncatingTail
        // Không nhãn nào trong thẻ được ĐÒI bề rộng.
        //
        // NSWindow coi ràng buộc bắt buộc trong `contentView` là ràng buộc của CHÍNH CỬA SỔ: một
        // nhãn giữ sức chống nén mặc định (750) trên câu lệnh dài 60 ký tự đẩy cửa sổ từ 1456 pt
        // lên 2482 pt, và cửa sổ KHÔNG co lại sau đó. Đo 18/09 bằng ảnh chụp: 2912 → 4964 điểm
        // ảnh ngay khi thẻ Run đầu tiên xuất hiện. Đây đúng là cơ chế đã làm cửa sổ bản cũ nhích
        // dần 720 → 818 pt mà không ai truy ra nguyên nhân.
        for n in [tieuDe, dongHienTai] {
            n.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            n.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        demBuoc.font = EideToken.fontUI
        demBuoc.textColor = EideToken.Mau.faint
        dongHienTai.font = EideToken.fontUI
        dongHienTai.textColor = EideToken.Mau.muted

        let chiTiet = NSButton(title: "Mở chi tiết", target: self, action: #selector(_chiTiet))
        chiTiet.bezelStyle = .inline
        chiTiet.font = EideToken.fontUI
        chiTiet.contentTintColor = EideToken.Mau.info
        // "Dừng khẩn", không phải "Dừng". Không có đường huỷ RIÊNG một lượt chạy: một chuỗi
        // chuyển sang `cancelled` khi các bước của nó nhận E3002, tức khi cả PHIÊN bị dừng. Một
        // nút ghi "Dừng" trên một thẻ sẽ đọc như "dừng việc này thôi", và người bấm nó để bỏ một
        // lượt chạy lỡ tay sẽ hạ luôn mọi thứ khác đang chạy.
        nutDung.title = "Dừng khẩn"
        nutDung.toolTip = "Dừng khẩn CẢ PHIÊN — không có đường huỷ riêng một lượt chạy"
        nutDung.target = self
        nutDung.action = #selector(_dung)
        nutDung.bezelStyle = .inline
        nutDung.font = EideToken.fontUI
        nutDung.contentTintColor = EideToken.Mau.bad

        let dem = NSView()   // đẩy hai nút sang phải
        dem.setContentHuggingPriority(.init(1), for: .horizontal)
        let dau = NSStackView(views: [tieuDe, demBuoc, dem, chiTiet, nutDung])
        dau.orientation = .horizontal
        dau.spacing = 8

        thanh.orientation = .horizontal
        thanh.distribution = .fillEqually
        thanh.spacing = 3

        let coc = NSStackView(views: [dau, thanh, dongHienTai])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 7
        coc.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        coc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coc)
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: topAnchor),
            coc.leadingAnchor.constraint(equalTo: leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: trailingAnchor),
            coc.bottomAnchor.constraint(equalTo: bottomAnchor),
            dau.widthAnchor.constraint(equalTo: coc.widthAnchor, constant: -24),
            thanh.widthAnchor.constraint(equalTo: coc.widthAnchor, constant: -24),
            thanh.heightAnchor.constraint(equalToConstant: Self.CAO_DOAN),
            dongHienTai.widthAnchor.constraint(equalTo: coc.widthAnchor, constant: -24),
        ])
        _ve()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Nhận một sự kiện `event.run.progress` của CHÍNH lượt chạy này.
    ///
    /// `kind` quyết định, không phải thứ tự đến: sự kiện đi qua một ống chung với câu trả lời và
    /// một bước có thể tới sau bước kế nó. Vì thế `i` được LẤY từ sự kiện chứ không tự tăng.
    public func nhan(_ p: [String: Any]) {
        switch p["kind"] as? String {
        case "run.started":
            if let ds = p["steps"] as? [[String: Any]] {
                tong = ds.count
                nhanBuoc = ds.map { ($0["cap"] as? String) ?? "?" }
            }
            if let van = p["text"] as? String, !van.isEmpty { tieuDe.stringValue = van }
        case "run.step_started":
            trangThai = .chay
            tong = (p["of"] as? Int) ?? tong
            buoc = max(buoc, ((p["i"] as? Int) ?? buoc + 1) - 1)
            dongHienTai.stringValue = "▶ đang chạy `\(p["cap"] as? String ?? "?")`"
        case "run.step_done":
            tong = (p["of"] as? Int) ?? tong
            buoc = max(buoc, (p["i"] as? Int) ?? buoc)
            if (p["status"] as? String) == "failed" {
                dongHienTai.stringValue = "✖ `\(p["cap"] as? String ?? "?")` hỏng — xem Nhật ký"
            }
        case "run.blocked":
            trangThai = .chan
            let thieu = (p["missing"] as? [String] ?? []).joined(separator: ", ")
            dongHienTai.stringValue = "⏸ Chờ anh: \(p["reason"] as? String ?? "chưa rõ")"
                + (thieu.isEmpty ? "" : " — \(thieu)")
        case "run.done":
            trangThai = (p["state"] as? String) == "cancelled" ? .huy : .xong
            buoc = tong
            dongHienTai.stringValue = trangThai == .huy
                ? "✖ Đã huỷ" : "✅ Xong \(p["done"] as? Int ?? tong)/\(tong) bước"
        case "run.cancelled":
            trangThai = .huy
            dongHienTai.stringValue = "✖ Đã huỷ (Dừng khẩn)"
        default:
            return
        }
        _ve()
    }

    private func _ve() {
        demBuoc.stringValue = tong > 0 ? "bước \(min(buoc + 1, tong))/\(tong)" : "đang lập kế hoạch"
        nutDung.isHidden = trangThai == .xong || trangThai == .huy
        for v in thanh.arrangedSubviews { thanh.removeArrangedSubview(v); v.removeFromSuperview() }
        // Không có bước nào thì vẽ MỘT đoạn xám: một thanh tiến độ rỗng vẫn phải chiếm chỗ của
        // nó, nếu không thẻ nhảy cao thêm 5 pt ngay khi bước đầu tiên tới.
        for i in 0..<max(tong, 1) {
            let o = NSView()
            o.wantsLayer = true
            o.layer?.cornerRadius = Self.CAO_DOAN / 2
            o.layer?.backgroundColor = _mauDoan(i).cgColor
            o.translatesAutoresizingMaskIntoConstraints = false
            thanh.addArrangedSubview(o)
        }
    }

    private func _mauDoan(_ i: Int) -> NSColor { Self.mauBuoc(i, buoc: buoc, trangThai: trangThai) }

    /// Màu một đoạn của thanh tiến độ — §1.4, bốn nghĩa bốn màu.
    ///
    /// Tách ra làm hàm tĩnh để đo được: đây là chỗ cả bốn màu ngữ nghĩa cùng xuất hiện, nên cũng
    /// là chỗ một lần dùng chéo lộ ra rõ nhất.
    public static func mauBuoc(_ i: Int, buoc: Int, trangThai: TrangThai) -> NSColor {
        if i < buoc { return EideToken.Mau.ok }
        if i == buoc && trangThai == .chan { return EideToken.Mau.warn }
        if i == buoc && trangThai == .chay { return EideToken.Mau.info }
        if trangThai == .huy { return EideToken.Mau.faint }
        return EideToken.Mau.border2
    }

    @objc private func _chiTiet() { onChiTiet?(ma) }
    @objc private func _dung() { onDung?() }
}
