import Foundation

/// Luật kết hợp — FR-MIN-003.
///
/// Đặc tả: *"Thuật toán Apriori với cắt tỉa hash-tree. Hai dạng đầu vào: (a) mỗi dòng một giỏ
/// hàng, item phân tách bởi delimiter chọn được; (b) dạng long 2 cột [mã giao dịch, item]. Tham
/// số: support và confidence tối thiểu (mặc định 1% / 50%). Đầu ra: bảng luật A→B với support,
/// confidence, lift, leverage — sắp/lọc theo cột; click một luật đánh dấu (Mark) mọi giao dịch
/// chứa luật đó trong file nguồn; xuất bảng luật CSV."*
///
/// ## Confidence cao là chỉ số DỄ ĐỌC NHẦM nhất trong cả cụm khai phá
///
/// *"Ai mua tã thì 92% cũng mua túi nylon"* nghe như một phát hiện. Nhưng nếu **95%** giỏ hàng
/// nào cũng có túi nylon, thì luật ấy nói rằng người mua tã mua túi nylon **ÍT HƠN** trung bình.
/// Confidence 92% ở đây là một con số đúng dẫn tới một kết luận ngược.
///
/// `lift` là thứ chữa nó: `lift = confidence / P(B)`. Bằng 1 nghĩa là "chẳng liên quan gì",
/// dưới 1 nghĩa là "liên quan NGƯỢC". `leverage = P(A∪B) − P(A)·P(B)` bổ sung một vế nữa —
/// lift lớn trên hai item cùng rất hiếm là chuyện thường và thường vô dụng, còn leverage cân
/// theo số giao dịch thật sự bị ảnh hưởng.
///
/// Nên cả bốn con số cùng nằm trong `Rule`, và **thứ tự mặc định là theo `lift`, không theo
/// `confidence`**. Sắp theo confidence đưa lên đầu bảng đúng những luật vô nghĩa nhất.
///
/// ## Về "cắt tỉa hash-tree"
///
/// Phần thật sự quyết định độ phức tạp của Apriori là **cắt tỉa theo bao đóng xuống**: một tập k
/// item chỉ có thể phổ biến nếu MỌI tập con k−1 của nó phổ biến. Chỗ này cài đúng như vậy.
///
/// Hash-tree là một cấu trúc để đếm nhanh xem một giao dịch chứa những ứng viên nào. Ở đây thay
/// bằng một `Dictionary` khoá theo tập item: cùng độ phức tạp (tra O(1) cho mỗi tập con ứng
/// viên), ít hơn khoảng hai trăm dòng, và không có cây nào để cân. Đây là một **sai lệch có chủ
/// ý so với chữ trong đặc tả** chứ không phải một chỗ quên, nên nó được ghi ra đây và trong
/// `methodology`.
public enum Apriori {

    public static let defaultMinimumSupport = 0.01
    public static let defaultMinimumConfidence = 0.5

    /// Trần số ứng viên mỗi tầng.
    ///
    /// Với `minSupport` rất nhỏ và nhiều item khác nhau, số ứng viên nổ theo tổ hợp. Trần này
    /// không phải để tối ưu — nó là để một lần bấm nhầm (support 0,01%) không ăn hết bộ nhớ máy
    /// rồi kéo cả ứng dụng theo. Chạm trần thì DỪNG và NÓI RA.
    public static let candidateLimit = 200_000

    // MARK: - Đọc đầu vào

    /// Dạng (a): mỗi dòng một giỏ, item phân tách bởi `delimiter`.
    ///
    /// Bỏ khoảng trắng quanh item, bỏ item rỗng, và **bỏ trùng trong cùng một giỏ**: mua hai hộp
    /// sữa vẫn là một giao dịch có sữa. Không bỏ trùng thì support của item ấy phồng lên theo số
    /// lượng mua chứ không theo số giao dịch, và mọi con số phía sau sai theo.
    public static func baskets(
        from rows: [String], delimiter: Character = ","
    ) -> [[String]] {
        rows.map { row in
            var seen = Set<String>()
            var items: [String] = []
            for piece in row.split(separator: delimiter, omittingEmptySubsequences: false) {
                let item = piece.trimmingCharacters(in: .whitespaces)
                guard !item.isEmpty, seen.insert(item).inserted else { continue }
                items.append(item)
            }
            return items.sorted()
        }
    }

