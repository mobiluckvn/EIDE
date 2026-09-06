import Foundation

/// Tìm và thay thế trên cả cây thư mục (FR-SRCH-105, FR-SRCH-106, NFR-PERF-06).
///
/// Ba quyết định định hình toàn bộ file này:
///
/// 1. **Một pattern biên dịch dùng chung cho mọi luồng.** `pcre2_code` chỉ-đọc sau khi biên
///    dịch nên chia sẻ được; mỗi luồng chỉ cần `match_data`/`match_context`/JIT stack riêng,
///    và `PCRE2Pattern.enumerateMatches` đã tự cấp phát chúng. Biên dịch lại cho từng file
///    là 0,2 ms × số file — với 10 000 file là 2 giây thuần lãng phí (ADR-03 §3.2).
///
/// 2. **Song song theo FILE, không theo vùng trong file.** Ranh giới file là ranh giới tự
///    nhiên: không có kết quả nào nằm vắt qua hai file, nên không cần khâu vá kết quả ở biên.
///
/// 3. **`concurrency` là tham số, không phải hằng số.** NFR-PERF-06 đòi CHỨNG MINH khả năng
///    dùng nhiều lõi; muốn chứng minh thì phải đo được cả cấu hình một lõi.
public enum FindInFiles {

    // MARK: - Tùy chọn

    public struct Options {
        /// Mẫu tên file được nhận. Rỗng = mọi file.
        public var includeGlobs: [String]
        /// Mẫu tên file bị loại, xét SAU `includeGlobs`.
        public var excludeGlobs: [String]
        /// Tên thư mục không đi vào. Mặc định là những thư mục mà kết quả tìm trong đó gần
        /// như luôn là nhiễu.
        public var excludeDirectories: Set<String>
        /// Bỏ qua file lớn hơn ngưỡng này.
        public var maxFileSizeBytes: Int
        /// Bỏ qua file nhị phân (phát hiện bằng byte NUL ở đầu file).
        public var skipBinary: Bool
        public var followSymlinks: Bool
        /// Số luồng; 0 = số lõi đang hoạt động.
        public var concurrency: Int
        /// Trần kết quả mỗi file; 0 = không giới hạn.
        public var limitPerFile: Int
        /// Dưới ngưỡng này thì đọc bằng `read()` vào bộ đệm dùng lại; trên thì `mmap`.
        /// Là tham số chứ không phải hằng số vì điểm hòa vốn phụ thuộc hệ thống file —
        /// và vì chỉ có đo mới biết, xem `smallFileThreshold`.
        public var readInsteadOfMapBelowBytes: Int

        public init(
            includeGlobs: [String] = [],
            excludeGlobs: [String] = [],
            excludeDirectories: Set<String> = [".git", ".build", "node_modules", ".svn", "DerivedData"],
            maxFileSizeBytes: Int = 512 * 1024 * 1024,
            skipBinary: Bool = true,
            followSymlinks: Bool = false,
            concurrency: Int = 0,
            limitPerFile: Int = 0,
            readInsteadOfMapBelowBytes: Int = FindInFiles.smallFileThreshold
        ) {
            self.includeGlobs = includeGlobs
            self.excludeGlobs = excludeGlobs
            self.excludeDirectories = excludeDirectories
            self.maxFileSizeBytes = maxFileSizeBytes
            self.skipBinary = skipBinary
            self.followSymlinks = followSymlinks
            self.concurrency = concurrency
            self.limitPerFile = limitPerFile
            self.readInsteadOfMapBelowBytes = readInsteadOfMapBelowBytes
        }

        var resolvedConcurrency: Int {
            concurrency > 0 ? concurrency : ProcessInfo.processInfo.activeProcessorCount
        }
    }

    // MARK: - Kết quả

    public struct Hit {
        public let byteRange: Range<Int>
        /// Số dòng 1-based — đúng thứ hiện trong panel Search Results và trong `geditor` CLI.
        public let line: Int
        /// Cột tính bằng BYTE, 1-based. Lớp trình bày quy đổi sang ký tự (FR-CORE-018).
        public let byteColumn: Int
        /// Nội dung dòng chứa kết quả, đã cắt EOL và giới hạn độ dài.
        public let lineText: String

