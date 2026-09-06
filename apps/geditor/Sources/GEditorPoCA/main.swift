import AppKit
import ScintillaCocoa

// PoC-A (ADR-01) — Scintilla-Cocoa và TextKit 2 song song.
//
// Vì sao đây là một ỨNG DỤNG chứ không phải một benchmark dòng lệnh: cả hai ứng viên chỉ tiêu
// tiền khi có cửa sổ thật để vẽ vào. Đo `NSTextView` không gắn vào window là đo một view không
// bao giờ dựng bố cục, và con số sẽ đẹp một cách vô nghĩa.
//
//   geditor-poca                       mở giao diện, tự chọn thao tác (cần cho phần IME)
//   geditor-poca --auto                chạy hết các cỡ rồi in báo cáo và thoát
//   geditor-poca --auto --out F        ghi báo cáo ra file F (ghi dần sau MỖI cỡ)
//   geditor-poca --auto --sizes 1,10   chỉ chạy các cỡ này (MB)
//   geditor-poca --auto --engine scintilla|textkit|lazy|paged
//   geditor-poca --ime                 chỉ kiểm marked-text tiếng Việt rồi thoát
//                                      chỉ đo MỘT engine
//
// scripts/run-poc-a.sh chạy MỖI cặp (engine, cỡ) trong MỘT tiến trình riêng. Lý do là bộ nhớ:
// hai engine sống chung một tiến trình thì phys_footprint đo được của engine thứ hai đã trừ
// đi phần engine thứ nhất vừa trả lại, và có lần cho ra số ÂM. Tiến trình riêng còn giữ được
// kết quả khi một engine bị hệ thống giết vì hết RAM.

struct Options {
    var auto = false
    var out: String?
    var sizesMB: [Int] = [1, 10, 50, 100, 250, 500]
    var typingSamples = 300
    /// nil = cả hai.
    var onlyEngine: String?
    /// Giữ cửa sổ sau khi đo xong — để chụp màn hình kiểm chứng bằng mắt.
    var hold = false
    /// Nội dung thử thuần ASCII — CHỈ để chẩn đoán, không phải để lấy số chính thức.
    var ascii = false
    /// Chỉ chạy phần kiểm bộ gõ tiếng Việt rồi thoát.
    var imeOnly = false
}

func parseOptions() -> Options {
    var options = Options()
    var arguments = Array(CommandLine.arguments.dropFirst())
    while let argument = arguments.first {
        arguments.removeFirst()
        switch argument {
        case "--auto": options.auto = true
        case "--hold": options.hold = true
        case "--ascii": options.ascii = true
        case "--ime": options.imeOnly = true
        case "--out": options.out = arguments.isEmpty ? nil : arguments.removeFirst()
        case "--sizes":
            if !arguments.isEmpty {
                options.sizesMB = arguments.removeFirst().split(separator: ",").compactMap { Int($0) }
            }
        case "--engine":
            if !arguments.isEmpty { options.onlyEngine = arguments.removeFirst() }
        case "--samples":
            if !arguments.isEmpty { options.typingSamples = Int(arguments.removeFirst()) ?? 300 }
        default: break
        }
    }
    return options
}

final class PoCWindowController: NSWindowController {

    private let options: Options
    private let scintilla = ScintillaEngine()
    private let textKit = TextKit2Engine()
    private let lazyTextKit = LazyTextKitEngine()
    private let paged = PagedTextKitEngine()
    private let container = NSView()
    private let results = NSTextView()
    private let picker = NSSegmentedControl(
        labels: ["Scintilla", "TextKit 2", "TK2 + piece table", "TK2 cửa sổ"],
        trackingMode: .selectOne, target: nil, action: nil
    )
    private var report: [String] = []

    init(options: Options) {
        self.options = options
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_100, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "PoC-A · ADR-01 — engine hiển thị"
        window.center()
        super.init(window: window)
        buildInterface()
    }

    required init?(coder: NSCoder) { fatalError() }

    private var engines: [DisplayEngine] { [scintilla, textKit, lazyTextKit, paged] }

    private var currentEngine: DisplayEngine {
        engines[Swift.min(Swift.max(picker.selectedSegment, 0), engines.count - 1)]
    }

