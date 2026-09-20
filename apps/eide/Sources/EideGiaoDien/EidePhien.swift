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
            await _lamMoi()
            _batNhipTim()
        } catch {
            khung.dock.themLuot(.loi, "\(error)")
        }
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
            let cach = e.maEide == "E6003" ? " → chạy `eide migrate` trong thư mục dự án."
                     : (e.maEide == "E6000"
                        ? " → store bị ghi ngoài EIDE; dựng lại chỉ mục trước khi làm tiếp." : "")
            khung.dock.themLuot(.loi, "Mở `\(ten)` không xong: \(e)\(cach)")
        }
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
        khung.thanhTren.onDungKhan = { [weak self] in
            Task { await self?._dungKhan() }
        }
        khung.cotPhai.onDuyet = { [weak self] ma, thuan in
            Task { await self?._quyet(ma, thuan) }
        }
        khung.cotPhai.onHoanTac = { [weak self] ma in
            Task { await self?._hoanTac(ma) }
        }
        // Nối ở ĐÂY chứ không trong `khoiDong()`: một nút chỉ sống khi một hàm khác được gọi
        // là một nút chết trong mọi đường chạy quên gọi hàm ấy — và `--chup` là một đường như thế.
        khung.manChao.onTao = { [weak self] van in
            Task { await self?.taoDuAn(van) }
        }
        khung.cotPhai.onChonRun = { [weak self] _ in
            self?.moMan("S2", boiTacTu: false)
        }
    }

    /// Mở một màn. `boiTacTu` quyết định có nhấp nháy hay không (§2B.5).
    public func moMan(_ tien: String, boiTacTu: Bool) {
        // Tiền tố lạ thì NÓI RA. Trước phép kiểm này, `moMan("S3")` chạy trót lọt: cột trái
        // không chọn gì, tab mang nhãn "S3", vùng làm việc ghi nhận một màn không tồn tại — và
        // một bài tự kiểm khẳng định cả ba thứ ấy vẫn ĐẠT.
        guard EideManHinhDS.man(tien) != nil else {
            khung.dock.themLuot(.loi, "Không có màn nào mang tiền tố `\(tien)` trong danh mục 25 màn.")
            return
        }
        khung.cotTrai.chon(tien, nhapNhay: boiTacTu)
        khung.thanhTab.mo(tien)
        // Người MỞ màn ra là đã xem — badge về 0 bất kể daemon còn sống hay không. Đặt sau
        // `guard let d = daemon` (chỗ tự nhiên hơn) thì mất daemon xong badge đứng mãi, và một
        // badge không bao giờ tắt là một badge người ta thôi nhìn.
        daXem(tien)
        khung.vungLamViec.moMan(tien, nangLucDs: _nangLucCua(tien))

        if let tao = Self.MAN[tien] {
            let man = tao()
            khung.vungLamViec.datMan(man)
            guard let d = daemon else {
                return khung.vungLamViec.khiRong(
                    vi: "chưa mở dự án nào nên không có daemon để hỏi",
                    buocKe: "tạo hoặc mở một dự án")
            }
            Task { [weak self] in
                await man.nap { ten, tham in
                    _ = self   // giữ phiên sống đúng bằng thời gian màn còn nạp
                    return try await d.goi(ten, tham)
                }
                // Mốc nước §7.2: màn này đang hiện trạng thái tính tới seq nào.
                man.seqCuoi = self?.seqNghe ?? 0
            }
            return
        }
        if let m = EideManHinhDS.man(tien), m.canBoard {
            return khung.vungLamViec.khiRong(
                vi: "chưa có bo mạch cắm vào máy",
                buocKe: "cắm board và mạch nạp, rồi mở lại màn này")
        }
        khung.vungLamViec.khiRong(vi: "màn này chưa nối dữ liệu trong bản dựng hiện tại",
                                  buocKe: "đang làm — xem mục 8 của UXC-31")
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
    ]


    // MARK: - đồng bộ sự kiện (UXC-31 §7)

    /// `seq` sổ cái nghe được gần nhất. 0 = chưa nghe gì.
    private var seqNghe = 0

    /// Màn ĐANG ĐÓNG có sự kiện chưa xem — §7.3 ("chỉ tăng badge nhóm").
    private var moiTheoMan: [String: Int] = [:]

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
    private func _theoSeq(_ p: [String: Any]) {
        guard let seq = p["seq"] as? Int, seq > 0 else { return }
        defer { seqNghe = max(seqNghe, seq) }
        // Bản ghi ĐẦU TIÊN nghe được không nói lên điều gì: daemon có thể đã chạy từ trước.
        guard seqNghe > 0, seq > seqNghe + 1 else { return }
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
        guard p["cap"] != nil else { return true }
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
        for tien in can where tien != dangMo {
            moiTheoMan[tien, default: 0] += 1
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
    private func _henNapLai(_ man: EideManCoSo, _ tien: String) {
        guard let d = daemon, !choNapLai.contains(tien) else { return }
        choNapLai.insert(tien)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.GOP_NAP * 1_000_000_000))
            guard let self else { return }
            choNapLai.remove(tien)
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
        for (tien, n) in moiTheoMan { g[tien, default: 0] += n }
        khung.cotTrai.choTheoMan = g
    }

    /// Người mở một màn → phần "chưa xem" của nó về 0.
    func daXem(_ tien: String) {
        guard moiTheoMan[tien] != nil else { return }
        moiTheoMan[tien] = nil
        _veBadge()
    }

    /// Cho bài đo đọc số sự kiện chưa xem.
    public func chuaXem(_ tien: String) -> Int { moiTheoMan[tien] ?? 0 }

    /// `seq` nghe được gần nhất — cho bài đo.
    public var seqDangNghe: Int { seqNghe }

    /// Người bấm "Tải lại" trên dải Dữ liệu cũ — §7.2.
    @objc func _taiLai() {
        khung.datDuLieuCu(false, tre: 0)
        guard let tien = khung.vungLamViec.dangMo else { return }
        moMan(tien, boiTacTu: false)
    }

    // MARK: - lệnh và sự kiện

    private func _gui(_ van: String) async {
        guard let d = daemon else {
            return khung.dock.themLuot(.cho, "Chưa mở dự án nào — tạo hoặc mở một dự án trước.")
        }
        do {
            let r = try await d.goi("chat.send", ["text": van])
            if let rid = r["run_id"] as? String {
                khung.dock.themLuot(.tacTu, "Đang chạy (run \(rid.prefix(10))).")
            }
            // Chuỗi dừng chờ người thì NÓI RA nó chờ gì — không để nó đứng im mãi.
            for n in (r["cho_nguoi"] as? [[String: Any]] ?? []) {
                let thieu = (n["thieu"] as? [String] ?? []).joined(separator: ", ")
                khung.dock.themLuot(.cho, "Dừng ở `\(n["cap"] as? String ?? "?")` — "
                                    + "cần anh cho biết: \(thieu).")
            }
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
        moMan(tien, boiTacTu: true)
        khung.dock.themLuot(.heThong, "→ mở màn \(EideManHinhDS.nhan(tien)) "
                            + "(tác tử đang chạy `\(cap)`)")
    }

    /// Người duyệt hoặc từ chối một mục chờ.
    ///
    /// Không đoán kết quả: chỉ khi daemon trả lời xong mới đọc lại hàng đợi. Cột phải là bản
    /// chiếu (B7) — nếu nó tự xoá thẻ trước, một lần từ chối bị chính sách chặn sẽ biến mất khỏi
    /// màn hình mà việc vẫn còn nằm trong hàng đợi.
    private func _quyet(_ ma: String, _ thuan: Bool) async {
        guard let d = daemon else { return }
        do {
            let r = try await d.goi("gate.decide",
                                    ["gate_id": ma, "decision": thuan ? "approve" : "reject"])
            let tt = r["status"] as? String ?? "?"
            khung.dock.themLuot(thuan ? .heThong : .cho,
                "\(thuan ? "Đã duyệt" : "Đã từ chối") `\(r["cap"] as? String ?? ma)` — \(tt).")
        } catch {
            khung.dock.themLuot(.loi, "\(error)")
        }
        await _lamMoi()
    }

    private func _hoanTac(_ ma: String) async {
        guard let d = daemon else { return }
        do {
            _ = try await d.goi("undo.apply", ["undo_ref": ma])
            khung.dock.themLuot(.heThong, "Đã hoàn tác `\(ma.prefix(12))`.")
        } catch {
            khung.dock.themLuot(.loi, "Không hoàn tác được: \(error)")
        }
        await _lamMoi()
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
        guard loai.hasPrefix("run.") || p["node_id"] != nil else { return }
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
        the.nhan(p)
        if the.trangThai == .chan || the.trangThai == .xong || the.trangThai == .huy {
            Task { await _lamMoi() }
        }
    }

    /// Gọi một năng lực từ bảng lệnh.
    ///
    /// KHÔNG đoán tham số. Năng lực nào cần tham số thì lời gọi dừng ở cổng hoặc trả E1000, và
    /// câu trả lời ấy được nói nguyên văn ra vùng trao đổi — tự điền một giá trị "hợp lý" cho
    /// một năng lực có thể ghi tệp hoặc nạp firmware là cách nhanh nhất để mất lòng tin.
    public func goiNangLuc(_ id: String) async {
        guard let d = daemon else {
            return khung.dock.themLuot(.cho, "Chưa mở dự án nào — tạo hoặc mở một dự án trước.")
        }
        khung.dock.themLuot(.nguoi, "/\(id)")
        do {
            let r = try EideKetQua.boc(
                try await d.goi("caps.invoke", ["id": id, "params": [:]]), id)
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
    public func _lamMoi() async {
        guard let d = daemon else { return }
        if let tc = try? await d.goi("autonomy.get"), let m = tc["autonomy"] as? String {
            khung.thanhTren.datMuc(m, dung: (tc["stopped"] as? Bool) ?? false)
        }
        let cho = (try? await d.goi("queue.list"))?["items"] as? [[String: Any]] ?? []
        let ht = (try? await d.goi("undo.list"))?["items"] as? [[String: Any]] ?? []
        khung.thanhTren.datDem(cho: cho.count, hoanTac: ht.count)
        khung.cotPhai.datCho(cho.map {
            (ma: $0["run_id"] as? String ?? "?",
             tieuDe: $0["cap"] as? String ?? "?",
             ly: (($0["decision"] as? [String: Any])?["reason"] as? String) ?? "")
        })
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
