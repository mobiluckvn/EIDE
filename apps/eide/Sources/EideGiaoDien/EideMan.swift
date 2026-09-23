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
/// Lượt nạp bị một lượt mới thay thế — không phải lỗi, chỉ là tín hiệu rút lui.
struct LoiNapCu: Error {}

@MainActor
open class EideManCoSo: NSView {

    /// Tiền tố kỹ thuật trong `EideManHinhDS` — cũng là khoá tra năng lực đứng sau màn.
    open class var tien: String { "" }

    /// Nạp dữ liệu. Lỗi ném ra từ đây được lớp cơ sở bắt và hiện thành trạng thái rỗng CÓ LÝ DO.
    open func napDuLieu(_ goi: @escaping EideGoi) async throws {}

    /// **`seq` sổ cái tại lần vẽ gần nhất** — UXC-31 §7.2.
    ///
    /// Không dùng để phát hiện nhảy quãng: `seq` là số thứ tự TOÀN CỤC của sổ cái, còn mỗi màn
    /// chỉ nghe vài loại sự kiện, nên một màn thấy `seq` 5 rồi 11 là chuyện bình thường. Phép
    /// phát hiện nhảy quãng vì thế nằm ở `EidePhien`, nơi nghe đủ mọi loại.
    ///
    /// Con số này là MỐC NƯỚC: "màn đang hiện trạng thái tính tới seq bao nhiêu" — thứ mà
    /// §7.2 gọi là "bấm = query lại **từ seq đã có**".
    public internal(set) var seqCuoi = 0

    /// Áp một sự kiện vào màn đang MỞ — UXC-31 §7.3 ("vẽ lại đúng phần liên quan").
    ///
    /// Trả `true` nghĩa là màn đã tự cập nhật phần liên quan tại chỗ. Trả `false` — mặc định —
    /// nghĩa là màn chưa biết vẽ riêng phần ấy, và bên gọi sẽ nạp lại CHÍNH MÀN NÀY (không phải
    /// cả cửa sổ).
    ///
    /// Mặc định là `false` chứ không phải "tự nạp lại": một lớp cơ sở tự ý nạp lại sẽ giấu mất
    /// việc màn con chưa hiện thực diff render, và §7.3 tồn tại chính vì nạp lại cả màn là thứ
    /// cần tránh. Để `false` thì đếm được còn bao nhiêu màn chưa làm phần ấy.
    open func apDung(_ ten: String, _ p: [String: Any]) -> Bool { false }

    /// Người vừa gõ một phím vào một vùng soạn thảo của màn — §2D.2(b).
    ///
    /// Nằm ở lớp cơ sở chứ không riêng S14: "editor" theo nghĩa của §2D.2 là bất kỳ chỗ nào
    /// người đang viết dài, và màn nào mọc thêm một vùng như thế sau này cũng cần cùng luật.
    public var onNguoiGo: (() -> Void)?

    /// Mở một màn KHÁC — tiền tố màn trong `EideManHinhDS`. [DEV-185]
    ///
    /// Nằm ở lớp cơ sở vì "bấm được sang đúng màn" là yêu cầu của nhiều màn, không riêng S1:
    /// một con số tổng hợp mà không bấm vào được thì người đọc phải tự đi tìm chỗ xem chi tiết,
    /// và họ đoán sai thì bỏ luôn. Màn không được tự gọi `EidePhien` — nó không biết phiên nào
    /// đang giữ mình; phiên gắn móc này lúc dựng màn.
    public var onMoMan: ((String) -> Void)?

