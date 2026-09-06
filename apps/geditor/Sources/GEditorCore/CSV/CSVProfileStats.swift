import Foundation

extension CSVProfiler {

    /// Thống kê thô của một cột, gom trong lượt quét.
    ///
    /// Mọi thứ ở đây phải cập nhật được bằng MỘT lần nhìn vào ô và một lượng bộ nhớ cố định —
    /// hồ sơ chạy trên bảng hàng triệu hàng, nên bất cứ thứ gì lớn dần theo số hàng đều bị
    /// chặn bằng ngưỡng và nói rõ ra là đã chặn.
    struct ColumnStats {
        var rows = 0
        var nullCells = 0
        var numberCells = 0
        var dateCells = 0

        /// Welford: đếm, trung bình chạy, tổng bình phương lệch.
        var count = 0
        var mean = 0.0
        var m2 = 0.0

        var minNumber = Double.greatestFiniteMagnitude
        var maxNumber = -Double.greatestFiniteMagnitude
        var minText: String?
        var maxText: String?

        /// Băm 64-bit của các giá trị đã gặp.
        ///
        /// Băm chứ không giữ chuỗi: 10.000 chuỗi mỗi cột nhân hai chục cột là hàng chục MB cho
        /// một con số duy nhất. Xác suất hai giá trị khác nhau trùng băm ở quy mô 10.000 là
        /// khoảng 3·10⁻¹², nhỏ hơn nhiều so với mức mà một con số "distinct" cần chính xác.
        var distinctHashes: Set<UInt64> = []
        var distinctOverflow = false

        /// Bảng đếm CHÍNH XÁC, chỉ sống khi cột còn dưới ngưỡng distinct.
        var counts: [UInt64: (value: String, count: Int)] = [:]

        /// Vài ô cực trị mỗi đầu, để chấm điểm bất thường sau khi biết mean và σ.
        var lowest: [(value: Double, cell: CSVClean.CellRef)] = []
        var highest: [(value: Double, cell: CSVClean.CellRef)] = []

        /// Số ô cực trị giữ mỗi đầu. Giá trị bất thường theo |z| > 3 luôn nằm ở hai đầu, nên
        /// giữ hai đầu là đủ; giữ nhiều hơn chỉ tốn bộ nhớ cho những ô sẽ bị loại.
        static let extremeSlots = 32

        mutating func record(
            bytes: [UInt8], range: Range<Int>, quoted: Bool,
            dialect: CSVDialect, spec: CSVNullSpec,
            rowIndex: Int, column: Int, base: Int
        ) {
            rows += 1

            // Ô rỗng nhận ra trên BYTE, không dựng chuỗi. Trong dữ liệu thật đây là một phần
            // đáng kể số ô, và mỗi chuỗi không dựng là một lần cấp phát không xảy ra.
            if range.isEmpty {
                nullCells += 1
                return
            }

            // Ô bọc ngoặc phải bóc ra trước; ô thường đọc THẲNG trên byte của cửa sổ, không
            // sao chép. Trong bảng thật gần như mọi ô đều không bọc, nên đây là đường chạy
            // chính và nó không cấp phát gì.
            if quoted {
                let unescaped = CSVEngine.unescape(Array(bytes[range]), dialect: dialect)
                unescaped.withUnsafeBufferPointer {
                    record(cell: $0, spec: spec, rowIndex: rowIndex, column: column,
                           offset: base + range.lowerBound)
                }
            } else {
                bytes.withUnsafeBufferPointer { window in
                    let cell = UnsafeBufferPointer(
                        rebasing: window[range.lowerBound ..< range.upperBound]
                    )
                    record(cell: cell, spec: spec, rowIndex: rowIndex, column: column,
                           offset: base + range.lowerBound)
                }
            }
        }

        /// Ghi nhận một ô đã bóc vỏ, làm việc thẳng trên byte.
        private mutating func record(
            cell: UnsafeBufferPointer<UInt8>, spec: CSVNullSpec,
            rowIndex: Int, column: Int, offset: Int
        ) {
            if spec.isNull(cell) {
                nullCells += 1
                return
            }
            // Ô thiếu KHÔNG vào phép đếm distinct và bảng "hay gặp": "N/A" là chỗ TRỐNG chứ
            // không phải một giá trị. Đếm nó vào thì một cột ba tỉnh thành có "4 giá trị khác
            // nhau", và người đọc hồ sơ đi tìm cái tỉnh thứ tư không bao giờ tồn tại. Số ô
            // thiếu đã có cột riêng ngay bên cạnh.
            note(Self.hash(cell), cell)

            if case let .certain(date, _) = CSVClean.readDate(cell) {
                dateCells += 1
                // Ngày so sánh trên dạng ISO: so chuỗi thô sẽ xếp "25/07/2026" trước
                // "2026-01-01" và cho ra một khoảng thời gian bịa đặt.
                noteText(date.iso)
                return
            }

            if let value = CSVClean.numericValue(of: cell) {
                numberCells += 1
                noteNumber(value, rowIndex: rowIndex, column: column, offset: offset, cell: cell)
                return
            }

            noteTextIfExtreme(cell)
        }

