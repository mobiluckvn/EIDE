import XCTest
@testable import GEditorCore

/// Kiểm thử bảng mã tiếng Việt legacy (FR-ENC-201, FR-ENC-202, FR-ENC-203).
///
/// Bên đối chứng là `LegacyEncodingFixtures` — byte do `iconv` của hệ thống sinh ra, chép vào
/// repo lúc chạy `scripts/generate-encoding-tables.py`. Nghĩa là test so codec của ta với một
/// hiện thực ĐỘC LẬP, chứ không so bảng với chính nó. Nếu chỉ tự so, một bảng sai vẫn "pass"
/// hết — mà bảng sai thì không làm chương trình hỏng, nó làm hỏng file của người dùng.
final class LegacyEncodingTests: XCTestCase {

    private func codec(for name: String) -> SingleByteCodec {
        switch name {
        case "tcvn3": return .tcvn3
        case "viscii": return .viscii
        default: return .windows1258
        }
    }

    // MARK: - Đối chứng với iconv

    func testDecodeMatchesSystemConverter() {
        let suites: [(String, [LegacyEncodingFixtures.Sample])] = [
            ("tcvn3", LegacyEncodingFixtures.tcvn3),
            ("viscii", LegacyEncodingFixtures.viscii),
            ("windows1258", LegacyEncodingFixtures.windows1258),
        ]

        for (name, samples) in suites {
            XCTAssertFalse(samples.isEmpty, "\(name): fixture rỗng — bộ sinh bảng có vấn đề")
            for sample in samples {
                let decoded = String(decoding: codec(for: name).decode(sample.bytes), as: UTF8.self)
                XCTAssertEqual(
                    decoded, sample.text,
                    "\(name): giải mã \(sample.bytes.count) byte ra sai"
                )
            }
        }
    }

    func testEncodeMatchesSystemConverter() {
        let suites: [(String, [LegacyEncodingFixtures.Sample])] = [
            ("tcvn3", LegacyEncodingFixtures.tcvn3),
            ("viscii", LegacyEncodingFixtures.viscii),
            ("windows1258", LegacyEncodingFixtures.windows1258),
        ]

        for (name, samples) in suites {
            for sample in samples {
                let result = codec(for: name).encode(Array(sample.text.utf8))
                XCTAssertTrue(result.isLossless, "\(name): mất ký tự khi mã hóa \"\(sample.text)\"")
                XCTAssertEqual(result.bytes, sample.bytes, "\(name): mã hóa \"\(sample.text)\" ra sai")
            }
        }
    }

    // MARK: - Khứ hồi

    /// Bất biến quan trọng nhất: mở file rồi lưu lại KHÔNG được đổi một byte nào.
    func testEveryAssignedByteRoundTrips() {
        // Chỉ các bảng MỘT byte: bất biến "mỗi byte một ký tự" không áp dụng cho VNI, vốn
        // dùng hai byte cho chữ có dấu. VNI có bộ kiểm khứ hồi riêng trong VNIEncodingTests.
        for encoding in TextEncoding.allCases where encoding.isVietnameseLegacy {
            guard let codec = encoding.singleByteCodec else { continue }
            for byte in UInt8.min ... UInt8.max where codec.isAssigned(byte) {
                let decoded = codec.decode([byte])
                let encoded = codec.encode(decoded)
                XCTAssertEqual(
                    encoded.bytes, [byte],
                    "\(codec.name): byte \(String(format: "%#04x", byte)) không khứ hồi được"
                )
            }
        }
    }

