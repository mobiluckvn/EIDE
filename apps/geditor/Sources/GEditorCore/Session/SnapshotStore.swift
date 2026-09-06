import Foundation

/// Bản nháp của một tài liệu chưa lưu.
public struct Snapshot: Codable, Equatable {

    /// Cách nội dung bản nháp được lưu.
    public enum Kind: String, Codable {
        /// Toàn bộ nội dung tài liệu.
        case full
        /// Chỉ NHẬT KÝ SỬA ĐỔI, phát lại trên file gốc. Bắt buộc với tài liệu lớn: ghi cả
        /// 1 GB mỗi chu kỳ autosave vừa đốt đĩa vừa dựng một mảng 1 GB trong RAM.
        case delta
    }

    public var kind: Kind
    public var documentID: String
    /// Đường dẫn file gốc; `nil` với tài liệu chưa từng lưu (untitled).
    public var originalPath: String?
    public var savedAtEpoch: Double
    public var byteCount: Int
    /// Vị trí caret để khôi phục đúng chỗ đang gõ (FR-DOC-303).
    public var caretOffset: Int

    public init(
        kind: Kind = .full,
        documentID: String,
        originalPath: String?,
        savedAtEpoch: Double,
        byteCount: Int,
        caretOffset: Int
    ) {
        self.kind = kind
        self.documentID = documentID
        self.originalPath = originalPath
        self.savedAtEpoch = savedAtEpoch
        self.byteCount = byteCount
        self.caretOffset = caretOffset
    }
}

/// Lưu/khôi phục bản nháp chưa lưu (FR-DOC-304, NFR-REL-01).
///
/// Tiêu chí nghiệm thu là TC-DOC-01: `kill -9` giữa phiên rồi mở lại app phải khôi phục
/// 100% nội dung chưa lưu của MỌI tab, mất tối đa một chu kỳ autosave. Vì vậy:
///  - Ghi snapshot cũng phải nguyên tử (dùng `AtomicFileWriter`) — snapshot hỏng còn tệ
///    hơn không có snapshot.
///  - Không bao giờ đụng vào file gốc của người dùng.
///
/// TODO(Phase 1): ghi delta thay vì full khi tài liệu vượt ngưỡng (SAD §2.3 SnapshotStore),
/// và chuyển sang QoS `.utility` trên SnapshotQueue riêng (SAD §4.1).
public final class SnapshotStore {
    private let root: URL
    private let fileManager = FileManager.default

    public init(root: URL = AppPaths.snapshotsDirectory) {
        self.root = root
    }

    private func directory(for documentID: String) -> URL {
        root.appendingPathComponent(documentID, isDirectory: true)
    }

    /// Ghi bản nháp: nội dung + manifest mô tả.
    public func write(_ bytes: [UInt8], manifest: Snapshot) throws {
        try write(manifest: manifest) { descriptor in
            try bytes.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let written = Darwin.write(
                        descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset
                    )
                    if written < 0 {
                        if errno == EINTR { continue }
                        throw AtomicFileWriter.Failure.writeFailed(errno: errno)
                    }
                    offset += written
                }
            }
        }
    }

    /// Ghi bản nháp với nội dung sinh theo từng đoạn — không dựng cả tài liệu trong RAM.
    public func write(manifest: Snapshot, contentWriter: (Int32) throws -> Void) throws {
        let directory = directory(for: manifest.documentID)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        try AtomicFileWriter.write(
            to: directory.appendingPathComponent("content").path, contentWriter
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(manifest)
        try AtomicFileWriter.write(
            Array(json),
            to: directory.appendingPathComponent("manifest.json").path
        )
    }

    /// Danh sách mọi bản nháp còn tồn đọng — gọi khi khởi động để dựng banner
    /// "Đã khôi phục N tài liệu chưa lưu từ phiên trước" (UI/UX §7.1).
    public func pendingSnapshots() throws -> [Snapshot] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let decoder = JSONDecoder()
        return try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .compactMap { directory in
                let manifest = directory.appendingPathComponent("manifest.json")
                guard let data = try? Data(contentsOf: manifest) else { return nil }
                return try? decoder.decode(Snapshot.self, from: data)
            }
            .sorted { $0.savedAtEpoch > $1.savedAtEpoch }
    }

    public func content(for documentID: String) throws -> [UInt8] {
        let url = directory(for: documentID).appendingPathComponent("content")
        return Array(try Data(contentsOf: url))
    }

    /// Xóa bản nháp sau khi người dùng đã lưu thật hoặc chủ động bỏ.
    public func discard(documentID: String) throws {
        let directory = directory(for: documentID)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }
}
