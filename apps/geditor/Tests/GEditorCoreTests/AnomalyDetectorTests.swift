import XCTest
@testable import GEditorCore

final class AnomalyDetectorTests: XCTestCase {

    /// Dãy sạch 1…10 với một điểm cực đoan cắm vào giữa.
    private let spiked: [Double] = [10, 12, 11, 13, 12, 11, 500, 12, 10, 13]

    // MARK: - IQR

    func testIQRTinhTayDuocVaGiaiThichNeuDungConSo() throws {
        let report = try AnomalyDetector.detect(spiked, column: "doanh_thu", method: .iqr(k: 1.5))

        XCTAssertEqual(report.findings.count, 1)
        let finding = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(finding.row, 6, "phải là chỉ số HÀNG GỐC, không phải chỉ số sau khi sắp")
        XCTAssertEqual(finding.value, 500)

        // Tính tay để bài kiểm không chỉ chép lại mã: dãy sắp là
        // [10, 10, 11, 11, 12, 12, 12, 13, 13, 500]. Phân vị kiểu 7 (R type-7):
        //   Q1 tại vị trí 0,25×(10−1) = 2,25 → 11 + 0,25×(11−11) = 11
        //   Q3 tại vị trí 0,75×(10−1) = 6,75 → 12 + 0,75×(13−12) = 12,75
        let sorted = spiked.sorted()
        XCTAssertEqual(ChartData.quantile(sorted, 0.25), 11, accuracy: 1e-9)
        XCTAssertEqual(ChartData.quantile(sorted, 0.75), 12.75, accuracy: 1e-9)
        // IQR = 1,75 → (500 − 12,75) / 1,75 = 278,43×
        XCTAssertEqual(finding.score, (500 - 12.75) / 1.75, accuracy: 1e-9)

        // Đặc tả lấy đúng dạng câu này làm ví dụ, nên nó là YÊU CẦU chứ không phải trang trí.
        XCTAssertTrue(finding.explanation.contains("doanh_thu = 500"), finding.explanation)
        XCTAssertTrue(finding.explanation.contains("×IQR trên Q3"), finding.explanation)
        XCTAssertTrue(finding.explanation.contains("Q3 = 12.75"), finding.explanation)
    }

    func testIQRKhongDoDuocPhanTanThiKHONGKetLuan() throws {
        // Bảy giá trị bằng nhau và một điểm lệch: Q1 = Q3 nên IQR = 0. Chia cho 0 sẽ cho ra
        // "vô cùng lần IQR" và đánh dấu mọi thứ khác 5 — vô nghĩa. Không đo được thì im lặng.
        let report = try AnomalyDetector.detect(
            [5, 5, 5, 5, 5, 5, 5, 900], column: "x", method: .iqr())
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertTrue(report.methodology.contains("IQR = 0"), report.methodology)
        XCTAssertTrue(report.methodology.contains("KHÔNG kết luận"), report.methodology)
    }

    // MARK: - z-score, và vì sao nó là lựa chọn tồi trên dữ liệu bẩn

    func testZScoreBiCHINHDIEMCUCDOANLAMCHOMU() throws {
        // Đây là lý do đặc tả đòi khuyến nghị MAD khi phân bố lệch, và là lý do phương pháp mặc
        // định không được chọn thay người dùng trong im lặng.
        //
        // 500 kéo trung bình lên 60,4 và độ lệch chuẩn lên 154 — chính nó thổi phồng cái thước
        // dùng để đo nó. Với 10 điểm, |z| lớn nhất có thể là (n−1)/√n ≈ 2,85 < 3, nên z-score
        // ngưỡng 3 KHÔNG THỂ tìm ra bất kỳ điểm nào. Không phải nó bỏ sót vì kém may.
        let zReport = try AnomalyDetector.detect(spiked, column: "doanh_thu", method: .zScore())
        XCTAssertTrue(zReport.findings.isEmpty, "z-score ngưỡng 3 mù trên n = 10")

        // MAD dùng trung vị và độ lệch tuyệt đối trung vị — điểm cực đoan không kéo được chúng.
        let madReport = try AnomalyDetector.detect(spiked, column: "doanh_thu", method: .mad())
        XCTAssertEqual(madReport.findings.map(\.row), [6])

        // Và skewness bắt được chính tình huống ấy, nên khuyến nghị là MAD.
        XCTAssertGreaterThan(
            abs(AnomalyDetector.skewness(spiked)), AnomalyDetector.skewedThreshold)
        XCTAssertEqual(AnomalyDetector.recommendedMethod(for: spiked), .mad())
    }

