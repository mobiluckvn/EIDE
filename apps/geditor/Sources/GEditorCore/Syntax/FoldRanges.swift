import Foundation

/// Một vùng gấp được: dòng đầu vẫn hiện, phần thân bị giấu.
///
/// Đơn vị là DÒNG chứ không phải byte tùy ý. Gấp giữa dòng nghe có vẻ tổng quát hơn nhưng nó
/// làm hỏng mọi phép quy đổi vị trí: con nháy, vùng chọn, tô màu và cả số dòng ở thanh trạng
/// thái đều tính theo dòng. Gấp theo dòng thì `TextWindow` chỉ việc bỏ bớt vài mốc dòng, còn
/// gấp giữa dòng thì phải viết lại cả tầng quy đổi.
public struct FoldRange: Equatable, Sendable {

    public enum Kind: String, Equatable, Sendable {
        /// Khối con thụt sâu hơn dòng đầu — YAML, Python, và bất cứ ngôn ngữ nào dùng thụt lề.
        case indentation
        /// `[section]` của TOML/INI.
        case section
        /// Object và mảng JSON, lấy từ `JSONIndex` nên biên chính xác tuyệt đối.
        case brackets
        /// Cặp thẻ XML/HTML.
        case tag
    }

    /// Dòng chứa phần đầu. Dòng này KHÔNG bị giấu — nó là chỗ để bấm mở lại.
    public let headerLine: Int
    /// Dòng cuối cùng bị giấu.
    ///
    /// Với JSON thì đây là dòng chứa dấu ĐÓNG, và nó cũng biến mất khi gấp. Gấp theo dòng thì
    /// `},` không thể vừa bị giấu vừa hiện ra. Trình soạn thảo khác giấu từ sau `{` tới trước
    /// `}` để còn hiện `{⋯}` trên một dòng, nhưng đó là gấp GIỮA DÒNG — xem ghi chú ở đầu kiểu
    /// này để biết vì sao chỗ này không đi đường ấy.
    public let lastLine: Int
    /// Khoảng BYTE bị giấu: TRỌN các dòng từ `headerLine + 1` tới `lastLine`, kể cả ký tự
    /// xuống dòng cuối cùng.
    ///
    /// Bắt đầu từ đầu dòng KẾ, không phải từ cuối nội dung dòng đầu. Cắt từ cuối nội dung sẽ
    /// nuốt luôn ký tự xuống dòng của chính dòng đầu, và hai dòng còn lại dính liền thành
    /// `a:b: 3`.
    public let hiddenBytes: Range<Int>

    /// Chỗ con nháy đậu khi nó vốn nằm trong phần bị giấu: cuối nội dung dòng đầu.
    ///
    /// Phải có một quy ước rõ ràng, vì con nháy KHÔNG thể ở trong chữ đã giấu. Đưa nó về cuối
    /// dòng đầu là chỗ gần nhất mà người dùng còn nhìn thấy.
    public let caretHome: Int

    public let kind: Kind

    public var lineCount: Int { lastLine - headerLine }

    public init(headerLine: Int, lastLine: Int, hiddenBytes: Range<Int>, caretHome: Int, kind: Kind) {
        self.headerLine = headerLine
        self.lastLine = lastLine
        self.hiddenBytes = hiddenBytes
        self.caretHome = caretHome
        self.kind = kind
    }
}

/// Tính các vùng gấp được của một tài liệu.
///
/// **Chỉ đọc.** Không hàm nào ở đây sinh ra sửa đổi.
///
/// Bốn cách tính, chọn theo ngôn ngữ:
///
/// | | |
/// |---|---|
/// | thụt lề | YAML, Python |
/// | mục `[…]` | TOML, INI |
/// | cấu trúc JSON | JSON — biên lấy từ `JSONIndex` nên chính xác tuyệt đối |
/// | cặp thẻ | XML, HTML — quét dung thứ, xem `byTags` |
/// | cây cú pháp | mọi ngôn ngữ còn lại — xem `byTree` |
public enum FoldRanges {

    /// Trần kích thước, cùng lý do với `DocumentOutline.sizeLimit`: tính vùng gấp phải đọc
    /// TOÀN tài liệu, và trên file hàng trăm MB thì danh sách vùng gấp cũng lớn tới mức vô dụng.
    public static let sizeLimit = DocumentOutline.sizeLimit

