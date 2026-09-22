import AppKit

/// **Nút bật/tắt theo ô nhập** — nút chỉ sáng khi có thứ để gửi.
///
/// ## Vì sao là một cơ chế, không phải ba lần vá
///
/// Bộ đo `--bam-thu` bấm thật từng nút rồi so màn hình trước/sau. Nó tìm ra ba nút im lặng —
/// `Gửi`, `Hỏi`, `Lưu câu trả lời` — và cả ba im vì CÙNG một lý do: chúng đòi một ô nhập có
/// nội dung, nhưng vẫn trông bấm được khi ô ấy trống, và `guard !rỗng else { return }` bên
/// trong làm chúng lặng thinh.
///
/// Chủ sản phẩm ngồi trước máy và nói: *"gần như các nút không dùng được một nút nào cả"*. Ba
/// nút ấy đúng là ba nút to nhất, thứ người ta thử đầu tiên.
///
/// Vá từng cái sẽ để cái thứ tư ra đời tuần sau. Ràng buộc ở đây làm đúng-theo-cấu-tạo: ai nối
/// một nút với một ô đều nhận luôn phần bật/tắt, và `--bam-thu` bỏ qua nút đang tắt nên nó
/// không còn bị tố oan.
///
/// ## Một nút TẮT nói được nhiều hơn một nút im
///
/// Nút tắt nói "chưa tới lượt bạn bấm". Nút sáng mà bấm không ra gì dạy người dùng đúng một
/// điều: nút của ứng dụng này không đáng tin — và họ mang bài học ấy sang mọi nút còn lại,
/// kể cả những nút chạy tốt.
@MainActor
public final class EideNutTheoO: NSObject, NSTextFieldDelegate {

    private let o: NSTextField
    private let nut: [NSButton]
    private let hopLe: (String) -> Bool

    /// Giữ bộ nối sống bằng chính ô nhập: `delegate` là tham chiếu yếu, nên một bộ nối không ai
    /// giữ sẽ bị thu hồi ngay và nút đứng tắt vĩnh viễn — một cách hỏng tệ hơn cả lỗi gốc.
    private static var giu: [ObjectIdentifier: EideNutTheoO] = [:]

    /// Nối `nut` vào `o`: nút chỉ bật khi `hopLe(nội dung ô)` đúng.
    ///
    /// - Parameter hopLe: mặc định là "không rỗng sau khi bỏ khoảng trắng".
    @discardableResult
    public static func noi(_ o: NSTextField, _ nut: NSButton...,
                           hopLe: @escaping (String) -> Bool = {
                               !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                           }) -> EideNutTheoO {
        let b = EideNutTheoO(o: o, nut: nut, hopLe: hopLe)
        o.delegate = b
        giu[ObjectIdentifier(o)] = b
        b.capNhat()
        return b
    }

    private init(o: NSTextField, nut: [NSButton], hopLe: @escaping (String) -> Bool) {
        self.o = o
        self.nut = nut
        self.hopLe = hopLe
    }

    /// Đọc lại ô và bật/tắt nút. Công khai vì mã ĐẶT chữ vào ô (không qua bàn phím) phải gọi
    /// nó — `controlTextDidChange` chỉ bắn khi người gõ.
    public func capNhat() {
        let ok = hopLe(o.stringValue)
        for n in nut { n.isEnabled = ok }
    }

    public func controlTextDidChange(_ n: Notification) {
        guard (n.object as? NSTextField) === o else { return }
        capNhat()
    }
}
