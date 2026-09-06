import Foundation

/// Một điều kiện lọc trên MỘT cột (FR-QRY-002).
///
/// Cú pháp gõ thẳng vào ô lọc dưới tiêu đề cột, không cần biết SQL — đó là điểm của cả yêu
/// cầu này. Người dùng văn phòng gõ `>100`, `Hà Nội`, `a|b|c` và được đúng thứ họ nghĩ.
public struct CSVFilterCondition: Equatable, Sendable {

    public enum Test: Equatable, Sendable {
        /// Chứa chuỗi (không phân biệt hoa thường, không phân biệt dấu tiếng Việt).
        case contains(String)
        case equals(String)
        case notEquals(String)
        /// So SỐ. Ô không đọc được thành số thì không khớp — và không phải lỗi.
        case greater(Double)
        case greaterOrEqual(Double)
        case less(Double)
        case lessOrEqual(Double)
        case between(Double, Double)
        /// Một trong các giá trị, ngăn bằng `|`.
        case inList([String])
        case isNull
        case isNotNull
    }

    public var column: Int
    public var test: Test
    /// Đúng chuỗi người dùng đã gõ — để hiện lại trong ô và để ghi vào báo cáo.
    public var text: String

    public init(column: Int, test: Test, text: String) {
        self.column = column
        self.test = test
        self.text = text
    }
}

/// Lọc hiển thị theo cột (FR-QRY-002).
///
/// **Chỉ ảnh hưởng HIỂN THỊ.** Không hàm nào ở đây sinh ra một `TextEdit`; lọc là cách nhìn,
/// không phải cách sửa. Đó là bất biến NFR-QRY-03, và nó là lý do người dùng dám gõ thử.
public enum CSVFilter {

    /// Đọc chuỗi người dùng gõ thành điều kiện.
    ///
    /// Cú pháp, theo thứ tự thử:
    /// - `null` / `!null` — ô thiếu / có dữ liệu
    /// - `>100` `>=100` `<100` `<=100` — so số
    /// - `100..200` — khoảng, hai đầu đều tính
    /// - `=Huế` — bằng đúng chuỗi ấy
    /// - `!=Huế` — khác
    /// - `a|b|c` — một trong các giá trị
    /// - còn lại — CHỨA chuỗi ấy
    ///
    /// Mặc định là "chứa" chứ không phải "bằng": người ta gõ vào ô lọc để TÌM, và gõ "Hà" mà
    /// không ra "Hà Nội" thì ô lọc trông như hỏng.
    ///
    /// Chuỗi rỗng hoặc toàn khoảng trắng cho ra `nil` — không có điều kiện nào, cột ấy không lọc.
    public static func parse(_ raw: String, column: Int) -> CSVFilterCondition? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        func condition(_ test: CSVFilterCondition.Test) -> CSVFilterCondition {
            CSVFilterCondition(column: column, test: test, text: raw)
        }

        let lower = text.lowercased()
        if lower == "null" || lower == "trống" { return condition(.isNull) }
        if lower == "!null" || lower == "!trống" { return condition(.isNotNull) }

        for (prefix, make) in [
            (">=", { CSVFilterCondition.Test.greaterOrEqual($0) }),
            ("<=", { CSVFilterCondition.Test.lessOrEqual($0) }),
            (">", { CSVFilterCondition.Test.greater($0) }),
            ("<", { CSVFilterCondition.Test.less($0) }),
        ] where text.hasPrefix(prefix) {
            let rest = String(text.dropFirst(prefix.count))
            guard let value = number(rest) else { return condition(.contains(text)) }
            return condition(make(value))
        }

        // Khoảng: "100..200". Kiểm TRƯỚC dấu "=" vì "1..2" không chứa "=" nhưng chứa dấu chấm.
        if let range = text.range(of: ".."),
           let low = number(String(text[text.startIndex ..< range.lowerBound])),
           let high = number(String(text[range.upperBound...])) {
            return condition(.between(Swift.min(low, high), Swift.max(low, high)))
        }

        if text.hasPrefix("!=") { return condition(.notEquals(String(text.dropFirst(2)))) }
        if text.hasPrefix("=") { return condition(.equals(String(text.dropFirst()))) }

        if text.contains("|") {
            let items = text.split(separator: "|", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if items.count > 1 { return condition(.inList(items)) }
        }

        return condition(.contains(text))
    }

