import XCTest
@testable import GEditorCore

/// FR-KNW-902 — Chunk Inspector.
final class ChunkInspectorTests: XCTestCase {

    private func buffer(_ lines: [String]) -> TextBuffer {
        TextBuffer(original: MemoryByteSource(Array(lines.joined(separator: "\n").utf8)))
    }

    private func record(_ object: [String: Any]) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    // MARK: - Đoán schema

    func testDOANDUNGTruongVanBanVaDinhDanhTheoTenQuen() {
        let lines = (0 ..< 20).map { index in
            record(["id": "c\(index)", "text": "nội dung khá dài của chunk số \(index)",
                    "nguon": index % 2 == 0 ? "web" : "pdf"])
        }
        let report = ChunkInspector.inspect(buffer: buffer(lines))
        XCTAssertEqual(report.schema.text, "text")
        XCTAssertEqual(report.schema.id, "id")
        XCTAssertEqual(report.schema.metadataFields, ["nguon"])
    }

    /// Tên LẠ nhưng hình dạng đúng thì vẫn đoán ra — điểm không chỉ dựa vào tên.
    func testDOANDUOCKhiTenTruongLa() {
        let lines = (0 ..< 20).map { index in
            record(["ma_dinh_danh": "x\(index)",
                    "phan_noi_dung": String(repeating: "chữ ", count: 40) + "\(index)"])
        }
        let report = ChunkInspector.inspect(buffer: buffer(lines))
        XCTAssertEqual(report.schema.text, "phan_noi_dung")
        XCTAssertEqual(report.schema.id, "ma_dinh_danh")
    }

    /// Trường TÊN là `id` mà giá trị trùng gần hết thì KHÔNG được coi là định danh.
    ///
    /// Đây là vế mà cách đoán chỉ-theo-tên không bao giờ bắt được, và nó gặp thật: một pipeline
    /// gán `id` theo TÀI LIỆU nguồn chứ không theo chunk, nên hai mươi chunk cùng một `id`.
    func testTENLaIdNhungGiaTriTrungThiKhongPhaiDinhDanh() {
        let lines = (0 ..< 20).map { index in
            record(["id": "cùng-một-giá-trị",
                    "khoa": "k\(index)",
                    "text": "nội dung khá dài của chunk số \(index)"])
        }
        let report = ChunkInspector.inspect(buffer: buffer(lines))
        XCTAssertEqual(report.schema.id, "khoa", "\(report.schema.idCandidates)")
    }

    /// Ứng viên mang theo LÝ DO tính điểm — người đọc chấm lại được.
    func testUNGVIENMangTheoLyDoTinhDiem() throws {
        let lines = (0 ..< 5).map { record(["text": "nội dung \($0)", "id": "c\($0)"]) }
        let report = ChunkInspector.inspect(buffer: buffer(lines))
        let candidate = try XCTUnwrap(report.schema.textCandidates.first)
        XCTAssertTrue(candidate.reason.contains("phủ"), candidate.reason)
        XCTAssertTrue(candidate.reason.contains("dài trung bình"), candidate.reason)
        XCTAssertTrue(candidate.reason.contains("tên quen"), candidate.reason)
    }

    /// Trường metadata LỒNG được nhận ra.
    func testNHANRAMetadataLong() {
        let lines = (0 ..< 5).map { index in
            record(["text": "nội dung \(index)", "metadata": ["nguon": "web", "trang": index]])
        }
        let report = ChunkInspector.inspect(buffer: buffer(lines))
        XCTAssertEqual(report.schema.nestedMetadataField, "metadata")
    }

    /// Trường có nhiều KIỂU khác nhau được kể ra — dấu hiệu schema không nhất quán.
    func testKIEUKhongNhatQuanDuocKeRa() throws {
        let report = ChunkInspector.inspect(buffer: buffer([
            record(["text": "một", "trang": 1]),
            record(["text": "hai", "trang": "2"]),
        ]))
        let field = try XCTUnwrap(report.fields.first { $0.name == "trang" })
        XCTAssertEqual(Set(field.kinds), Set([.number, .string]))
    }

    // MARK: - Thống kê

