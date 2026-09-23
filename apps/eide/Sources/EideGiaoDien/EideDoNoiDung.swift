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
        khop(muc, trong: van) != nil
    }

    /// Dấu hiệu nào khớp, và khớp Ở CÂU NÀO — `nil` nghĩa là không mục nào khớp. [DEV-190]
    ///
    /// ## Một phép đo chỉ trả `true`/`false` thì không ai soi lại được nó
    ///
    /// Đo 23/09/2026 khi rà soát 77 mục: dấu hiệu `engine` của S16 khớp câu *"engine hiện có
    /// không có kênh để nhìn"* — một câu về kỳ vọng chưa quan sát được, không phải bảng nền
    /// tảng mô phỏng mà mục ấy đòi. Mục được đếm là ĐÃ HIỆN trong khi màn không hề gọi
    /// `sim.build_platform`. Ngược lại, dấu hiệu `constant-guard` của S14 báo THIẾU trong khi
    /// màn có đủ: nó in "▎ n hằng số phần cứng KHÔNG trỏ fact — `G-FACT` sẽ chặn merge", đúng
    /// việc ấy nhưng không dùng đúng chữ ấy.
    ///
    /// Hai lỗi ngược chiều nhau, cùng một gốc: **`true`/`false` không mang bằng chứng.** Trả
    /// kèm câu khớp thì người đọc báo cáo tự thấy ngay dấu hiệu nào bắt nhầm.
    public static func khop(_ muc: Muc, trong van: String) -> (dau: String, cau: String)? {
        guard muc.do_duoc else { return ("(chưa đo được)", "") }
        let v = _thuong(van)
        for d in muc.dau_hieu where !_thuong(d).isEmpty {
            var tu = v.startIndex
            while let r = v.range(of: _thuong(d), range: tu..<v.endIndex) {
                if !_phuDinh(v, r) { return (d, _cauQuanh(van, v, r)) }
                tu = r.upperBound
            }
        }
        return nil
    }

    /// Chỗ khớp này có nằm trong một câu PHỦ ĐỊNH không? [DEV-190]
    ///
    /// ## Màn nói "chưa có X" đang được tính là "đã hiện X"
    ///
    /// Lỗ hệ thống, đo 23/09/2026 bằng chính bản in bằng chứng vừa thêm:
    ///
    /// * S4 mục *"Lượt nhập gần nhất"* khớp câu **"Chưa có LƯỢT NHẬP nào trong sổ cái"**;
    /// * S3 mục *"bước đang bị chặn kèm CÁCH GỠ"* khớp câu **"Không cổng nào đang chặn"**;
    /// * S1 mục *"Hoàn tác được: số mục + hạn sớm nhất"* khớp ô **"Mục hoàn tác 0"** của bảng
    ///   phiên làm việc — một dòng khác hẳn khối mà mục ấy đòi.
    ///
    /// Trạng thái rỗng CÓ LÝ DO là đúng luật B5 và phải giữ; nhưng nó không được tính là đã
    /// hiện nội dung. Nếu tính thì một màn chỉ cần nói "chưa có gì" là qua được mọi phép đo —
    /// tức là cổng thưởng cho đúng thứ nó phải bắt.
    ///
    /// Bắt theo CỬA SỔ 28 ký tự ngay trước chỗ khớp, không quét cả màn: cả màn thì gần như
    /// trang nào cũng có một chữ "chưa" ở đâu đó, và bộ dò sẽ báo thiếu mọi thứ.
    private static func _phuDinh(_ v: String, _ r: Range<String.Index>) -> Bool {
        let dau = v.index(r.lowerBound, offsetBy: -28, limitedBy: v.startIndex) ?? v.startIndex
        var truoc = String(v[dau..<r.lowerBound])
        // DỪNG ở ranh giới câu. Nhìn lui 28 ký tự mà vắt qua dòng trước thì nó bắt phải chữ
        // "chưa" của một câu KHÁC — một âm tính giả, ngược hẳn lỗi mà luật này sinh ra để chặn.
        //
        // Đo 23/09/2026 ở màn Kế hoạch: khối CÒN THIẾU in hai gạch đầu dòng,
        // "• tần số thạch anh CHƯA có fact" rồi "• Cổng G1 (G1-02) ASK: …". Dấu hiệu `Cổng`
        // khớp đúng chỗ, nhưng chữ "chưa" của gạch đầu dòng TRƯỚC lọt vào cửa sổ nhìn lui, nên
        // mục bị báo thiếu trong khi màn hiện đủ — và tôi suýt kết luận rằng nó cần sửa lõi.
        for x in ["\n", "•", "·", "\t", "↵"] {
            if let i = truoc.range(of: x, options: .backwards) {
                truoc = String(truoc[i.upperBound...])
            }
        }
        for t in ["chua ", "khong ", "trong -", "chua co", "khong co"] where truoc.contains(t) {
            return true
        }
        return false
    }

    /// Cắt ~90 ký tự quanh chỗ khớp, trên chuỗi GỐC (còn dấu) để người đọc được.
    ///
    /// Chỉ số tính trên chuỗi đã bỏ dấu; `folding` giữ nguyên số ký tự với tiếng Việt nên hai
    /// chuỗi cùng độ dài và chỉ số dùng chung được. Lệch thì cắt lệch vài ký tự — chấp nhận
    /// được cho một dòng bằng chứng, và vẫn đúng câu.
    private static func _cauQuanh(_ goc: String, _ v: String, _ r: Range<String.Index>) -> String {
        let n = v.distance(from: v.startIndex, to: r.lowerBound)
        guard goc.count == v.count else { return String(goc.prefix(90)) }
        let dau = max(0, n - 40), cuoi = min(goc.count, n + 50)
        let a = goc.index(goc.startIndex, offsetBy: dau)
        let b = goc.index(goc.startIndex, offsetBy: cuoi)
        return String(goc[a..<b])
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func _thuong(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
    }
}
