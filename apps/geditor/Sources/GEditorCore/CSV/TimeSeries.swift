import Foundation

/// Phân tích chuỗi thời gian — FR-MIN-004.
///
/// Đặc tả: *"DECOMPOSITION trend/seasonal/residual bằng moving average; chu kỳ mùa vụ tự phát
/// hiện qua ACF hoặc người dùng đặt tay. DỰ BÁO: Holt-Winters (additive/multiplicative) với
/// seasonal-naive và naive làm baseline so sánh; horizon người dùng đặt; khoảng tin cậy 80%/95%.
/// Đầu ra: biểu đồ lịch sử + đường dự báo + dải tin cậy; bảng giá trị dự báo kèm sai số huấn
/// luyện (MAE/MAPE) đối chiếu baseline — **nếu model không thắng baseline, nói thẳng trong kết
/// quả**."*
///
/// ## Câu cuối là câu quan trọng nhất, và nó ngược với thói quen của cả ngành
///
/// Công cụ dự báo thường trình bày kết quả của mô hình như một sự thật: một đường cong đẹp, một
/// dải tin cậy, vài con số. Người dùng không có cách nào biết rằng *"lấy giá trị tháng trước"*
/// có khi còn chính xác hơn.
///
/// Ở đây baseline **luôn được chạy**, và `verdict` nói thẳng ai thắng. Một mô hình thua
/// seasonal-naive không phải là một mô hình cần giấu đi — nó là thông tin quan trọng nhất trên
/// màn hình, vì nó nói rằng dữ liệu này không có gì để học ngoài tính mùa vụ.
///
/// ## Khoảng tin cậy ở đây là XẤP XỈ, và điều đó phải được nói ra
///
/// Khoảng tin cậy đúng của Holt-Winters đòi dạng không gian trạng thái (ETS) với phương sai suy
/// ra từ chính mô hình. Ở đây dùng cách xấp xỉ quen thuộc: độ lệch chuẩn phần dư huấn luyện, nới
/// theo `√h`. Nó hợp lý cho vài bước đầu và NỚI QUÁ CHẬM ở tầm xa.
///
/// Không nói ra điều đó là để người dùng đọc một dải 95% như một bảo đảm 95%. Nên `methodology`
/// nói, và nói bằng chữ chứ không bằng một dấu sao.
public enum TimeSeries {

    // MARK: - Phát hiện chu kỳ

