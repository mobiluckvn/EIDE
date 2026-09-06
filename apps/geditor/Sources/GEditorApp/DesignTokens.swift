import AppKit
import GEditorCore

/// Design token — nguồn sự thật duy nhất cho màu, chữ, lưới (UI/UX §2, ADR-09).
///
/// Năm màu của VÙNG SOẠN THẢO đọc từ `Tokens.theme` (FR-UI-801) — người dùng đổi được, và
/// theme là file JSON trong `themes/`. Những màu còn lại vẫn là hằng số: chúng thuộc về phần
/// khung của ứng dụng và phải khớp với phần còn lại của máy, không phải với theme.
///
/// Bảng màu GEditor lấy CAM làm chủ đạo. Không đưa tông cam vào dải màu cột CSV —
/// sẽ lẫn với màu hành động của giao diện (UI/UX §2.1).
public enum Tokens {

    /// Theme đang dùng (FR-UI-801). Đổi giá trị này rồi vẽ lại là màu đổi theo.
    ///
    /// `static var` chứ không phải hằng: mọi màu bên dưới đọc nó ở thời điểm VẼ, nên không có
    /// chỗ nào phải đi thông báo cho ai. Cái giá là một biến toàn cục có thể ghi — chấp nhận
    /// được vì nó chỉ đổi khi người dùng chọn theme khác, và luôn trên luồng chính.
    public static var theme: Theme = .cam

    public enum Color {

        /// Dựng một `NSColor` đổi theo nền sáng/tối từ một cặp màu của theme.
        ///
        /// Đọc `Tokens.theme` BÊN TRONG closure, không phải lúc dựng: closure chạy lại mỗi lần
        /// AppKit cần màu, nên đổi theme là màu mới có hiệu lực ngay ở lần vẽ kế tiếp. Bắt giá
        /// trị lúc dựng thì đổi theme xong phải khởi động lại mới thấy.
        static func themed(_ pair: KeyPath<Theme, Theme.Pair>) -> NSColor {
            NSColor(name: nil) { appearance in
                let value = appearance.isDark
                    ? Tokens.theme[keyPath: pair].dark
                    : Tokens.theme[keyPath: pair].light
                guard let rgb = Theme.components(value) else {
                    // Màu gõ sai trong file theme: dùng màu của theme MẶC ĐỊNH, không rơi về
                    // đen. Đen trông như một lựa chọn thiết kế và người dùng đi tìm lỗi chỗ khác.
                    let fallback = appearance.isDark
                        ? Theme.cam[keyPath: pair].dark : Theme.cam[keyPath: pair].light
                    let safe = Theme.components(fallback) ?? (0.5, 0.5, 0.5)
                    return NSColor(srgbRed: safe.r, green: safe.g, blue: safe.b, alpha: 1)
                }
                return NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
            }
        }
        /// Nhận diện, nhấn — màu duy nhất của phần khung mà theme đổi được.
        public static let orange = themed(\.accent)
        /// Heading, chrome đậm.
        public static let ember = NSColor(srgbRed: 0xA3 / 255, green: 0x43 / 255, blue: 0x09 / 255, alpha: 1)
        /// Phụ trợ: chấm chưa lưu, banner.
        public static let gold = NSColor(srgbRed: 0xF8 / 255, green: 0xB9 / 255, blue: 0x42 / 255, alpha: 1)
        /// Lỗi, validate.
        public static let error = NSColor(srgbRed: 0xD1 / 255, green: 0x34 / 255, blue: 0x38 / 255, alpha: 1)

        /// Nút chính/link — đổi theo theme để giữ tương phản AA với chữ trắng.
        public static let action = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(srgbRed: 0xFF / 255, green: 0x9E / 255, blue: 0x5E / 255, alpha: 1)
                : NSColor(srgbRed: 0xC2 / 255, green: 0x4E / 255, blue: 0x08 / 255, alpha: 1)
        }

        public static let editorBackground = themed(\.editorBackground)
        public static let editorInk = themed(\.editorInk)
        public static let selection = themed(\.selection)

        /// Nền của mọi kết quả tìm kiếm khi bật tô hết (FR-SRCH-109).
        ///
        /// KHÁC `selection`, và đó là cả điểm của nó: kết quả đang đứng được vẽ bằng vùng chọn
        /// thật, còn những kết quả kia bằng màu này. Dùng chung một màu thì người dùng mất dấu
        /// chỗ mình đang đứng giữa hai trăm chỗ giống hệt nhau.
        public static let searchHighlight = themed(\.searchHighlight)

