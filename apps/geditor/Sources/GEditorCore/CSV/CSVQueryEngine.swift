import Foundation

/// Truy vấn SQL trên bảng CSV đang mở — chạy trên **DuckDB** (ADR-14, 26/08/2026).
///
/// Thay hẳn engine tự viết (`CSVQuery` + `CSVQueryParser` + `CSVQueryRunner`, 1.240 dòng) đã
/// phục vụ FR-CSV-407 từ 24/08. Lý do bỏ nó KHÔNG phải vì nó chạy sai — nó đúng, nhanh, và có
/// 48 bài kiểm. Lý do là **một sản phẩm không nên có hai tập cú pháp SQL**: engine cũ từ chối
/// `JOIN`, `DISTINCT`, `HAVING`, `IN`, `LIKE`, `BETWEEN` và truy vấn con (PoC-K đo 7/7), nên
/// giữ cả hai nghĩa là cùng một câu SQL chạy được ở panel này và bị từ chối ở panel kia, và
/// người dùng không có cách nào đoán ra vì sao.
///
/// ## Dữ liệu đi vào DuckDB bằng đường nào
///
/// Đây là hệ quả kiến trúc lớn nhất của việc đổi engine, và nó phải được nói ra chứ không giấu:
/// engine cũ chạy **thẳng trên `TextBuffer`** — trên chính vùng nhớ đang mở, kể cả khi tài liệu
/// đã sửa mà chưa lưu. DuckDB đọc **file**.
///
/// Nên `run` cần một trong hai:
///
/// - **`sourcePath` khớp với buffer** (tài liệu đã lưu, chưa sửa): trỏ DuckDB thẳng vào file
///   gốc. Không chép một byte nào — đường nhanh, và là đường của phần lớn lượt dùng.
/// - **Buffer đã sửa**: phải ghi ra file tạm trước. Với tài liệu 500 MB đang sửa dở thì đó là
///   500 MB đi vào đĩa cho MỘT câu truy vấn. `materializationLimit` chặn trước và **nói ra**,
///   thay vì để người dùng chờ một việc họ không biết mình đã yêu cầu.
///
/// Không có đường thứ ba: DuckDB không nhận một vùng nhớ làm nguồn CSV.
///
/// ## Chỉ-đọc (NFR-QRY-03)
///
/// Bảo đảm bằng HAI lớp, vì một lớp là không đủ:
///
/// 1. Cơ sở dữ liệu nằm **trong bộ nhớ**, và file nguồn chỉ được đọc qua `read_csv` /
///    `read_json_auto` / `read_parquet`. Mọi thứ người dùng tạo ra sống trong một CSDL vứt đi
///    khi đóng panel.
/// 2. `inspect` đi qua `duckdb_extract_statements` + `duckdb_prepare` +
///    `duckdb_prepared_statement_type`: **đúng một câu**, và câu ấy **phải là SELECT**. Thứ gì
///    không phải SELECT — kể cả `COPY … TO 'file'`, thứ DuckDB hoàn toàn có thể dùng để GHI ra
///    đĩa — bị chặn trước khi chạm tới dữ liệu.
///
/// Lớp 1 bảo vệ file nguồn; lớp 2 bảo vệ mọi file khác trên máy.
public enum CSVQueryEngine {

    /// Kết quả: một bảng nhỏ, đã sẵn sàng hiện ra.
    ///
    /// `String?` chứ không `String`: `nil` là `NULL`, khác hẳn chuỗi rỗng. Engine cũ không phân
    /// biệt được vì nó đọc mọi ô thành chuỗi; đổi sang DuckDB thì phân biệt ấy có thật, và cả
    /// cụm FR-CLN-002 (xử lý giá trị thiếu) dựng trên đúng phân biệt đó.
    public struct Result: Equatable, Sendable {
        public var titles: [String]
        public var rows: [[String?]]
        /// Mili-giây DuckDB tiêu cho câu này — để panel hiện và để bộ đo so sánh.
        public var milliseconds: Double

        public init(titles: [String], rows: [[String?]], milliseconds: Double = 0) {
            self.titles = titles
            self.rows = rows
            self.milliseconds = milliseconds
        }
    }

