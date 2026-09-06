import AppKit

/// Lượt chạy KHÔNG có ai ngồi trước máy — `--self-test`, `--capture`, `--measure-startup`,
/// `--soak`, `--measure-idle`.
///
/// **Vì sao cần biết điều này.** `NSAlert.runModal()` chờ một cú bấm. Không có ai bấm thì nó
/// chờ mãi mãi, và cả lượt chạy treo theo — không đỏ, không lỗi, không dòng log nào. Bộ tự
/// kiểm đứng im giữa chừng và triệu chứng duy nhất là "sao hôm nay chạy lâu thế".
///
/// Chuyện này đã xảy ra hai lần. Lần đầu vá riêng cho `closeTab(at:force:)`. Lần hai — bài
/// kiểm "tab đang GHIM" mở một file chưa từng tạo — treo qua `presentError`, và lúc ấy mới rõ
/// vá từng chỗ là sai hướng: trong `MainWindowController` có 28 chỗ gọi `runModal()`.
///
/// **Chia làm hai loại, và chỉ một loại tự trả lời được.**
///
/// - Hộp thoại chỉ BÁO TIN (`presentError`) không hỏi gì cả. Ở lượt chạy không người, nó ghi
///   lại rồi đi tiếp — không mất thông tin nào, vì thứ nó định nói đã nằm trong `lastError`
///   để bài kiểm đọc.
/// - Hộp thoại HỎI ("đóng tab chưa lưu?", "ghi đè?") thì tự chọn hộ là quyết định thay người
///   dùng, và một bài kiểm chạy trên câu trả lời do chính nó bịa ra thì không kiểm gì cả. Nên
///   `ask` trả `.abort` — khác mọi nút, nên chỗ gọi tự đi nhánh "người dùng huỷ" vốn đã có sẵn.
///   Chỗ nào bài kiểm THẬT SỰ muốn thao tác chạy tới cùng thì nói ra bằng tham số kiểu `force:`.
///
/// **Cả 13 chỗ hỏi trong app giờ đi qua `ask`.** Đã kiểm ngược: gỡ nhánh `isActive` ra rồi chạy
/// lại thì bộ tự kiểm đứng im ở 0/174 sau 200 giây, không in nổi một dòng nào. Đó chính là kiểu
/// hỏng mà tệp này sinh ra để chặn — và nó lặng lẽ tới mức trông như máy chậm.
///
/// **Cờ này KHÔNG được dùng để đổi hành vi sản phẩm.** Nó chỉ nói "không có ai bấm được".
/// Một nhánh `if isActive` bọc quanh logic thật sẽ biến bộ tự kiểm thành thứ kiểm một chương
/// trình khác với chương trình ta giao — đúng cái bẫy mà `run-startup-kpi.sh` đã ghi cảnh báo.
enum Unattended {

    /// Đọc `CommandLine` MỘT lần, lúc dùng đầu tiên.
    ///
    /// `static let` chứ không phải thuộc tính tính toán: `presentError` gọi được từ đường gõ
    /// phím, và quét lại mảng đối số ở mỗi lần là việc thừa ở đúng chỗ không nên có việc thừa.
    static let isActive: Bool = {
        // `--office-e2e` phải có mặt ở đây, và nó đã VẮNG ở bản đầu. Hậu quả không phải một
        // bài kiểm đỏ: khi phép ghi Office hỏng, `presentError` dựng một `NSAlert` modal và cả
        // bộ E2E ĐỨNG MÃI — không đỏ, không xanh, chỉ treo. Một bộ kiểm treo ở nhánh lỗi là bộ
        // kiểm chỉ chạy được khi sản phẩm đúng.
        let flags: Set<String> = ["--self-test", "--capture", "--measure-startup", "--soak",
                                  "--measure-idle", "--office-e2e", "--doc-sweep",
                                  "--measure-open"]
        return CommandLine.arguments.contains { flags.contains($0) }
    }()

    /// Lỗi gần nhất mà app định đưa ra cho người dùng, dạng "tiêu đề: chi tiết".
    ///
    /// Có mặt để một bài kiểm khẳng định được rằng thao tác vừa rồi hỏng ĐÚNG cách nó phải
    /// hỏng. Không có nó thì "app nuốt lỗi" và "app không gặp lỗi" trông giống hệt nhau.
    private(set) static var lastError: String?

    /// Số lỗi đã đưa ra kể từ lần `resetLog()` gần nhất.
    private(set) static var errorCount = 0

    /// Ghi lại một lỗi thay cho việc hiện hộp thoại.
    static func recordError(_ title: String, _ detail: String) {
        lastError = "\(title): \(detail)"
        errorCount += 1
        // In ra luôn: bài kiểm đọc `lastError`, nhưng người đọc log lúc gỡ lỗi thì không.
        NSLog("[GEditor] (không người) %@: %@", title, detail)
    }

    /// Câu hỏi gần nhất mà app định đặt ra cho người dùng.
    private(set) static var lastPrompt: String?

    /// Số hộp thoại HỎI đã bị chặn kể từ lần `resetLog()` gần nhất.
    private(set) static var promptCount = 0

