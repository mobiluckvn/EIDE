import XCTest
@testable import GEditorCore

final class ClusteringTests: XCTestCase {

    /// Ba đám tách bạch quanh (0,0), (10,10), (0,10). Không có gì mơ hồ để phân cụm sai.
    private func threeBlobs() -> [[Double]] {
        var rows: [[Double]] = []
        for (cx, cy) in [(0.0, 0.0), (10.0, 10.0), (0.0, 10.0)] {
            for i in 0..<20 {
                let jitter = Double(i % 5) * 0.1
                rows.append([cx + jitter, cy + Double((i / 5) % 4) * 0.1])
            }
        }
        return rows
    }

    private let names = ["x", "y"]

    // MARK: - k-means

    func testTIMDUNGBaDamTachBach() throws {
        let result = try Clustering.kMeans(rows: threeBlobs(), columns: names, k: 3)
        XCTAssertEqual(result.clusters.count, 3)
        XCTAssertEqual(result.clusters.map(\.size).sorted(), [20, 20, 20])

        // Hai mươi hàng đầu phải cùng một nhãn, và khác nhãn của hai mươi hàng sau.
        let labels = result.labels.compactMap { $0 }
        XCTAssertEqual(Set(labels[0..<20]).count, 1)
        XCTAssertEqual(Set(labels[20..<40]).count, 1)
        XCTAssertEqual(Set(labels[40..<60]).count, 1)
        XCTAssertEqual(Set(labels).count, 3)

        // Ba đám tách bạch → silhouette phải rất cao.
        XCTAssertGreaterThan(try XCTUnwrap(result.silhouette), 0.9)
        XCTAssertTrue(result.converged, "phải hội tụ sớm, không chạm trần 50 vòng")
        XCTAssertLessThan(result.iterations, Clustering.maximumIterations)
    }

    func testTATDINH_CungSeedChoCungPhanCum() throws {
        let rows = threeBlobs()
        let first = try Clustering.kMeans(rows: rows, columns: names, k: 3, seed: 42)
        let second = try Clustering.kMeans(rows: rows, columns: names, k: 3, seed: 42)
        XCTAssertEqual(first, second)
        // NFR-MIN-02 đòi seed nằm TRONG kết quả — một bảng không nói ra seed là bảng không
        // chạy lại được.
        XCTAssertEqual(first.seed, 42)
        XCTAssertTrue(first.methodology.contains("seed 42"), first.methodology)
    }

    func testSEEDKHACCoTheChoKetQuaKhac_NenNoPhaiDuocGHILAI() throws {
        // Trên dữ liệu mơ hồ (một dải liên tục, không có ranh giới thật), k-means++ với hai
        // seed khác nhau đi tới hai cực tiểu địa phương khác nhau. Đó chính là lý do đặc tả đòi
        // ghi seed: nếu không thì hai người chạy cùng một tệp ra hai bảng và không ai giải
        // thích được vì sao.
        var rows: [[Double]] = []
        for i in 0..<60 { rows.append([Double(i), Double(i % 7)]) }
        var seen = Set<[Int?]>()
        for seed in [UInt64(1), 7, 99, 12_345, 777_777] {
            seen.insert(try Clustering.kMeans(
                rows: rows, columns: names, k: 4, seed: seed).labels)
        }
        XCTAssertGreaterThan(seen.count, 1, "nếu mọi seed cho cùng kết quả thì bài này vô nghĩa")
    }

