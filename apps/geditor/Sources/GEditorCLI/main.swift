import Foundation
import GEditorCore

// CLI `geditor` (FR-AUTO-605).
//
// LƯU Ý THƯƠNG HIỆU: tên lệnh là "geditor", KHÔNG phải "gedit" — trùng trình soạn thảo
// của GNOME, rủi ro nhầm lẫn và tranh chấp tên.
//
// Nối với ứng dụng qua Unix domain socket (SAD §2.4 CLIBridge) — xem `CLIBridge` trong lõi
// về lý do chọn socket thay vì XPC.

struct Invocation {
    struct Target {
        var path: String
        var line: Int?
        var column: Int?
    }

    var targets: [Target] = []
    var wait = false
    var newWindow = false
    var readOnly = false
    var readStdin = false
    var showHelp = false
    var showVersion = false
    var showInfo = false

    // --- Công thức làm sạch (FR-CLN-005) ---
    var recipePath: String?
    /// Ghi đè chính file gốc thay vì ghi ra bản mới cạnh nó. Phải nói ra tường minh.
    var overwrite = false
    var outputDirectory: String?
    /// Chỉ in ra sẽ làm gì, không ghi file nào.
    var dryRun = false

    // --- Truy vấn từ dòng lệnh (FR-QRY-006) ---
    var queryPath: String?
    /// `--report bao_cao.greport.md` — FR-RPT-004.
    var reportPath: String?
    /// `--param thang=2026-08`, lặp được.
    var parameters: [String: String] = [:]
    /// `--param-list tinh.csv` — mỗi hàng một báo cáo (FR-RPT-006 · FR-DQR-003).
    var parameterListPath: String?
    /// `--name "bao-cao-{tinh}.html"` — mẫu đặt tên tệp đầu ra của lượt batch.
    var outputNameTemplate: String?
    var exportFormat: QueryExport.Format?
    /// `--out` dùng chung với `--recipe`. Một file khi có ĐÚNG một đầu vào; là thư mục khi
    /// chạy batch — nếu không thì file thứ hai ghi đè kết quả của file thứ nhất trong im lặng.
    var outputPath: String? { outputDirectory }

    // --- Cổng chất lượng (FR-DQR-005) ---
    var qualityRulesPath: String?
    /// `--fail-under 90`.
    var failUnder: Double?
    /// `--json ket-qua.json`; `-` là ra thẳng màn hình.
    var jsonPath: String?
    /// `--record-history` — nối một dòng vào `.gquality.history.jsonl` (FR-DQR-004).
    var recordHistory = false
    /// `--now 2026-08-26` — đóng đinh mốc của chiều TIMELINESS để hai lần chạy cùng điểm.
    var now: Date?
}

/// `--info` — mở file bằng lõi và in ra những gì nó nhận biết được.
///
/// Không cần ứng dụng và không cần XPC, nên đây là đường DUY NHẤT hiện có để kiểm chứng lõi
/// trên dữ liệu thật của người dùng: nhận diện bảng mã có đúng file TCVN3 của họ không, file
/// có trộn EOL không, Large File Mode có bật không. Với một sản phẩm mà đoán sai bảng mã là
/// hỏng dữ liệu, khả năng kiểm tra trước khi mở là thứ đáng có sớm.
func printInfo(_ path: String) -> Int32 {
    let document: Document
    do {
        document = try Document.open(path: path)
    } catch {
        FileHandle.standardError.write(Data("geditor: không mở được \(path): \(error)\n".utf8))
        return 66  // EX_NOINPUT
    }

    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0

    print("\(path)")
    print("  kích thước    \(size) byte\(document.isLargeFileMode ? "  (Large File Mode)" : "")")
    print("  bảng mã       \(document.encoding.displayName)", terminator: "")
    if let best = document.detection.first {
        print("  (\(Int((best.confidence * 100).rounded()))% — \(best.reason))")
    } else {
        print("")
    }
    for guess in document.detection.dropFirst().prefix(3) {
        print("                cũng có thể: \(guess.encoding.displayName) "
            + "(\(Int((guess.confidence * 100).rounded()))%)")
    }

    let eol = document.eol.map(\.rawValue) ?? "không có dòng nào kết thúc"
    print("  xuống dòng    \(eol)\(document.hasMixedEOL ? "  ⚠️  TRỘN NHIỀU KIỂU" : "")")
    print("  số dòng       \(document.buffer.lineCount)")
    print("  quyền         \(document.isReadOnly ? "chỉ đọc" : "đọc ghi")")
    return 0
}

/// Phân tích "duong/dan/file.txt:120:5" → (path, line, column).
func parseTarget(_ argument: String) -> Invocation.Target {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count >= 2 else { return Invocation.Target(path: argument, line: nil, column: nil) }

    // Chỉ coi là dòng/cột khi thực sự là số — tên file chứa ":" vẫn phải mở được.
    if parts.count >= 3, let line = Int(parts[parts.count - 2]), let column = Int(parts[parts.count - 1]) {
        return Invocation.Target(
            path: parts[0 ..< (parts.count - 2)].joined(separator: ":"),
            line: line,
            column: column
        )
    }
    if let line = Int(parts[parts.count - 1]) {
        return Invocation.Target(
            path: parts[0 ..< (parts.count - 1)].joined(separator: ":"),
            line: line,
            column: nil
        )
    }
    return Invocation.Target(path: argument, line: nil, column: nil)
}

