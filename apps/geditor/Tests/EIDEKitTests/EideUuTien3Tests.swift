import AppKit
import XCTest
@testable import EIDEKit

/// Hai mục ưu tiên 3 của USECASE §4 — vòng đời dự án (UC-A6/A7) và ngân sách token (UC-F7).
final class EideUuTien3Tests: XCTestCase {

    @MainActor
    private func _chu(_ m: ManHinhCoSo) -> String {
        func quet(_ v: NSView) -> [String] {
            var ra: [String] = []
            if let t = v as? NSTextField { ra.append(t.stringValue) }
            for c in v.subviews { ra += quet(c) }
            return ra
        }
        return ([m.tomTat.stringValue] + quet(m.cot)).joined(separator: "\n")
    }

    // MARK: - Mục 8 · Ngân sách ngày

    @MainActor
    func testCONnhieuTHIhienXANHvaKHONGcanhBAO() {
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [], "budget": [
            "daily_budget_usd": 5.0, "spent_usd": 0.5, "remaining_usd": 4.5,
            "warn_pct": 20.0, "sap_het": false,
        ]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("4.5000") && chu.contains("5.00"), chu)
        XCTAssertTrue(chu.contains("90%"), chu)
        XCTAssertFalse(chu.contains("LEO THANG"), "còn 90% mà đã doạ leo thang: \(chu)")
    }

    @MainActor
    func testSAPhetTHInoiRAhauQUAchuKHONGchiNOIcoSO() {
        // APD-08 §5: ngân sách ngày còn dưới 20% là MỘT TRONG NĂM lý do leo thang. Người đọc
        // cần biết VIỆC GÌ SẮP KHÔNG CHẠY, không chỉ biết một con số nhỏ.
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [], "budget": [
            "daily_budget_usd": 5.0, "spent_usd": 4.6, "remaining_usd": 0.4,
            "warn_pct": 20.0, "sap_het": true,
        ]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("LEO THANG"), chu)
        XCTAssertTrue(chu.contains("daily_budget_usd"), "phải nói chỗ nâng trần: \(chu)")
    }

    @MainActor
    func testKHONGcoTRANthiNOIRAchuKHONGhienCON100() {
        // `daily_budget_usd` vắng nghĩa là chưa ai đặt trần. Một thanh đầy màu xanh ở đó là lời
        // trấn an không có căn cứ.
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [], "budget": ["spent_usd": 1.25, "calls_today": 3]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("chưa đặt trần"), chu)
        XCTAssertTrue(chu.contains("1.2500"), "vẫn phải nói đã tiêu bao nhiêu: \(chu)")
        XCTAssertFalse(chu.contains("100%"), chu)
    }

    @MainActor
    func testKHONGcoKHOInganSACHthiKHONGhienGI() {
        let v = ModelsView()
        v.capNhat(ketQua: ["events": []])
        XCTAssertFalse(_chu(v).contains("ngân sách ngày"), _chu(v))
    }

    @MainActor
    func testNGANSACHhongKIEUkhongLAMnoHONG() {
        let v = ModelsView()
        for xau in [["daily_budget_usd": "năm đô"], ["daily_budget_usd": 0],
                    ["remaining_usd": NSNull()], [:]] as [[String: Any]] {
            v.capNhat(ketQua: ["events": [], "budget": xau])
        }
        XCTAssertNotNil(v)
    }

    @MainActor
    func testTIEUquaTRANthiKHONGhienSOam() {
        // Chi phí vượt trần là chuyện có thật (một lượt gọi đắt bất ngờ). "Còn -0,3 USD" là một
        // con số không có nghĩa với ai.
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [], "budget": [
            "daily_budget_usd": 5.0, "spent_usd": 5.3, "remaining_usd": 0.0, "sap_het": true,
        ]])
        // Tìm SỐ ÂM, không tìm dấu gạch: "APD-08" và "daily_budget_usd" đều có gạch, và một
        // test bắt cả chúng là một test đỏ vì lý do không liên quan gì tới điều nó canh.
        let chu = _chu(v)
        XCTAssertFalse(chu.contains("còn -") || chu.contains("-0."), chu)
        XCTAssertTrue(chu.contains("0.0000"), "vượt trần thì còn 0, không phải số âm: \(chu)")
    }
}
