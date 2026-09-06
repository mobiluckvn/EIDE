import Compression
import Foundation

/// Đọc `.tar` và các bản đã nén của nó — `.tar.gz`, `.tgz`, `.tar.xz`, `.gz`, `.xz`.
///
/// **Vì sao tự viết, khi đã định vendor libarchive.** Vì phần này KHÔNG cần libarchive: định
/// dạng TAR là những khối 512 byte với một header văn bản, và hai bộ giải nén đi kèm đều nằm
/// trong `Compression` của hệ điều hành. Vendor một thư viện C để làm thứ đã có sẵn là gánh
/// thêm một phụ thuộc phải theo dõi bản vá bảo mật, đổi lấy không gì.
///
/// Còn lại đúng hai định dạng thật sự cần thư viện ngoài — **RAR và 7z** — và chúng có bộ giải
/// nén riêng không thể viết lại trong vài trăm dòng.
///
/// **BZIP2 chưa làm, và nói ra.** `Compression` không có bzip2. Nó cần một bộ giải nén riêng,
/// nên `.tar.bz2` bị từ chối kèm lý do thay vì mở ra một danh sách rỗng.
public struct TarArchive {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case notATar
        case unsupportedCompression(String)
        case truncated(atOffset: Int)
        case tooLarge(Int)

