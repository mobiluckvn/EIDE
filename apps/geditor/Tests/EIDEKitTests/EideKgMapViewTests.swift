import AppKit
import XCTest

@testable import EIDEKit

/// Nửa bản đồ của màn 7 — mười năng lực `view.*` trước hôm nay không cái nào hiện được.
///
/// Bất biến của khung nhìn này: **bản đồ phải nói ra chỗ TRỐNG, không chỉ chỗ có.** Một bản đồ
/// tri thức với 13.494 fact vẫn có thể thiếu đúng thanh ghi đang cần, và `coverage_map` là
/// năng lực duy nhất trong nhóm biết phần hệ thống KHÔNG biết.
final class EideKgMapViewTests: XCTestCase {

    private func chu(_ m: ManHinhCoSo) -> String {
        let hang = m.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }
        return ([m.tomTat.stringValue]
                + m.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
                + hang.compactMap { ($0 as? NSTextField)?.stringValue }
                + hang.compactMap { ($0 as? NSButton)?.title }).joined(separator: " ")
    }

    // MARK: - Độ phủ: con số đáng lên tiêu đề nhất

    func testTIEUDEmangTIlePHUchuKhongMangTONGsoFACT() {
        // Tổng số fact là con số dễ làm người ta yên tâm mà không nói được gì.
        let v = KgMapView()
        v.capNhat(ketQua: ["heatmap": [
            "I2C1": ["registers_total": 10, "with_facts": 9, "reviewed": 7],
            "SPI1": ["registers_total": 12, "with_facts": 2, "reviewed": 0, "requested": 3],
        ]])
        XCTAssertEqual(v.tiLePhu ?? 0, 11.0 / 22.0, accuracy: 0.001)
        XCTAssertEqual(v.soNgoaiViTrong, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("phủ 50%"), v.tomTat.stringValue)
        XCTAssertTrue(v.tomTat.stringValue.contains("NGOẠI VI THIẾU TRI THỨC"),
                      v.tomTat.stringValue)
    }

    func testNGOAIViPHUthapLENtruoc() {
        // Đó là chỗ mã sinh ra sẽ phải đoán.
        let v = KgMapView()
        v.capNhat(ketQua: ["heatmap": [
            "I2C1": ["registers_total": 10, "with_facts": 10],
            "SPI1": ["registers_total": 10, "with_facts": 1],
        ]])
        let dau = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { ($0 as? NSTextField)?.stringValue }.first
        XCTAssertEqual(dau, "SPI1")
    }

    func testNGUONGphuYEUla05() {
        XCTAssertEqual(KgMapView.nguongPhuYeu, 0.5)
    }

    // MARK: - Đồ thị: nhóm theo tầng tin cậy

    func testNUTnhomTHEOtangTINcay() {
        // Một danh sách 500 nút phẳng thì không ai đọc. Nhóm theo `tier` trả lời đúng câu người
        // dùng hỏi: bao nhiêu phần tri thức này đáng tin?
        let v = KgMapView()
        v.capNhat(ketQua: ["graph": [
            "nodes": [
                ["id": "n1", "label": "I2C1", "kind": "periph", "tier": "gold"],
                ["id": "n2", "label": "CR1", "kind": "reg", "tier": "gold"],
                ["id": "n3", "label": "SDO", "kind": "pin", "tier": "bronze",
                 "status": "conflict"],
            ],
            "edges": [["from": "n1", "to": "n2"]],
        ]])
        XCTAssertEqual(v.soNut, 3)
        XCTAssertEqual(v.soCanh, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("3 nút · 1 liên kết"), v.tomTat.stringValue)

        let s = chu(v)
        XCTAssertTrue(s.contains("vàng"), s)
        XCTAssertTrue(s.contains("đang mâu thuẫn"), s)

        // Vàng trước đồng — thứ tự tầng, không phải thứ tự từ điển.
        let nhan = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { ($0 as? NSTextField)?.stringValue }
        XCTAssertEqual(nhan.first, "vàng")
    }

    func testBAMnutMObanDOlanCAN() {
        let v = KgMapView()
        var nhan: String?
        v.onMoNut = { nhan = $0 }
        v.capNhat(ketQua: ["graph": ["nodes": [["id": "chip:st/periph:I2C1", "tier": "gold"]]]])
        let nut = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { $0 as? NSButton }.first
        nut?.performClick(nil)
        XCTAssertEqual(nhan, "chip:st/periph:I2C1")
    }

    // MARK: - Mâu thuẫn: thứ duy nhất ở màn này CHẶN việc

    func testMAUthuanLENdauTHANvaToDO() {
        let v = KgMapView()
        v.capNhat(ketQua: [
            "graph": ["nodes": [["id": "n1", "tier": "gold"]]],
            "rows": [["conflict_id": "c_1", "subject": "chip:st/periph:I2C1/addr",
                      "a": "0x76", "b": "0x77", "tiers": ["gold", "bronze"]]],
        ])
        XCTAssertEqual(v.soXungDot, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("1 MÂU THUẪN"), v.tomTat.stringValue)

        let hang = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
        let mau = hang.first?.last.flatMap { ($0 as? NSTextField)?.textColor }
        XCTAssertEqual(mau, EideToken.Mau.bad, "mâu thuẫn phải là dòng đầu và tô đỏ")
        XCTAssertTrue(chu(v).contains("0x76 ⟷ 0x77"), chu(v))
    }

    // MARK: - Truy nguồn

    func testDUONGtoiNGUONhienCAchuoi() {
        // VIEW-02 trả đường đi tới nguồn — câu trả lời cho "vì sao tin fact này". Hiện mỗi
        // điểm cuối thì mất đúng phần giải thích.
        let v = KgMapView()
        v.capNhat(ketQua: [
            "graph": ["nodes": []],
            "paths_to_sources": [["fact:f_1", "src:STM32F411.svd", "doc:RM0383 tr.47"]],
        ])
        XCTAssertTrue(chu(v).contains("fact:f_1 → src:STM32F411.svd → doc:RM0383 tr.47"), chu(v))
    }

    func testVETtruyHOIhienDIEMcuaTUNGdoan() {
        // Không kèm điểm thì người đọc không phân biệt đoạn khớp chắc chắn với đoạn vừa đủ qua
        // ngưỡng.
        let v = KgMapView()
        v.capNhat(ketQua: [
            "chunks": [["id": "ch_1", "text": "I2C1 base 0x40005400"]],
            "scores": ["ch_1": 0.93],
            "graph_path": ["q", "fact:f_1"],
        ])
        let s = chu(v)
        XCTAssertTrue(s.contains("0.93"), s)
        XCTAssertTrue(s.contains("q → fact:f_1"), s)
    }

    func testSOsanhNGUONnoiRAcoBAOnhieuDIEMkhac() {
        let v = KgMapView()
        v.capNhat(ketQua: ["comparison": [
            ["source": "datasheet", "answer": "0x76", "differences": []],
            ["source": "errata", "answer": "0x77", "differences": ["addr"]],
        ]])
        XCTAssertTrue(chu(v).contains("1 điểm khác"), chu(v))
    }

    // MARK: - Chung

    func testRONGthiNOIRAcachLAMtiep() {
        let v = KgMapView()
        v.capNhat(ketQua: [:])
        let s = chu(v)
        XCTAssertTrue(s.contains("/view.kg_map"), s)
        XCTAssertTrue(s.contains("/view.coverage_map"), s)
        XCTAssertEqual(v.accessibilityRole(), .group)
    }

    func testDOTHIdungXONGmaKHONGconNUTnaoTHInoiRA() {
        let v = KgMapView()
        v.capNhat(ketQua: ["graph": ["nodes": [], "edges": []]])
        XCTAssertEqual(v.soNut, 0)
        XCTAssertTrue(chu(v).contains("chưa có fact"), chu(v))
    }
}
