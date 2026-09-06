import Foundation
import GEditorCore

/// NFR-KNW-02 — mở và index JSONL 1 GB tới **trạng thái duyệt record được** ≤ 10 giây.
///
/// ## Câu hỏi này có hai vế, và chỉ vế đầu là cổng
///
/// Chỉ tiêu nói "tới trạng thái duyệt record được", không nói "tới lúc kiểm xong mọi bản ghi".
/// Hai việc ấy khác nhau cả bậc độ lớn, và gộp chúng lại là tự đặt cho mình một chỉ tiêu khác
/// với chỉ tiêu đã ký:
///
/// * **Mở + index** — mmap tệp, dựng chỉ mục dòng của piece table. Sau bước này bản ghi thứ n
///   đã lấy ra được, tức người dùng cuộn được. **Đây là thứ NFR-KNW-02 chấm.**
/// * **Kiểm** — đọc hết tệp, chạy bộ đọc JSON trên từng dòng. Đây là việc nền có tiến độ và
///   huỷ, và bộ đo vẫn in ra để biết nó tốn bao nhiêu.
///
/// Bộ đo cũng đo **thời gian lấy một bản ghi bất kỳ** sau khi mở, vì "duyệt được" mà mỗi lần
/// cuộn tốn nửa giây thì chữ "duyệt được" ấy không thật.
enum JSONLKPI {

