import Foundation

/// Khai phá văn bản: n-gram và TF-IDF — FR-MIN-006.
///
/// ## Tokenizer dùng chung, không viết bản thứ hai
///
/// Tách token đi qua `BM25Tokenizer` — đúng bộ tách mà truy hồi (FR-KNW-918) dùng. Ghi chú ở đó
/// đã dự đoán chỗ này: *"FR-KNW-918 viết «tokenizer tiếng Việt dùng chung FR-MIN-006»"*.
///
/// Điều đó quan trọng hơn vẻ ngoài của nó: nếu bảng từ khoá tách từ theo một luật và chỉ mục
/// truy hồi tách theo luật khác, thì bấm một từ khoá sẽ tìm ra số kết quả khác với con số vừa
/// hiện trong bảng — và không có gì báo lỗi.
///
/// ## Ghép TỪ GHÉP là tuỳ chọn, và mặc định TẮT
///
/// `BM25Tokenizer` tách theo ÂM TIẾT: «cơ sở dữ liệu» thành bốn token. Đặc tả cho phép nạp từ
/// điển từ ghép của người dùng để gộp chúng lại.
///
/// Mặc định TẮT có chủ ý: bật sẵn nghĩa là con số tần suất đổi theo một từ điển mà người dùng
/// chưa từng thấy, và họ không có cách nào biết vì sao «dữ liệu» đếm được 12 chứ không phải 47.
/// Bật lên là một hành động, và khi bật thì khối "Phương pháp" nói ra từ điển nào đang dùng.
///
/// ## Stopword: có sẵn hai thứ tiếng, nhưng KHÔNG bật sẵn cho n-gram
///
/// Với bảng TỪ KHOÁ thì bỏ stopword là đúng — «của», «the» không phải từ khoá của tài liệu nào.
/// Với n-gram thì SAI: một cụm hai từ như «cơ sở» có nghĩa, và loại «của» đi trước khi ghép sẽ
/// dựng ra những cụm chưa từng xuất hiện trong văn bản («hệ thống dữ liệu» từ «hệ thống của dữ
/// liệu»). Nên n-gram lọc stopword ở HAI ĐẦU cụm, không lọc ở giữa.
public enum TextMining {

    // MARK: - Stopword

    /// Stopword tiếng Việt — hư từ, không mang nội dung.
    public static let vietnameseStopwords: Set<String> = [
        "và", "của", "có", "là", "được", "trong", "cho", "với", "các", "những", "một",
        "này", "đó", "khi", "đã", "sẽ", "cũng", "nếu", "thì", "mà", "nhưng", "hoặc",
        "từ", "đến", "về", "theo", "tại", "bởi", "vì", "nên", "để", "ở", "ra", "vào",
        "lên", "xuống", "rồi", "còn", "chỉ", "cả", "như", "hơn", "rất", "quá", "không",
        "chưa", "đang", "phải", "bị", "do", "trên", "dưới", "sau", "trước", "giữa",
    ]

