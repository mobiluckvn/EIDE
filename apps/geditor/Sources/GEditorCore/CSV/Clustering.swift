import Foundation

/// Phân cụm — FR-MIN-002.
///
/// Đặc tả: *"K-MEANS: khởi tạo k-means++, seed cố định; k do người dùng chọn HOẶC gợi ý tự động
/// bằng elbow trên đường cong WCSS; tối đa 50 vòng lặp, dừng sớm khi hội tụ. DBSCAN: eps gợi ý
/// qua k-distance plot, minPts mặc định 2×số chiều; điểm nhiễu gán nhãn noise. Chuẩn hóa z-score
/// hoặc min-max TRƯỚC khi cụm (bật mặc định, tắt được, ghi rõ trong kết quả). Đầu ra: tab MỚI =
/// dữ liệu gốc + cột cluster_id; bảng tâm cụm + kích thước + silhouette score; scatter tô màu
/// theo cụm."*
///
/// ## Chuẩn hoá là mặc định vì không chuẩn hoá thì kết quả VÔ NGHĨA
///
/// Cụm `doanh_thu` (hàng triệu) cạnh `so_luong` (hàng đơn vị): khoảng cách Euclid gần như hoàn
/// toàn do `doanh_thu` quyết định, và `so_luong` không tham gia. Người dùng nghĩ họ đang cụm
/// theo hai chiều, thực tế đang cụm theo một. Đây không phải "kết quả kém tối ưu" — nó là một
/// kết quả trả lời câu hỏi khác.
///
/// Nhưng đặc tả cho **tắt được**, và đúng: khi các cột đã cùng đơn vị (mười hai tháng doanh thu
/// chẳng hạn), chuẩn hoá làm mất chính cái mà người ta muốn giữ. Nên nó là lựa chọn, và **cách
/// đã chọn được ghi vào kết quả** — một bảng cụm không nói ra nó đã chuẩn hoá hay chưa là một
/// bảng không tái lập được.
///
/// ## Silhouette là O(n²), và ở đây nó được LẤY MẪU
///
/// Silhouette đúng nghĩa so mỗi điểm với mọi điểm khác. Với 100.000 dòng đó là 10¹⁰ phép tính —
/// không phải chậm, là bất khả. Nên với bảng lớn nó tính trên một mẫu, và **kết quả nói rõ đã
/// lấy mẫu bao nhiêu**. Cùng khuôn với ghi chú rút gọn của biểu đồ (NFR-QRY-02): một con số ước
/// lượng không tự khai là ước lượng thì bị đọc như số đo.
public enum Clustering {

    /// Trần vòng lặp k-means, theo đặc tả.
    public static let maximumIterations = 50
    /// Số điểm tối đa dùng để tính silhouette. Trên mức này thì lấy mẫu tất định.
    public static let silhouetteSampleLimit = 2_000

    // MARK: - Chuẩn hoá

    public enum Scaling: String, CaseIterable, Equatable, Sendable {
        case zScore, minMax, none

        public var vietnamese: String {
            switch self {
            case .zScore: return "z-score"
            case .minMax: return "min-max"
            case .none: return "không chuẩn hoá"
            }
        }
    }

    /// Chuẩn hoá theo CỘT. Cột hằng giữ nguyên 0 — chia cho 0 sẽ cho `nan` và làm hỏng mọi
    /// khoảng cách về sau, kể cả những chiều không liên quan.
    static func scaled(_ rows: [[Double]], by scaling: Scaling) -> [[Double]] {
        guard scaling != .none, let first = rows.first else { return rows }
        let k = first.count
        let n = Double(rows.count)
        var out = rows
        for j in 0..<k {
            let column = rows.map { $0[j] }
            switch scaling {
            case .zScore:
                let mean = column.reduce(0, +) / n
                let variance = column.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / max(1, n - 1)
                let sd = variance.squareRoot()
                guard sd > 0 else {
                    for i in 0..<rows.count { out[i][j] = 0 }
                    continue
                }
                for i in 0..<rows.count { out[i][j] = (rows[i][j] - mean) / sd }
            case .minMax:
                let low = column.min() ?? 0
                let span = (column.max() ?? 0) - low
                guard span > 0 else {
                    for i in 0..<rows.count { out[i][j] = 0 }
                    continue
                }
                for i in 0..<rows.count { out[i][j] = (rows[i][j] - low) / span }
            case .none: break
            }
        }
        return out
    }

