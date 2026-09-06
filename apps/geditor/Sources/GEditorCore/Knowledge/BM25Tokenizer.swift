import Foundation

/// Cắt văn bản thành token cho chỉ mục BM25 — FR-KNW-918.
///
/// ## Giới hạn phải nói ra ngay: đây CHƯA phải bộ tách từ tiếng Việt
///
/// FR-KNW-918 viết *"tokenizer tiếng Việt dùng chung FR-MIN-006"*. FR-MIN-006 (khai phá văn bản)
/// **chưa có mã** — nó là P2, Phase 4. Nên bộ này cắt theo **ranh giới ký tự**, không theo từ
/// ghép: *"cơ sở dữ liệu"* thành ba token `cơ` `sở` `dữ` `liệu`, không phải một.
///
/// Điều đó **không** làm BM25 sai — nó làm BM25 trả lời một câu hỏi hơi khác: khớp theo âm tiết
/// thay vì theo từ. Với tiếng Việt, khác biệt ấy có thật và đo được, nên nó phải nằm trong khối
/// "Phương pháp" của mọi báo cáo dùng chỉ mục này (NFR-MIN-04), chứ không giấu trong mã.
///
/// Khi FR-MIN-006 có mã, chỗ thay là hàm này — và chỉ mục cũ **tự vô hiệu** vì tên bộ tách từ
/// nằm trong đầu tệp chỉ mục (xem `BM25Index.Manifest.tokenizer`).
///
/// ## Dấu tiếng Việt: GIỮ, không bỏ
///
/// Bỏ dấu thì `má`, `mà`, `mã`, `ma` gộp làm một — và trong một corpus tiếng Việt, đó là gộp
/// những từ chẳng liên quan gì tới nhau. Ô lọc CSV và Function List cố ý bỏ dấu vì ở đó người
/// dùng đang GÕ TÌM và gõ thiếu dấu là chuyện thường; truy hồi thì ngược lại — nó xếp hạng theo
/// mức khớp, và một cú gộp sai làm hỏng chính thứ nó đo.
///
/// `foldDiacritics` để lại như một công tắc vì corpus song ngữ có ca dùng thật, nhưng **mặc
/// định TẮT**, và nó nằm trong đầu tệp chỉ mục nên đổi công tắc là chỉ mục cũ hết hiệu lực.
public struct BM25Tokenizer: Equatable, Sendable {

    /// Tên ghi vào đầu tệp chỉ mục. Đổi cách cắt token thì PHẢI đổi tên này.
    public static let name = "am-tiet-v1"

    public var foldDiacritics: Bool
    /// Token ngắn hơn ngần này bị bỏ. 1 là hợp lý cho tiếng Việt (âm tiết một chữ có nghĩa).
    public var minimumLength: Int

    public init(foldDiacritics: Bool = false, minimumLength: Int = 1) {
        self.foldDiacritics = foldDiacritics
        self.minimumLength = max(1, minimumLength)
    }

