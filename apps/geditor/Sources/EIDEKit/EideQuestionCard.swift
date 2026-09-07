import AppKit

/// Thẻ câu hỏi gộp — UXD-13 U3 và §4 (QuestionCard).
///
/// U3: *"Một câu hỏi, có mặc định, có đếm ngược"*. §4: *"Viền vàng; câu hỏi; phương án đánh số
/// (nút; mặc định tô đậm); đếm ngược mm:ss; nhãn `ghi nhớ: <key>`; gõ số 1–9 để chọn"*.
/// Nguồn: sự kiện `event.chat.question` → `chat.answer`; hết giờ → mặc định.
///
/// **Đếm ngược không phải trang trí.** DPS-09 D3 nói: *"im lặng quá T ⇒ chọn mặc định và báo"*.
/// Nghĩa là thẻ này sẽ TỰ QUYẾT khi hết giờ, nên nó phải cho người thấy còn bao lâu và mặc định
/// là gì — một quyết định tự động mà người không kịp thấy nó sắp xảy ra thì không khác gì tác tử
/// tự làm không hỏi.
public final class QuestionCard: NSView {

    public struct PhuongAn {
        public let nhan: String
        public let giaTri: String
        public init(nhan: String, giaTri: String) { self.nhan = nhan; self.giaTri = giaTri }
    }

    /// (giá trị đã chọn, có phải do hết giờ không). Cờ thứ hai đi vào `chat.answer` để nhật ký
    /// phân biệt "người chọn" với "hết giờ lấy mặc định" — hai chuyện rất khác nhau khi sau này
    /// có ai hỏi vì sao lại làm thế.
    public var onTraLoi: ((String, Bool) -> Void)?

    private let cauHoi: String
    private let phuongAn: [PhuongAn]
    private let macDinh: Int
    private let ghiNho: String?
    private var conLai: Int
    private var dongHo: Timer?
    private var daTraLoi = false

    private let nhanDem = NSTextField(labelWithString: "")
    private var nut: [NSButton] = []

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }

    public init(cauHoi: String, phuongAn: [PhuongAn], macDinh: Int = 0,
                timeoutS: Int = 120, ghiNho: String? = nil) {
        self.cauHoi = cauHoi
        // §4 nói "gõ số 1–9 để chọn", nên quá 9 phương án là một thẻ không dùng hết được bằng
        // bàn phím. Cắt ở đây và nói ra, thay vì dựng một thẻ có nút thứ 10 không phím nào tới.
        self.phuongAn = Array(phuongAn.prefix(9))
        self.macDinh = max(0, min(phuongAn.count - 1, macDinh))
        self.ghiNho = ghiNho
        self.conLai = timeoutS
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.warnBg.cgColor
        layer?.borderColor = EideToken.Mau.accent.cgColor      // §4 "viền vàng"
        layer?.borderWidth = 2
        layer?.cornerRadius = EideToken.radius[1]

        let coc = NSStackView()
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = EideToken.space[1]
        coc.edgeInsets = NSEdgeInsets(top: EideToken.space[2], left: EideToken.space[2],
                                      bottom: EideToken.space[2], right: EideToken.space[2])

        let hoi = NSTextField(wrappingLabelWithString: cauHoi)
        hoi.font = NSFont.boldSystemFont(ofSize: 13)
        hoi.textColor = EideToken.Mau.text
        coc.addArrangedSubview(hoi)

        for (i, pa) in self.phuongAn.enumerated() {
            let b = NSButton(title: "\(i + 1). \(pa.nhan)", target: self, action: #selector(bam(_:)))
            b.tag = i
            b.bezelStyle = .rounded
            // §4 "mặc định tô đậm". Không dựa vào một mình kiểu chữ: U10 đòi "không dựa vào màu
            // đơn lẻ", và cùng lý lẽ ấy áp cho độ đậm — nên mặc định còn mang chữ trong nhãn
            // trợ năng và một dấu "•" nhìn thấy được.
            b.font = i == self.macDinh ? NSFont.boldSystemFont(ofSize: 13) : EideToken.fontUI
            if i == self.macDinh { b.title += "  • mặc định" }
            b.keyEquivalent = "\(i + 1)"
            b.setAccessibilityLabel("Phương án \(i + 1): \(pa.nhan)"
                                    + (i == self.macDinh ? ". Đây là mặc định." : ""))
            nut.append(b)
            coc.addArrangedSubview(b)
        }

        let hang = NSStackView()
        hang.orientation = .horizontal
        hang.spacing = EideToken.space[2]
        nhanDem.font = EideToken.fontMono
        nhanDem.textColor = EideToken.Mau.warn
        hang.addArrangedSubview(nhanDem)
        if let k = ghiNho {
            let g = NSTextField(labelWithString: "ghi nhớ: \(k)")
            g.font = EideToken.fontUI
            g.textColor = EideToken.Mau.muted
            g.setAccessibilityLabel("Lựa chọn sẽ được ghi nhớ vào tùy chọn \(k)")
            hang.addArrangedSubview(g)
        }
        coc.addArrangedSubview(hang)

        coc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coc)
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: topAnchor),
            coc.leadingAnchor.constraint(equalTo: leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: trailingAnchor),
            coc.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityLabel("Câu hỏi cần trả lời: \(cauHoi)")
        veDem()
        batDem()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit { dongHo?.invalidate() }

    // MARK: - đếm ngược

    /// Định dạng mm:ss theo §4. Tách thành hàm để test được mà không cần dựng cả thẻ.
    public static func mmss(_ giay: Int) -> String {
        let g = max(0, giay)
        return String(format: "%02d:%02d", g / 60, g % 60)
    }

    private func batDem() {
        guard conLai > 0 else { return }
        dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            s.conLai -= 1
            s.veDem()
            if s.conLai <= 0 { s.hetGio() }
        }
    }

    private func veDem() {
        nhanDem.stringValue = "còn " + Self.mmss(conLai)
        nhanDem.setAccessibilityLabel("Còn \(conLai) giây trước khi chọn mặc định")
    }

    private func hetGio() {
        dongHo?.invalidate()
        tra(macDinh, doHetGio: true)
    }

    // MARK: - trả lời

    @objc private func bam(_ s: NSButton) { tra(s.tag, doHetGio: false) }

    private func tra(_ i: Int, doHetGio: Bool) {
        // Một thẻ chỉ trả lời MỘT lần: người bấm đúng lúc đồng hồ về 0 sẽ gửi hai câu trả lời
        // cho cùng một question_id, và bên kia không có cách nào biết cái nào là thật.
        guard !daTraLoi, i < phuongAn.count else { return }
        daTraLoi = true
        dongHo?.invalidate()
        for b in nut { b.isEnabled = false }
        nhanDem.stringValue = doHetGio ? "hết giờ — đã chọn mặc định" : "đã chọn"
        onTraLoi?(phuongAn[i].giaTri, doHetGio)
    }

    /// Cho test: chạy đồng hồ tới 0 mà không phải chờ thật.
    public func chayHetGioNgay() { conLai = 1; hetGio() }
}
