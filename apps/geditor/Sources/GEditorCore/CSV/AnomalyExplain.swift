import Foundation

/// Phân rã giải thích đa biến — FR-MIN-008.
///
/// Đặc tả: *"Với mỗi dòng bất thường Mahalanobis (FR-MIN-001), phân rã ĐÓNG GÓP của từng cột
/// bằng leave-one-out: ΔD²(j) = D² đầy đủ − D² khi bỏ cột j, chuẩn hóa thành %; sinh câu giải
/// thích tự động: «bất thường chủ yếu do tổ hợp doanh_thu (61%) × số_lượng (27%)». … Tổng %
/// luôn = 100, công thức trong khối Phương pháp."*
///
/// ## Vì sao leave-one-out chứ không phải cách rẻ hơn
///
/// `AnomalyDetector.mahalanobis` đã có sẵn một phân rã **miễn phí**: dạng toàn phương
/// `D² = Σⱼ δⱼ · (Σ⁻¹δ)ⱼ` tách đúng thành k số hạng cộng lại bằng D². Cám dỗ là dùng luôn nó.
///
/// Nhưng nó trả lời một câu hỏi khác. Số hạng thứ j **có thể âm** — khi cột j đi ngược chiều
/// tương quan, nó *kéo* khoảng cách xuống — và một bảng "đóng góp" có số âm thì không đọc được
/// như phần trăm. Leave-one-out trả lời đúng câu người dùng hỏi: *bỏ cột này ra thì dòng này còn
/// bất thường bao nhiêu?*
///
/// Và ΔD²(j) **luôn ≥ 0**, không phải nhờ may mắn: có đẳng thức
/// `D²đầy đủ = D²(bỏ j) + (xⱼ − x̂ⱼ)² / σ²ⱼ|còn lại`, với `x̂ⱼ` là kỳ vọng của cột j suy từ các
/// cột kia. Số hạng thêm vào là một bình phương chia cho một phương sai — không âm được.
/// `testDongGopKhongBaoGioAM` giữ tính chất ấy.
///
/// ## Chuẩn hoá 100% là một PHÉP QUY ƯỚC, và phải nói ra
///
/// Tổng các ΔD²(j) **không** bằng D². (Với hai cột độc lập, mỗi ΔD² bằng đúng zⱼ², nên tổng
/// đúng bằng D²; nhưng khi có tương quan thì phần "chung" giữa các cột bị đếm hụt.) Chia cho
/// tổng để ra 100% là quy ước cho dễ đọc, không phải một đẳng thức.
///
/// Đặc tả đòi tổng luôn = 100 và đòi công thức nằm trong khối Phương pháp — hai vế ấy đi cùng
/// nhau chính vì lý do này. Con số 61% nghĩa là *"trong phần giải thích được, cột này chiếm
/// 61%"*, không phải *"61% khoảng cách nằm ở cột này"*. Khối Phương pháp nói đúng câu đó.
public struct MahalanobisModel: Sendable {

    public let columns: [String]
    public let mean: [Double]
    /// Σ⁻¹ trên đủ k cột.
    let inverse: [[Double]]
    /// `subInverse[j]` = nghịch đảo hiệp phương sai khi BỎ cột j. Tính một lần cho cả bảng —
    /// làm lại cho từng dòng bất thường là k phép khử Gauss mỗi dòng.
    let subInverse: [[[Double]]]
    let subMean: [[Double]]
    public let rowCount: Int

    public enum Failure: Error, Equatable, Sendable {
        case tooFewColumns
        case tooFewRows(rows: Int, columns: Int)
        case singular

