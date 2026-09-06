import Foundation
import GEditorCore

/// PoC-C (SAD §8, ADR-03): PCRE2 + JIT trên hai kiến trúc, và hành vi khi gặp deadline.
///
/// Ba câu hỏi phải trả lời, theo README "BẮT ĐẦU CODE TỪ ĐÂU":
///   1. Throughput trên 100 MB là bao nhiêu, và JIT đáng giá bao nhiêu so với interpreter?
///   2. Pattern backtracking độc bị chặn NHƯ THẾ NÀO, và `match_limit` quy ra bao nhiêu ms?
///   3. JIT có chạy trên CẢ HAI kiến trúc không (NFR-PORT-01)?
struct PoCCReport: Encodable {

    struct Build: Encodable {
        let pcre2Version: String
        let jitAvailable: Bool
        let jitTarget: String
    }

    struct PatternResult: Encodable {
        let name: String
        let pattern: String
        let mode: String
        let matches: Int
        let compileMs: Double
        let jitCompileMs: Double
        let jitThroughputMBps: Double
        let interpreterThroughputMBps: Double
        /// JIT nhanh gấp mấy lần interpreter trên chính pattern này.
        let jitSpeedup: Double
        /// Nhánh interpreter có bị cắt vì quá hạn hay không. Khi `true`, throughput của nó là
        /// số đo TRÊN PHẦN ĐÃ QUÉT ĐƯỢC và `jitSpeedup` là CẬN DƯỚI, không phải giá trị thật.
        let interpreterTimedOut: Bool
    }

    struct CalibrationPoint: Encodable {
        let matchLimit: UInt32
        let jitElapsedMs: Double
        let interpreterElapsedMs: Double
        /// "budget" = bị trần chặn (đúng như mong đợi); "match"/"nomatch" = chạy xong.
        let outcome: String
    }

    struct Deadline: Encodable {
        let pattern: String
        let subjectLength: Int
        let calibration: [CalibrationPoint]
        let recommendedMatchLimit: UInt32
        let worstCaseMsAtRecommended: Double
        let budgetMs: Double
    }

    struct BulkMatch: Encodable {
        let targetMatches: Int
        let elapsedMs: Double
        let matchesPerSecond: Double
    }

    /// Giá của việc để PCRE2 tự kiểm tính hợp lệ UTF-8 ở MỖI lần khớp.
    ///
    /// Đo trên fixture NHỎ vì đường chậm là O(n²) — chạy nó ở 100 MB thì benchmark không
    /// bao giờ kết thúc, và đó chính là kết luận cần ghi vào ADR.
    struct UTFCheckCost: Encodable {
        let fixtureMB: Double
        let matches: Int
        let validatedOnceMs: Double
        let recheckedEveryMatchMs: Double
        let slowdown: Double
    }

    let poc = "PoC-C"
    let adr = "ADR-03"
    let architecture: String
    let build: Build
    let fixtureMB: Double
    let patterns: [PatternResult]
    let deadline: Deadline
    let bulkMatch: BulkMatch
    let utfCheckCost: UTFCheckCost
    let notes: [String]
}

