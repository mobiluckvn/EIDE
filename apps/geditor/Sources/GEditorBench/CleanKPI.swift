import Foundation
import GEditorCore

/// Đo cụm làm sạch — NFR-CLN-01.
///
/// Chỉ tiêu: "Data Profile trên bảng 1 triệu dòng × 20 cột hoàn tất ≤ 10 giây (máy chuẩn Apple
/// Silicon)". Bài này đo ĐÚNG cỡ ấy chứ không đo cỡ nhỏ rồi nhân lên: chi phí trên mỗi ô không
/// phải hằng số — bảng băm distinct đầy dần, bộ nhớ đệm trượt khác đi, và bản ngoại suy từ
/// 100 nghìn hàng đã từng cho một con số lệch hẳn với số đo thật.
///
/// Đo cả bộ phát hiện của Bàn làm sạch (FR-CLN-006) trong cùng lần chạy: hai phép quét đọc
/// cùng một bảng theo hai đường khác nhau, và đặt cạnh nhau mới thấy đường nào đắt ở đâu.
struct CleanKPIReport: Encodable {

    struct Pass: Encodable {
        let rows: Int
        let columns: Int
        let cells: Int
        let fixtureMB: Double
        let seconds: Double
        let millionCellsPerSecond: Double
        let budgetSeconds: Double?
        let pass: Bool?
    }

    struct Filter: Encodable {
        let rows: Int
        let description: String
        let matched: Int
        /// Thời gian tới MÀN HÌNH ĐẦU TIÊN — con số mà NFR-QRY-01 nói tới.
        let firstScreenMs: Double
        /// Thời gian quét hết file để biết tổng số dòng khớp.
        let fullScanMs: Double
        let budgetMs: Double
        let pass: Bool
    }

    let kpi = [
        "NFR-CLN-01 (Data Profile)", "FR-CLN-006 (bộ phát hiện)", "NFR-QRY-01 (gõ filter)",
    ]
    let architecture: String
    let profile: Pass
    let scanner: Pass
    let filters: [Filter]
    /// Kiểm ĐÚNG, không chỉ kiểm NHANH: một phép quét nhanh mà sai thì con số thời gian vô nghĩa.
    let correctness: [String: String]
    let notes: [String]
}