    // MARK: - Kết quả

    public struct Cluster: Equatable, Sendable {
        public var id: Int
        /// Tâm cụm, trong thang ĐÃ CHUẨN HOÁ.
        public var centre: [Double]
        /// Tâm cụm quy về thang GỐC — con số người dùng đọc được ("doanh thu trung bình 4,2
        /// triệu"), chứ không phải "0,31 độ lệch chuẩn".
        public var centreInOriginalUnits: [Double]
        public var size: Int

        public init(id: Int, centre: [Double], centreInOriginalUnits: [Double], size: Int) {
            self.id = id
            self.centre = centre
            self.centreInOriginalUnits = centreInOriginalUnits
            self.size = size
        }
    }

    public struct Result: Equatable, Sendable {
        /// Nhãn cụm theo HÀNG GỐC. `-1` = nhiễu (chỉ DBSCAN sinh ra), `nil` = hàng thiếu số.
        public var labels: [Int?]
        public var clusters: [Cluster]
        public var columns: [String]
        public var scaling: Scaling
        public var seed: UInt64
        /// `nil` khi không tính được (một cụm duy nhất, hoặc quá ít điểm).
        public var silhouette: Double?
        /// Rỗng khi silhouette tính trên toàn bộ. Có chữ khi đã lấy mẫu.
        public var silhouetteNote: String
        public var iterations: Int
        public var converged: Bool
        public var methodology: String

        public init(
            labels: [Int?], clusters: [Cluster], columns: [String], scaling: Scaling,
            seed: UInt64, silhouette: Double?, silhouetteNote: String, iterations: Int,
            converged: Bool, methodology: String
        ) {
            self.labels = labels
            self.clusters = clusters
            self.columns = columns
            self.scaling = scaling
            self.seed = seed
            self.silhouette = silhouette
            self.silhouetteNote = silhouetteNote
            self.iterations = iterations
            self.converged = converged
            self.methodology = methodology
        }

        public var noiseCount: Int { labels.filter { $0 == -1 }.count }
    }

    public enum Failure: Error, Equatable, Sendable {
        case tooFewRows(have: Int, need: Int)
        case noColumns

        public var message: String {
            switch self {
            case .tooFewRows(let have, let need):
                return "Chỉ có \(have) hàng đủ số, cần ít nhất \(need)."
            case .noColumns:
                return "Chưa chọn cột số nào để phân cụm."
            }
        }
    }

    // MARK: - k-means

