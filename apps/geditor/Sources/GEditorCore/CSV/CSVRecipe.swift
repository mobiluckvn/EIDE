import Foundation

/// Một công thức làm sạch: dãy bước đặt tên, ghi ra JSON, chạy lại trên file khác (FR-CLN-005).
///
/// Công thức tồn tại vì việc làm sạch hiếm khi làm một lần. Người ta nhận cùng một mẫu báo cáo
/// mỗi tháng, và tháng nào cũng phải chuẩn hóa đúng ngần ấy cột theo đúng ngần ấy cách. Chuỗi
/// bước ấy là TRI THỨC về dữ liệu của họ, đáng được đặt tên và chia sẻ chứ không đáng phải nhớ
/// lại từ đầu.
public struct CSVRecipe: Codable, Equatable {

    /// Phiên bản schema. File ghi bằng bản mới hơn thì từ chối đọc — đọc bừa một schema chưa
    /// biết rồi áp lên dữ liệu người dùng là cách hỏng dữ liệu tệ nhất: im lặng và có vẻ đúng.
    public static let currentVersion = 1

    public var version: Int
    public var name: String
    /// Ghi lại để người nhận biết công thức này ra đời từ file nào — không dùng vào việc gì
    /// khác, và KHÔNG dùng để kiểm tra tính hợp lệ.
    public var sourceFile: String?
    public var steps: [CSVRecipeStep]

    public init(name: String, sourceFile: String? = nil, steps: [CSVRecipeStep]) {
        self.version = Self.currentVersion
        self.name = name
        self.sourceFile = sourceFile
        self.steps = steps
    }

    /// Số bước đang bật.
    public var enabledCount: Int { steps.filter(\.enabled).count }

    // MARK: - Đọc / ghi JSON

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public enum LoadError: Error, Equatable {
        /// File ghi bằng bản schema mới hơn bản đang chạy.
        case tooNew(fileVersion: Int, supported: Int)
        case malformed(String)

        public var message: String {
            switch self {
            case let .tooNew(fileVersion, supported):
                return "Công thức này ghi bằng schema v\(fileVersion), bản đang chạy chỉ đọc tới v\(supported)."
            case let .malformed(detail):
                return "Không đọc được công thức: \(detail)"
            }
        }
    }

    public static func load(from data: Data) throws -> CSVRecipe {
        let recipe: CSVRecipe
        do {
            recipe = try JSONDecoder().decode(CSVRecipe.self, from: data)
        } catch {
            // Đọc riêng số phiên bản để phân biệt "file của bản mới hơn" với "file hỏng": hai
            // trường hợp ấy cần hai câu trả lời khác nhau cho người dùng.
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = object["version"] as? Int, version > currentVersion {
                throw LoadError.tooNew(fileVersion: version, supported: currentVersion)
            }
            throw LoadError.malformed(String(describing: error))
        }
        guard recipe.version <= currentVersion else {
            throw LoadError.tooNew(fileVersion: recipe.version, supported: currentVersion)
        }
        return recipe
    }
}

/// Một bước trong công thức.
public struct CSVRecipeStep: Codable, Equatable {

    /// Tên cột — cách chính để tìm lại cột trên file khác.
    ///
    /// Chỉ số cột chỉ là DỰ PHÒNG. File tháng sau có thể thêm một cột ở giữa, và khi ấy "cột
    /// thứ 3" trỏ vào một cột khác hẳn: chuẩn hóa ngày lên cột doanh thu sẽ phá dữ liệu mà
    /// không báo một tiếng nào. Tìm theo tên thì hoặc đúng cột, hoặc không thấy và nói ra.
    public var columnName: String?
    public var columnIndex: Int
    public var kind: CSVCleanStep.Kind
    /// Bước tắt vẫn nằm trong công thức nhưng không chạy — trình sửa bật/tắt được từng bước.
    public var enabled: Bool

