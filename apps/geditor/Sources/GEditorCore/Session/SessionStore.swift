import Foundation

/// Trạng thái một tab trong phiên làm việc (FR-DOC-303).
public struct SessionTab: Codable, Equatable {

    /// Đường dẫn file; `nil` với tài liệu chưa từng được lưu.
    public var path: String?

    /// Security-scoped bookmark của file, để mở lại được ở phiên sau khi chạy trong App Sandbox.
    ///
    /// Đường dẫn KHÔNG đủ. Trong sandbox, quyền đọc một file người dùng đã chọn chỉ sống tới lúc
    /// app thoát; lần mở sau, cùng đường dẫn ấy là đường dẫn của người lạ và mọi phép đọc trả về
    /// "không tồn tại". Bookmark là thứ duy nhất mang quyền qua lần khởi động — xem
    /// `SandboxAccess`.
    ///
    /// Vẫn giữ CẢ `path`: nó là thứ đọc được bằng mắt khi soi tệp phiên, và là đường lùi khi
    /// bookmark hỏng (bản không sandbox vẫn mở được bằng đường dẫn trần).
    public var bookmark: Data?

    /// Khớp với `Snapshot.documentID`.
    ///
    /// Đây là sợi dây duy nhất nối phiên với nội dung CHƯA LƯU. Thiếu nó thì khôi phục phiên
    /// chỉ mở lại được những tab đã có file trên đĩa — mà tài liệu chưa lưu mới là thứ mất đi
    /// là mất hẳn.
    public var documentID: String

    public var caretOffset: Int
    public var isPinned: Bool
    /// Chỉ số màu tab; `nil` = không tô.
    public var colorIndex: Int?
    /// Tài liệu có nội dung chưa lưu tại lúc ghi phiên hay không.
    public var isModified: Bool

    public init(
        path: String?, documentID: String, caretOffset: Int,
        isPinned: Bool = false, colorIndex: Int? = nil, isModified: Bool = false,
        bookmark: Data? = nil
    ) {
        self.path = path
        self.bookmark = bookmark
        self.documentID = documentID
        self.caretOffset = Swift.max(0, caretOffset)
        self.isPinned = isPinned
        self.colorIndex = colorIndex
        self.isModified = isModified
    }

    /// Tab này có gì đáng khôi phục không.
    ///
    /// Tab rỗng chưa đặt tên và chưa sửa gì là tab người dùng chưa làm gì với nó. Mở lại nó ở
    /// phiên sau chỉ tạo rác — và với người mở app nhiều lần trong ngày thì rác tích lại nhanh.
    public var isWorthRestoring: Bool { path != nil || isModified }
}

/// Trạng thái chia đôi màn hình của một cửa sổ (FR-DOC-302 + FR-DOC-303).
public struct SessionSplit: Codable, Equatable {
    /// Chia DỌC (hai cột) hay chia NGANG (hai hàng).
    public var isVertical: Bool
    /// Tab mà nửa thứ hai đang mở.
    public var secondTabIndex: Int

    public init(isVertical: Bool, secondTabIndex: Int) {
        self.isVertical = isVertical
        self.secondTabIndex = Swift.max(0, secondTabIndex)
    }
}

/// Trạng thái một cửa sổ (FR-DOC-303 đòi "hỗ trợ nhiều cửa sổ").
public struct SessionWindow: Codable, Equatable {

    public var tabs: [SessionTab]
    public var activeTabIndex: Int
    /// Khung cửa sổ trên màn hình: x, y, rộng, cao. `nil` = để hệ điều hành quyết.
    public var frame: [Double]?
    /// `nil` khi cửa sổ không chia đôi.
    public var split: SessionSplit?

    /// Thư mục đang mở làm workspace (FR-DOC-308); `nil` khi không mở thư mục nào.
    public var workspacePath: String?

    /// Bookmark của thư mục ấy, để mở lại được ở phiên sau trong App Sandbox.
    ///
    /// Cùng lý do với `SessionTab.bookmark`, và ở đây còn nặng hơn: một thư mục workspace là
    /// quyền truy cập cho HÀNG TRĂM file bên trong nó. Mất quyền ấy thì cây thư mục hiện ra
    /// rỗng và FSEvents im lặng — không có gì báo lỗi.
    public var workspaceBookmark: Data?

    public init(
        tabs: [SessionTab], activeTabIndex: Int = 0, frame: [Double]? = nil,
        split: SessionSplit? = nil,
        workspacePath: String? = nil, workspaceBookmark: Data? = nil
    ) {
        self.tabs = tabs
        self.workspacePath = workspacePath
        self.workspaceBookmark = workspaceBookmark
        self.activeTabIndex = tabs.isEmpty
            ? 0
            : Swift.min(Swift.max(activeTabIndex, 0), tabs.count - 1)
        self.frame = frame
        self.split = split
    }
}

