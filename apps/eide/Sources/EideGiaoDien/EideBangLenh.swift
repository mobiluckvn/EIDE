import AppKit
import EideLoi

/// **Bảng lệnh ⌘K** — UXC-31 §4, tiêu chí N9. Lớp phủ 560×320 giữa-trên màn.
///
/// Ba điều tài liệu nói rõ và cả ba đều là lý do nó KHÔNG phải một menu gợi ý trong ô lệnh:
///
/// 1. **Tìm theo MÔ TẢ, không chỉ theo tên.** Người dùng nhớ "cái tra thanh ghi", không nhớ
///    `passport.query`.
/// 2. **Tìm được cả MÀN.** Nửa số thứ người ta muốn mở là một màn hình, không phải một năng lực.
/// 3. **Bỏ dấu.** "ho chieu" phải ra "Hộ chiếu chip". Bắt gõ đủ dấu trong một ô tìm-nhanh là
///    biến phím tắt thành một bài kiểm tra chính tả.
public final class EideBangLenh: NSView {

    public struct Muc {
        public let ma: String          // tiền tố màn, hoặc id năng lực
        public let nhan: String
        public let mota: String
        public let laMan: Bool
        public init(ma: String, nhan: String, mota: String, laMan: Bool) {
            self.ma = ma; self.nhan = nhan; self.mota = mota; self.laMan = laMan
        }
    }

    public var onChonMan: ((String) -> Void)?
    public var onChonNangLuc: ((String) -> Void)?

    private let o = NSTextField()
    private let coc = NSStackView()
    private let dem = NSTextField(labelWithString: "")
    private var nguon: [Muc] = []
    private var loc: [Muc] = []
    private var chon = 0

    public static let RONG: CGFloat = 560
    public static let CAO: CGFloat = 320
    /// Số dòng hiện tối đa. Bảng cao 320 pt chứa được chừng này; phần bị cắt nói ra ở dòng đếm.
    public static let TOI_DA = 9

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // Nền mờ toàn màn: lớp phủ phải CẮT người dùng khỏi phần còn lại, nếu không nó chỉ là
        // một hộp nữa trong một cửa sổ đã đầy hộp.
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        isHidden = true

