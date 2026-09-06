import Foundation

/// Cầu nối giữa các phép biến đổi dòng và tài liệu thật (FR-CORE-004…010).
///
/// `LineOps` cố ý chỉ biết về `[String]` — nó thuần túy, dễ test, không chạm buffer. Nhưng
/// giữa nó và `TextBuffer` cần một lớp biết ba việc mà `LineOps` không nên biết:
///
/// 1. **Trả về `[TextEdit]`, không tự sửa.** Lớp gọi truyền cả mảng vào `applyEdits` để mọi
///    thao tác hàng loạt là ĐÚNG MỘT bước undo (FR-CORE-004) — bất biến của toàn sản phẩm.
/// 2. **Chỉ sinh edit cho dòng THỰC SỰ đổi.** Chuyển hoa/thường 1 triệu dòng mà chỉ 100 dòng
///    khác đi thì phải ra 100 edit, không phải 1 triệu.
/// 3. **Gộp vùng liền nhau.** Xóa 400 000 dòng trùng, phần lớn nằm thành cụm, gộp lại còn
///    vài chục nghìn edit thay vì 400 000.
public enum DocumentOps {

    // MARK: - Truy cập dòng theo lô

    /// Phạm vi byte của mọi dòng, GỒM ký tự xuống dòng.
    ///
    /// Quét MỘT lượt bằng SIMD thay vì gọi `offset(ofLineStart:)` cho từng dòng: truy vấn lẻ
    /// là O(log n) cộng một lần quét khối 64 KB, rất tốt cho một vài dòng nhưng thành lãng
    /// phí lớn khi cần cả triệu dòng theo thứ tự.
    public static func lineRanges(of buffer: TextBuffer) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        ranges.reserveCapacity(buffer.lineCount)

