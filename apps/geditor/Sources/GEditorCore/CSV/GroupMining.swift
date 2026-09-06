import Foundation

/// Khai phá theo nhóm — FR-MIN-007.
///
/// Đặc tả: *"Chọn cột nhóm (vd: tỉnh, chi nhánh) → chạy bất thường / dự báo / tương quan cho
/// TỪNG NHÓM độc lập: mỗi tỉnh một model Holt-Winters riêng với chu kỳ tự phát hiện riêng; mỗi
/// nhóm một ngưỡng IQR riêng (tránh outlier giả do trộn phân bố khác nhau — lỗi kinh điển). Đầu
/// ra: BẢNG XẾP HẠNG NHÓM … trần 1.000 nhóm có cảnh báo."*
///
/// ## Đặc tả tự gọi tên cái bẫy, và nó nghiêm trọng theo CẢ HAI chiều
///
/// Trộn hai phân bố rồi đặt một ngưỡng chung hỏng theo hai hướng, và hướng thứ hai nguy hiểm hơn:
///
/// **Bỏ SÓT.** Hai chi nhánh, một quanh 10 và một quanh 100. Gộp lại thì Q1 ≈ 10, Q3 ≈ 100, nên
/// IQR ≈ 90 và hàng rào rộng tới ±135 — một giá trị 20 ở chi nhánh nhỏ (gấp đôi mức bình thường
/// của nó, rõ ràng bất thường) lọt qua không một tiếng động. Ngưỡng chung càng nhiều nhóm càng
/// rộng, tức **càng nhiều dữ liệu thì càng mù**.
///
/// **Báo NHẦM.** Ngược lại, một nhóm có độ phân tán lớn hơn hẳn sẽ bị hàng rào chung cắt mất
/// phần đuôi hoàn toàn bình thường của nó, và người dùng nhận một danh sách vài trăm "bất
/// thường" đều là dương tính giả — rồi họ bỏ cả tính năng.
///
/// Cách chữa duy nhất là **mỗi nhóm một ngưỡng của riêng nó**, và đó là toàn bộ lý do yêu cầu
/// này tồn tại tách khỏi FR-MIN-001.
///
/// ## "Nhóm lệch tương quan" là chỗ bắt nghịch lý Simpson
///
/// Cột xếp hạng thứ ba đo `|r(nhóm) − r(toàn bộ)|`. Nó không phải một chỉ số trang trí: khi mọi
/// nhóm có tương quan ÂM mà tập gộp lại cho tương quan DƯƠNG, kết luận rút ra từ bảng gộp là
/// kết luận ngược. Bảng xếp hạng đưa những nhóm ấy lên đầu, nơi người ta nhìn thấy.
public enum GroupMining {

    /// Trần số nhóm. Vượt thì cắt và CẢNH BÁO — không im lặng cắt, và cũng không chạy tiếp.
    ///
    /// Một cột nhóm chọn nhầm (mã đơn hàng chẳng hạn) sinh ra một nhóm cho mỗi hàng, và khi ấy
    /// mỗi "nhóm" một hàng thì không thống kê được gì. Trần này chủ yếu bắt tình huống ấy.
    public static let groupLimit = 1_000

    public struct Options: Equatable, Sendable {
        /// Cột chạy bất thường. `nil` = bỏ qua phần này.
        public var anomalyColumn: String?
        /// Cột chạy dự báo. `nil` = bỏ qua.
        public var forecastColumn: String?
        /// Cặp cột chạy tương quan. `nil` = bỏ qua.
        public var correlationPair: (String, String)?
        public var horizon: Int
        public var iqrK: Double
        /// Số hàng tối thiểu để một nhóm được chấm. Nhóm nhỏ hơn vẫn hiện, kèm lý do.
        public var minimumRows: Int

