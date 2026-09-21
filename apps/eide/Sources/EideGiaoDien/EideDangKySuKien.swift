import Foundation
import EideLoi

/// **Bảng đăng ký sự kiện của các màn.** UXC-31 §7.1.
///
/// > "giao diện subscribe thông báo JSON-RPC theo LOẠI sự kiện; mỗi màn khai báo tĩnh danh sách
/// > loại nó cần — có **bảng đăng ký kiểm được**, không màn nào subscribe *tất cả*."
///
/// ## Vì sao không phải mỗi màn tự nghe lấy
///
/// Một màn tự gắn tay nghe vào kênh sẽ tự quyết lấy nó quan tâm gì, và không chỗ nào trong mã
/// trả lời được câu "sự kiện `event.knowledge.changed` đi tới những màn nào". Bảng này là chỗ
/// trả lời câu ấy — nên nó là dữ liệu, tĩnh, và có phép kiểm đọc thẳng vào.
///
/// ## `event.*` lấy từ mã SINH, không chép tay
///
/// 22 tên sự kiện đã nằm trong `EideMethod` (sinh từ `openrpc.json`). Chép lại chúng vào đây là
/// tạo bản thứ hai của cùng một danh sách, và bản thứ hai sẽ lệch ngay lần thêm sự kiện sau —
/// đúng hình dạng của [DEV-043] và của lần `caps.json` lệch khỏi nguồn sinh (20/09).
public enum EideDangKySuKien {

    /// Mọi loại sự kiện mà daemon phát ra, theo hợp đồng đã sinh.
    public static let TAT_CA: Set<String> = Set(
        EideMethod.allCases.map(\.rawValue).filter { $0.hasPrefix("event.") })

    /// Màn → loại sự kiện nó cần. Cột "nghe:" của UXC-31 §8.
    ///
    /// Màn KHÔNG có mặt ở đây là màn không nghe gì — hợp lệ, và khác hẳn với nghe tất cả.
    public static let BANG: [String: Set<String>] = [
        // S1 Tổng quan — "nghe: run.*, human.*, thay đổi pending/undo".
        "Main": ["event.run.progress", "event.queue.changed",
                 "event.undo.registered", "event.undo.expired", "event.autonomy.changed"],
        // S2 Nhật ký — UXC-31 §8 ghi "nghe: MỌI LOẠI", và đó là đúng: màn này LÀ sổ cái.
        //
        // Nó khai bằng `TAT_CA` — một hằng số có tên, sinh từ hợp đồng — chứ không bằng một
        // chuỗi `"*"`. Khác biệt không phải là chữ nghĩa: `"*"` làm mọi sự kiện thêm sau này tự
        // chảy vào mọi chỗ mà không ai quyết; `TAT_CA` vẫn là một khai báo đọc được, và phép
        // kiểm dưới đây đòi **đúng một màn duy nhất** được dùng nó.
        "NhatKy": TAT_CA,
        // S3 Bản đồ luồng — "nghe: run.*".
        "FlowMap": ["event.run.progress"],
        // S4 Nhập tài liệu — "nghe: ingest.*"; sổ cái đổ chúng về `knowledge.changed`.
        "Ingest": ["event.knowledge.changed", "event.job.progress"],
        // S5 Hộ chiếu chip — fact đổi thì bảng fact phải đổi theo.
        "Passport": ["event.knowledge.changed"],
        // S6 Hộ chiếu mạch — net và chân đều là fact.
        "Board": ["event.knowledge.changed", "event.discover.changed"],
        // S7 Bản đồ tri thức — "nghe: kg.*".
        "Graph": ["event.knowledge.changed"],
        // S8 Xung đột tri thức — xung đột sinh ra lúc ghi store, và giải quyết qua cổng.
        "XungDot": ["event.knowledge.changed", "event.gate.opened", "event.gate.decided"],
        // S9 Làm rõ yêu cầu — câu hỏi gộp là một mục ASK ở cổng, nên nó tới qua hàng đợi.
        "LamRo": ["event.queue.changed", "event.gate.opened", "event.chat.question",
                  "event.chat.restated"],
        // S10 Yêu cầu & kiến trúc — yêu cầu và ADR đều là hiện vật trong store.
        "ReqArch": ["event.knowledge.changed", "event.run.progress"],
        // S11 Lược đồ — "chỉ báo đồng bộ hai chiều mã ↔ hình": mã đổi thì hình thành cũ.
        "DiagramView": ["event.diagram.stale", "event.run.progress"],
        // S12 Kế hoạch — kế hoạch đổi theo lượt chạy của tác tử.
        "PlanDiff": ["event.run.progress", "event.knowledge.changed"],
        // S13 Tài liệu — `event.doc.stale` là đúng tín hiệu "mục này đã cũ so với mã".
        "Doc": ["event.doc.stale", "event.run.progress"],
        // S25 Chính sách — mức tự chủ và niêm.
        "ChinhSach": ["event.autonomy.changed", "event.notice"],
    ]

    /// Màn nào cần nghe loại sự kiện này.
    public static func manCan(_ loai: String) -> [String] {
        BANG.filter { $0.value.contains(loai) }.keys.sorted()
    }

    /// Màn duy nhất được phép nghe TẤT CẢ — và lý do nó được phép.
    public static let MAN_NGHE_TAT_CA = "NhatKy"
}