func parseArguments(_ arguments: [String]) -> Invocation {
    var invocation = Invocation()
    var pendingValue: ((String) -> Void)?

    for argument in arguments {
        if let take = pendingValue {
            take(argument)
            pendingValue = nil
            continue
        }
        switch argument {
        case "--recipe": pendingValue = { invocation.recipePath = $0 }
        case "--out": pendingValue = { invocation.outputDirectory = $0 }
        case "--overwrite": invocation.overwrite = true
        case "--dry-run": invocation.dryRun = true
        case "--query": pendingValue = { invocation.queryPath = $0 }
        case "--report": pendingValue = { invocation.reportPath = $0 }
        case "--format": pendingValue = { value in
            guard let format = QueryExport.Format(argument: value) else {
                FileHandle.standardError.write(
                    Data("geditor: --format không nhận «\(value)» — dùng csv, json hoặc md\n".utf8))
                exit(64)
            }
            invocation.exportFormat = format
        }
        case "--param": pendingValue = { value in
            // `thang=2026-08`. Tách ở dấu `=` ĐẦU TIÊN: giá trị hoàn toàn có thể chứa dấu `=`
            // (một biểu thức, một chuỗi base64), và tách ở dấu cuối sẽ cắt mất phần đầu.
            guard let separator = value.firstIndex(of: "=") else {
                FileHandle.standardError.write(
                    Data("geditor: --param cần dạng tên=giá_trị, nhận «\(value)»\n".utf8))
                exit(64)
            }
            let name = String(value[value.startIndex ..< separator])
            invocation.parameters[name] = String(value[value.index(after: separator)...])
        }
        case "--param-list": pendingValue = { invocation.parameterListPath = $0 }
        case "--name": pendingValue = { invocation.outputNameTemplate = $0 }
        case "--quality": pendingValue = { invocation.qualityRulesPath = $0 }
        case "--fail-under": pendingValue = { value in
            guard let number = Double(value), (0...100).contains(number) else {
                FileHandle.standardError.write(Data(
                    "geditor: --fail-under cần một số trong 0…100, nhận «\(value)»\n".utf8))
                // Mã 2 chứ không 64: lệnh này là một CỔNG, và một cổng không bao giờ được thoát
                // bằng mã mà pipeline có thể hiểu nhầm là "đạt". Xem `QualityGate`.
                exit(2)
            }
            invocation.failUnder = number
        }
        case "--json": pendingValue = { invocation.jsonPath = $0 }
        case "--record-history": invocation.recordHistory = true
        case "--now": pendingValue = { value in
            guard let date = QualityCard.parseDay(value) else {
                FileHandle.standardError.write(Data(
                    "geditor: --now cần dạng YYYY-MM-DD, nhận «\(value)»\n".utf8))
                exit(2)
            }
            invocation.now = date
        }
        case "--wait", "-w": invocation.wait = true
        case "--new-window", "-n": invocation.newWindow = true
        case "--read-only", "-r": invocation.readOnly = true
        case "--help", "-h": invocation.showHelp = true
        case "--version", "-v": invocation.showVersion = true
        case "--info", "-i": invocation.showInfo = true
        case "-": invocation.readStdin = true
        default:
            if argument.hasPrefix("-") {
                FileHandle.standardError.write(Data("geditor: tham số không nhận ra: \(argument)\n".utf8))
                exit(64)  // EX_USAGE
            }
            invocation.targets.append(parseTarget(argument))
        }
    }
    return invocation
}

let usage = """
geditor — GEditor for macOS

Cách dùng:
  geditor [tùy chọn] [file[:dòng[:cột]] ...]
  <lệnh> | geditor            đọc stdin thành tab mới

Tùy chọn:
  -w, --wait          chờ tới khi đóng file rồi mới thoát
  -n, --new-window    mở trong cửa sổ mới
  -r, --read-only     mở ở chế độ chỉ đọc
  -i, --info          in nhận diện bảng mã, EOL, số dòng rồi thoát (không mở app)
  -h, --help          hiện trợ giúp này
  -v, --version       hiện phiên bản

Công thức làm sạch (FR-CLN-005) — chạy trong tiến trình này, KHÔNG mở app:
  --query <file.sql>     chạy câu truy vấn lên các file chỉ định (FR-QRY-006)
  --param tên=giá_trị    giá trị cho tham số :tên trong câu truy vấn (lặp được)
  --format csv|json|md   định dạng kết quả (mặc định: suy từ đuôi --out, hoặc csv)
  --recipe <file.json>   chạy công thức lên các file chỉ định
  --out <thư mục>        ghi kết quả vào thư mục này
  --overwrite            ghi đè chính file gốc (mặc định: ghi ra «tên-sach.csv» cạnh nó)
  --dry-run              chỉ in ra sẽ làm gì, không ghi file nào

Cổng chất lượng (FR-DQR-005) — MÃ THOÁT 0 đạt · 1 trượt · 2 lỗi chạy:
  --quality <chuan.yaml> chấm các file chỉ định theo bộ quy tắc
  --fail-under <0…100>   điểm tổng dưới ngưỡng này thì TRƯỢT
  --json <file|->        ghi kết quả máy đọc được (dùng «-» để in ra màn hình)
  --record-history       nối một dòng vào «chuan.history.jsonl» để theo dõi trôi dạt
  --now <YYYY-MM-DD>     đóng đinh mốc thời gian của chiều «tươi mới»
  --recipe <file.json>   làm sạch trong bộ nhớ TRƯỚC khi chấm (không ghi file nào)

Báo cáo (FR-RPT-004…006):
  --report <file.greport.md>  dựng báo cáo ra HTML tự chứa
  --param-list <file.csv|json>  mỗi hàng một báo cáo; cần --out <thư mục>
  --name "bao-cao-{tinh}.html"  mẫu đặt tên tệp đầu ra của lượt loạt

Ví dụ:
  geditor --quality chuan.yaml du-lieu.csv --fail-under 90
  geditor --quality chuan.yaml *.csv --json ket-qua.json --record-history
  geditor --quality chuan.yaml --recipe lam_sach.json du-lieu.csv
  geditor --report thang.greport.md --param-list tinh.csv --out bc/ du-lieu.csv
  geditor bao_cao.csv:120:5
  geditor --info du_lieu_tcvn3.csv
  geditor --query bao_cao.sql --out ket_qua.csv du_lieu.csv
  geditor --query theo_thang.sql --param thang=2026-08 --format md --out bc/ *.csv
  geditor --recipe lam_sach.json *.csv
  geditor --recipe lam_sach.json --dry-run bao_cao_thang7.csv
  ps aux | geditor
"""

