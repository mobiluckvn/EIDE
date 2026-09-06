import XCTest
@testable import GEditorCore

final class AprioriTests: XCTestCase {

    // MARK: - Đọc đầu vào

    func testDANGGIOHANGBoTrungTrongCungMotGio() {
        // Mua hai hộp sữa vẫn là MỘT giao dịch có sữa. Không bỏ trùng thì support của item ấy
        // phồng theo số lượng mua chứ không theo số giao dịch, và mọi con số sau đó sai theo.
        let baskets = Apriori.baskets(from: ["sữa, bánh, sữa", " tã ,, bia "])
        XCTAssertEqual(baskets[0], ["bánh", "sữa"])
        XCTAssertEqual(baskets[1], ["bia", "tã"])
    }

    func testDANGLONGGomTheoMaGiaoDich_GiuThuTuXuatHien() {
        let (baskets, rows) = Apriori.baskets(
            transactionIDs: ["T2", "T1", "T2", "T1", nil, "T3"],
            items: ["bia", "sữa", "tã", "bánh", "x", "sữa"])
        XCTAssertEqual(baskets, [["bia", "tã"], ["bánh", "sữa"], ["sữa"]])
        // Chỉ số hàng gốc phải giữ được — cần cho việc bấm luật rồi tô dòng nguồn.
        XCTAssertEqual(rows, [[0, 2], [1, 3], [5]])
    }

    // MARK: - Bẫy lớn nhất: confidence cao mà vô nghĩa

    func testCONFIDENCECAOMaLIFTDUOI1ThiPhaiCANHBAO() throws {
        // «túi nylon» có trong 95% giỏ. Người mua «tã» thì 80% cũng lấy túi — nghe như một phát
        // hiện, nhưng 80% < 95%, tức người mua tã lấy túi ÍT HƠN trung bình. Confidence 80% ở
        // đây là một con số đúng dẫn tới kết luận NGƯỢC.
        // Dựng bằng cách LOẠI TRỪ chứ không bằng hai điều kiện chồng nhau — bản đầu của bài
        // kiểm này viết `if index < 95` và `if index >= 90`, tưởng cho 8 giỏ chung, thật ra chỉ
        // 3. Ở đây liệt kê thẳng những giỏ KHÔNG có túi, nên đếm được bằng mắt.
        let khongCoTui: Set<Int> = [0, 1, 50, 51, 52]      // túi: 95/100 giỏ
        var baskets: [[String]] = []
        for index in 0..<100 {
            var basket = ["hàng\(index % 7)"]
            if !khongCoTui.contains(index) { basket.append("túi") }
            if index < 10 { basket.append("tã") }          // tã: 10 giỏ, 8 trong đó có túi
            baskets.append(basket.sorted())
        }

        let result = try Apriori.run(
            baskets: baskets, minimumSupport: 0.05, minimumConfidence: 0.5)
        let rule = try XCTUnwrap(
            result.rules.first { $0.antecedent == ["tã"] && $0.consequent == ["túi"] })

        XCTAssertEqual(rule.confidence, 0.8, accuracy: 1e-9, "confidence TRÔNG cao")
        XCTAssertLessThan(rule.lift, 1, "nhưng lift dưới 1: liên hệ NGƯỢC")
        XCTAssertLessThan(rule.leverage, 0)
        XCTAssertTrue(rule.caution.contains("BỚT khả năng"), rule.caution)
    }

    func testMACDINHSapTheoLIFTChuKhongTheoCONFIDENCE() throws {
        // Sắp theo confidence đưa lên đầu bảng đúng những luật vô nghĩa nhất.
        var baskets: [[String]] = []
        for index in 0..<100 {
            var basket = ["phổ_biến"]                       // có trong MỌI giỏ
            if index % 10 == 0 { basket += ["a", "b"] }     // a và b luôn đi cùng nhau, 10 giỏ
            baskets.append(basket.sorted())
        }
        let result = try Apriori.run(
            baskets: baskets, minimumSupport: 0.05, minimumConfidence: 0.5)

        let first = try XCTUnwrap(result.rules.first)
        XCTAssertGreaterThan(first.lift, 5, "luật đầu bảng phải là luật có lift cao")

        // Luật `a → phổ_biến` có confidence 100% — cao nhất có thể — mà lift đúng bằng 1.
        let trivial = try XCTUnwrap(
            result.rules.first { $0.antecedent == ["a"] && $0.consequent == ["phổ_biến"] })
        XCTAssertEqual(trivial.confidence, 1, accuracy: 1e-9)
        XCTAssertEqual(trivial.lift, 1, accuracy: 1e-9)
        XCTAssertTrue(trivial.caution.contains("KHÔNG liên quan"), trivial.caution)

        // Và nó KHÔNG được đứng trên luật kia.
        let firstIndex = try XCTUnwrap(result.rules.firstIndex(of: first))
        let trivialIndex = try XCTUnwrap(result.rules.firstIndex(of: trivial))
        XCTAssertLessThan(firstIndex, trivialIndex)
    }