    /// Cắt và chuẩn hoá.
    ///
    /// Ranh giới token: chữ cái hoặc chữ số. Mọi thứ khác là dấu ngắt — kể cả `_` và `-`, khác
    /// với `CompletionEngine.isWordCharacter`. Lý do: ở đây token là ĐƠN VỊ TRUY HỒI, và người
    /// hỏi *"hợp đồng"* nên khớp được cả `hop-dong` lẫn `hop_dong` trong dữ liệu cào về.
    ///
    /// ## Chạy trên UTF-8, KHÔNG duyệt `Character`
    ///
    /// Bản đầu viết `for character in text { if character.isLetter … }` — đúng và đọc được, và
    /// **chậm hơn hai bậc**. PoC-M lấy mẫu bộ dựng chỉ mục và thấy 60% thời gian nằm ở đúng hai
    /// chỗ: `Character.isLetter` gọi `_swift_stdlib_getBinaryProperties` (tra bảng Unicode cho
    /// TỪNG ký tự), và `String.Iterator.next()` đi vòng qua `_CFStringGetCStringPtrInternal` —
    /// vì chuỗi do `JSONSerialization` trả về là `NSString` bắc cầu, nên mỗi lần lấy một ký tự
    /// là một lần gọi Objective-C.
    ///
    /// `makeContiguousUTF8()` gỡ vế thứ hai bằng MỘT lần chuyển cho cả bản ghi; duyệt byte gỡ
    /// vế thứ nhất. Phân loại chữ cái dùng bảng cho ASCII và dải Latin mở rộng (chỗ mọi chữ
    /// tiếng Việt nằm), chỉ rơi về `Unicode.Scalar.properties` cho ký tự lạ — mà corpus tiếng
    /// Việt gần như không có.
    public func tokens(in text: String) -> [String] {
        var text = text
        text.makeContiguousUTF8()
        // Mọi biến đổi nằm TRONG closure và kết quả trả ra qua giá trị trả về, KHÔNG có biến
        // cục bộ nào bị closure bắt giữ.
        //
        // Đó không phải chuyện văn phong. Bản trước có `func flush()` lồng bên trong, bắt giữ
        // `token`/`out`/`isASCII`; Swift không chứng minh được hai lần truy cập không chồng
        // nhau nên nó chèn kiểm tra ĐỘC QUYỀN TRUY CẬP lúc chạy vào từng lần sửa. Bộ lấy mẫu
        // đo được `AccessSet::insert` + `swift_beginAccess`/`endAccess` + `SwiftTLSContext`
        // chiếm **27%** cả lượt dựng chỉ mục — nhiều hơn cả phần cắt token thật sự.
        //
        // Cái giá của việc gỡ hàm lồng là vòng lặp phải có một điểm kết-thúc-token DUY NHẤT,
        // nên nó chạy tới `count` chứ không tới `count - 1`: vòng cuối cùng không đọc byte
        // nào, nó chỉ để đóng token đang dở.
        return text.withUTF8 { tokens(inUTF8: $0) }
    }

    /// Cắt token thẳng trên byte, không cần có `String` nào trước đó.
    ///
    /// Bộ dựng chỉ mục gọi thẳng bản này khi nó lấy được giá trị trường ra khỏi dòng JSONL mà
    /// không phải nhờ `JSONSerialization` — xem `BM25Index.rawString(field:in:)`.
    public func tokens(inUTF8 utf8: UnsafeBufferPointer<UInt8>) -> [String] {
        let minimum = minimumLength
        let fold = foldDiacritics
    let count = utf8.count
        var out: [String] = []
        out.reserveCapacity(count / 6)
        var token: [UInt8] = []
        token.reserveCapacity(32)
        var isASCII = true
        var index = 0

        while index <= count {
            if index < count {
                let byte = utf8[index]
                if byte < 0x80 {
                    if BM25Tokenizer.asciiWord[Int(byte)] {
                        token.append(byte)
                        index += 1
                        continue
                    }
                    index += 1
                } else {
                    // Ký tự nhiều byte: lấy trọn chuỗi byte của nó rồi hỏi một lần.
                    var width = 1
                    if byte >= 0xF0 { width = 4 } else if byte >= 0xE0 { width = 3 }
                    else if byte >= 0xC0 { width = 2 }
                    let end = min(count, index + width)
                    if BM25Tokenizer.isWordScalar(BM25Tokenizer.scalar(utf8, index, end)) {
                        token.append(contentsOf: utf8[index ..< end])
                        isASCII = false
                        index = end
                        continue
                    }
                    index = end
                }
            } else {
                index += 1
            }

            // Điểm kết thúc token duy nhất.
            if token.isEmpty { continue }
            // Token thuần ASCII hạ hoa thường ngay trên byte; token có dấu mới cần
            // `lowercased()` thật, và nó hiếm hơn nhiều lần trong một corpus trộn số với chữ.
            var word: String
            if isASCII {
                for position in token.indices
                where token[position] >= 65 && token[position] <= 90 {
                    token[position] += 32
                }
                word = String(decoding: token, as: UTF8.self)
            } else {
                word = String(decoding: token, as: UTF8.self).lowercased()
            }
            token.removeAll(keepingCapacity: true)
            isASCII = true
            if fold { word = CSVFilter.fold(word) }
            // `word.count` đếm CỤM KÝ TỰ — nó chạy thuật toán ngắt grapheme của Unicode
            // trên từng token. Ngưỡng mặc định là 1 và mọi token tới đây đều khác rỗng,
            // nên phép đếm ấy chỉ cần chạy khi người dùng đặt ngưỡng cao hơn.
            if minimum > 1, word.count < minimum { continue }
            out.append(word)
        }
        return out
    }

