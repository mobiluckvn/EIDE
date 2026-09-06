import XCTest
@testable import GEditorCore

final class TimeSeriesTests: XCTestCase {

    /// Chuỗi có xu hướng tăng + mùa vụ chu kỳ 4, không nhiễu.
    private func seasonal(periods: Int = 8) -> [Double] {
        var out: [Double] = []
        let pattern = [10.0, 20, 5, 15]
        for cycle in 0..<periods {
            for index in 0..<4 { out.append(100 + Double(cycle) * 8 + pattern[index]) }
        }
        return out
    }

    // MARK: - Phát hiện chu kỳ

    func testACFCaoDungTaiChuKyThat() {
        let values = seasonal()
        let atPeriod = TimeSeries.autocorrelation(values, lag: 4)
        let offPeriod = TimeSeries.autocorrelation(values, lag: 3)
        XCTAssertGreaterThan(atPeriod, offPeriod)
    }

    func testTIMDUNGChuKyCoBanChuKhongPhaiBOI() {
        // Với dữ liệu chu kỳ 4, ACF ở 8, 12, 16 cũng cao — đôi khi cao hơn vì xu hướng cộng
        // thêm. Trả về 12 là đúng về ACF và sai về ý nghĩa: nó ngốn ba lần số điểm để ước lượng
        // mùa vụ và làm mất một nửa dữ liệu huấn luyện.
        XCTAssertEqual(TimeSeries.detectPeriod(seasonal()), 4)
    }

    func testKHONGCoMuaVuThiTraVeNIL_KhongEpMotChuKy() {
        // Ép một chu kỳ lên dữ liệu không có mùa vụ sinh ra thành phần "mùa vụ" toàn nhiễu, và
        // mô hình học thuộc nhiễu ấy rồi lặp nó ra tương lai — trông thuyết phục, hoàn toàn bịa.
        var values: [Double] = []
        var generator = SeededGenerator(seed: 7)
        for _ in 0..<60 { values.append(50 + generator.nextUnit() * 2) }
        XCTAssertNil(TimeSeries.detectPeriod(values))
    }

    func testCHUOIQUANGANThiKhongKetLuanChuKy() {
        XCTAssertNil(TimeSeries.detectPeriod([1, 2, 3, 1, 2]))
    }

    // MARK: - Phân rã

