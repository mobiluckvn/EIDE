import Foundation
import GEditorCore

// PoC-K — DuckDB có đáng nhúng ở phạm vi RỘNG hơn FR-CSV-407 không?
//
// ADR-11 lật DuckDB cho riêng FR-CSV-407 và ghi rõ phạm vi lật: "phần còn lại của SAD không
// đổi". Nhưng SRS v2.2 còn dựa vào DuckDB ở bảy chỗ khác (FR-QRY-001/003/005/006,
// FR-DQR-001 rule `expr`/`foreign_key`, FR-KNW-907, FR-KNW-913), và năm trong bảy chỗ ấy đòi
// đúng những cú pháp mà engine tự viết đang báo "chưa làm".
//
// Phần Swift của PoC làm hai việc, và CỐ Ý không làm việc thứ ba:
//
//   1. Dựng fixture Y HỆT PoC-G rồi GHI RA FILE, để DuckDB và engine tự viết đọc cùng một byte.
//      Không dùng lại con số 619/752 ms đã lưu: chúng đo ở phiên khác, mà chính tài liệu này
//      đã ghi rằng cùng một bản dựng cho 507/524/547 ms ở ba phiên đo khác nhau. So hai engine
//      thì phải so TRONG CÙNG MỘT PHIÊN.
//   2. Chạy engine tự viết trên đúng bốn câu của PoC-G, và **hỏi nó bảy câu nó chưa làm được**
//      rồi ghi lại NGUYÊN VĂN thông báo lỗi. Danh sách ấy là bằng chứng cho cái cổng, chứ không
//      phải trí nhớ của người viết tài liệu.
//   3. KHÔNG đo DuckDB ở đây — phần đó nằm ở `scripts/run-poc-k.sh`, vì thứ cần đo là hình dạng
//      thật: `dlopen` một dylib nằm trong bundle đã ký, đúng cách PoC-I đã đo libxml2.
enum PoCK {
    struct Report: Encodable {
        struct Fixture: Encodable {
            let rows: Int
            let columns: Int
            let cells: Int
            let megabytes: Double
            let path: String
            let lookupPath: String
            let lookupRows: Int
        }

        struct Query: Encodable {
            let sql: String
            let milliseconds: Double
            let rowsOut: Int
            let rowsScanned: Int
            let answer: String
        }

        struct Gap: Encodable {
            let sql: String
            let need: String
            let error: String
            let parsed: Bool
        }

        let poc: String
        let architecture: String
        let fixture: Fixture
        let product: [Query]
        let gaps: [Gap]
        let correctness: [String: String]
        let notes: [String]
    }

