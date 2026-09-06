import Foundation

/// Bộ quy tắc kỳ vọng chất lượng dữ liệu — FR-DQR-001, tệp `.gquality.yaml`.
///
/// Cụm FR-DQR nâng từ MÔ TẢ hiện trạng (Data Profile: *"cột này 2% null"*) lên **PHÁN XÉT theo
/// kỳ vọng** (*"2% null có ĐẠT không?"*). Khác biệt ấy nằm trọn ở tệp này: nó là chỗ người dùng
/// viết ra chuẩn của họ, và mọi thứ còn lại của cụm chỉ là chấm điểm theo chuẩn ấy.
///
/// ## Tệp đặt CẠNH dữ liệu, không nằm trong app
///
/// Cùng luật ADR-09 với theme, macro và Cleaning Recipe: cấu hình là văn bản, nằm cạnh thứ nó
/// nói về, diff được, chép sang máy khác được, và sửa tay được khi hỏng. Một bộ quy tắc chất
/// lượng sống trong cơ sở dữ liệu nội bộ của app là một bộ quy tắc không review được — mà
/// review chính là việc người ta làm với chuẩn dữ liệu.
public struct QualityRules: Equatable, Sendable {

    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var rules: [Rule]
    /// Trọng số sáu chiều của FR-DQR-002. Thiếu khoá nào thì chiều ấy trọng số 1 — *"mặc định
    /// bằng nhau"* đúng như đặc tả, và không bắt người dùng khai đủ sáu dòng để bắt đầu.
    public var weights: [Dimension: Double]
    /// Khoá dùng cho chiều UNIQUENESS. Rỗng thì chiều ấy KHÔNG chấm được, và điểm tổng phải nói
    /// ra là nó thiếu chứ không âm thầm coi như 100.
    public var uniquenessKey: [String]
    /// Cột số đem kiểm outlier cho chiều ACCURACY-PROXY.
    public var accuracyColumns: [String]
    /// Cột thời gian + ngưỡng tươi mới cho chiều TIMELINESS.
    public var freshness: Freshness?
    /// Ngưỡng cảnh báo trôi dạt so với lần chạy gần nhất — FR-DQR-004.
    public var drift: Drift

    public init(
        schemaVersion: Int = QualityRules.currentSchemaVersion,
        rules: [Rule] = [],
        weights: [Dimension: Double] = [:],
        uniquenessKey: [String] = [],
        accuracyColumns: [String] = [],
        freshness: Freshness? = nil,
        drift: Drift = Drift()
    ) {
        self.schemaVersion = schemaVersion
        self.rules = rules
        self.weights = weights
        self.uniquenessKey = uniquenessKey
        self.accuracyColumns = accuracyColumns
        self.freshness = freshness
        self.drift = drift
    }

    /// Ngưỡng trôi dạt — FR-DQR-004 (*"CẢNH BÁO khi lệch vượt ngưỡng khai báo trong YAML
    /// (delta tuyệt đối hoặc %) so lần gần nhất"*).
    ///
    /// ```yaml
    /// drift:
    ///   max_total_drop: 3          # điểm tổng tụt quá 3 điểm
    ///   max_dimension_drop: 5      # bất kỳ chiều nào tụt quá 5 điểm
    ///   max_row_change_pct: 20     # số hàng đổi quá 20%
    ///   max_null_increase_pct: 1   # %null của MỘT cột tăng quá 1 điểm phần trăm
    ///   warn_on_new_failure: true  # luật đang ĐẠT chuyển sang TRƯỢT
    /// ```
    ///
    /// Mọi ngưỡng đều **tắt theo mặc định** trừ `warn_on_new_failure`. Lý do: một cảnh báo bật
    /// sẵn với con số do app tự chọn sẽ kêu ở lần chạy thứ hai của mọi người, và thứ kêu sai
    /// ngay lần đầu thì lần thứ ba đã bị bỏ qua. Còn *"luật đang đạt nay trượt"* thì không cần
    /// ngưỡng nào để mà chọn sai — nó là một sự kiện, không phải một con số.
    public struct Drift: Equatable, Sendable {
        public var maxTotalDrop: Double?
        public var maxDimensionDrop: Double?
        public var maxRowChangePercent: Double?
        public var maxNullIncreasePercent: Double?
        public var warnOnNewFailure: Bool