var invocation = parseArguments(Array(CommandLine.arguments.dropFirst()))

if invocation.showHelp {
    print(usage)
    exit(0)
}

/// `--recipe` — chạy công thức làm sạch, không cần ứng dụng.
///
/// Chạy thẳng trong tiến trình này chứ không gửi qua socket cho app: đây là đường dùng trong
/// script và trong CI, nơi thường không có ai đăng nhập đồ họa để mà mở cửa sổ.
///
/// Mặc định KHÔNG ghi đè. Người dùng có thể quét cả một thư mục bằng một dòng lệnh, và ghi đè
/// mặc định thì một lần chạy nhầm là không lấy lại được.
/// `--query` — chạy một câu truy vấn lên file, không cần ứng dụng (FR-QRY-006).
///
/// Không đi qua cầu nối CLI như `geditor file.txt`: đây là một lệnh **hoàn toàn ngoại tuyến**,
/// dùng được trong pipeline và trong `cron`. Cùng lối `--recipe` đã đặt, và cùng lý do — thứ
/// người ta chạy hàng đêm không được phụ thuộc vào một app đang mở trên màn hình ai đó.
/// `geditor --report bao_cao.greport.md --param thang=2026-08 --out bc_t8.html` — FR-RPT-004,
/// FR-RPT-005.
///
/// ## Mã thoát nói được BA tình huống, không phải hai
///
/// `0` xong sạch · `65` báo cáo đã dựng nhưng CÓ KHỐI HỎNG · `66`/`64` không dựng được.
///
/// Vế giữa là vế đáng nói. Trình kết xuất cố ý để một khối hỏng không giết cả trang, nên tệp
/// HTML vẫn ra và vẫn mở được. Nếu mã thoát cũng là 0 thì một job chạy hàng đêm sẽ báo thành
/// công trong khi ba biểu đồ trong báo cáo là hộp lỗi đỏ — và không ai biết cho tới khi có người
/// mở tệp ra đọc. Nên tệp vẫn ghi, nhưng mã thoát nói ra.
func runReport(_ invocation: Invocation) -> Int32 {
    guard let reportPath = invocation.reportPath else { return 64 }
    guard let text = try? String(contentsOfFile: reportPath, encoding: .utf8) else {
        FileHandle.standardError.write(
            Data("geditor: không đọc được báo cáo \(reportPath)\n".utf8))
        return 66  // EX_NOINPUT
    }

    let document: ReportDocument
    do {
        document = try ReportDocument.parse(text)
    } catch let failure as ReportDocument.Failure {
        FileHandle.standardError.write(
            Data("geditor: \(reportPath) \(failure.description)\n".utf8))
        return 65  // EX_DATAERR
    } catch {
        FileHandle.standardError.write(
            Data("geditor: \(reportPath): \(error.localizedDescription)\n".utf8))
        return 65
    }

    // Nguồn dữ liệu: file CSV nêu sau lệnh, hoặc khoá `source` trong frontmatter.
    //
    // Khoá `source` giải theo đường dẫn TƯƠNG ĐỐI với chính tệp báo cáo, không với thư mục đang
    // đứng. Một báo cáo và dữ liệu của nó nằm cạnh nhau trong kho mã; chạy nó từ thư mục khác
    // mà hỏng là thứ khiến người ta bỏ luôn cách viết đường dẫn tương đối.
    var sourcePath = invocation.targets.first?.path
    if sourcePath == nil, let declared = document.frontmatter?["source"]?.stringValue {
        sourcePath = (declared as NSString).isAbsolutePath
            ? declared
            : ((reportPath as NSString).deletingLastPathComponent as NSString)
                .appendingPathComponent(declared)
    }
    // Không phải báo cáo nào cũng cần một BẢNG.
    //
    // Khối ```mermaid vẽ từ chính nội dung của nó, và khối ```quality ở chế độ chunk
    // (FR-KNW-922) đọc corpus JSONL khai ngay trong khối. Một báo cáo chỉ gồm những khối ấy mà
    // vẫn bị đòi một tệp CSV thì người dùng phải dựng ra một tệp giả để làm vui lòng cờ lệnh —
    // và tệp giả ấy sẽ tồn tại mãi trong kho mã.
    let needsTable = document.blocks.contains { block in
        switch block.kind {
        case .query, .chart, .mining: return true
        // Khối ```retrieval khai corpus và bộ đánh giá NGAY TRONG khối (FR-KNW-919).
        case .mermaid, .retrieval: return false
        case .quality:
            // Chế độ chunk khai `corpus:`; chế độ bảng thì không. Khối SAI CÚ PHÁP tính là cần
            // bảng — nó sẽ báo lỗi cú pháp lúc dựng, và đó là chỗ báo lỗi đúng.
            // Chế độ chunk (`corpus:`) và chế độ đồ thị (`graph:`) khai nguồn NGAY trong khối.
            let spec = try? QualityBlockSpec.parse(block.content)
            guard let spec else { return true }
            return spec.corpus.isEmpty && spec.graph.isEmpty
        }
    }
    if sourcePath == nil, needsTable {
        FileHandle.standardError.write(Data((
            "geditor: --report cần một file dữ liệu — nêu sau lệnh, hoặc khai «source:» "
                + "trong frontmatter\n").utf8))
        return 64  // EX_USAGE
    }
    var bytes = Data()
    if let sourcePath {
        guard let read = FileManager.default.contents(atPath: sourcePath) else {
            FileHandle.standardError.write(
                Data("geditor: không đọc được dữ liệu \(sourcePath)\n".utf8))
            return 66
        }
        bytes = read
    }

    // Tham số: mặc định trong frontmatter, rồi `--param` đè lên. Thiếu thì báo NGAY, trước khi
    // chạy truy vấn nào — cùng lý do với `--query`: một job lặng lẽ xuất ra báo cáo rỗng vì
    // quên một cờ là thứ không ai phát hiện cho tới cuối tháng.
    let declared: [ReportParameter]
    do {
        declared = try ReportParameters.declared(in: document.frontmatter)
    } catch let failure as ReportParameters.Failure {
        FileHandle.standardError.write(Data("geditor: \(failure.message)\n".utf8))
        return 65
    } catch {
        return 65
    }
    // --- Chạy LOẠT theo danh sách tham số (FR-RPT-006 · FR-DQR-003) ----------------------
    if let listPath = invocation.parameterListPath {
        return runReportBatch(
            invocation, document: document, reportPath: reportPath, sourcePath: sourcePath,
            bytes: bytes, declared: declared, listPath: listPath)
    }

    let values = ReportParameters.resolve(
        declared: declared, supplied: [:], overrides: invocation.parameters)
    let missing = ReportParameters.missing(in: document, values: values)
    if !missing.isEmpty {
        FileHandle.standardError.write(Data(
            "geditor: thiếu tham số \(missing.map { "--param " + $0 + "=…" }.joined(separator: ", "))\n"
                .utf8))
        return 64
    }

    let buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
    let rendered: ReportRenderer.Rendered
    do {
        rendered = try ReportRenderer.render(
            document, in: buffer, dialect: .comma,
            options: ReportRenderer.Options(
                values: values, sourcePath: sourcePath,
                basePath: (reportPath as NSString).deletingLastPathComponent,
                recordQualityHistory: invocation.recordHistory))
    } catch {
        FileHandle.standardError.write(
            Data("geditor: không dựng được báo cáo: \(error)\n".utf8))
        return 70  // EX_SOFTWARE
    }
    for alert in rendered.qualityAlerts {
        FileHandle.standardError.write(Data(
            "geditor: \(reportPath) dòng \(alert.line + 1): \(alert.message)\n".utf8))
    }

    if let out = invocation.outputPath {
        // KHÔNG cho ghi đè chính tệp báo cáo hay tệp dữ liệu. Đây là bài học đã trả giá một lần
        // trong dự án: bản CLI truy vấn từng ghi kết quả đè lên chính file nguồn.
        for guarded in [reportPath, sourcePath].compactMap({ $0 })
        where QueryExport.wouldOverwriteSource(output: out, source: guarded) {
            FileHandle.standardError.write(Data((
                "geditor: --out trỏ vào chính \((guarded as NSString).lastPathComponent) — "
                    + "từ chối ghi đè\n").utf8))
            return 73  // EX_CANTCREAT
        }
        do {
            try rendered.html.write(toFile: out, atomically: true, encoding: .utf8)
        } catch {
            FileHandle.standardError.write(
                Data("geditor: không ghi được \(out): \(error.localizedDescription)\n".utf8))
            return 73
        }
    } else {
        FileHandle.standardOutput.write(Data(rendered.html.utf8))
    }

    for failure in rendered.failures {
        FileHandle.standardError.write(Data(
            "geditor: \(reportPath) dòng \(failure.line + 1): \(failure.message)\n".utf8))
    }
    return rendered.hasFailures ? 65 : 0
}

