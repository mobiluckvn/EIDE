import Foundation

/// Dịch tham chiếu kiểu A1 khi hàng bị chèn vào hoặc xoá đi.
///
/// **Vì sao phải có lớp này trước khi cho chèn/xoá hàng ở giữa.** Số hiệu hàng trong một tệp
/// `.xlsx` không chỉ nằm ở thuộc tính `r` của `<row>`. Nó còn nằm trong công thức (`=A5`), vùng
/// ô gộp (`<mergeCell ref="A1:B5"/>`), định dạng có điều kiện (`sqref`), xác thực dữ liệu, vùng
/// lọc, liên kết, vùng dữ liệu của sheet. Đổi số hiệu hàng mà bỏ sót một chỗ là **làm hỏng tệp
/// một cách im lặng**: nó vẫn mở được, chỉ là vài công thức trỏ sai chỗ — và người dùng phát
/// hiện ra sau khi đã dùng con số ấy.
///
/// **Tuyệt đối `$` KHÔNG miễn dịch với chèn hàng.** `$A$5` nghĩa là "đừng đổi khi tôi CHÉP công
/// thức này đi chỗ khác", không phải "đừng đổi khi có hàng chèn vào trên". Excel dịch cả hai
/// loại. Bỏ qua vế này là sai theo đúng cách khó nhận ra nhất, vì phần lớn công thức trong tệp
/// thật là tương đối và sẽ trông đúng.
public enum A1Reference {

    /// Kế hoạch dịch: xoá `deleted` hàng bắt đầu từ `at`, rồi chèn `inserted` hàng vào đó.
    ///
    /// Một phép chèn thuần là `deleted == 0`; một phép xoá thuần là `inserted == 0`. Gộp hai
    /// thứ vào một cấu trúc vì chúng dịch số hiệu bằng CÙNG một công thức, và tách ra thành hai
    /// đường là mời hai chỗ lệch nhau.
    public struct Shift: Equatable, Sendable {
        /// Chỉ số hàng 0-based nơi phép sửa bắt đầu.
        public var at: Int
        public var deleted: Int
        public var inserted: Int

        public init(at: Int, deleted: Int, inserted: Int) {
            self.at = at
            self.deleted = deleted
            self.inserted = inserted
        }

        public var delta: Int { inserted - deleted }
        public var isEmpty: Bool { deleted == 0 && inserted == 0 }

        /// Số hiệu hàng MỚI của một hàng cũ (1-based vào, 1-based ra).
        ///
        /// Trả `nil` khi hàng ấy đã bị xoá — chỗ gọi phải quyết định làm gì, và với công thức
        /// thì câu trả lời là `#REF!` đúng như Excel làm.
        public func newRowNumber(for oldRow: Int) -> Int? {
            let zero = oldRow - 1
            if zero < at { return oldRow }
            if zero < at + deleted { return nil }
            return oldRow + delta
        }
    }

    // MARK: - Một ô

    /// `"$A$5"` → (cột `"$A"`, hàng 5, có `$` trước hàng).
    struct Cell: Equatable {
        var columnPart: String      // gồm cả `$` nếu có
        var rowDollar: Bool
        var row: Int
    }

    static func parseCell(_ text: String) -> Cell? {
        var index = text.startIndex
        var column = ""
        if index < text.endIndex, text[index] == "$" {
            column.append("$")
            index = text.index(after: index)
        }
        var letters = ""
        while index < text.endIndex, text[index].isLetter {
            letters.append(text[index])
            index = text.index(after: index)
        }
        guard !letters.isEmpty else { return nil }
        column += letters

        var rowDollar = false
        if index < text.endIndex, text[index] == "$" {
            rowDollar = true
            index = text.index(after: index)
        }
        var digits = ""
        while index < text.endIndex, text[index].isNumber {
            digits.append(text[index])
            index = text.index(after: index)
        }
        guard index == text.endIndex, let row = Int(digits) else { return nil }
        return Cell(columnPart: column, rowDollar: rowDollar, row: row)
    }

    static func render(_ cell: Cell) -> String {
        cell.columnPart + (cell.rowDollar ? "$" : "") + String(cell.row)
    }

    /// Dịch một tham chiếu ô. Trả `nil` khi hàng ấy đã bị xoá.
    public static func shiftCell(_ text: String, by shift: Shift) -> String? {
        guard var cell = parseCell(text) else { return text }
        guard let row = shift.newRowNumber(for: cell.row) else { return nil }
        cell.row = row
        return render(cell)
    }

