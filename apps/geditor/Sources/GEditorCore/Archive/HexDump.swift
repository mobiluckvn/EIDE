import Foundation

/// Trình bày byte thành dòng hex — phần thuần tính toán của chế độ xem nhị phân.
///
/// ## Vì sao ở lõi mà không nằm trong view
///
/// Ba chỗ cần đúng một cách trình bày: khung xem trên màn hình, nút **Chép** (chép ra phải giống
/// hệt thứ đang nhìn), và bài kiểm. Ba bản hiện thực là ba lần lệch nhau về căn lề, và lệch căn
/// lề trong một bảng hex thì người đọc đếm sai offset — tức sai đúng thứ duy nhất bảng ấy dùng
/// để làm.
///
/// ## Không hàm nào ở đây đọc tệp
///
/// Chúng nhận byte của **một dòng** rồi trả về chữ. Khung xem lấy byte từ `MappedFile`, tức từ
/// bộ nhớ ánh xạ — mở tệp 1 GB ở chế độ nhị phân không tốn 1 GB RAM, và không có đường nào ở đây
/// vô tình nạp cả tệp.
public enum HexDump {

    /// Số byte mỗi dòng.
    ///
    /// 16 chứ không phải một con số đổi được. Bảng hex là thứ người ta đọc bằng cách **đếm nhẩm
    /// theo cột**, và mọi tài liệu định dạng nhị phân trên đời đều mô tả offset theo bội của 16.
    /// Một khung hex 24 byte/dòng buộc người đọc phải quy đổi trong đầu ở mỗi dòng.
    public static let bytesPerRow = 16

    /// Số dòng cần cho một tệp cỡ `size`.
    ///
    /// Tệp RỖNG có 0 dòng, không phải 1: một dòng toàn dấu chấm cho một tệp rỗng trông y hệt
    /// một tệp 16 byte NUL, và hai thứ ấy phải phân biệt được.
    public static func rowCount(forSize size: Int) -> Int {
        size <= 0 ? 0 : (size + bytesPerRow - 1) / bytesPerRow
    }

    /// Khoảng byte của dòng thứ `row`, đã cắt theo cỡ tệp.
    public static func byteRange(ofRow row: Int, size: Int) -> Range<Int> {
        let start = min(row * bytesPerRow, max(size, 0))
        let end = min(start + bytesPerRow, max(size, 0))
        return start ..< end
    }

    /// Cột offset, ví dụ `0001F400`.
    ///
    /// Rộng theo CỠ TỆP chứ không cố định 8 ký tự: tệp dưới 4 GB thì 8 ký tự là đủ và thừa chỗ
    /// cho tệp nhỏ, còn tệp lớn hơn thì 8 ký tự **cắt mất chữ số đầu** — một offset cụt là một
    /// offset sai, và nó sai một cách trông vẫn hợp lý.
    public static func offsetColumn(_ offset: Int, size: Int) -> String {
        let width = max(8, String(max(size - 1, 0), radix: 16).count)
        let text = String(max(offset, 0), radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }

    /// Cột hex: `48 65 6C 6C 6F ...`, đệm cho dòng cuối để cột ASCII không nhảy chỗ.
    ///
    /// Có một khoảng trắng THÊM ở giữa byte thứ 8 và thứ 9. Không phải trang trí: mắt người
    /// không đếm nổi 16 ô liền nhau, và mọi công cụ hex đều tách đôi ở đúng chỗ ấy.
    public static func hexColumn(_ bytes: [UInt8], padded: Bool = true) -> String {
        var parts: [String] = []
        for index in 0 ..< bytesPerRow {
            if index == bytesPerRow / 2 { parts.append("") }
            if index < bytes.count {
                let value = String(bytes[index], radix: 16, uppercase: true)
                parts.append(value.count == 1 ? "0" + value : value)
            } else if padded {
                parts.append("  ")
            }
        }
        return parts.joined(separator: " ")
    }

    /// Cột chữ: byte in được giữ nguyên, còn lại thành `.`.
    ///
    /// **Chỉ ASCII in được, KHÔNG giải mã UTF-8.** Một ký tự tiếng Việt chiếm hai tới ba byte,
    /// nên hiện nó ra sẽ làm cột chữ không còn thẳng hàng với cột hex — mà sự thẳng hàng ấy
    /// chính là công dụng của cột này. Ai cần đọc chữ có dấu thì đã có chế độ xem thường.
    public static func asciiColumn(_ bytes: [UInt8]) -> String {
        String(bytes.map { $0 >= 0x20 && $0 < 0x7F ? Character(UnicodeScalar($0)) : "." })
    }

    /// Một dòng đầy đủ, đúng như nó hiện trên màn hình và đúng như nút Chép ghi ra.
    public static func line(offset: Int, bytes: [UInt8], size: Int) -> String {
        offsetColumn(offset, size: size)
            + "  " + hexColumn(bytes)
            + "  |" + asciiColumn(bytes) + "|"
    }

    /// Nhiều dòng liền nhau, dựng từ một khối byte bắt đầu tại `offset`.
    public static func text(from bytes: [UInt8], startingAt offset: Int, size: Int) -> String {
        stride(from: 0, to: bytes.count, by: bytesPerRow).map { index in
            let slice = Array(bytes[index ..< min(index + bytesPerRow, bytes.count)])
            return line(offset: offset + index, bytes: slice, size: size)
        }.joined(separator: "\n")
    }
}
