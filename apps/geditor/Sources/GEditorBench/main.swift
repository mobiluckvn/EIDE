import Foundation

// Điểm vào của bộ đo. JSON đi ra stdout (script CI đọc thẳng); tiến trình đi ra stderr.
//
//   geditor-bench                      KPI lõi cho CI (STP §4.1) — mặc định
//   geditor-bench poc-b [--mb N]       PoC-B: piece table trên mmap file lớn (SAD §8, ADR-02)
//   geditor-bench poc-c [--mb N]       PoC-C: PCRE2 + JIT và hành vi deadline (SAD §8, ADR-03)
//   geditor-bench poc-d [--mb a,b,c]   PoC-D: tô màu cú pháp tree-sitter (SAD §8, ADR-04)
//   geditor-bench poc-g [--rows N]     PoC-G: tập con SQL trên CSVEngine (FR-CSV-407)
//   geditor-bench search               NFR-PERF-06 + NFR-PERF-08 theo tiêu chí STP §4.1
//   geditor-bench ops                  TC-CORE-08 (khử trùng lặp) + TC-CSV-03 (xóa cột)
//   geditor-bench csv-table [--rows N] FR-CSV-403: chỉ mục hàng, tra cứu, sắp xếp Table view
//   geditor-bench clean [--rows N]     NFR-CLN-01: hồ sơ dữ liệu + bộ phát hiện Bàn làm sạch
//
// Tùy chọn của poc-b:
//   --mb N            kích thước fixture, mặc định 1024 (1 GB)
//   --typing N        số lần gõ phím lẻ, mặc định 10000
//   --batch N         số vị trí trong một nhóm undo, mặc định 10000
//   --scale a,b,c     các kích thước MB để so cây piece với mảng phẳng, mặc định 4,16,64,256
//   --scale-edits N   số lần sửa ở mỗi mốc scale, mặc định 2000

func intOption(_ name: String, default fallback: Int) -> Int {
    guard let index = CommandLine.arguments.firstIndex(of: name),
          index + 1 < CommandLine.arguments.count,
          let value = Int(CommandLine.arguments[index + 1])
    else { return fallback }
    return value
}

func stringOption(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name),
          index + 1 < CommandLine.arguments.count
    else { return nil }
    return CommandLine.arguments[index + 1]
}

