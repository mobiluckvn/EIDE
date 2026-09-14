import Foundation

/// Mở một **dự án EIDE** từ giao diện — GIAM-SAT-UI §0.2.
///
/// ## Vì sao cần lớp này
///
/// `EideDaemonLauncher.moClient()` chạy `eide daemon` **không có `-p`**, và cả hai chỗ gọi nó
/// đều dùng mặc định ấy. Daemon vì thế không thuộc dự án nào, nên mọi màn đọc dữ liệu dự án —
/// Tổng quan, Hộ chiếu, Bản đồ tri thức, Mô phỏng, Hàng đợi — đều rỗng. Và rỗng **vì không có
/// dự án**, chứ không phải vì chưa có dữ liệu; hai chuyện ấy đòi hai câu trả lời khác nhau
/// nhưng màn hình thì trông y hệt.
///
/// Đổi dự án là **khởi động lại daemon**, không phải gọi một năng lực: `ctx.project_dir` được
/// quyết lúc `Daemon.__init__` chạy, và sổ cái cũng mở theo nó. Một `project.open` gọi giữa
/// chừng chỉ đổi được dữ liệu trong store, không đổi được daemon đang trỏ vào đâu.
public enum EideDuAn {

    /// Một thư mục có phải dự án EIDE không, và nếu không thì **vì sao**.
    ///
    /// Trả lý do chứ không trả `Bool`: người vừa chọn nhầm thư mục cha cần biết nên vào thư mục
    /// con nào, còn người chọn một dự án đã bị xoá `.eide` cần biết đó là chuyện khác hẳn.
    public enum KetQua: Equatable {
        case duoc(String)
        case khongPhaiThuMuc
        case thieuEide          // có thư mục nhưng không có `.eide/`
        case thieuStore         // có `.eide/` nhưng chưa `eide migrate`

        public var loi: String? {
            switch self {
            case .duoc: return nil
            case .khongPhaiThuMuc:
                return "Đường dẫn này không phải một thư mục."
            case .thieuEide:
                return "Thư mục này không có `.eide/` — nó chưa phải dự án EIDE. "
                     + "Tạo bằng cách gõ \"tạo dự án cho chip …\" ở ô lệnh."
            case .thieuStore:
                return "Dự án có `.eide/` nhưng chưa có store. Chạy `eide migrate -p <dự án>` "
                     + "— hàng đợi và tri thức cần store để lưu được qua các phiên."
            }
        }
    }

    /// Kiểm một đường dẫn TRƯỚC khi khởi động daemon.
    ///
    /// Kiểm ở đây thay vì để daemon tự chết: `eide daemon -p <không phải dự án>` vẫn chạy được
    /// và vẫn trả lời RPC — nó chỉ trả rỗng cho mọi thứ. Người dùng khi ấy nhìn một cửa sổ đầy
    /// màn trống và không có gì nói cho họ biết đã chọn nhầm thư mục.
    public static func kiem(_ duong: String) -> KetQua {
        let fm = FileManager.default
        var laThuMuc: ObjCBool = false
        guard fm.fileExists(atPath: duong, isDirectory: &laThuMuc), laThuMuc.boolValue else {
            return .khongPhaiThuMuc
        }
        let eide = (duong as NSString).appendingPathComponent(".eide")
        guard fm.fileExists(atPath: eide, isDirectory: &laThuMuc), laThuMuc.boolValue else {
            return .thieuEide
        }
        // `store/store.sqlite`, không phải `store.sqlite`: đường dẫn thật là
        // `.eide/store/store.sqlite` (đo 14/09/2026 — có lúc tôi đã tìm nhầm một cấp và kết
        // luận sai rằng dự án chưa migrate).
        let store = (eide as NSString).appendingPathComponent("store/store.sqlite")
        guard fm.fileExists(atPath: store) else { return .thieuStore }
        return .duoc(duong)
    }

    // MARK: - Danh sách gần đây

    private static let KHOA_GAN_DAY = "eide.duAnGanDay"
    static let TOI_DA_GAN_DAY = 8

    /// Dự án đã mở gần đây, mới nhất trước.
    ///
    /// Lọc bỏ thư mục không còn tồn tại **khi đọc**, không khi ghi: một dự án nằm trên ổ ngoài
    /// chưa cắm vào thì vẫn nên ở trong danh sách, chỉ là không mở được lúc này. Xoá nó khỏi
    /// danh sách vì một lần rút ổ là làm người dùng mất một lối tắt họ dùng hằng ngày.
    public static func ganDay(_ kho: UserDefaults = .standard) -> [String] {
        let ds = (kho.array(forKey: KHOA_GAN_DAY) as? [String]) ?? []
        return ds.filter { FileManager.default.fileExists(atPath: $0) }
    }

    /// Ghi nhận một dự án vừa mở. Đưa lên đầu, bỏ trùng, cắt bớt phần cũ.
    public static func nhoDaMo(_ duong: String, _ kho: UserDefaults = .standard) {
        var ds = (kho.array(forKey: KHOA_GAN_DAY) as? [String]) ?? []
        ds.removeAll { $0 == duong }
        ds.insert(duong, at: 0)
        if ds.count > TOI_DA_GAN_DAY { ds = Array(ds.prefix(TOI_DA_GAN_DAY)) }
        kho.set(ds, forKey: KHOA_GAN_DAY)
    }

    /// Nhãn hiện trong menu: tên thư mục, kèm thư mục cha khi hai dự án trùng tên.
    ///
    /// Hai dự án cùng tên là chuyện thường — `~/eide/blink` và `~/work/blink` — và một menu có
    /// hai dòng giống hệt nhau thì người dùng phải bấm thử để biết cái nào là cái nào.
    public static func nhan(_ duong: String, trong ds: [String]) -> String {
        let ten = (duong as NSString).lastPathComponent
        let trung = ds.filter { ($0 as NSString).lastPathComponent == ten }.count > 1
        guard trung else { return ten }
        let cha = ((duong as NSString).deletingLastPathComponent as NSString).lastPathComponent
        return "\(ten) — \(cha)"
    }
}
