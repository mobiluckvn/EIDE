import XCTest
@testable import GEditorCore

/// Cắt chunk — FR-KNW-903. Kèm phép bọc JSON dùng chung (`JSONText`).
final class ChunkerTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func texts(_ chunks: [Chunker.Chunk], _ b: TextBuffer) -> [String] {
        chunks.map { String(decoding: b.bytes(in: $0.range), as: UTF8.self) }
    }

    // MARK: - Cỡ cố định

    func testCoDinhKhongChongLan() {
        let b = buffer("abcdefghij")
        let c = Chunker.chunks(in: b, strategy: .fixed(size: 4, overlap: 0))
        XCTAssertEqual(texts(c, b), ["abcd", "efgh", "ij"])
        XCTAssertEqual(c.map(\.index), [0, 1, 2])
    }

    func testCoDinhCoChongLan() {
        let b = buffer("abcdefgh")
        let c = Chunker.chunks(in: b, strategy: .fixed(size: 4, overlap: 2))
        XCTAssertEqual(texts(c, b), ["abcd", "cdef", "efgh"])
    }

    /// Bài quan trọng nhất của nhóm này. `overlap >= size` làm mỗi bước tiến ≤ 0 và vòng lặp
    /// chạy mãi — trên tài liệu lớn thì triệu chứng là app ĐỨNG IM, không phải một thông báo lỗi.
    /// Đây là tham số người dùng gõ vào ô nhập, nên "chắc không ai gõ thế" không phải bảo đảm.
    func testChongLanLONHONcoThiKHONGtreo() {
        let b = buffer(String(repeating: "x", count: 1000))
        let c = Chunker.chunks(in: b, strategy: .fixed(size: 10, overlap: 999))
        XCTAssertFalse(c.isEmpty)
        XCTAssertLessThan(c.count, 2000, "số chunk phình vô hạn nghĩa là vòng lặp không tiến")
        XCTAssertEqual(c.last?.range.upperBound, 1000, "phải phủ hết tài liệu")
    }

    /// Không bao giờ cắt GIỮA một ký tự: nửa ký tự đi vào JSONL rồi vào chỉ mục truy hồi, nơi
    /// nó không khớp với gì cả và cũng không báo lỗi.
    func testKhongCatGIUAmotKyTuTiengViet() {
        let b = buffer("ăâêôơư")          // mỗi ký tự 2 byte
        let c = Chunker.chunks(in: b, strategy: .fixed(size: 3, overlap: 0))
        for chunk in c {
            let s = String(decoding: b.bytes(in: chunk.range), as: UTF8.self)
            XCTAssertFalse(s.contains("\u{FFFD}"), "chunk chứa ký tự hỏng: \(s)")
        }
        XCTAssertEqual(texts(c, b).joined(), "ăâêôơư", "ghép lại phải ra nguyên văn")
    }

    func testTaiLieuRONGthiKhongCoChunkNao() {
        XCTAssertTrue(Chunker.chunks(in: buffer(""), strategy: .fixed(size: 8, overlap: 0)).isEmpty)
    }

    // MARK: - Theo câu

    func testTheoCauGopChoToiKhiChamTran() {
        let b = buffer("Một. Hai. Ba. Bốn.")
        let c = Chunker.chunks(in: b, strategy: .sentence(maxSize: 10))
        XCTAssertGreaterThan(c.count, 1)
        XCTAssertEqual(texts(c, b).joined(), "Một. Hai. Ba. Bốn.")
    }

    /// KHÔNG cắt sau chữ số: `3.14` và `mục 2.1` là ca hay gặp nhất trong tài liệu kỹ thuật
    /// tiếng Việt, và cắt nhầm ở đó sinh ra hàng loạt chunk một chữ.
    func testKhongCatGiuaMotSoThapPhan() {
        let b = buffer("Giá trị 3.14 là số pi. Câu sau.")
        let c = Chunker.chunks(in: b, strategy: .sentence(maxSize: 1000))
        XCTAssertEqual(c.count, 1, "cả đoạn dưới trần thì là một chunk: \(texts(c, b))")

        let tach = Chunker.bienCau(b, cancelToken: CancelToken())
        XCTAssertEqual(tach.count, 2, "đúng hai câu, không phải bốn: \(tach)")
    }

    /// Một câu DÀI hơn trần thành một chunk riêng, không bị chẻ đôi — chẻ giữa câu là mất đúng
    /// thứ chiến lược này sinh ra để giữ.
    func testCauDaiHONtranVanLaMotChunk() {
        let dai = String(repeating: "từ ", count: 50) + "hết."
        let b = buffer(dai)
        let c = Chunker.chunks(in: b, strategy: .sentence(maxSize: 10))
        XCTAssertEqual(c.count, 1)
    }

    // MARK: - Theo heading

    func testTheoHeadingCatTaiMoiHeading() {
        let b = buffer("""
        # Một
        nội dung một
        # Hai
        nội dung hai
        """)
        let c = Chunker.chunks(in: b, strategy: .heading(level: 1))
        XCTAssertEqual(c.count, 2)
        XCTAssertEqual(c.map(\.heading), ["# Một", "# Hai"])
    }

    func testHeadingSauMucDaChonThiKHONGcat() {
        let b = buffer("# Một\n## Hai\nnội dung\n")
        XCTAssertEqual(Chunker.chunks(in: b, strategy: .heading(level: 1)).count, 1)
        XCTAssertEqual(Chunker.chunks(in: b, strategy: .heading(level: 2)).count, 2)
    }

    /// Phần TRƯỚC heading đầu tiên không bị bỏ — nó thường là phần mở đầu của tài liệu.
    func testPhanTruocHeadingDauTienKhongBiBO() {
        let b = buffer("mở đầu\n# Một\nnội dung\n")
        let c = Chunker.chunks(in: b, strategy: .heading(level: 1))
        XCTAssertEqual(c.count, 2)
        XCTAssertTrue(texts(c, b)[0].contains("mở đầu"))
        XCTAssertNil(c[0].heading)
    }

    /// Không có heading nào là kết quả HỢP LỆ — cả tài liệu thành một chunk. Trả rỗng sẽ làm
    /// người dùng tưởng tính năng hỏng.
    func testKhongCoHeadingThiCaTaiLieuLaMotChunk() {
        let b = buffer("chỉ là văn xuôi\n")
        let c = Chunker.chunks(in: b, strategy: .heading(level: 3))
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c[0].range, 0 ..< b.count)
    }

    /// `#hashtag` KHÔNG phải heading — thiếu dấu cách sau dấu thăng.
    func testHashtagKhongPhaiHeading() {
        let b = buffer("#hashtag chứ không phải heading\n")
        XCTAssertEqual(Chunker.chunks(in: b, strategy: .heading(level: 6)).count, 1)
        XCTAssertNil(Chunker.chunks(in: b, strategy: .heading(level: 6))[0].heading)
    }

    // MARK: - Xuất JSONL

    func testJSONLgiuOffsetDeTruyNguocVeTaiLieuGoc() throws {
        let b = buffer("# A\nmột\n# B\nhai\n")
        let c = Chunker.chunks(in: b, strategy: .heading(level: 1))
        let jsonl = Chunker.jsonl(c, in: b, source: "tai-lieu.md")

        let dong = jsonl.split(separator: "\n")
        XCTAssertEqual(dong.count, 2)
        for (i, line) in dong.enumerated() {
            let doi = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            let object = try XCTUnwrap(doi)
            XCTAssertEqual(object["start"] as? Int, c[i].range.lowerBound)
            XCTAssertEqual(object["end"] as? Int, c[i].range.upperBound)
            XCTAssertEqual(object["source"] as? String, "tai-lieu.md")
        }
    }

    /// Chữ chứa xuống dòng và dấu nháy vẫn ra JSON ĐỌC LẠI ĐƯỢC.
    func testJSONLvoiChuCoXuongDongVaDauNhay() throws {
        let b = buffer("dòng một\n\"trích dẫn\"\n")
        let c = Chunker.chunks(in: b, strategy: .fixed(size: 1000, overlap: 0))
        let jsonl = Chunker.jsonl(c, in: b)
        let doi = try JSONSerialization.jsonObject(
            with: Data(jsonl.trimmingCharacters(in: .newlines).utf8)) as? [String: Any]
        XCTAssertEqual(try XCTUnwrap(doi)["text"] as? String, "dòng một\n\"trích dẫn\"\n")
    }
}

