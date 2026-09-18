import AppKit
import EideGiaoDien
import EideLoi

/// Điểm vào của bản EIDE mới.
///
/// Cửa sổ mở ở ĐÚNG cỡ bản demo được xem (1456×838), đặt tường minh chứ không để ràng buộc
/// quyết. Bản cũ chưa bao giờ đặt cỡ cửa sổ: nó cao 720 rồi 818 pt vì chuỗi ràng buộc cứng của
/// panel làm `fittingSize` lớn hơn cửa sổ và AppKit phóng to cửa sổ cho vừa — một con số là TÁC
/// DỤNG PHỤ của bố cục, nhích dần lên mà không bao giờ co lại.
final class UngDung: NSObject, NSApplicationDelegate {

    var cuaSo: NSWindow!
    var khung: EideKhung!

    func applicationDidFinishLaunching(_ n: Notification) {
        khung = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        cuaSo = NSWindow(contentRect: khung.frame,
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        cuaSo.title = "EIDE"
        cuaSo.contentView = khung
        cuaSo.center()

        _noiDay()

        // `--chup <thư-mục>`: dựng cửa sổ, chụp, thoát. Để so ảnh với bản demo mà không cần
        // người ngồi trước máy.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--chup"), i + 1 < args.count {
            let thuMuc = URL(fileURLWithPath: args[i + 1])
            try? FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
            cuaSo.makeKeyAndOrderFront(nil)
            khung.layoutSubtreeIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self._chup(thuMuc.appendingPathComponent("khung.png"))
                exit(0)
            }
            return
        }
        cuaSo.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Nối các vùng với nhau. TẤT CẢ ở một chỗ, để đọc được luồng điều khiển của cả cửa sổ.
    private func _noiDay() {
        khung.cotTrai.onChon = { [weak self] tien in
            guard let self else { return }
            self.khung.thanhTab.mo(tien)
            self.khung.vungLamViec.moMan(tien, nangLucDs: [])
            self.khung.vungLamViec.khiRong(
                vi: "chưa nối daemon trong bản dựng này",
                buocKe: "chạy `eide daemon` rồi mở lại dự án")
        }
        khung.thanhTab.onChon = { [weak self] tien in
            self?.khung.cotTrai.chon(tien)
            self?.khung.vungLamViec.moMan(tien, nangLucDs: [])
        }
        khung.thanhTab.onDong = { [weak self] tien in
            guard let self else { return }
            if let ke = self.khung.thanhTab.dong(tien) {
                self.khung.cotTrai.chon(ke)
                self.khung.vungLamViec.moMan(ke, nangLucDs: [])
            } else {
                self.khung.vungLamViec.dongMan()
            }
        }
        khung.dock.onGui = { [weak self] van in
            self?.khung.dock.themLuot(.tacTu, "Chưa nối daemon — câu \"\(van)\" chưa gửi đi được.")
        }
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
let uy = UngDung()
app.delegate = uy
app.setActivationPolicy(.regular)
app.run()
