import Foundation
import PCRE2

/// Pattern đã biên dịch (và JIT hóa) — ADR-03.
///
/// Tách khỏi engine vì hai chi phí rất khác nhau: biên dịch + JIT là hàng chục tới hàng trăm
/// µs MỘT LẦN, còn khớp là chuyện của từng file. Find in Files trên 10 000 file phải biên
/// dịch đúng một lần (FR-SRCH-105, NFR-PERF-06).
///
/// An toàn luồng: `pcre2_code` chỉ-đọc sau khi biên dịch nên DÙNG CHUNG giữa các luồng được,
/// miễn mỗi luồng có `match_data`, `match_context` và JIT stack riêng. `matches(in:...)` tự
/// cấp phát cả ba, nên gọi song song trên cùng một `PCRE2Pattern` là hợp lệ.
public final class PCRE2Pattern {

    /// Trần công sức cho MỘT lần khớp.
    ///
    /// Đây là cơ chế duy nhất chặn được catastrophic backtracking từ BÊN TRONG một lần khớp;
    /// deadline theo đồng hồ chỉ chen vào được giữa hai kết quả. Giá trị mặc định lấy từ
    /// phép hiệu chỉnh PoC-C — xem docs/adr/ADR-03-regex-engine.md.
    public struct Limits {
        /// Số lần engine vào thân vòng lặp khớp. PCRE2 mặc định 10 000 000 — quá cao cho
        /// một trình soạn thảo tương tác.
        public var matchLimit: UInt32
        /// Độ sâu backtracking. LƯU Ý: nhánh JIT KHÔNG áp dụng trần này (JIT không đệ quy
        /// theo cách interpreter làm), nên nó chỉ bảo vệ đường dự phòng.
        public var depthLimit: UInt32
        /// Trần bộ nhớ heap cho một lần khớp, tính bằng KB.
        public var heapLimitKB: UInt32
        /// Trần ngăn xếp JIT. Pattern lồng sâu cần nhiều hơn mặc định 32 KB của PCRE2.
        public var jitStackMaxBytes: Int

        public init(
            matchLimit: UInt32 = 1_000_000,
            depthLimit: UInt32 = 10_000,
            heapLimitKB: UInt32 = 16_384,
            jitStackMaxBytes: Int = 1 << 20
        ) {
            self.matchLimit = matchLimit
            self.depthLimit = depthLimit
            self.heapLimitKB = heapLimitKB
            self.jitStackMaxBytes = jitStackMaxBytes
        }
    }

    private let code: OpaquePointer

    /// Con trỏ `pcre2_code` cho phần còn lại của module (Replace, Find in Files).
    ///
    /// Không công khai: ngoài module không ai được cầm con trỏ này — vòng đời của nó gắn với
    /// `deinit` của lớp, cầm ra ngoài là dangling pointer chờ sẵn.
    var codePointer: OpaquePointer { code }

    public let limits: Limits
    /// JIT có biên dịch thành công hay không. `false` = đang chạy interpreter.
    public let isJITCompiled: Bool
    /// Thời gian biên dịch pattern (ms) — số liệu PoC-C.
    public let compileMilliseconds: Double
    /// Thời gian JIT hóa (ms) — số liệu PoC-C.
    public let jitMilliseconds: Double

    /// Pattern có được biên dịch để chịu được subject UTF-8 HỎNG hay không.
    ///
    /// Đắt: xem ghi chú ở `enumerateMatches`. Chỉ bật khi đã biết dữ liệu có byte hỏng.
    public let allowsInvalidUTF: Bool

    /// Nguyên liệu biên dịch, giữ lại để dựng được biến thể khác của cùng pattern.
    public let sourcePattern: String
    public let sourceOptions: SearchOptions
    private let usedJIT: Bool

