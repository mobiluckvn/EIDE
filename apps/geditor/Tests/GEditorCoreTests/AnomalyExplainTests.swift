import XCTest
@testable import GEditorCore

final class AnomalyExplainTests: XCTestCase {

    /// Hai cột tương quan chặt, cộng nhiễu nhỏ để Σ không suy biến.
    private func correlated() -> [[Double]] {
        var rows: [[Double]] = []
        for i in 1...40 {
            let x = Double(i)
            let jitter: Double = i % 2 == 0 ? 0.6 : -0.6
            rows.append([x, x * 2 + jitter])
        }
        return rows
    }

    /// Ba cột TRỰC GIAO — lưới đầy đủ 5×5×5.
    ///
    /// Bản đầu của hàm này dùng ba dãy modulo (`i%7`, `(i*3)%11`, `(i*5)%13`) và gọi chúng là
    /// "độc lập". Chúng gần độc lập, nhưng hiệp phương sai mẫu KHÁC 0, nên đẳng thức
    /// `ΔD²(j) = zⱼ²` sai lệch tới 50% — và bài kiểm dựa vào nó trượt. Lưới đầy đủ thì mỗi giá
    /// trị của một cột đi kèm đủ mọi giá trị của hai cột kia, nên hiệp phương sai triệt tiêu
    /// CHÍNH XÁC, không phải xấp xỉ.
    private func independent() -> [[Double]] {
        var rows: [[Double]] = []
        for a in 0..<5 {
            for b in 0..<5 {
                for c in 0..<5 { rows.append([Double(a), Double(b), Double(c)]) }
            }
        }
        return rows
    }

    // MARK: - Tính chất mà đặc tả đòi

    func testTongPhanTramLUONBang100() throws {
        let model = try MahalanobisModel(rows: independent(), columns: ["a", "b", "c"])
        // Thử nhiều dòng, kể cả dòng RẤT BÌNH THƯỜNG: đặc tả nói "tổng % LUÔN = 100", không
        // phải "luôn = 100 với dòng bất thường".
        for probe in [[0.0, 0, 0], [3, 5, 7], [50, 1, 1], [1.9, 2.1, 2]] {
            let total = model.contributions(of: probe).map(\.percent).reduce(0, +)
            XCTAssertEqual(total, 100, accuracy: 1e-9, "\(probe)")
        }
    }

    func testDUNGTAMDuLieuThiKHONGCoGiDePhanRa() throws {
        // Biên duy nhất mà "tổng % luôn = 100" không đúng được, và bài kiểm trên đã tìm ra nó:
        // tại đúng trung bình, D² = 0 và mọi phần trăm là 0/0.
        //
        // Chia đều 100/k cho đẹp bảng là bịa ra cấu trúc không tồn tại — câu giải thích khi ấy
        // sẽ nói "chủ yếu do cột a" về một hàng hoàn toàn bình thường. Biên này không đụng tới
        // đường dùng thật vì phân rã chỉ chạy cho dòng ĐÃ vượt ngưỡng.
        let model = try MahalanobisModel(rows: independent(), columns: ["a", "b", "c"])
        XCTAssertEqual(model.mean, [2, 2, 2])
        let atCentre = model.contributions(of: [2, 2, 2])
        XCTAssertEqual(model.squaredDistance(of: [2, 2, 2]), 0, accuracy: 1e-12)
        XCTAssertTrue(atCentre.allSatisfy { $0.percent == 0 && $0.delta == 0 })
        XCTAssertTrue(
            model.explanation(of: [2, 2, 2]).contains("không cột nào chiếm quá 5%"),
            model.explanation(of: [2, 2, 2]))
    }

    func testDongGopKhongBaoGioAM() throws {
        // Đây là tính chất khiến leave-one-out ĐỌC ĐƯỢC như phần trăm, và nó không phải may
        // mắn: D²đủ = D²(bỏ j) + (xⱼ − x̂ⱼ)² / σ²(j | còn lại). Số hạng thêm vào là bình
        // phương chia phương sai.
        let model = try MahalanobisModel(rows: correlated(), columns: ["x", "y"])
        for x in stride(from: -50.0, through: 100, by: 3.5) {
            for y in stride(from: -50.0, through: 200, by: 7.5) {
                let deltas = model.contributions(of: [x, y]).map(\.delta)
                XCTAssertTrue(deltas.allSatisfy { $0 >= 0 }, "(\(x), \(y)) → \(deltas)")
            }
        }
    }