    /// Khứ hồi trên văn bản thật, không chỉ trên từng byte lẻ — chỗ này bắt lỗi kết hợp
    /// và tách dấu, thứ mà byte đơn không chạm tới.
    func testRoundTripOnVietnameseSentences() {
        // Cố ý chỉ dùng ký tự nằm TRONG kho của cả ba bảng mã. Gạch ngang dài "—" không có
        // trong TCVN3 lẫn VISCII; nó được kiểm riêng ở `testDashNotInCharsetIsReported`.
        let sentences = [
            "Cộng hòa Xã hội Chủ nghĩa Việt Nam - Độc lập Tự do Hạnh phúc",
            "Đơn hàng DH-0091, Công ty Anh Đào, CN Huế",
            "ăâêôơư ĂÂÊÔƠƯ đĐ",
            "à á ả ã ạ ằ ắ ẳ ẵ ặ ầ ấ ẩ ẫ ậ",
            "ù ú ủ ũ ụ ừ ứ ử ữ ự ỳ ý ỷ ỹ ỵ",
        ]

        for encoding in TextEncoding.allCases where encoding.isVietnameseLegacy {
            guard let codec = encoding.singleByteCodec else { continue }
            for sentence in sentences {
                let encoded = codec.encode(Array(sentence.utf8))
                XCTAssertTrue(
                    encoded.isLossless,
                    "\(codec.name) không biểu diễn được \"\(sentence)\""
                )
                let decoded = String(decoding: codec.decode(encoded.bytes), as: UTF8.self)
                XCTAssertEqual(decoded, sentence, "\(codec.name) khứ hồi sai")
            }
        }
    }

    // MARK: - Kết hợp dấu

    /// TCVN3 và CP1258 viết "ế" thành chữ nền + dấu. Giải mã PHẢI kết hợp lại, nếu không
    /// người dùng gõ "ế" đi tìm sẽ không thấy dòng nào — dù trên màn hình trông giống hệt.
    func testCombiningMarksAreComposedOnDecode() throws {
        for encoding in [TextEncoding.tcvn3, .windows1258] {
            let codec = encoding.singleByteCodec!
            let encoded = codec.encode(Array("ế".utf8))
            XCTAssertTrue(encoded.isLossless)

            let decoded = String(decoding: codec.decode(encoded.bytes), as: UTF8.self)
            XCTAssertEqual(decoded, "ế")
            XCTAssertEqual(
                decoded.unicodeScalars.count, 1,
                "\(codec.name): phải ra dạng dựng sẵn, nhận \(decoded.unicodeScalars.count) điểm mã"
            )
        }
    }

    /// Dấu tổ hợp đứng một mình (không có chữ nền trước) không được nuốt mất.
    func testStandaloneCombiningMarkSurvives() {
        let codec = SingleByteCodec.tcvn3
        // 0xB3 là dấu sắc tổ hợp trong TCVN3.
        let decoded = String(decoding: codec.decode([0xB3]), as: UTF8.self)
        XCTAssertEqual(decoded.unicodeScalars.count, 1)
        XCTAssertEqual(decoded.unicodeScalars.first?.value, 0x0301)
    }

    // MARK: - Vùng điều khiển của TCVN3

    /// TCVN3 giấu 12 chữ HOA trong vùng điều khiển C0 — nhưng né đúng tab, LF, CR. Nếu nó
    /// không né thì trình soạn thảo không tách được dòng trên file TCVN3.
    func testTCVN3PutsLettersInControlRangeButSparesLineBreaks() {
        let codec = SingleByteCodec.tcvn3

        for byte: UInt8 in [0x09, 0x0A, 0x0D, 0x00] {
            XCTAssertEqual(
                codec.scalar(for: byte), UInt32(byte),
                "byte điều khiển \(String(format: "%#04x", byte)) phải giữ nguyên nghĩa"
            )
        }

        let lettersInC0 = (UInt8(0x01) ... UInt8(0x1F)).filter { byte in
            guard let scalar = codec.scalar(for: byte) else { return false }
            return scalar > 0x7F
        }
        XCTAssertEqual(lettersInC0.count, 12, "TCVN3 đặt đúng 12 chữ trong vùng C0")
    }

    /// Tách dòng phải chạy trên nội dung TCVN3 có chữ nằm trong vùng điều khiển.
    func testLineSplittingWorksOnTCVN3Content() throws {
        let text = "Ứng dụng\nỦy ban\nÝ kiến\n"
        let encoded = SingleByteCodec.tcvn3.encode(Array(text.utf8))
        XCTAssertTrue(encoded.isLossless)
        XCTAssertTrue(encoded.bytes.contains(0x0A), "phải còn byte xuống dòng")

        let utf8 = try EncodingConverter.decode(encoded.bytes, from: .tcvn3)
        let buffer = TextBuffer(original: MemoryByteSource(utf8))
        XCTAssertEqual(buffer.lineCount, 3)
        XCTAssertEqual(buffer.line(0), "Ứng dụng")
        XCTAssertEqual(buffer.line(2), "Ý kiến")
    }

