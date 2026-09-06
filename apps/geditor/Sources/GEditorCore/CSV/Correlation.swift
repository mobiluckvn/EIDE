import Foundation

/// Ma trận tương quan — FR-MIN-005.
///
/// Đặc tả: *"Pearson và Spearman trên mọi cặp cột số; hiển thị ma trận số + heatmap (thang màu
/// phân kỳ, mù màu an toàn); click một ô mở scatter 2 cột kèm đường hồi quy tuyến tính đơn giản
/// + R². Mọi kết quả kèm chú thích cố định: «Tương quan không hàm ý nhân quả» — đúng tinh thần
/// giáo dục của sản phẩm."*
///
/// ## Ba cái bẫy, và cả ba đều im lặng
///
/// **1. Ô trống.** Hai cột hiếm khi thiếu số ở cùng những hàng. Bỏ cả hàng khi bất kỳ cột nào
/// trống (*listwise*) có thể vứt đi phần lớn bảng vì một cột bẩn; tính từng cặp trên những hàng
/// đủ số của riêng cặp ấy (*pairwise*) giữ được nhiều dữ liệu hơn nhưng khiến mỗi ô dựa trên
/// một số hàng KHÁC NHAU. Ở đây chọn **pairwise**, và **`n` của từng ô nằm trong kết quả** —
/// một hệ số 0,93 tính trên 6 hàng không cùng nghĩa với 0,93 tính trên 6.000 hàng, và người đọc
/// phải thấy điều đó chứ không phải đoán.
///
/// **2. Giá trị bằng nhau khi xếp hạng.** Spearman là Pearson trên THỨ HẠNG. Xếp hạng ngây thơ
/// (1, 2, 3, …) cho những giá trị bằng nhau một thứ tự tuỳ tiện, và kết quả đổi theo thứ tự
/// hàng trong file — tức mất tính tất định mà NFR-MIN-02 đòi. Phải dùng **hạng trung bình**.
/// Dữ liệu thật đầy giá trị lặp (trạng thái, mã vùng, số lượng nhỏ), nên đây không phải trường
/// hợp hiếm.
///
/// **3. Cột hằng.** Độ lệch chuẩn 0 → 0/0. Trả `nil` kèm lý do, **không** trả 0: 0 nghĩa là
/// "đã đo, và không có liên hệ nào", còn đây là "không đo được". Hai câu khác hẳn nhau.
public enum Correlation {

    /// Câu bắt buộc đi kèm mọi kết quả.
    ///
    /// Không phải trang trí. Ma trận tương quan là công cụ dễ bị đọc sai nhất trong cả cụm khai
    /// phá: người ta thấy 0,87 giữa `quang_cao` và `doanh_thu` rồi kết luận quảng cáo sinh ra
    /// doanh thu, trong khi cả hai cùng chạy theo mùa vụ. Đặc tả gọi đây là *"tinh thần giáo
    /// dục của sản phẩm"*, và nó được kiểm như một yêu cầu.
    public static let caveat = "Tương quan không hàm ý nhân quả."

    public enum Method: String, CaseIterable, Equatable, Sendable {
        /// Đo quan hệ TUYẾN TÍNH. Nhạy với điểm cực đoan.
        case pearson
        /// Pearson trên hạng — đo quan hệ ĐƠN ĐIỆU. Bền với điểm cực đoan và với quan hệ cong.
        case spearman

        public var vietnamese: String {
            switch self {
            case .pearson: return "Pearson"
            case .spearman: return "Spearman"
            }
        }
    }

    public struct Cell: Equatable, Sendable {
        public var row: Int
        public var column: Int
        /// Hệ số trong [−1, 1]. `nil` khi KHÔNG đo được — xem `note`.
        public var value: Double?
        /// Số hàng đủ số ở CẢ HAI cột. Phải hiện ra cạnh hệ số.
        public var count: Int
        public var note: String?

        public init(
            row: Int, column: Int, value: Double?, count: Int, note: String? = nil
        ) {
            self.row = row
            self.column = column
            self.value = value
            self.count = count
            self.note = note
        }
    }

    public struct Matrix: Equatable, Sendable {
        public var columns: [String]
        public var method: Method
        /// Chỉ NỬA DƯỚI kể cả đường chéo — ma trận đối xứng, lưu cả hai nửa là lưu hai lần cùng
        /// một con số và mở đường cho chúng lệch nhau.
        public var cells: [Cell]