    /// - Parameter seed: ghi vào kết quả. Mặc định cố định, KHÔNG lấy từ đồng hồ — xem
    ///   `SeededGenerator`.
    public static func kMeans(
        rows: [[Double]], columns: [String], k: Int, scaling: Scaling = .zScore,
        seed: UInt64 = 20_260_826, cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        guard !columns.isEmpty else { throw Failure.noColumns }
        let (usable, indices) = usableRows(rows, width: columns.count)
        let clusterCount = max(1, min(k, usable.count))
        guard usable.count >= clusterCount else {
            throw Failure.tooFewRows(have: usable.count, need: clusterCount)
        }

        let points = scaled(usable, by: scaling)
        var generator = SeededGenerator(seed: seed)
        var centres = try seedCentres(
            points, k: clusterCount, generator: &generator, cancelToken: cancelToken)

        var assignment = [Int](repeating: 0, count: points.count)
        var iterations = 0
        var converged = false
        while iterations < maximumIterations {
            try cancelToken.check()
            iterations += 1
            var changed = false
            for (index, point) in points.enumerated() {
                let nearest = nearestCentre(point, centres)
                if assignment[index] != nearest {
                    assignment[index] = nearest
                    changed = true
                }
            }
            // Dừng sớm khi KHÔNG hàng nào đổi cụm. So tâm cụm thay vì so phân công là cách hay
            // gặp và nó sai theo hướng nguy hiểm: tâm có thể nhích một lượng nhỏ mãi mãi vì sai
            // số dấu phẩy động, và vòng lặp chạy đủ 50 lần mỗi lần dù kết quả đã đứng yên.
            if !changed {
                converged = true
                break
            }
            centres = recentre(points, assignment: assignment, k: clusterCount, previous: centres)
        }

        return try assemble(
            points: points, original: usable, indices: indices, rowCount: rows.count,
            assignment: assignment, centres: centres, columns: columns, scaling: scaling,
            seed: seed, iterations: iterations, converged: converged,
            methodology: """
                Phương pháp: k-means, k = \(clusterCount), khởi tạo k-means++ với seed \(seed).
                Chuẩn hoá: \(scaling.vietnamese) (theo từng cột, trước khi tính khoảng cách).
                Dừng sau \(iterations)/\(maximumIterations) vòng — \
                \(converged ? "đã hội tụ (không hàng nào đổi cụm)" : "CHẠM TRẦN vòng lặp, kết quả có thể chưa ổn định").
                Khoảng cách Euclid trong thang đã chuẩn hoá. Kết quả TẤT ĐỊNH: cùng dữ liệu, \
                cùng k và cùng seed cho cùng phân cụm.
                """,
            cancelToken: cancelToken)
    }

    /// k-means++: tâm đầu chọn ngẫu nhiên, mỗi tâm sau chọn với xác suất tỉ lệ D(x)².
    ///
    /// Khởi tạo ngẫu nhiên thuần cho kết quả tệ một cách có hệ thống: hai tâm rơi vào cùng một
    /// đám thì k-means không tách chúng ra được nữa, và cụm còn lại nuốt hết phần dữ liệu kia.
    /// k-means++ đẩy các tâm ra xa nhau ngay từ đầu, và đó là toàn bộ khác biệt về chất lượng.
    private static func seedCentres(
        _ points: [[Double]], k: Int, generator: inout SeededGenerator, cancelToken: CancelToken
    ) throws -> [[Double]] {
        guard let first = points.first else { return [] }
        var centres = [points[Int(generator.nextUnit() * Double(points.count)) % points.count]]
        _ = first
        var distances = [Double](repeating: .greatestFiniteMagnitude, count: points.count)

        while centres.count < k {
            try cancelToken.check()
            var total = 0.0
            for (index, point) in points.enumerated() {
                distances[index] = min(
                    distances[index], squaredDistance(point, centres[centres.count - 1]))
                total += distances[index]
            }
            guard total > 0 else {
                // Mọi điểm còn lại trùng khít một tâm đã có. Không có gì để tách thêm; thêm tâm
                // trùng lặp chỉ tạo ra cụm rỗng. Dừng với ít cụm hơn yêu cầu là câu trả lời
                // đúng, và `clusters` sẽ nói ra số cụm thật.
                break
            }
            // Chọn theo bánh xe roulette trên D(x)².
            let target = generator.nextUnit() * total
            var accumulated = 0.0
            var chosen = points.count - 1
            for (index, distance) in distances.enumerated() {
                accumulated += distance
                if accumulated >= target {
                    chosen = index
                    break
                }
            }
            centres.append(points[chosen])
        }
        return centres
    }

