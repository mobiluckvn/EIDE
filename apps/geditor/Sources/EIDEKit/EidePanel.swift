import AppKit

/// Panel EIDE trong GEditor — WI-021.
///
/// Spec: UXD-13 U1 (lệnh là giao diện chính, ChatPanel là màn hình mặc định), U2 (làm rồi báo
/// cáo, nhìn thấy được — thanh tự chủ luôn hiện, hàng đợi tách "chờ tôi" và "đã làm — hoàn tác
/// được"), U5 (mọi nút là một năng lực), U6 (dừng khẩn ở mọi nơi, ⌘⇧.), U7 (token PTIT),
/// U8 (tiếng Việt trước), U9 (ba trạng thái rỗng/lỗi/chờ), U10 (tương phản, bàn phím);
/// GPI-23 §1 (client thuần); DEVIATIONS DEV-004 (panel trong app, không qua khung plugin).
///
/// ## Vì sao ba vùng chứ không phải ba panel
///
/// U2 nói thanh trạng thái tự chủ "LUÔN hiện" và hàng đợi tách hai danh sách. Nếu tách thành
/// ba panel bật/tắt riêng thì người dùng có thể tắt đúng cái đang nói "máy vừa tự làm 3 việc"
/// — và lời hứa "làm rồi báo cáo, NHÌN THẤY ĐƯỢC" thành tùy chọn. Nên một panel, ba vùng cố
/// định: thanh tự chủ trên cùng, hội thoại giữa, hàng đợi dưới.
public final class EidePanel: NSView {