    func testZScoreTimDuocTrenDayCANDOI() throws {
        // Đối chứng ngược cho bài trên: cùng thuật toán, dữ liệu đủ lớn và cân đối thì nó CHẠY.
        // Thiếu bài này thì bài trên chỉ chứng minh được "hàm luôn trả về rỗng".
        var values = (0..<200).map { Double($0 % 20) + 40 }   // 40…59, đều
        values.append(200)
        let report = try AnomalyDetector.detect(values, column: "x", method: .zScore())
        XCTAssertEqual(report.findings.map(\.row), [200])
        XCTAssertTrue(report.methodology.contains("Welford"), report.methodology)
    }

    func testKhuyenNghiZScoreKhiPhanBoCANDOI() {
        // Đối chứng cho `testZScoreBiCHINHDIEMCUCDOANLAMCHOMU`: nếu khuyến nghị LÚC NÀO cũng
        // trả về MAD thì bài kia chẳng chứng minh được gì.
        //
        // Lưu ý dãy 40…59 cộng thêm một điểm 200 ở bài trên có skewness 9,5 — tức nó LỆCH, và
        // khuyến nghị đúng cho nó vẫn là MAD. Một dãy cân đối phải không có điểm cực đoan nào.
        let symmetric = (0..<200).map { Double($0 % 20) + 40 }
        XCTAssertLessThan(abs(AnomalyDetector.skewness(symmetric)), 0.1)
        XCTAssertEqual(AnomalyDetector.recommendedMethod(for: symmetric), .zScore())
    }

    // MARK: - MAD

    func testMADDungCHUNGHangSoVoiQualityScorer() {
        // Đặc tả FR-DQR-002 nói chiều ACCURACY "tái dùng ĐÚNG thuật toán FR-MIN-001". Hai bản
        // hiện thực rời nhau sẽ trôi ra xa nhau, và người dùng thấy điểm chất lượng nói khác
        // bảng bất thường trên cùng một cột. Bài kiểm này giữ chúng dính vào nhau.
        XCTAssertEqual(QualityScorer.madSigmaFactor, AnomalyDetector.madSigmaFactor)
        XCTAssertEqual(AnomalyDetector.madSigmaFactor, 1.4826)
    }

    func testMADBangKhongThiKHONGKetLuan() throws {
        // Quá nửa giá trị bằng trung vị → MAD = 0. Nếu chia liều thì mọi giá trị khác trung vị
        // đều thành "vô cùng lần MAD" và bị đánh dấu hết.
        let report = try AnomalyDetector.detect(
            [7, 7, 7, 7, 7, 7, 8, 9], column: "x", method: .mad())
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertTrue(report.methodology.contains("MAD = 0"), report.methodology)
    }

    func testZScoreKhiMOIGIATRIBANGNHAU() throws {
        // Độ lệch chuẩn = 0 → mọi z là 0/0. Phải nói ra chứ không trả về nan rồi so sánh với
        // ngưỡng (nan > 3 là false, nên nó sẽ "chạy đúng" một cách tình cờ — và ngừng chạy
        // đúng ngay khi ai đó đổi dấu so sánh).
        let report = try AnomalyDetector.detect(
            [7, 7, 7, 7, 7], column: "x", method: .zScore())
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertTrue(report.methodology.contains("độ lệch chuẩn = 0"), report.methodology)
    }

