import AppKit

/// Hiện ký tự ẩn (FR-ENC-205).
///
/// Bật/tắt theo TỪNG NHÓM như SRS đòi, không phải một công tắc chung: người sửa file CSV cần
/// thấy tab và khoảng trắng cuối dòng, còn người đọc log thì chỉ vướng mắt.
struct InvisibleOptions: Equatable {
    var spaces = false
    var tabs = false
    var lineEndings = false
    /// NBSP, ký tự zero-width, ký tự điều khiển — nhóm "nguy hiểm".
    var special = false

    var isAnyOn: Bool { spaces || tabs || lineEndings || special }

    static let allOn = InvisibleOptions(spaces: true, tabs: true, lineEndings: true, special: true)
}

/// Ký hiệu vẽ thay cho một ký tự ẩn.
enum InvisibleGlyph {

    /// Ký hiệu cho `scalar`, hoặc `nil` nếu ký tự đó không thuộc nhóm nào đang bật.
    ///
    /// Nhóm "đặc biệt" quan trọng hơn vẻ ngoài của nó: NBSP và ký tự zero-width là thủ phạm
    /// kinh điển của những lỗi "trông giống hệt mà không khớp" — dán từ web vào rồi tìm kiếm
    /// không ra, hoặc CSV lệch cột. Người dùng phải NHÌN THẤY chúng.
    static func symbol(for scalar: Unicode.Scalar, options: InvisibleOptions) -> String? {
        switch scalar {
        case " ":
            return options.spaces ? "·" : nil
        case "\t":
            return options.tabs ? "→" : nil
        case "\n":
            return options.lineEndings ? "¶" : nil
        case "\r":
            return options.lineEndings ? "␍" : nil
        case "\u{00A0}":                                   // NBSP
            return options.special ? "⍽" : nil
        case "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}":  // zero-width, BOM
            return options.special ? "▯" : nil
        default:
            // Ký tự điều khiển khác (trừ tab/xuống dòng đã xử lý ở trên).
            if options.special, scalar.value < 0x20 || scalar.value == 0x7F { return "▯" }
            return nil
        }
    }
}

/// Hộp giữ tùy chọn, DÙNG CHUNG giữa view và các đoạn bố cục.
///
/// Không chép tùy chọn vào từng đoạn: đoạn được tạo một lần rồi TextKit giữ lại và dùng tiếp,
/// nên bản chép sẽ đứng yên ở trạng thái lúc tạo. Bật "hiện ký tự ẩn" xong màn hình không đổi
/// gì, và bộ đếm nói thẳng ra: vẽ 4 đoạn, 0 ký hiệu.
final class InvisibleSettings {
    var options = InvisibleOptions()

    /// Có vẽ ký hiệu ngắt dòng mềm ở cuối mỗi hàng bị ngắt hay không (FR-CORE-015).
    ///
    /// Ở cùng hộp với ký tự ẩn vì cùng một lý do: đoạn bố cục được TextKit giữ lại sau khi
    /// dựng, nên trạng thái phải ĐỌC lúc vẽ chứ không chụp lúc tạo.
    var showsWrapMarker = false
}

/// Đoạn bố cục có vẽ thêm ký hiệu cho ký tự ẩn.
///
/// TextKit 2 không có `NSLayoutManager` để chèn vào lúc vẽ glyph như TextKit 1; đường được hỗ
/// trợ là thay `NSTextLayoutFragment` và vẽ đè sau khi gọi `super`.
final class InvisiblesLayoutFragment: NSTextLayoutFragment {

    /// Đọc tại lúc VẼ, không chụp lúc tạo.
    weak var settings: InvisibleSettings?
    var color: NSColor = Tokens.Color.invisibleInk

    private var options: InvisibleOptions { settings?.options ?? InvisibleOptions() }

    /// Đếm số lần vẽ — chỉ để chẩn đoán khi bật GEDITOR_TRACE_INVISIBLES.
    static var drawCount = 0
    static var symbolCount = 0
    /// Số ký hiệu ngắt dòng mềm đã vẽ — bài tự kiểm dùng để chứng minh nó THẬT SỰ hiện ra,
    /// chứ không phải chỉ có nhánh code đi qua.
    static var wrapMarkerCount = 0

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        Self.drawCount += 1
        if ProcessInfo.processInfo.environment["GEDITOR_TRACE_INVISIBLES"] != nil {
            NSLog("[GEditor] draw: bật=%@ · %d dòng con · settings=%@",
                  String(options.isAnyOn), textLineFragments.count,
                  settings == nil ? "NIL" : "có")
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Tokens.Font.editor(),
            .foregroundColor: color,
        ]

        if settings?.showsWrapMarker == true {
            drawWrapMarkers(at: point, in: context, attributes: attributes)
        }
        guard options.isAnyOn else { return }

        for lineFragment in textLineFragments {
            let text = lineFragment.attributedString.string
            guard let range = Range(lineFragment.characterRange, in: text) else { continue }

            var index = lineFragment.characterRange.location
            for character in text[range] {
                defer { index += character.utf16.count }
                guard let scalar = character.unicodeScalars.first,
                      let symbol = InvisibleGlyph.symbol(for: scalar, options: options)
                else { continue }

                // Vị trí ký tự do chính TextKit cấp — tự tính bề rộng chữ là sai ngay khi
                // font không đều hoặc có ligature.
                Self.symbolCount += 1
                let location = lineFragment.locationForCharacter(at: index)
                let origin = CGPoint(
                    x: point.x + lineFragment.typographicBounds.origin.x + location.x,
                    y: point.y + lineFragment.typographicBounds.origin.y
                )
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
                (symbol as NSString).draw(at: origin, withAttributes: attributes)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }

    /// Ký hiệu ngắt dòng mềm — SRS FR-CORE-015 đòi "hiển thị ký hiệu wrap".
    ///
    /// Nó trả lời đúng một câu hỏi mà người dùng không tự trả lời được: dòng này xuống hàng vì
    /// tôi đã bấm Enter, hay vì cửa sổ hẹp? Với file CSV hay log thì hai chuyện ấy khác hẳn
    /// nhau, và đoán sai là sửa nhầm dữ liệu.
    ///
    /// `textLineFragments` là các HÀNG MÀN HÌNH của cùng một đoạn, nên mọi hàng trừ hàng CUỐI
    /// đều là chỗ bị ngắt mềm — không phải tự đi tìm chỗ gãy, TextKit đã chia sẵn.
    private func drawWrapMarkers(
        at point: CGPoint, in context: CGContext, attributes: [NSAttributedString.Key: Any]
    ) {
        guard textLineFragments.count > 1 else { return }

        for lineFragment in textLineFragments.dropLast() {
            let bounds = lineFragment.typographicBounds
            let origin = CGPoint(
                x: point.x + bounds.origin.x + bounds.width,
                y: point.y + bounds.origin.y
            )
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            Self.wrapMarkerCount += 1
            ("↩" as NSString).draw(at: origin, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