        public init(
            anomalyColumn: String? = nil, forecastColumn: String? = nil,
            correlationPair: (String, String)? = nil, horizon: Int = 4,
            iqrK: Double = 1.5, minimumRows: Int = 8
        ) {
            self.anomalyColumn = anomalyColumn
            self.forecastColumn = forecastColumn
            self.correlationPair = correlationPair
            self.horizon = horizon
            self.iqrK = iqrK
            self.minimumRows = minimumRows
        }

        public static func == (lhs: Options, rhs: Options) -> Bool {
            lhs.anomalyColumn == rhs.anomalyColumn
                && lhs.forecastColumn == rhs.forecastColumn
                && lhs.correlationPair?.0 == rhs.correlationPair?.0
                && lhs.correlationPair?.1 == rhs.correlationPair?.1
                && lhs.horizon == rhs.horizon && lhs.iqrK == rhs.iqrK
                && lhs.minimumRows == rhs.minimumRows
        }
    }

    public struct GroupResult: Equatable, Sendable {
        public var name: String
        public var rowCount: Int
        /// Chỉ số hàng GỐC thuộc nhóm này — để drill xuống và để tô Mark.
        public var rowIndices: [Int]

        /// Số dòng bất thường theo ngưỡng CỦA RIÊNG NHÓM.
        public var anomalies: Int
        public var anomalyRate: Double
        /// Hàng rào IQR của riêng nhóm, để người dùng thấy nó khác nhóm khác.
        public var fence: (low: Double, high: Double)?

        /// MAPE của mô hình tốt nhất trên nhóm. `nil` khi không dự báo được.
        public var mape: Double?
        public var forecastVerdict: String
        public var period: Int?

        /// Tương quan của cặp cột trong nhóm này.
        public var correlation: Double?
        /// `|r(nhóm) − r(toàn bộ)|`. `nil` khi một trong hai không đo được.
        public var correlationGap: Double?

        /// Vì sao nhóm này không chấm được (quá ít hàng…). Rỗng khi chấm bình thường.
        public var note: String

        public init(
            name: String, rowCount: Int, rowIndices: [Int], anomalies: Int, anomalyRate: Double,
            fence: (low: Double, high: Double)?, mape: Double?, forecastVerdict: String,
            period: Int?, correlation: Double?, correlationGap: Double?, note: String
        ) {
            self.name = name
            self.rowCount = rowCount
            self.rowIndices = rowIndices
            self.anomalies = anomalies
            self.anomalyRate = anomalyRate
            self.fence = fence
            self.mape = mape
            self.forecastVerdict = forecastVerdict
            self.period = period
            self.correlation = correlation
            self.correlationGap = correlationGap
            self.note = note
        }

        public static func == (lhs: GroupResult, rhs: GroupResult) -> Bool {
            lhs.name == rhs.name && lhs.rowCount == rhs.rowCount
                && lhs.rowIndices == rhs.rowIndices && lhs.anomalies == rhs.anomalies
                && lhs.anomalyRate == rhs.anomalyRate
                && lhs.fence?.low == rhs.fence?.low && lhs.fence?.high == rhs.fence?.high
                && lhs.mape == rhs.mape && lhs.forecastVerdict == rhs.forecastVerdict
                && lhs.period == rhs.period && lhs.correlation == rhs.correlation
                && lhs.correlationGap == rhs.correlationGap && lhs.note == rhs.note
        }
    }

    public struct Report: Equatable, Sendable {
        public var groups: [GroupResult]
        /// Số nhóm đã bị cắt vì chạm trần. 0 khi không cắt.
        public var truncated: Int
        /// Tương quan trên TOÀN BỘ, mốc để đo độ lệch của từng nhóm.
        public var pooledCorrelation: Double?
        public var methodology: String
        /// Người dùng đã HUỶ giữa chừng — bảng chỉ có phần đã chạy xong.
        ///
        /// NFR-MIN-05 đòi đúng chữ này: *"HỦY giữa chừng giữ nguyên kết quả các nhóm đã hoàn
        /// tất (partial results hợp lệ, **đánh dấu rõ**)"*. Hai vế, và vế thứ hai mới là vế
        /// khó: một bảng 300 nhóm trông y hệt một bảng 1.000 nhóm bị cắt, nên nếu không đánh
        /// dấu thì người dùng đọc nó như kết quả đầy đủ và kết luận về những nhóm chưa từng
        /// được chấm.
        public var cancelled: Bool