    /// Tự hàm tương quan (ACF) tại một độ trễ.
    ///
    /// Dùng ước lượng chuẩn — mẫu số là tổng bình phương trên TOÀN dãy, không phải trên phần
    /// chồng lấn. Chia theo phần chồng lấn làm ACF ở độ trễ lớn phồng lên (ít số hạng hơn, cùng
    /// mẫu số nhỏ hơn), và khi ấy "chu kỳ mạnh nhất" luôn rơi vào độ trễ lớn nhất được xét.
    public static func autocorrelation(_ values: [Double], lag: Int) -> Double {
        guard lag > 0, values.count > lag else { return 0 }
        let n = Double(values.count)
        let mean = values.reduce(0, +) / n
        var numerator = 0.0
        var denominator = 0.0
        for index in 0..<values.count {
            let d = values[index] - mean
            denominator += d * d
            if index >= lag { numerator += d * (values[index - lag] - mean) }
        }
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    /// Chu kỳ mùa vụ mạnh nhất, hoặc `nil` khi không có chu kỳ nào đủ rõ.
    ///
    /// `nil` là một câu trả lời hợp lệ và hay gặp. Ép một chu kỳ lên dữ liệu không có mùa vụ sẽ
    /// sinh ra một thành phần "mùa vụ" toàn nhiễu, và mô hình khi ấy học thuộc nhiễu.
    ///
    /// - Parameter minimumStrength: ACF tối thiểu để coi là có mùa vụ. 0,3 là mức quen dùng cho
    ///   "tương quan vừa phải" — dưới nữa thì phần lớn là nhiễu.
    ///
    /// ## ACF chạy trên SAI PHÂN BẬC MỘT, không trên chuỗi gốc
    ///
    /// Đây là chỗ bản đầu của hàm này sai, và sai một cách rất dễ lọt. Trên một chuỗi có xu
    /// hướng tăng, mọi giá trị sau đều lớn hơn mọi giá trị trước, nên ACF cao ở **mọi** độ trễ
    /// và giảm chậm — đỉnh mùa vụ chìm hẳn trong cái nền ấy. Với chuỗi thử chu kỳ 4 kèm xu
    /// hướng, hàm cũ trả về **2**: ACF(2) chỉ thấp hơn ACF(4) vài phần trăm vì cả hai đều chủ
    /// yếu đo xu hướng, và bộ lọc "chọn ước số" nhặt luôn con số nhỏ hơn.
    ///
    /// Sai phân bậc một khử xu hướng tuyến tính và để lại đúng phần dao động. Đây là cách làm
    /// chuẩn, và cái giá là mất một điểm ở đầu chuỗi.
    public static func detectPeriod(
        _ values: [Double], maximum: Int = 0, minimumStrength: Double = 0.3
    ) -> Int? {
        // Cần ít nhất hai chu kỳ đầy đủ để nói được là có chu kỳ.
        let cap = maximum > 0 ? maximum : values.count / 2
        guard values.count >= 8, cap >= 2 else { return nil }

        var differenced: [Double] = []
        differenced.reserveCapacity(values.count - 1)
        for index in 1..<values.count { differenced.append(values[index] - values[index - 1]) }

        var best: (lag: Int, value: Double)?
        for lag in 2...min(cap, differenced.count - 2) {
            let value = autocorrelation(differenced, lag: lag)
            guard value >= minimumStrength else { continue }
            if best == nil || value > best!.value { best = (lag, value) }
        }
        guard let best else { return nil }

        // Chọn chu kỳ CƠ BẢN, không chọn bội của nó.
        //
        // Với dữ liệu chu kỳ 4, ACF ở độ trễ 8, 12, 16 cũng cao. Trả về 12 cho dữ liệu chu kỳ 4
        // là đúng về ACF và sai về ý nghĩa: nó ngốn ba lần số điểm để ước lượng mùa vụ, và làm
        // mất một nửa dữ liệu huấn luyện.
        for candidate in 2...best.lag where best.lag % candidate == 0 {
            if autocorrelation(differenced, lag: candidate) >= best.value * 0.9 {
                return candidate
            }
        }
        return best.lag
    }

    // MARK: - Phân rã

    public struct Decomposition: Equatable, Sendable {
        public var period: Int
        public var multiplicative: Bool
        /// Xu hướng — `nil` ở hai đầu, nơi trung bình trượt tâm không tính được.
        public var trend: [Double?]
        /// Mùa vụ, một giá trị cho mỗi điểm (lặp theo chu kỳ).
        public var seasonal: [Double]
        /// Phần dư. `nil` ở chỗ không có xu hướng.
        public var residual: [Double?]

        public init(
            period: Int, multiplicative: Bool, trend: [Double?], seasonal: [Double],
            residual: [Double?]
        ) {
            self.period = period
            self.multiplicative = multiplicative
            self.trend = trend
            self.seasonal = seasonal
            self.residual = residual
        }
    }

    /// Phân rã cổ điển bằng trung bình trượt TÂM.
    ///
    /// Chu kỳ CHẴN cần trung bình trượt 2×m (trung bình của hai cửa sổ m lệch nhau một bước),
    /// vì một cửa sổ m điểm với m chẵn không có tâm nằm trên một điểm dữ liệu. Bỏ qua chi tiết
    /// này làm thành phần xu hướng lệch nửa bước, và nửa bước ấy chảy hết vào "mùa vụ".
    public static func decompose(
        _ values: [Double], period: Int, multiplicative: Bool = false
    ) -> Decomposition? {
        guard period >= 2, values.count >= period * 2 else { return nil }

        var trend = [Double?](repeating: nil, count: values.count)
        let half = period / 2
        for index in values.indices {
            if period % 2 == 0 {
                guard index >= half, index + half < values.count else { continue }
                // Hai đầu cửa sổ mang trọng số một nửa — đó chính là trung bình 2×m.
                var total = (values[index - half] + values[index + half]) / 2
                for offset in (index - half + 1)...(index + half - 1) { total += values[offset] }
                trend[index] = total / Double(period)
            } else {
                guard index >= half, index + half < values.count else { continue }
                var total = 0.0
                for offset in (index - half)...(index + half) { total += values[offset] }
                trend[index] = total / Double(period)
            }
        }

        // Gỡ xu hướng, rồi trung bình theo VỊ TRÍ TRONG CHU KỲ.
        var buckets = [[Double]](repeating: [], count: period)
        for index in values.indices {
            guard let base = trend[index] else { continue }
            if multiplicative {
                guard base != 0 else { continue }
                buckets[index % period].append(values[index] / base)
            } else {
                buckets[index % period].append(values[index] - base)
            }
        }
        var factors = buckets.map { bucket -> Double in
            guard !bucket.isEmpty else { return multiplicative ? 1 : 0 }
            return bucket.reduce(0, +) / Double(bucket.count)
        }
        // Chuẩn hoá: cộng lại bằng 0 (cộng) hoặc nhân lại bằng 1 (nhân). Không chuẩn hoá thì
        // thành phần mùa vụ mang theo một phần mức trung bình, và nó bị đếm HAI LẦN — một lần
        // trong xu hướng, một lần trong mùa vụ.
        if multiplicative {
            let mean = factors.reduce(0, +) / Double(period)
            if mean != 0 { factors = factors.map { $0 / mean } }
        } else {
            let mean = factors.reduce(0, +) / Double(period)
            factors = factors.map { $0 - mean }
        }

        let seasonal = values.indices.map { factors[$0 % period] }
        let residual: [Double?] = values.indices.map { index in
            guard let base = trend[index] else { return nil }
            if multiplicative {
                let denominator = base * seasonal[index]
                return denominator != 0 ? values[index] / denominator : nil
            }
            return values[index] - base - seasonal[index]
        }
        return Decomposition(
            period: period, multiplicative: multiplicative, trend: trend,
            seasonal: seasonal, residual: residual)
    }

    // MARK: - Sai số

    public struct Accuracy: Equatable, Sendable {
        public var mae: Double
        /// `nil` khi KHÔNG tính được — xem `mapeNote`.
        public var mape: Double?
        public var mapeNote: String
        public var count: Int

        public init(mae: Double, mape: Double?, mapeNote: String, count: Int) {
            self.mae = mae
            self.mape = mape
            self.mapeNote = mapeNote
            self.count = count
        }
    }

    /// MAE và MAPE giữa giá trị thật và giá trị khớp.
    ///
    /// ## MAPE chia cho giá trị THẬT, nên số 0 là một cái bẫy
    ///
    /// Một tháng doanh thu bằng 0 làm MAPE thành vô cùng. Cách hay gặp — bỏ qua những điểm ấy
    /// trong im lặng — biến MAPE thành một con số tính trên một tập con mà không ai biết, và
    /// tập con ấy lệch có hệ thống (bỏ đúng những kỳ khó dự báo nhất).
    ///
    /// Ở đây: bỏ qua thì có, nhưng **nói ra bỏ bao nhiêu**; và nếu bỏ quá một phần tư thì MAPE
    /// trả `nil`, vì lúc ấy nó không còn mô tả cùng một chuỗi nữa.
    public static func accuracy(actual: [Double], fitted: [Double?]) -> Accuracy? {
        var absoluteErrors: [Double] = []
        var percentErrors: [Double] = []
        var skipped = 0
        for index in 0..<min(actual.count, fitted.count) {
            guard let predicted = fitted[index], predicted.isFinite else { continue }
            let error = abs(actual[index] - predicted)
            absoluteErrors.append(error)
            if actual[index] == 0 {
                skipped += 1
            } else {
                percentErrors.append(error / abs(actual[index]) * 100)
            }
        }
        guard !absoluteErrors.isEmpty else { return nil }
        let mae = absoluteErrors.reduce(0, +) / Double(absoluteErrors.count)

        let total = absoluteErrors.count
        if percentErrors.isEmpty {
            return Accuracy(
                mae: mae, mape: nil,
                mapeNote: "MAPE không tính được: mọi giá trị thật đều bằng 0.", count: total)
        }
        if Double(skipped) / Double(total) > 0.25 {
            return Accuracy(
                mae: mae, mape: nil,
                mapeNote: "MAPE không tính được: \(skipped)/\(total) kỳ có giá trị thật bằng 0 "
                    + "(quá 25%) — bỏ qua chúng sẽ cho một con số tính trên một chuỗi khác.",
                count: total)
        }
        return Accuracy(
            mae: mae, mape: percentErrors.reduce(0, +) / Double(percentErrors.count),
            mapeNote: skipped > 0
                ? "MAPE bỏ qua \(skipped)/\(total) kỳ có giá trị thật bằng 0."
                : "",
            count: total)
    }
}

// MARK: - Dự báo

extension TimeSeries {

