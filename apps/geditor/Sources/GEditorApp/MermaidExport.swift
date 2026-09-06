import AppKit
import GEditorCore

/// Xuất sơ đồ ra PNG/SVG và chép vào clipboard — FR-MMD-007.
///
/// ## Rasterize từ SVG, KHÔNG chụp màn hình web view
///
/// `WKWebView.takeSnapshot` có sẵn và nghe hợp lý hơn. Nhưng nó chụp đúng những gì đang HIỆN:
/// cỡ phụ thuộc bề rộng panel, phần sơ đồ cuộn ra ngoài bị cắt, và ảnh mang theo cả nền của
/// trang. Ảnh xuất ra khi ấy đổi theo việc người dùng kéo panel rộng hay hẹp — một thứ không ai
/// đoán được và không ai muốn.
///
/// Vẽ lại từ chuỗi SVG thì cỡ do `viewBox` quyết định, nên **1x/2x/3x là ba tỷ lệ thật của cùng
/// một hình**, và ảnh không phụ thuộc trạng thái cửa sổ.
///
/// ## `NSImage(data:)` đọc SVG từ macOS 13
///
/// NFR-PORT-02 đòi chạy từ macOS 12. Trên máy cũ hàm này trả `nil` và chỗ gọi nói ra —
/// **xuất SVG vẫn dùng được**, chỉ mất PNG và clipboard. Mất một tiện nghi, không mất nội dung.
enum MermaidExport {

    /// Ba tỷ lệ đặc tả kê tên.
    enum Scale: Int, CaseIterable {
        case oneX = 1, twoX = 2, threeX = 3

        var label: String { "\(rawValue)x" }
    }

    /// Dữ liệu PNG của một sơ đồ.
    ///
    /// - Parameter background: `nil` = NỀN TRONG SUỐT. Mermaid không vẽ hình nền nào, nên trong
    ///   suốt là mặc định và nền đục mới là thứ phải thêm — ngược với trực giác, và đã kiểm
    ///   bằng cách mở một tệp SVG thật.
    static func png(from svg: String, scale: Scale, background: NSColor?) -> Data? {
        guard let size = MermaidSVG.size(of: svg) else { return nil }
        // Đặt `width`/`height` thật trước khi dựng ảnh: `width="100%"` của mermaid làm
        // `NSImage` nhận một cỡ vô nghĩa, và ảnh ra sai tỷ lệ.
        let sized = MermaidSVG.withExplicitSize(svg)
        guard let image = NSImage(data: Data(sized.utf8)) else { return nil }

        let pixels = size.pixels(scale: Double(scale.rawValue))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels.width, pixelsHigh: pixels.height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = NSSize(width: size.width, height: size.height)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = context
        // Vẽ theo `interpolation: .high` — hình gốc là vector nên phóng to vẫn nét, nhưng chữ
        // và viền vẫn qua một lượt lấy mẫu.
        context.imageInterpolation = .high
        let target = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        if let background {
            background.setFill()
            target.fill()
        }
        image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
        context.flushGraphics()
        return rep.representation(using: .png, properties: [:])
    }

    /// Chuỗi SVG để GHI RA TỆP.
    ///
    /// Khác chuỗi dùng để hiện trên màn hình ở hai chỗ: có `width`/`height` thật (nếu không,
    /// cùng một tệp mở trong Preview thì vừa màn hình mà dán vào Word thì bé bằng một dòng
    /// chữ), và có hình nền khi người dùng không chọn nền trong suốt.
    static func svgFile(from svg: String, background: NSColor?) -> String {
        var out = MermaidSVG.withExplicitSize(svg)
        if let background, let hex = hexString(background) {
            out = MermaidSVG.addingBackground(out, color: hex)
        }
        return out
    }

    /// Chép ảnh vào clipboard — *"dán thẳng vào Keynote/Slack"*.
    ///
    /// Ghi CẢ hai kiểu: PNG cho ứng dụng hiểu ảnh bitmap, và `NSImage` (tức TIFF) cho ứng dụng
    /// chỉ hỏi kiểu ảnh chung. Chỉ ghi PNG thì Keynote dán được còn vài ứng dụng cũ thì không;
    /// chỉ ghi TIFF thì Slack nhận một tệp nặng gấp mấy lần.
    ///
    /// KHÔNG ghi chuỗi SVG kèm theo. Nghe thì tiện, nhưng nhiều ứng dụng ưu tiên kiểu VĂN BẢN
    /// khi có cả hai — và người dùng bấm "chép ảnh" rồi dán ra một đống mã XML.
    @discardableResult
    static func copyToPasteboard(png: Data) -> Bool {
        guard let image = NSImage(data: png) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        pasteboard.writeObjects([image])
        return true
    }

    /// Màu nền theo theme đang chọn. `nil` khi người dùng muốn nền trong suốt.
    static func background(for theme: MermaidRenderer.Theme, transparent: Bool) -> NSColor? {
        guard !transparent else { return nil }
        switch theme {
        case .light: return .white
        case .dark: return NSColor(calibratedWhite: 0.15, alpha: 1)
        case .brand:
            return color(fromHex: MermaidBrand.load().background) ?? .white
        }
    }

    static func hexString(_ color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "#%02x%02x%02x",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded()))
    }

    static func color(fromHex hex: String) -> NSColor? {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }
}