        public var message: String {
            switch self {
            case .tooFewColumns:
                return "Cần ít nhất 2 cột số để tìm bất thường đa biến — với một cột thì "
                    + "z-score cho đúng kết quả ấy mà rẻ hơn nhiều."
            case .tooFewRows(let rows, let columns):
                return "Chỉ có \(rows) hàng đủ số trên \(columns) cột. Cần nhiều hơn \(columns) "
                    + "hàng thì ma trận hiệp phương sai mới không suy biến."
            case .singular:
                return "Ma trận hiệp phương sai suy biến: trong các cột đã chọn có cột là tổ "
                    + "hợp tuyến tính của cột khác (thường gặp: một cột thành tiền bằng tích của "
                    + "hai cột kia), hoặc có cột chỉ toàn một giá trị. Bỏ bớt một cột rồi thử "
                    + "lại."
            }
        }
    }

    /// - Parameter rows: chỉ những hàng ĐỦ SỐ. Lọc là việc của tầng gọi, vì nó còn phải giữ
    ///   chỉ số hàng gốc để báo cho người dùng.
    public init(rows: [[Double]], columns: [String], cancelToken: CancelToken = CancelToken())
        throws {
        let k = columns.count
        guard k >= 2 else { throw Failure.tooFewColumns }
        guard rows.count > k else {
            throw Failure.tooFewRows(rows: rows.count, columns: k)
        }
        self.columns = columns
        self.rowCount = rows.count

        let n = Double(rows.count)
        var mean = [Double](repeating: 0, count: k)
        for row in rows {
            for j in 0..<k { mean[j] += row[j] }
        }
        for j in 0..<k { mean[j] /= n }
        self.mean = mean

        var cov = [[Double]](repeating: [Double](repeating: 0, count: k), count: k)
        for row in rows {
            try cancelToken.check()
            for i in 0..<k {
                let di = row[i] - mean[i]
                for j in i..<k { cov[i][j] += di * (row[j] - mean[j]) }
            }
        }
        for i in 0..<k {
            for j in i..<k {
                cov[i][j] /= (n - 1)
                cov[j][i] = cov[i][j]
            }
        }
        guard let inverse = AnomalyDetector.invert(cov) else { throw Failure.singular }
        self.inverse = inverse

        // k ma trận con, mỗi cái bỏ đi một hàng và một cột.
        //
        // Một ma trận con CÓ THỂ suy biến ngay cả khi ma trận đầy đủ thì không — nhưng ngược
        // lại thì không: bỏ bớt cột chỉ làm bài toán dễ hơn. Trường hợp suy biến ở đây được ghi
        // là "không phân rã được cột này" chứ không làm hỏng cả kết quả, vì khoảng cách đầy đủ
        // vẫn tính được và vẫn đúng.
        var subInverse: [[[Double]]] = []
        var subMean: [[Double]] = []
        for skip in 0..<k {
            let keep = (0..<k).filter { $0 != skip }
            let minor = keep.map { i in keep.map { j in cov[i][j] } }
            subInverse.append(AnomalyDetector.invert(minor) ?? [])
            subMean.append(keep.map { mean[$0] })
        }
        self.subInverse = subInverse
        self.subMean = subMean
    }

    /// D² trên đủ k cột.
    public func squaredDistance(of row: [Double]) -> Double {
        let k = columns.count
        guard row.count == k else { return 0 }
        let delta = (0..<k).map { row[$0] - mean[$0] }
        return quadratic(delta, inverse)
    }

    public func distance(of row: [Double]) -> Double {
        max(0, squaredDistance(of: row)).squareRoot()
    }

    public struct Contribution: Equatable, Sendable {
        public var column: String
        /// ΔD²(j) = D² đầy đủ − D² khi bỏ cột j. Luôn ≥ 0.
        public var delta: Double
        /// Phần trăm sau chuẩn hoá. Tổng đúng 100 (xem ghi chú đầu tệp về ý nghĩa).
        public var percent: Double

        public init(column: String, delta: Double, percent: Double) {
            self.column = column
            self.delta = delta
            self.percent = percent
        }
    }

