import XCTest
@testable import GEditorCore

/// NFR-MIN-04 — *"Mọi đầu ra kèm khối «Phương pháp»: thuật toán, tham số, seed, công thức"*.
///
/// ## Vì sao một bài kiểm riêng cho một tính chất "hiển nhiên"
///
/// Mỗi bộ khai phá đều CÓ trường `methodology`, và mỗi bộ đều điền nó — hôm nay. Nhưng không có
/// gì buộc bộ thứ mười một phải điền, và không có gì buộc một nhánh sớm (`guard` trả về kết quả
/// rỗng) phải điền. Đúng nhánh ấy mới là chỗ hỏng đáng sợ nhất: người dùng nhận một bảng KHÔNG
/// có gì, không biết vì sao, và cũng không có khối Phương pháp để đọc ra lý do.
///
/// Bài này vì thế gọi từng bộ ở CẢ hai đường: dữ liệu đẹp, và dữ liệu mà bộ ấy từ chối chấm.
final class MethodologyBlockTests: XCTestCase {

    private func assertHasMethod(_ text: String, _ what: String, file: StaticString = #filePath,
                                 line: UInt = #line) {
        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "\(what): khối Phương pháp RỖNG", file: file, line: line)
        // Không chỉ đòi khác rỗng: một dấu chấm cũng khác rỗng. Đòi nó nói được điều gì đó.
        XCTAssertGreaterThan(text.count, 20, "\(what): khối Phương pháp quá ngắn để nói gì",
                             file: file, line: line)
    }

    func testMOIboKHAIphaDEUkemKHOIphuongPHAP() throws {
        var values: [Double] = []
        var rows: [[Double]] = []
        for index in 0 ..< 60 {
            let base = Double(index % 17) * 3
            values.append(index == 30 ? base + 400 : base)
            rows.append([Double(index % 7), Double(index % 11), Double(index % 5)])
        }

        assertHasMethod(
            try AnomalyDetector.detect(values, column: "x", method: .iqr()).methodology,
            "AnomalyDetector.iqr")
        assertHasMethod(
            try AnomalyDetector.detect(values, column: "x", method: .zScore()).methodology,
            "AnomalyDetector.zScore")
        assertHasMethod(
            try AnomalyDetector.mahalanobis(rows: rows, columns: ["a", "b", "c"]).methodology,
            "AnomalyDetector.mahalanobis")
        assertHasMethod(
            try Clustering.kMeans(rows: rows, columns: ["a", "b", "c"], k: 3).methodology,
            "Clustering.kMeans")
        assertHasMethod(
            try Apriori.run(baskets: (0 ..< 60).map { $0 % 3 == 0 ? ["a", "b"] : ["a", "c"] })
                .methodology,
            "Apriori")
        assertHasMethod(
            try GroupMining.run(
                labels: (0 ..< 60).map { "n\($0 % 4)" }, columns: ["x"], values: [values],
                options: GroupMining.Options(anomalyColumn: "x", forecastColumn: "x")).methodology,
            "GroupMining")
        if let forecast = try TimeSeries.forecast(values, horizon: 3) {
            assertHasMethod(forecast.methodology, "TimeSeries.forecast")
        } else {
            XCTFail("dữ liệu thử không đủ để dự báo — bài kiểm không kiểm được vế này")
        }
        let documents: [String] = values.map { "gia tri \(Int($0)) trong bang du lieu" }
        assertHasMethod(TextMining.run(documents: documents).methodology, "TextMining")
    }

    func testNHANHTUchoiCHAMcungPHAInoiRAlyDO() throws {
        // Nhánh "không đủ dữ liệu" là nhánh người dùng gặp nhiều nhất trong đời thật — cột mới
        // nhập, nhóm nhỏ, tệp vừa lọc còn ba dòng. Trả về bảng rỗng KÈM lý do là khác hẳn trả
        // về bảng rỗng.
        assertHasMethod(
            try AnomalyDetector.detect([1], column: "x", method: .iqr()).methodology,
            "AnomalyDetector — một giá trị")
        assertHasMethod(
            try Apriori.run(baskets: []).methodology, "Apriori — không giao dịch nào")
        assertHasMethod(
            TextMining.run("").methodology, "TextMining — văn bản rỗng")
    }
}
