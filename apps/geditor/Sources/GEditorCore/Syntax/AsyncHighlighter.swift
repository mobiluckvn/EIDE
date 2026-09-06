import Foundation

/// Chạy tô màu cú pháp NGOÀI luồng chính (ADR-04 §3).
///
/// Bắt buộc, không phải tối ưu: PoC-D đo phân tích một cửa sổ 2 MB mất **110–190 ms**. Làm
/// việc ấy trên luồng chính là treo giao diện gần một phần năm giây mỗi lần cuộn sang vùng mới
/// — trần NFR-PERF-04 cho một phím là vài mili-giây.
///
/// Ba chuyện lớp này phải làm đúng, và cả ba đều là chuyện sai lặng lẽ nếu làm ẩu:
///
/// 1. **Không đụng buffer ở luồng nền.** Yêu cầu mang theo BẢN SAO byte, chụp trên luồng gọi.
///    `TextBuffer` không an toàn đa luồng; đọc nó trong khi người dùng gõ không phải "có thể
///    sai màu" mà là đọc vào vùng nhớ đã bị dời.
/// 2. **Bỏ kết quả CŨ.** Người dùng cuộn nhanh thì nhiều yêu cầu chồng nhau; kết quả về muộn
///    của một cửa sổ đã trôi qua sẽ tô lên nội dung khác hẳn. Mỗi yêu cầu mang một số thứ tự,
///    và kết quả nào không phải số mới nhất thì vứt.
/// 3. **Huỷ việc đang chạy.** Cuộn qua mười cửa sổ mà không huỷ là xếp hàng mười lần phân
///    tích, mỗi lần 190 ms, và cái người dùng cần là cái cuối cùng.
public final class AsyncHighlighter {

    /// Kết quả của một lần tô, kèm số thứ tự để chỗ nhận biết nó còn mới hay không.
    public struct Result: Sendable {
        public let spans: [HighlightSpan]
        public let range: Range<Int>
        public let generation: Int
    }

    private let highlighter: SyntaxHighlighter
    private let queue: DispatchQueue
    private let lock = NSLock()

    private var latestGeneration = 0
    private var inFlight: CancelToken?

    public var language: SyntaxLanguage { highlighter.language }

    public init?(language: SyntaxLanguage) {
        guard let highlighter = SyntaxHighlighter(language: language) else { return nil }
        self.highlighter = highlighter
        // Hàng đợi NỐI TIẾP: hai lần phân tích song song chỉ tranh nhau CPU, vì kết quả cần
        // luôn là cái cuối cùng. Ưu tiên `.userInitiated` chứ không `.background`: người dùng
        // đang nhìn vào chỗ chờ tô màu.
        queue = DispatchQueue(label: "geditor.highlight", qos: .userInitiated)
    }

    /// Số thứ tự của yêu cầu mới nhất đã phát ra.
    public var currentGeneration: Int {
        lock.lock(); defer { lock.unlock() }
        return latestGeneration
    }

    /// Chụp yêu cầu trên luồng gọi rồi đẩy sang luồng nền.
    ///
    /// `completion` được gọi trên `deliverOn`. Trả về số thứ tự của yêu cầu vừa phát.
    @discardableResult
    public func request(
        buffer: TextBuffer,
        range: Range<Int>,
        deliverOn: DispatchQueue = .main,
        completion: @escaping (Result) -> Void
    ) -> Int {
        // Chụp TRƯỚC khi rời luồng này — đây là chỗ duy nhất được phép đụng vào buffer.
        let snapshot = highlighter.makeRequest(in: buffer, range: range)

        lock.lock()
        latestGeneration += 1
        let generation = latestGeneration
        inFlight?.cancel()
        let token = CancelToken()
        inFlight = token
        lock.unlock()

        guard let snapshot else {
            // Không có gì để tô (tài liệu rỗng, hoặc YAML file lớn). Vẫn TRẢ LỜI, để chỗ gọi
            // xoá được màu cũ — im lặng thì màu của cửa sổ trước còn nằm lại trên chữ mới.
            deliverOn.async { completion(Result(spans: [], range: range, generation: generation)) }
            return generation
        }

        queue.async { [weak self] in
            guard let self else { return }
            if token.isCancelled { return }
            let spans = self.highlighter.spans(for: snapshot, cancelToken: token)

            // Kiểm huỷ SAU khi tính xong. Đây là chỗ duy nhất chặn kết quả cũ, và nó đủ:
            // `request` huỷ token cũ TRƯỚC khi tăng số thứ tự, nên "kết quả này đã cũ" luôn
            // kéo theo "token này đã bị huỷ".
            //
            // Bản đầu còn một nhánh nữa so lại số thứ tự ở đây. Đối chứng âm cho thấy bỏ nhánh
            // ấy đi thì KHÔNG bài nào đỏ — vì nó không bao giờ chạy tới. Giữ lại một lớp bảo
            // vệ không bao giờ kích hoạt là tệ hơn không có: người đọc sau sẽ tin vào nó.
            if token.isCancelled { return }

            deliverOn.async {
                completion(Result(spans: spans, range: range, generation: generation))
            }
        }
        return generation
    }

    /// Huỷ việc đang chạy. Gọi khi tài liệu đóng hoặc cửa sổ đổi hẳn.
    public func cancel() {
        lock.lock()
        inFlight?.cancel()
        inFlight = nil
        latestGeneration += 1     // mọi kết quả đang bay đều thành cũ
        lock.unlock()
    }
}