        public init(
            groups: [GroupResult], truncated: Int, pooledCorrelation: Double?,
            methodology: String, cancelled: Bool = false
        ) {
            self.groups = groups
            self.truncated = truncated
            self.pooledCorrelation = pooledCorrelation
            self.methodology = methodology
            self.cancelled = cancelled
        }

        /// Ba bảng xếp hạng mà đặc tả đòi.
        public func ranked(by key: Ranking, limit: Int = 10) -> [GroupResult] {
            let scored = groups.filter { $0.note.isEmpty }
            switch key {
            case .anomalies:
                return Array(scored.sorted { $0.anomalyRate > $1.anomalyRate }.prefix(limit))
            case .forecastError:
                return Array(scored.filter { $0.mape != nil }
                    .sorted { ($0.mape ?? 0) > ($1.mape ?? 0) }.prefix(limit))
            case .correlationGap:
                return Array(scored.filter { $0.correlationGap != nil }
                    .sorted { ($0.correlationGap ?? 0) > ($1.correlationGap ?? 0) }
                    .prefix(limit))
            }
        }
    }

    public enum Ranking: String, CaseIterable, Equatable, Sendable {
        case anomalies, forecastError, correlationGap

        public var vietnamese: String {
            switch self {
            case .anomalies: return "Nhiều bất thường nhất"
            case .forecastError: return "Dự báo tệ nhất (MAPE)"
            case .correlationGap: return "Lệch tương quan nhiều nhất"
            }
        }
    }

    // MARK: - Chạy

