import Foundation

/// Hai chế độ hiển thị của MỌI tệp: **View** và **Code**.
///
/// ## Vì sao cần một mô hình chung
///
/// Trước tệp này, sản phẩm đã có sáu cặp "xem / sửa" nhưng mỗi cặp một tên và một phím: bảng CSV
/// gọi là *"Xem dạng bảng / văn bản"*, Markdown gọi là *"Xem trước"*, media gọi là *"Xem nhị
/// phân"*, Mermaid và báo cáo lại gọi là *"xem trước"* nhưng mở ra khung khác. Cùng một ý niệm,
/// sáu cái tên — và người dùng phải học lại ở mỗi loại tệp.
///
/// Ở đây gom về một mô hình, và mô hình ấy là **nguồn sự thật duy nhất**: lệnh đổi chế độ đọc
/// nó, trang trợ giúp mô tả nó, và một bài kiểm đối chiếu hai thứ ấy với nhau.
///
/// ## Định nghĩa
///
/// - **Code** là bản GỐC sửa được. Với tệp văn bản đó là chính văn bản; với tệp nhị phân —
///   PDF, ảnh, nhạc, phim — không có nguồn văn bản nào, nên Code là **byte**. Nói "loại này
///   không có chế độ Code" thì tiện hơn nhưng sai: byte đúng là nguồn của chúng.
/// - **View** là bản DỰNG RA từ Code. Nó có thể đẹp hơn, gọn hơn, hoặc chạy được — nhưng nó
///   luôn là hệ quả, không phải bản gốc.
///
/// ## Luật: sửa ở Code, trừ hai ngoại lệ có chủ ý
///
/// Sửa xảy ra ở Code. Hai chỗ phá luật ấy, và cả hai đều vì thao tác ở View tự nhiên hơn hẳn:
/// **ô bảng CSV** và **ô biểu mẫu PDF**. Cả hai ghi thẳng vào nguồn, nên không sinh ra một bản
/// thứ hai để rồi phải hỏi bản nào đúng.
///
/// ## Không giả vờ
///
/// Vài loại **chưa có** View — XML, YAML, sơ đồ trong tab, dàn ý PowerPoint. Mô hình nói thẳng
/// điều đó qua `DisplayModes.viewImplemented`, và lệnh đổi chế độ trả lời "chưa có" kèm TÊN thứ
/// còn thiếu, thay vì mở ra một khung trống. Một khung trống là lời hứa suông; một câu từ chối
/// có tên gọi là thông tin.
public enum DisplayView: String, Equatable, Sendable, CaseIterable {

    /// Chữ đã dựng — Markdown, Word.
    case renderedText
    /// Bảng hàng–cột — CSV, TSV, sheet của Excel.
    case table
    /// Sơ đồ — Mermaid, DOT.
    case diagram
    /// Cây khoá–giá trị — JSON, XML, YAML.
    case tree
    /// Trang tài liệu dựng ra — PDF.
    case document
    case image
    /// Bộ phát nhạc hoặc phim.
    case player
    /// Danh sách mục trong tệp nén.
    case archiveList
    /// Báo cáo đã chạy truy vấn và vẽ biểu đồ — `.greport.md`.
    case report
    /// Tô theo mức nghiêm trọng, lọc được — tệp log.
    case logLevels
    /// Dàn ý slide — PowerPoint.
    case outline
    /// Loại này không có gì để dựng ra.
    case none

}

/// Bản gốc sửa được.
public enum DisplayCode: String, Equatable, Sendable {
    /// Chính văn bản đang mở trong khung soạn thảo.
    case source
    /// Byte của tệp, hiện dưới dạng hex.
    case binary
}

/// Nơi người dùng sửa được nội dung.
public enum DisplayEditing: String, Equatable, Sendable {
    /// Chỉ ở Code.
    case codeOnly
    /// Cả hai — ô bảng CSV, ô biểu mẫu PDF.
    case both
    /// Không sửa được nội dung (ảnh, nhạc, phim, tệp nén).
    case readOnly
}

public struct DisplayModes: Equatable, Sendable {
    public let view: DisplayView
    public let code: DisplayCode
    public let editing: DisplayEditing

    /// Chế độ View của loại tệp NÀY đã dựng được chưa.
    ///
    /// **Theo từng loại tệp, không theo kiểu View.** Bản đầu để cờ này trên `DisplayView`, và nó
    /// sai ngay khi cây JSON dựng xong còn cây XML thì chưa: cả hai cùng là `.tree`, nhưng một
    /// cái mở được và một cái không. Đặt ở đây thì mỗi nhánh của `of(path:kind:language:)` tự khai
    /// đúng sự thật của nhánh mình.
    public let viewImplemented: Bool