    func testCHUANHOAThayDoiKetQua_VaCachDaChonNamTrongKetQua() throws {
        // Hai cột lệch thang một nghìn lần: `to` (0…1000) và `nho` (0…1).
        //
        // Cấu trúc THẬT nằm ở cột `nho`: hai đám tách bạch. Cột `to` chỉ là một dải đều không
        // có cấu trúc gì. Không chuẩn hoá thì `to` áp đảo và k-means cắt dải ấy làm đôi ở giữa
        // — trả lời một câu hỏi khác hẳn.
        var rows: [[Double]] = []
        for i in 0..<40 {
            rows.append([Double(i) * 25, i < 20 ? 0.0 : 1.0])
        }
        let names = ["to", "nho"]

        let scaled = try Clustering.kMeans(
            rows: rows, columns: names, k: 2, scaling: .zScore)
        let raw = try Clustering.kMeans(rows: rows, columns: names, k: 2, scaling: .none)

        // Có chuẩn hoá: cắt đúng theo `nho`, tức hai mươi hàng đầu một cụm.
        let scaledLabels = scaled.labels.compactMap { $0 }
        XCTAssertEqual(Set(scaledLabels[0..<20]).count, 1)
        XCTAssertEqual(Set(scaledLabels[20..<40]).count, 1)
        XCTAssertNotEqual(scaledLabels[19], scaledLabels[20])

        // Không chuẩn hoá: cũng cắt làm đôi nhưng vì `to`, nên silhouette THẤP hơn hẳn — cấu
        // trúc thật không được tìm ra.
        XCTAssertGreaterThan(
            try XCTUnwrap(scaled.silhouette), try XCTUnwrap(raw.silhouette))

        // Và cách đã chọn phải nằm trong kết quả.
        XCTAssertEqual(scaled.scaling, .zScore)
        XCTAssertTrue(scaled.methodology.contains("z-score"), scaled.methodology)
        XCTAssertTrue(raw.methodology.contains("không chuẩn hoá"), raw.methodology)
    }

    func testTAMCUMTraVeCaHaiTHANG() throws {
        // Người dùng đọc "doanh thu trung bình 4,2 triệu", không đọc "0,31 độ lệch chuẩn".
        var rows: [[Double]] = []
        for i in 0..<30 { rows.append([Double(i < 15 ? 1_000_000 : 5_000_000), Double(i)]) }
        let result = try Clustering.kMeans(
            rows: rows, columns: ["doanh_thu", "stt"], k: 2)
        let means = result.clusters.map { $0.centreInOriginalUnits[0] }.sorted()
        XCTAssertEqual(means, [1_000_000, 5_000_000])
        // Thang chuẩn hoá thì quanh 0.
        XCTAssertTrue(result.clusters.allSatisfy { abs($0.centre[0]) < 5 })
    }

    func testCOTHANGKhongLamHONGMoiKhoangCach() throws {
        // Cột chỉ có một giá trị: độ lệch chuẩn 0. Chia liều sẽ cho `nan`, và một `nan` làm mọi
        // so sánh khoảng cách thành `false` — k-means khi ấy nhét tất cả vào cụm 0 trong im lặng.
        var rows: [[Double]] = []
        for i in 0..<30 { rows.append([7, Double(i < 15 ? 0 : 100)]) }
        let result = try Clustering.kMeans(rows: rows, columns: ["hang", "that"], k: 2)
        XCTAssertEqual(result.clusters.map(\.size).sorted(), [15, 15])
        XCTAssertTrue(result.clusters.allSatisfy { $0.centre.allSatisfy(\.isFinite) })
    }

    func testHANGTHIEUSOGiuNhanNILVaKhongLamLECHCHISO() throws {
        var rows = threeBlobs()
        rows.insert([.nan, 5], at: 0)
        rows.insert([3, .nan], at: 30)
        let result = try Clustering.kMeans(rows: rows, columns: names, k: 3)
        XCTAssertNil(result.labels[0])
        XCTAssertNil(result.labels[30])
        XCTAssertEqual(result.labels.count, rows.count, "nhãn trả về theo HÀNG GỐC")
        XCTAssertEqual(result.labels.compactMap { $0 }.count, 60)
        XCTAssertEqual(result.clusters.map(\.size).sorted(), [20, 20, 20])
    }

    func testKLonHonSoHangThiKepLai_KhongSap() throws {
        let result = try Clustering.kMeans(
            rows: [[1, 1], [2, 2], [3, 3]], columns: names, k: 99)
        XCTAssertLessThanOrEqual(result.clusters.count, 3)
    }

    func testMOIDIEMTRUNGNHAUThiDungSomVoiItCumHon() throws {
        // Không có gì để tách. Thêm tâm trùng lặp chỉ sinh ra cụm rỗng, nên trả về ÍT cụm hơn
        // yêu cầu là câu trả lời đúng — và số cụm thật nằm trong kết quả.
        let rows = [[Double]](repeating: [4, 4], count: 20)
        let result = try Clustering.kMeans(rows: rows, columns: names, k: 5)
        XCTAssertLessThan(result.clusters.count, 5)
        XCTAssertNil(result.silhouette, "một cụm thì silhouette không định nghĩa")
        XCTAssertTrue(result.methodology.contains("Không tính được silhouette"))
    }

