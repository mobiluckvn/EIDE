import Foundation

/// Nạp danh sách entity và tìm mọi lần xuất hiện trong văn bản — FR-KNW-908.
///
/// ## Ba luật của phép khớp, và cả ba đều đến từ dữ liệu tiếng Việt
///
/// 1. **Khớp DÀI NHẤT thắng.** Có cả «An Phát» lẫn «Công ty An Phát» trong danh sách thì một
///    câu chứa cả cụm dài phải khớp cụm dài. Khớp ngắn trước sẽ cắt cụm dài làm đôi và đếm
///    thành hai entity — con số thống kê sai theo hướng phóng đại.
/// 2. **Phải đúng BIÊN TỪ.** «An» không được khớp bên trong «Anh» hay «Hoàn». Đây không phải
///    chuyện hiếm: tên riêng tiếng Việt ngắn và trùng âm tiết với vô số từ thường.
/// 3. **KHÔNG phân biệt hoa thường, nhưng GIỮ dấu.** «CÔNG TY» và «Công ty» là một; «má» và
///    «ma» thì không. Cùng luật với `BM25Tokenizer` và ngược với `TextDistance.normalize` —
///    hai chỗ ấy hỏi hai câu khác nhau, và ghi chú ở `TextDistance` đã nói vì sao.
///
/// ## Vì sao quét MỘT LƯỢT
///
/// Cách hiển nhiên là lặp qua từng entity rồi tìm chuỗi con — với 5.000 entity trên một tài liệu
/// 10 MB thì đó là 5.000 lượt quét toàn văn.
///
/// Ở đây là **một lượt**, dựa trên một bảng chỉ mục theo BYTE ĐẦU: tại mỗi vị trí, chỉ những
/// entity bắt đầu bằng đúng byte ấy mới được thử, và trong nhóm đó thì thử từ DÀI tới NGẮN để
/// luật "khớp dài nhất thắng" thành sự thật chứ không thành một lời hứa.
///
/// Chưa phải Aho-Corasick — không có liên kết thất bại, nên trường hợp xấu nhất vẫn là
/// `độ dài văn bản × độ dài khoá dài nhất`. Nói ra vì nó là ranh giới có thật: với danh sách
/// entity mà hàng nghìn mục cùng byte đầu, chỗ này sẽ chậm và đó là lúc cần đổi thuật toán.
public enum EntityMarker {

    public struct Entity: Equatable, Sendable {
        public let text: String
        public let type: String

        public init(text: String, type: String) {
            self.text = text
            self.type = type
        }
    }

    public struct Occurrence: Equatable, Sendable {
        /// Khoảng BYTE trong buffer.
        public let range: Range<Int>
        /// Chỉ số trong danh sách entity.
        public let entity: Int
        /// Dòng 0-based — cùng quy ước `DOTGraph.line` và `TextBuffer.lineNumber(atOffset:)`.
        public let line: Int
    }

    public struct Report: Equatable, Sendable {
        public let occurrences: [Occurrence]
        /// Loại → số lần xuất hiện.
        public let byType: [String: Int]
        /// Chỉ số entity → số lần xuất hiện.
        public let byEntity: [Int: Int]
        /// Loại → chỉ số màu Mark (0…8), gán TẤT ĐỊNH theo thứ tự bảng chữ cái.
        ///
        /// Tất định là điều kiện, không phải điểm cộng: màu đổi giữa hai lần chạy trên cùng một
        /// file làm người dùng tưởng dữ liệu đổi.
        public let colorOfType: [String: Int]
    }

    public struct Failure: Error, Equatable {
        public let reason: String
    }

    // MARK: - Nạp danh sách

    /// Nạp từ CSV. Hai cột đầu là `text` và `type`; dòng tiêu đề bị bỏ nếu nhận ra.
    public static func loadCSV(_ text: String, dialect: CSVDialect = .comma) throws -> [Entity] {
        let buffer = TextBuffer(text: text)
        var out: [Entity] = []
        var dong = 0
        try CSVEngine.forEachRow(in: buffer, dialect: dialect) { row in
            defer { dong += 1 }
            guard row.count >= 2 else { return true }
            let o = row.prefix(2).map {
                String(decoding: CSVEngine.unescape(buffer.bytes(in: $0.range), dialect: dialect),
                       as: UTF8.self).trimmingCharacters(in: .whitespaces)
            }
            // Nhận ra dòng tiêu đề bằng NỘI DUNG chứ không bằng vị trí: một danh sách entity
            // xuất từ công cụ khác có thể không có tiêu đề, và bỏ dòng đầu vô điều kiện là mất
            // một entity mà không ai biết.
            if dong == 0, ["text", "entity", "name", "ten"].contains(o[0].lowercased()) {
                return true
            }
            guard !o[0].isEmpty else { return true }
            out.append(Entity(text: o[0], type: o[1].isEmpty ? "khác" : o[1]))
            return true
        }
        return out
    }

    /// Nạp từ JSON: mảng `[{"text":…, "type":…}]`.
    public static func loadJSON(_ text: String) throws -> [Entity] {
        guard let doi = try? JSONSerialization.jsonObject(with: Data(text.utf8)),
              let mang = doi as? [[String: Any]] else {
            throw Failure(reason: "JSON phải là một MẢNG các đối tượng {text, type}")
        }
        return mang.compactMap { muc in
            guard let t = muc["text"] as? String, !t.isEmpty else { return nil }
            return Entity(text: t, type: (muc["type"] as? String) ?? "khác")
        }
    }

    // MARK: - Tìm

