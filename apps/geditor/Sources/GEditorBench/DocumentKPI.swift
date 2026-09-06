import Foundation
import GEditorCore

/// Hai KPI thao tác tài liệu, theo đúng tiêu chí Pass trong STP §4.1.
///
///  - **TC-CORE-08 / FR-CORE-006** — 1 triệu dòng, 40% trùng, Remove Duplicate Lines giữ bản
///    đầu: số dòng đúng, thứ tự bản giữ nguyên, hoàn tất < 3 s, MỘT bước undo.
///  - **TC-CSV-03 / FR-CSV-404** — CSV 1 triệu dòng có quoted field, xóa cột 3: cột biến mất,
///    quoted field các cột khác nguyên vẹn, < 5 s, MỘT bước undo.
struct DocumentKPIReport: Encodable {

    struct Dedup: Encodable {
        let lines: Int
        let duplicateRatio: Double
        let uniqueLines: Int
        /// Dựng kế hoạch: quét dòng, băm nội dung, gộp vùng xóa.
        let planMs: Double
        let applyMs: Double
        let totalMs: Double
        let budgetMs: Double
        /// Số `TextEdit` sau khi gộp vùng liền nhau — nhỏ hơn số dòng bị xóa rất nhiều.
        let editCount: Int
        let deletedLines: Int
        let linesAfter: Int
        let orderPreserved: Bool
        let undoSteps: Int
        let pass: Bool
    }

    struct DeleteColumn: Encodable {
        let rows: Int
        let fixtureMB: Double
        let column: Int
        let planMs: Double
        let applyMs: Double
        let totalMs: Double
        let budgetMs: Double
        let editCount: Int
        let quotedFieldsIntact: Bool
        let undoSteps: Int
        let pass: Bool
    }

    let kpi = ["FR-CORE-006 (TC-CORE-08)", "FR-CSV-404 (TC-CSV-03)"]
    let architecture: String
    let dedup: Dedup
    let deleteColumn: DeleteColumn
    let notes: [String]
}

