import Foundation

/// Số học của việc cuộn dọc: quy đổi giữa DÒNG tài liệu và toạ độ y trên khung cuộn.
///
/// Tách hẳn khỏi view, và tách vì một lý do cụ thể: phần này đã sai một lần rồi mà không ai
/// thấy. "Đi tới dòng 5.000.000" trên file 500 MB đặt caret trượt, rồi thanh trạng thái đọc ra
/// vị trí của cửa sổ mới và báo dòng 5.014.364 — sai mười bốn nghìn dòng, im lặng. Số học nằm
/// lẫn trong view thì không có cách nào kiểm nó ngoài việc mở app lên và nhìn.
///
/// Hai chuyện làm nó khó hơn vẻ ngoài:
///
/// 1. **Trần chiều cao.** 7,3 triệu dòng × 17 pt là 124 triệu point; AppKit không xử lý đúng ở
///    cỡ ấy. Vượt trần thì khung bị NÉN và mọi toạ độ quy đổi theo tỉ lệ — cuộn vẫn tới đúng
///    chỗ, chỉ mất độ mịn khi kéo tay.
/// 2. **Ngắt dòng mềm (FR-CORE-015).** Bật wrap thì một DÒNG tài liệu chiếm nhiều HÀNG màn
///    hình, và số hàng ấy không biết được nếu chưa dựng bố cục cả tài liệu — điều không thể làm
///    với file 1 GB. Nên `rowsPerLine` ở đây là số ƯỚC LƯỢNG, đo từ phần tài liệu ĐÃ dựng bố
///    cục thật (xem `WindowedTextView`). Nói thẳng giới hạn: thanh cuộn chính xác ở vùng đã
///    xem và xấp xỉ ở vùng chưa xem.
public struct VerticalGeometry: Equatable {

    public let lineCount: Int
    public let lineHeight: Double
    /// Số HÀNG màn hình trung bình cho mỗi DÒNG tài liệu. Bằng 1 khi tắt ngắt dòng mềm.
    public let rowsPerLine: Double
    /// Lề trên + lề dưới của vùng chữ.
    public let insetHeight: Double
    public let maximumHeight: Double

    public init(
        lineCount: Int,
        lineHeight: Double,
        rowsPerLine: Double = 1,
        insetHeight: Double = 0,
        maximumHeight: Double = 4_000_000
    ) {
        self.lineCount = Swift.max(0, lineCount)
        // Chặn số vô nghĩa NGAY ở cửa vào. Chiều cao dòng bằng 0 sẽ thành chia cho 0 trong
        // `line(atY:)`, và một `rowsPerLine` là NaN (đo trên cửa sổ rỗng: 0 hàng / 0 dòng) sẽ
        // lan ra mọi phép tính rồi hiện thành khung cuộn biến mất.
        self.lineHeight = lineHeight.isFinite && lineHeight > 0 ? lineHeight : 1
        self.rowsPerLine = rowsPerLine.isFinite && rowsPerLine >= 1 ? rowsPerLine : 1
        self.insetHeight = insetHeight.isFinite && insetHeight >= 0 ? insetHeight : 0
        self.maximumHeight = maximumHeight.isFinite && maximumHeight > 0 ? maximumHeight : 1
    }

    /// Chiều cao một DÒNG tài liệu trước khi nén.
    public var unscaledLineHeight: Double { lineHeight * rowsPerLine }

    /// Chiều cao cả tài liệu nếu vẽ hết, chưa nén.
    public var contentHeight: Double {
        Double(lineCount) * unscaledLineHeight + insetHeight
    }

    /// Tỉ lệ nén, luôn ≤ 1.
    public var scale: Double {
        let content = contentHeight
        guard content > maximumHeight else { return 1 }
        return maximumHeight / content
    }

    /// Chiều cao khung cuộn thật sự đặt cho AppKit.
    ///
    /// Không bao giờ bằng 0: khung cuộn cao 0 thì `NSScrollView` coi như không có nội dung và
    /// tài liệu rỗng sẽ không đặt được caret.
    public var canvasHeight: Double { Swift.max(Swift.min(contentHeight, maximumHeight), 1) }

    /// Chiều cao một dòng SAU khi nén — đơn vị của mọi phép quy đổi bên dưới.
    private var rowStride: Double { Swift.max(unscaledLineHeight * scale, .leastNormalMagnitude) }

    /// Đỉnh của một dòng trên khung cuộn.
    public func y(ofLine line: Int) -> Double {
        Double(Swift.min(Swift.max(line, 0), Swift.max(lineCount - 1, 0))) * rowStride
    }

    /// Dòng nằm tại toạ độ y.
    ///
    /// Cộng epsilon trước khi lấy phần nguyên: khi tài liệu bị nén, `rowStride` xuống dưới 1 pt
    /// và `y(ofLine:)` rồi `line(atY:)` liên tiếp sẽ rơi xuống dòng LIỀN TRƯỚC vì sai số dấu
    /// phẩy động. Lệch một dòng mỗi lần cuộn nghe thì nhỏ, nhưng nó tích lại thành đúng cái lỗi
    /// 5.014.364 đã gặp.
    public func line(atY y: Double) -> Int {
        guard lineCount > 0, y.isFinite else { return 0 }
        let raw = (y / rowStride) + 1e-9
        guard raw > 0 else { return 0 }
        guard raw < Double(lineCount) else { return lineCount - 1 }
        return Swift.min(Int(raw), lineCount - 1)
    }
}