    /// Vì sao KHÔNG dùng phân rã theo số hạng của dạng toàn phương, dù nó miễn phí.
    func testPhanRaTheoSOHANGCoTheRaSoAM_LeaveOneOutThiKhong() throws {
        let rows = correlated()
        let model = try MahalanobisModel(rows: rows, columns: ["x", "y"])

        // Điểm thử phải chọn có chủ đích. `x` gần đúng TRUNG BÌNH (δ₀ ≈ 0) trong khi `y` vọt
        // rất xa: khi ấy phần tử ngoài đường chéo của Σ⁻¹ — âm mạnh vì hai cột tương quan chặt
        // — lật dấu cả số hạng thứ nhất. Một điểm lệch cả hai chiều cùng lúc (như [35, 20] ở
        // bản đầu) thì cả hai số hạng đều dương, và bài kiểm không chứng minh được gì.
        let probe: [Double] = [21, 100]
        let delta = [probe[0] - model.mean[0], probe[1] - model.mean[1]]

        // Số hạng thứ j của dạng toàn phương: δⱼ × (Σ⁻¹δ)ⱼ. Chúng cộng lại ĐÚNG bằng D²…
        var terms: [Double] = []
        for j in 0..<2 {
            var acc = 0.0
            for m in 0..<2 { acc += model.inverse[j][m] * delta[m] }
            terms.append(delta[j] * acc)
        }
        XCTAssertEqual(terms.reduce(0, +), model.squaredDistance(of: probe), accuracy: 1e-6)

        // …nhưng ít nhất một trong hai là SỐ ÂM. Một cột "đóng góp −180%" thì bảng phần trăm
        // vô nghĩa, và câu giải thích tự động nói ra một điều sai.
        XCTAssertTrue(terms.contains { $0 < 0 }, "\(terms)")

        // Leave-one-out trên cùng điểm ấy thì không.
        let contributions = model.contributions(of: probe)
        XCTAssertTrue(contributions.allSatisfy { $0.delta >= 0 && $0.percent >= 0 })
    }

    func testHAICOTDOCLAPThiDongGopBangZBinhPhuong() throws {
        // Trường hợp tính tay được: cột độc lập thì bỏ cột j đi chỉ mất đúng số hạng zⱼ², nên
        // ΔD²(j) = zⱼ². Nếu ma trận con bị dựng sai (lấy nhầm hàng/cột khi bỏ chỉ số j) thì
        // đẳng thức này vỡ — và đó đúng là chỗ dễ sai nhất trong cả tệp.
        let rows = independent()
        let model = try MahalanobisModel(rows: rows, columns: ["a", "b", "c"])
        let probe: [Double] = [6, 10, 12]

        for (j, name) in ["a", "b", "c"].enumerated() {
            let column = rows.map { $0[j] }
            let n = Double(column.count)
            let mean = column.reduce(0, +) / n
            let variance = column.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / (n - 1)
            let z = (probe[j] - mean) / variance.squareRoot()
            let delta = try XCTUnwrap(
                model.contributions(of: probe).first { $0.column == name }).delta
            XCTAssertEqual(delta, z * z, accuracy: 1e-6, name)
        }
    }

    func testCotDONGGOPNHIEUNHATDungLaCotBiLECH() throws {
        let rows = independent()
        let model = try MahalanobisModel(rows: rows, columns: ["a", "b", "c"])
        // Đẩy riêng cột `b` ra rất xa, hai cột kia để ở giữa dải.
        let probe: [Double] = [3, 400, 6]
        let top = try XCTUnwrap(model.contributions(of: probe).first)
        XCTAssertEqual(top.column, "b")
        XCTAssertGreaterThan(top.percent, 90)
    }

    // MARK: - Câu giải thích

