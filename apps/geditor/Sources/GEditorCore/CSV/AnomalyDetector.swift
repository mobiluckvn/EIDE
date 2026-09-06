import Foundation

/// Phát hiện bất thường — FR-MIN-001.
///
/// ## Không có phụ thuộc ML, và đó là ràng buộc cứng
///
/// NFR-MIN-04: *"Toàn bộ thuật toán là CỔ ĐIỂN, TỰ CÀI ĐẶT trong GEditorCore — KHÔNG dependency
/// ML mới, không Python/sklearn, không GPU, không model file, không AutoML."* Lý do nằm ở
/// NFR-PERF-01 và NFR-PERF-05: một trình soạn thảo khởi động trong 500 ms và nghỉ ở 18 MB không
/// kéo theo được một runtime học máy. Bốn phương pháp dưới đây gộp lại chưa tới bốn trăm dòng.
///
/// ## Mọi dòng bị đánh dấu phải kèm GIẢI THÍCH ĐỌC ĐƯỢC
///
/// Đặc tả nêu thẳng ví dụ: *"doanh_thu = 2,4 tỷ vượt 5,1×IQR trên Q3 của cột"*. Đây không phải
/// tính năng phụ — nó là khác biệt giữa một công cụ dùng được và một hộp đen. Một danh sách
/// hai trăm dòng "bất thường" mà không nói vì sao thì người dùng không kiểm được cái nào là
/// dương tính giả, và họ sẽ bỏ cả tính năng.
///
/// ## Tất định (NFR-MIN-02)
///
/// Không có thành phần ngẫu nhiên nào ở đây — bốn phương pháp đều là thống kê mô tả. Nên không
/// có seed để ghi. `Finding` vẫn mang theo tham số đã dùng, vì một kết quả không nói ra ngưỡng
/// của nó là kết quả không tái lập được.
public enum AnomalyDetector {

    /// Hằng số MAD, **dùng chung với `QualityScorer`**.
    ///
    /// `QualityScorer` viết công thức này ra trước (chiều ACCURACY-PROXY của FR-DQR-002), và ghi
    /// rõ rằng khi FR-MIN-001 tới thì nó phải dùng LẠI đúng hằng số chứ không viết bản thứ hai.
    /// Đây là chỗ trả món nợ ấy: cả hai đọc từ đây.
    ///
    /// 1,4826 đưa MAD về cùng thang với độ lệch chuẩn của phân bố chuẩn, nên ngưỡng 3 đọc được
    /// như "3 sigma" quen thuộc.
    public static let madSigmaFactor = 1.4826

    public enum Method: Equatable, Sendable {
        /// |z| > ngưỡng. Nhanh, một lượt quét — nhưng chính trung bình và độ lệch chuẩn bị
        /// điểm cực đoan kéo đi, nên nó **kém nhạy đúng lúc dữ liệu bẩn nhất**.
        case zScore(threshold: Double = 3)
        /// Ngoài `[Q1 − k·IQR, Q3 + k·IQR]`. Không bị kéo, và là thứ biểu đồ hộp vẽ ra.
        case iqr(k: Double = 1.5)
        /// |x − trung vị| > ngưỡng × 1,4826 × MAD. Bền nhất với dữ liệu lệch.
        case mad(threshold: Double = 3)

        public var vietnamese: String {
            switch self {
            case .zScore(let threshold): return "z-score (|z| > \(ChartRender.number(threshold)))"
            case .iqr(let k): return "IQR (k = \(ChartRender.number(k)))"
            case .mad(let threshold): return "MAD (ngưỡng \(ChartRender.number(threshold)))"
            }
        }
    }

    public struct Finding: Equatable, Sendable {
        /// Chỉ số hàng trong dãy đầu vào, 0-based.
        public var row: Int
        public var value: Double
        /// Điểm bất thường — càng lớn càng lệch. Thang tuỳ phương pháp, nên đừng so giữa hai
        /// phương pháp khác nhau.
        public var score: Double
        /// Câu giải thích, tiếng Việt, nêu ĐÚNG con số.
        public var explanation: String