    public enum Model: String, CaseIterable, Equatable, Sendable {
        case holtWintersAdditive, holtWintersMultiplicative, seasonalNaive, naive

        public var vietnamese: String {
            switch self {
            case .holtWintersAdditive: return "Holt-Winters cộng"
            case .holtWintersMultiplicative: return "Holt-Winters nhân"
            case .seasonalNaive: return "seasonal-naive"
            case .naive: return "naive"
            }
        }

        var isBaseline: Bool { self == .seasonalNaive || self == .naive }
    }

    public struct Forecast: Equatable, Sendable {
        public var model: Model
        /// Giá trị khớp trên phần huấn luyện. `nil` ở những kỳ đầu chưa đủ dữ kiện.
        public var fitted: [Double?]
        public var future: [Double]
        /// Dải 80% và 95%, cùng độ dài với `future`.
        public var lower80: [Double]
        public var upper80: [Double]
        public var lower95: [Double]
        public var upper95: [Double]
        public var accuracy: Accuracy?
        /// Tham số đã dùng — để chạy lại được.
        public var parameters: String

        public init(
            model: Model, fitted: [Double?], future: [Double],
            lower80: [Double], upper80: [Double], lower95: [Double], upper95: [Double],
            accuracy: Accuracy?, parameters: String
        ) {
            self.model = model
            self.fitted = fitted
            self.future = future
            self.lower80 = lower80
            self.upper80 = upper80
            self.lower95 = lower95
            self.upper95 = upper95
            self.accuracy = accuracy
            self.parameters = parameters
        }
    }

