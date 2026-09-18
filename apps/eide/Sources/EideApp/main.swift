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

        phien.moMan("S3", boiTacTu: false)
        do_("5. mở màn thì tab mở theo", khung.thanhTab.tab.contains("S3"))
        do_("6. vùng làm việc đổi sang màn ấy", khung.vungLamViec.dangMo == "S3",
            "(\(khung.vungLamViec.dangMo ?? "nil"))")

        await phien._lamMoi()
        let mucTruoc = khung.thanhTren.mucHienTai
        do_("7. mức tự chủ đọc được từ daemon", mucTruoc.contains("A"), "(\(mucTruoc))")

        await phien.dungKhan()
        await phien._lamMoi()
        do_("8. dừng khẩn hiện ra ở thanh trên, không núp sau mức tự chủ",
            khung.thanhTren.mucHienTai.contains("DỪNG"), "(\(khung.thanhTren.mucHienTai))")

        khung.datDuLieuCu(true, tre: 9)
        khung.layoutSubtreeIfNeeded()
        do_("9. dải Dữ liệu cũ nói rõ trễ bao lâu", khung.chuDaiCu.contains("9 giây"),
            "(\(khung.chuDaiCu))")

        try? FileManager.default.removeItem(atPath: tam)
        print("\nĐẠT \(dat)/\(dat + hong)")
        exit(hong == 0 ? 0 : 1)
    }

    private func _chup(_ url: URL) {
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
