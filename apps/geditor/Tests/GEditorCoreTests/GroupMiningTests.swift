import XCTest
@testable import GEditorCore

final class GroupMiningTests: XCTestCase {

    // MARK: - Huỷ giữa chừng (NFR-MIN-05)

    func testHUYgiuaCHUNGgiuLAInhomDAxongVAdanhDAUro() throws {
        // NFR-MIN-05: *"HỦY giữa chừng giữ nguyên kết quả các nhóm đã hoàn tất (partial results
        // hợp lệ, đánh dấu rõ)"*. Hai vế, và bản trước hỏng CẢ HAI: `try cancelToken.check()`
        // ném ra ngoài, nên một cú huỷ cuốn theo mọi nhóm đã chấm xong.
        //
        // Lỗi ấy sống suốt từ khi cụm FR-MIN khép, vì không bài kiểm nào từng huỷ giữa chừng —
        // nó chỉ lộ ra khi có người ĐO chỉ tiêu thay vì đọc mã.
        var labels: [String?] = []
        var series: [Double] = []
        for group in 0 ..< 40 {
            for row in 0 ..< 12 {
                labels.append("nhom_\(group)")
                series.append(Double((row % 4) * 10 + group))
            }
        }
        let options = GroupMining.Options(anomalyColumn: "gia_tri", forecastColumn: "gia_tri")

        // Huỷ SẴN từ trước: mọi nhóm đều chưa chạy, nên bảng phải RỖNG mà vẫn hợp lệ — và phải
        // tự nhận là đã bị huỷ, không giả vờ là "40 nhóm không có gì đáng nói".
        let token = CancelToken()
        token.cancel()
        let stopped = try GroupMining.run(
            labels: labels, columns: ["gia_tri"], values: [series],
            options: options, cancelToken: token)
        XCTAssertTrue(stopped.cancelled, "huỷ mà bảng không tự nhận là đã huỷ")
        XCTAssertTrue(stopped.groups.isEmpty)
        XCTAssertTrue(stopped.methodology.contains("ĐÃ HUỶ"),
                      "khối Phương pháp phải nói ra, vì nó đi theo cả bản xuất báo cáo")

        // Không huỷ thì đủ nhóm và KHÔNG mang dấu huỷ — đối chứng cho vế trên.
        let full = try GroupMining.run(
            labels: labels, columns: ["gia_tri"], values: [series], options: options)
        XCTAssertEqual(full.groups.count, 40)
        XCTAssertFalse(full.cancelled)
        XCTAssertFalse(full.methodology.contains("ĐÃ HUỶ"))
    }

    func testHUYroiVAOGIUAmotNHOMvanGIUnhungNHOMtruoc() throws {
        // Nửa thứ hai của lỗi, và là nửa khó thấy hơn: chặn huỷ ở ĐẦU vòng lặp thôi thì chưa
        // đủ, vì phần lớn thời gian nằm TRONG một nhóm (phép dự báo) chứ không giữa hai nhóm.
        // `TimeSeries.forecast` NÉM khi bị huỷ, và cú ném ấy cuốn cả hàm — nên bảng vẫn về
        // rỗng dù vòng lặp đã có phép chặn.
        //
        // Bài này huỷ đúng lúc phép dự báo của nhóm thứ nhất đang chạy, bằng một token có HẠN
        // GIỜ thay vì bấm tay: hạn giờ là tất định, còn `Thread.sleep` thì tuỳ máy.
        var labels: [String?] = []
        var series: [Double] = []
        for group in 0 ..< 300 {
            for row in 0 ..< 16 {
                labels.append("nhom_\(group)")
                series.append(Double((row % 4) * 7 + group % 5))
            }
        }
        let options = GroupMining.Options(anomalyColumn: "x", forecastColumn: "x")

        // Token hết hạn sau một khoảng RẤT ngắn: vài nhóm đầu kịp xong, phần còn lại thì không.
        let token = CancelToken(timeout: 0.01)
        let report = try GroupMining.run(
            labels: labels, columns: ["x"], values: [series],
            options: options, cancelToken: token)

        XCTAssertTrue(report.cancelled, "huỷ giữa chừng mà bảng không tự nhận")
        XCTAssertLessThan(report.groups.count, 300, "không cắt gì cả — token chưa hết hạn kịp")
        // Vế quan trọng nhất: phần đã xong KHÔNG bị vứt. Bản trước trả về đúng 0 nhóm.
        XCTAssertTrue(report.methodology.contains("ĐÃ HUỶ"))
        for group in report.groups {
            XCTAssertFalse(group.name.isEmpty, "nhóm đã xong phải còn nguyên vẹn")
        }
    }

