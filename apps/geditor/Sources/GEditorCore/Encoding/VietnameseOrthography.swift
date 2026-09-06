import Foundation

/// Ba quy tắc chính tả tiếng Việt dùng để chấm xem một cách giải mã có hợp lý không.
///
/// **Vì sao cần đến chính tả:** thống kê byte không phân biệt được TCVN3 với VISCII. Cả hai
/// phủ đúng kho chữ Việt, nên mọi dòng byte hợp lệ ở bảng này đọc sang bảng kia vẫn ra 100%
/// chữ Việt — chỉ khác ở chỗ ghép lại thành từ có nghĩa hay không:
///
///     đúng (TCVN3):  Cộng hòa Xã hội Chủ nghĩa Việt Nam
///     sai  (VISCII): Céng hưa Xở héi Chự nghỵa Viỷt Nam
///     sai  (CP1258): Cµng ḥa Xă hµi Chü nghîa Vi®t Nam
///
/// **Vì sao CHỈ ba quy tắc này:** chúng đúng với mọi văn bản tiếng Việt và kiểm được mà không
/// cần từ điển. Một danh sách vần hợp lệ sẽ mạnh hơn nhiều, nhưng viết nó ra từ trí nhớ thì
/// đúng bằng việc gõ tay bảng mã — thứ mà cả module này được dựng ra để tránh.
enum VietnameseOrthography {

    /// Năm dấu thanh của tiếng Việt: huyền, sắc, ngã, hỏi, nặng.
    ///
    /// Khác với dấu chất lượng nguyên âm (mũ, trăng, móc) tạo ra ă â ê ô ơ ư — những dấu đó
    /// thuộc về bản thân chữ cái, không phải thanh điệu, nên không bị quy tắc "một dấu" chi phối.
    static let toneMarks: Set<UInt32> = [0x0300, 0x0301, 0x0303, 0x0309, 0x0323]

    /// Mọi chữ mang dấu thanh — suy từ chính bảng kết hợp đã sinh, không liệt kê tay.
    private static let tonedScalars: Set<UInt32> = {
        var scalars = Set<UInt32>()
        for entry in LegacyEncodingTables.composition where toneMarks.contains(entry.mark) {
            scalars.insert(entry.composed)
        }
        return scalars
    }()

    private static let dLower: UInt32 = 0x0111  // đ
    private static let dUpper: UInt32 = 0x0110  // Đ

    struct Assessment {
        let words: Int
        let violations: Int

        /// 1 = không vi phạm gì; 0 = mỗi từ đều sai.
        var plausibility: Double {
            guard words > 0 else { return 0 }
            return max(0, 1 - Double(violations) / Double(words))
        }
    }

    /// Đếm vi phạm chính tả trên một dãy điểm mã đã giải mã.
    static func assess(_ scalars: [UInt32]) -> Assessment {
        var words = 0
        var violations = 0

        var indexInWord = 0
        var tonesInWord = 0
        var previous: Unicode.Scalar?

        func endWord() {
            guard indexInWord > 0 else { return }
            words += 1
            // Quy tắc B — mỗi âm tiết mang TỐI ĐA MỘT dấu thanh. Hai dấu thanh cạnh nhau
            // gần như luôn nghĩa là đang đọc sai bảng mã.
            if tonesInWord > 1 { violations += tonesInWord - 1 }
            indexInWord = 0
            tonesInWord = 0
            previous = nil
        }

        for value in scalars {
            guard let scalar = Unicode.Scalar(value), scalar.properties.isAlphabetic else {
                endWord()
                continue
            }

            // Quy tắc A — "đ" chỉ đứng ĐẦU âm tiết. Thấy nó ở giữa từ ("Viđt") là dấu hiệu
            // chắc chắn của việc đọc sai bảng mã.
            if (value == dLower || value == dUpper), indexInWord > 0 {
                violations += 1
            }

            // Quy tắc F — chữ HOA không xuất hiện giữa từ ("hoÌa"). Không phải quy tắc tiếng
            // Việt mà là quy tắc của văn bản nói chung; nó bắt được các trường hợp bảng mã
            // sai đẩy chữ sang vùng byte của chữ hoa.
            if let previous, previous.properties.isLowercase, scalar.properties.isUppercase {
                violations += 1
            }

            if tonedScalars.contains(value) { tonesInWord += 1 }

            previous = scalar
            indexInWord += 1
        }
        endWord()

        return Assessment(words: words, violations: violations)
    }
}
