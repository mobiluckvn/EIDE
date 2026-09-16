import AppKit
import EIDEKit
import GEditorCore

/// NFR-USE-01: menu bar đầy đủ theo HIG — App/File/Edit/View/Search/Format/Window/Help.
/// Người dùng Notepad++ được đón bằng KEYMAP PRESET, không phải bằng giao diện Windows (NT-4).
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var mainWindowController: MainWindowController?
    private var cliBridge: CLIBridgeServer?
    private var servicesProvider: ServicesProvider?

    /// Mở cửa sổ EIDE — UXD-13 §1/§2 (sidebar 23 màn, 1440×900).
    ///
    /// Khác `MainWindowController.showEidePanel` ở CHỖ ĐỨNG chứ không ở nội dung: cùng một
    /// `EidePanel`, nhưng một bên là dải 420 px dưới đáy trình soạn thảo, một bên là cửa sổ
    /// riêng của sản phẩm. Mockup §2 mô tả cái thứ hai.
    @MainActor
    @objc func moCuaSoEide() {
        // KHÔNG mở cửa sổ mới: cửa sổ chính ĐÃ LÀ EIDE từ DEV-098 (sidebar 23 màn bên trái,
        // trình soạn thảo là màn "Mã nguồn"). Mục menu này nay chỉ đưa nó lên trước và mở màn
        // Tổng quan — giữ lại vì nó là lối vào không đi qua menu Format, vốn bị AppKit vô hiệu
        // hoá toàn bộ khi chạy binary trần lúc phát triển.
        guard let cua = mainWindowController else { return }
        cua.showWindow(nil)
        cua.window?.makeKeyAndOrderFront(nil)
        cua.chonManEide(tien: "Main")
    }

    /// Dự án EIDE mở sẵn lúc khởi động, hoặc nil.
    ///
    /// Hai nguồn, theo thứ tự: biến môi trường `EIDE_PROJECT` (chỉ đích danh — dùng khi mở từ
    /// dòng lệnh hoặc khi kiểm thử), rồi **dự án gần nhất**. Mở lại dự án gần nhất là thứ người
    /// dùng mong đợi ở một IDE; mở lên một cửa sổ trống sau khi hôm qua vừa làm việc cả buổi là
    /// bắt họ đi tìm lại đường vào mỗi sáng.
    ///
    /// Kiểm `EideDuAn.kiem` trước khi trả về: dự án gần nhất có thể đã bị xoá hoặc đổi tên, và
    /// khởi động lên một hộp thoại lỗi thì tệ hơn là khởi động lên một cửa sổ trống.
    @MainActor
    static func duAnMoSan() -> String? {
        if let d = ProcessInfo.processInfo.environment["EIDE_PROJECT"], !d.isEmpty {
            return EideDuAn.kiem(d).loi == nil ? d : nil
        }
        return EideDuAn.ganDay().first { EideDuAn.kiem($0).loi == nil }
    }

    /// **Tệp → Mở dự án EIDE…** — GIAM-SAT-UI §0.2.
    ///
    /// Chọn một thư mục có `.eide/`. Khác "Mở thư mục làm Workspace" ở trên: workspace là cây
    /// tệp cho trình soạn thảo, dự án EIDE là chỗ có store, sổ cái, chính sách và hộ chiếu.
    @MainActor
    @objc func moDuAnEide(_ sender: Any?) {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.allowsMultipleSelection = false
        p.prompt = "Mở dự án"
        p.message = "Chọn thư mục dự án EIDE (thư mục có `.eide/`)"
        // Mở sẵn ở `~/eide` — `defaults.project_dir` của POL-17, tức chỗ `project.create` đặt
        // dự án mới. Người vừa bảo tác tử tạo dự án sẽ tìm nó ở đúng đó.
        let mac_dinh = NSHomeDirectory() + "/eide"
        if FileManager.default.fileExists(atPath: mac_dinh) {
            p.directoryURL = URL(fileURLWithPath: mac_dinh)
        }
        guard p.runModal() == .OK, let u = p.url else { return }
        moDuAnEide(duong: u.path)
    }

    /// Mở một dự án theo đường dẫn — dùng chung cho hộp thoại và menu gần đây.
    /// Mở một dự án theo đường dẫn.
    ///
    /// `diTru: true` cho dự án VỪA TẠO: `project.create` không chạy migration, nên store chưa
    /// có bảng nào — và hàng đợi cần store để mục ASK sống qua các phiên. Đo 14/09 trên luồng
    /// AVR: mục chờ đầu tiên biến mất, `eide queue list` trả rỗng, và không có gì báo lý do.
    @MainActor
    func moDuAnEide(duong: String, diTru: Bool = false) {
        if diTru { Self.diTruStore(duong) }
        // Kiểm TRƯỚC khi mở cửa sổ: `eide daemon -p <không phải dự án>` vẫn chạy và vẫn trả lời
        // RPC, chỉ trả rỗng cho mọi thứ — người dùng khi ấy nhìn một cửa sổ đầy màn trống mà
        // không có gì nói cho họ biết đã chọn nhầm.
        if let loi = EideDuAn.kiem(duong).loi {
            let a = NSAlert()
            a.messageText = "Không mở được dự án"
            a.informativeText = loi
            a.runModal()
            return
        }
        // Đổi dự án NGAY TRONG cửa sổ đang mở.
        //
        // Trước 15/09/2026, nhánh này dựng một `EideWindowController` — cửa sổ EIDE thời trước
        // DEV-098. Chọn một dự án từ menu trên thanh trên vì thế mở ra một cửa sổ THỨ HAI mang
        // dự án mới, trong khi cửa sổ người dùng đang nhìn giữ nguyên dự án cũ: hai bản sao của
        // cùng một sản phẩm, hai tiến trình daemon, hai dòng sự kiện, và không có gì trên màn
        // hình nói cho ai biết cái nào đang nói về cái gì. DEV-098 chốt "một giao diện tên
        // EIDE" — nhánh ấy là mảnh sót lại của trạng thái trước nó.
        guard let cua = mainWindowController else {
            bao(khongChayDuoc: ())
            return
        }
        if let loi = cua.doiDuAnEide(duong) {
            let a = NSAlert()
            a.messageText = "Không mở được dự án"
            a.informativeText = loi
            a.runModal()
            return
        }
        cua.showWindow(nil)
        cua.window?.makeKeyAndOrderFront(nil)
    }

    /// Chạy `eide migrate -p <dự án>` cho một dự án vừa tạo.
    ///
    /// Đồng bộ và chờ: nó mất vài chục ms, và mở daemon trước khi store có bảng thì hàng đợi
    /// im lặng nuốt mục chờ đầu tiên. Lỗi thì bỏ qua — `EideDuAn.kiem` ngay sau đây sẽ bắt và
    /// nói ra bằng câu của nó.
    @MainActor
    static func diTruStore(_ duong: String) {
        guard let eide = EideDaemonLauncher.timEide() else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: eide[0])
        p.arguments = Array(eide.dropFirst()) + ["migrate", "-p", duong]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        if let goc = EideDaemonLauncher.gocKho() {
            p.currentDirectoryURL = URL(fileURLWithPath: goc)
        }
        try? p.run()
        p.waitUntilExit()
    }

    /// **Tệp → Dự án EIDE gần đây** — dựng menu con ngay lúc bấm.
    ///
    /// Dựng lúc bấm chứ không lúc khởi động: danh sách đổi mỗi lần mở một dự án, và một menu
    /// dựng sẵn từ lúc mở app sẽ thiếu đúng dự án người vừa làm việc.
    @objc func duAnEideGanDay(_ sender: Any?) {
        let ds = EideDuAn.ganDay()
        let m = NSMenu()
        if ds.isEmpty {
            // Nói ra thay vì hiện một menu rỗng: menu rỗng trông như hỏng.
            let x = m.addItem(withTitle: "Chưa mở dự án EIDE nào", action: nil, keyEquivalent: "")
            x.isEnabled = false
        }
        for d in ds {
            let it = m.addItem(withTitle: EideDuAn.nhan(d, trong: ds),
                               action: #selector(moDuAnGanDay(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = d
            it.toolTip = d
        }
        if let it = sender as? NSMenuItem {
            it.submenu = m
            // Bấm thẳng vào mục cha (thay vì rê chuột) thì hiện menu tại vị trí con trỏ.
            if let sk = NSApp.currentEvent, sk.type == .leftMouseDown || sk.type == .keyDown {
                m.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            }
        }
    }

    @MainActor
    @objc private func moDuAnGanDay(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? String else { return }
        moDuAnEide(duong: d)
    }

    private func bao(khongChayDuoc: Void) {
        let a = NSAlert()
        a.messageText = "Chưa chạy được EIDE"
        a.informativeText = "Không tìm thấy `eide`. Chạy `make setup` trong kho EIDE, "
            + "hoặc đặt EIDE_PYTHON trỏ tới python của venv."
        a.runModal()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[GEditor] %@", GEditorCore.diagnosticSummary)

        // Lượt chạy không người thì dữ liệu đi vào thư mục tạm, không vào Application Support
        // thật. Phải đặt TRƯỚC `createDirectories` và trước `loadSettings` — sau đó thì đã có
        // đường đọc/ghi đi qua gốc cũ rồi. Xem `AppPaths.applicationSupportOverride`.
        if Unattended.isActive {
            let root = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("geditor-khong-nguoi-\(ProcessInfo.processInfo.processIdentifier)",
                                        isDirectory: true)
            AppPaths.applicationSupportOverride = root
            Unattended.registerTemporaryRoot(root)
        }

        // NFR-REL-03 — cài bộ bắt sự cố NGAY sau khi biết thư mục dữ liệu nằm ở đâu, trước
        // mọi việc nặng. Sự cố lúc khởi động là loại khó lần ra nhất, và đó cũng là loại mà
        // người dùng không có cách nào kể lại: app chưa kịp hiện gì.
        //
        // `install()` tự tắt trong lượt chạy không người — bộ tự kiểm cố ý gây lỗi ở vài chỗ,
        // và một handler bắt tín hiệu sẽ nuốt mất chúng.
        do {
            try AppPaths.createDirectories()
        } catch {
            NSLog("[GEditor] không tạo được thư mục dữ liệu: %@", String(describing: error))
        }

        // Lối vào của `check-crash-reporter.sh` phải đứng TRƯỚC `install()`: nó đổi thư mục
        // dữ liệu sang một chỗ tạm, mà `install()` chốt đường tệp báo cáo ngay lúc chạy. Bản
        // đầu đặt sau, và hai lượt thử ghi báo cáo vào Application Support THẬT của người đang
        // ngồi máy — đúng thứ một cờ đo đạc không bao giờ được làm.
        CrashReporter.runCrashSignalProbeIfRequested()
        CrashReporter.install()

        // Bộ tự kiểm và bộ chụp ảnh phải chạy ở MỘT ngôn ngữ tất định.
        //
        // `L10n.effective` giải `.system` theo locale của máy, nên trên một máy đặt tiếng Anh
        // thì mọi bài kiểm so chuỗi tiếng Việt sẽ trượt — và trượt vì lý do không liên quan gì
        // tới thứ chúng đang kiểm. Một bộ tự kiểm xanh trên máy này và đỏ trên máy kia là bộ
        // tự kiểm không dùng được.
        //
        // Đặt TRƯỚC `buildMenuBar` vì menu dựng một lần và giữ nguyên chữ của lần dựng ấy.
        if CommandLine.arguments.contains("--self-test")
            || CommandLine.arguments.contains("--capture")
            || CommandLine.arguments.contains("--vong-giao-dien")
            || CommandLine.arguments.contains("--office-e2e") {
            L10n.lock(to: .vi)
        }

        StartupProbe.mark("didFinishLaunching")
        buildMenuBar()
        // Chụp NGAY tại đây, trước khi có cửa sổ nào: xem `appOwnedMenuTitles`.
        AppDelegate.appOwnedMenuTitles = Self.currentMenuTitles()
        StartupProbe.mark("menuBar")

        let controller = MainWindowController()
        StartupProbe.mark("controllerInit")
        // Đọc cấu hình TRƯỚC khi cửa sổ hiện ra: cỡ chữ và nền đọc từ đó, và áp sau khi đã vẽ
        // thì người dùng thấy một nhịp nháy đổi giao diện ở mỗi lần khởi động.
        controller.loadSettings()
        // Cửa sổ đầu vào sổ đăng ký như mọi cửa sổ khác (FR-DOC-302). KHÔNG có "cửa sổ chính"
        // ngầm định: một cửa sổ đặc biệt sẽ lộ ra đúng lúc người dùng đóng nó và mở tiếp cái khác.
        WindowManager.shared.register(controller)
        controller.showWindow(nil)
        StartupProbe.mark("showWindow")
        controller.window?.makeKeyAndOrderFront(nil)
        mainWindowController = controller

        // Cửa sổ EIDE — giao diện của sản phẩm, mở bằng `--eide` hoặc `EIDE_UI=1`.
        //
        // Đây là lối vào KHÔNG đi qua menu, và điều đó có lý do đo được: menu của một app chạy
        // không có bundle (`.build/debug/GEditorApp` trần) bị AppKit vô hiệu hoá toàn bộ — mọi
        // mục trong menu Format đều `enabled: false`, kể cả mục mở panel EIDE. Trong lúc phát
        // triển thì đó là cách duy nhất chạy nhanh, nên phải có một đường không phụ thuộc menu.

        // FR-AUTO-606: đăng ký nhận văn bản/file từ ứng dụng khác qua menu Services.
        //
        // Đặt SAU khi cửa sổ đã có: hai dịch vụ đều cần một controller để mở tab, và đăng ký
        // trước thì có một quãng ngắn hệ điều hành đã quảng cáo dịch vụ mà ta chưa phục vụ nổi.
        let services = ServicesProvider(controller: controller)
        NSApp.servicesProvider = services
        servicesProvider = services

        StartupProbe.mark("windowFront")
        StartupProbe.layersAtLaunch = controller.attachedLayerNamesForSelfTest
        StartupProbe.grammarLibraryLoadedAtLaunch = GrammarLibrary.isLoaded
        // Ảnh dyld tại đúng mốc này — bất biến "khởi động chỉ nạp thứ thực sự cần" (ADR-14).
        // Phải chụp Ở ĐÂY: một dòng sau thôi là phiên đã khôi phục và bài kiểm đã mở panel.
        LazyLoadAudit.captureAtLaunch()

        // `--measure-startup`: đo NFR-PERF-01 và NFR-PERF-05 rồi thoát (xem `StartupProbe`).
        //
        // Đặt NGAY SAU khi cửa sổ hiện ra và TRƯỚC mọi việc khởi động lười khác (khôi phục
        // phiên, hỏi bản nháp): mốc của NFR-PERF-01 là "cửa sổ nhận được thao tác gõ", không
        // phải "app đã làm xong mọi việc".
        if CommandLine.arguments.contains("--measure-startup") {
            StartupProbe.reportAndExit(controller: controller)
        }

        // `--capture <thư-mục>`: chụp ảnh cửa sổ ở vài trạng thái rồi thoát (xem `WindowCapture`).
        if CommandLine.arguments.contains("--capture") {
            WindowCapture.run(controller: controller, arguments: CommandLine.arguments)
        }

        // `--vong-giao-dien <thư-mục>`: đi một vòng làm việc THẬT qua giao diện, ghi nhật ký và
        // ảnh từng bước rồi thoát. Xem `VongGiaoDien`.
        if CommandLine.arguments.contains("--vong-giao-dien") {
            VongGiaoDien.run(controller: controller, arguments: CommandLine.arguments)
        }

        // `--doc-sweep <thư-mục>`: mở MỌI tệp trong thư mục rồi báo cáo (xem `DocumentSweep`).
        if CommandLine.arguments.contains("--doc-sweep") {
            DocumentSweep.run(controller: controller, arguments: CommandLine.arguments)
        }

        // `--office-e2e`: đi hết vòng mở/sửa/lưu/đóng/mở lại cho ảnh · Office · file nén rồi
        // thoát. Chạy dưới `scripts/run-office-e2e.sh` (xem `OfficeE2E`).
        if CommandLine.arguments.contains("--office-e2e") {
            OfficeE2E.run(controller: controller, arguments: CommandLine.arguments)
        }

        // `--measure-idle N`: đo CPU và số lần đánh thức lúc nhàn rỗi rồi thoát
        // (NFR-PERF-07, xem `IdleProbe`).
        if CommandLine.arguments.contains("--measure-idle") {
            IdleProbe.run(on: controller, arguments: CommandLine.arguments)
        }

        // `--measure-open <tệp>…`: đo đường mở tệp và đường cuộn rồi thoát (xem `OpenProbe`).
        //
        // Tách khỏi `--measure-startup`: cái kia đo tới lúc cửa sổ nhận được thao tác gõ với
        // một tab RỖNG, và nó không chạm gì tới việc mở một tệp 46 MB.
        if CommandLine.arguments.contains("--measure-open") {
            OpenProbe.run(on: controller, arguments: CommandLine.arguments)
        }

        // `--mermaid-kpi`: đo NFR-MMD-01 trên chính `MermaidRenderer` rồi thoát.
        if CommandLine.arguments.contains("--mermaid-kpi") {
            MermaidKPI.run(arguments: CommandLine.arguments)
        }

        // `--soak N`: chạy dài ngẫu nhiên rồi thoát (NFR-REL-03, xem `SoakTest`).
        if CommandLine.arguments.contains("--soak") {
            SoakTest.run(on: controller, arguments: CommandLine.arguments)
        }

        // `--self-test`: chạy các bài không kiểm được bằng phím giả lập rồi thoát.
        if CommandLine.arguments.contains("--self-test") {
            let status = SelfTest.run(on: controller)
            exit(status)
        }

        // Cầu nối `geditor` chỉ có ở bản tải trực tiếp — bản App Store chạy trong sandbox, và
        // socket Unix trong Application Support khi ấy trỏ vào container nên tiến trình CLI
        // bên ngoài không mở được. Xem `Distribution`.
        if Distribution.current.supportsCLIBridge {
            startCLIBridge(for: controller)
        }

        // Mở lại phiên trước TRƯỚC khi hỏi về bản nháp mồ côi (FR-DOC-303).
        //
        // Thứ tự này quan trọng: phiên đã ôm sẵn phần lớn bản nháp (tab nào chưa lưu thì phiên
        // ghi cả `documentID` của nó). Hỏi trước rồi khôi phục sau sẽ thành hỏi người dùng một
        // câu mà chính ta sắp tự trả lời — và trả lời khác đi.
        let restored = WindowManager.shared.restoreSession()
        if restored > 0 {
            controller.showRestoreBanner("Đã mở lại \(restored) tab của phiên trước.")
        }

        // Chạy thẳng từ terminal (`GEditor file.txt`) thì file đến qua argv, không qua Apple
        // Event — `application(_:openFiles:)` sẽ không bao giờ được gọi.
        //
        // Mở file này SAU khi đã khôi phục phiên, và mở THÊM một tab chứ không thay cả phiên.
        // Bản đầu thoát sớm ở đây, trước cả lệnh khôi phục — hậu quả không phải chỉ là "không
        // mở lại tab": lúc thoát, app ghi đè phiên bằng đúng một tab vừa mở, nên `geditor
        // foo.txt` NUỐT MẤT danh sách tab của phiên trước. Người dùng không có cách nào lấy lại.
        let files = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        if let first = files.first {
            controller.openInNewTab(path: first)
        }

        // NFR-REL-01 / TC-DOC-01 — hỏi khôi phục SAU khi cửa sổ đã hiện, không phải trước:
        // hộp thoại modal bung ra trên nền trống trông như ứng dụng lỗi, và người dùng không
        // có ngữ cảnh nào để quyết định.
        offerToRestoreSnapshots(alreadyRestored: controller.restoredDocumentIDs)

        // NFR-REL-03 — lần chạy sau một sự cố thì NÓI RA. Đặt sau phần khôi phục nháp: thứ
        // người dùng cần trước hết là tài liệu của họ, báo cáo sự cố đứng sau.
        if let notice = CrashReporter.pendingNotice() {
            controller.showBannerPublic(
                notice, actionTitle: L("Mở báo cáo"),
                action: #selector(MainWindowController.openCrashReport(_:)))
        }

        offerWelcomeWindow(for: controller)
    }

    /// Mở cửa sổ chào ở lần khởi động, trừ khi người dùng đã tắt (NFR-USE-04).
    ///
    /// **Dựng ở LƯỢT CHẠY SAU của vòng lặp sự kiện, không phải ngay tại đây.** Cửa sổ trợ giúp
    /// phải dựng gần trăm view cho trang đầu; làm việc ấy trong `didFinishLaunching` là cộng
    /// thẳng vào quãng người dùng chờ tới lúc gõ được — đúng thứ NFR-PERF-01 đo, và đúng thứ
    /// ADR-08 đã tốn bốn bước để giành lại.
    ///
    /// **Nói rõ một giới hạn của phép đo:** `--measure-startup` thoát TRƯỚC dòng này, nên con số
    /// 465 ms không bao gồm cửa sổ chào. Điều đó đúng với ý nghĩa của chỉ tiêu — nó đo tới lúc
    /// cửa sổ soạn thảo nhận được thao tác gõ, và cửa sổ chào dựng sau mốc ấy — nhưng nó KHÔNG
    /// có nghĩa là cửa sổ chào miễn phí với người dùng thật.
    private func offerWelcomeWindow(for controller: MainWindowController) {
        guard AppDelegate.shouldShowWelcome(
            settingSaysYes: controller.settings.showWelcomeOnLaunch,
            arguments: CommandLine.arguments
        ) else { return }

        DispatchQueue.main.async {
            HelpWindowController.show(
                topicID: HelpContent.entryTopicID, welcome: true, settings: controller
            )
        }
    }

    /// Có mở cửa sổ chào ở lượt chạy này không.
    ///
    /// Tách khỏi `offerWelcomeWindow` để bài tự kiểm hỏi được nó. Bản đầu gộp làm một, và hậu quả
    /// là phần DUY NHẤT chưa ai kiểm lại đúng là phần quyết định — nó nằm sau một hàng rào mà
    /// chính bộ tự kiểm dựng lên để chặn cửa sổ bung ra giữa lượt chạy không người lái.
    ///
    /// Cả bốn cờ đo đạc đều thoát trước khi tới đây, nên hàng rào này là lớp thứ hai. Giữ nó vì
    /// một cờ mới thêm về sau sẽ không tự nhớ chạy qua chỗ này.
    static func shouldShowWelcome(settingSaysYes: Bool, arguments: [String]) -> Bool {
        guard settingSaysYes else { return false }
        let khongNguoiLai = ["--self-test", "--capture", "--measure", "--soak", "--office-e2e",
                             "--doc-sweep"]
        return !arguments.contains { argument in
            khongNguoiLai.contains { argument.hasPrefix($0) }
        }
    }

    /// Lắng nghe lệnh `geditor` (SAD §2.4 CLIBridge, FR-AUTO-605).
    ///
    /// Không lắng nghe được thì ứng dụng vẫn chạy bình thường — chỉ mất khả năng nhận file từ
    /// dòng lệnh. Đó là tính năng phụ, không đáng để chặn khởi động.
    private func startCLIBridge(for controller: MainWindowController) {
        let server = CLIBridgeServer()
        do {
            try server.start { [weak controller] request in
                guard let controller else { return }
                if let piped = request.stdinPath {
                    controller.openPipedContent(temporaryPath: piped)
                } else if let target = request.targets.first {
                    controller.open(
                        path: target.path, line: target.line, column: target.column,
                        readOnly: request.readOnly
                    )
                } else {
                    return
                }
                controller.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            cliBridge = server
            controller.cliBridge = server
        } catch {
            NSLog("[GEditor] không mở được cầu nối CLI: %@", String(describing: error))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ghi phiên TRƯỚC khi dọn dẹp: đây là lần ghi duy nhất chắc chắn có trạng thái cuối
        // cùng. Nhịp autosave 20 giây chỉ là lưới đỡ cho trường hợp không kịp thoát đẹp.
        WindowManager.shared.saveSession()

        // Dọn file socket: để lại thì lần chạy sau `geditor` tưởng có app đang chạy và treo
        // một nhịp trước khi nhận ra không ai trả lời.
        cliBridge?.stop()
    }

    /// "Đã khôi phục N tài liệu chưa lưu từ phiên trước" (UI/UX §7.1).
    private func offerToRestoreSnapshots(alreadyRestored: Set<String> = []) {
        let store = SnapshotStore()
        // Bỏ những bản nháp mà phiên vừa mở lại rồi: hỏi lại chúng là mời người dùng mở
        // trùng cùng một nội dung thành hai tab.
        let pending = ((try? store.pendingSnapshots()) ?? [])
            .filter { !alreadyRestored.contains($0.documentID) }
        guard !pending.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Đã tìm thấy \(pending.count) tài liệu chưa lưu từ phiên trước"
        alert.informativeText = pending
            .prefix(5)
            .map { $0.originalPath.map { ($0 as NSString).lastPathComponent } ?? "Chưa đặt tên" }
            .joined(separator: "\n")
        alert.addButton(withTitle: "Khôi phục")
        alert.addButton(withTitle: "Bỏ qua")

        guard Unattended.ask(alert) == .alertFirstButtonReturn else {
            // "Bỏ qua" KHÔNG xóa bản nháp: người dùng có thể đổi ý, và xóa dữ liệu chưa lưu
            // của họ vì một lần bấm nhầm là thứ không sửa được.
            return
        }
        mainWindowController?.restoreFirstSnapshot(pending, store: store)
    }

    /// Đóng cửa sổ CUỐI CÙNG thì thoát app.
    ///
    /// Đúng lối của một trình soạn thảo tài liệu trên macOS: người dùng đóng cửa sổ cuối là họ
    /// đã xong. Giữ app sống trong Dock mà không cửa sổ nào thì họ phải bấm biểu tượng để lấy
    /// lại một cửa sổ trống — thêm một bước không ai xin.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// ⌘⇧N — cửa sổ mới (FR-DOC-302).
    @objc func newWindow(_ sender: Any?) {
        WindowManager.shared.newWindow()
    }

    /// Mở file do Finder, `open -a GEditor` hoặc lệnh `geditor` chuyển tới.
    ///
    /// # Bốn chỗ hỏng trong mười dòng, và chúng chỉ lộ ra khi app ĐANG CHẠY SẴN
    ///
    /// Anh báo: mở một tệp từ Finder khi GEditor đã mở từ trước thì không thấy app bật lên.
    /// Bản cũ hỏng theo bốn cách khác nhau, và cả bốn đều biến mất nếu app vừa khởi động —
    /// đúng trạng thái mà mọi lần thử tay đều rơi vào.
    ///
    /// 1. **Không đưa app ra trước.** macOS chỉ tự kích hoạt app trong vài đường; mở bằng "Mở
    ///    bằng ▸", bằng `open -a`, hay khi app đang ở sau một cửa sổ khác thì tệp được mở
    ///    ĐÚNG — chỉ là không ai nhìn thấy. Với người dùng thì "không mở được" và "mở rồi mà
    ///    nằm sau lưng" là cùng một chuyện.
    ///
    /// 2. **Trỏ vào cửa sổ ĐẦU TIÊN chứ không cửa sổ đang dùng.** `mainWindowController` được
    ///    gán một lần lúc khởi động và không bao giờ đổi. Mở cửa sổ thứ hai rồi đóng cửa sổ
    ///    đầu thì con trỏ ấy trỏ vào một controller đã chết: `open(path:)` chạy, không lỗi,
    ///    không hiện gì. `WindowManager.active` mới là chỗ biết cửa sổ nào đang ở trước.
    ///
    /// 3. **Không cửa sổ nào thì không làm gì.** `mainWindowController?.open` với `nil` là một
    ///    câu lệnh rỗng — rồi vẫn báo `.success` cho hệ điều hành. Nay dựng cửa sổ mới.
    ///
    /// 4. **Chỉ mở tệp ĐẦU TIÊN.** Chọn năm tệp trong Finder rồi Enter thì bốn tệp biến mất
    ///    không lời nào. Ghi chú TODO cũ nói phải có thanh tab trước — thanh tab có từ lâu rồi,
    ///    ghi chú thì ở lại.
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard !filenames.isEmpty else {
            return sender.reply(toOpenOrPrint: .failure)
        }

        let controller = WindowManager.shared.active ?? WindowManager.shared.newWindow()
        for path in filenames {
            controller.open(path: path)
        }

        // Đưa ra trước SAU khi đã mở, để cửa sổ hiện lên với nội dung đã sẵn thay vì hiện ra
        // rỗng rồi mới nhảy sang tab mới.
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        sender.reply(toOpenOrPrint: .success)
    }

    /// Bấm biểu tượng trong Dock khi app đang chạy mà không còn cửa sổ nào.
    ///
    /// `applicationShouldTerminateAfterLastWindowClosed` trả `true`, nên trạng thái này hiếm.
    /// Nhưng nó CÓ xảy ra: app vẫn sống trong lúc một hộp thoại lưu đang mở, và trong lúc chạy
    /// dưới cờ không người lái. Không có hàm này thì bấm vào Dock không ra gì cả.
    func applicationShouldHandleReopen(
        _ sender: NSApplication, hasVisibleWindows: Bool
    ) -> Bool {
        if !hasVisibleWindows, WindowManager.shared.active == nil {
            WindowManager.shared.newWindow()
        }
        WindowManager.shared.active?.window?.makeKeyAndOrderFront(nil)
        return true
    }

    // MARK: - Menu bar

    /// Nhan đề mọi mục menu do CHÍNH APP dựng, chụp ngay sau `buildMenuBar()`.
    ///
    /// **Vì sao phải phân biệt.** macOS tự chèn mục vào thanh menu khi thấy app có cửa sổ hợp
    /// lệ — `Enter Full Screen` vào View, các mục sắp xếp cửa sổ vào Window. Chúng do hệ điều
    /// hành dựng và hệ điều hành dịch, theo ngôn ngữ của MÁY chứ không theo bảng dịch của ta.
    ///
    /// Bài kiểm "mọi mục menu đều có bản dịch tiếng Anh" từng đòi dịch cả chúng, nên nó trượt
    /// ở bản binary trần mà lại xanh ở bundle — cùng một mã, khác kết quả, tuỳ máy tự chèn gì.
    /// Một bài kiểm đổi màu theo môi trường thì không nói được gì về sản phẩm.
    ///
    /// Chụp ở đúng thời điểm này chứ không lọc theo danh sách tên: `buildMenuBar()` chạy TRƯỚC
    /// khi cửa sổ đầu tiên ra đời, nên lúc ấy thanh menu chỉ có thứ của ta. Lọc theo tên tiếng
    /// Anh cứng thì lại hỏng ngay khi chạy trên máy đặt ngôn ngữ khác — đúng cái bẫy đang gỡ.
    static private(set) var appOwnedMenuTitles: Set<String> = []

    /// Nhan đề của mọi nhóm và mọi mục đang có trên thanh menu.
    static func currentMenuTitles() -> Set<String> {
        var titles: Set<String> = []
        for group in NSApp.mainMenu?.items ?? [] {
            guard let submenu = group.submenu else { continue }
            titles.insert(submenu.title)
            for item in submenu.items where !item.isSeparatorItem {
                titles.insert(item.title)
            }
        }
        return titles
    }

    private func buildMenuBar() {
        let mainMenu = NSMenu()

        // --- App ---
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let veItem = appMenu.addItem(withTitle: L("Về EIDE"), action: #selector(showAbout),
                                     keyEquivalent: "")
        veItem.target = self
        veItem.image = MenuIcons.image(for: "Về GEditor")
        appMenu.addItem(.separator())
        // NFR-SEC-01. Mục này CÓ MẶT ở cả hai kênh phát hành, và ở bản App Store nó nói ra vì
        // sao không dùng được thay vì biến mất: một mục menu vắng mặt là câu hỏi hỗ trợ, còn
        // một câu trả lời tại chỗ thì không. Cùng lối với plugin native và lọc lệnh ngoài.
        let capNhatItem = appMenu.addItem(withTitle: L("Kiểm tra bản cập nhật…"),
                                          action: #selector(checkForUpdates), keyEquivalent: "")
        capNhatItem.target = self
        capNhatItem.image = MenuIcons.image(for: "Kiểm tra bản cập nhật…")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Cài đặt…"), action: #selector(MainWindowController.showPreferences(_:)), keyEquivalent: ",")
            .image = MenuIcons.image(for: "Cài đặt…")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Thoát GEditor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ).image = MenuIcons.image(for: "Thoát GEditor")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // --- File ---
        // Action đi qua RESPONDER CHAIN (target nil): cửa sổ nào đang hoạt động thì cửa sổ đó
        // nhận lệnh. Gắn thẳng vào một controller cụ thể sẽ hỏng ngay khi có tab và split.
        mainMenu.addItem(makeMenu("File", items: [
            ("Tab mới", #selector(MainWindowController.newTab(_:)), "t"),
            ("Đóng tab", #selector(MainWindowController.closeCurrentTab(_:)), "w"),
            ("Tab kế", #selector(MainWindowController.nextTab(_:)), "}"),
            ("Tab trước", #selector(MainWindowController.previousTab(_:)), "{"),
            ("-", nil, ""),
            ("Tài liệu mới", #selector(MainWindowController.newDocument(_:)), "n"),
            // FR-DOC-302. ⌥⌘N vì ⇧⌘N đã là quy ước "thư mục mới" ở Finder và nhiều app.
            ("Cửa sổ mới", #selector(AppDelegate.newWindow(_:)), "~n"),
            // Có lệnh bàn phím chứ không chỉ có cú kéo: một tính năng chỉ dùng được bằng chuột
            // là tính năng người dùng VoiceOver và người dùng bàn phím không có (NFR-USE-03).
            ("Tách tab ra cửa sổ mới", #selector(MainWindowController.moveTabToNewWindow(_:)), "^n"),
            ("Mở…", #selector(MainWindowController.openDocument(_:)), "o"),
            ("Mở thư mục làm Workspace…", #selector(MainWindowController.openFolderAsWorkspace(_:)), "O"),
            ("Mở gần đây", #selector(MainWindowController.showRecentDocumentsMenu(_:)), ""),
            ("-", nil, ""),
            // Mở DỰ ÁN EIDE — khác hẳn "mở thư mục làm workspace" ở trên. Workspace là cây tệp
            // cho trình soạn thảo; dự án EIDE là một thư mục có `.eide/` với store, sổ cái,
            // chính sách và hộ chiếu. Không có đường này thì daemon chạy không thuộc dự án nào
            // và mọi màn có dữ liệu đều rỗng — rỗng vì KHÔNG CÓ DỰ ÁN, chứ không phải vì chưa
            // có dữ liệu (GIAM-SAT-UI §0.2).
            ("Mở dự án EIDE…", #selector(AppDelegate.moDuAnEide(_:)), "E"),
            ("Dự án EIDE gần đây", #selector(AppDelegate.duAnEideGanDay(_:)), ""),
            ("-", nil, ""),
            ("Lưu", #selector(MainWindowController.saveDocument(_:)), "s"),
            ("Lưu thành…", #selector(MainWindowController.saveDocumentAs(_:)), "S"),
            // FR-DOC-314. Ba lệnh quản lý tệp mà macOS dạy người dùng mong đợi ở menu File —
            // làm thẳng bằng `FileManager`, không qua `NSDocument` (xem FR-DOC-305 §4bis).
            ("Nhân bản tệp", #selector(MainWindowController.duplicateDocument(_:)), ""),
            ("Đổi tên tệp…", #selector(MainWindowController.renameDocument(_:)), ""),
            ("Chuyển tệp tới…", #selector(MainWindowController.moveDocument(_:)), ""),
            // FR-CORE-008. Mặc định TẮT: nó sửa những dòng người dùng không chạm tới, và bật
            // sẵn sẽ biến một lần lưu thành diff hàng nghìn dòng trong kho mã của người khác.
            ("Cắt khoảng trắng cuối dòng khi lưu", #selector(MainWindowController.toggleTrimOnSave(_:)), ""),
            ("-", nil, ""),
            // FR-DOC-309. Chế độ theo dõi khóa tài liệu ở CHỈ ĐỌC: vừa cho gõ vừa nạp thêm từ
            // đĩa là hai nguồn sửa đổi tranh nhau, và bên thua là phần người dùng vừa gõ.
            ("Theo dõi file (tail -f)", #selector(MainWindowController.toggleFollowTail(_:)), ""),
            ("In…", #selector(MainWindowController.printDocument(_:)), "p"),
            ("-", nil, ""),
            ("Mở lại tab vừa đóng", #selector(MainWindowController.reopenLastClosedTab(_:)), "T"),
        ]))

        // --- Edit ---
        // Undo/Redo đi vào `TextBuffer` chứ không vào `UndoManager` của AppKit: FR-CORE-004
        // đòi một thao tác hàng loạt là MỘT bước, mà UndoManager đếm theo từng lần gõ.
        mainMenu.addItem(makeMenu("Edit", items: [
            ("Hoàn tác", #selector(MainWindowController.undoDocument(_:)), "z"),
            ("Làm lại", #selector(MainWindowController.redoDocument(_:)), "Z"),
            ("-", nil, ""),
            ("Cắt", #selector(NSText.cut(_:)), "x"),
            ("Sao chép", #selector(MainWindowController.copySelection(_:)), "c"),
            ("Dán", #selector(MainWindowController.pasteSelection(_:)), "v"),
            ("Lịch sử clipboard…", #selector(MainWindowController.showClipboardHistory(_:)), "V"),
            ("Column Editor…", #selector(MainWindowController.showColumnEditor(_:)), "~c"),
            ("Chọn lần kế tiếp", #selector(MainWindowController.selectNextOccurrence(_:)), "d"),
            ("Chọn tất cả", #selector(NSText.selectAll(_:)), "a"),
            ("-", nil, ""),
            // Keymap chốt ở UI/UX §9.1 (khắc phục A-06): ⇧⌘D = Nhân đôi dòng, giữ
            // trí nhớ cơ bắp Ctrl+D của Notepad++. Distraction-free dùng ⌃⌘D.
            ("Nhân đôi dòng", #selector(MainWindowController.duplicateLines(_:)), "D"),
            ("Xóa dòng", #selector(MainWindowController.deleteLines(_:)), "K"),
            ("Comment dòng", #selector(MainWindowController.toggleComment(_:)), "/"),
        ]))

        // --- Search ---
        mainMenu.addItem(makeMenu("Search", items: [
            ("Tìm…", #selector(MainWindowController.showFindPanel(_:)), "f"),
            ("Tìm và thay…", #selector(MainWindowController.showFindPanel(_:)), "~f"),
            ("Tìm trong thư mục…", #selector(MainWindowController.findInFiles(_:)), "F"),
            ("Thay trong thư mục…", #selector(MainWindowController.replaceInFiles(_:)), ""),
            ("-", nil, ""),
            ("Kết quả kế", #selector(MainWindowController.findNextFromMenu(_:)), "g"),
            ("Kết quả trước", #selector(MainWindowController.findPreviousFromMenu(_:)), "G"),
            ("-", nil, ""),
            ("Đi tới dòng…", #selector(MainWindowController.goToLine(_:)), "l"),
            // FR-CORE-012. ⌃⌘B vì ⌘B thuộc về in đậm ở mọi ứng dụng Mac, kể cả nơi không có
            // chữ đậm — trí nhớ cơ bắp không phân biệt.
            ("Nhảy tới ngoặc khớp", #selector(MainWindowController.goToMatchingBracket(_:)), "^b"),
            ("-", nil, ""),
            // FR-SRCH-110. Thử regex trên một MẨU, không phải trên tài liệu 200 MB.
            ("Thử biểu thức chính quy…", #selector(MainWindowController.showRegexTester(_:)), ""),
            ("-", nil, ""),
            // Đánh dấu & lọc dòng (FR-SRCH-107). Phần tô màu ở lề thuộc lớp hiển thị và
            // chờ ADR-01; phần lọc thì dùng được ngay.
            ("Đánh dấu mọi dòng khớp…", #selector(MainWindowController.markAllMatchingLines(_:)), "m"),
            ("Đảo dấu", #selector(MainWindowController.invertLineMarks(_:)), ""),
            ("Bỏ mọi dấu", #selector(MainWindowController.clearLineMarks(_:)), ""),
            ("-", nil, ""),
            ("Chép dòng đã đánh dấu", #selector(MainWindowController.copyMarkedLines(_:)), ""),
            ("Xóa dòng đã đánh dấu", #selector(MainWindowController.deleteMarkedLines(_:)), ""),
            ("Chỉ giữ dòng đã đánh dấu", #selector(MainWindowController.keepOnlyMarkedLines(_:)), ""),
        ]))

        // --- Lines ---
        // Mọi mục ở đây là MỘT bước undo, dù chạm cả triệu dòng (FR-CORE-004).
        mainMenu.addItem(makeMenu("Lines", items: [
            ("Sắp xếp A→Z", #selector(MainWindowController.sortLinesAscending(_:)), ""),
            ("Sắp xếp Z→A", #selector(MainWindowController.sortLinesDescending(_:)), ""),
            ("Sắp xếp tự nhiên", #selector(MainWindowController.sortLinesNatural(_:)), ""),
            ("-", nil, ""),
            ("Khử trùng lặp", #selector(MainWindowController.removeDuplicateLines(_:)), ""),
            ("Đảo thứ tự dòng", #selector(MainWindowController.reverseLines(_:)), ""),
            ("-", nil, ""),
            // Dời dòng dùng ⌥↑/⌥↓ — quy ước của trình soạn thảo trên macOS. Notepad++ dùng
            // Ctrl+Shift+Up nhưng ⌃ trên macOS là chỗ của Mission Control.
            ("Dời dòng lên", #selector(MainWindowController.moveLinesUp(_:)), "~\u{F700}"),
            ("Dời dòng xuống", #selector(MainWindowController.moveLinesDown(_:)), "~\u{F701}"),
            ("Ghép dòng", #selector(MainWindowController.joinLines(_:)), "j"),
            ("Tách dòng theo độ dài…", #selector(MainWindowController.splitLinesByLength(_:)), ""),
            ("Tách dòng theo ký tự…", #selector(MainWindowController.splitLinesByCharacter(_:)), ""),
            ("-", nil, ""),
            ("Xóa dòng rỗng", #selector(MainWindowController.removeBlankLines(_:)), ""),
            ("Nén dòng trống liên tiếp", #selector(MainWindowController.squeezeBlankLines(_:)), ""),
            ("Cắt khoảng trắng cuối dòng", #selector(MainWindowController.trimTrailingWhitespace(_:)), ""),
            ("-", nil, ""),
            ("Tab → Space", #selector(MainWindowController.tabsToSpaces(_:)), ""),
            ("Space → Tab", #selector(MainWindowController.spacesToTabs(_:)), ""),
            ("-", nil, ""),
            // Đủ tám kiểu của FR-CORE-010. Lõi `LineOps.CaseStyle` có đủ từ đầu; trước đây
            // menu chỉ nối ba, nên năm kiểu kia không có đường vào nào.
            ("HOA", #selector(MainWindowController.convertToUppercase(_:)), ""),
            ("thường", #selector(MainWindowController.convertToLowercase(_:)), ""),
            ("Chữ Hoa Đầu Từ", #selector(MainWindowController.convertToTitleCase(_:)), ""),
            ("Chữ hoa đầu câu", #selector(MainWindowController.convertToSentenceCase(_:)), ""),
            ("Đảo hoa/thường", #selector(MainWindowController.invertCase(_:)), ""),
            ("camelCase", #selector(MainWindowController.convertToCamelCase(_:)), ""),
            ("snake_case", #selector(MainWindowController.convertToSnakeCase(_:)), ""),
            ("kebab-case", #selector(MainWindowController.convertToKebabCase(_:)), ""),
        ]))

        // --- CSV ---
        mainMenu.addItem(makeMenu("CSV", items: [
            // ⌥⌘T thuộc về việc CHUYỂN Bảng ↔ Văn bản, đúng như UI/UX §6 đặt. Trước đây phím
            // này gán cho bật/tắt chế độ CSV; nhường lại, vì thứ người dùng làm hàng chục lần
            // một buổi là chuyển cách nhìn, còn bật/tắt chế độ CSV thì gần như không ai đụng
            // tới sau lần đầu.
            ("CSV: chọn sheet…", #selector(MainWindowController.showSheetPicker(_:)), ""),
            ("Xem dạng bảng / văn bản", #selector(MainWindowController.toggleTableView(_:)), "~t"),
            ("-", nil, ""),
            ("Xóa cột…", #selector(MainWindowController.deleteCSVColumn(_:)), ""),
            ("Kiểm tra dữ liệu (số cột · kiểu)", #selector(MainWindowController.validateCSV(_:)), ""),
            // ⇧⌘L theo UI/UX §6.2. Đặc tả gọi nó là menu "Data → Clean-up"; ở đây menu tên
            // "CSV" và mọi thao tác dữ liệu đã nằm sẵn trong đó — thêm một menu nữa chỉ để
            // đúng chữ sẽ tách đôi một nhóm việc mà người dùng nghĩ là một.
            ("Bàn làm sạch dữ liệu…", #selector(MainWindowController.showCleanBench(_:)), "L"),
            // FR-CLN-004. Đứng cạnh Bàn làm sạch chứ không nằm trong nó: đây là thao tác
            // duy nhất của cụm cần người DUYỆT TỪNG CỤM, không phải xem trước rồi bấm một lần.
            ("Trùng lặp mờ theo cột…", #selector(MainWindowController.showFuzzyDedup(_:)), ""),
            // FR-KNW-906. Ra tab MỚI: file .nt là dữ liệu nguồn, một lệnh "xem dạng bảng"
            // không được viết đè lên nó.
            ("Mở triple/edge dạng bảng", #selector(MainWindowController.showTripleTable(_:)), ""),
            // FR-KNW-903. Ranh giới tô bằng chính DẤU DÒNG, nên bản đồ tài liệu và lệnh
            // "nhảy dấu kế tiếp" thấy chunk luôn — không phải học một cách điều hướng riêng.
            ("Xem trước cắt chunk…", #selector(MainWindowController.showChunkPreview(_:)), ""),
            // FR-KNW-910. Chỉ kê những cặp CÓ đường đi — kê hết rồi để người dùng bấm vào
            // một cặp không hỗ trợ là biến một giới hạn đã biết thành lỗi họ phải tự tìm.
            ("Chuyển đổi tri thức…", #selector(MainWindowController.showKnowledgeConvert(_:)), ""),
            // FR-KNW-908. Dùng lại Mark nhiều màu, nên bản đồ tài liệu và "nhảy dấu kế
            // tiếp" thấy entity luôn — không phải học một cách điều hướng riêng.
            // FR-MIN-006. Kết quả ra TAB MỚI dạng CSV chứ không dựng panel thứ mười lăm:
            // Table view, sắp xếp, lọc và xuất file đều chạy sẵn trên một bảng CSV thật.
            ("Khai phá văn bản (n-gram, TF-IDF)", #selector(MainWindowController.showTextMining(_:)), ""),
            ("Đánh dấu entity từ danh sách…", #selector(MainWindowController.showEntityMarking(_:)), ""),
            // FR-KNW-904. Lỗi đổ vào danh sách kết quả tìm chứ không dựng bảng thứ hai:
            // ngữ nghĩa khớp hẳn — "một danh sách vị trí trong tệp, bấm để nhảy tới".
            ("Kiểm cú pháp đồ thị", #selector(MainWindowController.validateGraphSyntax(_:)), ""),
            // FR-KNW-909. Schema là tệp RIÊNG người dùng chỉ ra — không đoán từ tên tệp,
            // vì đoán sai nghĩa là báo một tràng lỗi cho một tệp vốn đúng.
            ("Kiểm theo JSON Schema…", #selector(MainWindowController.validateAgainstJSONSchema(_:)), ""),
            ("Chạy công thức làm sạch…", #selector(MainWindowController.runCleaningRecipe(_:)), ""),
            ("-", nil, ""),
            ("Chuyển đổi…", #selector(MainWindowController.showConvertSheet(_:)), ""),
            ("Đổi dấu phân tách…", #selector(MainWindowController.changeCSVDelimiter(_:)), ""),
            ("Xuất sang JSON…", #selector(MainWindowController.exportCSVToJSON(_:)), ""),
        ]))

        // --- Format ---
        // FR-UI-805: bảng mã hiện thành HAI NHÓM TÁCH BẠCH bên trong menu bật lên, xem
        // `MainWindowController.showEncodingMenu`. Ở menu bar chỉ là hai cửa vào.
        mainMenu.addItem(makeMenu("Format", items: [
            ("Bảng mã…", #selector(MainWindowController.showEncodingMenu(_:)), ""),
            ("Xuống dòng…", #selector(MainWindowController.showEOLMenu(_:)), ""),
            // FR-ENC-206. Quan trọng với tiếng Việt hơn phần lớn ngôn ngữ khác: macOS sinh
            // NFD, Windows và web dùng NFC, và hai file trông giống hệt nhau vẫn khác byte.
            ("Chuẩn hóa Unicode…", #selector(MainWindowController.normalizeUnicode(_:)), ""),
            ("-", nil, ""),
            // Công cụ JSON (FR-FMT-504) và lint YAML (FR-FMT-507).
            ("JSON: định dạng lại", #selector(MainWindowController.formatJSON(_:)), "~j"),
            ("JSON: thu gọn một dòng", #selector(MainWindowController.minifyJSON(_:)), ""),
            ("JSON: sắp xếp khóa", #selector(MainWindowController.sortJSONKeys(_:)), ""),
            ("JSON: truy vấn JSONPath…", #selector(MainWindowController.showJSONPathPanel(_:)), "~J"),
            // FR-KNW-901 · FR-KNW-902 — chế độ JSONL và Chunk Inspector.
            ("JSONL: kiểm và soi chunk…", #selector(MainWindowController.showJSONLPanel(_:)), ""),
            // Hai lối vào EIDE, và chúng khác nhau về CHỖ ĐỨNG, không về nội dung:
            // panel nằm cạnh mã nguồn (tiện khi đang sửa code), cửa sổ là giao diện của sản
            // phẩm (UXD-13 §2: sidebar 23 màn, 1440×900). Cùng một `EidePanel` bên trong.
            // Panel cạnh mã vẫn giữ cho ai muốn EIDE nằm dưới trình soạn thảo cùng lúc;
            // sidebar của cửa sổ chính là lối đi thường ngày (DEV-098).
            ("EIDE: panel cạnh mã…", #selector(MainWindowController.showEidePanel(_:)), ""),
            // FR-KNW-918 · FR-KNW-919 — truy hồi BM25 và đánh giá golden set.
            ("JSONL: phòng thí nghiệm truy hồi…",
             #selector(MainWindowController.showRetrievalPanel(_:)), ""),
            ("-", nil, ""),
            // FR-CSV-407 — truy vấn SQL trên bảng CSV đang mở (ADR-11).
            ("CSV: truy vấn SQL…", #selector(MainWindowController.showSQLPanel(_:)), "~Q"),
            ("CSV: chất lượng dữ liệu…",
             #selector(MainWindowController.showQualityReport(_:)), ""),
            // FR-MIN-001 — tìm bất thường trên một cột số.
            ("CSV: tìm bất thường…",
             #selector(MainWindowController.showAnomalies(_:)), ""),
            // FR-MIN-005 — ma trận tương quan trên mọi cặp cột số.
            ("CSV: ma trận tương quan…",
             #selector(MainWindowController.showCorrelation(_:)), ""),
            // FR-MIN-002 — phân cụm k-means / DBSCAN.
            ("CSV: phân cụm…",
             #selector(MainWindowController.showClusterSheet(_:)), ""),
            // FR-MIN-004 — dự báo chuỗi thời gian, luôn so với baseline.
            ("CSV: dự báo chuỗi thời gian…",
             #selector(MainWindowController.showForecast(_:)), ""),
            // FR-MIN-007 — khai phá theo nhóm, mỗi nhóm một ngưỡng riêng.
            ("CSV: khai phá theo nhóm…",
             #selector(MainWindowController.showGroupMining(_:)), ""),
            // FR-MIN-003 — luật kết hợp Apriori.
            ("CSV: luật kết hợp…",
             #selector(MainWindowController.showAssociation(_:)), ""),
            ("-", nil, ""),
            // FR-RPT-001 — xem trước báo cáo .greport.md, soạn trái preview phải.
            ("Báo cáo: xem trước",
             #selector(MainWindowController.toggleReportPreview(_:)), "~R"),
            // FR-RPT-006 — mỗi bộ tham số một tệp.
            ("Báo cáo: sinh loạt…",
             #selector(MainWindowController.showReportBatch(_:)), ""),
            // FR-MMD-001/002 — Mermaid Studio: soạn trái, sơ đồ phải.
            ("Sơ đồ Mermaid: xem trước",
             #selector(MainWindowController.toggleMermaidStudio(_:)), "~D"),
            // FR-MMD-005 — thư viện mẫu, chèn một click.
            ("Sơ đồ Mermaid: chèn mẫu…",
             #selector(MainWindowController.showMermaidTemplates(_:)), ""),
            // FR-MMD-006 — chuẩn hoá thụt lề, giữ nguyên chú thích, một bước undo.
            ("Sơ đồ Mermaid: định dạng lại",
             #selector(MainWindowController.formatMermaid(_:)), ""),
            // FR-MMD-004 — soạn trực quan. Cử chỉ chuột (kéo, double-click) có bản sao ở đây
            // để tới được bằng bàn phím: NFR-USE-03 đòi *"điều hướng đầy đủ bằng bàn phím"*,
            // và không cử chỉ kéo nào gõ được trên bàn phím.
            ("Sơ đồ Mermaid: thêm phần tử…",
             #selector(MainWindowController.addMermaidNode(_:)), ""),
            ("Sơ đồ Mermaid: nối hai phần tử đang chọn",
             #selector(MainWindowController.addMermaidEdge(_:)), ""),
            ("Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…",
             #selector(MainWindowController.editMermaidLabel(_:)), ""),
            ("Sơ đồ Mermaid: xoá phần tử đang chọn",
             #selector(MainWindowController.removeMermaidElement(_:)), ""),
            ("Sơ đồ Mermaid: đưa message lên trên",
             #selector(MainWindowController.moveMermaidMessageUp(_:)), ""),
            ("Sơ đồ Mermaid: đưa message xuống dưới",
             #selector(MainWindowController.moveMermaidMessageDown(_:)), ""),
            // FR-MMD-008 — tách khối ra tệp .mmd rồi nhúng ngược, giữ tham chiếu để sửa một nơi.
            ("Sơ đồ Mermaid: tách khối ra tệp .mmd…",
             #selector(MainWindowController.splitMermaidBlock(_:)), ""),
            ("Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại",
             #selector(MainWindowController.embedMermaidBlock(_:)), ""),
            ("-", nil, ""),
            // Công cụ XML (FR-FMT-505). Chưa có validate XSD/DTD — phần ấy cần libxml2.
            ("XML: định dạng lại", #selector(MainWindowController.formatXML(_:)), ""),
            ("XML: thu gọn một dòng", #selector(MainWindowController.minifyXML(_:)), ""),
            ("XML: kiểm cú pháp", #selector(MainWindowController.validateXML(_:)), ""),
            // FR-FMT-505 (PoC-I). DTD qua Foundation, XSD qua libxml2 HỆ THỐNG nạp lười —
            // không vendor một byte nào, và máy không có libxml2 thì nói ra chứ không sập.
            ("XML: kiểm theo DTD/XSD…", #selector(MainWindowController.validateXMLAgainstSchema(_:)), ""),
            ("XML: đánh giá XPath…", #selector(MainWindowController.evaluateXPath(_:)), ""),
            ("-", nil, ""),
            ("YAML: kiểm khóa trùng và thụt lề", #selector(MainWindowController.lintYAML(_:)), ""),
            ("-", nil, ""),
            ("Xem trước Markdown", #selector(MainWindowController.showMarkdownPreview(_:)), ""),
        ]))

        // --- View ---
        let viewMenu = makeMenu("View", items: [
            ("Ẩn/hiện sidebar (Function List)", #selector(MainWindowController.toggleSidebar(_:)), "0"),
            ("Ẩn/hiện bản đồ tài liệu", #selector(MainWindowController.toggleDocumentMap(_:)), "~m"),
            ("-", nil, ""),
            // Gấp mã (FR-CORE · FR-FMT-507). ⌥⌘← / ⌥⌘→ theo đúng Xcode, vì người dùng macOS
            // mang thói quen ấy sang. ⌥⌘↑ và ⌥⌘↓ đã có chủ nên "gấp tất cả" thêm ⇧.
            ("Gấp / mở khối tại con nháy", #selector(MainWindowController.toggleFold(_:)), "~\u{F702}"),
            ("Gấp tất cả", #selector(MainWindowController.foldAll(_:)), "~+\u{F702}"),
            ("Bỏ gấp tất cả", #selector(MainWindowController.unfoldAll(_:)), "~\u{F703}"),
            ("-", nil, ""),
            // FR-CORE-016. ⌘0 đã là sidebar nên "cỡ gốc" dùng ⌘⌥0 — và ⌘= thay cho ⌘+ theo
            // đúng lối macOS (người dùng không phải giữ ⇧ để gõ dấu cộng).
            ("Phóng to chữ", #selector(MainWindowController.increaseFontSize(_:)), "="),
            ("Thu nhỏ chữ", #selector(MainWindowController.decreaseFontSize(_:)), "-"),
            // KHÔNG dùng ⌥⌘0: phím ấy đã là "Bỏ chia đôi". Trùng phím thì AppKit lặng lẽ chỉ
            // kích hoạt mục ĐẦU TIÊN và lệnh kia trông như hỏng — xem bài tự kiểm phím trùng.
            ("Cỡ chữ gốc", #selector(MainWindowController.resetFontSize(_:)), "^0"),
            ("-", nil, ""),
            // FR-DOC-302. ⌥⌘= / ⌥⌘- theo lối chia khung quen thuộc trên macOS.
            ("Chia đôi theo chiều dọc", #selector(MainWindowController.splitVertically(_:)), "~="),
            ("Chia đôi theo chiều ngang", #selector(MainWindowController.splitHorizontally(_:)), "~-"),
            ("Bỏ chia đôi", #selector(MainWindowController.closeSplitView(_:)), "~0"),
            ("Mở tab này ở nửa kia", #selector(MainWindowController.showTabInOtherPane(_:)), "~]"),
            ("Nhảy sang nửa kia", #selector(MainWindowController.focusOtherPane(_:)), "~["),
            ("-", nil, ""),
            // FR-CORE-015: một mục vòng qua ba chế độ, một mục đặt cột.
            //
            // KHÔNG gán ⌥⌘W dù nó vừa trống vừa dễ nhớ: trong hầu hết ứng dụng Mac, ⌥⌘W là
            // "đóng tất cả cửa sổ". Trong một trình soạn thảo có phần chưa lưu, cho phím ấy
            // một nghĩa khác là mời người dùng mất việc theo trí nhớ cơ bắp. Chỗ bấm nhanh của
            // lệnh này là mục "Ngắt: …" trên status bar.
            ("Ngắt dòng (tắt / cửa sổ / cột)", #selector(MainWindowController.cycleWrapMode(_:)), ""),
            ("Ngắt dòng tại cột…", #selector(MainWindowController.setWrapColumn(_:)), ""),
            ("-", nil, ""),
            // FR-SRCH-107. Giữ nguyên phím của Notepad++ (UI/UX §9.1: ⌘F2 bookmark, F2 nhảy)
            // — đây là nhóm người dùng mà cả sản phẩm nhắm tới, và trí nhớ cơ bắp của họ là
            // thứ không nên bắt học lại.
            ("Đánh dấu dòng này", #selector(MainWindowController.toggleLineMark(_:)), "\u{F705}"),
            ("Dấu kế tiếp", #selector(MainWindowController.goToNextMark(_:)), "!\u{F705}"),
            ("Dấu trước đó", #selector(MainWindowController.goToPreviousMark(_:)), "!+\u{F705}"),
            ("Màu đánh dấu…", #selector(MainWindowController.showMarkColorMenu(_:)), ""),
            ("-", nil, ""),
            // FR-ENC-205 đòi bật/tắt TỪNG NHÓM, không phải một công tắc chung.
            ("Hiện tất cả ký tự ẩn", #selector(MainWindowController.toggleAllInvisibles(_:)), "~i"),
            ("  Khoảng trắng", #selector(MainWindowController.toggleInvisibleSpaces(_:)), ""),
            ("  Tab", #selector(MainWindowController.toggleInvisibleTabs(_:)), ""),
            ("  Xuống dòng", #selector(MainWindowController.toggleInvisibleLineEndings(_:)), ""),
            ("  NBSP · zero-width · điều khiển", #selector(MainWindowController.toggleInvisibleSpecial(_:)), ""),
            ("Đổi chế độ View / Code", #selector(MainWindowController.toggleViewCode(_:)), "~v"),
            ("Xem nhị phân", #selector(MainWindowController.toggleBinaryView(_:)), ""),
            ("Chế độ CSV (tô màu theo cột)", #selector(MainWindowController.toggleCSVMode(_:)), ""),
            // FR-FMT-508. Tô THAY cho tô cú pháp, không chồng lên: file log không có cú pháp
            // để tô, và hai nguồn màu cùng ghi lên một khoảng byte thì không đoán được cái nào
            // thắng.
            ("Chế độ Log (tô theo mức)", #selector(MainWindowController.toggleLogMode(_:)), ""),
            ("Lọc log theo mức…", #selector(MainWindowController.filterLogLevel(_:)), ""),
        ])
        insertFoldLevelSubmenu(into: viewMenu)
        mainMenu.addItem(viewMenu)

        // --- Macro (FR-AUTO-601/602) ---
        mainMenu.addItem(makeMenu("Macro", items: [
            ("Bắt đầu / dừng ghi", #selector(MainWindowController.toggleMacroRecording(_:)), "^r"),
            ("-", nil, ""),
            ("Phát lại", #selector(MainWindowController.playMacro(_:)), "^p"),
            ("Phát nhiều lần…", #selector(MainWindowController.playMacroTimes(_:)), ""),
            ("Phát đến cuối tài liệu", #selector(MainWindowController.playMacroToEndOfFile(_:)), ""),
            ("Chạy trên mọi tab", #selector(MainWindowController.playMacroOnAllTabs(_:)), ""),
            // FR-AUTO-602 phần batch. Khác "mọi tab" ở chỗ file còn CHƯA MỞ, nên không có gì
            // để nhìn và không có bước lùi nào — mặc định ghi ra file mới.
            ("Chạy trên cả thư mục…", #selector(MainWindowController.playMacroOnFolder(_:)), ""),
            ("Hủy macro đang chạy", #selector(MainWindowController.cancelMacro(_:)), ""),
            ("-", nil, ""),
            ("Lưu macro…", #selector(MainWindowController.saveMacro(_:)), ""),
            ("Macro đã lưu…", #selector(MainWindowController.showSavedMacroMenu(_:)), ""),
            ("-", nil, ""),
            // FR-AUTO-604. Chỉ chạy ở bản tải trực tiếp; bản App Store nói rõ vì sao không.
            ("Lọc qua lệnh ngoài…", #selector(MainWindowController.runTextFilter(_:)), ""),
            // FR-AUTO-603 · FR-PLUG-701. Script JavaScript trong `scripts/`, API cố ý hẹp.
            ("Script…", #selector(MainWindowController.showScriptMenu(_:)), ""),
            // FR-PLUG-701 · FR-PLUG-705. Gói là MỘT file JSON: cài là chép file, gỡ là xoá file,
            // và danh sách gói suy ra từ ĐĨA chứ không từ một cuốn sổ có thể nói dối.
            ("Gói mở rộng…", #selector(MainWindowController.showPluginManager(_:)), ""),
            // FR-DOC-305 hướng A (PoC-J): kho phiên bản CỦA HỆ ĐIỀU HÀNH, bảng duyệt của
            // GEditor. Giao diện lịch sử nguyên bản của macOS đòi `NSDocument` — xem PoC-J.
            ("Bản đã lưu…", #selector(MainWindowController.showDocumentVersions(_:)), ""),
            // FR-PLUG-702/703/704 (ADR-12). Plugin NATIVE chạy ở tiến trình riêng, và chỉ có ở
            // bản tải trực tiếp — bản App Store nói rõ vì sao không, không mờ đi im lặng.
            ("Plugin native…", #selector(MainWindowController.showNativePluginMenu(_:)), ""),
        ]))

        // --- Window / Help ---
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // NFR-USE-04. Nội dung là chuỗi trong mã (`HelpContent`), không phải file trong bundle:
        // hai kênh phát hành có bố cục bundle khác nhau, và một trang trợ giúp mở không nổi vì
        // tìm không thấy file thì hỏng đúng lúc người dùng đang bí.
        mainMenu.addItem(makeMenu("Help", items: [
            ("Trợ giúp GEditor", #selector(MainWindowController.showHelpPage(_:)), "?"),
            ("Giới thiệu tính năng", #selector(MainWindowController.showWelcomeTour(_:)), ""),
            ("Di cư từ Notepad++", #selector(MainWindowController.showMigrationPage(_:)), ""),
        ]))

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    /// Phím tắt ghi bằng tiền tố: "^" = ⌃, "~" = ⌥, "+" = ⇧, "!" = BỎ ⌘, chữ HOA = ⇧ (quy
    /// ước sẵn có của AppKit).
    ///
    /// Cần vì hai lệnh cùng dùng chữ F theo keymap UI/UX §9.1: ⌥⌘F là Tìm và thay, ⇧⌘F là
    /// Tìm trong thư mục. Trùng phím tắt thì AppKit lặng lẽ chỉ kích hoạt mục ĐẦU TIÊN, và
    /// lệnh kia trông như hỏng.
    ///
    /// "!" và "+" thêm vào để giữ đúng phím Notepad++ cho phím CHỨC NĂNG: keymap đòi F2 trần
    /// để nhảy bookmark và ⇧F2 để lùi. Với chữ cái thì ⇧ ghi bằng chữ HOA, nhưng F2 không có
    /// chữ hoa nên phải nói thẳng ra.
    private func makeMenu(_ title: String, items: [(String, Selector?, String)]) -> NSMenuItem {
        let item = NSMenuItem()
        // FR-UI-804: dịch ở ĐÚNG MỘT CHỖ — chỗ mục menu thật sự được tạo ra. Dịch ở từng lời
        // gọi thì mỗi mục thêm về sau là một cơ hội quên.
        let menu = NSMenu(title: L(title))
        for (label, action, key) in items {
            if label == "-" {
                menu.addItem(.separator())
                continue
            }
            var modifiers: NSEvent.ModifierFlags = [.command]
            var key = key
            while let first = key.first, "^~+!".contains(first) {
                switch first {
                case "^": modifiers.insert(.control)
                case "~": modifiers.insert(.option)
                case "+": modifiers.insert(.shift)
                default: modifiers.remove(.command)
                }
                key.removeFirst()
            }
            let entry = menu.addItem(withTitle: L(label), action: action, keyEquivalent: key)
            // Biểu tượng tra bằng nhãn GỐC, không phải nhãn đã dịch: `MenuIcons` và bảng dịch
            // dùng chung một hệ khoá, nên tra bằng `L(label)` sẽ trượt ở mọi thứ tiếng trừ
            // tiếng Việt — và trượt im lặng, chỉ mất hình.
            entry.image = MenuIcons.image(for: label)
            if key.first?.isUppercase == true { modifiers.insert(.shift) }
            entry.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        }
        item.submenu = menu
        return item
    }

    /// Vế thứ ba của FR-FMT-503 — "fold theo cấp", tám cấp như Notepad++.
    ///
    /// Là SUBMENU chứ không phải tám mục phẳng: menu View đã dài, và tám dòng chỉ khác nhau một
    /// chữ số đọc thành một bức tường. `makeMenu` chỉ dựng menu cấp một nên phần này viết tay,
    /// nhưng vẫn đi qua `L()` ở đúng chỗ mục được tạo ra — cùng luật với `makeMenu` (FR-UI-804).
    ///
    /// Chèn NGAY SAU "Bỏ gấp tất cả" bằng cách tìm theo selector chứ không theo chỉ số cứng:
    /// một mục thêm vào menu View ngày mai sẽ làm chỉ số cứng chèn nhầm chỗ, im lặng.
    private func insertFoldLevelSubmenu(into viewMenu: NSMenuItem) {
        guard let menu = viewMenu.submenu else { return }
        let anchor = menu.indexOfItem(
            withTarget: nil, andAction: #selector(MainWindowController.unfoldAll(_:)))
        guard anchor >= 0 else { return }

        let submenu = NSMenu(title: L("Gấp theo cấp"))
        for level in 1...8 {
            let item = submenu.addItem(
                withTitle: LF("Cấp %d", level),
                action: #selector(MainWindowController.foldToLevel(_:)),
                keyEquivalent: String(level))
            // Cấp đi qua `tag`, không qua nhan đề: nhan đề đổi theo ngôn ngữ giao diện.
            item.tag = level
            item.keyEquivalentModifierMask = [.command, .option]
        }

        let holder = NSMenuItem(title: L("Gấp theo cấp"), action: nil, keyEquivalent: "")
        holder.image = MenuIcons.image(for: "Gấp theo cấp")
        holder.submenu = submenu
        menu.insertItem(holder, at: anchor + 1)
    }

    /// "Kiểm tra bản cập nhật…" — NFR-SEC-01.
    ///
    /// Không dùng được thì **nói ra bằng một hộp thoại**, chứ không làm mục menu mờ đi. Người
    /// dùng bản App Store bấm vào đây là đang hỏi một câu chính đáng ("có bản mới không?"), và
    /// câu trả lời đúng là "có, nhưng qua App Store" — không phải sự im lặng.
    @MainActor @objc private func checkForUpdates() {
        if let ly_do = UpdateController.shared.unavailableReason {
            let hop = NSAlert()
            hop.messageText = L("Kiểm tra bản cập nhật")
            hop.informativeText = ly_do
            hop.addButton(withTitle: L("Đóng"))
            hop.runModal()
            return
        }
        UpdateController.shared.checkForUpdates(self)
    }

    /// Dòng chú thích của hộp "Về GEditor".
    ///
    /// `GEditorCore.diagnosticSummary` (phiên bản · kiến trúc · SIMD · kênh phát hành) **cộng
    /// thêm phiên bản mermaid** — NFR-MMD-02 đòi nguyên văn *"phiên bản pin và ghi trong
    /// About"*. Vế "pin" đã có từ lúc vendor và có bài tự kiểm đòi trang chạy đúng bản đã kê;
    /// vế "ghi trong About" thì thiếu tới 28/08/2026, và nó không thừa: khi một sơ đồ cũ đột
    /// nhiên vẽ khác đi, câu hỏi ĐẦU TIÊN là "bản mermaid nào", và người trả lời là người dùng
    /// đang ngồi trước máy chứ không phải người đọc được kho mã.
    ///
    /// Ghép ở tầng app chứ không nhét vào `diagnosticSummary`: bản kê mermaid là tài nguyên của
    /// bundle, mà lõi thì không được biết gì về bundle (NFR-MNT-01).
    static var aboutCredits: String {
        guard let version = MermaidAsset.manifest?.version, !version.isEmpty else {
            // Không có bản kê thì NÓI RA, đừng im lặng bỏ vế ấy đi — một hộp About thiếu dòng
            // này trông y hệt một hộp About của bản dựng lành lặn.
            return GEditorCore.diagnosticSummary + " · " + L("mermaid: không đọc được bản kê")
        }
        return GEditorCore.diagnosticSummary + " · mermaid \(version)"
    }

    @objc private func showAbout() {
        // Ảnh trong hộp Giới thiệu là WORDMARK đầy đủ (hình + chữ), không phải biểu tượng.
        //
        // Đây là chỗ DUY NHẤT trong sản phẩm có đủ chỗ ngang cho tỉ lệ 347×40, và là chỗ câu
        // "Học viện Công nghệ Bưu chính Viễn thông" cần đọc được — thanh trên chỉ đủ cho hình.
        var tuy: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "EIDE",
            .applicationVersion: GEditorCore.version,
            .init(rawValue: "Copyright"): "CÔNG TY TNHH MOBILUCK · code247.ai",
            .credits: NSAttributedString(
                string: "Đề án tốt nghiệp Thạc sĩ Kỹ thuật Điện tử — Học viện Công nghệ Bưu "
                    + "chính Viễn thông (PTIT)\nHọc viên Vũ Trí Công · GVHD TS. Nguyễn Trung "
                    + "Hiếu\n\n" + Self.aboutCredits,
                attributes: [.font: Tokens.Font.caption]
            ),
        ]
        // Thiếu ảnh thì BỎ khoá, không đặt `nil`: `orderFrontStandardAboutPanel` nhận một khoá
        // mang nil và vẽ ra một ô trống thay cho icon ứng dụng — tệ hơn là không đặt gì.
        if let logo = EideLogo.wordmark() { tuy[.applicationIcon] = logo }
        NSApp.orderFrontStandardAboutPanel(options: tuy)
    }
}
