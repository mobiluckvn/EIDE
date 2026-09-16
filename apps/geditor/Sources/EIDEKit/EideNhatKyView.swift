import AppKit

/// **Nhật ký hoạt động** — dòng thời gian mọi việc tác tử làm, bất kể nó chạy ở đâu.
///
/// Spec: API-15 §1 (`event.*`), §5 (`ledger_events.json` — 26 kiểu sự kiện); SEC-25 §3 (sổ cái
/// chỉ-thêm có chuỗi băm); GIAM-SAT-UI §G7.
///
/// ## Vì sao màn này phải tồn tại
///
/// Trước 14/09/2026 **không màn nào trả lời được câu "tác tử vừa làm gì"**. 23 màn hình của
/// UXD-13 đều là màn CHUYÊN ĐỀ: hộ chiếu hiện fact, mô phỏng hiện kết quả chạy, mã nguồn hiện
/// bản vá. Mỗi màn trả lời tốt câu hỏi của nó, và không màn nào trả lời câu hỏi bắc ngang —
/// mà đó lại là câu hỏi đầu tiên của người ngồi giám sát.
///
/// Nguồn dữ liệu là **sổ cái**, không phải một danh sách sự kiện panel tự gom. Khác biệt ấy
/// quan trọng: sổ cái là chuỗi băm chỉ-thêm, nên một dòng trên màn này là một dòng ĐÃ NẰM
/// TRONG BẰNG CHỨNG. Không có đường nào để giao diện hiện một việc mà sổ cái không có, và cũng
/// không có đường nào để một việc đã làm không hiện lên đây.
///
/// ## Ba trạng thái, không phải hai
///
/// Màn rỗng có ba nghĩa khác nhau và phải nói ra được cả ba: *chưa mở dự án nào*, *dự án này
/// chưa có việc gì*, và *có việc nhưng bộ lọc đang giấu hết*. Gộp chúng thành một câu "không có
/// gì" là để người dùng tự đoán — đúng thứ lỗi im lặng số 21 đã mắc ở tầng UI.
public final class NhatKyView: NSView, KhungNhinEide {

    /// Một dòng nhật ký, đã dịch sang thứ người đọc được.
    struct Dong {
        let luc: String
        let loai: String
        let nhan: String
        let chiTiet: String
        let mau: NSColor
        let boi: String        // "tác tử" | "người"
        let capId: String?     // để bấm-mở-màn-chuyên-đề
    }

    private let tieuDe = NSTextField(labelWithString: "Nhật ký hoạt động")
    private let tomTat = NSTextField(labelWithString: "")
    private let bangLoc = NSSegmentedControl()
    private let bang = NSTableView()
    private let cuon = NSScrollView()

    private var tatCa: [Dong] = []
    private var hienThi: [Dong] = []

    /// Bấm một dòng → mở màn chuyên đề tương ứng. Panel nối vào đây.
    public var onMoMan: ((String) -> Void)?

    /// Giữ tối đa ngần này dòng trong bộ nhớ.
    ///
    /// `extract.svd` của ESP32-C3 ghi hơn 8.000 `store.write` trong một lượt; giữ hết thì màn
    /// này ăn hết bộ nhớ của một cửa sổ mà không ai cuộn tới dòng thứ 2.000. Cắt từ ĐẦU (cũ
    /// nhất) vì dòng thời gian đọc từ mới xuống cũ.
    static let TOI_DA = 2_000

    /// Nhóm lọc — gom 26 kiểu sổ cái thành sáu thứ người dùng thật sự hỏi.
    static let NHOM: [(ten: String, kinds: Set<String>)] = [
        ("Tất cả", []),
        ("Năng lực", ["cap.run.start", "cap.run.finish"]),
        ("Cổng", ["gate.decision", "gate.human", "policy.escalate", "policy.sign",
                  "autonomy.change", "stop"]),
        ("Tri thức", ["store.write", "store.migrate", "acq.state"]),
        ("Công cụ", ["tool.report"]),
        ("Mô hình", ["model.call"]),
    ]

