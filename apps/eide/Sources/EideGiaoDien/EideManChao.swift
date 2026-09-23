import AppKit
import EideLoi

/// **Màn hình chào** — UXC-31 §3.1, trả lời phát hiện R2 của bản rà soát.
///
/// Workspace chưa có dự án nào thì TOÀN MÀN là màn này: một câu chào, một đoạn giải thích trạng
/// thái rỗng, một ô gợi ý, và ĐÚNG MỘT nút chính. Không menu, không cột phải.
///
/// ## Vì sao đúng một nút
///
/// Người vừa cài xong có đúng một việc phải làm. Mọi nút thứ hai ở màn này là một ngã rẽ họ
/// phải cân nhắc trước khi biết sản phẩm làm gì — và đó là chỗ người ta đóng ứng dụng lại.
///
/// Đây cũng là trạng thái rỗng lớn nhất của sản phẩm, nên nó phải theo đúng luật B5 như mọi
/// trạng thái rỗng khác: nói LÝ DO rỗng, rồi nói BƯỚC KẾ TIẾP.
public final class EideManChao: NSView {

    /// Người bấm tạo dự án, kèm câu mô tả họ vừa gõ (có thể rỗng) và THƯ MỤC lưu.
    ///
    /// `nil` = để lõi dùng workspace mặc định. Truyền chuỗi rỗng thay cho `nil` sẽ thành
    /// `--dir ""` và tạo dự án ở thư mục hiện hành của tiến trình — một chỗ người dùng không
    /// chọn và không đoán được.
    public var onTao: ((String, String?) -> Void)?

    private let o = NSTextField()
    private let nut = NSButton()
    private let nhanTt = NSTextField(labelWithString: "")
    private let nhanThuMuc = NSTextField(labelWithString: "")

    /// Thư mục người đã chọn; `nil` = workspace mặc định.
    public private(set) var thuMuc: String?

