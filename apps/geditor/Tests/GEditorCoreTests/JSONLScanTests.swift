import XCTest
@testable import GEditorCore

/// FR-KNW-901 — chế độ JSONL.
final class JSONLScanTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer {
        TextBuffer(original: MemoryByteSource(Array(text.utf8)))
    }

    // MARK: - Kiểm

    func testDEMDUNGBanGhiHopLeVaDongTrang() {
        let result = JSONLScan.scan(buffer: buffer("""
            {"a":1}
            {"a":2}

            {"a":3}
            """))
        XCTAssertEqual(result.lineCount, 4)
        XCTAssertEqual(result.recordCount, 3)
        XCTAssertEqual(result.objectCount, 3)
        XCTAssertEqual(result.blankCount, 1)
        XCTAssertEqual(result.problemCount, 0)
    }

    /// Số hiệu dòng của lỗi là số hiệu dòng TÀI LIỆU, không phải thứ tự bản ghi hợp lệ.
    ///
    /// Đánh số lại theo bản ghi hợp lệ thì "bấm để nhảy tới dòng" nhảy sai đúng vào lúc người
    /// dùng cần nó nhất — lúc đang sửa một tệp có lỗi.
    func testSOHIEUDONGLoiLaSoHieuDongTaiLieu() {
        let result = JSONLScan.scan(buffer: buffer("""
            {"a":1}
            {hỏng}
            {"a":3}
            {"b":}
            """))
        XCTAssertEqual(result.problems.map(\.line), [1, 3])
        XCTAssertEqual(result.recordCount, 2)
        XCTAssertEqual(result.problemCount, 2)
    }

    /// Lỗi mang theo vị trí TRONG dòng, không chỉ số hiệu dòng.
    func testLOIMangTheoViTriTrongDong() {
        let result = JSONLScan.scan(buffer: buffer(#"{"a":1,}"#))
        XCTAssertEqual(result.problems.count, 1)
        XCTAssertEqual(result.problems[0].offset, 7)
    }

    /// Dòng cuối KHÔNG có ký tự xuống dòng vẫn là một dòng.
    func testDONGCUOIKhongXuongDongVanLaMotDong() {
        let result = JSONLScan.scan(buffer: buffer("{\"a\":1}\n{\"a\":2}"))
        XCTAssertEqual(result.lineCount, 2)
        XCTAssertEqual(result.recordCount, 2)
    }

    /// `\r\n` bị cắt trước khi kiểm.
    ///
    /// Không cắt thì MỌI dòng của một tệp sinh trên Windows đều báo "còn thừa chữ sau giá trị
    /// JSON" — một bảng lỗi đầy ắp mà không lỗi nào có thật.
    func testCRLFKhongLamMoiDongThanhLoi() {
        let result = JSONLScan.scan(buffer: buffer("{\"a\":1}\r\n{\"a\":2}\r\n"))
        XCTAssertEqual(result.problemCount, 0)
        XCTAssertEqual(result.recordCount, 2)
    }

    /// Bản ghi hợp lệ nhưng KHÔNG phải đối tượng: không tính là lỗi, nhưng được đếm riêng.
    func testBANGHIKhongPhaiDoiTuongDemRieng() {
        let result = JSONLScan.scan(buffer: buffer("""
            {"a":1}
            [1,2,3]
            "chuỗi trần"
            """))
        XCTAssertEqual(result.recordCount, 3)
        XCTAssertEqual(result.objectCount, 1)
        XCTAssertEqual(result.nonObjectCount, 2)
        XCTAssertEqual(result.problemCount, 0)
    }

    /// Danh sách lỗi bị CẮT thì nói ra, và tổng số thật vẫn đúng.
    func testDANHSACHLOICatThiNoiRa() {
        let text = (0 ..< 50).map { _ in "{hỏng}" }.joined(separator: "\n")
        let result = JSONLScan.scan(buffer: buffer(text), problemLimit: 10)
        XCTAssertEqual(result.problems.count, 10)
        XCTAssertEqual(result.problemCount, 50)
        XCTAssertTrue(result.problemsTruncated)
    }

    /// Tệp đủ lớn để tiến độ được hỏi NHIỀU LẦN — 20 MB, vượt xa nhịp hỏi 4 MB.
    private func bigDocument(lines: Int = 200_000) -> TextBuffer {
        let filler = String(repeating: "x", count: 80)
        return buffer((0 ..< lines)
            .map { "{\"a\":\($0),\"t\":\"\(filler)\"}" }.joined(separator: "\n"))
    }

    /// Tiến độ trả `false` thì DỪNG NGAY, và kết quả nói rõ nó chưa xong.
    func testTIENDOTraFalseThiDungNgay() {
        let document = bigDocument()
        var calls = 0
        let result = JSONLScan.scan(buffer: document) { fraction in
            calls += 1
            XCTAssertGreaterThan(fraction, 0)
            return false
        }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(result.wasCancelled)
        XCTAssertGreaterThan(result.lineCount, 0)
        XCTAssertLessThan(result.lineCount, 200_000)
    }

    /// `CancelToken` bật giữa chừng cũng dừng — và nó dừng ở CHECKPOINT KẾ TIẾP.
    ///
    /// Bài này bắt được một lỗi thật ở bản đầu: tiến độ và huỷ được hỏi mỗi lần hết một KHỐI
    /// piece table, mà một tệp mmap là MỘT khối duy nhất — nên trên tệp lớn, đúng loại tệp chế
    /// độ này sinh ra để phục vụ, nút Huỷ không bao giờ ăn.
    func testCANCELTOKENBatGiuaChungThiDung() {
        let document = bigDocument()
        let token = CancelToken()
        let result = JSONLScan.scan(buffer: document, cancelToken: token) { _ in
            token.cancel()
            return true
        }
        XCTAssertTrue(result.wasCancelled)
        XCTAssertLessThan(result.lineCount, 200_000)
    }

    /// Tiến độ được hỏi NHIỀU LẦN trên một tệp lớn, không phải một lần ở cuối.
    func testTIENDODuocHoiNhieuLan() {
        var fractions: [Double] = []
        _ = JSONLScan.scan(buffer: bigDocument()) { fractions.append($0); return true }
        XCTAssertGreaterThanOrEqual(fractions.count, 4, "\(fractions)")
        XCTAssertEqual(fractions, fractions.sorted(), "tiến độ phải TĂNG đều")
        XCTAssertLessThanOrEqual(fractions.last ?? 0, 1.0)
    }

    /// Kết quả KHÔNG đổi khi tài liệu bị chia thành nhiều mảnh piece table.
    ///
    /// Bài này đo đúng chỗ dễ sai của cách quét theo KHỐI thay vì theo dòng: một dòng có thể
    /// nằm vắt qua hai mảnh, và phần nối (`leftover`) là chỗ duy nhất xử lý nó.
    func testCHIANHIEUMANHVanRaCungKetQua() {
        let text = (0 ..< 200).map { "{\"a\":\($0),\"t\":\"nội dung số \($0)\"}" }
            .joined(separator: "\n")
        let plain = buffer(text)
        let expected = JSONLScan.scan(buffer: plain)

        // Chia nhỏ bằng cách sửa rải rác — mỗi lần sửa cắt piece table thêm một nhát.
        let edited = buffer(text)
        for index in stride(from: 0, to: edited.count - 2, by: 37) {
            edited.replace(index ..< index, with: "", label: "chia")
        }
        for index in [10, 200, 900, 1_500] where index < edited.count {
            edited.replace(index ..< index, with: " ", label: "chèn")
        }
        let actual = JSONLScan.scan(buffer: edited)
        XCTAssertGreaterThan(edited.pieceCount, 1, "bài kiểm phải thật sự chia mảnh")
        XCTAssertEqual(actual.lineCount, expected.lineCount)
        XCTAssertEqual(actual.recordCount, expected.recordCount)
        XCTAssertEqual(actual.problemCount, expected.problemCount)
    }

    /// Một dòng DÀI hơn một khối vẫn được kiểm đúng một lần.
    func testDONGDAIHonMotKhoiVanDungMotLan() {
        let long = "{\"a\":\"" + String(repeating: "x", count: 300_000) + "\"}"
        let result = JSONLScan.scan(buffer: buffer(long + "\n{\"b\":1}"))
        XCTAssertEqual(result.lineCount, 2)
        XCTAssertEqual(result.recordCount, 2)
        XCTAssertEqual(result.problemCount, 0)
    }

    // MARK: - Nhận diện

    func testNHANDIENTheoDuoiTep() {
        let text = buffer("{\"a\":1}")
        XCTAssertTrue(JSONLScan.looksLikeJSONL(buffer: text, path: "/a/b.jsonl"))
        XCTAssertTrue(JSONLScan.looksLikeJSONL(buffer: text, path: "/a/b.ndjson"))
        // `.json` là JSON THƯỜNG — một giá trị trải nhiều dòng, không phải mỗi dòng một bản ghi.
        XCTAssertFalse(JSONLScan.looksLikeJSONL(buffer: text, path: "/a/b.json"))
    }

    /// Không có đuôi quen thì NGỬI, và ngửi bằng luật chặt.
    func testNGUINOIDUNGKhiDuoiTepLa() {
        XCTAssertTrue(JSONLScan.looksLikeJSONL(
            buffer: buffer("{\"a\":1}\n{\"a\":2}\n"), path: "/a/b.txt"))
        // JSON thường trải nhiều dòng: dòng đầu `{` một mình KHÔNG hợp lệ.
        XCTAssertFalse(JSONLScan.looksLikeJSONL(
            buffer: buffer("{\n  \"a\": 1\n}\n"), path: "/a/b.txt"))
        // CSV, log, văn bản thường.
        XCTAssertFalse(JSONLScan.looksLikeJSONL(buffer: buffer("a,b,c\n1,2,3\n"), path: nil))
        XCTAssertFalse(JSONLScan.looksLikeJSONL(buffer: buffer(""), path: nil))
        // Mảng mỗi dòng thì KHÔNG nhận: bản ghi JSONL của cụm này là đối tượng.
        XCTAssertFalse(JSONLScan.looksLikeJSONL(buffer: buffer("[1,2]\n[3,4]\n"), path: nil))
    }

    // MARK: - Thẻ xem

    func testTHEXEMInDepDungDongVaTuChoiDongHong() throws {
        let text = buffer("{\"a\":1}\n{hỏng}\n{\"b\":[1,2]}")
        XCTAssertEqual(JSONLScan.prettyRecord(buffer: text, line: 0), "{\n  \"a\": 1\n}")
        XCTAssertNil(JSONLScan.prettyRecord(buffer: text, line: 1))
        XCTAssertEqual(
            JSONLScan.prettyRecord(buffer: text, line: 2),
            "{\n  \"b\": [\n    1,\n    2\n  ]\n}")
        XCTAssertNil(JSONLScan.prettyRecord(buffer: text, line: 99))
    }

    func testTRUONGCuaMotDong() throws {
        let text = buffer("{\"id\":\"c1\",\"n\":2}")
        let fields = try XCTUnwrap(JSONLScan.fields(buffer: text, line: 0))
        XCTAssertEqual(fields.map(\.name), ["id", "n"])
        XCTAssertEqual(fields.map(\.kind), [.string, .number])
    }
}
