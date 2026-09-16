import AppKit
import EIDEKit
import GEditorCore

/// Tự kiểm những đường mà phím giả lập không chạm tới được (`GEditorApp --self-test`).
///
/// Vì sao cần: bộ gõ tiếng Việt đánh dấu MỌI phím, nên gõ qua AppleScript không đi vào đường
/// gõ thường của `NSTextView`; và AppleScript bấm menu thì lúc được lúc không. Kết quả là phần
/// gõ trên nhiều caret nằm ở trạng thái "đã viết nhưng chưa ai kiểm" — trạng thái tệ nhất.
///
/// Cách làm: gọi thẳng `NSTextView.insertText(_:replacementRange:)`. Nó vẫn đi qua ĐÚNG đường
/// AppKit thật (`shouldChangeTextIn` → delegate của ta), chỉ bỏ qua tầng bàn phím và bộ gõ.
/// Nói rõ giới hạn ấy ngay đây: bài này KHÔNG thay được người gõ tay cho TC-IME-02.
enum SelfTest {

    struct Case {
        let name: String

        /// Vì sao bài này KHÔNG chạy được ở môi trường hiện tại. `nil` = chạy được.
        ///
        /// **Vì sao cần một trạng thái thứ ba.** Trước đây chỉ có hai: `nil` là đạt, chuỗi là
        /// trượt. Nên một bài không chạy được — thiếu `clang`, thiếu fixture, sandbox chặn —
        /// chỉ có hai lựa chọn, và cả hai đều nói dối: trả `nil` thì nó hiện ✅ dù chưa kiểm gì,
        /// trả chuỗi thì nó hiện ❌ dù sản phẩm không sai.
        ///
        /// Màu xanh giả là kiểu nói dối nguy hiểm hơn. Nó đã xảy ra thật ở đây: ba bài Office
        /// đọc tệp mẫu trong kho, và trong bundle App Store thì sandbox chặn đường ấy.
        ///
        /// Điều kiện bỏ qua phải kiểm THỨ MÔI TRƯỜNG, không kiểm thứ sản phẩm làm. Nếu chính bộ
        /// tự kiểm đọc được tệp mẫu mà sản phẩm thì không, đó là lỗi sản phẩm và phải đỏ.
        let skipReason: ((MainWindowController) -> String?)?

        let run: (MainWindowController) -> String?   // nil = đạt, chuỗi = lý do trượt

        init(name: String,
             skipWhen skipReason: ((MainWindowController) -> String?)? = nil,
             run: @escaping (MainWindowController) -> String?) {
            self.name = name
            self.skipReason = skipReason
            self.run = run
        }
    }

    static func run(on controller: MainWindowController) -> Int32 {
        // Đệm THEO DÒNG, không theo khối. Khi đầu ra bị chuyển hướng vào tệp, stdout mặc định
        // đệm 4 KB còn NSLog ghi thẳng vào stderr; gộp hai luồng bằng `2>&1` thì mốc xả 4 KB rơi
        // vào GIỮA một ký tự UTF-8 nhiều byte và tệp log thôi hợp lệ từ chỗ ấy trở đi.
        //
        // Hậu quả không phải chuyện thẩm mỹ: `grep` chạy trong locale UTF-8 ngừng khớp các mẫu
        // tiếng Việt sau điểm hỏng, nên `grep "❌"` trả về RỖNG trên một log CÓ dòng trượt. Đó
        // đúng là lý do lần TRƯỢT chập chờn trước không truy ra được tên bài.
        setvbuf(stdout, nil, _IOLBF, 0)

        // `--self-test <cụm>` chỉ chạy những bài có tên chứa `cụm`.
        //
        // Có nó vì một lỗi CHẬP CHỜN 1% không truy được bằng cách chạy cả 360 bài: mỗi lượt mất
        // hơn một phút, nên bắt được nó một lần đã tốn hai giờ. Lọc còn ba bài thì một lượt mất
        // hai giây, và trăm lượt là chuyện của vài phút.
        //
        // Bộ lọc KHÔNG ĐƯỢC im lặng: một cụm gõ sai cho ra "Đạt 0/0" — một dòng xanh nói rằng
        // mọi thứ đều tốt trong khi chưa bài nào chạy.
        let filter = CommandLine.arguments
            .drop(while: { $0 != "--self-test" }).dropFirst().first
            .flatMap { $0.hasPrefix("-") ? nil : $0 }
        let cases = filter.map { needle in
            Self.cases.filter { $0.name.localizedCaseInsensitiveContains(needle) }
        } ?? Self.cases
        if let filter {
            print("▸ Chỉ chạy \(cases.count) bài có tên chứa «\(filter)»")
            if cases.isEmpty {
                print("❌ không bài nào khớp — đừng đọc con số dưới như một lượt chạy sạch")
                return 1
            }
        }

        var failures = 0
        var skipped = 0
        for testCase in cases {
            if let reason = testCase.skipReason?(controller) {
                print("⏭  \(testCase.name)\n   BỎ QUA: \(reason)")
                skipped += 1
                continue
            }
            if let reason = testCase.run(controller) {
                print("❌ \(testCase.name)\n   \(reason)")
                failures += 1
            } else {
                print("✅ \(testCase.name)")
            }
        }
        let passed = cases.count - failures - skipped
        var summary = failures == 0
            ? "\nĐạt \(passed)/\(cases.count)"
            : "\nTRƯỢT \(failures)/\(cases.count)"
        // Số bỏ qua LUÔN hiện, kể cả khi bằng 0. Chỉ in khi khác 0 thì một dòng "Đạt 276/276"
        // và một dòng "Đạt 273/276" trông như nhau với người đọc lướt, và con số bỏ qua âm thầm
        // lớn lên chính là cách một bộ kiểm rỗng dần mà vẫn xanh.
        summary += "  ·  bỏ qua \(skipped)"
        print(summary)
        // Dọn thư mục tạm chỉ khi ĐẠT — trượt thì giữ lại làm bằng chứng (xem `Unattended`).
        if failures == 0 {
            Unattended.removeTemporaryRoots()
            removeTemporaryFolders()
        }
        return failures == 0 ? 0 : 1
    }

    /// Tệp mẫu trong kho có ĐỌC ĐƯỢC từ môi trường hiện tại không.
    ///
    /// Dùng cho `Case.skipWhen`. Đọc THẬT một byte chứ không hỏi `fileExists`: trong sandbox,
    /// `fileExists` vẫn trả `true` cho tệp ngoài vùng chứa — chỉ lệnh đọc mới bị chặn. Bản đầu
    /// của ba bài Office hỏi `fileExists`, đi tiếp, rồi chép hụt trong im lặng vì `try?`, và
    /// bài kiểm báo "không nhận ra bảng tính" — một câu đổ lỗi cho sản phẩm.
    /// Dựng một dự án EIDE thứ hai trong thư mục tạm, hoặc nil nếu không dựng được.
    ///
    /// Hai bước chứ không một: `project.create` KHÔNG chạy migration, và một dự án chưa di trú
    /// thì `EideDuAn.kiem` từ chối — nên bỏ bước `migrate` sẽ làm bài kiểm trượt vì một lý do
    /// không liên quan gì tới thứ nó định kiểm.
    static func duAnThuHai() -> String? {
        guard let py = ProcessInfo.processInfo.environment["EIDE_PYTHON"] else { return nil }
        let tam = NSTemporaryDirectory() + "eide-doi-du-an-" + UUID().uuidString

        func chay(_ arg: [String]) -> (Int32, String) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: py)
            p.arguments = ["-m", "eide.cli"] + arg
            let ra = Pipe()
            p.standardOutput = ra
            p.standardError = ra
            guard (try? p.run()) != nil else { return (-1, "") }
            // Đọc HẾT ống trước `waitUntilExit`: ống có đệm hữu hạn, và một tiến trình con in
            // nhiều hơn đệm sẽ đứng chờ ai đó đọc trong lúc ta đứng chờ nó chết.
            let d = ra.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (p.terminationStatus, String(data: d, encoding: .utf8) ?? "")
        }

        try? FileManager.default.createDirectory(atPath: tam, withIntermediateDirectories: true)
        let (_, out) = chay(["caps", "invoke", "project.create",
                             #"{"text":"dự án thử đổi","chip":"st.stm32f411"}"#, "-p", tam])
        guard let i = out.firstIndex(of: "{"),
              let j = try? JSONSerialization.jsonObject(with: Data(out[i...].utf8)),
              let duong = (j as? [String: Any])?["path"] as? String else { return nil }
        guard chay(["migrate", "-p", duong]).0 == 0 else { return nil }
        return duong
    }

    static func fixtureUnreadable(_ relative: String) -> String? {
        let path = repoFile(relative)
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return "không mở được tệp mẫu \(relative) — sandbox chặn đường ra ngoài vùng chứa"
        }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 1), !head.isEmpty else {
            return "không đọc được tệp mẫu \(relative)"
        }
        return nil
    }

    // MARK: - Dựng plugin thử bằng clang

    /// Biên dịch một dylib plugin ngay lúc chạy bài kiểm.
    ///
    /// **Vì sao dựng chứ không kèm sẵn một dylib trong kho.** Một nhị phân trong kho mã là thứ
    /// không ai đọc được, không ai biết nó chứa gì, và phải dựng lại cho từng kiến trúc. Dựng
    /// tại chỗ thì mã nguồn của plugin nằm ngay dưới đây, đọc được, và luôn khớp kiến trúc máy
    /// đang chạy.
    ///
    /// Trả `nil` khi máy không có `clang` — bài kiểm nói ra và bỏ qua, chứ không đỏ vì một lý
    /// do không liên quan tới sản phẩm.
    static func buildPlugin(named name: String, body: String) -> String? {
        let root = NSTemporaryDirectory() + "geditor-selftest-plugin-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(
            atPath: root, withIntermediateDirectories: true)
        Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))

        let source = root + "/\(name).c"
        let dylib = root + "/lib\(name).dylib"
        guard (try? body.write(toFile: source, atomically: true, encoding: .utf8)) != nil
        else { return nil }

        let clang = Process()
        clang.executableURL = URL(fileURLWithPath: "/usr/bin/clang")
        clang.arguments = ["-O0", "-dynamiclib", "-o", dylib, source]
        clang.standardOutput = FileHandle.nullDevice
        clang.standardError = FileHandle.nullDevice
        guard (try? clang.run()) != nil else { return nil }
        clang.waitUntilExit()
        guard clang.terminationStatus == 0,
              FileManager.default.fileExists(atPath: dylib) else { return nil }
        return dylib
    }

    static let upperCasePlugin = """
        #include <string.h>
        #include <stdint.h>
        static char out[1 << 16];
        const char *geditor_plugin_describe(void) {
            return "{\\"name\\":\\"Hoa hết\\",\\"version\\":\\"1.0\\",\\"apiVersion\\":1,"
                   "\\"commands\\":{\\"upper\\":\\"CHỮ HOA\\",\\"nothing\\":\\"Không đổi\\"}}";
        }
        const char *geditor_plugin_run(const char *command, const char *text,
                                       int32_t start, int32_t end) {
            if (strcmp(command, "nothing") == 0) return 0;
            size_t n = strlen(text);
            if (n >= sizeof(out)) n = sizeof(out) - 1;
            for (size_t i = 0; i < n; i++) {
                char c = text[i];
                int inside = (start < 0) || ((int32_t)i >= start && (int32_t)i < end);
                out[i] = (inside && c >= 'a' && c <= 'z') ? (char)(c - 32) : c;
            }
            out[n] = 0;
            return out;
        }
        """

    static let hangingPlugin = """
        #include <stdint.h>
        const char *geditor_plugin_describe(void) {
            return "{\\"name\\":\\"Treo\\",\\"version\\":\\"1.0\\",\\"apiVersion\\":1,"
                   "\\"commands\\":{\\"hang\\":\\"Treo\\"}}";
        }
        const char *geditor_plugin_run(const char *c, const char *t, int32_t a, int32_t b) {
            for (;;) { }
        }
        """

    static let futureApiPlugin = """
        #include <stdint.h>
        const char *geditor_plugin_describe(void) {
            return "{\\"name\\":\\"Gói tương lai\\",\\"version\\":\\"9.0\\",\\"apiVersion\\":99,"
                   "\\"commands\\":{\\"a\\":\\"A\\"}}";
        }
        const char *geditor_plugin_run(const char *c, const char *t, int32_t a, int32_t b) {
            return 0;
        }
        """

    /// Menu do hệ điều hành tự đổ mục vào — ta không đặt action cho chúng, và không được đòi.
    ///
    /// `Window` do AppKit quản lý (`NSApp.windowsMenu`). Menu ứng dụng chứa mục chuẩn của hệ
    /// như "Ẩn GEditor", còn `Help` trỏ sang trang trợ giúp của bundle.
    static let menusAllowedToBeEmpty: Set<String> = ["Window"]

    /// Dựng một thư mục và một tệp thử, và NÓI RA nếu hỏng.
    ///
    /// Trả `nil` khi mọi thứ ổn, hoặc một câu mô tả lỗi để bài kiểm trả thẳng ra.
    static func dungTepThu(directory: String, file: String, noiDung: String) -> String? {
        do {
            try FileManager.default.createDirectory(
                atPath: directory, withIntermediateDirectories: true)
            try noiDung.write(toFile: file, atomically: true, encoding: .utf8)
        } catch {
            return "DỰNG DỮ LIỆU hỏng, chưa kiểm được gì: \(error)"
        }
        return nil
    }

    /// Phần đuôi giải thích cho mọi thông báo "không có bookmark".
    ///
    /// Ba bài bookmark từng trượt chập chờn với đúng một câu "không có bookmark" — không nói
    /// được tệp còn đó không, `makeBookmark` hỏng vì lý do gì. Truy một lỗi 1/13 lượt bằng một
    /// câu như thế là truy bằng cách đoán. Bốn dữ kiện dưới đây là thứ phân biệt được "tệp biến
    /// mất" với "hệ điều hành từ chối cấp bookmark".
    static func viSaoKhongCoBookmark(_ path: String) -> String {
        var phan: [String] = []
        phan.append(FileManager.default.fileExists(atPath: path) ? "tệp CÒN" : "tệp KHÔNG CÒN")

        // Thử lại TRƯỚC rồi mới đọc `lastFailure`, không phải ngược lại.
        //
        // Thứ tự ngược cho ra một câu vô nghĩa ở đúng ca hay gặp nhất: khi `Document.open` ném
        // vì tệp không còn, `makeBookmark` chưa hề được gọi, nên `lastFailure` rỗng và thông
        // báo nói "chưa từng báo lỗi" — đúng về mặt chữ, vô dụng về mặt truy lỗi. Gọi thử một
        // lần trước thì `lastFailure` chắc chắn mang lý do THẬT của lần hỏng này.
        let lai = SandboxAccess.makeBookmark(for: URL(fileURLWithPath: path))
        phan.append(lai == nil ? "thử lại vẫn HỎNG" : "thử lại thì ĐƯỢC — lỗi nhất thời")
        if let loi = SandboxAccess.lastFailure {
            phan.append("lý do: \(loi)")
        }
        return " — " + phan.joined(separator: " · ")
    }

    /// Những hạng số nhiều mà một thứ tiếng THỰC SỰ sinh ra được.
    ///
    /// Dò bằng cách thử, không bằng cách khai tay một bảng thứ hai: một bảng khai tay sẽ trôi
    /// khỏi `Plural.category` đúng vào ngày ai đó sửa luật, và khi ấy cổng đòi hỏi sai thứ.
    /// Dải 0…200 phủ hết mọi luật đang có — chỗ xa nhất là tiếng Rumani và tiếng Ả Rập, đều
    /// quyết định theo hai chữ số cuối.
    static func hangSinhRaDuoc(_ language: L10n.Language) -> Set<String> {
        Set((0...200).map { Plural.category($0, language).rawValue })
    }

    /// Ruột của mọi nhóm số nhiều `{…=…}` trong một chuỗi.
    ///
    /// Đòi có dấu `=` — cùng luật với `L10n.expandPlurals`, để bài kiểm không đi soi `{init}`
    /// của Mermaid rồi báo đỏ một thứ hoàn toàn đúng.
    static func nhomSoNhieu(_ text: String) -> [String] {
        var ra: [String] = []
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            guard chars[i] == "{" else { i += 1; continue }
            var j = i + 1
            while j < chars.count, chars[j] != "}", chars[j] != "{" { j += 1 }
            if j < chars.count, chars[j] == "}" {
                let than = String(chars[(i + 1)..<j])
                if than.contains("=") { ra.append(than) }
                i = j + 1
            } else {
                i += 1
            }
        }
        return ra
    }

    /// Mục menu ĐÃ BIẾT là chưa có hành động, kèm mã yêu cầu đang nợ nó.
    ///
    /// Danh sách này tồn tại để bài kiểm menu không phải đỏ triền miên trong lúc còn nợ — một
    /// bộ tự kiểm đỏ sẵn thì lỗi mới trượt qua mà không ai để ý. Nhưng nó **tự dọn**: bài kiểm
    /// trượt cả khi một mục ở đây ĐÃ ĐƯỢC nối, nên không ai quên xoá dòng tương ứng, và danh
    /// sách không âm thầm phình ra thành chỗ giấu việc.
    /// Hiện RỖNG: mọi mục menu đều đã có hành động. Giữ lại cơ chế vì mục menu mới hay được
    /// thêm vào trước khi có mã phía sau, và khi ấy nó cần một chỗ khai báo công khai.
    static let menuItemsPendingImplementation: [String: String] = [:]

    /// Mọi mục menu thật, **kể cả trong submenu lồng**, kèm đường dẫn đọc được của nó.
    ///
    /// CÓ MẶT VÌ hai bài kiểm menu trước nay chỉ đi MỘT tầng: chúng duyệt `mainMenu.items` rồi
    /// duyệt `submenu.items`, và dừng ở đó. Ngày 28/08/2026 menu View có submenu lồng đầu tiên
    /// ("Gấp theo cấp", FR-FMT-503) — tám mục ấy sẽ vô hình với cả hai cổng: một mục quên nối
    /// hành động, hay một phím tắt giành mất của lệnh khác, đều lọt.
    ///
    /// Đó đúng là bài học của chính phiên ấy: **cổng chỉ canh được đúng thứ nó soi.** Đệ quy ở
    /// một chỗ dùng chung để lần sau thêm submenu nữa thì không phải nhớ sửa hai bài kiểm.
    static func allMenuItems(under menu: NSMenu, path: String = "") -> [(path: String, item: NSMenuItem)] {
        var out: [(String, NSMenuItem)] = []
        for item in menu.items where !item.isSeparatorItem {
            let here = path.isEmpty ? item.title : "\(path) › \(item.title)"
            if let child = item.submenu {
                out += allMenuItems(under: child, path: here)
            } else {
                out.append((here, item))
            }
        }
        return out
    }

    /// Mục menu giả mang đúng `tag` mà `foldToLevel` đọc.
    ///
    /// Đi qua `NSMenuItem` thật chứ không gọi một hàm nội bộ nhận `Int`: đường mà người dùng
    /// thật sự đi là menu → `tag` → lệnh, và một `tag` quên gán sẽ lọt qua bài kiểm nào bỏ
    /// đoạn ấy đi.
    static func menuItem(level: Int) -> NSMenuItem {
        let item = NSMenuItem()
        item.tag = level
        return item
    }

    // MARK: - Các bài

    static let cases: [Case] = [

        // ---------------------------------------------------------------- Khung EIDE
        //
        // Ba bài dưới đây kiểm CỬA SỔ THẬT, và chúng ở đây vì không bộ test nào khác kiểm được:
        // `MainWindowController` nằm trong target thực thi `GEditorApp`, mà một target thực thi
        // thì không import được từ bộ test. Hệ quả đo được là cả một lớp lỗi từng sống rất lâu —
        // "bấm vào sidebar thì màn nào cũng rỗng" (lỗi im lặng 32) chỉ lộ ra khi có người bật
        // giao diện lên và bấm thử.
        //
        // Ảnh chụp cũng không thay được: `cacheDisplay` KHÔNG vẽ cột điều hướng ra, nên trên ảnh
        // nó là một vùng trong suốt — không phân biệt được "không vẽ được" với "không có".

        Case(name: "EIDE: cột điều hướng có mặt trong cửa sổ, rộng 220") { controller in
            guard let goc = controller.window?.contentView else { return "cửa sổ chưa có contentView" }
            func tim(_ v: NSView) -> NSView? {
                if v.accessibilityLabel() == "Điều hướng màn hình EIDE" { return v }
                for c in v.subviews { if let r = tim(c) { return r } }
                return nil
            }
            guard let dh = tim(goc) else {
                return "không tìm thấy cột điều hướng EIDE trong cây khung nhìn — "
                     + "cửa sổ đang là trình soạn thảo trần, không phải EIDE (DEV-098)"
            }
            // Bề rộng đọc từ ràng buộc chứ không từ `frame`: `frame` chỉ đúng sau một lượt bố
            // cục, và bài này chạy ngay sau khi cửa sổ hiện ra.
            controller.window?.layoutIfNeeded()
            let rong = dh.enclosingScrollView?.frame.width ?? dh.frame.width
            guard rong >= 200 else { return "cột điều hướng rộng \(rong) pt — gần như không thấy" }
            return nil
        },

        Case(name: "EIDE: mở màn Mã nguồn thì cây tệp hiện ra") { controller in
            controller.chonManEide(tien: "Code")
            controller.window?.layoutIfNeeded()
            guard controller.isSidebarVisible else {
                return "vào màn Mã nguồn mà cây tệp vẫn ẩn — người dùng thấy một bộ đệm trống "
                     + "và không có đường nào tới tệp của dự án"
            }
            return nil
        },

        Case(name: "EIDE: mọi màn sidebar mở được, không màn nào làm rơi cửa sổ") { controller in
            // Đi qua HẾT các màn. Bài này bắt đúng dạng lỗi im lặng 32: một màn mở ra rỗng, hoặc
            // một tiền tố trong bảng điều hướng không khớp tiền tố nào trong panel.
            for nhom in EideDieuHuong.NHOM {
                for m in nhom.man {
                    controller.chonManEide(tien: m.tien)
                    controller.window?.layoutIfNeeded()
                    guard controller.window?.contentView != nil else {
                        return "mở màn \(m.nhan) (\(m.tien)) xong thì cửa sổ mất contentView"
                    }
                }
            }
            controller.chonManEide(tien: "Code")
            return nil
        },

        Case(name: "EIDE: đổi dự án ở NGAY trong cửa sổ này, không mở cửa sổ thứ hai") { c in
            guard let cu = c.duAnDangMo else { return "chưa mở dự án nào — không đổi được" }
            guard let moi = duAnThuHai() else {
                return "không dựng được dự án thứ hai để thử (cần EIDE_PYTHON)"
            }
            defer { try? FileManager.default.removeItem(atPath: moi) }

            // Đếm cửa sổ TRƯỚC. Lỗi cần bắt không phải "đổi không được" mà là "đổi được, kèm một
            // cửa sổ thứ hai" — và cái thứ hai thì không ai nhìn thấy trong một bài kiểm chỉ hỏi
            // dự án hiện tại là gì.
            let truoc = NSApp.windows.count
            c.chonManEide(tien: "Passport")
            if let loi = c.doiDuAnEide(moi) { return "đổi dự án hỏng: \(loi)" }

            guard c.duAnDangMo == moi else {
                return "đổi xong mà `duAnDangMo` vẫn là \(c.duAnDangMo ?? "nil")"
            }
            guard NSApp.windows.count == truoc else {
                return "đổi dự án làm số cửa sổ đi từ \(truoc) lên \(NSApp.windows.count) — "
                     + "đây đúng là cửa sổ thứ hai mà DEV-098 bỏ đi"
            }
            // Màn đang xem phải GIỮ NGUYÊN: người đổi dự án lúc đang xem hộ chiếu muốn xem hộ
            // chiếu của dự án mới.
            guard c.eidePanel?.tenManDangMo == "Passport" else {
                return "đổi dự án xong bị ném khỏi màn đang xem, sang "
                     + "\(c.eidePanel?.tenManDangMo ?? "hội thoại")"
            }
            // Cây tệp phải theo sang dự án mới, không ở lại thư mục cũ.
            c.chonManEide(tien: "Code")
            c.window?.layoutIfNeeded()
            guard c.workspaceRootForSelfTest == moi else {
                return "cây tệp còn trỏ \(c.workspaceRootForSelfTest ?? "nil"), trong khi panel "
                     + "đã nói về \(moi)"
            }

            _ = c.doiDuAnEide(cu)      // trả lại dự án ban đầu cho các bài sau
            return nil
        },

        Case(name: "EIDE: cây trên màn Bản đồ cao đúng trần, không co thành vài dòng") { c in
            guard c.coPanelEide else { return "không chạy được `eide daemon`" }
            c.chonManEide(tien: "Graph")
            // Panel gọi daemon rồi mới dựng cây — chờ vòng run loop cho lời gọi ấy về.
            RunLoop.current.run(until: Date().addingTimeInterval(6))
            c.window?.layoutIfNeeded()

            func tim(_ v: NSView) -> NSView? {
                if v is EideCayView { return v }
                for s in v.subviews { if let r = tim(s) { return r } }
                return nil
            }
            guard let goc = c.window?.contentView, let cay = tim(goc) else {
                return "không thấy cây nào trên màn Bản đồ — `view.kg_map` chưa về, hoặc kết quả "
                     + "lại bị đổ sang khung nhìn khác"
            }
            // Ảnh chụp 15/09/2026 cho thấy khung cây chỉ khoảng 100 pt, trong khi trần là 420 và
            // test đơn vị đo được 420. Bài này nói chắc bên nào đúng trên cửa sổ THẬT.
            guard cay.frame.height >= EideTuVung.caoToiDa - 1 else {
                return "cây cao \(Int(cay.frame.height)) pt, trần là \(Int(EideTuVung.caoToiDa))"
            }
            return nil
        },

        Case(name: "EIDE: kiểm kê 23 màn — màn nào mở ra RỖNG") { c in
            guard c.coPanelEide, let panel = c.eidePanel else {
                return "không chạy được `eide daemon`"
            }
            // Đi qua HẾT các màn trên điều hướng, mở từng cái bằng đúng đường người dùng đi, chờ
            // daemon trả lời, rồi ĐẾM xem thân màn có gì.
            //
            // Bài này không khẳng định màn nào phải có bao nhiêu dòng — nó in ra một bảng kiểm
            // kê. Khẳng định duy nhất: KHÔNG màn nào được vừa rỗng vừa im. Một màn rỗng mà nói
            // ra lý do ("cần board", "chưa có tài liệu") là một màn trung thực; một màn rỗng
            // không nói gì là lỗi im lặng số 21, 32 và 41 quay lại.
            var rong: [String] = []
            var bang: [(String, Int, String)] = []
            for nhom in EideDieuHuong.NHOM {
                for m in nhom.man where m.tien != "Code" {
                    c.chonManEide(tien: m.tien)
                    _ = panel.moMan(m.tien)
                    RunLoop.current.run(until: Date().addingTimeInterval(1.2))
                    c.window?.layoutIfNeeded()
                    let d = panel.kiemKeManDangMo()
                    bang.append((m.nhan, d.soDong, d.khoi))
                    if d.soDong == 0 && d.khoi.isEmpty && !d.coChu { rong.append(m.nhan) }
                }
            }
            print("   ┌─ kiểm kê màn ──────────────────────────────────────────")
            for (ten, so, khoi) in bang {
                print(String(format: "   │ %-22@ %3d dòng  %@",
                             ten as NSString, so, khoi as NSString))
            }
            print("   └────────────────────────────────────────────────────────")
            guard rong.isEmpty else {
                return "màn mở ra RỖNG và không nói lý do: \(rong.joined(separator: ", "))"
            }
            return nil
        },

        Case(name: "EIDE: mở tệp mã thì LỀ có dấu fact và dấu vi phạm") { c in
            guard let goc = ProcessInfo.processInfo.environment["EIDE_PROJECT"] else {
                return "chưa đặt EIDE_PROJECT"
            }
            let nguon = (goc as NSString).appendingPathComponent("src")
            guard let ten = (try? FileManager.default.contentsOfDirectory(atPath: nguon))?
                .filter({ $0.hasSuffix(".c") }).sorted().first else {
                return "dự án chưa có src/*.c"
            }
            let tep = (nguon as NSString).appendingPathComponent(ten)
            guard let noi = try? String(contentsOfFile: tep, encoding: .utf8),
                  noi.contains("eide:fact") else {
                return "tệp \(ten) không có chú thích `eide:fact` để kiểm"
            }

            c.chonManEide(tien: "Code")
            c.moTepTuCay(tep)
            // Chú thích fact chấm NGAY (đọc từ văn bản); vi phạm phải chờ daemon.
            RunLoop.current.run(until: Date().addingTimeInterval(6))

            let dau = c.editorView.dauEideDeTest()
            let coFact = dau.values.filter { if case .coFact = $0 { return true }; return false }
            let viPham = dau.values.filter { if case .viPham = $0 { return true }; return false }
            guard !coFact.isEmpty else {
                return "mở \(ten) mà lề KHÔNG có dấu fact nào, trong khi tệp có `eide:fact`"
            }
            print("   \(ten): \(coFact.count) dòng có fact · \(viPham.count) dòng vi phạm")
            // Không khẳng định SỐ vi phạm: nó tuỳ store của dự án. Khẳng định rằng đường đi
            // tới daemon có chạy — tệp mẫu có hằng số trần thì phải ra ít nhất một vi phạm.
            guard !viPham.isEmpty else {
                return "không có dấu vi phạm nào — `code.constant_guard` chưa về tới lề"
            }
            return nil
        },

        Case(name: "gõ một ký tự trên ba vùng chọn") { controller in
            controller.prepareSelfTestDocument("ERROR một\nOK hai\nERROR ba\n")
            controller.selectAllOccurrencesForSelfTest("ERROR")
            controller.typeForSelfTest("X")
            return expect(controller, "X một\nOK hai\nX ba\n")
        },

        /// Thanh trạng thái phải DÙNG LẠI view của nó, không dựng lại ở mỗi lần đổi.
        ///
        /// Không phải chuyện gọn gàng. Mỗi `NSButton` mới kéo theo một chùm đăng ký KVO của
        /// AppKit không bao giờ được thu lại, và thanh này đổi sau mỗi lần sửa lẫn mỗi lần con
        /// nháy nhúc nhích — bộ chạy dài `--soak` đo được 226.000 đối tượng KVO đọng lại sau
        /// 4.000 thao tác, bộ nhớ leo tới 191 MB (NFR-REL-03, trần nhàn rỗi 80 MB).
        ///
        /// Kiểm CẢ HAI vế. "View không đổi" một mình là mệnh đề mà một thanh trạng thái chết
        /// cứng cũng thoả — nên bài này đòi chữ phải cập nhật thật.
        Case(name: "thanh trạng thái dùng lại view thay vì dựng lại") { controller in
            controller.prepareSelfTestDocument("aaa\nbbb\nccc\n")
            controller.setCaretForSelfTest(documentOffset: 0)
            let before = controller.statusSegmentsForSelfTest
            let caretBefore = before.first { $0.name == "caret" }?.title ?? ""

            for character in "abcdefghij" { controller.typeForSelfTest(String(character)) }
            controller.setCaretForSelfTest(documentOffset: controller.editorDocument.buffer.count)

            let after = controller.statusSegmentsForSelfTest
            let identitiesBefore = before.map(\.identity)
            let identitiesAfter = after.map(\.identity)
            guard identitiesBefore == identitiesAfter else {
                return "thanh trạng thái đã dựng lại view: \(identitiesBefore.count) mục trước, "
                    + "\(identitiesAfter.count) sau, danh tính khác nhau"
            }
            let caretAfter = after.first { $0.name == "caret" }?.title ?? ""
            guard caretAfter != caretBefore else {
                return "chữ ở mục caret không đổi sau khi gõ và dời con nháy: "
                    + String(reflecting: caretAfter)
            }
            return nil
        },

        /// Thanh tab cũng phải DÙNG LẠI nút của nó — nguồn rò thứ hai, cùng mẫu với thanh
        /// trạng thái. Đổi tab qua lại không được đẻ ra nút mới.
        ///
        /// Kiểm cả vế "vẫn chạy đúng": tab đang mở phải đổi thật, không thì một thanh tab chết
        /// cứng cũng thoả mệnh đề đầu.
        /// Nửa đang gõ phải hiện ĐÚNG tài liệu mà lệnh sửa nhắm tới — kể cả sau khi danh sách
        /// tab ngắn lại dưới chân nó.
        ///
        /// Chỉ số tab của mỗi nửa được phép giữ giá trị quá tầm sau khi đóng bớt tab; chỉ getter
        /// `activeIndex` là tự kẹp khi ĐỌC. Nên `editorDocument` đọc ra một tài liệu (đã kẹp)
        /// trong khi view vẫn hiện tài liệu khác. Hậu quả không phải hiện sai chữ: `onEdit` tính
        /// vùng sửa trên buffer của VIEW rồi áp lên buffer của TÀI LIỆU.
        ///
        /// Bộ chạy dài `--soak` bắt được ở hạt giống 1234 (NFR-REL-03) — hạt cuối cùng còn đỏ
        /// sau khi đã sửa bốn lỗi khác cùng họ.
        Case(name: "nửa đang gõ hiện đúng tài liệu sau khi đóng bớt tab") { controller in
            controller.resetTabsForSelfTest()
            for _ in 0 ..< 4 { controller.newTab(nil) }
            controller.splitForSelfTest(vertical: false)
            // Đưa mỗi nửa tới một tab khác nhau, rồi đóng cho tới khi chỉ số của nửa kia quá tầm.
            controller.activateTabForSelfTest(controller.tabCountForSelfTest - 1)
            while controller.tabCountForSelfTest > 1 {
                controller.closeCurrentTabForSelfTest()
            }
            controller.focusPaneForSelfTest(1)
            guard controller.panesInSyncForSelfTest else {
                return "nửa đang gõ hiện một buffer khác với tài liệu của nó — "
                    + "chỉ số \(controller.paneTabIndicesForSelfTest), "
                    + "\(controller.tabCountForSelfTest) tab"
            }
            // Và gõ được thật, không sập: đây mới là thứ người dùng chạm tới.
            controller.typeForSelfTest("x")
            return controller.documentTextForSelfTest.contains("x")
                ? nil : "gõ vào nửa đang hoạt động không tới được tài liệu"
        },

        // MARK: - Plugin native ở tiến trình riêng (FR-PLUG-702/703, ADR-12)
        //
        // Ba bài dưới đây dựng plugin THẬT bằng `clang` rồi cho app nạp qua tiến trình phụ. Giả
        // lập cầu nối thì chỉ kiểm lại chính đoạn giả lập; thứ đáng kiểm ở đây — `dlopen` có
        // qua được library validation không, ống có giữ đúng biên thông điệp không, plugin treo
        // có bị cắt không — chỉ hiện ra khi có tiến trình thật.

        Case(name: "plugin native: khai tên và biến đổi văn bản") { controller in
            // Bản App Store cố ý KHÔNG có plugin native (ADR-12). Ở đó bài này vẫn kiểm một
            // mệnh đề — rằng nó từ chối ĐÚNG CÁCH — chứ không bỏ qua im lặng: một nhánh "bỏ
            // qua" là một bài kiểm có thể không kiểm gì cả.
            guard NativePluginRegistry.shared.isSupported else {
                let bridge = NativePluginBridge(url: URL(fileURLWithPath: "/khong/co/that.dylib"))
                defer { bridge.close() }
                do {
                    _ = try bridge.describe()
                    return "bản App Store mà plugin native vẫn chạy được"
                } catch let error as NativePluginBridge.Failure {
                    return error == .notAvailable ? nil : "từ chối sai lý do: \(error)"
                } catch {
                    return "từ chối sai kiểu: \(error)"
                }
            }
            guard let plugin = SelfTest.buildPlugin(named: "hoa", body: SelfTest.upperCasePlugin)
            else { return "không dựng được plugin thử (cần clang)" }
            defer { try? FileManager.default.removeItem(atPath: plugin) }

            let bridge = NativePluginBridge(url: URL(fileURLWithPath: plugin))
            defer { bridge.close() }
            do {
                let manifest = try bridge.describe()
                guard manifest.name == "Hoa hết" else { return "tên sai: \(manifest.name)" }
                guard manifest.commands["upper"] != nil else { return "thiếu lệnh upper" }

                let out = try bridge.run(command: "upper", text: "abcdef", selection: 2 ..< 4)
                guard out == "abCDef" else {
                    return "plugin không tôn trọng vùng chọn: \(String(reflecting: out))"
                }
                // "Không đổi gì" phải về đúng như thế, KHÁC hẳn chuỗi rỗng — nếu không thì mỗi
                // lần chạy một plugin chỉ-xem là một bước hoàn tác rỗng.
                guard try bridge.run(command: "nothing", text: "abc", selection: nil) == nil else {
                    return "\"không đổi gì\" phải trả nil"
                }
                return nil
            } catch {
                return "gọi plugin hỏng: \(error.localizedDescription)"
            }
        },

        Case(name: "plugin native treo bị CẮT, app vẫn sống") { controller in
            // Bản App Store cố ý KHÔNG có plugin native (ADR-12). Ở đó bài này vẫn kiểm một
            // mệnh đề — rằng nó từ chối ĐÚNG CÁCH — chứ không bỏ qua im lặng: một nhánh "bỏ
            // qua" là một bài kiểm có thể không kiểm gì cả.
            guard NativePluginRegistry.shared.isSupported else {
                let bridge = NativePluginBridge(url: URL(fileURLWithPath: "/khong/co/that.dylib"))
                defer { bridge.close() }
                do {
                    _ = try bridge.describe()
                    return "bản App Store mà plugin native vẫn chạy được"
                } catch let error as NativePluginBridge.Failure {
                    return error == .notAvailable ? nil : "từ chối sai lý do: \(error)"
                } catch {
                    return "từ chối sai kiểu: \(error)"
                }
            }
            guard let plugin = SelfTest.buildPlugin(named: "treo", body: SelfTest.hangingPlugin)
            else { return "không dựng được plugin thử (cần clang)" }
            defer { try? FileManager.default.removeItem(atPath: plugin) }

            let bridge = NativePluginBridge(url: URL(fileURLWithPath: plugin))
            defer { bridge.close() }
            let started = Date()
            do {
                _ = try bridge.run(command: "hang", text: "x", selection: nil)
                return "plugin lặp vô hạn mà lời gọi vẫn trả về bình thường — hạn giờ không chạy"
            } catch let error as NativePluginBridge.Failure {
                guard error == .timedOut else { return "phải là timedOut, nhận \(error)" }
            } catch {
                return "lỗi sai kiểu: \(error)"
            }
            // Buộc vào CHÍNH hằng số của cầu nối, không vào một con số chép tay.
            //
            // Bản đầu ghi cứng 20 giây ("5 giây cộng rộng tay"). Khi hạn giờ được nới lên dưới
            // bản dựng có thiết bị đo, con số 20 ấy thành ra đúng bằng hạn — và bài kiểm đỏ ở
            // mọi lượt chạy độ phủ. Điều bài này thật sự muốn khẳng định là *"cầu nối cắt ĐÚNG
            // hạn nó tự khai, chứ không chờ mãi"*, nên nó phải đọc hạn ấy chứ không đoán.
            let limit = NativePluginBridge.timeout + 15
            let waited = Date().timeIntervalSince(started)
            guard waited < limit else {
                return String(format: "cắt quá muộn: %.1f giây (hạn %.0f)", waited, limit)
            }
            return nil
        },

        Case(name: "plugin native khai API mới hơn thì bị TỪ CHỐI, kèm lý do") { controller in
            // Bản App Store cố ý KHÔNG có plugin native (ADR-12). Ở đó bài này vẫn kiểm một
            // mệnh đề — rằng nó từ chối ĐÚNG CÁCH — chứ không bỏ qua im lặng: một nhánh "bỏ
            // qua" là một bài kiểm có thể không kiểm gì cả.
            guard NativePluginRegistry.shared.isSupported else {
                let bridge = NativePluginBridge(url: URL(fileURLWithPath: "/khong/co/that.dylib"))
                defer { bridge.close() }
                do {
                    _ = try bridge.describe()
                    return "bản App Store mà plugin native vẫn chạy được"
                } catch let error as NativePluginBridge.Failure {
                    return error == .notAvailable ? nil : "từ chối sai lý do: \(error)"
                } catch {
                    return "từ chối sai kiểu: \(error)"
                }
            }
            guard let plugin = SelfTest.buildPlugin(named: "moi", body: SelfTest.futureApiPlugin)
            else { return "không dựng được plugin thử (cần clang)" }
            defer { try? FileManager.default.removeItem(atPath: plugin) }

            let bridge = NativePluginBridge(url: URL(fileURLWithPath: plugin))
            defer { bridge.close() }
            do {
                _ = try bridge.describe()
                return "plugin khai API 99 mà vẫn được nhận"
            } catch let error as NativePluginBridge.Failure {
                guard case let .plugin(message) = error else { return "lỗi sai kiểu: \(error)" }
                // Lời từ chối phải nói ĐỦ để người dùng biết cập nhật cái nào.
                guard message.contains("99") else { return "không nói plugin cần API nào: \(message)" }
                return nil
            } catch {
                return "lỗi sai kiểu: \(error)"
            }
        },

        /// Vòng đời đầy đủ theo FR-PLUG-704: CÀI → thấy trong danh sách → CHẠY trên tài liệu
        /// → GỠ → biến khỏi danh sách.
        ///
        /// Kiểm cả mệnh đề mà SEC-03 đòi: danh sách suy ra TỪ ĐĨA. Nên bài này gỡ bằng cách
        /// **xoá file** rồi hỏi lại danh sách — nếu ở đâu đó có một cuốn sổ đăng ký thì bước ấy
        /// sẽ lộ ra ngay, vì cuốn sổ không biết file vừa bị xoá.
        Case(name: "plugin native: cài, chạy trên tài liệu, rồi gỡ") { controller in
            let registry = NativePluginRegistry.shared
            guard registry.isSupported else { return nil }   // bản App Store: không có tính năng
            registry.useTemporaryDirectoryForSelfTest()
            defer { registry.closeAll() }

            guard let built = SelfTest.buildPlugin(named: "hoa2", body: SelfTest.upperCasePlugin)
            else { return "không dựng được plugin thử (cần clang)" }

            let installed: NativePluginRegistry.Installed
            do {
                installed = try registry.install(from: URL(fileURLWithPath: built))
            } catch {
                return "cài hỏng: \(error.localizedDescription)"
            }
            guard registry.installed().contains(installed) else {
                return "cài xong mà không thấy trong danh sách"
            }

            // DUYỆT trước khi chạy (NFR-SEC-03). Bước này thay cho cú bấm "Tôi tin file này"
            // của người dùng — bài kiểm phải đi qua đúng cánh cổng ấy, không được vòng qua.
            do { try registry.approve(installed.url) } catch {
                return "không ghi được sổ duyệt: \(error.localizedDescription)"
            }

            // Bản khai đọc được, và lệnh của nó chạy được trên tài liệu thật.
            let described = registry.describeAll()
            guard described.count == 1, let manifest = described[0].manifest else {
                return "không đọc được bản khai: \(described.first?.failure ?? "?")"
            }
            guard manifest.commands["upper"] != nil else { return "thiếu lệnh upper" }

            controller.prepareSelfTestDocument("abc\n")
            let depth = controller.editorDocument.buffer.undoDepth
            controller.runNativePlugin(installed, command: "upper", label: "Thử")
            guard controller.documentTextForSelfTest == "ABC\n" else {
                return "plugin không đổi được tài liệu: "
                    + String(reflecting: controller.documentTextForSelfTest)
            }
            // MỘT bước hoàn tác, như mọi thao tác khác.
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "phải là đúng một bước hoàn tác, nhận "
                    + "\(controller.editorDocument.buffer.undoDepth - depth)"
            }

            // Gỡ = xoá file. Danh sách phải theo ĐĨA.
            do { try registry.remove(installed) } catch {
                return "gỡ hỏng: \(error.localizedDescription)"
            }
            guard registry.installed().isEmpty else {
                return "gỡ rồi mà danh sách vẫn còn — ở đâu đó có một cuốn sổ đăng ký"
            }
            return nil
        },

        /// Plugin HỎNG vẫn phải hiện trong danh sách, kèm lý do.
        ///
        /// Một plugin biến mất khỏi bảng vì nó lỗi là cách chắc chắn để người dùng không hiểu
        /// chuyện gì đang xảy ra — và cũng không biết đường gỡ nó ra.
        Case(name: "plugin native hỏng vẫn hiện trong danh sách, kèm lý do") { controller in
            let registry = NativePluginRegistry.shared
            guard registry.isSupported else { return nil }
            registry.useTemporaryDirectoryForSelfTest()
            defer { registry.closeAll() }

            // Một file .dylib không phải dylib: `dlopen` sẽ từ chối.
            let fake = registry.directory.appendingPathComponent("librac.dylib")
            try? FileManager.default.createDirectory(
                at: registry.directory, withIntermediateDirectories: true)
            guard (try? Data("không phải mã máy".utf8).write(to: fake)) != nil else {
                return "không ghi được file thử"
            }

            let described = registry.describeAll()
            guard described.count == 1 else { return "phải thấy đúng một mục" }
            guard described[0].manifest == nil, let failure = described[0].failure else {
                return "file rác mà vẫn đọc được bản khai"
            }
            guard !failure.isEmpty else { return "hỏng mà không nói lý do" }
            return nil
        },

        /// Bảng quản lý phải phản ánh đúng ĐĨA — kể cả plugin hỏng.
        ///
        /// Đây là mệnh đề SEC-03 đòi nhìn thấy được: người dùng phải biết đang có gì, nó nằm ở
        /// đâu, và gỡ thế nào. Bài kiểm soi menu ĐÃ DỰNG chứ không bung nó ra — `NSMenu.popUp`
        /// chạy một vòng theo dõi chuột, đúng họ với `runModal` đã treo bộ tự kiểm hai lần.
        Case(name: "plugin BỊ THAY sau khi duyệt thì bị TỪ CHỐI, không hỏi lại (NFR-SEC-03)") { controller in
            // Đây là hình dạng của một cuộc tấn công chuỗi cung ứng, và là lý do chính khiến
            // sổ duyệt ghi HASH chứ không chỉ ghi tên file: người dùng đã nói "tôi tin file
            // này", họ chưa nói "tôi tin mọi file sẽ nằm ở chỗ này về sau".
            let registry = NativePluginRegistry.shared
            guard registry.isSupported else { return nil }
            registry.useTemporaryDirectoryForSelfTest()
            defer { registry.closeAll() }

            guard let built = SelfTest.buildPlugin(named: "thay1", body: SelfTest.upperCasePlugin),
                  let cai = try? registry.install(from: URL(fileURLWithPath: built))
            else { return "không cài được plugin thử" }
            do { try registry.approve(cai.url) } catch { return "không duyệt được" }

            // Đã duyệt thì chạy được — nửa này là ĐỐI CHỨNG: không có nó thì phần dưới xanh kể
            // cả khi cổng chặn nhầm mọi thứ.
            controller.prepareSelfTestDocument("abc\n")
            controller.runNativePlugin(cai, command: "upper", label: "Thử")
            guard controller.documentTextForSelfTest == "ABC\n" else {
                return "plugin ĐÃ DUYỆT mà không chạy được: "
                    + String(reflecting: controller.documentTextForSelfTest)
            }

            // THAY file bằng một bản khác, giữ nguyên tên. Đóng cầu nối trước, nếu không thì
            // tiến trình cũ vẫn sống và bài kiểm đo lại chính bản đã nạp.
            registry.closeAll()
            guard let banKhac = SelfTest.buildPlugin(named: "thay2", body: SelfTest.upperCasePlugin),
                  let data = FileManager.default.contents(atPath: banKhac)
            else { return "không dựng được bản thay thế" }
            // Thêm vài byte để hash khác đi mà file vẫn là một dylib chạy được — nếu chỉ đổi
            // sang một bản dylib khác thì có thể tình cờ trùng byte.
            try? (data + Data(repeating: 0x00, count: 16)).write(to: cai.url)

            controller.prepareSelfTestDocument("abc\n")
            controller.runNativePlugin(cai, command: "upper", label: "Thử")
            guard controller.documentTextForSelfTest == "abc\n" else {
                return "plugin ĐÃ BỊ THAY mà vẫn chạy được — cổng NFR-SEC-03 thủng"
            }
            // Và phải là TỪ CHỐI, không phải một câu hỏi: người dùng không có cách nào trả lời
            // đúng câu "file này vừa đổi, anh có tin không?".
            guard let hoi = Unattended.lastPrompt, hoi.contains("từ chối") else {
                return "không hiện cảnh báo 'đã đổi': \(Unattended.lastPrompt ?? "(không có)")"
            }
            return nil
        },

        Case(name: "bảng quản lý plugin native phản ánh đúng đĩa") { controller in
            let registry = NativePluginRegistry.shared
            guard registry.isSupported else { return nil }
            registry.useTemporaryDirectoryForSelfTest()
            defer { registry.closeAll() }

            // Chưa cài gì: phải nói ra, không để menu trống trơn.
            let empty = controller.makeNativePluginMenu()
            guard empty.items.contains(where: { $0.title.contains("Chưa cài") }) else {
                return "menu rỗng không nói 'chưa cài gì'"
            }

            guard let built = SelfTest.buildPlugin(named: "hoa3", body: SelfTest.upperCasePlugin),
                  let cai = try? registry.install(from: URL(fileURLWithPath: built))
            else { return "không cài được plugin thử" }

            // CHƯA duyệt: menu phải hiện plugin kèm cảnh báo, KHÔNG hiện tên lệnh của nó — vì
            // đọc được tên lệnh nghĩa là đã chạy mã chưa duyệt để lấy hai dòng chữ ấy.
            let chuaDuyet = controller.makeNativePluginMenu().items.map(\.title)
            guard !chuaDuyet.contains(where: { $0.contains("Hoa hết") }) else {
                return "plugin CHƯA DUYỆT mà menu đã đọc được lệnh của nó — cổng NFR-SEC-03 thủng"
            }

            do { try registry.approve(cai.url) } catch {
                return "không ghi được sổ duyệt: \(error.localizedDescription)"
            }
            registry.closeAll()

            let menu = controller.makeNativePluginMenu()
            let titles = menu.items.map { $0.title }
            guard titles.contains(where: { $0.contains("Hoa hết") }) else {
                return "không thấy tên plugin trong menu: \(titles)"
            }
            guard titles.contains(where: { $0.contains("CHỮ HOA") }) else {
                return "không thấy lệnh của plugin trong menu: \(titles)"
            }
            // ĐƯỜNG DẪN phải nhìn thấy được — đó là câu trả lời "cài từ đâu, gỡ thế nào".
            guard menu.items.contains(where: { ($0.toolTip ?? "").contains("hoa3") }) else {
                return "menu không cho biết plugin nằm ở đâu"
            }
            guard menu.items.contains(where: { $0.title.contains("Gỡ") }) else {
                return "menu không có đường gỡ"
            }
            return nil
        },

        /// Lưu nhiều lần → duyệt được bản cũ → khôi phục → **hoàn tác được** (FR-DOC-305).
        ///
        /// Mệnh đề cuối mới là mệnh đề đáng giữ. Khôi phục mà không hoàn tác được thì chính
        /// tính năng cứu dữ liệu lại là chỗ làm mất dữ liệu: chọn nhầm bản là mất phần đang sửa.
        Case(name: "duyệt và khôi phục bản đã lưu, có hoàn tác") { controller in
            guard let path = controller.openSelfTestFile("bản 1 — Nguyễn\n", extension: "txt")
            else { return "không dựng được file thử" }

            for text in ["bản 2 — Trần\n", "bản 3 — Lê\n"] {
                controller.setSelectionForSelfTest(
                    documentRange: 0 ..< controller.editorDocument.buffer.count)
                controller.typeForSelfTest(text)
                controller.saveDocument(nil)
            }

            let menu = controller.makeDocumentVersionsMenu()
            let entries = menu.items.filter { $0.action != nil }
            guard entries.count >= 2 else {
                return "phải thấy ít nhất hai bản cũ, thấy \(entries.count)"
            }
            // Mục cũ NHẤT nằm cuối — danh sách sắp mới trước.
            guard let oldest = entries.last else { return "không có mục nào" }

            let before = controller.documentTextForSelfTest
            let depth = controller.editorDocument.buffer.undoDepth
            _ = oldest.target?.perform(oldest.action, with: oldest)

            let restored = controller.documentTextForSelfTest
            guard restored != before else { return "khôi phục không đổi gì" }
            guard restored.contains("bản 1") else {
                return "khôi phục sai bản: \(String(reflecting: restored))"
            }
            // MỘT bước hoàn tác, và hoàn tác về đúng chỗ cũ.
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "phải là đúng một bước hoàn tác"
            }
            _ = controller.editorDocument.buffer.undo()
            guard controller.documentTextForSelfTest == before else {
                return "hoàn tác không về nguyên trạng"
            }
            return nil
        },

        Case(name: "thanh tab dùng lại nút thay vì dựng lại") { controller in
            controller.resetTabsForSelfTest()
            controller.newTab(nil)
            controller.newTab(nil)
            let before = controller.tabButtonIdentitiesForSelfTest
            guard before.count >= 2 else { return "cần ít nhất hai tab, có \(before.count)" }

            for _ in 0 ..< 10 {
                for index in 0 ..< controller.tabCountForSelfTest {
                    controller.activateTabForSelfTest(index)
                }
            }
            let after = controller.tabButtonIdentitiesForSelfTest
            guard before == after else {
                return "thanh tab đã dựng lại nút sau khi đổi tab qua lại "
                    + "(\(before.count) nút trước, \(after.count) sau)"
            }
            controller.activateTabForSelfTest(0)
            guard controller.activeTabIndexForSelfTest == 0 else {
                return "đổi tab không có tác dụng: đang ở tab "
                    + "\(controller.activeTabIndexForSelfTest)"
            }
            return nil
        },

        Case(name: "gõ nhiều ký tự liên tiếp trên ba vùng chọn") { controller in
            controller.prepareSelfTestDocument("ERROR một\nOK hai\nERROR ba\n")
            controller.selectAllOccurrencesForSelfTest("ERROR")
            for character in "LOI" { controller.typeForSelfTest(String(character)) }
            return expect(controller, "LOI một\nOK hai\nLOI ba\n")
        },

        Case(name: "gõ chữ có dấu trên nhiều caret") { controller in
            controller.prepareSelfTestDocument("x A\nx B\n")
            controller.selectAllOccurrencesForSelfTest("x")
            controller.typeForSelfTest("Việt")
            return expect(controller, "Việt A\nViệt B\n")
        },

        Case(name: "một thao tác gõ là MỘT bước undo") { controller in
            controller.prepareSelfTestDocument("ERROR một\nERROR hai\n")
            controller.selectAllOccurrencesForSelfTest("ERROR")
            let before = controller.editorDocument.buffer.text
            let depth = controller.editorDocument.buffer.undoDepth
            controller.typeForSelfTest("X")

            let buffer = controller.editorDocument.buffer
            // Phải kiểm CẢ nội dung: chỉ kiểm undoDepth thì bài này vẫn xanh khi nhiều caret
            // hỏng hoàn toàn — sửa một chỗ cũng là một bước undo. Đã thấy đúng như vậy khi
            // chạy đối chứng âm.
            guard buffer.text == "X một\nX hai\n" else {
                return "nội dung sai: \(String(reflecting: buffer.text))"
            }
            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth), phải chỉ tăng 1"
            }
            _ = buffer.undo()
            return buffer.text == before ? nil : "undo không về nguyên trạng: \(String(reflecting: buffer.text))"
        },

        Case(name: "gõ đè lên khối cột") { controller in
            controller.prepareSelfTestDocument("Nguyễn 001\nTrần 002\nLê 003\n")
            controller.selectColumnBlockForSelfTest(from: (0, 0), to: (2, 3))
            controller.typeForSelfTest("##")
            // Cột 0..3 của "Nguyễn" là "Ngu" (N,g,u) — còn lại "yễn".
            return expect(controller, "##yễn 001\n##n 002\n##003\n")
        },

        Case(name: "dán khối vào một caret giữ hình chữ nhật") { controller in
            controller.prepareSelfTestDocument("aaa\nbbb\nccc\n")
            controller.setCaretForSelfTest(documentOffset: 1)
            controller.pasteForSelfTest("1\n2\n3")
            return expect(controller, "a1aa\nb2bb\nc3cc\n")
        },

        Case(name: "Column Editor đánh số khối cột") { controller in
            controller.prepareSelfTestDocument("a\nb\nc\n")
            controller.selectColumnBlockForSelfTest(from: (0, 0), to: (2, 0))
            controller.applyColumnEditorForSelfTest(
                .number(start: 1, step: 1, radix: .decimal, padding: 3, uppercase: false)
            )
            return expect(controller, "001a\n002b\n003c\n")
        },

        Case(name: "Column Editor là MỘT bước undo") { controller in
            controller.prepareSelfTestDocument("a\nb\nc\n")
            controller.selectColumnBlockForSelfTest(from: (0, 0), to: (2, 0))
            let before = controller.editorDocument.buffer.text
            let depth = controller.editorDocument.buffer.undoDepth
            controller.applyColumnEditorForSelfTest(.text("> "))

            let buffer = controller.editorDocument.buffer
            guard buffer.text == "> a\n> b\n> c\n" else {
                return "nội dung sai: \(String(reflecting: buffer.text))"
            }
            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth), phải chỉ tăng 1"
            }
            _ = buffer.undo()
            return buffer.text == before ? nil : "undo không về nguyên trạng"
        },

        // MARK: - Ngắt dòng mềm (FR-CORE-015 · TC-CORE-13)

        Case(name: "vòng ba chế độ ngắt dòng và quay lại") { controller in
            controller.prepareSelfTestDocument("a\n")
            controller.setWrapModeForSelfTest(.off)
            var seen: [WrapMode] = []
            for _ in 0 ..< 3 {
                controller.cycleWrapModeForSelfTest()
                seen.append(controller.wrapModeForSelfTest)
            }
            guard seen == [.window, .column(80), .off] else { return "vòng ra \(seen)" }
            return nil
        },

        Case(name: "ba chế độ đặt thùng chữ KHÁC nhau") { controller in
            // Tài liệu phải CÓ dòng dài, nếu không thì ba chế độ đều cho cùng một bề rộng và
            // bài kiểm không phân biệt được gì.
            controller.prepareSelfTestDocument(String(repeating: "x", count: 2_000) + "\na\n")

            // Tắt: thùng chữ phải đủ rộng cho CẢ dòng dài, và không bám bề rộng view.
            //
            // Bản đầu của bài này đòi thùng chữ rộng hơn một triệu point — tức là nó khẳng định
            // CÁCH LÀM (thùng vô hạn) chứ không khẳng định HÀNH VI. Khi cách làm đổi vì lý do
            // hiệu năng, bài kiểm tố cáo nhầm code đang đúng.
            controller.setWrapModeForSelfTest(.off)
            let off = controller.textContainerWidthForSelfTest
            if controller.tracksViewWidthForSelfTest { return "chế độ TẮT vẫn bám bề rộng view" }
            let needed = 2_000.0 * controller.characterWidthForSelfTest
            if off < needed {
                return "chế độ TẮT: thùng chữ \(Int(off)) pt < dòng dài \(Int(needed)) pt — vẫn sẽ ngắt"
            }

            // Theo cửa sổ: bám bề rộng view.
            controller.setWrapModeForSelfTest(.window)
            if !controller.tracksViewWidthForSelfTest { return "chế độ THEO CỬA SỔ không bám view" }

            // Tại cột: bề rộng cố định, KHÔNG bám view, và hẹp hơn hẳn.
            controller.setWrapModeForSelfTest(.column(40))
            if controller.tracksViewWidthForSelfTest { return "chế độ TẠI CỘT vẫn bám view" }
            let column = controller.textContainerWidthForSelfTest
            guard column > 0, column < off else { return "thùng chữ ở cột 40 rộng \(column)" }
            return nil
        },

        Case(name: "dòng 50.000 ký tự không bị cắt mất chữ") { controller in
            // Đây là bài của TC-CORE-13, và nó bắt đúng cái lỗi mà việc bật wrap sinh ra:
            // chiều cao khung chữ từng tính bằng SỐ DÒNG × chiều cao dòng, nên một dòng ngắt
            // thành mấy trăm hàng sẽ bị cắt cụt — mà nhìn code thì không thấy gì sai.
            controller.prepareSelfTestDocument(String(repeating: "x", count: 50_000) + "\nsau\n")
            controller.setWrapModeForSelfTest(.window)
            controller.flushDrawingForSelfTest()

            let g = controller.wrapGeometryForSelfTest
            guard g.laidOutHeight > 0 else { return "TextKit chưa dựng bố cục — bài này vô nghĩa" }
            guard g.textViewHeight >= g.laidOutHeight else {
                return "khung chữ cao \(Int(g.textViewHeight)) pt mà bố cục cần \(Int(g.laidOutHeight)) pt — chữ bị cắt"
            }
            guard g.canvasBottom >= g.textViewHeight else {
                return "khung cuộn \(Int(g.canvasBottom)) pt không chứa nổi khung chữ \(Int(g.textViewHeight)) pt"
            }
            // Và phải THẬT SỰ có ngắt: dòng 50.000 ký tự trong một cửa sổ vài trăm point mà
            // chỉ cao bằng vài dòng thì nghĩa là wrap chưa chạy, và ba kiểm tra trên vô nghĩa.
            guard g.laidOutHeight > 20 * 17 else {
                return "bố cục chỉ cao \(Int(g.laidOutHeight)) pt — dòng dài chưa hề bị ngắt"
            }
            return nil
        },

        Case(name: "ký hiệu ngắt dòng hiện ra") { controller in
            controller.prepareSelfTestDocument(String(repeating: "x", count: 50_000) + "\n")
            controller.setWrapModeForSelfTest(.off)
            controller.flushDrawingForSelfTest()
            InvisiblesLayoutFragment.wrapMarkerCount = 0

            // Đối chứng âm nằm ngay trong bài: TẮT thì không được vẽ ký hiệu nào.
            controller.flushDrawingForSelfTest()
            guard InvisiblesLayoutFragment.wrapMarkerCount == 0 else {
                return "tắt ngắt dòng mà vẫn vẽ \(InvisiblesLayoutFragment.wrapMarkerCount) ký hiệu"
            }

            controller.setWrapModeForSelfTest(.window)
            controller.flushDrawingForSelfTest()
            guard InvisiblesLayoutFragment.wrapMarkerCount > 0 else {
                return "bật ngắt dòng mà không vẽ ký hiệu nào"
            }
            return nil
        },

        Case(name: "caret đi xuống theo HÀNG màn hình, không theo dòng tài liệu") { controller in
            // Dòng đầu dài 50.000 ký tự. Bấm mũi tên xuống từ đầu dòng:
            //  · bật wrap  → caret vẫn nằm TRONG dòng ấy (nhảy sang hàng kế tiếp);
            //  · tắt wrap  → caret nhảy hẳn sang dòng sau.
            // Hai kết quả trái ngược nhau nên bài này không thể xanh vì lý do vu vơ.
            controller.prepareSelfTestDocument(String(repeating: "x", count: 50_000) + "\nsau\n")

            controller.setWrapModeForSelfTest(.window)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.flushDrawingForSelfTest()
            controller.moveDownForSelfTest()
            let wrapped = controller.caretOffsetForSelfTest
            guard wrapped > 0, wrapped < 50_000 else {
                return "bật wrap: caret nhảy tới \(wrapped), phải còn trong dòng dài"
            }

            controller.setWrapModeForSelfTest(.off)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.flushDrawingForSelfTest()
            controller.moveDownForSelfTest()
            let flat = controller.caretOffsetForSelfTest
            guard flat > 50_000 else {
                return "tắt wrap: caret dừng ở \(flat), phải sang hẳn dòng sau"
            }
            return nil
        },

        Case(name: "đổi chế độ ngắt dòng nhiều lần vẫn còn chữ") { controller in
            // Thấy trên ảnh chụp: bấm đổi chế độ vài lần thì vùng soạn thảo TRẮNG TRƠN, còn
            // thanh trạng thái vẫn nói tài liệu có 981 ký tự. Chữ không mất khỏi buffer — nó
            // mất khỏi màn hình, nên không test nào của lõi bắt được.
            let text = "khong thut le: " + String(repeating: "aaaa ", count: 60) + "\n"
                + "        thut 8: " + String(repeating: "bbbb ", count: 60) + "\nhet\n"
            controller.prepareSelfTestDocument(text)

            for round in 1 ... 3 {
                for mode in [WrapMode.window, .column(80), .off] {
                    controller.setWrapModeForSelfTest(mode)
                    controller.flushDrawingForSelfTest()

                    let g = controller.wrapGeometryForSelfTest
                    guard g.textViewHeight > 0 else {
                        return "vòng \(round), \(mode.displayName): khung chữ cao 0"
                    }
                    guard g.laidOutHeight > 0 else {
                        return "vòng \(round), \(mode.displayName): TextKit không dựng bố cục — màn hình trắng"
                    }
                    guard g.textViewHeight >= g.laidOutHeight else {
                        return "vòng \(round), \(mode.displayName): khung chữ \(Int(g.textViewHeight)) < bố cục \(Int(g.laidOutHeight))"
                    }
                    guard g.canvasBottom >= g.textViewHeight else {
                        return "vòng \(round), \(mode.displayName): khung cuộn \(Int(g.canvasBottom)) không chứa nổi khung chữ"
                    }
                    guard controller.textContainerWidthForSelfTest > 0 else {
                        return "vòng \(round), \(mode.displayName): thùng chữ rộng 0"
                    }
                }
            }
            // Nội dung phải nguyên vẹn — đổi cách HIỂN THỊ không được đụng vào tài liệu.
            return expect(controller, text)
        },

        Case(name: "hẹp cửa sổ lại thì ngắt lại, không trắng màn hình") { controller in
            // Đây là bài dựng lại đúng cái đã thấy trên ảnh chụp: cửa sổ bị kéo hẹp trong lúc
            // bật ngắt dòng, và vùng soạn thảo trắng trơn. Nguyên nhân là hình học chỉ được
            // tính lại khi NẠP cửa sổ nội dung, mà đổi cỡ cửa sổ thì không nạp lại gì cả.
            let line = String(repeating: "aaaa ", count: 100)
            controller.prepareSelfTestDocument(line + "\n" + line + "\nhet\n")
            controller.setWrapModeForSelfTest(.window)

            var previousHeight = 0.0
            var previousWidth = 0.0
            for wanted in [900.0, 600.0, 380.0] {
                let width = controller.setWindowWidthForSelfTest(wanted)
                controller.flushDrawingForSelfTest()

                // Chế độ "theo cửa sổ" thì khung chữ phải rộng BẰNG cửa sổ. Thiếu bài này thì
                // khung chữ chỉ rộng hai phần ba mà mọi kiểm tra chiều cao vẫn xanh — đã thấy
                // đúng như vậy trên ảnh chụp.
                let editorWidth = controller.editorWidthForSelfTest
                let textWidth = controller.textViewWidthForSelfTest
                guard abs(textWidth - editorWidth) < 30 else {
                    return "rộng \(Int(width)): khung chữ \(Int(textWidth)) pt trong khung soạn thảo \(Int(editorWidth)) pt"
                }

                let g = controller.wrapGeometryForSelfTest
                guard g.laidOutHeight > 0 else { return "rộng \(Int(width)): bố cục rỗng — màn hình trắng" }
                // So với chiều cao THẬT (ép dựng hết), không so với phần đã dựng: phần đã dựng
                // bị chính khung chữ giới hạn nên so như thế là so vòng tròn.
                let needed = controller.fullyLaidOutHeightForSelfTest()
                guard g.textViewHeight >= needed else {
                    return "rộng \(Int(width)): khung chữ \(Int(g.textViewHeight)) pt < cần \(Int(needed)) pt — chữ bị cắt"
                }
                guard g.canvasBottom >= g.textViewHeight else {
                    return "rộng \(Int(width)): khung cuộn \(Int(g.canvasBottom)) không chứa nổi khung chữ"
                }
                // Hẹp hơn thì phải CAO hơn — nếu không thì chưa hề ngắt lại, và ba kiểm tra
                // trên chỉ đang nghiệm đúng một bố cục cũ đứng yên.
                // Chỉ đòi cao hơn khi cửa sổ THẬT SỰ hẹp đi — cửa sổ có bề rộng tối thiểu.
                if previousWidth > width, g.laidOutHeight <= previousHeight {
                    return "hẹp từ \(Int(previousWidth)) còn \(Int(width)) mà bố cục vẫn cao \(Int(g.laidOutHeight)) pt — chưa ngắt lại"
                }
                previousHeight = g.laidOutHeight
                previousWidth = width
            }
            return nil
        },

        // MARK: - Đánh dấu dòng, chín màu (FR-SRCH-107)

        Case(name: "dòng đánh dấu được TÔ NỀN thật") { controller in
            // Phần dấu vốn chỉ sống trong controller: đánh dấu 500 dòng mà màn hình không đổi
            // gì, và không cách nào biết lệnh có chạy hay không ngoài việc đọc code.
            controller.prepareSelfTestDocument("mot\nhai\nba\nbon\nnam\n")
            controller.setWrapModeForSelfTest(.off)
            controller.flushDrawingForSelfTest()

            guard controller.markedBandsForSelfTest().isEmpty else {
                return "chưa đánh dấu gì mà đã tô \(controller.markedBandsForSelfTest().count) dải"
            }

            controller.markLinesForSelfTest([1, 3], color: 0)
            controller.flushDrawingForSelfTest()
            let bands = controller.markedBandsForSelfTest()
            guard bands.map(\.line).sorted() == [1, 3] else {
                return "tô các dòng \(bands.map(\.line).sorted()), mong đợi [1, 3]"
            }
            return nil
        },

        Case(name: "chín màu đánh dấu độc lập nhau trên màn hình") { controller in
            controller.prepareSelfTestDocument("mot\nhai\nba\nbon\nnam\n")
            controller.setWrapModeForSelfTest(.off)
            controller.markLinesForSelfTest([0], color: 0)
            controller.markLinesForSelfTest([2], color: 4)
            controller.markLinesForSelfTest([4], color: 8)
            controller.flushDrawingForSelfTest()

            let bands = controller.markedBandsForSelfTest().sorted { $0.line < $1.line }
            guard bands.map(\.line) == [0, 2, 4] else { return "tô các dòng \(bands.map(\.line))" }
            guard bands.map(\.color) == [0, 4, 8] else {
                return "màu ra \(bands.map(\.color)), mong đợi [0, 4, 8] — chín màu không độc lập"
            }
            return nil
        },

        Case(name: "một dòng mang hai màu thì tô màu nhỏ hơn") { controller in
            controller.prepareSelfTestDocument("mot\nhai\n")
            controller.setWrapModeForSelfTest(.off)
            controller.markLinesForSelfTest([1], color: 6)
            controller.markLinesForSelfTest([1], color: 2)
            controller.flushDrawingForSelfTest()

            let bands = controller.markedBandsForSelfTest()
            guard bands.count == 1 else { return "tô \(bands.count) dải cho một dòng" }
            guard bands[0].color == 2 else { return "tô màu \(bands[0].color), mong đợi 2" }
            return nil
        },

        Case(name: "F2 nhảy tới dấu kế tiếp và quay vòng") { controller in
            controller.prepareSelfTestDocument("a\nb\nc\nd\ne\nf\n")
            controller.markLinesForSelfTest([1, 4], color: 0)
            controller.setCaretLineForSelfTest(0)

            controller.goToNextMarkForSelfTest()
            guard controller.caretLineForSelfTest() == 1 else {
                return "lần 1 tới dòng \(controller.caretLineForSelfTest()), mong đợi 1"
            }
            controller.goToNextMarkForSelfTest()
            guard controller.caretLineForSelfTest() == 4 else {
                return "lần 2 tới dòng \(controller.caretLineForSelfTest()), mong đợi 4"
            }
            controller.goToNextMarkForSelfTest()
            guard controller.caretLineForSelfTest() == 1 else {
                return "lần 3 tới dòng \(controller.caretLineForSelfTest()) — phải quay vòng về 1"
            }
            return nil
        },

        Case(name: "xóa dòng đánh dấu chạm MỌI màu và là một bước undo") { controller in
            controller.prepareSelfTestDocument("giu1\nxoaA\ngiu2\nxoaB\n")
            controller.markLinesForSelfTest([1], color: 0)
            controller.markLinesForSelfTest([3], color: 5)
            let depth = controller.editorDocument.buffer.undoDepth

            controller.deleteMarkedLinesForSelfTest()
            guard controller.editorDocument.buffer.text == "giu1\ngiu2\n" else {
                return "còn lại \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(controller.editorDocument.buffer.undoDepth)"
            }
            // Số dòng đã đổi nên dấu phải được bỏ — giữ lại là trỏ vào dòng khác.
            guard controller.markCountForSelfTest == 0 else {
                return "còn \(controller.markCountForSelfTest) dấu sau khi số dòng đã đổi"
            }
            return nil
        },

        Case(name: "menu đổi màu đánh dấu thật sự đổi màu") { controller in
            // Đường này suýt lọt: menu bung ra là modal nên kịch bản AppleScript với không
            // tới, và trên ảnh chụp thì năm dòng đánh dấu ra cùng một màu mà không biết vì
            // menu hỏng hay vì chuột bấm trượt.
            controller.prepareSelfTestDocument("a\nb\nc\n")
            let titles = controller.markMenuTitlesForSelfTest
            guard titles.count == 9 else { return "menu có \(titles.count) mục, phải có 9" }
            guard Set(titles).count == 9 else { return "có hai mục trùng tên: \(titles)" }

            guard controller.pickMarkColorFromMenuForSelfTest(5) else {
                return "mục menu không có target/action — bấm vào sẽ không làm gì"
            }
            guard controller.activeMarkColorForSelfTest == 5 else {
                return "chọn mục 5 mà màu đang dùng là \(controller.activeMarkColorForSelfTest)"
            }

            // Và màu ấy phải đi tới tận chỗ VẼ, không chỉ nằm trong biến.
            controller.markLinesForSelfTest([1], color: controller.activeMarkColorForSelfTest)
            controller.flushDrawingForSelfTest()
            let bands = controller.markedBandsForSelfTest()
            guard bands.count == 1, bands[0].color == 5 else {
                return "vẽ ra \(bands.map(\.color)), mong đợi [5]"
            }
            return nil
        },

        Case(name: "nền panel ĐỔI THEO theme, không đứng nguyên màu lúc dựng") { controller in
            // Tìm ra bằng cách NHÌN ẢNH: `--capture` trong CÙNG một lượt chạy cho cảnh `trong`
            // nền sáng và cảnh `csv` nền TỐI. Nguyên nhân là `.cgColor` — một ảnh chụp. `NSColor`
            // của dự án có bản sáng và bản tối, `draw(_:)` giải lại ở mỗi lần vẽ nên luôn đúng,
            // nhưng `layer.backgroundColor` nhận một màu ĐÃ CHỐT. Gán một lần lúc dựng view thì
            // nó đứng nguyên khi người dùng đổi theme.
            //
            // Bài này bắt view tự đổi appearance rồi đọc lại màu nền THẬT của layer.
            // Dựng một view RIÊNG, không gắn vào cửa sổ.
            //
            // Bản đầu của bài này mở panel SQL của chính controller, và nó làm ĐỎ hai bài khác:
            // bài "panel SQL chỉ vào cửa sổ khi người dùng mở nó" thấy panel đã có sẵn, còn bản
            // đồ tài liệu thì lệch bố cục. Một bài kiểm để lại dấu vết trong cửa sổ dùng chung
            // là một bài kiểm đi phá bài khác.
            _ = controller
            let panel = SQLPanel()

            var colors: [String: [CGFloat]] = [:]
            for (name, appearance) in [("sáng", NSAppearance(named: .aqua)!),
                                       ("tối", NSAppearance(named: .darkAqua)!)] {
                panel.appearance = appearance
                panel.layoutSubtreeIfNeeded()
                guard let raw = panel.layer?.backgroundColor,
                      let converted = NSColor(cgColor: raw)?.usingColorSpace(.sRGB) else {
                    return "không đọc được màu nền ở theme \(name)"
                }
                colors[name] = [converted.redComponent, converted.greenComponent,
                                converted.blueComponent]
            }
            panel.appearance = nil

            guard let light = colors["sáng"], let dark = colors["tối"] else {
                return "thiếu màu ở một trong hai theme"
            }
            // Không so màu cụ thể — bảng màu đổi được. Chỉ đòi hai theme cho ra HAI màu khác
            // nhau, và sáng phải sáng hơn tối.
            let lightSum = light.reduce(0, +), darkSum = dark.reduce(0, +)
            guard abs(lightSum - darkSum) > 0.3 else {
                return "nền hai theme gần như một màu (\(lightSum) vs \(darkSum)) — layer không "
                    + "cập nhật theo appearance"
            }
            guard lightSum > darkSum else {
                return "theme sáng lại tối hơn theme tối"
            }
            return nil
        },

        Case(name: "chín màu đánh dấu phân biệt được ở CẢ hai theme") { _ in
            // Chín màu mà hai màu trông giống hệt nhau thì tính năng chỉ đúng trên giấy: cả
            // điểm của nó là đánh dấu ba pattern rồi PHÂN BIỆT chúng trên một màn hình.
            //
            // Kiểm bằng số thay vì nhìn mắt, và kiểm màu ĐÃ PHA trên nền: màu đánh dấu là màu
            // nền có alpha, nên hai màu rất khác nhau vẫn có thể pha ra gần như một.
            for appearance in [NSAppearance(named: .aqua)!, NSAppearance(named: .darkAqua)!] {
                var composited: [(name: String, rgb: (Double, Double, Double))] = []
                appearance.performAsCurrentDrawingAppearance {
                    guard let background = Tokens.Color.editorBackground.usingColorSpace(.sRGB)
                    else { return }
                    for (index, color) in Tokens.Color.markColors.enumerated() {
                        guard let front = color.usingColorSpace(.sRGB) else { continue }
                        let alpha = front.alphaComponent
                        composited.append((
                            Tokens.Color.markColorNames[index],
                            (front.redComponent * alpha + background.redComponent * (1 - alpha),
                             front.greenComponent * alpha + background.greenComponent * (1 - alpha),
                             front.blueComponent * alpha + background.blueComponent * (1 - alpha))
                        ))
                    }
                }
                guard composited.count == 9 else { return "chỉ pha được \(composited.count)/9 màu" }

                let theme = appearance.name == .darkAqua ? "tối" : "sáng"
                for i in 0 ..< composited.count {
                    for j in (i + 1) ..< composited.count {
                        let a = composited[i].rgb, b = composited[j].rgb
                        let distance = (
                            (a.0 - b.0) * (a.0 - b.0)
                                + (a.1 - b.1) * (a.1 - b.1)
                                + (a.2 - b.2) * (a.2 - b.2)
                        ).squareRoot() * 255
                        guard distance >= 12 else {
                            return "theme \(theme): «\(composited[i].name)» và «\(composited[j].name)»"
                                + " chỉ cách nhau \(Int(distance))/255 — nhìn ra một màu"
                        }
                    }
                }
            }
            return nil
        },

        // MARK: - Phiên làm việc (FR-DOC-303)

        Case(name: "phiên mở lại đúng danh sách tab, vị trí con trỏ và tab ghim") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let files = (0 ..< 3).map { root.appendingPathComponent("tab\($0).txt") }
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                for (index, file) in files.enumerated() {
                    try "noi dung \(index)\ndong hai\ndong ba\n".write(to: file, atomically: true, encoding: .utf8)
                }
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.resetTabsForSelfTest()
            for file in files { controller.openInNewTabForSelfTest(path: file.path) }
            controller.setTabPinnedForSelfTest(1, true)
            controller.setCaretForSelfTest(documentOffset: 12)
            controller.saveSession()

            // Quên sạch, rồi mở lại từ ĐĨA — không phải từ biến còn trong bộ nhớ.
            controller.resetTabsForSelfTest()
            guard controller.tabPathsForSelfTest.count == 1 else { return "reset không sạch" }

            let count = controller.restoreSession()
            guard count == 3 else { return "mở lại \(count) tab, mong đợi 3" }
            let paths = controller.tabPathsForSelfTest
            guard paths == files.map({ $0.path }) else {
                return "thứ tự tab sai: \(paths.map { $0.map { ($0 as NSString).lastPathComponent } ?? "nil" })"
            }
            guard controller.tabPinnedForSelfTest == [false, true, false] else {
                return "cờ ghim ra \(controller.tabPinnedForSelfTest)"
            }
            guard controller.tabCaretsForSelfTest[2] == 12 else {
                return "con trỏ tab cuối ở \(controller.tabCaretsForSelfTest[2]), mong đợi 12"
            }
            return nil
        },

        Case(name: "phiên giữ được NỘI DUNG CHƯA LƯU") { controller in
            // Đây là phần đáng giá nhất của FR-DOC-303: file đã lưu thì mất phiên vẫn mở tay
            // lại được, còn nội dung chưa lưu mất là mất hẳn.
            let root = controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument("ban nhap chua luu\n")
            _ = root

            controller.writeSnapshotsForSelfTest()      // chụp bản nháp + ghi phiên
            controller.resetTabsForSelfTest()

            let count = controller.restoreSession()
            guard count == 1 else { return "mở lại \(count) tab, mong đợi 1" }
            guard controller.tabTextsForSelfTest == ["ban nhap chua luu\n"] else {
                return "nội dung ra \(controller.tabTextsForSelfTest)"
            }
            guard controller.tabPathsForSelfTest == [nil] else {
                return "tài liệu chưa lưu mà lại có đường dẫn \(controller.tabPathsForSelfTest)"
            }
            return nil
        },

        Case(name: "file biến mất thì bỏ qua tab ấy, không hỏng cả phiên") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let kept = root.appendingPathComponent("con.txt")
            let gone = root.appendingPathComponent("mat.txt")
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try "con lai\n".write(to: kept, atomically: true, encoding: .utf8)
                try "sap bi xoa\n".write(to: gone, atomically: true, encoding: .utf8)
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: kept.path)
            controller.openInNewTabForSelfTest(path: gone.path)
            controller.saveSession()

            try? FileManager.default.removeItem(at: gone)
            controller.resetTabsForSelfTest()

            let count = controller.restoreSession()
            guard count == 1 else { return "mở lại \(count) tab, mong đợi 1" }
            guard controller.tabPathsForSelfTest == [kept.path] else {
                return "mở lại nhầm: \(controller.tabPathsForSelfTest)"
            }
            return nil
        },

        Case(name: "tab trắng chưa động tới KHÔNG được mở lại") { controller in
            // Không lọc thì người mở app nhiều lần trong ngày tích dần một đống tab trắng.
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            controller.saveSession()
            controller.resetTabsForSelfTest()
            guard controller.restoreSession() == 0 else {
                return "mở lại \(controller.restoreSession()) tab trắng"
            }
            return nil
        },

        // MARK: - Chia đôi màn hình (FR-DOC-302 · TC-DOC-05)

        Case(name: "chia đôi thì hai pane mở CÙNG một tài liệu") { controller in
            controller.closeSplitForSelfTest()
            controller.prepareSelfTestDocument("mot\nhai\nba\n")
            guard !controller.isSplitForSelfTest else { return "chưa chia mà đã báo là đã chia" }

            controller.splitForSelfTest(vertical: true)
            guard controller.isSplitForSelfTest else { return "gọi chia đôi mà không chia" }
            guard controller.paneDocumentIsSameForSelfTest() else {
                return "hai pane mở hai tài liệu khác nhau"
            }
            guard controller.paneTextForSelfTest(0) == controller.paneTextForSelfTest(1) else {
                return "nội dung hai pane khác nhau ngay khi vừa chia"
            }

            // Và phải chia THẬT trên màn hình. Thiếu bài này thì "đã chia" chỉ là một biến
            // `Bool` bằng true trong khi người dùng vẫn nhìn thấy đúng một khung — đã thấy
            // đúng như vậy trên ảnh chụp.
            controller.layoutWindowForSelfTest()
            controller.flushDrawingForSelfTest()
            let left = controller.paneSizeForSelfTest(0)
            let right = controller.paneSizeForSelfTest(1)
            guard right.width > 50, right.height > 50 else {
                return "nửa thứ hai có kích thước \(Int(right.width))×\(Int(right.height)) — không nhìn thấy được"
            }
            guard abs(left.width - right.width) < left.width * 0.3 else {
                return "chia không đều: \(Int(left.width)) và \(Int(right.width))"
            }
            controller.closeSplitForSelfTest()
            return nil
        },

        Case(name: "sửa ở pane này thì pane kia đổi theo TỨC THÌ") { controller in
            // Đây đúng là TC-DOC-05. Nó cũng là chỗ dễ hỏng nhất của chia đôi: hai khung giữ
            // hai bản sao chuỗi riêng, nên pane không gõ vào sẽ hiện nội dung ĐÃ CHẾT và người
            // dùng sửa tiếp trên cái họ đang nhìn.
            controller.closeSplitForSelfTest()
            controller.prepareSelfTestDocument("ERROR mot\nhai\n")
            controller.splitForSelfTest(vertical: true)

            controller.focusPaneForSelfTest(0)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.typeForSelfTest("X")

            let left = controller.paneTextForSelfTest(0)
            let right = controller.paneTextForSelfTest(1)
            guard left.hasPrefix("XERROR") else { return "pane trái không nhận ký tự: \(left.prefix(12))" }
            guard right == left else {
                return "pane phải vẫn là nội dung cũ: \(right.prefix(12))"
            }
            controller.closeSplitForSelfTest()
            return nil
        },

        Case(name: "hai pane cuộn ĐỘC LẬP nhau") { controller in
            // Nửa còn lại của TC-DOC-05, và là cả lý do người ta chia đôi: xem hai chỗ xa nhau
            // trong CÙNG một file. Đồng bộ cả vị trí cuộn thì tính năng thành vô dụng.
            controller.closeSplitForSelfTest()
            let lines = (0 ..< 400).map { "dong \($0)" }.joined(separator: "\n") + "\n"
            controller.prepareSelfTestDocument(lines)
            controller.splitForSelfTest(vertical: true)

            controller.scrollPaneForSelfTest(1, to: 1_200)
            controller.flushDrawingForSelfTest()
            let before = controller.paneScrollForSelfTest(1)
            guard before > 100 else { return "pane phải không cuộn được (y = \(before))" }

            // Gõ vào pane trái: pane phải phải đổi NỘI DUNG mà KHÔNG nhảy chỗ xem.
            controller.focusPaneForSelfTest(0)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.typeForSelfTest("Z")
            controller.flushDrawingForSelfTest()

            guard controller.paneTextForSelfTest(1).hasPrefix("Zdong 0") else {
                return "pane phải không thấy sửa đổi"
            }
            let after = controller.paneScrollForSelfTest(1)
            guard abs(after - before) < 2 else {
                return "pane phải bị kéo từ y=\(Int(before)) về y=\(Int(after)) — cuộn không độc lập"
            }
            controller.closeSplitForSelfTest()
            return nil
        },

        Case(name: "mở tab này ở nửa kia thì nửa kia ĐỔI sang đúng tài liệu ấy") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let files = (0 ..< 2).map { root.appendingPathComponent("pane\($0).txt") }
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try "NOI DUNG A\n".write(to: files[0], atomically: true, encoding: .utf8)
                try "NOI DUNG B\n".write(to: files[1], atomically: true, encoding: .utf8)
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.closeSplitForSelfTest()
            controller.resetTabsForSelfTest()
            for file in files { controller.openInNewTabForSelfTest(path: file.path) }

            // Dựng thế đứng để bài kiểm CÓ NGHĨA: chia đôi khi đang ở tab B (nên nửa phải nhân
            // bản thành B), rồi kéo nửa trái về tab A. Bây giờ hai nửa khác nhau sẵn.
            //
            // Bản đầu của bài này không dựng bước ấy, và nó VẪN XANH khi tôi cắt hẳn phần
            // chuyển tab: nửa phải đang là B chỉ vì lúc chia đôi nó nhân bản tab hiện tại.
            controller.splitForSelfTest(vertical: true)
            controller.focusPaneForSelfTest(0)
            controller.activateTabForSelfTest(0)
            controller.flushDrawingForSelfTest()
            guard controller.paneTextForSelfTest(1).hasPrefix("NOI DUNG B") else {
                return "dựng thế đứng hỏng: nửa phải đang là «\(controller.paneTextForSelfTest(1).prefix(10))»"
            }

            // Giờ mới là việc cần kiểm: mở tab A (đang ở nửa trái) sang nửa phải.
            controller.showTabInOtherPaneForSelfTest()
            controller.flushDrawingForSelfTest()
            guard controller.paneTextForSelfTest(1).hasPrefix("NOI DUNG A") else {
                return "nửa phải vẫn là «\(controller.paneTextForSelfTest(1).prefix(10))», mong đợi A"
            }
            controller.closeSplitForSelfTest()
            return nil
        },

        Case(name: "phiên nhớ cả trạng thái chia đôi") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let file = root.appendingPathComponent("chia.txt")
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try "mot\nhai\n".write(to: file, atomically: true, encoding: .utf8)
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.closeSplitForSelfTest()
            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: file.path)
            controller.splitForSelfTest(vertical: false)      // chia NGANG
            controller.saveSession()

            controller.closeSplitForSelfTest()
            controller.resetTabsForSelfTest()
            guard !controller.isSplitForSelfTest else { return "reset không bỏ được chia đôi" }

            guard controller.restoreSession() == 1 else { return "không mở lại được tab" }
            guard controller.isSplitForSelfTest else {
                return "mở lại phiên mà mất trạng thái chia đôi"
            }
            guard !controller.isSplitVerticalForSelfTest else {
                return "chia lại theo chiều DỌC, phiên trước là chiều NGANG"
            }
            controller.closeSplitForSelfTest()
            return nil
        },

        Case(name: "kéo đổi vị trí tab thì hai nửa vẫn trỏ đúng tài liệu") { controller in
            // Lỗi mà bài này chặn: kéo một tab sang chỗ khác, và nửa kia của màn hình lặng lẽ
            // nhảy sang tài liệu khác vì chỉ số của nó không được dời theo.
            let root = controller.useTemporaryStoresForSelfTest()
            let files = (0 ..< 3).map { root.appendingPathComponent("kt\($0).txt") }
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                for (index, file) in files.enumerated() {
                    try "TAI LIEU \(index)\n".write(to: file, atomically: true, encoding: .utf8)
                }
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.closeSplitForSelfTest()
            controller.resetTabsForSelfTest()
            for file in files { controller.openInNewTabForSelfTest(path: file.path) }

            // Nửa trái xem tài liệu 0, nửa phải xem tài liệu 2.
            controller.splitForSelfTest(vertical: true)
            controller.focusPaneForSelfTest(1)
            controller.activateTabForSelfTest(2)
            controller.focusPaneForSelfTest(0)
            controller.activateTabForSelfTest(0)
            controller.flushDrawingForSelfTest()
            guard controller.paneTextForSelfTest(1).hasPrefix("TAI LIEU 2") else {
                return "dựng thế đứng hỏng: nửa phải là «\(controller.paneTextForSelfTest(1).prefix(11))»"
            }

            // Kéo tài liệu 0 xuống cuối: thứ tự thành 1, 2, 0.
            controller.moveTabForSelfTest(from: 0, to: 2)
            controller.flushDrawingForSelfTest()

            guard controller.tabPathsForSelfTest == [files[1].path, files[2].path, files[0].path] else {
                return "thứ tự tab ra \(controller.tabPathsForSelfTest.map { ($0! as NSString).lastPathComponent })"
            }
            // Kiểm CHỈ SỐ, không kiểm chữ đang hiện.
            //
            // Đổi vị trí tab không nạp lại khung soạn thảo, nên chữ trên màn hình không đổi dù
            // chỉ số có sai — bản đầu của bài này kiểm chữ và nó VẪN XANH khi tôi cắt hẳn phần
            // dời chỉ số. Sai ở đây là sai NGẦM: chỉ số trỏ một đằng, màn hình hiện một nẻo, và
            // nó chỉ nổ ra ở thao tác kế tiếp.
            let targets = controller.paneTargetPathsForSelfTest.map {
                $0.map { ($0 as NSString).lastPathComponent } ?? "nil"
            }
            guard targets == ["kt0.txt", "kt2.txt"] else {
                return "sau khi kéo, hai nửa trỏ vào \(targets) — mong đợi [kt0.txt, kt2.txt]"
            }
            controller.closeSplitForSelfTest()
            return nil
        },

        Case(name: "thả tab vào nửa kia thì nửa ấy mở tab đó") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let files = (0 ..< 2).map { root.appendingPathComponent("tha\($0).txt") }
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try "THA A\n".write(to: files[0], atomically: true, encoding: .utf8)
                try "THA B\n".write(to: files[1], atomically: true, encoding: .utf8)
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.closeSplitForSelfTest()
            controller.resetTabsForSelfTest()
            for file in files { controller.openInNewTabForSelfTest(path: file.path) }
            controller.splitForSelfTest(vertical: true)
            controller.focusPaneForSelfTest(0)
            controller.activateTabForSelfTest(1)
            controller.flushDrawingForSelfTest()

            guard controller.dropTabForSelfTest(0, intoPane: 1) else {
                return "thả vào nửa phải mà nửa ấy không đổi tab"
            }
            controller.flushDrawingForSelfTest()
            guard controller.paneTextForSelfTest(1).hasPrefix("THA A") else {
                return "nửa phải là «\(controller.paneTextForSelfTest(1).prefix(6))», mong đợi THA A"
            }
            controller.closeSplitForSelfTest()
            return nil
        },

        Case(name: "bỏ chia đôi thì về lại một pane") { controller in
            controller.closeSplitForSelfTest()
            controller.prepareSelfTestDocument("mot\n")
            controller.splitForSelfTest(vertical: false)
            guard controller.isSplitForSelfTest else { return "không chia được theo chiều ngang" }
            controller.closeSplitForSelfTest()
            guard !controller.isSplitForSelfTest else { return "bỏ chia đôi mà vẫn còn chia" }
            // Và vẫn gõ được sau khi gộp lại — pane còn lại phải còn nối đủ callback.
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.typeForSelfTest("A")
            return expect(controller, "Amot\n")
        },

        // MARK: - Macro (FR-AUTO-601/602 · TC-AUTO-01)

        Case(name: "ghi macro bắt được cả chữ gõ lẫn lệnh di chuyển") { controller in
            // Ghi đi qua ĐÚNG đường AppKit: chữ qua `insertText`, lệnh qua `doCommand(by:)`.
            // Bắt bằng keyDown thì macro phụ thuộc bố cục bàn phím và bộ gõ đang bật.
            controller.prepareSelfTestDocument("mot\nhai\n")
            controller.setCaretForSelfTest(documentOffset: 0)

            controller.toggleMacroRecordingForSelfTest()      // bắt đầu ghi
            controller.typeForSelfTest("A")
            controller.typeForSelfTest("B")
            controller.sendCommandForSelfTest(#selector(NSResponder.moveToEndOfLine(_:)))
            controller.sendCommandForSelfTest(#selector(NSResponder.moveDown(_:)))
            controller.sendCommandForSelfTest(#selector(NSResponder.deleteBackward(_:)))
            controller.toggleMacroRecordingForSelfTest()      // dừng ghi

            let steps = controller.recordedMacroStepsForSelfTest
            // "A" rồi "B" phải GỘP thành một bước: không gộp thì macro ghi một câu là hàng
            // trăm bước, đọc không được và phát lại chậm hơn nhiều lần.
            guard steps == [.insert("AB"), .move(.lineEnd), .move(.down), .deleteBackward] else {
                return "ghi ra \(steps)"
            }
            return nil
        },

        Case(name: "phát macro 20 lần cho kết quả như làm tay 20 lần") { controller in
            let source = (0 ..< 20).map { "dong \($0) ERROR\n" }.joined()
            let expected = (0 ..< 20).map { "dong \($0) WARN\n" }.joined()
            controller.prepareSelfTestDocument(source)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.setMacroForSelfTest([
                .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
                .replaceSelection("WARN"),
            ])
            controller.runMacroForSelfTest(repetitions: 20)
            return expect(controller, expected)
        },

        Case(name: "phát macro là MỘT bước undo, kể cả chạy 20 lần") { controller in
            let source = (0 ..< 20).map { "dong \($0) ERROR\n" }.joined()
            controller.prepareSelfTestDocument(source)
            controller.setCaretForSelfTest(documentOffset: 0)
            let depth = controller.editorDocument.buffer.undoDepth

            controller.setMacroForSelfTest([
                .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
                .replaceSelection("WARN"),
            ])
            controller.runMacroForSelfTest(repetitions: 20)

            let buffer = controller.editorDocument.buffer
            guard !buffer.text.contains("ERROR") else { return "macro không chạy" }
            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth), phải chỉ tăng 1"
            }
            _ = buffer.undo()
            return buffer.text == source ? nil : "một lần undo không về nguyên trạng"
        },

        Case(name: "phát đến cuối tài liệu thì DỪNG, không chạy mãi") { controller in
            controller.prepareSelfTestDocument((0 ..< 300).map { "dong \($0) X\n" }.joined())
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.setMacroForSelfTest([
                .find(pattern: "X", mode: .normal, matchCase: true, wholeWord: false),
                .replaceSelection("Y"),
            ])
            controller.runMacroForSelfTest(repetitions: 0)
            let text = controller.editorDocument.buffer.text
            guard !text.contains(" X") else { return "còn sót chỗ chưa xử lý" }
            guard text.hasPrefix("dong 0 Y\n") else { return "kết quả sai: \(text.prefix(20))" }
            return nil
        },

        Case(name: "macro chạy trên MỌI tab đang mở") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let files = (0 ..< 3).map { root.appendingPathComponent("mac\($0).txt") }
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                for file in files {
                    try "ERROR o day\n".write(to: file, atomically: true, encoding: .utf8)
                }
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.closeSplitForSelfTest()
            controller.resetTabsForSelfTest()
            for file in files { controller.openInNewTabForSelfTest(path: file.path) }

            controller.setMacroForSelfTest([
                .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
                .replaceSelection("WARN"),
            ])
            controller.runMacroOnAllTabsForSelfTest()

            let texts = controller.tabTextsForSelfTest
            guard texts.allSatisfy({ $0.hasPrefix("WARN") }) else {
                return "còn tab chưa chạy: \(texts.map { String($0.prefix(6)) })"
            }
            return nil
        },

        Case(name: "macro đã lưu còn nguyên khi đọc lại từ đĩa") { controller in
            // TC-AUTO-01 đòi "lưu macro, khởi động lại app vẫn còn". Bài này kiểm phần đĩa:
            // ghi ra rồi đọc lại bằng một kho mới, đúng thứ xảy ra khi mở lại app.
            _ = controller.useTemporaryMacroStoreForSelfTest()
            controller.setMacroForSelfTest([
                .find(pattern: "^ERROR (\\w+)$", mode: .regex, matchCase: true, wholeWord: false),
                .replaceSelection("WARN $1"),
                .move(.nextLine),
            ])
            guard controller.saveCurrentMacroForSelfTest(named: "Đổi ERROR") else {
                return "không lưu được macro"
            }
            guard controller.savedMacroNamesForSelfTest == ["Đổi ERROR"] else {
                return "đọc lại ra \(controller.savedMacroNamesForSelfTest)"
            }
            let titles = controller.savedMacroMenuTitlesForSelfTest
            guard titles.count == 1, titles[0].contains("Đổi ERROR"), titles[0].contains("3 bước") else {
                return "menu macro ra \(titles)"
            }
            return nil
        },

        // MARK: - Nhân đôi · xóa dòng · comment (FR-CORE-007 · FR-CORE-014)

        Case(name: "nhân đôi dòng và xóa dòng đi qua đúng lệnh menu") { controller in
            // Ba mục menu này từng nằm trong thanh Edit với action `nil`: có chỗ bấm, không có
            // gì xảy ra. Bài này đi qua ĐÚNG các `@objc` mà menu gọi, nên nếu ai đó tháo dây
            // nối ra khỏi menu thì lỗi vẫn lọt — cái đó phải nhìn menu mà kiểm, xem bài dưới.
            controller.prepareSelfTestDocument("một\nhai\nba\n")
            controller.setCaretForSelfTest(documentOffset: 6)          // dòng "hai" — "một\n" là 6 BYTE
            controller.duplicateLines(nil)
            guard controller.editorDocument.buffer.text == "một\nhai\nhai\nba\n" else {
                return "nhân đôi ra \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            // Nhân đôi cả triệu dòng vẫn phải là MỘT bước hoàn tác — bất biến của cả sản phẩm.
            // Đi qua lệnh Hoàn tác của menu chứ không gọi thẳng `buffer.undo()`: gọi thẳng thì
            // khung nhìn không biết tài liệu đã đổi, và mọi phép đo sau đó nói về trạng thái cũ.
            controller.undoDocument(nil)
            guard controller.editorDocument.buffer.text == "một\nhai\nba\n" else {
                return "một lần hoàn tác không đưa được về chỗ cũ: "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }

            controller.setCaretForSelfTest(documentOffset: 6)
            controller.deleteLines(nil)
            guard controller.editorDocument.buffer.text == "một\nba\n" else {
                return "xóa dòng ra \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            return nil
        },

        Case(name: "comment ⌘/ dùng dấu của ĐÚNG ngôn ngữ, bấm hai lần về chỗ cũ") { controller in
            controller.prepareSelfTestDocument("x = 1\ny = 2\n")
            controller.setSyntaxLanguageForSelfTest(.python)
            controller.setSelectionForSelfTest(documentRange: 0 ..< 12)
            controller.toggleComment(nil)
            guard controller.editorDocument.buffer.text == "# x = 1\n# y = 2\n" else {
                return "Python phải dùng #, ra \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            controller.setSelectionForSelfTest(documentRange: 0 ..< 16)
            controller.toggleComment(nil)
            guard controller.editorDocument.buffer.text == "x = 1\ny = 2\n" else {
                return "bấm lần hai không trả về chỗ cũ: \(String(reflecting: controller.editorDocument.buffer.text))"
            }

            // Đối chứng: ngôn ngữ khác thì dấu khác. Dùng chung một dấu cho mọi ngôn ngữ là
            // cách làm hỏng file — `#` trong một file Rust không phải chú thích.
            controller.prepareSelfTestDocument("let a = 1;\n")
            controller.setSyntaxLanguageForSelfTest(.rust)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.toggleComment(nil)
            guard controller.editorDocument.buffer.text == "// let a = 1;\n" else {
                return "Rust phải dùng //, ra \(String(reflecting: controller.editorDocument.buffer.text))"
            }

            // XML không có comment một dòng — phải bọc khối, không được bịa ra `//`.
            controller.prepareSelfTestDocument("<a/>\n")
            controller.setSyntaxLanguageForSelfTest(.xml)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.toggleComment(nil)
            guard controller.editorDocument.buffer.text == "<!-- <a/> -->\n" else {
                return "XML phải bọc khối, ra \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            return nil
        },

        Case(name: "chuẩn hóa Unicode gộp được chữ Việt dạng tổ hợp") { controller in
            // Cùng một chữ "ế": ba điểm mã (NFD, macOS hay sinh) và một điểm mã (NFC, Windows
            // và web dùng). Hai dòng trông giống hệt nhau mà khác byte thì tìm kiếm trượt và
            // khử trùng lặp bỏ sót — nên lệnh này phải có đường vào từ giao diện.
            controller.prepareSelfTestDocument("Hue\u{0302}\u{0301}\n")
            let before = controller.editorDocument.buffer.text.utf8.count
            controller.normalizeDocument(to: .nfc)
            let after = controller.editorDocument.buffer.text
            guard after == "Huế\n" else { return "ra \(String(reflecting: after))" }
            guard after.utf8.count < before else {
                return "số byte không giảm (\(before) → \(after.utf8.count)) — chưa chuẩn hóa gì"
            }
            return nil
        },

        Case(name: "mọi mục menu đều có việc để làm — không mục nào bấm vào là im lặng") { controller in
            // Bài này bắt đúng loại lỗi vừa tìm ra: bốn mục menu tồn tại với `action: nil`.
            // Chúng trông như tính năng đã có, kể cả với người viết mã, cho tới khi ai đó bấm.
            _ = controller
            guard let mainMenu = NSApp.mainMenu else { return "chưa có thanh menu" }
            var dead: Set<String> = []
            // Đi ĐỆ QUY: menu View có submenu lồng ("Gấp theo cấp"), và bản trước của bài này
            // dừng ở tầng một nên tám mục trong đó không ai soi.
            for (path, item) in Self.allMenuItems(under: mainMenu) {
                let group = path.components(separatedBy: " › ").first ?? path
                guard !Self.menusAllowedToBeEmpty.contains(group) else { continue }
                if item.action == nil { dead.insert(path) }
            }
            let known = Set(Self.menuItemsPendingImplementation.keys)
            let unexpected = dead.subtracting(known)
            guard unexpected.isEmpty else {
                return "mục menu không có hành động: \(unexpected.sorted().joined(separator: ", "))"
            }
            // Chiều ngược lại, và đây mới là chỗ giữ cho danh sách nợ không mục ruỗng: mục đã
            // được nối rồi mà vẫn nằm trong danh sách thì phải xoá đi.
            let stale = known.subtracting(dead)
            guard stale.isEmpty else {
                return "đã nối rồi, xoá khỏi `menuItemsPendingImplementation`: "
                    + stale.sorted().joined(separator: ", ")
            }
            return nil
        },

        Case(name: "theo dõi file nạp phần mới và khóa vùng soạn thảo") { controller in
            let path = NSTemporaryDirectory() + "geditor-selftest-tail.log"
            try? "dòng 1\n".write(toFile: path, atomically: true, encoding: .utf8)
            defer {
                if controller.isFollowingTail { controller.toggleFollowTail(nil) }
                try? FileManager.default.removeItem(atPath: path)
            }

            controller.openInNewTabForSelfTest(path: path)
            controller.toggleFollowTail(nil)
            guard controller.isFollowingTail else { return "không bật được chế độ theo dõi" }

            // Theo dõi phải KHÓA vùng soạn thảo: vừa cho gõ vừa nạp thêm từ đĩa là hai nguồn
            // sửa đổi tranh nhau một tài liệu, và bên thua là phần người dùng vừa gõ.
            guard controller.editorDocument.isReadOnly else {
                return "đang theo dõi mà tài liệu vẫn sửa được"
            }

            let handle = FileHandle(forWritingAtPath: path)!
            handle.seekToEndOfFile()
            handle.write(Data("dòng 2\n".utf8))
            try? handle.close()
            controller.pollTailForSelfTest()

            guard controller.editorDocument.buffer.text == "dòng 1\ndòng 2\n" else {
                return "sau khi ghi thêm, tài liệu là "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }

            // Tắt theo dõi phải trả lại quyền sửa — nhưng chỉ về đúng quyền THẬT của file.
            controller.toggleFollowTail(nil)
            guard !controller.isFollowingTail, !controller.editorDocument.isReadOnly else {
                return "tắt theo dõi mà tài liệu vẫn bị khóa"
            }
            return nil
        },

        // FR-DOC-314 — nhân bản · đổi tên · chuyển tệp, và Lưu thành chọn được bảng mã/EOL.
        //
        // Ba lệnh đầu đụng vào TỆP THẬT trên đĩa và không có bước lùi nào, nên bất biến quan
        // trọng nhất là: tab đang mở phải trỏ đúng chỗ mới, và không tệp nào bị ghi đè.
        Case(name: "nhân bản · đổi tên · chuyển tệp, và Lưu thành chọn bảng mã") { controller in
            let folder = NSTemporaryDirectory() + "doc314-\(UUID().uuidString)"
            let sub = (folder as NSString).appendingPathComponent("kho")
            try? FileManager.default.createDirectory(
                atPath: sub, withIntermediateDirectories: true)
            defer {
                controller.resetTabsForSelfTest()
                try? FileManager.default.removeItem(atPath: folder)
            }
            let path = (folder as NSString).appendingPathComponent("bao-cao.txt")
            try? "nội dung\n".write(toFile: path, atomically: true, encoding: .utf8)

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: path)

            // NHÂN BẢN — tên theo lối Finder, và bản sao MỞ RA thành tab.
            controller.duplicateDocument(nil)
            let copy = (folder as NSString).appendingPathComponent("bao-cao 2.txt")
            guard FileManager.default.fileExists(atPath: copy) else {
                return "nhân bản mà không có «bao-cao 2.txt»"
            }
            guard controller.editorDocument.path == copy else {
                return "nhân bản mà không mở bản sao: \(controller.editorDocument.path ?? "nil")"
            }
            guard (try? String(contentsOfFile: path, encoding: .utf8)) == "nội dung\n" else {
                return "TỆP GỐC bị đụng tới khi nhân bản"
            }

            // ĐỔI TÊN — tab phải trỏ sang tên mới, tệp cũ biến mất.
            controller.activateTabForSelfTest(path: path)
            guard controller.renameDocumentForSelfTest(to: "bao-cao-2026.txt") else {
                return "không đổi tên được"
            }
            let renamed = (folder as NSString).appendingPathComponent("bao-cao-2026.txt")
            guard FileManager.default.fileExists(atPath: renamed),
                  !FileManager.default.fileExists(atPath: path) else {
                return "đổi tên mà tệp cũ vẫn còn hoặc tệp mới không có"
            }
            guard controller.editorDocument.path == renamed else {
                return "đổi tên xong mà tab vẫn trỏ vào tệp cũ — lần ⌘S sau sẽ ghi nhầm chỗ"
            }

            // Tên đụng tệp có sẵn thì TỪ CHỐI, không ghi đè.
            guard !controller.renameDocumentForSelfTest(to: "bao-cao 2.txt") else {
                return "đổi tên đè lên một tệp đang có"
            }
            guard (try? String(contentsOfFile: copy, encoding: .utf8)) == "nội dung\n" else {
                return "tệp bị đè mất nội dung"
            }
            // Tên có dấu `/` là một ĐƯỜNG DẪN, không phải tên.
            guard !controller.renameDocumentForSelfTest(to: "kho/lung-tung.txt") else {
                return "nhận một đường dẫn làm tên tệp"
            }

            // CHUYỂN TỆP sang thư mục con.
            guard controller.moveDocumentForSelfTest(toFolder: sub) else {
                return "không chuyển được tệp"
            }
            let moved = (sub as NSString).appendingPathComponent("bao-cao-2026.txt")
            guard FileManager.default.fileExists(atPath: moved),
                  controller.editorDocument.path == moved else {
                return "chuyển tệp mà tab không theo sang chỗ mới"
            }

            // LƯU THÀNH với bảng mã khác — nội dung đọc lại phải đúng bằng bảng mã ấy.
            let utf16 = (folder as NSString).appendingPathComponent("ban-utf16.txt")
            controller.saveDocumentAsForSelfTest(path: utf16, encoding: .utf16LE, eol: .crlf)
            guard let data = FileManager.default.contents(atPath: utf16) else {
                return "Lưu thành không tạo ra tệp"
            }
            guard let doc = try? Document.open(path: utf16),
                  doc.encoding == .utf16LE else {
                return "tệp lưu ra không phải UTF-16LE"
            }
            guard data.count > "nội dung\r\n".utf8.count else {
                return "tệp UTF-16 phải dài hơn bản UTF-8 — có vẻ bảng mã không được áp"
            }
            return nil
        },

        // FR-FMT-505 — XPath đánh giá được, và gõ `>` thì thẻ tự đóng.
        Case(name: "XML: đánh giá XPath và tự đóng thẻ") { controller in
            let folder = NSTemporaryDirectory() + "xpath-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer {
                controller.resetTabsForSelfTest()
                try? FileManager.default.removeItem(atPath: folder)
            }
            let xml = (folder as NSString).appendingPathComponent("don.xml")
            try? "<don><hang ma=\"A1\">Bàn</hang><hang ma=\"B2\">Ghế</hang></don>\n"
                .write(toFile: xml, atomically: true, encoding: .utf8)

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: xml)
            let truoc = controller.tabCountForSelfTest
            guard controller.evaluateXPathForSelfTest("//hang/@ma") else {
                return "không đánh giá được XPath: «\(controller.lastTransientForSelfTest)»"
            }
            guard controller.tabCountForSelfTest == truoc + 1 else {
                return "đánh giá XPath mà không mở tab kết quả"
            }
            guard controller.editorDocument.buffer.text == "A1\nB2\n" else {
                return "kết quả XPath ra "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }

            // Biểu thức hỏng phải NÓI RA, không im lặng mở một tab rỗng.
            controller.clearTransientForSelfTest()
            let sau = controller.tabCountForSelfTest
            guard !controller.evaluateXPathForSelfTest("//[[[") else {
                return "biểu thức hỏng mà vẫn nhận"
            }
            guard controller.tabCountForSelfTest == sau else {
                return "biểu thức hỏng mà vẫn mở tab"
            }
            guard !controller.lastTransientForSelfTest.isEmpty else {
                return "biểu thức hỏng mà không nói gì"
            }

            // Tự đóng thẻ: gõ `>` trong tệp XML thì thẻ đóng hiện ra, con nháy nằm GIỮA.
            controller.activateTabForSelfTest(path: xml)
            controller.prepareSelfTestEditToDocument("")
            controller.setSyntaxLanguageForSelfTest(.xml)
            // Gõ TỪNG KÝ TỰ như người dùng thật. Chèn thẻ đóng chỉ kích hoạt khi `>` là một
            // phím vừa gõ — dán cả khối XML kết thúc bằng `>` thì KHÔNG, vì lúc ấy thẻ đóng
            // đã nằm sẵn trong thứ vừa dán.
            for ky_tu in "<ghi_chu>" { controller.typeForSelfTest(String(ky_tu)) }
            guard controller.editorDocument.buffer.text == "<ghi_chu></ghi_chu>" else {
                return "gõ thẻ mở mà ra "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }
            guard controller.caretOffsetForSelfTest == "<ghi_chu>".utf8.count else {
                return "con nháy không nằm giữa hai thẻ: byte \(controller.caretOffsetForSelfTest)"
            }

            // Trong ngôn ngữ KHÁC thì `>` là toán tử — không được chèn gì.
            controller.prepareSelfTestEditToDocument("")
            controller.setSyntaxLanguageForSelfTest(.python)
            for ky_tu in "if a > b:" { controller.typeForSelfTest(String(ky_tu)) }
            guard controller.editorDocument.buffer.text == "if a > b:" else {
                return "tự chèn thẻ vào mã Python: "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // FR-CORE-002 — chọn khối chữ nhật KHÔNG cần chuột.
        //
        // Đặc tả đòi cả hai đường; trước nay chỉ có Option+kéo. Với người chỉ dùng bàn phím
        // (NFR-USE-03) thì đây là đường DUY NHẤT tới chế độ cột và Column Editor.
        Case(name: "chọn khối cột bằng Option+Cmd+mũi tên") { controller in
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestEditToDocument("abcd\nefgh\nijkl\n")
            controller.setSelectionForSelfTest(documentRange: 1 ..< 1)   // dòng 1, cột 1

            let view = controller.editorView
            view.extendColumnSelection(.right)
            view.extendColumnSelection(.down)
            view.extendColumnSelection(.down)

            // Khối 3 dòng × 1 cột: ký tự thứ 2 của mỗi dòng — b · f · j.
            let ranges = view.selection.ranges
            guard ranges.count == 3 else {
                return "khối kéo qua 3 dòng mà ra \(ranges.count) vùng chọn"
            }
            let buffer = controller.editorDocument.buffer
            let text = ranges.map { String(decoding: buffer.bytes(in: $0), as: UTF8.self) }
            guard text == ["b", "f", "j"] else {
                return "khối chọn ra \(text), mong [b, f, j]"
            }

            // Một phím KHÁC phải kết thúc khối: giữ neo lại thì lần Option+Cmd+mũi tên sau đó
            // kéo khối từ một chỗ người dùng đã rời đi từ lâu.
            controller.typeForSelfTest("x")
            guard view.columnKeyboardAnchorForSelfTest == nil else {
                return "gõ chữ xong mà neo khối vẫn còn"
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // FR-CORE-009 — thụt lề đi theo NGÔN NGỮ, không phải một con số cho cả app.
        //
        // Người ta không chọn thụt lề theo sở thích mà theo quy ước từng cộng đồng: Go dùng
        // TAB, Python 4 dấu cách, JavaScript thường 2. Một con số chung nghĩa là mỗi tệp chạm
        // vào là một lần diff mọc thêm những dòng họ không hề sửa.
        Case(name: "thụt lề đi theo ngôn ngữ của tệp đang mở") { controller in
            let folder = NSTemporaryDirectory() + "indent-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer {
                controller.setLanguageIndentForSelfTest("go", nil)
                controller.setLanguageIndentForSelfTest("python", nil)
                controller.resetTabsForSelfTest()
                try? FileManager.default.removeItem(atPath: folder)
            }
            let go = (folder as NSString).appendingPathComponent("a.go")
            let py = (folder as NSString).appendingPathComponent("b.py")
            try? "package main\n".write(toFile: go, atomically: true, encoding: .utf8)
            try? "def f():\n    return 1\n".write(toFile: py, atomically: true, encoding: .utf8)

            controller.setLanguageIndentForSelfTest("go", .init(width: 8, usesTabs: true))
            controller.setLanguageIndentForSelfTest("python", .init(width: 4, usesTabs: false))

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: go)
            guard controller.tabWidthForSelfTest == 8 else {
                return "mở tệp .go mà thanh trạng thái ghi Tab: \(controller.tabWidthForSelfTest)"
            }
            guard controller.effectiveIndent.usesTabs else {
                return "khai Go dùng TAB mà thụt lề hiệu lực vẫn là dấu cách"
            }

            // Đổi tab: thụt lề phải ĐI THEO, không giữ con số của tệp trước.
            controller.openInNewTabForSelfTest(path: py)
            guard controller.tabWidthForSelfTest == 4 else {
                return "sang tệp .py mà vẫn giữ Tab: \(controller.tabWidthForSelfTest) của Go"
            }
            guard !controller.effectiveIndent.usesTabs else {
                return "sang Python mà vẫn dùng TAB của Go"
            }

            // Ngôn ngữ KHÔNG khai riêng thì rơi về cài đặt chung.
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestEditToDocument("chỉ là văn bản\n")
            guard controller.tabWidthForSelfTest == controller.settingsTabWidthForSelfTest else {
                return "tệp không khai riêng mà không dùng cài đặt chung: "
                    + "\(controller.tabWidthForSelfTest) ≠ \(controller.settingsTabWidthForSelfTest)"
            }
            return nil
        },

        // FR-SRCH-105 — lượt tìm sau không được XOÁ SẠCH lượt trước, và kết quả xuất ra được.
        //
        // Thói quen có thật: tìm `TODO`, đọc dở, tìm `FIXME` để so, rồi muốn quay lại danh sách
        // đầu. Trước đây đường quay lại duy nhất là chạy lại cả phép tìm trên thư mục.
        Case(name: "kết quả tìm: giữ lượt trước và xuất ra tab được") { controller in
            func summary(_ path: String, _ dong: [String]) -> FindInFiles.Summary {
                let hits = dong.enumerated().map { index, text in
                    FindInFiles.Hit(byteRange: 0 ..< 1, line: index + 1, byteColumn: 3,
                                    lineText: text)
                }
                return FindInFiles.Summary(
                    results: [FindInFiles.FileResult(path: path, hits: hits)], filesScanned: 1)
            }

            controller.resetTabsForSelfTest()
            controller.showSearchResultsForSelfTest(summary("/tmp/a.swift", ["// TODO một"]),
                                                    pattern: "TODO")
            controller.showSearchResultsForSelfTest(
                summary("/tmp/b.swift", ["// FIXME hai", "// FIXME ba"]), pattern: "FIXME")

            let titles = controller.searchHistoryTitlesForSelfTest
            guard titles.count == 2 else {
                return "hai lượt tìm mà lịch sử có \(titles.count) mục: \(titles)"
            }
            guard titles[0].contains("FIXME"), titles[1].contains("TODO") else {
                return "lịch sử không xếp lượt mới nhất lên đầu: \(titles)"
            }

            // Quay lại lượt CŨ thì panel phải hiện đúng nội dung của nó.
            controller.selectSearchHistoryForSelfTest(1)
            guard controller.searchResultsSummaryForSelfTest.contains("TODO") else {
                return "chọn lượt cũ mà panel vẫn ghi "
                    + "«\(controller.searchResultsSummaryForSelfTest)»"
            }

            // Xuất ra: một TAB MỚI, định dạng đường-dẫn:dòng:cột như grep -n.
            let truoc = controller.tabCountForSelfTest
            controller.exportSearchResultsForSelfTest()
            guard controller.tabCountForSelfTest == truoc + 1 else {
                return "bấm Xuất mà không mở tab nào"
            }
            let text = controller.editorDocument.buffer.text
            guard text.contains("/tmp/a.swift:1:3: // TODO một") else {
                return "tab xuất ra không đúng định dạng grep: "
                    + String(reflecting: String(text.prefix(200)))
            }
            // Xuất lượt ĐANG XEM, không phải lượt mới nhất — người dùng vừa chọn lượt cũ.
            guard !text.contains("FIXME") else {
                return "xuất nhầm lượt: đang xem lượt TODO mà ra kết quả FIXME"
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // FR-AUTO-602 — mask gõ ở hộp chọn thư mục phải tới được phép lọc tệp.
        //
        // Phép lọc đã có bài ở lõi (`MacroBatchTests`); bài này kiểm DÂY NỐI, thứ lõi không
        // thấy: ô nhập nằm trong `NSOpenPanel`, và mọi thứ gộp chung với hộp chọn tệp là mã
        // không bài kiểm nào chạm tới — đúng chỗ hở mà cổng độ phủ tầng app đã lộ ra hôm 04/09.
        Case(name: "batch macro chỉ chạy trên tệp khớp mask") { controller in
            let dir = NSTemporaryDirectory() + "macro-mask-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }
            try? "cu cu\n".write(toFile: dir + "/a.csv", atomically: true, encoding: .utf8)
            try? "cu cu\n".write(toFile: dir + "/b.json", atomically: true, encoding: .utf8)

            controller.setMacroForSelfTest([
                .find(pattern: "cu", mode: .normal, matchCase: true, wholeWord: false),
                .replaceSelection("moi"),
            ])
            controller.playMacroOnFolderForSelfTest(path: dir, mask: "*.csv", force: true)
            _ = controller.waitForSelfTestPublic("batch macro", seconds: 10, until: {
                FileManager.default.fileExists(atPath: dir + "/a-macro.csv")
            })

            guard FileManager.default.fileExists(atPath: dir + "/a-macro.csv") else {
                return "tệp khớp mask không được xử lý"
            }
            guard !FileManager.default.fileExists(atPath: dir + "/b-macro.json") else {
                return "tệp KHÔNG khớp mask vẫn bị xử lý — mask chỉ là một ô nhập trang trí"
            }
            guard (try? String(contentsOfFile: dir + "/b.json", encoding: .utf8)) == "cu cu\n" else {
                return "tệp ngoài mask bị sửa"
            }

            // Chờ tác vụ nền XONG HẲN, không dừng ở lúc tệp kết quả vừa hiện ra.
            //
            // Batch chạy ở luồng nền và khi xong nó mở một TAB báo cáo. Bài kiểm thoát sớm thì
            // cú mở tab ấy rơi vào GIỮA bài kế tiếp — và vì đổi tài liệu là đóng mọi panel
            // phân tích, bài kế tiếp thấy panel của nó biến mất mà không hiểu vì sao. Đã gặp
            // thật: bài «panel phân tích» đỏ khi chạy cả bộ, xanh khi chạy riêng.
            _ = controller.waitForSelfTestPublic("báo cáo batch", seconds: 10, until: {
                controller.lastTransientForSelfTest.contains("file xong")
            })

            // Mask không khớp gì thì phải NÓI RA mask, không đổ cho thư mục rỗng.
            controller.playMacroOnFolderForSelfTest(path: dir, mask: "*.khong-co", force: true)
            guard controller.bannerMessageForSelfTest.contains("khong-co") else {
                return "mask không khớp gì mà thông báo không nhắc tới mask: "
                    + "«\(controller.bannerMessageForSelfTest)»"
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // FR-CORE-018 — thanh trạng thái phải nói ĐỦ: dòng · cột · offset · cỡ tài liệu.
        //
        // Offset là thứ bắc cầu giữa thanh trạng thái và mọi công cụ khác của sản phẩm: lỗi
        // JSON/XML, `--doc-sweep`, khung xem nhị phân, ô «Đi tới @1024» đều nói bằng offset.
        // Thiếu nó thì hai nửa ấy không nối được với nhau.
        Case(name: "thanh trạng thái nói đủ offset và cỡ tài liệu") { controller in
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestEditToDocument("mot\nhai\nba\n")
            controller.goToForSelfTest("@5")

            let caret = controller.statusCaretTitleForSelfTest
            guard caret.contains("@5") else {
                return "con nháy ở byte 5 mà mục vị trí ghi «\(caret)»"
            }
            let size = controller.statusDocSizeTitleForSelfTest
            guard size.contains("11"), size.contains("3") else {
                return "tài liệu 11 byte · 3 dòng mà mục cỡ ghi «\(size)»"
            }

            // Bấm vào mục ấy thì đếm đủ ký tự và từ — con số chỉ tính khi người dùng hỏi.
            controller.clearTransientForSelfTest()
            controller.clickStatusSegmentForSelfTest(.docSize)
            let tin = controller.lastTransientForSelfTest
            guard tin.contains("từ") || tin.contains("word") else {
                return "bấm mục cỡ tài liệu mà không đếm được từ: «\(tin)»"
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // FR-SRCH-111 — ô «Đi tới» hiểu cả ba cách viết, và NÓI RA khi không hiểu.
        //
        // Phép phân tích chuỗi đã có bài ở lõi (`GoToTargetTests`); bài này kiểm phần lõi không
        // với tới được: con nháy có ĐẶT ĐÚNG CHỖ không. Cột đếm theo ký tự còn offset đếm theo
        // byte, nên một dòng tiếng Việt là chỗ hai con số ấy tách nhau ra.
        Case(name: "đi tới: số dòng · dòng,cột · @offset") { controller in
            controller.resetTabsForSelfTest()
            // Dòng 2 có dấu tiếng Việt: "Nguyễn" là 6 ký tự nhưng 8 byte.
            controller.prepareSelfTestEditToDocument("mot\nNguyễn Văn A\nba\n")

            guard controller.goToForSelfTest("3") else { return "không đi tới được dòng 3" }
            guard controller.caretOffsetForSelfTest == "mot\nNguyễn Văn A\n".utf8.count else {
                return "đi tới dòng 3 mà con nháy ở byte \(controller.caretOffsetForSelfTest)"
            }

            // Cột 8 của dòng 2 = sau "Nguyễn " (7 ký tự = 9 byte).
            guard controller.goToForSelfTest("2,8") else { return "không đi tới được 2,8" }
            let mong = "mot\n".utf8.count + "Nguyễn ".utf8.count
            guard controller.caretOffsetForSelfTest == mong else {
                return "cột 8 của dòng tiếng Việt ra byte "
                    + "\(controller.caretOffsetForSelfTest), mong \(mong) — cột đang bị đếm "
                    + "theo byte thay vì theo ký tự"
            }

            guard controller.goToForSelfTest("@5") else { return "không đi tới được @5" }
            guard controller.caretOffsetForSelfTest == 5 else {
                return "@5 ra byte \(controller.caretOffsetForSelfTest)"
            }

            // Cột vượt quá dòng thì dừng ở CUỐI DÒNG ấy, không tràn sang dòng sau.
            guard controller.goToForSelfTest("1,999") else { return "không đi tới được 1,999" }
            guard controller.caretOffsetForSelfTest == 3 else {
                return "cột vượt quá dòng ra byte \(controller.caretOffsetForSelfTest), "
                    + "mong 3 (cuối dòng 1)"
            }

            // Chuỗi không hiểu phải NÓI RA, không im lặng nhảy về đầu tài liệu.
            controller.clearTransientForSelfTest()
            guard !controller.goToForSelfTest("linh tinh") else {
                return "chuỗi vô nghĩa mà vẫn nhận"
            }
            guard controller.lastTransientForSelfTest.contains("Không hiểu") else {
                return "chuỗi vô nghĩa mà không nói gì: «\(controller.lastTransientForSelfTest)»"
            }
            guard controller.caretOffsetForSelfTest == 3 else {
                return "chuỗi vô nghĩa mà con nháy vẫn nhảy đi mất"
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // Panel phân tích không được trưng kết quả của một tài liệu KHÁC.
        //
        // Cột panel là chỗ trả lời cho câu hỏi "tệp này có gì": kiểm tra dữ liệu, làm sạch,
        // chất lượng, tương quan, SQL. Chúng sống qua lần đổi tab, nên bảng «Kiểm tra dữ liệu:
        // 2 lỗi ở cột y» nằm nguyên đó khi người dùng đã sang một tệp .txt không có cột nào —
        // và những ô tô đỏ trên bảng CSV thì được đánh theo SỐ HÀNG của tài liệu cũ.
        Case(name: "panel phân tích không sống qua lần đổi tài liệu") { controller in
            let folder = NSTemporaryDirectory() + "panel-doi-tab-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer {
                controller.resetTabsForSelfTest()
                try? FileManager.default.removeItem(atPath: folder)
            }
            let csv = (folder as NSString).appendingPathComponent("so-lieu.csv")
            let txt = (folder as NSString).appendingPathComponent("ghi-chu.txt")
            try? "x,y\n1,2\n3,khong-phai-so\n4,5\n".write(
                toFile: csv, atomically: true, encoding: .utf8)
            try? "chỉ là văn bản, không có cột nào\n".write(
                toFile: txt, atomically: true, encoding: .utf8)

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: csv)
            controller.validateForSelfTest()
            guard controller.validationPanelVisibleForSelfTest else {
                return "không mở được panel kiểm tra — bài này không kiểm được gì"
            }

            // Đổi TAB.
            controller.openInNewTabForSelfTest(path: txt)
            guard !controller.validationPanelVisibleForSelfTest else {
                return "sang tab .txt mà panel kiểm tra vẫn trưng kết quả của tệp CSV, "
                    + "tên cột \(controller.validationColumnNamesForSelfTest)"
            }
            guard controller.csvTypeIssueRowsForSelfTest.isEmpty else {
                return "ô tô đỏ của tài liệu cũ còn lại \(controller.csvTypeIssueRowsForSelfTest.count) hàng"
            }

            // Và đổi TÀI LIỆU TRONG CÙNG MỘT TAB — đường thứ hai tới cùng chỗ hỏng.
            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: csv)
            controller.validateForSelfTest()
            guard controller.validationPanelVisibleForSelfTest else {
                return "không mở lại được panel kiểm tra ở lượt hai"
            }
            controller.open(path: txt)
            guard !controller.validationPanelVisibleForSelfTest else {
                return "mở tệp khác trong CÙNG tab mà panel kiểm tra vẫn còn kết quả cũ"
            }
            return nil
        },

        // Chỉ mục hàng CSV dựng cho tab NÀY không được đem đọc buffer của tab KHÁC.
        //
        // `csvIndex` là bảng OFFSET BYTE — nó chỉ đúng với đúng một nội dung. Nó lại là biến
        // của cửa sổ, nên sau khi mở bảng ở một tab rồi sang tab khác, `showValidationPanel`
        // vẫn cầm chỉ mục cũ (`csvIndex ?? build(...)`) và đọc tên cột ở những offset thuộc về
        // tài liệu trước. Kết quả: panel gọi tên cột bằng chữ lấy từ một tệp khác — hoặc, nếu
        // tệp mới ngắn hơn, đọc ra ngoài phạm vi.
        Case(name: "chỉ mục hàng CSV không rò từ tab này sang tab khác") { controller in
            let folder = NSTemporaryDirectory() + "csv-index-tab-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer {
                controller.resetTabsForSelfTest()
                try? FileManager.default.removeItem(atPath: folder)
            }

            // Tab A dài và rộng; tab B ngắn hơn hẳn, nên offset của A trỏ ra ngoài B.
            let a = (folder as NSString).appendingPathComponent("a.csv")
            let b = (folder as NSString).appendingPathComponent("b.csv")
            var rong = "alpha,beta,gamma\n"
            for i in 0 ..< 200 { rong += "gia-tri-\(i),gia-tri-\(i),gia-tri-\(i)\n" }
            try? rong.write(toFile: a, atomically: true, encoding: .utf8)
            try? "x,y\n1,2\n3,khong-phai-so\n".write(toFile: b, atomically: true, encoding: .utf8)

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: a)
            controller.showTableViewForSelfTest()
            _ = controller.waitForSelfTestPublic("chỉ mục hàng", seconds: 10, until: {
                controller.csvIndexRowCountForSelfTest > 0
            })
            guard controller.csvIndexRowCountForSelfTest > 0 else {
                return "không dựng được chỉ mục cho tab đầu — bài này không kiểm được gì"
            }

            controller.openInNewTabForSelfTest(path: b)

            // Hỏi THẲNG cái đang sai, chứ không hỏi vòng qua một hậu quả.
            //
            // Bản đầu của bài này chỉ hỏi tên cột ở panel kiểm tra, và nó XANH trong khi chỉ mục
            // của tab trước vẫn còn nguyên 201 hàng: `CSVRowIndex.values` tình cờ kẹp lại theo
            // buffer mới nên hậu quả không lộ ra ở đúng chỗ ấy. Một phép hỏi xanh vì cái nó hỏi
            // không phải cái đang hỏng thì tệ hơn không có phép hỏi nào.
            guard controller.csvIndexRowCountForSelfTest == 0 else {
                return "sang tab khác mà chỉ mục cũ vẫn còn "
                    + "\(controller.csvIndexRowCountForSelfTest) hàng — nó là bảng OFFSET BYTE "
                    + "của một tài liệu không còn mở"
            }

            controller.validateForSelfTest()
            let names = controller.validationColumnNamesForSelfTest
            guard names == ["x", "y"] else {
                return "panel kiểm tra gọi tên cột là \(names) — tên cột của tab TRƯỚC"
            }
            return nil
        },

        // Mọi mục trên thanh trạng thái phải LÀM MỘT VIỆC khi bấm.
        //
        // UI/UX §3 bán đúng một điểm khác biệt: status bar ở đây bấm được, không phải chỉ để
        // đọc. Bốn mục cuối (`mode`, `language`, `tabWidth`, `readOnly`) từng rơi vào
        // `default: break` — bấm vào không có gì xảy ra, và người dùng không phân biệt được
        // "chưa làm" với "hỏng". Bài này đi qua cả bốn.
        Case(name: "bốn mục cuối của thanh trạng thái bấm vào là đổi được thật") { controller in
            // Bấm ĐÚNG cái nút trên thanh, rồi chọn trong menu vừa bung ra. Gọi thẳng
            // `buildModeMenu()` thì bài kiểm vẫn xanh cả khi dây nối từ cú bấm bị cắt — mà dây
            // nối đứt chính là hình dạng cũ của lỗi này (`default: break`).
            func bam(_ segment: StatusBarView.Segment, _ title: String) -> Bool {
                controller.clickStatusSegmentForSelfTest(segment)
                guard let menu = controller.lastPresentedMenuForSelfTest else { return false }
                guard let item = menu.items.first(where: {
                    $0.title.trimmingCharacters(in: .whitespaces) == title
                }), let action = item.action else { return false }
                return NSApp.sendAction(action, to: item.target, from: item)
            }

            controller.resetTabsForSelfTest()
            controller.prepareSelfTestEditToDocument("ten;tuoi\nAn;30\nBinh;25\n")
            controller.setCSVModeForSelfTest(true)

            // VẾ MỘT — chọn lại DẤU PHÂN TÁCH.
            //
            // Phép đoán theo nội dung sai là lỗi im lặng nhất của cả nhóm CSV: mọi thao tác cột
            // sau đó đều lệch mà không có gì báo. Đường sửa duy nhất là mục này.
            guard bam(.mode, "gạch đứng") else {
                return "menu chế độ không có mục «gạch đứng»"
            }
            guard controller.statusModeForSelfTest?.contains("gạch đứng") == true else {
                return "chọn gạch đứng mà thanh trạng thái ghi "
                    + "«\(controller.statusModeForSelfTest ?? "trống")»"
            }
            guard controller.csvDialectForSelfTest.delimiter == UInt8(ascii: "|") else {
                return "nhãn đổi mà phép tách cột thì không — đúng kiểu hỏng tệ nhất"
            }
            guard bam(.mode, L("Tự nhận diện")) else {
                return "menu chế độ không có mục «Tự nhận diện»"
            }
            guard controller.csvDialectForSelfTest.delimiter == UInt8(ascii: ";") else {
                return "bỏ chọn tay rồi mà không quay về phép đoán theo nội dung"
            }

            // VẾ HAI — chọn ngôn ngữ tô màu cho một tài liệu KHÔNG có đuôi tệp.
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestEditToDocument("def f():\n    return 1\n")
            guard bam(.language, "Python") else {
                return "menu ngôn ngữ không có mục «Python»"
            }
            guard controller.statusLanguageForSelfTest == "Python" else {
                return "chọn Python mà thanh trạng thái ghi «\(controller.statusLanguageForSelfTest)»"
            }
            guard bam(.language, L("Văn bản thuần")) else {
                return "menu ngôn ngữ không có mục «Văn bản thuần»"
            }
            guard controller.statusLanguageForSelfTest == L("Văn bản thuần") else {
                return "tắt tô màu mà thanh trạng thái vẫn ghi "
                    + "«\(controller.statusLanguageForSelfTest)»"
            }

            // VẾ BA — độ rộng tab.
            let cu = controller.tabWidthForSelfTest
            defer { _ = bam(.tabWidth, LF("%d dấu cách", cu)) }
            guard bam(.tabWidth, LF("%d dấu cách", cu == 8 ? 2 : 8)) else {
                return "menu độ rộng tab không có mục nào khác giá trị đang dùng"
            }
            guard controller.tabWidthForSelfTest == (cu == 8 ? 2 : 8) else {
                return "chọn độ rộng tab mà con số không đổi: \(controller.tabWidthForSelfTest)"
            }

            // VẾ BỐN — mục chỉ đọc phải NÓI RA điều gì đó, dù nói "đang sửa được".
            controller.clearTransientForSelfTest()
            controller.clickStatusSegmentForSelfTest(.readOnly)
            guard !controller.lastTransientForSelfTest.isEmpty else {
                return "bấm mục chỉ đọc mà không có gì xảy ra"
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // Dòng log mới của tab ĐANG THEO DÕI không được rơi vào tab người dùng đang gõ.
        //
        // Bộ theo dõi từng là một biến của CỬA SỔ, còn `handleTailChange` thì làm việc trên
        // `editorDocument` — tức tài liệu ĐANG HIỆN. Ghép hai điều ấy lại: bật theo dõi một file
        // log ở tab 1, sang tab 2 gõ dở, và dòng log kế tiếp nạp lại tab 2 từ đĩa rồi đặt nó
        // thành chỉ đọc. Phần vừa gõ mất, không một thông báo nào, và nguyên nhân nằm ở một tab
        // họ không nhìn thấy.
        Case(name: "dòng log mới rơi đúng tab đang theo dõi, không rơi vào tab đang gõ") { controller in
            let folder = NSTemporaryDirectory() + "tail-tab-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            let log = (folder as NSString).appendingPathComponent("a.log")
            let notes = (folder as NSString).appendingPathComponent("b.txt")
            try? "dòng 1\n".write(toFile: log, atomically: true, encoding: .utf8)
            try? "ghi chú gốc\n".write(toFile: notes, atomically: true, encoding: .utf8)
            defer {
                if controller.isFollowingTail { controller.toggleFollowTail(nil) }
                controller.resetTabsForSelfTest()
                try? FileManager.default.removeItem(atPath: folder)
            }

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: log)
            controller.toggleFollowTail(nil)
            guard controller.isFollowingTail else { return "không bật được chế độ theo dõi" }
            // Trạng thái bền phải NÓI RA — dải băng thoáng qua thì vài giây sau không còn gì
            // giải thích vì sao tài liệu không gõ được.
            guard controller.statusModeForSelfTest?.contains(L("Đang theo dõi")) == true else {
                return "đang theo dõi mà thanh trạng thái ghi "
                    + "«\(controller.statusModeForSelfTest ?? "trống")»"
            }

            // Sang tab thứ hai và gõ vào đó — đúng thứ người dùng làm trong lúc chờ log.
            controller.openInNewTabForSelfTest(path: notes)
            guard controller.isFollowingTail == false else {
                return "sang tab khác mà nó vẫn tự nhận là đang theo dõi"
            }
            guard controller.statusModeForSelfTest?.contains(L("Đang theo dõi")) != true else {
                return "tab không theo dõi mà thanh trạng thái vẫn nói «Đang theo dõi»"
            }
            controller.prepareSelfTestEditToDocument("ghi chú gốc\nđang gõ dở\n")
            guard !controller.editorDocument.isReadOnly else {
                return "tab đang gõ đã bị khoá chỉ đọc trước cả khi log có dòng mới"
            }

            // Log có dòng mới trong lúc người dùng đang ở tab kia.
            let handle = FileHandle(forWritingAtPath: log)!
            handle.seekToEndOfFile()
            handle.write(Data("dòng 2\n".utf8))
            try? handle.close()
            controller.pollTailForSelfTestInAnyTab()

            let visible = controller.editorDocument.buffer.text
            guard visible == "ghi chú gốc\nđang gõ dở\n" else {
                return "dòng log rơi vào tab đang gõ: nội dung nay là "
                    + String(reflecting: visible)
            }
            guard !controller.editorDocument.isReadOnly else {
                return "tab đang gõ bị khoá chỉ đọc vì một tab khác đang theo dõi file"
            }

            // Và tab đang theo dõi thì phải NHẬN được dòng mới — nếu không thì bài này xanh
            // chỉ vì tính năng đã chết hẳn.
            controller.activateTabForSelfTest(path: log)
            guard controller.editorDocument.buffer.text == "dòng 1\ndòng 2\n" else {
                return "tab đang theo dõi không nhận dòng mới: "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }
            return nil
        },

        Case(name: "gõ vào ô Tìm là nhảy tới ngay, và tô hết mọi kết quả") { controller in
            controller.prepareSelfTestDocument("alpha\nbeta\nalpha\ngamma\nalpha\n")
            controller.showFindPanel(nil)
            defer { controller.handleFindActionForSelfTest(.close) }

            // Gõ dở: "al" đã phải khớp rồi, chứ không đợi bấm Enter.
            controller.typeIntoFindFieldForSelfTest("al")
            guard controller.searchHighlightsForSelfTest.count == 3 else {
                return "gõ «al» ra \(controller.searchHighlightsForSelfTest.count) kết quả, mong 3"
            }
            guard controller.caretOffsetForSelfTest == 0 else {
                return "chưa nhảy tới kết quả đầu: con nháy ở \(controller.caretOffsetForSelfTest)"
            }

            // Gõ thêm một ký tự nữa cho hẹp lại tới mức không còn gì.
            controller.typeIntoFindFieldForSelfTest("alphaz")
            guard controller.searchHighlightsForSelfTest.isEmpty else {
                return "«alphaz» không có trong tài liệu mà vẫn tô "
                    + "\(controller.searchHighlightsForSelfTest.count) chỗ"
            }

            // Tìm tiếp từ CHỖ ĐANG ĐỨNG, không phải từ đầu file: người dùng đọc ở giữa tài
            // liệu mà bị ném về đầu là mất chỗ đang đọc.
            // "alpha" ở byte 0, 11 và 23. Đứng ở byte 6 (đầu "beta") thì phải tới 11, không
            // phải quay về 0.
            controller.setCaretForSelfTest(documentOffset: 6)
            controller.typeIntoFindFieldForSelfTest("alpha")
            guard controller.caretOffsetForSelfTest == 11 else {
                return "đứng ở byte 6 mà nhảy tới \(controller.caretOffsetForSelfTest), mong 11"
            }

            // Xoá sạch ô Tìm phải xoá cả phần tô — không để lại nền vàng của phép tìm đã xong.
            controller.typeIntoFindFieldForSelfTest("")
            guard controller.searchHighlightsForSelfTest.isEmpty else {
                return "ô Tìm rỗng mà còn \(controller.searchHighlightsForSelfTest.count) chỗ tô"
            }
            return nil
        },

        Case(name: "Enter giữ thụt lề, và thêm một bậc sau dấu mở khối") { controller in
            // Đi qua `insertNewline` của NSTextView — đúng đường phím Enter đi. Gọi thẳng
            // `SmartIndent` thì chỉ kiểm lại phép tính đã có test lõi, không kiểm được thứ
            // đáng ngờ ở đây: dây nối giữa AppKit và lõi.
            controller.prepareSelfTestDocument("    let a = 1\n")
            controller.setSyntaxLanguageForSelfTest(.rust)
            controller.setCaretForSelfTest(documentOffset: 13)          // cuối dòng
            controller.insertNewlineForSelfTest()
            guard controller.editorDocument.buffer.text == "    let a = 1\n    \n" else {
                return "thừa hưởng thụt lề ra \(String(reflecting: controller.editorDocument.buffer.text))"
            }

            controller.prepareSelfTestDocument("fn main() {\n")
            controller.setSyntaxLanguageForSelfTest(.rust)
            controller.setCaretForSelfTest(documentOffset: 11)
            controller.insertNewlineForSelfTest()
            guard controller.editorDocument.buffer.text == "fn main() {\n    \n" else {
                return "sau dấu mở khối ra \(String(reflecting: controller.editorDocument.buffer.text))"
            }

            // Đối chứng âm: văn bản thuần KHÔNG được đoán khối, chỉ thừa hưởng thụt lề.
            controller.prepareSelfTestDocument("ghi chú {\n")
            controller.setSyntaxLanguageForSelfTest(nil)
            controller.setCaretForSelfTest(documentOffset: 10)   // "ghi chú {" là 10 BYTE — ú chiếm 2
            controller.insertNewlineForSelfTest()
            guard controller.editorDocument.buffer.text == "ghi chú {\n\n" else {
                return "văn bản thuần bị thêm thụt lề: "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }
            return nil
        },

        Case(name: "khớp ngoặc bỏ qua dấu nằm trong chuỗi và chú thích") { controller in
            controller.prepareSelfTestDocument("f(\"a)b\", x)\n")
            controller.setSyntaxLanguageForSelfTest(.c)
            controller.setCaretForSelfTest(documentOffset: 1)           // dấu (
            guard let match = controller.currentBracketMatch() else {
                return "không tìm ra cặp ngoặc nào"
            }
            guard match.close == 10 else {
                return "khớp với byte \(match.close), mong 10 — dấu ) trong chuỗi bị tính nhầm"
            }
            controller.goToMatchingBracket(nil)
            guard controller.editorDocument.buffer.lineNumber(
                atOffset: controller.caretOffsetForSelfTest
            ) == 0, controller.caretOffsetForSelfTest == 10 else {
                return "nhảy tới byte \(controller.caretOffsetForSelfTest), mong 10"
            }
            return nil
        },

        Case(name: "lịch sử clipboard nhớ đúng thứ tự và không sinh bản trùng") { controller in
            controller.prepareSelfTestDocument("một\nhai\n")
            controller.clipboardRing.clear()

            controller.setSelectionForSelfTest(documentRange: 0 ..< 5)   // "một" là 5 BYTE
            controller.copySelection(nil)
            controller.setSelectionForSelfTest(documentRange: 6 ..< 9)   // "hai"
            controller.copySelection(nil)
            guard controller.clipboardRing.entries == ["hai", "một"] else {
                return "lịch sử ra \(controller.clipboardRing.entries)"
            }

            // Chép lại đoạn cũ thì NÂNG LÊN đầu, không thêm mục thứ ba.
            controller.setSelectionForSelfTest(documentRange: 0 ..< 5)
            controller.copySelection(nil)
            guard controller.clipboardRing.entries == ["một", "hai"] else {
                return "chép lại sinh trùng: \(controller.clipboardRing.entries)"
            }
            return nil
        },

        Case(name: "cắt khoảng trắng khi lưu chỉ chạy khi được bật") { controller in
            let path = NSTemporaryDirectory() + "geditor-selftest-trim.txt"
            defer { try? FileManager.default.removeItem(atPath: path) }

            // TẮT (mặc định): lưu không được đụng vào khoảng trắng người dùng đã gõ.
            controller.prepareSelfTestDocument("a   \nb\t\n")
            controller.setTrimOnSaveForSelfTest(false)
            controller.saveDocumentToPathForSelfTest(path)
            guard controller.editorDocument.buffer.text == "a   \nb\t\n" else {
                return "đang TẮT mà vẫn cắt: \(String(reflecting: controller.editorDocument.buffer.text))"
            }

            controller.setTrimOnSaveForSelfTest(true)
            controller.saveDocumentToPathForSelfTest(path)
            guard controller.editorDocument.buffer.text == "a\nb\n" else {
                return "đang BẬT mà không cắt: \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            // Là một bước hoàn tác RIÊNG: gộp vào thao tác cuối của người dùng thì ⌘Z sau khi
            // lưu sẽ gỡ luôn cả thứ họ vừa gõ.
            controller.undoDocument(nil)
            guard controller.editorDocument.buffer.text == "a   \nb\t\n" else {
                return "hoàn tác sau khi lưu không trả lại khoảng trắng"
            }
            controller.setTrimOnSaveForSelfTest(false)
            return nil
        },

        Case(name: "cài gói mở rộng rồi gỡ, không đụng file của người dùng") { controller in
            // FR-PLUG-701 · FR-PLUG-705. Bài này đi qua ĐÚNG thư mục dữ liệu thật mà ứng dụng
            // dùng, không phải một thư mục tạm — vì thứ đáng ngờ chính là chỗ nối giữa gói và
            // ba thư mục ấy, và một bài kiểm dùng thư mục riêng sẽ bỏ qua đúng chỗ đó.
            let destinations = controller.pluginDestinations
            for url in [destinations.scripts, destinations.themes, destinations.languages] {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            // File của riêng người dùng — gỡ gói KHÔNG được chạm vào nó.
            let mine = destinations.scripts.appendingPathComponent("cua-toi-selftest.js")
            try? "riêng".write(to: mine, atomically: true, encoding: .utf8)
            defer {
                PluginPackage.uninstall(name: "Gói tự kiểm", from: destinations)
                try? FileManager.default.removeItem(at: mine)
            }

            let package = PluginPackage(
                name: "Gói tự kiểm", version: "1.0.0",
                scripts: ["đánh-số": "doc.log('x');"], themes: [Theme.than]
            )
            guard (try? package.install(into: destinations)) != nil else {
                return "không cài được gói"
            }
            guard PluginPackage.installedNames(in: destinations).contains("goi-tu-kiem") else {
                return "cài xong mà không thấy trong danh sách"
            }
            // Theme của gói phải hiện ra trong danh sách theme THẬT của ứng dụng.
            guard controller.availableThemeNames().contains(Theme.than.name) else {
                return "theme trong gói không vào được danh sách theme"
            }

            let removed = PluginPackage.uninstall(name: "Gói tự kiểm", from: destinations)
            guard removed.count == 2 else { return "gỡ ra \(removed.count) file, mong 2" }
            guard FileManager.default.fileExists(atPath: mine.path) else {
                return "GỠ GÓI ĐÃ XOÁ FILE CỦA NGƯỜI DÙNG"
            }
            return nil
        },

        Case(name: "kéo tab sang cửa sổ khác dời đúng tài liệu, không nhân bản") { controller in
            // FR-DOC-302. Bất biến quan trọng nhất: tab ĐI, không phải được CHÉP. Một phép
            // "dời" thật ra là chép sẽ để lại hai tab cùng trỏ vào một tài liệu, hai khung soạn
            // thảo cùng ghi, và bên thua là phần người dùng vừa gõ.
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let dir = NSTemporaryDirectory() + "geditor-selftest-windows"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }
            let paths = (0 ..< 2).map { "\(dir)/w\($0).txt" }
            for (index, path) in paths.enumerated() {
                try? "nội dung \(index)\n".write(toFile: path, atomically: true, encoding: .utf8)
            }
            for path in paths { controller.openInNewTabForSelfTest(path: path) }

            let target = WindowManager.shared.newWindow()
            defer { target.close() }
            guard WindowManager.shared.controllers.count >= 2 else {
                return "không mở được cửa sổ thứ hai"
            }

            let before = controller.tabCountForSelfTest
            let movedPath = paths[0]
            let index = controller.tabPathsForSelfTest.firstIndex(of: movedPath) ?? 0

            // Thả vào GIỮA cửa sổ đích, tính theo toạ độ màn hình — đúng thứ vòng kéo truyền vào.
            guard let frame = target.window?.frame else { return "cửa sổ đích không có khung" }
            controller.dropTabAtScreenPointForSelfTest(
                index, NSPoint(x: frame.midX, y: frame.midY)
            )

            guard controller.tabCountForSelfTest == before - 1 else {
                return "cửa sổ nguồn còn \(controller.tabCountForSelfTest) tab, mong \(before - 1)"
            }
            guard !controller.tabPathsForSelfTest.contains(movedPath) else {
                return "tab vẫn còn ở cửa sổ nguồn — đây là CHÉP chứ không phải DỜI"
            }
            guard target.tabPathsForSelfTest.contains(movedPath) else {
                return "cửa sổ đích không nhận được tab: \(target.tabPathsForSelfTest)"
            }
            // Và nó phải là tab ĐANG MỞ ở cửa sổ đích: người dùng vừa kéo nó sang đây.
            guard target.editorDocument.path == movedPath else {
                return "tab tới nơi mà không được mở ra"
            }
            // Nội dung phải nguyên vẹn, không phải một tab rỗng mang đúng tên.
            guard target.editorDocument.buffer.text == "nội dung 0\n" else {
                return "nội dung sai: \(String(reflecting: target.editorDocument.buffer.text))"
            }
            return nil
        },

        // Bài ĐỐI CHỨNG ÂM cho một lỗi thật, và cho cách sửa nó.
        //
        // Trước 24/08/2026, mở một file không tồn tại trong lượt chạy tự kiểm làm
        // `presentError` bật `NSAlert.runModal()`, và hộp thoại không có ai bấm giữ luôn run
        // loop: bộ tự kiểm đứng im giữa chừng, không đỏ, không lỗi, không một dòng log. Triệu
        // chứng duy nhất là "hôm nay chạy lâu thế". Mất một buổi mới lần ra.
        //
        // Nên bài này KHÔNG kiểm tính năng nào. Nó kiểm rằng chính bộ tự kiểm còn chạy được:
        // gặp lỗi thì đi tiếp và ghi lại, chứ không treo.
        //
        // Đã kiểm ngược bằng cách gỡ nhánh `Unattended` khỏi `presentError` rồi chạy lại. Kết
        // quả đáng ghi lại vì nó khác điều tôi đoán: bài này **ĐỎ** ("app ghi 0 lỗi — mong đúng
        // 1"), chứ lượt ấy KHÔNG treo. Cộng với ba lượt đo trước đó — hai treo, một chạy hết —
        // kết luận đúng là: hộp thoại modal trong lượt chạy không người **khi treo khi không**.
        // Đó chính là lý do phải chặn nó chứ không phải sống chung: một lỗi lúc hiện lúc ẩn tốn
        // nhiều thời gian hơn hẳn một lỗi luôn hỏng. Dù rơi vào nhánh nào thì cũng lần ra được:
        // hoặc bài này đỏ, hoặc bộ kiểm đứng lại ở một bài mang đúng tên vấn đề.
        Case(name: "lỗi khi không có ai ngồi trước máy thì ghi lại, KHÔNG treo") { controller in
            guard Unattended.isActive else {
                return "cờ `Unattended` tắt trong chính lượt chạy tự kiểm — mọi hộp thoại báo lỗi sẽ treo"
            }
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            Unattended.resetLog()

            let missing = NSTemporaryDirectory() + "geditor-selftest-khong-co-that.txt"
            try? FileManager.default.removeItem(atPath: missing)
            // Nếu nhánh `Unattended` biến mất thì dòng dưới đây không bao giờ trả về.
            controller.openInNewTabForSelfTest(path: missing)

            guard Unattended.errorCount == 1 else {
                return "mở file không tồn tại mà app ghi \(Unattended.errorCount) lỗi — mong đúng 1"
            }
            guard let recorded = Unattended.lastError,
                  recorded.hasPrefix("Không mở được file") else {
                return "lỗi ghi lại không đúng thứ vừa xảy ra: \(Unattended.lastError ?? "không có")"
            }
            // Và tab hỏng KHÔNG được len vào cửa sổ.
            guard !controller.tabPathsForSelfTest.contains(missing) else {
                return "mở hỏng mà vẫn sinh ra một tab"
            }
            Unattended.resetLog()
            return nil
        },

        // Nửa còn lại của bài trên: hộp thoại HỎI, không phải hộp thoại báo tin.
        //
        // `presentError` chặn được vì nó không hỏi gì. Hộp thoại hỏi thì khác — tự bấm hộ là
        // bịa ra câu trả lời của người dùng. Nên `Unattended.ask` trả `.abort`, và mọi chỗ gọi
        // tự đi nhánh "người dùng huỷ" vốn đã có sẵn. Bài này canh cả ba mệnh đề: KHÔNG treo,
        // KHÔNG tự đồng ý, và CÓ ghi lại là đã hỏi.
        Case(name: "hộp thoại HỎI khi không có ai ngồi trước máy: huỷ, ghi lại, không treo") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument("noi dung\n")
            controller.typeForSelfTest("x")            // làm tab thành ĐÃ SỬA
            guard controller.editorDocument.isModified else {
                return "gõ vào mà tài liệu không được đánh dấu đã sửa"
            }
            Unattended.resetLog()

            let before = controller.tabCountForSelfTest
            // Nếu `Unattended.ask` biến mất thì dòng dưới đây không bao giờ trả về.
            controller.closeCurrentTab(nil)

            guard Unattended.promptCount == 1 else {
                return "đóng tab đã sửa mà app hỏi \(Unattended.promptCount) lần — mong đúng 1"
            }
            guard let prompt = Unattended.lastPrompt, prompt.contains("chưa lưu") else {
                return "câu hỏi ghi lại không đúng: \(Unattended.lastPrompt ?? "không có")"
            }
            // Và quan trọng nhất: KHÔNG tự đồng ý. Tab phải còn nguyên.
            guard controller.tabCountForSelfTest == before else {
                return "app tự bấm Đóng hộ người dùng — mất phần chưa lưu"
            }
            Unattended.resetLog()
            return nil
        },

        Case(name: "thanh trạng thái hiện cột THỊ GIÁC, không phải số byte") { controller in
            // Nhãn ghi "Cột". Trước 24/08/2026 nó hiện `byteColumn`, nên gõ "Nguyễn" xong thì
            // nó báo 9 trong khi người dùng đếm được 7 — một con số đúng về mặt máy móc và vô
            // dụng với người đang nhìn. Bài này đi qua ĐÚNG đường cập nhật thật của thanh ấy.
            controller.prepareSelfTestDocument("Nguyễn\tx\n")

            // Sau "Nguyễn" (6 ký tự, 8 byte) — cột phải là 7, không phải 9.
            controller.setCaretForSelfTest(documentOffset: 8)
            var status = controller.statusCaretColumnForSelfTest
            guard status.column == 7 else {
                return "sau `Nguyễn` báo cột \(status.column), mong 7 (byte thì ra 9)"
            }
            guard !status.approximate else { return "dòng ngắn mà lại báo ước lượng" }

            // Sau TAB — TAB đứng ở cột 6 nở tới nấc 8, nên cột hiện ra là 9.
            controller.setCaretForSelfTest(documentOffset: 9)
            status = controller.statusCaretColumnForSelfTest
            guard status.column == 9 else {
                return "sau TAB báo cột \(status.column), mong 9 (nấc tab 4)"
            }
            return nil
        },

        Case(name: "tab đang GHIM thì không dời sang cửa sổ khác được") { controller in
            // Ghim nghĩa là "giữ tab này ở đây". Để một cú kéo vô tình mang nó đi là làm hỏng
            // chính lời hứa của việc ghim.
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            let dir = NSTemporaryDirectory() + "geditor-selftest-pin"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }
            let path = dir + "/ghim.txt"
            let other = dir + "/khac.txt"
            try? "x\n".write(toFile: path, atomically: true, encoding: .utf8)
            // `khac.txt` phải TỒN TẠI. Trước đây dòng dưới mở một file chưa từng được tạo:
            // `openInNewTab` ném, `presentError` bật `NSAlert.runModal`, và một hộp thoại modal
            // không có ai bấm sẽ giữ luôn run loop — cả bộ tự kiểm đứng im ở bài thứ 53. Bản
            // release chạy nhanh nên đôi khi thoát được, bản debug thì treo khoảng hai trên ba
            // lần: đúng loại lỗi tệ nhất, vì nó trông như "máy chậm" chứ không như một lỗi.
            try? "y\n".write(toFile: other, atomically: true, encoding: .utf8)
            controller.openInNewTabForSelfTest(path: path)
            controller.openInNewTabForSelfTest(path: other)

            let index = controller.tabPathsForSelfTest.firstIndex(of: path) ?? 0
            controller.togglePinForSelfTest(index)
            guard controller.detachTabForSelfTest(index) == nil else {
                return "gỡ được tab đang ghim"
            }
            guard controller.tabPathsForSelfTest.contains(path) else {
                return "tab ghim biến mất khỏi cửa sổ"
            }
            return nil
        },

        Case(name: "phiên làm việc nhớ CẢ HAI cửa sổ, kèm khung") { controller in
            // FR-DOC-303 gặp FR-DOC-302: schema phiên đã có `windows: [SessionWindow]` từ lâu
            // nhưng app chỉ ghi một phần tử. Bài này khẳng định nó ghi đủ.
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            let second = WindowManager.shared.newWindow()
            defer { second.close() }

            let session = WindowManager.shared.currentSession
            guard session.windows.count >= 2 else {
                return "phiên chỉ ghi \(session.windows.count) cửa sổ"
            }
            // Khung của TỪNG cửa sổ phải khác nhau — cửa sổ mới đặt lệch, không chồng khít.
            let frames = session.windows.compactMap(\.frameRect)
            guard frames.count >= 2 else { return "phiên không ghi khung cửa sổ" }
            guard frames[0].origin != frames[1].origin else {
                return "hai cửa sổ chồng khít — người dùng bấm «Cửa sổ mới» mà tưởng không chạy"
            }
            return nil
        },

        Case(name: "AppleScript đọc và ghi được tài liệu, và tôn trọng chỉ đọc") { controller in
            // FR-AUTO-606. Bài này đi qua ĐÚNG các thuộc tính mà `.sdef` khai — nếu ai đó đổi
            // tên khoá ở một bên mà quên bên kia thì AppleScript sẽ im lặng trả về rỗng, và
            // không có gì báo cho ai biết.
            //
            // Điều nó KHÔNG kiểm được: bản thân đường AppleScript của hệ điều hành. Việc ấy
            // cần một bundle đã ký và quyền Automation — ghi ở docs/trang-thai.md §6.
            controller.prepareSelfTestDocument("nội dung ban đầu\n")
            guard NSApp.scriptingDocumentText == "nội dung ban đầu\n" else {
                return "đọc ra \(String(reflecting: NSApp.scriptingDocumentText))"
            }

            NSApp.scriptingDocumentText = "script vừa ghi\n"
            guard controller.editorDocument.buffer.text == "script vừa ghi\n" else {
                return "ghi không ăn: \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            // MỘT bước hoàn tác: script chạy khi người dùng không nhìn, nên đó đúng là lúc họ
            // cần lùi được nhất.
            controller.undoDocument(nil)
            guard controller.editorDocument.buffer.text == "nội dung ban đầu\n" else {
                return "một lần hoàn tác không gỡ được thay đổi của AppleScript"
            }

            controller.setSelectionForSelfTest(documentRange: 0 ..< 5)   // "nội" là 5 BYTE — n(1) ộ(3) i(1)
            guard NSApp.scriptingSelectedText == "nội" else {
                return "vùng chọn ra \(String(reflecting: NSApp.scriptingSelectedText))"
            }
            guard NSApp.scriptingDocumentPath.isEmpty else {
                return "tài liệu chưa lưu mà báo đường dẫn \(NSApp.scriptingDocumentPath)"
            }

            // Tài liệu chỉ đọc thì KHÔNG được ghi — và phải nói ra, không im lặng.
            controller.editorDocument.lockForReading()
            NSApp.scriptingDocumentText = "cố ghi vào tài liệu chỉ đọc"
            guard controller.editorDocument.buffer.text == "nội dung ban đầu\n" else {
                return "ghi được vào tài liệu ĐANG CHỈ ĐỌC"
            }
            return nil
        },

        Case(name: "Services nhận được văn bản và file từ ứng dụng khác") { controller in
            // FR-AUTO-606. Đi qua ĐÚNG hai hàm mà macOS gọi, kể cả đường báo lỗi — im lặng thì
            // người dùng chọn Services, không có gì xảy ra, và không biết vì sao.
            let provider = ServicesProvider(controller: controller)
            let pasteboard = NSPasteboard(name: .init("geditor-selftest-services"))

            pasteboard.clearContents()
            pasteboard.setString("một đoạn từ Safari", forType: .string)
            var message: NSString = ""
            provider.openSelectedTextInGEditor(pasteboard, userData: nil, error: &message)
            guard message.length == 0 else { return "báo lỗi dù có văn bản: \(message)" }
            guard controller.editorDocument.buffer.text == "một đoạn từ Safari" else {
                return "không mở ra đúng nội dung: "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }
            // Phải là tab CHƯA LƯU, không phải một file tạm nào đó trong /tmp.
            guard controller.editorDocument.path == nil else {
                return "ghi ra file \(controller.editorDocument.path!) thay vì tab chưa lưu"
            }

            // Pasteboard rỗng phải NÓI RA, không im lặng.
            pasteboard.clearContents()
            message = ""
            provider.openSelectedTextInGEditor(pasteboard, userData: nil, error: &message)
            guard message.length > 0 else { return "pasteboard rỗng mà không báo gì" }

            // Nhiều file thì mở NHIỀU tab, không chỉ file đầu.
            let dir = NSTemporaryDirectory() + "geditor-selftest-services"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }
            let paths = (0 ..< 3).map { "\(dir)/tep\($0).txt" }
            for path in paths { try? "x\n".write(toFile: path, atomically: true, encoding: .utf8) }

            let before = controller.tabCountForSelfTest
            pasteboard.clearContents()
            pasteboard.writeObjects(paths.map { NSURL(fileURLWithPath: $0) })
            message = ""
            provider.openSelectedFilesInGEditor(pasteboard, userData: nil, error: &message)
            guard message.length == 0 else { return "báo lỗi dù có file: \(message)" }
            guard controller.tabCountForSelfTest >= before + 3 else {
                return "chọn 3 file mà chỉ mở \(controller.tabCountForSelfTest - before) tab"
            }
            return nil
        },

        Case(name: "macro chạy cả thư mục: ghi file MỚI, không đụng file gốc") { controller in
            // FR-AUTO-602. Đây là thao tác KHÔNG LÙI ĐƯỢC trên file người dùng chưa mở, nên bất
            // biến quan trọng nhất là file gốc còn nguyên — kiểm nó ở tầng này chứ không chỉ ở
            // test lõi, vì đường giao diện mới là đường người dùng đi.
            _ = controller
            let dir = NSTemporaryDirectory() + "geditor-selftest-macrobatch"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }
            let path = dir + "/a.txt"
            try? "cu cu\n".write(toFile: path, atomically: true, encoding: .utf8)

            let macro = Macro(name: "đổi", steps: [
                .find(pattern: "cu", mode: .normal, matchCase: true, wholeWord: false),
                .replaceSelection("moi"),
            ])
            let result = MacroBatch.run(
                macro, on: MacroBatch.textFiles(in: dir), destination: .suffix("-macro")
            )
            guard result.succeededCount == 1 else { return "không chạy được: \(result.report)" }
            guard (try? String(contentsOfFile: path, encoding: .utf8)) == "cu cu\n" else {
                return "FILE GỐC BỊ ĐỔI — mặc định phải là không ghi đè"
            }
            guard let output = result.files.first?.outputPath,
                  (try? String(contentsOfFile: output, encoding: .utf8)) == "moi moi\n" else {
                return "kết quả không đúng"
            }
            // Chạy lần hai KHÔNG được xử lý lại chính kết quả của lần một.
            guard MacroBatch.textFiles(in: dir).count == 1 else {
                return "lần chạy sau sẽ nuốt cả file kết quả của lần trước"
            }
            return nil
        },

        Case(name: "script sửa được tài liệu, và script hỏng không làm hỏng tài liệu") { controller in
            controller.prepareSelfTestDocument("một\nhai\n")
            controller.runScript(source: "doc.replace(doc.text.toUpperCase());", name: "hoa.js")
            guard controller.editorDocument.buffer.text == "MỘT\nHAI\n" else {
                return "script không sửa được: \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            // Cả lần chạy là MỘT bước hoàn tác, như mọi thao tác khác của sản phẩm.
            controller.undoDocument(nil)
            guard controller.editorDocument.buffer.text == "một\nhai\n" else {
                return "một lần hoàn tác không gỡ được thay đổi của script"
            }

            // Script LỖI không được đụng vào tài liệu.
            let before = controller.editorDocument.buffer.text
            controller.runScript(source: "khong_ton_tai(", name: "hong.js")
            guard controller.editorDocument.buffer.text == before else {
                return "script lỗi mà tài liệu vẫn bị sửa"
            }

            // Script không gọi `replace` thì cũng không đổi gì.
            controller.runScript(source: "doc.log('chỉ ghi nhật ký');", name: "log.js")
            guard controller.editorDocument.buffer.text == before else {
                return "script không gọi replace mà tài liệu vẫn đổi"
            }

            // API phải HẸP: script không được với tới file hay tiến trình.
            let probe = ScriptRunner.run(
                source: "doc.replace(typeof require + ',' + typeof process);",
                text: "", selection: 0 ..< 0
            )
            guard probe.replacement == "undefined,undefined" else {
                return "API rộng hơn thiết kế: \(probe.replacement ?? "nil")"
            }
            return nil
        },

        Case(name: "script chạy vô hạn không treo ứng dụng") { controller in
            // Không có API công khai nào ngắt được một JSContext đang chạy, nên script chạy ở
            // luồng nền và luồng chính chỉ ĐỢI. Bài này khẳng định điều quan trọng nhất: quá
            // hạn thì ta lấy lại quyền điều khiển, chứ không đứng đó mãi.
            _ = controller
            let started = Date()
            let outcome = ScriptRunner.run(
                source: "while (true) {}", text: "x", selection: 0 ..< 0
            )
            let elapsed = Date().timeIntervalSince(started)
            guard outcome.failure != nil else { return "script vô hạn mà báo là chạy xong" }
            guard outcome.replacement == nil else { return "script vô hạn mà vẫn trả về kết quả" }
            guard elapsed < ScriptRunner.timeout + 3 else {
                return "đợi \(Int(elapsed))s, quá hạn \(Int(ScriptRunner.timeout))s quá xa"
            }
            // Và câu trả lời phải NÓI RA cái giá còn lại, không giấu.
            guard outcome.failure?.contains("CPU") == true else {
                return "không nói cho người dùng biết luồng kia vẫn đang chạy"
            }
            return nil
        },

        Case(name: "xem trước Markdown dựng ra chữ, không phải chuỗi nguồn") { controller in
            controller.prepareSelfTestDocument("""
                # Tiêu đề

                Một đoạn có **chữ đậm** và `mã`.
                """)
            controller.showMarkdownPreview(nil)
            guard let preview = controller.markdownPreview else { return "không mở được panel" }
            let rendered = preview.renderedTextForSelfTest

            // Dấu Markdown phải BIẾN MẤT — còn nguyên `**` nghĩa là nó chỉ chép chuỗi nguồn
            // sang một ô khác chứ chưa dựng gì.
            guard !rendered.contains("**"), !rendered.contains("# ") else {
                return "chưa dựng, vẫn là chuỗi nguồn: \(String(reflecting: rendered.prefix(60)))"
            }
            guard rendered.contains("Tiêu đề"), rendered.contains("chữ đậm") else {
                return "mất nội dung: \(String(reflecting: rendered.prefix(60)))"
            }
            // Tài liệu quá lớn thì TỪ CHỐI và nói ra, không treo.
            let huge = String(repeating: "x", count: MarkdownPreview.sizeLimit + 1)
            guard preview.present(markdown: huge) != nil else {
                return "tài liệu vượt trần mà vẫn nhận dựng"
            }
            return nil
        },

        Case(name: "chế độ Log tô theo mức và lọc ra tab mới") { controller in
            let text = """
                2026-08-23 10:00:00 INFO khởi động
                2026-08-23 10:00:01 ERROR không mở được file
                    at Foo.bar(Foo.java:42)
                2026-08-23 10:00:02 DEBUG chi tiết
                """
            controller.prepareSelfTestDocument(text + "\n")
            controller.toggleLogMode(nil)
            defer { if controller.isLogModeForSelfTest { controller.toggleLogMode(nil) } }
            guard controller.isLogModeForSelfTest else { return "không bật được chế độ Log" }
            controller.flushDrawingForSelfTest()

            // Màu phải KHÁC nhau giữa dòng lỗi và dòng thường — cùng màu thì tô cũng như không.
            let errorColor = Tokens.Color.logLevel(.error)
            let debugColor = Tokens.Color.logLevel(.debug)
            guard errorColor != debugColor else { return "ERROR và DEBUG cùng một màu" }

            // Lọc: dòng stack trace KHÔNG có mức riêng nhưng phải đi THEO dòng lỗi sinh ra nó.
            controller.filterLogLevelForSelfTest(.error)
            let filtered = controller.editorDocument.buffer.text
            guard filtered.contains("ERROR không mở được file") else {
                return "lọc mất cả dòng lỗi: \(String(reflecting: filtered))"
            }
            guard filtered.contains("at Foo.bar") else {
                return "dòng tiếp nối của stack trace bị cắt khỏi dòng lỗi của nó"
            }
            guard !filtered.contains("DEBUG"), !filtered.contains("INFO") else {
                return "lọc từ ERROR trở lên mà vẫn còn mức thấp hơn"
            }
            return nil
        },

        Case(name: "thử regex chạy trên mẫu và giải thích được biểu thức") { controller in
            controller.prepareSelfTestDocument("an@vidu.com và binh@khac.com\n")
            controller.setSelectionForSelfTest(documentRange: 0 ..< 11)
            controller.showRegexTester(nil)
            guard let panel = controller.regexTesterPanel else { return "không mở được panel" }

            panel.setSampleForSelfTest("an@vidu.com và binh@khac.com")
            panel.setPatternForSelfTest(#"(\w+)@(\w+)\.com"#)
            guard panel.statusForSelfTest.contains("2") else {
                return "mong 2 lần khớp, panel nói «\(panel.statusForSelfTest)»"
            }
            guard panel.resultTextForSelfTest.contains("«an»"),
                  panel.resultTextForSelfTest.contains("«vidu»") else {
                return "không hiện được nhóm bắt: \(String(reflecting: panel.resultTextForSelfTest))"
            }
            guard panel.explanationForSelfTest.contains("một ký tự từ") else {
                return "không giải thích được \\w: \(String(reflecting: panel.explanationForSelfTest))"
            }

            // Biểu thức sai phải nói SAI Ở ĐÂU, không im lặng trả về rỗng.
            panel.setPatternForSelfTest("(")
            guard !panel.statusForSelfTest.isEmpty,
                  panel.resultTextForSelfTest.isEmpty else {
                return "biểu thức hỏng mà không báo gì"
            }
            return nil
        },

        Case(name: "view TỰ VẼ đều nói được mình là gì cho VoiceOver") { controller in
            // NFR-USE-03. Điều khiển chuẩn của AppKit tự có nhãn từ `title`; view TỰ VẼ thì
            // hoàn toàn câm — người dùng VoiceOver gặp một vùng trống giữa cửa sổ, không biết
            // nó là gì và bấm vào thì xảy ra chuyện gì.
            //
            // Bài này chỉ soi những view ta tự vẽ và có tương tác. Nó KHÔNG khẳng định cả ứng
            // dụng đã dùng được bằng VoiceOver — điều đó phải một người thật ngồi nghe mới
            // biết, và §5 của `docs/trang-thai.md` ghi việc ấy.
            controller.toggleDocumentMapForSelfTest()
            defer { controller.toggleDocumentMapForSelfTest() }
            controller.drawDocumentMapForSelfTest()

            var missing: [String] = []
            for (name, view) in controller.selfDrawnViewsForSelfTest {
                if !view.isAccessibilityElement() {
                    missing.append("\(name): không phải phần tử accessibility")
                } else if (view.accessibilityLabel() ?? "").isEmpty {
                    missing.append("\(name): không có nhãn")
                }
            }
            guard missing.isEmpty else { return missing.joined(separator: ", ") }

            // Nhãn thôi chưa đủ với view mang TRẠNG THÁI: bản đồ tài liệu phải nói được đang
            // xem tới đâu, không thì nhãn "Bản đồ tài liệu" chẳng giúp gì.
            let mapValue = (controller.documentMapView.accessibilityValue() as? String) ?? ""
            guard mapValue.contains("dòng") else {
                return "bản đồ tài liệu không nói được đang xem tới đâu: «\(mapValue)»"
            }
            return nil
        },

        Case(name: "mọi mục menu đều có bản dịch tiếng Anh") { controller in
            // FR-UI-804. Menu bar là phần giao diện người dùng nhìn thấy trước nhất và nhiều
            // nhất, nên nó phải dịch ĐỦ — một menu nửa Anh nửa Việt tệ hơn cả một menu toàn
            // tiếng Việt. Bài này cũng là thứ giữ cho mục menu THÊM VỀ SAU không quên dịch.
            _ = controller
            var titles: [String] = []
            for group in NSApp.mainMenu?.items ?? [] {
                guard let submenu = group.submenu,
                      !Self.menusAllowedToBeEmpty.contains(submenu.title) else { continue }
                titles.append(submenu.title)
                for item in submenu.items where !item.isSeparatorItem {
                    titles.append(item.title)
                }
            }
            // Menu đang dựng bằng tiếng Anh (máy chạy locale en) thì bài này vô nghĩa — chuỗi
            // đã dịch rồi, tra ngược lại sẽ báo thiếu hàng loạt. Nói ra thay vì trượt bừa.
            guard L10n.effective == .vi else {
                return nil
            }
            // Chỉ xét mục do CHÍNH APP dựng. macOS tự chèn `Enter Full Screen` và mấy mục sắp
            // xếp cửa sổ khi thấy app có cửa sổ hợp lệ; chúng do hệ điều hành dịch theo ngôn
            // ngữ của máy, không thuộc bảng dịch của ta. Đòi dịch cả chúng làm bài này trượt ở
            // binary trần mà xanh ở bundle — xem `AppDelegate.appOwnedMenuTitles`.
            let ourTitles = titles.filter { AppDelegate.appOwnedMenuTitles.contains($0) }
            guard !ourTitles.isEmpty else {
                return "không thấy mục menu nào của app — ảnh chụp lúc dựng menu bị rỗng"
            }
            let missing = L10n.untranslated(among: ourTitles)
            guard missing.isEmpty else {
                return "\(missing.count) mục menu chưa có bản dịch: "
                    + missing.prefix(5).joined(separator: ", ")
            }
            return nil
        },

        Case(name: "luật số nhiều đúng ở những con số HAY BỊ VIẾT SAI") { _ in
            // Mọi con số dưới đây đều là chỗ mà một hiện thực viết `n == 1` sẽ đi qua trót lọt
            // với các giá trị nhỏ rồi sai. Đó là lý do bài này thử 21 và 22 chứ không thử 1–5.
            let phep: [(L10n.Language, Int, Plural.Category)] = [
                // Tiếng Nga: hàng đơn vị quyết định, trừ nhóm 11–14.
                (.ru, 1, .one), (.ru, 21, .one), (.ru, 101, .one),
                (.ru, 11, .many), (.ru, 111, .many),
                (.ru, 2, .few), (.ru, 24, .few), (.ru, 12, .many), (.ru, 5, .many),
                // Tiếng Ba Lan giống Nga ở "few"/"many" nhưng KHÁC ở "one": chỉ đúng số 1.
                (.pl, 1, .one), (.pl, 21, .many), (.pl, 22, .few), (.pl, 5, .many),
                // Tiếng Séc: 2–4 tính theo GIÁ TRỊ thật, nên 22 không phải "few".
                (.cs, 1, .one), (.cs, 3, .few), (.cs, 22, .other), (.cs, 5, .other),
                // Tiếng Rumani: số 0 và hai chữ số cuối 1–19 đều là "few".
                (.ro, 1, .one), (.ro, 0, .few), (.ro, 19, .few), (.ro, 119, .few),
                (.ro, 20, .other),
                // Tiếng Ả Rập là thứ tiếng duy nhất trong bộ dùng cả `zero` lẫn `two`.
                (.ar, 0, .zero), (.ar, 1, .one), (.ar, 2, .two),
                (.ar, 3, .few), (.ar, 11, .many), (.ar, 100, .other),
                // Tiếng Do Thái có dạng ĐÔI.
                (.he, 2, .two), (.he, 3, .other),
                // Tiếng Bồ Đào Nha gộp 0 vào "one"; tiếng Anh thì không — khác nhau đúng ở 0.
                (.pt, 0, .one), (.en, 0, .other), (.en, 1, .one),
                // Nhóm một dạng: mọi con số đều "other".
                (.vi, 1, .other), (.ja, 1, .other), (.zhHans, 5, .other), (.id, 1, .other),
            ]
            for (ngon, n, mong) in phep {
                let thuc = Plural.category(n, ngon)
                guard thuc == mong else {
                    return "\(ngon.rawValue) với n=\(n): mong \(mong.rawValue), ra \(thuc.rawValue)"
                }
            }
            return nil
        },

        Case(name: "chuỗi hai con số chọn được HAI dạng số nhiều độc lập") { _ in
            // Đây là vế mà một bảng "mỗi khoá một biến thể" không làm nổi: tiếng Nga sẽ cần
            // bốn nhân bốn biến thể cho một câu có hai con số.
            let mau = "Đã gộp %1$d {one=nhóm|few=nhóma|many=nhómb} · %2$d {one=ô|few=ôa|many=ôb}"
            let ra = L10n.expandPlurals(mau, [1, 5], language: .ru)
            guard ra == "Đã gộp %1$d nhóm · %2$d ôb" else { return "ra «\(ra)»" }

            // Ô KHÔNG đánh số thì gắn theo thứ tự xuất hiện.
            let ngam = L10n.expandPlurals("%d {one=a|other=b} và %d {one=a|other=b}",
                                          [1, 2], language: .en)
            guard ngam == "%d a và %d b" else { return "ô ngầm: «\(ngam)»" }

            // Ô KHÔNG PHẢI số nguyên vẫn phải được đếm khi tính thứ tự ngầm, nếu không thì
            // nhóm sau nó sẽ soi nhầm đối số.
            let lan = L10n.expandPlurals("%@ có %d {one=dòng|other=dòng}", ["x", 1], language: .en)
            guard lan == "%@ có %d dòng" else { return "ô lẫn kiểu: «\(lan)»" }
            return nil
        },

        Case(name: "«%%{init}%%» của Mermaid KHÔNG bị bộ số nhiều nuốt mất") { _ in
            // Đối chứng cho luật "phải chứa dấu `=` mới là nhóm số nhiều". Không có luật ấy thì
            // `{init}` bị ăn mất và chỉ thị Mermaid hỏng — im lặng ở mọi chỗ khác, chỉ nổ ở
            // đúng một tính năng.
            for mau in ["Lưu và chèn %%{init}%% vào tài liệu",
                        "Sơ đồ này đã có chỉ thị %%{init}%% — cái của bạn giữ nguyên.",
                        "Đã chèn %%{init}%%"] {
                let ra = L10n.expandPlurals(mau, [], language: .ru)
                guard ra == mau else { return "«\(mau)» bị đổi thành «\(ra)»" }
            }
            // Chuỗi không có nhóm nào thì trả về CHÍNH NÓ, kể cả khi có ô số.
            let khong = "Đã đánh dấu %d dòng"
            guard L10n.expandPlurals(khong, [3], language: .ru) == khong else {
                return "chuỗi không có nhóm bị đổi"
            }
            return nil
        },

        Case(name: "thiếu nhánh thì rơi về «other», không rơi về rỗng") { _ in
            // Bảng dịch sẽ có chỗ khai thiếu hạng — nhất là tiếng Ả Rập với sáu hạng. Rơi về
            // `other` cho ra một câu hơi cứng; rơi về chuỗi rỗng cho ra một câu MẤT CHỮ, và đó
            // là kiểu hỏng không ai đọc log mà thấy.
            let thieu = L10n.expandPlurals("%d {one=tệp|other=tệp}", [3], language: .ar)
            guard thieu == "%d tệp" else { return "ra «\(thieu)»" }
            // Không hạng nào khớp và cũng không có `other` → lấy nhánh đầu, vẫn có chữ.
            let chiOne = L10n.expandPlurals("%d {one=tệp}", [3], language: .en)
            guard chiOne == "%d tệp" else { return "chỉ có one: «\(chiOne)»" }
            // Đối số không phải Int (chuỗi lọt vào chỗ con số) → `other`, không sập.
            let sai = L10n.expandPlurals("%d {one=tệp|other=tệpb}", ["x"], language: .en)
            guard sai == "%d tệpb" else { return "đối số sai kiểu: «\(sai)»" }
            return nil
        },

        Case(name: "LF dịch, chọn dạng số nhiều, rồi ghép — trong một lượt") { _ in
            // Đường đi thật của chỗ gọi. Khoá dưới đây có trong bảng tiếng Anh kèm dạng số
            // nhiều, nên bài này cũng là bằng chứng bảng dịch mang được cú pháp ấy.
            var mot = ""
            var nhieu = ""
            L10n.withLanguageForSelfTest(.en) {
                mot = LF("Đã đánh dấu %d dòng vi phạm", 1)
                nhieu = LF("Đã đánh dấu %d dòng vi phạm", 7)
            }
            guard mot == "Marked 1 violating line" else { return "n=1 ra «\(mot)»" }
            guard nhieu == "Marked 7 violating lines" else { return "n=7 ra «\(nhieu)»" }
            return nil
        },

        Case(name: "mọi nhóm số nhiều trong bảng dịch đều đọc được và có nhánh «other»") { _ in
            // Cổng cho chính cú pháp. Một nhánh gõ sai tên hạng ("ones=") làm cả nhóm không
            // được nhận là nhóm số nhiều — và khi ấy người dùng đọc thấy nguyên đoạn
            // "{ones=dòng|other=dòng}" trên màn hình. Lỗi hiện rành rành, nhưng chỉ hiện ở
            // đúng thứ tiếng ấy với đúng câu ấy.
            var hong: [String] = []
            for ngon in L10n.Language.allCases {
                guard let bang = L10n.table(for: ngon) else { continue }
                for (khoa, gia) in bang where gia.contains("{") {
                    let mocoi = L10n.nhomKhongCoOSo(gia)
                    if mocoi > 0 {
                        hong.append("\(ngon.rawValue) «\(khoa.prefix(28))»: \(mocoi) nhóm không có ô số đứng trước")
                    }
                    for nhom in Self.nhomSoNhieu(gia) {
                        let hang = nhom.components(separatedBy: "|").map {
                            $0.components(separatedBy: "=").first ?? ""
                        }
                        if hang.contains(where: { Plural.Category(rawValue: $0) == nil }) {
                            hong.append("\(ngon.rawValue) «\(khoa.prefix(28))»: {\(nhom)}")
                            continue
                        }
                        // Đủ khi khai HẾT những hạng mà chính thứ tiếng ấy sinh ra được — bảng
                        // tiếng Nga khai `one|few|many` là trọn vẹn, vì luật tiếng Nga không
                        // bao giờ trả về `other`. Đòi thêm một nhánh `other` chết ở đó chỉ làm
                        // bảng khó đọc hơn cho chính người dịch.
                        //
                        // `other` vẫn được chấp nhận thay cho phần còn thiếu, vì nó là nhánh
                        // rơi về của `chonNhanh` — nên một bảng khai nửa vời vẫn ra chữ, chỉ
                        // hơi cứng, chứ không ra chuỗi rỗng.
                        let sinhRaDuoc = Self.hangSinhRaDuoc(ngon)
                        if !hang.contains("other") && !sinhRaDuoc.isSubset(of: Set(hang)) {
                            let thieu = sinhRaDuoc.subtracting(Set(hang)).sorted().joined(separator: ",")
                            hong.append("\(ngon.rawValue) «\(khoa.prefix(28))»: thiếu \(thieu)")
                        }
                    }
                }
            }
            guard hong.isEmpty else {
                return "\(hong.count) nhóm số nhiều hỏng: " + hong.prefix(3).joined(separator: " · ")
            }
            return nil
        },

        Case(name: "tiếng Nga: 1 · 2 · 5 · 11 · 21 ra bốn dạng đúng") { _ in
            // Đi hết đường thật — bảng dịch, luật hạng, bộ bung nhóm, rồi `String(format:)` —
            // với đúng những con số mà tiếng Nga đổi dạng. 21 và 11 là hai chỗ mà một luật viết
            // `n == 1` sẽ ra sai, và cũng là hai chỗ người dịch hay quên khi tự soát bằng mắt.
            var ra: [Int: String] = [:]
            L10n.withLanguageForSelfTest(.ru) {
                for n in [1, 2, 5, 11, 21] { ra[n] = LF("%d hàng · %@", n, "x") }
            }
            let mong: [Int: String] = [
                1: "1 строка · x",      // именительный единственного
                2: "2 строки · x",      // родительный единственного
                5: "5 строк · x",       // родительный множественного
                11: "11 строк · x",     // 11 KHÔNG theo hàng đơn vị
                21: "21 строка · x",    // 21 lại quay về dạng của 1
            ]
            for (n, m) in mong.sorted(by: { $0.key < $1.key }) {
                guard ra[n] == m else { return "n=\(n): mong «\(m)», ra «\(ra[n] ?? "")»" }
            }
            return nil
        },

        Case(name: "một câu HAI con số: mỗi ô chọn dạng riêng, đối số không lệch") { _ in
            // Bài "hai con số" ở trên chỉ kiểm bộ BUNG nhóm, trên một chuỗi tự chế. Bài này đi
            // hết đường thật với một khoá THẬT trong bảng tiếng Nga, nên nó bắt được thêm một
            // lớp hỏng mà bài kia không chạm tới: bung nhóm xong, `String(format:)` có còn ghép
            // đúng đối số vào đúng ô không.
            //
            // Đây là chỗ đáng ngờ nhất của cả cơ chế. Việc bung nhóm CHÈN chữ vào giữa chuỗi
            // định dạng; nếu chữ chèn vào vô tình chứa một `%` thì mọi ô phía sau lệch một bậc,
            // và người dùng thấy số hàng nằm ở chỗ số ô.
            var ra: [String] = []
            L10n.withLanguageForSelfTest(.ru) {
                ra.append(LF("Đã gộp %d cụm · %d ô đổi giá trị", 1, 5))
                ra.append(LF("Đã gộp %d cụm · %d ô đổi giá trị", 5, 1))
                ra.append(LF("Đã gộp %d cụm · %d ô đổi giá trị", 2, 3))
            }
            let mong = [
                "Объединено 1 группа · изменено 5 ячеек",
                "Объединено 5 групп · изменено 1 ячейка",
                "Объединено 2 группы · изменено 3 ячейки",
            ]
            // `zip` dừng ở dãy NGẮN HƠN, nên `ra` rỗng là bài kiểm xanh mà chẳng so gì cả —
            // đúng kiểu xanh rỗng của một vòng lặp không chạy. Chốt số lượng trước khi so.
            guard ra.count == mong.count else {
                return "dựng được \(ra.count) chuỗi, cần \(mong.count) — chưa so được gì"
            }
            for (thuc, m) in zip(ra, mong) where thuc != m {
                return "mong «\(m)», ra «\(thuc)»"
            }
            return nil
        },

        Case(name: "tiếng Ả Rập dùng đủ SÁU hạng, không rơi hết về một dạng") { _ in
            // Tiếng Ả Rập là thứ tiếng duy nhất trong bộ dùng cả `zero` lẫn `two`, và là chỗ
            // duy nhất mà một bảng khai thiếu vẫn TRÔNG như chạy được: `chonNhanh` rơi về
            // `other` nên câu vẫn ra chữ, chỉ là sai dạng ở năm trong sáu khoảng.
            //
            // Nên bài này không hỏi "có ra chữ không" mà hỏi "sáu khoảng có ra SÁU kết quả
            // khác nhau không". Sáu con số dưới đây mỗi cái rơi vào một hạng.
            var ra: [Int: String] = [:]
            L10n.withLanguageForSelfTest(.ar) {
                for n in [0, 1, 2, 3, 11, 100] { ra[n] = LF("%d hàng · %@", n, "x") }
            }
            let hang = [0: "zero", 1: "one", 2: "two", 3: "few", 11: "many", 100: "other"]
            let khac = Set(ra.values)
            guard khac.count == 6 else {
                let gop = ra.sorted { $0.key < $1.key }
                    .map { "\($0.key)(\(hang[$0.key]!))=«\($0.value)»" }.joined(separator: " ")
                return "sáu hạng chỉ cho \(khac.count) kết quả khác nhau: \(gop)"
            }
            // Và không cái nào còn sót dấu ngoặc nhóm.
            for (n, chuoi) in ra where chuoi.contains("{") {
                return "n=\(n) còn dấu ngoặc: «\(chuoi)»"
            }
            return nil
        },

        Case(name: "mọi chuỗi đếm tiếng Anh DỰNG RA khác nhau ở 1 và 2") { _ in
            // Bài trên chỉ soát CÚ PHÁP của nhóm số nhiều. Bài này dựng thật ra chữ, vì hai
            // kiểu hỏng còn lại không lộ ra ở cú pháp:
            //
            //   · dấu `{` còn sót lại trên màn hình — nhóm viết đúng cú pháp nhưng gắn vào một
            //     ô KHÔNG PHẢI số nguyên, nên không ô nào nhận nó;
            //   · hai nhánh giống hệt nhau — chép nhầm, và với tiếng Anh thì đó luôn là lỗi.
            //
            // Chỉ soi tiếng Anh: ở tiếng Việt, tiếng Nhật hay tiếng Indonesia thì hai nhánh
            // GIỐNG nhau mới là đúng, nên đòi hỏi này áp lên chúng sẽ là đòi hỏi sai.
            var hong: [String] = []
            for (khoa, gia) in L10n.en where !Self.nhomSoNhieu(gia).isEmpty {
                // Đủ đối số cho mọi ô, và đều là số — chỉ cần các ô SỐ nhận đúng giá trị.
                let mot = L10n.expandPlurals(gia, Array(repeating: 1, count: 8), language: .en)
                let hai = L10n.expandPlurals(gia, Array(repeating: 2, count: 8), language: .en)
                if mot.contains("{") || hai.contains("{") {
                    hong.append("còn dấu ngoặc: «\(khoa.prefix(34))»")
                } else if mot == hai {
                    hong.append("1 và 2 ra giống hệt nhau: «\(khoa.prefix(34))»")
                }
            }
            guard hong.isEmpty else {
                return "\(hong.count) chuỗi hỏng: " + hong.prefix(3).joined(separator: " · ")
            }
            return nil
        },

        Case(name: "mọi lệnh trên thanh menu đều có biểu tượng") { _ in
            // Cùng lý lẽ với bài dịch ngay trên: menu bar là chỗ người dùng nhìn nhiều nhất,
            // nên một menu NỬA có hình nửa không đọc lộn xộn hơn hẳn một menu không hình nào.
            // Và đây là thứ giữ cho mục menu THÊM VỀ SAU không quên khai biểu tượng.
            //
            // Chỉ xét MỘT tầng bên trong mỗi menu: tám mục "Cấp 1…8" của submenu gấp theo cấp
            // khác nhau đúng một chữ số, cho chúng tám cái hình chỉ để lấp chỗ là thêm nhiễu.
            //
            // # Vì sao KHÔNG hỏi `muc.image == nil`
            //
            // Bản đầu của bài này hỏi đúng câu ấy, và nó XANH khi đã cố ý xoá dòng "In…" khỏi
            // `MenuIcons`. Lý do: macOS đời mới TỰ gắn ký hiệu SF cho những mục menu nối vào
            // selector chuẩn của AppKit — `printDocument:`, `saveDocument:`, `copy:`… Trên máy
            // này chúng có hình dù bảng của ta không khai gì; trên macOS 12, đích triển khai
            // thật, chúng KHÔNG có. Tức là bài kiểm đo hành vi của hệ điều hành đang chạy chứ
            // không đo thứ ta viết ra, và nó xanh ở đúng chỗ đáng lẽ phải đỏ.
            //
            // Nên hỏi thẳng vào BẢNG CỦA TA: mục menu này có dòng khai biểu tượng chưa. Câu ấy
            // cho cùng một câu trả lời trên mọi phiên bản macOS.
            guard L10n.effective == .vi else { return nil }
            var thieu: [String] = []
            for nhom in NSApp.mainMenu?.items ?? [] {
                guard let submenu = nhom.submenu else { continue }
                // Menu Window do AppKit tự đổ vào (Minimize, Zoom, Bring All to Front). Chúng
                // không thuộc quyền ta, và đòi hỏi ở đây sẽ đỏ vì lý do vô can.
                if submenu === NSApp.windowsMenu { continue }
                for muc in submenu.items where !muc.isSeparatorItem {
                    guard muc.action != nil || muc.submenu != nil else { continue }
                    // Bài này khoá ngôn ngữ về tiếng Việt, nên nhan đề trên menu ĐÚNG BẰNG
                    // khoá của bảng — cùng hệ khoá với bảng dịch, xem ghi chú ở `MenuIcons`.
                    if MenuIcons.bang[muc.title] == nil { thieu.append(muc.title) }
                }
            }
            guard thieu.isEmpty else {
                return "\(thieu.count) mục menu chưa khai biểu tượng: "
                    + thieu.prefix(5).joined(separator: ", ")
            }
            return nil
        },

        Case(name: "bảng biểu tượng không có dòng thừa, không có tên gõ sai") { controller in
            // Cổng HAI CHIỀU. Chiều thiếu do bài trên canh; chiều thừa canh ở đây, vì một mục
            // menu bị xoá đi mà dòng biểu tượng của nó ở lại thì bảng dần thành nghĩa địa —
            // và người đọc sau không phân biệt nổi dòng nào còn sống.
            //
            // Menu ngữ cảnh chỉ dựng khi có người bấm chuột phải, nên phải DỰNG nó ra ở đây
            // trước khi hỏi. Bản đầu không làm vậy và tố oan sáu dòng của menu tiêu đề CSV:
            // chúng CÓ được hỏi tới thật, nhưng ở một bài chạy sau bài này. Một cổng phụ thuộc
            // vào thứ tự chạy của bài khác là cổng sẽ đỏ vào ngày ai đó sắp lại danh sách.
            controller.prepareSelfTestDocument("ma,ho_ten,tien\nA,Cam,3\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }
            // Ẩn một cột để mục "Hiện lại: …" xuất hiện, rồi trả lại ngay: bài kiểm không được
            // để lại trạng thái cho bài sau.
            controller.csvTable.hideColumnForSelfTest(0)
            _ = controller.csvTable.headerMenuTitlesForSelfTest(1)
            controller.csvTable.showColumnForSelfTest(0)

            let thua = MenuIcons.khoaThua
            guard thua.isEmpty else {
                return "\(thua.count) dòng trong MenuIcons không mục menu nào dùng: "
                    + thua.prefix(5).joined(separator: ", ")
            }
            // Tên gõ sai cho ra `nil` y hệt tên chưa tồn tại trên máy này. Bài này chỉ bắt được
            // vế GÕ SAI; vế "ký hiệu ra đời quá muộn so với macOS 12" phải chặn lúc CHỌN tên —
            // xem ghi chú đầu `MenuIcons`.
            let hong = MenuIcons.kyHieuKhongDung
            guard hong.isEmpty else {
                return "\(hong.count) tên ký hiệu không dựng nổi ảnh: "
                    + hong.prefix(5).joined(separator: ", ")
            }
            return nil
        },

        Case(name: "cài đặt ghi ra file text và đọc lại được nguyên vẹn") { controller in
            // FR-UI-803 · NFR-PORT-03: cấu hình là một file JSON đọc được bằng mắt, không phải
            // UserDefaults. Bài này đi qua ĐÚNG đường của cửa sổ Cài đặt.
            let path = URL(fileURLWithPath: NSTemporaryDirectory() + "geditor-selftest-settings.json")
            defer { try? FileManager.default.removeItem(at: path) }

            var written = Settings()
            written.fontSize = 17
            written.tabWidth = 2
            written.language = "en"
            written.trimTrailingWhitespaceOnSave = true
            do { try written.save(to: path) } catch { return "không ghi được: \(error)" }

            // Phải là văn bản người đọc được, không phải plist nhị phân.
            guard let text = try? String(contentsOf: path, encoding: .utf8),
                  text.contains("\"fontSize\""), text.contains("\n") else {
                return "file cấu hình không phải JSON nhiều dòng đọc được bằng mắt"
            }

            guard let back = try? Settings.load(from: path), back == written else {
                return "đọc lại không khớp bản đã ghi"
            }

            // File của bản MỚI HƠN thì phải TỪ CHỐI, không được ghi đè: người dùng đồng bộ hai
            // máy sẽ mất sạch cấu hình mà không cách nào biết vì sao.
            var future = written
            future.schemaVersion = Settings.currentSchemaVersion + 1
            try? future.save(to: path)
            do {
                _ = try Settings.load(from: path)
                return "đọc được file của lược đồ tương lai — đáng lẽ phải từ chối"
            } catch { /* đúng như mong đợi */ }

            // Khoá thiếu thì về mặc định, không phải lỗi: sửa tay file này là chuyện được
            // khuyến khích, và gõ thiếu một khoá không được làm app không mở lên nổi.
            try? "{ \"schemaVersion\": 1 }".write(to: path, atomically: true, encoding: .utf8)
            guard let sparse = try? Settings.load(from: path), sparse.tabWidth == Settings().tabWidth
            else { return "file thiếu khoá phải rơi về mặc định" }

            // Và giá trị vô lý từ cửa sổ Cài đặt phải bị KẸP, không nhận bừa.
            let panel = PreferencesPanel(settings: Settings()) { _ in }
            panel.setFontSizeForSelfTest("0")
            guard panel.settingsForSelfTest.fontSize >= 8 else {
                return "gõ cỡ chữ 0 mà nhận: \(panel.settingsForSelfTest.fontSize)"
            }
            panel.setFontSizeForSelfTest("999")
            guard panel.settingsForSelfTest.fontSize <= 32 else {
                return "gõ cỡ chữ 999 mà nhận: \(panel.settingsForSelfTest.fontSize)"
            }
            return nil
        },

        Case(name: "đổi phím tắt ăn vào menu, và phím trùng thì bị từ chối") { controller in
            // FR-UI-802. Bài này phải TRẢ LẠI trạng thái cũ ở cuối: nó sửa thẳng menu bar dùng
            // chung, và để lại phím đã đổi thì bài "không hai mục menu nào giành cùng một phím"
            // chạy sau sẽ đọc một menu bar khác với menu bar thật.
            func item(_ selector: String) -> NSMenuItem? {
                for group in NSApp.mainMenu?.items ?? [] {
                    guard let submenu = group.submenu else { continue }
                    for entry in submenu.items where entry.action.map(NSStringFromSelector) == selector {
                        return entry
                    }
                }
                return nil
            }
            guard let duplicate = item("duplicateLines:") else { return "không tìm ra lệnh Nhân đôi dòng" }
            let originalKey = duplicate.keyEquivalent
            let originalMask = duplicate.keyEquivalentModifierMask
            defer {
                duplicate.keyEquivalent = originalKey
                duplicate.keyEquivalentModifierMask = originalMask
            }

            // ⌃⌥⇧⌘Y — chắc chắn chưa ai dùng.
            let rejected = KeyBindings.apply(["duplicateLines:": "^~+y"], to: NSApp.mainMenu)
            guard rejected.isEmpty else { return "phím trống mà bị từ chối: \(rejected)" }
            guard duplicate.keyEquivalent == "y" else {
                return "phím không đổi: vẫn là «\(duplicate.keyEquivalent)»"
            }

            // Phím ĐÃ CÓ CHỦ thì phải từ chối và NÓI RA. Bỏ qua lặng lẽ thì người dùng đặt một
            // phím, thấy nó không chạy, và không có gì nói cho họ biết vì sao.
            let clash = KeyBindings.apply(["duplicateLines:": "s"], to: NSApp.mainMenu)
            guard !clash.isEmpty else { return "đặt trùng ⌘S của lệnh Lưu mà không báo gì" }
            guard duplicate.keyEquivalent == "y" else {
                return "bị từ chối rồi mà phím vẫn đổi thành «\(duplicate.keyEquivalent)»"
            }
            return nil
        },

        Case(name: "đổi theme thì màu vùng soạn thảo đổi theo") { controller in
            // FR-UI-801. Đọc màu THẬT sau khi giải theo nền sáng/tối, không so tên theme: so
            // tên chỉ chứng minh biến đã được gán, còn câu hỏi là màu vẽ ra có đổi không.
            let original = Tokens.theme
            defer { Tokens.theme = original }

            func ink(dark: Bool) -> NSColor {
                let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
                var resolved = NSColor.black
                appearance.performAsCurrentDrawingAppearance {
                    resolved = Tokens.Color.editorInk.usingColorSpace(.sRGB) ?? .black
                }
                return resolved
            }

            Tokens.theme = .cam
            let camLight = ink(dark: false)
            Tokens.theme = .than
            let thanLight = ink(dark: false)
            guard camLight != thanLight else {
                return "đổi theme mà màu chữ nền sáng vẫn y nguyên"
            }

            // Và cả hai chế độ nền đều phải cho ra màu KHÁC nhau — một theme chỉ định nghĩa
            // một bản sẽ có nửa số lần là chữ đen trên nền đen.
            guard ink(dark: true) != ink(dark: false) else {
                return "nền sáng và nền tối cho cùng một màu chữ"
            }

            // Màu gõ sai phải rơi về theme MẶC ĐỊNH, không phải về đen.
            var broken = Theme.cam
            broken.editorInk = Theme.Pair(light: "không-phải-màu", dark: "không-phải-màu")
            Tokens.theme = broken
            Tokens.theme = .cam
            let good = ink(dark: false)
            Tokens.theme = broken
            guard ink(dark: false) == good else {
                return "màu hỏng không rơi về theme mặc định"
            }
            return nil
        },

        Case(name: "không hai mục menu nào giành cùng một phím tắt") { controller in
            // AppKit lặng lẽ chỉ kích hoạt mục ĐẦU TIÊN khi hai mục khai cùng phím, và lệnh
            // kia trông y hệt như bị hỏng. Chú thích trong `AppDelegate` đã cảnh báo chuyện
            // này; bài kiểm biến lời cảnh báo thành thứ máy giữ giúp. Nó vừa bắt được một ca
            // thật: "Cỡ chữ gốc" suýt lấy ⌥⌘0 của "Bỏ chia đôi".
            _ = controller
            guard let mainMenu = NSApp.mainMenu else { return "chưa có thanh menu" }
            var owner: [String: String] = [:]
            var clashes: [String] = []
            // Đệ quy vì lý do y hệt bài trên: ⌥⌘1…⌥⌘8 của "Gấp theo cấp" nằm trong submenu
            // lồng, và một phím tắt giành mất của lệnh khác thì AppKit không nói gì cả.
            for (path, item) in Self.allMenuItems(under: mainMenu) where !item.keyEquivalent.isEmpty {
                let key = "\(item.keyEquivalentModifierMask.rawValue)+\(item.keyEquivalent)"
                if let taken = owner[key] {
                    clashes.append("«\(taken)» và «\(path)»")
                } else {
                    owner[key] = path
                }
            }
            guard clashes.isEmpty else {
                return "trùng phím tắt: \(clashes.joined(separator: ", "))"
            }
            return nil
        },

        Case(name: "thu phóng đổi cỡ chữ mà KHÔNG đụng vào tài liệu") { controller in
            controller.prepareSelfTestDocument("một dòng để đo\n")
            let text = controller.editorDocument.buffer.text
            let revision = controller.editorDocument.buffer.revision
            let base = controller.editorFontSizeForSelfTest

            controller.increaseFontSize(nil)
            guard controller.editorFontSizeForSelfTest > base else {
                return "phóng to mà cỡ chữ vẫn \(base) pt"
            }
            controller.decreaseFontSize(nil)
            controller.decreaseFontSize(nil)
            guard controller.editorFontSizeForSelfTest < base else {
                return "thu nhỏ hai lần mà cỡ chữ vẫn \(controller.editorFontSizeForSelfTest) pt"
            }
            controller.resetFontSize(nil)
            guard controller.editorFontSizeForSelfTest == base else {
                return "về cỡ gốc ra \(controller.editorFontSizeForSelfTest) pt, mong \(base)"
            }

            // Đây mới là điều quan trọng: thu phóng là CÁCH NHÌN. Một byte đổi hay một bước
            // hoàn tác sinh ra đều là sai.
            guard controller.editorDocument.buffer.text == text,
                  controller.editorDocument.buffer.revision == revision else {
                return "đổi cỡ chữ mà tài liệu bị sửa"
            }

            // Kẹp trần/sàn: bấm thu nhỏ ba mươi lần không được ra cỡ chữ 0 hay số âm.
            for _ in 0 ..< 30 { controller.decreaseFontSize(nil) }
            guard controller.editorFontSizeForSelfTest >= 8 else {
                return "thu nhỏ không có sàn: ra \(controller.editorFontSizeForSelfTest) pt"
            }
            for _ in 0 ..< 60 { controller.increaseFontSize(nil) }
            guard controller.editorFontSizeForSelfTest <= 32 else {
                return "phóng to không có trần: ra \(controller.editorFontSizeForSelfTest) pt"
            }
            controller.resetFontSize(nil)
            return nil
        },

        Case(name: "mở lại tab vừa đóng lấy về đúng file, theo thứ tự ngược") { controller in
            let dir = NSTemporaryDirectory() + "geditor-selftest-reopen"
            try? FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true
            )
            let paths = (0 ..< 3).map { "\(dir)/tep\($0).txt" }
            for (index, path) in paths.enumerated() {
                try? "nội dung \(index)\n".write(toFile: path, atomically: true, encoding: .utf8)
            }
            defer { try? FileManager.default.removeItem(atPath: dir) }

            for path in paths { controller.openInNewTabForSelfTest(path: path) }
            // Đóng tab đang mở ba lần: tab hoạt động lùi dần, nên thứ tự ĐÓNG là tep2, tep1,
            // tep0 — ngược với thứ tự mở.
            for _ in paths { controller.closeCurrentTabForSelfTest() }

            // Ngăn xếp: cái đóng SAU CÙNG (tep0) phải quay lại TRƯỚC.
            for expected in paths {
                controller.reopenLastClosedTab(nil)
                guard controller.editorDocument.path == expected else {
                    return "mở lại ra \(controller.editorDocument.path ?? "nil"), mong \(expected)"
                }
            }
            // Hết nợ thì không được mở bừa một tab nào.
            let before = controller.editorDocument.path
            controller.reopenLastClosedTab(nil)
            guard controller.editorDocument.path == before else {
                return "hết tab đã đóng mà vẫn mở ra \(controller.editorDocument.path ?? "nil")"
            }
            return nil
        },

        // MARK: - Bản đồ tài liệu (FR-DOC-306)

        Case(name: "bản đồ mô tả CẢ tài liệu, không chỉ cửa sổ đang mở") { controller in
            // Đây là lời hứa của tính năng. Một bản đồ chỉ mô tả phần đang mở mà trông như mô
            // tả cả file sẽ khiến người dùng kết luận sai về thứ họ KHÔNG nhìn thấy.
            let text = (0 ..< 5000).map { "dòng \($0)" }.joined(separator: "\n") + "\n"
            controller.prepareSelfTestDocument(text)
            controller.toggleDocumentMapForSelfTest()
            guard controller.documentMapVisibleForSelfTest else { return "bản đồ không hiện" }
            controller.flushDrawingForSelfTest()

            let mapped = controller.documentMapView.mappedLineCountForSelfTest
            guard mapped == 5000 else {
                return "bản đồ nói nó mô tả \(mapped) dòng, tài liệu có 5000"
            }
            guard controller.documentMapView.rowCountForSelfTest > 0 else {
                return "bản đồ không có hàng nào"
            }
            controller.toggleDocumentMapForSelfTest()
            return nil
        },

        Case(name: "bản đồ vẽ ra HÌNH DÁNG, không phải một cột xám đều") { controller in
            // Bài kiểm này sinh ra từ một lỗi thật, và cả ba bài bên cạnh đều đã XANH trong khi
            // lỗi đang sống: chúng kiểm DỮ LIỆU — số dòng được mô tả, cú bấm nhảy đúng chỗ,
            // khung tầm nhìn đi theo cuộn — chứ không kiểm HÌNH. Bản đồ khi ấy có đúng MỘT hàng
            // cho cả tài liệu, vẽ ra một vệt mực cao hết view, và mọi con số vẫn đúng.
            //
            // Nên bài này đọc thẳng những hình chữ nhật đã VẼ, và hỏi hai câu mà cột xám không
            // trả lời được: bản đồ có nhiều hàng không, và các vệt mực có KHÁC NHAU không.
            // Tài liệu phải DÀI HƠN bản đồ cao bao nhiêu điểm: chỉ khi ấy số hàng mới do bề cao
            // quyết định, và câu hỏi "bản đồ có bám theo bề cao không" mới có nghĩa.
            var text = ""
            for block in 0 ..< 150 {
                for i in 0 ..< 20 {
                    text += String(repeating: "    ", count: (block % 3) + (i % 4))
                    text += "let bien_\(i) = tinh(\(String(repeating: "x", count: (i * 7) % 40)))\n"
                }
                text += "\n\n"
            }
            controller.prepareSelfTestDocument(text)
            controller.toggleDocumentMapForSelfTest()
            // Trả cửa sổ về đúng bề cao cũ: bài này co cửa sổ lại, và mọi bài chạy sau đều đo
            // trên cùng một cửa sổ.
            let originalHeight = controller.windowHeightForSelfTest
            defer {
                controller.setWindowHeightForSelfTest(originalHeight)
                controller.toggleDocumentMapForSelfTest()
            }
            controller.drawDocumentMapForSelfTest()

            let view = controller.documentMapView
            let lines = view.mappedLineCountForSelfTest
            guard lines > 3000 else { return "fixture chỉ có \(lines) dòng" }

            /// Bản đồ cao bao nhiêu điểm thì có bấy nhiêu hàng. Chấp một phần tám sai số: chỗ
            /// dựng có quyền không dựng lại vì một cú đổi bề cao li ti, nhưng không có quyền
            /// lệch hẳn một bậc.
            func rowsFollowHeight() -> String? {
                let height = view.lastDrawBounds.height
                guard height > 0 else { return "bản đồ chưa vẽ lần nào" }
                let rows = view.rowCountForSelfTest
                guard abs(rows - Int(height)) * 8 <= Int(height) else {
                    return "bản đồ cao \(Int(height))pt mà có \(rows) hàng cho \(lines) dòng"
                }
                return nil
            }
            if let bad = rowsFollowHeight() { return bad }

            // Mực phải gồ ghề. Fixture cố ý thụt lề 0–24 cột và dòng dài ngắn khác nhau, nên
            // nếu mọi vệt bắt đầu cùng một chỗ và dài như nhau thì thứ vẽ ra không phải hình
            // dáng tài liệu.
            let ink = view.lastDrawInkRects
            guard ink.count >= 8 else { return "chỉ vẽ được \(ink.count) vệt mực" }
            guard Set(ink.map { ($0.minX * 10).rounded() }).count >= 3 else {
                return "mọi vệt mực bắt đầu cùng một chỗ — thụt lề không lên bản đồ"
            }
            guard Set(ink.map { ($0.width * 10).rounded() }).count >= 3 else {
                return "mọi vệt mực dài như nhau — độ dài dòng không lên bản đồ"
            }
            if let stray = ink.first(where: { $0.minX < 0 || $0.maxX > view.lastDrawBounds.width }) {
                return "vệt mực \(stray) nằm ngoài dải rộng \(view.lastDrawBounds.width)pt"
            }

            // Rồi ĐỔI bề cao cửa sổ. Đây là chỗ bắt được lỗi thật: bản đồ dựng một lần rồi nhớ
            // tạm theo tài liệu, nên nếu số hàng không nằm trong khóa nhớ tạm thì nó giữ nguyên
            // số hàng cũ mãi mãi — kể cả số hàng dựng lúc bố cục chưa áp, tức là MỘT hàng, tức
            // là một cột xám đều. Tài liệu có đổi đâu mà dựng lại.
            let tall = view.lastDrawBounds.height
            controller.setWindowHeightForSelfTest(Double(tall) / 2)
            controller.drawDocumentMapForSelfTest()
            guard view.lastDrawBounds.height < tall else {
                return "co cửa sổ mà bản đồ vẫn cao \(tall)pt — móc đổi kích thước không ăn"
            }
            if let bad = rowsFollowHeight() { return bad }
            return nil
        },

        Case(name: "bấm vào bản đồ là nhảy tới đúng vùng ấy của tài liệu") { controller in
            let text = (0 ..< 2000).map { "dòng \($0)" }.joined(separator: "\n") + "\n"
            controller.prepareSelfTestDocument(text)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.toggleDocumentMapForSelfTest()
            controller.flushDrawingForSelfTest()

            controller.documentMapView.clickAtFractionForSelfTest(0.5)
            let line = controller.caretLineForSelfTest()
            guard abs(line - 1000) <= 5 else {
                return "bấm giữa bản đồ mà con nháy nhảy tới dòng \(line + 1), mong quanh 1001"
            }
            controller.toggleDocumentMapForSelfTest()
            return nil
        },

        Case(name: "khung tầm nhìn của bản đồ đi theo màn hình khi cuộn") { controller in
            let text = (0 ..< 3000).map { "dòng \($0)" }.joined(separator: "\n") + "\n"
            controller.prepareSelfTestDocument(text)
            controller.toggleDocumentMapForSelfTest()
            controller.flushDrawingForSelfTest()
            controller.refreshDocumentMap()
            let atTop = controller.documentMapView.visibleLinesForSelfTest
            guard !atTop.isEmpty else { return "khung tầm nhìn rỗng lúc ở đầu file" }

            // CUỘN thật, không chỉ dời con nháy: khung tầm nhìn nói về thứ đang HIỆN trên màn
            // hình, và đặt con nháy ở dòng 2500 mà không cuộn thì màn hình vẫn ở đầu file.
            let target = text.utf8.count / 2
            controller.scrollToForSelfTest(target)
            controller.flushDrawingForSelfTest()
            controller.refreshDocumentMap()

            let after = controller.documentMapView.visibleLinesForSelfTest
            guard after.lowerBound > atTop.lowerBound else {
                return "cuộn xuống giữa file mà khung tầm nhìn vẫn ở \(after)"
            }
            controller.toggleDocumentMapForSelfTest()
            return nil
        },

        // MARK: - Giữ quyền truy cập qua các phiên (App Sandbox)

        Case(name: "mở file là phiên mang theo bookmark, không chỉ đường dẫn") { controller in
            // Trong sandbox, đường dẫn trần KHÔNG mở lại được file ở lần chạy sau: quyền chết
            // theo lần chạy app. Thiếu bookmark thì khôi phục phiên hỏng IM LẶNG — người dùng
            // mở app thấy tab hôm qua biến mất, không thông báo gì.
            let directory = NSTemporaryDirectory() + "bookmark-\(UUID().uuidString)"
            let file = directory + "/phien.txt"
            // Dựng dữ liệu KHÔNG được nuốt lỗi. Bản đầu dùng `try?` cho cả hai bước, nên một
            // lần tạo thư mục hỏng sẽ hiện ra thành "không có bookmark" — tố cáo nhầm đúng thứ
            // bài kiểm định canh, và người đọc thông báo lỗi không có đường nào biết được.
            if let loi = Self.dungTepThu(directory: directory, file: file, noiDung: "nội dung\n") {
                return loi
            }
            defer { try? FileManager.default.removeItem(atPath: directory) }

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: file)

            let flags = controller.sessionBookmarksForSelfTest
            guard flags.contains(true) else {
                return "mở file xong mà không tab nào trong phiên có bookmark (\(flags))"
                    + Self.viSaoKhongCoBookmark(file)
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        Case(name: "mở lại từ bookmark cho đúng nội dung, và thả quyền khi đóng tab") { controller in
            let directory = NSTemporaryDirectory() + "bookmark-\(UUID().uuidString)"
            let file = directory + "/mo-lai.txt"
            if let loi = Self.dungTepThu(directory: directory, file: file, noiDung: "một\nhai\n") {
                return loi
            }
            defer { try? FileManager.default.removeItem(atPath: directory) }

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: file)
            guard let bookmark = controller.activeBookmarkForSelfTest else {
                return "tab vừa mở không có bookmark" + Self.viSaoKhongCoBookmark(file)
            }
            let before = SandboxAccess.activeCount
            controller.resetTabsForSelfTest()

            // Tài liệu chỉ được sống TRONG khối này. Mọi tham chiếu trong bài kiểm phải chết
            // trước khi đếm quyền, nếu không bài kiểm tự giữ nó sống rồi kết luận là app rò —
            // đúng thứ đã xảy ra ở bản đầu, vì `guard let` sinh thêm một tham chiếu sống tới
            // hết closure.
            weak var probe: Document?
            do {
                guard let opened = Document.open(bookmark: bookmark, preferredPath: file) else {
                    return "không mở lại được từ bookmark"
                }
                probe = opened
                guard opened.buffer.text == "một\nhai\n" else {
                    return "mở lại ra nội dung khác: «\(opened.buffer.text)»"
                }
                guard opened.path == file else {
                    return "mở lại đổi đường dẫn thành «\(opened.path ?? "nil")» — tab sẽ hiện khác hôm qua"
                }
                controller.adoptDocumentForSelfTest(opened)
            }
            controller.resetTabsForSelfTest()

            // Quyền phải được thả khi tài liệu ra khỏi tầm; không thả thì nó tích lại suốt phiên.
            guard SandboxAccess.activeCount <= before else {
                return probe == nil
                    ? "tài liệu đã giải phóng mà quyền không được thả"
                    : "tài liệu VẪN CÒN SỐNG sau khi đóng tab — chỗ nào đó đang giữ nó"
            }
            return nil
        },

        Case(name: "workspace sống qua lần khởi động, kèm bookmark") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let folder = root.appendingPathComponent("du-an")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? "a\n".write(to: folder.appendingPathComponent("mot.txt"),
                             atomically: true, encoding: .utf8)

            controller.resetTabsForSelfTest()
            controller.openWorkspaceForSelfTest(folder.path)
            guard controller.workspaceRootForSelfTest == folder.path else {
                return "mở thư mục xong mà controller không nhớ: \(controller.workspaceRootForSelfTest ?? "nil")"
            }
            let saved = controller.sessionWorkspaceForSelfTest
            guard saved.path == folder.path, saved.hasBookmark else {
                return "phiên ghi thư mục là \(saved.path ?? "nil"), bookmark: \(saved.hasBookmark)"
                    + Self.viSaoKhongCoBookmark(folder.path)
            }
            controller.saveSession()

            // Quên sạch rồi mở lại TỪ ĐĨA — kể cả khi không có tab nào đáng khôi phục, thư mục
            // vẫn phải quay lại.
            controller.resetTabsForSelfTest()
            controller.closeWorkspaceForSelfTest()
            guard controller.workspaceRootForSelfTest == nil else { return "đóng không sạch" }

            _ = controller.restoreSession()
            guard controller.workspaceRootForSelfTest == folder.path else {
                return "mở lại phiên mà thư mục không quay lại: "
                    + (controller.workspaceRootForSelfTest ?? "nil")
            }
            controller.closeWorkspaceForSelfTest()
            controller.resetTabsForSelfTest()
            return nil
        },

        // MARK: - Công cụ XML (FR-FMT-505)

        Case(name: "định dạng XML là MỘT bước undo và giữ nguyên văn thuộc tính") { controller in
            let source = "<a ten='Nguyễn' ghi=\"x &amp; y\"><b><c/></b></a>"
            controller.prepareSelfTestDocument(source)
            controller.formatXML(nil)

            let formatted = controller.documentTextForSelfTest
            guard formatted.contains("ten='Nguyễn'"), formatted.contains("ghi=\"x &amp; y\"") else {
                return "định dạng xong mà thuộc tính bị viết lại: «\(formatted)»"
            }
            guard formatted.contains("\n  <b>") else {
                return "không thụt lề: «\(formatted)»"
            }
            controller.undoDocument(nil)
            guard controller.documentTextForSelfTest == source else {
                return "một lần undo không trả lại nguyên bản"
            }
            return nil
        },

        Case(name: "XML hỏng thì KHÔNG sửa file, con nháy nhảy tới chỗ lỗi") { controller in
            let source = "<a>\n  <b>\n  </c>\n</a>\n"
            controller.prepareSelfTestDocument(source)
            controller.formatXML(nil)

            guard controller.documentTextForSelfTest == source else {
                return "file hỏng mà vẫn bị sửa"
            }
            let line = controller.caretLineForSelfTest()
            guard line == 2 else { return "con nháy ở dòng \(line + 1), mong dòng 3" }
            let message = controller.bannerMessageForSelfTest
            guard message.contains("</c>") else {
                return "thông báo «\(message)» không nói ra thẻ nào sai"
            }
            return nil
        },

        Case(name: "kiểm XML hợp lệ thì nói rõ là hợp lệ") { controller in
            controller.prepareSelfTestDocument("<a><b/></a>")
            controller.validateXML(nil)
            guard controller.bannerMessageForSelfTest.contains("well-formed") else {
                return "báo «\(controller.bannerMessageForSelfTest)»"
            }
            return nil
        },

        Case(name: "gấp thẻ XML: dấu > trong thuộc tính không đóng thẻ") { controller in
            let source = "<a>\n  <b title=\"x > y\">\n    <c/>\n  </b>\n</a>\n"
            controller.prepareSelfTestDocument(source)
            controller.setSyntaxLanguageForSelfTest(.xml)
            controller.setCaretForSelfTest(documentOffset: 5)      // dòng `<b …>`
            controller.toggleFold(nil)

            guard controller.foldedHeaderLinesForSelfTest == [1] else {
                return "gấp ra \(controller.foldedHeaderLinesForSelfTest), mong [1]"
            }
            let visible = controller.visibleWindowTextForSelfTest
            guard visible == "<a>\n  <b title=\"x > y\">\n</a>\n" else {
                return "chữ hiện ra là «\(visible)»"
            }
            controller.unfoldAll(nil)
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        // MARK: - Gấp mã (FR-CORE · FR-FMT-507)

        Case(name: "gấp khối YAML thì chữ biến mất khỏi màn hình, mở lại thì về đủ") { controller in
            let source = "ten: cua hang\ndia_chi:\n  so: 12\n  duong: Lê Lợi\nghi_chu: xong\n"
            controller.prepareSelfTestDocument(source)
            controller.setSyntaxLanguageForSelfTest(.yaml)
            controller.setCaretForSelfTest(documentOffset: source.utf8.count - 1)

            // Con nháy đặt vào dòng `dia_chi:` rồi gấp.
            let diaChi = source.range(of: "dia_chi:")!
            let offset = source.utf8.distance(
                from: source.utf8.startIndex, to: diaChi.lowerBound.samePosition(in: source.utf8)!
            )
            controller.setCaretForSelfTest(documentOffset: offset)
            controller.toggleFold(nil)

            guard controller.foldedHeaderLinesForSelfTest == [1] else {
                return "gấp xong mà danh sách vùng gấp là \(controller.foldedHeaderLinesForSelfTest)"
            }
            let folded = controller.visibleWindowTextForSelfTest
            guard folded == "ten: cua hang\ndia_chi:\nghi_chu: xong\n" else {
                return "chữ hiện ra sau khi gấp là «\(folded)»"
            }
            // Tài liệu KHÔNG được đụng vào: gấp là cách nhìn, không phải sửa file.
            guard controller.documentTextForSelfTest == source else {
                return "gấp mà tài liệu bị sửa"
            }
            // Phải CÓ dấu hiệu trên màn hình. Không có thì người dùng tưởng file mất nội dung —
            // bản này chưa có lề số dòng nên phù hiệu `⋯` là chỗ duy nhất nói ra điều ấy.
            //
            // Ép vẽ trước khi hỏi: TextKit 2 dựng bố cục LƯỜI, nên hỏi ngay sau khi đổi chuỗi
            // sẽ nhận về rỗng cho một phù hiệu thật ra vẫn hiện đúng.
            controller.flushDrawingForSelfTest()
            let markers = controller.foldMarkerRectsForSelfTest
            guard markers.count == 1, markers[0].width > 0, markers[0].height > 0 else {
                return "gấp xong mà không có phù hiệu nào trên màn hình (\(markers))"
            }

            controller.toggleFold(nil)
            guard controller.foldedHeaderLinesForSelfTest.isEmpty,
                  controller.visibleWindowTextForSelfTest == source else {
                return "mở lại mà chữ không về đủ"
            }
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "con nháy trong chỗ vừa gấp được đưa về cuối dòng đầu") { controller in
            let source = "a:\n  x: 1\n  y: 2\nb: 3\n"
            controller.prepareSelfTestDocument(source)
            controller.setSyntaxLanguageForSelfTest(.yaml)
            // Đứng ở giữa `  y: 2` rồi gấp khối chứa nó.
            controller.setCaretForSelfTest(documentOffset: 14)
            controller.toggleFold(nil)

            let caret = controller.caretOffsetForSelfTest
            guard caret == 2 else {
                return "con nháy ở \(caret), lẽ ra phải về cuối `a:` là 2 — nếu không nó nằm "
                    + "trong chữ vô hình và phím mũi tên kế tiếp đi từ hư không"
            }
            controller.unfoldAll(nil)
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "gõ khi đang gấp: chữ vào đúng chỗ, phần gấp không lệch") { controller in
            let source = "a:\n  x: 1\n  y: 2\nb: 3\n"
            controller.prepareSelfTestDocument(source)
            controller.setSyntaxLanguageForSelfTest(.yaml)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.toggleFold(nil)
            guard controller.foldedHeaderLinesForSelfTest == [0] else { return "không gấp được" }

            // Gõ vào CUỐI tài liệu, tức là sau phần đang bị giấu.
            controller.editorViewSetCaretToEndForSelfTest()
            controller.typeForSelfTest("!")

            guard controller.documentTextForSelfTest == source + "!" else {
                return "tài liệu thành «\(controller.documentTextForSelfTest)»"
            }
            let visible = controller.visibleWindowTextForSelfTest
            guard visible == "a:\nb: 3\n!" else {
                return "chữ hiện ra thành «\(visible)» — vùng gấp lệch sau khi gõ"
            }
            controller.unfoldAll(nil)
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "gấp tất cả chỉ gấp khối NGOÀI CÙNG") { controller in
            controller.prepareSelfTestDocument("a:\n  b:\n    1\n  c: 2\nd: 3\n")
            controller.setSyntaxLanguageForSelfTest(.yaml)
            controller.foldAll(nil)
            guard controller.foldedHeaderLinesForSelfTest == [0] else {
                return "gấp tất cả ra \(controller.foldedHeaderLinesForSelfTest), mong [0] — "
                    + "gấp cả khối lồng bên trong thì mở ra phải bấm hai lần mà kết quả y hệt"
            }
            guard controller.visibleWindowTextForSelfTest == "a:\nd: 3\n" else {
                return "chữ hiện ra là «\(controller.visibleWindowTextForSelfTest)»"
            }
            controller.unfoldAll(nil)
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "gấp theo cấp (FR-FMT-503): cấp 2 gấp khối LỒNG, khối ngoài vẫn mở") { controller in
            controller.unfoldAll(nil)
            controller.prepareSelfTestDocument("a:\n  b:\n    1\n  c:\n    2\nd: 3\n")
            controller.setSyntaxLanguageForSelfTest(.yaml)

            // Cấp 1 và cấp 2 phải cho hai kết quả KHÁC nhau — nếu chúng giống nhau thì "theo
            // cấp" chỉ là tên gọi khác của "gấp tất cả", tức vẫn thiếu đúng vế đặc tả đòi.
            controller.foldToLevel(Self.menuItem(level: 1))
            let level1 = controller.foldedHeaderLinesForSelfTest
            guard level1 == [0] else { return "cấp 1 gấp \(level1), mong [0]" }

            controller.foldToLevel(Self.menuItem(level: 2))
            let level2 = controller.foldedHeaderLinesForSelfTest
            guard level2 == [1, 3] else { return "cấp 2 gấp \(level2), mong [1, 3]" }
            // Gấp cấp THAY THẾ trạng thái đang gấp chứ không cộng dồn: khối ngoài phải mở ra.
            guard controller.visibleWindowTextForSelfTest == "a:\n  b:\n  c:\nd: 3\n" else {
                return "chữ hiện ra là «\(controller.visibleWindowTextForSelfTest)»"
            }

            controller.unfoldAll(nil)
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "gấp cấp sâu hơn tài liệu thì NÓI RA, không im lặng không làm gì") { controller in
            controller.unfoldAll(nil)
            controller.prepareSelfTestDocument("a:\n  b: 1\nc: 2\n")
            controller.setSyntaxLanguageForSelfTest(.yaml)

            controller.foldToLevel(Self.menuItem(level: 5))
            guard controller.foldedHeaderLinesForSelfTest.isEmpty else {
                return "gấp được cấp 5 trên tài liệu chỉ sâu 1 cấp"
            }
            // Một lệnh không đổi gì trên màn hình trông y hệt một lệnh hỏng.
            let status = controller.bannerMessageForSelfTest
            guard status.contains("chỉ sâu") else { return "thông báo là «\(status)»" }

            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "bản dịch giữ NGUYÊN các ô định dạng — dịch hụt một %d là sập app") { controller in
            _ = controller
            // FR-UI-804. Từ 28/08/2026 bảng dịch có chuỗi ĐỊNH DẠNG (`"Cột %d"`), và chúng mở ra
            // một loại lỗi mà nhãn thường không có: `String(format:)` đọc tham số theo ĐÚNG số ô
            // trong chuỗi. Bản tiếng Anh thiếu một `%d` thì đối số thứ hai bị đọc như rác; thừa
            // một ô thì nó đọc qua cuối danh sách. Cả hai đều SẬP, và chỉ sập với người dùng
            // chạy giao diện tiếng Anh — tức không ai trong nhóm gặp.
            //
            // So theo BỘI SỐ chứ không theo thứ tự: một ngôn ngữ được phép đảo thứ tự bằng
            // `%1$@`/`%2$@`, nhưng không được phép đổi TẬP các ô.
            let o = try? NSRegularExpression(pattern: "%(?:[0-9]+\\\\$)?[-0-9.]*[@dfsu]")
            guard let o else { return "không dựng được biểu thức dò ô định dạng" }
            func oDinhDang(_ s: String) -> [String] {
                o.matches(in: s, range: NSRange(s.startIndex..., in: s))
                    .compactMap { Range($0.range, in: s).map { r in String(s[r]) } }
                    .sorted()
            }

            var lech: [String] = []
            for (viet, anh) in L10n.en {
                let a = oDinhDang(viet), b = oDinhDang(anh)
                if a != b { lech.append("«\(viet)» có \(a) mà bản Anh có \(b)") }
            }
            guard lech.isEmpty else {
                return "bản dịch lệch ô định dạng: " + lech.sorted().prefix(3).joined(separator: " · ")
            }
            return nil
        },

        // MARK: - Hai panel từng 0% độ phủ (MNT-02bis)
        //
        // `ColumnEditorPanel` và `SearchResultsView` đều thuộc FR đã ✅ (FR-CORE-003,
        // FR-SRCH-105) mà **không một dòng nào của chúng từng chạy trong bất kỳ bài kiểm nào**.
        // Bốn bài dưới đây đóng khoảng trống ấy, và cả bốn đi qua ĐÚNG những điều khiển người
        // dùng chạm tới — gọi tắt vào lõi thì vẫn để nguyên phần NỐI, tức đúng chỗ đang hở.

        Case(name: "Prompt & JSON Schema (FR-KNW-909): gấp frontmatter, và lỗi schema chỉ đúng dòng") { controller in
            // Vế một: frontmatter gấp được, và dòng «---» đầu vẫn hiện để bấm mở lại.
            controller.prepareSelfTestDocument("""
            ---
            model: claude
            temperature: 0.2
            ---
            Xin chào {{ ten }}.

            """)
            let vung = controller.foldRangesIncludingFrontmatter()
            guard vung.first?.headerLine == 0, vung.first?.lastLine == 3 else {
                return "vùng gấp frontmatter sai: \(vung.map { ($0.headerLine, $0.lastLine) })"
            }

            // Vế hai: lỗi schema phải chỉ ĐÚNG DÒNG — không phải dồn hết về dòng 0.
            controller.prepareSelfTestDocument("""
            {
              "name": "tra_cuu",
              "parameters": {},
              "retries": 99
            }

            """)
            controller.kiemTheoSchema("""
            {"type": "object",
             "properties": {"retries": {"type": "integer", "maximum": 5}}}
            """)
            let d = controller.lastSchemaDiagnostics
            guard d.count == 1 else { return "mong đúng một lỗi, có \(d.count): \(d)" }
            guard d[0].line == 3 else {
                return "lỗi chỉ dòng \(d[0].line), mong 3 — dồn về dòng 0 là dấu hiệu tra đường "
                    + "dẫn hỏng"
            }
            guard controller.searchResultsVisibleForSelfTest else {
                return "lỗi không hiện lên danh sách kết quả"
            }
            controller.hideResultsPanel()

            // Vế ba: từ khoá schema CHƯA HIỂU phải được đánh dấu riêng, không trộn với lỗi dữ liệu.
            controller.kiemTheoSchema("{\"type\": \"object\", \"oneOf\": []}")
            guard controller.lastSchemaDiagnostics.first?.unsupported == true else {
                return "«oneOf» không được đánh dấu là chưa hiểu: \(controller.lastSchemaDiagnostics)"
            }
            controller.hideResultsPanel()
            return nil
        },

        Case(name: "Kiểm cú pháp đồ thị (FR-KNW-904): lỗi vào danh sách kết quả, bấm nhảy được") { controller in
            let duong = NSTemporaryDirectory() + "geditor-selftest-knw904.dot"
            // `rankdir=LR` là GÁN THUỘC TÍNH ĐỒ THỊ — `DOTGraph` đọc được nhưng bỏ qua và nói ra
            // bằng cảnh báo. Đầu vào cũ (`a -> ;`) KHÔNG sinh cảnh báo nào, nên bài kiểm lõi
            // tương ứng so hai danh sách rỗng và xanh vô nghĩa; bài này bắt được điều đó.
            try? "digraph {\n  rankdir=LR\n  a -> b;\n}\n"
                .write(toFile: duong, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: duong) }

            controller.openInNewTabForSelfTest(path: duong)
            controller.validateGraphSyntax(nil)

            guard !controller.lastGraphDiagnostics.isEmpty else {
                return "tệp DOT hỏng mà không báo lỗi nào"
            }
            // Chẩn đoán phải khớp NGUYÊN VĂN cảnh báo của bộ đọc thật — hai bên không được nói
            // hai chuyện khác nhau về cùng một tệp.
            let boDoc = DOTGraph.parse(controller.editorDocument.buffer.text).warnings
            guard controller.lastGraphDiagnostics.map(\.line) == boDoc.map(\.line) else {
                return "lệch số dòng với bộ đọc: \(controller.lastGraphDiagnostics.map(\.line)) "
                    + "so \(boDoc.map(\.line))"
            }
            // Và lỗi phải HIỆN RA ở danh sách kết quả, không chỉ nằm trong biến.
            guard controller.searchResultsVisibleForSelfTest,
                  !controller.searchResultRowsForSelfTest.isEmpty else {
                return "không hiện lên danh sách kết quả"
            }
            controller.hideResultsPanel()

            // Tệp KHÔNG phải định dạng đồ thị thì nói ra, không đoán bừa.
            controller.prepareSelfTestDocument("chỉ là ghi chú\n")
            controller.validateGraphSyntax(nil)
            guard controller.bannerMessageForSelfTest.contains("Chưa nhận ra")
                    || controller.bannerMessageForSelfTest.contains("Unrecognised") else {
                return "tệp lạ mà không nói ra: «\(controller.bannerMessageForSelfTest)»"
            }
            controller.closeCurrentTabForSelfTest()
            return nil
        },

        Case(name: "API script jsonl.* và graph.* (FR-KNW-912) chạy thật trong JSContext") { controller in
            // JSONL có một dòng HỎNG và một trường chỉ có ở nửa số bản ghi — để `validate` và
            // `stats` có gì thật mà trả lời.
            controller.prepareSelfTestDocument("""
            {"id":"c1","text":"Một","source":"web"}
            {"id":"c2","text":"Hai","source":""}
            dòng hỏng
            {"id":"c3","text":"Ba"}

            """)
            controller.runScript(source: """
                var r = jsonl.records(doc.text);
                var v = jsonl.validate(doc.text);
                var s = jsonl.stats(doc.text);
                doc.log("records=" + r.length);
                doc.log("ok=" + v.ok + " loi=" + v.errors.length + " dong=" + v.errors[0].line);
                doc.log("count=" + s.count + " source=" + s.fields.source.present);
                """, name: "knw912-jsonl.js")

            let log = controller.scriptLogForSelfTest.joined(separator: " | ")
            guard log.contains("records=3") else { return "jsonl.records sai: \(log)" }
            // `validate` phải nói ĐÚNG DÒNG hỏng, và `records` bỏ qua nó — hai hàm trả lời hai
            // câu khác nhau, gộp lại thì chỗ gọi không biết dữ liệu đủ hay thiếu.
            guard log.contains("ok=false"), log.contains("loi=1"), log.contains("dong=3") else {
                return "jsonl.validate sai: \(log)"
            }
            // Chuỗi RỖNG không tính là có giá trị — cùng luật CorpusSQL.
            guard log.contains("source=1") else {
                return "jsonl.stats tính chuỗi rỗng là có giá trị: \(log)"
            }

            controller.prepareSelfTestDocument("""
            digraph {
              a [label="An"];
              b [label="Bình"];
              a -> b [label="biết"];
            }

            """)
            controller.runScript(source: """
                doc.log("nodes=" + graph.nodes(doc.text).length);
                doc.log("edge0=" + graph.edges(doc.text)[0].label);
                var q = graph.query(doc.text, "MATCH (n) RETURN n");
                doc.log("query=" + (q.error ? "LOI:" + q.error : q.rows.length));
                var xau = graph.query(doc.text, "câu này không phải Cypher");
                doc.log("xau=" + (xau.error ? "co-loi" : "KHONG-BAO-LOI"));
                """, name: "knw912-graph.js")

            let log2 = controller.scriptLogForSelfTest.joined(separator: " | ")
            guard log2.contains("nodes=2"), log2.contains("edge0=biết") else {
                return "graph.nodes/edges sai: \(log2)"
            }
            // Câu sai trả LỖI THÀNH DỮ LIỆU, không ném ngoại lệ — một script chạy hàng loạt file
            // sẽ dừng hẳn ở file đầu tiên có cú pháp lạ nếu nó ném.
            guard log2.contains("xau=co-loi") else {
                return "graph.query câu sai mà không trả lỗi: \(log2)"
            }
            return nil
        },

        Case(name: "Khai phá văn bản (FR-MIN-006): bảng ra tab mới, rồi tô ngược lên tài liệu") { controller in
            controller.prepareSelfTestDocument("""
            Cơ sở dữ liệu lớn. Cơ sở dữ liệu nhỏ.

            """)
            let nguon = controller.editorDocument.buffer.text
            let tabTruoc = controller.tabCountForSelfTest

            controller.showTextMining(nil)

            guard controller.tabCountForSelfTest == tabTruoc + 1 else {
                return "không mở tab bảng từ khoá"
            }
            let bang = controller.editorDocument.buffer.text
            guard bang.hasPrefix("tu_khoa,bac,tan_suat,so_tai_lieu,tfidf") else {
                return "tab mới không phải bảng từ khoá: «\(bang.prefix(50))»"
            }
            guard let report = controller.lastMiningReport, !report.terms.isEmpty else {
                return "không có báo cáo khai phá"
            }
            // Corpus MỘT tài liệu thì phải NÓI RA rằng cột TF-IDF không phân biệt được gì.
            guard report.methodology.contains("Chỉ MỘT tài liệu") else {
                return "không nói ra giới hạn của TF-IDF trên một tài liệu"
            }

            // Vế "click từ → Mark mọi occurrence": đi qua FR-KNW-908, không dựng đường tô thứ hai.
            controller.toTuKhoaLenTaiLieu()
            guard controller.editorDocument.buffer.text == nguon else {
                return "không quay về tab nguồn — tô lên bảng từ khoá thì vô nghĩa"
            }
            guard let ent = controller.lastEntityReport, !ent.occurrences.isEmpty else {
                return "không tô được từ khoá nào lên tài liệu"
            }
            guard !controller.markedBandsForSelfTest().isEmpty else { return "không có dấu nào" }
            return nil
        },

        Case(name: "Đánh dấu entity (FR-KNW-908): tô theo LOẠI, và thống kê đếm đủ") { controller in
            let duong = NSTemporaryDirectory() + "geditor-selftest-entity.csv"
            try? "text,type\nAn,PER\nAn Phát,ORG\n".write(toFile: duong, atomically: true,
                                                            encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: duong) }

            controller.prepareSelfTestDocument("""
            An gặp An Phát.
            Anh ấy về.
            AN PHÁT ký.

            """)
            let nguon = controller.editorDocument.buffer.text
            controller.napVaDanhDauEntity(path: duong)

            guard let report = controller.lastEntityReport else { return "không có báo cáo" }

            // «An Phát» là cụm DÀI nên nó thắng «An»; «Anh» KHÔNG được khớp «An».
            guard report.byEntity[1] == 2 else {
                return "«An Phát» khớp \(report.byEntity[1] ?? 0) lần, mong 2 (kể cả AN PHÁT hoa)"
            }
            guard report.byEntity[0] == 1 else {
                return "«An» khớp \(report.byEntity[0] ?? 0) lần, mong 1 — «Anh» không được tính"
            }
            guard report.byType["ORG"] == 2, report.byType["PER"] == 1 else {
                return "thống kê theo loại sai: \(report.byType)"
            }

            // Hai loại phải nhận hai MÀU khác nhau.
            guard report.colorOfType["ORG"] != report.colorOfType["PER"] else {
                return "hai loại cùng màu: \(report.colorOfType)"
            }
            // Và có dấu thật trên tài liệu.
            guard !controller.markedBandsForSelfTest().isEmpty else { return "không tô dấu nào" }

            // Đánh dấu là CÁCH NHÌN — tài liệu không được đổi.
            guard controller.editorDocument.buffer.text == nguon else {
                return "đánh dấu mà tài liệu đã đổi"
            }
            return nil
        },

        Case(name: "Chuyển đổi tri thức (FR-KNW-910): xem trước rồi mới ra tab mới") { controller in
            controller.prepareSelfTestDocument("""
            digraph {
              a [label="An"];
              b [label="Bình"];
              a -> b [label="biết"];
            }

            """)
            let nguon = controller.editorDocument.buffer.text
            let tabTruoc = controller.tabCountForSelfTest

            // Hai nửa kiểm riêng, vì `Unattended.ask` cố ý KHÔNG tự bấm đồng ý cho hộp thoại.
            //
            // Nửa một: bản xem trước phải là năm dòng ĐẦU của kết quả thật.
            let xem = try? KnowledgeConvert.preview(nguon, from: .graphDOT, to: .graphEdgeList)
            guard let xem, xem.hasPrefix("source\ttarget\tlabel") else {
                return "xem trước sai: «\(xem ?? "nil")»"
            }
            // Nửa hai: áp thì ra tab mới.
            controller.chuyenDoiTriThucForSelfTest(from: .graphDOT, to: .graphEdgeList)
            controller.apChuyenDoiTriThuc()

            guard controller.tabCountForSelfTest == tabTruoc + 1 else {
                return "áp chuyển đổi mà không mở tab mới"
            }
            let ra = controller.editorDocument.buffer.text
            guard ra.hasPrefix("source\ttarget\tlabel") else {
                return "tab mới không phải edge list: «\(ra.prefix(50))»"
            }
            guard ra.contains("biết") else { return "mất nhãn cạnh: \(ra)" }

            // Tài liệu NGUỒN không bị đụng.
            controller.closeCurrentTabForSelfTest()
            guard controller.editorDocument.buffer.text == nguon else {
                return "file DOT gốc đã bị sửa"
            }
            return nil
        },

        Case(name: "Chuyển đổi tri thức: cặp KHÔNG hỗ trợ thì nói ra lý do, không im lặng") { controller in
            controller.prepareSelfTestDocument("# tiêu đề\n")
            let tabTruoc = controller.tabCountForSelfTest
            controller.chuyenDoiTriThucForSelfTest(from: .chunksMarkdown, to: .chunksJSONL)

            guard controller.tabCountForSelfTest == tabTruoc else {
                return "cặp không hỗ trợ mà vẫn mở tab"
            }
            // Lý do phải DẪN người dùng đi đâu tiếp, không chỉ nói "không được".
            let bao = controller.bannerMessageForSelfTest
            guard bao.contains("cắt chunk") || bao.contains("CẮT CHUNK") else {
                return "không dẫn sang FR-KNW-903: «\(bao)»"
            }
            return nil
        },

        Case(name: "Xem trước cắt chunk (FR-KNW-903): tô ranh giới, rồi xuất JSONL ra tab MỚI") { controller in
            controller.prepareSelfTestDocument("""
            # Một
            nội dung một
            # Hai
            nội dung hai

            """)
            let nguon = controller.editorDocument.buffer.text
            let tabTruoc = controller.tabCountForSelfTest

            controller.catChunkForSelfTest(.heading(level: 1))

            // Ranh giới tô bằng DẤU DÒNG, nên bản đồ tài liệu và "nhảy dấu kế tiếp" thấy luôn.
            let danhDau = controller.markedBandsForSelfTest().map(\.line).sorted()
            guard danhDau == [0, 2] else {
                return "dấu ranh giới ở \(danhDau), mong [0, 2]"
            }
            // Tài liệu KHÔNG bị đụng — xem trước là cách nhìn, không phải một phép sửa.
            guard controller.editorDocument.buffer.text == nguon else {
                return "xem trước mà tài liệu đã đổi"
            }

            controller.xuatChunkJSONL()
            guard controller.tabCountForSelfTest == tabTruoc + 1 else {
                return "xuất JSONL không mở tab mới"
            }
            let jsonl = controller.editorDocument.buffer.text
            guard jsonl.contains("\"start\"") , jsonl.contains("\"heading\"") else {
                return "JSONL thiếu offset hoặc heading: «\(jsonl.prefix(80))»"
            }
            controller.closeCurrentTabForSelfTest()
            return nil
        },

        Case(name: "Bảng triple (FR-KNW-906): ra tab MỚI, và dòng hỏng được ĐẾM chứ không nuốt") { controller in
            controller.prepareSelfTestDocument("""
            <http://a/s1> <http://a/p> "Hà Nội"@vi .
            dòng này hỏng
            <http://a/s2> <http://a/p> <http://a/o> .

            """)
            let nguon = controller.editorDocument.buffer.text
            let tabTruoc = controller.tabCountForSelfTest

            controller.showTripleTable(nil)

            guard controller.tabCountForSelfTest == tabTruoc + 1 else {
                return "không mở tab mới: \(tabTruoc) → \(controller.tabCountForSelfTest)"
            }
            let bang = controller.editorDocument.buffer.text
            guard bang.hasPrefix("subject\tpredicate\tobject\tdong") else {
                return "tab mới không phải bảng triple: «\(bang.prefix(60))»"
            }
            // Hậu tố ngôn ngữ phải còn nguyên — cắt đi là mất thông tin không khôi phục được.
            //
            // Đọc NGƯỢC bảng ra rồi mới so, không so trên chữ thô: literal `"Hà Nội"@vi` có dấu
            // nháy nên `CSVEngine.escape` bọc nó lại — đúng như phải thế. So trên chữ thô sẽ
            // bắt bộ bọc làm việc của nó thành một lỗi, và cách "sửa" duy nhất khi ấy là tắt
            // bọc đi — tức phá đúng thứ giữ cho bảng không vỡ.
            var doiTuong: [String] = []
            try? CSVEngine.forEachRow(in: controller.editorDocument.buffer, dialect: .tab) { row in
                if row.count > 2 {
                    doiTuong.append(String(
                        decoding: CSVEngine.unescape(
                            controller.editorDocument.buffer.bytes(in: row[2].range),
                            dialect: .tab),
                        as: UTF8.self))
                }
                return true
            }
            guard doiTuong.contains("\"Hà Nội\"@vi") else {
                return "mất hậu tố @vi sau khi đọc ngược bảng: \(doiTuong)"
            }

            // Dòng hỏng phải được NÓI RA, không im lặng bỏ qua.
            let bao = controller.bannerMessageForSelfTest
            guard bao.contains("1 dòng hỏng") || bao.contains("1 malformed") else {
                return "không nói ra dòng hỏng: «\(bao)»"
            }

            // Và tài liệu NGUỒN không bị đụng tới.
            controller.closeCurrentTabForSelfTest()
            guard controller.editorDocument.buffer.text == nguon else {
                return "file .nt gốc đã bị sửa"
            }
            return nil
        },

        Case(name: "Trùng lặp mờ (FR-CLN-004): KHÔNG tick thì KHÔNG gộp gì") { controller in
            // Bất biến quan trọng nhất của mã này, và nó phải sống qua tầng giao diện chứ không
            // chỉ ở lõi: đặc tả viết thẳng "không bao giờ tự merge". Bảng khởi đầu KHÔNG tick
            // cụm nào, và nút Gộp phải TẮT — một hộp thoại tick sẵn tất cả biến việc mất dữ
            // liệu im lặng thành một cú Enter.
            controller.prepareSelfTestDocument("""
            ma,ten
            1,Công ty TNHH An Phát
            2,Cty TNHH An Phát
            3,CÔNG TY TNHH AN PHAT
            4,Xưởng gỗ Trường Sơn

            """)
            let truoc = controller.editorDocument.buffer.text
            let cum = try? CSVFuzzyDedup.scan(column: 1, in: controller.editorDocument.buffer,
                                              dialect: .comma)
            guard let cum, cum.count == 1 else {
                return "quét ra \(cum?.count ?? -1) cụm, mong 1"
            }

            let sheet = CSVFuzzyDedupSheet(clusters: cum, columnName: "ten")
            _ = sheet.view          // ép dựng giao diện
            guard !sheet.canApplyForSelfTest else {
                return "chưa tick cụm nào mà nút Gộp đã BẬT"
            }
            guard sheet.summaryForSelfTest.contains("KHÔNG có gì thay đổi") else {
                return "không nói ra rằng chưa chọn gì thì không đổi gì: «\(sheet.summaryForSelfTest)»"
            }

            // Tick một cụm thì nút mới bật, và con số phải nói ra bao nhiêu hàng sẽ đổi.
            sheet.tickForSelfTest(0)
            guard sheet.canApplyForSelfTest else { return "tick rồi mà nút Gộp vẫn tắt" }
            guard sheet.summaryForSelfTest.contains("3 hàng") else {
                return "tóm tắt không nói đúng số hàng: «\(sheet.summaryForSelfTest)»"
            }

            // Và tài liệu vẫn chưa bị đụng — tick chỉ là ý định, chưa phải hành động.
            guard controller.editorDocument.buffer.text == truoc else {
                return "mới tick mà tài liệu đã đổi"
            }
            return nil
        },

        Case(name: "Column Editor: dãy số hex có đệm 0 — xem trước rồi OK, MỘT bước undo") { controller in
            controller.prepareSelfTestDocument("a\nb\nc\nd\n")
            // Khối cột ba dòng: đây là điều kiện để `showColumnEditor` không kêu bíp.
            controller.selectColumnBlockForSelfTest(from: (line: 0, column: 1), to: (line: 2, column: 1))
            controller.showColumnEditor(nil)

            guard let panel = controller.columnEditorPanelForSelfTest else {
                return "bấm Column Editor mà không có panel nào mở"
            }
            panel.setModeForSelfTest(1)          // Dãy số
            panel.setFieldsForSelfTest(start: "10", step: "5", padding: "4",
                                       radix: .hexadecimal, uppercase: true)

            // Xem trước là thứ người dùng ĐỌC trước khi bấm OK. Nếu nó trống hoặc "—" thì họ
            // đang bấm mù, và bài kiểm nào bỏ qua ô này sẽ không bao giờ bắt được điều đó.
            let xem = panel.previewForSelfTest
            guard xem.contains("000A") else { return "xem trước là «\(xem)», mong có 000A" }

            let truoc = controller.editorDocument.buffer.revision
            panel.confirmForSelfTest()

            let sau = controller.editorDocument.buffer.text
            guard sau == "a000A\nb000F\nc0014\nd\n" else {
                return "sau khi chèn: \(String(reflecting: sau))"
            }
            // Chèn vào ba dòng phải là MỘT bước hoàn tác, không phải ba.
            controller.undoForSelfTest()
            guard controller.editorDocument.buffer.text == "a\nb\nc\nd\n" else {
                return "một lần ⌘Z không trả về nguyên trạng: "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }
            _ = truoc
            return nil
        },

        Case(name: "Column Editor: ngày sai định dạng thì xem trước nói KHÔNG BIẾT, OK không chèn gì") { controller in
            controller.prepareSelfTestDocument("x\ny\n")
            controller.selectColumnBlockForSelfTest(from: (line: 0, column: 1), to: (line: 1, column: 1))
            controller.showColumnEditor(nil)
            guard let panel = controller.columnEditorPanelForSelfTest else {
                return "không có panel nào mở"
            }
            panel.setModeForSelfTest(2)          // Dãy ngày
            panel.setFieldsForSelfTest(date: "khong-phai-ngay", dateFormat: "dd/MM/yyyy")

            // `currentContent()` trả nil, nên xem trước phải nói ra chứ không hiện một dãy đoán.
            guard panel.previewForSelfTest == "—" else {
                return "ngày hỏng mà xem trước vẫn hiện «\(panel.previewForSelfTest)»"
            }
            panel.confirmForSelfTest()
            guard controller.editorDocument.buffer.text == "x\ny\n" else {
                return "OK với ngày hỏng mà vẫn chèn: "
                    + String(reflecting: controller.editorDocument.buffer.text)
            }
            return nil
        },

        Case(name: "Column Editor: Huỷ thì KHÔNG chạm vào tài liệu") { controller in
            controller.prepareSelfTestDocument("m\nn\n")
            controller.selectColumnBlockForSelfTest(from: (line: 0, column: 1), to: (line: 1, column: 1))
            controller.showColumnEditor(nil)
            guard let panel = controller.columnEditorPanelForSelfTest else {
                return "không có panel nào mở"
            }
            panel.setModeForSelfTest(0)
            panel.setFieldsForSelfTest(text: "ZZZ")
            let truoc = controller.editorDocument.buffer.revision
            panel.cancelForSelfTest()
            guard controller.editorDocument.buffer.revision == truoc else {
                return "bấm Huỷ mà tài liệu vẫn đổi"
            }
            return nil
        },

        Case(name: "Search Results: ba trạng thái đều hiện đúng, và lỗi không lẫn với kết quả") { controller in
            // Đang chạy → có kết quả → thông báo lỗi. Ba trạng thái dùng chung một bảng, nên
            // thứ đáng kiểm là chúng KHÔNG dính vào nhau.
            controller.showSearchRunningForSelfTest("Đang tìm \"abc\"…")
            guard controller.searchResultsVisibleForSelfTest else {
                return "gọi showRunning mà panel vẫn ẩn"
            }

            let hit = FindInFiles.Hit(byteRange: 4..<7, line: 2, byteColumn: 5,
                                      lineText: "let abc = 1")
            let summary = FindInFiles.Summary(
                results: [FindInFiles.FileResult(path: "/tmp/mot.swift", hits: [hit])],
                filesScanned: 3)
            controller.showSearchResultsForSelfTest(summary, pattern: "abc")

            let hang = controller.searchResultRowsForSelfTest
            guard hang.contains(where: { $0.contains("mot.swift") }) else {
                return "không thấy tên file trong bảng: \(hang)"
            }
            guard hang.contains(where: { $0.contains("let abc = 1") }) else {
                return "không thấy dòng chứa kết quả trong bảng: \(hang)"
            }

            // Chuyển sang thông báo thì bảng cũ phải BIẾN MẤT. Để lại kết quả của lần tìm trước
            // dưới một dòng "Đã hủy" là cách chắc chắn khiến người dùng đọc nhầm dữ liệu cũ
            // thành dữ liệu mới.
            controller.showSearchMessageForSelfTest("Đã hủy", isError: false)
            let sau = controller.searchResultRowsForSelfTest
            guard !sau.contains(where: { $0.contains("let abc = 1") }) else {
                return "hiện thông báo rồi mà kết quả cũ vẫn nằm lại: \(sau)"
            }
            controller.hideResultsPanel()
            return nil
        },

        Case(name: "Tự cập nhật (NFR-SEC-01): mục menu CÓ MẶT, và khả dụng đúng theo kênh") { controller in
            _ = controller
            // Mục menu phải có mặt ở CẢ HAI kênh — ở bản App Store nó nói ra vì sao không dùng
            // được. Một mục vắng mặt là câu hỏi hỗ trợ; một câu trả lời tại chỗ thì không.
            guard let mainMenu = NSApp.mainMenu else { return "chưa có thanh menu" }
            let co = Self.allMenuItems(under: mainMenu)
                .contains { $0.item.title == L("Kiểm tra bản cập nhật…") }
            guard co else { return "không thấy mục «Kiểm tra bản cập nhật…» trong thanh menu" }

            // Bản dựng hiện tại còn mang khoá GIỮ CHỖ, nên kênh phải tự coi là KHÔNG dùng được
            // và phải nói ra lý do. Đây là vế quan trọng: một kênh cập nhật trỏ tới khoá không
            // tồn tại mà im lặng sẽ hỏng đúng lúc có bản vá cần đẩy đi.
            //
            // `assumeIsolated` chứ không `Task { @MainActor }`: bộ tự kiểm CHẠY trên luồng chính
            // (nó bấm menu và đọc view), nên khẳng định này đúng — và nó giữ bài kiểm đồng bộ,
            // tức một lỗi vẫn trả về đúng lượt chạy này thay vì biến mất vào một Task.
            return MainActor.assumeIsolated { () -> String? in
            let bo = UpdateController.shared

            // Bài này chạy ở HAI ngữ cảnh và phải đúng ở cả hai, nên nó kiểm BẤT BIẾN chứ không
            // kiểm một kết quả cố định:
            //
            //  · từ binary trần trong `.build` — không có bundle nên `Bundle.main` không có
            //    `SUPublicEDKey`, kênh phải tự coi là KHÔNG dùng được và NÓI RA lý do;
            //  · từ bundle đã dựng (`run-self-test.sh --bundle`) — khoá thật có mặt từ
            //    28/08/2026, nên ở bản tải trực tiếp kênh phải dùng được.
            //
            // Bản trước của bài này neo vào "khoá còn là chỗ giữ chỗ" và CỐ Ý đỏ khi khoá thành
            // thật. Nó đã làm đúng việc ấy: khoá thật vào kho thì nó đỏ ngay, buộc phải sửa lại
            // đây thay vì để một bài kiểm nói về một thế giới không còn tồn tại.
            if bo.hasPlaceholderKey {
                guard !bo.isAvailable else {
                    return "không có khoá thật mà kênh vẫn tự nhận là dùng được"
                }
                guard let ly_do = bo.unavailableReason, !ly_do.isEmpty else {
                    return "không dùng được mà KHÔNG nói ra lý do"
                }
            } else {
                // Có khoá thật: chỉ còn KÊNH PHÁT HÀNH quyết định.
                guard bo.isAvailable == Distribution.current.supportsSelfUpdate else {
                    return "có khoá thật mà khả dụng (\(bo.isAvailable)) không khớp kênh "
                        + "\(Distribution.current.rawValue)"
                }
                if !bo.isAvailable {
                    guard let ly_do = bo.unavailableReason, !ly_do.isEmpty else {
                        return "bản App Store không cập nhật được mà KHÔNG nói ra lý do"
                    }
                }
            }

            // Và bấm vào mục ấy KHÔNG được dựng bộ cập nhật — dựng nó là kéo theo một lượt mạng
            // mà người dùng chưa cho phép.
            guard bo.diagnosticForSelfTest.contains("built=false") else {
                return "bộ cập nhật đã bị dựng dù kênh không dùng được: \(bo.diagnosticForSelfTest)"
            }
            return nil
            }
        },

        Case(name: "About ghi phiên bản mermaid (NFR-MMD-02)") { controller in
            _ = controller
            // Chỉ tiêu đòi "phiên bản pin VÀ ghi trong About". Vế pin đã có bài kiểm riêng;
            // bài này giữ vế thứ hai, vốn thiếu tới 28/08/2026.
            let credits = AppDelegate.aboutCredits
            guard let version = MermaidAsset.manifest?.version, !version.isEmpty else {
                return "không đọc được bản kê mermaid nên không kiểm được vế About"
            }
            guard credits.contains(version) else {
                return "About không nhắc phiên bản mermaid «\(version)»: «\(credits)»"
            }
            // Và nó không được NUỐT phần chẩn đoán cũ — dòng ấy là thứ đầu tiên cần biết khi
            // đọc một báo lỗi.
            guard credits.contains(GEditorCore.diagnosticSummary) else {
                return "About mất phần chẩn đoán: «\(credits)»"
            }
            return nil
        },

        Case(name: "gấp khối C: dấu ngoặc trong chuỗi và chú thích KHÔNG tính") { controller in
            // Đây là lý do gấp đi qua cây cú pháp chứ không đếm byte: ba dấu ngoặc ở dòng thứ
            // hai không mở hay đóng khối nào, và bộ đếm byte sẽ lệch từ đó tới hết file.
            let source = """
                int main(void) {
                  printf("dùng { để mở khối");   // và } để đóng
                  return 0;
                }
                """
            controller.prepareSelfTestDocument(source)
            controller.setSyntaxLanguageForSelfTest(.c)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.toggleFold(nil)

            guard controller.foldedHeaderLinesForSelfTest == [0] else {
                return "gấp ra \(controller.foldedHeaderLinesForSelfTest), mong [0]"
            }
            // Dòng đầu GIỮ ký tự xuống dòng của nó — phần bị giấu là trọn các dòng thân.
            guard controller.visibleWindowTextForSelfTest == "int main(void) {\n" else {
                return "chữ hiện ra là «\(controller.visibleWindowTextForSelfTest)»"
            }
            controller.unfoldAll(nil)
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "file không có khối nào gấp được thì NÓI RA, không im lặng") { controller in
            // Dọn trước: một bài kiểm phía trên thoát sớm vì lỗi sẽ để lại vùng gấp, và bài này
            // sẽ lặng lẽ đi vào nhánh "mở khối đang gấp" thay vì nhánh đang muốn kiểm.
            controller.unfoldAll(nil)
            controller.prepareSelfTestDocument("int x = 1;\n")
            controller.setSyntaxLanguageForSelfTest(.c)
            controller.toggleFold(nil)
            guard controller.foldedHeaderLinesForSelfTest.isEmpty else {
                return "gấp được một file chỉ có một dòng khai báo"
            }
            let status = controller.bannerMessageForSelfTest
            guard status.contains("Không có khối nào gấp được") else {
                return "thông báo là «\(status)»"
            }
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        // MARK: - Truy vấn JSONPath (FR-FMT-504)

        Case(name: "JSONPath tìm đúng nút và bấm vào thì nhảy tới đúng byte") { controller in
            let source = """
                {
                  "cua_hang": {
                    "sach": [
                      { "ten": "Truyện Kiều", "gia": 120000 },
                      { "ten": "Số đỏ", "gia": 85000 }
                    ]
                  }
                }
                """
            controller.prepareSelfTestDocument(source)
            controller.openJSONPathForSelfTest()
            guard controller.jsonPathPanelVisibleForSelfTest else { return "panel không hiện" }

            controller.jsonPathPanel.typeQueryForSelfTest("$..ten")
            guard controller.jsonPathPanel.matchCountForSelfTest == 2 else {
                return "mong 2 kết quả, được \(controller.jsonPathPanel.matchCountForSelfTest) — "
                    + controller.jsonPathPanel.summaryForSelfTest
            }
            guard let second = controller.jsonPathPanel.matchForSelfTest(1) else {
                return "không lấy được kết quả thứ hai"
            }
            guard second.path == "$.cua_hang.sach[1].ten" else {
                return "đường dẫn sai: \(second.path)"
            }

            // Bấm vào kết quả phải BÔI SÁNG đúng giá trị, không chỉ đặt con nháy đâu đó gần đó.
            controller.jsonPathPanel.clickRowForSelfTest(1)
            let selected = controller.selectedTextForSelfTest
            guard selected == "\"Số đỏ\"" else {
                return "bấm kết quả nhưng vùng chọn là «\(selected)», mong «\"Số đỏ\"»"
            }
            controller.closeJSONPathForSelfTest()
            return nil
        },

        Case(name: "truy vấn sai KHÁC với không có gì khớp") { controller in
            controller.prepareSelfTestDocument(#"{"a": 1}"#)
            controller.openJSONPathForSelfTest()

            controller.jsonPathPanel.typeQueryForSelfTest("$.khong_co")
            let empty = controller.jsonPathPanel.summaryForSelfTest
            guard empty.contains("Không có gì khớp") else {
                return "không khớp mà báo «\(empty)»"
            }

            controller.jsonPathPanel.typeQueryForSelfTest("$.a[?(@.b = 1)]")
            let broken = controller.jsonPathPanel.summaryForSelfTest
            guard broken.contains("==") else {
                return "truy vấn sai mà báo «\(broken)» — phải nói ra chỗ sai"
            }
            guard controller.jsonPathPanel.matchCountForSelfTest == 0 else {
                return "truy vấn sai mà vẫn còn kết quả cũ trên danh sách"
            }
            controller.closeJSONPathForSelfTest()
            return nil
        },

        Case(name: "file không phải JSON thì nói ngay lúc mở panel") { controller in
            controller.prepareSelfTestDocument("day khong phai json\n")
            controller.openJSONPathForSelfTest()
            let message = controller.jsonPathPanel.summaryForSelfTest
            guard message.contains("Không phải JSON hợp lệ") else {
                return "mở panel trên file thường mà báo «\(message)»"
            }
            controller.closeJSONPathForSelfTest()
            return nil
        },

        Case(name: "xuất kết quả JSONPath ra TAB MỚI, không đụng file gốc") { controller in
            let source = #"{"gia": [120000, 85000, 95000]}"#
            controller.prepareSelfTestDocument(source)
            let before = controller.tabCountForSelfTest
            controller.openJSONPathForSelfTest()
            controller.jsonPathPanel.typeQueryForSelfTest("$.gia[?(@ > 90000)]")
            guard controller.jsonPathPanel.matchCountForSelfTest == 2 else {
                return "mong 2 kết quả, được \(controller.jsonPathPanel.matchCountForSelfTest)"
            }
            controller.jsonPathPanel.exportForSelfTest()
            guard controller.tabCountForSelfTest == before + 1 else {
                return "xuất mà không mở tab mới"
            }
            let exported = controller.documentTextForSelfTest
            guard exported.contains("120000"), exported.contains("95000"),
                  !exported.contains("85000") else {
                return "tab mới không chứa đúng tập khớp: \(exported)"
            }
            controller.closeCurrentTabForSelfTest()
            guard controller.documentTextForSelfTest == source else {
                return "file gốc bị đụng vào sau khi xuất"
            }
            controller.closeJSONPathForSelfTest()
            return nil
        },

        Case(name: "đổi tài liệu thì truy vấn chạy trên tài liệu MỚI") { controller in
            // Bản nhớ chỉ mục từng chỉ so số revision. Revision đếm từ 0 trong từng buffer, nên
            // hai tài liệu vừa sửa một lần đều mang revision 1 — và truy vấn trả về kết quả của
            // file trước, trỏ vào những khoảng byte của một file đã đóng.
            controller.prepareSelfTestDocument(#"{"ten": "mot"}"#)
            controller.openJSONPathForSelfTest()
            controller.jsonPathPanel.typeQueryForSelfTest("$.ten")
            guard controller.jsonPathPanel.matchForSelfTest(0)?.preview == "mot" else {
                return "truy vấn đầu đã sai"
            }

            controller.prepareSelfTestDocument(#"{"ten": "hai"}"#)
            controller.jsonPathPanel.typeQueryForSelfTest("$.ten")
            let found = controller.jsonPathPanel.matchForSelfTest(0)?.preview ?? "(rỗng)"
            guard found == "hai" else {
                return "đổi tài liệu rồi mà truy vấn vẫn trả «\(found)» của tài liệu cũ"
            }
            controller.closeJSONPathForSelfTest()
            return nil
        },

        // MARK: - Dựng lười giao diện (ADR-08 §2.10)

        Case(name: "cửa sổ khởi động chỉ dựng ba tầng luôn hiện, không dựng panel nào") { _ in
            // Sáu panel còn lại nằm sẵn trong cây view từng tốn ~96 ms ở lần giải Auto Layout
            // đầu tiên — nhiều hơn cả phần tiết kiệm được khi tách grammar nặng ra dylib.
            // Bốn tầng, không phải ba: `docBar` (khung chung View/Code) là một hàng CỐ ĐỊNH
            // thêm vào 04/09/2026 theo yêu cầu người dùng — mọi loại tệp phải có cùng một chỗ
            // để đổi chế độ. Nó là một `NSSegmentedControl` cộng hai nhãn, không phải một panel
            // kéo theo cây view; chỉ tiêu khởi động đo lại sau khi thêm vẫn nằm trong dải nhiễu.
            let expected = ["tabBar", "docBar", "middle", "status"]
            guard StartupProbe.layersAtLaunch == expected else {
                return "lúc cửa sổ hiện ra đã dựng ["
                    + StartupProbe.layersAtLaunch.joined(separator: ", ")
                    + "] — chỉ được có [" + expected.joined(separator: ", ")
                    + "]. Có mã nào đó chạm vào một panel ở đường khởi động, và nó kéo cả cây "
                    + "con của panel ấy vào lần bố cục đầu tiên."
            }
            return nil
        },

        Case(name: "mở rồi đóng panel thì panel Ở LẠI, không dựng lại lần sau") { controller in
            // Gắn rồi gỡ theo từng lần bật/tắt là dời chi phí bố cục sang chỗ khó chịu hơn:
            // người dùng bật/tắt Tìm liên tục sẽ thấy khựng mỗi lần.
            controller.showFindPanel(nil)
            guard controller.attachedLayerNamesForSelfTest.contains("find") else {
                return "mở Tìm mà panel không vào cửa sổ"
            }
            controller.handleFindActionForSelfTest(.close)
            guard controller.attachedLayerNamesForSelfTest.contains("find") else {
                return "đóng Tìm xong panel bị gỡ khỏi cửa sổ — lần mở sau sẽ phải dựng lại"
            }
            return nil
        },

        // MARK: - Tô màu cú pháp (FR-FMT-501 · ADR-04)

        // Điều bài này canh: dựng cửa sổ và mở một tài liệu THƯỜNG không chạm tới dylib bảng
        // tra grammar (ADR-08 §2.13). Đó là cả lý do dylib ấy tồn tại — phiên chỉ mở `.txt`,
        // `.csv`, `.log` thì không trả một mili-giây nào cho 7 MB bảng tra.
        //
        // Hỏi ẢNH CHỤP lúc cửa sổ hiện ra, không hỏi trạng thái hiện thời. Từ khi cả hai mươi
        // ngôn ngữ chuyển vào dylib, bất kỳ bài kiểm nào chạy trước và mở một file có tô màu
        // cũng nạp nó — hỏi `isLoaded` giữa chừng là buộc bài này phụ thuộc thứ tự chạy, và
        // một bài kiểm đỏ vì thứ tự là một bài kiểm không nói gì về sản phẩm.
        //
        // Nó KHÔNG canh được chuyện app lỡ liên kết TĨNH vào dylib: khi ấy `handle` vẫn đi qua
        // `dlopen` và ảnh chụp vẫn `false`, y hệt. Phép kiểm ấy là `otool -L` trong
        // scripts/run-self-test.sh và scripts/build-universal.sh, không phải bài này.
        // MARK: - Truy vấn SQL trên bảng CSV (FR-CSV-407 · ADR-11)

        Case(name: "panel SQL chỉ vào cửa sổ khi người dùng mở nó") { controller in
            guard !controller.attachedLayerNamesForSelfTest.contains("sql") else {
                return "panel SQL đã nằm trong cửa sổ trước khi ai mở nó — ADR-08 §2.10"
            }
            controller.openSQLPanelForSelfTest()
            guard controller.sqlPanelVisibleForSelfTest else { return "mở mà không hiện ra" }
            return nil
        },

        Case(name: "truy vấn SQL chạy qua ĐÚNG đường của panel, ra đúng số") { controller in
            controller.prepareSelfTestDocument("""
                ma,thanh_pho,doanh_thu
                KH1,Hà Nội,100
                KH2,Đà Nẵng,200
                KH3,Hà Nội,300
                """)
            let grouped: CSVQueryEngine.Result
            do {
                grouped = try controller.runSQLForSelfTest(
                    "SELECT thanh_pho, COUNT(*), SUM(doanh_thu) FROM t GROUP BY thanh_pho"
                        + " ORDER BY SUM(doanh_thu) DESC")
            } catch {
                return "câu hợp lệ mà ném: \(error)"
            }
            // Tên cột của phép gộp KHÔNG còn là "COUNT(*)" như engine tự viết đặt — DuckDB
            // đặt "count_star()". Đây là thay đổi người dùng THẤY, và chỗ đúng để ghi nó là
            // đây: đổi kỳ vọng mà không nói gì thì lần sau không ai biết vì sao nó khác.
            // Muốn tên đẹp thì đặt AS, và menu cú pháp của panel nên gợi ý đúng như thế.
            guard grouped.titles == ["thanh_pho", "count_star()", "sum(doanh_thu)"] else {
                return "tiêu đề sai: \(grouped.titles)"
            }
            guard grouped.rows == [["Hà Nội", "2", "400"], ["Đà Nẵng", "1", "200"]] else {
                return "kết quả sai: \(grouped.rows)"
            }
            return nil
        },

        Case(name: "câu SQL sai cú pháp thì panel chỉ ĐÚNG CHỖ, không chỉ nói `sai`") { controller in
            controller.prepareSelfTestDocument("a,b\n1,2\n")
            controller.openSQLPanelForSelfTest()
            // Câu cũ ở đây là "SELECT a FROM t WHERE b" — với engine tự viết nó SAI, với DuckDB
            // nó ĐÚNG (cột số ép được sang boolean). Giữ nguyên thì bài kiểm đo một tiền đề đã
            // hết hiệu lực.
            //
            // Và câu thay thế đầu tiên ("SELECT a FROM t WHERE", cụt hẳn) cũng sai: DuckDB trả
            // "syntax error at END OF INPUT" — không có vị trí để chỉ, vì lỗi Ở CUỐI. Đòi một
            // mũi tên cho câu ấy là đòi một thứ không tồn tại. Câu dưới đây có lỗi ở GIỮA, nên
            // vị trí là thứ có thật và đáng đòi.
            controller.sqlPanel.typeQueryForSelfTest("SELECT COUNT( FROM t")
            let message = controller.sqlPanel.summaryForSelfTest
            guard message.hasPrefix("⚠") else { return "câu sai mà panel không báo: \(message)" }
            // DuckDB tự kèm vị trí trong thông điệp ("LINE 1: …" và một dấu mũ). Panel không
            // dựng mũi tên thứ hai nữa — hai mũi tên chỉ hai chỗ khác nhau tệ hơn không có.
            guard message.contains("LINE") || message.contains("^") else {
                return "báo lỗi mà không chỉ vị trí — người dùng phải tự dò: \(message)"
            }
            // Và câu phải bằng TIẾNG VIỆT (ADR-14 §3.2 khoản 1): đổi engine không được đổi
            // luôn thứ tiếng mà sản phẩm nói với người dùng.
            guard message.contains("sai cú pháp") else {
                return "thông báo chưa dịch: \(message)"
            }

            // Câu CỤT thì không có vị trí — và bản dịch phải nói đúng chuyện đó thay vì một
            // câu chung chung khiến người dùng đi soi lại phần họ đã gõ đúng.
            controller.sqlPanel.typeQueryForSelfTest("SELECT a FROM t WHERE")
            let cụt = controller.sqlPanel.summaryForSelfTest
            guard cụt.contains("bị cụt") else {
                return "câu cụt mà không nói là cụt: \(cụt)"
            }
            return nil
        },

        Case(name: "Pivot dựng câu SQL và ĐƯA VÀO ô truy vấn, không tự chạy (FR-QRY-003)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.prepareSelfTestDocument(
                "tinh,doanh_thu,ma_don\nHuế,100,A\nHà Nội,250,B\nHuế,300,C\n")
            controller.openSQLPanelForSelfTest()

            let sheet = controller.makePivotSheetForSelfTest()
            // Xem trước phải cập nhật theo TỪNG lần chọn: người ta học cấu trúc `GROUP BY` bằng
            // cách thấy nó mọc ra, không bằng cách đọc nó sau khi đã xong.
            sheet.addRowForSelfTest("tinh")
            guard sheet.previewForSelfTest.contains("GROUP BY \"tinh\"") else {
                return "xem trước không có GROUP BY: \(sheet.previewForSelfTest)"
            }
            sheet.addValueForSelfTest("doanh_thu", .sum)
            guard sheet.previewForSelfTest.contains("SUM(\"doanh_thu\")") else {
                return "xem trước không có SUM: \(sheet.previewForSelfTest)"
            }

            var applied = ""
            controller.sqlPanel.typeQueryWithoutRunningForSelfTest("")
            applied = sheet.applyForSelfTest()
            controller.applyPivotSQLForSelfTest(applied)

            // Đưa vào ô, KHÔNG chạy: câu phải nằm trong ô mà bảng kết quả vẫn trống.
            guard controller.sqlPanel.rowCountForSelfTest == 0 else {
                return "pivot đã TỰ CHẠY — người dùng mất cơ hội đọc và sửa câu trước"
            }

            // Và câu ấy phải CHẠY ĐƯỢC khi người dùng bấm Enter.
            controller.sqlPanel.typeQueryForSelfTest(applied)
            guard controller.waitForSQLResultForSelfTest() else {
                return "truy vấn không xong trong 5 giây"
            }
            guard controller.sqlPanel.rowCountForSelfTest == 2 else {
                return "pivot ra \(controller.sqlPanel.rowCountForSelfTest) hàng, mong 2 — "
                    + controller.sqlPanel.summaryForSelfTest
            }
            controller.closeSQLPanelForSelfTest()
            return nil
        },

        Case(name: "Danh mục bảng ảo: đăng ký, suy schema, và BÁO khi file đổi (FR-QRY-005)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.prepareSelfTestDocument("z\n1\n")
            let root = NSTemporaryDirectory() + "geditor-catalog-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let path = root + "/vung mien.csv"
            try? "tinh,mien\nHuế,Trung\nHà Nội,Bắc\n"
                .write(toFile: path, atomically: true, encoding: .utf8)

            guard controller.registerCatalogSource(path: path) else {
                return "không đăng ký được nguồn"
            }
            // Tên suy từ tên file, bỏ dấu và đổi dấu cách thành gạch dưới.
            guard controller.catalogTableNamesForSelfTest == ["vung_mien"] else {
                return "tên bảng sai: \(controller.catalogTableNamesForSelfTest)"
            }
            // Schema suy NGAY lúc đăng ký — danh mục không có schema là một danh sách đường dẫn.
            guard controller.queryCatalog.tables[0].columns.map(\.name) == ["tinh", "mien"] else {
                return "không suy được schema: \(controller.queryCatalog.tables[0].columns)"
            }
            guard controller.catalogStaleCountForSelfTest == 0 else {
                return "vừa đăng ký mà đã báo cũ"
            }

            // Sửa file GIỮ NGUYÊN độ dài — chỉ so cỡ file thì lọt.
            try? "tinh,mien\nHue,Trung\nHa Noi,Bac\n"
                .write(toFile: path, atomically: true, encoding: .utf8)
            guard controller.catalogStaleCountForSelfTest == 1 else {
                return "file đã đổi mà danh mục không nhận ra"
            }
            return nil
        },

        Case(name: "Biểu đồ: vẽ từ kết quả truy vấn, đổi loại, xuất PNG và SVG (FR-QRY-004)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.prepareSelfTestDocument(
                "tinh,doanh_thu\nHuế,100\nHà Nội,250\nĐà Nẵng,180\n")
            controller.openSQLPanelForSelfTest()
            controller.sqlPanel.typeQueryForSelfTest(
                "SELECT tinh, doanh_thu FROM t ORDER BY doanh_thu DESC")
            guard controller.waitForSQLResultForSelfTest() else {
                return "truy vấn không xong trong 5 giây"
            }
            guard controller.sqlPanel.isChartEnabledForSelfTest else {
                return "bảng có cột số mà nút Biểu đồ vẫn tắt"
            }
            controller.sqlPanel.tapChartForSelfTest()
            guard controller.chartPanelVisibleForSelfTest else { return "không mở được panel" }

            // Cho panel một kích thước THẬT rồi bố trí. Bài tự kiểm không có vòng hiển thị của
            // cửa sổ, nên không có bước này thì `bounds` bằng 0 và mọi phép xuất ảnh trả rỗng —
            // bài kiểm sẽ đo một view chưa bao giờ được đặt xuống đâu.
            controller.chartPanel.frame = NSRect(x: 0, y: 0, width: 520, height: 300)
            controller.chartPanel.layoutSubtreeIfNeeded()

            // Phải VẼ THẬT, không phải một khung trắng.
            let drawn = controller.chartPanel.chart.primitiveCountForSelfTest
            guard drawn > 5 else { return "chỉ vẽ \(drawn) hình — biểu đồ trống" }

            // SVG phải đọc được bằng bộ phân tích XML THẬT, và phải chứa nhãn tiếng Việt.
            let svg = controller.chartPanel.chart.svgForSelfTest
            guard (try? XMLDocument(xmlString: svg, options: [])) != nil else {
                return "SVG xuất ra không phải XML hợp lệ"
            }
            guard svg.contains("Huế") else { return "SVG mất nhãn tiếng Việt" }

            // PNG phải ra byte thật, không phải một tệp rỗng.
            let bytes = controller.chartPanel.chart.pngBytesForSelfTest()
            guard bytes > 1_000 else { return "PNG chỉ \(bytes) byte — gần như chắc là ảnh trống" }

            // Đổi loại thì hình vẽ phải ĐỔI. Không có phép so này thì menu chọn loại có thể
            // không nối vào gì cả mà bài kiểm vẫn xanh.
            controller.chartPanel.selectKindForSelfTest(.line)
            let asLine = controller.chartPanel.chart.svgForSelfTest
            guard asLine != svg else { return "đổi sang Đường mà hình vẽ không đổi" }
            guard asLine.contains("<polyline") else { return "biểu đồ Đường không có đường nào" }

            controller.chartPanel.selectKindForSelfTest(.histogram)
            guard controller.chartPanel.chart.svgForSelfTest != asLine else {
                return "đổi sang Phân bố mà hình vẽ không đổi"
            }
            controller.closeChartPanelForSelfTest()
            controller.closeSQLPanelForSelfTest()
            return nil
        },

        Case(name: "Biểu đồ: bảng TOÀN CHỮ thì nút tắt và nói ra (FR-QRY-004)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.prepareSelfTestDocument("ten,tinh\nAn,Huế\nBinh,Hà Nội\n")
            controller.openSQLPanelForSelfTest()
            controller.sqlPanel.typeQueryForSelfTest("SELECT ten, tinh FROM t")
            guard controller.waitForSQLResultForSelfTest() else {
                return "truy vấn không xong trong 5 giây"
            }
            // Một nút bấm vào rồi hiện lỗi là một nút đáng lẽ đã tắt.
            guard !controller.sqlPanel.isChartEnabledForSelfTest else {
                return "bảng toàn chữ mà nút Biểu đồ vẫn bật"
            }
            controller.closeSQLPanelForSelfTest()
            return nil
        },

        Case(name: "Bất thường: thanh trượt đổi kết quả NGAY, và tô màu theo mức (FR-MIN-001)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-min-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/doanh-thu.csv"

            // Cột `tinh` là CHỮ — nó phải không xuất hiện trong danh sách cột chọn được.
            //
            // Cột `doanh_thu` quanh 10…13, rồi cắm vào ba điểm được chọn để rơi vào ĐÚNG ba
            // mức nặng khác nhau. Với 18 giá trị này, trung vị = 12 và MAD = 1, nên thang là
            // 1,4826 và ở ngưỡng 3 thì điểm chia mức tại 3 (nhẹ), 4,5 (vừa) và 9 (nặng):
            //   17  → |17−12| / 1,4826 = 3,37  → 1,12× ngưỡng → NHẸ
            //   20  → |20−12| / 1,4826 = 5,40  → 1,80× ngưỡng → VỪA
            //   500 → 329                       → NẶNG
            // Bản đầu của bài kiểm này dùng 40 và 500, và cả hai đều ra NẶNG — bài kiểm trượt
            // đúng chỗ nó phải trượt, vì một màu duy nhất thì vế (b) không có nghĩa gì.
            var text = "tinh,doanh_thu\n"
            let base = [10, 12, 11, 13, 12, 11, 12, 10, 13, 11, 12, 10, 13, 11, 12]
            for (i, value) in base.enumerated() { text += "T\(i),\(value)\n" }
            text += "TX,17\n"
            text += "TY,20\n"
            text += "TZ,500\n"
            try? text.write(toFile: data, atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showAnomaliesForSelfTest()
            guard controller.anomalyPanelVisibleForSelfTest else {
                return "không mở được bảng bất thường"
            }

            // Cột chữ phải bị loại — hỏi DuckDB kiểu thật, không đoán từ nội dung.
            let offered = controller.anomalyColumnsForSelfTest
            guard offered == ["doanh_thu"] else {
                return "cột chọn được là \(offered), mong chỉ có doanh_thu"
            }

            // Phân bố lệch mạnh → khuyến nghị MAD (mục 2 trong danh sách), chọn sẵn.
            guard controller.anomalyPanel.selectedMethodIndexForSelfTest == 2 else {
                return "phân bố lệch mà không khuyến nghị MAD"
            }

            // Vế (c): kéo thanh trượt phải đổi số dòng khớp NGAY, không đọc lại dữ liệu.
            // Kiểm bằng cách hạ ngưỡng rồi nâng ngưỡng và xem con số đi đúng hướng.
            controller.anomalyPanel.setThresholdForSelfTest(1)
            let loose = controller.anomalyPanel.findingCountForSelfTest
            controller.anomalyPanel.setThresholdForSelfTest(6)
            let strict = controller.anomalyPanel.findingCountForSelfTest
            guard loose > strict else {
                return "ngưỡng 1 cho \(loose) dòng, ngưỡng 6 cho \(strict) — thanh trượt không "
                    + "ảnh hưởng gì tới kết quả"
            }
            guard strict >= 1 else { return "ngưỡng 6 mà không còn dòng nào — 500 phải sót lại" }
            guard controller.anomalyPanel.previewTextForSelfTest.contains("/") else {
                return "không hiện số dòng khớp: «\(controller.anomalyPanel.previewTextForSelfTest)»"
            }

            // ĐỐI CHỨNG cho "đọc đúng một lần": xoá file khỏi đĩa rồi kéo tiếp. Nếu panel âm
            // thầm đọc lại thì chỗ này hỏng; nếu nó dùng ảnh chụp thì vẫn chạy đúng.
            try? FileManager.default.removeItem(atPath: data)
            controller.anomalyPanel.setThresholdForSelfTest(3)
            guard controller.anomalyPanel.findingCountForSelfTest > 0 else {
                return "kéo thanh trượt sau khi file biến mất thì mất kết quả — tức là nó ĐANG "
                    + "đọc lại đĩa mỗi nhịp, và trên bảng lớn sẽ giật"
            }

            // Vế (b): tô màu KHÁC NHAU theo mức nặng.
            controller.markAllAnomaliesForSelfTest()
            let colours = Set(controller.markColorsForSelfTest())
            guard colours.count == 3 else {
                return "dùng \(colours.count) màu cho ba mức nặng khác nhau — mong đúng 3"
            }

            // Mọi dòng phải có câu giải thích nêu đúng con số (NFR-MIN-04).
            guard let report = controller.anomalyPanel.report else { return "không có kết quả" }
            for finding in report.findings where !finding.explanation.contains("MAD") {
                return "câu giải thích không nói ra phương pháp: «\(finding.explanation)»"
            }

            // Vế (d): xuất tab mới, kèm khối phương pháp thành chú thích.
            let before = controller.tabCountForSelfTest
            controller.exportAnomaliesForSelfTest()
            guard controller.tabCountForSelfTest == before + 1 else {
                return "không mở tab kết quả"
            }
            let exported = controller.editorDocument.buffer.text
            guard exported.hasPrefix("# Phương pháp:") else {
                return "tệp xuất ra không mở đầu bằng khối Phương pháp"
            }
            guard exported.contains("dong,gia_tri,diem,muc,vi_sao") else {
                return "thiếu dòng tiêu đề trong tệp xuất"
            }
            controller.hideAnomalyPanel()
            return nil
        },

        Case(name: "Báo cáo: preview dựng bảng + biểu đồ, một khối hỏng KHÔNG giết cả trang (FR-RPT-001/004)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-rpt-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))

            try? """
                tinh,thang,doanh_thu
                Hà Nội,2026-08,1500000
                Huế,2026-08,900000
                Đà Nẵng,2026-08,1200000
                Hà Nội,2026-07,1300000

                """.write(toFile: root + "/ban-hang.csv", atomically: true, encoding: .utf8)

            let reportPath = root + "/bao-cao.greport.md"
            try? """
                ---
                title: Doanh thu
                source: ban-hang.csv
                params:
                  thang: "2026-08"
                ---
                # Doanh thu tháng :thang

                ```query
                SELECT tinh, doanh_thu FROM t WHERE thang = :thang ORDER BY doanh_thu DESC
                ```

                ```chart
                kind: bar
                title: Theo tỉnh
                ```

                ```query
                SELECT cot_khong_ton_tai FROM t
                ```

                Kết.
                """.write(toFile: reportPath, atomically: true, encoding: .utf8)

            controller.open(path: reportPath, line: nil, column: nil, readOnly: false)
            guard controller.isReportDocument else {
                return "không nhận ra tài liệu .greport.md"
            }
            controller.toggleReportPreview(nil)
            guard controller.isReportPreviewVisible else { return "không mở được preview" }

            guard let rendered = controller.reportPreview.rendered else {
                return "preview không dựng được: «\(controller.reportPreview.headerTextForSelfTest)»"
            }

            // Hai khối lành chạy, khối hỏng KHÔNG giết cả trang.
            guard rendered.succeeded == 2 else {
                return "\(rendered.succeeded) khối chạy được, mong 2"
            }
            guard rendered.failures.count == 1 else {
                return "\(rendered.failures.count) khối hỏng, mong 1"
            }
            guard controller.reportPreview.headerTextForSelfTest.contains("HỎNG") else {
                return "thanh trạng thái không báo có khối hỏng"
            }

            let html = rendered.html
            // Bảng có số theo quy ước Việt, căn phải.
            guard html.contains("<td class=\"num\">1.500.000</td>") else {
                return "bảng không định dạng số kiểu Việt"
            }
            // Biểu đồ nhúng SVG TRONG DÒNG, không phải <img src>.
            guard html.contains("<svg"), !html.contains("<img") else {
                return "biểu đồ không nhúng SVG trong dòng"
            }
            // Tham số mặc định của frontmatter phải áp cho CẢ văn xuôi.
            guard html.contains("Doanh thu tháng 2026-08") else {
                return "tham số không thay trong văn xuôi"
            }
            // Và cả phần văn xuôi sau khối hỏng vẫn phải còn.
            guard html.contains("Kết.") else { return "mất phần văn xuôi sau khối hỏng" }
            // HTML tự chứa: không một yêu cầu mạng nào.
            for forbidden in ["<script", "src=\"http", "href=\"http"] {
                guard !html.contains(forbidden) else {
                    return "HTML còn tham chiếu ra ngoài: \(forbidden)"
                }
            }

            // Đổi tham số bằng tay rồi dựng lại → bảng đổi theo.
            controller.setReportParameterForSelfTest("thang", "2026-07")
            controller.refreshReportPreview()
            guard let second = controller.reportPreview.rendered else {
                return "dựng lại thất bại"
            }
            guard second.html.contains("1.300.000"), !second.html.contains("1.500.000") else {
                return "đổi tham số không đổi dữ liệu bảng"
            }

            // Tài liệu KHÔNG phải báo cáo thì không mở preview.
            controller.hideReportPreview()
            controller.resetTabsForSelfTest()
            let plain = root + "/thuong.txt"
            try? "chỉ là văn bản".write(toFile: plain, atomically: true, encoding: .utf8)
            controller.open(path: plain, line: nil, column: nil, readOnly: false)
            controller.toggleReportPreview(nil)
            guard !controller.isReportPreviewVisible else {
                return "mở preview cho một tài liệu không phải báo cáo"
            }
            return nil
        },

        Case(name: "Mermaid: vẽ nhiều loại sơ đồ, một sơ đồ HỎNG không giết sơ đồ khác (FR-MMD-001)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-mmd-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let path = root + "/so-do.md"
            // Ba khối: hai lành (hai LOẠI khác nhau) và một hỏng nằm GIỮA.
            try? """
                # Sơ đồ

                ```mermaid
                flowchart TD
                  A[Bắt đầu] --> B{Kiểm tra}
                  B -->|đúng| C[Xong]
                ```

                ```mermaid
                flowchart TD
                  A -->
                ```

                ```mermaid
                sequenceDiagram
                  Người dùng ->> App: mở tệp
                  App -->> Người dùng: nội dung
                ```
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.toggleMermaidStudioForSelfTest()
            guard controller.isMermaidPanelVisible else {
                return "không mở được Mermaid Studio: \(controller.bannerMessageForSelfTest)"
            }
            guard controller.waitForMermaidRenderForSelfTest(atLeast: 1) else {
                return "hết giờ chờ mermaid vẽ"
            }
            if let reason = controller.mermaidFailureReasonForSelfTest {
                return "bộ render không dựng được: \(reason)"
            }
            guard controller.mermaidPanel.diagramCountForSelfTest == 3 else {
                return "\(controller.mermaidPanel.diagramCountForSelfTest) sơ đồ, mong 3 — "
                    + controller.mermaidPanel.headerTextForSelfTest
            }
            // Một sơ đồ hỏng, HAI sơ đồ kia vẫn ra — đúng câu FR-MMD-001 đòi.
            guard controller.mermaidPanel.failureCountForSelfTest == 1 else {
                return "\(controller.mermaidPanel.failureCountForSelfTest) sơ đồ hỏng, mong 1"
            }
            let header = controller.mermaidPanel.headerTextForSelfTest
            guard header.contains("HỎNG"), header.contains("thứ 2") else {
                return "dòng trạng thái không chỉ ra sơ đồ thứ 2 hỏng: \(header)"
            }
            // Lỗi cú pháp phải nói ĐÚNG DÒNG (FR-MMD-001).
            guard controller.mermaidPanel.lastResults[1].line != nil else {
                return "sơ đồ hỏng mà không nói dòng nào"
            }

            // Bấm một node trên sơ đồ → con nháy nhảy tới đúng dòng định nghĩa (FR-MMD-002).
            controller.clickMermaidElementForSelfTest(diagram: 0, text: "Kiểm tra")
            let line = controller.caretLineForSelfTest()
            // Dòng 4 (0-based) là `  A[Bắt đầu] --> B{Kiểm tra}` — dòng ĐỊNH NGHĨA node.
            guard line == 4 else {
                return "bấm node «Kiểm tra» đưa con nháy tới dòng \(line), mong 4"
            }

            // Phiên bản mermaid mà TRANG báo về phải khớp bản kê đã vendor (NFR-MMD-02).
            if let reported = controller.mermaidVersionForSelfTest,
               let manifest = MermaidAsset.manifest, !reported.isEmpty {
                guard reported.hasPrefix(manifest.version) else {
                    return "trang chạy mermaid \(reported) mà bản kê ghi \(manifest.version)"
                }
            }
            controller.hideMermaidPanel()
            return nil
        },

        Case(name: "Mermaid: MỌI mẫu trong thư viện phải vẽ được thật (FR-MMD-005)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            guard MermaidAsset.isAvailable else { return MermaidAsset.failureReason }

            // Đây là bài kiểm đáng giá nhất của thư viện mẫu. Bài kiểm ở tầng lõi chỉ đọc được
            // "mẫu này khai đúng loại nó nói"; chỉ mermaid mới trả lời được "mẫu này VẼ ĐƯỢC".
            // Một mẫu sai cú pháp trông y hệt một mẫu đúng trong mã nguồn, và nó chỉ lộ ra khi
            // người dùng chèn xong rồi thấy hộp lỗi đỏ.
            let diagrams = MermaidLibrary.diagramTemplates
            var failures: [String] = []
            var done = false
            controller.mermaidRenderer.render(
                diagrams.enumerated().map { .init(index: $0.offset, source: $0.element.source) }
            ) { results in
                for result in results where result.isFailure {
                    let title = result.index < diagrams.count
                        ? diagrams[result.index].title : "?"
                    failures.append("«\(title)»: \(result.error ?? "?")")
                }
                done = true
            }
            guard controller.waitForSelfTestPublic("vẽ mẫu", seconds: 60, until: { done }) else {
                return "hết giờ chờ vẽ \(diagrams.count) mẫu"
            }
            guard failures.isEmpty else {
                return "\(failures.count)/\(diagrams.count) mẫu KHÔNG vẽ được — "
                    + failures.joined(separator: " · ")
            }

            // Mẩu cú pháp cũng phải vẽ được, nhưng chỉ khi ĐẶT VÀO một sơ đồ cùng loại — đó là
            // đúng cách người dùng dùng chúng.
            var fragmentFailures: [String] = []
            var fragmentsDone = false
            let fragments = MermaidLibrary.fragments
            let hosts: [String] = fragments.map { fragment in
                let host = MermaidLibrary.diagramTemplates.first { $0.kind == fragment.kind }
                return (host?.source ?? "") + "\n" + fragment.source
            }
            controller.mermaidRenderer.render(
                hosts.enumerated().map { .init(index: $0.offset, source: $0.element) }
            ) { results in
                for result in results where result.isFailure {
                    let title = result.index < fragments.count
                        ? fragments[result.index].title : "?"
                    fragmentFailures.append("«\(title)»: \(result.error ?? "?")")
                }
                fragmentsDone = true
            }
            guard controller.waitForSelfTestPublic(
                "vẽ mẩu", seconds: 60, until: { fragmentsDone }) else {
                return "hết giờ chờ vẽ \(fragments.count) mẩu cú pháp"
            }
            guard fragmentFailures.isEmpty else {
                return "\(fragmentFailures.count)/\(fragments.count) mẩu KHÔNG vẽ được — "
                    + fragmentFailures.joined(separator: " · ")
            }
            return nil
        },

        Case(name: "Mermaid: chèn mẫu một click, và gợi ý theo tên node đã khai (FR-MMD-005)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-mmd5-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let path = root + "/ghi-chu.md"
            try? "# Ghi chú\n\n".write(toFile: path, atomically: true, encoding: .utf8)
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.editorViewSetCaretToEndForSelfTest()

            // --- Chèn mẫu ----------------------------------------------------------------
            let sheet = controller.makeMermaidTemplateSheetForSelfTest()
            guard sheet.templateCountForSelfTest >= 11 else {
                return "thư viện chỉ có \(sheet.templateCountForSelfTest) mục"
            }
            guard sheet.insertForSelfTest(titled: "Lưu đồ quy trình duyệt") else {
                return "không tìm thấy mẫu lưu đồ trong thư viện"
            }
            let text = controller.documentTextForSelfTest
            // Mẫu ĐẦY ĐỦ chèn vào tệp Markdown phải tự bọc hàng rào — không có nó thì nó chỉ
            // là mấy dòng chữ, không phải một sơ đồ.
            guard text.contains("```mermaid") else {
                return "mẫu chèn vào .md mà không bọc hàng rào: \(text)"
            }
            guard MermaidDocument.blocks(in: text).count == 1 else {
                return "\(MermaidDocument.blocks(in: text).count) khối sau khi chèn, mong 1"
            }
            guard text.contains("Nhận hồ sơ") else { return "mẫu không có nhãn tiếng Việt" }
            // Một bước undo trả lại nguyên trạng.
            controller.undoDocument(nil)
            guard !controller.documentTextForSelfTest.contains("```mermaid") else {
                return "hoàn tác một bước không gỡ hết mẫu vừa chèn"
            }
            controller.redoDocument(nil)

            // --- Gợi ý -------------------------------------------------------------------
            // Con nháy đặt vào GIỮA sơ đồ, ngay sau một tiền tố của tên node đã khai.
            let full = controller.documentTextForSelfTest
            guard let insertion = full.range(of: "  A[Nhận hồ sơ] --> B{Đủ giấy tờ?}\n") else {
                return "không tìm thấy dòng đầu của mẫu vừa chèn"
            }
            // Con nháy tính theo BYTE, không theo ký tự: nhãn tiếng Việt có dấu nên hai con số
            // ấy lệch nhau, và đặt nhầm sẽ rơi vào giữa một ký tự nhiều byte.
            let offset = full.utf8.distance(from: full.utf8.startIndex,
                                            to: insertion.upperBound)
            controller.setCaretForSelfTest(documentOffset: offset)
            controller.typeForSelfTest("  Th")
            controller.refreshCompletionForSelfTest()
            let words = controller.completionWordsForSelfTest
            guard words.contains("Thẩm") || words.contains("ThamDinh") || !words.isEmpty else {
                return "không có gợi ý nào giữa sơ đồ"
            }
            // Gõ một tiền tố của TỪ KHOÁ mermaid: `sub` phải ra `subgraph`, thứ không có trong
            // tài liệu — nên nó chỉ đến từ danh sách từ khoá của FR-MMD-005.
            controller.typeForSelfTest("\n  sub")
            controller.refreshCompletionForSelfTest()
            guard controller.completionWordsForSelfTest.contains("subgraph") else {
                return "gõ «sub» giữa lưu đồ mà không gợi ý «subgraph»: "
                    + "\(controller.completionWordsForSelfTest)"
            }
            // Và KHÔNG gợi ý từ khoá của loại sơ đồ khác.
            guard !controller.completionWordsForSelfTest.contains("participant") else {
                return "gợi ý từ khoá của sequenceDiagram trong một lưu đồ"
            }
            return nil
        },

        Case(name: "Báo cáo: sinh loạt từ danh sách tham số, mỗi bộ một tệp (FR-RPT-006)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-rpt6-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            try? """
                tinh,doanh_thu
                Hà Nội,1500000
                Huế,900000
                Đà Nẵng,1200000

                """.write(toFile: root + "/ban-hang.csv", atomically: true, encoding: .utf8)
            // Danh sách BA tỉnh, trong đó một tỉnh KHÔNG có dữ liệu — bảng của nó rỗng nhưng
            // tệp vẫn phải ra, và cả loạt không được dừng vì nó.
            try? "tinh\nHuế\nHà Nội\nCà Mau\n"
                .write(toFile: root + "/tinh.csv", atomically: true, encoding: .utf8)

            let reportPath = root + "/thang.greport.md"
            try? """
                ---
                title: Doanh thu :tinh
                source: ban-hang.csv
                params:
                  - name: tinh
                ---
                # Doanh thu :tinh

                ```query
                SELECT tinh, doanh_thu FROM t WHERE tinh = :tinh
                ```

                ```mermaid
                flowchart LR
                  A[Thu] --> B[Chi]
                ```
                """.write(toFile: reportPath, atomically: true, encoding: .utf8)

            controller.open(path: reportPath, line: nil, column: nil, readOnly: false)
            let outFolder = URL(fileURLWithPath: root + "/bc")
            if let refusal = controller.runReportBatchForSelfTest(
                listPath: root + "/tinh.csv", folder: outFolder) {
                return refusal
            }
            guard controller.waitForSelfTestPublic("sinh loạt", seconds: 60, until: {
                controller.lastReportBatch != nil
            }) else { return "hết giờ chờ sinh loạt" }
            guard let outcome = controller.lastReportBatch else { return "không có kết quả" }
            guard outcome.entries.count == 3 else {
                return "\(outcome.entries.count) dòng tổng kết, mong 3"
            }
            guard outcome.failedCount == 0 else {
                return "có \(outcome.failedCount) bộ hỏng: \(outcome.report)"
            }

            // Mỗi bộ MỘT tệp, tên mang giá trị tham số — dấu cách thành `_`, dấu tiếng Việt giữ.
            let files = (try? FileManager.default
                .contentsOfDirectory(atPath: outFolder.path))?.sorted() ?? []
            guard files.count == 3 else { return "\(files.count) tệp, mong 3: \(files)" }
            guard files.contains("thang-Hà_Nội.html") else {
                return "tên tệp không mang giá trị tham số: \(files)"
            }
            // Nội dung PHẢI khác nhau giữa hai tỉnh — nếu giống nhau thì tham số không được áp.
            let hue = (try? String(
                contentsOfFile: outFolder.appendingPathComponent("thang-Huế.html").path,
                encoding: .utf8)) ?? ""
            let hanoi = (try? String(
                contentsOfFile: outFolder.appendingPathComponent("thang-Hà_Nội.html").path,
                encoding: .utf8)) ?? ""
            guard hue.contains("900.000"), !hue.contains("1.500.000") else {
                return "báo cáo Huế có số liệu của tỉnh khác"
            }
            guard hanoi.contains("1.500.000") else { return "báo cáo Hà Nội thiếu số liệu" }
            guard hue.contains("Doanh thu Huế") else { return "tham số không thay trong văn xuôi" }
            // Sơ đồ mermaid phải được VẼ và điền vào — bản xuất từ UI bằng chất lượng bản đơn.
            guard hue.contains("<svg") else { return "báo cáo không có sơ đồ đã vẽ" }
            guard !hue.contains(ReportRenderer.mermaidMarker(1)) else {
                return "chỗ trống sơ đồ chưa được điền"
            }

            // Bảng tổng kết ra TAB MỚI, có đủ ba dòng và dòng cộng.
            guard controller.documentTextForSelfTest.contains("Cà Mau"),
                  controller.documentTextForSelfTest.contains("3 bộ tham số") else {
                return "bảng tổng kết thiếu: \(controller.documentTextForSelfTest)"
            }
            return nil
        },

        Case(name: "Mermaid: chọn văn bản thì phần tử tương ứng SÁNG trên sơ đồ (FR-MMD-002)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            guard MermaidAsset.isAvailable else { return MermaidAsset.failureReason }

            let root = NSTemporaryDirectory() + "geditor-mmd2-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let path = root + "/so-do.mmd"
            try? """
                flowchart TD
                  A[Nhận hồ sơ] --> B{Đủ giấy tờ?}
                  B -->|Đủ| C[Thẩm định]
                """.write(toFile: path, atomically: true, encoding: .utf8)
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.toggleMermaidStudioForSelfTest()
            guard controller.isMermaidPanelVisible else { return "không mở được Mermaid Studio" }
            guard controller.waitForMermaidRenderForSelfTest(atLeast: 1) else {
                return "hết giờ chờ vẽ"
            }

            // Con nháy vào dòng 1 (`A[Nhận hồ sơ] --> B{...}`) → NHÃN của hai node phải được
            // gửi sang trang vẽ, và nhãn đứng TRƯỚC định danh.
            let text = controller.documentTextForSelfTest
            guard let line1 = text.range(of: "  A[Nhận hồ sơ]") else {
                return "không tìm thấy dòng cần đặt con nháy"
            }
            controller.setCaretForSelfTest(
                documentOffset: text.utf8.distance(
                    from: text.utf8.startIndex, to: line1.upperBound))
            let focus = controller.mermaidFocusForSelfTest
            guard focus.first == "Nhận hồ sơ" || focus.first == "Đủ giấy tờ?" else {
                return "không gửi nhãn nào, hoặc gửi sai thứ tự: \(focus)"
            }
            guard focus.contains("Nhận hồ sơ"), focus.contains("Đủ giấy tờ?") else {
                return "thiếu nhãn của một trong hai node: \(focus)"
            }

            // Và trang vẽ phải THẬT SỰ tô sáng đúng một phần tử cho mỗi nhãn — kiểm bằng cách
            // đếm phần tử mang lớp `gm-hit` trong DOM, không tin lời gọi là đủ.
            guard let hits = controller.waitForMermaidHitsForSelfTest(expected: 2) else {
                return "trang vẽ không tô sáng đúng 2 phần tử"
            }
            guard hits == 2 else { return "tô sáng \(hits) phần tử, mong 2" }

            // Con nháy ra khỏi mọi sơ đồ (dòng khai báo) thì XOÁ tô sáng: một viền cam đứng mãi
            // trên một node người dùng đã rời đi là một chỉ dẫn nói sai.
            controller.setCaretForSelfTest(documentOffset: 0)
            guard controller.mermaidFocusForSelfTest.contains("flowchart") == false else {
                return "gửi cả từ khoá của dòng khai báo: \(controller.mermaidFocusForSelfTest)"
            }
            controller.hideMermaidPanel()
            return nil
        },

        Case(name: "Mermaid: xuất PNG 1x/2x/3x, chép ảnh, nền trong suốt (FR-MMD-007)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            guard MermaidAsset.isAvailable else { return MermaidAsset.failureReason }

            let root = NSTemporaryDirectory() + "geditor-mmd7-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let path = root + "/so-do.mmd"
            try? "flowchart TD\n  A[Bắt đầu] --> B[Xong]\n"
                .write(toFile: path, atomically: true, encoding: .utf8)
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.toggleMermaidStudioForSelfTest()
            guard controller.isMermaidPanelVisible else { return "không mở được Mermaid Studio" }
            guard controller.waitForSelfTestPublic("vẽ để xuất", seconds: 30, until: {
                controller.mermaidPanel.lastSVGForSelfTest != nil
            }) else { return "hết giờ chờ vẽ" }
            guard let svg = controller.mermaidPanel.lastSVGForSelfTest else {
                return "không có SVG nào"
            }

            // Bốn đường xuất đặc tả kê tên đều phải có mặt trong menu.
            let titles = controller.mermaidPanel.exportMenuTitlesForSelfTest.joined(separator: "|")
            for needed in ["1x", "2x", "3x", "SVG", "clipboard"] {
                guard titles.contains(needed) else {
                    return "menu Xuất thiếu «\(needed)»: \(titles)"
                }
            }

            // --- PNG ba tỷ lệ là ba cỡ THẬT của cùng một hình ------------------------------
            guard let size = MermaidSVG.size(of: svg) else { return "SVG không có viewBox" }
            var pixelWidths: [Int] = []
            for scale in MermaidExport.Scale.allCases {
                guard let data = MermaidExport.png(
                    from: svg, scale: scale, background: .white) else {
                    // macOS 12 không dựng được ảnh từ SVG — nói ra và bỏ qua phần này, chứ
                    // không đỏ vì một lý do không liên quan tới sản phẩm.
                    return nil
                }
                guard let image = NSImage(data: data),
                      let rep = image.representations.first else {
                    return "PNG \(scale.label) không đọc lại được"
                }
                pixelWidths.append(rep.pixelsWide)
                guard data.count > 100 else { return "PNG \(scale.label) rỗng" }
            }
            guard pixelWidths.count == 3 else { return "thiếu tỷ lệ" }
            guard pixelWidths[0] == size.pixels(scale: 1).width,
                  pixelWidths[1] == size.pixels(scale: 2).width,
                  pixelWidths[2] == size.pixels(scale: 3).width else {
                return "cỡ điểm ảnh sai: \(pixelWidths) trên viewBox \(size.width)"
            }
            guard pixelWidths[2] > pixelWidths[1], pixelWidths[1] > pixelWidths[0] else {
                return "3x không lớn hơn 2x lớn hơn 1x: \(pixelWidths)"
            }

            // --- Nền trong suốt là MẶC ĐỊNH của mermaid, nền đục mới là thứ phải thêm -------
            guard let opaque = MermaidExport.png(from: svg, scale: .oneX, background: .white),
                  let clear = MermaidExport.png(from: svg, scale: .oneX, background: nil) else {
                return "không dựng được hai bản nền"
            }
            guard let opaqueRep = NSBitmapImageRep(data: opaque),
                  let clearRep = NSBitmapImageRep(data: clear) else {
                return "không đọc lại được PNG"
            }
            // Điểm ảnh góc trên bên trái: bản đục phải ĐỤC, bản trong phải TRONG.
            let opaqueCorner = opaqueRep.colorAt(x: 0, y: 0)?.alphaComponent ?? 0
            let clearCorner = clearRep.colorAt(x: 0, y: 0)?.alphaComponent ?? 1
            guard opaqueCorner > 0.99 else { return "nền đục mà góc vẫn trong suốt" }
            guard clearCorner < 0.01 else { return "nền trong suốt mà góc vẫn đục" }

            // --- Chép ảnh vào clipboard ----------------------------------------------------
            guard MermaidExport.copyToPasteboard(png: opaque) else {
                return "không chép được ảnh vào clipboard"
            }
            guard NSPasteboard.general.data(forType: .png) != nil else {
                return "clipboard không có kiểu PNG"
            }
            // KHÔNG được kèm chuỗi SVG: nhiều ứng dụng ưu tiên kiểu VĂN BẢN khi có cả hai, và
            // người dùng bấm "chép ảnh" rồi dán ra một đống mã XML.
            if let text = NSPasteboard.general.string(forType: .string) {
                guard !text.contains("<svg") else { return "clipboard kèm cả mã SVG" }
            }

            // --- Tệp SVG xuất ra phải có cỡ THẬT -------------------------------------------
            let file = MermaidExport.svgFile(from: svg, background: .white)
            guard MermaidSVG.attribute("width", in: file) != "100%" else {
                return "tệp SVG vẫn để width=100%"
            }
            guard file.contains("<rect x=\"0\" y=\"0\"") else {
                return "tệp SVG nền đục mà không có hình nền"
            }
            controller.hideMermaidPanel()
            return nil
        },

        Case(name: "Mermaid: màu thương hiệu lưu ra tệp và chèn được vào tài liệu (FR-MMD-007)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            let root = NSTemporaryDirectory() + "geditor-mmd7b-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let path = root + "/ghi-chu.md"
            try? """
                # Ghi chú

                ```mermaid
                flowchart TD
                  A --> B
                ```
                """.write(toFile: path, atomically: true, encoding: .utf8)
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            var brand = MermaidBrand()
            brand.primaryColor = "#ff8800"
            controller.insertMermaidInitDirectiveForSelfTest(brand)
            let text = controller.documentTextForSelfTest
            guard text.contains("%%{init:"), text.contains("#ff8800") else {
                return "không chèn được chỉ thị: \(text)"
            }
            // Chỉ thị phải nằm TRONG khối, ngay trước dòng khai báo — đặt ngoài hàng rào thì nó
            // chỉ là một dòng chữ trong Markdown.
            let blocks = MermaidDocument.blocks(in: text)
            guard blocks.count == 1, blocks[0].source.hasPrefix("%%{init:") else {
                return "chỉ thị không nằm trong khối: \(blocks.map(\.source))"
            }
            // Và khối vẫn phân tích ra đúng loại sơ đồ.
            guard blocks[0].kind == .flowchart else {
                return "chèn chỉ thị xong thì mất loại sơ đồ: \(blocks[0].kind)"
            }
            // Chèn lần hai KHÔNG được chồng lên: hai chỉ thị trong một sơ đồ là tổ hợp mermaid
            // xử lý theo cách không ai đoán được.
            controller.insertMermaidInitDirectiveForSelfTest(brand)
            let again = controller.documentTextForSelfTest
            guard again.components(separatedBy: "%%{init:").count - 1 == 1 else {
                return "chèn chồng chỉ thị lần hai"
            }
            guard controller.bannerMessageForSelfTest.contains("đã có sẵn") else {
                return "không nói ra vì sao không chèn: \(controller.bannerMessageForSelfTest)"
            }
            return nil
        },

        Case(name: "Mermaid: định dạng lại giữ chú thích, gạch dưới đúng dòng lỗi (FR-MMD-006)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-mmd6-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))

            // --- Grammar: tệp .mmd phải được nhận ra -------------------------------------
            let diagramPath = root + "/so-do.mmd"
            try? """
                flowchart TD
                        A[Bắt đầu] --> B{Kiểm tra}
                %%   chú thích   căn   bằng   dấu   cách
                B --> C[Xong]
                """.write(toFile: diagramPath, atomically: true, encoding: .utf8)
            controller.open(path: diagramPath, line: nil, column: nil, readOnly: false)
            guard controller.statusLanguageForSelfTest == "Mermaid" else {
                return "tệp .mmd không nhận ra grammar: \(controller.statusLanguageForSelfTest)"
            }

            // --- Định dạng lại ------------------------------------------------------------
            controller.formatMermaid(nil)
            let formatted = controller.documentTextForSelfTest
            guard formatted.contains("\n  A[Bắt đầu] --> B{Kiểm tra}") else {
                return "thụt lề chưa chuẩn hoá: \(formatted)"
            }
            // Chú thích giữ NGUYÊN VĂN — khoảng trắng bên trong không bị "dọn".
            guard formatted.contains("%%   chú thích   căn   bằng   dấu   cách") else {
                return "chú thích bị sửa: \(formatted)"
            }
            // MỘT bước undo trả lại nguyên trạng.
            controller.undoDocument(nil)
            guard controller.documentTextForSelfTest.contains("        A[Bắt đầu]") else {
                return "hoàn tác một bước không trả lại được bản cũ"
            }
            controller.redoDocument(nil)

            // --- Gạch dưới đúng dòng ------------------------------------------------------
            controller.resetTabsForSelfTest()
            let mdPath = root + "/ghi-chu.md"
            // Khối nằm SAU nhiều dòng văn xuôi: nếu mã quên quy số dòng của mermaid về số dòng
            // của TÀI LIỆU thì dấu lỗi rơi lên phần văn xuôi ở đầu tệp.
            try? """
                # Ghi chú

                Một
                Hai
                Ba

                ```mermaid
                flowchart TD
                  A -->
                ```
                """.write(toFile: mdPath, atomically: true, encoding: .utf8)
            controller.open(path: mdPath, line: nil, column: nil, readOnly: false)
            controller.toggleMermaidStudioForSelfTest()
            guard controller.isMermaidPanelVisible else { return "không mở được Mermaid Studio" }
            guard controller.waitForSelfTestPublic("gạch lỗi", seconds: 30, until: {
                !controller.problemRangesForSelfTest.isEmpty
            }) else {
                return "không gạch dòng nào dù sơ đồ sai cú pháp"
            }
            let ranges = controller.problemRangesForSelfTest
            guard ranges.count == 1 else { return "\(ranges.count) dòng bị gạch, mong 1" }
            let line = controller.documentLineForSelfTest(offset: ranges[0].lowerBound)
            // Dòng 8 (0-based) là `  A -->` — dòng thứ hai của khối bắt đầu ở dòng 6.
            guard line == 8 else { return "gạch dòng \(line), mong 8" }

            // Sửa xong thì dấu gạch phải BIẾN MẤT, không ở lại trên một dòng đã đúng.
            controller.setCaretForSelfTest(documentOffset: ranges[0].upperBound)
            controller.typeForSelfTest(" B")
            guard controller.waitForSelfTestPublic("xoá gạch", seconds: 30, until: {
                controller.problemRangesForSelfTest.isEmpty
            }) else {
                return "sửa xong mà dấu gạch còn nguyên"
            }
            controller.hideMermaidPanel()
            return nil
        },

        Case(name: "Mermaid trong báo cáo và trong xem trước Markdown (FR-MMD-003)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-mmd3-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            try? "tinh,doanh_thu\nHuế,900000\n"
                .write(toFile: root + "/ban-hang.csv", atomically: true, encoding: .utf8)

            // --- Báo cáo -----------------------------------------------------------------
            let reportPath = root + "/bao-cao.greport.md"
            try? """
                ---
                source: ban-hang.csv
                ---
                # Quy trình

                ```mermaid
                flowchart TD
                  A[Nhận] --> B[Duyệt]
                ```

                ```query
                SELECT tinh, doanh_thu FROM t
                ```
                """.write(toFile: reportPath, atomically: true, encoding: .utf8)

            controller.open(path: reportPath, line: nil, column: nil, readOnly: false)
            controller.toggleReportPreview(nil)
            guard let first = controller.reportPreview.rendered else {
                return "preview không dựng được"
            }
            // Lõi để lại chỗ trống; trang hiện NGAY, chưa chờ sơ đồ.
            guard first.mermaid.count == 1 else {
                return "\(first.mermaid.count) khối mermaid, mong 1"
            }
            guard first.html.contains(ReportRenderer.mermaidMarker(0)) else {
                return "trang đầu tiên không có chỗ trống cho sơ đồ"
            }
            // Rồi sơ đồ vẽ xong và được ĐIỀN vào.
            guard controller.waitForSelfTestPublic("mermaid trong báo cáo", seconds: 30, until: {
                controller.lastReportRender.map {
                    !$0.html.contains(ReportRenderer.mermaidMarker(0))
                } ?? false
            }) else {
                return "hết giờ chờ điền sơ đồ vào báo cáo: "
                    + (controller.mermaidFailureReasonForSelfTest ?? "không rõ")
            }
            let filled = controller.lastReportRender?.html ?? ""
            guard filled.contains("<svg") else { return "báo cáo không có SVG nào" }
            // Tự chứa: SVG nhúng TRONG DÒNG, không có script và không tham chiếu ra ngoài.
            for forbidden in ["<script", "src=\"http", "href=\"http"] {
                guard !filled.contains(forbidden) else {
                    return "HTML còn tham chiếu ra ngoài: \(forbidden)"
                }
            }
            controller.hideReportPreview()

            // --- Xem trước Markdown ------------------------------------------------------
            controller.resetTabsForSelfTest()
            let mdPath = root + "/ghi-chu.md"
            try? """
                # Ghi chú

                ```mermaid
                flowchart LR
                  X --> Y
                ```

                Cuối.
                """.write(toFile: mdPath, atomically: true, encoding: .utf8)
            controller.open(path: mdPath, line: nil, column: nil, readOnly: false)
            controller.showMarkdownPreview(nil)
            guard let preview = controller.markdownPreviewForSelfTest else {
                return "không mở được xem trước Markdown"
            }
            // Dấu mốc phải BIẾN MẤT sau khi ảnh được chèn vào — còn nó nghĩa là chưa chèn.
            guard controller.waitForSelfTestPublic("mermaid trong markdown", seconds: 30, until: {
                !preview.renderedTextForSelfTest.contains(MarkdownPreview.marker(0))
            }) else {
                return "hết giờ chờ chèn sơ đồ vào xem trước Markdown"
            }
            guard preview.renderedTextForSelfTest.contains("Cuối.") else {
                return "mất phần văn bản sau khối sơ đồ"
            }
            return nil
        },

        Case(name: "Báo cáo: khối ```quality và ```mining chạy trong preview (FR-DQR-003 · FR-MIN-007)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-rpt-dqr-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))

            var rows = ["tinh,doanh_thu"]
            for index in 0..<10 { rows.append("Huế,\(100 + index % 3)") }
            for index in 0..<10 { rows.append("Hà Nội,\(5000 + index % 3)") }
            rows.append("Huế,")           // một ô rỗng cho luật not_null
            try? (rows.joined(separator: "\n") + "\n")
                .write(toFile: root + "/ban-hang.csv", atomically: true, encoding: .utf8)
            try? """
                rules:
                  - col: doanh_thu
                    not_null: true

                """.write(toFile: root + "/.gquality.yaml", atomically: true, encoding: .utf8)

            let reportPath = root + "/bao-cao.greport.md"
            try? """
                ---
                source: ban-hang.csv
                ---
                # Chất lượng và khai phá

                ```quality
                rules_file: .gquality.yaml
                now: 2026-08-27
                ```

                ```mining
                group_by: tinh
                value: doanh_thu
                ```
                """.write(toFile: reportPath, atomically: true, encoding: .utf8)

            controller.open(path: reportPath, line: nil, column: nil, readOnly: false)
            controller.toggleReportPreview(nil)
            guard let rendered = controller.reportPreview.rendered else {
                return "preview không dựng được: «\(controller.reportPreview.headerTextForSelfTest)»"
            }
            // Cả hai khối phải CHẠY. Đây cũng là bài kiểm cho `basePath`: thiếu nó thì
            // `rules_file: .gquality.yaml` được tìm trong thư mục ĐANG ĐỨNG của tiến trình app,
            // một chỗ người dùng không biết là ở đâu.
            guard rendered.failures.isEmpty else {
                return "khối hỏng: \(rendered.failures.map(\.message).joined(separator: " | "))"
            }
            guard rendered.succeeded == 2 else {
                return "\(rendered.succeeded) khối chạy được, mong 2"
            }
            guard rendered.qualityScores.count == 1 else { return "không có điểm chất lượng" }
            let html = rendered.html
            guard html.contains("g-score-value") else { return "thiếu thẻ điểm" }
            // Công thức phải là CHỮ trên trang — báo cáo được in ra, không hover được.
            guard html.contains("Công thức chấm điểm") else { return "thiếu khối công thức" }
            // NFR-MIN-04: mọi đầu ra khai phá kèm khối Phương pháp.
            guard html.contains("Phương pháp") else { return "thiếu khối Phương pháp" }
            guard html.contains("Hà Nội"), html.contains("Huế") else {
                return "bảng xếp hạng nhóm không có nhóm nào"
            }
            controller.hideReportPreview()
            return nil
        },

        Case(name: "Luật kết hợp: sắp theo LIFT không theo confidence, và bấm luật TÔ giao dịch (FR-MIN-003)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-luat-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))

            // --- Dạng (a): mỗi dòng một giỏ ------------------------------------------------
            //
            // «túi» có trong MỌI giỏ. «bia» và «tã» đi cùng nhau ở 10 giỏ. Luật «bia → túi» có
            // confidence 100% — cao nhất có thể — mà lift đúng bằng 1, tức chẳng nói gì. Luật
            // «bia → tã» có lift rất cao. Bảng phải đưa luật thứ hai lên TRƯỚC.
            let basketFile = root + "/gio-hang.csv"
            var text = "ma,gio\n"
            for index in 0..<40 {
                var items = ["túi"]
                if index < 10 { items += ["bia", "tã"] }
                else { items.append("hàng\(index % 5)") }
                text += "G\(index),\"\(items.joined(separator: ";"))\"\n"
            }
            try? text.write(toFile: basketFile, atomically: true, encoding: .utf8)

            controller.open(path: basketFile, line: nil, column: nil, readOnly: false)
            controller.showAssociationForSelfTest()
            guard controller.associationPanelVisibleForSelfTest else {
                return "không mở được bảng luật kết hợp"
            }
            controller.associationPanel.selectColumnsForSelfTest(first: "gio", second: nil)
            // Dữ liệu dùng dấu «;» vì ô CSV đã dùng dấu phẩy — đây chính là lý do đặc tả đòi
            // "delimiter CHỌN ĐƯỢC". Bản đầu của bài kiểm quên đổi, và mỗi giỏ thành MỘT item
            // duy nhất «túi;bia;tã»: không cặp nào, không luật nào, bảng rỗng.
            controller.associationPanel.setDelimiterForSelfTest(";")
            controller.associationPanel.setThresholdsForSelfTest(
                support: 20, confidence: 50)

            guard let result = controller.associationPanel.result else {
                return "không có kết quả luật"
            }
            guard result.transactionCount == 40 else {
                return "đọc ra \(result.transactionCount) giao dịch, mong 40"
            }

            guard let biaToTa = result.rules.firstIndex(where: {
                $0.antecedent == ["bia"] && $0.consequent == ["tã"]
            }) else { return "không tìm ra luật «bia → tã»: \(result.rules.map(\.text))" }
            guard let biaToTui = result.rules.firstIndex(where: {
                $0.antecedent == ["bia"] && $0.consequent == ["túi"]
            }) else { return "không tìm ra luật «bia → túi»" }

            // Luật vô nghĩa có confidence CAO NHẤT nhưng phải nằm SAU.
            guard result.rules[biaToTui].confidence >= result.rules[biaToTa].confidence else {
                return "dữ liệu thử không dựng đúng: luật tầm thường phải có confidence cao nhất"
            }
            guard biaToTa < biaToTui else {
                return "bảng đang sắp theo confidence chứ không theo lift — luật lift ≈ 1 "
                    + "đứng ở vị trí \(biaToTui), luật lift cao ở \(biaToTa)"
            }
            // Và luật tầm thường phải mang câu cảnh báo.
            guard result.rules[biaToTui].caution.contains("KHÔNG liên quan") else {
                return "luật lift ≈ 1 không có cảnh báo: «\(result.rules[biaToTui].caution)»"
            }

            // Bấm luật «bia → tã» → tô đúng 10 giao dịch.
            let marksBefore = controller.markColorsForSelfTest().count
            controller.associationPanel.pickRuleForSelfTest(biaToTa)
            let marksAfter = controller.markColorsForSelfTest().count
            guard marksAfter - marksBefore == 10 else {
                return "bấm luật tô \(marksAfter - marksBefore) dòng, mong 10"
            }

            // Xuất tab mới.
            let before = controller.tabCountForSelfTest
            controller.exportAssociationForSelfTest()
            guard controller.tabCountForSelfTest == before + 1 else {
                return "không mở tab kết quả"
            }
            let exported = controller.editorDocument.buffer.text
            guard exported.contains("ve_trai,ve_phai,support,confidence,lift,leverage,so_giao_dich,canh_bao") else {
                return "thiếu dòng tiêu đề trong tệp xuất"
            }
            guard exported.contains("CÁCH ĐỌC") else {
                return "khối Phương pháp không nói cách đọc lift"
            }

            // --- Dạng (b): hai cột [mã giao dịch, item] ------------------------------------
            //
            // Cùng nội dung, khác bố cục. Một giao dịch trải trên NHIỀU hàng, nên phép tô phải
            // tô hết các hàng của giao dịch chứ không chỉ hàng đầu.
            let longFile = root + "/dang-long.csv"
            var longText = "ma_gd,item\n"
            for index in 0..<40 {
                longText += "T\(index),túi\n"
                if index < 10 {
                    longText += "T\(index),bia\n"
                    longText += "T\(index),tã\n"
                }
            }
            try? longText.write(toFile: longFile, atomically: true, encoding: .utf8)

            controller.open(path: longFile, line: nil, column: nil, readOnly: false)
            controller.showAssociationForSelfTest()
            controller.associationPanel.selectShapeForSelfTest(1)
            controller.associationPanel.selectColumnsForSelfTest(
                first: "ma_gd", second: "item")
            controller.associationPanel.setThresholdsForSelfTest(
                support: 20, confidence: 50)

            guard let longResult = controller.associationPanel.result else {
                return "dạng hai cột không cho kết quả"
            }
            guard longResult.transactionCount == 40 else {
                return "dạng hai cột gom ra \(longResult.transactionCount) giao dịch, mong 40"
            }
            guard let longIndex = longResult.rules.firstIndex(where: {
                $0.antecedent == ["bia"] && $0.consequent == ["tã"]
            }) else { return "dạng hai cột không tìm ra luật «bia → tã»" }

            // 10 giao dịch × 3 hàng mỗi giao dịch = 30 dòng phải được tô.
            let longBefore = controller.markColorsForSelfTest().count
            controller.associationPanel.pickRuleForSelfTest(longIndex)
            let longAfter = controller.markColorsForSelfTest().count
            guard longAfter - longBefore == 30 else {
                return "dạng hai cột tô \(longAfter - longBefore) dòng, mong 30 "
                    + "(10 giao dịch × 3 hàng)"
            }
            controller.hideAssociationPanel()
            return nil
        },

        Case(name: "Khai phá theo nhóm: mỗi nhóm một HÀNG RÀO RIÊNG, và drill TÔ ngược vào dữ liệu (FR-MIN-007)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-nhom-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/chi-nhanh.csv"

            // Hai chi nhánh có phân bố khác hẳn: A quanh 10, B quanh 100. Cắm vào A một giá trị
            // 20 — gấp đôi mức bình thường của A, rõ ràng bất thường TRONG A, nhưng nằm gọn
            // trong hàng rào GỘP (Q1 ≈ 10, Q3 ≈ 100 → hàng rào tới ±135).
            //
            // Đây đúng là "lỗi kinh điển" mà đặc tả gọi tên, dựng thành dữ liệu chạy được.
            var text = "chi_nhanh,doanh_thu,chi_phi\n"
            for index in 0..<14 {
                text += "A,\(10 + index % 3),\(5 + index % 2)\n"
            }
            for index in 0..<14 {
                text += "B,\(100 + index % 3),\(50 + index % 2)\n"
            }
            text += "A,20,6\n"      // hàng dữ liệu 28
            try? text.write(toFile: data, atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showGroupMiningForSelfTest()
            guard controller.groupMiningPanelVisibleForSelfTest else {
                return "không mở được bảng khai phá theo nhóm"
            }
            guard let report = controller.groupMiningPanel.report else {
                return "không có kết quả khai phá"
            }
            guard report.groups.count == 2 else {
                return "gom ra \(report.groups.count) nhóm, mong 2"
            }

            guard let groupA = report.groups.first(where: { $0.name == "A" }),
                  let groupB = report.groups.first(where: { $0.name == "B" }) else {
                return "thiếu nhóm A hoặc B"
            }

            // Hai hàng rào phải TÁCH HẲN nhau — bằng chứng nhìn được rằng hai nhóm đang được đo
            // bằng hai cây thước khác nhau.
            guard let fenceA = groupA.fence, let fenceB = groupB.fence else {
                return "thiếu hàng rào riêng của nhóm"
            }
            guard fenceA.high < fenceB.low else {
                return "hai hàng rào chồng nhau: A tới \(fenceA.high), B từ \(fenceB.low)"
            }

            // Và ngưỡng riêng phải BẮT ĐƯỢC giá trị 20 mà ngưỡng gộp bỏ sót.
            guard groupA.anomalies == 1 else {
                return "nhóm A tìm ra \(groupA.anomalies) bất thường, mong 1"
            }
            guard groupB.anomalies == 0 else {
                return "nhóm B có \(groupB.anomalies) bất thường giả"
            }

            // Bảng xếp hạng: A phải đứng đầu ở "nhiều bất thường nhất".
            guard controller.groupMiningPanel.shownNamesForSelfTest.first == "A" else {
                return "xếp hạng bất thường không đưa A lên đầu: "
                    + "\(controller.groupMiningPanel.shownNamesForSelfTest)"
            }
            // Đổi cách xếp hạng phải đổi thứ tự bảng, không chỉ đổi nhãn.
            controller.groupMiningPanel.selectRankingForSelfTest(2)
            guard controller.groupMiningPanel.shownNamesForSelfTest.count == 2 else {
                return "đổi cách xếp hạng làm mất nhóm"
            }
            controller.groupMiningPanel.selectRankingForSelfTest(0)

            // Drill = TÔ NGƯỢC vào dữ liệu gốc. Nhóm A có 15 hàng.
            let marksBefore = controller.markColorsForSelfTest().count
            controller.groupMiningPanel.drillForSelfTest(0)
            let marksAfter = controller.markColorsForSelfTest().count
            guard marksAfter - marksBefore == 15 else {
                return "drill tô \(marksAfter - marksBefore) dòng, mong 15"
            }

            // Xuất tab mới: ba bảng xếp hạng + cột hàng rào riêng.
            let before = controller.tabCountForSelfTest
            controller.exportGroupMiningForSelfTest()
            guard controller.tabCountForSelfTest == before + 1 else {
                return "không mở tab kết quả"
            }
            let exported = controller.editorDocument.buffer.text
            guard exported.contains("nhom,so_hang,bat_thuong,ty_le,hang_rao_thap,hang_rao_cao,mape,r,lech_r,ghi_chu") else {
                return "thiếu dòng tiêu đề trong tệp xuất"
            }
            guard exported.contains("Nhiều bất thường nhất") else {
                return "tệp xuất thiếu bảng xếp hạng"
            }
            guard exported.contains("hàng rào tính RIÊNG cho từng nhóm") else {
                return "khối Phương pháp không nói vì sao hàng rào phải riêng"
            }
            controller.hideGroupMiningPanel()
            return nil
        },

        Case(name: "Dự báo: có mùa vụ thì THẮNG baseline; bước nhảy ngẫu nhiên thì NÓI RA là thua (FR-MIN-004)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-dubao-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/doanh-thu-quy.csv"

            // Hai cột trong CÙNG một file, để bài kiểm so được hai kết luận trái ngược nhau:
            //   `mua_vu`  — xu hướng + chu kỳ 4, mô hình PHẢI thắng baseline.
            //   `ngau_nhien` — bước nhảy ngẫu nhiên, mô hình PHẢI thua.
            var seriesA: [Double] = []
            var seriesB: [Double] = [100]
            var generator = SeededGenerator(seed: 2_026)
            let pattern: [Double] = [10, 20, 5, 15]
            for index in 0..<40 {
                // Tách từng bước một, KHÔNG viết thành một biểu thức: trình biên dịch Swift
                // suy kiểu cho một biểu thức số học trộn `Int` và `Double` theo cấp số nhân
                // các khả năng, và trong một tệp lớn nó chạm trần thời gian rồi báo lỗi ở đúng
                // dòng này — một lỗi trông như lỗi của phép tính chứ không phải của kiểu.
                let trend = Double(index / 4) * 8
                let seasonal: Double = pattern[index % 4]
                seriesA.append(100 + trend + seasonal)
                if index > 0 {
                    let step: Double = (generator.nextUnit() - 0.5) * 30
                    seriesB.append(seriesB[index - 1] + step)
                }
            }
            var text = "ky,mua_vu,ngau_nhien\n"
            for index in 0..<40 {
                text += "Q\(index),\(seriesA[index]),\(ChartRender.number(seriesB[index]))\n"
            }
            try? text.write(toFile: data, atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showForecastForSelfTest()
            guard controller.forecastPanelVisibleForSelfTest else {
                return "không mở được bảng dự báo"
            }

            // Cột đầu (`ky` là chữ nên bị loại) → `mua_vu`. Mô hình phải THẮNG.
            guard let winning = controller.forecastPanel.comparison else {
                return "không có kết quả dự báo"
            }
            guard winning.period == 4 else {
                return "chu kỳ nhận ra là \(String(describing: winning.period)), mong 4"
            }
            guard winning.modelBeatsBaselines else {
                return "trên chuỗi có mùa vụ rõ mà mô hình vẫn thua: \(winning.verdict)"
            }
            guard !controller.forecastPanel.verdictIsWarningForSelfTest else {
                return "mô hình thắng mà kết luận vẫn tô màu cảnh báo"
            }

            // Bảng phải có đúng số kỳ, và biểu đồ phải có DẢI TIN CẬY.
            guard controller.forecastPanel.rowCountForSelfTest == 6 else {
                return "bảng có \(controller.forecastPanel.rowCountForSelfTest) kỳ, mong 6"
            }
            let svg = controller.forecastPanel.svgForSelfTest
            guard svg.contains("<polygon") else { return "biểu đồ thiếu dải tin cậy" }
            guard svg.contains("dự báo") else {
                return "biểu đồ thiếu vạch ranh giới quá khứ / tương lai"
            }

            // Đổi sang cột bước nhảy ngẫu nhiên — mô hình phải THUA và phải NÓI RA.
            //
            // Đặt chu kỳ BẰNG TAY thành 4. Không đặt thì ACF đúng đắn báo "không có mùa vụ" và
            // hệ thống lùi về naive — một hành xử trung thực, nhưng nó tránh mất tình huống mà
            // bài kiểm này cần dựng: Holt-Winters CHẠY THẬT rồi thua. Đây cũng chính là vế
            // "người dùng đặt chu kỳ bằng tay" của đặc tả, và bản đầu của panel thiếu nó — bài
            // kiểm này là chỗ phát hiện ra.
            controller.forecastPanel.setPeriodForSelfTest(4)
            controller.forecastPanel.onPickColumn?("ngau_nhien")
            guard let losing = controller.forecastPanel.comparison else {
                return "không dựng lại được dự báo cho cột thứ hai"
            }
            guard !losing.modelBeatsBaselines else {
                return "trên bước nhảy ngẫu nhiên mà mô hình lại thắng: \(losing.verdict)"
            }
            guard controller.forecastPanel.verdictTextForSelfTest.contains("THUA BASELINE") else {
                return "không nói thẳng là thua: «\(controller.forecastPanel.verdictTextForSelfTest)»"
            }
            // Và phải ĐỔI MÀU — mắt bắt được trước khi đọc.
            guard controller.forecastPanel.verdictIsWarningForSelfTest else {
                return "mô hình thua mà kết luận không đổi màu"
            }

            // Xuất tab mới: khối Phương pháp, sai số của CẢ baseline, và bảng giá trị.
            let before = controller.tabCountForSelfTest
            controller.exportForecastForSelfTest()
            guard controller.tabCountForSelfTest == before + 1 else {
                return "không mở tab kết quả"
            }
            let exported = controller.editorDocument.buffer.text
            guard exported.contains("ky,du_bao,thap_80,cao_80,thap_95,cao_95") else {
                return "thiếu dòng tiêu đề trong tệp xuất"
            }
            guard exported.contains("naive: MAE") || exported.contains("naive: MAE") else {
                return "tệp xuất không kèm sai số của baseline"
            }
            guard exported.contains("KHOẢNG TIN CẬY LÀ XẤP XỈ") else {
                return "tệp xuất không nói khoảng tin cậy là xấp xỉ"
            }
            guard exported.contains("không sắp lại") else {
                return "tệp xuất không nói rõ giả định về thứ tự hàng"
            }
            controller.hideForecastPanel()
            return nil
        },

        Case(name: "Phân cụm: elbow gợi ý k, tab mới có cluster_id, scatter TÔ MÀU theo cụm (FR-MIN-002)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-cum-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/khach.csv"

            // Ba đám tách bạch, mỗi đám 20 hàng. Cột `ten` là chữ nên phải bị loại.
            var text = "ten,x,y\n"
            for (index, centre) in [(0, 0), (10, 10), (0, 10)].enumerated() {
                for i in 0..<20 {
                    let x = Double(centre.0) + Double(i % 5) * 0.1
                    let y = Double(centre.1) + Double((i / 5) % 4) * 0.1
                    text += "K\(index)_\(i),\(x),\(y)\n"
                }
            }
            try? text.write(toFile: data, atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            guard let sheet = controller.makeClusterSheetForSelfTest() else {
                return "không dựng được sheet phân cụm"
            }

            // Đường cong WCSS phải được VẼ ngay trong sheet — đặc tả đòi thấy đường cong chứ
            // không chỉ thấy một con số.
            guard sheet.curvePointCountForSelfTest > 5 else {
                return "sheet không vẽ đường cong (\(sheet.curvePointCountForSelfTest) hình)"
            }
            // Và elbow phải gợi ý đúng k = 3 trên dữ liệu ba đám.
            guard sheet.kForSelfTest == "3" else {
                return "elbow gợi ý k = \(sheet.kForSelfTest), mong 3"
            }
            // Câu gợi ý phải NÓI RÕ đây là mẹo đọc đồ thị, không phải tiêu chí thống kê.
            guard sheet.suggestionForSelfTest.contains("mẹo đọc đồ thị") else {
                return "gợi ý không nói rõ giới hạn: «\(sheet.suggestionForSelfTest)»"
            }

            // Đổi sang DBSCAN thì đường cong đổi sang k-distance và eps được gợi ý.
            sheet.selectAlgorithmForSelfTest(1)
            guard sheet.suggestionForSelfTest.contains("k-distance") else {
                return "đổi sang DBSCAN không dựng đường k-distance"
            }
            guard let eps = Double(sheet.epsForSelfTest), eps > 0 else {
                return "eps gợi ý không dùng được: «\(sheet.epsForSelfTest)»"
            }
            sheet.selectAlgorithmForSelfTest(0)

            let before = controller.tabCountForSelfTest
            sheet.runForSelfTest()

            guard let result = controller.lastClusterResult else { return "không có kết quả" }
            guard result.clusters.count == 3 else {
                return "tìm ra \(result.clusters.count) cụm, mong 3"
            }
            guard result.clusters.map(\.size).sorted() == [20, 20, 20] else {
                return "kích thước cụm \(result.clusters.map(\.size).sorted())"
            }
            // NFR-MIN-02: seed phải nằm trong kết quả.
            guard result.methodology.contains("seed") else {
                return "khối Phương pháp không ghi seed"
            }
            guard let silhouette = result.silhouette, silhouette > 0.9 else {
                return "silhouette \(String(describing: result.silhouette)) trên ba đám tách bạch"
            }

            // Scatter phải TÔ MÀU theo cụm: ba cụm → ba màu chấm khác nhau trong SVG.
            guard controller.chartPanelVisibleForSelfTest else {
                return "không mở biểu đồ phân cụm"
            }
            let svg = controller.chartPanel.svgForSelfTest
            var fills = Set<String>()
            for match in svg.components(separatedBy: "<circle").dropFirst() {
                guard let range = match.range(of: "fill=\"") else { continue }
                let rest = match[range.upperBound...]
                if let end = rest.firstIndex(of: "\"") {
                    fills.insert(String(rest[..<end]))
                }
            }
            guard fills.count == 3 else {
                return "scatter dùng \(fills.count) màu chấm cho 3 cụm"
            }

            // Tab mới: khối Phương pháp, bảng tâm cụm, rồi cluster_id theo dòng.
            guard controller.tabCountForSelfTest == before + 1 else {
                return "không mở tab kết quả"
            }
            let exported = controller.editorDocument.buffer.text
            guard exported.contains("# --- Tâm cụm (thang gốc) ---") else {
                return "tệp xuất thiếu bảng tâm cụm"
            }
            guard exported.contains("dong,cluster_id") else {
                return "tệp xuất thiếu cột cluster_id"
            }
            // Tâm cụm phải ở THANG GỐC, không phải thang z-score.
            //
            // So bằng KHOẢNG chứ không bằng chuỗi: tâm là trung bình nên nó ra 10,20 chứ không
            // ra đúng "10". Phân biệt hai thang thì rõ ràng — thang gốc có toạ độ quanh 10, còn
            // z-score với ba cụm nằm gọn trong khoảng ±2.
            var centreCoordinates: [Double] = []
            for line in exported.split(separator: "\n") where line.hasPrefix("# ") {
                let fields = line.dropFirst(2).split(separator: ",", omittingEmptySubsequences: false)
                guard fields.count == 4, Int(fields[0]) != nil, Int(fields[1]) != nil else {
                    continue
                }
                centreCoordinates += fields.dropFirst(2).compactMap { Double($0) }
            }
            guard centreCoordinates.count == 6 else {
                return "đọc ra \(centreCoordinates.count) toạ độ tâm cụm, mong 6 (3 cụm × 2 cột)"
            }
            guard centreCoordinates.contains(where: { $0 > 9 }) else {
                return "tâm cụm không ở thang gốc — toạ độ lớn nhất là "
                    + "\(centreCoordinates.max() ?? 0), mong quanh 10"
            }
            controller.hideChartPanel()
            return nil
        },

        Case(name: "Tương quan: ma trận, đổi cách, và bấm ô ra scatter kèm R² (FR-MIN-005)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            let root = NSTemporaryDirectory() + "geditor-corr-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/ban-hang.csv"

            // `tinh` là CHỮ nên phải bị loại. Ba cột số dựng có chủ đích:
            //   gio  = 1…24
            //   khach = gio × 3 (tương quan Pearson đúng +1)
            //   loi  = khách giảm dần (tương quan âm mạnh)
            var text = "tinh,gio,khach,loi\n"
            for i in 1...24 {
                text += "T\(i),\(i),\(i * 3),\(100 - i * 2)\n"
            }
            try? text.write(toFile: data, atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showCorrelationForSelfTest()
            guard controller.correlationPanelVisibleForSelfTest else {
                return "không mở được bảng tương quan"
            }

            // Cột chữ bị loại: 3 cột số + 1 cột nhãn hàng = 4 cột bảng.
            guard controller.correlationPanel.columnCountForSelfTest == 4 else {
                return "bảng có \(controller.correlationPanel.columnCountForSelfTest) cột, mong 4"
            }

            guard let matrix = controller.correlationPanel.matrix else { return "không có ma trận" }
            guard matrix.columns == ["gio", "khach", "loi"] else {
                return "cột số nhận ra là \(matrix.columns)"
            }

            // gio ↔ khach là quan hệ tuyến tính hoàn hảo.
            guard let rPositive = matrix.value(1, 0), abs(rPositive - 1) < 1e-9 else {
                return "gio ↔ khach = \(String(describing: matrix.value(1, 0))), mong 1"
            }
            // gio ↔ loi là âm hoàn hảo.
            guard let rNegative = matrix.value(2, 0), abs(rNegative + 1) < 1e-9 else {
                return "gio ↔ loi = \(String(describing: matrix.value(2, 0))), mong −1"
            }

            // Hai ô ấy phải có MÀU KHÁC HẲN nhau — nếu thang màu không phân kỳ thì +1 và −1
            // trông giống nhau và cả heatmap vô dụng.
            let hexPositive = controller.correlationPanel.backgroundHexForSelfTest(row: 1, column: 0)
            let hexNegative = controller.correlationPanel.backgroundHexForSelfTest(row: 2, column: 0)
            guard hexPositive != hexNegative else {
                return "tương quan +1 và −1 cùng màu \(hexPositive ?? "?")"
            }

            // Câu chú thích nhân quả phải LUÔN hiện, không nằm trong tooltip.
            guard controller.correlationPanel.caveatTextForSelfTest.contains("nhân quả") else {
                return "không hiện câu «không hàm ý nhân quả»"
            }

            // Đổi sang Spearman chạy lại trên ảnh chụp — không đọc lại đĩa. Chứng minh bằng
            // cách xoá file trước khi đổi.
            try? FileManager.default.removeItem(atPath: data)
            controller.correlationPanel.selectMethodForSelfTest(1)
            guard let spearman = controller.correlationPanel.matrix else {
                return "đổi phương pháp sau khi xoá file thì mất ma trận — tức đang đọc lại đĩa"
            }
            guard spearman.method == .spearman else { return "không đổi sang Spearman" }
            guard let rho = spearman.value(1, 0), abs(rho - 1) < 1e-9 else {
                return "Spearman gio ↔ khach = \(String(describing: spearman.value(1, 0)))"
            }

            // Bấm một ô → biểu đồ phân tán, có đường hồi quy, tiêu đề mang R².
            controller.correlationPanel.pickPairForSelfTest(1, 0)
            guard controller.chartPanelVisibleForSelfTest else {
                return "bấm ô không mở biểu đồ"
            }
            let svg = controller.chartPanel.svgForSelfTest
            guard svg.contains("<line") else { return "biểu đồ phân tán thiếu đường hồi quy" }
            guard svg.contains("R²") else { return "tiêu đề không mang R²" }
            // Câu chú thích phải nằm TRONG hình, vì ảnh sẽ được dán vào báo cáo.
            guard svg.contains("nhân quả") else {
                return "ảnh xuất ra không mang câu «không hàm ý nhân quả»"
            }

            // Xuất tab mới, kèm khối phương pháp.
            let before = controller.tabCountForSelfTest
            controller.exportCorrelationForSelfTest()
            guard controller.tabCountForSelfTest == before + 1 else {
                return "không mở tab kết quả"
            }
            let exported = controller.editorDocument.buffer.text
            guard exported.contains("cot_1,cot_2,he_so,n,ghi_chu") else {
                return "thiếu dòng tiêu đề trong tệp xuất"
            }
            guard exported.contains("# ") && exported.contains("nhân quả") else {
                return "tệp xuất không mang khối Phương pháp kèm chú thích"
            }
            controller.hideCorrelationPanel()
            controller.hideChartPanel()
            return nil
        },

        Case(name: "Bảng chất lượng: chấm điểm, bấm luật thì TÔ đúng dòng (FR-DQR-001/002)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()

            // Tệp quy tắc nằm CẠNH dữ liệu (ADR-09), nên bài kiểm phải dựng cả hai trong một
            // thư mục tạm — không thế thì nó ghi `.gquality.yaml` vào thư mục thật của người
            // đang chạy máy.
            let root = NSTemporaryDirectory() + "geditor-dqr-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/bang.csv"
            // ma_don: KH03 lặp (hàng 3, 4). tinh: Sài Gòn ngoài danh sách (hàng 5).
            try? """
                ma_don,tinh
                KH01,Hà Nội
                KH02,Huế
                KH03,Đà Nẵng
                KH03,Hà Nội
                KH05,Sài Gòn

                """.write(toFile: data, atomically: true, encoding: .utf8)
            try? """
                uniqueness_key: [ma_don]
                rules:
                  - col: ma_don
                    unique: true
                  - col: tinh
                    in_set: [Hà Nội, Huế, Đà Nẵng]
                    severity: warn

                """.write(toFile: root + "/.gquality.yaml", atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showQualityReportForSelfTest()
            guard controller.qualityPanelVisibleForSelfTest else {
                return "không mở được bảng chất lượng"
            }
            guard controller.qualityPanel.ruleCountForSelfTest == 2 else {
                return "đọc ra \(controller.qualityPanel.ruleCountForSelfTest) luật, mong 2 — "
                    + controller.qualityPanel.summaryForSelfTest
            }
            guard controller.qualityPanel.summaryForSelfTest.contains("1 lỗi") else {
                return "tóm tắt sai: \(controller.qualityPanel.summaryForSelfTest)"
            }

            // Sáu chiều phải hiện ĐỦ, và chiều không chấm được phải thành chữ chứ không thành
            // ô trống — nếu nó trống thì người đọc hiểu là "không có vấn đề gì".
            let labels = controller.qualityPanel.dimensionLabelsForSelfTest
            guard labels.count == 6 else { return "hiện \(labels.count) chiều, mong 6" }
            guard labels.contains(where: { $0.contains("—") }) else {
                return "không chiều nào báo 'không chấm được' dù tệp chưa khai accuracy/freshness"
            }
            // NFR-DQR-03: công thức phải tra lại được, ở đây là qua tooltip.
            guard controller.qualityPanel.dimensionTooltipsForSelfTest
                .allSatisfy({ !$0.isEmpty }) else {
                return "có chiều không kèm công thức"
            }

            // Bấm luật `unique` → tô CẢ HAI dòng KH03 (dòng 4 và 5 của tài liệu, vì dòng 1 là
            // tiêu đề).
            let before = controller.markCountForSelfTest
            controller.qualityPanel.clickRuleForSelfTest(0)
            let marked = controller.markCountForSelfTest - before
            guard marked == 2 else {
                return "bấm luật unique mà tô \(marked) dòng, mong 2"
            }

            // Xuất vi phạm ra tab mới, không đụng file gốc.
            let tabs = controller.tabCountForSelfTest
            controller.exportViolationsForSelfTest()
            guard controller.tabCountForSelfTest == tabs + 1 else {
                return "xuất mà không sinh tab mới"
            }
            guard controller.documentTextForSelfTest.contains("muc,luat") else {
                return "tab xuất không có tiêu đề cột"
            }
            controller.closeQualityPanelForSelfTest()
            return nil
        },

        Case(name: "Bảng chất lượng: nút sửa mở đúng công cụ, sửa xong TỰ chấm lại (FR-DQR-006)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            let root = NSTemporaryDirectory() + "geditor-dqr6-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/bang.csv"
            // Hai dòng KH03 GIỐNG HỆT nhau (khử trùng lặp xoá được), và một tỉnh ngoài danh sách.
            try? """
                ma_don,tinh
                KH01,Hà Nội
                KH02,Huế
                KH03,Đà Nẵng
                KH03,Đà Nẵng
                KH05,Sài Gòn

                """.write(toFile: data, atomically: true, encoding: .utf8)
            try? """
                uniqueness_key: [ma_don]
                rules:
                  - col: ma_don
                    unique: true
                  - col: tinh
                    in_set: [Hà Nội, Huế, Đà Nẵng]
                  - col: ma_don
                    length: {min: 1}

                """.write(toFile: root + "/.gquality.yaml", atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showQualityReportForSelfTest()
            guard controller.qualityPanelVisibleForSelfTest else {
                return "không mở được bảng chất lượng"
            }

            // Nút chỉ có ở luật TRƯỢT, và chữ trên nút phải là công cụ ĐÚNG cho từng loại luật.
            let titles = controller.qualityPanel.fixButtonTitlesForSelfTest
            guard titles.count == 3 else { return "đọc ra \(titles.count) luật, mong 3" }
            guard titles[0] == "Khử trùng lặp…" else {
                return "luật unique mở nhầm công cụ: \(titles[0] ?? "không có nút")"
            }
            guard titles[1] == "Thay thế…" else {
                return "luật in_set mở nhầm công cụ: \(titles[1] ?? "không có nút")"
            }
            guard titles[2] == nil else {
                return "luật ĐẠT vẫn có nút sửa: \(titles[2] ?? "")"
            }

            // `in_set` → hộp Thay thế nạp sẵn GIÁ TRỊ đang sai, không nạp mẫu của luật.
            controller.qualityPanel.fixRuleForSelfTest(1)
            guard controller.findFieldTextForSelfTest == "Sài Gòn" else {
                return "ô Tìm không có giá trị sai: «\(controller.findFieldTextForSelfTest)»"
            }
            guard !controller.findFieldModeIsRegexForSelfTest else {
                return "một giá trị mà vẫn bật regex — dấu chấm trong dữ liệu sẽ khớp bừa"
            }

            // `unique` → khử trùng lặp, rồi TỰ chấm lại: điểm phải đổi mà không cần bấm gì thêm.
            let before = controller.qualityPanel.scoreTextForSelfTest
            controller.qualityPanel.fixRuleForSelfTest(0)
            guard controller.documentTextForSelfTest.components(separatedBy: "KH03").count - 1 == 1
            else { return "khử trùng lặp không xoá dòng KH03 lặp" }
            let after = controller.qualityPanel.scoreTextForSelfTest
            guard before != after else {
                return "sửa xong mà điểm KHÔNG tự cập nhật — vòng verify không khép: \(after)"
            }
            controller.closeQualityPanelForSelfTest()
            return nil
        },

        Case(name: "Bảng chất lượng: mỗi lượt chấm ghi một mốc, tab Xu hướng so được (FR-DQR-004)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            let root = NSTemporaryDirectory() + "geditor-dqr4-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/bang.csv"
            try? "ma_don,tinh\nKH01,Hà Nội\nKH02,Huế\n"
                .write(toFile: data, atomically: true, encoding: .utf8)
            try? """
                rules:
                  - col: tinh
                    in_set: [Hà Nội, Huế]

                """.write(toFile: root + "/.gquality.yaml", atomically: true, encoding: .utf8)

            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showQualityReportForSelfTest()
            let historyFile = root + "/.gquality.history.jsonl"
            guard FileManager.default.fileExists(atPath: historyFile) else {
                return "chấm xong mà không ghi mốc nào vào lịch sử"
            }
            // Lịch sử ghi CẠNH bộ luật, KHÔNG bao giờ ghi vào file dữ liệu (NFR-DQR-02).
            guard (try? String(contentsOfFile: data, encoding: .utf8))
                == "ma_don,tinh\nKH01,Hà Nội\nKH02,Huế\n" else {
                return "file dữ liệu bị đụng tới"
            }

            // Lượt chấm thứ hai trên dữ liệu XẤU HƠN — sửa ngay trong trình soạn, đúng đường
            // người dùng đi giữa hai lần chấm.
            controller.selectAllOccurrencesForSelfTest("Huế")
            controller.pasteForSelfTest("Sài Gòn")
            controller.showQualityReportForSelfTest()
            guard controller.qualityPanel.historyCountForSelfTest >= 2 else {
                return "chỉ có \(controller.qualityPanel.historyCountForSelfTest) mốc, mong ≥ 2"
            }

            controller.qualityPanel.selectModeForSelfTest(.trend)
            controller.qualityPanel.compareRowsForSelfTest([0, 1])
            let text = controller.qualityPanel.summaryForSelfTest
            guard text.contains("điểm") || text.contains("tụt") || text.contains("luật mới trượt")
            else { return "chọn hai mốc mà không so được: \(text)" }
            guard text.contains("luật mới trượt") else {
                return "không nói ra luật nào mới trượt: \(text)"
            }
            controller.qualityPanel.selectModeForSelfTest(.rules)
            controller.closeQualityPanelForSelfTest()
            return nil
        },

        Case(name: "Bảng chất lượng: chưa có tệp quy tắc thì NÓI ĐƯỜNG DẪN (FR-DQR-001)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            let root = NSTemporaryDirectory() + "geditor-dqr-thieu-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            Unattended.registerTemporaryRoot(URL(fileURLWithPath: root))
            let data = root + "/bang.csv"
            try? "a,b\n1,2\n".write(toFile: data, atomically: true, encoding: .utf8)
            controller.open(path: data, line: nil, column: nil, readOnly: false)
            controller.showQualityReportForSelfTest()
            // "Không tìm thấy tệp quy tắc" mà không nói tìm ở đâu thì người dùng không biết
            // đặt nó vào chỗ nào.
            guard controller.bannerMessageForSelfTest.contains(".gquality.yaml") else {
                return "không nói đường dẫn tệp quy tắc: \(controller.bannerMessageForSelfTest)"
            }
            return nil
        },

        Case(name: "Workbench: tham số :param hiện ô nhập và thay đúng giá trị (FR-QRY-001)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.prepareSelfTestDocument("ten,tinh\nAn,Huế\nBinh,Hà Nội\nChi,Huế\n")
            controller.openSQLPanelForSelfTest()

            // Câu KHÔNG có tham số: hàng ô nhập phải ẩn. Một hàng ô trống thường trực là một
            // hàng người dùng phải học cách bỏ qua.
            controller.sqlPanel.typeQueryWithoutRunningForSelfTest("SELECT * FROM t")
            guard !controller.sqlPanel.isParameterRowVisibleForSelfTest else {
                return "câu không có tham số mà vẫn hiện hàng ô nhập"
            }

            controller.sqlPanel.typeQueryWithoutRunningForSelfTest(
                "SELECT COUNT(*) FROM t WHERE tinh = :tinh")
            guard controller.sqlPanel.parameterNamesForSelfTest == ["tinh"] else {
                return "không dựng ô nhập cho :tinh — \(controller.sqlPanel.parameterNamesForSelfTest)"
            }

            // Chưa nhập giá trị thì phải NÓI RA, không lặng lẽ chạy với NULL: `WHERE tinh =
            // NULL` không trả hàng nào và người dùng sẽ đi tìm lỗi trong dữ liệu.
            controller.sqlPanel.typeQueryForSelfTest("SELECT COUNT(*) FROM t WHERE tinh = :tinh")
            guard controller.sqlPanel.summaryForSelfTest.contains("Chưa nhập giá trị") else {
                return "chạy với tham số rỗng mà không cảnh báo: "
                    + controller.sqlPanel.summaryForSelfTest
            }

            controller.sqlPanel.setParameterForSelfTest("tinh", "Huế")
            controller.sqlPanel.typeQueryForSelfTest("SELECT COUNT(*) FROM t WHERE tinh = :tinh")
            guard controller.waitForSQLResultForSelfTest() else {
                return "truy vấn không xong trong 5 giây"
            }
            guard controller.sqlPanel.rowCountForSelfTest == 1 else {
                return "chạy có tham số mà không ra kết quả: "
                    + controller.sqlPanel.summaryForSelfTest
            }
            controller.closeSQLPanelForSelfTest()
            return nil
        },

        Case(name: "Workbench: lịch sử giữ câu NGUYÊN BẢN còn :param (FR-QRY-001)") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.prepareSelfTestDocument("ten,tinh\nAn,Huế\n")
            controller.openSQLPanelForSelfTest()
            controller.sqlPanel.typeQueryWithoutRunningForSelfTest(
                "SELECT COUNT(*) FROM t WHERE tinh = :tinh")
            controller.sqlPanel.setParameterForSelfTest("tinh", "Huế")
            controller.sqlPanel.typeQueryForSelfTest("SELECT COUNT(*) FROM t WHERE tinh = :tinh")
            // Lịch sử chỉ được ghi SAU khi truy vấn xong, nên phải đợi. Bài này từng xanh mà
            // KHÔNG đợi — tức xanh do may, và đó là loại xanh tệ nhất.
            guard controller.waitForSQLResultForSelfTest() else {
                return "truy vấn không xong trong 5 giây"
            }

            // Lịch sử phải giữ `:tinh`, KHÔNG giữ `'Huế'` — bấm lại một câu đã thay giá trị thì
            // mất luôn tính tham số, và lịch sử thành hai chục bản sao chỉ khác con số.
            let history = controller.sqlPanel.historyTitlesForSelfTest
            guard history.contains(where: { $0.contains(":tinh") }) else {
                return "lịch sử không giữ tham số nguyên bản: \(history)"
            }
            guard !history.contains(where: { $0.contains("'Huế'") }) else {
                return "lịch sử lưu câu ĐÃ THAY giá trị: \(history)"
            }
            controller.closeSQLPanelForSelfTest()
            return nil
        },

        Case(name: "JOIN chạy được — thứ engine tự viết TỪ CHỐI (ADR-14)") { controller in
            // Bài này THAY bài "cú pháp SQL chưa làm thì gọi ĐÚNG TÊN nó" của ADR-11.
            //
            // Bài cũ vẫn XANH sau khi đổi engine, nhưng xanh vì lý do sai: thông điệp lỗi của
            // DuckDB tình cờ có chữ "JOIN" trong đó. Một bài kiểm xanh vì lý do sai nguy hiểm
            // hơn một bài đỏ — nó canh gác một lời hứa đã không còn tồn tại.
            controller.prepareSelfTestDocument("ten,tp\nAn,Huế\nBình,Hà Nội\n")
            controller.openSQLPanelForSelfTest()
            let result: CSVQueryEngine.Result
            do {
                result = try controller.runSQLForSelfTest("""
                    SELECT COUNT(*) FROM t JOIN (SELECT 'Huế' AS x) v ON t.tp = v.x
                    """)
            } catch {
                return "JOIN vẫn ném: \(error)"
            }
            guard result.rows == [["1"]] else { return "JOIN ra sai: \(result.rows)" }
            return nil
        },

        Case(name: "tên cột sai thì panel đưa DANH SÁCH cột có thật") { controller in
            controller.prepareSelfTestDocument("ma,thanh_pho\nKH1,Huế\n")
            controller.openSQLPanelForSelfTest()
            controller.sqlPanel.typeQueryForSelfTest("SELECT thanh_p FROM t")
            let message = controller.sqlPanel.summaryForSelfTest
            guard message.contains("thanh_pho"), message.contains("ma") else {
                return "không liệt kê cột có thật: \(message)"
            }
            return nil
        },

        Case(name: "xuất kết quả SQL ra tab mới, BỌC ô có dấu phẩy") { controller in
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument("ten,dia_chi\nAn,\"Lê Lợi, quận 1\"\n")
            let result: CSVQueryEngine.Result
            do {
                result = try controller.runSQLForSelfTest("SELECT ten, dia_chi FROM t")
            } catch {
                return "câu hợp lệ mà ném: \(error)"
            }
            let before = controller.tabCountForSelfTest
            controller.exportSQLForSelfTest(result)
            guard controller.tabCountForSelfTest == before + 1 else {
                return "xuất mà không sinh tab mới"
            }
            let text = controller.editorDocument.buffer.text
            // Ô có dấu phẩy phải được bọc lại, nếu không file xuất ra là một CSV hỏng mang
            // đúng hình dạng đúng.
            guard text.contains("\"Lê Lợi, quận 1\"") else {
                return "ô có dấu phẩy không được bọc: \(String(reflecting: text))"
            }
            return nil
        },

        Case(name: "bảng tra grammar chưa nạp lúc khởi động, chỉ nạp khi mở C++ (ADR-08)") { controller in
            guard !StartupProbe.grammarLibraryLoadedAtLaunch else {
                return """
                    libTreeSitterHeavy đã nạp ngay lúc cửa sổ hiện ra — có gì trên đường khởi \
                    động đang hỏi tới grammar, và mọi phiên đều trả tiền cho nó
                    """
            }

            controller.prepareSelfTestDocument("class Lop { public: int x; };\n")
            controller.setSyntaxLanguageForSelfTest(.cpp)
            guard controller.waitForHighlightingForSelfTest() else {
                return "mở C++ mà không có màu — \(GrammarLibrary.failureReason ?? "không rõ vì sao")"
            }
            guard GrammarLibrary.isLoaded else {
                return "có màu C++ mà dylib báo chưa nạp — con số chẩn đoán nói dối"
            }
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "khởi động không nạp dylib nặng nào, và bộ dò tự chứng minh nó dò được (ADR-14)") { _ in
            // Bất biến anh chốt 26/08/2026 khi đồng ý nhúng DuckDB: bundle được phép to ra,
            // khởi động thì không. Bài này gác vế ấy — và nó là cổng DUY NHẤT sẽ đỏ vào đúng
            // ngày ai đó nối DuckDB vào đường khởi động, vì con số mili-giây sẽ trôi dần trong
            // nhiễu máy chứ không nhảy một phát qua trần.
            guard LazyLoadAudit.passesAtLaunch else {
                return LazyLoadAudit.failureMessage()
            }

            // ĐỐI CHỨNG ÂM. Một bộ dò hỏng cũng trả về "không có gì" y hệt lúc mọi thứ đúng,
            // nên trước khi tin chữ ĐẠT ở trên, bắt bộ dò nhìn một danh sách CÓ thư viện nặng
            // và đòi nó phải nhận ra. Cùng luật với bộ đếm của `--soak`: gây một lỗi giả và
            // đòi bộ đếm nhích.
            let giả = LazyLoadAudit.bundled.map {
                "/Nhà/kho/Contents/Frameworks/\($0.imageMatch).dylib"
            }
            let bắtĐược = LazyLoadAudit.loadedBundled(in: giả)
            guard bắtĐược.count == LazyLoadAudit.bundled.count else {
                return "bộ dò nạp-lười bỏ sót \(LazyLoadAudit.bundled.count - bắtĐược.count)"
                    + "/\(LazyLoadAudit.bundled.count) thư viện trong danh sách dựng sẵn"
                    + " — chữ ĐẠT ở trên không nói lên điều gì"
            }
            // Và nó không được báo bừa: một danh sách sạch phải cho ra rỗng.
            guard LazyLoadAudit.loadedBundled(in: ["/usr/lib/libSystem.B.dylib"]).isEmpty else {
                return "bộ dò nạp-lười báo có thư viện nặng trong một danh sách không có gì"
            }

            // Vế A đo bằng NHÂN, nên nó phải thấy được thứ vừa nạp thật. Bài grammar ngay trên
            // đã mở một file C++, tức libTreeSitterHeavy giờ đã nằm trong tiến trình — nếu
            // `loadedImages()` không thấy nó thì phép đo đang nhìn nhầm chỗ.
            guard GrammarLibrary.isLoaded else {
                return "bài này phải chạy SAU bài grammar; không có gì vừa nạp để đối chứng"
            }
            let bâyGiờ = LazyLoadAudit.loadedBundled(in: LazyLoadAudit.loadedImages())
            guard bâyGiờ.contains(where: { $0.imageMatch == "libTreeSitterHeavy" }) else {
                return "libTreeSitterHeavy đã nạp thật mà bộ dò hỏi nhân lại không thấy"
                    + " — vế A đang nhìn nhầm chỗ, và cổng DuckDB dựa trên nó là cổng giấy"
            }
            return nil
        },

        Case(name: "C# và Ruby cũng lên màu từ dylib (ADR-08)") { controller in
            // Hai mươi grammar chung một dylib, mỗi cái một ký hiệu, và C# là ký hiệu DUY NHẤT
            // lệch tên (`tree_sitter_c_sharp` chứ không phải `tree_sitter_csharp`). Đường đi
            // qua `dlsym` nên tên gõ nhầm không lộ ra lúc biên dịch — chỉ lộ thành "file này
            // không có màu". `GrammarLibraryTests` kiểm cả hai mươi; bài này kiểm hai ca khó
            // nhất qua đường giao diện thật.
            for (language, source) in [
                (SyntaxLanguage.csharp, "class KhachHang { public string Ten { get; set; } }\n"),
                (SyntaxLanguage.ruby, "class Lop\n  def ham(a)\n    a + 1\n  end\nend\n"),
            ] {
                controller.prepareSelfTestDocument(source)
                controller.setSyntaxLanguageForSelfTest(language)
                guard controller.waitForHighlightingForSelfTest() else {
                    controller.setSyntaxLanguageForSelfTest(nil)
                    return "\(language.displayName) không lên màu — "
                        + (GrammarLibrary.failureReason ?? "không rõ vì sao")
                }
            }
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "màu cú pháp lên THẬT trên chữ, đúng chỗ") { controller in
            // Đọc màu từ chính kho chữ của NSTextView, không từ danh sách span: danh sách đúng
            // mà đặt sai chỗ thì bài kiểm vẫn xanh còn màn hình vẫn sai.
            let source = "int main(void) { return 0; }\n"
            controller.prepareSelfTestDocument(source)
            controller.setSyntaxLanguageForSelfTest(.c)
            guard controller.waitForHighlightingForSelfTest() else {
                return "chờ 5 giây mà không có màu nào"
            }

            // "return" bắt đầu ở offset 17 trong chuỗi trên.
            let returnOffset = source.range(of: "return").map {
                source.distance(from: source.startIndex, to: $0.lowerBound)
            }!
            guard let keyword = controller.syntaxColorForSelfTest(at: returnOffset) else {
                return "không có màu tại từ khoá return"
            }
            guard keyword != Tokens.Color.editorInk else {
                return "từ khoá return vẫn màu chữ thường"
            }
            // Khoảng trắng giữa hai câu lệnh KHÔNG được tô: tô cả khoảng trắng nghĩa là đoạn
            // bị nới rộng quá và mọi offset đều đáng ngờ.
            let spaceOffset = returnOffset - 1
            let space = controller.syntaxColorForSelfTest(at: spaceOffset)
            guard space == nil || space == Tokens.Color.editorInk else {
                return "khoảng trắng trước return cũng bị tô"
            }
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "chữ tiếng Việt trong chuỗi không làm lệch màu") { controller in
            // Quy đổi offset BYTE của tree-sitter sang đơn vị UTF-16 của NSTextStorage là chỗ
            // dự án này đã sai vài lần. "Nguyễn" 6 ký tự nhưng 9 byte.
            let source = "const char *ten = \"Nguyễn Văn A\";\nint x = 1;\n"
            controller.prepareSelfTestDocument(source)
            controller.setSyntaxLanguageForSelfTest(.c)
            guard controller.waitForHighlightingForSelfTest() else { return "không có màu" }

            let quote = source.range(of: "\"Nguyễn")!.lowerBound
            let quoteOffset = source.utf8.distance(
                from: source.utf8.startIndex, to: quote.samePosition(in: source.utf8)!
            )
            guard let stringColor = controller.syntaxColorForSelfTest(at: quoteOffset + 3) else {
                return "không có màu bên trong chuỗi"
            }
            guard stringColor != Tokens.Color.editorInk else {
                return "bên trong chuỗi vẫn màu chữ thường — offset lệch"
            }
            // Và chữ `int` của dòng SAU phải mang màu từ khoá, không mang màu chuỗi.
            let intOffset = source.utf8.count - "int x = 1;\n".utf8.count
            let after = controller.syntaxColorForSelfTest(at: intOffset)
            guard after != stringColor else {
                return "màu chuỗi tràn sang dòng sau — đúng kiểu lệch offset do chữ nhiều byte"
            }
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        Case(name: "đổi ngôn ngữ thì màu cũ bị xoá") { controller in
            controller.prepareSelfTestDocument("int main(void) { return 0; }\n")
            controller.setSyntaxLanguageForSelfTest(.c)
            guard controller.waitForHighlightingForSelfTest() else { return "không tô được" }

            controller.setSyntaxLanguageForSelfTest(nil)
            controller.flushDrawingForSelfTest()
            guard !controller.hasSyntaxColorsForSelfTest else {
                return "bỏ ngôn ngữ mà màu cũ còn nằm lại trên chữ"
            }
            return nil
        },

        Case(name: "nhận ngôn ngữ theo đuôi file và hiện ở thanh trạng thái") { controller in
            let root = controller.useTemporaryStoresForSelfTest()
            let file = root.appendingPathComponent("thu.py")
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try "def ham(a):\n    return a + 1\n".write(to: file, atomically: true, encoding: .utf8)
            } catch {
                return "không dựng được file thử: \(error)"
            }

            controller.closeSplitForSelfTest()
            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: file.path)

            guard controller.syntaxLanguageForSelfTest == .python else {
                return "ngôn ngữ nhận ra: \(String(describing: controller.syntaxLanguageForSelfTest))"
            }
            guard controller.statusLanguageForSelfTest == "Python" else {
                return "thanh trạng thái ghi «\(controller.statusLanguageForSelfTest)»"
            }
            controller.setSyntaxLanguageForSelfTest(nil)
            return nil
        },

        // MARK: - Chế độ CSV, tô màu theo cột (FR-CSV-401/402)

        Case(name: "mỗi cột CSV một màu, và cột lặp lại thì cùng màu") { controller in
            let source = "ten,tuoi,thanh_pho,ghi_chu\nAn,30,Ha Noi,x\nBinh,25,Hue,y\n"
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.flushDrawingForSelfTest()

            func offset(of text: String) -> Int {
                source.utf8.distance(
                    from: source.utf8.startIndex,
                    to: source.range(of: text)!.lowerBound.samePosition(in: source.utf8)!
                )
            }
            guard let c0 = controller.columnColorForSelfTest(at: offset(of: "ten")),
                  let c1 = controller.columnColorForSelfTest(at: offset(of: "tuoi")),
                  let c2 = controller.columnColorForSelfTest(at: offset(of: "thanh_pho"))
            else { return "không có màu cột nào" }

            guard c0 != c1, c1 != c2, c0 != c2 else { return "ba cột đầu trùng màu" }

            // Cùng một cột ở hàng khác phải CÙNG màu — đó là cả điểm của rainbow columns.
            guard let an = controller.columnColorForSelfTest(at: offset(of: "An")),
                  let binh = controller.columnColorForSelfTest(at: offset(of: "Binh"))
            else { return "không có màu ở các hàng dữ liệu" }
            guard an == c0, binh == c0 else { return "cột 0 đổi màu giữa các hàng" }
            controller.setCSVModeForSelfTest(false)
            return nil
        },

        Case(name: "Finder mở NHIỀU tệp: mở hết, không nuốt mất tệp nào") { controller in
            // Anh báo: mở tệp từ Finder khi GEditor đã mở sẵn thì không thấy app bật lên. Đọc
            // lại `application(_:openFiles:)` thấy bốn lỗi; bài này canh được MỘT trong bốn.
            //
            // GIỚI HẠN, nói thẳng ra để không ai đọc màu xanh này rộng hơn thực tế:
            //
            // · "Đưa app ra trước" (`NSApp.activate`) không kiểm được ở đây — một lượt chạy
            //   không người lái không có khái niệm app nào đang ở trước.
            // · "Vào cửa sổ ĐANG DÙNG thay vì cửa sổ đầu tiên" cũng không: cửa sổ chỉ thành
            //   key sau khi hệ thống cửa sổ xử lý, và trong lượt chạy này `isKeyWindow` không
            //   bao giờ bật. Đã thử và bỏ, chứ không phải chưa nghĩ tới.
            //
            // Vế còn lại thì kiểm được, và nó cũng là một lỗi thật: bản cũ chỉ mở tệp ĐẦU
            // TIÊN. Chọn năm tệp trong Finder rồi Enter thì bốn tệp biến mất không lời nào.
            guard let delegate = NSApp.delegate as? AppDelegate else {
                return "không lấy được AppDelegate"
            }
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("finder-open-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            var paths: [String] = []
            for index in 0 ..< 3 {
                let path = (folder as NSString).appendingPathComponent("tep-\(index).txt")
                try? Data("nội dung \(index)\n".utf8).write(to: URL(fileURLWithPath: path))
                paths.append(path)
            }

            let before = controller.tabCountForSelfTest
            delegate.application(NSApp, openFiles: paths)

            guard controller.tabCountForSelfTest == before + paths.count else {
                return "mở \(paths.count) tệp mà chỉ thêm "
                    + "\(controller.tabCountForSelfTest - before) tab"
            }
            let opened = Set(controller.tabPathsForSelfTest.compactMap { $0 })
            for path in paths where !opened.contains(path) {
                return "thiếu tab cho \((path as NSString).lastPathComponent)"
            }

            // Danh sách rỗng phải trả về THẤT BẠI, không phải im lặng báo thành công. Hệ điều
            // hành dùng câu trả lời ấy để quyết định có báo lỗi cho người dùng hay không.
            delegate.application(NSApp, openFiles: [])
            return nil
        },

        Case(name: "CSV lớn: cuộn xa rồi màu cột vẫn tô ĐÚNG chỗ vừa hiện ra") { controller in
            // ĐỐI CHỨNG ÂM CHO MỘT LƯỢT TỐI ƯU. `applyColumnColors` nay ghi nhớ vùng đã tô và
            // bỏ qua nếu tầm nhìn còn nằm trong đó — đo được 132 ms → 1,4 ms mỗi lần cuộn.
            //
            // Nhưng một bản vá "thôi không tô nữa" cũng cho đúng con số ấy. Bài kiểm màu cột
            // đang có chạy trên ba dòng và không cuộn đi đâu, nên nó KHÔNG phân biệt được hai
            // chuyện. Bài này cuộn hẳn ra ngoài vùng đã tô rồi hỏi lại màu.
            var lines = ["ma,ten,tinh,diem,ghi_chu"]
            for index in 0 ..< 4000 {
                lines.append("MA\(index),Nguyễn Văn \(index),Tỉnh \(index % 63),\(index % 10),x")
            }
            let source = lines.joined(separator: "\n") + "\n"
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.flushDrawingForSelfTest()

            let buffer = controller.editorDocument.buffer
            /// Màu của ô thứ 0 và ô thứ 1 của một dòng.
            func twoFields(ofLine line: Int) -> (NSColor, NSColor)? {
                let range = buffer.contentRange(ofLine: line)
                let bytes = buffer.bytes(in: range)
                guard let comma = bytes.firstIndex(of: UInt8(ascii: ",")) else { return nil }
                guard let first = controller.columnColorForSelfTest(at: range.lowerBound),
                      let second = controller.columnColorForSelfTest(at: range.lowerBound + comma + 1)
                else { return nil }
                return (first, second)
            }

            guard let top = twoFields(ofLine: 1) else { return "đầu tài liệu không có màu cột" }
            guard top.0 != top.1 else { return "hai cột đầu tài liệu đã cùng màu" }

            // Cuộn thật xa bằng đúng đường người dùng đi, rồi để vòng lặp sự kiện chạy —
            // `boundsDidChange` (thứ đánh thức `viewportMoved`) đi qua đó chứ không phát ngay.
            controller.goTo(line: 3900, column: nil)
            controller.settleForSelfTest()

            // Hỏi màu ở dòng ĐANG THẬT SỰ NHÌN THẤY, không ở dòng vừa xin tới.
            //
            // Hai con số ấy lệch nhau, và lệch có lý do đã ghi trong `VerticalGeometry`: chiều
            // cao khung suy từ `rowsPerLine` ƯỚC LƯỢNG, nên "đi tới dòng 3900" đặt khung ở
            // quanh dòng 3550. Bám vào dòng xin tới là bài kiểm đi đo một thứ khác với thứ
            // người dùng nhìn thấy.
            let visible = controller.editorView.visibleLineRange
            guard visible.lowerBound > 100 else {
                return "cuộn không đi đâu cả: vẫn đang ở \(visible)"
            }
            let middle = (visible.lowerBound + visible.upperBound) / 2
            guard let far = twoFields(ofLine: middle) else {
                return "cuộn tới dòng \(middle) rồi mà KHÔNG có màu cột — phép ghi nhớ chặn nhầm"
            }
            guard far.0 != far.1 else {
                return "ở dòng \(middle) hai cột cạnh nhau cùng màu"
            }
            // Và cùng một CỘT thì cùng màu dù cách nhau mấy nghìn dòng — đó là cả điểm của
            // rainbow columns, và nó chứng minh phép tô bám theo cột chứ không tô một dải bất kỳ.
            guard far.0 == top.0, far.1 == top.1 else {
                return "cùng cột mà màu đổi giữa dòng 1 và dòng \(middle)"
            }

            controller.setCSVModeForSelfTest(false)
            return nil
        },

        Case(name: "Ngôn ngữ đã ĐĂNG KÝ thì phải dịch gần đủ — không có bảng nửa vời") { _ in
            // Vì sao cần: đăng ký một bảng mới dịch 40% là tệ hơn không đăng ký. Người dùng chọn
            // tiếng ấy, thấy menu đúng tiếng mình, rồi mọi thông báo lỗi lại ra tiếng Anh — họ
            // kết luận sản phẩm hỏng, không kết luận "bản dịch chưa xong".
            //
            // Không đăng ký thì `effective` đi tiếp xuống lựa chọn kế của họ, và đó là hành vi
            // thành thật hơn.
            //
            // Ngưỡng 95% chứ không 100%: chuỗi nhiều dòng của khối «Phương pháp» cố ý để rơi về
            // tiếng Anh ở mọi bảng, nên 100% là một mốc không bảng nào chạm tới được.
            let khoa = Array(L10n.en.keys)
            var bangKe: [String] = []
            for language in L10n.Language.allCases {
                guard L10n.table(for: language) != nil else { continue }
                let phu = L10n.coverage(of: language, among: khoa)
                let tiLe = Double(phu.done) / Double(max(phu.total, 1)) * 100
                bangKe.append("\(language.rawValue) \(Int(tiLe))%")
                guard tiLe >= 95 else {
                    return "\(language.rawValue) mới dịch \(phu.done)/\(phu.total) "
                        + "(\(Int(tiLe))%) — gỡ đăng ký hoặc dịch nốt"
                }
            }
            // Ít nhất MỘT bảng — tức phép lặp trên có chạy thật. Không có vế này thì một ngày
            // `table(for:)` trả `nil` cho tất cả, vòng lặp không quay lần nào, và bài kiểm xanh
            // vì nó chẳng kiểm gì. Ngưỡng là 1 chứ không phải một con số theo số ngôn ngữ đang
            // có: bảng tiếng Anh luôn tồn tại, còn số bảng còn lại thì lớn dần theo từng đợt
            // dịch — chốt nó ở đây là buộc phải sửa bài kiểm mỗi lần thêm một thứ tiếng.
            guard !bangKe.isEmpty else { return "không có bảng dịch nào — phép đếm chạy rỗng" }
            print("   \(bangKe.count) bảng: \(bangKe.joined(separator: " · "))")
            return nil
        },

        Case(name: "Không bảng nào là bản CHUYỂN MÃ của bảng khác") { _ in
            // Bốn lần trong đợt dịch này tôi đứng trước cùng một cám dỗ: 繁體中文 từ 简体中文,
            // فارسی từ العربية, اردو từ العربية, và dansk từ svenska. Mỗi lần "chạy một bộ
            // chuyển mã là xong trong một giây", và mỗi lần kết quả TRÔNG đúng với người không
            // đọc được thứ tiếng ấy — nhưng đọc lên là sai, vì chữ viết chung không kéo theo
            // từ vựng chung.
            //
            // Cổng này bắt đúng chuyện đó, và nó rẻ. Đo được giữa những bảng dịch THẬT:
            //
            //     da ↔ nb   19%   (cao nhất — bokmål sinh ra từ tiếng Đan viết)
            //     sv ↔ nb    9%
            //     sv ↔ da    7%
            //
            // Phần trùng ấy là tên kỹ thuật giữ nguyên ở mọi thứ tiếng: SQL · k-means · MAPE ·
            // IQR · Support · Lift. Ngưỡng 60% nằm xa trên mức cao nhất từng đo và xa dưới mức
            // một bản chép — nên nó không kêu oan, mà cũng không bỏ lọt.
            let bang = L10n.Language.allCases.compactMap { language -> (String, [String: String])? in
                guard let table = L10n.table(for: language) else { return nil }
                return (language.rawValue, table)
            }
            guard bang.count >= 2 else { return nil }

            var caoNhat = (cap: "", tiLe: 0)
            for i in bang.indices {
                for j in bang.indices where j > i {
                    let (tenA, a) = bang[i]
                    let (tenB, b) = bang[j]
                    let chung = a.keys.filter { a[$0] != nil && a[$0] == b[$0] }.count
                    let tiLe = chung * 100 / max(a.count, 1)
                    if tiLe > caoNhat.tiLe { caoNhat = ("\(tenA) ↔ \(tenB)", tiLe) }
                    guard tiLe < 60 else {
                        return "\(tenA) và \(tenB) trùng \(chung)/\(a.count) mục (\(tiLe)%) — "
                            + "gần chắc chắn một bảng là bản chuyển mã của bảng kia"
                    }
                }
            }
            print("   \(bang.count) bảng · trùng nhau nhiều nhất: "
                  + "\(caoNhat.cap) \(caoNhat.tiLe)% (ngưỡng báo động 60%)")
            return nil
        },

        Case(name: "Mọi bản dịch giữ ĐÚNG các ô %d/%@ — sai một cái là hiện rác hoặc sập") { _ in
            // 165 trên 1010 chuỗi có ô định dạng. `String(format:)` đọc chúng theo THỨ TỰ và
            // theo KIỂU: một bản dịch đánh rơi `%d`, hay đảo `%@ %d` thành `%d %@`, thì tham số
            // được đọc sai kiểu — in ra con trỏ dưới dạng số, hoặc sập ngay tại chỗ.
            //
            // Đây là lớp lỗi mà người dịch không thấy: bản dịch đọc trôi chảy, chỉ có ô định
            // dạng là sai. Và nó chỉ nổ ở đúng cái nhánh hiếm sinh ra thông báo ấy.
            // Bộ nhận dạng phải phân biệt Ô ĐỊNH DẠNG với DẤU PHẦN TRĂM THẬT, và bản đầu của
            // chính nó đã không phân biệt được: nó thấy "Dải 80%" ↔ "80% band" rồi tố bản dịch
            // thêm một ô "%b". Không có ô nào cả — có một dấu phần trăm và một chữ "band".
            //
            // Nên sau `%` phải là một ký tự chuyển đổi THẬT. `%` đứng trước dấu cách, trước chữ
            // cái thường không thuộc bảng, hay ở cuối chuỗi, đều là phần trăm nguyên nghĩa.
            // So THAM SỐ THỨ MẤY mang kiểu gì, không so thứ tự chúng xuất hiện.
            //
            // Vì nhiều thứ tiếng BẮT BUỘC phải đảo. Tiếng Việt viết «%d giá trị sai ở cột %@»,
            // tiếng Nga đặt tên cột trước con số — và đảo thẳng `%d` với `%@` thì `String(format:)`
            // đọc con trỏ như số nguyên. Cách đúng là ô ĐÁNH SỐ: `%1$d`, `%2$@` giữ nguyên tham
            // số nào đi với chỗ nào, dù chúng đứng ở đâu trong câu.
            //
            // Nên bộ đo phải hiểu `%n$`. Bản đầu không hiểu, và nó sẽ ép mọi bản dịch phải theo
            // trật tự từ tiếng Việt — tức bắt người dịch viết những câu Nga sai ngữ pháp để làm
            // vừa lòng một bài kiểm.
            let kyTuChuyenDoi = Set("diouxXeEfgGaAcsp@")
            func oDinhDang(_ text: String) -> [Int: String] {
                var found: [Int: String] = [:]
                var thuTuNgam = 0
                let chars = Array(text)
                var i = 0
                while i < chars.count {
                    guard chars[i] == "%" else { i += 1; continue }
                    var j = i + 1
                    guard j < chars.count else { break }
                    if chars[j] == "%" { i = j + 1; continue }        // `%%` — phần trăm thật
                    // Tiền tố đánh số `n$` — phải đọc TRƯỚC cờ, vì `1$` và cờ `0` trông giống nhau.
                    var viTri: Int?
                    var k = j
                    var so = ""
                    while k < chars.count, chars[k].isNumber { so.append(chars[k]); k += 1 }
                    if k < chars.count, chars[k] == "$", let n = Int(so) {
                        viTri = n
                        j = k + 1
                    }
                    while j < chars.count, "0123456789.-+#'".contains(chars[j]) { j += 1 }
                    while j < chars.count, "lhzjt".contains(chars[j]) { j += 1 }   // ld, lld, zu…
                    guard j < chars.count, kyTuChuyenDoi.contains(chars[j]) else {
                        i += 1                                        // không phải ô — bỏ qua
                        continue
                    }
                    thuTuNgam += 1
                    found[viTri ?? thuTuNgam] = String(chars[j])
                    i = j + 1
                }
                return found
            }

            for language in L10n.Language.allCases {
                guard let table = L10n.table(for: language) else { continue }
                for (viet, dich) in table {
                    let goc = oDinhDang(viet)
                    let ra = oDinhDang(dich)
                    guard goc == ra else {
                        let ta = goc.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }
                        let no = ra.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }
                        return "\(language.rawValue): «\(viet)» có ô \(ta) mà bản dịch có \(no)"
                    }
                }
            }
            return nil
        },

        Case(name: "Bản dịch không được RỖNG, và không được bỏ nguyên tiếng Việt") { _ in
            // Hai kiểu "đã dịch" giả. Cả hai đều làm bộ đếm độ phủ báo xanh trong khi người
            // dùng nhận về một nhãn trống hoặc một câu tiếng Việt giữa giao diện tiếng Nhật.
            //
            // Ngoại lệ hẹp và có lý do: những chuỗi vốn giống nhau ở mọi thứ tiếng — tên riêng
            // ("GEditor", "CSV", "SQL", "JSON"), ký hiệu, và các từ mượn nguyên dạng.
            for language in L10n.Language.allCases {
                guard let table = L10n.table(for: language) else { continue }
                for (viet, dich) in table {
                    guard !dich.trimmingCharacters(in: .whitespaces).isEmpty else {
                        return "\(language.rawValue): «\(viet)» dịch thành chuỗi rỗng"
                    }
                    // Giống hệt bản tiếng Việt VÀ có dấu tiếng Việt → chắc chắn là bỏ sót.
                    let coDauViet = viet.contains { "ăâđêôơưáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩị"
                        .contains(Character($0.lowercased())) }
                    if dich == viet && coDauViet {
                        return "\(language.rawValue): «\(viet)» còn nguyên tiếng Việt"
                    }
                }
            }
            return nil
        },

        Case(name: "Bộ chọn ngôn ngữ: chọn tiếng nào RA ĐÚNG tiếng ấy, dù menu có dải phân cách") {
            controller in
            // Đây là bài kiểm cho một bẫy CHỈ SỐ. Bản đầu của bộ chọn đọc
            // `L10n.Language.allCases[indexOfSelectedItem]`, đúng chừng nào menu còn phẳng.
            // Thêm ba dải phân cách và ba tiêu đề vùng là mọi chỉ số phía sau lệch sáu — người
            // dùng chọn tiếng Ả Rập nhận về tiếng Do Thái, không có gì để nổ và không ai biết.
            //
            // Nên bài này KHÔNG đọc chỉ số. Nó chọn theo tên rồi hỏi cấu hình nhận được gì.
            let panel = controller.preferencesPanelForSelfTest()
            controller.settleForSelfTest()

            let demDuoc = panel.selectableLanguageCountForSelfTest
            let mongDoi = L10n.Language.allCases.count
            guard demDuoc == mongDoi else {
                return "bộ chọn có \(demDuoc) mục chọn được, trong khi có \(mongDoi) ngôn ngữ"
            }

            // Thử đúng những ngôn ngữ nằm SAU dải phân cách — chỗ chỉ số lệch.
            for language in [L10n.Language.ar, .he, .ja, .zhHant, .ms, .vi] {
                panel.setLanguageForSelfTest(language)
                controller.settleForSelfTest()
                guard controller.settingsLanguageForSelfTest == language.rawValue else {
                    return "chọn \(language.displayName) mà cấu hình ghi "
                        + "\(controller.settingsLanguageForSelfTest)"
                }
                guard panel.languageTitleForSelfTest == language.displayName else {
                    return "chọn \(language.displayName) mà bộ chọn hiện "
                        + "\(panel.languageTitleForSelfTest)"
                }
            }

            panel.setLanguageForSelfTest(.system)
            controller.settleForSelfTest()
            return nil
        },

        Case(name: "RTL: giao diện lật gương, còn NỘI DUNG người dùng thì không") { controller in
            // Hai vế, và vế thứ hai mới là vế dễ làm sai.
            //
            // Lật cả cửa sổ là một dòng, vì 328 neo đều dùng leading/trailing. Nhưng lật CẢ
            // vùng soạn thảo thì câu SQL, đường dẫn tệp và bảng CSV cũng đảo — lúc ấy sản phẩm
            // không phải "đã bản địa hoá", mà là hỏng theo một kiểu chỉ người đọc tiếng Ả Rập
            // mới báo được.
            var loi: String?
            L10n.withLanguageForSelfTest(.ar) {
                controller.applyLayoutDirection()
                controller.settleForSelfTest()
                let chieu = controller.layoutDirectionForSelfTest()
                if chieu.khung != "phai" {
                    loi = "tiếng Ả Rập mà khung vẫn viết từ \(chieu.khung)"
                } else if chieu.soanThao != "trai" {
                    loi = "vùng soạn thảo bị đảo theo — nội dung người dùng không được đảo"
                }
                // Căn theo mép cũng phải đổi bên, nếu không cột số thứ tự dòng dính mép sai.
                if loi == nil, NSTextAlignment.trailingEdge != .left {
                    loi = "căn mép cuối vẫn là .right trong giao diện phải-sang-trái"
                }
            }
            if let loi { controller.applyLayoutDirection(); return loi }

            // Và trả về được: đổi sang tiếng không-RTL thì cửa sổ phải lật lại.
            //
            // Không có vế này thì một bản hiện thực "đặt cờ RTL rồi không bao giờ gỡ" vẫn xanh,
            // và người dùng đổi từ tiếng Ả Rập sang tiếng Anh sẽ mắc kẹt ở giao diện lật.
            L10n.withLanguageForSelfTest(.en) {
                controller.applyLayoutDirection()
                controller.settleForSelfTest()
                if controller.layoutDirectionForSelfTest().khung != "trai" {
                    loi = "đổi về tiếng Anh mà khung vẫn viết từ phải"
                }
            }
            controller.applyLayoutDirection()
            controller.settleForSelfTest()
            return loi
        },

        Case(name: "Ngôn ngữ: 30 thứ tiếng, tên bản ngữ, và chiều viết suy từ CHÍNH nó") { _ in
            // Ba tính chất mà một bảng ngôn ngữ gõ tay hay sai, và cả ba đều im lặng.
            let all = L10n.Language.allCases.filter { $0 != .system && $0 != .vi }
            guard all.count >= 30 else {
                return "mới có \(all.count) ngôn ngữ, chưa đủ 30"
            }

            // MỘT: tên phải là tên BẢN NGỮ. Người tìm tiếng mẹ đẻ trong danh sách hiện bằng thứ
            // tiếng họ không đọc được thì chỉ nhận ra "日本語" — không nhận ra "Tiếng Nhật".
            for language in all where language.displayName.isEmpty {
                return "\(language.rawValue) không có tên hiển thị"
            }
            if L10n.Language.ja.displayName != "日本語" || L10n.Language.ar.displayName != "العربية" {
                return "tên ngôn ngữ không phải tên bản ngữ"
            }

            // HAI: mã không được trùng nhau. Trùng thì hai ngôn ngữ ghi đè cấu hình của nhau và
            // người dùng thấy mình chọn tiếng này lại ra tiếng kia.
            let codes = Set(all.map(\.rawValue))
            guard codes.count == all.count else { return "có mã ngôn ngữ trùng nhau" }

            // BA: RTL phải suy từ chính ngôn ngữ, KHÔNG suy từ vùng. Tiếng Thổ nằm cùng nhóm
            // Trung Đông với tiếng Ả Rập nhưng viết trái-sang-phải; ai gộp "Trung Đông = RTL"
            // sẽ lật ngược giao diện của cả nước Thổ.
            guard L10n.Language.ar.isRTL, L10n.Language.he.isRTL, L10n.Language.fa.isRTL,
                  L10n.Language.ur.isRTL else {
                return "thiếu ngôn ngữ RTL"
            }
            guard !L10n.Language.tr.isRTL else {
                return "tiếng Thổ bị đánh dấu RTL — suy chiều viết từ vùng địa lý"
            }

            // BỐN: mọi ngôn ngữ phải thuộc đúng một vùng, nếu không bộ chọn sẽ nuốt mất nó.
            for language in all where language.region == nil {
                return "\(language.rawValue) không thuộc vùng nào — bộ chọn sẽ không hiện nó"
            }
            let tongVung = L10n.Language.Region.allCases
                .reduce(0) { $0 + L10n.Language.inRegion($1).count }
            guard tongVung == all.count else {
                return "gom nhóm sót: \(tongVung) trên \(all.count) ngôn ngữ"
            }
            return nil
        },

        Case(name: "Ghép thẻ ngôn ngữ của hệ: en-US ra tiếng Anh, zh-Hans-CN ra giản thể") { _ in
            // Hệ trả về thẻ có vùng (`en-US`, `pt-BR`, `zh-Hant-TW`). So BẰNG thì mọi thẻ ấy
            // trượt hết và người dùng Mỹ nhận giao diện tiếng Việt — kiểu hỏng không ai gặp
            // trên máy người viết mã, vì máy ấy đặt tiếng Việt.
            let phepThu: [(String, L10n.Language)] = [
                ("en-US", .en), ("en", .en), ("fr-CA", .fr), ("pt-BR", .pt),
                ("zh-Hans-CN", .zhHans), ("zh-CN", .zhHans), ("zh-Hant-TW", .zhHant),
                ("zh-TW", .zhHant), ("zh-HK", .zhHant), ("ar-EG", .ar), ("he-IL", .he),
                ("nb-NO", .nb), ("no", .nb), ("nn-NO", .nb), ("ja-JP", .ja),
            ]
            for (the, mong) in phepThu {
                let ra = L10n.match(the)
                guard ra == mong else {
                    return "\(the) ghép ra \(ra?.rawValue ?? "không gì") — mong \(mong.rawValue)"
                }
            }
            // Và thẻ ta KHÔNG có bảng thì phải trả về không-gì, để `effective` đi tiếp xuống
            // lựa chọn kế của người dùng thay vì dừng ở một ngôn ngữ rỗng.
            guard L10n.match("xx-YY") == nil else { return "thẻ lạ mà vẫn ghép ra một ngôn ngữ" }
            return nil
        },

        Case(name: "Panel kết quả: bám theo cửa sổ đổi cỡ, và kéo quá tay không PHỒNG cả khung") {
            controller in
            // Bài kiểm cho panel SQL ở dưới không thay được bài này, vì panel kết quả có thêm
            // MỘT ràng buộc riêng mà mười ba panel kia không có: "cao nhiều nhất 40% khung".
            // Ràng buộc ấy bắt buộc, và hằng số do thanh kéo đặt cũng bắt buộc — hai cái không
            // cùng đúng được khi người dùng kéo quá 40%.
            //
            // Nó KHÔNG kẹp panel lại như người ta tưởng khi đọc. Auto Layout gỡ mâu thuẫn bằng
            // cách nới thứ nới được: đo trên khung 720 pt thì `container` phồng lên 1440.
            controller.collapseAllPanelsForSelfTest()
            controller.showSearchResultsForSelfTest(
                FindInFiles.Summary(results: [], filesScanned: 0), pattern: "x")
            controller.settleForSelfTest()

            // Dọn bằng `defer`, không phải bằng bốn dòng ở cuối thân hàm.
            //
            // Bài này trả về sớm ở bảy chỗ. Dọn ở cuối thì mỗi lần nó ĐỎ, cửa sổ ở lại cỡ đã
            // phóng và panel ở lại mở — nên bài kế tiếp cũng đỏ, vì trạng thái của bài này chứ
            // không phải vì lỗi của nó. Đúng chuyện vừa xảy ra: một lỗi thật hiện ra thành hai
            // dòng đỏ, và dòng thứ hai chỉ sai chỗ.
            var daNoRa: Double = 0
            defer {
                if daNoRa != 0 { controller.resizeWindowForSelfTest(byHeight: -daNoRa) }
                controller.hideResultsPanel()
                controller.settleForSelfTest()
            }

            let khung = controller.contentHeightForSelfTest
            guard khung > 200 else { return "khung chưa có kích thước thật" }
            guard let mo = controller.panelHeightForSelfTest("results") else {
                return "không đọc được chiều cao panel kết quả"
            }
            // Luật là 0,32 × khung, NHƯNG trần cắt trước khi luật ấy được áp: cột dọc còn bao
            // nhiêu chỗ thì panel chỉ được bấy nhiêu. Bài đầu tiên bỏ qua vế trần và đỏ ngay
            // lần đầu có thêm một hàng cố định trong cột — 220 pt theo luật, 218 pt theo trần.
            let tran = controller.panelCeilingForSelfTest("results") ?? khung
            let mongDoi = min(max(180, khung * 0.32), max(180, khung * 0.6), max(180, tran))
            guard abs(mo - mongDoi) < 1 else {
                return "mở ra \(Int(mo)) pt trên khung \(Int(khung)) pt, trần \(Int(tran)) pt "
                    + "— mong \(Int(mongDoi))"
            }

            // Và chiều cao ấy phải THẬT SỰ xuất hiện trên màn hình.
            //
            // Ràng buộc chiều cao panel để ưu tiên dưới `fittingSizeCompression` (xem
            // `makePanelHeight`), tức nó là đề nghị chứ không phải mệnh lệnh. Bài kiểm chỉ đọc
            // hằng số sẽ xanh y hệt khi panel bẹp còn 0 pt trên màn hình — nó đọc lại đúng con
            // số mà chính sản phẩm vừa ghi, và không hỏi ai có nghe không.
            guard let khungPanel = controller.panelFrameHeightForSelfTest("results") else {
                return "không đọc được khung thật của panel kết quả"
            }
            guard abs(khungPanel - mo) < 1 else {
                return "đặt \(Int(mo)) pt mà trên màn hình chỉ cao \(Int(khungPanel)) pt — "
                    + "ràng buộc bị thứ khác đè"
            }

            // VẾ MỘT: cửa sổ to lên thì panel to theo.
            //
            // Chưa kéo bao giờ thì panel không có con số của riêng nó, nên nó phải bám tỉ lệ ở
            // MỌI cỡ cửa sổ chứ không chỉ ở cỡ lúc mở. Không có vế này thì "cao theo cửa sổ"
            // chỉ đúng trong đúng một khoảnh khắc, và phần còn lại của phiên vẫn là hằng số
            // cứng — chỉ khác con số.
            daNoRa = controller.resizeWindowForSelfTest(byHeight: 400)
            controller.settleForSelfTest()
            let khungTo = controller.contentHeightForSelfTest
            // Ngưỡng 100 chứ không 400: cửa sổ không nở quá màn hình, nên xin 400 pt trên một
            // máy màn hình thấp chỉ được 298 — và bài kiểm đòi đủ 400 sẽ đỏ vì cỡ màn hình của
            // người chạy, một lý do chẳng liên quan gì tới thứ nó đang kiểm. Mọi phép so bên
            // dưới đều tính từ `khungTo` ĐO ĐƯỢC, nên nở bao nhiêu cũng kiểm đúng.
            guard khungTo > khung + 100 else {
                return "cửa sổ không to lên thật: \(Int(khung)) → \(Int(khungTo))"
            }
            guard let sauKhiTo = controller.panelHeightForSelfTest("results") else {
                return "mất ràng buộc chiều cao sau khi đổi cỡ"
            }
            guard abs(sauKhiTo - min(max(180, khungTo * 0.32), max(180, khungTo * 0.6))) < 1 else {
                return "khung đi từ \(Int(khung)) lên \(Int(khungTo)) mà panel đứng ở "
                    + "\(Int(sauKhiTo)) pt — không bám theo"
            }

            // VẾ HAI: kéo quá tay thì DỪNG ở trần, và khung KHÔNG được to ra.
            //
            // Vế "khung không đổi" mới là vế bắt được lỗi thật; vế "dừng ở trần" thì ràng buộc
            // cũ cũng qua được.
            _ = controller.dragPanelForSelfTest("results", by: 10000)
            controller.settleForSelfTest()
            guard let keo = controller.panelHeightForSelfTest("results") else {
                return "mất ràng buộc chiều cao sau khi kéo"
            }
            guard keo <= khungTo * 0.8 + 1 else {
                return "kéo quá tay lên tới \(Int(keo)) pt, quá trần \(Int(khungTo * 0.8))"
            }
            let khungSauKeo = controller.contentHeightForSelfTest
            guard abs(khungSauKeo - khungTo) < 1 else {
                return "kéo panel làm khung phồng từ \(Int(khungTo)) lên \(Int(khungSauKeo)) pt"
            }

            return nil
        },

        Case(name: "Panel cao theo CỬA SỔ và KÉO được, không đứng ở một hằng số cứng") {
            controller in
            // Anh nêu: "thông tin nhiều thì giao diện bé xíu, phần không có thông tin thì
            // rộng". Đọc lại thì đúng vậy: mười bốn panel có chiều cao viết cứng 160–340 pt,
            // chọn khi nhìn một cửa sổ cỡ trung, và không đổi theo bất cứ thứ gì.
            controller.collapseAllPanelsForSelfTest()
            // Nới cửa sổ trước, và trả lại đúng phần đã nở khi xong.
            //
            // Vế "kéo lên thì cao thêm" chỉ có nghĩa khi CÒN CHỖ để cao thêm. Trên một cửa sổ
            // vừa đủ, trần chạm sàn và panel đứng im — đúng như thiết kế, nhưng bài kiểm khi ấy
            // đỏ và tố sản phẩm "kéo không ăn". Đã xảy ra: cửa sổ teo dần qua các bài trước đó.
            let daNoRa = controller.resizeWindowForSelfTest(byHeight: 400)
            defer {
                if daNoRa != 0 { controller.resizeWindowForSelfTest(byHeight: -daNoRa) }
                controller.closeSQLPanelForSelfTest()
                controller.settleForSelfTest()
            }
            controller.openSQLPanelForSelfTest()
            controller.settleForSelfTest()

            guard let opened = controller.panelHeightForSelfTest("sql") else {
                return "không đọc được chiều cao panel SQL"
            }
            // VẾ MỘT: theo TỈ LỆ cửa sổ, không phải hằng số cũ (SQLPanel.height = 220).
            //
            // So với chiều cao cửa sổ chứ không so với một con số viết sẵn: bài kiểm mà chốt
            // "phải bằng 320" sẽ đỏ ngay khi ai đó đổi cỡ cửa sổ mặc định, và nó không nói
            // được gì về tính chất đang cần — rằng panel BÁM theo cửa sổ.
            let windowHeight = controller.contentHeightForSelfTest
            guard windowHeight > 200 else { return "cửa sổ chưa có kích thước thật" }
            let expected = min(max(220, windowHeight * 0.32), windowHeight * 0.6)
            guard abs(opened - expected) < 1 else {
                return "panel cao \(Int(opened)) pt trên cửa sổ \(Int(windowHeight)) pt — "
                    + "mong đợi \(Int(expected))"
            }

            // VẾ HAI: kéo được, và kéo LÊN thì CAO THÊM.
            //
            // Dấu ngược là kiểu hỏng người ta thử một lần rồi bỏ cuộc chứ không báo lại, nên
            // nó phải có bài kiểm chứ không chỉ có chú thích.
            guard controller.dragPanelForSelfTest("sql", by: 80) else {
                return "không tìm thấy thanh kéo của panel SQL"
            }
            guard let taller = controller.panelHeightForSelfTest("sql") else {
                return "mất ràng buộc chiều cao sau khi kéo"
            }
            guard taller > opened + 70 else {
                return "kéo lên 80 pt mà chiều cao đi từ \(Int(opened)) sang \(Int(taller))"
            }

            // VẾ BA: kéo xuống dưới sàn thì DỪNG ở sàn, không co về 0 rồi biến mất.
            _ = controller.dragPanelForSelfTest("sql", by: -10000)
            guard let floored = controller.panelHeightForSelfTest("sql") else {
                return "mất ràng buộc chiều cao"
            }
            guard floored >= 220 - 1 else {
                return "kéo quá tay làm panel co xuống \(Int(floored)) pt, dưới sàn 220"
            }

            // VẾ BỐN: lựa chọn được NHỚ. Đóng rồi mở lại phải ra đúng con số vừa kéo, chứ
            // không quay về mặc định — nếu không thì thanh kéo chỉ là một trò tiêu khiển.
            controller.closeSQLPanelForSelfTest()
            controller.settleForSelfTest()
            controller.openSQLPanelForSelfTest()
            controller.settleForSelfTest()
            guard let reopened = controller.panelHeightForSelfTest("sql") else {
                return "mở lại không có chiều cao"
            }
            guard abs(reopened - floored) < 1 else {
                return "mở lại quên mất con số đã kéo: \(Int(floored)) → \(Int(reopened))"
            }

            controller.closeSQLPanelForSelfTest()
            return nil
        },

        Case(name: "CSV RỘNG: cột nằm giữa màn hình vẫn được tô, không bị cắt oan") { controller in
            // ĐỐI CHỨNG cho phép cắt theo chiều NGANG. `applyColumnColors` nay bỏ qua những ô
            // nằm ngoài tầm nhìn ngang — đó là thứ đưa CSV 200 cột từ 44,9 ms xuống 13,8 ms
            // mỗi nhịp cuộn.
            //
            // Cắt quá tay thì hỏng theo kiểu khó thấy: cột 0 và 1 vẫn có màu (chúng luôn ở mép
            // trái), nên MỌI bài kiểm màu cột đang có vẫn xanh. Chỉ những cột ở giữa màn hình
            // mới mất màu — và không bài nào hỏi tới chúng.
            var lines = [(0 ..< 24).map { "cot\($0)" }.joined(separator: ",")]
            for row in 0 ..< 300 {
                lines.append((0 ..< 24).map { "v\($0)_\(row % 9)" }.joined(separator: ","))
            }
            let source = lines.joined(separator: "\n") + "\n"
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.settleForSelfTest()

            let buffer = controller.editorDocument.buffer
            let range = buffer.contentRange(ofLine: 5)
            let bytes = buffer.bytes(in: range)

            // Mốc đầu mỗi ô trên dòng ấy.
            var starts = [range.lowerBound]
            for (index, byte) in bytes.enumerated() where byte == UInt8(ascii: ",") {
                starts.append(range.lowerBound + index + 1)
            }
            guard starts.count == 24 else { return "dựng sai fixture: \(starts.count) ô" }

            // Ô thứ 8 nằm quanh ký tự thứ 60 — giữa màn hình rộng chừng 140 ký tự, tức CHẮC
            // CHẮN nhìn thấy được. Nó phải có màu, và màu khác ô liền kề.
            guard let mid = controller.columnColorForSelfTest(at: starts[8]),
                  let next = controller.columnColorForSelfTest(at: starts[9])
            else { return "cột giữa màn hình KHÔNG có màu — phép cắt ngang cắt oan" }
            guard mid != next else { return "hai cột giữa màn hình cùng màu" }

            // Và cột 0 vẫn đúng — để bài này không lặng lẽ thành một bài chỉ kiểm cột giữa.
            // Bảng màu có sáu sắc lặp lại; cột 0 và cột 8 rơi vào hai sắc khác nhau (0 và 2).
            guard let first = controller.columnColorForSelfTest(at: starts[0]), first != mid else {
                return "cột 0 và cột 8 cùng màu — bảng màu không lặp như dự kiến"
            }

            controller.setCSVModeForSelfTest(false)
            return nil
        },

        Case(name: "dấu phẩy TRONG field bọc ngoặc không làm lệch màu cột") { controller in
            // Luật RFC 4180 số 1. Tô theo phép tách chuỗi thay vì theo parser sẽ hỏng đúng ở
            // đây, và hỏng lặng lẽ: màu vẫn đẹp, chỉ là sai cột.
            let source = "a,b,c\n\"mot, hai\",X,Y\nz,X,Y\n"
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.flushDrawingForSelfTest()

            func offsetOfLast(_ text: String) -> Int {
                let range = source.range(of: text, options: .backwards)!
                return source.utf8.distance(from: source.utf8.startIndex,
                                            to: range.lowerBound.samePosition(in: source.utf8)!)
            }
            let quotedRowX = source.utf8.distance(
                from: source.utf8.startIndex,
                to: source.range(of: "X,Y")!.lowerBound.samePosition(in: source.utf8)!
            )
            let plainRowX = offsetOfLast("X,Y")

            guard let a = controller.columnColorForSelfTest(at: quotedRowX),
                  let b = controller.columnColorForSelfTest(at: plainRowX)
            else { return "không có màu" }
            guard a == b else {
                return "cùng cột 1 mà hai hàng khác màu — dấu phẩy trong ngoặc đã làm lệch cột"
            }
            controller.setCSVModeForSelfTest(false)
            return nil
        },

        Case(name: "tô cột trên cửa sổ 2 MB đủ nhanh để chạy thẳng luồng chính") { controller in
            // Tô cú pháp phải ra luồng nền vì tốn 110–190 ms. Tô cột thì chỉ là một lượt quét
            // byte. Bài này ĐO thay vì tin: quá 50 ms thì phải đổi sang chạy nền.
            var source = "cot_a,cot_b,cot_c,cot_d\n"
            var index = 0
            while source.utf8.count < 2_000_000 {
                source += "gia tri \(index),\"co, dau phay\",\(index * 7),ghi chu \(index)\n"
                index += 1
            }
            controller.prepareSelfTestDocument(source)

            // Lấy lần NHANH NHẤT trong ba lần, không lấy một lần duy nhất.
            //
            // Câu hỏi ở đây là "phép tô này có rẻ không", tức là một cận DƯỚI. Một lần đo lẻ
            // trả lời cả câu ấy lẫn câu "máy có đang bận không", và câu thứ hai thì bài kiểm
            // không kiểm soát được — bài này đã hai lần chớp đỏ ở 56 ms chỉ vì chạy ngay sau
            // một lần biên dịch. Lần nhanh nhất là lần ít bị nhiễu nhất, và nếu phép tô thật
            // sự chậm đi thì CẢ BA lần đều chậm.
            var best = Double.infinity
            for _ in 0 ..< 3 {
                controller.setCSVModeForSelfTest(false)
                controller.flushDrawingForSelfTest()
                let started = Date()
                controller.setCSVModeForSelfTest(true)
                controller.flushDrawingForSelfTest()
                best = Swift.min(best, Date().timeIntervalSince(started) * 1000)
            }

            guard controller.columnColorForSelfTest(at: 0) != nil else {
                return "không tô được gì trên file 2 MB"
            }
            guard best < 50 else {
                return "tô cột mất \(Int(best)) ms trên cửa sổ 2 MB (lần nhanh nhất trong ba)"
                    + " — phải chuyển sang chạy nền"
            }
            controller.setCSVModeForSelfTest(false)
            return nil
        },

        Case(name: "tô CÚ PHÁP trên cửa sổ 2 MB cũng phải đủ nhanh") { controller in
            // Bài này sinh ra vì bài CSV bên trên: cùng một cách đặt thuộc tính, cùng cỡ cửa
            // sổ. Nếu CSV mất 744 ms thì không có lý do gì cú pháp lại nhanh — mà tôi đã cho
            // qua nó chỉ vì bài kiểm cũ dùng tài liệu vài chục byte.
            var source = ""
            while source.utf8.count < 2_000_000 {
                source += "static int ham(int a) { const char *s = \"chao\"; return a + 1; }\n"
            }
            // ĐO NỀN trước: nạp cùng tài liệu ấy mà KHÔNG tô màu.
            //
            // Không có mốc nền thì con số "2.185 ms" không nói được gì: TextKit dựng bố cục
            // 2 MB cũng tốn thời gian, và tốn dù có tô hay không. Cái cần chặn là phần TÔ MÀU
            // thêm vào, không phải tổng.
            controller.setSyntaxLanguageForSelfTest(nil)
            let baselineStart = Date()
            controller.prepareSelfTestDocument(source)
            controller.flushDrawingForSelfTest()
            let baseline = Date().timeIntervalSince(baselineStart) * 1000

            controller.prepareSelfTestDocument(source)
            let started = Date()
            controller.setSyntaxLanguageForSelfTest(.c)
            guard controller.waitForHighlightingForSelfTest() else { return "không tô được" }
            let elapsed = Date().timeIntervalSince(started) * 1000

            controller.setSyntaxLanguageForSelfTest(nil)
            let overhead = elapsed - baseline
            guard overhead < 400 else {
                return "tô cú pháp thêm \(Int(overhead)) ms (nền \(Int(baseline)) ms, tổng \(Int(elapsed)) ms)"
            }
            return nil
        },

        Case(name: "hàng tiêu đề chỉ DÍNH sau khi đã cuộn qua nó") { controller in
            // Hiện lúc hàng đầu vẫn còn trong tầm nhìn là vẽ hai dòng tiêu đề chồng nhau —
            // người dùng tưởng file có hai dòng header.
            var source = "ma,ho_ten,thanh_pho,doanh_thu\n"
            for index in 0 ..< 3_000 {
                source += "KH\(index),Nguyễn Văn A,Hà Nội,\(index * 11)\n"
            }
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.setWrapModeForSelfTest(.off)
            controller.scrollToForSelfTest(0)
            controller.flushDrawingForSelfTest()

            guard !controller.csvHeaderVisibleForSelfTest else {
                return "đang ở đầu file mà hàng tiêu đề đã dính"
            }

            controller.scrollToForSelfTest(source.utf8.count / 2)
            controller.flushDrawingForSelfTest()
            guard controller.csvHeaderVisibleForSelfTest else {
                return "đã cuộn xuống giữa file mà hàng tiêu đề không hiện"
            }
            guard controller.csvHeaderTextForSelfTest == "ma,ho_ten,thanh_pho,doanh_thu" else {
                return "hàng tiêu đề ghi «\(controller.csvHeaderTextForSelfTest)»"
            }
            guard controller.csvHeaderColumnsForSelfTest == 4 else {
                return "đếm được \(controller.csvHeaderColumnsForSelfTest) cột, mong đợi 4"
            }

            // Màu của hàng tiêu đề phải KHỚP màu cột bên dưới, nếu không nó chỉ gây nhiễu.
            guard let h0 = controller.csvHeaderColorForSelfTest(0),
                  let h1 = controller.csvHeaderColorForSelfTest(1)
            else { return "hàng tiêu đề không có màu cột" }
            guard h0 != h1 else { return "hai cột đầu của hàng tiêu đề trùng màu" }
            guard h0 == Tokens.Color.rainbow(0), h1 == Tokens.Color.rainbow(1) else {
                return "màu hàng tiêu đề không khớp bảng màu cột"
            }

            controller.scrollToForSelfTest(0)
            controller.flushDrawingForSelfTest()
            guard !controller.csvHeaderVisibleForSelfTest else {
                return "cuộn về đầu file mà hàng tiêu đề vẫn dính"
            }
            controller.setCSVModeForSelfTest(false)
            return nil
        },

        Case(name: "tắt chế độ CSV thì hàng tiêu đề biến mất") { controller in
            var source = "a,b,c\n"
            for index in 0 ..< 2_000 { source += "\(index),x,y\n" }
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.scrollToForSelfTest(source.utf8.count / 2)
            controller.flushDrawingForSelfTest()
            guard controller.csvHeaderVisibleForSelfTest else { return "chưa hiện được để mà tắt" }

            controller.setCSVModeForSelfTest(false)
            controller.flushDrawingForSelfTest()
            guard !controller.csvHeaderVisibleForSelfTest else {
                return "tắt chế độ CSV mà hàng tiêu đề còn nằm lại"
            }
            return nil
        },

        Case(name: "chế độ CSV nói ra DẤU PHÂN TÁCH đã nhận diện") { controller in
            // Nhận nhầm delimiter là lỗi im lặng nhất của cả nhóm CSV: mọi thao tác cột sau
            // đó đều sai và người dùng không có cách nào biết. Nên nó phải hiện ra.
            controller.prepareSelfTestDocument("ten;tuoi;thanh_pho\nAn;30;Ha Noi\nBinh;25;Hue\n")
            controller.setCSVModeForSelfTest(true)
            guard controller.csvDialectForSelfTest == .semicolon else {
                return "nhận ra dấu «\(controller.csvDialectForSelfTest.displayName)», mong đợi chấm phẩy"
            }
            guard controller.statusModeForSelfTest == "CSV · chấm phẩy" else {
                return "thanh trạng thái ghi «\(controller.statusModeForSelfTest ?? "nil")»"
            }
            controller.setCSVModeForSelfTest(false)
            guard controller.statusModeForSelfTest != "CSV · chấm phẩy" else {
                return "tắt chế độ CSV mà thanh trạng thái vẫn ghi CSV"
            }
            return nil
        },

        // NFR-USE-05, vế MỘT: công tắc chữ ghép.
        //
        // Vế dễ hỏng nhất không phải "bật có ăn không" mà là **chữ nạp từ tệp có ăn không**:
        // mỗi lần cuộn ra ngoài cửa sổ hiện tại, cả chuỗi trong view bị thay, và thuộc tính của
        // cửa sổ trước mất sạch. Một công tắc chỉ ăn với chữ vừa gõ là công tắc hỏng theo kiểu
        // không ai báo cáo được: người dùng bật nó, thấy đúng, cuộn một cái là hết.
        Case(name: "chữ ghép: công tắc ăn cả chữ đang hiện lẫn chữ sắp gõ, và sống qua lượt cuộn") {
            controller in
            // Tài liệu phải VƯỢT 2 MB — cỡ một cửa sổ chữ (`TextWindow.defaultSize`). Bản đầu
            // của bài này dùng 400 dòng, và nhát bẻ «nạp cửa sổ không đặt lại chữ ghép» ĐI LỌT:
            // cả tài liệu lọt trong một cửa sổ nên chẳng có lượt nạp lại nào để mà hỏng.
            controller.prepareSelfTestDocument(String(repeating: "office fi fl -> != data\n",
                                                      count: 120_000))
            var settings = controller.settings
            let before = settings.ligatures
            defer {
                settings.ligatures = before
                controller.applySettings(settings, persist: false)
            }

            settings.ligatures = true
            controller.applySettings(settings, persist: false)
            guard controller.editorView.ligatureInStorageForSelfTest == 1 else {
                return "bật mà chữ đang hiện vẫn mang "
                    + "\(String(describing: controller.editorView.ligatureInStorageForSelfTest))"
            }
            guard controller.editorView.ligatureWhenTypingForSelfTest == 1 else {
                return "bật mà chữ SẮP GÕ không mang thuộc tính chữ ghép"
            }

            // Cuộn xa để ép nạp lại cửa sổ — chỗ chuỗi trong view bị thay hẳn.
            controller.editorView.repaginate(around: controller.editorDocument.buffer.count - 1)
            controller.editorView.reveal(documentOffset: controller.editorDocument.buffer.count - 1)
            controller.editorView.layoutSubtreeIfNeeded()
            guard controller.editorView.ligatureInStorageForSelfTest == 1 else {
                return "cuộn một cái là mất chữ ghép — thuộc tính không được đặt lại khi nạp "
                    + "cửa sổ mới"
            }

            settings.ligatures = false
            controller.applySettings(settings, persist: false)
            guard controller.editorView.ligatureInStorageForSelfTest == 0,
                  controller.editorView.ligatureWhenTypingForSelfTest == 0 else {
                return "tắt mà thuộc tính không về 0"
            }
            return nil
        },

        // NFR-USE-05, vế HAI: *"render đúng emoji · ký tự tổ hợp · chữ có dấu ở MỌI mức zoom"*.
        //
        // Mục này trong bảng trạng thái ghi ⛔ kèm đúng câu «chưa có bài đo nào» — và đây là
        // sản phẩm bán cho người gõ tiếng Việt, tức chữ có dấu là ca THƯỜNG, không phải ca lạ.
        //
        // Bài đo VẼ THẬT ra bitmap rồi đếm điểm ảnh có mực, ở cả bốn mức cỡ chữ mà sản phẩm cho
        // phép. Hỏi AppKit "chuỗi này rộng bao nhiêu" thì không trả lời được câu hỏi thật: một
        // ô vuông .notdef cũng có bề rộng.
        Case(name: "hiển thị: chữ có dấu · ký tự tổ hợp · emoji vẽ ra mực ở mọi cỡ chữ") { _ in
            /// Số điểm ảnh có mực, và có điểm ảnh MÀU nào không.
            func ink(_ text: String, size: CGFloat) -> (pixels: Int, coloured: Bool) {
                let font = Tokens.Font.editor(size: size)
                let string = NSAttributedString(
                    string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
                let bounds = string.size()
                let width = max(8, Int(bounds.width.rounded(.up)) + 4)
                let height = max(8, Int(bounds.height.rounded(.up)) + 4)
                guard let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                    let context = NSGraphicsContext(bitmapImageRep: rep)
                else { return (0, false) }

                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                NSColor.white.setFill()
                NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)).fill()
                string.draw(at: NSPoint(x: 2, y: 2))
                NSGraphicsContext.restoreGraphicsState()

                var pixels = 0
                var coloured = false
                for y in 0 ..< height {
                    for x in 0 ..< width {
                        guard let colour = rep.colorAt(x: x, y: y) else { continue }
                        let red = colour.redComponent, green = colour.greenComponent
                        let blue = colour.blueComponent
                        // Nền trắng: bất kỳ điểm nào tối đi là mực.
                        if red < 0.9 || green < 0.9 || blue < 0.9 { pixels += 1 }
                        // Emoji vẽ bằng font MÀU. Một ô .notdef thì đen trắng.
                        if abs(red - green) > 0.15 || abs(green - blue) > 0.15 { coloured = true }
                    }
                }
                return (pixels, coloured)
            }

            let sizes: [CGFloat] = [8, 13, 20, 32]
            for size in sizes {
                // Chữ có dấu, kể cả dấu chồng hai tầng — thứ tiếng Việt có mà phần lớn ngôn ngữ
                // khác không.
                let vietnamese = ink("Tiếng Việt: ế ữ ằ ỗ ợ", size: size)
                guard vietnamese.pixels > 20 else {
                    return "cỡ \(Int(size))pt: chữ tiếng Việt chỉ vẽ ra \(vietnamese.pixels) "
                        + "điểm mực"
                }

                // Ký tự TỔ HỢP: cùng một chữ «ế» viết bằng NFC và bằng NFD phải ra gần như cùng
                // một lượng mực. Lệch nhiều nghĩa là bản NFD vẽ thành hai hình rời hoặc thành ô
                // vuông thiếu glyph — đúng thứ hỏng mà người dùng dán chữ từ macOS Finder gặp
                // phải, vì tên tệp trên APFS là NFD.
                let nfc = ink("ế", size: size).pixels
                let nfd = ink("e\u{0302}\u{0301}", size: size).pixels
                guard nfc > 0, nfd > 0 else {
                    return "cỡ \(Int(size))pt: NFC \(nfc) · NFD \(nfd) điểm mực — có bản không vẽ"
                }
                let lech = Double(abs(nfc - nfd)) / Double(max(nfc, nfd))
                guard lech < 0.5 else {
                    return "cỡ \(Int(size))pt: NFC và NFD lệch \(Int(lech * 100))% lượng mực — "
                        + "gần như chắc chắn bản tổ hợp không được dựng thành một chữ"
                }

                // Emoji phải ra MÀU. Ô vuông thiếu glyph vẫn có mực, nên phép đếm mực một mình
                // không phân biệt được — chính là chỗ một bài kiểm dễ xanh giả.
                let emoji = ink("🙂", size: size)
                guard emoji.pixels > 10 else {
                    return "cỡ \(Int(size))pt: emoji không vẽ ra gì"
                }
                guard emoji.coloured else {
                    return "cỡ \(Int(size))pt: emoji vẽ ra ĐEN TRẮNG — gần như chắc chắn là ô "
                        + "vuông thiếu glyph chứ không phải emoji"
                }
            }
            return nil
        },

        // NFR-REL-03 — báo cáo sự cố opt-in.
        //
        // Vế nặng nhất KHÔNG phải "có ghi được báo cáo không" mà là **"báo cáo có sạch không"**:
        // chỉ tiêu viết *"gửi kèm ngữ cảnh tối thiểu, KHÔNG kèm nội dung tài liệu"*. Người dùng
        // sản phẩm này mở hợp đồng, bảng lương, dữ liệu dân cư — một báo cáo mang theo vài dòng
        // của tệp đang mở là một sự cố thứ hai, và là loại không ai phát hiện được.
        //
        // Bài mở một tài liệu chứa chuỗi bí mật VÀ đặt tên tệp mang chuỗi ấy, rồi soi báo cáo:
        // đường dẫn cũng là dữ liệu (`/Users/an/Desktop/luong-thang-12.xlsx` nói ra ba điều
        // riêng tư trước khi ai kịp mở nó).
        Case(name: "báo cáo sự cố: không chứa nội dung lẫn đường dẫn tài liệu, và người dùng tự quyết") { controller in
            let secret = "BIMAT-KHONG-DUOC-RO-RI-9F3A"
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("crash-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("\(secret).txt")
            try? Data("nội dung mật: \(secret)\n".utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            CrashReporter.discardReports()
            guard CrashReporter.pendingNotice() == nil else {
                return "chưa có sự cố nào mà đã có câu nhắc"
            }

            guard let report = CrashReporter.writeReportForSelfTest(reason: "bài tự kiểm") else {
                return "không ghi được báo cáo sự cố"
            }
            defer { CrashReporter.discardReports() }
            guard let text = try? String(contentsOf: report, encoding: .utf8) else {
                return "báo cáo ghi ra không đọc lại được"
            }

            // ── Vế MỘT: sạch.
            guard !text.contains(secret) else {
                return "báo cáo CHỨA nội dung hoặc đường dẫn tài liệu đang mở"
            }
            // ── Vế HAI: vẫn đủ dùng. Một báo cáo sạch mà rỗng nghĩa thì không ai sửa được gì.
            guard text.contains("GEditor"), text.contains("macOS:") else {
                return "báo cáo thiếu ngữ cảnh tối thiểu: «\(text.prefix(60))»"
            }
            guard text.contains("Kiến trúc:") else { return "báo cáo không nói kiến trúc máy" }
            guard text.count > 200 else {
                return "báo cáo chỉ \(text.count) ký tự — thiếu ngăn xếp lời gọi"
            }

            // ── Vế BA: người dùng tự quyết, và app NÓI RA rằng nó có.
            guard let notice = CrashReporter.pendingNotice() else {
                return "có báo cáo mà lần chạy sau không nhắc gì"
            }
            guard notice.contains("không có gì được gửi đi") else {
                return "câu nhắc không nói ra rằng KHÔNG có đường gửi: «\(notice)»"
            }

            // Mở báo cáo là một TAB — sản phẩm này là trình soạn thảo, đọc nó ở đây là tự nhiên.
            let tabsBefore = controller.tabCountForSelfTest
            controller.openCrashReport(nil)
            guard controller.tabCountForSelfTest == tabsBefore + 1 else {
                return "bấm «Mở báo cáo» mà không ra tab mới"
            }
            guard controller.documentTextForSelfTest.contains("macOS:") else {
                return "tab mới không phải báo cáo sự cố"
            }
            // Đã đưa cho người dùng rồi thì lần khởi động sau không nhắc lại.
            guard CrashReporter.pendingNotice() == nil else {
                return "mở báo cáo xong mà nó vẫn nằm trong hàng chờ"
            }
            return nil
        },

        Case(name: "xóa lùi trên nhiều caret") { controller in
            controller.prepareSelfTestDocument("ab\nab\n")
            controller.selectAllOccurrencesForSelfTest("b")
            controller.deleteBackwardForSelfTest()
            return expect(controller, "a\na\n")
        },

        // MARK: - Table view (FR-CSV-403)

        Case(name: "bảng lấy tên cột từ hàng tiêu đề và không hiện hàng ấy thành dữ liệu") { controller in
            controller.prepareSelfTestDocument("ma,ten,tien\nA1,Cam,3\nA2,An,1\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            guard controller.isTableViewVisibleForSelfTest else { return "bảng không hiện ra" }
            guard controller.csvTable.columnTitlesForSelfTest == ["ma", "ten", "tien"] else {
                return "tên cột: \(controller.csvTable.columnTitlesForSelfTest)"
            }
            guard controller.csvTable.rowCountForSelfTest == 2 else {
                return "bảng có \(controller.csvTable.rowCountForSelfTest) hàng, mong đợi 2 (tiêu đề không tính)"
            }
            guard controller.csvTable.valuesForSelfTest(displayRow: 0) == ["A1", "Cam", "3"] else {
                return "hàng đầu: \(controller.csvTable.valuesForSelfTest(displayRow: 0))"
            }
            return nil
        },

        // ⌘C khi BẢNG đang che vùng soạn thảo. Cùng mẫu lỗi với cây cấu trúc và với sơ đồ chiếm
        // trọn tab: lệnh chung tác động lên thứ đang bị che, nên người dùng chép ra được một
        // đoạn văn bản họ không nhìn thấy và không có gì báo là đã chép nhầm.
        Case(name: "bảng CSV: ⌘C chép HÀNG đang chọn, ô có dấu phẩy vẫn nguyên vẹn") { controller in
            // Ô «Cam, quýt» chứa đúng dấu phân tách của tệp — nếu phép chép nối chuỗi bằng tay
            // thì chỗ dán sẽ tách nó thành hai ô, im lặng.
            controller.prepareSelfTestDocument("ma,ten,tien\nA1,\"Cam, quýt\",3\nA2,An,1\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }
            guard controller.isTableViewVisibleForSelfTest else { return "bảng không hiện ra" }

            controller.csvTable.selectDisplayRowForSelfTest(0)
            NSPasteboard.general.clearContents()
            controller.copySelection(nil)
            let copied = NSPasteboard.general.string(forType: .string) ?? ""
            guard copied == "A1\tCam, quýt\t3" else {
                return "⌘C trên bảng chép «\(copied)» — mong «A1⇥Cam, quýt⇥3»; nếu ra văn bản "
                    + "thô của tệp thì nó vừa chép vùng soạn thảo đang bị che"
            }

            // Ô chứa chính TAB thì phải được bọc, không thì chỗ dán tách nó làm đôi.
            //
            // Tắt bảng TRƯỚC khi đổi tài liệu: `showTableViewForSelfTest` không làm gì khi bảng
            // đang hiện, nên nếu để nguyên thì phần dưới đây chép lại hàng của tài liệu TRƯỚC —
            // và bài kiểm sẽ nói về một thứ nó không hề dựng ra. Đã gặp thật ở đúng chỗ này.
            controller.showTextViewForSelfTest()
            controller.prepareSelfTestDocument("a,b\n\"x\ty\",2\n")
            controller.showTableViewForSelfTest()
            guard controller.csvTable.valuesForSelfTest(displayRow: 0) == ["x\ty", "2"] else {
                return "bảng chưa đọc tài liệu mới: "
                    + "\(controller.csvTable.valuesForSelfTest(displayRow: 0))"
            }
            controller.csvTable.selectDisplayRowForSelfTest(0)
            NSPasteboard.general.clearContents()
            controller.copySelection(nil)
            let quoted = NSPasteboard.general.string(forType: .string) ?? ""
            guard quoted == "\"x\ty\"\t2" else {
                return "ô chứa TAB không được bọc: «\(quoted)»"
            }
            return nil
        },

        Case(name: "bảng dựng theo hàng RỘNG NHẤT, không theo hàng tiêu đề") { controller in
            // Hàng thừa cột mà bảng chỉ có số cột của tiêu đề thì phần thừa BIẾN MẤT khỏi màn
            // hình — và thứ người dùng không nhìn thấy là thứ họ sẽ vô tình xoá.
            controller.prepareSelfTestDocument("a,b\n1,2\n3,4,5,6\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            guard controller.csvTable.columnCountForSelfTest == 4 else {
                return "bảng có \(controller.csvTable.columnCountForSelfTest) cột, mong đợi 4"
            }
            guard controller.csvTable.valuesForSelfTest(displayRow: 1) == ["3", "4", "5", "6"] else {
                return "hàng thừa cột đọc ra: \(controller.csvTable.valuesForSelfTest(displayRow: 1))"
            }
            return nil
        },

        Case(name: "chuyển Văn bản → Bảng giữ nguyên hàng đang đứng") { controller in
            var text = "ma,ten\n"
            for row in 1 ... 500 { text += "M\(row),Ten \(row)\n" }
            controller.prepareSelfTestDocument(text)

            // Đứng ở hàng 300 (hàng file 300, vì hàng 0 là tiêu đề).
            let buffer = controller.editorDocument.buffer
            controller.setCaretForSelfTest(documentOffset: buffer.offset(ofLineStart: 300) + 3)
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            guard let selected = controller.csvTable.selectedFileRowForSelfTest else {
                return "bảng không chọn hàng nào"
            }
            guard selected == 300 else { return "bảng chọn hàng \(selected), mong đợi 300" }
            guard controller.csvTable.valuesForSelfTest(displayRow: 299) == ["M300", "Ten 300"] else {
                return "hàng ấy đọc ra: \(controller.csvTable.valuesForSelfTest(displayRow: 299))"
            }
            return nil
        },

        Case(name: "chuyển Bảng → Văn bản đưa con nháy về đầu hàng đang chọn") { controller in
            var text = "ma,ten\n"
            for row in 1 ... 500 { text += "M\(row),Ten \(row)\n" }
            controller.prepareSelfTestDocument(text)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.showTableViewForSelfTest()
            controller.csvTable.select(fileRow: 400)
            controller.showTextViewForSelfTest()

            let buffer = controller.editorDocument.buffer
            let caret = controller.caretOffsetForSelfTest
            let expected = buffer.offset(ofLineStart: 400)
            guard caret == expected else {
                return "con nháy ở \(caret), mong đợi \(expected) (đầu hàng 400)"
            }
            return nil
        },

        Case(name: "sắp xếp hiển thị KHÔNG đụng một byte nào của văn bản") { controller in
            // Bất biến quan trọng nhất của FR-CSV-403 (NT-5): bấm tiêu đề để NHÌN, không phải
            // để sửa. Gộp hai việc là cách phá dữ liệu ngoài ý muốn.
            let source = "ma,ten\nA,Cam\nB,An\nC,Bưởi\n"
            controller.prepareSelfTestDocument(source)
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            let depthBefore = controller.editorDocument.buffer.undoDepth
            controller.csvTable.clickHeaderForSelfTest(1)
            controller.csvTable.waitForSortForSelfTest()

            guard controller.csvTable.valuesForSelfTest(displayRow: 0) == ["B", "An"] else {
                return "sau khi sắp, hàng đầu là \(controller.csvTable.valuesForSelfTest(displayRow: 0))"
            }
            guard controller.editorDocument.buffer.text == source else {
                return "văn bản ĐÃ ĐỔI: \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            guard controller.editorDocument.buffer.undoDepth == depthBefore else {
                return "sắp xếp hiển thị sinh thêm bước undo"
            }
            guard controller.csvTable.sortLabelForSelfTest.contains("chỉ hiển thị") else {
                return "nhãn không nói rõ «chỉ hiển thị»: «\(controller.csvTable.sortLabelForSelfTest)»"
            }
            return nil
        },

        Case(name: "sắp xếp xong vẫn giữ đúng hàng đang chọn") { controller in
            // Mất lựa chọn khi sắp xếp thì người dùng đang xem một bản ghi cụ thể sẽ mất dấu
            // nó — và lúc quay về chế độ văn bản, con nháy không còn chỗ nào để về.
            controller.prepareSelfTestDocument("ma,ten\nA,Cam\nB,An\nC,Bưởi\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            controller.csvTable.select(fileRow: 3)          // hàng "C,Bưởi"
            controller.csvTable.clickHeaderForSelfTest(1)
            controller.csvTable.waitForSortForSelfTest()

            guard controller.csvTable.selectedFileRowForSelfTest == 3 else {
                return "sau khi sắp, đang chọn hàng \(String(describing: controller.csvTable.selectedFileRowForSelfTest)), mong đợi 3"
            }
            return nil
        },

        Case(name: "cột # hiện số hàng TRONG FILE, không phải vị trí trong bảng") { controller in
            // Đang sắp xếp hiển thị thì số hàng nhảy cóc — và đó chính là điều cần cho người
            // dùng thấy: hàng vẫn nằm nguyên chỗ cũ trong file.
            controller.prepareSelfTestDocument("ma,ten\nA,Cam\nB,An\nC,Bưởi\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            controller.csvTable.clickHeaderForSelfTest(1)
            controller.csvTable.waitForSortForSelfTest()
            guard controller.csvTable.fileRowForSelfTest(displayRow: 0) == 2 else {
                return "hàng đầu bảng ứng với hàng file \(String(describing: controller.csvTable.fileRowForSelfTest(displayRow: 0))), mong đợi 2"
            }
            return nil
        },

        Case(name: "áp sắp xếp vào file là MỘT bước undo") { controller in
            let source = "ma,ten\nA,Cam\nB,An\nC,Bưởi\n"
            controller.prepareSelfTestDocument(source)
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            controller.csvTable.clickHeaderForSelfTest(1)
            controller.csvTable.waitForSortForSelfTest()
            guard controller.csvTable.applyButtonVisibleForSelfTest else {
                return "chưa hiện nút «Áp sắp xếp vào file»"
            }

            let buffer = controller.editorDocument.buffer
            let depth = buffer.undoDepth
            controller.csvTable.applySortForSelfTest()

            guard buffer.text == "ma,ten\nB,An\nC,Bưởi\nA,Cam\n" else {
                return "văn bản sau khi ghi: \(String(reflecting: buffer.text))"
            }
            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth), phải chỉ tăng 1"
            }
            _ = buffer.undo()
            return buffer.text == source ? nil : "một lần undo không về nguyên trạng"
        },

        // MARK: - Thao tác cột trên hàng tiêu đề (FR-CSV-404/408)

        Case(name: "ẩn cột: biến khỏi bảng nhưng còn NGUYÊN trong file") { controller in
            // Trộn "ẩn" với "xóa" là cách mất dữ liệu nhanh nhất. Bài này chốt rằng ẩn không
            // đụng một byte nào của văn bản.
            let source = "ma,ten,tien\nA,Cam,3\nB,An,1\n"
            controller.prepareSelfTestDocument(source)
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            let depth = controller.editorDocument.buffer.undoDepth
            controller.csvTable.hideColumnForSelfTest(1)

            guard controller.csvTable.columnTitlesForSelfTest == ["ma", "tien"] else {
                return "cột còn lại: \(controller.csvTable.columnTitlesForSelfTest)"
            }
            guard controller.editorDocument.buffer.text == source else {
                return "văn bản ĐÃ ĐỔI: \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            guard controller.editorDocument.buffer.undoDepth == depth else {
                return "ẩn cột sinh thêm bước undo"
            }
            // Và phải có dòng nhắc — cột biến mất không lời nào thì người dùng sẽ tin là file
            // không có cột ấy.
            guard controller.csvTable.hiddenNoteForSelfTest.contains("ten") else {
                return "không nhắc cột nào đang ẩn: «\(controller.csvTable.hiddenNoteForSelfTest)»"
            }

            // Và bảng phải NHƯỜNG CHỖ cho dòng nhắc. Ảnh chụp cho thấy bản đầu ghim cả hai
            // vào đáy khung, nên dòng nhắc vẽ đè lên hàng cuối của bảng.
            guard controller.csvTable.tableBottomGapForSelfTest > 1 else {
                return "bảng chạy xuống hết khung, dòng nhắc sẽ vẽ đè lên hàng cuối"
            }

            controller.csvTable.showColumnForSelfTest(1)
            guard controller.csvTable.columnTitlesForSelfTest == ["ma", "ten", "tien"] else {
                return "hiện lại rồi mà cột là: \(controller.csvTable.columnTitlesForSelfTest)"
            }
            guard controller.csvTable.hiddenNoteForSelfTest.isEmpty else {
                return "hết cột ẩn mà dòng nhắc còn nằm lại"
            }
            guard controller.csvTable.tableBottomGapForSelfTest < 1 else {
                return "hết cột ẩn mà bảng vẫn chừa chỗ trống dưới đáy"
            }
            return nil
        },

        Case(name: "không cho ẩn cột cuối cùng đang hiện") { controller in
            // Bảng không còn cột nào thì không còn chỗ nào bấm chuột phải để hiện lại.
            controller.prepareSelfTestDocument("a,b\n1,2\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            controller.csvTable.hideColumnForSelfTest(0)
            controller.csvTable.hideColumnForSelfTest(1)
            guard controller.csvTable.columnCountForSelfTest >= 1 else {
                return "đã ẩn hết cột, không còn đường quay lại"
            }
            return nil
        },

        Case(name: "menu tiêu đề nói rõ đang thao tác trên cột nào") { controller in
            // Menu chung cho cả hàng tiêu đề là cái bẫy: "Xóa cột này" sẽ xóa nhầm cột.
            controller.prepareSelfTestDocument("ma,ho_ten,tien\nA,Cam,3\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            let titles = controller.csvTable.headerMenuTitlesForSelfTest(1)
            guard titles.first == "Cột 2: ho_ten" else {
                return "mục đầu menu: «\(titles.first ?? "")»"
            }
            for wanted in ["Ẩn cột này", "Đổi tên tiêu đề…", "Chèn cột trống bên trái",
                           "Chèn cột trống bên phải", "Xóa cột này khỏi file…"] {
                guard titles.contains(wanted) else { return "menu thiếu «\(wanted)»" }
            }
            return nil
        },

        Case(name: "chèn cột trống bên phải: một bước undo, bảng thấy cột mới") { controller in
            let source = "ma,ten\nA,Cam\n"
            controller.prepareSelfTestDocument(source)
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            let buffer = controller.editorDocument.buffer
            let depth = buffer.undoDepth
            controller.runColumnCommandForSelfTest(.insertRight(0))

            guard buffer.text == "ma,,ten\nA,,Cam\n" else {
                return "văn bản: \(String(reflecting: buffer.text))"
            }
            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth), phải chỉ tăng 1"
            }
            guard controller.csvTable.columnCountForSelfTest == 3 else {
                return "bảng có \(controller.csvTable.columnCountForSelfTest) cột, mong đợi 3"
            }
            _ = buffer.undo()
            return buffer.text == source ? nil : "một lần undo không về nguyên trạng"
        },

        Case(name: "kéo tiêu đề hoán vị cột TRONG FILE, kể cả khi kéo sang phải") { controller in
            // Kéo sang phải là chỗ mà cách suy ra hoán vị bằng "so hai danh sách thứ tự" cho
            // kết quả sai hẳn. Bài này đi đúng đường mà AppKit gọi tới.
            controller.prepareSelfTestDocument("a,b,c\n1,2,3\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            // Cột "#" là 0, nên cột dữ liệu đầu tiên là 1: kéo nó tới cuối.
            controller.csvTable.simulateColumnDragForSelfTest(fromVisible: 1, toVisible: 3)
            guard controller.editorDocument.buffer.text == "b,c,a\n2,3,1\n" else {
                return "văn bản: \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            guard controller.csvTable.columnTitlesForSelfTest == ["b", "c", "a"] else {
                return "bảng dựng lại thành: \(controller.csvTable.columnTitlesForSelfTest)"
            }
            return nil
        },

        Case(name: "đang ẩn cột thì KHÓA kéo tiêu đề") { controller in
            // Lúc có cột ẩn, vị trí trên màn hình không còn dịch được sang chỉ số cột logic.
            // Khóa hẳn còn hơn đoán — đoán sai ở đây là hoán vị nhầm cột trong cả file.
            controller.prepareSelfTestDocument("a,b,c\n1,2,3\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            guard controller.csvTable.reorderAllowedForSelfTest else {
                return "chưa ẩn cột nào mà đã khóa kéo tiêu đề"
            }
            controller.csvTable.hideColumnForSelfTest(1)
            guard !controller.csvTable.reorderAllowedForSelfTest else {
                return "đang ẩn cột mà vẫn cho kéo tiêu đề"
            }
            controller.csvTable.showColumnForSelfTest(1)
            guard controller.csvTable.reorderAllowedForSelfTest else {
                return "hiện lại hết rồi mà vẫn khóa"
            }
            return nil
        },

        // MARK: - Kiểm tra dữ liệu (FR-CSV-405)

        Case(name: "kiểm tra dữ liệu bắt được ô sai kiểu và nói rõ kiểu suy ra") { controller in
            var text = "ma,tien\n"
            for row in 1 ... 40 { text += "KH\(row),\(row * 100)\n" }
            text += "KH41,chưa thu\n"
            controller.prepareSelfTestDocument(text)
            controller.setCSVModeForSelfTest(true)
            controller.validateForSelfTest()
            defer { controller.closeValidationPanelForSelfTest() }

            guard controller.validationPanelVisibleForSelfTest else { return "panel không hiện" }
            guard controller.validationPanel.issueCountForSelfTest == 1 else {
                return "tìm được \(controller.validationPanel.issueCountForSelfTest) lỗi, mong đợi 1"
            }
            guard let issue = controller.validationPanel.issueForSelfTest(0) else {
                return "không đọc được lỗi"
            }
            guard issue.rowIndex == 41 else { return "lỗi ở hàng \(issue.rowIndex), mong đợi 41" }
            guard case .wrongType(1, .number, "chưa thu") = issue.kind else {
                return "loại lỗi: \(issue.kind)"
            }
            // Kiểu suy ra được phải hiện lên: không có nó thì lỗi trông như tùy tiện.
            guard controller.validationPanel.summaryForSelfTest.contains("tien: số") else {
                return "tóm tắt không nói kiểu: «\(controller.validationPanel.summaryForSelfTest)»"
            }
            return nil
        },

        Case(name: "file sạch thì nói rõ là KHÔNG có lỗi") { controller in
            // Im lặng khi không có lỗi là tệ nhất: người dùng không biết đã kiểm hay chưa.
            var text = "ma,tien\n"
            for row in 1 ... 40 { text += "KH\(row),\(row * 100)\n" }
            controller.prepareSelfTestDocument(text)
            controller.setCSVModeForSelfTest(true)
            controller.validateForSelfTest()
            defer { controller.closeValidationPanelForSelfTest() }

            guard controller.validationPanel.issueCountForSelfTest == 0 else {
                return "báo nhầm \(controller.validationPanel.issueCountForSelfTest) lỗi"
            }
            guard controller.validationPanel.summaryForSelfTest.contains("Không tìm thấy lỗi") else {
                return "tóm tắt: «\(controller.validationPanel.summaryForSelfTest)»"
            }
            return nil
        },

        Case(name: "bấm vào một lỗi thì nhảy tới đúng hàng ở chế độ văn bản") { controller in
            var text = "ma,tien\n"
            for row in 1 ... 40 { text += "KH\(row),\(row * 100)\n" }
            text += "KH41,chưa thu\n"
            controller.prepareSelfTestDocument(text)
            controller.setCSVModeForSelfTest(true)
            controller.setCaretForSelfTest(documentOffset: 0)
            controller.validateForSelfTest()
            defer { controller.closeValidationPanelForSelfTest() }

            controller.validationPanel.clickIssueForSelfTest(0)
            let buffer = controller.editorDocument.buffer
            let expected = buffer.offset(ofLineStart: 41)
            guard controller.caretOffsetForSelfTest == expected else {
                return "con nháy ở \(controller.caretOffsetForSelfTest), mong đợi \(expected)"
            }
            return nil
        },

        Case(name: "đóng panel thì xoá luôn màu đỏ trên bảng") { controller in
            // Màu đỏ nằm lại sau khi đóng panel là nói dối: nó khẳng định một kết quả kiểm tra
            // mà người dùng đã bỏ đi, và tài liệu có thể đã sửa từ lúc ấy.
            var text = "ma,tien\n"
            for row in 1 ... 40 { text += "KH\(row),\(row * 100)\n" }
            text += "KH41,chưa thu\n"
            controller.prepareSelfTestDocument(text)
            controller.setCSVModeForSelfTest(true)
            controller.validateForSelfTest()

            guard controller.csvTypeIssueRowsForSelfTest == [41] else {
                return "hàng bị tô đỏ: \(controller.csvTypeIssueRowsForSelfTest.sorted())"
            }
            controller.closeValidationPanelForSelfTest()
            guard controller.csvTypeIssueRowsForSelfTest.isEmpty else {
                return "đóng panel rồi mà màu đỏ còn nằm lại"
            }
            guard !controller.validationPanelVisibleForSelfTest else { return "panel không đóng" }
            return nil
        },

        // MARK: - Chuyển đổi định dạng (FR-CSV-406)

        Case(name: "xem trước đi qua ĐÚNG hàm sinh ra bản thật") { controller in
            // Viết riêng một hàm rút gọn cho ô xem trước là cách chắc chắn để nó nói dối đúng
            // vào lúc người dùng tin nó.
            //
            // Bản đầu của bài này chỉ kiểm "xem trước là TIỀN TỐ của bản đầy đủ" trên định
            // dạng SQL — và đối chứng âm cho thấy nó VÔ DỤNG: cắt năm dòng đầu của bản đầy đủ
            // cũng thỏa, vì mỗi câu INSERT đúng một dòng. Phải kiểm ở những định dạng mà cắt
            // dòng cho ra thứ KHÁC HẲN.
            var text = "ma,ten\n"
            for row in 1 ... 40 { text += "KH\(row),Tên \(row)\n" }
            controller.prepareSelfTestDocument(text)
            controller.setCSVModeForSelfTest(true)

            let sheet = controller.makeConvertSheetForSelfTest()
            sheet.loadViewForSelfTest()

            // Markdown: hàm thật cho tiêu đề + gạch + 5 hàng = 7 dòng. Cắt 5 dòng đầu chỉ được
            // 3 hàng dữ liệu.
            sheet.selectFormatForSelfTest(.markdown)
            let markdown = sheet.previewTextForSelfTest.split(separator: "\n")
            guard markdown.count == 7 else {
                return "Markdown xem trước có \(markdown.count) dòng, mong đợi 7"
            }
            guard markdown.filter({ $0.hasPrefix("| KH") }).count == 5 else {
                return "Markdown xem trước có \(markdown.filter { $0.hasPrefix("| KH") }.count) hàng dữ liệu"
            }

            // JSON: hàm thật ĐÓNG mảng lại. Cắt dòng cho ra JSON hỏng.
            sheet.selectFormatForSelfTest(.json)
            let json = sheet.previewTextForSelfTest
            guard json.hasSuffix("]") else {
                return "JSON xem trước không đóng mảng: …\(json.suffix(30))"
            }
            guard (try? JSONSerialization.jsonObject(
                with: Data(json.utf8)
            )) != nil else { return "JSON xem trước KHÔNG hợp lệ" }

            // XML: hàm thật đóng thẻ gốc.
            sheet.selectFormatForSelfTest(.xml)
            guard sheet.previewTextForSelfTest.hasSuffix("</bang>\n") else {
                return "XML xem trước không đóng thẻ gốc"
            }
            return nil
        },

        Case(name: "chuyển đổi tạo TAB MỚI, tài liệu gốc không đụng tới") { controller in
            let source = "ma,ten\nA1,Cam\nA2,An\n"
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)

            let tabsBefore = controller.tabPathsForSelfTest.count
            controller.convertForSelfTest(.markdown)

            guard controller.tabPathsForSelfTest.count == tabsBefore + 1 else {
                return "số tab: \(tabsBefore) → \(controller.tabPathsForSelfTest.count)"
            }
            guard controller.editorDocument.buffer.text.contains("| A1 | Cam |") else {
                return "tab mới chứa: \(controller.editorDocument.buffer.text.prefix(60))"
            }
            // Tab GỐC phải còn nguyên — chuyển đổi là tạo bản mới, không phải sửa bản cũ.
            guard controller.tabTextsForSelfTest.contains(source) else {
                return "tài liệu gốc đã bị đổi"
            }
            return nil
        },

        Case(name: "ô xem trước KHÔNG ngắt dòng: năm hàng là năm dòng vẽ") { controller in
            // Bài này đếm mực trên bitmap của ô xem trước, không hỏi AppKit về dự định bố trí.
            // Bản trước đây hỏi, và nó xanh trong khi ứng dụng thật ngắt dòng — vì phép hỏi tự
            // nó đã đổi bộ máy bố trí trước khi đo.
            //
            // Chữ để ASCII: dấu tiếng Việt vươn cao có thể làm hai dải mực dính nhau.
            // Hàng phải DÀI hơn bề ngang khung xem trước, nếu không thì cấu hình hỏng cũ cũng
            // chẳng ngắt dòng và bước đo lại cái thước ở dưới không nói được gì.
            var source = "ma,ten,dia_chi\n"
            for i in 1...4 {
                source += "A\(i),Nguyen Van Mot Hai Ba Bon Nam Sau Bay Tam Chin Muoi,"
                source += "So 123 Duong Rat Dai Ngoac Ngoeo Quan Mot Thanh Pho Ho Chi Minh Viet Nam\n"
            }
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            let sheet = controller.makeConvertSheetForSelfTest()
            sheet.loadViewForSelfTest()
            sheet.selectFormatForSelfTest(.tsv)

            let expected = sheet.previewTextForSelfTest
                .split(separator: "\n", omittingEmptySubsequences: true).count
            let drawn = sheet.drawnPreviewLineCountForSelfTest()
            guard drawn == expected else { return "chuỗi=\(expected) dòng, vẽ=\(drawn) dòng" }

            // Không ngắt dòng thì phần vượt ra ngoài khung phải CUỘN tới được. Cắt chữ mà không
            // cho cuộn thì còn tệ hơn ngắt dòng: người dùng không có cách nào đọc phần cuối.
            let needed = sheet.previewNeededWidthForSelfTest
            guard needed > sheet.previewVisibleWidthForSelfTest else {
                return "dòng thử chỉ cần \(needed)pt, không vượt khung — bài kiểm không nói gì"
            }
            guard sheet.previewScrollableWidthForSelfTest >= needed else {
                return "cần \(needed)pt mà chỉ cuộn được \(sheet.previewScrollableWidthForSelfTest)pt"
            }

            // Đo lại chính cái thước: ép ô về đúng cấu hình hỏng cũ — ngắt dòng theo bề ngang
            // khung — thì nó PHẢI đếm ra nhiều hơn. Nếu không, cái thước mù và câu "không ngắt
            // dòng" ở trên chẳng khẳng định được gì.
            let width = sheet.previewVisibleWidthForSelfTest
            sheet.forcePreviewWrapForSelfTest(width: width)
            let wrapped = sheet.drawnPreviewLineCountForSelfTest()
            sheet.restorePreviewForSelfTest()
            guard wrapped > expected else {
                return "thước mù: ép ngắt dòng ở bề ngang \(width) mà vẫn đếm ra \(wrapped) dòng"
            }
            return nil
        },

        Case(name: "tài liệu quá lớn thì KHÓA tạo tab mới và nói rõ vì sao") { controller in
            // Tab mới giữ toàn bộ kết quả trong bộ nhớ. Thà nói trước còn hơn để ứng dụng chết
            // giữa chừng sau khi người dùng đã chờ.
            controller.prepareSelfTestDocument("ma,ten\nA1,Cam\n")
            controller.setCSVModeForSelfTest(true)
            let small = controller.makeConvertSheetForSelfTest()
            small.loadViewForSelfTest()
            guard small.newTabEnabledForSelfTest else {
                return "tài liệu nhỏ mà đã khóa tạo tab mới"
            }

            var big = "ma,ten\n"
            big.reserveCapacity(CSVConvertSheet.newTabSizeLimit + 1024)
            while big.utf8.count <= CSVConvertSheet.newTabSizeLimit { big += "KH,Tên rất dài ở đây\n" }
            controller.prepareSelfTestDocument(big)
            let sheet = controller.makeConvertSheetForSelfTest()
            sheet.loadViewForSelfTest()
            guard !sheet.newTabEnabledForSelfTest else {
                return "tài liệu \(big.utf8.count) byte mà vẫn cho tạo tab mới"
            }
            guard sheet.noteForSelfTest.contains("bộ nhớ") else {
                return "không nói rõ lý do: «\(sheet.noteForSelfTest)»"
            }
            return nil
        },

        // MARK: - Tự hoàn thành (FR-CORE-013)

        Case(name: "gõ vài ký tự thì hiện gợi ý từ chính tài liệu") { controller in
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument("khach_hang = 1\nkhach_le = 2\ndoanh_thu = 3\nkha")
            controller.setCompletionEnabledForSelfTest(true)
            controller.editorViewSetCaretToEndForSelfTest()
            controller.refreshCompletionForSelfTest()

            guard controller.completionPopup.isVisible else { return "không hiện gợi ý nào" }
            let words = controller.completionPopup.wordsForSelfTest
            guard words.contains("khach_hang"), words.contains("khach_le") else {
                return "gợi ý: \(words)"
            }
            guard !words.contains("doanh_thu") else { return "gợi ý cả từ không khớp: \(words)" }
            return nil
        },

        Case(name: "chọn một gợi ý là MỘT bước undo, con nháy ở cuối từ") { controller in
            let source = "khach_hang = 1\nkha"
            controller.prepareSelfTestDocument(source)
            controller.editorViewSetCaretToEndForSelfTest()
            controller.refreshCompletionForSelfTest()

            guard controller.completionPopup.isVisible else { return "không hiện gợi ý nào" }
            let buffer = controller.editorDocument.buffer
            let depth = buffer.undoDepth
            controller.completionPopup.commitForSelfTest()

            guard buffer.text == "khach_hang = 1\nkhach_hang" else {
                return "văn bản: \(String(reflecting: buffer.text))"
            }
            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth)"
            }
            guard controller.editorView.selectedDocumentRange.lowerBound == buffer.count else {
                return "con nháy không ở cuối từ vừa chèn"
            }
            _ = buffer.undo()
            guard buffer.text == source else { return "một lần undo không về nguyên trạng" }
            return nil
        },

        Case(name: "mũi tên đổi lựa chọn, Esc đóng danh sách") { controller in
            controller.prepareSelfTestDocument("alpha_mot = 1\nalpha_hai = 2\nalp")
            controller.editorViewSetCaretToEndForSelfTest()
            controller.refreshCompletionForSelfTest()

            guard controller.completionPopup.wordsForSelfTest.count >= 2 else {
                return "cần ít nhất hai gợi ý: \(controller.completionPopup.wordsForSelfTest)"
            }
            let first = controller.completionPopup.selectedWordForSelfTest
            controller.completionPopup.moveForSelfTest(1)
            guard controller.completionPopup.selectedWordForSelfTest != first else {
                return "mũi tên không đổi lựa chọn"
            }
            controller.completionPopup.hide()
            guard !controller.completionPopup.isVisible else { return "Esc không đóng danh sách" }
            return nil
        },

        Case(name: "tắt tự hoàn thành thì KHÔNG hiện gì") { controller in
            controller.prepareSelfTestDocument("khach_hang = 1\nkha")
            controller.editorViewSetCaretToEndForSelfTest()
            controller.setCompletionEnabledForSelfTest(false)
            controller.refreshCompletionForSelfTest()

            guard !controller.completionPopup.isVisible else { return "tắt rồi mà vẫn hiện" }
            controller.setCompletionEnabledForSelfTest(true)
            return nil
        },

        // MARK: - Công cụ JSON và YAML (FR-FMT-504, FR-FMT-507)

        Case(name: "định dạng JSON là MỘT bước undo và không đổi dữ liệu") { controller in
            let source = #"{"ten":"GEditor","so":1.0,"mu":1e3,"dai":123456789012345678901}"#
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)

            let buffer = controller.editorDocument.buffer
            let depth = buffer.undoDepth
            controller.formatJSONForSelfTest()

            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth)"
            }
            // Số giữ NGUYÊN VĂN: đây là lý do không dùng JSONSerialization.
            for token in ["1.0", "1e3", "123456789012345678901"] {
                guard buffer.text.contains(token) else {
                    return "mất nguyên văn số «\(token)»: \(buffer.text)"
                }
            }
            // Thứ tự khóa giữ nguyên.
            guard let tenAt = buffer.text.range(of: "\"ten\""),
                  let soAt = buffer.text.range(of: "\"so\""),
                  tenAt.lowerBound < soAt.lowerBound
            else { return "thứ tự khóa đã đổi" }

            _ = buffer.undo()
            guard buffer.text == source else { return "một lần undo không về nguyên trạng" }
            return nil
        },

        Case(name: "JSON hỏng thì KHÔNG đụng vào file, đưa con nháy tới chỗ lỗi") { controller in
            let source = "{\n  \"a\": 1,\n  \"b\": 2\n  \"c\": 3\n}"
            controller.prepareSelfTestDocument(source)
            let buffer = controller.editorDocument.buffer
            let depth = buffer.undoDepth

            controller.formatJSONForSelfTest()

            guard buffer.text == source else { return "file hỏng mà vẫn bị sửa" }
            guard buffer.undoDepth == depth else { return "đẻ ra một bước undo cho file hỏng" }

            // Con nháy phải ở dòng 4 — chỗ thiếu dấu phẩy.
            let caret = controller.editorView.selectedDocumentRange.lowerBound
            let linesBefore = source.prefix(caret).components(separatedBy: "\n").count
            guard linesBefore >= 4 else { return "con nháy ở dòng \(linesBefore), chờ dòng 4" }
            return nil
        },

        Case(name: "thu gọn rồi định dạng lại quay về đúng như cũ") { controller in
            let pretty = "{\n  \"a\": [\n    1,\n    2\n  ],\n  \"b\": true\n}\n"
            controller.prepareSelfTestDocument(pretty)
            let buffer = controller.editorDocument.buffer

            controller.minifyJSONForSelfTest()
            guard buffer.text == #"{"a":[1,2],"b":true}"# else {
                return "thu gọn ra: \(String(reflecting: buffer.text))"
            }
            controller.formatJSONForSelfTest()
            guard buffer.text == pretty else {
                return "định dạng lại ra: \(String(reflecting: buffer.text))"
            }
            return nil
        },

        Case(name: "kiểm YAML bắt khóa trùng và nói rõ dòng nào đè dòng nào") { controller in
            let source = """
            may_chu: alpha
            cong: 8080
            may_chu: beta
            """
            controller.prepareSelfTestDocument(source)
            controller.lintYAMLForSelfTest()

            guard controller.lastYAMLIssues.count == 1 else {
                return "\(controller.lastYAMLIssues.count) cảnh báo"
            }
            let issue = controller.lastYAMLIssues[0]
            guard issue.line == 3 else { return "báo ở dòng \(issue.line)" }
            guard issue.message.contains("dòng 1"), issue.message.contains("ĐÈ") else {
                return "thông điệp: «\(issue.message)»"
            }
            // Lint chỉ ĐỌC — nó không được sửa file.
            guard controller.editorDocument.buffer.text == source else {
                return "lint đã sửa file"
            }
            return nil
        },

        // MARK: - Folder as Workspace (FR-DOC-308)

        Case(name: "cây thư mục: thư mục trước, file sau, bỏ qua node_modules") { controller in
            let root = NSTemporaryDirectory() + "geditor-ws-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: root) }
            let manager = FileManager.default
            do {
                try manager.createDirectory(
                    atPath: (root as NSString).appendingPathComponent("src"),
                    withIntermediateDirectories: true
                )
                try manager.createDirectory(
                    atPath: (root as NSString).appendingPathComponent("node_modules"),
                    withIntermediateDirectories: true
                )
                try Data("x".utf8).write(to: URL(
                    fileURLWithPath: (root as NSString).appendingPathComponent("doc.txt")
                ))
            } catch { return "không dựng được thư mục thử" }

            controller.openWorkspaceForSelfTest(root)
            guard controller.isSidebarVisible else { return "mở workspace mà sidebar vẫn ẩn" }
            let names = controller.workspaceView.visibleNamesForSelfTest
            guard names == ["src", "doc.txt"] else { return "cây hiện: \(names)" }
            return nil
        },

        Case(name: "lọc tìm file trong cả cây, gõ KHÔNG DẤU cũng ra") { controller in
            let root = NSTemporaryDirectory() + "geditor-ws-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: root) }
            do {
                try FileManager.default.createDirectory(
                    atPath: (root as NSString).appendingPathComponent("sau/hon"),
                    withIntermediateDirectories: true
                )
                try Data("x".utf8).write(to: URL(
                    fileURLWithPath: (root as NSString)
                        .appendingPathComponent("sau/hon/Báo cáo tháng.txt")
                ))
            } catch { return "không dựng được thư mục thử" }

            controller.openWorkspaceForSelfTest(root)
            controller.workspaceView.setFilterForSelfTest("bao cao")

            let names = controller.workspaceView.visibleNamesForSelfTest
            guard names == ["Báo cáo tháng.txt"] else { return "kết quả: \(names)" }
            guard controller.workspaceView.titleForSelfTest.contains("1 kết quả") else {
                return "tiêu đề: «\(controller.workspaceView.titleForSelfTest)»"
            }
            return nil
        },

        Case(name: "bấm file trong cây thì mở thành TAB MỚI") { controller in
            let root = NSTemporaryDirectory() + "geditor-ws-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: root) }
            let path = (root as NSString).appendingPathComponent("mo_toi.txt")
            do {
                try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
                try Data("nội dung file\n".utf8).write(to: URL(fileURLWithPath: path))
            } catch { return "không dựng được thư mục thử" }

            controller.resetTabsForSelfTest()
            controller.openWorkspaceForSelfTest(root)
            controller.workspaceView.openFileForSelfTest(path)

            guard controller.editorDocument.path == path else {
                return "tài liệu đang mở: \(controller.editorDocument.path ?? "nil")"
            }
            guard controller.editorDocument.buffer.text == "nội dung file\n" else {
                return "nội dung: \(controller.editorDocument.buffer.text.prefix(30))"
            }

            // Mở file thứ hai thì phải thành tab RIÊNG — tab đầu đã có nội dung, không được đè.
            let second = (root as NSString).appendingPathComponent("thu_hai.txt")
            guard (try? Data("file hai\n".utf8).write(to: URL(fileURLWithPath: second))) != nil else {
                return "không ghi được file thứ hai"
            }
            let tabsBefore = controller.tabPathsForSelfTest.count
            controller.workspaceView.openFileForSelfTest(second)
            guard controller.tabPathsForSelfTest.count == tabsBefore + 1 else {
                return "file thứ hai không mở thành tab riêng: \(controller.tabPathsForSelfTest.count) tab"
            }
            guard controller.tabPathsForSelfTest.contains(path) else {
                return "tab của file đầu đã bị thay"
            }
            return nil
        },

        Case(name: "tạo file mới trong cây rồi mở nó ra; trùng tên thì BÁO LỖI") { controller in
            let root = NSTemporaryDirectory() + "geditor-ws-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: root) }
            do {
                try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
                try Data("quý giá".utf8).write(to: URL(
                    fileURLWithPath: (root as NSString).appendingPathComponent("co_san.txt")
                ))
            } catch { return "không dựng được thư mục thử" }

            controller.openWorkspaceForSelfTest(root)

            // Đi thẳng qua lõi: hộp thoại hỏi tên không bấm được trong bài tự kiểm.
            guard (try? Workspace.createFile(named: "moi.txt", in: root)) != nil else {
                return "không tạo được file mới"
            }
            controller.workspaceView.refreshNow()
            guard controller.workspaceView.visibleNamesForSelfTest.contains("moi.txt") else {
                return "cây chưa thấy file mới: \(controller.workspaceView.visibleNamesForSelfTest)"
            }

            // Tạo trùng tên KHÔNG được ghi đè — một thao tác "tạo mới" mà xóa trắng file cũ là
            // mất dữ liệu, và người dùng chỉ biết khi mở nó ra.
            do {
                _ = try Workspace.createFile(named: "co_san.txt", in: root)
                return "tạo trùng tên mà không báo lỗi"
            } catch {}
            let kept = (try? String(
                contentsOfFile: (root as NSString).appendingPathComponent("co_san.txt"),
                encoding: .utf8
            )) ?? ""
            guard kept == "quý giá" else { return "file cũ bị đè: «\(kept)»" }
            controller.closeFunctionListForSelfTest()
            return nil
        },

        // MARK: - Function List (FR-DOC-307)

        Case(name: "Function List liệt kê hàm và lớp theo thứ tự FILE") { controller in
            let source = """
            import os

            def tinh_tong(a, b):
                return a + b

            class KhachHang:
                def chao(self):
                    return "hi"

            def main():
                pass
            """
            controller.resetTabsForSelfTest()
            guard let path = controller.openSelfTestFile(source, extension: "py") else {
                return "không ghi được file thử"
            }
            defer { try? FileManager.default.removeItem(atPath: path) }
            controller.openFunctionListForSelfTest()

            let names = controller.functionList.namesForSelfTest
            guard names == ["tinh_tong", "KhachHang", "chao", "main"] else {
                return "danh sách: \(names)"
            }
            guard controller.functionList.titleForSelfTest.contains("Python") else {
                return "tiêu đề: «\(controller.functionList.titleForSelfTest)»"
            }
            return nil
        },

        Case(name: "bấm một mục thì con nháy nhảy tới đúng định nghĩa") { controller in
            let source = """
            def mot():
                pass

            def hai():
                pass
            """
            guard let path = controller.openSelfTestFile(source, extension: "py") else {
                return "không ghi được file thử"
            }
            defer { try? FileManager.default.removeItem(atPath: path) }
            controller.openFunctionListForSelfTest()

            guard controller.functionList.countForSelfTest == 2 else {
                return "\(controller.functionList.countForSelfTest) mục"
            }
            controller.functionList.clickRowForSelfTest(1)

            let caret = controller.editorView.selectedDocumentRange.lowerBound
            let expected = source.distance(
                from: source.startIndex, to: source.range(of: "def hai")!.lowerBound
            )
            guard caret == expected else { return "con nháy ở \(caret), chờ \(expected)" }
            return nil
        },

        Case(name: "ô lọc trong Function List tìm được cả khi gõ KHÔNG DẤU") { controller in
            let source = """
            def chao_khach():
                pass

            def tinh_tien():
                pass
            """
            guard let path = controller.openSelfTestFile(source, extension: "py") else {
                return "không ghi được file thử"
            }
            defer { try? FileManager.default.removeItem(atPath: path) }
            controller.openFunctionListForSelfTest()

            controller.functionList.setFilterForSelfTest("tien")
            guard controller.functionList.namesForSelfTest == ["tinh_tien"] else {
                return "lọc «tien» ra: \(controller.functionList.namesForSelfTest)"
            }
            controller.functionList.setFilterForSelfTest("")
            guard controller.functionList.countForSelfTest == 2 else {
                return "xóa lọc mà còn \(controller.functionList.countForSelfTest) mục"
            }
            return nil
        },

        Case(name: "file không nhận ra ngôn ngữ thì NÓI RÕ, không im lặng") { controller in
            // Ô trống không có lời giải thích sẽ bị đọc thành "file này không có hàm nào".
            guard let path = controller.openSelfTestFile("xin chào\n", extension: "abcxyz") else {
                return "không ghi được file thử"
            }
            defer { try? FileManager.default.removeItem(atPath: path) }
            controller.openFunctionListForSelfTest()

            guard controller.functionList.countForSelfTest == 0 else {
                return "\(controller.functionList.countForSelfTest) mục cho file không rõ ngôn ngữ"
            }
            guard controller.functionList.titleForSelfTest.contains("Không nhận ra") else {
                return "tiêu đề: «\(controller.functionList.titleForSelfTest)»"
            }
            controller.closeFunctionListForSelfTest()
            return nil
        },

        // MARK: - Lọc tương tác theo cột (FR-QRY-002)

        Case(name: "gõ ô lọc thu hẹp bảng và nói rõ N / tổng") { controller in
            var source = "ma,tinh,doanh_so\n"
            for index in 1...20 {
                let tinh = index % 3 == 0 ? "Huế" : "Hà Nội"
                source += "A\(index),\(tinh),\(index * 100)\n"
            }
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            // Về văn bản rồi sang bảng: bảng chỉ nạp lại tài liệu khi CHUYỂN sang nó, và bài
            // trước có thể đã để nó đang hiện — khi ấy nó vẫn giữ buffer cũ.
            controller.showTextViewForSelfTest()
            controller.showTableViewForSelfTest()

            let all = controller.csvTable.rowCountForSelfTest
            guard all == 20 else { return "bảng có \(all) hàng trước khi lọc" }

            controller.csvTable.setFilterForSelfTest("Huế", column: 1)
            guard controller.csvTable.rowCountForSelfTest == 6 else {
                return "lọc xong còn \(controller.csvTable.rowCountForSelfTest) hàng, chờ 6"
            }
            // Con số phải nói cả TỔNG: "6 dòng" và "6 / 20 dòng" là hai câu khác nhau.
            guard controller.csvTable.filterLabelForSelfTest.contains("6 / 20") else {
                return "nhãn: «\(controller.csvTable.filterLabelForSelfTest)»"
            }

            // Thêm ô lọc thứ hai là AND, thu hẹp tiếp: trong sáu hàng Huế (3,6,9,12,15,18)
            // chỉ ba hàng cuối có doanh_so > 1000.
            controller.csvTable.setFilterForSelfTest(">1000", column: 2)
            guard controller.csvTable.rowCountForSelfTest == 3 else {
                return "AND hai cột còn \(controller.csvTable.rowCountForSelfTest) hàng, chờ 3"
            }

            controller.csvTable.clearFiltersForSelfTest()
            guard controller.csvTable.rowCountForSelfTest == 20 else {
                return "xóa lọc mà bảng còn \(controller.csvTable.rowCountForSelfTest) hàng"
            }
            controller.showTextViewForSelfTest()
            return nil
        },

        Case(name: "lọc KHÔNG đụng một byte nào của văn bản") { controller in
            // Bất biến NFR-QRY-03, và là lý do người dùng dám gõ thử.
            var source = "ma,tinh\n"
            for index in 1...20 { source += "A\(index),\(index % 2 == 0 ? "Huế" : "Hà Nội")\n" }
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.showTextViewForSelfTest()
            controller.showTableViewForSelfTest()

            let depth = controller.editorDocument.buffer.undoDepth
            controller.csvTable.setFilterForSelfTest("Huế", column: 1)

            guard controller.editorDocument.buffer.text == source else {
                return "lọc đã sửa văn bản"
            }
            guard controller.editorDocument.buffer.undoDepth == depth else {
                return "lọc đẻ ra một bước undo"
            }
            controller.csvTable.clearFiltersForSelfTest()
            controller.showTextViewForSelfTest()
            return nil
        },

        Case(name: "xuất dòng khớp ra TAB MỚI, giữ hàng tiêu đề") { controller in
            var source = "ma,tinh\n"
            for index in 1...20 { source += "A\(index),\(index % 4 == 0 ? "Huế" : "Hà Nội")\n" }
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.showTextViewForSelfTest()
            controller.showTableViewForSelfTest()
            controller.csvTable.setFilterForSelfTest("Huế", column: 1)

            guard controller.csvTable.exportFilteredVisibleForSelfTest else {
                return "lọc xong mà nút xuất vẫn ẩn"
            }
            let tabsBefore = controller.tabPathsForSelfTest.count
            controller.csvTable.exportFilteredForSelfTest()

            let deadline = Date().addingTimeInterval(10)
            while controller.tabPathsForSelfTest.count == tabsBefore, Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            let text = controller.editorDocument.buffer.text
            guard text.hasPrefix("ma,tinh\n") else { return "thiếu hàng tiêu đề: \(text.prefix(30))" }
            guard text.components(separatedBy: "\n").filter({ !$0.isEmpty }).count == 6 else {
                return "tab mới: \(String(reflecting: text))"
            }
            guard controller.tabTextsForSelfTest.contains(source) else {
                return "tài liệu gốc đã bị đổi"
            }
            controller.csvTable.clearFiltersForSelfTest()
            controller.showTextViewForSelfTest()
            return nil
        },

        // MARK: - Bàn làm sạch dữ liệu (FR-CLN-006)

        Case(name: "Bàn làm sạch nêu đúng cột và số lượng phát hiện") { controller in
            var source = "ma,tinh,ngay\n"
            for index in 1...12 {
                let tinh = index % 4 == 0 ? "N/A" : "Huế"
                let ngay = index % 3 == 0 ? "25/07/2026" : "2026-07-02"
                source += "A\(index),\(tinh),\(ngay)\n"
            }
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard controller.cleanPanelVisibleForSelfTest else { return "panel không mở" }
            let titles = controller.cleanPanel.findingTitlesForSelfTest
            guard titles.contains(where: { $0.contains("Ô thiếu") && $0.contains("3 ô") }) else {
                return "không nêu đúng số ô thiếu: \(titles)"
            }
            guard titles.contains(where: { $0.contains("định dạng khác nhau") }) else {
                return "không thấy cột ngày hỗn tạp: \(titles)"
            }
            // Phát hiện phải gọi tên CỘT của người dùng, không phải số thứ tự.
            guard controller.cleanPanel.findingForSelfTest(0)?.columnName != nil,
                  ["tinh", "ngay"].contains(controller.cleanPanel.findingForSelfTest(0)!.columnName)
            else { return "phát hiện không gọi đúng tên cột" }
            return nil
        },

        Case(name: "xem trước hiện trước→sau mà KHÔNG đụng vào dữ liệu") { controller in
            var source = "ma,ngay\n"
            for index in 1...12 {
                source += "A\(index),\(index % 3 == 0 ? "2026-07-25" : "25/07/2026")\n"
            }
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard let finding = controller.cleanPanel.findingForSelfTest(0) else {
                return "không có phát hiện nào"
            }
            let sheet = controller.makeCleanSheetForSelfTest(finding)
            sheet.loadViewForSelfTest()

            guard let first = sheet.samplesForSelfTest.first else { return "bảng mẫu rỗng" }
            guard first.before == "25/07/2026", first.after == "2026-07-25" else {
                return "mẫu sai: «\(first.before)» → «\(first.after ?? "nil")»"
            }
            // Xem trước là XEM: văn bản phải còn nguyên cho tới khi người dùng bấm Áp dụng.
            guard controller.editorDocument.buffer.text == source else {
                return "xem trước đã sửa dữ liệu"
            }
            return nil
        },

        Case(name: "áp một nhóm là MỘT bước undo, xong thì quét lại danh mục") { controller in
            var source = "ma,ngay\n"
            for index in 1...12 {
                source += "A\(index),\(index % 3 == 0 ? "2026-07-25" : "25/07/2026")\n"
            }
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard let finding = controller.cleanPanel.findingForSelfTest(0) else {
                return "không có phát hiện nào"
            }
            let before = controller.editorDocument.buffer.undoDepth
            controller.runCleanStepForSelfTest(
                CSVCleanStep(column: finding.column, kind: .normalizeDates(order: nil)),
                finding: finding
            )

            guard controller.editorDocument.buffer.undoDepth == before + 1 else {
                return "undoDepth \(before) → \(controller.editorDocument.buffer.undoDepth)"
            }
            guard controller.editorDocument.buffer.text.contains("A1,2026-07-25") else {
                return "chưa chuẩn hóa: \(controller.editorDocument.buffer.text.prefix(40))"
            }
            // Sau khi sửa, danh mục cũ nói về một file không còn tồn tại — phải quét lại.
            guard !controller.cleanPanel.findingTitlesForSelfTest
                .contains(where: { $0.contains("định dạng khác nhau") })
            else { return "danh mục vẫn còn nhóm đã sửa xong" }

            _ = controller.editorDocument.buffer.undo()
            return nil
        },

        Case(name: "KHÔNG hỏi quy ước ngày khi dữ liệu đã tự nói ra") { controller in
            // Cột có ô ngày > 12 thì quy ước đã rõ. Mỗi câu hỏi thừa làm người dùng bấm nhanh
            // hơn cho xong ở câu hỏi thật.
            var source = "ma,ngay\n"
            for index in 1...10 { source += "A\(index),03/04/2026\n" }
            source += "A11,31/12/2026\nA12,2026-01-01\n"
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard let finding = controller.cleanPanel.findingForSelfTest(0) else {
                return "không có phát hiện nào"
            }
            let sheet = controller.makeCleanSheetForSelfTest(finding)
            sheet.loadViewForSelfTest()
            guard sheet.optionTitlesForSelfTest.count == 1 else {
                return "hỏi thừa: \(sheet.optionTitlesForSelfTest)"
            }
            guard case let .normalizeDates(order) = sheet.selectedStepForSelfTest.kind,
                  order == .dayFirst
            else { return "không chọn sẵn quy ước rút ra từ dữ liệu" }
            return nil
        },

        Case(name: "cột toàn ô mơ hồ thì PHẢI hỏi, và nói rõ ô nào bị giữ nguyên") { controller in
            var source = "ma,ngay\n"
            for index in 1...11 { source += "A\(index),03/04/2026\n" }
            source += "A12,2026-01-01\n"
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard let finding = controller.cleanPanel.findingForSelfTest(0) else {
                return "không có phát hiện nào"
            }
            let sheet = controller.makeCleanSheetForSelfTest(finding)
            sheet.loadViewForSelfTest()
            guard sheet.optionTitlesForSelfTest.count == 3 else {
                return "phải hỏi quy ước: \(sheet.optionTitlesForSelfTest)"
            }

            // Chọn "bỏ qua ô mơ hồ" thì sheet phải nói ra rằng chúng được GIỮ NGUYÊN.
            sheet.selectOptionForSelfTest(2)
            guard sheet.warningForSelfTest.contains("GIỮ NGUYÊN") else {
                return "không cảnh báo về ô không đọc được: «\(sheet.warningForSelfTest)»"
            }
            return nil
        },

        Case(name: "báo cáo làm sạch kể cả phần CÒN LẠI, không chỉ phần đã làm") { controller in
            var source = "ma,tinh,ngay\n"
            for index in 1...12 {
                let ngay = index % 3 == 0 ? "2026-07-25" : "25/07/2026"
                source += "A\(index),\(index % 4 == 0 ? "N/A" : "Huế"),\(ngay)\n"
            }
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard let dates = (0 ..< controller.cleanPanel.findingCountForSelfTest)
                .compactMap({ controller.cleanPanel.findingForSelfTest($0) })
                .first(where: { if case .mixedDates = $0.kind { true } else { false } })
            else { return "không thấy nhóm ngày: \(controller.cleanPanel.findingTitlesForSelfTest)" }

            controller.runCleanStepForSelfTest(
                CSVCleanStep(column: dates.column, kind: .normalizeDates(order: nil)),
                finding: dates
            )
            guard controller.cleanPanel.reportEnabledForSelfTest else {
                return "áp xong mà nút báo cáo vẫn khóa"
            }

            let tabsBefore = controller.tabPathsForSelfTest.count
            controller.exportCleanReportForSelfTest()
            guard controller.tabPathsForSelfTest.count == tabsBefore + 1 else {
                return "báo cáo không mở thành tab mới"
            }
            let report = controller.editorDocument.buffer.text
            guard report.contains("Đã áp dụng (1)") else { return "báo cáo thiếu phần đã làm" }
            guard report.contains("Còn lại"), report.contains("Ô thiếu") else {
                return "báo cáo chỉ kể phần đã làm — đọc như thể file đã sạch"
            }
            controller.closeCleanPanelForSelfTest()
            return nil
        },

        Case(name: "hồ sơ dữ liệu nêu kiểu, null, distinct và giá trị bất thường") { controller in
            var source = "ma,tinh,doanh_so\n"
            for index in 1...40 {
                let tinh = index % 4 == 0 ? "N/A" : (index % 2 == 0 ? "Huế" : "Đà Nẵng")
                source += "A\(index),\(tinh),\(index == 20 ? 999999 : 100 + index % 5)\n"
            }
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()
            controller.openProfileForSelfTest()

            guard let profile = controller.cleanPanel.profileForSelfTest else {
                return "không dựng được hồ sơ"
            }
            guard profile.columns.count == 3 else { return "\(profile.columns.count) cột" }

            let tinh = profile.columns[1]
            guard tinh.name == "tinh" else { return "cột 2 tên «\(tinh.name)»" }
            guard tinh.nullCells == 10 else { return "\(tinh.nullCells) ô thiếu, chờ 10" }
            // HAI giá trị thật, không phải ba: "N/A" là chỗ trống chứ không phải một tỉnh.
            guard tinh.distinct == 2, tinh.distinctExact else {
                return "distinct \(tinh.distinct) (chính xác: \(tinh.distinctExact))"
            }

            let doanhSo = profile.columns[2]
            guard doanhSo.type == .number else { return "kiểu \(doanhSo.type.displayName)" }
            guard doanhSo.outliers.contains(where: { $0.value == "999999" }) else {
                return "không bắt được giá trị cực đoan"
            }
            return nil
        },

        Case(name: "hồ sơ chỉ chạy khi người dùng mở sang xem") { controller in
            // Hồ sơ mất vài giây trên bảng lớn; tiêu chừng ấy cho câu hỏi chưa ai đặt là cách
            // chắc chắn để Bàn làm sạch mang tiếng chậm.
            controller.prepareSelfTestDocument("ma,x\nA1,1\nA2,2\nA3,3\n")
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard controller.cleanPanel.profileForSelfTest == nil else {
                return "hồ sơ đã chạy dù người dùng chưa mở tab Hồ sơ"
            }
            controller.openProfileForSelfTest()
            guard controller.cleanPanel.profileForSelfTest != nil else {
                return "mở tab Hồ sơ mà không chạy"
            }
            return nil
        },

        Case(name: "báo cáo kèm hồ sơ nói rõ PHƯƠNG PHÁP và chỗ nào là ước lượng") { controller in
            var source = "ma,tinh\n"
            for index in 1...40 { source += "A\(index),\(index % 4 == 0 ? "N/A" : "Huế")\n" }
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()
            controller.openProfileForSelfTest()

            guard let finding = controller.cleanPanel.findingForSelfTest(0) else {
                return "không có phát hiện nào"
            }
            controller.runCleanStepForSelfTest(
                CSVCleanStep(column: finding.column, kind: .fillWithValue("Chưa rõ")),
                finding: finding
            )
            controller.exportCleanReportForSelfTest()

            let report = controller.editorDocument.buffer.text
            // So bằng `L(...)` chứ không bằng chuỗi tiếng Việt cứng: từ 28/08/2026 báo cáo ĐI
            // THEO ngôn ngữ giao diện, nên một bài kiểm neo vào tiếng Việt sẽ đỏ ở máy chạy
            // tiếng Anh — tức đỏ đúng chỗ không có gì hỏng.
            guard report.contains(L("\n## Hồ sơ dữ liệu\n\n").trimmingCharacters(in: .newlines))
            else { return "báo cáo thiếu hồ sơ" }
            guard report.contains(
                L("| Cột | Kiểu | Null | Distinct | Nhỏ nhất | Lớn nhất | Trung bình |\n")
                    .trimmingCharacters(in: .newlines))
            else { return "hồ sơ không thành bảng" }
            // Hai mẩu dưới đây nằm TRONG khối "Phương pháp" đã dịch trọn, nên lấy chính bản dịch
            // ấy ra mà tìm — chứ không đoán một mẩu con của nó.
            let phuongPhap = LF("""
                \n**Phương pháp.** Một lượt quét, chỉ đọc. Trung bình và độ lệch chuẩn tính \
                bằng Welford. Distinct đếm chính xác tới %d giá trị; vượt ngưỡng thì con số là \
                CẬN DƯỚI và bảng «hay gặp» bị bỏ. Giá trị bất thường chấm bằng |z| > 3 — thước \
                này bị chính outlier kéo lệch khi phân bố lệch, nên hãy đọc nó như một gợi ý để \
                nhìn, không phải một phán quyết. Ô thiếu không tính vào distinct. Cột chữ lấy \
                nhỏ nhất/lớn nhất theo thứ tự BYTE, không phải thứ tự chữ cái tiếng Việt.\n
                """, CSVProfiler.distinctLimit)
            guard report.contains(phuongPhap.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return "con số không kèm phương pháp — người đọc không tự kiểm chứng được"
            }
            // Khối "Phương pháp" là chuỗi NHIỀU DÒNG, nên chỗ gọi và khoá trong bảng dịch phải
            // giống nhau từng byte. Lệch một dấu cách thì `L()` im lặng trả về nguyên bản tiếng
            // Việt — báo cáo vẫn đúng, bài kiểm trên vẫn xanh, và bản tiếng Anh mất nguyên một
            // đoạn mà không ai biết. Hỏi thẳng bảng dịch là cách duy nhất bắt được điều đó.
            let khoaPhuongPhap = L("""
                \n**Phương pháp.** Một lượt quét, chỉ đọc. Trung bình và độ lệch chuẩn tính \
                bằng Welford. Distinct đếm chính xác tới %d giá trị; vượt ngưỡng thì con số là \
                CẬN DƯỚI và bảng «hay gặp» bị bỏ. Giá trị bất thường chấm bằng |z| > 3 — thước \
                này bị chính outlier kéo lệch khi phân bố lệch, nên hãy đọc nó như một gợi ý để \
                nhìn, không phải một phán quyết. Ô thiếu không tính vào distinct. Cột chữ lấy \
                nhỏ nhất/lớn nhất theo thứ tự BYTE, không phải thứ tự chữ cái tiếng Việt.\n
                """)
            guard khoaPhuongPhap.contains("**Method.**") || L10n.effective == .vi else {
                return "khối «Phương pháp» không tra được bản dịch — chỗ gọi lệch khoá trong bảng"
            }
            guard L10n.en[khoaPhuongPhap] != nil || khoaPhuongPhap.contains("**Method.**") else {
                return "khối «Phương pháp» KHÔNG có mặt trong bảng dịch"
            }
            controller.closeCleanPanelForSelfTest()
            return nil
        },

        Case(name: "công thức gom đúng các bước đã áp, ghi cột theo TÊN") { controller in
            var source = "ma,ngay\n"
            for index in 1...12 {
                source += "A\(index),\(index % 3 == 0 ? "2026-07-25" : "25/07/2026")\n"
            }
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()

            guard controller.cleanPanel.recipeEnabledForSelfTest == false else {
                return "chưa áp bước nào mà nút lưu công thức đã mở"
            }
            guard let finding = controller.cleanPanel.findingForSelfTest(0) else {
                return "không có phát hiện nào"
            }
            controller.runCleanStepForSelfTest(
                CSVCleanStep(column: finding.column, kind: .normalizeDates(order: .dayFirst)),
                finding: finding
            )
            guard controller.cleanPanel.recipeEnabledForSelfTest else {
                return "áp xong mà nút lưu công thức vẫn khóa"
            }

            let recipe = controller.recipeFromLogForSelfTest(name: "thử")
            guard recipe.steps.count == 1 else { return "\(recipe.steps.count) bước" }
            guard recipe.steps[0].columnName == "ngay" else {
                return "cột ghi theo tên «\(recipe.steps[0].columnName ?? "nil")»"
            }
            // Ghi ra JSON rồi đọc lại phải ra đúng công thức ấy — đó là thứ sẽ gửi sang máy khác.
            let reloaded = try? CSVRecipe.load(from: recipe.jsonData())
            guard reloaded == recipe else { return "JSON đi rồi về không khớp" }
            return nil
        },

        Case(name: "công thức chạy lại trên file có bố cục KHÁC, tìm cột theo tên") { controller in
            // Cột ngày ở file mới nằm ở vị trí khác. Chạy theo chỉ số thì chuẩn hóa ngày sẽ
            // rơi vào cột doanh thu và viết lại những con số thành ngày tháng.
            let recipe = CSVRecipe(name: "chuẩn hóa ngày", steps: [
                CSVRecipeStep(columnName: "ngay", columnIndex: 1,
                              kind: .normalizeDates(order: .dayFirst)),
            ])
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument("ma,doanh_so,ngay\nA1,\"1.234,56\",25/07/2026\n")
            controller.setCSVModeForSelfTest(true)

            let tabsBefore = controller.tabPathsForSelfTest.count
            controller.applyRecipeForSelfTest(recipe)

            guard let run = controller.lastRecipeRun else { return "không có kết quả chạy" }
            guard run.appliedCount == 1, !run.hasProblems else { return run.report }
            // Báo cáo mở thành tab MỚI, nên tài liệu vừa sửa là tab trước đó.
            guard controller.tabPathsForSelfTest.count == tabsBefore + 1 else {
                return "báo cáo không mở thành tab mới"
            }
            guard controller.editorDocument.buffer.text.hasPrefix("## ") else {
                return "tab mới không phải báo cáo"
            }
            guard controller.tabTextsForSelfTest.contains(where: {
                $0.contains("A1,\"1.234,56\",2026-07-25")
            }) else {
                return "công thức không áp đúng cột: \(controller.tabTextsForSelfTest)"
            }
            return nil
        },

        Case(name: "sheet công thức nói TRƯỚC những bước sẽ bị bỏ qua") { controller in
            let recipe = CSVRecipe(name: "hai bước", steps: [
                CSVRecipeStep(columnName: "ngay", columnIndex: 1,
                              kind: .normalizeDates(order: .dayFirst)),
                CSVRecipeStep(columnName: "khong_co", columnIndex: 5, kind: .trim(collapseInner: false)),
            ])
            controller.prepareSelfTestDocument("ma,ngay\nA1,25/07/2026\n")
            controller.setCSVModeForSelfTest(true)

            let sheet = controller.makeRecipeSheetForSelfTest(recipe)
            sheet.loadViewForSelfTest()
            guard sheet.noteForSelfTest.contains("khong_co") else {
                return "không cảnh báo trước: «\(sheet.noteForSelfTest)»"
            }

            // Tắt hết thì không còn gì để chạy.
            sheet.setStepEnabledForSelfTest(0, false)
            sheet.setStepEnabledForSelfTest(1, false)
            guard !sheet.runEnabledForSelfTest else { return "tắt hết mà vẫn cho chạy" }
            return nil
        },

        Case(name: "cả công thức là MỘT bước undo, kể cả khi có bước bị bỏ qua") { controller in
            let recipe = CSVRecipe(name: "ba bước", steps: [
                CSVRecipeStep(columnName: "ngay", columnIndex: 1,
                              kind: .normalizeDates(order: .dayFirst)),
                CSVRecipeStep(columnName: "ten", columnIndex: 2, kind: .trim(collapseInner: true)),
                CSVRecipeStep(columnName: "khong_co", columnIndex: 9, kind: .changeCase(.upper)),
            ])
            let source = "ma,ngay,ten\nA1,25/07/2026,\"Cty  Anh Đào \"\n"
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)

            let buffer = controller.editorDocument.buffer
            let depth = buffer.undoDepth
            controller.applyRecipeForSelfTest(recipe)

            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth), phải chỉ tăng 1"
            }
            guard buffer.text == "ma,ngay,ten\nA1,2026-07-25,Cty Anh Đào\n" else {
                return "kết quả: \(String(reflecting: buffer.text))"
            }
            _ = buffer.undo()
            guard buffer.text == source else { return "một lần undo không về nguyên trạng" }

            // Bước bỏ qua phải nằm trong báo cáo, không được im lặng.
            guard let run = controller.lastRecipeRun, run.hasProblems,
                  run.report.contains("khong_co") else {
                return "báo cáo không nói tới bước bị bỏ qua"
            }
            return nil
        },

        Case(name: "chạy công thức trên THƯ MỤC không đụng vào file gốc") { controller in
            // Từ giao diện, người dùng chỉ vào một thư mục bằng hai cú bấm mà không thấy bên
            // trong có bao nhiêu file. Ghi đè ở đường này là đánh cược dữ liệu của họ vào một
            // hộp thoại chọn thư mục.
            let folder = NSTemporaryDirectory() + "geditor-selftest-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: folder) }
            do {
                try FileManager.default.createDirectory(
                    atPath: folder, withIntermediateDirectories: true
                )
            } catch { return "không dựng được thư mục thử" }

            let source = "ma,ngay\nA1,25/07/2026\n"
            let path = (folder as NSString).appendingPathComponent("thang7.csv")
            do {
                try Data(source.utf8).write(to: URL(fileURLWithPath: path))
            } catch { return "không ghi được file thử" }

            let recipe = CSVRecipe(name: "chuẩn hóa ngày", steps: [
                CSVRecipeStep(columnName: "ngay", columnIndex: 1,
                              kind: .normalizeDates(order: .dayFirst)),
            ])
            let result = CSVRecipeBatch.run(recipe, files: CSVRecipeBatch.csvFiles(in: folder))

            guard result.succeededCount == 1 else { return result.report }
            let after = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            guard after == source else { return "file gốc bị sửa: \(String(reflecting: after))" }

            let output = (folder as NSString).appendingPathComponent("thang7-sach.csv")
            let cleaned = (try? String(contentsOfFile: output, encoding: .utf8)) ?? ""
            guard cleaned == "ma,ngay\nA1,2026-07-25\n" else {
                return "kết quả: \(String(reflecting: cleaned))"
            }
            return nil
        },

        Case(name: "mở Bàn làm sạch cho tài liệu khác thì nhật ký bắt đầu lại") { controller in
            // Nhật ký theo sang tài liệu mới thì báo cáo bàn giao của file này liệt kê cả việc
            // đã làm trên file trước — nói sai về việc đã làm gì với dữ liệu của ai.
            var source = "ma,ngay\n"
            for index in 1...12 {
                source += "A\(index),\(index % 3 == 0 ? "2026-07-25" : "25/07/2026")\n"
            }
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)
            controller.openCleanBenchForSelfTest()
            guard let finding = controller.cleanPanel.findingForSelfTest(0) else {
                return "không có phát hiện nào"
            }
            controller.runCleanStepForSelfTest(
                CSVCleanStep(column: finding.column, kind: .normalizeDates(order: nil)),
                finding: finding
            )
            guard controller.cleanPanel.applied.count == 1 else {
                return "nhật ký có \(controller.cleanPanel.applied.count) mục sau một bước"
            }

            controller.prepareSelfTestDocument("ma,tinh\nA1,Huế\nA2,N/A\n")
            controller.openCleanBenchForSelfTest()
            guard controller.cleanPanel.applied.isEmpty else {
                return "nhật ký của tài liệu trước theo sang: \(controller.cleanPanel.applied.count) mục"
            }
            guard !controller.cleanPanel.reportEnabledForSelfTest else {
                return "chưa làm gì mà nút báo cáo đã mở"
            }
            return nil
        },

        Case(name: "đổi dấu phân tách là MỘT bước undo") { controller in
            let source = "ma,ten\nA1,\"Cam, Quýt\"\n"
            controller.prepareSelfTestDocument(source)
            controller.setCSVModeForSelfTest(true)

            let buffer = controller.editorDocument.buffer
            let depth = buffer.undoDepth
            controller.changeDelimiterForSelfTest(UInt8(ascii: "\t"))

            // Ô có dấu phẩy KHÔNG còn cần bọc khi đã sang Tab.
            guard buffer.text == "ma\tten\nA1\tCam, Quýt\n" else {
                return "văn bản: \(String(reflecting: buffer.text))"
            }
            guard buffer.undoDepth == depth + 1 else {
                return "undoDepth \(depth) → \(buffer.undoDepth), phải chỉ tăng 1"
            }
            _ = buffer.undo()
            return buffer.text == source ? nil : "một lần undo không về nguyên trạng"
        },

        Case(name: "sửa ô có dấu phẩy thì được bọc ngoặc khi ghi vào văn bản") { controller in
            // Ghi thẳng giá trị có dấu phẩy vào văn bản sẽ tách nó thành hai cột và làm lệch
            // toàn bộ hàng — đúng loại hỏng dữ liệu mà người dùng chỉ phát hiện ra rất muộn.
            controller.prepareSelfTestDocument("ma,ten\nA,Cam\nB,An\n")
            controller.showTableViewForSelfTest()
            defer { controller.showTextViewForSelfTest() }

            controller.csvTable.commitEditForSelfTest(displayRow: 0, column: 1, value: "Cam, Quýt")
            guard controller.editorDocument.buffer.text == "ma,ten\nA,\"Cam, Quýt\"\nB,An\n" else {
                return "văn bản: \(String(reflecting: controller.editorDocument.buffer.text))"
            }
            // Và bảng đọc lại vẫn thấy đúng HAI cột, không phải ba.
            guard controller.csvTable.valuesForSelfTest(displayRow: 0) == ["A", "Cam, Quýt"] else {
                return "bảng đọc lại: \(controller.csvTable.valuesForSelfTest(displayRow: 0))"
            }
            return nil
        },

        // MARK: - FR-KNW-901 · FR-KNW-902 — chế độ JSONL

        /// Đường ghép đầy đủ: mở panel → kiểm → bấm một dòng lỗi → con nháy nhảy tới đó.
        ///
        /// Bài kiểm ở lõi chấm được `JSONLScan` trả đúng số hiệu dòng. Nó KHÔNG chấm được rằng
        /// số hiệu ấy đi tới đúng chỗ trong tài liệu — giữa hai thứ có bảng danh sách, phép
        /// đổi dòng-sang-offset, và việc nạp lại cửa sổ văn bản.
        Case(name: "JSONL: bấm dòng lỗi thì con nháy nhảy tới đúng dòng") { controller in
            controller.prepareSelfTestDocument("""
                {"id":"c1","text":"một"}
                {hỏng}
                {"id":"c3","text":"ba"}

                """)
            controller.showJSONLPanel(nil)
            controller.selectJSONLTabForSelfTest(.problems)
            guard controller.jsonlListedLinesForSelfTest == [1] else {
                return "danh sách lỗi: \(controller.jsonlListedLinesForSelfTest)"
            }
            controller.selectJSONLLineForSelfTest(1)
            let caret = controller.editorView.selectedDocumentRange.lowerBound
            let line = controller.editorDocument.buffer.lineNumber(atOffset: caret)
            guard line == 1 else { return "con nháy ở dòng \(line), đáng lẽ dòng 1" }
            return nil
        },

        /// Thẻ bản ghi đi THEO con nháy — «song song văn bản thô» của FR-KNW-901.
        ///
        /// Và dòng HỎNG phải hiện văn bản thô kèm lời báo, chứ không hiện một thẻ trống: người
        /// dùng đang đứng ở đó để sửa nó.
        Case(name: "JSONL: thẻ bản ghi đi theo con nháy, dòng hỏng hiện văn bản thô") {
            controller in
            controller.prepareSelfTestDocument("""
                {"id":"c1","text":"một"}
                {hỏng}

                """)
            controller.showJSONLPanel(nil)
            controller.selectJSONLTabForSelfTest(.record)
            controller.selectJSONLLineForSelfTest(0)
            guard controller.jsonlCardTextForSelfTest.contains("\"id\": \"c1\"") else {
                return "thẻ dòng 0: \(controller.jsonlCardTextForSelfTest)"
            }
            // In ĐẸP chứ không chép nguyên dòng — thẻ phải xuống dòng.
            guard controller.jsonlCardTextForSelfTest.contains("\n") else {
                return "thẻ không in đẹp: \(controller.jsonlCardTextForSelfTest)"
            }
            controller.selectJSONLLineForSelfTest(1)
            guard controller.jsonlCardTextForSelfTest == "{hỏng}" else {
                return "thẻ dòng hỏng: \(controller.jsonlCardTextForSelfTest)"
            }
            guard controller.jsonlSummaryForSelfTest.contains("không phải JSON hợp lệ") else {
                return "tóm tắt dòng hỏng: \(controller.jsonlSummaryForSelfTest)"
            }
            return nil
        },

        /// Lọc theo metadata ra đúng những dòng khớp, và chúng bấm được.
        Case(name: "JSONL: lọc theo metadata ra đúng dòng và bấm nhảy được") { controller in
            controller.prepareSelfTestDocument("""
                {"id":"c1","text":"một","nguon":"web"}
                {"id":"c2","text":"hai","nguon":"pdf"}
                {"id":"c3","text":"ba","nguon":"web"}

                """)
            controller.showJSONLPanel(nil)
            controller.runJSONLFilterForSelfTest(field: "nguon", value: "\"web\"")
            guard controller.jsonlListedLinesForSelfTest == [0, 2] else {
                return "lọc ra: \(controller.jsonlListedLinesForSelfTest)"
            }
            controller.selectJSONLLineForSelfTest(2)
            let caret = controller.editorView.selectedDocumentRange.lowerBound
            guard controller.editorDocument.buffer.lineNumber(atOffset: caret) == 2 else {
                return "bấm kết quả lọc không nhảy tới dòng 2"
            }
            return nil
        },

        /// Báo cáo chunk phải NÓI RA giới hạn của chính nó.
        ///
        /// Cùng luật với khối "Phương pháp" của FR-MIN: một bảng số không nói nó đếm bằng gì
        /// thì người đọc sẽ mặc định nó đếm bằng thứ họ quen — ở đây là token của model.
        Case(name: "JSONL: báo cáo chunk nói ra giới hạn của phép đếm") { controller in
            controller.prepareSelfTestDocument("""
                {"id":"c1","text":"một hai ba","nguon":"web"}
                {"id":"c2","text":"bốn năm sáu bảy","nguon":"pdf"}

                """)
            controller.showJSONLPanel(nil)
            controller.selectJSONLTabForSelfTest(.chunks)
            let text = controller.jsonlCardTextForSelfTest
            for needle in ["PHƯƠNG PHÁP", "KHÔNG phải bộ tách của model",
                           "không theo cụm hiển thị", "trùng GẦN"] {
                guard text.contains(needle) else { return "báo cáo thiếu «\(needle)»" }
            }
            // Và nó phải nói trường văn bản nào đã dùng — mọi con số phía trên phụ thuộc nó.
            guard controller.jsonlSummaryForSelfTest.contains("text") else {
                return "tóm tắt không nói trường văn bản: \(controller.jsonlSummaryForSelfTest)"
            }
            return nil
        },

        // MARK: - FR-KNW-918 · FR-KNW-919 — Retrieval Lab

        /// Đường ghép đầy đủ: mở corpus thật → dựng chỉ mục → hỏi → top-k kèm điểm và TÔ SÁNG.
        ///
        /// Bài kiểm ở lõi chấm được `BM25Index.highlights` trả đúng dải UTF-16. Nó KHÔNG chấm
        /// được rằng dải ấy tô đúng chữ trên màn hình — giữa hai thứ có phép ghép chuỗi kết quả
        /// (số hạng, điểm, định danh, rồi mới tới nội dung chunk), và một sai số một ký tự ở
        /// đó sẽ tô lệch mà vẫn "có tô".
        Case(name: "Retrieval Lab: hỏi ra top-k và tô sáng ĐÚNG chữ khớp") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("retrieval-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = folder + "/chunks.jsonl"
            try? """
                {"id":"c1","text":"hợp đồng mua bán nhà đất"}
                {"id":"c2","text":"biên bản bàn giao thiết bị"}
                {"id":"c3","text":"hợp đồng lao động thời vụ"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)
            controller.askRetrievalForSelfTest("hợp đồng")

            let text = controller.retrievalResultTextForSelfTest
            guard text.contains("hợp đồng mua bán nhà đất") else {
                return "kết quả không có chunk c1: \(text)"
            }
            guard !text.contains("biên bản bàn giao") else {
                return "chunk không khớp lại lọt vào kết quả"
            }
            // Điểm BM25 phải hiện ra, không chỉ nội dung.
            guard text.contains("#1") else { return "thiếu số hạng: \(text)" }

            // Tô sáng phải trúng ĐÚNG những chữ khớp, không trúng chữ khác.
            let ranges = controller.retrievalHighlightsForSelfTest
            guard !ranges.isEmpty else { return "không tô sáng gì" }
            let ns = text as NSString
            let words = ranges.map { ns.substring(with: $0) }
            guard Set(words) == Set(["hợp", "đồng"]) else {
                return "tô sáng nhầm chữ: \(words)"
            }
            return nil
        },

        /// Hai núm k1/b phải mang theo GIẢI THÍCH đổi theo giá trị — đặc tả đòi thẳng.
        ///
        /// Một tooltip tĩnh kiểu "k1 điều khiển độ bão hoà tần suất" không giúp ai quyết định
        /// gì; câu ở đây phải nói giá trị ĐANG ĐẶT làm gì.
        Case(name: "Retrieval Lab: núm k1/b có giải thích đổi theo giá trị") { controller in
            controller.showRetrievalPanel(nil)
            controller.tuneRetrievalForSelfTest(k1: 0, b: 0)
            let low = controller.retrievalTuningNoteForSelfTest
            controller.tuneRetrievalForSelfTest(k1: 3, b: 1)
            let high = controller.retrievalTuningNoteForSelfTest
            guard low != high else { return "giải thích KHÔNG đổi theo giá trị: \(low)" }
            guard low.contains("MỘT lần"), high.contains("thưởng mạnh") else {
                return "giải thích không nói ra hệ quả: «\(low)» / «\(high)»"
            }
            guard low.contains("bỏ qua độ dài"), high.contains("phạt tối đa") else {
                return "giải thích b không nói ra hệ quả: «\(low)» / «\(high)»"
            }
            return nil
        },

        /// Đổi k1 thì kết quả được xếp lại — núm phải THẬT SỰ nối vào chỉ mục.
        ///
        /// Bài này bắt được cái lỗi khó thấy nhất của một thanh trượt: nó đổi nhãn, đổi câu
        /// giải thích, và không đổi gì khác.
        Case(name: "Retrieval Lab: đổi k1 thì chỉ mục được dựng lại") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("retune-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = folder + "/chunks.jsonl"
            // c1 lặp «hợp đồng» ba lần và DÀI; c2 nhắc một lần và NGẮN. Hai chunk ấy đổi chỗ
            // cho nhau khi b đi từ 0 (bỏ qua độ dài) lên 1 (phạt tối đa theo độ dài).
            try? """
                {"id":"c1","text":"hợp đồng hợp đồng hợp đồng và rất nhiều chữ khác nữa để chunk này dài hẳn ra so với chunk kia trong corpus nhỏ này"}
                {"id":"c2","text":"hợp đồng"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)
            controller.tuneRetrievalForSelfTest(k1: 1.2, b: 0)
            controller.askRetrievalForSelfTest("hợp đồng")
            let withoutLengthPenalty = controller.retrievalResultTextForSelfTest
            controller.tuneRetrievalForSelfTest(k1: 1.2, b: 1)
            let withLengthPenalty = controller.retrievalResultTextForSelfTest
            guard withoutLengthPenalty != withLengthPenalty else {
                return "đổi b từ 0 sang 1 KHÔNG đổi gì — núm chưa nối vào chỉ mục"
            }
            return nil
        },

        /// Sinh báo cáo `.greport.md` TÁI LẬP ĐƯỢC, không phải một bảng dùng một lần.
        Case(name: "Retrieval Lab: sinh báo cáo .greport.md chạy lại được") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("golden-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = folder + "/chunks.jsonl"
            let golden = folder + "/golden.jsonl"
            try? """
                {"id":"c1","text":"hợp đồng mua bán nhà đất"}
                {"id":"c2","text":"biên bản bàn giao thiết bị"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)
            try? #"""
                {"qid":"q1","question":"hợp đồng","relevant_ids":["c1"]}
                """#.write(toFile: golden, atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)
            controller.makeRetrievalReport(corpus: corpus, golden: golden)

            let text = controller.editorDocument.buffer.text
            guard text.contains("```retrieval") else { return "không sinh khối retrieval" }
            // Đường dẫn phải TƯƠNG ĐỐI: báo cáo nằm cạnh corpus và đi vào git cùng nó.
            guard text.contains("corpus: chunks.jsonl"), text.contains("golden: golden.jsonl")
            else { return "đường dẫn không tương đối: \(text)" }

            // Và nó phải CHẠY được — đó là nghĩa của "tái lập được".
            let document = try? ReportDocument.parse(text)
            guard let document else { return "báo cáo sinh ra không phân tích được" }
            let rendered = try? ReportRenderer.render(
                document, in: TextBuffer(original: MemoryByteSource([])), dialect: .comma,
                options: ReportRenderer.Options(basePath: folder))
            guard let rendered, rendered.failures.isEmpty else {
                return "báo cáo sinh ra chạy KHÔNG được: \(rendered?.failures ?? [])"
            }
            guard rendered.html.contains("recall@10") else {
                return "báo cáo không có chỉ số recall"
            }
            return nil
        },

        // MARK: - FR-KNW-905 — Graph Preview cho DOT

        /// Đường ghép đầy đủ: mở tệp DOT thật → vẽ bằng CHÍNH bộ vẽ mermaid → bấm node nhảy
        /// tới đúng dòng KHAI trong tệp DOT.
        ///
        /// Bài kiểm ở lõi chấm được phép chuyển DOT → Mermaid. Nó KHÔNG chấm được rằng bản
        /// chuyển ấy mermaid vẽ ra được, cũng không chấm được rằng số dòng bấm-node quy về tệp
        /// DOT gốc chứ không quy về bản chuyển — và đó là chỗ dễ lệch nhất, vì bản chuyển có
        /// một dòng đầu (`flowchart TD`) mà tệp DOT không có.
        Case(name: "Graph Preview: DOT vẽ được và bấm node nhảy đúng dòng KHAI") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dot-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.dot")
            // Node `b` được NHẮC ở dòng 2 và KHAI ở dòng 3 — hai dòng khác nhau, nên bài kiểm
            // phân biệt được "nhảy tới chỗ định nghĩa" với "nhảy tới chỗ nhắc tên".
            try? """
                digraph G {
                    a -> b;
                    b [label="Duyệt hồ sơ"];
                    b -> c [label="đạt"];
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.isMermaidPanelVisible else {
                return "không mở được Mermaid Studio"
            }
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            if let reason = controller.mermaidFailureReasonForSelfTest {
                return "bộ render không dựng được: \(reason)"
            }
            guard controller.mermaidPanel.failureCountForSelfTest == 0 else {
                return "bản chuyển từ DOT không vẽ được: "
                    + controller.mermaidPanel.headerTextForSelfTest
            }

            // Bấm node theo CHỮ hiện trên nó → nhảy tới dòng KHAI (dòng 2, 0-based).
            controller.clickMermaidElementForSelfTest(diagram: 0, text: "Duyệt hồ sơ")
            let caret = controller.editorView.selectedDocumentRange.lowerBound
            let line = controller.editorDocument.buffer.lineNumber(atOffset: caret)
            guard line == 2 else {
                return "bấm node nhảy tới dòng \(line), đáng lẽ dòng khai là 2"
            }
            return nil
        },

        /// Chiều ngược lại: con nháy ở một dòng DOT thì node tương ứng sáng lên.
        ///
        /// Tên node ở chế độ DOT phải lấy từ chính đồ thị đã đọc, không lấy bằng bộ tách của
        /// Mermaid — cú pháp hai bên khác nhau, và tách nhầm thì tô sáng nhầm node.
        Case(name: "Graph Preview: con nháy trên dòng DOT thì node tương ứng sáng") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dotfocus-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.dot")
            try? """
                digraph G {
                    a [label="Nhận hồ sơ"];
                    b [label="Duyệt hồ sơ"];
                    a -> b;
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            // Đưa con nháy vào dòng khai node `b`.
            let offset = controller.editorDocument.buffer.contentRange(ofLine: 2).lowerBound
            controller.editorView.setSelection(MultiSelection(caretAt: offset))
            controller.focusMermaidElementAtCaret()
            guard let hits = controller.waitForMermaidHitsForSelfTest(expected: 1) else {
                return "không tô sáng node nào cho dòng khai của b"
            }
            guard hits == 1 else { return "tô sáng \(hits) phần tử, mong 1" }
            return nil
        },

        /// Phần DOT mà phép chuyển BỎ QUA phải hiện ra, không nuốt.
        ///
        /// Một sơ đồ vẽ thiếu mà không có gì báo là tệ hơn hẳn một sơ đồ không vẽ — và người
        /// dùng sẽ tin vào một hình sai.
        Case(name: "Graph Preview: phần DOT bị bỏ qua được nói ra trên panel") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dotwarn-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.dot")
            try? """
                digraph G {
                    rankdir=LR;
                    subgraph cluster_0 {
                        a -> b;
                    }
                    b -> c;
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            let header = controller.mermaidPanel.headerTextForSelfTest
            guard header.contains("⚠") else {
                return "panel không nói ra phần bị bỏ qua: \(header)"
            }
            guard header.contains("node"), header.contains("cạnh") else {
                return "panel không nói số node/cạnh đã đọc được: \(header)"
            }
            // Và nó KHÔNG được nhuộm đỏ: "subgraph đọc phẳng" là giới hạn đã biết, không phải
            // một thứ hỏng.
            guard controller.mermaidPanel.failureCountForSelfTest == 0 else {
                return "cảnh báo bị coi là lỗi"
            }
            return nil
        },

        // MARK: - FR-KNW-915 — Soạn thảo Graph trực quan

        /// Đường ghép đầy đủ của cử chỉ KÉO: bật công tắc → kéo giữa hai node TRÊN HÌNH → một
        /// cạnh mới trong VĂN BẢN → một lần Cmd-Z trả về nguyên trạng.
        ///
        /// Cú kéo được diễn bằng `MouseEvent` thật gửi vào trang, không phải bằng cách gọi
        /// thẳng `handleGraphEditGesture`. Khác biệt là cả giá trị của bài kiểm: gọi thẳng thì
        /// công tắc `editing`, phép bỏ cú thả-tại-chỗ, và phép đọc `data-index` — tức toàn bộ
        /// phần JavaScript — không hề chạy.
        Case(name: "Soạn Graph: kéo giữa hai node trên hình sinh cạnh trong văn bản") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dotedit-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.dot")
            try? """
                digraph G {
                    // chú thích của người dùng
                    a [label="Nhận hồ sơ"];
                    b [label="Duyệt hồ sơ"];
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            let goc = controller.editorDocument.buffer.text
            let depth = controller.editorDocument.buffer.undoDepth

            controller.mermaidPanel.setVisualEditingForSelfTest(true)
            controller.lastGraphEditForSelfTest = nil
            let answer = controller.dragOnGraphForSelfTest(
                from: "Nhận hồ sơ", to: "Duyệt hồ sơ")
            guard answer == "đã gửi" else {
                return "trang không diễn được cú kéo: \(answer ?? "không trả lời")"
            }
            let text = controller.editorDocument.buffer.text
            guard text != goc else {
                return "kéo xong văn bản không đổi — \(controller.lastGraphEditForSelfTest ?? "không rõ lý do")"
            }
            let graph = DOTGraph.parse(text)
            guard graph.edges.contains(where: { $0.from == "a" && $0.to == "b" }) else {
                return "không sinh ra cạnh a → b:\n\(text)"
            }
            // Chú thích và thụt lề của người dùng phải còn nguyên — đặc tả đòi đúng vế này.
            guard text.contains("// chú thích của người dùng") else {
                return "phép sửa làm mất chú thích:\n\(text)"
            }
            guard text.contains("    \"a\" -> \"b\";") else {
                return "câu lệnh mới không theo thụt lề hiện hành:\n\(text)"
            }
            // MỘT bước hoàn tác, không phải hai.
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "một cú kéo tạo \(controller.editorDocument.buffer.undoDepth - depth) "
                    + "bước hoàn tác, phải là 1"
            }
            _ = controller.editorDocument.buffer.undo()
            guard controller.editorDocument.buffer.text == goc else {
                return "một lần hoàn tác không trả về nguyên trạng"
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(false)
            return nil
        },

        /// ĐỐI CHỨNG ÂM của chính công tắc: tắt thì cùng cú kéo ấy KHÔNG được sửa gì.
        ///
        /// Không có bài này thì bài trên vẫn xanh kể cả khi công tắc chẳng nối vào đâu — và
        /// khi ấy mọi cú kéo để bôi đen chữ trên sơ đồ đều lặng lẽ thêm cạnh vào tệp.
        Case(name: "Soạn Graph: công tắc TẮT thì cú kéo không sửa gì") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dotoff-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.dot")
            try? """
                digraph G {
                    a [label="Nhận hồ sơ"];
                    b [label="Duyệt hồ sơ"];
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(false)
            guard controller.mermaidPanel.isVisualEditBoxVisibleForSelfTest else {
                return "công tắc soạn trực quan không hiện với tài liệu DOT"
            }
            let goc = controller.editorDocument.buffer.text
            let depth = controller.editorDocument.buffer.undoDepth
            controller.lastGraphEditForSelfTest = nil
            _ = controller.dragOnGraphForSelfTest(from: "Nhận hồ sơ", to: "Duyệt hồ sơ")
            guard controller.editorDocument.buffer.text == goc else {
                return "công tắc TẮT mà văn bản vẫn đổi:\n"
                    + controller.editorDocument.buffer.text
            }
            guard controller.editorDocument.buffer.undoDepth == depth else {
                return "công tắc TẮT mà vẫn ghi một bước hoàn tác"
            }
            return nil
        },

        /// Double-click tới ĐÚNG node, và phép đổi nhãn áp được.
        ///
        /// Chia làm hai nửa vì `Unattended.ask` cố tình không tự bấm OK: nửa cử chỉ chấm bằng
        /// dấu vết node đã phân giải, nửa áp chấm bằng cách gọi thẳng phép sửa. Làm yếu
        /// `Unattended` để bài chạy một mạch thì hỏng đúng thứ nó tồn tại để bảo vệ.
        Case(name: "Soạn Graph: double-click tới đúng node, đổi nhãn giữ định danh") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dotlabel-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.dot")
            try? """
                digraph G {
                    a [label="Nhận hồ sơ"];
                    b [label="Duyệt hồ sơ"];
                    a -> b;
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(true)
            controller.lastGraphEditForSelfTest = nil
            let answer = controller.doubleClickOnGraphForSelfTest("Duyệt hồ sơ")
            guard answer == "đã gửi" else {
                return "trang không diễn được double-click: \(answer ?? "không trả lời")"
            }
            // Chữ trên hình là NHÃN; thứ đi tiếp phải là ĐỊNH DANH. Lẫn hai thứ thì phép sửa
            // đi tìm một node tên «Duyệt hồ sơ» và không bao giờ thấy.
            guard controller.lastGraphEditForSelfTest == "ask-label: b" else {
                return "double-click phân giải ra: "
                    + (controller.lastGraphEditForSelfTest ?? "không gì cả")
            }

            let depth = controller.editorDocument.buffer.undoDepth
            controller.setGraphLabel(node: "b", to: "Thẩm định hồ sơ")
            let graph = DOTGraph.parse(controller.editorDocument.buffer.text)
            guard graph.nodes.first(where: { $0.name == "b" })?.label == "Thẩm định hồ sơ" else {
                return "nhãn không đổi:\n\(controller.editorDocument.buffer.text)"
            }
            guard graph.edges.count == 1 else {
                return "đổi nhãn làm hỏng cạnh: còn \(graph.edges.count) cạnh"
            }
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "đổi nhãn không phải MỘT bước hoàn tác"
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(false)
            return nil
        },

        /// Xoá node bằng BÀN PHÍM (vùng chọn trong văn bản) — NFR-USE-03 đòi đường không chuột.
        ///
        /// Và chấm cái bẫy riêng của phép xoá: bỏ sót cạnh treo thì DOT tự sinh lại node từ
        /// chính những cạnh ấy, nên node "đã xoá" hiện lại ngay lượt vẽ sau.
        Case(name: "Soạn Graph: xoá node kéo theo cạnh, node không quay lại") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dotdel-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.dot")
            try? """
                digraph G {
                    a [label="Nhận hồ sơ"];
                    b [label="Duyệt hồ sơ"];
                    c [label="Trả kết quả"];
                    a -> b;
                    b -> c;
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            // Con nháy lên dòng khai node `b` (dòng 2, 0-based).
            let offset = controller.editorDocument.buffer.contentRange(ofLine: 2).lowerBound
            controller.editorView.setSelection(MultiSelection(caretAt: offset))
            let depth = controller.editorDocument.buffer.undoDepth
            controller.removeGraphElementFromSelection(confirmed: true)

            let graph = DOTGraph.parse(controller.editorDocument.buffer.text)
            guard !graph.nodes.contains(where: { $0.name == "b" }) else {
                return "node b quay lại từ cạnh treo:\n"
                    + controller.editorDocument.buffer.text
            }
            guard graph.edges.isEmpty else {
                return "còn \(graph.edges.count) cạnh treo:\n"
                    + controller.editorDocument.buffer.text
            }
            guard graph.nodes.count == 2 else {
                return "xoá nhầm node khác: còn \(graph.nodes.count) node"
            }
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "xoá node tạo \(controller.editorDocument.buffer.undoDepth - depth) "
                    + "bước hoàn tác, phải là 1"
            }
            return nil
        },

        // MARK: - FR-MMD-004 — Soạn thảo sơ đồ Mermaid trực quan

        /// Bài kiểm ĐẮT NHẤT của cụm, và là bài duy nhất chấm được thứ đáng lo nhất: **câu lệnh
        /// ta sinh ra có phải mermaid hợp lệ không.**
        ///
        /// Bảng phương ngữ trong `MermaidEdit.declaration(id:label:kind:)` là chỗ dễ sai nhất —
        /// `class Foo["Nhãn"]`, `ZZ["Nhãn"] { }` của ER, `participant A as X` — và sai nghĩa là
        /// **sơ đồ đang chạy bỗng không vẽ được nữa**. Một bài kiểm so chuỗi sẽ xanh với mọi
        /// cú pháp bịa ra; chỉ có chạy qua chính mermaid.js mới trả lời được.
        Case(name: "Soạn Mermaid: bốn phương ngữ vẫn VẼ ĐƯỢC sau thêm/nối/sửa nhãn") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mmdedit-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            let fixtures: [(String, String, String)] = [
                ("flowchart", "A", """
                    flowchart TD
                        A["Nhận hồ sơ"] --> B["Duyệt hồ sơ"]
                    """),
                ("state", "ChoDuyet", """
                    stateDiagram-v2
                        [*] --> ChoDuyet
                        ChoDuyet --> DaDuyet : đạt
                    """),
                ("class", "HoSo", """
                    classDiagram
                        class HoSo
                        class NguoiDuyet
                        HoSo --> NguoiDuyet : gửi tới
                    """),
                ("er", "KHACH", """
                    erDiagram
                        KHACH ||--o{ DONHANG : "đặt"
                    """),
                ("sequence", "A", """
                    sequenceDiagram
                        participant A as Người gửi
                        participant B as Người nhận
                        A->>B: chào
                    """),
            ]

            for (name, anchor, source) in fixtures {
                let path = (folder as NSString).appendingPathComponent("\(name).mmd")
                try? source.write(toFile: path, atomically: true, encoding: .utf8)
                controller.open(path: path, line: nil, column: nil, readOnly: false)
                var before = controller.mermaidRenderCountForSelfTest
                controller.openMermaidStudioForSelfTest()
                controller.refreshMermaidPreview()
                guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                    return "\(name): hết giờ chờ vẽ lần đầu"
                }
                guard controller.mermaidPanel.failureCountForSelfTest == 0 else {
                    return "\(name): MẪU đã không vẽ được, bài kiểm sai chứ không phải mã sai — "
                        + controller.mermaidPanel.headerTextForSelfTest
                }

                // Ba phép, mỗi phép vẽ lại và phải còn vẽ được.
                let ops: [(String, (String) throws -> [TextEdit])] = [
                    ("thêm phần tử", { try MermaidEdit.addNode(id: "ZZ", label: "Thử", in: $0) }),
                    ("nối", { try MermaidEdit.addEdge(from: anchor, to: "ZZ", in: $0) }),
                    ("sửa nhãn", { try MermaidEdit.setLabel(of: "ZZ", to: "Đã sửa", in: $0) }),
                ]
                for (opName, body) in ops {
                    guard let block = controller.freshMermaidBlock() else {
                        return "\(name): không tìm thấy khối sơ đồ"
                    }
                    before = controller.mermaidRenderCountForSelfTest
                    controller.lastGraphEditForSelfTest = nil
                    controller.applyMermaidEdit("tự kiểm", block: block, body)
                    guard controller.lastGraphEditForSelfTest == "tự kiểm" else {
                        return "\(name)/\(opName) không áp được: "
                            + (controller.lastGraphEditForSelfTest ?? "không rõ")
                    }
                    guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                        return "\(name)/\(opName): hết giờ chờ vẽ lại"
                    }
                    guard controller.mermaidPanel.failureCountForSelfTest == 0 else {
                        return "\(name)/\(opName) sinh ra mã KHÔNG VẼ ĐƯỢC: "
                            + controller.mermaidPanel.headerTextForSelfTest + "\n"
                            + controller.editorDocument.buffer.text
                    }
                }
                // Và cấu trúc đọc lại được đúng như vừa sửa.
                let m = MermaidEdit.parse(controller.editorDocument.buffer.text)
                guard m.node("ZZ")?.label == "Đã sửa" else {
                    return "\(name): nhãn không về đúng chỗ:\n"
                        + controller.editorDocument.buffer.text
                }
                guard m.edges.contains(where: { $0.from == anchor && $0.to == "ZZ" }) else {
                    return "\(name): cạnh mới mất:\n" + controller.editorDocument.buffer.text
                }
            }
            return nil
        },

        /// Cử chỉ KÉO thật trên sơ đồ mermaid — cùng đường JavaScript mà FR-KNW-915 dựng, nay
        /// đi tiếp sang `MermaidEdit` thay vì `GraphEdit`.
        Case(name: "Soạn Mermaid: kéo giữa hai node sinh cạnh, một bước hoàn tác") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mmddrag-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.mmd")
            try? """
                flowchart TD
                    %% chú thích của người dùng
                    A["Nhận hồ sơ"]
                    B["Duyệt hồ sơ"]
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ"
            }
            let goc = controller.editorDocument.buffer.text
            let depth = controller.editorDocument.buffer.undoDepth

            controller.mermaidPanel.setVisualEditingForSelfTest(true)
            controller.lastGraphEditForSelfTest = nil
            let answer = controller.dragOnGraphForSelfTest(
                from: "Nhận hồ sơ", to: "Duyệt hồ sơ")
            guard answer == "đã gửi" else {
                return "trang không diễn được cú kéo: \(answer ?? "không trả lời")"
            }
            let text = controller.editorDocument.buffer.text
            guard text != goc else {
                return "kéo xong văn bản không đổi — "
                    + (controller.lastGraphEditForSelfTest ?? "không rõ lý do")
            }
            let m = MermaidEdit.parse(text)
            guard m.edges.contains(where: { $0.from == "A" && $0.to == "B" }) else {
                return "không sinh ra cạnh A --> B:\n\(text)"
            }
            guard text.contains("%% chú thích của người dùng") else {
                return "phép sửa làm mất chú thích:\n\(text)"
            }
            guard text.contains("    A --> B") else {
                return "câu lệnh mới không theo thụt lề hiện hành:\n\(text)"
            }
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "một cú kéo tạo \(controller.editorDocument.buffer.undoDepth - depth) "
                    + "bước hoàn tác, phải là 1"
            }
            _ = controller.editorDocument.buffer.undo()
            guard controller.editorDocument.buffer.text == goc else {
                return "một lần hoàn tác không trả về nguyên trạng"
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(false)
            return nil
        },

        /// Khối ` ```mermaid ` nằm GIỮA một tệp Markdown: sửa đổi phải rơi đúng vào khối.
        ///
        /// Đây là chỗ dễ lệch nhất của cả tính năng — `MermaidEdit` tính theo nguồn sơ đồ, còn
        /// buffer chứa cả tài liệu. Cùng họ với lỗi số dòng đã gặp ở FR-KNW-905.
        Case(name: "Soạn Mermaid: khối trong Markdown sửa đúng chỗ, phần chữ không đụng") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mmdmd-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("tai-lieu.md")
            try? """
                # Quy trình

                Đoạn chữ TRƯỚC sơ đồ, không được đụng tới.

                ```mermaid
                flowchart TD
                    A["Nhận hồ sơ"]
                    B["Duyệt hồ sơ"]
                ```

                Đoạn chữ SAU sơ đồ.
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ"
            }
            guard let block = controller.freshMermaidBlock(index: 0) else {
                return "không tìm thấy khối mermaid trong tệp Markdown"
            }
            controller.lastGraphEditForSelfTest = nil
            controller.applyMermaidEdit("tự kiểm", block: block) {
                try MermaidEdit.addEdge(from: "A", to: "B", in: $0)
            }
            let text = controller.editorDocument.buffer.text
            guard text.contains("Đoạn chữ TRƯỚC sơ đồ, không được đụng tới."),
                  text.contains("Đoạn chữ SAU sơ đồ.") else {
                return "sửa đổi rơi ra ngoài khối:\n\(text)"
            }
            let blocks = MermaidDocument.blocks(in: text)
            guard blocks.count == 1 else { return "hàng rào khối bị hỏng:\n\(text)" }
            guard MermaidEdit.parse(blocks[0].source).edges.count == 1 else {
                return "cạnh không vào đúng khối:\n\(text)"
            }
            return nil
        },

        /// Loại chưa soạn trực quan được phải NÓI RA — đặc tả đòi *"hiển thị rõ 'chỉ soạn text'"*.
        Case(name: "Soạn Mermaid: mindmap nói rõ CHỈ SOẠN TEXT, và không sửa gì") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mmdtext-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.mmd")
            try? """
                mindmap
                  root((Hồ sơ))
                    Tiếp nhận
                    Thẩm định
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ"
            }
            let goc = controller.editorDocument.buffer.text
            controller.lastVisualEditNoticeForSelfTest = nil
            controller.mermaidPanel.setVisualEditingForSelfTest(true)
            let notice = controller.lastVisualEditNoticeForSelfTest ?? ""
            guard notice.contains("chỉ soạn text") else {
                return "bật công tắc trên mindmap mà không nói gì: «\(notice)»"
            }
            guard notice.count > "chỉ soạn text".count + 20 else {
                return "nói «chỉ soạn text» mà không nói VÌ SAO: «\(notice)»"
            }
            // Và cử chỉ trên đó KHÔNG được sửa gì.
            controller.lastGraphEditForSelfTest = nil
            _ = controller.dragOnGraphForSelfTest(from: "Tiếp nhận", to: "Thẩm định")
            guard controller.editorDocument.buffer.text == goc else {
                return "mindmap bị sửa dù không hỗ trợ:\n"
                    + controller.editorDocument.buffer.text
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(false)
            return nil
        },

        /// gantt và pie không có hai đầu để kéo — chúng sửa qua BẢNG THUỘC TÍNH, đúng như đặc tả
        /// kê riêng cho hai loại này.
        Case(name: "Soạn Mermaid: bảng thuộc tính sửa được pie, mỗi ô một bước hoàn tác") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mmdpie-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.mmd")
            try? """
                pie showData
                    title Tỉ lệ hồ sơ
                    "Đạt" : 386
                    "Trượt" : 85
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ"
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(true)
            guard controller.mermaidPanel.isPropertyTableVisibleForSelfTest else {
                return "bật soạn trực quan trên pie mà bảng thuộc tính không hiện"
            }
            guard controller.mermaidPanel.propertyTable.rowCountForSelfTest == 2 else {
                return "bảng có \(controller.mermaidPanel.propertyTable.rowCountForSelfTest) "
                    + "mục, mong 2 — «title» không được tính là một lát bánh"
            }

            let depth = controller.editorDocument.buffer.undoDepth
            let renderBefore = controller.mermaidRenderCountForSelfTest
            controller.mermaidPanel.propertyTable.editForSelfTest(
                row: 0, label: "Đạt yêu cầu", value: "400")
            guard controller.waitForMermaidRenderForSelfTest(atLeast: renderBefore + 1) else {
                return "hết giờ chờ vẽ lại sau khi sửa bảng"
            }
            guard controller.mermaidPanel.failureCountForSelfTest == 0 else {
                return "sửa bảng xong sơ đồ KHÔNG vẽ được: "
                    + controller.mermaidPanel.headerTextForSelfTest
            }
            let rows = MermaidEdit.parse(controller.editorDocument.buffer.text).rows
            guard rows.first?.label == "Đạt yêu cầu", rows.first?.value == "400" else {
                return "bảng không ghi vào văn bản:\n"
                    + controller.editorDocument.buffer.text
            }
            guard rows.count == 2 else {
                return "sửa một mục làm hỏng mục khác:\n"
                    + controller.editorDocument.buffer.text
            }
            guard controller.editorDocument.buffer.undoDepth == depth + 1 else {
                return "một ô sửa tạo \(controller.editorDocument.buffer.undoDepth - depth) "
                    + "bước hoàn tác, phải là 1"
            }
            controller.mermaidPanel.setVisualEditingForSelfTest(false)
            return nil
        },

        // MARK: - FR-MMD-008 — Tách khối ra tệp .mmd và nhúng ngược

        /// Vòng đầy đủ: tách → tệp `.mmd` có thật → khối giữ tham chiếu → **sơ đồ vẫn VẼ ĐƯỢC**
        /// → sửa tệp thì tài liệu đổi theo → nhúng ngược trả về nguyên trạng.
        ///
        /// Vế "vẫn vẽ được" là vế đáng tiền nhất. Sau khi tách, thân khối chỉ còn một dòng chú
        /// thích `%%`, nên nếu tầng vẽ không giải tham chiếu thì sơ đồ **biến mất ngay trong
        /// chính tài liệu vừa tách nó** — và một khối trống trông y hệt "tài liệu vốn không có
        /// sơ đồ ở đây".
        Case(name: "Tách sơ đồ: tách ra tệp .mmd, vẫn vẽ được, sửa một nơi, nhúng lại nguyên vẹn") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mmdsplit-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("tai-lieu.md")
            let goc = """
                # Quy trình

                Đoạn chữ TRƯỚC sơ đồ.

                ```mermaid
                flowchart TD
                    A["Nhận hồ sơ"] --> B["Duyệt hồ sơ"]
                ```

                Đoạn chữ SAU sơ đồ.

                """
            try? goc.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            var before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ lần đầu"
            }

            // --- Tách ---
            guard let block = controller.freshMermaidBlock(index: 0) else {
                return "không tìm thấy khối mermaid"
            }
            before = controller.mermaidRenderCountForSelfTest
            controller.lastGraphEditForSelfTest = nil
            controller.splitMermaidBlock(block, to: "so-do.mmd")
            let target = (folder as NSString).appendingPathComponent("so-do.mmd")
            guard FileManager.default.fileExists(atPath: target) else {
                return "không ghi ra tệp .mmd: "
                    + (controller.lastGraphEditForSelfTest ?? "không rõ lý do")
            }
            let tach = controller.editorDocument.buffer.text
            guard tach.contains("%% geditor:file so-do.mmd") else {
                return "khối không giữ dòng tham chiếu:\n\(tach)"
            }
            guard !tach.contains("flowchart TD") else {
                return "thân cũ còn sót trong tài liệu:\n\(tach)"
            }
            guard tach.contains("Đoạn chữ TRƯỚC sơ đồ."), tach.contains("Đoạn chữ SAU sơ đồ.") else {
                return "sửa đổi rơi ra ngoài khối:\n\(tach)"
            }

            // --- Vẫn vẽ được, vì tầng vẽ GIẢI tham chiếu; và SỬA MỘT NƠI ---
            //
            // Hai vế gộp làm một phép kiểm có chủ ý. Kiểm riêng vế "ngay sau khi tách vẫn vẽ
            // được" là **không chứng minh được**: nội dung tệp lúc ấy giống hệt nội dung vừa
            // nằm trong khối, nên một tầng vẽ KHÔNG giải tham chiếu sẽ để nguyên kết quả của
            // lượt vẽ trước — và mọi phép hỏi đều thấy đúng thứ mình mong. Đối chứng âm đã chỉ
            // ra đúng điều đó: tắt phép giải mà bài kiểm vẫn xanh ở vế ấy.
            //
            // Nên tệp rời được sửa thành một nội dung KHÁC HẲN trước khi hỏi. Khi ấy chỉ có
            // một cách để chữ mới hiện trên hình: tầng vẽ đã đọc tệp.
            try? "flowchart TD\n    A[\"Đã đổi ở tệp rời\"]\n"
                .write(toFile: target, atomically: true, encoding: .utf8)
            controller.refreshMermaidPreview()
            // Chờ theo NỘI DUNG, không theo số lượt vẽ.
            //
            // Đếm lượt vẽ ở đây đã cho một bài kiểm đỏ oan: lượt vẽ HOÃN 300 ms sau phím cuối
            // vẫn đang bay khi bài kiểm chốt con số, nên `renderCount + 1` được thoả bởi lượt
            // vẽ CŨ (đọc tệp trước khi sửa) trong khi lượt mới còn trong hàng đợi. Điều bài
            // kiểm này thật sự muốn là "sơ đồ rốt cuộc phản ánh tệp", nên nó hỏi đúng câu ấy.
            // MỘT lần gọi vẽ, không gọi lại nhiều lần. Bản đầu của bài này gọi lại mỗi giây
            // cho "chắc ăn", và chính chỗ ấy giấu một lỗi thật trong `MermaidRenderer.drain`:
            // một lượt vẽ xin trong lúc lượt khác đang chạy bị nuốt mất. Gọi lại là chữa triệu
            // chứng; bài kiểm nay đòi đúng cái phải đúng.
            controller.waitForSelfTestPublic("vẽ theo tệp rời", seconds: 15) {
                controller.mermaidPanel.lastSVGForSelfTest?
                    .contains("Đã đổi ở tệp rời") == true
            }
            guard controller.mermaidPanel.lastSVGForSelfTest?
                .contains("Đã đổi ở tệp rời") == true else {
                return "sửa tệp rời mà sơ đồ trong tài liệu không đổi theo — tầng vẽ không "
                    + "giải tham chiếu, hoặc lượt vẽ bị nuốt: "
                    + controller.mermaidPanel.headerTextForSelfTest
            }
            guard controller.mermaidPanel.failureCountForSelfTest == 0 else {
                return "sơ đồ tham chiếu không vẽ được: "
                    + controller.mermaidPanel.headerTextForSelfTest
            }
            _ = before

            // --- Soạn trực quan trên khối tham chiếu phải TỪ CHỐI, và chỉ ra tệp ---
            controller.lastGraphEditForSelfTest = nil
            if let ref = controller.freshMermaidBlock(index: 0) {
                controller.applyMermaidEdit("tự kiểm", block: ref) {
                    try MermaidEdit.addNode(id: "ZZ", in: $0)
                }
            }
            guard controller.lastGraphEditForSelfTest?.contains("so-do.mmd") == true else {
                return "sửa vào khối tham chiếu mà không bị chặn: "
                    + (controller.lastGraphEditForSelfTest ?? "không nói gì")
            }
            guard controller.editorDocument.buffer.text == tach else {
                return "khối tham chiếu bị ghi đè:\n\(controller.editorDocument.buffer.text)"
            }

            // --- Nhúng ngược ---
            controller.embedMermaidBlock(nil)
            let lai = controller.editorDocument.buffer.text
            guard lai.contains("Đã đổi ở tệp rời"), !lai.contains("geditor:file") else {
                return "nhúng ngược không dán nội dung trở lại:\n\(lai)"
            }
            guard MermaidDocument.blocks(in: lai).count == 1 else {
                return "hàng rào khối hỏng sau khi nhúng:\n\(lai)"
            }
            // Tệp KHÔNG bị xoá: xoá là việc không hoàn tác được bằng Cmd-Z.
            guard FileManager.default.fileExists(atPath: target) else {
                return "nhúng ngược đã xoá mất tệp .mmd"
            }
            return nil
        },

        /// Tam giác chuyển đổi Mermaid ↔ DOT ↔ edge list phải có mặt TRÊN MENU, không chỉ trong
        /// lõi: hai chiều đã chạy được từ FR-KNW-910 mà chưa bao giờ bấm tới được.
        Case(name: "Tách sơ đồ: menu chuyển đổi có đủ tam giác Mermaid ↔ DOT ↔ edge list") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("mmdconv-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("so-do.mmd")
            try? "flowchart TD\n    A[\"Nhận\"] --> B[\"Duyệt\"]\n"
                .write(toFile: path, atomically: true, encoding: .utf8)
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            // Bản xem trước đi qua CHÍNH hàm chuyển đổi (khuôn FR-CSV-406), nên nửa này chấm
            // được mà không cần bấm qua hộp thoại — `Unattended.ask` cố tình trả `.abort`.
            for (tu, den) in [
                (KnowledgeConvert.Format.graphMermaid, KnowledgeConvert.Format.graphEdgeList),
                (.graphEdgeList, .graphMermaid),
                (.graphMermaid, .graphDOT),
            ] {
                controller.chuyenDoiTriThucForSelfTest(from: tu, to: den)
            }
            // Nửa áp: gọi thẳng phép áp đang chờ, đúng cách bài kiểm FR-KNW-910 vẫn làm.
            controller.chuyenDoiTriThucForSelfTest(from: .graphMermaid, to: .graphEdgeList)
            controller.apChuyenDoiTriThuc()
            let edge = controller.editorDocument.buffer.text
            guard edge.contains("A\tB") else {
                return "chuyển sang edge list không ra cạnh A → B:\n\(edge)"
            }
            return nil
        },

        // MARK: - FR-KNW-926 — Golden Set Builder

        /// Đường ghép đầy đủ và ĐẾM SỐ THAO TÁC: gõ câu hỏi → bấm chọn chunk → bấm Lưu.
        ///
        /// Đặc tả tự đặt mục tiêu «≤ 3 click + 1 lần gõ mỗi record», nên bài này đếm thật:
        /// một lần gõ (câu hỏi, đã dùng luôn làm truy vấn) và hai cú bấm (chọn một chunk, bấm
        /// Lưu). Nếu một ngày nào đó việc chọn chunk phải đi qua thêm một hộp thoại, bài này
        /// vẫn xanh — nên nó KHÔNG thay được việc thử tay; nó chỉ giữ cho đường chính không vỡ.
        Case(name: "Golden Set Builder: gõ câu hỏi, bấm chọn, lưu ra JSONL") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("gsb-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
            try? """
                {"id":"c1","text":"hợp đồng mua bán nhà đất","nguon":"web"}
                {"id":"c2","text":"hợp đồng lao động thời vụ","nguon":"pdf"}
                {"id":"c3","text":"biên bản bàn giao thiết bị","nguon":"web"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)
            controller.setLabellingForSelfTest(true)

            // 1 lần gõ: câu hỏi vừa là truy vấn vừa là nội dung record.
            controller.askRetrievalForSelfTest("hợp đồng")
            guard !controller.retrievalResultTextForSelfTest.isEmpty else {
                return "không có kết quả để gán nhãn"
            }
            guard !controller.canSaveGoldenRecordForSelfTest else {
                return "chưa chọn chunk nào mà nút Lưu đã bật"
            }
            // Click 1: chọn kết quả đầu.
            controller.clickRetrievalHitForSelfTest(rank: 0)
            guard controller.canSaveGoldenRecordForSelfTest else {
                return "chọn rồi mà nút Lưu vẫn tắt"
            }
            // Dấu ✓ phải hiện ra — người dùng cần thấy mình vừa chọn cái gì.
            guard controller.retrievalResultTextForSelfTest.contains("✓") else {
                return "không có dấu chọn trên kết quả"
            }
            // Click 2: Lưu.
            controller.saveGoldenRecordForSelfTest()

            let queries = controller.goldenQueriesForSelfTest
            guard queries.count == 1 else { return "\(queries.count) record, mong 1" }
            guard queries[0].question == "hợp đồng" else {
                return "câu hỏi lưu sai: \(queries[0].question)"
            }
            guard queries[0].relevant == ["c1"] else {
                return "id kỳ vọng lưu sai: \(queries[0].relevant)"
            }
            // Và tệp trên đĩa phải nạp lại được bằng chính bộ nạp của FR-KNW-919.
            let reloaded = try? RetrievalEval.loadGoldenSet(
                path: controller.goldenPathForSelfTest)
            guard reloaded?.count == 1, reloaded?[0].relevant == ["c1"] else {
                return "tệp ghi ra không nạp lại được bằng bộ nạp của 919"
            }
            // Lưu xong thì lựa chọn được xoá để gõ câu tiếp theo ngay.
            guard !controller.canSaveGoldenRecordForSelfTest else {
                return "lưu xong mà lựa chọn cũ vẫn còn"
            }
            return nil
        },

        /// Đếm phủ theo NGUỒN, và nguồn chưa có câu hỏi nào phải được kể tên.
        ///
        /// Nguồn không có câu hỏi nào là lỗ hổng lớn nhất của một bộ đánh giá, và nó vô hình
        /// nếu chỉ nhìn danh sách record.
        Case(name: "Golden Set Builder: đếm phủ và kể ra nguồn còn thiếu") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("gsbcov-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
            try? """
                {"id":"c1","text":"hợp đồng mua bán nhà đất","nguon":"web"}
                {"id":"c2","text":"hợp đồng lao động thời vụ","nguon":"pdf"}
                {"id":"c3","text":"biên bản bàn giao thiết bị","nguon":"email"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)
            controller.setLabellingForSelfTest(true)
            controller.askRetrievalForSelfTest("hợp đồng mua bán")
            controller.clickRetrievalHitForSelfTest(rank: 0)
            controller.setGoldenNoteForSelfTest("ca dễ")
            controller.saveGoldenRecordForSelfTest()

            let coverage = controller.goldenCoverageForSelfTest
            guard coverage.contains("1 câu") else { return "không đếm record: \(coverage)" }
            guard coverage.contains("thiếu:") else {
                return "không kể ra nguồn còn thiếu: \(coverage)"
            }
            // Ghi chú phải đi vào record.
            guard controller.goldenQueriesForSelfTest.first?.note == "ca dễ" else {
                return "ghi chú không được lưu"
            }
            return nil
        },

        /// Nút Đánh giá dùng LUÔN bộ đang dựng, không hỏi lại đường dẫn.
        ///
        /// Hỏi lại là hỏi một câu mà người dùng vừa trả lời bằng chính việc họ đang làm — và
        /// trong lượt chạy không người thì hộp chọn tệp sẽ treo cả bộ tự kiểm.
        Case(name: "Golden Set Builder: nút Đánh giá dùng luôn bộ đang dựng") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("gsbrun-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
            try? """
                {"id":"c1","text":"hợp đồng mua bán nhà đất","nguon":"web"}
                {"id":"c2","text":"biên bản bàn giao thiết bị","nguon":"pdf"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)
            controller.setLabellingForSelfTest(true)
            controller.askRetrievalForSelfTest("hợp đồng")
            controller.clickRetrievalHitForSelfTest(rank: 0)
            controller.saveGoldenRecordForSelfTest()

            controller.evaluateFromBuilderForSelfTest()
            let text = controller.editorDocument.buffer.text
            guard text.contains("```retrieval") else {
                return "không sinh báo cáo từ bộ đang dựng"
            }
            guard text.contains("golden: chunks.golden.jsonl") else {
                return "báo cáo không trỏ vào bộ đang dựng: \(text)"
            }
            // Và báo cáo ấy phải CHẠY được ngay.
            guard let document = try? ReportDocument.parse(text),
                  let rendered = try? ReportRenderer.render(
                    document, in: TextBuffer(original: MemoryByteSource([])), dialect: .comma,
                    options: ReportRenderer.Options(basePath: folder)),
                  rendered.failures.isEmpty else {
                return "báo cáo sinh từ builder chạy KHÔNG được"
            }
            guard rendered.html.contains("recall@10") else {
                return "báo cáo không có chỉ số"
            }
            return nil
        },

        // MARK: - FR-KNW-913 — thực thi openCypher tập con

        /// Đường ghép đầy đủ: gõ Cypher → SQL hiện trong Query Workbench → chạy thật trên
        /// DuckDB → kết quả tô sáng ngược lên sơ đồ.
        ///
        /// Ba đầu ra ấy là ba câu riêng của đặc tả, và bài kiểm ở lõi chỉ chấm được cái giữa.
        Case(name: "Cypher: chạy thật, SQL hiện ra, kết quả tô sáng lên sơ đồ") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("cypher-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("do-thi.dot")
            try? """
                digraph G {
                    an [label="An", type="nguoi"];
                    binh [label="Bình", type="nguoi"];
                    chi [label="Chi", type="nhom"];
                    an -> binh [label="gửi"];
                    an -> chi [label="nhắc"];
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            guard controller.isCypherBarVisibleForSelfTest else {
                return "ô Cypher không hiện cho tài liệu DOT"
            }

            controller.runCypherForSelfTest(
                "MATCH (a:nguoi)-[r]->(b) WHERE r.label = 'gửi' RETURN a.name, b.name")

            // 1. Câu SQL phải nằm trong ô của Query Workbench — sửa tiếp được.
            let sql = controller.sqlQueryForSelfTest
            guard sql.contains("JOIN edge"), sql.contains("node AS") else {
                return "SQL không vào ô Query Workbench: \(sql)"
            }
            guard sql.contains("'gửi'") else { return "điều kiện WHERE không vào SQL: \(sql)" }

            // 2. Chạy thật: máy không có DuckDB thì bỏ qua vế này, nói rõ chứ không giả vờ.
            if controller.sqlRowCountForSelfTest == nil {
                return nil
            }
            guard controller.sqlRowCountForSelfTest == 1 else {
                return "\(controller.sqlRowCountForSelfTest ?? -1) hàng, mong 1"
            }

            // 3. Kết quả tô sáng ngược lên sơ đồ.
            guard let hits = controller.waitForMermaidHitsForSelfTest(expected: 2) else {
                return "kết quả không tô sáng node nào"
            }
            guard hits == 2 else { return "tô sáng \(hits) phần tử, mong 2 (An và Bình)" }
            return nil
        },

        /// Cypher sai thì báo lỗi TIẾNG VIỆT nói rõ chỗ, và KHÔNG để ô SQL trống.
        Case(name: "Cypher: truy vấn sai thì nói rõ, không để ô SQL trống") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("cyphererr-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("do-thi.dot")
            try? "digraph { a -> b }".write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }
            // Vượt trần hop — phải từ chối TRƯỚC khi chạy.
            controller.runCypherForSelfTest(
                "MATCH (a)-->(b)-->(c)-->(d)-->(e) RETURN a.name")
            let header = controller.mermaidPanel.headerTextForSelfTest
            guard header.contains("Cypher"), header.contains("trần") else {
                return "không nói rõ lý do từ chối: \(header)"
            }
            return nil
        },

        // MARK: - FR-KNW-914 — thuật toán đồ thị

        /// Ba đích của kết quả, kiểm cả ba trên đường sản phẩm.
        ///
        /// Bài kiểm ở lõi chấm được thuật toán và phép sinh kiểu vẽ. Nó KHÔNG chấm được rằng
        /// kiểu vẽ ấy đi vào bản chuyển rồi tới mermaid, cũng không chấm được rằng bảng node ra
        /// đúng một tab mới đọc được.
        Case(name: "Đồ thị: PageRank và cộng đồng tô lên hình, bảng node ra tab mới") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("graphalgo-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("do-thi.dot")
            try? """
                graph G {
                    a1 -- a2; a2 -- a3; a3 -- a1;
                    b1 -- b2; b2 -- b3; b3 -- b1;
                    a1 -- b1;
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }

            // CSR phải dựng MỘT lần và tái dùng.
            controller.runGraphAlgorithmForSelfTest(.pageRank)
            guard controller.graphCSRNodeCountForSelfTest == 6 else {
                return "CSR không dựng: \(controller.graphCSRNodeCountForSelfTest) node"
            }
            guard controller.graphStylesForSelfTest.values.contains(where: {
                $0.contains("stroke-width")
            }) else { return "PageRank không thành độ dày viền" }

            controller.runGraphAlgorithmForSelfTest(.communities)
            guard controller.graphStylesForSelfTest.values.contains(where: {
                $0.contains("fill:")
            }) else { return "cộng đồng không thành màu nền" }
            // Hai lớp phải CHỒNG lên nhau, không phải cái sau xoá cái trước.
            guard let sample = controller.graphStylesForSelfTest["a1"],
                  sample.contains("fill:"), sample.contains("stroke-width") else {
                return "chạy cộng đồng làm mất kiểu vẽ của PageRank: "
                    + (controller.graphStylesForSelfTest["a1"] ?? "—")
            }

            // Kiểu vẽ phải tới được mermaid — vẽ lại và không hỏng.
            let second = controller.mermaidRenderCountForSelfTest
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: second + 1) else {
                return "hết giờ chờ vẽ lại sau khi tô màu"
            }
            guard controller.mermaidPanel.failureCountForSelfTest == 0 else {
                return "sơ đồ có kiểu vẽ KHÔNG vẽ được: "
                    + controller.mermaidPanel.headerTextForSelfTest
            }

            // Đích thứ ba: bảng node ra tab mới.
            let tabsBefore = controller.tabCountForSelfTest
            controller.runGraphAlgorithmForSelfTest(.exportTable)
            guard controller.tabCountForSelfTest == tabsBefore + 1 else {
                return "bảng node không ra tab mới"
            }
            let table = controller.editorDocument.buffer.text
            guard table.hasPrefix("id,ten,bac_ra,bac_vao,pagerank,hang_pagerank,cong_dong") else {
                return "bảng node thiếu cột: \(table.prefix(120))"
            }
            guard table.split(separator: "\n").count == 7 else {
                return "bảng node có \(table.split(separator: "\n").count) dòng, mong 7"
            }
            return nil
        },

        // MARK: - FR-KNW-925 — truy hồi lai BM25 × đồ thị

        /// Đường ghép đầy đủ, và ràng buộc α = 1 kiểm TRÊN GIAO DIỆN chứ không chỉ ở lõi.
        ///
        /// Bài kiểm ở lõi chấm `HybridRetrieval.search`. Nó KHÔNG chấm được rằng thanh trượt α
        /// nối đúng vào phép tìm, rằng tệp đồ thị được nạp từ đúng chỗ, và rằng đường tô sáng
        /// vẫn nguyên sau khi thứ hạng bị xếp lại.
        Case(name: "Lai: α = 1 trùng BM25, α nhỏ đổi thứ hạng, tô sáng vẫn đúng") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("hybrid-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
            try? """
                {"id":"a","text":"hồ sơ hồ sơ hồ sơ"}
                {"id":"b","text":"hồ sơ của Bình"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)
            // Đồ thị đặt CẠNH corpus, cùng quy ước với bộ đánh giá golden set.
            try? "graph { An -- \"Bình\" }"
                .write(toFile: (folder as NSString).appendingPathComponent("chunks.dot"),
                       atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)

            // BM25 thuần: chunk lặp từ lên trước.
            controller.askRetrievalForSelfTest("hồ sơ An")
            let pure = controller.retrievalResultTextForSelfTest
            guard pure.contains("hồ sơ hồ sơ hồ sơ") else {
                return "không có kết quả BM25: \(pure)"
            }
            let pureFirst = pure.contains("hồ sơ hồ sơ hồ sơ")
                && (pure.range(of: "hồ sơ hồ sơ hồ sơ")?.lowerBound ?? pure.endIndex)
                    < (pure.range(of: "hồ sơ của Bình")?.lowerBound ?? pure.endIndex)
            guard pureFirst else { return "tiền đề sai: BM25 không xếp chunk lặp từ lên trước" }

            // α = 1: THỨ TỰ phải trùng BM25 thuần.
            //
            // So THỨ TỰ chứ không so cả chuỗi: ở chế độ lai, bảng hiện ĐIỂM LAI (BM25 đã chuẩn
            // hoá) chứ không hiện điểm BM25 thô — đó là con số đã quyết định thứ hạng, nên hiện
            // nó là đúng. Ràng buộc của đặc tả nói về KẾT QUẢ, tức thứ tự.
            controller.setHybridForSelfTest(true, alpha: 1)
            guard controller.isHybridOnForSelfTest else {
                return "không bật được phép lai: \(controller.retrievalSummaryForSelfTest)"
            }
            let atOne = controller.retrievalResultTextForSelfTest
            let atOneFirst = (atOne.range(of: "hồ sơ hồ sơ hồ sơ")?.lowerBound ?? atOne.endIndex)
                < (atOne.range(of: "hồ sơ của Bình")?.lowerBound ?? atOne.endIndex)
            guard atOneFirst else { return "α = 1 KHÔNG trùng thứ tự BM25 thuần" }

            // α nhỏ: chunk có entity láng giềng phải vượt lên.
            controller.setHybridForSelfTest(true, alpha: 0.1)
            let hybrid = controller.retrievalResultTextForSelfTest
            let hybridFirst = (hybrid.range(of: "hồ sơ của Bình")?.lowerBound ?? hybrid.endIndex)
                < (hybrid.range(of: "hồ sơ hồ sơ hồ sơ")?.lowerBound ?? hybrid.endIndex)
            guard hybridFirst else { return "α = 0,1 không đổi thứ hạng" }

            // Tô sáng vẫn trúng đúng chữ khớp sau khi xếp lại.
            let ranges = controller.retrievalHighlightsForSelfTest
            guard !ranges.isEmpty else { return "xếp lại xong thì mất tô sáng" }
            let ns = hybrid as NSString
            let words = Set(ranges.map { ns.substring(with: $0) })
            guard words.isSubset(of: ["hồ", "sơ", "an"]) else {
                return "tô sáng nhầm chữ sau khi xếp lại: \(words)"
            }
            return nil
        },

        /// Thiếu tệp đồ thị thì NÓI RA, không lặng lẽ chạy BM25 thuần.
        ///
        /// Lặng lẽ thì người dùng tưởng phép lai đang chạy và kết luận "đồ thị chẳng giúp gì" —
        /// một kết luận sai về một thứ chưa bao giờ được bật.
        Case(name: "Lai: thiếu tệp đồ thị thì nói ra, không im lặng") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("hybridmissing-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
            try? #"{"id":"a","text":"hồ sơ"}"#
                .write(toFile: corpus, atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)
            controller.setHybridForSelfTest(true, alpha: 0.5)
            guard !controller.isHybridOnForSelfTest else {
                return "bật được phép lai dù không có đồ thị"
            }
            let summary = controller.retrievalSummaryForSelfTest
            guard summary.contains("chunks.dot") else {
                return "không nói ra tệp còn thiếu: \(summary)"
            }
            return nil
        },

        // MARK: - FR-KNW-924 — Graph Quality Report

        /// Chấm sức khoẻ trên đường sản phẩm, và lỗi phải vào ĐÚNG danh sách bấm-nhảy.
        ///
        /// Bài kiểm ở lõi chấm bảy phép kiểm. Nó KHÔNG chấm được rằng danh sách lỗi tới được
        /// panel kết quả, rằng số dòng quy đúng về tệp DOT, và rằng bấm một dòng thì con nháy
        /// nhảy tới đó.
        Case(name: "Đồ thị: chấm sức khoẻ, lỗi vào danh sách bấm-nhảy") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("gqui-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("do-thi.dot")
            try? """
                digraph G {
                    a [label="Nguyễn Văn A"];
                    b [label="Nguyen Van A"];
                    coi [label="Mồ côi"];
                    a -> b;
                    a -> b;
                    a -> chua_khai;
                }
                """.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }

            controller.runGraphAlgorithmForSelfTest(.quality)
            let problems = controller.graphQualityProblemsForSelfTest
            guard !problems.isEmpty else { return "không chấm được sức khoẻ" }

            // Bốn loại lỗi của tệp mẫu đều phải có mặt.
            let kinds = Set(problems.map(\.kind))
            for kind in [GraphQuality.Problem.Kind.orphan, .duplicateEdge, .danglingEdge,
                         .nearLabel] where !kinds.contains(kind) {
                return "thiếu loại lỗi «\(kind.vietnamese)»: \(kinds.map(\.rawValue))"
            }

            // Số dòng phải nằm TRONG tệp — không có phép quy đổi nào thì nó rơi ra ngoài.
            let lineCount = controller.editorDocument.buffer.lineCount
            for problem in problems where problem.line < 0 || problem.line >= lineCount {
                return "lỗi báo ở dòng \(problem.line), tệp chỉ có \(lineCount) dòng"
            }

            // Danh sách phải tới được panel kết quả.
            let rows = controller.searchResultRowsForSelfTest
            guard rows.count >= problems.count else {
                return "panel kết quả có \(rows.count) dòng, lỗi có \(problems.count)"
            }

            // Điểm phải chấm được, và chiều Tươi mới bị loại chứ không tính 100.
            guard let score = controller.graphQualityScoreForSelfTest, score < 100 else {
                return "điểm sức khoẻ: \(String(describing: controller.graphQualityScoreForSelfTest))"
            }
            return nil
        },

        // MARK: - FR-KNW-920 — Chunk ↔ Entity ↔ Graph

        /// Hai đầu ra của 920 trên đường sản phẩm: báo cáo phủ, và gói ngữ cảnh JSONL.
        ///
        /// Bài kiểm ở lõi chấm phép ánh xạ và phép trích. Nó KHÔNG chấm được rằng đồ thị được
        /// nạp từ đúng chỗ (`<corpus>.dot`), rằng ánh xạ dùng chung giữa hai lệnh, và rằng gói
        /// sinh ra là JSONL đọc lại được.
        Case(name: "GraphRAG: báo cáo phủ và gói ngữ cảnh ra tab mới") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("graphrag-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
            try? """
                {"id":"c1","text":"hợp đồng do An ký"}
                {"id":"c2","text":"biên bản do Bình lập"}
                {"id":"c3","text":"không nhắc tới ai cả"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)
            try? "graph { An -- \"Bình\"; \"Ế\" }"
                .write(toFile: (folder as NSString).appendingPathComponent("chunks.dot"),
                       atomically: true, encoding: .utf8)

            controller.openInNewTabForSelfTest(path: corpus)
            controller.showRetrievalPanel(nil)

            // --- Báo cáo phủ ---
            controller.runGraphRAGForSelfTest(.coverage)
            let report = controller.editorDocument.buffer.text
            guard report.contains("Phủ Chunk") else {
                return "không sinh báo cáo phủ: \(report.prefix(120))"
            }
            // «Ế» không chunk nào nhắc; chunk c3 mồ côi.
            guard report.contains("Ế") else { return "thiếu entity không được nhắc" }
            guard report.contains("dòng 3") else { return "thiếu chunk mồ côi" }
            // Và con số 0 của phép kiểm thứ ba phải NÓI RA vì sao nó bằng 0.
            guard report.contains("theo cấu tạo") else {
                return "không nói ra vì sao «node không có entity đối ứng» rỗng"
            }

            // --- Gói ngữ cảnh ---
            controller.runGraphRAGForSelfTest(.contextPackage)
            let package = controller.editorDocument.buffer.text
            let lines = package.split(separator: "\n").map(String.init)
            guard !lines.isEmpty else { return "không sinh gói ngữ cảnh" }
            for line in lines {
                guard let object = (try? JSONSerialization.jsonObject(with: Data(line.utf8)))
                        as? [String: Any] else {
                    return "dòng gói ngữ cảnh không phải JSON: \(line.prefix(80))"
                }
                for key in ["query_seed", "triples", "chunks"] where object[key] == nil {
                    return "gói thiếu trường «\(key)»"
                }
            }
            // Seed «An» phải có triple An—Bình và chunk c1.
            guard let anLine = lines.first(where: { $0.contains("\"query_seed\":\"An\"") }),
                  anLine.contains("Bình"), anLine.contains("c1") else {
                return "gói của seed An thiếu triple hoặc chunk"
            }
            return nil
        },

        // MARK: - FR-KNW-923 — gom biến thể entity

        /// Chu trình đầy đủ: đề xuất → duyệt → áp, và **không bao giờ tự merge**.
        ///
        /// Vế cuối là ràng buộc của đặc tả, và nó chỉ kiểm được trên đường sản phẩm: bước đề
        /// xuất phải KHÔNG sửa gì cả, và bước áp phải đọc bảng người dùng đã sửa.
        Case(name: "Gom entity: đề xuất không sửa gì, áp bảng duyệt mới sửa") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("entres-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("do-thi.dot")
            let original = """
                digraph G {
                    "Nguyen Van A" -> "Tran Thi B";
                    "Nguyễn Văn A" -> "Tran Thi B";
                }
                """
            try? original.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }

            // --- Bước 1: đề xuất. Tệp đồ thị KHÔNG được đổi. ---
            controller.runGraphAlgorithmForSelfTest(.resolveEntities)
            let onDisk = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            guard onDisk == original else {
                return "bước ĐỀ XUẤT đã sửa tệp đồ thị — vi phạm «không bao giờ tự merge»"
            }
            let reviewPath = MainWindowController.resolutionReviewPath(forGraph: path)
            guard let review = try? String(contentsOfFile: reviewPath, encoding: .utf8) else {
                return "không sinh bảng duyệt"
            }
            guard review.contains("Nguyen Van A"), review.contains("canonical") else {
                return "bảng duyệt thiếu cụm: \(review.prefix(120))"
            }

            // --- Bước 3: áp bảng duyệt (giữ nguyên đề xuất) ---
            controller.activateTabForSelfTest(path: path)

            // --- Bước 2: đường THẬT hỏi trước khi ghi. Lượt chạy không người KHÔNG được áp. ---
            //
            // Một phép gộp node không hoàn tác được bằng cách gõ lại, nên nó không bao giờ được
            // xảy ra mà không có người bấm — kể cả trong một lượt chạy tự động.
            controller.runGraphAlgorithmForSelfTest(.applyResolution)
            guard controller.editorDocument.buffer.text == original else {
                return "lượt chạy KHÔNG NGƯỜI đã áp phép gộp mà không ai bấm"
            }

            // --- Bước 3: áp thật (bỏ qua hộp hỏi, chỉ bài kiểm mới đi đường này) ---
            controller.applyEntityResolutionForSelfTest()
            let applied = controller.editorDocument.buffer.text
            guard applied != original else { return "áp bảng duyệt mà không đổi gì" }

            // Sau khi gộp, đồ thị còn HAI node.
            let after = DOTGraph.parse(applied)
            guard after.nodes.count == 2 else {
                return "sau khi gộp còn \(after.nodes.count) node: \(after.nodes.map(\.name))"
            }

            // Cả ba đầu ra phải có mặt, sinh CÙNG LÚC.
            let base = (path as NSString).deletingPathExtension
            for suffix in [".alias.csv", ".markers.txt"] {
                guard FileManager.default.fileExists(atPath: base + suffix) else {
                    return "thiếu đầu ra «\(suffix)»"
                }
            }
            let markers = (try? String(contentsOfFile: base + ".markers.txt",
                                       encoding: .utf8)) ?? ""
            guard markers.contains("Nguyễn Văn A"), !markers.contains("Nguyen Van A") else {
                return "danh sách marker chưa cập nhật: \(markers)"
            }

            // MỘT bước undo cho cả changeset.
            controller.undoForSelfTest()
            guard controller.editorDocument.buffer.text == original else {
                return "undo không trả về nguyên trạng — changeset không phải MỘT bước"
            }
            return nil
        },

        // MARK: - FR-KNW-921 — nhập & so điểm retrieval ngoài

        /// Sinh báo cáo so hai HỆ, và **lượt chạy không người không mở được hộp chọn tệp**.
        Case(name: "Điểm ngoài: báo cáo so hai hệ, đường dẫn tương đối, hộp chọn tệp bị chặn") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("ngoai-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
            try? """
                {"id":"c1","text":"hợp đồng mua bán nhà đất"}
                {"id":"c2","text":"hợp đồng lao động"}
                {"id":"c3","text":"biên bản bàn giao nhà"}
                """.write(toFile: corpus, atomically: true, encoding: .utf8)
            let golden = (folder as NSString).appendingPathComponent("golden.jsonl")
            try? """
                {"qid":"q1","question":"hợp đồng","relevant_ids":["c1"]}
                {"qid":"q2","question":"bàn giao","relevant_ids":["c3"]}
                """.write(toFile: golden, atomically: true, encoding: .utf8)
            let scores = (folder as NSString).appendingPathComponent("diem-ngoai.jsonl")
            try? """
                {"query":"hợp đồng","chunk_id":"c2","score":0.91}
                {"query":"hợp đồng","chunk_id":"c1","score":0.42}
                """.write(toFile: scores, atomically: true, encoding: .utf8)

            controller.open(path: corpus, line: nil, column: nil, readOnly: false)
            controller.showRetrievalPanel(nil)

            // Đường thật đi qua HỘP CHỌN TỆP, và lượt chạy không người phải dừng ở đó.
            let before = controller.tabPathsForSelfTest.count
            controller.evaluateForSelfTest(.externalScores)
            guard controller.tabPathsForSelfTest.count == before else {
                return "lượt chạy KHÔNG NGƯỜI đã mở được hộp chọn tệp"
            }

            controller.makeExternalReportForSelfTest(
                corpus: corpus, golden: golden, external: scores)
            let text = controller.editorDocument.buffer.text
            guard text.contains("external: diem-ngoai.jsonl") else {
                return "khối thiếu khoá «external» hoặc đường dẫn không TƯƠNG ĐỐI: \(text)"
            }
            guard !text.contains(folder) else {
                return "báo cáo mang đường dẫn tuyệt đối nên chỉ chạy được trên máy này"
            }

            // Dựng thật báo cáo ấy: hai cột phải là hai HỆ, và câu không ghép được phải bị loại.
            let rendered = try? ReportRenderer.render(
                try ReportDocument.parse(text),
                in: TextBuffer(original: MemoryByteSource([])), dialect: .comma,
                options: ReportRenderer.Options(basePath: folder))
            guard let rendered, rendered.failures.isEmpty else {
                return "báo cáo hỏng: \(rendered?.failures.map(\.message) ?? [])"
            }
            guard rendered.html.contains("Điểm ngoài"),
                  rendered.html.contains("KHÔNG tính vector") else {
                return "thẻ điểm thiếu cột «Điểm ngoài» hoặc ranh giới ADR-11"
            }
            guard rendered.html.contains("1 câu của bộ đánh giá KHÔNG có trong tệp ngoài") else {
                return "không nói ra câu bị loại khỏi phép so"
            }
            return nil
        },

        // MARK: - FR-KNW-916 — tái cấu trúc đồ thị

        /// Bốn phép, chạy qua đúng đường người dùng bấm: đổi tên → tách → gộp → trích.
        ///
        /// Vế cứng kiểm ở đây là **một bước undo**: sau mỗi phép, một lần Cmd-Z phải trả về
        /// nguyên trạng. Changeset áp nửa vời thì Cmd-Z để lại một đồ thị chưa ai khai bao giờ.
        Case(name: "Tái cấu trúc đồ thị: đổi tên, tách, gộp, trích — mỗi phép MỘT bước undo") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("refactor-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("do-thi.dot")
            let original = """
                digraph G {
                    "Nguyễn An";
                    "Nguyen An";
                    "Nguyễn An" -> "Kho A";
                    "Nguyễn An" -> "Kho B";
                    "Nguyen An" -> "Kho A";
                }
                """
            try? original.write(toFile: path, atomically: true, encoding: .utf8)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let before = controller.mermaidRenderCountForSelfTest
            controller.openMermaidStudioForSelfTest()
            controller.refreshMermaidPreview()
            guard controller.waitForMermaidRenderForSelfTest(atLeast: before + 1) else {
                return "hết giờ chờ vẽ sơ đồ DOT"
            }

            func select(lines: ClosedRange<Int>) {
                let buffer = controller.editorDocument.buffer
                let start = buffer.offset(ofLineStart: lines.lowerBound)
                let next = min(buffer.count, buffer.offset(ofLineStart: lines.upperBound + 1))
                controller.setSelectionForSelfTest(documentRange: start ..< max(start, next - 1))
            }

            // --- Không người: KHÔNG phép nào được ghi ---
            //
            // Cả bốn đi qua một ô nhập tên hoặc một hộp hỏi, và `Unattended.ask` trả `.abort`.
            // Một phép gộp node không hoàn tác được bằng cách gõ lại, nên nó không bao giờ
            // được xảy ra mà không có người bấm.
            select(lines: 1...1)
            controller.runGraphAlgorithmForSelfTest(.renameNode)
            select(lines: 1...2)
            controller.runGraphAlgorithmForSelfTest(.mergeNodes)
            select(lines: 3...5)
            controller.runGraphAlgorithmForSelfTest(.splitNode)
            guard controller.editorDocument.buffer.text == original else {
                return "lượt chạy KHÔNG NGƯỜI đã sửa đồ thị mà không ai bấm"
            }

            // --- Đổi tên: ba chỗ, một bước undo ---
            select(lines: 1...1)
            controller.renameGraphNodeForSelfTest(to: "Nguyễn Văn An")
            let renamed = controller.editorDocument.buffer.text
            guard renamed.components(separatedBy: "Nguyễn Văn An").count - 1 == 3 else {
                return "đổi tên không chạm đủ ba chỗ: \(renamed)"
            }
            controller.undoForSelfTest()
            guard controller.editorDocument.buffer.text == original else {
                return "undo sau ĐỔI TÊN không trả về nguyên trạng"
            }

            // --- Tách: vùng chọn KHÔNG nói rõ ai bị tách thì từ chối, không đoán ---
            //
            // Ba dòng ấy chạm «Nguyễn An» hai lần và «Kho A» cũng hai lần. Đoán bừa ở đây là
            // sửa đúng những cạnh người dùng vừa chỉ vào, theo một cách họ không yêu cầu.
            select(lines: 3...5)
            controller.splitGraphNodeForSelfTest(to: "An kho")
            guard controller.editorDocument.buffer.text == original else {
                return "TÁCH đã đoán khi vùng chọn có hai ứng viên ngang nhau"
            }

            // --- Tách: hai cạnh của «Nguyễn An» chuyển sang node mới ---
            select(lines: 3...4)
            controller.splitGraphNodeForSelfTest(to: "An kho")
            let split = DOTGraph.parse(controller.editorDocument.buffer.text)
            guard split.edges.filter({ $0.from == "An kho" }).count == 2 else {
                return "tách không chuyển đủ hai cạnh: \(split.edges.map { "\($0.from)->\($0.to)" })"
            }
            controller.undoForSelfTest()
            guard controller.editorDocument.buffer.text == original else {
                return "undo sau TÁCH không trả về nguyên trạng"
            }

            // --- Gộp: hai biến thể thành một, và cạnh trùng bị khử ---
            select(lines: 1...2)
            controller.mergeGraphNodesForSelfTest()
            let mergedText = controller.editorDocument.buffer.text
            guard !mergedText.contains("Nguyen An") else {
                return "gộp còn sót biến thể không dấu: \(mergedText)"
            }
            let merged = DOTGraph.parse(mergedText)
            guard merged.edges.count == 2 else {
                return "gộp chưa khử cạnh trùng — còn \(merged.edges.count) cạnh"
            }
            guard Set(merged.nodes.map(\.name)).count == 3 else {
                return "sau gộp còn \(Set(merged.nodes.map(\.name)).count) node khác nhau"
            }
            controller.undoForSelfTest()
            guard controller.editorDocument.buffer.text == original else {
                return "undo sau GỘP không trả về nguyên trạng"
            }

            // --- Trích: sinh tệp mới, KHÔNG chạm tài liệu đang mở ---
            select(lines: 3...3)
            controller.runGraphAlgorithmForSelfTest(.extractSubgraph)
            guard (try? String(contentsOfFile: path, encoding: .utf8)) == original else {
                return "TRÍCH đã sửa tệp gốc trên đĩa"
            }
            let target = (path as NSString).deletingPathExtension + ".trich.dot"
            guard let extracted = try? String(contentsOfFile: target, encoding: .utf8) else {
                return "không sinh tệp trích"
            }
            let sub = DOTGraph.parse(extracted)
            guard sub.edges.count == 1, Set(sub.nodes.map(\.name)) == ["Nguyễn An", "Kho A"] else {
                return "tệp trích sai phạm vi: \(extracted)"
            }
            // TRÍCH mở tệp mới ở tab mới, nên tài liệu ĐANG HOẠT ĐỘNG đã đổi — quay lại tab cũ
            // rồi mới kiểm nó còn nguyên. Cùng cái bẫy đã ghi ở FR-KNW-920.
            controller.activateTabForSelfTest(path: path)
            guard controller.editorDocument.buffer.text == original else {
                return "TRÍCH đã sửa tài liệu đang mở"
            }
            return nil
        },

        // MARK: - Khung xem ảnh · PDF · file nén
        //
        // Ba bài dưới đây đi qua ĐÚNG đường người dùng đi: `controller.open(path:)` với một tệp
        // thật trên đĩa. Gọi tắt vào từng khung xem thì bỏ qua đúng chỗ dễ hỏng nhất — phép
        // nhận diện loại tệp và việc tráo khung soạn thảo bằng khung xem.

        Case(name: "Mở ảnh: nhận ra là ảnh, tráo khung, và KHÔNG dựng buffer từ byte nhị phân") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("media-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            // Ảnh THẬT do ImageIO ghi ra, không phải vài byte bịa.
            let path = (folder as NSString).appendingPathComponent("thu.png")
            let image = NSImage(size: NSSize(width: 40, height: 24))
            image.lockFocus()
            NSColor.orange.setFill()
            NSRect(x: 0, y: 0, width: 40, height: 24).fill()
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                return "không dựng được ảnh thử"
            }
            try? png.write(to: URL(fileURLWithPath: path))

            // Kích thước MONG ĐỢI đọc từ chính tệp vừa ghi, không gõ cứng 40×24.
            //
            // `lockFocus` vẽ ở tỉ lệ màn hình, nên trên máy Retina tệp ra 80×48 — và `pixelSize`
            // báo 80×48 là ĐÚNG, vì nó cố ý trả về số điểm ảnh thật chứ không phải số điểm của
            // AppKit. Gõ cứng con số ở đây thì bài kiểm đỏ trên máy Retina và xanh trên máy
            // thường, tức nó đang đo màn hình chứ không đo mã.
            guard let onDisk = NSBitmapImageRep(data: png) else { return "không đọc lại được ảnh" }
            let expected = NSSize(width: onDisk.pixelsWide, height: onDisk.pixelsHigh)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .image else {
                return "không nhận ra ảnh: \(String(describing: controller.editorDocument.mediaKind))"
            }
            // Vế quan trọng nhất: buffer PHẢI rỗng. Đường cũ giải mã PNG thành văn bản rồi dựng
            // chỉ mục dòng trên ký tự rác — đúng thứ người dùng đang phàn nàn.
            guard controller.editorDocument.buffer.count == 0 else {
                return "đã giải mã ảnh thành văn bản: \(controller.editorDocument.buffer.count) byte"
            }
            guard controller.isMediaViewerVisibleForSelfTest else {
                return "khung xem media không hiện"
            }
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ImageViewerView else {
                return "khung con không phải khung ảnh"
            }
            guard viewer.hasImageForSelfTest else { return "khung ảnh không nạp được ảnh" }
            guard viewer.pixelSizeForSelfTest == expected else {
                return "kích thước sai: \(viewer.pixelSizeForSelfTest), mong \(expected)"
            }
            // Xoay hai lần thì bề rộng và bề cao trở về như cũ.
            viewer.rotateForSelfTest()
            guard viewer.rotationForSelfTest == 90 else { return "xoay không đổi trạng thái" }

            // Và chuyển sang một tab VĂN BẢN thì khung ảnh phải biến mất. Quên chỗ này thì ảnh
            // nằm đè lên chữ của tab kế tiếp.
            controller.newTabForSelfTest()
            guard !controller.isMediaViewerVisibleForSelfTest else {
                return "khung ảnh còn nằm đè lên tab văn bản"
            }
            return nil
        },

        Case(name: "Mở PDF: đọc được số trang, tìm ra chữ, bôi vàng ghi được vào tệp") { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("media-pdf-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("thu.pdf")

            // PDF THẬT do CoreGraphics ghi, hai trang, có tầng chữ.
            var box = CGRect(x: 0, y: 0, width: 300, height: 200)
            guard let context = CGContext(
                URL(fileURLWithPath: path) as CFURL, mediaBox: &box, nil) else {
                return "không dựng được PDF thử"
            }
            for page in 1...2 {
                context.beginPDFPage(nil)
                let text = NSAttributedString(
                    string: "Trang \(page) — Nguyễn Văn Anh",
                    attributes: [.font: NSFont.systemFont(ofSize: 18)])
                let line = CTLineCreateWithAttributedString(text)
                context.textPosition = CGPoint(x: 20, y: 100)
                CTLineDraw(line, context)
                context.endPDFPage()
            }
            context.closePDF()

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .pdf else { return "không nhận ra PDF" }
            guard let viewer = controller.mediaViewer.contentForSelfTest as? PDFViewerView else {
                return "khung con không phải khung PDF"
            }
            guard viewer.pageCountForSelfTest == 2 else {
                return "\(viewer.pageCountForSelfTest) trang, mong 2"
            }

            // Tìm KHÔNG dấu vẫn phải ra chữ CÓ dấu — đúng lời hứa của ô tìm trong phần còn lại
            // của ứng dụng, và là lý do bật `.diacriticInsensitive`.
            guard viewer.searchForSelfTest("nguyen van anh") == 2 else {
                return "tìm không dấu ra \(viewer.searchForSelfTest("nguyen van anh")) kết quả, mong 2"
            }

            // Bôi vàng rồi ghi ra tệp, và ĐỌC LẠI tệp vừa ghi — chú thích phải còn.
            let before = viewer.annotationCountForSelfTest
            viewer.selectAllTextOnFirstPageForSelfTest()
            viewer.highlightForSelfTest()
            guard viewer.annotationCountForSelfTest > before else {
                return "bôi vàng không thêm chú thích nào"
            }
            let copyPath = (folder as NSString).appendingPathComponent("co-chu-thich.pdf")
            guard viewer.writeCopyForSelfTest(to: copyPath) else { return "không ghi được bản sao" }
            guard let again = PDFViewerView.inspectForSelfTest(copyPath) else {
                return "bản vừa ghi mở lại không được"
            }
            guard again.pages == 2 else { return "bản sao mất trang: \(again.pages)" }
            guard again.annotations > 0 else {
                return "chú thích KHÔNG vào tệp — bôi vàng chỉ sống trong bộ nhớ"
            }
            return nil
        },

        // Excel và Word DỰNG TẠI CHỖ — để hai đường ấy có mặt trong bundle App Store.
        //
        // Ba bài Office bên dưới đọc tệp thật trong kho và vì thế BỊ BỎ QUA trong sandbox: nó
        // không cho với ra ngoài vùng chứa. Nghĩa là đường mở Office — thứ người dùng chạm tới
        // hằng ngày — chưa từng được kiểm ở đúng cấu hình phát hành, đúng chỗ đã giấu hai lỗi
        // chặn phát hành hồi 31/08.
        //
        // Bài này KHÔNG thay ba bài kia: chúng đọc tệp Office THẬT do Microsoft Office ghi ra,
        // với đủ styles, sharedStrings và quan hệ; bài này chỉ dựng bộ xương tối thiểu. Hai câu
        // hỏi khác nhau — «đọc được tệp thật không» và «đường ấy có sống trong sandbox không».
        Case(name: "Office: mở .xlsx và .docx dựng tại chỗ — chạy được cả trong sandbox") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("office-sandbox-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            // ── Excel: workbook + quan hệ + một sheet dùng chuỗi NỘI TUYẾN.
            //
            // `inlineStr` chứ không `sharedStrings`: bảng chuỗi chung là một tệp thứ hai phải
            // giữ đồng bộ chỉ số, và ở đây ta đang kiểm ĐƯỜNG MỞ chứ không kiểm bộ đọc chuỗi.
            func cell(_ reference: String, _ text: String) -> String {
                "<c r=\"\(reference)\" t=\"inlineStr\"><is><t>\(text)</t></is></c>"
            }
            let sheet = "<?xml version=\"1.0\"?><worksheet "
                + "xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>"
                + "<row r=\"1\">" + cell("A1", "ma") + cell("B1", "ten") + "</row>"
                + "<row r=\"2\">" + cell("A2", "A1") + cell("B2", "Cam sành") + "</row>"
                + "<row r=\"3\">" + cell("A3", "A2") + cell("B3", "Quýt Huế") + "</row>"
                + "</sheetData></worksheet>"
            guard let xlsx = Self.minimalZip([
                "xl/workbook.xml": "<?xml version=\"1.0\"?><workbook "
                    + "xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" "
                    + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
                    + "<sheets><sheet name=\"Bang1\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>",
                "xl/_rels/workbook.xml.rels": "<?xml version=\"1.0\"?><Relationships "
                    + "xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                    + "<Relationship Id=\"rId1\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
                "xl/worksheets/sheet1.xml": sheet,
            ]) else { return "không dựng được .xlsx thử" }
            let xlsxPath = (folder as NSString).appendingPathComponent("bang.xlsx")
            try? xlsx.write(to: URL(fileURLWithPath: xlsxPath))

            controller.open(path: xlsxPath, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .excel else {
                return "không nhận ra .xlsx: "
                    + "\(String(describing: controller.editorDocument.mediaKind))"
            }
            let csv = controller.documentTextForSelfTest
            guard csv.contains("Cam sành"), csv.contains("Quýt Huế") else {
                return "mở .xlsx ra không phải bảng: «\(csv.prefix(60))»"
            }
            // Không đòi chế độ Bảng hiện sẵn: bài Excel đọc tệp thật ngay dưới cũng không đòi
            // vế ấy, và đòi thêm ở đây là dựng một hợp đồng thứ hai cho cùng một đường mở.
            // Vế đúng là: bảng tính KHÔNG rơi vào khung media, vì nó dùng bảng CSV.
            guard !controller.isMediaViewerVisibleForSelfTest else {
                return "bảng tính lại mở bằng khung media"
            }
            guard !controller.editorDocument.isReadOnly else {
                return "bảng tính bị khoá — không sửa được ô nào"
            }

            // ── Word: chỉ cần `word/document.xml` với vài đoạn.
            func paragraph(_ text: String) -> String {
                "<w:p><w:r><w:t>\(text)</w:t></w:r></w:p>"
            }
            guard let docx = Self.minimalZip([
                "word/document.xml": "<?xml version=\"1.0\"?><w:document "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                    + "<w:body>" + paragraph("Báo cáo quý I")
                    + paragraph("Doanh thu tăng mười hai phần trăm") + "</w:body></w:document>",
            ]) else { return "không dựng được .docx thử" }
            let docxPath = (folder as NSString).appendingPathComponent("bao-cao.docx")
            try? docx.write(to: URL(fileURLWithPath: docxPath))

            controller.open(path: docxPath, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .word else {
                return "không nhận ra .docx: "
                    + "\(String(describing: controller.editorDocument.mediaKind))"
            }
            let markdown = controller.documentTextForSelfTest
            guard markdown.contains("Báo cáo quý I"),
                  markdown.contains("Doanh thu tăng mười hai phần trăm") else {
                return "mở .docx ra không đủ đoạn: «\(markdown.prefix(80))»"
            }

            // ── Và vòng GHI NGƯỢC, cho cả hai định dạng.
            //
            // Ba bài Office đọc tệp thật cũng kiểm vế này, và cũng bị bỏ qua trong sandbox —
            // nên cho tới hôm nay, đường ⌘S của Word và Excel chưa từng chạy ở đúng cấu hình
            // phát hành. Mà ghi ngược là đường NGUY HIỂM nhất của cả hai: nó ghi đè tệp của
            // người dùng.
            let doanMoi = markdown.replacingOccurrences(
                of: "Doanh thu tăng mười hai phần trăm", with: "Doanh thu tăng hai mươi phần trăm")
            controller.prepareSelfTestEditToDocument(doanMoi)
            controller.saveDocumentForSelfTest()
            guard let docxLai = try? DOCXReader.read(path: docxPath) else {
                return ".docx sau khi ghi không mở lại được — đường ⌘S làm hỏng tệp"
            }
            guard docxLai.markdown.contains("hai mươi phần trăm") else {
                return "đoạn đã sửa KHÔNG vào tệp .docx: «\(docxLai.markdown.prefix(80))»"
            }

            // Excel: sửa một ô rồi ⌘S, và đòi phần KHÔNG phải sheet giữ nguyên từng byte.
            controller.open(path: xlsxPath, line: nil, column: nil, readOnly: false)
            guard let truoc = try? ZipArchive(path: xlsxPath),
                  let sheetPath = try? XLSXReader(path: xlsxPath).sheets.first?.path else {
                return "không mở lại được .xlsx vừa dựng"
            }
            var byteCu: [String: [UInt8]] = [:]
            for entry in truoc.entries where entry.path != sheetPath && !entry.isDirectory {
                byteCu[entry.path] = try? truoc.data(for: entry)
            }
            guard !byteCu.isEmpty else {
                return "tệp thử chỉ có mỗi sheet — vế «giữ nguyên từng byte» không kiểm được gì"
            }

            let cu = controller.documentTextForSelfTest
            guard let xuong = cu.firstIndex(of: "\n") else { return "bảng chỉ có một dòng" }
            controller.prepareSelfTestEditToDocument("GEDITOR-SANDBOX" + cu[xuong...])
            controller.saveDocumentForSelfTest()

            guard let sau = try? XLSXReader(path: xlsxPath), let sheet = sau.sheets.first,
                  let luoi = try? sau.grid(of: sheet) else {
                return ".xlsx sau khi ghi không mở lại được"
            }
            guard luoi.rows.first?.first == "GEDITOR-SANDBOX" else {
                return "ô đã sửa KHÔNG vào tệp .xlsx: «\(luoi.rows.first?.first ?? "")»"
            }
            guard let lai = try? ZipArchive(path: xlsxPath) else {
                return "không mở lại được .xlsx dạng nén"
            }
            for (name, bytes) in byteCu {
                guard let now = try? lai.data(named: name), now == bytes else {
                    return "phần «\(name)» bị đổi dù không ai sửa nó"
                }
            }
            return nil
        },

        Case(name: "Mở Excel: ra thẳng BẢNG CSV, và tài liệu SỬA ĐƯỢC",
             skipWhen: { _ in Self.fixtureUnreadable("docs/TongHop_TinhNang_GEditor_v2.0.xlsx") }) { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("media-xlsx-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            // Tệp Excel THẬT trong kho — bài này không dựng XLSX bằng tay.
            let source = Self.repoFile("docs/TongHop_TinhNang_GEditor_v2.0.xlsx")
            guard FileManager.default.fileExists(atPath: source) else {
                return nil            // không có tệp mẫu thì không có gì để kiểm
            }
            let path = (folder as NSString).appendingPathComponent("bang.xlsx")
            try? FileManager.default.copyItem(atPath: source, toPath: path)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .excel else {
                return "không nhận ra bảng tính: "
                    + "\(String(describing: controller.editorDocument.mediaKind))"
            }
            // Khác hẳn ảnh/PDF: buffer PHẢI có nội dung, vì đó là đường đưa bảng tính về
            // chính bảng CSV của sản phẩm.
            guard controller.editorDocument.buffer.count > 0 else {
                return "buffer rỗng — bảng tính chưa được đổi sang CSV"
            }
            guard controller.documentTextForSelfTest.contains(",") else {
                return "nội dung không phải CSV"
            }
            // Excel ghi ngược được (`XLSXWriter`) nên nó KHÔNG khoá. Đây từng là bài kiểm ngược
            // lại — giữ lại vế này để lần sau ai gỡ `XLSXWriter` thì bài kiểm nói ra ngay.
            guard !controller.editorDocument.isReadOnly else {
                return "bảng tính bị khoá — không sửa được ô nào"
            }
            // Khung media không được hiện: bảng tính dùng bảng CSV.
            guard !controller.isMediaViewerVisibleForSelfTest else {
                return "bảng tính lại mở bằng khung file nén"
            }
            return nil
        },

        Case(name: "Excel: sửa ô rồi ⌘S — ghi ngược vào .xlsx, phần còn lại giữ NGUYÊN BYTE",
             skipWhen: { _ in Self.fixtureUnreadable("docs/TongHop_TinhNang_GEditor_v2.0.xlsx") }) {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("media-xlsxw-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            let source = Self.repoFile("docs/TongHop_TinhNang_GEditor_v2.0.xlsx")
            guard FileManager.default.fileExists(atPath: source) else { return nil }
            let path = (folder as NSString).appendingPathComponent("bang.xlsx")
            try? FileManager.default.copyItem(atPath: source, toPath: path)

            // Chụp lại toàn bộ phần KHÔNG phải sheet, để lát nữa đòi chúng giữ nguyên từng byte.
            guard let truoc = try? ZipArchive(path: path),
                  let sheetPath = try? XLSXReader(path: path).sheets.first?.path else {
                return "không mở được bảng tính mẫu"
            }
            var byteCu: [String: [UInt8]] = [:]
            for entry in truoc.entries where entry.path != sheetPath && !entry.isDirectory {
                byteCu[entry.path] = try? truoc.data(for: entry)
            }

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .excel else {
                return "không nhận ra bảng tính"
            }
            // Excel nay GHI NGƯỢC được, nên nó không còn chỉ-đọc.
            guard !controller.editorDocument.isReadOnly else {
                return "bảng tính vẫn bị khoá — không sửa được"
            }

            // Sửa ô đầu tiên qua chính buffer, rồi ⌘S.
            let cu = controller.documentTextForSelfTest
            guard let xuong = cu.firstIndex(of: "\n") else { return "bảng chỉ có một dòng" }
            let moi = "GEDITOR-TU-KIEM" + cu[xuong...]
            controller.prepareSelfTestEditToDocument(String(moi))
            controller.saveDocumentForSelfTest()

            // Đọc lại tệp trên đĩa bằng bộ đọc — giá trị mới phải có mặt.
            guard let sau = try? XLSXReader(path: path),
                  let sheet = sau.sheets.first,
                  let luoi = try? sau.grid(of: sheet) else {
                return "tệp sau khi ghi không mở lại được"
            }
            guard luoi.rows.first?.first == "GEDITOR-TU-KIEM" else {
                return "ô đã sửa KHÔNG vào tệp: «\(luoi.rows.first?.first ?? "")»"
            }

            // Và lời hứa trung tâm: mọi phần khác giữ nguyên TỪNG BYTE. Đây là thứ phân biệt
            // "sửa tại chỗ" với "dựng lại tệp từ những gì bộ đọc hiểu".
            guard let lai = try? ZipArchive(path: path) else { return "không mở lại được file nén" }
            for (name, bytes) in byteCu {
                guard let now = try? lai.data(named: name), now == bytes else {
                    return "phần «\(name)» bị đổi dù không ai sửa nó"
                }
            }
            return nil
        },

        Case(name: "Word: ra Markdown, sửa một đoạn rồi ⌘S ghi ngược vào .docx",
             skipWhen: { _ in Self.fixtureUnreadable("docs/GioiThieu_TinhNang_GEditor_v2.0.docx") }) { controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("media-docx-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            let source = Self.repoFile("docs/GioiThieu_TinhNang_GEditor_v2.0.docx")
            guard FileManager.default.fileExists(atPath: source) else { return nil }
            let path = (folder as NSString).appendingPathComponent("tai-lieu.docx")
            try? FileManager.default.copyItem(atPath: source, toPath: path)

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .word else {
                return "không nhận ra tài liệu Word"
            }
            guard let original = try? DOCXReader.read(path: path) else {
                return "không đọc được tài liệu Word"
            }
            let text = controller.documentTextForSelfTest
            guard text.count > 500 else { return "nội dung gần như rỗng: \(text.count) ký tự" }
            guard text.contains("# ") else { return "không có tiêu đề Markdown nào" }
            // Rò thẻ XML là cách hỏng tệ nhất ở đây: nó vẫn ra "nội dung", chỉ là nội dung sai.
            guard !text.contains("<w:") else { return "thẻ Word lọt vào tài liệu" }
            // Word ra Markdown thì dùng KHUNG SOẠN THẢO, không phải bảng CSV.
            guard !controller.isMediaViewerVisibleForSelfTest else {
                return "Word lại mở bằng khung file nén"
            }
            // Word nay ghi ngược được (`DOCXWriter`) nên nó không còn khoá.
            guard !controller.editorDocument.isReadOnly else {
                return "tài liệu Word bị khoá — không sửa được"
            }

            // Sửa một đoạn rồi ⌘S, và đọc lại tệp trên đĩa.
            let dong = text.components(separatedBy: "\n")
            guard let viTri = dong.firstIndex(where: {
                !$0.isEmpty && !$0.hasPrefix("|") && !$0.hasPrefix("#") && $0.count > 20
            }) else { return "không tìm được đoạn nào để sửa" }
            var moi = dong
            moi[viTri] = "GEDITOR-TU-KIEM đã sửa đoạn này."
            controller.prepareSelfTestEditToDocument(moi.joined(separator: "\n"))
            controller.saveDocumentForSelfTest()

            guard let lai = try? DOCXReader.read(path: path) else {
                return "tệp sau khi ghi không mở lại được"
            }
            guard lai.markdown.contains("GEDITOR-TU-KIEM đã sửa đoạn này.") else {
                return "đoạn đã sửa KHÔNG vào tệp"
            }
            // Và phần còn lại của tài liệu phải nguyên: số đoạn không đổi.
            guard lai.paragraphCount == original.paragraphCount else {
                return "số đoạn đổi từ \(original.paragraphCount) thành \(lai.paragraphCount)"
            }
            return nil
        },

        Case(name: "Mở file nén: liệt kê mục, mở mục văn bản ra tab, chặn đường dẫn thoát ra") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("media-zip-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("thu.zip")

            // ZIP dựng bằng tay, CẤT NGUYÊN không nén.
            //
            // Ở đây điều ấy chấp nhận được, và cần nói rõ vì sao: bài này kiểm KHUNG XEM chứ
            // không kiểm bộ đọc. Bộ đọc có bài riêng ở `ZipArchiveTests`, và fixture của nó do
            // `/usr/bin/zip` thật tạo ra — một hiện thực độc lập. Còn ở đây, phụ thuộc vào một
            // chương trình ngoài sẽ làm bài tự kiểm trong bundle đã ký hỏng vì lý do không
            // liên quan gì tới thứ nó đo.
            guard let zip = Self.minimalZip(["ghi-chu.txt": "Xin chào từ trong file nén\n"]) else {
                return "không dựng được zip thử"
            }
            try? zip.write(to: URL(fileURLWithPath: path))

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .archive else {
                return "không nhận ra file nén"
            }
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ArchiveViewerView else {
                return "khung con không phải khung file nén"
            }
            guard viewer.entryPathsForSelfTest == ["ghi-chu.txt"] else {
                return "danh sách mục sai: \(viewer.entryPathsForSelfTest)"
            }

            // Mở mục văn bản → phải ra một tab MỚI mang đúng nội dung.
            let tabsBefore = controller.tabCountForSelfTest
            viewer.selectRowForSelfTest(0)
            viewer.openSelectedForSelfTest()
            guard controller.tabCountForSelfTest == tabsBefore + 1 else {
                return "mở mục không tạo tab mới"
            }
            guard controller.documentTextForSelfTest == "Xin chào từ trong file nén\n" else {
                return "nội dung mục sai: \(String(reflecting: controller.documentTextForSelfTest))"
            }

            // Hàng rào Zip Slip phải chặn, và phải cho đường dẫn lành đi qua.
            guard ZipArchive.safeDestination(for: "../../thoat", under: folder) == nil else {
                return "Zip Slip KHÔNG bị chặn"
            }
            guard ZipArchive.safeDestination(for: "a/b.txt", under: folder) != nil else {
                return "đường dẫn lành cũng bị chặn"
            }
            return nil
        },

        // BUNG TẤT CẢ — đường mà bài ZIP ở trên không đi.
        //
        // Bài trên hỏi `ZipArchive.safeDestination` THẲNG, và đó là câu hỏi "phép kiểm có đúng
        // không". Câu chưa ai hỏi là câu quan trọng hơn: **phép bung có GỌI nó không**. Một
        // hàng rào chỉ có trên giấy trông y hệt một hàng rào thật, cho tới ngày ai đó bung một
        // tệp nén lấy trên mạng và nó ghi đè `~/.zshrc`.
        //
        // Bài này vì thế bung THẬT ra một thư mục tạm rồi đi soi đĩa: hai mục lành phải có mặt
        // với đúng nội dung, mục thoát ra ngoài phải KHÔNG có ở đâu cả.
        Case(name: "file nén: bung tất cả ghi đúng thư mục, mục thoát ra ngoài bị TỪ CHỐI") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("bung-\(UUID().uuidString)")
            let target = (folder as NSString).appendingPathComponent("đích")
            try? FileManager.default.createDirectory(
                atPath: target, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            let path = (folder as NSString).appendingPathComponent("thu.zip")
            guard let zip = Self.minimalZip([
                "ghi-chu.txt": "một\n",
                "thu-muc/trong-do.txt": "hai\n",
                "../thoat.txt": "BA — không được ra tới đây\n",
            ]) else { return "không dựng được zip thử" }
            try? zip.write(to: URL(fileURLWithPath: path))

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ArchiveViewerView
            else { return "khung con không phải khung file nén" }
            guard viewer.rowCountForSelfTest == 3 else {
                return "danh sách mục: \(viewer.entryPathsForSelfTest)"
            }

            viewer.extractAllForSelfTest(into: URL(fileURLWithPath: target))

            let manager = FileManager.default
            let lanh = (target as NSString).appendingPathComponent("ghi-chu.txt")
            let trongThuMuc = (target as NSString).appendingPathComponent("thu-muc/trong-do.txt")
            guard manager.fileExists(atPath: lanh) else { return "không bung ra ghi-chu.txt" }
            guard manager.fileExists(atPath: trongThuMuc) else {
                return "không tạo thư mục con khi bung"
            }
            guard (try? String(contentsOfFile: lanh, encoding: .utf8)) == "một\n" else {
                return "nội dung mục đã bung sai"
            }
            // Mục thoát ra ngoài: KHÔNG được có ở thư mục cha, cũng không được có trong đích.
            let thoat = (folder as NSString).appendingPathComponent("thoat.txt")
            guard !manager.fileExists(atPath: thoat) else {
                return "Zip Slip ĐI LỌT — «../thoat.txt» đã ghi ra ngoài thư mục đích"
            }
            guard !manager.fileExists(atPath:
                (target as NSString).appendingPathComponent("thoat.txt")) else {
                return "mục bị từ chối lại được ghi vào đích dưới tên khác"
            }
            // Và phải NÓI RA, không bỏ im lặng: người dùng cần biết tệp nén này định làm gì.
            let summary = viewer.summaryForSelfTest
            guard summary.contains("2"), summary.contains("1") else {
                return "dòng tổng kết không nói đủ «2 mục đã bung · 1 bị từ chối»: «\(summary)»"
            }
            return nil
        },

        // Mục KHÔNG phải văn bản đi đường khác hẳn: ghi ra tệp tạm rồi mở như một tệp bình
        // thường, để chính khung xem ảnh/PDF lo phần còn lại.
        Case(name: "file nén: mở một mục nhị phân thì ghi ra tệp tạm rồi mở như tệp thường") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("nen-nhi-phan-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("thu.zip")

            // Byte NUL là thứ phân biệt "văn bản" với "không phải văn bản" ở `asText`.
            guard let zip = Self.minimalZip(["anh.dat": "\u{0}\u{1}\u{2}nhị phân"]) else {
                return "không dựng được zip thử"
            }
            try? zip.write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ArchiveViewerView
            else { return "khung con không phải khung file nén" }

            let tabsBefore = controller.tabCountForSelfTest
            viewer.selectRowForSelfTest(0)
            viewer.openSelectedForSelfTest()
            guard controller.tabCountForSelfTest == tabsBefore + 1 else {
                return "mở mục nhị phân không tạo tab mới"
            }
            // Tab mới phải trỏ vào một TỆP trên đĩa — đó là cả điểm của nhánh này — và mang
            // đúng tên mục, chứ không phải một tab văn bản không tên.
            guard let opened = controller.editorDocument.path else {
                return "tab mới không có đường dẫn: mục nhị phân bị mở như văn bản"
            }
            guard (opened as NSString).lastPathComponent == "anh.dat" else {
                return "tệp tạm mang tên «\((opened as NSString).lastPathComponent)»"
            }
            return nil
        },

        Case(name: "Mở file nén qua libarchive: tầng thứ ba của khung xem có sống trong bundle") {
            controller in
            // VÌ SAO CÓ BÀI NÀY BÊN CẠNH BÀI ZIP Ở TRÊN. Khung xem file nén có ba tầng bộ đọc:
            // ZIP tự viết, TAR tự viết, rồi libarchive nạp từ nguồn. Bài ZIP dừng ở tầng một —
            // nó không bao giờ chạm tới libarchive. Mà libarchive mới là tầng mang lời hứa
            // đáng ngờ nhất: rằng bản App Store, chạy trong sandbox, mở được .7z và .rar mà
            // KHÔNG sinh tiến trình con nào.
            //
            // Lời hứa ấy chỉ kiểm được ở đây, trong bundle thật. `swift test` chạy ngoài
            // sandbox, nên nó không phân biệt được "thư viện tĩnh làm được" với "tiến trình con
            // làm được".
            //
            // Dùng cpio chứ không dùng .7z: định dạng cpio "070707" là văn bản bát phân thuần,
            // dựng bằng tay trong hai chục dòng. Dựng một kho .7z bằng tay thì cần cả bộ nén
            // LZMA, còn gọi công cụ ngoài lại đúng thứ bài này sinh ra để chứng minh là không
            // cần. Tầng bộ đọc là MỘT — cpio đi qua đúng đường mà .7z đi.
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("media-cpio-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("thu.cpio")

            let noiDung = "Xin chào từ libarchive — có dấu tiếng Việt\n"
            try? Self.minimalCpio(["bao-cao.txt": noiDung])
                .write(to: URL(fileURLWithPath: path))

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .archive else {
                return "không nhận ra file nén"
            }
            guard let viewer = controller.mediaViewer.contentForSelfTest as? ArchiveViewerView else {
                return "khung con không phải khung file nén"
            }
            guard viewer.entryPathsForSelfTest == ["bao-cao.txt"] else {
                return "libarchive không liệt kê được mục: \(viewer.entryPathsForSelfTest)"
            }

            let tabsBefore = controller.tabCountForSelfTest
            viewer.selectRowForSelfTest(0)
            viewer.openSelectedForSelfTest()
            guard controller.tabCountForSelfTest == tabsBefore + 1 else {
                return "mở mục không tạo tab mới"
            }
            // Nội dung phải nguyên vẹn KỂ CẢ dấu tiếng Việt: đó là chỗ `setlocale(LC_CTYPE)`
            // trong LibArchiveReader đang gánh, và là chỗ đã hỏng một lần.
            guard controller.documentTextForSelfTest == noiDung else {
                return "nội dung sai: \(String(reflecting: controller.documentTextForSelfTest))"
            }
            return nil
        },

        // MARK: - View / Code

        // Trang trợ giúp và mô hình phải nói CÙNG MỘT chuyện.
        //
        // Đây là chỗ dễ lệch nhất trong cả tính năng: ai đó dựng xong cây JSON, lật
        // `DisplayView.tree.isImplemented` sang `true`, và trang trợ giúp vẫn nói "chưa có" —
        // người dùng đọc trang ấy rồi không bao giờ thử. Cổng này bắt đúng chiều ấy.
        Case(name: "trang trợ giúp View/Code khớp với mô hình") { _ in
            let book = HelpContent.book(language: L10n.effective.rawValue)
            guard let topic = book.topic(id: "che-do-view-code") else {
                return "không có trang «che-do-view-code»"
            }
            // Soi TỪNG BẢNG một, không soi cả trang gộp lại.
            //
            // Bản đầu của cổng này hỏi "cả trang có nhắc cụm từ ấy không" — và nó để lọt đúng
            // cái nó sinh ra để bắt: dòng YAML chuyển từ bảng «CHƯA có View» sang bảng chính,
            // cụm từ vẫn còn nguyên trên trang, cổng vẫn xanh. Một cụm từ "có mặt đâu đó" không
            // trả lời được câu hỏi "nó nằm ở bảng nào".
            func rows(headerFirst: String, headerSecond: String) -> [[String]]? {
                for block in topic.blocks {
                    if case let .table(headers, rows) = block,
                       headers.count >= 2, headers[0] == headerFirst, headers[1] == headerSecond {
                        return rows
                    }
                }
                return nil
            }
            guard let bangChinh = rows(headerFirst: "Loại tệp", headerSecond: "View") else {
                return "không thấy bảng chính trong trang trợ giúp"
            }
            let bangChuaCo = rows(headerFirst: "Loại tệp", headerSecond: "View sẽ là")
            func coDong(_ bang: [[String]], _ tuKhoa: String) -> Bool {
                bang.contains { $0.contains { $0.contains(tuKhoa) } }
            }

            // Danh sách loại CHƯA dựng được nay RỖNG. Cổng vẫn phải chạy đúng ở cả hai trạng
            // thái, vì loại tệp mới sẽ lại làm nó không rỗng: rỗng thì trang KHÔNG được còn cái
            // bảng ấy — một bảng trống dưới tiêu đề "chưa có View" đọc như "chưa kiểm xong".
            let chuaCo: [(path: String, kind: MediaKind?, tuKhoa: String)] = []
            if chuaCo.isEmpty {
                guard bangChuaCo == nil else {
                    return "không loại nào còn thiếu View mà trang vẫn giữ bảng «CHƯA có View»"
                }
                let text = topic.blocks.flatMap { HelpBlockText.searchable($0) }
                    .joined(separator: " ")
                guard text.contains("nay đều dựng được") else {
                    return "trang trợ giúp chưa nói ra rằng không còn loại nào thiếu View"
                }
            } else {
                guard let bangChuaCo else {
                    return "còn loại thiếu View mà trang không có bảng «CHƯA có View»"
                }
                for muc in chuaCo {
                    let language: SyntaxLanguage? = SyntaxLanguage.detect(path: muc.path)
                    let modes = DisplayModes.of(path: muc.path, kind: muc.kind, language: language)
                    guard !modes.canToggle else {
                        return "«\(muc.path)» nay đã dựng được View — hãy chuyển nó ra khỏi bảng "
                            + "«CHƯA có View» trong trang trợ giúp rồi sửa bài kiểm này"
                    }
                    guard coDong(bangChuaCo, muc.tuKhoa) else {
                        return "bảng «CHƯA có View» không có dòng «\(muc.tuKhoa)»"
                    }
                    guard !coDong(bangChinh, muc.tuKhoa) else {
                        return "«\(muc.tuKhoa)» nằm ở CẢ HAI bảng — một loại tệp chỉ ở một bên"
                    }
                }
            }
            // Và không loại tệp nào được âm thầm khai là "chưa dựng" mà trang không nhắc tới.
            for path in ["so-do.mmd", "do-thi.dot", "slide.pptx", "a.yaml", "a.xml", "a.json"] {
                let kind: MediaKind? = path.hasSuffix(".pptx") ? .powerpoint : nil
                let modes = DisplayModes.of(
                    path: path, kind: kind, language: SyntaxLanguage.detect(path: path))
                guard modes.canToggle else {
                    return "«\(path)» khai là chưa dựng được View, mà danh sách ấy đang rỗng"
                }
            }

            // Chiều ngược lại: đã dựng được thì phải nằm ở BẢNG CHÍNH và rời khỏi bảng kia.
            let daCo: [(path: String, kind: MediaKind?, language: SyntaxLanguage?,
                        tuKhoa: String)] = [
                ("a.json", nil, .json, "Cây khoá–giá trị, gấp mở được"),
                ("a.xml", nil, .xml, "Cây thẻ, gấp mở được"),
                ("a.yaml", nil, .yaml, "Cây khoá–giá trị theo thụt lề"),
                ("slide.pptx", .powerpoint, nil, "Trang slide dựng ra"),
                ("so-do.mmd", nil, nil, "Sơ đồ vẽ ra, chiếm trọn tab"),
            ]
            for muc in daCo {
                guard DisplayModes.of(path: muc.path, kind: muc.kind, language: muc.language)
                    .canToggle
                else { return "«\(muc.path)» đang khai là chưa dựng được View" }
                guard coDong(bangChinh, muc.tuKhoa) else {
                    return "«\(muc.path)» đã dựng được mà bảng chính chưa có dòng «\(muc.tuKhoa)»"
                }
                guard !coDong(bangChuaCo ?? [], muc.tuKhoa) else {
                    return "«\(muc.path)» đã dựng được mà vẫn còn trong bảng «CHƯA có View»"
                }
            }

            // Các chế độ đã dựng được khác cũng phải có mặt ở BẢNG CHÍNH, không phải "đâu đó
            // trên trang".
            for tuKhoa in ["Bảng", "Trang dựng ra", "Chữ đã dựng", "Bộ phát", "Danh sách mục",
                           "Tô theo mức"] where !coDong(bangChinh, tuKhoa) {
                return "bảng chính thiếu dòng cho «\(tuKhoa)»"
            }
            // Hai ngoại lệ "sửa được ở View" phải được nói ra — chúng phá luật chung.
            let text = topic.blocks.flatMap { HelpBlockText.searchable($0) }.joined(separator: " ")
            guard text.contains("ô bảng CSV"), text.contains("ô biểu mẫu PDF") else {
                return "trang trợ giúp không nói ra hai ngoại lệ sửa-được-ở-View"
            }
            return nil
        },

        Case(name: "View/Code chọn đúng cặp chế độ cho từng loại tệp") { controller in
            // Đi qua ĐÚNG hàm mà lệnh menu gọi, không chép lại luật.
            func modes(_ path: String, _ kind: MediaKind?) -> DisplayModes {
                DisplayModes.of(path: path, kind: kind, language: nil)
            }
            guard modes("a.pdf", .pdf).code == .binary else { return "PDF: Code phải là byte" }
            guard modes("a.csv", nil).editing == .both else { return "CSV: phải sửa được cả hai" }
            guard DisplayModes.of(path: "a.json", kind: nil, language: .json).canToggle else {
                return "JSON phải đổi chế độ được — cây JSON đã dựng"
            }
            guard DisplayModes.of(path: "a.xml", kind: nil, language: .xml).canToggle else {
                return "XML phải đổi chế độ được — cây XML đã dựng"
            }
            guard DisplayModes.of(path: "a.yaml", kind: nil, language: .yaml).canToggle else {
                return "YAML phải đổi chế độ được — cây YAML đã dựng"
            }
            guard modes("slide.pptx", .powerpoint).canToggle else {
                return "PowerPoint phải đổi chế độ được — dàn ý đã dựng"
            }
            guard modes("so-do.mmd", nil).canToggle, modes("do-thi.dot", nil).canToggle else {
                return "sơ đồ phải đổi chế độ được — sơ đồ trong tab đã dựng"
            }

            // Và lệnh THẬT trên một tệp KHÔNG CÓ View phải nói ra, không im lặng. Trước đây bài
            // này dùng một tệp "có chỗ cho View nhưng chưa dựng"; loại ấy nay không còn cái nào,
            // nên nó chuyển sang mã nguồn — thứ không có View và đó là chuyện bình thường.
            let path = NSTemporaryDirectory() + "view-code-\(UUID().uuidString).swift"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data("let a = 1\n".utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            Unattended.resetLog()
            controller.toggleViewCode(nil)
            guard controller.lastTransientForSelfTest.contains("chỉ có một chế độ hiển thị") else {
                return "đổi chế độ trên mã nguồn không nói gì: «\(controller.lastTransientForSelfTest)»"
            }
            return nil
        },

        // Cây JSON: đi qua ĐÚNG lệnh người dùng bấm, không gọi thẳng khung nhìn.
        //
        // Vế đáng giá nhất là phép nhảy về nguồn: nó là thứ phân biệt một cây dùng được với một
        // bản in đẹp. Bài kiểm đòi con nháy rơi vào ĐÚNG byte của nút, không phải một chỗ hợp lệ
        // bất kỳ.
        Case(name: "cây JSON: bật bằng ⌥⌘V, bấm một nút là nhảy đúng byte trong nguồn") { controller in
            let json = """
                {
                  "ten": "An",
                  "dia_chi": {"tinh": "Huế"},
                  "diem": [9, 8, 10]
                }
                """
            let path = NSTemporaryDirectory() + "cay-\(UUID().uuidString).json"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(json.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            guard !controller.isStructureTreeVisible else { return "cây hiện sẵn khi chưa bấm gì" }
            controller.toggleViewCode(nil)
            guard controller.isStructureTreeVisible else {
                return "bấm đổi chế độ trên JSON mà cây không hiện: "
                    + "«\(controller.lastTransientForSelfTest)»"
            }

            let tree = controller.structureTree
            guard tree.nodeCountForSelfTest > 0 else { return "cây rỗng" }
            // Mở sẵn hai tầng đầu: gốc + ba khoá con phải thấy ngay, không phải bấm.
            guard tree.rowCountForSelfTest >= 4 else {
                return "chỉ hiện \(tree.rowCountForSelfTest) hàng — hai tầng đầu chưa mở sẵn"
            }

            // Tìm hàng của khoá `dia_chi` rồi bấm nó.
            var row = -1
            for index in 0 ..< tree.rowCountForSelfTest
            where tree.labelForSelfTest(row: index) == "dia_chi" { row = index; break }
            guard row >= 0 else { return "không thấy hàng «dia_chi» trong cây" }

            tree.clickRowForSelfTest(row)
            guard !controller.isStructureTreeVisible else {
                return "bấm một nút mà không quay về chế độ Code"
            }
            // Con nháy rơi vào GIÁ TRỊ của nút, không vào khoá — `JSONIndex.range` bao đúng
            // giá trị, và đó cũng là chỗ người ta muốn sửa. Bài kiểm khoá hành vi ấy lại thay vì
            // để nó trôi: nhảy tới một chỗ "gần đúng" là thứ chỉ lộ ra khi tệp lớn.
            let expected = Array(json.utf8).count - Array(
                json[json.range(of: "{\"tinh\"")!.lowerBound...].utf8).count
            guard controller.caretOffsetForSelfTest == expected else {
                return "con nháy ở byte \(controller.caretOffsetForSelfTest), mong \(expected)"
            }

            // Bấm lệnh lần nữa thì cây phải hiện lại — đây là một CÔNG TẮC.
            controller.toggleViewCode(nil)
            guard controller.isStructureTreeVisible else { return "bật lại lần hai không được" }
            controller.toggleViewCode(nil)
            guard !controller.isStructureTreeVisible else { return "tắt lần hai không được" }
            return nil
        },

        // Mở tệp ra là VÀO THẲNG chế độ View — `Settings.openInViewMode`, mặc định BẬT.
        //
        // Người dùng yêu cầu: *"các file nên để mặc định chế độ view nếu có"*. Bài này cũng giữ
        // vế NGƯỢC lại, và vế ấy quan trọng ngang: xem trước Markdown mở một CỬA SỔ riêng, nên
        // bật sẵn nó nghĩa là mỗi tệp `.md` mở ra đều bung thêm một cửa sổ không ai xin.
        Case(name: "mặc định vào View: tệp có View thì mở thẳng, .md thì KHÔNG bung cửa sổ") { controller in
            let folder = NSTemporaryDirectory() + "mac-dinh-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            func viet(_ ten: String, _ noi_dung: String) -> String {
                let path = (folder as NSString).appendingPathComponent(ten)
                try? Data(noi_dung.utf8).write(to: URL(fileURLWithPath: path))
                return path
            }

            // JSON: có cây → phải vào thẳng View.
            controller.resetWindowForSelfTest()
            controller.open(path: viet("a.json", "{\"a\": 1}\n"),
                            line: nil, column: nil, readOnly: false)
            controller.openDefaultViewModeForSelfTest()
            guard controller.isAnyViewModeVisible else {
                return "mở .json mà không vào thẳng chế độ View"
            }
            guard controller.documentToolbar.selectedIsViewForSelfTest else {
                return "đã ở View mà công tắc trên khung chung vẫn chỉ vào Code"
            }
            controller.hideAllViewModes()

            // Markdown: View của nó là một CỬA SỔ riêng — không được tự bung.
            //
            // Đóng cửa sổ xem trước TRƯỚC đã: một bài kiểm khác có thể đã mở nó, và khi ấy phép
            // hỏi dưới đây sẽ tố cáo bài này về một cửa sổ nó không hề bung ra.
            controller.markdownPreviewForSelfTest?.close()
            controller.resetWindowForSelfTest()
            controller.open(path: viet("b.md", "# Tiêu đề\n\nMột đoạn.\n"),
                            line: nil, column: nil, readOnly: false)
            controller.openDefaultViewModeForSelfTest()
            guard controller.markdownPreviewForSelfTest?.window?.isVisible != true else {
                return "mở .md mà tự bung cửa sổ xem trước"
            }

            // Mã nguồn: không có View, và cũng không được có gì hiện ra.
            controller.resetWindowForSelfTest()
            controller.open(path: viet("c.swift", "let x = 1\n"),
                            line: nil, column: nil, readOnly: false)
            controller.openDefaultViewModeForSelfTest()
            guard !controller.isAnyViewModeVisible else {
                return "mở tệp mã nguồn mà có khung View nào đó hiện ra"
            }
            return nil
        },

        // Mở LẠI một tệp Office từ phiên trước — chỗ người dùng vừa bắt được lỗi.
        //
        // Ba đường mở tệp từng gọi thẳng `Document.open` và bỏ qua phép nhận diện media: khôi
        // phục phiên, nạp lại khi tệp đổi trên đĩa, và chế độ theo dõi log. Hậu quả thấy ngay
        // trên màn hình: thoát app rồi mở lại, tab `.docx` quay về thành **byte ZIP thô** kèm
        // một bảng mã đoán bừa, và khung chung nói "tệp này chỉ có một chế độ hiển thị".
        //
        // `--doc-sweep` không thấy gì, vì nó chỉ mở tệp LẦN ĐẦU.
        Case(name: "mở lại từ phiên trước: tệp Office vẫn là Office, không thành byte thô",
             skipWhen: { _ in Self.fixtureUnreadable("data/vanban/Chuong1_Vuong_quoc_So.docx") }
        ) { controller in
            let path = Self.repoFile("data/vanban/Chuong1_Vuong_quoc_So.docx")
            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .word else {
                return "mở lần đầu đã sai loại: "
                    + "\(String(describing: controller.editorDocument.mediaKind))"
            }
            let lanDau = controller.documentTextForSelfTest

            // Đi qua ĐÚNG đường khôi phục phiên: ghi phiên, dọn cửa sổ, rồi khôi phục.
            controller.saveSession()
            controller.resetWindowForSelfTest()
            let soTab = controller.restoreSession()
            guard soTab > 0 else { return "không khôi phục được tab nào" }

            guard controller.editorDocument.mediaKind == .word else {
                return "khôi phục phiên xong, tệp Word thành "
                    + "\(String(describing: controller.editorDocument.mediaKind))"
            }
            // Vế nặng nhất: NỘI DUNG phải là chữ của tài liệu, không phải byte của tệp nén.
            let sauKhoiPhuc = controller.documentTextForSelfTest
            guard !sauKhoiPhuc.hasPrefix("PK") else {
                return "khôi phục xong ra BYTE ZIP THÔ — «\(sauKhoiPhuc.prefix(40))»"
            }
            guard sauKhoiPhuc == lanDau else {
                return "nội dung sau khôi phục khác lần mở đầu"
            }
            guard controller.documentToolbar.isEnabledForSelfTest else {
                return "khôi phục xong mà khung chung nói tệp chỉ có một chế độ"
            }
            return nil
        },

        // END-TO-END chế độ View trên TỆP THẬT của người dùng, đi hết mọi định dạng.
        //
        // Người dùng yêu cầu đúng bài này: *"test end to end tính năng view của tất cả các định
        // dạng"*, trên `data/vanban` — 63 tệp thật, không phải fixture dựng tay.
        //
        // Ba vế cho MỖI tệp, và vế thứ ba mới là vế hay bị bỏ:
        //   1. mở ra ĐÚNG loại (không rơi về văn bản thô);
        //   2. công tắc View của khung chung BẬT được;
        //   3. bấm View thì có khung hiện ra THẬT — không phải chỉ đổi cái nhãn.
        //
        // Bài trước đó (`--doc-sweep`) chỉ kiểm vế một. Vế ba là chỗ người dùng vừa báo hỏng.
        Case(name: "END-TO-END: mọi định dạng trong data/vanban đều VÀO được chế độ View",
             // Điều kiện bỏ qua phải trỏ vào một TỆP: `fixtureUnreadable` mở bằng `FileHandle`,
             // và mở một thư mục thì luôn thất bại — bản đầu vì thế tự bỏ qua chính nó ở mọi
             // lượt chạy, im lặng, mà vẫn hiện ra như một bài kiểm có tồn tại.
             skipWhen: { _ in Self.fixtureUnreadable("data/vanban/Chuong1_Vuong_quoc_So.docx") }
        ) { controller in
            let folder = Self.repoFile("data/vanban")
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            guard names.count > 20 else { return "thư mục tệp thật chỉ có \(names.count) mục" }

            // Một tệp cho MỖI đuôi — quét cả 63 tệp thì bài này chạy hàng phút, mà cái cần đo
            // là ĐƯỜNG ĐI của từng định dạng chứ không phải từng tệp.
            var chosen: [String: String] = [:]
            for name in names.sorted() {
                let ext = (name as NSString).pathExtension.lowercased()
                guard !ext.isEmpty, chosen[ext] == nil else { continue }
                chosen[ext] = (folder as NSString).appendingPathComponent(name)
            }
            guard chosen.count >= 5 else { return "chỉ thấy \(chosen.count) định dạng" }

            var hong: [String] = []
            var daVao: [String] = []
            for (ext, path) in chosen.sorted(by: { $0.key < $1.key }) {
                controller.resetWindowForSelfTest()
                controller.open(path: path, line: nil, column: nil, readOnly: false)
                let bar = controller.documentToolbar

                guard bar.isEnabledForSelfTest else {
                    // Văn bản thuần và mã nguồn KHÔNG có View — đó là đúng, không phải lỗi.
                    if ["txt", "md", "csv", "json", "log"].contains(ext) {
                        hong.append("\(ext): công tắc View TẮT dù định dạng này có chế độ View")
                    }
                    continue
                }
                guard !bar.kindForSelfTest.isEmpty else {
                    hong.append("\(ext): khung không nói View là gì")
                    continue
                }

                bar.clickForSelfTest(view: true)
                let vao = controller.waitForSelfTestPublic("View \(ext)", seconds: 25, until: {
                    controller.isAnyViewModeVisible
                })
                if vao {
                    daVao.append(ext)
                } else {
                    hong.append("\(ext): bấm View mà không khung nào hiện "
                                + "(«\(bar.kindForSelfTest)»)")
                }

                // Với Word và PowerPoint, "khung có hiện" chưa đủ. Khung ĐÃ hiện trong lần hỏng
                // đầu tiên — và nó trắng trơn. Nên ở hai định dạng này phải đo tới tận MỰC trên
                // giấy, thứ duy nhất phân biệt một trang dựng ra với một mảng trắng.
                if vao, ext == "docx" || ext == "pptx" {
                    let pages = controller.officePreview.pages
                    pages.layoutNowForSelfTest()
                    if pages.pageCountForSelfTest == 0 {
                        hong.append("\(ext): View mở ra mà không có trang nào")
                    } else if pages.firstPageInkForSelfTest() <= 0.002 {
                        hong.append("\(ext): tờ giấy đầu trắng trơn")
                    }
                }
                controller.hideAllViewModes()
            }

            guard hong.isEmpty else {
                return "\(hong.count) định dạng hỏng — " + hong.joined(separator: " · ")
            }
            guard daVao.count >= 5 else {
                return "chỉ \(daVao.count) định dạng vào được View: \(daVao)"
            }
            return nil
        },

        // Khung chung trên đầu cửa sổ — MỌI loại tệp cùng một chỗ, cùng một hình dạng.
        //
        // Người dùng nói: *"thống nhất một khung chung, và khung phải nằm trên top"*. Trước đây
        // mỗi chế độ View tự dựng thanh công cụ riêng — PDF hai hàng nút, bảng CSV một kiểu, cây
        // một kiểu — nên mở tệp mới là phải học lại chỗ bấm.
        //
        // Bài này đi qua BỐN loại tệp khác hẳn nhau và đòi khung nói đúng ở cả bốn: cùng công
        // tắc, đúng tên chế độ View của loại ấy, và bấm được.
        Case(name: "khung chung: bốn loại tệp, cùng một công tắc, tên chế độ View nói đúng loại") { controller in
            let folder = NSTemporaryDirectory() + "khung-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            func viet(_ ten: String, _ noi_dung: String) -> String {
                let path = (folder as NSString).appendingPathComponent(ten)
                try? Data(noi_dung.utf8).write(to: URL(fileURLWithPath: path))
                return path
            }

            // (tệp, chữ phải có trong tên chế độ View, có đổi chế độ được không)
            let ca: [(String, String, Bool)] = [
                (viet("a.json", "{\"a\": 1}\n"), "Cây", true),
                (viet("b.csv", "ma,ten\n1,An\n"), "Bảng", true),
                (viet("c.mmd", "graph TD\n  A --> B\n"), "Sơ đồ", true),
                // Tệp một chế độ: khung phải NÓI RA lý do, không để một công tắc mờ câm lặng.
                (viet("d.swift", "let x = 1\n"), "một chế độ", false),
            ]

            for (path, mongDoi, doiDuoc) in ca {
                controller.open(path: path, line: nil, column: nil, readOnly: false)
                let ten = (path as NSString).lastPathComponent
                let bar = controller.documentToolbar
                guard bar.isEnabledForSelfTest == doiDuoc else {
                    return "«\(ten)»: công tắc \(bar.isEnabledForSelfTest ? "bật" : "tắt") "
                        + "trong khi mong \(doiDuoc ? "bật" : "tắt")"
                }
                guard bar.kindForSelfTest.contains(mongDoi) else {
                    return "«\(ten)»: khung nói «\(bar.kindForSelfTest)», mong có «\(mongDoi)»"
                }
                guard !bar.selectedIsViewForSelfTest else {
                    return "«\(ten)»: vừa mở đã ở chế độ View"
                }
                guard doiDuoc else { continue }

                // Bấm nửa «View» của công tắc — đúng thao tác người dùng làm.
                bar.clickForSelfTest(view: true)
                // Vài chế độ View dựng ở luồng nền — bảng CSV phải đợi chỉ mục hàng, sơ đồ phải
                // đợi lượt vẽ. Hỏi ngay sau cú bấm là hỏi trước khi việc xong.
                guard controller.waitForSelfTestPublic("khung View \(ten)", seconds: 20, until: {
                    controller.isAnyViewModeVisible
                }) else {
                    return "«\(ten)»: bấm View trên khung chung mà không có khung nào hiện"
                }
                guard bar.selectedIsViewForSelfTest else {
                    return "«\(ten)»: đang ở View mà công tắc vẫn chỉ vào Code"
                }
                bar.clickForSelfTest(view: false)
                guard controller.waitForSelfTestPublic("về Code \(ten)", seconds: 10, until: {
                    !controller.isAnyViewModeVisible
                }) else {
                    return "«\(ten)»: bấm Code mà khung View không tắt"
                }
            }
            return nil
        },

        // Tệp Office xem như một trình đọc tài liệu, không phải như chữ rút ra.
        //
        // Người dùng nói: *"docx, pdf, xlsx, pptx phải view như trình view office và pdf"*. Vế
        // đắt nhất của bài này là vế CHỈ ĐỌC-và-nói-thật: QuickLook dựng tệp TRÊN ĐĨA, nên khi
        // buffer đã sửa mà chưa lưu thì trang bên View là bản CŨ — và người dùng phải được biết
        // điều đó, không thì họ đọc một tài liệu không còn tồn tại.
        Case(name: "Office: View dựng TRANG tài liệu, và nói ra khi bản trên đĩa đã cũ") { controller in
            let folder = NSTemporaryDirectory() + "office-view-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            func paragraph(_ text: String) -> String {
                "<w:p><w:r><w:t>\(text)</w:t></w:r></w:p>"
            }
            guard let docx = Self.minimalZip([
                "word/document.xml": "<?xml version=\"1.0\"?><w:document "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                    + "<w:body>" + paragraph("Báo cáo quý I") + "</w:body></w:document>",
            ]) else { return "không dựng được .docx thử" }
            let path = (folder as NSString).appendingPathComponent("bao-cao.docx")
            try? docx.write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            // Khung chung phải gọi tên đúng: «Trang tài liệu», không phải «Chữ đã dựng».
            guard controller.documentToolbar.kindForSelfTest.contains("Trang") else {
                return "khung nói «\(controller.documentToolbar.kindForSelfTest)» cho .docx"
            }

            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.isOfficePreviewVisible else {
                return "bấm View trên .docx mà không mở khung xem trang"
            }
            guard controller.officePreview.previewedPathForSelfTest == path else {
                return "khung xem đang dựng «"
                    + (controller.officePreview.previewedPathForSelfTest ?? "không có") + "»"
            }
            // Chưa sửa gì thì không có cảnh báo nào.
            guard controller.officePreview.noticeForSelfTest.isEmpty else {
                return "chưa sửa gì mà đã báo bản trên đĩa cũ"
            }

            // Sửa ở Code rồi quay lại View: phải NÓI RA rằng trang đang xem là bản cũ.
            controller.documentToolbar.clickForSelfTest(view: false)
            controller.prepareSelfTestEditToDocument(
                controller.documentTextForSelfTest + "\ndòng mới chưa lưu\n")
            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.officePreview.noticeForSelfTest.contains("chưa lưu") else {
                return "sửa mà chưa lưu, nhưng khung xem không nói gì: «"
                    + controller.officePreview.noticeForSelfTest + "»"
            }
            controller.documentToolbar.clickForSelfTest(view: false)
            return nil
        },

        // Trang có VẼ RA THẬT không, và có chiếm hết bề ngang không.
        //
        // Hai câu này là hai lỗi thật, và cả hai đều lọt qua mọi phép so đã có.
        //
        // **Bề ngang** là điều người dùng báo: *"màn view của Office rất nhỏ so với không gian
        // của ứng dụng về chiều ngang"*. Bản dùng QuickLook vẽ trang ở khổ tự nhiên rồi căn
        // giữa, và không có API nào bảo nó làm khác.
        //
        // **Vẽ ra thật** là lỗi của chính bản thay thế, và nó tệ hơn: `draw` chạy đủ 2400 lượt,
        // số trang đúng, bề ngang đúng, xuất một tờ ra PDF thì đủ chữ đủ màu đủ ảnh — mà màn
        // hình trắng trơn. Nguyên nhân nằm ở `wantsLayer`: nó ép cả cây bên dưới thành
        // layer-backed, và tờ canvas cao hơn 30.000 pt vượt giới hạn texture của CoreAnimation.
        // Không có ngoại lệ, không có cảnh báo — chỉ là không vẽ.
        //
        // Nên bài này đo BA thứ: có mực trên giấy · giấy rộng gần bằng khung · và không view nào
        // trên đường ấy bật layer.
        Case(name: "Office: trang có MỰC thật, rộng gần bằng khung, và không view nào bật layer") { controller in
            let folder = NSTemporaryDirectory() + "trang-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            // Đủ chữ để ra nhiều hơn một trang — bộ phân trang chỉ lộ ra khi phải cắt thật.
            let body = (1 ... 400).map {
                "<w:p><w:r><w:rPr><w:sz w:val=\"24\"/></w:rPr>"
                    + "<w:t>Dòng thứ \($0) của tài liệu thử, đủ dài để chiếm hết bề ngang trang "
                    + "giấy và buộc bộ dựng phải ngắt dòng.</w:t></w:r></w:p>"
            }.joined()
            guard let docx = Self.minimalZip([
                "word/document.xml": "<?xml version=\"1.0\"?><w:document "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                    + "<w:body>" + body
                    + "<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/>"
                    + "<w:pgMar w:top=\"1134\" w:right=\"1134\" w:bottom=\"1134\" "
                    + "w:left=\"1134\"/></w:sectPr></w:body></w:document>",
            ]) else { return "không dựng được .docx thử" }
            let path = (folder as NSString).appendingPathComponent("nhieu-trang.docx")
            try? docx.write(to: URL(fileURLWithPath: path))

            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.isOfficePreviewVisible else { return "không mở được khung trang" }

            let pages = controller.officePreview.pages
            pages.layoutNowForSelfTest()

            guard pages.pageCountForSelfTest > 1 else {
                return "400 đoạn chữ mà chỉ ra \(pages.pageCountForSelfTest) trang — bộ phân "
                    + "trang không cắt"
            }

            let layered = pages.layerBackedAnywhereForSelfTest
            guard layered.isEmpty else {
                return "đường dựng trang bật layer ở \(layered) — canvas cao vài chục nghìn "
                    + "point sẽ không vẽ ra gì"
            }

            let ink = pages.firstPageInkForSelfTest()
            guard ink > 0.005 else {
                return "tờ giấy đầu gần như trắng (\(Int(ink * 1000))‰ điểm ảnh có mực)"
            }

            // Vừa bề ngang: tờ giấy phải chiếm gần hết khung, chỉ chừa lề và thanh cuộn.
            pages.zoom = .fitWidth
            pages.layoutNowForSelfTest()
            let khung = pages.bounds.width
            let giay = pages.pageWidthOnScreenForSelfTest
            guard khung > 200 else { return "khung xem chỉ rộng \(Int(khung)) pt" }
            guard giay >= khung * 0.85 else {
                return "vừa-bề-ngang mà tờ giấy chỉ rộng \(Int(giay))/\(Int(khung)) pt"
            }

            // Vừa trang: cả tờ phải lọt trong khung, nếu không thì nút ấy nói dối tên nó.
            pages.zoom = .fitPage
            pages.layoutNowForSelfTest()
            let cao = pages.pageWidthOnScreenForSelfTest / 210 * 297   // A4
            guard cao <= pages.bounds.height + 1 else {
                return "vừa-trang mà tờ giấy cao \(Int(cao)) pt trong khung \(Int(pages.bounds.height)) pt"
            }
            controller.hideAllViewModes()
            return nil
        },

        // Ảnh nhúng phải đi HẾT đường: từ gói zip, qua mô hình trang, tới bản dựng.
        //
        // Đây là lý do sản phẩm tự đọc `.docx` thay vì gọi bộ nhập OOXML của AppKit. Bộ nhập ấy
        // đọc được font, cỡ, màu, bảng, khổ giấy — và **vứt sạch ảnh**. Đo trên tệp thật của
        // người dùng: gói có 15 tệp trong `word/media/`, chuỗi nó trả về có 0 ký tự đính kèm.
        Case(name: "Office: ảnh nhúng còn nguyên trong bản dựng trang") { controller in
            let folder = NSTemporaryDirectory() + "anh-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            // PNG 2×2 đỏ, viết thẳng bằng byte: ảnh phải là thứ giải mã được thật, không phải
            // một chuỗi giả — `NSImage(data:)` trả nil cho rác và bài kiểm sẽ xanh vì lý do sai.
            let png = Data(base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFklEQVQIHWP8z8Dwn4"
                + "EIwESEGjBhagAAcxwCAI8fWtEAAAAASUVORK5CYII=")
            guard let png, NSImage(data: png) != nil else { return "PNG thử không giải mã được" }

            guard var docx = Self.minimalZip([
                "word/document.xml": "<?xml version=\"1.0\"?><w:document "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
                    + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
                    + "xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" "
                    + "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">"
                    + "<w:body><w:p><w:r><w:drawing><wp:inline>"
                    + "<wp:extent cx=\"1828800\" cy=\"1828800\"/>"
                    + "<a:blip r:embed=\"rId5\"/></wp:inline></w:drawing></w:r></w:p>"
                    + "<w:p><w:r><w:t>Có ảnh phía trên</w:t></w:r></w:p></w:body></w:document>",
                "word/_rels/document.xml.rels": "<?xml version=\"1.0\"?><Relationships "
                    + "xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                    + "<Relationship Id=\"rId5\" Type=\"image\" Target=\"media/o.png\"/>"
                    + "</Relationships>",
                "word/media/o.png": String(decoding: png, as: UTF8.self),
            ]) else { return "không dựng được .docx có ảnh" }

            // `minimalZip` nhận chuỗi, mà PNG không phải văn bản UTF-8: dựng gói bằng đường
            // chuỗi rồi vá lại byte ảnh là mời một lỗi khác. Ghi tệp rồi kiểm bằng chính bộ đọc
            // của lõi — nếu lõi không thấy ảnh thì bài này phải ĐỎ chứ không được bỏ qua.
            let path = (folder as NSString).appendingPathComponent("co-anh.docx")
            try? docx.write(to: URL(fileURLWithPath: path))
            docx = Data()

            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.isOfficePreviewVisible else { return "không mở được khung trang" }
            guard controller.officePreview.imageCountForSelfTest >= 1 else {
                return "gói có ảnh mà bản dựng không mang ảnh nào"
            }
            controller.hideAllViewModes()
            return nil
        },

        // PowerPoint: View là SLIDE DỰNG RA, không phải dàn ý đổ lên tờ trắng.
        //
        // Bản đầu của chế độ này đổ dàn ý lên giấy và nói thật về giới hạn ấy bằng một dòng chữ
        // trên khung. Đọc được — nhưng "đọc được" không phải thứ người ta mở một bộ slide để
        // tìm. Bài này canh phần đã trả nợ: hộp chữ có CHỖ ĐỨNG riêng, khổ đúng 16:9 của tệp,
        // cỡ chữ tiêu đề lấy từ master chứ không phải một con số cố định.
        Case(name: "PowerPoint: slide dựng theo hình khối có toạ độ, khổ và cỡ chữ lấy từ tệp",
             skipWhen: { _ in Self.fixtureUnreadable("data/vanban/ngon-ngu/bao-cao-quy.pptx") }
        ) { controller in
            let path = Self.repoFile("data/vanban/ngon-ngu/bao-cao-quy.pptx")
            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .powerpoint else {
                return "không nhận ra .pptx"
            }
            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.isOfficePreviewVisible else { return "không mở được trang slide" }

            let pages = controller.officePreview.pages
            pages.layoutNowForSelfTest()
            guard pages.pageCountForSelfTest >= 2 else {
                return "bộ slide ra \(pages.pageCountForSelfTest) trang"
            }
            guard pages.firstPageInkForSelfTest() > 0.002 else { return "slide đầu trắng trơn" }

            // Khổ phải lấy từ `p:sldSz` của tệp, không phải một con số đoán. Slide 16:9 rộng
            // hơn cao rõ rệt — một tờ A4 dọc lọt vào đây là dấu hiệu đọc nhầm khổ.
            let ratio = pages.pageAspectForSelfTest
            guard ratio > 1.3 else {
                return "khổ slide ra tỉ lệ \(String(format: "%.2f", ratio)), không phải nằm ngang"
            }

            // Mô hình slide phải có nhiều hơn MỘT hộp, và các hộp phải nằm ở chỗ khác nhau —
            // nếu tất cả cùng toạ độ thì phép thừa kế layout/master đã không chạy.
            let deck = try? PPTXLayout.read(path: path)
            guard let deck, let first = deck.slides.first else { return "không đọc được mô hình" }
            guard first.shapes.count >= 2 else {
                return "slide đầu chỉ có \(first.shapes.count) hộp"
            }
            let origins = Set(first.shapes.map { "\(Int($0.x)),\(Int($0.y))" })
            guard origins.count >= 2 else {
                return "mọi hộp cùng một chỗ đứng — thừa kế layout/master không chạy"
            }
            guard first.shapes.allSatisfy({ $0.width > 1 && $0.height > 1 }) else {
                return "có hộp rộng 0 pt — nó sẽ biến mất khi vẽ"
            }

            // Cỡ chữ tiêu đề phải LỚN HƠN hẳn chữ thân. Cả hai bằng nhau nghĩa là `p:txStyles`
            // của master chưa được đọc, và slide hiện ra như một khối chữ đều tăm tắp.
            func size(of shape: PPTXLayout.Shape) -> Double {
                for paragraph in shape.paragraphs {
                    for inline in paragraph.inlines {
                        if case .text(_, let style) = inline { return style.sizePt }
                    }
                }
                return 0
            }
            let title = first.shapes.first { ($0.placeholderKey ?? "").hasPrefix("title")
                || ($0.placeholderKey ?? "").hasPrefix("ctrTitle") }
            let others = first.shapes.filter { $0.placeholderKey != title?.placeholderKey }
            if let title, let body = others.first(where: { size(of: $0) > 0 }) {
                guard size(of: title) > size(of: body) else {
                    return "tiêu đề \(size(of: title)) pt không lớn hơn thân \(size(of: body)) pt"
                }
            }

            // Dàn ý — cách nhìn thứ hai — vẫn phải mở được từ khung chung.
            controller.toggleOutlineTree(nil)
            guard !controller.isOfficePreviewVisible else {
                return "bật dàn ý mà trang slide vẫn che bên dưới"
            }
            controller.hideAllViewModes()
            return nil
        },

        // Mỗi PHẦN của tài liệu mang chân trang riêng, và trang lấy đúng của phần chứa nó.
        //
        // Sách in chia phần ở mỗi chương. Đo trên sách thật của người dùng: 45 phần, 35 phần
        // khai đầu/chân trang riêng. Dùng một bản cho cả cuốn thì 34 phần hiện sai tên chương —
        // đúng chỗ người đọc nhìn để biết mình đang ở đâu.
        //
        // Bài này hỏi CHỮ chứ không hỏi mực: ảnh chụp nói được "có chân trang", không nói được
        // "chân trang của phần nào".
        Case(name: "Trang tài liệu: mỗi phần lấy đúng chân trang của phần ấy") { controller in
            let folder = NSTemporaryDirectory() + "phan-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            func footer(_ text: String) -> String {
                "<?xml version=\"1.0\"?><w:ftr "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                    + "<w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:ftr>"
            }
            func filler(_ label: String, _ count: Int) -> String {
                (1 ... count).map {
                    "<w:p><w:r><w:rPr><w:sz w:val=\"24\"/></w:rPr><w:t>\(label) dòng \($0), "
                        + "đủ dài để phần này chiếm hơn một trang giấy.</w:t></w:r></w:p>"
                }.joined()
            }
            let page = "<w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1440\" "
                + "w:right=\"1134\" w:bottom=\"1440\" w:left=\"1134\"/>"
            let document = "<?xml version=\"1.0\"?><w:document "
                + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
                + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
                + "<w:body>" + filler("Chương một", 90)
                + "<w:p><w:pPr><w:sectPr>"
                + "<w:footerReference w:type=\"default\" r:id=\"rIdA\"/>" + page
                + "</w:sectPr></w:pPr><w:r><w:t>hết chương một</w:t></w:r></w:p>"
                + filler("Chương hai", 90)
                + "<w:sectPr><w:footerReference w:type=\"default\" r:id=\"rIdB\"/>" + page
                + "</w:sectPr></w:body></w:document>"
            let rels = "<?xml version=\"1.0\"?><Relationships "
                + "xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                + "<Relationship Id=\"rIdA\" Type=\"footer\" Target=\"footerA.xml\"/>"
                + "<Relationship Id=\"rIdB\" Type=\"footer\" Target=\"footerB.xml\"/>"
                + "</Relationships>"

            guard let docx = Self.minimalZip([
                "word/document.xml": document,
                "word/footerA.xml": footer("PHẦN MỘT"),
                "word/footerB.xml": footer("PHẦN HAI"),
                "word/_rels/document.xml.rels": rels,
            ]) else { return "không dựng được .docx thử" }
            let path = (folder as NSString).appendingPathComponent("hai-phan.docx")
            try? docx.write(to: URL(fileURLWithPath: path))

            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.isOfficePreviewVisible else { return "không mở được khung trang" }
            let pages = controller.officePreview.pages
            pages.layoutNowForSelfTest()

            let total = pages.pageCountForSelfTest
            guard total >= 4 else { return "hai phần × 90 dòng mà chỉ ra \(total) trang" }

            let first = pages.footerTextForSelfTest(page: 0)
            let last = pages.footerTextForSelfTest(page: total - 1)
            guard first == "PHẦN MỘT" else {
                return "trang đầu lấy chân trang «\(first)», phải là «PHẦN MỘT»"
            }
            guard last == "PHẦN HAI" else {
                return "trang cuối lấy chân trang «\(last)», phải là «PHẦN HAI» — "
                    + "cả cuốn đang dùng chung chân trang của phần đầu"
            }

            // Và phần hai phải bắt đầu ở TRANG MỚI, đúng cách Word ngắt phần.
            let firstOfSecond = (0 ..< total).first {
                pages.footerTextForSelfTest(page: $0) == "PHẦN HAI"
            }
            guard let firstOfSecond, firstOfSecond > 0 else {
                return "không tìm thấy trang nào thuộc phần hai"
            }
            guard pages.footerTextForSelfTest(page: firstOfSecond - 1) == "PHẦN MỘT" else {
                return "ranh giới hai phần không nằm giữa hai trang"
            }
            controller.hideAllViewModes()
            return nil
        },

        // Khung chung không được NÓI NGƯỢC với thứ đang hiện trên màn hình.
        //
        // Ảnh chụp màn hình lộ ra hai chỗ nghi ngờ, và cả hai đều là kiểu lỗi tệ nhất: giao
        // diện nói một đằng, màn hình hiện một nẻo. Bài này hỏi cả hai.
        Case(name: "khung chung và thanh trạng thái không nói ngược với màn hình") { controller in
            let folder = NSTemporaryDirectory() + "noi-nguoc-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            // VẾ MỘT — tài liệu CHƯA ĐẶT TÊN mang nội dung CSV.
            //
            // `DisplayModes` nhận loại theo đường dẫn, mà tài liệu chưa lưu thì không có đường
            // dẫn. Nếu bảng hiện ra được thì khung chung KHÔNG được bảo "tệp này chỉ có một chế
            // độ hiển thị" — người dùng đang nhìn thẳng vào chế độ thứ hai.
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestEditToDocument("ten,tuoi\nAn,30\nBinh,25\n")
            controller.showTableViewForSelfTest()
            _ = controller.waitForSelfTestPublic("bảng CSV", seconds: 10, until: {
                controller.isTableViewVisibleForSelfTest
            })
            if controller.isTableViewVisibleForSelfTest {
                let kind = controller.documentToolbar.kindForSelfTest
                guard controller.documentToolbar.isEnabledForSelfTest else {
                    return "bảng CSV đang hiện mà công tắc View/Code TẮT, kèm chữ «\(kind)»"
                }
                guard controller.documentToolbar.selectedIsViewForSelfTest else {
                    return "bảng CSV đang hiện mà công tắc vẫn chỉ Code"
                }
            }
            controller.hideAllViewModes()

            // VẾ HAI — đổi tab thì thanh trạng thái phải theo tab MỚI.
            //
            // Mục «CSV · dấu phẩy» của tab bảng mà còn nằm đó khi đang mở tệp JSON thì nó đang
            // mô tả một tài liệu khác — và nó là thứ người dùng tin để biết dấu phân tách nào
            // đang dùng.
            let csv = (folder as NSString).appendingPathComponent("bang.csv")
            let json = (folder as NSString).appendingPathComponent("cay.json")
            try? "ten,tuoi\nAn,30\n".write(toFile: csv, atomically: true, encoding: .utf8)
            try? "{\"a\": 1}".write(toFile: json, atomically: true, encoding: .utf8)

            controller.resetTabsForSelfTest()
            controller.openInNewTabForSelfTest(path: csv)
            guard controller.statusModeForSelfTest?.contains("CSV") == true else {
                return "mở .csv mà thanh trạng thái không nói CSV: "
                    + "«\(controller.statusModeForSelfTest ?? "trống")»"
            }
            controller.openInNewTabForSelfTest(path: json)
            let mode = controller.statusModeForSelfTest ?? ""
            guard !mode.contains("CSV") else {
                return "đang ở tab .json mà thanh trạng thái vẫn nói «\(mode)» của tab trước"
            }
            controller.resetTabsForSelfTest()
            return nil
        },

        // Ô «Kết quả tìm kiếm» chỉ được mang KẾT QUẢ TÌM.
        //
        // Ảnh chụp bắt được: sau khi quét Bàn làm sạch, panel Tìm hiện «Không phát hiện gì cần
        // làm sạch» đúng chỗ đáng lẽ ghi «3/17». Hai tính năng khác đang ghi vào ô của tính năng
        // thứ ba, và ô ấy có nhãn trợ năng là «Kết quả tìm kiếm» — nó nói dối cả với người nhìn
        // lẫn với người nghe.
        Case(name: "ô kết quả tìm kiếm không mang chữ của tính năng khác") { controller in
            controller.resetTabsForSelfTest()
            controller.prepareSelfTestEditToDocument("ten,tuoi\nAn,30\nBinh,25\n")
            controller.showTableViewForSelfTest()
            _ = controller.waitForSelfTestPublic("bảng CSV", seconds: 10, until: {
                controller.isTableViewVisibleForSelfTest
            })
            controller.showFindPanel(nil)
            controller.findPanelSetStatusForSelfTest("")

            // Một tin của BẢNG, phát đúng đường mà phép sắp xếp phát.
            controller.emitTableStatusForSelfTest("Sắp xếp theo tuoi ↑ · chỉ hiển thị")
            guard controller.lastTransientForSelfTest.contains("Sắp xếp") else {
                return "tin của bảng không tới dải băng chung: "
                    + "«\(controller.lastTransientForSelfTest)»"
            }
            let inFind = controller.findPanelStatusForSelfTest
            guard inFind.isEmpty else {
                return "ô kết quả tìm kiếm đang mang «\(inFind)» — tin của bảng, không phải "
                    + "kết quả tìm"
            }
            controller.hideAllViewModes()
            controller.resetTabsForSelfTest()
            return nil
        },

        // Chọn chữ trên trang, và ⌘C chép ĐÚNG thứ đang bôi đen.
        //
        // Một trình đọc tài liệu không chép được chữ ra thì người ta phải mở lại tệp bằng Word.
        // Vế thứ hai là mẫu lỗi đã gặp bốn lần ở sản phẩm này: **lệnh chung tác động lên thứ
        // đang bị che**. ⌘C khi trang đang phủ kín vùng soạn thảo mà lại chép nội dung vùng soạn
        // thảo thì người dùng dán ra một thứ họ không hề nhìn thấy, và không có gì báo.
        Case(name: "Trang tài liệu: chọn được chữ, và ⌘C chép đúng thứ đang bôi đen") { controller in
            let folder = NSTemporaryDirectory() + "chon-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            let unique = "Vương quốc Số có năm ổ khoá"
            let body = "<w:p><w:r><w:t>\(unique)</w:t></w:r></w:p>"
                + (1 ... 40).map {
                    "<w:p><w:r><w:t>Dòng đệm số \($0).</w:t></w:r></w:p>"
                }.joined()
            guard let docx = Self.minimalZip([
                "word/document.xml": "<?xml version=\"1.0\"?><w:document "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                    + "<w:body>" + body + "</w:body></w:document>",
            ]) else { return "không dựng được .docx thử" }
            let path = (folder as NSString).appendingPathComponent("chon.docx")
            try? docx.write(to: URL(fileURLWithPath: path))

            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.isOfficePreviewVisible else { return "không mở được khung trang" }
            let pages = controller.officePreview.pages
            pages.layoutNowForSelfTest()

            // Chưa chọn gì thì ⌘C phải NÓI RA, không được lặng lẽ chép nội dung vùng soạn thảo.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("dấu vết cũ", forType: .string)
            controller.copySelection(nil)
            guard NSPasteboard.general.string(forType: .string) == "dấu vết cũ" else {
                return "chưa chọn gì mà ⌘C vẫn ghi đè clipboard — nhiều khả năng nó chép "
                    + "vùng soạn thảo đang bị che"
            }

            pages.selectAllText()
            let selected = pages.selectedText
            guard selected.contains(unique) else {
                return "chọn tất cả mà không lấy được chữ trên trang: «\(selected.prefix(40))»"
            }
            guard selected.contains("Dòng đệm số 40") else {
                return "chọn tất cả chỉ lấy được trang đầu"
            }

            controller.copySelection(nil)
            let pasted = NSPasteboard.general.string(forType: .string) ?? ""
            guard pasted.contains(unique) else {
                return "⌘C không chép được chữ đang bôi đen"
            }

            // Bỏ chọn thì trở lại trạng thái "chưa chọn gì".
            pages.clearSelection()
            guard pages.selectedText.isEmpty else { return "bỏ chọn mà vẫn còn vùng chọn" }
            controller.hideAllViewModes()
            return nil
        },

        // Đầu và chân trang — và SỐ TRANG trong đó.
        //
        // Đây là thứ đầu tiên người ta tìm khi đối chiếu bản dựng với bản in. Trường `PAGE` chỉ
        // có giá trị lúc VẼ (cùng một chân trang dùng lại cho 383 tờ, mỗi tờ một con số), nên nó
        // đi qua lõi dưới dạng một chỗ trống có tên rồi mới được điền.
        //
        // Bài này đo theo DẢI: cả tờ thì phần thân át hết, và một chân trang biến mất vẫn cho ra
        // con số y hệt. Kèm đối chứng âm — cùng tài liệu ấy, bỏ chân trang đi, dải dưới phải sạch.
        Case(name: "Trang tài liệu: chân trang hiện ra trong băng lề, và mang đúng số trang") { controller in
            let folder = NSTemporaryDirectory() + "chan-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            let body = (1 ... 120).map {
                "<w:p><w:r><w:rPr><w:sz w:val=\"24\"/></w:rPr><w:t>Dòng \($0) của phần thân, "
                    + "dài vừa đủ để tài liệu phải cắt ra nhiều trang.</w:t></w:r></w:p>"
            }.joined()
            let section = "<w:sectPr>%@<w:pgSz w:w=\"11906\" w:h=\"16838\"/>"
                + "<w:pgMar w:top=\"1440\" w:right=\"1134\" w:bottom=\"1440\" "
                + "w:left=\"1134\" w:header=\"709\" w:footer=\"709\"/></w:sectPr>"
            func document(_ reference: String) -> String {
                "<?xml version=\"1.0\"?><w:document "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
                    + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
                    + "<w:body>" + body
                    + String(format: section, reference) + "</w:body></w:document>"
            }
            // Chân trang «— <PAGE> —» căn giữa, đúng hình dạng sách in dùng.
            let footer = "<?xml version=\"1.0\"?><w:ftr "
                + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                + "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>"
                + "<w:r><w:rPr><w:sz w:val=\"20\"/></w:rPr><w:t xml:space=\"preserve\">— </w:t></w:r>"
                + "<w:r><w:instrText>PAGE</w:instrText></w:r>"
                + "<w:r><w:rPr><w:sz w:val=\"20\"/></w:rPr><w:t xml:space=\"preserve\"> —</w:t></w:r>"
                + "</w:p></w:ftr>"
            let rels = "<?xml version=\"1.0\"?><Relationships "
                + "xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                + "<Relationship Id=\"rId3\" Type=\"footer\" Target=\"footer1.xml\"/></Relationships>"

            func build(_ name: String, withFooter: Bool) -> String? {
                var parts = [
                    "word/document.xml": document(
                        withFooter
                            ? "<w:footerReference w:type=\"default\" r:id=\"rId3\"/>" : ""),
                ]
                if withFooter {
                    parts["word/footer1.xml"] = footer
                    parts["word/_rels/document.xml.rels"] = rels
                }
                guard let data = Self.minimalZip(parts) else { return nil }
                let path = (folder as NSString).appendingPathComponent(name)
                try? data.write(to: URL(fileURLWithPath: path))
                return path
            }

            // Dải phải nằm TRỌN trong băng lề dưới, không được chạm vùng chữ.
            //
            // Lề dưới 1440 twip = 72 pt trên tờ A4 cao 842 pt, tức 8,5% cuối. Bản đầu lấy 10% và
            // đối chứng âm đỏ ngay: dải liếm vào 12 pt cuối của vùng chữ, nên "băng lề" của một
            // tài liệu KHÔNG có chân trang vẫn có mực. Lấy 6% và chừa mép giấy.
            let band = CGRect(x: 0, y: 0.925, width: 1, height: 0.06)

            func inkInFooterBand(_ path: String) -> Double? {
                controller.resetWindowForSelfTest()
                controller.open(path: path, line: nil, column: nil, readOnly: false)
                controller.documentToolbar.clickForSelfTest(view: true)
                guard controller.isOfficePreviewVisible else { return nil }
                let pages = controller.officePreview.pages
                pages.layoutNowForSelfTest()
                guard pages.pageCountForSelfTest > 1 else { return nil }
                return pages.inkForSelfTest(page: 1, band: band)
            }

            guard let withPath = build("co-chan.docx", withFooter: true),
                  let withoutPath = build("khong-chan.docx", withFooter: false)
            else { return "không dựng được .docx thử" }

            guard let bare = inkInFooterBand(withoutPath) else {
                return "không mở được bản KHÔNG chân trang"
            }
            controller.hideAllViewModes()
            guard let dressed = inkInFooterBand(withPath) else {
                return "không mở được bản CÓ chân trang"
            }

            // ĐỐI CHỨNG ÂM trước: không có chân trang thì băng lề phải sạch. Không có vế này thì
            // một phép đo trả về "có mực" vì bóng đổ hay vì mép giấy vẫn xanh.
            //
            // Ngưỡng ở đây NHỎ hơn ngưỡng của cả trang hai bậc, và có lý do đo được: một dòng
            // «— 2 —» chiếm 1711 điểm ảnh trong một băng lề 2 triệu điểm — 0,85‰. Dùng lại
            // ngưỡng 2‰ của cả trang thì bài kiểm báo "chân trang trắng" trong khi nó vẽ đúng.
            guard bare < 0.0001 else {
                return "tài liệu KHÔNG có chân trang mà băng lề dưới vẫn "
                    + "\(String(format: "%.2f", bare * 1000))‰ mực"
            }
            guard dressed > 0.0003 else {
                return "có chân trang mà băng lề dưới gần trắng "
                    + "(\(String(format: "%.2f", dressed * 1000))‰)"
            }

            // Và con số phải là SỐ TRANG thật, không phải một chỗ trống.
            guard let hit = controller.searchPagesForSelfTest("Dòng 1 của phần thân") else {
                return "không tìm được chữ trong tài liệu vừa dựng"
            }
            _ = hit
            let model = try? DOCXLayout.read(path: withPath)
            guard model?.footer.first?.inlines.contains(.pageNumber) == true else {
                return "chân trang đọc ra không mang trường PAGE"
            }
            controller.hideAllViewModes()
            return nil
        },

        // Tìm chữ TRONG TRANG — một cuốn 383 trang không tìm được thì đọc bằng gì.
        //
        // Panel Tìm chung không dùng lại được: nó tìm trong buffer và tô kết quả lên vùng soạn
        // thảo, thứ đang bị khung trang che kín. Người dùng gõ vào đó và không thấy gì xảy ra.
        Case(name: "Trang tài liệu: ⌘F tìm trong trang, nhảy đúng trang, và đếm được chỗ khớp") { controller in
            let folder = NSTemporaryDirectory() + "tim-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            // Chữ cần tìm nằm ở CUỐI, để phép nhảy trang phải làm việc thật.
            var body = (1 ... 300).map {
                "<w:p><w:r><w:rPr><w:sz w:val=\"24\"/></w:rPr><w:t>Dòng \($0) chỉ là chữ đệm "
                    + "cho đủ dài để tài liệu này phải cắt ra nhiều trang.</w:t></w:r></w:p>"
            }.joined()
            body += "<w:p><w:r><w:t>Vương quốc Số nằm ở cuối sách</w:t></w:r></w:p>"
            guard let docx = Self.minimalZip([
                "word/document.xml": "<?xml version=\"1.0\"?><w:document "
                    + "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                    + "<w:body>" + body + "</w:body></w:document>",
            ]) else { return "không dựng được .docx thử" }
            let path = (folder as NSString).appendingPathComponent("tim.docx")
            try? docx.write(to: URL(fileURLWithPath: path))

            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.documentToolbar.clickForSelfTest(view: true)
            guard controller.isOfficePreviewVisible else { return "không mở được khung trang" }
            controller.officePreview.pages.layoutNowForSelfTest()
            let total = controller.officePreview.pages.pageCountForSelfTest
            guard total > 2 else { return "chỉ ra \(total) trang, chưa đủ để kiểm phép nhảy" }

            // ⌘F khi đang xem trang phải đưa con nháy vào ô tìm CỦA TRANG.
            controller.showFindPanel(nil)
            guard controller.window?.firstResponder !== controller.editorView.textView else {
                return "⌘F trong chế độ trang vẫn đưa con nháy về vùng soạn thảo"
            }

            // Không dấu, không hoa thường: gõ "vuong quoc" phải ra "Vương quốc".
            guard let hit = controller.searchPagesForSelfTest("vuong quoc so") else {
                return "không tìm thấy chữ có thật trong tài liệu"
            }
            guard hit.total == 1 else { return "đếm ra \(hit.total) chỗ khớp, phải là 1" }
            guard hit.page >= total - 2 else {
                return "chữ ở cuối sách mà báo trang \(hit.page + 1)/\(total)"
            }

            // Chữ không có thì nói KHÔNG CÓ, và không nhảy đi đâu cả.
            guard controller.searchPagesForSelfTest("mot chuoi khong he ton tai") == nil else {
                return "tìm ra một chuỗi không hề có trong tài liệu"
            }
            controller.hideAllViewModes()
            return nil
        },

        // Excel KHÔNG đi vào bản dựng trang, và đó là chủ ý.
        //
        // Một bảng tính không có "khổ giấy" cho tới lúc in, còn thứ người ta mở `.xlsx` để làm
        // là đọc số THEO Ô. Lưới ô làm việc ấy tốt hơn mọi ảnh chụp trang, và nó vốn đã chiếm
        // hết bề ngang cửa sổ. Bài này canh để không ai "thống nhất" nó vào cùng một đường rồi
        // làm mất bảng sửa được.
        Case(name: "Excel: View là BẢNG TÍNH sửa được, không phải trang dựng ra") { controller in
            let folder = NSTemporaryDirectory() + "xlsx-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            guard let xlsx = Self.minimalZip([
                "xl/workbook.xml": "<?xml version=\"1.0\"?><workbook "
                    + "xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" "
                    + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
                    + "<sheets><sheet name=\"Bang1\" sheetId=\"1\" r:id=\"rId1\"/></sheets>"
                    + "</workbook>",
                "xl/_rels/workbook.xml.rels": "<?xml version=\"1.0\"?><Relationships "
                    + "xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                    + "<Relationship Id=\"rId1\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
                "xl/worksheets/sheet1.xml": "<?xml version=\"1.0\"?><worksheet "
                    + "xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
                    + "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Tỉnh</t>"
                    + "</is></c><c r=\"B1\" t=\"inlineStr\"><is><t>Số</t></is></c></row>"
                    + "<row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>Huế</t></is></c>"
                    + "<c r=\"B2\" t=\"inlineStr\"><is><t>42</t></is></c></row>"
                    + "<row r=\"3\"><c r=\"A3\" t=\"inlineStr\"><is><t>Đà Nẵng</t></is></c>"
                    + "<c r=\"B3\" t=\"inlineStr\"><is><t>7</t></is></c></row>"
                    + "</sheetData></worksheet>",
            ]) else { return "không dựng được .xlsx thử" }
            let path = (folder as NSString).appendingPathComponent("so-lieu.xlsx")
            try? xlsx.write(to: URL(fileURLWithPath: path))

            controller.resetWindowForSelfTest()
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.editorDocument.mediaKind == .excel else {
                return "không nhận ra .xlsx: "
                    + "\(String(describing: controller.editorDocument.mediaKind))"
            }
            // `.xlsx` mở ra là ĐÃ ở bảng rồi — đó là đường mở riêng của Excel. Bấm View lúc ấy
            // là bấm tắt. Bài kiểm hỏi TRẠNG THÁI cuối, không hỏi số lần bấm.
            if !controller.isTableViewVisibleForSelfTest {
                controller.documentToolbar.clickForSelfTest(view: true)
            }
            // Bảng dựng ở lượt vẽ sau: phân tích CSV rồi mới gắn view. Hỏi ngay sau cú bấm là
            // hỏi trước khi câu trả lời tồn tại.
            _ = controller.waitForSelfTestPublic("bảng .xlsx", seconds: 10, until: {
                controller.isTableViewVisibleForSelfTest
            })
            guard !controller.isOfficePreviewVisible else {
                return ".xlsx bị đẩy vào bản dựng trang — mất bảng tính sửa được"
            }
            guard controller.isTableViewVisibleForSelfTest else {
                let flags = controller.viewModeFlagsForSelfTest
                    .map { "\($0.name)=\($0.on)" }.joined(separator: " ")
                return "View của .xlsx không phải bảng tính — đang hiện: \(flags)"
            }
            // Và công tắc phải NÓI rằng đang ở View — nếu không thì người dùng thấy bảng mà
            // khung chung bảo họ đang ở Code.
            guard controller.documentToolbar.selectedIsViewForSelfTest else {
                return "bảng tính đang hiện mà công tắc vẫn chỉ Code"
            }
            controller.hideAllViewModes()
            return nil
        },

        // Chế độ View/Code phải THẤY ĐƯỢC trên giao diện, không chỉ nằm trong menu.
        //
        // Lỗi này do người dùng báo, và nó là loại tệ nhất: tính năng chạy đúng, có phím tắt,
        // có mục menu — nhưng mở một tệp JSON lên thì trên màn hình không có gì nói rằng có một
        // cây khoá–giá trị đang chờ. Người lỡ bấm ⌥⌘V cũng không thấy đường quay lại. Với người
        // dùng, một tính năng không tìm ra được thì không tồn tại.
        //
        // Bài này giữ cả BA vế: nhãn nói đúng chế độ đang bật · tệp chỉ có một chế độ thì mục
        // ấy TẮT kèm lý do · và bấm vào nó thì đổi chế độ thật.
        Case(name: "thanh trạng thái: mục View/Code nói đúng chế độ, và bấm được") { controller in
            let json = "{\n  \"ten\": \"An\",\n  \"tuoi\": 30\n}\n"
            let folder = NSTemporaryDirectory() + "viewcode-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("cong-ty.json")
            try? Data(json.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            // ── Đang ở Code: nhãn phải mời sang View, và phải BẤM ĐƯỢC.
            var label = controller.statusBar.viewCodeForSelfTest
            guard label.title.contains("Code"), label.title.contains("View") else {
                return "mục View/Code không hiện đủ hai chế độ: «\(label.title)»"
            }
            guard label.enabled else { return "tệp JSON mà mục View/Code bị tắt" }
            guard label.active.contains("Code") else {
                return "vừa mở tệp JSON mà nhãn nói «\(label.active)» — khung đang bật: "
                    + (controller.viewModeFlagsForSelfTest.filter(\.on).map(\.name)
                        .joined(separator: ", ").isEmpty
                        ? "không khung nào"
                        : controller.viewModeFlagsForSelfTest.filter(\.on).map(\.name)
                            .joined(separator: ", "))
            }
            guard label.tooltip.contains("⌥⌘V") else {
                return "tooltip không nói phím tắt: «\(label.tooltip)»"
            }

            // ── Bấm THẬT vào mục ấy — không gọi tắt `toggleViewCode`.
            controller.statusBar.clickSegmentForSelfTest(.viewCode)
            guard controller.isStructureTreeVisible else {
                return "bấm mục View/Code trên thanh trạng thái mà cây không hiện"
            }
            label = controller.statusBar.viewCodeForSelfTest
            guard label.active.contains("View") else {
                return "đang ở chế độ View mà nhãn nói «\(label.active)» — một chỉ dẫn nói sai "
                    + "còn tệ hơn không có chỉ dẫn"
            }

            // ── Bấm lần nữa thì về Code, và nhãn theo kịp.
            controller.statusBar.clickSegmentForSelfTest(.viewCode)
            guard !controller.isStructureTreeVisible else { return "bấm lần hai không tắt cây" }
            guard controller.statusBar.viewCodeForSelfTest.active.contains("Code") else {
                return "về Code mà nhãn chưa đổi lại"
            }

            // ── Tệp chỉ có MỘT chế độ: mục ấy tắt, và nói ra lý do.
            let swiftPath = (folder as NSString).appendingPathComponent("thu.swift")
            try? Data("let x = 1\n".utf8).write(to: URL(fileURLWithPath: swiftPath))
            controller.open(path: swiftPath, line: nil, column: nil, readOnly: false)
            label = controller.statusBar.viewCodeForSelfTest
            guard !label.enabled else {
                return "tệp mã nguồn mà mục View/Code vẫn bấm được"
            }
            guard !label.title.contains("View") else {
                return "tệp một chế độ mà nhãn «\(label.title)» vẫn mời sang View"
            }
            guard label.tooltip.contains("một chế độ") else {
                return "không nói ra vì sao tắt: «\(label.tooltip)»"
            }
            return nil
        },

        // Chiều NGƯỢC của phép nhảy về nguồn: bật View thì cây phải mở sẵn ở chỗ con nháy đang
        // đứng. Bài này đòi ba vế cùng lúc, vì thiếu vế nào thì tính năng cũng vô dụng:
        //
        //   1. nút đúng được CHỌN (không phải chỉ dựng cây rồi để đấy),
        //   2. cây mở SÂU HƠN hai tầng mặc định để nút ấy có hàng,
        //   3. bật View KHÔNG làm con nháy nhúc nhích — View chỉ là một cách nhìn.
        //
        // Nút đích cố ý đặt ở tầng ba: tầng một và hai đã mở sẵn cho mọi tệp, nên một bài kiểm
        // đặt đích ở đó sẽ xanh kể cả khi `reveal` không làm gì cả.
        Case(name: "cây JSON: bật View thì mở sẵn ở chỗ con nháy, sâu hơn hai tầng mặc định") { controller in
            let json = """
                {
                  "cong_ty": {
                    "chi_nhanh": {
                      "hue": {"truong_phong": "Nguyễn Văn An"},
                      "da_nang": {"truong_phong": "Trần Thị Bình"}
                    }
                  }
                }
                """
            let path = NSTemporaryDirectory() + "cay-theo-nhay-\(UUID().uuidString).json"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(json.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            // Đặt con nháy giữa tên «Trần Thị Bình» — sâu tầng năm, và ở nhánh THỨ HAI để một
            // hiện thực chọn bừa nhánh đầu không lọt.
            let caret = Array(json.utf8).count
                - Array(json[json.range(of: "Trần Thị Bình")!.lowerBound...].utf8).count
            controller.setCaretForSelfTest(documentOffset: caret)

            controller.toggleViewCode(nil)
            // Trả cây về trạng thái tắt ở MỌI đường thoát, kể cả đường thoát vì đỏ. Không có vế
            // này thì một bài đỏ để lại cây đang hiện, bài kế bấm ⌥⌘V là TẮT nó đi, và bài kế ấy
            // cũng đỏ theo — đọc log sẽ thấy hai lỗi trong khi chỉ có một.
            defer { if controller.isStructureTreeVisible { controller.toggleViewCode(nil) } }
            guard controller.isStructureTreeVisible else {
                return "cây không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            let tree = controller.structureTree
            let row = tree.selectedRowForSelfTest
            guard row >= 0 else {
                return "cây mở ra mà không chọn nút nào — con nháy ở byte \(caret) bị bỏ quên"
            }
            let label = tree.labelForSelfTest(row: row)
            guard label == "truong_phong" else {
                return "chọn nhầm nút «\(label)», mong «truong_phong»"
            }
            // Nút ấy nằm ở tầng bốn, tức phải mở thêm hai tầng nữa mới có hàng để chọn.
            guard tree.rowCountForSelfTest > 4 else {
                return "chỉ \(tree.rowCountForSelfTest) hàng — cây chưa mở sâu tới nút được chọn"
            }
            // Đúng nhánh «da_nang»: hàng ngay trên nó phải là nhánh ấy, không phải «hue».
            let above = tree.labelForSelfTest(row: row - 1)
            guard above == "da_nang" else {
                return "nút được chọn nằm dưới «\(above)» — mong nhánh «da_nang»"
            }
            // Bật View không được dời con nháy: nếu tắt View đi mà chỗ đứng đã khác thì lệnh này
            // không còn là một cách NHÌN nữa, nó thành một lệnh sửa vị trí.
            guard controller.caretOffsetForSelfTest == caret else {
                return "bật View làm con nháy dời từ \(caret) sang "
                    + "\(controller.caretOffsetForSelfTest)"
            }
            return nil
        },

        // Ô lọc trong cây. Bốn vế, và vế cuối là vế dễ hỏng nhất: sau khi lọc, một cú bấm phải
        // vẫn rơi vào ĐÚNG nút — phép lọc đổi các HÀNG trên màn hình, nên nếu chỗ nào đó neo
        // theo số hàng thay vì theo nút thì con nháy sẽ nhảy sang chỗ khác mà không ai thấy sai.
        Case(name: "cây: lọc theo tên và theo giá trị, gõ KHÔNG DẤU cũng ra, bấm vẫn đúng nút") { controller in
            let json = """
                {
                  "khach": {"ten": "An", "tinh": "Huế"},
                  "kho": {"ten": "Kho A", "tinh": "Đà Nẵng"},
                  "tong": 1200000
                }
                """
            let path = NSTemporaryDirectory() + "cay-loc-\(UUID().uuidString).json"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(json.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.setCaretForSelfTest(documentOffset: 0)

            controller.toggleViewCode(nil)
            defer { if controller.isStructureTreeVisible { controller.toggleViewCode(nil) } }
            guard controller.isStructureTreeVisible else {
                return "cây không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            let tree = controller.structureTree

            // ── Lọc theo NHÃN: giữ nút khớp và tổ tiên của nó, bỏ phần còn lại.
            tree.setFilterForSelfTest("tinh")
            var labels = tree.visibleLabelsForSelfTest
            guard labels.filter({ $0 == "tinh" }).count == 2 else {
                return "lọc «tinh» ra \(labels)"
            }
            guard labels.contains("khach"), labels.contains("kho") else {
                return "lọc xong mất TỔ TIÊN — không còn biết nút khớp nằm ở nhánh nào: \(labels)"
            }
            guard !labels.contains("tong"), !labels.contains("ten") else {
                return "lọc xong vẫn còn nút không khớp: \(labels)"
            }

            // ── Lọc theo GIÁ TRỊ, gõ KHÔNG DẤU: «da nang» phải ra «Đà Nẵng».
            tree.setFilterForSelfTest("da nang")
            labels = tree.visibleLabelsForSelfTest
            guard labels == ["$", "kho", "tinh"] else {
                return "lọc không dấu theo giá trị ra \(labels), mong [$, kho, tinh]"
            }

            // ── Bấm nút còn lại sau khi lọc: phải nhảy đúng byte của «Đà Nẵng», không phải của
            // nút cùng tên ở nhánh kia.
            guard let row = labels.firstIndex(of: "tinh") else { return "mất hàng «tinh»" }
            tree.clickRowForSelfTest(row)
            let expected = Array(json.utf8).count
                - Array(json[json.range(of: "\"Đà Nẵng\"")!.lowerBound...].utf8).count
            guard controller.caretOffsetForSelfTest == expected else {
                return "bấm trong cây đã lọc rơi vào byte \(controller.caretOffsetForSelfTest), "
                    + "mong \(expected)"
            }

            // ── Không khớp gì thì NÓI RA, và bỏ lọc thì cây trở lại đầy đủ.
            controller.toggleViewCode(nil)
            guard controller.isStructureTreeVisible else { return "bật lại cây không được" }
            tree.setFilterForSelfTest("không-có-chuỗi-này")
            guard tree.visibleLabelsForSelfTest.isEmpty else {
                return "lọc không khớp mà vẫn còn hàng: \(tree.visibleLabelsForSelfTest)"
            }
            guard tree.headerForSelfTest == L("Không có kết quả") else {
                return "lọc không khớp mà đầu khung nói «\(tree.headerForSelfTest)»"
            }
            tree.setFilterForSelfTest("")
            guard tree.visibleLabelsForSelfTest.contains("tong") else {
                return "bỏ lọc mà cây chưa trở lại đầy đủ: \(tree.visibleLabelsForSelfTest)"
            }
            return nil
        },

        // ⌘C trên cây chép ĐƯỜNG DẪN của nút đang chọn.
        //
        // Vế đắt nhất không phải "có chép không" mà là **đường dẫn ấy có CHẠY được không**: bài
        // đem chuỗi vừa chép chạy qua chính bộ JSONPath của sản phẩm và đòi nó trỏ về đúng
        // khoảng byte của nút. Một bài chỉ so chuỗi sẽ xanh với mọi cú pháp bịa ra.
        Case(name: "cây: ⌘C chép đường dẫn, và đường dẫn ấy chạy được qua chính bộ JSONPath") { controller in
            let json = """
                {
                  "khach": {"tên": "An", "diem": [9, 8, 10]},
                  "tong": 1200000
                }
                """
            let path = NSTemporaryDirectory() + "cay-chep-\(UUID().uuidString).json"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(json.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.setCaretForSelfTest(documentOffset: 0)

            controller.toggleViewCode(nil)
            defer { if controller.isStructureTreeVisible { controller.toggleViewCode(nil) } }
            guard controller.isStructureTreeVisible else {
                return "cây không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            let tree = controller.structureTree

            // Chọn nút «tên» — khoá có dấu, tức đường dẫn phải bọc ngoặc mới dán lại được.
            tree.setFilterForSelfTest("tên")
            guard let row = tree.visibleLabelsForSelfTest.firstIndex(of: "tên") else {
                return "không thấy hàng «tên»: \(tree.visibleLabelsForSelfTest)"
            }
            tree.selectRowForSelfTest(row)

            NSPasteboard.general.clearContents()
            controller.copySelection(nil)
            guard let copied = NSPasteboard.general.string(forType: .string) else {
                return "⌘C trên cây không chép gì cả"
            }
            guard copied.hasPrefix("$") else {
                return "⌘C chép «\(copied)» — đó không phải đường dẫn; nhiều khả năng nó vừa "
                    + "chép vùng chọn của trình soạn thảo đang bị che"
            }

            // Chạy THẬT qua bộ truy vấn: đường dẫn phải trỏ về đúng khoảng byte của nút.
            let bytes = Array(json.utf8)
            let matches: [JSONPath.Match]
            do {
                matches = try JSONPath.run(copied, on: JSONIndex(bytes: bytes), bytes: bytes)
            } catch {
                return "đường dẫn «\(copied)» không chạy được: \(error)"
            }
            guard matches.count == 1 else {
                return "đường dẫn «\(copied)» khớp \(matches.count) nút, mong đúng 1"
            }
            let expected = Array(json.utf8).count
                - Array(json[json.range(of: "\"An\"")!.lowerBound...].utf8).count
            guard matches[0].range.lowerBound == expected else {
                return "đường dẫn «\(copied)» trỏ vào byte \(matches[0].range.lowerBound), "
                    + "mong \(expected)"
            }
            return nil
        },

        // Cây chỉ dùng được bằng CHUỘT thì nó chưa phải một chế độ xem, nó là một bức tranh.
        // Hai phím kết thúc một lượt xem phải làm hai việc KHÁC NHAU, và chỗ dễ sai là ở Esc:
        // nếu nó cũng dời con nháy như Enter thì người dùng mất chỗ đứng chỉ vì đã nhìn.
        Case(name: "cây: Enter nhảy về nguồn, Esc trả về Code mà không dời con nháy") { controller in
            let json = """
                {
                  "ten": "An",
                  "dia_chi": {"tinh": "Huế"}
                }
                """
            let path = NSTemporaryDirectory() + "cay-phim-\(UUID().uuidString).json"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(json.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            // Con nháy đặt GIỮA một giá trị, không ở byte 0 và không ở đầu nút.
            //
            // Chỗ đứng này là cả sức nặng của bài: bản đầu đặt nó ở byte 0, và một nhát bẻ cho
            // Esc chạy đúng đường của Enter vẫn ĐẬU — vì nút được chọn lúc ấy cũng bắt đầu ở
            // byte 0, nên hai hành vi khác hẳn nhau cho ra cùng một con số.
            let inside = Array(json.utf8).count
                - Array(json[json.range(of: "\"Huế\"")!.lowerBound...].utf8).count + 2
            controller.setCaretForSelfTest(documentOffset: inside)

            // ── Esc: xem xong, không đi đâu cả.
            controller.toggleViewCode(nil)
            guard controller.isStructureTreeVisible else {
                return "cây không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            controller.structureTree.pressEscapeForSelfTest()
            guard !controller.isStructureTreeVisible else { return "Esc không đóng cây" }
            guard controller.caretOffsetForSelfTest == inside else {
                return "Esc dời con nháy từ \(inside) sang "
                    + "\(controller.caretOffsetForSelfTest) — đường lui phải trả về chỗ cũ"
            }

            // ── Enter: đi tới đúng nút đang chọn, y như một cú bấm chuột.
            controller.toggleViewCode(nil)
            defer { if controller.isStructureTreeVisible { controller.toggleViewCode(nil) } }
            guard controller.isStructureTreeVisible else { return "bật lại cây không được" }
            let tree = controller.structureTree
            var row = -1
            for index in 0 ..< tree.rowCountForSelfTest
            where tree.labelForSelfTest(row: index) == "tinh" { row = index; break }
            guard row >= 0 else { return "không thấy hàng «tinh» trong cây" }
            tree.selectRowForSelfTest(row)
            tree.pressReturnForSelfTest()

            guard !controller.isStructureTreeVisible else {
                return "Enter không quay về chế độ Code"
            }
            let expected = Array(json.utf8).count
                - Array(json[json.range(of: "\"Huế\"")!.lowerBound...].utf8).count
            guard controller.caretOffsetForSelfTest == expected else {
                return "Enter đưa con nháy tới byte \(controller.caretOffsetForSelfTest), "
                    + "mong \(expected)"
            }
            return nil
        },

        // Cây XML đi qua ĐÚNG lệnh ⌥⌘V, và phải chọn đúng bộ dựng theo ngôn ngữ — không phải
        // theo đuôi tệp. Bài này cũng giữ vế "thuộc tính mang tiền tố @".
        Case(name: "cây XML: chọn đúng bộ dựng, thuộc tính có @, nhảy đúng byte") { controller in
            let xml = """
                <don_hang ma="DH-01">
                  <khach tinh="Huế">Nguyễn Văn An</khach>
                  <tong>1200000</tong>
                </don_hang>
                """
            let path = NSTemporaryDirectory() + "cay-\(UUID().uuidString).xml"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(xml.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            controller.toggleViewCode(nil)
            guard controller.isStructureTreeVisible else {
                return "cây XML không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            let tree = controller.structureTree
            // Gốc + ba con của gốc phải thấy ngay ở hai tầng mở sẵn.
            var nhan: [String] = []
            for row in 0 ..< tree.rowCountForSelfTest {
                nhan.append(tree.labelForSelfTest(row: row))
            }
            guard nhan.first == "don_hang" else { return "gốc sai: \(nhan)" }
            guard nhan.contains("@ma") else {
                return "thuộc tính không mang tiền tố @ — \(nhan)"
            }
            guard nhan.contains("khach"), nhan.contains("tong") else {
                return "thiếu thẻ con — \(nhan)"
            }

            // Bấm thẻ `tong` thì con nháy phải rơi vào đúng `<tong>` trong nguồn.
            guard let row = nhan.firstIndex(of: "tong") else { return "không thấy hàng «tong»" }
            tree.clickRowForSelfTest(row)
            let expected = Array(xml.utf8).count
                - Array(xml[xml.range(of: "<tong>")!.lowerBound...].utf8).count
            guard controller.caretOffsetForSelfTest == expected else {
                return "con nháy ở byte \(controller.caretOffsetForSelfTest), mong \(expected)"
            }
            return nil
        },

        // Cây YAML đi qua đúng lệnh ⌥⌘V. Giữ luôn hai vế riêng của YAML: dãy nằm NGANG cột với
        // khoá của nó, và nút trỏ vào đầu KHOÁ chứ không vào giá trị.
        Case(name: "cây YAML: dãy ngang cột vẫn treo đúng khoá, nhảy về đầu khoá") { controller in
            let yaml = """
                máy_chủ:
                  tên: web-01
                cổng:
                - 80
                - 443
                """
            let path = NSTemporaryDirectory() + "cay-\(UUID().uuidString).yaml"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(yaml.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            controller.toggleViewCode(nil)
            guard controller.isStructureTreeVisible else {
                return "cây YAML không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            let tree = controller.structureTree
            var nhan: [String] = []
            for row in 0 ..< tree.rowCountForSelfTest { nhan.append(tree.labelForSelfTest(row: row)) }
            guard nhan.first == "$" else { return "gốc sai: \(nhan)" }
            guard nhan.contains("máy_chủ"), nhan.contains("cổng") else {
                return "thiếu khoá cấp một — \(nhan)"
            }

            // Bấm CẢ HAI loại nút. Khoảng byte của nút chứa do lúc đóng khối ghi, còn của nút lá
            // do lúc đọc giá trị ghi — hai đường khác hẳn nhau, thử một cái không nói gì về cái
            // kia. Bài đầu chỉ bấm nút chứa, và một nhát bẻ vào đường của lá đã đi lọt.
            func byteOf(_ needle: String) -> Int {
                Array(yaml.utf8).count - Array(yaml[yaml.range(of: needle)!.lowerBound...].utf8).count
            }
            for (nhãn, mốc) in [("cổng", "cổng:"), ("tên", "tên: web-01")] {
                if !controller.isStructureTreeVisible { controller.toggleViewCode(nil) }
                let tree = controller.structureTree
                var hàng = -1
                for row in 0 ..< tree.rowCountForSelfTest
                where tree.labelForSelfTest(row: row) == nhãn { hàng = row; break }
                guard hàng >= 0 else { return "không thấy hàng «\(nhãn)»" }
                tree.clickRowForSelfTest(hàng)
                guard controller.caretOffsetForSelfTest == byteOf(mốc) else {
                    return "«\(nhãn)»: con nháy ở byte \(controller.caretOffsetForSelfTest), "
                        + "mong \(byteOf(mốc))"
                }
            }
            return nil
        },

        // Dàn ý PowerPoint đi qua ĐÚNG lệnh ⌥⌘V, trên một bản trình chiếu THẬT.
        // Cùng một chế độ View, nhưng trên một tệp `.pptx` DỰNG TẠI CHỖ.
        //
        // Bài dưới đây đọc tệp thật trong kho, và vì thế nó BỊ BỎ QUA trong bundle App Store:
        // sandbox không cho với ra ngoài vùng chứa. Nghĩa là chế độ View của PowerPoint chưa
        // từng được kiểm trong đúng cấu hình mà người dùng chạy — và bundle sandbox chính là
        // chỗ đã giấu hai lỗi chặn phát hành hồi 31/08.
        //
        // Tệp dựng tại chỗ nằm ở thư mục tạm, nơi sandbox GHI VÀ ĐỌC được, nên bài này chạy ở
        // mọi cấu hình. Nó không thay bài kia: bài kia kiểm tệp PowerPoint THẬT do một hiện
        // thực khác ghi ra, còn bài này kiểm đường đi trong sandbox. Hai câu hỏi khác nhau.
        Case(name: "dàn ý PowerPoint: chạy được cả trong sandbox, trên .pptx dựng tại chỗ") {
            controller in
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("pptx-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let path = (folder as NSString).appendingPathComponent("thu.pptx")

            func slide(_ lines: [String]) -> String {
                let body = lines.map {
                    "<a:p><a:r><a:t>\($0)</a:t></a:r></a:p>"
                }.joined()
                return "<?xml version=\"1.0\"?><p:sld xmlns:p=\"p\" xmlns:a=\"a\">"
                    + "<p:cSld><p:spTree>\(body)</p:spTree></p:cSld></p:sld>"
            }
            guard let zip = Self.minimalZip([
                // `presentation.xml` phải có mặt, nếu không `PPTXReader` từ chối ngay.
                "ppt/presentation.xml": "<?xml version=\"1.0\"?><p:presentation xmlns:p=\"p\"/>",
                "ppt/slides/slide1.xml": slide(["Mở đầu", "Bối cảnh", "Mục tiêu"]),
                "ppt/slides/slide2.xml": slide(["Kết quả", "Doanh thu tăng"]),
            ]) else { return "không dựng được .pptx thử" }
            try? zip.write(to: URL(fileURLWithPath: path))

            controller.open(path: path, line: nil, column: nil, readOnly: false)
            let markdown = controller.editorDocument.buffer.text
            // Tiêu đề slide mang SỐ THỨ TỰ («## 2. Kết quả») — đó là tiền tố do `PPTXReader`
            // sinh, và nhãn trong cây là phần sau «## ».
            guard markdown.contains("## 1. Mở đầu") else {
                return "mở .pptx ra không phải dàn ý: «\(markdown.prefix(60))»"
            }

            // ⌥⌘V nay mở TRANG SLIDE (QuickLook); dàn ý là cách nhìn thứ hai, nằm ở nút
            // «Dàn ý» trên khung chung. Bài kiểm đi qua đúng lối mà người dùng đi.
            controller.toggleOutlineTree(nil)
            defer { if controller.isStructureTreeVisible { controller.toggleOutlineTree(nil) } }
            guard controller.isStructureTreeVisible else {
                return "dàn ý không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            let tree = controller.structureTree
            let nhan = tree.visibleLabelsForSelfTest
            guard nhan.contains("1. Mở đầu"), nhan.contains("2. Kết quả") else {
                return "thiếu slide trong dàn ý: \(nhan)"
            }
            guard nhan.contains("Bối cảnh") else { return "thiếu gạch đầu dòng: \(nhan)" }

            // Bấm slide thứ hai thì con nháy rơi đúng dòng `## Kết quả`.
            guard let row = nhan.firstIndex(of: "2. Kết quả") else {
                return "không thấy hàng slide 2: \(nhan)"
            }
            tree.clickRowForSelfTest(row)
            let expected = Array(markdown.utf8).count
                - Array(markdown[markdown.range(of: "## 2. Kết quả")!.lowerBound...].utf8).count
            guard controller.caretOffsetForSelfTest == expected else {
                return "con nháy ở byte \(controller.caretOffsetForSelfTest), mong \(expected)"
            }
            return nil
        },

        Case(name: "dàn ý PowerPoint: mỗi slide một nút, bấm là nhảy đúng dòng dàn ý",
             skipWhen: { _ in Self.fixtureUnreadable("data/vanban/ngon-ngu/bao-cao-quy.pptx") }
        ) { controller in
            controller.open(path: Self.repoFile("data/vanban/ngon-ngu/bao-cao-quy.pptx"),
                            line: nil, column: nil, readOnly: false)
            let markdown = controller.editorDocument.buffer.text
            guard markdown.contains("## ") else { return "mở ra không phải dàn ý: \(markdown.prefix(80))" }

            controller.toggleOutlineTree(nil)
            guard controller.isStructureTreeVisible else {
                return "dàn ý không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            let tree = controller.structureTree
            var nhan: [String] = []
            for row in 0 ..< tree.rowCountForSelfTest { nhan.append(tree.labelForSelfTest(row: row)) }
            guard let dau = nhan.first, !dau.hasPrefix("## ") else {
                return "nhãn slide còn nguyên tiền tố Markdown: «\(nhan.first ?? "")»"
            }
            guard nhan.count >= 2 else { return "dàn ý chỉ có \(nhan.count) hàng" }

            // Bấm slide đầu thì con nháy phải rơi vào đúng dòng `## ` đầu tiên của dàn ý.
            tree.clickRowForSelfTest(0)
            let expected = Array(markdown.utf8).count
                - Array(markdown[markdown.range(of: "## ")!.lowerBound...].utf8).count
            guard controller.caretOffsetForSelfTest == expected else {
                return "con nháy ở byte \(controller.caretOffsetForSelfTest), mong \(expected)"
            }
            return nil
        },

        // Sơ đồ trong tab. Vế đắt nhất không phải "có vẽ không" mà là: bộ vẽ chỉ có MỘT
        // `WKWebView`, nên hai khung sơ đồ không bao giờ được hiện cùng lúc — cái thua sẽ trống
        // trơn mà không báo gì.
        Case(name: "sơ đồ trong tab: vẽ ra, và không tranh khung với bảng Mermaid Studio",
             skipWhen: { _ in
                 MermaidAsset.isAvailable ? nil : "máy này không có tệp vendor mermaid"
             }
        ) { controller in
            let path = NSTemporaryDirectory() + "so-do-\(UUID().uuidString).mmd"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data("graph TD\n  A[Đầu vào] --> B[Xử lý]\n  B --> C[Kết quả]\n".utf8)
                .write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            guard !controller.isDiagramTabVisible else { return "sơ đồ hiện sẵn khi chưa bấm gì" }
            controller.toggleViewCode(nil)
            guard controller.isDiagramTabVisible else {
                return "bấm đổi chế độ trên .mmd mà sơ đồ không hiện: "
                    + "«\(controller.lastTransientForSelfTest)»"
            }
            // Chờ ĐÚNG thứ cần quan sát, không chờ bộ đếm lượt vẽ. Bộ đếm cộng dồn cả phiên tự
            // kiểm và bộ vẽ có hàng đợi, nên "đếm tăng thêm một" có thể là lượt của bài khác vừa
            // xong — phép chờ đậu trong khi sơ đồ của bài này còn đang vẽ dở.
            guard controller.waitForSelfTestPublic("sơ đồ trong tab", seconds: 30, until: {
                !controller.diagramTab.headerTextForSelfTest.isEmpty
            }) else { return "chờ mãi mà khung sơ đồ trong tab vẫn không nói gì" }
            guard controller.diagramTab.headerTextForSelfTest.contains("sơ đồ") else {
                return "khung sơ đồ nói lạ: «\(controller.diagramTab.headerTextForSelfTest)»"
            }

            // Bật bảng bên cạnh thì tab phải nhường, không thì hai khung tranh một view.
            controller.toggleMermaidStudioForSelfTest()
            guard !controller.isDiagramTabVisible else {
                return "mở Mermaid Studio mà sơ đồ trong tab vẫn còn — hai khung tranh một view"
            }
            guard controller.isMermaidPanelVisible else { return "Mermaid Studio không mở" }

            // Và ngược lại.
            controller.toggleViewCode(nil)
            guard controller.isDiagramTabVisible, !controller.isMermaidPanelVisible else {
                return "quay lại tab mà bảng bên cạnh vẫn còn"
            }
            controller.toggleViewCode(nil)
            guard !controller.isDiagramTabVisible else { return "bấm lần nữa mà sơ đồ không tắt" }
            return nil
        },

        // Chiều Code → View của sơ đồ, đối xứng với "cây mở ra ở chỗ con nháy".
        //
        // Ở bảng Mermaid Studio, phép tô sáng bám vào sự kiện DỜI CON NHÁY. Tab thì không có sự
        // kiện ấy — vùng soạn thảo bị che, người dùng không dời con nháy nữa — nên nếu chỉ bám
        // vào đó thì sơ đồ trong tab luôn mở ra không có gì sáng, và View không nói được câu
        // «chỗ anh đang đứng là chỗ này».
        Case(name: "sơ đồ trong tab: mở ra thì phần tử ở dòng con nháy sáng sẵn",
             skipWhen: { _ in
                 MermaidAsset.isAvailable ? nil : "máy này không có tệp vendor mermaid"
             }
        ) { controller in
            let source = "graph TD\n  A[Đầu vào] --> B[Xử lý]\n  B --> C[Kết quả]\n"
            let path = NSTemporaryDirectory() + "so-do-sang-\(UUID().uuidString).mmd"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(source.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            // Con nháy ở dòng khai `C[Kết quả]` — dòng 2, đếm từ 0.
            let caret = controller.editorDocument.buffer.contentRange(ofLine: 2).lowerBound
            controller.setCaretForSelfTest(documentOffset: caret)

            controller.toggleViewCode(nil)
            defer { if controller.isDiagramTabVisible { controller.toggleViewCode(nil) } }
            guard controller.isDiagramTabVisible else {
                return "sơ đồ không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            guard let hits = controller.waitForMermaidHitsForSelfTest(expected: 1) else {
                return "mở tab mà không phần tử nào sáng — chiều Code → View của sơ đồ chưa nối"
            }
            guard hits == 1 else { return "tô sáng \(hits) phần tử, mong 1" }
            // Và phải là ĐÚNG phần tử của dòng ấy. Hỏi TRANG xem cái đang sáng mang chữ gì —
            // đọc danh sách chữ đã GỬI thì không trả lời được câu ấy: nó chứa cả định danh
            // (`B`, `C`) vốn không khớp phần tử nào, vì mermaid vẽ nhãn chứ không vẽ định danh.
            let lit = controller.highlightedTextsForSelfTest()
            guard lit == ["Kết quả"] else {
                return "phần tử đang sáng mang chữ \(lit), mong [Kết quả]"
            }
            return nil
        },

        // Bấm một phần tử trong sơ đồ ĐANG CHIẾM TRỌN TAB.
        //
        // Đường nhảy về nguồn vốn đã có và dùng chung cho cả bảng lẫn tab — nhưng ở tab, vùng
        // soạn thảo đang bị che, nên con nháy dời mà không ai thấy. Cùng luật với cây: bấm một
        // thứ trong View là về Code, vì việc tiếp theo gần như luôn là SỬA chỗ vừa bấm.
        Case(name: "sơ đồ trong tab: bấm một node là về Code, con nháy ở đúng dòng khai node",
             skipWhen: { _ in
                 MermaidAsset.isAvailable ? nil : "máy này không có tệp vendor mermaid"
             }
        ) { controller in
            let source = "graph TD\n  A[Đầu vào] --> B[Xử lý]\n  B --> C[Kết quả]\n"
            let path = NSTemporaryDirectory() + "so-do-bam-\(UUID().uuidString).mmd"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(source.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.setCaretForSelfTest(documentOffset: 0)

            controller.toggleViewCode(nil)
            defer { if controller.isDiagramTabVisible { controller.toggleViewCode(nil) } }
            guard controller.isDiagramTabVisible else {
                return "sơ đồ không hiện: «\(controller.lastTransientForSelfTest)»"
            }
            guard controller.waitForSelfTestPublic("sơ đồ trong tab", seconds: 30, until: {
                !controller.diagramTab.headerTextForSelfTest.isEmpty
            }) else { return "chờ mãi mà khung sơ đồ trong tab vẫn không nói gì" }

            // Bấm THẬT trong trang, không gọi tắt callback.
            var sent: String?
            controller.mermaidRenderer.dispatchClickForSelfTest(on: "Kết quả") { sent = $0 }
            guard controller.waitForSelfTestPublic("gửi cú bấm", seconds: 10, until: {
                sent != nil
            }) else { return "trang không trả lời cú bấm" }
            guard sent == "đã gửi" else { return "không bấm được node «Kết quả»: \(sent ?? "?")" }

            guard controller.waitForSelfTestPublic("về Code", seconds: 10, until: {
                !controller.isDiagramTabVisible
            }) else {
                return "bấm một node mà sơ đồ vẫn chiếm trọn tab — con nháy có dời cũng không "
                    + "ai thấy, vì vùng soạn thảo đang bị che"
            }
            // Dòng 2 (đếm từ 0) là dòng khai `C[Kết quả]`.
            let expected = controller.editorDocument.buffer.contentRange(ofLine: 2).lowerBound
            guard controller.caretOffsetForSelfTest == expected else {
                return "con nháy ở byte \(controller.caretOffsetForSelfTest), mong \(expected) "
                    + "(đầu dòng khai node vừa bấm)"
            }
            return nil
        },

        Case(name: "cây JSON: tệp hỏng cú pháp thì nói ra, không dựng cây cụt") { controller in
            let path = NSTemporaryDirectory() + "hong-\(UUID().uuidString).json"
            defer { try? FileManager.default.removeItem(atPath: path) }
            try? Data(#"{"a":1,"b":}"#.utf8).write(to: URL(fileURLWithPath: path))
            controller.open(path: path, line: nil, column: nil, readOnly: false)

            controller.toggleViewCode(nil)
            guard controller.isStructureTreeVisible else { return "không mở được cây" }
            let tree = controller.structureTree
            guard tree.nodeCountForSelfTest == 0 else {
                return "JSON hỏng mà vẫn dựng \(tree.nodeCountForSelfTest) nút"
            }
            guard tree.headerForSelfTest.contains("Không dựng được cây") else {
                return "không nói vì sao: «\(tree.headerForSelfTest)»"
            }
            controller.toggleViewCode(nil)
            return nil
        },

        // MARK: - Tầng công cụ trang PDF

        // Xoay và hoàn tác. Phép ngược phải trả về ĐÚNG góc cũ, không phải "một góc nào đó" —
        // xoay phải rồi hoàn tác mà ra 270° thì trang in ra vẫn sai.
        Case(name: "PDF: xoay trang, hoàn tác trả về đúng góc cũ") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["MOT", "HAI", "BA"]) else {
                return "không mở được PDF thử"
            }
            guard viewer.rotationForSelfTest(page: 0) == 0 else { return "góc ban đầu khác 0" }

            viewer.goToPageForSelfTest(0)
            viewer.rotateForSelfTest(90)
            guard viewer.rotationForSelfTest(page: 0) == 90 else {
                return "xoay phải ra \(viewer.rotationForSelfTest(page: 0))°"
            }
            guard viewer.hasUnsavedPageEditsForSelfTest else {
                return "sửa rồi mà không đánh dấu là chưa lưu"
            }
            viewer.undoPageEditForSelfTest()
            guard viewer.rotationForSelfTest(page: 0) == 0 else {
                return "hoàn tác ra \(viewer.rotationForSelfTest(page: 0))°, mong 0"
            }
            guard !viewer.hasUnsavedPageEditsForSelfTest else {
                return "hoàn tác hết rồi mà vẫn báo chưa lưu"
            }
            return nil
        },

        Case(name: "PDF: dời trang đổi đúng thứ tự, hoàn tác trả về chỗ cũ") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["MOT", "HAI", "BA"]) else {
                return "không mở được PDF thử"
            }
            viewer.goToPageForSelfTest(0)
            viewer.movePageForSelfTest(by: 1)
            guard viewer.textForSelfTest(page: 0) == "HAI",
                  viewer.textForSelfTest(page: 1) == "MOT" else {
                return "sau khi dời: \(viewer.textForSelfTest(page: 0))·\(viewer.textForSelfTest(page: 1))"
            }
            viewer.undoPageEditForSelfTest()
            guard viewer.textForSelfTest(page: 0) == "MOT",
                  viewer.textForSelfTest(page: 1) == "HAI" else {
                return "hoàn tác không trả về chỗ cũ"
            }
            // Ở trang đầu mà dời lên thì KHÔNG được lặng lẽ làm gì đó.
            viewer.goToPageForSelfTest(0)
            let depth = viewer.undoDepthForSelfTest
            viewer.movePageForSelfTest(by: -1)
            guard viewer.undoDepthForSelfTest == depth else {
                return "dời lên ở trang đầu vẫn ghi một thao tác"
            }
            return nil
        },

        // Xoá nhiều trang cùng lúc. Chỗ dễ sai nhất: xoá theo chiều xuôi thì mỗi lần xoá làm mọi
        // chỉ số phía sau tụt một, và tập chỉ số người dùng nhập lập tức trỏ sai trang.
        Case(name: "PDF: xoá nhiều trang không lệch chỉ số, hoàn tác trả về đủ") { controller in
            guard let viewer = Self.openPDF(
                controller, pages: ["MOT", "HAI", "BA", "BON", "NAM"]
            ) else { return "không mở được PDF thử" }

            guard viewer.deletePagesForSelfTest("2,4") else { return "phép xoá bị từ chối" }
            guard viewer.pageCountForSelfTest == 3 else {
                return "còn \(viewer.pageCountForSelfTest) trang, mong 3"
            }
            let con_lai = (0 ..< 3).map { viewer.textForSelfTest(page: $0) }
            guard con_lai == ["MOT", "BA", "NAM"] else {
                return "xoá lệch chỉ số — còn lại \(con_lai)"
            }
            viewer.undoPageEditForSelfTest()
            let sau_hoan_tac = (0 ..< 5).map { viewer.textForSelfTest(page: $0) }
            guard sau_hoan_tac == ["MOT", "HAI", "BA", "BON", "NAM"] else {
                return "hoàn tác ra \(sau_hoan_tac)"
            }
            return nil
        },

        Case(name: "PDF: từ chối xoá TẤT CẢ trang") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["MOT", "HAI"]) else {
                return "không mở được PDF thử"
            }
            // Một PDF không còn trang nào là thứ nhiều trình đọc từ chối mở. Người muốn bỏ cả
            // tệp thì xoá tệp, không xoá từng trang.
            guard !viewer.deletePagesForSelfTest("1-2") else {
                return "xoá hết trang mà vẫn cho qua"
            }
            guard viewer.pageCountForSelfTest == 2 else { return "đã xoá mất trang" }
            return nil
        },

        // Trích ra tệp mới: tệp gốc KHÔNG được đụng, và tệp mới phải mở lại được.
        Case(name: "PDF: trích trang ra tệp mới, gốc nguyên vẹn, tệp mới mở lại đúng") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["MOT", "HAI", "BA", "BON"]) else {
                return "không mở được PDF thử"
            }
            let out = (NSTemporaryDirectory() as NSString).appendingPathComponent("trich.pdf")
            defer { try? FileManager.default.removeItem(atPath: out) }

            guard viewer.extractForSelfTest("1,3", to: out) else { return "trích không ghi được" }
            guard viewer.pageCountForSelfTest == 4 else {
                return "trích mà tài liệu gốc đổi còn \(viewer.pageCountForSelfTest) trang"
            }
            guard !viewer.hasUnsavedPageEditsForSelfTest else {
                return "trích ra tệp khác mà lại đánh dấu tài liệu đang mở là đã sửa"
            }
            guard let lai = PDFViewerView.inspectForSelfTest(out), lai.pages == 2 else {
                return "tệp trích mở lại không đúng"
            }
            return nil
        },

        // Tách làm HAI tệp. Vế đáng giá nhất là vế "phần còn lại": lệnh này ghi hai tệp trong
        // một lần hỏi, nên một bài chỉ soi tệp thứ nhất sẽ xanh cả khi tệp thứ hai không bao
        // giờ ra đời — mà tệp thứ hai mới là thứ chứa những trang người dùng KHÔNG chọn, tức
        // thứ họ sẽ chỉ phát hiện là mất khi cần tới.
        Case(name: "PDF: tách làm hai tệp, phần còn lại đủ trang, tài liệu gốc nguyên vẹn") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["MOT", "HAI", "BA", "BON"]) else {
                return "không mở được PDF thử"
            }
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("tach-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }
            let first = (folder as NSString).appendingPathComponent("phan-1.pdf")

            guard viewer.splitForSelfTest("1-2", to: first) else { return "tách không ghi được" }

            let second = (folder as NSString).appendingPathComponent("phan-1-con-lai.pdf")
            guard let a = PDFViewerView.inspectForSelfTest(first), a.pages == 2 else {
                return "tệp thứ nhất không mở lại được đúng 2 trang"
            }
            guard let b = PDFViewerView.inspectForSelfTest(second), b.pages == 2 else {
                return "KHÔNG có tệp «phần còn lại» đúng 2 trang cạnh tệp thứ nhất"
            }
            guard viewer.pageCountForSelfTest == 4 else {
                return "tách mà tài liệu gốc còn \(viewer.pageCountForSelfTest) trang"
            }
            // Tách toàn bộ tài liệu thì KHÔNG phải là tách — phải từ chối, không ghi một tệp
            // rỗng làm "phần còn lại".
            guard !viewer.splitForSelfTest("1-4", to: first) else {
                return "tách TOÀN BỘ tài liệu mà vẫn nhận"
            }
            return nil
        },

        // Xuất trang ra PNG. Bài soi BYTE của tệp ghi ra, không chỉ soi tệp có tồn tại: một
        // `NSBitmapImageRep` dựng hỏng vẫn ghi ra được một tệp, chỉ là nó rỗng hoặc đen.
        Case(name: "PDF: xuất trang ra PNG, đúng số tệp và đúng định dạng") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["MOT", "HAI", "BA"]) else {
                return "không mở được PDF thử"
            }
            let folder = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("anh-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                atPath: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: folder) }

            let written = viewer.exportImagesForSelfTest("1,3", into: folder)
            guard written == 2 else { return "xuất được \(written) ảnh, mong 2" }

            // Tên tệp mang số trang THẬT (1 và 3), không phải số thứ tự trong lượt xuất — người
            // dùng đối chiếu ảnh với trang trong tài liệu bằng đúng con số ấy.
            let one = (folder as NSString).appendingPathComponent("trang-001.png")
            let three = (folder as NSString).appendingPathComponent("trang-003.png")
            guard let dataOne = FileManager.default.contents(atPath: one),
                  FileManager.default.fileExists(atPath: three) else {
                return "thiếu tệp: \((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])"
            }
            guard Array(dataOne.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] else {
                return "tệp ghi ra không phải PNG"
            }
            // Một trang A4 vẽ ở 2× không thể nhỏ như một ảnh rỗng.
            guard dataOne.count > 1000 else { return "ảnh chỉ \(dataOne.count) byte — gần như rỗng" }
            return nil
        },

        Case(name: "PDF: gộp tệp khác vào sau trang đang xem, hoàn tác gỡ đúng phần đã chèn") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["MOT", "HAI"]) else {
                return "không mở được PDF thử"
            }
            let other = (NSTemporaryDirectory() as NSString).appendingPathComponent("gop-vao.pdf")
            defer { try? FileManager.default.removeItem(atPath: other) }
            guard Self.makePDF(at: other, pages: ["XEN1", "XEN2"]) else {
                return "không dựng được PDF để gộp"
            }

            viewer.goToPageForSelfTest(0)
            viewer.mergeForSelfTest(path: other)
            guard viewer.pageCountForSelfTest == 4 else {
                return "gộp xong có \(viewer.pageCountForSelfTest) trang, mong 4"
            }
            let thu_tu = (0 ..< 4).map { viewer.textForSelfTest(page: $0) }
            guard thu_tu == ["MOT", "XEN1", "XEN2", "HAI"] else {
                return "gộp sai chỗ — \(thu_tu)"
            }
            viewer.undoPageEditForSelfTest()
            guard viewer.pageCountForSelfTest == 2,
                  (0 ..< 2).map({ viewer.textForSelfTest(page: $0) }) == ["MOT", "HAI"] else {
                return "hoàn tác không gỡ đúng phần đã chèn"
            }
            return nil
        },

        // Câu hỏi quan trọng nhất của lối "phủ rồi vẽ": vẽ lại trang có biến nó thành ẢNH không.
        //
        // Nếu có thì cái giá quá đắt — mất chọn chữ, mất tìm, mất chép, và tệp phình lên. Bài
        // này hỏi thẳng bằng cách đòi tầng chữ CÒN NGUYÊN sau khi chèn ảnh chữ ký.
        Case(name: "PDF ký: chèn ảnh xong tầng chữ vẫn còn — không rasterise trang") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["HOP DONG SO 7", "HAI"]) else {
                return "không mở được PDF thử"
            }
            viewer.goToPageForSelfTest(0)
            let truoc = viewer.textForSelfTest(page: 0)
            guard truoc.contains("HOP DONG SO 7") else { return "chữ ban đầu đã sai: \(truoc)" }

            let chuKy = NSImage(size: NSSize(width: 120, height: 40))
            chuKy.lockFocus()
            NSColor.blue.setFill()
            NSRect(x: 0, y: 0, width: 120, height: 40).fill()
            chuKy.unlockFocus()

            viewer.insertSignatureForSelfTest(chuKy)
            guard viewer.hasUnsavedPageEditsForSelfTest else { return "chèn xong không đánh dấu đã sửa" }
            let sau = viewer.textForSelfTest(page: 0)
            guard sau.contains("HOP DONG SO 7") else {
                return "TẦNG CHỮ MẤT sau khi chèn — trang đã bị rasterise: \(String(sau.prefix(60)))"
            }
            guard viewer.pageCountForSelfTest == 2 else { return "số trang đổi sau khi ký" }
            // Trang KHÔNG bị ký thì phải nguyên xi.
            guard viewer.textForSelfTest(page: 1) == "HAI" else { return "trang khác bị đụng" }

            // Ghi ra đĩa rồi MỞ LẠI: bằng chứng trang vừa dựng là một PDF hợp lệ, không phải
            // một khối byte chỉ PDFKit trong tiến trình này đọc nổi.
            let out = NSTemporaryDirectory() + "da-ky-\(UUID().uuidString).pdf"
            defer { try? FileManager.default.removeItem(atPath: out) }
            guard viewer.writeCopyForSelfTest(to: out) else { return "không ghi được tệp đã ký" }
            guard let lai = PDFViewerView.inspectForSelfTest(out), lai.pages == 2 else {
                return "tệp đã ký mở lại không đúng số trang"
            }

            viewer.undoPageEditForSelfTest()
            guard viewer.textForSelfTest(page: 0) == "HOP DONG SO 7" else {
                return "hoàn tác không trả về trang cũ"
            }
            return nil
        },

        // Vẽ đè chữ mới, và NÓI RA giới hạn quan trọng nhất của lối này.
        //
        // Chữ cũ bị PHỦ chứ không bị XOÁ: nó vẫn nằm trong luồng nội dung và vẫn trích ra được.
        // Bài kiểm khẳng định đúng điều đó — không phải vì nó tốt, mà vì nó là SỰ THẬT và trang
        // trợ giúp phải nói ra. Ai cần bôi đen thật thì đây không phải công cụ ấy.
        Case(name: "PDF sửa chữ: chữ mới VÀO tầng chữ, chữ cũ vẫn còn — cả hai đều phải nói ra") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["SO TIEN 100"]) else {
                return "không mở được PDF thử"
            }
            viewer.goToPageForSelfTest(0)
            let box = viewer.pageBoundsForSelfTest(0)
            let vung = CGRect(x: box.minX + 20, y: box.minY + 90, width: 160, height: 24)

            viewer.replaceTextForSelfTest("SO TIEN 999", rect: vung)
            guard viewer.hasUnsavedPageEditsForSelfTest else { return "sửa chữ không đánh dấu đã sửa" }

            let text = viewer.textForSelfTest(page: 0)
            guard text.contains("SO TIEN 100") else {
                return "trang bị rasterise — mất cả chữ cũ lẫn tầng chữ"
            }
            // Chữ MỚI cũng vào tầng chữ — đo được, và tốt hơn giả định ban đầu.
            //
            // `NSString.draw` vào một `CGPDFContext` phát ra toán tử CHỮ thật, nên chữ vẽ đè vẫn
            // tìm được bằng ⌘F và chép ra được. Bên `mobiluck-reader` §K mất khoản này vì Android
            // buộc phải vẽ ảnh một bit; ở đây không mất. Giữ vế này trong bài kiểm để nếu một
            // ngày nào đó ai đó đổi sang vẽ ảnh, cổng sẽ nói ngay là lời hứa đã đổi.
            guard text.contains("999") else {
                return "chữ vẽ đè KHÔNG vào tầng chữ — trang trợ giúp đang hứa nhiều hơn thực tế"
            }
            viewer.undoPageEditForSelfTest()
            guard !viewer.hasUnsavedPageEditsForSelfTest else { return "hoàn tác không sạch" }
            return nil
        },

        // Biểu mẫu: điền → ghi ra tệp → MỞ LẠI TỆP và đòi giá trị còn nguyên.
        //
        // Hỏi tệp trên đĩa chứ không hỏi biến trong bộ nhớ: cả điểm của tính năng này là bên
        // nhận mở tờ khai lên và thấy nó đã điền.
        Case(name: "PDF biểu mẫu: điền rồi ghi, mở lại tệp thấy đúng giá trị") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["TO KHAI"]) else {
                return "không mở được PDF thử"
            }
            guard viewer.addTextFieldForSelfTest(name: "ho_ten") else {
                return "không dựng được ô biểu mẫu"
            }
            guard viewer.formFieldCountForSelfTest == 1 else {
                return "đếm ra \(viewer.formFieldCountForSelfTest) ô, mong 1"
            }

            // Chữ có dấu: đây đúng chỗ `mobiluck-reader` §I cảnh báo font mặc định của PDF làm
            // mất dấu, nên phải kiểm bằng một cái tên thật.
            viewer.setFormValueForSelfTest(0, "Nguyễn Văn Anh")
            let out = NSTemporaryDirectory() + "to-khai-\(UUID().uuidString).pdf"
            defer { try? FileManager.default.removeItem(atPath: out) }
            guard viewer.writeCopyForSelfTest(to: out) else { return "không ghi được tệp" }

            let lai = PDFViewerView.formValuesForSelfTest(out)
            guard lai == ["Nguyễn Văn Anh"] else {
                return "mở lại tệp ra \(lai), mong [\"Nguyễn Văn Anh\"]"
            }
            return nil
        },

        Case(name: "PDF biểu mẫu: xoá nội dung đã điền, hoàn tác trả lại") { controller in
            guard let viewer = Self.openPDF(controller, pages: ["TO KHAI"]) else {
                return "không mở được PDF thử"
            }
            guard viewer.addTextFieldForSelfTest(name: "dia_chi") else {
                return "không dựng được ô biểu mẫu"
            }
            viewer.setFormValueForSelfTest(0, "Hà Nội")
            viewer.resetFormForSelfTest()
            guard viewer.formValueForSelfTest(0) == "" else {
                return "xoá xong còn \(viewer.formValueForSelfTest(0) ?? "nil")"
            }
            viewer.undoPageEditForSelfTest()
            guard viewer.formValueForSelfTest(0) == "Hà Nội" else {
                return "hoàn tác ra \(viewer.formValueForSelfTest(0) ?? "nil")"
            }
            return nil
        },

        // MARK: - Xem nhị phân và bộ phát

        // Nguyên tắc của sản phẩm: tệp lớn cỡ nào cũng phải MỞ RẤT NHANH. Bài này giữ nó bằng
        // một con số, không bằng lời hứa — và nó đo trên tệp 1 GB THẬT (tệp thưa: nhân cấp phát
        // lười nên nó không tốn 1 GB đĩa, nhưng `stat` và `mmap` vẫn thấy đủ 1 GB).
        //
        // Ngưỡng 300 ms rộng hơn nhiều so với thời gian đo được, và cố ý thế: bài kiểm này canh
        // KIẾN TRÚC — "không có ai lỡ đọc cả tệp" — chứ không canh vài chục mili-giây dao động
        // giữa các máy. Đọc cả 1 GB thì con số sẽ là hàng giây, tức vượt xa ngưỡng.
        Case(name: "xem nhị phân tệp 1 GB mở gần như tức thì") { controller in
            let path = NSTemporaryDirectory() + "geditor-hex-1gb.bin"
            defer { try? FileManager.default.removeItem(atPath: path) }
            FileManager.default.createFile(atPath: path, contents: nil)
            guard let handle = FileHandle(forWritingAtPath: path) else {
                return "không tạo được tệp thử"
            }
            // 1 KB đầu có nội dung thật để còn kiểm được nội dung dòng đầu.
            try? handle.write(contentsOf: Data((0 ..< 256).map { UInt8($0) }))
            try? handle.truncate(atOffset: 1 << 30)
            try? handle.close()

            let viewer = HexViewerView()
            let start = Date()
            viewer.load(path: path)
            let elapsed = Date().timeIntervalSince(start) * 1000

            guard viewer.fileSize == 1 << 30 else {
                return "cỡ tệp đọc sai: \(viewer.fileSize)"
            }
            guard elapsed < 300 else {
                return "mở tệp 1 GB mất \(Int(elapsed)) ms — nghi có chỗ đọc cả tệp"
            }
            // Dòng đầu phải đúng byte, không phải một bảng rỗng trông như đã mở được.
            let first = viewer.lineForSelfTest(row: 0)
            guard first.hasPrefix("00000000  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F") else {
                return "dòng đầu sai: \(first)"
            }
            print("   mở 1 GB ở chế độ nhị phân: \(Int(elapsed)) ms")
            return nil
        },

        // Phân trang: cửa sổ 4 MB tồn tại vì `NSTableView` mất chính xác toạ độ ở tài liệu rất
        // cao. Bài này giữ hai vế — số hàng đúng bằng một cửa sổ, và nhảy offset thì cửa sổ dời.
        Case(name: "xem nhị phân: nhảy tới offset xa thì cửa sổ dời theo") { _ in
            let path = NSTemporaryDirectory() + "geditor-hex-window.bin"
            defer { try? FileManager.default.removeItem(atPath: path) }
            FileManager.default.createFile(atPath: path, contents: nil)
            guard let handle = FileHandle(forWritingAtPath: path) else { return "không tạo được tệp" }
            try? handle.truncate(atOffset: 32 << 20)              // 32 MB
            try? handle.close()

            let viewer = HexViewerView()
            viewer.load(path: path)
            guard viewer.windowStartForSelfTest == 0 else { return "cửa sổ đầu không ở 0" }
            let expected = HexViewerView.windowBytes / HexDump.bytesPerRow
            guard viewer.rowCountForSelfTest == expected else {
                return "cửa sổ \(viewer.rowCountForSelfTest) hàng, chờ \(expected)"
            }

            viewer.goToOffsetTextForSelfTest("1000000")           // 0x1000000 = 16 MB
            guard viewer.windowStartForSelfTest == 16 << 20 else {
                return "nhảy tới 16 MB mà cửa sổ ở \(viewer.windowStartForSelfTest)"
            }
            // Offset vượt cỡ tệp thì KHÔNG được im lặng dời cửa sổ đi đâu đó.
            let before = viewer.windowStartForSelfTest
            viewer.goToOffsetTextForSelfTest("FFFFFFFF")
            guard viewer.windowStartForSelfTest == before else {
                return "offset vượt cỡ tệp vẫn dời cửa sổ"
            }
            return nil
        },

        // Bộ phát đi qua đường AVFoundation THẬT với một tệp WAV tự dựng — không giả lập.
        Case(name: "phát được tệp WAV, và dừng được") { _ in
            let path = NSTemporaryDirectory() + "geditor-thu.wav"
            defer { try? FileManager.default.removeItem(atPath: path) }
            guard (try? Self.minimalWAV(seconds: 1).write(to: URL(fileURLWithPath: path))) != nil
            else { return "không ghi được tệp WAV thử" }

            guard MediaKind.of(path: path) == .audio else { return "không nhận ra là nhạc" }

            let viewer = MediaPlayerView()
            viewer.load(path: path, kind: .audio)
            // `loadValuesAsynchronously` trả lời ở lượt chạy sau, nên phải cho vòng lặp chạy.
            let deadline = Date().addingTimeInterval(5)
            while !viewer.hasPlayerForSelfTest, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            guard viewer.hasPlayerForSelfTest else {
                return "không dựng được bộ phát cho WAV"
            }
            guard !viewer.isFallbackVisibleForSelfTest else {
                return "WAV mà lại hiện khung «không phát được»"
            }
            viewer.playForSelfTest()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            guard viewer.isPlayingForSelfTest else { return "bấm phát mà không chạy" }
            viewer.stop()
            guard !viewer.isPlayingForSelfTest else { return "dừng rồi mà vẫn chạy" }
            return nil
        },

        // Định dạng macOS không giải mã được phải NÓI RA, không hiện một ô đen.
        Case(name: "định dạng không phát được thì nói lý do, không hiện ô đen") { _ in
            let path = NSTemporaryDirectory() + "geditor-thu.mkv"
            defer { try? FileManager.default.removeItem(atPath: path) }
            // Chữ ký Matroska thật, phần thân là rác — đủ để nhận ra loại và đủ để AVFoundation
            // từ chối. Đúng tình huống người dùng gặp với một tệp `.mkv` thật.
            var bytes: [UInt8] = [0x1A, 0x45, 0xDF, 0xA3]
            bytes += [UInt8](repeating: 0x42, count: 1024)
            guard (try? Data(bytes).write(to: URL(fileURLWithPath: path))) != nil else {
                return "không ghi được tệp thử"
            }
            guard MediaKind.of(path: path) == .video else { return "không nhận ra là phim" }

            let viewer = MediaPlayerView()
            viewer.load(path: path, kind: .video)
            let deadline = Date().addingTimeInterval(5)
            while !viewer.isFallbackVisibleForSelfTest, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            guard viewer.isFallbackVisibleForSelfTest else {
                return "không phát được mà cũng không nói gì"
            }
            guard viewer.fallbackTextForSelfTest.contains("Không phát được") else {
                return "câu thông báo không nói rõ: \(viewer.fallbackTextForSelfTest)"
            }
            return nil
        },

        // Ảnh động phải ĐỘNG, và nút phát chỉ có mặt khi ảnh thật sự nhiều khung.
        Case(name: "ảnh động phát được; ảnh tĩnh không có nút phát") { _ in
            let gifPath = NSTemporaryDirectory() + "geditor-dong.gif"
            let pngPath = NSTemporaryDirectory() + "geditor-tinh.png"
            defer {
                try? FileManager.default.removeItem(atPath: gifPath)
                try? FileManager.default.removeItem(atPath: pngPath)
            }
            guard (try? Self.twoFrameGIF().write(to: URL(fileURLWithPath: gifPath))) != nil else {
                return "không ghi được GIF thử"
            }
            let solid = NSImage(size: NSSize(width: 4, height: 4))
            solid.lockFocus()
            NSColor.red.setFill()
            NSRect(x: 0, y: 0, width: 4, height: 4).fill()
            solid.unlockFocus()
            guard let tiff = solid.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]),
                  (try? png.write(to: URL(fileURLWithPath: pngPath))) != nil
            else { return "không ghi được PNG thử" }

            let animated = ImageViewerView()
            animated.load(path: gifPath)
            guard animated.frameCountForSelfTest == 2 else {
                return "GIF hai khung mà đếm ra \(animated.frameCountForSelfTest)"
            }
            guard animated.isAnimatingForSelfTest else { return "ảnh động mà không chạy" }
            animated.togglePlaybackForSelfTest()
            guard !animated.isAnimatingForSelfTest else { return "bấm tạm dừng mà vẫn chạy" }

            let still = ImageViewerView()
            still.load(path: pngPath)
            guard still.frameCountForSelfTest == 1 else {
                return "ảnh tĩnh mà đếm ra \(still.frameCountForSelfTest) khung"
            }
            return nil
        },

        // MARK: - Trợ giúp (NFR-USE-04)

        // Cổng phủ lệnh. Đây là bài duy nhất biến câu "mọi tính năng đều có hướng dẫn" thành
        // một mệnh đề kiểm được.
        //
        // Đối chiếu với THANH MENU THẬT, không với một danh sách chép tay. Một danh sách chép
        // tay sẽ trôi khỏi menu đúng như trang trạng thái đã trôi khỏi kho ba lần — và nó trôi
        // theo hướng tệ nhất: lệnh mới thêm vào menu không có hướng dẫn, mà cổng vẫn xanh vì
        // danh sách của nó chưa biết lệnh ấy tồn tại.
        Case(name: "mọi lệnh trên thanh menu đều có trang hướng dẫn") { _ in
            let book = HelpContent.book(language: L10n.effective.rawValue)
            let missing = HelpCoverage.missingCommands(in: book)
            guard missing.isEmpty else {
                return "\(missing.count) lệnh chưa có hướng dẫn: " + missing.joined(separator: " · ")
            }
            return nil
        },

        // Đối chứng của cổng trên: một mã lệnh trong sách mà menu KHÔNG còn có nghĩa là trang
        // hướng dẫn đang tả một lệnh đã bị đổi tên hoặc bỏ đi — người đọc sẽ đi tìm nó trong
        // menu và không thấy.
        Case(name: "sách không hướng dẫn lệnh nào đã biến khỏi menu") { _ in
            let book = HelpContent.book(language: L10n.effective.rawValue)
            let onMenu = AppDelegate.appOwnedMenuTitles
            let ghosts = book.coveredCommands.subtracting(onMenu).sorted()
            guard ghosts.isEmpty else {
                return "\(ghosts.count) lệnh có hướng dẫn nhưng không có trên menu: "
                    + ghosts.joined(separator: " · ")
            }
            return nil
        },

        // Quyết định "có chào lúc khởi động không" — cả bốn nhánh.
        //
        // Bài này tồn tại vì phần ấy nằm sau chính hàng rào mà bộ tự kiểm dựng lên: cửa sổ chào
        // bị chặn trong lượt chạy không người lái, nên nếu không hỏi thẳng hàm quyết định thì
        // đúng phần quan trọng nhất của tính năng là phần KHÔNG có bài kiểm nào.
        Case(name: "luật mở cửa sổ chào lúc khởi động") { _ in
            let người = ["/path/GEditorApp", "tep.txt"]
            guard AppDelegate.shouldShowWelcome(settingSaysYes: true, arguments: người) else {
                return "cấu hình nói CÓ, lượt chạy bình thường — mà không mở"
            }
            guard !AppDelegate.shouldShowWelcome(settingSaysYes: false, arguments: người) else {
                return "người dùng đã tắt mà vẫn mở — lời hứa «từ đó không mở lại nữa» bị phá"
            }
            for cờ in ["--self-test", "--capture", "--measure-startup", "--soak", "--office-e2e"] {
                guard !AppDelegate.shouldShowWelcome(
                    settingSaysYes: true, arguments: ["/path/GEditorApp", cờ]
                ) else {
                    return "lượt chạy \(cờ) vẫn bung cửa sổ chào"
                }
            }
            return nil
        },

        Case(name: "sách trợ giúp không tự mâu thuẫn") { _ in
            // MỌI cuốn, không riêng cuốn của ngôn ngữ đang chạy. Một liên kết gãy trong bản
            // tiếng Anh không lộ ra ở đây nếu bài kiểm chỉ soi bản tiếng Việt — và nó sẽ lộ ra
            // ở máy người dùng.
            for language in HelpContent.translatedLanguages.sorted() {
                let problems = HelpContent.book(language: language).problems()
                guard problems.isEmpty else {
                    return "sách «\(language)» có \(problems.count) lỗi: "
                        + problems.prefix(5).joined(separator: " · ")
                }
            }
            return nil
        },

        // Hai cuốn phải có CÙNG BỘ MÃ TRANG.
        //
        // Đây là điều kiện để đổi ngôn ngữ mà người đọc **ở nguyên trang họ đang đọc**. Lệch
        // một mã thì trang ấy im lặng rơi về trang đầu — người dùng bấm đổi tiếng và thấy mình
        // bị ném về mục lục, không hiểu vì sao. Nó cũng là điều kiện để `.seeAlso` không gãy.
        Case(name: "mọi bản dịch sách trợ giúp có cùng bộ mã trang") { _ in
            let goc = HelpContent.book(language: "vi")
            let macGoc = Set(goc.allTopics.map(\.id))
            guard macGoc.count == goc.allTopics.count else {
                return "bản gốc có mã trang TRÙNG NHAU"
            }

            for language in HelpContent.translatedLanguages.sorted() where language != "vi" {
                let ban = HelpContent.book(language: language)
                let mac = Set(ban.allTopics.map(\.id))
                let thieu = macGoc.subtracting(mac)
                let thua = mac.subtracting(macGoc)
                guard thieu.isEmpty else {
                    return "sách «\(language)» thiếu \(thieu.count) trang: "
                        + thieu.sorted().prefix(5).joined(separator: ", ")
                }
                guard thua.isEmpty else {
                    return "sách «\(language)» có \(thua.count) trang không có ở bản gốc: "
                        + thua.sorted().prefix(5).joined(separator: ", ")
                }
                // Thứ tự chương cũng phải khớp: mục lục hai bên đọc lên phải là một cuốn sách.
                guard ban.chapters.map(\.id) == goc.chapters.map(\.id) else {
                    return "sách «\(language)» sắp chương khác bản gốc"
                }
                // Và mỗi trang phải có nội dung THẬT, không phải một vỏ rỗng để qua phép đếm.
                for topic in ban.allTopics {
                    guard !topic.blocks.isEmpty, !topic.title.isEmpty, !topic.summary.isEmpty else {
                        return "sách «\(language)»: trang \(topic.id) rỗng"
                    }
                }
            }
            return nil
        },

        // Cửa sổ trợ giúp phải DỰNG ĐƯỢC mọi trang, không chỉ trang đầu.
        //
        // Bài này đi qua đúng đường AppKit thật: mỗi trang được dựng thành view và đếm lại. Một
        // khối kiểu mới mà bộ dựng quên xử lý sẽ lộ ra ở đây chứ không lộ ra ở máy người dùng.
        Case(name: "dựng được view cho mọi trang trợ giúp") { _ in
            for language in HelpContent.translatedLanguages.sorted() {
            let book = HelpContent.book(language: language)
            for topic in book.allTopics {
                let views = HelpBlockViews.views(for: topic.blocks, book: book, onNavigate: { _ in })
                guard views.count == topic.blocks.count else {
                    return "sách «\(language)» trang \(topic.id): "
                        + "\(topic.blocks.count) khối ra \(views.count) view"
                }
            }
            }
            return nil
        },

        // Đổi ngôn ngữ sách phải GIỮ NGUYÊN trang đang đọc.
        //
        // Đây là lý do mã trang cố ý không dịch. Không giữ được thì người dùng bấm đổi tiếng
        // giữa chừng một trang dài và bị ném về mục lục — họ sẽ đọc đó là lỗi, không đọc là
        // «bản dịch chưa có trang ấy».
        Case(name: "đổi ngôn ngữ sách trợ giúp giữ nguyên trang đang đọc") { controller in
            let help = HelpWindowController.show(topicID: "column-editor", settings: controller)
            defer { help.window?.close() }

            guard help.helpLanguageChoicesForSelfTest.contains("en"),
                  help.helpLanguageChoicesForSelfTest.contains("vi") else {
                return "danh sách ngôn ngữ thiếu: \(help.helpLanguageChoicesForSelfTest)"
            }

            help.pickHelpLanguageForSelfTest("en")
            guard help.helpLanguageForSelfTest == "en" else {
                return "chọn tiếng Anh mà sách vẫn là «\(help.helpLanguageForSelfTest)»"
            }
            guard help.currentTopicIDForSelfTest == "column-editor" else {
                return "đổi ngôn ngữ xong bị ném sang trang "
                    + "«\(help.currentTopicIDForSelfTest ?? "không có")»"
            }
            guard help.currentTitleForSelfTest == "Column Editor" else {
                return "trang tiếng Anh mà nhan đề là «\(help.currentTitleForSelfTest)»"
            }

            // Và quay lại tiếng Việt cũng vậy — đường về phải chạy được, không chỉ đường đi.
            help.pickHelpLanguageForSelfTest("vi")
            guard help.helpLanguageForSelfTest == "vi",
                  help.currentTopicIDForSelfTest == "column-editor" else {
                return "quay về tiếng Việt thì lạc trang"
            }
            return nil
        },

        Case(name: "cửa sổ trợ giúp mở đúng trang và đi theo liên kết") { controller in
            let help = HelpWindowController.show(topicID: "nhieu-con-nhay", settings: controller)
            defer { help.window?.close() }
            guard help.currentTopicIDForSelfTest == "nhieu-con-nhay" else {
                return "mở nhầm trang: \(help.currentTopicIDForSelfTest ?? "không có")"
            }
            help.go(to: "column-editor")
            guard help.currentTopicIDForSelfTest == "column-editor" else {
                return "không đi được sang trang khác"
            }
            guard help.canGoBackForSelfTest else { return "nút Lùi không bật lên sau khi đi" }
            return nil
        },

        // Ô tích "không mở lại" phải GHI THẬT xuống cấu hình.
        //
        // Bài này đi qua chính hành động của nút, không gọi thẳng hàm ghi: chỗ hỏng thật sự nằm
        // ở dây nối giữa nút và cấu hình, và một bài kiểm gọi thẳng hàm ghi thì xanh kể cả khi
        // dây ấy đứt.
        Case(name: "ô tích chào mừng ghi xuống cấu hình và giữ nguyên sau đó") { controller in
            let before = controller.settings.showWelcomeOnLaunch
            defer { controller.setShowWelcomeOnLaunch(before) }

            controller.setShowWelcomeOnLaunch(true)
            let help = HelpWindowController.show(
                topicID: HelpContent.entryTopicID, welcome: true, settings: controller
            )
            defer { help.window?.close() }
            guard help.welcomeFooterVisibleForSelfTest else {
                return "mở kiểu chào mà không có chân trang"
            }
            guard help.dontShowAgainCheckedForSelfTest == false else {
                return "ô tích đang bật trong khi cấu hình nói vẫn hiện"
            }

            help.clickDontShowAgainForSelfTest()
            guard controller.settings.showWelcomeOnLaunch == false else {
                return "bấm ô tích mà cấu hình không đổi"
            }

            // Và đọc lại từ ĐĨA: ghi vào biến trong bộ nhớ thì mất sạch ở lần khởi động sau,
            // đúng lúc lời hứa "từ đó không mở lại nữa" phải có hiệu lực.
            guard let onDisk = try? Settings.load(from: AppPaths.settingsFile) else {
                return "không đọc lại được settings.json"
            }
            guard onDisk.showWelcomeOnLaunch == false else {
                return "settings.json trên đĩa vẫn nói là còn mở lại"
            }
            return nil
        },
    ]

    /// Vị trí byte đầu tiên của `needle` trong `haystack`, hoặc `nil`.
    ///
    /// Tìm trên BYTE chứ không trên `String.range(of:)`: bài kiểm cần offset tài liệu, và mọi
    /// phép quy đổi từ chỉ số `String` sang offset byte đều là một chỗ để sai thêm một lần.
    static func indexOf(_ needle: [UInt8], in haystack: [UInt8]) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        for start in 0 ... (haystack.count - needle.count)
        where Array(haystack[start ..< start + needle.count]) == needle {
            return start
        }
        return nil
    }

    /// Kho cpio tối thiểu, định dạng "070707" (odc) — chỉ dùng cho bài tự kiểm khung xem.
    ///
    /// Header là 76 ký tự bát phân viết dạng văn bản, không nén, không checksum. Tên tệp đi
    /// ngay sau header và ĐẾM CẢ byte NUL kết thúc — quên byte ấy thì mọi tên lệch một ký tự
    /// và libarchive từ chối cả kho.
    ///
    /// Kho kết thúc bằng một mục tên `TRAILER!!!` cỡ 0. Thiếu nó thì bộ đọc chạy quá cuối tệp.
    /// Dựng một PDF nhiều trang rồi mở nó trong khung PDF, trả về khung ấy.
    ///
    /// Đi qua ĐÚNG đường mở tệp của sản phẩm (`controller.open`), không dựng thẳng một
    /// `PDFViewerView` rời: cái cần kiểm gồm cả việc nhận diện tệp và tráo khung, và một bài
    /// kiểm dựng thẳng khung sẽ xanh kể cả khi đường nhận diện đứt.
    static func openPDF(_ controller: MainWindowController, pages: [String]) -> PDFViewerView? {
        let folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pdf-trang-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        temporaryFolders.append(folder)
        let path = (folder as NSString).appendingPathComponent("thu.pdf")
        guard makePDF(at: path, pages: pages) else { return nil }
        controller.open(path: path, line: nil, column: nil, readOnly: false)
        return controller.mediaViewer.contentForSelfTest as? PDFViewerView
    }

    /// Thư mục tạm các bài kiểm PDF đã tạo — dọn một lần ở cuối lượt chạy.
    private static var temporaryFolders: [String] = []

    static func removeTemporaryFolders() {
        for folder in temporaryFolders { try? FileManager.default.removeItem(atPath: folder) }
        temporaryFolders.removeAll()
    }

    /// Một PDF THẬT do CoreGraphics ghi, mỗi trang một dòng chữ khác nhau.
    ///
    /// Chữ khác nhau từng trang là điều kiện để kiểm được THỨ TỰ: sau khi dời hay xoá trang, câu
    /// hỏi duy nhất đáng hỏi là "trang nào đang đứng ở đâu", và một tập trang trắng giống hệt
    /// nhau thì không trả lời được câu ấy — bài kiểm sẽ xanh cả khi thứ tự sai.
    @discardableResult
    static func makePDF(at path: String, pages: [String]) -> Bool {
        var box = CGRect(x: 0, y: 0, width: 300, height: 200)
        guard let context = CGContext(URL(fileURLWithPath: path) as CFURL, mediaBox: &box, nil)
        else { return false }
        for label in pages {
            context.beginPDFPage(nil)
            let text = NSAttributedString(
                string: label, attributes: [.font: NSFont.systemFont(ofSize: 18)])
            context.textPosition = CGPoint(x: 20, y: 100)
            CTLineDraw(CTLineCreateWithAttributedString(text), context)
            context.endPDFPage()
        }
        context.closePDF()
        return true
    }

    /// Một tệp WAV PCM im lặng, đủ hợp lệ để AVFoundation phát thật.
    ///
    /// Tự dựng thay vì kèm một tệp mẫu trong kho: tệp mẫu trong kho thì bài kiểm chạy được ở bản
    /// dựng phát triển và **bị sandbox chặn** trong bundle App Store — đúng cái bẫy đã làm ba bài
    /// Office xanh giả. Byte dựng tại chỗ thì không có đường dẫn nào để mà chặn.
    static func minimalWAV(seconds: Int) -> Data {
        let sampleRate = 8000, channels = 1, bitsPerSample = 16
        let dataBytes = sampleRate * channels * bitsPerSample / 8 * seconds
        var out = Data()
        func append(_ text: String) { out.append(contentsOf: Array(text.utf8)) }
        func append32(_ value: Int) {
            out.append(contentsOf: (0 ..< 4).map { UInt8((value >> (8 * $0)) & 0xFF) })
        }
        func append16(_ value: Int) {
            out.append(contentsOf: (0 ..< 2).map { UInt8((value >> (8 * $0)) & 0xFF) })
        }
        append("RIFF"); append32(36 + dataBytes); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(channels)
        append32(sampleRate)
        append32(sampleRate * channels * bitsPerSample / 8)      // byte mỗi giây
        append16(channels * bitsPerSample / 8)                   // khối căn chỉnh
        append16(bitsPerSample)
        append("data"); append32(dataBytes)
        out.append(Data(repeating: 0, count: dataBytes))
        return out
    }

    /// Một GIF hai khung, dựng bằng chính bộ mã hoá ảnh của hệ điều hành.
    ///
    /// Dựng bằng ImageIO chứ không gõ tay từng byte GIF: bài kiểm hỏi "bộ đọc ảnh đếm ra mấy
    /// khung", nên tệp thử phải do một bộ mã hoá THẬT sinh ra. Một chuỗi byte gõ tay mà sai một
    /// chỗ sẽ làm bài kiểm đỏ vì lý do không liên quan gì tới thứ nó đang kiểm.
    static func twoFrameGIF() -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, "com.compuserve.gif" as CFString, 2, nil
        ) else { return Data() }

        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)

        for colour in [NSColor.red, NSColor.blue] {
            let image = NSImage(size: NSSize(width: 4, height: 4))
            image.lockFocus()
            colour.setFill()
            NSRect(x: 0, y: 0, width: 4, height: 4).fill()
            image.unlockFocus()
            guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }
            CGImageDestinationAddImage(destination, cg, [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1],
            ] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { return Data() }
        return data as Data
    }

    private static func minimalCpio(_ files: [String: String]) -> Data {
        var out = Data()

        func muc(_ name: String, _ body: [UInt8], mode: Int) {
            let nameBytes = Array(name.utf8) + [0]
            var header = "070707"
            // dev · ino · mode · uid · gid · nlink · rdev — mỗi trường 6 chữ số bát phân.
            for value in [0, 0, mode, 0, 0, 1, 0] {
                header += String(format: "%06o", value)
            }
            // mtime và filesize là 11 chữ số. Để mtime = 0: kho tự kiểm không được phụ thuộc
            // vào đồng hồ, nếu không nó thành một bài kiểm khác nhau mỗi lần chạy.
            header += String(format: "%011o", 0)
            header += String(format: "%06o", nameBytes.count)
            header += String(format: "%011o", body.count)
            out.append(contentsOf: Array(header.utf8))
            out.append(contentsOf: nameBytes)
            out.append(contentsOf: body)
        }

        for (name, body) in files.sorted(by: { $0.key < $1.key }) {
            muc(name, Array(body.utf8), mode: 0o100_644)
        }
        muc("TRAILER!!!", [], mode: 0)
        return out
    }

    /// ZIP tối thiểu, mọi mục CẤT NGUYÊN — chỉ dùng cho bài tự kiểm khung xem.
    ///
    /// Xem ghi chú trong chính bài kiểm về việc vì sao dựng bằng tay ở đây là đúng, còn ở
    /// `ZipArchiveTests` thì không.
    /// Đường dẫn một tệp trong kho mã, suy từ vị trí tệp nguồn này.
    ///
    /// Bài tự kiểm chạy cả trong bundle đã ký lẫn từ `.build`, nên không suy từ `argv[0]` —
    /// `GrammarLibrary` đã một lần chết vì đúng cách ấy.
    private static func repoFile(_ relative: String) -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent(relative).path
    }

    private static func minimalZip(_ files: [String: String]) -> Data? {
        var out = Data()
        var directory = Data()
        var count = 0

        func put16(_ into: inout Data, _ v: UInt16) {
            into.append(UInt8(v & 0xFF)); into.append(UInt8((v >> 8) & 0xFF))
        }
        func put32(_ into: inout Data, _ v: UInt32) {
            for shift in stride(from: 0, to: 32, by: 8) {
                into.append(UInt8((v >> UInt32(shift)) & 0xFF))
            }
        }

        for (name, body) in files.sorted(by: { $0.key < $1.key }) {
            let nameBytes = Array(name.utf8)
            let data = Array(body.utf8)
            let crc = CRC32.compute(data)
            let offset = UInt32(out.count)

            put32(&out, 0x0403_4B50)                       // local file header
            put16(&out, 20); put16(&out, 0x0800)           // phiên bản · cờ (tên là UTF-8)
            put16(&out, 0)                                 // phương pháp: cất nguyên
            put16(&out, 0); put16(&out, 0)                 // giờ · ngày
            put32(&out, crc)
            put32(&out, UInt32(data.count)); put32(&out, UInt32(data.count))
            put16(&out, UInt16(nameBytes.count)); put16(&out, 0)
            out.append(contentsOf: nameBytes)
            out.append(contentsOf: data)

            put32(&directory, 0x0201_4B50)                 // central directory header
            put16(&directory, 20); put16(&directory, 20)
            put16(&directory, 0x0800); put16(&directory, 0)
            put16(&directory, 0); put16(&directory, 0)
            put32(&directory, crc)
            put32(&directory, UInt32(data.count)); put32(&directory, UInt32(data.count))
            put16(&directory, UInt16(nameBytes.count))
            put16(&directory, 0); put16(&directory, 0)
            put16(&directory, 0); put16(&directory, 0)
            put32(&directory, 0)
            put32(&directory, offset)
            directory.append(contentsOf: nameBytes)
            count += 1
        }

        let directoryOffset = UInt32(out.count)
        out.append(directory)
        put32(&out, 0x0605_4B50)                           // end of central directory
        put16(&out, 0); put16(&out, 0)
        put16(&out, UInt16(count)); put16(&out, UInt16(count))
        put32(&out, UInt32(directory.count)); put32(&out, directoryOffset)
        put16(&out, 0)
        return out
    }

    private static func expect(_ controller: MainWindowController, _ wanted: String) -> String? {
        let actual = controller.editorDocument.buffer.text
        guard actual != wanted else { return nil }
        return "mong đợi \(String(reflecting: wanted))\n   nhận   \(String(reflecting: actual))"
    }
}