/// `--report … --param-list tinh.csv --out bc/` — FR-RPT-006, và vế batch của FR-DQR-003.
///
/// ## `--out` ở đây BẮT BUỘC là thư mục
///
/// Sáu mươi ba báo cáo không có chỗ nào để đi nếu đầu ra là một tệp — hoặc tệ hơn, chúng lần
/// lượt đè lên nhau và người chạy chỉ nhận được cái cuối cùng, im lặng. In cả loạt ra màn hình
/// cũng vô nghĩa. Nên thiếu `--out` là lỗi dùng lệnh, nói ngay chứ không đoán.
func runReportBatch(
    _ invocation: Invocation, document: ReportDocument, reportPath: String,
    sourcePath: String?, bytes: Data, declared: [ReportParameter], listPath: String
) -> Int32 {
    guard let folder = invocation.outputDirectory else {
        FileHandle.standardError.write(Data((
            "geditor: --param-list cần --out <thư mục> — mỗi bộ tham số một tệp\n").utf8))
        return 64
    }
    let sets: [ReportBatch.ParameterSet]
    do {
        sets = try ReportBatch.parameterSets(fromFile: listPath)
    } catch let failure as ReportBatch.Failure {
        FileHandle.standardError.write(Data("geditor: \(failure.message)\n".utf8))
        return 65
    } catch {
        FileHandle.standardError.write(Data("geditor: \(listPath): \(error)\n".utf8))
        return 65
    }
    do {
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    } catch {
        FileHandle.standardError.write(Data(
            "geditor: không tạo được thư mục \(folder): \(error.localizedDescription)\n".utf8))
        return 73
    }

    // Cache dùng CHUNG cả loạt: 63 tỉnh chấm cùng một bộ luật trên cùng một tệp nguồn thì khối
    // ```quality của chúng cho ra đúng một kết quả — chấm 63 lần là trả 63 lần cho một câu trả
    // lời. (Khối ```query thì vẫn chạy lại: câu của nó ĐỔI theo tham số.)
    let cache = QualityCache()
    var outcome = ReportBatch.Outcome()
    for (index, set) in sets.enumerated() {
        let values = ReportParameters.resolve(
            declared: declared, supplied: set.values, overrides: invocation.parameters)
        let missing = ReportParameters.missing(in: document, values: values)
        guard missing.isEmpty else {
            outcome.entries.append(.init(
                label: set.label, path: nil, failed: true,
                message: "thiếu tham số " + missing.map { ":\($0)" }.joined(separator: ", ")))
            continue
        }
        let name = ReportBatch.outputName(
            template: invocation.outputNameTemplate, set: set, reportPath: reportPath)
        let destination = (folder as NSString).appendingPathComponent(name)
        // Cùng hàng rào của lượt chạy đơn: không bao giờ ghi đè tệp báo cáo hay tệp dữ liệu.
        if [reportPath, sourcePath].compactMap({ $0 }).contains(where: {
            QueryExport.wouldOverwriteSource(output: destination, source: $0)
        }) {
            outcome.entries.append(.init(
                label: set.label, path: destination, failed: true,
                message: "trỏ vào chính tệp nguồn — từ chối ghi đè"))
            continue
        }
        if FileManager.default.fileExists(atPath: destination), !invocation.overwrite {
            outcome.entries.append(.init(
                label: set.label, path: destination, failed: true,
                message: "đã có — dùng --overwrite nếu thật sự muốn đè"))
            continue
        }
        if invocation.dryRun {
            outcome.entries.append(.init(
                label: set.label, path: destination, failed: false, message: "(chạy thử)"))
            continue
        }

        // Buffer DỰNG LẠI cho mỗi bộ: trình kết xuất có thể ghi ra tệp tạm khi truy vấn trên
        // buffer, và dùng chung một buffer qua 63 lượt là mở đường cho lượt sau đọc trạng thái
        // của lượt trước.
        let buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
        do {
            let rendered = try ReportRenderer.render(
                document, in: buffer, dialect: .comma,
                options: ReportRenderer.Options(
                    values: values, sourcePath: sourcePath,
                    basePath: (reportPath as NSString).deletingLastPathComponent,
                    qualityCache: cache,
                    recordQualityHistory: invocation.recordHistory))
            try rendered.html.write(toFile: destination, atomically: true, encoding: .utf8)
            // Khối hỏng KHÔNG làm mất tệp, nhưng phải tính là HỎNG: một loạt 63 tệp mà mỗi tệp
            // có một hộp lỗi đỏ vẫn là 63 tệp ghi thành công, và mã thoát 0 sẽ nói dối.
            outcome.entries.append(.init(
                label: set.label, path: destination, failed: rendered.hasFailures,
                message: rendered.hasFailures
                    ? "\(rendered.failures.count) khối HỎNG: "
                        + (rendered.failures.first?.message ?? "")
                    : (rendered.qualityAlerts.first?.message ?? "")))
        } catch {
            outcome.entries.append(.init(
                label: set.label, path: destination, failed: true,
                message: "\(error)"))
        }
        FileHandle.standardError.write(Data(
            "[\(index + 1)/\(sets.count)] \(name)\n".utf8))
    }

    print(outcome.report)
    return outcome.failedCount > 0 ? 65 : 0
}

