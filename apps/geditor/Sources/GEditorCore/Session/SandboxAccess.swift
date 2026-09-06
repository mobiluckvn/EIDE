import Foundation

/// Giữ quyền truy cập file qua các lần khởi động, bằng security-scoped bookmark.
///
/// **Vì sao phải có.** Trong App Sandbox, người dùng chọn một file qua `NSOpenPanel` là app
/// được quyền đọc file ấy — nhưng chỉ **cho tới khi app thoát**. Lần mở sau, cùng đường dẫn ấy
/// trở lại thành đường dẫn của người lạ. Không có gì báo lỗi: `FileManager` trả về "không tồn
/// tại", `open()` trả `EPERM`, và app hiện ra một danh sách tab trống trong khi người dùng biết
/// chắc hôm qua họ đang mở dở năm file.
///
/// Bookmark là thứ duy nhất mang quyền ấy qua lần khởi động. Nó phải được tạo **lúc còn quyền**
/// (ngay khi mở file), chứ không phải lúc cần dùng — đó là chỗ dễ làm ngược nhất.
///
/// **Đếm lượt mở, không mở-đóng theo từng thao tác.** Hai tab cùng trỏ vào một file, hoặc một
/// file nằm trong thư mục workspace đang mở, sẽ xin quyền hai lần. `stopAccessing…` gọi sớm ở
/// một chỗ sẽ cắt quyền của chỗ kia — và triệu chứng là "thỉnh thoảng lưu không được", loại lỗi
/// tốn nhiều ngày nhất để tìm. Nên ở đây đếm lượt: chỉ thả khi lượt cuối cùng thả.
///
/// **Bản không sandbox cũng chạy đúng đường này.** Hai kênh phát hành dùng chung một đường mã
/// (xem `Distribution`); bookmark tạo được cả khi không sandbox, và `startAccessing…` trả `false`
/// thì cũng không sao — quyền vốn đã có sẵn. Cho bản trực tiếp đi đường khác chỉ để "tối ưu" là
/// đẻ ra một nhánh không ai chạy thử.
public enum SandboxAccess {

    // MARK: - Tạo và giải mã

    /// Tạo bookmark cho một file hoặc thư mục người dùng vừa chọn.
    ///
    /// Gọi NGAY khi còn quyền. Trả `nil` nếu không tạo được — chỗ gọi vẫn lưu đường dẫn như cũ,
    /// vì một phiên khôi phục được một nửa vẫn hơn không khôi phục gì.
    public static func makeBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil
            )
        } catch {
            // NÓI RA lý do, đừng nuốt.
            //
            // `try?` ở bản đầu biến mọi thất bại thành một `nil` không lời. Hậu quả không phải
            // là app sập — nó chạy tiếp, chỉ là phiên sau khôi phục thiếu, và người dùng thấy
            // "hôm qua mở năm tệp, hôm nay còn hai". Không có gì trong log để lần ra.
            //
            // Và đó không phải chuyện giả định: bộ tự kiểm trượt chập chờn đúng ở ba bài
            // bookmark, mà không bài nào nói được vì sao — vì lý do đã bị vứt ngay tại đây.
            lastFailure = error
            NSLog("[GEditor] không tạo được bookmark cho %@: %@",
                  url.path, String(describing: error))
            return nil
        }
    }

    /// Lỗi lần tạo bookmark hỏng gần nhất — để bài tự kiểm nói được NGUYÊN NHÂN, không chỉ nói
    /// "không có bookmark".
    public private(set) static var lastFailure: Error?

    public struct Resolved {
        public let url: URL
        /// Bookmark đã cũ (file bị đổi tên hoặc di chuyển) — nội dung vẫn tới được, nhưng nên
        /// tạo lại bookmark, nếu không lần sau có thể hỏng hẳn.
        public let isStale: Bool
    }

    /// Giải mã bookmark thành URL. `nil` nghĩa là file đã biến mất hoặc bookmark hỏng.
    public static func resolve(_ data: Data) -> Resolved? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data, options: [.withSecurityScope],
            relativeTo: nil, bookmarkDataIsStale: &stale
        ) else { return nil }
        return Resolved(url: url, isStale: stale)
    }

    // MARK: - Mở và thả quyền

    private static let lock = NSLock()
    /// Đường dẫn ĐÃ CHUẨN HÓA → số lượt đang giữ quyền.
    private static var counts: [String: Int] = [:]

    /// Khóa của bảng đếm.
    ///
    /// Phải chuẩn hóa, không dùng `url.path` thô. `/var/folders/…` và `/private/var/folders/…`
    /// là CÙNG một file — `/var` là symlink tới `/private/var` trên macOS — nhưng là hai chuỗi
    /// khác nhau. `NSOpenPanel` trả về dạng này, bookmark giải mã ra dạng kia, và bảng đếm sẽ
    /// tưởng đó là hai file: mở hai lượt, thả một lượt ở mỗi khóa, và quyền bị cắt trong khi
    /// chỗ khác vẫn đang cần. Bài kiểm bắt được đúng ca ấy.
    private static func key(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// Xin quyền truy cập và ghi nhận một lượt.
    ///
    /// Trả `true` nếu URL này đang dùng được. Lưu ý `false` KHÔNG luôn nghĩa là hỏng: ngoài
    /// sandbox, `startAccessingSecurityScopedResource` trả `false` cho một URL vốn đã truy cập
    /// được. Chỗ gọi nên cứ thử đọc file rồi mới kết luận.
    @discardableResult
    public static func begin(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let key = key(url)
        if let existing = counts[key], existing > 0 {
            counts[key] = existing + 1
            return true
        }
        let started = url.startAccessingSecurityScopedResource()
        // Ghi nhận lượt KỂ CẢ khi `started == false`: chỗ gọi vẫn sẽ gọi `end` cân đối, và một
        // bảng đếm lệch sẽ làm lần `begin` sau tưởng mình đã có quyền.
        counts[key] = 1
        return started
    }

    /// Thả một lượt. Chỉ lượt cuối cùng mới thật sự dừng truy cập.
    public static func end(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }

        let key = key(url)
        guard let existing = counts[key] else { return }
        if existing <= 1 {
            counts.removeValue(forKey: key)
            url.stopAccessingSecurityScopedResource()
        } else {
            counts[key] = existing - 1
        }
    }

    /// Giải mã rồi mở quyền trong một bước — dạng dùng thường gặp nhất.
    ///
    /// Bookmark cũ thì vẫn dùng và BÁO LẠI cho chỗ gọi để nó lưu bookmark mới; bỏ qua cờ ấy
    /// nghĩa là mỗi lần đổi tên file lại tiến gần hơn tới lần hỏng hẳn.
    public static func open(_ data: Data) -> Resolved? {
        guard let resolved = resolve(data) else { return nil }
        begin(resolved.url)
        return resolved
    }

    // MARK: - Móc chẩn đoán

    /// Số đường đang giữ quyền. Dùng để bắt lỗi mở mà không thả.
    public static var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return counts.count
    }

    public static func holdCount(for url: URL) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[key(url)] ?? 0
    }

    /// Thả hết. CHỈ dùng cho bài kiểm — trong app thật, thả sớm là cắt quyền của chỗ khác.
    static func releaseAllForTesting() {
        lock.lock()
        defer { lock.unlock() }
        for key in counts.keys {
            URL(fileURLWithPath: key).stopAccessingSecurityScopedResource()
        }
        counts.removeAll()
    }
}
