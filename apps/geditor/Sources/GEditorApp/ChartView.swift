import AppKit
import GEditorCore

/// Vẽ biểu đồ — FR-QRY-004, phần hiển thị.
///
/// **Không tự tính gì.** Mọi phép tính — rút gọn, chia khoảng, phân vị, vạch trục, vị trí từng
/// hình — nằm ở `ChartData` và `ChartRender` trong lõi. View này chỉ đọc một danh sách hình
/// nguyên thuỷ và đặt bút. Đó là điều kiện để phần xuất SVG không thể lệch khỏi thứ hiện trên
/// màn hình: cả hai đọc cùng một danh sách.
///
/// **`isFlipped = true`** — gốc toạ độ trái-trên, theo SVG. Một trong hai backend phải lật, và
/// lật ở đây là một dòng; lật ở phía SVG là lật trong mọi hình.
final class ChartView: NSView {

    override var isFlipped: Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .image }
    override func accessibilityLabel() -> String? {
        // NFR-USE-03: view TỰ VẼ phải khai vai trò, nhãn VÀ giá trị. Một biểu đồ câm lặng với
        // VoiceOver là một ô trống trên màn hình của người khiếm thị.
        guard let series else { return L("Biểu đồ") }
        let high = series.points.map(\.y).max() ?? 0
        let low = series.points.map(\.y).min() ?? 0
        return String(
            format: L("Biểu đồ %@ của «%@» — %d điểm, giá trị từ %@ đến %@"),
            kind.vietnamese, series.name, series.points.count,
            ChartRender.number(low), ChartRender.number(high))
    }

    private(set) var kind: ChartData.Kind = .bar
    private(set) var series: ChartData.Series?
    private(set) var title = ""

    private(set) var trendLine: (slope: Double, intercept: Double)?
    private(set) var pointGroups: [Int]?

    func show(
        _ series: ChartData.Series?, kind: ChartData.Kind, title: String = "",
        trendLine: (slope: Double, intercept: Double)? = nil,
        pointGroups: [Int]? = nil
    ) {
        raw = nil
        self.series = series
        self.kind = kind
        self.title = title
        self.trendLine = trendLine
        self.pointGroups = pointGroups
        needsDisplay = true
    }

    private var layout: ChartRender.Layout {
        ChartRender.Layout(width: Double(bounds.width), height: Double(bounds.height))
    }

    /// Danh sách hình dựng SẴN từ bên ngoài — dùng cho biểu đồ dự báo (FR-MIN-004), thứ không
    /// khớp vào khuôn một-dãy của `ChartData.Kind`.
    ///
    /// Vẫn đi qua đúng đường vẽ và đúng đường xuất ảnh của mọi biểu đồ khác, nên không có
    /// backend thứ hai để lệch.
    private var raw: [ChartRender.Primitive]?

    func showRaw(_ primitives: [ChartRender.Primitive]) {
        raw = primitives
        series = nil
        needsDisplay = true
    }

    private var primitives: [ChartRender.Primitive] {
        if let raw { return raw }
        guard let series else { return [] }
        return ChartRender.primitives(
            kind: kind, series: series, layout: layout, title: title, trendLine: trendLine,
            pointGroups: pointGroups)
    }

    override func draw(_ dirtyRect: NSRect) {
        Tokens.Color.editorBackground.setFill()
        bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        ChartView.draw(primitives, in: context)
    }

    /// Vẽ một danh sách hình. `static` để đường XUẤT ẢNH dùng lại đúng hàm này — nếu xuất ảnh
    /// có đường vẽ riêng thì ảnh và màn hình lại là hai thứ.
    static func draw(_ primitives: [ChartRender.Primitive], in context: CGContext) {
        for primitive in primitives {
            switch primitive {
            case let .rect(x, y, width, height, fill):
                context.setFillColor(colour(fill).cgColor)
                context.fill(CGRect(x: x, y: y, width: width, height: height))
            case let .line(x1, y1, x2, y2, stroke, width):
                context.setStrokeColor(colour(stroke).cgColor)
                context.setLineWidth(width)
                context.beginPath()
                context.move(to: CGPoint(x: x1, y: y1))
                context.addLine(to: CGPoint(x: x2, y: y2))
                context.strokePath()
            case let .polyline(points, stroke, width):
                guard let first = points.first else { break }
                context.setStrokeColor(colour(stroke).cgColor)
                context.setLineWidth(width)
                context.setLineJoin(.round)
                context.beginPath()
                context.move(to: CGPoint(x: first.0, y: first.1))
                for point in points.dropFirst() {
                    context.addLine(to: CGPoint(x: point.0, y: point.1))
                }
                context.strokePath()
            case let .polygon(points, fill, opacity):
                guard let first = points.first else { break }
                context.setFillColor(colour(fill).withAlphaComponent(opacity).cgColor)
                context.beginPath()
                context.move(to: CGPoint(x: first.0, y: first.1))
                for point in points.dropFirst() {
                    context.addLine(to: CGPoint(x: point.0, y: point.1))
                }
                context.closePath()
                context.fillPath()
            case let .circle(x, y, radius, fill):
                context.setFillColor(colour(fill).cgColor)
                context.fillEllipse(in: CGRect(
                    x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            case let .text(x, y, string, size, anchor, fill):
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: size),
                    .foregroundColor: colour(fill),
                ]
                let text = NSAttributedString(string: string, attributes: attributes)
                let width = text.size().width
                let originX: Double
                switch anchor {
                case .start: originX = x
                case .middle: originX = x - width / 2
                case .end: originX = x - width
                }
                // `y` trong danh sách là ĐƯỜNG CHÂN CHỮ (theo SVG); AppKit vẽ từ góc trên, nên
                // lùi lên một khoảng bằng phần chữ nằm trên đường chân.
                text.draw(at: NSPoint(x: originX, y: y - size))
            }
        }
    }

    /// Màu theo VAI TRÒ → màu theo THEME. Bảng hex trong `ChartRender.Ink` chỉ dành cho SVG,
    /// vốn không biết người xem đang ở theme nào.
    private static func colour(_ ink: ChartRender.Ink) -> NSColor {
        switch ink {
        case .axis: return Tokens.Color.editorInk
        case .grid: return Tokens.Color.editorInk.withAlphaComponent(0.15)
        case .label: return Tokens.Color.editorInk.withAlphaComponent(0.7)
        case .warning: return Tokens.Color.ember
        default:
            // Màu DÃY dùng đúng bảng hex của SVG: nếu màn hình và ảnh xuất ra khác màu thì
            // người ta gửi cho nhau hai biểu đồ khác nhau. Ba màu vai trò ở trên thì theo
            // theme, vì chúng là khung chứ không phải dữ liệu.
            return hexColour(ink.hex)
        }
    }

    private static func hexColour(_ hex: String) -> NSColor {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    // MARK: - Xuất (FR-QRY-004)

    /// PNG ở bội số điểm ảnh chỉ định — `2` cho màn hình Retina, `3` để dán vào slide.
    func pngData(scale: Int = 2) -> Data? {
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return nil }
        let pixelWidth = Int(size.width) * scale
        let pixelHeight = Int(size.height) * scale
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelWidth, pixelsHigh: pixelHeight,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        representation.size = size

        guard let context = NSGraphicsContext(bitmapImageRep: representation) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cgContext = context.cgContext
        // Nền TRẮNG, không trong suốt: ảnh dán vào Keynote hay Slack trên nền tối mà trong suốt
        // thì chữ đen biến mất. Muốn nền trong suốt thì dùng SVG.
        cgContext.setFillColor(NSColor.white.cgColor)
        cgContext.fill(CGRect(origin: .zero, size: size))
        cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        // Lật: bitmap context có gốc TRÁI-DƯỚI, còn danh sách hình dùng gốc TRÁI-TRÊN.
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)
        ChartView.draw(primitives, in: cgContext)
        NSGraphicsContext.restoreGraphicsState()

        return representation.representation(using: .png, properties: [:])
    }

    func svgText() -> String {
        ChartRender.svg(primitives, layout: layout)
    }

    // MARK: - Móc tự kiểm

    var primitiveCountForSelfTest: Int { primitives.count }
    var svgForSelfTest: String { svgText() }
    func pngBytesForSelfTest() -> Int { pngData()?.count ?? 0 }
}
