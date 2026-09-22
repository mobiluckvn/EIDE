import AppKit
import Foundation

// Đặt cùng module với `EideDoNutChet`: cả hai là BỘ ĐO của giao diện, và một bộ đo phải kiểm
// được từ bài kiểm của giao diện. Để ở target `EideApp` thì `EideGiaoDienTests` không thấy nó
// — và một phép đo không ai đo lại được thì không có gì bảo đảm nó đo đúng.

/// Bộ dò NỘI DUNG màn — `EideApp --do-noi-dung <dự án>`.
///
/// ## Vì sao cần, khi đã có `--do-nut` và `--bam-thu`
///
/// Hai bộ kia hỏi *"nút có nối vào đâu không"* và *"bấm xong màn hình có đổi không"*. Cả hai
/// đều mù với câu hỏi người dùng thật sự hỏi: **màn này có hiện thứ nó phải hiện không.**
///
/// Đo 22/09/2026 lúc dựng bảng rà soát: `--do-nut` báo *"0 nút chết trên 25 màn"* trong khi
/// **bốn mục menu không có lớp màn nào phía sau** (Discovery, LogAssist, Debug, Bench). Nó lặp
/// qua danh sách menu, gọi `moMan()`, hàm ấy trả về ngay vì `EidePhien.MAN` không có tiền tố
/// ấy, rồi nó đếm nút trên một vùng làm việc TRỐNG. Không nút nào thì không nút nào chết — một
/// phép đo xanh ở đúng chỗ cần thấy nhất.
///
/// ## Hợp đồng nội dung đến từ đâu
///
/// `docs/spec/ui/man_can_hien.json`, sinh từ cột "DỮ LIỆU PHẢI HIỆN" của
/// `docs/EIDE-VUNG-MAN-HINH.xlsx` — bản chủ sản phẩm duyệt 22/09/2026. Danh sách nằm ngoài mã
/// là có chủ ý: thêm một mục vào Excel thì cổng tự đỏ thêm, không phải nhớ sửa hai chỗ.
///
/// ## Vì sao "ít nhất một dấu hiệu" chứ không "tất cả"
///
/// Một khối dữ liệu diễn đạt được vài cách — bảng hay câu, "Tầng" hay "tier". Bắt khớp hết mọi
/// mẩu chữ sẽ biến bộ dò thành phép so giao diện từng pixel: đỏ mỗi lần đổi chữ, và vì thế bị
/// tắt đi. Cổng nào người ta tắt đi thì không phải cổng.
public enum EideDoNoiDung {

    public struct Muc: Decodable {
        public let mo_ta: String
        public let dau_hieu: [String]
        public let do_duoc: Bool
    }

    public struct Man: Decodable {
        public let ma: String
        public let ten: String
        public let muc: [Muc]
    }

    /// Đọc hợp đồng nội dung. `nil` khi chưa sinh — nói ra chứ không lặng lẽ cho qua.
    public static func hopDong(_ goc: URL) -> [String: Man]? {
        let f = goc.appendingPathComponent("docs/spec/ui/man_can_hien.json")
        guard let d = try? Data(contentsOf: f),
              let ds = try? JSONDecoder().decode([String: Man].self, from: d) else { return nil }
        return ds
    }

    /// Một mục coi như ĐÃ HIỆN khi chữ trên màn chứa ít nhất một dấu hiệu của nó.
    ///
    /// So không phân biệt hoa thường và bỏ dấu tiếng Việt: nhãn có thể viết "Tầng" hay "TẦNG",
    /// và một bộ dò đỏ vì chữ hoa là một bộ dò dạy người ta bỏ qua nó.
    public static func daHien(_ muc: Muc, trong van: String) -> Bool {
        guard muc.do_duoc else { return true }        // chưa đo được thì không kết tội
        let v = _thuong(van)
        return muc.dau_hieu.contains { _thuong($0).isEmpty == false && v.contains(_thuong($0)) }
    }

    private static func _thuong(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
    }
}