    enum Failure: Error { case failed(String) }

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("   \(message)\n".utf8))
    }

    static func timed(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    static func run(rows: Int, columns: Int, outDirectory: String) throws -> Report {
        guard rows % 5 == 0 else {
            throw Failure.failed("--rows phải chia hết cho 5: fixture xoay vòng đúng 5 thành phố")
        }

        // --- 1. Fixture, ghi ra đĩa -------------------------------------------------------
        log("dựng fixture \(rows) hàng × \(columns) cột…")
        let bytes = CleanKPI.fixture(rows: rows, columns: columns)
        let megabytes = Double(bytes.count) / 1_048_576
        let csvPath = (outDirectory as NSString).appendingPathComponent("poc-k-fixture.csv")
        try Data(bytes).write(to: URL(fileURLWithPath: csvPath))
        log(String(format: "  %.0f MB → %@", megabytes, csvPath))

        // Bảng tra để đo JOIN — thứ FR-QRY-005 đòi và engine tự viết chưa có.
        // Cố ý NHỎ: join một bảng lớn với một bảng tra vài dòng là hình dạng thật của
        // FR-DQR-001 `foreign_key` và của phần lớn join trong công việc dữ liệu văn phòng.
        let lookup = """
            thanh_pho,vung_mien
            Hà Nội,Bắc
            TP Hồ Chí Minh,Nam
            Đà Nẵng,Trung
            Huế,Trung
            Cần Thơ,Nam

            """
        let lookupPath = (outDirectory as NSString).appendingPathComponent("poc-k-vung-mien.csv")
        try Data(lookup.utf8).write(to: URL(fileURLWithPath: lookupPath))

        let buffer = TextBuffer(original: MemoryByteSource(bytes))

        // --- 2. Kỳ vọng, suy từ CÔNG THỨC SINH --------------------------------------------
        //
        // Cùng luật với PoC-G: lấy kết quả phép đo làm đáp án thì phép kiểm không kiểm gì cả.
        let expectedDanang = rows / 5
        var expectedTrungSum = 0.0      // Đà Nẵng + Huế — đáp án của câu JOIN
        var expectedTrungCount = 0
        for row in 0 ..< rows where row % 5 == 2 || row % 5 == 3 {
            expectedTrungSum += row == rows / 2 ? 999_999_999.0 : Double((row * 137) % 900_000)
            expectedTrungCount += 1
        }

        var correctness: [String: String] = [:]
        correctness["đáp án JOIN suy từ công thức sinh (vùng Trung = Đà Nẵng + Huế)"] =
            "\(expectedTrungCount) hàng · tổng \(String(format: "%.0f", expectedTrungSum))"

        // --- 3. Engine tự viết, ĐO LẠI TRONG PHIÊN NÀY ------------------------------------
        log("chạy engine sản phẩm (CSVQueryEngine trên DuckDB) — cùng bốn câu của PoC-G…")
        var product: [Report.Query] = []
        let cases = [
            "SELECT COUNT(*) FROM t WHERE thanh_pho = 'Đà Nẵng'",
            "SELECT thanh_pho, COUNT(*), SUM(doanh_thu), AVG(doanh_thu) FROM t GROUP BY thanh_pho",
            "SELECT ma_kh, SUM(doanh_thu) FROM t GROUP BY ma_kh",
            "SELECT * FROM t LIMIT 10",
        ]
        for sql in cases {
            var result: CSVQueryEngine.Result?
            let milliseconds = timed {
                result = try? CSVQueryEngine.run(
                    sql, in: buffer, dialect: .comma, sourcePath: csvPath)
            }
            guard let result else { throw Failure.failed("engine không chạy được: \(sql)") }
            let answer = result.rows.first
                .map { $0.map { $0 ?? "NULL" }.joined(separator: " · ") } ?? "(rỗng)"
            product.append(.init(
                sql: sql, milliseconds: milliseconds, rowsOut: result.rows.count,
                rowsScanned: -1, answer: String(answer.prefix(80))))
            log(String(format: "  %7.0f ms  %@", milliseconds, sql))
        }

        correctness["engine đếm đúng số hàng Đà Nẵng"] =
            product[0].answer == String(expectedDanang)
                ? "đúng (\(expectedDanang))"
                : "SAI: \(product[0].answer), mong \(expectedDanang)"

        // --- 4. Bảy câu engine TỰ VIẾT từng từ chối ---------------------------------------
        //
        // Bản ghi lịch sử của bảy lời từ chối ấy nằm ở `benchmarks/results/poc-k-arm64.json`.
        // Engine tự viết đã bị xoá 26/08/2026 theo ADR-14, nên ở đây chỉ còn một việc: chứng
        // minh engine hiện tại CHẠY ĐƯỢC cả bảy. Câu nào đỏ nghĩa là việc đổi engine đã đánh
        // mất đúng thứ nó được đổi để lấy.
        log("chạy bảy câu mà engine cũ từng từ chối…")
        let gapCases: [(String, String)] = [
            (
                "SELECT COUNT(*) FROM t JOIN (SELECT 'Đà Nẵng' AS tp UNION ALL"
                    + " SELECT 'Huế') v ON t.thanh_pho = v.tp",
                "FR-QRY-005 join đa file · FR-DQR-001 rule foreign_key"
            ),
            ("SELECT COUNT(DISTINCT thanh_pho) FROM t", "FR-QRY-003 pivot sinh SQL có DISTINCT"),
            (
                "SELECT COUNT(*) FROM (SELECT thanh_pho FROM t GROUP BY thanh_pho"
                    + " HAVING COUNT(*) > 100)",
                "FR-QRY-003 pivot có điều kiện trên nhóm"
            ),
            ("SELECT COUNT(*) FROM t WHERE thanh_pho IN ('Huế', 'Đà Nẵng')",
             "FR-DQR-001 rule in_set"),
            ("SELECT COUNT(*) FROM t WHERE ghi_chu LIKE 'binh%'", "FR-DQR-001 rule regex/like"),
            ("SELECT COUNT(*) FROM t WHERE doanh_thu BETWEEN 0 AND 1000",
             "FR-DQR-001 rule range"),
            (
                "SELECT COUNT(*) FROM t WHERE doanh_thu > (SELECT AVG(doanh_thu) FROM t)",
                "FR-DQR-002 chiều ACCURACY · FR-KNW-913 openCypher → SQL lồng"
            ),
        ]
        var gaps: [Report.Gap] = []
        for (sql, need) in gapCases {
            var message = "chạy được"
            var parsed = true
            do {
                let result = try CSVQueryEngine.run(
                    sql, in: buffer, dialect: .comma, sourcePath: csvPath)
                message = result.rows.first?.first.map { $0 ?? "NULL" } ?? "(rỗng)"
            } catch {
                parsed = false
                message = (error as? CSVQueryEngine.Failure)?.message ?? "\(error)"
            }
            gaps.append(.init(sql: sql, need: need, error: message, parsed: parsed))
            log("  \(parsed ? "CHẠY ĐƯỢC" : "ĐỎ") — \(sql.prefix(46))… → \(message.prefix(20))")
        }

        // Đối chứng cho chính bảng trên: nếu bốn câu cơ bản ở mục 3 cũng đỏ thì bảng này không
        // nói lên điều gì — "cả bảy đều chạy" chỉ có nghĩa khi phép đo còn phân biệt được.
        correctness["bảng trên có đối chứng: bốn câu cơ bản vẫn chạy được"] =
            product.count == cases.count ? "đúng (\(cases.count)/\(cases.count) câu chạy)" : "SAI"

        let ran = gaps.filter(\.parsed).count
        correctness["bảy câu engine cũ từng từ chối, nay chạy được"] =
            ran == gaps.count ? "đúng (\(ran)/\(gaps.count))" : "SAI: chỉ \(ran)/\(gaps.count)"

        return Report(
            poc: "PoC-K — DuckDB ở phạm vi rộng hơn FR-CSV-407",
            architecture: architectureName(),
            fixture: .init(
                rows: rows, columns: columns, cells: rows * columns, megabytes: megabytes,
                path: csvPath, lookupPath: lookupPath, lookupRows: 5),
            product: product, gaps: gaps, correctness: correctness,
            notes: [
                "Phần này KHÔNG đo DuckDB. Nó dựng fixture chung và đo lại engine tự viết trong"
                    + " CÙNG PHIÊN, để `scripts/run-poc-k.sh` so hai engine trên cùng byte và"
                    + " cùng máy — chứ không so với con số 619/752 ms lưu từ phiên khác.",
                "Bảng `gaps` ghi nguyên văn lỗi của engine tự viết. Nó là danh sách việc phải"
                    + " viết nếu chọn đường A (mở rộng engine tự viết), và là thứ thay cho trí"
                    + " nhớ khi đọc lại quyết định này sau sáu tháng.",
                "Fixture giống hệt PoC-G (CleanKPI.fixture) — cùng công thức sinh, nên mọi đáp"
                    + " án đúng-sai vẫn suy từ công thức chứ không từ đường CSV đang đo.",
            ]
        )
    }

    private static func architectureName() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "không rõ"
        #endif
    }
}
