import Foundation

/// Chuẩn hoá chuỗi để SO SÁNH kiểu ô tìm kiếm: bỏ hoa thường và bỏ dấu tiếng Việt.
///
/// **Vì sao nó ra đời ở đây chứ không nằm trong tính năng gọi nó đầu tiên.** Trước tệp này kho
/// đã có bốn chỗ tự bỏ dấu — `CSVFilter`, `CSVSort`, `QueryCatalog`, `PluginPackage` — mỗi chỗ
/// một biến thể, và chỉ MỘT trong bốn chỗ xử lý `Đ`. Một tính năng thứ năm cần cùng phép ấy
/// (tìm trong trang trợ giúp) là đúng lúc để dừng nhân bản, chứ không phải lúc thêm bản thứ năm.
///
/// **`Đ` phải thay tay.** `folding(.diacriticInsensitive)` bỏ được dấu của mọi nguyên âm tiếng
/// Việt nhưng KHÔNG đụng tới `Đ`/`đ`: trong Unicode đó là một chữ cái riêng (U+0110/U+0111),
/// không phải D mang dấu. Thiếu chỗ này thì gõ "da nang" không ra "Đà Nẵng" — và người dùng sẽ
/// kết luận là dữ liệu không có, chứ không nghĩ tại ô lọc.
public enum TextFold {

    /// Bỏ hoa thường VÀ bỏ dấu. Dùng cho mọi ô mang nghĩa "tìm kiếm", không dùng cho phép so bằng
    /// mang nghĩa "đúng y hệt".
    public static func fold(_ value: String) -> String {
        // Cửa nhanh cho chuỗi thuần ASCII: `folding(options:)` gọi vào ICU và tốn hàng chục lần
        // một phép hạ hoa-thường thường. Cột mã, cột số, cột ngày — phần lớn một bảng — đều là
        // ASCII, và ở đó không có dấu nào để mà bỏ. Đo trên bảng một triệu hàng: bỏ cửa nhanh
        // này là mất phần lớn 3,7 giây của một lượt lọc chữ.
        if value.allSatisfy({ $0.isASCII }) {
            return value.lowercased()
        }
        var out = value
        if out.contains("Đ") || out.contains("đ") {
            out = out.replacingOccurrences(of: "Đ", with: "D")
                .replacingOccurrences(of: "đ", with: "d")
        }
        return out.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
