import AppKit
import EIDEKit
import GEditorCore

/// **Một vòng làm việc THẬT, đi qua chính giao diện** — `GEditorApp --vong-giao-dien <thư-mục>`.
///
/// ## Vì sao cần chế độ này, khi đã có `--self-test` và `--capture`
///
/// Ba thứ trả lời ba câu khác nhau:
///
/// - `--self-test` hỏi *"bất biến này còn đúng không"* — nó khẳng định, và nó dừng ở bài đầu sai.
/// - `--capture` hỏi *"màn này trông thế nào"* — nó chụp một trạng thái dựng sẵn.
/// - Chế độ này hỏi *"một người dùng đi hết một vòng thì gặp gì"* — nó KHÔNG khẳng định gì cả,
///   nó GHI LẠI: mỗi bước một dòng log có mốc thời gian, một ảnh, và kết quả thật của lời gọi.
///
/// Khác biệt quan trọng nhất nằm ở chữ "đi qua giao diện": mọi bước dưới đây gọi đúng hàm mà
/// một cú bấm chuột gọi — `chonManEide` cho sidebar, `chayNhuNguoiDung` cho nút Chạy của biểu
/// mẫu, `moTepTuCay` cho cú bấm vào tệp. Chạy cùng chuỗi ấy bằng CLI thì đo được lõi và KHÔNG đo
/// được thứ đã hỏng nhiều nhất trong dự án này: chỗ nối giữa giao diện và lõi.
///
/// ## Vòng chạy không dừng khi một bước hỏng
///
/// Đây là bản ghi cho báo cáo, không phải cổng chất lượng. Một bước hỏng được ghi là hỏng rồi đi
/// tiếp — vì thứ đáng biết là *bao nhiêu bước trong vòng này chạy được*, và dừng ở bước 3 thì
/// không ai biết bước 9 ra sao.
enum VongGiaoDien {

    /// Một bước trong vòng: tên người đọc được, và việc nó làm.
    private struct Buoc {
        let ten: String
        let lam: (MainWindowController) -> String
    }

    private static var log: [String] = []
    private static var batDau = Date()
    private static var thuMuc = URL(fileURLWithPath: ".")
    private static var soAnh = 0

    static func run(controller: MainWindowController, arguments: [String]) -> Never {
        guard let i = arguments.firstIndex(of: "--vong-giao-dien"), i + 1 < arguments.count else {
            FileHandle.standardError.write(Data("Thiếu thư mục: --vong-giao-dien <thư-mục>\n".utf8))
            exit(2)
        }
        thuMuc = URL(fileURLWithPath: arguments[i + 1])
        try? FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
        batDau = Date()

        ghi("# Một vòng EIDE qua giao diện")
        ghi("")
        ghi("Máy: \(GEditorCore.diagnosticSummary)")
        ghi("Dự án: \(ProcessInfo.processInfo.environment["EIDE_PROJECT"] ?? "(chưa đặt)")")
        ghi("")

        var dat = 0
        for (n, b) in cacBuoc.enumerated() {
            let t0 = Date()
            let kq = b.lam(controller)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            let hong = kq.hasPrefix("HỎNG")
            if !hong { dat += 1 }
            ghi("## \(n + 1). \(b.ten)")
            ghi("")
            ghi("- \(hong ? "❌" : "✅") \(kq)")
            ghi("- \(ms) ms")
            // Chiều cao cửa sổ và chiều cao Auto Layout ĐÒI. Hai số này lệch nhau nghĩa là có
            // ràng buộc nào đó đang kéo cửa sổ to ra — và một cửa sổ cao hơn màn hình là lỗi
            // người dùng gặp trước mọi lỗi khác.
            if let w = controller.window, let v = w.contentView {
                let doi = v.fittingSize.height
                ghi(String(format: "- cửa sổ %.0f pt · Auto Layout đòi %.0f pt%@",
                           w.frame.height, doi,
                           doi > w.frame.height + 1 ? "  ⚠ ĐANG KÉO CỬA SỔ TO RA" : ""))
                if doi > w.frame.height - 1 { ghi("- " + _aiDoi(v)) }
            }
            let anh = chupBuoc(controller, n + 1, b.ten)
            if let anh { ghi("- ảnh: `\(anh)`") }
            ghi("")
        }

        ghi("---")
        ghi("")
        ghi("**\(dat)/\(cacBuoc.count) bước chạy được** · tổng "
            + String(format: "%.1f", Date().timeIntervalSince(batDau)) + " s")

        let f = thuMuc.appendingPathComponent("vong-giao-dien.md")
        try? log.joined(separator: "\n").appending("\n").write(to: f, atomically: true,
                                                               encoding: .utf8)
        print("\n✅ \(dat)/\(cacBuoc.count) bước · nhật ký: \(f.path)")
        exit(dat == cacBuoc.count ? 0 : 1)
    }