    private static func nearestCentre(_ point: [Double], _ centres: [[Double]]) -> Int {
        var best = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, centre) in centres.enumerated() {
            let distance = squaredDistance(point, centre)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    private static func recentre(
        _ points: [[Double]], assignment: [Int], k: Int, previous: [[Double]]
    ) -> [[Double]] {
        let width = points.first?.count ?? 0
        var sums = [[Double]](repeating: [Double](repeating: 0, count: width), count: k)
        var counts = [Int](repeating: 0, count: k)
        for (index, point) in points.enumerated() {
            let cluster = assignment[index]
            counts[cluster] += 1
            for j in 0..<width { sums[cluster][j] += point[j] }
        }
        return (0..<k).map { cluster in
            // Cụm RỖNG giữ nguyên tâm cũ thay vì thành gốc toạ độ. Đặt về 0 là dời tâm ấy tới
            // một chỗ có thể nằm giữa dữ liệu, và vòng sau nó hút mất một phần cụm khác — một
            // cụm rỗng khi ấy sinh ra dao động không bao giờ hội tụ.
            guard counts[cluster] > 0 else { return previous[cluster] }
            return sums[cluster].map { $0 / Double(counts[cluster]) }
        }
    }

    // MARK: - Chung

    static func squaredDistance(_ a: [Double], _ b: [Double]) -> Double {
        var total = 0.0
        for index in 0..<min(a.count, b.count) {
            let d = a[index] - b[index]
            total += d * d
        }
        return total
    }

    /// Những hàng đủ số, kèm chỉ số hàng GỐC để trả nhãn về đúng chỗ.
    private static func usableRows(_ rows: [[Double]], width: Int) -> ([[Double]], [Int]) {
        var usable: [[Double]] = []
        var indices: [Int] = []
        for (index, row) in rows.enumerated()
        where row.count == width && row.allSatisfy(\.isFinite) {
            usable.append(row)
            indices.append(index)
        }
        return (usable, indices)
    }

    private static func assemble(
        points: [[Double]], original: [[Double]], indices: [Int], rowCount: Int,
        assignment: [Int], centres: [[Double]], columns: [String], scaling: Scaling,
        seed: UInt64, iterations: Int, converged: Bool, methodology: String,
        cancelToken: CancelToken
    ) throws -> Result {
        var labels = [Int?](repeating: nil, count: rowCount)
        for (position, index) in indices.enumerated() { labels[index] = assignment[position] }

        let width = columns.count
        var sizes = [Int](repeating: 0, count: centres.count)
        var originalSums = [[Double]](
            repeating: [Double](repeating: 0, count: width), count: centres.count)
        for (position, cluster) in assignment.enumerated() where cluster >= 0 {
            sizes[cluster] += 1
            for j in 0..<width { originalSums[cluster][j] += original[position][j] }
        }
        let clusters = (0..<centres.count).map { id in
            Cluster(
                id: id, centre: centres[id],
                centreInOriginalUnits: sizes[id] > 0
                    ? originalSums[id].map { $0 / Double(sizes[id]) }
                    : [Double](repeating: .nan, count: width),
                size: sizes[id])
        }

        let (score, note) = try silhouette(
            points: points, assignment: assignment, seed: seed, cancelToken: cancelToken)
        var text = methodology
        if let score {
            text += "\nSilhouette \(ChartRender.number(score)) "
                + "(−1 tệ · 0 chồng lấn · +1 tách bạch)."
            if !note.isEmpty { text += " \(note)" }
        } else {
            text += "\nKhông tính được silhouette: cần ít nhất 2 cụm không rỗng."
        }
        return Result(
            labels: labels, clusters: clusters, columns: columns, scaling: scaling, seed: seed,
            silhouette: score, silhouetteNote: note, iterations: iterations,
            converged: converged, methodology: text)
    }

    // MARK: - Silhouette

    /// Điểm silhouette trung bình, LẤY MẪU khi bảng lớn.
    ///
    /// Với mỗi điểm: `s = (b − a) / max(a, b)`, `a` = khoảng cách trung bình tới cùng cụm,
    /// `b` = nhỏ nhất trong các khoảng cách trung bình tới cụm khác.
    ///
    /// Mẫu chọn bằng bước nhảy đều tính từ một điểm bắt đầu do seed quyết định — tất định, và
    /// không rơi vào bẫy "lấy 2.000 dòng ĐẦU", vốn sẽ lấy trúng một cụm duy nhất trên bảng đã
    /// được sắp xếp sẵn (mà bảng của người dùng thường đã sắp).
    static func silhouette(
        points: [[Double]], assignment: [Int], seed: UInt64, cancelToken: CancelToken
    ) throws -> (Double?, String) {
        let clusterCount = (assignment.max() ?? -1) + 1
        let occupied = Set(assignment.filter { $0 >= 0 }).count
        guard clusterCount >= 2, occupied >= 2, points.count > clusterCount else {
            return (nil, "")
        }

        var sampleIndices: [Int]
        var note = ""
        if points.count <= silhouetteSampleLimit {
            sampleIndices = Array(points.indices)
        } else {
            let step = Double(points.count) / Double(silhouetteSampleLimit)
            let offset = Int(SeededGenerator.mix(seed) % UInt64(max(1, Int(step))))
            sampleIndices = (0..<silhouetteSampleLimit).compactMap {
                let index = Int(Double($0) * step) + offset
                return index < points.count ? index : nil
            }
            note = "Tính trên mẫu \(sampleIndices.count) / \(points.count) điểm "
                + "(bước đều, tất định theo seed) — đây là ƯỚC LƯỢNG, không phải số đo đầy đủ."
        }

        var total = 0.0
        var counted = 0
        for index in sampleIndices {
            try cancelToken.check()
            let own = assignment[index]
            guard own >= 0 else { continue }
            var sums = [Double](repeating: 0, count: clusterCount)
            var counts = [Int](repeating: 0, count: clusterCount)
            for (other, point) in points.enumerated() where other != index {
                let cluster = assignment[other]
                guard cluster >= 0 else { continue }
                sums[cluster] += squaredDistance(points[index], point).squareRoot()
                counts[cluster] += 1
            }
            guard counts[own] > 0 else { continue }   // cụm một mình: s không định nghĩa
            let a = sums[own] / Double(counts[own])
            var b = Double.greatestFiniteMagnitude
            for cluster in 0..<clusterCount where cluster != own && counts[cluster] > 0 {
                b = min(b, sums[cluster] / Double(counts[cluster]))
            }
            guard b < .greatestFiniteMagnitude else { continue }
            let denominator = max(a, b)
            guard denominator > 0 else { continue }
            total += (b - a) / denominator
            counted += 1
        }
        guard counted > 0 else { return (nil, "") }
        return (total / Double(counted), note)
    }
}

// MARK: - DBSCAN

extension Clustering {