    /// Vùng gấp cho một tài liệu, chọn cách tính theo ngôn ngữ.
    ///
    /// Trả mảng rỗng khi không biết cách gấp — im lặng ở đây là đúng, vì "ngôn ngữ này chưa hỗ
    /// trợ gấp" không phải một lỗi người dùng cần xử lý.
    public static func compute(
        in buffer: TextBuffer, language: SyntaxLanguage?
    ) -> [FoldRange] {
        guard buffer.count <= sizeLimit else { return [] }

        switch language {
        case .json:
            return byJSONStructure(in: buffer)
        case .xml, .html:
            return byTags(in: buffer)
        case .toml:
            return bySection(in: buffer)
        case .yaml, .python:
            return byIndentation(in: buffer)
        case .none:
            return []
        case .some(let other):
            // Mọi ngôn ngữ còn lại đi qua CÂY CÚ PHÁP. Không có bảng luật theo ngôn ngữ: một
            // khối gấp được là một nút mở và đóng bằng cặp ngoặc khớp — xem `byTree`.
            return byTree(in: buffer, language: other)
        }
    }

    // MARK: - Cấp lồng (FR-FMT-503 — "fold theo cấp")

    /// Cấp lồng của từng vùng, **0 là ngoài cùng**, cùng thứ tự với mảng đưa vào.
    ///
    /// Cấp của một vùng là SỐ vùng bao nó, không phải độ sâu thụt lề của dòng đầu. Hai thứ ấy
    /// khác nhau ở đúng chỗ hay gặp nhất: một hàm thụt 8 dấu cách vì nằm trong `if` nằm trong
    /// `for` vẫn có thể là khối gấp được cấp 1 nếu hai cái kia không sinh ra vùng gấp nào. Người
    /// dùng bấm "gấp cấp 2" thì họ nói về cái CÂY họ nhìn thấy ở lề trái, không nói về dấu cách.
    ///
    /// Bao nhau xét theo DÒNG chứ không theo byte: `hiddenBytes` bắt đầu từ dòng KẾ dòng đầu,
    /// nên hai vùng có chung dòng đầu (không xảy ra với bốn bộ tính hiện có, nhưng bộ thứ năm
    /// thì chưa biết) sẽ không bao nhau theo byte dù rõ ràng một cái nằm trong cái kia.
    public static func levels(of folds: [FoldRange]) -> [Int] {
        folds.map { fold in
            folds.reduce(into: 0) { depth, other in
                guard other != fold else { return }
                if other.headerLine <= fold.headerLine && fold.lastLine <= other.lastLine
                    && other.lineCount > fold.lineCount {
                    depth += 1
                }
            }
        }
    }

    /// Các vùng ở đúng một cấp. `level` đếm từ **1**, như "Collapse Level 1…8" của Notepad++.
    ///
    /// Trả về vùng ở ĐÚNG cấp ấy chứ không phải "cấp ấy trở vào": gấp luôn phần bên trong thì
    /// phần bị giấu vẫn y hệt (vùng ngoài đã giấu nó rồi) nhưng người dùng phải bấm mở nhiều
    /// lần cho mỗi khối — cùng lý do `foldAll` chỉ lấy vùng ngoài cùng.
    public static func ranges(atLevel level: Int, in folds: [FoldRange]) -> [FoldRange] {
        guard level >= 1 else { return [] }
        let depths = levels(of: folds)
        return zip(folds, depths).filter { $0.1 == level - 1 }.map(\.0)
    }

    /// Các vùng ngoài cùng — tức `ranges(atLevel: 1, …)`.
    ///
    /// Có tên riêng vì "gấp tất cả" gọi nó, và một cái tên nói đúng ý định đọc dễ hơn một con số.
    public static func outermost(in folds: [FoldRange]) -> [FoldRange] {
        ranges(atLevel: 1, in: folds)
    }

    /// Số cấp sâu nhất của một tài liệu — để giao diện biết bấm tới cấp mấy thì hết chuyện.
    public static func levelCount(of folds: [FoldRange]) -> Int {
        (levels(of: folds).max() ?? -1) + 1
    }

    // MARK: - Theo thụt lề (YAML, Python — FR-FMT-507)

