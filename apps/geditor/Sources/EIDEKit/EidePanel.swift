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
    private let thanhMan = NSStackView()
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
        "XungDot", "LamRo", "NhatKy",
    ]

    /// id năng lực → tên màn hình, lấy từ `caps.list` (daemon suy từ bảng UXD-13 §2).
    private var manHinhCua: [String: String] = [:]

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
                let r = try await client.goi(.capsInvoke, ["id": id, "params": params])
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

    /// Lỗi của một CapabilityRun thành một câu người đọc được.
    ///
    /// E2000 (`GROUNDING_FAILED`) chiếm phần lớn lỗi mà một màn vừa mở gặp phải: năng lực cần
    /// một dự án có store, và dự án vừa tạo thì chưa có. Đó KHÔNG phải hỏng — đó là thứ tự
    /// công việc. Hiện nó dưới dạng lỗi đỏ là dạy người dùng rằng phần mềm này hay lỗi.
    static func docLoi(_ r: [String: Any]) -> String {
        guard let e = r["error"] as? [String: Any] else {
            return "chưa chạy được (trạng thái \((r["status"] as? String) ?? "?"))."
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
        hoiThoai.isHidden = true
        thanhMan.isHidden = false
        tenMan.stringValue = ten
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
    /// - **FlowMap** khai `nang_luc: []` — cố ý, nó hiện trạng thái của chính dòng công việc
    ///   chứ không hiện kết quả của một năng lực nào.
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
        _moTheoTenMan(tien, thamSo: thamSo)
    }

    /// Đóng màn chuyên đề, quay về hội thoại.
    public func dongManChuyenDe() { dongMan() }

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
        hoiThoai.isHidden = true
        thanhMan.isHidden = false
        // Nhãn người đọc được, không phải tiền tố kỹ thuật: người bấm "Dò board" mà thấy
        // tiêu đề "Discovery" phải tự dịch trong đầu, và hai chữ ấy không phải lúc nào cũng
        // giống nhau ("LamRo" → "Làm rõ yêu cầu").
        tenMan.stringValue = EideDieuHuong.NHOM
            .flatMap(\.man).first { $0.tien == k.tien }?.nhan ?? k.tien
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
            let v = khungCua(k.tien, id: cap) ?? k.v
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

    @objc private func dongMan() {
        for k in bangMan { k.v.isHidden = true }
        banDo.isHidden = true
        thanhMan.isHidden = true
        hoiThoai.isHidden = false
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
        } else {
            hoiThoai.themLuot(by: .cho, text: "Đã hiểu \(y), chưa dựng được chuỗi việc.")
        }
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
            hoiThoai.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            hoiThoai.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor, constant: -g),
            hoiThoai.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -g),
            hoiThoai.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),

            thanhMan.topAnchor.constraint(equalTo: thanhTuChu.bottomAnchor, constant: g),
            thanhMan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),

            oNhap.topAnchor.constraint(equalTo: thanhMan.bottomAnchor, constant: g),
            oNhap.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            oNhap.trailingAnchor.constraint(lessThanOrEqualTo: vungPhai.leadingAnchor,
                                            constant: -g),
        ])

        // Mọi màn chuyên đề dùng ĐÚNG một khung: cột giữa, từ dưới thanh tiêu đề màn xuống tới
        // trên ô lệnh. Cùng khung thì không màn nào âm thầm rộng hơn màn khác.
        for k in bangMan.map(\.v) + [banDo] {
            NSLayoutConstraint.activate([
                k.topAnchor.constraint(equalTo: oNhap.bottomAnchor, constant: g),
                k.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
                k.trailingAnchor.constraint(equalTo: vungPhai.leadingAnchor, constant: -g),
                k.bottomAnchor.constraint(equalTo: hoiThoai.topAnchor, constant: -g),
            ])
        }
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
    private func moManHinh(id: String, thamSo: String) {
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

        await MainActor.run {
            self.manHinhCua = bang
            self.hoiThoai.oLenh.napNangLuc(ds + themMan)
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
            // "Bảng lệnh: tìm năng lực/màn hình" — chính là menu "/" của ô lệnh, nên ⌘K điền
            // sẵn dấu gạch chéo thay vì dựng một bảng thứ hai làm cùng một việc.
            hoiThoai.oLenh.dienSan("/")
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
        theTienDo[id] = the
        hoiThoai.themThe(the)
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
