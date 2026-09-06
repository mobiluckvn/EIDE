import Foundation

/// Bảng mã VNI (VNI-Windows / VNI ANSI) — FR-ENC-201.
///
/// Khác mọi bảng mã Việt legacy còn lại ở một điểm quyết định: **VNI dùng HAI byte cho chữ có
/// dấu**. Chữ nền đi trước, cụm dấu đi sau — "á" là `61 F9`, "ế" là `65 E1`. Vì vậy nó không
/// phải `SingleByteCodec` và không dùng chung đường tra bảng với TCVN3/VISCII.
///
/// Hệ quả thực tế đáng nhớ khi đọc số liệu: file VNI **dài hơn** file TCVN3 cùng nội dung, và
/// số byte trong file không bằng số ký tự.
///
/// Bảng do `scripts/generate-vni-table.py` sinh từ file UCM đã vendor, sau bốn phép kiểm độc
/// lập. Không dòng nào trong bảng được gõ tay — xem `vendor/NGUON.md`.
public enum VNICodec {

    /// (chữ nền, cụm dấu) → scalar. Khóa gộp hai byte thành một `UInt16` để tra bằng một phép.
    private static let doubleByteMap: [UInt16: UInt32] = {
        var map: [UInt16: UInt32] = [:]
        map.reserveCapacity(VNIEncodingTable.doubleByte.count)
        for entry in VNIEncodingTable.doubleByte {
            map[UInt16(entry.base) << 8 | UInt16(entry.mark)] = entry.scalar
        }
        return map
    }()

    /// scalar → byte. Giá trị thứ hai là `nil` với chữ chỉ cần một byte.
    private static let encodeMap: [UInt32: (UInt8, UInt8?)] = {
        var map: [UInt32: (UInt8, UInt8?)] = [:]
        map.reserveCapacity(VNIEncodingTable.doubleByte.count + 128)
        for (byte, scalar) in VNIEncodingTable.singleByte.enumerated() where scalar != 0xFFFD {
            map[scalar] = (UInt8(byte), nil)
        }
        for entry in VNIEncodingTable.doubleByte {
            map[entry.scalar] = (entry.base, entry.mark)
        }
        return map
    }()

    /// Duyệt dòng byte, trả về từng scalar kèm số byte đã ăn.
    ///
    /// `nil` = byte không có trong bảng. Tách riêng để bộ nhận diện bảng mã dùng lại đúng một
    /// logic tách byte với bộ giải mã — hai bản sao của quy tắc "tham lam" sẽ lệch nhau, và
    /// khi ấy nhận diện nói một đằng còn mở file ra một nẻo.
    static func scan(_ bytes: [UInt8], limit: Int = .max, _ body: (UInt32?, Int) -> Void) {
        var index = 0
        let end = Swift.min(bytes.count, limit)
        while index < end {
            let byte = bytes[index]
            if index + 1 < bytes.count {
                let key = UInt16(byte) << 8 | UInt16(bytes[index + 1])
                if let scalar = doubleByteMap[key] {
                    body(scalar, 2)
                    index += 2
                    continue
                }
            }
            let scalar = VNIEncodingTable.singleByte[Int(byte)]
            body(scalar == 0xFFFD ? nil : scalar, 1)
            index += 1
        }
    }

    /// Chỉ lấy scalar — dùng cho phần chấm chính tả của bộ nhận diện.
    static func decodeScalars(_ bytes: [UInt8], limit: Int = .max) -> [UInt32] {
        var scalars: [UInt32] = []
        scalars.reserveCapacity(bytes.count)
        scan(bytes, limit: limit) { scalar, _ in if let scalar { scalars.append(scalar) } }
        return scalars
    }

    /// byte của file → UTF-8.
    ///
    /// Đọc THAM LAM: gặp một byte có thể là chữ nền thì thử ghép với byte kế; ghép được thì ăn
    /// cả hai. Đây là cách duy nhất đúng, vì chính byte chữ nền đứng một mình cũng là một chữ
    /// hợp lệ ("a" là `61`, "á" là `61 F9`) — không nhìn byte sau thì không phân biệt được.
    public static func decode(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count + bytes.count / 2)

        scan(bytes) { scalar, _ in
            // Byte không nằm trong bảng: dùng ký tự thay thế thay vì bỏ đi, để độ dài và vị trí
            // không lệch — người dùng thấy "" ở đúng chỗ hỏng chứ không thấy chữ dính vào nhau.
            guard let scalar, let unicode = Unicode.Scalar(scalar) else {
                out.append(contentsOf: [0xEF, 0xBF, 0xBD])
                return
            }
            out.append(contentsOf: Array(String(unicode).utf8))
        }
        return out
    }

    /// UTF-8 → byte của file.
    ///
    /// Dựng sẵn (NFC) trước khi tra bảng: nội dung có thể ở dạng tổ hợp (chữ nền + dấu rời),
    /// mà bảng VNI đánh chỉ số theo ký tự dựng sẵn. Bỏ bước này thì mọi chữ có dấu ở dạng tổ
    /// hợp đều bị coi là không biểu diễn được — và văn bản gõ bằng một số bộ gõ thì hay ở dạng
    /// tổ hợp.
    public static func encode(_ utf8: [UInt8]) -> SingleByteCodec.EncodeResult {
        let text = String(decoding: utf8, as: UTF8.self).precomposedStringWithCanonicalMapping
        var out: [UInt8] = []
        out.reserveCapacity(text.utf8.count)
        var unrepresentable = 0
        var firstUnrepresentable: UInt32?

        for scalar in text.unicodeScalars {
            if let (base, mark) = encodeMap[scalar.value] {
                out.append(base)
                if let mark { out.append(mark) }
            } else {
                unrepresentable += 1
                if firstUnrepresentable == nil { firstUnrepresentable = scalar.value }
                out.append(UInt8(ascii: "?"))
            }
        }

        return SingleByteCodec.EncodeResult(
            bytes: out, unrepresentable: unrepresentable, firstUnrepresentable: firstUnrepresentable
        )
    }
}
