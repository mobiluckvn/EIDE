import Foundation

/// File này nằm trên loại ổ nào, và điều đó đổi cách ta phải ghi (NFR-REL-04).
///
/// **Vì sao phải phân biệt.** `AtomicFileWriter` dựa vào `rename()` — nguyên tử ở mức hệ thống
/// file, và đó là nền của lời hứa "không mất dữ liệu chưa lưu" (NFR-REL-01/02). Lời hứa ấy
/// đúng trên ổ cục bộ. Trên hai loại ổ khác thì không đủ:
///
/// - **iCloud Drive** có tiến trình khác (`bird`) đọc và ghi cùng file. Ghi thẳng mà không báo
///   cho nó biết thì hai bên có thể ghi chồng nhau, và bản thua là bản của người dùng.
/// - **Ổ mạng** (SMB, AFP, NFS) không bảo đảm `rename()` nguyên tử theo cùng nghĩa, và `fsync`
///   trên nhiều máy chủ chỉ đẩy tới bộ đệm của máy chủ chứ không tới đĩa.
///
/// **Điều lớp này KHÔNG làm: nó không tự sửa gì.** Nó chỉ TRẢ LỜI câu hỏi "ổ này loại gì", để
/// chỗ ghi quyết định có cần `NSFileCoordinator` hay không, và để giao diện nói cho người dùng
/// biết khi họ đang sửa một file trên ổ mà lời hứa an toàn yếu hơn.
public enum VolumeKind: String, Equatable, Sendable {
    case local
    case iCloud
    case network

    /// Loại ổ chứa `path`. Không xác định được thì coi là `local` — đó là trường hợp áp đảo,
    /// và đoán là `network` sẽ bắt mọi phép lưu bình thường trả giá điều phối vô ích.
    public static func of(path: String) -> VolumeKind {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .volumeIsLocalKey]
        // Hỏi cả THƯ MỤC CHA khi file chưa tồn tại: lúc "Lưu thành…" thì file đích chưa có, và
        // hỏi nó sẽ không ra gì trong khi thư mục thì luôn có mặt.
        for candidate in [url, url.deletingLastPathComponent()] {
            guard let values = try? candidate.resourceValues(forKeys: keys) else { continue }
            if values.isUbiquitousItem == true { return .iCloud }
            if let isLocal = values.volumeIsLocal, !isLocal { return .network }
            return .local
        }
        return .local
    }

    /// Ổ này có cần đi qua `NSFileCoordinator` không.
    public var needsCoordination: Bool { self != .local }

    /// Câu nói cho người dùng, hoặc `nil` khi không có gì đáng nói.
    ///
    /// Nói MỘT LẦN lúc mở, không phải mỗi lần lưu: một cảnh báo lặp lại ở mỗi ⌘S sẽ bị bỏ qua
    /// từ lần thứ hai, và khi ấy nó không còn là cảnh báo nữa.
    public var advisory: String? {
        switch self {
        case .local: return nil
        case .iCloud:
            return "File nằm trên iCloud Drive — lưu sẽ được điều phối với tiến trình đồng bộ."
        case .network:
            return "File nằm trên ổ mạng — mất kết nối giữa chừng có thể làm phép lưu dở dang."
        }
    }
}
