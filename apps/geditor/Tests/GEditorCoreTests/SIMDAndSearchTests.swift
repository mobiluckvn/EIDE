import XCTest
import GEditorSIMD
@testable import GEditorCore

/// Truy vết: NFR-PORT-01 (một binary, hai kiến trúc), SAD §2.3 (SIMDDispatch).
///
/// Nhánh vector phải cho KẾT QUẢ Y HỆT nhánh scalar. Test này chạy trên cả runner
/// arm64 và x86_64 trong CI — đó là toàn bộ mục đích của nó.
final class SIMDDispatchTests: XCTestCase {

    private func scalarCountNewlines(_ bytes: [UInt8]) -> Int {
        bytes.filter { $0 == UInt8(ascii: "\n") }.count
    }

    func testBackendMatchesArchitecture() {
        let backend = GEditorCore.simdBackend
        #if arch(arm64)
        XCTAssertEqual(backend, "neon")
        #elseif arch(x86_64)
        XCTAssertTrue(["avx2", "scalar"].contains(backend), "được: \(backend)")
        #endif
    }

    /// Quét mọi độ dài quanh biên vector (16/32 byte) — chỗ nhánh SIMD hay sai nhất.
    func testCountNewlinesMatchesScalarAcrossLengths() {
        for length in 0 ... 600 {
            var bytes = [UInt8](repeating: UInt8(ascii: "a"), count: length)
            for i in stride(from: 0, to: length, by: 7) { bytes[i] = UInt8(ascii: "\n") }
            let simd = bytes.withUnsafeBufferPointer { geditor_count_newlines($0.baseAddress, length) }
            XCTAssertEqual(Int(simd), scalarCountNewlines(bytes), "sai ở độ dài \(length)")
        }
    }

    func testCountNewlinesOnLargeBuffer() {
        let line = Array("một dòng dữ liệu tiếng Việt\n".utf8)
        let bytes = Array(repeating: line, count: 50_000).flatMap { $0 }
        let simd = bytes.withUnsafeBufferPointer { geditor_count_newlines($0.baseAddress, bytes.count) }
        XCTAssertEqual(Int(simd), 50_000)
    }

    func testFindByte() {
        let bytes = Array("abc,def".utf8)
        bytes.withUnsafeBytes { buffer in
            XCTAssertEqual(ByteScan.firstIndex(of: UInt8(ascii: ","), in: buffer), 3)
            XCTAssertNil(ByteScan.firstIndex(of: UInt8(ascii: ";"), in: buffer))
        }
    }

    func testFindByteFromOffset() {
        let bytes = Array("a,b,c".utf8)
        bytes.withUnsafeBytes { buffer in
            XCTAssertEqual(ByteScan.firstIndex(of: UInt8(ascii: ","), in: buffer, from: 2), 3)
            XCTAssertNil(ByteScan.firstIndex(of: UInt8(ascii: ","), in: buffer, from: 4))
        }
    }

    func testLineIndexOnEmptyBuffer() {
        let index = LineIndex(table: PieceTable(text: ""))
        XCTAssertEqual(index.lineCount, 1, "buffer rỗng vẫn có đúng một dòng")
    }

    func testLineIndexIgnoresPhantomLineAfterTrailingNewline() {
        let index = LineIndex(table: PieceTable(text: "a\nb\n"))
        XCTAssertEqual(index.lineCount, 2, "EOL cuối file không tạo thêm dòng thứ ba")
    }
}

/// Truy vết: FR-SRCH-101 (ba chế độ), FR-SRCH-104 (regex an toàn), NFR-REL-05.
final class SearchEngineTests: XCTestCase {

    private let engine = FoundationSearchEngine()

    func testNormalModeTreatsPatternLiterally() throws {
        let bytes = Array("giá 1+1 đồng".utf8)
        let matches = try engine.find(
            pattern: "1+1", in: bytes,
            options: SearchOptions(mode: .normal), limit: 0, cancelToken: CancelToken()
        )
        XCTAssertEqual(matches.count, 1, "chế độ Normal không được diễn giải '+' như regex")
    }

    func testExtendedModeDecodesEscapes() {
        XCTAssertEqual(ExtendedEscape.decode("a\\tb"), "a\tb")
        XCTAssertEqual(ExtendedEscape.decode("a\\nb"), "a\nb")
        XCTAssertEqual(ExtendedEscape.decode("\\x41"), "A")
        XCTAssertEqual(ExtendedEscape.decode("c:\\\\path"), "c:\\path")
    }

    func testRegexModeCapturesGroups() throws {
        let bytes = Array("id=1204 id=77".utf8)
        let matches = try engine.find(
            pattern: "id=(\\d+)", in: bytes,
            options: SearchOptions(mode: .regex), limit: 0, cancelToken: CancelToken()
        )
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].groups.first??.count, 4)
    }

    /// Offset trả về phải là BYTE, không phải UTF-16 — hợp đồng của toàn bộ lõi.
    func testMatchOffsetsAreByteOffsets() throws {
        let text = "Tiếng Việt ERROR"
        let bytes = Array(text.utf8)
        let matches = try engine.find(
            pattern: "ERROR", in: bytes,
            options: SearchOptions(mode: .normal, matchCase: true), limit: 0, cancelToken: CancelToken()
        )
        XCTAssertEqual(matches.count, 1)
        let matched = String(decoding: bytes[matches[0].range], as: UTF8.self)
        XCTAssertEqual(matched, "ERROR", "cắt buffer theo offset trả về phải ra đúng chuỗi khớp")
    }

    func testLimitStopsEarly() throws {
        let bytes = Array(String(repeating: "x", count: 100).utf8)
        let matches = try engine.find(
            pattern: "x", in: bytes,
            options: SearchOptions(mode: .normal), limit: 5, cancelToken: CancelToken()
        )
        XCTAssertEqual(matches.count, 5)
    }

    func testCancelledTokenStopsSearch() {
        let bytes = Array(String(repeating: "x", count: 1000).utf8)
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(
            try engine.find(
                pattern: "x", in: bytes,
                options: SearchOptions(mode: .normal), limit: 0, cancelToken: token
            )
        ) { error in
            XCTAssertTrue(error is OperationCancelled)
        }
    }

    func testDeadlineTokenReportsLimit() {
        let token = CancelToken(timeout: 0)
        XCTAssertThrowsError(try token.check()) { error in
            XCTAssertTrue(error is DeadlineExceeded)
        }
    }
}
