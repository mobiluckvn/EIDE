import Foundation

/// Dựng biểu đồ thành **danh sách hình nguyên thuỷ** — FR-QRY-004.
///
/// ## Vì sao có tầng trung gian này thay vì vẽ thẳng
///
/// Đặc tả đòi *"export PNG/SVG"*. PNG ra từ Core Graphics; SVG là văn bản. Cách hiển nhiên —
/// vẽ bằng Core Graphics cho màn hình, rồi viết một hàm khác sinh SVG — cho **hai bản hiện
/// thực của cùng một biểu đồ**, và chúng sẽ lệch nhau. Không lệch ngay: lệch sau ba tháng, ở
/// đúng chỗ ai đó sửa một bên mà quên bên kia, và người dùng phát hiện bằng cách gửi cho đồng
/// nghiệp một file SVG khác thứ họ nhìn trên màn hình.
///
/// Nên cả hai đọc CÙNG một danh sách. Sinh danh sách là số học thuần, kiểm được ở lõi mà không
/// dựng cửa sổ nào — kể cả phần SVG, vốn chỉ là một phép đổi chuỗi.
///
/// ## Hệ toạ độ: gốc TRÁI TRÊN
///
/// Theo SVG, không theo AppKit. Một trong hai backend phải lật, và lật ở phía AppKit là một
/// phép biến đổi duy nhất ở một chỗ duy nhất; lật ở phía SVG là lật trong mọi hình.
public enum ChartRender {

    /// Màu, đặt tên theo VAI TRÒ chứ không theo sắc.
    ///
    /// Backend AppKit tra `Tokens.theme` để đổi theo theme sáng/tối; backend SVG dùng bảng cố
    /// định. Đặt tên theo sắc ("xanh", "cam") thì tên ấy sai ngay khi đổi theme.
    public enum Ink: String, Equatable, Sendable {
        case axis, grid, label, series1, series2, series3, series4, series5, series6, warning

        /// Màu cho SVG. Chọn dải phân biệt được với **mù màu đỏ-lục** — hai màu đầu không phải
        /// đỏ và lục cạnh nhau, và không cặp nào chỉ khác nhau ở sắc.
        public var hex: String {
            switch self {
            case .axis: return "#3c3c3c"
            case .grid: return "#e0e0e0"
            case .label: return "#555555"
            case .series1: return "#4269d0"
            case .series2: return "#efb118"
            case .series3: return "#ff725c"
            case .series4: return "#6cc5b0"
            case .series5: return "#a463f2"
            case .series6: return "#97bbf5"
            case .warning: return "#a34309"
            }
        }

        public static let seriesPalette: [Ink] =
            [.series1, .series2, .series3, .series4, .series5, .series6]
    }

    public enum Anchor: String, Equatable, Sendable {
        case start, middle, end
    }

    public enum Primitive: Equatable, Sendable {
        case rect(x: Double, y: Double, width: Double, height: Double, fill: Ink)
        case line(x1: Double, y1: Double, x2: Double, y2: Double, stroke: Ink, width: Double)
        case polyline(points: [(Double, Double)], stroke: Ink, width: Double)
        case circle(x: Double, y: Double, radius: Double, fill: Ink)
        case text(x: Double, y: Double, string: String, size: Double, anchor: Anchor, fill: Ink)
        /// Vùng tô kín — dải tin cậy của FR-MIN-004. `opacity` trong `[0, 1]`.
        ///
        /// Cần một hình riêng thay vì ghép nhiều `rect`: dải tin cậy có mép TRÊN và mép DƯỚI
        /// đều là đường gấp khúc, và xấp xỉ nó bằng các cột chữ nhật cho ra một mép răng cưa
        /// đúng ở chỗ người đọc đang cân nhắc mức độ không chắc chắn.
        case polygon(points: [(Double, Double)], fill: Ink, opacity: Double)

