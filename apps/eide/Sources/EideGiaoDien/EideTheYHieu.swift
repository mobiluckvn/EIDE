import AppKit
import EideLoi

/// **Thẻ "Ý hiểu"** — UXC-31 §2D.6.
///
/// Câu tác tử nói lại trước khi làm, kèm danh sách bước dự kiến. Đây là chỗ duy nhất người dùng
/// bắt được một lệnh bị hiểu SAI trước khi nó ghi tệp — và `chat.restate` (CHAT-05) cố ý dựng
/// câu bằng mẫu cố định chứ không nhờ mô hình diễn đạt, vì một câu văn mượt hơn mà lệch khỏi
/// chuỗi thật thì nó xác nhận nhầm thứ.
///
/// ## Hai nút, và khi nào chúng KHÔNG hiện
///
/// §2D.6 đòi hai nút "Đúng — làm đi" / "Sửa ý hiểu" ở mức A1. Hai nút ấy chỉ có nghĩa nếu chuỗi
/// đang ĐỢI — mà orchestrator hiện không có chỗ dừng nào giữa "dựng xong chuỗi" và "chạy bước
/// đầu tiên" ([DEV-140]). Nên thẻ này nhận `cho: Bool`: đợi thật thì hiện nút, không đợi thì
/// **nói ra mình không đợi** thay vì hiện hai nút bấm vào không đảo được gì.
///
/// Một nút "Đúng — làm đi" đặt trên một việc đã làm xong là thứ tệ hơn không có nút: người dùng
/// học được rằng bấm hay không bấm đều thế, rồi họ thôi đọc cả thẻ.
@MainActor
public final class EideTheYHieu: NSView {

    public var onDuyet: (() -> Void)?
    public var onSua: (() -> Void)?

    /// Nhãn các nút đang hiện — cho bài đo đọc.
    public private(set) var nhanNut: [String] = []

    public init(van: String, buoc: [String], muc: String?, cho: Bool) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.infoBg.cgColor
        layer?.cornerRadius = 9
        layer?.borderWidth = 1
        layer?.borderColor = EideToken.Mau.info.cgColor

        let tieu = NSTextField(labelWithString: "Ý HIỂU  ·  chat.restate")
        tieu.font = NSFont.boldSystemFont(ofSize: 10)
        tieu.textColor = EideToken.Mau.info

        let cau = NSTextField(wrappingLabelWithString:
            van.isEmpty ? "`chat.restate` không trả câu nào." : van)
        cau.font = NSFont.boldSystemFont(ofSize: 12.5)

        var hang: [NSView] = [tieu, cau]

        // Danh sách bước ĐÁNH SỐ. Một danh sách gạch đầu dòng không nói được "bước 3 trên 7", mà
        // độ dài của chuỗi chính là thứ người đọc cân nhắc trước khi gật đầu.
        if buoc.isEmpty {
            hang.append(_phu("Chưa đọc được danh sách bước dự kiến."))
        } else {
            for (i, b) in buoc.enumerated() {
                hang.append(_phu("\(i + 1). `\(b)`"))
            }
        }

        if cho {
            let ok = NSButton(title: "Đúng — làm đi", target: self, action: #selector(_duyet))
            ok.bezelStyle = .rounded
            ok.font = NSFont.boldSystemFont(ofSize: 12)
            let sua = NSButton(title: "Sửa ý hiểu", target: self, action: #selector(_sua))
            sua.bezelStyle = .inline
            sua.font = EideToken.fontUI
            nhanNut = [ok.title, sua.title]
            let n = NSStackView(views: [ok, sua])
            n.orientation = .horizontal
            n.spacing = 8
            hang.append(n)
        } else {
            hang.append(_phu(Self.viSaoKhongHoi(muc)))
        }

        let coc = NSStackView(views: hang)
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 3
        coc.setCustomSpacing(6, after: cau)
        coc.edgeInsets = NSEdgeInsets(top: 8, left: 11, bottom: 9, right: 11)
        coc.translatesAutoresizingMaskIntoConstraints = false
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

    /// Vì sao thẻ không hỏi lại — và câu trả lời KHÁC NHAU theo mức tự chủ.
    ///
    /// Ở A2–A3 thì đúng hợp đồng: §2D.6 viết "mức A2–A3 tự chạy nhưng vẫn in ý hiểu". Ở A0–A1
    /// thì đó là một thiếu sót có thật của tầng dưới, và nói ra nó là việc của thẻ này.
    public static func viSaoKhongHoi(_ muc: String?) -> String {
        let m = muc ?? "?"
        if m == "A0" || m == "A1" {
            return "Mức \(m) — theo §2D.6 anh phải gật đầu trước. Orchestrator hiện chưa có chỗ "
                 + "dừng giữa \"dựng xong chuỗi\" và \"chạy bước đầu\", nên chuỗi đã được giao "
                 + "đi; các cổng chính sách vẫn chặn từng bước. Xem DEVIATIONS DEV-140."
        }
        return "Mức \(m) — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn."
    }

    private func _phu(_ s: String) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.muted
        return n
    }

    @objc private func _duyet() { onDuyet?() }
    @objc private func _sua() { onSua?() }
}