    /// Thư mục dự án đang mở. [DEV-189]
    ///
    /// Phiên biết đường dẫn này từ lúc `moDuAn`, nên màn KHÔNG phải đi hỏi lõi. Trước 23/09/2026
    /// màn Trình soạn thảo hỏi `project.status.report["path"]` — một trường **không tồn tại**:
    /// PROJECT-08 khai `report` gồm `features, gates_open, undo_items, cost_today, autonomy,
    /// target`, không có `path`. Hệ quả là S14 hiện trạng thái rỗng *"chưa biết thư mục dự án"*
    /// trên MỌI dự án, tức màn chưa bao giờ chạy — và bộ dò nội dung xếp nó vào nhóm "dự án
    /// chưa có dữ liệu" nên lỗi sống sót qua nhiều lượt đo.
    public var duAnGoc: String?

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
    /// Số thế hệ nạp. Một lượt nạp CŨ không được ghi vào màn của lượt mới. [DEV-164]
    ///
    /// `nap` mở đầu bằng `xoa()`, nên hai lượt chồng nhau đánh nhau trên cùng một cây khung
    /// nhìn: lượt sau xoá sạch những gì lượt trước vừa vẽ, rồi lượt trước tỉnh dậy và vẽ tiếp
    /// vào màn của lượt sau.
    ///
    /// Đo 22/09/2026 bằng ảnh chụp cửa sổ thật giữa một lượt CNC: màn Tổng quan hiện `Đang
    /// đọc…` (của lượt B) cạnh bảng `NGÂN SÁCH MÔ HÌNH` (của lượt A), và **thiếu hẳn** bảng
    /// `PHIÊN LÀM VIỆC` — đúng dấu vết của cuộc đua ấy. Nhãn chờ không bao giờ tắt vì lượt A
    /// gỡ nhãn của CHÍNH NÓ, thứ `xoa()` đã tháo ra từ lâu.
    ///
    /// Trước [DEV-154] hiếm khi xảy ra vì mọi lời gọi xếp hàng một. Từ khi gọi song song được,
    /// `veLaiManDangMo` và `_henNapLai` dễ dàng chạm vào một màn còn đang nạp.
    private var theHe = 0

    /// Thế hệ của lượt nạp đang chạy, đi theo TASK chứ không theo đối tượng.
    ///
    /// `@TaskLocal` là thứ duy nhất làm được: `doc()` được gọi từ bên trong `napDuLieu` của một
    /// lượt nạp cụ thể, và nó cần biết mình thuộc lượt nào — một biến của màn thì luôn mang giá
    /// trị của lượt MỚI NHẤT, tức đúng thứ không phân biệt được.
    @TaskLocal static var theHeCuaToi: Int = -1

    public final func nap(_ goi: @escaping EideGoi) async {
        theHe += 1
        let cua_toi = theHe
        await EideManCoSo.$theHeCuaToi.withValue(cua_toi) {
            await _nap(goi, cua_toi)
        }
    }