        private mutating func note(_ hash: UInt64, _ cell: UnsafeBufferPointer<UInt8>) {
            if !distinctOverflow {
                distinctHashes.insert(hash)
                if distinctHashes.count > CSVProfiler.distinctLimit {
                    // Tràn: bỏ cả hai bảng. Giữ lại một bảng đếm dở dang sẽ cho ra danh sách
                    // "hay gặp" thiên vị những giá trị xuất hiện SỚM — một câu trả lời sai mà
                    // trông vẫn có vẻ hợp lý.
                    distinctOverflow = true
                    counts.removeAll(keepingCapacity: false)
                    return
                }
            } else {
                return
            }
            // Chuỗi chỉ được giữ khi CHÈN mới, tức là nhiều nhất `distinctLimit` lần mỗi cột.
            if let existing = counts[hash] {
                counts[hash] = (existing.value, existing.count + 1)
            } else {
                counts[hash] = (String(decoding: cell, as: UTF8.self), 1)
            }
        }

        /// So min/max của cột chữ NGAY TRÊN BYTE; chuỗi chỉ dựng khi ô này thật sự là cực trị.
        private mutating func noteTextIfExtreme(_ cell: UnsafeBufferPointer<UInt8>) {
            if minText == nil || Self.less(cell, than: minText!) {
                minText = String(decoding: cell, as: UTF8.self)
            }
            if maxText == nil || Self.greater(cell, than: maxText!) {
                maxText = String(decoding: cell, as: UTF8.self)
            }
        }

        /// So sánh byte theo thứ tự từ điển — cùng thứ tự mà `String` cho chuỗi UTF-8.
        static func less(_ cell: UnsafeBufferPointer<UInt8>, than other: String) -> Bool {
            for (a, b) in zip(cell, other.utf8) {
                if a != b { return a < b }
            }
            return cell.count < other.utf8.count
        }

        static func greater(_ cell: UnsafeBufferPointer<UInt8>, than other: String) -> Bool {
            for (a, b) in zip(cell, other.utf8) {
                if a != b { return a > b }
            }
            return cell.count > other.utf8.count
        }

        private mutating func noteText(_ value: String) {
            if minText == nil || value < minText! { minText = value }
            if maxText == nil || value > maxText! { maxText = value }
        }

        private mutating func noteNumber(
            _ value: Double, rowIndex: Int, column: Int, offset: Int,
            cell: UnsafeBufferPointer<UInt8>
        ) {
            // Welford: ổn định số học trên hàng triệu giá trị, khác với cộng dồn rồi chia.
            count += 1
            let delta = value - mean
            mean += delta / Double(count)
            m2 += delta * (value - mean)

            minNumber = Swift.min(minNumber, value)
            maxNumber = Swift.max(maxNumber, value)

            // Chỉ dựng chuỗi cho ô LỌT vào danh sách cực trị: 32 ô mỗi đầu, không phải triệu ô.
            guard mayBeExtreme(value) else { return }
            let reference = CSVClean.CellRef(
                rowIndex: rowIndex, column: column, offset: offset,
                value: String(decoding: cell, as: UTF8.self)
            )
            insert(into: &lowest, value: value, cell: reference, keepSmallest: true)
            insert(into: &highest, value: value, cell: reference, keepSmallest: false)
        }

        /// Ô này có cửa lọt vào một trong hai danh sách cực trị không.
        private func mayBeExtreme(_ value: Double) -> Bool {
            if lowest.count < Self.extremeSlots || highest.count < Self.extremeSlots { return true }
            return value < lowest[lowest.count - 1].value || value > highest[highest.count - 1].value
        }

        private func insert(
            into slots: inout [(value: Double, cell: CSVClean.CellRef)],
            value: Double, cell: CSVClean.CellRef, keepSmallest: Bool
        ) {
            if slots.count == Self.extremeSlots {
                // Ngoài rìa thì bỏ ngay — đây là đường chạy cho gần như mọi ô.
                let edge = keepSmallest ? slots[slots.count - 1].value : slots[slots.count - 1].value
                if keepSmallest ? value >= edge : value <= edge { return }
                slots.removeLast()
            }
            let index = slots.firstIndex {
                keepSmallest ? value < $0.value : value > $0.value
            } ?? slots.count
            slots.insert((value, cell), at: index)
        }

