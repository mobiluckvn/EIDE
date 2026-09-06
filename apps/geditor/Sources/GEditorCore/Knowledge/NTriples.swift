import Foundation

/// Đọc N-Triples và edge list thành bảng ba cột — FR-KNW-906.
///
/// ## Vì sao KHÔNG dạy `CSVEngine` hiểu N-Triples
///
/// Đặc tả viết *"mọi thao tác cột theo field an toàn quoted (tái dùng CSVEngine)"*, và cách đọc
/// câu ấy dễ sai nhất là thêm một `CSVDialect` cho N-Triples. Không được: N-Triples có **hai**
/// cách bọc chồng lên nhau — `<iri>` cho tài nguyên và `"chữ"` cho literal, cộng hậu tố `@vi`
/// hoặc `^^<kiểu>` — còn CSV chỉ có một. Nhồi chúng vào một bộ tách trường sẽ hỏng ở đúng chỗ
/// dữ liệu thật hay có: một literal chứa dấu tab, hoặc một IRI chứa dấu phẩy.
///
/// Nên đường đi là: **đọc N-Triples bằng bộ đọc riêng, rồi PHÁT ra bảng ba cột qua
/// `CSVEngine.escape`**. Từ đó mọi thao tác cột của FR-CSV chạy nguyên vẹn mà không phải biết
/// N-Triples là gì.
///
/// ## Object giữ nguyên hình dạng, không "làm sạch"
///
/// `"Hà Nội"@vi` vào cột object nguyên văn cả hậu tố ngôn ngữ. Cắt hậu tố đi cho "đẹp" là làm
/// mất thông tin **không khôi phục được** — và người mở một file triple lên là người đang cần
/// đúng thông tin ấy.
public enum NTriples {

    public struct Triple: Equatable, Sendable {
        public let subject: String
        public let predicate: String
        public let object: String
        /// Dòng trong file (1-based) — để bấm một hàng là nhảy về đúng chỗ.
        public let line: Int
    }

    public struct Failure: Error, Equatable {
        public let line: Int
        public let reason: String
    }

    /// Đuôi file được coi là triple/edge list.
    public static let extensions = ["nt", "ntriples"]

