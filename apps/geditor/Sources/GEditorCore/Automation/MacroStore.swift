import Foundation

/// Lưu macro có tên, sống qua các lần mở app (FR-AUTO-601, TC-AUTO-01).
///
/// MỖI macro một file, không phải một file chung.
///
/// Lý do là hỏng thì hỏng lẻ: một file macro viết dở vì mất điện chỉ làm mất đúng macro ấy,
/// còn một file chung hỏng là mất sạch. Đổi lại, người dùng gửi cho nhau được một macro bằng
/// cách gửi một file — đúng tinh thần ADR-09 "cấu hình là file văn bản".
public final class MacroStore {

    private let root: URL
    private let fileManager = FileManager.default

    public init(root: URL = AppPaths.macrosDirectory) {
        self.root = root
    }

    public var directory: URL { root }

    /// Tên file an toàn cho một tên macro.
    ///
    /// Người dùng đặt tên macro là "sửa CSV / cột 3" thì dấu gạch chéo sẽ thành thư mục con,
    /// và dấu chấm đầu tên sẽ thành file ẩn. Chỉ giữ chữ, số, gạch ngang và gạch dưới; phần
    /// còn lại thành gạch ngang.
    public static func fileName(for name: String) -> String {
        let allowed = name.map { character -> Character in
            if character.isLetter || character.isNumber { return character }
            return "-"
        }
        let trimmed = String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return trimmed.isEmpty ? "macro" : trimmed
    }

    public func save(_ macro: Macro) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(macro)
        let url = root.appendingPathComponent(Self.fileName(for: macro.name) + ".json")
        try AtomicFileWriter.write([UInt8](data), to: url.path)
    }

    /// Mọi macro đã lưu, sắp theo TÊN.
    ///
    /// Sắp theo tên chứ không theo thời gian sửa: menu Macro phải đứng yên giữa hai lần mở,
    /// nếu không thì phím tắt gán theo vị trí sẽ trỏ vào macro khác mỗi ngày.
    ///
    /// File hỏng bị BỎ QUA chứ không làm hỏng cả danh sách — cùng lý do như file phiên.
    public func all() throws -> [Macro] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let files = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let macros = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Macro? in
                guard let data = fileManager.contents(atPath: url.path) else { return nil }
                return try? JSONDecoder().decode(Macro.self, from: data)
            }
        return macros.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func delete(named name: String) throws {
        let url = root.appendingPathComponent(Self.fileName(for: name) + ".json")
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}
