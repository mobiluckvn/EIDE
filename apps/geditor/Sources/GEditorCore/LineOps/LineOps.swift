import Foundation

/// Thao tác hàng loạt trên dòng (FR-CORE-005…010).
///
/// Quy ước bắt buộc: MỌI hàm ở đây trả về `[TextEdit]` chứ không tự sửa buffer.
/// Lớp gọi truyền cả mảng vào `TextBuffer.applyEdits(_:label:)` → một bước undo
/// (FR-CORE-004). Không hàm nào được phép gọi UI hay I/O.
public enum LineOps {

    public enum SortKind {
        /// Từ điển theo byte.
        case lexicographic(caseSensitive: Bool)
        /// So sánh số (nguyên và thực); dòng không phải số xếp sau.
        case numeric
        /// Natural sort: file1 < file2 < file10.
        case natural
    }

    public enum TrimSide {
        case leading, trailing, both
    }

    // MARK: - Sắp xếp (FR-CORE-005)

    /// Sắp xếp các dòng trong `lines` (mảng nội dung dòng, không gồm EOL).
    ///
    /// - Parameter column: sắp theo cột thứ N (0-based) sau khi tách bằng `delimiter`;
    ///   `nil` = sắp theo cả dòng.
    public static func sort(
        lines: [String],
        kind: SortKind,
        ascending: Bool = true,
        column: Int? = nil,
        delimiter: Character = ","
    ) -> [String] {
        func key(_ line: String) -> String {
            guard let column else { return line }
            let parts = line.split(separator: delimiter, omittingEmptySubsequences: false)
            return column < parts.count ? String(parts[column]) : ""
        }

        let sorted = lines.enumerated().sorted { a, b in
            let ka = key(a.element), kb = key(b.element)
            let result = compare(ka, kb, kind: kind)
            if result == 0 { return a.offset < b.offset }  // ổn định
            return ascending ? result < 0 : result > 0
        }
        return sorted.map(\.element)
    }

    /// So sánh hai khóa sắp xếp.
    ///
    /// Không `private` vì `DocumentOps` phải dùng lại đúng phép so sánh này khi sắp theo cột
    /// CSV — nó tự trích khóa bằng parser RFC 4180 (tách bằng `split` sẽ vỡ field bọc ngoặc
    /// kép có chứa dấu phẩy), nhưng thứ tự thì phải giống hệt để hai đường không lệch nhau.
    static func compare(_ a: String, _ b: String, kind: SortKind) -> Int {
        switch kind {
        case .lexicographic(let caseSensitive):
            let lhs = caseSensitive ? a : a.lowercased()
            let rhs = caseSensitive ? b : b.lowercased()
            if lhs == rhs { return 0 }
            return lhs < rhs ? -1 : 1

        case .numeric:
            let na = Double(a.trimmingCharacters(in: .whitespaces))
            let nb = Double(b.trimmingCharacters(in: .whitespaces))
            switch (na, nb) {
            case let (x?, y?): return x == y ? 0 : (x < y ? -1 : 1)
            case (nil, _?): return 1     // không phải số → xếp sau
            case (_?, nil): return -1
            default: return compare(a, b, kind: .lexicographic(caseSensitive: true))
            }

        case .natural:
            return naturalCompare(a, b)
        }
    }

    /// So sánh natural: chuỗi số liền nhau được so theo giá trị.
    static func naturalCompare(_ a: String, _ b: String) -> Int {
        var i = a.startIndex, j = b.startIndex
        while i < a.endIndex && j < b.endIndex {
            let ca = a[i], cb = b[j]
            if ca.isNumber && cb.isNumber {
                var na = "", nb = ""
                while i < a.endIndex, a[i].isNumber { na.append(a[i]); i = a.index(after: i) }
                while j < b.endIndex, b[j].isNumber { nb.append(b[j]); j = b.index(after: j) }
                let va = Int(na) ?? 0, vb = Int(nb) ?? 0
                if va != vb { return va < vb ? -1 : 1 }
            } else {
                if ca != cb { return ca < cb ? -1 : 1 }
                i = a.index(after: i)
                j = b.index(after: j)
            }
        }
        if i == a.endIndex && j == b.endIndex { return 0 }
        return i == a.endIndex ? -1 : 1
    }

