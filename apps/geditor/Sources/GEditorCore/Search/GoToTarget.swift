import Foundation

/// Thứ người dùng gõ vào ô «Đi tới» (FR-SRCH-111).
///
/// Đặc tả đòi ba cách viết: số dòng, `dòng,cột`, và một OFFSET. Ba cách ấy phải phân biệt được
/// **chỉ bằng chuỗi đã gõ** — không có hộp chọn kiểu nào, vì một hộp chọn nghĩa là người dùng
/// phải bấm hai lần cho việc họ muốn làm một lần.
///
/// # Vì sao offset cần một tiền tố
///
/// `1234` là dòng hay là offset? Không có câu trả lời đúng — cả hai đều hợp lý, và đoán sai thì
/// con nháy nhảy tới một chỗ hoàn toàn khác mà không có gì báo. Nên offset viết `@1234`: một ký
/// tự, đọc lên là "tại vị trí", và không đụng vào cách viết mà mọi trình soạn thảo khác đã dạy
/// người dùng (`12,34`).
///
/// # Vì sao phép phân tích nằm ở LÕI
///
/// Nó không cần một cửa sổ nào để chạy, nên nó không nên chỉ được kiểm bằng bài tự kiểm giao
/// diện. Ở đây thì `swift test` chạm tới được, kể cả những cách gõ hỏng mà người ta ít nghĩ ra:
/// `,5` · `3,` · `@` · `0` · số âm · khoảng trắng thừa.
public enum GoToTarget: Equatable, Sendable {
    /// Dòng (đếm từ 1), và cột nếu có (đếm từ 1).
    case line(Int, column: Int?)
    /// Vị trí BYTE trong tài liệu, đếm từ 0.
    case offset(Int)

    /// Đọc chuỗi người dùng gõ. `nil` = không hiểu, và chỗ gọi phải nói ra chứ đừng đoán bừa.
    ///
    /// Nhận `12`, `12,5`, `12:5`, `@340`. Khoảng trắng quanh các phần đều bỏ qua, vì chép một
    /// vị trí từ log ra thường dính theo dấu cách.
    public static func parse(_ text: String) -> GoToTarget? {
        let raw = text.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return nil }

        if raw.hasPrefix("@") {
            let rest = raw.dropFirst().trimmingCharacters(in: .whitespaces)
            guard let value = Int(rest), value >= 0 else { return nil }
            return .offset(value)
        }

        // Cả `,` lẫn `:` — `dòng:cột` là cách trình biên dịch và linter in ra lỗi, nên nó là
        // thứ người dùng có sẵn trong clipboard.
        //
        // `omittingEmptySubsequences: false` là phần bắt buộc, và bài kiểm đã bắt được lúc nó
        // còn thiếu: mặc định của `split` VỨT phần rỗng, nên `,5` và `5,` đều rút gọn thành
        // `["5"]` và cả hai được đọc thành "dòng 5" — một chuỗi gõ hụt bị hiểu thành một lệnh
        // hợp lệ, tức con nháy nhảy đi mà người dùng không hề ra lệnh ấy.
        let parts = raw.split(omittingEmptySubsequences: false,
                              whereSeparator: { $0 == "," || $0 == ":" })
        guard parts.count <= 2 else { return nil }

        guard let line = Int(parts[0].trimmingCharacters(in: .whitespaces)), line >= 1 else {
            return nil
        }
        guard parts.count == 2 else { return .line(line, column: nil) }
        guard let column = Int(parts[1].trimmingCharacters(in: .whitespaces)), column >= 1 else {
            return nil
        }
        return .line(line, column: column)
    }
}
