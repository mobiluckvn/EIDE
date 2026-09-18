import AppKit
import EideLoi

/// Cách một màn nói chuyện với lõi: MỘT hàm, không phải một đối tượng.
///
/// Màn không giữ tham chiếu tới daemon, tới phiên, hay tới khung. Nó nhận đúng khả năng "gọi
/// một phương thức JSON-RPC" và không có gì khác — nên không màn nào tự ý mở dự án, đổi mức tự
/// chủ, hay bấm hộ người dùng một cái nút ở vùng khác.
public typealias EideGoi = @MainActor (String, [String: Any]) async throws -> [String: Any]

/// **Lớp cơ sở của mọi màn.**
///
/// Bản cũ để mỗi màn tự dựng lấy header, tự quyết trạng thái rỗng, tự bắt lỗi — và kết quả là
/// 26 cách nói "không có dữ liệu", trong đó bốn cách là im lặng. Ở đây ba thứ ấy nằm trong lớp
/// cơ sở, nên một màn mới KHÔNG THỂ quên chúng.
@MainActor
open class EideManCoSo: NSView {

    /// Tiền tố kỹ thuật trong `EideManHinhDS` — cũng là khoá tra năng lực đứng sau màn.
    open class var tien: String { "" }

    /// Nạp dữ liệu. Lỗi ném ra từ đây được lớp cơ sở bắt và hiện thành trạng thái rỗng CÓ LÝ DO.
    open func napDuLieu(_ goi: @escaping EideGoi) async throws {}

    public let than = NSStackView()

    /// Thời gian lần nạp gần nhất, tách làm hai: chờ lõi, và vẽ. Tách vì hai con số ấy dẫn tới
    /// hai việc sửa hoàn toàn khác nhau, và gộp lại thì một màn chậm không nói được nó chậm ở
    /// đâu. Đo 18/09 trên sổ cái 9 128 bản ghi: `view.timeline` 0,47 s, vẽ 2,5 s.
    public private(set) var msGoi: Double = 0
    public private(set) var msTong: Double = 0

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        than.orientation = .vertical
        than.alignment = .leading
        than.spacing = 10
        than.translatesAutoresizingMaskIntoConstraints = false
        addSubview(than)
        NSLayoutConstraint.activate([
            than.topAnchor.constraint(equalTo: topAnchor),
            than.leadingAnchor.constraint(equalTo: leadingAnchor),
            than.trailingAnchor.constraint(equalTo: trailingAnchor),
            than.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    /// Nạp và tự lo phần hỏng. Màn KHÔNG được tự nuốt lỗi: một màn rỗng vì lỗi và một màn rỗng
    /// vì chưa có dữ liệu là hai trạng thái khác nhau, và người dùng phải phân biệt được.
    public final func nap(_ goi: @escaping EideGoi) async {
        xoa()
        // Nhãn chờ phải SỐNG QUA lời gọi. Bản đầu gọi `xoa()` ngay trong `do` — tức xoá nó ở
        // cùng một lượt chạy, trước cả `await` đầu tiên — nên nó chưa bao giờ hiện lên một điểm
        // ảnh nào. Hệ quả đo được 18/09: màn Nhật ký trên dự án có sổ cái lớn đứng TRẮNG TRƠN
        // hơn một giây, không tiêu đề phụ, không dòng chờ; nhìn y hệt một màn hỏng.
        let cho = _nhan("Đang đọc…", mau: EideToken.Mau.faint)
        them(cho)
        msGoi = 0
        let t0 = ProcessInfo.processInfo.systemUptime
        do {
            try await napDuLieu(goi)
        } catch {
            rong(vi: "không đọc được: \(error)", buocKe: "kiểm tra daemon còn sống, rồi mở lại màn")
        }
        msTong = (ProcessInfo.processInfo.systemUptime - t0) * 1000
        than.removeArrangedSubview(cho)
        cho.removeFromSuperview()
        if than.arrangedSubviews.isEmpty {
            rong(vi: "lõi trả về danh sách rỗng",
                 buocKe: "ra lệnh cho tác tử để có dữ liệu đầu tiên")
        }
    }

    // MARK: - đọc lõi

    /// Gọi lõi và bóc vỏ `CapabilityRun` — xem `EideKetQua.boc`.
    public func doc(_ goi: EideGoi, _ ten: String, _ tham: [String: Any] = [:]) async throws -> [String: Any] {
        let t0 = ProcessInfo.processInfo.systemUptime
        let r = try await goi(ten, tham)
        msGoi += (ProcessInfo.processInfo.systemUptime - t0) * 1000
        return try EideKetQua.boc(r, ten)
    }

    /// Gọi thẳng một năng lực qua `caps.invoke`.
    public func nangLuc(_ goi: @escaping EideGoi, _ id: String,
                        _ tham: [String: Any] = [:]) async throws -> [String: Any] {
        try await doc(goi, "caps.invoke", ["id": id, "params": tham])
    }

    // MARK: - khối dựng sẵn

    public func xoa() {
        for v in than.arrangedSubviews { than.removeArrangedSubview(v); v.removeFromSuperview() }
    }

    public func them(_ v: NSView) {
        than.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: than.widthAnchor).isActive = true
    }

    /// Trạng thái rỗng ĐÚNG HAI PHẦN — bất biến B5.
    public func rong(vi ly: String, buocKe: String) {
        them(_nhan("Màn này đang rỗng — vì: \(ly)", mau: EideToken.Mau.muted))
        them(_nhan("Bước kế tiếp: \(buocKe)", mau: EideToken.Mau.faint))
    }

    public func tieuDePhu(_ s: String) {
        let n = NSTextField(labelWithString: s)
        n.font = NSFont.boldSystemFont(ofSize: 10.5)
        n.textColor = EideToken.Mau.faint
        them(n)
    }

    private func _nhan(_ s: String, mau: NSColor) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        return n
    }