    /// Dạng (b): hai cột `[mã giao dịch, item]`.
    ///
    /// Trả về giỏ theo thứ tự XUẤT HIỆN đầu tiên của mã giao dịch, kèm chỉ số hàng gốc của từng
    /// giỏ — cần cho việc bấm một luật rồi tô các dòng nguồn.
    public static func baskets(
        transactionIDs: [String?], items: [String?]
    ) -> (baskets: [[String]], rows: [[Int]]) {
        var order: [String] = []
        var grouped: [String: Set<String>] = [:]
        var rows: [String: [Int]] = [:]
        for index in 0..<min(transactionIDs.count, items.count) {
            guard let id = transactionIDs[index], !id.isEmpty,
                  let item = items[index]?.trimmingCharacters(in: .whitespaces), !item.isEmpty
            else { continue }
            if grouped[id] == nil {
                grouped[id] = []
                rows[id] = []
                order.append(id)
            }
            grouped[id]?.insert(item)
            rows[id]?.append(index)
        }
        return (order.map { (grouped[$0] ?? []).sorted() }, order.map { rows[$0] ?? [] })
    }

    // MARK: - Kết quả

    public struct Rule: Equatable, Sendable {
        public var antecedent: [String]
        public var consequent: [String]
        /// `P(A ∪ B)` — tỷ lệ giao dịch chứa cả hai vế.
        public var support: Double
        /// `P(A ∪ B) / P(A)`.
        public var confidence: Double
        /// `confidence / P(B)`. **1 = chẳng liên quan gì.**
        public var lift: Double
        /// `P(A ∪ B) − P(A)·P(B)`.
        public var leverage: Double
        /// Số giao dịch chứa cả hai vế.
        public var count: Int

        public init(
            antecedent: [String], consequent: [String], support: Double, confidence: Double,
            lift: Double, leverage: Double, count: Int
        ) {
            self.antecedent = antecedent
            self.consequent = consequent
            self.support = support
            self.confidence = confidence
            self.lift = lift
            self.leverage = leverage
            self.count = count
        }

        public var text: String {
            antecedent.joined(separator: " + ") + " → " + consequent.joined(separator: " + ")
        }

        /// Cảnh báo đọc nhầm, gắn vào từng luật.
        ///
        /// Không phải một cột phụ: đây là chỗ duy nhất người dùng gặp con số lift lúc họ đang
        /// nhìn một confidence 92% và sắp tin vào nó.
        public var caution: String {
            if lift < 1 {
                return "lift < 1: mua vế trái làm vế phải BỚT khả năng xuất hiện, dù "
                    + "confidence trông cao"
            }
            if lift < 1.1 {
                return "lift ≈ 1: hai vế gần như KHÔNG liên quan — confidence cao chỉ vì vế "
                    + "phải vốn đã phổ biến"
            }
            return ""
        }
    }

    public struct Result: Equatable, Sendable {
        public var rules: [Rule]
        public var transactionCount: Int
        public var itemCount: Int
        /// Số tập phổ biến tìm được, theo kích thước.
        public var frequentBySize: [Int: Int]
        /// Có phải đã dừng vì chạm trần ứng viên.
        public var hitCandidateLimit: Bool
        public var methodology: String

        public init(
            rules: [Rule], transactionCount: Int, itemCount: Int, frequentBySize: [Int: Int],
            hitCandidateLimit: Bool, methodology: String
        ) {
            self.rules = rules
            self.transactionCount = transactionCount
            self.itemCount = itemCount
            self.frequentBySize = frequentBySize
            self.hitCandidateLimit = hitCandidateLimit
            self.methodology = methodology
        }

        /// Giao dịch nào chứa TRỌN một luật — cho việc bấm luật rồi tô dòng nguồn.
        public static func transactions(
            containing rule: Rule, in baskets: [[String]]
        ) -> [Int] {
            let needed = Set(rule.antecedent).union(rule.consequent)
            return baskets.indices.filter { needed.isSubset(of: Set(baskets[$0])) }
        }
    }

    // MARK: - Chạy

