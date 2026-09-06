import Compression
import Foundation

/// Ghi lại một file ZIP, **thay đúng vài mục và chép nguyên phần còn lại**.
///
/// **Vì sao không dựng lại từ đầu.** Một tệp `.xlsx` có hàng chục phần: định dạng, biểu đồ,
/// ảnh nhúng, bảng tính khác, thuộc tính tài liệu, chữ ký số. Dựng lại tệp từ những gì bộ đọc
/// hiểu được nghĩa là **vứt đi mọi thứ nó không hiểu** — và bộ đọc này cố ý chỉ hiểu giá trị ô.
/// Chép nguyên byte đã nén của các mục không đụng tới là cách duy nhất giữ được phần ấy, kể cả
/// những phần ta không biết tên.
///
/// **Chép byte ĐÃ NÉN, không giải rồi nén lại.** Nhanh hơn nhiều, và tránh hẳn một loại sai:
/// nén lại bằng tham số khác cho ra byte khác, nên một tệp "không sửa gì" vẫn khác bản gốc.
///
/// **Không ghi đè bản gốc.** Lớp này chỉ ghi ra một đường dẫn MỚI. Việc thay thế tệp cũ (nếu
/// người dùng xin) thuộc về lớp trên và phải đi qua `AtomicFileWriter` — cùng lối "không đụng
/// bản gốc" mà chú thích PDF đang dùng.
public enum ZipWriter {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case encryptedEntry(String)
        case cannotWrite(path: String)
        case entryTooLarge(String)

