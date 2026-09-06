import Foundation

/// Kiểu xuống dòng (FR-ENC-204).
public enum EOL: String, CaseIterable {
    case lf = "LF"        // Unix/macOS
    case crlf = "CRLF"    // Windows
    case cr = "CR"        // Mac cổ điển

    public var bytes: [UInt8] {
        switch self {
        case .lf: return [0x0A]
        case .crlf: return [0x0D, 0x0A]
        case .cr: return [0x0D]
        }
    }
}

/// Kết quả phân tích EOL của một tài liệu.
public struct EOLReport: Equatable {
    public var lf: Int
    public var crlf: Int
    public var cr: Int

    public var total: Int { lf + crlf + cr }

    /// Kiểu chiếm đa số; `nil` khi tài liệu không có dòng nào kết thúc.
    public var dominant: EOL? {
        guard total > 0 else { return nil }
        if crlf >= lf && crlf >= cr { return .crlf }
        if lf >= cr { return .lf }
        return .cr
    }

    /// File trộn nhiều kiểu EOL → banner cảnh báo + nút chuẩn hóa một bước (UI/UX §4.2).
    public var isMixed: Bool {
        [lf, crlf, cr].filter { $0 > 0 }.count > 1
    }
}

/// Phát hiện BOM, phân tích/chuyển đổi EOL, chuẩn hóa Unicode (FR-ENC-204, FR-ENC-206).
///
/// Phần bảng mã đã tách ra thành các kiểu riêng, mỗi kiểu một việc:
///  - `TextEncoding` + `EncodingConverter` — đọc/ghi byte theo bảng mã (FR-ENC-201).
///  - `EncodingDetector` — nhận diện kèm độ tin cậy (FR-ENC-202).
///  - `EncodingChange` — "diễn giải lại" và "chuyển đổi sang" là hai kiểu TÁCH BẠCH,
///    vì lẫn hai thao tác này là cách mất dữ liệu dễ nhất (FR-ENC-203).
///
/// TODO(FR-ENC-201): còn thiếu VNI-Windows. Nó là bảng mã HAI BYTE (chữ nền + byte dấu) và
/// không có bộ chuyển đổi nào trên máy để suy bảng ra — xem `scripts/generate-encoding-tables.py`
/// về lý do không gõ bảng bằng tay. Cần bản đặc tả của nhà cung cấp trước khi làm.
public enum EncodingEngine {

    public struct BOM: Equatable {
        public let encoding: String.Encoding
        public let length: Int
        public let name: String
    }

    private static let bomTable: [(bytes: [UInt8], encoding: String.Encoding, name: String)] = [
        ([0x00, 0x00, 0xFE, 0xFF], .utf32BigEndian, "UTF-32 BE"),
        ([0xFF, 0xFE, 0x00, 0x00], .utf32LittleEndian, "UTF-32 LE"),
        ([0xEF, 0xBB, 0xBF], .utf8, "UTF-8 BOM"),
        ([0xFE, 0xFF], .utf16BigEndian, "UTF-16 BE"),
        ([0xFF, 0xFE], .utf16LittleEndian, "UTF-16 LE"),
    ]

    /// Nhận diện BOM ở đầu file. Thứ tự kiểm tra UTF-32 trước UTF-16 là bắt buộc:
    /// BOM UTF-32 LE bắt đầu bằng đúng hai byte của BOM UTF-16 LE.
    public static func detectBOM(_ bytes: [UInt8]) -> BOM? {
        for entry in bomTable where bytes.count >= entry.bytes.count {
            if Array(bytes.prefix(entry.bytes.count)) == entry.bytes {
                return BOM(encoding: entry.encoding, length: entry.bytes.count, name: entry.name)
            }
        }
        return nil
    }

    /// Kiểm tra chuỗi byte có phải UTF-8 hợp lệ hay không.
    public static func isValidUTF8(_ bytes: [UInt8]) -> Bool {
        String(bytes: bytes, encoding: .utf8) != nil
    }

    // MARK: - EOL

    public static func analyzeEOL(_ bytes: [UInt8]) -> EOLReport {
        var report = EOLReport(lf: 0, crlf: 0, cr: 0)
        var i = 0
        while i < bytes.count {
            if bytes[i] == 0x0D {
                if i + 1 < bytes.count && bytes[i + 1] == 0x0A {
                    report.crlf += 1
                    i += 2
                    continue
                }
                report.cr += 1
            } else if bytes[i] == 0x0A {
                report.lf += 1
            }
            i += 1
        }
        return report
    }

    /// Chuẩn hóa mọi kiểu EOL về `target` — một thao tác, một bước undo (FR-ENC-204).
    public static func convertEOL(_ bytes: [UInt8], to target: EOL) -> [UInt8] {
        let replacement = target.bytes
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            if bytes[i] == 0x0D {
                out.append(contentsOf: replacement)
                i += (i + 1 < bytes.count && bytes[i + 1] == 0x0A) ? 2 : 1
            } else if bytes[i] == 0x0A {
                out.append(contentsOf: replacement)
                i += 1
            } else {
                out.append(bytes[i])
                i += 1
            }
        }
        return out
    }

    // MARK: - Chuẩn hóa Unicode (FR-ENC-206)

    public enum NormalizationForm: String, CaseIterable, Sendable {
        case nfc, nfd, nfkc, nfkd
    }

    /// Chuẩn hóa Unicode.
    ///
    /// Vì sao là P0 trên thực tế dù SRS xếp P1: macOS sinh NFD, Windows/Web dùng NFC.
    /// Cùng một chữ "ế" ở hai dạng có byte khác nhau → tìm kiếm trượt, diff báo khác,
    /// CSV so khóa sai. Mặc định `normalize-on-save = NFC` (UI/UX §8.1).
    public static func normalize(_ text: String, to form: NormalizationForm) -> String {
        switch form {
        case .nfc: return text.precomposedStringWithCanonicalMapping
        case .nfd: return text.decomposedStringWithCanonicalMapping
        case .nfkc: return text.precomposedStringWithCompatibilityMapping
        case .nfkd: return text.decomposedStringWithCompatibilityMapping
        }
    }

    /// Hai chuỗi có bằng nhau sau khi chuẩn hóa canonical hay không.
    /// Chế độ tìm kiếm Normal phải khớp cả NFC lẫn NFD (UI/UX §10).
    public static func canonicallyEqual(_ a: String, _ b: String) -> Bool {
        a.precomposedStringWithCanonicalMapping == b.precomposedStringWithCanonicalMapping
    }
}
