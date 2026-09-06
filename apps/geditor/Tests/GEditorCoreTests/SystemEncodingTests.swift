import XCTest
@testable import GEditorCore

/// Bảng mã do hệ điều hành chuyển đổi (FR-ENC-201).
///
/// Byte mong đợi do codec của Python sinh (`scripts/generate-system-encoding-fixtures.py`);
/// ở đây là CoreFoundation của macOS. Hai hiện thực độc lập, không chung dòng mã nào — khớp
/// nhau mới là bằng chứng, chứ không phải "chạy thấy không lỗi".
final class SystemEncodingTests: XCTestCase {

    func testEveryDeclaredEncodingExistsOnThisMachine() {
        for encoding in TextEncoding.allCases {
            XCTAssertTrue(encoding.isAvailable,
                          "\(encoding.displayName) khai báo nhưng máy không có bộ chuyển đổi")
        }
    }

    /// Byte trên đĩa → chữ. Đây là chiều làm hỏng dữ liệu nếu sai: người dùng mở file ra và
    /// thấy chữ khác.
    func testDecodeMatchesPython() throws {
        for sample in SystemEncodingFixtures.all {
            let utf8 = try EncodingConverter.decode(sample.bytes, from: sample.encoding)
            XCTAssertEqual(String(decoding: utf8, as: UTF8.self), sample.text,
                           "giải mã \(sample.encoding.displayName)")
        }
    }

    /// Chữ → byte trên đĩa.
    func testEncodeMatchesPython() {
        for sample in SystemEncodingFixtures.all {
            let result = EncodingConverter.encode(Array(sample.text.utf8), to: sample.encoding)
            XCTAssertEqual(result.unrepresentable, 0, "\(sample.encoding.displayName) báo mất ký tự")
            XCTAssertEqual(result.bytes, sample.bytes, "mã hoá \(sample.encoding.displayName)")
        }
    }

    func testRoundTrip() throws {
        for sample in SystemEncodingFixtures.all {
            let encoded = EncodingConverter.encode(Array(sample.text.utf8), to: sample.encoding)
            let decoded = try EncodingConverter.decode(encoded.bytes, from: sample.encoding)
            XCTAssertEqual(String(decoding: decoded, as: UTF8.self), sample.text,
                           "vòng tròn \(sample.encoding.displayName)")
        }
    }

    // MARK: - Mất ký tự khi lưu (FR-ENC-203)

    /// Lưu chữ Việt sang Shift-JIS là mất chữ. Con số mất PHẢI đúng, vì lớp trên dựa vào nó
    /// để hỏi lại người dùng trước khi ghi đè file.
    func testCountsUnrepresentableCharacters() {
        // "Tiếng Việt": chỉ "ế" và "ệ" là không có trong Shift-JIS, phần còn lại là ASCII.
        let result = EncodingConverter.encode(Array("Tiếng Việt".utf8), to: .shiftJIS)
        XCTAssertEqual(result.unrepresentable, 2, "phải đếm đúng số ký tự mất")
        XCTAssertEqual(result.firstUnrepresentable, 0x1EBF, "ký tự đầu tiên mất phải là \"ế\"")
        XCTAssertFalse(result.bytes.isEmpty, "không được trả về rỗng")
    }

    /// Hồi quy cho lỗi đã có: đường mã hoá qua Foundation từng trả `unrepresentable: 0` KỂ CẢ
    /// khi chuyển đổi hỏng hoàn toàn — người dùng lưu ra file rỗng sau một hộp thoại nói mọi
    /// thứ ổn.
    func testFailedConversionIsNeverReportedAsClean() {
        let result = EncodingConverter.encode(Array("日本語テキスト".utf8), to: .isoLatin1)
        XCTAssertGreaterThan(result.unrepresentable, 0, "mất ký tự mà báo sạch là lỗi mất dữ liệu")
    }

    /// Bảng mã nhiều byte không được nhận nhầm là codec một byte.
    func testMultiByteEncodingsAreNotSingleByteCodecs() {
        for encoding in [TextEncoding.shiftJIS, .gb18030, .eucKR, .big5] {
            XCTAssertNil(encoding.singleByteCodec, "\(encoding.displayName)")
            XCTAssertFalse(encoding.isVietnameseLegacy)
        }
    }
}
