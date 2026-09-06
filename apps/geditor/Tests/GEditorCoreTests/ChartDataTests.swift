import XCTest
@testable import GEditorCore

/// FR-QRY-004 — phần TÍNH của biểu đồ. Số học thuần, không dựng cửa sổ nào.
final class ChartDataTests: XCTestCase {

    // MARK: - Rút gọn LTTB (NFR-QRY-02)

    func testKhongRutGonKhiDuoiTRAN() {
        let points = (0 ..< 100).map { ChartData.Point(x: Double($0), y: Double($0)) }
        let series = ChartData.series(name: "a", points: points)
        XCTAssertEqual(series.points.count, 100)
        // Ghi chú rỗng KHI VÀ CHỈ KHI không rút gọn — đó là hợp đồng của kiểu này.
        XCTAssertTrue(series.samplingNote.isEmpty)
    }

    func testRutGonThiNOIRA() {
        let points = (0 ..< 10_000).map {
            ChartData.Point(x: Double($0), y: sin(Double($0) / 100))
        }
        let series = ChartData.series(name: "a", points: points, limit: 500)
        XCTAssertEqual(series.points.count, 500)
        XCTAssertEqual(series.originalCount, 10_000)
        // Vẽ một triệu điểm xuống 800 điểm ảnh rồi im lặng là nói dối bằng hình.
        XCTAssertTrue(series.samplingNote.contains("10000"), series.samplingNote)
        XCTAssertTrue(series.samplingNote.contains("KHÔNG hiện mọi điểm"), series.samplingNote)
    }

    func testGIUdiemDAUvaCUOI() {
        let points = (0 ..< 5_000).map { ChartData.Point(x: Double($0), y: Double($0 % 7)) }
        let reduced = ChartData.downsample(points, to: 100)
        // Một biểu đồ mất điểm đầu là một biểu đồ bắt đầu ở chỗ khác với dữ liệu.
        XCTAssertEqual(reduced.first?.x, 0)
        XCTAssertEqual(reduced.last?.x, 4_999)
    }

    func testGIUDINHNHONmaLayMauDEUseLamMAT() {
        // Đường phẳng, một đỉnh nhọn duy nhất ở giữa. Lấy mẫu đều mỗi 100 điểm sẽ bỏ qua nó
        // hoàn toàn — và với dữ liệu doanh thu hay đo lường thì đỉnh nhọn thường CHÍNH LÀ thứ
        // người ta mở biểu đồ ra để tìm.
        var points = (0 ..< 2_000).map { ChartData.Point(x: Double($0), y: 1.0) }
        points[977] = ChartData.Point(x: 977, y: 500)
        let reduced = ChartData.downsample(points, to: 100)
        XCTAssertTrue(reduced.contains { $0.y == 500 },
                      "đỉnh nhọn biến mất sau khi rút gọn — LTTB không làm việc của nó")

        // Đối chứng: lấy mẫu ĐỀU thật sự làm mất nó. Không có dòng này thì bài trên không
        // chứng minh được LTTB hơn gì.
        let naive = stride(from: 0, to: points.count, by: points.count / 100).map { points[$0] }
        XCTAssertFalse(naive.contains { $0.y == 500 })
    }

    func testRutGonGIUthuTuTruc() {
        let points = (0 ..< 3_000).map {
            ChartData.Point(x: Double($0), y: Double.random(in: 0 ... 1))
        }
        let reduced = ChartData.downsample(points, to: 200)
        XCTAssertEqual(reduced, reduced.sorted { $0.x < $1.x },
                       "điểm ra không còn tăng theo trục X — đường vẽ sẽ tự cắt chính nó")
    }

    // MARK: - Phân bố

    func testHistogramDemDUtatCaGiaTri() {
        let values = (0 ..< 1_000).map { Double($0) }
        let bins = ChartData.histogram(values)
        XCTAssertEqual(bins.reduce(0) { $0 + $1.count }, 1_000,
                       "tổng các khoảng phải bằng số điểm — có điểm rơi ra ngoài")
    }