/// Phiên làm việc ghi ra đĩa (FR-DOC-303).
public struct Session: Codable, Equatable {

    /// Bản schema. Có sẵn từ đầu vì file này sẽ sống qua nhiều phiên bản app, và một file
    /// phiên đọc sai còn tệ hơn không có file phiên: nó mở lại sai thứ.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var savedAtEpoch: Double
    public var windows: [SessionWindow]

    public init(windows: [SessionWindow], savedAtEpoch: Double = Date().timeIntervalSince1970) {
        self.schemaVersion = Self.currentSchemaVersion
        self.savedAtEpoch = savedAtEpoch
        self.windows = windows
    }

    /// Có gì để khôi phục không.
    public var isEmpty: Bool {
        windows.allSatisfy {
            // Thư mục workspace TỰ NÓ đáng khôi phục. Người dùng mở một thư mục, chưa mở file
            // nào, thoát app — lần sau cây thư mục phải còn đó. Bản đầu chỉ đếm tab, nên đúng
            // ca ấy phiên bị coi là rỗng và vứt đi.
            $0.workspacePath == nil && $0.tabs.filter(\.isWorthRestoring).isEmpty
        }
    }

    /// Bỏ những tab không đáng khôi phục, và bỏ luôn cửa sổ trống sau khi lọc.
    public func pruned() -> Session {
        var copy = self
        copy.windows = windows.compactMap { window in
            let kept = window.tabs.filter(\.isWorthRestoring)
            guard !kept.isEmpty else {
                // Không còn tab nào nhưng vẫn có thư mục thì giữ cửa sổ lại — xem `isEmpty`.
                guard window.workspacePath != nil else { return nil }
                var bare = window
                bare.tabs = []
                bare.activeTabIndex = 0
                bare.split = nil
                return bare
            }
            // Chỉ số tab đang mở phải tính LẠI theo danh sách đã lọc, không giữ số cũ: giữ số
            // cũ thì bỏ một tab ở đầu là mở lại đúng tab khác.
            let active = window.tabs.indices.contains(window.activeTabIndex)
                ? kept.firstIndex(of: window.tabs[window.activeTabIndex]) ?? 0
                : 0
            // Chỉ số tab của nửa thứ hai cũng phải tính lại theo danh sách đã lọc.
            let split = window.split.map { previous -> SessionSplit in
                let index = window.tabs.indices.contains(previous.secondTabIndex)
                    ? kept.firstIndex(of: window.tabs[previous.secondTabIndex]) ?? 0
                    : 0
                return SessionSplit(isVertical: previous.isVertical, secondTabIndex: index)
            }
            return SessionWindow(tabs: kept, activeTabIndex: active, frame: window.frame, split: split)
        }
        return copy
    }
}

/// Đọc/ghi phiên làm việc trên đĩa.
///
/// JSON chứ không phải plist nhị phân: quy tắc ADR-09 là mọi dữ liệu cấu hình phải diff được
/// và sửa tay được. Khi phiên khôi phục sai, người dùng — và cả người sửa lỗi — phải mở được
/// file ra xem nó nói gì.
public final class SessionStore {

    private let file: URL
    private let fileManager = FileManager.default

    public init(root: URL = AppPaths.sessionDirectory) {
        file = root.appendingPathComponent("session.json")
    }

    public var fileURL: URL { file }

    /// Ghi phiên. Nguyên tử như mọi lần ghi khác của dự án (NFR-REL-02).
    ///
    /// Ghi thẳng đè lên file sẽ để lại một file phiên CỤT nếu máy tắt giữa chừng — đúng lúc
    /// người dùng cần nó nhất là lúc mất điện.
    public func save(_ session: Session) throws {
        try fileManager.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        // `withoutEscapingSlashes` không phải chuyện thẩm mỹ: nội dung chính của file này TOÀN
        // LÀ đường dẫn, và không có nó thì mọi dòng đọc ra "\/Users\/congvt\/..." — đúng thứ
        // làm hỏng cái lý do JSON được chọn ở ADR-09.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(session)
        try AtomicFileWriter.write([UInt8](data), to: file.path)
    }

    /// Đọc phiên; `nil` khi chưa có phiên nào.
    ///
    /// File hỏng hoặc schema lạ cũng trả `nil` chứ không ném lỗi: không mở lại được phiên cũ
    /// là chuyện khó chịu, còn không mở được app thì là chuyện hỏng. Người dùng luôn còn bản
    /// nháp của FR-DOC-304 làm lưới an toàn thứ hai.
    public func load() throws -> Session? {
        guard fileManager.fileExists(atPath: file.path) else { return nil }
        guard let data = fileManager.contents(atPath: file.path),
              let session = try? JSONDecoder().decode(Session.self, from: data),
              session.schemaVersion <= Session.currentSchemaVersion
        else { return nil }
        return session
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: file.path) else { return }
        try fileManager.removeItem(at: file)
    }
}