    public struct Comparison: Equatable, Sendable {
        public var chosen: Forecast
        public var baselines: [Forecast]
        /// Mô hình có MAE nhỏ nhất trong TẤT CẢ, kể cả baseline.
        public var bestModel: Model
        /// Câu nói thẳng ai thắng — đặc tả đòi vế này.
        public var verdict: String
        public var period: Int?
        public var methodology: String

        public init(
            chosen: Forecast, baselines: [Forecast], bestModel: Model, verdict: String,
            period: Int?, methodology: String
        ) {
            self.chosen = chosen
            self.baselines = baselines
            self.bestModel = bestModel
            self.verdict = verdict
            self.period = period
            self.methodology = methodology
        }

        public var modelBeatsBaselines: Bool { !bestModel.isBaseline }
    }

    /// Dự báo, kèm hai baseline và phán xét.
    ///
    /// - Parameter period: `nil` = tự phát hiện qua ACF.
    public static func forecast(
        _ values: [Double], horizon: Int, model: Model = .holtWintersAdditive,
        period: Int? = nil, cancelToken: CancelToken = CancelToken()
    ) throws -> Comparison? {
        let clean = values.filter { $0.isFinite }
        guard clean.count >= 4, horizon >= 1 else { return nil }
        let detected = period ?? detectPeriod(clean)

        var chosenModel = model
        var seasonNote = ""
        // Không đủ hai chu kỳ đầy đủ thì KHÔNG có gì để ước lượng mùa vụ. Chạy Holt-Winters khi
        // ấy sẽ khớp mùa vụ vào nhiễu của một chu kỳ duy nhất, và dự báo lặp lại nhiễu ấy ra
        // tương lai — trông rất thuyết phục và hoàn toàn bịa.
        let usableSeason = detected.flatMap { clean.count >= $0 * 2 ? $0 : nil }
        if usableSeason == nil, model != .naive {
            chosenModel = .naive
            seasonNote = detected == nil
                ? "Không tìm thấy chu kỳ mùa vụ nào đủ rõ (ACF < 0,3), nên đã lùi về naive."
                : "Chuỗi chỉ có \(clean.count) điểm, chưa đủ hai chu kỳ \(detected!) — "
                    + "không ước lượng được mùa vụ, nên đã lùi về naive."
        }
        if chosenModel == .holtWintersMultiplicative, clean.contains(where: { $0 <= 0 }) {
            // Nhân chia cho thành phần mùa vụ; giá trị ≤ 0 làm nó vỡ hoặc lật dấu.
            chosenModel = .holtWintersAdditive
            seasonNote += (seasonNote.isEmpty ? "" : " ")
                + "Chuỗi có giá trị ≤ 0 nên dạng NHÂN không dùng được — đã chuyển sang dạng cộng."
        }

        let chosen = try run(
            chosenModel, clean, horizon: horizon, period: usableSeason,
            cancelToken: cancelToken)
        var baselines: [Forecast] = []
        for baseline in [Model.naive, .seasonalNaive] where baseline != chosenModel {
            if baseline == .seasonalNaive, usableSeason == nil { continue }
            baselines.append(try run(
                baseline, clean, horizon: horizon, period: usableSeason,
                cancelToken: cancelToken))
        }

        let all = [chosen] + baselines
        let ranked = all.compactMap { forecast -> (Model, Double)? in
            guard let mae = forecast.accuracy?.mae else { return nil }
            return (forecast.model, mae)
        }.sorted { $0.1 < $1.1 }
        let best = ranked.first?.0 ?? chosenModel

        var verdict: String
        if best.isBaseline && !chosenModel.isBaseline {
            let chosenMAE = chosen.accuracy?.mae ?? .nan
            let bestMAE = ranked.first?.1 ?? .nan
            verdict = "MÔ HÌNH THUA BASELINE. \(best.vietnamese) có MAE "
                + "\(ChartRender.number(bestMAE)), thấp hơn \(chosenModel.vietnamese) "
                + "(\(ChartRender.number(chosenMAE))). Với chuỗi này, cách đơn giản hơn dự báo "
                + "tốt hơn — nên dùng nó, và nên nghi ngờ rằng chuỗi không có cấu trúc gì để học."
        } else if chosenModel.isBaseline {
            verdict = "Đang dùng \(chosenModel.vietnamese) — bản thân nó là một baseline, "
                + "không phải một mô hình học được gì từ dữ liệu."
        } else {
            verdict = "\(chosenModel.vietnamese) thắng cả hai baseline (MAE "
                + "\(ChartRender.number(chosen.accuracy?.mae ?? .nan)))."
        }
        if !seasonNote.isEmpty { verdict = seasonNote + " " + verdict }

        var methodology = """
            Phương pháp: \(chosenModel.vietnamese), tầm dự báo \(horizon) kỳ.
            \(chosen.parameters)
            Chu kỳ mùa vụ: \(usableSeason.map(String.init) ?? "không có") \
            (\(period == nil ? "tự phát hiện qua ACF" : "người dùng đặt")).
            So với baseline: \(baselines.map { forecast in
                "\(forecast.model.vietnamese) MAE \(ChartRender.number(forecast.accuracy?.mae ?? .nan))"
            }.joined(separator: " · ")).
            \(verdict)
            KHOẢNG TIN CẬY LÀ XẤP XỈ: dựng từ độ lệch chuẩn phần dư huấn luyện, nới theo √h. \
            Khoảng đúng của Holt-Winters đòi dạng không gian trạng thái (ETS); cách ở đây nới \
            QUÁ CHẬM ở tầm xa, nên dải 95% ở kỳ thứ mười hẹp hơn thực tế.
            Thuật toán cổ điển, tự cài đặt trong GEditorCore — không dùng thư viện học máy nào \
            (NFR-MIN-04). Kết quả TẤT ĐỊNH.
            """
        if let note = chosen.accuracy?.mapeNote, !note.isEmpty {
            methodology += "\n\(note)"
        }
        return Comparison(
            chosen: chosen, baselines: baselines, bestModel: best, verdict: verdict,
            period: usableSeason, methodology: methodology)
    }

