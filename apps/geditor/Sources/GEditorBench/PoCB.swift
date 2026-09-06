import Foundation
import GEditorCore

/// PoC-B (SAD §8, ADR-02): piece table trên mmap với file 1 GB.
///
/// Câu hỏi PoC phải trả lời, theo đúng thứ tự README "BẮT ĐẦU CODE TỪ ĐÂU":
///   1. Mở file 1 GB mất bao lâu tới lúc trả lời được truy vấn dòng?
///   2. Tốn bao nhiêu RAM — phân biệt trang mmap sạch với RAM thật sự chiếm giữ?
///   3. Sửa 10 000 vị trí mất bao lâu, và mỗi phím gõ lẻ mất bao lâu (p95)?
///   4. Phân mảnh tới đâu thì gãy, và bản mảng phẳng gãy ở kích thước nào?
struct PoCBReport: Encodable {
    struct Fixture: Encodable {
        let path: String
        let megabytes: Double
        let lineCount: Int
    }

    struct Open: Encodable {
        /// mmap thuần: chỉ tạo ánh xạ, chưa chạm trang nào.
        let mmapMs: Double
        /// Dựng chỉ mục newline theo khối — chỗ duy nhất quét toàn file.
        let newlineIndexMs: Double
        /// Truy vấn dòng ĐẦU TIÊN sau khi mở (không được phép có công việc hoãn lại giấu ở đây).
        let firstLineQueryMs: Double
        let totalMs: Double
        let throughputMBps: Double
    }

    struct Memory: Encodable {
        let baselineFootprintMB: Double
        let afterOpenResidentMB: Double
        let afterOpenFootprintMB: Double
        let afterEditsFootprintMB: Double
        /// Bảng mốc của NewlineBlockIndex — cấu trúc duy nhất tỉ lệ với kích thước file.
        let newlineIndexKB: Double
        let addBufferKB: Double
    }

    struct InteractiveEdits: Encodable {
        let edits: Int
        /// Mỗi mẫu = một lần gõ: applyEdits(1 sửa) + đọc lại số dòng, như status bar vẫn làm.
        let p50Us: Double
        let p95Us: Double
        let p99Us: Double
        let maxUs: Double
        let totalMs: Double
    }

    struct BatchEdit: Encodable {
        let edits: Int
        let applyMs: Double
        let undoMs: Double
        let redoMs: Double
        let pieceCountAfter: Int
        let treeDepthAfter: Int
    }

    struct LineQuery: Encodable {
        let samples: Int
        let pieceCount: Int
        let offsetToLineP95Us: Double
        let lineToOffsetP95Us: Double
    }

    struct ScalePoint: Encodable {
        let megabytes: Int
        let edits: Int
        let pieceTreeMs: Double
        let flatArrayMs: Double
        let speedup: Double
    }

    let poc = "PoC-B"
    let adr = "ADR-02"
    let architecture: String
    let simdBackend: String
    let version: String
    let fixture: Fixture
    let open: Open
    let memory: Memory
    let interactiveEdits: InteractiveEdits
    let batchEdit: BatchEdit
    let lineQuery: LineQuery
    let scaling: [ScalePoint]
    let notes: [String]
}

