import Foundation

/// Đổi thông báo lỗi tiếng Anh của DuckDB sang tiếng Việt (ADR-14 §3.2 khoản 1).
///
/// Đổi engine sang DuckDB lấy được bảy cú pháp mà engine tự viết từ chối, nhưng mất câu lỗi
/// tiếng Việt gọi đúng tên chỗ sai. Trên một sản phẩm bán cho người gõ tiếng Việt thì đó không
/// phải khoản mất nhỏ: người dùng văn phòng của FR-CSV-407 là người **không biết SQL**, và một
/// câu `Binder Error: Referenced column "x" not found in FROM clause!` không giúp họ sửa gì.
///
/// ## Luật của bộ dịch này
///
/// **Chỗ không nhận ra thì NÓI LÀ KHÔNG NHẬN RA, không đoán.** Cùng luật mà bộ giải thích regex
/// (FR-SRCH-110) đã theo: đoán một câu tiếng Việt nghe xuôi cho một lỗi ta chưa hiểu là dẫn
/// người dùng đi sai đường, và tệ hơn hẳn việc để nguyên tiếng Anh. Lỗi lạ đi qua nguyên văn,
/// có gắn nhãn để người báo lỗi biết đây là chỗ chưa dịch.
///
/// **Giữ nguyên phần CỤ THỂ.** Tên cột, danh sách cột gợi ý, vị trí dòng và dấu mũ đều là thứ
/// người dùng cần — dịch phần khung, giữ nguyên phần dữ liệu.
///
/// **Mẫu lấy từ lỗi THẬT.** Bốn họ dưới đây thu thập bằng cách chạy mười lăm câu sai trên
/// DuckDB 1.5.5 và chép lại nguyên văn, không phải nhớ ra hay suy từ tài liệu.
public enum DuckDBErrorText {

    /// Có dịch được không — để bài kiểm và giao diện phân biệt "đã dịch" với "để nguyên".
    public struct Translation: Equatable, Sendable {
        public var text: String
        /// `false` khi không nhận ra họ lỗi; `text` khi ấy là nguyên văn tiếng Anh.
        public var recognised: Bool
    }

    public static func vietnamese(_ raw: String) -> Translation {
        let (headline, tail) = split(raw)

        // --- Họ 1: cột không tồn tại ------------------------------------------------------
        //
        // "Binder Error: Referenced column "khong_co" not found in FROM clause!"
        // kèm dòng "Candidate bindings: "thanh_pho", "doanh_thu""
        if headline.contains("Referenced column"), let column = quoted(headline) {
            var text = "Không có cột «\(column)» trong bảng."
            if let candidates = value(after: "Candidate bindings:", in: raw) {
                // Danh sách cột CÓ THẬT là thứ quý nhất trong cả thông báo — engine cũ cũng trả
                // đúng danh sách này, và đó là chi tiết duy nhất giúp người không biết SQL sửa
                // được ngay.
                text += " Cột có thật: \(candidates)."
            }
            return .init(text: text + position(tail), recognised: true)
        }

        // --- Họ 2: bảng hoặc hàm không tồn tại --------------------------------------------
        //
        // "Catalog Error: Table with name X does not exist!" + "Did you mean "Y"?"
        if headline.contains("does not exist") {
            let suggestion = value(after: "Did you mean", in: raw)
                .map { " Có phải ý anh là \($0.trimmingCharacters(in: CharacterSet(charactersIn: " ?")))?" }
                ?? ""
            if headline.contains("Table with name"),
               let name = word(after: "Table with name", in: headline) {
                // Bảng của tài liệu đang mở LUÔN tên là `t`. Nói ra, vì đó là câu hỏi đầu tiên
                // của người mới dùng panel này.
                //
                // Và BỎ gợi ý của DuckDB ở đây: catalog trong bộ nhớ chỉ có bảng `t` cùng các
                // bảng hệ thống, nên nó gợi ý những cái tên như "pg_proc" — vừa vô nghĩa với
                // người dùng vừa dẫn họ đi sai hướng. Gợi ý cho HÀM thì giữ, vì DuckDB có hàng
                // trăm hàm thật và gõ nhầm tên hàm là chuyện thường.
                return .init(
                    text: "Không có bảng «\(name)». Bảng của tài liệu đang mở tên là «t»."
                        + position(tail),
                    recognised: true)
            }
            if headline.contains("Function with name"),
               let name = word(after: "Function with name", in: headline) {
                return .init(
                    text: "Không có hàm «\(name)»." + suggestion + position(tail),
                    recognised: true)
            }
        }

        // --- Họ 3: sai cú pháp -------------------------------------------------------------
        //
        // "Parser Error: syntax error at or near "FROM""
        // "syntax error at end of input" — câu cụt. Không có vị trí để chỉ, và đó chính là
        // thông tin: người dùng gõ dở rồi bấm chạy. Nói đúng chuyện ấy thay vì một câu "sai cú
        // pháp" chung chung khiến họ đi soi lại phần đã gõ đúng.
        if headline.contains("syntax error at end of input") {
            return .init(text: "Câu truy vấn bị cụt — thiếu phần sau chỗ vừa gõ.",
                         recognised: true)
        }
        if headline.contains("syntax error at or near") {
            let near = quoted(headline).map { " gần «\($0)»" } ?? ""
            return .init(text: "Câu truy vấn sai cú pháp\(near)." + position(tail),
                         recognised: true)
        }
        if headline.contains("Parser Error") {
            return .init(text: "Câu truy vấn sai cú pháp." + position(tail), recognised: true)
        }

        // --- Họ 4: đổi kiểu không được -----------------------------------------------------
        //
        // "Conversion Error: Could not convert string 'abc' to INT32"
        if headline.contains("Could not convert string") {
            let value = singleQuoted(headline).map { "«\($0)»" } ?? "một giá trị"
            let kind = headline.components(separatedBy: " to ").last.map(vietnameseType) ?? "số"
            return .init(
                text: "Không đổi được \(value) sang \(kind). "
                    + "Cột này có ô không đúng kiểu, hoặc phép so sánh đang so chữ với số."
                    + position(tail),
                recognised: true)
        }

        // --- Không nhận ra --------------------------------------------------------------
        //
        // Để NGUYÊN VĂN và nói rõ là chưa dịch. Một câu tiếng Việt bịa ra cho lỗi ta chưa hiểu
        // sẽ dẫn người dùng đi sai đường, và họ không có cách nào biết là mình bị dẫn sai.
        return .init(text: "Lỗi từ engine truy vấn (chưa có bản dịch): " + raw, recognised: false)
    }

