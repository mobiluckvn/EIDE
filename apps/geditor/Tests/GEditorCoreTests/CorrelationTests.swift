import XCTest
@testable import GEditorCore

final class CorrelationTests: XCTestCase {

    // MARK: - Pearson

    func testQUANHETUYENTINHHOANHAOChoDungCong1VaTru1() throws {
        let x: [Double] = [1, 2, 3, 4, 5]
        XCTAssertEqual(try XCTUnwrap(Correlation.pearson(x, [2, 4, 6, 8, 10])), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(Correlation.pearson(x, [10, 8, 6, 4, 2])), -1, accuracy: 1e-12)
        // Hệ số góc và điểm cắt KHÔNG ảnh hưởng: r đo hình dạng, không đo thang đo.
        XCTAssertEqual(
            try XCTUnwrap(Correlation.pearson(x, [1003, 1006, 1009, 1012, 1015])), 1,
            accuracy: 1e-12)
    }

    func testGiaTriTinhTAYDuoc() throws {
        // x = [1,2,3,4,5], y = [2,1,4,3,5].
        // x̄ = 3, ȳ = 3. dx = [−2,−1,0,1,2], dy = [−1,−2,1,0,2].
        // Σdxdy = 2+2+0+0+4 = 8. Σdx² = 10. Σdy² = 1+4+1+0+4 = 10.
        // r = 8 / √100 = 0,8.
        let r = try XCTUnwrap(Correlation.pearson([1, 2, 3, 4, 5], [2, 1, 4, 3, 5]))
        XCTAssertEqual(r, 0.8, accuracy: 1e-12)
    }

    func testCotHANGThiKHONGDoDuoc_KhongPhaiBang0() {
        // 0 nghĩa là "đã đo, không có liên hệ". Cột hằng nghĩa là "không đo được". Trả 0 ở đây
        // là nói một câu sai, và nói theo hướng người đọc sẽ tin.
        XCTAssertNil(Correlation.pearson([5, 5, 5, 5], [1, 2, 3, 4]))
        XCTAssertNil(Correlation.pearson([1, 2, 3, 4], [7, 7, 7, 7]))
    }

    func testKepVe1_KhongDeRa1_0000000000000002() throws {
        // Cauchy–Schwarz bảo đảm |r| ≤ 1 về toán, nhưng phép chia dấu phẩy động thì không.
        // Bảng in "1,00" cạnh một ô "1,00" mà thang màu vẽ khác nhau là thứ không giải thích được.
        var xs: [Double] = []
        for i in 0..<500 { xs.append(1_000_000 + Double(i) * 0.001) }
        let ys = xs.map { $0 * 3 - 7 }
        let r = try XCTUnwrap(Correlation.pearson(xs, ys))
        XCTAssertLessThanOrEqual(r, 1)
        XCTAssertEqual(r, 1, accuracy: 1e-9)
    }

    // MARK: - Spearman và cái bẫy hạng trùng

    func testHANGTRUNGBINHChoGiaTriBANGNHAU() {
        // [10, 20, 20, 30] → [1, 2.5, 2.5, 4].
        XCTAssertEqual(Correlation.averageRanks([10, 20, 20, 30]), [1, 2.5, 2.5, 4])
        // Cả bốn bằng nhau → tất cả hạng 2,5.
        XCTAssertEqual(Correlation.averageRanks([7, 7, 7, 7]), [2.5, 2.5, 2.5, 2.5])
        // Ô trống giữ nguyên là nan và KHÔNG chiếm một hạng.
        let ranks = Correlation.averageRanks([10, .nan, 20, 30])
        XCTAssertTrue(ranks[1].isNaN)
        XCTAssertEqual([ranks[0], ranks[2], ranks[3]], [1, 2, 3])
    }