    public enum Failure: Error, Equatable, Sendable {
        /// Máy không có libduckdb. Tách riêng để giao diện nói "máy này thiếu thứ gì đó" thay
        /// vì đổ lỗi cho câu truy vấn của người dùng.
        case unavailable(String)
        /// Lỗi của chính câu truy vấn — đã dịch sang tiếng Việt khi nhận ra được họ lỗi.
        case query(String)
        /// Câu không phải `SELECT` (COPY, DROP, INSTALL…). Tách riêng vì lý do từ chối khác hẳn
        /// một lỗi cú pháp, và DuckDB gọi cả hai là "Parser Error".
        case notReadOnly
        /// Nhiều câu ngăn bởi dấu `;`.
        case multipleStatements(Int)
        case cancelled
        /// Buffer đã sửa và quá lớn để ghi ra file tạm.
        case tooLargeToMaterialize(bytes: Int, limit: Int)

        public var message: String {
            switch self {
            case .unavailable(let why):
                return "Không dùng được engine truy vấn trên máy này. \(why)"
            case .query(let text):
                return text
            case .notReadOnly:
                return "Panel này chỉ chạy câu ĐỌC dữ liệu (SELECT). Câu vừa gõ sẽ ghi hoặc "
                    + "đổi trạng thái, nên nó bị từ chối trước khi chạm tới dữ liệu "
                    + "(NFR-QRY-03)."
            case .multipleStatements(let count):
                return "Câu truy vấn có \(count) lệnh ngăn bởi dấu «;». Panel chỉ chạy MỘT "
                    + "lệnh SELECT — chạy cả chuỗi là mở đường cho một lệnh ghi nấp sau một "
                    + "lệnh đọc."
            case .cancelled:
                return "Đã hủy truy vấn."
            case .tooLargeToMaterialize(let bytes, let limit):
                return """
                    Tài liệu đã sửa và đang ở \(bytes / 1_048_576) MB, quá mức \
                    \(limit / 1_048_576) MB cho phép chép ra file tạm. Lưu tài liệu rồi chạy \
                    lại — khi đã lưu thì truy vấn đọc thẳng file gốc, không chép gì cả.
                    """
            }
        }
    }

    /// Trần cho việc chép buffer đã sửa ra file tạm.
    ///
    /// 256 MB: đủ cho mọi bảng CSV người ta thật sự ngồi sửa tay, và đủ nhỏ để không biến một
    /// câu truy vấn thành một lượt ghi đĩa hàng phút. Cùng tinh thần với trần 64 MB của
    /// FR-DOC-305 và trần 20 MB của in ấn — một con số nói ra được, không phải một cú treo máy.
    public static var materializationLimit = 256 * 1_048_576

    /// Tên bảng mà người dùng gõ trong câu truy vấn.
    ///
    /// Giữ nguyên `t` của engine cũ: mọi câu người dùng đã lưu, mọi ảnh chụp màn hình trong tài
    /// liệu, và mọi bài kiểm đều viết `FROM t`. Đổi tên bảng là một thay đổi phá vỡ mà chẳng
    /// đổi lại được gì.
    public static let tableName = "t"

    // MARK: - Chạy

    /// Kiểm câu truy vấn mà KHÔNG quét dữ liệu.
    ///
    /// Có mặt vì panel chạy truy vấn ở luồng nền: không có hàm này thì một câu gõ sai tên cột
    /// phải chờ hết lượt quét rồi mới được báo, và trong lúc ấy panel hiện "Đang chạy…" cho một
    /// câu không bao giờ chạy nổi.
    ///
    /// Đi qua `duckdb_prepare`: DuckDB ràng buộc hết tên cột và kiểu — nên tên cột sai bị bắt
    /// ngay — mà không đọc một hàng nào, và lỗi trỏ vào ĐÚNG chuỗi người dùng gõ.
    public static func validate(
        _ sql: String, in buffer: TextBuffer, dialect: CSVDialect, sourcePath: String? = nil,
        extraSources: [String: String] = [:]
    ) throws {
        _ = try execute(
            sql, in: buffer, dialect: dialect, sourcePath: sourcePath,
            extraSources: extraSources, cancelToken: CancelToken(), inspectOnly: true)
    }