        public init(
            maxTotalDrop: Double? = nil, maxDimensionDrop: Double? = nil,
            maxRowChangePercent: Double? = nil, maxNullIncreasePercent: Double? = nil,
            warnOnNewFailure: Bool = true
        ) {
            self.maxTotalDrop = maxTotalDrop
            self.maxDimensionDrop = maxDimensionDrop
            self.maxRowChangePercent = maxRowChangePercent
            self.maxNullIncreasePercent = maxNullIncreasePercent
            self.warnOnNewFailure = warnOnNewFailure
        }

        public var isEmpty: Bool {
            maxTotalDrop == nil && maxDimensionDrop == nil && maxRowChangePercent == nil
                && maxNullIncreasePercent == nil && !warnOnNewFailure
        }
    }

    /// Sáu chiều của FR-DQR-002.
    public enum Dimension: String, CaseIterable, Equatable, Sendable {
        case completeness, validity, uniqueness, consistency, accuracy, timeliness

        public var vietnamese: String {
            switch self {
            case .completeness: return "Đầy đủ"
            case .validity: return "Hợp lệ"
            case .uniqueness: return "Không trùng"
            case .consistency: return "Nhất quán"
            case .accuracy: return "Chính xác (ước lượng)"
            case .timeliness: return "Tươi mới"
            }
        }
    }

    public struct Freshness: Equatable, Sendable {
        public var column: String
        /// Dữ liệu cũ hơn ngần này ngày thì chiều TIMELINESS bắt đầu trừ điểm.
        public var maxAgeDays: Double

        public init(column: String, maxAgeDays: Double) {
            self.column = column
            self.maxAgeDays = maxAgeDays
        }
    }

    public enum Severity: String, Equatable, Sendable {
        case error, warn
    }

    public enum DataType: String, Equatable, Sendable {
        case int, float, date, text
    }

    public struct Rule: Equatable, Sendable {
        public var column: String?
        public var kind: Kind
        public var severity: Severity
        /// Dòng trong tệp YAML — để panel nhảy tới đúng luật khi người dùng bấm vào nó.
        public var line: Int

        public init(column: String?, kind: Kind, severity: Severity = .error, line: Int = 0) {
            self.column = column
            self.kind = kind
            self.severity = severity
            self.line = line
        }

        public enum Kind: Equatable, Sendable {
            // Theo cột
            case notNull(maxNullPercent: Double)
            case unique
            case dtype(DataType)
            case range(min: Double?, max: Double?)
            case length(min: Int?, max: Int?)
            case regex(String)
            case inSet([String])
            case dateFormat(String)
            // Liên cột
            case compare(left: String, op: String, right: String)
            case expr(String)
            // Liên file
            case foreignKey(file: String, column: String)
        }

        /// Tên hiện trên bảng kết quả.
        public var title: String {
            let subject = column.map { "«\($0)»" } ?? ""
            switch kind {
            case .notNull(let percent):
                return percent > 0
                    ? "\(subject) không rỗng (cho phép \(format(percent))% null)"
                    : "\(subject) không rỗng"
            case .unique: return "\(subject) không trùng"
            case .dtype(let type): return "\(subject) đúng kiểu \(type.rawValue)"
            case .range(let low, let high):
                let lowText = low.map { "≥ \(format($0))" }
                let highText = high.map { "≤ \(format($0))" }
                return "\(subject) trong khoảng "
                    + [lowText, highText].compactMap { $0 }.joined(separator: " và ")
            case .length(let low, let high):
                return "\(subject) dài "
                    + [low.map { "≥ \($0)" }, high.map { "≤ \($0)" }]
                        .compactMap { $0 }.joined(separator: " và ") + " ký tự"
            case .regex(let pattern): return "\(subject) khớp mẫu `\(pattern)`"
            case .inSet(let values):
                let preview = values.prefix(3).joined(separator: ", ")
                return "\(subject) thuộc danh sách (\(preview)\(values.count > 3 ? "…" : ""))"
            case .dateFormat(let format): return "\(subject) đúng dạng ngày `\(format)`"
            case .compare(let left, let op, let right): return "`\(left) \(op) \(right)`"
            case .expr(let text): return "`\(text)`"
            case .foreignKey(let file, let target):
                return "\(subject) phải có trong «\(target)» của \((file as NSString).lastPathComponent)"
            }
        }

