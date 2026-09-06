import Foundation

/// Tài liệu báo cáo `.greport.md` — FR-RPT-001.
///
/// Đặc tả: *"Tài liệu báo cáo là Markdown mở rộng: fenced block ```query chứa SQL DuckDB render
/// thành bảng nhúng, block ```chart chứa spec YAML (kiểu, trục, tiêu đề) render biểu đồ — soạn
/// bên trái, preview bên phải. File thuần văn bản: diff/Git/chia sẻ được, nhất quán triết lý
/// «dữ liệu là văn bản» (ADR-09)."*
///
/// ## Tệp này chỉ ĐỌC, không chạy gì
///
/// Phân tích ra khối và tham số, hết. Không mở DuckDB, không vẽ, không đọc file nguồn. Ba lý do:
///
/// 1. **Kiểm được mà không cần dữ liệu.** Toàn bộ luật cú pháp của định dạng kiểm bằng so chuỗi.
/// 2. **Preview gõ tới đâu phân tích tới đó.** Người dùng gõ một ký tự thì chạy lại hàm này —
///    vài chục micro-giây trên một tài liệu vài trăm dòng. Nếu nó chạy truy vấn thì mỗi phím gõ
///    là một lượt quét bảng, và NFR-PERF-02 (thao tác gõ ≤ 16 ms) vỡ ngay.
/// 3. **Lỗi cú pháp tách khỏi lỗi dữ liệu.** *"Khối chart thiếu khoá `kind`"* là lỗi của tài
///    liệu; *"cột `doanh_thu` không tồn tại"* là lỗi của dữ liệu. Trộn hai loại vào một chỗ báo
///    lỗi thì người dùng không biết phải sửa tệp nào.
///
/// ## Vì sao TỰ phân tích Markdown thay vì dùng thư viện
///
/// Thứ cần ở đây không phải một trình phân tích Markdown đầy đủ — chỉ cần tìm **khối rào** và
/// **frontmatter**, hai thứ có luật đơn giản và không nhập nhằng. Phần Markdown còn lại được
/// chuyển nguyên si sang trình kết xuất. Kéo một thư viện Markdown vào lõi để dùng 2% của nó là
/// đổi một phụ thuộc mới lấy tám mươi dòng.
public struct ReportDocument: Equatable, Sendable {

    /// Đuôi tệp mà đặc tả đặt tên.
    public static let fileExtension = "greport.md"

    public enum BlockKind: String, Equatable, Sendable {
        /// SQL DuckDB → bảng nhúng.
        case query
        /// Spec YAML → biểu đồ.
        case chart
        /// Luật chất lượng (FR-DQR-003). Nhận biết được ngay từ bây giờ, nhưng phần CHẠY thuộc
        /// FR-DQR-003 — xem `ReportRenderer`.
        case quality
        /// Khai phá dữ liệu (FR-MIN-007).
        case mining
        /// Đánh giá truy hồi bằng golden set (FR-KNW-919).
        case retrieval
        /// Sơ đồ Mermaid (FR-MMD-003).
        ///
        /// Khối này KHÔNG chạy trong lõi: vẽ nó cần một engine JavaScript, mà lõi thì không
        /// được biết tới WebKit (NFR-MNT-01). Trình kết xuất để lại một CHỖ TRỐNG có đánh số,
        /// và tầng app điền SVG vào — xem `ReportRenderer.spliceMermaid`.
        case mermaid
    }

    public struct Block: Equatable, Sendable {
        public var kind: BlockKind
        public var content: String
        /// Dòng bắt đầu của hàng rào mở, 0-based — để nhảy tới chỗ lỗi trong trình soạn.
        public var line: Int
        /// Thứ tự xuất hiện trong tài liệu, dùng làm khoá ổn định cho preview.
        public var index: Int

        public init(kind: BlockKind, content: String, line: Int, index: Int) {
            self.kind = kind
            self.content = content
            self.line = line
            self.index = index
        }
    }

    /// Một đoạn của tài liệu: hoặc văn bản Markdown, hoặc một khối chạy được.
    ///
    /// Giữ THỨ TỰ xen kẽ chứ không tách thành hai danh sách. Báo cáo là một văn bản có mạch —
    /// tách khối ra khỏi văn xuôi rồi ghép lại theo chỉ số là cách chắc chắn để một ngày nào đó
    /// ghép sai thứ tự.
    public enum Segment: Equatable, Sendable {
        case markdown(String)
        case block(Block)
    }

    public var frontmatter: YAMLValue?
    public var segments: [Segment]