    public static func run(
        baskets: [[String]],
        minimumSupport: Double = defaultMinimumSupport,
        minimumConfidence: Double = defaultMinimumConfidence,
        maximumItemsetSize: Int = 4,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        let nonEmpty = baskets.filter { !$0.isEmpty }
        let total = nonEmpty.count
        guard total > 0 else {
            return Result(
                rules: [], transactionCount: 0, itemCount: 0, frequentBySize: [:],
                hitCandidateLimit: false,
                methodology: "Không có giao dịch nào (mọi dòng đều rỗng).")
        }
        let minimumCount = max(1, Int((minimumSupport * Double(total)).rounded(.up)))
        let sets = nonEmpty.map { Set($0) }

        // --- Tầng 1 -------------------------------------------------------------------------
        var counts: [String: Int] = [:]
        for basket in sets {
            try cancelToken.check()
            for item in basket { counts[item, default: 0] += 1 }
        }
        let itemCount = counts.count
        // Sắp theo TÊN, không theo số đếm: hai item cùng số đếm phải luôn ra cùng một thứ tự,
        // nếu không thì hai lần chạy cho hai bảng luật khác nhau (NFR-MIN-02).
        var frequent: [[String]] = counts
            .filter { $0.value >= minimumCount }
            .keys.sorted().map { [$0] }

        var supportCount: [[String]: Int] = [:]
        for itemset in frequent { supportCount[itemset] = counts[itemset[0]] }
        var frequentBySize: [Int: Int] = [1: frequent.count]

        // --- Tầng 2 trở lên -----------------------------------------------------------------
        var hitLimit = false
        var size = 1
        while size < maximumItemsetSize, !frequent.isEmpty {
            try cancelToken.check()
            size += 1
            let candidates = generateCandidates(from: frequent, size: size)
            if candidates.count > candidateLimit {
                hitLimit = true
                break
            }
            guard !candidates.isEmpty else { break }

            var levelCounts: [[String]: Int] = [:]
            for basket in sets {
                try cancelToken.check()
                for candidate in candidates where candidate.allSatisfy(basket.contains) {
                    levelCounts[candidate, default: 0] += 1
                }
            }
            let survivors = levelCounts.filter { $0.value >= minimumCount }
            guard !survivors.isEmpty else { break }
            for (itemset, count) in survivors { supportCount[itemset] = count }
            frequent = survivors.keys.sorted { $0.lexicographicallyPrecedes($1) }
            frequentBySize[size] = frequent.count
        }

        // --- Sinh luật ----------------------------------------------------------------------
        var rules: [Rule] = []
        for (itemset, count) in supportCount where itemset.count >= 2 {
            try cancelToken.check()
            let unionSupport = Double(count) / Double(total)
            // Mọi cách chia tập thành (vế trái, vế phải) không rỗng.
            for mask in 1..<((1 << itemset.count) - 1) {
                var antecedent: [String] = []
                var consequent: [String] = []
                for (position, item) in itemset.enumerated() {
                    if mask & (1 << position) != 0 { antecedent.append(item) }
                    else { consequent.append(item) }
                }
                guard let antecedentCount = supportCount[antecedent], antecedentCount > 0,
                      let consequentCount = supportCount[consequent], consequentCount > 0
                else { continue }
                let confidence = Double(count) / Double(antecedentCount)
                guard confidence >= minimumConfidence else { continue }
                let pA = Double(antecedentCount) / Double(total)
                let pB = Double(consequentCount) / Double(total)
                rules.append(Rule(
                    antecedent: antecedent, consequent: consequent, support: unionSupport,
                    confidence: confidence, lift: pB > 0 ? confidence / pB : 0,
                    leverage: unionSupport - pA * pB, count: count))
            }
        }
        // Mặc định sắp theo LIFT, không theo confidence — xem ghi chú đầu tệp. Khoá phụ là
        // support rồi tới chuỗi luật, để thứ tự tất định khi lift bằng nhau.
        rules.sort {
            if $0.lift != $1.lift { return $0.lift > $1.lift }
            if $0.support != $1.support { return $0.support > $1.support }
            return $0.text < $1.text
        }

        return Result(
            rules: rules, transactionCount: total, itemCount: itemCount,
            frequentBySize: frequentBySize, hitCandidateLimit: hitLimit,
            methodology: methodologyText(
                total: total, itemCount: itemCount, minimumSupport: minimumSupport,
                minimumCount: minimumCount, minimumConfidence: minimumConfidence,
                maximumItemsetSize: maximumItemsetSize, frequentBySize: frequentBySize,
                ruleCount: rules.count, hitLimit: hitLimit))
    }

