import Foundation
import GEditorCore

/// Danh sách plugin native đã cài, và đường chạy chúng — FR-PLUG-704 (ADR-12).
///
/// **Danh sách suy ra TỪ ĐĨA, không có sổ đăng ký.** Cùng luật với gói dữ liệu
/// (`PluginPackage`) và vì cùng một lý do: người dùng xoá tay một file trong Finder thì một
/// cuốn sổ nói khác đi là cuốn sổ nói dối. Cài là chép file vào
/// `~/Library/Application Support/GEditor/plugins/`, gỡ là xoá file — không có bước thứ ba, và
/// không có trạng thái nào để lệch pha.
///
/// Đó cũng là câu trả lời tối thiểu mà **SEC-03** đòi: *cài từ đâu* (một file người dùng tự
/// chép vào, đường dẫn hiện ngay trên bảng) và *gỡ thế nào* (xoá file ấy — bằng ứng dụng hay
/// bằng Finder đều đúng như nhau).
///
/// ## Nạp LƯỜI, và vì sao điều đó quan trọng
///
/// Quét thư mục là rẻ; hỏi từng plugin "anh là ai" thì không — mỗi lần hỏi là một tiến trình
/// mới và một `dlopen` mã lạ. Làm việc ấy lúc khởi động là trả giá ADR-08 cho một tính năng
/// phần lớn người dùng không có plugin nào để dùng.
///
/// Nên: `installed()` chỉ đọc tên file. Bản khai chỉ được hỏi khi ai đó thật sự mở bảng quản lý
/// hoặc mở menu plugin.
final class NativePluginRegistry {

    static let shared = NativePluginRegistry()

    /// Đuôi file quy ước. Dùng `.dylib` chứ không đặt đuôi riêng: đó ĐÚNG là thứ nó là, và một
    /// cái đuôi bịa ra chỉ làm người ta tưởng định dạng có gì khác.
    static let fileExtension = "dylib"

    /// Một plugin đã cài, ở mức "mới chỉ biết tên file".
    struct Installed: Equatable {
        let url: URL
        var fileName: String { url.lastPathComponent }
    }

    /// Một plugin đã hỏi được bản khai — hoặc đã hỏi và HỎNG.
    ///
    /// Giữ cả hai trong một kiểu, vì bảng quản lý phải hiện được cả plugin hỏng: một plugin
    /// biến mất khỏi danh sách vì nó lỗi là cách chắc chắn để người dùng không hiểu chuyện gì
    /// đang xảy ra, và cũng không biết đường gỡ nó ra.
    struct Described {
        let installed: Installed
        let manifest: NativePluginManifest?
        let failure: String?
    }

    private var bridges: [URL: NativePluginBridge] = [:]

    // MARK: - Đọc đĩa

    /// Thư mục plugin đang dùng. Bài tự kiểm trỏ nó sang chỗ tạm — xem
    /// `useTemporaryDirectoryForSelfTest`.
    var directory: URL { overrideDirectory ?? AppPaths.nativePluginsDirectory }

    private var overrideDirectory: URL?

    /// Plugin native có dùng được ở bản này không (ADR-12: chỉ bản tải trực tiếp).
    var isSupported: Bool { Distribution.current == .direct }

