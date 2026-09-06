import Foundation

/// Chuẩn bị dữ liệu cho biểu đồ — FR-QRY-004, và là nền cho FR-MIN-002/004/005,
/// FR-RPT-001/002/003, FR-DQR-004.
///
/// ## Vì sao phần TÍNH nằm ở lõi, tách khỏi phần VẼ
///
/// Tám yêu cầu vẽ bằng cùng bộ này. Nếu phép rút gọn, phép chia khoảng và phép tính hộp nằm
/// trong một `NSView` thì chúng chỉ kiểm được bằng cách dựng cửa sổ — tức chỉ kiểm được ở tầng
/// tự kiểm giao diện, nơi mỗi bài chạy chậm hơn ba bậc và đọc kết quả bằng cách soi điểm ảnh.
/// Ở đây chúng là số học thuần: vào là mảng số, ra là mảng số, và một bài kiểm chạy trong
/// micro-giây so được từng chữ số.
///
/// ## Rút gọn phải NÓI RA
///
/// NFR-QRY-02: *"Render biểu đồ từ 1 triệu điểm ≤ 2 giây nhờ downsample tự động (ghi chú rõ mức
/// lấy mẫu trên biểu đồ)"*. Vế trong ngoặc quan trọng ngang vế đầu: vẽ một triệu điểm xuống 800
/// điểm ảnh rồi im lặng là **nói dối bằng hình** — người xem tưởng mình đang nhìn toàn bộ dữ
/// liệu. Nên `Series` luôn mang theo `samplingNote`, và nó rỗng khi và chỉ khi không rút gọn gì.
public enum ChartData {

    public enum Kind: String, CaseIterable, Equatable, Sendable {
        case bar, line, histogram, scatter, box

        public var vietnamese: String {
            switch self {
            case .bar: return "Cột"
            case .line: return "Đường"
            case .histogram: return "Phân bố"
            case .scatter: return "Phân tán"
            case .box: return "Hộp"
            }
        }
    }

    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double
        /// Nhãn trục X khi dữ liệu là chữ (biểu đồ cột theo tỉnh…). `nil` khi X là số.
        public var label: String?

