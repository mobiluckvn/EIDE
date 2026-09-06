import Foundation

/// Tham số `:tên` trong câu truy vấn — FR-QRY-001.
///
/// Đặc tả: *"tham số hóa (`:param`) với ô nhập khi chạy"*. Người dùng viết một câu một lần rồi
/// chạy nó hằng tháng với `:thang` khác nhau, thay vì sửa tay giữa câu SQL và gõ nhầm.
///
/// ## Ba chỗ `:` KHÔNG phải tham số, và cả ba đều xuất hiện trong SQL thật
///
/// 1. **Toán tử ép kiểu `::`** của DuckDB/Postgres — `doanh_thu::INTEGER`. Bắt nhầm nó thành
///    tham số tên `:INTEGER` là biến một câu chạy được thành một hộp thoại hỏi giá trị.
/// 2. **Bên trong chuỗi** — `WHERE ghi_chu = 'giờ: 10'`. Dấu hai chấm ở đó là dữ liệu.
/// 3. **Bên trong tên có nháy kép** — `"cột: lạ"`. Tên cột trong CSV của người dùng có đủ thứ.
///
/// Cả ba đều là lỗi im lặng nếu làm sai: câu vẫn chạy, chỉ chạy trên một câu SQL khác.
public enum QueryParameters {

    /// Tên các tham số, theo THỨ TỰ xuất hiện, không lặp.
    ///
    /// Thứ tự xuất hiện chứ không phải thứ tự bảng chữ cái: ô nhập hiện ra theo đúng thứ tự
    /// người dùng đọc câu truy vấn của mình.
    public static func names(in sql: String) -> [String] {
        var found: [String] = []
        var seen: Set<String> = []
        for (name, _) in scan(sql) where !seen.contains(name) {
            seen.insert(name)
            found.append(name)
        }
        return found
    }

    /// Thay mọi `:tên` bằng giá trị, đã bọc thành LITERAL SQL.
    ///
    /// Bọc chứ không ghép thẳng: giá trị đến từ một ô nhập, và một dấu nháy trong đó sẽ phá vỡ
    /// câu truy vấn — hoặc đổi nó thành câu khác. Người dùng gõ `O'Brien` vào ô "khách hàng"
    /// không phải đang tấn công ai, nhưng hậu quả thì giống hệt.
    ///
    /// Số và `NULL` đi qua nguyên dạng: `:thang` nhận `2026-08` là chuỗi, nhận `12` là số, và
    /// người dùng không phải nghĩ về chuyện ấy.
    public static func substitute(_ sql: String, values: [String: String]) -> String {
        let hits = scan(sql)
        guard !hits.isEmpty else { return sql }
        var result = ""
        var index = sql.startIndex
        for (name, range) in hits {
            result += sql[index ..< range.lowerBound]
            result += literal(values[name])
            index = range.upperBound
        }
        result += sql[index...]
        return result
    }

    /// Tham số có tên trong câu nhưng chưa có giá trị.
    public static func missing(in sql: String, values: [String: String]) -> [String] {
        names(in: sql).filter { (values[$0] ?? "").isEmpty }
    }

    // MARK: - Bên trong

    static func literal(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "NULL" }
        // Số đi qua nguyên dạng. Bọc một số thành chuỗi thì `:nam > 2020` so chữ với số và
        // DuckDB sẽ báo lỗi đổi kiểu — đúng loại lỗi người dùng không hiểu vì sao.
        if Double(value) != nil { return value }
        return "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }

    /// Mọi vị trí `:tên` thật sự là tham số.
    private static func scan(_ sql: String) -> [(String, Range<String.Index>)] {
        var hits: [(String, Range<String.Index>)] = []
        var index = sql.startIndex
        var quote: Character?

        while index < sql.endIndex {
            let character = sql[index]

            if let open = quote {
                // Trong chuỗi hoặc trong tên có nháy: mọi thứ là dữ liệu cho tới dấu đóng.
                // SQL nhân đôi dấu nháy để thoát (`'O''Brien'`), và cách xử lý ấy tự đúng ở
                // đây: dấu đóng rồi dấu mở lại ngay, và phần giữa vẫn nằm ngoài.
                if character == open { quote = nil }
                index = sql.index(after: index)
                continue
            }

            if character == "'" || character == "\"" {
                quote = character
                index = sql.index(after: index)
                continue
            }

            if character == ":" {
                let next = sql.index(after: index)
                // `::` là ép kiểu, không phải tham số. Nhảy qua CẢ HAI dấu — nhảy một dấu thì
                // dấu thứ hai lại được xét và `x::INT` thành tham số `:INT`.
                if next < sql.endIndex, sql[next] == ":" {
                    index = sql.index(after: next)
                    continue
                }
                var end = next
                while end < sql.endIndex, sql[end].isLetter || sql[end].isNumber
                    || sql[end] == "_" {
                    end = sql.index(after: end)
                }
                if end > next {
                    hits.append((String(sql[next ..< end]), index ..< end))
                    index = end
                    continue
                }
            }
            index = sql.index(after: index)
        }
        return hits
    }
}