    /// Cùng pattern, nhưng biên dịch để chịu được UTF-8 hỏng.
    ///
    /// Find in Files cần nó: pattern dùng chung được biên dịch cho dữ liệu sạch, còn một file
    /// lẻ có byte hỏng thì phải có bản riêng chứ không được bỏ qua — dữ liệu TCVN3/VNI chưa
    /// chuyển mã vẫn phải tìm ra (FR-ENC-201). Biên dịch lại tốn ~0,2 ms và chỉ xảy ra với
    /// đúng những file hỏng, nên chưa cần cache.
    func recompiledAllowingInvalidUTF() throws -> PCRE2Pattern {
        try PCRE2Pattern(
            pattern: sourcePattern, options: sourceOptions,
            limits: limits, useJIT: usedJIT, allowInvalidUTF: true
        )
    }

    public init(
        pattern: String,
        options: SearchOptions = SearchOptions(),
        limits: Limits = Limits(),
        useJIT: Bool = true,
        allowInvalidUTF: Bool = false
    ) throws {
        self.limits = limits
        self.allowsInvalidUTF = allowInvalidUTF
        self.sourcePattern = pattern
        self.sourceOptions = options
        self.usedJIT = useJIT

        let source: [UInt8]
        let isLiteral: Bool

        switch options.mode {
        case .normal:
            source = Array(pattern.utf8)
            // PCRE2_LITERAL rẻ và ĐÚNG hơn việc tự escape pattern: không có ký tự nào lọt lưới.
            isLiteral = true
        case .extended:
            source = Array(ExtendedEscape.decode(pattern).utf8)
            isLiteral = true
        case .regex:
            source = Array(pattern.utf8)
            isLiteral = false
        }

        // PCRE2_MATCH_INVALID_UTF cho phép khớp trên subject có byte hỏng (dữ liệu TCVN3/VNI
        // chưa chuyển mã, file nhị phân mở nhầm) thay vì hỏng cả lần tìm. Nhưng nó ĐẮT —
        // xem ghi chú trong `enumerateMatches` — nên chỉ bật khi người gọi đã xác định là cần.
        var compileOptions: UInt32 = PCRE2_UTF
        if allowInvalidUTF { compileOptions |= PCRE2_MATCH_INVALID_UTF }
        if !options.matchCase { compileOptions |= PCRE2_CASELESS }

        if isLiteral {
            // PCRE2_LITERAL chỉ đi được với một TẬP CỜ HẸP; thêm UCP/MULTILINE/DOTALL vào là
            // pcre2_compile trả "invalid option bits with PCRE2_LITERAL". Bỏ chúng không mất
            // gì: neo dòng và `.` vô nghĩa khi pattern là chuỗi thuần, còn so khớp không phân
            // biệt hoa thường của tiếng Việt đã do PCRE2_UTF + PCRE2_CASELESS lo (PCRE2 dùng
            // bảng gấp chữ Unicode khi UTF bật).
            compileOptions |= PCRE2_LITERAL
        } else {
            // PCRE2_UCP: `\w`, `\b`, `\d` phải hiểu theo Unicode chứ không chỉ ASCII —
            // không có nó thì `\w+` cắt "Huế" thành "Hu" (NFR-USE-02).
            compileOptions |= PCRE2_UCP
            if options.multiline { compileOptions |= PCRE2_MULTILINE }
            if options.dotMatchesNewline { compileOptions |= PCRE2_DOTALL }
        }

        var errorCode: Int32 = 0
        var errorOffset: GEditorPCRE2Size = 0

        let (finalSource, finalOptions) = Self.wrapWholeWord(
            source: source, compileOptions: compileOptions, enabled: options.wholeWord
        )

        var compiled: OpaquePointer?
        let compileStart = DispatchTime.now()
        finalSource.withUnsafeBufferPointer { buf in
            compiled = pcre2_compile_8(
                buf.baseAddress, GEditorPCRE2Size(buf.count), finalOptions,
                &errorCode, &errorOffset, nil
            )
        }
        self.compileMilliseconds =
            Double(DispatchTime.now().uptimeNanoseconds - compileStart.uptimeNanoseconds) / 1_000_000

        guard let compiled else {
            throw RegexCompileError(
                pattern: pattern,
                message: Self.errorMessage(errorCode),
                offset: Int(errorOffset)
            )
        }
        self.code = compiled

        if useJIT {
            let jitStart = DispatchTime.now()
            let rc = pcre2_jit_compile_8(compiled, PCRE2_JIT_COMPLETE)
            self.jitMilliseconds =
                Double(DispatchTime.now().uptimeNanoseconds - jitStart.uptimeNanoseconds) / 1_000_000
            // JIT hỏng KHÔNG phải lỗi người dùng: pattern vẫn chạy được bằng interpreter.
            // Nuốt lỗi ở đây là chủ ý — nhưng phải phơi ra `isJITCompiled` để benchmark và
            // chẩn đoán biết mình đang đo nhánh nào.
            self.isJITCompiled = (rc == 0)
        } else {
            self.jitMilliseconds = 0
            self.isJITCompiled = false
        }
    }

