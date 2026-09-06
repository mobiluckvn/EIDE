import Foundation
import CoreServices

/// Theo dõi thay đổi trong một cây thư mục qua FSEvents (FR-DOC-308).
///
/// Vì sao FSEvents chứ không phải `DispatchSource` trên từng thư mục: một cây dự án có hàng
/// nghìn thư mục, và mở một mô tả file cho mỗi thư mục sẽ chạm trần `ulimit` trước khi kịp
/// theo dõi xong. FSEvents theo dõi cả cây bằng một luồng sự kiện duy nhất, và hệ điều hành
/// đã gom sự kiện sẵn cho ta.
///
/// **Gom nhịp trước khi báo.** Một lần `git checkout` hay một lần build sinh ra hàng nghìn sự
/// kiện trong vài trăm mili giây; báo từng cái lên UI là dựng lại cây hàng nghìn lần cho một
/// thay đổi mà người dùng nhìn thấy là "một lần".
public final class DirectoryWatcher {

    /// Khoảng gom sự kiện, giây. FSEvents tự gom trong khoảng này trước khi gọi ta.
    public static let coalesceInterval = 0.3

    private let root: String
    private var stream: FSEventStreamRef?
    private let queue: DispatchQueue
    private let onChange: ([String]) -> Void

    /// - Parameter onChange: gọi trên `queue`, kèm các đường dẫn đã đổi.
    public init(
        root: String,
        queue: DispatchQueue = DispatchQueue(label: "geditor.workspace.watch"),
        onChange: @escaping ([String]) -> Void
    ) {
        self.root = root
        self.queue = queue
        self.onChange = onChange
    }

    deinit { stop() }

    public var isRunning: Bool { stream != nil }

    @discardableResult
    public func start() -> Bool {
        guard stream == nil else { return true }

        // `info` giữ con trỏ THÔ tới chính đối tượng này. Không dùng `Unmanaged.passRetained`:
        // FSEvents sẽ giữ tham chiếu suốt đời stream, và khi ấy `deinit` không bao giờ chạy —
        // đối tượng tự giữ mình sống mãi. `stop()` trong `deinit` mới là thứ dọn dẹp, nên con
        // trỏ ở đây phải là KHÔNG sở hữu.
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            let raw = unsafeBitCast(paths, to: NSArray.self)
            var changed: [String] = []
            changed.reserveCapacity(count)
            for index in 0 ..< count {
                if let path = raw[index] as? String { changed.append(path) }
            }
            watcher.onChange(changed)
        }

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
        )
        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            [root] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.coalesceInterval,
            flags
        ) else { return false }

        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamRelease(created)
            return false
        }
        stream = created
        return true
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