        public init(x: Double, y: Double, label: String? = nil) {
            self.x = x
            self.y = y
            self.label = label
        }
    }

    public struct Series: Equatable, Sendable {
        public var name: String
        public var points: [Point]
        /// Số điểm TRƯỚC khi rút gọn.
        public var originalCount: Int
        /// Rỗng khi không rút gọn gì. Xem ghi chú ở đầu tệp.
        public var samplingNote: String

        public init(
            name: String, points: [Point], originalCount: Int, samplingNote: String = ""
        ) {
            self.name = name
            self.points = points
            self.originalCount = originalCount
            self.samplingNote = samplingNote
        }
    }

    /// Trần điểm vẽ.
    ///
    /// 2.000: gấp đôi bề ngang một cửa sổ thường, nên mỗi điểm ảnh vẫn có hơn một điểm dữ liệu
    /// và đường cong không bị "gãy" thấy được. Vẽ nhiều hơn thế là tô đi tô lại cùng một cột
    /// điểm ảnh — tốn thời gian mà mắt không nhận được gì thêm.
    public static let maximumPoints = 2_000

    // MARK: - Từ kết quả truy vấn

    /// Chọn cột và dựng dãy từ một bảng kết quả.
    ///
    /// Luật chọn, và nó cố ý ĐƠN GIẢN và ĐOÁN ĐƯỢC:
    ///
    /// - Cột **số đầu tiên** làm trục Y. Đó gần như luôn là thứ người ta vừa `SUM`/`COUNT` ra.
    /// - Cột **trước nó** làm trục X nếu có; không thì dùng chỉ số hàng.
    ///
    /// Không đoán thông minh hơn thế. Một phép chọn "thông minh" đúng tám lần trong mười lại tệ
    /// hơn một phép chọn máy móc đúng tám lần: người dùng học được luật máy móc sau hai lần
    /// dùng, còn luật thông minh thì họ không bao giờ đoán được lần thứ chín nó làm gì.
    ///
    /// Trả `nil` khi không có cột số nào — vẽ biểu đồ từ một bảng toàn chữ là vẽ ra một thứ
    /// không có nghĩa, và im lặng làm thế còn tệ hơn từ chối.
    public static func series(
        from result: CSVQueryEngine.Result, limit: Int = maximumPoints
    ) -> Series? {
        guard !result.rows.isEmpty else { return nil }
        // Cột số = cột mà MỌI ô không rỗng đều đọc được thành số. Chỉ nhìn ô đầu là đủ để một
        // cột mã bưu chính "01000" bị coi là số và một cột lẫn chữ ở hàng thứ hai làm hỏng cả
        // biểu đồ.
        func isNumeric(_ column: Int) -> Bool {
            var sawValue = false
            for row in result.rows {
                guard column < row.count, let text = row[column], !text.isEmpty else { continue }
                guard Double(text) != nil else { return false }
                sawValue = true
            }
            return sawValue
        }
        guard let firstNumeric = result.titles.indices.first(where: isNumeric) else { return nil }

        // Cột số đầu tiên làm trục Y, cột ngay TRƯỚC nó làm nhãn trục X. Luật ấy đúng cho hình
        // dạng thường gặp nhất — `SELECT tinh, doanh_thu` — nhưng vỡ ở đúng một chỗ: khi cột
        // đầu bảng đã là số.
        //
        // `SELECT diem, so_bai FROM t GROUP BY 1 ORDER BY 1` cho ra hai cột số. Luật cũ chọn
        // `diem` làm Y và không còn cột nào làm X, nên biểu đồ vẽ ĐIỂM theo chỉ số hàng: một
        // đường đi lên đều tăm tắp. Nó KHÔNG trống, KHÔNG báo lỗi, và trông hoàn toàn hợp lý —
        // chỉ là nó vẽ khoá thay vì vẽ số đo. Đã gặp thật khi chụp phổ điểm 1,2 triệu bài, và
        // cùng họ với lỗi `AnomalyPanel` mặc định lấy cột số đầu tiên (hoá ra là `ma_tinh`).
        //
        // Nên: cột đầu là số MÀ còn cột số khác phía sau thì cột đầu là KHOÁ, không phải số đo.
        // Đẩy Y sang cột số kế tiếp và lấy cột đầu làm X. Bảng chỉ có một cột số thì giữ nguyên
        // như cũ — khi ấy cột ấy đúng là thứ duy nhất vẽ được.
        let nextNumeric = result.titles.indices
            .dropFirst(firstNumeric + 1)
            .first(where: isNumeric)
        let yColumn = (firstNumeric == 0 ? nextNumeric : nil) ?? firstNumeric
        let xColumn = yColumn > 0 ? yColumn - 1 : nil

        var points: [Point] = []
        points.reserveCapacity(result.rows.count)
        for (index, row) in result.rows.enumerated() {
            guard yColumn < row.count, let text = row[yColumn], let y = Double(text) else {
                continue
            }
            let label = xColumn.flatMap { column -> String? in
                column < row.count ? row[column] : nil
            }
            // Trục X là số khi nhãn đọc được thành số; không thì dùng chỉ số hàng và giữ nhãn
            // để vẽ chữ.
            let x = label.flatMap(Double.init) ?? Double(index)
            points.append(Point(x: x, y: y, label: label))
        }
        guard !points.isEmpty else { return nil }
        return series(name: result.titles[yColumn], points: points, limit: limit)
    }

    /// Dãy cho biểu đồ PHÂN BỐ — mỗi điểm là một khoảng.
    public static func histogramSeries(
        from result: CSVQueryEngine.Result
    ) -> Series? {
        guard let base = series(from: result, limit: Int.max) else { return nil }
        let bins = histogram(base.points.map(\.y))
        guard !bins.isEmpty else { return nil }
        let points = bins.map {
            Point(x: $0.lowerBound, y: Double($0.count),
                  label: ChartData.shortNumber($0.lowerBound))
        }
        return Series(name: base.name, points: points, originalCount: base.points.count)
    }

    static func shortNumber(_ value: Double) -> String {
        if abs(value) >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if abs(value) >= 1_000 { return String(format: "%.0fk", value / 1_000) }
        return value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    // MARK: - Rút gọn LTTB

    /// Largest-Triangle-Three-Buckets — giữ HÌNH DÁNG, không giữ khoảng cách đều.
    ///
    /// Vì sao không lấy mẫu đều (mỗi 500 điểm lấy 1): một đỉnh nhọn nằm giữa hai mốc lấy mẫu sẽ
    /// **biến mất hoàn toàn**, và với dữ liệu doanh thu hay đo lường thì đỉnh nhọn thường là
    /// thứ người ta mở biểu đồ ra để tìm. LTTB chọn trong mỗi khoảng điểm tạo TAM GIÁC LỚN NHẤT
    /// với điểm đã chọn trước đó và trung bình khoảng sau — tức ưu tiên điểm làm đường đổi hướng
    /// mạnh nhất, đúng thứ mắt người coi là "hình dáng".
    ///
    /// Điểm ĐẦU và CUỐI luôn được giữ: một biểu đồ mất điểm đầu là một biểu đồ bắt đầu ở chỗ
    /// khác với dữ liệu.
    public static func downsample(_ points: [Point], to threshold: Int) -> [Point] {
        guard threshold >= 3, points.count > threshold else { return points }

        var sampled: [Point] = []
        sampled.reserveCapacity(threshold)
        // Trừ 2 vì điểm đầu và cuối nằm ngoài các khoảng.
        let bucketSize = Double(points.count - 2) / Double(threshold - 2)
        sampled.append(points[0])
        var previous = 0

        for bucket in 0 ..< (threshold - 2) {
            // Trung bình của khoảng KẾ TIẾP — đỉnh thứ ba của tam giác.
            let nextStart = Int((Double(bucket + 1) * bucketSize).rounded(.down)) + 1
            let nextEnd = min(
                Int((Double(bucket + 2) * bucketSize).rounded(.down)) + 1, points.count)
            var averageX = 0.0
            var averageY = 0.0
            let nextCount = max(1, nextEnd - nextStart)
            for index in nextStart ..< max(nextStart + 1, nextEnd) where index < points.count {
                averageX += points[index].x
                averageY += points[index].y
            }
            averageX /= Double(nextCount)
            averageY /= Double(nextCount)

            let start = Int((Double(bucket) * bucketSize).rounded(.down)) + 1
            let end = min(Int((Double(bucket + 1) * bucketSize).rounded(.down)) + 1, points.count)
            var best = start
            var bestArea = -1.0
            let anchor = points[previous]
            for index in start ..< max(start + 1, end) where index < points.count {
                // Diện tích tam giác × 2, không cần chia đôi vì chỉ đem so với nhau.
                let area = abs(
                    (anchor.x - averageX) * (points[index].y - anchor.y)
                        - (anchor.x - points[index].x) * (averageY - anchor.y))
                if area > bestArea {
                    bestArea = area
                    best = index
                }
            }
            sampled.append(points[best])
            previous = best
        }
        sampled.append(points[points.count - 1])
        return sampled
    }

    /// Rút gọn nếu cần, và **ghi lại là đã rút gọn**.
    public static func series(
        name: String, points: [Point], limit: Int = maximumPoints
    ) -> Series {
        guard points.count > limit else {
            return Series(name: name, points: points, originalCount: points.count)
        }
        let reduced = downsample(points, to: limit)
        return Series(
            name: name, points: reduced, originalCount: points.count,
            samplingNote: "Đã rút gọn \(points.count) điểm còn \(reduced.count) để vẽ "
                + "(giữ hình dáng bằng LTTB) — biểu đồ này KHÔNG hiện mọi điểm dữ liệu.")
    }

    // MARK: - Phân bố (histogram)

    public struct Bin: Equatable, Sendable {
        public var lowerBound: Double
        public var upperBound: Double
        public var count: Int

        public init(lowerBound: Double, upperBound: Double, count: Int) {
            self.lowerBound = lowerBound
            self.upperBound = upperBound
            self.count = count
        }
    }

    /// Chia khoảng theo **Freedman–Diaconis**, có sàn và trần.
    ///
    /// Bề rộng khoảng = 2 × IQR / ∛n. Chọn quy tắc này thay vì Sturges vì nó dựa vào IQR nên
    /// **không bị một giá trị cực đoan kéo lệch**: một ô doanh thu 999 tỷ giữa bảng sẽ khiến
    /// quy tắc theo biên độ chia ra một khoảng chứa tất cả và mấy chục khoảng rỗng.
    ///
    /// Kẹp trong 5…60 khoảng: dưới 5 thì không còn là phân bố, trên 60 thì mỗi cột mảnh hơn một
    /// điểm ảnh trên màn hình thường.
    public static func histogram(_ values: [Double], binCount: Int? = nil) -> [Bin] {
        let clean = values.filter { $0.isFinite }.sorted()
        guard let low = clean.first, let high = clean.last else { return [] }
        guard clean.count > 1 else {
            return [Bin(lowerBound: low, upperBound: high, count: 1)]
        }
        guard high > low else {
            // Mọi giá trị bằng nhau: một khoảng, và nói đúng như thế. Chia nó thành hai mươi
            // khoảng rỗng quanh một cột là vẽ ra một phân bố không tồn tại.
            return [Bin(lowerBound: low, upperBound: high, count: clean.count)]
        }

        let count: Int
        if let binCount {
            count = max(1, binCount)
        } else {
            let q1 = quantile(clean, 0.25)
            let q3 = quantile(clean, 0.75)
            let iqr = q3 - q1
            let width = iqr > 0
                ? 2 * iqr / pow(Double(clean.count), 1.0 / 3.0)
                : (high - low) / 10
            count = width > 0
                ? min(60, max(5, Int(((high - low) / width).rounded(.up))))
                : 10
        }

        let width = (high - low) / Double(count)
        var bins = (0 ..< count).map { index in
            Bin(lowerBound: low + Double(index) * width,
                upperBound: low + Double(index + 1) * width, count: 0)
        }
        for value in clean {
            // Giá trị lớn nhất rơi vào khoảng CUỐI, không rơi ra ngoài. Không có dòng này thì
            // đúng một điểm — điểm cao nhất — biến mất khỏi mọi biểu đồ phân bố.
            let index = min(count - 1, Int((value - low) / width))
            bins[index].count += 1
        }
        return bins
    }

    // MARK: - Hộp (box plot)

    public struct BoxStats: Equatable, Sendable {
        public var minimum: Double
        public var q1: Double
        public var median: Double
        public var q3: Double
        public var maximum: Double
        /// Đầu râu dưới/trên — biên trong phạm vi 1,5 × IQR, KHÔNG phải min/max.
        public var lowerWhisker: Double
        public var upperWhisker: Double
        public var outliers: [Double]

        public init(
            minimum: Double, q1: Double, median: Double, q3: Double, maximum: Double,
            lowerWhisker: Double, upperWhisker: Double, outliers: [Double]
        ) {
            self.minimum = minimum
            self.q1 = q1
            self.median = median
            self.q3 = q3
            self.maximum = maximum
            self.lowerWhisker = lowerWhisker
            self.upperWhisker = upperWhisker
            self.outliers = outliers
        }
    }

    /// Năm số của biểu đồ hộp, cộng râu 1,5 × IQR và danh sách điểm ngoài.
    ///
    /// Râu dừng ở **giá trị THẬT gần nhất còn nằm trong 1,5 × IQR**, không dừng ở đúng con số
    /// `q1 − 1,5 × IQR`. Vẽ râu tới một chỗ không có dữ liệu là vẽ ra một khoảng trống trông
    /// như có dữ liệu.
    public static func box(_ values: [Double]) -> BoxStats? {
        let clean = values.filter { $0.isFinite }.sorted()
        guard let minimum = clean.first, let maximum = clean.last else { return nil }
        let q1 = quantile(clean, 0.25)
        let median = quantile(clean, 0.5)
        let q3 = quantile(clean, 0.75)
        let iqr = q3 - q1
        let lowerFence = q1 - 1.5 * iqr
        let upperFence = q3 + 1.5 * iqr
        let inside = clean.filter { $0 >= lowerFence && $0 <= upperFence }
        return BoxStats(
            minimum: minimum, q1: q1, median: median, q3: q3, maximum: maximum,
            lowerWhisker: inside.first ?? minimum,
            upperWhisker: inside.last ?? maximum,
            outliers: clean.filter { $0 < lowerFence || $0 > upperFence })
    }

    /// Phân vị theo nội suy tuyến tính (kiểu R type 7 — cũng là mặc định của numpy).
    ///
    /// Nói rõ KIỂU vì có chín định nghĩa phân vị khác nhau và chúng cho số khác nhau trên mẫu
    /// nhỏ. Một biểu đồ hộp mà người dùng đối chiếu với numpy phải khớp, nếu không họ sẽ tin
    /// numpy và nghĩ GEditor sai.
    public static func quantile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        guard sorted.count > 1 else { return sorted[0] }
        let position = fraction * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    // MARK: - Vạch trục

    /// Vạch trục ở những con số ĐẸP — 1, 2, 5 × 10ⁿ.
    ///
    /// Chia đều biên độ cho 5 sẽ ra những vạch như `0 · 237 · 474 · 711` — đúng về khoảng cách
    /// và vô dụng khi đọc. Người ta đọc biểu đồ bằng cách so mắt với vạch, nên vạch phải là số
    /// nhẩm được.
    public static func ticks(from low: Double, to high: Double, count: Int = 5) -> [Double] {
        guard high > low, count > 1 else { return [low] }
        let rawStep = (high - low) / Double(count - 1)
        let magnitude = pow(10, (log10(rawStep)).rounded(.down))
        let normalized = rawStep / magnitude
        // Làm tròn về GẦN NHẤT, không làm tròn lên (Heckbert).
        //
        // Làm tròn lên thì bước 237 thành 500, và một trục 0…948 chỉ còn hai vạch: `0` và
        // `500`. Đúng là số đẹp, và vô dụng — người ta đọc biểu đồ bằng cách so mắt với vạch,
        // nên hai vạch trên cả chiều cao là không so được với gì.
        let niceStep = (normalized < 1.5 ? 1.0
            : normalized < 3 ? 2.0
            : normalized < 7 ? 5.0 : 10.0) * magnitude
        var result: [Double] = []
        var value = (low / niceStep).rounded(.down) * niceStep
        while value <= high + niceStep * 0.001 {
            if value >= low - niceStep * 0.001 { result.append(value) }
            value += niceStep
        }
        return result
    }
}