    func testKhongCoCotThiNemLoi() {
        XCTAssertThrowsError(try Clustering.kMeans(rows: [[1]], columns: [], k: 2)) {
            XCTAssertEqual($0 as? Clustering.Failure, .noColumns)
        }
    }

    func testHuyGiuaChung() {
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(try Clustering.kMeans(
            rows: threeBlobs(), columns: names, k: 3, cancelToken: token))
    }

    // MARK: - Elbow

    func testWCSSGIAMDONDIEUKhiKTang() throws {
        // Bất biến toán học: thêm một tâm không bao giờ làm tổng bình phương trong cụm tăng.
        // Nếu chỉ số hàng bị lệch ở đâu đó thì đường cong sẽ răng cưa và bài này bắt được.
        let (curve, _) = try Clustering.elbow(rows: threeBlobs(), columns: names, maxK: 8)
        XCTAssertEqual(curve.map(\.k), Array(1...8))
        for index in 1..<curve.count {
            XCTAssertLessThanOrEqual(
                curve[index].wcss, curve[index - 1].wcss + 1e-9,
                "k = \(curve[index].k) có WCSS lớn hơn k = \(curve[index - 1].k)")
        }
        XCTAssertGreaterThan(curve[0].wcss, curve[7].wcss, "phải giảm THẬT, không phẳng lì")
    }

    func testELBOWGoiYDungKTrenDuLieuBietTruoc() throws {
        // Ba đám tách bạch → chỗ gãy phải ở k = 3.
        let (_, suggested) = try Clustering.elbow(rows: threeBlobs(), columns: names, maxK: 8)
        XCTAssertEqual(suggested, 3)
    }

    func testELBOWChuanHoaCaHaiTrucTruocKhiDoDayCung() {
        // Không chuẩn hoá hai trục thì trục WCSS (hàng triệu) áp đảo trục k (1…10) và điểm "xa
        // dây cung nhất" luôn rơi vào k = 2 bất kể hình dạng. Đường cong dưới đây gãy rõ ở k = 4.
        let curve = [
            Clustering.ElbowPoint(k: 1, wcss: 8_000_000),
            Clustering.ElbowPoint(k: 2, wcss: 5_000_000),
            Clustering.ElbowPoint(k: 3, wcss: 2_600_000),
            Clustering.ElbowPoint(k: 4, wcss: 400_000),
            Clustering.ElbowPoint(k: 5, wcss: 380_000),
            Clustering.ElbowPoint(k: 6, wcss: 365_000),
            Clustering.ElbowPoint(k: 7, wcss: 355_000),
        ]
        XCTAssertEqual(Clustering.suggestedK(from: curve), 4)
    }

    // MARK: - DBSCAN

    func testDBSCANTimCumMaKHONGCanBietTruocSoCum() throws {
        let result = try Clustering.dbscan(
            rows: threeBlobs(), columns: names, eps: 0.5, minPoints: 4)
        XCTAssertEqual(result.clusters.count, 3)
        XCTAssertEqual(result.noiseCount, 0)
        XCTAssertTrue(result.methodology.contains("DBSCAN"), result.methodology)
        XCTAssertTrue(result.methodology.contains("minPts = 4"), result.methodology)
    }

    func testDBSCANGanNHANNHIEUChoDiemLacLoai() throws {
        var rows = threeBlobs()
        rows.append([500, 500])       // rất xa mọi đám
        rows.append([-300, 42])
        let result = try Clustering.dbscan(
            rows: rows, columns: names, eps: 0.5, minPoints: 4)
        XCTAssertEqual(result.noiseCount, 2)
        XCTAssertEqual(result.labels[rows.count - 1], -1)
        XCTAssertEqual(result.labels[rows.count - 2], -1)
        // Điều k-means KHÔNG làm được: nó buộc mọi điểm vào một cụm nào đó.
        let kmeans = try Clustering.kMeans(rows: rows, columns: names, k: 3)
        XCTAssertEqual(kmeans.noiseCount, 0)
    }