    public override init(frame: NSRect) {
        super.init(frame: frame)
        dung()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung() {
        tieuDe.font = EideToken.fontUI
        tieuDe.textColor = EideToken.Mau.text
        tomTat.font = EideToken.fontUI
        tomTat.textColor = EideToken.Mau.muted
        tomTat.stringValue = "Chưa mở dự án nào."

        bangLoc.segmentCount = Self.NHOM.count
        for (i, n) in Self.NHOM.enumerated() {
            bangLoc.setLabel(n.ten, forSegment: i)
        }
        bangLoc.selectedSegment = 0
        bangLoc.target = self
        bangLoc.action = #selector(doiLoc)
        bangLoc.setAccessibilityLabel("Lọc nhật ký theo nhóm")

        bang.headerView = nil
        bang.rowHeight = 22
        bang.backgroundColor = EideToken.Mau.surface
        bang.dataSource = self
        bang.delegate = self
        bang.setAccessibilityLabel("Dòng thời gian hoạt động")
        let cot = NSTableColumn(identifier: .init("dong"))
        cot.width = 900
        bang.addTableColumn(cot)

        cuon.documentView = bang
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false

        for v in [tieuDe, tomTat, bangLoc, cuon] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let g = EideToken.space[2]
        NSLayoutConstraint.activate([
            tieuDe.topAnchor.constraint(equalTo: topAnchor, constant: g),
            tieuDe.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),

            bangLoc.centerYAnchor.constraint(equalTo: tieuDe.centerYAnchor),
            bangLoc.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -g),
            bangLoc.leadingAnchor.constraint(greaterThanOrEqualTo: tieuDe.trailingAnchor,
                                             constant: g),

            tomTat.topAnchor.constraint(equalTo: tieuDe.bottomAnchor, constant: 4),
            tomTat.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            tomTat.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -g),

            cuon.topAnchor.constraint(equalTo: tomTat.bottomAnchor, constant: g),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -g),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -g),
        ])
    }

    // MARK: - Nhận sự kiện

    /// Một `event.*` từ daemon → một dòng nhật ký.
    ///
    /// Nhận THÔ và dịch tại đây, không nhờ panel lọc trước: màn này là chỗ duy nhất muốn thấy
    /// mọi thứ, và mọi nơi khác đều chỉ quan tâm một lát cắt.
    @MainActor
    public func them(_ ten: String, _ p: [String: Any]) {
        guard let d = Self.dich(ten, p) else { return }
        tatCa.append(d)
        if tatCa.count > Self.TOI_DA {
            tatCa.removeFirst(tatCa.count - Self.TOI_DA)
        }
        locLai()
    }

    /// `event.*` + payload → dòng hiển thị, hoặc nil nếu không phải thứ đáng ghi.
    ///
    /// Hàm tĩnh và thuần để test được mà không dựng cửa sổ — đây là chỗ dễ sai nhất của cả màn,
    /// vì nó phải đọc payload của 20 loại sự kiện khác nhau.
    static func dich(_ ten: String, _ p: [String: Any]) -> Dong? {
        let luc = gioPhut((p["at"] as? String) ?? "")
        let kind = (p["kind"] as? String) ?? ten
        let boi = ((p["actor"] as? String) == "human") ? "người" : "tác tử"
        let cap = p["cap"] as? String

        switch ten {
        case "event.run.progress":
            let ten_nl = cap ?? (p["node_id"] as? String) ?? "?"
            let tt = (p["status"] as? String) ?? (p["state"] as? String)
            // `cap.run.start` không có `status`; `finish` thì có. Phân biệt bằng chính điều ấy
            // thay vì bằng `kind`, vì một ngày nào đó `event.job.progress` cũng vào đây.
            if let tt {
                let ok = (tt == "done")
                return Dong(luc: luc, loai: "năng lực",
                            nhan: ten_nl,
                            chiTiet: ok ? "xong" : tt + (loiNgan(p).map { " · \($0)" } ?? ""),
                            mau: ok ? EideToken.Mau.ok : EideToken.Mau.bad,
                            boi: boi, capId: ten_nl)
            }
            return Dong(luc: luc, loai: "năng lực", nhan: ten_nl, chiTiet: "bắt đầu",
                        mau: EideToken.Mau.muted, boi: boi, capId: ten_nl)

        case "event.gate.decided":
            let qd = (p["decision"] as? String) ?? "?"
            return Dong(luc: luc, loai: "cổng",
                        nhan: "\(qd) · \((p["rule"] as? String) ?? "?")",
                        chiTiet: (p["reason"] as? String) ?? "",
                        mau: qd == "REJECT" ? EideToken.Mau.bad : EideToken.Mau.muted,
                        boi: boi, capId: p["action_cap"] as? String)

        case "event.gate.opened":
            return Dong(luc: luc, loai: "cổng",
                        nhan: "CHỜ NGƯỜI · \((p["rule"] as? String) ?? (p["gate"] as? String) ?? "?")",
                        chiTiet: (p["reason"] as? String) ?? (p["summary"] as? String) ?? "",
                        mau: EideToken.Mau.warn, boi: boi, capId: p["action_cap"] as? String)

        case "event.model.call":
            let vao = EideSo.nguyen(p["tokens_in"]) ?? 0
            let ra = EideSo.nguyen(p["tokens_out"]) ?? 0
            var ct = "\(vao) vào · \(ra) ra"
            if let usd = EideSo.thuc(p["cost_usd"]) { ct += String(format: " · $%.4f", usd) }
            return Dong(luc: luc, loai: "mô hình",
                        nhan: (p["role"] as? String) ?? (p["model"] as? String) ?? "mô hình",
                        chiTiet: ct, mau: EideToken.Mau.info, boi: boi, capId: "Models")

        case "event.tool.report":
            let dat = (p["passed"] as? Bool) ?? false
            var ct = dat ? "đạt" : "hỏng"
            if let ms = EideSo.nguyen(p["duration_ms"]) { ct += " · \(ms) ms" }
            return Dong(luc: luc, loai: "công cụ",
                        nhan: (p["tool"] as? String) ?? "công cụ",
                        chiTiet: ct, mau: dat ? EideToken.Mau.ok : EideToken.Mau.bad,
                        boi: boi, capId: "Env")

        case "event.knowledge.changed":
            // `store.write` là sự kiện ồn nhất của cả hệ thống — một lượt `extract.svd` ghi hàng
            // nghìn dòng. Gộp bằng cách hiện BẢNG và SỐ, không hiện từng bản ghi.
            let bang = (p["table"] as? String) ?? "store"
            let n = EideSo.nguyen(p["n"]) ?? EideSo.nguyen(p["facts_added"])
            return Dong(luc: luc, loai: "tri thức", nhan: bang,
                        chiTiet: n.map { "\($0) bản ghi" } ?? "đã ghi",
                        mau: EideToken.Mau.muted, boi: boi, capId: "Graph")

        case "event.autonomy.changed":
            return Dong(luc: luc, loai: "tự chủ",
                        nhan: (p["effective"] as? String) ?? "đổi mức",
                        chiTiet: (p["reason"] as? String) ?? "", mau: EideToken.Mau.warn,
                        boi: boi, capId: nil)

        case "event.notice":
            let muc = (p["level"] as? String) ?? "info"
            return Dong(luc: luc, loai: kind == "policy.escalate" ? "leo thang" : "thông báo",
                        nhan: kind == "policy.escalate" ? "TÁC TỬ CẦN NGƯỜI" : muc,
                        chiTiet: (p["text"] as? String) ?? (p["message"] as? String) ?? "",
                        mau: muc == "error" ? EideToken.Mau.bad : EideToken.Mau.warn,
                        boi: boi, capId: nil)

        case "event.queue.changed":
            // `gate.human` đi vào đây: người vừa duyệt hay từ chối một mục.
            guard kind == "gate.human" else { return nil }
            return Dong(luc: luc, loai: "cổng",
                        nhan: "người \((p["decision"] as? String) == "REJECT" ? "TỪ CHỐI" : "duyệt")",
                        chiTiet: (p["note"] as? String) ?? "", mau: EideToken.Mau.ok,
                        boi: "người", capId: nil)

        case "event.undo.registered":
            return Dong(luc: luc, loai: "hoàn tác",
                        nhan: (p["kind"] as? String) ?? "việc đã làm",
                        chiTiet: (p["deadline"] as? String).map { "hạn \(gioPhut($0))" } ?? "",
                        mau: EideToken.Mau.muted, boi: boi, capId: nil)

        case "event.project.changed":
            return Dong(luc: luc, loai: "dự án",
                        nhan: (p["id"] as? String) ?? "dự án",
                        chiTiet: (p["state"] as? String) ?? "", mau: EideToken.Mau.info,
                        boi: boi, capId: "Main")

        case "event.chat.intent":
            let caps = (p["caps"] as? [Any])?.compactMap { $0 as? String } ?? []
            return Dong(luc: luc, loai: "ý định",
                        nhan: (p["text"] as? String) ?? "hiểu yêu cầu",
                        chiTiet: caps.isEmpty ? "" : caps.joined(separator: " → "),
                        mau: EideToken.Mau.info, boi: boi, capId: nil)

        default:
            return nil
        }
    }

    private static func loiNgan(_ p: [String: Any]) -> String? {
        if let e = p["error"] as? String { return e }
        if let e = p["error"] as? [String: Any] { return e["eide_code"] as? String }
        return nil
    }

    /// `2026-09-14T07:42:06.162717+00:00` → `14:42:06` (giờ máy).
    ///
    /// Sổ cái ghi UTC vì nó là bằng chứng và múi giờ làm bằng chứng khó đối chiếu. Người đọc
    /// màn này thì đang ngồi trước máy, và "việc ấy xảy ra lúc mấy giờ" là giờ của họ.
    static func gioPhut(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var d = f.date(from: iso)
        if d == nil {
            f.formatOptions = [.withInternetDateTime]
            d = f.date(from: iso)
        }
        guard let d else { return String(iso.prefix(19).suffix(8)) }
        let ra = DateFormatter()
        ra.dateFormat = "HH:mm:ss"
        return ra.string(from: d)
    }

    // MARK: - Lọc và vẽ

    @objc private func doiLoc() { locLai() }

    private func locLai() {
        let nhom = Self.NHOM[max(0, min(bangLoc.selectedSegment, Self.NHOM.count - 1))]
        hienThi = nhom.kinds.isEmpty ? tatCa : tatCa.filter { thuocNhom($0, nhom.kinds) }
        capNhatTomTat(daLoc: !nhom.kinds.isEmpty)
        bang.reloadData()
        if !hienThi.isEmpty {
            bang.scrollRowToVisible(hienThi.count - 1)
        }
    }

    private func thuocNhom(_ d: Dong, _ kinds: Set<String>) -> Bool {
        // Khớp theo NHÃN LOẠI đã dịch, không theo `kind` thô: một dòng "năng lực" có thể đến từ
        // `cap.run.start` hay `cap.run.finish`, và người lọc nghĩ theo nhóm chứ không theo tên
        // kỹ thuật.
        switch d.loai {
        case "năng lực": return kinds.contains("cap.run.start")
        case "cổng", "tự chủ", "leo thang": return kinds.contains("gate.decision")
        case "tri thức": return kinds.contains("store.write")
        case "công cụ": return kinds.contains("tool.report")
        case "mô hình": return kinds.contains("model.call")
        default: return false
        }
    }

    /// Ba trạng thái rỗng khác nhau — xem docstring của lớp.
    private func capNhatTomTat(daLoc: Bool) {
        if tatCa.isEmpty {
            tomTat.stringValue = chuaCoDuAn
                ? "Chưa mở dự án nào — Tệp → Mở dự án EIDE…"
                : "Dự án đã mở nhưng chưa có việc nào được ghi vào sổ cái."
            tomTat.textColor = EideToken.Mau.muted
            return
        }
        if hienThi.isEmpty && daLoc {
            tomTat.stringValue = "\(tatCa.count) việc trong sổ, nhưng bộ lọc đang giấu hết — "
                + "chọn \"Tất cả\" để xem."
            tomTat.textColor = EideToken.Mau.warn
            return
        }
        let nguoi = hienThi.filter { $0.boi == "người" }.count
        tomTat.stringValue = "\(hienThi.count) việc"
            + (daLoc ? " (lọc từ \(tatCa.count))" : "")
            + (nguoi > 0 ? " · \(nguoi) do người quyết" : "")
        tomTat.textColor = EideToken.Mau.muted
    }

    private var chuaCoDuAn = true

    /// Panel gọi khi biết dự án đã mở hay chưa — quyết định câu nào trong hai câu rỗng.
    @MainActor
    public func datCoDuAn(_ co: Bool) {
        chuaCoDuAn = !co
        if tatCa.isEmpty { capNhatTomTat(daLoc: false) }
    }

    /// Câu tóm tắt đang hiện — ba trạng thái rỗng phân biệt được từ ngoài.
    ///
    /// Đây là toàn bộ nội dung người dùng đọc khi màn không có dòng nào, nên nó là bề mặt đáng
    /// kiểm chứ không phải chi tiết bên trong.
    @MainActor
    public var tomTatText: String { tomTat.stringValue }

    /// Số dòng đang giữ trong bộ nhớ — khác số dòng đang hiện khi có bộ lọc.
    @MainActor
    public var soDongDeTest: Int { tatCa.count }

    /// Số dòng dữ liệu đang hiện, theo `KhungNhinEide` — với nhật ký là số MỐC đã nhận.
    public var soDong: Int { tatCa.count }

    /// Chọn nhóm lọc theo TÊN. Dùng cho test và cho lệnh `/nhật ký <nhóm>` về sau.
    @MainActor
    public func chonNhomDeTest(_ ten: String) {
        guard let i = Self.NHOM.firstIndex(where: { $0.ten == ten }) else { return }
        bangLoc.selectedSegment = i
        locLai()
    }

    // MARK: - KhungNhinEide

    /// Nạp lịch sử từ `view.timeline` (VIEW-12, `ref: memory.ledger`).
    ///
    /// **Lịch sử đi bằng đường hỏi-đáp, không bằng kênh đẩy.** Bản đầu cho daemon tự phát lại
    /// 200 bản ghi lúc mở, và nó treo daemon: stdio là ống có đệm hữu hạn (64 KB trên macOS),
    /// còn client chỉ đọc khi đang chờ trả lời một lời gọi — nên phát một khối lớn trước khi
    /// client gửi gì là ghi vào ống không ai đọc. Đo được: dự án ESP32-C3 ≈ 82 KB, vượt ngưỡng,
    /// cửa sổ mở lên rồi đứng im không báo gì.
    ///
    /// Kênh đẩy giữ đúng việc của nó: sự kiện thời gian thực, ít và rải rác.
    public func capNhat(ketQua: [String: Any]) {
        // `[Any]` rồi lọc từng phần tử, KHÔNG `as? [[String: Any]]`: cast cả mảng thất bại nếu
        // **một** phần tử sai kiểu, và khi ấy cả lô biến mất. Một bản ghi hỏng trong sổ cái là
        // chuyện có thật (ghi dở, đĩa lỗi) — mất một dòng thì chấp nhận được, mất cả phiên làm
        // việc thì không.
        guard let tho = ketQua["events"] as? [Any] else {
            // Không có `events` nghĩa là năng lực khác trả về, không phải "không có lịch sử".
            // Im lặng xoá dòng thời gian ở đây là xoá đúng thứ người đang đọc.
            return
        }
        let ds = tho.compactMap { $0 as? [String: Any] }
        tatCa.removeAll()
        for e in ds.suffix(Self.TOI_DA) {
            // `view.timeline` trả bản ghi SỔ CÁI thô (`kind` + `data`), còn `dich()` đọc payload
            // của `event.*`. Quy về một dạng ở đây, thay vì dạy `dich()` hai ngôn ngữ.
            guard let kind = e["kind"] as? String else { continue }
            var p = (e["data"] as? [String: Any]) ?? [:]
            p["kind"] = kind
            p["at"] = e["at"]
            p["actor"] = e["by"] ?? p["actor"]
            if let d = Self.dich(Self.tenSuKien(kind), p) { tatCa.append(d) }
        }
        chuaCoDuAn = false
        locLai()
    }

    /// Kiểu sổ cái → tên `event.*`, khớp bảng `SU_KIEN` của daemon.
    ///
    /// Lặp lại bảng ấy ở đây là một bản sao, và bản sao thì trôi. Nhưng đường còn lại — bắt
    /// `view.timeline` trả tên sự kiện — là bắt một năng lực biết về giao thức của giao diện.
    /// Bản sao nhỏ và có test đối chiếu với `SU_KIEN` giữ nó khỏi trôi.
    static func tenSuKien(_ kind: String) -> String {
        switch kind {
        case "cap.run.start", "cap.run.finish": return "event.run.progress"
        case "gate.decision": return "event.gate.decided"
        case "gate.human": return "event.queue.changed"
        case "undo.register", "undo.apply": return "event.undo.registered"
        case "undo.expire": return "event.undo.expired"
        case "autonomy.change", "stop": return "event.autonomy.changed"
        case "policy.escalate", "policy.sign", "error": return "event.notice"
        case "store.write", "store.migrate", "acq.state": return "event.knowledge.changed"
        case "discover.result": return "event.discover.changed"
        case "project.state": return "event.project.changed"
        case "model.call": return "event.model.call"
        case "tool.report": return "event.tool.report"
        case "question": return "event.chat.question"
        case "answer": return "event.chat.restated"
        case "report": return "event.chat.report"
        case "intent": return "event.chat.intent"
        default: return "event.\(kind)"
        }
    }

    public func chuaNap(_ vi: String) {
        tomTat.stringValue = vi
        tomTat.textColor = EideToken.Mau.warn
    }
}

