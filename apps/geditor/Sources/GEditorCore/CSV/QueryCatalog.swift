import Foundation

/// Danh mục bảng ảo — FR-QRY-005.
///
/// Đặc tả: *"Đăng ký file trong workspace thành bảng ảo (tên bảng đặt được, mặc định theo tên
/// file); danh mục bảng hiển thị schema suy luận; join/union nhiều file trong một truy vấn;
/// catalog tự vô hiệu khi file đổi."*
///
/// ## "Tự vô hiệu khi file đổi" là vế quan trọng nhất
///
/// Một danh mục nhớ schema của `khach_hang.csv` từ sáng, rồi buổi chiều ai đó thêm một cột vào
/// file ấy: mọi câu truy vấn dựa trên danh mục cũ sẽ chạy trên một hình dung sai về dữ liệu —
/// hoặc tệ hơn, chạy đúng nhưng người dùng đọc kết quả theo cột cũ.
///
/// Nên mỗi bảng mang một **dấu vân** (cỡ file + thời điểm sửa). `isStale` so lại với đĩa, và
/// tầng trên hiện ra để người dùng thấy — chứ danh mục **không tự nạp lại trong im lặng**: nạp
/// lại giữa lúc người ta đang gõ nửa câu truy vấn là đổi ý nghĩa câu ấy mà không ai yêu cầu.
public struct QueryCatalog: Equatable, Sendable {

    public struct Column: Equatable, Sendable {
        public var name: String
        /// Kiểu DuckDB suy ra (`BIGINT`, `VARCHAR`, `DATE`…). Để HIỆN, không để quyết định.
        public var type: String

        public init(name: String, type: String) {
            self.name = name
            self.type = type
        }
    }

    /// Dấu vân của file tại lúc đăng ký.
    ///
    /// Cỡ **và** thời điểm sửa, không chỉ một trong hai. Chỉ so cỡ thì một lần sửa giữ nguyên
    /// độ dài — đổi `Huế` thành `Hue` trong một ô — lọt qua; chỉ so thời điểm thì một lần chép
    /// file giữ nguyên mtime cũng lọt. Đây đúng là cặp bẫy mà FR-DOC-309 đã gặp với `tail -f`:
    /// so cỡ không bắt được xoay vòng log, phải so cả inode.
    public struct Fingerprint: Equatable, Sendable {
        public var size: Int
        public var modified: Double

        public init(size: Int, modified: Double) {
            self.size = size
            self.modified = modified
        }

        public static func read(path: String) -> Fingerprint? {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = attributes[.size] as? Int
            else { return nil }
            let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            return Fingerprint(size: size, modified: modified)
        }
    }

    public struct Table: Equatable, Sendable {
        public var name: String
        public var path: String
        public var columns: [Column]
        public var fingerprint: Fingerprint?

        public init(
            name: String, path: String, columns: [Column] = [], fingerprint: Fingerprint? = nil
        ) {
            self.name = name
            self.path = path
            self.columns = columns
            self.fingerprint = fingerprint
        }

        /// File đã đổi kể từ lúc đăng ký chưa.
        ///
        /// File **biến mất** cũng tính là đổi: một bảng trỏ vào chỗ không còn gì là một bảng
        /// người dùng phải biết, không phải một bảng im lặng trả về lỗi lúc chạy.
        public var isStale: Bool {
            guard let fingerprint else { return false }
            guard let current = Fingerprint.read(path: path) else { return true }
            return current != fingerprint
        }
    }

    public private(set) var tables: [Table] = []

    public init() {}

    // MARK: - Đăng ký

    public enum Failure: Error, Equatable, Sendable {
        case invalidName(String)
        case duplicateName(String)
        case unreadable(String)

        public var message: String {
            switch self {
            case .invalidName(let name):
                return "Tên bảng «\(name)» không dùng được — chỉ chữ không dấu, số và gạch "
                    + "dưới, không bắt đầu bằng số, và không trùng «\(CSVQueryEngine.tableName)» "
                    + "(tên của tài liệu đang mở)."
            case .duplicateName(let name):
                return "Đã có bảng tên «\(name)» trong danh mục."
            case .unreadable(let path):
                return "Không đọc được \((path as NSString).lastPathComponent)."
            }
        }
    }

