import Foundation
@testable import GEditorCore

/// Ghi một gói ZIP tối thiểu để dựng fixture `.docx` / `.xlsx` / `.pptx` cho bài kiểm.
///
/// **Vì sao viết tay chứ không gọi bộ ghi của sản phẩm.** `DOCXWriter` là thứ đang được kiểm ở
/// chỗ khác; dựng fixture bằng chính nó thì hai bên cùng hiểu sai một kiểu và phép so vẫn xanh —
/// bài học đã ghi lại một lần và nó đắt. Ở đây mọi byte đều do bài kiểm tự đặt, nên khi bộ đọc
/// đọc ra đúng thì đó là bằng chứng thật.
///
/// Không nén (method 0). Gói cần nhỏ và cần đọc được, không cần gọn.
enum ZipTestWriter {

    static func write(entries: [(String, [UInt8])], to path: String) throws {
        var payload: [UInt8] = []
        var directory: [UInt8] = []

        for (name, bytes) in entries {
            let nameBytes = Array(name.utf8)
            let crc = CRC32.compute(bytes)
            let offset = UInt32(payload.count)

            // Local file header
            payload += le32(0x0403_4B50)
            payload += le16(20)                 // cần bản 2.0 để đọc
            payload += le16(0)                  // cờ
            payload += le16(0)                  // method 0 = lưu nguyên
            payload += le16(0) + le16(0)        // giờ và ngày sửa
            payload += le32(crc)
            payload += le32(UInt32(bytes.count))
            payload += le32(UInt32(bytes.count))
            payload += le16(UInt16(nameBytes.count))
            payload += le16(0)
            payload += nameBytes
            payload += bytes

            // Central directory entry
            directory += le32(0x0201_4B50)
            directory += le16(20) + le16(20)
            directory += le16(0) + le16(0)
            directory += le16(0) + le16(0)
            directory += le32(crc)
            directory += le32(UInt32(bytes.count))
            directory += le32(UInt32(bytes.count))
            directory += le16(UInt16(nameBytes.count))
            directory += le16(0) + le16(0) + le16(0)
            directory += le16(0) + le32(0)
            directory += le32(offset)
            directory += nameBytes
        }

        let directoryOffset = UInt32(payload.count)
        payload += directory
        payload += le32(0x0605_4B50)
        payload += le16(0) + le16(0)
        payload += le16(UInt16(entries.count)) + le16(UInt16(entries.count))
        payload += le32(UInt32(directory.count))
        payload += le32(directoryOffset)
        payload += le16(0)

        try Data(payload).write(to: URL(fileURLWithPath: path))
    }

    private static func le16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private static func le32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
        ]
    }
}