    public static func find(
        _ entities: [Entity], in buffer: TextBuffer, cancelToken: CancelToken = CancelToken()
    ) -> Report {
        let loai = Set(entities.map(\.type)).sorted()
        var mau: [String: Int] = [:]
        for (i, t) in loai.enumerated() { mau[t] = i % LineMarkBook.colorCount }
        guard !entities.isEmpty else {
            return Report(occurrences: [], byType: [:], byEntity: [:], colorOfType: mau)
        }

        // Khoá khớp: hạ chữ thường, GIỮ dấu.
        let khoa = entities.map { Array($0.text.lowercased().utf8) }
        // Chỉ mục theo byte đầu — cắt phần lớn vị trí ngay bước một.
        var theoByteDau: [UInt8: [Int]] = [:]
        for (i, k) in khoa.enumerated() where !k.isEmpty {
            theoByteDau[k[0], default: []].append(i)
        }
        // Trong mỗi nhóm, thử khoá DÀI trước để "khớp dài nhất thắng" thành sự thật.
        for key in theoByteDau.keys {
            theoByteDau[key]?.sort { khoa[$0].count > khoa[$1].count }
        }

        let goc = buffer.bytes(in: 0 ..< buffer.count)
        let bytes = hạThường(buffer.text, goc)
        var out: [Occurrence] = []
        var demLoai: [String: Int] = [:]
        var demEntity: [Int: Int] = [:]

        var i = 0
        while i < bytes.count {
            if cancelToken.isCancelled { break }
            guard let ungVien = theoByteDau[bytes[i]], laBienTrai(goc, i) else { i += 1; continue }
            var khop: (Int, Int)?          // (chỉ số entity, độ dài)
            for e in ungVien {
                let k = khoa[e]
                guard i + k.count <= bytes.count else { continue }
                var j = 0
                while j < k.count, bytes[i + j] == k[j] { j += 1 }
                guard j == k.count, laBienPhai(goc, i + k.count) else { continue }
                khop = (e, k.count)
                break                       // đã sắp theo độ dài giảm dần → cái đầu là dài nhất
            }
            guard let (e, dai) = khop else { i += 1; continue }
            out.append(Occurrence(range: i ..< (i + dai), entity: e,
                                  line: buffer.lineNumber(atOffset: i)))
            demEntity[e, default: 0] += 1
            demLoai[entities[e].type, default: 0] += 1
            i += dai
        }

        return Report(occurrences: out, byType: demLoai, byEntity: demEntity, colorOfType: mau)
    }

    /// Bản hạ chữ thường của văn bản, **giữ nguyên độ dài byte** để offset còn khớp buffer gốc.
    ///
    /// ## Bản đầu của hàm này SAI, và bài kiểm bắt được
    ///
    /// Nó chỉ hạ byte ASCII (`A`…`Z` → `+32`) kèm một ghi chú tự tin rằng "chữ tiếng Việt đã
    /// được `lowercased()` xử lý ở phía khoá". Sai: `Ô` là `C3 94` còn `ô` là `C3 B4` — không
    /// phép cộng nào trên byte đầu biến cái này thành cái kia, nên «CÔNG TY» không bao giờ khớp
    /// «công ty». Bài `testKhongPhanBietHoaThuong` đỏ ngay, và đó là lý do nó tồn tại.
    ///
    /// ## Vì sao đi theo SCALAR mà vẫn ra byte
    ///
    /// Hạ chữ thường đúng phải qua bảng Unicode, nhưng kết quả phải giữ nguyên **độ dài byte**:
    /// mọi `Occurrence` là một khoảng byte trên buffer GỐC, và một phép biến đổi làm lệch độ dài
    /// sẽ dời mọi vị trí sau nó — con trỏ nhảy sai chỗ, vùng tô lệch, và không có gì báo lỗi.
    ///
    /// Với chữ tiếng Việt thì hai dạng hoa/thường luôn cùng độ dài UTF-8, nên phép thay là an
    /// toàn. Ký tự nào KHÔNG cùng độ dài thì **giữ nguyên** — nó sẽ không khớp bất kể hoa
    /// thường, và đó là cái giá đúng để trả: thà sót một khớp còn hơn lệch mọi vị trí phía sau.
    static func hạThường(_ text: String, _ goc: [UInt8]) -> [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(goc.count)
        for scalar in text.unicodeScalars {
            let dai = String(scalar).utf8.count
            let thuong = Array(String(scalar).lowercased().utf8)
            if thuong.count == dai {
                out += thuong
            } else {
                out += Array(String(scalar).utf8)
            }
        }
        // Bất biến: độ dài phải khớp buffer gốc. Lệch là mọi offset sau đó sai, nên thà quay về
        // bản gốc (mất phép khớp không phân biệt hoa thường) còn hơn báo sai vị trí.
        return out.count == goc.count ? out : goc
    }

    /// Biên trái: đầu file, hoặc byte trước không phải chữ/số.
    static func laBienTrai(_ bytes: [UInt8], _ i: Int) -> Bool {
        i == 0 ? true : !laChu(bytes, i - 1)
    }

    static func laBienPhai(_ bytes: [UInt8], _ i: Int) -> Bool {
        i >= bytes.count ? true : !laChu(bytes, i)
    }

    /// Byte này có thuộc một "từ" không.
    ///
    /// Byte ≥ 0x80 coi là CHỮ: chúng là phần của một ký tự nhiều byte, và mọi ký tự nhiều byte
    /// trong ngữ cảnh này đều là chữ tiếng Việt. Coi chúng là dấu phân cách sẽ làm «Nguyễn» khớp
    /// bên trong «Nguyễnnn» — và tệ hơn, làm biên rơi vào GIỮA một ký tự.
    static func laChu(_ bytes: [UInt8], _ i: Int) -> Bool {
        let b = bytes[i]
        if b >= 0x80 { return true }
        return (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
            || b == UInt8(ascii: "_")
    }
}