    private static func run(
        _ model: Model, _ values: [Double], horizon: Int, period: Int?,
        cancelToken: CancelToken
    ) throws -> Forecast {
        switch model {
        case .naive:
            return naiveForecast(values, horizon: horizon, period: 1)
        case .seasonalNaive:
            return naiveForecast(values, horizon: horizon, period: period ?? 1)
        case .holtWintersAdditive, .holtWintersMultiplicative:
            return try holtWinters(
                values, horizon: horizon, period: period ?? 1,
                multiplicative: model == .holtWintersMultiplicative, cancelToken: cancelToken)
        }
    }

    /// naive (`period = 1`) và seasonal-naive gộp làm một: cả hai đều là *"lấy lại giá trị của
    /// kỳ trước cách đây `period` bước"*. Hai bản riêng là hai chỗ để lệch nhau.
    private static func naiveForecast(
        _ values: [Double], horizon: Int, period: Int
    ) -> Forecast {
        let step = max(1, period)
        var fitted = [Double?](repeating: nil, count: values.count)
        for index in step..<values.count { fitted[index] = values[index - step] }

        var future: [Double] = []
        for h in 0..<horizon {
            // Lặp lại chu kỳ cuối. Với naive (`step = 1`) đây đúng là "giữ nguyên giá trị cuối".
            let source = values.count - step + (h % step)
            future.append(values[max(0, min(source, values.count - 1))])
        }
        let accuracy = TimeSeries.accuracy(actual: values, fitted: fitted)
        let (l80, u80, l95, u95) = intervals(
            around: future, residuals: residuals(values, fitted))
        return Forecast(
            model: step == 1 ? .naive : .seasonalNaive, fitted: fitted, future: future,
            lower80: l80, upper80: u80, lower95: l95, upper95: u95, accuracy: accuracy,
            parameters: step == 1
                ? "naive: ŷ(t+h) = y(t)."
                : "seasonal-naive: ŷ(t+h) = y(t+h−\(step)), lặp lại chu kỳ cuối.")
    }