    /// Vị trí của những token nằm trong `terms`, tính bằng **offset UTF-16**.
    ///
    /// FR-KNW-918 đòi *"HIGHLIGHT từ khớp trong từng chunk"*. Tô sáng không làm được bằng cách
    /// tìm chuỗi con: câu hỏi «hợp» phải sáng ở «hợp đồng» nhưng KHÔNG được sáng ở «hợp tác xã»
    /// — à không, phải sáng ở cả hai, vì cả hai đều chứa token `hợp`. Đúng luật là: sáng ở
    /// những chỗ mà **bộ tách token này** cắt ra đúng token ấy. Bất cứ luật nào khác sẽ tô sáng
    /// một chỗ mà điểm BM25 không hề tính tới, và người dùng sẽ đọc bảng điểm sai.
    ///
    /// Offset UTF-16 vì đích đến là một text view của AppKit, và `NSRange` đếm bằng UTF-16.
    /// Trả về offset chứ không trả `String.Index` để kết quả đi qua được ranh giới lõi/app.
    public func matches(in text: String, terms: Set<String>) -> [Range<Int>] {
        guard !terms.isEmpty else { return [] }
        var text = text
        text.makeContiguousUTF8()
        let fold = foldDiacritics
        return text.withUTF8 { utf8 -> [Range<Int>] in
            var out: [Range<Int>] = []
            var token: [UInt8] = []
            token.reserveCapacity(32)
            var isASCII = true
            var index = 0
            var utf16 = 0            // vị trí UTF-16 của `index`
            var tokenStart = 0       // vị trí UTF-16 của đầu token đang gom

            while index <= utf8.count {
                var isWord = false
                var width = 1
                var units = 1
                if index < utf8.count {
                    let byte = utf8[index]
                    if byte < 0x80 {
                        isWord = BM25Tokenizer.asciiWord[Int(byte)]
                    } else {
                        if byte >= 0xF0 { width = 4 } else if byte >= 0xE0 { width = 3 }
                        else if byte >= 0xC0 { width = 2 }
                        let end = min(utf8.count, index + width)
                        width = end - index
                        // Ký tự ngoài mặt phẳng cơ bản chiếm HAI đơn vị UTF-16.
                        units = width == 4 ? 2 : 1
                        isWord = BM25Tokenizer.isWordScalar(
                            BM25Tokenizer.scalar(utf8, index, end))
                    }
                }
                if isWord {
                    if token.isEmpty { tokenStart = utf16 }
                    token.append(contentsOf: utf8[index ..< (index + width)])
                    if width > 1 { isASCII = false }
                    index += width
                    utf16 += units
                    continue
                }

                if !token.isEmpty {
                    var word: String
                    if isASCII {
                        for position in token.indices
                        where token[position] >= 65 && token[position] <= 90 {
                            token[position] += 32
                        }
                        word = String(decoding: token, as: UTF8.self)
                    } else {
                        word = String(decoding: token, as: UTF8.self).lowercased()
                    }
                    if fold { word = CSVFilter.fold(word) }
                    if terms.contains(word) { out.append(tokenStart ..< utf16) }
                    token.removeAll(keepingCapacity: true)
                    isASCII = true
                }
                if index >= utf8.count { break }
                index += width
                utf16 += units
            }
            return out
        }
    }

