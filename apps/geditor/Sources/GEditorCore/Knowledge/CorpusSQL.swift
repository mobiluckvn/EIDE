import Foundation

/// Truy vấn SQL thẳng trên corpus và đồ thị — FR-KNW-907.
///
/// ## Một nửa mã này đã có sẵn, và nói ra thì rẻ hơn viết lại
///
/// Đặc tả viết *"mở rộng DuckDB (FR-CSV-407) đọc trực tiếp JSONL và Parquet"*. Khi đối chiếu mã
/// thì vế ấy **đã xong từ trước**: `CSVQueryEngine.readerCall(for:escaped:)` chọn
/// `read_json_auto` cho `.jsonl/.ndjson/.json` và `read_parquet` cho `.parquet`, và
/// `extraSources` đăng ký chúng thành view. Đã kiểm bằng vật thật, không suy từ mã: DuckDB vendor
/// đọc được JSONL ba dòng và suy đúng bốn cột, còn `read_parquet` trả lỗi *"No files found"* —
/// tức hàm CÓ, chỉ thiếu file.
///
/// Nên tệp này **không** viết lại lớp đọc. Nó thêm đúng hai thứ còn thiếu:
///
/// 1. một đường vào **không cần buffer CSV** — `CSVQueryEngine.run` đòi một tài liệu đang mở làm
///    bảng `t`, mà hỏi thống kê một corpus trên đĩa thì không có tài liệu nào cả;
/// 2. bốn **câu hỏi dựng sẵn** mà đặc tả gọi tên: phân bố degree, node mồ côi, bản ghi trùng,
///    phủ metadata.
///
/// ## Vì sao câu hỏi dựng sẵn, không phải "cứ để người dùng tự gõ SQL"
///
/// Bốn câu ấy trông đơn giản mà viết đúng thì không: "node mồ côi" phải hợp cả cột nguồn lẫn cột
/// đích trước khi trừ, "phủ metadata" phải phân biệt NULL với chuỗi rỗng, và "phân bố degree"
/// phải đếm cả cạnh vào lẫn cạnh ra. Gõ sai một trong ba thì kết quả vẫn ra một bảng trông hợp
/// lý — và đó là kiểu sai không ai bắt được.
public enum CorpusSQL {

    /// Chỉ-đọc, thừa hưởng NFR-QRY-03 từ `CSVQueryEngine`: mọi câu đi qua `inspect` trước.
    public typealias Result = CSVQueryEngine.Result
    public typealias Failure = CSVQueryEngine.Failure

    /// Bốn câu hỏi đặc tả gọi tên.
    public enum Builtin: String, CaseIterable, Sendable {
        /// Phân bố bậc của node trong một edge list.
        case degreeDistribution
        /// Node chỉ xuất hiện ở một phía và không nối với gì khác.
        case orphanNodes
        /// Bản ghi trùng theo một trường khoá.
        case duplicateRecords
        /// Tỷ lệ ô có giá trị thật của từng cột.
        case metadataCoverage

        public var displayName: String {
            switch self {
            case .degreeDistribution: return "Phân bố bậc (degree)"
            case .orphanNodes: return "Node mồ côi"
            case .duplicateRecords: return "Bản ghi trùng"
            case .metadataCoverage: return "Phủ metadata"
            }
        }
    }

    /// Chạy một câu SQL trên các nguồn đã đặt tên.
    ///
    /// - Parameter sources: tên view → đường dẫn file. Đuôi file quyết định bộ đọc, đúng bảng
    ///   của `CSVQueryEngine.readerCall` — nên `.jsonl`, `.parquet`, `.tsv`, `.csv` đều đi được
    ///   mà không phải khai gì thêm.
    public static func run(
        _ sql: String,
        sources: [String: String],
        cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        guard DuckDB.isAvailable else {
            throw Failure.unavailable(DuckDB.failureReason ?? "không nạp được libduckdb")
        }
        let connection = try DuckDB.connect()

        // Cùng khuôn canh huỷ với `CSVQueryEngine`: `duckdb_interrupt` phải được gọi từ luồng
        // KHÁC, vì luồng này đang bị chính truy vấn chiếm. NFR-QRY-01 đòi huỷ ≤ 200 ms.
        let finished = NSLock()
        var done = false
        if !cancelToken.isCancelled {
            Thread.detachNewThread { [weak connection] in
                while true {
                    Thread.sleep(forTimeInterval: 0.05)
                    finished.lock(); let stop = done; finished.unlock()
                    if stop { return }
                    if cancelToken.isCancelled { connection?.interrupt(); return }
                }
            }
        }
        defer { finished.lock(); done = true; finished.unlock() }

        // Đăng ký theo thứ tự TÊN, không theo thứ tự từ điển trả về: `Dictionary` không có thứ
        // tự, và một thông báo lỗi đổi chỗ giữa hai lần chạy là thông báo không tra được.
        for name in sources.keys.sorted() {
            guard CSVQueryEngine.isValidTableName(name) else {
                throw Failure.query("Tên nguồn «\(name)» không hợp lệ.")
            }
            let path = sources[name]!
            let escaped = path.replacingOccurrences(of: "'", with: "''")
            do {
                _ = try connection.query("""
                    CREATE OR REPLACE VIEW "\(name)" AS
                    SELECT * FROM \(CSVQueryEngine.readerCall(for: path, escaped: escaped))
                    """)
            } catch DuckDB.Failure.query(let message) {
                throw Failure.query("Không đọc được nguồn «\(name)»: "
                    + DuckDBErrorText.vietnamese(message).text)
            }
        }

        // HÀNG RÀO CHỈ-ĐỌC — cùng một luật với `CSVQueryEngine`, và cố ý lặp lại ở đây chứ không
        // "tin rằng chỗ kia đã kiểm": đây là một đường vào KHÁC, và một hàng rào chỉ giữ được
        // những lối nó thật sự đứng chắn.
        let inspection = try connection.inspect(sql)
        guard inspection.statementCount == 1 else {
            throw Failure.multipleStatements(inspection.statementCount)
        }
        guard inspection.isSelect else { throw Failure.notReadOnly }

        let started = DispatchTime.now().uptimeNanoseconds
        do {
            let table = try connection.query(sql)
            return Result(titles: table.titles, rows: table.rows,
                          milliseconds: Double(DispatchTime.now().uptimeNanoseconds - started) / 1e6)
        } catch DuckDB.Failure.cancelled {
            throw Failure.cancelled
        } catch DuckDB.Failure.query(let message) {
            throw Failure.query(DuckDBErrorText.vietnamese(message).text)
        }
    }

