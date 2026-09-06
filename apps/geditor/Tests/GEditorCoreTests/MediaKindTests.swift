import XCTest
@testable import GEditorCore

final class MediaKindTests: XCTestCase {

    // MARK: - Nội dung thắng đuôi tệp

    func testNOIDUNGthangDUOITEPkhiHaiThuNoiKhacNhau() {
        // Một tệp tên `.txt` nhưng ruột là PNG thì nó là ảnh. Mở nó ra thành văn bản là hiện
        // một màn hình ký tự rác, và người dùng không có cách nào biết vì sao.
        let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        XCTAssertEqual(MediaKind.of(head: png, path: "/x/ghi-chu.txt"), .image)

        // Chiều ngược lại cũng phải đúng, và nó là chiều QUAN TRỌNG HƠN: tên `.xlsx` mà ruột
        // là CSV — chuyện xảy ra suốt khi người ta xuất dữ liệu — phải mở ra được như văn bản.
        // Đoán theo đuôi ở đây sẽ CHẶN người dùng khỏi một tệp họ hoàn toàn đọc được.
        let csv = Array("tinh,doanh_thu\nHà Nội,1500000\n".utf8)
        XCTAssertNil(MediaKind.of(head: csv, path: "/x/bang.xlsx"))
        XCTAssertNil(MediaKind.of(head: csv, path: "/x/bang.png"))
        XCTAssertNil(MediaKind.of(head: Array("# Ghi chú\n".utf8), path: "/x/a.zip"))
    }

    func testNHIPHANkhongCoCHUKYthiVANhoiDUOITEP() {
        // Đối chứng cho bài trên: nhánh "tin nội dung" chỉ được áp cho VĂN BẢN. Một tệp nhị
        // phân lạ vẫn phải rơi xuống đuôi tệp, nếu không thì mọi định dạng ảnh hiếm đều mở ra
        // thành ký tự rác.
        let binary: [UInt8] = [0x00, 0x01, 0x02, 0x03] + [UInt8](repeating: 0x7F, count: 60)
        XCTAssertEqual(MediaKind.of(head: binary, path: "/x/anh.ico"), .image)
    }

    func testDUOITEPchiLaCUUCANHCUOI() {
        // Tệp rỗng: nội dung không nói gì, lúc ấy mới hỏi tới đuôi.
        XCTAssertEqual(MediaKind.of(head: [], path: "/x/anh.heic"), .image)
        XCTAssertEqual(MediaKind.of(head: [], path: "/x/a.7z"), .archive)
        XCTAssertNil(MediaKind.of(head: [], path: "/x/ghi-chu.md"))
    }

    func testNHANRAtungHoAnh() {
        func head(_ b: [UInt8]) -> [UInt8] { b + [UInt8](repeating: 0, count: 32) }
        XCTAssertEqual(MediaKind.of(head: head([0xFF, 0xD8, 0xFF]), path: "/x"), .image)
        XCTAssertEqual(MediaKind.of(head: head(Array("GIF89a".utf8)), path: "/x"), .image)
        XCTAssertEqual(MediaKind.of(head: head([0x42, 0x4D]), path: "/x"), .image)
        XCTAssertEqual(MediaKind.of(head: head([0x49, 0x49, 0x2A, 0x00]), path: "/x"), .image)

        // WEBP và HEIC là container — chữ ký nằm ở offset 8, không phải offset 0.
        let webp = Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WEBP".utf8)
        XCTAssertEqual(MediaKind.of(head: head(webp), path: "/x"), .image)
        let heic = [UInt8](repeating: 0, count: 4) + Array("ftypheic".utf8)
        XCTAssertEqual(MediaKind.of(head: head(heic), path: "/x"), .image)

        // Và một container KHÁC không phải ảnh thì không được nhận nhầm THÀNH ẢNH.
        //
        // Dòng này trước đây đòi `nil`, và con số ấy đúng khi `MediaKind` chưa có loại video:
        // lúc ấy "không phải ảnh" là tất cả những gì nói được về một hộp `ftypisom`. Từ
        // 02/09/2026 có `.video`, nên câu trả lời đúng chặt hơn — nhưng vế mà bài kiểm này
        // thật sự canh vẫn nguyên: nó KHÔNG được là `.image`.
        let mp4 = [UInt8](repeating: 0, count: 4) + Array("ftypisom".utf8)
        XCTAssertEqual(MediaKind.of(head: head(mp4), path: "/x"), .video)
        XCTAssertNotEqual(MediaKind.of(head: head(mp4), path: "/x"), .image)
    }

