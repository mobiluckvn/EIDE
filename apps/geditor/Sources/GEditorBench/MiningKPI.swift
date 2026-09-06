import Foundation
import GEditorCore

/// Bốn chỉ tiêu khai phá dữ liệu mà **chưa ai từng đo** — NFR-MIN-01, NFR-MIN-05, NFR-DQR-03.
///
/// Bảng trạng thái xếp chúng vào ô ⛔ với đúng một câu: *"CÓ mã, chưa có phép đo … làm xong
/// không có nghĩa là đã đo"*. Bộ này trả lời từng con số một, ở ĐÚNG cỡ mà chỉ tiêu nói tới —
/// không đo cỡ nhỏ rồi nhân lên, vì PoC-G đã cho thấy chi phí mỗi ô không phải hằng số.
///
/// ## Vì sao đo trong `geditor-bench` chứ không trong bài tự kiểm
///
/// Một triệu hàng × 20 cột là ~200 MB và vài chục giây. Bộ tự kiểm chạy sau mỗi lần dựng, nên
/// một bài như thế sẽ bị người ta bỏ qua trong vòng một tuần. Đây là phép đo trước phát hành,
/// và nó nói ra kết quả bằng số chứ không chỉ đạt/trượt.
enum MiningKPI {

    struct Report: Encodable {
        let kpi: String
        let architecture: String
        let rows: Int
        let columns: Int
        /// NFR-MIN-01 — anomaly ≤ 10 s.
        let anomalyMs: Double
        let anomalyBudgetMs: Double
        /// NFR-MIN-01 — k-means (k ≤ 20, ≤ 50 vòng) ≤ 30 s.
        let kMeansMs: Double
        let kMeansBudgetMs: Double
        let kMeansIterations: Int
        /// NFR-MIN-01 — apriori 1 triệu giao dịch ≤ 60 s.
        let aprioriMs: Double
        let aprioriBudgetMs: Double
        let aprioriRules: Int
        /// NFR-MIN-01 — hủy ≤ 200 ms. `nil` khi KHÔNG đo được (xem `cancelMeasured`).
        let cancelMs: Double?
        let cancelBudgetMs: Double
        /// Tác vụ có còn đang chạy lúc gọi `cancel()` không. Sai thì con số trên vô nghĩa.
        let cancelMeasured: Bool
        /// NFR-MIN-05 — 1.000 nhóm × (anomaly + forecast) ≤ 120 s.
        let groupMiningMs: Double
        let groupMiningBudgetMs: Double
        let groupCount: Int
        /// NFR-MIN-05 — hủy giữa chừng GIỮ NGUYÊN kết quả các nhóm đã xong.
        let partialGroupsKept: Int
        /// Phép huỷ có thật sự cắt GIỮA CHỪNG không (0 < giữ lại < tổng).
        let partialMeasured: Bool
        /// NFR-DQR-03 — cùng dữ liệu + cùng luật → cùng điểm, từng bit.
        let deterministic: Bool
        /// NFR-QRY-01 vế cuối — *"hủy ≤ 200 ms"* trên phép lọc CSV. `nil` = không đo được.
        let filterCancelMs: Double?
        let filterCancelBudgetMs: Double
        let pass: Bool
        let notes: [String]
    }

    // MARK: - Chạy