        /// FNV-1a 64-bit.
        ///
        /// Không dùng `Hasher` của Swift: nó gieo hạt NGẪU NHIÊN theo mỗi lần chạy tiến trình,
        /// nên cùng một file cho ra ngưỡng tràn khác nhau giữa hai lần mở. Sổ tay thuật toán
        /// đặt tính TẤT ĐỊNH lên hàng đầu — chạy lại cùng dữ liệu phải ra cùng con số.
        static func hash(_ value: UnsafeBufferPointer<UInt8>) -> UInt64 {
            var out: UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in value {
                out ^= UInt64(byte)
                out = out &* 0x100_0000_01b3
            }
            return out
        }

        /// Chốt hồ sơ của cột.
        func finish(column: Int, name: String) -> CSVColumnProfile {
            let typed = Swift.max(numberCells, dateCells)
            let nonEmpty = rows - nullCells
            let type: CSVValueType
            if nonEmpty >= CSVValidator.minimumSample,
               Double(typed) / Double(nonEmpty) >= CSVValidator.typeThreshold {
                type = numberCells >= dateCells ? .number : .date(.iso)
            } else {
                type = .text
            }

            let deviation = count > 1 ? (m2 / Double(count - 1)).squareRoot() : 0
            let top = counts.values
                .sorted { ($0.count, $1.value) > ($1.count, $0.value) }
                .prefix(5)
                .map { (value: $0.value, count: $0.count) }

            var minimum: String?
            var maximum: String?
            switch type {
            case .number where count > 0:
                minimum = format(minNumber)
                maximum = format(maxNumber)
            default:
                minimum = minText
                maximum = maxText
            }

            // Chấm điểm bất thường CHỈ trên những ô cực trị đã giữ: |z| > 3 thì ô ấy chắc chắn
            // nằm ở một trong hai đầu, nên không cần quét lại tài liệu.
            var outliers: [CSVClean.CellRef] = []
            if type == .number, count > 2, deviation > 0 {
                let candidates = (lowest + highest).sorted {
                    abs($0.value - mean) > abs($1.value - mean)
                }
                var seen = Set<Int>()
                for candidate in candidates {
                    guard abs(candidate.value - mean) / deviation > 3 else { break }
                    guard seen.insert(candidate.cell.offset).inserted else { continue }
                    outliers.append(candidate.cell)
                    if outliers.count >= CSVProfiler.outlierSamples { break }
                }
            }

            return CSVColumnProfile(
                column: column, name: name, type: type,
                rows: rows, nullCells: nullCells, typedCells: typed,
                distinct: distinctOverflow ? CSVProfiler.distinctLimit : distinctHashes.count,
                distinctExact: !distinctOverflow,
                topValues: distinctOverflow ? [] : Array(top),
                topExact: !distinctOverflow,
                minimum: minimum, maximum: maximum,
                mean: type == .number && count > 0 ? mean : nil,
                standardDeviation: type == .number && count > 1 ? deviation : nil,
                outliers: outliers
            )
        }

        /// Số viết ra gọn: bỏ đuôi `.0` cho số nguyên, giữ đủ chữ số nghĩa cho số lẻ.
        private func format(_ value: Double) -> String {
            value == value.rounded() && abs(value) < 1e15
                ? String(Int64(value))
                : String(format: "%.6g", value)
        }
    }
}

extension Double {

    /// Đọc một ô thành số theo đúng luật của `CSVClean.readNumber`.
    ///
    /// Đi qua chính hàm ấy chứ không tự phân tích lại: hồ sơ nói "cột này là số" mà nút chuẩn
    /// hóa lại bảo "ô này không phải số" là hai bộ phận của cùng một ứng dụng cãi nhau trước
    /// mặt người dùng. Ô mơ hồ (`1.234`) lấy cách đọc Anh-Mỹ để có một con số dùng được cho
    /// thống kê — và hồ sơ không phải chỗ sửa dữ liệu, nên chọn ở đây không làm hỏng gì.
    init?(numeric value: String) {
        let parsed: CSVParsedNumber
        switch CSVClean.readNumber(value) {
        case let .certain(number, _): parsed = number
        case let .needsStyle(_, anglo): parsed = anglo
        case .notANumber: return nil
        }
        let text = parsed.negative ? "-" + parsed.integerDigits : parsed.integerDigits
        guard let whole = Double(text) else { return nil }
        guard !parsed.fractionDigits.isEmpty else {
            self = whole
            return
        }
        guard let fraction = Double("0." + parsed.fractionDigits) else { return nil }
        self = parsed.negative ? whole - fraction : whole + fraction
    }
}