    // MARK: - Câu hỏi dựng sẵn

    /// Phân bố bậc: mỗi node đếm CẢ cạnh vào lẫn cạnh ra.
    ///
    /// Đếm một phía là sai theo cách khó thấy: trong một đồ thị tri thức, một node "hub" thường
    /// chỉ đứng ở phía đích (mọi thứ trỏ về nó), nên đếm cạnh-ra sẽ xếp nó cùng hạng với node
    /// mồ côi.
    public static func degreeDistributionSQL(
        edges: String = "e", source: String = "source", target: String = "target"
    ) -> String {
        """
        WITH d AS (
            SELECT "\(source)" AS node FROM "\(edges)"
            UNION ALL
            SELECT "\(target)" AS node FROM "\(edges)"
        )
        SELECT bac, count(*) AS so_node
        FROM (SELECT node, count(*) AS bac FROM d WHERE node IS NOT NULL GROUP BY node)
        GROUP BY bac
        ORDER BY bac
        """
    }

    /// Node mồ côi: có mặt trong danh sách node nhưng KHÔNG xuất hiện ở đầu nào của cạnh nào.
    ///
    /// Phải hợp cả hai cột cạnh TRƯỚC rồi mới trừ. Trừ theo từng cột rồi giao lại cho ra kết quả
    /// khác hẳn — và vẫn là một bảng trông hợp lý.
    public static func orphanNodesSQL(
        nodes: String = "n", nodeKey: String = "id",
        edges: String = "e", source: String = "source", target: String = "target"
    ) -> String {
        """
        SELECT "\(nodeKey)" AS node
        FROM "\(nodes)"
        WHERE "\(nodeKey)" NOT IN (
            SELECT "\(source)" FROM "\(edges)" WHERE "\(source)" IS NOT NULL
            UNION
            SELECT "\(target)" FROM "\(edges)" WHERE "\(target)" IS NOT NULL
        )
        ORDER BY node
        """
    }

    /// Bản ghi trùng theo một trường khoá — trả cả SỐ LẦN để người đọc biết mức nghiêm trọng.
    public static func duplicateRecordsSQL(
        table: String = "c", key: String = "id", limit: Int = 500
    ) -> String {
        """
        SELECT "\(key)" AS khoa, count(*) AS so_lan
        FROM "\(table)"
        WHERE "\(key)" IS NOT NULL
        GROUP BY "\(key)"
        HAVING count(*) > 1
        ORDER BY so_lan DESC, khoa
        LIMIT \(limit)
        """
    }

    /// Phủ metadata: mỗi cột có bao nhiêu phần trăm ô mang giá trị THẬT.
    ///
    /// Chuỗi RỖNG không tính là có giá trị. Đó không phải chi tiết vụn: trong corpus xuất từ
    /// công cụ khác, trường thiếu thường ra `""` chứ không ra `NULL`, và một cột 100% `""` mà
    /// báo "phủ 100%" là câu trả lời sai cho đúng câu hỏi người ta đang hỏi.
    ///
    /// Cần biết TÊN CỘT nên nó nhận danh sách — chỗ gọi lấy bằng `DESCRIBE`.
    public static func metadataCoverageSQL(table: String = "c", columns: [String]) -> String {
        guard !columns.isEmpty else { return "SELECT NULL AS cot WHERE false" }
        let ve = columns.map { cot in
            let an = cot.replacingOccurrences(of: "\"", with: "\"\"")
            let nhan = cot.replacingOccurrences(of: "'", with: "''")
            return """
                SELECT '\(nhan)' AS cot,
                       count(*) FILTER (
                           WHERE "\(an)" IS NOT NULL AND CAST("\(an)" AS VARCHAR) <> ''
                       ) AS co_gia_tri,
                       count(*) AS tong
                FROM "\(table)"
                """
        }.joined(separator: "\nUNION ALL\n")
        return """
            SELECT cot, co_gia_tri, tong,
                   round(100.0 * co_gia_tri / nullif(tong, 0), 1) AS phu_phan_tram
            FROM (\n\(ve)\n)
            ORDER BY phu_phan_tram, cot
            """
    }

    /// Tên cột của một nguồn — chỗ gọi cần nó để dựng câu phủ metadata.
    public static func columns(of source: String, path: String) throws -> [String] {
        try run("DESCRIBE SELECT * FROM \"\(source)\"", sources: [source: path])
            .rows.compactMap { $0.first ?? nil }
    }
}