    static func run(arguments: [String]) {
        let sizeMB = intOption("--mb", in: arguments, default: 1_024)
        let cache = ".build/poc-m"
        try? FileManager.default.createDirectory(
            atPath: cache, withIntermediateDirectories: true)
        // Dùng LẠI corpus của PoC-M: cùng bộ sinh có seed cố định, nên hai bộ đo nói về cùng
        // một tệp và số liệu của chúng so được với nhau.
        let corpus = cache + "/corpus-\(sizeMB)mb.jsonl"
        if !FileManager.default.fileExists(atPath: corpus) {
            FileHandle.standardError.write(Data("▸ Sinh corpus \(sizeMB) MB…\n".utf8))
            BM25KPI.generateCorpus(path: corpus, megabytes: sizeMB)
        }
        let corpusBytes = (try? FileManager.default
            .attributesOfItem(atPath: corpus)[.size] as? Int) ?? 0 ?? 0

        print("\n▸ KPI JSONL — chế độ JSONL (FR-KNW-901, NFR-KNW-02)")

        // --- 1. Mở + index: cổng của NFR-KNW-02 ------------------------------------------
        let openStart = DispatchTime.now().uptimeNanoseconds
        guard let document = try? Document.open(path: corpus) else {
            FileHandle.standardError.write(Data("❌ không mở được \(corpus)\n".utf8))
            exit(1)
        }
        let lineCount = document.buffer.lineCount
        let openMs = Double(DispatchTime.now().uptimeNanoseconds - openStart) / 1_000_000

        // --- 2. Lấy bản ghi bất kỳ: "duyệt được" phải THẬT ------------------------------
        //
        // Lấy rải khắp tệp chứ không lấy liên tiếp: đọc tuần tự thì mọi trang đã nằm trong bộ
        // nhớ đệm, và con số đo được sẽ nói về bộ nhớ đệm chứ không nói về việc nhảy tới.
        var jumpMs: [Double] = []
        let step = max(1, lineCount / 200)
        for index in stride(from: 0, to: lineCount, by: step).prefix(200) {
            let started = DispatchTime.now().uptimeNanoseconds
            _ = JSONLScan.prettyRecord(buffer: document.buffer, line: index)
            jumpMs.append(Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
        }
        jumpMs.sort()
        let jumpMedian = jumpMs.isEmpty ? 0 : jumpMs[jumpMs.count / 2]
        let jumpWorst = jumpMs.last ?? 0

        // --- 3. Nhận diện ------------------------------------------------------------------
        let sniffStart = DispatchTime.now().uptimeNanoseconds
        let recognized = JSONLScan.looksLikeJSONL(buffer: document.buffer, path: corpus)
        let sniffMs = Double(DispatchTime.now().uptimeNanoseconds - sniffStart) / 1_000_000

        // --- 4. Kiểm cả tệp: KHÔNG phải cổng, nhưng phải biết nó tốn bao nhiêu -------------
        var reports = 0
        let scanStart = DispatchTime.now().uptimeNanoseconds
        let result = JSONLScan.scan(buffer: document.buffer) { _ in reports += 1; return true }
        let scanMs = Double(DispatchTime.now().uptimeNanoseconds - scanStart) / 1_000_000

        // --- 5. Thống kê chunk: vế thứ hai của NFR-KNW-02 --------------------------------
        //
        // Chỉ tiêu viết *"thống kê chunk 1 triệu record ≤ 15 giây (DuckDB)"*. Chữ "(DuckDB)"
        // là GỢI Ý cài đặt của đặc tả, không phải điều kiện: bộ này đọc thẳng trên vùng byte
        // của tài liệu đang mở, nên nó không phải nạp lại 1 GB vào một bảng để đếm độ dài
        // chuỗi. Con số đo được nằm dưới, và ai muốn đổi sang DuckDB thì phải đánh bại nó.
        let inspectStart = DispatchTime.now().uptimeNanoseconds
        let inspection = ChunkInspector.inspect(buffer: document.buffer)
        let inspectMs = Double(DispatchTime.now().uptimeNanoseconds - inspectStart) / 1_000_000
        let inspectBudgetMs = 15_000.0 * Double(lineCount) / 1_000_000

        let budgetMs = 10_000.0
        print("  corpus        \(corpusBytes / 1_000_000) MB · \(lineCount) dòng")
        print(String(format: "  mở + index    %.0f ms   / trần %.0f ms  ← NFR-KNW-02",
                     openMs, budgetMs))
        print(String(format: "  nhảy tới dòng %.3f ms (trung vị) · %.3f ms (xấu nhất)",
                     jumpMedian, jumpWorst))
        print(String(format: "  nhận diện     %.1f ms · %@", sniffMs, recognized ? "CÓ" : "KHÔNG"))
        print(String(format: "  kiểm cả tệp   %.0f ms · %d bản ghi · %d lỗi · %d nhịp tiến độ",
                     scanMs, result.recordCount, result.problemCount, reports))

        print(String(format: "  thống kê chunk %.0f ms / trần %.0f ms (theo tỷ lệ 15 s cho 1 "
                     + "triệu bản ghi)", inspectMs, inspectBudgetMs))
        print("  đoán schema   văn bản «\(inspection.textField ?? "—")» · "
              + "định danh «\(inspection.schema.id ?? "—")» · "
              + "\(inspection.schema.metadataFields.count) trường metadata")
        print(String(format: "  độ dài chunk  %d–%d ký tự · trung bình %.0f · %d rỗng · %d nhóm trùng",
                     inspection.characters.minimum, inspection.characters.maximum,
                     inspection.characters.average, inspection.emptyCount,
                     inspection.duplicateCount))

        let passed = openMs <= budgetMs && recognized && inspectMs <= inspectBudgetMs
        print(passed ? "\n✅ NFR-KNW-02 ĐẠT" : "\n❌ NFR-KNW-02 TRƯỢT")

        let payload: [String: Any] = [
            "corpusBytes": corpusBytes,
            "lineCount": lineCount,
            "openMs": openMs,
            "openBudgetMs": budgetMs,
            "jumpMedianMs": jumpMedian,
            "jumpWorstMs": jumpWorst,
            "sniffMs": sniffMs,
            "recognized": recognized,
            "scanMs": scanMs,
            "recordCount": result.recordCount,
            "problemCount": result.problemCount,
            "progressReports": reports,
            "inspectMs": inspectMs,
            "inspectBudgetMs": inspectBudgetMs,
            "textField": inspection.textField ?? "",
            "idField": inspection.schema.id ?? "",
            "emptyCount": inspection.emptyCount,
            "duplicateGroupCount": inspection.duplicateCount,
            "passed": passed,
        ]
        let path = "benchmarks/results/jsonl-\(architecture()).json"
        try? FileManager.default.createDirectory(
            atPath: "benchmarks/results", withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(
            withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("   kết quả ở \(path)")
        }
        exit(passed ? 0 : 1)
    }

    private static func intOption(_ name: String, in arguments: [String], default value: Int)
        -> Int {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
              let parsed = Int(arguments[index + 1]) else { return value }
        return parsed
    }

    private static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