    public init(frontmatter: YAMLValue?, segments: [Segment]) {
        self.frontmatter = frontmatter
        self.segments = segments
    }

    public var blocks: [Block] {
        segments.compactMap { if case let .block(b) = $0 { return b } else { return nil } }
    }

    // MARK: - Phân tích

    public struct Failure: Error, Equatable, Sendable {
        public var line: Int
        public var message: String

        public init(line: Int, message: String) {
            self.line = line
            self.message = message
        }

        public var description: String { "dòng \(line + 1): \(message)" }
    }

    public static func parse(_ text: String) throws -> ReportDocument {
        var lines = text.components(separatedBy: "\n")
        var lineOffset = 0

        // --- Frontmatter -----------------------------------------------------------------
        //
        // `---` ở ĐÚNG dòng đầu tiên, đóng bằng `---` hoặc `...`. Không chấp nhận dòng trống
        // phía trước: một tài liệu bắt đầu bằng dòng trống rồi `---` thì `---` ấy là đường kẻ
        // ngang của Markdown, và nuốt nó thành frontmatter sẽ làm mất một phần nội dung mà
        // người dùng nhìn thấy trong trình soạn.
        var frontmatter: YAMLValue?
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            var end: Int?
            for index in 1..<lines.count {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                if trimmed == "---" || trimmed == "..." {
                    end = index
                    break
                }
            }
            guard let end else {
                throw Failure(line: 0, message: "frontmatter mở bằng «---» mà không có dòng "
                    + "«---» đóng lại")
            }
            let body = lines[1..<end].joined(separator: "\n")
            do {
                frontmatter = try YAMLReader.parse(body)
            } catch let failure as YAMLReader.Failure {
                // Cộng 1 để quy về số dòng của TỆP, không phải của đoạn frontmatter.
                throw Failure(
                    line: failure.line + 1, message: "frontmatter: \(failure.message)")
            }
            lines = Array(lines[(end + 1)...])
            lineOffset = end + 1
        }

        // --- Khối rào --------------------------------------------------------------------
        var segments: [Segment] = []
        var markdown: [String] = []
        var blockIndex = 0
        var cursor = 0

        func flushMarkdown() {
            guard !markdown.isEmpty else { return }
            let joined = markdown.joined(separator: "\n")
            // Đoạn chỉ có khoảng trắng không tạo ra segment — nếu không thì mỗi khối bị kẹp
            // giữa hai segment rỗng, và trình kết xuất sinh ra những thẻ `<p></p>` trống.
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.markdown(joined))
            }
            markdown.removeAll()
        }

        while cursor < lines.count {
            let raw = lines[cursor]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("```") else {
                markdown.append(raw)
                cursor += 1
                continue
            }

            let info = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            guard let kind = BlockKind(rawValue: info.lowercased()) else {
                // Khối rào KHÔNG phải của báo cáo (```sql, ```swift, ``` trần) đi thẳng sang
                // Markdown NGUYÊN VẸN, kể cả nội dung bên trong.
                //
                // Chỗ này dễ sai: nếu chỉ chuyển dòng mở rồi tiếp tục vòng lặp bình thường thì
                // một dòng `# tiêu đề` bên trong khối mã sẽ bị hiểu là tiêu đề Markdown, và một
                // dòng ```chart bên trong khối ví dụ sẽ bị CHẠY. Nên phải nhảy tới hàng rào
                // đóng và chép nguyên khối.
                markdown.append(raw)
                cursor += 1
                while cursor < lines.count {
                    markdown.append(lines[cursor])
                    let closing = lines[cursor].trimmingCharacters(in: .whitespaces)
                    cursor += 1
                    if closing.hasPrefix("```") { break }
                }
                continue
            }

            let openLine = cursor
            cursor += 1
            var body: [String] = []
            var closed = false
            while cursor < lines.count {
                if lines[cursor].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    closed = true
                    cursor += 1
                    break
                }
                body.append(lines[cursor])
                cursor += 1
            }
            guard closed else {
                throw Failure(
                    line: lineOffset + openLine,
                    message: "khối ```\(kind.rawValue) không có hàng rào ``` đóng lại")
            }
            let content = body.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else {
                throw Failure(
                    line: lineOffset + openLine,
                    message: "khối ```\(kind.rawValue) rỗng")
            }
            flushMarkdown()
            segments.append(.block(Block(
                kind: kind, content: content, line: lineOffset + openLine, index: blockIndex)))
            blockIndex += 1
        }
        flushMarkdown()
        return ReportDocument(frontmatter: frontmatter, segments: segments)
    }
}