    func testGiaTriLONNHATkhongRoiRaNGOAI() {
        // Không có phép kẹp ở khoảng cuối thì đúng một điểm — điểm cao nhất — biến mất khỏi
        // mọi biểu đồ phân bố.
        let bins = ChartData.histogram([1, 2, 3, 4, 5, 100])
        XCTAssertEqual(bins.reduce(0) { $0 + $1.count }, 6)
        XCTAssertGreaterThanOrEqual(bins.last?.upperBound ?? 0, 100)
    }

    func testMoiGiaTriBANGNHAUthiMOTkhoang() {
        // Chia nó thành hai mươi khoảng rỗng quanh một cột là vẽ ra một phân bố không tồn tại.
        let bins = ChartData.histogram([5, 5, 5, 5])
        XCTAssertEqual(bins.count, 1)
        XCTAssertEqual(bins[0].count, 4)
    }

    func testGiaTriCUCDOANkhongKeoLechSOKHOANG() {
        // Freedman–Diaconis dựa vào IQR nên một ô 999 tỷ không làm cả biểu đồ thành một cột.
        var values = (0 ..< 500).map { Double($0 % 50) }
        values.append(999_999_999)
        let bins = ChartData.histogram(values)
        XCTAssertGreaterThanOrEqual(bins.count, 5)
        XCTAssertLessThanOrEqual(bins.count, 60)
    }

    // MARK: - Hộp

