import Foundation

/// Lịch sử và câu truy vấn đã lưu — FR-QRY-001.
///
/// Đặc tả: *"lịch sử truy vấn theo workspace; saved query đặt tên"*. Hai thứ khác nhau, và khác
/// nhau ở chỗ **ai quyết định**: lịch sử là thứ app tự ghi, câu đã lưu là thứ người dùng cố ý
/// đặt tên. Trộn chúng vào một danh sách sẽ khiến câu quan trọng trôi mất giữa hai chục lần thử.
///
/// ## Theo WORKSPACE, không phải toàn cục
///
/// Câu truy vấn dính chặt vào dữ liệu: `SELECT … WHERE tinh = 'Huế'` chỉ có nghĩa với bảng có
/// cột `tinh`. Một lịch sử toàn cục sẽ trộn câu của mọi bộ dữ liệu người dùng từng mở, và phần
/// lớn chúng sẽ báo "không có cột ấy" khi bấm lại.
///
/// ## Tệp JSON đọc được bằng mắt, cùng luật ADR-09
///
/// Người dùng phải chép được một câu đã lưu sang máy khác, và phải sửa tay được khi cần. Ghi
/// nguyên tử; tệp của bản mới hơn thì TỪ CHỐI chứ không ghi đè.
public struct QueryLibrary: Codable, Equatable, Sendable {

    public static let currentSchemaVersion = 1

    /// Trần lịch sử. Đủ để tìm lại câu hôm qua, đủ nhỏ để danh sách còn duyệt được bằng mắt.
    /// Câu nào đáng giữ lâu hơn thì người dùng ĐẶT TÊN cho nó — đó chính là `saved`.
    public static let historyLimit = 50

    public struct Entry: Codable, Equatable, Sendable {
        public var sql: String
        /// ISO 8601. Chuỗi chứ không `Date`: tệp này người ta đọc bằng mắt.
        public var at: String

        public init(sql: String, at: String) {
            self.sql = sql
            self.at = at
        }
    }

    public struct Saved: Codable, Equatable, Sendable {
        public var name: String
        public var sql: String

        public init(name: String, sql: String) {
            self.name = name
            self.sql = sql
        }
    }

    public var schemaVersion: Int
    /// Mới nhất ĐỨNG ĐẦU — thứ tự người dùng muốn thấy trong menu thả xuống.
    public var history: [Entry]
    public var saved: [Saved]

    public init(
        schemaVersion: Int = QueryLibrary.currentSchemaVersion,
        history: [Entry] = [], saved: [Saved] = []
    ) {
        self.schemaVersion = schemaVersion
        self.history = history
        self.saved = saved
    }

    // MARK: - Lịch sử

    /// Ghi một câu vừa chạy.
    ///
    /// Câu TRÙNG câu gần nhất thì chỉ cập nhật thời điểm, không thêm dòng: bấm Chạy ba lần để
    /// xem lại kết quả là chuyện thường, và ba dòng giống hệt nhau trong lịch sử chỉ đẩy những
    /// câu khác ra khỏi trần.
    public mutating func record(_ sql: String, at timestamp: String) {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        history.removeAll { $0.sql == trimmed }
        history.insert(Entry(sql: trimmed, at: timestamp), at: 0)
        if history.count > Self.historyLimit {
            history.removeSubrange(Self.historyLimit...)
        }
    }

    // MARK: - Câu đã lưu

    /// Lưu hoặc GHI ĐÈ theo tên.
    ///
    /// Ghi đè khi trùng tên là đúng ý người dùng ("lưu lại bản sửa"), nhưng nó là thao tác mất
    /// dữ liệu — nên tầng giao diện phải hỏi lại. Hàm này không hỏi thay; nó chỉ làm.
    public mutating func save(name: String, sql: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        saved.removeAll { $0.name == trimmedName }
        saved.append(Saved(name: trimmedName, sql: sql))
        saved.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func sql(named name: String) -> String? {
        saved.first { $0.name == name }?.sql
    }

    public mutating func remove(named name: String) {
        saved.removeAll { $0.name == name }
    }

    // MARK: - Đĩa

    public enum Failure: Error, Equatable, Sendable {
        case newerSchema(Int)

        public var message: String {
            switch self {
            case .newerSchema(let version):
                return "Thư viện truy vấn thuộc bản GEditor mới hơn (schema \(version)) — "
                    + "hãy cập nhật app. GEditor KHÔNG ghi đè tệp này."
            }
        }
    }

    public static func load(from url: URL) throws -> QueryLibrary {
        guard let data = try? Data(contentsOf: url) else { return QueryLibrary() }
        let decoded = try JSONDecoder().decode(QueryLibrary.self, from: data)
        guard decoded.schemaVersion <= currentSchemaVersion else {
            throw Failure.newerSchema(decoded.schemaVersion)
        }
        return decoded
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
