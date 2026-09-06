import Foundation

/// Một mục trong cây thư mục của workspace (FR-DOC-308).
public struct WorkspaceEntry: Equatable, Sendable {
    public let path: String
    public let name: String
    public let isDirectory: Bool

    public init(path: String, isDirectory: Bool) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
        self.isDirectory = isDirectory
    }
}

/// Thư mục làm workspace: đọc cây, lọc theo tên, thao tác file (FR-DOC-308).
///
/// Đọc theo TỪNG CẤP chứ không quét cả cây một lần. Người dùng mở thư mục dự án của họ, và
/// thư mục ấy có thể chứa `node_modules` với hai trăm nghìn file — quét hết để rồi hiện ra một
/// cây mà chín mươi phần trăm không ai mở tới là cách chắc chắn để sidebar mất mười giây mới
/// hiện, mỗi lần.
public enum Workspace {

    /// Thư mục bỏ qua mặc định.
    ///
    /// Không phải "ẩn cho gọn" mà là "đừng đi vào": đây là những thư mục sinh ra bởi công cụ,
    /// đông file tới mức chỉ riêng việc liệt kê đã đủ làm treo, và gần như không ai sửa tay
    /// file bên trong. Người dùng bật lại được — đó là lý do nó là một tham số, không phải
    /// một hằng số nằm sâu trong mã.
    public static let defaultIgnored: Set<String> = [
        ".git", ".svn", ".hg", "node_modules", ".build", "DerivedData",
        ".venv", "__pycache__", ".next", "dist", "vendor",
    ]

    /// Đọc MỘT cấp của cây.
    ///
    /// Thư mục lên trước, rồi tới file; trong mỗi nhóm sắp theo tên không phân biệt hoa
    /// thường — đúng thứ tự Finder hiện, để mắt người dùng không phải học lại một trật tự mới.
    public static func children(
        of directory: String,
        showHidden: Bool = false,
        ignored: Set<String> = defaultIgnored
    ) -> [WorkspaceEntry] {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: directory) else { return [] }

        var entries: [WorkspaceEntry] = []
        for name in names {
            if !showHidden, name.hasPrefix(".") { continue }
            if ignored.contains(name) { continue }
            let path = (directory as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard manager.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }
            entries.append(WorkspaceEntry(path: path, isDirectory: isDirectory.boolValue))
        }

        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Tìm file theo tên trong cả cây (lọc nhanh của sidebar).
    ///
    /// - Parameter limit: dừng sau khi đủ bấy nhiêu kết quả. Ô lọc chỉ hiện được vài chục dòng;
    ///   quét tiếp sau khi đã đủ là tiêu thời gian cho thứ không ai nhìn.
    public static func find(
        _ needle: String,
        under root: String,
        showHidden: Bool = false,
        ignored: Set<String> = defaultIgnored,
        limit: Int = 200,
        cancelToken: CancelToken = CancelToken()
    ) -> [WorkspaceEntry] {
        let trimmed = needle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let folded = fold(trimmed)

        var out: [WorkspaceEntry] = []
        var queue = [root]

        while !queue.isEmpty, out.count < limit {
            guard (try? cancelToken.check()) != nil else { break }
            let directory = queue.removeFirst()
            for entry in children(of: directory, showHidden: showHidden, ignored: ignored) {
                if fold(entry.name).contains(folded) {
                    out.append(entry)
                    if out.count >= limit { break }
                }
                if entry.isDirectory { queue.append(entry.path) }
            }
        }
        return out
    }

    /// Bỏ dấu và hoa thường, dùng chung luật với ô lọc CSV và Function List.
    ///
    /// Người dùng không nên phải nhớ ba luật tìm kiếm khác nhau trong cùng một ứng dụng.
    static func fold(_ value: String) -> String { CSVFilter.fold(value) }

    // MARK: - Thao tác file

    public enum FileError: Error, Equatable {
        case alreadyExists(String)
        case failed(String)

        public var message: String {
            switch self {
            case let .alreadyExists(path):
                return "Đã có «\((path as NSString).lastPathComponent)» ở đó"
            case let .failed(detail):
                return detail
            }
        }
    }

    /// Tạo file rỗng.
    ///
    /// KHÔNG ghi đè: trùng tên thì báo lỗi. Một thao tác "tạo file mới" mà lặng lẽ xóa trắng
    /// file cũ cùng tên là mất dữ liệu, và người dùng sẽ không biết cho tới lúc mở nó ra.
    @discardableResult
    public static func createFile(named name: String, in directory: String) throws -> String {
        let path = (directory as NSString).appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: path) else {
            throw FileError.alreadyExists(path)
        }
        guard FileManager.default.createFile(atPath: path, contents: Data()) else {
            throw FileError.failed("Không tạo được \(name)")
        }
        return path
    }

    @discardableResult
    public static func createDirectory(named name: String, in directory: String) throws -> String {
        let path = (directory as NSString).appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: path) else {
            throw FileError.alreadyExists(path)
        }
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
        } catch {
            throw FileError.failed("Không tạo được thư mục \(name): \(error)")
        }
        return path
    }

    @discardableResult
    public static func rename(_ path: String, to name: String) throws -> String {
        let parent = (path as NSString).deletingLastPathComponent
        let target = (parent as NSString).appendingPathComponent(name)
        guard target != path else { return path }
        guard !FileManager.default.fileExists(atPath: target) else {
            throw FileError.alreadyExists(target)
        }
        do {
            try FileManager.default.moveItem(atPath: path, toPath: target)
        } catch {
            throw FileError.failed("Không đổi tên được: \(error)")
        }
        return target
    }

    /// Xóa vào THÙNG RÁC, không xóa thẳng.
    ///
    /// Đặc tả nói rõ "xóa vào Thùng rác", và lý do đáng nhắc lại: sidebar là chỗ người ta bấm
    /// nhanh, còn `removeItem` thì không có đường lùi. Thùng rác cho họ một đêm để đổi ý.
    public static func moveToTrash(_ path: String) throws {
        do {
            try FileManager.default.trashItem(
                at: URL(fileURLWithPath: path), resultingItemURL: nil
            )
        } catch {
            throw FileError.failed("Không chuyển vào Thùng rác được: \(error)")
        }
    }
}