    /// Một dòng mở ra khối gồm mọi dòng SAU nó thụt sâu hơn nó.
    ///
    /// Ba quy tắc, và cả ba đều đến từ việc nhìn file thật:
    ///
    /// - **Dòng trắng không đóng khối.** YAML và Python đều có dòng trắng giữa các mục; coi nó
    ///   là kết thúc khối thì một file cấu hình bình thường vỡ thành mấy chục mẩu.
    /// - **Dòng trắng ở CUỐI khối không thuộc về khối.** Gấp một khối rồi thấy ba dòng trắng
    ///   còn lại lơ lửng thì trông như lỗi.
    /// - **Tab tính bằng 8 cột.** Trộn tab với dấu cách trong một file YAML là bệnh, nhưng nó
    ///   có thật, và đoán 4 hay 8 thì cũng phải chọn một — chọn 8 cho khớp `expand-tabs` mặc
    ///   định của terminal.
    public static func byIndentation(in buffer: TextBuffer) -> [FoldRange] {
        let lines = buffer.lineCount
        guard lines > 1 else { return [] }

        var indents = [Int](repeating: -1, count: lines)   // -1 = dòng trắng
        for line in 0 ..< lines {
            indents[line] = indentWidth(of: line, in: buffer)
        }

        var folds: [FoldRange] = []
        // Ngăn xếp các khối đang mở: (dòng đầu, mức thụt của dòng đầu).
        var open: [(line: Int, indent: Int)] = []

        for line in 0 ..< lines {
            let indent = indents[line]
            if indent < 0 { continue }                      // dòng trắng: không mở, không đóng

            while let top = open.last, indent <= top.indent {
                if let fold = makeFold(
                    header: top.line, endingBefore: line, indents: indents,
                    kind: .indentation, in: buffer
                ) {
                    folds.append(fold)
                }
                open.removeLast()
            }
            open.append((line, indent))
        }
        while let top = open.popLast() {
            if let fold = makeFold(
                header: top.line, endingBefore: lines, indents: indents,
                kind: .indentation, in: buffer
            ) {
                folds.append(fold)
            }
        }
        return folds.sorted { $0.headerLine < $1.headerLine }
    }

    /// Số cột thụt của một dòng; `-1` nếu dòng trắng.
    static func indentWidth(of line: Int, in buffer: TextBuffer) -> Int {
        let range = buffer.contentRange(ofLine: line)
        guard !range.isEmpty else { return -1 }
        let bytes = buffer.bytes(in: range)
        var width = 0
        for byte in bytes {
            if byte == UInt8(ascii: " ") {
                width += 1
            } else if byte == 0x09 {
                width += 8 - (width % 8)
            } else {
                return width
            }
        }
        return -1                                           // toàn khoảng trắng = dòng trắng
    }

    // MARK: - Theo mục (TOML, INI — FR-FMT-507)

    /// `[muc]` mở một khối kéo tới ngay trước `[muc]` kế tiếp.
    ///
    /// KHÔNG lồng theo `[a.b]`: trong TOML, `[a.b]` là một bảng độc lập nằm cạnh `[a]`, không
    /// phải bảng con của nó về mặt cú pháp file — hai bảng ấy có thể viết cách nhau cả trăm
    /// dòng và xen giữa là bảng khác. Gấp `[a]` mà nuốt luôn `[a.b]` ở tận cuối file sẽ giấu
    /// mất những dòng người dùng không hề coi là thuộc về nó.
    public static func bySection(in buffer: TextBuffer) -> [FoldRange] {
        let lines = buffer.lineCount
        guard lines > 1 else { return [] }

        var headers: [Int] = []
        var blanks = [Bool](repeating: false, count: lines)
        for line in 0 ..< lines {
            let range = buffer.contentRange(ofLine: line)
            let bytes = buffer.bytes(in: range)
            let first = bytes.first { $0 != UInt8(ascii: " ") && $0 != 0x09 }
            blanks[line] = first == nil
            if first == UInt8(ascii: "[") { headers.append(line) }
        }
        guard !headers.isEmpty else { return [] }

        var indents = [Int](repeating: 0, count: lines)
        for line in 0 ..< lines where blanks[line] { indents[line] = -1 }

        var folds: [FoldRange] = []
        for (i, header) in headers.enumerated() {
            let end = i + 1 < headers.count ? headers[i + 1] : lines
            if let fold = makeFold(
                header: header, endingBefore: end, indents: indents, kind: .section, in: buffer
            ) {
                folds.append(fold)
            }
        }
        return folds
    }

    // MARK: - Theo cấu trúc JSON