enum PoCC {

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("  \(message)\n".utf8))
    }

    /// Pattern đại diện cho việc người dùng thật sự làm trên file CSV/log.
    ///
    /// Cố ý gồm cả những dạng có đặc tính hiệu năng rất khác nhau: chuỗi thuần (engine dùng
    /// memchr), pattern có neo (bỏ qua phần lớn vị trí), lớp Unicode (tra bảng), và tham
    /// chiếu ngược (JIT không tối ưu được nhiều).
    static let patterns: [(name: String, pattern: String, mode: SearchMode)] = [
        ("literal", "Thừa Thiên Huế", .normal),
        ("mã đơn", "\\bDH-\\d+\\b", .regex),
        ("ngày", "\\d{4}-\\d{2}-\\d{2}", .regex),
        ("neo đầu dòng", "^DH-\\d+", .regex),
        ("lựa chọn", "(Huế|Đà Nẵng|Hà Nội)", .regex),
        ("lớp Unicode", "\\p{L}{4,}", .regex),
        ("số tiền", "[0-9]{6,}", .regex),
        ("tham chiếu ngược", "(\\w{2,})\\1", .regex),
    ]

    /// Hạn cho MỖI phép đo throughput.
    ///
    /// Cần thiết vì nhánh interpreter không chỉ chậm hơn mà với vài pattern là không dùng
    /// được: `\bDH-\d+\b` mất ~159 giây trên 32 MB, gấp 10⁴ lần nhánh JIT. Không có hạn này
    /// thì benchmark treo — và bản thân việc phải đặt hạn đã là một kết luận của PoC-C.
    static let measurementTimeout: TimeInterval = 5

    static func run(megabytes: Int, budgetMs: Double) throws -> PoCCReport {
        let fixture = Fixture.inMemory(megabytes: megabytes)
        let fixtureMB = Double(fixture.count) / 1_048_576

        log("PCRE2 \(PCRE2SearchEngine.version) · JIT \(PCRE2SearchEngine.isJITAvailable ? "có" : "KHÔNG") · target \(PCRE2SearchEngine.jitTarget)")
        log("fixture \(Int(fixtureMB)) MB")

        // --- 1. Throughput từng pattern, JIT vs interpreter ----------------------------

        var results: [PoCCReport.PatternResult] = []
        for entry in patterns {
            let options = SearchOptions(mode: entry.mode)

            let jitPattern = try PCRE2Pattern(pattern: entry.pattern, options: options, useJIT: true)
            let plainPattern = try PCRE2Pattern(pattern: entry.pattern, options: options, useJIT: false)

            // `subjectIsValidUTF8: true` — fixture do ta sinh ra nên chắc chắn hợp lệ. Bỏ qua
            // tham số này là rơi vào đường O(n²), xem `utfCheckCost`.
            let jit = scan(jitPattern, over: fixture)
            let interpreter = scan(plainPattern, over: fixture)

            let jitMBps = fixtureMB / (jit.elapsedMs / 1000)
            // Khi bị cắt vì quá hạn, chỉ tính trên số byte THỰC SỰ đã quét — báo throughput
            // theo cả fixture sẽ là nói dối theo hướng có lợi cho ta.
            let interpreterMB = Double(interpreter.coveredBytes) / 1_048_576
            let interpreterMBps = interpreterMB / (interpreter.elapsedMs / 1000)
            let speedup = interpreterMBps > 0 ? jitMBps / interpreterMBps : 0

            results.append(PoCCReport.PatternResult(
                name: entry.name,
                pattern: entry.pattern,
                mode: "\(entry.mode)",
                matches: jit.matches,
                compileMs: jitPattern.compileMilliseconds,
                jitCompileMs: jitPattern.jitMilliseconds,
                jitThroughputMBps: jitMBps,
                interpreterThroughputMBps: interpreterMBps,
                jitSpeedup: speedup,
                interpreterTimedOut: interpreter.timedOut
            ))
            let name = entry.name.padding(toLength: 18, withPad: " ", startingAt: 0)
            let flag = interpreter.timedOut ? " ⏱" : "  "
            log(String(format: "  %@ JIT %7.0f MB/s · interp %7.0f MB/s%@ (×%.0f) · %d kết quả",
                       name, jitMBps, interpreterMBps, flag, speedup, jit.matches))
        }

        // --- 2. Hiệu chỉnh trần backtracking ------------------------------------------
        //
        // `(a+)+$` trên chuỗi toàn 'a' không kết thúc bằng khớp: engine phải thử mọi cách
        // chia chuỗi thành các nhóm 'a' → số bước tăng theo hàm mũ. Đây là dạng pattern mà
        // người dùng gõ nhầm vẫn ra, nên phải chặn được chứ không chỉ khuyến cáo.

        let catastrophicPattern = "(a+)+$"
        let subject = Array((String(repeating: "a", count: 60) + "!").utf8)
        log("hiệu chỉnh trần backtracking trên \(catastrophicPattern)…")

        var calibration: [PoCCReport.CalibrationPoint] = []
        var recommended: UInt32 = 1_000
        var worstCase: Double = 0

        for limit in [UInt32(1_000), 10_000, 100_000, 1_000_000, 10_000_000] {
            var limits = PCRE2Pattern.Limits()
            limits.matchLimit = limit
            limits.depthLimit = limit

            var outcome = "match"
            let jitMs = try measureBudget(
                catastrophicPattern, subject: subject, limits: limits, useJIT: true, outcome: &outcome
            )
            var ignored = ""
            let plainMs = try measureBudget(
                catastrophicPattern, subject: subject, limits: limits, useJIT: false, outcome: &ignored
            )

            calibration.append(PoCCReport.CalibrationPoint(
                matchLimit: limit,
                jitElapsedMs: jitMs,
                interpreterElapsedMs: plainMs,
                outcome: outcome
            ))
            log(String(format: "  match_limit %10d → JIT %8.2f ms · interp %8.2f ms (%@)",
                       limit, jitMs, plainMs, outcome))

            // Trần được đề xuất là trần LỚN NHẤT còn nằm trong ngân sách, xét cả hai nhánh:
            // interpreter là đường dự phòng khi JIT hỏng, không được phép chậm hơn ngân sách.
            if max(jitMs, plainMs) <= budgetMs {
                recommended = limit
                worstCase = max(jitMs, plainMs)
            }
        }

        // --- 3. Tốc độ gom kết quả hàng loạt (nền của NFR-PERF-08) ---------------------

        let target = 1_000_000
        let bulkPattern = try PCRE2Pattern(pattern: "\\d+", options: SearchOptions(mode: .regex))
        var collected = 0
        let bulkMs = fixture.withUnsafeBytes { buffer in
            Measure.milliseconds {
                collected = 0
                try? bulkPattern.enumerateMatches(in: buffer, subjectIsValidUTF8: true) { _ in
                    collected += 1
                    return collected < target
                }
            }
        }
        log(String(format: "gom %d kết quả: %.0f ms", collected, bulkMs))

        // --- 4. Giá của việc kiểm UTF-8 lặp lại --------------------------------------

        let smallMB = 2
        let small = Fixture.inMemory(megabytes: smallMB)
        let smallMBValue = Double(small.count) / 1_048_576
        let utfPattern = try PCRE2Pattern(pattern: "DH-\\d+", options: SearchOptions(mode: .regex))
        var utfMatches = 0

        let fastMs = small.withUnsafeBytes { buffer in
            Measure.milliseconds {
                utfMatches = 0
                try? utfPattern.enumerateMatches(in: buffer, subjectIsValidUTF8: true) { _ in
                    utfMatches += 1
                    return true
                }
            }
        }
        let slowMs = small.withUnsafeBytes { buffer in
            Measure.milliseconds {
                try? utfPattern.enumerateMatches(in: buffer, subjectIsValidUTF8: false) { _ in true }
            }
        }
        log(String(format: "kiểm UTF-8 %d MB: một lần %.1f ms · mỗi lần khớp %.1f ms (×%.0f)",
                   smallMB, fastMs, slowMs, slowMs / max(fastMs, 0.000_001)))

        return PoCCReport(
            architecture: GEditorCore.architecture,
            build: .init(
                pcre2Version: PCRE2SearchEngine.version,
                jitAvailable: PCRE2SearchEngine.isJITAvailable,
                jitTarget: PCRE2SearchEngine.jitTarget
            ),
            fixtureMB: fixtureMB,
            patterns: results,
            deadline: .init(
                pattern: catastrophicPattern,
                subjectLength: subject.count,
                calibration: calibration,
                recommendedMatchLimit: recommended,
                worstCaseMsAtRecommended: worstCase,
                budgetMs: budgetMs
            ),
            bulkMatch: .init(
                targetMatches: collected,
                elapsedMs: bulkMs,
                matchesPerSecond: Double(collected) / (bulkMs / 1000)
            ),
            utfCheckCost: .init(
                fixtureMB: smallMBValue,
                matches: utfMatches,
                validatedOnceMs: fastMs,
                recheckedEveryMatchMs: slowMs,
                slowdown: slowMs / max(fastMs, 0.000_001)
            ),
            notes: [
                "Throughput đo trên nguồn trong RAM để loại nhiễu I/O — chỉ so engine với engine.",
                "interpreterThroughputMBps là ĐƯỜNG DỰ PHÒNG khi JIT không biên dịch được pattern, không phải cấu hình phát hành.",
                "Hiệu chỉnh trần dùng (a+)+$ trên chuỗi toàn 'a': số bước tăng theo hàm mũ, không có kết quả khớp.",
                "budgetMs là ngân sách cho MỘT lần khớp; find-in-files còn chịu thêm CancelToken giữa các kết quả.",
            ]
        )
    }

    /// Quét toàn bộ `bytes`, có hạn thời gian.
    ///
    /// Trả về cả số byte ĐÃ QUÉT để phép đo bị cắt giữa chừng vẫn quy ra được throughput
    /// trung thực thay vì phải bỏ đi.
    private static func scan(
        _ pattern: PCRE2Pattern, over bytes: [UInt8]
    ) -> (matches: Int, elapsedMs: Double, coveredBytes: Int, timedOut: Bool) {
        var matches = 0
        var covered = 0
        var timedOut = false
        let token = CancelToken(timeout: measurementTimeout)

        let elapsed = bytes.withUnsafeBytes { buffer in
            Measure.milliseconds {
                do {
                    try pattern.enumerateMatches(
                        in: buffer, subjectIsValidUTF8: true, cancelToken: token
                    ) { match in
                        matches += 1
                        covered = match.range.upperBound
                        return true
                    }
                    covered = buffer.count
                } catch {
                    timedOut = true
                }
            }
        }
        return (matches, elapsed, covered, timedOut)
    }

    /// Đo thời gian tới lúc engine bỏ cuộc (hoặc chạy xong) với một trần cho trước.
    private static func measureBudget(
        _ pattern: String,
        subject: [UInt8],
        limits: PCRE2Pattern.Limits,
        useJIT: Bool,
        outcome: inout String
    ) throws -> Double {
        let compiled = try PCRE2Pattern(
            pattern: pattern, options: SearchOptions(mode: .regex), limits: limits, useJIT: useJIT
        )
        var result = "nomatch"
        let elapsed = subject.withUnsafeBytes { buffer in
            Measure.milliseconds {
                do {
                    var found = false
                    try compiled.enumerateMatches(in: buffer) { _ in found = true; return false }
                    result = found ? "match" : "nomatch"
                } catch is RegexBudgetExceeded {
                    result = "budget"
                } catch {
                    result = "error"
                }
            }
        }
        outcome = result
        return elapsed
    }
}