func listOption(_ name: String, default fallback: [Int]) -> [Int] {
    guard let index = CommandLine.arguments.firstIndex(of: name),
          index + 1 < CommandLine.arguments.count
    else { return fallback }
    let parsed = CommandLine.arguments[index + 1].split(separator: ",").compactMap { Int($0) }
    return parsed.isEmpty ? fallback : parsed
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

func emit<T: Encodable>(_ value: T) throws {
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
}

let mode = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? "core"

switch mode {
case "poc-b":
    FileHandle.standardError.write(Data("▸ PoC-B — piece table trên mmap (SAD §8, ADR-02)\n".utf8))
    let report = try PoCB.run(
        megabytes: intOption("--mb", default: 1024),
        interactiveEdits: intOption("--typing", default: 10_000),
        batchEdits: intOption("--batch", default: 10_000),
        scaleSizes: listOption("--scale", default: [4, 16, 64, 256]),
        scaleEdits: intOption("--scale-edits", default: 2_000)
    )
    try emit(report)

case "poc-d":
    FileHandle.standardError.write(
        Data("▸ PoC-D — tô màu cú pháp tree-sitter (SAD §8, ADR-04)\n".utf8)
    )
    try emit(PoCD.run(
        megabytes: listOption("--mb", default: [1, 8, 64]),
        // 2 MB đúng bằng cửa sổ nội dung mà ADR-01 đã chốt — phép đo cuối chỉ có nghĩa khi
        // lát cắt bằng đúng cái cửa sổ thật.
        sliceMegabytes: intOption("--slice", default: 2)
    ))

case "poc-d-fixture":
    // In dữ liệu thử ra stdout để KIỂM BẰNG MẮT và bằng công cụ của chính ngôn ngữ ấy.
    let lang = CommandLine.arguments.firstIndex(of: "--lang")
        .flatMap { $0 + 1 < CommandLine.arguments.count ? CommandLine.arguments[$0 + 1] : nil } ?? "python"
    if let language = PoCD.Language.all.first(where: { $0.name == lang }) {
        FileHandle.standardOutput.write(Data(language.fixture(megabytes: intOption("--mb", default: 1))))
    }

case "poc-d-python":
    let probeLang = CommandLine.arguments.firstIndex(of: "--lang")
        .flatMap { $0 + 1 < CommandLine.arguments.count ? CommandLine.arguments[$0 + 1] : nil } ?? "python"
    try emit(PoCDPython.run(sizes: listOption("--mb", default: [1, 2, 4, 8]), languageName: probeLang))

case "poc-d-mem":
    // Một phép đo bộ nhớ, một tiến trình. Xem `scripts/run-poc-d.sh`.
    let name = CommandLine.arguments.firstIndex(of: "--lang")
        .flatMap { $0 + 1 < CommandLine.arguments.count ? CommandLine.arguments[$0 + 1] : nil } ?? "json"
    if let sample = PoCD.measureMemory(languageName: name, megabytes: intOption("--mb", default: 8)) {
        try emit(sample)
    } else {
        FileHandle.standardError.write(Data("không đo được \(name)\n".utf8))
        exit(1)
    }

case "poc-c":
    FileHandle.standardError.write(Data("▸ PoC-C — PCRE2 + JIT (SAD §8, ADR-03)\n".utf8))
    try emit(PoCC.run(
        megabytes: intOption("--mb", default: 100),
        // Ngân sách cho MỘT lần khớp. Chọn 100 ms: tìm kiếm chạy ngoài main thread, nhưng
        // nút Hủy phải đáp ứng ≤ 200 ms (NFR-PERF-06), nên một lần khớp không được chiếm
        // quá nửa khoảng đó.
        budgetMs: Double(intOption("--budget-ms", default: 100))
    ))

case "search":
    FileHandle.standardError.write(Data("▸ KPI tìm kiếm — NFR-PERF-06 và NFR-PERF-08 (STP §4.1)\n".utf8))
    try emit(SearchKPI.run(
        megabytes: intOption("--mb", default: 100),
        treeFiles: intOption("--files", default: 10_000),
        kilobytesPerFile: intOption("--kb", default: 10)
    ))

case "ops":
    FileHandle.standardError.write(Data("▸ KPI thao tác tài liệu — TC-CORE-08 và TC-CSV-03 (STP §4.1)\n".utf8))
    try emit(DocumentKPI.run(
        lines: intOption("--lines", default: 1_000_000),
        rows: intOption("--rows", default: 1_000_000)
    ))

case "clean":
    FileHandle.standardError.write(Data("▸ KPI làm sạch — NFR-CLN-01 (Data Profile) và FR-CLN-006\n".utf8))
    try emit(CleanKPI.run(
        rows: intOption("--rows", default: 1_000_000),
        columns: intOption("--columns", default: 20)
    ))

case "poc-g":
    FileHandle.standardError.write(
        Data("▸ PoC-G — tập con SQL trên CSVEngine (FR-CSV-407)\n".utf8))
    try emit(PoCG.run(
        rows: intOption("--rows", default: 1_000_000),
        columns: intOption("--columns", default: 20)
    ))

case "poc-k":
    FileHandle.standardError.write(
        Data("▸ PoC-K — DuckDB ở phạm vi rộng hơn FR-CSV-407\n".utf8))
    guard let out = stringOption("--out") else {
        FileHandle.standardError.write(Data("Cần --out <thư mục ghi fixture>\n".utf8))
        exit(2)
    }
    try emit(PoCK.run(
        rows: intOption("--rows", default: 1_000_000),
        columns: intOption("--columns", default: 20),
        outDirectory: out
    ))

case "poc-m":
    FileHandle.standardError.write(
        Data("▸ PoC-M — BM25 Retrieval Lab (FR-KNW-918, NFR-KNW-04)\n".utf8))
    BM25KPI.run(arguments: CommandLine.arguments)

case "graph":
    GraphKPI.run(arguments: CommandLine.arguments)

case "jsonl":
    JSONLKPI.run(arguments: CommandLine.arguments)

case "quality":
    FileHandle.standardError.write(
        Data("▸ KPI chất lượng dữ liệu — NFR-DQR-01 (FR-DQR-001)\n".utf8))
    try emit(QualityKPI.run(
        rows: intOption("--rows", default: 1_000_000),
        columns: intOption("--columns", default: 20)
    ))

case "chart":
    FileHandle.standardError.write(
        Data("▸ KPI biểu đồ — NFR-QRY-02 (FR-QRY-004)\n".utf8))
    try emit(ChartKPI.run(points: intOption("--points", default: 1_000_000)))

case "csv-table":
    FileHandle.standardError.write(Data("▸ KPI Table view CSV — FR-CSV-403\n".utf8))
    try emit(CSVTableKPI.run(
        rows: intOption("--rows", default: 1_000_000),
        samples: intOption("--samples", default: 2_000)
    ))

case "document-map":
    FileHandle.standardError.write(Data("▸ KPI bản đồ tài liệu — FR-DOC-306\n".utf8))
    guard let path = stringOption("--file") else {
        FileHandle.standardError.write(Data("Cần --file <đường dẫn>\n".utf8))
        exit(2)
    }
    try emit(DocumentMapKPI.run(path: path, rowCounts: [200, 600, 1200]))

case "mining":
    FileHandle.standardError.write(
        Data("▸ KPI khai phá dữ liệu — NFR-MIN-01 · NFR-MIN-05 · NFR-DQR-03\n".utf8))
    try emit(MiningKPI.run(
        rows: intOption("--rows", default: 1_000_000),
        columns: intOption("--columns", default: 20),
        groups: intOption("--groups", default: 1_000),
        baskets: intOption("--baskets", default: 1_000_000)
    ))

case "report":
    FileHandle.standardError.write(
        Data("▸ KPI báo cáo — NFR-RPT-01\n".utf8))
    try emit(ReportKPI.run(rows: intOption("--rows", default: 1_000_000)))

case "hybrid":
    FileHandle.standardError.write(Data("▸ KPI truy hồi hybrid — NFR-KNW-05\n".utf8))
    try emit(HybridKPI.run(
        chunks: intOption("--chunks", default: 20_000),
        nodes: intOption("--nodes", default: 2_000),
        queries: intOption("--queries", default: 20)
    ))

case "core":
    try emit(CoreKPI.run())

default:
    FileHandle.standardError.write(Data("Chế độ không hợp lệ: \(mode). Dùng `core` hoặc `poc-b`.\n".utf8))
    exit(2)
}