    deinit {
        pcre2_code_free_8(code)
    }

    /// Bọc "cả từ" (FR-SRCH-101).
    ///
    /// Với pattern literal không thể chèn `\b` vào chuỗi — nó sẽ thành hai ký tự thường.
    /// Cách đúng: bỏ cờ literal, escape nội dung bằng `\Q…\E`, rồi mới bọc `\b`.
    private static func wrapWholeWord(
        source: [UInt8], compileOptions: UInt32, enabled: Bool
    ) -> ([UInt8], UInt32) {
        guard enabled else { return (source, compileOptions) }

        if compileOptions & PCRE2_LITERAL != 0 {
            // \Q…\E vô hiệu hóa mọi siêu ký tự; chỉ "\E" bên trong mới phá được, nên tách nó.
            var quoted = Array("\\b(?:\\Q".utf8)
            var index = 0
            while index < source.count {
                if index + 1 < source.count,
                   source[index] == UInt8(ascii: "\\"), source[index + 1] == UInt8(ascii: "E") {
                    quoted.append(contentsOf: Array("\\E\\\\E\\Q".utf8))
                    index += 2
                } else {
                    quoted.append(source[index])
                    index += 1
                }
            }
            quoted.append(contentsOf: Array("\\E)\\b".utf8))
            // Đã thôi literal thì phải bật lại PCRE2_UCP, nếu không `\b` quanh "Huế" tính
            // theo bảng ASCII và coi "ế" là ranh giới từ.
            return (quoted, (compileOptions & ~PCRE2_LITERAL) | PCRE2_UCP)
        }

        return (Array("\\b(?:".utf8) + source + Array(")\\b".utf8), compileOptions)
    }

    /// `PCRE2_UNSET` — nhóm không tham gia lần khớp này.
    ///
    /// PCRE2 đánh dấu bằng `~(PCRE2_SIZE)0` (mọi bit 1). `PCRE2_SIZE` là `size_t`, mà Swift
    /// import `size_t` thành `Int` CÓ DẤU, nên cùng một mẫu bit ấy hiện ra phía Swift là -1.
    /// So sánh theo bit pattern chứ không viết `-1` để không ai đọc nhầm thành "offset âm".
    static let unsetOffset = Int(bitPattern: ~UInt(0))

    static func errorMessage(_ code: Int32) -> String {
        var buffer = [UInt8](repeating: 0, count: 256)
        let length = buffer.withUnsafeMutableBufferPointer {
            pcre2_get_error_message_8(code, $0.baseAddress, GEditorPCRE2Size($0.count))
        }
        guard length > 0 else { return "lỗi PCRE2 \(code)" }
        return String(decoding: buffer[0 ..< Int(length)], as: UTF8.self)
    }

    // MARK: - Khớp