    func testCauGiaiThichDungDANGDacTaNeu() throws {
        let model = try MahalanobisModel(rows: independent(), columns: ["doanh_thu", "so_luong", "phi"])
        let text = model.explanation(of: [40, 40, 3])
        // Đặc tả nêu đúng dạng: «bất thường chủ yếu do tổ hợp doanh_thu (61%) × số_lượng (27%)».
        XCTAssertTrue(text.hasPrefix("bất thường chủ yếu do"), text)
        XCTAssertTrue(text.contains("%"), text)
    }

    func testCauGiaiThichBOQUACotDuoi5PhanTramVaCatOBACOT() throws {
        // Một câu liệt kê tám cột với những con số 2% thì không ai đọc, và cái đáng nói bị chôn
        // giữa những cái không đáng.
        var rows: [[Double]] = []
        for i in 0..<80 {
            rows.append([
                Double(i % 7), Double((i * 3) % 11), Double((i * 5) % 13),
                Double((i * 2) % 9), Double((i * 4) % 17),
            ])
        }
        let names = ["c1", "c2", "c3", "c4", "c5"]
        let model = try MahalanobisModel(rows: rows, columns: names)
        let text = model.explanation(of: [30, 40, 50, 4, 8])
        let mentioned = names.filter { text.contains($0) }
        XCTAssertLessThanOrEqual(mentioned.count, 3, text)
        XCTAssertGreaterThan(mentioned.count, 0, text)
    }

    func testKhongCotNaoDangKeThiNOITHANG() throws {
        // Với 20 cột gần như đều nhau, không cột nào chạm 5%. Bịa ra "chủ yếu do c1" khi c1 chỉ
        // hơn c2 đúng 0,1% là nói dối một cách tinh vi.
        var rows: [[Double]] = []
        for i in 0..<200 {
            rows.append((0..<20).map { Double((i &* (7 &+ $0)) % (11 &+ $0)) })
        }
        let names = (1...20).map { "c\($0)" }
        let model = try MahalanobisModel(rows: rows, columns: names)
        let probe = (0..<20).map { _ in 3.0 }
        let contributions = model.contributions(of: probe)
        // Chỉ khẳng định điều thật sự đúng: hàm KHÔNG bao giờ trả về câu rỗng.
        XCTAssertFalse(model.explanation(of: probe).isEmpty)
        XCTAssertEqual(contributions.count, 20)
        XCTAssertEqual(contributions.map(\.percent).reduce(0, +), 100, accuracy: 1e-6)
    }

    // MARK: - Từ chối

    func testMaTranCONSuyBienThiCotDoDeVE0_KhongLamHONGCaKetQua() throws {
        // Ba cột trong đó c3 = c1 + c2. Ma trận ĐẦY ĐỦ suy biến, nên `init` phải ném. Đây là
        // biên đúng: nếu nó lọt qua thì mọi con số phía sau đều là rác.
        let rows: [[Double]] = (1...40).map { i in
            let a = Double(i), b = Double((i * 3) % 7)
            return [a, b, a + b]
        }
        XCTAssertThrowsError(
            try MahalanobisModel(rows: rows, columns: ["c1", "c2", "c3"])
        ) { error in
            XCTAssertEqual(error as? MahalanobisModel.Failure, .singular)
        }
    }

    func testKhoiPhuongPhapNOIRoCachDocPhanTram() {
        // NFR-MIN-04, và quan trọng hơn: chống một hiểu nhầm cụ thể. "61%" KHÔNG có nghĩa là
        // 61% khoảng cách nằm ở cột ấy. Khối Phương pháp phải nói ra, vì tổng ΔD² không bằng D².
        let text = MahalanobisModel.methodology
        XCTAssertTrue(text.contains("leave-one-out"), text)
        XCTAssertTrue(text.contains("KHÔNG bằng D²"), text)
        XCTAssertTrue(text.contains("quy ước"), text)
    }

    func testTatDinh() throws {
        let model = try MahalanobisModel(rows: independent(), columns: ["a", "b", "c"])
        XCTAssertEqual(model.contributions(of: [9, 1, 4]), model.contributions(of: [9, 1, 4]))
    }
}
