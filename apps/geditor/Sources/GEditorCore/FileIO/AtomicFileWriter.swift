import Foundation

/// Ghi file nguyên tử: temp + fsync + rename (NFR-REL-02).
///
/// BẤT BIẾN KIẾN TRÚC — mọi đường lưu của sản phẩm phải đi qua đây. Không nơi nào
/// được ghi đè trực tiếp lên file đích: tiến trình bị kill hoặc đĩa đầy giữa chừng
/// phải để lại file gốc NGUYÊN VẸN (TC-DOC-02).
///
/// Trình tự:
///   1. Ghi vào file tạm CÙNG THƯ MỤC đích (rename chỉ nguyên tử trong cùng volume).
///   2. fsync(fd) — ép dữ liệu xuống đĩa trước khi đổi tên.
///   3. Sao chép quyền, chủ sở hữu, xattr, tag Finder từ file gốc.
///   4. rename() — nguyên tử ở mức hệ thống file.
public enum AtomicFileWriter {

    public enum Failure: Error, CustomStringConvertible {
        case cannotCreateTemp(directory: String, errno: Int32)
        case writeFailed(errno: Int32)
        case syncFailed(errno: Int32)
        case renameFailed(errno: Int32)

        public var description: String {
            switch self {
            case .cannotCreateTemp(let dir, let e):
                return "Không tạo được file tạm trong \(dir): \(String(cString: strerror(e)))"
            case .writeFailed(let e): return "Ghi thất bại: \(String(cString: strerror(e)))"
            case .syncFailed(let e): return "Đồng bộ đĩa thất bại: \(String(cString: strerror(e)))"
            case .renameFailed(let e): return "Đổi tên thất bại: \(String(cString: strerror(e)))"
            }
        }
    }

    /// Ghi `bytes` vào `path` một cách nguyên tử.
    public static func write(_ bytes: [UInt8], to path: String) throws {
        try write(to: path) { fd in
            try bytes.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let written = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                    if written < 0 {
                        if errno == EINTR { continue }
                        throw Failure.writeFailed(errno: errno)
                    }
                    offset += written
                }
            }
        }
    }

    /// Ghi nguyên tử với nội dung do `body` sinh ra theo từng đoạn (dùng cho file lớn:
    /// nội dung được stream thẳng từ piece table, không dựng chuỗi liên tục trong RAM).
    public static func write(to path: String, _ body: (Int32) throws -> Void) throws {
        // NFR-REL-04: trên iCloud Drive và ổ mạng, phép ghi phải đi qua `NSFileCoordinator`.
        //
        // iCloud có tiến trình `bird` đọc/ghi cùng file; ghi thẳng thì hai bên có thể chồng lên
        // nhau và bản thua là bản của người dùng. Điều phối là cách hệ điều hành cho ta nói
        // "tôi sắp ghi, đừng đụng vào".
        //
        // Chỉ trả giá khi CẦN: ổ cục bộ — trường hợp áp đảo — đi thẳng như cũ, vì điều phối tốn
        // một vòng qua tiến trình khác cho mỗi lần lưu.
        guard !VolumeKind.of(path: path).needsCoordination else {
            return try writeCoordinated(to: path, body)
        }
        try writeDirectly(to: path, body)
    }

    /// Ghi qua `NSFileCoordinator` — cùng một thân hàm, chỉ khác chỗ nó chạy.
    ///
    /// `coordinate` chạy khối lệnh ĐỒNG BỘ trên luồng gọi, nên lỗi ném ra từ bên trong vẫn ra
    /// tới đây được — miễn là bắt lại qua một biến, vì chữ ký của nó không cho `throws` đi qua.
    private static func writeCoordinated(to path: String, _ body: (Int32) throws -> Void) throws {
        let coordinator = NSFileCoordinator()
        var thrown: Error?
        var coordinationError: NSError?
        coordinator.coordinate(
            writingItemAt: URL(fileURLWithPath: path), options: .forReplacing,
            error: &coordinationError
        ) { url in
            do { try writeDirectly(to: url.path, body) } catch { thrown = error }
        }
        if let thrown { throw thrown }
        if let coordinationError { throw coordinationError }
    }

    private static func writeDirectly(to path: String, _ body: (Int32) throws -> Void) throws {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent().path

        var template = Array("\(directory)/.geditor-XXXXXX".utf8CString)
        let fd = template.withUnsafeMutableBufferPointer { mkstemp($0.baseAddress!) }
        guard fd >= 0 else {
            throw Failure.cannotCreateTemp(directory: directory, errno: errno)
        }
        let tempPath = String(cString: template)

        func cleanUp() {
            close(fd)
            unlink(tempPath)
        }

        do {
            try body(fd)
        } catch {
            cleanUp()
            throw error
        }

        // fsync TRƯỚC rename: rename nguyên tử về metadata, nhưng dữ liệu chưa xuống
        // đĩa thì mất điện vẫn cho ra file rỗng/cụt.
        guard fsync(fd) == 0 else {
            let e = errno
            cleanUp()
            throw Failure.syncFailed(errno: e)
        }
        close(fd)

        preserveMetadata(from: path, to: tempPath)

        guard rename(tempPath, path) == 0 else {
            let e = errno
            unlink(tempPath)
            throw Failure.renameFailed(errno: e)
        }
    }

    /// Sao chép quyền / chủ sở hữu / extended attributes / tag Finder từ file gốc.
    ///
    /// Bỏ qua khi file đích chưa tồn tại (lưu lần đầu) — file tạm giữ quyền mặc định 0600
    /// của mkstemp, cần nới về 0644 & umask cho đúng kỳ vọng người dùng.
    private static func preserveMetadata(from original: String, to temp: String) {
        var st = stat()
        if stat(original, &st) == 0 {
            chmod(temp, st.st_mode & 0o7777)
            chown(temp, st.st_uid, st.st_gid)
            copyExtendedAttributes(from: original, to: temp)
        } else {
            let mask = umask(0)
            umask(mask)
            chmod(temp, 0o666 & ~mask)
        }
    }

    private static func copyExtendedAttributes(from source: String, to destination: String) {
        let size = listxattr(source, nil, 0, 0)
        guard size > 0 else { return }

        var namesBuffer = [CChar](repeating: 0, count: size)
        guard listxattr(source, &namesBuffer, size, 0) == size else { return }

        var offset = 0
        while offset < size {
            let name = String(cString: Array(namesBuffer[offset...]))
            offset += name.utf8.count + 1
            guard !name.isEmpty else { continue }

            let valueSize = getxattr(source, name, nil, 0, 0, 0)
            guard valueSize >= 0 else { continue }
            var value = [UInt8](repeating: 0, count: max(valueSize, 1))
            guard getxattr(source, name, &value, valueSize, 0, 0) == valueSize else { continue }
            _ = setxattr(destination, name, value, valueSize, 0, 0)
        }
    }
}
