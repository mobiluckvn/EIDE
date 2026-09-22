import AppKit
import EideLoi

/// **Thẻ HỎI–ĐÁP trong vùng trao đổi** — [DEV-181]. UXC-31 §2D, §8 S9.
///
/// ## Nguyên tắc chủ sản phẩm chốt 22/09/2026
///
/// *"Tất cả các trao đổi đều phải thực hiện ở vùng trao đổi. Agent hỏi gì thì phải hiển thị ở
/// vùng trao đổi thì tôi mới biết trả lời chứ?"*
///
/// Vùng trao đổi là **cuộc trò chuyện** — hỏi và trả lời. Tab Làm rõ yêu cầu là **sổ ghi** —
/// còn treo những gì. Cùng một câu hỏi xuất hiện ở cả hai chỗ; trả lời ở đâu cũng được.
///
/// [DEV-160] đưa câu hỏi sang tab vì lý do đúng — bong bóng chat TRÔI mất sau vài lượt gõ.
/// Nhưng kết luận khi ấy sai: đáng lẽ là CẢ HAI. Đo 22/09/2026, chủ sản phẩm gặp đúng hậu quả:
/// tác tử dừng, vùng trao đổi in "Dừng ở `env.check` — cần anh cho biết: isa", và câu hỏi tiếp
/// theo của họ là *"Tôi cần tìm chỗ nào để trả lời?"*.
///
/// ## Một thẻ, hai loại việc
///
/// Với người dùng, "thiếu tham số" và "cổng chặn cần phê duyệt" đều là **tác tử đang hỏi tôi**.
/// Tách thành hai thứ khác nhau trên màn hình là bắt họ học một phân loại của hệ thống. Nên
/// cùng một thẻ:
///
/// * `.thieuThamSo` — mỗi trường một câu hỏi tiếng Việt, kèm lựa chọn khi EIDE biết tập giá trị
/// * `.congChan`    — nút Duyệt / Từ chối kèm ô ghi lý do
///
/// ## Vì sao lựa chọn là NÚT, không phải gợi ý trong câu chữ
///
/// `isa` có đúng ba giá trị hợp lệ, đọc từ `docs/spec/isa/`. Viết chúng vào câu văn thì người
/// dùng vẫn phải gõ lại đúng chính tả; làm thành nút thì họ bấm. Ô gõ tự do vẫn còn, vì tập
/// đóng của hôm nay có thể thiếu thứ họ cần — nhưng nó không còn là đường DUY NHẤT.
@MainActor
public final class EideTheHoi: NSView {

    public enum Loai {
        /// Nút chuỗi thiếu dữ kiện. `truong` = các tham số đang hỏi.
        case thieuThamSo(clarId: String, truong: [Truong])
        /// Cổng chính sách chặn, cần người quyết. `khoa` = `<run_id>:<gate>` của [DEV-176].
        case congChan(khoa: String, cong: String, quyTac: String, lyDo: String)
        /// Một việc người phải bấm mới xong — [DEV-184]. Không phải cổng, không phải câu hỏi:
        /// sản phẩm đã biết chính xác phải làm gì, chỉ cần người đồng ý cho làm.
        case canLam(nhan: String, viec: String, moTa: String)
    }

    public struct Truong {
        public let khoa: String
        public let hoi: String
        public let luaChon: [(giaTri: String, giaiThich: String)]
        public init(khoa: String, hoi: String, luaChon: [(giaTri: String, giaiThich: String)]) {
            self.khoa = khoa; self.hoi = hoi; self.luaChon = luaChon
        }
    }

    /// (mã điểm cần làm rõ, câu trả lời) — người gõ hoặc chọn xong bấm Trả lời.
    public var onTraLoi: ((String, String) -> Void)?
    /// (khoá cổng, duyệt hay không, lý do) — [DEV-176] `gate.decide`.
    public var onQuyet: ((String, Bool, String) -> Void)?
    /// Người bấm nút của `.canLam` — [DEV-184].
    public var onLam: (() -> Void)?

    /// Nhãn các nút đang hiện — cho bài đo đọc, cùng khuôn `EideTheYHieu`.
    public private(set) var nhanNut: [String] = []

    private let o = NSTextField()
    private var daChon: [String: String] = [:]
    private let loai: Loai