enum DocumentKPI {

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("  \(message)\n".utf8))
    }

    static func run(lines: Int, rows: Int) throws -> DocumentKPIReport {

        // --- TC-CORE-08 — khử trùng lặp -----------------------------------------------

        log("TC-CORE-08: \(lines) dòng, 40% trùng…")
        let (text, uniqueCount) = duplicateHeavyFixture(lines: lines, duplicateRatio: 0.4)
        let dedupBuffer = TextBuffer(original: MemoryByteSource(Array(text.utf8)))

        var edits: [TextEdit] = []
        let planMs = Measure.milliseconds {
            edits = (try? DocumentOps.removeDuplicateLines(in: dedupBuffer)) ?? []
        }
        let deleted = edits.reduce(0) { $0 + $1.range.count }
        let applyMs = Measure.milliseconds {
            dedupBuffer.applyEdits(edits, label: "Khử trùng lặp")
        }

        let linesAfter = dedupBuffer.lineCount
        // Thứ tự bản được giữ phải y như thứ tự xuất hiện lần đầu trong bản gốc.
        let expectedOrder = firstOccurrenceOrder(text)
        let actualOrder = (0 ..< min(linesAfter, expectedOrder.count)).map { dedupBuffer.line($0) }
        let orderPreserved = actualOrder == Array(expectedOrder.prefix(actualOrder.count))

        let dedupUndoSteps = dedupBuffer.canUndo ? 1 : 0
        _ = dedupBuffer.undo()
        let dedupOneStep = !dedupBuffer.canUndo

        let dedupTotal = planMs + applyMs
        let dedupPass = dedupTotal <= 3_000
            && linesAfter == uniqueCount
            && orderPreserved
            && dedupUndoSteps == 1 && dedupOneStep

        log(String(format: "  kế hoạch %.0f ms · áp dụng %.0f ms · TỔNG %.2f s (trần 3 s) · %d edit cho %d byte xóa · %d dòng còn lại (cần %d) · %@",
                   planMs, applyMs, dedupTotal / 1000, edits.count, deleted,
                   linesAfter, uniqueCount, dedupPass ? "ĐẠT" : "KHÔNG ĐẠT"))

        // --- TC-CSV-03 — xóa cột -------------------------------------------------------

        log("TC-CSV-03: CSV \(rows) hàng có quoted field, xóa cột 3…")
        let csv = csvFixture(rows: rows)
        let csvBuffer = TextBuffer(original: MemoryByteSource(csv))
        let fixtureMB = Double(csv.count) / 1_048_576

        var csvEdits: [TextEdit] = []
        let csvPlanMs = Measure.milliseconds {
            csvEdits = (try? CSVOps.deleteColumn(2, in: csvBuffer, dialect: .comma)) ?? []
        }
        let csvApplyMs = Measure.milliseconds {
            csvBuffer.applyEdits(csvEdits, label: "Xóa cột")
        }

        // Quoted field ở cột 1 phải còn nguyên cả dấu bọc lẫn dấu phẩy bên trong.
        let firstLine = csvBuffer.line(0)
        let quotedIntact = firstLine.contains("\"Công ty Anh Đào, CN Huế\"")

        let csvUndoSteps = csvBuffer.canUndo ? 1 : 0
        _ = csvBuffer.undo()
        let csvOneStep = !csvBuffer.canUndo

        let csvTotal = csvPlanMs + csvApplyMs
        let csvPass = csvTotal <= 5_000 && quotedIntact && csvUndoSteps == 1 && csvOneStep

        log(String(format: "  kế hoạch %.0f ms · áp dụng %.0f ms · TỔNG %.2f s (trần 5 s) · %d edit · quoted field %@ · %@",
                   csvPlanMs, csvApplyMs, csvTotal / 1000, csvEdits.count,
                   quotedIntact ? "nguyên vẹn" : "BỊ VỠ", csvPass ? "ĐẠT" : "KHÔNG ĐẠT"))

        return DocumentKPIReport(
            architecture: GEditorCore.architecture,
            dedup: .init(
                lines: lines, duplicateRatio: 0.4, uniqueLines: uniqueCount,
                planMs: planMs, applyMs: applyMs, totalMs: dedupTotal, budgetMs: 3_000,
                editCount: edits.count, deletedLines: lines - uniqueCount, linesAfter: linesAfter,
                orderPreserved: orderPreserved, undoSteps: dedupUndoSteps, pass: dedupPass
            ),
            deleteColumn: .init(
                rows: rows, fixtureMB: fixtureMB, column: 2,
                planMs: csvPlanMs, applyMs: csvApplyMs, totalMs: csvTotal, budgetMs: 5_000,
                editCount: csvEdits.count, quotedFieldsIntact: quotedIntact,
                undoSteps: csvUndoSteps, pass: csvPass
            ),
            notes: [
                "Dòng trùng được rải TẤT ĐỊNH khắp tài liệu chứ không dồn cụm: dồn cụm sẽ gộp thành vài edit và làm phép đo dễ hơn thực tế.",
                "Kế hoạch và áp dụng đo tách nhau vì chúng chịu chi phối bởi hai thứ khác nhau — băm nội dung và thao tác trên cây piece.",
                "Trần lấy từ STP §4.1; con số thời gian là của MÁY ĐANG ĐO, phải đo lại trên máy chuẩn §2.1 trước khi chốt.",
            ]
        )
    }

    // MARK: - Fixture

    /// Tài liệu có đúng `duplicateRatio` phần dòng là bản trùng, rải đều và TẤT ĐỊNH.
    private static func duplicateHeavyFixture(
        lines: Int, duplicateRatio: Double
    ) -> (text: String, uniqueLines: Int) {
        let uniqueCount = Int(Double(lines) * (1 - duplicateRatio))
        var rng = DeterministicRNG(seed: 4_2026)
        var out = ""
        out.reserveCapacity(lines * 24)

        var written = 0
        var nextUnique = 0
        while written < lines {
            // Xen kẽ dòng mới và dòng lặp lại một dòng đã có, thay vì gom các bản trùng lại
            // với nhau — dữ liệu thật nằm rải rác, và gộp vùng xóa sẽ ăn gian nếu chúng liền kề.
            if nextUnique < uniqueCount, rng.int(10) >= 4 {
                out += "DH-\(nextUnique),Công ty số \(nextUnique),\(nextUnique * 1000)\n"
                nextUnique += 1
            } else if nextUnique > 0 {
                let repeated = rng.int(nextUnique)
                out += "DH-\(repeated),Công ty số \(repeated),\(repeated * 1000)\n"
            } else {
                out += "DH-0,Công ty số 0,0\n"
                nextUnique = 1
            }
            written += 1
        }
        return (out, nextUnique)
    }

    /// CSV có quoted field chứa dấu phẩy ở cột 1 — đúng hình dạng TC-CSV-03 yêu cầu.
    private static func csvFixture(rows: Int) -> [UInt8] {
        let template = Array(Fixture.line.utf8)
        var out = [UInt8]()
        out.reserveCapacity(rows * template.count)
        for _ in 0 ..< rows { out.append(contentsOf: template) }
        return out
    }

    /// Thứ tự các dòng theo lần XUẤT HIỆN ĐẦU TIÊN — kỳ vọng sau khi khử trùng lặp giữ bản đầu.
    private static func firstOccurrenceOrder(_ text: String) -> [String] {
        var seen = Set<String>()
        var order: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).dropLast() {
            let value = String(line)
            if seen.insert(value).inserted { order.append(value) }
        }
        return order
    }
}
