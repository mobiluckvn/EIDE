import AppKit
import GEditorCore

/// `--doc-sweep <thư-mục>` — mở MỌI tệp trong một thư mục qua đúng đường của sản phẩm, rồi báo
/// cáo loại nhận ra, dung lượng đọc được, và thời gian mở.
///
/// ## Vì sao cần, khi đã có bài tự kiểm và bài kiểm lõi
///
/// Cả hai loại kia chạy trên dữ liệu do CHÍNH dự án dựng ra — một PDF bốn trang do CoreGraphics
/// ghi, một `.xlsx` do LibreOffice chuyển từ CSV ba dòng. Chúng kiểm được LUẬT, nhưng không kiểm
/// được thứ mà tài liệu thật mang theo: font nhúng lạ, ảnh 300 dpi, bảng tính có sheet ẩn, tệp
/// 12 MB, chữ tiếng Việt trong tên tệp, PDF xuất từ InDesign, DOCX xuất từ Google Docs.
///
/// Bộ quét này không khẳng định nội dung ĐÚNG — nó không biết tài liệu của người dùng phải chứa
/// gì. Nó khẳng định ba điều yếu hơn nhưng vẫn đáng giá, và cả ba đều là những điều đã hỏng thật
/// ở các sản phẩm cùng loại:
///
/// 1. **Không tệp nào làm sập ứng dụng.**
/// 2. **Không tệp nào bị nhận nhầm loại** — một `.docx` mở ra khung file nén là đã sai.
/// 3. **Không tệp nào mở ra RỖNG** trong khi nó rõ ràng có nội dung.
///
/// Và nó in ra thời gian mở, để nguyên tắc "tệp lớn cỡ nào cũng phải mở nhanh" có con số chứ
/// không có lời hứa.
///
/// **Không sửa gì.** Bộ quét chỉ mở và đọc; không tệp nào trong thư mục bị ghi lại. Thư mục
/// người dùng đưa vào là tài liệu thật của họ.
enum DocumentSweep {

    /// Ngưỡng chậm — quá mức này thì in cảnh báo, không phải lỗi.
    private static let slowMilliseconds = 2000.0

