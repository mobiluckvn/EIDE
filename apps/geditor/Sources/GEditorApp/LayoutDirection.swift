import AppKit

/// Đảo chiều giao diện cho tiếng Ả Rập · Do Thái · Ba Tư · Urdu (FR-UI-804).
///
/// # Vì sao gần như không phải sửa gì
///
/// Vì cột dọc và mọi panel đã neo bằng `leadingAnchor`/`trailingAnchor` từ đầu — 328 chỗ, và
/// **không một chỗ nào** dùng `leftAnchor`/`rightAnchor`. Auto Layout tự giải leading thành mép
/// PHẢI khi chiều viết là phải-sang-trái, nên đặt `userInterfaceLayoutDirection` là cả cửa sổ
/// lật gương: sidebar sang phải, thanh cuộn đổi bên, panel đảo đầu.
///
/// Nếu hồi ấy ai đó viết `leftAnchor` cho tiện thì hôm nay là 328 chỗ phải đọc lại từng cái, và
/// mỗi cái là một cơ hội bỏ sót — thứ chỉ lộ ra dưới mắt người đọc tiếng Ả Rập.
///
/// # Thứ KHÔNG được lật
///
/// Chiều viết của giao diện và chiều viết của NỘI DUNG là hai chuyện khác nhau. Người Ả Rập
/// soạn một tệp CSV hay một câu SQL thì tệp ấy vẫn là trái-sang-phải: `SELECT * FROM x` đảo
/// chiều là vô nghĩa, và một đường dẫn `/Users/…` đảo chiều thì không còn đọc được. Xem
/// `applyContentDirection`.
enum LayoutDirection {

    static var isRTL: Bool { L10n.effective.isRTL }

    /// Áp chiều viết lên cả cây view của cửa sổ.
    ///
    /// Đặt ở view GỐC chứ không đi từng view con: `userInterfaceLayoutDirection` di truyền
    /// xuống, nên một lần đặt là đủ, và view nào dựng SAU cũng thừa hưởng — quan trọng, vì mười
    /// bốn panel của GEditor dựng lười, có cái mãi tới lúc người dùng bấm menu mới ra đời.
    static func apply(to root: NSView) {
        root.userInterfaceLayoutDirection = isRTL ? .rightToLeft : .leftToRight
    }

    /// Ép một view về trái-sang-phải bất kể giao diện đang chiều nào.
    ///
    /// Dùng cho vùng chứa NỘI DUNG của người dùng: văn bản đang soạn, bảng CSV, ô nhập SQL,
    /// đường dẫn tệp. Nội dung không đổi chiều theo ngôn ngữ giao diện — người Ai Cập mở một
    /// tệp CSV tiếng Anh thì bảng ấy vẫn đọc từ trái.
    static func forceLeftToRight(_ view: NSView) {
        view.userInterfaceLayoutDirection = .leftToRight
    }
}

extension NSTextAlignment {

    /// Căn về mép ĐẦU dòng: trái khi viết trái-sang-phải, phải khi ngược lại.
    ///
    /// Có mặt vì `.left` và `.right` là hướng tuyệt đối, còn thứ giao diện cần gần như luôn là
    /// hướng tương đối. `.natural` của AppKit suy chiều từ CHỮ trong ô — nên một ô trống, hay
    /// một ô chứa toàn chữ số, sẽ căn sai trong giao diện Ả Rập; hai thứ ấy đầy trong bảng CSV.
    static var leadingEdge: NSTextAlignment { LayoutDirection.isRTL ? .right : .left }

    /// Căn về mép CUỐI dòng. Dùng cho cột số — số thứ tự dòng, số đếm, số tiền.
    static var trailingEdge: NSTextAlignment { LayoutDirection.isRTL ? .left : .right }
}