    /// Tên bảng mặc định suy từ tên file.
    ///
    /// Bỏ đuôi, đổi dấu cách và gạch ngang thành gạch dưới, bỏ dấu tiếng Việt, bỏ ký tự lạ. Tên
    /// không còn hợp lệ sau khi dọn thì trả `nil` — và tầng trên hỏi người dùng đặt tên, chứ
    /// không bịa ra `bang_1`. Một danh mục toàn `bang_1`, `bang_2` là một danh mục không tra
    /// được.
    public static func defaultName(forPath path: String) -> String? {
        let stem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        // `đ`/`Đ` phải đổi TRƯỚC khi gỡ dấu.
        //
        // `diacriticInsensitive` không đụng tới nó — trong Unicode `đ` là một CHỮ CÁI riêng
        // (U+0111), không phải `d` mang dấu. Nên nó rơi khỏi bộ lọc ASCII và `đơn hàng.csv`
        // thành `on_hang`: mất đúng chữ đầu, và mất trong im lặng. Nhánh dự phòng cũ chỉ cứu
        // trường hợp RỖNG, mà đây không rỗng — nó chỉ SAI.
        let deStroked = stem
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
        let folded = deStroked.folding(
            options: [.diacriticInsensitive], locale: Locale(identifier: "vi"))
        var cleaned = ""
        for character in folded {
            if character.isASCII, character.isLetter || character.isNumber {
                cleaned.append(character)
            } else if character == " " || character == "-" || character == "_" {
                cleaned.append("_")
            }
        }
        while cleaned.hasPrefix("_") { cleaned.removeFirst() }
        guard CSVQueryEngine.isValidTableName(cleaned) else { return nil }
        return cleaned
    }

    /// Thêm một bảng. Schema do `inferColumns` cung cấp — tách ra để kiểm được mà không cần
    /// DuckDB, và để tầng gọi quyết định có chịu chi phí đọc file hay không.
    public mutating func register(
        path: String, name: String, columns: [Column] = []
    ) throws {
        guard CSVQueryEngine.isValidTableName(name) else { throw Failure.invalidName(name) }
        guard !tables.contains(where: { $0.name == name }) else {
            throw Failure.duplicateName(name)
        }
        guard let fingerprint = Fingerprint.read(path: path) else {
            throw Failure.unreadable(path)
        }
        tables.append(Table(
            name: name, path: path, columns: columns, fingerprint: fingerprint))
        tables.sort { $0.name < $1.name }
    }

    public mutating func remove(name: String) {
        tables.removeAll { $0.name == name }
    }

    /// Cập nhật dấu vân và schema sau khi người dùng bấm nạp lại.
    public mutating func refresh(name: String, columns: [Column]) {
        guard let index = tables.firstIndex(where: { $0.name == name }) else { return }
        tables[index].columns = columns
        tables[index].fingerprint = Fingerprint.read(path: tables[index].path)
    }

    /// Dạng mà `CSVQueryEngine.run(extraSources:)` nhận.
    public var sources: [String: String] {
        Dictionary(uniqueKeysWithValues: tables.map { ($0.name, $0.path) })
    }

    public var staleTables: [Table] { tables.filter(\.isStale) }

    // MARK: - Suy schema

    /// Câu SQL hỏi DuckDB schema của một nguồn, KHÔNG đọc hàng nào.
    ///
    /// `DESCRIBE` bọc trong `SELECT * FROM (…)` vì hàng rào chỉ-đọc của `CSVQueryEngine` chỉ
    /// cho chạy câu `SELECT` — và bọc lại là đúng, không phải là lách: kết quả vẫn chỉ đọc.
    public static func describeSQL(forPath path: String) -> String {
        let escaped = path.replacingOccurrences(of: "'", with: "''")
        return "SELECT * FROM (DESCRIBE SELECT * FROM "
            + CSVQueryEngine.readerCall(for: path, escaped: escaped) + ")"
    }

    /// Đọc kết quả `DESCRIBE` thành danh sách cột.
    public static func columns(fromDescribe result: CSVQueryEngine.Result) -> [Column] {
        guard let nameIndex = result.titles.firstIndex(of: "column_name"),
              let typeIndex = result.titles.firstIndex(of: "column_type")
        else { return [] }
        return result.rows.compactMap { row in
            guard nameIndex < row.count, let name = row[nameIndex] else { return nil }
            let type = typeIndex < row.count ? (row[typeIndex] ?? "") : ""
            return Column(name: name, type: type)
        }
    }
}
