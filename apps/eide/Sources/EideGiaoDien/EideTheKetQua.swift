import AppKit
import EideLoi

/// **Thẻ "Kết quả từng bước"** — mỗi bước một dòng bấm mở ra được.
///
/// ## Vì sao thẻ này tồn tại
///
/// Chủ sản phẩm chạy thử một lượt sáu bước rồi nói nguyên văn: *"Đã chạy xong 6/6 việc và thứ
/// tôi nhận được là một thông báo. Tôi cần việc 1 là việc gì, output là gì. Việc 2 là gì, output
/// là gì — tôi cần phải xem được nó."*
///
/// Trước đó vùng trao đổi chỉ có `Đã làm 6 việc: project.open, view.timeline, chat.parse_intent…`
/// — một danh sách TÊN NĂNG LỰC. Nó nói máy đã chạy gì, không nói máy đã làm ra gì. Và đầu ra
/// mỗi bước thì bị vứt đi ngay sau khi giải tham chiếu xong: sổ cái chỉ giữ `result_hash`, một
/// mã băm. Sản phẩm làm ra kết quả rồi quên chúng trong cùng một nhịp.
///
/// ## Mở SẴN, không gập lại
///
/// Một thẻ gập mặc định là một thẻ không ai mở: người dùng vừa đọc "xong 6/6" và không có lý do
/// nào để nghi ngờ, nên họ đi tiếp. Mà nghi ngờ đúng lúc ấy chính là thứ sản phẩm này cần —
/// UXC-31 §2D.6 dựng cả thẻ Ý hiểu cho một việc y hệt. Nên mỗi bước hiện sẵn phần TÓM TẮT (số
/// lượng và mã), và nút mở ra chỉ dành cho phần đầy đủ.
@MainActor
public final class EideTheKetQua: NSView {

    /// Số bước đang hiện — cho bài đo đọc.
    public private(set) var soBuoc = 0
    /// Chữ của từng dòng tóm tắt — cho bài đo đọc.
    public private(set) var dongTomTat: [String] = []

    private let coc = NSStackView()

    public init(buoc: [[String: Any]]) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.cornerRadius = 9
        layer?.borderWidth = 1
        layer?.borderColor = EideToken.Mau.border2.cgColor

        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 5
        coc.edgeInsets = NSEdgeInsets(top: 9, left: 11, bottom: 10, right: 11)
        coc.translatesAutoresizingMaskIntoConstraints = false

        let tieu = NSTextField(labelWithString: "KẾT QUẢ TỪNG BƯỚC")
        tieu.font = NSFont.boldSystemFont(ofSize: 10)
        tieu.textColor = EideToken.Mau.muted
        coc.addArrangedSubview(tieu)

