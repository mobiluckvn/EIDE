import Darwin
import Foundation

/// Lớp bọc HẸP quanh DuckDB — chỗ duy nhất trong sản phẩm chạm vào thư viện ấy (ADR-14).
///
/// Cùng khuôn với `LibXML2`: gọi qua `dlsym` chứ không `import` một module. `import` bắt liên
/// kết lúc dựng, và khi ấy thiếu thư viện là app **không khởi động nổi**; ở đây "không có
/// DuckDB" là một giá trị (`nil`) chứ không phải một tai nạn. Với một dylib 94 MB nằm trong
/// bundle, khác biệt ấy là khác biệt giữa "tính năng truy vấn báo lỗi" và "app không mở được".
///
/// Nạp LƯỜI cũng là bất biến của ADR-14 §4: `dlopen` chỉ chạy ở lần truy vấn đầu tiên, và cổng
/// `LazyLoadAudit` hỏi thẳng nhân để chắc rằng lúc khởi động nó chưa nằm trong tiến trình.
///
/// ## Vì sao kết quả là `String?` chứ không phải kiểu đã phân loại
///
/// DuckDB biết kiểu của từng cột, nhưng tầng trên của GEditor là một trình soạn thảo văn bản:
/// thứ nó cần hiện ra là chữ. Đổi mọi ô sang `String` ngay tại đây giữ bề mặt hẹp và tránh
/// dựng một cây kiểu song song với kiểu của DuckDB. `nil` dành riêng cho `NULL` — phân biệt
/// được với chuỗi rỗng, vì trong dữ liệu thật hai thứ ấy khác nhau.
public final class DuckDB {

    /// Nơi tìm dylib, theo thứ tự. Đổi phương án đóng gói về sau chỉ cần thêm một đường dẫn
    /// vào đây — không chạm chỗ gọi nào (bài học `XMLSchemaValidator.libraryCandidates`).
    public static var libraryCandidates: [String] = {
        var paths: [String] = []
        // 1. Ép bằng biến môi trường — dùng cho CI và cho lúc thử một phiên bản khác.
        if let forced = ProcessInfo.processInfo.environment["GEDITOR_DUCKDB_DYLIB"] {
            paths.append(forced)
        }
        // 2. Trong bundle đã ký. Đây là đường của bản phát hành: dylib nằm trong
        //    `Contents/Frameworks` và ký cùng bundle, nên không cần
        //    `disable-library-validation` (xem hai tệp entitlement).
        if let frameworks = Bundle.main.privateFrameworksPath {
            paths.append(frameworks + "/libduckdb.dylib")
        }
        // 3. Cây làm việc — để `swift test` và bộ đo chạy được mà không cần dựng bundle.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CSV
            .deletingLastPathComponent()   // GEditorCore
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // gốc kho
        paths.append(root.appendingPathComponent("vendor/duckdb/libduckdb.dylib").path)
        paths.append(root.appendingPathComponent(".build/poc-k/libduckdb.dylib").path)
        return paths
    }()

    /// `nil` khi máy không có DuckDB. Tính MỘT lần — `dlopen` tốn 6,9 ms (PoC-K), không có lý
    /// do làm lại, và một `static let` cũng bảo đảm chỉ có một handle cho cả tiến trình.
    public static let shared: DuckDB? = DuckDB()

    /// Vì sao không nạp được — để giao diện nói được câu tử tế thay vì im lặng.
    public private(set) static var failureReason: String?

    private let handle: UnsafeMutableRawPointer
    public let version: String

    // MARK: - Chữ ký C
    //
    // Bề mặt cố ý hẹp: đúng mười ba hàm, tất cả nằm trong tệp này, mỗi chữ ký viết ngay cạnh
    // chỗ dùng. Đó là cách bù lại phần kiểm kiểu mà `dlsym` lấy mất.

