import XCTest
@testable import GEditorCore

/// Mẫu dò bảng mã bị cắt giữa một ký tự nhiều byte (lỗi tìm ra khi dựng PoC-A).
///
/// Đây là lỗi MẤT DỮ LIỆU chứ không phải hiển thị xấu: `Document.open` giải mã cả file theo
/// bảng mã đoán sai, người dùng thấy chữ sai, và lưu lại là hỏng file thật.
final class EncodingSampleBoundaryTests: XCTestCase {

    /// "ề" là 3 byte (E1 BB 81), mà 262.144 chia 3 dư 1 — chỗ cắt luôn rơi vào giữa ký tự.
    private func makeUTF8BeyondSample() -> [UInt8] {
        let count = EncodingDetector.sampleBytes / 3 + 1_000
        return Array(String(repeating: "ề", count: count).utf8)
    }

    func testLargeVietnameseUTF8IsNotMistakenForLegacy() {
        let bytes = makeUTF8BeyondSample()
        XCTAssertGreaterThan(bytes.count, EncodingDetector.sampleBytes)
        // Chốt lại tiền đề của phép thử: chỗ cắt PHẢI rơi vào byte tiếp nối.
        XCTAssertTrue((0x80 ... 0xBF).contains(bytes[EncodingDetector.sampleBytes]))

        let guesses = EncodingDetector.detect(bytes)
        XCTAssertEqual(guesses.first?.encoding, .utf8)
        XCTAssertGreaterThan(guesses.first?.confidence ?? 0, 0.9)
    }

    /// Mở thật qua `Document`: nội dung phải nguyên vẹn từng byte.
    func testDocumentOpenKeepsBytesIntact() throws {
        let bytes = makeUTF8BeyondSample()
        let path = NSTemporaryDirectory() + "geditor-bien-mau-\(UUID().uuidString).txt"
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        defer { unlink(path) }

        let document = try Document.open(path: path)
        XCTAssertEqual(document.encoding, .utf8)
        // Đoán sai bảng mã thì buffer PHÌNH ra vì giải mã một byte thành nhiều byte.
        XCTAssertEqual(document.buffer.count, bytes.count)
    }

    // MARK: - Bản thân phép cắt

    func testTrimRemovesOnlyIncompleteTail() {
        let complete = Array("ềab".utf8)
        XCTAssertEqual(EncodingDetector.trimmedToUTF8Boundary(complete), complete)

        let cutMidCharacter = Array("abcề".utf8).dropLast()            // thiếu 1 byte cuối
        XCTAssertEqual(EncodingDetector.trimmedToUTF8Boundary(Array(cutMidCharacter)),
                       Array("abc".utf8))

        let cutAfterLead = Array("abcề".utf8).dropLast(2)              // chỉ còn byte dẫn đầu
        XCTAssertEqual(EncodingDetector.trimmedToUTF8Boundary(Array(cutAfterLead)),
                       Array("abc".utf8))
    }

    /// Dữ liệu legacy KHÔNG được đụng tới: mấy byte cuối của nó chỉ là byte, không phải chuỗi
    /// dở dang. Cắt nhầm ở đây sẽ làm điểm của bảng mã legacy lệch đi.
    func testTrimLeavesLegacyBytesAlone() {
        let tcvn3 = EncodingConverter.encode(Array("Tiếng Việt".utf8), to: .tcvn3).bytes
        let trimmed = EncodingDetector.trimmedToUTF8Boundary(tcvn3)
        // Byte cuối của chuỗi này là 't' (ASCII) nên không có gì để cắt.
        XCTAssertEqual(trimmed, tcvn3)
    }
}
