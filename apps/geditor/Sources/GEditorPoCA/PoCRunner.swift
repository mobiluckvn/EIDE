import AppKit
import QuartzCore

/// Ép mọi thứ đang chờ vẽ phải vẽ XONG, ngay bây giờ.
///
/// `NSView.display()` là đủ cho view vẽ trực tiếp, nhưng KHÔNG đủ cho view có layer: ở đó nó
/// chỉ đánh dấu layer cần vẽ, còn nét vẽ thật xảy ra khi CoreAnimation commit. Scintilla rơi
/// vào trường hợp thứ hai — bản đo đầu tiên của tôi ghi 0,03 ms mỗi phím và SCN_PAINTED đếm
/// được 0 lần vẽ, tức là đo đúng chi phí của việc KHÔNG vẽ gì.
///
/// Gọi ở một chỗ dùng chung, không đặt trong từng adapter: hai engine phải chịu đúng một cách
/// ép vẽ, nếu không thì hai con số không so được với nhau.
@inline(never)
func flushPendingDrawing() {
    CATransaction.begin()
    CATransaction.flush()
    CATransaction.commit()
}

/// Chạy các phép đo của PoC-A và trả về kết quả dạng chữ (ADR-01).
///
/// Bốn câu hỏi SAD §8 đặt ra cho PoC-A:
///   1. latency gõ p95 trên file 500 MB
///   2. marked-text với Telex (EVKey) — cần NGƯỜI gõ, xem `IMELogView`
///   3. multi-caret 1.000 caret
///   4. column mode 10.000 dòng
///
/// Câu 1 chạy theo CỠ TĂNG DẦN chứ không nhảy thẳng vào 500 MB. Một engine treo ở 500 MB chỉ
/// cho ta biết "treo", còn đường cong theo cỡ cho biết nó gãy ở đâu và gãy kiểu gì — thứ mà
/// ADR cần để lập luận, không phải chỉ để loại.
struct PoCRunner {

    /// Ngân sách cho MỘT lần nạp. Vượt thì bỏ các cỡ lớn hơn.
    ///
    /// 120 giây không phải con số đẹp mà là ngưỡng đã quá xa yêu cầu: NFR-PERF-01 đòi mở 1 GB
    /// dưới 5 giây. Một engine cần hơn hai phút cho 500 MB đã trả lời xong câu hỏi rồi.
    static let loadBudgetSeconds = 120.0

    struct Result {
        var engine: String
        var sizeBytes: Int
        var lines: Int
        var loadSeconds: Double
        var footprintAfterLoad: Int
        var typing: LatencySampler?
        var typingNote: String?
        var paintsWhileTyping = 0
        var typedUnits = 0
        var expectedUnits = 0
        var caretAtStart = 0
        var multiCaret: String
        var columnMode: String
        var scrollSeconds: Double?
        var extraNote: String?
        var viewport = ""
    }

    /// Sinh nội dung thử: dòng tiếng Việt CÓ DẤU, độ dài không đều.
    ///
    /// Không dùng chữ ASCII lặp lại: engine hiển thị nào cũng có đường nhanh cho văn bản một
    /// byte một ký tự, và GEditor sinh ra để dùng với tiếng Việt. Đo bằng ASCII là đo một
    /// trường hợp mà người dùng của sản phẩm này không gặp.
    static func makeCorpus(bytes target: Int, ascii: Bool = false) -> [UInt8] {
        let patterns = ascii ? [
            // CHỈ để chẩn đoán: ở ASCII thì offset byte và offset UTF-16 bằng nhau, nên chạy
            // được với ASCII mà hỏng với tiếng Việt là chỉ thẳng vào chỗ lệch đơn vị.
            "Nguyen Thi Hong Nhung, Quan Tan Binh, don hang so ",
            "Tran Van Duc - cong no ky truoc, ma khach hang ",
            "Le Hoang Phuong Uyen; ghi chu: giao trong ngay, so ",
        ] : [
            "Nguyễn Thị Hồng Nhung, Quận Tân Bình, đơn hàng số ",
            "Trần Văn Đức — công nợ kỳ trước, mã khách hàng ",
            "Lê Hoàng Phương Uyên; ghi chú: giao trong ngày, số ",
        ]
        var out: [UInt8] = []
        out.reserveCapacity(target + 128)
        var counter = 0
        while out.count < target {
            let line = patterns[counter % patterns.count] + String(counter) + "\n"
            out.append(contentsOf: line.utf8)
            counter += 1
        }
        return out
    }

