import Foundation

/// Một gợi ý tự hoàn thành (FR-CORE-013).
public struct CompletionCandidate: Equatable, Sendable {

    public enum Source: Equatable, Sendable {
        /// Từ đã xuất hiện đâu đó trong tài liệu.
        case document
        /// Tên hàm/lớp lấy từ cây cú pháp — thứ người dùng thật sự muốn gõ đúng.
        case symbol
    }

    public let word: String
    public let source: Source
    /// Điểm khớp; cao hơn thì đứng trên.
    public let score: Int
}

/// Tự hoàn thành theo từ trong tài liệu và theo ký hiệu (FR-CORE-013).
///
/// Không có máy chủ ngôn ngữ, không có mô hình: gợi ý lấy từ chính TÀI LIỆU đang mở, cộng với
/// danh sách hàm/lớp mà Function List đã dựng. Với một trình soạn thảo đa ngôn ngữ thì đó là
/// nguồn duy nhất luôn đúng — nó không bao giờ gợi ý một cái tên không tồn tại trong dự án.
public enum CompletionEngine {

    /// Số ký tự tối thiểu trước khi gợi ý.
    ///
    /// Gợi ý ngay từ ký tự đầu sẽ bung một danh sách dài mỗi lần người dùng bắt đầu một từ,
    /// và cái danh sách ấy che mất chính dòng họ đang gõ. Cấu hình được, đúng như đặc tả đòi.
    public static let defaultMinimumPrefix = 2

    /// Cửa sổ quét quanh con nháy.
    ///
    /// Không quét cả tài liệu: trên file một gigabyte thì mỗi phím gõ sẽ là một lượt đọc cả
    /// file. Một megabyte quanh chỗ đang gõ chứa gần như mọi từ mà người ta định dùng lại —
    /// cùng lối với cửa sổ tô màu của ADR-01.
    public static let defaultWindow = 1 << 20

    /// Số gợi ý trả về.
    public static let defaultLimit = 12

    // MARK: - Thu thập từ

    /// Các từ khác nhau trong cửa sổ quanh `offset`.
    ///
    /// "Từ" gồm chữ cái (kể cả chữ có dấu), chữ số và dấu gạch dưới. Chữ có dấu phải tính:
    /// một trình soạn thảo cho người Việt mà không gợi ý được `khach_hàng` thì tính năng này
    /// chỉ dùng được nửa thời gian.
    public static func words(
        in buffer: TextBuffer, around offset: Int, windowBytes: Int = defaultWindow
    ) -> Set<String> {
        guard buffer.count > 0 else { return [] }
        let half = windowBytes / 2
        let lower = max(0, min(offset, buffer.count) - half)
        let upper = min(buffer.count, lower + windowBytes)
        guard lower < upper else { return [] }

        let text = String(decoding: buffer.bytes(in: lower ..< upper), as: UTF8.self)
        var out: Set<String> = []
        var current = ""
        for character in text {
            if isWordCharacter(character) {
                current.append(character)
            } else if !current.isEmpty {
                if current.count >= 2 { out.insert(current) }
                current = ""
            }
        }
        if current.count >= 2 { out.insert(current) }
        return out
    }

    public static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// Từ đang gõ dở ngay trước `offset`.
    public static func prefix(in buffer: TextBuffer, before offset: Int) -> String {
        guard offset > 0, buffer.count > 0 else { return "" }
        let lower = max(0, offset - 256)
        let text = String(decoding: buffer.bytes(in: lower ..< min(offset, buffer.count)), as: UTF8.self)
        var out = ""
        for character in text.reversed() {
            guard isWordCharacter(character) else { break }
            out.append(character)
        }
        return String(out.reversed())
    }

    // MARK: - Khớp mờ