        public init(columns: [String], method: Method, cells: [Cell]) {
            self.columns = columns
            self.method = method
            self.cells = cells
        }

        public func value(_ row: Int, _ column: Int) -> Double? {
            cell(row, column)?.value
        }

        public func cell(_ row: Int, _ column: Int) -> Cell? {
            let (low, high) = row >= column ? (row, column) : (column, row)
            return cells.first { $0.row == low && $0.column == high }
        }

        /// Những cặp mạnh nhất, bỏ đường chéo. Sắp theo |hệ số| giảm dần.
        ///
        /// Với 20 cột thì ma trận có 190 ô — không ai đọc hết. Danh sách này là thứ người dùng
        /// thật sự cần, và nó phải bỏ đường chéo: `r(x, x) = 1` luôn đứng đầu và không nói gì.
        public func strongest(limit: Int = 10) -> [Cell] {
            cells
                .filter { $0.row != $0.column && $0.value != nil }
                .sorted { abs($0.value ?? 0) > abs($1.value ?? 0) }
                .prefix(limit)
                .map { $0 }
        }

        /// Khối "Phương pháp" (NFR-MIN-04).
        public var methodology: String {
            let pairs = cells.filter { $0.row != $0.column }
            let unscored = pairs.filter { $0.value == nil }.count
            var text = """
                Phương pháp: hệ số tương quan \(method.vietnamese) trên \(columns.count) cột số, \
                \(pairs.count) cặp.
                """
            switch method {
            case .pearson:
                text += "\nr = Σ(xᵢ−x̄)(yᵢ−ȳ) / √[Σ(xᵢ−x̄)² · Σ(yᵢ−ȳ)²]. Đo quan hệ TUYẾN TÍNH; "
                    + "một điểm cực đoan kéo được r đi rất xa."
            case .spearman:
                text += "\nρ = Pearson trên THỨ HẠNG, hạng của các giá trị bằng nhau lấy trung "
                    + "bình. Đo quan hệ ĐƠN ĐIỆU; bền với điểm cực đoan và với quan hệ cong."
            }
            text += "\nÔ trống xử lý theo từng cặp (pairwise): mỗi ô dùng những hàng đủ số của "
                + "riêng cặp ấy, nên n khác nhau giữa các ô và n nằm ngay trong bảng."
            if unscored > 0 {
                text += "\n\(unscored) cặp KHÔNG đo được (cột hằng hoặc quá ít hàng) — để trống "
                    + "chứ không ghi 0, vì 0 nghĩa là «đã đo và không có liên hệ»."
            }
            text += "\n\(caveat)"
            return text
        }
    }

    // MARK: - Tính ma trận

    /// - Parameter columns: dữ liệu theo CỘT. `columns[j][i]` là hàng i của cột j.
    public static func matrix(
        _ columns: [[Double]], names: [String], method: Method,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Matrix {
        precondition(columns.count == names.count)
        // Spearman xếp hạng TỪNG CỘT một lần rồi chạy Pearson trên hạng — không xếp lại cho mỗi
        // cặp. Với 20 cột đó là 20 lần sắp thay vì 380.
        //
        // Nhưng có một chi tiết: hạng phải tính trên TOÀN cột, kể cả những hàng mà cột kia
        // trống. Đó là định nghĩa chuẩn của Spearman theo mẫu, và nó khiến hạng KHÔNG phụ
        // thuộc vào việc ta đang ghép cột này với cột nào — nếu không thì `ρ(a,b)` tính từ
        // bảng đầy đủ sẽ khác `ρ(a,b)` tính từ bảng đã lọc, mà hai cái phải như nhau.
        let prepared: [[Double]]
        switch method {
        case .pearson: prepared = columns
        case .spearman: prepared = columns.map(averageRanks)
        }

        var cells: [Cell] = []
        for i in 0..<columns.count {
            for j in 0...i {
                try cancelToken.check()
                cells.append(pair(prepared[i], prepared[j], row: i, column: j))
            }
        }
        return Matrix(columns: names, method: method, cells: cells)
    }

    private static func pair(_ xs: [Double], _ ys: [Double], row: Int, column: Int) -> Cell {
        var xClean: [Double] = []
        var yClean: [Double] = []
        for index in 0..<min(xs.count, ys.count) where xs[index].isFinite && ys[index].isFinite {
            xClean.append(xs[index])
            yClean.append(ys[index])
        }
        guard xClean.count >= 3 else {
            return Cell(
                row: row, column: column, value: nil, count: xClean.count,
                note: "chỉ \(xClean.count) hàng đủ số ở cả hai cột — cần ít nhất 3")
        }
        guard let r = pearson(xClean, yClean) else {
            return Cell(
                row: row, column: column, value: nil, count: xClean.count,
                note: "một trong hai cột chỉ có MỘT giá trị trên phần chung — không có gì để "
                    + "so, và 0 sẽ bị đọc nhầm thành «không liên hệ»")
        }
        return Cell(row: row, column: column, value: r, count: xClean.count)
    }

    /// Pearson trên hai dãy đã khớp và đã sạch. `nil` khi một dãy là hằng.
    public static func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 2 else { return nil }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for index in 0..<xs.count {
            let dx = xs[index] - meanX
            let dy = ys[index] - meanY
            sxy += dx * dy
            sxx += dx * dx
            syy += dy * dy
        }
        guard sxx > 0, syy > 0 else { return nil }
        // Kẹp về [−1, 1]: về toán thì bất đẳng thức Cauchy–Schwarz bảo đảm điều đó, nhưng phép
        // chia dấu phẩy động có thể cho ra 1,0000000000000002, và một bảng in "r = 1,00" cạnh
        // một ô "r = 1,00" mà thang màu lại vẽ khác nhau là thứ không giải thích được.
        return min(1, max(-1, sxy / (sxx * syy).squareRoot()))
    }