        /// Dựng một kết quả KHÔNG đến từ phép tìm.
        ///
        /// FR-KNW-924 đổ danh sách lỗi cấu trúc đồ thị vào chính panel này: ngữ nghĩa khớp hẳn
        /// — "một danh sách vị trí trong tệp, bấm để nhảy tới" — và dựng bảng thứ hai với cùng
        /// hành vi là thêm một thứ để học và thêm một chỗ để hai bên trôi khỏi nhau.
        public init(byteRange: Range<Int>, line: Int, byteColumn: Int, lineText: String) {
            self.byteRange = byteRange
            self.line = line
            self.byteColumn = byteColumn
            self.lineText = lineText
        }
    }

    public struct FileResult {
        public let path: String
        public let hits: [Hit]
        /// Bị cắt vì chạm `limitPerFile`.
        public let truncated: Bool

        public init(path: String, hits: [Hit], truncated: Bool = false) {
            self.path = path
            self.hits = hits
            self.truncated = truncated
        }
    }

    /// Conform `Error` để dùng được trong `Result` — file bị bỏ qua không phải sự cố, nhưng
    /// nó là nhánh "không có kết quả" của cùng một phép toán, và `Result` diễn đạt đúng điều đó.
    public enum SkipReason: String, Error {
        case tooLarge, binary, unreadable
    }

    public struct Summary {
        public let results: [FileResult]
        public let filesScanned: Int
        public let filesSkipped: [String: SkipReason]
        public let elapsed: TimeInterval

        public init(
            results: [FileResult], filesScanned: Int,
            filesSkipped: [String: SkipReason] = [:], elapsed: TimeInterval = 0
        ) {
            self.results = results
            self.filesScanned = filesScanned
            self.filesSkipped = filesSkipped
            self.elapsed = elapsed
        }

        public var totalHits: Int { results.reduce(0) { $0 + $1.hits.count } }

        /// Kết quả dưới dạng văn bản để XUẤT RA — SRS FR-SRCH-105.
        ///
        /// Định dạng `đường-dẫn:dòng:cột: nội dung` — cùng khuôn `grep -n` và cùng khuôn trình
        /// biên dịch in lỗi, nên mỗi dòng dán thẳng vào ô «Đi tới» của sản phẩm này được, và
        /// cả `grep`/`awk`/`sed` của người dùng cũng đọc được mà không phải viết bộ tách riêng.
        /// Một định dạng đẹp hơn nhưng chỉ mình ta hiểu thì không xuất đi đâu được.
        ///
        /// Cột đếm theo BYTE, đúng như `Hit.byteColumn` — và dòng đầu nói ra điều đó, vì một
        /// con số cột không nói đơn vị là một con số không dùng được.
        public func exportText(pattern: String) -> String {
            var lines = [
                "# \(totalHits) kết quả cho «\(pattern)» trong \(results.count)/\(filesScanned) tệp",
                "# đường-dẫn:dòng:cột (cột tính theo BYTE) — dán được vào ô «Đi tới»",
                "",
            ]
            for result in results {
                for hit in result.hits {
                    lines.append("\(result.path):\(hit.line):\(hit.byteColumn): \(hit.lineText)")
                }
                if result.truncated {
                    lines.append("\(result.path): … còn nữa, đã cắt vì chạm trần mỗi tệp")
                }
            }
            if !filesSkipped.isEmpty {
                lines.append("")
                lines.append("# \(filesSkipped.count) tệp bỏ qua")
                for (path, reason) in filesSkipped.sorted(by: { $0.key < $1.key }) {
                    lines.append("# \(path): \(reason)")
                }
            }
            return lines.joined(separator: "\n") + "\n"
        }
    }

    /// Độ dài tối đa của đoạn xem trước một dòng.
    ///
    /// Không có trần này thì một file JSON nén một dòng dài 50 MB sẽ nhét 50 MB vào MỖI kết
    /// quả — panel kết quả tự làm nổ bộ nhớ của chính nó.
    static let previewByteLimit = 512

    /// Số byte đầu file dùng để đoán nhị phân.
    static let binarySniffBytes = 8192