    /// Duyệt mọi kết quả khớp trong `buffer`. Trả `false` từ `body` để dừng sớm.
    ///
    /// Vòng lặp dưới đây bám sát `pcre2demo.c` của upstream. Ba chỗ dễ sai, đều có test riêng:
    ///  - **Khớp rỗng**: `()` hay `a*` khớp chuỗi rỗng ở mọi vị trí. Nếu cứ tiếp tục từ
    ///    `ovector[1]` thì lặp vô hạn tại chỗ. Phải thử lại có `NOTEMPTY_ATSTART|ANCHORED`,
    ///    thất bại thì mới nhích một KÝ TỰ.
    ///  - **`\K`**: đặt lại điểm bắt đầu báo cáo, nên `ovector[0]` có thể LÙI về trước vị trí
    ///    ta bắt đầu tìm. Không xử lý là lặp vô hạn.
    ///  - **Nhích một ký tự ≠ nhích một byte**: với UTF-8 phải bỏ qua byte tiếp nối `10xxxxxx`,
    ///    và không được tách đôi cặp CRLF.
    ///
    /// `subjectIsValidUTF8` là tham số HIỆU NĂNG, không phải tham số ngữ nghĩa. PCRE2 kiểm tra
    /// tính hợp lệ UTF-8 của subject ở MỖI lời gọi `pcre2_match`; với hàng trăm nghìn kết quả,
    /// một lần tìm O(n) biến thành O(n²) — đo được 34 000 lần chậm hơn trên 4 MB (ADR-03 §3.3).
    /// Truyền `true` khi đã tự kiểm một lần bằng `ByteScan.isValidUTF8`; khi đó `PCRE2_NO_UTF_CHECK`
    /// được bật cho mọi lần khớp. Truyền `nil` để hàm tự kiểm.
    ///
    /// KHÔNG được truyền `true` cho dữ liệu chưa kiểm: PCRE2 sẽ hành xử không xác định trên
    /// UTF-8 hỏng, tới mức đọc ra ngoài biên.
    /// Đường tiện lợi: tự dựng rồi bỏ một `PCRE2Matcher` cho đúng lần gọi này.
    ///
    /// Dùng cho tài liệu đơn lẻ. Khi quét HÀNG NGHÌN buffer thì phải tự giữ một `PCRE2Matcher`
    /// cho mỗi luồng — lý do đo được nằm ở phần chú thích của `PCRE2Matcher`.
    public func enumerateMatches(
        in buffer: UnsafeRawBufferPointer,
        subjectIsValidUTF8: Bool? = nil,
        cancelToken: CancelToken = CancelToken(),
        _ body: (SearchMatch) throws -> Bool
    ) throws {
        guard let matcher = PCRE2Matcher(pattern: self) else { return }
        try matcher.enumerateMatches(
            in: buffer, subjectIsValidUTF8: subjectIsValidUTF8, cancelToken: cancelToken, body
        )
    }

    /// Trạng thái thô của một lần khớp — đủ để gọi tiếp `pcre2_substitute` trên đúng lần khớp đó.
    ///
    /// Chỉ dùng trong module. Nó tồn tại để Replace All KHÔNG phải viết lại vòng lặp khớp:
    /// ba cái bẫy ở trên (khớp rỗng, `\K`, nhích ký tự) mà có hai bản hiện thực thì sớm muộn
    /// hai bản sẽ lệch nhau.
    struct MatchCursor {
        let match: SearchMatch
        let matchData: OpaquePointer
        let matchContext: OpaquePointer
        let subject: UnsafePointer<UInt8>
        let subjectLength: GEditorPCRE2Size
        /// Offset đã truyền cho `pcre2_match` sinh ra lần khớp này — `PCRE2_SUBSTITUTE_MATCHED`
        /// đòi dùng lại đúng giá trị này.
        let startOffset: GEditorPCRE2Size
        let baseOptions: UInt32
    }

    func enumerateRaw(
        in buffer: UnsafeRawBufferPointer,
        subjectIsValidUTF8: Bool? = nil,
        cancelToken: CancelToken = CancelToken(),
        _ body: (MatchCursor) throws -> Bool
    ) throws {
        guard let matcher = PCRE2Matcher(pattern: self) else { return }
        try matcher.enumerateRaw(
            in: buffer, subjectIsValidUTF8: subjectIsValidUTF8, cancelToken: cancelToken, body
        )
    }
}