func runQuery(_ invocation: Invocation) -> Int32 {
    guard let queryPath = invocation.queryPath else { return 64 }
    guard let sql = try? String(contentsOfFile: queryPath, encoding: .utf8) else {
        FileHandle.standardError.write(
            Data("geditor: không đọc được câu truy vấn \(queryPath)\n".utf8))
        return 66  // EX_NOINPUT
    }

    // Tham số thiếu là lỗi CỦA LỆNH, không phải kết quả rỗng. Một job chạy hàng đêm mà lặng lẽ
    // xuất ra file rỗng vì quên một cờ là thứ không ai phát hiện cho tới cuối tháng.
    let missing = QueryParameters.missing(in: sql, values: invocation.parameters)
    if !missing.isEmpty {
        FileHandle.standardError.write(Data(
            "geditor: thiếu tham số \(missing.map { "--param " + $0 + "=…" }.joined(separator: ", "))\n"
                .utf8))
        return 64  // EX_USAGE
    }
    let resolved = QueryParameters.substitute(sql, values: invocation.parameters)

    var files: [String] = []
    for target in invocation.targets {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            files.append(contentsOf: CSVRecipeBatch.csvFiles(in: target.path))
        } else {
            files.append(target.path)
        }
    }
    guard !files.isEmpty else {
        FileHandle.standardError.write(Data("geditor: --query cần ít nhất một file\n".utf8))
        return 64
    }

    // Định dạng: cờ tường minh thắng; nếu không thì suy từ đuôi `--out`; cuối cùng là CSV.
    let format = invocation.exportFormat
        ?? invocation.outputPath.flatMap {
            QueryExport.Format(argument: ($0 as NSString).pathExtension)
        }
        ?? .csv

    // `--out` là THƯ MỤC khi có nhiều đầu vào, hoặc khi nó đã tồn tại và là một thư mục.
    //
    // Vế thứ hai không phải chi tiết vụn: `--out bao_cao/ mot_file.csv` là cách người ta gõ, và
    // hiểu nó thành "ghi vào một FILE tên là bao_cao" cho ra một lỗi Cocoa thô ("Is a
    // directory") mà người dùng không nối được với thứ họ vừa gõ.
    var outIsDirectory: ObjCBool = false
    if let out = invocation.outputPath {
        _ = FileManager.default.fileExists(atPath: out, isDirectory: &outIsDirectory)
    }
    let batch = files.count > 1 || outIsDirectory.boolValue
    var failures = 0
    for (index, file) in files.enumerated() {
        guard let bytes = FileManager.default.contents(atPath: file) else {
            FileHandle.standardError.write(Data("geditor: không đọc được \(file)\n".utf8))
            failures += 1
            continue
        }
        let buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
        do {
            let result = try CSVQueryEngine.run(
                resolved, in: buffer, dialect: .comma, sourcePath: file)
            let text = QueryExport.text(result, format: format)
            guard let out = invocation.outputPath else {
                print(text, terminator: "")
                continue
            }
            // MỘT file vào → `--out` là tên file. NHIỀU file vào → `--out` là thư mục, và mỗi
            // đầu vào một đầu ra. Ghi tất cả vào một tên là để file thứ hai đè kết quả của file
            // thứ nhất trong im lặng.
            let destination: String
            if batch {
                try? FileManager.default.createDirectory(
                    atPath: out, withIntermediateDirectories: true)
                let stem = ((file as NSString).lastPathComponent as NSString)
                    .deletingPathExtension
                destination = (out as NSString)
                    .appendingPathComponent(stem + "." + format.fileExtension)
            } else {
                destination = out
            }
            // NFR-QRY-03 — chặn TRƯỚC cả `--overwrite`. Xem `wouldOverwriteSource`.
            if QueryExport.wouldOverwriteSource(output: destination, source: file) {
                let message = "geditor: \(destination) CHÍNH LÀ file nguồn — truy vấn không "
                    + "bao giờ ghi đè dữ liệu gốc (NFR-QRY-03). Chọn --out khác.\n"
                FileHandle.standardError.write(Data(message.utf8))
                failures += 1
                continue
            }
            if FileManager.default.fileExists(atPath: destination), !invocation.overwrite {
                FileHandle.standardError.write(Data(
                    "geditor: \(destination) đã có — dùng --overwrite nếu thật sự muốn đè\n".utf8))
                failures += 1
                continue
            }
            if invocation.dryRun {
                print("\(file) → \(destination) (\(result.rows.count) hàng)")
                continue
            }
            try Data(text.utf8).write(to: URL(fileURLWithPath: destination), options: .atomic)
            let progress = "[\(index + 1)/\(files.count)] "
                + "\((file as NSString).lastPathComponent) → "
                + "\((destination as NSString).lastPathComponent) "
                + "(\(result.rows.count) hàng)\n"
            FileHandle.standardError.write(Data(progress.utf8))
        } catch let failure as CSVQueryEngine.Failure {
            FileHandle.standardError.write(
                Data("geditor: \((file as NSString).lastPathComponent): \(failure.message)\n".utf8))
            failures += 1
        } catch {
            FileHandle.standardError.write(Data("geditor: \(file): \(error)\n".utf8))
            failures += 1
        }
    }
    // Mã thoát khác 0 khi có file lỗi: pipeline gọi lệnh này phải biết mà dừng.
    return failures > 0 ? 1 : 0
}

