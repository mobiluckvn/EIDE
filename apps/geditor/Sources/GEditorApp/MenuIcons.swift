import AppKit

/// Biểu tượng cho từng mục menu — MỘT bảng, tra bằng đúng khoá mà `L()` dùng.
///
/// # Vì sao là bảng riêng chứ không phải phần tử thứ tư của tuple mục menu
///
/// `makeMenu` nhận `(nhãn, selector, phím)`. Thêm một ô nữa vào tuple là sửa 161 chỗ gọi, và
/// mỗi chỗ ấy là một cơ hội để lệch. Tệ hơn: nó trộn hai thứ khác hẳn nhau — CÁI MENU LÀM GÌ
/// (selector, phím tắt) và NÓ TRÔNG RA SAO. Đổi một biểu tượng lẽ ra không phải chạm vào dòng
/// khai báo lệnh.
///
/// Khoá là chuỗi tiếng Việt, GIỐNG HỆT khoá của bảng dịch. Không phải trùng hợp: cả hai đều
/// hỏi cùng một câu — "mục menu này là mục nào" — và dùng chung một khoá thì một mục đổi tên
/// làm cả hai bảng hụt cùng lúc, tức là cả hai cổng cùng đỏ. Hai hệ khoá riêng sẽ để một trong
/// hai âm thầm lệch.
///
/// # Vì sao chỉ lấy ký hiệu của SF Symbols 1–3
///
/// Đích triển khai là macOS 12 (Package.swift), tức SF Symbols 3. Một tên ra đời ở SF Symbols 4
/// vẫn dựng được trên máy phát triển chạy macOS mới, `NSImage` trả về ảnh, bài kiểm xanh — rồi
/// trên máy người dùng macOS 12 nó trả `nil` và mục menu MẤT biểu tượng, không báo gì. Cổng ở
/// `SelfTest` chỉ bắt được tên GÕ SAI, không bắt được tên ra đời quá muộn: hai lỗi ấy cho cùng
/// một triệu chứng `nil` trên máy này nhưng khác nhau trên máy kia. Nên hàng rào thật nằm ở
/// việc CHỌN: mọi tên dưới đây đều có từ SF Symbols 1 hoặc 2 (macOS 11), trừ vài chỗ ghi rõ.
///
/// Trùng biểu tượng giữa các menu khác nhau là CHẤP NHẬN ĐƯỢC và cố ý: "Cắt" ở menu Edit và
/// "Cắt khoảng trắng cuối dòng" ở menu Lines cùng là chiếc kéo vì chúng đúng là cùng một ý.
/// Ép mỗi mục một biểu tượng riêng sẽ đẻ ra những hình vô nghĩa chỉ để khác nhau.
enum MenuIcons {

    /// Những khoá đã được hỏi tới trong phiên này.
    ///
    /// Có để cổng chạy được HAI CHIỀU: thiếu biểu tượng thì đỏ, mà thừa một dòng cho mục menu
    /// đã bị xoá cũng đỏ. Chỉ chặn chiều thiếu thì bảng này sẽ dần thành nghĩa địa của những
    /// mục không còn tồn tại — đúng bài học của `menuItemsPendingImplementation`.
    private(set) static var daHoi: Set<String> = []

    /// Ảnh cho một mục menu, hoặc `nil` nếu mục ấy chưa khai biểu tượng.
    static func image(for key: String) -> NSImage? {
        daHoi.insert(key)
        guard let name = bang[key] else { return nil }
        return NSImage(systemSymbolName: name, accessibilityDescription: key)
    }

    /// Khoá khai trong bảng mà KHÔNG mục menu nào hỏi tới.
    static var khoaThua: [String] {
        bang.keys.filter { !daHoi.contains($0) }.sorted()
    }

    /// Khoá mà tên ký hiệu không dựng nổi ảnh trên máy này — gần như luôn là gõ sai tên.
    static var kyHieuKhongDung: [String] {
        bang.filter { NSImage(systemSymbolName: $0.value, accessibilityDescription: nil) == nil }
            .keys.sorted()
    }

