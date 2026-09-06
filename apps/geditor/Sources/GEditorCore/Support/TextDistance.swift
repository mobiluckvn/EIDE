import Foundation

/// Khoảng cách chỉnh sửa giữa hai chuỗi — nền dùng chung cho mọi phép so MỜ.
///
/// ## Vì sao ở đây chứ không nằm trong tệp đầu tiên cần nó
///
/// Ba mã yêu cầu cần đúng phép đo này: FR-CLN-004 (khử trùng lặp mờ), FR-KNW-923 (gom biến thể
/// entity), và FR-KNW-924 (nhãn node trùng gần). Dự án này đã gặp mẫu **"hai bản của một thuật
/// toán"** ba lần — MAD của FR-DQR và FR-MIN-001, SplitMix64 của `PieceTree` và `SeededGenerator`,
/// hằng số outlier — và mỗi lần hai bản cho hai con số khác nhau trên cùng một dữ liệu.
///
/// Nên nó ra đời ở đây, ở chỗ dùng chung, ngay lần đầu cần tới.
///
/// ## Levenshtein, không phải Jaccard
///
/// Nhãn node là chuỗi NGẮN (tên người, tên tổ chức), và cái sai của chúng là sai CHÍNH TẢ hoặc
/// thiếu dấu: «Nguyễn Văn A» ↔ «Nguyen Van A» ↔ «Nguyễn Văn Á». Levenshtein đo đúng loại sai
/// ấy. Jaccard trên shingle (thứ FR-KNW-922 dùng cho chunk) đo sự chồng lấn của những đoạn dài,
/// và trên chuỗi mười ký tự thì nó nhiễu.
public enum TextDistance {

    /// Khoảng cách Levenshtein, có TRẦN.
    ///
    /// Trần không phải để tiết kiệm bộ nhớ mà để **cắt sớm**: mọi chỗ dùng đều hỏi "hai chuỗi
    /// này có gần nhau không", chứ không hỏi "xa nhau bao nhiêu". Vượt trần thì trả `limit + 1`
    /// và dừng — trên một danh sách mười nghìn nhãn, khác biệt ấy là khác biệt giữa vài trăm
    /// mili-giây và vài phút.
    public static func levenshtein(_ left: [UInt8], _ right: [UInt8], limit: Int) -> Int {
        if left.isEmpty { return min(right.count, limit + 1) }
        if right.isEmpty { return min(left.count, limit + 1) }
        // Chênh lệch độ dài đã vượt trần thì khỏi tính: đó là cận dưới của khoảng cách.
        if abs(left.count - right.count) > limit { return limit + 1 }

        var previous = Array(0 ... right.count)
        var current = [Int](repeating: 0, count: right.count + 1)
        for i in 1 ... left.count {
            current[0] = i
            var best = current[0]
            for j in 1 ... right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                best = min(best, current[j])
            }
            // Cả một hàng đều vượt trần thì mọi hàng sau cũng vậy — khoảng cách chỉ tăng.
            if best > limit { return limit + 1 }
            swap(&previous, &current)
        }
        return min(previous[right.count], limit + 1)
    }

    /// Độ giống 0…1: `1 − khoảng cách ÷ độ dài chuỗi dài hơn`.
    ///
    /// Chia cho chuỗi DÀI hơn chứ không cho trung bình: «An» và «An Nguyễn Văn» khác nhau 11 ký
    /// tự trên 13, và chia cho trung bình sẽ cho ra một con số nghe như "khá giống".
    public static func similarity(_ left: String, _ right: String, threshold: Double) -> Double {
        let a = Array(normalize(left).utf8)
        let b = Array(normalize(right).utf8)
        let longest = max(a.count, b.count)
        guard longest > 0 else { return left == right ? 1 : 0 }
        // Trần suy NGƯỢC từ ngưỡng: chỉ cần biết "có đạt ngưỡng không".
        let limit = Int((1 - threshold) * Double(longest))
        let distance = levenshtein(a, b, limit: limit)
        return distance > limit ? 0 : 1 - Double(distance) / Double(longest)
    }

    /// Chuẩn hoá trước khi so: bỏ dấu, hạ chữ thường, gom khoảng trắng.
    ///
    /// Bỏ dấu ở ĐÂY thì đúng, khác hẳn chỗ truy hồi (`BM25Tokenizer` GIỮ dấu). Lý do: ở đây ta
    /// đang tìm những nhãn **đáng lẽ là một** mà bị gõ khác nhau, và thiếu dấu là kiểu gõ khác
    /// phổ biến nhất trong dữ liệu tiếng Việt. Ở truy hồi thì ngược lại — gộp `má` với `ma` là
    /// gộp hai từ chẳng liên quan.
    public static func normalize(_ text: String) -> String {
        CSVFilter.fold(text.lowercased())
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Cụm chuỗi GẦN NHAU, gom bắc cầu.
    ///
    /// Lọc theo ĐỘ DÀI trước khi tính khoảng cách: hai chuỗi lệch nhau quá `(1 − ngưỡng) × dài`
    /// ký tự thì chắc chắn không đạt, và phép lọc ấy rẻ hơn Levenshtein vài bậc.
    ///
    /// Trả về cụm theo chỉ số TĂNG DẦN, cụm sắp theo phần tử đầu — tất định.
    public static func clusters(
        _ values: [String], threshold: Double, cancelToken: CancelToken? = nil
    ) -> [[Int]] {
        let normalized = values.map { Array(normalize($0).utf8) }
        let order = values.indices.sorted {
            normalized[$0].count != normalized[$1].count
                ? normalized[$0].count < normalized[$1].count : $0 < $1
        }
        var parent = Array(values.indices)
        func find(_ node: Int) -> Int {
            var node = node
            while parent[node] != node { parent[node] = parent[parent[node]]; node = parent[node] }
            return node
        }

        for (position, index) in order.enumerated() {
            if cancelToken?.isCancelled == true { break }
            let a = normalized[index]
            guard !a.isEmpty else { continue }
            for other in order[(position + 1)...] {
                let b = normalized[other]
                let longest = max(a.count, b.count)
                let limit = Int((1 - threshold) * Double(longest))
                // Danh sách đã sắp theo độ dài, nên khi chênh lệch vượt trần thì mọi chuỗi sau
                // cũng vậy — dừng hẳn vòng trong.
                if b.count - a.count > limit { break }
                guard levenshtein(a, b, limit: limit) <= limit else { continue }
                let left = find(index), right = find(other)
                if left != right { parent[max(left, right)] = min(left, right) }
            }
        }

        var groups: [Int: [Int]] = [:]
        for index in values.indices { groups[find(index), default: []].append(index) }
        return groups.values.filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { ($0.first ?? 0) < ($1.first ?? 0) }
    }
}
