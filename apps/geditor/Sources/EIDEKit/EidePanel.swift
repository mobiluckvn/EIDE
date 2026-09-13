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
    private let hangDoi = ReviewQueueView()

    // Các màn chuyên đề của UXD-13 §2. Chúng chiếm chỗ hội thoại chứ không đè lên thanh tự chủ
    // hay hàng đợi: U2 nói hai thứ ấy LUÔN hiện, kể cả khi người đang đọc một màn khác — nhất
    // là lúc ấy, vì đó là lúc tác tử vẫn đang chạy sau lưng.
    private let hoChieu = PassportView()
    private let hoiDap = RagAskView()
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
    private lazy var bangMan: [(tien: String, v: NSView)] = [
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
    ]

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
    ]

    /// id năng lực → tên màn hình, lấy từ `caps.list` (daemon suy từ bảng UXD-13 §2).
    private var manHinhCua: [String: String] = [:]

    public init(client: EideClient) {
        self.client = client
        super.init(frame: .zero)
        dungGiaoDien()
        noiHangDoi()
        noiManChuyenDe()
        hoiThoai.onGui = { [weak self] text in self?.gui(text) }
        thanhTuChu.onDungKhan = { [weak self] in self?.dungKhan() }
        Task { await lamMoi() }
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
                      _ xong: @escaping ([String: Any]) -> Void) {
        Task {
            do {
                let r = try await client.goi(.capsInvoke, ["id": id, "params": params])
                await MainActor.run {
                    if (r["status"] as? String) == "done" {
                        xong((r["result"] as? [String: Any]) ?? [:])
                    } else {
                        self.hienKetQua(r)
                    }
                }
            } catch {
                await MainActor.run { self.hienLoi(error) }
            }
            await lamMoi()
        }
    }

    private func khungCua(_ man: String) -> NSView? {
        bangMan.first { man.hasPrefix($0.tien) }?.v
    }

    /// Mở một màn chuyên đề: nó chiếm chỗ hội thoại, thanh tự chủ và hàng đợi ở nguyên.
    private func hienKhung(_ v: NSView, ten: String, thamSo: String) {
        for k in bangMan { k.v.isHidden = (k.v !== v) }
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
    }

    @objc private func dongMan() {
        for k in bangMan { k.v.isHidden = true }
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

        for v in [thanhTuChu, hoiThoai, hangDoi, thanhMan] as [NSView] + bangMan.map(\.v) {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let g = EideToken.contentGap
        NSLayoutConstraint.activate([
            thanhTuChu.topAnchor.constraint(equalTo: topAnchor),
            thanhTuChu.leadingAnchor.constraint(equalTo: leadingAnchor),
            thanhTuChu.trailingAnchor.constraint(equalTo: trailingAnchor),
            thanhTuChu.heightAnchor.constraint(equalToConstant: EideToken.statusbarHeight + 8),

            hoiThoai.topAnchor.constraint(equalTo: thanhTuChu.bottomAnchor, constant: g),
            hoiThoai.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            hoiThoai.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -g),

            hangDoi.topAnchor.constraint(equalTo: hoiThoai.bottomAnchor, constant: g),
            hangDoi.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            hangDoi.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -g),
            hangDoi.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -g),
            hangDoi.heightAnchor.constraint(equalToConstant: 120),

            thanhMan.topAnchor.constraint(equalTo: thanhTuChu.bottomAnchor, constant: g),
            thanhMan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
        ])

        // Mọi màn chuyên đề dùng ĐÚNG khung của hội thoại, chỉ lùi xuống dưới thanh tiêu đề
        // màn. Cùng khung thì không màn nào âm thầm rộng hơn màn khác rồi che mất hàng đợi.
        for k in bangMan.map(\.v) {
            NSLayoutConstraint.activate([
                k.topAnchor.constraint(equalTo: thanhMan.bottomAnchor, constant: g),
                k.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
                k.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -g),
                k.bottomAnchor.constraint(equalTo: hangDoi.topAnchor, constant: -g),
            ])
        }
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
        guard let man = manHinhCua[id] else {
            // U9: lỗi phải nói được hành động tiếp theo. Một id gõ sai không được im lặng.
            hoiThoai.themLuot(by: .loi,
                              text: "Không có năng lực `\(id)` có màn hình. Gõ \"/\" để xem danh sách.")
            return
        }
        guard let v = khungCua(man) else {
            hoiThoai.themLuot(by: .heThong,
                              text: "Màn \"\(man)\" chưa dựng — `\(id)` thuộc màn ấy. "
                                  + "Ba màn đã có: Passport, Graph → RagAsk, Doc.")
            return
        }
        hienKhung(v, ten: man, thamSo: thamSo)
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
            let intent = ((r["result"] as? [String: Any])?["intent"] as? [String: Any])
            let ten = intent?["intent"] as? String ?? "?"
            let tin = intent?["confidence"] as? Double ?? 0
            hoiThoai.themLuot(by: .tacTu, text: "Tôi hiểu là: \(ten) (tin cậy \(Int(tin * 100))%).")
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
        await MainActor.run {
            self.manHinhCua = bang
            self.hoiThoai.oLenh.napNangLuc(ds)
        }
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
    private func lamMoi() async {
        await napGoiY()
        let tuChu = try? await client.goi(.autonomyGet, [:])
        let doi = try? await client.goi(.queueList, [:])
        let undo = try? await client.goi(.undoList, [:])
        await MainActor.run {
            self.thanhTuChu.capNhat(muc: tuChu?["autonomy"] as? String,
                                    dungKhan: tuChu?["stopped"] as? Bool ?? false,
                                    soCho: (doi?["items"] as? [[String: Any]])?.count ?? 0,
                                    soHoanTac: (undo?["items"] as? [[String: Any]])?.count ?? 0)
            self.hangDoi.capNhat(cho: doi?["items"] as? [[String: Any]] ?? [],
                                 hoanTac: undo?["items"] as? [[String: Any]] ?? [])
        }
    }
}
