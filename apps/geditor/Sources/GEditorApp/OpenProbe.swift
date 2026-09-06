import AppKit
import Darwin
import GEditorCore

/// Đo đường MỞ MỘT TỆP và đường CUỘN trên tệp ấy — `GEditorApp --measure-open <tệp>…`.
///
/// # Vì sao cần một phép đo riêng, khi đã có `--measure-startup`
///
/// `StartupProbe` đo tới lúc **cửa sổ nhận được thao tác gõ** với một tab rỗng. Nó không chạm
/// tới thứ người dùng đang phàn nàn: mở một tệp 46 MB thì app đứng im. Hai đường hoàn toàn
/// khác nhau, và một con số khởi động đẹp không nói gì về đường còn lại.
///
/// # Vì sao đo THEO CHẶNG chứ không đo một con số tổng
///
/// "Mở tệp mất 8 giây" không sửa được. Cùng con số ấy có thể là đọc đĩa, là dựng chỉ mục dòng,
/// là dò kiểu tệp, là dựng lưới CSV, hay là lượt vẽ đầu tiên — và bốn trong năm chỗ ấy nằm ở
/// những tệp khác nhau do những quyết định khác nhau. Đo tổng rồi đoán chặng là cách chắc chắn
/// để tối ưu nhầm chỗ, đúng bài học đã ghi ở `StartupProbe.preMainMs`.
///
/// # Cuộn đo bằng gì
///
/// Không đo FPS: không có ai kéo chuột trong một lượt chạy không người lái, và một con số FPS
/// tự sinh ra sẽ chỉ đo tốc độ vòng lặp của chính phép đo. Thay vào đó đo **thời gian một lượt
/// nhảy tới vị trí xa rồi bố cục lại** — đó là việc thật mà cuộn bắt máy làm, và nó là thứ
/// quyết định cuộn có giật hay không.
///
/// Mốc: một khung hình ở 60 Hz là **16,7 ms**. Một lượt nhảy vượt ngưỡng ấy là một khung bị bỏ,
/// và người dùng thấy nó thành giật.
enum OpenProbe {

    /// Ngân sách cho một lượt bố cục, tính bằng mili-giây. 60 Hz.
    static let frameBudgetMs = 16.7

    /// Mốc "mở tệp mà không thấy đơ".
    ///
    /// 500 ms là ngưỡng quen thuộc: dưới mức ấy người dùng còn thấy thao tác của mình và kết
    /// quả là một chuyện; trên mức ấy họ bắt đầu tự hỏi máy có nhận không.
    static let openBudgetMs = 500.0

    /// Ngân sách cho một cú NHẢY XA — hai khung hình.
    ///
    /// Rộng hơn cuộn liên tục có lý do, không phải để cho dễ đạt: một cú nhảy buộc nạp lại cả
    /// cửa sổ chữ 2 MB, và riêng lượt dựng ấy đã tốn 5–7 ms (`TextWindowing.defaultSize`).
    /// Nó cũng là thao tác RỜI RẠC — người dùng bấm ⌘↓ một lần rồi nhìn kết quả, chứ không
    /// nhận ra hai khung hình trong lúc kéo liên tục.
    static let jumpBudgetMs = 33.4

    static func run(on controller: MainWindowController, arguments: [String]) -> Never {
        let paths = pathArguments(arguments)
        guard !paths.isEmpty else {
            print("Dùng: GEditorApp --measure-open <tệp> [<tệp>…]")
            exit(2)
        }

        var failures = 0
        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else {
                print("❌ không có tệp: \(path)")
                failures += 1
                continue
            }
            failures += measureOne(controller: controller, path: path) ? 0 : 1
        }

        print(failures == 0
              ? "\n✅ Mọi tệp đều mở và cuộn trong ngân sách"
              : "\n❌ \(failures) tệp vượt ngân sách")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Đo một tệp

    private static func measureOne(controller: MainWindowController, path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        let bytes = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        print("\n── \(name) · \(humanSize(bytes)) ──")

        // Chặng 1 — dò kiểu tệp. Chạy trên MỌI lần mở, kể cả tệp văn bản thuần, nên nó phải rẻ.
        let sniff = time { _ = MediaKind.of(path: path) }

        // Chặng 2 — đọc tệp và dựng chỉ mục dòng, KHÔNG có tầng giao diện nào tham gia.
        var document: Document?
        let load = time { document = try? Document.open(path: path) }
        guard let document else {
            print("   ❌ không mở được")
            return false
        }
        let lines = document.buffer.lineCount

        // Chặng 3 — cả đường mở thật, đúng như khi người dùng bấm. Đây là con số người dùng
        // cảm thấy; hai chặng trên chỉ để biết nó tiêu vào đâu.
        let openAll = time { controller.openInNewTabForSelfTest(path: path) }

        // Chặng 4 — cuộn. Nhảy tới mười vị trí rải đều, kể cả cuối tệp: chỗ đắt nhất của một
        // bố cục lười luôn là chỗ xa nhất chưa ai chạm tới.
        let jumps = measureScroll(controller: controller, lineCount: lines)

        let viewLayer = max(0, openAll - load - sniff)
        print(String(format: "   dò kiểu tệp      %8.1f ms", sniff))
        print(String(format: "   đọc + chỉ mục    %8.1f ms   (%d dòng)", load, lines))
        print(String(format: "   tầng giao diện   %8.1f ms", viewLayer))
        print(String(format: "   ─ TỔNG mở        %8.1f ms   (ngân sách %.0f)", openAll, openBudgetMs))
        print(String(format: "   cuộn liên tục    %8.1f ms   (ngân sách %.1f — một khung hình)",
                     jumps.continuous, frameBudgetMs))
        print(String(format: "   nhảy xa          %8.1f ms   (ngân sách %.1f — có nạp lại cửa sổ)",
                     jumps.jump, jumpBudgetMs))

        var ok = true
        if openAll > openBudgetMs {
            print(String(format: "   ❌ mở chậm gấp %.1f lần ngân sách", openAll / openBudgetMs))
            ok = false
        }
        if jumps.continuous > frameBudgetMs {
            print(String(format: "   ❌ cuộn liên tục tốn %.1f ms — %.1f khung hình bị bỏ mỗi nhịp",
                         jumps.continuous, jumps.continuous / frameBudgetMs))
            ok = false
        }
        if jumps.jump > jumpBudgetMs {
            print(String(format: "   ❌ một cú nhảy xa tốn %.1f ms", jumps.jump))
            ok = false
        }
        if ok { print("   ✅ trong ngân sách") }
        return ok
    }

