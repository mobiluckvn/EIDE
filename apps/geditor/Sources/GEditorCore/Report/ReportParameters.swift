import Foundation

/// Tham số của báo cáo — FR-RPT-004.
///
/// Đặc tả: *"Tham số :param dùng trong mọi block query, khai báo ở frontmatter (kiểu, mặc định);
/// hộp nhập tham số khi chạy từ UI; CLI: `geditor --report bao_cao.greport.md --param
/// thang=2026-08 --out bc_t8.html`."*
///
/// ## Không giải lại bài toán bọc giá trị
///
/// `QueryParameters.substitute` đã bọc giá trị thành literal SQL — một dấu nháy trong giá trị
/// không phá được câu truy vấn. Phần này chỉ lo **khai báo** (kiểu, mặc định, nhãn) và **thứ tự
/// ưu tiên** của các nguồn giá trị. Việc thay chuỗi vẫn đi qua đúng hàm mà Query Workbench dùng,
/// nên một câu chạy đúng trong Workbench thì chạy đúng trong báo cáo.
///
/// ## Thứ tự ưu tiên, và vì sao nó phải rõ ràng
///
/// Cùng một tham số có thể đến từ ba chỗ: mặc định trong frontmatter, ô nhập trên giao diện, và
/// `--param` trên dòng lệnh. **Dòng lệnh thắng, rồi tới giá trị người dùng nhập, cuối cùng mới
/// tới mặc định.**
///
/// Thứ tự ngược lại nghe cũng hợp lý ("tài liệu biết rõ nhất") nhưng nó phá đúng thứ FR-RPT-006
/// cần: sinh loạt báo cáo, mỗi bộ tham số một tệp. Nếu mặc định trong tệp thắng thì cả loạt cho
/// ra cùng một báo cáo, và nó cho ra trong im lặng.
public struct ReportParameter: Equatable, Sendable {

    public enum Kind: String, Equatable, Sendable {
        case string, number, date

        /// Suy kiểu từ giá trị mặc định khi người dùng không khai.
        ///
        /// Dạng khai gọn `thang: "2026-08"` phổ biến hơn dạng đầy đủ nhiều lần, nên nó phải
        /// chạy được mà không bắt ai học thêm cú pháp.
        static func inferred(from value: YAMLValue) -> Kind {
            if value.doubleValue != nil { return .number }
            let text = value.stringValue ?? ""
            // `2026-08` và `2026-08-15` — đủ để hiện ô chọn ngày thay vì ô chữ.
            if text.range(of: "^\\d{4}-\\d{2}(-\\d{2})?$", options: .regularExpression) != nil {
                return .date
            }
            return .string
        }
    }

    public var name: String
    public var kind: Kind
    public var defaultValue: String
    /// Nhãn hiện trên ô nhập. Rỗng thì dùng chính tên tham số.
    public var label: String

    public init(name: String, kind: Kind, defaultValue: String, label: String = "") {
        self.name = name
        self.kind = kind
        self.defaultValue = defaultValue
        self.label = label
    }

    public var displayLabel: String { label.isEmpty ? name : label }
}

public enum ReportParameters {

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Đọc khai báo từ frontmatter. Không có khoá `params` thì trả về rỗng — hợp lệ.
    ///
    /// Hai dạng khai đều nhận:
    /// ```yaml
    /// params:
    ///   thang: "2026-08"                 # gọn — kiểu suy từ giá trị
    ///   nguong:                          # đầy đủ
    ///     type: number
    ///     default: 1000
    ///     label: Ngưỡng doanh thu
    /// ```
    public static func declared(in frontmatter: YAMLValue?) throws -> [ReportParameter] {
        guard let params = frontmatter?["params"] else { return [] }
        var out: [ReportParameter] = []
        for name in params.mappingKeys {
            guard let entry = params[name] else { continue }
            guard !name.isEmpty else { continue }

            if let type = entry["type"]?.stringValue {
                guard let kind = ReportParameter.Kind(rawValue: type.lowercased()) else {
                    throw Failure(message: "tham số «\(name)» khai kiểu «\(type)» không hiểu — "
                        + "chỉ có string, number, date")
                }
                out.append(ReportParameter(
                    name: name, kind: kind,
                    defaultValue: entry["default"].map(text(of:)) ?? "",
                    label: entry["label"]?.stringValue ?? ""))
            } else if entry["default"] != nil || entry["label"] != nil {
                // Khai dạng ánh xạ nhưng thiếu `type` — suy từ `default`.
                let fallback = entry["default"] ?? .null
                out.append(ReportParameter(
                    name: name, kind: ReportParameter.Kind.inferred(from: fallback),
                    defaultValue: text(of: fallback),
                    label: entry["label"]?.stringValue ?? ""))
            } else {
                out.append(ReportParameter(
                    name: name, kind: ReportParameter.Kind.inferred(from: entry),
                    defaultValue: text(of: entry)))
            }
        }
        return out
    }

    /// Ghép ba nguồn giá trị theo đúng thứ tự ưu tiên. Xem ghi chú đầu tệp.
    public static func resolve(
        declared: [ReportParameter], supplied: [String: String], overrides: [String: String] = [:]
    ) -> [String: String] {
        var values: [String: String] = [:]
        for parameter in declared where !parameter.defaultValue.isEmpty {
            values[parameter.name] = parameter.defaultValue
        }
        for (key, value) in supplied where !value.isEmpty { values[key] = value }
        for (key, value) in overrides where !value.isEmpty { values[key] = value }
        return values
    }

    /// Tham số dùng trong tài liệu mà không có giá trị nào.
    ///
    /// Quét MỌI khối `query`, không chỉ khối đầu — một báo cáo hay có năm câu truy vấn dùng
    /// chung một `:thang`, và thiếu giá trị thì cả năm hỏng chứ không chỉ một.
    public static func missing(
        in document: ReportDocument, values: [String: String]
    ) -> [String] {
        var found: [String] = []
        var seen: Set<String> = []
        for block in document.blocks where block.kind == .query {
            for name in QueryParameters.missing(in: block.content, values: values)
            where !seen.contains(name) {
                seen.insert(name)
                found.append(name)
            }
        }
        return found
    }

    /// Đọc `--param ten=gia_tri` của dòng lệnh.
    ///
    /// Chỉ tách ở dấu `=` ĐẦU TIÊN: một giá trị hoàn toàn có thể chứa dấu bằng
    /// (`--param loc=a=b`), và tách ở mọi dấu bằng sẽ cắt mất phần đuôi trong im lặng.
    public static func parseArgument(_ argument: String) throws -> (String, String) {
        guard let separator = argument.firstIndex(of: "=") else {
            throw Failure(message: "«\(argument)» thiếu dấu = — dạng đúng là ten=gia_tri")
        }
        let name = String(argument[argument.startIndex ..< separator])
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            throw Failure(message: "«\(argument)» thiếu tên tham số trước dấu =")
        }
        return (name, String(argument[argument.index(after: separator)...]))
    }

    /// Giá trị YAML về dạng chuỗi để đưa vào SQL.
    ///
    /// Số nguyên in KHÔNG có đuôi `.0`: `default: 1000` phải thành `1000`, vì `1000.0` trong
    /// một câu `LIMIT :n` là lỗi cú pháp, và trong `WHERE ma = :n` thì nó không khớp gì cả.
    private static func text(of value: YAMLValue) -> String {
        if let number = value.doubleValue {
            return number == number.rounded() && abs(number) < 1e15
                ? String(Int(number)) : String(number)
        }
        if let flag = value.boolValue { return flag ? "true" : "false" }
        return value.stringValue ?? ""
    }
}