    /// Stopword tiếng Anh.
    public static let englishStopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "then", "else", "of", "to", "in",
        "on", "at", "by", "for", "with", "from", "as", "is", "are", "was", "were", "be",
        "been", "being", "have", "has", "had", "do", "does", "did", "will", "would",
        "can", "could", "should", "may", "might", "must", "this", "that", "these",
        "those", "it", "its", "not", "no", "so", "than", "too", "very", "all", "any",
    ]

    public static let defaultStopwords = vietnameseStopwords.union(englishStopwords)

    // MARK: - Cấu hình

    public struct Config: Equatable, Sendable {
        /// Bậc n-gram cao nhất; đặc tả đòi 1–3.
        public var maxN: Int
        public var stopwords: Set<String>
        /// Từ điển từ ghép, đã chuẩn hoá về chữ thường. Rỗng = không ghép.
        public var compounds: Set<String>
        /// Số từ khoá giữ lại.
        public var limit: Int

        public init(maxN: Int = 3, stopwords: Set<String> = defaultStopwords,
                    compounds: Set<String> = [], limit: Int = 100) {
            self.maxN = max(1, min(maxN, 3))
            self.stopwords = stopwords
            self.compounds = compounds
            self.limit = limit
        }
    }

    public struct Term: Equatable, Sendable {
        public let text: String
        /// Số âm tiết — 1 là từ đơn, 2–3 là cụm.
        public let n: Int
        /// Số lần xuất hiện trong tài liệu đang xét.
        public let count: Int
        /// Số TÀI LIỆU chứa nó (bằng `1` khi chỉ có một tài liệu).
        public let documentCount: Int
        public let tfidf: Double
    }

    public struct Report: Equatable, Sendable {
        public let terms: [Term]
        public let documentCount: Int
        public let tokenCount: Int
        public let methodology: String
    }

    // MARK: - Chạy

    /// Khai phá MỘT tài liệu. TF-IDF khi ấy suy biến thành tần suất — và nói ra điều đó.
    public static func run(_ text: String, config: Config = Config()) -> Report {
        run(documents: [text], config: config)
    }

    /// Khai phá cả corpus. `documents` là trường `text` của từng bản ghi, hoặc từng tài liệu.
    public static func run(
        documents: [String], config: Config = Config(),
        cancelToken: CancelToken = CancelToken()
    ) -> Report {
        let tokenizer = BM25Tokenizer()
        var tanSuat: [String: Int] = [:]           // cụm → số lần trong CẢ corpus
        var soTaiLieu: [String: Int] = [:]         // cụm → số tài liệu chứa nó
        var bacCua: [String: Int] = [:]
        var tongToken = 0

        for doc in documents {
            if cancelToken.isCancelled { break }
            let tokens = ghepTuGhep(tokenizer.tokens(in: doc), compounds: config.compounds)
            tongToken += tokens.count
            var thayTrongDoc: Set<String> = []

            for n in 1 ... config.maxN {
                guard tokens.count >= n else { break }
                for i in 0 ... (tokens.count - n) {
                    let cum = Array(tokens[i ..< (i + n)])
                    // Lọc stopword ở HAI ĐẦU, không ở giữa: loại chúng trước khi ghép sẽ dựng ra
                    // những cụm chưa từng xuất hiện trong văn bản.
                    guard let dau = cum.first, let cuoi = cum.last,
                          !config.stopwords.contains(dau), !config.stopwords.contains(cuoi)
                    else { continue }
                    let khoa = cum.joined(separator: " ")
                    tanSuat[khoa, default: 0] += 1
                    bacCua[khoa] = n
                    thayTrongDoc.insert(khoa)
                }
            }
            for khoa in thayTrongDoc { soTaiLieu[khoa, default: 0] += 1 }
        }

        let N = max(documents.count, 1)
        var terms: [Term] = tanSuat.map { khoa, dem in
            let df = soTaiLieu[khoa] ?? 1
            // IDF làm mượt (`+1` cả tử lẫn mẫu) để một corpus MỘT tài liệu không cho ra log(1)=0
            // trên mọi từ — khi ấy bảng xếp hạng rỗng nghĩa, và người dùng thấy một cột toàn 0.
            let idf = log(Double(N + 1) / Double(df + 1)) + 1
            return Term(text: khoa, n: bacCua[khoa] ?? 1, count: dem,
                        documentCount: df, tfidf: Double(dem) * idf)
        }
        // Sắp TẤT ĐỊNH: điểm giảm dần, hoà thì theo tần suất, hoà nữa thì theo bảng chữ cái.
        terms.sort {
            $0.tfidf != $1.tfidf ? $0.tfidf > $1.tfidf
                : ($0.count != $1.count ? $0.count > $1.count : $0.text < $1.text)
        }

        return Report(terms: Array(terms.prefix(config.limit)),
                      documentCount: documents.count,
                      tokenCount: tongToken,
                      methodology: methodology(config, documentCount: documents.count))
    }

    /// Gộp âm tiết liền nhau thành từ ghép khi từ điển có cụm ấy. Ưu tiên cụm DÀI hơn.
    ///
    /// Cùng luật "khớp dài nhất thắng" của `EntityMarker`, và cùng lý do: có cả «cơ sở» lẫn «cơ
    /// sở dữ liệu» trong từ điển thì cụm dài phải thắng, nếu không nó bị cắt làm đôi và đếm
    /// thành hai từ.
    static func ghepTuGhep(_ tokens: [String], compounds: Set<String>) -> [String] {
        guard !compounds.isEmpty else { return tokens }
        var out: [String] = []
        var i = 0
        while i < tokens.count {
            var ghep: String?
            var dai = 0
            for n in stride(from: min(4, tokens.count - i), through: 2, by: -1) {
                let cum = tokens[i ..< (i + n)].joined(separator: " ")
                if compounds.contains(cum) { ghep = cum; dai = n; break }
            }
            if let ghep { out.append(ghep); i += dai } else { out.append(tokens[i]); i += 1 }
        }
        return out
    }

    /// NFR-MIN-04: mọi đầu ra kèm khối "Phương pháp".
    static func methodology(_ config: Config, documentCount: Int) -> String {
        var parts = [
            "Tách token bằng `BM25Tokenizer` (\(BM25Tokenizer.name)) — CÙNG bộ tách mà chỉ mục "
                + "truy hồi dùng, nên số kết quả khi bấm một từ khoá khớp với con số trong bảng.",
            "n-gram 1…\(config.maxN); stopword lọc ở HAI ĐẦU cụm, không lọc ở giữa.",
            "TF-IDF = tần suất × (log((N+1)/(df+1)) + 1).",
        ]
        parts.append(config.compounds.isEmpty
            ? "KHÔNG ghép từ ghép: «cơ sở dữ liệu» đếm thành ba âm tiết riêng."
            : "Có ghép từ ghép theo từ điển \(config.compounds.count) mục, ưu tiên cụm dài hơn.")
        if documentCount <= 1 {
            // Nói ra chứ không để người đọc tưởng cột TF-IDF mang thông tin nó không mang.
            parts.append("⚠ Chỉ MỘT tài liệu nên df = 1 với mọi cụm: cột TF-IDF khi ấy chỉ là "
                + "tần suất nhân một hằng số, không phân biệt được từ đặc trưng với từ phổ biến.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Đầu ra

    /// Xuất CSV — đặc tả đòi vế này.
    public static func csv(_ report: Report) -> String {
        var out = "tu_khoa,bac,tan_suat,so_tai_lieu,tfidf\n"
        for t in report.terms {
            out += [t.text, String(t.n), String(t.count), String(t.documentCount),
                    String(format: "%.4f", t.tfidf)]
                .map { CSVEngine.escape($0, dialect: .comma) }
                .joined(separator: ",") + "\n"
        }
        return out
    }

    /// Chuyển kết quả thành danh sách entity cho FR-KNW-908 — đặc tả đòi *"kết quả dùng được làm
    /// đầu vào cho entity marker"*.
    ///
    /// Loại đặt theo BẬC (`1-gram`, `2-gram`, `3-gram`) chứ không đặt "keyword" cho tất: entity
    /// marker tô MÀU THEO LOẠI, nên chia theo bậc cho ra ba màu và người đọc phân biệt được cụm
    /// với từ đơn ngay trên trang.
    public static func entities(_ report: Report) -> [EntityMarker.Entity] {
        report.terms.map { EntityMarker.Entity(text: $0.text, type: "\($0.n)-gram") }
    }
}