    /// - Parameter labels: giá trị cột nhóm cho từng hàng. `nil` = hàng không thuộc nhóm nào.
    /// - Parameter values: dữ liệu theo CỘT, `values[j][i]` là hàng i của cột j.
    public static func run(
        labels: [String?], columns: [String], values: [[Double]], options: Options,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Report {
        func columnIndex(_ name: String?) -> Int? {
            name.flatMap { columns.firstIndex(of: $0) }
        }
        let anomalyIndex = columnIndex(options.anomalyColumn)
        let forecastIndex = columnIndex(options.forecastColumn)
        let pairIndex = options.correlationPair.flatMap { pair -> (Int, Int)? in
            guard let first = columnIndex(pair.0), let second = columnIndex(pair.1) else {
                return nil
            }
            return (first, second)
        }

        // Gom nhóm GIỮ NGUYÊN thứ tự xuất hiện đầu tiên, không sắp theo tên.
        //
        // Thứ tự xuất hiện là thứ tự trong file, và với dữ liệu chuỗi thời gian thì thứ tự ấy
        // MANG NGHĨA — phần dự báo bên dưới đọc từng nhóm theo đúng thứ tự hàng gốc. Sắp lại
        // theo tên ở đây sẽ không đổi kết quả (mỗi nhóm vẫn giữ thứ tự nội bộ), nhưng nó làm
        // bảng nhảy lung tung giữa hai lần chạy trên hai file cùng nội dung khác thứ tự.
        var order: [String] = []
        var buckets: [String: [Int]] = [:]
        for (row, label) in labels.enumerated() {
            guard let label else { continue }
            if buckets[label] == nil {
                buckets[label] = []
                order.append(label)
            }
            buckets[label]?.append(row)
        }

        var truncated = 0
        if order.count > groupLimit {
            truncated = order.count - groupLimit
            order = Array(order.prefix(groupLimit))
        }

        // Mốc tương quan trên TOÀN BỘ, để đo độ lệch của từng nhóm.
        var pooled: Double?
        if let pairIndex {
            pooled = Correlation.pearson(
                cleaned(values[pairIndex.0], values[pairIndex.1]).0,
                cleaned(values[pairIndex.0], values[pairIndex.1]).1)
        }

        var results: [GroupResult] = []
        var cancelled = false
        for name in order {
            // Huỷ thì DỪNG, không NÉM.
            //
            // Bản trước gọi `try cancelToken.check()` ở đây, nên một cú huỷ cuốn theo mọi nhóm
            // đã chấm xong — trong khi NFR-MIN-05 nói thẳng là phải giữ chúng lại. Lỗi ấy nằm
            // im suốt từ khi cụm FR-MIN khép, vì không bài kiểm nào từng huỷ giữa chừng: nó chỉ
            // lộ ra khi có người ĐO chỉ tiêu thay vì đọc mã.
            if cancelToken.isCancelled {
                cancelled = true
                break
            }
            let rows = buckets[name] ?? []
            guard rows.count >= options.minimumRows else {
                results.append(GroupResult(
                    name: name, rowCount: rows.count, rowIndices: rows, anomalies: 0,
                    anomalyRate: 0, fence: nil, mape: nil, forecastVerdict: "", period: nil,
                    correlation: nil, correlationGap: nil,
                    note: "chỉ \(rows.count) hàng — cần ít nhất \(options.minimumRows) "
                        + "để thống kê nói được gì"))
                continue
            }

            // --- Bất thường: NGƯỠNG CỦA RIÊNG NHÓM ------------------------------------------
            var anomalies = 0
            var fence: (low: Double, high: Double)?
            if let anomalyIndex {
                let series = rows.map { values[anomalyIndex][$0] }.filter { $0.isFinite }
                if series.count >= 4 {
                    let sorted = series.sorted()
                    let q1 = ChartData.quantile(sorted, 0.25)
                    let q3 = ChartData.quantile(sorted, 0.75)
                    let iqr = q3 - q1
                    if iqr > 0 {
                        let low = q1 - options.iqrK * iqr
                        let high = q3 + options.iqrK * iqr
                        fence = (low, high)
                        anomalies = series.filter { $0 < low || $0 > high }.count
                    }
                }
            }

            // --- Dự báo: chu kỳ TỰ PHÁT HIỆN RIÊNG cho mỗi nhóm -----------------------------
            var mape: Double?
            var verdict = ""
            var period: Int?
            if let forecastIndex {
                let series = rows.map { values[forecastIndex][$0] }.filter { $0.isFinite }
                // Huỷ NÉM RA TỪ BÊN TRONG phép dự báo, và nó phải dừng ở đây chứ không cuốn cả
                // hàm. Đây là nửa còn lại của lỗi "mất sạch kết quả khi huỷ": chặn ở đầu vòng
                // lặp thôi thì chưa đủ, vì phần lớn thời gian nằm TRONG một nhóm chứ không giữa
                // hai nhóm — nên cú huỷ gần như luôn rơi vào giữa một phép dự báo.
                //
                // Nhóm đang dở bị BỎ, không nửa vời: một hàng có `anomalies` mà thiếu `mape`
                // trông y hệt một nhóm mà dự báo không kết luận được.
                do {
                    if let comparison = try TimeSeries.forecast(
                        series, horizon: options.horizon, cancelToken: cancelToken) {
                        mape = comparison.chosen.accuracy?.mape
                        verdict = comparison.verdict
                        period = comparison.period
                    }
                } catch {
                    cancelled = true
                    break
                }
            }

            // --- Tương quan trong nhóm, và độ lệch so toàn bộ -------------------------------
            var correlation: Double?
            var gap: Double?
            if let pairIndex {
                let (xs, ys) = cleaned(
                    rows.map { values[pairIndex.0][$0] }, rows.map { values[pairIndex.1][$0] })
                correlation = Correlation.pearson(xs, ys)
                if let correlation, let pooled { gap = abs(correlation - pooled) }
            }

            results.append(GroupResult(
                name: name, rowCount: rows.count, rowIndices: rows, anomalies: anomalies,
                anomalyRate: rows.isEmpty ? 0 : Double(anomalies) / Double(rows.count) * 100,
                fence: fence, mape: mape, forecastVerdict: verdict, period: period,
                correlation: correlation, correlationGap: gap, note: ""))
        }

        var methodology = methodologyText(
            groupCount: results.count, truncated: truncated, options: options, pooled: pooled)
        if cancelled {
            // Câu này đi vào khối "Phương pháp", tức đi theo cả bản xuất báo cáo — chứ không
            // chỉ hiện thoáng qua trên panel rồi mất.
            methodology += "\n⚠ ĐÃ HUỶ giữa chừng: bảng chỉ gồm \(results.count)/"
                + "\(order.count) nhóm đã chấm xong. Những nhóm còn lại KHÔNG được chấm — "
                + "đừng đọc bảng này như kết quả đầy đủ."
        }
        return Report(
            groups: results, truncated: truncated, pooledCorrelation: pooled,
            methodology: methodology, cancelled: cancelled)
    }

    private static func cleaned(_ xs: [Double], _ ys: [Double]) -> ([Double], [Double]) {
        var a: [Double] = [], b: [Double] = []
        for index in 0..<min(xs.count, ys.count) where xs[index].isFinite && ys[index].isFinite {
            a.append(xs[index])
            b.append(ys[index])
        }
        return (a, b)
    }

    private static func methodologyText(
        groupCount: Int, truncated: Int, options: Options, pooled: Double?
    ) -> String {
        var text = "Phương pháp: khai phá theo nhóm trên \(groupCount) nhóm, "
            + "mỗi nhóm chạy ĐỘC LẬP.\n"
        if let column = options.anomalyColumn {
            text += "Bất thường trên «\(column)»: IQR với k = \(ChartRender.number(options.iqrK)), "
                + "và hàng rào tính RIÊNG cho từng nhóm — dùng một hàng rào chung cho các nhóm "
                + "có phân bố khác nhau sẽ bỏ sót bất thường của nhóm nhỏ và báo nhầm ở nhóm "
                + "phân tán rộng.\n"
        }
        if let column = options.forecastColumn {
            text += "Dự báo trên «\(column)»: mỗi nhóm một mô hình riêng, chu kỳ mùa vụ tự phát "
                + "hiện riêng qua ACF, và mỗi nhóm tự so với baseline của chính nó.\n"
        }
        if let pair = options.correlationPair {
            text += "Tương quan «\(pair.0)» ↔ «\(pair.1)»: Pearson trong từng nhóm, "
                + "so với mốc toàn bộ "
                + (pooled.map { ChartRender.number($0) } ?? "(không đo được)")
                + ". Cột «lệch tương quan» đo |r(nhóm) − r(toàn bộ)| — nhóm đứng đầu là chỗ kết "
                + "luận rút từ bảng GỘP có thể ngược với sự thật trong nhóm.\n"
            text += "\(Correlation.caveat)\n"
        }
        if truncated > 0 {
            text += "CẢNH BÁO: có nhiều hơn \(groupLimit) nhóm; \(truncated) nhóm cuối đã bị bỏ "
                + "qua. Cột nhóm có quá nhiều giá trị khác nhau (mã đơn hàng chẳng hạn) thì mỗi "
                + "nhóm chỉ vài hàng, và thống kê trên vài hàng không nói được gì.\n"
        }
        text += "Thuật toán cổ điển, tự cài đặt trong GEditorCore — không dùng thư viện học máy "
            + "nào (NFR-MIN-04). Kết quả TẤT ĐỊNH."
        return text
    }
}