/// `geditor --quality chuan.yaml du-lieu.csv --fail-under 90 --json ra.json` — FR-DQR-005.
///
/// ## Vì sao hàm này KHÔNG dùng mã thoát 64/65/66 như phần còn lại của lệnh
///
/// Xem ghi chú đầu `QualityGate`: đặc tả đòi đúng ba mã 0/1/2 vì đó là quy ước của công cụ kiểm
/// trong CI. Mọi đường thoát của hàm này đều phải nằm trong ba mã ấy — kể cả lỗi cú pháp dòng
/// lệnh, vì một cổng thoát bằng mã lạ là một cổng mà `set -e` của người dùng xử lý sai.
func runQualityGate(_ invocation: Invocation) -> Int32 {
    guard let rulesPath = invocation.qualityRulesPath else { return 2 }
    guard let text = try? String(contentsOfFile: rulesPath, encoding: .utf8) else {
        FileHandle.standardError.write(
            Data("geditor: không đọc được bộ quy tắc \(rulesPath)\n".utf8))
        return 2
    }
    let rules: QualityRules
    do {
        rules = try QualityRules.load(fromYAML: text)
    } catch let failure as QualityRules.Failure {
        FileHandle.standardError.write(Data("geditor: \(rulesPath): \(failure.message)\n".utf8))
        return 2
    } catch {
        FileHandle.standardError.write(Data("geditor: \(rulesPath): \(error)\n".utf8))
        return 2
    }

    var files: [String] = []
    for target in invocation.targets {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            files.append(contentsOf: CSVRecipeBatch.csvFiles(in: target.path))
        } else {
            files.append(target.path)
        }
    }
    guard !files.isEmpty else {
        FileHandle.standardError.write(Data("geditor: --quality cần ít nhất một file\n".utf8))
        return 2
    }

    // `--recipe` đi cùng: làm sạch TRONG BỘ NHỚ rồi chấm lại — *"kết hợp --recipe: làm sạch
    // xong tự chấm lại"*. KHÔNG ghi file nào: lệnh này là một cổng để đọc, và một cổng sửa dữ
    // liệu của người ta là thứ không ai muốn tìm thấy trong `.gitlab-ci.yml`. Muốn ghi thì chạy
    // `--recipe` riêng.
    var prepare: ((TextBuffer, String) throws -> Bool)?
    if let recipePath = invocation.recipePath {
        let recipe: CSVRecipe
        do {
            recipe = try CSVRecipe.load(from: try Data(contentsOf: URL(fileURLWithPath: recipePath)))
        } catch let error as CSVRecipe.LoadError {
            FileHandle.standardError.write(Data("geditor: \(error.message)\n".utf8))
            return 2
        } catch {
            FileHandle.standardError.write(
                Data("geditor: không đọc được công thức \(recipePath): \(error)\n".utf8))
            return 2
        }
        prepare = { buffer, path in
            let run = try CSVRecipeRunner.run(
                recipe, on: buffer, dialect: .comma,
                fileName: (path as NSString).lastPathComponent)
            return run.appliedCount > 0
        }
    }

    let options = QualityGate.Options(
        failUnder: invocation.failUnder,
        // Hàng ví dụ tốn một lượt quét cho mỗi luật trượt, nên chỉ lấy khi có người hỏi tới.
        violationSamples: invocation.jsonPath == nil ? 0 : 5,
        now: invocation.now,
        recordHistory: invocation.recordHistory)
    let outcome = QualityGate.run(
        rules: rules, rulesPath: rulesPath, files: files, dialect: .comma,
        options: options, prepare: prepare)

    if let jsonPath = invocation.jsonPath {
        let json = QualityGate.json(outcome, options: options)
        if jsonPath == "-" {
            FileHandle.standardOutput.write(Data(json.utf8))
        } else {
            do {
                try Data(json.utf8).write(to: URL(fileURLWithPath: jsonPath), options: .atomic)
            } catch {
                FileHandle.standardError.write(Data(
                    "geditor: không ghi được \(jsonPath): \(error.localizedDescription)\n".utf8))
                return 2
            }
        }
    }
    // Báo cho người đọc ra stderr khi JSON đang chiếm stdout — nếu không thì `--json -` trộn
    // hai thứ vào một dòng ống và `jq` nghẹn ngay ký tự đầu.
    let report = Data(QualityGate.text(outcome, options: options).utf8)
    if invocation.jsonPath == "-" {
        FileHandle.standardError.write(report)
    } else {
        FileHandle.standardOutput.write(report)
    }
    return outcome.exitCode
}