        var lineStart = 0
        var global = 0
        buffer.forEachChunk { chunk in
            var position = 0
            while position < chunk.count,
                  let at = ByteScan.firstIndex(of: UInt8(ascii: "\n"), in: chunk, from: position) {
                ranges.append(lineStart ..< (global + at + 1))
                lineStart = global + at + 1
                position = at + 1
            }
            global += chunk.count
        }
        // Dòng cuối không kết thúc bằng EOL. Nếu tài liệu kết thúc bằng EOL thì `lineStart`
        // đã bằng `global` và không có dòng ảo nào được thêm — cùng quy ước với `lineCount`.
        if lineStart < global { ranges.append(lineStart ..< global) }
        return ranges
    }

    /// Phạm vi byte của dòng, đã bỏ CR/LF cuối dòng.
    static func contentRange(_ range: Range<Int>, in buffer: TextBuffer) -> Range<Int> {
        var end = range.upperBound
        guard end > range.lowerBound else { return range }
        let tail = buffer.bytes(in: max(range.lowerBound, end - 2) ..< end)
        if tail.last == UInt8(ascii: "\n") {
            end -= 1
            if tail.count >= 2, tail[tail.count - 2] == UInt8(ascii: "\r") { end -= 1 }
        } else if tail.last == UInt8(ascii: "\r") {
            end -= 1
        }
        return range.lowerBound ..< end
    }

    /// Gộp các phạm vi xóa liền nhau thành một.
    ///
    /// `ranges` phải tăng dần và không giao nhau.
    static func coalesce(_ ranges: [Range<Int>]) -> [Range<Int>] {
        var merged: [Range<Int>] = []
        merged.reserveCapacity(ranges.count)
        for range in ranges {
            if let last = merged.last, last.upperBound == range.lowerBound {
                merged[merged.count - 1] = last.lowerBound ..< range.upperBound
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    // MARK: - Khử trùng lặp (FR-CORE-006)

    /// Xóa dòng trùng.
    ///
    /// Chạy trên BYTE, không dựng `String`: với một triệu dòng, một triệu `String` là một
    /// triệu lần cấp phát cộng chi phí kiểm tra UTF-8 — đủ để vượt trần 3 giây của TC-CORE-08
    /// trước khi làm được việc gì có ích. So sánh byte cũng là so sánh ĐÚNG ở đây: hai dòng
    /// chỉ là một khi chúng giống nhau từng byte.
    public static func removeDuplicateLines(
        in buffer: TextBuffer,
        scope: LineOps.DedupScope = .whole,
        keep: LineOps.DedupKeep = .first,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard ranges.count > 1 else { return [] }

        var remove = [Bool](repeating: false, count: ranges.count)

        switch scope {
        case .consecutive:
            var previous: [UInt8]?
            for (index, range) in ranges.enumerated() {
                if index % 65_536 == 0 { try cancelToken.check() }
                let content = buffer.bytes(in: contentRange(range, in: buffer))
                if let previous, previous == content {
                    remove[keep == .first ? index : index - 1] = true
                }
                previous = content
            }

        case .whole:
            var seen: [[UInt8]: Int] = [:]
            seen.reserveCapacity(ranges.count)
            for (index, range) in ranges.enumerated() {
                if index % 65_536 == 0 { try cancelToken.check() }
                let content = buffer.bytes(in: contentRange(range, in: buffer))
                if let first = seen[content] {
                    remove[keep == .first ? index : first] = true
                    if keep == .last { seen[content] = index }
                } else {
                    seen[content] = index
                }
            }
        }

        let doomed = ranges.enumerated().filter { remove[$0.offset] }.map(\.element)
        return coalesce(doomed).map { TextEdit(range: $0, bytes: []) }
    }

    // MARK: - Sắp xếp (FR-CORE-005)

    /// Sắp xếp dòng trong `lineRange` (0-based, gồm cả dòng cuối); `nil` = cả tài liệu.
    ///
    /// Sắp xếp viết lại toàn vùng nên trả về ĐÚNG MỘT `TextEdit` thay vì một edit cho mỗi
    /// dòng: cây piece chỉ phải làm một phép tách-nối, và bước undo giữ đúng một bản của
    /// vùng cũ thay vì hàng triệu mảnh.
    ///
    /// Khi sắp theo CỘT, khóa được trích bằng parser RFC 4180 chứ không bằng cách tách chuỗi
    /// theo dấu phân tách: `"Công ty Anh Đào, CN Huế"` là MỘT field, tách thô sẽ biến nó
    /// thành hai và làm lệch toàn bộ các cột phía sau (TC-CORE-06).
    public static func sortLines(
        in buffer: TextBuffer,
        lineRange: ClosedRange<Int>? = nil,
        kind: LineOps.SortKind = .lexicographic(caseSensitive: true),
        ascending: Bool = true,
        column: Int? = nil,
        dialect: CSVDialect = .comma
    ) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }

        let bounds = lineRange ?? 0 ... (ranges.count - 1)
        let lower = max(0, bounds.lowerBound)
        let upper = min(ranges.count - 1, bounds.upperBound)
        guard lower < upper else { return [] }

        let selected = Array(ranges[lower ... upper])
        let lines = selected.map { range in
            String(decoding: buffer.bytes(in: contentRange(range, in: buffer)), as: UTF8.self)
        }

        let keys: [String]
        if let column {
            keys = lines.map { line in
                let fields = CSVEngine.parse(Array(line.utf8), dialect: dialect, maxRows: 1)
                guard let row = fields.first, column < row.count else { return "" }
                let raw = Array(Array(line.utf8)[row[column].range])
                return String(decoding: CSVEngine.unescape(raw, dialect: dialect), as: UTF8.self)
            }
        } else {
            keys = lines
        }

        // Sắp CHỈ SỐ rồi mới lấy dòng: giữ ổn định (dòng khóa bằng nhau giữ nguyên thứ tự cũ)
        // mà không phải kéo theo cả nội dung dòng trong mỗi lần so sánh.
        let order = lines.indices.sorted { left, right in
            let result = LineOps.compare(keys[left], keys[right], kind: kind)
            if result == 0 { return left < right }
            return ascending ? result < 0 : result > 0
        }
        guard order != Array(lines.indices) else { return [] }
        let sorted = order.map { lines[$0] }

        // Giữ NGUYÊN kiểu xuống dòng của từng vị trí thay vì của từng dòng: người dùng sắp
        // xếp nội dung, không sắp xếp ký tự xuống dòng. Làm ngược lại sẽ trộn CRLF vào giữa
        // một file toàn LF chỉ vì một dòng lạc nào đó bị đẩy lên trên.
        var out = [UInt8]()
        out.reserveCapacity(selected.last!.upperBound - selected.first!.lowerBound)
        for (offset, range) in selected.enumerated() {
            out.append(contentsOf: Array(sorted[offset].utf8))
            let content = contentRange(range, in: buffer)
            out.append(contentsOf: buffer.bytes(in: content.upperBound ..< range.upperBound))
        }

        let region = selected.first!.lowerBound ..< selected.last!.upperBound
        return [TextEdit(range: region, bytes: out)]
    }

    // MARK: - Thao tác dòng (FR-CORE-007)

    /// Byte xuống dòng của một dòng; rỗng nếu dòng đó là dòng cuối không có ký tự xuống dòng.
    private static func eolBytes(of range: Range<Int>, in buffer: TextBuffer) -> [UInt8] {
        buffer.bytes(in: contentRange(range, in: buffer).upperBound ..< range.upperBound)
    }

    /// Kiểu xuống dòng dùng khi phải TẠO một dòng mới.
    ///
    /// Lấy của dòng đầu vùng, không lấy mặc định của hệ điều hành: chèn LF vào giữa một file
    /// CRLF là cách trộn EOL mà người dùng không hề yêu cầu.
    private static func preferredEOL(_ ranges: [Range<Int>], in buffer: TextBuffer) -> [UInt8] {
        for range in ranges {
            let eol = eolBytes(of: range, in: buffer)
            if !eol.isEmpty { return eol }
        }
        return [UInt8(ascii: "\n")]
    }

    /// Ghép các dòng trong `lineRange` thành MỘT dòng (FR-CORE-007).
    public static func joinLines(
        in buffer: TextBuffer,
        lineRange: ClosedRange<Int>? = nil,
        separator: String = ""
    ) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }
        let bounds = lineRange ?? 0 ... (ranges.count - 1)
        let lower = max(0, bounds.lowerBound)
        let upper = min(ranges.count - 1, bounds.upperBound)
        guard lower < upper else { return [] }

        let selected = Array(ranges[lower ... upper])
        let lines = selected.map {
            String(decoding: buffer.bytes(in: contentRange($0, in: buffer)), as: UTF8.self)
        }
        var out = Array(LineOps.join(lines, separator: separator).utf8)
        // Giữ ký tự xuống dòng của dòng CUỐI cùng: vùng ghép vẫn phải nối đúng vào phần sau.
        out.append(contentsOf: eolBytes(of: selected.last!, in: buffer))

        let region = selected.first!.lowerBound ..< selected.last!.upperBound
        return [TextEdit(range: region, bytes: out)]
    }

    /// Tách dòng dài theo độ dài hoặc theo ký tự (FR-CORE-007).
    ///
    /// Sinh edit theo TỪNG DÒNG chứ không viết lại cả vùng: trong một tài liệu thật chỉ vài
    /// dòng vượt giới hạn, và viết lại cả vùng biến một thao tác nhỏ thành một bản sao cả
    /// tài liệu trong bước undo.
    public static func splitLines(
        in buffer: TextBuffer,
        lineRange: ClosedRange<Int>? = nil,
        atLength length: Int? = nil,
        atCharacter character: Character? = nil,
        atWordBoundary: Bool = true,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [TextEdit] {
        guard length != nil || character != nil else { return [] }
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }
        let bounds = lineRange ?? 0 ... (ranges.count - 1)
        let lower = max(0, bounds.lowerBound)
        let upper = min(ranges.count - 1, bounds.upperBound)
        guard lower <= upper else { return [] }

        let eol = preferredEOL(ranges, in: buffer)
        var edits: [TextEdit] = []
        for index in lower ... upper {
            if index % 65_536 == 0 { try cancelToken.check() }
            let content = contentRange(ranges[index], in: buffer)
            let line = String(decoding: buffer.bytes(in: content), as: UTF8.self)

            var pieces = [line]
            if let character { pieces = LineOps.split(line, at: character) }
            if let length {
                pieces = pieces.flatMap { LineOps.split($0, atLength: length, atWordBoundary: atWordBoundary) }
            }
            guard pieces.count > 1 else { continue }

            var out: [UInt8] = []
            for (offset, piece) in pieces.enumerated() {
                if offset > 0 { out.append(contentsOf: eol) }
                out.append(contentsOf: Array(piece.utf8))
            }
            edits.append(TextEdit(range: content, bytes: out))
        }
        return edits
    }

    /// Dời một khối dòng lên (`by` âm) hoặc xuống (`by` dương) — FR-CORE-007.
    public static func moveLines(
        in buffer: TextBuffer, lineRange: ClosedRange<Int>, by offset: Int
    ) -> [TextEdit] {
        guard offset != 0 else { return [] }
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }
        let lower = max(0, lineRange.lowerBound)
        let upper = min(ranges.count - 1, lineRange.upperBound)
        guard lower <= upper else { return [] }

        guard lower + offset >= 0, upper + offset <= ranges.count - 1 else { return [] }

        // Dời khối = HOÁN CHỖ nó với đúng những dòng nó nhảy qua. Vùng viết lại chỉ gồm khối
        // và mấy dòng ấy, không hơn.
        //
        // Bản đầu tính "vị trí chèn" sau khi đã bỏ khối ra khỏi danh sách, và chỉ số đích khi
        // ấy không còn nghĩa cũ nữa: dời lên thì đúng, dời xuống thì đứng yên. Cách này không
        // có chỗ cho kiểu nhầm đó.
        let block = Array(lower ... upper)
        let regionLower = min(lower, lower + offset)
        let regionUpper = max(upper, upper + offset)
        let order: [Int] = offset > 0
            ? Array((upper + 1) ... (upper + offset)) + block
            : block + Array((lower + offset) ... (lower - 1))
        let selected = Array(ranges[regionLower ... regionUpper])

        var out: [UInt8] = []
        out.reserveCapacity(selected.last!.upperBound - selected.first!.lowerBound)
        for (position, sourceLine) in order.enumerated() {
            out.append(contentsOf: buffer.bytes(in: contentRange(ranges[sourceLine], in: buffer)))
            out.append(contentsOf: eolBytes(of: selected[position], in: buffer))
        }
        let region = selected.first!.lowerBound ..< selected.last!.upperBound
        return [TextEdit(range: region, bytes: out)]
    }

    /// Đảo ngược thứ tự dòng (FR-CORE-007).
    public static func reverseLines(
        in buffer: TextBuffer, lineRange: ClosedRange<Int>? = nil
    ) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }
        let bounds = lineRange ?? 0 ... (ranges.count - 1)
        let lower = max(0, bounds.lowerBound)
        let upper = min(ranges.count - 1, bounds.upperBound)
        guard lower < upper else { return [] }

        let selected = Array(ranges[lower ... upper])
        let contents = selected.map { buffer.bytes(in: contentRange($0, in: buffer)) }

        var out: [UInt8] = []
        out.reserveCapacity(selected.last!.upperBound - selected.first!.lowerBound)
        for (position, range) in selected.enumerated() {
            out.append(contentsOf: contents[contents.count - 1 - position])
            out.append(contentsOf: eolBytes(of: range, in: buffer))
        }
        let region = selected.first!.lowerBound ..< selected.last!.upperBound
        return [TextEdit(range: region, bytes: out)]
    }

    /// Nhân đôi một khối dòng, bản sao đặt ngay dưới bản gốc (FR-CORE-007).
    ///
    /// Chèn chứ không viết đè: một `TextEdit` rỗng ở đúng đầu dòng kế tiếp. Cách này giữ
    /// nguyên mọi byte của khối gốc — kể cả EOL trộn lẫn — thay vì dựng lại chúng từ chuỗi.
    public static func duplicateLines(
        in buffer: TextBuffer, lineRange: ClosedRange<Int>
    ) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }
        let lower = max(0, lineRange.lowerBound)
        let upper = min(ranges.count - 1, lineRange.upperBound)
        guard lower <= upper else { return [] }

        let region = ranges[lower].lowerBound ..< ranges[upper].upperBound
        var copy = buffer.bytes(in: region)

        // Dòng CUỐI tài liệu không có EOL. Nhân đôi nó mà chép nguyên xi thì hai dòng dính vào
        // nhau thành một — phải thêm EOL vào giữa, lấy kiểu của chính tài liệu này.
        if eolBytes(of: ranges[upper], in: buffer).isEmpty {
            copy.append(contentsOf: preferredEOL(ranges, in: buffer))
            // Bản sao thành dòng cuối, và nó cũng không cần EOL: chèn vào SAU khối gốc nghĩa là
            // bản gốc giờ mới là dòng có EOL. Thứ tự byte đúng là <gốc><EOL><bản sao>.
            return [TextEdit(range: region.upperBound ..< region.upperBound, bytes: shiftEOL(copy))]
        }
        return [TextEdit(range: region.upperBound ..< region.upperBound, bytes: copy)]
    }

    /// Chuyển EOL vừa thêm ở CUỐI về ĐẦU: `<khối><EOL>` thành `<EOL><khối>`.
    ///
    /// Dùng khi nhân đôi dòng cuối tài liệu — chỗ chèn nằm ngay sau dòng gốc chưa có EOL, nên
    /// ký tự xuống dòng phải đi trước bản sao thì mới tách được hai dòng.
    private static func shiftEOL(_ bytes: [UInt8]) -> [UInt8] {
        var out = bytes
        var eol: [UInt8] = []
        while let last = out.last, last == 0x0A || last == 0x0D {
            eol.insert(last, at: 0)
            out.removeLast()
        }
        return eol + out
    }

    /// Xóa hẳn một khối dòng (FR-CORE-007).
    public static func deleteLines(
        in buffer: TextBuffer, lineRange: ClosedRange<Int>
    ) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }
        let lower = max(0, lineRange.lowerBound)
        let upper = min(ranges.count - 1, lineRange.upperBound)
        guard lower <= upper else { return [] }

        var region = ranges[lower].lowerBound ..< ranges[upper].upperBound
        // Xóa tới hết tài liệu thì phải nuốt cả EOL của dòng ĐỨNG TRƯỚC, không thì còn lại một
        // dòng trống ở cuối mà người dùng không hề tạo ra.
        if upper == ranges.count - 1, lower > 0 {
            region = contentRange(ranges[lower - 1], in: buffer).upperBound ..< region.upperBound
        }
        return [TextEdit(range: region, bytes: [])]
    }

    // MARK: - Comment nhanh (FR-CORE-014)

    /// Bật/tắt comment dòng cho một khối.
    ///
    /// **Toàn khối đi cùng một hướng.** Nếu MỌI dòng có nội dung đều đã comment thì bỏ comment,
    /// còn lại thì comment tất. Quyết định theo từng dòng sẽ biến một khối comment dở thành cái
    /// bàn cờ, và bấm hai lần không đưa được về chỗ cũ.
    ///
    /// Dấu comment chèn tại CỘT THỤT LỀ NÔNG NHẤT của khối, không phải cột 0: giữ được hình
    /// dáng thụt lề của đoạn mã, đúng thứ mọi trình soạn thảo khác làm.
    public static func toggleLineComment(
        in buffer: TextBuffer, lineRange: ClosedRange<Int>, token: String
    ) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty, !token.isEmpty else { return [] }
        let lower = max(0, lineRange.lowerBound)
        let upper = min(ranges.count - 1, lineRange.upperBound)
        guard lower <= upper else { return [] }

        let contents = (lower ... upper).map { index -> (Range<Int>, String) in
            let content = contentRange(ranges[index], in: buffer)
            return (content, String(decoding: buffer.bytes(in: content), as: UTF8.self))
        }
        // Dòng trắng không tính vào phép quyết định và cũng không bị chèn dấu: comment một dòng
        // trống chỉ tạo rác.
        let meaningful = contents.filter { !LineOps.isBlank($0.1) }
        guard !meaningful.isEmpty else { return [] }

        let removing = meaningful.allSatisfy {
            $0.1.trimmingCharacters(in: .whitespaces).hasPrefix(token)
        }
        let column = meaningful.map { $0.1.prefix(while: { $0 == " " || $0 == "\t" }).count }.min() ?? 0

        var edits: [TextEdit] = []
        for (content, text) in meaningful {
            let chars = Array(text)
            // Cột đếm theo KÝ TỰ, chỗ chèn tính theo BYTE. Một dòng thụt lề bằng chữ tiếng Việt
            // thì hai số ấy khác nhau, và lấy nhầm sẽ cắt vào giữa một ký tự UTF-8.
            func byteOffset(upTo index: Int) -> Int {
                String(chars[0 ..< min(index, chars.count)]).utf8.count
            }
            if removing {
                let start = chars.prefix(while: { $0 == " " || $0 == "\t" }).count
                var length = token.count
                // Nuốt luôn MỘT dấu cách sau dấu comment — chính dấu cách mà bước comment đã
                // thêm vào. Bỏ sót nó thì comment/bỏ comment vài lần là thụt lề trôi dần.
                if start + length < chars.count, chars[start + length] == " " { length += 1 }
                let from = content.lowerBound + byteOffset(upTo: start)
                let to = content.lowerBound + byteOffset(upTo: start + length)
                edits.append(TextEdit(range: from ..< to, bytes: []))
            } else {
                let at = content.lowerBound + byteOffset(upTo: column)
                edits.append(TextEdit(range: at ..< at, bytes: Array("\(token) ".utf8)))
            }
        }
        return edits
    }

    /// Bật/tắt comment KHỐI bọc quanh một vùng dòng (FR-CORE-014).
    ///
    /// Dùng cho ngôn ngữ không có comment một dòng — XML, HTML, CSS. Cặp dấu bọc quanh CẢ khối
    /// chứ không quanh từng dòng: `<!-- -->` lồng nhau là lỗi cú pháp trong XML, nên bọc từng
    /// dòng rồi bọc tiếp lần nữa sẽ sinh ra file hỏng.
    public static func toggleBlockComment(
        in buffer: TextBuffer, lineRange: ClosedRange<Int>, open: String, close: String
    ) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty, !open.isEmpty, !close.isEmpty else { return [] }
        let lower = max(0, lineRange.lowerBound)
        let upper = min(ranges.count - 1, lineRange.upperBound)
        guard lower <= upper else { return [] }

        let first = contentRange(ranges[lower], in: buffer)
        let last = contentRange(ranges[upper], in: buffer)
        let region = first.lowerBound ..< last.upperBound
        let text = String(decoding: buffer.bytes(in: region), as: UTF8.self)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.hasPrefix(open), trimmed.hasSuffix(close) {
            // Bỏ bọc: viết lại cả vùng bằng phần ruột, đã cắt dấu cách mà bước bọc thêm vào.
            let inner = trimmed.dropFirst(open.count).dropLast(close.count)
            return [TextEdit(range: region, text: String(inner).trimmingCharacters(in: .whitespaces))]
        }
        return [TextEdit(range: region, text: "\(open) \(text) \(close)")]
    }

    /// Nén nhiều dòng trống liên tiếp thành MỘT (FR-CORE-008).
    public static func squeezeBlankLines(in buffer: TextBuffer) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        var doomed: [Range<Int>] = []
        var previousWasBlank = false
        for range in ranges {
            let content = buffer.bytes(in: contentRange(range, in: buffer))
            let blank = LineOps.isBlank(String(decoding: content, as: UTF8.self))
            // Giữ dòng trống ĐẦU TIÊN của mỗi cụm, xóa các dòng sau nó.
            if blank && previousWasBlank { doomed.append(range) }
            previousWasBlank = blank
        }
        return coalesce(doomed).map { TextEdit(range: $0, bytes: []) }
    }

    // MARK: - Biến đổi từng dòng (FR-CORE-008, 009, 010)

    /// Áp `transform` lên từng dòng; chỉ dòng ĐỔI mới sinh ra `TextEdit`.
    public static func transformLines(
        in buffer: TextBuffer,
        lineRange: ClosedRange<Int>? = nil,
        cancelToken: CancelToken = CancelToken(),
        _ transform: (String) -> String
    ) throws -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        guard !ranges.isEmpty else { return [] }

        let bounds = lineRange ?? 0 ... (ranges.count - 1)
        let lower = max(0, bounds.lowerBound)
        let upper = min(ranges.count - 1, bounds.upperBound)
        guard lower <= upper else { return [] }

        var edits: [TextEdit] = []
        for index in lower ... upper {
            if index % 65_536 == 0 { try cancelToken.check() }
            let content = contentRange(ranges[index], in: buffer)
            let original = buffer.bytes(in: content)
            let result = Array(transform(String(decoding: original, as: UTF8.self)).utf8)
            if result != original {
                edits.append(TextEdit(range: content, bytes: result))
            }
        }
        return edits
    }

    /// Cắt khoảng trắng đầu/cuối dòng (FR-CORE-008).
    public static func trimLines(
        in buffer: TextBuffer,
        side: LineOps.TrimSide = .trailing,
        lineRange: ClosedRange<Int>? = nil
    ) throws -> [TextEdit] {
        try transformLines(in: buffer, lineRange: lineRange) { LineOps.trim($0, side: side) }
    }

    /// Xóa dòng rỗng (FR-CORE-008).
    public static func removeBlankLines(in buffer: TextBuffer) -> [TextEdit] {
        let ranges = lineRanges(of: buffer)
        let blank = ranges.filter { range in
            let content = buffer.bytes(in: contentRange(range, in: buffer))
            return LineOps.isBlank(String(decoding: content, as: UTF8.self))
        }
        return coalesce(blank).map { TextEdit(range: $0, bytes: []) }
    }

    /// TAB ↔ Space (FR-CORE-009).
    public static func tabsToSpaces(
        in buffer: TextBuffer, tabWidth: Int, lineRange: ClosedRange<Int>? = nil
    ) throws -> [TextEdit] {
        try transformLines(in: buffer, lineRange: lineRange) {
            LineOps.tabsToSpaces($0, tabWidth: tabWidth)
        }
    }

    public static func spacesToTabs(
        in buffer: TextBuffer, tabWidth: Int, lineRange: ClosedRange<Int>? = nil
    ) throws -> [TextEdit] {
        try transformLines(in: buffer, lineRange: lineRange) {
            LineOps.spacesToTabs($0, tabWidth: tabWidth)
        }
    }

    /// Đổi hoa/thường và kiểu định danh (FR-CORE-010).
    public static func convertCase(
        in buffer: TextBuffer, to style: LineOps.CaseStyle, lineRange: ClosedRange<Int>? = nil
    ) throws -> [TextEdit] {
        try transformLines(in: buffer, lineRange: lineRange) {
            LineOps.convertCase($0, to: style)
        }
    }
}