    func testSpearmanKHONGDOIKhiDaoThuTuHangCoGiaTriTRUNG() throws {
        // Đây là lý do phải dùng hạng trung bình, và nó kiểm được trực tiếp.
        //
        // Xếp hạng ngây thơ (1, 2, 3, …) gán cho hai giá trị bằng nhau hai hạng khác nhau theo
        // thứ tự chúng xuất hiện trong file. Khi ấy sắp lại bảng — một thao tác không đổi nội
        // dung — làm ρ đổi, và NFR-MIN-02 (tất định) vỡ.
        let a: [Double] = [1, 2, 2, 3, 4, 4, 5]
        let b: [Double] = [9, 8, 7, 6, 5, 4, 3]

        let first = try Correlation.matrix([a, b], names: ["a", "b"], method: .spearman)

        // Hoán đổi hai hàng có giá trị TRÙNG ở cột a (chỉ số 1 và 2), mang theo cả cột b.
        var a2 = a, b2 = b
        a2.swapAt(1, 2)
        b2.swapAt(1, 2)
        let second = try Correlation.matrix([a2, b2], names: ["a", "b"], method: .spearman)

        XCTAssertEqual(
            try XCTUnwrap(first.value(1, 0)), try XCTUnwrap(second.value(1, 0)), accuracy: 1e-12)
    }

    func testSpearmanThayQuanHeDONDIEUCONGMaPearsonBOSOT() throws {
        // y = x³ trên x > 0: đơn điệu tuyệt đối, nên ρ phải bằng đúng 1. Pearson thì không, vì
        // quan hệ không tuyến tính. Đây là lý do đặc tả đòi CẢ HAI chứ không chọn một.
        let x = (1...30).map(Double.init)
        let y = x.map { $0 * $0 * $0 }

        let spearman = try Correlation.matrix([x, y], names: ["x", "y"], method: .spearman)
        XCTAssertEqual(try XCTUnwrap(spearman.value(1, 0)), 1, accuracy: 1e-12)

        let pearson = try Correlation.matrix([x, y], names: ["x", "y"], method: .pearson)
        let r = try XCTUnwrap(pearson.value(1, 0))
        XCTAssertLessThan(r, 0.93, "Pearson trên y = x³ phải THẤP hơn hẳn 1, đo được \(r)")
        XCTAssertGreaterThan(r, 0.8, "nhưng vẫn dương mạnh")
    }

    func testSpearmanBENVoiDiemCucDoanMaPearsonKhongBen() throws {
        var x = (1...20).map(Double.init)
        var y = x.map { $0 * 2 }
        // Một điểm hỏng duy nhất, kiểu lỗi nhập liệu điển hình: thừa ba số 0.
        x.append(21)
        y.append(-40_000)

        let pearson = try XCTUnwrap(
            Correlation.matrix([x, y], names: ["x", "y"], method: .pearson).value(1, 0))
        let spearman = try XCTUnwrap(
            Correlation.matrix([x, y], names: ["x", "y"], method: .spearman).value(1, 0))

        // Pearson bị lật hẳn sang ÂM bởi một dòng trên hai mươi mốt: từ +1 xuống dưới 0.
        XCTAssertLessThan(pearson, 0, "một điểm hỏng lật được dấu của Pearson: \(pearson)")

        // Spearman tụt từ 1 xuống ~0,73 — GIỮ NGUYÊN DẤU và vẫn nói "quan hệ dương mạnh".
        //
        // Đừng đọc 0,73 là "gần như không suy suyển": điểm hỏng nhảy từ hạng 21 xuống hạng 1,
        // tức dịch chuyển hạng LỚN NHẤT có thể với một dòng. 0,73 là trường hợp XẤU NHẤT của
        // Spearman trước một dòng hỏng, chứ không phải một trường hợp nhẹ. Điều đáng nói là ngay
        // ở trường hợp xấu nhất ấy nó vẫn kết luận đúng chiều, còn Pearson thì kết luận ngược.
        XCTAssertGreaterThan(spearman, 0.7, "Spearman: \(spearman)")
        XCTAssertGreaterThan(spearman - pearson, 1.0, "khoảng cách giữa hai phương pháp")
    }

    // MARK: - Ma trận

    func testDuongCHEOBang1VaMaTranDOIXUNG() throws {
        let matrix = try Correlation.matrix(
            [[1, 2, 3, 4], [4, 3, 2, 1], [1, 3, 2, 4]],
            names: ["a", "b", "c"], method: .pearson)
        for i in 0..<3 {
            XCTAssertEqual(try XCTUnwrap(matrix.value(i, i)), 1, accuracy: 1e-12)
        }
        // Tra theo cả hai chiều phải ra cùng một ô — chỉ lưu nửa dưới, nên đây là chỗ dễ sai.
        XCTAssertEqual(matrix.value(0, 2), matrix.value(2, 0))
        XCTAssertEqual(matrix.cells.count, 6, "3 cột → 6 ô nửa dưới kể cả đường chéo")
    }

