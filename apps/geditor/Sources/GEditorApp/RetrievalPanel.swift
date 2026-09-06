import AppKit
import GEditorCore

/// BM25 Retrieval Lab — FR-KNW-918.
///
/// Đặc tả: *"ô nhập câu hỏi → top-k chunk kèm điểm BM25 và HIGHLIGHT từ khớp trong từng chunk;
/// tham số k1 (mặc định 1,2) và b (0,75) chỉnh được **với giải thích ý nghĩa**"*.
///
/// ## Hai núm và một câu giải thích cho mỗi núm
///
/// Chữ "với giải thích ý nghĩa" trong đặc tả không phải trang trí. `k1` và `b` là hai hằng số
/// mà gần như không ai nhớ nghĩa, và một thanh trượt không chú thích thì người dùng kéo bừa rồi
/// kết luận "BM25 không ổn định". Nên mỗi núm mang theo một câu nói **hai đầu của nó làm gì**,
/// và câu ấy đổi theo giá trị đang đặt chứ không phải một tooltip tĩnh.
///
/// ## Tô sáng đi qua bộ tách token, không đi qua tìm chuỗi con
///
/// Nếu tô sáng bằng cách tìm chuỗi con thì nó sẽ sáng ở những chỗ mà điểm BM25 không hề tính
/// tới, và người dùng đọc bảng điểm sai. `BM25Index.highlights` cắt token đúng bộ tách đã dùng
/// để dựng chỉ mục — xem `BM25Tokenizer.matches`.
final class RetrievalPanel: NSView {

    // NFR-USE-03: đặt tên cho NHÓM.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Phòng thí nghiệm truy hồi BM25") }

    static let height: CGFloat = 300

    private let field = NSTextField()
    private let summary = NSTextField(labelWithString: "")
    private let k1Slider = NSSlider()
    private let bSlider = NSSlider()
    private let k1Label = NSTextField(labelWithString: "")
    private let bLabel = NSTextField(labelWithString: "")
    private let tuningNote = NSTextField(labelWithString: "")
    /// Bật phép lai BM25 × đồ thị — FR-KNW-925.
    private let hybridBox = NSButton()
    private let alphaSlider = NSSlider()
    private let alphaLabel = NSTextField(labelWithString: "")
    private let graphRAGPicker = NSPopUpButton()
    private let closeButton = NSButton()
    private let evaluateButton = NSPopUpButton()
    private let scrollView = NSScrollView()
    private let results = ClickableTextView()
    private let labelBar = NSView()
    private let labelToggle = NSButton()
    private let saveButton = NSButton()
    private let exportButton = NSButton()
    private let coverage = NSTextField(labelWithString: "")
    private let noteField = NSTextField()

    private var hits: [BM25Index.Hit] = []
    /// Dải ký tự (UTF-16) của từng kết quả trong ô kết quả — để biết người dùng bấm vào cái nào.
    private var hitRanges: [Range<Int>] = []
    private var hitIdentifiers: [String] = []
    /// Kết quả đang được chọn là "đúng" cho câu hỏi hiện tại.
    private(set) var chosen: Set<Int> = []

    var onQuery: ((String) -> Void)?
    /// Người dùng kéo núm — chỗ gọi dựng lại chỉ mục với tham số mới rồi hỏi lại.
    var onTuning: ((_ k1: Double, _ b: Double) -> Void)?
    /// Mở bộ đánh giá golden set (FR-KNW-919).
    var onEvaluate: ((EvaluateAction) -> Void)?

    /// Hai đường đánh giá. Menu bật xuống thay vì hai nút: hàng công cụ này đã có ô câu hỏi,
    /// hộp GraphRAG và nút Đóng, và một nút nữa thì ô câu hỏi hẹp lại đúng bằng chừng ấy.
    public enum EvaluateAction: Int, CaseIterable {
        case goldenSet = 1, externalScores

        var title: String {
            switch self {
            case .goldenSet: return L("Bộ đánh giá golden set…")
            case .externalScores: return L("So với điểm ngoài (JSONL)…")
            }
        }
    }
    /// Bật/tắt phép lai, hoặc kéo α — FR-KNW-925.
    var onHybrid: ((_ enabled: Bool, _ alpha: Double) -> Void)?
    /// Phân tích phủ hoặc xuất gói ngữ cảnh — FR-KNW-920.
    var onGraphRAG: ((GraphRAGAction) -> Void)?

    public enum GraphRAGAction: Int, CaseIterable {
        case none, coverage, contextPackage

