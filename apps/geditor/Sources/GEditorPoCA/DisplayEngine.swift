import AppKit

/// Hai ứng viên engine hiển thị của ADR-01 phải chịu ĐÚNG MỘT phép đo.
///
/// Giao diện này tồn tại để không ai đo Scintilla một kiểu và TextKit 2 một kiểu khác rồi so
/// hai con số không cùng đơn vị. Mỗi thao tác ở đây là một thứ người dùng làm được, và phần
/// đo nằm ở `PoCRunner` — không nằm trong adapter, để adapter không tự "giúp" mình nhanh lên.
protocol DisplayEngine: AnyObject {

    var name: String { get }
    var view: NSView { get }

    /// Nạp nội dung UTF-8. Ném lỗi/`false` nếu engine không nhận nổi cỡ này.
    func load(_ bytes: [UInt8]) throws

    /// Đặt caret vào đầu dòng `line`. NGOÀI vùng đo — mỗi engine dùng line index của nó.
    func beginTyping(atLine line: Int)

    /// Gõ một ký tự tại caret nội bộ rồi tự đẩy caret lên.
    ///
    /// Tách khỏi `beginTyping` là CHỦ Ý. Bản đầu tôi viết `insert(_:at:)` theo vị trí byte,
    /// và bản dựng TextKit 2 phải quét cả chuỗi để đổi byte → UTF-16 ở MỖI lần gõ: O(n) trên
    /// 500 MB. Số đo khi ấy nói về hàm đổi chỉ số của tôi chứ không nói về TextKit 2.
    func typeOneCharacter(_ text: String)

    /// Ép engine dựng bố cục và VẼ XONG.
    ///
    /// Đây là phần đắt nhất và cũng là phần người dùng cảm thấy. Đo mỗi thao tác chèn mà
    /// không ép vẽ là đo một hàng đợi rỗng: cả hai engine sẽ đều "1 microgiây" và con số ấy
    /// không nói được gì về việc gõ có giật hay không.
    func forceDisplay()

    /// Đặt N caret rời (FR-CORE-001). `nil` = engine KHÔNG hỗ trợ — bản thân đó là kết quả.
    func setCarets(_ positions: [Int]) -> Bool

    /// Chọn khối chữ nhật qua `lines` dòng (column mode). `false` = không hỗ trợ.
    func selectRectangle(fromLine: Int, toLine: Int, column: Int) -> Bool

    func scrollToLine(_ line: Int)

    var documentLength: Int { get }
    var lineCount: Int { get }

    /// Số lần view VẼ XONG kể từ lần gọi trước, rồi đặt lại về 0.
    ///
    /// Phép đo phải tự chứng minh mình. Gõ 300 phím mà không có lần vẽ nào thì con số latency
    /// là latency của một view lười, và so hai con số lười với nhau không kết luận được gì.
    func takePaintCount() -> Int

    /// Cỡ view và số dòng đang hiện — báo cáo phải nói rõ nó đo trên khung nhìn nào.
    var viewportDescription: String { get }

    /// Độ dài nội dung theo đơn vị RIÊNG của engine (Scintilla: byte; TextKit: UTF-16).
    ///
    /// Dùng để phép đo tự chứng minh lần nữa: gõ 300 phím thì độ dài phải tăng đúng 300 đơn
    /// vị. Không kiểm thì một caret đặt sai chỗ hoặc một lần chèn bị nuốt sẽ biến thành
    /// "engine này gõ nhanh lắm".
    var nativeLength: Int { get }

    /// Vị trí caret hiện tại theo đơn vị riêng của engine.
    var caretPosition: Int { get }

    /// Nơi bộ gõ nói chuyện với engine. `nil` = engine không nhận được input của hệ thống,
    /// và với NFR-USE-02 thì bản thân điều đó đã là một kết quả.
    var inputClient: NSTextInputClient? { get }

    /// Đưa tài liệu về rỗng và đặt caret ở đầu — dùng trước mỗi kịch bản gõ.
    func resetDocument()

    /// Toàn bộ nội dung. Chỉ dùng khi kiểm, tài liệu lúc đó rất nhỏ.
    func documentText() -> String

    /// Đặt con trỏ ngay sau `prefix`. Engine tự quy đổi sang đơn vị của mình.
    func placeCaret(after prefix: String)

    /// `true` nếu `nativeLength` đếm BYTE, `false` nếu đếm đơn vị UTF-16.
    ///
    /// Engine tự khai thay vì để chỗ đo đoán theo kiểu lớp: đoán sai thì phép tự kiểm báo
    /// động giả, và một phép kiểm hay báo động giả sẽ bị bỏ qua đúng lúc nó nói thật.
    var countsBytes: Bool { get }
}

enum EngineError: Error, CustomStringConvertible {
    case refused(String)

    var description: String {
        switch self { case .refused(let why): return why }
    }
}