    // MARK: - Cái bẫy mà đặc tả tự gọi tên

    func testNGUONGCHUNGBOSOTBatThuongCuaNhomNHO_NguongRIENGThiBat() throws {
        // Hai chi nhánh: A quanh 10, B quanh 100. Cắm vào A một giá trị 20 — gấp đôi mức bình
        // thường của A, rõ ràng bất thường TRONG A.
        //
        // Gộp lại thì Q1 ≈ 10 và Q3 ≈ 100, nên IQR ≈ 90 và hàng rào rộng tới ±135: giá trị 20
        // lọt qua không một tiếng động. Càng nhiều nhóm, hàng rào chung càng rộng — tức càng
        // nhiều dữ liệu thì càng mù.
        var labels: [String?] = []
        var series: [Double] = []
        for index in 0..<12 {
            labels.append("A")
            series.append(10 + Double(index % 3))
        }
        for index in 0..<12 {
            labels.append("B")
            series.append(100 + Double(index % 3))
        }
        labels.append("A")
        series.append(20)

        // Đối chứng: hàng rào GỘP thật sự bỏ sót nó.
        let pooled = series.sorted()
        let q1 = ChartData.quantile(pooled, 0.25)
        let q3 = ChartData.quantile(pooled, 0.75)
        let high = q3 + 1.5 * (q3 - q1)
        XCTAssertGreaterThan(high, 20, "hàng rào gộp phải rộng hơn 20, tức bỏ sót")

        // Ngưỡng riêng thì bắt được.
        let report = try GroupMining.run(
            labels: labels, columns: ["x"], values: [series],
            options: GroupMining.Options(anomalyColumn: "x"))
        let groupA = try XCTUnwrap(report.groups.first { $0.name == "A" })
        let groupB = try XCTUnwrap(report.groups.first { $0.name == "B" })
        XCTAssertEqual(groupA.anomalies, 1, "nhóm A phải bắt được giá trị 20")
        XCTAssertEqual(groupB.anomalies, 0)

        // Và hai nhóm phải có HAI hàng rào khác nhau — đó là cả điểm của yêu cầu này.
        let fenceA = try XCTUnwrap(groupA.fence)
        let fenceB = try XCTUnwrap(groupB.fence)
        XCTAssertLessThan(fenceA.high, fenceB.low, "hai hàng rào phải tách hẳn nhau")
    }

    func testNGUONGCHUNGBAONHAMOnNhomPHANTANRONG() throws {
        // Chiều ngược lại, và là chiều làm người dùng bỏ tính năng: nhóm A rất chụm, nhóm B rất
        // trải. Hàng rào chung bị A kéo hẹp lại và cắt mất phần đuôi HOÀN TOÀN BÌNH THƯỜNG của B.
        var labels: [String?] = []
        var series: [Double] = []
        for index in 0..<40 {
            labels.append("chum")
            series.append(50 + Double(index % 2) * 0.1)
        }
        for index in 0..<40 {
            labels.append("trai")
            series.append(50 + Double(index) - 20)
        }

        let pooled = series.sorted()
        let q1 = ChartData.quantile(pooled, 0.25)
        let q3 = ChartData.quantile(pooled, 0.75)
        let low = q1 - 1.5 * (q3 - q1)
        let high = q3 + 1.5 * (q3 - q1)
        let falsePositives = series.filter { $0 < low || $0 > high }.count
        XCTAssertGreaterThan(falsePositives, 0, "hàng rào gộp phải báo nhầm ít nhất một điểm")

        let report = try GroupMining.run(
            labels: labels, columns: ["x"], values: [series],
            options: GroupMining.Options(anomalyColumn: "x"))
        for group in report.groups {
            XCTAssertEqual(group.anomalies, 0, "\(group.name) không có bất thường thật nào")
        }
    }

    // MARK: - Nghịch lý Simpson

