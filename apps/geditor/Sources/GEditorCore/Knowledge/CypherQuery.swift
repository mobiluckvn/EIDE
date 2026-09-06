import Foundation

/// Đọc một TẬP CON của openCypher — FR-KNW-913.
///
/// ## Tập con, và ranh giới của nó viết ra đây chứ không để người dùng dò
///
/// openCypher đầy đủ là một ngôn ngữ lớn. Đặc tả FR-KNW-913 tự khoanh vùng: *"MATCH pattern tối
/// đa 3 hop với nhãn và thuộc tính, WHERE, RETURN, ORDER BY/LIMIT, count/collect"*. Bộ này đọc
/// đúng vùng ấy và **từ chối rõ ràng** mọi thứ ngoài vùng — chứ không đọc một nửa rồi chạy ra
/// một kết quả trông hợp lý.
///
/// Đọc được:
///
/// ```cypher
/// MATCH (a:Người)-[r:GỬI]->(b)
/// WHERE a.name STARTS WITH 'Nguyễn' AND b.kind <> 'nháp'
/// RETURN a.name, count(b) AS so_ban
/// ORDER BY so_ban DESC
/// LIMIT 10
/// ```
///
/// KHÔNG đọc: nhiều pattern ngăn bởi dấu phẩy, `OPTIONAL MATCH`, `WITH`, `UNWIND`, `CREATE`,
/// `MERGE`, đường đi độ dài thay đổi `*1..3`, hàm ngoài `count`/`collect`. Mỗi thứ bị từ chối
/// đều có câu nói ra **nó là gì** và **vùng đọc được gồm những gì**.
///
/// ## Vì sao TỪ CHỐI thay vì bỏ qua
///
/// Một truy vấn `MATCH (a), (b) RETURN a` mà bộ đọc lặng lẽ bỏ `(b)` sẽ chạy và trả về một bảng
/// — bảng ấy đúng cho một câu hỏi KHÁC với câu người dùng hỏi. Đó là kiểu hỏng không ai phát
/// hiện, vì không có gì trông sai cả.
public struct CypherQuery: Equatable, Sendable {

    // MARK: - Mẫu

    public struct NodePattern: Equatable, Sendable {
        /// Tên biến. Rỗng = node vô danh, không tham chiếu được trong WHERE/RETURN.
        public var variable: String
        /// Nhãn sau dấu `:`. `nil` = không lọc theo nhãn.
        public var label: String?
        /// Thuộc tính khai trong `{…}`.
        public var properties: [(key: String, value: Value)]

        public static func == (left: NodePattern, right: NodePattern) -> Bool {
            left.variable == right.variable && left.label == right.label
                && left.properties.map(\.key) == right.properties.map(\.key)
                && left.properties.map(\.value) == right.properties.map(\.value)
        }
    }

    public enum Direction: String, Equatable, Sendable {
        /// `-[r]->`
        case forward
        /// `<-[r]-`
        case backward
        /// `-[r]-`
        case any
    }

    public struct EdgePattern: Equatable, Sendable {
        public var variable: String
        /// Loại cạnh sau dấu `:`.
        public var type: String?
        public var direction: Direction
        public var properties: [(key: String, value: Value)]

        public static func == (left: EdgePattern, right: EdgePattern) -> Bool {
            left.variable == right.variable && left.type == right.type
                && left.direction == right.direction
                && left.properties.map(\.key) == right.properties.map(\.key)
                && left.properties.map(\.value) == right.properties.map(\.value)
        }
    }

    // MARK: - Giá trị và điều kiện

    public enum Value: Equatable, Sendable {
        case text(String)
        case number(Double)
        case boolean(Bool)
        case null
    }

    public enum Comparison: String, Equatable, Sendable {
        case equal = "="
        case notEqual = "<>"
        case less = "<"
        case lessOrEqual = "<="
        case greater = ">"
        case greaterOrEqual = ">="
        case contains = "CONTAINS"
        case startsWith = "STARTS WITH"
        case endsWith = "ENDS WITH"
    }

    public indirect enum Condition: Equatable, Sendable {
        case compare(variable: String, property: String, op: Comparison, value: Value)
        case isNull(variable: String, property: String, negated: Bool)
        case and(Condition, Condition)
        case or(Condition, Condition)
        case not(Condition)
    }

    // MARK: - RETURN

