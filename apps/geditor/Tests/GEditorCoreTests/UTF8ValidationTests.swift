import XCTest
@testable import GEditorCore

/// Kiểm thử `ByteScan.isValidUTF8`.
///
/// Vì sao bộ test này khắt khe hơn vẻ ngoài của hàm: kết quả của nó quyết định có truyền
/// `PCRE2_NO_UTF_CHECK` cho PCRE2 hay không. Một lần trả `true` NHẦM trên dữ liệu hỏng là
/// PCRE2 chạy với giả định sai và có thể đọc ra ngoài biên buffer — lỗi bộ nhớ, không phải
/// lỗi kết quả. Nên mọi dạng UTF-8 sai đều phải có mặt ở đây, kể cả những dạng mà bộ kiểm
/// "đếm byte tiếp nối" ngây thơ vẫn cho qua.
final class UTF8ValidationTests: XCTestCase {

    private func assertValid(_ bytes: [UInt8], _ message: String, line: UInt = #line) {
        XCTAssertTrue(ByteScan.isValidUTF8(bytes), message, line: line)
    }

    private func assertInvalid(_ bytes: [UInt8], _ message: String, line: UInt = #line) {
        XCTAssertFalse(ByteScan.isValidUTF8(bytes), message, line: line)
    }

    // MARK: - Hợp lệ

    func testValidSequences() {
        assertValid([], "buffer rỗng")
        assertValid(Array("ASCII thuần".utf8), "ASCII")
        assertValid(Array("Thừa Thiên Huế".utf8), "tiếng Việt có dấu")
        assertValid(Array("日本語".utf8), "ba byte")
        assertValid(Array("😀".utf8), "bốn byte")
        assertValid([0x00, 0x7F], "biên một byte")
        assertValid([0xC2, 0x80], "U+0080 — điểm mã hai byte nhỏ nhất")
        assertValid([0xDF, 0xBF], "U+07FF — điểm mã hai byte lớn nhất")
        assertValid([0xE0, 0xA0, 0x80], "U+0800 — ba byte nhỏ nhất")
        assertValid([0xEF, 0xBF, 0xBF], "U+FFFF")
        assertValid([0xF0, 0x90, 0x80, 0x80], "U+10000 — bốn byte nhỏ nhất")
        assertValid([0xF4, 0x8F, 0xBF, 0xBF], "U+10FFFF — điểm mã lớn nhất")
    }

    // MARK: - Không hợp lệ

    func testStrayContinuationByte() {
        assertInvalid([0x80], "byte tiếp nối đứng một mình")
        assertInvalid([0x41, 0xBF, 0x42], "byte tiếp nối lạc giữa ASCII")
    }

    func testOverlongEncodings() {
        // Đây là dạng mà bộ kiểm ngây thơ bỏ lọt: đúng số byte tiếp nối, sai điểm mã.
        assertInvalid([0xC0, 0x80], "mã hóa dài dư của U+0000")
        assertInvalid([0xC1, 0xBF], "mã hóa dài dư của U+007F")
        assertInvalid([0xE0, 0x80, 0x80], "mã hóa dài dư ba byte")
        assertInvalid([0xE0, 0x9F, 0xBF], "ba byte dưới U+0800")
        assertInvalid([0xF0, 0x80, 0x80, 0x80], "mã hóa dài dư bốn byte")
        assertInvalid([0xF0, 0x8F, 0xBF, 0xBF], "bốn byte dưới U+10000")
    }

    func testSurrogatesAreRejected() {
        // U+D800…U+DFFF chỉ tồn tại trong UTF-16; UTF-8 cấm mã hóa chúng.
        assertInvalid([0xED, 0xA0, 0x80], "U+D800")
        assertInvalid([0xED, 0xBF, 0xBF], "U+DFFF")
        assertValid([0xED, 0x9F, 0xBF], "U+D7FF — ngay dưới vùng thay thế, vẫn hợp lệ")
        assertValid([0xEE, 0x80, 0x80], "U+E000 — ngay trên vùng thay thế, vẫn hợp lệ")
    }

    func testBeyondMaximumCodePoint() {
        assertInvalid([0xF4, 0x90, 0x80, 0x80], "U+110000 vượt trần Unicode")
        assertInvalid([0xF5, 0x80, 0x80, 0x80], "0xF5 không bao giờ hợp lệ")
        assertInvalid([0xFF], "0xFF không bao giờ hợp lệ")
        assertInvalid([0xFE], "0xFE không bao giờ hợp lệ")
    }

    func testTruncatedSequences() {
        assertInvalid([0xC2], "hai byte bị cắt")
        assertInvalid([0xE0, 0xA0], "ba byte bị cắt")
        assertInvalid([0xF0, 0x90, 0x80], "bốn byte bị cắt")
        assertInvalid(Array("Huế".utf8).dropLast(), "ký tự cuối bị cắt")
    }

    func testWrongContinuationByte() {
        assertInvalid([0xE0, 0xA0, 0x41], "byte thứ ba là ASCII")
        assertInvalid([0xF0, 0x90, 0x80, 0xC2], "byte thứ tư là byte mở đầu")
    }

    // MARK: - Đối chứng

    /// So với bộ giải mã của Swift trên dữ liệu ngẫu nhiên.
    ///
    /// `String(decoding:as:)` thay mọi chuỗi hỏng bằng U+FFFD, nên "giải mã rồi mã hóa lại
    /// ra đúng byte ban đầu" tương đương "hợp lệ". Đây là bên đối chứng độc lập, không dùng
    /// chung một dòng logic nào với hàm đang kiểm.
    func testAgreesWithSwiftDecoderOnRandomBytes() {
        var state: UInt64 = 0x5EED
        func nextByte() -> UInt8 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return UInt8(truncatingIfNeeded: state)
        }

        for _ in 0 ..< 3_000 {
            let length = Int(nextByte() % 12)
            let bytes = (0 ..< length).map { _ in nextByte() }
            let roundTrip = Array(String(decoding: bytes, as: UTF8.self).utf8)
            XCTAssertEqual(
                ByteScan.isValidUTF8(bytes), roundTrip == bytes,
                "bất đồng trên \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))"
            )
        }
    }

    /// Dữ liệu ngẫu nhiên gần như luôn hỏng, nên phải kiểm thêm trên chuỗi UTF-8 THẬT bị
    /// làm hỏng một chỗ — đó mới là hình dạng của file thật.
    func testAgreesWithSwiftDecoderOnCorruptedText() {
        let source = Array("Đơn hàng DH-0091 — Công ty Anh Đào, CN Huế 🇻🇳".utf8)
        for position in source.indices {
            for replacement: UInt8 in [0x80, 0xC0, 0xED, 0xF5, 0xFF, 0x41] {
                var corrupted = source
                corrupted[position] = replacement
                let roundTrip = Array(String(decoding: corrupted, as: UTF8.self).utf8)
                XCTAssertEqual(
                    ByteScan.isValidUTF8(corrupted), roundTrip == corrupted,
                    "bất đồng khi đổi byte \(position) thành \(String(format: "%02X", replacement))"
                )
            }
        }
    }
}