    /// Hàm đọc của DuckDB cho một nguồn, chọn theo ĐUÔI FILE.
    ///
    /// FR-QRY-001 đòi console chạy trên *"CSV, TSV, JSONL, Parquet"*. Ba định dạng sau không
    /// đọc bằng `read_csv` được: Parquet là nhị phân có schema riêng, còn JSONL mỗi dòng là một
    /// đối tượng chứ không phải một hàng phân tách bằng dấu.
    ///
    /// Chọn theo đuôi file chứ không dò nội dung: dò nội dung nghĩa là đọc file trước khi biết
    /// đọc nó bằng gì, và đoán sai trên một file 2 GB thì tốn cả một lượt quét để phát hiện.
    /// Đuôi lạ thì rơi về `read_csv` — DuckDB sẽ tự nói ra nếu nó không đọc nổi.
    static func readerCall(for path: String, escaped: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "parquet":
            return "read_parquet('\(escaped)')"
        case "json", "jsonl", "ndjson":
            // `read_json_auto` suy schema từ vài dòng đầu. Đó là một phép ĐOÁN, và DuckDB nói
            // ra khi đoán trượt — tốt hơn là ta tự đoán rồi im lặng.
            return "read_json_auto('\(escaped)')"
        case "tsv", "tab":
            return "read_csv('\(escaped)', header = true, delim = '\t')"
        default:
            return "read_csv('\(escaped)', header = true)"
        }
    }

    /// Tên bảng có hợp lệ không — dùng cho nguồn phụ của FR-QRY-001.
    ///
    /// Chỉ chữ ASCII, số và gạch dưới, không bắt đầu bằng số, và không trùng `t`. Chặt hơn SQL
    /// cho phép, và cố ý: tên bảng ở đây suy ra từ **tên file** của người dùng, tức từ một chuỗi
    /// ta không kiểm soát. Bọc trong dấu nháy kép rồi cho qua mọi thứ là mời một tên file có dấu
    /// nháy vào giữa câu SQL — và tên file thì đặt được tuỳ ý.
    public static func isValidTableName(_ name: String) -> Bool {
        guard let first = name.first, first.isASCII, first.isLetter || first == "_" else {
            return false
        }
        return name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
            && name.lowercased() != tableName
    }

    public static func run(
        _ sql: String,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        sourcePath: String? = nil,
        extraSources: [String: String] = [:],
        cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        try execute(
            sql, in: buffer, dialect: dialect, sourcePath: sourcePath,
            extraSources: extraSources, cancelToken: cancelToken, inspectOnly: false)
    }

    /// Số hiệu hàng (1-based, không tính dòng tiêu đề) của những hàng khớp `predicate`.
    ///
    /// Dùng cho FR-DQR-001: *"click rule → Mark và nhảy tới các dòng vi phạm"*. Đếm thôi không
    /// đủ — người dùng cần tới được chỗ sai.
    ///
    /// ## `parallel = false` không phải tuỳ chọn, nó là điều kiện ĐÚNG
    ///
    /// DuckDB đọc CSV song song, và khi ấy `row_number() OVER ()` **không bảo đảm** theo thứ tự
    /// file — nó theo thứ tự các mảnh chạy xong. Số hàng sai nghĩa là Mark rơi nhầm dòng và
    /// người dùng đi sửa một hàng không có lỗi: sai trong im lặng, đúng loại hỏng nguy hiểm
    /// nhất của sản phẩm này.
    ///
    /// Bản DuckDB ở đây chưa có `file_row_number`, nên quét tuần tự là cách duy nhất còn lại.
    /// Cái giá chấp nhận được vì câu này chỉ chạy khi người dùng BẤM vào một luật, và nó có
    /// `LIMIT`: không ai duyệt tay một triệu dòng vi phạm.
    /// - Parameter extraProjection: cột phụ tính trong CÙNG lượt quét, ví dụ
    ///   `COUNT(*) OVER (PARTITION BY "ma") AS __dup`. Có mặt để luật `unique` hỏi được "giá
    ///   trị này có lặp không" mà **không phải đọc lại file** — đọc lại đòi biết đường dẫn
    ///   nguồn, mà tài liệu chưa lưu thì không có đường dẫn nào.
    public static func rowNumbers(
        matching predicate: String,
        extraProjection: String? = nil,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        sourcePath: String? = nil,
        limit: Int = 500,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [Int] {
        let source = try Source(buffer: buffer, sourcePath: sourcePath)
        defer { source.cleanUp() }
        let connection: DuckDB.Connection
        do {
            connection = try DuckDB.connect()
        } catch {
            throw Failure.unavailable(String(describing: error))
        }
        let escaped = source.path.replacingOccurrences(of: "'", with: "''")
        let delimiter = String(UnicodeScalar(dialect.delimiter))
            .replacingOccurrences(of: "'", with: "''")
        let extra = extraProjection.map { ", " + $0 } ?? ""
        let sql = """
            SELECT __rn FROM (
              SELECT row_number() OVER () AS __rn\(extra), *
              FROM read_csv('\(escaped)', header = true, delim = '\(delimiter)',
                            parallel = false)
            ) WHERE \(predicate) LIMIT \(max(1, limit))
            """
        do {
            let table = try connection.query(sql)
            return table.rows.compactMap { $0.first.flatMap { $0.flatMap(Int.init) } }
        } catch DuckDB.Failure.query(let message) {
            throw Failure.query(DuckDBErrorText.vietnamese(message).text)
        }
    }

    // MARK: - Bên trong

    private static func execute(
        _ sql: String, in buffer: TextBuffer, dialect: CSVDialect,
        sourcePath: String?, extraSources: [String: String] = [:],
        cancelToken: CancelToken, inspectOnly: Bool
    ) throws -> Result {
        let source = try Source(buffer: buffer, sourcePath: sourcePath)
        defer { source.cleanUp() }

        let connection: DuckDB.Connection
        do {
            connection = try DuckDB.connect()
        } catch DuckDB.Failure.unavailable(let why) {
            throw Failure.unavailable(why)
        } catch {
            throw Failure.unavailable(String(describing: error))
        }

        // Một luồng canh nút Hủy. Nó CHỈ sống trong lúc câu truy vấn đang chạy — không phải
        // vòng hỏi nền, nên không đụng NFR-PERF-07. Cần nó vì `CancelToken` là kiểu HỎI
        // (`isCancelled`) chứ không gọi lại, còn `duckdb_interrupt` thì phải được gọi từ luồng
        // khác trong lúc truy vấn đang chiếm luồng này.
        let finished = NSLock()
        var done = false
        if !cancelToken.isCancelled {
            Thread.detachNewThread { [weak connection] in
                while true {
                    Thread.sleep(forTimeInterval: 0.05)   // NFR-QRY-01 đòi hủy ≤ 200 ms
                    finished.lock()
                    let stop = done
                    finished.unlock()
                    if stop { return }
                    if cancelToken.isCancelled {
                        connection?.interrupt()
                        return
                    }
                }
            }
        }
        defer {
            finished.lock()
            done = true
            finished.unlock()
        }

        do {
            _ = try connection.query(source.createViewSQL(dialect: dialect))
        } catch DuckDB.Failure.query(let message) {
            // Lỗi ở bước này KHÔNG phải lỗi câu người dùng gõ — nó là lỗi đọc file CSV (dấu
            // phân tách sai, file rỗng, dòng tiêu đề trùng tên cột). Nói nguyên văn vẫn tốt
            // hơn nuốt đi, nhưng đừng để nó trông như lỗi cú pháp SQL.
            throw Failure.query(
                "Không đọc được bảng CSV: " + DuckDBErrorText.vietnamese(message).text)
        }

        // Nguồn PHỤ của FR-QRY-001: mỗi file thêm là một view nữa trong cùng phiên, nên một câu
        // `JOIN` giữa chúng chạy được mà không phải viết `read_csv('…')` bằng tay.
        //
        // Đăng ký theo thứ tự TÊN chứ không theo thứ tự từ điển trả về: `Dictionary` không có
        // thứ tự, và một câu lỗi chỉ vào "nguồn thứ hai" sẽ chỉ vào nguồn khác nhau mỗi lần chạy.
        for (name, path) in extraSources.sorted(by: { $0.key < $1.key }) {
            guard isValidTableName(name) else {
                throw Failure.query(
                    "Tên bảng «\(name)» không hợp lệ — chỉ chữ không dấu, số và gạch dưới, "
                        + "và không được trùng «\(tableName)».")
            }
            let escaped = path.replacingOccurrences(of: "'", with: "''")
            do {
                _ = try connection.query("""
                    CREATE OR REPLACE VIEW "\(name)" AS
                    SELECT * FROM \(readerCall(for: path, escaped: escaped))
                    """)
            } catch DuckDB.Failure.query(let message) {
                // Nói TÊN NGUỒN. Không có nó thì người dùng đăng ký năm file và nhận một câu
                // lỗi về "file không đọc được" mà không biết file nào.
                throw Failure.query("Không đọc được nguồn «\(name)»: "
                    + DuckDBErrorText.vietnamese(message).text)
            }
        }

        // HÀNG RÀO CHỈ-ĐỌC. Chạy TRƯỚC mọi lần thực thi, kể cả khi `run` được gọi thẳng —
        // đây là chỗ duy nhất, nên không có đường vòng nào bỏ qua nó được.
        let inspection: DuckDB.Inspection
        do {
            inspection = try connection.inspect(sql)
        } catch DuckDB.Failure.query(let message) {
            throw Failure.query(DuckDBErrorText.vietnamese(message).text)
        }
        guard inspection.statementCount == 1 else {
            throw Failure.multipleStatements(inspection.statementCount)
        }
        guard inspection.isSelect else { throw Failure.notReadOnly }
        if inspectOnly {
            return Result(titles: [], rows: [], milliseconds: 0)
        }

        let started = DispatchTime.now().uptimeNanoseconds
        do {
            let table = try connection.query(sql)
            let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            return Result(titles: table.titles, rows: table.rows, milliseconds: milliseconds)
        } catch DuckDB.Failure.cancelled {
            throw Failure.cancelled
        } catch DuckDB.Failure.query(let message) {
            // Người dùng bấm Hủy thì DuckDB báo lỗi ngắt; nếu token đã bật thì đừng đổ lỗi cho
            // câu truy vấn.
            throw cancelToken.isCancelled
                ? Failure.cancelled
                : Failure.query(DuckDBErrorText.vietnamese(message).text)
        }
    }

    /// Nguồn dữ liệu cho DuckDB — hoặc file gốc, hoặc một file tạm chép từ buffer.
    private struct Source {
        let path: String
        private let temporary: Bool

        init(buffer: TextBuffer, sourcePath: String?) throws {
            // Đường nhanh: file trên đĩa đã CHÍNH LÀ nội dung buffer.
            //
            // So bằng SỐ BYTE chứ không tin `isModified` của tầng trên: hàm này ở lõi và không
            // biết tầng trên có gọi đúng hay không, mà đoán sai ở đây nghĩa là truy vấn chạy
            // trên một phiên bản dữ liệu KHÁC thứ người dùng đang nhìn — sai trong im lặng,
            // đúng loại hỏng nguy hiểm nhất của sản phẩm này.
            if let sourcePath,
               let size = try? FileManager.default
                   .attributesOfItem(atPath: sourcePath)[.size] as? Int,
               size == buffer.count {
                self.path = sourcePath
                self.temporary = false
                return
            }

            let bytes = buffer.count
            guard bytes <= CSVQueryEngine.materializationLimit else {
                throw Failure.tooLargeToMaterialize(
                    bytes: bytes, limit: CSVQueryEngine.materializationLimit)
            }
            let temporaryPath = NSTemporaryDirectory()
                + "/geditor-query-\(UUID().uuidString).csv"
            try Data(buffer.bytes(in: 0 ..< bytes)).write(to: URL(fileURLWithPath: temporaryPath))
            self.path = temporaryPath
            self.temporary = true
        }

        func cleanUp() {
            if temporary { try? FileManager.default.removeItem(atPath: path) }
        }

        func createViewSQL(dialect: CSVDialect) -> String {
            let escaped = path.replacingOccurrences(of: "'", with: "''")
            let delimiter = String(UnicodeScalar(dialect.delimiter))
                .replacingOccurrences(of: "'", with: "''")
            // Để DuckDB TỰ SUY KIỂU. Engine cũ đọc mọi ô thành chuỗi rồi mới thử đổi sang số
            // khi so sánh; đó là lý do nó không làm nổi `BETWEEN` và `range`. Suy kiểu ở tầng
            // đọc là thứ khiến FR-DQR-001 khả thi.
            return """
                CREATE OR REPLACE VIEW \(CSVQueryEngine.tableName) AS
                SELECT * FROM read_csv('\(escaped)', header = true, delim = '\(delimiter)')
                """
        }
    }
}