    /// Hạng trung bình cho các giá trị bằng nhau. Ô trống giữ nguyên là `nan`.
    ///
    /// Ví dụ `[10, 20, 20, 30]` → `[1, 2.5, 2.5, 4]`. Nếu xếp `[1, 2, 3, 4]` thì kết quả phụ
    /// thuộc vào việc hàng nào đứng trước trong file, và cùng một bảng đã sắp lại sẽ cho ρ khác.
    public static func averageRanks(_ values: [Double]) -> [Double] {
        let indexed = values.enumerated()
            .filter { $0.element.isFinite }
            .sorted { $0.element < $1.element }
        var ranks = [Double](repeating: .nan, count: values.count)
        var position = 0
        while position < indexed.count {
            var end = position
            while end + 1 < indexed.count, indexed[end + 1].element == indexed[position].element {
                end += 1
            }
            // Hạng 1-based, trung bình của khối bằng nhau.
            let average = Double(position + end + 2) / 2
            for k in position...end { ranks[indexed[k].offset] = average }
            position = end + 1
        }
        return ranks
    }

    // MARK: - Hồi quy tuyến tính đơn giản (cho scatter)

    public struct Fit: Equatable, Sendable {
        public var slope: Double
        public var intercept: Double
        /// Hệ số xác định. Với hồi quy tuyến tính ĐƠN, `r2 == r²` — xem `testR2BangBinhPhuongR`.
        public var r2: Double
        public var count: Int

        public init(slope: Double, intercept: Double, r2: Double, count: Int) {
            self.slope = slope
            self.intercept = intercept
            self.r2 = r2
            self.count = count
        }

        /// Phương trình đường thẳng, để in cạnh biểu đồ.
        public func equation(x: String, y: String) -> String {
            let sign = intercept < 0 ? "−" : "+"
            return "\(y) = \(ChartRender.number(slope)) × \(x) "
                + "\(sign) \(ChartRender.number(abs(intercept)))"
        }
    }

    /// Bình phương tối thiểu trên hai cột. `nil` khi x là hằng (đường thẳng đứng, không có hệ số góc).
    public static func fit(x xs: [Double], y ys: [Double]) -> Fit? {
        var xClean: [Double] = []
        var yClean: [Double] = []
        for index in 0..<min(xs.count, ys.count) where xs[index].isFinite && ys[index].isFinite {
            xClean.append(xs[index])
            yClean.append(ys[index])
        }
        guard xClean.count >= 2 else { return nil }
        let n = Double(xClean.count)
        let meanX = xClean.reduce(0, +) / n
        let meanY = yClean.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for index in 0..<xClean.count {
            let dx = xClean[index] - meanX
            let dy = yClean[index] - meanY
            sxy += dx * dy
            sxx += dx * dx
            syy += dy * dy
        }
        guard sxx > 0 else { return nil }
        let slope = sxy / sxx
        // `syy == 0` nghĩa là y là hằng: đường khớp là đường ngang và khớp HOÀN HẢO, nhưng R²
        // theo công thức là 0/0. Quy ước ở đây là 0 — "mô hình không giải thích được gì về
        // biến thiên của y", đúng vì y không hề biến thiên.
        let r2 = syy > 0 ? min(1, max(0, sxy * sxy / (sxx * syy))) : 0
        return Fit(
            slope: slope, intercept: meanY - slope * meanX, r2: r2, count: xClean.count)
    }
}

