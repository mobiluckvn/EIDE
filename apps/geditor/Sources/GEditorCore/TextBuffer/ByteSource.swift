import Foundation

/// Nguồn byte chỉ-đọc cho piece table (ADR-02).
///
/// Hai hiện thực: `MappedFile` (mmap file gốc — không copy nội dung vào RAM) và
/// `MemoryByteSource` (tài liệu mới hoặc dữ liệu nhỏ trong test).
public protocol ByteSource: AnyObject {
    var count: Int { get }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}

public final class MemoryByteSource: ByteSource {
    private let storage: [UInt8]

    public init(_ bytes: [UInt8]) { self.storage = bytes }
    public convenience init(_ string: String) { self.init(Array(string.utf8)) }

    public var count: Int { storage.count }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withUnsafeBytes(body)
    }
}

/// File ánh xạ bộ nhớ — nền tảng của Large File Mode (FR-DOC-310, NFR-PERF-03).
///
/// Không đọc file vào chuỗi liên tục (cấm bởi SRS §3.4): trang nhớ được kernel nạp
/// theo nhu cầu, nên mở file 1–4 GB không tốn RAM tương ứng.
public final class MappedFile: ByteSource {
    public enum Failure: Error, CustomStringConvertible {
        case cannotOpen(path: String, errno: Int32)
        case cannotStat(path: String, errno: Int32)
        case cannotMap(path: String, errno: Int32)

        public var description: String {
            switch self {
            case .cannotOpen(let p, let e): return "Không mở được \(p): \(String(cString: strerror(e)))"
            case .cannotStat(let p, let e): return "Không đọc được thuộc tính \(p): \(String(cString: strerror(e)))"
            case .cannotMap(let p, let e): return "Không ánh xạ được \(p): \(String(cString: strerror(e)))"
            }
        }
    }

    public let path: String
    public let count: Int
    private let fd: Int32
    private let base: UnsafeRawPointer?

    public init(path: String) throws {
        self.path = path

        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { throw Failure.cannotOpen(path: path, errno: errno) }

        var st = stat()
        guard fstat(fd, &st) == 0 else {
            let e = errno
            close(fd)
            throw Failure.cannotStat(path: path, errno: e)
        }

        let size = Int(st.st_size)
        self.fd = fd
        self.count = size

        if size == 0 {
            // mmap độ dài 0 là lỗi trên BSD — file rỗng vẫn phải mở được.
            self.base = nil
            return
        }

        guard let p = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0), p != MAP_FAILED else {
            let e = errno
            close(fd)
            throw Failure.cannotMap(path: path, errno: e)
        }
        self.base = UnsafeRawPointer(p)

        // Gợi ý kernel: buffer văn bản chủ yếu được quét tuần tự khi dựng line index.
        madvise(UnsafeMutableRawPointer(mutating: p), size, MADV_SEQUENTIAL)
    }

    deinit {
        if let base, count > 0 {
            munmap(UnsafeMutableRawPointer(mutating: base), count)
        }
        close(fd)
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        guard let base, count > 0 else {
            return try body(UnsafeRawBufferPointer(start: nil, count: 0))
        }
        return try body(UnsafeRawBufferPointer(start: base, count: count))
    }
}
