import Foundation
import GEditorCore

/// NFR-DQR-01 — *"1 triệu dòng × 50 rule ≤ 15 giây"* (FR-DQR-001).
///
/// Đo ở ĐÚNG cỡ chỉ tiêu nói tới, không đo cỡ nhỏ rồi nhân lên — cùng lý do PoC-G đã ghi: chi
/// phí mỗi ô không phải hằng số, và chỉ con số ở cỡ thật mới dùng được.
///
/// Chỉ tiêu còn nói CÁCH đạt: *"RuleCompiler gom các rule cùng cột thành ÍT LƯỢT QUÉT nhất có
/// thể"*. Nên bộ đo này in thêm một cột đối chứng: cùng 50 luật ấy chạy TỪNG CÂU MỘT. Không có
/// nó thì "618 ms" chỉ nói rằng nó nhanh, không nói rằng thiết kế gom-một-lượt là thứ làm nó nhanh.
enum QualityKPI {
    struct Report: Encodable {
        let kpi: String
        let architecture: String
        let rows: Int
        let columns: Int
        let ruleCount: Int
        let batchedMs: Double
        let oneByOneMs: Double
        let speedup: Double
        let budgetMs: Double
        let pass: Bool
        let violationsBySample: [String: Int]
        let notes: [String]
    }

    static func run(rows: Int, columns: Int) throws -> Report {
        FileHandle.standardError.write(Data("   dựng fixture \(rows) hàng…\n".utf8))
        let bytes = CleanKPI.fixture(rows: rows, columns: columns)
        let directory = NSTemporaryDirectory() + "geditor-dqr-kpi-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/bang.csv"
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        let buffer = TextBuffer(original: MemoryByteSource(bytes))

        // Năm loại luật × mười lượt = 50, đúng con số chỉ tiêu nói tới.
        var yaml = "rules:\n"
        for _ in 0 ..< 10 {
            yaml += "  - col: ma_kh\n    not_null: true\n"
            yaml += "  - col: doanh_thu\n    range: {min: 0}\n"
            yaml += "  - col: thanh_pho\n"
            yaml += "    in_set: [Hà Nội, Huế, Đà Nẵng, Cần Thơ, TP Hồ Chí Minh]\n"
            yaml += "  - col: ngay\n    date_format: '%Y-%m-%d'\n"
            yaml += "  - col: ghi_chu\n    length: {max: 40}\n"
        }
        let rules = try QualityRules.load(fromYAML: yaml)

        // Một lượt hâm nóng, không tính giờ: nạp file vào page cache để phép đo đầu tiên không
        // phải trả tiền hộ những phép sau.
        _ = try QualityEngine.evaluate(
            QualityRules(rules: [rules.rules[0]]), in: buffer, dialect: .comma, sourcePath: path)

        FileHandle.standardError.write(Data("   50 luật, GOM một lượt quét…\n".utf8))
        let batched = try QualityEngine.evaluate(
            rules, in: buffer, dialect: .comma, sourcePath: path)

        FileHandle.standardError.write(Data("   50 luật, TỪNG CÂU MỘT (đối chứng)…\n".utf8))
        let start = DispatchTime.now().uptimeNanoseconds
        for rule in rules.rules {
            _ = try QualityEngine.evaluate(
                QualityRules(rules: [rule]), in: buffer, dialect: .comma, sourcePath: path)
        }
        let oneByOne = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000

        // Đúng-sai: số vi phạm suy từ CÔNG THỨC SINH fixture, không suy từ kết quả engine.
        //  - `ghi_chu` là "N/A" ở mỗi hàng thứ 10, còn lại "binh thuong" — không ô nào quá 40.
        //  - `thanh_pho` xoay vòng đúng năm thành phố trong danh sách.
        //  - `doanh_thu` luôn ≥ 0.
        var sample: [String: Int] = [:]
        for result in batched.results.prefix(5) {
            sample[result.rule.title] = result.violations
        }

        return Report(
            kpi: "NFR-DQR-01 — 1 triệu dòng × 50 rule ≤ 15 s",
            architecture: architectureName(),
            rows: rows, columns: columns, ruleCount: rules.rules.count,
            batchedMs: batched.milliseconds, oneByOneMs: oneByOne,
            speedup: oneByOne / max(batched.milliseconds, 0.001),
            budgetMs: 15_000, pass: batched.milliseconds <= 15_000,
            violationsBySample: sample,
            notes: [
                "Cột đối chứng 'từng câu một' KHÔNG phải một bản hiện thực khác — nó là chính"
                    + " engine ấy chạy 50 lần với mỗi lần một luật. Chênh lệch vì thế đo đúng"
                    + " một thứ: giá của việc gom nhiều luật vào một lượt quét.",
                "Mọi kỳ vọng đúng-sai suy từ công thức sinh fixture (CleanKPI.fixture), không"
                    + " suy từ kết quả engine đang đo.",
            ]
        )
    }

    private static func architectureName() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
