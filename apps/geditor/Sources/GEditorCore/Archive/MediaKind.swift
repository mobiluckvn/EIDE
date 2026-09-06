import Foundation

/// Loại tệp KHÔNG phải văn bản mà GEditor mở được bằng một khung xem riêng.
///
/// **Vì sao nhận diện bằng NỘI DUNG chứ không bằng đuôi tệp.** Đuôi tệp nói lên ý định của
/// người đặt tên, không nói lên sự thật: một `.docx` tải dở là ZIP đứt đoạn, một `.txt` do máy
/// ảnh sinh ra có thể là JPEG, và một tệp không đuôi vẫn phải mở đúng. Đuôi tệp chỉ được dùng
/// làm **cứu cánh cuối** khi mấy byte đầu không nói lên điều gì.
///
/// **Vì sao SVG KHÔNG nằm ở đây.** SVG là XML — tức là văn bản, và GEditor sửa được nó bằng
/// đúng những công cụ đang có (tô màu cú pháp, ⌘F, multi-caret). Đưa nó thành "ảnh chỉ xem" là
/// lấy đi một thứ đang dùng tốt để đổi lấy một thứ kém hơn.
public enum MediaKind: String, Equatable, Sendable, CaseIterable {
    case image
    case pdf
    case word
    case excel
    case powerpoint
    case archive
    case audio
    case video

    /// Tên hiện cho người dùng.
    public var displayName: String {
        switch self {
        case .image: return "Ảnh"
        case .pdf: return "PDF"
        case .word: return "Tài liệu Word"
        case .excel: return "Bảng tính Excel"
        case .powerpoint: return "Bản trình chiếu PowerPoint"
        case .archive: return "File nén"
        case .audio: return "Âm thanh"
        case .video: return "Video"
        }
    }

    /// Loại này phát được bằng bộ phát của hệ điều hành.
    ///
    /// Nhận diện ĐƯỢC không có nghĩa là phát ĐƯỢC: `.mkv`, `.webm`, `.wma` đều nhận ra chắc
    /// chắn từ chữ ký, và AVFoundation không giải mã nổi cái nào. Phân biệt hai câu hỏi ấy ngay
    /// ở kiểu, vì trộn chúng lại là cách sinh ra một khung phát trống trơn không nói gì.
    public var isPlayable: Bool { self == .audio || self == .video }

    /// Loại này có phải tài liệu OOXML (ruột là ZIP) không.
    public var isOfficeOpenXML: Bool {
        self == .word || self == .excel || self == .powerpoint
    }

    /// Số byte đầu tệp cần đọc để nhận diện.
    ///
    /// 512 vì chữ ký `ustar` của TAR nằm ở offset 257 — mọi chữ ký khác đều nằm trong 16 byte
    /// đầu. Đọc đúng ngần này chứ không đọc cả tệp: nhận diện phải rẻ, nó chạy trên MỌI lần mở.
    public static let sniffLength = 512

    // MARK: - Nhận diện