    /// Histogram đếm tay được: ba chunk 1 · 2 · 3 từ.
    func testHISTOGRAMDemTayDuoc() {
        let report = ChunkInspector.inspect(buffer: buffer([
            record(["text": "một"]),
            record(["text": "một hai"]),
            record(["text": "một hai ba"]),
        ]), config: .init(histogramBuckets: 3))
        XCTAssertEqual(report.words.minimum, 1)
        XCTAssertEqual(report.words.maximum, 3)
        XCTAssertEqual(report.words.total, 3)
        XCTAssertEqual(report.words.counts.reduce(0, +), 3)
        XCTAssertEqual(report.words.average, 2, accuracy: 1e-9)
        XCTAssertEqual(report.characters.minimum, 3)          // "một"
        XCTAssertEqual(report.characters.maximum, 10)         // "một hai ba"
    }

    /// Histogram chia đều theo GIÁ TRỊ, nên cái ĐUÔI hiện ra thành một cột lẻ loi.
    ///
    /// Chia theo phân vị cho các cột cao bằng nhau — đẹp, và giấu đúng thứ người xem đang tìm.
    func testHISTOGRAMChiaDeuTheoGiaTriNenDuoiHienRa() {
        var lines = (0 ..< 99).map { _ in record(["text": "ngắn"]) }
        lines.append(record(["text": String(repeating: "x", count: 1_000)]))
        let report = ChunkInspector.inspect(buffer: buffer(lines), config: .init(histogramBuckets: 10))
        XCTAssertEqual(report.characters.counts.first, 99)
        XCTAssertEqual(report.characters.counts.last, 1)
    }

    /// "Độ dài ký tự" ở đây đếm theo **ký tự Unicode (scalar)**, không theo cụm hiển thị.
    ///
    /// Khác biệt này CÓ THẬT với tiếng Việt: `"ề"` viết dạng tổ hợp (NFD) là hai scalar mà một
    /// cụm. Chọn scalar vì đếm cụm chạy thuật toán ngắt của Unicode trên từng ký tự và chiếm
    /// 57,7% lượt thống kê 1 GB — và vì ngưỡng độ dài của model cũng đếm theo scalar/byte.
    /// Ghim bằng bài kiểm để không ai "sửa" nó thành `text.count` mà không biết cái giá.
    func testDODAIDemTheoScalarKhongTheoCumHienThi() {
        // "ề" tổ hợp: "e" + U+0302 (mũ) + U+0300 (huyền) → 3 scalar, 1 cụm hiển thị.
        let combining = "e\u{0302}\u{0300}"
        XCTAssertEqual(combining.count, 1, "tiền đề: đây là MỘT cụm hiển thị")
        XCTAssertEqual(combining.unicodeScalars.count, 3, "tiền đề: và BA scalar")

        let report = ChunkInspector.inspect(buffer: buffer([record(["text": combining])]))
        XCTAssertEqual(report.characters.minimum, 3)
    }

    // MARK: - Rỗng và trùng

    func testCHUNKRONGDuocBatVaKeRaTheoDong() {
        let report = ChunkInspector.inspect(buffer: buffer([
            record(["text": "có nội dung"]),
            record(["text": ""]),
            record(["text": "   "]),
            record(["text": "cũng có nội dung"]),
        ]))
        XCTAssertEqual(report.emptyCount, 2)
        XCTAssertEqual(report.emptyLines, [1, 2])
    }

    /// Trùng ở đây là trùng CHÍNH XÁC — khác một khoảng trắng là KHÔNG trùng.
    ///
    /// Trùng gần là việc của FR-KNW-922, và cố ý không gộp: hai phép đo trả lời hai câu hỏi
    /// khác nhau với hai cái giá khác nhau.
    func testTRUNGLaTrungCHINHXAC() {
        let report = ChunkInspector.inspect(buffer: buffer([
            record(["text": "cùng một nội dung"]),
            record(["text": "khác hẳn"]),
            record(["text": "cùng một nội dung"]),
            record(["text": "cùng  một nội dung"]),   // hai khoảng trắng
        ]))
        XCTAssertEqual(report.duplicateGroups, [[0, 2]])
        XCTAssertEqual(report.duplicateCount, 1)
    }

    // MARK: - Lọc theo metadata