        public static func == (lhs: Primitive, rhs: Primitive) -> Bool {
            switch (lhs, rhs) {
            case let (.rect(a, b, c, d, e), .rect(f, g, h, i, j)):
                return a == f && b == g && c == h && d == i && e == j
            case let (.line(a, b, c, d, e, f), .line(g, h, i, j, k, l)):
                return a == g && b == h && c == i && d == j && e == k && f == l
            case let (.polyline(a, b, c), .polyline(d, e, f)):
                return a.count == d.count && zip(a, d).allSatisfy { $0 == $1 } && b == e && c == f
            case let (.circle(a, b, c, d), .circle(e, f, g, h)):
                return a == e && b == f && c == g && d == h
            case let (.text(a, b, c, d, e, f), .text(g, h, i, j, k, l)):
                return a == g && b == h && c == i && d == j && e == k && f == l
            case let (.polygon(a, b, c), .polygon(d, e, f)):
                return a.count == d.count && zip(a, d).allSatisfy { $0 == $1 } && b == e && c == f
            default: return false
            }
        }
    }

    /// Bảng màu thay được — FR-RPT-002 (*"theme màu preset (G-Light, G-Dark, Brand cam) và
    /// custom JSON"*).
    ///
    /// Chỉ ánh xạ `Ink` → mã màu, không đụng tới hình học. Nhờ vậy đổi theme không thể làm lệch
    /// một toạ độ nào: cùng danh sách hình, khác bảng tra màu.
    public struct Palette: Equatable, Sendable {
        public var colours: [Ink: String]

        public init(colours: [Ink: String] = [:]) { self.colours = colours }

        /// Màu của một vai trò; thiếu khai thì rơi về màu gốc của `Ink`.
        ///
        /// Rơi về chứ không báo lỗi: một theme tuỳ biến chỉ khai ba màu dãy vẫn phải vẽ được
        /// trục và lưới, và bắt người dùng khai đủ mười vai trò để đổi một màu là bắt sai chỗ.
        public func hex(_ ink: Ink) -> String { colours[ink] ?? ink.hex }

        /// Mặc định — đúng bảng màu gốc của `Ink`.
        public static let gLight = Palette()

        /// Nền tối: trục và chữ sáng lên, lưới mờ đi. Màu DÃY giữ nguyên để cùng một biểu đồ ở
        /// hai theme vẫn nhận ra được là cùng dữ liệu.
        public static let gDark = Palette(colours: [
            .axis: "#d8d8d8", .grid: "#3a3a3a", .label: "#a8a8a8",
        ])

        /// Thương hiệu — cam của biểu tượng ứng dụng làm màu dãy thứ nhất.
        public static let brand = Palette(colours: [
            .series1: "#d94f2b", .series2: "#f0a04b", .series3: "#7a4a8c",
            .series4: "#3f7d78", .series5: "#c1573f", .series6: "#8a8f4d",
        ])

        public static func named(_ name: String) -> Palette? {
            switch name.lowercased() {
            case "g-light", "light", "glight": return .gLight
            case "g-dark", "dark", "gdark": return .gDark
            case "brand", "cam": return .brand
            default: return nil
            }
        }
    }

    /// Kiểu vẽ: bảng màu và quy ước số của nhãn trục.
    ///
    /// `numbers` là `nil` ở mặc định, KHÔNG phải một `NumberStyle` tương đương. Có một khác
    /// biệt thật giữa hai cách: `nil` đi qua đúng `ChartRender.number` mà mọi biểu đồ ngoài báo
    /// cáo đang dùng, nên thêm tham số này không đổi một điểm ảnh nào của những chỗ ấy.
    public struct Style: Equatable, Sendable {
        public var palette: Palette
        public var numbers: NumberStyle?

        public init(palette: Palette = .gLight, numbers: NumberStyle? = nil) {
            self.palette = palette
            self.numbers = numbers
        }

        public static let `default` = Style()

        func label(_ value: Double) -> String {
            numbers?.compact(value) ?? ChartRender.number(value)
        }
    }

    public struct Layout: Equatable, Sendable {
        public var width: Double
        public var height: Double
        /// Chừa chỗ cho nhãn trục. Trái rộng hơn vì số trên trục Y dài hơn nhãn trục X.
        public var insetLeft: Double = 56
        public var insetRight: Double = 12
        public var insetTop: Double = 14
        public var insetBottom: Double = 34

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }

