import Foundation

/// Plugin NATIVE chạy ở tiến trình riêng — FR-PLUG-702 · FR-PLUG-703 (ADR-12).
///
/// Tệp này là phần LÕI: hình dạng của lời gọi và của câu trả lời, cùng phép mã hoá chúng.
/// Nó không biết gì về tiến trình, về ống, về AppKit — nhờ thế kiểm được bằng `swift test`
/// mà không cần dựng một tiến trình con nào.
///
/// ## Vì sao plugin native phải ở tiến trình khác
///
/// ADR-12 chốt sau PoC-H: hardened runtime — bắt buộc để công chứng — bật library validation,
/// và dyld từ chối dylib của bên thứ ba với đúng câu *"different Team IDs"*. Ba lối ra, và lối
/// được chọn là **cho plugin chạy ở tiến trình riêng**: app chính giữ nguyên entitlement, chỉ
/// một tiến trình phụ nhỏ mang `disable-library-validation`.
///
/// Lý do thật không phải hiệu năng (0,010 ms mỗi lần gọi — bằng không so với việc plugin làm)
/// mà là **phạm vi thiệt hại**: plugin hỏng hay độc hại thì nó chết một mình, còn văn bản chưa
/// lưu của người dùng nằm ở tiến trình khác.
///
/// ## API cố ý HẸP, và đây là lý do
///
/// Bài học FR-AUTO-603 áp dụng nguyên vẹn: **mở rộng bề mặt API về sau thì dễ, thu hẹp lại thì
/// phá thứ người khác đã viết.** Nên plugin native ở bản đầu thấy đúng một hình dạng:
///
///     văn bản vào  →  plugin  →  văn bản ra
///
/// Không đọc file, không mạng, không hỏi trạng thái ứng dụng, không vẽ giao diện. Một plugin là
/// một phép BIẾN ĐỔI VĂN BẢN có tên.
///
/// Hẹp thế này còn được một thứ nữa: nó khiến tiến trình phụ không cần quyền gì. Mọi dữ liệu đi
/// vào đều do app truyền, nên tiến trình ấy không có gì để mất và không có gì để lộ.
///
/// ## `apiVersion` là lời hứa, không phải số trang trí
///
/// Plugin khai nó hiểu API phiên bản nào. App từ chối plugin khai số nó không biết, và từ chối
/// bằng một câu nói rõ số nào so với số nào — chứ không im lặng chạy rồi hỏng ở giữa.
public enum NativePlugin {

    /// Phiên bản API mà bản dựng này nói chuyện được.
    ///
    /// Tăng số này khi hình dạng lời gọi đổi theo cách plugin cũ không hiểu. Thêm một trường
    /// TUỲ CHỌN thì không phải đổi — đó chính là lý do mọi trường thêm về sau phải tuỳ chọn.
    public static let apiVersion = 1

    /// Giới hạn kích thước một thông điệp, tính bằng byte.
    ///
    /// Có trần vì đầu bên kia là mã của NGƯỜI KHÁC: một plugin hỏng (hoặc cố tình) có thể khai
    /// độ dài 4 GB và app sẽ ngồi cấp phát cho tới khi hết bộ nhớ. 64 MB đủ cho mọi tài liệu
    /// mà một phép biến đổi văn bản đụng tới, và nhỏ hơn trần RAM hai bậc.
    public static let messageLimit = 64 << 20
}

/// Những gì plugin tự khai về mình.
public struct NativePluginManifest: Codable, Equatable, Sendable {

    public var name: String
    public var version: String
    /// Phiên bản API plugin nói được — xem `NativePlugin.apiVersion`.
    public var apiVersion: Int
    /// Các phép biến đổi plugin cung cấp; khoá là tên lệnh, giá trị là nhãn cho menu.
    public var commands: [String: String]
    public var author: String?
    public var summary: String?

    public init(
        name: String, version: String, apiVersion: Int = NativePlugin.apiVersion,
        commands: [String: String], author: String? = nil, summary: String? = nil
    ) {
        self.name = name
        self.version = version
        self.apiVersion = apiVersion
        self.commands = commands
        self.author = author
        self.summary = summary
    }