extension NhatKyView: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int { hienThi.count }

    public func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        guard row < hienThi.count else { return nil }
        let d = hienThi[row]
        let hop = NSTableCellView()

        let gio = NSTextField(labelWithString: d.luc)
        gio.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        gio.textColor = EideToken.Mau.muted

        let loai = NSTextField(labelWithString: d.loai)
        loai.font = EideToken.fontUI
        loai.textColor = EideToken.Mau.muted

        let nhan = NSTextField(labelWithString: d.nhan)
        nhan.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        nhan.textColor = d.mau

        let ct = NSTextField(labelWithString: d.chiTiet)
        ct.font = EideToken.fontUI
        ct.textColor = EideToken.Mau.text
        ct.lineBreakMode = .byTruncatingTail

        // Việc do NGƯỜI quyết phải phân biệt được ngay: đó là những dòng duy nhất trên màn này
        // mà ai đó đã đọc và đồng ý, và trộn chúng vào việc máy tự làm là xoá mất ranh giới ấy.
        let dau = NSTextField(labelWithString: d.boi == "người" ? "☑" : " ")
        dau.font = EideToken.fontUI
        dau.textColor = EideToken.Mau.ok

        for v in [gio, loai, nhan, ct, dau] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            hop.addSubview(v)
        }
        NSLayoutConstraint.activate([
            gio.leadingAnchor.constraint(equalTo: hop.leadingAnchor, constant: 4),
            gio.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            gio.widthAnchor.constraint(equalToConstant: 62),

            dau.leadingAnchor.constraint(equalTo: gio.trailingAnchor, constant: 2),
            dau.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            dau.widthAnchor.constraint(equalToConstant: 14),

            loai.leadingAnchor.constraint(equalTo: dau.trailingAnchor, constant: 4),
            loai.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            loai.widthAnchor.constraint(equalToConstant: 74),

            nhan.leadingAnchor.constraint(equalTo: loai.trailingAnchor, constant: 6),
            nhan.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            nhan.widthAnchor.constraint(lessThanOrEqualToConstant: 260),

            ct.leadingAnchor.constraint(equalTo: nhan.trailingAnchor, constant: 8),
            ct.centerYAnchor.constraint(equalTo: hop.centerYAnchor),
            ct.trailingAnchor.constraint(lessThanOrEqualTo: hop.trailingAnchor, constant: -6),
        ])
        return hop
    }

    public func tableViewSelectionDidChange(_ n: Notification) {
        let r = bang.selectedRow
        guard r >= 0, r < hienThi.count, let man = hienThi[r].capId else { return }
        onMoMan?(man)
    }
}