    func testMoiOMangTheoSOHANGCuaRIENGNo() throws {
        // Pairwise: cột a và b đủ số ở 5 hàng, a và c chỉ đủ ở 3. Một hệ số tính trên 3 hàng
        // không cùng nghĩa với một hệ số tính trên 5, và người đọc phải THẤY điều đó.
        let a: [Double] = [1, 2, 3, 4, 5]
        let b: [Double] = [2, 4, 5, 4, 6]
        let c: [Double] = [1, .nan, 9, .nan, 4]
        let matrix = try Correlation.matrix([a, b, c], names: ["a", "b", "c"], method: .pearson)
        XCTAssertEqual(try XCTUnwrap(matrix.cell(1, 0)).count, 5)
        XCTAssertEqual(try XCTUnwrap(matrix.cell(2, 0)).count, 3)
        XCTAssertTrue(matrix.methodology.contains("pairwise"), matrix.methodology)
    }

    func testQUAITHANGThiNOIRoLyDoChuKhongDeTrong() throws {
        let matrix = try Correlation.matrix(
            [[1, 2, 3, 4], [8, 8, 8, 8]], names: ["a", "hang"], method: .pearson)
        let cell = try XCTUnwrap(matrix.cell(1, 0))
        XCTAssertNil(cell.value)
        let note = try XCTUnwrap(cell.note)
        XCTAssertTrue(note.contains("MỘT giá trị"), note)
        XCTAssertTrue(matrix.methodology.contains("KHÔNG đo được"), matrix.methodology)
    }

    func testQUAITHIEUHANGThiNoiCanBaoNhieu() throws {
        let matrix = try Correlation.matrix(
            [[1, 2, .nan, .nan], [3, 4, 5, 6]], names: ["a", "b"], method: .pearson)
        let cell = try XCTUnwrap(matrix.cell(1, 0))
        XCTAssertNil(cell.value)
        XCTAssertEqual(cell.count, 2)
        XCTAssertTrue(try XCTUnwrap(cell.note).contains("ít nhất 3"), cell.note ?? "")
    }

    func testCapMANHNHATBoDuongCheo() throws {
        let matrix = try Correlation.matrix(
            [[1, 2, 3, 4, 5], [2, 4, 6, 8, 10], [5, 1, 4, 2, 3]],
            names: ["a", "b", "c"], method: .pearson)
        let top = matrix.strongest()
        XCTAssertFalse(top.contains { $0.row == $0.column }, "r(x,x) = 1 luôn đứng đầu và vô nghĩa")
        let first = try XCTUnwrap(top.first)
        XCTAssertEqual(Set([first.row, first.column]), Set([0, 1]))
    }

    func testCHUTHICHNhanQuaCoTrongMoiKetQua() throws {
        // Đặc tả gọi đây là "tinh thần giáo dục của sản phẩm", nên nó được kiểm như một yêu cầu.
        for method in Correlation.Method.allCases {
            let matrix = try Correlation.matrix(
                [[1, 2, 3, 4], [2, 3, 4, 6]], names: ["a", "b"], method: method)
            XCTAssertTrue(
                matrix.methodology.contains("không hàm ý nhân quả"),
                "\(method): \(matrix.methodology)")
        }
    }

    func testTatDinh() throws {
        let columns = [[3.0, 1, 4, 1, 5, 9, 2, 6], [2.0, 7, 1, 8, 2, 8, 1, 8]]
        for method in Correlation.Method.allCases {
            let first = try Correlation.matrix(columns, names: ["a", "b"], method: method)
            let second = try Correlation.matrix(columns, names: ["a", "b"], method: method)
            XCTAssertEqual(first, second)
        }
    }

    func testHuyGiuaChung() {
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(try Correlation.matrix(
            [[1, 2, 3], [4, 5, 6]], names: ["a", "b"], method: .pearson, cancelToken: token))
    }

    // MARK: - Hồi quy cho scatter