    /// Ba khung nhìn đòi chiều cao nhiều nhất — để biết ai kéo cửa sổ to ra.
    ///
    /// Duyệt cây và so `fittingSize.height` của từng nút với chiều cao nó ĐANG có. Nút nào đòi
    /// nhiều hơn phần được cấp là nút đang đẩy; in ba nút đầu là đủ để đi thẳng tới chỗ sửa,
    /// thay cho ba lượt đoán như tôi vừa làm.
    private static func _aiDoi(_ goc: NSView) -> String {
        var ds: [(String, CGFloat, CGFloat)] = []
        func di(_ v: NSView, _ sau: Int) {
            guard sau < 6 else { return }
            let doi = v.fittingSize.height
            if doi > 1 { ds.append((String(describing: type(of: v)), doi, v.frame.height)) }
            for c in v.subviews { di(c, sau + 1) }
        }
        di(goc, 0)
        let top = ds.sorted { $0.1 > $1.1 }.prefix(3)
            .map { String(format: "%@ đòi %.0f (đang có %.0f)", $0.0, $0.1, $0.2) }

        // Và các CON TRỰC TIẾP của panel: chuỗi ràng buộc dọc cộng dồn ở đây, nên đây là chỗ
        // đọc ra ai đang đẩy — không phải ở nút sâu nhất có `fittingSize` lớn.
        func timPanel(_ v: NSView) -> NSView? {
            if String(describing: type(of: v)) == "EidePanel" { return v }
            for c in v.subviews { if let r = timPanel(c) { return r } }
            return nil
        }
        var con = ""
        if let pn = timPanel(goc) {
            con = "\n- con của panel: " + pn.subviews.map {
                String(format: "%@ %.0f/%.0f%@", String(describing: type(of: $0)),
                       $0.fittingSize.height, $0.frame.height, $0.isHidden ? " (ẩn)" : "")
            }.joined(separator: " · ")
        }
        return "đòi nhiều nhất: " + top.joined(separator: " · ") + con
    }

    private static func ghi(_ s: String) {
        log.append(s)
        if !s.isEmpty { print("   " + s) }
    }

    private static func chupBuoc(_ c: MainWindowController, _ n: Int, _ ten: String) -> String? {
        soAnh += 1
        let ten = String(format: "buoc-%02d.png", n)
        let u = thuMuc.appendingPathComponent(ten)
        return WindowCapture.chup(c, ra: u) ? ten : nil
    }