enum PoCB {

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("  \(message)\n".utf8))
    }

    static func run(
        megabytes: Int,
        interactiveEdits: Int,
        batchEdits: Int,
        scaleSizes: [Int],
        scaleEdits: Int
    ) throws -> PoCBReport {

        let baseline = ProcessMemory.snapshot()

        log("sinh/kiểm tra fixture \(megabytes) MB…")
        let path = try Fixture.path(megabytes: megabytes)

        // --- 1. Mở file ---------------------------------------------------------------

        log("mở file qua mmap + dựng chỉ mục…")
        var mapped: MappedFile!
        let mmapMs = Measure.milliseconds { mapped = try? MappedFile(path: path) }
        guard let mapped else {
            throw NSError(domain: "GEditorBench", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "không mmap được \(path)"])
        }

        var buffer: TextBuffer!
        let indexMs = Measure.milliseconds { buffer = TextBuffer(original: mapped) }
        var lineCount = 0
        let firstQueryMs = Measure.milliseconds { lineCount = buffer.lineCount }

        let afterOpen = ProcessMemory.snapshot()
        let fileMB = Double(mapped.count) / 1_048_576
        let openTotalMs = mmapMs + indexMs + firstQueryMs
        log(String(format: "mở xong: %.0f MB · %d dòng · %.1f ms", fileMB, lineCount, openTotalMs))

        // --- 2. Gõ phím lẻ ------------------------------------------------------------

        log("\(interactiveEdits) lần sửa lẻ (mô phỏng gõ phím)…")
        var rng = DeterministicRNG(seed: 20260819)
        var samples: [Double] = []
        samples.reserveCapacity(interactiveEdits)

        let interactiveTotalMs = Measure.milliseconds {
            for _ in 0 ..< interactiveEdits {
                let offset = rng.int(buffer.count + 1)
                samples.append(Measure.milliseconds {
                    buffer.applyEdits([TextEdit.insert(at: offset, text: "ă")], label: "Gõ")
                    // Status bar đọc lại vị trí con trỏ sau MỖI phím — chi phí này thuộc về
                    // đường gõ, không được tách ra khỏi phép đo (FR-CORE-018, UI/UX §3).
                    _ = buffer.lineCount
                    _ = buffer.lineNumber(atOffset: offset)
                })
            }
        }

        let afterEdits = ProcessMemory.snapshot()
        log(String(
            format: "gõ xong: p50 %.0f µs · p95 %.0f µs · max %.0f µs · %d piece",
            Measure.percentile(samples, 0.50) * 1000,
            Measure.percentile(samples, 0.95) * 1000,
            (samples.max() ?? 0) * 1000,
            buffer.pieceCount
        ))

        // --- 3. Truy vấn dòng trên tài liệu đã phân mảnh -------------------------------

        let querySamples = 5_000
        var offsetToLine: [Double] = []
        var lineToOffset: [Double] = []
        offsetToLine.reserveCapacity(querySamples)
        lineToOffset.reserveCapacity(querySamples)
        for _ in 0 ..< querySamples {
            let offset = rng.int(buffer.count)
            offsetToLine.append(Measure.milliseconds { _ = buffer.lineNumber(atOffset: offset) })
            let line = rng.int(buffer.lineCount)
            lineToOffset.append(Measure.milliseconds { _ = buffer.offset(ofLineStart: line) })
        }

        let fragmentedPieceCount = buffer.pieceCount
        let addBufferKB = Double(buffer.addBufferByteCount) / 1024
        // Chỉ mục newline = một Int cho mỗi khối 64 KB của file gốc.
        let newlineIndexKB = Double(
            (mapped.count / NewlineBlockIndex.blockSize + 1) * MemoryLayout<Int>.stride
        ) / 1024

        buffer = nil

        // --- 4. Một nhóm 10 000 sửa = một bước undo (FR-CORE-004) ----------------------

        log("\(batchEdits) sửa trong MỘT nhóm undo…")
        let batchBuffer = TextBuffer(original: try MappedFile(path: path))
        let stride = max(2, batchBuffer.count / (batchEdits + 1))
        let edits = (0 ..< batchEdits).map { i in
            TextEdit(range: (i * stride) ..< (i * stride + 2), text: "XX")
        }
        let applyMs = Measure.milliseconds { batchBuffer.applyEdits(edits, label: "Benchmark") }
        let undoMs = Measure.milliseconds { _ = batchBuffer.undo() }
        let redoMs = Measure.milliseconds { _ = batchBuffer.redo() }
        let batchPieces = batchBuffer.pieceCount
        let batchDepth = batchBuffer.treeDepth

        // --- 5. Điểm gãy của mảng piece phẳng -----------------------------------------

        log("quét điểm gãy: cây piece vs mảng phẳng…")
        var scaling: [PoCBReport.ScalePoint] = []
        for size in scaleSizes {
            let bytes = Fixture.inMemory(megabytes: size)
            let treeMs = measureInteractive(edits: scaleEdits, bytes: bytes)
            let flatMs = measureLegacyInteractive(edits: scaleEdits, bytes: bytes)
            scaling.append(PoCBReport.ScalePoint(
                megabytes: size,
                edits: scaleEdits,
                pieceTreeMs: treeMs,
                flatArrayMs: flatMs,
                speedup: treeMs > 0 ? flatMs / treeMs : 0
            ))
            log(String(format: "  %4d MB: cây %.1f ms · mảng phẳng %.1f ms (×%.0f)",
                       size, treeMs, flatMs, flatMs / max(treeMs, 0.0001)))
        }

        return PoCBReport(
            architecture: GEditorCore.architecture,
            simdBackend: GEditorCore.simdBackend,
            version: GEditorCore.version,
            fixture: .init(path: path, megabytes: fileMB, lineCount: lineCount),
            open: .init(
                mmapMs: mmapMs,
                newlineIndexMs: indexMs,
                firstLineQueryMs: firstQueryMs,
                totalMs: openTotalMs,
                throughputMBps: fileMB / (openTotalMs / 1000)
            ),
            memory: .init(
                baselineFootprintMB: baseline.footprintMB,
                afterOpenResidentMB: afterOpen.residentMB,
                afterOpenFootprintMB: afterOpen.footprintMB,
                afterEditsFootprintMB: afterEdits.footprintMB,
                newlineIndexKB: newlineIndexKB,
                addBufferKB: addBufferKB
            ),
            interactiveEdits: .init(
                edits: interactiveEdits,
                p50Us: Measure.percentile(samples, 0.50) * 1000,
                p95Us: Measure.percentile(samples, 0.95) * 1000,
                p99Us: Measure.percentile(samples, 0.99) * 1000,
                maxUs: (samples.max() ?? 0) * 1000,
                totalMs: interactiveTotalMs
            ),
            batchEdit: .init(
                edits: batchEdits,
                applyMs: applyMs,
                undoMs: undoMs,
                redoMs: redoMs,
                pieceCountAfter: batchPieces,
                treeDepthAfter: batchDepth
            ),
            lineQuery: .init(
                samples: querySamples,
                pieceCount: fragmentedPieceCount,
                offsetToLineP95Us: Measure.percentile(offsetToLine, 0.95) * 1000,
                lineToOffsetP95Us: Measure.percentile(lineToOffset, 0.95) * 1000
            ),
            scaling: scaling,
            notes: [
                "afterOpenResidentMB gồm trang mmap SẠCH do quét chỉ mục chạm vào; kernel thu hồi được. Con số ràng buộc NFR-PERF-05 là footprint.",
                "Fixture sinh ngoài repo tại GEDITOR_FIXTURE_DIR (mặc định thư mục tạm).",
                "scaling đo trên nguồn trong RAM để loại nhiễu I/O; chỉ so cấu trúc dữ liệu.",
            ]
        )
    }

    /// Đường gõ phím của bản PoC-B: cây piece + truy vấn dòng O(log n).
    private static func measureInteractive(edits: Int, bytes: [UInt8]) -> Double {
        let buffer = TextBuffer(original: MemoryByteSource(bytes))
        var rng = DeterministicRNG(seed: 12345)
        return Measure.milliseconds {
            for _ in 0 ..< edits {
                let offset = rng.int(buffer.count + 1)
                buffer.applyEdits([TextEdit.insert(at: offset, text: "x")], label: "Gõ")
                _ = buffer.lineCount
            }
        }
    }

    /// Đường gõ phím của bản trước PoC-B: mảng phẳng + quét lại toàn tài liệu mỗi lần.
    private static func measureLegacyInteractive(edits: Int, bytes: [UInt8]) -> Double {
        let table = LegacyPieceTable(original: MemoryByteSource(bytes))
        var rng = DeterministicRNG(seed: 12345)
        return Measure.milliseconds {
            for _ in 0 ..< edits {
                let offset = rng.int(table.count + 1)
                table.replace(offset ..< offset, with: [UInt8(ascii: "x")])
                _ = table.rebuiltLineCount()
            }
        }
    }
}
