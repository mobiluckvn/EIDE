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
        // §2.2 — cỡ tối thiểu. Dưới 1100 × 700 thì năm vùng chen nhau tới mức vùng làm việc
        // không còn đọc được, và cửa sổ nhỏ hơn thứ nó cần là cửa sổ người dùng tưởng mình dùng
        // được rồi kết luận sản phẩm chật chội.
        cuaSo.contentMinSize = EideKhung.CO_TOI_THIEU
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
                    // Cửa sổ ở đúng cỡ TỐI THIỂU — §2.2. Dải icon 44 pt chỉ hiện ra ở đây, và nó
                    // là thứ duy nhất trong §2 mà một bài kiểm đọc số không thay được con mắt:
                    // "44 pt" đúng không có nghĩa là ba con số trong đó còn đọc được.
                    self.cuaSo.setContentSize(EideKhung.CO_TOI_THIEU)
                    self.khung.layoutSubtreeIfNeeded()
                    self._chup(thuMuc.appendingPathComponent("khung-toi-thieu.png"))
                    self.cuaSo.setContentSize(NSSize(width: 1456, height: 838))
                    self.khung.layoutSubtreeIfNeeded()
                    // Rồi một màn CÓ DỮ LIỆU: ảnh của khung rỗng không nói được gì về cách một
                    // bảng thật nằm trong đó.
                    for tien in ["Main", "ChinhSach", "NhatKy", "Passport", "XungDot", "Ingest", "Graph", "Board", "LamRo", "ReqArch", "DiagramView", "PlanDiff", "Doc", "Code", "DiffMerge", "Env", "Models", "ToolForge", "Registry", "FlowMap", "Sim"] {
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
                    self.khung.bangLenh.dong()

                    // Form tham số §4.4 và toast §4.3 trên cửa sổ thật. Hai lớp phủ này là chỗ
                    // duy nhất trong §4 mà một bài kiểm đọc chuỗi không thay được con mắt: nhãn
                    // đúng không có nghĩa là hộp vừa, và một ô nhập tràn ra ngoài hộp thì người
                    // dùng gõ vào một chỗ họ không thấy.
                    await self.phien.goiNangLuc("kg.neighborhood")
                    self.khung.layoutSubtreeIfNeeded()
                    self._chup(thuMuc.appendingPathComponent("form-tham-so.png"))
                    self.khung.formThamSo.dong()

                    self.khung.toast.hien(
                        ["decision": "REJECT", "gate": "G-FACT", "rule": "FACT-03",
                         "reason": "hằng số 0x40000000 không trỏ về fact nào đã duyệt"],
                        cap: "code.merge")
                    self.khung.layoutSubtreeIfNeeded()
                    self._chup(thuMuc.appendingPathComponent("toast-cong.png"))
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
        // `--du-an <đường dẫn>`: mở thẳng một dự án có sẵn. Không có cờ này thì phiên khởi
        // động ở màn chào và người phải tự chọn — đúng cho dùng thật, nhưng không dùng được
        // khi cần mở đúng một dự án để xem hoặc để trình bày.
        if let i = args.firstIndex(of: "--du-an"), i + 1 < args.count {
            let d = NSString(string: args[i + 1]).expandingTildeInPath
            Task { @MainActor in await self.phien.moDuAn(d) }
        }
        // `--do-nut <đường dẫn dự án>`: mở LẦN LƯỢT mọi màn và dò nút chết. Trả mã thoát khác
        // 0 nếu có nút nào không nối vào đâu — để `make check` dùng được.
        if let i = args.firstIndex(of: "--do-nut"), i + 1 < args.count {
            let d = NSString(string: args[i + 1]).expandingTildeInPath
            Task { @MainActor in await self._doNut(d) }
            return
        }
        // `--bam-thu <dự án>`: BẤM THẬT từng nút rồi so màn hình trước/sau. Một nút có nối
        // nhưng bấm xong không đổi gì là một nút chết theo nghĩa người dùng.
        // `--do-noi-dung <dự án>`: mở từng màn và hỏi MỘT câu khác hẳn hai bộ dò kia —
        // "màn này có hiện thứ nó phải hiện không". Xem `EideDoNoiDung`.
        if let i = args.firstIndex(of: "--do-noi-dung"), i + 1 < args.count {
            let d = NSString(string: args[i + 1]).expandingTildeInPath
            Task { @MainActor in await self._doNoiDung(d) }
            return
        }
        if let i = args.firstIndex(of: "--bam-thu"), i + 1 < args.count {
            let d = NSString(string: args[i + 1]).expandingTildeInPath
            Task { @MainActor in await self._bamThu(d) }
            return
        }
        if args.contains("--tu-kiem") {
            Task { await self._tuKiem() }
            return
        }
        // `--kich-ban <tệp> [--ra <thư mục>]`: chạy một PHIÊN thật qua đường giao diện, chụp
        // ảnh và ghi nhật ký từng bước. Xem `KichBan.swift`.
        if let i = args.firstIndex(of: "--kich-ban"), i + 1 < args.count {
            let ra = (args.firstIndex(of: "--ra").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil })
                ?? NSTemporaryDirectory() + "eide-kich-ban"
            Task { await KichBan.chay(self, tep: args[i + 1], ra: URL(fileURLWithPath: ra)) }
            return
        }
        Task { await phien.khoiDong() }
    }

    /// Bản tĩnh của `_chuTrong` — dùng được từ chỗ gọi tĩnh.
    ///
    /// **Đọc cả NHÃN NÚT.** [DEV-183] Bản đầu chỉ đọc `NSTextField`/`NSTextView`, nên mọi thứ
    /// màn hình nói bằng nút đều VÔ HÌNH với phép đo. Đo 22/09/2026: màn Bản đồ luồng vẽ tám
    /// pha P0–P7 thành tám nút — bộ dò báo "CHƯA DỰNG 3/3" cho một màn đang hiện đủ cả tám,
    /// và nếu tin vào đó thì việc tiếp theo là đi viết lại một màn không hỏng.
    ///
    /// `_chuTrong` (bản instance) đã đọc nút từ trước, và chính chỗ lệch giữa hai hàm đo cùng
    /// một thứ là nguồn của lỗi này.
    static func chuTrongTinh(_ v: NSView) -> String {
        var ra = ""
        if let t = v as? NSTextField {
            ra += (t.attributedStringValue.string.isEmpty ? t.stringValue
                                                          : t.attributedStringValue.string) + " "
            ra += (t.placeholderString ?? "") + " "
        }
        if let t = v as? NSTextView { ra += t.string + " " }
        if let b = v as? NSButton {
            ra += (b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string) + " "
        }
        for c in v.subviews { ra += chuTrongTinh(c) }
        return ra
    }

    /// Mọi chữ NGƯỜI ĐỌC ĐƯỢC trong một cây khung nhìn.
    ///
    /// Gồm cả `placeholderString` và tiêu đề nút, không chỉ `stringValue`. Bản đầu chỉ đọc
    /// `stringValue` nên nó mù với hai phần trong ba phần của popover §2A.2 — ô lọc là một
    /// placeholder, "Dự án mới" là một tiêu đề nút — và bài kiểm báo HỎNG cho một popover dựng
    /// đúng. Một hàm đo mù một nửa màn hình thì nó nói sai cả hai chiều.
    private func _chuTrong(_ v: NSView) -> String {
        var ra = ""
        if let t = v as? NSTextField {
            ra += (t.attributedStringValue.string.isEmpty ? t.stringValue
                                                          : t.attributedStringValue.string)
            ra += " " + (t.placeholderString ?? "")
        }
        if let b = v as? NSButton {
            ra += " " + (b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string)
        }
        for c in v.subviews { ra += "\n" + _chuTrong(c) }
        return ra
    }

    /// Màn PHẢI có dữ liệu ngay trên một dự án vừa tạo: phiên, sổ cái và bảng quy tắc đều ra
    /// đời cùng dự án. Mọi màn khác đứng trên tri thức hoặc mã mà dự án mới chưa có.
    static let CAN_DU_LIEU: Set<String> = ["Main", "NhatKy", "ChinhSach"]

    /// Mở mọi màn rồi dò nút chết — `--do-nut <dự án>`.
    ///
    /// Mở THẬT từng màn thay vì dựng từng lớp màn rời: một nút chỉ chết khi nó nằm trong cây
    /// khung nhìn đã dựng xong với dữ liệu thật, và phần lớn nút của sản phẩm này chỉ ra đời
    /// khi có dữ liệu để bấm.
    private func _doNut(_ duAn: String) async {
        await phien.moDuAn(duAn)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        var tong = 0
        // Vùng trao đổi và thanh trên luôn có mặt — dò trước, một lần.
        for (ten, v) in [("VÙNG TRAO ĐỔI", khung.dock as NSView),
                         ("THANH TRÊN", khung.thanhTren as NSView),
                         ("CỘT TRÁI", khung.cotTrai as NSView),
                         ("CỘT PHẢI", khung.cotPhai as NSView)] {
            let ds = EideDoNutChet.do_(v, ten: ten)
            if !ds.isEmpty { print("\n\(ten): \(ds.count) nút chết\n\(EideDoNutChet.baoCao(ds))") }
            tong += ds.count
        }
        for m in EideManHinhDS.tatCa {
            _ = phien.moMan(m.tien, boiTacTu: false)
            try? await Task.sleep(nanoseconds: 700_000_000)
            khung.layoutSubtreeIfNeeded()
            let ds = EideDoNutChet.do_(khung.vungLamViec, ten: "MÀN \(m.tien)")
            if !ds.isEmpty {
                print("\nMÀN \(m.tien) (\(m.nhan)): \(ds.count) nút chết")
                print(EideDoNutChet.baoCao(ds))
            }
            tong += ds.count
        }
        print("\n=== TỔNG: \(tong) nút chết trên \(EideManHinhDS.tatCa.count) màn + 4 vùng")
        exit(tong == 0 ? 0 : 1)
    }

    /// Mở từng màn rồi so chữ hiển thị với hợp đồng nội dung — `--do-noi-dung <dự án>`.
    /// Câu LÝ DO của trạng thái rỗng, nếu màn đang rỗng. [DEV-183]
    ///
    /// Luật B5 bắt mọi trạng thái rỗng nói lý do, và chính câu ấy là thứ phân biệt "dự án chưa
    /// có hiện vật loại này" với "không nối được daemon nên màn nào cũng rỗng". Không in nó ra
    /// thì hai tình huống ấy trông y hệt nhau trong báo cáo — và cái thứ hai là một sản phẩm
    /// hỏng hoàn toàn đang được báo cáo là "không đo được".
    static func lyDoRong(_ van: String) -> String? {
        let moc = "Màn này đang rỗng — vì:"
        guard let r = van.range(of: moc) else { return nil }
        return van[r.upperBound...]
            .prefix(while: { $0 != "\n" })
            .trimmingCharacters(in: .whitespaces)
    }

    /// Câu lý do rỗng này nói màn HỎNG hay nói dự án chưa có dữ liệu?
    ///
    /// Bắt theo mã lỗi `E….` và theo cụm "không đọc được" — hai thứ mọi màn đều dùng khi lời
    /// gọi năng lực ném. Danh sách phải hẹp: bắt rộng quá thì một câu rỗng bình thường có chữ
    /// "không" bị gọi là hỏng, và cổng đỏ vì phép đo chứ không vì sản phẩm.
    static func laLoi(_ ly: String) -> Bool {
        if ly.contains("không đọc được") { return true }
        // `E6003`, `E2000`… — chữ E rồi bốn chữ số.
        let k = Array(ly)
        for i in 0..<max(0, k.count - 4) where k[i] == "E" {
            if k[(i + 1)...(i + 4)].allSatisfy({ $0.isNumber }) { return true }
        }
        return false
    }

    /// Chờ màn nạp xong — dùng chung cho `--do-noi-dung` và `--bam-thu`.
    ///
    /// Mốc "xong" là lúc chữ "Đang đọc…" biến mất. Trần 12 giây rồi đi tiếp: một màn treo phải
    /// hiện ra thành một mục CHƯA DỰNG, không được treo cả phép đo.
    private func _choNapXong() async {
        let t0 = ProcessInfo.processInfo.systemUptime
        while _chuTrong(khung.vungLamViec).contains("Đang đọc…"),
              ProcessInfo.processInfo.systemUptime - t0 < 12 {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        khung.layoutSubtreeIfNeeded()
    }

    private func _doNoiDung(_ duAn: String) async {
        let goc = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        guard let hd = EideDoNoiDung.hopDong(goc) else {
            print("✖ chưa có docs/spec/ui/man_can_hien.json — chạy "
                  + "`python scripts/gen_man_can_hien.py` trước")
            exit(2)
        }
        await phien.moDuAn(duAn)
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        var thieu = 0, du = 0, khongMan = 0, khongDo = 0
        var manRong: [String] = []
        for m in EideManHinhDS.tatCa {
            guard let can = hd[m.tien] else { continue }
            // MÀN KHÔNG DỰNG ĐƯỢC là một thất bại, không phải một màn rỗng.
            //
            // Hỏi `EidePhien.MAN` chứ KHÔNG hỏi giá trị trả về của `moMan`: hàm ấy chỉ canh
            // danh sách MENU (`EideManHinhDS`), nên bốn mục có trong menu mà không có lớp màn
            // vẫn được nó trả `true` — nó mở tab, xoá badge, rồi đặt một vùng làm việc trống.
            // Đó đúng là chỗ `--do-nut` mù: đếm nút trên vùng trống thì "0 nút chết".
            guard EidePhien.MAN[m.tien] != nil else {
                print("\n✖ \(can.ma) \(m.nhan) — KHÔNG CÓ MÀN: có trong menu cột trái, "
                      + "không có lớp nào trong EidePhien.MAN; bấm vào mở ra vùng trống")
                khongMan += 1
                thieu += can.muc.count
                continue
            }
            _ = phien.moMan(m.tien, boiTacTu: false)
            // CHỜ MÀN NẠP XONG, không ngủ một khoảng cố định. [DEV-183]
            //
            // `--bam-thu` đã có phép chờ này từ 22/09; `--do-noi-dung` thì không, và nó đo
            // trong lúc màn còn đang in "Đang đọc…". Hệ quả: hai lần chạy liên tiếp trên CÙNG
            // một dự án ra 32/24/21 rồi 31/27/19 — cùng một mã, khác kết luận. Một cổng chập
            // chờn tệ hơn không có cổng: nó dạy người ta chạy lại cho tới khi xanh.
            await _choNapXong()
            let van = Self.chuTrongTinh(khung.vungLamViec)
            let hong = can.muc.filter { !EideDoNoiDung.daHien($0, trong: van) }
            du += can.muc.count - hong.count
            guard !hong.isEmpty else { continue }

            // ---- "CHƯA DỰNG" khác "KHÔNG ĐO ĐƯỢC". [DEV-183]
            //
            // Bản đầu gộp cả hai thành "thiếu". Đo 22/09/2026 trên dự án `congvt1` — 0 fact,
            // 0 hộ chiếu, 0 yêu cầu, 0 tính năng — bộ dò báo 48 mục thiếu trên 21 màn, trong
            // khi phần lớn các màn ấy đang hiện ĐÚNG trạng thái rỗng mà luật B5 quy định.
            //
            // Tin vào con số ấy là đi viết lại 21 màn không hỏng, và tệ hơn: sau khi viết xong
            // con số vẫn y nguyên, vì dấu hiệu cần tìm nằm trong dữ liệu chứ không nằm trong mã.
            // Một phép đo không phân biệt được "màn thiếu mục này" với "dự án chưa có dữ liệu
            // loại này" thì nó không đo cái nó tưởng nó đo.
            //
            // Màn đang ở trạng thái rỗng thì KHÔNG kết luận gì về nó — báo "không đo được" và
            // nói ra cần dữ liệu gì. Muốn đo thật thì chạy trên một dự án có đủ hiện vật.
            if let ly = Self.lyDoRong(van) {
                // "Rỗng vì CHƯA CÓ dữ liệu" khác "rỗng vì KHÔNG ĐỌC ĐƯỢC dữ liệu".
                //
                // Cái đầu là trạng thái bình thường của một dự án mới và không kết luận gì về
                // màn. Cái sau là màn HỎNG — và nó trông y hệt trên màn hình. Đo 22/09/2026:
                // 18 trong 20 màn "rỗng" của một dự án có 290 fact thật ra đang in
                // `E6003: store user_version=7, cần 10`; xếp chúng vào "không đo được" là giấu
                // một sản phẩm hỏng sau một nhãn vô hại.
                if Self.laLoi(ly) {
                    thieu += hong.count
                    print("\n✖ \(can.ma) \(m.nhan) — MÀN HỎNG, không đọc được dữ liệu "
                          + "(\(hong.count)/\(can.muc.count) mục không đo được vì lý do này):"
                          + "\n     → \(ly)")
                    continue
                }
                khongDo += hong.count
                manRong.append("\(can.ma) \(m.nhan) (\(hong.count) mục) — \(ly)")
                continue
            }
            thieu += hong.count
            print("\n✖ \(can.ma) \(m.nhan) — CHƯA DỰNG \(hong.count)/\(can.muc.count) "
                  + "(màn CÓ dữ liệu, mục vẫn không hiện):")
            for h in hong {
                print("     · \(h.mo_ta)  [chờ: \(h.dau_hieu.joined(separator: " / "))]")
            }
        }
        if !manRong.isEmpty {
            print("\n— KHÔNG ĐO ĐƯỢC \(khongDo) mục: màn đang ở trạng thái rỗng vì dự án này "
                  + "chưa có dữ liệu loại ấy.\n  Chạy lại trên một dự án có đủ hiện vật mới "
                  + "kết luận được.\n"
                  + manRong.map { "     · " + $0 }.joined(separator: "\n"))
        }
        print("\n=== NỘI DUNG: \(du) mục đã hiện · \(thieu) CHƯA DỰNG · \(khongDo) không đo được"
              + (khongMan > 0 ? " · \(khongMan) màn KHÔNG MỞ ĐƯỢC" : ""))
        // Chỉ "chưa dựng" và "không có màn" mới làm đỏ cổng. Để "không đo được" làm đỏ thì
        // cổng này vĩnh viễn đỏ trên mọi dự án mới — và một cổng luôn đỏ là một cổng bị tắt.
        exit(thieu == 0 && khongMan == 0 ? 0 : 1)
    }

    /// Nút KHÔNG bấm thử: hạ cả phiên, hoặc đổi thứ khó dựng lại.
    ///
    /// Danh sách phải NGẮN và mỗi tên phải có lý do — một danh sách bỏ qua dài là cách biến
    /// phép đo thành thứ luôn xanh.
    static let KHONG_BAM: Set<String> = [
        "Dừng khẩn",        // hạ cả phiên, mọi phép đo sau đó vô nghĩa
        "Từ chối",          // quyết định không đảo được trên hàng đợi thật
        "Hoàn tác",         // đổi dữ liệu dự án thật
    ]

    /// Bấm thật từng nút, so vân tay màn hình trước/sau — `--bam-thu <dự án>`.
    private func _bamThu(_ duAn: String) async {
        await phien.moDuAn(duAn)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        var imLang: [String] = []
        var tongBam = 0

        /// Chờ màn nạp XONG. Không có phép chờ này thì bộ đo chụp lúc màn còn trống, và một
        /// màn trống không có nút nào — báo cáo khi ấy nói "0 nút chết" cho một màn chưa hề
        /// được dò. Đo 22/09/2026: cả 25 màn góp đúng 0 nút.
        func choNap() async {
            let t0 = ProcessInfo.processInfo.systemUptime
            while self._chuTrong(self.khung.vungLamViec).contains("Đang đọc…"),
                  ProcessInfo.processInfo.systemUptime - t0 < 12 {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            self.khung.layoutSubtreeIfNeeded()
        }

        func thu(_ goc: NSView, _ ten: String, moLai: @escaping () async -> Void) async {
            await moLai()
            await choNap()
            let n = EideDoNutChet.nutDs(goc).count
            for i in 0..<n {
                await moLai()
                await choNap()
                let ds = EideDoNutChet.nutDs(goc)
                guard i < ds.count else { break }
                let (b, duong) = ds[i]
                let nhan = b.title.isEmpty ? b.attributedTitle.string : b.title
                if nhan.isEmpty || Self.KHONG_BAM.contains(nhan) { continue }
                // Nút TẮT đang nói "chưa tới lượt bạn bấm" — đó là hành vi đúng, không phải nút
                // chết. `EideNutTheoO` lo phần bật lại khi ô nhập có dữ liệu.
                if !b.isEnabled { continue }
                // `NSPopUpButton` MỞ MENU chứ không đổi màn hình, nên phép so trước/sau luôn
                // báo nó im — một lời tố oan. Đo nó bằng thứ đúng với nó: có mục để chọn không.
                if let pu = b as? NSPopUpButton {
                    if pu.numberOfItems <= 1 {
                        imLang.append("  ✖ [\(nhan)] danh sách thả xuống KHÔNG có mục nào"
                                      + "\n     \(ten) · \(duong)")
                    }
                    tongBam += 1
                    continue
                }
                let truoc = EideDoNutChet.vanTay(khung)
                _ = b.target?.perform(b.action, with: b)
                try? await Task.sleep(nanoseconds: 600_000_000)
                khung.layoutSubtreeIfNeeded()
                tongBam += 1
                if EideDoNutChet.vanTay(khung) == truoc {
                    imLang.append("  ✖ [\(nhan)] bấm xong màn hình KHÔNG đổi gì\n     \(ten) · \(duong)")
                }
            }
        }

        await thu(khung.dock, "VÙNG TRAO ĐỔI", moLai: {})
        for m in EideManHinhDS.tatCa {
            await thu(khung.vungLamViec, "MÀN \(m.tien)", moLai: { [weak self] in
                _ = self?.phien.moMan(m.tien, boiTacTu: false)
            })
        }
        print("\n=== BẤM \(tongBam) nút — \(imLang.count) nút KHÔNG làm gì")
        if !imLang.isEmpty { print(imLang.joined(separator: "\n")) }
        exit(imLang.isEmpty ? 0 : 1)
    }

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
                // "Rỗng có lý do" KHÔNG được thành lối thoát cho một lỗi. Lớp cơ sở dựng câu
                // "không đọc được: …" khi `napDuLieu` ném, và câu ấy cũng có đủ hai phần — nên
                // chỉ đếm hai phần thì một màn hỏng đi qua được phép kiểm. Đo 20/09: màn Xung
                // đột tri thức trên dự án tạm ĐẠT với lý do là một E2000.
                let loi = van.contains("không đọc được")
                do_("6c. màn \(tien) rỗng CÓ LÝ DO và có bước kế tiếp",
                    !loi && van.contains("vì:") && van.contains("Bước kế tiếp"),
                    loi ? "(rỗng vì LỖI, không vì thiếu dữ liệu)" : "(\(lyDo))")
                print("       └ \(lyDo)")
            } else {
                do_("6c. màn \(tien) nạp được dữ liệu thật",
                    !van.contains("Màn này đang rỗng") && !van.contains("Đang đọc…"), "(\(lyDo))")
            }
        }

        await phien._lamMoi()
        let mucTruoc = khung.thanhTren.mucHienTai
        do_("7. mức tự chủ đọc được từ daemon", mucTruoc.contains("A"), "(\(mucTruoc))")

        // §2D.6 KHÔNG đo được ở đây: đường `chat.send` đi qua `chat.parse_intent`,
        // tức qua mô hình, tức qua mạng và qua tiền — cùng lý do `--chup` không gọi nó.
        // Luật "A0/A1 thì `plan_only`" kiểm ở `tests/test_dung_cho_gat_dau.py`, và
        // `plan_only`/`chat.resume` kiểm end-to-end qua Router ở cùng tệp ấy.
        // Ghi ra chứ không lặng lẽ bỏ: một phép đo biến mất khỏi danh sách trông y hệt
        // một phép đo chưa ai nghĩ tới.

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

        // §2D.2(c) — chỉ đo được ở ĐÂY. Luật "không đổi chiều cao khi con trỏ ở ô lệnh" hỏi
        // `window?.firstResponder`, mà `firstResponder` chỉ có nghĩa khi có một cửa sổ thật với
        // một trường soạn thảo thật. Mọi bài `swift test` chạy ngoài cửa sổ đều bỏ lọt nhánh này
        // — và nó đã từng sai im lặng theo chiều ngược lại (`nil === nil` → true).
        khung.dock.datCao(.chuan, buoc: true)
        let daVao = khung.dock.doTroVaoOLenh()
        khung.dock.datCao(.thuGon)
        do_("15. con trỏ đang ở ô lệnh thì chiều cao vùng trao đổi KHÔNG tự đổi (§2D.2c)",
            daVao && khung.dock.cao == .chuan, "(con trỏ vào ô: \(daVao), cao: \(khung.dock.cao))")
        khung.window?.makeFirstResponder(nil)
        khung.dock.datCao(.thuGon)
        do_("15b. rời ô lệnh thì luật tự chuyển chạy lại", khung.dock.cao == .thuGon)

        // §2C.3 — tác tử không cướp màn người vừa tự chọn.
        phien.moMan("Passport", boiTacTu: false)
        let chiem = phien.moMan("NhatKy", boiTacTu: true)
        do_("16. tác tử KHÔNG cướp màn người vừa tự chọn, nhưng vẫn thêm tab (§2C.3)",
            !chiem && khung.vungLamViec.dangMo == "Passport"
                   && khung.thanhTab.tab.contains("NhatKy"),
            "(chiếm: \(chiem), đang mở: \(khung.vungLamViec.dangMo ?? "—"), "
            + "tab: \(khung.thanhTab.tab.count))")

        // §2.2 — thu cửa sổ về đúng cỡ tối thiểu. Chỉ đo được trên cửa sổ THẬT: `contentMinSize`
        // là thứ `NSWindow` cưỡng chế, và một bài kiểm dựng khung ngoài cửa sổ sẽ vui vẻ đặt bề
        // ngang 800 pt — một trạng thái người dùng không bao giờ tới được.
        cuaSo.setContentSize(EideKhung.CO_TOI_THIEU)
        khung.layoutSubtreeIfNeeded()
        do_("17. cửa sổ không co xuống dưới 1100 × 700 (§2.2)",
            khung.frame.width >= 1100 && khung.frame.height >= 700,
            String(format: "(%.0f × %.0f pt)", khung.frame.width, khung.frame.height))
        do_("17b. chạm ngưỡng thì cột phải thu còn 44 pt và KHÔNG biến mất (§2.2)",
            khung.cotPhai.hep && !khung.cotPhai.isHidden
                && abs(khung.cotPhai.frame.width - 44) < 1,
            String(format: "(hẹp: %@, rộng %.0f pt)", khung.cotPhai.hep ? "có" : "không",
                   khung.cotPhai.frame.width))
        cuaSo.setContentSize(NSSize(width: 1456, height: 838))
        khung.layoutSubtreeIfNeeded()
        do_("17c. nới cửa sổ ra thì cột phải đầy đủ trở lại",
            !khung.cotPhai.hep, String(format: "(%.0f pt)", khung.cotPhai.frame.width))

        // §2A.2 — popover chuyển dự án, neo vào nút tên dự án ở thanh trên.
        await phien.moChonDuAn()
        let chu = _chuTrong(phien.chonDuAn.view)
        // Danh sách là dự án của WORKSPACE người dùng, không phải dự án tạm của bài kiểm — `tam`
        // nằm ngoài workspace nên nó không được có mặt ở đây, và đòi nó là đòi sai.
        do_("18. popover chuyển dự án có đủ ô lọc · danh sách · nút tạo mới (§2A.2)",
            chu.contains("Lọc theo tên") && chu.contains("Dự án mới")
                && !chu.contains("Không dự án nào khớp")
                && phien.chonDuAn.loc("").count > 0,
            "(\(phien.chonDuAn.loc("").count) dự án đọc từ `project.list`)")
        phien.popChon.close()

        // §4.4 — form tham số dựng từ hợp đồng THẬT trong registry, không từ một JSON bịa ra.
        // `kg.neighborhood` là R0 và khai `node` bắt buộc. Chọn một năng lực CÓ THẬT tham số bắt
        // buộc chứ không chọn theo trí nhớ: bản đầu dùng `passport.query`, mà hợp đồng của nó
        // khai `required: []` — phép đo khi ấy xanh hay đỏ đều không nói gì về §4.4.
        //
        // Lời gọi KHÔNG chạy: `goiNangLuc` mở form rồi trả về, nên không năng lực nào được thi
        // hành trong bài tự kiểm này.
        await phien.goiNangLuc("kg.neighborhood")
        let dangHoi = !khung.formThamSo.isHidden
        let thieu = khung.formThamSo.conThieu().sorted()
        do_("19. năng lực cần tham số thì MỞ FORM chứ không gọi thiếu (§4.4)",
            dangHoi && !thieu.isEmpty, "(form mở: \(dangHoi), còn thiếu: \(thieu))")
        khung.formThamSo.dong()

        // §4.3 — toast quyết định cổng. `project.status` không tham số nên nó chạy thẳng, và
        // quyết định của cổng phải hiện ra dù APPROVE.
        await phien.goiNangLuc("project.status")
        // Từ vựng THẬT của cổng là APPROVE / ASK / REJECT. UXC-31 §4.3 viết "DENY" — một từ
        // `PolicyGate` không bao giờ phát ra. Xem [DEV-143].
        do_("20. toast hiện quyết định cổng kèm mã quy tắc (§4.3)",
            khung.toast.chu.contains("project.status")
                && ["APPROVE", "ASK", "REJECT"].contains(where: khung.toast.chu.contains),
            "(\(khung.toast.chu))")
        khung.toast.an()

        // §9.1 — ba phím tắt còn lại, đo trên phiên thật chứ không đọc bảng menu: một mục menu
        // có `keyEquivalent` đúng mà `action` trỏ vào hư vô vẫn "có phím tắt".
        do_("21. ⌘1…⌘6 nhảy đủ sáu nhóm (§9.1)",
            (1...6).allSatisfy { phien.nhayNhom($0) != nil }
                && phien.nhayNhom(7) == nil,
            "(\(EideManHinhDS.nhom.count) nhóm)")
        do_("21b. ⌘W đóng tab, hết tab thì KHÔNG đóng cửa sổ (§9.1)",
            { var n = 0; while phien.dongTabHienTai() { n += 1; if n > 40 { break } }
              return n > 0 && !phien.dongTabHienTai() }(),
            "(còn \(khung.thanhTab.tab.count) tab)")

        // §6.1 — modal ASK với ĐÚNG hai lựa chọn, và Esc là vế an toàn (§9.3).
        khung.modalHoi.mo(maCho: "kiem", cap: "code.modify", tep: nil, vi: "bộ đệm bẩn")
        khung.layoutSubtreeIfNeeded()
        let sl = khung.modalHoi.nhanNut
        khung.modalHoi.cancelOperation(nil)
        do_("22. modal P-EDIT-01 đúng HAI lựa chọn, Esc = vế an toàn (§6.1, §9.3)",
            sl.count == 2 && khung.modalHoi.isHidden,
            "(\(sl.joined(separator: " | ")))")

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

        // §9.1 — điều hướng đủ bằng bàn phím. Đặt trong MENU chứ không bắt phím thô: menu là
        // chỗ duy nhất macOS cho người dùng biết ứng dụng có những phím tắt gì, và một phím tắt
        // không ai tìm ra được là một phím tắt chỉ tác giả dùng.
        lenh.submenu?.addItem(NSMenuItem.separator())
        let luu = NSMenuItem(title: "Lưu tệp (code.human_save)",
                             action: #selector(_luuTep), keyEquivalent: "s")
        luu.target = self
        lenh.submenu?.addItem(luu)
        let dongTab = NSMenuItem(title: "Đóng tab", action: #selector(_dongTab),
                                 keyEquivalent: "w")
        dongTab.target = self
        lenh.submenu?.addItem(dongTab)
        goc.addItem(lenh)

        let dh = NSMenuItem()
        dh.submenu = NSMenu(title: "Điều hướng")
        for (i, n) in EideManHinhDS.nhom.enumerated() {
            let m = NSMenuItem(title: n.ten, action: #selector(_nhayNhom(_:)),
                               keyEquivalent: "\(i + 1)")
            m.tag = i + 1
            m.target = self
            dh.submenu?.addItem(m)
        }
        goc.addItem(dh)

        NSApp.mainMenu = goc
    }

    @objc private func _moBangLenh() { khung.bangLenh.mo() }
    @objc private func _luuTep() { Task { await phien.luuTepHienTai() } }
    @objc private func _dongTab() { phien.dongTabHienTai() }
    @objc private func _nhayNhom(_ m: NSMenuItem) { phien.nhayNhom(m.tag) }
    @objc private func _dungKhan() { Task { await phien.dungKhan() } }

    private func _co(_ nhan: String) {
        print(String(format: "  [cỡ] %-16@ %.0f × %.0f", nhan as NSString,
                     khung.frame.width, khung.frame.height))
    }

    /// Cho bộ lái kịch bản dùng lại — cùng một phép chụp, nên ảnh của hai chế độ
    /// so được với nhau.
    func _chupCong(_ url: URL) { _chup(url) }

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
