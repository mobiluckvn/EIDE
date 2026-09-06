import Foundation

/// Nhận diện bảng mã kèm ĐỘ TIN CẬY (FR-ENC-202).
///
/// Trả về danh sách xếp hạng chứ không phải một đáp án. Lý do: đoán bảng mã một byte là bài
/// toán không có lời giải chắc chắn — cùng một dãy byte hợp lệ trong cả TCVN3 lẫn VISCII, chỉ
/// khác ở chỗ đọc ra chữ nào có nghĩa. Trả một đáp án duy nhất là giả vờ chắc chắn, và người
/// dùng sẽ không có cách nào sửa khi ta đoán sai. Banner "Phát hiện Windows-1258 (62%)" của
/// UI/UX §4.2 cần đúng con số này, cùng với danh sách để họ chọn lại.
public enum EncodingDetector {

    public struct Guess: Equatable {
        public let encoding: TextEncoding
        /// 0…1. Không phải xác suất theo nghĩa thống kê — là điểm đã chuẩn hóa để so sánh
        /// giữa các ứng viên và để hiện cho người dùng.
        public let confidence: Double
        /// Vì sao — hiện trong tooltip, và là thứ giúp gỡ lỗi khi nhận diện sai.
        public let reason: String
    }

    /// Số byte đầu file dùng để đoán.
    ///
    /// Đủ để thống kê ổn định mà không phải chạm cả file 1 GB chỉ để mở nó. Văn bản thật có
    /// đặc trưng bảng mã ngay từ đoạn đầu; nếu 256 KB đầu toàn ASCII thì phần sau hầu như
    /// chắc chắn cũng vậy.
    public static let sampleBytes = 256 * 1024

    /// Kho ký tự "đặc trưng tiếng Việt", suy từ chính bảng mã đã sinh.
    ///
    /// Không gõ tay danh sách chữ: VISCII phủ đúng kho chữ Việt, nên mọi điểm mã ngoài ASCII
    /// trong bảng VISCII chính là định nghĩa cần dùng. Bảng đổi thì định nghĩa tự đổi theo.
    private static let vietnameseScalars: Set<UInt32> = {
        var scalars = Set<UInt32>()
        for byte in 0x80 ... 0xFF {
            let scalar = LegacyEncodingTables.viscii[byte]
            if scalar != LegacyEncodingTables.unassigned { scalars.insert(scalar) }
        }
        for byte in 0x00 ... 0xFF {
            let scalar = LegacyEncodingTables.tcvn3[byte]
            if scalar != LegacyEncodingTables.unassigned, scalar > 0x7F { scalars.insert(scalar) }
        }
        return scalars
    }()

    /// Cắt bỏ chuỗi UTF-8 dở dang ở CUỐI mẫu.
    ///
    /// Không có bước này thì mọi file UTF-8 lớn hơn `sampleBytes` mà chỗ cắt rơi vào giữa một
    /// ký tự nhiều byte sẽ bị coi là KHÔNG hợp lệ UTF-8, và bộ dò đẩy nó sang bảng mã một byte.
    /// Với tiếng Việt thì đó không phải trường hợp hiếm mà là mặc định: gần như mọi dòng đều
    /// có ký tự nhiều byte, nên xác suất chỗ cắt rơi trúng là ~2/3.
    ///
    /// Hậu quả nếu để nguyên là mất dữ liệu, không phải hiển thị xấu: `Document.open` sẽ giải
    /// mã CẢ FILE bằng bảng mã đoán sai, và lưu lại là hỏng thật. Đã gặp: file 1 MB tiếng Việt
    /// UTF-8 bị nhận là VISCII 65% trong khi UTF-8 không lọt nổi top 3.
    ///
    /// Chỉ bỏ TỐI ĐA 3 byte, và chỉ khi chúng đúng là một chuỗi dở dang — không đụng tới dữ
    /// liệu legacy, nơi mấy byte cuối cũng chỉ là mấy byte như mọi byte khác.
    static func trimmedToUTF8Boundary(_ sample: [UInt8]) -> [UInt8] {
        guard !sample.isEmpty else { return sample }
        var index = sample.count - 1
        let lowest = Swift.max(0, sample.count - 3)
        while index >= lowest {
            let byte = sample[index]
            if byte < 0x80 { return sample }                    // ASCII: mẫu kết thúc gọn
            if byte >= 0xC0 {                                    // byte dẫn đầu
                let needed = byte >= 0xF0 ? 4 : (byte >= 0xE0 ? 3 : 2)
                let available = sample.count - index
                return available >= needed ? sample : Array(sample[..<index])
            }
            index -= 1                                           // byte tiếp nối
        }
        return sample
    }