        public init(row: Int, value: Double, score: Double, explanation: String) {
            self.row = row
            self.value = value
            self.score = score
            self.explanation = explanation
        }
    }

    public struct Report: Equatable, Sendable {
        public var findings: [Finding]
        public var checked: Int
        public var method: String
        /// Khối "Phương pháp" mà NFR-MIN-04 đòi — thuật toán, tham số, công thức.
        public var methodology: String

        public init(findings: [Finding], checked: Int, method: String, methodology: String) {
            self.findings = findings
            self.checked = checked
            self.method = method
            self.methodology = methodology
        }

        public var rate: Double {
            checked > 0 ? Double(findings.count) / Double(checked) * 100 : 0
        }
    }

    // MARK: - Đơn biến

    public static func detect(
        _ values: [Double], column: String, method: Method,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Report {
        let clean = values.enumerated().filter { $0.element.isFinite }
        guard clean.count > 1 else {
            return Report(
                findings: [], checked: clean.count, method: method.vietnamese,
                methodology: "Không đủ dữ liệu để kết luận (cần ít nhất 2 giá trị số).")
        }

        switch method {
        case .zScore(let threshold):
            // Welford một lượt: tránh `Σx²` vốn mất chữ số có nghĩa khi giá trị lớn và phương
            // sai nhỏ — đúng hình dạng của dữ liệu tiền tệ.
            var mean = 0.0, m2 = 0.0, count = 0.0
            for (_, value) in clean {
                count += 1
                let delta = value - mean
                mean += delta / count
                m2 += delta * (value - mean)
            }
            let sd = (m2 / (count - 1)).squareRoot()
            guard sd > 0 else {
                return Report(
                    findings: [], checked: clean.count, method: method.vietnamese,
                    methodology: methodologyText(method, extra:
                        "Mọi giá trị bằng nhau (độ lệch chuẩn = 0) nên không có gì lệch."))
            }
            var findings: [Finding] = []
            for (index, value) in clean {
                try cancelToken.check()
                let z = (value - mean) / sd
                guard abs(z) > threshold else { continue }
                findings.append(Finding(
                    row: index, value: value, score: abs(z),
                    explanation: "\(column) = \(ChartRender.number(value)) lệch \(ChartRender.number(abs(z)))× độ lệch chuẩn "
                        + "so trung bình \(ChartRender.number(mean)) (ngưỡng \(ChartRender.number(threshold)))"))
            }
            return Report(
                findings: findings, checked: clean.count, method: method.vietnamese,
                methodology: methodologyText(method, extra:
                    "Trung bình \(ChartRender.number(mean)) · độ lệch chuẩn \(ChartRender.number(sd)) "
                        + "(Welford, một lượt quét)."))

        case .iqr(let k):
            let sorted = clean.map(\.element).sorted()
            let q1 = ChartData.quantile(sorted, 0.25)
            let q3 = ChartData.quantile(sorted, 0.75)
            let iqr = q3 - q1
            guard iqr > 0 else {
                return Report(
                    findings: [], checked: clean.count, method: method.vietnamese,
                    methodology: methodologyText(method, extra:
                        "Q1 = Q3 = \(ChartRender.number(q1)) nên IQR = 0 — không đo được độ phân tán, "
                            + "và không đo được thì KHÔNG kết luận."))
            }
            let low = q1 - k * iqr
            let high = q3 + k * iqr
            var findings: [Finding] = []
            for (index, value) in clean {
                try cancelToken.check()
                guard value < low || value > high else { continue }
                // Đúng câu mà đặc tả lấy làm ví dụ.
                let times = value > high ? (value - q3) / iqr : (q1 - value) / iqr
                let side = value > high ? "trên Q3" : "dưới Q1"
                findings.append(Finding(
                    row: index, value: value, score: times,
                    explanation: "\(column) = \(ChartRender.number(value)) vượt \(ChartRender.number(times))×IQR \(side) "
                        + "của cột (Q1 = \(ChartRender.number(q1)), Q3 = \(ChartRender.number(q3)))"))
            }
            return Report(
                findings: findings, checked: clean.count, method: method.vietnamese,
                methodology: methodologyText(method, extra:
                    "Q1 = \(ChartRender.number(q1)) · Q3 = \(ChartRender.number(q3)) · IQR = \(ChartRender.number(iqr)) · "
                        + "khoảng hợp lệ [\(ChartRender.number(low)), \(ChartRender.number(high))]."))

        case .mad(let threshold):
            let sorted = clean.map(\.element).sorted()
            let median = ChartData.quantile(sorted, 0.5)
            let deviations = sorted.map { abs($0 - median) }.sorted()
            let mad = ChartData.quantile(deviations, 0.5)
            guard mad > 0 else {
                return Report(
                    findings: [], checked: clean.count, method: method.vietnamese,
                    methodology: methodologyText(method, extra:
                        "MAD = 0 (quá nửa giá trị bằng trung vị \(ChartRender.number(median))) — không đo "
                            + "được độ phân tán, nên KHÔNG kết luận thay vì kết luận xấu."))
            }
            let scale = madSigmaFactor * mad
            var findings: [Finding] = []
            for (index, value) in clean {
                try cancelToken.check()
                let score = abs(value - median) / scale
                guard score > threshold else { continue }
                findings.append(Finding(
                    row: index, value: value, score: score,
                    explanation: "\(column) = \(ChartRender.number(value)) cách trung vị \(ChartRender.number(median)) "
                        + "một khoảng \(ChartRender.number(score))× MAD (ngưỡng \(ChartRender.number(threshold)))"))
            }
            return Report(
                findings: findings, checked: clean.count, method: method.vietnamese,
                methodology: methodologyText(method, extra:
                    "Trung vị \(ChartRender.number(median)) · MAD \(ChartRender.number(mad)) · "
                        + "thang = 1,4826 × MAD = \(ChartRender.number(scale))."))
        }
    }

    /// Độ lệch (skewness) — dùng để KHUYẾN NGHỊ phương pháp, không để quyết định thay người dùng.
    ///
    /// Đặc tả: *"MAD (robust — khuyến nghị tự động khi phân bố lệch, kiểm bằng độ lệch
    /// skewness)"*. Khuyến nghị chứ không tự đổi: đổi phương pháp sau lưng người dùng nghĩa là
    /// cùng một nút bấm cho hai kết quả khác nhau trên hai bộ dữ liệu, và họ không biết vì sao.
    public static func skewness(_ values: [Double]) -> Double {
        let clean = values.filter { $0.isFinite }
        guard clean.count > 2 else { return 0 }
        let n = Double(clean.count)
        let mean = clean.reduce(0, +) / n
        var m2 = 0.0, m3 = 0.0
        for value in clean {
            let d = value - mean
            m2 += d * d
            m3 += d * d * d
        }
        m2 /= n
        m3 /= n
        guard m2 > 0 else { return 0 }
        return m3 / pow(m2, 1.5)
    }

    /// Ngưỡng |skewness| mà trên đó nên khuyên dùng MAD. 1,0 là mốc quen dùng cho "lệch mạnh".
    public static let skewedThreshold = 1.0

    public static func recommendedMethod(for values: [Double]) -> Method {
        abs(skewness(values)) > skewedThreshold ? .mad() : .zScore()
    }

    private static func methodologyText(_ method: Method, extra: String) -> String {
        """
        Phương pháp: \(method.vietnamese)
        \(extra)
        Thuật toán cổ điển, tự cài đặt trong GEditorCore — không dùng thư viện học máy nào \
        (NFR-MIN-04). Kết quả TẤT ĐỊNH: cùng dữ liệu và cùng tham số cho cùng kết quả.
        """
    }
}

// MARK: - Đa biến (Mahalanobis)

extension AnomalyDetector {