/// Tài nguyên khớp gắn với MỘT luồng: `match_data`, `match_context` và JIT stack.
///
/// Tách khỏi `PCRE2Pattern` vì lý do đo được, không phải vì gọn gàng. Ba thứ này trước đây
/// được cấp phát bên trong mỗi lần `enumerateMatches`, tức MỘT LẦN CHO MỖI FILE khi quét cây
/// thư mục. `pcre2_jit_stack_create` gọi `mmap` với cờ `MAP_JIT`, mà thao tác trên bảng ánh
/// xạ bộ nhớ thì các luồng phải tranh nhau khóa của nhân — nên find-in-files gần như không
/// nhanh thêm khi tăng từ 4 lên 8 luồng (ADR-03 §5, TC-PERF-05).
///
/// KHÔNG an toàn để dùng chung giữa các luồng. `PCRE2Pattern` thì có (nó chỉ-đọc sau khi biên
/// dịch); mỗi luồng giữ một `PCRE2Matcher` riêng trỏ về cùng pattern đó.
public final class PCRE2Matcher {

    /// Giữ pattern sống: `code` bên trong nó là con trỏ mà mọi lời gọi ở đây dùng tới.
    public let pattern: PCRE2Pattern

    private let matchData: OpaquePointer
    private let matchContext: OpaquePointer
    private let jitStack: OpaquePointer?

    public init?(pattern: PCRE2Pattern) {
        guard let matchData = pcre2_match_data_create_from_pattern_8(pattern.codePointer, nil)
        else { return nil }
        guard let matchContext = pcre2_match_context_create_8(nil) else {
            pcre2_match_data_free_8(matchData)
            return nil
        }

        let limits = pattern.limits
        pcre2_set_match_limit_8(matchContext, limits.matchLimit)
        pcre2_set_depth_limit_8(matchContext, limits.depthLimit)
        pcre2_set_heap_limit_8(matchContext, limits.heapLimitKB)

        var stack: OpaquePointer?
        if pattern.isJITCompiled {
            stack = pcre2_jit_stack_create_8(32 * 1024, limits.jitStackMaxBytes, nil)
            if let stack {
                pcre2_jit_stack_assign_8(matchContext, nil, UnsafeMutableRawPointer(stack))
            }
        }

        self.pattern = pattern
        self.matchData = matchData
        self.matchContext = matchContext
        self.jitStack = stack
    }

    deinit {
        if let jitStack { pcre2_jit_stack_free_8(jitStack) }
        pcre2_match_context_free_8(matchContext)
        pcre2_match_data_free_8(matchData)
    }

    public func enumerateMatches(
        in buffer: UnsafeRawBufferPointer,
        subjectIsValidUTF8: Bool? = nil,
        cancelToken: CancelToken = CancelToken(),
        _ body: (SearchMatch) throws -> Bool
    ) throws {
        try enumerateRaw(
            in: buffer, subjectIsValidUTF8: subjectIsValidUTF8, cancelToken: cancelToken
        ) { try body($0.match) }
    }