    /// Điểm khớp mờ, hoặc `nil` nếu không khớp.
    ///
    /// Luật: mọi ký tự của truy vấn phải xuất hiện trong ứng viên, ĐÚNG THỨ TỰ nhưng không cần
    /// liền nhau — gõ `khh` ra `khach_hang`. Điểm thưởng cho:
    ///
    ///  - khớp liên tiếp (gõ `khach` khớp `khach_hang` mạnh hơn `k_h_a_c_h`),
    ///  - khớp ngay ĐẦU TỪ hoặc sau `_`/chữ hoa (`kh` khớp đầu `khach_hang` và đầu `hang`),
    ///  - ứng viên NGẮN (gõ `ten` thì `ten` phải trên `ten_khach_hang_day_du`).
    ///
    /// Không phân biệt hoa thường và không phân biệt dấu, cùng luật với ô lọc CSV và Function
    /// List — người dùng không nên phải nhớ ba cách tìm khác nhau trong một ứng dụng.
    public static func score(_ candidate: String, query: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let foldedCandidate = Array(CSVFilter.fold(candidate))
        let foldedQuery = Array(CSVFilter.fold(query))
        guard foldedQuery.count <= foldedCandidate.count else { return nil }

        var score = 0
        var candidateIndex = 0
        var previousMatch = -2

        for needle in foldedQuery {
            var found = false
            while candidateIndex < foldedCandidate.count {
                defer { candidateIndex += 1 }
                guard foldedCandidate[candidateIndex] == needle else { continue }

                score += 1
                if candidateIndex == previousMatch + 1 { score += 4 }
                if candidateIndex == 0 { score += 8 }
                else if isBoundary(foldedCandidate, at: candidateIndex, original: candidate) {
                    score += 4
                }
                previousMatch = candidateIndex
                found = true
                break
            }
            guard found else { return nil }
        }

        // Ứng viên càng dài thì mỗi ký tự thừa càng làm nó xa ý định của người gõ.
        score -= max(0, foldedCandidate.count - foldedQuery.count) / 2
        return score
    }

    /// Vị trí này có phải đầu một "từ con" không (sau `_`, sau chữ số, hoặc chỗ chuyển sang HOA).
    private static func isBoundary(
        _ folded: [Character], at index: Int, original: String
    ) -> Bool {
        guard index > 0 else { return true }
        if folded[index - 1] == "_" { return true }
        // Ranh giới camelCase phải đọc trên chuỗi GỐC: bản đã hạ hoa thường không còn chữ hoa
        // nào để mà nhận ra.
        let characters = Array(original)
        guard index < characters.count else { return false }
        return characters[index].isUppercase && !characters[index - 1].isUppercase
    }

    // MARK: - Gợi ý

    /// Dựng danh sách gợi ý cho từ đang gõ dở.
    ///
    /// - Parameters:
    ///   - symbols: tên hàm/lớp từ Function List; chúng được ưu tiên hơn từ thường vì đó là
    ///     thứ người dùng thật sự cần gõ đúng chính tả.
    ///   - minimumPrefix: dưới ngưỡng này thì KHÔNG gợi ý gì.
    public static func suggestions(
        prefix query: String,
        in buffer: TextBuffer,
        around offset: Int,
        symbols: [String] = [],
        minimumPrefix: Int = defaultMinimumPrefix,
        limit: Int = defaultLimit,
        windowBytes: Int = defaultWindow
    ) -> [CompletionCandidate] {
        guard query.count >= minimumPrefix else { return [] }

        var seen: Set<String> = [query]
        var out: [CompletionCandidate] = []

        for symbol in symbols where !seen.contains(symbol) {
            guard let score = score(symbol, query: query) else { continue }
            seen.insert(symbol)
            // Ký hiệu được cộng điểm: gõ đúng tên một hàm quan trọng hơn gõ đúng một từ trong
            // chú thích, và người dùng sẽ thấy nó ngay dòng đầu.
            out.append(CompletionCandidate(word: symbol, source: .symbol, score: score + 10))
        }

        for word in words(in: buffer, around: offset, windowBytes: windowBytes)
        where !seen.contains(word) {
            guard let score = score(word, query: query) else { continue }
            seen.insert(word)
            out.append(CompletionCandidate(word: word, source: .document, score: score))
        }

        // Điểm bằng nhau thì xếp theo bảng chữ cái, để danh sách không nhảy chỗ giữa hai lần
        // gõ giống nhau — một danh sách tự đảo thứ tự là danh sách không ai dám bấm nhanh.
        return Array(
            out.sorted {
                $0.score != $1.score
                    ? $0.score > $1.score
                    : $0.word.localizedStandardCompare($1.word) == .orderedAscending
            }
            .prefix(limit)
        )
    }
}