        /// Màu chữ theo mức nghiêm trọng của dòng log (FR-FMT-508).
        ///
        /// Dùng lại màu SẴN CÓ của bảng màu sản phẩm, không bịa màu mới: đỏ đã là màu lỗi ở
        /// panel kiểm dữ liệu, vàng đã là màu cảnh báo. Một file log tô bằng bảng màu thứ hai
        /// sẽ dạy người dùng hai nghĩa cho cùng một màu.
        ///
        /// Mức thấp (`trace`, `debug`) tô NHẠT chứ không tô màu riêng: chúng chiếm phần lớn
        /// một file log, và tô nổi chúng lên là làm mờ đúng thứ người ta đang tìm.
        public static func logLevel(_ level: LogFormat.Level) -> NSColor {
            switch level {
            case .critical: return error
            case .error: return error
            case .warning: return gold
            case .notice: return action
            case .info: return editorInk
            case .debug, .trace: return secondaryInk
            }
        }

        /// Nền của phần "khung" quanh vùng soạn thảo: thanh tab, thanh trạng thái.
        ///
        /// Không dùng `editorBackground` cho khung: tab đang mở được phân biệt bằng CÁCH nó
        /// cùng màu với vùng soạn thảo, nên khung phải khác màu thì mới thấy sự khác ấy.
        public static let chrome = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(srgbRed: 0x22 / 255, green: 0x1D / 255, blue: 0x19 / 255, alpha: 1)
                : NSColor(srgbRed: 0xF2 / 255, green: 0xEE / 255, blue: 0xEA / 255, alpha: 1)
        }

        /// Nền của vùng xem tài liệu — xám, để mép tờ giấy trắng nhìn thấy được.
        ///
        /// Không lấy `editorBackground`: ở theme sáng nó gần trắng, và một tờ giấy trắng trên
        /// nền trắng thì không còn là tờ giấy — người đọc mất luôn thông tin lề tài liệu kết
        /// thúc ở đâu.
        public static let pageBackdrop = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(srgbRed: 0.13, green: 0.13, blue: 0.14, alpha: 1)
                : NSColor(srgbRed: 0.36, green: 0.37, blue: 0.39, alpha: 1)
        }

        /// Đường kẻ bảng TRÊN TRANG GIẤY. Trang luôn trắng nên màu này cũng cố định — dùng màu
        /// theo theme sẽ cho ra đường kẻ gần trắng ở giao diện tối.
        public static let paperRule = NSColor(srgbRed: 0.62, green: 0.62, blue: 0.64, alpha: 1)

        public static let separator = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(white: 1, alpha: 0.12)
                : NSColor(white: 0, alpha: 0.10)
        }

        /// Chữ phụ: tên tab không hoạt động, nhãn mờ.
        public static let secondaryInk = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(srgbRed: 0xE7 / 255, green: 0xDC / 255, blue: 0xD2 / 255, alpha: 0.62)
                : NSColor(srgbRed: 0x1F / 255, green: 0x29 / 255, blue: 0x33 / 255, alpha: 0.60)
        }

        /// Ký tự ẩn (FR-ENC-205) — phải ĐỌC RA ĐƯỢC nhưng không được tranh chỗ với chữ thật.
        ///
        /// Cùng tông với chữ nhưng nhạt hẳn: người dùng bật ký tự ẩn để soi khoảng trắng, chứ
        /// không phải để nhìn một rừng dấu chấm át cả nội dung.
        public static let invisibleInk = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(srgbRed: 0xE7 / 255, green: 0xDC / 255, blue: 0xD2 / 255, alpha: 0.32)
                : NSColor(srgbRed: 0x1F / 255, green: 0x29 / 255, blue: 0x33 / 255, alpha: 0.30)
        }

        /// Nền dòng được Mark (FR-SRCH-107).
        public static let markLine = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(srgbRed: 0x4D / 255, green: 0x3F / 255, blue: 0x11 / 255, alpha: 1)
                : NSColor(srgbRed: 0xFF / 255, green: 0xF1 / 255, blue: 0xC2 / 255, alpha: 1)
        }

        /// Chín màu đánh dấu độc lập (FR-SRCH-107: "bookmark tối thiểu 9 màu độc lập").
        ///
        /// Ba điều quyết định bảng màu này, theo thứ tự quan trọng:
        ///
        /// 1. **Màu 0 là `mark/line`**, không đặt màu mới: UI/UX §2 đã chuẩn hoá token ấy và
        ///    đó là màu người dùng gặp khi bấm "Đánh dấu" mà không chọn gì.
        /// 2. **Đây là màu NỀN sau chữ, không phải màu chữ.** Nên tám màu còn lại lấy sắc từ
        ///    `markHuesLight` / `markHuesDark` rồi hạ xuống dạng nền nhạt: chữ vẫn phải đọc
        ///    được trên đó, nếu không thì "đánh dấu" thành "che mất".
        /// 3. **Phân biệt được khi đứng cạnh nhau**, vì cả điểm của chín màu là đánh dấu ba
        ///    pattern rồi so chúng trên cùng một màn hình.
        ///
        /// Dùng alpha thay vì màu đặc: nền vùng soạn thảo khác nhau giữa hai theme, và pha
        /// bằng alpha thì màu tự hoà theo nền thay vì phải bảo trì mười tám hằng số.
        public static let markColors: [NSColor] = {
            var colors: [NSColor] = [markLine]
            for index in 0 ..< 8 {
                colors.append(NSColor(name: nil) { appearance in
                    let hue = appearance.isDark ? markHuesDark[index] : markHuesLight[index]
                    return hue.withAlphaComponent(appearance.isDark ? 0.30 : 0.24)
                })
            }
            return colors
        }()

        /// TÁM sắc riêng biệt cho màu 1…8 — không phải sáu sắc lặp lại hai vòng.
        ///
        /// Bản đầu dùng sáu sắc rainbow rồi lặp vòng hai ở alpha thấp hơn cho ba màu cuối.
        /// Bài tự kiểm "chín màu phân biệt được" bắt ngay: ở theme sáng, hai màu cuối chỉ cách
        /// nhau **11/255** sau khi pha lên nền — mắt thường nhìn ra một màu. Lặp sắc rồi hạ
        /// alpha là cách chắc chắn làm hai màu hội tụ về màu nền.
        ///
        /// Sáu sắc đầu là bảng rainbow CSV (đã kiểm WCAG AA), thêm cam thương hiệu và một sắc
        /// xám lam để đủ tám mà vẫn cách nhau trên vòng màu.
        private static let markHuesLight: [NSColor] = rainbowLight + [
            NSColor(srgbRed: 0xC2 / 255, green: 0x4E / 255, blue: 0x08 / 255, alpha: 1),
            NSColor(srgbRed: 0x55 / 255, green: 0x62 / 255, blue: 0x70 / 255, alpha: 1),
        ]

        private static let markHuesDark: [NSColor] = rainbowDark + [
            NSColor(srgbRed: 0xFF / 255, green: 0x9E / 255, blue: 0x5E / 255, alpha: 1),
            NSColor(srgbRed: 0x8F / 255, green: 0xA3 / 255, blue: 0xB8 / 255, alpha: 1),
        ]

        /// Tên đọc được của chín màu — dùng cho menu và VoiceOver (NFR-USE-03).
        public static let markColorNames = [
            L("Vàng (mặc định)"), L("Xanh dương"), L("Xanh lá"), L("Vàng đất"), L("Tím"),
            L("Hồng"), L("Xanh ngọc"), L("Cam"), L("Xám lam"),
        ]

        /// Màu cho từng loại token cú pháp (FR-FMT-501).
        ///
        /// UI/UX v2.0 chưa quy định bảng này — Style Configurator là việc của Phase 2
        /// (FR-UI-801). Ba nguyên tắc tự đặt, ghi ra để sau này Style Configurator kế thừa:
        ///
        /// 1. **Phần lớn chữ KHÔNG màu.** Tô mọi thứ là không tô gì: mắt không còn chỗ nghỉ
        ///    và cái quan trọng chìm nghỉm. `variable`, `property`, `punctuation` giữ màu chữ
        ///    thường; chỉ những loại thật sự đáng nhìn mới có màu riêng.
        /// 2. **Lấy sắc từ bảng rainbow CSV**, đã kiểm WCAG AA trên nền vùng soạn thảo ở cả
        ///    hai theme. Không bịa sắc mới cho một tính năng.
        /// 3. **Tránh tông CAM.** UI/UX §2.1 dành cam cho nhận diện và hành động; chữ cam
        ///    trong mã nguồn sẽ lẫn với caret, với vùng chọn và với nút chính.
        ///
        /// Tên capture của tree-sitter phân cấp bằng dấu chấm ("keyword.function",
        /// "string.special"). Chỉ lấy phần TRƯỚC dấu chấm đầu tiên: hai mươi grammar đặt tên
        /// nhánh con khác nhau, và bám theo từng tên là tự nhận việc bảo trì vô tận.
        public static func syntax(_ scope: String) -> NSColor? {
            let root = scope.split(separator: ".").first.map(String.init) ?? scope
            switch root {
            case "comment": return syntaxComment
            case "string", "character": return rainbow(1)      // xanh lá
            case "number", "float", "boolean", "constant": return rainbow(2)   // vàng đất
            case "keyword", "conditional", "repeat", "include", "exception", "preproc":
                return rainbow(3)                              // tím
            case "function", "method", "constructor": return rainbow(0)        // xanh dương
            case "type", "class", "namespace": return rainbow(5)               // xanh ngọc
            case "tag", "attribute", "label": return rainbow(4)                // hồng
            case "escape": return rainbow(4)
            default: return nil                                // giữ màu chữ thường
            }
        }

        /// Chú thích: đọc được nhưng lùi hẳn về sau. Cùng tinh thần với `invisibleInk`.
        public static let syntaxComment = NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(srgbRed: 0xE7 / 255, green: 0xDC / 255, blue: 0xD2 / 255, alpha: 0.52)
                : NSColor(srgbRed: 0x1F / 255, green: 0x29 / 255, blue: 0x33 / 255, alpha: 0.50)
        }

        /// Màu của cột thứ `index`, lặp tuần hoàn qua sáu sắc (FR-CSV-402).
        ///
        /// Dựng SẴN sáu màu động một lần, không tạo mới mỗi lần gọi.
        ///
        /// `NSColor(name: nil) { … }` tạo một đối tượng mới mỗi lần, và hai đối tượng như vậy
        /// KHÔNG bằng nhau kể cả khi cùng sinh ra một sắc. Hệ quả trên màn hình thì không có,
        /// nhưng mọi phép so màu đều sai — bài tự kiểm báo "cột 0 đổi màu giữa các hàng" trong
        /// khi mắt nhìn thấy cùng một màu.
        public static func rainbow(_ index: Int) -> NSColor {
            let count = rainbowDynamic.count
            return rainbowDynamic[((index % count) + count) % count]
        }

        private static let rainbowDynamic: [NSColor] = (0 ..< 6).map { index in
            NSColor(name: nil) { appearance in
                let palette = appearance.isDark ? rainbowDark : rainbowLight
                return palette[index % palette.count]
            }
        }

        /// Sáu màu cột CSV, lặp tuần hoàn theo CHỈ SỐ CỘT LOGIC sau khi parse RFC 4180 —
        /// không theo vị trí ký tự, nên quoted field không làm lệch màu (FR-CSV-402).
        public static let rainbowLight: [NSColor] = [
            NSColor(srgbRed: 0x0B / 255, green: 0x62 / 255, blue: 0xC4 / 255, alpha: 1),
            NSColor(srgbRed: 0x0A / 255, green: 0x8F / 255, blue: 0x6F / 255, alpha: 1),
            NSColor(srgbRed: 0x7A / 255, green: 0x6A / 255, blue: 0x00 / 255, alpha: 1),
            NSColor(srgbRed: 0x8A / 255, green: 0x3E / 255, blue: 0xC4 / 255, alpha: 1),
            NSColor(srgbRed: 0xC0 / 255, green: 0x29 / 255, blue: 0x59 / 255, alpha: 1),
            NSColor(srgbRed: 0x2E / 255, green: 0x7D / 255, blue: 0xA1 / 255, alpha: 1),
        ]

        public static let rainbowDark: [NSColor] = [
            NSColor(srgbRed: 0x57 / 255, green: 0xA8 / 255, blue: 0xFF / 255, alpha: 1),
            NSColor(srgbRed: 0x3F / 255, green: 0xD6 / 255, blue: 0xAB / 255, alpha: 1),
            NSColor(srgbRed: 0xE4 / 255, green: 0xCB / 255, blue: 0x4A / 255, alpha: 1),
            NSColor(srgbRed: 0xC8 / 255, green: 0x8A / 255, blue: 0xFF / 255, alpha: 1),
            NSColor(srgbRed: 0xFF / 255, green: 0x7B / 255, blue: 0xA1 / 255, alpha: 1),
            NSColor(srgbRed: 0x6F / 255, green: 0xC7 / 255, blue: 0xE8 / 255, alpha: 1),
        ]
    }

    public enum Font {
        /// Vùng soạn thảo: SF Mono → Menlo (fallback), 13 pt, line-height 1.6.
        public static func editor(size: CGFloat = 13) -> NSFont {
            NSFont(name: "SF Mono", size: size)
                ?? NSFont(name: "Menlo", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }

        public static let editorLineHeightMultiple: CGFloat = 1.6
        /// Toàn bộ chrome, hộp thoại, panel.
        public static let ui = NSFont.systemFont(ofSize: 13)
        /// Status bar, chú thích, đếm kết quả.
        public static let caption = NSFont.systemFont(ofSize: 11)
        /// Ô nhập pattern, path, giá trị field.
        public static func monoInline(size: CGFloat = 12) -> NSFont { editor(size: size) }
    }

    /// Lưới 4 pt — mọi padding/margin là bội của 4 (UI/UX §2.3).
    public enum Metrics {
        public static let grid: CGFloat = 4
        public static let listRowHeight: CGFloat = 24
        public static let csvRowHeightCompact: CGFloat = 22
        public static let csvRowHeightComfortable: CGFloat = 28
        public static let statusBarHeight: CGFloat = 24
        public static let cornerPanel: CGFloat = 10
        public static let cornerControl: CGFloat = 7
        public static let cornerChip: CGFloat = 6
        /// Hit-target tối thiểu cho mọi control chuột (UI/UX §10).
        public static let minimumHitTarget: CGFloat = 24

        public static func spacing(_ multiple: CGFloat) -> CGFloat { grid * multiple }
    }

    /// Thời lượng chuyển động (UI/UX §12). Trả 0 khi bật Reduce Motion (NFR-USE-03).
    public enum Motion {
        public static var reduceMotion: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }

        public static var panel: TimeInterval { reduceMotion ? 0 : 0.16 }
        public static var scrollToMatch: TimeInterval { reduceMotion ? 0 : 0.22 }
        public static var flashMatch: TimeInterval { reduceMotion ? 0 : 0.40 }
        public static var dirtyDotFade: TimeInterval { reduceMotion ? 0 : 0.20 }
    }
}

