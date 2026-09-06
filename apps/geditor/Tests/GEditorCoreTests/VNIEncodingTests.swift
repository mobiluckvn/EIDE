import XCTest
@testable import GEditorCore

/// Bảng mã VNI-Windows (FR-ENC-201).
///
/// VNI là bảng mã Việt legacy DUY NHẤT dùng hai byte cho chữ có dấu, nên nó không đi qua
/// `SingleByteCodec` và cần bộ kiểm riêng.
final class VNIEncodingTests: XCTestCase {

    /// Giá trị neo, đối chiếu với mô tả công khai của bảng mã VNI: À = 41 D8, á = 61 F9.
    ///
    /// Có mặt để nếu ai đó thay file UCM bằng bảng khác thì test này vỡ ngay, chứ không chờ
    /// tới khi người dùng mở file ra thấy chữ lạ.
    func testAnchorValues() {
        XCTAssertEqual(EncodingConverter.encode(Array("À".utf8), to: .vni).bytes, [0x41, 0xD8])
        XCTAssertEqual(EncodingConverter.encode(Array("á".utf8), to: .vni).bytes, [0x61, 0xF9])
        XCTAssertEqual(EncodingConverter.encode(Array("đ".utf8), to: .vni).bytes, [0xF1])
        XCTAssertEqual(EncodingConverter.encode(Array("ế".utf8), to: .vni).bytes, [0x65, 0xE1])
    }

    /// Khứ hồi trên TOÀN BỘ bảng: mọi ký tự bảng mã biết phải đi và về nguyên vẹn.
    func testEveryMappingRoundTrips() throws {
        for entry in VNIEncodingTable.doubleByte {
            let scalar = Unicode.Scalar(entry.scalar)!
            let text = String(scalar)
            let encoded = EncodingConverter.encode(Array(text.utf8), to: .vni)
            XCTAssertEqual(encoded.unrepresentable, 0, "\(text)")
            XCTAssertEqual(encoded.bytes, [entry.base, entry.mark], "\(text)")

            let decoded = try EncodingConverter.decode(encoded.bytes, from: .vni)
            XCTAssertEqual(String(decoding: decoded, as: UTF8.self), text)
        }

        for (byte, value) in VNIEncodingTable.singleByte.enumerated() where value != 0xFFFD {
            let text = String(Unicode.Scalar(value)!)
            let decoded = try EncodingConverter.decode([UInt8(byte)], from: .vni)
            XCTAssertEqual(String(decoding: decoded, as: UTF8.self), text, "byte 0x\(String(byte, radix: 16))")
        }
    }

    func testFullSentenceRoundTrips() throws {
        let sentence = "Cộng hòa Xã hội Chủ nghĩa Việt Nam. Thừa Thiên Huế, Đà Nẵng, "
            + "Quảng Ngãi, Bà Rịa Vũng Tàu, Đắk Lắk."
        let encoded = EncodingConverter.encode(Array(sentence.utf8), to: .vni)
        XCTAssertEqual(encoded.unrepresentable, 0)
        let decoded = try EncodingConverter.decode(encoded.bytes, from: .vni)
        XCTAssertEqual(String(decoding: decoded, as: UTF8.self), sentence)
    }

    /// Đặc điểm nhận dạng của VNI: file DÀI HƠN số ký tự, vì chữ có dấu tốn hai byte.
    func testTonedCharactersTakeTwoBytes() {
        let text = "Việt"
        let encoded = EncodingConverter.encode(Array(text.utf8), to: .vni)
        // V-i-ệ-t = 4 ký tự, trong đó "ệ" tốn 2 byte → 5 byte.
        XCTAssertEqual(encoded.bytes.count, 5)
        XCTAssertEqual(text.count, 4)
    }

    /// Chữ ở dạng TỔ HỢP cũng phải mã hoá được — một số bộ gõ sinh ra dạng này.
    func testDecomposedInputIsComposedBeforeEncoding() {
        let decomposed = "Việt".decomposedStringWithCanonicalMapping
        XCTAssertNotEqual(decomposed.unicodeScalars.count, "Việt".unicodeScalars.count)
        let encoded = EncodingConverter.encode(Array(decomposed.utf8), to: .vni)
        XCTAssertEqual(encoded.unrepresentable, 0, "dạng tổ hợp bị coi là không mã hoá được")
        XCTAssertEqual(encoded.bytes, EncodingConverter.encode(Array("Việt".utf8), to: .vni).bytes)
    }

    /// Ký tự ngoài kho phải được BÁO mất, không im lặng.
    func testCharactersOutsideCharsetAreReported() {
        let result = EncodingConverter.encode(Array("a — b".utf8), to: .vni)
        XCTAssertEqual(result.unrepresentable, 1)
        XCTAssertEqual(result.firstUnrepresentable, 0x2014)
    }

    // MARK: - Nhận diện

    func testVNIContentIsDetected() {
        let sentence = "Cộng hòa Xã hội Chủ nghĩa Việt Nam. Thừa Thiên Huế, Đà Nẵng, "
            + "Quảng Ngãi, Bà Rịa Vũng Tàu."
        let bytes = EncodingConverter.encode(Array(sentence.utf8), to: .vni).bytes
        let guesses = EncodingDetector.detect(bytes)
        XCTAssertEqual(guesses.first?.encoding, .vni,
                       "đoán: \(guesses.prefix(3).map { "\($0.encoding.rawValue) \(Int($0.confidence * 100))%" })")
    }

    /// Bộ nhận diện phải dùng ĐÚNG bộ tách byte của bộ giải mã. Hai bản sao của quy tắc "tham
    /// lam" sẽ lệch nhau, và khi ấy nhận diện nói một đằng còn mở file ra một nẻo.
    func testDetectorAndDecoderAgreeOnByteSplitting() {
        let bytes = EncodingConverter.encode(Array("Đắk Lắk, Bình Định".utf8), to: .vni).bytes
        var scanned = 0
        VNICodec.scan(bytes) { _, consumed in scanned += consumed }
        XCTAssertEqual(scanned, bytes.count, "bộ tách byte bỏ sót hoặc ăn lố")
    }
}
