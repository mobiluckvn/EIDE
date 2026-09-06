import Foundation

/// Đọc và sửa nhẹ chuỗi SVG mà mermaid trả về — FR-MMD-007.
///
/// ## Cỡ thật lấy từ `viewBox`, không lấy từ `width`
///
/// SVG của mermaid mở đầu như thế này:
///
/// ```
/// <svg id="g1" width="100%" style="max-width: 133.09375px;" viewBox="0 0 133.09375 363.875" …>
/// ```
///
/// `width="100%"` không nói gì về cỡ; `max-width` chỉ nói bề NGANG. Chỉ `viewBox` mang cả hai
/// chiều, và nó là thứ mọi trình vẽ dùng để tính tỷ lệ. Đây là chỗ đoán sai thì ảnh PNG xuất ra
/// méo hoặc bé tí — nên nó được ĐỌC từ một tệp SVG thật rồi mới viết mã, chứ không suy từ trí nhớ.
///
/// ## Nền mermaid TRONG SUỐT sẵn, nên "nền trong suốt" KHÔNG phải việc phải làm
///
/// Ngược với trực giác: mermaid không vẽ hình chữ nhật nền nào, nên tuỳ chọn *"nền trong suốt"*
/// của FR-MMD-007 là mặc định, còn thứ phải làm thêm là **nền ĐỤC**. Cũng là điều chỉ biết được
/// bằng cách mở một tệp SVG thật ra xem.
public enum MermaidSVG {

    public struct Size: Equatable, Sendable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }

        /// Cỡ ảnh raster ở một tỷ lệ, làm tròn LÊN.
        ///
        /// Làm tròn lên chứ không xuống: làm tròn xuống cắt mất một hàng điểm ảnh ở mép phải và
        /// mép dưới, và với một sơ đồ có viền thì hàng ấy chính là cái viền.
        public func pixels(scale: Double) -> (width: Int, height: Int) {
            (max(1, Int((width * scale).rounded(.up))),
             max(1, Int((height * scale).rounded(.up))))
        }
    }

    /// Cỡ tự nhiên của sơ đồ. `nil` khi không đọc được `viewBox`.
    public static func size(of svg: String) -> Size? {
        guard let value = attribute("viewBox", in: svg) else { return nil }
        let parts = value.split(whereSeparator: { $0 == " " || $0 == "," })
            .compactMap { Double($0) }
        guard parts.count == 4, parts[2] > 0, parts[3] > 0 else { return nil }
        return Size(width: parts[2], height: parts[3])
    }

    /// Thêm một hình chữ nhật NỀN phủ kín sơ đồ.
    ///
    /// Chèn ngay sau thẻ `<svg …>` để nó nằm DƯỚI mọi thứ khác — SVG vẽ theo thứ tự tài liệu,
    /// nên một hình nền đặt ở cuối sẽ che mất cả sơ đồ.
    ///
    /// Dùng `viewBox` chứ không dùng `width="100%"`: bên trong `<svg>`, `100%` tính theo khung
    /// nhìn của trình vẽ, mà khung ấy có thể khác cỡ tự nhiên khi ảnh bị co giãn.
    public static func addingBackground(_ svg: String, color: String) -> String {
        guard let close = svg.range(of: ">"), let size = size(of: svg) else { return svg }
        let rect = "<rect x=\"0\" y=\"0\" width=\"\(number(size.width))\" "
            + "height=\"\(number(size.height))\" fill=\"\(color)\"/>"
        return svg.replacingCharacters(in: close.upperBound ..< close.upperBound, with: rect)
    }

    /// Đặt `width`/`height` THẬT vào thẻ gốc.
    ///
    /// Cần cho tệp `.svg` xuất ra: `width="100%"` khiến ảnh co theo khung của thứ mở nó, nên
    /// cùng một tệp mở trong Preview thì vừa màn hình, dán vào Word thì bé bằng một dòng chữ.
    public static func withExplicitSize(_ svg: String, scale: Double = 1) -> String {
        guard let size = size(of: svg) else { return svg }
        var out = svg
        let width = number(size.width * scale)
        let height = number(size.height * scale)
        out = replacingAttribute("width", with: width, in: out)
        if attribute("height", in: out) != nil {
            out = replacingAttribute("height", with: height, in: out)
        } else if let close = out.range(of: ">") {
            out = out.replacingCharacters(
                in: close.lowerBound ..< close.lowerBound, with: " height=\"\(height)\"")
        }
        return out
    }

    // MARK: - Mảnh

    /// Giá trị một thuộc tính của thẻ `<svg>` MỞ ĐẦU.
    ///
    /// Chỉ nhìn tới dấu `>` đầu tiên: bên trong sơ đồ có hàng chục thẻ mang `width`, và lấy
    /// nhầm một cái trong số ấy cho ra một cỡ ảnh vô nghĩa.
    public static func attribute(_ name: String, in svg: String) -> String? {
        guard let close = svg.firstIndex(of: ">") else { return nil }
        let head = svg[svg.startIndex ..< close]
        guard let start = head.range(of: name + "=\"") else { return nil }
        guard let end = head[start.upperBound...].firstIndex(of: "\"") else { return nil }
        return String(head[start.upperBound ..< end])
    }

    static func replacingAttribute(_ name: String, with value: String, in svg: String) -> String {
        guard let close = svg.firstIndex(of: ">") else { return svg }
        let head = svg[svg.startIndex ..< close]
        guard let start = head.range(of: name + "=\""),
              let end = head[start.upperBound...].firstIndex(of: "\"") else { return svg }
        return svg.replacingCharacters(in: start.upperBound ..< end, with: value)
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e9
            ? String(Int(value)) : String(format: "%.4f", value)
    }
}
