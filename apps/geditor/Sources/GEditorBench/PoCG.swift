import Foundation
import GEditorCore

/// PoC-G — tập con SQL chạy thẳng trên `CSVEngine` (FR-CSV-407).
///
/// **Vì sao có PoC này.** SAD chốt DuckDB làm engine SQL. Hai lần sửa sau đó bỏ ngỏ mục này:
/// App Store cấm tải mã lúc chạy nên nửa "optional component tải khi bật" không dùng được, rồi
/// commit `41aee01` chỉ ra lập luận "40 MB cộng thẳng vào thời gian khởi động" là sai — nó gộp
/// *nằm trong bundle* với *nằm trong binary chính* với *nằm trên đường khởi động*. Nên cả lý
/// do chọn DuckDB lẫn lý do bỏ nó đều không còn đứng, và giá thật của DuckDB là ~40 MB tải về
/// cho mọi người dùng, kể cả người không bao giờ chạy SQL.
///
/// Phương án thay thế: tự viết một tập con SQL trên `CSVEngine`. PoC này đo xem nó có sống nổi
/// ở cỡ dữ liệu thật không.
///
/// **Điều PoC này CỐ Ý KHÔNG đo: bộ phân tích cú pháp SQL.** Viết parser cho
/// `SELECT … WHERE … GROUP BY … ORDER BY` là việc đã biết cách làm và đã làm một lần trong dự
/// án này (JSONPath, FR-FMT-504). Thứ chưa ai biết — và thứ có thể giết cả phương án — là chi
/// phí THỰC THI: mọi câu có `GROUP BY` đều buộc quét hết bảng, và NFR-QRY-01 đã đo sàn phân
/// tích CSV ~0,8 giây trên 1 triệu hàng. Nếu một phép gộp mất hàng chục giây thì tập con SQL
/// tự viết không dùng được, và câu trả lời đúng là DuckDB (hoặc bỏ mục này).
///
/// Bốn câu hỏi, mỗi câu có thể lật phương án:
///
/// 1. **Sàn quét** — đọc hết bảng mà không tính gì tốn bao nhiêu? Mọi câu truy vấn trả tiền nó.
/// 2. **Lọc** — so sánh trên BYTE hay dựng `String` rồi so? Chênh nhau bao nhiêu?
/// 3. **Gộp nhóm** — số nhóm nhỏ (5) và số nhóm bằng số hàng (1 triệu). Cái sau là rủi ro BỘ
///    NHỚ: một bảng băm một triệu khoá.
/// 4. **Đúng hay không** — số nhanh mà sai thì vô nghĩa. Mọi kết quả đối chiếu với giá trị suy
///    thẳng từ công thức sinh fixture, KHÔNG suy từ chính đường CSV đang đo.
struct PoCGReport: Encodable {

    struct Fixture: Encodable {
        let rows: Int
        let columns: Int
        let cells: Int
        let megabytes: Double
    }

    struct Scan: Encodable {
        let path: String
        let milliseconds: Double
        let rowsSeen: Int
        let millionCellsPerSecond: Double
        let note: String
    }

    struct Query: Encodable {
        /// Câu SQL mà phép đo này mô phỏng. PoC chạy kế hoạch dựng tay, không qua parser.
        let sql: String
        let milliseconds: Double
        let rowsOut: Int
        let note: String
    }

    struct Memory: Encodable {
        let description: String
        let groups: Int
        let footprintBeforeMB: Double
        let footprintAfterMB: Double
        let deltaMB: Double
        let bytesPerGroup: Int
    }

    /// Cùng câu hỏi, nhưng chạy qua MÃ SẢN PHẨM (`CSVQueryRunner`) thay vì kế hoạch dựng tay.
    ///
    /// Có mặt vì một con số PoC mà mã sản phẩm không tái lập được là một con số vô giá trị. Đặt
    /// cạnh nhau thì thấy ngay phần "trên đường đi tới sản phẩm" đắt thêm bao nhiêu — cây
    /// `WHERE` đã giải, bảng gộp nhiều ô, dựng chuỗi cho kết quả.
    struct Product: Encodable {
        let sql: String
        let milliseconds: Double
        let rowsOut: Int
        let rowsScanned: Int
        /// Phép đo tương ứng ở kế hoạch dựng tay, để so.
        let prototypeMs: Double?
        let note: String
    }

