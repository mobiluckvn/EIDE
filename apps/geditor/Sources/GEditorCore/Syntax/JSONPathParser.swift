import Foundation

/// Đọc chuỗi truy vấn JSONPath thành danh sách bước.
///
/// Tách khỏi `JSONPath.swift` vì hai việc khác nhau: tệp kia CHẠY truy vấn trên dữ liệu, tệp
/// này chỉ đọc chính chuỗi truy vấn. Mọi lỗi ở đây đều kèm vị trí ký tự, để ô nhập chỉ được
/// đúng chỗ người dùng gõ sai thay vì nói chung chung "truy vấn không hợp lệ".
extension JSONPath {

    static func parse(_ query: String) throws -> [Step] {
        var reader = QueryReader(query)
        return try reader.run()
    }

    struct QueryReader {
        let chars: [Character]
        var index = 0

        init(_ query: String) { chars = Array(query) }

        mutating func run() throws -> [Step] {
            skipSpace()
            guard peek() == "$" else {
                throw Failure.syntax(message: "Truy vấn phải bắt đầu bằng $", offset: index)
            }
            index += 1

            var steps: [Step] = []
            while true {
                skipSpace()
                guard let char = peek() else { break }
                switch char {
                case ".":
                    index += 1
                    if peek() == "." {
                        index += 1
                        steps.append(try descendantStep())
                    } else if peek() == "*" {
                        index += 1
                        steps.append(.wildcard)
                    } else {
                        steps.append(.names([try readBareName()]))
                    }
                case "[":
                    index += 1
                    steps.append(try bracketStep())
                default:
                    throw Failure.syntax(
                        message: "Chỗ này phải là `.` hoặc `[`, không phải `\(char)`", offset: index
                    )
                }
            }
            return steps
        }

        /// Sau `..`: có thể là tên, `*`, hoặc `[...]`.
        private mutating func descendantStep() throws -> Step {
            if peek() == "*" {
                index += 1
                return .descendant(name: nil)
            }
            if peek() == "[" {
                // `$..[0]` và `$..[?(...)]` cần hai bước: gom hết con cháu rồi lọc. Ở đây trả
                // bước gom, còn `[` sẽ được vòng lặp chính đọc ở lượt sau.
                return .descendant(name: nil)
            }
            return .descendant(name: try readBareName())
        }

        private mutating func bracketStep() throws -> Step {
            skipSpace()
            guard let char = peek() else {
                throw Failure.syntax(message: "Thiếu `]`", offset: index)
            }

            if char == "*" {
                index += 1
                try expect("]")
                return .wildcard
            }
            if char == "?" {
                index += 1
                let filter = try readFilter()
                try expect("]")
                return .filter(filter)
            }
            if char == "'" || char == "\"" {
                var names: [String] = []
                while true {
                    skipSpace()
                    names.append(try readQuotedName())
                    skipSpace()
                    if peek() == "," { index += 1; continue }
                    break
                }
                try expect("]")
                return .names(names)
            }
            if char == "(" {
                throw Failure.unsupported("biểu thức script `[(...)]`")
            }
            return try readIndexOrSlice()
        }

        /// `[0]`, `[-1]`, `[0,2]`, `[1:5]`, `[::2]`.
        private mutating func readIndexOrSlice() throws -> Step {
            var parts: [Int?] = []
            var current: Int?
            var sawColon = false
            var sawDigit = false

            loop: while true {
                skipSpace()
                guard let char = peek() else { throw Failure.syntax(message: "Thiếu `]`", offset: index) }
                switch char {
                case "-", "0"..."9":
                    current = try readInteger()
                    sawDigit = true
                case ":":
                    index += 1
                    sawColon = true
                    parts.append(current)
                    current = nil
                case ",":
                    guard !sawColon else {
                        throw Failure.unsupported("dấu phẩy bên trong lát cắt")
                    }
                    index += 1
                    parts.append(current)
                    current = nil
                case "]":
                    break loop
                default:
                    throw Failure.syntax(
                        message: "Không đọc được `\(char)` bên trong `[...]`", offset: index
                    )
                }
            }
            try expect("]")
            parts.append(current)

            guard sawDigit || sawColon else {
                throw Failure.syntax(message: "`[]` rỗng", offset: index)
            }
            if sawColon {
                guard parts.count <= 3 else {
                    throw Failure.syntax(message: "Lát cắt nhiều nhất ba phần `[a:b:c]`", offset: index)
                }
                return .slice(
                    from: parts.count > 0 ? parts[0] : nil,
                    to: parts.count > 1 ? parts[1] : nil,
                    step: parts.count > 2 ? parts[2] : nil
                )
            }
            return .indices(parts.compactMap { $0 })
        }

        // MARK: - Lọc