    /// Chạy một hộp thoại HỎI.
    ///
    /// Ở lượt chạy bình thường: hiện ra và chờ người dùng bấm, y như trước.
    ///
    /// Ở lượt không có ai ngồi trước máy: **không tự trả lời hộ**, mà trả về `.abort`. Giá trị
    /// ấy khác mọi nút, nên `guard … == .alertFirstButtonReturn else { return }` ở chỗ gọi tự đi
    /// nhánh "người dùng huỷ" — nhánh an toàn, và nó vốn đã có sẵn ở mọi chỗ gọi. Không có
    /// nhánh nào phải viết mới, và không chỗ nào bị quyết định thay.
    ///
    /// **Vì sao không auto-bấm nút "Đồng ý".** Vì thế là bịa ra câu trả lời của người dùng, và
    /// một bài kiểm chạy trên câu trả lời do chính nó bịa thì không kiểm gì cả. Chỗ nào bài
    /// kiểm THẬT SỰ muốn thao tác chạy tới cùng thì nói ra bằng tham số kiểu `force:` —
    /// `closeTab(at:force:)` là tiền lệ.
    ///
    /// Nhãn lấy từ chính `alert.messageText` chứ không truyền tay: nhãn viết tay sẽ lệch khỏi
    /// hộp thoại ngay lần đầu ai đó sửa câu chữ, và khi ấy nó chỉ ra chỗ sai.
    static func ask(_ alert: NSAlert) -> NSApplication.ModalResponse {
        guard isActive else { return alert.runModal() }
        lastPrompt = alert.messageText
        promptCount += 1
        NSLog("[GEditor] (không người) bỏ qua câu hỏi: %@", alert.messageText)
        return .abort
    }

    // MARK: - Rác tạm của lượt chạy

    /// Những thư mục tạm mà lượt chạy này đã tạo.
    ///
    /// Bộ tự kiểm trỏ kho phiên, kho bản nháp và kho macro vào thư mục TẠM — bắt buộc, vì
    /// không thế thì nó ghi đè lên phiên làm việc THẬT của người đang chạy máy. Nhưng không ai
    /// dọn: mỗi lượt `--self-test` để lại 28 thư mục, và trên máy này đã đọng **5.357 thư mục,
    /// 62 MB** trước khi có đoạn mã này.
    ///
    /// Không phải lỗi sản phẩm — cả hai đường tạo đều là `…ForSelfTest`, người dùng không bao
    /// giờ đi qua. Nhưng nó là rác đổ vào máy người sửa mã, và nó lớn lên mãi.
    private(set) static var temporaryRoots: [URL] = []

    static func registerTemporaryRoot(_ url: URL) { temporaryRoots.append(url) }

    /// Dọn rác tạm — **chỉ gọi khi lượt chạy ĐẠT**.
    ///
    /// Lượt chạy trượt thì giữ nguyên: thư mục tạm là bằng chứng. Một bài kiểm phiên làm việc
    /// đỏ mà kho phiên của nó đã bị xoá thì người sửa chỉ còn mỗi dòng thông báo để đoán.
    static func removeTemporaryRoots() {
        for root in temporaryRoots { try? FileManager.default.removeItem(at: root) }
        temporaryRoots.removeAll()
    }

    /// Mở một hộp CHỌN FILE (`NSOpenPanel` / `NSSavePanel`).
    ///
    /// **Cùng lớp lỗi với `NSAlert.runModal()`, và bị bỏ sót lâu hơn.** `ask` chặn được hộp
    /// thoại HỎI, nhưng hộp chọn file là một `runModal` khác: nó cũng chờ một cú bấm không bao
    /// giờ tới trong lượt chạy không người, và cả lượt chạy treo theo — không đỏ, không lỗi.
    ///
    /// Có 16 chỗ mở panel trong `MainWindowController`, và trước khi có hàm này thì KHÔNG chỗ
    /// nào được chặn. Chúng chưa treo bao giờ chỉ vì chưa bài kiểm nào bấm tới — tức là một quả
    /// mìn chờ người đầu tiên thêm "mở file…" vào bộ chạy dài.
    ///
    /// Trả `.abort` chứ không tự chọn một file: bịa ra lựa chọn của người dùng thì bài kiểm chạy
    /// trên câu trả lời do chính nó dựng, và như thế không kiểm gì cả. `.abort` khác mọi nút nên
    /// `guard … == .OK` ở chỗ gọi tự đi nhánh "người dùng huỷ" vốn đã có sẵn.
    static func chooseFile(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
        guard isActive else { return panel.runModal() }
        lastPrompt = panel.message ?? panel.title
        promptCount += 1
        NSLog("[GEditor] (không người) bỏ qua hộp chọn file: %@", lastPrompt ?? "")
        return .abort
    }

    /// Xoá sổ ghi. Bài kiểm gọi trước khi cố tình gây lỗi, để đọc được đúng lỗi của mình.
    static func resetLog() {
        lastError = nil
        errorCount = 0
        lastPrompt = nil
        promptCount = 0
    }
}