    // MARK: - Khử trùng lặp (FR-CORE-006)

    public enum DedupScope {
        /// Xóa mọi dòng trùng trên toàn tài liệu.
        case whole
        /// Chỉ gộp các dòng trùng LIỀN NHAU (như `uniq`).
        case consecutive
    }

    public enum DedupKeep {
        case first, last
    }

    /// Trả về chỉ số các dòng CẦN XÓA.
    public static func duplicateLineIndices(
        lines: [String],
        scope: DedupScope = .whole,
        keep: DedupKeep = .first
    ) -> [Int] {
        switch scope {
        case .consecutive:
            var remove: [Int] = []
            for i in 1 ..< max(lines.count, 1) where lines[i] == lines[i - 1] {
                remove.append(keep == .first ? i : i - 1)
            }
            return remove.sorted()

        case .whole:
            var seen: [String: Int] = [:]
            var remove = Set<Int>()
            for (i, line) in lines.enumerated() {
                if let previous = seen[line] {
                    remove.insert(keep == .first ? i : previous)
                    if keep == .last { seen[line] = i }
                } else {
                    seen[line] = i
                }
            }
            return remove.sorted()
        }
    }

    // MARK: - Khoảng trắng (FR-CORE-008)

    public static func trim(_ line: String, side: TrimSide = .both) -> String {
        var s = Substring(line)
        if side == .leading || side == .both {
            while let c = s.first, c == " " || c == "\t" { s = s.dropFirst() }
        }
        if side == .trailing || side == .both {
            while let c = s.last, c == " " || c == "\t" { s = s.dropLast() }
        }
        return String(s)
    }

    /// Dòng rỗng theo nghĩa FR-CORE-008: rỗng hoặc chỉ chứa khoảng trắng.
    public static func isBlank(_ line: String) -> Bool {
        line.allSatisfy { $0 == " " || $0 == "\t" }
    }

    // MARK: - TAB ↔ Space (FR-CORE-009)

    /// Đổi tab thành space theo tab stop, giữ nguyên hình thức thụt lề.
    public static func tabsToSpaces(_ line: String, tabWidth: Int) -> String {
        precondition(tabWidth > 0)
        var out = ""
        var column = 0
        for ch in line {
            if ch == "\t" {
                let pad = tabWidth - (column % tabWidth)
                out += String(repeating: " ", count: pad)
                column += pad
            } else {
                out.append(ch)
                column += 1
            }
        }
        return out
    }

    /// Đổi space thành tab ở phần THỤT LỀ ĐẦU DÒNG.
    ///
    /// Không đụng tới space giữa dòng: gộp chúng thành tab sẽ phá dữ liệu (ví dụ
    /// văn bản căn cột, chuỗi trong mã nguồn). TC-CORE-12 kiểm round-trip.
    public static func spacesToTabs(_ line: String, tabWidth: Int) -> String {
        precondition(tabWidth > 0)
        var indentWidth = 0
        var index = line.startIndex
        loop: while index < line.endIndex {
            switch line[index] {
            case " ": indentWidth += 1
            case "\t": indentWidth += tabWidth - (indentWidth % tabWidth)
            default: break loop
            }
            index = line.index(after: index)
        }
        let tabs = indentWidth / tabWidth
        let spaces = indentWidth % tabWidth
        return String(repeating: "\t", count: tabs)
            + String(repeating: " ", count: spaces)
            + String(line[index...])
    }

    // MARK: - Ghép và tách dòng (FR-CORE-007)

