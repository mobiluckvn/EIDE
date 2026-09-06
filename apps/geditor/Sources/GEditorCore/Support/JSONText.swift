import Foundation

/// Bọc một chuỗi thành chuỗi JSON hợp lệ — nền dùng chung.
///
/// ## Vì sao tệp này ra đời muộn, và vì sao nó phải ra đời
///
/// Tới 28/08/2026 kho có **BA** bản của phép bọc này — `GoldenSetBuilder`, `CSVOps`,
/// `MermaidBrand` — và chúng **không giống nhau**:
///
/// | Bản | Thoát `\n`, `\t`, ký tự điều khiển | Hex |
/// |---|---|---|
/// | `GoldenSetBuilder` | có | `%04x` thường |
/// | `CSVOps` | có | `%04X` HOA |
/// | `MermaidBrand` | **KHÔNG** | — |
///
/// Bản thứ ba là một **lỗi thật**, không phải khác biệt về gu: một giá trị thương hiệu chứa
/// xuống dòng sẽ sinh ra JSON hỏng, và chỗ nhận nó là JavaScript trong WKWebView — nơi một
/// chuỗi hỏng thành lỗi cú pháp làm sơ đồ không vẽ được, chứ không thành một thông báo đọc được.
///
/// Đây là lần thứ TƯ dự án gặp mẫu "hai bản của một thuật toán" (sau MAD, SplitMix64, hằng số
/// outlier — xem ghi chú đầu `TextDistance`). Ba lần trước hai bản cho hai con số khác nhau;
/// lần này một bản cho ra dữ liệu hỏng. Nên nó về đây, và ba chỗ kia gọi vào đây.
///
/// ## Hex viết thường
///
/// Dạng thoát `\u00NN` viết hex THƯỜNG. Cả thường lẫn HOA đều hợp lệ; chọn thường vì hai
/// trong ba bản cũ dùng thường, và vì mọi
/// bộ sinh JSON phổ biến (`JSONSerialization`, `json.dumps`) cũng vậy — khi so hai tệp bằng
/// `diff`, giống bộ sinh phổ biến thì ít nhiễu hơn.
public enum JSONText {

    /// Chuỗi JSON có sẵn hai dấu nháy bao ngoài.
    ///
    /// KHÔNG thoát ký tự ngoài ASCII: JSON cho phép UTF-8 nguyên văn, và thoát chúng thành
    /// `\uXXXX` làm tệp phình gấp sáu lần với tiếng Việt — đúng thứ ngôn ngữ mà mọi corpus của
    /// sản phẩm này chứa.
    public static func quoted(_ text: String) -> String {
        var out = "\""
        out.reserveCapacity(text.utf8.count + 2)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}
