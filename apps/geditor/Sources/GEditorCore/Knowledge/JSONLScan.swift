import Foundation

/// Chế độ JSONL: kiểm tra từng bản ghi của một tài liệu đang mở — FR-KNW-901.
///
/// Đặc tả: *"Mở file JSONL/NDJSON hàng GB trên hạ tầng Large File Mode: parse record-theo-dòng
/// streaming, validate JSON từng record, danh sách record lỗi nhảy tới dòng; xem record dạng
/// thẻ (pretty) song song văn bản thô."*
///
/// ## Hai chặng, và vì sao phải là hai
///
/// NFR-KNW-02 viết *"mở và index file JSONL 1 GB tới **trạng thái duyệt record được** ≤ 10
/// giây"*. Câu ấy đo tới lúc DUYỆT ĐƯỢC, không đo tới lúc kiểm xong:
///
/// 1. **Mở.** `Document.load` mmap tệp rồi dựng chỉ mục dòng của `PieceTable` — sau bước ấy
///    "bản ghi thứ n" đã là `contentRange(ofLine: n)`, tức duyệt được ngay. Chặng này KHÔNG đi
///    qua tệp này; nó là hạ tầng Large File Mode có sẵn (ADR-02).
/// 2. **Kiểm.** Tệp này. Nó đọc hết tệp một lượt, và trên 1 GB thì nó tốn nhiều giây.
///
/// Nếu gộp hai chặng thì mở một tệp 1 GB nghĩa là ngồi chờ trước một cửa sổ trống. Nên chặng
/// kiểm chạy có **tiến độ và huỷ**, và danh sách lỗi lớn dần trong lúc người dùng đã cuộn được.
///
/// ## Dòng hỏng vẫn GIỮ CHỖ
///
/// Số hiệu dòng ở đây là số hiệu dòng của tài liệu, không phải thứ tự bản ghi hợp lệ. Đánh số
/// lại theo bản ghi hợp lệ thì "bấm để nhảy tới dòng" nhảy sai đúng vào lúc người dùng cần nó
/// nhất — lúc đang sửa một tệp có lỗi.
public enum JSONLScan {

    public struct Problem: Equatable, Sendable {
        /// Số hiệu dòng trong tài liệu, 0-based.
        public var line: Int
        /// Vị trí byte TRONG dòng.
        public var offset: Int
        public var message: String

        public init(line: Int, offset: Int, message: String) {
            self.line = line
            self.offset = offset
            self.message = message
        }
    }

    public struct Result: Equatable, Sendable {
        public var lineCount: Int
        /// Dòng là JSON hợp lệ — kể cả khi nó không phải đối tượng.
        public var recordCount: Int
        /// Dòng hợp lệ VÀ là đối tượng `{…}`. Bản ghi JSONL bình thường nằm ở đây.
        public var objectCount: Int
        public var blankCount: Int
        /// Danh sách lỗi, đã cắt theo `problemLimit`.
        public var problems: [Problem]
        /// Tổng số lỗi THẬT — có thể lớn hơn `problems.count`.
        public var problemCount: Int
        public var wasCancelled: Bool
        /// Byte đã đọc — để chỗ gọi nói "đã kiểm x/y" khi bị huỷ giữa chừng.
        public var scannedBytes: Int

        public init(
            lineCount: Int = 0, recordCount: Int = 0, objectCount: Int = 0,
            blankCount: Int = 0, problems: [Problem] = [], problemCount: Int = 0,
            wasCancelled: Bool = false, scannedBytes: Int = 0
        ) {
            self.lineCount = lineCount
            self.recordCount = recordCount
            self.objectCount = objectCount
            self.blankCount = blankCount
            self.problems = problems
            self.problemCount = problemCount
            self.wasCancelled = wasCancelled
            self.scannedBytes = scannedBytes
        }

        /// Danh sách lỗi có bị cắt không — phải nói ra, không cắt trong im lặng.
        public var problemsTruncated: Bool { problemCount > problems.count }

        /// Bản ghi không phải đối tượng. Không phải LỖI, nhưng đáng nói với một tệp chunk.
        public var nonObjectCount: Int { recordCount - objectCount }
    }

    /// Trần số lỗi giữ lại.
    ///
    /// Một tệp sinh sai từ đầu có thể hỏng cả triệu dòng, và giữ đủ chúng thì bảng lỗi ngốn
    /// nhiều bộ nhớ hơn chính tệp. Một nghìn dòng đầu đã quá đủ để thấy KIỂU lỗi; tổng số thật
    /// vẫn được đếm và hiện ra.
    public static let defaultProblemLimit = 1_000