    /// Số chiều tối đa còn dùng lưới. Trên mức này thì quét thẳng.
    ///
    /// Lưới tìm hàng xóm bằng cách duyệt các ô kề, và số ô kề là `3^d`. Ở 5 chiều đã là 243 ô,
    /// ở 8 chiều là 6.561 — nhiều hơn cả số điểm trong phần lớn bảng, nên lưới trở thành CHẬM
    /// HƠN quét thẳng. Đây là mặt trái quen thuộc của chỉ mục không gian, và nó phải được nói
    /// ra chứ không giấu trong một hằng số không tên.
    static let gridDimensionLimit = 5

    /// DBSCAN — phân cụm theo mật độ. Điểm không thuộc cụm nào được gán nhãn `-1` (nhiễu).
    ///
    /// Khác k-means ở hai điểm quyết định cách dùng: **không cần biết trước số cụm**, và **có
    /// khái niệm nhiễu**. k-means bắt buộc mọi điểm phải thuộc một cụm, nên một hàng hỏng vẫn bị
    /// nhét vào đâu đó và kéo tâm cụm ấy đi.
    ///
    /// - Parameter minPoints: mặc định `2 × số chiều`, theo đặc tả.
    public static func dbscan(
        rows: [[Double]], columns: [String], eps: Double, minPoints: Int? = nil,
        scaling: Scaling = .zScore, seed: UInt64 = 20_260_826,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        guard !columns.isEmpty else { throw Failure.noColumns }
        let (usable, indices) = usableRows(rows, width: columns.count)
        guard usable.count >= 2 else { throw Failure.tooFewRows(have: usable.count, need: 2) }

        let points = scaled(usable, by: scaling)
        let minPts = minPoints ?? (2 * columns.count)
        let index = NeighbourIndex(points: points, radius: eps)

        // `-2` = chưa xét, `-1` = nhiễu, `≥ 0` = cụm.
        var labels = [Int](repeating: -2, count: points.count)
        var clusterId = 0
        for start in points.indices {
            try cancelToken.check()
            guard labels[start] == -2 else { continue }
            let seeds = index.neighbours(of: start)
            guard seeds.count >= minPts else {
                labels[start] = -1
                continue
            }
            labels[start] = clusterId
            // Hàng đợi, KHÔNG đệ quy: một cụm mật độ cao trải dài có thể sâu hàng chục nghìn
            // mức, và đệ quy ở đó là tràn ngăn xếp — sập ứng dụng, không phải một lỗi.
            var queue = seeds
            var cursor = 0
            while cursor < queue.count {
                try cancelToken.check()
                let current = queue[cursor]
                cursor += 1
                // Điểm ĐÃ bị gán nhiễu vẫn được nhận vào cụm: nó là điểm BIÊN — không đủ dày để
                // tự mở rộng cụm, nhưng nằm trong bán kính của một điểm lõi. Bỏ qua nó là bào
                // mòn rìa mọi cụm.
                if labels[current] == -1 { labels[current] = clusterId }
                guard labels[current] == -2 else { continue }
                labels[current] = clusterId
                let neighbours = index.neighbours(of: current)
                if neighbours.count >= minPts { queue.append(contentsOf: neighbours) }
            }
            clusterId += 1
        }

        // Tâm cụm DBSCAN là trung bình các thành viên — không phải một tham số của thuật toán
        // (DBSCAN không có tâm), nhưng người dùng cần một con số đại diện để đọc bảng.
        let width = columns.count
        var sums = [[Double]](repeating: [Double](repeating: 0, count: width), count: max(1, clusterId))
        var counts = [Int](repeating: 0, count: max(1, clusterId))
        for (position, label) in labels.enumerated() where label >= 0 {
            counts[label] += 1
            for j in 0..<width { sums[label][j] += points[position][j] }
        }
        let centres = (0..<clusterId).map { id -> [Double] in
            counts[id] > 0 ? sums[id].map { $0 / Double(counts[id]) }
                : [Double](repeating: 0, count: width)
        }

        let noise = labels.filter { $0 == -1 }.count
        return try assemble(
            points: points, original: usable, indices: indices, rowCount: rows.count,
            assignment: labels, centres: centres, columns: columns, scaling: scaling,
            seed: seed, iterations: 1, converged: true,
            methodology: """
                Phương pháp: DBSCAN, eps = \(ChartRender.number(eps)), minPts = \(minPts) \
                (mặc định 2 × số chiều).
                Chuẩn hoá: \(scaling.vietnamese) (theo từng cột, TRƯỚC khi tính khoảng cách — \
                eps đo trong thang đã chuẩn hoá).
                Tìm được \(clusterId) cụm; \(noise) / \(points.count) điểm là NHIỄU (nhãn −1) — \
                DBSCAN không ép mọi điểm phải thuộc một cụm.
                Kết quả TẤT ĐỊNH: không có thành phần ngẫu nhiên nào.
                """,
            cancelToken: cancelToken)
    }
}

/// Lưới không gian để tìm hàng xóm trong bán kính, thay cho việc so mọi cặp.
///
/// Cạnh ô bằng đúng bán kính, nên mọi hàng xóm nằm trong ô của điểm và các ô kề. Với dữ liệu
/// thật (điểm tụ thành đám) đây là khác biệt giữa vài giây và vài phút.
struct NeighbourIndex {

