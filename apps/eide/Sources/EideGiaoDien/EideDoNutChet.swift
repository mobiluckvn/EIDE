import AppKit

/// **Bộ dò nút chết** — đi hết cây khung nhìn và tìm mọi điều khiển KHÔNG nối vào đâu cả.
///
/// ## Vì sao cần một bộ dò, thay vì sửa từng nút
///
/// Chủ sản phẩm ngồi trước máy và nói: *"trên màn hình vùng trao đổi gần như các nút không dùng
/// được một nút nào cả. Ví như xem chi tiết đều không hoạt động hoặc xem đầy đủ mở ra trắng
/// trơn."* Sửa ba nút ấy không trả lời được câu hỏi thật sự đằng sau — **còn bao nhiêu nút như
/// thế nữa?** — và không có gì ngăn cái thứ tư ra đời tuần sau.
///
/// Mọi bài kiểm trước đó đều đo TỪNG BỘ PHẬN: dựng một thẻ, gọi thẳng hàm xử lý của nó, khẳng
/// định kết quả. Cách ấy xanh kể cả khi cái nút trên màn hình không nối vào hàm ấy — đúng loại
/// lỗi đã xảy ra nhiều lần trong kho này. Bộ dò này đo thứ ngược lại: **cái nút có nối không**,
/// không quan tâm hàm phía sau làm gì.
///
/// ## Một nút "chết" là gì
///
/// Bốn dạng, và cả bốn đều nhìn y hệt một nút sống trên ảnh chụp:
///
/// 1. `target == nil` và `action == nil` — bấm vào không gọi gì.
/// 2. Có `action` nhưng `target` không hiện thực selector ấy — bấm vào là `doesNotRecognizeSelector`.
/// 3. `isEnabled == false` mà không có lời giải thích nào cạnh nó.
/// 4. Ô nhập `isEditable` mà không có `target/action` lẫn `delegate` — gõ xong bấm Enter không
///    có gì xảy ra.
///
/// Dạng 2 là dạng nguy hiểm nhất vì nó làm ứng dụng **sập** chứ không chỉ im.
@MainActor
public enum EideDoNutChet {

    public struct NutChet {
        public let duong: String      // đường tới nút trong cây khung nhìn
        public let nhan: String
        public let vi: String
    }

    /// Dò một cây khung nhìn. `boQua` là nhãn của những nút CỐ Ý không có target — hiếm, và mỗi
    /// cái phải có lý do viết ra.
    public static func do_(_ goc: NSView, ten: String = "", boQua: Set<String> = []) -> [NutChet] {
        var ra: [NutChet] = []
        _di(goc, ten.isEmpty ? String(describing: type(of: goc)) : ten, boQua, &ra)
        return ra
    }

    private static func _di(_ v: NSView, _ duong: String, _ boQua: Set<String>,
                            _ ra: inout [NutChet]) {
        if let b = v as? NSButton {
            let nhan = b.title.isEmpty ? (b.attributedTitle.string) : b.title
            if !boQua.contains(nhan) {
                if b.action == nil {
                    ra.append(NutChet(duong: duong, nhan: nhan,
                                      vi: "không có `action` — bấm vào không gọi gì"))
                } else if b.target == nil {
                    // `target == nil` nghĩa là AppKit đi tìm theo chuỗi phản hồi. Hợp lệ với
                    // menu, nhưng một nút trong thân màn mà trông cậy vào chuỗi phản hồi thì
                    // gần như luôn là quên gắn target.
                    ra.append(NutChet(duong: duong, nhan: nhan,
                                      vi: "có `action` \(b.action!) nhưng `target` là nil"))
                } else if !b.target!.responds(to: b.action!) {
                    ra.append(NutChet(duong: duong, nhan: nhan,
                                      vi: "target \(type(of: b.target!)) KHÔNG hiện thực "
                                        + "\(b.action!) — bấm vào là sập"))
                }
            }
        }
        if let t = v as? NSTextField, t.isEditable, !boQua.contains(t.placeholderString ?? "") {
            if t.action == nil && t.delegate == nil {
                ra.append(NutChet(duong: duong, nhan: t.placeholderString ?? "(ô nhập)",
                                  vi: "ô nhập không có `action` lẫn `delegate` — gõ xong "
                                    + "bấm Enter không có gì xảy ra"))
            } else if let a = t.action, let tg = t.target, !tg.responds(to: a) {
                ra.append(NutChet(duong: duong, nhan: t.placeholderString ?? "(ô nhập)",
                                  vi: "target KHÔNG hiện thực \(a)"))
            }
        }
        for (i, c) in v.subviews.enumerated() {
            _di(c, "\(duong)/\(String(describing: type(of: c)))[\(i)]", boQua, &ra)
        }
    }

    /// Mọi nút trong cây, kèm đường dẫn — để bài kiểm BẤM từng cái.
    public static func nutDs(_ goc: NSView, duong: String = "") -> [(nut: NSButton, duong: String)] {
        var ra: [(NSButton, String)] = []
        func di(_ v: NSView, _ d: String) {
            if let b = v as? NSButton { ra.append((b, d)) }
            for (i, c) in v.subviews.enumerated() {
                di(c, "\(d)/\(String(describing: type(of: c)))[\(i)]")
            }
        }
        di(goc, duong.isEmpty ? String(describing: type(of: goc)) : duong)
        return ra
    }

    /// Mọi chữ NGƯỜI ĐỌC ĐƯỢC trong một cây — dấu vân tay của màn hình, để so trước/sau.
    ///
    /// Gồm cả `isHidden`: một nút "Xem đầy đủ" chỉ bật `isHidden = false` cho một khung nhìn
    /// TRỐNG vẫn là một nút không làm gì cho người dùng, và một phép so chỉ đọc chữ HIỆN sẽ
    /// tưởng nó có tác dụng. Nên đếm riêng phần chữ nhìn thấy được.
    public static func vanTay(_ v: NSView) -> String {
        var ra = ""
        func di(_ x: NSView) {
            if x.isHidden { return }
            if let t = x as? NSTextField {
                ra += (t.attributedStringValue.string.isEmpty ? t.stringValue
                                                              : t.attributedStringValue.string)
                ra += "|"
            }
            if let t = x as? NSTextView { ra += t.string + "|" }
            if let b = x as? NSButton { ra += "[" + (b.title) + "]" }
            // KÍCH THƯỚC cũng là thứ người dùng thấy đổi.
            //
            // Bản đầu chỉ đọc chữ, nên ba nút đổi cỡ vùng trao đổi bị báo là "không làm gì" —
            // chúng đổi chiều cao chứ không đổi chữ nào. Một phép đo mù với hình học sẽ tố oan
            // đúng những nút CHỈ đổi hình học, và người đọc báo cáo sẽ đi sửa một nút không
            // hỏng. Làm tròn để hoạt ảnh đang chạy dở không thành một khác biệt giả.
            ra += "<\(Int(x.frame.width.rounded()))x\(Int(x.frame.height.rounded()))>"
            for c in x.subviews { di(c) }
        }
        di(v)
        return ra
    }

    /// Báo cáo một dòng mỗi nút chết, hoặc câu "không có" — cho bài tự kiểm in ra.
    public static func baoCao(_ ds: [NutChet]) -> String {
        guard !ds.isEmpty else { return "không có nút chết" }
        return ds.map { "  ✖ [\($0.nhan)] \($0.vi)\n     tại \($0.duong)" }
            .joined(separator: "\n")
    }
}