    /// Mọi object và mảng nhiều hơn một dòng.
    ///
    /// Dùng `JSONIndex` thay vì đếm ngoặc: biên chính xác tuyệt đối, vì `{` nằm trong một chuỗi
    /// đã được bộ quét JSON hiểu đúng là ký tự chứ không phải dấu mở khối. Đếm ngoặc bằng byte
    /// sẽ gấp sai ngay ở file đầu tiên có `"ghi_chu": "dùng { để mở khối"`.
    public static func byJSONStructure(in buffer: TextBuffer) -> [FoldRange] {
        let bytes = buffer.bytes(in: 0 ..< buffer.count)
        let index = JSONIndex(bytes: bytes)
        guard index.failure == nil, !index.tooLarge else { return [] }

        var folds: [FoldRange] = []
        for node in index.nodes where node.kind.isContainer {
            let headerLine = buffer.lineNumber(atOffset: node.range.lowerBound)
            let lastLine = buffer.lineNumber(atOffset: max(node.range.upperBound - 1, 0))
            guard lastLine > headerLine else { continue }
            // Giấu TRỌN các dòng sau dòng đầu: dấu `{` và những gì đứng trước nó vẫn hiện,
            // nên dòng gấp lại đọc được là `"cua_hang": {`.
            let hiddenStart = buffer.offset(ofLineStart: headerLine + 1)
            let hiddenEnd = buffer.lineRangeForFold(lastLine).upperBound
            guard hiddenStart < hiddenEnd else { continue }
            folds.append(FoldRange(
                headerLine: headerLine, lastLine: lastLine,
                hiddenBytes: hiddenStart ..< hiddenEnd,
                caretHome: buffer.contentRange(ofLine: headerLine).upperBound,
                kind: .brackets
            ))
        }
        return folds.sorted { $0.headerLine < $1.headerLine }
    }

    // MARK: - Theo cặp thẻ (XML, HTML — FR-FMT-505)

    /// Mỗi cặp `<ten>` … `</ten>` trải nhiều dòng là một vùng gấp.
    ///
    /// **Quét riêng, KHÔNG dùng `XMLTool`.** Hai việc khác nhau: `XMLTool` đọc để kiểm và viết
    /// lại, nên nó phải từ chối file hỏng. Gấp thì ngược lại — người ta gấp giữa lúc đang SỬA
    /// dở, và lúc ấy file gần như luôn tạm thời không well-formed. Một trình soạn thảo mà mất
    /// hết vùng gấp ngay khi bạn xóa một dấu `>` là một trình soạn thảo khó chịu. Nên chỗ này
    /// quét dung thứ: thẻ nào không khớp thì bỏ qua thẻ ấy, phần còn lại vẫn gấp được.
    ///
    /// Vẫn phải hiểu bốn thứ, vì bỏ qua chúng là gấp sai chứ không phải gấp thiếu:
    /// `<!-- -->`, `<![CDATA[ ]]>`, `<? ?>`, và dấu nháy trong giá trị thuộc tính (một `>` nằm
    /// trong `title="a > b"` không đóng thẻ nào cả).
    ///
    /// HTML có thẻ rỗng không cần đóng (`<br>`, `<img>`, `<meta>`…). Danh sách ấy được tra ở
    /// đây, nếu không thì `<br>` đầu tiên sẽ nuốt cả phần còn lại của tài liệu vào một vùng gấp.
    public static func byTags(in buffer: TextBuffer) -> [FoldRange] {
        let bytes = buffer.bytes(in: 0 ..< buffer.count)
        var folds: [FoldRange] = []
        var open: [(name: String, offset: Int)] = []
        var i = 0

        func matches(_ text: String, at index: Int) -> Bool {
            let needle = Array(text.utf8)
            guard index + needle.count <= bytes.count else { return false }
            for (offset, byte) in needle.enumerated() where bytes[index + offset] != byte {
                return false
            }
            return true
        }

        while i < bytes.count {
            guard bytes[i] == UInt8(ascii: "<") else { i += 1; continue }

            if matches("<!--", at: i) { i = skip(to: "-->", from: i + 4, in: bytes); continue }
            if matches("<![CDATA[", at: i) { i = skip(to: "]]>", from: i + 9, in: bytes); continue }
            if matches("<?", at: i) { i = skip(to: "?>", from: i + 2, in: bytes); continue }
            if matches("<!", at: i) { i = skip(to: ">", from: i + 2, in: bytes); continue }

            let tagStart = i
            let isClose = matches("</", at: i)
            var cursor = i + (isClose ? 2 : 1)
            let nameStart = cursor
            while cursor < bytes.count, isNameByte(bytes[cursor]) { cursor += 1 }
            let name = String(decoding: bytes[nameStart ..< cursor], as: UTF8.self).lowercased()

            // Đi tới `>` của thẻ này, nhảy qua giá trị thuộc tính có dấu nháy.
            var selfClosing = false
            while cursor < bytes.count, bytes[cursor] != UInt8(ascii: ">") {
                if bytes[cursor] == UInt8(ascii: "\"") || bytes[cursor] == UInt8(ascii: "'") {
                    let quote = bytes[cursor]
                    cursor += 1
                    while cursor < bytes.count, bytes[cursor] != quote { cursor += 1 }
                }
                if bytes[cursor] == UInt8(ascii: "/") { selfClosing = true } else if
                    bytes[cursor] != UInt8(ascii: " ") && bytes[cursor] != 0x09
                    && bytes[cursor] != 0x0A && bytes[cursor] != 0x0D {
                    selfClosing = false
                }
                cursor += 1
            }
            i = Swift.min(cursor + 1, bytes.count)

            if name.isEmpty { continue }
            if isClose {
                // Tìm ngược tới thẻ mở CÙNG TÊN gần nhất, bỏ những thẻ chưa đóng nằm giữa —
                // đó chính là chỗ dung thứ với file đang sửa dở.
                guard let match = open.lastIndex(where: { $0.name == name }) else { continue }
                let opening = open[match].offset
                open.removeSubrange(match ..< open.count)
                if let fold = tagFold(from: opening, to: i, in: buffer) { folds.append(fold) }
            } else if !selfClosing && !voidHTMLTags.contains(name) {
                open.append((name, tagStart))
            }
        }
        return folds.sorted { $0.headerLine < $1.headerLine }
    }