        /// Chiều mà luật này đóng góp điểm cho (FR-DQR-002).
        ///
        /// Ánh xạ lấy nguyên văn đặc tả: VALIDITY là *"tỷ lệ pass của các rule định dạng/dtype/
        /// range/regex"*; CONSISTENCY là *"rule liên cột + liên file"*. `not_null` và `unique`
        /// KHÔNG thuộc VALIDITY — chúng có chiều riêng, và tính cả vào VALIDITY nữa là đếm một
        /// vi phạm hai lần.
        public var dimension: Dimension {
            switch kind {
            case .notNull: return .completeness
            case .unique: return .uniqueness
            case .dtype, .range, .length, .regex, .inSet, .dateFormat: return .validity
            case .compare, .expr, .foreignKey: return .consistency
            }
        }
    }

    // MARK: - Đọc từ YAML

    public struct Failure: Error, Equatable, Sendable {
        public let line: Int
        public let reason: String

        public var message: String {
            line > 0 ? "Dòng \(line): \(reason)" : reason
        }
    }

    public static func load(fromYAML text: String) throws -> QualityRules {
        let root: YAMLValue
        do {
            root = try YAMLReader.parse(text)
        } catch let failure as YAMLReader.Failure {
            throw Failure(line: failure.line, reason: failure.reason)
        }

        let version = root["schemaVersion"]?.intValue ?? currentSchemaVersion
        guard version <= currentSchemaVersion else {
            // Cùng luật `Settings` và `CSVRecipe`: tệp của bản mới hơn thì TỪ CHỐI, không đoán.
            // Đọc một luật mình chưa hiểu rồi chấm điểm theo nó là cho ra một điểm số sai mang
            // đúng hình dạng đúng.
            throw Failure(line: 0, reason:
                "bộ quy tắc thuộc bản GEditor mới hơn (schema \(version)) — hãy cập nhật app")
        }

        var parsed = QualityRules(schemaVersion: version)

        for (key, value) in [("weights", root["weights"])] where value != nil {
            _ = key
            guard case .mapping(let pairs)? = value else {
                throw Failure(line: 0, reason: "`weights` phải là một bảng khoá: số")
            }
            for (name, weight) in pairs {
                guard let dimension = Dimension(rawValue: name) else {
                    throw Failure(line: 0, reason: "`weights` có chiều lạ «\(name)». "
                        + "Sáu chiều: " + Dimension.allCases.map(\.rawValue).joined(separator: ", "))
                }
                guard let number = weight.doubleValue, number >= 0 else {
                    throw Failure(line: 0, reason: "trọng số của «\(name)» phải là số không âm")
                }
                parsed.weights[dimension] = number
            }
        }

        parsed.uniquenessKey = (root["uniqueness_key"]?.sequenceValue ?? [])
            .compactMap(\.stringValue)
        parsed.accuracyColumns = (root["accuracy_columns"]?.sequenceValue ?? [])
            .compactMap(\.stringValue)

        if let drift = root["drift"] {
            let known: Set<String> = [
                "max_total_drop", "max_dimension_drop", "max_row_change_pct",
                "max_null_increase_pct", "warn_on_new_failure",
            ]
            for key in drift.mappingKeys where !known.contains(key) {
                throw Failure(line: 0, reason: "`drift` có khoá lạ «\(key)» — hiểu được: "
                    + known.sorted().joined(separator: ", "))
            }
            for (key, value) in [
                ("max_total_drop", drift["max_total_drop"]),
                ("max_dimension_drop", drift["max_dimension_drop"]),
                ("max_row_change_pct", drift["max_row_change_pct"]),
                ("max_null_increase_pct", drift["max_null_increase_pct"]),
            ] {
                guard let value else { continue }
                guard let number = value.doubleValue, number >= 0 else {
                    throw Failure(line: 0,
                                  reason: "`drift.\(key)` phải là số không âm")
                }
                switch key {
                case "max_total_drop": parsed.drift.maxTotalDrop = number
                case "max_dimension_drop": parsed.drift.maxDimensionDrop = number
                case "max_row_change_pct": parsed.drift.maxRowChangePercent = number
                default: parsed.drift.maxNullIncreasePercent = number
                }
            }
            if let flag = drift["warn_on_new_failure"]?.boolValue {
                parsed.drift.warnOnNewFailure = flag
            }
        }

        if let freshness = root["freshness"] {
            guard let column = freshness["column"]?.stringValue,
                  let days = freshness["max_age_days"]?.doubleValue
            else {
                throw Failure(line: 0,
                              reason: "`freshness` cần cả `column` và `max_age_days`")
            }
            parsed.freshness = Freshness(column: column, maxAgeDays: days)
        }

        guard let items = root["rules"]?.sequenceValue else {
            throw Failure(line: 0, reason: "tệp không có mục `rules`")
        }
        parsed.rules = try items.enumerated().map { try rule(from: $0.element, index: $0.offset) }
        return parsed
    }

