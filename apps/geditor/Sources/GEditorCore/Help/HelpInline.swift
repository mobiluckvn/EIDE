import Foundation

/// Ký hiệu nội tuyến trong câu văn của trang trợ giúp: `**đậm**` và `` `mã` ``.
///
/// **Đúng hai ký hiệu, và sẽ không thêm.** Cám dỗ ở đây là cứ thế bò dần tới một bộ dựng
/// Markdown đầy đủ — nghiêng, liên kết, gạch ngang, danh sách lồng. Mỗi thứ thêm vào là một
/// nhánh nữa trong bộ dựng của tầng app và một luật nữa người dịch phải giữ. Đậm để nhấn một
/// mệnh đề, `mã` để phân biệt thứ gõ được với thứ đọc thôi — hai việc ấy đủ cho mọi trang đang
/// có. Liên kết sang trang khác đã có khối `.seeAlso`, là chỗ đúng của nó: một liên kết giữa
/// dòng văn thì bộ soát liên kết chết không nhìn thấy.
///
/// **Ký hiệu lẻ là LỖI, không phải chữ thường.** Bộ dựng Markdown thường nuốt một dấu ``` ` ```
/// lẻ và in nó ra như chữ bình thường. Ở đây nó làm `problems()` đỏ lên. Lý do: một dấu lẻ hầu
/// như luôn là gõ thiếu, và cái giá của việc đoán sai — nửa trang bị in bằng phông mã — chỉ lộ
/// ra khi có người mở đúng trang ấy.
public enum HelpInline {

    public enum Style: Sendable, Equatable {
        case plain
        case strong
        case code
    }

    public struct Run: Sendable, Equatable {
        public let text: String
        public let style: Style

        public init(_ text: String, _ style: Style) {
            self.text = text
            self.style = style
        }
    }

    /// Tách một câu thành các đoạn có kiểu.
    ///
    /// `mã` được cắt TRƯỚC `**đậm**`: bên trong một khối mã, hai dấu sao là hai dấu sao — người
    /// viết trợ giúp về regex sẽ gõ `` `\d**` `` và không đợi nó hoá đậm.
    public static func runs(_ text: String) -> [Run] {
        var out: [Run] = []
        var plain = ""
        var index = text.startIndex

        func flushPlain() {
            if !plain.isEmpty {
                out.append(Run(plain, .plain))
                plain = ""
            }
        }

        while index < text.endIndex {
            let character = text[index]

            if character == "`" {
                let after = text.index(after: index)
                if let close = text[after...].firstIndex(of: "`") {
                    flushPlain()
                    out.append(Run(String(text[after..<close]), .code))
                    index = text.index(after: close)
                    continue
                }
            }

            if character == "*", text[index...].hasPrefix("**") {
                let after = text.index(index, offsetBy: 2)
                if let close = range(of: "**", in: text, from: after) {
                    flushPlain()
                    out.append(Run(String(text[after..<close.lowerBound]), .strong))
                    index = close.upperBound
                    continue
                }
            }

            plain.append(character)
            index = text.index(after: index)
        }
        flushPlain()
        return out
    }

    /// Chữ thuần, đã bỏ mọi ký hiệu. Dùng cho ô tìm và cho nhãn trợ năng.
    public static func plainText(_ text: String) -> String {
        runs(text).map(\.text).joined()
    }

    /// Ký hiệu gõ thiếu vế đóng.
    public static func problems(in text: String) -> [String] {
        var out: [String] = []
        // Đếm trên bản đã bóc: cặp nào khớp thì đã bị `runs` lấy đi, nên còn sót lại là còn lẻ.
        let leftover = runs(text).filter { $0.style == .plain }.map(\.text).joined()
        if leftover.filter({ $0 == "`" }).count % 2 != 0 || leftover.contains("`") {
            out.append("có dấu ` lẻ — thiếu vế đóng")
        }
        if occurrences(of: "**", in: leftover) > 0 {
            out.append("có dấu ** lẻ — thiếu vế đóng")
        }
        return out
    }

    private static func range(of needle: String, in text: String, from: String.Index)
        -> Range<String.Index>? {
        text.range(of: needle, range: from..<text.endIndex)
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var cursor = text.startIndex
        while let found = text.range(of: needle, range: cursor..<text.endIndex) {
            count += 1
            cursor = found.upperBound
        }
        return count
    }
}
