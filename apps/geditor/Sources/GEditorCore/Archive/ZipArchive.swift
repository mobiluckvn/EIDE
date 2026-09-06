import Compression
import Foundation

/// Đọc file ZIP — nền cho cả hai việc: duyệt file nén, và đọc OOXML.
///
/// **Vì sao tự viết thay vì gọi thư viện.** `.docx`, `.xlsx`, `.pptx` đều LÀ file ZIP, nên một
/// bộ đọc ZIP đúng đắn mở ra cả hai tính năng bằng cùng một khối mã. Còn về phía thư viện:
/// macOS không có API ZIP công khai nào. `/usr/lib/libarchive` thì có, nhưng nó không nằm trong
/// SDK — Apple đổi hay bỏ lúc nào cũng được, và đó là rủi ro không đáng cho bản App Store
/// (xem [[geditor-muc-tieu-app-store]]). Phần giải nén thật thì KHÔNG tự viết: `Compression`
/// của hệ điều hành làm DEFLATE, và đó là API công khai.
///
/// **Không nạp cả file vào RAM.** Dùng `MappedFile` như phần còn lại của lõi (ADR-02): một
/// `.zip` 4 GB phải duyệt được mà không tốn 4 GB. Chỉ khi người dùng xin ĐÚNG một mục thì mục
/// ấy mới được giải nén, và chỉ mục ấy.
///
/// **Đọc thư mục trung tâm, không quét tuần tự.** Cuối file ZIP có một bảng mục lục
/// (central directory) kê mọi mục kèm offset. Quét từ đầu file theo local header cũng ra danh
/// sách, nhưng nó sai ở đúng chỗ khó thấy: mục đã XOÁ khỏi mục lục vẫn còn nguyên phần dữ liệu
/// trong file, nên lối quét sẽ liệt kê những thứ mà mọi công cụ khác coi là không tồn tại.
public struct ZipArchive {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case notAZip(path: String)
        case truncated(atOffset: Int)
        case unsupportedMethod(entry: String, method: UInt16)
        case encrypted(entry: String)
        case crcMismatch(entry: String, expected: UInt32, actual: UInt32)
        case tooLargeToExtract(entry: String, size: Int)
        case unsafePath(entry: String)