    private static func rule(from value: YAMLValue, index: Int) throws -> Rule {
        let severity: Severity
        if let text = value["severity"]?.stringValue {
            guard let parsed = Severity(rawValue: text) else {
                throw Failure(line: 0,
                              reason: "luật thứ \(index + 1): `severity` phải là `error` hoặc `warn`")
            }
            severity = parsed
        } else {
            severity = .error
        }

        let column = value["col"]?.stringValue

        func need(_ what: String) -> Failure {
            Failure(line: 0, reason: "luật thứ \(index + 1): \(what)")
        }

        // Liên file / liên cột trước, vì chúng KHÔNG cần `col` theo cùng nghĩa.
        if let expr = value["expr"]?.stringValue {
            return Rule(column: nil, kind: .expr(expr), severity: severity)
        }
        if let compare = value["compare"] {
            guard let left = compare["a"]?.stringValue,
                  let right = compare["b"]?.stringValue
            else { throw need("`compare` cần `a` và `b`") }
            let op = compare["op"]?.stringValue ?? "<="
            guard ["<", "<=", "=", ">=", ">", "<>"].contains(op) else {
                throw need("`compare.op` lạ: «\(op)»")
            }
            return Rule(column: nil, kind: .compare(left: left, op: op, right: right),
                        severity: severity)
        }
        if let foreign = value["foreign_key"] {
            guard let column else { throw need("`foreign_key` cần `col`") }
            guard let file = foreign["file"]?.stringValue,
                  let target = foreign["column"]?.stringValue
            else { throw need("`foreign_key` cần `file` và `column`") }
            return Rule(column: column, kind: .foreignKey(file: file, column: target),
                        severity: severity)
        }

        guard let column else { throw need("thiếu `col`") }

        if let notNull = value["not_null"] {
            let allowed = notNull.doubleValue
                ?? value["max_null_pct"]?.doubleValue
                ?? 0
            guard notNull.boolValue != false else {
                throw need("`not_null: false` không có nghĩa — bỏ luật ấy đi thì rõ hơn")
            }
            return Rule(column: column, kind: .notNull(maxNullPercent: allowed),
                        severity: severity)
        }
        if value["unique"]?.boolValue == true {
            return Rule(column: column, kind: .unique, severity: severity)
        }
        if let type = value["dtype"]?.stringValue {
            guard let parsed = DataType(rawValue: type) else {
                throw need("`dtype` lạ «\(type)» — nhận int, float, date, text")
            }
            return Rule(column: column, kind: .dtype(parsed), severity: severity)
        }
        if let range = value["range"] {
            let low = range["min"]?.doubleValue
            let high = range["max"]?.doubleValue
            guard low != nil || high != nil else { throw need("`range` cần `min` hoặc `max`") }
            if let low, let high, low > high { throw need("`range.min` lớn hơn `range.max`") }
            return Rule(column: column, kind: .range(min: low, max: high), severity: severity)
        }
        if let length = value["length"] {
            let low = length["min"]?.intValue
            let high = length["max"]?.intValue
            guard low != nil || high != nil else { throw need("`length` cần `min` hoặc `max`") }
            return Rule(column: column, kind: .length(min: low, max: high), severity: severity)
        }
        if let pattern = value["regex"]?.stringValue {
            return Rule(column: column, kind: .regex(pattern), severity: severity)
        }
        if let set = value["in_set"]?.sequenceValue {
            let values = set.compactMap(\.stringValue)
            guard !values.isEmpty else { throw need("`in_set` rỗng") }
            return Rule(column: column, kind: .inSet(values), severity: severity)
        }
        if let format = value["date_format"]?.stringValue {
            return Rule(column: column, kind: .dateFormat(format), severity: severity)
        }

        // Không nhận ra loại luật nào: NÓI RA những khoá đã thấy. Một luật gõ sai tên bị bỏ qua
        // trong im lặng nghĩa là người dùng tưởng dữ liệu đã được kiểm theo nó.
        throw need("không nhận ra loại luật. Khoá đã thấy: "
            + value.mappingKeys.joined(separator: ", "))
    }
}

private func format(_ value: Double) -> String {
    value == value.rounded() && abs(value) < 1e15
        ? String(Int(value)) : String(format: "%g", value)
}