        let hop = NSView()
        hop.wantsLayer = true
        hop.layer?.backgroundColor = EideToken.Mau.surface.cgColor
        hop.layer?.cornerRadius = 12
        hop.layer?.borderWidth = 1
        hop.layer?.borderColor = EideToken.Mau.border2.cgColor
        hop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hop)

        o.placeholderString = "Tìm màn hoặc năng lực — gõ không dấu cũng được"
        o.font = NSFont.systemFont(ofSize: 14)
        o.delegate = self
        o.focusRingType = .none
        o.isBordered = false
        o.drawsBackground = false
        o.translatesAutoresizingMaskIntoConstraints = false

        dem.font = EideToken.fontUI
        dem.textColor = EideToken.Mau.faint
        dem.translatesAutoresizingMaskIntoConstraints = false

        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 1
        coc.translatesAutoresizingMaskIntoConstraints = false

        let vach = NSBox()
        vach.boxType = .separator
        vach.translatesAutoresizingMaskIntoConstraints = false

        for v in [o, vach, coc, dem] { hop.addSubview(v) }
        NSLayoutConstraint.activate([
            hop.centerXAnchor.constraint(equalTo: centerXAnchor),
            hop.topAnchor.constraint(equalTo: topAnchor, constant: 96),
            hop.widthAnchor.constraint(equalToConstant: Self.RONG),
            hop.heightAnchor.constraint(equalToConstant: Self.CAO),
            o.topAnchor.constraint(equalTo: hop.topAnchor, constant: 14),
            o.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 16),
            o.trailingAnchor.constraint(equalTo: hop.trailingAnchor, constant: -16),
            vach.topAnchor.constraint(equalTo: o.bottomAnchor, constant: 12),
            vach.leadingAnchor.constraint(equalTo: hop.leadingAnchor),
            vach.trailingAnchor.constraint(equalTo: hop.trailingAnchor),
            coc.topAnchor.constraint(equalTo: vach.bottomAnchor, constant: 6),
            coc.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 8),
            coc.trailingAnchor.constraint(equalTo: hop.trailingAnchor, constant: -8),
            dem.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 16),
            dem.bottomAnchor.constraint(equalTo: hop.bottomAnchor, constant: -10),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Nguồn: 25 màn + mọi năng lực đã hiện thực.
    public func datNguon(nangLuc: [(id: String, mota: String)]) {
        nguon = EideManHinhDS.tatCa.map {
            Muc(ma: $0.tien, nhan: $0.nhan, mota: "màn hình · \($0.ma)", laMan: true)
        } + nangLuc.map {
            Muc(ma: $0.id, nhan: $0.id, mota: $0.mota, laMan: false)
        }
    }

    public var soMuc: Int { nguon.count }

    public func mo() {
        isHidden = false
        o.stringValue = ""
        _loc("")
        window?.makeFirstResponder(o)
    }

    public func dong() {
        isHidden = true
        window?.makeFirstResponder(nil)
    }

    /// Bỏ dấu tiếng Việt và hạ chữ thường. `đ` KHÔNG rụng dấu qua `folding` — nó là một chữ cái
    /// riêng trong bảng chữ cái, không phải `d` có dấu — nên phải thay tay; thiếu nó thì "dong
    /// bo" không tìm ra "Đồng bộ".
    public static func bo(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
         .replacingOccurrences(of: "đ", with: "d")
         .replacingOccurrences(of: "Đ", with: "d")
         .lowercased()
    }

    /// Đường vào cho bài đo — ĐẶT chữ vào ô tìm rồi lọc, đúng như người gõ.
    ///
    /// Chỉ gọi `_loc` mà không đặt `o.stringValue` thì ảnh chụp cho thấy một bảng đầy kết quả
    /// bên dưới một ô tìm TRỐNG: một tấm ảnh nói dối về thứ vừa xảy ra.
    @discardableResult
    public func locDeTest(_ van: String) -> [Muc] {
        o.stringValue = van
        _loc(van)
        return loc
    }

    private func _loc(_ van: String) {
        let k = Self.bo(van.trimmingCharacters(in: .whitespaces))
        // Màn LÊN TRƯỚC khi điểm bằng nhau: người gõ ⌘K rồi "mo phong" muốn MỞ màn Mô phỏng,
        // không muốn gọi thẳng `sim.run`.
        loc = k.isEmpty ? nguon.filter(\.laMan)
            : nguon.filter { Self.bo($0.nhan).contains(k) || Self.bo($0.mota).contains(k)
                             || Self.bo($0.ma).contains(k) }
                   .sorted { ($0.laMan ? 0 : 1, $0.ma) < ($1.laMan ? 0 : 1, $1.ma) }
        chon = 0
        _ve()
    }

    private func _ve() {
        for v in coc.arrangedSubviews { coc.removeArrangedSubview(v); v.removeFromSuperview() }
        for (i, m) in loc.prefix(Self.TOI_DA).enumerated() {
            let n = NSTextField(labelWithString: "\(m.laMan ? "▸" : "·")  \(m.nhan)   \(m.mota)")
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.text
            n.lineBreakMode = .byTruncatingTail
            n.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let hang = NSView()
            hang.wantsLayer = true
            hang.layer?.backgroundColor = (i == chon ? EideToken.Mau.infoBg : .clear).cgColor
            hang.layer?.cornerRadius = 6
            n.translatesAutoresizingMaskIntoConstraints = false
            hang.addSubview(n)
            hang.translatesAutoresizingMaskIntoConstraints = false
            coc.addArrangedSubview(hang)
            NSLayoutConstraint.activate([
                hang.widthAnchor.constraint(equalTo: coc.widthAnchor),
                hang.heightAnchor.constraint(equalToConstant: 24),
                n.leadingAnchor.constraint(equalTo: hang.leadingAnchor, constant: 8),
                n.trailingAnchor.constraint(equalTo: hang.trailingAnchor, constant: -8),
                n.centerYAnchor.constraint(equalTo: hang.centerYAnchor),
            ])
        }
        dem.stringValue = loc.isEmpty
            ? "Không có mục nào khớp — thử một từ trong mô tả, ví dụ \"thanh ghi\"."
            : "\(loc.count) mục" + (loc.count > Self.TOI_DA ? " · hiện \(Self.TOI_DA) đầu" : "")
                + " · ↑↓ chọn · ⏎ mở · Esc đóng"
    }

    private func _dung() {
        guard chon < loc.count else { return }
        let m = loc[chon]
        dong()
        // Đi qua ĐÚNG đường mọi lời gọi khác đi (B2) — bảng lệnh không có lối tắt riêng.
        if m.laMan { onChonMan?(m.ma) } else { onChonNangLuc?(m.ma) }
    }
}

extension EideBangLenh: NSTextFieldDelegate {

    public func controlTextDidChange(_ n: Notification) { _loc(o.stringValue) }

    /// Mũi tên đi trong danh sách TRONG KHI con trỏ vẫn ở ô tìm — người không phải rời tay khỏi
    /// bàn phím để chọn, mà đó là toàn bộ lý do một bảng lệnh tồn tại.
    public func control(_ c: NSControl, textView: NSTextView,
                        doCommandBy s: Selector) -> Bool {
        switch s {
        case #selector(NSResponder.moveDown(_:)):
            chon = min(chon + 1, max(0, min(loc.count, Self.TOI_DA) - 1)); _ve(); return true
        case #selector(NSResponder.moveUp(_:)):
            chon = max(chon - 1, 0); _ve(); return true
        case #selector(NSResponder.insertNewline(_:)):
            _dung(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            dong(); return true
        default:
            return false
        }
    }
}