    /// Ghép nhiều dòng thành một.
    ///
    /// Mặc định KHÔNG chèn gì vào giữa, giống Ctrl+J của Notepad++ — sản phẩm này lấy
    /// Notepad++ làm mốc tương đương. Người dùng ghép prose bị xuống dòng thì truyền `" "`.
    /// Chèn dấu cách mặc định sẽ làm hỏng đúng trường hợp hay gặp nhất: một hàng CSV bị cắt
    /// làm đôi, ghép lại phải liền y như cũ.
    public static func join(_ lines: [String], separator: String = "") -> String {
        lines.joined(separator: separator)
    }

    /// Tách một dòng dài thành nhiều dòng, mỗi dòng tối đa `length` KÝ TỰ.
    ///
    /// Đếm theo ký tự chứ không theo byte: "Nguyễn" là 6 ký tự nhưng 9 byte, và người dùng
    /// đặt giới hạn 80 là nói về thứ họ nhìn thấy trên màn hình.
    ///
    /// `atWordBoundary` lùi về khoảng trắng gần nhất để không cắt giữa từ. Không tìm thấy
    /// khoảng trắng nào thì vẫn cắt cứng — thà một dòng xấu còn hơn một dòng dài vô hạn.
    public static func split(_ line: String, atLength length: Int, atWordBoundary: Bool = true) -> [String] {
        guard length > 0, line.count > length else { return [line] }

        var pieces: [String] = []
        var rest = Substring(line)
        while rest.count > length {
            let hardLimit = rest.index(rest.startIndex, offsetBy: length)
            var cut = hardLimit
            if atWordBoundary,
               let space = rest[rest.startIndex ..< hardLimit].lastIndex(where: { $0 == " " || $0 == "\t" }),
               space > rest.startIndex {
                cut = space
            }
            pieces.append(String(rest[rest.startIndex ..< cut]))
            // Nuốt đúng MỘT khoảng trắng ở chỗ cắt: nó là chỗ ngắt, không phải nội dung.
            rest = rest[cut...]
            if atWordBoundary, let first = rest.first, first == " " || first == "\t" {
                rest = rest.dropFirst()
            }
        }
        if !rest.isEmpty || pieces.isEmpty { pieces.append(String(rest)) }
        return pieces
    }

    /// Tách một dòng tại MỌI lần xuất hiện của `character`.
    ///
    /// Ký tự tách bị BỎ ĐI, không giữ lại ở cuối dòng: người dùng tách một hàng CSV thành
    /// từng field thì không muốn dấu phẩy còn dính lại.
    public static func split(_ line: String, at character: Character) -> [String] {
        line.split(separator: character, omittingEmptySubsequences: false).map(String.init)
    }

    // MARK: - Hoa/thường & kiểu định danh (FR-CORE-010)

    public enum CaseStyle {
        case upper, lower, proper, sentence, invert
        case camel, snake, kebab
    }

    public static func convertCase(_ text: String, to style: CaseStyle) -> String {
        switch style {
        case .upper: return text.uppercased()
        case .lower: return text.lowercased()
        case .proper: return text.capitalized
        case .sentence:
            guard let first = text.first else { return text }
            return String(first).uppercased() + text.dropFirst().lowercased()
        case .invert:
            return String(text.map { c in
                c.isUppercase ? Character(c.lowercased()) : Character(c.uppercased())
            })
        case .camel, .snake, .kebab:
            let words = identifierWords(text)
            guard !words.isEmpty else { return text }
            switch style {
            case .camel:
                return words[0].lowercased()
                    + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
            case .snake:
                return words.map { $0.lowercased() }.joined(separator: "_")
            default:
                return words.map { $0.lowercased() }.joined(separator: "-")
            }
        }
    }

    /// Tách định danh thành từ: camelCase, snake_case, kebab-case, "chữ thường".
    static func identifierWords(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        for ch in text {
            if ch == "_" || ch == "-" || ch == " " {
                if !current.isEmpty { words.append(current); current = "" }
            } else if ch.isUppercase, !current.isEmpty, current.last?.isUppercase == false {
                words.append(current)
                current = String(ch)
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}
