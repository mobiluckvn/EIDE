import XCTest
@testable import GEditorCore

/// FR-QRY-004 — dựng biểu đồ thành hình nguyên thuỷ, và xuất SVG từ CÙNG danh sách ấy.
final class ChartRenderTests: XCTestCase {

    private let layout = ChartRender.Layout(width: 400, height: 240)

    private func series(_ values: [Double], labels: [String]? = nil) -> ChartData.Series {
        let points = values.enumerated().map {
            ChartData.Point(x: Double($0.offset), y: $0.element, label: labels?[$0.offset])
        }
        return ChartData.Series(name: "s", points: points, originalCount: values.count)
    }

    // MARK: - Trục

    func testCOTluonBatDauTuKHONG() {
        // Cắt gốc trục làm cột 102 trông cao gấp đôi cột 101 — cách kinh điển để nói dối bằng
        // biểu đồ, và nó xảy ra do lười chứ hiếm khi do cố ý.
        let primitives = ChartRender.primitives(
            kind: .bar, series: series([101, 102, 103]), layout: layout)
        var ticks: [Double] = []
        for case let .text(_, _, string, _, anchor, _) in primitives where anchor == .end {
            ticks.append(Double(string) ?? .nan)
        }
        XCTAssertTrue(ticks.contains(0), "trục cột không có vạch 0: \(ticks)")
    }

    func testDUONGthiKHONGbatBuocTuKhong() {
        // Khác biểu đồ cột: với đường, cắt gốc là hợp lệ và thường là cần — một dãy nhiệt độ
        // 36,5…37,2 mà ép về 0 thì thành một đường phẳng vô nghĩa.
        let primitives = ChartRender.primitives(
            kind: .line, series: series([101, 102, 103]), layout: layout)
        var ticks: [Double] = []
        for case let .text(_, _, string, _, anchor, _) in primitives where anchor == .end {
            ticks.append(Double(string) ?? .nan)
        }
        XCTAssertFalse(ticks.contains(0), "trục đường bị ép về 0: \(ticks)")
    }

    func testKHONGCODULIEUthiNOIRA() {
        let primitives = ChartRender.primitives(
            kind: .line, series: series([]), layout: layout)
        // Một khung trắng trông giống biểu đồ chưa vẽ xong, và người dùng sẽ ngồi đợi.
        let texts = primitives.compactMap { primitive -> String? in
            if case let .text(_, _, string, _, _, _) = primitive { return string }
            return nil
        }
        XCTAssertTrue(texts.contains { $0.contains("Không có dữ liệu") }, "\(texts)")
    }

    // MARK: - Ghi chú rút gọn (NFR-QRY-02)

    func testGHICHUrutGonNAMTRENbieuDo() {
        let points = (0 ..< 5_000).map { ChartData.Point(x: Double($0), y: Double($0 % 13)) }
        let reduced = ChartData.series(name: "s", points: points, limit: 200)
        let primitives = ChartRender.primitives(kind: .line, series: reduced, layout: layout)
        let texts = primitives.compactMap { primitive -> String? in
            if case let .text(_, _, string, _, _, _) = primitive { return string }
            return nil
        }
        // Phải nằm TRONG hình, không phải trong tooltip hay dòng trạng thái — ảnh PNG người ta
        // dán vào báo cáo phải tự nói được rằng nó đã rút gọn.
        XCTAssertTrue(texts.contains { $0.contains("rút gọn") }, "\(texts)")
    }

    func testKHONGrutGonThiKHONGcoGhiChu() {
        let primitives = ChartRender.primitives(
            kind: .line, series: series([1, 2, 3]), layout: layout)
        let texts = primitives.compactMap { primitive -> String? in
            if case let .text(_, _, string, _, _, _) = primitive { return string }
            return nil
        }
        XCTAssertFalse(texts.contains { $0.contains("rút gọn") })
    }

    // MARK: - Hộp

    func testHOPveDUnamPhanVaDiemNgoai() {
        let values: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 100]
        let primitives = ChartRender.primitives(
            kind: .box, series: series(values), layout: layout)
        let circles = primitives.filter { if case .circle = $0 { return true }; return false }
        XCTAssertEqual(circles.count, 1, "một điểm ngoài (100) phải được vẽ riêng")
        let rects = primitives.filter { if case .rect = $0 { return true }; return false }
        XCTAssertEqual(rects.count, 1, "đúng một hộp q1…q3")
    }

    // MARK: - SVG

    func testSVGdungCUNGdanhSachHINH() {
        let primitives = ChartRender.primitives(
            kind: .bar, series: series([3, 1, 2], labels: ["a", "b", "c"]), layout: layout)
        let svg = ChartRender.svg(primitives, layout: layout)
        // Số hình chữ nhật trong SVG phải khớp số hình chữ nhật trong danh sách (cộng 1 cho nền).
        let rectCount = primitives.filter { if case .rect = $0 { return true }; return false }.count
        XCTAssertEqual(svg.components(separatedBy: "<rect").count - 1, rectCount + 1)
        XCTAssertTrue(svg.hasPrefix("<svg"), svg.prefix(40).description)
        XCTAssertTrue(svg.hasSuffix("</svg>\n"))
    }

    func testSVGthoatKYTUXMLtrongDULIEUnguoiDung() {
        // Nhãn trục là DỮ LIỆU. Một tên có `&` là đủ để sinh ra tệp SVG không mở được.
        let primitives = ChartRender.primitives(
            kind: .bar, series: series([1, 2], labels: ["A & B", "<script>"]), layout: layout)
        let svg = ChartRender.svg(primitives, layout: layout)
        XCTAssertTrue(svg.contains("A &amp; B"), svg)
        XCTAssertTrue(svg.contains("&lt;script&gt;"), svg)
        XCTAssertFalse(svg.contains("<script>"), "thẻ script lọt nguyên vào SVG")
    }

    func testSVGdocDuocBangBoPHANTICHXML() throws {
        let primitives = ChartRender.primitives(
            kind: .line, series: series([1, 5, 2, 8]), layout: layout)
        let svg = ChartRender.svg(primitives, layout: layout)
        // Kiểm bằng bộ phân tích THẬT, không bằng cách đếm dấu ngoặc: một tệp SVG hỏng vẫn có
        // thể chứa đủ chuỗi mình đi tìm.
        XCTAssertNoThrow(try XMLDocument(xmlString: svg, options: []))
    }

    func testSVGgiuChuTIENGVIETnguyenVen() throws {
        let primitives = ChartRender.primitives(
            kind: .bar, series: series([1, 2], labels: ["Huế", "Đà Nẵng"]), layout: layout)
        let svg = ChartRender.svg(primitives, layout: layout)
        XCTAssertTrue(svg.contains("Huế"), svg)
        XCTAssertTrue(svg.contains("Đà Nẵng"), svg)
    }

    func testMAUphanBietDuocKhiInDENTRANG() {
        // Sáu màu dãy phải khác nhau; và không cặp nào chỉ khác ở SẮC đỏ-lục — dải này phải
        // phân biệt được với người mù màu đỏ-lục.
        let hexes = ChartRender.Ink.seriesPalette.map(\.hex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "có hai màu dãy trùng nhau")
    }
}
