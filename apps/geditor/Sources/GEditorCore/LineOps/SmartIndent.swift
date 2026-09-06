import Foundation

/// Thụt lề tự động khi xuống dòng (FR-CORE-011).
///
/// **Quy tắc chỉ có hai câu**, và cố ý dừng ở đó:
///
/// 1. Dòng mới thừa hưởng thụt lề của dòng đang đứng.
/// 2. Dòng đang đứng MỞ một khối thì thêm một bậc.
///
/// **Vì sao không làm hơn.** Thụt lề "thông minh" theo kiểu định dạng lại cả khối — kiểu mà
/// IDE làm — cần hiểu ngữ pháp và cần biết ý định của người viết. Khi nó đoán trúng thì tiết
/// kiệm một phím; khi đoán trượt thì nó SỬA thứ người dùng vừa gõ, và họ phải gỡ ra. Một phím
/// tiết kiệm không bù nổi một lần bị sửa sai.
///
/// Đặc biệt: ở đây KHÔNG có luật "gõ `}` thì tự lùi dòng về một bậc". Luật ấy chạm vào dòng đã
/// gõ xong chứ không phải dòng mới, và nó là thứ hay bị kêu nhất ở mọi trình soạn thảo có nó.
///
/// **Thuần túy.** Không chạm buffer, không sinh sửa đổi — chỉ trả về chuỗi thụt lề cần chèn.
public enum SmartIndent {

    /// Bề rộng một bậc thụt lề, tính theo cột.
    public static let defaultStep = 4

    /// Chuỗi thụt lề cho dòng MỚI, khi xuống dòng ở cuối `line`.
    ///
    /// - Parameters:
    ///   - line: nội dung dòng đang đứng, KHÔNG gồm ký tự xuống dòng.
    ///   - language: `nil` cho văn bản thuần — khi ấy chỉ thừa hưởng thụt lề, không thêm bậc.
    ///   - usesTabs: dòng mới thụt bằng TAB hay bằng dấu cách.
    ///   - tabWidth: một TAB rộng mấy cột.
    public static func indent(
        afterLine line: String,
        language: SyntaxLanguage?,
        usesTabs: Bool = false,
        tabWidth: Int = 4,
        step: Int = defaultStep
    ) -> String {
        let inherited = leadingWhitespace(of: line)
        guard let language, language.opensBlock(line) else { return inherited }

        // Thêm một bậc. Đo bằng CỘT chứ không bằng số ký tự: một dòng thụt bằng TAB và một
        // dòng thụt bằng tám dấu cách trông giống nhau, và dòng mới phải khớp với thứ nhìn
        // thấy, không phải với thứ đếm được.
        let columns = width(of: inherited, tabWidth: tabWidth) + step
        return whitespace(toColumn: columns, usesTabs: usesTabs, tabWidth: tabWidth)
    }

    /// Phần khoảng trắng đầu dòng, nguyên văn.
    public static func leadingWhitespace(of line: String) -> String {
        String(line.prefix(while: { $0 == " " || $0 == "\t" }))
    }

    /// Bề rộng theo CỘT của một chuỗi khoảng trắng, TAB nở tới nấc kế tiếp.
    public static func width(of whitespace: String, tabWidth: Int) -> Int {
        var columns = 0
        for character in whitespace {
            if character == "\t" {
                let step = max(1, tabWidth)
                columns += step - (columns % step)
            } else {
                columns += 1
            }
        }
        return columns
    }

    /// Chuỗi khoảng trắng đạt đúng `column` cột.
    static func whitespace(toColumn column: Int, usesTabs: Bool, tabWidth: Int) -> String {
        guard column > 0 else { return "" }
        guard usesTabs, tabWidth > 0 else { return String(repeating: " ", count: column) }
        // Còn dư vài cột lẻ thì đệm bằng dấu cách: một TAB không chia nhỏ được, và làm tròn
        // lên sẽ đẩy dòng mới thụt sâu hơn dòng nó đang theo.
        return String(repeating: "\t", count: column / tabWidth)
            + String(repeating: " ", count: column % tabWidth)
    }
}