    /// Đọc một số theo đúng luật của `CSVClean.readNumber` — cả kiểu Việt/Âu lẫn Anh-Mỹ.
    ///
    /// Đi qua chính hàm ấy để ô lọc và phần còn lại của ứng dụng không bất đồng về "cái gì là
    /// số": ô `1.234,56` trong cột tiền kiểu Việt được đọc là một nghìn hai trăm ba tư phẩy
    /// năm sáu ở cả hai nơi.
    ///
    /// Hệ quả cần biết khi GÕ vào ô lọc: `>1.000` là "hơn một phẩy không", không phải "hơn một
    /// nghìn" — vì `1.000` đứng một mình đọc được cả hai cách, và cách đọc mơ hồ ấy được chốt
    /// theo quy ước Anh-Mỹ ở mọi nơi trong ứng dụng. Muốn một nghìn thì gõ `>1000`, và đó cũng
    /// là cách người ta gõ tự nhiên vào một ô lọc.
    static func number(_ text: String) -> Double? {
        let bytes = Array(text.trimmingCharacters(in: .whitespaces).utf8)
        guard !bytes.isEmpty else { return nil }
        return bytes.withUnsafeBufferPointer { CSVClean.numericValue(of: $0) }
    }

    // MARK: - Khớp một ô

    public static func matches(
        _ value: String, _ test: CSVFilterCondition.Test, spec: CSVNullSpec = .default
    ) -> Bool {
        switch test {
        case let .contains(needle):
            return fold(value).contains(fold(needle))
        case let .equals(other):
            return fold(value) == fold(other)
        case let .notEquals(other):
            return fold(value) != fold(other)
        case let .inList(items):
            let folded = fold(value)
            return items.contains { fold($0) == folded }
        case .isNull:
            return spec.isNull(value)
        case .isNotNull:
            return !spec.isNull(value)
        case let .greater(bound):
            return number(value).map { $0 > bound } ?? false
        case let .greaterOrEqual(bound):
            return number(value).map { $0 >= bound } ?? false
        case let .less(bound):
            return number(value).map { $0 < bound } ?? false
        case let .lessOrEqual(bound):
            return number(value).map { $0 <= bound } ?? false
        case let .between(low, high):
            return number(value).map { $0 >= low && $0 <= high } ?? false
        }
    }

    /// Chuẩn hóa để so sánh: bỏ hoa thường VÀ bỏ dấu tiếng Việt.
    ///
    /// Bỏ dấu vì người dùng gõ ô lọc bằng bàn phím đang ở chế độ nào cũng được: gõ "hue" phải
    /// ra "Huế". Đây là ô TÌM KIẾM chứ không phải một phép so bằng chính xác — ai cần chính
    /// xác thì có `=Huế`, và bản `=` cũng bỏ dấu, vì một ô lọc phân biệt dấu sẽ làm người dùng
    /// tưởng dữ liệu không có ở đó.
    ///
    /// Phép chuẩn hoá — kể cả khoản `Đ` phải thay tay và cửa nhanh ASCII — nay ở `TextFold`,
    /// vì tính năng thứ năm cần nó (tìm trong trang trợ giúp) là đúng lúc dừng nhân bản.
    /// Hàm này giữ lại làm tên gọi quen thuộc trong vòng lặp nóng của phép lọc.
    @inline(__always)
    static func fold(_ value: String) -> String {
        TextFold.fold(value)
    }

    // MARK: - Điều kiện đã biên dịch

    /// Điều kiện đã chuẩn bị sẵn cho vòng lặp nóng.
    ///
    /// Chuỗi cần tìm được bỏ dấu MỘT lần ở đây thay vì một lần cho mỗi ô. Đo trên bảng một
    /// triệu hàng: chỉ riêng việc bỏ dấu chuỗi cần tìm ở trong vòng lặp đã chiếm phần lớn
    /// 3,7 giây của phép lọc chữ.
    struct Compiled {
        let column: Int
        let test: CSVFilterCondition.Test
        /// Bản đã bỏ dấu của chuỗi cần tìm; rỗng với phép so số và phép kiểm ô thiếu.
        let folded: [String]
        /// Bản BYTE của `folded`, chỉ có khi mọi chuỗi cần tìm đều thuần ASCII sau khi bỏ dấu.
        ///
        /// Phần lớn chuỗi cần tìm rơi vào đây, kể cả chuỗi gõ có dấu: bỏ dấu "Đà" ra "da".
        /// Có nó thì ô dữ liệu thuần ASCII so được thẳng trên byte, khỏi dựng `String` nào.
        let foldedBytes: [[UInt8]]?
    }

