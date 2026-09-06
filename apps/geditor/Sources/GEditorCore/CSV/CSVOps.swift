import Foundation

/// Thao tác cấu trúc trên tài liệu CSV (FR-CSV-404, FR-CSV-406).
///
/// Phần KIỂM TRA dữ liệu nằm ở `CSVValidator`: nó kiểm cả số cột lẫn kiểu theo cột trong một
/// lượt quét. Trước đây chỗ này có một hàm `validate` chỉ đếm cột; giữ lại hai bản kiểm cùng
/// một thứ là cách chắc chắn để chúng lệch nhau về sau.
///
/// Cùng quy ước với `DocumentOps`: trả về `[TextEdit]`, không tự sửa buffer — mọi thao tác
/// hàng loạt là MỘT bước undo (FR-CORE-004).
///
/// Mọi thứ ở đây đứng trên phạm vi byte do `CSVEngine.parse` trả về, nên ba luật RFC 4180
/// được giữ nguyên: field bọc ngoặc kép chứa được dấu phẩy, `""` là một dấu `"`, và field
/// bọc chứa được cả xuống dòng. Nếu thao tác cột làm việc trên "dòng" thay vì trên field thì
/// một file có quoted field xuống dòng sẽ bị cắt sai ngay từ dòng đầu tiên.
public enum CSVOps {

    // MARK: - Xóa cột (FR-CSV-404)

    /// Xóa cột thứ `index` (0-based).
    ///
    /// Phạm vi xóa gồm cả DẤU PHÂN TÁCH đi kèm, nếu không thì file còn lại một dấu phẩy thừa
    /// ở mỗi dòng. Cột cuối nuốt dấu phân tách đứng TRƯỚC nó; các cột khác nuốt dấu đứng sau.
    public static func deleteColumn(
        _ index: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [TextEdit] {
        var edits: [TextEdit] = []

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            // Dòng không có cột đó thì bỏ qua — dữ liệu thật hay có dòng thiếu cột, và làm
            // hỏng chúng khi xóa cột là cách mất dữ liệu không ai ngờ tới.
            guard index < row.count else { return true }

            let field = row[index]
            let range: Range<Int>
            if index + 1 < row.count {
                range = field.range.lowerBound ..< row[index + 1].range.lowerBound
            } else if index > 0 {
                range = row[index - 1].range.upperBound ..< field.range.upperBound
            } else {
                range = field.range   // cột duy nhất: chỉ xóa nội dung, giữ dòng
            }
            if !range.isEmpty { edits.append(TextEdit(range: range, bytes: [])) }
            return true
        }
        return edits
    }

    // MARK: - Chèn cột (FR-CSV-404)

    /// Chèn một cột RỖNG vào vị trí `index` (0-based); `index` bằng số cột nghĩa là thêm vào cuối.
    ///
    /// Chỉ chèn đúng MỘT dấu phân tách cho mỗi hàng — nội dung của cột mới là chuỗi rỗng, và
    /// chuỗi rỗng trong CSV không cần dấu bọc.
    ///
    /// Hàng ngắn hơn `index` thì dấu phân tách rơi xuống CUỐI hàng. Bất biến giữ được là "mọi
    /// hàng đều tăng đúng một field": hàng vốn lệch cột vẫn lệch y như cũ, không lệch thêm.
    /// Cách khác — bỏ qua hàng ngắn như khi xóa cột — sẽ khiến số cột của chúng lệch một bậc
    /// so với phần còn lại của file.
    public static func insertColumn(
        at index: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [TextEdit] {
        guard index >= 0 else { return [] }
        var edits: [TextEdit] = []
        let separator = [dialect.delimiter]

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            guard let last = row.last else { return true }
            if index < row.count {
                // Chèn dấu phân tách NGAY TRƯỚC cột ấy: "a,b,c" chèn ở 1 thành "a,,b,c".
                let at = row[index].range.lowerBound
                edits.append(TextEdit(range: at ..< at, bytes: separator))
            } else {
                let at = last.range.upperBound
                edits.append(TextEdit(range: at ..< at, bytes: separator))
            }
            return true
        }
        return edits
    }

    // MARK: - Đổi tên tiêu đề cột (FR-CSV-408)

    /// Đổi tên cột `index` ở hàng tiêu đề.
    ///
    /// Chỉ đụng vào HÀNG ĐẦU. Tên mới được bọc lại khi cần — người dùng đặt tên "Doanh thu,
    /// VNĐ" mà ghi thẳng thì hàng tiêu đề tách thành hai cột và lệch khỏi toàn bộ dữ liệu bên
    /// dưới.
    public static func renameHeader(
        _ index: Int,
        to name: String,
        in buffer: TextBuffer,
        dialect: CSVDialect
    ) throws -> [TextEdit] {
        guard index >= 0, buffer.count > 0 else { return [] }
        var header: [CSVField] = []
        try CSVEngine.forEachRow(in: buffer, dialect: dialect) { row in
            header = row
            return false                       // chỉ cần hàng đầu
        }
        guard index < header.count else { return [] }
        return [TextEdit(
            range: header[index].range, text: CSVEngine.escape(name, dialect: dialect)
        )]
    }