        public var plotWidth: Double { max(1, width - insetLeft - insetRight) }
        public var plotHeight: Double { max(1, height - insetTop - insetBottom) }
    }

    // MARK: - Dựng

    /// - Parameter trendLine: hệ số góc và điểm cắt của một đường thẳng vẽ ĐÈ lên biểu đồ
    ///   phân tán (FR-MIN-005 đòi *"scatter 2 cột kèm đường hồi quy tuyến tính đơn giản"*).
    ///   Nhận hai con số thay vì một kiểu của phần tương quan: đây là hình học thuần tuý, và
    ///   `ChartRender` không có lý do gì phải biết đường ấy từ đâu ra. Bỏ qua với mọi loại
    ///   biểu đồ khác — một đường hồi quy trên biểu đồ hộp không có nghĩa.
    /// - Parameter pointGroups: nhãn NHÓM cho từng điểm của biểu đồ phân tán — dùng cho
    ///   FR-MIN-002 (*"scatter tô màu theo cụm"*). Mỗi nhóm một màu trong dải `series*`. Nhãn
    ///   âm (nhiễu DBSCAN) vẽ màu nhạt của trục thay vì một màu dãy: nhiễu KHÔNG phải một cụm,
    ///   và cho nó một màu ngang hàng các cụm là nói sai điều đó bằng hình ảnh.
    ///
    ///   Nhận `[Int]` thay vì một kiểu của phần phân cụm, cùng lý do với `trendLine`: đây là
    ///   việc tô màu theo nhóm, và lõi vẽ không cần biết nhóm ấy từ đâu ra.
    public static func primitives(
        kind: ChartData.Kind,
        series: ChartData.Series,
        layout: Layout,
        title: String = "",
        trendLine: (slope: Double, intercept: Double)? = nil,
        pointGroups: [Int]? = nil,
        style: Style = .default
    ) -> [Primitive] {
        switch kind {
        case .bar: return bar(series, layout, title, style)
        case .line, .scatter:
            return xy(kind: kind, series, layout, title, trendLine, pointGroups, style)
        case .histogram: return histogram(series, layout, title, style)
        case .box: return box(series, layout, title, style)
        }
    }

    /// Ghi chú rút gọn, vẽ ngay trên biểu đồ.
    ///
    /// NFR-QRY-02 đòi *"ghi chú rõ mức lấy mẫu TRÊN biểu đồ"* — không phải trong một tooltip,
    /// không phải trong một dòng trạng thái sẽ biến mất khi xuất ảnh. Ảnh PNG người ta dán vào
    /// báo cáo phải tự nói được rằng nó đã rút gọn.
    private static func samplingNote(_ series: ChartData.Series, _ layout: Layout) -> [Primitive] {
        guard !series.samplingNote.isEmpty else { return [] }
        return [.text(
            x: layout.insetLeft, y: layout.height - 6,
            string: series.samplingNote, size: 9, anchor: .start, fill: .warning)]
    }

    private static func frame(
        _ layout: Layout, yTicks: [Double], yLow: Double, yHigh: Double,
        _ style: Style = .default
    ) -> [Primitive] {
        var out: [Primitive] = []
        let span = max(yHigh - yLow, .leastNormalMagnitude)
        for tick in yTicks {
            let y = layout.insetTop + layout.plotHeight * (1 - (tick - yLow) / span)
            out.append(.line(
                x1: layout.insetLeft, y1: y, x2: layout.width - layout.insetRight, y2: y,
                stroke: .grid, width: 1))
            out.append(.text(
                x: layout.insetLeft - 6, y: y + 3, string: style.label(tick), size: 10,
                anchor: .end, fill: .label))
        }
        // Trục vẽ SAU lưới để nó nằm trên.
        out.append(.line(
            x1: layout.insetLeft, y1: layout.insetTop,
            x2: layout.insetLeft, y2: layout.insetTop + layout.plotHeight,
            stroke: .axis, width: 1))
        out.append(.line(
            x1: layout.insetLeft, y1: layout.insetTop + layout.plotHeight,
            x2: layout.width - layout.insetRight, y2: layout.insetTop + layout.plotHeight,
            stroke: .axis, width: 1))
        return out
    }

    private static func bar(
        _ series: ChartData.Series, _ layout: Layout, _ title: String, _ style: Style = .default
    ) -> [Primitive] {
        guard !series.points.isEmpty else { return empty(layout) }
        // Trục Y của biểu đồ CỘT luôn bắt đầu từ 0.
        //
        // Cắt gốc trục làm cột 102 trông cao gấp đôi cột 101 — đó là cách kinh điển để nói dối
        // bằng biểu đồ, và nó xảy ra do lười chứ hiếm khi do cố ý.
        let high = max(series.points.map(\.y).max() ?? 0, 0)
        let low = min(series.points.map(\.y).min() ?? 0, 0)
        let ticks = ChartData.ticks(from: low, to: high)
        let yLow = min(low, ticks.first ?? low)
        let yHigh = max(high, ticks.last ?? high)
        var out = frame(layout, yTicks: ticks, yLow: yLow, yHigh: yHigh, style)

        let span = max(yHigh - yLow, .leastNormalMagnitude)
        let slot = layout.plotWidth / Double(series.points.count)
        let barWidth = max(1, slot * 0.7)
        let zeroY = layout.insetTop + layout.plotHeight * (1 - (0 - yLow) / span)
        for (index, point) in series.points.enumerated() {
            let x = layout.insetLeft + slot * Double(index) + (slot - barWidth) / 2
            let valueY = layout.insetTop + layout.plotHeight * (1 - (point.y - yLow) / span)
            out.append(.rect(
                x: x, y: min(valueY, zeroY), width: barWidth, height: abs(zeroY - valueY),
                fill: .series1))
            if let label = point.label, series.points.count <= 16 {
                out.append(.text(
                    x: x + barWidth / 2, y: layout.insetTop + layout.plotHeight + 14,
                    string: label, size: 10, anchor: .middle, fill: .label))
            }
        }
        return out + titleText(title, layout) + samplingNote(series, layout)
    }

    private static func xy(
        kind: ChartData.Kind, _ series: ChartData.Series, _ layout: Layout, _ title: String,
        _ trendLine: (slope: Double, intercept: Double)? = nil,
        _ pointGroups: [Int]? = nil,
        _ style: Style = .default
    ) -> [Primitive] {
        guard !series.points.isEmpty else { return empty(layout) }
        let ys = series.points.map(\.y)
        let xs = series.points.map(\.x)
        let ticks = ChartData.ticks(from: ys.min() ?? 0, to: ys.max() ?? 1)
        let yLow = min(ys.min() ?? 0, ticks.first ?? 0)
        let yHigh = max(ys.max() ?? 1, ticks.last ?? 1)
        var out = frame(layout, yTicks: ticks, yLow: yLow, yHigh: yHigh, style)

        let ySpan = max(yHigh - yLow, .leastNormalMagnitude)
        let xLow = xs.min() ?? 0
        let xSpan = max((xs.max() ?? 1) - xLow, .leastNormalMagnitude)
        func place(_ point: ChartData.Point) -> (Double, Double) {
            (layout.insetLeft + layout.plotWidth * (point.x - xLow) / xSpan,
             layout.insetTop + layout.plotHeight * (1 - (point.y - yLow) / ySpan))
        }
        if kind == .line {
            out.append(.polyline(points: series.points.map(place), stroke: .series1, width: 1.5))
        } else {
            for (index, point) in series.points.enumerated() {
                let (x, y) = place(point)
                let group = pointGroups.flatMap { index < $0.count ? $0[index] : nil }
                out.append(.circle(x: x, y: y, radius: 2, fill: ink(forGroup: group)))
            }
        }
        if kind == .scatter, let trendLine {
            // Vẽ qua HAI ĐẦU dải x rồi để hệ toạ độ tự cắt, thay vì lấy hai điểm dữ liệu:
            // đường phải chạy hết bề ngang khung, kể cả khi điểm dữ liệu tụ về một phía.
            //
            // `place` nhận một `Point`, nên hai đầu đi qua đúng phép biến đổi mà các chấm đi
            // qua — nếu tính toạ độ riêng cho đường thì nó sẽ lệch khỏi đám chấm ngay khi ai đó
            // đổi cách đặt trục.
            let xHigh = xLow + xSpan
            let start = place(ChartData.Point(
                x: xLow, y: trendLine.slope * xLow + trendLine.intercept))
            let end = place(ChartData.Point(
                x: xHigh, y: trendLine.slope * xHigh + trendLine.intercept))
            out.append(.line(
                x1: start.0, y1: start.1, x2: end.0, y2: end.1, stroke: .series2, width: 1.5))
        }
        return out + titleText(title, layout) + samplingNote(series, layout)
    }

    /// Màu của một nhóm điểm. `nil` (không phân nhóm) → màu dãy đầu; âm (nhiễu) → màu trục.
    static func ink(forGroup group: Int?) -> Ink {
        guard let group else { return .series1 }
        guard group >= 0 else { return .grid }
        let palette: [Ink] = [.series1, .series2, .series3, .series4, .series5, .series6]
        // Quay vòng khi số cụm vượt số màu. Sáu cụm trở lên thì màu bắt đầu lặp, và đó là giới
        // hạn thật của cách đọc bằng màu — bảng cụm bên cạnh mới là chỗ tra chính xác.
        return palette[group % palette.count]
    }

    private static func histogram(
        _ series: ChartData.Series, _ layout: Layout, _ title: String, _ style: Style = .default
    ) -> [Primitive] {
        // Điểm của phân bố mang `x` là mốc trái khoảng, `y` là số đếm — `ChartData.histogram`
        // dựng sẵn, ở đây chỉ vẽ.
        bar(series, layout, title, style)
    }

    private static func box(
        _ series: ChartData.Series, _ layout: Layout, _ title: String, _ style: Style = .default
    ) -> [Primitive] {
        guard let stats = ChartData.box(series.points.map(\.y)) else { return empty(layout) }
        let ticks = ChartData.ticks(from: min(stats.lowerWhisker, stats.outliers.min() ?? stats.minimum),
                                    to: max(stats.upperWhisker, stats.outliers.max() ?? stats.maximum))
        let yLow = ticks.first ?? stats.minimum
        let yHigh = ticks.last ?? stats.maximum
        var out = frame(layout, yTicks: ticks, yLow: yLow, yHigh: yHigh, style)
        let span = max(yHigh - yLow, .leastNormalMagnitude)
        func y(_ value: Double) -> Double {
            layout.insetTop + layout.plotHeight * (1 - (value - yLow) / span)
        }
        let centre = layout.insetLeft + layout.plotWidth / 2
        let halfWidth = min(60, layout.plotWidth / 4)

        out.append(.line(x1: centre, y1: y(stats.upperWhisker), x2: centre,
                         y2: y(stats.lowerWhisker), stroke: .axis, width: 1))
        out.append(.rect(x: centre - halfWidth, y: y(stats.q3), width: halfWidth * 2,
                         height: max(1, y(stats.q1) - y(stats.q3)), fill: .series1))
        out.append(.line(x1: centre - halfWidth, y1: y(stats.median),
                         x2: centre + halfWidth, y2: y(stats.median), stroke: .axis, width: 2))
        for outlier in stats.outliers {
            out.append(.circle(x: centre, y: y(outlier), radius: 2.5, fill: .warning))
        }
        return out + titleText(title, layout) + samplingNote(series, layout)
    }

    private static func titleText(_ title: String, _ layout: Layout) -> [Primitive] {
        guard !title.isEmpty else { return [] }
        return [.text(x: layout.width / 2, y: 11, string: title, size: 11,
                      anchor: .middle, fill: .label)]
    }

    private static func empty(_ layout: Layout) -> [Primitive] {
        // "Không có gì để vẽ" phải hiện ra thành chữ. Một khung trắng trông giống một biểu đồ
        // chưa vẽ xong, và người dùng sẽ ngồi đợi.
        [.text(x: layout.width / 2, y: layout.height / 2,
               string: "Không có dữ liệu để vẽ", size: 12, anchor: .middle, fill: .label)]
    }

    public static func number(_ value: Double) -> String {
        if abs(value) >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if abs(value) >= 1_000 { return String(format: "%.0fk", value / 1_000) }
        return value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
    }

    // MARK: - Xuất SVG

    /// SVG từ CÙNG danh sách hình mà màn hình vẽ — xem ghi chú ở đầu tệp.
    /// - Parameter style: bảng màu. Mặc định giữ nguyên màu gốc của `Ink`, nên mọi chỗ gọi
    ///   sẵn có không đổi một byte nào trong ảnh xuất ra.
    public static func svg(
        _ primitives: [Primitive], layout: Layout, style: Style = .default
    ) -> String {
        var out = """
            <svg xmlns="http://www.w3.org/2000/svg" width="\(number(layout.width))" \
            height="\(number(layout.height))" \
            viewBox="0 0 \(number(layout.width)) \(number(layout.height))">
            <rect width="100%" height="100%" fill="#ffffff"/>

            """
        for primitive in primitives {
            switch primitive {
            case let .rect(x, y, width, height, fill):
                out += "<rect x=\"\(f(x))\" y=\"\(f(y))\" width=\"\(f(width))\" "
                    + "height=\"\(f(height))\" fill=\"\(style.palette.hex(fill))\"/>\n"
            case let .line(x1, y1, x2, y2, stroke, width):
                out += "<line x1=\"\(f(x1))\" y1=\"\(f(y1))\" x2=\"\(f(x2))\" y2=\"\(f(y2))\" "
                    + "stroke=\"\(style.palette.hex(stroke))\" stroke-width=\"\(f(width))\"/>\n"
            case let .polyline(points, stroke, width):
                let list = points.map { "\(f($0.0)),\(f($0.1))" }.joined(separator: " ")
                out += "<polyline points=\"\(list)\" fill=\"none\" stroke=\"\(style.palette.hex(stroke))\" "
                    + "stroke-width=\"\(f(width))\"/>\n"
            case let .circle(x, y, radius, fill):
                out += "<circle cx=\"\(f(x))\" cy=\"\(f(y))\" r=\"\(f(radius))\" "
                    + "fill=\"\(style.palette.hex(fill))\"/>\n"
            case let .polygon(points, fill, opacity):
                let list = points.map { "\(f($0.0)),\(f($0.1))" }.joined(separator: " ")
                out += "<polygon points=\"\(list)\" fill=\"\(style.palette.hex(fill))\" "
                    + "fill-opacity=\"\(f(opacity))\" stroke=\"none\"/>\n"
            case let .text(x, y, string, size, anchor, fill):
                out += "<text x=\"\(f(x))\" y=\"\(f(y))\" font-size=\"\(f(size))\" "
                    + "text-anchor=\"\(anchor.rawValue)\" fill=\"\(style.palette.hex(fill))\" "
                    + "font-family=\"-apple-system, Helvetica, sans-serif\">"
                    + escapeXML(string) + "</text>\n"
            }
        }
        return out + "</svg>\n"
    }

    /// Thoát XML. Nhãn trục là DỮ LIỆU của người dùng — một tên tỉnh có `&` là đủ để sinh ra
    /// một tệp SVG không mở được.
    static func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func f(_ value: Double) -> String {
        // Ba chữ số thập phân là quá đủ cho toạ độ điểm ảnh, và nó giữ tệp SVG nhỏ và diff được.
        value == value.rounded() ? String(Int(value)) : String(format: "%.3f", value)
    }
}

