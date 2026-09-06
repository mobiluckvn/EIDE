import Foundation

/// Thụt lề hiện hành của một tệp, đọc từ chính tệp ấy.
///
/// ## Vì sao là một tệp riêng
///
/// Hai chỗ cần đúng phép này — `GraphEdit` (FR-KNW-915) và `MermaidEdit` (FR-MMD-004) — và cả
/// hai đều sinh câu lệnh mới chèn vào tệp của người dùng. Kho này đã bốn lần gặp mẫu "hai bản
/// của một thuật toán", lần tệ nhất là ba bộ thoát chuỗi JSON mà một bộ hỏng hẳn. Nên phép này
/// ra đời ở chỗ dùng chung NGAY lần thứ hai cần tới, chứ không phải sau khi đã có hai bản.
///
/// Chỗ khác nhau giữa hai chỗ gọi chỉ là "dòng nào không tính" — DOT bỏ qua `//` và `{`, Mermaid
/// bỏ qua `%%` và `subgraph`. Đó là một tham số, không phải một thuật toán thứ hai.
public enum TextIndent {

    /// Chuỗi thụt lề PHỔ BIẾN NHẤT trong các dòng câu lệnh.
    ///
    /// Lấy cái phổ biến nhất chứ không lấy của dòng đầu: dòng đầu thường là chú thích căn lề
    /// trái, và khi ấy mọi câu lệnh mới sẽ dán sát mép trong khi phần còn lại thụt vào.
    ///
    /// - Parameter ignoring: trả `true` cho những dòng KHÔNG được tính (chú thích, dòng mở/đóng
    ///   khối). Nội dung truyền vào đã bỏ phần thụt lề.
    public static func common(
        of text: String, ignoring: (Substring) -> Bool = { _ in false }
    ) -> String {
        var dem: [String: Int] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let noiDung = line.drop { $0 == " " || $0 == "\t" }
            guard !noiDung.isEmpty, !ignoring(noiDung) else { continue }
            dem[String(line.prefix(line.count - noiDung.count)), default: 0] += 1
        }
        // Hoà thì lấy chuỗi thụt DÀI hơn — thà thụt sâu một nấc còn hơn dán sát mép.
        return dem.max { ($0.value, $0.key.count) < ($1.value, $1.key.count) }?.key ?? "    "
    }
}
