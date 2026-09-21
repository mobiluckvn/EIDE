import AppKit
import EideLoi
import PDFKit

/// **Khung xem tài liệu gốc có bôi sáng** — UXC-31 §8 S5 ("cột nguồn bấm mở ĐÚNG TRANG PDF kèm
/// bbox") và §8 S13; `view.doc_side_by_side` (VIEW-11). [DEV-133] nửa sau.
///
/// ## Vì sao KHÔNG đẩy sang Preview
///
/// `NSWorkspace` không có đường mở PDF ở một trang cho trước — Preview không nhận tham số
/// trang. Đẩy sang nó nghĩa là người dùng nhận một tệp 400 trang mở ở trang 1, rồi tự đi tìm
/// trang 42; và bbox thì mất hẳn. Cả hai thứ ấy chính là nội dung của mục này.
///
/// `PDFKit` là framework của hệ, không phải phụ thuộc mới: không thêm dòng nào vào
/// `Package.swift`.
///
/// ## Bôi sáng: chỉ vẽ khi BIẾT CHẮC phải vẽ thế nào
///
/// `bbox` trong store được ghi theo hai quy ước (`[x,y,w,h]` và `[x0,y0,x1,y1]`), và VIEW-11
/// nói ra quy ước nào qua `bbox_dang`. Gặp `"khong-ro"` thì **không vẽ** và nói rõ vì sao: một
/// vùng bôi sáng lệch chỗ tệ hơn không bôi, vì người dùng sẽ đối chiếu con số với một vùng
/// không phải nguồn của nó — và tin rằng mình vừa kiểm chứng.
@MainActor
public final class EideXemNguon: NSView {

