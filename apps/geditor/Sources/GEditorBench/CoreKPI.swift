import Foundation
import GEditorCore

/// Bộ đo KPI mức lõi cho CI (STP §4.1).
///
/// Quy trình chuẩn theo STP: Release build, máy cắm nguồn, đóng ứng dụng khác, mỗi chỉ số
/// đo 5 lần LẤY TRUNG VỊ. Kết quả ghi JSON vào repo; CI so với baseline và fail khi suy
/// giảm > 10% trên bất kỳ KPI nào (SAD §7 — benchmark là bước chặn merge).
///
/// PHẠM VI: chỉ các KPI mức LÕI. Những KPI cần ứng dụng thật (NFR-PERF-01 khởi động nguội,
/// NFR-PERF-03 mở 1 GB tới tương tác, NFR-PERF-04 latency gõ p95, NFR-PERF-07 năng lượng)
/// nằm trong mục "pending" của JSON để không ai nhầm bộ đo này là đã phủ hết NFR-PERF.
enum CoreKPI {

    struct Report: Encodable {
        let architecture: String
        let simdBackend: String
        let version: String
        let fixtureMB: Double
        let iterations: Int
        let metrics: [String: Double]
        let pending: [String]
    }

    static let iterations = 5

    /// 32 MB — đủ để số đo ổn định, đủ nhanh cho CI.
    static let fixtureMegabytes = 32