    /// Đo HAI loại thao tác cuộn, vì chúng có giá khác nhau về bản chất.
    ///
    /// **Cuộn liên tục** — nhích từng màn hình một, không rời cửa sổ chữ đang nạp. Đây là thứ
    /// người dùng làm gần như suốt: lăn chuột, kéo hai ngón, giữ mũi tên xuống. Nó phải nằm
    /// trong MỘT khung hình, nếu không màn hình giật.
    ///
    /// **Nhảy xa** — ⌘↓, kéo thanh cuộn xuống đáy, "Đi tới dòng". Nó buộc nạp lại cả cửa sổ
    /// chữ 2 MB, và riêng lượt dựng cửa sổ ấy đã tốn 5–7 ms. Đòi nó nằm trong một khung hình
    /// là đòi một thứ khác với "cuộn mượt" — và một ngân sách không đạt được sẽ bị người sau
    /// nới ra cho qua, kéo theo cả vế đang canh thật.
    ///
    /// Gộp hai thứ vào một con số là cách chắc chắn để hoặc bỏ lọt giật, hoặc báo đỏ mãi mãi.
    private static func measureScroll(
        controller: MainWindowController, lineCount: Int
    ) -> (continuous: Double, jump: Double) {
        guard lineCount > 1 else { return (0, 0) }

        // ── Cuộn liên tục ──
        // Bắt đầu từ giữa tài liệu để cửa sổ chữ đã nạp sẵn, rồi nhích từng nhịp nhỏ. Bước
        // nhảy tính theo DÒNG chứ không theo byte: đó là đơn vị người dùng cuộn.
        var continuous: [Double] = []
        controller.goTo(line: lineCount / 2, column: nil)
        var line = lineCount / 2
        var cCaret = 0.0, cReveal = 0.0, cStatus = 0.0
        for _ in 0 ..< 30 {
            line = min(lineCount - 1, line + 25)
            var offset = 0
            let a = time { offset = controller.editorDocument.buffer.offset(ofLineStart: line) }
            let b = time { controller.editorView.setCaret(documentOffset: offset) }
            let c = time { controller.editorView.reveal(documentOffset: offset) }
            let d = time { controller.updateCaretStatusForProbe() }
            cCaret += b; cReveal += c; cStatus += d
            continuous.append(a + b + c + d)
        }
        print(String(format: "   liên tục ├ con nháy %6.2f · cuộn %6.2f · status %5.2f ms/nhịp",
                     cCaret / 30, cReveal / 30, cStatus / 30))

        // ── Nhảy xa ──
        var jumps: [Double] = []
        var offsetMs = 0.0, caretMs = 0.0, revealMs = 0.0, statusMs = 0.0
        for step in 0 ... 10 {
            let target = min(lineCount - 1, max(1, lineCount * step / 10))
            var offset = 0
            let a = time { offset = controller.editorDocument.buffer.offset(ofLineStart: target) }
            let b = time { controller.editorView.setCaret(documentOffset: offset) }
            let c = time { controller.editorView.reveal(documentOffset: offset) }
            let d = time { controller.updateCaretStatusForProbe() }
            offsetMs += a; caretMs += b; revealMs += c; statusMs += d
            jumps.append(a + b + c + d)
        }

        let count = Double(jumps.count)
        print(String(format: "   nhảy xa  └ con nháy %6.2f · cuộn %6.2f · status %5.2f ms/lượt",
                     caretMs / count, revealMs / count, statusMs / count))
        _ = offsetMs

        return (continuous.sorted().last ?? 0, jumps.sorted().last ?? 0)
    }

    // MARK: - Trợ giúp

    /// Chạy một khối và trả thời gian tường, tính bằng mili-giây.
    ///
    /// Dùng `mach_absolute_time` chứ không `Date()`: đồng hồ tường có thể bị NTP kéo lùi giữa
    /// hai lần đọc, và khi ấy phép đo ra số âm hoặc một con số vô nghĩa.
    static func time(_ body: () -> Void) -> Double {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let start = mach_absolute_time()
        body()
        let elapsed = mach_absolute_time() - start
        return Double(elapsed) * Double(info.numer) / Double(info.denom) / 1_000_000.0
    }

    private static func pathArguments(_ arguments: [String]) -> [String] {
        guard let index = arguments.firstIndex(of: "--measure-open") else { return [] }
        // Mọi đối số sau cờ, cho tới cờ tiếp theo.
        var result: [String] = []
        for argument in arguments[(index + 1)...] {
            if argument.hasPrefix("--") { break }
            result.append(argument)
        }
        return result
    }

    private static func humanSize(_ bytes: Int) -> String {
        if bytes >= 1_048_576 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.0f KB", Double(bytes) / 1024) }
        return "\(bytes) B"
    }
}