    /// Xếp hạng ứng viên bảng mã cho `bytes`.
    public static func detect(_ bytes: [UInt8]) -> [Guess] {
        let sample = trimmedToUTF8Boundary(Array(bytes.prefix(sampleBytes)))

        // 1. BOM là bằng chứng dứt khoát — không có gì để đoán.
        if let bom = EncodingEngine.detectBOM(sample), let encoding = encodingForBOM(bom) {
            return [Guess(encoding: encoding, confidence: 1.0, reason: "Có BOM \(bom.name)")]
        }

        // 2. Toàn ASCII: mọi bảng mã ở đây đều đọc giống nhau, nên chọn UTF-8 và nói rõ vì sao.
        if !sample.contains(where: { $0 >= 0x80 || ($0 < 0x20 && !isTextControl($0)) }) {
            return [Guess(
                encoding: .utf8, confidence: 1.0,
                reason: "Chỉ có ký tự ASCII — mọi bảng mã hỗ trợ đều đọc giống nhau"
            )]
        }

        var guesses: [Guess] = []

        // 3. UTF-8 hợp lệ với ký tự nhiều byte là bằng chứng rất mạnh: xác suất một file
        //    legacy tình cờ hợp lệ UTF-8 trên hàng nghìn byte là cực thấp.
        if ByteScan.isValidUTF8(sample) {
            guesses.append(Guess(
                encoding: .utf8, confidence: 0.99,
                reason: "Chuỗi byte hợp lệ theo UTF-8 nhiều byte"
            ))
        }

        // 4. Chấm điểm từng bảng mã legacy.
        for encoding in TextEncoding.allCases where encoding.isVietnameseLegacy {
            let score: Score
            if let codec = encoding.singleByteCodec {
                score = self.score(sample, with: codec)
            } else if encoding == .vni {
                score = scoreVNI(sample)
            } else {
                continue
            }
            guesses.append(Guess(
                encoding: encoding,
                confidence: score.confidence,
                reason: score.reason
            ))
        }

        return guesses.sorted { $0.confidence > $1.confidence }
    }

    /// Đáp án tốt nhất, hoặc UTF-8 khi không có gì để dựa vào.
    public static func best(_ bytes: [UInt8]) -> Guess {
        detect(bytes).first ?? Guess(encoding: .utf8, confidence: 0, reason: "Không có căn cứ")
    }

    // MARK: - Chấm điểm

    private struct Score {
        let confidence: Double
        let reason: String
    }

    /// Bốn tín hiệu thô mà công thức chấm điểm cần.
    private struct Signals {
        var assigned = 0
        var nonASCII = 0
        var vietnamese = 0
        var strayControls = 0
    }

    private static func score(_ bytes: [UInt8], with codec: SingleByteCodec) -> Score {
        var signals = Signals()
        for byte in bytes {
            guard let scalar = codec.scalar(for: byte) else { continue }
            signals.assigned += 1
            if byte < 0x80, scalar == UInt32(byte) {
                // ASCII thuần: không phân biệt được bảng mã nào, bỏ qua khi chấm điểm.
                if scalar < 0x20, !isTextControl(byte) { signals.strayControls += 1 }
                continue
            }
            signals.nonASCII += 1
            if vietnameseScalars.contains(scalar) { signals.vietnamese += 1 }
            if scalar < 0x20, !isTextControl(UInt8(scalar)) { signals.strayControls += 1 }
        }
        return finish(signals, byteCount: bytes.count,
                      orthography: codec.decodeScalars(bytes, limit: sampleBytes))
    }

