import Foundation

/// Trùng lặp mờ trên một cột CSV — FR-CLN-004.
///
/// ## Nó KHÔNG bao giờ tự gộp
///
/// Đặc tả viết thẳng: *"người dùng duyệt gộp/giữ qua khuôn diff; **không bao giờ tự merge**"*.
/// Kiểu ở đây phản ánh đúng điều ấy — nó chỉ trả về **đề xuất**, và phép sửa duy nhất nó sinh ra
/// (`edits(applying:)`) đòi một `Decision` cho từng cụm. Không có đường tắt "gộp hết".
///
/// Đó không phải sự thận trọng thừa. Hai chuỗi giống nhau 92% có thể là một lỗi gõ, mà cũng có
/// thể là hai công ty thật khác nhau đúng một chữ — và máy không phân biệt được. Gộp nhầm hai
/// bản ghi là mất dữ liệu **im lặng**: không có ô nào trống đi, không có dòng nào đỏ lên, chỉ có
/// hai thực thể hoá thành một và không ai biết cho tới khi đối chiếu sổ sách.
///
/// ## Thuật toán dùng chung, không viết lại
///
/// Gom cụm đi qua `TextDistance.clusters` — đúng hàm mà FR-KNW-923 (gom biến thể entity) và
/// FR-KNW-924 (nhãn node trùng gần) dùng. Dự án này đã gặp mẫu "hai bản của một thuật toán" ba
/// lần và mỗi lần hai bản cho hai con số khác nhau trên cùng dữ liệu; xem ghi chú đầu
/// `TextDistance`.
public enum CSVFuzzyDedup {

    /// Ngưỡng tương đồng mặc định.
    ///
    /// 0,86 chọn bằng cách thử trên dữ liệu tiếng Việt thật, không phải bằng cách chọn một số
    /// tròn: dưới 0,80 thì «Công ty A» và «Công ty B» bắt đầu dính nhau — chúng chỉ khác một ký
    /// tự trên chín — còn trên 0,90 thì «Nguyễn Văn Aa» và «Nguyen Van A» rời nhau, mà đó đúng
    /// là ca cần bắt.
    public static let defaultThreshold = 0.86

    /// Viết tắt phổ biến, quy về dạng đầy đủ TRƯỚC khi so.
    ///
    /// Đặc tả đòi vế này (*"viết tắt phổ biến"*), và nó không thay được bằng khoảng cách chuỗi:
    /// «Cty TNHH An Phát» và «Công ty TNHH An Phát» lệch nhau 5 ký tự trên 20 — trượt mọi ngưỡng
    /// hợp lý — trong khi chúng hiển nhiên là một.
    ///
    /// Bảng này CỐ Ý NGẮN và chỉ chứa những dạng không mơ hồ trong dữ liệu doanh nghiệp Việt.
    /// Thêm một dòng vào đây là một quyết định có hệ quả: mỗi phép quy đổi là một cách hai bản
    /// ghi KHÁC NHAU bị kéo lại gần nhau. Không thêm dạng nào có thể là tên riêng.
    public static let abbreviations: [String: String] = [
        "cty": "cong ty",
        "c.ty": "cong ty",
        "cp": "co phan",
        "tnhh mtv": "tnhh mot thanh vien",
        "dn": "doanh nghiep",
        "tp": "thanh pho",
        "q": "quan",
        "p": "phuong",
        "tt": "thi tran",
        "h": "huyen",
        "x": "xa",
        "đ": "duong",
        "kcn": "khu cong nghiep",
    ]

    /// Chuẩn hoá đầy đủ cho phép so: `TextDistance.normalize` cộng bảng viết tắt.
    ///
    /// Chỉ đổi khi viết tắt đứng thành TỪ RIÊNG. Thay theo chuỗi con sẽ biến «Quang» thành
    /// «Quanuang» — và loại lỗi ấy chỉ lộ ra ở dữ liệu thật, không lộ ở bài kiểm ai cũng nghĩ ra.
    public static func normalize(_ text: String) -> String {
        TextDistance.normalize(text)
            .split(separator: " ")
            .map { abbreviations[String($0)] ?? String($0) }
            .joined(separator: " ")
    }

    /// Một cụm ứng viên: những hàng mà cột đang xét gần nhau.
    public struct Cluster: Sendable {
        /// Chỉ số hàng trong tài liệu (0-based, tính cả dòng tiêu đề).
        public let rowIndices: [Int]
        /// Giá trị nguyên văn của từng hàng, cùng thứ tự với `rowIndices`.
        public let values: [String]
        /// Điểm tương đồng THẤP NHẤT trong cụm — cụm gom bắc cầu nên đây là cận dưới thật.
        ///
        /// Hiện cận dưới chứ không hiện trung bình: người duyệt cần biết cặp XA NHẤT trong cụm
        /// gần nhau tới đâu, vì đó mới là cặp có thể sai.
        public let lowestSimilarity: Double
        /// Giá trị được đề nghị giữ — nhưng chỉ là ĐỀ NGHỊ, `Decision` mới quyết.
        public let suggested: String