    public init(
        view: DisplayView, code: DisplayCode, editing: DisplayEditing,
        viewImplemented: Bool = true
    ) {
        self.view = view
        self.code = code
        self.editing = editing
        self.viewImplemented = viewImplemented
    }

    /// Loại này đổi qua lại được giữa hai chế độ chưa.
    public var canToggle: Bool { view != .none && viewImplemented }
}

extension DisplayModes {

    /// Hai chế độ của một tệp.
    ///
    /// Quyết định theo **loại media trước, rồi mới tới ngôn ngữ cú pháp**: một tệp `.json` nằm
    /// trong tệp nén thì cái người dùng đang xem là tệp nén, không phải JSON.
    public static func of(path: String, kind: MediaKind?, language: SyntaxLanguage?)
        -> DisplayModes {
        if let kind {
            switch kind {
            case .pdf:
                // Sửa được NGAY Ở VIEW: chú thích, ô biểu mẫu, thao tác trang. Không có nguồn
                // văn bản nào để mà sửa, nên Code là byte.
                return DisplayModes(view: .document, code: .binary, editing: .both)
            case .image:
                return DisplayModes(view: .image, code: .binary, editing: .readOnly)
            case .audio, .video:
                return DisplayModes(view: .player, code: .binary, editing: .readOnly)
            case .archive:
                return DisplayModes(view: .archiveList, code: .binary, editing: .readOnly)
            case .excel:
                // Excel về thẳng bảng CSV của sản phẩm; Code là CSV của sheet đang mở.
                return DisplayModes(view: .table, code: .source, editing: .both)
            case .word:
                return DisplayModes(view: .renderedText, code: .source, editing: .codeOnly)
            case .powerpoint:
                // View là TRANG SLIDE dựng ra — hộp chữ đúng chỗ, nền, ảnh, cỡ chữ theo master.
                // Dàn ý không mất: nó là nút riêng ở khung chung, và nó mới là thứ SỬA ĐƯỢC.
                // Code là chính dàn ý Markdown ấy, sửa rồi ghi ngược vào slide.
                return DisplayModes(view: .outline, code: .source, editing: .codeOnly)
            }
        }

        let name = (path as NSString).lastPathComponent.lowercased()
        if name.hasSuffix(".greport.md") {
            return DisplayModes(view: .report, code: .source, editing: .codeOnly)
        }
        switch (path as NSString).pathExtension.lowercased() {
        case "md", "markdown", "mdown":
            return DisplayModes(view: .renderedText, code: .source, editing: .codeOnly)
        case "csv", "tsv", "tab":
            return DisplayModes(view: .table, code: .source, editing: .both)
        case "mmd", "mermaid", "dot", "gv":
            // Sơ đồ chiếm trọn tab; Code là chính nguồn mermaid hoặc DOT. Bảng Mermaid Studio
            // bên cạnh vẫn còn — nó là chỗ soạn, còn tab là chỗ NHÌN.
            return DisplayModes(view: .diagram, code: .source, editing: .codeOnly)
        case "log":
            return DisplayModes(view: .logLevels, code: .source, editing: .codeOnly)
        default:
            break
        }
        switch language {
        case .json:
            // Cây JSON đã dựng được — `StructureTree.json` dùng lại `JSONIndex`.
            return DisplayModes(view: .tree, code: .source, editing: .codeOnly)
        case .xml, .html:
            // Cây XML đã dựng được — `StructureTree.xml` chạy trên `XMLIndex`.
            return DisplayModes(view: .tree, code: .source, editing: .codeOnly)
        case .yaml:
            // Cây YAML đã dựng được — `StructureTree.yaml` chạy trên `YAMLIndex`. Không dùng
            // `YAMLReader`: nó trả cây giá trị KHÔNG kèm khoảng byte, mà một cây không nhảy về
            // nguồn được thì chỉ là bản in đẹp.
            return DisplayModes(view: .tree, code: .source, editing: .codeOnly)
        default:
            // Mã nguồn và văn bản thuần: chỉ có một chế độ, và đó là chuyện bình thường chứ
            // không phải thiếu sót. Một tệp Swift không có "bản dựng ra" nào đáng xem.
            return DisplayModes(view: .none, code: .source, editing: .codeOnly,
                                viewImplemented: false)
        }
    }
}