    private let points: [[Double]]
    private let radius: Double
    private let squaredRadius: Double
    private let buckets: [[Int]: [Int]]
    private let useGrid: Bool

    init(points: [[Double]], radius: Double) {
        self.points = points
        self.radius = radius
        self.squaredRadius = radius * radius
        let dimensions = points.first?.count ?? 0
        // Bán kính 0 hoặc không hữu hạn thì lưới vô nghĩa (mọi điểm rơi vào một ô, hoặc phép
        // chia cho 0). Quét thẳng vẫn cho câu trả lời ĐÚNG, chỉ chậm — đúng thứ tự ưu tiên.
        self.useGrid = dimensions > 0 && dimensions <= Clustering.gridDimensionLimit
            && radius.isFinite && radius > 0
        guard useGrid else {
            self.buckets = [:]
            return
        }
        var buckets: [[Int]: [Int]] = [:]
        for (index, point) in points.enumerated() {
            buckets[NeighbourIndex.cell(point, radius), default: []].append(index)
        }
        self.buckets = buckets
    }

    private static func cell(_ point: [Double], _ radius: Double) -> [Int] {
        point.map { Int(($0 / radius).rounded(.down)) }
    }

    func neighbours(of index: Int) -> [Int] {
        let point = points[index]
        guard useGrid else {
            return points.indices.filter {
                Clustering.squaredDistance(point, points[$0]) <= squaredRadius
            }
        }
        var found: [Int] = []
        for cell in neighbourCells(NeighbourIndex.cell(point, radius)) {
            for candidate in buckets[cell] ?? []
            where Clustering.squaredDistance(point, points[candidate]) <= squaredRadius {
                found.append(candidate)
            }
        }
        return found
    }