    /// Đoán loại của một tệp trên đĩa. `nil` = cứ mở như văn bản.
    public static func of(path: String) -> MediaKind? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let head = [UInt8]((try? handle.read(upToCount: sniffLength)) ?? Data())
        return of(head: head, path: path)
    }

    /// Nhánh thuần tính toán — tách ra để bài kiểm chạy được mà không cần tệp thật.
    public static func of(head: [UInt8], path: String) -> MediaKind? {
        if head.starts(with: Array("%PDF-".utf8)) { return .pdf }
        if let image = imageKind(head) { return image }
        // Hỏi NGAY SAU ảnh, và đó là bắt buộc chứ không phải tuỳ ý: HEIC và MP4 dùng CHUNG hộp
        // `ftyp`, chỉ khác nhau ở nhãn hiệu bên trong. `imageKind` đã nhận hết nhãn ảnh, nên
        // mọi nhãn `ftyp` còn lại đến được đây là phim hoặc nhạc.
        if let played = audioVideoKind(head, path: path) { return played }

        // ZIP: có thể là file nén thường, có thể là OOXML. Phân biệt được bằng cách mở ra xem
        // bên trong có bộ xương của Office không — nên câu trả lời ở đây là "chưa biết", và
        // `refine(zipAt:)` sẽ nói tiếp. Tách hai bước vì bước sau phải đọc mục lục của file nén,
        // đắt hơn hẳn việc soi 512 byte.
        if ZipArchive.looksLikeZip(head) { return refine(zipAt: path) }

        if isOtherArchive(head) { return .archive }
        // TAR không nén: chữ ký `ustar` nằm ở offset 257 nên `isOtherArchive` bắt được, nhưng
        // TAR cổ (v7) không có chữ ký nào. Nhận nó bằng CHECKSUM của khối header đầu.
        if head.count >= 512, TarArchive.isTarHeader(Array(head[0 ..< 512])) { return .archive }

        // Nội dung TRÔNG NHƯ VĂN BẢN thì tin nội dung, đừng hỏi đuôi nữa.
        //
        // Không có nhánh này thì một tệp CSV lỡ đặt tên `.xlsx` — chuyện xảy ra suốt khi người
        // ta xuất dữ liệu — sẽ mở ra một khung xem Excel báo "không đọc được", trong khi nội
        // dung của nó hoàn toàn đọc được bằng chính GEditor. Cách hỏng ấy tệ hơn hẳn việc mở
        // nhầm một ảnh thành văn bản, vì nó CHẶN người dùng khỏi thứ họ có thể dùng.
        if !head.isEmpty, looksLikeText(head) { return nil }

        // Chỉ tới ĐÂY mới hỏi các chữ ký viết bằng ký tự in được — xem `isPrintableMagicArchive`.
        if isPrintableMagicArchive(head) { return .archive }

        // Cứu cánh cuối: đuôi tệp. Chỉ tới đây khi nội dung không nói gì — tệp rỗng, hoặc một
        // định dạng nhị phân mà bảng chữ ký ở trên chưa có.
        return byExtension(path)
    }

    /// Mấy trăm byte đầu có trông như văn bản không.
    ///
    /// Cùng phép đo với `FindInFiles`: byte NUL gần như không bao giờ xuất hiện trong văn bản
    /// và gần như luôn xuất hiện rất sớm trong tệp nhị phân. Thêm một vế nữa cho chắc — tỉ lệ
    /// byte điều khiển — vì vài định dạng nhị phân (ảnh raw, font) mở đầu bằng vùng không có
    /// NUL.
    private static func looksLikeText(_ head: [UInt8]) -> Bool {
        if head.contains(0) { return false }
        let control = head.filter { $0 < 0x20 && $0 != 0x09 && $0 != 0x0A && $0 != 0x0D }.count
        return Double(control) / Double(head.count) < 0.05
    }

    /// Mở file ZIP ra để biết nó là Office hay chỉ là file nén.
    ///
    /// Ba tệp dưới đây là **bộ xương bắt buộc** của từng loại OOXML — không có chúng thì Word,
    /// Excel, PowerPoint đều từ chối mở. Dùng chúng thay vì `[Content_Types].xml` (mọi OOXML
    /// đều có, không phân biệt được ai với ai) và thay vì đuôi tệp.
    private static func refine(zipAt path: String) -> MediaKind {
        guard let archive = try? ZipArchive(path: path) else { return .archive }
        let names = Set(archive.entries.map(\.path))
        if names.contains("word/document.xml") { return .word }
        if names.contains("xl/workbook.xml") { return .excel }
        if names.contains("ppt/presentation.xml") { return .powerpoint }
        return .archive
    }

    private static func imageKind(_ head: [UInt8]) -> MediaKind? {
        func has(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            guard head.count >= offset + signature.count else { return false }
            return Array(head[offset ..< offset + signature.count]) == signature
        }

        if has([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return .image }   // PNG
        if has([0xFF, 0xD8, 0xFF]) { return .image }                                  // JPEG
        if has(Array("GIF87a".utf8)) || has(Array("GIF89a".utf8)) { return .image }    // GIF
        if has([0x42, 0x4D]) { return .image }                                        // BMP
        if has([0x49, 0x49, 0x2A, 0x00]) || has([0x4D, 0x4D, 0x00, 0x2A]) {            // TIFF
            return .image
        }
        if has([0x69, 0x63, 0x6E, 0x73]) { return .image }                            // ICNS
        // WEBP và HEIC đều là container: "RIFF····WEBP" và "····ftypheic".
        if has(Array("RIFF".utf8)), has(Array("WEBP".utf8), at: 8) { return .image }
        if has(Array("ftyp".utf8), at: 4) {
            let brand = head.count >= 12 ? String(decoding: head[8 ..< 12], as: UTF8.self) : ""
            if ["heic", "heix", "hevc", "mif1", "avif"].contains(brand) { return .image }
        }
        return nil
    }

    /// Nhạc và phim, nhận theo chữ ký.
    ///
    /// ## Ba chỗ chữ ký KHÔNG tự nó trả lời được, và cách xử
    ///
    /// 1. **Hộp `ftyp`** dùng chung cho cả ảnh HEIC, nhạc M4A và phim MP4 — phân biệt bằng nhãn
    ///    hiệu ở byte 8…11. Nhãn lạ thì trả `nil` chứ không đoán: một hộp ISO-BMFF còn có thể là
    ///    phụ đề, là ảnh động, là thứ chưa sinh ra khi đoạn mã này được viết.
    /// 2. **`RIFF`** mở đầu cả WEBP, WAV lẫn AVI. WEBP đã bị `imageKind` lấy trước; ở đây chỉ
    ///    còn phải phân biệt hai cái sau bằng nhãn ở byte 8.
    /// 3. **ASF** (`.wma` và `.wmv`) có **một chữ ký cho hai loại** — trong container ấy, nhạc
    ///    hay phim là chuyện của luồng bên trong chứ không phải của header. Đọc luồng chỉ để đặt
    ///    một cái nhãn là quá đắt cho một định dạng mà macOS không phát nổi, nên chỗ này hỏi
    ///    ĐUÔI TỆP. Đây là ngoại lệ duy nhất, và nó được nói ra chứ không giấu.
    private static func audioVideoKind(_ head: [UInt8], path: String) -> MediaKind? {
        func has(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            guard head.count >= offset + signature.count else { return false }
            return Array(head[offset ..< offset + signature.count]) == signature
        }
        func has(_ text: String, at offset: Int = 0) -> Bool { has(Array(text.utf8), at: offset) }

        // --- Hộp ISO-BMFF ------------------------------------------------------------------
        if has("ftyp", at: 4), head.count >= 12 {
            switch String(decoding: head[8 ..< 12], as: UTF8.self) {
            case "M4A ", "M4B ", "M4P ", "M4R ": return .audio
            case "isom", "iso2", "iso4", "iso5", "iso6", "mp41", "mp42", "avc1", "dash",
                 "M4V ", "M4VH", "M4VP", "qt  ", "3gp4", "3gp5", "3g2a":
                return .video
            default: return nil
            }
        }
        // QuickTime đời cũ không có `ftyp`: hộp đầu tiên là một trong những hộp dưới đây.
        for atom in ["moov", "mdat", "wide", "free", "skip", "pnot"] where has(atom, at: 4) {
            return .video
        }

        // --- RIFF --------------------------------------------------------------------------
        if has("RIFF") {
            if has("WAVE", at: 8) { return .audio }
            if has("AVI ", at: 8) { return .video }
            return nil
        }

        // --- Nhạc ---------------------------------------------------------------------------
        if has("ID3") { return .audio }                                   // MP3 có thẻ ID3
        if has("fLaC") { return .audio }
        if has("OggS") { return .audio }                                  // Vorbis · Opus · FLAC
        if has("FORM"), has("AIFF", at: 8) || has("AIFC", at: 8) { return .audio }
        if has("caff") { return .audio }                                  // Core Audio Format
        if has("MAC ") { return .audio }                                  // Monkey's Audio
        if has("wvpk") { return .audio }                                  // WavPack
        // Khung MPEG audio trần (MP3 không thẻ, hoặc AAC-ADTS). Byte đầu 0xFF, và ba bit đầu của
        // byte sau phải là 111 — mẫu đồng bộ. Hỏi SAU mọi thứ khác vì nó rộng nhất; JPEG cũng mở
        // đầu bằng 0xFF nhưng `imageKind` đã lấy trước.
        if head.count >= 2, head[0] == 0xFF, head[1] & 0xE0 == 0xE0 { return .audio }

        // --- Phim ---------------------------------------------------------------------------
        if has([0x1A, 0x45, 0xDF, 0xA3]) { return .video }                // Matroska: mkv · webm
        if has("FLV") { return .video }
        if has([0x00, 0x00, 0x01, 0xBA]) || has([0x00, 0x00, 0x01, 0xB3]) { return .video }

        // --- ASF: một chữ ký, hai loại — xem ghi chú ở đầu hàm ------------------------------
        if has([0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11]) {
            return (path as NSString).pathExtension.lowercased() == "wma" ? .audio : .video
        }
        return nil
    }

    private static func isOtherArchive(_ head: [UInt8]) -> Bool {
        func has(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            guard head.count >= offset + signature.count else { return false }
            return Array(head[offset ..< offset + signature.count]) == signature
        }
        if has([0x1F, 0x8B]) { return true }                                          // gzip
        if has([0x42, 0x5A, 0x68]) { return true }                                    // bzip2
        if has([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) { return true }                  // xz
        if has([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) { return true }                  // 7z
        if has([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]) { return true }                  // rar
        if has([0x1F, 0x9D]) { return true }                                          // compress .Z
        // cpio biến thể nhị phân — theo thứ tự byte của máy đã tạo ra nó.
        if has([0xC7, 0x71]) || has([0x71, 0xC7]) { return true }
        return false
    }

    /// Chữ ký kho nén viết bằng ký tự IN ĐƯỢC.
    ///
    /// Tách khỏi `isOtherArchive` vì chúng chỉ được hỏi SAU khi đã kết luận nội dung không phải
    /// văn bản. Lý do rất cụ thể: chữ ký cpio là chuỗi `"070701"`, và một tệp CSV bắt đầu bằng
    /// một mã bưu chính hay số căn cước dạng `070701,…` sẽ khớp y hệt. Hỏi chúng trước phép thử
    /// văn bản là biến một tệp đọc được thành một khung "không mở được kho nén".
    ///
    /// Kho nén thật thì không bao giờ đi tới đây bằng nhầm lẫn: header của chúng có byte NUL
    /// hoặc byte điều khiển ngay trong vài trăm byte đầu, nên `looksLikeText` đã loại rồi.
    private static func isPrintableMagicArchive(_ head: [UInt8]) -> Bool {
        func has(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            guard head.count >= offset + signature.count else { return false }
            return Array(head[offset ..< offset + signature.count]) == signature
        }
        if has(Array("ustar".utf8), at: 257) { return true }                          // tar
        if has(Array("LZIP".utf8)) { return true }                                    // lzip .lz
        if has(Array("MSCF".utf8)) { return true }                                    // cab
        if has(Array("xar!".utf8)) { return true }                                    // xar và .pkg
        if has(Array("!<arch>".utf8)) { return true }                                 // ar
        // cpio dạng văn bản: "070707" của bản cũ, "070701"/"070702" của SVR4.
        for magic in ["070707", "070701", "070702"] where has(Array(magic.utf8)) { return true }
        // LHA/LZH: chữ ký ở offset 2, dạng "-lh5-" hay "-lzs-". Hai byte đầu là cỡ header và
        // checksum, không dùng để nhận diện được.
        if has(Array("-lh".utf8), at: 2) || has(Array("-lz".utf8), at: 2) { return true }
        // ISO9660 CỐ Ý không có ở đây: chữ ký "CD001" nằm ở offset 32769, ngoài tầm 512 byte
        // mà phép nhận diện này đọc. Đọc xa hơn chỉ vì một định dạng hiếm là bắt MỌI lần mở
        // tệp trả giá. Đuôi `.iso` ở `byExtension` lo phần ấy.
        return false
    }

    private static func byExtension(_ path: String) -> MediaKind? {
        switch (path as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "webp", "heic", "heif",
             "avif", "icns", "ico":
            return .image
        case "pdf": return .pdf
        case "docx", "docm", "dotx": return .word
        case "xlsx", "xlsm", "xltx": return .excel
        case "pptx", "pptm", "potx": return .powerpoint
        case "mp3", "m4a", "m4b", "aac", "wav", "wave", "aif", "aiff", "aifc", "flac",
             "ogg", "oga", "opus", "caf", "wma", "ape", "wv", "amr", "mid", "midi":
            return .audio
        case "mp4", "m4v", "mov", "qt", "avi", "mkv", "webm", "flv", "wmv", "mpg", "mpeg",
             "mpe", "m2v", "3gp", "3g2", "ts", "mts", "m2ts", "ogv":
            return .video
        case "zip", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "lz", "z", "taz",
             "7z", "rar", "jar", "war",
             // Nhóm dưới đây mở được nhờ libarchive nạp từ nguồn.
             "cab", "lha", "lzh", "iso", "xar", "pkg", "cpio", "ar":
            return .archive
        default: return nil
        }
    }
}