    /// Sinh ứng viên tầng `size` từ các tập phổ biến tầng `size − 1`, rồi CẮT TỈA.
    ///
    /// Hai bước, và bước thứ hai là linh hồn của Apriori:
    ///
    /// 1. **Ghép theo tiền tố**: hai tập chỉ khác nhau ở phần tử cuối thì ghép được. Vì mọi tập
    ///    đều sắp theo tên, cách này sinh mỗi ứng viên đúng MỘT lần — không cần khử trùng.
    /// 2. **Bao đóng xuống**: bỏ ngay ứng viên nào có một tập con `size − 1` KHÔNG phổ biến.
    ///    Không có bước này thì số ứng viên là tổ hợp chập `size` của toàn bộ item, và Apriori
    ///    không còn khác gì vét cạn.
    static func generateCandidates(from frequent: [[String]], size: Int) -> [[String]] {
        guard size >= 2, let width = frequent.first?.count, width == size - 1 else { return [] }
        let known = Set(frequent)
        var candidates: [[String]] = []
        for i in 0..<frequent.count {
            for j in (i + 1)..<frequent.count {
                let a = frequent[i], b = frequent[j]
                // Cùng tiền tố `size − 2` phần tử, khác nhau ở phần tử cuối.
                guard width == 1 || Array(a.dropLast()) == Array(b.dropLast()) else { continue }
                guard let lastA = a.last, let lastB = b.last, lastA < lastB else { continue }
                let candidate = a + [lastB]
                // Bao đóng xuống: mọi tập con bỏ đi một phần tử phải phổ biến.
                var survives = true
                for drop in 0..<candidate.count {
                    var subset = candidate
                    subset.remove(at: drop)
                    if !known.contains(subset) {
                        survives = false
                        break
                    }
                }
                if survives { candidates.append(candidate) }
            }
        }
        return candidates
    }

    private static func methodologyText(
        total: Int, itemCount: Int, minimumSupport: Double, minimumCount: Int,
        minimumConfidence: Double, maximumItemsetSize: Int, frequentBySize: [Int: Int],
        ruleCount: Int, hitLimit: Bool
    ) -> String {
        var text = """
            Phương pháp: Apriori trên \(total) giao dịch, \(itemCount) item khác nhau.
            Ngưỡng: support ≥ \(ChartRender.number(minimumSupport * 100))% \
            (tức ≥ \(minimumCount) giao dịch) · confidence ≥ \
            \(ChartRender.number(minimumConfidence * 100))% · tập tối đa \
            \(maximumItemsetSize) item.
            Cắt tỉa theo BAO ĐÓNG XUỐNG: một tập k item chỉ được xét nếu mọi tập con k−1 của nó \
            đã phổ biến. (Đặc tả viết "hash-tree"; ở đây đếm bằng bảng băm khoá theo tập item — \
            cùng độ phức tạp, ít mã hơn nhiều, và không có cây nào phải cân.)
            Tập phổ biến theo kích thước: \
            \(frequentBySize.keys.sorted().map { "\($0) item: \(frequentBySize[$0] ?? 0)" }
                .joined(separator: " · ")).
            Sinh ra \(ruleCount) luật, SẮP THEO LIFT.
            CÁCH ĐỌC: confidence cao KHÔNG có nghĩa là có liên hệ. Nếu vế phải vốn đã xuất hiện \
            trong 90% giao dịch thì mọi luật dẫn tới nó đều có confidence quanh 90% mà chẳng nói \
            gì. lift = confidence / P(vế phải): bằng 1 là không liên quan, dưới 1 là liên quan \
            NGƯỢC. leverage cân theo số giao dịch thật sự bị ảnh hưởng, nên nó hạ bớt những cặp \
            item cùng rất hiếm vốn hay có lift rất lớn mà vô dụng.
            """
        if hitLimit {
            text += "\nCẢNH BÁO: số ứng viên vượt \(candidateLimit) nên đã DỪNG sớm — bảng luật "
                + "này KHÔNG đầy đủ. Nâng ngưỡng support lên rồi chạy lại."
        }
        text += "\nThuật toán cổ điển, tự cài đặt trong GEditorCore — không dùng thư viện học "
            + "máy nào (NFR-MIN-04). Kết quả TẤT ĐỊNH."
        return text
    }
}
