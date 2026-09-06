import Foundation
import PCRE2

/// Chuỗi thay thế không hợp lệ (FR-SRCH-103).
///
/// Tách khỏi `RegexCompileError` vì với người dùng đây là hai ô nhập khác nhau trên hộp
/// Find/Replace: chỉ đúng ô sai mới được tô đỏ.
public struct ReplacementTemplateError: Error, CustomStringConvertible {
    public let template: String
    public let message: String
    /// Offset byte trong chuỗi thay thế nơi engine bỏ cuộc.
    public let offset: Int

    public init(template: String, message: String, offset: Int) {
        self.template = template
        self.message = message
        self.offset = offset
    }

    public var description: String { "Lỗi chuỗi thay thế tại vị trí \(offset): \(message)" }
}

/// Kế hoạch thay thế — danh sách sửa đổi, CHƯA áp dụng.
///
/// Trả về kế hoạch thay vì tự sửa buffer là quy ước chung với `LineOps`: lớp gọi truyền cả
/// mảng vào `TextBuffer.applyEdits(_:label:)` để có ĐÚNG MỘT bước undo cho toàn bộ thao tác
/// (FR-CORE-004). Nó cũng là thứ làm cho "dry-run" của FR-SRCH-106 thành chuyện hiển nhiên:
/// dry-run chính là dừng lại ở kế hoạch.
public struct ReplacementPlan {
    public let edits: [TextEdit]
    public let matchCount: Int
    /// Bị cắt vì chạm `limit` — còn kết quả chưa xử lý.
    public let truncated: Bool
    /// Chênh lệch độ dài tài liệu sau khi áp dụng (âm = tài liệu ngắn lại).
    public let byteDelta: Int

    public init(edits: [TextEdit], matchCount: Int, truncated: Bool, byteDelta: Int) {
        self.edits = edits
        self.matchCount = matchCount
        self.truncated = truncated
        self.byteDelta = byteDelta
    }

    public var isEmpty: Bool { edits.isEmpty }
}

extension PCRE2Pattern {

    /// Đường tiện lợi: dựng rồi bỏ một `PCRE2Matcher` cho đúng lần gọi này.
    ///
    /// Khi thay thế trên HÀNG NGHÌN file thì phải tự giữ một `PCRE2Matcher` cho mỗi luồng —
    /// xem chú thích của lớp đó.
    public func replacementEdits(
        in buffer: UnsafeRawBufferPointer,
        template: String,
        limit: Int = 0,
        subjectIsValidUTF8: Bool? = nil,
        cancelToken: CancelToken = CancelToken()
    ) throws -> ReplacementPlan {
        guard let matcher = PCRE2Matcher(pattern: self) else {
            return ReplacementPlan(edits: [], matchCount: 0, truncated: false, byteDelta: 0)
        }
        return try matcher.replacementEdits(
            in: buffer, template: template, limit: limit,
            subjectIsValidUTF8: subjectIsValidUTF8, cancelToken: cancelToken
        )
    }
}

extension PCRE2Matcher {

    /// Sinh kế hoạch thay thế cho toàn bộ `buffer` (FR-SRCH-103).
    ///
    /// Cú pháp chuỗi thay thế là cú pháp PCRE2 ở chế độ mở rộng:
    ///  - `$1`, `${1}`, `${tên}` — nhóm bắt được; nhóm không tham gia thành chuỗi rỗng.
    ///  - `\U` `\L` — ép hoa/thường cho tới `\E`; `\u` `\l` — ép một ký tự kế tiếp.
    ///  - `\n` `\r` `\t` `\xNN` — ký tự điều khiển.
    ///  - `\1`…`\99` được dịch sang `${1}`…`${99}` trước khi đưa cho PCRE2: đó là thói quen
    ///    của người dùng Notepad++, và trong cú pháp PCRE2 thuần thì `\1` vốn là lỗi, nên
    ///    phép dịch này chỉ nới rộng chứ không đổi nghĩa cái gì đang chạy được.
    public func replacementEdits(
        in buffer: UnsafeRawBufferPointer,
        template: String,
        limit: Int = 0,
        subjectIsValidUTF8: Bool? = nil,
        cancelToken: CancelToken = CancelToken()
    ) throws -> ReplacementPlan {

        let templateBytes = Array(PCRE2Pattern.normalizeTemplate(template).utf8)

        // Đường nhanh: chuỗi thay thế không có `$` và không có `\` thì mọi lần khớp cho ra
        // CÙNG MỘT dãy byte. Bỏ hẳn `pcre2_substitute` — và vì Array của Swift là copy-on-write,
        // một triệu `TextEdit` cùng trỏ về một vùng lưu trữ duy nhất thay vì một triệu mảng.
        let isConstant = !templateBytes.contains { $0 == UInt8(ascii: "$") || $0 == UInt8(ascii: "\\") }

        var edits: [TextEdit] = []
        var matchCount = 0
        var truncated = false
        var byteDelta = 0

        // Bộ đệm dùng lại giữa các lần khớp: cấp phát mới cho mỗi kết quả trong một triệu
        // kết quả là tự thua ngay ở phép đo NFR-PERF-08.
        var output = [UInt8](repeating: 0, count: 256)

        try enumerateRaw(
            in: buffer, subjectIsValidUTF8: subjectIsValidUTF8, cancelToken: cancelToken
        ) { cursor in
            matchCount += 1

            let replacement: [UInt8]
            if isConstant {
                replacement = templateBytes
            } else {
                replacement = try Self.expand(
                    template: template,
                    templateBytes: templateBytes,
                    cursor: cursor,
                    code: pattern.codePointer,
                    limits: pattern.limits,
                    output: &output
                )
            }

            edits.append(TextEdit(range: cursor.match.range, bytes: replacement))
            byteDelta += replacement.count - cursor.match.range.count

            if limit > 0 && edits.count >= limit {
                truncated = true
                return false
            }
            return true
        }

        return ReplacementPlan(
            edits: edits, matchCount: matchCount, truncated: truncated, byteDelta: byteDelta
        )
    }