        public var description: String {
            switch self {
            case .notATar: return "Tệp này không phải kho TAR"
            case .unsupportedCompression(let name):
                return "Chưa giải nén được dạng \(name)"
            case .truncated(let offset): return "Kho TAR đứt đoạn ở byte \(offset)"
            case .tooLarge(let size):
                return "Giải nén ra \(size / 1_048_576) MB — quá lớn để mở trong bộ nhớ"
            }
        }
    }

    public struct Entry: Equatable, Sendable {
        public var path: String
        public var size: Int
        public var modified: Date?
        public var isDirectory: Bool
        /// Offset của phần dữ liệu trong luồng đã giải nén.
        var dataOffset: Int
    }

    public let entries: [Entry]
    private let bytes: [UInt8]

    /// Trần cho cả kho khi giải nén vào bộ nhớ.
    ///
    /// Khác `ZipArchive` — nơi trần áp cho MỘT mục — vì TAR không có mục lục: muốn biết trong
    /// kho có gì thì phải giải nén cả luồng. Đó là bản chất của định dạng, không phải lựa chọn.
    public static let memoryLimit = 512 * 1_048_576

    // MARK: - Mở

    public init(path: String) throws {
        let raw = try MappedFile(path: path)
        let head = raw.withUnsafeBytes { bytes -> [UInt8] in
            [UInt8](UnsafeRawBufferPointer(rebasing: bytes[0 ..< min(512, bytes.count)]))
        }
        let all = raw.withUnsafeBytes { [UInt8]($0) }

        let plain = try Self.decompress(all, head: head)
        guard plain.count >= 512 else { throw Failure.notATar }
        self.bytes = plain
        self.entries = try Self.readEntries(plain)
    }

    /// Giải nén luồng nếu nó nằm trong một lớp nén, hoặc trả nguyên.
    static func decompress(_ data: [UInt8], head: [UInt8]) throws -> [UInt8] {
        if head.count >= 2, head[0] == 0x1F, head[1] == 0x8B {
            return try gunzip(data)
        }
        if head.count >= 6, Array(head[0 ..< 6]) == [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00] {
            return try inflate(data, algorithm: COMPRESSION_LZMA, name: "xz")
        }
        if head.count >= 3, head[0] == 0x42, head[1] == 0x5A, head[2] == 0x68 {
            throw Failure.unsupportedCompression("bzip2")
        }
        return data
    }

    /// Gỡ vỏ gzip rồi giải phần DEFLATE bên trong.
    ///
    /// `Compression` không đọc vỏ gzip — `COMPRESSION_ZLIB` của Apple là DEFLATE trần. Vỏ ấy có
    /// độ dài thay đổi (tên tệp, chú thích, CRC header đều tuỳ chọn), nên phải đọc cờ để biết
    /// nhảy qua bao nhiêu byte. Đoán một con số cố định là cách hỏng với đúng những tệp có ghi
    /// tên gốc bên trong — tức phần lớn tệp do `gzip` tạo ra.
    static func gunzip(_ data: [UInt8]) throws -> [UInt8] {
        guard data.count > 18 else { throw Failure.truncated(atOffset: data.count) }
        let flags = data[3]
        var cursor = 10

        if flags & 0x04 != 0 {                       // FEXTRA
            guard cursor + 2 <= data.count else { throw Failure.truncated(atOffset: cursor) }
            cursor += 2 + Int(data[cursor]) | (Int(data[cursor + 1]) << 8)
        }
        for mask in [UInt8(0x08), UInt8(0x10)] where flags & mask != 0 {   // FNAME, FCOMMENT
            while cursor < data.count, data[cursor] != 0 { cursor += 1 }
            cursor += 1
        }
        if flags & 0x02 != 0 { cursor += 2 }         // FHCRC
        guard cursor < data.count - 8 else { throw Failure.truncated(atOffset: cursor) }

        // Bốn byte cuối của tệp gzip là kích thước gốc — dùng làm cỡ đệm, và đó là con số
        // ĐÁNG NGỜ (tệp có thể nói dối), nên vẫn kẹp theo trần.
        let declared = (0 ..< 4).reduce(0) { $0 | (Int(data[data.count - 4 + $1]) << (8 * $1)) }
        let payload = Array(data[cursor ..< (data.count - 8)])
        return try inflate(payload, algorithm: COMPRESSION_ZLIB, name: "gzip",
                           hint: declared)
    }

    static func inflate(
        _ input: [UInt8], algorithm: compression_algorithm, name: String, hint: Int = 0
    ) throws -> [UInt8] {
        // Không biết trước cỡ thật thì nhân dần lên. Mỗi lần thất bại là một lượt giải nén bỏ
        // đi, nên bắt đầu từ ước lượng của chính tệp khi có.
        var capacity = max(hint, input.count * 4, 64 * 1024)
        while capacity <= Self.memoryLimit {
            var output = [UInt8](repeating: 0, count: capacity)
            let written = input.withUnsafeBufferPointer { source in
                output.withUnsafeMutableBufferPointer { destination in
                    compression_decode_buffer(
                        destination.baseAddress!, capacity,
                        source.baseAddress!, input.count, nil, algorithm)
                }
            }
            if written > 0, written < capacity { return Array(output[0 ..< written]) }
            if written == capacity { capacity *= 2; continue }   // đầy đệm: có thể còn nữa
            guard written == 0 else { return Array(output[0 ..< written]) }
            capacity *= 2
        }
        throw Failure.tooLarge(capacity)
    }

    // MARK: - Đọc mục lục

    static func readEntries(_ data: [UInt8]) throws -> [Entry] {
        var entries: [Entry] = []
        var cursor = 0
        /// Tên dài do GNU tar ghi ở một mục riêng đứng TRƯỚC mục thật.
        var pendingLongName: String?

        while cursor + 512 <= data.count {
            let block = Array(data[cursor ..< cursor + 512])
            // Hai khối 0 liên tiếp là dấu kết thúc kho.
            if block.allSatisfy({ $0 == 0 }) { break }

            guard Self.isTarHeader(block) else {
                guard entries.isEmpty else { break }
                throw Failure.notATar
            }

            // Tên từ header mở rộng (pax hoặc GNU) là đường dẫn TRỌN VẸN. Ghép thêm trường
            // `prefix` của header vào nó sẽ ra một đường dẫn lặp chính nó — và lặp trông vẫn
            // như một đường dẫn thật, nên nó lọt qua mọi phép kiểm "có rỗng không".
            let longName = pendingLongName
            let name = longName ?? Self.string(block, 0, 100)
            let prefix = longName == nil ? Self.string(block, 345, 155) : ""
            let size = Self.octal(block, 124, 12)
            let modified = Self.octal(block, 136, 12)
            let type = block[156]
            pendingLongName = nil

            cursor += 512
            let dataStart = cursor
            let padded = (size + 511) / 512 * 512

            switch type {
            case UInt8(ascii: "L"):
                // GNU long name: nội dung của mục NÀY là tên của mục KẾ TIẾP.
                guard dataStart + size <= data.count else {
                    throw Failure.truncated(atOffset: dataStart)
                }
                pendingLongName = String(
                    decoding: data[dataStart ..< dataStart + size].prefix { $0 != 0 },
                    as: UTF8.self)
            case UInt8(ascii: "x"), UInt8(ascii: "X"):
                // Header mở rộng kiểu **pax** — đây là cách `tar` của macOS (bsdtar) ghi tên
                // dài, KHÔNG phải kiểu `L` của GNU. Bỏ qua nó thì mọi tên trên 100 ký tự hiện
                // ra bị cắt cụt ở đúng ký tự thứ 100, và cắt cụt trông y như một tên thật.
                guard dataStart + size <= data.count else {
                    throw Failure.truncated(atOffset: dataStart)
                }
                if let value = Self.paxValue(
                    "path", in: Array(data[dataStart ..< dataStart + size])) {
                    pendingLongName = value
                }
            case UInt8(ascii: "g"), UInt8(ascii: "K"):
                break                                 // pax toàn cục / vendor: không phải tệp
            default:
                let full = prefix.isEmpty ? name : prefix + "/" + name
                guard !full.isEmpty else { break }
                entries.append(Entry(
                    path: full,
                    size: size,
                    modified: modified > 0 ? Date(timeIntervalSince1970: Double(modified)) : nil,
                    isDirectory: type == UInt8(ascii: "5") || full.hasSuffix("/"),
                    dataOffset: dataStart))
            }
            cursor += padded
        }
        return entries
    }

    /// Giá trị của một khoá trong khối pax.
    ///
    /// Mỗi bản ghi có dạng `"<độ dài> <khoá>=<giá trị>\n"`, và **độ dài tính CẢ chính con số
    /// ấy**. Đọc theo dấu `\n` thay vì theo độ dài sẽ hỏng với giá trị có chứa xuống dòng —
    /// hiếm, nhưng hợp lệ.
    static func paxValue(_ key: String, in block: [UInt8]) -> String? {
        var cursor = 0
        while cursor < block.count {
            var digits = ""
            while cursor < block.count, block[cursor] != UInt8(ascii: " ") {
                digits.append(Character(UnicodeScalar(block[cursor])))
                cursor += 1
            }
            guard let length = Int(digits), length > digits.count, cursor < block.count else {
                return nil
            }
            let recordStart = cursor - digits.count
            let recordEnd = min(recordStart + length, block.count)
            let body = String(decoding: block[(cursor + 1) ..< recordEnd], as: UTF8.self)
            if let equals = body.firstIndex(of: "="), String(body[body.startIndex ..< equals]) == key {
                return String(body[body.index(after: equals)...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            }
            cursor = recordEnd
        }
        return nil
    }

    /// Khối này có phải header TAR không.
    ///
    /// Kiểm bằng CHECKSUM chứ không chỉ bằng chữ ký `ustar`: TAR cổ (v7) không có chữ ký ấy,
    /// và một kho do `tar` của macOS tạo ra vẫn có thể mang header kiểu cũ.
    static func isTarHeader(_ block: [UInt8]) -> Bool {
        guard block.count == 512 else { return false }
        let declared = octal(block, 148, 8)
        guard declared > 0 else { return false }
        var signed = 0
        for (index, byte) in block.enumerated() {
            // Tám byte checksum được coi như dấu cách khi tính.
            signed += (148 ..< 156).contains(index) ? 32 : Int(byte)
        }
        return signed == declared
    }

    static func string(_ block: [UInt8], _ offset: Int, _ length: Int) -> String {
        let slice = block[offset ..< min(offset + length, block.count)].prefix { $0 != 0 }
        return String(decoding: slice, as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)
    }

    static func octal(_ block: [UInt8], _ offset: Int, _ length: Int) -> Int {
        var value = 0
        for index in offset ..< min(offset + length, block.count) {
            let byte = block[index]
            if byte == 0 || byte == UInt8(ascii: " ") {
                if value > 0 { break } else { continue }
            }
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "7") else { break }
            value = value * 8 + Int(byte - UInt8(ascii: "0"))
        }
        return value
    }

    // MARK: - Lấy nội dung

    public func data(for entry: Entry) throws -> [UInt8] {
        guard entry.dataOffset + entry.size <= bytes.count else {
            throw Failure.truncated(atOffset: entry.dataOffset)
        }
        return Array(bytes[entry.dataOffset ..< entry.dataOffset + entry.size])
    }

    public var totalSize: Int { entries.reduce(0) { $0 + $1.size } }
}