    /// Cho run loop chạy để giao diện kịp dựng và daemon kịp trả lời.
    private static func cho(_ giay: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(giay))
    }

    /// Kiểm kê thân màn đang mở — dùng chính phép đo của bài tự kiểm.
    private static func kiemKe(_ c: MainWindowController) -> String {
        guard let p = c.eidePanel else { return "không có panel" }
        let d = p.kiemKeManDangMo()
        let khoi = d.khoi.isEmpty ? "" : " · " + d.khoi
        return "\(d.soDong) dòng\(khoi)"
    }

    // MARK: - Vòng chạy

    private static let cacBuoc: [Buoc] = [

        Buoc(ten: "Mở dự án — cửa sổ dựng xong, cột điều hướng có mặt") { c in
            cho(3)
            guard c.coPanelEide else { return "HỎNG: không chạy được `eide daemon`" }
            let duAn = c.duAnDangMo ?? "(không rõ)"
            return "dự án `\((duAn as NSString).lastPathComponent)` · panel sẵn sàng"
        },

        Buoc(ten: "Tổng quan dự án — bấm mục đầu trên sidebar") { c in
            c.chonManEide(tien: "Main")
            cho(3)
            return kiemKe(c)
        },

        Buoc(ten: "Môi trường — máy này có gì") { c in
            c.chonManEide(tien: "Env")
            cho(4)
            return kiemKe(c)
        },

        Buoc(ten: "Nhập tài liệu — trích fact từ một header C") { c in
            c.chonManEide(tien: "Ingest")
            cho(2)
            guard let p = c.eidePanel, let goc = c.duAnDangMo else {
                return "HỎNG: chưa mở dự án"
            }
            // Dựng một header nhỏ NGAY TRONG dự án, rồi trích qua đúng đường biểu mẫu.
            let h = (goc as NSString).appendingPathComponent("include")
            try? FileManager.default.createDirectory(atPath: h, withIntermediateDirectories: true)
            let tep = (h as NSString).appendingPathComponent("soc_vong.h")
            let noi = "/* vòng chạy thử */\n#define UART0_BASE 0x60000000\n"
                + "#define SRAM_LOW  0x3FC80000\n#define SRAM_HIGH 0x3FCE0000\n"
            guard (try? noi.write(toFile: tep, atomically: true, encoding: .utf8)) != nil else {
                return "HỎNG: không ghi được header thử"
            }
            p.chayNhuNguoiDung("extract.header_c", ["file": tep, "part": "esp.esp32c3"])
            cho(5)
            return kiemKe(c)
        },

        Buoc(ten: "Hộ chiếu chip — tra fact vừa trích") { c in
            c.chonManEide(tien: "Passport")
            cho(4)
            return kiemKe(c)
        },

        Buoc(ten: "Bản đồ tri thức — đồ thị dựng từ store") { c in
            c.chonManEide(tien: "Graph")
            cho(5)
            return kiemKe(c)
        },

        Buoc(ten: "Xung đột tri thức — hai nguồn nói khác nhau") { c in
            c.chonManEide(tien: "XungDot")
            cho(4)
            return kiemKe(c)
        },

        Buoc(ten: "Mã nguồn — mở một tệp, xem dấu tri thức ở lề") { c in
            c.chonManEide(tien: "Code")
            cho(2)
            guard let goc = c.duAnDangMo else { return "HỎNG: chưa mở dự án" }
            let src = (goc as NSString).appendingPathComponent("src")
            guard let ten = (try? FileManager.default.contentsOfDirectory(atPath: src))?
                .filter({ $0.hasSuffix(".c") }).sorted().first else {
                return "HỎNG: dự án không có src/*.c"
            }
            c.moTepTuCay((src as NSString).appendingPathComponent(ten))
            cho(6)
            let d = c.editorView.dauEideDeTest()
            let fact = d.values.filter { if case .coFact = $0 { return true }; return false }.count
            let vp = d.values.count - fact
            return "\(ten) · \(fact) dòng có fact · \(vp) dòng vi phạm constant-guard"
        },

        Buoc(ten: "Mô phỏng — chạy firmware thật nếu dự án có") { c in
            c.chonManEide(tien: "Sim")
            cho(2)
            guard let p = c.eidePanel, let goc = c.duAnDangMo else {
                return "HỎNG: chưa mở dự án"
            }
            let elf = (goc as NSString).appendingPathComponent("build/fw.elf")
            let thuMucSim = (goc as NSString).appendingPathComponent("sim")
            let kb = (try? FileManager.default.contentsOfDirectory(atPath: thuMucSim))?
                .filter { $0.hasSuffix(".yaml") }.sorted().first
            guard FileManager.default.fileExists(atPath: elf), let kb else {
                return "bỏ qua — dự án chưa có build/fw.elf và sim/*.yaml"
            }
            p.chayNhuNguoiDung("sim.run", ["artifact": elf,
                                           "scenario": (thuMucSim as NSString)
                                               .appendingPathComponent(kb)])
            cho(90)
            return kiemKe(c)
        },

        Buoc(ten: "Ô LỆNH gõ được NGAY TRÊN một màn chuyên đề") { c in
            guard let p = c.eidePanel else { return "HỎNG: chưa có panel" }
            // KHÔNG đóng màn. USECASE UC-B1: "một ô lệnh luôn gõ được, không phải một màn" —
            // nên bài này mở màn Hộ chiếu rồi gõ NGAY TẠI ĐÓ.
            c.chonManEide(tien: "Passport")
            cho(3)
            guard p.oLenhGoDuocDeTest else {
                return "HỎNG: mở một màn thì ô lệnh biến mất — muốn nói một câu phải bỏ màn"
            }
            p.goNhuNguoiDung("cho tôi biết chip này có bao nhiêu RAM")
            cho(40)
            let l1 = p.soLuotHoiThoaiDeTest
            guard l1 >= 2 else { return "HỎNG: gõ trên màn chuyên đề mà không ai trả lời" }
            p.dongManChuyenDe()
            cho(1)
            p.goNhuNguoiDung("đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART mỗi giây")
            cho(45)
            let luot = p.soLuotHoiThoaiDeTest
            return luot >= 3 ? "gõ được CẢ trên màn chuyên đề lẫn ở hội thoại · \(luot) lượt"
                             : "HỎNG: gõ xong không thấy tác tử trả lời (\(luot) lượt)"
        },

        Buoc(ten: "Tác tử tự MỞ và FOCUS đúng màn của việc nó đang làm") { c in
            guard let p = c.eidePanel else { return "HỎNG: chưa có panel" }
            // Đứng ở một màn KHÔNG liên quan, rồi bảo tác tử chạy một năng lực của màn khác.
            c.chonManEide(tien: "Env")
            cho(3)
            let truoc = p.tenManDangMo ?? "(hội thoại)"
            // Chờ qua thời gian giữ màn của người dùng — nếu không, tác tử cố ý KHÔNG cướp màn.
            cho(EidePanel.GIU_MAN_NGUOI_CHON + 1)
            p.chayNhuNguoiDung("passport.query", ["part": "atmega328p"])
            cho(12)
            let sau = p.tenManDangMo ?? "(hội thoại)"
            return sau == "Passport"
                ? "đang ở `\(truoc)` → tác tử chạy `passport.query` → tự mở `\(sau)`"
                : "HỎNG: tác tử chạy `passport.query` mà màn vẫn là `\(sau)`"
        },

        Buoc(ten: "BA ĐIỀU KIỆN: tác tử sửa mã → mở màn mã, mà hội thoại VẪN hiện") { c in
            guard let p = c.eidePanel, let goc = c.duAnDangMo else {
                return "HỎNG: chưa mở dự án"
            }
            c.chonManEide(tien: "Env")
            cho(2)
            cho(EidePanel.GIU_MAN_NGUOI_CHON + 1)

            let src = (goc as NSString).appendingPathComponent("src")
            guard let ten = (try? FileManager.default.contentsOfDirectory(atPath: src))?
                .filter({ $0.hasSuffix(".c") }).sorted().first,
                let noi = try? String(contentsOfFile:
                    (src as NSString).appendingPathComponent(ten), encoding: .utf8) else {
                return "HỎNG: dự án không có src/*.c"
            }
            // Tác tử "sửa mã": chạy một năng lực `code.*` — đúng ví dụ chủ sản phẩm đưa.
            p.chayNhuNguoiDung("code.constant_guard",
                               ["patch": ["files": [["path": "src/" + ten, "content": noi,
                                                     "mode": "replace"]],
                                          "cites": [], "rationale": "vòng chạy"]])
            cho(12)

            let man = p.tenManDangMo ?? "(hội thoại)"
            let hoiThoaiHien = p.oLenhGoDuocDeTest
            var loi: [String] = []
            if man != "Code" { loi.append("tác tử chạy `code.*` mà màn là `\(man)`") }
            if !hoiThoaiHien { loi.append("HỘI THOẠI BIẾN MẤT — vi phạm điều kiện bất biến") }
            return loi.isEmpty
                ? "mở màn `\(man)` · hội thoại vẫn hiện"
                : "HỎNG: " + loi.joined(separator: " · ")
        },

        Buoc(ten: "Nhật ký — mọi việc vừa làm có vào sổ cái không") { c in
            c.chonManEide(tien: "NhatKy")
            cho(5)
            return kiemKe(c)
        },

        Buoc(ten: "Mô hình & chi phí — tiêu bao nhiêu trong vòng này") { c in
            c.chonManEide(tien: "Models")
            cho(4)
            return kiemKe(c)
        },

        Buoc(ten: "Hành trình & cổng — chính sách đã quyết những gì") { c in
            c.chonManEide(tien: "FlowMap")
            cho(4)
            return kiemKe(c)
        },

        Buoc(ten: "BẢNG LỆNH ⌘K: tìm được năng lực bằng chữ KHÔNG DẤU") { c in
            let (tong, n) = c.eideMoBangLenh()
            guard tong > 200 else {
                return "HỎNG: bảng lệnh chỉ thấy \(tong) mục — phải thấy cả registry lẫn màn"
            }
            return n > 0
                ? "✅ \(tong) mục · gõ \"ho chieu\" (không dấu) ra \(n) kết quả"
                : "HỎNG: gõ không dấu không ra kết quả nào"
        },

        // ĐẶT CUỐI vì nó phá hỏng daemon: mọi bước sau đây sẽ không có gì để nói.
        //
        // Bài kiểm B6/N6 của UXC-31, và là bài kiểm PHỦ ĐỊNH duy nhất của vòng này: nó khẳng
        // định giao diện KHÔNG im lặng khi mất nguồn dữ liệu. Trước 17/09/2026 kênh sự kiện chỉ
        // được bơm trong lúc có một lời gọi đang chạy, nên khi người ngồi yên thì cửa sổ điếc
        // hoàn toàn — và điếc mà không biết mình điếc là hình dạng gốc của mọi lỗi im lặng.
        Buoc(ten: "MẤT DAEMON: màn hình có NÓI RA rằng dữ liệu đã cũ không") { c in
            guard c.coPanelEide else { return "HỎNG: không có panel để đo" }
            if c.eideDangBaoDuLieuCu { return "HỎNG: đang báo dữ liệu cũ TRƯỚC khi giết daemon" }
            c.eideGietDaemonDeTest()
            cho(5)          // hạn N6 là 2 s; chờ rộng hơn để không phụ thuộc nhịp máy
            return c.eideDangBaoDuLieuCu
                ? "✅ daemon chết → dải \"Dữ liệu cũ\" hiện ra"
                : "HỎNG: daemon chết mà màn hình vẫn hiện dữ liệu cũ như thật"
        },
    ]
}