/// Phép bọc chuỗi JSON dùng chung — gộp từ BA bản khác nhau ngày 28/08/2026.
final class JSONTextTests: XCTestCase {

    func testThoatDayDu() {
        XCTAssertEqual(JSONText.quoted("a\"b"), "\"a\\\"b\"")
        XCTAssertEqual(JSONText.quoted("a\\b"), "\"a\\\\b\"")
        XCTAssertEqual(JSONText.quoted("a\nb"), "\"a\\nb\"")
        XCTAssertEqual(JSONText.quoted("a\tb"), "\"a\\tb\"")
        XCTAssertEqual(JSONText.quoted("a\u{01}b"), "\"a\\u0001b\"")
    }

    /// Tiếng Việt đi qua NGUYÊN VĂN, không bị thoát thành `\\uXXXX` — thoát chúng làm tệp phình
    /// gấp sáu lần với đúng thứ ngôn ngữ mà mọi corpus của sản phẩm này chứa.
    func testTiengVietDiQuaNguyenVan() {
        XCTAssertEqual(JSONText.quoted("Hà Nội"), "\"Hà Nội\"")
    }

    /// Đây là bản `MermaidBrand` CŨ, giữ lại nguyên văn để chứng minh nó HỎNG thật — chứ không
    /// phải "khác gu". Một giá trị chứa xuống dòng cho ra JSON không đọc lại được.
    func testBanCuCuaMermaidBrandSINHraJSONhong() {
        func banCu(_ text: String) -> String {
            var out = "\""
            for c in text {
                switch c {
                case "\"": out += "\\\""
                case "\\": out += "\\\\"
                default: out.append(c)
                }
            }
            return out + "\""
        }
        let gia_tri = "màu\nnền"
        XCTAssertNil(
            try? JSONSerialization.jsonObject(with: Data("{\"x\":\(banCu(gia_tri))}".utf8)),
            "bản cũ lẽ ra phải sinh JSON hỏng — nếu bài này xanh thì tiền đề của việc gộp là sai")
        XCTAssertNotNil(
            try? JSONSerialization.jsonObject(
                with: Data("{\"x\":\(JSONText.quoted(gia_tri))}".utf8)),
            "bản dùng chung phải đọc lại được")
    }
}