    private func buildInterface() {
        guard let content = window?.contentView else { return }

        picker.selectedSegment = 0
        picker.target = self
        picker.action = #selector(switchEngine)

        let runButton = NSButton(title: "Chạy đo tự động", target: self, action: #selector(runAll))
        let imeButton = NSButton(title: "Nạp 1 MB để gõ thử IME", target: self, action: #selector(prepareIME))
        let imeCheck = NSButton(title: "Kiểm bộ gõ bằng máy", target: self, action: #selector(runIMEChecks))

        let toolbar = NSStackView(views: [picker, runButton, imeCheck, imeButton])
        toolbar.orientation = .horizontal
        toolbar.spacing = 12
        toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        results.isEditable = false
        results.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let resultsScroll = NSScrollView()
        resultsScroll.documentView = results
        resultsScroll.hasVerticalScroller = true
        resultsScroll.translatesAutoresizingMaskIntoConstraints = false
        resultsScroll.heightAnchor.constraint(equalToConstant: 240).isActive = true

        container.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView(views: [toolbar, container, resultsScroll])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        showEngineView()
    }

    private func showEngineView() {
        container.subviews.forEach { $0.removeFromSuperview() }
        let view = currentEngine.view
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    @objc private func switchEngine() { showEngineView() }

    private func log(_ text: String) {
        report.append(text)
        results.string = report.joined(separator: "\n")
        results.scrollToEndOfDocument(nil)
        print(text)
        fflush(stdout)
        // Ghi dần sau MỖI cỡ: nếu engine nào ngốn hết RAM và bị hệ thống giết ở cỡ sau, phần
        // đã đo được vẫn còn. Báo cáo mất trắng vì lần đo cuối cùng thất bại là một cách phí
        // thời gian rất dễ tránh.
        if let out = options.out, let data = (text + "\n").data(using: .utf8) {
            // Ghi NỐI TIẾP: mỗi tiến trình đóng góp một mảnh vào cùng một báo cáo, và mảnh đã
            // ghi vẫn còn nếu tiến trình sau bị giết vì hết RAM.
            if let handle = FileHandle(forWritingAtPath: out) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                FileManager.default.createFile(atPath: out, contents: data)
            }
        }
    }

    /// Chạy bộ kiểm marked-text trên mọi engine có `NSTextInputClient`.
    @objc func runIMEChecks() {
        log("Kiểm bộ gõ tiếng Việt bằng máy (NFR-USE-02) — mô phỏng giao thức NSTextInputClient\n")
        var anyFailed = false
        for engine in engines {
            // Engine phải nằm trong cửa sổ và là first responder: một số hiện thực
            // `NSTextInputClient` hỏi tới window, và ngoài cửa sổ thì chúng im lặng không làm gì.
            picker.selectedSegment = engines.firstIndex { $0 === engine } ?? 0
            showEngineView()
            window?.displayIfNeeded()

            guard let client = engine.inputClient else {
                log("── Bộ gõ tiếng Việt · \(engine.name) ──")
                log("  ⚠️  không có NSTextInputClient — phải tự hiện thực giao thức bộ gõ\n")
                continue
            }
            let outcomes = IMEHarness.scenarios.map {
                IMEHarness.run($0, client: client,
                               readText: { engine.documentText() },
                               reset: { engine.resetDocument() },
                               placeCaret: { engine.placeCaret(after: $0) })
            }
            log(IMEHarness.report(engine.name, outcomes) + "\n")
            if outcomes.contains(where: { !$0.passed }) { anyFailed = true }
        }
        // Đối chứng âm: phép kiểm phải BẮT được lỗi kinh điển, nếu không thì mọi dấu ✅ ở
        // trên chỉ chứng minh phép kiểm luôn xanh.
        let broken = DeliberatelyBrokenInputClient()
        let controlOutcomes = IMEHarness.scenarios.map {
            IMEHarness.run($0, client: broken,
                           readText: { broken.text }, reset: { broken.reset() },
                           placeCaret: { _ in })
        }
        let caught = controlOutcomes.filter { !$0.passed }.count
        log("── Đối chứng âm · client cố tình nối thêm thay vì thay vùng marked ──")
        log("  bắt được \(caught)/\(controlOutcomes.count) kịch bản"
            + (caught >= 4 ? "  ✅ phép kiểm có tác dụng" : "  ❌ PHÉP KIỂM KHÔNG CÓ TÁC DỤNG"))
        if caught < 4 { anyFailed = true }
        log("")

        log(anyFailed
            ? "⚠️  Có kịch bản TRƯỢT — xem ADR-01 §7 trước khi chốt."
            : "Mọi kịch bản đạt. Vẫn CẦN người gõ thật bằng EVKey: phép kiểm này chứng minh"
              + " ứng dụng xử lý đúng giao thức, không chứng minh bộ gõ gửi đúng chuỗi.")
        if options.imeOnly { NSApp.terminate(nil) }
    }

    @objc func prepareIME() {
        let corpus = PoCRunner.makeCorpus(bytes: 1 << 20, ascii: options.ascii)
        try? currentEngine.load(corpus)
        currentEngine.beginTyping(atLine: 2)
        window?.makeFirstResponder(currentEngine.view)
        log("""

        ── Gõ thử IME tiếng Việt (\(currentEngine.name)) ──
          Bật EVKey/Telex rồi gõ vào khung trên. Kiểm đúng bốn thứ:
            1. "vieejt"    → "việt"      (dấu vào đúng nguyên âm, không nhảy ra sau)
            2. "ddaay"     → "đây"       (đ ở đầu âm tiết)
            3. "toans"     → "toán"      (dấu trên nguyên âm chính của nguyên âm đôi)
            4. gõ rồi Undo → về đúng trạng thái trước khi bắt đầu chuỗi marked-text
          Chữ đang soạn (marked text) phải có gạch chân và KHÔNG được nhảy vị trí.
        """)
    }

    @objc func runAll() {
        // Khi script gọi (một engine mỗi tiến trình), phần đầu đã do script ghi một lần.
        // Lặp lại nó ở mỗi mảnh chỉ làm báo cáo khó đọc.
        if options.onlyEngine == nil {
            log("PoC-A · ADR-01 — \(ProcessInfo.processInfo.operatingSystemVersionString)")
            log("máy: \(hardwareName()) · \(ProcessInfo.processInfo.processorCount) lõi")
            log("Scintilla \(GEScintillaView.scintillaVersion()) · mẫu gõ: \(options.typingSamples)\n")
        }

        // Chạy từng cỡ trên vòng lặp chính, không phải trong một hàm chạy thẳng: cửa sổ phải
        // được vẽ giữa các lần đo, nếu không AppKit gộp hết vào một lượt vẽ cuối.
        var work: [(DisplayEngine, Int)] = []
        for size in options.sizesMB {
            if options.onlyEngine == nil || options.onlyEngine == "scintilla" { work.append((scintilla, size)) }
            if options.onlyEngine == nil || options.onlyEngine == "textkit" { work.append((textKit, size)) }
            if options.onlyEngine == nil || options.onlyEngine == "lazy" { work.append((lazyTextKit, size)) }
            if options.onlyEngine == nil || options.onlyEngine == "paged" { work.append((paged, size)) }
        }
        runNext(work, index: 0, skip: Set<String>())
    }

    private func runNext(_ work: [(DisplayEngine, Int)], index: Int, skip: Set<String>) {
        guard index < work.count else {
            if options.onlyEngine == nil { log("\n── xong ──") }
            if options.auto && !options.hold { NSApp.terminate(nil) }
            return
        }
        let (engine, sizeMB) = work[index]
        var skip = skip

        if skip.contains(engine.name) {
            log("── \(engine.name) · \(sizeMB) MB — BỎ QUA (cỡ trước đã vượt ngân sách) ──")
            DispatchQueue.main.async { self.runNext(work, index: index + 1, skip: skip) }
            return
        }

        // Hiện đúng engine đang đo: view phải nằm trong cửa sổ thì mới thật sự vẽ.
        picker.selectedSegment = engines.firstIndex { $0 === engine } ?? 0
        showEngineView()
        window?.displayIfNeeded()

        let corpus = PoCRunner.makeCorpus(bytes: sizeMB << 20, ascii: options.ascii)
        let result = PoCRunner.run(engine: engine, corpus: corpus, typingSamples: options.typingSamples)
        log(result.report + "\n")

        if result.loadSeconds > PoCRunner.loadBudgetSeconds {
            log("   ⚠️  \(engine.name) vượt ngân sách nạp \(Int(PoCRunner.loadBudgetSeconds)) s — bỏ các cỡ lớn hơn")
            skip.insert(engine.name)
        }

        DispatchQueue.main.async { self.runNext(work, index: index + 1, skip: skip) }
    }

    private func hardwareName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0)
        return String(cString: bytes)
    }

    func startIfAutomatic() {
        if options.imeOnly {
            DispatchQueue.main.async { self.runIMEChecks() }
            return
        }
        guard options.auto else { return }
        DispatchQueue.main.async { self.runAll() }
    }
}

final class PoCAppDelegate: NSObject, NSApplicationDelegate {
    let controller: PoCWindowController

    init(options: Options) {
        controller = PoCWindowController(options: options)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.startIfAutomatic()
    }
}

let options = parseOptions()
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = PoCAppDelegate(options: options)
application.delegate = delegate
application.run()
