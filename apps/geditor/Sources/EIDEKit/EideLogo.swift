import AppKit

/// **Nhận diện PTIT** — biểu tượng và wordmark, dựng từ tệp chính thức.
///
/// Nguồn: `docs/logo-ptit-1.svg`, chủ sản phẩm cung cấp 16/09/2026. Hai bản dựng sẵn trong
/// `apps/geditor/Resources/`: `ptit-mark.svg` (chỉ hình, 40×40) và `ptit-logo.svg` (hình + chữ,
/// 347×40). Bảng màu của sản phẩm cũng lấy từ chính tệp ấy — xem `EideToken.Mau.brand`.
///
/// ## Vì sao đọc SVG lúc chạy chứ không nhúng PNG
///
/// Logo xuất hiện ở ba cỡ rất khác nhau: 28 pt trên thanh trên, 64 pt trong hộp Giới thiệu,
/// 1024 px trong icon ứng dụng. Nhúng PNG nghĩa là ba tệp phải cùng được cập nhật khi bộ nhận
/// diện đổi, và cái bị quên sẽ là cái ít người nhìn nhất. SVG thì một nguồn cho mọi cỡ, và
/// `NSImage` đọc được SVG từ macOS 11 — nền tảng tối thiểu của sản phẩm đã là macOS 14.
///
/// ## Thiếu tệp thì trả `nil`, không vẽ thay
///
/// Một logo tự vẽ "gần giống" là thứ tệ hơn không có logo: nó đi vào ảnh chụp báo cáo, vào slide
/// bảo vệ, và không ai kịp nhận ra nó không phải bộ nhận diện thật.
public enum EideLogo {

    /// Biểu tượng vuông (không kèm chữ) — thanh trên, hộp thoại, icon.
    public static func bieuTuong() -> NSImage? { _doc("ptit-mark") }

    /// Wordmark đầy đủ: biểu tượng + hai dòng chữ, tỉ lệ 347×40.
    public static func wordmark() -> NSImage? { _doc("ptit-logo") }

    /// Tỉ lệ ngang/dọc của wordmark — để bên gọi đặt ràng buộc mà không phải đoán.
    public static let TI_LE_WORDMARK: CGFloat = 347.0 / 40.0

    private static var cache: [String: NSImage] = [:]

    private static func _doc(_ ten: String) -> NSImage? {
        if let s = cache[ten] { return s }
        // `Bundle.module` cho bản dựng SwiftPM có resource; `Bundle.main` cho bản .app đã đóng
        // gói. Thử cả hai vì cùng một mã chạy ở cả hai chỗ, và một trong hai luôn trả nil.
        let url = Bundle.module.url(forResource: ten, withExtension: "svg",
                                    subdirectory: "Resources")
            ?? Bundle.module.url(forResource: ten, withExtension: "svg")
            ?? Bundle.main.url(forResource: ten, withExtension: "svg")
        guard let url, let anh = NSImage(contentsOf: url) else { return nil }
        // `isTemplate = false`: đây là logo MÀU. Để template thì AppKit tô lại thành một màu duy
        // nhất theo ngữ cảnh, và đỏ PTIT cùng vàng ngọn đuốc biến mất.
        anh.isTemplate = false
        cache[ten] = anh
        return anh
    }
}