    static let bang: [String: String] = [
        // --- App ---
        "Về GEditor": "info.circle",
        "Kiểm tra bản cập nhật…": "arrow.down.circle",
        "Cài đặt…": "gearshape",
        "Thoát GEditor": "power",

        // --- File ---
        "Tab mới": "plus.square.on.square",
        "Đóng tab": "xmark.square",
        "Tab kế": "arrow.right.square",
        "Tab trước": "arrow.left.square",
        "Tài liệu mới": "doc.badge.plus",
        "Cửa sổ mới": "macwindow",
        "Tách tab ra cửa sổ mới": "arrow.up.right.square",
        "Mở…": "folder",
        "Mở thư mục làm Workspace…": "folder.circle",
        "Mở gần đây": "clock.arrow.circlepath",
        "Lưu": "square.and.arrow.down",
        "Lưu thành…": "square.and.arrow.down.on.square",
        "Nhân bản tệp": "plus.square.on.square",
        "Đổi tên tệp…": "character.cursor.ibeam",
        "Chuyển tệp tới…": "folder.badge.gearshape",
        "Cắt khoảng trắng cuối dòng khi lưu": "scissors",
        "Theo dõi file (tail -f)": "eye",
        "In…": "printer",
        "Mở lại tab vừa đóng": "arrow.counterclockwise",

        // --- Edit ---
        "Hoàn tác": "arrow.uturn.left",
        "Làm lại": "arrow.uturn.right",
        "Cắt": "scissors",
        "Sao chép": "doc.on.doc",
        "Dán": "doc.on.clipboard",
        "Lịch sử clipboard…": "list.bullet.rectangle",
        "Column Editor…": "tablecells",
        "Chọn lần kế tiếp": "text.cursor",
        "Chọn tất cả": "checkmark.square",
        "Nhân đôi dòng": "plus.rectangle.on.rectangle",
        "Xóa dòng": "trash",
        "Comment dòng": "text.bubble",

        // --- Search ---
        "Tìm…": "magnifyingglass",
        "Tìm và thay…": "arrow.left.arrow.right",
        "Tìm trong thư mục…": "doc.text.magnifyingglass",
        "Thay trong thư mục…": "arrow.triangle.2.circlepath",
        "Kết quả kế": "chevron.down",
        "Kết quả trước": "chevron.up",
        "Đi tới dòng…": "number",
        "Nhảy tới ngoặc khớp": "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left",
        "Thử biểu thức chính quy…": "asterisk.circle",
        "Đánh dấu mọi dòng khớp…": "text.badge.checkmark",
        "Đảo dấu": "arrow.up.arrow.down",
        "Bỏ mọi dấu": "xmark.circle",
        "Chép dòng đã đánh dấu": "doc.on.doc",
        "Xóa dòng đã đánh dấu": "trash",
        "Chỉ giữ dòng đã đánh dấu": "line.horizontal.3.decrease",

        // --- Lines ---
        "Sắp xếp A→Z": "arrow.down",
        "Sắp xếp Z→A": "arrow.up",
        "Sắp xếp tự nhiên": "arrow.up.arrow.down",
        "Khử trùng lặp": "rectangle.on.rectangle",
        "Đảo thứ tự dòng": "arrow.up.and.down",
        "Dời dòng lên": "arrow.up.square",
        "Dời dòng xuống": "arrow.down.square",
        "Ghép dòng": "link",
        "Tách dòng theo độ dài…": "rectangle.split.1x2",
        "Tách dòng theo ký tự…": "rectangle.split.2x1",
        "Xóa dòng rỗng": "minus.circle",
        "Nén dòng trống liên tiếp": "arrow.down.right.and.arrow.up.left",
        "Cắt khoảng trắng cuối dòng": "scissors",
        "Tab → Space": "arrow.right.to.line.alt",
        "Space → Tab": "arrow.left.to.line.alt",
        "HOA": "textformat",
        "thường": "textformat.abc",
        "Chữ Hoa Đầu Từ": "textformat.abc.dottedunderline",
        "Chữ hoa đầu câu": "text.alignleft",
        "Đảo hoa/thường": "arrow.2.squarepath",
        "camelCase": "curlybraces",
        "snake_case": "underline",
        "kebab-case": "minus",

        // --- CSV ---
        "CSV: chọn sheet…": "square.stack",
        "Xem dạng bảng / văn bản": "tablecells",
        "Xóa cột…": "minus.rectangle",
        "Kiểm tra dữ liệu (số cột · kiểu)": "checkmark.seal",
        "Bàn làm sạch dữ liệu…": "wand.and.stars",
        "Trùng lặp mờ theo cột…": "rectangle.on.rectangle",
        "Mở triple/edge dạng bảng": "link.circle",
        "Xem trước cắt chunk…": "square.split.2x2",
        "Chuyển đổi tri thức…": "arrow.triangle.branch",
        "Khai phá văn bản (n-gram, TF-IDF)": "text.magnifyingglass",
        "Đánh dấu entity từ danh sách…": "tag",
        "Kiểm cú pháp đồ thị": "circle.hexagongrid",
        "Kiểm theo JSON Schema…": "checkmark.shield",
        "Chạy công thức làm sạch…": "play.rectangle",
        "Chuyển đổi…": "arrow.left.arrow.right.circle",
        "Đổi dấu phân tách…": "divide",
        "Xuất sang JSON…": "square.and.arrow.up",

        // --- Format ---
        "Bảng mã…": "character",
        "Xuống dòng…": "return",
        "Chuẩn hóa Unicode…": "character.textbox",
        "JSON: định dạng lại": "curlybraces",
        "JSON: thu gọn một dòng": "arrow.down.right.and.arrow.up.left",
        "JSON: sắp xếp khóa": "arrow.up.arrow.down.square",
        "JSON: truy vấn JSONPath…": "magnifyingglass.circle",
        "JSONL: kiểm và soi chunk…": "list.bullet.rectangle",
        // KHÔNG dùng "flask" dù nó đúng nghĩa "phòng thí nghiệm": ký hiệu ấy ra đời ở SF
        // Symbols 4 (macOS 13). Trên máy này nó dựng được, trên macOS 12 nó trả `nil`.
        "JSONL: phòng thí nghiệm truy hồi…": "chart.bar.xaxis",
        "CSV: truy vấn SQL…": "terminal",
        "CSV: chất lượng dữ liệu…": "checkmark.seal",
        "CSV: tìm bất thường…": "exclamationmark.triangle",
        "CSV: ma trận tương quan…": "square.grid.3x3",
        "CSV: phân cụm…": "circle.grid.hex",
        "CSV: dự báo chuỗi thời gian…": "waveform.path.ecg",
        "CSV: khai phá theo nhóm…": "chart.bar",
        "CSV: luật kết hợp…": "arrow.triangle.branch",
        "Báo cáo: xem trước": "doc.richtext",
        "Báo cáo: sinh loạt…": "doc.on.doc.fill",
        "Sơ đồ Mermaid: xem trước": "eye",
        "Sơ đồ Mermaid: chèn mẫu…": "square.grid.2x2",
        "Sơ đồ Mermaid: định dạng lại": "wand.and.rays",
        "Sơ đồ Mermaid: thêm phần tử…": "plus.circle",
        "Sơ đồ Mermaid: nối hai phần tử đang chọn": "link",
        "Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…": "pencil",
        "Sơ đồ Mermaid: xoá phần tử đang chọn": "trash",
        "Sơ đồ Mermaid: đưa message lên trên": "arrow.up.square",
        "Sơ đồ Mermaid: đưa message xuống dưới": "arrow.down.square",
        "Sơ đồ Mermaid: tách khối ra tệp .mmd…": "arrow.up.forward.square",
        "Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại": "arrow.down.left.square",
        "XML: định dạng lại": "chevron.left.slash.chevron.right",
        "XML: thu gọn một dòng": "arrow.down.right.and.arrow.up.left",
        "XML: kiểm cú pháp": "checkmark.circle",
        "XML: kiểm theo DTD/XSD…": "checkmark.shield",
        "XML: đánh giá XPath…": "location.magnifyingglass",
        "YAML: kiểm khóa trùng và thụt lề": "list.bullet.indent",
        "Xem trước Markdown": "doc.richtext",

        // --- View ---
        "Ẩn/hiện sidebar (Function List)": "sidebar.left",
        "Ẩn/hiện bản đồ tài liệu": "map",
        "Gấp / mở khối tại con nháy": "chevron.right.square",
        "Gấp tất cả": "arrow.down.right.and.arrow.up.left",
        "Bỏ gấp tất cả": "arrow.up.left.and.arrow.down.right",
        "Gấp theo cấp": "list.bullet.indent",
        "Phóng to chữ": "plus.magnifyingglass",
        "Thu nhỏ chữ": "minus.magnifyingglass",
        "Cỡ chữ gốc": "1.magnifyingglass",
        "Chia đôi theo chiều dọc": "rectangle.split.2x1",
        "Chia đôi theo chiều ngang": "rectangle.split.1x2",
        "Bỏ chia đôi": "rectangle",
        "Mở tab này ở nửa kia": "arrow.right.square",
        "Nhảy sang nửa kia": "arrow.left.arrow.right.square",
        "Ngắt dòng (tắt / cửa sổ / cột)": "text.alignleft",
        "Ngắt dòng tại cột…": "arrow.turn.down.left",
        "Đánh dấu dòng này": "bookmark",
        "Dấu kế tiếp": "arrow.down.to.line.alt",
        "Dấu trước đó": "arrow.up.to.line.alt",
        "Màu đánh dấu…": "paintpalette",
        "Hiện tất cả ký tự ẩn": "eye.slash",
        // Cùng lý do như "flask": "space" là SF Symbols 4. Dấu chấm vuông lại hợp hơn — đó
        // đúng là thứ trình soạn thảo vẽ ra ở chỗ một khoảng trắng.
        "  Khoảng trắng": "dot.square",
        "  Tab": "arrow.right.to.line.alt",
        "  Xuống dòng": "return",
        "  NBSP · zero-width · điều khiển": "questionmark.square",
        "Đổi chế độ View / Code": "rectangle.2.swap",
        "Xem nhị phân": "number.square",
        "Chế độ CSV (tô màu theo cột)": "tablecells.badge.ellipsis",
        "Chế độ Log (tô theo mức)": "doc.plaintext",
        "Lọc log theo mức…": "line.horizontal.3.decrease.circle",

        // --- Macro ---
        "Bắt đầu / dừng ghi": "record.circle",
        "Phát lại": "play",
        "Phát nhiều lần…": "repeat",
        "Phát đến cuối tài liệu": "forward.end",
        "Chạy trên mọi tab": "square.stack",
        "Chạy trên cả thư mục…": "folder.badge.gearshape",
        "Hủy macro đang chạy": "stop.circle",
        "Lưu macro…": "square.and.arrow.down",
        "Macro đã lưu…": "list.bullet",
        "Lọc qua lệnh ngoài…": "terminal",
        "Script…": "curlybraces.square",
        "Gói mở rộng…": "shippingbox",
        "Bản đã lưu…": "clock.arrow.circlepath",
        "Plugin native…": "puzzlepiece",

        // --- Menu ngữ cảnh trên hàng tiêu đề bảng CSV ---
        "Ẩn cột này": "eye.slash",
        "Đổi tên tiêu đề…": "pencil",
        "Chèn cột trống bên trái": "arrow.left.square",
        "Chèn cột trống bên phải": "arrow.right.square",
        "Xóa cột này khỏi file…": "trash",
        "Hiện lại: %@": "eye",

        // --- Help ---
        "Trợ giúp GEditor": "questionmark.circle",
        "Giới thiệu tính năng": "sparkles",
        "Di cư từ Notepad++": "arrow.right.doc.on.clipboard",
    ]
}