    static func compile(_ conditions: [CSVFilterCondition]) -> [Compiled] {
        conditions.map { condition in
            let folded: [String]
            switch condition.test {
            case let .contains(text), let .equals(text), let .notEquals(text):
                folded = [fold(text)]
            case let .inList(items):
                folded = items.map(fold)
            default:
                folded = []
            }
            let bytes = folded.map { Array($0.utf8) }
            let asciiOnly = bytes.allSatisfy { $0.allSatisfy { $0 < 0x80 } }
            return Compiled(
                column: condition.column, test: condition.test, folded: folded,
                foldedBytes: asciiOnly ? bytes : nil)
        }
    }

    /// Một ô đã chuẩn bị sẵn: bản nguyên văn và bản đã bỏ dấu.
    ///
    /// Tách ra để bỏ dấu MỘT lần cho mỗi GIÁ TRỊ thay vì một lần cho mỗi HÀNG — xem
    /// `foldCacheLimit`. Phép so số và phép kiểm ô thiếu dùng bản nguyên văn, nên phải giữ cả
    /// hai chứ không chỉ giữ bản đã bỏ dấu.
    struct Cell {
        let text: String
        let folded: String
    }

    static func matches(_ cell: Cell, _ compiled: Compiled, spec: CSVNullSpec) -> Bool {
        switch compiled.test {
        case .contains:
            return cell.folded.contains(compiled.folded[0])
        case .equals:
            return cell.folded == compiled.folded[0]
        case .notEquals:
            return cell.folded != compiled.folded[0]
        case .inList:
            return compiled.folded.contains(cell.folded)
        default:
            return matches(cell.text, compiled.test, spec: spec)
        }
    }

    /// Trần cho bảng nhớ tạm phép bỏ dấu.
    ///
    /// **Vì sao có bảng này.** Bỏ dấu một chuỗi có dấu là một lượt gọi vào ICU, và nó chiếm gần
    /// hết thời gian lọc theo cột chữ: đo trên một triệu hàng, lọc cột `thanh_pho` tốn 2757 ms
    /// trong khi sàn quét CSV chỉ 556 ms. Cột người ta đem ra lọc lại thường ÍT giá trị phân
    /// biệt — tên thành phố, trạng thái, phân loại — nên một triệu lượt gọi ICU thật ra chỉ hỏi
    /// đi hỏi lại vài câu.
    ///
    /// **Vì sao có TRẦN.** Cột mã khách hàng thì mỗi hàng một giá trị, và khi ấy bảng nhớ tạm
    /// phình bằng chính bảng dữ liệu mà không giúp gì. Chạm trần thì thôi ghi thêm — vẫn đúng,
    /// chỉ là hết nhanh.
    static let foldCacheLimit = 8192

    static func matches(_ value: String, _ compiled: Compiled, spec: CSVNullSpec) -> Bool {
        switch compiled.test {
        case .contains:
            return fold(value).contains(compiled.folded[0])
        case .equals:
            return fold(value) == compiled.folded[0]
        case .notEquals:
            return fold(value) != compiled.folded[0]
        case .inList:
            let folded = fold(value)
            return compiled.folded.contains(folded)
        default:
            return matches(value, compiled.test, spec: spec)
        }
    }

    // MARK: - Khớp trên BYTE, không dựng String

    /// Khớp một ô mà KHÔNG dựng `String` nào — chỉ dùng được khi cả ô lẫn chuỗi cần tìm đều
    /// thuần ASCII sau khi bỏ dấu. Trả `nil` nghĩa là "không đi đường này được".
    ///
    /// **Vì sao đáng có hai đường.** Đường `String` cho mỗi hàng: một mảng byte, một `String`,
    /// một lượt duyệt `allSatisfy { $0.isASCII }`, rồi một `lowercased()`. Bốn lần cấp phát và
    /// hai lượt đi hết chuỗi, nhân với một triệu hàng. Với ô ASCII thì bỏ dấu chính là hạ hoa
    /// thường ASCII, tức `byte | 0x20` — làm thẳng trên byte cho ra ĐÚNG cùng kết quả.
    ///
    /// Ô có dấu tiếng Việt thì vẫn phải đi đường `String`: bỏ dấu Unicode là việc của ICU, và
    /// tự viết lại nó ở đây là cách chắc chắn để "Đà Nẵng" thôi khớp với "da nang".
    static func matchesASCII(
        _ cell: ArraySlice<UInt8>, _ compiled: Compiled
    ) -> Bool? {
        guard let needles = compiled.foldedBytes else { return nil }
        for byte in cell where byte >= 0x80 { return nil }

        switch compiled.test {
        case .contains:
            return containsASCII(cell, needles[0])
        case .equals:
            return equalsASCII(cell, needles[0])
        case .notEquals:
            return !equalsASCII(cell, needles[0])
        case .inList:
            return needles.contains { equalsASCII(cell, $0) }

        // Phép so SỐ cũng không cần `String`: `CSVClean.numericValue` vốn đã nhận byte thô,
        // còn đường cũ thì dựng `String`, cắt khoảng trắng, rồi lại đổi ngược về byte.
        case let .greater(bound):
            return numberASCII(cell).map { $0 > bound } ?? false
        case let .greaterOrEqual(bound):
            return numberASCII(cell).map { $0 >= bound } ?? false
        case let .less(bound):
            return numberASCII(cell).map { $0 < bound } ?? false
        case let .lessOrEqual(bound):
            return numberASCII(cell).map { $0 <= bound } ?? false
        case let .between(low, high):
            return numberASCII(cell).map { $0 >= low && $0 <= high } ?? false

        // Ô thiếu vẫn đi đường `String`: `CSVNullSpec` cho người dùng khai những chuỗi được coi
        // là rỗng ("N/A", "-", "null"…), và so danh sách ấy trên byte là chép lại luật ở chỗ
        // thứ hai — chỗ nào lệch thì lệch âm thầm.
        default:
            return nil
        }
    }

