// SINH TỰ ĐỘNG — đừng sửa tay.
//
// Nguồn: docs/spec/ui/tokens.json (sinh từ docs/ho-so/nguon/uxd.js §7).
// Sinh lại: python3 scripts/gen_ui_swift.py   ·   Đối chiếu: --kiem (chạy trong CI).
//
// UXD-13 §7 và U7: đỏ PTIT cho điều hướng và hành động chính, vàng cho việc CẦN NGƯỜI,
// xám xanh cho hành động phụ và cho tác tử. Ba màu ấy mang nghĩa, không phải trang trí:
// người dùng đọc màu để biết việc nào máy tự làm và việc nào đang chờ mình.

import AppKit

/// Token thiết kế PTIT (UXD-13 §7).
public enum EideToken {

    public enum Mau {
        public static let primary = NSColor(hex: "#BC2626")
        public static let brand = NSColor(hex: "#DE221A")
        public static let brandGold = NSColor(hex: "#B89C0E")
        public static let brandGoldLight = NSColor(hex: "#EFF003")
        public static let accent = NSColor(hex: "#F2B705")
        public static let secondary = NSColor(hex: "#373D4E")
        public static let ok = NSColor(hex: "#1d7a4f")
        public static let okBg = NSColor(hex: "#e7f4ec")
        public static let warn = NSColor(hex: "#8a5a00")
        public static let warnBg = NSColor(hex: "#fdf3dd")
        public static let bad = NSColor(hex: "#A31F1F")
        public static let badBg = NSColor(hex: "#FBECEC")
        public static let info = NSColor(hex: "#1b5fa5")
        public static let infoBg = NSColor(hex: "#e9f1fa")
        public static let bg = NSColor(hex: "#f5f4f2")
        public static let surface = NSColor(hex: "#ffffff")
        public static let border = NSColor(hex: "#e2e0dc")
        public static let border2 = NSColor(hex: "#cfcdc8")
        public static let text = NSColor(hex: "#1b1b1b")
        public static let muted = NSColor(hex: "#6b6b6b")
        public static let faint = NSColor(hex: "#707070")
    }

    public static let fontUI = NSFont(name: "IBM Plex Sans", size: 13)
        ?? NSFont.systemFont(ofSize: 13)
    public static let fontMono = NSFont(name: "IBM Plex Mono", size: 12)
        ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    public static let space: [CGFloat] = [4, 8, 12, 16, 24]
    public static let radius: [CGFloat] = [6, 8, 10]
    public static let sidebarWidth: CGFloat = 212
    public static let topbarHeight: CGFloat = 52
    public static let statusbarHeight: CGFloat = 26
    public static let contentGap: CGFloat = 16

    /// UXD-13 U10 / WCAG 2.2 AA. Ghi ra thành hằng số để TEST đo được, chứ không để nó
    /// thành một câu trong tài liệu mà không ai kiểm.
    public static let tuongPhanToiThieu: Double = 4.5
    public static let hoTroNenToi = false
}

extension NSColor {
    /// `#RRGGBB` → NSColor trong không gian sRGB.
    ///
    /// Dùng sRGB chứ không phải `deviceRGB`: token là mã màu của bộ nhận diện, và nó
    /// phải ra đúng một màu trên mọi màn hình, không phụ thuộc màn hình đang cắm.
    public convenience init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let n = UInt32(s, radix: 16) ?? 0
        self.init(srgbRed: CGFloat((n >> 16) & 0xFF) / 255,
                  green: CGFloat((n >> 8) & 0xFF) / 255,
                  blue: CGFloat(n & 0xFF) / 255, alpha: 1)
    }

    /// Độ sáng tương đối theo WCAG 2.2 — để `tuongPhan(_:)` đo được U10.
    var doSangTuongDoi: Double {
        guard let c = usingColorSpace(.sRGB) else { return 0 }
        func k(_ v: CGFloat) -> Double {
            let d = Double(v)
            return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * k(c.redComponent) + 0.7152 * k(c.greenComponent) + 0.0722 * k(c.blueComponent)
    }

    /// Tỉ số tương phản với một màu khác (WCAG 2.2). ≥ 4,5 là đạt AA cho chữ thường.
    public func tuongPhan(_ khac: NSColor) -> Double {
        let a = doSangTuongDoi, b = khac.doSangTuongDoi
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