    /// Bao nhiêu byte thì hỏi tiến độ một lần.
    ///
    /// 4 MB trên đường đọc tuần tự là cỡ vài mili-giây, nên nút Huỷ ăn gần như tức thì mà chi
    /// phí gọi lại giao diện vẫn không đáng kể.
    static let reportInterval = 4 << 20

    /// Kiểm cả tài liệu.
    ///
    /// - Parameter progress: byte đã đọc / tổng byte. Trả `false` để HUỶ — kết quả trả về vẫn
    ///   dùng được, với `wasCancelled = true`.
    public static func scan(
        buffer: TextBuffer,
        problemLimit: Int = defaultProblemLimit,
        cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil
    ) -> Result {
        var result = Result()
        let walk = forEachLine(buffer: buffer, cancelToken: cancelToken, progress: progress) {
            line, _ in
            check(line, into: &result, problemLimit: problemLimit)
        }
        result.wasCancelled = walk.cancelled
        result.scannedBytes = walk.scannedBytes
        return result
    }

    /// Duyệt từng dòng của một `TextBuffer`, cho mượn vùng byte — nền của cả 901 lẫn 902.
    ///
    /// ## Đi theo KHỐI của piece table chứ không theo dòng
    ///
    /// `buffer.bytes(in:)` cấp phát một mảng mới cho MỖI dòng; trên một tệp 690.000 dòng đó là
    /// 690.000 lần cấp phát chỉ để đọc rồi vứt. `forEachChunk` cho mượn thẳng vùng byte liền
    /// mạch, và ranh giới dòng tìm bằng `memchr`.
    ///
    /// ## Tiến độ hỏi BÊN TRONG vòng dòng, không phải giữa các khối
    ///
    /// Bản đầu hỏi mỗi lần hết một khối, và một bài kiểm huỷ đã bắt được: một tệp mmap là MỘT
    /// khối duy nhất, nên trên 1 GB thì tiến độ không bao giờ chạy và nút Huỷ không bao giờ ăn.
    /// Lỗi ấy chỉ hiện ra trên tệp lớn — đúng loại tệp mà chế độ này sinh ra để phục vụ.
    @discardableResult
    static func forEachLine(
        buffer: TextBuffer,
        cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil,
        body: (UnsafeBufferPointer<UInt8>, Int) -> Void
    ) -> (cancelled: Bool, scannedBytes: Int, lineCount: Int) {
        let total = max(buffer.count, 1)
        var leftover: [UInt8] = []
        var stop = false
        var consumed = 0
        var sinceLastReport = 0
        var number = 0

        buffer.forEachChunk { raw in
            guard !stop, let base = raw.baseAddress else { return }
            let chunk = base.assumingMemoryBound(to: UInt8.self)
            var start = 0
            // Phần đuôi của khối trước nối với phần đầu khối này thành một dòng trọn vẹn.
            if !leftover.isEmpty {
                if let found = memchr(chunk, 0x0A, raw.count) {
                    let end = UnsafeRawPointer(found) - raw.baseAddress!
                    leftover.append(contentsOf: UnsafeBufferPointer(start: chunk, count: end))
                    leftover.withUnsafeBufferPointer { body($0, number) }
                    number += 1
                    leftover.removeAll(keepingCapacity: true)
                    start = end + 1
                } else {
                    leftover.append(
                        contentsOf: UnsafeBufferPointer(start: chunk, count: raw.count))
                    consumed += raw.count
                    return
                }
            }
            while start < raw.count {
                guard let found = memchr(chunk + start, 0x0A, raw.count - start) else { break }
                let end = UnsafeRawPointer(found) - raw.baseAddress!
                body(UnsafeBufferPointer(start: chunk + start, count: end - start), number)
                number += 1
                consumed += end + 1 - start
                sinceLastReport += end + 1 - start
                start = end + 1

                if sinceLastReport >= reportInterval {
                    sinceLastReport = 0
                    if cancelToken?.isCancelled == true { stop = true; return }
                    if let progress, !progress(Double(consumed) / Double(total)) {
                        stop = true
                        return
                    }
                }
            }
            if start < raw.count {
                leftover.append(
                    contentsOf: UnsafeBufferPointer(start: chunk + start, count: raw.count - start))
                consumed += raw.count - start
            }
        }

        // Dòng cuối không có `\n` vẫn là một dòng.
        if !stop, !leftover.isEmpty {
            leftover.withUnsafeBufferPointer { body($0, number) }
            number += 1
        }
        return (stop, min(consumed, buffer.count), number)
    }