    /// Bảng chỉ đọc — MỘT khung nhìn cho CẢ bảng.
    ///
    /// Hai bản trước đều hỏng, và hỏng theo cùng một kiểu:
    ///
    /// 1. Mỗi ô một `NSTextField`: 120 hàng × 4 cột = 480 khung nhìn, màn Nhật ký mất hơn một
    ///    giây để vẽ.
    /// 2. Mỗi hàng một `NSStackView` bọc một nhãn có điểm dừng tab: ràng buộc bề rộng của nhãn
    ///    bị chính stack phá (ưu tiên nội bộ ≤ 999, không ghi log), nên hàng co về ~190 pt
    ///    trong khi chữ tràn ra ngoài — bảng bốn cột hiện thành bốn dòng chồng nhau. Đủ chữ,
    ///    nên nó trông như một lựa chọn trình bày xấu chứ không như một lỗi bố cục.
    ///
    /// Nay cả bảng là MỘT nhãn: điểm dừng tab lo cột, `headIndent` lo dòng gấp, và nền xen kẽ
    /// đi bằng thuộc tính `.backgroundColor` của từng đoạn. Không stack, không ràng buộc nào để
    /// phá, và số khung nhìn không phụ thuộc số hàng.
    public func bang(cot: [(ten: String, rong: CGFloat)], dong: [[String]]) {
        var moc: CGFloat = 0
        var dung: [NSTextTab] = []
        for c in cot.dropLast() {
            moc += c.rong + 10
            dung.append(NSTextTab(textAlignment: .left, location: moc))
        }
        let kieu = NSMutableParagraphStyle()
        kieu.tabStops = dung
        kieu.headIndent = moc
        kieu.lineBreakMode = .byWordWrapping
        kieu.paragraphSpacing = 3

        let s = NSMutableAttributedString()
        func hang(_ o: [String], dam: Bool, nen: NSColor?) {
            for (i, van) in o.enumerated() {
                var thuoc: [NSAttributedString.Key: Any] = [
                    .font: dam ? NSFont.boldSystemFont(ofSize: 11)
                               : (i == 0 ? EideToken.fontMono : EideToken.fontUI),
                    .foregroundColor: dam ? EideToken.Mau.faint : EideToken.Mau.text,
                    .paragraphStyle: kieu,
                ]
                if let nen { thuoc[.backgroundColor] = nen }
                // Tab trong dữ liệu sẽ ĐẨY LỆCH mọi cột sau nó — thay bằng dấu cách ngay ở đây,
                // vì một ô lệch cột đọc như một ô của hàng khác.
                s.append(NSAttributedString(
                    string: van.replacingOccurrences(of: "\t", with: " ")
                          + (i < o.count - 1 ? "\t" : "\n"),
                    attributes: thuoc))
            }
        }
        hang(cot.map(\.ten), dam: true, nen: nil)
        for (i, d) in dong.enumerated() {
            hang(d, dam: false, nen: i % 2 == 1 ? EideToken.Mau.bg : nil)
        }

        let n = NSTextField(labelWithAttributedString: s)
        n.lineBreakMode = .byWordWrapping
        n.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        them(n)
    }
}
