import XCTest
@testable import GEditorCore

/// Nhận diện nhạc và phim theo CHỮ KÝ.
///
/// Bài quan trọng nhất ở đây là nhóm `ftyp`: ảnh HEIC, nhạc M4A và phim MP4 dùng **chung** một
/// hộp mở đầu, khác nhau đúng bốn ký tự nhãn hiệu. Nhầm một nhãn là mở nhạc ra khung xem ảnh.
final class MediaKindAudioVideoTests: XCTestCase {

    private func head(_ bytes: [UInt8], pad: Int = 64) -> [UInt8] {
        bytes + [UInt8](repeating: 0, count: max(0, pad - bytes.count))
    }

    private func ftyp(_ brand: String) -> [UInt8] {
        head([0, 0, 0, 0x20] + Array("ftyp".utf8) + Array(brand.utf8))
    }

    // MARK: - Hộp ftyp dùng chung

    func testFTYPnhanANHvanRAanh() {
        XCTAssertEqual(MediaKind.of(head: ftyp("heic"), path: "a.heic"), .image)
        XCTAssertEqual(MediaKind.of(head: ftyp("avif"), path: "a.avif"), .image)
    }

    func testFTYPnhanNHACraNHAC_nhanPHIMraPHIM() {
        XCTAssertEqual(MediaKind.of(head: ftyp("M4A "), path: "a.m4a"), .audio)
        XCTAssertEqual(MediaKind.of(head: ftyp("mp42"), path: "a.mp4"), .video)
        XCTAssertEqual(MediaKind.of(head: ftyp("qt  "), path: "a.mov"), .video)
    }

    func testFTYPnhanLAthiKHONGdoanBUA() {
        // Hộp ISO-BMFF còn có thể là phụ đề, ảnh động, hay một thứ chưa sinh ra. Đoán bừa là
        // mở nhầm khung; trả nil là để các bước sau (nội dung, đuôi tệp) trả lời.
        let unknown = MediaKind.of(head: ftyp("zzzz"), path: "a.bin")
        XCTAssertNil(unknown, "nhãn lạ mà vẫn đoán ra \(String(describing: unknown))")
    }

    // MARK: - RIFF dùng chung cho ba thứ

    func testRIFFtachDUOCwebpVAwavVAavi() {
        let webp = head(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WEBP".utf8))
        let wav = head(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8))
        let avi = head(Array("RIFF".utf8) + [0, 0, 0, 0] + Array("AVI ".utf8))
        XCTAssertEqual(MediaKind.of(head: webp, path: "a.webp"), .image)
        XCTAssertEqual(MediaKind.of(head: wav, path: "a.wav"), .audio)
        XCTAssertEqual(MediaKind.of(head: avi, path: "a.avi"), .video)
    }

    // MARK: - Chữ ký riêng

    func testCHUkyNHACthuongGAP() {
        XCTAssertEqual(MediaKind.of(head: head(Array("ID3".utf8)), path: "a.mp3"), .audio)
        XCTAssertEqual(MediaKind.of(head: head(Array("fLaC".utf8)), path: "a.flac"), .audio)
        XCTAssertEqual(MediaKind.of(head: head(Array("OggS".utf8)), path: "a.ogg"), .audio)
        let aiff = head(Array("FORM".utf8) + [0, 0, 0, 0] + Array("AIFF".utf8))
        XCTAssertEqual(MediaKind.of(head: aiff, path: "a.aiff"), .audio)
    }

    func testCHUkyPHIMthuongGAP() {
        XCTAssertEqual(MediaKind.of(head: head([0x1A, 0x45, 0xDF, 0xA3]), path: "a.mkv"), .video)
        XCTAssertEqual(MediaKind.of(head: head([0x1A, 0x45, 0xDF, 0xA3]), path: "a.webm"), .video)
        XCTAssertEqual(MediaKind.of(head: head(Array("FLV".utf8)), path: "a.flv"), .video)
        // QuickTime đời cũ: không có `ftyp`, hộp đầu là `moov`/`mdat`.
        XCTAssertEqual(
            MediaKind.of(head: head([0, 0, 0, 0x14] + Array("moov".utf8)), path: "a.mov"), .video
        )
    }

    func testASFmotCHUkyHAIloai_phanBIETbangDUOI() {
        // Ngoại lệ có chủ ý và được ghi trong mã: header ASF không nói nhạc hay phim.
        let asf = head([0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11])
        XCTAssertEqual(MediaKind.of(head: asf, path: "a.wma"), .audio)
        XCTAssertEqual(MediaKind.of(head: asf, path: "a.wmv"), .video)
    }

    // MARK: - Không được cướp tệp của loại khác

    func testJPEGvanLAanh_duMOdauBANG0xFF() {
        // Phép dò khung MPEG audio bắt mẫu 0xFF + 3 bit 1. JPEG mở đầu 0xFF D8 FF, khớp mẫu ấy.
        // Nó phải được `imageKind` lấy TRƯỚC — nếu không, mọi ảnh JPEG thành tệp nhạc.
        XCTAssertEqual(MediaKind.of(head: head([0xFF, 0xD8, 0xFF, 0xE0]), path: "a.jpg"), .image)
    }

    func testVANbanTHUANkhongBIhieuNHAMlaNHAC() {
        let csv = Array("ma_don,ngay,tong\n1,2026-09-01,1000\n".utf8)
        XCTAssertNil(MediaKind.of(head: csv, path: "a.csv"))
    }

    func testPDFvaZIPkhongBIcuop() {
        XCTAssertEqual(MediaKind.of(head: head(Array("%PDF-1.7".utf8)), path: "a.pdf"), .pdf)
    }

    // MARK: - Đuôi tệp là cứu cánh cuối

    func testTEProngTHIhoiDUOItep() {
        XCTAssertEqual(MediaKind.of(head: [], path: "a.mp3"), .audio)
        XCTAssertEqual(MediaKind.of(head: [], path: "a.mkv"), .video)
        XCTAssertEqual(MediaKind.of(head: [], path: "a.txt"), nil)
    }

    // MARK: - isPlayable

    func testPHATduocCHIlaNHACvaPHIM() {
        XCTAssertTrue(MediaKind.audio.isPlayable)
        XCTAssertTrue(MediaKind.video.isPlayable)
        for kind in [MediaKind.image, .pdf, .word, .excel, .powerpoint, .archive] {
            XCTAssertFalse(kind.isPlayable, "\(kind) không phải thứ để phát")
        }
    }
}
