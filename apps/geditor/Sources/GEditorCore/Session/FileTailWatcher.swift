import Foundation

/// Theo dõi một file đang được ghi thêm (FR-DOC-309, kiểu `tail -f`).
///
/// **Khác `DirectoryWatcher` ở chỗ nó theo dõi MỘT file, và quan tâm tới phần THÊM VÀO.**
/// FSEvents báo "thư mục có gì đó đổi"; ở đây câu hỏi hẹp hơn nhiều: file dài thêm bao nhiêu
/// byte kể từ lần nhìn trước. Trả lời được câu ấy thì chỗ gọi chỉ phải đọc phần đuôi, chứ không
/// phải nạp lại cả file — với một log 8 GB thì khác biệt ấy là dùng được hay không dùng được.
///
/// **Ba chuyện xảy ra với file log mà một bộ theo dõi ngây thơ sẽ hiểu sai:**
///
/// 1. **File bị cắt cụt** (`> app.log`) — cỡ mới NHỎ hơn cỡ cũ. Đọc "từ chỗ cũ tới hết" sẽ ra
///    rác hoặc rỗng. Phải nhận ra và báo là đã cắt.
/// 2. **File bị xoay vòng** (`logrotate` đổi tên rồi tạo file mới cùng tên) — cỡ có thể lớn hơn
///    hoặc nhỏ hơn, nhưng **inode đổi**. So cỡ không phát hiện được; so inode thì có.
/// 3. **File biến mất** rồi quay lại vài giây sau. Không được coi đó là hết theo dõi.
///
/// Dùng `DispatchSource` trên file descriptor chứ không hỏi vòng: hỏi vòng mỗi 100 ms cho một
/// file im lìm là đốt pin cho không việc gì (NFR-PERF-07).
public final class FileTailWatcher {

    /// Chuyện gì vừa xảy ra với file.
    public enum Change: Equatable, Sendable {
        /// File dài thêm; phần mới nằm ở khoảng byte này.
        case appended(Range<Int>)
        /// File bị cắt cụt hoặc bị thay bằng file khác — chỗ gọi phải đọc lại từ đầu.
        case replaced(newSize: Int)
        /// File không còn ở đường dẫn ấy nữa.
        ///
        /// **Có thể chỉ là thoáng qua.** Xoay vòng log và cả phép ghi nguyên tử (ghi file tạm
        /// rồi đổi tên đè lên) đều có một khoảnh khắc đường dẫn ấy trống. Chỗ gọi phải hiểu
        /// đây là "tạm dừng, chờ xem" chứ không phải "thôi theo dõi" — dừng hẳn ở nhịp ấy là
        /// tự tay bỏ theo dõi đúng lúc file đang được ghi nhiều nhất.
        case vanished
    }

    private let path: String
    private let queue: DispatchQueue
    private let onChange: (Change) -> Void

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private var lastSize = 0
    private var lastInode: UInt64 = 0

    public init(
        path: String,
        queue: DispatchQueue = DispatchQueue(label: "geditor.tail"),
        onChange: @escaping (Change) -> Void
    ) {
        self.path = path
        self.queue = queue
        self.onChange = onChange
    }

    deinit { stop() }

    public var isRunning: Bool { source != nil }

    /// Bắt đầu theo dõi từ trạng thái HIỆN TẠI của file.
    ///
    /// Không phát `appended` cho phần đã có sẵn: người dùng vừa mở file thì họ đã thấy nội dung
    /// ấy rồi, và báo "vừa thêm 8 GB" là vô nghĩa.
    @discardableResult
    public func start() -> Bool {
        stop()
        descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return false }

        let stat = Self.probe(path)
        lastSize = stat.size
        lastInode = stat.inode

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .extend, .delete, .rename], queue: queue
        )
        source.setEventHandler { [weak self] in self?.handleEvent() }
        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }
        self.source = source
        source.resume()
        return true
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    /// Hỏi một lần, không cần sự kiện — cho bài kiểm và cho lần đồng bộ đầu tiên.
    public func poll() { handleEvent() }

    private func handleEvent() {
        let stat = Self.probe(path)
        guard stat.exists else {
            onChange(.vanished)
            return
        }

        // Inode đổi = file khác, dù tên vẫn thế. Đây là `logrotate`, và so cỡ không bắt được:
        // file mới có thể tình cờ dài hơn file cũ.
        if stat.inode != lastInode {
            lastInode = stat.inode
            lastSize = stat.size
            onChange(.replaced(newSize: stat.size))
            // Mở lại descriptor: cái đang giữ vẫn trỏ vào file CŨ đã bị đổi tên, nên mọi sự
            // kiện sau đó nói về một file không ai còn nhìn nữa.
            restart()
            return
        }
        if stat.size < lastSize {
            lastSize = stat.size
            onChange(.replaced(newSize: stat.size))
            return
        }
        guard stat.size > lastSize else { return }
        let range = lastSize ..< stat.size
        lastSize = stat.size
        onChange(.appended(range))
    }

    private func restart() {
        let wasRunning = isRunning
        stop()
        if wasRunning { _ = start() }
    }

    static func probe(_ path: String) -> (exists: Bool, size: Int, inode: UInt64) {
        var info = stat()
        guard stat(path, &info) == 0 else { return (false, 0, 0) }
        return (true, Int(info.st_size), UInt64(info.st_ino))
    }
}