    static func run(controller: MainWindowController, arguments: [String]) -> Never {
        guard let index = arguments.firstIndex(of: "--doc-sweep"), index + 1 < arguments.count else {
            FileHandle.standardError.write(Data("Thiếu thư mục: --doc-sweep <thư-mục>\n".utf8))
            exit(2)
        }
        let folder = arguments[index + 1]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder))?
            .filter { !$0.hasPrefix(".") }
            .sorted()
        guard let names, !names.isEmpty else {
            FileHandle.standardError.write(Data("Không có tệp nào trong \(folder)\n".utf8))
            exit(2)
        }

        print("▸ Quét \(names.count) tệp trong \(folder)\n")
        var problems: [String] = []
        var slow: [String] = []
        var byKind: [String: Int] = [:]
        var builtPages: [String: Int] = [:]
        var printedPages: [String: Int] = [:]

        for name in names {
            let path = (folder as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            if isDirectory.boolValue { continue }

            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
                .flatMap { $0 } ?? 0
            let kind = MediaKind.of(path: path)
            let kindName = kind?.rawValue ?? "văn bản"
            byKind[kindName, default: 0] += 1

            let start = Date()
            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            // Cho vòng lặp chạy: vài đường mở hoãn phần dựng giao diện sang lượt sau.
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            let elapsed = Date().timeIntervalSince(start) * 1000

            var measure = describe(controller: controller, kind: kind)
            // Với PDF, thử luôn tầng công cụ trang trên tài liệu THẬT. Vòng thử này KHÔNG đụng
            // tệp gốc: nó xoay trong bộ nhớ rồi hoàn tác, và trích ra một tệp TẠM rồi xoá.
            if kind == .pdf,
               let viewer = controller.mediaViewer.contentForSelfTest as? PDFViewerView,
               viewer.pageCountForSelfTest > 0 {
                printedPages[name] = viewer.pageCountForSelfTest
            }
            if kind == .pdf, let issue = exercisePageTools(controller: controller, name: name) {
                measure += " · " + issue
            }
            // Với Word và PowerPoint, DỰNG TRANG THẬT trên tệp thật.
            //
            // Mở được tệp và dựng được trang là hai câu hỏi khác nhau, và câu thứ hai đã trả lời
            // sai một lần theo cách khó thấy nhất: khung mở ra, số trang đúng, bề ngang đúng —
            // giấy trắng trơn. Nên ở đây đo tới tận MỰC.
            var pageIssue: String?
            if kind == .word || kind == .powerpoint {
                if let issue = exercisePages(controller: controller) {
                    problems.append("\(name): \(issue)")
                    measure += " · " + issue
                    pageIssue = issue
                } else {
                    measure += " · \(lastPageCount) trang"
                    if kind == .word { builtPages[name] = lastPageCount }
                }
            }
            let flag: String
            if pageIssue != nil {
                flag = "❌"
            } else if let issue = check(controller: controller, kind: kind, measure: measure) {
                problems.append("\(name): \(issue)")
                flag = "❌"
            } else if elapsed > slowMilliseconds {
                slow.append("\(name): \(Int(elapsed)) ms")
                flag = "🐢"
            } else {
                flag = "✅"
            }
            print(String(format: "%@ %-58@ %-11@ %7@  %5d ms  %@",
                         flag, String(name.prefix(58)), kindName,
                         ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file),
                         Int(elapsed), measure))
        }

        reportPagination(built: builtPages, printed: printedPages)

        print("\n── Theo loại ──")
        for (kind, count) in byKind.sorted(by: { $0.key < $1.key }) {
            print("   \(kind): \(count)")
        }
        if !slow.isEmpty {
            print("\n── Chậm hơn \(Int(slowMilliseconds)) ms ──")
            slow.forEach { print("   🐢 \($0)") }
        }
        if problems.isEmpty {
            print("\n✅ \(names.count) tệp: không tệp nào sập, nhận nhầm loại, hay mở ra rỗng")
            exit(0)
        }
        print("\n❌ \(problems.count) tệp có vấn đề")
        problems.forEach { print("   \($0)") }
        exit(1)
    }

    /// Chạy tầng công cụ trang trên một PDF thật. Trả về mô tả lỗi, hoặc `nil` khi mọi thứ đúng.
    ///
    /// Bài tự kiểm chạy vòng này trên một PDF bốn trang do CoreGraphics dựng. Ở đây nó chạy trên
    /// tài liệu thật — 347 trang, font nhúng, ảnh 300 dpi — và đó là chỗ khác nhau đáng giá:
    /// một phép chép trang hỏng với font con hay ảnh CMYK sẽ không lộ ra trên fixture bốn trang.
    private static func exercisePageTools(
        controller: MainWindowController, name: String
    ) -> String? {
        guard let viewer = controller.mediaViewer.contentForSelfTest as? PDFViewerView,
              viewer.pageCountForSelfTest > 0
        else { return "KHÔNG dựng được khung PDF" }

        // 1. Xoay rồi hoàn tác — phải về đúng góc cũ.
        let before = viewer.rotationForSelfTest(page: 0)
        viewer.goToPageForSelfTest(0)
        viewer.rotateForSelfTest(90)
        guard viewer.rotationForSelfTest(page: 0) == before + 90 else { return "XOAY sai" }
        viewer.undoPageEditForSelfTest()
        guard viewer.rotationForSelfTest(page: 0) == before else { return "HOÀN TÁC xoay sai" }

        // 2. Trích trang đầu ra tệp tạm, rồi mở lại kiểm chứng.
        let out = NSTemporaryDirectory() + "sweep-trich-\(UUID().uuidString).pdf"
        defer { try? FileManager.default.removeItem(atPath: out) }
        guard viewer.extractForSelfTest("1", to: out) else { return "TRÍCH không ghi được" }
        guard let lai = PDFViewerView.inspectForSelfTest(out), lai.pages == 1 else {
            return "tệp TRÍCH mở lại không đúng"
        }
        guard viewer.pageCountForSelfTest > 0, !viewer.hasUnsavedPageEditsForSelfTest else {
            return "trích xong mà tài liệu gốc bị đụng"
        }
        return nil
    }

    /// Một dòng mô tả những gì đọc được — đơn vị khác nhau theo từng loại.
    /// Số trang của lần `exercisePages` gần nhất — chỉ để in ra dòng báo cáo.
    private static var lastPageCount = 0

    /// Mở chế độ View của một tệp Word/PowerPoint và đo xem trang có THẬT không.
    ///
    /// Trả về mô tả lỗi, hoặc `nil` nếu trang dựng ra đàng hoàng.
    private static func exercisePages(controller: MainWindowController) -> String? {
        controller.showOfficePreview()
        guard controller.isOfficePreviewVisible else { return "không mở được chế độ trang" }
        defer { controller.hideAllViewModes() }

        let pages = controller.officePreview.pages
        pages.layoutNowForSelfTest()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        pages.layoutNowForSelfTest()
        lastPageCount = pages.pageCountForSelfTest

        guard lastPageCount > 0 else { return "dựng ra 0 trang" }
        let layered = pages.layerBackedAnywhereForSelfTest
        guard layered.isEmpty else { return "bật layer ở \(layered)" }
        let ink = pages.firstPageInkForSelfTest()
        guard ink > 0.002 else { return "tờ giấy đầu trắng (\(Int(ink * 1000))‰)" }
        return nil
    }

    /// Đối chiếu số trang ta dựng với **bản in thật** của cùng cuốn sách.
    ///
    /// Thư mục tài liệu của người dùng thường có cả `.docx` lẫn bản PDF đã đem đi in. Đó là sự
    /// thật gần nhất có được cho câu hỏi *"bản dựng của ta cách bản in bao xa"* — một câu mà
    /// không bài kiểm nào khác trả lời được, vì nó không hỏi đúng hay sai mà hỏi **giống đến
    /// đâu**.
    ///
    /// Đây là CÔNG CỤ ĐO, không phải cổng: thư mục ấy là tệp riêng của người dùng, không nằm
    /// trong kho, nên không thể bắt một lần dựng phải đỏ vì nó.
    ///
    /// **Bản `preview` bị loại.** Nó là bản TRÍCH để xem thử, không phải sách đủ — so với nó ra
    /// 62% và con số ấy chỉ nói rằng ta vừa so hai cuốn khác nhau.
    private static func reportPagination(built: [String: Int], printed: [String: Int]) {
        func stem(_ name: String) -> String {
            var value = (name as NSString).deletingPathExtension.lowercased()
            for junk in ["_kdp", "_interior_6x9", "_full", "_print_interior", "_final",
                         "_grayscale", "_print", "_cuon2", "_book2", "_v2"] {
                value = value.replacingOccurrences(of: junk, with: "")
            }
            return value
        }
        var lookup: [String: Int] = [:]
        for (name, count) in printed where !name.lowercased().contains("preview") {
            lookup[stem(name)] = count
        }

        var rows: [(String, Int, Int, Double)] = []
        for (name, ours) in built {
            guard let theirs = lookup[stem(name)], theirs > 0 else { continue }
            rows.append((name, ours, theirs,
                         Double(ours - theirs) / Double(theirs) * 100))
        }
        guard !rows.isEmpty else { return }

        print("\n── Số trang so với BẢN IN ──")
        for row in rows.sorted(by: { $0.0 < $1.0 }) {
            // Đệm bằng tay: `%-46@` của `String(format:)` KHÔNG đệm chuỗi Swift, nên cả bảng
            // trôi thành một dòng răng cưa không đọc được theo cột.
            let name = String(row.0.prefix(46)).padding(
                toLength: 46, withPad: " ", startingAt: 0)
            print(String(format: "   %@ %4d / %4d  %+6.1f%%", name, row.1, row.2, row.3))
        }
        let average = rows.reduce(0.0) { $0 + abs($1.3) } / Double(rows.count)
        print(String(format: "   %d cặp · lệch tuyệt đối trung bình %.1f%%", rows.count, average))
    }

    private static func describe(controller: MainWindowController, kind: MediaKind?) -> String {
        switch kind {
        case .pdf:
            guard let viewer = controller.mediaViewer.contentForSelfTest as? PDFViewerView
            else { return "không dựng được khung PDF" }
            let fields = viewer.formFieldCountForSelfTest
            return "\(viewer.pageCountForSelfTest) trang"
                + (fields > 0 ? " · \(fields) ô biểu mẫu" : "")
        case .image:
            return controller.mediaViewer.contentForSelfTest is ImageViewerView
                ? "khung ảnh" : "không dựng được khung ảnh"
        case .archive, .audio, .video:
            return controller.mediaViewer.contentForSelfTest == nil
                ? "không dựng được khung" : "khung riêng"
        case .excel, .word, .powerpoint, .none:
            let text = controller.documentTextForSelfTest
            let lines = text.isEmpty ? 0 : text.components(separatedBy: "\n").count
            return "\(lines) dòng · \(text.count) ký tự"
        }
    }

    /// Ba điều bộ quét khẳng định. Trả `nil` khi tệp không có vấn đề gì.
    private static func check(
        controller: MainWindowController, kind: MediaKind?, measure: String
    ) -> String? {
        if measure.hasPrefix("không dựng được") { return measure }
        // Phần do `exercisePageTools` nối vào chỉ có mặt khi CÓ lỗi.
        if measure.contains("KHÔNG dựng được") || measure.contains("sai")
            || measure.contains("không ghi được") || measure.contains("bị đụng") {
            return measure
        }

        switch kind {
        case .pdf:
            guard let viewer = controller.mediaViewer.contentForSelfTest as? PDFViewerView
            else { return "khung con không phải khung PDF" }
            // Một PDF không trang nào là tệp hỏng hoặc bộ đọc hỏng — cả hai đều đáng biết.
            guard viewer.pageCountForSelfTest > 0 else { return "PDF mở ra 0 trang" }
        case .excel, .word, .powerpoint:
            // Ba định dạng Office đi vào KHUNG SOẠN THẢO, không vào khung media. Nếu tệp rơi vào
            // khung media thì bộ đọc đã ném lỗi và đường lùi đã đưa nó về khung file nén — mở
            // được, nhưng không phải thứ người dùng muốn.
            if controller.isMediaViewerVisibleForSelfTest {
                return "\(kind!.rawValue) rơi về khung file nén — bộ đọc đã từ chối tệp này"
            }
            guard !controller.documentTextForSelfTest.isEmpty else {
                return "\(kind!.rawValue) mở ra RỖNG"
            }
        case .image, .archive, .audio, .video:
            guard controller.isMediaViewerVisibleForSelfTest else {
                return "\(kind!.rawValue) không mở vào khung media"
            }
        case .none:
            break
        }
        return nil
    }
}