    func testBATDUOCNhomNguocChieuVoiTapGOP() throws {
        // Ba nhóm, trong mỗi nhóm `y` GIẢM theo `x`. Nhưng các nhóm nằm lệch nhau theo đường
        // chéo đi lên, nên gộp lại `y` TĂNG theo `x`.
        //
        // Ai đọc bảng gộp sẽ kết luận ngược hoàn toàn với sự thật trong mọi nhóm. Đây là lý do
        // cột "lệch tương quan" tồn tại.
        var labels: [String?] = []
        var xs: [Double] = []
        var ys: [Double] = []
        for (offset, name) in [(0.0, "N1"), (10.0, "N2"), (20.0, "N3")] {
            for index in 0..<12 {
                labels.append(name)
                xs.append(offset + Double(index) * 0.3)
                ys.append(offset * 3 - Double(index) * 0.3)
            }
        }

        let report = try GroupMining.run(
            labels: labels, columns: ["x", "y"], values: [xs, ys],
            options: GroupMining.Options(correlationPair: ("x", "y")))

        // Tập gộp: tương quan DƯƠNG mạnh.
        let pooled = try XCTUnwrap(report.pooledCorrelation)
        XCTAssertGreaterThan(pooled, 0.9, "gộp lại phải ra dương mạnh: \(pooled)")

        // Từng nhóm: tương quan ÂM hoàn hảo.
        for group in report.groups {
            XCTAssertEqual(try XCTUnwrap(group.correlation), -1, accuracy: 1e-9, group.name)
        }

        // Bảng xếp hạng phải đưa chúng lên đầu, và độ lệch phải lớn.
        let ranked = report.ranked(by: .correlationGap)
        XCTAssertEqual(ranked.count, 3)
        XCTAssertGreaterThan(try XCTUnwrap(ranked[0].correlationGap), 1.9)
        XCTAssertTrue(
            report.methodology.contains("ngược với sự thật trong nhóm"), report.methodology)
    }

    // MARK: - Dự báo theo nhóm

    func testMOINHOMMotChuKyRIENG() throws {
        // Đặc tả: "mỗi tỉnh một model Holt-Winters riêng với chu kỳ tự phát hiện RIÊNG".
        // Nhóm `quy` có chu kỳ 4, nhóm `tuan` có chu kỳ 7. Một chu kỳ chung sẽ sai ở một trong
        // hai nhóm, và sai theo kiểu học thuộc nhiễu.
        var labels: [String?] = []
        var series: [Double] = []
        let quarterly = [10.0, 20, 5, 15]
        let weekly = [3.0, 9, 4, 12, 5, 11, 2]
        for cycle in 0..<10 {
            for index in 0..<4 {
                labels.append("quy")
                series.append(100 + Double(cycle) * 5 + quarterly[index])
            }
        }
        for cycle in 0..<10 {
            for index in 0..<7 {
                labels.append("tuan")
                series.append(50 + Double(cycle) * 2 + weekly[index])
            }
        }

        let report = try GroupMining.run(
            labels: labels, columns: ["gt"], values: [series],
            options: GroupMining.Options(forecastColumn: "gt"))
        XCTAssertEqual(try XCTUnwrap(report.groups.first { $0.name == "quy" }).period, 4)
        XCTAssertEqual(try XCTUnwrap(report.groups.first { $0.name == "tuan" }).period, 7)
    }

    func testXEPHANGTheoMAPE() throws {
        // Nhóm `sach` là chuỗi mùa vụ hoàn hảo → MAPE gần 0. Nhóm `nhieu` là bước nhảy ngẫu
        // nhiên → MAPE cao. Bảng xếp hạng phải đưa `nhieu` lên đầu.
        var labels: [String?] = []
        var series: [Double] = []
        for cycle in 0..<10 {
            for index in 0..<4 {
                labels.append("sach")
                series.append(100 + Double(cycle) * 5 + [10.0, 20, 5, 15][index])
            }
        }
        var generator = SeededGenerator(seed: 99)
        var walk = 100.0
        for _ in 0..<40 {
            labels.append("nhieu")
            walk += (generator.nextUnit() - 0.5) * 60
            series.append(abs(walk) + 20)
        }

        let report = try GroupMining.run(
            labels: labels, columns: ["gt"], values: [series],
            options: GroupMining.Options(forecastColumn: "gt"))
        let ranked = report.ranked(by: .forecastError)
        XCTAssertEqual(ranked.first?.name, "nhieu", "MAPE: \(ranked.map { ($0.name, $0.mape) })")
    }

    // MARK: - Biên

