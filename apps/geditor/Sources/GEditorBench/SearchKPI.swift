import Foundation
import GEditorCore

/// Hai KPI cuối còn đo được ở mức lõi, theo đúng tiêu chí Pass trong STP §4.1.
///
///  - **TC-PERF-06 / NFR-PERF-08** — regex thay 1 triệu kết quả trên 100 MB: ≤ 30 s,
///    và toàn bộ phải là MỘT bước undo.
///  - **TC-PERF-05 / NFR-PERF-06** — find-in-files trên 10 000 file, đo ở 4 và 8 lõi:
///    thời gian 8 lõi ≤ 0,6 × thời gian 4 lõi (scale gần tuyến tính).
///
/// Những KPI còn lại trong danh sách "pending" đều cần ứng dụng thật và engine hiển thị từ
/// PoC-A; không bộ đo mức lõi nào chạm tới được.
struct SearchKPIReport: Encodable {

    struct Replace: Encodable {
        let fixtureMB: Double
        let pattern: String
        let template: String
        let matches: Int
        /// Dựng kế hoạch sửa đổi (tìm + giãn chuỗi thay thế).
        let planMs: Double
        /// Áp vào piece table như MỘT nhóm undo.
        let applyMs: Double
        let undoMs: Double
        let totalMs: Double
        let budgetMs: Double
        /// Số bước undo sinh ra. Phải bằng 1 — FR-CORE-004 và TC-PERF-06 đều đòi vậy.
        let undoSteps: Int
        let footprintPeakMB: Double
        let pass: Bool
    }

    struct ScalePoint: Encodable {
        let concurrency: Int
        let elapsedMs: Double
        let throughputMBps: Double
        /// Nhanh gấp mấy lần so với một luồng. Đây mới là con số nói được "có dùng đa lõi
        /// không"; tỉ lệ 8/4 của STP chỉ là một lát cắt của cùng đường cong này.
        let speedupOverSingle: Double
    }

    /// So hai cách nạp file ở cùng số luồng — `read()` vào bộ đệm dùng lại, hay `mmap`.
    struct IOStrategyPoint: Encodable {
        let strategy: String
        let concurrency: Int
        let elapsedMs: Double
        let throughputMBps: Double
    }

    struct Scaling: Encodable {
        let files: Int
        let totalMB: Double
        let activeCores: Int
        let filesWithMatches: Int
        let expectedFilesWithMatches: Int
        let points: [ScalePoint]
        /// Thời gian 8 lõi chia thời gian 4 lõi. Tiêu chí STP: ≤ 0,6.
        let ratioEightOverFour: Double
        let threshold: Double
        let pass: Bool
        let ioStrategy: [IOStrategyPoint]
        /// Vì sao con số ở đây KHÔNG kết luận được TC-PERF-05.
        let caveat: String
    }

    let kpi = ["NFR-PERF-06 (TC-PERF-05)", "NFR-PERF-08 (TC-PERF-06)"]
    let architecture: String
    let pcre2Version: String
    let replaceMillionMatches: Replace
    let findInFiles: Scaling
    let notes: [String]
}

