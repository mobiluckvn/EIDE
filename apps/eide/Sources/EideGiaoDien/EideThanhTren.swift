import AppKit
import EideLoi

/// **Thanh trên** — `#topbar`, UXC-31 §2A. Đúng thứ tự trái → phải, không thêm bớt.
public final class EideThanhTren: NSView {

    public var onDuAn: (() -> Void)?
    public var onBangLenh: (() -> Void)?
    public var onDungKhan: (() -> Void)?
    /// Bấm một bộ đếm → cuộn tới khối tương ứng ở cột phải (§2A.4/2A.5), không mở màn mới.
    public var onDemCho: (() -> Void)?
    public var onDemHoanTac: (() -> Void)?
    /// Bấm huy hiệu mức tự chủ → mở màn S25 Chính sách tự chủ (§2A.3).
    public var onMuc: (() -> Void)?

    private let ten = NSButton()
    /// Huy hiệu mức tự chủ. **Nút chứ không nhãn** — §2A.3 đòi bấm được, và "A0" là con số
    /// người muốn đổi ngay khi nhìn thấy nó. Một huy hiệu đỏ không bấm được buộc họ đi tìm màn
    /// Chính sách trong cột trái, đúng lúc đang vội.
    private let muc = NSButton()
    private let demCho = NSButton()
    private let demHoanTac = NSButton()
    private let nutDung = NSButton()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor

        let logo = NSTextField(labelWithString: "EIDE")
        logo.font = NSFont.boldSystemFont(ofSize: 15)
        logo.textColor = EideToken.Mau.primary

        ten.title = "— chưa mở dự án — ▾"
        ten.bezelStyle = .rounded
        ten.font = NSFont.boldSystemFont(ofSize: 13)
        ten.target = self
        ten.action = #selector(_duAn)

        muc.isBordered = false
        muc.font = NSFont.boldSystemFont(ofSize: 11)
        muc.wantsLayer = true
        muc.layer?.cornerRadius = 10
        muc.target = self
        muc.action = #selector(_muc)
        muc.toolTip = "Mở màn Chính sách tự chủ (S25)"
        datMuc("A2")

        for (b, s) in [(demCho, #selector(_cho)), (demHoanTac, #selector(_hoanTac))] {
            b.bezelStyle = .inline
            b.font = EideToken.fontUI
            b.contentTintColor = EideToken.Mau.muted
            b.target = self
            b.action = s
        }
        datDem(cho: 0, hoanTac: 0)

        let kbtn = NSButton(title: "⌘K · bảng lệnh", target: self, action: #selector(_bangLenh))
        kbtn.bezelStyle = .inline
        kbtn.font = EideToken.fontUI
        kbtn.contentTintColor = EideToken.Mau.faint

        nutDung.title = "■ Dừng khẩn"
        nutDung.bezelStyle = .rounded
        nutDung.font = NSFont.boldSystemFont(ofSize: 12)
        nutDung.contentTintColor = EideToken.Mau.primary
        nutDung.target = self
        nutDung.action = #selector(_dung)

        let dem = NSView()
        dem.setContentHuggingPriority(.init(1), for: .horizontal)
        let h = NSStackView(views: [logo, ten, muc, demCho, demHoanTac, dem, kbtn, nutDung])
        h.orientation = .horizontal
        h.alignment = .centerY
        h.spacing = 12
        h.translatesAutoresizingMaskIntoConstraints = false
        addSubview(h)
        NSLayoutConstraint.activate([
            h.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            h.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            h.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Hai giá trị cho bài đo đọc — KHÔNG phải trạng thái thứ hai: chúng đọc thẳng từ chính
    /// khung nhìn người dùng đang nhìn. Một bài kiểm đọc bản sao thì nó kiểm bản sao.
    public var tenDuAn: String { ten.title }
    public var mucHienTai: String {
        muc.attributedTitle.string.isEmpty ? muc.title : muc.attributedTitle.string
    }

    public func datDuAn(_ s: String?) {
        ten.title = (s.map { ($0 as NSString).lastPathComponent } ?? "— chưa mở dự án —") + " ▾"
    }

    /// `dung` = cờ dừng khẩn CÒN CÀI, đọc từ `autonomy.get`.
    ///
    /// Mức tự chủ và cờ dừng là HAI thứ khác nhau: dừng khẩn cắt mọi việc mà không hạ mức, nên
    /// một dự án đang đứng im hoàn toàn vẫn báo "A2". Hiện mỗi mức là nói dối bằng cách nói thật
    /// một nửa — người đọc "A2" rồi ngồi đợi tác tử làm việc mà nó sẽ không bao giờ làm.
    public func datMuc(_ m: String, dung: Bool = false) {
        let van = dung ? " ĐÃ DỪNG KHẨN · \(m) " : " Tự chủ \(m) "
        // A0 = nền ĐỎ. Mức "tác tử không tự làm gì" phải khác hẳn mọi mức khác về màu, vì nó là
        // trạng thái người vừa bấm Dừng khẩn hoặc vừa siết quyền — và cả hai đều cần thấy ngay.
        let do_ = dung || m == "A0"
        // `attributedTitle` chứ không `contentTintColor`: nút `isBordered = false` vẽ tiêu đề
        // bằng màu nhãn của hệ, và màu ấy KHÔNG đổi theo tint trên nền pill tự vẽ.
        muc.attributedTitle = NSAttributedString(string: van, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: do_ ? EideToken.Mau.primary : EideToken.Mau.info,
        ])
        muc.layer?.backgroundColor = (do_ ? EideToken.Mau.badBg : EideToken.Mau.infoBg).cgColor
        muc.setAccessibilityLabel(
            "Mức tự chủ \(m)\(dung ? ", đã dừng khẩn" : "") — bấm để mở màn Chính sách tự chủ")
    }

    public func datDem(cho: Int, hoanTac: Int) {
        demCho.title = "Chờ tôi \(cho)"
        demHoanTac.title = "Hoàn tác \(hoanTac)"
    }

    @objc private func _duAn() { onDuAn?() }
    @objc private func _bangLenh() { onBangLenh?() }
    @objc private func _dung() { onDungKhan?() }
    @objc private func _muc() { onMuc?() }
    @objc private func _cho() { onDemCho?() }
    @objc private func _hoanTac() { onDemHoanTac?() }
}