    /// Đọc số từ byte thô, sau khi bỏ khoảng trắng hai đầu.
    private static func numberASCII(_ cell: ArraySlice<UInt8>) -> Double? {
        var start = cell.startIndex
        var end = cell.endIndex
        while start < end, cell[start] == 0x20 || cell[start] == 0x09 { start += 1 }
        while end > start, cell[end - 1] == 0x20 || cell[end - 1] == 0x09 { end -= 1 }
        guard start < end else { return nil }
        return Array(cell[start ..< end]).withUnsafeBufferPointer {
            CSVClean.numericValue(of: $0)
        }
    }

    /// Hạ hoa thường theo luật ASCII — đúng thứ `String.lowercased()` làm với chuỗi ASCII.
    @inline(__always)
    private static func lowerASCII(_ byte: UInt8) -> UInt8 {
        byte >= 0x41 && byte <= 0x5A ? byte | 0x20 : byte
    }

    @inline(__always)
    private static func equalsASCII(_ cell: ArraySlice<UInt8>, _ needle: [UInt8]) -> Bool {
        guard cell.count == needle.count else { return false }
        var index = cell.startIndex
        for expected in needle {
            if lowerASCII(cell[index]) != expected { return false }
            index += 1
        }
        return true
    }

    private static func containsASCII(_ cell: ArraySlice<UInt8>, _ needle: [UInt8]) -> Bool {
        guard !needle.isEmpty else { return true }
        guard cell.count >= needle.count else { return false }
        let last = cell.endIndex - needle.count
        var start = cell.startIndex
        while start <= last {
            var index = start
            var matched = true
            for expected in needle {
                if lowerASCII(cell[index]) != expected { matched = false; break }
                index += 1
            }
            if matched { return true }
            start += 1
        }
        return false
    }

    // MARK: - Lọc cả bảng

    public struct Result: Equatable {
        /// Số hàng LOGIC trong file, theo đúng thứ tự file.
        public let rows: [Int]
        /// Tổng số hàng dữ liệu đã xét.
        public let total: Int
        /// Dừng sớm vì bị hủy — con số ở trên chỉ là phần đã xét.
        public let cancelled: Bool
        /// Dừng vì đã đủ lô đầu: còn hàng khớp phía sau chưa tìm tới.
        public let partial: Bool

        public var summary: String {
            if cancelled { return "\(rows.count) dòng khớp (đã dừng giữa chừng)" }
            if partial { return "\(rows.count)+ dòng khớp — đang tìm tiếp…" }
            return "\(rows.count) / \(total) dòng khớp"
        }
    }

    /// Số hàng khớp đủ để lấp đầy màn hình đầu tiên.
    ///
    /// Bảng chỉ vẽ chừng bốn chục hàng cùng lúc; tìm được ngần ấy là đã có thứ để hiện ra.
    public static let firstScreen = 60