    /// Holt-Winters, tham số chọn bằng QUÉT LƯỚI trên SSE huấn luyện.
    ///
    /// Quét lưới chứ không tối ưu bằng gradient: lưới cho kết quả **tất định bit-by-bit**
    /// (NFR-MIN-02), không phụ thuộc điểm khởi đầu, và 11³ = 1.331 tổ hợp trên một chuỗi vài
    /// trăm điểm là chuyện của vài chục mili-giây. Một bộ tối ưu tinh vi hơn sẽ đổi tính tất
    /// định lấy vài phần trăm SSE — sai giá.
    static func holtWinters(
        _ values: [Double], horizon: Int, period: Int, multiplicative: Bool,
        cancelToken: CancelToken
    ) throws -> Forecast {
        let m = max(1, period)
        let grid = stride(from: 0.1, through: 0.9, by: 0.1).map { $0 }

        var best: (alpha: Double, beta: Double, gamma: Double, sse: Double)?
        for alpha in grid {
            try cancelToken.check()
            for beta in grid {
                for gamma in (m > 1 ? grid : [0.1]) {
                    let fitted = holtWintersFit(
                        values, period: m, multiplicative: multiplicative,
                        alpha: alpha, beta: beta, gamma: gamma).fitted
                    var sse = 0.0
                    var counted = 0
                    for index in values.indices {
                        guard let predicted = fitted[index], predicted.isFinite else { continue }
                        let error = values[index] - predicted
                        sse += error * error
                        counted += 1
                    }
                    guard counted > 0, sse.isFinite else { continue }
                    if best == nil || sse < best!.sse {
                        best = (alpha, beta, gamma, sse)
                    }
                }
            }
        }
        let chosen = best ?? (0.3, 0.1, 0.1, 0)
        let state = holtWintersFit(
            values, period: m, multiplicative: multiplicative,
            alpha: chosen.alpha, beta: chosen.beta, gamma: chosen.gamma)

        var future: [Double] = []
        for h in 1...horizon {
            let seasonIndex = (values.count + h - 1) % m
            let base = state.level + Double(h) * state.trend
            future.append(multiplicative
                ? base * state.seasonal[seasonIndex]
                : base + state.seasonal[seasonIndex])
        }
        let accuracy = TimeSeries.accuracy(actual: values, fitted: state.fitted)
        let (l80, u80, l95, u95) = intervals(
            around: future, residuals: residuals(values, state.fitted))
        return Forecast(
            model: multiplicative ? .holtWintersMultiplicative : .holtWintersAdditive,
            fitted: state.fitted, future: future,
            lower80: l80, upper80: u80, lower95: l95, upper95: u95, accuracy: accuracy,
            parameters: "α = \(ChartRender.number(chosen.alpha)) · "
                + "β = \(ChartRender.number(chosen.beta)) · "
                + "γ = \(ChartRender.number(chosen.gamma)) "
                + "(quét lưới 0,1…0,9 theo SSE huấn luyện — tất định).")
    }