    /// Bất thường ĐA BIẾN — FR-MIN-001, vế thứ hai.
    ///
    /// ## Vì sao cần vế này, khi đã có bốn phương pháp đơn biến
    ///
    /// Một đơn hàng `số_lượng = 3, đơn_giá = 200` bình thường trên cả hai cột nếu xét riêng. Một
    /// đơn `số_lượng = 3000, đơn_giá = 0.5` cũng vậy. Nhưng nếu trong bảng này số lượng lớn LUÔN
    /// đi với đơn giá thấp thì đơn thứ nhất mới là cái lệch — và không phương pháp đơn biến nào
    /// thấy được, vì cái lệch nằm ở QUAN HỆ giữa hai cột chứ không ở cột nào cả.
    ///
    /// Khoảng cách Mahalanobis đo đúng thứ đó: `d² = (x − μ)ᵀ Σ⁻¹ (x − μ)`. Nghịch đảo ma trận
    /// hiệp phương sai `Σ⁻¹` chính là thứ "chia cho độ phân tán theo mọi hướng", kể cả hướng
    /// chéo.
    ///
    /// ## Ngưỡng đặt trên `d`, không trên `d²`
    ///
    /// Vì `d` cùng thang với `|z|`: khi các cột không tương quan, `Σ` là ma trận chéo và
    /// `d² = z₁² + … + z_k²`. Nên ngưỡng mặc định 3 đọc được y hệt ngưỡng z-score, và người dùng
    /// không phải học một thang thứ hai.
    ///
    /// `testHaiCotKHONGTUONGQUANThiDBangCanBacHaiTongZBinhPhuong` giữ đẳng thức ấy — và tiện thể
    /// kiểm luôn phần nghịch đảo ma trận, vì nếu `Σ⁻¹` sai ở bất kỳ đâu thì nó vỡ ngay. (Trường
    /// hợp một cột thì gọn hơn nữa, `d = |z|`, nhưng hàm này CHẶN k < 2 — với một cột thì
    /// `detect(_:method: .zScore)` cho đúng kết quả ấy mà rẻ hơn nhiều lần.)
    public struct MultivariateResult: Equatable, Sendable {
        public var findings: [Finding]
        public var checked: Int
        public var methodology: String
        /// `nil` khi chấm được. Có giá trị khi KHÔNG chấm được — và khi ấy `findings` rỗng.
        public var refusal: String?