    // MARK: - Mất mát khi mã hóa

    func testUnrepresentableCharactersAreCountedNotSilentlyDropped() {
        let result = SingleByteCodec.tcvn3.encode(Array("Việt 日本 語".utf8))
        XCTAssertEqual(result.unrepresentable, 3, "ba ký tự Nhật không có trong TCVN3")
        XCTAssertFalse(result.isLossless)
        XCTAssertEqual(result.firstUnrepresentable, 0x65E5, "ký tự đầu tiên mất là 日")
        XCTAssertEqual(result.bytes.filter { $0 == UInt8(ascii: "?") }.count, 3)
    }

    /// Gạch ngang dài không có trong TCVN3/VISCII. Phải BÁO mất, không được âm thầm thay
    /// bằng gạch nối — đó chính là điều `iconv` làm, và là lý do fixture phải loại mẫu đó ra.
    func testDashNotInCharsetIsReported() throws {
        for encoding in [TextEncoding.tcvn3, .viscii] {
            let result = encoding.singleByteCodec!.encode(Array("a — b".utf8))
            XCTAssertEqual(result.unrepresentable, 1, "\(encoding.displayName)")
            XCTAssertEqual(result.firstUnrepresentable, 0x2014)
        }
        // CP1258 thì CÓ gạch ngang dài, nên không được báo mất.
        let cp = SingleByteCodec.windows1258.encode(Array("a — b".utf8))
        XCTAssertTrue(cp.isLossless)
    }

    func testInvalidUTF8InputDoesNotDesynchronizeEncoder() {
        var input = Array("Việt".utf8)
        input.append(0xFF)
        input.append(contentsOf: Array("Nam".utf8))

        let result = SingleByteCodec.viscii.encode(input)
        let decoded = String(decoding: SingleByteCodec.viscii.decode(result.bytes), as: UTF8.self)
        XCTAssertTrue(decoded.hasPrefix("Việt"), "phần trước byte hỏng phải nguyên vẹn")
        XCTAssertTrue(decoded.hasSuffix("Nam"), "phần sau byte hỏng phải nguyên vẹn")
    }

    // MARK: - FR-ENC-202: nhận diện

    func testBOMDetectionIsCertain() {
        let bytes: [UInt8] = [0xEF, 0xBB, 0xBF] + Array("Việt".utf8)
        let guess = EncodingDetector.best(bytes)
        XCTAssertEqual(guess.encoding, .utf8BOM)
        XCTAssertEqual(guess.confidence, 1.0)
    }

    func testPureASCIIIsReportedAsUnambiguous() {
        let guess = EncodingDetector.best(Array("plain ascii only 123\n".utf8))
        XCTAssertEqual(guess.encoding, .utf8)
        XCTAssertEqual(guess.confidence, 1.0)
        XCTAssertTrue(guess.reason.contains("ASCII"))
    }

    func testValidUTF8VietnameseBeatsLegacyGuesses() {
        let bytes = Array("Cộng hòa Xã hội Chủ nghĩa Việt Nam".utf8)
        let guesses = EncodingDetector.detect(bytes)
        XCTAssertEqual(guesses.first?.encoding, .utf8)
        XCTAssertGreaterThan(guesses.first!.confidence, 0.9)
    }

    /// Bài kiểm tra thật của bộ nhận diện: cùng một câu, mã hóa bằng ba bảng khác nhau, mỗi
    /// lần phải đoán ra ĐÚNG bảng đã dùng.
    func testEachLegacyEncodingIsIdentified() {
        let sentence = "Cộng hòa Xã hội Chủ nghĩa Việt Nam — Độc lập Tự do Hạnh phúc. "
            + "Thừa Thiên Huế, Đà Nẵng, Quảng Ngãi, Bà Rịa Vũng Tàu."

        for encoding in TextEncoding.allCases where encoding.isVietnameseLegacy {
            // Qua EncodingConverter chứ không qua singleByteCodec: VNI dùng hai byte cho chữ
            // có dấu nên không có codec một byte, và ép kiểu ở đây từng làm test sập.
            let bytes = EncodingConverter.encode(Array(sentence.utf8), to: encoding).bytes
            let guesses = EncodingDetector.detect(bytes)
            XCTAssertEqual(
                guesses.first?.encoding, encoding,
                "đoán sai: \(guesses.prefix(3).map { "\($0.encoding.rawValue) \(Int($0.confidence * 100))%" })"
            )
            XCTAssertGreaterThan(guesses.first!.confidence, 0.5)
        }
    }