    func testPHANRATaiDungLaiChuoiGoc() throws {
        // Bất biến của phân rã CỘNG: xu hướng + mùa vụ + phần dư = giá trị gốc, ở mọi điểm tính
        // được. Nếu chuẩn hoá mùa vụ sai hay trung bình trượt lệch thì đẳng thức này vỡ.
        let values = seasonal()
        let parts = try XCTUnwrap(TimeSeries.decompose(values, period: 4))
        var checked = 0
        for index in values.indices {
            guard let trend = parts.trend[index], let residual = parts.residual[index] else {
                continue
            }
            XCTAssertEqual(
                trend + parts.seasonal[index] + residual, values[index], accuracy: 1e-9,
                "điểm \(index)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 20, "phải kiểm được phần lớn chuỗi")
    }

    func testMUAVUCONGLAIBANG0() throws {
        // Không chuẩn hoá thì mùa vụ mang theo một phần mức trung bình, và mức ấy bị đếm HAI
        // LẦN — một lần trong xu hướng, một lần trong mùa vụ.
        let parts = try XCTUnwrap(TimeSeries.decompose(seasonal(), period: 4))
        let oneCycle = Array(parts.seasonal[0..<4])
        XCTAssertEqual(oneCycle.reduce(0, +), 0, accuracy: 1e-9)
    }

    func testMUAVUNHANThiTRUNGBINHBANG1() throws {
        // Quy ước chuẩn của phân rã NHÂN là các hệ số TRUNG BÌNH bằng 1 (tổng bằng m), không
        // phải NHÂN lại bằng 1. Bản đầu của bài kiểm này đòi tích bằng 1 và trượt — mã theo
        // đúng quy ước, bài kiểm hiểu sai quy ước.
        var values: [Double] = []
        for cycle in 0..<8 {
            for factor in [1.0, 1.4, 0.7, 0.9] {
                values.append((100 + Double(cycle) * 10) * factor)
            }
        }
        let parts = try XCTUnwrap(
            TimeSeries.decompose(values, period: 4, multiplicative: true))
        let oneCycle = Array(parts.seasonal[0..<4])
        XCTAssertEqual(oneCycle.reduce(0, +) / 4, 1, accuracy: 1e-9)
        // Và các hệ số phải giữ đúng TỶ LỆ giữa các mùa: 1,4 gấp đôi 0,7.
        //
        // Dung sai 3% chứ không phải 1e−6, và lý do đáng ghi lại: phân rã cổ điển KHÔNG khôi
        // phục chính xác hệ số mùa vụ của một chuỗi nhân có xu hướng. Trung bình trượt của tích
        // (xu hướng × mùa vụ) không bằng tích của trung bình trượt — còn một số hạng ghép giữa
        // hai thành phần. Đo được ở đây là 2,036 thay vì 2,000.
        //
        // Đó là giới hạn của phương pháp, không phải lỗi cài đặt, và nó là một lý do nữa để
        // `verdict` của phần dự báo phải so với baseline thay vì tin vào mô hình.
        XCTAssertEqual(oneCycle[1] / oneCycle[2], 2, accuracy: 0.06)
    }

    func testCHUKYCHANDungTrungBinhTruot2m() throws {
        // Chu kỳ chẵn cần trung bình 2×m; một cửa sổ 4 điểm không có tâm nằm trên điểm dữ liệu.
        // Bỏ qua chi tiết này làm xu hướng lệch nửa bước, và nửa bước ấy chảy hết vào mùa vụ.
        //
        // Kiểm bằng chuỗi mùa vụ THUẦN không xu hướng: xu hướng đúng phải là HẰNG SỐ.
        var values: [Double] = []
        for _ in 0..<8 { values += [10, 20, 5, 15] }
        let parts = try XCTUnwrap(TimeSeries.decompose(values, period: 4))
        let trends = parts.trend.compactMap { $0 }
        XCTAssertGreaterThan(trends.count, 20)
        for trend in trends {
            XCTAssertEqual(trend, 12.5, accuracy: 1e-9, "xu hướng phải phẳng: \(trends)")
        }
    }

    func testKhongDuHaiChuKyThiKhongPhanRa() {
        XCTAssertNil(TimeSeries.decompose([1, 2, 3, 4, 5], period: 4))
    }

    // MARK: - Sai số

    func testMAEVaMAPETinhTayDuoc() throws {
        // thật  = [10, 20, 30], khớp = [12, 18, 33]
        // sai số tuyệt đối = [2, 2, 3] → MAE = 7/3 ≈ 2,333
        // phần trăm = [20, 10, 10] → MAPE = 40/3 ≈ 13,333
        let accuracy = try XCTUnwrap(
            TimeSeries.accuracy(actual: [10, 20, 30], fitted: [12, 18, 33]))
        XCTAssertEqual(accuracy.mae, 7.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(accuracy.mape), 40.0 / 3, accuracy: 1e-12)
        XCTAssertTrue(accuracy.mapeNote.isEmpty)
    }

    func testMAPEGapSO0ThiNOIRA_KhongBoQuaTrongIMLANG() throws {
        // Bỏ qua trong im lặng biến MAPE thành con số tính trên một tập con mà không ai biết,
        // và tập con ấy lệch CÓ HỆ THỐNG — nó bỏ đúng những kỳ khó dự báo nhất.
        let accuracy = try XCTUnwrap(
            TimeSeries.accuracy(actual: [10, 0, 30, 40, 50], fitted: [12, 3, 33, 44, 45]))
        XCTAssertNotNil(accuracy.mape)
        XCTAssertTrue(accuracy.mapeNote.contains("bỏ qua 1/5"), accuracy.mapeNote)
    }

    func testQUA25PhanTramLaSO0ThiMAPEKhongTinhDuoc() throws {
        let accuracy = try XCTUnwrap(
            TimeSeries.accuracy(actual: [0, 0, 30, 40], fitted: [1, 1, 33, 44]))
        XCTAssertNil(accuracy.mape)
        XCTAssertTrue(accuracy.mapeNote.contains("quá 25%"), accuracy.mapeNote)
        XCTAssertGreaterThan(accuracy.mae, 0, "MAE vẫn tính được — nó không chia cho gì cả")
    }

    // MARK: - Dự báo, và phán xét

    func testHOLTWINTERSTHANGBaselineTrenChuoiCoCauTruc() throws {
        let comparison = try XCTUnwrap(
            try TimeSeries.forecast(seasonal(periods: 10), horizon: 4))
        XCTAssertEqual(comparison.period, 4)
        XCTAssertTrue(comparison.modelBeatsBaselines, comparison.verdict)
        XCTAssertTrue(comparison.verdict.contains("thắng cả hai baseline"), comparison.verdict)
        XCTAssertEqual(comparison.chosen.future.count, 4)

        // Dự báo phải tiếp tục ĐÚNG mẫu: kỳ tiếp theo là vị trí 0 của chu kỳ, tức mức + 10.
        let expected = 100 + 10.0 * 8 + 10
        XCTAssertEqual(comparison.chosen.future[0], expected, accuracy: expected * 0.1)
    }

    func testMOHINHTHUABaselineThiNOITHANG() throws {
        // Đây là yêu cầu cốt lõi của FR-MIN-004, nên nó cần dữ liệu mà mô hình THẬT SỰ thua.
        //
        // Bước nhảy ngẫu nhiên (random walk): giá trị tiếp theo là giá trị hiện tại cộng một
        // nhiễu độc lập. Không có xu hướng để ngoại suy, không có mùa vụ để học — dự báo tốt
        // nhất có thể ĐÚNG BẰNG naive. Holt-Winters sẽ đuổi theo nhiễu và thua.
        var values: [Double] = [100]
        var generator = SeededGenerator(seed: 2_026)
        for _ in 0..<80 {
            values.append(values[values.count - 1] + (generator.nextUnit() - 0.5) * 20)
        }
        let comparison = try XCTUnwrap(
            try TimeSeries.forecast(values, horizon: 5, period: 4))

        XCTAssertFalse(comparison.modelBeatsBaselines, comparison.verdict)
        XCTAssertTrue(comparison.bestModel.isBaseline)
        XCTAssertTrue(comparison.verdict.contains("MÔ HÌNH THUA BASELINE"), comparison.verdict)
        // Và phải nói RÕ nên dùng cái nào thay thế.
        XCTAssertTrue(comparison.verdict.contains("nên dùng nó"), comparison.verdict)
        XCTAssertTrue(comparison.methodology.contains("MÔ HÌNH THUA"), comparison.methodology)
    }

    func testBASELINELUONDuocChay_KhongPhaiTuyChon() throws {
        let comparison = try XCTUnwrap(
            try TimeSeries.forecast(seasonal(periods: 10), horizon: 3))
        let models = Set(comparison.baselines.map(\.model))
        XCTAssertEqual(models, [.naive, .seasonalNaive])
        XCTAssertTrue(comparison.baselines.allSatisfy { $0.accuracy != nil })
    }

    func testKHONGDUHAICHUKYThiLUIVeNaive_KhongBiaMuaVu() throws {
        // Khớp mùa vụ vào nhiễu của MỘT chu kỳ duy nhất rồi lặp nó ra tương lai là cách sinh ra
        // một dự báo trông rất thuyết phục và hoàn toàn bịa.
        let short: [Double] = [10, 20, 5, 15, 11]
        let comparison = try XCTUnwrap(try TimeSeries.forecast(short, horizon: 3, period: 4))
        XCTAssertEqual(comparison.chosen.model, .naive)
        XCTAssertNil(comparison.period)
        XCTAssertTrue(comparison.verdict.contains("chưa đủ hai chu kỳ"), comparison.verdict)
    }

    func testDANGNHANGapGiaTriKHONGDUONGThiChuyenSangCONG() throws {
        var values: [Double] = []
        for cycle in 0..<8 {
            for offset in [0.0, 5, -3, 2] { values.append(Double(cycle) - 4 + offset) }
        }
        let comparison = try XCTUnwrap(try TimeSeries.forecast(
            values, horizon: 2, model: .holtWintersMultiplicative, period: 4))
        XCTAssertEqual(comparison.chosen.model, .holtWintersAdditive)
        XCTAssertTrue(comparison.verdict.contains("dạng NHÂN không dùng được"), comparison.verdict)
    }

    // MARK: - Khoảng tin cậy

    func testDAI95RONGHONDAI80VaCaHaiNOIRaTheoTam() throws {
        let comparison = try XCTUnwrap(
            try TimeSeries.forecast(seasonal(periods: 10), horizon: 6))
        let forecast = comparison.chosen
        for step in 0..<6 {
            XCTAssertLessThan(forecast.lower95[step], forecast.lower80[step], "bước \(step)")
            XCTAssertGreaterThan(forecast.upper95[step], forecast.upper80[step], "bước \(step)")
            XCTAssertLessThanOrEqual(forecast.lower80[step], forecast.future[step])
            XCTAssertGreaterThanOrEqual(forecast.upper80[step], forecast.future[step])
        }
        // Nới dần: dải ở bước cuối phải rộng hơn dải ở bước đầu.
        XCTAssertGreaterThan(
            forecast.upper95[5] - forecast.lower95[5],
            forecast.upper95[0] - forecast.lower95[0])
    }

    func testKHOANGTINCAYTUKHAILaXAPXI() throws {
        // Không nói ra thì người dùng đọc một dải 95% như một bảo đảm 95%.
        let comparison = try XCTUnwrap(
            try TimeSeries.forecast(seasonal(periods: 10), horizon: 3))
        XCTAssertTrue(
            comparison.methodology.contains("KHOẢNG TIN CẬY LÀ XẤP XỈ"), comparison.methodology)
        XCTAssertTrue(comparison.methodology.contains("QUÁ CHẬM"), comparison.methodology)
    }

    // MARK: - Tính chất chung

    func testTATDINH() throws {
        let values = seasonal(periods: 10)
        let first = try XCTUnwrap(try TimeSeries.forecast(values, horizon: 4))
        let second = try XCTUnwrap(try TimeSeries.forecast(values, horizon: 4))
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.methodology.contains("TẤT ĐỊNH"))
        // Tham số quét lưới phải nằm trong kết quả để chạy lại được.
        XCTAssertTrue(first.chosen.parameters.contains("α = "), first.chosen.parameters)
    }

    func testCHUOIQUANGANThiTraVeNIL() throws {
        XCTAssertNil(try TimeSeries.forecast([1, 2], horizon: 3))
        XCTAssertNil(try TimeSeries.forecast(seasonal(), horizon: 0))
    }

    func testHuyGiuaChung() {
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(try TimeSeries.forecast(
            seasonal(periods: 10), horizon: 4, cancelToken: token))
    }

    func testNAIVEVaSEASONALNAIVEDungMotDuongMa() throws {
        // Hai baseline là cùng một phép "lấy lại giá trị cách đây `period` bước". Hai bản riêng
        // là hai chỗ để lệch nhau.
        let comparison = try XCTUnwrap(
            try TimeSeries.forecast(seasonal(periods: 10), horizon: 4))
        let naive = try XCTUnwrap(comparison.baselines.first { $0.model == .naive })
        let seasonalNaive = try XCTUnwrap(
            comparison.baselines.first { $0.model == .seasonalNaive })

        // naive: mọi kỳ tương lai đều bằng giá trị cuối cùng.
        let values = seasonal(periods: 10)
        XCTAssertEqual(naive.future, [Double](repeating: values[values.count - 1], count: 4))
        // seasonal-naive: lặp lại đúng chu kỳ cuối.
        XCTAssertEqual(seasonalNaive.future, Array(values.suffix(4)))
    }
}

// MARK: - Biểu đồ dự báo

final class ForecastChartTests: XCTestCase {