    private let pdf = PDFView()
    private let nhan = NSTextField(wrappingLabelWithString: "")
    private var lop: EideLopBoiSang?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nhan.font = EideToken.fontUI
        nhan.textColor = EideToken.Mau.muted
        nhan.translatesAutoresizingMaskIntoConstraints = false
        pdf.autoScales = true
        pdf.displayMode = .singlePage
        pdf.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nhan)
        addSubview(pdf)
        NSLayoutConstraint.activate([
            nhan.topAnchor.constraint(equalTo: topAnchor),
            nhan.leadingAnchor.constraint(equalTo: leadingAnchor),
            nhan.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdf.topAnchor.constraint(equalTo: nhan.bottomAnchor, constant: 6),
            pdf.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdf.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdf.bottomAnchor.constraint(equalTo: bottomAnchor),
            pdf.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Chữ đang hiện — cho bài đo đọc.
    public var chuNhan: String { nhan.stringValue }
    /// Trang đang mở (1-based), `nil` khi chưa mở được gì.
    public var trangDangMo: Int? {
        guard let t = pdf.document, let p = pdf.currentPage else { return nil }
        return t.index(for: p) + 1
    }

    /// Mở vế TRÁI của `view.doc_side_by_side`.
    ///
    /// Trả `false` khi không mở được, và khi ấy `chuNhan` nói **vì sao** — không tệp, tệp không
    /// phải PDF, trang ngoài khoảng. Một khung trống không có lời là một khung người dùng đoán
    /// là sản phẩm hỏng.
    @discardableResult
    public func mo(_ trai: [String: Any]) -> Bool {
        lop?.removeFromSuperlayer()
        lop = nil
        pdf.document = nil

        let uri = ((trai["source"] as? [String: Any])?["uri"] as? String)
            ?? (trai["uri"] as? String) ?? ""
        guard !uri.isEmpty else {
            nhan.stringValue = "Fact này không có nguồn nào để mở."
            return false
        }
        guard !uri.contains("://") || uri.hasPrefix("file://") else {
            nhan.stringValue = "Nguồn là một địa chỉ mạng (\(uri)) — không mở trong khung này. "
                             + "Tải về rồi nhập ở màn Nhập tài liệu (S4)."
            return false
        }
        let duong = uri.hasPrefix("file://") ? String(uri.dropFirst(7)) : uri
        guard FileManager.default.fileExists(atPath: duong) else {
            nhan.stringValue = "Không tìm thấy tệp nguồn: \(duong)"
            return false
        }
        guard (duong as NSString).pathExtension.lowercased() == "pdf",
              let tl = PDFDocument(url: URL(fileURLWithPath: duong)) else {
            nhan.stringValue = "Nguồn không phải PDF đọc được: \((duong as NSString).lastPathComponent)"
            return false
        }
        pdf.document = tl

        let soTrang = EideManHoChieu.nguyen(trai["page"])
        // Trang trong `locator` đếm TỪ 1 như người đọc đếm; `PDFDocument` đếm từ 0. Lệch một
        // trang là lỗi không ai thấy trên tài liệu dày — nó vẫn mở ra một trang trông hợp lý.
        guard let n = soTrang, n >= 1, n <= tl.pageCount, let tr = tl.page(at: n - 1) else {
            nhan.stringValue = soTrang == nil
                ? "\((duong as NSString).lastPathComponent) — locator không ghi số trang."
                : "\((duong as NSString).lastPathComponent) — trang \(soTrang!) ngoài khoảng "
                  + "1…\(tl.pageCount)."
            return true
        }
        pdf.go(to: tr)

        let dang = (trai["bbox_dang"] as? String) ?? "khong-ro"
        let hop = Self.hinhChuNhat(trai["bbox"], dang: dang)
        if let hop {
            _boiSang(hop, trang: tr)
            nhan.stringValue = "\((duong as NSString).lastPathComponent) · trang \(n) · "
                             + "vùng nguồn đã bôi sáng"
        } else {
            nhan.stringValue = "\((duong as NSString).lastPathComponent) · trang \(n) · "
                             + Self.viSaoKhongBoi(trai["bbox"], dang: dang)
        }
        return true
    }

    /// `bbox` + `bbox_dang` → hình chữ nhật trong toạ độ TRANG PDF, hoặc `nil`.
    ///
    /// `nil` không phải lỗi: `"khong-ro"` nghĩa là VIEW-11 không kết luận được quy ước nào, và
    /// đoán ở đây là đặt vùng bôi sáng vào một chỗ có thể không phải nguồn.
    public static func hinhChuNhat(_ bbox: Any?, dang: String) -> NSRect? {
        guard let b = bbox as? [Any], b.count == 4 else { return nil }
        let v = b.compactMap { EideManHoChieu.nguyen($0).map(Double.init)
                               ?? ($0 as? Double) ?? Double("\($0)") }
        guard v.count == 4 else { return nil }
        switch dang {
        case "rong-cao": return NSRect(x: v[0], y: v[1], width: v[2], height: v[3])
        case "hai-goc":  return NSRect(x: v[0], y: v[1], width: v[2] - v[0], height: v[3] - v[1])
        default:         return nil
        }
    }

    public static func viSaoKhongBoi(_ bbox: Any?, dang: String) -> String {
        guard bbox != nil else { return "locator không ghi bbox — không có vùng nào để chỉ." }
        return "bbox ghi theo một quy ước KHÔNG rõ (`\(dang)`), nên không bôi sáng: một vùng "
             + "lệch chỗ tệ hơn không có vùng nào."
    }

    private func _boiSang(_ hop: NSRect, trang: PDFPage) {
        // `PDFAnnotation` chứ không vẽ đè lên khung nhìn: annotation sống trong toạ độ TRANG,
        // nên nó đi theo khi người dùng cuộn và phóng to. Một lớp vẽ trên khung nhìn phải tự
        // theo dõi hai thứ ấy, và sẽ trượt ở đúng lúc người ta nhìn kỹ nhất.
        let a = PDFAnnotation(bounds: hop, forType: .highlight, withProperties: nil)
        a.color = EideToken.Mau.warn.withAlphaComponent(0.45)
        trang.addAnnotation(a)
        // Cuộn tới vùng ấy: mở đúng trang mà vùng nguồn nằm dưới đáy vẫn là một lần đi tìm.
        pdf.go(to: hop, on: trang)
    }
}

/// Lớp vẽ dự phòng — giữ tên để `mo()` dọn được mọi thứ nó từng thêm.
@MainActor
final class EideLopBoiSang: CALayer {}