    /// Mọi ô lệch −1, 0, +1 theo từng chiều — `3^d` ô.
    private func neighbourCells(_ origin: [Int]) -> [[Int]] {
        var cells: [[Int]] = [[]]
        for axis in origin {
            var next: [[Int]] = []
            next.reserveCapacity(cells.count * 3)
            for prefix in cells {
                for delta in -1...1 { next.append(prefix + [axis + delta]) }
            }
            cells = next
        }
        return cells
    }
}

// MARK: - Gợi ý tham số

extension Clustering {

    /// Một điểm trên đường cong WCSS: `k` và tổng bình phương khoảng cách trong cụm.
    public struct ElbowPoint: Equatable, Sendable {
        public var k: Int
        public var wcss: Double

        public init(k: Int, wcss: Double) {
            self.k = k
            self.wcss = wcss
        }
    }

    /// Đường cong WCSS cho `k = 1 … maxK`, kèm `k` được gợi ý.
    ///
    /// ## Elbow tìm bằng KHOẢNG CÁCH TỚI DÂY CUNG, không bằng mắt
    ///
    /// Cách người ta hay mô tả — *"nhìn chỗ đường gãy"* — không cài đặt được. Cách cài đặt được:
    /// nối điểm đầu và điểm cuối của đường cong bằng một đoạn thẳng, rồi lấy điểm cách đoạn ấy
    /// xa nhất. Đó chính là chỗ đường cong "gãy" nhiều nhất so với xu hướng chung của nó, và nó
    /// tất định.
    ///
    /// **Gợi ý, không quyết định.** WCSS luôn giảm khi k tăng, nên "k tối ưu" theo WCSS luôn là
    /// `k = n`. Elbow chỉ là một mẹo đọc đồ thị chứ không phải một tiêu chí thống kê, và đặc tả
    /// dùng đúng chữ *"gợi ý"*. Người dùng vẫn chọn.
    public static func elbow(
        rows: [[Double]], columns: [String], maxK: Int = 10, scaling: Scaling = .zScore,
        seed: UInt64 = 20_260_826, cancelToken: CancelToken = CancelToken()
    ) throws -> (curve: [ElbowPoint], suggested: Int) {
        let (usable, _) = usableRows(rows, width: columns.count)
        let limit = max(2, min(maxK, usable.count - 1))
        guard usable.count >= 3 else {
            throw Failure.tooFewRows(have: usable.count, need: 3)
        }

        var curve: [ElbowPoint] = []
        for k in 1...limit {
            try cancelToken.check()
            let result = try kMeans(
                rows: rows, columns: columns, k: k, scaling: scaling, seed: seed,
                cancelToken: cancelToken)
            let points = scaled(usable, by: scaling)
            var wcss = 0.0
            for (position, label) in result.labels.compactMap({ $0 }).enumerated()
            where label >= 0 && label < result.clusters.count && position < points.count {
                wcss += squaredDistance(points[position], result.clusters[label].centre)
            }
            curve.append(ElbowPoint(k: k, wcss: wcss))
        }
        return (curve, suggestedK(from: curve))
    }

