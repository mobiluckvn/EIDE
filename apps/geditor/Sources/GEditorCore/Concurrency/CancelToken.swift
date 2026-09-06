import Foundation

/// Lỗi khi tác vụ bị người dùng hủy.
public struct OperationCancelled: Error {
    public init() {}
}

/// Lỗi khi tác vụ vượt quá hạn thời gian (deadline).
public struct DeadlineExceeded: Error {
    public let limit: TimeInterval
    public init(limit: TimeInterval) { self.limit = limit }
}

/// Token hủy + deadline dùng chung cho MỌI tác vụ dài trong lõi.
///
/// Ràng buộc kiến trúc (SAD §4.1): mọi tác vụ dài nhận `CancelToken`; UI luôn có
/// tiến trình + nút Hủy đáp ứng ≤ 200 ms (NFR-PERF-06). Regex bắt buộc chạy dưới
/// deadline để không bao giờ treo UI (FR-SRCH-104, NFR-REL-05).
public final class CancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCancelled = false
    private let start: DispatchTime
    private let timeout: TimeInterval?

    /// - Parameter timeout: hạn thời gian tính từ lúc khởi tạo; `nil` = không giới hạn.
    public init(timeout: TimeInterval? = nil) {
        self.start = .now()
        self.timeout = timeout
    }

    /// Token không bao giờ hủy — chỉ dùng trong test và tác vụ nhỏ có biên xác định.
    public static var never: CancelToken { CancelToken() }

    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCancelled
    }

    /// Thời gian đã trôi qua kể từ khi tạo token.
    public var elapsed: TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }

    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        _isCancelled = true
    }

    /// Điểm kiểm tra đặt trong vòng lặp nóng — ném lỗi khi bị hủy hoặc quá hạn.
    ///
    /// Gọi định kỳ (mỗi vài nghìn phần tử) chứ không phải mỗi byte: chi phí lock
    /// mỗi byte sẽ phá KPI throughput.
    public func check() throws {
        if isCancelled { throw OperationCancelled() }
        if let timeout, elapsed > timeout { throw DeadlineExceeded(limit: timeout) }
    }
}
