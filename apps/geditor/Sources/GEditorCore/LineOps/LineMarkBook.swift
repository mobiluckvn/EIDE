import Foundation

/// Chín tập đánh dấu ĐỘC LẬP — phần còn lại của FR-SRCH-107 ("bookmark tối thiểu 9 màu độc lập").
///
/// Vì sao phải độc lập chứ không phải một tập có thuộc tính màu: cái người dùng làm với nó là
/// đánh dấu BA pattern khác nhau bằng ba màu rồi so chúng trên cùng một màn hình — "dòng nào
/// vừa có ERROR vừa có timeout". Một dòng thuộc nhiều màu cùng lúc là chuyện thường, nên màu
/// không thể là thuộc tính của dòng.
///
/// Chỉ số màu chạy 0…8. Số 0 là màu mặc định, và nó dùng đúng token `mark/line` mà UI/UX §2 đã
/// quy định — không đặt màu mới cho việc đã có chuẩn.
public struct LineMarkBook: Equatable {

    public static let colorCount = 9

    private var sets: [LineMarkSet]

    /// Màu mà thao tác "đánh dấu" kế tiếp sẽ dùng.
    public private(set) var activeColor: Int

    public init() {
        sets = Array(repeating: LineMarkSet(), count: Self.colorCount)
        activeColor = 0
    }

    // MARK: - Đọc

    public subscript(color: Int) -> LineMarkSet {
        get { sets[Self.clamp(color)] }
        set { sets[Self.clamp(color)] = newValue }
    }

    public var active: LineMarkSet {
        get { sets[activeColor] }
        set { sets[activeColor] = newValue }
    }

    public var isEmpty: Bool { sets.allSatisfy(\.isEmpty) }

    /// Mọi dòng đang được đánh dấu, bất kể màu.
    ///
    /// Đây là tập mà các phép LỌC làm việc trên đó (chép, xóa, chỉ giữ dòng đánh dấu). Quy tắc
    /// là "cái gì đang thấy tô nền thì thao tác chạm tới" — dự đoán được mà không cần đọc tài
    /// liệu. Lọc theo riêng một màu là việc của menu, không phải mặc định.
    public var union: LineMarkSet {
        var all = Set<Int>()
        for set in sets { all.formUnion(set.lines) }
        return LineMarkSet(all)
    }

    public var count: Int { union.count }

    /// Các màu đang đánh dấu một dòng, tăng dần.
    public func colors(at line: Int) -> [Int] {
        (0 ..< Self.colorCount).filter { sets[$0].contains(line) }
    }

    /// Màu dùng để TÔ dòng khi nó mang nhiều dấu.
    ///
    /// Lấy màu nhỏ nhất chứ không lấy màu vừa thêm: cùng một tài liệu phải trông giống nhau ở
    /// hai lần mở, và "màu vừa thêm" là thứ phụ thuộc thứ tự thao tác.
    public func displayColor(at line: Int) -> Int? {
        (0 ..< Self.colorCount).first { sets[$0].contains(line) }
    }

    // MARK: - Sửa

    public mutating func setActiveColor(_ color: Int) { activeColor = Self.clamp(color) }

    /// Bật/tắt dấu ở màu đang chọn (⌘F2 theo keymap UI/UX §9).
    public mutating func toggle(_ line: Int) { sets[activeColor].toggle(line) }

    public mutating func clearActive() { sets[activeColor].clear() }

    public mutating func clearAll() {
        sets = Array(repeating: LineMarkSet(), count: Self.colorCount)
    }

    /// Đảo dấu của màu đang chọn trên toàn tài liệu.
    public mutating func invertActive(lineCount: Int) { sets[activeColor].invert(lineCount: lineCount) }

    // MARK: - Điều hướng (F2 / ⇧F2)

    /// Dòng đánh dấu KẾ TIẾP sau `line`, quay vòng về đầu tài liệu.
    ///
    /// Quay vòng cùng lý do như ⌘D ở multi-caret: tới dấu cuối rồi bấm tiếp mà không có gì xảy
    /// ra thì người dùng tưởng phím hỏng. Trả `nil` chỉ khi KHÔNG có dấu nào.
    ///
    /// `color` là `nil` thì đi qua mọi màu.
    ///
    /// **`withinLineCount` là BẮT BUỘC, và đó là chủ ý.** Dấu là SỐ DÒNG, còn nội dung thì đổi
    /// dưới chân nó: đánh dấu dòng 40 rồi xoá gần hết tài liệu thì dấu ấy trỏ vào một dòng
    /// không còn tồn tại. Chỗ gọi lấy số dòng ấy đi hỏi `offset(ofLineStart:)` — một hàm có
    /// `precondition` — nên nó không hiện sai một con số, nó làm app SẬP.
    ///
    /// Bộ chạy dài `--soak` tìm ra ở bước 337 (NFR-REL-03): đánh dấu, xoá cho tài liệu rỗng,
    /// rồi bấm F2. Các phép khác của `LineMarks` (xoá dòng đã đánh dấu, chép, giữ lại) vốn đã
    /// tự chặn bằng `line < ranges.count`; chỉ đường ĐIỀU HƯỚNG là quên.
    ///
    /// Để tham số này có giá trị mặc định thì chỗ gọi lại được phép quên, và cái quên ấy chỉ
    /// lộ ra khi tài liệu vừa co lại — tức là hiếm, và luôn ở tay người dùng chứ không ở tay
    /// người viết mã.
    public func nextMarkedLine(after line: Int, withinLineCount lineCount: Int,
                               color: Int? = nil) -> Int? {
        let lines = linesFor(color).filter { $0 < lineCount }
        guard !lines.isEmpty else { return nil }
        return lines.first { $0 > line } ?? lines.first
    }

    public func previousMarkedLine(before line: Int, withinLineCount lineCount: Int,
                                   color: Int? = nil) -> Int? {
        let lines = linesFor(color).filter { $0 < lineCount }
        guard !lines.isEmpty else { return nil }
        return lines.last { $0 < line } ?? lines.last
    }

    private func linesFor(_ color: Int?) -> [Int] {
        guard let color else { return union.sorted }
        return sets[Self.clamp(color)].sorted
    }

    private static func clamp(_ color: Int) -> Int {
        Swift.min(Swift.max(color, 0), colorCount - 1)
    }
}
