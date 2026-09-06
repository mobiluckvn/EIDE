import Foundation

/// Đổi vị trí tab bằng cách kéo thả (FR-DOC-301).
///
/// Phần khó của việc này không phải là dời phần tử trong mảng — nó là dời MỌI CHỈ SỐ đang trỏ
/// vào mảng ấy: tab đang mở, tab mà nửa kia của màn hình đang mở, và bất cứ thứ gì sau này giữ
/// một chỉ số tab. Quên một chỗ thì kéo một tab sang trái là màn hình lặng lẽ nhảy sang tài
/// liệu khác — không sập, không báo, chỉ sai.
///
/// Nên phép này nằm ở lõi và có test, thay vì nằm rải trong lớp giao diện.
public enum TabReorder {

    /// Mảng sau khi chuyển phần tử `from` tới vị trí `to`.
    ///
    /// `to` là vị trí trong mảng SAU khi đã nhấc phần tử ra — cùng quy ước với thao tác kéo
    /// thả mà người dùng nhìn thấy: thả vào khe thứ mấy thì nằm ở khe thứ ấy.
    public static func apply<T>(_ items: [T], from: Int, to: Int) -> [T] {
        guard items.indices.contains(from) else { return items }
        let destination = Swift.min(Swift.max(to, 0), items.count - 1)
        guard destination != from else { return items }

        var moved = items
        let element = moved.remove(at: from)
        moved.insert(element, at: destination)
        return moved
    }

    /// Vị trí MỚI của một chỉ số đang theo dõi, sau khi chuyển `from` → `to`.
    ///
    /// Ba trường hợp, và trường hợp thứ nhất là cái hay bị quên nhất:
    ///
    /// 1. Chỉ số theo dõi CHÍNH LÀ tab đang bị kéo → nó đi theo tới chỗ mới.
    /// 2. Tab bị kéo đi qua nó → nó dịch một bậc, chiều tuỳ hướng kéo.
    /// 3. Nằm ngoài đoạn bị ảnh hưởng → đứng yên.
    public static func track(_ index: Int, from: Int, to: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let last = count - 1
        let source = Swift.min(Swift.max(from, 0), last)
        let destination = Swift.min(Swift.max(to, 0), last)
        let tracked = Swift.min(Swift.max(index, 0), last)
        guard source != destination else { return tracked }

        if tracked == source { return destination }
        if source < destination {
            // Kéo sang PHẢI: mọi thứ nằm giữa lùi một bậc sang trái.
            return (tracked > source && tracked <= destination) ? tracked - 1 : tracked
        }
        // Kéo sang TRÁI: mọi thứ nằm giữa tiến một bậc sang phải.
        return (tracked >= destination && tracked < source) ? tracked + 1 : tracked
    }
}
