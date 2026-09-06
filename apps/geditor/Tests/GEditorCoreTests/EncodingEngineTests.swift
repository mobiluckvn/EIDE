import XCTest
@testable import GEditorCore

/// Truy vết: FR-ENC-202 (BOM), FR-ENC-204 (EOL hỗn hợp), FR-ENC-206 (NFC/NFD).
/// Tương ứng TC-ENC-04/05 trong STP §3.3.
final class EncodingEngineTests: XCTestCase {

    // MARK: - BOM

    func testDetectUTF8BOM() {
        let bom = EncodingEngine.detectBOM([0xEF, 0xBB, 0xBF, 0x61])
        XCTAssertEqual(bom?.length, 3)
        XCTAssertEqual(bom?.encoding, .utf8)
    }

    /// BOM UTF-32 LE bắt đầu bằng đúng hai byte của BOM UTF-16 LE — thứ tự kiểm tra
    /// sai sẽ nhận nhầm và làm hỏng toàn bộ nội dung file.
    func testUTF32LEIsNotMistakenForUTF16LE() {
        let bom = EncodingEngine.detectBOM([0xFF, 0xFE, 0x00, 0x00, 0x41])
        XCTAssertEqual(bom?.encoding, .utf32LittleEndian)
        XCTAssertEqual(bom?.length, 4)
    }

    func testNoBOM() {
        XCTAssertNil(EncodingEngine.detectBOM(Array("xin chào".utf8)))
    }

    // MARK: - EOL (TC-ENC-04)

    func testAnalyzeMixedEOL() {
        let report = EncodingEngine.analyzeEOL(Array("a\r\nb\nc\rd".utf8))
        XCTAssertEqual(report.crlf, 1)
        XCTAssertEqual(report.lf, 1)
        XCTAssertEqual(report.cr, 1)
        XCTAssertTrue(report.isMixed, "file trộn EOL phải kích hoạt banner cảnh báo")
    }

    func testPureLFIsNotMixed() {
        let report = EncodingEngine.analyzeEOL(Array("a\nb\nc\n".utf8))
        XCTAssertFalse(report.isMixed)
        XCTAssertEqual(report.dominant, .lf)
    }

    func testCRLFIsCountedOnceNotAsCRPlusLF() {
        let report = EncodingEngine.analyzeEOL(Array("a\r\nb\r\n".utf8))
        XCTAssertEqual(report.crlf, 2)
        XCTAssertEqual(report.cr, 0)
        XCTAssertEqual(report.lf, 0)
    }

    func testNormalizeMixedEOLToLF() {
        let converted = EncodingEngine.convertEOL(Array("a\r\nb\nc\rd".utf8), to: .lf)
        XCTAssertEqual(String(decoding: converted, as: UTF8.self), "a\nb\nc\nd")
    }

    func testConvertEOLToCRLF() {
        let converted = EncodingEngine.convertEOL(Array("a\nb\n".utf8), to: .crlf)
        XCTAssertEqual(String(decoding: converted, as: UTF8.self), "a\r\nb\r\n")
    }

    // MARK: - NFC/NFD (TC-ENC-05)

    func testVietnameseNFCvsNFDDifferInBytes() {
        let nfc = EncodingEngine.normalize("Tiếng Việt", to: .nfc)
        let nfd = EncodingEngine.normalize("Tiếng Việt", to: .nfd)
        XCTAssertNotEqual(
            Array(nfc.utf8), Array(nfd.utf8),
            "NFC và NFD phải khác byte — đây chính là nguồn lỗi tìm kiếm trượt trên macOS"
        )
        XCTAssertTrue(EncodingEngine.canonicallyEqual(nfc, nfd))
    }

    func testNormalizeIsIdempotent() {
        let once = EncodingEngine.normalize("Đà Nẵng", to: .nfc)
        let twice = EncodingEngine.normalize(once, to: .nfc)
        XCTAssertEqual(once, twice)
    }

    func testNFCRoundTripFromNFD() {
        let nfd = EncodingEngine.normalize("Huế", to: .nfd)
        XCTAssertEqual(EncodingEngine.normalize(nfd, to: .nfc), "Huế")
    }
}