    /// Đo một engine ở một cỡ.
    static func run(engine: DisplayEngine, corpus: [UInt8], typingSamples: Int) -> Result {
        var result = Result(
            engine: engine.name, sizeBytes: corpus.count, lines: 0,
            loadSeconds: 0, footprintAfterLoad: 0,
            typing: nil, typingNote: nil,
            multiCaret: "chưa chạy", columnMode: "chưa chạy", scrollSeconds: nil
        )

        let before = MemoryProbe.footprintBytes()
        let loadStart = DispatchTime.now().uptimeNanoseconds
        do {
            try engine.load(corpus)
        } catch {
            result.typingNote = "nạp thất bại: \(error)"
            return result
        }
        engine.forceDisplay()
        flushPendingDrawing()
        result.loadSeconds = Double(DispatchTime.now().uptimeNanoseconds - loadStart) / 1_000_000_000
        result.footprintAfterLoad = MemoryProbe.footprintBytes() - before
        result.lines = engine.lineCount

        result.viewport = engine.viewportDescription
        if let textKit = engine as? TextKit2Engine {
            result.extraNote = "bảng chỉ số dòng: \(MemoryProbe.format(textKit.lineIndexBytes))"
        }

        // Gõ ở GIỮA tài liệu, không phải đầu. Chèn ở offset 0 là trường hợp dễ nhất cho mọi
        // cấu trúc dữ liệu, và cũng là trường hợp người dùng ít làm nhất trên file lớn.
        var typing = LatencySampler()
        engine.beginTyping(atLine: engine.lineCount / 2)
        _ = engine.takePaintCount()   // bỏ số vẽ của lần nạp
        result.caretAtStart = engine.caretPosition
        let lengthBefore = engine.nativeLength
        var expected = 0
        let keystrokes = Array("Việt Nam xin chào ")
        for index in 0 ..< typingSamples {
            let character = String(keystrokes[index % keystrokes.count])
            // Đơn vị của engine: Scintilla đếm byte, TextKit đếm UTF-16. Chữ "ệ" là 3 byte
            // nhưng 1 đơn vị UTF-16 — so nhầm đơn vị thì phép kiểm sẽ báo động giả.
            expected += engine.countsBytes ? character.utf8.count : character.utf16.count
            typing.measure {
                engine.typeOneCharacter(character)
                engine.forceDisplay()
                flushPendingDrawing()
            }
        }
        result.typing = typing
        result.paintsWhileTyping = engine.takePaintCount()
        result.typedUnits = engine.nativeLength - lengthBefore
        result.expectedUnits = expected

        // 1.000 caret (FR-CORE-001).
        let step = Swift.max(1, engine.lineCount / 1_000)
        let carets = (0 ..< 1_000).map { $0 * step }.filter { $0 < engine.lineCount }
        let caretStart = DispatchTime.now().uptimeNanoseconds
        if engine.setCarets(carets.map { $0 * 40 }) {
            engine.forceDisplay()
            flushPendingDrawing()
            let ms = Double(DispatchTime.now().uptimeNanoseconds - caretStart) / 1_000_000
            result.multiCaret = String(format: "%d caret trong %.1f ms", carets.count, ms)
        } else {
            result.multiCaret = "KHÔNG hỗ trợ"
        }

        // Column mode 10.000 dòng.
        let columnStart = DispatchTime.now().uptimeNanoseconds
        let toLine = Swift.min(10_000, engine.lineCount - 1)
        if engine.selectRectangle(fromLine: 0, toLine: toLine, column: 5) {
            engine.forceDisplay()
            flushPendingDrawing()
            let ms = Double(DispatchTime.now().uptimeNanoseconds - columnStart) / 1_000_000
            result.columnMode = String(format: "%d dòng trong %.1f ms", toLine, ms)
        } else {
            result.columnMode = "KHÔNG hỗ trợ"
        }

        // Nhảy tới cuối file: đo cảm giác "kéo thanh cuộn xuống đáy".
        let scrollStart = DispatchTime.now().uptimeNanoseconds
        engine.scrollToLine(engine.lineCount - 1)
        engine.forceDisplay()
        flushPendingDrawing()
        result.scrollSeconds = Double(DispatchTime.now().uptimeNanoseconds - scrollStart) / 1_000_000_000

        return result
    }
}

extension PoCRunner.Result {

    var report: String {
        var lines = [
            "── \(engine) · \(MemoryProbe.format(sizeBytes)) ──",
            String(format: "  nạp            %.3f s   (%d dòng)", loadSeconds, self.lines),
            "  phys_footprint \(MemoryProbe.format(footprintAfterLoad))",
            "  khung nhìn     \(viewport)",
        ]
        if let extraNote { lines.append("  \(extraNote)") }
        if let typing {
            lines.append("  gõ             \(typing.summary)")
            lines.append("  số lần vẽ      \(paintsWhileTyping) / \(typing.count) phím")
            lines.append("  caret bắt đầu  \(caretAtStart)")
            lines.append("  nội dung tăng  \(typedUnits) / \(expectedUnits) đơn vị")
            if paintsWhileTyping == 0 {
                lines.append("  ⚠️  KHÔNG vẽ lần nào — số đo gõ ở trên KHÔNG dùng được")
            }
            if typedUnits != expectedUnits {
                lines.append("  ⚠️  nội dung KHÔNG tăng đúng — lần gõ bị nuốt, số đo vô nghĩa")
            }
        }
        if let typingNote { lines.append("  ⚠️  \(typingNote)") }
        lines.append("  multi-caret    \(multiCaret)")
        lines.append("  column mode    \(columnMode)")
        if let scrollSeconds {
            lines.append(String(format: "  nhảy cuối file %.3f s", scrollSeconds))
        }
        return lines.joined(separator: "\n")
    }
}