    // MARK: - Mảnh

    /// Tách dòng đầu (câu lỗi) khỏi phần đuôi (LINE … và dấu mũ).
    private static func split(_ raw: String) -> (String, String) {
        let lines = raw.components(separatedBy: "\n")
        let headline = lines.first ?? raw
        let tail = lines.dropFirst().joined(separator: "\n")
        return (headline, tail)
    }

    /// Giữ nguyên khối `LINE n: …` và dấu mũ của DuckDB.
    ///
    /// Không dịch và không dựng lại: nó chỉ ĐÚNG VỊ TRÍ khi giữ nguyên từng ký tự khoảng trắng,
    /// và một mũi tên tự dựng lệch đi vài cột còn tệ hơn không có mũi tên nào.
    private static func position(_ tail: String) -> String {
        // Chỉ giữ TỪ dòng "LINE …" trở đi. Phần trước nó là những dòng tiếng Anh ("Candidate
        // bindings:", "Did you mean …") mà câu tiếng Việt phía trên đã nuốt vào rồi — để lại
        // là in cùng một thông tin hai lần, một lần bằng thứ tiếng người dùng không đọc.
        let lines = tail.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("LINE ") }) else { return "" }
        let block = lines[start...].joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
        return block.isEmpty ? "" : "\n\n" + block
    }

    private static func quoted(_ text: String) -> String? {
        let parts = text.components(separatedBy: "\"")
        return parts.count >= 3 ? parts[1] : nil
    }

    private static func singleQuoted(_ text: String) -> String? {
        let parts = text.components(separatedBy: "'")
        return parts.count >= 3 ? parts[1] : nil
    }

    private static func word(after marker: String, in text: String) -> String? {
        guard let range = text.range(of: marker) else { return nil }
        return text[range.upperBound...]
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
            .first
    }

    private static func value(after marker: String, in text: String) -> String? {
        for line in text.components(separatedBy: "\n") where line.contains(marker) {
            guard let range = line.range(of: marker) else { continue }
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// Tên kiểu của DuckDB, nói bằng tiếng người dùng hiểu.
    ///
    /// "INT32" không nói gì với người làm bảng lương. Cố ý gộp mọi bề rộng số nguyên thành một
    /// chữ "số nguyên": phân biệt 32 với 64 bit là chi tiết của engine, không phải của người
    /// đang sửa một ô dữ liệu.
    private static func vietnameseType(_ raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if name.hasPrefix("INT") || name.hasPrefix("BIGINT") || name.hasPrefix("HUGEINT")
            || name.hasPrefix("SMALLINT") || name.hasPrefix("TINYINT") {
            return "số nguyên"
        }
        if name.hasPrefix("DOUBLE") || name.hasPrefix("FLOAT") || name.hasPrefix("DECIMAL") {
            return "số thập phân"
        }
        if name.hasPrefix("DATE") { return "ngày" }
        if name.hasPrefix("TIMESTAMP") { return "mốc thời gian" }
        if name.hasPrefix("BOOL") { return "giá trị đúng/sai" }
        return "kiểu \(name)"
    }
}
