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

    /// Như `nangLuc`, nhưng **"dự án chưa có store" trả `nil` chứ không ném.**
    ///
    /// `store.sqlite` chỉ ra đời khi có thứ đầu tiên cần ghi vào, nên mọi năng lực đọc tri thức
    /// đều trả E2000 trên một dự án vừa tạo. Đó là câu *"chưa nhập gì"* — trạng thái thường gặp
    /// nhất của màn đầu tiên người dùng mở — chứ không phải một sự cố.
    ///
    /// Để nguyên thì màn hiện "không đọc được: … (E2000)" và đẩy người đi kiểm daemon, một việc
    /// không hỏng. Ba màn đã cần đúng phép này (S4, S7, S8) nên nó nằm ở đây chứ không chép lại
    /// ở từng màn — và `--tu-kiem` 6c phân biệt được "rỗng vì thiếu dữ liệu" với "rỗng vì lỗi"
    /// chính nhờ nó.
    ///
    /// Chỉ nuốt E2000, và chỉ để TRẢ VỀ `nil`: bên gọi vẫn phải tự nói ra trạng thái rỗng của
    /// mình bằng câu của mình.
    public func nangLucNeuCo(_ goi: @escaping EideGoi, _ id: String,
                             _ tham: [String: Any] = [:]) async throws -> [String: Any]? {
        do {
            return try await nangLuc(goi, id, tham)
        } catch let e as EideKetQua.Loi where e.maEide == "E2000" {
            return nil
        }
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
    ///
    /// **Chi phí nằm ở đâu, đo 20/09 trên bảng 287 hàng × 5 cột của màn Hộ chiếu chip:** dựng
    /// chuỗi có thuộc tính — kể cả phép cắt ô — mất **6 ms**; dựng `NSTextField` từ chuỗi ấy
    /// mất **~200 ms**. Nghĩa là thứ đắt là lượt dàn chữ của AppKit, và nó tăng theo BỀ RỘNG
    /// dòng chứ không chỉ theo số hàng: nới hai cột của màn ấy (208→264 và 92→136 pt) đẩy thời
    /// gian vẽ từ 33 ms lên 99 ms trước khi thêm bất cứ thứ gì khác.
    ///
    /// Ghi lại vì lần đầu tôi đoán sai chỗ: đã đi tối ưu phép cắt — nơi tốn 6 ms — trong khi
    /// 97% thời gian nằm ở dòng kế bên.
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
        // Nhớ lại phép cắt theo (cột, chữ). Một bảng hộ chiếu 287 hàng có 4 cột mà giá trị lặp
        // đi lặp lại — `vàng · chưa duyệt` 287 lần, `ATmega328P.atdf` 287 lần — nên không nhớ
        // thì cùng một phép đo bề rộng chạy hàng trăm lượt.
        var daCat: [String: String] = [:]
        func hang(_ o: [String], dam: Bool, nen: NSColor?) {
            for (i, van) in o.enumerated() {
                let phong = dam ? NSFont.boldSystemFont(ofSize: 11)
                                : (i == 0 ? EideToken.fontMono : EideToken.fontUI)
                var thuoc: [NSAttributedString.Key: Any] = [
                    .font: phong,
                    .foregroundColor: dam ? EideToken.Mau.faint : EideToken.Mau.text,
                    .paragraphStyle: kieu,
                ]
                if let nen { thuoc[.backgroundColor] = nen }
                // Tab trong dữ liệu sẽ ĐẨY LỆCH mọi cột sau nó — thay bằng dấu cách ngay ở đây,
                // vì một ô lệch cột đọc như một ô của hàng khác.
                //
                // Một ô DÀI HƠN CỘT làm đúng như thế mà không cần tab nào: điểm dừng tab là
                // mốc tuyệt đối, nên chữ tràn qua mốc sẽ đẩy ô kế sang mốc SAU đó, và cả phần
                // đuôi của hàng lệch đi một cột. Đo 20/09 trên màn Hộ chiếu chip:
                // `periph:AC/reg:DIDR1/field:AIN0D` dài hơn cột CHỦ THỂ, và hàng ấy hiện "vàng
                // · chưa duyệt" nằm dưới tiêu đề NGUỒN — đọc như một fact có nguồn tên "vàng".
                let tho = van.replacingOccurrences(of: "\t", with: " ")
                let khoa = "\(i)\u{1}\(dam ? 1 : 0)\u{1}\(tho)"
                let vua = daCat[khoa] ?? {
                    let x = Self.catVua(tho, rong: i < cot.count - 1 ? cot[i].rong : 0,
                                        font: phong)
                    daCat[khoa] = x
                    return x
                }()
                s.append(NSAttributedString(
                    string: vua + (i < o.count - 1 ? "\t" : "\n"), attributes: thuoc))
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

    /// Cắt một ô cho vừa cột, kèm `…`. `rong == 0` nghĩa là cột cuối — không cắt, vì nó chạy
    /// hết bề ngang còn lại và có `headIndent` lo phần gấp dòng.
    ///
    /// Đo bằng chính phông sẽ vẽ ra, không đếm ký tự: cột CHỦ THỂ dùng phông mono còn các cột
    /// sau dùng phông UI tỉ lệ, nên một ngưỡng tính theo số ký tự đúng ở cột này và sai ở cột kia.
    /// Hai đường tắt trước khi đo, vì `size(withAttributes:)` dựng một lượt dàn chữ mỗi lần gọi
    /// (~0,6 ms) và một bảng 287 hàng × 5 cột gọi nó hơn một nghìn lượt. Đo 20/09: phép cắt
    /// ngây thơ đẩy thời gian VẼ màn Hộ chiếu chip từ 33 ms lên 223 ms.
    ///
    /// 1. **Phông đều ô** (cột đầu của mọi bảng ở đây): bề rộng ĐÚNG BẰNG `số ô × bước tiến`,
    ///    không phải một ước lượng — nên cột đắt nhất thôi hẳn việc đo.
    /// 2. **Phông tỉ lệ**: `bước tiến lớn nhất` cho một chặn trên. Qua được chặn ấy là chắc
    ///    chắn vừa; chỉ phần còn lại mới phải đo, và đo bằng chia đôi chứ không bỏ từng ký tự.
    public static func catVua(_ s: String, rong: CGFloat, font: NSFont) -> String {
        guard rong > 0, !s.isEmpty else { return s }
        let so = CGFloat(s.count)
        let buoc = font.maximumAdvancement.width
        if font.isFixedPitch {
            guard so * buoc > rong else { return s }
            let giu = max(0, Int(rong / buoc) - 1)
            return giu == 0 ? "…" : String(s.prefix(giu)) + "…"
        }
        guard so * buoc > rong else { return s }

        let thuoc: [NSAttributedString.Key: Any] = [.font: font]
        func be(_ t: String) -> CGFloat { (t as NSString).size(withAttributes: thuoc).width }
        guard be(s) > rong else { return s }
        var thap = 0, cao = s.count
        while thap < cao {
            let giua = (thap + cao + 1) / 2
            if be(String(s.prefix(giua)) + "…") <= rong { thap = giua } else { cao = giua - 1 }
        }
        return thap == 0 ? "…" : String(s.prefix(thap)) + "…"
    }
}
