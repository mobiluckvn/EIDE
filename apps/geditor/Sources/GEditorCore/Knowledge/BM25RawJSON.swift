import Foundation

/// Lấy MỘT trường chuỗi ra khỏi một dòng JSONL mà không dựng đối tượng — FR-KNW-918.
///
/// ## Vì sao có thứ này thay vì cứ dùng `JSONSerialization`
///
/// PoC-M lấy mẫu lượt dựng chỉ mục 400 MB và thấy `newJSONString` chiếm **8,2%**, chưa kể phần
/// `swift_bridgeObjectRetain/Release` đi kèm. `JSONSerialization` dựng một `NSDictionary` và một
/// `NSString` cho **mọi** khoá và **mọi** giá trị của **mọi** bản ghi — trong khi bộ dựng chỉ mục
/// chỉ cần đúng hai trường, và một trong hai chỉ để cắt thành token rồi vứt.
///
/// Chuỗi `NSString` bắc cầu còn đắt lần thứ hai: bộ cắt token duyệt trên UTF-8, mà chuỗi bắc cầu
/// thì phải chuyển thành UTF-8 liền mạch trước đã.
///
/// ## Ranh giới: bộ này KHÔNG phải bộ đọc JSON
///
/// Nó chỉ nhận phần JSON mà nó chắc chắn đọc đúng, và **trả `nil` cho mọi thứ còn lại** để chỗ
/// gọi lui về `JSONSerialization`. Cụ thể nó bỏ cuộc khi:
///
/// * giá trị có ký tự thoát (`\"`, `\\`, `\uXXXX`) — giải mã thoát là chỗ dễ sai nhất, và
///   trong corpus thật nó hiếm;
/// * giá trị của trường cần tìm không phải chuỗi;
/// * gặp bất kỳ ký tự nào không đúng ngữ pháp ở vị trí đang đứng.
///
/// Bỏ cuộc thì CHẬM, không SAI. Đó là điều kiện để đường tắt này được phép tồn tại: một bộ đọc
/// JSON viết tay mà cố đọc hết mọi thứ thì sớm muộn cũng đọc sai một dòng nào đó, và một chỉ mục
/// sai thì không có gì trong sản phẩm chỉ ra được.
///
/// `BM25IndexTests` đối chiếu bộ này với `JSONSerialization` trên một tập ca hiểm — cả hai phải
/// cho cùng kết quả, hoặc bộ này phải nói "không biết".
enum BM25RawJSON {

    /// Dải byte của giá trị chuỗi tại `field`, hoặc `nil` nếu phải lui về bộ đọc đầy đủ.
    ///
    /// Dải trả về là **chỉ số trong `line`**, chưa giải mã thoát — vì đường tắt này chỉ nhận
    /// giá trị không có thoát nào.
    static func stringRange(
        field: String, in line: UnsafeBufferPointer<UInt8>
    ) -> Range<Int>? {
        let key = Array(field.utf8)
        var index = 0
        let count = line.count

        func skipSpace() {
            while index < count {
                let byte = line[index]
                if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D { index += 1 }
                else { return }
            }
        }

        skipSpace()
        guard index < count, line[index] == 0x7B else { return nil }   // '{'
        index += 1
        skipSpace()
        if index < count, line[index] == 0x7D { return nil }           // '{}' — không có trường

        while index < count {
            // --- khoá ---
            skipSpace()
            guard index < count, line[index] == 0x22 else { return nil }   // '"'
            guard let keyRange = scanString(line, &index) else { return nil }
            let matches = keyRange.count == key.count
                && !keyRange.isEmpty
                && memcmp(line.baseAddress! + keyRange.lowerBound, key, key.count) == 0

            skipSpace()
            guard index < count, line[index] == 0x3A else { return nil }   // ':'
            index += 1
            skipSpace()
            guard index < count else { return nil }

            // --- giá trị ---
            if line[index] == 0x22 {
                let start = index
                guard let valueRange = scanString(line, &index) else { return nil }
                if matches {
                    // Có thoát thì bộ này không nhận. `scanString` đã nhảy qua chúng đúng cách
                    // (nên nó biết chuỗi kết thúc ở đâu), nhưng GIẢI MÃ thì để bộ đọc thật làm.
                    return hasBackslash(line, from: start, to: index) ? nil : valueRange
                }
            } else {
                // Trường khác trường ta cần: nhảy qua, không diễn giải.
                guard skipValue(line, &index) else { return nil }
                if matches { return nil }   // trường cần tìm nhưng không phải chuỗi
            }

            skipSpace()
            guard index < count else { return nil }
            if line[index] == 0x2C { index += 1; continue }             // ','
            if line[index] == 0x7D { return nil }                      // '}' — hết, không thấy
            return nil
        }
        return nil
    }

    /// Đọc một chuỗi bắt đầu tại `index` (đang ở dấu `"`), trả dải BÊN TRONG hai dấu nháy.
    /// Sau khi trả về, `index` đứng ngay sau dấu nháy đóng.
    private static func scanString(
        _ line: UnsafeBufferPointer<UInt8>, _ index: inout Int
    ) -> Range<Int>? {
        let count = line.count
        index += 1
        let start = index
        while index < count {
            let byte = line[index]
            if byte == 0x5C {                 // '\' — nhảy qua cả ký tự bị thoát
                index += 2
                continue
            }
            if byte == 0x22 {
                let end = index
                index += 1
                return start ..< end
            }
            index += 1
        }
        return nil
    }

    private static func hasBackslash(
        _ line: UnsafeBufferPointer<UInt8>, from: Int, to: Int
    ) -> Bool {
        var index = from
        while index < to {
            if line[index] == 0x5C { return true }
            index += 1
        }
        return false
    }

    /// Nhảy qua một giá trị bất kỳ. Chỉ cần biết nó KẾT THÚC ở đâu, không cần biết nó là gì.
    private static func skipValue(
        _ line: UnsafeBufferPointer<UInt8>, _ index: inout Int
    ) -> Bool {
        let count = line.count
        guard index < count else { return false }
        switch line[index] {
        case 0x22:
            return scanString(line, &index) != nil
        case 0x7B, 0x5B:                       // '{' hoặc '['
            var depth = 0
            while index < count {
                let byte = line[index]
                if byte == 0x22 {
                    guard scanString(line, &index) != nil else { return false }
                    continue
                }
                if byte == 0x7B || byte == 0x5B { depth += 1 }
                if byte == 0x7D || byte == 0x5D {
                    depth -= 1
                    if depth == 0 { index += 1; return true }
                }
                index += 1
            }
            return false
        default:                               // số, true, false, null
            let start = index
            while index < count {
                let byte = line[index]
                if byte == 0x2C || byte == 0x7D || byte == 0x5D
                    || byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D { break }
                index += 1
            }
            return index > start
        }
    }
}
