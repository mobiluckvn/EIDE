import XCTest
@testable import GEditorCore

final class HexDumpTests: XCTestCase {

    // MARK: - Đếm dòng

    func testTEProngCOkhongDONG_khongPHAImotDONGtrong() {
        // Một dòng toàn dấu chấm cho tệp rỗng trông y hệt một tệp 16 byte NUL.
        XCTAssertEqual(HexDump.rowCount(forSize: 0), 0)
        XCTAssertEqual(HexDump.rowCount(forSize: 1), 1)
        XCTAssertEqual(HexDump.rowCount(forSize: 16), 1)
        XCTAssertEqual(HexDump.rowCount(forSize: 17), 2)
    }

    func testKHOANGbyteCUAdongCUOIbiCATtheoCOtep() {
        XCTAssertEqual(HexDump.byteRange(ofRow: 0, size: 5), 0 ..< 5)
        XCTAssertEqual(HexDump.byteRange(ofRow: 1, size: 20), 16 ..< 20)
        // Dòng vượt quá tệp trả về khoảng RỖNG, không phải khoảng âm hay chỉ số ngoài biên.
        XCTAssertEqual(HexDump.byteRange(ofRow: 99, size: 20), 20 ..< 20)
    }

    // MARK: - Cột offset

    func testCOToffsetNOIrongTHEOcoTEP() {
        XCTAssertEqual(HexDump.offsetColumn(0, size: 100), "00000000")
        XCTAssertEqual(HexDump.offsetColumn(255, size: 100_000), "000000FF")
    }

    func testTEPvuot4GBkhongBIcutCHUsoDAU() {
        // 8 ký tự chỉ đủ tới 0xFFFFFFFF. Một offset cụt là một offset SAI mà trông vẫn hợp lý.
        let size = 0x1_0000_0000 + 32
        XCTAssertEqual(HexDump.offsetColumn(0x1_0000_0010, size: size), "100000010")
        XCTAssertEqual(HexDump.offsetColumn(0, size: size).count, 9)
    }

    // MARK: - Cột hex

    func testCOThexCOkhoangTRANGgiuaBYTEthu8vaTHU9() {
        let bytes: [UInt8] = Array(0 ..< 16)
        let column = HexDump.hexColumn(bytes)
        XCTAssertEqual(column, "00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F")
    }

    func testDONGcuoiDUOCdemDEcotCHUkhongNHAYcho() {
        let full = HexDump.hexColumn(Array(0 ..< 16))
        let short = HexDump.hexColumn([0x41, 0x42])
        XCTAssertEqual(
            short.count, full.count,
            "dòng thiếu byte phải đệm cho đủ, nếu không cột chữ của dòng cuối lệch khỏi các dòng trên"
        )
    }

    // MARK: - Cột chữ

    func testBYTEkhongINduocTHANHdauCHAM() {
        XCTAssertEqual(HexDump.asciiColumn([0x48, 0x69, 0x00, 0x0A, 0x7F, 0xFF]), "Hi....")
    }

    func testKHONGgiaiMAutf8_vICOTchuPHAIthangHANGvoiCOThex() {
        // "ế" là ba byte trong UTF-8. Giải mã ra một ký tự thì cột chữ ngắn đi hai ô và không
        // còn dóng được với cột hex — mà sự thẳng hàng ấy chính là công dụng của cột này.
        let bytes = Array("ế".utf8)
        XCTAssertEqual(bytes.count, 3)
        XCTAssertEqual(HexDump.asciiColumn(bytes), "...")
    }

    // MARK: - Dòng đầy đủ

    func testMOTdongDAYdu() {
        let bytes = Array("Xin chao GEditor".utf8)
        XCTAssertEqual(bytes.count, 16)
        XCTAssertEqual(
            HexDump.line(offset: 0, bytes: bytes, size: 16),
            "00000000  58 69 6E 20 63 68 61 6F  20 47 45 64 69 74 6F 72  |Xin chao GEditor|"
        )
    }

    func testNHIEUdongDUNGtuMOTkhoiBYTE() {
        let bytes = Array("ABCDEFGHIJKLMNOPQR".utf8)      // 18 byte → hai dòng
        let text = HexDump.text(from: bytes, startingAt: 0, size: bytes.count)
        let lines = text.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("00000000"))
        XCTAssertTrue(lines[1].hasPrefix("00000010"))
        XCTAssertTrue(lines[1].hasSuffix("|QR|"), "dòng cuối chỉ có 2 byte: \(lines[1])")
    }

    func testCHEPraGIONGhetTHUdangNHIN() {
        // Nút Chép và khung xem dùng CHUNG hàm này — đó là cả lý do nó nằm ở lõi.
        let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let line = HexDump.line(offset: 32, bytes: bytes, size: 36)
        XCTAssertEqual(HexDump.text(from: bytes, startingAt: 32, size: 36), line)
    }
}