    /// ĐẾM token mà không dựng chuỗi nào.
    ///
    /// Có mặt vì Chunk Inspector (FR-KNW-902) chỉ cần con SỐ. Dựng 110 triệu `String` để rồi
    /// lấy `.count` là cấp phát 110 triệu lần cho một phép đếm — bộ lấy mẫu đo được lượt thống
    /// kê 1 GB mất **69,7 giây** so với trần 10,4, và đây là một trong hai chỗ tốn.
    ///
    /// Ngưỡng `minimumLength` chỉ chạy khi người dùng đặt > 1, cùng lý do như ở `tokens`.
    public func countTokens(inUTF8 utf8: UnsafeBufferPointer<UInt8>) -> Int {
        guard minimumLength <= 1, !foldDiacritics else {
            return tokens(inUTF8: utf8).count
        }
        var count = 0
        var inToken = false
        var index = 0
        while index < utf8.count {
            let byte = utf8[index]
            var isWord: Bool
            var width = 1
            if byte < 0x80 {
                isWord = BM25Tokenizer.asciiWord[Int(byte)]
            } else {
                if byte >= 0xF0 { width = 4 } else if byte >= 0xE0 { width = 3 }
                else if byte >= 0xC0 { width = 2 }
                let end = min(utf8.count, index + width)
                isWord = BM25Tokenizer.isWordScalar(BM25Tokenizer.scalar(utf8, index, end))
                width = end - index
            }
            if isWord {
                if !inToken { count += 1; inToken = true }
            } else {
                inToken = false
            }
            index += width
        }
        return count
    }

    /// Bảng ASCII: chữ cái và chữ số là ký tự TRONG token, còn lại là dấu ngắt.
    static let asciiWord: [Bool] = (0 ..< 128).map { code in
        let scalar = UInt8(code)
        return (scalar >= 48 && scalar <= 57)      // 0-9
            || (scalar >= 65 && scalar <= 90)      // A-Z
            || (scalar >= 97 && scalar <= 122)     // a-z
    }

    static func scalar(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int) -> UInt32 {
        var value: UInt32 = 0
        let first = bytes[start]
        let width = end - start
        switch width {
        case 2: value = UInt32(first & 0x1F)
        case 3: value = UInt32(first & 0x0F)
        case 4: value = UInt32(first & 0x07)
        default: return UInt32(first)
        }
        for index in (start + 1) ..< end {
            value = (value << 6) | UInt32(bytes[index] & 0x3F)
        }
        return value
    }

    /// Ký tự này có thuộc về một token không.
    ///
    /// Dải Latin mở rộng phủ trọn chữ tiếng Việt, trừ hai chỗ phải loại bằng tay: `×` (U+00D7)
    /// và `÷` (U+00F7) nằm giữa các chữ cái nhưng là DẤU TOÁN. Bỏ sót hai ngoại lệ ấy thì
    /// `3×4` thành một token, và bản đối chứng Python (`str.isalnum()`) sẽ nói ngược lại — đúng
    /// chỗ NFR-KNW-04 đòi hai cài đặt khớp nhau.
    static func isWordScalar(_ value: UInt32) -> Bool {
        if value == 0xD7 || value == 0xF7 { return false }
        if (0xC0 ... 0x24F).contains(value) { return true }      // Latin-1 + Latin mở rộng A/B
        if (0x1E00 ... 0x1EFF).contains(value) { return true }   // Latin Extended Additional
        guard let unicode = Unicode.Scalar(value) else { return false }
        return unicode.properties.isAlphabetic
            || (unicode.value >= 0x30 && unicode.value <= 0x39)
    }

    /// Mô tả cho khối "Phương pháp" — NFR-MIN-04 đòi mọi kết quả nói ra cách nó được tính.
    public var methodology: String {
        "Tách token theo ranh giới chữ/số, hạ chữ thường"
            + (foldDiacritics ? ", BỎ DẤU tiếng Việt" : ", GIỮ dấu tiếng Việt")
            + ". Tách theo ÂM TIẾT, không theo TỪ GHÉP: «cơ sở dữ liệu» thành ba token. Ghép từ "
            + "ghép có ở FR-MIN-006 (`TextMining`) và cần một TỪ ĐIỂN người dùng nạp — chỉ mục "
            + "này cố ý không dùng nó, vì đổi cách tách là làm mọi chỉ mục cũ vô nghĩa mà không "
            + "có gì báo."
    }
}