    func testDBSCANNhanDIEMBIENVaoCum_KhongBaoMonRia() throws {
        // Một điểm nằm trong bán kính của một điểm lõi nhưng tự nó không đủ dày. Bỏ qua nó là
        // bào mòn rìa MỌI cụm, và số liệu kích thước cụm sai một cách có hệ thống.
        var rows: [[Double]] = []
        for i in 0..<10 { rows.append([Double(i) * 0.1, 0]) }   // đám dày
        rows.append([1.0, 0])                                    // điểm biên
        let result = try Clustering.dbscan(
            rows: rows, columns: names, eps: 0.15, minPoints: 3, scaling: .none)
        XCTAssertEqual(result.noiseCount, 0, "điểm biên phải được nhận vào cụm")
        XCTAssertEqual(result.clusters.first?.size, 11)
    }

    func testLUOIVaQUETTHANGChoCUNGKetQua() throws {
        // Đối chứng cho chỉ mục không gian: nếu lưới bỏ sót một ô kề thì nó cho kết quả KHÁC
        // quét thẳng, và khác một cách rất khó thấy (vài điểm rìa thành nhiễu).
        //
        // Ép quét thẳng bằng cách nhân số chiều lên quá `gridDimensionLimit`, giữ nguyên khoảng
        // cách bằng cách chèn các cột hằng 0.
        let rows = threeBlobs()
        let padded = rows.map { $0 + [Double](repeating: 0, count: 5) }
        let paddedNames = names + (1...5).map { "z\($0)" }

        let viaGrid = try Clustering.dbscan(
            rows: rows, columns: names, eps: 0.5, minPoints: 4, scaling: .none)
        let viaScan = try Clustering.dbscan(
            rows: padded, columns: paddedNames, eps: 0.5, minPoints: 4, scaling: .none)
        XCTAssertGreaterThan(paddedNames.count, Clustering.gridDimensionLimit)
        XCTAssertEqual(viaGrid.labels, viaScan.labels)
    }

    func testDBSCANTatDinh() throws {
        let rows = threeBlobs()
        XCTAssertEqual(
            try Clustering.dbscan(rows: rows, columns: names, eps: 0.5),
            try Clustering.dbscan(rows: rows, columns: names, eps: 0.5))
    }

    func testK_DISTANCEGoiYEpsDungDuoc() throws {
        // Gợi ý phải nằm trong khoảng dùng được: đủ lớn để đám dính lại, đủ nhỏ để ba đám không
        // dính vào nhau. Kiểm bằng cách CHẠY DBSCAN với chính con số ấy.
        let rows = threeBlobs()
        let (curve, eps, _) = try Clustering.kDistanceCurve(
            rows: rows, columns: names, minPoints: 4, scaling: .none)
        XCTAssertEqual(curve.count, rows.count)
        XCTAssertEqual(curve, curve.sorted(by: >), "đường cong phải sắp GIẢM DẦN")
        XCTAssertGreaterThan(eps, 0)

        let result = try Clustering.dbscan(
            rows: rows, columns: names, eps: eps, minPoints: 4, scaling: .none)
        XCTAssertEqual(result.clusters.count, 3, "eps gợi ý phải tách đúng ba đám")
    }

    // MARK: - Silhouette

    func testSILHOUETTECaoKhiTachBachVaTHAPKhiChongLan() throws {
        let separated = try Clustering.kMeans(rows: threeBlobs(), columns: names, k: 3)

        // Cùng dữ liệu nhưng ép thành 6 cụm: cắt vụn các đám thật → chồng lấn → điểm tụt.
        let overCut = try Clustering.kMeans(rows: threeBlobs(), columns: names, k: 6)
        XCTAssertGreaterThan(
            try XCTUnwrap(separated.silhouette), try XCTUnwrap(overCut.silhouette))
    }

    func testSILHOUETTELAYMAUThiPhaiNOIRA() throws {
        // Ngưỡng lấy mẫu là 2.000 điểm. Dựng 2.500 để vượt qua nó.
        var rows: [[Double]] = []
        for i in 0..<2_500 {
            rows.append([Double(i % 2) * 50 + Double(i % 7) * 0.1, Double(i % 3) * 0.1])
        }
        let result = try Clustering.kMeans(rows: rows, columns: names, k: 2)
        XCTAssertFalse(result.silhouetteNote.isEmpty)
        XCTAssertTrue(result.silhouetteNote.contains("ƯỚC LƯỢNG"), result.silhouetteNote)
        XCTAssertTrue(result.methodology.contains("ƯỚC LƯỢNG"), result.methodology)

        // Đối chứng: dưới ngưỡng thì KHÔNG có ghi chú. Thiếu vế này thì bài trên vẫn xanh kể cả
        // khi ghi chú luôn được gắn vào.
        let small = try Clustering.kMeans(rows: threeBlobs(), columns: names, k: 3)
        XCTAssertTrue(small.silhouetteNote.isEmpty)
    }