enum CleanKPI {

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("  \(message)\n".utf8))
    }

    static func run(rows: Int, columns: Int) throws -> CleanKPIReport {
        log("dựng fixture \(rows) hàng × \(columns) cột…")
        let bytes = fixture(rows: rows, columns: columns)
        let buffer = TextBuffer(original: MemoryByteSource(bytes))
        let fixtureMB = Double(bytes.count) / 1_048_576
        let cells = rows * columns
        log(String(format: "  %.0f MB · %d ô", fixtureMB, cells))

        // --- Data Profile ----------------------------------------------------------------
        var report: CSVProfileReport?
        let profileSeconds = Measure.milliseconds {
            report = try? CSVProfiler.profile(in: buffer, dialect: .comma)
        } / 1000
        guard let report else { throw CSVTableKPI.BenchError.failed("không dựng được hồ sơ") }

        let profilePass = CleanKPIReport.Pass(
            rows: rows, columns: columns, cells: cells, fixtureMB: fixtureMB,
            seconds: profileSeconds,
            millionCellsPerSecond: Double(cells) / profileSeconds / 1_000_000,
            budgetSeconds: 10, pass: profileSeconds <= 10
        )
        log(String(format: "  hồ sơ: %.2f s (trần 10 s) · %@",
                   profileSeconds, profileSeconds <= 10 ? "ĐẠT" : "KHÔNG ĐẠT"))

        // --- bộ phát hiện của Bàn làm sạch -----------------------------------------------
        var findings: [CSVCleanFinding] = []
        let scanSeconds = Measure.milliseconds {
            findings = (try? CSVCleanScanner.scan(in: buffer, dialect: .comma)) ?? []
        } / 1000
        let scannerPass = CleanKPIReport.Pass(
            rows: rows, columns: columns, cells: cells, fixtureMB: fixtureMB,
            seconds: scanSeconds,
            millionCellsPerSecond: Double(cells) / scanSeconds / 1_000_000,
            budgetSeconds: nil, pass: nil
        )
        log(String(format: "  bộ phát hiện: %.2f s · %d nhóm", scanSeconds, findings.count))

        // --- lọc theo cột (NFR-QRY-01) ----------------------------------------------------
        //
        // "Gõ filter phản hồi ≤ 300 ms". Đo trên CÙNG bảng một triệu hàng: mỗi lần người dùng
        // gõ thêm một ký tự là một lượt quét mới, nên đây là con số họ cảm nhận được.
        var filters: [CleanKPIReport.Filter] = []
        let cases: [(String, [CSVFilterCondition])] = [
            ("chữ, một cột", [CSVFilter.parse("Huế", column: 1)!]),
            ("số, một cột", [CSVFilter.parse(">800000", column: 2)!]),
            ("hai cột (AND)", [
                CSVFilter.parse("Huế", column: 1)!, CSVFilter.parse(">400000", column: 2)!,
            ]),
            ("ô thiếu", [CSVFilter.parse("null", column: 3)!]),
            // Trường hợp XẤU NHẤT: hàng khớp duy nhất nằm ở cuối bảng, nên "màn hình đầu tiên"
            // cũng phải quét hết file. Không đo ca này là tự lừa mình bằng những con số đẹp.
            ("khớp một hàng CUỐI bảng", [
                CSVFilter.parse("=KH\(String(format: "%08d", rows - 1))", column: 0)!,
            ]),
        ]
        for (name, conditions) in cases {
            var matched = 0
            let firstMs = Measure.milliseconds {
                _ = CSVFilter.rows(
                    matching: conditions, in: buffer, dialect: .comma,
                    prefix: CSVFilter.firstScreen
                )
            }
            let fullMs = Measure.milliseconds {
                matched = CSVFilter.rows(matching: conditions, in: buffer, dialect: .comma).rows.count
            }
            filters.append(CleanKPIReport.Filter(
                rows: rows, description: name, matched: matched,
                firstScreenMs: firstMs, fullScanMs: fullMs,
                budgetMs: 300, pass: firstMs <= 300
            ))
            log(String(format: "  lọc %@: màn đầu %.0f ms · quét hết %.0f ms · %d dòng khớp · %@",
                       name, firstMs, fullMs, matched, firstMs <= 300 ? "ĐẠT" : "KHÔNG ĐẠT"))
        }

        // --- kiểm ĐÚNG -------------------------------------------------------------------
        //
        // Fixture dựng có chủ ý: cột 1 là mã duy nhất, cột 2 có đúng 5 giá trị, cột 3 là số có
        // một giá trị cực đoan cấy vào, cột 4 có 1/10 ô thiếu. Sai chỗ nào thì con số thời
        // gian ở trên không còn nghĩa gì.
        var checks: [String: String] = [:]
        func check(_ name: String, _ actual: String, _ expected: String) {
            checks[name] = actual == expected ? "ĐÚNG (\(actual))" : "SAI: \(actual) ≠ \(expected)"
        }
        check("cột mã: distinct là cận dưới",
              String(report.columns[0].distinctExact), "false")
        check("cột thành phố: distinct",
              String(report.columns[1].distinct), "5")
        check("cột doanh thu: kiểu",
              report.columns[2].type.displayName, CSVValueType.number.displayName)
        check("cột doanh thu: bắt được giá trị cực đoan",
              String(report.columns[2].outliers.contains { $0.value == "999999999" }), "true")
        check("cột ghi chú: tỉ lệ null",
              String(format: "%.1f", report.columns[3].nullPercent), "10.0")
        check("cột ngày: kiểu",
              report.columns[4].type.displayName, CSVValueType.date(.iso).displayName)

        for (name, result) in checks.sorted(by: { $0.key < $1.key }) {
            log("  \(result.hasPrefix("ĐÚNG") ? "✓" : "✗") \(name): \(result)")
        }

        return CleanKPIReport(
            architecture: architecture,
            profile: profilePass,
            scanner: scannerPass,
            filters: filters,
            correctness: checks,
            notes: [
                "Đo ở ĐÚNG cỡ của NFR-CLN-01, không ngoại suy từ bảng nhỏ.",
                "Hồ sơ đọc byte của cửa sổ; chuỗi chỉ dựng cho ô không rỗng và giữ lại cho bảng đếm.",
                "distinct đếm chính xác tới \(CSVProfiler.distinctLimit); vượt thì là CẬN DƯỚI.",
                "Lọc đo trên cùng bảng: mỗi ký tự người dùng gõ là một lượt quét mới.",
            ]
        )
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    /// Bảng thử: mỗi cột có một tính chất mà hồ sơ phải nói đúng.
    /// Bảng mẫu tất định. `internal` chứ không `private` vì PoC-G dùng LẠI đúng bảng này:
    /// kỳ vọng đúng-sai của nó suy thẳng từ công thức sinh ở đây, nên hai bên phải là một.
    static func fixture(rows: Int, columns: Int) -> [UInt8] {
        var header = ["ma_kh", "thanh_pho", "doanh_thu", "ghi_chu", "ngay"]
        while header.count < columns { header.append("cot\(header.count + 1)") }
        header = Array(header.prefix(columns))

        var out = Array((header.joined(separator: ",") + "\n").utf8)
        out.reserveCapacity(rows * (18 * columns))
        let cities = ["Hà Nội", "TP Hồ Chí Minh", "Đà Nẵng", "Huế", "Cần Thơ"]

        for row in 0 ..< rows {
            var fields: [String] = []
            fields.append("KH\(String(format: "%08d", row))")             // duy nhất
            fields.append(cities[row % 5])                                 // đúng 5 giá trị
            // Một giá trị cực đoan duy nhất, cấy vào giữa bảng.
            fields.append(row == rows / 2 ? "999999999" : "\((row * 137) % 900_000)")
            fields.append(row % 10 == 0 ? "N/A" : "binh thuong")           // 10% thiếu
            fields.append("2026-08-\(String(format: "%02d", row % 28 + 1))")
            while fields.count < columns {
                fields.append("v\(row % 1_000)_\(fields.count)")
            }
            out.append(contentsOf: Array((fields.prefix(columns).joined(separator: ",") + "\n").utf8))
        }
        return out
    }
}