    // MARK: - Tính chất chung

    func testBoQuaOTRONGVaGiuNGUYENCHISOHANG() throws {
        // Cột số có ô rỗng là chuyện thường; `Double.nan` không được kéo trung bình thành nan,
        // và quan trọng hơn: hàng thứ 6 vẫn phải báo là hàng thứ 6 dù ba hàng trước bị bỏ qua.
        let values: [Double] = [10, .nan, 12, .nan, 11, 900, 13, .nan, 12]
        let report = try AnomalyDetector.detect(values, column: "x", method: .iqr())
        XCTAssertEqual(report.checked, 6, "chỉ đếm ô có số")
        XCTAssertEqual(report.findings.map(\.row), [5])
    }

    func testTatDinh_ChayHaiLanChoCungKetQua() throws {
        // NFR-MIN-02. Không có seed vì không có ngẫu nhiên — nhưng "không có ngẫu nhiên" là một
        // khẳng định cần được kiểm, không phải một điều hiển nhiên.
        let first = try AnomalyDetector.detect(spiked, column: "x", method: .mad())
        let second = try AnomalyDetector.detect(spiked, column: "x", method: .mad())
        XCTAssertEqual(first, second)
    }

    func testKhoiPhuongPhapNoiRoKHONGDungThuVienML() throws {
        // NFR-MIN-04 đòi mọi kết quả kèm khối "Phương pháp". Đây là ràng buộc kiểm được.
        let report = try AnomalyDetector.detect(spiked, column: "x", method: .iqr(k: 2))
        XCTAssertTrue(report.methodology.hasPrefix("Phương pháp: IQR (k = 2)"), report.methodology)
        XCTAssertTrue(report.methodology.contains("không dùng thư viện học máy"))
        XCTAssertTrue(report.methodology.contains("TẤT ĐỊNH"))
    }

    func testHuyGiuaChungNemLoi() {
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(
            try AnomalyDetector.detect(
                spiked, column: "x", method: .iqr(), cancelToken: token))
        // Đối chứng: cùng lời gọi với token CHƯA huỷ thì chạy bình thường. Thiếu vế này thì
        // bài trên vẫn xanh kể cả khi `detect` ném vì một lý do hoàn toàn khác.
        XCTAssertNoThrow(
            try AnomalyDetector.detect(
                spiked, column: "x", method: .iqr(), cancelToken: CancelToken()))
    }

    func testDayQuaNganThiNoiKhongDuDuLieu() throws {
        let report = try AnomalyDetector.detect([42], column: "x", method: .mad())
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertTrue(report.methodology.contains("Không đủ dữ liệu"))
        XCTAssertEqual(report.rate, 0, "không chia cho 0")
    }
}

// MARK: - Đa biến

final class MahalanobisTests: XCTestCase {