    func testR2BangBinhPhuongR() throws {
        // Tính chất của hồi quy tuyến tính ĐƠN, và là bài kiểm chéo tốt nhất giữa hai hàm: nếu
        // `fit` hay `pearson` sai ở đâu thì đẳng thức này vỡ.
        let x: [Double] = [1, 2, 3, 4, 5, 6, 7]
        let y: [Double] = [2, 1, 4, 3, 7, 5, 9]
        let fit = try XCTUnwrap(Correlation.fit(x: x, y: y))
        let r = try XCTUnwrap(Correlation.pearson(x, y))
        XCTAssertEqual(fit.r2, r * r, accuracy: 1e-12)
    }

    func testDuongKHOPDungTrenQuanHeBietTruoc() throws {
        // y = 3x + 7 chính xác → hệ số góc 3, điểm cắt 7, R² = 1.
        let x = (0...10).map(Double.init)
        let fit = try XCTUnwrap(Correlation.fit(x: x, y: x.map { 3 * $0 + 7 }))
        XCTAssertEqual(fit.slope, 3, accuracy: 1e-12)
        XCTAssertEqual(fit.intercept, 7, accuracy: 1e-12)
        XCTAssertEqual(fit.r2, 1, accuracy: 1e-12)
        XCTAssertEqual(fit.equation(x: "x", y: "y"), "y = 3 × x + 7")
    }

    func testPhuongTrinhVietDauTRUKhiDiemCatAM() throws {
        let x = (0...10).map(Double.init)
        let fit = try XCTUnwrap(Correlation.fit(x: x, y: x.map { 2 * $0 - 5 }))
        XCTAssertEqual(fit.equation(x: "gio", y: "doanh_thu"), "doanh_thu = 2 × gio − 5")
    }

    func testXHANGThiKhongCoDuongKhop() {
        // Đường thẳng đứng không có hệ số góc. Trả `nil` chứ không trả một hệ số vô cùng lớn.
        XCTAssertNil(Correlation.fit(x: [4, 4, 4, 4], y: [1, 2, 3, 4]))
    }

    func testYHANGThiKhopHOANHAONhungR2Bang0() throws {
        // Biên đáng nói: đường khớp là đường ngang và nó đi qua ĐÚNG mọi điểm, nhưng R² theo
        // công thức là 0/0. Quy ước 0 — "mô hình không giải thích được gì về biến thiên của y",
        // và đúng, vì y không hề biến thiên.
        let fit = try XCTUnwrap(Correlation.fit(x: [1, 2, 3, 4], y: [9, 9, 9, 9]))
        XCTAssertEqual(fit.slope, 0, accuracy: 1e-12)
        XCTAssertEqual(fit.intercept, 9, accuracy: 1e-12)
        XCTAssertEqual(fit.r2, 0)
    }

    // MARK: - Thang màu

    func testTHANGMAUPhanKyQuanh0() {
        XCTAssertEqual(Correlation.heatHex(0), "#F7F7F7")
        // Hai đầu phải là hai SẮC khác nhau, không phải hai độ đậm của cùng một sắc.
        let negative = Correlation.heatHex(-1)
        let positive = Correlation.heatHex(1)
        XCTAssertEqual(negative, "#2166AC")
        XCTAssertEqual(positive, "#B35806")

        // Đối xứng về ĐỘ ĐẬM: r = +0,5 và r = −0,5 phải cách điểm trung tính bằng nhau, nếu
        // không thì mắt đọc một chiều là mạnh hơn chiều kia trong khi chúng bằng nhau.
        func distance(_ hex: String) -> Double {
            var value: UInt64 = 0
            Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
            let r = Double((value >> 16) & 0xFF), g = Double((value >> 8) & 0xFF)
            let b = Double(value & 0xFF)
            return abs(r - 247) + abs(g - 247) + abs(b - 247)
        }
        XCTAssertEqual(distance(Correlation.heatHex(0.5)) / distance(Correlation.heatHex(1)),
                       0.5, accuracy: 0.02)
    }

    func testCHUTrenOTOIPhaiLaChuTRANG() {
        // Đặc tả đòi ma trận SỐ và heatmap CÙNG LÚC — con số nằm trên ô màu. Chữ đen cố định sẽ
        // biến mất ở r = −1, tức đúng những ô quan trọng nhất là những ô không đọc được.
        XCTAssertEqual(Correlation.heatInkHex(-1), "#FFFFFF")
        XCTAssertEqual(Correlation.heatInkHex(0), "#1A1A1A")
        XCTAssertEqual(Correlation.heatInkHex(0.2), "#1A1A1A")
    }
}