    /// `k` cách xa dây cung nối hai đầu đường cong nhất.
    static func suggestedK(from curve: [ElbowPoint]) -> Int {
        guard curve.count >= 3, let first = curve.first, let last = curve.last else {
            return curve.first?.k ?? 1
        }
        // Chuẩn hoá cả hai trục về [0, 1] TRƯỚC khi đo khoảng cách. Không thế thì trục WCSS
        // (hàng triệu) áp đảo trục k (1…10) và "điểm xa dây cung nhất" luôn rơi vào k = 2, bất
        // kể đường cong có hình gì.
        let kSpan = Double(last.k - first.k)
        let wcssSpan = first.wcss - last.wcss
        guard kSpan > 0, wcssSpan > 0 else { return first.k }

        var bestK = first.k
        var bestDistance = -1.0
        for point in curve {
            let x = Double(point.k - first.k) / kSpan
            let y = (point.wcss - last.wcss) / wcssSpan
            // Dây cung đi từ (0, 1) tới (1, 0), tức đường `x + y = 1`. Khoảng cách tỉ lệ với
            // |1 − x − y|, và mọi điểm của một đường cong lồi đều nằm dưới nó.
            let distance = abs(1 - x - y)
            if distance > bestDistance {
                bestDistance = distance
                bestK = point.k
            }
        }
        return bestK
    }

    /// Đường cong k-distance: khoảng cách tới hàng xóm gần thứ `k`, sắp GIẢM DẦN.
    ///
    /// Đây là cách chuẩn để chọn `eps` cho DBSCAN: chỗ đường cong bẻ gấp lên chính là ranh giới
    /// giữa "điểm trong đám" và "điểm ngoài rìa". `suggestedEps` lấy chỗ ấy bằng cùng phép đo
    /// dây cung mà elbow dùng — một phép đo cho hai bài toán cùng hình dạng.
    ///
    /// Chi phí là O(n²) nên nó **lấy mẫu** khi bảng lớn, và nói ra là đã lấy mẫu.
    public static func kDistanceCurve(
        rows: [[Double]], columns: [String], minPoints: Int? = nil,
        scaling: Scaling = .zScore, seed: UInt64 = 20_260_826,
        cancelToken: CancelToken = CancelToken()
    ) throws -> (curve: [Double], suggestedEps: Double, note: String) {
        let (usable, _) = usableRows(rows, width: columns.count)
        guard usable.count >= 3 else {
            throw Failure.tooFewRows(have: usable.count, need: 3)
        }
        let points = scaled(usable, by: scaling)
        let k = min(max(1, minPoints ?? (2 * columns.count)), points.count - 1)

        var sampleIndices = Array(points.indices)
        var note = ""
        if points.count > silhouetteSampleLimit {
            let step = Double(points.count) / Double(silhouetteSampleLimit)
            let offset = Int(SeededGenerator.mix(seed) % UInt64(max(1, Int(step))))
            sampleIndices = (0..<silhouetteSampleLimit).compactMap {
                let index = Int(Double($0) * step) + offset
                return index < points.count ? index : nil
            }
            note = "Đường cong dựng trên mẫu \(sampleIndices.count) / \(points.count) điểm "
                + "(bước đều, tất định theo seed)."
        }

        var distances: [Double] = []
        distances.reserveCapacity(sampleIndices.count)
        for index in sampleIndices {
            try cancelToken.check()
            var nearest: [Double] = []
            for other in points.indices where other != index {
                nearest.append(squaredDistance(points[index], points[other]))
            }
            nearest.sort()
            distances.append(nearest[min(k - 1, nearest.count - 1)].squareRoot())
        }
        distances.sort(by: >)

        // Dùng lại đúng phép đo dây cung của elbow bằng cách gói đường cong vào cùng kiểu dữ
        // liệu — hai bản hiện thực của cùng một mẹo hình học sẽ trôi ra xa nhau.
        let asCurve = distances.enumerated().map { ElbowPoint(k: $0.offset + 1, wcss: $0.element) }
        let kneeIndex = max(0, min(suggestedK(from: asCurve) - 1, distances.count - 1))
        return (distances, distances[kneeIndex], note)
    }
}
