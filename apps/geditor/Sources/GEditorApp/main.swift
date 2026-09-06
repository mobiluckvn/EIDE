import AppKit

// Điểm vào ứng dụng. Dựng NSApplication bằng mã (không storyboard) để bộ khung
// build được bằng SwiftPM trên cả hai kiến trúc mà không cần file .xcodeproj.
//
// NFR-PERF-01: khởi động nguội ≤ 500 ms (Apple Silicon) / ≤ 1 s (Intel), đo tới khi
// cửa sổ NHẬN ĐƯỢC THAO TÁC GÕ. Mọi việc nặng khi khởi động (quét snapshot, nạp
// grammar, dựng chỉ mục) phải chạy bất đồng bộ SAU khi cửa sổ đã sẵn sàng.

// Mốc ĐẦU TIÊN của mã ta: mọi thứ trước dòng này là dyld nạp và liên kết framework. Tách hai
// phần ấy ra mới biết nên tối ưu chỗ nào — cắt việc trong `applicationDidFinishLaunching` sẽ
// vô ích nếu phần lớn thời gian nằm trước cả `main()`.
StartupProbe.markMainEntered()

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.activate(ignoringOtherApps: true)
application.run()