    /// Thẻ HTML không có thẻ đóng.
    static let voidHTMLTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    ]

    private static func isNameByte(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
            || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
            || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "-")
            || byte == UInt8(ascii: ":") || byte == UInt8(ascii: ".")
    }

    private static func skip(to terminator: String, from index: Int, in bytes: [UInt8]) -> Int {
        let needle = Array(terminator.utf8)
        var i = index
        while i + needle.count <= bytes.count {
            var hit = true
            for (offset, byte) in needle.enumerated() where bytes[i + offset] != byte {
                hit = false
                break
            }
            if hit { return i + needle.count }
            i += 1
        }
        return bytes.count
    }

    private static func tagFold(from start: Int, to end: Int, in buffer: TextBuffer) -> FoldRange? {
        let headerLine = buffer.lineNumber(atOffset: start)
        let lastLine = buffer.lineNumber(atOffset: Swift.max(end - 1, 0))
        guard lastLine > headerLine else { return nil }
        let hiddenStart = buffer.offset(ofLineStart: headerLine + 1)
        let hiddenEnd = buffer.lineRangeForFold(lastLine).upperBound
        guard hiddenStart < hiddenEnd else { return nil }
        return FoldRange(
            headerLine: headerLine, lastLine: lastLine,
            hiddenBytes: hiddenStart ..< hiddenEnd,
            caretHome: buffer.contentRange(ofLine: headerLine).upperBound, kind: .tag
        )
    }

    // MARK: - Chung

    /// Dựng một vùng gấp từ dòng `header` tới trước dòng `end`, đã bỏ dòng trắng ở cuối.
    private static func makeFold(
        header: Int, endingBefore end: Int, indents: [Int], kind: FoldRange.Kind,
        in buffer: TextBuffer
    ) -> FoldRange? {
        var last = end - 1
        while last > header && indents[last] < 0 { last -= 1 }   // cắt dòng trắng đuôi
        guard last > header else { return nil }

        let hiddenStart = buffer.offset(ofLineStart: header + 1)
        let hiddenEnd = buffer.lineRangeForFold(last).upperBound
        guard hiddenStart < hiddenEnd else { return nil }
        return FoldRange(
            headerLine: header, lastLine: last, hiddenBytes: hiddenStart ..< hiddenEnd,
            caretHome: buffer.contentRange(ofLine: header).upperBound, kind: kind
        )
    }
}

extension TextBuffer {
    /// Phạm vi byte của một dòng KỂ CẢ ký tự xuống dòng.
    ///
    /// `contentRange` bỏ CR/LF, đúng cho việc đọc nội dung. Gấp thì cần cả ký tự xuống dòng:
    /// giấu nội dung mà để lại `\n` sẽ để lại một dòng trắng cho mỗi dòng đã gấp.
    func lineRangeForFold(_ line: Int) -> Range<Int> {
        let start = offset(ofLineStart: line)
        let end = line + 1 < lineCount ? offset(ofLineStart: line + 1) : count
        return start ..< end
    }
}