    public init(cap: String, loai: Loai) {
        self.loai = loai
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.warnBg.cgColor
        layer?.cornerRadius = 9
        layer?.borderWidth = 1
        layer?.borderColor = EideToken.Mau.warn.cgColor

        let tieu = NSTextField(labelWithString: "TÁC TỬ HỎI  ·  \(cap)")
        tieu.font = NSFont.boldSystemFont(ofSize: 10)
        tieu.textColor = EideToken.Mau.warn
        var hang: [NSView] = [tieu]

        switch loai {
        case let .thieuThamSo(_, truong):
            for t in truong {
                let c = NSTextField(wrappingLabelWithString: t.hoi)
                c.font = NSFont.boldSystemFont(ofSize: 12.5)
                hang.append(c)
                for lc in t.luaChon {
                    let b = NSButton(radioButtonWithTitle:
                        lc.giaTri + (lc.giaiThich.isEmpty ? "" : "   — \(lc.giaiThich)"),
                        target: self, action: #selector(_chon(_:)))
                    b.identifier = NSUserInterfaceItemIdentifier("\(t.khoa)|\(lc.giaTri)")
                    b.font = EideToken.fontUI
                    hang.append(b)
                }
            }
            o.placeholderString = truong.count == 1
                ? "…hoặc gõ câu trả lời khác"
                : "…hoặc gõ câu trả lời cho các mục trên"
            o.font = EideToken.fontUI
            let nut = NSButton(title: "Trả lời", target: self, action: #selector(_guiTraLoi))
            nut.bezelStyle = .rounded
            nut.font = NSFont.boldSystemFont(ofSize: 12)
            nhanNut = [nut.title]
            let d = NSStackView(views: [o, nut])
            d.orientation = .horizontal
            d.spacing = 8
            o.setContentHuggingPriority(.defaultLow, for: .horizontal)
            hang.append(d)

        case let .congChan(_, cong, quyTac, lyDo):
            let c = NSTextField(wrappingLabelWithString:
                "Cổng \(cong) (\(quyTac)) chặn: \(lyDo)")
            c.font = NSFont.boldSystemFont(ofSize: 12.5)
            hang.append(c)
            hang.append(_phu("Anh duyệt thì tác tử chạy tiếp; từ chối thì nó lập lại kế hoạch."))
            o.placeholderString = "lý do (ghi vào sổ quyết định)"
            o.font = EideToken.fontUI
            let ok = NSButton(title: "Duyệt", target: self, action: #selector(_duyet))
            ok.bezelStyle = .rounded
            ok.font = NSFont.boldSystemFont(ofSize: 12)
            let khong = NSButton(title: "Từ chối", target: self, action: #selector(_tuChoi))
            khong.bezelStyle = .inline
            khong.font = EideToken.fontUI
            nhanNut = [ok.title, khong.title]
            let d = NSStackView(views: [o, ok, khong])
            d.orientation = .horizontal
            d.spacing = 8
            o.setContentHuggingPriority(.defaultLow, for: .horizontal)
            hang.append(d)

        case let .canLam(nhan, viec, moTa):
            let c = NSTextField(wrappingLabelWithString: viec)
            c.font = NSFont.boldSystemFont(ofSize: 12.5)
            hang.append(c)
            hang.append(_phu(moTa))
            let nut = NSButton(title: nhan, target: self, action: #selector(_lam))
            nut.bezelStyle = .rounded
            nut.font = NSFont.boldSystemFont(ofSize: 12)
            nhanNut = [nhan]
            hang.append(nut)
        }

        let coc = NSStackView(views: hang)
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 4
        coc.edgeInsets = NSEdgeInsets(top: 8, left: 11, bottom: 9, right: 11)
        coc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coc)
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: topAnchor),
            coc.leadingAnchor.constraint(equalTo: leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: trailingAnchor),
            coc.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        // `.canLam` không có ô gõ, nên `o` không nằm trong cây khung nhìn — ràng buộc lên một
        // view chưa có superview là một lỗi lúc chạy, không phải một cảnh báo.
        if o.superview != nil {
            o.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Câu trả lời gộp từ nút đã bấm và ô gõ.
    ///
    /// Ô gõ ĐỨNG SAU và không ghi đè: người chọn `armv7e-m` rồi gõ thêm "bo Nucleo-F411RE" là
    /// đang bổ sung, không phải đổi ý. Gộp giữ cả hai; ghi đè thì mất một nửa ý họ.
    public func cauTraLoi() -> String {
        let chon = daChon.map { "\($0.key): \($0.value)" }.sorted()
        let go = o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return ([chon.joined(separator: "; "), go].filter { !$0.isEmpty }).joined(separator: " · ")
    }

    @objc private func _chon(_ n: NSButton) {
        guard let id = n.identifier?.rawValue else { return }
        let p = id.split(separator: "|", maxSplits: 1).map(String.init)
        guard p.count == 2 else { return }
        daChon[p[0]] = p[1]
        // Radio của AppKit chỉ tự loại trừ nhau khi CÙNG superview và cùng action; ở đây mỗi
        // trường có nhóm riêng nên phải tự tắt các nút cùng trường.
        for v in (n.superview?.subviews ?? []) {
            if let b = v as? NSButton, b !== n,
               b.identifier?.rawValue.hasPrefix(p[0] + "|") == true {
                b.state = .off
            }
        }
    }

    @objc private func _guiTraLoi() {
        guard case let .thieuThamSo(clarId, _) = loai else { return }
        let v = cauTraLoi()
        guard !v.isEmpty else { return }      // không gửi câu rỗng: nó ghi một dòng vô nghĩa
        onTraLoi?(clarId, v)
    }

    @objc private func _lam() { onLam?() }

    @objc private func _duyet() { _quyet(true) }
    @objc private func _tuChoi() { _quyet(false) }

    private func _quyet(_ thuan: Bool) {
        guard case let .congChan(khoa, _, _, _) = loai else { return }
        onQuyet?(khoa, thuan, o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func _phu(_ s: String) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.muted
        return n
    }
}
