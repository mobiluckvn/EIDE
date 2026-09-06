import Foundation

/// Kết quả chạy một công thức trên một file (FR-CLN-005).
public struct CSVRecipeRun: Equatable {

    public struct StepResult: Equatable {
        public let step: CSVRecipeStep
        /// Cột thật sự đã chạm tới, sau khi tìm theo tên.
        public let column: Int?
        public let summary: String
        public let applied: Bool
        /// Vì sao bước không chạy — `nil` nghĩa là đã chạy.
        public let problem: String?
    }

    public let recipeName: String
    public let fileName: String
    public let results: [StepResult]

    public var appliedCount: Int { results.filter(\.applied).count }
    public var skippedCount: Int { results.count - appliedCount }
    /// Có bước nào KHÔNG chạy được không — chỗ gọi phải nói ra, không được im lặng.
    public var hasProblems: Bool { results.contains { $0.problem != nil } }

    /// Báo cáo Markdown cho MỘT file (NFR-CLN-02c).
    ///
    /// Mỗi file một báo cáo riêng, kể cả khi chạy hàng loạt: gộp chung thì một file hỏng chìm
    /// nghỉm giữa hai chục file trôi chảy, mà file hỏng mới là thứ người ta cần thấy.
    public var report: String {
        var out = "## \(fileName)\n\n"
        out += "Công thức «\(recipeName)» — \(appliedCount) bước chạy"
        out += skippedCount > 0 ? ", \(skippedCount) bước bỏ qua\n\n" : "\n\n"
        for (index, result) in results.enumerated() {
            let mark = result.applied ? "✓" : "✗"
            out += "\(index + 1). \(mark) \(result.step.displayName)\n"
            out += "   - \(result.problem ?? result.summary)\n"
        }
        return out
    }
}

/// Chạy công thức làm sạch lên một tài liệu (FR-CLN-005).
public enum CSVRecipeRunner {

    /// Chạy công thức và ÁP vào buffer, tất cả trong MỘT bước undo.
    ///
    /// Phải áp chứ không chỉ trả về sửa đổi như các thao tác đơn lẻ: bước thứ hai được tính
    /// trên tài liệu ĐÃ CÓ bước thứ nhất. Dựng sẵn mọi sửa đổi rồi áp một lượt sẽ sai ngay khi
    /// một bước xóa hàng — mọi offset phía sau nó dịch đi.
    ///
    /// Một bước undo cho cả công thức, đúng đặc tả: người dùng chạy nhầm công thức lên file thì
    /// một lần ⌘Z là về nguyên trạng, chứ không phải bấm bảy lần và tự đoán đã về tới đâu.
    @discardableResult
    public static func run(
        _ recipe: CSVRecipe,
        on buffer: TextBuffer,
        dialect: CSVDialect,
        fileName: String,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        cancelToken: CancelToken = CancelToken()
    ) throws -> CSVRecipeRun {
        var results: [CSVRecipeRun.StepResult] = []

        buffer.beginUndoGroup(label: "Công thức «\(recipe.name)»")
        defer { buffer.endUndoGroup() }

        for step in recipe.steps {
            try cancelToken.check()

            guard step.enabled else {
                results.append(.init(
                    step: step, column: nil, summary: "", applied: false,
                    problem: "bước đang tắt"
                ))
                continue
            }

            // Tên cột đọc LẠI ở mỗi bước: một bước trước đó có thể đã xóa hàng hoặc đổi ô, và
            // hàng tiêu đề vẫn là nguồn sự thật cho bước tiếp theo.
            let names = headerNames(in: buffer, dialect: dialect, hasHeader: hasHeader)
            guard let column = resolve(step, in: names) else {
                results.append(.init(
                    step: step, column: nil, summary: "", applied: false,
                    problem: problemDescription(step, names: names)
                ))
                continue
            }

            let clean = CSVCleanStep(column: column, kind: step.kind)
            let outcome = try clean.run(
                in: buffer, dialect: dialect, hasHeader: hasHeader,
                spec: spec, cancelToken: cancelToken
            )
            buffer.applyEdits(
                outcome.edits,
                label: clean.displayName(columnName: step.columnName ?? "cột \(column + 1)")
            )
            results.append(.init(
                step: step, column: column, summary: outcome.summary,
                applied: !outcome.isEmpty,
                problem: outcome.isEmpty ? "không có gì để đổi" : nil
            ))
        }

        return CSVRecipeRun(recipeName: recipe.name, fileName: fileName, results: results)
    }

    /// Tìm cột cho một bước: theo TÊN trước, chỉ số chỉ là dự phòng.
    ///
    /// Đây là chỗ một công thức chạy sai có thể phá dữ liệu mà không ai biết. File tháng sau
    /// thêm một cột ở giữa thì "cột thứ 3" trỏ vào cột khác hẳn, và chuẩn hóa ngày lên cột
    /// doanh thu sẽ viết lại những con số thành ngày tháng. Bước có tên cột mà file không có
    /// tên ấy thì KHÔNG chạy — thà bỏ một bước còn hơn chạy nó lên nhầm chỗ.
    public static func resolve(_ step: CSVRecipeStep, in names: [String]) -> Int? {
        if let name = step.columnName, !name.isEmpty {
            return names.firstIndex(of: name)
        }
        // Công thức không ghi tên (file không có hàng tiêu đề): chỉ còn chỉ số để mà dùng.
        return step.columnIndex < max(names.count, step.columnIndex + 1) ? step.columnIndex : nil
    }

    private static func problemDescription(_ step: CSVRecipeStep, names: [String]) -> String {
        guard let name = step.columnName else { return "không tìm được cột" }
        let available = names.prefix(8).map { "«\($0)»" }.joined(separator: ", ")
        return "file này không có cột «\(name)» — cột hiện có: \(available)"
    }

    /// Tên các cột, đọc từ hàng tiêu đề.
    public static func headerNames(
        in buffer: TextBuffer, dialect: CSVDialect, hasHeader: Bool
    ) -> [String] {
        guard hasHeader, buffer.count > 0 else { return [] }
        var names: [String] = []
        try? CSVEngine.forEachRow(in: buffer, dialect: dialect) { row in
            names = row.map {
                String(
                    decoding: CSVEngine.unescape(buffer.bytes(in: $0.range), dialect: dialect),
                    as: UTF8.self
                )
            }
            return false
        }
        return names
    }
}