        public init(
            findings: [Finding], checked: Int, methodology: String, refusal: String? = nil
        ) {
            self.findings = findings
            self.checked = checked
            self.methodology = methodology
            self.refusal = refusal
        }
    }

    /// - Parameter columns: tên cột, để viết được câu giải thích.
    /// - Parameter rows: mỗi phần tử là một hàng, độ dài bằng `columns.count`.
    public static func mahalanobis(
        rows: [[Double]], columns: [String], threshold: Double = 3,
        cancelToken: CancelToken = CancelToken()
    ) throws -> MultivariateResult {
        let k = columns.count
        // Hàng thiếu số ở BẤT KỲ cột nào bị loại khỏi phép tính — không thể đo khoảng cách trong
        // không gian k chiều khi thiếu một toạ độ. Nhưng phải giữ chỉ số hàng gốc.
        let usable = rows.enumerated().filter {
            $0.element.count == k && $0.element.allSatisfy(\.isFinite)
        }

        let model: MahalanobisModel
        do {
            model = try MahalanobisModel(
                rows: usable.map(\.element), columns: columns, cancelToken: cancelToken)
        } catch let failure as MahalanobisModel.Failure {
            // Ba lý do từ chối, mỗi lý do một câu nói rõ phải làm gì. Riêng trường hợp suy
            // biến: bịa ra một nghịch đảo giả (pseudo-inverse) ở đây sẽ cho ra những con số
            // trông hợp lý mà không ai kiểm được.
            return MultivariateResult(
                findings: [], checked: usable.count, methodology: "",
                refusal: failure.message)
        }

        var findings: [Finding] = []
        for (index, row) in usable {
            try cancelToken.check()
            let distance = model.distance(of: row)
            guard distance > threshold else { continue }
            // Câu giải thích đi qua phân rã LEAVE-ONE-OUT của FR-MIN-008, không qua phân rã
            // theo số hạng của dạng toàn phương. Hai cách cho hai con số khác nhau, và cách
            // kia có thể ra số ÂM khi một cột đi ngược chiều tương quan — xem đầu
            // `MahalanobisModel`.
            findings.append(Finding(
                row: index, value: distance, score: distance,
                explanation: "cách tâm dữ liệu \(ChartRender.number(distance)) đơn vị "
                    + "Mahalanobis (ngưỡng \(ChartRender.number(threshold))); "
                    + model.explanation(of: row)))
        }

        let columnList = columns.joined(separator: ", ")
        return MultivariateResult(
            findings: findings, checked: usable.count,
            methodology: """
                Phương pháp: khoảng cách Mahalanobis trên \(k) cột (\(columnList)), \
                ngưỡng d > \(ChartRender.number(threshold)).
                d² = (x − μ)ᵀ Σ⁻¹ (x − μ), với Σ là hiệp phương sai mẫu (chia n − 1) trên \
                \(model.rowCount) hàng đủ số. Nghịch đảo bằng khử Gauss-Jordan có chọn trục.
                Với một cột, d rút gọn về đúng |z| — nên ngưỡng ở đây đọc như ngưỡng z-score.
                \(MahalanobisModel.methodology)
                Thuật toán cổ điển, tự cài đặt trong GEditorCore — không dùng thư viện học máy \
                nào (NFR-MIN-04). Kết quả TẤT ĐỊNH.
                """)
    }

