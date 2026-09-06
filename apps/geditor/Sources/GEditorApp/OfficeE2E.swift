import AppKit
import GEditorCore

/// Đi HẾT đường của người dùng cho mảng ảnh · PDF · Office · file nén (`--office-e2e`).
///
/// **Vì sao cần, khi đã có bài kiểm lõi và bài tự kiểm.** Bài kiểm lõi chạy `XLSXWriter` mà
/// không cần cửa sổ. Bài tự kiểm chạy trong app nhưng phần lớn gọi thẳng vào bộ đọc. Không bộ
/// nào đi hết đường thật:
///
///     mở bằng app → sửa qua buffer → ⌘S → **ĐÓNG TAB** → **MỞ LẠI** → đọc bằng bộ đọc
///
/// Vế "đóng rồi mở lại" là vế hai bộ kia thiếu, và nó bắt đúng loại lỗi hay xảy ra nhất ở tầng
/// nối: ghi thành công vào bộ nhớ mà chưa xuống đĩa, hoặc xuống đĩa rồi mà lần mở sau vẫn đọc
/// bản cũ. Cả hai đều XANH với mọi bài kiểm chỉ nhìn một nửa.
///
/// Chạy dưới `scripts/run-office-e2e.sh`, nơi có thêm đối chứng NGOÀI bằng LibreOffice.
enum OfficeE2E {

    /// Dấu người dùng để lại — đủ lạ để `grep` không trúng thứ khác.
    static let marker = "GEDITOR-E2E"
    static let appendedMarker = "HANG-MOI"

    static func run(controller: MainWindowController, arguments: [String]) -> Never {
        guard let folder = ProcessInfo.processInfo.environment["GEDITOR_E2E_DIR"] else {
            print("Thiếu GEDITOR_E2E_DIR")
            exit(2)
        }

        var failures: [String] = []
        func check(_ name: String, _ body: () -> String?) {
            controller.resetWindowForSelfTest()
            if let reason = body() {
                print("❌ \(name)")
                print("   \(reason)")
                failures.append(name)
            } else {
                print("✅ \(name)")
            }
        }

        check("Ảnh: mở ra khung ảnh, buffer KHÔNG chứa byte nhị phân") {
            let path = (folder as NSString).appendingPathComponent("anh.png")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu anh.png" }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .image else { return "không nhận ra ảnh" }
            guard controller.editorDocument.buffer.count == 0 else {
                return "ảnh bị giải mã thành văn bản"
            }
            guard controller.isMediaViewerVisibleForSelfTest else { return "khung ảnh không hiện" }
            return nil
        }

        check("File nén: liệt kê được mục bên trong") {
            let path = (folder as NSString).appendingPathComponent("bo.zip")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu bo.zip" }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .archive else {
                return "không nhận ra file nén"
            }
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ArchiveViewerView,
                  viewer.rowCountForSelfTest > 0 else { return "danh sách mục rỗng" }
            return nil
        }

        check("TAR.GZ: liệt kê được mục, và mở được mục văn bản") {
            let path = (folder as NSString).appendingPathComponent("kho.tar.gz")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu kho.tar.gz" }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .archive else {
                return "không nhận ra kho tar.gz"
            }
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ArchiveViewerView,
                  viewer.rowCountForSelfTest > 0 else { return "danh sách mục rỗng" }
            guard viewer.entryPathsForSelfTest.contains(where: { $0.hasSuffix("ghi-chu.txt") })
            else { return "không thấy mục mong đợi: \(viewer.entryPathsForSelfTest)" }