    public init(columnName: String?, columnIndex: Int, kind: CSVCleanStep.Kind, enabled: Bool = true) {
        self.columnName = columnName
        self.columnIndex = columnIndex
        self.kind = kind
        self.enabled = enabled
    }

    public var displayName: String {
        CSVCleanStep(column: columnIndex, kind: kind)
            .displayName(columnName: columnName ?? "cột \(columnIndex + 1)")
    }
}

// MARK: - Codable viết tay cho Kind

/// Khóa JSON viết TAY, không để Swift tự sinh.
///
/// File này người dùng mở ra đọc, sửa tay và gửi cho nhau. Tên khóa do trình biên dịch sinh ra
/// vừa khó đọc vừa đổi theo tên biến trong mã — đổi tên một `case` là làm hỏng mọi công thức
/// đã lưu trên máy người khác.
extension CSVCleanStep.Kind: Codable {

    private enum CodingKeys: String, CodingKey {
        case action, order, to, from, grouped, collapseInner, letterCase, value, direction
    }

    private enum Action: String, Codable {
        case normalizeDates, normalizeNumbers, trim, changeCase, fillWithValue, fill, deleteRowsWithNull
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .normalizeDates(order):
            try container.encode(Action.normalizeDates, forKey: .action)
            try container.encodeIfPresent(order?.rawValue, forKey: .order)
        case let .normalizeNumbers(to, from, grouped):
            try container.encode(Action.normalizeNumbers, forKey: .action)
            try container.encode(to.rawValue, forKey: .to)
            try container.encodeIfPresent(from?.rawValue, forKey: .from)
            try container.encode(grouped, forKey: .grouped)
        case let .trim(collapseInner):
            try container.encode(Action.trim, forKey: .action)
            try container.encode(collapseInner, forKey: .collapseInner)
        case let .changeCase(letterCase):
            try container.encode(Action.changeCase, forKey: .action)
            try container.encode(letterCase.rawValue, forKey: .letterCase)
        case let .fillWithValue(value):
            try container.encode(Action.fillWithValue, forKey: .action)
            try container.encode(value, forKey: .value)
        case let .fill(direction):
            try container.encode(Action.fill, forKey: .action)
            try container.encode(direction.rawValue, forKey: .direction)
        case .deleteRowsWithNull:
            try container.encode(Action.deleteRowsWithNull, forKey: .action)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(Action.self, forKey: .action)

        func enumValue<T: RawRepresentable>(_ key: CodingKeys) throws -> T? where T.RawValue == String {
            guard let raw = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
            guard let value = T(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: container, debugDescription: "giá trị không hiểu được: «\(raw)»"
                )
            }
            return value
        }

        switch action {
        case .normalizeDates:
            self = .normalizeDates(order: try enumValue(.order))
        case .normalizeNumbers:
            guard let to: CSVNumberStyle = try enumValue(.to) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .to, in: container, debugDescription: "thiếu quy ước đích"
                )
            }
            self = .normalizeNumbers(
                to: to,
                source: try enumValue(.from),
                grouped: try container.decodeIfPresent(Bool.self, forKey: .grouped) ?? true
            )
        case .trim:
            self = .trim(
                collapseInner: try container.decodeIfPresent(Bool.self, forKey: .collapseInner) ?? false
            )
        case .changeCase:
            guard let letterCase: CSVLetterCase = try enumValue(.letterCase) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .letterCase, in: container, debugDescription: "thiếu kiểu hoa thường"
                )
            }
            self = .changeCase(letterCase)
        case .fillWithValue:
            self = .fillWithValue(try container.decode(String.self, forKey: .value))
        case .fill:
            guard let direction: CSVFillDirection = try enumValue(.direction) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .direction, in: container, debugDescription: "thiếu hướng điền"
                )
            }
            self = .fill(direction)
        case .deleteRowsWithNull:
            self = .deleteRowsWithNull
        }
    }
}