    // MARK: - Một vùng

    /// Dịch `"A1:B5"`. Trả `nil` khi CẢ vùng nằm trong phần bị xoá.
    ///
    /// Vùng bị xoá MỘT PHẦN thì co lại chứ không biến mất — đúng như Excel làm khi xoá hàng
    /// giữa một vùng ô gộp.
    public static func shiftRange(_ text: String, by shift: Shift) -> String? {
        guard let colon = text.firstIndex(of: ":") else { return shiftCell(text, by: shift) }
        let leftText = String(text[text.startIndex ..< colon])
        let rightText = String(text[text.index(after: colon)...])
        guard var left = parseCell(leftText), var right = parseCell(rightText) else { return text }

        let deletedRange = (shift.at + 1) ... (shift.at + max(shift.deleted, 1))
        let fullyInside = shift.deleted > 0
            && left.row >= deletedRange.lowerBound && right.row <= deletedRange.upperBound
        guard !fullyInside else { return nil }

        // Đầu vùng rơi vào phần bị xoá thì kéo lên đúng chỗ phép xoá bắt đầu; cuối vùng rơi vào
        // đó thì kéo xuống hàng ngay trước phép xoá. Không làm vậy thì vùng sẽ trỏ vào một hàng
        // không còn tồn tại.
        left.row = shift.newRowNumber(for: left.row) ?? (shift.at + 1)
        right.row = shift.newRowNumber(for: right.row) ?? shift.at
        if right.row < left.row { right.row = left.row }
        return render(left) + ":" + render(right)
    }

    /// Dịch một danh sách vùng cách nhau bằng dấu cách (`sqref="A1:A5 C1:C5"`).
    public static func shiftSqref(_ text: String, by shift: Shift) -> String {
        text.split(separator: " ")
            .compactMap { shiftRange(String($0), by: shift) }
            .joined(separator: " ")
    }

    // MARK: - Công thức

    /// Dịch mọi tham chiếu A1 trong một công thức.
    ///
    /// **Bỏ qua phần trong dấu nháy kép**: `=IF(A1>0,"B2 hỏng","")` có chuỗi `B2` mà không phải
    /// tham chiếu. Dịch nó là sửa chữ hiển thị cho người dùng.
    ///
    /// **Bỏ qua tên hàm và tên đã đặt**: `LOG10(` là tên hàm, `Thang1` có thể là tên đã đặt. Chỉ
    /// nhận khi chữ+số đứng một mình — tức ký tự ngay trước không phải chữ/số/gạch dưới, và ký
    /// tự ngay sau không phải chữ/số/gạch dưới/dấu mở ngoặc.
    public static func shiftFormula(_ formula: String, by shift: Shift) -> String {
        var out = ""
        out.reserveCapacity(formula.count)
        let characters = Array(formula)
        var index = 0
        var inQuote = false

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                inQuote.toggle()
                out.append(character)
                index += 1
                continue
            }
            if inQuote {
                out.append(character)
                index += 1
                continue
            }

            // Thử đọc một tham chiếu bắt đầu tại đây.
            if character == "$" || character.isLetter {
                let previous = index > 0 ? characters[index - 1] : " "
                let boundaryBefore = !(previous.isLetter || previous.isNumber
                    || previous == "_" || previous == "!" || previous == "$")
                var end = index
                if characters[end] == "$" { end += 1 }
                var letters = 0
                while end < characters.count, characters[end].isLetter { end += 1; letters += 1 }
                var sawDollar = false
                if end < characters.count, characters[end] == "$" { end += 1; sawDollar = true }
                var digits = 0
                while end < characters.count, characters[end].isNumber { end += 1; digits += 1 }
                let after = end < characters.count ? characters[end] : " "
                let boundaryAfter = !(after.isLetter || after.isNumber || after == "_"
                    || after == "(")
                _ = sawDollar

                if boundaryBefore, boundaryAfter, letters > 0, letters <= 3, digits > 0 {
                    let text = String(characters[index ..< end])
                    out += shiftCell(text, by: shift) ?? "#REF!"
                    index = end
                    continue
                }
            }
            out.append(character)
            index += 1
        }
        return out
    }
}