    /// VNI dùng HAI byte cho chữ có dấu, nên không tra được theo từng byte như ba bảng kia.
    ///
    /// Chấm bằng đúng công thức và đúng bộ tách byte của bộ giải mã VNI — nếu chấm bằng một
    /// bản sao khác của quy tắc tách thì nhận diện sẽ nói một đằng còn mở file ra một nẻo.
    private static func scoreVNI(_ bytes: [UInt8]) -> Score {
        var signals = Signals()
        VNICodec.scan(bytes) { scalar, consumed in
            guard let scalar else { return }
            signals.assigned += consumed
            // Một byte ăn vào mà ra chữ có dấu thì đó là bằng chứng VNI: đúng thứ phân biệt
            // nó với ba bảng mã một byte.
            if consumed == 1, scalar < 0x80 {
                if scalar < 0x20, !isTextControl(UInt8(scalar)) { signals.strayControls += 1 }
                return
            }
            signals.nonASCII += 1
            if vietnameseScalars.contains(scalar) { signals.vietnamese += 1 }
        }
        return finish(signals, byteCount: bytes.count,
                      orthography: VNICodec.decodeScalars(bytes, limit: sampleBytes))
    }

    private static func finish(
        _ signals: Signals, byteCount: Int, orthography: [UInt32]
    ) -> Score {
        let assigned = signals.assigned
        let nonASCII = signals.nonASCII
        let vietnamese = signals.vietnamese
        let strayControls = signals.strayControls
        let total = Double(byteCount)
        let assignedRatio = total > 0 ? Double(assigned) / total : 0
        // Tín hiệu 1 — trong các byte KHÔNG phải ASCII, bao nhiêu phần đọc ra chữ Việt? Bảng
        // mã sai sẽ cho ra ký hiệu tiền tệ, phân số, chữ Bắc Âu: hợp lệ về mặt bảng nhưng vô
        // nghĩa trong một văn bản tiếng Việt. Tín hiệu này tách CP1258 khỏi hai bảng kia.
        let vietnameseRatio = nonASCII > 0 ? Double(vietnamese) / Double(nonASCII) : 0
        // Ký tự điều khiển lạc trong văn bản gần như luôn nghĩa là đọc sai bảng mã.
        let controlPenalty = total > 0 ? Double(strayControls) / total * 4 : 0

        // Tín hiệu 2 — chính tả. TCVN3 và VISCII không tách nhau được bằng thống kê byte
        // (cả hai đều cho 100% chữ Việt trên dòng byte của nhau); chỉ có cấu trúc từ mới
        // tách được. Xem `VietnameseOrthography`.
        let assessment = VietnameseOrthography.assess(orthography)
        let plausibility = assessment.words > 0 ? assessment.plausibility : 1

        let raw = assignedRatio * 0.15 + vietnameseRatio * 0.50 + plausibility * 0.35 - controlPenalty
        let confidence = min(max(raw, 0), 0.98)

        var reason = "\(Int((vietnameseRatio * 100).rounded()))% byte ngoài ASCII đọc ra chữ tiếng Việt"
        if assessment.violations > 0 {
            reason += " · \(assessment.violations) lỗi chính tả trên \(assessment.words) từ"
        }
        if strayControls > 0 {
            reason += " · \(strayControls) ký tự điều khiển lạc"
        }
        return Score(confidence: confidence, reason: reason)
    }

    /// Ký tự điều khiển hợp lệ trong văn bản.
    private static func isTextControl(_ byte: UInt8) -> Bool {
        byte == 0x09 || byte == 0x0A || byte == 0x0D
    }

    private static func encodingForBOM(_ bom: EncodingEngine.BOM) -> TextEncoding? {
        switch bom.name {
        case "UTF-8 BOM": return .utf8BOM
        case "UTF-16 LE": return .utf16LE
        case "UTF-16 BE": return .utf16BE
        case "UTF-32 LE": return .utf32LE
        case "UTF-32 BE": return .utf32BE
        default: return nil
        }
    }
}