    func testNHOMQUANHOThiNOIRoLyDo_KhongChamDiem() throws {
        var labels: [String?] = ["tí", "tí"]
        var series: [Double] = [1, 2]
        for index in 0..<20 {
            labels.append("đủ")
            series.append(Double(index))
        }
        let report = try GroupMining.run(
            labels: labels, columns: ["x"], values: [series],
            options: GroupMining.Options(anomalyColumn: "x"))
        let small = try XCTUnwrap(report.groups.first { $0.name == "tí" })
        XCTAssertFalse(small.note.isEmpty)
        XCTAssertTrue(small.note.contains("chỉ 2 hàng"), small.note)
        XCTAssertNil(small.fence)
        // Và nhóm không chấm được phải bị LOẠI khỏi bảng xếp hạng, không đứng đầu với 0%.
        XCTAssertFalse(report.ranked(by: .anomalies).contains { $0.name == "tí" })
    }

    func testVUOTTRANThiCATVaCANHBAO_KhongImLang() throws {
        // Cột nhóm chọn nhầm (mã đơn hàng) sinh ra một nhóm cho mỗi hàng.
        let count = GroupMining.groupLimit + 25
        let labels: [String?] = (0..<count).map { "ma\($0)" }
        let series = (0..<count).map { Double($0) }
        let report = try GroupMining.run(
            labels: labels, columns: ["x"], values: [series], options: GroupMining.Options())
        XCTAssertEqual(report.groups.count, GroupMining.groupLimit)
        XCTAssertEqual(report.truncated, 25)
        XCTAssertTrue(report.methodology.contains("CẢNH BÁO"), report.methodology)
        XCTAssertTrue(report.methodology.contains("25 nhóm cuối"), report.methodology)
    }

    func testGIUCHISOHANGGOCDeDrillXuong() throws {
        let labels: [String?] = ["A", "B", "A", nil, "B", "A"]
        let series: [Double] = [1, 2, 3, 4, 5, 6]
        let report = try GroupMining.run(
            labels: labels, columns: ["x"], values: [series],
            options: GroupMining.Options(minimumRows: 1))
        XCTAssertEqual(try XCTUnwrap(report.groups.first { $0.name == "A" }).rowIndices, [0, 2, 5])
        XCTAssertEqual(try XCTUnwrap(report.groups.first { $0.name == "B" }).rowIndices, [1, 4])
        XCTAssertEqual(report.groups.count, 2, "hàng không có nhãn không tạo ra nhóm")
    }

    func testGIUTHUTUXUATHIENDauTien() throws {
        let labels: [String?] = ["z", "a", "m", "a", "z"]
        let series: [Double] = [1, 2, 3, 4, 5]
        let report = try GroupMining.run(
            labels: labels, columns: ["x"], values: [series],
            options: GroupMining.Options(minimumRows: 1))
        XCTAssertEqual(report.groups.map(\.name), ["z", "a", "m"])
    }

    func testTATDINH() throws {
        let labels: [String?] = (0..<60).map { $0 % 3 == 0 ? "A" : "B" }
        let series = (0..<60).map { Double($0 % 11) }
        let options = GroupMining.Options(anomalyColumn: "x", forecastColumn: "x")
        XCTAssertEqual(
            try GroupMining.run(
                labels: labels, columns: ["x"], values: [series], options: options),
            try GroupMining.run(
                labels: labels, columns: ["x"], values: [series], options: options))
    }

    func testHuyGiuaChungKHONGnemMAtraVEphanDAxong() throws {
        // **Hợp đồng này đã ĐỔI, có chủ ý.** Bản trước đòi `run` NÉM khi bị huỷ, và nó ném thật
        // — nhưng NFR-MIN-05 viết ngược lại: *"HỦY giữa chừng giữ nguyên kết quả các nhóm đã
        // hoàn tất (partial results hợp lệ, đánh dấu rõ)"*. Bài kiểm cũ vì thế khoá đúng cái
        // hành vi mà đặc tả cấm, và nó xanh suốt vì không ai đối chiếu lại với chỉ tiêu.
        let token = CancelToken()
        token.cancel()
        let report = try GroupMining.run(
            labels: ["A", "A"], columns: ["x"], values: [[1, 2]],
            options: GroupMining.Options(minimumRows: 1), cancelToken: token)
        XCTAssertTrue(report.cancelled)
        XCTAssertTrue(report.groups.isEmpty)
    }

    func testCotKhongTonTaiThiBoQuaPhanDo_KhongSap() throws {
        let report = try GroupMining.run(
            labels: ["A", "A", "A"], columns: ["x"], values: [[1, 2, 3]],
            options: GroupMining.Options(anomalyColumn: "khong_co", minimumRows: 1))
        XCTAssertEqual(report.groups.count, 1)
        XCTAssertNil(report.groups[0].fence)
    }
}
