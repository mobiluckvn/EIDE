import AppKit
import EideGiaoDien
import EideLoi

/// Điểm vào của bản EIDE mới.
///
/// Cửa sổ mở ở ĐÚNG cỡ bản demo được xem (1456×838), đặt tường minh chứ không để ràng buộc
/// quyết. Bản cũ chưa bao giờ đặt cỡ cửa sổ: nó cao 720 rồi 818 pt vì chuỗi ràng buộc cứng của
/// panel làm `fittingSize` lớn hơn cửa sổ và AppKit phóng to cửa sổ cho vừa — một con số là TÁC
/// DỤNG PHỤ của bố cục, nhích dần lên mà không bao giờ co lại.
@MainActor
final class UngDung: NSObject, NSApplicationDelegate {

    var cuaSo: NSWindow!
    var khung: EideKhung!
    var phien: EidePhien!

    func applicationDidFinishLaunching(_ n: Notification) {
        khung = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        cuaSo = NSWindow(contentRect: khung.frame,
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        cuaSo.title = "EIDE"
        cuaSo.contentView = khung
        cuaSo.center()

        phien = EidePhien(khung: khung)
        _dungMenu()

        // `--chup <thư-mục>`: dựng cửa sổ, chụp, thoát. Để so ảnh với bản demo mà không cần
        // người ngồi trước máy.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--chup"), i + 1 < args.count {
            let thuMuc = URL(fileURLWithPath: args[i + 1])
            try? FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
            cuaSo.makeKeyAndOrderFront(nil)
            khung.layoutSubtreeIfNeeded()
            // Chụp HAI ảnh: màn chào trước khi quét workspace, rồi khung đầy đủ sau khi daemon
            // trả lời. Một ảnh duy nhất luôn bỏ mất một trong hai trạng thái, và màn chào là
            // trạng thái người dùng mới gặp trước nhất.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self._chup(thuMuc.appendingPathComponent("chao.png"))
                Task {
                    await self.phien.khoiDong()
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    self.khung.layoutSubtreeIfNeeded()
                    self._chup(thuMuc.appendingPathComponent("khung.png"))
                    // Rồi một màn CÓ DỮ LIỆU: ảnh của khung rỗng không nói được gì về cách một
                    // bảng thật nằm trong đó.
                    for tien in ["Main", "ChinhSach", "NhatKy", "Passport"] {
                        let t0 = ProcessInfo.processInfo.systemUptime
                        self.phien.moMan(tien, boiTacTu: false)
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        while self._chuTrong(self.khung.vungLamViec).contains("Đang đọc…"),
                              ProcessInfo.processInfo.systemUptime - t0 < 10 {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                        }
                        let m = self.khung.vungLamViec.manDangMo
                        print(String(format: "  %@ hiện xong sau %.2f s (lõi %.0f ms, vẽ %.0f ms)",
                                     tien, ProcessInfo.processInfo.systemUptime - t0,
                                     m?.msGoi ?? 0, (m?.msTong ?? 0) - (m?.msGoi ?? 0)))
                        self.khung.layoutSubtreeIfNeeded()
                        self._chup(thuMuc.appendingPathComponent("man-\(tien).png"))
                    }
                    // Thẻ Run trên cửa sổ thật. Bơm đúng những bản ghi `chat.py` ghi ra —
                    // `chat.send` đi qua mô hình, tức qua mạng và qua tiền, nên nó không nằm
                    // trong một đường chụp ảnh.
                    self.phien.napSuKien("event.run.progress", [
                        "kind": "run.started", "run_id": "demo", "n": 7,
                        "text": "đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART",
                        "steps": [["id": "n1", "cap": "passport.query"],
                                  ["id": "n2", "cap": "extract.header_c"],
                                  ["id": "n3", "cap": "code.write"],
                                  ["id": "n4", "cap": "code.build"],
                                  ["id": "n5", "cap": "sim.run"],
                                  ["id": "n6", "cap": "code.merge"]]])
                    self.khung.layoutSubtreeIfNeeded(); self._co("sau run.started")
                    for i in 1...3 {
                        self.phien.napSuKien("event.run.progress",
                            ["kind": "run.step_done", "run_id": "demo", "cap": "b\(i)",
                             "i": i, "of": 6, "status": "done"])
                    }
                    self.khung.layoutSubtreeIfNeeded(); self._co("sau 3 step_done")
                    self.phien.napSuKien("event.run.progress",
                        ["kind": "run.step_started", "run_id": "demo",
                         "cap": "code.build", "i": 4, "of": 6])
                    self.khung.layoutSubtreeIfNeeded(); self._co("sau step_started")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.khung.layoutSubtreeIfNeeded()
                    self._chup(thuMuc.appendingPathComponent("the-run.png"))

                    self.khung.bangLenh.mo()
                    _ = self.khung.bangLenh.locDeTest("ho chieu")
                    self.khung.layoutSubtreeIfNeeded()
                    self._chup(thuMuc.appendingPathComponent("bang-lenh.png"))
                    exit(0)
                }
            }
            return
        }
        cuaSo.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // `--tu-kiem`: dựng một dự án DÙNG MỘT LẦN trong thư mục tạm rồi lái phiên qua từng
        // bước, in ra từng phép đo. Không chạm vào workspace thật của người dùng — bài tự kiểm
        // của bản cũ từng cài cờ dừng khẩn lên dự án đang làm dở và không ai biết vì sao hôm sau
        // tác tử ngồi im.
        if args.contains("--tu-kiem") {
            Task { await self._tuKiem() }
            return
        }
        Task { await phien.khoiDong() }
    }

    private func _chuTrong(_ v: NSView) -> String {
        var ra = (v as? NSTextField)?.stringValue ?? ""
        for c in v.subviews { ra += "\n" + _chuTrong(c) }
        return ra
    }

    /// Màn PHẢI có dữ liệu ngay trên một dự án vừa tạo: phiên, sổ cái và bảng quy tắc đều ra
    /// đời cùng dự án. Mọi màn khác đứng trên tri thức hoặc mã mà dự án mới chưa có.
    static let CAN_DU_LIEU: Set<String> = ["Main", "NhatKy", "ChinhSach"]

    private func _tuKiem() async {
        var dat = 0, hong = 0
        func do_(_ ten: String, _ dung: Bool, _ them: String = "") {
            if dung { dat += 1; print("  ĐẠT  \(ten)") }
            else { hong += 1; print("  HỎNG \(ten) \(them)") }
        }
        let tam = NSTemporaryDirectory() + "eide-tu-kiem-\(ProcessInfo.processInfo.processIdentifier)"
        print("Workspace tạm: \(tam)")

        do_("1. chưa có dự án thì màn chào phủ toàn cửa sổ", khung.dangChao)
        await phien.taoDuAn("nhấp nháy LED trên ATmega328P", thuMuc: tam)
        do_("2. tạo xong thì màn chào biến mất", !khung.dangChao)
        do_("3. thanh trên mang tên dự án", khung.thanhTren.tenDuAn.contains("nhap-nhay-led"),
            "(\(khung.thanhTren.tenDuAn))")
        do_("4. registry nạp được ≥ 200 năng lực", phien.soNangLuc >= 200, "(\(phien.soNangLuc))")

        phien.moMan("FlowMap", boiTacTu: false)
        do_("5. mở màn thì tab mở theo", khung.thanhTab.tab.contains("FlowMap"))
        do_("6. vùng làm việc đổi sang màn ấy", khung.vungLamViec.dangMo == "FlowMap",
            "(\(khung.vungLamViec.dangMo ?? "nil"))")
        phien.moMan("S3", boiTacTu: false)
        do_("6b. tiền tố lạ KHÔNG mở được màn nào", khung.vungLamViec.dangMo == "FlowMap")

        for tien in EidePhien.MAN.keys.sorted() {
            // Đo THỜI GIAN mở màn, không chỉ nội dung. Bản đầu của bảng dựng 480 khung nhìn cho
            // 120 hàng và mất hơn một giây — một màn trắng hơn một giây là một màn người dùng
            // cho là hỏng, mà không phép kiểm nội dung nào bắt được.
            let t0 = ProcessInfo.processInfo.systemUptime
            phien.moMan(tien, boiTacTu: false)
            try? await Task.sleep(nanoseconds: 700_000_000)
            while _chuTrong(khung.vungLamViec).contains("Đang đọc…"),
                  ProcessInfo.processInfo.systemUptime - t0 < 8 {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            let giay = ProcessInfo.processInfo.systemUptime - t0
            do_("6d. màn \(tien) hiện xong dưới 2 giây", giay < 2.0, String(format: "(%.2f s)", giay))
            let van = _chuTrong(khung.vungLamViec)
            let lyDo = van.split(separator: "\n")
                .filter { $0.contains("rỗng") || $0.contains("Bước kế tiếp") }
                .joined(separator: " | ")
            // Một dự án vừa tạo KHÔNG có tri thức nào, nên màn Hộ chiếu chip đúng ra phải rỗng
            // ở đây. Bắt nó có dữ liệu là bắt nó nói dối. Nhưng "rỗng" cũng không được là một
            // lối thoát: phép kiểm đòi trạng thái rỗng ĐÚNG HAI PHẦN (B5) — vì gì, và bước kế
            // tiếp là gì — nên một màn hỏng im lặng vẫn trượt.
            //
            // Ba màn trong `CAN_DU_LIEU` thì khác: phiên, sổ cái và bảng quy tắc có mặt từ lúc
            // dự án ra đời, nên rỗng ở đó là hỏng thật.
            if van.contains("Màn này đang rỗng"), !Self.CAN_DU_LIEU.contains(tien) {
                do_("6c. màn \(tien) rỗng CÓ LÝ DO và có bước kế tiếp",
                    van.contains("vì:") && van.contains("Bước kế tiếp"), "(\(lyDo))")
                print("       └ \(lyDo)")
            } else {
                do_("6c. màn \(tien) nạp được dữ liệu thật",
                    !van.contains("Màn này đang rỗng") && !van.contains("Đang đọc…"), "(\(lyDo))")
            }
        }

        await phien._lamMoi()
        let mucTruoc = khung.thanhTren.mucHienTai
        do_("7. mức tự chủ đọc được từ daemon", mucTruoc.contains("A"), "(\(mucTruoc))")

        await phien.dungKhan()
        await phien._lamMoi()
        do_("8. dừng khẩn hiện ra ở thanh trên, không núp sau mức tự chủ",
            khung.thanhTren.mucHienTai.contains("DỪNG"), "(\(khung.thanhTren.mucHienTai))")

        phien.moMan("ChinhSach", boiTacTu: false)
        try? await Task.sleep(nanoseconds: 900_000_000)
        let sauDung = _chuTrong(khung.vungLamViec)
        do_("8b. sau dừng khẩn, màn nói bị CHẶN chứ không nói \"không có dữ liệu\"",
            sauDung.contains("dừng khẩn") || sauDung.contains("cổng chính sách"),
            "(\(sauDung.split(separator: "\n").filter { $0.contains("vì:") }.joined()))")

        // Thẻ Run, rồi phép đo quan trọng nhất của cả bài: CỬA SỔ KHÔNG ĐƯỢC PHÌNH.
        // NSWindow coi ràng buộc bắt buộc trong `contentView` là ràng buộc của chính cửa sổ, nên
        // một nhãn đòi bề rộng ở bất kỳ đâu trong cây khung nhìn đều đẩy cửa sổ rộng ra và nó
        // không co lại. Cửa sổ bản cũ nhích 720 → 818 pt suốt nhiều ngày vì đúng cơ chế này.
        phien.napSuKien("event.run.progress", [
            "kind": "run.started", "run_id": "kiem", "text": String(repeating: "câu lệnh dài ", count: 12),
            "steps": [["cap": "code.write"], ["cap": "code.build"], ["cap": "sim.run"]]])
        phien.napSuKien("event.run.progress",
                        ["kind": "run.step_started", "run_id": "kiem", "cap": "code.build",
                         "i": 2, "of": 3])
        khung.layoutSubtreeIfNeeded()
        do_("10. thẻ Run hiện ra trong vùng trao đổi",
            _chuTrong(khung.dock).contains("bước 2/3"))
        do_("11. cửa sổ KHÔNG phình ra vì nội dung", khung.frame.width == 1456,
            String(format: "(%.0f pt)", khung.frame.width))

        phien.napSuKien("event.run.progress",
                        ["kind": "cap.run.start", "run_id": "le", "cap": "plane.hello"])
        khung.layoutSubtreeIfNeeded()
        do_("12. lời gọi năng lực ĐƠN LẺ không sinh thẻ Run",
            !_chuTrong(khung.dock).contains("đang lập kế hoạch"))

        khung.bangLenh.mo()
        let kq = khung.bangLenh.locDeTest("ho chieu")
        do_("13. bảng lệnh nạp cả màn lẫn năng lực từ registry",
            khung.bangLenh.soMuc > 200, "(\(khung.bangLenh.soMuc) mục)")
        do_("14. gõ KHÔNG DẤU vẫn ra màn Hộ chiếu chip",
            kq.contains { $0.ma == "Passport" }, "(\(kq.count) kết quả)")
        khung.bangLenh.dong()

        khung.datDuLieuCu(true, tre: 9)
        khung.layoutSubtreeIfNeeded()
        do_("9. dải Dữ liệu cũ nói rõ trễ bao lâu", khung.chuDaiCu.contains("9 giây"),
            "(\(khung.chuDaiCu))")

        try? FileManager.default.removeItem(atPath: tam)
        print("\nĐẠT \(dat)/\(dat + hong)")
        exit(hong == 0 ? 0 : 1)
    }

    /// In cỡ cửa sổ sau mỗi bước. Cửa sổ phình ra là lỗi ÂM THẦM: ảnh vẫn đẹp, mọi vùng vẫn
    /// đúng tỉ lệ, chỉ là người dùng thấy một cửa sổ tự lớn lên và không co lại.
    /// Menu thật, không phải bộ bắt phím.
    ///
    /// `NSEvent.addLocalMonitorForEvents` cũng bắt được ⌘K và ngắn hơn ba lần, nhưng phím tắt ấy
    /// sẽ KHÔNG xuất hiện ở đâu cả: thanh menu là chỗ duy nhất trên macOS mà người dùng tra được
    /// một ứng dụng có những lệnh gì. Thanh trên đã quảng cáo "⌘K · bảng lệnh"; quảng cáo một
    /// phím tắt rồi giấu nó khỏi menu là nửa vời.
    private func _dungMenu() {
        let goc = NSMenu()

        let ungDung = NSMenuItem()
        ungDung.submenu = NSMenu(title: "EIDE")
        ungDung.submenu?.addItem(withTitle: "Thoát EIDE", action: #selector(NSApplication.terminate(_:)),
                                 keyEquivalent: "q")
        goc.addItem(ungDung)

        let lenh = NSMenuItem()
        lenh.submenu = NSMenu(title: "Lệnh")
        let k = NSMenuItem(title: "Bảng lệnh…", action: #selector(_moBangLenh), keyEquivalent: "k")
        k.target = self
        lenh.submenu?.addItem(k)
        let dung = NSMenuItem(title: "Dừng khẩn", action: #selector(_dungKhan), keyEquivalent: ".")
        dung.keyEquivalentModifierMask = [.command, .shift]
        dung.target = self
        lenh.submenu?.addItem(dung)
        goc.addItem(lenh)

        NSApp.mainMenu = goc
    }

    @objc private func _moBangLenh() { khung.bangLenh.mo() }
    @objc private func _dungKhan() { Task { await phien.dungKhan() } }

    private func _co(_ nhan: String) {
        print(String(format: "  [cỡ] %-16@ %.0f × %.0f", nhan as NSString,
                     khung.frame.width, khung.frame.height))
    }

    private func _chup(_ url: URL) {
        _co((url.lastPathComponent as NSString).deletingPathExtension)
        guard let v = cuaSo.contentView,
              let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("đã chụp \(url.path)")
    }
}

let app = NSApplication.shared
// `MainActor.assumeIsolated`: mã cấp tệp chạy nonisolated, còn `UngDung` là @MainActor vì nó chỉ
// đụng AppKit. Ở đây ta ĐANG ở luồng chính — nói ra điều đó thay vì nới lỏng lớp uỷ nhiệm.
let uy = MainActor.assumeIsolated { UngDung() }
app.delegate = uy
app.setActivationPolicy(.regular)
app.run()