    /// Giãn chuỗi thay thế cho ĐÚNG lần khớp đang giữ trong `cursor`.
    private static func expand(
        template: String,
        templateBytes: [UInt8],
        cursor: PCRE2Pattern.MatchCursor,
        code: OpaquePointer,
        limits: PCRE2Pattern.Limits,
        output: inout [UInt8]
    ) throws -> [UInt8] {

        // PCRE2_SUBSTITUTE_MATCHED — dùng lại lần khớp đã có trong match_data thay vì khớp lại.
        // PCRE2_SUBSTITUTE_REPLACEMENT_ONLY — chỉ trả phần thay thế, không trả cả subject đã
        //   sửa; đây là điều kiện để sinh được `TextEdit` từng vị trí thay vì một khối khổng lồ.
        // PCRE2_SUBSTITUTE_EXTENDED — bật `\U \L \u \l \E`, thứ FR-SRCH-103 gọi tên.
        // PCRE2_SUBSTITUTE_UNSET_EMPTY — nhóm không tham gia thành rỗng thay vì lỗi.
        // PCRE2_SUBSTITUTE_OVERFLOW_LENGTH — khi thiếu chỗ thì trả về ĐỘ DÀI CẦN, để nới đúng
        //   một lần thay vì dò dần.
        let options = PCRE2_SUBSTITUTE_MATCHED
            | PCRE2_SUBSTITUTE_REPLACEMENT_ONLY
            | PCRE2_SUBSTITUTE_EXTENDED
            | PCRE2_SUBSTITUTE_UNSET_EMPTY
            | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH
            | cursor.baseOptions

        for attempt in 0 ..< 2 {
            var outputLength = GEditorPCRE2Size(output.count)
            var rc: Int32 = 0

            templateBytes.withUnsafeBufferPointer { replacement in
                output.withUnsafeMutableBufferPointer { out in
                    rc = pcre2_substitute_8(
                        code,
                        cursor.subject, cursor.subjectLength, cursor.startOffset,
                        options,
                        cursor.matchData, cursor.matchContext,
                        replacement.baseAddress, GEditorPCRE2Size(replacement.count),
                        out.baseAddress, &outputLength
                    )
                }
            }

            if rc >= 0 {
                return Array(output[0 ..< Int(outputLength)])
            }
            if rc == PCRE2_ERROR_NOMEMORY, attempt == 0 {
                // `outputLength` giờ chứa độ dài cần thiết. Cấp dư một chút để lần khớp sau
                // không phải nới lại ngay.
                output = [UInt8](repeating: 0, count: max(Int(outputLength) * 2, 256))
                continue
            }
            if rc == PCRE2_ERROR_BADREPLACEMENT || rc == PCRE2_ERROR_BADSUBSTITUTION
                || rc == PCRE2_ERROR_BADREPESCAPE || rc == PCRE2_ERROR_REPMISSINGBRACE {
                // Với lỗi chuỗi thay thế, PCRE2 đặt offset gây lỗi vào chính biến độ dài.
                throw ReplacementTemplateError(
                    template: template,
                    message: PCRE2Pattern.errorMessage(rc),
                    offset: Int(outputLength)
                )
            }
            throw Self.mapError(rc, limits: limits)
        }

        throw ReplacementTemplateError(
            template: template, message: "không cấp đủ bộ đệm cho chuỗi thay thế", offset: 0
        )
    }

}

extension PCRE2Pattern {

    /// Dịch `\1`…`\99` sang `${1}`…`${99}`, giữ nguyên `\\` và mọi escape khác.
    ///
    /// Dùng `${n}` chứ không phải `$n` để `\1` theo sau bởi chữ số literal không bị nuốt:
    /// `\1` + "23" phải là nhóm 1 rồi "23", không phải nhóm 123.
    static func normalizeTemplate(_ template: String) -> String {
        guard template.contains("\\") else { return template }

        var out = ""
        let characters = Array(template)
        var index = 0
        while index < characters.count {
            guard characters[index] == "\\", index + 1 < characters.count else {
                out.append(characters[index])
                index += 1
                continue
            }

            let next = characters[index + 1]
            if next.isNumber {
                var digits = ""
                var cursor = index + 1
                while cursor < characters.count, characters[cursor].isNumber, digits.count < 2 {
                    digits.append(characters[cursor])
                    cursor += 1
                }
                out += "${\(digits)}"
                index = cursor
            } else {
                // Gồm cả `\\`: nuốt cả hai ký tự để dấu gạch chéo được escape không bị coi là
                // mở đầu một tham chiếu nhóm.
                out.append(characters[index])
                out.append(next)
                index += 2
            }
        }
        return out
    }
}