    static func run(rows: Int, columns: Int, groups: Int, baskets: Int) throws -> Report {
        var notes: [String] = []

        FileHandle.standardError.write(Data("   dựng \(rows) hàng × \(columns) cột…\n".utf8))
        let matrix = numericMatrix(rows: rows, columns: columns)
        let firstColumn = matrix.map { $0[0] }

        // ── NFR-MIN-01, vế một: bất thường đơn biến trên một triệu giá trị.
        //
        // Chạy IQR chứ không z-score: `recommendedMethod` chọn nó cho phân bố lệch, và dữ liệu
        // tiền tệ thì lệch. Đo thứ sản phẩm thật sự chạy, không đo nhánh rẻ nhất.
        let anomaly = Measure.milliseconds {
            _ = try? AnomalyDetector.detect(firstColumn, column: "doanh_thu", method: .iqr())
        }

        // ── NFR-MIN-01, vế hai: k-means. Chỉ tiêu ghi rõ k ≤ 20 và ≤ 50 vòng.
        var iterations = 0
        let kMeans = Measure.milliseconds {
            if let result = try? Clustering.kMeans(rows: matrix, columns: names(columns), k: 20) {
                iterations = result.iterations
            }
        }
        if iterations > 50 {
            notes.append("k-means chạy \(iterations) vòng — chỉ tiêu nói ≤ 50; "
                         + "con số thời gian ở trên vì thế đo một lượt NẶNG HƠN chỉ tiêu.")
        }

        // ── NFR-MIN-01, vế ba: apriori trên một triệu giao dịch.
        FileHandle.standardError.write(Data("   dựng \(baskets) giỏ hàng…\n".utf8))
        let transactions = basketFixture(count: baskets)
        var rules = 0
        let apriori = Measure.milliseconds {
            if let result = try? Apriori.run(baskets: transactions, minimumSupport: 0.02) {
                rules = result.rules.count
            }
        }

        // ── NFR-MIN-01, vế bốn: HỦY ≤ 200 ms.
        //
        // Đo đúng thứ chỉ tiêu hỏi: khoảng từ lúc bấm huỷ tới lúc tác vụ thật sự dừng. Nên
        // token bị huỷ từ một luồng KHÁC trong khi phép tính đang chạy — huỷ trước khi chạy thì
        // chỉ đo được cái `guard` đầu hàm, và con số ấy luôn đẹp mà không nói gì.
        //
        // Kết quả đi qua một HỘP có khoá chứ không qua biến bắt giữ: bản đầu viết `var stopped`
        // rồi gán trong closure chạy ở luồng khác, và Swift bắt ngay lúc chạy — phép kiểm ĐỘC
        // QUYỀN TRUY CẬP thấy hai luồng cùng chạm một ô nhớ, và cả bộ đo sập với SIGTRAP.
        let cancelToken = CancelToken()
        let cancelClock = Date()
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue(label: "kpi.cancel").async {
            _ = try? Clustering.kMeans(rows: matrix, columns: names(columns), k: 20,
                                       cancelToken: cancelToken)
            box.stopped = Date()
            done.signal()
        }
        // Cho phép tính chạy thật sự rồi mới huỷ.
        Thread.sleep(forTimeInterval: 0.4)
        let requested = Date()
        cancelToken.cancel()
        done.wait()
        // Tác vụ xong TRƯỚC khi kịp huỷ thì phép đo này không đo gì cả — và con số ra sẽ ÂM.
        // Nói ra thay vì để một số âm trôi vào bảng: cùng luật với `AnomalyDetector` (*"không
        // đo được thì KHÔNG kết luận"*). Ở cỡ chỉ tiêu (1 triệu hàng) k-means chạy đủ lâu để
        // phép đo có nghĩa; ở cỡ nhỏ thì không, và bộ đo phải nói đúng điều đó.
        let stoppedAt = box.stopped ?? requested
        let cancelMeasured = stoppedAt > requested
        let cancelMs: Double? = cancelMeasured
            ? stoppedAt.timeIntervalSince(requested) * 1000 : nil
        if !cancelMeasured {
            notes.append("KHÔNG đo được phép huỷ: k-means xong trước khi gọi cancel() — "
                         + "cỡ dữ liệu quá nhỏ. Chạy ở đúng cỡ chỉ tiêu để đo vế này.")
        }
        notes.append(String(format: "huỷ đo từ lúc gọi `cancel()` tới lúc tác vụ trả về; "
                            + "tác vụ đã chạy %.0f ms trước đó",
                            requested.timeIntervalSince(cancelClock) * 1000))

        // ── NFR-MIN-05: 1.000 nhóm × (bất thường + dự báo).
        FileHandle.standardError.write(Data("   dựng \(groups) nhóm…\n".utf8))
        let grouped = groupFixture(groups: groups, rowsPerGroup: 24)
        let groupOptions = GroupMining.Options(
            anomalyColumn: "gia_tri", forecastColumn: "gia_tri", horizon: 4)
        var groupCount = 0
        let groupMining = Measure.milliseconds {
            if let report = try? GroupMining.run(
                labels: grouped.labels, columns: ["gia_tri"], values: grouped.values,
                options: groupOptions) {
                groupCount = report.groups.count
            }
        }

        // ── NFR-MIN-05, vế hai: huỷ giữa chừng phải GIỮ phần đã xong.
        // Phép huỷ phải bắn ĐÚNG GIỮA CHẶNG, và đó là chỗ hai bản trước đều trượt:
        //
        //   · ngủ 200 ms rồi huỷ → cả lượt (khoảng 160 ms) đã xong, "giữ 1000/1000" nhìn như
        //     một thành tích trong khi chưa huỷ gì;
        //   · ngủ 2 ms rồi huỷ ở luồng khác → luồng kia còn chưa kịp khởi động, giữ 0/1000.
        //
        // Nay lượt đo chạy ĐỒNG BỘ ở luồng này, còn phép huỷ được hẹn giờ ở luồng khác tại nửa
        // thời gian mà lượt ĐẦY ĐỦ vừa mất — con số ấy vừa đo xong ngay ở trên, nên nó không
        // phải hằng số đoán mò.
        let partialToken = CancelToken()
        let halfway = max(0.005, groupMining / 1000 / 2)
        DispatchQueue(label: "kpi.partial").asyncAfter(deadline: .now() + halfway) {
            partialToken.cancel()
        }
        var partial = 0
        if let report = try? GroupMining.run(
            labels: grouped.labels, columns: ["gia_tri"], values: grouped.values,
            options: groupOptions, cancelToken: partialToken) {
            partial = report.groups.count
        }

        // ── NFR-QRY-01, vế cuối: HUỶ phép lọc ≤ 200 ms.
        //
        // Mục NFR-QRY-01 trong bảng trạng thái ghi rõ *"vế «hủy ≤ 200 ms» vẫn chưa đo"* — hai
        // vế kia (màn hình đầu, quét hết) đã đo từ lâu ở `run-clean-kpi.sh`. Đo ở đây vì cùng
        // một khuôn: chạy thật, huỷ từ luồng khác giữa chừng, đếm từ lúc gọi `cancel()`.
        let filterBytes = CleanKPI.fixture(rows: rows, columns: columns)
        let filterBuffer = TextBuffer(original: MemoryByteSource(filterBytes))
        let filterToken = CancelToken()
        let filterBox = Box()
        let filterDone = DispatchSemaphore(value: 0)
        DispatchQueue(label: "kpi.filter").async {
            // Điều kiện khớp ĐÚNG MỘT hàng ở cuối bảng: đó là ca xấu nhất mà chính
            // `run-clean-kpi.sh` đã phơi ra, tức phép lọc chắc chắn còn đang chạy khi cú huỷ tới.
            _ = CSVFilter.rows(
                matching: [CSVFilterCondition(column: 1, test: .contains("khong-bao-gio-khop"),
                                              text: "khong-bao-gio-khop")],
                in: filterBuffer, dialect: .comma, cancelToken: filterToken)
            filterBox.stopped = Date()
            filterDone.signal()
        }
        Thread.sleep(forTimeInterval: 0.15)
        let filterRequested = Date()
        filterToken.cancel()
        filterDone.wait()
        let filterStopped = filterBox.stopped ?? filterRequested
        let filterCancelMs: Double? = filterStopped > filterRequested
            ? filterStopped.timeIntervalSince(filterRequested) * 1000 : nil
        if filterCancelMs == nil {
            notes.append("KHÔNG đo được phép huỷ LỌC: lượt quét xong trước khi gọi cancel().")
        }

        // ── NFR-DQR-03: cùng dữ liệu + cùng luật → cùng điểm, TỪNG BIT.
        //
        // So bằng chuỗi in ra ở độ chính xác đầy đủ chứ không so `Double` đã làm tròn: chỉ tiêu
        // viết "bit-by-bit", và hai con số khác nhau ở chữ số thứ mười lăm vẫn là hai con số.
        let deterministic = scoreTwice(matrix: matrix, columns: names(columns))

        // Huỷ giữa chừng chỉ có nghĩa khi nó cắt được THẬT: giữ 0 nhóm nghĩa là chưa nhóm nào
        // xong, giữ đủ nghĩa là chưa cắt gì.
        let partialMeasured = partial > 0 && partial < groupCount
        if !partialMeasured {
            notes.append("KHÔNG đo được phép huỷ giữa chừng của group-by: giữ lại "
                         + "\(partial)/\(groupCount) nhóm.")
        }
        if rules == 0 {
            notes.append("KHÔNG đo được tầng dựng luật của apriori: 0 luật vượt ngưỡng "
                         + "support — con số thời gian chỉ đo lượt quét.")
        }

        let anomalyBudget = 10_000.0, kMeansBudget = 30_000.0, aprioriBudget = 60_000.0
        let cancelBudget = 200.0, groupBudget = 120_000.0
        // `pass` đòi phép huỷ ĐO ĐƯỢC, không chỉ đòi con số đẹp: một vế không đo được mà vẫn
        // cho ĐẠT thì bảng KPI nói dối đúng chỗ nó sinh ra để canh.
        let pass = anomaly <= anomalyBudget && kMeans <= kMeansBudget
            && apriori <= aprioriBudget
            && cancelMeasured && (cancelMs ?? .infinity) <= cancelBudget
            && groupMining <= groupBudget && deterministic
            && rules > 0 && partialMeasured
            && (filterCancelMs ?? .infinity) <= 200

        return Report(
            kpi: "NFR-MIN-01 · NFR-MIN-05 · NFR-DQR-03",
            architecture: architecture(),
            rows: rows, columns: columns,
            anomalyMs: anomaly, anomalyBudgetMs: anomalyBudget,
            kMeansMs: kMeans, kMeansBudgetMs: kMeansBudget, kMeansIterations: iterations,
            aprioriMs: apriori, aprioriBudgetMs: aprioriBudget, aprioriRules: rules,
            cancelMs: cancelMs, cancelBudgetMs: cancelBudget, cancelMeasured: cancelMeasured,
            groupMiningMs: groupMining, groupMiningBudgetMs: groupBudget,
            groupCount: groupCount, partialGroupsKept: partial,
            partialMeasured: partialMeasured,
            deterministic: deterministic,
            filterCancelMs: filterCancelMs, filterCancelBudgetMs: 200,
            pass: pass, notes: notes)
    }