    func testLOCTHEOMetadataRaDungDong() {
        let lines = (0 ..< 6).map { index in
            record(["text": "nội dung \(index)", "nguon": index % 3 == 0 ? "web" : "pdf"])
        }
        let document = buffer(lines)
        XCTAssertEqual(
            ChunkInspector.lines(buffer: document, field: "nguon", equals: "\"web\""), [0, 3])
        XCTAssertEqual(
            ChunkInspector.lines(buffer: document, field: "nguon", equals: "\"pdf\""),
            [1, 2, 4, 5])
        XCTAssertEqual(
            ChunkInspector.lines(buffer: document, field: "nguon", equals: "\"khong-co\""), [])
    }

    /// Trường ÍT giá trị khác nhau thì có danh sách lọc; trường nhiều thì KHÔNG.
    ///
    /// Giữ danh sách cho một trường có một triệu giá trị riêng là dựng một bảng nặng bằng cả
    /// tệp để phục vụ một hộp chọn không ai kéo nổi.
    func testDANHSACHLOCChiCoVoiTruongItGiaTri() throws {
        let lines = (0 ..< 300).map { index in
            record(["text": "nội dung \(index)", "nguon": index % 3 == 0 ? "web" : "pdf",
                    "khoa": "k\(index)"])
        }
        let report = ChunkInspector.inspect(buffer: buffer(lines))
        let source = try XCTUnwrap(report.fields.first { $0.name == "nguon" })
        XCTAssertEqual(source.topValues.map(\.value), ["\"pdf\"", "\"web\""])
        XCTAssertEqual(source.topValues.map(\.count), [200, 100])

        let key = try XCTUnwrap(report.fields.first { $0.name == "khoa" })
        XCTAssertEqual(key.distinctCount, 300)
        XCTAssertTrue(key.topValues.isEmpty, "trường 300 giá trị riêng không được giữ danh sách")
    }

    // MARK: - Ranh giới

    /// Dòng không đọc được thì ĐẾM và không làm hỏng phần còn lại.
    func testDONGHONGDuocDemVaKhongLamHongPhanConLai() {
        let report = ChunkInspector.inspect(buffer: buffer([
            record(["text": "một"]),
            "{ đây không phải json }",
            record(["text": "hai"]),
        ]))
        XCTAssertEqual(report.invalidCount, 1)
        XCTAssertEqual(report.recordCount, 2)
    }

    /// Không đoán được trường văn bản thì KHÔNG bịa thống kê.
    func testKHONGDOANDUOCThiKhongBiaThongKe() {
        let report = ChunkInspector.inspect(buffer: buffer([
            record(["a": 1, "b": 2]),
            record(["a": 3, "b": 4]),
        ]))
        XCTAssertNil(report.textField)
        XCTAssertEqual(report.recordCount, 0)
        XCTAssertEqual(report.characters.total, 0)
    }

    /// Ép trường văn bản thì bộ này nghe theo, không cãi bằng phép đoán của nó.
    func testEPTRUONGVANBANThiNgheTheo() {
        let lines = (0 ..< 5).map { index in
            record(["text": "dài hơn hẳn nên phép đoán sẽ chọn nó \(index)",
                    "tom_tat": "ngắn \(index)"])
        }
        let report = ChunkInspector.inspect(
            buffer: buffer(lines), config: .init(textField: "tom_tat"))
        XCTAssertEqual(report.textField, "tom_tat")
        XCTAssertEqual(report.characters.maximum, "ngắn 4".count)
    }

    /// Giá trị có KÝ TỰ THOÁT vẫn thống kê được — đường tắt byte bỏ cuộc thì có đường lui.
    func testGIATRICoKyTuThoatVanThongKeDuoc() {
        let report = ChunkInspector.inspect(buffer: buffer([
            #"{"text":"có dấu ngoặc \" bên trong"}"#,
            #"{"text":"bình thường"}"#,
        ]))
        XCTAssertEqual(report.recordCount, 2)
        XCTAssertEqual(report.emptyCount, 0)
    }

    /// Hai lượt chạy cho kết quả GIỐNG HỆT.
    func testHAILUOTCHAYChoKetQuaGiongHet() {
        let lines = (0 ..< 200).map { index in
            record(["id": "c\(index)", "text": "nội dung số \(index % 37)",
                    "nguon": index % 4 == 0 ? "web" : "pdf"])
        }
        let document = buffer(lines)
        let first = ChunkInspector.inspect(buffer: document)
        let second = ChunkInspector.inspect(buffer: document)
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.duplicateGroups.isEmpty)
    }
}