    /// Phân rã leave-one-out cho một hàng, sắp giảm dần theo đóng góp.
    public func contributions(of row: [Double]) -> [Contribution] {
        let k = columns.count
        guard row.count == k else { return [] }
        let full = squaredDistance(of: row)
        var deltas = [Double](repeating: 0, count: k)
        for skip in 0..<k {
            let reduced = subInverse[skip]
            guard !reduced.isEmpty else {
                // Ma trận con suy biến: bỏ cột này thì các cột còn lại phụ thuộc tuyến tính
                // nhau. Không đo được thì để 0 và để phần trăm chảy sang các cột khác — chứ
                // không bịa một con số.
                deltas[skip] = 0
                continue
            }
            let keep = (0..<k).filter { $0 != skip }
            let delta = keep.enumerated().map { row[$0.element] - subMean[skip][$0.offset] }
            // Kẹp về 0: đẳng thức bảo đảm ΔD² ≥ 0, nhưng số dấu phẩy động có thể cho ra −1e−15
            // và một "−0,00%" trong bảng làm người đọc mất tin vào cả bảng.
            deltas[skip] = max(0, full - quadratic(delta, reduced))
        }
        let total = deltas.reduce(0, +)
        // Tổng bằng 0 khi hàng nằm ĐÚNG tâm dữ liệu: D² = 0, không có gì để phân rã, và mọi
        // phần trăm là 0/0. Trả về 0 cho tất cả — chứ không chia đều 100/k, vì chia đều là bịa
        // ra một cấu trúc không tồn tại, và câu giải thích khi ấy sẽ nói "chủ yếu do cột A"
        // về một hàng hoàn toàn bình thường.
        //
        // Đây là biên duy nhất mà "tổng % luôn = 100" của đặc tả không đúng được, và nó không
        // đụng tới đường dùng thật: phân rã chỉ chạy cho những dòng ĐÃ vượt ngưỡng.
        return (0..<k).map { j in
            Contribution(
                column: columns[j], delta: deltas[j],
                percent: total > 0 ? deltas[j] / total * 100 : 0)
        }.sorted { $0.delta > $1.delta }
    }

    /// Câu giải thích tự động, đúng dạng đặc tả nêu.
    ///
    /// Chỉ nêu những cột đủ đáng kể (≥ 5%) và tối đa ba cột: một câu liệt kê đủ tám cột với
    /// những con số 2% thì không ai đọc, và cái đáng nói bị chôn giữa những cái không đáng.
    public func explanation(of row: [Double]) -> String {
        let parts = contributions(of: row)
            .filter { $0.percent >= 5 }
            .prefix(3)
            .map { "\($0.column) (\(ChartRender.number($0.percent))%)" }
        guard !parts.isEmpty else {
            return "bất thường trải đều trên các cột, không cột nào chiếm quá 5%"
        }
        if parts.count == 1 { return "bất thường chủ yếu do \(parts[0])" }
        return "bất thường chủ yếu do tổ hợp " + parts.joined(separator: " × ")
    }

    /// Khối Phương pháp cho phần phân rã (NFR-MIN-04).
    public static let methodology = """
        Phân rã đóng góp: leave-one-out. ΔD²(j) = D² trên đủ các cột − D² khi bỏ cột j; \
        phần trăm = ΔD²(j) / Σ ΔD².
        ΔD²(j) luôn ≥ 0 vì D²đủ = D²(bỏ j) + (xⱼ − x̂ⱼ)² / σ²(j | các cột còn lại).
        LƯU Ý CÁCH ĐỌC: tổng các ΔD² KHÔNG bằng D² khi các cột có tương quan (phần "chung" \
        giữa các cột không thuộc riêng cột nào). Chia cho tổng để ra 100% là quy ước cho dễ \
        đọc. "61%" nghĩa là trong phần giải thích được, cột ấy chiếm 61% — không phải 61% \
        khoảng cách nằm ở cột ấy.
        """

    private func quadratic(_ delta: [Double], _ matrix: [[Double]]) -> Double {
        var total = 0.0
        for i in 0..<delta.count {
            var acc = 0.0
            for j in 0..<delta.count { acc += matrix[i][j] * delta[j] }
            total += delta[i] * acc
        }
        return total
    }
}
