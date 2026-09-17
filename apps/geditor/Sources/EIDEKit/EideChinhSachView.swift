import AppKit

/// **Màn Chính sách tự chủ (S25)** — `policy.*`.
///
/// Bảng quy tắc CHỈ ĐỌC, mức tự chủ hiện tại, và một câu nói thẳng rằng việc ký lại chính sách
/// là LỆNH DÒNG LỆNH chứ không phải năng lực.
///
/// ## Vì sao bảng quy tắc phải đọc được từ trong sản phẩm
///
/// Cổng chính sách quyết định tác tử được tự làm gì. Người dùng ở mức A3 giao cho nó cả một
/// chuỗi việc, và câu hỏi đầu tiên họ sẽ hỏi là *"nó được phép làm tới đâu?"*. Trả lời câu ấy
/// bằng "mở tệp `rules.yaml` trong thư mục cài đặt" là không trả lời.
///
/// ## Vì sao chỉ đọc
///
/// Sửa quy tắc trong sản phẩm nghĩa là sản phẩm tự nới quyền của chính nó — đúng thứ `G-WL-02`
/// dựng lên để chặn, và là lý do `eide policy sign` là một lệnh dòng lệnh. Màn này hiện đủ để
/// người ĐỌC và ĐỐI CHIẾU, không đủ để sửa.
public final class ChinhSachView: ManHinhCoSo {

    /// Người đổi mức tự chủ — `(mức mới)`. Đi qua `policy.set_autonomy` như mọi lời gọi khác.
    public var onDoiMuc: ((String) -> Void)?

    /// Số quy tắc đang hiện — cho bài kiểm đọc.
    public private(set) var soQuyTac = 0
    /// Mức tự chủ đang có hiệu lực.
    public private(set) var mucHienTai = ""

    public init() { super.init(ten: "Chính sách tự chủ") }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soQuyTac = 0

        mucHienTai = (ketQua["effective"] as? String) ?? (ketQua["autonomy"] as? String) ?? ""
        if !mucHienTai.isEmpty {
            themDong("mức đang có hiệu lực", mucHienTai, mau: EideToken.Mau.info)
        }

        let qt = (ketQua["rules"] as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
        if qt.isEmpty {
            noiRong("Chưa đọc được bảng quy tắc. Bước kế tiếp: chạy `policy.rules` — bảng nằm "
                    + "trong `docs/spec/policy/rules.yaml` và được niêm bằng chữ ký.")
            return
        }
        soQuyTac = qt.count
        tomTat.stringValue = "\(qt.count) quy tắc — chỉ đọc"

        themBang(cot: ["Mã", "Cổng", "Điều kiện", "Quyết định", "Lý do"],
                 hang: qt.map { r in
                     [(r["id"] as? String) ?? "?",
                      (r["gate"] as? String) ?? "*",
                      (r["when"] as? String) ?? "",
                      (r["decision"] as? String) ?? "",
                      (r["reason"] as? String) ?? ""]
                 })

        noiRong("Bảng này CHỈ ĐỌC. Ký lại chính sách là lệnh dòng lệnh `eide policy sign`, không "
                + "phải một năng lực — nếu nó là năng lực thì tác tử gọi được, tức tác tử tự cấp "
                + "quyền cho chính nó, và cả hệ thống cổng mất nghĩa (POL-17 §3, quy tắc G-WL-02).")
    }
}