    /// Ô nhớ dùng chung giữa luồng đo và luồng chạy tác vụ.
    ///
    /// Một lớp chứ không phải `var` bắt giữ: xem ghi chú ở chỗ đo phép huỷ.
    final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var _stopped: Date?
        private var _groups = 0

        var stopped: Date? {
            get { lock.lock(); defer { lock.unlock() }; return _stopped }
            set { lock.lock(); _stopped = newValue; lock.unlock() }
        }

        var groups: Int {
            get { lock.lock(); defer { lock.unlock() }; return _groups }
            set { lock.lock(); _groups = newValue; lock.unlock() }
        }
    }

    // MARK: - Dữ liệu thử

    static func names(_ count: Int) -> [String] {
        (0 ..< count).map { "cot_\($0)" }
    }

    /// Ma trận số TẤT ĐỊNH — cùng seed cho mọi lượt chạy, để hai lần đo so được với nhau.
    ///
    /// Dùng `SeededGenerator` của lõi chứ không `Double.random`: bộ sinh của hệ thống lấy hạt từ
    /// hệ điều hành, nên hai lượt đo cho hai bộ dữ liệu khác nhau và mọi so sánh trở thành so
    /// hai thứ khác nhau.
    static func numericMatrix(rows: Int, columns: Int) -> [[Double]] {
        var generator = SeededGenerator(seed: 20_260_904)
        var out: [[Double]] = []
        out.reserveCapacity(rows)
        for row in 0 ..< rows {
            var line: [Double] = []
            line.reserveCapacity(columns)
            for column in 0 ..< columns {
                let base = Double(generator.next() % 1_000_000) / 100
                // Một phần nghìn số là điểm cực đoan — có thứ cho phép bất thường tìm ra, và
                // cũng là hình dạng thật của dữ liệu tiền tệ.
                line.append(row % 1000 == 0 && column == 0 ? base * 50 : base)
            }
            out.append(line)
        }
        return out
    }

    /// Giỏ hàng tất định: mỗi giỏ 3–6 mặt hàng lấy từ một danh mục 40 mã, **kèm mẫu cài sẵn**.
    ///
    /// Bản đầu chỉ bốc ngẫu nhiên đều, và apriori trả về **0 luật**: không cặp nào vượt ngưỡng
    /// support. Con số thời gian khi ấy vẫn có — nhưng nó đo một lượt quét KHÔNG SINH RA GÌ, tức
    /// đo thiếu hẳn tầng dựng luật, đúng tầng đắt nhất. Một bộ đo như thế báo ĐẠT cho một hiện
    /// thực có thể chưa bao giờ chạy tới nửa sau của thuật toán.
    ///
    /// Nay cứ năm giỏ có một giỏ chứa trọn bộ ba `SP1·SP2·SP3` — đủ để support vượt ngưỡng và
    /// tầng dựng luật có việc thật. Bộ đo ĐÒI số luật > 0, không thì nói "không đo được".
    static func basketFixture(count: Int) -> [[String]] {
        var generator = SeededGenerator(seed: 20_260_905)
        let catalogue = (0 ..< 40).map { "SP\($0)" }
        var out: [[String]] = []
        out.reserveCapacity(count)
        for index in 0 ..< count {
            var basket: Set<String> = index % 5 == 0 ? ["SP1", "SP2", "SP3"] : []
            let size = 3 + Int(generator.next() % 4) + basket.count
            while basket.count < size {
                basket.insert(catalogue[Int(generator.next() % UInt64(catalogue.count))])
            }
            out.append(Array(basket).sorted())
        }
        return out
    }

    /// Dữ liệu cho `GroupMining` — trả về **theo CỘT**, không theo hàng.
    ///
    /// `GroupMining.run` đọc `values[cột][hàng]`. Bản đầu của bộ đo này dựng theo HÀNG và cả
    /// tiến trình sập với SIGTRAP ngay ở nhóm đầu tiên — chỉ số ra ngoài mảng, không phải lỗi
    /// của thuật toán. Ghi ra đây vì hai bố cục ấy có cùng kiểu `[[Double]]`, nên trình biên
    /// dịch không nói được gì.
    static func groupFixture(
        groups: Int, rowsPerGroup: Int
    ) -> (labels: [String?], values: [[Double]]) {
        var generator = SeededGenerator(seed: 20_260_906)
        var labels: [String?] = []
        var column: [Double] = []
        labels.reserveCapacity(groups * rowsPerGroup)
        column.reserveCapacity(groups * rowsPerGroup)
        for group in 0 ..< groups {
            for row in 0 ..< rowsPerGroup {
                labels.append("nhom_\(group)")
                // Có mùa vụ chu kỳ 4 để phần dự báo có việc thật mà làm.
                let seasonal = Double((row % 4) * 10)
                column.append(Double(generator.next() % 500) + seasonal)
            }
        }
        return (labels, [column])
    }

    /// Chấm điểm hai lần rồi so từng chữ số — NFR-DQR-03.
    static func scoreTwice(matrix: [[Double]], columns: [String]) -> Bool {
        func once() -> String {
            // Ba phép có thành phần dễ trôi nhất: k-means (có seed), tương quan (có sắp hạng),
            // và bất thường (có phân vị). Ghi ra chuỗi ở độ chính xác đầy đủ.
            let sample = Array(matrix.prefix(20_000))
            var out = ""
            if let cluster = try? Clustering.kMeans(rows: sample, columns: columns, k: 8) {
                out += cluster.labels.map { $0.map(String.init) ?? "-" }.joined(separator: ",")
                out += "|" + String(reflecting: cluster.silhouette ?? -1)
            }
            let first = sample.map { $0[0] }
            let second = sample.map { $0[min(1, $0.count - 1)] }
            if let pearson = Correlation.pearson(first, second) {
                out += "|" + String(reflecting: pearson)
            }
            if let anomaly = try? AnomalyDetector.detect(first, column: "c", method: .iqr()) {
                out += "|" + String(anomaly.findings.count)
                out += "|" + (anomaly.findings.first.map { String(reflecting: $0.score) } ?? "-")
            }
            return out
        }
        return once() == once()
    }

    static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