        soBuoc = buoc.count
        if buoc.isEmpty {
            coc.addArrangedSubview(_phu("Lượt này chưa bước nào chạy xong."))
        }
        for b in buoc {
            let i = EideManHoChieu.nguyen(b["i"]) ?? 0
            let cap = (b["cap"] as? String) ?? "?"
            let tom = Self.tomTat(b["ra"] as? [String: Any] ?? [:])
            let dong = "\(i). `\(cap)` — \(tom)"
            dongTomTat.append(dong)

            let nhan = NSTextField(wrappingLabelWithString: dong)
            nhan.font = EideToken.fontUI
            coc.addArrangedSubview(nhan)

            // Phần ĐẦY ĐỦ nằm sau một nút, vì nó có thể dài hàng trăm dòng và dán thẳng vào
            // vùng trao đổi sẽ đẩy mọi thứ khác ra khỏi tầm mắt.
            let day = Self.dayDu(b["dau_ra"] as? [String: Any] ?? [:])
            if !day.isEmpty {
                // `NSTextField(wrappingLabelWithString:)`, KHÔNG `NSTextView`.
                //
                // `NSTextView` trần trong một `NSStackView` không có chiều cao nội tại: nó cần
                // một `NSScrollView` bọc ngoài hoặc một hệ chữ dựng tay. Bản trước bật
                // `isHidden = false` cho một khung nhìn cao 0 pt — chủ sản phẩm bấm "Xem đầy
                // đủ" và thấy "trắng trơn", đúng nghĩa: khung nhìn CÓ hiện, chỉ là không cao.
                //
                // Nhãn bọc dòng thì tự đo chiều cao theo nội dung, và đây là chỗ CHỈ ĐỌC nên
                // không mất gì khi bỏ `NSTextView`.
                let o = NSTextField(wrappingLabelWithString: day)
                o.font = EideToken.fontMono
                o.isSelectable = true          // người đọc phải copy được đầu ra ra ngoài
                o.isHidden = true

                let nut = NSButton(title: "Xem đầy đủ ▾", target: self,
                                   action: #selector(_moRa(_:)))
                nut.bezelStyle = .inline
                nut.font = EideToken.fontUI
                nut.tag = coc.arrangedSubviews.count + 1   // vị trí của `o` sau khi thêm nút
                coc.addArrangedSubview(nut)
                coc.addArrangedSubview(o)
            }
        }

        addSubview(coc)
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: topAnchor),
            coc.leadingAnchor.constraint(equalTo: leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: trailingAnchor),
            coc.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Tóm tắt một đầu ra thành một câu — số lượng và MÃ, không diễn giải.
    ///
    /// Mã (`UR-CNC-01`) là thứ người đối chiếu được với bảng ở màn Yêu cầu & kiến trúc; một câu
    /// văn mô tả thì phải tin chứ không kiểm được.
    public static func tomTat(_ ra: [String: Any]) -> String {
        var phan: [String] = []
        for (k, v) in ra.sorted(by: { $0.key < $1.key }) where !k.hasSuffix("_ma") {
            let ma = ra["\(k)_ma"] as? [Any]
            let đuôi = ma.map { " (" + $0.prefix(4).map { "\($0)" }.joined(separator: ", ")
                                + ($0.count > 4 ? "…" : "") + ")" } ?? ""
            phan.append("\(v) \(k)\(đuôi)")
        }
        return phan.isEmpty ? "không trả về gì" : phan.joined(separator: " · ")
    }

    /// Đầu ra đầy đủ, dạng đọc được. Đầu ra BỊ CẮT thì nói ra, không im.
    public static func dayDu(_ dauRa: [String: Any]) -> String {
        guard !dauRa.isEmpty else { return "" }
        if (dauRa["_cat"] as? Bool) == true {
            return "⚠ " + ((dauRa["_vi"] as? String) ?? "đầu ra đã bị cắt bớt")
        }
        guard let d = try? JSONSerialization.data(withJSONObject: dauRa,
                                                  options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: d, encoding: .utf8) else { return "" }
        return s
    }

    @objc private func _moRa(_ n: NSButton) {
        guard n.tag < coc.arrangedSubviews.count else { return }
        let o = coc.arrangedSubviews[n.tag]
        o.isHidden.toggle()
        n.title = o.isHidden ? "Xem đầy đủ ▾" : "Thu lại ▴"
        // Ép bố cục lại NGAY: `isHidden` trên một phần tử của `NSStackView` chỉ đổi bố cục ở
        // vòng vẽ kế tiếp, và bài kiểm đọc chiều cao ngay sau khi bấm sẽ thấy nó chưa đổi.
        window?.layoutIfNeeded()
    }

    /// Phần đầy đủ của bước `i` (1-based) đang HIỆN không, và cao bao nhiêu — cho bài đo.
    ///
    /// Trả cả chiều cao vì đó chính là chỗ bản trước hỏng: khung nhìn có `isHidden == false`
    /// mà cao 0 pt thì người dùng thấy "trắng trơn", và một phép đo chỉ hỏi `isHidden` sẽ báo
    /// ĐẠT.
    public func phanDayDu(_ i: Int) -> (hien: Bool, cao: CGFloat)? {
        let nhan = coc.arrangedSubviews.compactMap { $0 as? NSTextField }
            .filter { $0.font == EideToken.fontMono }
        guard i >= 1, i <= nhan.count else { return nil }
        let v = nhan[i - 1]
        return (!v.isHidden, v.fittingSize.height)
    }

    private func _phu(_ s: String) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.muted
        return n
    }
}