    func installed() -> [Installed] {
        guard isSupported,
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return [] }
        return names
            .filter { $0.hasSuffix("." + Self.fileExtension) }
            .sorted()
            .map { Installed(url: directory.appendingPathComponent($0)) }
    }

    /// Hỏi bản khai của từng plugin. ĐẮT — xem chú thích "nạp lười" ở đầu lớp.
    func describeAll() -> [Described] {
        installed().map { plugin in
            do {
                return Described(
                    installed: plugin, manifest: try bridge(for: plugin.url).describe(),
                    failure: nil)
            } catch {
                // Plugin hỏng thì ĐÓNG tiến trình của nó ngay: giữ một tiến trình phụ sống chỉ
                // để nó không làm gì là giữ một `dlopen` mã lạ không lý do.
                close(plugin.url)
                return Described(
                    installed: plugin, manifest: nil,
                    failure: (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription)
            }
        }
    }

    // MARK: - Cài và gỡ

    enum InstallFailure: Error, LocalizedError {
        case notSupported
        case notADylib
        case alreadyInstalled(String)
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .notSupported:
                return L("Plugin native chỉ có ở bản tải trực tiếp, không có ở bản App Store.")
            case .notADylib:
                return L("Chỉ nhận file .dylib.")
            case let .alreadyInstalled(name):
                return L("Đã có một plugin trùng tên:") + " \(name)"
            case let .copyFailed(reason):
                return L("Không chép được plugin:") + " \(reason)"
            }
        }
    }

    /// Cài = CHÉP file vào thư mục plugin. Không giải nén, không chạy gì.
    ///
    /// **Cố ý không hỏi plugin trước khi chép.** Hỏi tức là `dlopen` mã lạ, và làm việc ấy như
    /// một phần của phép "cài" nghĩa là chỉ cần chọn nhầm file là đã chạy mã của nó. Chép
    /// trước, hỏi sau — và nếu nó hỏng thì bảng quản lý hiện nó kèm lỗi, người dùng gỡ ra được.
    @discardableResult
    func install(from source: URL) throws -> Installed {
        guard isSupported else { throw InstallFailure.notSupported }
        guard source.pathExtension == Self.fileExtension else { throw InstallFailure.notADylib }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw InstallFailure.alreadyInstalled(source.lastPathComponent)
        }
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw InstallFailure.copyFailed(error.localizedDescription)
        }
        return Installed(url: destination)
    }

    /// Gỡ = XOÁ file. Đóng tiến trình trước, vì một file đang bị `dlopen` giữ thì xoá được
    /// nhưng mã cũ vẫn sống trong tiến trình ấy — và người dùng sẽ thấy plugin "đã gỡ" mà vẫn
    /// chạy cho tới khi thoát app.
    func remove(_ plugin: Installed) throws {
        close(plugin.url)
        try FileManager.default.removeItem(at: plugin.url)
    }

    // MARK: - Tin cậy (NFR-SEC-03)

    /// Sổ duyệt, nằm CẠNH thư mục plugin.
    ///
    /// Không nằm trong thư mục ấy: `installed()` lọc theo đuôi `.dylib` nên một tệp JSON ở đó
    /// vô hại hôm nay, nhưng "vô hại vì bộ lọc hiện tại tình cờ bỏ qua nó" không phải một lý do
    /// đủ tốt để đặt sổ duyệt an ninh chung chỗ với thứ nó canh gác.
    var trustStoreURL: URL {
        directory.deletingLastPathComponent().appendingPathComponent("plugin-trust.json")
    }

    func trustStore() -> PluginTrust.Store {
        (try? PluginTrust.Store.load(from: trustStoreURL)) ?? PluginTrust.Store()
    }

    func verdict(for url: URL) throws -> PluginTrust.Verdict {
        try PluginTrust.verdict(forFileAt: url.path, in: trustStore())
    }

    /// Ghi nhận người dùng đã duyệt file này, ở đúng nội dung HIỆN TẠI của nó.
    func approve(_ url: URL) throws {
        var store = trustStore()
        store.approve(.init(
            fileName: url.lastPathComponent,
            sha256: try PluginTrust.sha256(ofFileAt: url.path),
            approvedAt: ISO8601DateFormatter().string(from: Date()),
            signedBy: PluginTrust.signer(ofFileAt: url.path)))
        try store.save(to: trustStoreURL)
    }

    func forgetApproval(_ url: URL) throws {
        var store = trustStore()
        store.forget(fileName: url.lastPathComponent)
        try store.save(to: trustStoreURL)
    }

    // MARK: - Chạy

    enum TrustFailure: LocalizedError {
        case notApproved(PluginTrust.Verdict, fileName: String)

        var message: String {
            switch self {
            case .notApproved(let verdict, let fileName):
                return PluginTrust.explanation(verdict, fileName: fileName)
            }
        }

        /// Bảng quản lý plugin bắt lỗi theo `LocalizedError` — không có nó thì chỗ đáng lẽ hiện
        /// câu cảnh báo an ninh lại hiện "The operation couldn't be completed."
        var errorDescription: String? { message }
    }

    /// Cửa DUY NHẤT dẫn tới việc chạy mã của plugin — nên cổng tin cậy nằm ở đây.
    ///
    /// Kể cả `describeAll()` cũng đi qua đây, và đó là chủ ý: hỏi một plugin "anh là ai" nghĩa
    /// là `dlopen` mã của nó. Một bảng quản lý hiện được tên và phiên bản của plugin CHƯA DUYỆT
    /// là một bảng đã chạy mã chưa duyệt để lấy được hai dòng chữ ấy.
    ///
    /// Mọi dữ kiện trong câu hỏi duyệt — đường dẫn, SHA-256, chữ ký — đọc được mà KHÔNG cần
    /// chạy gì. Đó là điều kiện để câu hỏi ấy có nghĩa.
    func bridge(for url: URL) throws -> NativePluginBridge {
        if let existing = bridges[url] { return existing }
        let verdict = try verdict(for: url)
        guard verdict == .trusted else {
            throw TrustFailure.notApproved(verdict, fileName: url.lastPathComponent)
        }
        let created = NativePluginBridge(url: url)
        bridges[url] = created
        return created
    }

    func close(_ url: URL) {
        bridges.removeValue(forKey: url)?.close()
    }

    func closeAll() {
        for bridge in bridges.values { bridge.close() }
        bridges.removeAll()
    }

    // MARK: - Móc tự kiểm

    /// Trỏ thư mục plugin vào một chỗ TẠM.
    ///
    /// Bắt buộc với bài tự kiểm, cùng lý do với `useTemporaryStoresForSelfTest`: không có nó
    /// thì bài kiểm chép mã máy vào thư mục plugin THẬT của người đang chạy máy.
    @discardableResult
    func useTemporaryDirectoryForSelfTest() -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-selftest-plugins-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        Unattended.registerTemporaryRoot(root)
        overrideDirectory = root
        return root
    }
}