    func testBoxKhopVoiPHANVIchuan() {
        // Kiểm bằng dãy tính tay: 1…9, trung vị 5, q1 = 3, q3 = 7 (R type 7 / numpy mặc định).
        let stats = ChartData.box([1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(stats?.median, 5)
        XCTAssertEqual(stats?.q1, 3)
        XCTAssertEqual(stats?.q3, 7)
    }

    func testRAUdungOgiaTriTHATganNhat() {
        // 1…9 rồi một điểm 100. IQR nhỏ nên 100 là điểm ngoài; râu trên phải dừng ở 9 — giá trị
        // THẬT gần nhất — chứ không dừng ở con số `q3 + 1,5×IQR`.
        let stats = ChartData.box([1, 2, 3, 4, 5, 6, 7, 8, 9, 100])
        XCTAssertEqual(stats?.outliers, [100])
        XCTAssertEqual(stats?.upperWhisker, 9)
        XCTAssertEqual(stats?.maximum, 100, "max vẫn là 100 — râu và max là hai thứ khác nhau")
    }

    func testBoxTraNILkhiKhongCoSO() {
        XCTAssertNil(ChartData.box([]))
        XCTAssertNil(ChartData.box([.nan, .infinity]))
    }

    // MARK: - Chọn cột từ kết quả truy vấn

    func testChonCotSODAUTIENlamTrucY() {
        let result = CSVQueryEngine.Result(
            titles: ["tinh", "so_don", "doanh_thu"],
            rows: [["Huế", "3", "100"], ["Hà Nội", "5", "250"]])
        let series = ChartData.series(from: result)
        XCTAssertEqual(series?.name, "so_don")
        XCTAssertEqual(series?.points.map(\.y), [3, 5])
        // Cột TRƯỚC nó làm nhãn trục X.
        XCTAssertEqual(series?.points.compactMap(\.label), ["Huế", "Hà Nội"])
    }

    func testCotDAUlaSOthiNoLaKHOAchuKhongPhaiSODO() {
        // `SELECT diem, so_bai … GROUP BY 1 ORDER BY 1` — hình dạng phổ biến nhất của một câu
        // đếm phân phối. Luật "cột số ĐẦU TIÊN làm Y" chọn `diem`, không còn cột nào làm X, nên
        // biểu đồ vẽ điểm theo chỉ số hàng: một đường đi lên đều tăm tắp.
        //
        // Cách hỏng ấy nguy hiểm hơn hẳn một biểu đồ trống: nó không báo lỗi và TRÔNG HỢP LÝ.
        // Đã gặp thật khi chụp phổ điểm Toán của 1,2 triệu bài — ảnh ra một cái dốc đẹp đẽ mà
        // không liên quan gì tới phổ điểm.
        let result = CSVQueryEngine.Result(
            titles: ["diem", "so_bai"],
            rows: [["0.45", "3"], ["0.5", "1"], ["0.55", "6"]])
        let series = ChartData.series(from: result)
        XCTAssertEqual(series?.name, "so_bai", "vẽ KHOÁ thay vì vẽ số đo")
        XCTAssertEqual(series?.points.map(\.y), [3, 1, 6])
        // Và trục X phải là chính giá trị điểm, không phải chỉ số hàng.
        XCTAssertEqual(series?.points.map(\.x), [0.45, 0.5, 0.55])
    }

    func testMOTcotSOduyNhatThiVANveCotAy() {
        // Đối chứng cho bài trên: luật mới chỉ được đẩy Y sang cột kế tiếp khi CÓ cột kế tiếp.
        // Bảng một cột số thì cột ấy đúng là thứ duy nhất vẽ được.
        let result = CSVQueryEngine.Result(
            titles: ["so_bai"], rows: [["3"], ["1"], ["6"]])
        let series = ChartData.series(from: result)
        XCTAssertEqual(series?.name, "so_bai")
        XCTAssertEqual(series?.points.map(\.y), [3, 1, 6])
    }

    func testCotLANCHUthiKHONGcoiLaSO() {
        // Chỉ nhìn ô ĐẦU là đủ để một cột lẫn chữ ở hàng thứ hai làm hỏng cả biểu đồ.
        let result = CSVQueryEngine.Result(
            titles: ["a", "b"],
            rows: [["1", "10"], ["khong-phai-so", "20"]])
        let series = ChartData.series(from: result)
        XCTAssertEqual(series?.name, "b", "cột `a` lẫn chữ mà vẫn bị chọn làm trục Y")
    }

    func testBangTOANCHUthiTRANILchuKhongVeBua() {
        let result = CSVQueryEngine.Result(
            titles: ["ten", "tinh"], rows: [["An", "Huế"]])
        // Vẽ biểu đồ từ một bảng toàn chữ là vẽ ra một thứ không có nghĩa, và im lặng làm thế
        // còn tệ hơn từ chối.
        XCTAssertNil(ChartData.series(from: result))
    }

    func testBangRONGtraNIL() {
        XCTAssertNil(ChartData.series(
            from: CSVQueryEngine.Result(titles: ["a"], rows: [])))
    }

    func testOTRONGbiBOQUAchuKhongThanhKHONG() {
        // Ô rỗng thành 0 là bịa ra một điểm dữ liệu — và trên biểu đồ đường nó thành một cú
        // rơi thẳng xuống đáy mà người dùng sẽ đi tìm nguyên nhân.
        let result = CSVQueryEngine.Result(
            titles: ["a"], rows: [["1"], [nil], ["3"]])
        XCTAssertEqual(ChartData.series(from: result)?.points.map(\.y), [1, 3])
    }

    // MARK: - Vạch trục

    func testVachOsoDEP() {
        // Chia đều cho 5 sẽ ra `0 · 237 · 474 · 711` — đúng khoảng cách và vô dụng khi đọc.
        let ticks = ChartData.ticks(from: 0, to: 948)
        XCTAssertTrue(ticks.allSatisfy { $0.truncatingRemainder(dividingBy: 100) == 0 },
                      "vạch không phải số nhẩm được: \(ticks)")
        XCTAssertTrue(ticks.count >= 3 && ticks.count <= 12, "\(ticks.count) vạch")
    }

    func testVachChoKhoangNHO() {
        let ticks = ChartData.ticks(from: 0, to: 1)
        XCTAssertTrue(ticks.contains(0))
        XCTAssertTrue(ticks.contains { abs($0 - 1) < 1e-9 })
    }

    func testVachKhiBIENDOrong() {
        XCTAssertEqual(ChartData.ticks(from: 5, to: 5), [5])
    }
}