    /// Đọc cả tài liệu. Dòng hỏng KHÔNG làm hỏng cả lượt đọc.
    ///
    /// Trả về cả triple đọc được lẫn danh sách dòng hỏng, thay vì ném ở dòng đầu tiên sai. File
    /// triple thật hay được ghép từ nhiều nguồn và gần như luôn có vài dòng lệch; dừng ở dòng
    /// đầu tiên nghĩa là người dùng không xem được gì cả vì một dòng trong mười nghìn.
    ///
    /// Nhưng **đếm** số dòng hỏng và trả ra — im lặng bỏ qua là cách một file mất một nửa nội
    /// dung mà không ai biết.
    public static func parse(_ text: String) -> (triples: [Triple], errors: [Failure]) {
        var triples: [Triple] = []
        var errors: [Failure] = []
        for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = index + 1
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            do {
                triples.append(try parseLine(trimmed, line: line))
            } catch let failure as Failure {
                errors.append(failure)
            } catch {
                errors.append(Failure(line: line, reason: "không đọc được"))
            }
        }
        return (triples, errors)
    }

    /// Một dòng: `subject predicate object .`
    static func parseLine(_ line: String, line number: Int) throws -> Triple {
        var scanner = Scanner(Array(line.utf8), line: number)
        let s = try scanner.term()
        let p = try scanner.term()
        let o = try scanner.term()
        try scanner.dot()
        return Triple(subject: s, predicate: p, object: o, line: number)
    }

    /// Bộ đọc theo BYTE, không theo `Character`.
    ///
    /// Cùng lý do `BM25Tokenizer` đi theo byte: `Character` của Swift phải tra bảng Unicode cho
    /// từng ký tự, và một file triple cỡ trăm MB thì khoản ấy là vài chục giây. Mọi ký tự có
    /// nghĩa ở đây (`<`, `>`, `"`, `\`, `.`, khoảng trắng) đều là ASCII, nên đọc byte an toàn —
    /// phần nhiều byte chỉ đi qua nguyên vẹn.
    struct Scanner {
        let bytes: [UInt8]
        var i = 0
        let line: Int

        init(_ bytes: [UInt8], line: Int) { self.bytes = bytes; self.line = line }

        mutating func skipSpaces() {
            while i < bytes.count, bytes[i] == 0x20 || bytes[i] == 0x09 { i += 1 }
        }

        mutating func term() throws -> String {
            skipSpaces()
            guard i < bytes.count else {
                throw Failure(line: line, reason: "thiếu thành phần")
            }
            switch bytes[i] {
            case UInt8(ascii: "<"): return try iri()
            case UInt8(ascii: "\""): return try literal()
            case UInt8(ascii: "_"): return blankNode()
            default:
                throw Failure(line: line,
                              reason: "thành phần phải bắt đầu bằng «<», «\"» hoặc «_:»")
            }
        }

        mutating func iri() throws -> String {
            let start = i
            i += 1
            while i < bytes.count, bytes[i] != UInt8(ascii: ">") { i += 1 }
            guard i < bytes.count else { throw Failure(line: line, reason: "IRI thiếu dấu «>»") }
            i += 1
            return String(decoding: bytes[start ..< i], as: UTF8.self)
        }

        /// Literal kèm hậu tố `@lang` hoặc `^^<kiểu>` nếu có — giữ NGUYÊN VĂN cả hậu tố.
        mutating func literal() throws -> String {
            let start = i
            i += 1
            while i < bytes.count {
                if bytes[i] == UInt8(ascii: "\\") { i += 2; continue }   // escape: bỏ qua cặp
                if bytes[i] == UInt8(ascii: "\"") { break }
                i += 1
            }
            guard i < bytes.count else {
                throw Failure(line: line, reason: "chuỗi thiếu dấu nháy đóng")
            }
            i += 1
            if i < bytes.count, bytes[i] == UInt8(ascii: "@") {
                i += 1
                while i < bytes.count, bytes[i] != 0x20, bytes[i] != 0x09,
                      bytes[i] != UInt8(ascii: ".") { i += 1 }
            } else if i + 1 < bytes.count,
                      bytes[i] == UInt8(ascii: "^"), bytes[i + 1] == UInt8(ascii: "^") {
                i += 2
                if i < bytes.count, bytes[i] == UInt8(ascii: "<") { _ = try iri() }
            }
            return String(decoding: bytes[start ..< i], as: UTF8.self)
        }

        mutating func blankNode() -> String {
            let start = i
            while i < bytes.count, bytes[i] != 0x20, bytes[i] != 0x09 { i += 1 }
            return String(decoding: bytes[start ..< i], as: UTF8.self)
        }

        mutating func dot() throws {
            skipSpaces()
            guard i < bytes.count, bytes[i] == UInt8(ascii: ".") else {
                throw Failure(line: line, reason: "dòng phải kết thúc bằng dấu «.»")
            }
        }
    }

    /// Phát ra bảng ba cột, bọc theo dialect — từ đây mọi thao tác cột của FR-CSV chạy nguyên vẹn.
    ///
    /// Cột thứ tư `dong` giữ số dòng gốc: bấm một hàng trong Table view là nhảy về đúng dòng
    /// trong file `.nt`. Không có nó thì bảng là một bản sao chết, và người dùng phải tự đi tìm.
    public static func table(_ triples: [Triple], dialect: CSVDialect = .tab) -> String {
        var out = ["subject", "predicate", "object", "dong"]
            .map { CSVEngine.escape($0, dialect: dialect) }
            .joined(separator: String(UnicodeScalar(dialect.delimiter))) + "\n"
        let sep = String(UnicodeScalar(dialect.delimiter))
        for t in triples {
            out += [t.subject, t.predicate, t.object, String(t.line)]
                .map { CSVEngine.escape($0, dialect: dialect) }
                .joined(separator: sep) + "\n"
        }
        return out
    }
}