    private typealias OpenExt = @convention(c) (
        UnsafePointer<CChar>?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
    ) -> Int32
    private typealias Close = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias Connect = @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
    ) -> Int32
    private typealias Disconnect = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias Query = @convention(c) (
        UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?
    ) -> Int32
    private typealias DestroyResult = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias ResultError = @convention(c) (UnsafeMutableRawPointer?)
        -> UnsafePointer<CChar>?
    private typealias ColumnCount = @convention(c) (UnsafeMutableRawPointer?) -> UInt64
    private typealias RowCount = @convention(c) (UnsafeMutableRawPointer?) -> UInt64
    private typealias ColumnName = @convention(c) (UnsafeMutableRawPointer?, UInt64)
        -> UnsafePointer<CChar>?
    private typealias ValueVarchar = @convention(c) (UnsafeMutableRawPointer?, UInt64, UInt64)
        -> UnsafeMutablePointer<CChar>?
    private typealias Free = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias Interrupt = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias Prepare = @convention(c) (
        UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?
    ) -> Int32
    private typealias PrepareError = @convention(c) (UnsafeMutableRawPointer?)
        -> UnsafePointer<CChar>?
    private typealias DestroyPrepare = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias StatementType = @convention(c) (UnsafeMutableRawPointer?) -> Int32
    private typealias ExtractStatements = @convention(c) (
        UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?
    ) -> UInt64
    private typealias ExtractError = @convention(c) (UnsafeMutableRawPointer?)
        -> UnsafePointer<CChar>?
    private typealias DestroyExtracted = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias LibraryVersion = @convention(c) () -> UnsafePointer<CChar>?

    private let openExt: OpenExt
    private let closeDB: Close
    private let connectDB: Connect
    private let disconnectDB: Disconnect
    private let runQuery: Query
    private let destroyResult: DestroyResult
    private let resultError: ResultError
    private let columnCount: ColumnCount
    private let rowCount: RowCount
    private let columnName: ColumnName
    private let valueVarchar: ValueVarchar
    private let freePointer: Free
    private let interruptConnection: Interrupt
    private let prepareStatement: Prepare
    private let prepareErrorText: PrepareError
    private let destroyPrepared: DestroyPrepare
    private let statementType: StatementType
    private let extractStatements: ExtractStatements
    private let extractErrorText: ExtractError
    private let destroyExtracted: DestroyExtracted

    private init?() {
        var opened: UnsafeMutableRawPointer?
        var tried: [String] = []
        for path in DuckDB.libraryCandidates {
            tried.append(path)
            if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) {
                opened = handle
                break
            }
        }
        guard let handle = opened else {
            DuckDB.failureReason = "không nạp được libduckdb.dylib — đã thử: "
                + tried.joined(separator: ", ")
            return nil
        }

        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let raw = dlsym(handle, name) else { return nil }
            return unsafeBitCast(raw, to: type)
        }
        guard let openExt = symbol("duckdb_open_ext", as: OpenExt.self),
              let closeDB = symbol("duckdb_close", as: Close.self),
              let connectDB = symbol("duckdb_connect", as: Connect.self),
              let disconnectDB = symbol("duckdb_disconnect", as: Disconnect.self),
              let runQuery = symbol("duckdb_query", as: Query.self),
              let destroyResult = symbol("duckdb_destroy_result", as: DestroyResult.self),
              let resultError = symbol("duckdb_result_error", as: ResultError.self),
              let columnCount = symbol("duckdb_column_count", as: ColumnCount.self),
              let rowCount = symbol("duckdb_row_count", as: RowCount.self),
              let columnName = symbol("duckdb_column_name", as: ColumnName.self),
              let valueVarchar = symbol("duckdb_value_varchar", as: ValueVarchar.self),
              let freePointer = symbol("duckdb_free", as: Free.self),
              let interruptConnection = symbol("duckdb_interrupt", as: Interrupt.self),
              let prepareStatement = symbol("duckdb_prepare", as: Prepare.self),
              let prepareErrorText = symbol("duckdb_prepare_error", as: PrepareError.self),
              let destroyPrepared = symbol("duckdb_destroy_prepare", as: DestroyPrepare.self),
              let statementType = symbol("duckdb_prepared_statement_type", as: StatementType.self),
              let extractStatements = symbol("duckdb_extract_statements", as: ExtractStatements.self),
              let extractErrorText = symbol("duckdb_extract_statements_error", as: ExtractError.self),
              let destroyExtracted = symbol("duckdb_destroy_extracted", as: DestroyExtracted.self)
        else {
            dlclose(handle)
            DuckDB.failureReason = "libduckdb.dylib nạp được nhưng thiếu ký hiệu cần dùng"
            return nil
        }

        self.handle = handle
        self.openExt = openExt
        self.closeDB = closeDB
        self.connectDB = connectDB
        self.disconnectDB = disconnectDB
        self.runQuery = runQuery
        self.destroyResult = destroyResult
        self.resultError = resultError
        self.columnCount = columnCount
        self.rowCount = rowCount
        self.columnName = columnName
        self.valueVarchar = valueVarchar
        self.freePointer = freePointer
        self.interruptConnection = interruptConnection
        self.prepareStatement = prepareStatement
        self.prepareErrorText = prepareErrorText
        self.destroyPrepared = destroyPrepared
        self.statementType = statementType
        self.extractStatements = extractStatements
        self.extractErrorText = extractErrorText
        self.destroyExtracted = destroyExtracted
        self.version = symbol("duckdb_library_version", as: LibraryVersion.self)?()
            .map { String(cString: $0) } ?? "không rõ"
    }

    // MARK: - Lỗi

    public enum Failure: Error, Equatable, Sendable {
        /// Máy không có thư viện. Tách riêng khỏi `query` để giao diện nói được câu khác nhau:
        /// một bên là "máy này thiếu thứ gì đó", bên kia là "câu anh gõ có vấn đề".
        case unavailable(String)
        case openFailed(String)
        /// Lỗi của chính câu truy vấn — thông điệp nguyên văn từ DuckDB.
        case query(String)
        case cancelled
    }

    // MARK: - Phiên

    /// Một kết nối tới cơ sở dữ liệu TRONG BỘ NHỚ.
    ///
    /// Trong bộ nhớ chứ không phải file trên đĩa: mọi truy vấn của GEditor là chỉ-đọc trên dữ
    /// liệu người dùng (NFR-QRY-03), nên không có gì cần giữ lại giữa hai lần chạy. Một file
    /// `.duckdb` nằm cạnh dữ liệu sẽ là thứ người dùng không yêu cầu và không biết xoá.
    public final class Connection {
        private let owner: DuckDB
        private var database: UnsafeMutableRawPointer?
        private var connection: UnsafeMutableRawPointer?
        private let lock = NSLock()

        fileprivate init(owner: DuckDB) throws {
            self.owner = owner
            var db: UnsafeMutableRawPointer?
            var errorText: UnsafeMutablePointer<CChar>?
            let status = withUnsafeMutablePointer(to: &db) { dbPointer in
                owner.openExt(nil, UnsafeMutableRawPointer(dbPointer), nil, &errorText)
            }
            guard status == 0, db != nil else {
                let message = errorText.map { String(cString: $0) } ?? "không rõ"
                errorText.map { owner.freePointer(UnsafeMutableRawPointer($0)) }
                throw Failure.openFailed(message)
            }
            var con: UnsafeMutableRawPointer?
            let connected = withUnsafeMutablePointer(to: &con) { conPointer in
                owner.connectDB(db, UnsafeMutableRawPointer(conPointer))
            }
            guard connected == 0, con != nil else {
                owner.closeDB(&db)
                throw Failure.openFailed("duckdb_connect thất bại")
            }
            self.database = db
            self.connection = con
        }

        deinit {
            if connection != nil { owner.disconnectDB(&connection) }
            if database != nil { owner.closeDB(&database) }
        }

        /// Ngắt truy vấn đang chạy. An toàn khi gọi từ luồng khác — đó là lý do nó tồn tại.
        ///
        /// NFR-QRY-01 đòi hủy ≤ 200 ms. `duckdb_interrupt` là API chính thức cho việc ấy;
        /// không có nó thì "Hủy" chỉ bỏ qua kết quả trong khi một lõi CPU vẫn chạy tiếp — đúng
        /// thứ `ScriptRunner` đã phải nói thẳng ra là mình không làm được.
        public func interrupt() {
            lock.lock()
            defer { lock.unlock() }
            if let connection { owner.interruptConnection(connection) }
        }

        /// Phân tích và RÀNG BUỘC câu, nhưng KHÔNG chạy nó.
        ///
        /// Đây là hàng rào chỉ-đọc của NFR-QRY-03, và nó là hàng rào **cấu trúc** chứ không
        /// phải mẹo chuỗi. Bản đầu bọc câu người dùng vào `SELECT * FROM ( … ) LIMIT 0`: nó
        /// chặn đúng, nhưng chuỗi bọc **lọt vào thông báo lỗi** — người gõ `SELECT khong_co
        /// FROM t` lại đọc được `LINE 1: SELECT * FROM (SELECT khong_co FROM t` với dấu mũ chỉ
        /// lệch. Một hàng rào làm hỏng thông báo lỗi là một hàng rào phải thay.
        ///
        /// `duckdb_extract_statements` đếm số câu mà không chạy gì — cần nó vì `duckdb_query`
        /// chạy CẢ CHUỖI câu ngăn bởi dấu `;`, nên "chỉ cho SELECT" mà không chặn nhiều câu là
        /// để hở đúng `SELECT 1; COPY t TO '…'`.
        ///
        /// `duckdb_prepare` ràng buộc tên cột và kiểu — tức bắt được mọi lỗi mà lúc chạy sẽ
        /// bắt — nhưng không đọc một hàng dữ liệu nào, và lỗi trỏ vào ĐÚNG chuỗi người dùng gõ.
        public func inspect(_ sql: String) throws -> Inspection {
            var extracted: UnsafeMutableRawPointer?
            let count = sql.withCString { text in
                withUnsafeMutablePointer(to: &extracted) { slot in
                    owner.extractStatements(connection, text, UnsafeMutableRawPointer(slot))
                }
            }
            defer { if extracted != nil { owner.destroyExtracted(&extracted) } }
            if count == 0 {
                let message = owner.extractErrorText(extracted).map { String(cString: $0) }
                    ?? "không phân tích được câu truy vấn"
                throw Failure.query(message)
            }
            guard count == 1 else {
                return Inspection(statementCount: Int(count), isSelect: false)
            }

            var prepared: UnsafeMutableRawPointer?
            let status = sql.withCString { text in
                withUnsafeMutablePointer(to: &prepared) { slot in
                    owner.prepareStatement(connection, text, UnsafeMutableRawPointer(slot))
                }
            }
            defer { if prepared != nil { owner.destroyPrepared(&prepared) } }
            guard status == 0 else {
                let message = owner.prepareErrorText(prepared).map { String(cString: $0) }
                    ?? "câu truy vấn không hợp lệ"
                throw Failure.query(message)
            }
            // 1 = DUCKDB_STATEMENT_TYPE_SELECT (duckdb.h). Mọi giá trị khác — COPY, DROP,
            // INSTALL, CREATE… — đều là câu GHI hoặc câu đổi trạng thái.
            return Inspection(statementCount: 1, isSelect: owner.statementType(prepared) == 1)
        }

        /// Chạy một câu và trả về cả bảng.
        ///
        /// Vật chất hoá toàn bộ kết quả — hợp lý ở đây vì mọi câu của GEditor đều có `LIMIT`
        /// hoặc là một phép gộp; tầng trên chịu trách nhiệm không hỏi một tỉ hàng.
        public func query(_ sql: String) throws -> Table {
            // Cấp một vùng nhớ THÔ thay vì khai lại `duckdb_result` bằng struct Swift.
            //
            // Struct ấy có sáu trường và bố cục của nó là chi tiết nội bộ của DuckDB — khai lại
            // là ký một hợp đồng với thứ upstream không hứa giữ nguyên, và sai bố cục thì hỏng
            // theo kiểu ghi đè bộ nhớ chứ không phải theo kiểu báo lỗi. Ta không đọc trường nào
            // trực tiếp, chỉ chuyền con trỏ ấy lại cho DuckDB, nên không cần biết bố cục.
            let slot = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 16)
            slot.initializeMemory(as: UInt8.self, repeating: 0, count: 256)
            defer {
                owner.destroyResult(slot)
                slot.deallocate()
            }

            let status = sql.withCString { owner.runQuery(connection, $0, slot) }
            guard status == 0 else {
                let message = owner.resultError(slot).map { String(cString: $0) }
                    ?? "truy vấn thất bại"
                // DuckDB báo ngắt bằng chính đường lỗi. Đổi nó thành `.cancelled` ngay tại đây
                // để tầng trên không phải so chuỗi tiếng Anh của thư viện.
                if message.localizedCaseInsensitiveContains("interrupt") {
                    throw Failure.cancelled
                }
                throw Failure.query(message)
            }

            let columns = Int(owner.columnCount(slot))
            let rows = Int(owner.rowCount(slot))
            var titles: [String] = []
            titles.reserveCapacity(columns)
            for column in 0 ..< columns {
                titles.append(owner.columnName(slot, UInt64(column)).map { String(cString: $0) }
                    ?? "cot\(column + 1)")
            }
            var values: [[String?]] = []
            values.reserveCapacity(rows)
            for row in 0 ..< rows {
                var line: [String?] = []
                line.reserveCapacity(columns)
                for column in 0 ..< columns {
                    if let raw = owner.valueVarchar(slot, UInt64(column), UInt64(row)) {
                        line.append(String(cString: raw))
                        owner.freePointer(UnsafeMutableRawPointer(raw))
                    } else {
                        line.append(nil)   // NULL, khác hẳn chuỗi rỗng
                    }
                }
                values.append(line)
            }
            return Table(titles: titles, rows: values)
        }
    }

    /// Kết quả kiểm một câu TRƯỚC khi chạy nó.
    public struct Inspection: Equatable, Sendable {
        /// Số câu lệnh trong chuỗi. Phải là 1 — xem `Connection.inspect`.
        public var statementCount: Int
        /// `true` khi câu là một `SELECT` thuần.
        public var isSelect: Bool
    }

    public struct Table: Equatable, Sendable {
        public var titles: [String]
        public var rows: [[String?]]

        public init(titles: [String], rows: [[String?]]) {
            self.titles = titles
            self.rows = rows
        }
    }

    /// Mở một kết nối mới, hoặc ném `.unavailable` nếu máy không có thư viện.
    public static func connect() throws -> Connection {
        guard let library = shared else {
            throw Failure.unavailable(failureReason ?? "không có DuckDB")
        }
        return try Connection(owner: library)
    }

    /// Có dùng được không — để giao diện tắt mục menu thay vì để người dùng bấm vào chỗ hỏng.
    public static var isAvailable: Bool { shared != nil }
}