    private func _nap(_ goi: @escaping EideGoi, _ cua_toi: Int) async {
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
        } catch is LoiNapCu {
            return          // lượt mới đã tiếp quản — rút lui lặng lẽ, không dọn gì
        } catch {
            rong(vi: "không đọc được: \(error)", buocKe: "kiểm tra daemon còn sống, rồi mở lại màn")
        }
        msTong = (ProcessInfo.processInfo.systemUptime - t0) * 1000
        // Lượt nạp CŨ thì rút lui lặng lẽ: nó vừa vẽ vào màn của lượt mới, và dọn thêm ở đây
        // sẽ xoá cả thứ của lượt mới. Thứ nó vẽ nhầm đã có `xoa()` của lượt sau lo.
        guard cua_toi == theHe else { return }
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
        // DỪNG một lượt nạp đã CŨ, ngay sau `await`. [DEV-164]
        //
        // Không có chỗ này thì lượt cũ tỉnh dậy và vẽ tiếp vào màn của lượt mới — đo được trên
        // màn Tổng quan: bảng `NGÂN SÁCH` của lượt A nằm cạnh nhãn `Đang đọc…` của lượt B, và
        // bảng `PHIÊN LÀM VIỆC` biến mất vì `xoa()` của B đã tháo nó ra.
        //
        // Ném chứ không `return`: `napDuLieu` của mỗi màn viết thẳng một mạch, không có chỗ nào
        // kiểm giá trị trả về, nên chỉ một ngoại lệ mới cuốn được cả mạch ấy về.
        try _dungNeuCu()
        return try EideKetQua.boc(r, ten)
    }

    /// Ném `LoiNapCu` nếu lượt nạp này đã bị một lượt mới thay thế.
    func _dungNeuCu() throws {
        let t = EideManCoSo.theHeCuaToi
        if t >= 0 && t != theHe { throw LoiNapCu() }
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
    /// Ô bấm được của bảng: `(hàng, cột)` → việc phải làm. Rỗng = bảng thường.
    ///
    /// Đặt ở lớp cơ sở chứ không ở từng màn vì `bang()` là chỗ DUY NHẤT dựng bảng, và một màn
    /// tự dựng bảng riêng để có ô bấm được sẽ mất phép cắt `catVua`, mất tab stop, mất cả phép
    /// nhớ theo (cột, chữ) — ba thứ đã tốn hai lần đo để làm đúng.
    public typealias OBam = [BamO: () -> Void]

    /// Khoá của một ô. `struct` chứ không tuple: tuple không `Hashable` được.
    public struct BamO: Hashable {
        public let hang: Int
        public let cot: Int
        public init(_ hang: Int, _ cot: Int) {
            self.hang = hang
            self.cot = cot
        }
    }

    public func bang(cot: [(ten: String, rong: CGFloat)], dong: [[String]],
                     bam: OBam = [:]) {
        // Nhớ lại để `themHangDau` vẽ lại được mà không phải hỏi lõi — §7.3 diff render.
        bangCot = cot
        bangDong = dong
        let s = chuoiBang(cot: cot, dong: dong, bam: bam)
        guard !bam.isEmpty else {
            let n = NSTextField(labelWithAttributedString: s)
            n.lineBreakMode = .byWordWrapping
            n.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            them(n)
            bangNhan = n
            return
        }
        oBam = bam
        let tv = EideBangBamDuoc(chu: s)
        tv.onBam = { [weak self] o in
            guard let viec = self?.oBam[o] else { return false }
            viec()
            return true
        }
        them(tv)
        bangBamDuoc = tv
    }

    /// Cột và hàng của bảng gần nhất — §7.3.
    private var bangCot: [(ten: String, rong: CGFloat)] = []
    private var bangDong: [[String]] = []
    private var bangNhan: NSTextField?

    /// **Chèn một hàng lên ĐẦU bảng và vẽ lại — không hỏi lõi, không dựng lại khung nhìn.**
    ///
    /// Đây là diff render mà §7.3 đòi. Cách lùi (nạp lại cả màn) tốn một lời gọi `view.timeline`
    /// 0,47 s cộng một lượt dựng `NSTextField` ~200 ms; ở đây chỉ dựng lại CHUỖI (~6 ms đo trên
    /// bảng 120 hàng) rồi gán vào chính khung nhìn đang có.
    ///
    /// `toiDa` cắt từ đuôi: màn Nhật ký giữ 120 dòng mới nhất, và một bảng tự dài ra mãi theo
    /// mỗi sự kiện sẽ chậm dần trong đúng phiên làm việc người ta đang theo dõi nó.
    ///
    /// Trả `false` khi chưa có bảng nào để chèn — bên gọi khi ấy phải nạp lại như cũ.
    @discardableResult
    public func themHangDau(_ hang: [String], toiDa: Int) -> Bool {
        guard let n = bangNhan, !bangCot.isEmpty else { return false }
        bangDong.insert(hang, at: 0)
        if bangDong.count > toiDa { bangDong.removeLast(bangDong.count - toiDa) }
        n.attributedStringValue = chuoiBang(cot: bangCot, dong: bangDong, bam: [:])
        return true
    }

    /// Chuỗi thuộc tính của một bảng. Tách khỏi `bang()` để `themHangDau` dùng lại — hai phép
    /// dựng bảng khác nhau là hai bảng sẽ trông khác nhau sau vài lần cập nhật.
    public func chuoiBang(cot: [(ten: String, rong: CGFloat)], dong: [[String]],
                          bam: OBam) -> NSAttributedString {
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
                // Ô bấm được → `.link` mang toạ độ. Chỉ gắn cho ô CÓ trong bản đồ: gắn cả
                // bảng thì mọi ô đổi màu và gạch chân, và người dùng học rằng mọi thứ bấm được.
                if hangHienTai >= 0, bam[BamO(hangHienTai, i)] != nil,
                   let u = URL(string: "eide-o://\(hangHienTai)/\(i)") {
                    thuoc[.link] = u
                    thuoc[.foregroundColor] = EideToken.Mau.info
                    thuoc[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                s.append(NSAttributedString(
                    string: vua + (i < o.count - 1 ? "\t" : "\n"), attributes: thuoc))
            }
        }
        hangHienTai = -1
        hang(cot.map(\.ten), dam: true, nen: nil)
        for (i, d) in dong.enumerated() {
            hangHienTai = i
            hang(d, dam: false, nen: i % 2 == 1 ? EideToken.Mau.bg : nil)
        }
        hangHienTai = -1
        return s
    }

    // MỘT khung nhìn cho cả bảng, kể cả khi có ô bấm được.
    //
    // `NSTextView` chỉ dùng khi thật sự cần — nó nặng hơn `NSTextField` và bảng hộ chiếu 287
    // hàng là chỗ đã đo hai lần để xuống 33 ms. Dựng một khung nhìn MỖI Ô thì còn tệ hơn: hai
    // bản trước làm thế và cả hai hỏng bố cục, một bản còn làm màn Nhật ký mất hơn một giây để
    // vẽ. Nên ô bấm được là một `.link` trong CÙNG chuỗi thuộc tính, và `NSTextView` là thứ duy
    // nhất trong AppKit chuyển một `.link` thành cú bấm. Xem `bang()` ở trên.

    /// Hàng đang dựng — để `hang()` biết ô nào bấm được mà không phải truyền thêm tham số qua
    /// một closure lồng nhau.
    private var hangHienTai = -1
    private var oBam: OBam = [:]
    /// Bảng bấm được gần nhất — cho bài đo bấm vào đúng chỗ người bấm.
    public private(set) var bangBamDuoc: EideBangBamDuoc?

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

/// **Bảng có ô bấm được** — UXC-31 §8 S5 (cột NGUỒN), [DEV-133].
///
/// Một `NSTextView` cho CẢ bảng, không phải một khung nhìn mỗi ô. Đó là cùng quyết định mà
/// `EideManCoSo.bang` đã ghi: hai bản trước dựng một khung nhìn mỗi ô, cả hai hỏng bố cục, và
/// một bản làm màn Nhật ký mất hơn một giây để vẽ. Ô bấm được ở đây là một thuộc tính `.link`
/// trong cùng chuỗi — `NSTextView` chỉ là thứ duy nhất trong AppKit biến `.link` thành cú bấm.
///
/// **Không sửa được, nhưng chọn được.** Bảng là dữ liệu để đọc và để chép ra ngoài; khoá luôn
/// phép chọn sẽ lấy mất một việc người dùng làm thường xuyên với một bảng fact — chép một địa
/// chỉ thanh ghi sang chỗ khác.
@MainActor
public final class EideBangBamDuoc: NSTextView, NSTextViewDelegate {

    /// Trả `true` nếu ô ấy THẬT SỰ có việc để làm.
    ///
    /// `-> Bool` chứ không `-> Void`: `textView(_:clickedOnLink:at:)` phải nói cho AppKit
    /// biết cú bấm đã được xử lý hay chưa, và trả `true` cho một ô không có việc gì là nói
    /// dối — AppKit khi ấy thôi tìm người xử lý khác, và một ô chưa nối im lặng trông y hệt
    /// một ô đã nối.
    public var onBam: ((EideManCoSo.BamO) -> Bool)?

    /// **`init(frame:textContainer:)`, không phải `init(frame:)`.**
    ///
    /// `NSTextView` khai `init(frame:textContainer:)` là khởi tạo ĐÍNH DANH; gọi `super.init(
    /// frame:)` từ lớp con thì AppKit vẫn định tuyến về cái kia, và nó chết ở runtime với
    /// *"Use of unimplemented initializer"*. Biên dịch sạch, chết lúc dựng — tức chết ở đúng
    /// màn đầu tiên người dùng mở, chứ không ở bàn của tôi.
    public override init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: textContainer)
    }

    /// **Dựng hệ chữ TƯỜNG MINH.**
    ///
    /// `init(frame:textContainer: nil)` cho ra một `NSTextView` **không có** `textStorage`,
    /// `layoutManager` hay `textContainer` — chỉ `init(frame:)` mới dựng cả bộ, mà lớp con
    /// không gọi được nó (xem ghi chú ở khởi tạo đính danh). Hệ quả nếu để `nil`: mọi lệnh
    /// `textStorage?.setAttributedString(...)` là một lệnh KHÔNG LÀM GÌ, và bảng hiện ra rỗng
    /// trơn. Không lỗi, không cảnh báo — đo được vì bốn phép khẳng định về nội dung bảng cùng
    /// đỏ trong khi mọi nhãn ngoài bảng vẫn xanh.
    public convenience init(chu: NSAttributedString) {
        let kho = NSTextStorage()
        let dan = NSLayoutManager()
        let khung = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        kho.addLayoutManager(dan)
        dan.addTextContainer(khung)
        self.init(frame: .zero, textContainer: khung)
        isEditable = false
        isSelectable = true
        drawsBackground = false
        // Dàn chữ theo bề ngang thật của khung nhìn, không theo một bề ngang vô hạn: bảng dùng
        // tab stop tuyệt đối, và một `textContainer` không theo khung sẽ để cột cuối chạy ra
        // ngoài vùng cắt thay vì gấp dòng.
        isHorizontallyResizable = false
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
        textContainerInset = .zero
        delegate = self
        textStorage?.setAttributedString(chu)
        // Màu link mặc định của AppKit là xanh hệ thống — ghi đè để bảng dùng đúng bảng màu
        // sản phẩm, vì `--tu-kiem` so ảnh với bản demo.
        linkTextAttributes = [.foregroundColor: EideToken.Mau.info,
                              .underlineStyle: NSUnderlineStyle.single.rawValue,
                              .cursor: NSCursor.pointingHand]
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    /// `NSTextView` không tự cao theo nội dung trong một `NSStackView` — phải tự khai.
    public override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else { return super.intrinsicContentSize }
        lm.ensureLayout(for: tc)
        return NSSize(width: NSView.noIntrinsicMetric, height: lm.usedRect(for: tc).height)
    }

    public override func layout() {
        super.layout()
        invalidateIntrinsicContentSize()
    }

    public func textView(_ v: NSTextView, clickedOnLink link: Any,
                         at charIndex: Int) -> Bool {
        guard let o = Self.doc(link) else { return false }
        return onBam?(o) ?? false
    }

    /// `eide-o://<hàng>/<cột>` → toạ độ ô. Trả `nil` cho mọi thứ khác — một link lạ trong bảng
    /// KHÔNG được mở trình duyệt, vì bảng này chỉ chứa dữ liệu của dự án.
    public static func doc(_ link: Any) -> EideManCoSo.BamO? {
        let s = (link as? URL)?.absoluteString ?? (link as? String) ?? ""
        guard s.hasPrefix("eide-o://") else { return nil }
        let p = s.dropFirst("eide-o://".count).split(separator: "/")
        guard p.count == 2, let h = Int(p[0]), let c = Int(p[1]) else { return nil }
        return EideManCoSo.BamO(h, c)
    }

    /// Bấm vào một ô — cho bài đo đi đúng đường người dùng đi.
    @discardableResult
    public func bamDeTest(_ hang: Int, _ cot: Int) -> Bool {
        textView(self, clickedOnLink: URL(string: "eide-o://\(hang)/\(cot)")!, at: 0)
    }
}