    /// Bản dựng này có nói chuyện được với plugin ấy không.
    ///
    /// Trả `nil` khi được, hoặc câu giải thích khi không. Câu ấy đi thẳng ra cho người dùng, nên
    /// nó phải nói ĐỦ để họ biết làm gì tiếp — "plugin cần API 3, bản này nói API 1" cho người
    /// ta biết phải cập nhật cái nào, còn "plugin không tương thích" thì không.
    public func incompatibilityReason(against apiVersion: Int = NativePlugin.apiVersion) -> String? {
        if self.apiVersion > apiVersion {
            return "\(name) cần API phiên bản \(self.apiVersion), bản GEditor này nói API "
                + "\(apiVersion) — cập nhật GEditor"
        }
        if self.apiVersion < 1 {
            return "\(name) khai API phiên bản \(self.apiVersion), không phải một số hợp lệ"
        }
        if commands.isEmpty {
            return "\(name) không khai lệnh nào — gói này không làm được gì"
        }
        return nil
    }
}

/// Lời gọi app gửi sang tiến trình plugin.
public enum NativePluginRequest: Codable, Equatable, Sendable {

    /// "Anh là ai, và làm được gì?" — luôn là lời gọi ĐẦU TIÊN.
    case describe

    /// "Chạy lệnh này trên đoạn văn bản này."
    ///
    /// `selection` là phần người dùng đang bôi đen, tính bằng offset BYTE trong `text`. `nil`
    /// nghĩa là không bôi đen gì — plugin tự quyết định làm trên cả văn bản hay không làm gì.
    case run(command: String, text: String, selection: Range<Int>?)
}

/// Câu trả lời tiến trình plugin gửi về.
public enum NativePluginResponse: Codable, Equatable, Sendable {

    case manifest(NativePluginManifest)

    /// Văn bản mới. `nil` nghĩa là plugin cố ý KHÔNG đổi gì — khác hẳn với trả về chuỗi rỗng.
    ///
    /// Phân biệt hai thứ ấy là bắt buộc: một plugin "chỉ xem" trả `nil` và tài liệu không vào
    /// lịch sử hoàn tác; nếu nó phải trả nguyên văn bản cũ thì mỗi lần chạy là một bước hoàn
    /// tác rỗng, và người dùng bấm ⌘Z ba lần mà không thấy gì đổi.
    case replacement(String?)

    /// Plugin tự báo hỏng. Câu chữ do plugin viết, nên chỗ hiện nó ra phải nói rõ đây là lời
    /// của plugin chứ không phải của GEditor.
    case failure(String)
}

/// Mã hoá thông điệp: bốn byte độ dài (big-endian) rồi tới JSON.
///
/// **Vì sao có tiền tố độ dài.** Ống không có biên thông điệp — đọc một lần có thể ra nửa
/// thông điệp, hoặc ra một thông điệp rưỡi. Không có tiền tố thì bên nhận phải đoán, và mọi
/// cách đoán (tìm dấu xuống dòng, tìm dấu `}`) đều hỏng ngay khi nội dung chứa đúng ký tự ấy —
/// mà nội dung ở đây là VĂN BẢN CỦA NGƯỜI DÙNG, tức là chứa mọi thứ.
///
/// **Vì sao không dùng `Codable` trực tiếp lên ống.** Cùng lý do: `JSONDecoder` cần một khối
/// byte trọn vẹn, và chính việc biết "trọn vẹn tới đâu" là thứ tiền tố này cung cấp.
public enum NativePluginWire {

    public enum Failure: Error, Equatable {
        /// Đầu kia đóng ống — bình thường khi kết thúc, hỏng khi đang giữa thông điệp.
        case endOfStream
        /// Độ dài khai vượt trần, hoặc âm.
        case messageTooLarge(Int)
        case malformed(String)
    }

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let body = try JSONEncoder().encode(value)
        var out = Data(capacity: body.count + 4)
        var length = UInt32(body.count).bigEndian
        withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
        out.append(body)
        return out
    }

    /// Tách MỘT thông điệp khỏi đầu `buffer`, trả về giá trị và số byte đã tiêu.
    ///
    /// Trả `nil` khi chưa đủ byte — chỗ gọi đọc thêm rồi hỏi lại. Đây là hình dạng duy nhất
    /// đúng với một ống: "chưa đủ" là trạng thái bình thường, không phải lỗi.
    public static func decode<T: Decodable>(
        _ type: T.Type, from buffer: Data
    ) throws -> (value: T, consumed: Int)? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).reduce(Int(0)) { ($0 << 8) | Int($1) }
        guard length >= 0, length <= NativePlugin.messageLimit else {
            throw Failure.messageTooLarge(length)
        }
        guard buffer.count >= 4 + length else { return nil }
        let body = buffer.dropFirst(4).prefix(length)
        do {
            return (try JSONDecoder().decode(type, from: Data(body)), 4 + length)
        } catch {
            throw Failure.malformed(String(describing: error))
        }
    }
}