    func testSVGvanLAVANBANchuKhongPhaiANH() {
        // SVG là XML. Sửa được bằng ⌘F, multi-caret, tô màu cú pháp — biến nó thành "ảnh chỉ
        // xem" là đổi một thứ đang dùng tốt lấy một thứ kém hơn.
        let svg = Array("<svg xmlns=\"http://www.w3.org/2000/svg\"><rect/></svg>".utf8)
        XCTAssertNil(MediaKind.of(head: svg, path: "/x/so-do.svg"))
    }

    func testPDFnhanRaBangCHUKY() {
        XCTAssertEqual(MediaKind.of(head: Array("%PDF-1.7\n".utf8), path: "/x/a"), .pdf)
        // Chuỗi "%PDF" ở GIỮA tệp thì không tính — nó phải ở đầu.
        XCTAssertNil(MediaKind.of(head: Array("xin chào %PDF-1.7".utf8), path: "/x/a"))
    }

    func testCSVbatDAUbangSOgiongCHUKYcpioVANlaVANBAN() {
        // Chữ ký cpio là chuỗi ký tự in được `"070701"`. Một tệp CSV mở đầu bằng mã bưu chính
        // hay số căn cước dạng ấy khớp y hệt — và nếu phép nhận diện hỏi chữ ký trước khi hỏi
        // "nội dung có phải văn bản không", tệp ấy sẽ mở ra một khung file nén báo lỗi, trong
        // khi người dùng hoàn toàn đọc được nó.
        for magic in ["070707", "070701", "070702"] {
            let csv = Array("\(magic),Hà Nội,1500000\n\(magic),Huế,920000\n".utf8)
            XCTAssertNil(MediaKind.of(head: csv, path: "/x/danh-sach.csv"),
                         "CSV mở đầu bằng «\(magic)» bị nhận nhầm thành kho nén")
        }
        // Các chữ ký in được khác cũng vậy.
        XCTAssertNil(MediaKind.of(head: Array("MSCF là viết tắt của gì?\n".utf8), path: "/x/a.txt"))
        XCTAssertNil(MediaKind.of(head: Array("xar! đọc là gì nhỉ\n".utf8), path: "/x/a.txt"))
    }

    func testCHUKYINDUOCvanNHANRAkhiNOIDUNGlaNHIPHAN() {
        // Đối chứng cho bài trên: chặn theo "trông như văn bản" không được làm mất khả năng
        // nhận diện kho thật. Kho cpio thật có byte NUL đệm ngay trong header đầu.
        func kho(_ magic: String) -> [UInt8] {
            Array(magic.utf8) + Array("000000000000".utf8)
                + [UInt8](repeating: 0, count: 200)
        }
        for magic in ["070707", "070701", "070702"] {
            XCTAssertEqual(MediaKind.of(head: kho(magic), path: "/x/khong-duoi"), .archive,
                           "kho cpio thật không nhận ra được nữa (\(magic))")
        }
        let cab = Array("MSCF".utf8) + [UInt8](repeating: 0, count: 60)
        XCTAssertEqual(MediaKind.of(head: cab, path: "/x/a"), .archive)
        let xar = Array("xar!".utf8) + [0x00, 0x1C] + [UInt8](repeating: 0, count: 60)
        XCTAssertEqual(MediaKind.of(head: xar, path: "/x/a"), .archive)
        let ar = Array("!<arch>\n".utf8) + [UInt8](repeating: 0, count: 60)
        XCTAssertEqual(MediaKind.of(head: ar, path: "/x/a"), .archive)
        let lha = [0x20, 0x00] + Array("-lh5-".utf8) + [UInt8](repeating: 0, count: 60)
        XCTAssertEqual(MediaKind.of(head: lha, path: "/x/a"), .archive)
    }

