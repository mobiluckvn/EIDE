import XCTest
@testable import GEditorCore

/// NFR-MIN-03 và NFR-DQR-02 — **chỉ-đọc tuyệt đối**, kiểm bằng checksum.
///
/// Cả hai chỉ tiêu là P0* và cả hai viết ra ĐÚNG cách kiểm: *"mining không bao giờ sửa file
/// nguồn (kiểm checksum)"*, *"chấm điểm không sửa dữ liệu nguồn (checksum)"*. Suốt nhiều phiên
/// chúng nằm trong ô «CÓ mã, chưa có phép đo»: tính chất đúng, nhưng không có gì giữ nó.
///
/// ## Vì sao checksum chứ không "đọc lại rồi so chuỗi"
///
/// So chuỗi bỏ sót đúng những thay đổi khó thấy nhất: một byte BOM thêm vào đầu, một dấu xuống
/// dòng cuối tệp, CRLF đổi thành LF. Ba thứ ấy không đổi nội dung mà người đọc thấy, nhưng đổi
/// TỆP — và với dữ liệu của người khác thì đó vẫn là sửa.
final class ReadOnlyGuaranteeTests: XCTestCase {

    private let csv = """
        ma_kh,thanh_pho,doanh_thu
        KH01,Hà Nội,1500000
        KH02,Huế,900000
        KH03,Đà Nẵng,1200000
        KH04,Hà Nội,300000
        KH05,Huế,7500000
        KH06,Cần Thơ,450000
        KH07,Hà Nội,620000
        KH08,Huế,880000
        KH09,Đà Nẵng,1310000
        KH10,Cần Thơ,90000

        """

    /// Tổng kiểm có TRỌNG SỐ theo vị trí — hoán vị hai byte cũng đổi kết quả.
    private func checksum(ofFileAt path: String) throws -> Int {
        let bytes = try Data(contentsOf: URL(fileURLWithPath: path))
        return bytes.enumerated().reduce(0) { $0 &+ (Int($1.element) &* ($1.offset &+ 1)) }
    }

    private func withSourceFile(_ body: (String, TextBuffer) throws -> Void) throws {
        let folder = NSTemporaryDirectory() + "readonly-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let path = folder + "/nguon.csv"
        try Data(csv.utf8).write(to: URL(fileURLWithPath: path))
        let buffer = TextBuffer(original: MemoryByteSource(Array(csv.utf8)))
        try body(path, buffer)
    }

    // MARK: - NFR-MIN-03

    func testKHAIphaKHONGdungVAOnguon() throws {
        try withSourceFile { path, buffer in
            let before = try checksum(ofFileAt: path)
            let beforeText = buffer.text

            var values: [Double] = []
            var rows: [[Double]] = []
            for line in csv.split(separator: "\n").dropFirst() {
                let parts = line.split(separator: ",")
                guard parts.count == 3, let money = Double(parts[2]) else { continue }
                values.append(money)
                rows.append([money, Double(parts[0].count)])
            }
            XCTAssertGreaterThan(values.count, 8, "fixture quá nhỏ, bài kiểm sẽ rỗng nghĩa")

            _ = try AnomalyDetector.detect(values, column: "doanh_thu", method: .iqr())
            _ = try AnomalyDetector.mahalanobis(rows: rows, columns: ["tien", "dai"])
            _ = try Clustering.kMeans(rows: rows, columns: ["tien", "dai"], k: 2)
            _ = try Apriori.run(baskets: rows.indices.map { ["a", "b\($0 % 3)"] })
            _ = try GroupMining.run(
                labels: rows.indices.map { "n\($0 % 3)" }, columns: ["tien"], values: [values],
                options: GroupMining.Options(anomalyColumn: "tien", minimumRows: 2))
            _ = TextMining.run(documents: [csv])

            XCTAssertEqual(try checksum(ofFileAt: path), before, "khai phá làm ĐỔI tệp nguồn")
            XCTAssertEqual(buffer.text, beforeText, "khai phá làm ĐỔI buffer nguồn")
        }
    }

    // MARK: - NFR-DQR-02

    func testCHAMdiemKHONGdungVAOnguon_vaLICHsuGHItepRIENG() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        try withSourceFile { path, buffer in
            let before = try checksum(ofFileAt: path)
            let rules = try QualityRules.load(fromYAML: """
                rules:
                  - col: ma_kh
                    not_null: true
                  - col: ma_kh
                    unique: true
                  - col: doanh_thu
                    range: {min: 0}
                """)
            let report = try QualityEngine.evaluate(rules, in: buffer, dialect: .comma,
                                                    sourcePath: path)
            XCTAssertEqual(report.results.count, 3, "ba luật phải chạy, không thì bài này rỗng")
            XCTAssertEqual(try checksum(ofFileAt: path), before, "chấm điểm làm ĐỔI tệp nguồn")

            // Lịch sử ghi TỆP RIÊNG cạnh rules, không bao giờ ghi vào tệp dữ liệu.
            let historyPath = (path as NSString).deletingLastPathComponent + "/lich-su.jsonl"
            let score = try QualityScorer.score(report, rules: rules, in: buffer,
                                                dialect: CSVDialect.comma, sourcePath: path)
            _ = try QualityHistory.append(
                QualitySnapshot(report: report, score: score, sourcePath: path, sourceHash: ""),
                to: historyPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: historyPath))
            XCTAssertEqual(try checksum(ofFileAt: path), before,
                           "ghi lịch sử mà tệp DỮ LIỆU cũng đổi")
        }
    }
}