    public enum Aggregate: String, Equatable, Sendable {
        case count, collect
    }

    public struct ReturnItem: Equatable, Sendable {
        public var variable: String
        /// `nil` khi trả về chính biến (`RETURN a`) hoặc `count(*)`.
        public var property: String?
        public var aggregate: Aggregate?
        /// `count(*)`
        public var isStar: Bool
        public var alias: String?

        public init(
            variable: String, property: String? = nil, aggregate: Aggregate? = nil,
            isStar: Bool = false, alias: String? = nil
        ) {
            self.variable = variable
            self.property = property
            self.aggregate = aggregate
            self.isStar = isStar
            self.alias = alias
        }

        /// Tên cột hiện ra.
        public var name: String {
            if let alias { return alias }
            if isStar { return "count(*)" }
            if let aggregate {
                return "\(aggregate.rawValue)(\(variable)\(property.map { "." + $0 } ?? ""))"
            }
            return property.map { "\(variable).\($0)" } ?? variable
        }
    }

    public struct Order: Equatable, Sendable {
        public var name: String
        public var descending: Bool
    }

    // MARK: - Truy vấn

    public var nodes: [NodePattern]
    public var edges: [EdgePattern]
    public var condition: Condition?
    public var items: [ReturnItem]
    public var distinct: Bool
    public var orders: [Order]
    public var limit: Int?
    public var skip: Int?

    /// Số hop = số cạnh trong mẫu.
    public var hops: Int { edges.count }