        public var count: Int { rowIndices.count }
    }

    /// Người dùng quyết gì với một cụm.
    public enum Decision: Equatable, Sendable {
        /// Giữ nguyên, không đụng vào.
        case keep
        /// Đổi mọi hàng trong cụm về giá trị này.
        case unify(to: String)
    }

    /// Tìm cụm ứng viên trên một cột.
    ///
    /// - Parameter maxRows: 0 = cả tài liệu.
    public static func scan(
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        threshold: Double = defaultThreshold,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [Cluster] {
        var values: [String] = []
        var rows: [Int] = []
        var rowNumber = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }
            if hasHeader, rowNumber == 0 { return true }
            guard column < row.count else { return maxRows <= 0 || values.count < maxRows }
            let raw = o(row[column], in: buffer, dialect: dialect)
            // Ô TRỐNG không phải "trùng mờ" với nhau — chúng là việc của FR-CLN-002 (ô thiếu).
            // Gom chúng vào đây sẽ đẻ ra một cụm khổng lồ nuốt mọi cụm thật.
            if !raw.trimmingCharacters(in: .whitespaces).isEmpty {
                values.append(raw)
                rows.append(rowNumber)
            }
            return maxRows <= 0 || values.count < maxRows
        }

        // Gom theo giá trị đã quy viết tắt, nhưng GIỮ nguyên văn để hiện cho người duyệt: người
        // ta duyệt thứ họ thấy trong file, không duyệt dạng chuẩn hoá nội bộ.
        let keys = values.map { normalize($0) }
        let groups = TextDistance.clusters(keys, threshold: threshold, cancelToken: cancelToken)

        return groups.compactMap { group -> Cluster? in
            guard group.count > 1 else { return nil }
            let cum = group.map { values[$0] }
            // Cận dưới thật của cụm: cặp xa nhau nhất.
            var thap = 1.0
            for i in 0 ..< group.count {
                for j in (i + 1) ..< group.count {
                    thap = min(thap, TextDistance.similarity(keys[group[i]], keys[group[j]],
                                                             threshold: 0))
                }
            }
            return Cluster(
                rowIndices: group.map { rows[$0] },
                values: cum,
                lowestSimilarity: thap,
                suggested: deNghi(cum)
            )
        }
    }

    /// Đọc một ô thành chuỗi — cùng cách `CSVCleanScanner` làm, đi qua `unescape`.
    static func o(_ field: CSVField, in buffer: TextBuffer, dialect: CSVDialect) -> String {
        String(decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
               as: UTF8.self)
    }

    /// Giá trị đề nghị giữ: dạng PHỔ BIẾN NHẤT, hoà thì lấy dạng DÀI NHẤT.
    ///
    /// Dài nhất khi hoà là có lý do: giữa «Cty An Phát» và «Công ty An Phát», bản dài hơn gần
    /// như luôn là bản đầy đủ hơn — viết tắt là thứ người ta gõ khi vội, không phải thứ người ta
    /// gõ thêm vào. Hoà cả độ dài thì lấy bản đứng trước, để kết quả TẤT ĐỊNH.
    static func deNghi(_ values: [String]) -> String {
        var dem: [String: Int] = [:]
        for v in values { dem[v, default: 0] += 1 }
        return values.max { a, b in
            let (da, db) = (dem[a] ?? 0, dem[b] ?? 0)
            if da != db { return da < db }
            if a.count != b.count { return a.count < b.count }
            return (values.firstIndex(of: a) ?? 0) > (values.firstIndex(of: b) ?? 0)
        } ?? values[0]
    }

    /// Sửa đổi cần áp, theo đúng quyết định của người dùng cho từng cụm.
    ///
    /// Trả về mảng RỖNG khi mọi cụm đều `.keep` — và chỗ gọi phải coi mảng rỗng là "không có gì
    /// để làm", không phải "đã xong". Đó là cách duy nhất bất biến "không bao giờ tự merge" sống
    /// được qua tầng giao diện.
    public static func edits(
        applying decisions: [Int: Decision],
        to clusters: [Cluster],
        column: Int,
        in buffer: TextBuffer,
        dialect: CSVDialect
    ) throws -> [TextEdit] {
        var muc_tieu: [Int: String] = [:]     // hàng → giá trị mới
        for (index, cluster) in clusters.enumerated() {
            guard case let .unify(to: dich) = decisions[index] ?? .keep else { continue }
            for (row, hien) in zip(cluster.rowIndices, cluster.values) where hien != dich {
                muc_tieu[row] = dich
            }
        }
        guard !muc_tieu.isEmpty else { return [] }

        var edits: [TextEdit] = []
        var rowNumber = 0
        try CSVEngine.forEachRow(in: buffer, dialect: dialect) { row in
            defer { rowNumber += 1 }
            guard let moi = muc_tieu[rowNumber], column < row.count else { return true }
            let field = row[column]
            edits.append(TextEdit(range: field.range,
                                  text: CSVEngine.escape(moi, dialect: dialect)))
            return true
        }
        return edits
    }
}