    /// Vòng lặp khớp toàn cục — xem chú thích ở `PCRE2Pattern.enumerateMatches` về ba cái bẫy.
    func enumerateRaw(
        in buffer: UnsafeRawBufferPointer,
        subjectIsValidUTF8: Bool? = nil,
        cancelToken: CancelToken = CancelToken(),
        _ body: (PCRE2Pattern.MatchCursor) throws -> Bool
    ) throws {
        guard let subject = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
        let subjectLength = GEditorPCRE2Size(buffer.count)
        let code = pattern.codePointer
        let limits = pattern.limits

        // Kiểm một lần, bỏ kiểm ở mọi lần khớp sau đó. Với pattern biên dịch kèm
        // PCRE2_MATCH_INVALID_UTF thì PCRE2 bỏ qua cờ này — nó tự lo phần hỏng.
        let validated = subjectIsValidUTF8 ?? ByteScan.isValidUTF8(buffer)
        let baseOptions: UInt32 = validated ? PCRE2_NO_UTF_CHECK : 0

        var startOffset: GEditorPCRE2Size = 0
        var matchOptions: UInt32 = 0
        var found = 0

        while true {
            // Hủy/deadline kiểm tra GIỮA các kết quả. Trần bên trong một lần khớp là
            // `matchLimit` — hai cơ chế bù cho nhau, thiếu cái nào cũng treo được UI.
            if found % 256 == 0 { try cancelToken.check() }

            let rc = pcre2_match_8(
                code, subject, subjectLength, startOffset,
                matchOptions | baseOptions, matchData, matchContext
            )

            if rc == PCRE2_ERROR_NOMATCH {
                // Không ở chế độ thử-lại-khớp-rỗng thì thật sự hết kết quả.
                if matchOptions == 0 { return }
                // Thử lại thất bại: nhích một ký tự rồi tìm tiếp bình thường.
                matchOptions = 0
                startOffset = Self.advance(subject, subjectLength, from: startOffset)
                if startOffset > subjectLength { return }
                continue
            }
            if rc < 0 { throw Self.mapError(rc, limits: limits) }

            guard let ovector = pcre2_get_ovector_pointer_8(matchData) else { return }
            let matchStart = ovector[0]
            let matchEnd = ovector[1]

            let pairs = rc == 0 ? Int(pcre2_get_ovector_count_8(matchData)) : Int(rc)
            var groups: [Range<Int>?] = []
            if pairs > 1 {
                groups.reserveCapacity(pairs - 1)
                for index in 1 ..< pairs {
                    let lower = ovector[index * 2]
                    let upper = ovector[index * 2 + 1]
                    groups.append(lower == PCRE2Pattern.unsetOffset ? nil : Int(lower) ..< Int(upper))
                }
            }

            found += 1
            let cursor = PCRE2Pattern.MatchCursor(
                match: SearchMatch(range: Int(matchStart) ..< Int(matchEnd), groups: groups),
                matchData: matchData,
                matchContext: matchContext,
                subject: subject,
                subjectLength: subjectLength,
                startOffset: startOffset,
                baseOptions: baseOptions
            )
            if try !body(cursor) { return }

            if matchStart == matchEnd {
                if matchEnd == subjectLength { return }
                startOffset = matchEnd
                matchOptions = PCRE2_NOTEMPTY_ATSTART | PCRE2_ANCHORED
            } else {
                matchOptions = 0
                startOffset = matchEnd
                // `\K` đã kéo điểm bắt đầu lùi lại: tiếp tục từ `matchEnd` sẽ khớp mãi cùng
                // một chỗ. Nhích từ `matchStart` để chắc chắn tiến lên.
                if startOffset <= matchStart {
                    if matchStart >= subjectLength { return }
                    startOffset = Self.advance(subject, subjectLength, from: matchStart)
                }
                if startOffset > subjectLength { return }
            }
        }
    }

    /// Nhích qua ĐÚNG MỘT ký tự kể từ `offset`: một cặp CRLF, hoặc một chuỗi UTF-8 đầy đủ.
    private static func advance(
        _ subject: UnsafePointer<UInt8>, _ length: GEditorPCRE2Size, from offset: GEditorPCRE2Size
    ) -> GEditorPCRE2Size {
        var next = offset + 1
        guard next < length else { return next }

        if subject[Int(offset)] == UInt8(ascii: "\r"), subject[Int(next)] == UInt8(ascii: "\n") {
            return next + 1
        }
        // Byte tiếp nối UTF-8 có dạng 10xxxxxx — không bao giờ là điểm bắt đầu ký tự.
        while next < length, (subject[Int(next)] & 0xC0) == 0x80 {
            next += 1
        }
        return next
    }