extension NSView {

    /// Đặt nền của layer theo màu chủ đề, giải màu TRONG appearance đang có hiệu lực.
    ///
    /// **`.cgColor` là một ẢNH CHỤP.** `NSColor` của dự án là màu động: nó có bản sáng và bản
    /// tối, và `draw(_:)` giải nó lại ở mỗi lần vẽ nên luôn đúng. Nhưng `layer.backgroundColor`
    /// nhận một `CGColor` — một màu cụ thể, đã chốt. Gán một lần lúc dựng view thì nó đứng
    /// nguyên khi người dùng đổi theme, trong khi mọi thứ vẽ bằng `draw(_:)` đổi theo.
    ///
    /// Hậu quả: đổi theme trong Cài đặt (`window?.appearance = …`) thì mọi nền dựng bằng layer
    /// giữ nguyên màu cũ, trong khi phần vẽ bằng `draw(_:)` đổi theo — cửa sổ thành hai nửa hai
    /// màu. Mười một view trong app dựng nền theo lối ấy và không view nào cập nhật lại.
    ///
    /// **Cách tìm ra thì đáng kể lại, vì tôi suýt kết luận sai.** Ảnh `--capture` cho cảnh `csv`
    /// nền tối còn cảnh `trong` nền trắng, và tôi đọc đó là "bảng CSV không theo theme". Sai:
    /// vùng soạn thảo trắng ở cảnh `trong` là chỗ CHƯA ĐƯỢC VẼ — `cacheDisplay` không bắt được
    /// lớp TextKit, đúng như `WindowCapture.write` đã ghi. Lỗi `.cgColor` là có thật, nhưng bằng
    /// chứng cho nó là bài tự kiểm đọc màu layer dưới hai appearance, không phải tấm ảnh ấy.
    ///
    /// Dùng CẶP với `viewDidChangeEffectiveAppearance()`: gọi lúc dựng là chưa đủ.
    func applyLayerBackground(_ color: NSColor) {
        wantsLayer = true
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = color.cgColor
        }
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