    func testTARnhanRaOoffset257() {
        var tar = [UInt8](repeating: 0, count: 300)
        for (i, b) in Array("ustar".utf8).enumerated() { tar[257 + i] = b }
        XCTAssertEqual(MediaKind.of(head: tar, path: "/x/a"), .archive)
    }

    // MARK: - Phân biệt OOXML với file nén thường, trên tệp THẬT

    func testFILEOFFICEthatTrongKhoNhanRaDungLOAI() throws {
        let cases: [(String, MediaKind)] = [
            ("docs/GioiThieu_TinhNang_GEditor_v2.0.docx", .word),
            ("docs/TongHop_TinhNang_GEditor_v2.0.xlsx", .excel),
        ]
        for (relative, expected) in cases {
            let path = kho(relative)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: path), "thiếu \(relative)")
            XCTAssertEqual(MediaKind.of(path: path), expected,
                           "\(relative) nhận nhầm loại")
        }
    }

    func testZIPTHUONGkhongBiNhanNhamThanhOFFICE() throws {
        let zipTool = "/usr/bin/zip"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: zipTool), "không có zip(1)")

        let root = NSTemporaryDirectory() + "/geditor-mk-\(UUID().uuidString)"
        let work = root + "/noi-dung"
        try FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }
        try Data("xin chào\n".utf8).write(to: URL(fileURLWithPath: work + "/a.txt"))

        let out = root + "/thu.zip"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zipTool)
        process.arguments = ["-q", "-r", out, "."]
        process.currentDirectoryURL = URL(fileURLWithPath: work)
        try process.run()
        process.waitUntilExit()

        // Đuôi `.zip` VÀ ruột là zip — nhưng không có bộ xương Office, nên nó là file nén.
        XCTAssertEqual(MediaKind.of(path: out), .archive)

        // Và phép phân biệt phải dựa vào bộ xương THẬT chứ không dựa vào đuôi: đổi tên thành
        // .docx thì nó vẫn phải là file nén, vì bên trong không có `word/document.xml`.
        let giaDanh = root + "/gia-danh.docx"
        try FileManager.default.moveItem(atPath: out, toPath: giaDanh)
        XCTAssertEqual(MediaKind.of(path: giaDanh), .archive,
                       "đổi đuôi thành .docx là đủ để nhận nhầm — phép phân biệt đang dựa vào đuôi")
    }

    private func kho(_ relative: String) -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent(relative).path
    }
}

extension MediaKindTests {

    func testTARCOkhongCOchuKyUSTARvanNHANRA() throws {
        // TAR v7 không có chữ ký `ustar`. Chỉ dò chữ ký thì một kho như vậy mở ra thành văn bản
        // rác — và `tar` của các hệ Unix cũ vẫn ghi kiểu ấy.
        var block = [UInt8](repeating: 0, count: 512)
        for (index, byte) in Array("a.txt".utf8).enumerated() { block[index] = byte }
        for (index, byte) in Array("00000000010".utf8).enumerated() { block[124 + index] = byte }
        var sum = 0
        for (index, byte) in block.enumerated() {
            sum += (148 ..< 156).contains(index) ? 32 : Int(byte)
        }
        for (index, byte) in Array(String(format: "%06o", sum).utf8).enumerated() {
            block[148 + index] = byte
        }
        block[155] = UInt8(ascii: " ")
        XCTAssertEqual(MediaKind.of(head: block, path: "/x/kho"), .archive)
    }
}