    let poc = "PoC-G — tập con SQL trên CSVEngine (FR-CSV-407)"
    let architecture: String
    let fixture: Fixture
    let scan: [Scan]
    let queries: [Query]
    let product: [Product]
    let memory: [Memory]
    /// Kiểm ĐÚNG chứ không chỉ kiểm NHANH.
    let correctness: [String: String]
    let verdict: String
    let notes: [String]
}

enum PoCG {

    enum Failure: Error { case failed(String) }

    /// Một ô của bảng gộp.
    ///
    /// Là `struct` có hàm `add` chứ không phải tuple, để mỗi hàng chỉ TRA TỪ ĐIỂN MỘT LẦN:
    /// `dict[key, default: Agg()].add(v)` đi qua `_modify` và sửa tại chỗ. Viết thành
    /// `dict[key, default: …].count += 1` rồi `… .sum += v` là hai lần tra, và ở một triệu hàng
    /// thì phép đo không còn nói về phép gộp nữa mà nói về cách viết của tôi.
    struct Agg {
        var count = 0
        var sum = 0.0
        mutating func add(_ value: Double) {
            count += 1
            sum += value
        }
    }

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("  \(message)\n".utf8))
    }

    /// Số lần lặp cho mỗi phép đo. Lấy TRUNG VỊ.
    ///
    /// Bản đầu của PoC này đo mỗi câu đúng một lần, theo thứ tự, và cho ra "so trên byte 92,9 ms
    /// · dựng String 202,3 ms" — một kết luận rất gọn và rất sai. Chạy lại thì thành 56,4 và
    /// 57,9. Phép đo ĐẦU TIÊN đang trả tiền cache nguội hộ mọi phép sau, nên thứ tự đo quyết
    /// định kết quả chứ không phải thứ đang đo.
    static let repeats = 3

    /// Chạy `body` vài lần, trả TRUNG VỊ. `body` phải tự đặt lại biến tích lũy của nó.
    static func timed(_ body: () -> Void) -> Double {
        Measure.median((0 ..< repeats).map { _ in Measure.milliseconds(body) })
    }

    // MARK: - Đọc ô mà KHÔNG dựng String
    //
    // Giả thuyết khi viết PoC này: dựng một `String` cho mỗi ô sẽ là khoản đắt nhất, nên phải
    // so sánh và đọc số thẳng trên byte.
    //
    // **Số đo bác nó.** Ở 1 triệu hàng, `WHERE thanh_pho = 'Đà Nẵng'` tốn 567 ms khi so trên
    // byte và 599 ms khi dựng `String` — chênh 5,6 %, trong khi SÀN QUÉT (đọc hết bảng mà
    // không tính gì) đã là 568 ms. Nói cách khác: phân tích CSV chiếm gần như toàn bộ thời
    // gian, và phép so sánh dù viết cách nào cũng gần như miễn phí.
    //
    // Lý do giả thuyết sai: một câu `WHERE` chỉ chạm MỘT cột, tức một triệu ô chứ không phải
    // hai mươi triệu. Con số "hai mươi triệu lần cấp phát" chỉ đúng cho `SELECT *` đọc mọi ô —
    // ca ấy PoC này CHƯA đo.
    //
    // Giữ lại đường byte vì nó đã viết xong, đúng, và không đắt hơn. Nhưng đừng ai đọc mã này
    // rồi tưởng nó là chỗ quyết định hiệu năng: chỗ ấy là bộ phân tích CSV.

    /// So một ô với một chuỗi mẫu, trên byte thô.
    @inline(__always)
    static func equals(_ bytes: [UInt8], _ range: Range<Int>, _ needle: [UInt8]) -> Bool {
        guard range.count == needle.count else { return false }
        var i = range.lowerBound
        var j = 0
        while j < needle.count {
            if bytes[i] != needle[j] { return false }
            i += 1
            j += 1
        }
        return true
    }

    /// Đọc số từ byte thô, không qua `String` và không qua `Double(_:)`.
    ///
    /// Chỉ nhận dạng số mà CSV thật hay có: dấu âm, phần nguyên, phần thập phân. Gặp thứ khác
    /// (số mũ, dấu phân nhóm) thì trả `nil` — PoC không giả vờ hiểu nhiều hơn nó hiểu.
    @inline(__always)
    static func number(_ bytes: [UInt8], _ range: Range<Int>) -> Double? {
        var i = range.lowerBound
        guard i < range.upperBound else { return nil }
        var negative = false
        if bytes[i] == UInt8(ascii: "-") { negative = true; i += 1 }
        var value = 0.0
        var anyDigit = false
        while i < range.upperBound, bytes[i] >= 48, bytes[i] <= 57 {
            value = value * 10 + Double(bytes[i] - 48)
            i += 1
            anyDigit = true
        }
        if i < range.upperBound, bytes[i] == UInt8(ascii: ".") {
            i += 1
            var scale = 0.1
            while i < range.upperBound, bytes[i] >= 48, bytes[i] <= 57 {
                value += Double(bytes[i] - 48) * scale
                scale /= 10
                i += 1
                anyDigit = true
            }
        }
        guard anyDigit, i == range.upperBound else { return nil }
        return negative ? -value : value
    }

    // MARK: - Chạy

    static func run(rows: Int, columns: Int) throws -> PoCGReport {
        guard rows % 5 == 0 else {
            throw Failure.failed("--rows phải chia hết cho 5: fixture xoay vòng đúng 5 thành phố")
        }
        log("dựng fixture \(rows) hàng × \(columns) cột…")
        let bytes = CleanKPI.fixture(rows: rows, columns: columns)
        let buffer = TextBuffer(original: MemoryByteSource(bytes))
        let megabytes = Double(bytes.count) / 1_048_576
        let cells = rows * columns
        log(String(format: "  %.0f MB · %d ô", megabytes, cells))

        // Cột của fixture: 0 ma_kh · 1 thanh_pho · 2 doanh_thu · 3 ghi_chu · 4 ngay
        let colMaKH = 0, colCity = 1, colRevenue = 2

        // --- Kỳ vọng, suy từ CÔNG THỨC SINH chứ không từ đường CSV đang đo ------------------
        //
        // Đây là chỗ dễ tự lừa nhất trong một PoC hiệu năng: lấy kết quả của chính phép đo làm
        // đáp án thì phép kiểm đúng-sai không kiểm gì cả.
        let cities = ["Hà Nội", "TP Hồ Chí Minh", "Đà Nẵng", "Huế", "Cần Thơ"]
        var expectedByCity: [String: (count: Int, sum: Double)] = [:]
        var expectedTotal = 0.0
        for row in 0 ..< rows {
            let revenue = row == rows / 2 ? 999_999_999.0 : Double((row * 137) % 900_000)
            let city = cities[row % 5]
            expectedByCity[city, default: (0, 0)].count += 1
            expectedByCity[city, default: (0, 0)].sum += revenue
            expectedTotal += revenue
        }
        let danang = "Đà Nẵng"
        let expectedDanangRows = expectedByCity[danang]?.count ?? -1

        var scans: [PoCGReport.Scan] = []
        var queries: [PoCGReport.Query] = []
        var memory: [PoCGReport.Memory] = []
        var correctness: [String: String] = [:]

        // --- 1. Sàn quét ------------------------------------------------------------------
        //
        // Hai đường của CSVEngine, đo cạnh nhau. `forEachRow` tiện hơn nhưng nó dựng một mảng
        // CSVField MỚI cho mỗi hàng để dời phạm vi sang hệ tọa độ toàn cục; `forEachWindow`
        // cấp phát một lần cho mỗi cửa sổ. Chênh lệch ở đây quyết định đường mà mã sản phẩm
        // phải đi, và nó đo được TRƯỚC khi viết dòng nào.
        // Một lượt quét KHỞI ĐỘNG, không tính giờ: nạp bảng vào cache để phép đo đầu tiên
        // không phải trả tiền hộ những phép sau.
        log("quét khởi động…")
        var warmup = 0
        try? CSVEngine.forEachWindow(in: buffer, dialect: .comma) { rows, _, _ in
            warmup += rows.count
            return true
        }

        log("sàn quét…")
        var rowsSeenByRow = 0
        let msByRow = timed {
            rowsSeenByRow = 0
            try? CSVEngine.forEachRow(in: buffer, dialect: .comma) { _ in
                rowsSeenByRow += 1
                return true
            }
        }
        scans.append(.init(
            path: "forEachRow (một mảng CSVField mỗi hàng)",
            milliseconds: msByRow, rowsSeen: rowsSeenByRow,
            millionCellsPerSecond: Double(cells) / (msByRow / 1000) / 1_000_000,
            note: "tiện, nhưng cấp phát theo HÀNG"
        ))

        var rowsSeenByWindow = 0
        let msByWindow = timed {
            rowsSeenByWindow = 0
            try? CSVEngine.forEachWindow(in: buffer, dialect: .comma) { rows, _, _ in
                rowsSeenByWindow += rows.count
                return true
            }
        }
        scans.append(.init(
            path: "forEachWindow (một mảng mỗi cửa sổ 1 MB)",
            milliseconds: msByWindow, rowsSeen: rowsSeenByWindow,
            millionCellsPerSecond: Double(cells) / (msByWindow / 1000) / 1_000_000,
            note: "đường mà mọi câu truy vấn phải đi"
        ))
        correctness["sàn quét: hai đường đếm ra cùng số hàng"] =
            rowsSeenByRow == rowsSeenByWindow ? "đúng (\(rowsSeenByWindow))"
                : "SAI: \(rowsSeenByRow) vs \(rowsSeenByWindow)"

        // --- 2. WHERE: so byte hay so String ----------------------------------------------
        log("WHERE — byte vs String…")
        let needle = Array(danang.utf8)
        var matchedBytes = 0
        let msWhereBytes = timed {
            matchedBytes = 0
            var rowIndex = 0
            try? CSVEngine.forEachWindow(in: buffer, dialect: .comma) { rows, window, _ in
                for row in rows {
                    defer { rowIndex += 1 }
                    // Bỏ DÒNG TIÊU ĐỀ. Bản đầu của PoC này không bỏ, và `GROUP BY thanh_pho`
                    // ra 6 nhóm thay vì 5 — chuỗi "thanh_pho" thành một nhóm mang tên chính
                    // cái cột. Con số thời gian gần như không đổi, nhưng kết quả thì sai, và
                    // một PoC đo sai ngữ nghĩa là một PoC trả lời cho câu hỏi khác.
                    guard rowIndex > 0, row.count > colCity else { continue }
                    if equals(window, row[colCity].range, needle) { matchedBytes += 1 }
                }
                return true
            }
        }
        queries.append(.init(
            sql: "SELECT COUNT(*) FROM t WHERE thanh_pho = 'Đà Nẵng'   -- so trên BYTE",
            milliseconds: msWhereBytes, rowsOut: 1,
            note: "\(matchedBytes) hàng khớp"
        ))

        var matchedString = 0
        let msWhereString = timed {
            matchedString = 0
            var rowIndex = 0
            try? CSVEngine.forEachWindow(in: buffer, dialect: .comma) { rows, window, _ in
                for row in rows {
                    defer { rowIndex += 1 }
                    guard rowIndex > 0, row.count > colCity else { continue }
                    let text = String(decoding: window[row[colCity].range], as: UTF8.self)
                    if text == danang { matchedString += 1 }
                }
                return true
            }
        }
        queries.append(.init(
            sql: "SELECT COUNT(*) FROM t WHERE thanh_pho = 'Đà Nẵng'   -- dựng String mỗi ô",
            milliseconds: msWhereString, rowsOut: 1,
            note: "\(matchedString) hàng khớp"
        ))
        correctness["WHERE đếm đúng số hàng Đà Nẵng"] =
            matchedBytes == expectedDanangRows && matchedString == expectedDanangRows
                ? "đúng (\(expectedDanangRows))"
                : "SAI: byte \(matchedBytes) · String \(matchedString) · mong \(expectedDanangRows)"

        // --- 3. GROUP BY số nhóm NHỎ ------------------------------------------------------
        log("GROUP BY thanh_pho (5 nhóm)…")
        var grouped: [String: Agg] = [:]
        let msGroupSmall = timed {
            grouped = [:]
            var rowIndex = 0
            try? CSVEngine.forEachWindow(in: buffer, dialect: .comma) { rows, window, _ in
                for row in rows {
                    defer { rowIndex += 1 }
                    guard rowIndex > 0, row.count > colRevenue else { continue }
                    let key = String(decoding: window[row[colCity].range], as: UTF8.self)
                    let value = number(window, row[colRevenue].range) ?? 0
                    grouped[key, default: Agg()].add(value)
                }
                return true
            }
        }
        queries.append(.init(
            sql: "SELECT thanh_pho, COUNT(*), SUM(doanh_thu), AVG(doanh_thu)"
                + " FROM t GROUP BY thanh_pho",
            milliseconds: msGroupSmall, rowsOut: grouped.count,
            note: "\(grouped.count) nhóm"
        ))

        var groupMismatch: String?
        for (city, expect) in expectedByCity {
            guard let got = grouped[city] else { groupMismatch = "thiếu nhóm \(city)"; break }
            if got.count != expect.count {
                groupMismatch = "\(city): COUNT \(got.count) ≠ \(expect.count)"; break
            }
            if abs(got.sum - expect.sum) > 0.5 {
                groupMismatch = "\(city): SUM \(got.sum) ≠ \(expect.sum)"; break
            }
        }
        correctness["GROUP BY: COUNT và SUM khớp công thức sinh"] = groupMismatch ?? "đúng cả 5 nhóm"

        let totalSum = grouped.values.reduce(0.0) { $0 + $1.sum }
        correctness["SUM toàn bảng khớp (gồm cả giá trị cực đoan 999.999.999)"] =
            abs(totalSum - expectedTotal) < 0.5 ? "đúng" : "SAI: \(totalSum) ≠ \(expectedTotal)"

        // --- 4. ORDER BY + LIMIT trên kết quả đã gộp --------------------------------------
        var top: [(String, Double)] = []
        let msOrder = timed {
            top = grouped.map { ($0.key, $0.value.sum) }
                .sorted { $0.1 > $1.1 }
                .prefix(3).map { $0 }
        }
        queries.append(.init(
            sql: "… GROUP BY thanh_pho ORDER BY SUM(doanh_thu) DESC LIMIT 3",
            milliseconds: msOrder, rowsOut: top.count,
            note: "sắp xếp chạy trên KẾT QUẢ ĐÃ GỘP (5 dòng), không trên bảng gốc"
        ))

        // --- 5. GROUP BY số nhóm bằng số hàng — rủi ro bộ nhớ -----------------------------
        //
        // Đây là ca xấu nhất thật sự: khoá là `ma_kh`, duy nhất từng hàng, nên bảng băm phình
        // bằng chính bảng dữ liệu. Một engine cột như DuckDB xử lý ca này bằng cách tràn ra
        // đĩa; một `Dictionary` của Swift thì không — nó chỉ lớn lên cho tới khi hết RAM.
        log("GROUP BY ma_kh (\(rows) nhóm) — ca xấu nhất về bộ nhớ…")
        let beforeMB = Double(ProcessMemory.footprintBytes()) / 1_048_576
        var wide: [String: Double] = [:]
        wide.reserveCapacity(rows)
        // MỘT lần, không lấy trung vị như các phép trên: phép đo ở đây là BỘ NHỚ, và nó chỉ
        // có nghĩa khi bảng băm được dựng từ trạng thái rỗng đúng một lần. Chạy lại lần hai
        // thì từ điển đã đầy, `deltaMB` thành gần bằng không, và con số ấy nói dối theo hướng
        // dễ chịu nhất.
        let msGroupWide = Measure.milliseconds {
            var rowIndex = 0
            try? CSVEngine.forEachWindow(in: buffer, dialect: .comma) { rows, window, _ in
                for row in rows {
                    defer { rowIndex += 1 }
                    guard rowIndex > 0, row.count > colRevenue else { continue }
                    let key = String(decoding: window[row[colMaKH].range], as: UTF8.self)
                    wide[key, default: 0] += number(window, row[colRevenue].range) ?? 0
                }
                return true
            }
        }
        let afterMB = Double(ProcessMemory.footprintBytes()) / 1_048_576
        let wideGroups = wide.count
        queries.append(.init(
            sql: "SELECT ma_kh, SUM(doanh_thu) FROM t GROUP BY ma_kh   -- mỗi hàng một nhóm",
            milliseconds: msGroupWide, rowsOut: wideGroups,
            note: "ca xấu nhất: số nhóm = số hàng"
        ))
        memory.append(.init(
            description: "bảng băm GROUP BY ma_kh (khoá String)",
            groups: wideGroups,
            footprintBeforeMB: beforeMB, footprintAfterMB: afterMB,
            deltaMB: afterMB - beforeMB,
            bytesPerGroup: wideGroups > 0
                ? Int((afterMB - beforeMB) * 1_048_576) / wideGroups : 0
        ))
        correctness["GROUP BY cardinality cao ra đúng số nhóm"] =
            wideGroups == rows ? "đúng (\(wideGroups) nhóm = \(rows) hàng, mã khách duy nhất)"
                : "SAI: \(wideGroups), mong \(rows)"
        correctness["dòng tiêu đề KHÔNG bị tính thành một nhóm"] =
            grouped.count == 5 ? "đúng (5 thành phố)" : "SAI: \(grouped.count) nhóm, mong 5"
        wide = [:]

        // --- 6. Phần "qua MÃ SẢN PHẨM" đã bị GỠ 26/08/2026 --------------------------------
        //
        // Mục này từng chạy lại bốn câu trên `CSVQueryRunner` — engine SQL tự viết của ADR-11.
        // Engine ấy đã bị xoá theo ADR-14 (chuyển hẳn sang DuckDB), nên đoạn mã ấy không còn
        // thứ để gọi.
        //
        // KHÔNG xoá cả PoC-G: phần còn lại của nó đo SÀN QUÉT của `CSVEngine` (forEachRow so
        // forEachWindow), và sàn ấy vẫn là sàn — nó nói cái giá tối thiểu của việc đi qua từng
        // ô CSV, độc lập với engine truy vấn nào ngồi bên trên. Số đo của mục 6 cũ vẫn còn
        // nguyên trong `benchmarks/results/poc-g-arm64.json` như một bản ghi lịch sử.
        let product: [PoCGReport.Product] = []

        // --- Kết luận ---------------------------------------------------------------------
        // Mốc đánh giá lấy theo MÃ SẢN PHẨM, không theo kế hoạch dựng tay: thứ người dùng chạy
        // là cái kia.
        let worstQuery = max(
            queries.map(\.milliseconds).max() ?? 0,
            product.map(\.milliseconds).max() ?? 0)
        let allCorrect = correctness.values.allSatisfy { !$0.hasPrefix("SAI") && !$0.contains("≠") }
        let verdict: String
        if !allCorrect {
            verdict = "KHÔNG ĐẠT — có phép tính ra kết quả SAI; con số thời gian không có nghĩa gì"
        } else if worstQuery <= 5_000 {
            verdict = String(
                format: "ĐẠT — câu chậm nhất %.0f ms trên %d hàng × %d cột. Tập con SQL tự viết"
                    + " sống được ở cỡ này; không cần DuckDB cho SELECT/WHERE/GROUP BY/ORDER BY.",
                worstQuery, rows, columns)
        } else {
            verdict = String(
                format: "CẦN CÂN LẠI — câu chậm nhất %.0f ms, quá mốc 5 s đề nghị.", worstQuery)
        }

        return PoCGReport(
            architecture: architectureName(),
            fixture: .init(rows: rows, columns: columns, cells: cells, megabytes: megabytes),
            scan: scans, queries: queries, product: product, memory: memory,
            correctness: correctness, verdict: verdict,
            notes: [
                "PoC CỐ Ý không có parser SQL. Kế hoạch truy vấn dựng tay; thứ đang đo là chi phí"
                    + " THỰC THI, vì đó là thứ chưa ai biết và là thứ có thể giết phương án.",
                "Mốc 5 giây là ĐỀ NGHỊ, chưa phải chỉ tiêu đã chốt: bộ tài liệu chưa có NFR nào"
                    + " cho FR-CSV-407. Đặt ngang hàng NFR-CLN-01 (Data Profile ≤ 10 s trên cùng"
                    + " cỡ bảng) rồi siết một nửa.",
                "Mọi kỳ vọng đúng-sai suy từ CÔNG THỨC SINH fixture, không suy từ đường CSV đang"
                    + " đo — lấy kết quả của phép đo làm đáp án thì không kiểm được gì.",
                "Chưa đo: JOIN, subquery, cửa sổ hàm. Nếu phạm vi cần chúng thì PoC này KHÔNG"
                    + " trả lời cho chúng, và câu trả lời rất có thể đổi.",
            ]
        )
    }

    private static func architectureName() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