    private let layout = ChartRender.Layout(width: 500, height: 320)

    private func build(horizon: Int = 4) -> [ChartRender.Primitive] {
        let history = (0..<20).map { 100 + Double($0) * 2 }
        let future = (0..<horizon).map { 140 + Double($0) * 2 }
        return ChartRender.forecastPrimitives(
            history: history, fitted: history.map { $0 - 1 }, future: future,
            lower80: future.map { $0 - 5 }, upper80: future.map { $0 + 5 },
            lower95: future.map { $0 - 10 }, upper95: future.map { $0 + 10 },
            layout: layout, title: "thử")
    }

    func testCoDUHaiDaiVaBaDuong() {
        let primitives = build()
        var polygons = 0, polylines = 0
        for primitive in primitives {
            if case .polygon = primitive { polygons += 1 }
            if case .polyline = primitive { polylines += 1 }
        }
        XCTAssertEqual(polygons, 2, "dải 80% và dải 95%")
        XCTAssertEqual(polylines, 3, "lịch sử · đường khớp · dự báo")
    }

    func testDAI95RONGHONDAI80TrenHINH() throws {
        var areas: [Double] = []
        for primitive in build() {
            guard case let .polygon(points, _, _) = primitive else { continue }
            // Diện tích theo công thức dây giày — dải nào phủ nhiều pixel hơn thì rộng hơn.
            var area = 0.0
            for index in points.indices {
                let next = points[(index + 1) % points.count]
                area += points[index].0 * next.1 - next.0 * points[index].1
            }
            areas.append(abs(area) / 2)
        }
        XCTAssertEqual(areas.count, 2)
        XCTAssertGreaterThan(areas[0], areas[1], "dải 95 vẽ TRƯỚC nên nó phải là dải rộng hơn")
    }

