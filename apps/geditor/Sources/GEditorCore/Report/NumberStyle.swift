import Foundation

/// Định dạng số cho báo cáo — FR-RPT-002.
///
/// Đặc tả: *"định dạng số/đơn vị (kể cả quy ước Việt 1.234,56)"*.
///
/// ## Vì sao KHÔNG dùng `NumberFormatter` của Foundation
///
/// `NumberFormatter` định dạng theo **locale của máy đang chạy**. Một báo cáo dựng trên máy đặt
/// tiếng Việt và một báo cáo dựng trên máy đặt tiếng Anh sẽ cho ra hai tệp HTML khác nhau từ
/// cùng một tài liệu `.greport.md` — cùng dữ liệu, khác dấu phân cách. Đó là mất tính tái lập,
/// và nó mất trong im lặng: không ai nhìn `1,234.56` mà nghĩ rằng máy mình đang nói dối.
///
/// Quy ước ở đây do **chính tài liệu khai**, và mặc định là kiểu Việt vì đây là sản phẩm Việt.
/// Ai cần kiểu Anh thì viết `number_format: plain` trong frontmatter, và tệp ấy cho ra cùng kết
/// quả trên mọi máy.
///
/// ## Ba tham số, không nhiều hơn
///
/// Nhóm nghìn, dấu thập phân, số chữ số sau dấu. Đơn vị đi kèm dạng tiền tố/hậu tố. Không có
/// làm tròn theo bậc (`1.2M`) ở đây — `ChartRender.number` đã làm việc ấy cho NHÃN TRỤC, nơi chỗ
/// hẹp và người đọc cần ước lượng. Bảng số trong báo cáo thì ngược lại: người ta cộng lại bằng
/// tay, nên `1.234.567` phải là `1.234.567`.
public struct NumberStyle: Equatable, Sendable {

    /// Dấu nhóm nghìn.
    public var groupSeparator: String
    /// Dấu thập phân.
    public var decimalSeparator: String
    /// Số chữ số sau dấu thập phân. `nil` = giữ đúng những chữ số có nghĩa, tối đa 6.
    public var decimals: Int?
    public var prefix: String
    public var suffix: String

    public init(
        groupSeparator: String = ".", decimalSeparator: String = ",", decimals: Int? = nil,
        prefix: String = "", suffix: String = ""
    ) {
        self.groupSeparator = groupSeparator
        self.decimalSeparator = decimalSeparator
        self.decimals = decimals
        self.prefix = prefix
        self.suffix = suffix
    }

    /// Quy ước Việt: `1.234,56`.
    public static let vietnamese = NumberStyle()
    /// Quy ước Anh–Mỹ: `1,234.56`.
    public static let english = NumberStyle(groupSeparator: ",", decimalSeparator: ".")
    /// Không nhóm nghìn — dạng máy đọc, dùng khi xuất lại ra CSV.
    public static let plain = NumberStyle(groupSeparator: "", decimalSeparator: ".")

    public static func named(_ name: String) -> NumberStyle? {
        switch name.lowercased() {
        case "vi", "vietnamese", "viet": return .vietnamese
        case "en", "english": return .english
        case "plain", "raw": return .plain
        default: return nil
        }
    }

    public func format(_ value: Double) -> String {
        guard value.isFinite else { return "—" }

        let digits = decimals ?? naturalDecimals(of: value)
        // Làm tròn TRƯỚC khi tách phần nguyên: làm tròn sau sẽ cho `1.999,9` thành phần nguyên
        // 1999 với phần lẻ "10" khi giá trị thật là 1999,95.
        let rounded = (value * pow(10, Double(digits))).rounded() / pow(10, Double(digits))
        let negative = rounded < 0
        let magnitude = abs(rounded)

        let whole = magnitude.rounded(.down)
        var text = grouped(String(format: "%.0f", whole))
        if digits > 0 {
            let fraction = (magnitude - whole) * pow(10, Double(digits))
            // `%.0f` trên phần lẻ đã nhân lên: `.rounded()` ở đây bù sai số dấu phẩy động, ví
            // dụ 0,1 + 0,2 cho 0,30000000000000004.
            let fractionText = String(
                format: "%0\(digits).0f", fraction.rounded())
            text += decimalSeparator + fractionText
        }
        return (negative ? "−" : "") + prefix + text + suffix
    }