    func testDetectionReturnsRankedAlternatives() {
        let bytes = SingleByteCodec.viscii.encode(Array("Tiếng Việt có dấu".utf8)).bytes
        let guesses = EncodingDetector.detect(bytes)
        XCTAssertGreaterThan(guesses.count, 1, "phải trả nhiều lựa chọn để người dùng sửa được")
        for index in 1 ..< guesses.count {
            XCTAssertLessThanOrEqual(guesses[index].confidence, guesses[index - 1].confidence)
        }
        XCTAssertFalse(guesses[0].reason.isEmpty)
    }

    // MARK: - FR-ENC-203: diễn giải lại vs chuyển đổi

    /// Diễn giải lại: byte gốc không đổi, chữ trên màn hình đổi.
    func testReinterpretChangesTextNotBytes() throws {
        let original = SingleByteCodec.tcvn3.encode(Array("Tiếng Việt".utf8)).bytes

        // Mở nhầm bằng VISCII → ra chữ vô nghĩa.
        let wrong = try EncodingChange.reinterpret(originalBytes: original, as: .viscii)
        XCTAssertNotEqual(String(decoding: wrong.utf8, as: UTF8.self), "Tiếng Việt")

        // Diễn giải lại bằng TCVN3 trên CHÍNH byte gốc → đúng chữ.
        let right = try EncodingChange.reinterpret(originalBytes: original, as: .tcvn3)
        XCTAssertEqual(String(decoding: right.utf8, as: UTF8.self), "Tiếng Việt")
    }

    /// Chuyển đổi: chữ không đổi, byte đổi.
    func testConvertChangesBytesNotText() {
        let utf8 = Array("Tiếng Việt".utf8)
        let preview = EncodingChange.convert(utf8: utf8, to: .viscii)

        XCTAssertNotEqual(preview.bytes, utf8, "byte phải đổi")
        XCTAssertFalse(preview.isLossy)
        XCTAssertNil(preview.warning)

        let back = SingleByteCodec.viscii.decode(preview.bytes)
        XCTAssertEqual(String(decoding: back, as: UTF8.self), "Tiếng Việt", "chữ phải giữ nguyên")
    }

    /// Chuyển đổi có mất dữ liệu phải cảnh báo TRƯỚC khi ghi, kèm ví dụ ký tự sẽ mất.
    func testLossyConversionWarnsBeforeWriting() throws {
        let preview = EncodingChange.convert(utf8: Array("Việt 日本".utf8), to: .tcvn3)
        XCTAssertTrue(preview.isLossy)
        let warning = try XCTUnwrap(preview.warning)
        XCTAssertTrue(warning.contains("2 ký tự"), warning)
        XCTAssertTrue(warning.contains("日"), "cảnh báo phải nêu ví dụ cụ thể: \(warning)")
        XCTAssertTrue(warning.contains("KHÔNG hoàn tác"), warning)
    }

    func testConvertToUTF8IsNeverLossy() {
        for encoding in TextEncoding.allCases where encoding.isVietnameseLegacy {
            let utf8 = Array("Tiếng Việt 日本 🇻🇳".utf8)
            _ = encoding
            let preview = EncodingChange.convert(utf8: utf8, to: .utf8)
            XCTAssertFalse(preview.isLossy)
            XCTAssertEqual(preview.bytes, utf8)
        }
    }

    func testBOMIsWrittenAndStripped() throws {
        let utf8 = Array("Việt".utf8)
        let preview = EncodingChange.convert(utf8: utf8, to: .utf8BOM)
        XCTAssertEqual(Array(preview.bytes.prefix(3)), [0xEF, 0xBB, 0xBF])

        let decoded = try EncodingConverter.decode(preview.bytes, from: .utf8BOM)
        XCTAssertEqual(decoded, utf8, "BOM phải bị cắt khi đọc lại")
    }
}