        var title: String {
            switch self {
            case .none: return L("GraphRAG…")
            case .coverage: return L("Phân tích phủ Chunk ↔ Entity")
            case .contextPackage: return L("Xuất gói ngữ cảnh (JSONL)")
            }
        }
    }
    /// Lưu một record vào bộ đánh giá — FR-KNW-926.
    var onSaveLabel: ((_ question: String, _ ids: [String], _ note: String) -> Void)?
    var onExportGoldenSet: (() -> Void)?
    var onToggleLabelling: ((Bool) -> Void)?
    var onClose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }

    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)

        field.placeholderString = L("Câu hỏi — Enter để tìm")
        field.font = Tokens.Font.monoInline()
        field.target = self
        field.action = #selector(runQuery)
        field.translatesAutoresizingMaskIntoConstraints = false

        hybridBox.setButtonType(.switch)
        hybridBox.title = L("Lai với đồ thị")
        hybridBox.font = Tokens.Font.caption
        hybridBox.target = self
        hybridBox.action = #selector(hybridChanged)
        hybridBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hybridBox)

        alphaSlider.minValue = 0
        alphaSlider.maxValue = 1
        alphaSlider.doubleValue = 0.7
        alphaSlider.target = self
        alphaSlider.action = #selector(hybridChanged)
        alphaSlider.controlSize = .small
        alphaSlider.isEnabled = false
        alphaSlider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(alphaSlider)

        for label in [summary, tuningNote, k1Label, bLabel, alphaLabel] {
            label.font = Tokens.Font.caption
            label.textColor = Tokens.Color.editorInk
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }

        // Dải giá trị lấy từ chính đặc tả và từ tài liệu gốc của BM25: `k1` thường nằm trong
        // 0…3, `b` theo định nghĩa nằm trong 0…1.
        k1Slider.minValue = 0
        k1Slider.maxValue = 3
        k1Slider.doubleValue = 1.2
        bSlider.minValue = 0
        bSlider.maxValue = 1
        bSlider.doubleValue = 0.75
        for slider in [k1Slider, bSlider] {
            slider.target = self
            slider.action = #selector(tuningChanged)
            slider.controlSize = .small
            slider.translatesAutoresizingMaskIntoConstraints = false
            addSubview(slider)
        }

        for action in GraphRAGAction.allCases {
            graphRAGPicker.addItem(withTitle: action.title)
        }
        graphRAGPicker.font = Tokens.Font.caption
        graphRAGPicker.target = self
        graphRAGPicker.action = #selector(graphRAGChanged)
        graphRAGPicker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(graphRAGPicker)

        // Menu bật xuống: mục đầu là NHÃN, hai mục sau là hai lệnh.
        evaluateButton.pullsDown = true
        evaluateButton.bezelStyle = .rounded
        evaluateButton.font = Tokens.Font.caption
        evaluateButton.translatesAutoresizingMaskIntoConstraints = false
        let evaluateMenu = NSMenu()
        evaluateMenu.addItem(withTitle: L("Đánh giá…"), action: nil, keyEquivalent: "")
        for action in EvaluateAction.allCases {
            let item = NSMenuItem(
                title: action.title, action: #selector(evaluateTapped), keyEquivalent: "")
            item.target = self
            item.tag = action.rawValue
            evaluateMenu.addItem(item)
        }
        evaluateButton.menu = evaluateMenu
        addSubview(evaluateButton)

        for (button, title, action) in [
            (closeButton, L("Đóng"), #selector(closeTapped)),
        ] {
            button.title = title
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
        }

        labelToggle.setButtonType(.switch)
        labelToggle.title = L("Gán nhãn")
        labelToggle.font = Tokens.Font.caption
        labelToggle.target = self
        labelToggle.action = #selector(labellingChanged)
        labelToggle.translatesAutoresizingMaskIntoConstraints = false

        noteField.placeholderString = L("Ghi chú (tuỳ chọn)")
        noteField.font = Tokens.Font.caption
        noteField.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, action) in [
            (saveButton, L("Lưu record"), #selector(saveTapped)),
            (exportButton, L("Xuất CSV"), #selector(exportTapped)),
        ] {
            button.title = title
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
            labelBar.addSubview(button)
        }
        saveButton.keyEquivalent = "\r"
        coverage.font = Tokens.Font.caption
        coverage.textColor = Tokens.Color.editorInk
        coverage.lineBreakMode = .byTruncatingTail
        coverage.translatesAutoresizingMaskIntoConstraints = false
        labelBar.addSubview(noteField)
        labelBar.addSubview(coverage)
        labelBar.isHidden = true
        labelBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelToggle)
        addSubview(labelBar)

        // Bấm vào một kết quả để CHỌN nó — mục tiêu «≤ 3 click + 1 lần gõ mỗi record» của
        // FR-KNW-926 chỉ đạt được nếu việc chọn là một cú bấm thẳng vào thứ người dùng đang
        // đọc. Một hàng hộp kiểm riêng bên dưới là thêm một chỗ phải nhìn và một chỗ bấm nhầm.
        results.onClickCharacter = { [weak self] index in self?.toggleHit(at: index) }
        results.isEditable = false
        results.isSelectable = true
        results.font = Tokens.Font.monoInline()
        results.drawsBackground = false
        results.textContainerInset = NSSize(width: 6, height: 6)
        scrollView.documentView = results
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(field)
        addSubview(scrollView)
        updateTuningLabels()

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            field.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            field.trailingAnchor.constraint(
                equalTo: graphRAGPicker.leadingAnchor, constant: -8),

            graphRAGPicker.trailingAnchor.constraint(
                equalTo: evaluateButton.leadingAnchor, constant: -8),
            graphRAGPicker.centerYAnchor.constraint(equalTo: field.centerYAnchor),

            evaluateButton.trailingAnchor.constraint(
                equalTo: closeButton.leadingAnchor, constant: -8),
            evaluateButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),

            k1Label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            k1Label.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 8),
            k1Label.widthAnchor.constraint(equalToConstant: 92),
            k1Slider.leadingAnchor.constraint(equalTo: k1Label.trailingAnchor, constant: 6),
            k1Slider.centerYAnchor.constraint(equalTo: k1Label.centerYAnchor),
            k1Slider.widthAnchor.constraint(equalToConstant: 130),

            bLabel.leadingAnchor.constraint(equalTo: k1Slider.trailingAnchor, constant: 16),
            bLabel.centerYAnchor.constraint(equalTo: k1Label.centerYAnchor),
            bLabel.widthAnchor.constraint(equalToConstant: 80),
            bSlider.leadingAnchor.constraint(equalTo: bLabel.trailingAnchor, constant: 6),
            bSlider.centerYAnchor.constraint(equalTo: k1Label.centerYAnchor),
            bSlider.widthAnchor.constraint(equalToConstant: 130),
            hybridBox.leadingAnchor.constraint(equalTo: bSlider.trailingAnchor, constant: 16),
            hybridBox.centerYAnchor.constraint(equalTo: k1Label.centerYAnchor),
            alphaLabel.leadingAnchor.constraint(equalTo: hybridBox.trailingAnchor, constant: 8),
            alphaLabel.centerYAnchor.constraint(equalTo: k1Label.centerYAnchor),
            alphaLabel.widthAnchor.constraint(equalToConstant: 62),
            alphaSlider.leadingAnchor.constraint(equalTo: alphaLabel.trailingAnchor, constant: 4),
            alphaSlider.centerYAnchor.constraint(equalTo: k1Label.centerYAnchor),
            alphaSlider.widthAnchor.constraint(equalToConstant: 110),
            alphaSlider.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -inset),

            tuningNote.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            tuningNote.trailingAnchor.constraint(
                equalTo: labelToggle.leadingAnchor, constant: -10),
            tuningNote.topAnchor.constraint(equalTo: k1Label.bottomAnchor, constant: 4),

            labelToggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            labelToggle.centerYAnchor.constraint(equalTo: tuningNote.centerYAnchor),

            labelBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            labelBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            labelBar.topAnchor.constraint(equalTo: tuningNote.bottomAnchor, constant: 4),
            labelBar.heightAnchor.constraint(equalToConstant: 26),

            noteField.leadingAnchor.constraint(equalTo: labelBar.leadingAnchor),
            noteField.centerYAnchor.constraint(equalTo: labelBar.centerYAnchor),
            noteField.widthAnchor.constraint(equalToConstant: 200),
            saveButton.leadingAnchor.constraint(equalTo: noteField.trailingAnchor, constant: 8),
            saveButton.centerYAnchor.constraint(equalTo: labelBar.centerYAnchor),
            exportButton.leadingAnchor.constraint(
                equalTo: saveButton.trailingAnchor, constant: 8),
            exportButton.centerYAnchor.constraint(equalTo: labelBar.centerYAnchor),
            coverage.leadingAnchor.constraint(
                equalTo: exportButton.trailingAnchor, constant: 10),
            coverage.trailingAnchor.constraint(equalTo: labelBar.trailingAnchor),
            coverage.centerYAnchor.constraint(equalTo: labelBar.centerYAnchor),

            summary.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            summary.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            summary.topAnchor.constraint(equalTo: labelBar.bottomAnchor, constant: 4),

            scrollView.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    // MARK: - Trạng thái

    func focusField() { window?.makeFirstResponder(field) }

    var query: String { field.stringValue }
    var k1: Double { (k1Slider.doubleValue * 100).rounded() / 100 }
    var b: Double { (bSlider.doubleValue * 100).rounded() / 100 }

    func presentBuilding(_ fraction: Double) {
        summary.stringValue = L("Đang dựng chỉ mục")
            + String(format: " — %.0f%%", fraction * 100)
        summary.textColor = Tokens.Color.editorInk
    }

    func presentUnusable(_ reason: String) {
        hits = []
        results.string = ""
        summary.stringValue = reason
        summary.textColor = Tokens.Color.error
    }

    /// Kết quả top-k, kèm tô sáng từ khớp.
    ///
    /// Ba trạng thái phải trông khác nhau: chưa hỏi gì · hỏi rồi mà không có gì khớp · có kết
    /// quả. Gộp hai cái đầu lại thì người dùng không biết mình đã bấm Enter chưa.
    func present(
        query: String, hits: [BM25Index.Hit],
        texts: [String], identifiers: [String], highlights: [[Range<Int>]],
        elapsedMs: Double, documentCount: Int
    ) {
        lastPresented = (query, hits, texts, identifiers, highlights, elapsedMs, documentCount)
        self.hits = hits
        guard !hits.isEmpty else {
            results.string = ""
            hitRanges = []
            summary.stringValue = L("Không chunk nào khớp") + " «\(query)»"
            summary.textColor = Tokens.Color.editorInk
            saveButton.isEnabled = false
            return
        }
        summary.stringValue = "\(hits.count) " + L("kết quả trên")
            + " \(documentCount) " + L("chunk")
            + String(format: " · %.1f ms", elapsedMs)
        summary.textColor = Tokens.Color.editorInk

        hitIdentifiers = identifiers
        hitRanges = []
        let body = NSMutableAttributedString()
        let mono = Tokens.Font.monoInline()
        for (rank, hit) in hits.enumerated() {
            let start = body.length
            let identifier = rank < identifiers.count ? identifiers[rank] : ""
            let mark = chosen.contains(rank) ? "✓ " : (isLabelling ? "  " : "")
            let header = mark + String(format: "#%d  %.4f  ", rank + 1, hit.score)
                + (identifier.isEmpty ? L("dòng") + " \(hit.document + 1)" : identifier)
                + "\n"
            body.append(NSAttributedString(string: header, attributes: [
                .font: mono, .foregroundColor: Tokens.Color.editorInk.withAlphaComponent(0.65),
            ]))
            let text = rank < texts.count ? texts[rank] : ""
            let chunk = NSMutableAttributedString(string: text + "\n\n", attributes: [
                .font: mono, .foregroundColor: Tokens.Color.editorInk,
            ])
            if rank < highlights.count {
                let length = (text as NSString).length
                for range in highlights[rank] where range.upperBound <= length {
                    chunk.addAttributes([
                        // Cùng màu mà thanh tìm kiếm dùng cho từ khớp: người dùng đã học
                        // nghĩa của nó ở chỗ khác trong ứng dụng rồi.
                        .backgroundColor: Tokens.Color.gold.withAlphaComponent(0.45),
                        .foregroundColor: Tokens.Color.editorInk,
                    ], range: NSRange(location: range.lowerBound, length: range.count))
                }
            }
            body.append(chunk)
            hitRanges.append(start ..< body.length)
        }
        results.textStorage?.setAttributedString(body)
        saveButton.isEnabled = isLabelling && !chosen.isEmpty
    }

    // MARK: - Gán nhãn — FR-KNW-926

    private typealias Presented = (
        query: String, hits: [BM25Index.Hit], texts: [String], identifiers: [String],
        highlights: [[Range<Int>]], elapsedMs: Double, documentCount: Int)
    private var lastPresented: Presented?

    var isLabelling: Bool { labelToggle.state == .on }

    /// Câu hỏi + id đang chọn — chỗ gọi lưu thành một record.
    var pendingLabel: (question: String, ids: [String], note: String) {
        let ids = chosen.sorted().compactMap { rank -> String? in
            guard rank < hitIdentifiers.count else { return nil }
            let identifier = hitIdentifiers[rank]
            return identifier.isEmpty ? nil : identifier
        }
        return (query.trimmingCharacters(in: .whitespaces), ids,
                noteField.stringValue.trimmingCharacters(in: .whitespaces))
    }

    func presentCoverage(_ text: String) { coverage.stringValue = text }

    /// Đã lưu xong: xoá lựa chọn và ghi chú để gõ câu tiếp theo ngay.
    ///
    /// KHÔNG xoá ô câu hỏi: người dùng hay gán nhãn nhiều câu quanh cùng một chủ đề, và câu
    /// vừa gõ là điểm xuất phát tốt cho câu sau. Xoá nó là bắt gõ lại từ đầu mỗi lần.
    func clearLabelSelection() {
        chosen = []
        noteField.stringValue = ""
        redrawResults()
    }

    private func toggleHit(at characterIndex: Int) {
        guard isLabelling else { return }
        guard let rank = hitRanges.firstIndex(where: { $0.contains(characterIndex) }) else {
            return
        }
        if chosen.contains(rank) { chosen.remove(rank) } else { chosen.insert(rank) }
        redrawResults()
    }

    private func redrawResults() {
        guard let last = lastPresented else { return }
        present(query: last.query, hits: last.hits, texts: last.texts,
                identifiers: last.identifiers, highlights: last.highlights,
                elapsedMs: last.elapsedMs, documentCount: last.documentCount)
    }

    @objc private func labellingChanged() {
        labelBar.isHidden = !isLabelling
        chosen = []
        redrawResults()
        onToggleLabelling?(isLabelling)
    }

    @objc private func saveTapped() {
        let pending = pendingLabel
        guard !pending.question.isEmpty, !pending.ids.isEmpty else { return }
        onSaveLabel?(pending.question, pending.ids, pending.note)
    }

    @objc private func exportTapped() { onExportGoldenSet?() }

    // MARK: - Giải thích hai núm

    /// Câu giải thích đổi THEO GIÁ TRỊ đang đặt, không phải một tooltip tĩnh.
    ///
    /// Một câu định nghĩa ("k1 điều khiển độ bão hoà tần suất") không giúp ai quyết định gì.
    /// Câu ở đây nói **giá trị hiện tại đang làm gì** — và ở hai đầu dải thì nó nói hẳn ra hệ
    /// quả, vì đó là chỗ người dùng dễ kéo tới rồi ngạc nhiên.
    static func explain(k1: Double, b: Double) -> String {
        let k1Text: String
        if k1 < 0.05 {
            k1Text = L("k1 = 0: mỗi từ chỉ tính MỘT lần dù xuất hiện bao nhiêu lần")
        } else if k1 < 0.9 {
            k1Text = L("k1 thấp: lặp từ nhiều lần gần như không cộng thêm điểm")
        } else if k1 <= 1.6 {
            k1Text = L("k1 quanh mặc định 1,2: lặp từ có cộng điểm nhưng giảm dần")
        } else {
            k1Text = L("k1 cao: chunk lặp một từ nhiều lần được thưởng mạnh")
        }
        let bText: String
        if b < 0.05 {
            bText = L("b = 0: bỏ qua độ dài, chunk dài không bị phạt")
        } else if b < 0.5 {
            bText = L("b thấp: chunk dài chỉ bị phạt nhẹ")
        } else if b <= 0.85 {
            bText = L("b quanh mặc định 0,75: chunk dài bị phạt vừa phải")
        } else {
            bText = L("b = 1: phạt tối đa theo độ dài, chunk ngắn được ưu ái")
        }
        return k1Text + " · " + bText
    }

    private func updateTuningLabels() {
        k1Label.stringValue = String(format: "k1 = %.2f", k1)
        bLabel.stringValue = String(format: "b = %.2f", b)
        alphaLabel.stringValue = String(format: "α = %.2f", alpha)
        alphaSlider.isEnabled = isHybrid
        tuningNote.stringValue = RetrievalPanel.explain(k1: k1, b: b)
            + (isHybrid ? " · " + RetrievalPanel.explainAlpha(alpha) : "")
    }

    var isHybrid: Bool { hybridBox.state == .on }
    var alpha: Double { (alphaSlider.doubleValue * 100).rounded() / 100 }

    /// Giải thích α, cùng khuôn với hai núm k1/b — và hai đầu dải nói hẳn hệ quả.
    static func explainAlpha(_ alpha: Double) -> String {
        if alpha >= 0.99 {
            return L("α = 1: bỏ hẳn tín hiệu đồ thị, kết quả trùng BM25 thuần")
        }
        if alpha >= 0.8 { return L("α cao: đồ thị chỉ chỉnh nhẹ thứ hạng của BM25") }
        if alpha >= 0.4 { return L("α quanh mặc định 0,7: BM25 dẫn, đồ thị chỉnh") }
        if alpha > 0.01 { return L("α thấp: đồ thị dẫn, BM25 chỉ phá hoà") }
        return L("α = 0: chỉ tín hiệu đồ thị; chunk không entity nào đều bằng điểm")
    }

    @objc private func hybridChanged() {
        updateTuningLabels()
        onHybrid?(isHybrid, alpha)
    }

    // MARK: - Hành động

    @objc private func runQuery() {
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            hits = []
            results.string = ""
            summary.stringValue = ""
            return
        }
        onQuery?(text)
    }

    @objc private func tuningChanged() {
        updateTuningLabels()
        onTuning?(k1, b)
    }

    @objc private func graphRAGChanged() {
        guard let choice = GraphRAGAction(rawValue: graphRAGPicker.indexOfSelectedItem),
              choice != .none else { return }
        // Trả về mục đầu ngay — đây là NÚT LỆNH đội lốt hộp chọn, không phải một trạng thái.
        graphRAGPicker.selectItem(at: 0)
        onGraphRAG?(choice)
    }

    func runGraphRAGForSelfTest(_ action: GraphRAGAction) { onGraphRAG?(action) }

    @objc private func evaluateTapped(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let action = EvaluateAction(rawValue: item.tag) else { return }
        onEvaluate?(action)
    }

    func evaluateForSelfTest(_ action: EvaluateAction) { onEvaluate?(action) }
    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc cho bài tự kiểm

    var resultTextForSelfTest: String { results.string }
    var summaryForSelfTest: String { summary.stringValue }
    var tuningNoteForSelfTest: String { tuningNote.stringValue }

    /// Vùng đã tô sáng, dạng (vị trí, độ dài) trong chuỗi kết quả.
    var highlightRangesForSelfTest: [NSRange] {
        guard let storage = results.textStorage else { return [] }
        var out: [NSRange] = []
        storage.enumerateAttribute(
            .backgroundColor, in: NSRange(location: 0, length: storage.length)
        ) { value, range, _ in
            if value != nil { out.append(range) }
        }
        return out
    }

    func setQueryForSelfTest(_ text: String) {
        field.stringValue = text
        runQuery()
    }

    func setHybridForSelfTest(_ on: Bool, alpha: Double) {
        hybridBox.state = on ? .on : .off
        alphaSlider.doubleValue = alpha
        hybridChanged()
    }

    func setTuningForSelfTest(k1: Double, b: Double) {
        k1Slider.doubleValue = k1
        bSlider.doubleValue = b
        tuningChanged()
    }

    func setLabellingForSelfTest(_ on: Bool) {
        labelToggle.state = on ? .on : .off
        labellingChanged()
    }

    /// Bấm vào kết quả thứ `rank` đúng như người dùng bấm chuột.
    func clickHitForSelfTest(rank: Int) {
        guard rank < hitRanges.count else { return }
        toggleHit(at: hitRanges[rank].lowerBound)
    }

    func saveLabelForSelfTest() { saveTapped() }
    func setNoteForSelfTest(_ text: String) { noteField.stringValue = text }
    var coverageForSelfTest: String { coverage.stringValue }
    var canSaveForSelfTest: Bool { saveButton.isEnabled }
}

/// Ô văn bản báo lại VỊ TRÍ KÝ TỰ được bấm.
///
/// `NSTextView` không có callback nào cho "người dùng bấm vào chỗ nào"; nó chỉ dời con nháy.
/// Lớp con này bắt `mouseDown`, quy toạ độ về chỉ số ký tự rồi báo ra — đủ cho FR-KNW-926 chọn
/// một kết quả bằng đúng MỘT cú bấm vào thứ người dùng đang đọc.
final class ClickableTextView: NSTextView {

    var onClickCharacter: ((Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        guard let onClickCharacter else { return }
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        guard index >= 0, index <= (textStorage?.length ?? 0) else { return }
        onClickCharacter(index)
    }
}
