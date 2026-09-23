import AppKit
import EideLoi

/// **Phiên làm việc** — nối daemon với khung. Chỗ DUY NHẤT hai bên biết về nhau.
///
/// `EideKhung` và các vùng của nó không gọi daemon; chúng nhận dữ liệu đã đọc sẵn và phát ra ý
/// định của người dùng. `EideDaemon` không biết gì về khung nhìn. Lớp này ở giữa.
///
/// Bản cũ không có lớp này: mỗi khung nhìn tự gọi `caps.invoke`, nên hai màn có thể hỏi cùng
/// một thứ theo hai cách và hiện hai kết quả khác nhau — và không ai đọc được luồng điều khiển
/// của cả cửa sổ ở một chỗ.
@MainActor
public final class EidePhien {

    public let khung: EideKhung
    private var daemon: EideDaemon?
    private var duAn: String?

    /// id năng lực → tên màn, từ `caps.list`. Dùng cho dòng phụ header và cho NT2 (tự mở màn).
    private var manCua: [String: String] = [:]
    private var motaCua: [String: String] = [:]

    /// Thẻ Run đang hiện, theo mã lượt chạy. Giữ ở ĐÂY chứ không trong dock: dock là nơi HIỆN
    /// bong bóng, còn "sự kiện này thuộc lượt chạy nào" là việc của lớp nối.
    private var theRun: [String: EideTheRun] = [:]

    /// Lần cuối nghe được daemon — nền của dải "Dữ liệu cũ" (B6).
    private var lucCuoiNghe = Date()
    private var nhipTim: Timer?
    /// Bộ xoay lệnh mẫu §3.4 — sống tối đa mười phút đầu.
    private var xoayMau: Timer?

    /// Nhịp tim và hạn dữ liệu cũ. Nhịp phải DÀY hơn hạn, nếu không thì hạn không đo được.
    public static let NHIP_TIM: TimeInterval = 1.0
    public static let HAN_CU: TimeInterval = 2.0

    public init(khung: EideKhung) {
        self.khung = khung
        _noiDay()
    }

    /// Số năng lực đã hiện thực mà registry trả về — dấu hiệu daemon nối thật hay chưa.
    public var soNangLuc: Int { manCua.count }

    // MARK: - khởi động

    /// Quét workspace: có dự án thì mở cái mới nhất, không có thì để nguyên màn chào.
    ///
    /// `project.list` sắp theo `last_open` giảm dần, nên phần tử đầu là dự án người vừa làm.
    /// Đây là chọn HỘ người dùng, nên nó phải nói ra mình vừa chọn gì — dòng đầu trong dock.
    public func khoiDong() async {
        let r = try? await EideDaemon.motLan(["project", "list"])
        guard let r, r.ma == 0, let ds = r.json?["projects"] as? [[String: Any]], !ds.isEmpty
        else {
            if let r, r.ma != 0 {
                khung.manChao.datTrangThai("Không chạy được `eide project list`: "
                                           + r.loi.trimmingCharacters(in: .whitespacesAndNewlines),
                                           ban: false)
            }
            return  // giữ màn chào — đúng trạng thái §3.1
        }
        guard let duong = ds[0]["path"] as? String else { return }
        khung.anManChao()
        await moDuAn(duong)
        if ds.count > 1 {
            khung.dock.themLuot(.heThong,
                "Mở dự án gần nhất trong \(ds.count) dự án của workspace.")
        }
    }