    func testMAULAYTHEOBUOCDEUChuKhongPhai2000DongDAU() throws {
        // Bảng của người dùng thường đã được SẮP. Lấy 2.000 dòng đầu khi ấy rơi trúng một cụm
        // duy nhất, và silhouette tính ra vô nghĩa.
        //
        // Dựng đúng tình huống ấy: 2.400 hàng đã sắp, 2.000 hàng đầu thuộc cụm A.
        var rows: [[Double]] = []
        for i in 0..<2_000 { rows.append([Double(i % 5) * 0.1, 0]) }
        for i in 0..<400 { rows.append([100 + Double(i % 5) * 0.1, 0]) }
        let result = try Clustering.kMeans(rows: rows, columns: names, k: 2)
        // Hai cụm rất xa nhau → silhouette phải gần 1. Nếu mẫu chỉ trúng cụm A thì mọi điểm
        // trong mẫu có cùng nhãn, `b` không tồn tại, và điểm sẽ tính sai hoặc thành nil.
        XCTAssertGreaterThan(try XCTUnwrap(result.silhouette), 0.9)
    }

    // MARK: - Chỉ mục lưới, kiểm TRỰC TIẾP

    func testLUOIChoDungTAPHANGXOMNhuQuetThang() {
        // `testLUOIVaQUETTHANGChoCUNGKetQua` so hai đường qua DBSCAN, và phép so ấy có thể thành
        // RỖNG nếu một ngày nào đó `useGrid` lặng lẽ thành false ở 2 chiều. Bài này so thẳng ở
        // mức chỉ mục, và so TỪNG tập hàng xóm chứ không so kết quả cuối.
        var generator = SeededGenerator(seed: 2_026)
        var points: [[Double]] = []
        for _ in 0..<400 {
            // Ba đám chồng lấn nhau một phần — hàng xóm nằm rải qua nhiều ô lưới, kể cả ô chéo.
            let cluster = Int(generator.nextUnit() * 3)
            points.append([
                Double(cluster) * 1.4 + generator.nextUnit(),
                Double(cluster % 2) * 1.4 + generator.nextUnit(),
            ])
        }

        for radius in [0.05, 0.3, 0.71, 1.0, 3.5] {
            let index = NeighbourIndex(points: points, radius: radius)
            for probe in stride(from: 0, to: points.count, by: 17) {
                let viaGrid = Set(index.neighbours(of: probe))
                let viaScan = Set(points.indices.filter {
                    Clustering.squaredDistance(points[probe], points[$0]) <= radius * radius
                })
                XCTAssertEqual(viaGrid, viaScan, "bán kính \(radius), điểm \(probe)")
            }
        }
    }

    func testLUOIBanKinh0HoacKhongHuuHanThiQUETTHANG() {
        // Bán kính 0 làm phép chia toạ độ cho 0 → toạ độ ô là ±vô cùng, và mọi điểm rơi vào một
        // ô. Quét thẳng vẫn cho câu trả lời ĐÚNG, chỉ chậm — đúng thứ tự ưu tiên.
        let points: [[Double]] = [[0, 0], [0, 0], [1, 1]]
        XCTAssertEqual(Set(NeighbourIndex(points: points, radius: 0).neighbours(of: 0)), [0, 1])
        XCTAssertEqual(
            Set(NeighbourIndex(points: points, radius: .infinity).neighbours(of: 0)), [0, 1, 2])
    }

    // MARK: - Bộ sinh số

    func testSEEDEDGENERATORTatDinhVaNamTrong0_1() {
        var a = SeededGenerator(seed: 12_345)
        var b = SeededGenerator(seed: 12_345)
        var c = SeededGenerator(seed: 12_346)
        var sameCount = 0
        for _ in 0..<1_000 {
            let x = a.nextUnit()
            XCTAssertGreaterThanOrEqual(x, 0)
            XCTAssertLessThan(x, 1, "khai [0, 1) thì KHÔNG được trả về 1")
            XCTAssertEqual(x, b.nextUnit())
            if x == c.nextUnit() { sameCount += 1 }
        }
        XCTAssertLessThan(sameCount, 5, "hai seed khác nhau phải cho hai dòng khác nhau")
    }
}
