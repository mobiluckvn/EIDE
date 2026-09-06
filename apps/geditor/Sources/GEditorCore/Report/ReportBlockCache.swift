import Foundation

/// Nhớ kết quả của từng khối ```query giữa hai lần dựng báo cáo — NFR-RPT-01.
///
/// Chỉ tiêu viết đủ cả cách làm: *"kết quả block được cache theo **hash(query + trạng thái
/// nguồn)** — chỉ block có nguồn đổi mới chạy lại"*. Phần thời gian của chỉ tiêu ấy đạt từ lâu,
/// nhưng phần này thì **chưa có mã** cho tới khi có người ĐO: bộ đo dựng cùng một tài liệu hai
/// lần trên cùng một nguồn và thấy lượt hai tốn 1.207 ms so với 1.313 ms — tức không có cache
/// nào cả.
///
/// ## Vì sao nó đáng có, chứ không chỉ để cho khớp đặc tả
///
/// Xem trước báo cáo dựng lại sau mỗi lần gõ (có hoãn nhịp). Người dùng sửa MỘT dòng văn xuôi
/// thì mười khối truy vấn chạy lại từ đầu — trên nguồn một triệu dòng, đó là vài giây cho một
/// thay đổi không chạm tới dữ liệu.
///
/// ## Khoá gồm những gì, và vì sao từng phần
///
/// - **Câu truy vấn ĐÃ THAY THAM SỐ.** Thay trước khi băm: hai lượt dựng khác `--param` là hai
///   câu khác nhau, và băm câu gốc sẽ trả về kết quả của tỉnh khác.
/// - **Dấu phân tách** và **đường dẫn nguồn**: cùng một câu trên hai tệp là hai kết quả.
/// - **Trạng thái nguồn**: số byte của buffer, và cỡ + thời điểm sửa của tệp nguồn nếu có.
///
/// ## Điều KHÔNG làm, và nói ra
///
/// Trạng thái nguồn đo bằng **cỡ + thời điểm sửa**, không băm nội dung. Băm một tệp một triệu
/// dòng ở mỗi lượt dựng thì chính phép băm ấy đắt hơn thứ nó tiết kiệm. Cái giá: một lần sửa
/// GIỮ NGUYÊN CỠ và giữ nguyên `mtime` sẽ không làm cache hết hiệu lực — trên máy thật, ghi tệp
/// luôn đổi `mtime`, nhưng một tệp được chép đè bằng `cp -p` thì có thể không.
///
/// Với **buffer trong bộ nhớ** (tài liệu chưa lưu) thì số byte là tất cả những gì ta có, và hai
/// lần sửa bù trừ nhau về độ dài là một khả năng thật. Nên bộ nhớ tạm này **chỉ sống trong một
/// đối tượng do chỗ gọi giữ**, và chỗ gọi vứt nó đi khi tài liệu đổi — chứ nó không tự cho mình
/// là đúng mãi mãi.
public final class ReportBlockCache: @unchecked Sendable {

    /// Khoá tra cứu — mọi thành phần đều nằm trong `Hashable` tổng hợp.
    struct Key: Hashable {
        let sql: String
        let delimiter: UInt8
        let sourcePath: String?
        let bufferBytes: Int
        let sourceSize: Int
        let sourceModified: Double
    }

    private let lock = NSLock()
    private var entries: [Key: CSVQueryEngine.Result] = [:]
    /// Trần số khối nhớ. Một tài liệu báo cáo thực tế có vài chục khối; trần chỉ để một phiên
    /// dựng loạt 63 tỉnh không giữ lại 63 × N kết quả.
    private let limit: Int

    private(set) public var hits = 0
    private(set) public var misses = 0

    public init(limit: Int = 64) {
        self.limit = max(1, limit)
    }

    /// Xoá sạch — chỗ gọi làm việc này khi tài liệu nguồn đổi.
    public func clear() {
        lock.lock()
        entries.removeAll()
        hits = 0
        misses = 0
        lock.unlock()
    }

    func value(for key: Key) -> CSVQueryEngine.Result? {
        lock.lock()
        defer { lock.unlock() }
        if let hit = entries[key] {
            hits += 1
            return hit
        }
        misses += 1
        return nil
    }

    func store(_ result: CSVQueryEngine.Result, for key: Key) {
        lock.lock()
        // Đầy thì bỏ HẾT chứ không bỏ từng mục theo tuổi: một tài liệu báo cáo dựng lại toàn
        // bộ khối ở mỗi lượt, nên "bỏ mục cũ nhất" sẽ bỏ đúng khối sắp được hỏi lại. Bỏ hết là
        // một lượt chạy lại đầy đủ rồi lại đầy — hành vi đoán được, và không cần đo tuổi.
        if entries.count >= limit { entries.removeAll(keepingCapacity: true) }
        entries[key] = result
        lock.unlock()
    }
}