enum SearchKPI {

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("  \(message)\n".utf8))
    }

    static func run(megabytes: Int, treeFiles: Int, kilobytesPerFile: Int) throws -> SearchKPIReport {

        // --- TC-PERF-06 — thay 1 triệu kết quả trên 100 MB -----------------------------

        log("TC-PERF-06: thay 1 triệu kết quả trên \(megabytes) MB…")
        let fixture = Fixture.inMemory(megabytes: megabytes)
        let fixtureMB = Double(fixture.count) / 1_048_576

        // `\d{4}-\d{2}-\d{2}` → ngày ở cuối mỗi dòng; template dùng tham chiếu nhóm để phép
        // đo đi qua ĐƯỜNG CHẬM (pcre2_substitute mỗi kết quả), không phải đường nhanh chuỗi
        // hằng. Đo đường nhanh ở đây là tự cho điểm.
        let pattern = "(\\d{4})-(\\d{2})-(\\d{2})"
        let template = "$3/$2/$1"
        let target = 1_000_000

        let compiled = try PCRE2Pattern(pattern: pattern, options: SearchOptions(mode: .regex))
        var plan: ReplacementPlan!
        let planMs = fixture.withUnsafeBytes { buffer in
            Measure.milliseconds {
                plan = try? compiled.replacementEdits(
                    in: buffer, template: template, limit: target, subjectIsValidUTF8: true
                )
            }
        }
        guard let plan, plan.edits.count == target else {
            throw NSError(domain: "GEditorBench", code: 3, userInfo: [
                NSLocalizedDescriptionKey:
                    "fixture \(megabytes) MB chỉ cho \(plan?.edits.count ?? 0) kết quả, cần \(target)"
            ])
        }

        let buffer = TextBuffer(original: MemoryByteSource(fixture))
        let applyMs = Measure.milliseconds {
            buffer.applyEdits(plan.edits, label: "Thay thế tất cả")
        }
        let footprintPeak = ProcessMemory.snapshot().footprintMB

        let undoSteps = buffer.canUndo ? 1 : 0
        let undoMs = Measure.milliseconds { _ = buffer.undo() }
        let stillHasUndo = buffer.canUndo

        let totalMs = planMs + applyMs
        let budgetMs = 30_000.0
        let replacePass = totalMs <= budgetMs && undoSteps == 1 && !stillHasUndo

        log(String(format: "  kế hoạch %.0f ms · áp dụng %.0f ms · TỔNG %.1f s (trần 30 s) · undo %.0f ms · %@",
                   planMs, applyMs, totalMs / 1000, undoMs, replacePass ? "ĐẠT" : "KHÔNG ĐẠT"))

        // --- TC-PERF-05 — find-in-files scale theo số lõi ------------------------------

        log("TC-PERF-05: dựng cây \(treeFiles) file × \(kilobytesPerFile) KB…")
        let (root, expectedMatches) = try Fixture.tree(
            files: treeFiles, kilobytesPerFile: kilobytesPerFile
        )

        let options = FindInFiles.Options(includeGlobs: ["*.csv", "*.log"])
        let files = FindInFiles.collectFiles(root: root, options: options)
        let totalBytes = files.reduce(0) { total, path in
            total + ((try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0 ?? 0)
        }
        let totalMB = Double(totalBytes) / 1_048_576
        log("  \(files.count) file sau lọc · \(Int(totalMB)) MB")

        let needle = try PCRE2Pattern(
            pattern: Fixture.targetNeedle, options: SearchOptions(mode: .normal)
        )

        var points: [SearchKPIReport.ScalePoint] = []
        var matchedFiles = 0
        for concurrency in [1, 2, 4, 8] {
            var summary: FindInFiles.Summary!
            // Đo 3 lần lấy trung vị: lần đầu chịu phạt page cache, mà ta đang so hai cấu hình
            // với nhau chứ không đo tốc độ đĩa.
            let elapsed = Measure.repeated(3) {
                var options = options
                options.concurrency = concurrency
                summary = try? FindInFiles.search(files: files, pattern: needle, options: options)
            }
            matchedFiles = summary?.results.count ?? 0
            points.append(SearchKPIReport.ScalePoint(
                concurrency: concurrency,
                elapsedMs: elapsed,
                throughputMBps: totalMB / (elapsed / 1000),
                speedupOverSingle: (points.first?.elapsedMs ?? elapsed) / elapsed
            ))
            log(String(format: "  %d luồng: %8.0f ms · %6.0f MB/s · %d file có kết quả",
                       concurrency, elapsed, totalMB / (elapsed / 1000), matchedFiles))
        }

        // So hai chiến lược nạp file ở cùng 8 luồng. Ngưỡng đặt bằng 0 = luôn mmap;
        // đặt rất lớn = luôn read(). Điểm hòa vốn phụ thuộc kích thước file nên phải ĐO,
        // và tham số này tồn tại trong `Options` chính vì thế.
        var ioPoints: [SearchKPIReport.IOStrategyPoint] = []
        for (label, threshold) in [("mmap", 0), ("read", Int.max)] {
            var probe = options
            probe.concurrency = 8
            probe.readInsteadOfMapBelowBytes = threshold
            let elapsed = Measure.repeated(3) {
                _ = try? FindInFiles.search(files: files, pattern: needle, options: probe)
            }
            ioPoints.append(SearchKPIReport.IOStrategyPoint(
                strategy: label, concurrency: 8, elapsedMs: elapsed,
                throughputMBps: totalMB / (elapsed / 1000)
            ))
            log(String(format: "  nạp bằng %-5@ (8 luồng): %6.0f ms · %6.0f MB/s",
                       label as NSString, elapsed, totalMB / (elapsed / 1000)))
        }

        let four = points.first { $0.concurrency == 4 }!.elapsedMs
        let eight = points.first { $0.concurrency == 8 }!.elapsedMs
        let ratio = eight / four
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let scalePass = ratio <= 0.6 && matchedFiles == expectedMatches

        log(String(format: "  8 lõi / 4 lõi = %.2f (trần 0,60) · %@",
                   ratio, scalePass ? "ĐẠT" : "KHÔNG ĐẠT"))

        return SearchKPIReport(
            architecture: GEditorCore.architecture,
            pcre2Version: PCRE2SearchEngine.version,
            replaceMillionMatches: .init(
                fixtureMB: fixtureMB,
                pattern: pattern,
                template: template,
                matches: plan.edits.count,
                planMs: planMs,
                applyMs: applyMs,
                undoMs: undoMs,
                totalMs: totalMs,
                budgetMs: budgetMs,
                undoSteps: undoSteps,
                footprintPeakMB: footprintPeak,
                pass: replacePass
            ),
            findInFiles: .init(
                files: files.count,
                totalMB: totalMB,
                activeCores: cores,
                filesWithMatches: matchedFiles,
                expectedFilesWithMatches: expectedMatches,
                points: points,
                ratioEightOverFour: ratio,
                threshold: 0.6,
                pass: scalePass,
                ioStrategy: ioPoints,
                caveat: """
                    STP TC-PERF-05 đo bằng cách GIỚI HẠN MÁY còn 4 rồi 8 lõi (taskpolicy) trên                     máy chuẩn §2.1. Ở đây chỉ giới hạn được SỐ LUỒNG CÔNG NHÂN trên một máy                     \(ProcessInfo.processInfo.activeProcessorCount) lõi — hai thí nghiệm khác nhau:                     lượt 4 luồng vẫn được dùng toàn bộ băng thông bộ nhớ và cache của cả máy,                     nên nó nhanh hơn so với một máy thật sự chỉ có 4 lõi, và tỉ lệ 8/4 vì thế                     bị đẩy lên. Con số kết luận được là speedupOverSingle; tỉ lệ 8/4 phải đo                     lại trên máy chuẩn.
                    """
            ),
            notes: [
                "Template dùng tham chiếu nhóm nên mỗi kết quả đi qua pcre2_substitute — đường CHẬM. Template chuỗi hằng nhanh hơn nhiều nhưng không đại diện.",
                "Số lõi giới hạn bằng số luồng công nhân, không phải taskpolicy như STP mô tả: cách này chặn đúng thứ cần chặn và không cần quyền đặc biệt.",
                "Máy đo có \(ProcessInfo.processInfo.activeProcessorCount) lõi hoạt động; tỉ lệ 8/4 chỉ có nghĩa khi máy đủ 8 lõi thật.",
                "Cây fixture nằm ngoài repo tại GEDITOR_FIXTURE_DIR và được dùng lại giữa các lần chạy.",
            ]
        )
    }
}