    private static func check(
        _ line: UnsafeBufferPointer<UInt8>, into result: inout Result, problemLimit: Int
    ) {
        let number = result.lineCount
        result.lineCount += 1

        // `\r` cuối dòng bị cắt trước khi kiểm — tệp sinh trên Windows là chuyện thường với dữ
        // liệu cào về, và báo "còn thừa chữ sau giá trị JSON" cho mọi dòng của một tệp CRLF là
        // một bảng lỗi vô dụng.
        var count = line.count
        if count > 0, line[count - 1] == 0x0D { count -= 1 }

        // Dòng trắng KHÔNG phải lỗi. Tệp JSONL hay có một dòng trống ở cuối, và nhiều bộ sinh
        // để lại dòng trống giữa các lô.
        var first = 0
        while first < count, line[first] == 0x20 || line[first] == 0x09 { first += 1 }
        if first >= count { result.blankCount += 1; return }

        let trimmed = UnsafeBufferPointer(start: line.baseAddress! , count: count)
        if let failure = JSONScanner.validate(trimmed) {
            result.problemCount += 1
            if result.problems.count < problemLimit {
                result.problems.append(Problem(
                    line: number, offset: failure.offset, message: failure.message))
            }
            return
        }
        result.recordCount += 1
        if line[first] == 0x7B { result.objectCount += 1 }
    }

    // MARK: - Nhận diện

    /// Số dòng đầu dùng để đoán.
    public static let sniffLines = 20

    /// Tệp này có phải JSONL không.
    ///
    /// Đuôi tệp là bằng chứng MẠNH nhưng không đủ: dữ liệu cào về hay mang đuôi `.txt` hoặc
    /// `.log`. Nên vẫn ngửi nội dung — và ngửi bằng luật CHẶT: mọi dòng không trắng trong 20
    /// dòng đầu phải là một ĐỐI TƯỢNG JSON hợp lệ.
    ///
    /// Chặt vì hậu quả lệch: đoán nhầm một tệp JSON thường (một đối tượng trải nhiều dòng)
    /// thành JSONL thì mọi dòng đều báo lỗi và bảng lỗi vô nghĩa. Một tệp `.jsonl` bị bỏ sót
    /// thì người dùng bật chế độ bằng tay — phiền, nhưng không sai.
    public static func looksLikeJSONL(buffer: TextBuffer, path: String?) -> Bool {
        if let path {
            let ext = (path as NSString).pathExtension.lowercased()
            if ext == "jsonl" || ext == "ndjson" { return true }
            if ext == "json" { return false }   // JSON thường: một giá trị, không phải mỗi dòng một
        }
        var seen = 0
        var line = 0
        while line < buffer.lineCount, seen < sniffLines {
            let range = buffer.contentRange(ofLine: line)
            line += 1
            var bytes = buffer.bytes(in: range)
            while let last = bytes.last, last == 0x0D { bytes.removeLast() }
            let blank = bytes.allSatisfy { $0 == 0x20 || $0 == 0x09 }
            if blank { continue }
            seen += 1
            let ok = bytes.withUnsafeBufferPointer { buffer -> Bool in
                guard buffer.first == 0x7B else { return false }
                return JSONScanner.validate(buffer) == nil
            }
            if !ok { return false }
        }
        return seen > 0
    }

    /// Bản ghi ở một dòng, in đẹp — thẻ xem của FR-KNW-901.
    ///
    /// Trả `nil` khi dòng không phải JSON hợp lệ; chỗ gọi hiện văn bản thô kèm thông báo lỗi
    /// thay vì một thẻ trống.
    public static func prettyRecord(buffer: TextBuffer, line: Int) -> String? {
        guard line >= 0, line < buffer.lineCount else { return nil }
        var bytes = buffer.bytes(in: buffer.contentRange(ofLine: line))
        while let last = bytes.last, last == 0x0D { bytes.removeLast() }
        return bytes.withUnsafeBufferPointer { JSONScanner.pretty($0) }
    }

    /// Trường mức trên cùng của bản ghi ở một dòng — nền cho FR-KNW-902.
    public static func fields(buffer: TextBuffer, line: Int) -> [JSONScanner.Field]? {
        guard line >= 0, line < buffer.lineCount else { return nil }
        var bytes = buffer.bytes(in: buffer.contentRange(ofLine: line))
        while let last = bytes.last, last == 0x0D { bytes.removeLast() }
        return bytes.withUnsafeBufferPointer { JSONScanner.topLevelFields($0) }
    }
}