    private static func holtWintersFit(
        _ values: [Double], period m: Int, multiplicative: Bool,
        alpha: Double, beta: Double, gamma: Double
    ) -> (fitted: [Double?], level: Double, trend: Double, seasonal: [Double]) {
        // Khởi tạo: mức = trung bình chu kỳ đầu, xu hướng = chênh lệch giữa hai chu kỳ đầu chia
        // m, mùa vụ = lệch của từng vị trí so mức. Đây là cách khởi tạo cổ điển; nó quan trọng
        // vì Holt-Winters không "quên" khởi tạo tồi nhanh như người ta tưởng trên chuỗi ngắn.
        var level: Double
        var trend: Double
        var seasonal = [Double](repeating: multiplicative ? 1 : 0, count: m)

        if m > 1, values.count >= m * 2 {
            let first = Array(values[0..<m])
            let second = Array(values[m..<(m * 2)])
            level = first.reduce(0, +) / Double(m)
            trend = (second.reduce(0, +) / Double(m) - level) / Double(m)
            for index in 0..<m {
                seasonal[index] = multiplicative
                    ? (level != 0 ? first[index] / level : 1)
                    : first[index] - level
            }
        } else {
            level = values[0]
            trend = values.count > 1 ? values[1] - values[0] : 0
        }

        var fitted = [Double?](repeating: nil, count: values.count)
        let start = (m > 1 && values.count >= m * 2) ? m : 1
        for index in start..<values.count {
            let seasonIndex = index % m
            let season = seasonal[seasonIndex]
            let predicted = multiplicative
                ? (level + trend) * season
                : level + trend + season
            fitted[index] = predicted

            let previousLevel = level
            if multiplicative {
                guard season != 0 else { continue }
                level = alpha * (values[index] / season) + (1 - alpha) * (level + trend)
                trend = beta * (level - previousLevel) + (1 - beta) * trend
                if level != 0 {
                    seasonal[seasonIndex] =
                        gamma * (values[index] / level) + (1 - gamma) * season
                }
            } else {
                level = alpha * (values[index] - season) + (1 - alpha) * (level + trend)
                trend = beta * (level - previousLevel) + (1 - beta) * trend
                seasonal[seasonIndex] =
                    gamma * (values[index] - level) + (1 - gamma) * season
            }
        }
        return (fitted, level, trend, seasonal)
    }

    private static func residuals(_ values: [Double], _ fitted: [Double?]) -> [Double] {
        var out: [Double] = []
        for index in values.indices {
            guard let predicted = fitted[index], predicted.isFinite else { continue }
            out.append(values[index] - predicted)
        }
        return out
    }

    /// Dải 80% và 95% quanh dự báo — XẤP XỈ, xem ghi chú đầu tệp.
    private static func intervals(
        around future: [Double], residuals: [Double]
    ) -> ([Double], [Double], [Double], [Double]) {
        guard residuals.count >= 2 else {
            return (future, future, future, future)
        }
        let mean = residuals.reduce(0, +) / Double(residuals.count)
        let variance = residuals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            / Double(residuals.count - 1)
        let sd = variance.squareRoot()
        // 1,2816 và 1,96: phân vị chuẩn hai phía cho 80% và 95%.
        var l80: [Double] = [], u80: [Double] = [], l95: [Double] = [], u95: [Double] = []
        for (step, value) in future.enumerated() {
            let widened = sd * Double(step + 1).squareRoot()
            l80.append(value - 1.2816 * widened)
            u80.append(value + 1.2816 * widened)
            l95.append(value - 1.96 * widened)
            u95.append(value + 1.96 * widened)
        }
        return (l80, u80, l95, u95)
    }
}