        /// `?(@.gia > 100000)` hoặc `?(@.co_san)`.
        private mutating func readFilter() throws -> Filter {
            skipSpace()
            try expect("(")
            skipSpace()
            guard peek() == "@" else {
                throw Failure.syntax(message: "Bộ lọc phải bắt đầu bằng `@`", offset: index)
            }
            index += 1

            var path: [String] = []
            while peek() == "." || peek() == "[" {
                if peek() == "." {
                    index += 1
                    path.append(try readBareName())
                } else {
                    index += 1
                    skipSpace()
                    path.append(try readQuotedName())
                    skipSpace()
                    try expect("]")
                }
            }

            skipSpace()
            if peek() == ")" {
                index += 1
                return .exists(path: path)
            }
            if peek() == "&" || peek() == "|" {
                throw Failure.unsupported("nhiều điều kiện `&&` `||` trong một bộ lọc")
            }

            let op = try readComparison()
            skipSpace()
            let literal = try readLiteral()
            skipSpace()
            // Kiểm `&&` ở CẢ HAI phía của phép so sánh. Chỉ kiểm phía trước thì
            // `?(@.a > 1 && @.b < 2)` sẽ báo "Thiếu `)`" — đúng về mặt kỹ thuật nhưng gửi
            // người dùng đi đếm dấu ngoặc thay vì cho biết thứ họ viết là chưa làm.
            if peek() == "&" || peek() == "|" {
                throw Failure.unsupported("nhiều điều kiện `&&` `||` trong một bộ lọc")
            }
            try expect(")")
            return .compare(path: path, op: op, literal: literal)
        }

        private mutating func readComparison() throws -> Comparison {
            // Đọc hai ký tự TRƯỚC một ký tự: `<=` phải thắng `<`, nếu không thì `<=` sẽ được
            // hiểu là `<` rồi `=` thành rác và lỗi báo sai chỗ.
            for candidate in ["==", "!=", "<=", ">="] where matches(candidate) {
                index += 2
                return Comparison(rawValue: candidate)!
            }
            for candidate in ["<", ">"] where matches(candidate) {
                index += 1
                return Comparison(rawValue: candidate)!
            }
            if matches("=") {
                throw Failure.syntax(message: "So sánh bằng viết là `==`, không phải `=`", offset: index)
            }
            if matches("=~") {
                throw Failure.unsupported("so khớp biểu thức chính quy `=~`")
            }
            throw Failure.syntax(message: "Thiếu phép so sánh", offset: index)
        }

        private mutating func readLiteral() throws -> Literal {
            guard let char = peek() else {
                throw Failure.syntax(message: "Thiếu giá trị để so sánh", offset: index)
            }
            if char == "'" || char == "\"" { return .string(try readQuotedName()) }
            if matchesWord("true") { index += 4; return .bool(true) }
            if matchesWord("false") { index += 5; return .bool(false) }
            if matchesWord("null") { index += 4; return .null }

            let start = index
            if peek() == "-" || peek() == "+" { index += 1 }
            while let c = peek(), c.isNumber || c == "." || c == "e" || c == "E" || c == "-" || c == "+" {
                index += 1
            }
            let text = String(chars[start ..< index])
            guard let value = Double(text) else {
                throw Failure.syntax(message: "Không đọc được `\(text)` là số", offset: start)
            }
            return .number(value)
        }

        // MARK: - Mảnh nhỏ

        private mutating func readBareName() throws -> String {
            let start = index
            while let char = peek(),
                  char.isLetter || char.isNumber || char == "_" || char == "-" {
                index += 1
            }
            guard index > start else {
                throw Failure.syntax(message: "Thiếu tên khóa sau dấu chấm", offset: index)
            }
            return String(chars[start ..< index])
        }

        private mutating func readQuotedName() throws -> String {
            guard let quote = peek(), quote == "'" || quote == "\"" else {
                throw Failure.syntax(message: "Tên khóa phải nằm trong dấu nháy", offset: index)
            }
            index += 1
            var out = ""
            while let char = peek() {
                if char == "\\", index + 1 < chars.count {
                    out.append(chars[index + 1])
                    index += 2
                    continue
                }
                if char == quote {
                    index += 1
                    return out
                }
                out.append(char)
                index += 1
            }
            throw Failure.syntax(message: "Thiếu dấu nháy đóng", offset: index)
        }

        private mutating func readInteger() throws -> Int {
            let start = index
            if peek() == "-" { index += 1 }
            while let char = peek(), char.isNumber { index += 1 }
            guard let value = Int(String(chars[start ..< index])) else {
                throw Failure.syntax(message: "Không đọc được số", offset: start)
            }
            return value
        }

        private func peek() -> Character? { index < chars.count ? chars[index] : nil }

        private func matches(_ text: String) -> Bool {
            let needle = Array(text)
            guard index + needle.count <= chars.count else { return false }
            return Array(chars[index ..< (index + needle.count)]) == needle
        }

        /// Như `matches` nhưng đòi ranh giới từ: `nullable` không được đọc thành `null`.
        private func matchesWord(_ text: String) -> Bool {
            guard matches(text) else { return false }
            let after = index + text.count
            guard after < chars.count else { return true }
            return !(chars[after].isLetter || chars[after].isNumber || chars[after] == "_")
        }

        private mutating func expect(_ char: Character) throws {
            skipSpace()
            guard peek() == char else {
                throw Failure.syntax(message: "Thiếu `\(char)`", offset: index)
            }
            index += 1
        }

        private mutating func skipSpace() {
            while let char = peek(), char == " " || char == "\t" { index += 1 }
        }
    }
}

/// Bảng dòng, để đổi khoảng byte thành số dòng.
///
/// Dựng một lần cho cả tập kết quả: đếm lại từ đầu cho từng kết quả là O(n×m), và với một file
/// vài MB có vài nghìn kết quả thì đó là vài giây đứng hình.
struct LineTable {
    private let starts: [Int]

    init(bytes: [UInt8]) {
        var starts = [0]
        for (offset, byte) in bytes.enumerated() where byte == 0x0A { starts.append(offset + 1) }
        self.starts = starts
    }

    func line(at offset: Int) -> Int {
        var low = 0
        var high = starts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }
}
