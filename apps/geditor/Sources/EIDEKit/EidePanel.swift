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

    public init(client: EideClient) {
        self.client = client
        super.init(frame: .zero)
        dungGiaoDien()
        hoiThoai.onGui = { [weak self] text in self?.gui(text) }
        thanhTuChu.onDungKhan = { [weak self] in self?.dungKhan() }
        Task { await lamMoi() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("dùng init(client:)") }

    private func dungGiaoDien() {
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.bg.cgColor
        for v in [thanhTuChu, hoiThoai, hangDoi] {
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
        ])
    }

    // MARK: - hành động

    /// U1: ô lệnh là giao diện chính. Lệnh đi qua `chat.parse_intent` như mọi đường vào khác —
    /// panel không tự hiểu lệnh, vì GPI-23 §1 nói nó là client thuần.
    private func gui(_ text: String) {
        hoiThoai.themLuot(by: .nguoi, text: text)
        Task {
            do {
                let r = try await client.goi(.capsInvoke,
                                             ["id": "chat.parse_intent", "params": ["text": text]])
                await MainActor.run { self.hienKetQua(r) }
            } catch {
                await MainActor.run { self.hienLoi(error) }
            }
            await lamMoi()
        }
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

    /// Đọc lại trạng thái từ daemon. Panel không giữ bản sao nào (GPI-23 §1).
    private func lamMoi() async {
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