        public var description: String {
            switch self {
            case .encryptedEntry(let name):
                return "«\(name)» có mật khẩu — không ghi lại được tệp có mục mã hoá"
            case .cannotWrite(let path):
                return "Không ghi được \((path as NSString).lastPathComponent)"
            case .entryTooLarge(let name):
                return "«\(name)» quá lớn để ghi lại"
            }
        }
    }

    /// Ghi `source` ra `destination`, thay nội dung những mục có tên trong `replacing`.
    ///
    /// Mục có tên trong `replacing` mà KHÔNG có trong tệp gốc sẽ được **thêm mới** — cần cho ca
    /// một sheet chưa từng có phần nào đó.
    public static func rewrite(
        _ source: ZipArchive, replacing: [String: [UInt8]], to destination: String
    ) throws {
        var out = [UInt8]()
        var directory = [UInt8]()
        var count = 0

        // Mục mã hoá: từ chối NGAY, trước khi ghi một byte nào. Ghi được nửa tệp rồi mới bỏ
        // cuộc là để lại một tệp hỏng ở chỗ người dùng vừa chọn.
        for entry in source.entries where entry.isEncrypted && replacing[entry.path] == nil {
            throw Failure.encryptedEntry(entry.path)
        }

        for entry in source.entries {
            let offset = out.count
            if let replacement = replacing[entry.path] {
                let written = try append(&out, name: entry.path, body: replacement,
                                         isDirectory: entry.isDirectory)
                appendDirectoryEntry(
                    &directory, name: entry.path, offset: offset,
                    crc: written.crc, compressed: written.compressed,
                    uncompressed: replacement.count, method: written.method)
            } else {
                // Chép nguyên: lấy đúng vùng byte đã nén trong tệp gốc.
                guard let raw = try source.rawBytes(of: entry) else { continue }
                appendLocalHeader(
                    &out, name: entry.path, crc: entry.crc32,
                    compressed: raw.count, uncompressed: entry.uncompressedSize,
                    method: entry.method.rawValue)
                out.append(contentsOf: raw)
                appendDirectoryEntry(
                    &directory, name: entry.path, offset: offset,
                    crc: entry.crc32, compressed: raw.count,
                    uncompressed: entry.uncompressedSize,
                    method: entry.method.rawValue)
            }
            count += 1
        }

        // Mục mới hoàn toàn.
        let existing = Set(source.entries.map(\.path))
        for (name, body) in replacing.sorted(by: { $0.key < $1.key }) where !existing.contains(name) {
            let offset = out.count
            let written = try append(&out, name: name, body: body, isDirectory: false)
            appendDirectoryEntry(
                &directory, name: name, offset: offset, crc: written.crc,
                compressed: written.compressed, uncompressed: body.count,
                method: written.method)
            count += 1
        }

        let directoryOffset = out.count
        out.append(contentsOf: directory)
        put32(&out, 0x0605_4B50)
        put16(&out, 0); put16(&out, 0)
        put16(&out, UInt16(min(count, 0xFFFF))); put16(&out, UInt16(min(count, 0xFFFF)))
        put32(&out, UInt32(directory.count)); put32(&out, UInt32(directoryOffset))
        put16(&out, 0)

        // Ghi NGUYÊN TỬ: hoặc tệp mới đủ, hoặc không có tệp nào. Ghi thẳng mà mất điện giữa
        // chừng thì người dùng còn lại một tệp `.xlsx` cụt — mở không được, và trông y như
        // một tệp thật.
        do {
            try AtomicFileWriter.write(out, to: destination)
        } catch {
            throw Failure.cannotWrite(path: destination)
        }
    }

    // MARK: - Ghi từng phần

    /// Kết quả ghi một mục — TRẢ VỀ chứ không để lại ở một biến tĩnh.
    ///
    /// Bản đầu dùng một `static var lastMethod` rồi đọc ngay sau khi gọi. Nó chạy đúng, và nó
    /// là loại mã sẽ hỏng ngay lần đầu có ai ghi hai tệp song song — kiểu hỏng không tái hiện
    /// được và không ai nghi ngờ dòng nào.
    private struct Written {
        var crc: UInt32
        var compressed: Int
        var method: UInt16
    }

    private static func append(
        _ out: inout [UInt8], name: String, body: [UInt8], isDirectory: Bool
    ) throws -> Written {
        guard body.count < 0xFFFF_FFFF else { throw Failure.entryTooLarge(name) }
        let crc = CRC32.compute(body)

        // Nén xong mà không nhỏ đi thì CẤT NGUYÊN. Với phần đã nén sẵn (ảnh PNG trong `.docx`)
        // deflate còn làm nó to ra.
        var payload = body
        var method: UInt16 = 0
        if !isDirectory, let deflated = deflate(body), deflated.count < body.count {
            payload = deflated
            method = 8
        }

        appendLocalHeader(
            &out, name: name, crc: crc,
            compressed: payload.count, uncompressed: body.count, method: method)
        out.append(contentsOf: payload)
        return Written(crc: crc, compressed: payload.count, method: method)
    }

    private static func appendLocalHeader(
        _ out: inout [UInt8], name: String, crc: UInt32,
        compressed: Int, uncompressed: Int, method: UInt16
    ) {
        let nameBytes = Array(name.utf8)
        put32(&out, 0x0403_4B50)
        put16(&out, 20)
        put16(&out, 0x0800)                    // tên là UTF-8
        put16(&out, method)
        put16(&out, 0); put16(&out, 0)         // giờ · ngày
        put32(&out, crc)
        put32(&out, UInt32(compressed)); put32(&out, UInt32(uncompressed))
        put16(&out, UInt16(nameBytes.count))
        // KHÔNG chép vùng `extra` của bản gốc: nó có thể chứa ZIP64 với kích thước cũ, và một
        // vùng extra nói khác header là tệp hỏng theo cách khó tìm nhất.
        put16(&out, 0)
        out.append(contentsOf: nameBytes)
    }

    private static func appendDirectoryEntry(
        _ directory: inout [UInt8], name: String, offset: Int, crc: UInt32,
        compressed: Int, uncompressed: Int, method: UInt16
    ) {
        let nameBytes = Array(name.utf8)
        put32(&directory, 0x0201_4B50)
        put16(&directory, 20); put16(&directory, 20)
        put16(&directory, 0x0800)
        put16(&directory, method)
        put16(&directory, 0); put16(&directory, 0)
        put32(&directory, crc)
        put32(&directory, UInt32(compressed)); put32(&directory, UInt32(uncompressed))
        put16(&directory, UInt16(nameBytes.count))
        put16(&directory, 0); put16(&directory, 0)     // extra · comment
        put16(&directory, 0); put16(&directory, 0)     // đĩa · thuộc tính trong
        put32(&directory, name.hasSuffix("/") ? 0x10 : 0)
        put32(&directory, UInt32(offset))
        directory.append(contentsOf: nameBytes)
    }

    private static func deflate(_ input: [UInt8]) -> [UInt8]? {
        guard !input.isEmpty else { return [] }
        var output = [UInt8](repeating: 0, count: input.count + 64)
        let written = input.withUnsafeBufferPointer { src in
            output.withUnsafeMutableBufferPointer { dst in
                compression_encode_buffer(
                    dst.baseAddress!, dst.count,
                    src.baseAddress!, input.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return Array(output[0 ..< written])
    }

    private static func put16(_ out: inout [UInt8], _ value: UInt16) {
        out.append(UInt8(value & 0xFF)); out.append(UInt8((value >> 8) & 0xFF))
    }

    private static func put32(_ out: inout [UInt8], _ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            out.append(UInt8((value >> UInt32(shift)) & 0xFF))
        }
    }
}

extension ZipArchive {
    /// Byte ĐÃ NÉN của một mục, đúng như nằm trong tệp.
    ///
    /// Có mặt để `ZipWriter` chép nguyên những mục không đụng tới. Giải nén rồi nén lại cũng ra
    /// một tệp mở được, nhưng nó tốn thời gian gấp bội và đổi byte của những phần lẽ ra không
    /// đổi — trong đó có thể có phần đang được một chữ ký số bảo vệ.
    func rawBytes(of entry: Entry) throws -> [UInt8]? {
        try withDataOffset(of: entry) { bytes, start in
            guard start + entry.compressedSize <= bytes.count else { return nil }
            return [UInt8](UnsafeRawBufferPointer(
                rebasing: bytes[start ..< start + entry.compressedSize]))
        }
    }
}