    // NFR-USE-03 của GEditor: đặt tên cho NHÓM, nếu không VoiceOver đọc ra một danh sách trôi nổi.
    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "EIDE — trợ lý nhúng" }

    public static let height: CGFloat = 420

    private let client: EideClient
    private let thanhTuChu = AutonomyBar()
    private let hoiThoai = ChatView()

    /// Dải "Dữ liệu cũ" — B6 của UXC-31 và tiêu chí N6.
    ///
    /// Nằm trên cùng vùng làm việc, ẩn khi mọi thứ bình thường.
    private let daiCu = EideDaiCu()

    /// Mở màn hợp nhất cho một tệp bị xung đột — UXC-31 §6.3.
    ///
    /// Dùng LẠI `XungDotView` chứ không dựng một màn riêng: hai loại xung đột là cùng một câu
    /// hỏi ("chọn vế nào, ai chịu trách nhiệm"), và một màn thứ hai trông gần giống sẽ dạy người
    /// dùng rằng hai thứ ấy khác nhau — rồi họ phải học lại thao tác ở nơi thứ hai.
    public func moHopNhatTep(duong: String, cuaToi: String) {
        nguoiVuaChonMan()
        _ = _moTheoTenMan("XungDot", thamSo: "")
        guard let v = khungCua("XungDot", id: "kg.conflicts") as? XungDotView else { return }
        let ten = (duong as NSString).lastPathComponent
        v.onChon = { [weak self] cid, ben, _ in
            guard let self else { return }
            let vung = Int(cid.split(separator: "#").last.map(String.init) ?? "1") ?? 1
            let ma = String(cid.split(separator: "#").first.map(String.init) ?? cid)
            self.chay("code.merge_conflict_resolve",
                      ["conflict_id": ma,
                       "choices": [["region": vung, "side": ben.uppercased()]]],
                      khiLoi: { loi in
                          self.hoiThoai.themLuot(by: .cho, text: "chưa hợp nhất được: \(loi)")
                      }) { _ in
                self.hoiThoai.themLuot(by: .heThong, text: "đã hợp nhất `\(ten)` theo lựa chọn của anh")
                Task { await self.lamMoi() }
            }
        }
        v.capNhat(ketQua: ["conflicts": _vungXungDot(duong: duong, cuaToi: cuaToi)])
    }

    /// Dựng dữ liệu hai vế cho màn xung đột từ tệp trên đĩa và bản của người.
    ///
    /// Hỏi daemon thay vì tự hợp nhất trong giao diện: phép hợp nhất ba bên đã chạy ở phía lõi
    /// lúc `code.human_save` báo E6004, và làm lại nó ở đây nghĩa là hai bên có thể ra hai kết
    /// quả khác nhau cho cùng một tệp — đúng thứ một màn xung đột KHÔNG được phép làm.
    private func _vungXungDot(duong: String, cuaToi: String) -> [[String: Any]] {
        guard let d = _xungDotCuoi, d.duong == duong else { return [] }
        return d.vung.enumerated().compactMap { i, v -> [String: Any]? in
            guard (v["kind"] as? String) == "giao" else { return nil }
            let so = (v["region"] as? Int) ?? (i + 1)
            return [
                "id": "\(d.ma)#\(so)", "type": "code",
                "detail": "\((duong as NSString).lastPathComponent) — vùng \(so)",
                "nodes": [
                    ["id": "anh sửa", "value": v["a"] ?? "", "tier": "người",
                     "source": "bộ đệm trình soạn thảo"],
                    ["id": "bản trên đĩa", "value": v["b"] ?? "", "tier": "tác tử / ngoài EIDE",
                     "source": duong],
                ],
            ]
        }
    }

    /// Xung đột mã gần nhất daemon báo về — điền từ lỗi E6004 của `code.human_save`.
    private var _xungDotCuoi: (ma: String, duong: String, vung: [[String: Any]])?

    /// Ghi nhận xung đột vừa sinh, để `moHopNhatTep` dựng được hai vế.
    public func nhanXungDotMa(ma: String, duong: String, vung: [[String: Any]]) {
        _xungDotCuoi = (ma, duong, vung)
    }

    /// Người bấm Lưu trong trình soạn thảo → `code.human_save` (UXD-13 v2.0 §7.1, UXC-31 §5.4).
    ///
    /// `xong(nil, nil)` = lưu được; `xong(mã lỗi, thông điệp)` = không. Gọi lại trên luồng chính.
    ///
    /// Đây là chỗ nguyên tắc "một đường" của FTR-30 §5.3 được giữ cho hành vi THƯỜNG XUYÊN NHẤT
    /// của sản phẩm: một lần gõ ⌘S nay để lại một commit có tác giả máy-đọc-được, một dòng sổ
    /// cái, và một mục hoàn tác — y như mọi việc tác tử làm.
    public func luuNhuNguoi(duong: String, noiDung: String, goc: String?,
                            xong: @escaping (String?, String?) -> Void) {
        var ts: [String: Any] = ["path": duong, "content": noiDung]
        if let goc { ts["base_content"] = goc }
        Task {
            do {
                let r = try await client.goi(.capsInvoke,
                                             ["id": "code.human_save", "params": ts])
                let tt = (r["status"] as? String) ?? ""
                let loi = r["error"] as? [String: Any]
                await MainActor.run {
                    if tt == "done" {
                        self.hoiThoai.themLuot(
                            by: .heThong,
                            text: "đã lưu `\((duong as NSString).lastPathComponent)` — "
                                + "commit \(((r["result"] as? [String: Any])?["commit"] as? String ?? "").prefix(8))")
                        Task { await self.lamMoi() }
                        xong(nil, nil)
                    } else {
                        // E6004 mang theo cả hai vế — giữ lại để `moHopNhatTep` dựng màn mà
                        // không phải hỏi daemon lần nữa.
                        if let ma = loi?["conflict_id"] as? String {
                            self.nhanXungDotMa(
                                ma: ma, duong: duong,
                                vung: (loi?["vung"] as? [[String: Any]]) ?? [])
                        }
                        xong((loi?["eide_code"] as? String) ?? "E?",
                             (loi?["message"] as? String) ?? "không lưu được")
                    }
                }
            } catch {
                await MainActor.run { xong("E?", "\(error)") }
            }
        }
    }

    /// Giết daemon để đo phép phát hiện mất kết nối — chỉ dùng trong bài kiểm.
    public func gietDaemonDeTest() { Task { await client.gietDeTest() } }

    /// Dải "Dữ liệu cũ" có đang hiện không — cho bài kiểm trên cửa sổ THẬT đọc.
    public var dangBaoDuLieuCu: Bool { daiCu.dangCu }

    /// Nhịp tim tới daemon. Xem `batNhipTim()` về lý do nó tồn tại.
    private var nhipTim: Timer?
    /// Lần cuối daemon trả lời. Dùng để quyết định khi nào dữ liệu thành "cũ".
    private var lucCuoiNghe = Date()
    /// Vùng phải — giám sát và tham gia, LUÔN hiện (THIET-KE-UI sheet 1).
    ///
    /// Gom nhật ký + hàng đợi + hoàn tác vào một cột bên phải thay vì rải chúng thành một mục
    /// sidebar và một dải đáy. Người trông một tác tử tự chạy cần thấy nó TRONG LÚC làm việc
    /// khác; bản cũ bắt họ rời màn đang xem để biết tác tử đang làm gì.
    /// Ô nhập của màn đang mở — sinh từ `input_schema` của năng lực chính (THIET-KE-UI sheet 3).
    private let oNhap = EideONhap(frame: .zero)
    /// UC-B2/B3 — tác tử nói lại cách hiểu và hỏi gộp. Màn riêng, không phải thẻ trôi trong chat.
    private let lamRo = LamRoView()
    /// UC-C9 — hai fact mâu thuẫn đặt cạnh nhau; T3, người quyết.
    private let xungDot = XungDotView()
    private let vungPhai = EideVungPhai(frame: .zero)
    private var hangDoi: ReviewQueueView { vungPhai.hangDoi }
    private var nhatKy: NhatKyView { vungPhai.nhatKy }

    // Các màn chuyên đề của UXD-13 §2. Chúng chiếm chỗ hội thoại chứ không đè lên thanh tự chủ
    // hay hàng đợi: U2 nói hai thứ ấy LUÔN hiện, kể cả khi người đang đọc một màn khác — nhất
    // là lúc ấy, vì đó là lúc tác tử vẫn đang chạy sau lưng.
    private let hoChieu = PassportView()
    private let hoiDap = RagAskView()
    private let banDo = KgMapView()
    private let taiLieu = DocView()
    private let tongQuan = ProjectStatusView()
    private let nhapTaiLieu = IngestView()
    private let hoChieuMach = BoardView()
    private let yeuCau = ReqArchView()
    private let luocDo = DiagramView()
    private let keHoach = PlanDiffView()
    private let maNguon = CodeView()
    private let moPhong = SimView()
    private let doBoard = DiscoveryView()
    private let logSerial = LogAssistView()
    private let goLoi = DebugView()
    private let doSuc = BenchView()
    private let xuongCongCu = ToolForgeView()
    private let khoGoi = RegistryView()
    private let moHinh = ModelsView()
    private let moiTruong = EnvView()
    private let hanhTrinh = FlowMapView()
    private let chinhSach = ChinhSachView()
    private let thanhMan = NSStackView()
    /// Thanh tab của vùng làm việc — UXC-31 §2C.1.
    public let thanhTab = EideThanhTab()
    /// Bảng lệnh ⌘K — UXC-31 §4.
    public let bangLenh = EideBangLenh()
    /// Nền TRẮNG của vùng làm việc — `#screen` của bản demo.
    private let nenLamViec = NSView()
    /// Vạch ngang tách vùng làm việc khỏi vùng trao đổi — `border-top` của `#dock`.
    private let vachDock = NSBox()
    /// Thanh nhỏ trên vùng trao đổi: nhãn + ba nút đổi chiều cao (UXC-31 §2D.3).
    private let thanhHoiThoai = NSStackView()
    /// Năng lực đứng sau màn đang mở — hiện cạnh tên màn (UXC-31 §2C.4).
    private let nangLucMan = NSTextField(labelWithString: "")
    private let tenMan = NSTextField(labelWithString: "")

    /// Tiền tố tên màn trong `screens.json` → khung nhìn.
    ///
    /// So bằng TIỀN TỐ vì bảng UXD-13 §2 ghi tên kèm chú thích tiếng Việt trong ngoặc
    /// ("Passport (Hộ chiếu chip)"), và so bằng dấu bằng thì không bao giờ khớp.
    ///
    /// Một BẢNG chứ không phải một chuỗi `if`: với hai chục màn, mỗi chỗ cần duyệt qua tất cả
    /// (ẩn hết, tìm một cái, mở một cái) sẽ là một danh sách chép tay, và danh sách chép tay
    /// thứ tư là chỗ có người quên thêm màn mới.
    private lazy var bangMan: [(tien: String, v: KhungNhinEide)] = [
        ("Passport", hoChieu),
        ("Graph", hoiDap),
        ("Doc", taiLieu),
        ("Main", tongQuan),
        ("Ingest", nhapTaiLieu),
        ("Board", hoChieuMach),
        ("ReqArch", yeuCau),
        ("DiagramView", luocDo),
        ("PlanDiff", keHoach),
        ("Code", maNguon),
        ("Sim", moPhong),
        ("Discovery", doBoard),
        ("LogAssist", logSerial),
        ("Debug", goLoi),
        ("Bench", doSuc),
        ("ToolForge", xuongCongCu),
        ("Registry", khoGoi),
        ("Models", moHinh),
        ("Env", moiTruong),
        ("FlowMap", hanhTrinh),
        // `DiffMerge` dùng CHUNG khung nhìn với `PlanDiff`: UXD-13 v2.0 §4 tách đôi màn theo
        // hai CÂU HỎI khác nhau của người dùng (kế hoạch thuộc Thiết kế, diff và cổng thuộc Mã
        // nguồn), nhưng dữ liệu là một. Hai khung nhìn riêng sẽ là hai bản sao của cùng một
        // trạng thái, và chúng sẽ lệch nhau.
        ("DiffMerge", keHoach),
        ("ChinhSach", chinhSach),
        ("NhatKy", nhatKy),
        ("LamRo", lamRo),
        ("XungDot", xungDot),
    ]

    /// Màn 7 có HAI khung nhìn, và năng lực người gõ quyết định mở cái nào.
    ///
    /// Tên màn có hai vế trả lời hai câu hỏi khác nhau: *"cho tôi biết điều này"* (`RagAskView`)
    /// và *"cho tôi thấy tri thức đang có hình gì"* (`KgMapView`). Bảng `bangMan` map một tiền
    /// tố về một khung nhìn, nên nó không đủ — trước khi có ngoại lệ này, gõ
    /// `/view.coverage_map` cho ra màn hỏi đáp, và màn ấy kết luận "Không tìm thấy gì trong
    /// tri thức của dự án" sau khi vừa nhận cả bản đồ độ phủ.
    private static let nangLucBanDo: Set<String> = [
        "view.kg_map", "view.kg_focus", "view.conflict_board", "view.coverage_map",
        "view.impact_map", "view.timeline", "view.rag_index", "view.rag_compare",
        "view.doc_side_by_side", "view.rag_trace",
    ]

    /// Màn có HAI khung nhìn, nên phải chọn khung theo NĂNG LỰC chứ không theo tiền tố màn.
    ///
    /// Đúng một màn: màn 7 "Bản đồ & hỏi đáp" (`RagAskView` trả lời câu hỏi, `KgMapView` vẽ tri
    /// thức). Mọi màn khác có một khung nhìn, và `napMacDinh` của chúng được chọn cho đúng khung
    /// ấy — áp phép định tuyến lên chúng chỉ tạo ra chỗ để một năng lực dùng chung (như
    /// `view.timeline`) kéo màn sang khung của màn khác.
    public static let MAN_HAI_KHUNG: Set<String> = ["Graph"]

    /// Phơi ra cho test: năng lực nào được định tuyến sang `KgMapView`.
    ///
    /// Cần thiết vì đây là chỗ hai quyết định phải khớp nhau — năng lực mặc định của màn 7 và
    /// bảng định tuyến. Lệch nhau thì bản đồ rơi vào màn hỏi đáp và màn ấy kết luận "không tìm
    /// thấy gì trong tri thức của dự án" ngay sau khi vừa nhận cả đồ thị.
    public static var nangLucBanDoDeTest: Set<String> { nangLucBanDo }

    /// Tiền tố tên của mọi màn panel dựng được, phơi ra để test đối chiếu thẳng với
    /// `docs/spec/ui/screens.json`.
    ///
    /// Rộng hơn `bangMan` đúng ba mục: `Chat`, `ReviewQueue` và `Trạng thái/khung` là ba màn
    /// LUÔN HIỆN (U2), không mở bằng "/" nên không nằm trong bảng màn chuyên đề. Hai mươi cái
    /// còn lại thì có.
    ///
    /// Con số "23/23 màn" chỉ có nghĩa nếu nó được ĐO lại mỗi lần chạy test. Một dòng trong tài
    /// liệu tiến độ thì đúng đúng một ngày; một bài test đối chiếu với bảng nguồn thì đỏ ngay
    /// hôm UXD-13 thêm màn thứ 24.
    public static let tienManDaDung: [String] = [
        "Chat", "Main", "ReviewQueue", "Ingest", "Passport", "Board", "Graph", "ReqArch",
        "DiagramView", "Doc", "PlanDiff", "Code", "Sim", "Discovery", "LogAssist", "Debug",
        "ToolForge", "Bench", "Registry", "Models", "Env", "FlowMap", "Trạng thái/khung",
        "XungDot", "LamRo", "NhatKy", "DiffMerge", "ChinhSach",
    ]

    /// id năng lực → tên màn hình, lấy từ `caps.list` (daemon suy từ bảng UXD-13 §2).
    private var manHinhCua: [String: String] = [:]
    /// id năng lực → mô tả, cho bảng lệnh tìm theo mô tả (UXC-31 §4.2).
    private var motaNangLuc: [String: String] = [:]

    /// Giữ thẻ đã xong trên màn bấy nhiêu giây trước khi gỡ.
    ///
    /// 4 giây: đủ để người đang nhìn thấy nó chuyển sang "xong", ngắn hơn hẳn thời gian họ đọc
    /// xong một dòng kết quả ở Nhật ký.
    static let TRE_GO_THE: TimeInterval = 4

    /// `run_id`/`job_id` → thẻ tiến độ đang hiện. Xem `hienTienDo`.
    private var theTienDo: [String: RunProgressCard] = [:]

    public init(client: EideClient) {
        // GHIM BẢNG MÀU SÁNG cho cả panel.
        //
        // `EideToken` là bảng màu PTIT của UXD-13 U7: các hằng số `#f4f6f9`, `#1c2530`… cố định,
        // không đổi theo chế độ sáng/tối. Còn các control của AppKit — ô nhập, nút, hàng xen kẽ
        // của bảng — thì ĐỔI theo giao diện hệ thống. Trên một máy đang để chế độ tối, hai thứ
        // ấy chồng lên nhau: nền panel sáng theo token, ô nhập và hàng xen kẽ đen theo hệ thống,
        // và chữ xám trên nền đen gần như không đọc được. Đo 15/09/2026 trên màn Hộ chiếu: sáu
        // ô nhập của biểu mẫu và bốn hàng xen kẽ của bảng fact đều là những khối đen đặc.
        //
        // Ghim `.aqua` là cách ĐÚNG với tài liệu đang có: UXD-13 khai đúng MỘT bảng màu, nên
        // "chế độ tối" của EIDE là một thứ chưa tồn tại — và bịa ra một bảng màu tối ở tầng mã
        // là quyết định thương hiệu, không phải quyết định kỹ thuật. Xem DEV-114.
        self.client = client
        super.init(frame: .zero)
        appearance = NSAppearance(named: .aqua)
        // PANEL KHÔNG ĐƯỢC ĐẨY CỬA SỔ TO RA.
        //
        // Đo 16/09/2026 bằng vòng chạy qua giao diện: cửa sổ đi 720 → 836 → 1009 pt khi mở lần
        // lượt màn Hộ chiếu và hội thoại, và **không bao giờ co lại** — AppKit phóng cửa sổ để
        // thoả ràng buộc bắt buộc, rồi để nguyên. Trên máy 13 inch thì nửa dưới nằm ngoài màn
        // hình, và ô lệnh — thứ dùng nhiều nhất — nằm ở nửa ấy.
        //
        // Hạ sức kháng nén theo chiều dọc xuống thấp nói đúng điều cần: *panel co lại được*. Nội
        // dung bên trong đã có vùng cuộn riêng (bản ghi hội thoại, thẻ, hàng đợi, thân màn), nên
        // co lại nghĩa là cuộn, không phải mất chữ.
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        dungGiaoDien()
        noiHangDoi()
        noiManChuyenDe()
        hoiThoai.onGui = { [weak self] text in self?.gui(text) }
        thanhTuChu.onDungKhan = { [weak self] in self?.dungKhan() }
        thanhTuChu.onDoiMuc = { [weak self] muc in self?.doiMucTuChu(muc) }
        thanhTuChu.onChonDuAn = { [weak self] in self?.onChonDuAn?() }
        oNhap.onChay = { [weak self] cap, ts in self?.chayTuONhap(cap, ts) }
        // UC-C9: người chọn một bên của xung đột. `kg.resolve_conflict` là T2 nên nó vào hàng
        // đợi trước khi chạy — đúng thiết kế: đây là quyết định về TRI THỨC, và hợp đồng đòi
        // `actor` để sổ cái ghi được ai đã chọn.
        xungDot.onChon = { [weak self] id, ben, dk in
            var ts: [String: Any] = ["conflict_id": id, "choice": ben, "actor": "human"]
            if let dk { ts["condition"] = dk }
            self?.chayTuONhap("kg.resolve_conflict", ts)
        }
        // UC-B2: "Đúng — làm đi" chạy chuỗi tác tử vừa mô tả; "Sửa ý hiểu" nạp câu vào ô lệnh
        // mà KHÔNG gửi, để người sửa một chữ thay vì gõ lại từ đầu.
        lamRo.onDongY = { [weak self] in self?.chayTuONhap("chat.orchestrate", [:]) }
        lamRo.onSuaYHieu = { [weak self] cau in self?.hoiThoai.oLenh.dienSan(cau) }
        lamRo.onTraLoi = { [weak self] dap in
            self?.chayTuONhap("chat.clarify", ["gaps": dap.map { ["key": $0.key, "answer": $0.value] }])
        }
        oNhap.onChonTep = { [weak self] nhan in self?.chonTep(nhan) }
        oNhap.onLayGoiY = { [weak self] nguon, nhan in self?.layGoiY(nguon, nhan) }
        Task {
            await client.theoDoi { [weak self] ten, p in
                Task { @MainActor in self?.nhanSuKien(ten, p) }
            }
            await lamMoi()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("dùng init(client:)") }

    /// Nối nút của hàng đợi vào daemon — API-15 §2 `gate.decide` / `undo.apply`.
    ///
    /// Làm mới NGAY sau mỗi hành động, không đợi chu kỳ: người vừa bấm "Duyệt" cần thấy mục ấy
    /// rời danh sách để biết cú bấm đã tới nơi. Một nút bấm xong mà danh sách không đổi thì
    /// người sẽ bấm lại — và bấm lại một mục đã duyệt là cách tạo ra hai lần chạy.
    private func noiHangDoi() {
        hangDoi.onQuyetDinh = { [weak self] rid, quyet in
            guard let self else { return }
            Task {
                do {
                    let r = try await self.client.goi(.gateDecide,
                                                      ["gate_id": rid, "decision": quyet])
                    await MainActor.run { self.hienKetQua(r) }
                } catch {
                    await MainActor.run { self.hienLoi(error) }
                }
                await self.lamMoi()
            }
        }
        hangDoi.onHoanTac = { [weak self] uref in
            guard let self else { return }
            Task {
                do {
                    let r = try await self.client.goi(.undoApply, ["undo_ref": uref])
                    // `undo.apply` trả `applied: false` khi loại hoàn tác chưa hiện thực — đó
                    // KHÔNG phải lỗi giao thức, nhưng người phải đọc được lý do chứ không thấy
                    // một dòng "xong" cho một việc chưa làm.
                    let xong = (r["applied"] as? Bool) ?? false
                    await MainActor.run {
                        self.hoiThoai.themLuot(by: xong ? .tacTu : .cho,
                                               text: xong ? "đã hoàn tác \(uref)"
                                                          : (r["reason"] as? String) ?? "chưa hoàn tác được")
                    }
                } catch {
                    await MainActor.run { self.hienLoi(error) }
                }
                await self.lamMoi()
            }
        }
    }

    /// Nối ba màn chuyên đề vào daemon — mỗi nút là một năng lực (U5), không nút nào tự tính.
    ///
    /// Kết quả `view.provenance` và `view.rag_trace` đi vào HỘI THOẠI chứ không vào màn đang mở:
    /// chúng là câu trả lời cho "vì sao con số này đúng", và câu trả lời ấy cần ở lại sau khi
    /// người đóng màn. Một chuỗi truy nguồn biến mất cùng lúc với thứ nó giải thích thì người
    /// đọc không đối chiếu được.
    private func noiManChuyenDe() {
        hoChieu.onTra = { [weak self] part in
            self?.chay("passport.query", ["part": part]) { r in self?.hoChieu.capNhat(ketQua: r) }
        }
        hoChieu.onXemNguon = { [weak self] fid in
            self?.chay("view.provenance", ["fact_id": fid]) { r in
                let chuoi = (r["chain"] as? [[String: Any]]) ?? []
                self?.hoiThoai.themLuot(by: .tacTu, text: Self.docChuoiNguon(fid, chuoi))
            }
        }
        hoiDap.onHoi = { [weak self] q in
            self?.chay("view.rag_ask", ["question": q]) { r in self?.hoiDap.capNhat(ketQua: r) }
        }
        hoiDap.onXemVet = { [weak self] tid in
            self?.chay("view.rag_trace", ["trace_id": tid]) { r in
                let n = ((r["chunks"] as? [[String: Any]]) ?? []).count
                let duong = ((r["graph_path"] as? [String]) ?? []).joined(separator: " → ")
                self?.hoiThoai.themLuot(by: .tacTu,
                                        text: "Vết truy hồi \(tid): \(n) đoạn văn bản"
                                            + (duong.isEmpty ? "" : "; đường đi trong đồ thị: \(duong)"))
            }
        }
        banDo.onMoNut = { [weak self] nut in
            // VIEW-02: bản đồ lân cận từ một nút, KÈM đường đi tới nguồn — đó là câu trả lời
            // cho "vì sao tin fact này".
            self?.chay("view.kg_focus", ["node": nut],
                       khiLoi: { [weak self] in self?.banDo.chuaNap($0) }) { r in
                self?.banDo.capNhat(ketQua: r)
            }
        }
        banDo.onMoXungDot = { [weak self] cid in
            self?.hoiThoai.themLuot(
                by: .heThong,
                text: "Mâu thuẫn \(cid) — duyệt ở hàng đợi, hoặc `/kg.resolve_conflict`.")
        }

        taiLieu.onMoMuc = { [weak self] noi in
            self?.hoiThoai.themLuot(by: .heThong, text: "Mục \(noi) — mở tệp trong GEditor.")
        }

        // Màn 2 — `project.status` gộp cả `target.detect` vào một lần đọc: hai lời gọi cho một
        // khung nhìn thì có lúc chúng lệch nhau một nhịp, và người đọc thấy "đích: nucleo-f411"
        // bên cạnh một danh sách tính năng của dự án khác.
        // Không có năng lực nào nhận một mã TÍNH NĂNG làm tham số — `req.change_impact` nhận
        // `delta{req_id|fact_id}`, và tính năng thì không phải yêu cầu. Nên nút này KHÔNG gọi
        // gì cả; nó đưa mã sang ô lệnh để người chọn tiếp. Gọi bừa một năng lực gần đúng rồi
        // hiện kết quả của nó dưới tiêu đề "ảnh hưởng của F-06" là bịa ra một câu trả lời.
        tongQuan.onMoTinhNang = { [weak self] ma in
            self?.hoiThoai.themLuot(
                by: .heThong,
                text: "Tính năng \(ma). Chưa có năng lực nào tra thẳng theo mã tính năng — "
                    + "thử `/req.trace_matrix` hoặc hỏi \"tính năng \(ma) còn thiếu gì\".")
        }

        nhapTaiLieu.onTrichXuat = { [weak self] tep in
            // `ingest.classify` đã nói tệp này đi bộ trích nào; bấm vào là CHẠY bộ ấy. Panel
            // không tự chọn extractor — đó là kết luận của năng lực, không phải của giao diện.
            self?.chay("ingest.index_text", ["files": [tep]]) { r in
                self?.nhapTaiLieu.capNhat(ketQua: r)
            }
        }

        hoChieuMach.onXemChan = { [weak self] xung in
            let chan = (xung["pin"] as? String) ?? "?"
            self?.chay("board.propose_fix", ["conflict": xung]) { r in
                self?.hienJson("Đề xuất sửa \(chan)", r)
            }
        }

        luocDo.onMoDong = { [weak self] n in
            self?.hoiThoai.themLuot(by: .heThong, text: "Lỗi lược đồ ở dòng \(n).")
        }

        keHoach.onDuyet = { [weak self] gid in
            // Duyệt ở đây ĐI QUA ĐÚNG `gate.decide` như nút ở hàng đợi. Hai đường duyệt khác
            // nhau là hai chỗ phải cùng ghi sổ cái, và cái thứ hai là cái người ta quên.
            self?.chay2(.gateDecide, ["gate_id": gid, "decision": "approve"])
        }

        maNguon.onMoViPham = { [weak self] tep, dong in
            self?.hoiThoai.themLuot(
                by: .heThong,
                text: "\(tep):\(dong) — hằng số không trỏ fact nào. `/code.annotate` để tìm fact "
                    + "khớp, hoặc `/kg.request` nếu tri thức chưa có.")
        }
        // Bấm một dòng mã mang chú thích fact → mở HỘ CHIẾU của chính fact ấy.
        //
        // Đây là nửa còn lại của luận điểm "mọi hằng số truy được về một fact": lề nói dòng này
        // dựa trên `f_b1c2`, và cú bấm phải dẫn tới chỗ nói `f_b1c2` là gì, từ nguồn nào, tầng
        // mấy. Không có đường ấy thì chú thích ở lề chỉ là một mã băm.
        maNguon.onXemFact = { [weak self] fid in
            self?.chayNhuNguoiDung("view.provenance", ["fact_id": fid])
        }


        // KHÔNG gọi `board.mark_lab` từ đây. BOARD-05 đòi `no_actuator`, `current_limited` và
        // `by` — hai lời cam kết về phần cứng cộng tên người cam kết, để rồi ghi vào
        // `autonomy.yaml` và KÝ (POL-17 §3). Đánh dấu lab là mở quyền TỰ NẠP FIRMWARE; một
        // panel tự điền `no_actuator: true` thay người là tác tử tự cấp cho mình quyền ấy —
        // cùng hình dạng với `policy sign`, thứ cố ý không phải năng lực.
        doBoard.onChonBoard = { [weak self] bid in
            self?.hoiThoai.themLuot(
                by: .heThong,
                text: "Board \(bid). Muốn tự nạp firmware thì phải đánh dấu lab, và việc đó cần "
                    + "anh xác nhận hai điều về phần cứng (không cơ cấu chấp hành, có hạn dòng) "
                    + "kèm tên anh — chạy `eide` CLI, panel không tự khẳng định thay anh được.")
        }

        logSerial.onMoDong = { [weak self] n in
            self?.hoiThoai.themLuot(by: .heThong, text: "Log dòng \(n) — mở trong GEditor.")
        }

        goLoi.onChayThiNghiem = { [weak self] tn, dich in
            // DEBUG-04 nhận `experiment{cap, args, expect}` và `target` — cả hai bắt buộc. Thí
            // nghiệm có thể chạm phần cứng, nên nó đi qua cổng như mọi việc R3 khác; panel
            // không tự quyết định gì, chỉ chuyển nguyên object mà `hypothesize` đã sinh ra.
            guard !dich.isEmpty else {
                self?.hoiThoai.themLuot(
                    by: .cho,
                    text: "Thí nghiệm này chưa có đích (`target`) — cần board đang cắm.")
                return
            }
            self?.chay("debug.experiment", ["experiment": tn, "target": dich]) { r in
                self?.goLoi.capNhat(ketQua: r)
            }
        }

        moPhong.onXemKichBan = { [weak self] duong in
            self?.hoiThoai.themLuot(by: .heThong, text: "Kịch bản: \(duong)")
        }

        xuongCongCu.onChayThu = { [weak self] tid in
            // TOOL-03 chạy công cụ trong sandbox — SEC-25 §2: không mạng, chỉ thư mục cho phép.
            self?.chay("tool.test", ["tool_id": tid]) { r in
                self?.xuongCongCu.capNhat(ketQua: r)
            }
        }

        khoGoi.onNap = { [weak self] goi in
            // REGISTRY-02 nhận `id` dạng `id@ver`, không phải `package`.
            self?.chay("registry.pull", ["id": goi]) { r in
                self?.khoGoi.capNhat(ketQua: r)
            }
        }

        moiTruong.onCai = { [weak self] cc in
            // KHÔNG gọi `env.install` thẳng: cài công cụ là R2 và đi qua cổng. Hỏi cách cài
            // trước (`env.guide_install`) thì người đọc được việc sắp xảy ra rồi mới quyết.
            self?.chay("env.guide_install", ["tool": cc]) { r in
                self?.moiTruong.capNhat(ketQua: r)
            }
        }

        hanhTrinh.onMoMuc = { [weak self] gid in
            self?.chay2(.gateDecide, ["gate_id": gid, "decision": "approve"])
        }

        yeuCau.onMoYeuCau = { [weak self] ma in
            // REQ-08 nhận `delta{req_id, old, new | fact_id}` — bọc đúng một tầng, không phẳng.
            self?.chay("req.change_impact", ["delta": ["req_id": ma]]) { r in
                self?.hienJson("Ảnh hưởng của \(ma)", r)
            }
        }
    }

    /// Gọi thẳng một phương thức RPC (không qua `caps.invoke`) rồi làm mới.
    private func chay2(_ m: EideMethod, _ p: [String: Any]) {
        Task {
            do {
                let r = try await client.goi(m, p)
                await MainActor.run { self.hienKetQua(r) }
            } catch {
                await MainActor.run { self.hienLoi(error) }
            }
            await lamMoi()
        }
    }

    /// Kết quả không có màn riêng thì đọc vào hội thoại dưới dạng khóa–giá trị.
    ///
    /// Thà một đoạn thô còn hơn một khung nhìn đoán mò: `req.change_impact` trả ra thứ mà tôi
    /// chưa dựng chỗ hiện tử tế, và bịa một bố cục cho nó là cách nhanh nhất để hiện sai.
    private func hienJson(_ ten: String, _ r: [String: Any]) {
        let dong = r.keys.sorted().map { k -> String in
            let v = r[k]
            if let a = v as? [Any] { return "  \(k): \(a.count) mục" }
            return "  \(k): \(EideKnowledgeFormat.giaTri(v))"
        }
        hoiThoai.themLuot(by: .tacTu,
                          text: dong.isEmpty ? "\(ten): không có gì."
                                             : "\(ten):\n" + dong.joined(separator: "\n"))
    }

    /// Chuỗi truy nguồn thành một đoạn đọc được. Mỗi mắt xích là *tài liệu → chỗ → cách lấy*;
    /// thiếu "cách lấy" (`method`) thì người đọc không biết con số đến từ máy đọc PDF hay từ
    /// một lần đo trên board, mà hai thứ ấy sai theo hai kiểu khác hẳn nhau.
    private static func docChuoiNguon(_ fid: String, _ chuoi: [[String: Any]]) -> String {
        guard !chuoi.isEmpty else {
            return "Fact \(fid) không có chuỗi nguồn nào — đây là lỗi dữ liệu, không phải fact yếu."
        }
        let dong = chuoi.map { m -> String in
            let nguon = (m["source"] as? String) ?? "?"
            let noi = (m["locator"] as? String).map { " \($0)" } ?? ""
            let cach = (m["method"] as? String).map { " [\($0)]" } ?? ""
            let xn = (m["confirmed_by"] as? String).map { " ✓\($0)" } ?? ""
            return "  • \(nguon)\(noi)\(cach)\(xn)"
        }
        return "Nguồn của \(fid):\n" + dong.joined(separator: "\n")
    }

    /// Gọi một năng lực rồi đưa `result` cho khung nhìn. Lỗi đi vào hội thoại — một màn chuyên
    /// đề im lặng khi gọi hỏng là màn người dùng bấm lại lần thứ ba.
    private func chay(_ id: String, _ params: [String: Any],
                      khiLoi: ((String) -> Void)? = nil,
                      _ xong: @escaping ([String: Any]) -> Void) {
        Task {
            do {
                var r = try await client.goi(.capsInvoke, ["id": id, "params": params])
                // VIỆC NẶNG trả `job_id` và `status: running` NGAY — API-15 §2. Trước
                // 15/09/2026 mọi trạng thái khác `done` đều rơi vào nhánh lỗi, nên chạy
                // `sim.run` cho ra câu *"chưa chạy được (trạng thái running)"*: một câu SAI,
                // phát ra đúng lúc việc đang chạy. Người dùng đọc nó rồi bấm lại, và lần bấm
                // thứ hai khởi động một `qemu` thứ hai.
                if (r["status"] as? String) == "running",
                   let jid = (r["job_id"] as? String) ?? ((r["result"] as? [String: Any])?["job_id"] as? String) {
                    r = await self.theoDoiViec(jid, id: id)
                }
                await MainActor.run {
                    if (r["status"] as? String) == "done" {
                        xong((r["result"] as? [String: Any]) ?? [:])
                    } else if let kl = khiLoi {
                        kl(Self.docLoi(r))
                    } else {
                        self.hienKetQua(r)
                    }
                }
            } catch {
                await MainActor.run {
                    if let kl = khiLoi { kl("\(error)") } else { self.hienLoi(error) }
                }
            }
            await lamMoi()
        }
    }

    /// Hỏi `job.status` tới khi việc nặng xong, rồi trả về một kết quả dạng CapabilityRun.
    ///
    /// ## Vì sao hỏi vòng chứ không chờ sự kiện
    ///
    /// `event.job.progress` có trong API-15 và panel đã hiện thẻ tiến độ từ nó. Nhưng sự kiện
    /// chỉ nói *đang tới đâu*; thứ màn cần là **kết quả**, và kết quả nằm trong `job.status`.
    /// Chờ một sự kiện "xong" rồi mới hỏi thì thêm một chỗ có thể lỡ: sự kiện phát trong lúc ta
    /// chưa kịp đăng ký là một màn chờ mãi mãi.
    ///
    /// Nhịp hỏi giãn dần: 0,3 s cho vài lượt đầu (việc nhẹ xong ngay thì không phải chờ nguyên
    /// một giây), rồi giãn tới 2 s. Đo 15/09: `sim.run` trên `qemu-system-avr` mất 25 giây, nên
    /// hỏi 0,3 s suốt 25 giây là 83 lượt gọi không cần thiết trên một ống stdio tuần tự.
    ///
    /// Trần `TRAN_CHO` có mặt vì một việc treo là chuyện có thật (một `qemu` không thoát), và
    /// một màn quay mãi không nói gì tệ hơn một màn nói "quá lâu, đây là cách xem tiếp".
    private func theoDoiViec(_ jid: String, id: String) async -> [String: Any] {
        let batDau = Date()
        var nhip: UInt64 = 300_000_000
        while Date().timeIntervalSince(batDau) < Self.TRAN_CHO {
            try? await Task.sleep(nanoseconds: nhip)
            nhip = min(nhip + 200_000_000, 2_000_000_000)
            guard let j = try? await client.goi(.jobStatus, ["job_id": jid]) else { continue }
            switch (j["state"] as? String) ?? "" {
            case "done":
                // `job.status` trả `result` là CẢ CapabilityRun (`asdict(run)` phía daemon), tức
                // một phong bì `{status, result, error, …}` — không phải phần thân. Bọc thêm một
                // lớp nữa ở đây thì màn nhận `{status, result}` thay cho `{report: …}` và kết
                // luận *"Mô phỏng không trả về kỳ vọng nào để hiện"* sau một lượt chạy 25 giây
                // ĐẠT 6/6. Trả thẳng phong bì: nó đã đúng hình dạng mà `chay` chờ.
                if let bi = j["result"] as? [String: Any], bi["status"] != nil { return bi }
                return ["status": "done", "result": j["result"] ?? [:]]
            case "failed":
                return ["status": "failed",
                        "error": (j["result"] as? [String: Any])?["error"]
                            ?? ["message": "việc `\(id)` hỏng: "
                                + (((j["log_tail"] as? [Any])?.last).map { "\($0)" } ?? "không rõ")]]
            case "cancelled":
                return ["status": "cancelled"]
            default:
                continue
            }
        }
        return ["status": "running", "job_id": jid]
    }

    /// Chờ một việc nặng nhiều nhất bấy nhiêu giây trước khi thôi hỏi.
    ///
    /// 10 phút: `code.build` một dự án lớn và `sim.run` một kịch bản dài đều nằm dưới mốc ấy, và
    /// quá nó thì gần như chắc chắn là treo chứ không phải chậm.
    public static let TRAN_CHO: TimeInterval = 600

    /// Lỗi của một CapabilityRun thành một câu người đọc được.
    ///
    /// E2000 (`GROUNDING_FAILED`) chiếm phần lớn lỗi mà một màn vừa mở gặp phải: năng lực cần
    /// một dự án có store, và dự án vừa tạo thì chưa có. Đó KHÔNG phải hỏng — đó là thứ tự
    /// công việc. Hiện nó dưới dạng lỗi đỏ là dạy người dùng rằng phần mềm này hay lỗi.
    static func docLoi(_ r: [String: Any]) -> String {
        guard let e = r["error"] as? [String: Any] else {
            // Mỗi trạng thái nói một việc KHÁC NHAU cho người dùng, nên đừng gộp chúng vào một
            // câu "chưa chạy được" — câu ấy đúng với `rejected` và sai với ba cái còn lại.
            switch (r["status"] as? String) ?? "?" {
            case "pending":
                return "Đang chờ anh duyệt ở hàng đợi bên phải — năng lực này cần người đồng ý "
                     + "trước khi chạy."
            case "running":
                return "Vẫn đang chạy sau \(Int(TRAN_CHO)) giây. Việc chạy tiếp ở nền; xem tiến "
                     + "độ ở thẻ bên phải, hoặc bấm Huỷ ở đó."
            case "cancelled":
                return "Đã huỷ theo yêu cầu. Kết quả bị bỏ — hợp đồng job.cancel nói rõ việc vẫn "
                     + "chạy hết nhưng kết quả không dùng."
            case "rejected":
                return "Chính sách TỪ CHỐI năng lực này. Xem màn Hành trình & cổng để biết quy "
                     + "tắc nào chặn."
            case let s:
                return "chưa chạy được (trạng thái \(s))."
            }
        }
        let ma = (e["eide_code"] as? String) ?? ""
        let tin = (e["message"] as? String) ?? ""
        if ma == "E2000" {
            let thieu = ((e["missing"] as? [String]) ?? []).joined(separator: ", ")
            return tin + (thieu.isEmpty ? "" : " (thiếu: \(thieu))")
                 + " — nạp tài liệu hoặc dựng tri thức trước rồi mở lại màn này."
        }
        return ma.isEmpty ? tin : "\(ma): \(tin)"
    }

    private func khungCua(_ man: String, id: String = "") -> KhungNhinEide? {
        if Self.nangLucBanDo.contains(id) { return banDo }
        return bangMan.first { man.hasPrefix($0.tien) }?.v
    }

    /// Mở một màn chuyên đề: nó chiếm chỗ hội thoại, thanh tự chủ và hàng đợi ở nguyên.
    ///
    /// **Màn mở ra phải nói đúng thứ nó biết.** Trước khi có `_napLanDau`, gõ `/project.status`
    /// cho ra màn Tổng quan hiện *"Chưa mở dự án nào — gõ tạo dự án…"* trong khi dự án đang mở.
    /// Câu ấy không thiếu, nó SAI: một khẳng định về trạng thái hệ thống, phát ra từ một khung
    /// nhìn chưa hỏi hệ thống câu nào.
    private func hienKhung(_ v: KhungNhinEide, ten: String, id: String, thamSo: String) {
        for k in bangMan { k.v.isHidden = (k.v !== v) }
        banDo.isHidden = (banDo !== v)
        manNgoai?.isHidden = true
        // Ô LỆNH Ở LẠI. Hội thoại vào chế độ gọn (giấu bản ghi, giữ thẻ và ô gõ) thay vì ẩn
        // hẳn — xem `ChatView.gon`. Ẩn hẳn nghĩa là muốn nói một câu thì phải bỏ màn đang xem.
        hoiThoai.isHidden = false
        hoiThoai.gon = false
        thanhMan.isHidden = false
        tenMan.stringValue = ten
        nangLucMan.stringValue = _nangLucCuaMan(ten)
        thanhTab.mo(tien: _tienCuaMan(ten), nhan: Self.nhanMan(_tienCuaMan(ten)))
        if !thamSo.isEmpty {
            // Điền sẵn ô nhập của màn, KHÔNG tự bấm Enter: người gõ "/passport.query stm32"
            // có thể muốn sửa lại trước khi tra, và một màn tự chạy ngay lúc mở là một màn
            // người dùng không kiểm soát được.
            (v as? PassportView)?.dienSan(thamSo)
            (v as? RagAskView)?.dienSan(thamSo)
        }
        v.chuaNap("Đang hỏi `\(id)`…")
        _napLanDau(v, id: id, tenMan: ten, thamSo: thamSo)
    }

    /// `/FlowMap`, `/Models` — mở màn bằng chính TÊN của nó.
    ///
    /// Ba màn trong bảng UXD-13 §2 không có năng lực nào trỏ tới, nên `/ns.name` không với tới
    /// được (đo 13/09, xem DEV-094):
    ///
    /// - **FlowMap** khai `policy.decide` (sửa 17/09/2026 — trước đó khai `[]`, trong khi
    ///   `napMacDinh` vẫn nạp đúng năng lực ấy: bảng và mã nói ngược nhau). Vẫn không với tới
    ///   được bằng `/ns.name` vì màn 1 đã nhận cả `policy.*` và bảng lấy màn ĐẦU TIÊN.
    /// - **Models** khai `policy` và `gateway` — hai chuỗi không khớp quy ước nào của bảng
    ///   (`ns.*` hoặc `ns.name` đầy đủ), nên khớp được 0 năng lực.
    /// - **Trạng thái/khung** khai `policy.set_autonomy`, nhưng năng lực ấy đã bị màn 1 nhận
    ///   trước qua mẫu `policy.*`, và bảng lấy màn ĐẦU TIÊN.
    ///
    /// U1 nói "mọi màn hình khác mở được từ lệnh" — không nói phải qua một năng lực. Không có
    /// lối này thì `ModelsView` và `FlowMapView` là mã chết: dựng xong, có test, và không cách
    /// nào mở ra.
    /// Mở một màn theo TÊN — lối vào cho sidebar của cửa sổ EIDE.
    @discardableResult
    public func moMan(_ tien: String, thamSo: String = "") -> Bool {
        // Người tự chọn: giữ màn này, đừng để tác tử kéo đi ngay — xem `_theoTacTu`.
        nguoiVuaChonMan()
        return _moTheoTenMan(tien, thamSo: thamSo)
    }

    /// Đóng màn chuyên đề, quay về hội thoại.
    public func dongManChuyenDe() { dongMan() }

    /// Kiểm kê thân màn đang mở: bao nhiêu dòng, những khối gì, có chữ nào không.
    ///
    /// Có mặt cho bài tự kiểm "màn nào mở ra RỖNG". Không bộ test nào khác trả lời được câu ấy:
    /// nó cần một daemon thật trên một dự án thật, và nó cần đi qua đúng đường người dùng đi.
    public func kiemKeManDangMo() -> (soDong: Int, khoi: String, coChu: Bool) {
        guard let v = (bangMan.map(\.v) + [banDo]).first(where: { !$0.isHidden }) else {
            return (0, "", false)
        }
        var bang = 0, cay = 0, ma = 0, dai = 0, chu = 0
        func quet(_ x: NSView) {
            switch x {
            case is EideBangView: bang += 1
            case is EideCayView: cay += 1
            case is EideMaView: ma += 1
            case is EideDaiTrangThai: dai += 1
            case let l as NSTextField where !l.stringValue.isEmpty: chu += 1
            default: break
            }
            for c in x.subviews { quet(c) }
        }
        quet(v)
        let khoi = [bang > 0 ? "\(bang) bảng" : "", cay > 0 ? "\(cay) cây" : "",
                    ma > 0 ? "\(ma) khối mã" : "", dai > 0 ? "\(dai) dải" : ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        // `soDong` hỏi qua GIAO THỨC, không ép kiểu về `ManHinhCoSo`: ba màn tri thức
        // (`PassportView`, `RagAskView`, `DocView`) viết trước lớp cơ sở nên không kế thừa nó, và
        // ép kiểu trả `nil` → bảng kiểm kê ghi "0 dòng" cho màn Hộ chiếu đang hiện 290 fact.
        return (v.soDong, khoi, chu > 0)
    }

    /// Tiền tố của màn đang mở, hoặc nil khi đang ở hội thoại.
    ///
    /// Dùng khi ĐỔI DỰ ÁN: panel cũ bị bỏ đi và panel mới phải mở lại đúng màn người đang xem.
    /// Người đổi dự án lúc đang xem "Hộ chiếu chip" muốn xem hộ chiếu của dự án mới, không muốn
    /// bị ném về Tổng quan rồi phải tự tìm đường quay lại.
    public var tenManDangMo: String? { _manDangHoi.isEmpty ? nil : _manDangHoi }

    /// Đóng panel và **tiến trình daemon của nó**.
    ///
    /// Mỗi panel giữ một `eide daemon` chạy nền qua stdio. Bỏ panel đi mà không đóng daemon thì
    /// tiến trình ấy sống tới khi ứng dụng thoát — và nó vẫn đang theo dõi sổ cái, vẫn đang
    /// phát sự kiện vào một ống không ai đọc. Đổi dự án vài lần là vài daemon mồ côi.
    ///
    /// Không `await`: người gọi là AppKit ở luồng chính, và một cửa sổ treo trong lúc chờ tiến
    /// trình con chết là thứ người dùng thấy ngay. `Task` tách ra, `terminate()` bên trong
    /// không cần ai đợi.
    @MainActor
    public func dong() {
        let c = client
        Task.detached { await c.dong() }
    }

    private func _moTheoTenMan(_ ten: String, thamSo: String) -> Bool {
        let t = ten.lowercased()
        guard let k = bangMan.first(where: { $0.tien.lowercased() == t }) else { return false }
        for v in bangMan { v.v.isHidden = (v.v !== k.v) }
        manNgoai?.isHidden = true
        hoiThoai.isHidden = false
        hoiThoai.gon = false
        // ẨN CẢ BẢN ĐỒ. `banDo` không nằm trong `bangMan` (nó là khung thứ hai của màn 7), nên
        // vòng lặp trên bỏ sót nó — và một khi bản đồ hiện ra, nó ĐÈ LÊN mọi màn mở sau đó.
        // Đo 16/09/2026: sau khi xem Nhật ký, cả màn "Mô hình & chi phí" lẫn "Hành trình & cổng"
        // đều hiện thân của bản đồ dưới tiêu đề của chính chúng.
        banDo.isHidden = true
        thanhMan.isHidden = false
        // Nhãn người đọc được, không phải tiền tố kỹ thuật: người bấm "Dò board" mà thấy
        // tiêu đề "Discovery" phải tự dịch trong đầu, và hai chữ ấy không phải lúc nào cũng
        // giống nhau ("LamRo" → "Làm rõ yêu cầu").
        tenMan.stringValue = EideDieuHuong.NHOM
            .flatMap(\.man).first { $0.tien == k.tien }?.nhan ?? k.tien
        // Đường vào từ CỘT ĐIỀU HƯỚNG — đường người dùng đi nhiều nhất. Bản đầu chỉ đặt dòng
        // phụ ở `hienKhung` (đường gõ `/ns.name`), nên dòng phụ tồn tại, có mã, và không bao
        // giờ hiện ra cho người bấm chuột.
        nangLucMan.stringValue = _nangLucCuaMan(k.tien)
        thanhTab.mo(tien: k.tien, nhan: Self.nhanMan(k.tien))
        k.v.chuaNap("Đang đọc trạng thái…")
        _dungONhap(choMan: k.tien, khungNhin: k.v)
        // Năng lực tự nạp TRƯỚC, rồi mới tới hai màn nạp bằng phương thức daemon.
        //
        // Thiếu nhánh này thì **mở màn nào từ sidebar cũng ra "chưa có nguồn dữ liệu"** trừ
        // `FlowMap` và `Models` — kể cả Tổng quan, Hộ chiếu, Môi trường, Nhật ký, những màn đã
        // có sẵn năng lực trong `napMacDinh`. Đo 14/09/2026 bằng cách bấm mục 22 trên sidebar
        // của bản dựng thật: màn mở ra, tiêu đề đúng, thân trống và một câu nói sai lý do.
        //
        // `napMacDinh` đã có từ 13/09 (lỗi im lặng số 21) nhưng chỉ chạy ở đường `_napLaiManDangMo`
        // — tức chỉ khi một sự kiện `knowledge.changed` tới. Mở màn bằng tay thì không ai gọi
        // nó. Hai đường vào cùng một màn, chỉ một đường nạp dữ liệu.
        if let cap = Self.napMacDinh(choMan: k.tien) {
            // Kết quả đi tới khung nhìn mà NĂNG LỰC trỏ về, không phải khung nhìn của tiền tố.
            //
            // Hai thứ ấy khác nhau ở đúng màn 7: tiền tố `Graph` trỏ về `RagAskView`, còn
            // `view.kg_map` thuộc `nangLucBanDo` nên phải vào `KgMapView`. Đổ nhầm chỗ thì màn
            // hỏi đáp nhận một bản đồ nó không đọc được và kết luận *"Không tìm thấy gì trong
            // tri thức của dự án"* — một câu SAI, phát ra ngay sau khi hệ thống vừa trả về 17
            // nút và 26 cạnh. Đo 15/09/2026, và nó đúng cùng hình dạng với lỗi im lặng 17 mà
            // ghi chú của `nangLucBanDo` đã mô tả cho đường gõ tay.
            // Định tuyến theo NĂNG LỰC chỉ áp cho màn có HAI khung nhìn.
            //
            // Bản 15/09 áp cho mọi màn, và nó sai ở đúng chỗ khó thấy: `napMacDinh("NhatKy")` là
            // `view.timeline`, mà `view.timeline` nằm trong `nangLucBanDo` — nên màn Nhật ký bị
            // thay bằng Bản đồ tri thức. Tiêu đề vẫn ghi "Nhật ký đầy đủ", thân thì hiện "Bản đồ
            // tri thức". Đo 16/09/2026 bằng một vòng chạy qua giao diện.
            //
            // Lý lẽ: `napMacDinh` được CHỌN THEO MÀN, nên theo xây dựng nó đã khớp khung nhìn của
            // màn ấy. Ngoại lệ duy nhất là màn 7, nơi có hai khung nhìn và tôi cố ý chọn năng lực
            // của khung bản đồ. Ghi ngoại lệ ấy thành dữ liệu, không thành một câu `if` ẩn.
            let v = Self.MAN_HAI_KHUNG.contains(k.tien) ? (khungCua(k.tien, id: cap) ?? k.v) : k.v
            if v !== k.v { hienKhung(v, ten: tenMan.stringValue, id: cap, thamSo: "") }
            chay(cap, [:], khiLoi: { [weak v] in v?.chuaNap($0) }) { [weak v] r in
                v?.capNhat(ketQua: r)
            }
            return true
        }
        _napManKhongNangLuc(k.tien, k.v)
        return true
    }

    /// Người bấm vào nút dự án trên thanh trên — cửa sổ mở menu chọn/tạo dự án.
    ///
    /// Panel không tự mở menu: danh sách dự án gần đây và việc khởi động lại daemon thuộc về
    /// tầng cửa sổ (một panel không tự thay được daemon của chính nó).
    public var onChonDuAn: (() -> Void)?

    /// Tạo dự án mới từ một câu tiếng Việt — `project.create` (PROJECT-01).
    ///
    /// Đây là đường vào đầu tiên của sản phẩm, và nó phải là MỘT CÂU chứ không phải một biểu
    /// mẫu: hợp đồng PROJECT-01 nhận `{text}` và tự suy ra tên, thư mục, chip nếu câu có nhắc.
    /// Bắt người dùng điền "tên dự án / đường dẫn / chip" là bắt họ quyết ba thứ trước khi biết
    /// mình muốn gì.
    public func taoDuAn(_ cau: String, _ xong: @escaping (String?, String?) -> Void) {
        chay("project.create", ["text": cau], khiLoi: { loi in xong(nil, loi) }) { r in
            xong(r["path"] as? String, nil)
        }
    }

    /// Chạy một năng lực và báo kết quả vào hội thoại — cho việc gọi từ MENU.
    ///
    /// Khác `chayTuONhap`: ở đây không có màn nào đang mở để đổ kết quả vào, và người dùng vừa
    /// bấm một mục menu nên họ đang nhìn cả cửa sổ. Hội thoại là chỗ duy nhất chắc chắn thấy.
    ///
    /// Việc R2 vào hàng đợi thì KHÔNG báo "xong": `chay` trả về qua `khiLoi` với câu của cổng,
    /// và nói "đã nhân bản" cho một việc đang chờ duyệt là nói dối về trạng thái dự án.
    @MainActor
    public func chayVaBao(_ cap: String, _ ts: [String: Any]) {
        hoiThoai.themLuot(by: .heThong, text: "Đang chạy `\(cap)`…")
        chay(cap, ts, khiLoi: { [weak self] loi in
            self?.hoiThoai.themLuot(by: .loi, text: loi)
        }) { [weak self] r in
            let tom = r.isEmpty ? "xong" : r.map { "\($0.key): \($0.value)" }
                .sorted().joined(separator: " · ")
            self?.hoiThoai.themLuot(by: .tacTu, text: "`\(cap)` \(tom)")
        }
    }

    /// Cập nhật tên dự án trên thanh trên.
    @MainActor
    public func datTenDuAn(_ ten: String?) { thanhTuChu.datDuAn(ten) }

    /// Người bấm "Chạy" trên ô nhập.
    ///
    /// Kết quả đổ về ĐÚNG màn đang mở, và lỗi hiện ngay cạnh nút chứ không trôi vào hội thoại —
    /// người vừa điền một form thì câu trả lời phải ở chỗ họ đang nhìn.
    /// Chạy một năng lực và đổ kết quả vào MÀN ĐANG MỞ — như thể người dùng vừa điền form và
    /// bấm nút.
    ///
    /// Phơi ra cho bộ chụp ảnh: vài màn (Mô phỏng, Benchmark) chỉ có gì để hiện sau khi chạy một
    /// năng lực CÓ THAM SỐ, và không có đường này thì ảnh của chúng mãi là ảnh một biểu mẫu
    /// rỗng — tức là ảnh không nói được gì về thứ ta vừa sửa.
    /// Trả `false` khi CHƯA có màn chuyên đề nào mở — bên gọi cần biết, không nên đoán.
    ///
    /// `chayTuONhap` bỏ qua trong im lặng khi không tìm thấy màn đang hiện, và điều đó đúng cho
    /// một ô nhập (ô nhập chỉ tồn tại khi có màn). Với một lời gọi bằng mã thì im lặng là bẫy:
    /// bộ chụp ảnh gọi hàm này ngay sau khi mở màn, màn chưa kịp hiện, lời gọi rơi vào hư
    /// không — và ảnh ra một màn trống mà không có gì trong log nói vì sao. Đo 15/09/2026.
    @discardableResult
    public func chayNhuNguoiDung(_ cap: String, _ ts: [String: Any]) -> Bool {
        guard bangMan.contains(where: { !$0.v.isHidden }) else { return false }
        chayTuONhap(cap, ts)
        return true
    }

    private func chayTuONhap(_ cap: String, _ ts: [String: Any]) {
        guard let k = bangMan.first(where: { !$0.v.isHidden }) else { return }
        let v = k.v
        oNhap.baoLoi("")
        v.chuaNap("Đang chạy `\(cap)`…")
        chay(cap, ts, khiLoi: { [weak self, weak v] loi in
            // Lỗi vào CẢ hai chỗ: cạnh nút để người đang điền form thấy ngay, và trong màn để
            // nó thôi hiện "Đang chạy…" mãi mãi.
            self?.oNhap.baoLoi(loi)
            v?.chuaNap(loi)
        }) { [weak v] r in
            v?.capNhat(ketQua: r)
        }
    }

    /// Gợi ý cho một ô nhập — gọi năng lực nguồn rồi rút danh sách giá trị.
    ///
    /// Mỗi nguồn trả một hình dạng khác nhau (`passport.list` → `{passports[]}` với `id`;
    /// `project.status` → `{report.features}`), nên phép rút nằm ở đây, một chỗ, thay vì bắt
    /// `EideONhap` biết về hợp đồng của từng năng lực.
    ///
    /// Lỗi thì trả rỗng, KHÔNG báo: gợi ý là tiện ích. Một hộp thoại lỗi bật lên chỉ vì chưa
    /// nạp được danh sách chip, trong lúc người dùng đang gõ, là tệ hơn hẳn việc không có gợi ý.
    private func layGoiY(_ nguon: String, _ nhan: @escaping ([String]) -> Void) {
        Task {
            guard let r = try? await client.goi(.capsInvoke, ["id": nguon, "params": [:]]),
                  (r["status"] as? String) == "done",
                  let kq = r["result"] as? [String: Any] else {
                nhan([])
                return
            }
            nhan(Self.rutGoiY(nguon, kq))
        }
    }

    /// `{kết quả năng lực}` → danh sách giá trị gợi ý. Thuần và tĩnh để test được.
    static func rutGoiY(_ nguon: String, _ kq: [String: Any]) -> [String] {
        switch nguon {
        case "passport.list":
            // `{passports[]}` — mỗi mục có `id` dạng `chip:st.stm32f411ce@1.0.0`. Người dùng gõ
            // phần PART (`st.stm32f411ce`), không gõ cả IRI lẫn phiên bản — đo 14/09: truy vấn
            // với `part: "chip:espressif.esp32c3"` trả rỗng vì tiền tố `chip:` không được bỏ.
            return ((kq["passports"] as? [Any]) ?? []).compactMap {
                guard let id = ($0 as? [String: Any])?["id"] as? String
                    ?? ($0 as? String) else { return nil }
                return id.split(separator: "@").first.map {
                    String($0).replacingOccurrences(of: "chip:", with: "")
                }
            }
        case "project.status":
            let bc = (kq["report"] as? [String: Any]) ?? kq
            return ((bc["features"] as? [Any]) ?? []).compactMap {
                ($0 as? [String: Any])?["id"] as? String ?? $0 as? String
            }
        case "env.detect":
            // ISA không nằm trong `env.detect`; nó nằm trong manifest. Trả rỗng thay vì rút bừa
            // một trường nghe giống — một gợi ý sai tệ hơn không gợi ý.
            return []
        default:
            return []
        }
    }

    /// Nút "Chọn tệp…" của ô nhập. Panel mở hộp thoại chứ không phải view — để `EideONhap` test
    /// được mà không bật một hộp thoại hệ thống giữa lượt chạy test.
    private func chonTep(_ nhan: @escaping (String) -> Void) {
        let o = NSOpenPanel()
        o.canChooseFiles = true
        o.canChooseDirectories = false
        o.allowsMultipleSelection = false
        if o.runModal() == .OK, let u = o.url { nhan(u.path) }
    }

    /// Dựng ô nhập cho màn đang mở — THIET-KE-UI sheet 3.
    ///
    /// Hỏi `caps.describe` rồi để `EideONhap` sinh form từ `input_schema`. Không viết tay form
    /// cho 21 màn: 37 tham số là 37 chỗ có thể sai, và một form viết tay sẽ trôi khỏi hợp đồng
    /// ngay lần đầu ai đó đổi tên tham số trong `cds.json`.
    ///
    /// Màn cần board thì nói rõ cần cắm gì thay vì dựng một form không chạy được — chủ sản phẩm
    /// chốt 14/09: *"vẫn hiện, nói rõ cần gì"*.
    private func _dungONhap(choMan tien: String, khungNhin v: KhungNhinEide) {
        guard let cap = Self.nangLucChinh[tien] else {
            oNhap.isHidden = true
            return
        }
        let canBoard = EideDieuHuong.NHOM.first { $0.ten == "PHẦN CỨNG" }?
            .man.contains { $0.tien == tien } ?? false
        // Ghi nhận màn đang mở TRƯỚC khi hỏi, và bỏ kết quả nếu người đã sang màn khác.
        //
        // `caps.describe` là một vòng gọi daemon, và người dùng bấm sidebar nhanh hơn thế. Không
        // có chốt này thì form nào VỀ SAU thắng, không phải màn nào ĐANG MỞ — đo 15/09 trên bản
        // dựng thật: màn "Dò board" hiện nút "Chạy bench.badge", tức form của một màn khác hẳn.
        // Người dùng bấm nút ấy là chạy một năng lực họ không chọn.
        oNhap.isHidden = true
        _manDangHoi = tien
        Task {
            let mo = try? await client.goi(.capsDescribe, ["id": cap])
            await MainActor.run {
                guard self._manDangHoi == tien else { return }
                guard let mo, !mo.isEmpty else {
                    self.oNhap.isHidden = true
                    v.chuaNap("Không đọc được hợp đồng của `\(cap)` — daemon còn chạy không?")
                    return
                }
                self.oNhap.dungTu(capId: cap, moTa: mo)
                self.oNhap.isHidden = false
                if canBoard {
                    v.chuaNap(EideDieuHuong.loiCanBoard(tien))
                }
            }
        }
    }

    /// Màn đang chờ hợp đồng — chốt chống đua cho `_dungONhap`.
    private var _manDangHoi = ""

    /// Thư mục gốc của dự án daemon đang mở.
    ///
    /// Panel không tự biết: nó chỉ cầm một `client` đã trỏ sẵn vào dự án, và `datTenDuAn` chỉ
    /// nhận TÊN để hiện lên thanh trên. Cửa sổ đặt giá trị này vào vì `code.*` trả đường dẫn
    /// TƯƠNG ĐỐI so với gốc dự án, và màn Mã nguồn cần đường đầy đủ để đọc tệp lên mà chú thích.
    public var duAnGoc: String? {
        didSet { maNguon.duAnHienTai = duAnGoc }
    }

    /// Hỏi `code.constant_guard` cho một tệp, trả về `(dòng → lý do, có CHẶN không)`.
    ///
    /// Dành cho trình soạn thảo: nó cần đúng hai thứ — dòng nào vi phạm, và cổng có chặn không —
    /// chứ không cần cả khung nhìn `CodeView`. Gọi thẳng `chay` nên KHÔNG đụng tới màn đang mở:
    /// người dùng có thể đang xem Hộ chiếu trong lúc mở một tệp mã ở tab khác.
    ///
    /// Bản vá dựng ở đây mang `mode: "replace"` với chính nội dung đang soạn thảo — tức guard
    /// chấm thứ người dùng ĐANG viết, kể cả khi chưa lưu. Đó là điểm của việc chấm sớm.
    public func chamViPham(tep: String, noiDung: String,
                           xong: @escaping ([Int: String], Bool) -> Void) {
        let va: [String: Any] = ["files": [["path": tep, "content": noiDung, "mode": "replace"]],
                                 "cites": [], "rationale": "chấm tri thức khi mở tệp"]
        chay("code.constant_guard", ["patch": va], khiLoi: { _ in
            // Lỗi thì KHÔNG gọi `xong`: gọi với danh sách rỗng sẽ xoá dấu vi phạm đang hiện và
            // nói "sạch" trong khi thật ra ta không biết gì.
        }) { r in
            let vp = (r["violations"] as? [[String: Any]]) ?? []
            var theoDong: [Int: String] = [:]
            for v in vp {
                guard let d = EideSo.nguyen(v["line"]) else { continue }
                let ly = (v["reason"] as? String) ?? ""
                let hs = (v["literal"] as? String) ?? EideKnowledgeFormat.giaTri(v["literal"])
                // Nhiều hằng số trên một dòng: nối lý do thay vì để cái sau đè cái trước.
                let moi = [hs, ly].filter { !$0.isEmpty }.joined(separator: " — ")
                theoDong[d] = theoDong[d].map { "\($0) · \(moi)" } ?? moi
            }
            xong(theoDong, (r["verdict"] as? String) == "block")
        }
    }

    /// Nói cho màn Mã nguồn biết tệp nào đang xem, rồi chạy một năng lực `code.*` trên nó.
    ///
    /// Gộp hai việc vì để rời thì có hai thứ tự đúng và một thứ tự sai — chạy trước rồi mới đặt
    /// tệp thì lượt cập nhật đầu tiên không có tệp nào để hiện.
    @discardableResult
    public func xemTepMa(_ duong: String, chay cap: String, _ ts: [String: Any]) -> Bool {
        maNguon.tepDangXem = duong
        return chayNhuNguoiDung(cap, ts)
    }

    /// Ép chiều cao hội thoại về 0 khi một màn chuyên đề đang mở.
    ///
    /// `isHidden = true` KHÔNG lấy lại chỗ: một khung nhìn ẩn vẫn tham gia Auto Layout đầy đủ.
    /// Nên hội thoại ẩn vẫn giữ sàn 150 pt CỘNG chiều cao nội dung của nó, và vì mép dưới của
    /// mọi màn chuyên đề buộc vào mép trên hội thoại, phần ấy bị lấy thẳng từ màn. Đo 16/09/2026
    /// trên màn Mô phỏng: khung mã chứa log UART bị cắt ngang ngay dòng đầu, trong khi nửa dưới
    /// cửa sổ trống trơn.

    /// Chiều cao tối thiểu của vùng trao đổi người–máy.
    public static let CAO_HOI_THOAI: CGFloat = 220

    /// Sàn chiều cao hội thoại — **bất biến**, không bao giờ về 0.
    ///
    /// Chủ sản phẩm chốt 16/09/2026: *"giao diện để người và máy cùng trao đổi là phải có và bất
    /// biến"*. Màn chuyên đề là thứ ĐẾN RỒI ĐI — tác tử làm tới phần nào thì màn ấy hiện ra —
    /// còn chỗ hai bên nói chuyện thì luôn ở đó.
    ///
    /// Bản trước ép hội thoại về 0 khi mở một màn, và đó là quyết định sai đã đi qua hai lần
    /// sửa: lần đầu giấu hẳn hội thoại, lần sau thu gọn còn ô gõ. Cả hai đều lấy chỗ của cuộc
    /// trao đổi để cho màn — trong khi màn đã có vùng cuộn riêng và không cần chỗ ấy.
    ///
    /// Ưu tiên CAO chứ không bắt buộc: trên cửa sổ rất thấp thì sàn này nhường, thay vì phóng
    /// cửa sổ to ra — lỗi đã đo được trong vòng chạy cùng ngày.
    private lazy var _sanHoiThoai: NSLayoutConstraint = {
        let c = hoiThoai.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.CAO_HOI_THOAI)
        c.priority = .defaultHigh
        return c
    }()

    /// TRẦN chiều cao hội thoại — bắt buộc.
    ///
    /// Sàn giữ cho vùng trao đổi không biến mất; trần giữ cho nó không nuốt vùng làm việc. Thiếu
    /// trần thì hội thoại cao theo nội dung: đo 16/09/2026 với ba thẻ đang chạy cộng một thông
    /// báo lỗi dài, hội thoại chiếm gần nửa cửa sổ và trình soạn thảo còn một dải BỐN DÒNG.
    ///
    /// Bắt buộc, khác sàn: một vùng trao đổi cao quá vẫn đọc được (nó cuộn), còn một vùng làm
    /// việc bị bóp còn bốn dòng thì không làm việc được.
    private lazy var _tranHoiThoai =
        hoiThoai.heightAnchor.constraint(lessThanOrEqualToConstant: Self.TRAN_HOI_THOAI)

    /// Chiều cao tối đa của vùng trao đổi. 320 pt ≈ năm lượt đối thoại cộng ô gõ.
    public static let TRAN_HOI_THOAI: CGFloat = 320

    /// Ba trạng thái chiều cao của vùng trao đổi — UXC-31 §2D.1.
    ///
    /// Sàn–trần (220…320, cao theo nội dung) giữ được hai bất biến quan trọng và thiếu đúng một
    /// thứ: người dùng KHÔNG đổi được nó. Trên màn 13 inch, soạn mã với 220 pt cố định dưới đáy
    /// là chật; mà bỏ sàn đi thì vùng trao đổi biến mất — thứ chủ sản phẩm cấm từ 16/09.
    ///
    /// Ba trạng thái thay một kích thước bằng một HÀNH VI: người kéo xuống khi cần chỗ soạn mã,
    /// kéo lên khi đang đọc một chuỗi dài, và hệ thống tự về mức chuẩn khi một Run bắt đầu — vì
    /// đúng lúc ấy có thứ mới để đọc. Không trạng thái nào bằng 0: `thuGon` vẫn để lại ô gõ.
    public enum CaoHoiThoai: CGFloat, CaseIterable {
        case thuGon = 48
        case chuan = 220
        case moRong = 320
    }

    /// Trạng thái hiện tại — cho bài kiểm đọc.
    public private(set) var caoHoiThoai: CaoHoiThoai = .chuan

    private lazy var _caoHoiThoai: NSLayoutConstraint =
        hoiThoai.heightAnchor.constraint(equalToConstant: CaoHoiThoai.chuan.rawValue)

    /// Đổi trạng thái vùng trao đổi.
    ///
    /// KHÔNG đổi khi con trỏ đang ở ô lệnh (§2D.2c): một ô nhập tụt xuống dưới tay người đang gõ
    /// là cách chắc chắn nhất để họ gõ nhầm chỗ và mất câu vừa viết.
    @MainActor
    public func datCaoHoiThoai(_ c: CaoHoiThoai, buoc: Bool = false) {
        if !buoc && _dangGoTrongONhap { return }
        caoHoiThoai = c
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15          // §2D.3: ≤ 150 ms
            ctx.allowsImplicitAnimation = true
            _caoHoiThoai.animator().constant = c.rawValue
            self.layoutSubtreeIfNeeded()
        }
    }

    /// Ba màn ấy nạp bằng PHƯƠNG THỨC RPC, không bằng `caps.invoke`.
    ///
    /// `queue.list` và `autonomy.get` là phương thức của daemon chứ không phải năng lực trong
    /// registry — `caps.describe("queue.list")` trả lỗi "năng lực không tồn tại". Nên quy tắc
    /// `tuChay` không áp dụng được ở đây, và đó là đúng: hai phương thức này chỉ đọc trạng thái
    /// daemon đang giữ sẵn, không chạy gì cả.
    private func _napManKhongNangLuc(_ tien: String, _ v: KhungNhinEide) {
        Task {
            switch tien {
            case "FlowMap":
                let doi = try? await client.goi(.queueList, [:])
                let tc = try? await client.goi(.autonomyGet, [:])
                var g: [String: Any] = doi ?? [:]
                g["autonomy"] = tc?["autonomy"]
                g["stopped"] = tc?["stopped"]
                await MainActor.run { v.capNhat(ketQua: g) }
            case "Main":
                // Màn Tổng quan gom HAI nguồn: `project.status` (năng lực) và `session.state`
                // (phương thức daemon, M2). Gộp ở đây vì chúng trả lời cùng một câu hỏi —
                // "dự án này đang ở đâu" — và bắt người dùng mở hai màn để ghép lại là bắt họ
                // làm việc của giao diện.
                let r = try? await client.goi(.capsInvoke,
                                              ["id": "project.status", "params": [:]])
                let ph = try? await client.goi(.sessionState, [:])
                var g: [String: Any] = (r?["result"] as? [String: Any]) ?? [:]
                if let ph { g["session"] = ph }
                await MainActor.run { v.capNhat(ketQua: g) }
            case "Models":
                // Màn chi phí gom HAI nguồn: sổ cái (`view.timeline` → `model.call`) và ngân
                // sách (`budget.state`). Một mình danh sách lượt gọi nói "đã tiêu vào đâu";
                // người sắp chạy một việc nặng hỏi câu khác — "tôi còn bao nhiêu".
                let ns = try? await client.goi(.budgetState, [:])
                let tl = try? await client.goi(.capsInvoke,
                                               ["id": "view.timeline", "params": [:]])
                var gm: [String: Any] = (tl?["result"] as? [String: Any]) ?? [:]
                if let ns { gm["budget"] = ns }
                await MainActor.run { v.capNhat(ketQua: gm) }
            case "__models_cu__":
                // Chi phí nằm trong `project.status`; mức tự chủ trong `autonomy.get`.
                let tc = try? await client.goi(.autonomyGet, [:])
                let r = try? await client.goi(.capsInvoke,
                                              ["id": "project.status", "params": [:]])
                var g: [String: Any] = (r?["result"] as? [String: Any]) ?? [:]
                g["autonomy"] = tc?["autonomy"]
                g["stopped"] = tc?["stopped"]
                await MainActor.run { v.capNhat(ketQua: g) }
            default:
                await MainActor.run { v.chuaNap("Màn \(tien) chưa có nguồn dữ liệu.") }
            }
        }
    }

    /// Hỏi hợp đồng TRƯỚC khi quyết định có tự chạy hay không.
    ///
    /// Ba điều kiện, và cả ba đều đọc từ `caps.describe` chứ không từ một danh sách tôi tự gõ:
    ///
    /// - **`risk == "R0"`** — lớp rủi ro của POL-17. R1 trở lên là có tác động ra ngoài.
    /// - **`undo == "none"`** — không có gì để hoàn tác nghĩa là không có gì bị thay đổi. Đây
    ///   là điều kiện bắt được `req.trace_matrix`: nó là R0, không tham số bắt buộc, nhưng
    ///   `undo: delete_created_files` — tức nó GHI TỆP. Một màn vừa mở ra mà đã ghi tệp vào dự
    ///   án của người ta là thứ không ai lường trước.
    /// - **`required` rỗng** — còn thiếu tham số thì đoán điền vào đâu là tự nghĩ ra hành vi.
    ///
    /// Không thỏa thì màn nói rõ nó đang chờ gì, thay vì khẳng định một điều chưa kiểm.
    /// Mở màn thì chạy luôn, hay chờ người?
    public enum NapLanDau: Equatable {
        case chay
        case cho(String)
    }

    /// Năng lực được phép chạy KHI MỞ MÀN — danh sách khai báo, không suy ra.
    ///
    /// ## Vì sao một danh sách, sau khi tôi vừa viết rằng danh sách gõ tay là sai
    ///
    /// Bản đầu của `tuChay` suy tính "chỉ đọc" từ ba trường hợp đồng: `risk == R0`,
    /// `undo == "none"`, `required` rỗng. Chạy thử trên registry thật thì **19 năng lực thỏa cả
    /// ba**, và trong đó có `policy.emergency_stop` — mở một màn ra là dừng khẩn cả hệ thống.
    ///
    /// Lỗ hổng nằm ở chỗ `undo: none` mang HAI nghĩa khác hẳn nhau:
    ///
    /// - *không có gì để hoàn tác vì không thay đổi gì* — `project.status`, `env.detect`;
    /// - *có thay đổi, nhưng không hoàn tác được* — `policy.emergency_stop` (T3),
    ///   `policy.learn_thresholds` (T2, `ask_when: Luôn`), `kg.build` (ghi vào store).
    ///
    /// Thêm `tier == T1` loại được hai cái đầu, nhưng `code.build` và `kg.build` vẫn lọt: cả
    /// hai là R0/T1/undo-none, và một cái chạy cmake vài chục giây còn cái kia ghi store.
    /// **CDS-12 không có trường nào nói năng lực có tác dụng phụ hay không** (xem DEV-095), nên
    /// suy tiếp là đoán — và đoán sai ở đây nghĩa là một cú gõ `/` làm dừng cả hệ thống.
    ///
    /// Tiêu chí vào danh sách là HAI: chỉ đọc, **và rẻ**. `view.rag_ask` chỉ đọc nhưng gọi mô
    /// hình — mở một màn ra mà tốn tiền là thứ người dùng không đồng ý trước.
    ///
    /// Nên: danh sách này là một quyết định THIẾT KẾ của panel, đúng như `bangMan`, và
    /// `tuChay` ở dưới vẫn chạy như một CHỐT THỨ HAI — hợp đồng vẫn có quyền phủ quyết danh
    /// sách, chỉ không còn được tin là đủ để tự mình cho phép.
    public static let napAnToan: Set<String> = [
        "project.status",       // màn 2  → `report`     — ProjectStatusView
        "passport.query",       // màn 5  → `facts`      — PassportView
        "passport.list",        // màn 5  → `passports`  — PassportView
        "view.kg_map",          // màn 7  → `graph`      — KgMapView
        "view.timeline",        // màn 7  → `events`     — KgMapView
        "view.conflict_board",  // màn 7  → `rows`       — KgMapView
        "report.progress",      // màn 10 → `md`         — DocView
        "env.detect",           // màn 21 → `env`        — EnvView
        // Thêm 15/09 cùng hai màn mới. Cả hai đã đối chiếu `output_schema` với khoá mà khung
        // nhìn thật sự đọc — đúng phép đo đã rút `napAnToan` từ 11 mục xuống 4 hồi 13/09:
        "kg.conflicts",         // Xung đột → `conflicts`, `resource_ready` — XungDotView
        // Thêm 17/09 cùng màn Chính sách tự chủ (S25). Đối chiếu như phép đo 13/09: hợp đồng
        // trả `{rules[], signed, reason}` và `ChinhSachView.capNhat` đọc đúng ba khoá ấy.
        // R0/T1, không tham số, `undo: none` — đúng hồ sơ mà danh sách này tồn tại để kể.
        "policy.rules",         // màn 27 → `rules`, `signed` — ChinhSachView
    ]

    /// Năng lực chỉ-đọc nhưng **chưa có khung nhìn nào đọc được đầu ra của chúng**.
    ///
    /// Bản đầu của `napAnToan` có 11 mục, chọn theo trực giác "màn này thì nạp năng lực kia".
    /// Đo lại bằng cách đối chiếu `output_schema` với khoá mà mã khung nhìn thật sự đọc: **chỉ
    /// 4 mục dùng được**. Bảy mục còn lại tự chạy xong rồi để khung nhìn hiện rỗng — tệ hơn là
    /// hiện SAI, vì `PassportView` nhận một danh sách hộ chiếu đầy đủ, không thấy khoá `facts`,
    /// và kết luận *"Không có fact nào cho mã này"*.
    ///
    /// Danh sách này không phải rác cần dọn: nó là **đơn đặt hàng UI còn nợ**. Mỗi dòng là một
    /// khung nhìn chưa dựng, và ngày dựng xong thì mục ấy chuyển lên `napAnToan`.
    /// Cập nhật 13/09 (đợt hai): năm mục đã chuyển lên `napAnToan` sau khi `KgMapView` ra đời
    /// và `PassportView`/`DocView` đọc thêm khoá. Hai mục còn lại KHÔNG phải nợ khung nhìn —
    /// chúng là hai năng lực **bảng UXD-13 §2 không gán màn nào**, nên không có chỗ để hiện.
    /// Đó là một khoảng trống của TÀI LIỆU, và nó nằm trong [DEV-094](DEVIATIONS.md).
    public static let noUI: [(cap: String, tra: String, canGi: String)] = [
        // `kg.conflicts` ĐÃ RA KHỎI danh sách này 15/09: nó có màn riêng ("Xung đột tri thức",
        // DEV-109). Một mục ở đây là một món nợ UI, và trả nợ thì phải gỡ tên khỏi sổ — để lại
        // thì lần rà sau người ta đi dựng một màn đã có.
        ("project.list", "projects",
         "danh sách dự án: bảng §2 không gán màn nào, và panel mở dự án qua `project.open`"),
    ]

    /// Năng lực nạp mặc định của mỗi màn, khi lệnh người gõ không tự chạy được.
    /// Năng lực nạp mặc định của mỗi màn — phải là thứ CHÍNH khung nhìn ấy đọc được.
    ///
    /// `Passport` từng nạp `passport.list`: nó trả `{passports}`, `PassportView` đọc `{facts}`,
    /// nên mở màn ra là hiện *"Không có fact nào cho mã này"* sau khi vừa nhận một danh sách
    /// hộ chiếu đầy đủ. Cùng hình dạng với lỗi #17, chỉ khác là lần này khung nhìn ĐÃ hỏi — nó
    /// chỉ không hiểu câu trả lời. `EideNapMacDinhTests` giữ điều này bằng cách đọc chính mã
    /// nguồn khung nhìn, không bằng một danh sách gõ tay.
    ///
    /// `Graph` nạp `view.kg_map` (từ 15/09/2026). Màn 7 có hai vế và vế mặc định phải là vế
    /// chạy được mà không cần gì: `view.rag_ask` đòi một mô hình lẫn một câu hỏi, còn bản đồ
    /// đọc thẳng store. Trước đó màn mở ra là một ô nhập rỗng, trong khi dự án có sẵn 17 nút và
    /// 26 cạnh không ai thấy.
    /// Năng lực CHÍNH của mỗi màn — cái mà ô nhập dựng form theo.
    ///
    /// Khác `napMacDinh`: `napMacDinh` là năng lực chạy được NGAY khi mở màn (không tham số,
    /// R0, không ghi gì). Bảng này là năng lực người dùng thật sự muốn chạy ở màn ấy, và phần
    /// lớn chúng CẦN tham số — đó chính là lý do 18/22 màn từng mở ra trống.
    ///
    /// Nguồn: THIET-KE-UI sheet 2 cột "Năng lực chính", chủ sản phẩm duyệt 14/09/2026.
    public static let nangLucChinh: [String: String] = [
        "Ingest": "ingest.classify",
        "Passport": "passport.query",
        "Board": "board.check_pins",
        "Graph": "view.rag_ask",
        "LamRo": "chat.parse_intent",
        "XungDot": "kg.conflicts",
        "ReqArch": "req.elicit",
        "DiagramView": "diagram.block",
        "PlanDiff": "plan.create",
        "DiffMerge": "code.review",
        "ChinhSach": "policy.rules",
        "Doc": "doc.generate",
        "Code": "code.build",
        "Sim": "sim.run",
        "Env": "env.check",
        "Discovery": "discover.ports",
        "Debug": "target.flash",
        "LogAssist": "debug.log_stats",
        "Bench": "bench.badge",
        "Main": "project.status",
        "NhatKy": "view.timeline",
        // `model.route` KHÔNG tồn tại — không có nhóm `model.*` trong 238 năng lực. Chi phí và
        // hồ sơ mô hình nằm ở `policy.budget`… cũng không có. Thứ gần nhất và CÓ THẬT là
        // `policy.learn_thresholds` (POLICY-06), vốn đọc `decision_log` để đề xuất ngưỡng —
        // đúng dữ liệu màn này cần. Bắt được bằng test E2E duyệt cả bảng; trước đó màn "Mô hình
        // & chi phí" mở ra sẽ báo lỗi mãi mãi vì hỏi hợp đồng của một năng lực không có.
        // UC-F7: chi phí đọc từ SỔ CÁI (`model.call`), không từ `models.yaml`.
        // `models.yaml` nói tác tử ĐƯỢC PHÉP dùng gì; sổ cái nói nó ĐÃ dùng gì.
        "Models": "view.timeline",
        "Registry": "registry.search",
        "ToolForge": "tool.need",
        "FlowMap": "policy.decide",
    ]

    /// Màn này có khung nhìn không? Điều hướng hỏi trước khi hiện một mục.
    ///
    /// Một mục điều hướng không có khung nhìn là một mục bấm vào thì không có gì hiện ra — và
    /// đó là cách DEV-094 xảy ra: hai màn nằm trong danh sách mà không ai mở tới được.
    @MainActor
    public func coManDeTest(_ tien: String) -> Bool {
        bangMan.contains { $0.tien == tien }
    }

    public static func napMacDinh(choMan tien: String) -> String? {
        switch tien {
        case "Passport": return "passport.query"
        // `Main` CỐ Ý không có ở đây. Nó nạp bằng nhánh riêng trong `_napManKhongNangLuc`, và
        // nhánh ấy gom HAI nguồn (`project.status` + `session.state`). Thêm `Main` vào bảng này
        // thì `napMacDinh` chạy trước và trả về, nên nhánh kia không bao giờ tới — màn mất nửa
        // dữ liệu mà vẫn trông như đang hoạt động. Tôi đã thêm nó ngày 16/09/2026 và
        // `testMANmainNAPbangNHANHrieng` bắt được ngay; bài test ấy có mặt đúng để chặn việc
        // này.
        case "Env": return "env.detect"
        // Nhật ký nạp LỊCH SỬ bằng một lời gọi, không chờ kênh đẩy. Kênh đẩy chỉ mang sự kiện
        // thời gian thực; một khối 200 bản ghi đẩy qua stdio làm đầy ống và treo daemon — đo
        // được 14/09/2026 trên dự án ESP32-C3 (82 KB > 64 KB đệm ống).
        case "NhatKy": return "view.timeline"
        // `kg.conflicts` R0, không tham số bắt buộc, không ghi gì — mở màn ra là thấy ngay có
        // xung đột nào đang chờ mình. Đây là màn mà "mở ra đã có dữ liệu" quan trọng nhất:
        // một xung đột không ai biết là một xung đột không ai giải.
        case "XungDot": return "kg.conflicts"
        // Màn 7 có hai vế, và vế mở ra mặc định phải là vế CHẠY ĐƯỢC. `view.rag_ask` cần một
        // mô hình (E5000 khi chưa có khoá) và cần một câu hỏi; `view.kg_map` là R0, không tham
        // số, đọc thẳng từ store. Đo 15/09/2026: mở "Bản đồ & hỏi đáp" từ sidebar ra một ô nhập
        // rỗng và dòng "Gõ câu hỏi rồi Enter", trong khi dự án có sẵn 17 nút và 26 cạnh không
        // ai thấy. Ghi chú cũ nói "Graph không có mặc định vì RagAskView chỉ hiểu
        // {answer, citations}" — đúng vào lúc viết, và hết đúng từ khi `nangLucBanDo` định
        // tuyến `view.kg_map` sang `KgMapView`.
        case "Graph": return "view.kg_map"
        // Màn "Làm rõ yêu cầu" KHÔNG tự nạp: `chat.parse_intent` cần `text`, và đoán một câu
        // để tự chạy là bịa ra yêu cầu của người dùng. Màn mở ra nói câu mời gõ ở ô lệnh.
        default: return nil
        }
    }

    /// Chốt thứ hai: hợp đồng có quyền phủ quyết danh sách.
    ///
    /// Tách thuần để test được mà không cần daemon — cùng lý do với `duongVao`: một quyết định
    /// chỉ tồn tại bên trong một `Task` bất đồng bộ là quyết định không ai kiểm được.
    public static func tuChay(hopDong: [String: Any], id: String,
                              coThamSo: Bool) -> NapLanDau {
        let risk = (hopDong["risk"] as? String) ?? "?"
        let tier = (hopDong["tier"] as? String) ?? "?"
        let undo = (hopDong["undo"] as? String) ?? "none"
        let hoi = (hopDong["ask_when"] as? String) ?? ""
        let can = ((hopDong["input_schema"] as? [String: Any])?["required"] as? [String]) ?? []

        if !can.isEmpty {
            return .cho("`\(id)` cần \(can.map { "`\($0)`" }.joined(separator: ", "))"
                        + (coThamSo ? " — điền rồi Enter." : " — chưa chạy."))
        }
        if !napAnToan.contains(id) {
            return .cho("`\(id)` không nằm trong nhóm chỉ-đọc nên không tự chạy lúc mở màn — "
                      + "gõ lệnh để chạy.")
        }
        if undo != "none" {
            return .cho("`\(id)` có thay đổi hoàn tác được (`\(undo)`) nên không tự chạy lúc "
                      + "mở màn — gõ lệnh để chạy.")
        }
        if risk != "R0" || tier != "T1" || !(hoi.isEmpty || hoi == "—") {
            return .cho("`\(id)` là \(risk)/\(tier), không tự chạy lúc mở màn — gõ lệnh để chạy.")
        }
        return .chay
    }

    private func _napLanDau(_ v: KhungNhinEide, id: String, tenMan ten: String,
                           thamSo: String) {
        Task {
            guard let hd = try? await client.goi(.capsDescribe, ["id": id]) else {
                return await MainActor.run {
                    v.chuaNap("Không đọc được hợp đồng của `\(id)`.")
                }
            }
            if case .chay = Self.tuChay(hopDong: hd, id: id, coThamSo: !thamSo.isEmpty) {
                return self.chay(id, [:],
                                 khiLoi: { v.chuaNap($0) }) { r in v.capNhat(ketQua: r) }
            }

            // Lệnh người gõ không tự chạy được — nhưng màn vẫn có thể nạp bằng năng lực mặc
            // định của NÓ. Gõ `/board.check_pins` mà thiếu tham số thì màn Hộ chiếu mạch vẫn
            // nên hiện những gì nó biết, chứ không đứng trắng chờ một tham số.
            if let md = Self.napMacDinh(choMan: _tienCuaMan(ten)), md != id,
               let hd2 = try? await client.goi(.capsDescribe, ["id": md]),
               case .chay = Self.tuChay(hopDong: hd2, id: md, coThamSo: false) {
                return self.chay(md, [:],
                                 khiLoi: { v.chuaNap($0) }) { r in v.capNhat(ketQua: r) }
            }

            if case .cho(let vi) = Self.tuChay(hopDong: hd, id: id,
                                               coThamSo: !thamSo.isEmpty) {
                await MainActor.run { v.chuaNap(vi) }
            }
        }
    }

    /// Tên màn trong `screens.json` → tiền tố trong `bangMan`.
    private func _tienCuaMan(_ ten: String) -> String {
        bangMan.first { ten.hasPrefix($0.tien) }?.tien ?? ten
    }

    /// Mở bảng lệnh và nạp nguồn: MỌI năng lực trong registry + MỌI màn (§4.2).
    @MainActor
    public func moBangLenh() {
        var ds: [EideBangLenh.Muc] = manHinhCua.keys.sorted().map {
            .init(id: $0, mota: motaNangLuc[$0] ?? "", laMan: false)
        }
        ds += EideDieuHuong.NHOM.flatMap(\.man).map {
            .init(id: $0.tien, mota: "màn hình — \($0.nhan)", laMan: true)
        }
        bangLenh.nap(ds)
        bangLenh.moRa()
    }

    /// Nhãn tiếng Việt của một màn, tra từ bảng điều hướng.
    ///
    /// MỘT nguồn cho tên tab. Hai đường mở màn truyền hai loại tên — đường gõ `/ns.name` truyền
    /// tên đầy đủ trong `screens.json` ("Passport (Hộ chiếu chip)"), đường bấm cột điều hướng
    /// truyền nhãn ("Môi trường") — nên thanh tab hiện ba kiểu chữ cạnh nhau, đo được 18/09/2026.
    /// Tab là chỗ người dùng quét mắt để tìm lại màn vừa đọc; ba kiểu đặt tên trong một hàng làm
    /// việc quét ấy chậm đi mà không mang thêm thông tin nào.
    public static func nhanMan(_ tien: String) -> String {
        EideDieuHuong.NHOM.flatMap(\.man).first { $0.tien == tien }?.nhan ?? tien
    }

    @objc private func _bamCaoHoiThoai(_ n: NSButton) {
        guard let v = n.identifier?.rawValue, let px = Double(v),
              let tt = CaoHoiThoai(rawValue: CGFloat(px)) else { return }
        // `buoc: true` — người BẤM là người quyết; phép hoãn "đang gõ" chỉ áp cho phép tự đổi.
        datCaoHoiThoai(tt, buoc: true)
    }

    @objc private func dongMan() {
        thanhTab.dongHet()
        for k in bangMan { k.v.isHidden = true }
        banDo.isHidden = true
        manNgoai?.isHidden = true
        thanhMan.isHidden = true
        // ẨN CẢ BIỂU MẪU của màn vừa đóng.
        //
        // `oNhap` dựng form theo `nangLucChinh` của màn đang mở, và `dongMan` không chạm tới nó —
        // nên bấm "← Hội thoại" từ màn Mô phỏng để lại hai ô `artifact`/`scenario` và nút
        // "Chạy sim.run" lơ lửng trên đầu hội thoại. Người dùng bấm nút ấy trong lúc đang trò
        // chuyện và không hiểu vì sao có nó. Đo 16/09/2026 trong vòng chạy qua giao diện.
        oNhap.isHidden = true
        hoiThoai.isHidden = false
        hoiThoai.gon = false
    }

    /// Kết quả `chat.send`: `{intent_id, run_id?}`. Trọn đường DPS-09 đã chạy, không phải mỗi
    /// bước hiểu ý — nên câu báo phải nói VIỆC ĐANG CHẠY, không nói "tôi hiểu là…".
    private func hienChuoi(_ r: [String: Any]) {
        if let run = r["run"] as? [String: Any] {
            return hienKetQua(run)   // chuỗi không dựng được: đã có cổng chặn hoặc lỗi
        }
        let y = (r["intent_id"] as? String) ?? "?"
        if let rid = r["run_id"] as? String {
            hoiThoai.themLuot(by: .tacTu, text: "Đang chạy: \(y) (run \(rid)).")
            // Chuỗi dừng chờ người thì nói ra NÓ CHỜ GÌ. Một chuỗi mười sáu bước dừng ở bước bốn
            // mà giao diện chỉ ghi "đang chạy" là giao diện đang nói sai: nó không chạy, nó chờ
            // — và người duy nhất gỡ được thế chờ ấy thì không biết mình đang được chờ.
            for n in (r["cho_nguoi"] as? [[String: Any]] ?? []) {
                let thieu = (n["thieu"] as? [String] ?? []).joined(separator: ", ")
                let cap = (n["cap"] as? String) ?? "?"
                hoiThoai.themLuot(by: .cho,
                                  text: "Dừng ở `\(cap)` — cần anh cho biết: \(thieu).")
            }
        } else {
            hoiThoai.themLuot(by: .cho, text: "Đã hiểu \(y), chưa dựng được chuỗi việc.")
        }
    }

    /// Khoảng nhịp tim, giây.
    public static let NHIP_TIM: TimeInterval = 1.0
    /// Quá bấy nhiêu giây không nghe được daemon thì dữ liệu trên màn là CŨ (N6 đòi ≤ 2 s).
    public static let HAN_DU_LIEU_CU: TimeInterval = 2.0

    /// Đập một nhịp mỗi giây, và đó là thứ làm cho kênh sự kiện có thật.
    ///
    /// API-15 cho `event.*` đi CHUNG ống với câu trả lời, và `EideClient` đọc ống ấy chỉ trong
    /// lúc một lời gọi đang chạy — một quyết định đúng (hai bên cùng đọc một ống là cách mất
    /// thông điệp, xem ghi chú ở `goi`), nhưng nó có một hệ quả không ai viết ra: **khi người
    /// dùng ngồi yên, giao diện điếc hoàn toàn.** Tác tử chạy qua CLI ở tiến trình khác, sổ cái
    /// đầy sự kiện, bộ theo dõi tệp của daemon phát đủ — và cửa sổ đứng im cho tới khi người
    /// bấm một cái gì đó. Cả cơ chế giám sát dựng ở DEV-102 dừng lại đúng ở tầng vận chuyển.
    ///
    /// Một nhịp tim rẻ hơn nhiều so với viết lại tầng vận chuyển thành hai luồng đọc–ghi: mỗi
    /// giây một `plane.hello`, và mọi thông báo đang xếp trong ống được bơm ra trong chính lời
    /// gọi ấy. Nó còn cho luôn phép phát hiện mất daemon — thứ B6 cần — mà không thêm cơ chế.
    ///
    /// Trong lúc một lời gọi dài đang chạy (mô phỏng 25 giây) thì nhịp tim xếp hàng sau nó,
    /// nhưng đúng lúc ấy ống ĐANG được đọc nên sự kiện vẫn tới ngay. Hai cơ chế bù nhau kín.
    private func batNhipTim() {
        nhipTim?.invalidate()
        nhipTim = Timer.scheduledTimer(withTimeInterval: Self.NHIP_TIM, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                let song = (try? await self.client.goi(.planeHello, [:])) != nil
                await MainActor.run {
                    if song { self.lucCuoiNghe = Date() }
                    self.capNhatDaiCu()
                }
            }
        }
    }

    /// Hiện/ẩn dải "Dữ liệu cũ" theo lần cuối nghe được daemon.
    @MainActor
    private func capNhatDaiCu() {
        let tre = Date().timeIntervalSince(lucCuoiNghe)
        daiCu.datCu(tre > Self.HAN_DU_LIEU_CU, tre: tre)
    }

    private func dungGiaoDien() {
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.bg.cgColor

        tenMan.font = NSFont.boldSystemFont(ofSize: 12)
        tenMan.textColor = EideToken.Mau.text
        let nutDong = NSButton(title: "← Hội thoại", target: self, action: #selector(dongMan))
        nutDong.bezelStyle = .inline
        nutDong.font = EideToken.fontUI
        thanhMan.orientation = .horizontal
        thanhMan.alignment = .centerY
        thanhMan.spacing = EideToken.space[1]
        thanhMan.addArrangedSubview(nutDong)
        thanhMan.addArrangedSubview(tenMan)
        // Dòng NĂNG LỰC đứng cạnh tên màn — UXC-31 §2C.4.
        //
        // Đặt ở THANH MÀN chứ không trong khung nhìn: tiêu đề người dùng THẬT SỰ nhìn thấy là
        // tiêu đề ở đây, còn `ManHinhCoSo.tieuDe` bị thanh này che. Đặt nhầm chỗ thì dòng phụ
        // tồn tại trong cây khung nhìn, có test, và không ai nhìn thấy — đúng hình dạng lỗi im
        // lặng 61 (dải chip cao 0) chỉ khác chỗ.
        nangLucMan.font = EideToken.fontMono
        nangLucMan.textColor = EideToken.Mau.faint
        thanhMan.addArrangedSubview(nangLucMan)
        thanhMan.isHidden = true
        for k in bangMan { k.v.isHidden = true }
        banDo.isHidden = true

        // BỐ CỤC BA VÙNG (THIET-KE-UI sheet 1, chủ sản phẩm duyệt 14/09/2026).
        //
        //   [ thanh tự chủ — suốt chiều ngang                                ]
        //   [ giữa: màn đang chọn + ô nhập          | phải: giám sát 300 px  ]
        //   [ giữa: ô lệnh (hội thoại)              |                        ]
        //
        // Vùng phải LUÔN hiện. Bản cũ đặt hàng đợi ở đáy cột giữa với chiều cao cố định 120 px,
        // và mở một màn chuyên đề là đẩy nó khuất — tức đúng lúc tác tử làm việc thì chỗ nó hỏi
        // người lại biến mất.
        oNhap.isHidden = true
        for v in [thanhTuChu, hoiThoai, vungPhai, thanhMan, oNhap] as [NSView]
                 + bangMan.map(\.v) + [banDo] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let g = EideToken.contentGap
        // Thanh vùng trao đổi: nhãn bên trái, ba nút đổi chiều cao bên phải.
        let nhanHT = NSTextField(labelWithString: "VÙNG TRAO ĐỔI")
        nhanHT.font = NSFont.boldSystemFont(ofSize: 10)
        nhanHT.textColor = EideToken.Mau.faint
        thanhHoiThoai.orientation = .horizontal
        thanhHoiThoai.alignment = .centerY
        thanhHoiThoai.spacing = 2
        thanhHoiThoai.addArrangedSubview(nhanHT)
        let dem = NSView()
        dem.setContentHuggingPriority(.init(1), for: .horizontal)
        thanhHoiThoai.addArrangedSubview(dem)
        for (nhan, tt) in [("▁", CaoHoiThoai.thuGon), ("▂", .chuan), ("▃", .moRong)] {
            let b = NSButton(title: nhan, target: self, action: #selector(_bamCaoHoiThoai(_:)))
            b.bezelStyle = .inline
            b.font = EideToken.fontUI
            b.toolTip = "Chiều cao vùng trao đổi: \(Int(tt.rawValue)) pt"
            b.identifier = NSUserInterfaceItemIdentifier("\(Int(tt.rawValue))")
            thanhHoiThoai.addArrangedSubview(b)
        }
        thanhHoiThoai.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thanhHoiThoai)

        // RANH GIỚI BA VÙNG, vẽ ra chứ không để người tự đoán (bản demo UX v2.0: `#screen` nền
        // trắng, `#dock` nền xám có viền trên).
        //
        // Trước đây cả cột giữa cùng một màu, nên vùng làm việc và vùng trao đổi dính vào nhau
        // thành một dải; người dùng phải suy ra ranh giới từ nội dung. Hai khung nhìn nền dưới
        // đây không nhận chuột, không tham gia bố cục của ai — chúng chỉ nói ra chỗ một vùng
        // kết thúc và vùng kia bắt đầu.
        nenLamViec.wantsLayer = true
        nenLamViec.layer?.backgroundColor = EideToken.Mau.surface.cgColor
        nenLamViec.layer?.cornerRadius = EideToken.radius[0]
        nenLamViec.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nenLamViec, positioned: .below, relativeTo: nil)

        vachDock.boxType = .separator
        vachDock.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vachDock)

        thanhTab.onChon = { [weak self] tien in
            guard let self else { return }
            self.nguoiVuaChonMan()
            _ = self._moTheoTenMan(tien, thamSo: "")
        }
        thanhTab.onDong = { [weak self] tien in
            guard let self else { return }
            // Đóng tab đang xem thì mở tab kế; hết tab thì về hội thoại. KHÔNG để vùng làm việc
            // trống mà thanh tab vẫn còn — người dùng sẽ bấm vào một tab không mở gì.
            if let ke = self.thanhTab.dong(tien: tien) {
                _ = self._moTheoTenMan(ke, thamSo: "")
            } else {
                self.dongMan()
            }
        }
        thanhTab.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thanhTab)

        bangLenh.isHidden = true
        bangLenh.translatesAutoresizingMaskIntoConstraints = false
        bangLenh.onChon = { [weak self] id, laMan in
            guard let self else { return }
            self.nguoiVuaChonMan()
            if laMan {
                _ = self._moTheoTenMan(id, thamSo: "")
            } else {
                // Năng lực đi qua ĐÚNG đường mọi lời gọi khác đi (B2): không lối tắt cho bảng
                // lệnh. Dùng lại `chayNhuNguoiDung` để cả phần hiện kết quả cũng giống hệt.
                _ = self.chayNhuNguoiDung(id, [:])
            }
        }
        addSubview(bangLenh)

        vungPhai.dangChay.onChon = { [weak self] ma in
            guard let self else { return }
            self.nguoiVuaChonMan()
            _ = self._moTheoTenMan("NhatKy", thamSo: ma)
        }
        daiCu.onTaiLai = { [weak self] in
            guard let self else { return }
            self.lucCuoiNghe = Date()
            self.capNhatDaiCu()
            Task { await self.lamMoi() }
        }
        addSubview(daiCu)
        batNhipTim()

        NSLayoutConstraint.activate([
            thanhTuChu.topAnchor.constraint(equalTo: topAnchor),
            thanhTuChu.leadingAnchor.constraint(equalTo: leadingAnchor),
            thanhTuChu.trailingAnchor.constraint(equalTo: trailingAnchor),
            thanhTuChu.heightAnchor.constraint(equalToConstant: EideToken.statusbarHeight + 8),

            vungPhai.topAnchor.constraint(equalTo: thanhTuChu.bottomAnchor),
            vungPhai.trailingAnchor.constraint(equalTo: trailingAnchor),
            vungPhai.bottomAnchor.constraint(equalTo: bottomAnchor),
            vungPhai.widthAnchor.constraint(equalToConstant: EideVungPhai.RONG),

            // Ô lệnh nằm DƯỚI cùng của cột giữa và cao cố định: nó phải gõ được mọi lúc, kể cả
            // khi một màn chuyên đề đang mở. Bản cũ để hội thoại chiếm cả cột rồi ẩn nó đi khi
            // mở màn — người dùng muốn gõ một câu phải đóng màn đang xem.
            thanhHoiThoai.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            thanhHoiThoai.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor, constant: -g),
            thanhHoiThoai.bottomAnchor.constraint(equalTo: hoiThoai.topAnchor, constant: -2),

            vachDock.leadingAnchor.constraint(equalTo: leadingAnchor),
            vachDock.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor),
            vachDock.bottomAnchor.constraint(equalTo: thanhHoiThoai.topAnchor, constant: -4),
            vachDock.heightAnchor.constraint(equalToConstant: 1),

            nenLamViec.topAnchor.constraint(equalTo: daiCu.bottomAnchor, constant: 4),
            nenLamViec.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nenLamViec.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor, constant: -4),
            nenLamViec.bottomAnchor.constraint(equalTo: vachDock.topAnchor, constant: -4),

            hoiThoai.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            hoiThoai.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor, constant: -g),
            hoiThoai.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -g),
            // (bắt buộc, = 0) phải thắng được nó.
            _caoHoiThoai,

            thanhMan.topAnchor.constraint(equalTo: thanhTuChu.bottomAnchor, constant: g),
            thanhMan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),

            // Bảng lệnh: lớp phủ GIỮA-TRÊN màn (§4.1), rộng 560 pt như bản demo.
            bangLenh.topAnchor.constraint(equalTo: topAnchor, constant: 70),
            bangLenh.centerXAnchor.constraint(equalTo: centerXAnchor),
            bangLenh.widthAnchor.constraint(equalToConstant: 560),
            bangLenh.heightAnchor.constraint(equalToConstant: 320),

            thanhTab.topAnchor.constraint(equalTo: thanhMan.bottomAnchor, constant: 2),
            thanhTab.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            thanhTab.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor, constant: -g),

            oNhap.topAnchor.constraint(equalTo: thanhTab.bottomAnchor, constant: g),
            oNhap.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            oNhap.trailingAnchor.constraint(lessThanOrEqualTo: vungPhai.leadingAnchor,
                                            constant: -g),
        ])

        // Mọi màn chuyên đề dùng ĐÚNG một khung: cột giữa, từ dưới thanh tiêu đề màn xuống tới
        // trên ô lệnh. Cùng khung thì không màn nào âm thầm rộng hơn màn khác.
        for k in bangMan.map(\.v) + [banDo] {
            NSLayoutConstraint.activate(_rangBuocVungMan(k))
        }
        batNhipTim()

        // Hội thoại bắt đầu ngay dưới thanh tự chủ khi KHÔNG có màn nào mở; khi có màn thì
        // ràng buộc trên của màn đẩy nó xuống. Ưu tiên thấp để nó nhường chỗ cho màn.
        let hoiThoaiTren = hoiThoai.topAnchor.constraint(
            equalTo: thanhTuChu.bottomAnchor, constant: g)
        hoiThoaiTren.priority = .defaultLow
        hoiThoaiTren.isActive = true
    }

    // MARK: - hành động

    /// U1: ô lệnh là giao diện chính. Hai đường vào, và chúng khác nhau về BẢN CHẤT:
    ///
    /// - **Câu tiếng Việt** → `chat.send`. Đây là đường DPS-09 đầy đủ: hiểu ý → neo vào dự án →
    ///   điền mặc định → dựng chuỗi. Panel KHÔNG gọi `chat.parse_intent` trực tiếp: đó mới là
    ///   bước 1 trong 4, và dừng ở đó thì người dùng đọc được "Tôi hiểu là: project.create
    ///   (92%)" rồi không có gì chạy cả — một giao diện hiểu mọi thứ và không làm gì.
    /// - **`/ns.name …`** → mở MÀN HÌNH của năng lực ấy. Danh sách gợi ý "/" đúng là danh sách
    ///   màn hình mở được: `CommandBox` lọc bỏ mọi năng lực có `ui` rỗng, và UXD-13 U1 nói "mọi
    ///   màn hình khác mở được từ lệnh". Ném `/passport.query st.stm32f411` vào bộ đoán ý là
    ///   bắt mô hình ép một id chính xác vào 19 intent của DPS-09 §4.1 — trong đó không có id
    ///   nào của 238 năng lực, nên năng lực người vừa CHỌN không bao giờ tới lượt.
    ///
    /// Panel vẫn là client thuần (GPI-23 §1): nó không hiểu lệnh, chỉ chuyển đúng thứ người đã
    /// chọn từ một danh sách do daemon cấp.
    /// Gõ một câu vào ô lệnh y như người dùng — cho vòng chạy qua giao diện.
    ///
    /// Đi qua ĐÚNG `gui(_:)`, tức qua cả `duongVao` (câu bắt đầu bằng `/` mở màn, còn lại đi
    /// `chat.send`). Gọi thẳng `chat.send` sẽ bỏ qua nhánh phân đường — mà nhánh ấy chính là thứ
    /// quyết định "gõ một câu tiếng Việt thì có việc gì xảy ra không".
    public func goNhuNguoiDung(_ text: String) { gui(text) }

    /// Số lượt trong ô hội thoại — cho vòng chạy đo "gõ xong tác tử có trả lời không".
    public var soLuotHoiThoaiDeTest: Int { hoiThoai.soLuotDeTest }

    /// Ô lệnh có gõ được ngay bây giờ không — hiện ra và không bị che.
    public var oLenhGoDuocDeTest: Bool { !hoiThoai.isHidden && hoiThoai.oLenhHienDeTest }

    private func gui(_ text: String) {
        hoiThoai.themLuot(by: .nguoi, text: text)
        switch Self.duongVao(text) {
        case .moMan(let id, let thamSo):
            return moManHinh(id: id, thamSo: thamSo)
        case .chuoiViec(let t):
            Task {
                do {
                    let r = try await client.goi(.chatSend, ["text": t])
                    await MainActor.run { self.hienChuoi(r) }
                } catch {
                    await MainActor.run { self.hienLoi(error) }
                }
                await lamMoi()
            }
        case .khongCoGi:
            break
        }
    }

    /// Một dòng trong ô lệnh đi về đâu.
    ///
    /// Tách thành hàm THUẦN vì đây đúng là chỗ một lỗi im lặng đã sống: panel từng ném cả
    /// `/passport.query st.stm32f411` vào `chat.parse_intent`, và vì `parse_intent` luôn trả về
    /// *một* intent nào đó với *một* độ tin cậy nào đó, màn hình luôn hiện "Tôi hiểu là: …" —
    /// trông y như đang chạy. Một hàm thuần thì test được mà không cần daemon, nên lần sau ai
    /// đổi đường đi sẽ phải đổi một bài test nói rõ vì sao nó thế.
    public enum DuongVao: Equatable {
        /// Câu tiếng Việt → `chat.send` (trọn DPS-09), KHÔNG phải `chat.parse_intent`.
        case chuoiViec(String)
        /// `/ns.name [tham số]` → mở màn hình của năng lực ấy.
        case moMan(id: String, thamSo: String)
        case khongCoGi
    }

    public static func duongVao(_ text: String) -> DuongVao {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return .khongCoGi }
        guard t.hasPrefix("/") else { return .chuoiViec(t) }
        let phan = t.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        guard let id = phan.first, !id.isEmpty else { return .khongCoGi }
        return .moMan(id: id,
                      thamSo: phan.count > 1
                          ? phan[1].trimmingCharacters(in: .whitespaces) : "")
    }

    /// `/ns.name [tham số]` → mở màn hình của năng lực, với tham số làm giá trị ban đầu.
    ///
    /// Không tự suy tham số thành `params`: mỗi năng lực có `input_schema` riêng, và đoán xem
    /// chuỗi sau id nên vào trường nào là đúng kiểu tự nghĩ ra hành vi. Màn hình có ô nhập của
    /// nó — `PassportView` có ô "Mã linh kiện", `RagAskView` có ô câu hỏi — nên tham số đi vào
    /// ô ấy và người bấm Enter là người quyết định chạy.
    /// Giữ màn người vừa tự chọn bấy nhiêu giây trước khi lại đi theo tác tử.
    ///
    /// 20 giây: đủ để đọc xong một bảng, ngắn hơn hẳn một lượt chạy có mô hình.
    public static let GIU_MAN_NGUOI_CHON: TimeInterval = 20

    private var _nguoiTuChonLuc: Date?

    /// Mở màn phụ trách năng lực `cap`, trừ khi người dùng vừa tự chọn một màn khác.
    private func _theoTacTu(_ cap: String) {
        if let luc = _nguoiTuChonLuc,
           Date().timeIntervalSince(luc) < Self.GIU_MAN_NGUOI_CHON { return }
        guard let man = manHinhCua[cap] else { return }
        // Màn "Mã nguồn" là trình soạn thảo (một màn NGOÀI), không có khung nhìn trong `bangMan`
        // — nên nó phải đi đường riêng. Đây đúng là ví dụ chủ sản phẩm đưa: *"agent đang viết
        // code hoặc sửa code thì sẽ mở phần giao diện code"*.
        if man.hasPrefix("Code"), manNgoai != nil {
            if manNgoai?.isHidden == false { return }
            hienManNgoai()
            onTacTuMoMan?("Code")
            hoiThoai.themLuot(by: .heThong, text: "→ mở màn Mã nguồn (tác tử đang chạy `\(cap)`)")
            return
        }
        guard let v = khungCua(man, id: cap) else { return }
        // Đã đúng màn rồi thì thôi — mở lại sẽ xoá thân màn và nạp lại, tức nhấp nháy dưới tay
        // người đang đọc.
        if !v.isHidden { return }
        hienKhung(v, ten: man, id: cap, thamSo: "")
        // FOCUS: chuyển cả mục đang sáng trên sidebar, không chỉ đổi nội dung.
        if let k = bangMan.first(where: { $0.v === v })?.tien ?? (v === banDo ? "Graph" : nil) {
            onTacTuMoMan?(k)
        }
        hoiThoai.themLuot(by: .heThong, text: "→ mở màn \(man) (tác tử đang chạy `\(cap)`)")
        // Nạp dữ liệu mặc định của màn nếu có: tác tử vừa chạy `cap`, và màn mở ra rỗng thì
        // người dùng thấy đúng cái tên màn và không thấy việc.
        if let mac = Self.napMacDinh(choMan: man), mac != cap {
            chay(mac, [:], khiLoi: { [weak v] in v?.chuaNap($0) }) { [weak v] r in
                v?.capNhat(ketQua: r)
            }
        }
    }

    /// Đánh dấu người vừa TỰ chọn một màn — gọi từ đường sidebar và đường gõ `/ns.name`.
    public func nguoiVuaChonMan() { _nguoiTuChonLuc = Date() }

    /// Ràng buộc của VÙNG MÀN: cột giữa, từ dưới ô nhập xuống trên hội thoại.
    ///
    /// Một bộ ràng buộc duy nhất cho cả 23 màn chuyên đề LẪN trình soạn thảo — nên không màn nào
    /// âm thầm rộng hơn màn khác, và trình soạn thảo không thể lấn vào chỗ của hội thoại.
    private func _rangBuocVungMan(_ k: NSView) -> [NSLayoutConstraint] {
        let g = EideToken.space[2]
        return [
            // Neo dưới DẢI CŨ, không dưới ô nhập: dải cao 0 khi bình thường nên không đổi gì,
            // còn khi nó hiện thì mọi màn tụt xuống thay vì bị nó đè lên.
            k.topAnchor.constraint(equalTo: daiCu.bottomAnchor, constant: g),
            k.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            k.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor, constant: -g),
            k.bottomAnchor.constraint(equalTo: thanhHoiThoai.topAnchor, constant: -g),
        ]
    }

    /// Khung nhìn NGOÀI đặt vào vùng màn — trình soạn thảo của cửa sổ.
    ///
    /// ## Vì sao trình soạn thảo phải nằm TRONG panel
    ///
    /// Chủ sản phẩm 16/09/2026: *"khu vực tương tác người và agent sẽ vẫn phải đảm bảo luôn hiển
    /// thị"*. Trước thay đổi này, cửa sổ đổi CHỖ giữa hai thứ: panel (có hội thoại và cột giám
    /// sát) và trình soạn thảo. Mở màn Mã nguồn nghĩa là ẩn panel — tức mất CẢ chỗ trao đổi lẫn
    /// chỗ giám sát, đúng lúc tác tử đang sửa mã và người cần nhìn nhất.
    ///
    /// Nay trình soạn thảo là MỘT MÀN như 22 màn kia: nó nằm trong vùng màn của panel, dùng đúng
    /// bộ ràng buộc ấy, và hội thoại cùng cột giám sát không bao giờ rời màn hình.
    private weak var manNgoai: NSView?

    /// Cửa sổ giao trình soạn thảo cho panel giữ. Gọi MỘT LẦN lúc dựng.
    public func datManNgoai(_ v: NSView) {
        manNgoai = v
        v.translatesAutoresizingMaskIntoConstraints = false
        addSubview(v)
        NSLayoutConstraint.activate(_rangBuocVungMan(v))
        v.isHidden = true
    }

    /// Hiện trình soạn thảo trong vùng màn, ẩn mọi màn chuyên đề.
    public func hienManNgoai() {
        for k in bangMan { k.v.isHidden = true }
        banDo.isHidden = true
        manNgoai?.isHidden = false
        oNhap.isHidden = true
        thanhMan.isHidden = false
        tenMan.stringValue = "Mã nguồn"
        hoiThoai.isHidden = false
        hoiThoai.gon = false
        _manDangHoi = "Code"
    }

    /// Tác tử vừa MỞ một màn: `(tiền tố màn)`. Cửa sổ nối vào để chuyển cả điều hướng.
    ///
    /// Panel không tự làm được việc này: sidebar thuộc về cửa sổ (DEV-098), và panel chỉ biết
    /// khung nhìn của mình. Không có đường này thì màn đổi mà **mục đang sáng trên sidebar vẫn ở
    /// chỗ cũ** — người dùng nhìn thấy nội dung một đằng, điều hướng một nẻo, và không biết mình
    /// đang ở đâu. Chủ sản phẩm 16/09/2026: *"tự mở và focus vào phần đó"*.
    public var onTacTuMoMan: ((String) -> Void)?

    /// Tác tử bắt đầu/thôi ghi một tệp — `(đường dẫn hoặc nil, mô tả bước)`. UXC-31 §5.6.
    public var onTacTuSuaTep: ((String?, String) -> Void)?

    private func moManHinh(id: String, thamSo: String) {
        nguoiVuaChonMan()
        // Thử TÊN MÀN trước khi báo không có: ba màn trong bảng UXD-13 §2 không có năng lực
        // nào trỏ tới chúng, nên không lệnh `/ns.name` nào mở được — xem `_moTheoTenMan`.
        if manHinhCua[id] == nil, _moTheoTenMan(id, thamSo: thamSo) { return }
        guard let man = manHinhCua[id] else {
            // U9: lỗi phải nói được hành động tiếp theo. Một id gõ sai không được im lặng.
            hoiThoai.themLuot(by: .loi,
                              text: "Không có năng lực `\(id)` có màn hình. Gõ \"/\" để xem danh sách.")
            return
        }
        guard let v = khungCua(man, id: id) else {
            hoiThoai.themLuot(by: .heThong,
                              text: "Màn \"\(man)\" chưa dựng — `\(id)` thuộc màn ấy. "
                                  + "Ba màn đã có: Passport, Graph → RagAsk, Doc.")
            return
        }
        hienKhung(v, ten: man, id: id, thamSo: thamSo)
    }

    /// U6: dừng khẩn ở mọi nơi, hạ A0 dưới 1 giây. Không hỏi lại — một nút dừng có hộp thoại
    /// xác nhận thì không còn là nút dừng khẩn.
    private func dungKhan() {
        Task {
            _ = try? await client.goi(.stop, [:])
            await lamMoi()
            await MainActor.run {
                self.hoiThoai.themLuot(by: .heThong, text: "■ Đã dừng khẩn. Mức tự chủ về A0.")
            }
        }
    }

    private func hienKetQua(_ r: [String: Any]) {
        // `caps.invoke` trả một CapabilityRun (API-15). Ba trạng thái, ba cách nói — U9 đòi
        // trạng thái chờ phải nhìn thấy được, không được lẫn vào "đã xong".
        let status = r["status"] as? String ?? "?"
        switch status {
        case "done":
            hoiThoai.themLuot(by: .tacTu,
                              text: Self.docKetQua((r["result"] as? [String: Any]) ?? [:]))
        case "pending":
            let d = r["decision"] as? [String: Any]
            hoiThoai.themLuot(by: .cho,
                              text: "Chờ anh duyệt — \(d?["reason"] as? String ?? "cổng chính sách").")
        default:
            let e = r["error"] as? [String: Any]
            hoiThoai.themLuot(by: .loi,
                              text: "\(e?["eide_code"] as? String ?? "lỗi"): \(e?["message"] as? String ?? "")")
        }
    }

    /// Kết quả của một năng lực KHÔNG có khung nhìn riêng, thành một câu đọc được.
    ///
    /// Bản đầu chỉ đọc `intent`, nên mọi năng lực khác chạy xong đều hiện *"Tôi hiểu là: ?
    /// (tin cậy 0%)"* — một câu vừa vô nghĩa vừa sai, và nó xuất hiện đúng vào lúc một việc
    /// vừa chạy thành công.
    ///
    /// Tám năng lực của màn Chat đổ về đây, và chúng là nhóm duy nhất cố ý KHÔNG có khung nhìn
    /// riêng: kết quả của `chat.ground` hay `policy.set_autonomy` là một câu nói với người,
    /// không phải một bảng để đọc. Hội thoại đúng là chỗ của chúng.
    static func docKetQua(_ kq: [String: Any]) -> String {
        // `chat.parse_intent` — ý hiểu, kèm độ tin cậy vì DPS-09 §4.1 coi < 0,6 là `unknown`.
        if let y = kq["intent"] as? [String: Any] {
            let ten = (y["intent"] as? String) ?? "?"
            let tin = EideSo.thuc(y["confidence"]) ?? 0
            let lon = (y["is_big"] as? Bool) ?? false
            return "Tôi hiểu là: \(ten) (tin cậy \(Int(tin * 100))%)"
                 + (lon ? " — việc lớn, tôi sẽ dựng kế hoạch trước." : ".")
        }
        // `chat.ground` — neo ý hiểu vào dự án. `missing` là thứ chặn chuỗi đi tiếp.
        if let g = kq["grounded"] as? [String: Any] {
            let thieu = (g["missing"] as? [Any]) ?? []
            return thieu.isEmpty
                ? "Đã neo vào dự án: " + g.keys.sorted().joined(separator: ", ") + "."
                : "Chưa neo được — thiếu "
                  + thieu.map { EideKnowledgeFormat.giaTri($0) }.joined(separator: ", ") + "."
        }
        // `chat.orchestrate` — chuỗi đã dựng và đang chạy.
        if let rid = kq["run_id"] as? String { return "Đang chạy chuỗi \(rid)." }
        // `chat.restate` / `chat.decline` — cả hai trả `text`, và `decline` là một lời TỪ CHỐI
        // có lý do; hiện nó như một câu bình thường thì người không biết việc đã dừng.
        if let van = kq["text"] as? String { return van }
        // `memory.compose` — gói ngữ cảnh C0..C7 cho một lượt gọi mô hình.
        if let b = kq["bundle"] as? [String: Any] {
            let tk = EideSo.nguyen((b["tokens"] as? [String: Any])?["total"] ?? b["tokens"])
            return "Đã gộp ngữ cảnh" + (tk.map { " — \($0) token" } ?? "") + "."
        }
        // `policy.permit` — quyền TẠM, và thời hạn là phần quan trọng nhất của nó.
        if let pid = kq["permission_id"] as? String {
            let han = (kq["expires_at"] as? String) ?? ""
            return "Đã cấp quyền tạm \(pid)"
                 + (han.isEmpty ? " — KHÔNG rõ hạn, đây là điều nên xem lại." : ", hết hạn \(han).")
        }
        // `policy.escalate` — leo thang lên người qua những kênh nào.
        if let k = kq["notified"] as? [Any] {
            return k.isEmpty
                ? "Đã leo thang nhưng KHÔNG kênh nào nhận — người sẽ không biết."
                : "Đã báo qua: " + k.map { EideKnowledgeFormat.giaTri($0) }
                    .joined(separator: ", ") + "."
        }
        // `policy.learn_thresholds` — đề xuất NỚI ngưỡng; POL-17 §3 đòi ký nên nó chỉ là đề nghị.
        if let dx = kq["proposals"] as? [Any] {
            return dx.isEmpty ? "Không có ngưỡng nào đáng đổi."
                              : "\(dx.count) đề xuất đổi ngưỡng — nới lỏng thì cần anh ký."
        }
        // `policy.set_autonomy` — mức THỰC SỰ có hiệu lực, có thể khác mức vừa xin.
        if let m = kq["effective"] as? String { return "Mức tự chủ đang có hiệu lực: \(m)." }

        if kq.isEmpty { return "Xong." }
        return "Xong — " + kq.keys.sorted().prefix(6).map { k in
            let v = kq[k]
            if let a = v as? [Any] { return "\(k): \(a.count) mục" }
            return "\(k): \(EideKnowledgeFormat.giaTri(v))"
        }.joined(separator: " · ")
    }

    private func hienLoi(_ error: Error) {
        if let f = error as? EideClient.Failure, let ma = f.maEide {
            // U9: "lỗi hiện mã API-15 VÀ HÀNH ĐỘNG GỢI Ý" — mã trần không giúp được ai.
            hoiThoai.themLuot(by: .loi, text: "\(ma.ma) \(f): \(ma.cachXuLy)")
        } else {
            hoiThoai.themLuot(by: .loi, text: "\(error)")
        }
    }

    /// Nạp danh sách năng lực cho gợi ý "/" — UXD-13 U1.
    ///
    /// Gọi MỘT lần lúc mở panel, không gọi lại mỗi lần gõ: registry chỉ đổi khi daemon khởi
    /// động lại (hoặc khi `tool.register` nạp nóng một năng lực `user.*`), nên hỏi lại theo
    /// từng phím là 238 dòng đi qua socket cho mỗi ký tự.
    private func napGoiY() async {
        guard let r = try? await client.goi(.capsList, [:]),
              let caps = r["caps"] as? [[String: Any]] else { return }
        let ds = caps.compactMap { c -> CommandBox.NangLuc? in
            guard let id = c["id"] as? String, c["implemented"] as? Bool == true else { return nil }
            return .init(id: id, mota: c["desc"] as? String ?? "", manHinh: c["ui"] as? String ?? "")
        }
        // Cùng một bảng cho gợi ý "/" VÀ cho việc mở màn: nếu tách hai bảng thì có ngày người
        // chọn được một năng lực trong menu rồi panel bảo "không có năng lực ấy".
        let bang = Dictionary(ds.map { ($0.id, $0.manHinh) }, uniquingKeysWith: { a, _ in a })

        // Ba màn không có năng lực nào trỏ tới (DEV-094) vào menu bằng chính TÊN màn. Mở được
        // mà tìm không ra thì cũng như không mở được: menu "/" là chỗ duy nhất người dùng biết
        // panel có những gì.
        let coNangLuc = Set(ds.map(\.manHinh))
        let man = await MainActor.run { self.bangMan.map(\.tien) }
        let themMan = man.filter { tien in !coNangLuc.contains { $0.hasPrefix(tien) } }
            .map { CommandBox.NangLuc(id: $0,
                                      mota: "màn hình (không phải năng lực)",
                                      manHinh: $0) }

        // Giữ lại MÔ TẢ, không chỉ tên. §4.2 đòi bảng lệnh tìm theo cả mô tả: người dùng nhớ
        // "cái tra thanh ghi" chứ không nhớ `passport.query`, và một ô tìm chỉ khớp tên là một
        // ô tìm chỉ dùng được cho người đã thuộc bảng 242 năng lực.
        let mota = Dictionary(ds.map { ($0.id, $0.mota) }, uniquingKeysWith: { a, _ in a })
        await MainActor.run {
            self.manHinhCua = bang
            self.motaNangLuc = mota
            self.hoiThoai.oLenh.napNangLuc(ds + themMan)
            self._dienNangLucPhu()
        }
    }

    /// Năng lực đứng sau một màn, đảo từ bảng `cap → màn` daemon gửi.
    ///
    /// Cắt còn ba tên: màn Nhập tài liệu đứng sau hơn hai mươi năng lực, và một dòng phụ dài
    /// hơn tên màn thì không còn là dòng phụ.
    @MainActor
    private func _nangLucCuaMan(_ ten: String) -> String {
        // Tra bằng CẢ HAI chiều: `ten` có thể là tiền tố (`Passport`) khi mở bằng `/` hoặc là
        // NHÃN tiếng Việt (`Hộ chiếu chip`) khi bấm trên cột điều hướng. `_tienCuaMan` chỉ xử lý
        // chiều thứ nhất — nó so `ten.hasPrefix(tiền tố)`, mà "Hộ chiếu chip" không bắt đầu bằng
        // "Passport", nên nó trả về chính cái nhãn và phép lọc dưới đây khớp 0 năng lực. Dòng
        // phụ vì thế rỗng ở đúng đường vào mà người dùng đi nhiều nhất.
        let tien = _tienCuaMan(ten)
        var ds = manHinhCua.filter {
            $0.value.hasPrefix(tien) || $0.value.contains("(\(ten))")
        }.keys.sorted()
        guard !ds.isEmpty else { return "" }
        // NĂNG LỰC MẶC ĐỊNH lên đầu, phần còn lại theo bảng chữ cái.
        //
        // Sắp thuần chữ cái cho ra "passport.diff · passport.export · passport.import" cho màn
        // Hộ chiếu chip — ba năng lực ít liên quan nhất tới thứ màn đang hiện, chỉ vì chữ `d`
        // đứng trước chữ `q`. Thứ người đọc cần là năng lực màn THẬT SỰ chạy khi mở ra.
        if let md = Self.napMacDinh(choMan: tien), let i = ds.firstIndex(of: md) {
            ds.remove(at: i)
            ds.insert(md, at: 0)
        }
        let hien = ds.count > 3 ? Array(ds.prefix(3)) + ["+\(ds.count - 3)"] : ds
        return hien.joined(separator: " · ")
    }

    /// Chiếu các thẻ Run đang chạy xuống khối ĐANG CHẠY ở cột phải — UXC-31 §2F.1.
    ///
    /// Gọi ở đúng hai chỗ thẻ Run đổi tập hợp: lúc thêm và lúc gỡ. KHÔNG gọi ở mỗi lần cập nhật
    /// tiến độ — bản chiếu một dòng không đổi khi một bước xong, và vẽ lại cột phải mỗi sự kiện
    /// là vẽ lại vài chục lần một giây trong lúc một chuỗi chạy.
    @MainActor
    private func _chieuDangChay() {
        let ds = theTienDo
            .filter { !$0.value.daXong || $0.value.choNguoi }
            .map { (ma: $0.key, dong: $0.value.tomTat_choTest) }
            .sorted { $0.dong < $1.dong }
        vungPhai.dangChay.datDs(ds)
    }

    /// Điền dòng phụ "năng lực đứng sau" cho từng màn — UXC-31 §2C.4.
    ///
    /// ĐẢO bảng `cap → màn` mà daemon vừa gửi, thay vì giữ một bảng `màn → cap` viết tay. Bảng
    /// viết tay là bản sao thứ hai của `screens.json`, và mọi bản sao thứ hai trong kho này đều
    /// đã lệch ít nhất một lần (xem DEV-128 lỗi 70). Đảo bảng thì không có gì để lệch.
    @MainActor
    private func _dienNangLucPhu() {
        var theoMan: [String: [String]] = [:]
        for (cap, man) in manHinhCua {
            theoMan[man, default: []].append(cap)
        }
        for (tien, v) in bangMan {
            guard let m = v as? ManHinhCoSo else { continue }
            let ds = theoMan.first { $0.key.hasPrefix(tien) }?.value.sorted() ?? []
            // Cắt còn ba tên: một màn như Nhập tài liệu đứng sau hơn hai mươi năng lực, và một
            // dòng phụ dài hai dòng thì không còn là dòng phụ.
            m.datNangLuc(ds.count > 3 ? Array(ds.prefix(3)) + ["+\(ds.count - 3)"] : ds)
        }
    }

    /// Thông báo `event.*` từ daemon — API-15 §1 (16 phương thức) và §5 (sổ cái).
    ///
    /// **Trước hôm nay không ai nghe kênh này.** `hienCauHoi` là `public`, có test, và chưa
    /// từng được gọi: daemon phát `event.chat.question` mỗi lần một năng lực cần người chọn,
    /// và thẻ câu hỏi gộp của U3 không bao giờ hiện ra. Người dùng thấy việc dừng lại mà không
    /// thấy câu hỏi — đúng loại im lặng mà U2 ("làm rồi báo cáo, NHÌN THẤY ĐƯỢC") cấm.
    ///
    /// Ba nhóm, ba cách xử lý khác nhau:
    ///
    /// - **Hỏi người** (`event.chat.question`) — hiện thẻ ngay; đây là thứ đang chặn công việc.
    /// - **Trạng thái đổi** (`queue.changed`, `gate.opened`, `undo.*`, `autonomy.changed`) —
    ///   đọc lại từ daemon. Panel không tự suy trạng thái mới từ nội dung sự kiện: GPI-23 §1
    ///   nói nó là client thuần, và một bản sao trạng thái dựng từ sự kiện sẽ trôi khỏi sự thật
    ///   sau đúng một thông điệp bị mất.
    /// - **Tri thức đổi** (`knowledge.changed`, `doc.stale`, `diagram.stale`) — nạp lại MÀN
    ///   ĐANG MỞ nếu nó hiện thứ vừa đổi. Một màn hộ chiếu mở sẵn trong lúc `extract.svd` chạy
    ///   xong mà vẫn hiện số fact cũ là một màn nói sai.
    @MainActor
    func nhanSuKien(_ ten: String, _ p: [String: Any]) {
        // MỌI sự kiện vào nhật ký TRƯỚC, kể cả loại `switch` dưới không xử lý.
        //
        // Thứ tự này là bất biến của cả tính năng giám sát: nếu nhật ký nằm trong một `case` thì
        // mỗi sự kiện thêm về sau là một chỗ có thể quên, và màn "tác tử vừa làm gì" sẽ im lặng
        // bỏ sót đúng việc vừa thêm. `NhatKyView.dich` tự bỏ thứ nó không hiểu, nên đưa thừa
        // vào đây rẻ hơn nhiều so với đưa thiếu.
        nhatKy.them(ten, p)
        switch ten {
        case "event.chat.question":
            hienCauHoi(p)
        case "event.chat.restated":
            hienYHieu(p)
        case "event.run.progress", "event.job.progress":
            // TÁC TỬ LÀM TỚI ĐÂU, MÀN ẤY MỞ RA VÀ ĐƯỢC FOCUS.
            //
            // Chủ sản phẩm chốt 16/09/2026: *"các giao diện chuyên biệt theo từng tác vụ khi
            // Agent thay đổi đến phần đó thì nó sẽ được show đến"*. Trước đó người dùng phải tự
            // đoán tác tử đang làm gì rồi tự bấm đúng màn — tức phải thuộc bảng 238 năng lực
            // thuộc màn nào.
            //
            // KHÔNG cướp màn khi người dùng vừa tự chọn một màn khác: `_nguoiTuChon` đánh dấu
            // lựa chọn của người và giữ nó trong `GIU_MAN_NGUOI_CHON` giây. Một giao diện tự đổi
            // màn ngay dưới tay người đang đọc là giao diện không dùng được.
            //
            // Nối vào `event.run.progress` chứ không một sự kiện riêng: daemon ánh xạ CẢ
            // `cap.run.start` lẫn `cap.run.finish` về tên ấy (`SU_KIEN` trong rpc.py). Tôi đã
            // viết `case "event.cap.run.start"` một lần và nó không bao giờ chạy — tên sự kiện
            // của sổ cái khác tên sự kiện của API-15, và chỗ ánh xạ nằm ở phía daemon.
            if let cap = p["cap"] as? String { _theoTacTu(cap) }
            _bamTepTacTuSua(p)
            hienTienDo(p)
        case "event.notice":
            let muc = (p["level"] as? String) ?? "info"
            let tin = (p["message"] as? String) ?? (p["text"] as? String) ?? ""
            hoiThoai.themLuot(by: muc == "error" ? .loi : .heThong, text: tin)
            // Leo thang KHÔNG phải một dòng thông báo. APD-08 §5: nó nghĩa là công việc đã dừng
            // lại chờ người — năm lý do (cổng ASK, hỏng 2 lần, ngân sách < 20%, board lệch hộ
            // chiếu, mẫu bất thường) đều dẫn tới cùng một tình trạng. Một dòng lẫn trong hội
            // thoại thì người giám sát lướt qua, và tác tử đứng im chờ mãi.
            if (p["kind"] as? String) == "policy.escalate" {
                thanhTuChu.leoThang(tin.isEmpty ? "tác tử đang chờ anh trả lời" : tin)
            }
        case "event.chat.report":
            hoiThoai.themLuot(by: .tacTu, text: (p["text"] as? String) ?? "(báo cáo)")
        case "event.queue.changed", "event.gate.opened", "event.undo.registered",
             "event.undo.expired", "event.autonomy.changed":
            Task { await lamMoi() }
        case "event.knowledge.changed", "event.doc.stale", "event.diagram.stale":
            _napLaiManDangMo()
        case "event.gate.decided", "event.model.call", "event.tool.report",
             "event.project.changed", "event.chat.intent":
            // Năm sự kiện GIÁM SÁT: tác tử vừa tự làm xong một việc. Không có gì phải bấm, và
            // cũng không có màn nào phải nạp lại — chỗ của chúng là dòng thời gian, nơi
            // `nhatKy.them` ở đầu hàm đã đưa chúng vào. Liệt kê ra đây thay vì để rơi xuống
            // `default` là để người đọc mã thấy chúng KHÔNG bị bỏ quên.
            break
        default:
            break   // discover.changed, serial.line — cần board
        }
    }

    /// Nạp lại màn đang mở, nếu nó tự nạp được.
    private func _napLaiManDangMo() {
        guard let k = bangMan.first(where: { !$0.v.isHidden }),
              let md = Self.napMacDinh(choMan: k.tien) else { return }
        let v = k.v
        chay(md, [:], khiLoi: { [weak v] in v?.chuaNap($0) }) { [weak v] r in
            v?.capNhat(ketQua: r)
        }
    }

    // MARK: - Phím tắt (UXD-13 §6)

    /// Mười tổ hợp phím của UXD-13 §6 — nhưng chỉ khi người đang làm việc TRONG panel.
    ///
    /// ## Vì sao có điều kiện ấy
    ///
    /// UXD-13 §6 viết cho một EIDE chiếm cả cửa sổ (mockup là 1440×900). Thực tế nó là một
    /// panel trong GEditor, nơi hai phím đã có chủ: `⌘L` là "Đi tới dòng…" và `⌘Z` là "Hoàn
    /// tác" của trình soạn thảo. Cướp chúng ở mức cửa sổ nghĩa là người đang sửa mã bấm `⌘Z` và
    /// thấy một mục hàng đợi bị hoàn tác thay vì dòng vừa gõ — một trong những cách tệ nhất để
    /// một tính năng mới làm hỏng một thói quen cũ.
    ///
    /// Nên: panel chỉ nhận phím khi first responder nằm trong cây của nó. Ngoài panel, GEditor
    /// giữ nguyên mọi phím. Đây là một sai khác có chủ ý với §6 — xem DEV-096.
    public override func performKeyEquivalent(with su: NSEvent) -> Bool {
        guard _dangLamViecTrongPanel else { return false }
        let cmd = su.modifierFlags.contains(.command)
        let shift = su.modifierFlags.contains(.shift)
        let phim = su.charactersIgnoringModifiers ?? ""

        switch (cmd, shift, phim) {
        case (true, false, "l"):
            hoiThoai.oLenh.vaoO()
            return true
        case (true, false, "k"):
            moBangLenh()
            return true
        case (true, true, "q"), (true, true, "Q"):
            dongMan()
            hangDoi.window?.makeFirstResponder(hangDoi)
            return true
        case (true, false, "z"):
            return hangDoi.hoanTacMucDau()
        case (true, false, "\r"):
            // ⌘⏎ trong DiagramView: render. Chỉ khi màn lược đồ đang mở — cùng phím ở màn khác
            // không được làm một việc khác, vì người dùng học phím theo việc chứ không theo màn.
            guard !luocDo.isHidden else { return false }
            chay("diagram.render", [:], khiLoi: { [weak self] in self?.luocDo.chuaNap($0) }) {
                [weak self] r in self?.luocDo.capNhat(ketQua: r)
            }
            return true
        case (false, false, "f"), (false, false, "F"):
            // "F trong bản đồ: tìm nút" — chỉ khi bản đồ đang mở VÀ con trỏ không ở ô nhập,
            // nếu không thì gõ chữ "f" vào câu hỏi sẽ mở hộp tìm.
            guard !banDo.isHidden, !_dangGoTrongONhap else { return false }
            hoiThoai.oLenh.dienSan("/view.kg_focus ")
            return true
        default:
            break
        }

        // ⌘1…⌘9 — chín màn đầu của bảng UXD-13 §2, đúng thứ tự bảng.
        if cmd, !shift, let n = Int(phim), (1...9).contains(n) {
            let ten = Self.tienManDaDung
            guard n <= ten.count else { return false }
            _ = _moTheoTenMan(ten[n - 1], thamSo: "")
            return true
        }
        return false
    }

    public override func keyDown(with su: NSEvent) {
        // Esc: đóng màn chuyên đề (UXD-13 §6). `performKeyEquivalent` không nhận Esc, nên nó
        // đi đường `keyDown`.
        if su.keyCode == 53 {
            dongMan()
            return
        }
        super.keyDown(with: su)
    }

    private var _dangLamViecTrongPanel: Bool {
        guard let fr = window?.firstResponder as? NSView else { return false }
        return fr === self || fr.isDescendant(of: self)
    }

    private var _dangGoTrongONhap: Bool {
        (window?.firstResponder as? NSText) != nil
            || (window?.firstResponder as? NSTextView) != nil
    }

    /// Thẻ ý hiểu — UXD-13 §4 RestateCard, từ `event.chat.restated` `{intent_id, text}`.
    ///
    /// Nút "Sửa ý hiểu" điền văn bản vào ô lệnh (UXD-13 §3), KHÔNG tự gửi lại: người sửa xong
    /// mới là người quyết định gửi. Tự gửi một câu vừa được sửa dở là chạy một việc không ai
    /// đặt hàng.
    @MainActor
    func hienYHieu(_ p: [String: Any]) {
        let van = (p["text"] as? String) ?? ""
        let buoc = ((p["steps"] as? [Any]) ?? []).map { EideKnowledgeFormat.giaTri($0) }
        let the = RestateCard(text: van, buoc: buoc,
                              intentId: (p["intent_id"] as? String) ?? "")
        the.onSua = { [weak self] t in self?.hoiThoai.oLenh.dienSan(t) }
        hoiThoai.themThe(the)
    }

    /// Theo dõi tệp tác tử đang ghi, để cửa sổ dựng băng §5.6.
    ///
    /// Bật ở `cap.run.start`, tắt ở `cap.run.finish` — cặp ấy luôn đủ đôi vì Router ghi cả hai
    /// quanh MỌI lời gọi, kể cả lời gọi hỏng. Bám vào `run.step_*` thì hụt: một năng lực gọi lẻ
    /// (người bấm nút trên màn) không nằm trong chuỗi nào và không có bước nào.
    private func _bamTepTacTuSua(_ p: [String: Any]) {
        guard let kind = p["kind"] as? String else { return }
        if kind == "cap.run.start", let t = p["target"] as? String {
            let cap = (p["cap"] as? String) ?? "một năng lực"
            let buoc: String
            if let i = EideSo.nguyen(p["i"]), let n = EideSo.nguyen(p["of"]) {
                buoc = "`\(cap)` (bước \(i)/\(n))"
            } else {
                buoc = "`\(cap)`"
            }
            onTacTuSuaTep?(t, buoc)
        } else if kind == "cap.run.finish" {
            onTacTuSuaTep?(nil, "")
        }
    }

    /// Thẻ tiến độ chuỗi — UXD-13 §4 RunProgress.
    ///
    /// **Một thẻ cho mỗi `run_id`, không phải một thẻ cho mỗi thông điệp.** Daemon phát một
    /// `event.run.progress` khi mỗi nút bắt đầu và một khi mỗi nút xong; một chuỗi 17 bước sinh
    /// 34 thông điệp, và 34 thẻ chồng nhau thì không ai đọc được cái nào.
    @MainActor
    func hienTienDo(_ p: [String: Any]) {
        let id = (p["run_id"] as? String) ?? (p["job_id"] as? String) ?? ""
        guard !id.isEmpty else { return }
        if let the = theTienDo[id] { return the.capNhat(p) }

        let the = RunProgressCard(runId: id)
        the.onHuy = { [weak self] rid in
            // `job.cancel` cho việc nặng; chuỗi thường thì dừng khẩn là đường duy nhất API-15
            // có — nói thẳng điều đó thay vì im lặng không làm gì.
            if p["job_id"] != nil {
                self?.chay2(.jobCancel, ["job_id": rid])
            } else {
                self?.hoiThoai.themLuot(
                    by: .heThong,
                    text: "Chuỗi \(rid) chỉ dừng được bằng dừng khẩn (⌘⇧.) — API-15 chưa có "
                        + "phương thức huỷ riêng cho một chuỗi.")
            }
        }
        the.onXemNut = { [weak self] cap in
            self?.chay2(.capsDescribe, ["id": cap])
        }
        // "Mở chi tiết" → màn Nhật ký, lọc sẵn theo mã lượt chạy. Thẻ Run trả lời câu "đến bước
        // mấy"; câu "bước ấy đã làm gì" thuộc về sổ cái, và dẫn người sang đúng chỗ ấy rẻ hơn
        // nhiều so với nhồi thêm chi tiết vào một thẻ nằm trong dòng hội thoại.
        the.onXemChiTiet = { [weak self] rid in
            self?.nguoiVuaChonMan()
            _ = self?._moTheoTenMan("NhatKy", thamSo: rid)
        }
        // GỠ thẻ khi việc xong. Không gỡ thì mỗi lượt chạy để lại một thẻ vĩnh viễn: đo
        // 16/09/2026 trong một vòng qua giao diện, mười lăm thẻ đã xong xếp chồng và kéo CỬA SỔ
        // cao 4048 px — người dùng cuộn mãi không tới ô lệnh.
        //
        // Chờ `TRE_GO_THE` giây rồi mới gỡ: biến mất ngay lúc xong thì người đang nhìn không kịp
        // thấy nó xong. Và không mất gì — việc đã xong nằm trong Nhật ký và trong cột "hoàn tác
        // được" bên phải; thẻ tiến độ chỉ nói về thứ ĐANG chạy.
        the.onXong = { [weak self, weak the] in
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.TRE_GO_THE) {
                guard let the else { return }
                // Thẻ ĐANG CHỜ NGƯỜI thì KHÔNG gỡ. "Xong" ở đây nghĩa là mọi nút đã chạy đều
                // kết thúc — nhưng một chuỗi dừng ở bước 3 để hỏi cũng thoả điều kiện ấy, và gỡ
                // nó đi là xoá đúng câu hỏi đang đợi người trả lời.
                if the.choNguoi { return }
                self?.theTienDo.removeValue(forKey: id)
                self?.hoiThoai.goThe(the)
                self?._chieuDangChay()
            }
        }
        theTienDo[id] = the
        hoiThoai.themThe(the)
        _chieuDangChay()
        // §2D.2a: một Run bắt đầu thì vùng trao đổi về mức chuẩn — đúng lúc ấy có thứ mới để
        // đọc, và một thẻ Run nằm trong một vùng cao 48 pt là một thẻ không ai thấy.
        if caoHoiThoai == .thuGon { datCaoHoiThoai(.chuan) }
        // ĐƯA thông điệp tạo ra thẻ VÀO thẻ. `init` chỉ gọi `capNhat([:])`, nên trước đây thông
        // điệp ĐẦU TIÊN — thông điệp duy nhất mang `cap`, và đôi khi là thông điệp duy nhất của
        // cả lượt chạy — bị vứt. Hệ quả đo 16/09/2026 qua giao diện: năm thẻ cùng lúc, cả năm ghi
        // "Đang chạy 7d173eec3fc0…" và KHÔNG thẻ nào biến mất, vì trạng thái `done`/`failed` nằm
        // trong chính thông điệp đã bị bỏ. Một lượt chạy xong mà giao diện vẫn nói đang chạy là
        // lời nói sai về việc máy vừa làm — đúng thứ màn giám sát tồn tại để không xảy ra.
        the.capNhat(p)
    }

    /// Hiện một thẻ câu hỏi gộp — UXD-13 U3, từ sự kiện `event.chat.question`.
    public func hienCauHoi(_ p: [String: Any]) {
        let pa = (p["options"] as? [[String: Any]] ?? []).map {
            QuestionCard.PhuongAn(nhan: $0["label"] as? String ?? "?",
                                  giaTri: String(describing: $0["value"] ?? ""))
        }
        guard !pa.isEmpty else { return }
        let the = QuestionCard(cauHoi: p["text"] as? String ?? "Anh chọn giúp?",
                               phuongAn: pa,
                               macDinh: p["default"] as? Int ?? 0,
                               timeoutS: p["timeout_s"] as? Int ?? 120,
                               ghiNho: p["remember_as"] as? String)
        let qid = p["question_id"] as? String ?? ""
        the.onTraLoi = { [weak self] giaTri, hetGio in
            Task { _ = try? await self?.client.goi(.chatAnswer,
                                                   ["question_id": qid, "option": giaTri,
                                                    "by_timeout": hetGio]) }
        }
        hoiThoai.themThe(the)
    }

    /// Đọc lại trạng thái từ daemon. Panel không giữ bản sao nào (GPI-23 §1).
    /// Người đổi mức tự chủ — API-15 §2 `autonomy.set`, APD-08 §2.
    ///
    /// Gọi rồi **đọc lại** bằng `lamMoi()`, không tự đặt nhãn: mức CÓ HIỆU LỰC do daemon tính
    /// (dự án → board → loại hành động, POL-17 §5), nên thứ người chọn và thứ thật sự có hiệu
    /// lực có thể khác nhau. Đặt nhãn theo lựa chọn là hứa một điều chưa chắc xảy ra.
    ///
    /// Lỗi thì NÓI RA. Một lệnh đổi chính sách mà thất bại trong im lặng là trường hợp xấu nhất
    /// của cả nhóm này: người dùng tin rằng họ vừa siết hoặc vừa nới quyền của tác tử, và không
    /// điều nào trong hai điều ấy xảy ra.
    private func doiMucTuChu(_ muc: String) {
        Task {
            do {
                _ = try await client.goi(.autonomySet, ["level": muc])
            } catch {
                await MainActor.run {
                    hoiThoai.themLuot(by: .loi,
                                      text: "Không đổi được mức tự chủ sang \(muc): \(error)")
                }
            }
            await lamMoi()
        }
    }

    private func lamMoi() async {
        await napGoiY()
        let tuChu = try? await client.goi(.autonomyGet, [:])
        let doi = try? await client.goi(.queueList, [:])
        // `undo.list` từng ném E1000 vì một bản ghi sổ cái CŨ thiếu trường `cap` — và `try?`
        // biến lỗi ấy thành một danh sách rỗng, nên vùng "Hoàn tác được" trống mà không ai
        // biết vì sao. Bắt riêng để NÓI RA. Xem lỗi im lặng số 34.
        var undo: [String: Any]?
        var loiUndo: String?
        do { undo = try await client.goi(.undoList, [:]) }
        catch { loiUndo = "\(error)" }
        await MainActor.run {
            if let loiUndo {
                self.hoiThoai.themLuot(by: .loi,
                                       text: "Không đọc được danh sách hoàn tác: \(loiUndo)")
            }
            // `autonomy.get` thất bại KHÁC với mức tự chủ chưa đặt. Nhãn "—" cho cả hai là để
            // người dùng nhìn một dấu gạch mà không biết tác tử đang được phép làm gì.
            if tuChu == nil {
                self.hoiThoai.themLuot(by: .loi,
                                       text: "Không đọc được mức tự chủ — daemon còn chạy không?")
            }
            self.thanhTuChu.capNhat(muc: tuChu?["autonomy"] as? String,
                                    dungKhan: tuChu?["stopped"] as? Bool ?? false,
                                    soCho: (doi?["items"] as? [[String: Any]])?.count ?? 0,
                                    soHoanTac: (undo?["items"] as? [[String: Any]])?.count ?? 0)
            self.hangDoi.capNhat(cho: doi?["items"] as? [[String: Any]] ?? [],
                                 hoanTac: undo?["items"] as? [[String: Any]] ?? [])
            // Hàng đợi rỗng thì tắt băng leo thang. Người vừa duyệt xong mục cuối mà băng
            // "ĐANG CHỜ ANH" vẫn đỏ trên đầu màn hình là một cảnh báo không tắt — và một cảnh
            // báo không tắt thì lần sau người ta không đọc nữa.
            if (doi?["items"] as? [[String: Any]])?.isEmpty ?? true {
                self.thanhTuChu.leoThang(nil)
            }
        }
    }
}