    // MARK: - Hoán vị cột (FR-CSV-404)

    /// Chuyển cột `from` tới vị trí `to`, giữ nguyên các cột khác.
    ///
    /// Viết lại từng hàng bằng cách GHÉP LẠI các field theo thứ tự mới, sao chép nguyên byte
    /// thô của mỗi field.
    ///
    /// Vì sao byte THÔ chứ không bóc ra rồi bọc lại: bóc-bọc vẫn cho ra nội dung đúng (đã thử
    /// bằng đối chứng âm — mọi bài kiểm vẫn xanh), nhưng nó CHUẨN HÓA cách bọc. Một field ghi
    /// là `"abc"` — bọc dù không cần — sẽ thành `abc`. Nội dung không đổi, nhưng file đổi ở
    /// những hàng mà người dùng không hề đụng tới, và với Git thì đó là cả file bị đánh dấu
    /// thay đổi. Đổi chỗ hai cột là đổi chỗ hai cột, không phải dịp để viết lại cách bọc.
    ///
    /// Hàng không đủ cột thì BỎ QUA, cùng lý do với xóa cột: dữ liệu thật hay có hàng thiếu
    /// cột, và sắp xếp lại một hàng thiếu cột là đoán xem field nào thuộc cột nào.
    public static func moveColumn(
        from: Int,
        to: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [TextEdit] {
        guard from >= 0, to >= 0, from != to else { return [] }
        var edits: [TextEdit] = []
        let separator = dialect.delimiter

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            guard from < row.count, to < row.count,
                  let lower = row.first?.range.lowerBound,
                  let upper = row.last?.range.upperBound else { return true }

            var order = Array(0 ..< row.count)
            order.remove(at: from)
            order.insert(from, at: to)

            var bytes: [UInt8] = []
            bytes.reserveCapacity(upper - lower)
            for (position, column) in order.enumerated() {
                if position > 0 { bytes.append(separator) }
                bytes.append(contentsOf: buffer.bytes(in: row[column].range))
            }
            edits.append(TextEdit(range: lower ..< upper, bytes: bytes))
            return true
        }
        return edits
    }

    // MARK: - Chuyển sang JSON (FR-CSV-406)

    /// CSV → JSON (mảng các object), dùng hàng đầu làm tên khóa.
    ///
    /// Hàng thiếu cột thì khóa thiếu bị BỎ QUA chứ không điền chuỗi rỗng: "không có dữ liệu"
    /// và "dữ liệu là chuỗi rỗng" là hai chuyện khác nhau, và JSON phân biệt được.
    ///
    /// - Parameter maxRows: 0 = cả tài liệu; số dương = chỉ bấy nhiêu hàng dữ liệu, cho bản
    ///   xem trước. Bản xem trước đi qua ĐÚNG hàm này chứ không phải một hàm rút gọn viết
    ///   riêng — hai đường khác nhau thì bản xem trước sẽ nói dối đúng lúc người dùng tin nó.
    public static func toJSON(
        _ buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> String {
        func value(_ field: CSVField) -> String {
            String(
                decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
                as: UTF8.self
            )
        }

        var keys: [String] = []
        var out = "["
        var wroteAny = false
        var isFirstRow = true
        var rows = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            if isFirstRow {
                isFirstRow = false
                if hasHeader {
                    keys = row.map(value)
                    return true
                }
                keys = (0 ..< row.count).map { "cột\($0 + 1)" }
            }
            // Hàng dài hơn hàng tiêu đề: sinh thêm khóa thay vì bỏ cột đi mất.
            while keys.count < row.count { keys.append("cột\(keys.count + 1)") }

            let pairs = row.enumerated().map { index, field in
                "    \(jsonString(keys[index])): \(jsonString(value(field)))"
            }
            out += (wroteAny ? ",\n" : "\n") + "  {\n" + pairs.joined(separator: ",\n") + "\n  }"
            wroteAny = true
            rows += 1
            return maxRows <= 0 || rows < maxRows
        }

        return wroteAny ? out + "\n]" : "[]"
    }

    /// Escape chuỗi theo đúng JSON (RFC 8259).
    ///
    /// Viết tay thay vì dùng `JSONSerialization` vì ta cần escape MỘT chuỗi lẻ chứ không phải
    /// dựng cả cây đối tượng — và với một triệu hàng thì dựng cây trung gian là tốn gấp đôi
    /// bộ nhớ so với chính đầu ra.
    static func jsonString(_ value: String) -> String { JSONText.quoted(value) }
}