// MARK: - Đường hồi quy vẽ đè lên biểu đồ phân tán

final class TrendLineTests: XCTestCase {

    private let layout = ChartRender.Layout(width: 400, height: 300)

    private func series() -> ChartData.Series {
        ChartData.Series(
            name: "y",
            points: (0...10).map { ChartData.Point(x: Double($0), y: Double($0) * 3 + 7) },
            originalCount: 11)
    }

    func testKhongTruyenDuongThiKhongVeThemGiCa() {
        let plain = ChartRender.primitives(kind: .scatter, series: series(), layout: layout)
        let withLine = ChartRender.primitives(
            kind: .scatter, series: series(), layout: layout,
            trendLine: (slope: 3, intercept: 7))
        XCTAssertEqual(withLine.count, plain.count + 1)
    }

    func testDuongCHAYHETBeNgangKhung() throws {
        let primitives = ChartRender.primitives(
            kind: .scatter, series: series(), layout: layout,
            trendLine: (slope: 3, intercept: 7))
        // Hình cuối trước tiêu đề là đường xu hướng.
        var found: (Double, Double, Double, Double)?
        for primitive in primitives {
            if case let .line(x1, y1, x2, y2, stroke, _) = primitive, stroke == .series2 {
                found = (x1, y1, x2, y2)
            }
        }
        let line = try XCTUnwrap(found)
        XCTAssertEqual(line.0, layout.insetLeft, accuracy: 0.001, "phải bắt đầu ở mép trái khung")
        XCTAssertEqual(
            line.2, layout.insetLeft + layout.plotWidth, accuracy: 0.001,
            "và chạy tới mép phải")
    }

    func testDuongDIQUADungCacDiemKhiQuanHeHOANHAO() throws {
        // y = 3x + 7 chính xác, nên đường khớp phải trùng khít với đám chấm. Kiểm bằng cách so
        // toạ độ MÀN HÌNH: nếu đường và chấm đi qua hai phép biến đổi khác nhau thì chúng lệch
        // nhau ở đây, dù cả hai đều "đúng" trong hệ toạ độ của riêng mình.
        let primitives = ChartRender.primitives(
            kind: .scatter, series: series(), layout: layout,
            trendLine: (slope: 3, intercept: 7))
        var circles: [(Double, Double)] = []
        var line: (Double, Double, Double, Double)?
        for primitive in primitives {
            switch primitive {
            case let .circle(x, y, _, _): circles.append((x, y))
            case let .line(x1, y1, x2, y2, stroke, _) where stroke == .series2:
                line = (x1, y1, x2, y2)
            default: break
            }
        }
        let l = try XCTUnwrap(line)
        XCTAssertEqual(circles.count, 11)
        for (x, y) in circles {
            // Nội suy tung độ của đường tại hoành độ của chấm.
            let t = (x - l.0) / (l.2 - l.0)
            XCTAssertEqual(l.1 + (l.3 - l.1) * t, y, accuracy: 0.001)
        }
    }

    func testLoaiBieuDoKHACThiBoQuaDuongXuHuong() {
        // Một đường hồi quy trên biểu đồ hộp hay biểu đồ cột không có nghĩa gì.
        for kind in [ChartData.Kind.bar, .box, .histogram, .line] {
            let plain = ChartRender.primitives(kind: kind, series: series(), layout: layout)
            let withLine = ChartRender.primitives(
                kind: kind, series: series(), layout: layout,
                trendLine: (slope: 3, intercept: 7))
            XCTAssertEqual(withLine.count, plain.count, "\(kind)")
        }
    }

    func testDuongVaoCaSVG() {
        // Màn hình và SVG đọc CÙNG danh sách hình, nên đường phải tự khắc có trong SVG. Bài
        // kiểm này giữ tính chất ấy khỏi bị phá bởi một đường vẽ riêng ở tầng view.
        let primitives = ChartRender.primitives(
            kind: .scatter, series: series(), layout: layout,
            trendLine: (slope: 3, intercept: 7))
        let svg = ChartRender.svg(primitives, layout: layout)
        XCTAssertTrue(svg.contains("<line"), svg.prefix(200).description)
    }
}