func runRecipe(_ invocation: Invocation) -> Int32 {
    guard let recipePath = invocation.recipePath else { return 64 }

    let recipe: CSVRecipe
    do {
        recipe = try CSVRecipe.load(from: try Data(contentsOf: URL(fileURLWithPath: recipePath)))
    } catch let error as CSVRecipe.LoadError {
        FileHandle.standardError.write(Data("geditor: \(error.message)\n".utf8))
        return 65  // EX_DATAERR
    } catch {
        FileHandle.standardError.write(
            Data("geditor: không đọc được công thức \(recipePath): \(error)\n".utf8)
        )
        return 66  // EX_NOINPUT
    }

    // Đối số là thư mục thì lấy các file CSV NGAY TRONG nó, không đệ quy.
    var files: [String] = []
    for target in invocation.targets {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            files.append(contentsOf: CSVRecipeBatch.csvFiles(in: target.path))
        } else {
            files.append(target.path)
        }
    }
    guard !files.isEmpty else {
        FileHandle.standardError.write(Data("geditor: --recipe cần ít nhất một file\n".utf8))
        return 64  // EX_USAGE
    }

    let destination: CSVRecipeBatch.Destination
    if let folder = invocation.outputDirectory {
        destination = .directory(folder)
    } else if invocation.overwrite {
        destination = .inPlace
    } else {
        destination = .default
    }

    if invocation.dryRun {
        // Nói ra sẽ làm gì, TỪNG file một. Một lệnh sắp sửa hai trăm file của người khác thì
        // xem trước không phải là tiện nghi, nó là điều tối thiểu.
        print("Chạy thử công thức «\(recipe.name)» — \(recipe.enabledCount)/\(recipe.steps.count) bước bật")
        for file in files {
            print("  \(file)")
            print("    → \(CSVRecipeBatch.outputPath(for: file, destination: destination))")
        }
        print("Chưa ghi file nào. Bỏ --dry-run để chạy thật.")
        return 0
    }

    let result = CSVRecipeBatch.run(recipe, files: files, destination: destination) { index, path in
        FileHandle.standardError.write(
            Data("[\(index + 1)/\(files.count)] \((path as NSString).lastPathComponent)\n".utf8)
        )
        return true
    }

    print(result.report)
    // Mã thoát khác 0 khi có file lỗi: script gọi lệnh này phải biết mà dừng.
    return result.failedCount > 0 ? 1 : 0
}

// Cổng chất lượng đứng TRƯỚC `--recipe`: khi có cả hai, `--recipe` là bước chuẩn bị của cổng
// chứ không phải một lệnh riêng.
if invocation.qualityRulesPath != nil {
    exit(runQualityGate(invocation))
}

if invocation.reportPath != nil {
    exit(runReport(invocation))
}
if invocation.queryPath != nil {
    exit(runQuery(invocation))
}

if invocation.recipePath != nil {
    exit(runRecipe(invocation))
}

if invocation.showVersion {
    print(GEditorCore.diagnosticSummary)
    exit(0)
}

if invocation.showInfo {
    guard !invocation.targets.isEmpty else {
        FileHandle.standardError.write(Data("geditor: --info cần ít nhất một file\n".utf8))
        exit(64)
    }
    var status: Int32 = 0
    for target in invocation.targets where printInfo(target.path) != 0 { status = 66 }
    exit(status)
}