    func testTHANGDOTinhTrenCaMEPNGOAICuaDai() {
        // Nếu thang chỉ tính trên lịch sử và dự báo thì dải 95% bị cắt cụt ở mép khung, và
        // người đọc thấy một dải HẸP hơn thực tế — sai đúng theo hướng nguy hiểm.
        //
        // Dựng một dải rất rộng rồi kiểm rằng mọi đỉnh của nó nằm trong khung vẽ.
        let history = (0..<10).map { 100 + Double($0) }
        let future = [110.0, 111, 112]
        let primitives = ChartRender.forecastPrimitives(
            history: history, fitted: history.map { $0 }, future: future,
            lower80: future.map { $0 - 40 }, upper80: future.map { $0 + 40 },
            lower95: future.map { $0 - 200 }, upper95: future.map { $0 + 200 },
            layout: layout)
        for primitive in primitives {
            guard case let .polygon(points, _, _) = primitive else { continue }
            for point in points {
                XCTAssertGreaterThanOrEqual(point.1, layout.insetTop - 0.5)
                XCTAssertLessThanOrEqual(
                    point.1, layout.insetTop + layout.plotHeight + 0.5)
            }
        }
    }

    func testCoVACHRANHGIOIQuaKhuVaTuongLai() throws {
        // Thiếu nó thì người đọc không biết đường cong chuyển từ dữ liệu sang phỏng đoán ở đâu.
        let primitives = build()
        let labels = primitives.compactMap { primitive -> String? in
            guard case let .text(_, _, string, _, _, _) = primitive else { return nil }
            return string
        }
        XCTAssertTrue(labels.contains("dự báo →"), "\(labels)")
    }

    func testDaiNOILIENTuDiemLichSuCUOI() throws {
        // Dải lơ lửng tách khỏi đường lịch sử đọc thành "có một khoảng trống không biết gì",
        // trong khi kỳ đầu tiên chính là chỗ ta chắc chắn nhất.
        let primitives = build()
        var historyEnd: (Double, Double)?
        for primitive in primitives {
            if case let .polyline(points, stroke, _) = primitive, stroke == .series1 {
                historyEnd = points.last
            }
        }
        let end = try XCTUnwrap(historyEnd)
        for primitive in primitives {
            guard case let .polygon(points, _, _) = primitive, let first = points.first else {
                continue
            }
            XCTAssertEqual(first.0, end.0, accuracy: 0.001)
            XCTAssertEqual(first.1, end.1, accuracy: 0.001)
        }
    }

    func testDaiVaoCaSVG() {
        let svg = ChartRender.svg(build(), layout: layout)
        XCTAssertTrue(svg.contains("<polygon"), "dải phải có trong ảnh xuất ra")
        XCTAssertTrue(svg.contains("fill-opacity"), svg.prefix(400).description)
    }
}