    /// Trần hop CỨNG — đặc tả gọi nó là *"giới hạn hop cứng chống bùng nổ tổ hợp"*.
    ///
    /// Mỗi hop là một phép nối. Trên đồ thị một triệu cạnh, bốn hop không có điều kiện lọc là
    /// một phép nối có thể sinh ra nhiều hàng hơn số nguyên tử trong phòng — và người dùng chỉ
    /// thấy ứng dụng đứng hình. Trần ở đây từ chối TRƯỚC khi chạy, kèm lý do.
    public static let maximumHops = 3

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        /// Vị trí ký tự trong câu truy vấn, để chỉ đúng chỗ.
        public var offset: Int
        public init(message: String, offset: Int = 0) {
            self.message = message
            self.offset = offset
        }
    }

    // MARK: - Phân tích

    public static func parse(_ text: String) throws -> CypherQuery {
        var parser = Parser(text: text)
        return try parser.parse()
    }

    struct Parser {
        let characters: [Character]
        var index = 0

        init(text: String) { characters = Array(text) }

        mutating func parse() throws -> CypherQuery {
            skipSpace()
            try expectKeyword("MATCH", hint: "truy vấn phải bắt đầu bằng MATCH")
            let (nodes, edges) = try pattern()
            guard edges.count <= CypherQuery.maximumHops else {
                throw Failure(message: "mẫu có \(edges.count) hop, vượt trần "
                    + "\(CypherQuery.maximumHops) — trần này chặn bùng nổ tổ hợp TRƯỚC khi "
                    + "chạy, vì mỗi hop là một phép nối và bốn hop không lọc trên đồ thị lớn "
                    + "có thể sinh ra hàng tỉ hàng", offset: index)
            }

            var condition: CypherQuery.Condition?
            skipSpace()
            if matchKeyword("WHERE") { condition = try expression() }

            skipSpace()
            try expectKeyword("RETURN", hint: "thiếu RETURN — truy vấn phải nói nó trả về gì")
            skipSpace()
            let distinct = matchKeyword("DISTINCT")
            let items = try returnItems()

            var orders: [CypherQuery.Order] = []
            skipSpace()
            if matchKeyword("ORDER") {
                skipSpace()
                try expectKeyword("BY", hint: "sau ORDER phải là BY")
                orders = try orderItems()
            }

            var skipCount: Int?
            var limit: Int?
            skipSpace()
            if matchKeyword("SKIP") { skipCount = try integer() }
            skipSpace()
            if matchKeyword("LIMIT") { limit = try integer() }

            skipSpace()
            guard index >= characters.count else {
                throw Failure(message: "còn thừa chữ sau truy vấn: «"
                    + String(characters[index...].prefix(24)) + "»", offset: index)
            }
            return CypherQuery(
                nodes: nodes, edges: edges, condition: condition, items: items,
                distinct: distinct, orders: orders, limit: limit, skip: skipCount)
        }

        // MARK: Mẫu

        mutating func pattern() throws -> ([NodePattern], [EdgePattern]) {
            var nodes: [NodePattern] = [try nodePattern()]
            var edges: [EdgePattern] = []
            while true {
                skipSpace()
                guard let edge = try edgePattern() else { break }
                edges.append(edge)
                nodes.append(try nodePattern())
            }
            skipSpace()
            if peek() == "," {
                throw Failure(message: "chỉ đọc được MỘT mẫu đường đi; nhiều mẫu ngăn bởi dấu "
                    + "phẩy thì chưa đọc được — tách thành nhiều truy vấn", offset: index)
            }
            return (nodes, edges)
        }

        mutating func nodePattern() throws -> NodePattern {
            skipSpace()
            guard peek() == "(" else {
                throw Failure(message: "mong một node dạng `(a)` hoặc `(a:Nhãn)`", offset: index)
            }
            index += 1
            skipSpace()
            let variable = identifier()
            skipSpace()
            var label: String?
            if peek() == ":" {
                index += 1
                label = identifier()
                guard !(label ?? "").isEmpty else {
                    throw Failure(message: "sau dấu `:` phải có tên nhãn", offset: index)
                }
            }
            let properties = try propertyMap()
            skipSpace()
            guard peek() == ")" else {
                throw Failure(message: "thiếu dấu `)` đóng node", offset: index)
            }
            index += 1
            return NodePattern(variable: variable, label: label, properties: properties)
        }

        /// Đọc một cạnh, `nil` khi hết mẫu.
        mutating func edgePattern() throws -> EdgePattern? {
            skipSpace()
            var direction = Direction.forward
            if peek() == "<" {
                guard peek(1) == "-" else {
                    throw Failure(message: "sau `<` phải là `-`", offset: index)
                }
                direction = .backward
                index += 2
            } else if peek() == "-" {
                index += 1
            } else {
                return nil
            }

            var variable = ""
            var type: String?
            var properties: [(key: String, value: Value)] = []
            if peek() == "[" {
                index += 1
                skipSpace()
                variable = identifier()
                skipSpace()
                if peek() == ":" {
                    index += 1
                    type = identifier()
                }
                skipSpace()
                if peek() == "*" {
                    throw Failure(message: "đường đi độ dài thay đổi (`*1..3`) chưa đọc được — "
                        + "viết rõ từng hop, tối đa \(CypherQuery.maximumHops)", offset: index)
                }
                properties = try propertyMap()
                skipSpace()
                guard peek() == "]" else {
                    throw Failure(message: "thiếu dấu `]` đóng cạnh", offset: index)
                }
                index += 1
            }

            guard peek() == "-" else {
                throw Failure(message: "cạnh phải kết thúc bằng `-`, `->` hoặc `-`", offset: index)
            }
            index += 1
            if peek() == ">" {
                guard direction != .backward else {
                    throw Failure(message: "cạnh không thể vừa `<-` vừa `->`", offset: index)
                }
                index += 1
            } else if direction == .forward {
                direction = .any
            }
            return EdgePattern(
                variable: variable, type: type, direction: direction, properties: properties)
        }

        mutating func propertyMap() throws -> [(key: String, value: Value)] {
            skipSpace()
            guard peek() == "{" else { return [] }
            index += 1
            var out: [(key: String, value: Value)] = []
            while true {
                skipSpace()
                if peek() == "}" { index += 1; return out }
                let key = identifier()
                guard !key.isEmpty else {
                    throw Failure(message: "mong tên thuộc tính", offset: index)
                }
                skipSpace()
                guard peek() == ":" else {
                    throw Failure(message: "sau tên thuộc tính phải là `:`", offset: index)
                }
                index += 1
                out.append((key, try value()))
                skipSpace()
                if peek() == "," { index += 1; continue }
                guard peek() == "}" else {
                    throw Failure(message: "thiếu `,` hoặc `}`", offset: index)
                }
            }
        }

        // MARK: WHERE

        mutating func expression() throws -> Condition {
            var left = try andExpression()
            while true {
                skipSpace()
                guard matchKeyword("OR") else { return left }
                left = .or(left, try andExpression())
            }
        }

        mutating func andExpression() throws -> Condition {
            var left = try unary()
            while true {
                skipSpace()
                guard matchKeyword("AND") else { return left }
                left = .and(left, try unary())
            }
        }

        mutating func unary() throws -> Condition {
            skipSpace()
            if matchKeyword("NOT") { return .not(try unary()) }
            if peek() == "(" {
                index += 1
                let inner = try expression()
                skipSpace()
                guard peek() == ")" else {
                    throw Failure(message: "thiếu `)` đóng nhóm điều kiện", offset: index)
                }
                index += 1
                return inner
            }
            return try comparison()
        }

        mutating func comparison() throws -> Condition {
            skipSpace()
            let variable = identifier()
            guard !variable.isEmpty else {
                throw Failure(message: "mong một điều kiện dạng `a.thuoc_tinh = 'giá trị'`",
                              offset: index)
            }
            guard peek() == "." else {
                throw Failure(message: "điều kiện phải nói rõ thuộc tính: `\(variable).ten`",
                              offset: index)
            }
            index += 1
            let property = identifier()
            guard !property.isEmpty else {
                throw Failure(message: "sau dấu `.` phải có tên thuộc tính", offset: index)
            }
            skipSpace()

            if matchKeyword("IS") {
                skipSpace()
                let negated = matchKeyword("NOT")
                skipSpace()
                guard matchKeyword("NULL") else {
                    throw Failure(message: "sau IS phải là NULL hoặc NOT NULL", offset: index)
                }
                return .isNull(variable: variable, property: property, negated: negated)
            }
            if matchKeyword("STARTS") {
                skipSpace()
                try expectKeyword("WITH", hint: "sau STARTS phải là WITH")
                return .compare(variable: variable, property: property,
                                op: .startsWith, value: try value())
            }
            if matchKeyword("ENDS") {
                skipSpace()
                try expectKeyword("WITH", hint: "sau ENDS phải là WITH")
                return .compare(variable: variable, property: property,
                                op: .endsWith, value: try value())
            }
            if matchKeyword("CONTAINS") {
                return .compare(variable: variable, property: property,
                                op: .contains, value: try value())
            }
            let op = try comparisonOperator()
            return .compare(variable: variable, property: property, op: op, value: try value())
        }

        mutating func comparisonOperator() throws -> Comparison {
            skipSpace()
            for candidate in ["<>", "<=", ">=", "=", "<", ">"] where matchSymbol(candidate) {
                return Comparison(rawValue: candidate)!
            }
            throw Failure(message: "mong một phép so sánh: = <> < <= > >= CONTAINS "
                + "«STARTS WITH» «ENDS WITH» «IS NULL»", offset: index)
        }

        // MARK: RETURN

        mutating func returnItems() throws -> [ReturnItem] {
            var out: [ReturnItem] = []
            while true {
                out.append(try returnItem())
                skipSpace()
                if peek() == "," { index += 1; continue }
                guard !out.isEmpty else {
                    throw Failure(message: "RETURN phải nêu ít nhất một thứ", offset: index)
                }
                return out
            }
        }

        mutating func returnItem() throws -> ReturnItem {
            skipSpace()
            let head = identifier()
            guard !head.isEmpty else {
                throw Failure(message: "mong tên biến hoặc `count(...)`/`collect(...)`",
                              offset: index)
            }
            var item: ReturnItem
            if peek() == "(" {
                guard let aggregate = Aggregate(rawValue: head.lowercased()) else {
                    throw Failure(message: "hàm «\(head)» chưa đọc được — chỉ có count và "
                        + "collect", offset: index)
                }
                index += 1
                skipSpace()
                if peek() == "*" {
                    index += 1
                    item = ReturnItem(variable: "", aggregate: aggregate, isStar: true)
                } else {
                    let variable = identifier()
                    var property: String?
                    if peek() == "." {
                        index += 1
                        property = identifier()
                    }
                    item = ReturnItem(
                        variable: variable, property: property, aggregate: aggregate)
                }
                skipSpace()
                guard peek() == ")" else {
                    throw Failure(message: "thiếu `)` đóng hàm", offset: index)
                }
                index += 1
            } else if peek() == "." {
                index += 1
                item = ReturnItem(variable: head, property: identifier())
            } else {
                item = ReturnItem(variable: head)
            }
            skipSpace()
            if matchKeyword("AS") {
                skipSpace()
                let alias = identifier()
                guard !alias.isEmpty else {
                    throw Failure(message: "sau AS phải có tên cột", offset: index)
                }
                item.alias = alias
            }
            return item
        }

        mutating func orderItems() throws -> [Order] {
            var out: [Order] = []
            while true {
                skipSpace()
                var name = identifier()
                guard !name.isEmpty else {
                    throw Failure(message: "ORDER BY phải nêu tên cột", offset: index)
                }
                if peek() == "." {
                    index += 1
                    name += "." + identifier()
                }
                skipSpace()
                var descending = false
                if matchKeyword("DESC") { descending = true }
                else { _ = matchKeyword("ASC") }
                out.append(Order(name: name, descending: descending))
                skipSpace()
                if peek() == "," { index += 1; continue }
                return out
            }
        }

        // MARK: Từ vựng

        mutating func value() throws -> Value {
            skipSpace()
            if peek() == "'" || peek() == "\"" {
                let quote = peek()!
                index += 1
                var out = ""
                while index < characters.count {
                    let character = characters[index]
                    if character == "\\", index + 1 < characters.count {
                        out.append(characters[index + 1])
                        index += 2
                        continue
                    }
                    if character == quote { index += 1; return .text(out) }
                    out.append(character)
                    index += 1
                }
                throw Failure(message: "chuỗi chưa đóng", offset: index)
            }
            if matchKeyword("TRUE") { return .boolean(true) }
            if matchKeyword("FALSE") { return .boolean(false) }
            if matchKeyword("NULL") { return .null }
            var text = ""
            if peek() == "-" { text = "-"; index += 1 }
            while let character = peek(), character.isNumber || character == "." {
                text.append(character)
                index += 1
            }
            guard let number = Double(text) else {
                throw Failure(message: "mong một giá trị: chuỗi trong nháy, số, true/false, "
                    + "hoặc null", offset: index)
            }
            return .number(number)
        }

        mutating func integer() throws -> Int {
            skipSpace()
            var text = ""
            while let character = peek(), character.isNumber {
                text.append(character)
                index += 1
            }
            guard let number = Int(text) else {
                throw Failure(message: "mong một số nguyên", offset: index)
            }
            return number
        }

        mutating func identifier() -> String {
            skipSpace()
            var out = ""
            // Backtick cho tên có khoảng trắng hoặc dấu — `MATCH (a:`Người dùng`)`.
            if peek() == "`" {
                index += 1
                while index < characters.count, characters[index] != "`" {
                    out.append(characters[index])
                    index += 1
                }
                if index < characters.count { index += 1 }
                return out
            }
            while let character = peek(),
                  character.isLetter || character.isNumber || character == "_" {
                out.append(character)
                index += 1
            }
            return out
        }

        func peek(_ ahead: Int = 0) -> Character? {
            let position = index + ahead
            return position < characters.count ? characters[position] : nil
        }

        mutating func skipSpace() {
            while let character = peek(), character.isWhitespace { index += 1 }
        }

        mutating func matchSymbol(_ text: String) -> Bool {
            let symbol = Array(text)
            guard index + symbol.count <= characters.count else { return false }
            for (offset, character) in symbol.enumerated()
            where characters[index + offset] != character { return false }
            index += symbol.count
            return true
        }

        /// Khớp một từ khoá KHÔNG phân biệt hoa thường, và chỉ khi nó là NGUYÊN một từ.
        ///
        /// Vế thứ hai đáng giá: không có nó thì `MATCH (android)` bị đọc thành từ khoá `AND`
        /// cộng một mẩu `roid`, và lỗi báo ra sẽ nói về một thứ chẳng liên quan.
        mutating func matchKeyword(_ word: String) -> Bool {
            skipSpace()
            let letters = Array(word)
            guard index + letters.count <= characters.count else { return false }
            for (offset, character) in letters.enumerated()
            where String(characters[index + offset]).lowercased()
                != String(character).lowercased() { return false }
            let after = index + letters.count
            if after < characters.count {
                let next = characters[after]
                if next.isLetter || next.isNumber || next == "_" { return false }
            }
            index = after
            return true
        }

        mutating func expectKeyword(_ word: String, hint: String) throws {
            guard matchKeyword(word) else {
                throw Failure(message: hint, offset: index)
            }
        }
    }
}
