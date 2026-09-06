import Foundation

/// Đọc tệp JSONL theo dòng, có huỷ và có tiến độ — nền chung cho cụm FR-KNW.
///
/// ## Vì sao tách ra khỏi `BM25IndexBuild`
///
/// Bộ dựng chỉ mục đã có sẵn vòng quét `read(upToCount:)` + `memchr` của nó, và nó ở lại đó vì
/// nó gắn với việc gom khối. Nhưng FR-KNW-901 (chế độ JSONL), FR-KNW-902 (Chunk Inspector) và
/// FR-KNW-922 (Chunk Quality Report) đều cần đúng một thứ: **duyệt dòng của một tệp GB mà không
/// nạp cả tệp vào bộ nhớ**. Viết lần thứ tư thì đó là lần thứ tư có cơ hội sai `leftover`.
///
/// ## Ba tính chất phải giữ, vì cả cụm dựa vào chúng
///
/// **1. Số hiệu dòng KHÔNG bao giờ nhảy.** Dòng rỗng và dòng không phải JSON vẫn được đếm và
/// vẫn được gọi lại. Bỏ chúng thì mọi số hiệu phía sau lệch một, và "bấm kết quả để nhảy tới
/// dòng" nhảy sai — một lỗi im lặng, không có gì trong sản phẩm chỉ ra được.
///
/// **2. Vị trí byte đi kèm mỗi dòng.** Chunk Inspector cần nhảy thẳng tới bản ghi thứ n mà
/// không đọc lại từ đầu.
///
/// **3. `\r\n` được cắt.** Tệp sinh trên Windows là chuyện thường với dữ liệu cào về, và một ký
/// tự `\r` dính ở cuối làm hỏng cả phép so chuỗi lẫn phép băm shingle.
public enum JSONLReader {

    public struct Line {
        /// Số hiệu dòng, 0-based. Đếm CẢ dòng rỗng và dòng hỏng.
        public let number: Int
        /// Vị trí byte của đầu dòng trong tệp.
        public let offset: Int
        /// Nội dung dòng, đã cắt `\r` cuối. Cho mượn — **không** giữ lại con trỏ này.
        public let bytes: UnsafeBufferPointer<UInt8>
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Kích thước một lần đọc. 8 MB là con số đã đo ở PoC-M; không có gì thiêng liêng, nhưng
    /// đổi nó thì đo lại chứ đừng đoán.
    public static let chunkSize = 8 << 20

    /// Duyệt từng dòng.
    ///
    /// - Parameter body: trả `false` để DỪNG SỚM (đủ số dòng cần xem chẳng hạn).
    /// - Parameter progress: số byte đã đọc / tổng số byte. Trả `false` để HUỶ.
    /// - Returns: tổng số dòng đã duyệt.
    @discardableResult
    public static func forEachLine(
        path: String,
        cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil,
        body: (Line) throws -> Bool
    ) throws -> Int {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let totalBytes = attributes[.size] as? Int else {
            throw Failure(message: "không đọc được \(path)")
        }
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw Failure(message: "không mở được \(path)")
        }
        defer { try? handle.close() }

        var leftover: [UInt8] = []
        var number = 0
        var offset = 0
        var consumed = 0
        var stopped = false

        while !stopped {
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            consumed += chunk.count
            var data = leftover
            data.append(contentsOf: chunk)
            leftover.removeAll(keepingCapacity: true)

            var cut = 0
            try data.withUnsafeBufferPointer { buffer in
                var start = 0
                while start < buffer.count {
                    guard let found = memchr(
                        buffer.baseAddress! + start, 0x0A, buffer.count - start) else { break }
                    let end = UnsafeRawPointer(found) - UnsafeRawPointer(buffer.baseAddress!)
                    var stop = end
                    if stop > start, buffer[stop - 1] == 0x0D { stop -= 1 }
                    let line = UnsafeBufferPointer(
                        start: buffer.baseAddress! + start, count: stop - start)
                    if try !body(Line(number: number, offset: offset, bytes: line)) {
                        stopped = true
                        cut = buffer.count
                        return
                    }
                    number += 1
                    offset += end - start + 1
                    start = end + 1
                }
                cut = start
            }
            if stopped { break }
            if cut < data.count { leftover.append(contentsOf: data[cut...]) }

            try cancelToken?.check()
            if let progress, !progress(Double(consumed) / Double(max(totalBytes, 1))) {
                throw Failure(message: "đã huỷ")
            }
        }

        // Dòng cuối không có `\n` vẫn là một dòng — tệp do người khác sinh ra thường thiếu nó.
        if !stopped, !leftover.isEmpty {
            var stop = leftover.count
            if stop > 0, leftover[stop - 1] == 0x0D { stop -= 1 }
            try leftover.withUnsafeBufferPointer { buffer in
                let line = UnsafeBufferPointer(start: buffer.baseAddress!, count: stop)
                _ = try body(Line(number: number, offset: offset, bytes: line))
            }
            number += 1
        }
        return number
    }

    /// Lấy giá trị chuỗi của một trường, ưu tiên đường tắt byte và lui về bộ đọc đầy đủ.
    ///
    /// Cùng luật với `BM25RawJSON`: bỏ cuộc thì CHẬM, không SAI.
    public static func string(
        field: String, in line: UnsafeBufferPointer<UInt8>
    ) -> String? {
        if let range = BM25RawJSON.stringRange(field: field, in: line) {
            return String(decoding: line[range], as: UTF8.self)
        }
        guard let object = try? JSONSerialization.jsonObject(
            with: Data(buffer: line)) as? [String: Any] else { return nil }
        return BM25Index.string(from: object[field])
    }
}