    /// Tạo dự án từ câu người gõ ở màn chào.
    ///
    /// `project.create` có thể trả `created=false` kèm `existing[]` khi thấy tên GẦN GIỐNG. Lúc
    /// ấy tuyệt đối không tự chọn: cái người dùng muốn có thể là dự án cũ, và tạo thêm bản thứ
    /// hai gần trùng tên là cách chắc chắn nhất để họ mất việc trong cái còn lại.
    public func taoDuAn(_ van: String, thuMuc: String? = nil) async {
        khung.manChao.datTrangThai("Đang tạo dự án…", ban: true)
        var tham = ["project", "new", van]
        if let thuMuc { tham += ["--dir", thuMuc] }
        guard let r = try? await EideDaemon.motLan(tham) else {
            return khung.manChao.datTrangThai("Không tìm thấy lệnh `eide` trên máy này.", ban: false)
        }
        guard r.ma == 0, let j = r.json, let duong = j["path"] as? String else {
            let loi = r.van.isEmpty ? r.loi : r.van
            return khung.manChao.datTrangThai(
                loi.trimmingCharacters(in: .whitespacesAndNewlines), ban: false)
        }
        if (j["created"] as? Bool) == false {
            let ten = (j["existing"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
            return khung.manChao.datTrangThai(
                "Workspace đã có dự án tên gần giống (\(ten.joined(separator: ", "))). "
                + "Gõ một tên khác, hoặc mở dự án cũ bằng `eide project list`.", ban: false)
        }
        khung.manChao.datTrangThai("", ban: false)
        khung.anManChao()
        await moDuAn(duong)
        lamQuen()
    }

    /// **§3.3 — sau khi tạo dự án: mở S1, chào, chỉ ĐÚNG BA THỨ.**
    ///
    /// Ba, không bốn. §3.3 viết thẳng "không tour dài", và lý do nằm ở chỗ người vừa gõ xong một
    /// câu mô tả dự án đang muốn xem chuyện gì xảy ra — không muốn đọc. Thứ tư trở đi là thứ họ
    /// lướt qua, và lướt qua một danh sách bốn mục thì họ lướt qua cả ba mục đầu.
    ///
    /// Mở S1 trước khi chào: câu chào nói về những thứ đang hiện trên màn hình, nên màn hình
    /// phải hiện rồi.
    func lamQuen() {
        moMan("Main", boiTacTu: false)
        khung.dock.batDauLamQuen(dongHo())
        khung.dock.themLuot(.tacTu, Self.chaoBaThu(soNangLuc: motaCua.isEmpty ? nil : motaCua.count))
        _batXoayMau()
    }

    /// Đúng ba thứ, theo đúng thứ tự §3.3: lệnh mẫu, ⌘K, Dừng khẩn.
    ///
    /// Số năng lực đếm TỪ REGISTRY của daemon đang nối, không chép cứng. Con số cũ là "244" và
    /// nó sai ngay hôm danh mục lên 245 — một câu chào nói sai một con số kiểm được là chỗ rẻ
    /// nhất để người dùng học rằng sản phẩm này không đáng tin về những con số nó đưa ra.
    ///
    /// `nil` khi chưa nạp xong registry: nói "danh mục năng lực" chung chung còn hơn in một số
    /// bịa ra.
    public static func chaoBaThu(soNangLuc: Int?) -> String {
        let n = soNangLuc.map { "\($0) năng lực" } ?? "danh mục năng lực"
        return "Dự án đã sẵn sàng. Ba thứ cần biết, hết:\n"
            + "1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.\n"
            + "2. ⌘K mở bảng lệnh — tìm \(n) và \(EideManHinhDS.tatCa.count) màn theo tên "
            + "hoặc mô tả.\n"
            + "3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào."
    }

    /// Bộ xoay lệnh mẫu của §3.4. Dừng hẳn khi hết mười phút — `xoayMau` trả `false`.
    private func _batXoayMau() {
        xoayMau?.invalidate()
        xoayMau = Timer.scheduledTimer(withTimeInterval: EideDock.XOAY_MOI, repeats: true) {
            [weak self] t in
            Task { @MainActor in
                guard let self else { return t.invalidate() }
                if !self.khung.dock.xoayMau(self.dongHo()) { t.invalidate() }
            }
        }
    }

    // MARK: - mở dự án

    /// Mở một dự án: bật daemon, đọc registry, dựng điều hướng.
    public func moDuAn(_ duong: String) async {
        await daemon?.dung()
        duAn = duong
        khung.thanhTren.datDuAn(duong)
        do {
            let d = try EideDaemon(duAn: duong)
            daemon = d
            await d.theoDoi { [weak self] ten, p in
                Task { @MainActor in self?._suKien(ten, p) }
            }
            try await _napRegistry(d)
            try await _moThat(d, duong)
            // ẨN MÀN CHÀO — sau khi `project.open` CHẠY XONG, không trước.
            //
            // Tới 22/09/2026 chỉ `taoDuAn` gọi `anManChao()`, nên mọi đường mở một dự án CÓ SẴN
            // (`--du-an`, `@mo` của bộ lái kịch bản, và nút mở dự án) đều để người dùng đứng lại
            // ở màn tạo dự án trong khi daemon đã nối, tab đã thêm, phiên đã mở. Chủ sản phẩm
            // nhìn màn hình và hỏi đúng câu ấy: "màn hình đang ở màn tạo dự án mà?"
            //
            // Đặt SAU `_moThat` vì đó là chỗ duy nhất biết dự án mở được thật: `project.open`
            // ném E6000 (store bị ghi ngoài cổng) hay E6003 (chưa di trú) thì màn chào phải ở
            // nguyên, vì nó là chỗ duy nhất người dùng làm được gì đó tiếp theo.
            khung.anManChao()
            await _lamMoi()
            _batNhipTim()
        } catch {
            khung.dock.themLuot(.loi, "\(error)")
            // E6003 thoát ra ở ĐÂY, không phải ở `_moThat`. [DEV-184]
            //
            // `_napRegistry` chạy TRƯỚC và nó cũng chạm store, nên với một dự án chưa di trú thì
            // `caps.list` hỏng trước khi `project.open` kịp được gọi. Đo 22/09/2026: đặt thẻ
            // "Di trú ngay" ở mỗi nhánh bắt của `_moThat` thì nó chỉ hiện khi truyền TÊN dự án
            // (đường đi lỗi), còn đường người dùng thật — đường dẫn đầy đủ — lại rơi vào nhánh
            // này và chỉ in một dòng chữ.
            //
            // Bắt ở cả hai chỗ chứ không dời hẳn xuống đây: hai nhánh là hai lỗi khác nhau, và
            // một ngày nào đó `_napRegistry` không còn chạm store thì nhánh kia vẫn phải đúng.
            _moiDiTru(duong, "\(error)")
        }
    }

    /// Hiện thẻ "Di trú ngay" nếu lỗi này là E6003 — [DEV-184]. Trả `true` nếu đã hiện.
    ///
    /// Đọc mã lỗi từ chuỗi vì hai nhánh gọi nó ném hai KIỂU lỗi khác nhau (`EideKetQua.Loi` của
    /// một lời gọi năng lực, và lỗi khởi động daemon). Bám vào kiểu thì phải sửa chỗ này mỗi lần
    /// thêm một đường hỏng; bám vào mã lỗi thì đúng thứ API-15 §3 hứa là ổn định.
    @discardableResult
    private func _moiDiTru(_ duong: String, _ vi: String) -> Bool {
        guard vi.contains("E6003") else { return false }
        let ten = (duong as NSString).lastPathComponent
        let the = EideTheHoi(cap: "project.open", loai: .canLam(
            nhan: "Di trú ngay",
            viec: "Dự án `\(ten)` dùng store của bản EIDE cũ, cần di trú mới mở được.",
            moTa: "Lệnh sao lưu store hiện tại trước khi chạy (DDD-14 §5). "
                + "Xong thì dự án tự mở lại."))
        the.onLam = { [weak self] in
            Task { await self?.diTru(duong) }
        }
        khung.dock.themThe(the)
        return true
    }

    /// Gọi `project.open` THẬT, không chỉ bật daemon lên.
    ///
    /// Bật daemon với `-p <đường dẫn>` mới chỉ nói cho nó biết thư mục nào; năm bước của
    /// PROJECT-02 chưa chạy. Bỏ qua chúng mất ba thứ, và cả ba đều im lặng:
    ///
    /// - **Phiên làm việc** không được mở, nên `session.state` trả rỗng và màn Tổng quan hiện
    ///   "chưa mở phiên nào" trên một dự án đang mở ngay trước mắt.
    /// - **Niêm store** không được kiểm, nên một store bị ghi ngoài cổng (E6000) đi thẳng vào
    ///   phiên làm việc — đúng thứ phép kiểm ấy tồn tại để chặn.
    /// - **`user_version`** không được so, nên một dự án của bản cũ (E6003) hỏng dần ở từng lời
    ///   gọi thay vì dừng ngay với một câu "chạy `eide migrate`".
    private func _moThat(_ d: EideDaemon, _ duong: String) async throws {
        let ten = (duong as NSString).lastPathComponent
        do {
            // ĐƯỜNG DẪN ĐẦY ĐỦ, không phải tên. Daemon chạy với `-p <dự án>`, nên `ctx.project_dir`
            // CHÍNH LÀ dự án; `project.open` lại tra tên trong thư mục ấy như một workspace và
            // không thấy gì. Lời gọi trả E2000 mà bên gọi vẫn báo "đã mở" — vì `caps.invoke` trả
            // lỗi TRONG kết quả, không phải bằng một lỗi JSON-RPC.
            let r = try EideKetQua.boc(try await d.goi("project.open", ["project": duong]),
                                       "project.open")
            let f = (r["features"] as? [String: Any])
            let n = (f?["total"] as? Int) ?? 0
            let dau = (r["first_failing"] as? [String: Any])?["title"] as? String
            khung.dock.themLuot(.tacTu, "Đã mở `\(ten)` — \(n) tính năng trong hồ sơ"
                                + (dau.map { ", đang dở: \($0)" } ?? "")
                                + ". Gõ một câu tiếng Việt để bắt đầu.")
        } catch let e as EideKetQua.Loi {
            // E6003/E6000 không phải lỗi để nuốt: chúng có CÁCH SỬA, và cách ấy phải hiện ra.
            let cach = e.maEide == "E6003" ? " → dự án của bản EIDE cũ."
                     : (e.maEide == "E6000"
                        ? " → store bị ghi ngoài EIDE; dựng lại chỉ mục trước khi làm tiếp." : "")
            khung.dock.themLuot(.loi, "Mở `\(ten)` không xong: \(e)\(cach)")
            // E6003 có MỘT cách sửa, và sản phẩm biết chính xác cách ấy — nên nó phải là một
            // cái nút. [DEV-184]
            //
            // Bản trước in "→ chạy `eide migrate` trong thư mục dự án" rồi dừng ở đó. Câu ấy
            // đúng và vẫn là một ngõ cụt trong ứng dụng: người dùng phải mở Terminal, biết
            // đường dẫn dự án, biết `eide` nằm ở đâu. Đo 22/09/2026 trên một dự án tạo trước
            // [DEV-170]: 18 trong 20 màn mở ra trống, mỗi màn in đúng mã lỗi ấy.
            //
            // PROJECT-02 nói lõi KHÔNG tự di trú, và điều đó giữ nguyên — di trú đổi dữ liệu
            // nên phải do người quyết. Thứ thiếu không phải một quyết định tự động mà là chỗ
            // để quyết.
            _moiDiTru(duong, e.maEide ?? "")
        }
    }

    /// Di trú store của một dự án rồi mở lại nó — [DEV-184].
    ///
    /// Chạy `eide migrate` một lần chứ không thêm một phương thức RPC: di trú đổi schema NGAY
    /// DƯỚI CHÂN daemon đang chạy, nên sau đó phải mở lại dự án bằng mọi giá. Một lệnh một lần
    /// làm đúng việc ấy và không để lại một daemon đang cầm store nửa cũ nửa mới.
    public func diTru(_ duong: String) async {
        khung.dock.themLuot(.heThong, "Đang di trú store… (sao lưu trước khi chạy)")
        let r: (ma: Int32, json: [String: Any]?, van: String, loi: String)
        do {
            r = try await EideDaemon.motLan(["migrate", "-p", duong])
        } catch {
            return khung.dock.themLuot(.loi, "Không chạy được `eide migrate`: \(error)")
        }
        guard r.ma == 0 else {
            let vi = r.loi.isEmpty ? r.van : r.loi
            return khung.dock.themLuot(.loi, "Di trú KHÔNG xong — dự án giữ nguyên. "
                + vi.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // Nói ra ĐÃ ĐỔI GÌ, không chỉ "xong": di trú là thao tác đổi dữ liệu, và câu "xong"
        // trần không cho người dùng cách nào biết nó đã động tới cái gì.
        let v = (r.json?["to_version"] as? Int).map { " → user_version \($0)" } ?? ""
        khung.dock.themLuot(.heThong, "Di trú xong\(v). Đang mở lại dự án…")
        await moDuAn(duong)
    }

    private func _napRegistry(_ d: EideDaemon) async throws {
        let r = try await d.goi("caps.list")
        let caps = (r["caps"] as? [[String: Any]]) ?? []
        for c in caps where (c["implemented"] as? Bool) == true {
            guard let id = c["id"] as? String else { continue }
            manCua[id] = c["ui"] as? String ?? ""
            motaCua[id] = c["desc"] as? String ?? ""
        }
        khung.bangLenh.datNguon(nangLuc: motaCua.keys.sorted().map { ($0, motaCua[$0] ?? "") })
    }

    /// Nạp thẳng bảng `năng lực → màn` mà không cần daemon.
    ///
    /// Chỉ để đo NT2: luật "tác tử chạm tới đâu, màn ấy mở" chỉ chạy khi bảng này có dữ liệu,
    /// mà dữ liệu ấy đến từ `caps.list` — tức từ một daemon thật. Không có hàm này thì mọi bài
    /// kiểm NT2 đều xanh vì luật không bao giờ được thi hành, chứ không phải vì nó đúng.
    func datBanDoMan(_ m: [String: String]) { manCua = m }

    /// Năng lực đứng sau một màn — đảo bảng `cap → màn`, không giữ bảng thứ hai.
    private func _nangLucCua(_ tien: String) -> [String] {
        manCua.filter { $0.value.hasPrefix(tien) }.keys.sorted()
    }

    // MARK: - nối các vùng

    private func _noiDay() {
        // §7.2: "bấm = query lại TỪ seq đã có". Nạp lại màn đang mở và xoá dải.
        khung.nutTaiLai.target = self
        khung.nutTaiLai.action = #selector(_taiLai)

        khung.cotTrai.onChon = { [weak self] tien in
            self?.moMan(tien, boiTacTu: false)
        }
        khung.thanhTab.onChon = { [weak self] tien in
            self?.moMan(tien, boiTacTu: false)
        }
        khung.thanhTab.onDong = { [weak self] tien in
            guard let self else { return }
            if let ke = self.khung.thanhTab.dong(tien) {
                self.moMan(ke, boiTacTu: false)
            } else {
                self.khung.vungLamViec.dongMan()
            }
        }
        khung.dock.onGui = { [weak self] van in
            Task { await self?._gui(van) }
        }
        khung.thanhTren.onBangLenh = { [weak self] in self?.khung.bangLenh.mo() }
        khung.bangLenh.onChonMan = { [weak self] tien in self?.moMan(tien, boiTacTu: false) }
        khung.bangLenh.onChonNangLuc = { [weak self] id in
            Task { await self?.goiNangLuc(id) }
        }
        khung.formThamSo.onChay = { [weak self] id, tham in
            Task { await self?.goiNangLuc(id, tham) }
        }
        khung.modalHoi.onChon = { [weak self] thuan in
            guard let self else { return }
            let ma = daHoi
            Task { await self._traLoiPEdit(thuan, ma) }
        }
        khung.thanhTren.onDungKhan = { [weak self] in
            Task { await self?._dungKhan() }
        }
        // §2A.3 huy hiệu → S25. §2A.4/2A.5 hai bộ đếm → CUỘN tới khối tương ứng ở cột phải, KHÔNG
        // mở màn: cả hai khối đã nằm sẵn trên màn hình, và mở thêm một màn để xem thứ đang hiện
        // là dạy người dùng đi vòng.
        khung.thanhTren.onMuc = { [weak self] in self?.moMan("ChinhSach", boiTacTu: false) }
        khung.thanhTren.onDemCho = { [weak self] in self?.khung.cotPhai.cuonToi(.cho) }
        khung.thanhTren.onDemHoanTac = { [weak self] in self?.khung.cotPhai.cuonToi(.hoanTac) }
        khung.cotPhai.onDuyet = { [weak self] ma, thuan in
            Task { await self?._quyet(ma, thuan) }
        }
        khung.cotPhai.onHoanTac = { [weak self] ma in
            Task { await self?._hoanTac(ma) }
        }
        // Nối ở ĐÂY chứ không trong `khoiDong()`: một nút chỉ sống khi một hàm khác được gọi
        // là một nút chết trong mọi đường chạy quên gọi hàm ấy — và `--chup` là một đường như thế.
        khung.manChao.onTao = { [weak self] van, thu in
            Task { await self?.taoDuAn(van, thuMuc: thu) }
        }
        khung.cotPhai.onChonRun = { [weak self] _ in
            self?.moMan("S2", boiTacTu: false)
        }
        khung.thanhTren.onDuAn = { [weak self] in
            Task { await self?.moChonDuAn() }
        }
        chonDuAn.onChon = { [weak self] d in
            guard let self else { return }
            popChon.close()
            Task { await self.doiDuAn(d.duong) }
        }
        chonDuAn.onTaoMoi = { [weak self] in
            guard let self else { return }
            popChon.close()
            // Về màn chào chứ không mở một hộp thoại thứ hai: §3.1 đã có đúng một chỗ để tạo dự
            // án, và hai đường tạo khác nhau là hai đường để lệch nhau.
            khung.manChao.isHidden = false
            khung.manChao.datTrangThai("", ban: false)
        }
    }

    // MARK: - §2A.2 bộ chuyển dự án

    public let chonDuAn = EideChonDuAn()
    public lazy var popChon: NSPopover = {
        let p = NSPopover()
        p.contentViewController = chonDuAn
        p.behavior = .transient
        return p
    }()

    /// Mở popover chuyển dự án. Đọc `project.list` MỖI LẦN mở, không nhớ bản cũ: danh sách dự án
    /// đổi ngoài ứng dụng (tạo bằng CLI, xoá bằng Finder), và một danh sách nhớ sẵn sẽ mời người
    /// dùng mở một thư mục không còn tồn tại.
    public func moChonDuAn() async {
        let r = try? await EideDaemon.motLan(["project", "list"])
        let ds = (r?.json?["projects"] as? [[String: Any]] ?? []).map(EideChonDuAn.DuAn.init)
        chonDuAn.dat(ds)
        if ds.isEmpty, let r, r.ma != 0 {
            khung.dock.themLuot(.loi, "Không đọc được danh sách dự án: "
                                + r.loi.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let neo = khung.thanhTren.nutDuAn
        guard neo.window != nil else { return }
        popChon.show(relativeTo: neo.bounds, of: neo, preferredEdge: .maxY)
    }

    /// **Đổi dự án = thay TOÀN BỘ ngữ cảnh** — §2A.2.
    ///
    /// Đóng hết tab, bỏ hết thẻ Run, xoá mọi badge. Giữ lại bất cứ thứ gì của dự án cũ đều là một
    /// lời nói dối cụ thể: một badge "Chờ tôi 2" còn sót lại trỏ vào hàng đợi của dự án KHÁC, và
    /// người bấm Duyệt ở đó duyệt một việc họ không hề nhìn thấy.
    ///
    /// Bố cục thì giữ nguyên — cột trái, chiều cao vùng trao đổi, cột phải hẹp hay rộng là lựa
    /// chọn của NGƯỜI, không thuộc về dự án nào.
    public func doiDuAn(_ duong: String) async {
        for t in khung.thanhTab.tab { khung.thanhTab.dong(t) }
        khung.vungLamViec.dongMan()
        for the in theRun.values { khung.dock.goThe(the) }
        theRun.removeAll()
        moiTheoMan.removeAll()
        choTheoMan.removeAll()
        manCua.removeAll()
        motaCua.removeAll()
        lanNguoiChon = nil
        _veBadge()
        khung.dock.themLuot(.heThong,
            "Đổi sang dự án `\((duong as NSString).lastPathComponent)` — đã đóng hết tab của dự "
            + "án cũ. Hàng đợi, thẻ chạy và huy hiệu đều thuộc về dự án đang mở.")
        khung.anManChao()
        await moDuAn(duong)
    }

    /// Khoảng "màn này là của tôi" sau một lần NGƯỜI tự chọn màn — §2C.3.
    public static let GIU_MAN: TimeInterval = 20

    /// Lần gần nhất người tự chọn một màn. `nil` = chưa lần nào, và khi ấy tác tử được mở thẳng:
    /// không có việc nào của người đang bị cắt ngang.
    private var lanNguoiChon: Date?

    /// Đồng hồ — tiêm được, vì bài kiểm cho §2C.3 phải vượt qua mốc 20 giây mà không chờ 20 giây.
    var dongHo: () -> Date = { Date() }

    /// Mở một màn. `boiTacTu` quyết định có nhấp nháy hay không (§2B.5).
    ///
    /// Trả về **có chiếm được vùng làm việc hay không**. Người gọi cần biết: câu báo ra vùng
    /// trao đổi khác hẳn giữa "đã mở màn X" và "đã thêm tab X ở nền", và một câu nói sai chỗ
    /// dạy người dùng nhìn nhầm chỗ.
    @discardableResult
    public func moMan(_ tien: String, boiTacTu: Bool, khoaViec: String? = nil) -> Bool {
        // Tiền tố lạ thì NÓI RA. Trước phép kiểm này, `moMan("S3")` chạy trót lọt: cột trái
        // không chọn gì, tab mang nhãn "S3", vùng làm việc ghi nhận một màn không tồn tại — và
        // một bài tự kiểm khẳng định cả ba thứ ấy vẫn ĐẠT.
        guard EideManHinhDS.man(tien) != nil else {
            khung.dock.themLuot(.loi, "Không có màn nào mang tiền tố `\(tien)` trong danh mục 25 màn.")
            return false
        }
        // §2C.3 — **không cướp màn.** Người vừa tự chọn một màn khác dưới 20 giây thì họ đang
        // ĐỌC nó; kéo màn hình đi lúc ấy làm mất chỗ đang đọc và không có nút quay lại. Tab vẫn
        // được thêm và cột trái vẫn nháy, nên việc của tác tử không bị giấu — chỉ không được
        // đặt lên trước việc của người.
        if boiTacTu, let t = lanNguoiChon, dongHo().timeIntervalSince(t) < Self.GIU_MAN,
           tien != khung.vungLamViec.dangMo {
            khung.thanhTab.moNen(tien)
            khung.cotTrai.nhayMuc(tien)
            // Khoá việc của chuỗi đang chạy, nếu bên gọi biết. Tác tử mở CÙNG một màn sáu
            // lần trong một chuỗi là MỘT thứ để xem, không phải sáu.
            moiTheoMan[tien, default: []].insert(khoaViec ?? "mo-nen")
            _veBadge()
            return false
        }
        if !boiTacTu { lanNguoiChon = dongHo() }
        khung.cotTrai.chon(tien, nhapNhay: boiTacTu)
        khung.thanhTab.mo(tien)
        // Người MỞ màn ra là đã xem — badge về 0 bất kể daemon còn sống hay không. Đặt sau
        // `guard let d = daemon` (chỗ tự nhiên hơn) thì mất daemon xong badge đứng mãi, và một
        // badge không bao giờ tắt là một badge người ta thôi nhìn.
        daXem(tien)
        khung.vungLamViec.moMan(tien, nangLucDs: _nangLucCua(tien))

        if let tao = Self.MAN[tien] {
            let man = tao()
            man.onNguoiGo = { [weak self] in self?.nguoiGo() }
            man.onMoMan = { [weak self] t in _ = self?.moMan(t, boiTacTu: false) }
            man.duAnGoc = duAn                    // [DEV-189]
            // Màn Làm rõ yêu cầu là màn DUY NHẤT cho tới nay mà người GHI vào từ bên trong nó.
            // Ghi xong thì thanh trên và cột phải phải đổi theo — chúng chiếu cùng một danh
            // sách việc chờ, và để chúng lệch nhau là để hai con số về cùng một thứ nằm cạnh
            // nhau mà khác nhau.
            (man as? EideManLamRo)?.onDaTraLoi = { [weak self] in await self?._lamMoi() }
            khung.vungLamViec.datMan(man)
            guard let d = daemon else {
                khung.vungLamViec.khiRong(
                    vi: "chưa mở dự án nào nên không có daemon để hỏi",
                    buocKe: "tạo hoặc mở một dự án")
                return true
            }
            Task { [weak self] in
                await man.nap { ten, tham in
                    _ = self   // giữ phiên sống đúng bằng thời gian màn còn nạp
                    return try await d.goi(ten, tham)
                }
                // Mốc nước §7.2: màn này đang hiện trạng thái tính tới seq nào.
                man.seqCuoi = self?.seqNghe ?? 0
            }
            return true
        }
        if let m = EideManHinhDS.man(tien), m.canBoard {
            khung.vungLamViec.khiRong(
                vi: "chưa có bo mạch cắm vào máy",
                buocKe: "cắm board và mạch nạp, rồi mở lại màn này")
            return true
        }
        khung.vungLamViec.khiRong(vi: "màn này chưa nối dữ liệu trong bản dựng hiện tại",
                                  buocKe: "đang làm — xem mục 8 của UXC-31")
        return true
    }

    // MARK: - §2D.2(b) gõ liên tục thì thu gọn vùng trao đổi

    /// Gõ liền mạch bao lâu thì thu gọn vùng trao đổi.
    public static let GO_LIEN: TimeInterval = 5

    /// Ngắt tay bao lâu thì coi như hết một mạch gõ. Con số này KHÔNG có trong UXC-31 — §2D.2(b)
    /// chỉ nói "liên tục 5 giây", mà "liên tục" cần một định nghĩa để đo được. 1,5 s là quãng
    /// nghỉ dài hơn mọi khoảng giữa hai phím của người gõ bình thường, kể cả lúc dừng nghĩ một
    /// nhịp giữa câu.
    public static let NGAT_GO: TimeInterval = 1.5

    /// Phím đầu tiên của mạch gõ đang chạy, và phím gần nhất.
    private var goTu: Date?
    private var goCuoi: Date?

    /// Người gõ một phím trong vùng soạn thảo của màn đang mở — §2D.2(b).
    ///
    /// Đo bằng MỐC THỜI GIAN chứ không bằng `Timer`: một bộ đếm giờ chạy nền phải bị huỷ đúng
    /// chỗ khi màn đóng, khi tệp đổi, khi cửa sổ mất tiêu điểm — ba đường quên huỷ là ba lần
    /// vùng trao đổi tự tụt xuống trong lúc người dùng đang đọc nó.
    func nguoiGo() {
        let gio = dongHo()
        if let c = goCuoi, gio.timeIntervalSince(c) > Self.NGAT_GO { goTu = nil }
        goCuoi = gio
        let tu = goTu ?? gio
        goTu = tu
        guard gio.timeIntervalSince(tu) >= Self.GO_LIEN, khung.dock.cao != .thuGon else { return }
        khung.dock.datCao(.thuGon)
        goTu = nil   // đã thu gọn rồi thì thôi, đừng thu lại mỗi phím sau đó
    }

    /// Bảng màn ĐÃ NỐI DỮ LIỆU. Khoá là tiền tố trong `EideManHinhDS`, và phép kiểm bố cục đối
    /// chiếu từng khoá với danh mục — một khoá gõ sai ở đây là một màn không bao giờ mở được, và
    /// nó trông y hệt một màn chưa làm.
    public static let MAN: [String: () -> EideManCoSo] = [
        EideManTongQuan.tien: { EideManTongQuan() },
        EideManNhatKy.tien: { EideManNhatKy() },
        EideManChinhSach.tien: { EideManChinhSach() },
        EideManHoChieu.tien: { EideManHoChieu() },
        EideManXungDot.tien: { EideManXungDot() },
        EideManNhapTaiLieu.tien: { EideManNhapTaiLieu() },
        EideManBanDoTriThuc.tien: { EideManBanDoTriThuc() },
        EideManHoChieuMach.tien: { EideManHoChieuMach() },
        EideManLamRo.tien: { EideManLamRo() },
        EideManYeuCau.tien: { EideManYeuCau() },
        EideManLuocDo.tien: { EideManLuocDo() },
        EideManKeHoach.tien: { EideManKeHoach() },
        EideManTaiLieu.tien: { EideManTaiLieu() },
        EideManSoanThao.tien: { EideManSoanThao() },
        EideManDiffMerge.tien: { EideManDiffMerge() },
        EideManMoiTruong.tien: { EideManMoiTruong() },
        EideManMoHinh.tien: { EideManMoHinh() },
        EideManCongCu.tien: { EideManCongCu() },
        EideManRegistry.tien: { EideManRegistry() },
        EideManLuong.tien: { EideManLuong() },
        EideManMoPhong.tien: { EideManMoPhong() },
        // Bốn màn chạm phần cứng — [DEV-186]. Tới 22/09/2026 chúng có trong menu cột trái mà
        // KHÔNG có mục nào ở bảng này, nên bấm vào mở ra một vùng làm việc trống.
        EideManDoBoard.tien: { EideManDoBoard() },
        EideManLog.tien: { EideManLog() },
        EideManGoLoi.tien: { EideManGoLoi() },
        EideManBench.tien: { EideManBench() },
    ]


    // MARK: - đồng bộ sự kiện (UXC-31 §7)

    /// `seq` sổ cái nghe được gần nhất. 0 = chưa nghe gì.
    private var seqNghe = 0

    /// `seq` của lần đọc pha gần nhất — §2D.4. `-1` = chưa đọc lần nào, khác hẳn `0`.
    private var seqPha = -1

    /// Màn ĐANG ĐÓNG có sự kiện chưa xem — §7.3 ("chỉ tăng badge nhóm").
    /// Các ĐƠN VỊ VIỆC chưa xem, theo màn. Tập hợp chứ không phải số đếm.
    ///
    /// Badge phải trả lời câu "có bao nhiêu việc mới ở màn này mà tôi chưa xem". Bản trước cộng
    /// 1 cho MỖI SỰ KIỆN, và `event.run.progress` gánh hai khái niệm khác hẳn nhau: sự kiện của
    /// CHUỖI, và `cap.run.*` của từng lời gọi lẻ — kể cả những lời gọi do chính một màn phát ra
    /// để tự vẽ. Một chuỗi sáu nút sinh vài chục sự kiện.
    ///
    /// Đo 22/09/2026 trên bài CNC: ba câu gõ ra huy hiệu `Nhật ký 470`, `Mã nguồn 713`,
    /// `DỰ ÁN 993`, trên một dự án có đúng 7 yêu cầu. Người dùng đọc "470" thành "470 thứ phải
    /// xem"; thật ra là 470 gói tin giao thức từ ba câu. Một con số như thế không sai theo
    /// nghĩa số học, nhưng nó trả lời một câu hỏi không ai hỏi — và người ta thôi nhìn badge.
    private var moiTheoMan: [String: Set<String>] = [:]

    /// Khoá của một ĐƠN VỊ VIỆC, suy từ chính sự kiện.
    ///
    /// Ưu tiên `chain.run_id`: mọi nút của một chuỗi mang cùng khoá ấy, nên một câu người gõ =
    /// MỘT việc, đúng như người dùng đếm. Không có chuỗi thì `run_id` của lời gọi lẻ.
    ///
    /// Không thuộc lượt chạy nào thì mỗi BẢN GHI SỔ CÁI là một việc (`seq`) — hai lần
    /// `store.write` rời nhau đúng là hai việc, và gộp chúng theo loại sẽ giấu mất một. Phép
    /// gộp chỉ đúng khi có thứ để gộp THEO: một lượt chạy.
    static func khoaViec(_ p: [String: Any]) -> String {
        if let c = p["chain"] as? [String: Any], let r = c["run_id"] as? String, !r.isEmpty {
            return r
        }
        if let r = p["run_id"] as? String, !r.isEmpty { return r }
        if let q = p["seq"] as? Int { return "seq:\(q)" }
        return (p["kind"] as? String) ?? "?"
    }

    /// Mục CHỜ TÔI theo màn, phái sinh từ hàng đợi (B7). Badge = trường này cộng `moiTheoMan`.
    private var choTheoMan: [String: Int] = [:]

    /// **§7.2 — phát hiện nhảy quãng.**
    ///
    /// Phép này nằm ở đây chứ không ở từng màn, vì `seq` là số thứ tự TOÀN CỤC của sổ cái: một
    /// màn chỉ nghe hai loại sự kiện sẽ thấy `seq` 5 rồi 11 và tưởng mình mất sáu bản ghi. Chỉ
    /// lớp nghe ĐỦ MỌI LOẠI mới nói được "thiếu" hay "không thiếu".
    ///
    /// Nhảy quãng khác mất daemon, và khác ở chỗ nguy hơn: mất daemon là không nghe thấy gì,
    /// còn nhảy quãng là màn hình VẪN đang cập nhật nên trông như đang đúng.
    /// Khoảng trống `seq` PHẢI LỚN mới đáng báo. [DEV-163]
    ///
    /// Không phải bản ghi sổ cái nào cũng sinh một sự kiện lên giao diện — daemon cố ý chỉ
    /// chuyển tiếp những loại người dùng cần thấy. `context.bundle` và `session.open` là việc
    /// nội bộ và không có tên sự kiện nào; chúng để lại một lỗ trong dãy `seq` mà giao diện
    /// nhận được.
    ///
    /// Đo 22/09/2026 trên một lượt CNC: 5/78 bản ghi không sinh sự kiện, và giao diện treo biển
    /// "thiếu 1 bản ghi sổ cái (seq 22…22)" trong khi tệp sổ cái HOÀN TOÀN LÀNH — 78 bản ghi,
    /// không thiếu, không trùng, `verify()` trả `(True, 0)`.
    ///
    /// Một cảnh báo toàn vẹn kêu sai là thứ tệ hơn không có cảnh báo: nó kêu ở mọi phiên làm
    /// việc bình thường, người dùng học cách bỏ qua, rồi lần sổ cái gãy thật thì nó kêu và
    /// không ai nhìn.
    ///
    /// `NGUONG_HO` là số loại nội bộ liên tiếp có thể xảy ra giữa hai sự kiện. Không dùng một
    /// danh sách loại: giao diện không được biết loại nào daemon chuyển tiếp — đó là chi tiết
    /// của phía kia, và một bản sao của nó ở đây là một chỗ sẽ trôi.
    static let NGUONG_HO = 8

    private func _theoSeq(_ p: [String: Any]) {
        guard let seq = p["seq"] as? Int, seq > 0 else { return }
        defer { seqNghe = max(seqNghe, seq) }
        // Bản ghi ĐẦU TIÊN nghe được không nói lên điều gì: daemon có thể đã chạy từ trước.
        guard seqNghe > 0, seq - seqNghe > Self.NGUONG_HO else { return }
        khung.datNhayQuang(seqNghe, seq)
    }


    /// Sự kiện này có phải một THAY ĐỔI TRẠNG THÁI không — hay chỉ là tiếng vọng của một lời
    /// gọi đọc?
    ///
    /// `event.run.progress` gánh hai khái niệm (xem `_theoRun`), và một trong hai là `cap.run.*`
    /// của MỘT lời gọi đơn lẻ — bao gồm cả những lời gọi mà chính một màn vừa mở phát ra để tự
    /// vẽ. Không lọc thì `_dinhTuyen` thấy màn đang mở "cần" sự kiện ấy, nạp lại nó, lần nạp
    /// lại sinh ra sự kiện y hệt, và vòng lặp không có đáy.
    ///
    /// Đo 20/09: thêm §7 xong, `--tu-kiem` treo ở màn đầu tiên — cùng hình dạng với lỗi NT2 đã
    /// sửa sáng cùng ngày, ở một chỗ khác. Nên phép phân biệt nay có MỘT tên và MỘT chỗ, và cả
    /// hai bên gọi dùng chung nó.
    static func laDoiTrangThai(_ ten: String, _ p: [String: Any]) -> Bool {
        // Dấu hiệu "tiếng vọng": sự kiện nói về MỘT LỜI GỌI NĂNG LỰC (`cap`) mà không thuộc
        // chuỗi nào (`node_id`) và không phải vòng đời chuỗi (`run.*`).
        //
        // Luật này rộng hơn `event.run.progress`, và phải thế: bản đầu chỉ lọc run.progress,
        // còn `gate.decision` → `event.gate.decided` của CÙNG lời gọi đọc ấy vẫn lọt — nên màn
        // Xung đột tri thức (khai nghe `gate.decided`) tự nạp lại chính mình, vô tận. Mỗi lời
        // gọi năng lực sinh ra ba bản ghi sổ cái, nên bịt một đường còn hai.
        // `cap` HOẶC `action_cap` — hai tên cho cùng một thứ. [DEV-169]
        //
        // `gate.decision` khai năng lực trong `action_cap` (Router ghi thế để phân biệt "năng
        // lực bị xét" với "năng lực đang chạy"), nên phép hỏi `p["cap"] != nil` không thấy nó
        // và MỌI quyết định cổng đi thẳng qua bộ lọc — kể cả quyết định cho một lời gọi đọc mà
        // chính một màn vừa phát ra để tự vẽ.
        //
        // Đo 22/09/2026 trên bài CNC: 109 khoá việc từ `gate.decision` trên tổng 119, và huy
        // hiệu `Nhật ký 120` trên một dự án có 5 yêu cầu. Mỗi lần màn tự vẽ lại là một "việc
        // mới cho anh" theo cách đếm ấy.
        //
        // Bỏ dòng `p["chain"] != nil` thêm ở [DEV-156]: nó là MÃ CHẾT — daemon `pop("chain")`
        // trước khi gửi, nên khoá ấy không bao giờ có mặt ở đây. Một điều kiện không bao giờ
        // đúng nằm trong một bộ lọc là chỗ người đọc sau sẽ tin nhầm.
        guard p["cap"] != nil || p["action_cap"] != nil else { return true }
        let loai = (p["kind"] as? String) ?? ""
        return loai.hasPrefix("run.") || p["node_id"] != nil
    }

    /// **§7.1 + §7.3 — đưa sự kiện tới đúng màn.**
    ///
    /// Màn đang MỞ và có khai báo nghe loại này → hỏi nó tự vẽ lại phần liên quan; nó chưa biết
    /// thì nạp lại CHÍNH màn ấy, không phải cả cửa sổ. Màn đang ĐÓNG → chỉ tăng badge.
    private func _dinhTuyen(_ ten: String, _ p: [String: Any]) {
        guard Self.laDoiTrangThai(ten, p) else { return }
        let can = EideDangKySuKien.manCan(ten)
        guard !can.isEmpty else { return }
        let dangMo = khung.vungLamViec.dangMo
        let khoa = Self.khoaViec(p)
        for tien in can where tien != dangMo {
            moiTheoMan[tien, default: []].insert(khoa)
        }
        _veBadge()
        guard let dangMo, can.contains(dangMo), let man = khung.vungLamViec.manDangMo else { return }
        if man.apDung(ten, p) { return }
        _henNapLai(man, dangMo)
    }


    /// Màn đang chờ nạp lại — gộp nhiều sự kiện thành MỘT lần nạp.
    private var choNapLai: Set<String> = []

    /// Cửa sổ gộp. Đủ ngắn để người không kịp thấy độ trễ, đủ dài để một lượt chạy nhiều bước
    /// không kéo theo một lần nạp cho mỗi bước.
    public static let GOP_NAP: TimeInterval = 0.4

    /// **Gộp lời gọi nạp lại** — hệ quả trực tiếp của §7.3 ("KHÔNG reload cả màn").
    ///
    /// Nạp lại NGAY ở mỗi sự kiện là thứ §7.3 cấm, và nó hỏng nhanh nhất ở đúng màn nghe nhiều
    /// nhất: đo 20/09, màn Nhật ký — khai `TAT_CA` theo §8 S2 — mất **7,68 s** để hiện xong,
    /// so với 0,35 s trước đó, vì mỗi sự kiện đẩy nó về lại trạng thái "Đang đọc…".
    ///
    /// Gộp không thay được diff render; nó là cách lùi TRUNG THỰC cho tới khi từng màn hiện
    /// thực `apDung`. Khác biệt đáng giữ: một lần nạp cho một chùm sự kiện, thay vì một lần
    /// nạp cho mỗi sự kiện.
    /// Màn nhận thêm sự kiện TRONG LÚC đang nạp — phải nạp thêm một lượt nữa sau khi xong.
    private var banLai: Set<String> = []

    /// Có nên BẮT ĐẦU một lượt nạp lại cho màn này không — phần QUYẾT ĐỊNH, tách khỏi phần gọi
    /// daemon để đo được mà không cần một daemon thật.
    ///
    /// Tách ra vì bài kiểm đầu tiên tôi viết cho lỗi này XANH CẢ KHI BẢN VÁ BỊ VÔ HIỆU:
    /// `EidePhien` trong bài kiểm không có daemon, nên `_henNapLai` thoát ngay ở dòng đầu và
    /// đường nạp lại chưa bao giờ được chạm tới. Một bài kiểm không tái hiện được điều kiện thì
    /// nó không đo gì cả — và nó tệ hơn không có, vì nó báo ĐẠT.
    func xepNapLai(_ tien: String) -> Bool {
        guard !choNapLai.contains(tien) else {
            banLai.insert(tien)
            return false
        }
        choNapLai.insert(tien)
        return true
    }

    /// Lượt nạp xong — trả `true` nếu có sự kiện tới trong lúc ấy và cần nạp thêm một lượt.
    func xongNapLai(_ tien: String) -> Bool {
        choNapLai.remove(tien)
        return banLai.remove(tien) != nil
    }

    private func _henNapLai(_ man: EideManCoSo, _ tien: String) {
        guard let d = daemon else { return }
        // Đang có một lượt nạp chờ hoặc đang chạy cho màn này → chỉ ĐÁNH DẤU, không xếp thêm.
        //
        // Bản trước gỡ `choNapLai` NGAY SAU khi ngủ, tức TRƯỚC `nap`. Nên sự kiện tới trong lúc
        // nạp lại xếp thêm một lượt nữa, lượt ấy giết lượt đang chạy ([DEV-164]), rồi chính nó
        // bị lượt sau giết — một LIVELOCK: màn không bao giờ nạp xong.
        //
        // Đo 22/09/2026 bằng ảnh chụp cửa sổ thật: tab "Làm rõ yêu cầu" mở ra chỉ có ba chữ
        // "Đang đọc…", bảng 5 điểm cần làm rõ không hiện, dù store có đủ. Cứ mỗi 0,4 s một lượt
        // nạp mới lại bắt đầu và giết lượt trước.
        //
        // Đây là lỗi mà [DEV-164] LÀM LỘ RA chứ không gây ra: trước đó hai lượt chồng nhau cùng
        // vẽ, nên màn vẫn hiện — sai nội dung, nhưng hiện. Sửa cuộc đua xong thì cái livelock
        // vốn đã ở đó mới thành nhìn thấy được.
        guard xepNapLai(tien) else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.GOP_NAP * 1_000_000_000))
            guard let self else { return }
            defer {
                // Có sự kiện mới trong lúc nạp → nạp thêm ĐÚNG MỘT lượt nữa. Không lặp vô hạn:
                // lượt sau chỉ chạy nếu `banLai` lại được đánh dấu lần nữa.
                if xongNapLai(tien),
                   khung.vungLamViec.dangMo == tien,
                   let dang = khung.vungLamViec.manDangMo {
                    _henNapLai(dang, tien)
                }
            }
            // Người có thể đã chuyển màn trong lúc chờ — nạp lại một màn không còn trên màn
            // hình là tốn một lượt gọi lõi để không ai thấy.
            guard khung.vungLamViec.dangMo == tien,
                  let dang = khung.vungLamViec.manDangMo, dang === man else { return }
            await man.nap { t, x in try await d.goi(t, x) }
            man.seqCuoi = seqNghe
        }
    }

    /// Badge = mục CHỜ TÔI cộng sự kiện CHƯA XEM của màn đang đóng.
    ///
    /// Hai nguồn, một con số, và đó là chủ ý: người nhìn cột trái hỏi "chỗ nào có việc cho tôi",
    /// không hỏi "việc ấy thuộc loại nào". Tách làm hai dãy số sẽ bắt họ học một bảng chú giải.
    private func _veBadge() {
        var g = choTheoMan
        for (tien, ds) in moiTheoMan { g[tien, default: 0] += ds.count }
        khung.cotTrai.choTheoMan = g
    }

    /// Người mở một màn → phần "chưa xem" của nó về 0.
    func daXem(_ tien: String) {
        guard moiTheoMan[tien] != nil else { return }
        moiTheoMan[tien] = nil
        _veBadge()
    }

    /// Cho bài đo đọc số sự kiện chưa xem.
    public func chuaXem(_ tien: String) -> Int { moiTheoMan[tien]?.count ?? 0 }

    /// `seq` nghe được gần nhất — cho bài đo.
    public var seqDangNghe: Int { seqNghe }

    /// Người bấm "Tải lại" trên dải Dữ liệu cũ — §7.2.
    @objc func _taiLai() {
        khung.datDuLieuCu(false, tre: 0)
        guard let tien = khung.vungLamViec.dangMo else { return }
        moMan(tien, boiTacTu: false)
    }

    // MARK: - lệnh và sự kiện

    /// Số lời gọi `chat.send` đang bay. Không phải `Bool`: hai lượt gõ chồng nhau thì lượt xong
    /// trước sẽ tắt cờ trong khi lượt sau còn đang bay.
    private var guiDangBay = 0

    /// Tin báo mở màn đã nói gần nhất — để không nói lại y hệt. Xem `_moTheoTacTu`.
    private var danBaoMan = ""

    /// Phiên có đang bận không — tín hiệu XÁC ĐỊNH cho bộ lái kịch bản (`--kich-ban`).
    ///
    /// `dock.dangChay` không dùng được vào việc này: nó chỉ được gán lại mỗi khi một sự kiện từ
    /// daemon tới, nên giữa lúc `chat.send` được gọi và lúc sự kiện đầu tiên về, nó vẫn là
    /// `false` — và bộ lái kết luận "xong" rồi chụp ảnh. Đo 21/09/2026 trên chặng A bài CNC:
    /// bước 2 "xong" sau 10,6 s trong khi thẻ Run còn ghi `bước 1/6 ▶ đang chạy req.elicit`.
    ///
    /// CHỈ một vế: `chat.send` có đang bay không.
    ///
    /// Bản đầu thêm vế "còn thẻ Run nào đang chạy" vì tôi tưởng các nút chạy tiếp ở daemon sau
    /// khi `chat.send` trả về. Không phải: `chat.orchestrate` chạy ĐỒNG BỘ, nên lúc `chat.send`
    /// trả lời thì chuỗi đã xong hoặc đã dừng để hỏi người.
    ///
    /// Vế thừa ấy làm treo cả bài đo. Mỗi lời gọi năng lực lồng bên trong (`plan.create`,
    /// `chat.parse_intent`…) cũng dựng một thẻ Run riêng, và chúng KHÔNG nhận `run.done` của
    /// chuỗi — nên một thẻ cũ ghim `dangBan` ở `true` vĩnh viễn.
    ///
    /// Đo 22/09/2026 trên bài CNC: daemon RẢNH (ngăn xếp đứng ở `read` trên stdin), ứng dụng
    /// RẢNH (vòng lặp sự kiện), màn hình ghi "✅ Xong 6/6 bước" — mà bộ lái vẫn đợi thêm 15
    /// phút cho tới khi hết hạn. Chủ sản phẩm nhìn màn hình và nói "vẫn lỗi như cũ, không có
    /// bất kỳ một báo lỗi nào cả" — đúng, vì không có lỗi nào: chỉ có một phép chờ sai.
    public var dangBan: Bool { guiDangBay > 0 }

    private func _gui(_ van: String) async {
        guard let d = daemon else {
            return khung.dock.themLuot(.cho, "Chưa mở dự án nào — tạo hoặc mở một dự án trước.")
        }
        guiDangBay += 1
        defer { guiDangBay -= 1 }
        vanGanNhat = van          // [DEV-181] — thứ sẽ gửi lại nếu chuỗi dừng để hỏi
        do {
            let r = try await d.goi("chat.send", ["text": van])
            // [DEV-154] `state: "running"` = chuỗi đang chạy Ở LUỒNG NỀN của daemon. Thẻ Ý hiểu
            // và thẻ Kết quả tới sau, bằng `event.chat.restated` và `event.chat.report`.
            //
            // Nói MỘT câu ở đây chứ không im: giữa lúc nhận lệnh và lúc sự kiện đầu tiên về có
            // thể mất vài chục giây, và một vùng trao đổi im trong vài chục giây là thứ người
            // dùng đọc thành "nó không nhận lệnh của tôi".
            if (r["state"] as? String) == "running" {
                let y = (r["intent_id"] as? String).map { " (ý hiểu: `\($0)`)" } ?? ""
                khung.dock.themLuot(.tacTu, "Đã nhận\(y) — đang làm. Tiến độ hiện ở thẻ Run, "
                                    + "kết quả hiện ngay dưới đây khi xong.")
                return
            }
            // §2D.6 — thẻ Ý hiểu TRƯỚC câu "đang chạy": người đọc từ trên xuống, và thứ họ cần
            // kiểm là ý hiểu, không phải mã lượt chạy.
            if r["restate"] != nil || r["steps"] != nil {
                // v1.3 — `state == "planned"` nghĩa là chuỗi ĐANG ĐỢI người gật đầu
                // ([DEV-140]). Chỉ khi ấy hai nút của §2D.6 mới có nghĩa; mọi lúc khác chuỗi
                // đã giao đi và một nút "Đúng — làm đi" trên nó là một nút không đảo được gì.
                let cho = (r["state"] as? String) == "planned"
                let ma = (r["run_id"] as? String) ?? ""
                let the = EideTheYHieu(
                    van: (r["restate"] as? String) ?? "",
                    buoc: (r["steps"] as? [[String: Any]] ?? []).compactMap { $0["cap"] as? String },
                    muc: Self.mucTu(khung.thanhTren.mucHienTai),
                    cho: cho)
                if cho {
                    the.onDuyet = { [weak self] in Task { await self?.tiepTuc(ma, true) } }
                    the.onSua = { [weak self] in Task { await self?.tiepTuc(ma, false) } }
                }
                khung.dock.themThe(the)
            }
            // NÚT HỎNG nói TRƯỚC câu "đang chạy": người đọc từ trên xuống, và một lỗi đặt
            // sau một câu nghe-ổn thì bị câu ấy che mất.
            //
            // Đo 21/09/2026, chặng A bài CNC: `req.elicit` hỏng ở nút đầu, năm nút sau kẹt
            // theo, và màn hình chỉ có "DỪNG, đang chờ anh trả lời" — không một chữ về nút
            // hỏng. Người dùng hỏi "vậy tôi trả lời cái gì?" và sản phẩm không có câu trả lời.
            // KẾT QUẢ TỪNG BƯỚC, ngay sau thẻ Ý hiểu. Thứ tự đọc: tôi hiểu gì → tôi làm ra
            // gì → còn gì chờ. Đặt kết quả sau câu "đang chạy" thì nó nằm dưới một dòng nghe
            // như kết luận, và người đọc dừng ở dòng ấy.
            if let br = r["buoc_ra"] as? [[String: Any]], !br.isEmpty {
                khung.dock.themThe(EideTheKetQua(buoc: br))
            }
            for n in (r["hong"] as? [[String: Any]] ?? []) {
                let ma = (n["ma"] as? String).map { "\($0): " } ?? ""
                khung.dock.themLuot(.loi,
                    "✖ Bước `\(n["cap"] as? String ?? "?")` HỎNG — \(ma)"
                    + "\((n["vi"] as? String) ?? "lõi không nói lý do")")
            }
            if let rid = r["run_id"] as? String {
                khung.dock.themLuot(.tacTu, "Đang chạy (run \(rid.prefix(10))) — "
                                    + "\(Self.trangThaiChuoi(r["state"])).")
            }
            // **Không có `run_id` = KHÔNG dựng được chuỗi, và điều đó phải NÓI RA.**
            //
            // Tới đây mọi nhánh trên đều có điều kiện, nên một `chat.send` trả về thứ không
            // khớp nhánh nào đi qua lặng lẽ: người dùng gõ một câu, thấy bong bóng của chính
            // mình, rồi không thấy gì nữa. Đo 21/09 bằng một phiên thật trên bài CNC — tám lượt
            // gõ, KHÔNG một câu trả lời nào, và không một lỗi nào.
            //
            // `chat.send` trả `{intent_id}` trần khi `chat.parse_intent` hoặc `chat.orchestrate`
            // hỏng: hợp đồng cho phép, nên chỗ này phải đọc được cả trường hợp ấy.
            else {
                let y = (r["intent_id"] as? String).map { " (ý hiểu: `\($0)`)" } ?? ""
                khung.dock.themLuot(.loi,
                    "Không dựng được chuỗi cho câu này\(y) — tác tử KHÔNG làm gì cả. "
                    + Self.viSaoKhongCoChuoi(r)
                    + " Xem màn Nhật ký (S2) để đọc lời gọi đã hỏng.")
            }
            // Chuỗi dừng chờ người thì NÓI RA nó chờ gì — không để nó đứng im mãi.
            for n in (r["cho_nguoi"] as? [[String: Any]] ?? []) { _hienCauHoi(n) }
        } catch {
            khung.dock.themLuot(.loi, "\(error)")
        }
        await _lamMoi()
    }

    /// Đường vào cho bài đo — gọi ĐÚNG hàm mà kênh sự kiện thật gọi.
    ///
    /// Không có đường nào để một bài kiểm tự sinh ra một lượt chạy thật: `chat.send` đi qua mô
    /// hình, tức qua mạng và qua tiền. Nên bài đo bơm đúng những bản ghi mà `chat.py` ghi ra, và
    /// mọi thứ sau điểm bơm — gom theo `run_id`, dựng thẻ, đổi chiều cao dock, làm mới cột phải
    /// — vẫn là mã thật.
    public func napSuKien(_ ten: String, _ p: [String: Any]) { _suKien(ten, p) }

    private func _suKien(_ ten: String, _ p: [String: Any]) {
        lucCuoiNghe = Date()
        _theoSeq(p)
        _dinhTuyen(ten, p)
        // ---- [DEV-154] kết quả của một lượt gõ nay tới BẰNG SỰ KIỆN.
        //
        // `chat.send` trả về ngay với `state: "running"`; thẻ Ý hiểu và thẻ Kết quả từng bước
        // đến sau, qua hai sự kiện mà `openrpc.json` đã khai từ trước.
        if ten == "event.chat.restated" { _nhanYHieu(p); return }
        if ten == "event.chat.report" { _nhanBaoCao(p); return }
        guard ten == "event.run.progress" else { return }
        _theoRun(p)
        guard let cap = p["cap"] as? String else { return }
        // NT2 — **TÁC TỬ** chạm tới đâu, màn ấy tự mở và ĐƯỢC FOCUS.
        //
        // Cùng bộ lọc của `_theoRun` ngay dưới, và cùng một lý do: `event.run.progress` gánh
        // hai khái niệm, và chỉ một trong hai là "tác tử đang làm việc". Cái còn lại —
        // `cap.run.*` của một lời gọi đơn lẻ — bao gồm cả những lời gọi mà CHÍNH MỘT MÀN vừa
        // mở phát ra để tự vẽ.
        //
        // Không lọc thì mở một màn đọc năng lực thuộc về màn khác sẽ bị chính mình đẩy đi.
        // Đo 20/09 bằng ảnh chụp cửa sổ thật: bấm *Hộ chiếu chip* → màn ấy gọi `project.status`
        // để biết chip đã ghim → NT2 thấy `project.status` thuộc màn *Tổng quan* → nhảy sang
        // Tổng quan. Ảnh `man-Passport.png` ra một màn Tổng quan với thân trống, và dòng
        // `hiện xong sau 0,55 s (lõi 0 ms, vẽ 0 ms)` đo nhầm một màn khác. Không test nào thấy:
        // cả hai màn đều đúng ở mức đơn vị, chỗ hỏng nằm giữa chúng.
        guard Self.laDoiTrangThai(ten, p) else { return }
        guard let man = manCua[cap], !man.isEmpty else { return }
        let tien = EideManHinhDS.tatCa.first { man.hasPrefix($0.tien) }?.tien
        guard let tien, tien != khung.vungLamViec.dangMo else { return }
        let nhan = EideManHinhDS.nhan(tien)
        // NÓI MỘT LẦN cho mỗi màn. Một chuỗi sáu nút thường đọc đi đọc lại cùng một màn, và
        // bản trước nói lại nguyên câu mỗi lần: đo 21/09/2026 trên chặng A bài CNC, câu §2C.3
        // hiện BỐN lần liên tiếp, giống nhau từng chữ, trong một vùng trao đổi chỉ có ba lượt
        // người gõ. Chuỗi càng dài thì tỉ lệ càng tệ — và người dùng học cách bỏ qua cả loại
        // thông báo ấy, kể cả lần nó nói điều quan trọng.
        //
        // Khoá theo (màn, có mở được hay không): nếu lần sau màn ấy mở lên trước mặt thật thì
        // đó là một tin KHÁC và phải nói.
        let moDuoc = moMan(tien, boiTacTu: true, khoaViec: Self.khoaViec(p))
        let khoa = "\(tien)|\(moDuoc)"
        defer { danBaoMan = khoa }
        guard danBaoMan != khoa else { return }
        if moDuoc {
            khung.dock.themLuot(.heThong, "→ mở màn \(nhan) (tác tử đang chạy `\(cap)`)")
        } else {
            khung.dock.themLuot(.heThong, "→ \(nhan) mở ở NỀN — anh vừa tự chọn màn khác chưa quá "
                + "\(Int(Self.GIU_MAN)) giây (§2C.3). Tab đã thêm, cột trái đang nháy.")
        }
    }

    /// Người duyệt hoặc từ chối một mục chờ.
    ///
    /// Không đoán kết quả: chỉ khi daemon trả lời xong mới đọc lại hàng đợi. Cột phải là bản
    /// chiếu (B7) — nếu nó tự xoá thẻ trước, một lần từ chối bị chính sách chặn sẽ biến mất khỏi
    /// màn hình mà việc vẫn còn nằm trong hàng đợi.
    /// `ghiChu` đi thẳng vào `note?` của API-15 §2 — ô "lý do" trên thẻ hứa *ghi vào sổ quyết
    /// định*, nên đánh rơi nó ở đây là để sản phẩm nói dối một câu nhỏ mỗi lần người dùng gõ.
    private func _quyet(_ ma: String, _ thuan: Bool, ghiChu: String = "") async {
        guard let d = daemon else { return }
        do {
            let r = try await d.goi("gate.decide",
                                    ["gate_id": ma, "decision": thuan ? "approve" : "reject",
                                     "note": ghiChu])
            let tt = r["status"] as? String ?? "?"
            khung.dock.themLuot(thuan ? .heThong : .cho,
                "\(thuan ? "Đã duyệt" : "Đã từ chối") `\(r["cap"] as? String ?? ma)` — \(tt).")
        } catch {
            khung.dock.themLuot(.loi, "\(error)")
        }
        await _lamMoi()
    }

    /// "Đã hoàn tác (supersede_facts)" trả lời sai câu hỏi người dùng đang hỏi.
    ///
    /// Họ không hỏi loại hoàn tác là gì — họ hỏi **cái gì vừa đổi**. Tên loại là từ vựng của
    /// POL-17, không phải của người bấm nút. Mỗi loại trả về những trường khác nhau, nên đọc
    /// đúng trường của loại ấy và nói ra bằng tiếng Việt; loại nào không có gì để nói thì im,
    /// chứ không bịa một con số cho đủ câu.
    static func doiLaiGi(_ r: [String: Any]) -> String {
        var y: [String] = []
        if let n = (r["superseded"] as? [Any])?.count, n > 0 { y.append("rút \(n) fact") }
        if let n = (r["restored"] as? [Any])?.count, n > 0 { y.append("trả \(n) fact cũ về") }
        if let n = (r["kept"] as? [Any])?.count, n > 0 { y.append("giữ nguyên \(n) fact") }
        if let n = r["reverted"] as? Int, n > 0 { y.append("đảo \(n) commit") }
        if let c = r["revert_commit"] as? String, !c.isEmpty { y.append("commit \(c.prefix(8))") }
        if let c = r["commit"] as? String, r["revert_commit"] == nil, !c.isEmpty {
            y.append("commit \(c.prefix(8))")
        }
        if r["clar_id"] != nil {
            // `restore_answer` lùi MỘT bước trong lịch sử, nên phải nói rõ về bản nào — "đã
            // hoàn tác" mà không nói quay về đâu thì người dùng vẫn phải đi mở tab để xem.
            y.append((r["quay_ve"] as? String).map { "quay về: \($0)" } ?? "điểm này về chưa trả lời")
        }
        return y.isEmpty ? "" : " — " + y.joined(separator: ", ")
    }

    private func _hoanTac(_ ma: String) async {
        guard let d = daemon else { return }
        do {
            // ĐỌC câu trả lời. `undo.apply` trả `{applied, kind, reason?}` và `applied: false`
            // là một câu trả lời HỢP LỆ, không phải lỗi: `Router.undo` trả nó khi loại hoàn tác
            // ấy chưa có hiện thực. Bản trước `_ =` vứt nó đi rồi báo "Đã hoàn tác" vô điều
            // kiện.
            //
            // Đo 21/09/2026: `cds.json` khai 5 loại hoàn tác — `supersede_facts` (18 năng lực)
            // và `reflash_known_good` (5) CHƯA có hiện thực nào đăng ký. Với 23 năng lực ấy,
            // người dùng bấm Hoàn tác, màn hình nói đã hoàn tác, và KHÔNG có gì được hoàn tác.
            //
            // Đây là kiểu nói dối tệ nhất trong sản phẩm này: nó làm người dùng tin rằng một
            // thay đổi đã được gỡ bỏ, nên họ thôi tìm cách gỡ nó.
            //
            // 22/09/2026 [DEV-170]: `supersede_facts` đã có hiện thực. Còn lại
            // `reflash_known_good` (5 năng lực) — nó chờ `target.flash`, một năng lực chạm
            // PHẦN CỨNG chưa viết, nên nhánh "chưa có hiện thực" bên dưới vẫn phải giữ.
            let r = try await d.goi("undo.apply", ["undo_ref": ma])
            if (r["applied"] as? Bool) == false {
                khung.dock.themLuot(.loi,
                    "✖ KHÔNG hoàn tác được `\(ma.prefix(12))` — việc đã làm VẪN CÒN NGUYÊN. "
                    + ((r["reason"] as? String) ?? "lõi không nói lý do") + ".")
            } else {
                khung.dock.themLuot(.heThong, "Đã hoàn tác `\(ma.prefix(12))`"
                                    + ((r["kind"] as? String).map { " (\($0))" } ?? "")
                                    + Self.doiLaiGi(r) + ".")
            }
        } catch {
            khung.dock.themLuot(.loi, "Không hoàn tác được: \(error)")
        }
        await _lamMoi()
        await veLaiManDangMo()
    }

    /// Vẽ lại màn đang mở từ store.
    ///
    /// `_lamMoi` chỉ dựng lại thanh trên và cột phải; vùng làm việc giữ nguyên thứ nó đọc lúc
    /// mở. Với các màn chỉ-đọc điều đó vô hại, nhưng hoàn tác ĐỔI dữ liệu ngay dưới chân màn
    /// đang mở. Đo 22/09/2026 qua ảnh chụp: bấm Hoàn tác một câu trả lời, vùng trao đổi báo
    /// "Đã hoàn tác (restore_answer)", và bảng ở tab Làm rõ yêu cầu VẪN hiện câu trả lời vừa
    /// bị gỡ — người dùng đọc hai điều trái ngược trên cùng một khung hình.
    public func veLaiManDangMo() async {
        guard let tien = khung.vungLamViec.dangMo, !tien.isEmpty,
              Self.MAN[tien] != nil else { return }
        _ = moMan(tien, boiTacTu: false)
    }

    /// Dừng khẩn. Công khai vì bài tự kiểm phải bấm được đúng cái nút người bấm.
    public func dungKhan() async { await _dungKhan() }

    /// Gom mọi sự kiện của MỘT lượt chạy về MỘT thẻ.
    ///
    /// Thẻ dựng LƯỜI: mở ứng dụng giữa một lượt chạy đang dở thì sự kiện đầu tiên nghe được là
    /// `run.step_started`, không phải `run.started`. Chờ đúng `run.started` mới dựng thẻ nghĩa
    /// là lượt chạy ấy không bao giờ hiện ra.
    private func _theoRun(_ p: [String: Any]) {
        guard let ma = p["run_id"] as? String else { return }
        // CHỈ lượt chạy nhiều bước. `event.run.progress` gánh hai khái niệm: vòng đời của một
        // CHUỖI (`run.*`) và vòng đời của MỘT lời gọi năng lực (`cap.run.*`). Không lọc thì mỗi
        // lời gọi đơn lẻ — kể cả `plane.hello` của nhịp tim — sinh một thẻ Run riêng, và vùng
        // trao đổi đầy những thẻ một đoạn không tiêu đề. Đo 18/09 bằng ảnh chụp: một dải xanh
        // chạy hết chiều ngang nằm trên thẻ thật, không chữ nào, không ai đoán được nó là gì.
        //
        // Một lời gọi THUỘC một chuỗi thì vẫn nhận: daemon đã đổi `run_id` của nó sang mã chuỗi
        // và gắn `node_id`, nên nó là một bước chứ không phải một lượt chạy riêng.
        let loai = (p["kind"] as? String) ?? ""
        // `as? String` chứ KHÔNG `!= nil`. JSON `null` tới đây thành `NSNull`, và `NSNull` khác
        // `nil` — nên phép so cũ cho lọt mọi bản ghi có khoá `node_id` rỗng. [DEV-167]
        //
        // Vá cả hai đầu: daemon thôi gửi khoá rỗng, và chỗ này thôi tin rằng "có khoá" nghĩa là
        // "có giá trị". Một bên sửa là đủ để hết triệu chứng, nhưng cùng một nhầm lẫn sẽ quay
        // lại ở khoá khác — `null` đi qua JSON là chuyện thường xuyên.
        let laNut = (p["node_id"] as? String).map { !$0.isEmpty } ?? false
        guard loai.hasPrefix("run.") || laNut else { return }
        let the: EideTheRun
        if let co = theRun[ma] {
            the = co
        } else {
            the = EideTheRun(ma: ma, van: (p["text"] as? String) ?? "Lượt chạy \(ma.prefix(8))")
            the.onChiTiet = { [weak self] _ in self?.moMan("NhatKy", boiTacTu: false) }
            the.onDung = { [weak self] in Task { await self?.dungKhan() } }
            theRun[ma] = the
            khung.dock.themThe(the)
            // Run mới bắt đầu → dock về mức chuẩn (§2D): đúng lúc ấy có thứ mới để đọc, và một
            // thẻ Run nằm trong vùng cao 48 pt là thẻ không ai thấy.
            khung.dock.datCao(.chuan)
        }
        let truoc = the.trangThai
        the.nhan(p)
        if the.trangThai == .chan || the.trangThai == .xong || the.trangThai == .huy {
            Task { await _lamMoi() }
        }
        // §2E.6 — chỉ ở LẦN ĐẦU chuyển sang trạng thái kết thúc. `run.done` có thể tới nhiều lần
        // (nghe lại sổ cái, nạp lại sau khi mất daemon), và mỗi lần in một báo cáo là vùng trao
        // đổi đầy bản sao của cùng một việc.
        guard truoc != the.trangThai else { return }
        if the.trangThai == .xong {
            Task { await _baoCao(ma) }
        } else if the.trangThai == .huy {
            khung.dock.themLuot(.cho, Self.cauHuy(p))
        }
    }

    // MARK: - §9.1 điều hướng bằng bàn phím

    /// ⌘1…⌘6 — nhảy tới nhóm thứ `i` ở cột trái, mở màn ĐẦU của nhóm.
    ///
    /// Mở màn đầu chứ không chỉ cuộn tới tiêu đề nhóm: một phím tắt đưa người tới một tiêu đề
    /// rồi bắt họ bấm chuột tiếp thì nó chưa thay được cái bấm chuột nào.
    @discardableResult
    public func nhayNhom(_ i: Int) -> String? {
        let nhom = EideManHinhDS.nhom
        guard i >= 1, i <= nhom.count, let dau = nhom[i - 1].man.first else { return nil }
        moMan(dau.tien, boiTacTu: false)
        return dau.tien
    }

    /// ⌘W — đóng tab đang mở. Không tab nào thì KHÔNG đóng cửa sổ: ⌘W trong một IDE là "đóng
    /// cái tôi đang xem", và để nó rơi xuống thành "đóng cả ứng dụng" là mất việc vì một phím.
    @discardableResult
    public func dongTabHienTai() -> Bool {
        guard let t = khung.thanhTab.dangMo else { return false }
        if let ke = khung.thanhTab.dong(t) {
            moMan(ke, boiTacTu: false)
        } else {
            khung.vungLamViec.dongMan()
        }
        return true
    }

    /// ⌘S — `code.human_save` trên tệp đang mở ở S14.
    ///
    /// Không mở S14 thì NÓI RA. ⌘S là phản xạ mạnh nhất của người viết mã; bấm nó mà không có
    /// gì xảy ra và không có lời nào là để họ tin rằng mình đã lưu.
    public func luuTepHienTai() async {
        guard let soan = khung.vungLamViec.manDangMo as? EideManSoanThao else {
            return khung.dock.themLuot(.cho,
                "⌘S lưu tệp của Trình soạn thảo (S14) — màn ấy đang không mở.")
        }
        guard soan.ban else {
            return khung.dock.themLuot(.heThong, "Không có gì để lưu — bộ đệm chưa đổi.")
        }
        await soan.luu()
    }

    // MARK: - §6.1 modal P-EDIT-01

    /// Quy tắc sinh ra modal §6.1. Một chuỗi, không phải một danh sách: P-EDIT-01 là quy tắc
    /// DUY NHẤT nói về "tệp đích đang có sửa chưa lưu của người".
    public static let LUAT_BAN = "P-EDIT-01"

    /// Mở modal cho mục chờ `P-EDIT-01` đầu tiên trong hàng đợi — §6.1.
    ///
    /// Modal chứ không để nó nằm im trong cột phải: mục chờ ở cột phải là danh sách việc người
    /// dùng xử lý *khi nào rảnh*, còn đây là một tác tử đang ĐỨNG ĐỢI trên đúng tệp người đang
    /// gõ. Hai thứ ấy khác nhau về độ gấp, và trộn chúng làm một thì cái gấp chìm vào cái không.
    ///
    /// Chỉ mở MỘT lần cho một mục: `_lamMoi()` chạy sau mỗi lần duyệt, mỗi lần hoàn tác và mỗi
    /// lần một lượt chạy đổi trạng thái, nên mở vô điều kiện sẽ dựng lại modal ngay sau khi
    /// người vừa đóng nó.
    private func _hoiPEdit(_ cho: [[String: Any]]) {
        guard khung.modalHoi.isHidden else { return }
        let muc = cho.first {
            (($0["decision"] as? [String: Any])?["rule"] as? String) == Self.LUAT_BAN
        }
        guard let muc, let ma = muc["run_id"] as? String, ma != daHoi else { return }
        daHoi = ma
        let soan = khung.vungLamViec.manDangMo as? EideManSoanThao
        khung.modalHoi.mo(
            maCho: ma,
            cap: (muc["cap"] as? String) ?? "một năng lực ghi mã",
            tep: (soan?.ban ?? false) ? soan?.dangMo : nil,
            vi: ((muc["decision"] as? [String: Any])?["reason"] as? String) ?? "")
    }

    /// Mục chờ đã hỏi rồi — đừng hỏi lại cùng một cái.
    private var daHoi = ""

    /// Người trả lời modal §6.1.
    private func _traLoiPEdit(_ thuan: Bool, _ ma: String) async {
        guard let d = daemon else { return }
        // Vế thuận là HAI việc theo đúng thứ tự: lưu bản của người TRƯỚC, rồi mới cho tác tử
        // chạy tiếp. Đảo thứ tự thì tác tử ghi lên tệp rồi bản của người mới lưu đè lại — và
        // lúc ấy chính việc của tác tử biến mất, lặng lẽ.
        if thuan, let soan = khung.vungLamViec.manDangMo as? EideManSoanThao, soan.ban {
            await soan.luu()
            if soan.ban {
                khung.dock.themLuot(.loi, "Không lưu được bộ đệm — KHÔNG cho tác tử chạy tiếp. "
                                    + "Sửa chỗ lưu hỏng trước, rồi duyệt lại ở cột phải.")
                daHoi = ""
                return
            }
        }
        await _quyet(ma, thuan)
    }

    /// Đặt mức tự chủ — cho bài tự kiểm dựng đúng điều kiện của §2D.6.
    @discardableResult
    public func datMucDeTest(_ muc: String) async throws -> String {
        guard let d = daemon else { return "" }
        let r = try await d.goi("autonomy.set", ["level": muc, "by": "human:tu-kiem"])
        await _lamMoi()
        return (r["effective"] as? String) ?? muc
    }

    /// Kết quả lập kế hoạch — cho bài tự kiểm đo §2D.6 trên daemon thật.
    public struct KeHoach {
        public let ma: String
        public let trangThai: String
        public let soBuoc: Int
    }

    /// Gửi một câu và trả về trạng thái lập kế hoạch. Đi ĐÚNG đường `chat.send` mà người dùng
    /// đi, nên nó đo cả phép quyết định `plan_only` theo mức tự chủ ở daemon.
    public func lapKeHoachDeTest(_ van: String) async throws -> KeHoach {
        guard let d = daemon else { return KeHoach(ma: "", trangThai: "—", soBuoc: 0) }
        let r = try await d.goi("chat.send", ["text": van])
        return KeHoach(ma: (r["run_id"] as? String) ?? "",
                       trangThai: (r["state"] as? String) ?? "—",
                       soBuoc: (r["steps"] as? [[String: Any]])?.count ?? 0)
    }

    /// Trạng thái một lượt chạy, bằng tiếng người.
    ///
    /// `asked` là chỗ hay bị đọc nhầm nhất: nó KHÔNG phải lỗi và cũng không phải xong — chuỗi
    /// dừng lại để hỏi. Hiện nguyên chữ `asked` thì người dùng không biết mình đang phải làm gì.
    static func trangThaiChuoi(_ x: Any?) -> String {
        switch (x as? String) ?? "" {
        case "planned": return "đang chờ anh gật đầu"
        case "running": return "đang chạy"
        case "asked": return "DỪNG, đang chờ anh trả lời"
        case "failed": return "DỪNG vì có bước hỏng — KHÔNG chờ anh, xem dòng ✖ ở trên"
        case "done": return "xong"
        case "blocked": return "bị cổng chặn"
        case "cancelled": return "đã huỷ"
        default: return "trạng thái chưa rõ"
        }
    }

    /// Đoán lý do chuỗi không dựng được, từ CHÍNH câu trả lời — không bịa.
    ///
    /// `chat.send` trả `asdict(run)` của lời gọi hỏng, nên `error.message` thường đã nói đủ.
    /// Không có thì nói thẳng là không biết: một câu đoán sai đẩy người dùng đi sửa nhầm chỗ.
    static func viSaoKhongCoChuoi(_ r: [String: Any]) -> String {
        if let e = r["error"] as? [String: Any] {
            let ma = (e["eide_code"] as? String).map { "\($0): " } ?? ""
            return "Lý do — \(ma)\((e["message"] as? String) ?? "không rõ")."
        }
        if let run = r["run"] as? [String: Any],
           let e = run["error"] as? [String: Any] {
            let ma = (e["eide_code"] as? String).map { "\($0): " } ?? ""
            return "Lý do — \(ma)\((e["message"] as? String) ?? "không rõ")."
        }
        return "Lõi không nói lý do."
    }

    /// `event.chat.restated` → thẻ Ý hiểu. [DEV-154]
    ///
    /// Thẻ này tới TRƯỚC thẻ kết quả, vì §2D.6 đặt nó làm chỗ người bắt một lệnh bị hiểu sai
    /// trước khi nó ghi tệp. Tới sau thì nó chỉ còn là một bản tường thuật.
    private func _nhanYHieu(_ p: [String: Any]) {
        let cho = (p["state"] as? String) == "planned"
        let ma = (p["run_id"] as? String) ?? ""
        let the = EideTheYHieu(
            van: (p["text"] as? String) ?? "",
            buoc: (p["steps"] as? [[String: Any]] ?? []).compactMap { $0["cap"] as? String },
            muc: Self.mucTu(khung.thanhTren.mucHienTai),
            cho: cho)
        if cho {
            the.onDuyet = { [weak self] in Task { await self?.tiepTuc(ma, true) } }
            the.onSua = { [weak self] in Task { await self?.tiepTuc(ma, false) } }
        }
        khung.dock.themThe(the)
    }

    /// `event.chat.report` → thẻ Kết quả từng bước, dòng lỗi, câu hỏi chờ người. [DEV-154]
    ///
    /// Thứ tự đọc: bước nào hỏng TRƯỚC (một lỗi đặt sau một câu nghe-ổn thì bị che), rồi làm
    /// ra gì, rồi còn chờ gì.
    /// Số báo cáo lượt chạy đã nhận. Mốc để bộ lái kịch bản biết một lượt gõ đã xong —
    /// `chat.send` nay trả về ngay, nên "hết bận" không còn nghĩa là "xong việc". [DEV-154]
    public private(set) var soBaoCao = 0

    private func _nhanBaoCao(_ p: [String: Any]) {
        soBaoCao += 1
        if let vi = p["loi"] as? String, !vi.isEmpty {
            khung.dock.themLuot(.loi, "✖ Lượt này KHÔNG chạy được — \(vi)")
        }
        for n in (p["failed"] as? [[String: Any]] ?? []) {
            let ma = (n["ma"] as? String).map { "\($0): " } ?? ""
            khung.dock.themLuot(.loi,
                "✖ Bước `\(n["cap"] as? String ?? "?")` HỎNG — \(ma)"
                + "\((n["vi"] as? String) ?? "lõi không nói lý do")")
        }
        if let br = p["done"] as? [[String: Any]], !br.isEmpty {
            khung.dock.themThe(EideTheKetQua(buoc: br))
        }
        if let v = p["van"] as? String, !v.isEmpty { vanGanNhat = v }
        for n in (p["waiting"] as? [[String: Any]] ?? []) { _hienCauHoi(n) }
        if let st = p["state"] as? String, !st.isEmpty {
            khung.dock.themLuot(.tacTu, "Lượt chạy \(Self.trangThaiChuoi(st)).")
        }
        Task { [weak self] in
            await self?._lamMoi()
            await self?.veLaiManDangMo()
        }
    }

    /// Câu gõ gần nhất của người — để gửi LẠI sau khi họ trả lời một câu hỏi. [DEV-181]
    ///
    /// Giữ ở đây chứ không đọc ngược vùng trao đổi: bong bóng trên màn là thứ để ĐỌC, dùng nó
    /// làm nguồn dữ liệu thì mỗi lần đổi cách hiển thị lại đổi cả hành vi.
    public private(set) var vanGanNhat = ""

    /// Một mục `waiting`/`cho_nguoi` → một THẺ HỎI trong vùng trao đổi. [DEV-181]
    ///
    /// Trước đây chỗ này in một dòng chữ: *"Dừng ở `env.check` — cần anh cho biết: isa"*. Câu ấy
    /// đúng và vô dụng: nó nêu tên một tham số, không nêu một câu hỏi, và không có chỗ nào để
    /// trả lời. Chủ sản phẩm đọc xong hỏi lại đúng hai câu — *"Tôi cần tìm chỗ nào để trả lời?"*
    /// và *"isa cho cái gì? Tôi cần bạn tư vấn mà"*.
    ///
    /// Lõi nay gửi kèm `clar_id`, `hoi` (tiếng Việt) và `truong[].lua_chon` (tập giá trị hợp lệ
    /// đọc từ `docs/spec/isa/` hoặc bảng passport). Thiếu `clar_id` thì KHÔNG dựng thẻ — một ô
    /// trả lời không biết ghi câu trả lời vào đâu còn tệ hơn một dòng chữ, vì nó hứa hẹn.
    private func _hienCauHoi(_ n: [String: Any]) {
        let cap = (n["cap"] as? String) ?? "?"
        let clarId = (n["clar_id"] as? String) ?? ""
        let truong: [EideTheHoi.Truong] = (n["truong"] as? [[String: Any]] ?? []).map { t in
            EideTheHoi.Truong(
                khoa: (t["khoa"] as? String) ?? "",
                hoi: (t["hoi"] as? String) ?? ((t["khoa"] as? String) ?? ""),
                luaChon: (t["lua_chon"] as? [[String: Any]] ?? []).map {
                    (giaTri: ($0["gia_tri"] as? String) ?? "",
                     giaiThich: ($0["giai_thich"] as? String) ?? "")
                })
        }
        guard !clarId.isEmpty, !truong.isEmpty else {
            let thieu = (n["thieu"] as? [String] ?? []).joined(separator: ", ")
            return khung.dock.themLuot(.cho, "Dừng ở `\(cap)` — "
                + (thieu.isEmpty ? ((n["vi"] as? String) ?? "chờ người")
                                 : "cần anh cho biết: \(thieu)")
                + " — mở tab Làm rõ yêu cầu để trả lời.")
        }
        let the = EideTheHoi(cap: cap, loai: .thieuThamSo(clarId: clarId, truong: truong))
        the.onTraLoi = { [weak self] ma, van in
            Task { await self?.traLoiCauHoi(ma, van) }
        }
        khung.dock.themThe(the)
    }

    /// Ghi câu trả lời rồi CHẠY LẠI câu gốc. [DEV-181]
    ///
    /// Hai việc, không một: `req.answer_clarification` đóng điểm cần làm rõ, nhưng chuỗi đã dừng
    /// từ trước và không có gì đánh thức nó. Chỉ ghi thôi thì người dùng trả lời xong ngồi nhìn
    /// một màn hình không đổi — nửa vòng lặp, đúng chỗ hỏng mà thẻ này sinh ra để vá.
    ///
    /// Chạy lại bằng chính câu gõ cũ chứ không "tiếp tục từ nút đang dở": lượt mới đọc câu trả
    /// lời qua lớp C2 (CXD-10 §2, `memory._c2_tra_loi_cua_nguoi`), nên nó không hỏi lại — và nó
    /// đi qua cổng chính sách một lần nữa như mọi lượt khác, thay vì có một đường vòng riêng.
    public func traLoiCauHoi(_ clarId: String, _ van: String) async {
        guard let d = daemon else { return }
        khung.dock.themLuot(.nguoi, van)
        do {
            _ = try await d.goi("caps.invoke",
                                ["id": "req.answer_clarification",
                                 "params": ["clar_id": clarId, "answer": van]])
        } catch {
            return khung.dock.themLuot(.loi, "Không ghi được câu trả lời: \(error)")
        }
        await _lamMoi()
        await veLaiManDangMo()
        guard !vanGanNhat.isEmpty else {
            return khung.dock.themLuot(.tacTu, "Đã ghi câu trả lời. Gõ lại việc anh cần để "
                                       + "tác tử chạy tiếp với dữ kiện này.")
        }
        khung.dock.themLuot(.tacTu, "Đã ghi câu trả lời — chạy lại việc cũ với dữ kiện này.")
        await _gui(vanGanNhat)
    }

    /// Cổng đã hiện thẻ trong vùng trao đổi — để không in lại mỗi nhịp làm mới.
    private var daHienCong: Set<String> = []

    /// Mục bị CỔNG chặn → thẻ Duyệt/Từ chối **ngay trong vùng trao đổi**. [DEV-181]
    ///
    /// Chủ sản phẩm chốt 22/09/2026: *"nút duyệt hoặc phê duyệt luôn ở ô trả lời chat"*. Cột
    /// phải vẫn giữ nguyên thẻ chờ — nó là chỗ TRA CỨU còn treo bao nhiêu việc; vùng trao đổi
    /// là chỗ ĐỐI THOẠI, và một câu hỏi chỉ hiện ở chỗ tra cứu là câu hỏi người đang trò chuyện
    /// không nghe thấy. Cùng lập luận với thẻ hỏi thiếu tham số ngay trên.
    ///
    /// Đọc từ `queue.list` chứ không từ `event.gate.opened`: `gate.decide` cần `gate_id`, và mã
    /// ấy là `run_id` của mục chờ — sự kiện cổng không mang nó. Dựng thẻ từ một nguồn không có
    /// mã thì được một nút bấm vào không đâu.
    private func _hienCongChan(_ cho: [[String: Any]]) {
        let con = Set(cho.compactMap { $0["run_id"] as? String })
        daHienCong.formIntersection(con)   // mục đã quyết xong thì quên đi: lần sau là tin MỚI
        for m in cho {
            guard let ma = m["run_id"] as? String, !daHienCong.contains(ma) else { continue }
            let qd = (m["decision"] as? [String: Any]) ?? [:]
            daHienCong.insert(ma)
            let the = EideTheHoi(cap: (m["cap"] as? String) ?? "?", loai: .congChan(
                khoa: ma,
                cong: (qd["gate"] as? String) ?? "?",
                quyTac: (qd["rule_id"] as? String) ?? (qd["rule"] as? String) ?? "—",
                lyDo: (qd["reason"] as? String) ?? "chính sách không nói lý do"))
            the.onQuyet = { [weak self] khoa, thuan, ly in
                Task { await self?._quyet(khoa, thuan, ghiChu: ly) }
            }
            khung.dock.themThe(the)
        }
    }

    /// Người trả lời thẻ Ý hiểu — §2D.6, [DEV-140].
    ///
    /// `thuan = false` là **HUỶ**, không phải "để đó": người bấm *Sửa ý hiểu* nói chuỗi này
    /// sai, và để nó ở `planned` thì lần mở dự án sau nó vẫn nằm trong hàng đợi như một việc
    /// đang chờ — người dùng phải nhớ rằng chính mình đã từ chối nó.
    public func tiepTuc(_ runId: String, _ thuan: Bool) async {
        guard let d = daemon, !runId.isEmpty else { return }
        do {
            let r = try await d.goi("chat.resume", ["run_id": runId, "approve": thuan])
            let tt = (r["state"] as? String) ?? "?"
            khung.dock.themLuot(thuan ? .heThong : .cho,
                thuan ? "Đã duyệt ý hiểu — chuỗi chạy tiếp (\(tt))."
                      : "Đã huỷ chuỗi. Gõ lại câu lệnh với ý anh muốn.")
            for n in (r["cho_nguoi"] as? [[String: Any]] ?? []) { _hienCauHoi(n) }
        } catch {
            khung.dock.themLuot(.loi, "\(error)")
        }
        await _lamMoi()
    }

    /// `" Tự chủ A2 "` → `"A2"`; `" ĐÃ DỪNG KHẨN · A0 "` → `"A0"`. Đọc từ chính huy hiệu người
    /// đang nhìn, không giữ một bản sao thứ hai của mức tự chủ.
    static func mucTu(_ nhan: String) -> String? {
        nhan.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .last { $0.count == 2 && $0.hasPrefix("A") && $0.last!.isNumber }
            .map(String.init)
    }

    /// Câu cho một lượt chạy bị huỷ — §2E.6 vế sau: **ai huỷ, lúc nào.**
    ///
    /// Hai thứ ấy không trang trí. Một lượt chạy biến mất mà không nói ai cắt nó thì người dùng
    /// phải đoán giữa "tôi bấm Dừng khẩn", "chính sách chặn" và "daemon chết" — ba nguyên nhân
    /// dẫn tới ba việc sửa hoàn toàn khác nhau.
    static func cauHuy(_ p: [String: Any]) -> String {
        let ai = (p["by"] as? String) ?? (p["actor"] as? String) ?? "không rõ ai"
        let luc = p["at"] is String ? EideManNhatKy.gio(p["at"] as? String)
                                    : "không rõ lúc nào"
        let vi = (p["reason"] as? String).map { " — \($0)" } ?? ""
        return "Lượt chạy bị huỷ: \(ai), lúc \(luc)\(vi)."
    }

    /// §2E.6 — `run.done` → `chat.report_back` in báo cáo NGAY DƯỚI thẻ.
    ///
    /// Gọi năng lực thật chứ không tự tóm tắt từ các sự kiện đã nghe: CHAT-07 là chỗ duy nhất
    /// biết đủ bốn thứ báo cáo cần (sản phẩm, cổng đã qua, chi phí, mục hoàn tác được), và ba
    /// trong bốn thứ ấy giao diện không nghe được từ `event.run.progress`.
    private func _baoCao(_ runId: String) async {
        guard let d = daemon else { return }
        do {
            let r = try EideKetQua.boc(
                try await d.goi("caps.invoke",
                                ["id": "chat.report_back", "params": ["run_id": runId]]),
                "chat.report_back")
            let van = (r["text"] as? String) ?? ""
            khung.dock.themLuot(.tacTu, van.isEmpty
                ? "Lượt chạy xong. `chat.report_back` không trả câu tóm tắt nào — xem màn Nhật ký."
                : van)
        } catch {
            // Báo cáo hỏng KHÔNG được nuốt: người vừa thấy một lượt chạy xong và đang chờ biết nó
            // làm được gì. Im lặng ở đây đọc thành "xong rồi, không có gì để nói".
            khung.dock.themLuot(.cho, "Lượt chạy xong, nhưng không lấy được báo cáo "
                                + "(`chat.report_back`): \(error). Xem màn Nhật ký (S2).")
        }
    }

    /// Gọi một năng lực từ bảng lệnh.
    ///
    /// KHÔNG đoán tham số. Năng lực nào cần tham số thì lời gọi dừng ở cổng hoặc trả E1000, và
    /// câu trả lời ấy được nói nguyên văn ra vùng trao đổi — tự điền một giá trị "hợp lý" cho
    /// một năng lực có thể ghi tệp hoặc nạp firmware là cách nhanh nhất để mất lòng tin.
    public func goiNangLuc(_ id: String) async {
        guard daemon != nil else {
            return khung.dock.themLuot(.cho, "Chưa mở dự án nào — tạo hoặc mở một dự án trước.")
        }
        // §4.4 — cần tham số bắt buộc thì MỞ FORM, không gọi thiếu. Gọi thiếu trả E1000
        // INPUT_SCHEMA: một mã lỗi đúng, mà đọc xong vẫn không biết phải điền gì.
        if let mota = try? await daemon?.goi("caps.describe", ["id": id]),
           !EideFormThamSo.batBuoc(mota).isEmpty {
            khung.formThamSo.mo(id: id, mota: mota)
            return
        }
        await goiNangLuc(id, [:])
    }

    /// Gọi một năng lực với tham số đã có. Đường chung của bảng lệnh và form §4.4.
    public func goiNangLuc(_ id: String, _ tham: [String: Any]) async {
        guard let d = daemon else {
            return khung.dock.themLuot(.cho, "Chưa mở dự án nào — tạo hoặc mở một dự án trước.")
        }
        khung.dock.themLuot(.nguoi, tham.isEmpty ? "/\(id)"
            : "/\(id) \(tham.keys.sorted().map { "\($0)=\(tham[$0]!)" }.joined(separator: " "))")
        do {
            let tho = try await d.goi("caps.invoke", ["id": id, "params": tham])
            // §4.3 — toast quyết định cổng, đọc TRƯỚC khi bóc kết quả. `EideKetQua.boc` ném khi
            // lời gọi không `done`, và đúng những lần ấy mới là lúc người dùng cần biết cổng nào
            // chặn: bóc trước thì quyết định rơi mất đúng ở nhánh nó có giá trị nhất.
            if let dec = tho["decision"] as? [String: Any] {
                khung.toast.hien(dec, cap: id)
                khung.dock.themLuot(.heThong, EideToast.cau(dec, cap: id))
            }
            let r = try EideKetQua.boc(tho, id)
            let khoa = r.keys.sorted().prefix(4).joined(separator: ", ")
            khung.dock.themLuot(.tacTu, "`\(id)` xong"
                                + (khoa.isEmpty ? "." : " — trả về: \(khoa)."))
            if let man = manCua[id],
               let tien = EideManHinhDS.tatCa.first(where: { man.hasPrefix($0.tien) })?.tien {
                moMan(tien, boiTacTu: true)
            }
        } catch let e as EideKetQua.Loi {
            khung.dock.themLuot(.cho, "\(e)")
        } catch {
            khung.dock.themLuot(.loi, "\(error)")
        }
        await _lamMoi()
    }

    private func _dungKhan() async {
        guard let d = daemon else { return }
        // `stop` là phương thức RIÊNG của daemon, không phải `caps.invoke`: nó phải chạy được
        // NGAY CẢ khi hàng đợi đang kẹt và mọi lời gọi năng lực đều bị chặn.
        _ = try? await d.goi("stop")
        khung.dock.themLuot(.cho, "Đã dừng khẩn — mọi việc đang chờ bị huỷ.")
        await _lamMoi()
    }

    /// Đọc lại trạng thái: mức tự chủ, hàng đợi, mục hoàn tác.
    /// Gợi ý cho ô lệnh, suy từ HIỆN VẬT THẬT của dự án.
    ///
    /// Thứ tự ưu tiên là thứ tự việc thật sự chặn nhau: chưa có yêu cầu thì mô tả việc trước;
    /// có yêu cầu mà chưa đối chiếu phần cứng thì đó là bước kế; còn điểm cần làm rõ thì nhắc
    /// người trả lời, vì tác tử đang chờ đúng chỗ ấy.
    ///
    /// Trả `nil` khi không biết gợi gì — và khi ấy câu chép sẵn nhận lại quyền. Bịa một gợi ý
    /// cho một trạng thái mình không hiểu là cách nhanh nhất làm người dùng thôi đọc ô này.
    static func goiYTuDuAn(yeuCau: [[String: Any]], lamRoMo: Int) -> String? {
        if yeuCau.isEmpty {
            return lamRoMo > 0 ? nil
                : "Mô tả việc cần làm bằng một câu tiếng Việt — tôi rút ra yêu cầu từ đó"
        }
        let chuaXet = yeuCau.filter { ($0["feasibility"] as? String) == nil }
        if let d = chuaXet.first, let ma = d["id"] as? String {
            return "Thử: đối chiếu \(ma) với phần cứng thật"
                + (chuaXet.count > 1 ? " (còn \(chuaXet.count) yêu cầu chưa đối chiếu)" : "")
        }
        if lamRoMo > 0 {
            return "Còn \(lamRoMo) điểm cần làm rõ — trả lời ở tab Làm rõ yêu cầu"
        }
        return "Thử: lập kế hoạch cho \((yeuCau.first?["id"] as? String) ?? "yêu cầu đầu tiên")"
    }

    /// Nhãn tiếng người cho loại điểm cần làm rõ — cùng bảng với màn S9, một nguồn.
    static func nhanLoaiLamRo(_ k: String) -> String { EideManLamRo.nhanLoai(k) }

    public func _lamMoi() async {
        guard let d = daemon else { return }
        if let tc = try? await d.goi("autonomy.get"), let m = tc["autonomy"] as? String {
            khung.thanhTren.datMuc(m, dung: (tc["stopped"] as? Bool) ?? false)
        }
        let cho = (try? await d.goi("queue.list"))?["items"] as? [[String: Any]] ?? []
        let ht = (try? await d.goi("undo.list"))?["items"] as? [[String: Any]] ?? []
        // ĐIỂM CẦN LÀM RÕ cũng là việc chờ người — [DEV-151].
        //
        // `queue.list` chỉ trả các mục bị CỔNG chặn. Nhưng một điểm cần làm rõ đang `open` cũng
        // đúng là "việc chờ anh", và nó không đi qua cổng nào. Đo 22/09/2026 bằng ảnh chụp cửa
        // sổ thật: tab Làm rõ yêu cầu hiện 5 dòng "CHỜ ANH" trong khi thanh trên ghi "Chờ tôi 0"
        // và cột phải ghi "Trống — không việc nào chờ anh". Hai chỗ trên CÙNG một khung hình nói
        // ngược nhau về cùng một việc, và người dùng không có cách nào biết chỗ nào đúng.
        let goiYeuCau = try? await d.goi("caps.invoke",
                                         ["id": "view.artifacts",
                                          "params": ["kind": "requirement", "limit": 200]])
        let goiLamRo = try? await d.goi("caps.invoke",
                                        ["id": "view.artifacts",
                                         "params": ["kind": "clarification", "limit": 200]])
        let ketLamRo = goiLamRo?["result"] as? [String: Any]
        let lamRo = (ketLamRo?["items"] as? [[String: Any]]) ?? []
        let yeuCau = ((goiYeuCau?["result"] as? [String: Any])?["items"]
                      as? [[String: Any]]) ?? []
        let lamRoMo = lamRo.filter { (($0["status"] as? String) ?? "open") == "open" }
        khung.thanhTren.datDem(cho: cho.count + lamRoMo.count, hoanTac: ht.count)
        khung.dock.datGoiYDuAn(Self.goiYTuDuAn(yeuCau: yeuCau, lamRoMo: lamRoMo.count))
        khung.cotPhai.onMoLamRo = { [weak self] in
            _ = self?.moMan(EideManLamRo.tien, boiTacTu: false)
        }
        var mucCho: [EideCotPhai.MucCho] = cho.map { m in
            let qd = (m["decision"] as? [String: Any]) ?? [:]
            return EideCotPhai.MucCho(ma: (m["run_id"] as? String) ?? "?",
                                      tieuDe: (m["cap"] as? String) ?? "?",
                                      ly: (qd["reason"] as? String) ?? "")
        }
        mucCho += lamRoMo.map { m in
            EideCotPhai.MucCho(ma: (m["id"] as? String) ?? "?",
                               tieuDe: "Làm rõ yêu cầu — "
                                   + Self.nhanLoaiLamRo((m["kind"] as? String) ?? ""),
                               ly: (m["text"] as? String) ?? "",
                               traLoiChu: true)
        }
        khung.cotPhai.datCho(mucCho)
        _hienCongChan(cho)
        // Sổ cái trả theo thứ tự GHI (cũ trước). Cột phải chỉ hiện 8 thẻ, nên phải đảo: việc
        // người muốn hoàn tác gần như luôn là việc vừa xảy ra.
        khung.cotPhai.datHoanTac(ht.reversed().map {
            // `cap` vắng mặt ở các mục do CLI hay phiên trước đăng ký; `kind` thì luôn có. Hiện
            // "?" cho một việc đã làm thật là cách nhanh nhất khiến người không dám bấm hoàn tác.
            (ma: $0["undo_ref"] as? String ?? "?",
             nhan: ($0["cap"] as? String) ?? ($0["kind"] as? String) ?? "việc chưa rõ tên",
             han: Self.conLai($0["deadline"] as? String, cua: $0["window"] as? String))
        })
        // Huy hiệu ở cột trái phái sinh từ CÙNG danh sách — một nguồn, hai chỗ chiếu (B7).
        var theoMan: [String: Int] = [:]
        for m in cho {
            guard let cap = m["cap"] as? String, let man = manCua[cap],
                  let tien = EideManHinhDS.tatCa.first(where: { man.hasPrefix($0.tien) })?.tien
            else { continue }
            theoMan[tien, default: 0] += 1
        }
        choTheoMan = theoMan
        _veBadge()
        _hoiPEdit(cho)

        // §2D.4 — pha hiện tại của dự án, đọc từ CÙNG nguồn màn S3 dùng (`view.timeline` → lời
        // gọi gần nhất có trong bản đồ BPD). Hai chỗ đoán pha bằng hai cách là hai chỗ có thể nói
        // hai câu khác nhau về cùng một dự án.
        //
        // Chỉ đọc lại khi sổ cái ĐÃ NHÍCH. `_lamMoi()` chạy sau mỗi lần duyệt cổng, mỗi lần hoàn
        // tác và mỗi lần một lượt chạy đổi trạng thái; `view.timeline` trên sổ cái 9 128 bản ghi
        // đo được 0,47 s (18/09), nên đọc vô điều kiện là dán nửa giây vào mọi thao tác ấy để
        // tính lại một con số không thể đổi khi không có bản ghi mới.
        if seqNghe != seqPha {
            seqPha = seqNghe
            if let sk = (try? await d.goi("caps.invoke",
                                          ["id": "view.timeline", "params": ["limit": 200]])),
               let ds = ((sk["result"] as? [String: Any])?["events"]) as? [[String: Any]] {
                khung.dock.datPha(EideManLuong.demTheoPha(ds).hienTai)
            }
        }
        khung.dock.dangChay = theRun.values.contains { $0.trangThai == .chay }
    }

    /// `datetime.isoformat()` của Python ghi cả phần thập phân của giây (`…:45.123456+00:00`),
    /// còn `ISO8601DateFormatter` mặc định TỪ CHỐI dạng ấy và trả `nil`. Đo 18/09/2026: mọi mục
    /// hoàn tác có hạn thật đều hiện "hạn không rõ" — một dòng vô hại trông như dữ liệu thiếu,
    /// trong khi thứ thiếu là một cờ của bộ phân tích. Thử cả hai dạng, theo thứ tự hay gặp.
    private static func _ngay(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// "còn 43 phút" — bản demo hiện quãng CÒN LẠI chứ không hiện mốc ISO, và đúng: cửa sổ
    /// hoàn tác là một cái đồng hồ đếm ngược, người cần biết mình còn bao lâu chứ không cần biết
    /// nó hết vào lúc mấy giờ.
    ///
    /// Cửa sổ `session` KHÔNG có mốc hạn: nó hết khi người mở một phiên mới. Nói "hạn không rõ"
    /// cho loại này là sai sự thật — hạn của nó rất rõ, chỉ là không phải một cái đồng hồ.
    public static func conLai(_ han: String?, cua: String?) -> String {
        if han == nil, cua == "session" { return "đến khi mở phiên mới" }
        guard let han, let d = _ngay(han) else { return "hạn không rõ" }
        let giay = d.timeIntervalSinceNow
        if giay <= 0 { return "đã hết hạn" }
        if giay < 90 { return "còn \(Int(giay)) giây" }
        // Phút LÀM TRÒN, giờ CẮT XUỐNG. Cắt xuống ở phút thì một cửa sổ 60 phút vừa mở đã hiện
        // "còn 59 phút" — trông như đồng hồ chạy sai. Làm tròn ở giờ thì 90 phút thành "2 giờ",
        // hứa nhiều hơn thực; ở quãng dài, nói ít hơn là hướng sai an toàn.
        if giay < 5400 { return "còn \(Int((giay / 60).rounded())) phút" }
        return "còn \(Int(giay / 3600)) giờ"
    }

    // MARK: - nhịp tim (B6)

    /// Đập một nhịp mỗi giây. Kênh `event.*` đi CHUNG ống với câu trả lời và chỉ được đọc trong
    /// lúc một lời gọi đang chạy — nên khi người dùng ngồi yên, giao diện điếc hoàn toàn. Nhịp
    /// tim vừa bơm ống vừa cho phép phát hiện mất daemon.
    private func _batNhipTim() {
        nhipTim?.invalidate()
        nhipTim = Timer.scheduledTimer(withTimeInterval: Self.NHIP_TIM, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, let d = self.daemon else { return }
                if (try? await d.goi("plane.hello")) != nil { self.lucCuoiNghe = Date() }
                let tre = Date().timeIntervalSince(self.lucCuoiNghe)
                self.khung.datDuLieuCu(tre > Self.HAN_CU, tre: tre)
            }
        }
    }
}