    /// Lý do tồn tại của cả vế đa biến, gói trong một bài kiểm.
    func testBatDuocDIEMLECHKHOIQUANHEMaDonBienKhongTheThay() throws {
        // `y` bám sát `x` (có nhiễu nhỏ để Σ không suy biến). Rồi cắm vào một điểm (5, 16):
        // x = 5 nằm gọn trong 1…20, y = 16 cũng nằm gọn trong 1…20. Xét RIÊNG từng cột thì
        // không cột nào có gì lạ. Nhưng cặp (5, 16) nằm rất xa đường y ≈ x.
        var rows: [[Double]] = []
        for i in 1...20 {
            let x = Double(i)
            let jitter: Double = i % 2 == 0 ? 0.5 : -0.5
            rows.append([x, x + jitter])
        }
        rows.append([5, 16])

        // Đối chứng đơn biến TRƯỚC: chứng minh rằng bài này thật sự khó, chứ không phải dễ.
        let xs = rows.map { $0[0] }, ys = rows.map { $0[1] }
        let xReport = try AnomalyDetector.detect(xs, column: "x", method: .zScore())
        let yReport = try AnomalyDetector.detect(ys, column: "y", method: .zScore())
        XCTAssertTrue(xReport.findings.isEmpty, "cột x xét riêng: không có gì lạ")
        XCTAssertTrue(yReport.findings.isEmpty, "cột y xét riêng: không có gì lạ")

        // Đa biến thì thấy.
        let result = try AnomalyDetector.mahalanobis(rows: rows, columns: ["x", "y"])
        XCTAssertNil(result.refusal)
        XCTAssertEqual(result.findings.map(\.row), [20], "đúng hàng vừa cắm vào")
        let finding = try XCTUnwrap(result.findings.first)
        XCTAssertTrue(finding.explanation.contains("Mahalanobis"), finding.explanation)

        // Phân rã leave-one-out (FR-MIN-008) phải chia gần ĐỀU cho hai cột — và đó là câu trả
        // lời đúng, không phải một kết quả nhạt nhoà: không cột nào tự nó sai (hai bài đối
        // chứng z-score ở trên đã chứng minh), cái lệch nằm ở TỔ HỢP. Một phân rã đổ 95% cho
        // một cột ở đây mới là phân rã sai.
        XCTAssertTrue(finding.explanation.contains("tổ hợp"), finding.explanation)
        let model = try MahalanobisModel(rows: rows, columns: ["x", "y"])
        let shares = model.contributions(of: [5, 16])
        XCTAssertEqual(shares.map(\.percent).reduce(0, +), 100, accuracy: 1e-9)
        for share in shares {
            XCTAssertEqual(share.percent, 50, accuracy: 5, "\(share.column) = \(share.percent)%")
        }
    }

    func testHaiCotKHONGTUONGQUANThiDBangCanBacHaiTongZBinhPhuong() throws {
        // Kiểm phần nghịch đảo ma trận bằng một trường hợp tính tay được: khi hai cột độc lập,
        // Σ là ma trận chéo, nên Σ⁻¹ cũng chéo với phần tử 1/phương sai, và
        //     d² = z₁² + z₂².
        // Nếu `invert` sai ở bất kỳ đâu thì đẳng thức này vỡ ngay. Đây cũng là lý do ngưỡng
        // mặc định 3 đọc được như ngưỡng z-score quen thuộc.
        //
        // Dựng dữ liệu trực giao: x chạy 1…10 lặp lại, y đổi theo khối — hiệp phương sai chéo
        // triệt tiêu chính xác.
        var rows: [[Double]] = []
        for block in 0..<10 {
            for i in 1...10 { rows.append([Double(i), Double(block)]) }
        }
        let result = try AnomalyDetector.mahalanobis(
            rows: rows, columns: ["x", "y"], threshold: 0)
        XCTAssertNil(result.refusal)

        let xs = rows.map { $0[0] }, ys = rows.map { $0[1] }
        func zed(_ values: [Double], _ value: Double) -> Double {
            let n = Double(values.count)
            let mean = values.reduce(0, +) / n
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / (n - 1)
            return (value - mean) / variance.squareRoot()
        }
        for row in [0, 7, 42, 99] {
            let zx: Double = zed(xs, rows[row][0])
            let zy: Double = zed(ys, rows[row][1])
            let expected: Double = (zx * zx + zy * zy).squareRoot()
            let actual = try XCTUnwrap(result.findings.first { $0.row == row }).score
            XCTAssertEqual(actual, expected, accuracy: 1e-9, "hàng \(row)")
        }
    }