// MARK: - Biểu đồ dự báo (FR-MIN-004)

extension ChartRender {

    /// Lịch sử + đường dự báo + hai dải tin cậy, trên MỘT hệ trục.
    ///
    /// ## Vì sao đây là một bộ dựng riêng chứ không phải một `Kind` mới
    ///
    /// Mọi `Kind` hiện có nhận đúng MỘT dãy điểm. Biểu đồ dự báo có bốn thứ trên cùng một trục —
    /// lịch sử, đường khớp, đường dự báo, và hai dải — và chúng phải chia CHUNG thang đo. Nhét
    /// vào khuôn một-dãy sẽ phải gọi bốn lần rồi ghép, và bốn lần gọi ấy mỗi lần tự tính thang
    /// riêng: bốn hình đúng chồng lên nhau thành một hình sai.
    ///
    /// Thang tính MỘT LẦN trên hợp của tất cả, kể cả mép ngoài của dải 95% — nếu không thì dải
    /// bị cắt cụt ở mép khung và người đọc thấy một dải hẹp hơn thực tế.
    public static func forecastPrimitives(
        history: [Double], fitted: [Double?], future: [Double],
        lower80: [Double], upper80: [Double], lower95: [Double], upper95: [Double],
        layout: Layout, title: String = "", note: String = "", style: Style = .default
    ) -> [Primitive] {
        guard !history.isEmpty, !future.isEmpty else { return empty(layout) }

        let everything = history + future + lower95 + upper95
        let ticks = ChartData.ticks(from: everything.min() ?? 0, to: everything.max() ?? 1)
        let yLow = min(everything.min() ?? 0, ticks.first ?? 0)
        let yHigh = max(everything.max() ?? 1, ticks.last ?? 1)
        var out = frame(layout, yTicks: ticks, yLow: yLow, yHigh: yHigh, style)

        let ySpan = max(yHigh - yLow, .leastNormalMagnitude)
        let total = Double(history.count + future.count - 1)
        func place(_ index: Double, _ value: Double) -> (Double, Double) {
            (layout.insetLeft + layout.plotWidth * index / max(1, total),
             layout.insetTop + layout.plotHeight * (1 - (value - yLow) / ySpan))
        }

        // Dải VẼ TRƯỚC để đường nằm đè lên. Dải 95 trước dải 80 vì nó rộng hơn.
        //
        // Dải bắt đầu từ điểm LỊCH SỬ CUỐI CÙNG, không từ kỳ dự báo đầu tiên: một dải lơ lửng
        // tách khỏi đường lịch sử đọc thành "có một khoảng trống không biết gì", trong khi thực
        // ra kỳ đầu tiên chính là chỗ ta chắc chắn nhất.
        let anchor = Double(history.count - 1)
        let anchorValue = history[history.count - 1]
        for (lower, upper, opacity) in [
            (lower95, upper95, 0.12), (lower80, upper80, 0.18),
        ] {
            var points: [(Double, Double)] = [place(anchor, anchorValue)]
            for step in future.indices {
                points.append(place(anchor + Double(step + 1), upper[step]))
            }
            for step in future.indices.reversed() {
                points.append(place(anchor + Double(step + 1), lower[step]))
            }
            out.append(.polygon(points: points, fill: .series2, opacity: opacity))
        }

        // Lịch sử.
        out.append(.polyline(
            points: history.enumerated().map { place(Double($0.offset), $0.element) },
            stroke: .series1, width: 1.5))

        // Đường khớp — mỏng hơn và màu khác: nó là mô hình nhìn về QUÁ KHỨ, không phải dữ liệu.
        let fittedPoints = fitted.enumerated().compactMap { entry -> (Double, Double)? in
            guard let value = entry.element, value.isFinite else { return nil }
            return place(Double(entry.offset), value)
        }
        if fittedPoints.count > 1 {
            out.append(.polyline(points: fittedPoints, stroke: .series4, width: 1))
        }

        // Dự báo, nối liền từ điểm lịch sử cuối.
        var futurePoints: [(Double, Double)] = [place(anchor, anchorValue)]
        for step in future.indices {
            futurePoints.append(place(anchor + Double(step + 1), future[step]))
        }
        out.append(.polyline(points: futurePoints, stroke: .series2, width: 2))

        // Vạch dọc ở ranh giới quá khứ / tương lai. Thiếu nó thì người đọc không biết đường
        // cong chuyển từ dữ liệu sang phỏng đoán ở đâu — và đó là thông tin quan trọng nhất
        // trên hình.
        let boundary = place(anchor, yHigh).0
        out.append(.line(
            x1: boundary, y1: layout.insetTop, x2: boundary,
            y2: layout.insetTop + layout.plotHeight, stroke: .axis, width: 0.5))
        out.append(.text(
            x: boundary + 3, y: layout.insetTop + 10, string: "dự báo →", size: 9,
            anchor: .start, fill: .label))

        out += titleText(title, layout)
        if !note.isEmpty {
            out.append(.text(
                x: layout.insetLeft, y: layout.height - 6, string: note, size: 9,
                anchor: .start, fill: .warning))
        }
        return out
    }
}
