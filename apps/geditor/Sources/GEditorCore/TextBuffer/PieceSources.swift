import Foundation

/// Nguồn byte của một piece, kèm chỉ mục newline (ADR-02).
///
/// Piece table chỉ có ĐÚNG HAI nguồn — file gốc chỉ-đọc và add buffer chỉ-nối-thêm — nên cả
/// hai đều thỏa điều kiện của `NewlineBlockIndex`: byte đã ghi không bao giờ đổi.
protocol IndexedSource: AnyObject {
    var count: Int { get }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R

    /// Số '\n' trong `[0, offset)` của nguồn.
    func newlinesBefore(_ offset: Int) -> Int

    /// Offset của '\n' thứ `n` (từ 0) trong nguồn.
    func offsetOfNewline(_ n: Int) -> Int?
}

extension IndexedSource {
    /// Số '\n' trong `range` — dùng khi tách piece để tính lại `Piece.newlines`.
    func newlines(in range: Range<Int>) -> Int {
        guard !range.isEmpty else { return 0 }

        // Đoạn NGẮN thì đếm thẳng. Đường qua chỉ mục là hai lần `newlinesBefore`, mỗi lần
        // quét từ đầu khối tới offset — trung bình nửa khối, tức ~32 KB mỗi lần. Với một
        // đoạn vài chục byte thì đó là đắt gấp hàng nghìn lần, mà tách piece sau khi tài
        // liệu đã phân mảnh gần như luôn rơi vào trường hợp này.
        if range.count <= NewlineBlockIndex.blockSize / 4 {
            return withUnsafeBytes { ByteScan.countNewlines(in: $0, range: range) }
        }
        return newlinesBefore(range.upperBound) - newlinesBefore(range.lowerBound)
    }
}

/// File gốc: nội dung cố định suốt phiên, chỉ mục dựng một lần khi mở.
final class OriginalSource: IndexedSource {
    private let source: ByteSource
    private let index: NewlineBlockIndex

    /// Thời gian dựng chỉ mục lúc mở (ms) — số liệu PoC-B.
    let indexBuildMilliseconds: Double

    init(_ source: ByteSource) {
        self.source = source
        let start = DispatchTime.now()
        self.index = source.withUnsafeBytes { NewlineBlockIndex(bytes: $0) }
        self.indexBuildMilliseconds =
            Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }

    var count: Int { source.count }
    var newlineCount: Int { index.totalNewlines }
    var checkpointBytes: Int { index.checkpointBytes }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try source.withUnsafeBytes(body)
    }

    func newlinesBefore(_ offset: Int) -> Int {
        source.withUnsafeBytes { index.newlinesBefore(offset, in: $0) }
    }

    func offsetOfNewline(_ n: Int) -> Int? {
        source.withUnsafeBytes { index.offsetOfNewline(n, in: $0) }
    }
}

/// Add buffer: mọi byte do người dùng gõ/dán/sinh ra, chỉ nối thêm, không bao giờ sửa lại.
///
/// Tính chất chỉ-nối-thêm là thứ giữ cho offset trong piece đã tạo luôn hợp lệ sau này —
/// undo chỉ cần trỏ lại vào đoạn cũ chứ không phải khôi phục nội dung.
final class AddBuffer: IndexedSource {
    private var storage: [UInt8] = []
    private var index = NewlineBlockIndex()

    var count: Int { storage.count }
    var newlineCount: Int { index.totalNewlines }

    /// Nối `bytes` vào cuối; trả về offset bắt đầu của đoạn vừa nối.
    func append(_ bytes: [UInt8]) -> Int {
        let start = storage.count
        storage.append(contentsOf: bytes)
        storage.withUnsafeBytes { index.extend(with: $0) }
        return start
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withUnsafeBytes(body)
    }

    func newlinesBefore(_ offset: Int) -> Int {
        storage.withUnsafeBytes { index.newlinesBefore(offset, in: $0) }
    }

    func offsetOfNewline(_ n: Int) -> Int? {
        storage.withUnsafeBytes { index.offsetOfNewline(n, in: $0) }
    }
}