        public var description: String {
            switch self {
            case .notAZip(let path):
                return "\((path as NSString).lastPathComponent) không phải file ZIP"
            case .truncated(let offset):
                return "File nén đứt đoạn ở byte \(offset)"
            case .unsupportedMethod(let entry, let method):
                return "«\(entry)» nén bằng phương pháp \(method), bộ đọc này chỉ hiểu"
                    + " «không nén» và «deflate»"
            case .encrypted(let entry):
                return "«\(entry)» có mật khẩu — bộ đọc này không giải mã"
            case .crcMismatch(let entry, let expected, let actual):
                return "«\(entry)» sai mã kiểm tra (CRC): mong \(expected), thực tế \(actual)"
            case .tooLargeToExtract(let entry, let size):
                return "«\(entry)» giải nén ra \(size / 1_048_576) MB — quá lớn để mở trong bộ nhớ"
            case .unsafePath(let entry):
                return "«\(entry)» có đường dẫn thoát ra ngoài thư mục đích"
            }
        }
    }

    /// Trần cho MỘT mục giải nén vào bộ nhớ.
    ///
    /// Đây là hàng rào chống "zip bomb": một file nén 1 MB có thể khai ra hàng chục GB, và
    /// không có trần thì lệnh xem trước một mục sẽ giết cả ứng dụng. 512 MB đủ rộng cho mọi
    /// tài liệu thật và vẫn còn xa mức làm máy nghẹt.
    public static let extractionLimit = 512 * 1_048_576

    public enum Method: UInt16, Equatable, Sendable {
        case stored = 0
        case deflate = 8
    }

    public struct Entry: Equatable, Sendable {
        /// Đường dẫn NGUYÊN VĂN như ghi trong file nén, chưa làm sạch.
        public var path: String
        public var compressedSize: Int
        public var uncompressedSize: Int
        public var method: Method
        public var crc32: UInt32
        public var modified: Date?
        public var isEncrypted: Bool
        /// Offset của local file header, cần để tìm chỗ dữ liệu bắt đầu.
        var localHeaderOffset: Int

        /// Mục thư mục — ZIP đánh dấu bằng dấu `/` ở cuối tên, không bằng cờ nào cả.
        public var isDirectory: Bool { path.hasSuffix("/") }

        /// Tỉ lệ nén, để hiện trong bảng. `nil` khi mục rỗng — chia cho 0.
        public var ratio: Double? {
            guard uncompressedSize > 0 else { return nil }
            return Double(compressedSize) / Double(uncompressedSize)
        }
    }

    public let path: String
    public let entries: [Entry]
    private let source: MappedFile

    /// Tổng kích thước sau khi giải nén — dùng cho dòng tóm tắt.
    public var totalUncompressedSize: Int {
        entries.reduce(0) { $0 + $1.uncompressedSize }
    }

    // MARK: - Mở

    public init(path: String) throws {
        let source = try MappedFile(path: path)
        self.path = path
        self.source = source
        self.entries = try source.withUnsafeBytes { bytes in
            try ZipArchive.readCentralDirectory(bytes, path: path)
        }
    }

    /// Nhận ra file ZIP bằng NỘI DUNG, không bằng đuôi tệp.
    ///
    /// Đuôi tệp nói lên ý định, không nói lên sự thật: `.docx` là ZIP, `.zip` tải dở thì không.
    /// Bốn byte đầu là đủ và rẻ.
    public static func looksLikeZip(_ head: [UInt8]) -> Bool {
        // "PK\3\4" mục thường · "PK\5\6" file rỗng · "PK\7\8" bản chia nhiều tệp.
        guard head.count >= 4, head[0] == 0x50, head[1] == 0x4B else { return false }
        return (head[2] == 3 && head[3] == 4)
            || (head[2] == 5 && head[3] == 6)
            || (head[2] == 7 && head[3] == 8)
    }

    // MARK: - Lấy nội dung một mục

    /// Giải nén ĐÚNG một mục ra bộ nhớ.
    public func data(for entry: Entry) throws -> [UInt8] {
        guard !entry.isEncrypted else { throw Failure.encrypted(entry: entry.path) }
        guard entry.uncompressedSize <= Self.extractionLimit else {
            throw Failure.tooLargeToExtract(entry: entry.path, size: entry.uncompressedSize)
        }

        let raw: [UInt8] = try source.withUnsafeBytes { bytes in
            let start = try Self.dataOffset(of: entry, in: bytes)
            guard start + entry.compressedSize <= bytes.count else {
                throw Failure.truncated(atOffset: start)
            }
            return [UInt8](UnsafeRawBufferPointer(
                rebasing: bytes[start ..< start + entry.compressedSize]))
        }

        let out: [UInt8]
        switch entry.method {
        case .stored:
            out = raw
        case .deflate:
            out = try Self.inflate(raw, expecting: entry.uncompressedSize, entry: entry.path)
        }

        // Kiểm CRC — đây là ĐỐI CHỨNG, không phải trang trí. Một file nén hỏng nửa chừng vẫn
        // giải ra được một mảng byte trông như dữ liệu; CRC là thứ duy nhất nói nó sai.
        // Ngoại lệ: mục rỗng và mục thư mục có CRC 0 hợp lệ.
        if !out.isEmpty || entry.crc32 != 0 {
            let actual = CRC32.compute(out)
            guard actual == entry.crc32 else {
                throw Failure.crcMismatch(entry: entry.path, expected: entry.crc32, actual: actual)
            }
        }
        return out
    }

    /// Lấy một mục theo tên — lối dùng của bộ đọc OOXML (`word/document.xml`…).
    public func data(named name: String) throws -> [UInt8]? {
        guard let entry = entries.first(where: { $0.path == name }) else { return nil }
        return try data(for: entry)
    }

    // MARK: - Đường dẫn an toàn khi bung ra đĩa

    /// Đường dẫn đã làm sạch để ghi ra đĩa, hoặc `nil` nếu nó không an toàn.
    ///
    /// **Zip Slip.** Một mục tên `../../../../etc/passwd` sẽ ghi RA NGOÀI thư mục đích nếu cứ
    /// nối chuỗi. Lỗi này có tên riêng vì nó đã hạ hàng loạt phần mềm thật. Cách chặn duy nhất
    /// đáng tin: chuẩn hoá đường dẫn rồi ĐÒI nó vẫn nằm trong thư mục đích — chứ không phải lọc
    /// chuỗi `..`, vì còn `..\` trên Windows, `%2e%2e`, và đường dẫn tuyệt đối.
    public static func safeDestination(for entryPath: String, under directory: String) -> String? {
        // Dấu `\` là dấu phân cách của Windows và nhiều bộ nén ghi nó vào ZIP. Không đổi thì
        // `..\..\x` lọt qua mọi phép kiểm dựa trên `/`.
        let normalized = entryPath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/") else { return nil }

        let base = (directory as NSString).standardizingPath
        let joined = (base as NSString).appendingPathComponent(normalized)
        let resolved = (joined as NSString).standardizingPath

        // `standardizingPath` đã gộp hết `.` và `..`. Sau khi gộp, đích phải còn nằm trong gốc.
        guard resolved == base || resolved.hasPrefix(base + "/") else { return nil }
        return resolved
    }

    // MARK: - Đọc thư mục trung tâm

    private static func readCentralDirectory(
        _ bytes: UnsafeRawBufferPointer, path: String
    ) throws -> [Entry] {
        guard bytes.count >= 22 else { throw Failure.notAZip(path: path) }
        guard let eocd = findEOCD(bytes) else { throw Failure.notAZip(path: path) }

        var count = Int(read16(bytes, eocd + 10))
        var directoryOffset = Int(read32(bytes, eocd + 16))
        var directorySize = Int(read32(bytes, eocd + 12))

        // ZIP64: khi số mục hoặc offset vượt trần 32 bit, ba trường trên bị đặt thành 0xFFFF /
        // 0xFFFFFFFF và giá trị thật nằm trong bản ghi ZIP64. Bỏ qua nhánh này thì mọi file nén
        // trên 4 GB đều "không phải ZIP" — mà GEditor là công cụ cho file cỡ Gigabyte.
        if count == 0xFFFF || directoryOffset == 0xFFFF_FFFF || directorySize == 0xFFFF_FFFF {
            if let z64 = findZip64EOCD(bytes, near: eocd) {
                count = Int(read64(bytes, z64 + 32))
                directorySize = Int(read64(bytes, z64 + 40))
                directoryOffset = Int(read64(bytes, z64 + 48))
            }
        }

        guard directoryOffset >= 0, directoryOffset + directorySize <= bytes.count else {
            throw Failure.truncated(atOffset: directoryOffset)
        }

        var entries: [Entry] = []
        entries.reserveCapacity(min(count, 4096))
        var cursor = directoryOffset

        while entries.count < count, cursor + 46 <= bytes.count {
            guard read32(bytes, cursor) == 0x0201_4B50 else { break }

            let flags = read16(bytes, cursor + 8)
            let rawMethod = read16(bytes, cursor + 10)
            let crc = read32(bytes, cursor + 16)
            var compressed = Int(read32(bytes, cursor + 20))
            var uncompressed = Int(read32(bytes, cursor + 24))
            let nameLength = Int(read16(bytes, cursor + 28))
            let extraLength = Int(read16(bytes, cursor + 30))
            let commentLength = Int(read16(bytes, cursor + 32))
            var localOffset = Int(read32(bytes, cursor + 42))
            let dosTime = read16(bytes, cursor + 12)
            let dosDate = read16(bytes, cursor + 14)

            let nameStart = cursor + 46
            guard nameStart + nameLength <= bytes.count else {
                throw Failure.truncated(atOffset: nameStart)
            }
            let nameBytes = [UInt8](UnsafeRawBufferPointer(
                rebasing: bytes[nameStart ..< nameStart + nameLength]))

            // Bit 11 = tên đã là UTF-8. Không có bit ấy thì chuẩn nói là CP437; nhưng phần lớn
            // bộ nén hiện đại ghi UTF-8 mà quên bật bit, nên thử UTF-8 TRƯỚC rồi mới lùi về
            // CP437. Lùi thẳng về CP437 sẽ làm mọi tên tiếng Việt thành ký tự lạ.
            let name: String
            if flags & 0x800 != 0 {
                name = String(decoding: nameBytes, as: UTF8.self)
            } else {
                name = String(bytes: nameBytes, encoding: .utf8)
                    ?? String(bytes: nameBytes, encoding: .windowsCP1252)
                    ?? String(decoding: nameBytes, as: UTF8.self)
            }

            // ZIP64 cho từng mục: giá trị thật nằm trong vùng extra, thẻ 0x0001. Thứ tự các
            // trường trong thẻ ấy là THEO NHU CẦU — chỉ trường nào bị tràn mới có mặt.
            let extraStart = nameStart + nameLength
            if uncompressed == 0xFFFF_FFFF || compressed == 0xFFFF_FFFF
                || localOffset == 0xFFFF_FFFF {
                var p = extraStart
                let extraEnd = min(extraStart + extraLength, bytes.count)
                while p + 4 <= extraEnd {
                    let tag = read16(bytes, p)
                    let size = Int(read16(bytes, p + 2))
                    var q = p + 4
                    if tag == 0x0001 {
                        if uncompressed == 0xFFFF_FFFF, q + 8 <= extraEnd {
                            uncompressed = Int(read64(bytes, q)); q += 8
                        }
                        if compressed == 0xFFFF_FFFF, q + 8 <= extraEnd {
                            compressed = Int(read64(bytes, q)); q += 8
                        }
                        if localOffset == 0xFFFF_FFFF, q + 8 <= extraEnd {
                            localOffset = Int(read64(bytes, q))
                        }
                        break
                    }
                    p += 4 + size
                }
            }

            let method = Method(rawValue: rawMethod)
            guard let method else {
                throw Failure.unsupportedMethod(entry: name, method: rawMethod)
            }

            entries.append(Entry(
                path: name,
                compressedSize: compressed,
                uncompressedSize: uncompressed,
                method: method,
                crc32: crc,
                modified: dosDateTime(date: dosDate, time: dosTime),
                isEncrypted: flags & 0x0001 != 0,
                localHeaderOffset: localOffset))

            cursor = extraStart + extraLength + commentLength
        }

        return entries
    }

    /// Chạy `body` với vùng byte của cả tệp và offset chỗ dữ liệu của một mục bắt đầu.
    ///
    /// Có mặt cho `ZipWriter`: nó cần đúng vùng byte ĐÃ NÉN, và `dataOffset` thì riêng tư vì nó
    /// chỉ có nghĩa bên trong một lượt `withUnsafeBytes`.
    func withDataOffset<R>(
        of entry: Entry, _ body: (UnsafeRawBufferPointer, Int) throws -> R
    ) throws -> R {
        try source.withUnsafeBytes { bytes in
            let start = try Self.dataOffset(of: entry, in: bytes)
            return try body(bytes, start)
        }
    }

    /// Chỗ dữ liệu của một mục bắt đầu.
    ///
    /// Phải đọc local header mới biết, vì độ dài phần `extra` ở local header **khác** với ở
    /// mục lục — chuẩn cho phép hai chỗ ghi khác nhau, và nhiều bộ nén dùng đúng quyền ấy. Lấy
    /// độ dài từ mục lục là lỗi kinh điển, và nó chỉ lộ ra với vài file.
    private static func dataOffset(
        of entry: Entry, in bytes: UnsafeRawBufferPointer
    ) throws -> Int {
        let header = entry.localHeaderOffset
        guard header + 30 <= bytes.count, read32(bytes, header) == 0x0403_4B50 else {
            throw Failure.truncated(atOffset: header)
        }
        let nameLength = Int(read16(bytes, header + 26))
        let extraLength = Int(read16(bytes, header + 28))
        return header + 30 + nameLength + extraLength
    }

    /// Tìm bản ghi kết thúc mục lục, quét NGƯỢC từ cuối file.
    ///
    /// Phải quét ngược vì bản ghi ấy có phần chú thích độ dài tuỳ ý ở đuôi, nên vị trí của nó
    /// không tính được. Chú thích tối đa 65.535 byte nên chỉ cần soi ngần ấy cộng 22.
    private static func findEOCD(_ bytes: UnsafeRawBufferPointer) -> Int? {
        let limit = max(0, bytes.count - 65_557)
        var i = bytes.count - 22
        while i >= limit {
            if read32(bytes, i) == 0x0605_4B50 { return i }
            i -= 1
        }
        return nil
    }

    private static func findZip64EOCD(_ bytes: UnsafeRawBufferPointer, near eocd: Int) -> Int? {
        // Ngay trước EOCD là "ZIP64 end of central directory locator" (20 byte), trong đó có
        // offset của bản ghi ZIP64 thật.
        let locator = eocd - 20
        guard locator >= 0, read32(bytes, locator) == 0x0706_4B50 else { return nil }
        let offset = Int(read64(bytes, locator + 8))
        guard offset >= 0, offset + 56 <= bytes.count,
              read32(bytes, offset) == 0x0606_4B50 else { return nil }
        return offset
    }

    // MARK: - Giải nén

    private static func inflate(
        _ input: [UInt8], expecting size: Int, entry: String
    ) throws -> [UInt8] {
        guard size > 0 else { return [] }
        var output = [UInt8](repeating: 0, count: size)
        let written = input.withUnsafeBufferPointer { src in
            output.withUnsafeMutableBufferPointer { dst in
                // `COMPRESSION_ZLIB` của Apple là DEFLATE TRẦN (không có header zlib) — đúng
                // thứ ZIP chứa. Tên gọi dễ gây nhầm, đã kiểm bằng bài kiểm vòng tròn.
                compression_decode_buffer(
                    dst.baseAddress!, size,
                    src.baseAddress!, input.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else {
            throw Failure.crcMismatch(entry: entry, expected: UInt32(size), actual: UInt32(written))
        }
        return output
    }

    // MARK: - Đọc số nhỏ

    private static func read16(_ b: UnsafeRawBufferPointer, _ i: Int) -> UInt16 {
        guard i + 2 <= b.count else { return 0 }
        return UInt16(b[i]) | (UInt16(b[i + 1]) << 8)
    }

    private static func read32(_ b: UnsafeRawBufferPointer, _ i: Int) -> UInt32 {
        guard i + 4 <= b.count else { return 0 }
        return UInt32(b[i]) | (UInt32(b[i + 1]) << 8)
            | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
    }

    private static func read64(_ b: UnsafeRawBufferPointer, _ i: Int) -> UInt64 {
        guard i + 8 <= b.count else { return 0 }
        var v: UInt64 = 0
        for k in (0 ..< 8).reversed() { v = (v << 8) | UInt64(b[i + k]) }
        return v
    }

    /// Giờ sửa đổi kiểu MS-DOS — hai số 16 bit, gốc thời gian là 1980.
    private static func dosDateTime(date: UInt16, time: UInt16) -> Date? {
        guard date != 0 else { return nil }
        var parts = DateComponents()
        parts.year = 1980 + Int((date >> 9) & 0x7F)
        parts.month = Int((date >> 5) & 0x0F)
        parts.day = Int(date & 0x1F)
        parts.hour = Int((time >> 11) & 0x1F)
        parts.minute = Int((time >> 5) & 0x3F)
        parts.second = Int(time & 0x1F) * 2
        return Calendar(identifier: .gregorian).date(from: parts)
    }
}

/// CRC-32 (đa thức IEEE) — thứ ZIP dùng để nói một mục có nguyên vẹn không.
///
/// Tự viết vì Foundation không có, và vì nó là **đối chứng**: không có nó thì một file nén hỏng
/// vẫn giải ra một mảng byte trông như dữ liệu, và lỗi chỉ lộ ra ở chỗ nào đó xa hơn nhiều.
public enum CRC32 {
    private static let table: [UInt32] = {
        (0 ..< 256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0 ..< 8 {
                c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    public static func compute(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFF_FFFF
    }
}