// MARK: - Thang màu heatmap

extension Correlation {

    /// Màu của một ô heatmap, dạng `#RRGGBB`.
    ///
    /// ## "Mù màu an toàn" loại bỏ lựa chọn hiển nhiên
    ///
    /// Thang đỏ–lục là thang mặc định của gần như mọi công cụ, và là thang tệ nhất có thể chọn:
    /// khoảng 8% nam giới không phân biệt được hai đầu của nó, nên với họ ma trận thành một
    /// mảng xám đồng đều — *tương quan +0,9 và −0,9 trông y hệt nhau*. Đó không phải "khó nhìn
    /// hơn một chút", đó là mất sạch thông tin.
    ///
    /// Ở đây dùng **lam ↔ trắng ↔ cam**. Lam và cam khác nhau ở cả sắc độ lẫn kênh vàng-lam,
    /// nên chúng phân biệt được với cả ba dạng mù màu phổ biến (protan, deutan, tritan). Đỏ–lam
    /// cũng an toàn với hai dạng đầu nhưng kém với tritan, nên cam thắng.
    ///
    /// ## Phân kỳ quanh 0, không phải quanh giữa dải
    ///
    /// Điểm trắng nằm ở đúng `r = 0` và độ đậm theo `|r|`. Nghĩa là dấu đọc được bằng SẮC (lam
    /// hay cam) và độ mạnh đọc được bằng ĐỘ ĐẬM — hai chiều thông tin trên hai kênh thị giác
    /// tách rời, thay vì ép cả hai vào một dải liên tục.
    public static func heatHex(_ value: Double) -> String {
        let clamped = min(1, max(-1, value))
        let strength = abs(clamped)
        // Trắng ngà chứ không trắng tinh: một ô trắng tinh lẫn vào nền bảng và người đọc không
        // biết ô ấy là "r = 0" hay là "chưa tính".
        let neutral = (r: 247.0, g: 247.0, b: 247.0)
        let end = clamped < 0
            ? (r: 33.0, g: 102.0, b: 172.0)     // lam đậm
            : (r: 179.0, g: 88.0, b: 6.0)       // cam đất
        func mix(_ from: Double, _ to: Double) -> Int {
            Int((from + (to - from) * strength).rounded())
        }
        return String(
            format: "#%02X%02X%02X",
            mix(neutral.r, end.r), mix(neutral.g, end.g), mix(neutral.b, end.b))
    }

    /// Màu chữ đọc được trên nền ấy — đen hay trắng, chọn theo độ sáng cảm nhận.
    ///
    /// Cần thiết vì đặc tả đòi ma trận SỐ *và* heatmap cùng lúc: con số nằm TRÊN ô màu. Chữ đen
    /// cố định sẽ biến mất trên ô lam đậm ở `r = −1`, và khi ấy đúng những ô quan trọng nhất là
    /// những ô không đọc được.
    public static func heatInkHex(_ value: Double) -> String {
        let strength = abs(min(1, max(-1, value)))
        // Hệ số theo ITU-R BT.601 — độ sáng CẢM NHẬN, không phải trung bình ba kênh: mắt người
        // nhạy với lục hơn lam nhiều lần, nên trung bình cộng sẽ đánh giá nền lam là sáng hơn
        // thực tế và chọn chữ đen lên một ô tối.
        let neutral = 0.299 * 247 + 0.587 * 247 + 0.114 * 247
        let end = value < 0
            ? 0.299 * 33 + 0.587 * 102 + 0.114 * 172
            : 0.299 * 179 + 0.587 * 88 + 0.114 * 6
        let luminance = neutral + (end - neutral) * strength
        return luminance < 140 ? "#FFFFFF" : "#1A1A1A"
    }
}