// Không có file và stdin là pipe → nhận nội dung từ stdin thành tab untitled.
let stdinIsPipe = isatty(FileHandle.standardInput.fileDescriptor) == 0
if invocation.targets.isEmpty && !stdinIsPipe && !invocation.readStdin {
    print(usage)
    exit(0)
}

/// Rót stdin ra file tạm và trả về đường dẫn.
///
/// Rót theo khối chứ không `readDataToEndOfFile`: `dd | geditor` cả GB thì đọc hết vào RAM là
/// hỏng đúng cái mà sản phẩm này sinh ra để làm được.
///
/// Dùng read/write POSIX với MỘT bộ đệm dùng lại, không dùng `FileHandle`. Bản đầu tiên dùng
/// `FileHandle.read(upToCount:)` và đo ra 160 MB RSS cho luồng 146 MB — `Data` trả về được
/// autorelease, mà vòng lặp không có pool nào để xả, nên "rót theo khối" chỉ đúng trên giấy.
/// Bộ đệm cố định thì lượng RAM là hằng số nhìn thấy được ngay trong mã.
///
/// Quyền 0600 vì nội dung qua ống dẫn hay là thứ nhạy cảm (`pass show`, log có token). Ứng
/// dụng xóa file ngay sau khi mmap, nên nó không nằm lại trên đĩa.
func spillStandardInput() -> String? {
    let path = NSTemporaryDirectory() + "geditor-stdin-\(getpid())-\(UInt32.random(in: 0 ..< .max))"
    let out = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
    guard out >= 0 else { return nil }
    defer { close(out) }

    var buffer = [UInt8](repeating: 0, count: 1 << 20)
    while true {
        let got = buffer.withUnsafeMutableBytes { read(0, $0.baseAddress, $0.count) }
        if got == 0 { break }
        if got < 0 {
            if errno == EINTR { continue }
            unlink(path)
            return nil
        }
        var written = 0
        while written < got {
            let n = buffer.withUnsafeBytes {
                write(out, $0.baseAddress!.advanced(by: written), got - written)
            }
            if n <= 0 {
                if n < 0 && errno == EINTR { continue }
                unlink(path)
                return nil
            }
            written += n
        }
    }
    return path
}

var pipedPath: String?
if invocation.targets.isEmpty && (stdinIsPipe || invocation.readStdin) {
    guard let path = spillStandardInput() else {
        FileHandle.standardError.write(Data("geditor: không ghi được nội dung stdin ra file tạm\n".utf8))
        exit(73)  // EX_CANTCREAT
    }
    pipedPath = path

    // `-w` chờ theo ĐƯỜNG DẪN tài liệu, mà tab từ ống dẫn không có đường dẫn nào. Nói ra chứ
    // không im lặng bỏ qua — im lặng ở đây làm `cmd | geditor -w` trong script trả về ngay và
    // người viết script tưởng file đã được sửa xong.
    if invocation.wait {
        FileHandle.standardError.write(Data(
            "geditor: --wait không áp dụng cho nội dung từ ống dẫn (tab chưa có tên)\n".utf8
        ))
        invocation.wait = false
    }
}

/// Đường dẫn tuyệt đối: ứng dụng chạy ở thư mục khác, đường dẫn tương đối sẽ trỏ sai chỗ.
func absolute(_ path: String) -> String {
    (path as NSString).isAbsolutePath
        ? path
        : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path).standardized.path
}

let request = CLIBridge.OpenRequest(
    targets: invocation.targets.map {
        CLIBridge.OpenRequest.Target(path: absolute($0.path), line: $0.line, column: $0.column)
    },
    stdinPath: pipedPath,
    readOnly: invocation.readOnly,
    newWindow: invocation.newWindow,
    wait: invocation.wait
)

/// Khởi động ứng dụng rồi thử lại — người dùng gõ `geditor file.txt` khi app chưa chạy là
/// trường hợp THƯỜNG GẶP NHẤT, không phải lỗi.
func launchApplication() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", "GEditor"]
    do { try process.run() } catch { return false }
    process.waitUntilExit()
    return process.terminationStatus == 0
}

func deliver() throws -> CLIBridge.Response {
    try CLIBridgeClient.send(request, waitForClose: invocation.wait)
}

/// Chờ xong mà app đã thoát thì phải nói ra — xem `CLIBridgeClient.quitMessage`.
func report(_ response: CLIBridge.Response) {
    if let message = response.message, message == CLIBridgeClient.quitMessage {
        FileHandle.standardError.write(Data("geditor: \(message)\n".utf8))
    }
}

do {
    report(try deliver())
} catch CLIBridge.Failure.notRunning {
    guard launchApplication() else {
        FileHandle.standardError.write(Data(
            "geditor: không tìm thấy GEditor.app. Hãy chép nó vào /Applications.\n".utf8
        ))
        if let pipedPath { unlink(pipedPath) }
        exit(69)  // EX_UNAVAILABLE
    }
    // Ứng dụng cần một nhịp để dựng socket. Thử lại thay vì ngủ một khoảng đoán mò.
    var delivered = false
    for _ in 0 ..< 50 {
        usleep(100_000)
        if let response = try? deliver() { report(response); delivered = true; break }
    }
    if !delivered {
        FileHandle.standardError.write(Data("geditor: GEditor không trả lời.\n".utf8))
        if let pipedPath { unlink(pipedPath) }
        exit(69)
    }
} catch {
    FileHandle.standardError.write(Data("geditor: \(error)\n".utf8))
    if let pipedPath { unlink(pipedPath) }
    exit(70)
}
