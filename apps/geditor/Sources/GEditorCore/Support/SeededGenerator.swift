import Foundation

/// Bộ sinh số giả ngẫu nhiên TẤT ĐỊNH — cùng seed cho cùng dãy số, trên mọi máy và mọi lần chạy.
///
/// ## Vì sao không dùng `SystemRandomNumberGenerator`
///
/// NFR-MIN-02 đòi *"kết quả tất định, seed ghi kèm trong mọi kết quả"*. Bộ sinh của hệ thống lấy
/// entropy từ nhân, nên chạy hai lần cho hai kết quả — và một bảng phân cụm đổi mỗi lần mở là
/// một bảng không dùng được để so, không dùng được để báo cáo, và không kiểm được bằng bài kiểm
/// tự động.
///
/// Ở đây là **SplitMix64**: băm một bộ đếm tăng dần. Nó nhỏ (ba phép trộn), không có trạng thái
/// ẩn, và phân bố đủ tốt cho việc chọn tâm cụm ban đầu. Nó **không** dùng được cho mật mã, và
/// không có chỗ nào trong GEditor cần điều đó.
///
/// ## Cùng thuật toán mà `PieceTree` dùng, và đó là chủ ý
///
/// `PieceTree` cần một ưu tiên treap tất định nên nó băm bộ đếm nút. Việc ấy giống hệt việc sinh
/// một dòng số ngẫu nhiên. Trước 26/08/2026 hai chỗ có hai bản chép rời nhau; gom về đây vì hai
/// bản của cùng một thuật toán là hai dãy số sẽ trôi ra xa nhau khi ai đó sửa một bên.
public struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        return SeededGenerator.mix(state)
    }

    /// Băm tất định một giá trị. Dùng khi cần một con số ổn định cho một khoá, chứ không cần
    /// một DÒNG số — `PieceTree` dùng dạng này cho ưu tiên treap.
    public static func mix(_ value: UInt64) -> UInt64 {
        var z = value
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Số thực trong `[0, 1)`.
    ///
    /// Lấy 53 bit cao chứ không lấy 64 bit rồi chia: `Double` chỉ có 53 bit định trị, nên chia
    /// cho `UInt64.max` làm tròn và có thể cho ra đúng `1.0` — mà một hàm khai `[0, 1)` trả về
    /// `1.0` sẽ cho chỉ số vượt biên ở chỗ gọi, rất hiếm và rất khó truy.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)   // 2⁵³
    }
}
