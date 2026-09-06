import Foundation

/// Đọc dãy trang người dùng gõ: `1-3,5,8-` — dùng cho trích trang, xoá trang, tách tệp.
///
/// ## Vào 1-based, ra 0-based, và chỉ quy đổi ở ĐÚNG MỘT CHỖ
///
/// Người dùng đếm trang từ 1 — đó là con số in trên màn hình, trong mọi công cụ PDF, và trong
/// câu "in trang 3 đến 7" mà người ta nói với nhau. Mã thì đánh chỉ số từ 0. Trộn hai hệ ấy là
/// nguồn lỗi lệch-một kinh điển, nên phép quy đổi nằm gọn trong tệp này: mọi thứ đi ra khỏi đây
/// đã là chỉ số 0-based, và không chỗ nào khác được cộng trừ 1 nữa.
///
/// ## Từ chối chứ không đoán
///
/// Ba chỗ có thể "đoán cho tiện", và cả ba đều bị từ chối:
///
/// - **Dãy ngược** (`5-2`): không tự đảo thành `2-5`. Người gõ ngược đang nghĩ tới một thứ
///   khác với thứ họ gõ, và với một lệnh **xoá trang** thì đoán sai nghĩa là mất trang.
/// - **Vượt số trang** (`1-999` trên tệp 10 trang): không cắt bớt về 10. Cắt bớt biến một câu
///   sai thành một câu chạy được, và người dùng không bao giờ biết mình đã gõ nhầm.
/// - **Chuỗi rỗng**: không hiểu ngầm là "tất cả". Một lệnh xoá chạy trên "tất cả" vì người dùng
///   quên gõ gì là cách hỏng tệ nhất có thể.
public enum PageRange {

    public struct Failure: Error, Equatable, CustomStringConvertible {
        public let reason: String
        public init(_ reason: String) { self.reason = reason }
        public var description: String { reason }
    }

    /// Đọc `text` thành tập chỉ số trang **0-based**.
    ///
    /// - Parameter pageCount: số trang của tài liệu, để bắt chỗ vượt biên.
    public static func parse(_ text: String, pageCount: Int) throws -> IndexSet {
        guard pageCount > 0 else { throw Failure("Tài liệu không có trang nào") }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw Failure("Chưa nhập trang nào. Ví dụ: 1-3,5,8-")
        }

        var out = IndexSet()
        // `omittingEmptySubsequences: false` — mặc định của `split` NUỐT mục rỗng, nên `1,,3`
        // sẽ lặng lẽ thành `1,3`. Luật ở đây đồng nhất: mọi dấu phẩy thừa đều bị chặn, kể cả
        // dấu phẩy cuối câu. Một luật đơn giản nói được thành một câu thì dễ đoán hơn một luật
        // có ngoại lệ "dấu phẩy cuối thì tha".
        for rawPart in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            let part = rawPart.trimmingCharacters(in: .whitespaces)
            guard !part.isEmpty else { throw Failure("Có một mục rỗng — thừa dấu phẩy") }

            let bounds = try self.bounds(of: part, pageCount: pageCount)
            out.insert(integersIn: bounds)
        }
        return out
    }

    /// Khoảng 0-based của một mục, đã kiểm biên.
    private static func bounds(of part: String, pageCount: Int) throws -> Range<Int> {
        // Dấu `-` ở ĐẦU nghĩa là "từ trang 1", ở CUỐI nghĩa là "tới trang cuối". Tách theo vị
        // trí dấu chứ không theo `split`, vì `split` nuốt mất vế rỗng và `-4` sẽ thành `4`.
        if part.hasPrefix("-") {
            let end = try number(String(part.dropFirst()), in: part, pageCount: pageCount)
            return 0 ..< end
        }
        if part.hasSuffix("-") {
            let start = try number(String(part.dropLast()), in: part, pageCount: pageCount)
            return (start - 1) ..< pageCount
        }
        guard let dash = part.firstIndex(of: "-") else {
            let only = try number(part, in: part, pageCount: pageCount)
            return (only - 1) ..< only
        }
        let start = try number(String(part[part.startIndex ..< dash]), in: part, pageCount: pageCount)
        let end = try number(String(part[part.index(after: dash)...]), in: part, pageCount: pageCount)
        guard start <= end else {
            throw Failure("«\(part)» viết ngược — trang đầu phải nhỏ hơn trang cuối")
        }
        return (start - 1) ..< end
    }

    /// Một số trang 1-based hợp lệ.
    private static func number(_ text: String, in part: String, pageCount: Int) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), !trimmed.isEmpty else {
            throw Failure("«\(part)» không phải số trang")
        }
        guard value >= 1 else { throw Failure("«\(part)» — trang đếm từ 1") }
        guard value <= pageCount else {
            throw Failure("«\(part)» vượt quá số trang — tài liệu có \(pageCount) trang")
        }
        return value
    }

    /// Viết một tập chỉ số 0-based thành chuỗi người đọc được, gộp các đoạn liền nhau.
    ///
    /// Dùng cho câu thông báo sau khi làm xong: *"đã xoá trang 2-4, 9"* nói rõ hơn hẳn
    /// *"đã xoá 4 trang"* — nhất là khi người dùng cần biết mình có gõ đúng ý không.
    public static func describe(_ indices: IndexSet) -> String {
        indices.rangeView.map { range in
            let first = range.lowerBound + 1
            let last = range.upperBound
            return first == last ? "\(first)" : "\(first)-\(last)"
        }.joined(separator: ", ")
    }
}