    /// Số chữ số thập phân "tự nhiên": bỏ đuôi 0, tối đa 6.
    ///
    /// Cần vì một cột có cả `1000` lẫn `12,5`: ép hai chữ số thì `1000` thành `1.000,00` (thừa),
    /// ép không chữ số thì `12,5` thành `13` (sai). Không khai `decimals` thì mỗi giá trị tự
    /// quyết — và tầng gọi có thể khai để cả cột đều nhau khi nó muốn.
    private func naturalDecimals(of value: Double) -> Int {
        guard value != value.rounded() else { return 0 }
        for digits in 1...6 {
            let scaled = value * pow(10, Double(digits))
            if abs(scaled - scaled.rounded()) < 1e-9 { return digits }
        }
        return 6
    }

    private func grouped(_ digits: String) -> String {
        guard !groupSeparator.isEmpty, digits.count > 3 else { return digits }
        var out: [String] = []
        var buffer = ""
        for character in digits.reversed() {
            buffer.append(character)
            if buffer.count == 3 {
                out.append(String(buffer.reversed()))
                buffer = ""
            }
        }
        if !buffer.isEmpty { out.append(String(buffer.reversed())) }
        return out.reversed().joined(separator: groupSeparator)
    }

    /// Dạng NÉN cho nhãn trục: `1,2M` · `340k` · `12,5`.
    ///
    /// ## Nén là nhu cầu BỐ CỤC, dấu phân cách là quy ước NGÔN NGỮ — hai chuyện khác nhau
    ///
    /// Một trục Y rộng 56 điểm không chứa nổi `1.234.567`; nhãn sẽ đè lên nhau và biểu đồ thành
    /// không đọc được. Nên nhãn trục LUÔN nén, kể cả trong báo cáo tiếng Việt.
    ///
    /// Nhưng dấu phân cách thì vẫn theo tài liệu: `1,2M` chứ không phải `1.2M`. Trộn hai chuyện
    /// này — hoặc bỏ nén để "đúng quy ước Việt", hoặc giữ dấu chấm để "cho gọn" — đều sai một
    /// nửa. Bảng số trong báo cáo thì ngược lại, KHÔNG nén: người ta cộng lại bằng tay.
    public func compact(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = abs(value)
        if magnitude >= 1_000_000 {
            return NumberStyle(
                groupSeparator: groupSeparator, decimalSeparator: decimalSeparator,
                decimals: 1, prefix: prefix, suffix: "M" + suffix)
                .format(value / 1_000_000)
        }
        if magnitude >= 1_000 {
            return NumberStyle(
                groupSeparator: groupSeparator, decimalSeparator: decimalSeparator,
                decimals: 0, prefix: prefix, suffix: "k" + suffix)
                .format(value / 1_000)
        }
        return format(value)
    }

    /// Định dạng một ô của bảng: số thì theo quy ước, chữ thì giữ nguyên.
    ///
    /// Nhận diện số bằng `Double(text)` — tức theo quy ước MÁY (`1234.56`), vì đó là dạng
    /// DuckDB trả về. Không thử đọc `1.234,56` ngược lại: một ô chữ `2.5` trong cột mã sản phẩm
    /// sẽ bị hiểu thành số và bị định dạng lại, làm hỏng dữ liệu người dùng.
    public func formatCell(_ text: String?) -> String {
        guard let text else { return "" }
        guard let value = Double(text) else { return text }
        return format(value)
    }
}
