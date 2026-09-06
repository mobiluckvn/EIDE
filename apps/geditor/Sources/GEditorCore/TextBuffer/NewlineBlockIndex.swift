import Foundation

/// Chỉ mục newline THƯA theo khối cố định — nền của truy vấn dòng trên file hàng GB (ADR-02).
///
/// Vì sao không lưu offset của MỌI dòng: file CSV 1 GB với dòng ~76 byte có ~14 triệu dòng.
/// Mảng `[Int]` đầy đủ tốn ~112 MB, tự nó đã vượt NFR-PERF-05 (RAM nhàn rỗi ≤ 80 MB) trước
/// khi tính bất cứ thứ gì khác. Thay vào đó chỉ lưu MỘT số nguyên cho mỗi khối 64 KB:
///
///     cumulative[b] = số '\n' trong [0, b * blockSize)
///
/// 1 GB → 16 384 mục → 128 KB. Mọi truy vấn quy về "tra bảng + quét SIMD trong ĐÚNG MỘT khối":
/// chặn trên 64 KB, tức ~1,3 µs ở tốc độ quét đo được (51 GB/s trên NEON, benchmarks/results).
///
/// Bất biến: `cumulative` chỉ chứa mốc của các khối ĐẦY (`cumulative.count - 1 == indexedBytes /
/// blockSize`). Phần đuôi dở dang được quét lại mỗi lần truy vấn — vẫn nằm trong chặn 64 KB, và
/// nhờ vậy `extend` sau khi add buffer dài thêm không phải sửa mục nào đã ghi.
public struct NewlineBlockIndex {

    /// 64 KB: đủ nhỏ để quét lại là chi phí bỏ qua được, đủ lớn để bảng mốc không đáng kể.
    public static let blockSize = 64 * 1024

    /// `cumulative[b]` = số '\n' trong `[0, b * blockSize)`. Luôn bắt đầu bằng `[0]`.
    private var cumulative: [Int] = [0]

    /// Số byte đã được phản ánh vào chỉ mục.
    public private(set) var indexedBytes = 0

    /// Tổng số '\n' trong `[0, indexedBytes)` — gồm cả phần đuôi chưa thành khối đầy.
    public private(set) var totalNewlines = 0

    public init() {}

    public init(bytes: UnsafeRawBufferPointer) {
        extend(with: bytes)
    }

    /// Quét phần mới xuất hiện của nguồn (`[indexedBytes, bytes.count)`).
    ///
    /// Chỉ hợp lệ với nguồn CHỈ NỐI THÊM: file gốc mmap (không đổi) và add buffer (append-only).
    /// Nếu byte cũ đổi thì phải dựng lại chỉ mục từ đầu.
    public mutating func extend(with bytes: UnsafeRawBufferPointer) {
        let total = bytes.count
        guard total > indexedBytes else { return }

        let blockSize = Self.blockSize
        let fullBlocks = total / blockSize
        while cumulative.count - 1 < fullBlocks {
            let b = cumulative.count - 1
            let start = b * blockSize
            let n = ByteScan.countNewlines(in: bytes, range: start ..< (start + blockSize))
            cumulative.append(cumulative[b] + n)
        }

        totalNewlines = cumulative[fullBlocks]
            + ByteScan.countNewlines(in: bytes, range: (fullBlocks * blockSize) ..< total)
        indexedBytes = total
    }

    /// Số '\n' nằm trước `offset` (tức trong `[0, offset)`).
    ///
    /// Chi phí: một phép chia, một lần đọc bảng, một lần quét SIMD ≤ `blockSize`.
    public func newlinesBefore(_ offset: Int, in bytes: UnsafeRawBufferPointer) -> Int {
        guard offset > 0 else { return 0 }
        guard offset < indexedBytes else { return totalNewlines }

        let b = min(offset / Self.blockSize, cumulative.count - 1)
        let blockStart = b * Self.blockSize
        return cumulative[b] + ByteScan.countNewlines(in: bytes, range: blockStart ..< offset)
    }

    /// Offset của byte '\n' thứ `n` (đánh số từ 0). `nil` nếu nguồn không có đủ ngần ấy newline.
    ///
    /// Chi phí: một tìm nhị phân trên bảng mốc (~14 bước cho 1 GB) rồi quét trong ĐÚNG khối
    /// chứa nó — vì `cumulative[b] ≤ n < cumulative[b+1]` nên newline thứ `n` không thể nằm
    /// ngoài khối `b`.
    public func offsetOfNewline(_ n: Int, in bytes: UnsafeRawBufferPointer) -> Int? {
        guard n >= 0, n < totalNewlines else { return nil }

        var lo = 0, hi = cumulative.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if cumulative[mid] <= n { lo = mid } else { hi = mid - 1 }
        }

        var remaining = n - cumulative[lo]
        var pos = lo * Self.blockSize
        while let at = ByteScan.firstIndex(of: UInt8(ascii: "\n"), in: bytes, from: pos) {
            if remaining == 0 { return at }
            remaining -= 1
            pos = at + 1
        }
        return nil
    }

    /// Bộ nhớ bảng mốc đang chiếm — số liệu PoC-B, không dùng trong đường nóng.
    public var checkpointBytes: Int { cumulative.count * MemoryLayout<Int>.stride }
}
