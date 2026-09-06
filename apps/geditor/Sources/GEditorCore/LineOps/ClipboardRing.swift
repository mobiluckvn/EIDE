import Foundation

/// Lịch sử những lần sao chép (FR-CORE-017).
///
/// **Vòng, không phải danh sách vô hạn.** Thứ người ta thật sự dùng là vài lần chép gần nhất;
/// giữ tất cả chỉ làm danh sách dài ra tới mức không tìm nổi, và với một trình soạn thảo file
/// hàng GB thì "tất cả" có thể là vài trăm megabyte nằm im trong RAM.
///
/// **Trùng thì nâng lên đầu, không thêm bản mới.** Chép đi chép lại cùng một đoạn — chuyện
/// thường khi dán vào nhiều chỗ — mà sinh ra mười mục giống hệt thì lịch sử thành vô dụng.
///
/// **Có trần cho từng mục.** Chép cả một file 200 MB rồi chép tiếp thứ khác thì 200 MB ấy sẽ
/// nằm lại trong vòng mà không ai còn cần. Mục quá `entryLimit` không được giữ: nó vẫn nằm ở
/// clipboard của hệ điều hành và vẫn dán được như thường, chỉ là không vào lịch sử.
///
/// **Thuần túy, không chạm AppKit.** Lớp giao diện đưa chuỗi vào và lấy chuỗi ra.
public struct ClipboardRing: Equatable, Sendable {

    /// Số mục nhiều nhất được giữ.
    public static let capacity = 20

    /// Cỡ lớn nhất của một mục, tính bằng byte UTF-8.
    public static let entryLimit = 1 << 20

    private(set) public var entries: [String] = []

    public init() {}

    public var isEmpty: Bool { entries.isEmpty }

    /// Ghi nhận một lần sao chép. Mới nhất luôn ở đầu.
    public mutating func record(_ text: String) {
        guard !text.isEmpty, text.utf8.count <= Self.entryLimit else { return }
        entries.removeAll { $0 == text }
        entries.insert(text, at: 0)
        if entries.count > Self.capacity { entries.removeLast(entries.count - Self.capacity) }
    }

    public func entry(at index: Int) -> String? {
        entries.indices.contains(index) ? entries[index] : nil
    }

    public mutating func clear() { entries.removeAll() }

    /// Nhãn một dòng để hiện trên menu.
    ///
    /// Xuống dòng và TAB đổi thành ký hiệu nhìn thấy được: một mục ba dòng mà hiện nguyên xi
    /// sẽ phá vỡ bố cục menu, còn cắt ở dòng đầu thì hai mục khác nhau trông giống hệt nhau.
    public static func label(for text: String, width: Int = 48) -> String {
        var flat = ""
        for character in text {
            switch character {
            case "\n": flat += "⏎"
            case "\r": continue
            case "\t": flat += "⇥"
            default: flat.append(character)
            }
            if flat.count >= width { return flat + "…" }
        }
        return flat
    }
}