    /// Dưới ngưỡng này thì đọc thẳng bằng `read()` vào bộ đệm dùng lại, thay vì `mmap`.
    ///
    /// Đo được, không phải phỏng đoán: với cây 10 000 file × 10 KB, đường mmap chạy ở
    /// 334 MB/s một luồng trong khi bản thân engine regex chạy 2,9 GB/s. Chênh lệch nằm ở
    /// `mmap`+lỗi trang+`munmap` cho MỖI file — thao tác đụng vào bảng ánh xạ bộ nhớ của
    /// tiến trình, thứ mà các luồng phải tranh nhau. Vì vậy find-in-files gần như không
    /// nhanh thêm khi tăng từ 4 lên 8 luồng.
    ///
    /// Với file lớn thì ngược lại: `read()` phải chép cả nội dung, còn `mmap` thì không —
    /// nên trên ngưỡng này vẫn dùng `mmap` (và đó cũng là đường của Large File Mode).
    public static let smallFileThreshold = 1 << 20

    // MARK: - Duyệt cây thư mục

    /// Liệt kê file ứng viên dưới `root`, đã lọc theo `options`.
    ///
    /// Duyệt tuần tự và có chủ ý: chi phí nằm ở việc ĐỌC file, không ở việc liệt kê tên, và
    /// một danh sách file cố định làm cho phần song song phía sau tất định — cùng đầu vào
    /// cho cùng thứ tự phân việc, nên benchmark tái lập được.
    public static func collectFiles(root: String, options: Options = Options()) -> [String] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root, isDirectory: &isDirectory) else { return [] }
        guard isDirectory.boolValue else { return [root] }

        var files: [String] = []
        var directories = [root]

        while let directory = directories.popLast() {
            guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
            for entry in entries.sorted() {
                let path = "\(directory)/\(entry)"
                var attributes: [FileAttributeKey: Any]?
                attributes = try? fileManager.attributesOfItem(atPath: path)
                let type = attributes?[.type] as? FileAttributeType

                if type == .typeSymbolicLink, !options.followSymlinks { continue }

                var entryIsDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: path, isDirectory: &entryIsDirectory) else { continue }

                if entryIsDirectory.boolValue {
                    if options.excludeDirectories.contains(entry) { continue }
                    directories.append(path)
                    continue
                }

                guard Glob.matchesAny(entry, patterns: options.includeGlobs) else { continue }
                if !options.excludeGlobs.isEmpty,
                   Glob.matchesAny(entry, patterns: options.excludeGlobs) { continue }
                files.append(path)
            }
        }
        return files
    }

    // MARK: - Tìm

    /// Tìm `pattern` trong mọi file dưới `root`.
    public static func search(
        root: String,
        pattern: String,
        searchOptions: SearchOptions = SearchOptions(),
        options: Options = Options(),
        limits: PCRE2Pattern.Limits = PCRE2Pattern.Limits(),
        cancelToken: CancelToken = CancelToken()
    ) throws -> Summary {
        let files = collectFiles(root: root, options: options)
        // Biên dịch MỘT LẦN, trước khi phân việc — xem ghi chú (1) ở đầu file.
        let compiled = try PCRE2Pattern(pattern: pattern, options: searchOptions, limits: limits)
        return try search(files: files, pattern: compiled, options: options, cancelToken: cancelToken)
    }

    /// Tìm bằng một pattern đã biên dịch sẵn — đường dùng lại khi tìm nhiều lần cùng pattern.
    public static func search(
        files: [String],
        pattern: PCRE2Pattern,
        options: Options = Options(),
        cancelToken: CancelToken = CancelToken()
    ) throws -> Summary {
        let start = DispatchTime.now()
        var results: [FileResult] = []
        var skipped: [String: SkipReason] = [:]
        var scanned = 0
        var failure: Error?

        let lock = NSLock()
        forEachFileInParallel(files, concurrency: options.resolvedConcurrency) { path, worker in
            if cancelToken.isCancelled { return }
            do {
                try cancelToken.check()
            } catch {
                lock.lock(); failure = failure ?? error; lock.unlock()
                cancelToken.cancel()
                return
            }

            switch scan(
                path: path, pattern: pattern, options: options,
                cancelToken: cancelToken, worker: worker
            ) {
            case .success(let result):
                lock.lock()
                scanned += 1
                if let result, !result.hits.isEmpty { results.append(result) }
                lock.unlock()
            case .skipped(let reason):
                lock.lock(); skipped[path] = reason; lock.unlock()
            case .failed(let error):
                lock.lock(); failure = failure ?? error; lock.unlock()
                cancelToken.cancel()
            }
        }

        if let failure { throw failure }

        // Sắp theo đường dẫn: thứ tự hoàn thành của các luồng là ngẫu nhiên, mà panel kết quả
        // và test đều cần thứ tự ổn định.
        results.sort { $0.path < $1.path }

        return Summary(
            results: results,
            filesScanned: scanned,
            filesSkipped: skipped,
            elapsed: Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        )
    }

    private enum ScanOutcome {
        case success(FileResult?)
        case skipped(SkipReason)
        case failed(Error)
    }

    /// Nạp nội dung file rồi gọi `body` — `read()` cho file nhỏ, `mmap` cho file lớn.
    ///
    /// `scratch` là bộ đệm RIÊNG của luồng gọi, được nới dần và dùng lại giữa các file: cấp
    /// phát 10 000 lần cho 10 000 file là đúng thứ đang cần tránh.
    static func withFileBytes<R>(
        path: String,
        maxBytes: Int,
        readBelow: Int = smallFileThreshold,
        scratch: inout [UInt8],
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> Result<R?, SkipReason> {
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { return .failure(.unreadable) }
        defer { close(descriptor) }

        var status = stat()
        guard fstat(descriptor, &status) == 0 else { return .failure(.unreadable) }
        let size = Int(status.st_size)

        guard size > 0 else { return .success(nil) }
        guard size <= maxBytes else { return .failure(.tooLarge) }

        if size > readBelow {
            guard let mapped = try? MappedFile(path: path) else { return .failure(.unreadable) }
            return .success(try mapped.withUnsafeBytes(body))
        }

        if scratch.count < size {
            scratch = [UInt8](repeating: 0, count: max(size, 64 * 1024))
        }
        var filled = 0
        while filled < size {
            let got = scratch.withUnsafeMutableBytes { raw -> Int in
                read(descriptor, raw.baseAddress!.advanced(by: filled), size - filled)
            }
            if got <= 0 {
                if got < 0 && errno == EINTR { continue }
                return .failure(.unreadable)
            }
            filled += got
        }
        return .success(try scratch.withUnsafeBytes { try body(UnsafeRawBufferPointer(rebasing: $0[0 ..< size])) })
    }

    private static func scan(
        path: String, pattern: PCRE2Pattern, options: Options,
        cancelToken: CancelToken, worker: Worker
    ) -> ScanOutcome {
        let loaded = withFileBytes(
            path: path, maxBytes: options.maxFileSizeBytes,
            readBelow: options.readInsteadOfMapBelowBytes, scratch: &worker.scratch
        ) { buffer -> ScanOutcome in
            if options.skipBinary, looksBinary(buffer) { return .skipped(.binary) }

            let isValidUTF8 = ByteScan.isValidUTF8(buffer)
            var ranges: [Range<Int>] = []
            var truncated = false

            do {
                // Pattern dùng chung được biên dịch cho subject HỢP LỆ. File có byte hỏng cần
                // pattern biên dịch khác (PCRE2_MATCH_INVALID_UTF), nên biên dịch riêng cho
                // đúng file đó thay vì bỏ qua nó — dữ liệu TCVN3/VNI chưa chuyển mã vẫn phải
                // tìm được (FR-ENC-201).
                let reusable = isValidUTF8 || pattern.allowsInvalidUTF
                    ? worker.matcher(for: pattern)
                    : try worker.invalidUTFMatcher(for: pattern)
                guard let usable = reusable else { return .success(nil) }

                try usable.enumerateMatches(
                    in: buffer, subjectIsValidUTF8: isValidUTF8, cancelToken: cancelToken
                ) { match in
                    ranges.append(match.range)
                    if options.limitPerFile > 0 && ranges.count >= options.limitPerFile {
                        truncated = true
                        return false
                    }
                    return true
                }
            } catch is OperationCancelled {
                return .success(nil)
            } catch {
                return .failed(error)
            }

            guard !ranges.isEmpty else { return .success(nil) }

            let index = NewlineBlockIndex(bytes: buffer)
            let hits = ranges.map { range -> Hit in
                let line = index.newlinesBefore(range.lowerBound, in: buffer)
                let lineStart = line == 0 ? 0 : (index.offsetOfNewline(line - 1, in: buffer)! + 1)
                let lineEnd = index.offsetOfNewline(line, in: buffer) ?? buffer.count
                return Hit(
                    byteRange: range,
                    line: line + 1,
                    byteColumn: range.lowerBound - lineStart + 1,
                    lineText: preview(buffer, lineStart ..< lineEnd)
                )
            }
            return .success(FileResult(path: path, hits: hits, truncated: truncated))
        }

        switch loaded {
        case .failure(let reason): return .skipped(reason)
        case .success(let outcome): return outcome ?? .success(nil)
        }
    }

    /// Đoạn xem trước của một dòng: bỏ CR cuối, cắt theo `previewByteLimit`.
    private static func preview(_ buffer: UnsafeRawBufferPointer, _ range: Range<Int>) -> String {
        var end = range.upperBound
        if end > range.lowerBound, buffer[end - 1] == UInt8(ascii: "\r") { end -= 1 }
        var limited = min(end, range.lowerBound + previewByteLimit)
        // Không cắt giữa một chuỗi UTF-8: lùi về biên ký tự gần nhất.
        while limited > range.lowerBound, limited < end, (buffer[limited] & 0xC0) == 0x80 {
            limited -= 1
        }
        let bytes = (range.lowerBound ..< limited).map { buffer[$0] }
        let text = String(decoding: bytes, as: UTF8.self)
        return limited < end ? text + "…" : text
    }

    /// Đoán file nhị phân bằng byte NUL ở đầu file.
    ///
    /// Cùng phép thử mà `grep` dùng, và vì cùng lý do: văn bản thật gần như không bao giờ
    /// chứa NUL, còn file nhị phân thì gần như luôn có ở đâu đó rất sớm. Rẻ và đủ đúng —
    /// một phép thử tinh vi hơn sẽ tốn nhiều hơn chính việc tìm kiếm.
    static func looksBinary(_ buffer: UnsafeRawBufferPointer) -> Bool {
        let end = min(buffer.count, binarySniffBytes)
        for index in 0 ..< end where buffer[index] == 0 { return true }
        return false
    }

    // MARK: - Thay thế (FR-SRCH-106)

    public struct FileReplacement {
        public let path: String
        public let matchCount: Int
        public let byteDelta: Int
        /// `false` khi chạy thử (dry-run) hoặc khi file không có kết quả nào.
        public let applied: Bool
    }

    /// Thay thế trên nhiều file.
    ///
    /// `dryRun: true` làm ĐÚNG mọi việc trừ bước ghi — đó là cách duy nhất để bản xem trước
    /// của FR-SRCH-106 nói đúng sự thật: nếu đường xem trước và đường ghi là hai đoạn mã khác
    /// nhau thì sớm muộn chúng nói hai chuyện khác nhau.
    ///
    /// Ghi qua `AtomicFileWriter` theo từng đoạn thẳng từ piece table (NFR-REL-02): tiến trình
    /// bị kill giữa chừng để lại file gốc nguyên vẹn, và file 1 GB không bị dựng lại trong RAM.
    public static func replace(
        files: [String],
        pattern: PCRE2Pattern,
        template: String,
        options: Options = Options(),
        dryRun: Bool,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [FileReplacement] {
        var replacements: [FileReplacement] = []
        var failure: Error?
        let lock = NSLock()

        forEachFileInParallel(files, concurrency: options.resolvedConcurrency) { path, worker in
            if cancelToken.isCancelled { return }

            do {
                _ = try withFileBytes(
                    path: path, maxBytes: options.maxFileSizeBytes,
                    readBelow: options.readInsteadOfMapBelowBytes, scratch: &worker.scratch
                ) { source -> Void in
                    if options.skipBinary, looksBinary(source) { return }

                    let isValid = ByteScan.isValidUTF8(source)
                    let reusable = isValid || pattern.allowsInvalidUTF
                        ? worker.matcher(for: pattern)
                        : try worker.invalidUTFMatcher(for: pattern)
                    guard let usable = reusable else { return }
                    let plan = try usable.replacementEdits(
                        in: source, template: template,
                        subjectIsValidUTF8: isValid, cancelToken: cancelToken
                    )
                    guard !plan.isEmpty else { return }

                    if !dryRun {
                        // Ghi thẳng từng đoạn: file trên đĩa được thay TOÀN BỘ, nên dựng piece
                        // table cho nó là trả giá cho một khả năng không dùng tới (dựng chỉ
                        // mục newline O(n) + một triệu thao tác cây + lịch sử undo cho một
                        // file không mở trong editor). Đường này chỉ chép xen kẽ: đoạn giữ
                        // nguyên lấy thẳng từ nguồn, đoạn thay thế lấy từ kế hoạch.
                        try AtomicFileWriter.write(to: path) { descriptor in
                            var cursor = 0
                            // Kết quả từ tìm toàn cục vốn đã tăng dần; sắp lại là để đường ghi
                            // không phụ thuộc vào bất biến của một module khác.
                            for edit in plan.edits.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
                                if edit.range.lowerBound > cursor {
                                    try writeAll(descriptor, UnsafeRawBufferPointer(
                                        rebasing: source[cursor ..< edit.range.lowerBound]
                                    ))
                                }
                                try edit.bytes.withUnsafeBytes { try writeAll(descriptor, $0) }
                                cursor = edit.range.upperBound
                            }
                            if cursor < source.count {
                                try writeAll(descriptor, UnsafeRawBufferPointer(
                                    rebasing: source[cursor ..< source.count]
                                ))
                            }
                        }
                    }

                    lock.lock()
                    replacements.append(FileReplacement(
                        path: path, matchCount: plan.matchCount,
                        byteDelta: plan.byteDelta, applied: !dryRun
                    ))
                    lock.unlock()
                }
            } catch {
                lock.lock(); failure = failure ?? error; lock.unlock()
                cancelToken.cancel()
            }
        }

        if let failure { throw failure }
        replacements.sort { $0.path < $1.path }
        return replacements
    }

    private static func writeAll(_ descriptor: Int32, _ chunk: UnsafeRawBufferPointer) throws {
        var offset = 0
        while offset < chunk.count {
            let written = write(descriptor, chunk.baseAddress!.advanced(by: offset), chunk.count - offset)
            if written < 0 {
                if errno == EINTR { continue }
                throw AtomicFileWriter.Failure.writeFailed(errno: errno)
            }
            offset += written
        }
    }

    // MARK: - Phân việc

    /// Tài nguyên RIÊNG của một luồng công nhân, sống suốt lượt quét.
    ///
    /// Cả ba thứ đều đắt khi cấp phát lại cho từng file, và với 10 000 file thì "từng file"
    /// nghĩa là 10 000 lần: bộ đệm đọc là malloc, còn `PCRE2Matcher` kéo theo một `mmap`
    /// `MAP_JIT` cho ngăn xếp JIT — thao tác đụng bảng ánh xạ bộ nhớ, tức các luồng phải
    /// tranh khóa của nhân. Đó là thứ chặn find-in-files không tăng tốc quá 4 luồng.
    final class Worker {
        var scratch: [UInt8] = []
        /// Dựng lười: luồng không nhận được file nào thì không tốn gì.
        private var primary: PCRE2Matcher?
        /// Dùng cho file có UTF-8 hỏng — pattern khác nên matcher cũng phải khác.
        private var invalidUTF: PCRE2Matcher?

        func matcher(for pattern: PCRE2Pattern) -> PCRE2Matcher? {
            if primary == nil { primary = PCRE2Matcher(pattern: pattern) }
            return primary
        }

        func invalidUTFMatcher(for pattern: PCRE2Pattern) throws -> PCRE2Matcher? {
            if invalidUTF == nil {
                invalidUTF = PCRE2Matcher(pattern: try pattern.recompiledAllowingInvalidUTF())
            }
            return invalidUTF
        }
    }

    /// Chạy `body` cho mỗi file trên đúng `concurrency` luồng.
    ///
    /// Không dùng `DispatchQueue.concurrentPerform`: nó tự chọn số luồng, mà NFR-PERF-06 cần
    /// đo được cấu hình một luồng để chứng minh mức tăng theo số lõi. Các luồng tự kéo việc
    /// từ một chỉ số chung thay vì chia đều trước — kích thước file lệch nhau hàng nghìn lần,
    /// chia đều là để một luồng ôm hết phần nặng.
    private static func forEachFileInParallel(
        _ files: [String], concurrency: Int, _ body: @escaping (String, Worker) -> Void
    ) {
        guard !files.isEmpty else { return }
        let workers = max(1, min(concurrency, files.count))

        if workers == 1 {
            let worker = Worker()
            for path in files { body(path, worker) }
            return
        }

        let indexLock = NSLock()
        var next = 0
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        for _ in 0 ..< workers {
            queue.async(group: group) {
                let worker = Worker()
                while true {
                    indexLock.lock()
                    let index = next
                    next += 1
                    indexLock.unlock()
                    guard index < files.count else { return }
                    body(files[index], worker)
                }
            }
        }
        group.wait()
    }
}