    static func run() -> Report {
        let fixture = Fixture.inMemory(megabytes: fixtureMegabytes)
        let fixtureMB = Double(fixture.count) / 1_048_576
        var metrics: [String: Double] = [:]

        // KPI 1 — dựng chỉ mục dòng (đường nóng khi mở file: SAD §4.2 bước 2).
        let indexMs = Measure.repeated(iterations) {
            _ = fixture.withUnsafeBytes { LineIndex(bytes: $0) }
        }
        metrics["lineIndexThroughputMBps"] = fixtureMB / (indexMs / 1000)

        // KPI 1bis — dựng CỬA SỔ nội dung 2 MB (ADR-01 §3.2).
        //
        // Ngân sách của ADR-01 là **4,5 ms mỗi lần nạp cửa sổ**, và con số ấy nằm trong tài
        // liệu từ lâu mà KHÔNG có gì canh. Đây là đường nóng nhất của lớp hiển thị: mỗi lần
        // cuộn ra khỏi cửa sổ hiện tại là một lần dựng lại, và người dùng cảm nhận nó trực
        // tiếp — quá ngân sách thì cuộn giật.
        //
        // Đo trên chữ TIẾNG VIỆT chứ không phải ASCII: cả hàm này sống bằng việc đi qua từng
        // scalar và cộng bề rộng byte, nên ASCII cho ra một con số đẹp mà vô nghĩa với người
        // dùng của sản phẩm.
        //
        // **Đọc con số này cho đúng.** Sáu lượt liên tiếp trên máy rảnh cho 5,09–5,32 ms, tức
        // biên độ 5% — vừa đủ nằm trong dung sai 10% của cổng chặn merge. Nhưng một lượt chạy
        // NGAY SAU bộ cổng khác cho 5,82 ms, tức 12%: đủ để cổng đỏ oan.
        //
        // Nên khi chỉ số này đỏ, hỏi "máy lúc ấy có đang bận không" TRƯỚC khi đi tìm hồi quy.
        // Cùng họ với `CLIBridgeTests` từng đỏ thất thường vì chạy cùng `run-coverage.sh`.
        let windowLine = "Nguyễn Thị Hồng Nhung, Quận Tân Bình, Thành phố Hồ Chí Minh\n"
        let windowText = String(repeating: windowLine, count: (2 << 20) / windowLine.utf8.count)
        let windowBuffer = TextBuffer(text: windowText)
        let windowMs = Measure.repeated(iterations) {
            _ = TextWindowing.window(around: windowBuffer.count / 2, in: windowBuffer)
        }
        metrics["textWindowBuild2MBMs"] = windowMs

        // KPI 2 — parse CSV RFC 4180 (FR-CSV-401).
        let csvMs = Measure.repeated(iterations) { _ = CSVEngine.parse(fixture, dialect: .comma) }
        metrics["csvParseThroughputMBps"] = fixtureMB / (csvMs / 1000)

        // KPI 3 — quét newline bằng nhánh SIMD (NEON/AVX2).
        let scanMs = Measure.repeated(iterations) { _ = ByteScan.countNewlines(in: fixture) }
        metrics["newlineScanThroughputMBps"] = fixtureMB / (scanMs / 1000)

        // KPI 4 — ghi file atomic 32 MB (NFR-REL-02): giá phải trả cho temp + fsync + rename.
        let tempPath = NSTemporaryDirectory() + "/geditor-bench-\(getpid()).bin"
        let writeMs = Measure.repeated(iterations) { try? AtomicFileWriter.write(fixture, to: tempPath) }
        metrics["atomicWriteThroughputMBps"] = fixtureMB / (writeMs / 1000)
        unlink(tempPath)

        // KPI 5 — một nhóm sửa 10.000 vị trí = một bước undo (FR-CORE-004, PoC-B).
        let buffer = TextBuffer(original: MemoryByteSource(fixture))
        let stride = max(2, fixture.count / 10_001)
        let edits = (0 ..< 10_000).map { i in
            TextEdit(range: (i * stride) ..< (i * stride + 2), text: "XX")
        }
        metrics["batchEdit10kMs"] = Measure.milliseconds {
            buffer.applyEdits(edits, label: "benchmark")
        }

        // KPI 6 — MỘT phím gõ trên tài liệu đã phân mảnh, p95 (ADR-02, cổng của NFR-PERF-04).
        //
        // Chỉ số này chặn đúng hồi quy mà PoC-B vừa khắc phục: nếu ai đó đưa lại việc dựng
        // lại chỉ mục dòng sau mỗi lần sửa, mọi KPI khác vẫn xanh còn chỉ số này nổ.
        let typing = TextBuffer(original: MemoryByteSource(fixture))
        var rng = DeterministicRNG(seed: 20260819)
        var typingSamples: [Double] = []
        typingSamples.reserveCapacity(2_000)
        for _ in 0 ..< 2_000 {
            let offset = rng.int(typing.count + 1)
            typingSamples.append(Measure.milliseconds {
                typing.applyEdits([TextEdit.insert(at: offset, text: "x")], label: "Gõ")
                _ = typing.lineCount
                _ = typing.lineNumber(atOffset: offset)
            })
        }
        metrics["interactiveTypingP95Ms"] = Measure.percentile(typingSamples, 0.95)

        // KPI 7 — tra cứu dòng trên tài liệu đã phân mảnh (2 000 piece), p95.
        var querySamples: [Double] = []
        querySamples.reserveCapacity(2_000)
        for _ in 0 ..< 2_000 {
            let line = rng.int(typing.lineCount)
            querySamples.append(Measure.milliseconds { _ = typing.offset(ofLineStart: line) })
        }
        metrics["lineQueryP95Ms"] = Measure.percentile(querySamples, 0.95)

        // KPI 8/9 — regex PCRE2 + JIT (ADR-03). Hai pattern có đặc tính rất khác nhau:
        // chuỗi thuần đi đường tối ưu memchr, còn pattern có định lượng thì không.
        //
        // Cổng này bắt hai kiểu hồi quy im lặng: JIT thôi biên dịch được (rơi về interpreter,
        // chậm 3–10⁴ lần) và việc lỡ tay bỏ `subjectIsValidUTF8` (kiểm UTF-8 lặp lại, O(n²)).
        for (key, pattern, mode) in [
            ("regexLiteralThroughputMBps", "Thừa Thiên Huế", SearchMode.normal),
            ("regexDateThroughputMBps", "\\d{4}-\\d{2}-\\d{2}", SearchMode.regex),
        ] {
            guard let compiled = try? PCRE2Pattern(
                pattern: pattern, options: SearchOptions(mode: mode)
            ) else { continue }
            let elapsed = fixture.withUnsafeBytes { buffer in
                Measure.repeated(3) {
                    try? compiled.enumerateMatches(in: buffer, subjectIsValidUTF8: true) { _ in true }
                }
            }
            metrics[key] = fixtureMB / (elapsed / 1000)
        }

        return Report(
            architecture: GEditorCore.architecture,
            simdBackend: GEditorCore.simdBackend,
            version: GEditorCore.version,
            fixtureMB: fixtureMB,
            iterations: iterations,
            metrics: metrics,
            // NFR-PERF-06 và NFR-PERF-08 đã rời danh sách này: chúng được đo trong
            // `geditor-bench search` theo đúng tiêu chí TC-PERF-05/TC-PERF-06, vì cần fixture
            // 10 000 file và 100 MB — quá nặng cho cổng chặn merge chạy ở mỗi lần push.
            pending: [
                "NFR-PERF-01 khởi động nguội — cần app thật (TC-PERF-01)",
                "NFR-PERF-02 mở file 100 MB tới tương tác (TC-PERF-02)",
                "NFR-PERF-03 mở 1 GB + cuộn 60 fps (TC-PERF-03/TC-DOC-03)",
                "NFR-PERF-04 latency gõ p95 ≤ 16 ms — phần lõi đã đo ở interactiveTypingP95Ms; phần hiển thị cần engine từ PoC-A",
                "NFR-PERF-05 RAM idle ≤ 80 MB (TC-PERF-04)",
                "NFR-PERF-07 năng lượng Low (TC-PERF-07)",
            ]
        )
    }
}