    func testCotLaTOHOPTUYENTINHThiTUCHOI_KhongBiaRaSo() throws {
        // `thanh_tien = so_luong × don_gia` với đơn giá cố định là cột phụ thuộc tuyến tính →
        // Σ suy biến, không có nghịch đảo. Chỗ này dễ cám dỗ dùng pseudo-inverse cho "chạy
        // được", và kết quả sẽ là những con số trông hợp lý mà không ai kiểm được.
        let rows: [[Double]] = (1...30).map { [Double($0), Double($0) * 25] }
        let result = try AnomalyDetector.mahalanobis(
            rows: rows, columns: ["so_luong", "thanh_tien"])
        XCTAssertTrue(result.findings.isEmpty)
        let refusal = try XCTUnwrap(result.refusal)
        XCTAssertTrue(refusal.contains("suy biến"), refusal)
        // Từ chối mà không nói cách sửa thì người dùng đứng lại ở đó.
        XCTAssertTrue(refusal.contains("Bỏ bớt một cột"), refusal)

        // Đối chứng: bỏ quan hệ tuyến tính đi thì CHẤM ĐƯỢC. Thiếu vế này thì bài trên vẫn
        // xanh kể cả khi hàm từ chối mọi thứ.
        var independent = rows
        for i in stride(from: 0, to: 30, by: 2) { independent[i][1] += 40 }
        XCTAssertNil(try AnomalyDetector.mahalanobis(
            rows: independent, columns: ["so_luong", "thanh_tien"]).refusal)
    }

    func testMotCotThiCHIDUONGSangZScore() throws {
        // Mahalanobis một chiều rút gọn về |z| — chạy được, nhưng tốn một ma trận 1×1 và một
        // phép khử Gauss cho thứ mà một lượt Welford làm xong. Chỉ đường thay vì im lặng chạy.
        let result = try AnomalyDetector.mahalanobis(
            rows: (1...30).map { [Double($0)] }, columns: ["x"])
        XCTAssertTrue(result.findings.isEmpty)
        let refusal = try XCTUnwrap(result.refusal)
        XCTAssertTrue(refusal.contains("z-score"), refusal)
    }

    func testKhongDuHangThiTUCHOI() throws {
        // 3 hàng trên 3 cột: Σ chắc chắn suy biến vì lý do hình học, không phải vì dữ liệu.
        // Nói thẳng "cần nhiều hơn 3 hàng" hữu ích hơn là báo "ma trận suy biến".
        let result = try AnomalyDetector.mahalanobis(
            rows: [[1, 2, 3], [4, 5, 6], [7, 8, 10]], columns: ["a", "b", "c"])
        let refusal = try XCTUnwrap(result.refusal)
        XCTAssertTrue(refusal.contains("Cần nhiều hơn 3 hàng"), refusal)
    }

    func testHangTHIEUSOBiLoaiNhungChiSoHangGocGiuNguyen() throws {
        var rows: [[Double]] = (1...20).map { [Double($0), Double($0) + 0.5] }
        rows.insert([.nan, 3], at: 0)
        rows.insert([7, .nan], at: 5)
        rows.append([5, 16])
        let result = try AnomalyDetector.mahalanobis(rows: rows, columns: ["x", "y"])
        XCTAssertEqual(result.checked, 21, "hai hàng thiếu số bị loại khỏi phép tính")
        XCTAssertEqual(result.findings.map(\.row), [rows.count - 1],
                       "vẫn phải báo đúng chỉ số hàng GỐC")
    }

    func testNghichDaoDungTrenMaTranBietTruoc() throws {
        // [[4, 7], [2, 6]] có định thức 10, nghịch đảo [[0.6, −0.7], [−0.2, 0.4]].
        let inverse = AnomalyDetector.invert([[4, 7], [2, 6]])
        let m = try XCTUnwrap(inverse)
        XCTAssertEqual(m[0][0], 0.6, accuracy: 1e-12)
        XCTAssertEqual(m[0][1], -0.7, accuracy: 1e-12)
        XCTAssertEqual(m[1][0], -0.2, accuracy: 1e-12)
        XCTAssertEqual(m[1][1], 0.4, accuracy: 1e-12)
        XCTAssertNil(AnomalyDetector.invert([[1, 2], [2, 4]]), "định thức 0")
    }
}