    /// Nghịch đảo bằng khử Gauss-Jordan có chọn trục từng phần. `nil` khi suy biến.
    ///
    /// Chọn trục là bắt buộc chứ không phải tinh chỉnh: không chọn trục thì một phần tử đường
    /// chéo rất nhỏ (cột có phương sai bé, ví dụ tỷ lệ phần trăm nằm cạnh cột doanh thu tính
    /// bằng đồng) trở thành mẫu số và thổi sai số lên nhiều bậc độ lớn.
    static func invert(_ matrix: [[Double]]) -> [[Double]]? {
        let n = matrix.count
        var a = matrix
        var inverse = (0..<n).map { i in
            (0..<n).map { j in i == j ? 1.0 : 0.0 }
        }
        // Thang của ma trận, để ngưỡng suy biến là TƯƠNG ĐỐI. Một ngưỡng tuyệt đối như 1e−12 sẽ
        // coi mọi ma trận đơn vị tiền tệ nhỏ là suy biến, và bỏ sót ma trận suy biến thật khi
        // các số rất lớn.
        let scale = matrix.flatMap { $0 }.map(abs).max() ?? 1
        let tolerance = max(scale, 1) * 1e-12

        for column in 0..<n {
            var pivot = column
            for row in (column + 1)..<n where abs(a[row][column]) > abs(a[pivot][column]) {
                pivot = row
            }
            guard abs(a[pivot][column]) > tolerance else { return nil }
            if pivot != column {
                a.swapAt(pivot, column)
                inverse.swapAt(pivot, column)
            }
            let divisor = a[column][column]
            for j in 0..<n {
                a[column][j] /= divisor
                inverse[column][j] /= divisor
            }
            for row in 0..<n where row != column {
                let factor = a[row][column]
                guard factor != 0 else { continue }
                for j in 0..<n {
                    a[row][j] -= factor * a[column][j]
                    inverse[row][j] -= factor * inverse[column][j]
                }
            }
        }
        return inverse
    }
}