    /// Workspace mặc định — CÙNG đường dẫn `project_dir_default()` của `eide_core.paths`.
    ///
    /// Viết lại ở đây vì màn chào chạy TRƯỚC khi có daemon để hỏi, và câu "dự án sẽ nằm ở đâu"
    /// phải trả lời được ngay lúc ấy. Đây là BẢN SAO THỨ HAI của một hằng số, tức là một chỗ sẽ
    /// lệch: nếu `defaults.project_dir` đổi thì màn chào sẽ nói một đường và lõi ghi một nẻo.
    /// Rủi ro chấp nhận được vì người dùng chỉ đọc nó rồi bấm "Đổi…"; nếu `project_dir` thành
    /// thứ cấu hình được thật thì phải hỏi lõi, không sửa hằng số này.
    public static var macDinh: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("eide")
    }

    /// Đang tạo dự án hay không. Cửa duy nhất chặn bấm hai lần — `project.create` không phải
    /// lệnh bình thường: bấm đúp sinh hai thư mục, và cái thứ hai người dùng không biết là mình
    /// đã tạo.
    private var dangBan = false

    /// Câu gợi ý đang hiện — cho bài kiểm đọc.
    public private(set) var goiY = ""

    /// Ba lệnh mẫu CHẠY ĐƯỢC THẬT, xoay vòng (§3.4). Không phải ví dụ trừu tượng: mỗi câu là
    /// một dự án nhúng có thật, để người gõ theo mà không phải nghĩ.
    public static let MAU = [
        "robot hai bánh tự cân bằng trên ATmega328P",
        "đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART",
        "nhấp nháy LED và đo dòng tiêu thụ trên ESP32-C3",
    ]

    public init(goiY: String = MAU[0]) {
        self.goiY = goiY
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.bg.cgColor

        let chao = NSTextField(labelWithString: "Chào mừng đến EIDE")
        chao.font = NSFont.boldSystemFont(ofSize: 19)

        let ly = NSTextField(wrappingLabelWithString:
            "Chưa có dự án nào trong workspace. Đây là trạng thái rỗng có LÝ DO và BƯỚC KẾ TIẾP "
            + "— quy tắc của mọi màn trong EIDE.")
        ly.font = EideToken.fontUI
        ly.textColor = EideToken.Mau.muted

        let g = NSTextField(wrappingLabelWithString:
            "Bước kế tiếp: mô tả dự án bằng MỘT câu — ví dụ \"\(goiY)\".")
        g.font = EideToken.fontUI
        g.textColor = EideToken.Mau.faint

        o.placeholderString = goiY
        o.font = EideToken.fontUI
        o.target = self
        o.action = #selector(_tao)

        nut.title = "Tạo dự án đầu tiên"
        nut.target = self
        nut.action = #selector(_tao)
        nut.bezelStyle = .rounded
        nut.keyEquivalent = "\r"
        nut.font = NSFont.boldSystemFont(ofSize: 13)

        nhanTt.font = EideToken.fontUI
        nhanTt.textColor = EideToken.Mau.bad
        nhanTt.isHidden = true

        nutVanTao.target = self
        nutVanTao.action = #selector(_vanTao)
        nutVanTao.bezelStyle = .rounded
        nutVanTao.font = NSFont.boldSystemFont(ofSize: 12)
        nutVanTao.isHidden = true

        // ---- CHỖ LƯU dự án, nói ra TRƯỚC khi tạo.
        //
        // §3.1 đòi màn này chỉ có ĐÚNG MỘT nút chính, và điều đó vẫn đúng: "Đổi…" là nút phụ
        // nằm trong một dòng thông tin, không phải một ngã rẽ ngang hàng với "Tạo dự án".
        //
        // Nhưng dòng thông tin ấy phải có. `project.create` ghi vào `~/eide` khi không ai nói
        // gì, và tới 22/09/2026 màn chào không hề nói ra điều đó: người dùng tạo dự án xong
        // phải đi tìm nó. Một trạng thái rỗng có "bước kế tiếp" mà giấu KẾT QUẢ của bước ấy thì
        // mới làm xong một nửa luật B5.
        nhanThuMuc.font = EideToken.fontUI
        nhanThuMuc.textColor = EideToken.Mau.muted
        let doi = NSButton(title: "Đổi…", target: self, action: #selector(_chonThuMuc))
        doi.bezelStyle = .inline
        doi.font = EideToken.fontUI
        let hangThuMuc = NSStackView(views: [nhanThuMuc, doi])
        hangThuMuc.orientation = .horizontal
        hangThuMuc.spacing = 8
        _veThuMuc()

        let hop = NSStackView(views: [chao, ly, g, o, hangThuMuc, nut, nhanTt, nutVanTao])
        hop.orientation = .vertical
        hop.alignment = .leading
        hop.spacing = 12
        hop.edgeInsets = NSEdgeInsets(top: 26, left: 30, bottom: 26, right: 30)
        hop.wantsLayer = true
        hop.layer?.backgroundColor = EideToken.Mau.surface.cgColor
        hop.layer?.cornerRadius = 12
        hop.layer?.borderWidth = 1
        hop.layer?.borderColor = EideToken.Mau.border.cgColor
        hop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hop)
        NSLayoutConstraint.activate([
            hop.centerXAnchor.constraint(equalTo: centerXAnchor),
            hop.centerYAnchor.constraint(equalTo: centerYAnchor),
            hop.widthAnchor.constraint(equalToConstant: 520),
            o.widthAnchor.constraint(equalTo: hop.widthAnchor, constant: -60),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Báo lại cho người: đang tạo, hoặc vì sao không tạo được. Mở khoá nút khi hết bận, nếu
    /// không một lần hỏng là màn này chết vĩnh viễn.
    public func datTrangThai(_ van: String, ban: Bool) {
        dangBan = ban
        nut.isEnabled = !ban
        nhanTt.stringValue = van
        nhanTt.isHidden = van.isEmpty
        nhanTt.textColor = ban ? EideToken.Mau.muted : EideToken.Mau.bad
        nutVanTao.isHidden = true
    }

    /// Người bấm "Vẫn tạo" sau khi đọc danh sách tên gần giống — [DEV-198].
    public var onVanTao: (() -> Void)?

    private let nutVanTao = NSButton(title: "Vẫn tạo", target: nil, action: nil)

    /// **Câu HỎI, không phải lời từ chối.** [DEV-198]
    ///
    /// PROJECT-01 bước 2 viết: tên gần giống thì *"trả `existing` để Orchestrator **HỎI**"*.
    /// Giao diện tới 23/09/2026 biến nó thành một lời từ chối, và lối thoát duy nhất nó đưa ra
    /// là `eide project list` — một lệnh dòng lệnh, giữa một màn hình dựng lên cho người chưa
    /// từng mở Terminal.
    ///
    /// Một câu hỏi phải có đường trả lời "CÓ". Không có nút này thì "ask" và "reject" là một
    /// thứ, và người dùng chỉ còn cách đổi tên dự án của mình cho vừa lòng một phép so chuỗi.
    public func hoiTenGanGiong(_ van: String) {
        dangBan = false
        nut.isEnabled = true
        nhanTt.stringValue = van
        nhanTt.isHidden = false
        nhanTt.textColor = EideToken.Mau.warn
        nutVanTao.isHidden = false
    }

    /// Gõ câu mô tả — cho bài đo đi đúng đường người dùng đi.
    public func datMoTaDeTest(_ van: String) { o.stringValue = van }

    /// Chọn thư mục mà KHÔNG mở hộp thoại hệ thống — `NSOpenPanel` là modal, và một bài kiểm
    /// chạy headless sẽ treo ở đó thay vì đỏ.
    public func datThuMucDeTest(_ duong: String?) {
        thuMuc = duong
        _veThuMuc()
    }

    private func _veThuMuc() {
        nhanThuMuc.stringValue = "Lưu tại: " + (thuMuc ?? Self.macDinh)
            + (thuMuc == nil ? "  (mặc định)" : "")
    }

    @objc private func _chonThuMuc() {
        let hop = NSOpenPanel()
        hop.canChooseDirectories = true
        hop.canChooseFiles = false
        hop.canCreateDirectories = true
        hop.allowsMultipleSelection = false
        hop.prompt = "Chọn"
        hop.message = "Chọn thư mục workspace — dự án mới sẽ nằm trong thư mục này."
        hop.directoryURL = URL(fileURLWithPath: thuMuc ?? Self.macDinh)
        guard hop.runModal() == .OK, let u = hop.url else { return }
        thuMuc = u.path
        _veThuMuc()
    }

    @objc private func _vanTao() { onVanTao?() }

    @objc private func _tao() {
        guard !dangBan else { return }
        let v = o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ô rỗng thì dùng chính câu gợi ý, KHÔNG gửi chuỗi rỗng: `project.create` sẽ tạo một dự
        // án tên "" ở đâu đó, và người dùng có một thư mục rác mà không biết vì sao.
        onTao?(v.isEmpty ? goiY : v, thuMuc)
    }
}