    static func mapError(_ rc: Int32, limits: PCRE2Pattern.Limits) -> Error {
        switch rc {
        case PCRE2_ERROR_MATCHLIMIT:
            return RegexBudgetExceeded(kind: .matchLimit, limit: limits.matchLimit)
        case PCRE2_ERROR_DEPTHLIMIT:
            return RegexBudgetExceeded(kind: .depthLimit, limit: limits.depthLimit)
        case PCRE2_ERROR_HEAPLIMIT:
            return RegexBudgetExceeded(kind: .heapLimit, limit: limits.heapLimitKB)
        case PCRE2_ERROR_JIT_STACKLIMIT:
            return RegexBudgetExceeded(kind: .heapLimit, limit: UInt32(limits.jitStackMaxBytes / 1024))
        default:
            return RegexCompileError(
                pattern: "", message: PCRE2Pattern.errorMessage(rc), offset: 0
            )
        }
    }
}

/// Engine tìm kiếm của sản phẩm (ADR-03, chốt bởi PoC-C).
///
/// So với `FoundationSearchEngine` nó khắc phục đúng ba thiếu sót đã ghi ở đó: cú pháp PCRE2
/// đầy đủ, trần backtracking tất định, và chạy thẳng trên vùng nhớ không dựng chuỗi.
public struct PCRE2SearchEngine: SearchEngine {

    public let limits: PCRE2Pattern.Limits
    public let useJIT: Bool

    public init(limits: PCRE2Pattern.Limits = PCRE2Pattern.Limits(), useJIT: Bool = true) {
        self.limits = limits
        self.useJIT = useJIT
    }

    public func find(
        pattern: String,
        in buffer: UnsafeRawBufferPointer,
        options: SearchOptions = SearchOptions(),
        limit: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [SearchMatch] {
        // Kiểm tính hợp lệ UTF-8 MỘT LẦN rồi mới chọn cách biên dịch. Đường nhanh (dữ liệu
        // sạch) bỏ hẳn việc PCRE2 kiểm lại subject ở mỗi lần khớp; đường chậm chỉ dành cho
        // file thật sự có byte hỏng. Chi tiết và số đo: ADR-03 §3.3.
        let isValid = ByteScan.isValidUTF8(buffer)

        let compiled = try PCRE2Pattern(
            pattern: pattern, options: options, limits: limits,
            useJIT: useJIT, allowInvalidUTF: !isValid
        )
        var matches: [SearchMatch] = []
        try compiled.enumerateMatches(
            in: buffer, subjectIsValidUTF8: isValid, cancelToken: cancelToken
        ) { match in
            matches.append(match)
            return limit <= 0 || matches.count < limit
        }
        return matches
    }

    /// Thông tin build của PCRE2 đang liên kết — dùng cho panel "Về GEditor" và chẩn đoán.
    public static var version: String {
        var buffer = [CChar](repeating: 0, count: 64)
        let length = buffer.withUnsafeMutableBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: $0.count) { raw in
                pcre2_config_8(UInt32(PCRE2_CONFIG_VERSION), UnsafeMutableRawPointer(raw))
            }
        }
        guard length > 0 else { return "không rõ" }
        return String(cString: buffer)
    }

    /// JIT có sẵn trong bản build này hay không (khác với "JIT hóa thành công cho pattern này").
    public static var isJITAvailable: Bool {
        var value: UInt32 = 0
        _ = pcre2_config_8(UInt32(PCRE2_CONFIG_JIT), &value)
        return value == 1
    }

    /// Kiến trúc đích của JIT ("ARM-64", "x86 64bit"…) — bằng chứng cho NFR-PORT-01.
    public static var jitTarget: String {
        var buffer = [CChar](repeating: 0, count: 128)
        let length = buffer.withUnsafeMutableBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: $0.count) { raw in
                pcre2_config_8(UInt32(PCRE2_CONFIG_JITTARGET), UnsafeMutableRawPointer(raw))
            }
        }
        guard length > 0 else { return "không có JIT" }
        return String(cString: buffer)
    }
}