    // MARK: - Bốn con số, tính tay được

    func testBONCHISOTinhTayDuoc() throws {
        // 10 giao dịch. A trong 6, B trong 5, A∪B trong 4.
        //   support(A→B)   = 4/10 = 0,4
        //   confidence     = 4/6  ≈ 0,6667
        //   lift           = 0,6667 / (5/10) = 1,3333
        //   leverage       = 0,4 − 0,6 × 0,5 = 0,1
        var baskets: [[String]] = []
        for _ in 0..<4 { baskets.append(["A", "B"]) }
        for _ in 0..<2 { baskets.append(["A"]) }
        for _ in 0..<1 { baskets.append(["B"]) }
        for index in 0..<3 { baskets.append(["C\(index)"]) }

        let result = try Apriori.run(
            baskets: baskets, minimumSupport: 0.3, minimumConfidence: 0.6)
        let rule = try XCTUnwrap(
            result.rules.first { $0.antecedent == ["A"] && $0.consequent == ["B"] })
        XCTAssertEqual(rule.support, 0.4, accuracy: 1e-12)
        XCTAssertEqual(rule.confidence, 4.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(rule.lift, (4.0 / 6) / 0.5, accuracy: 1e-12)
        XCTAssertEqual(rule.leverage, 0.4 - 0.6 * 0.5, accuracy: 1e-12)
        XCTAssertEqual(rule.count, 4)
    }

    func testNGUONGSUPPORTLamTronLEN() throws {
        // support 0,25 trên 10 giao dịch = 2,5 giao dịch. Làm tròn XUỐNG thành 2 sẽ nhận cả
        // những tập chỉ có 2 giao dịch, tức thấp hơn ngưỡng người dùng khai.
        let baskets = [["A"], ["A"], ["B"], ["B"], ["B"],
                       ["C"], ["C"], ["C"], ["C"], ["D"]]
        let result = try Apriori.run(
            baskets: baskets, minimumSupport: 0.25, minimumConfidence: 0.1)
        XCTAssertTrue(result.methodology.contains("≥ 3 giao dịch"), result.methodology)
        XCTAssertEqual(result.frequentBySize[1], 2, "chỉ B (3) và C (4) đạt ngưỡng")
    }

    // MARK: - Cắt tỉa

    func testCATTIATheoBaoDongXuong() {
        // {A,B} và {A,C} phổ biến, {B,C} KHÔNG. Ứng viên {A,B,C} phải bị loại NGAY ở bước sinh,
        // không phải bị loại sau khi đếm — đó là cả điểm của Apriori.
        let frequent = [["A", "B"], ["A", "C"]]
        XCTAssertTrue(Apriori.generateCandidates(from: frequent, size: 3).isEmpty)

        // Thêm {B,C} vào thì nó qua được.
        let withBC = [["A", "B"], ["A", "C"], ["B", "C"]]
        XCTAssertEqual(
            Apriori.generateCandidates(from: withBC, size: 3), [["A", "B", "C"]])
    }

    func testSINHMOIUNGVIENDUNGMOTLAN() {
        // Vì mọi tập đều sắp theo tên và chỉ ghép khi phần tử cuối tăng dần, không có ứng viên
        // nào sinh hai lần — nếu có thì số đếm ở tầng sau nhân đôi trong im lặng.
        let frequent = [["A"], ["B"], ["C"], ["D"]]
        let candidates = Apriori.generateCandidates(from: frequent, size: 2)
        XCTAssertEqual(candidates.count, 6, "C(4,2) = 6")
        XCTAssertEqual(Set(candidates).count, 6, "không trùng")
    }

    // MARK: - Tập nhiều item

    func testTIMDUOCTapBaItemVaSinhDuLuat() throws {
        var baskets: [[String]] = []
        for _ in 0..<8 { baskets.append(["bánh", "bia", "tã"]) }
        for _ in 0..<2 { baskets.append(["bia"]) }
        for index in 0..<10 { baskets.append(["khác\(index)"]) }

        let result = try Apriori.run(
            baskets: baskets, minimumSupport: 0.3, minimumConfidence: 0.6)
        XCTAssertEqual(result.frequentBySize[3], 1, "phải tìm ra tập 3 item")

        // Tập 3 item sinh ra 6 cách chia (2³ − 2), mọi cách đều phải có mặt nếu đạt ngưỡng.
        let fromTriple = result.rules.filter {
            Set($0.antecedent).union($0.consequent) == ["bánh", "bia", "tã"]
        }
        XCTAssertEqual(fromTriple.count, 6, "\(fromTriple.map(\.text))")
    }

    func testTRANKICHTHUOCTapDuocTonTrong() throws {
        var baskets: [[String]] = []
        for _ in 0..<10 { baskets.append(["A", "B", "C", "D", "E"]) }
        let result = try Apriori.run(
            baskets: baskets, minimumSupport: 0.5, minimumConfidence: 0.5,
            maximumItemsetSize: 2)
        XCTAssertNil(result.frequentBySize[3])
        XCTAssertEqual(result.frequentBySize[2], 10, "C(5,2) = 10")
    }

    // MARK: - Biên

    func testKHONGCoGiaoDichThiNoiRa() throws {
        let result = try Apriori.run(baskets: [[], [], []])
        XCTAssertTrue(result.rules.isEmpty)
        XCTAssertEqual(result.transactionCount, 0)
        XCTAssertTrue(result.methodology.contains("Không có giao dịch nào"))
    }

    func testKHONGLuatNaoDatNguongThiTraVeRONG_KhongHaNguong() throws {
        // Không có gì đi cùng nhau. Trả về rỗng là câu trả lời đúng; tự hạ ngưỡng để "có cái gì
        // đó cho người dùng xem" là bịa ra phát hiện.
        let baskets = (0..<20).map { ["item\($0)"] }
        let result = try Apriori.run(baskets: baskets, minimumSupport: 0.3)
        XCTAssertTrue(result.rules.isEmpty)
        XCTAssertEqual(result.frequentBySize[1], 0)
    }

    func testTIMDUOCGiaoDichCHUATRONMotLuat() throws {
        let baskets = [["A", "B"], ["A"], ["A", "B", "C"], ["B"]]
        let rule = Apriori.Rule(
            antecedent: ["A"], consequent: ["B"], support: 0.5, confidence: 0.66,
            lift: 1.3, leverage: 0.1, count: 2)
        XCTAssertEqual(
            Apriori.Result.transactions(containing: rule, in: baskets), [0, 2])
    }

    func testTATDINH() throws {
        var baskets: [[String]] = []
        for index in 0..<60 {
            baskets.append(["i\(index % 5)", "j\(index % 7)", "k\(index % 3)"].sorted())
        }
        let first = try Apriori.run(baskets: baskets, minimumSupport: 0.1)
        let second = try Apriori.run(baskets: baskets, minimumSupport: 0.1)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.rules.map(\.text), second.rules.map(\.text))
        XCTAssertTrue(first.methodology.contains("TẤT ĐỊNH"))
    }

    func testKHOIPHUONGPHAPNoiRoSaiLechSoVoiDacTa() throws {
        // Đặc tả viết "hash-tree"; ở đây đếm bằng bảng băm. Đó là sai lệch CÓ CHỦ Ý, nên nó phải
        // nằm trong kết quả chứ không chỉ trong chú thích mã.
        let result = try Apriori.run(baskets: [["A", "B"], ["A", "B"]], minimumSupport: 0.5)
        XCTAssertTrue(result.methodology.contains("hash-tree"), result.methodology)
        XCTAssertTrue(result.methodology.contains("BAO ĐÓNG XUỐNG"), result.methodology)
        XCTAssertTrue(result.methodology.contains("CÁCH ĐỌC"), result.methodology)
    }

    func testHuyGiuaChung() {
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(try Apriori.run(
            baskets: [["A", "B"], ["A", "B"]], cancelToken: token))
    }
}