            let tabsBefore = controller.tabCountForSelfTest
            guard let index = viewer.entryPathsForSelfTest.firstIndex(where: {
                $0.hasSuffix("ghi-chu.txt")
            }) else { return "không tìm được mục" }
            viewer.selectRowForSelfTest(index)
            viewer.openSelectedForSelfTest()
            guard controller.tabCountForSelfTest == tabsBefore + 1 else {
                return "mở mục trong tar không tạo tab mới"
            }
            guard controller.documentTextForSelfTest.contains("trong kho tar") else {
                return "nội dung mục sai: «\(controller.documentTextForSelfTest.prefix(60))»"
            }
            return nil
        }

        check("7z: liệt kê và mở được mục — qua công cụ nén của hệ điều hành") {
            let path = (folder as NSString).appendingPathComponent("kho.7z")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu kho.7z" }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .archive else {
                return "không nhận ra kho 7z"
            }
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ArchiveViewerView
            else { return "khung con không phải khung file nén" }
            guard let index = viewer.entryPathsForSelfTest.firstIndex(where: {
                $0.hasSuffix("ghi-chu.txt")
            }) else {
                return "không thấy mục trong 7z: \(viewer.entryPathsForSelfTest)"
            }
            viewer.selectRowForSelfTest(index)
            viewer.openSelectedForSelfTest()
            guard controller.documentTextForSelfTest.contains("trong kho 7z") else {
                return "nội dung mục 7z sai: «\(controller.documentTextForSelfTest.prefix(60))»"
            }
            return nil
        }

        check("Excel: mở → sửa ô → THÊM hàng → ⌘S → đóng tab → mở lại") {
            let path = (folder as NSString).appendingPathComponent("bang.xlsx")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu bang.xlsx" }

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .excel else {
                return "không nhận ra bảng tính"
            }
            let before = controller.documentTextForSelfTest
            guard let newline = before.firstIndex(of: "\n") else { return "bảng chỉ có một dòng" }

            // Sửa ô đầu VÀ thêm một hàng ở cuối — hai tính năng trong một lượt.
            var text = marker + before[newline...]
            if !text.hasSuffix("\n") { text += "\n" }
            text += "\(appendedMarker),99,ghi chu moi\n"
            controller.prepareSelfTestEditToDocument(text)
            controller.saveDocumentForSelfTest()

            // ĐÓNG TAB rồi MỞ LẠI — vế mà bài kiểm khác không có.
            controller.closeCurrentTabForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            let after = controller.documentTextForSelfTest
            guard after.hasPrefix(marker) else {
                return "ô đã sửa không còn sau khi mở lại: «\(after.prefix(40))»"
            }
            guard after.contains(appendedMarker) else { return "hàng thêm vào không còn" }
            // Dữ liệu cũ phải nguyên vẹn.
            guard after.contains("Binh") else { return "mất dữ liệu cũ sau khi ghi" }
            return nil
        }

        check("Excel: CHÈN hàng ở GIỮA → ⌘S → đóng tab → mở lại, công thức theo kịp") {
            let path = (folder as NSString).appendingPathComponent("cong-thuc.xlsx")
            // Thiếu fixture là ĐỎ, không phải bỏ qua. Bản đầu trả `nil` ở đây, và lần chạy đầu
            // tiên với tên tệp khác đã cho ra một dấu ✅ hoàn toàn rỗng — bài kiểm tự bỏ qua
            // chính nó, đúng cái bẫy đã gặp ở bài `.pptx`.
            guard FileManager.default.fileExists(atPath: path) else {
                return "thiếu cong-thuc.xlsx"
            }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .excel else {
                return "không nhận ra bảng tính có công thức"
            }
            var lines = controller.documentTextForSelfTest
                .components(separatedBy: "\n").filter { !$0.isEmpty }
            let soHangCu = lines.count
            // Chèn vào GIỮA — sau hàng tiêu đề và hàng dữ liệu đầu tiên.
            guard lines.count >= 3 else { return "bảng quá ngắn để chèn vào giữa" }
            lines.insert("\(appendedMarker),", at: 2)
            controller.prepareSelfTestEditToDocument(lines.joined(separator: "\n") + "\n")
            controller.saveDocumentForSelfTest()

            controller.closeCurrentTabForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            let after = controller.documentTextForSelfTest
                .components(separatedBy: "\n").filter { !$0.isEmpty }
            guard after.count == soHangCu + 1 else {
                return "sau khi chèn có \(after.count) hàng, mong \(soHangCu + 1)"
            }
            guard after[2].hasPrefix(appendedMarker) else {
                return "hàng chèn vào sai chỗ: «\(after[2])»"
            }
            return nil
        }

        check("Word: mở → sửa đoạn → ⌘S → đóng tab → mở lại") {
            let path = (folder as NSString).appendingPathComponent("tai-lieu.docx")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu tai-lieu.docx" }

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .word else {
                return "không nhận ra tài liệu Word"
            }
            var lines = controller.documentTextForSelfTest.components(separatedBy: "\n")
            guard let index = lines.firstIndex(where: {
                !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("|")
            }) else { return "không tìm được đoạn để sửa" }
            lines[index] = "\(marker) da sua doan nay."
            controller.prepareSelfTestEditToDocument(lines.joined(separator: "\n"))
            controller.saveDocumentForSelfTest()

            controller.closeCurrentTabForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            let after = controller.documentTextForSelfTest
            guard after.contains(marker) else {
                return "đoạn đã sửa không còn sau khi mở lại"
            }
            guard after.contains("Tieu de") else { return "mất tiêu đề sau khi ghi" }
            return nil
        }

        check("Word: THÊM đoạn → ⌘S → đóng tab → mở lại") {
            let path = (folder as NSString).appendingPathComponent("tai-lieu.docx")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu tai-lieu.docx" }
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            var lines = controller.documentTextForSelfTest.components(separatedBy: "\n")
            guard let index = lines.firstIndex(where: {
                !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("|")
            }) else { return "không tìm được đoạn mốc" }
            let soDoanCu = lines.filter { !$0.isEmpty }.count
            lines.insert("\(marker)-DOAN-MOI them vao.", at: index + 1)
            controller.prepareSelfTestEditToDocument(lines.joined(separator: "\n"))
            controller.saveDocumentForSelfTest()

            controller.closeCurrentTabForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            let after = controller.documentTextForSelfTest
            guard after.contains("\(marker)-DOAN-MOI") else {
                return "đoạn mới không còn sau khi mở lại"
            }
            let soDoanMoi = after.components(separatedBy: "\n").filter { !$0.isEmpty }.count
            guard soDoanMoi == soDoanCu + 1 else {
                return "sau khi thêm có \(soDoanMoi) dòng, mong \(soDoanCu + 1)"
            }
            return nil
        }

        check("Tài liệu văn bản thường KHÔNG bị đường Office đụng tới") {
            // Đối chứng: mảng tính năng mới không được đổi hành vi của tệp văn bản. Thiếu vế
            // này thì một lỗi ở `openMedia` sẽ làm hỏng chính thứ sản phẩm làm tốt nhất, và
            // không bài nào ở trên thấy.
            let path = (folder as NSString).appendingPathComponent("bang.csv")
            guard FileManager.default.fileExists(atPath: path) else { return "thiếu bang.csv" }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == nil else {
                return "tệp CSV bị nhận nhầm thành media"
            }
            guard !controller.editorDocument.isReadOnly else { return "tệp CSV bị khoá" }
            guard controller.documentTextForSelfTest.contains("Binh") else {
                return "không đọc được nội dung CSV"
            }
            return nil
        }

        print("")
        if failures.isEmpty {
            print("Đạt — vòng mở/sửa/lưu/mở lại chạy hết")
            exit(0)
        }
        print("TRƯỢT \(failures.count): \(failures.joined(separator: " · "))")
        exit(1)
    }
}