    /// Tìm các hàng khớp MỌI điều kiện (AND).
    ///
    /// AND chứ không phải OR, và không có dấu ngoặc: mỗi ô lọc thu hẹp thêm tập kết quả, đúng
    /// như bộ lọc của bảng tính mà người dùng đã quen. Ai cần biểu thức phức tạp hơn thì đó là
    /// việc của Query Workbench (FR-QRY-001), không phải của một hàng ô dưới tiêu đề.
    /// - Parameter prefix: dừng sau khi tìm đủ bấy nhiêu hàng khớp; 0 = quét hết.
    ///
    ///   Có tham số này vì một sự thật đo được: chỉ riêng việc PHÂN TÍCH một bảng 1 triệu hàng
    ///   × 20 cột đã tốn khoảng 0,8 giây, nên "gõ filter phản hồi ≤ 300 ms" (NFR-QRY-01) không
    ///   thể đạt bằng cách quét lại cả file sau mỗi ký tự — với bất kỳ mức tối ưu nào. Thứ đạt
    ///   được, và cũng là thứ người dùng thật sự cảm nhận, là MÀN HÌNH ĐẦU TIÊN có kết quả
    ///   trong ngân sách ấy. Chỗ gọi quét lô đầu để hiện ngay, rồi quét nốt ở nền để biết tổng.
    public static func rows(
        matching conditions: [CSVFilterCondition],
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        prefix: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) -> Result {
        var matched: [Int] = []
        var rowNumber = 0
        var total = 0
        var cancelled = false
        var partial = false
        let compiled = compile(conditions)
        var foldCache: [[UInt8]: Cell] = [:]

        guard !conditions.isEmpty else {
            // Không có điều kiện nào thì không phải quét: mọi hàng đều khớp, và chỗ gọi biết
            // cách hiện cả bảng mà không cần danh sách.
            return Result(rows: [], total: 0, cancelled: false, partial: false)
        }

        do {
            // Đi `forEachWindow`, KHÔNG đi `forEachRow`.
            //
            // `forEachRow` dựng một mảng `CSVField` MỚI cho mỗi hàng chỉ để dời phạm vi sang
            // hệ toạ độ toàn cục (PoC-G đo: 638 ms so với 556 ms trên một triệu hàng). Ở đây
            // còn tệ hơn thế: mỗi ô lại thêm một `buffer.bytes(in:)` nữa. Với `forEachWindow`,
            // byte của ô đã nằm sẵn trong mảng cửa sổ — không cấp phát lần nào.
            try CSVEngine.forEachWindow(
                in: buffer, dialect: dialect, cancelToken: cancelToken
            ) { rows, window, _ in
                for row in rows {
                    defer { rowNumber += 1 }
                    if hasHeader, rowNumber == 0 { continue }
                    total += 1

                    var allMatched = true
                    for condition in compiled {
                        // Hàng ngắn hơn cột đang lọc: ô ấy KHÔNG TỒN TẠI, mà không tồn tại thì
                        // cũng là không có dữ liệu — hệt như ô rỗng.
                        guard condition.column < row.count else {
                            if !matches("", condition, spec: spec) { allMatched = false; break }
                            continue
                        }
                        let raw = window[row[condition.column].range]
                        // Cửa NHANH: ô thuần ASCII và chuỗi cần tìm thuần ASCII thì so thẳng
                        // trên byte. Ô có dấu vẫn đi đường `String` bên dưới.
                        if row[condition.column].isQuoted == false,
                           let verdict = matchesASCII(raw, condition) {
                            if !verdict { allMatched = false; break }
                            continue
                        }
                        let key = Array(raw)
                        let cell: Cell
                        if let cached = foldCache[key] {
                            cell = cached
                        } else {
                            let text = String(
                                decoding: CSVEngine.unescape(key, dialect: dialect), as: UTF8.self)
                            cell = Cell(text: text, folded: fold(text))
                            if foldCache.count < Self.foldCacheLimit { foldCache[key] = cell }
                        }
                        if !matches(cell, condition, spec: spec) { allMatched = false; break }
                    }
                    guard allMatched else { continue }

                    matched.append(rowNumber)
                    if prefix > 0, matched.count >= prefix { partial = true; return false }
                }
                return true
            }
        } catch {
            cancelled = true
        }

        return Result(rows: matched, total: total, cancelled: cancelled, partial: partial)
    }

    /// Dựng lại văn bản CSV chỉ gồm các hàng khớp — để mở thành tab MỚI.
    ///
    /// Giữ nguyên hàng tiêu đề và sao chép nguyên byte thô của từng hàng: kết quả lọc phải là
    /// đúng những dòng ấy của file gốc, không phải một bản dựng lại có thể khác ở cách bọc.
    public static func extract(
        rows matched: [Int],
        from buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        cancelToken: CancelToken = CancelToken()
    ) throws -> String {
        let wanted = Set(matched)
        var out: [UInt8] = []
        var rowNumber = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }
            let keep = (hasHeader && rowNumber == 0) || wanted.contains(rowNumber)
            guard keep, let lower = row.first?.range.lowerBound,
                  let upper = row.last?.range.upperBound else { return true }
            out.append(contentsOf: buffer.bytes(in: lower ..< upper))
            out.append(UInt8(ascii: "\n"))
            return true
        }
        return String(decoding: out, as: UTF8.self)
    }
}
