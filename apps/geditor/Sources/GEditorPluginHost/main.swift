import Darwin
import Foundation
import GEditorCore

/// Tiến trình phụ nạp plugin native — FR-PLUG-702 · FR-PLUG-703 (ADR-12 phương án C).
///
/// **Đây là tiến trình DUY NHẤT trong sản phẩm được phép nạp mã của người khác.** Nó là lý do
/// cả kiến trúc này tồn tại, nên nó phải nhỏ tới mức đọc hết trong một lần ngồi.
///
/// Hardened runtime — bắt buộc để công chứng — bật library validation, và dyld từ chối dylib
/// của bên thứ ba (*"different Team IDs"*, đo ở PoC-H). Lối ra đã chốt: app chính giữ nguyên
/// entitlement, còn `disable-library-validation` chỉ nằm ở tiến trình này.
///
/// ## Nó KHÔNG có gì
///
/// Không mở file, không mở mạng, không đọc tài liệu của người dùng từ đĩa. Mọi thứ nó biết đều
/// do app truyền qua ống, và mọi thứ nó nói đều đi qua ống về. Nên một plugin độc hại ở đây
/// không có gì để lấy — và nếu nó làm tiến trình này chết, app vẫn sống, người dùng chỉ mất
/// tính năng của plugin chứ không mất việc đang làm.
///
/// ## Giao ước C mà plugin phải theo
///
/// Đúng hai hàm, cố ý ít tới mức khó viết sai:
///
/// ```c
/// const char *geditor_plugin_describe(void);
/// const char *geditor_plugin_run(const char *command, const char *text,
///                                int32_t selection_start, int32_t selection_end);
/// ```
///
/// - `describe` trả JSON của `NativePluginManifest`.
/// - `run` trả văn bản MỚI, hoặc `NULL` nghĩa là "không đổi gì".
/// - Vùng chọn tính bằng offset BYTE trong `text`; `-1, -1` nghĩa là không bôi đen gì.
/// - **Chuỗi trả về thuộc về plugin**, và chỉ cần sống tới lời gọi kế tiếp. Giao ước ấy chọn vì
///   nó là thứ dễ làm đúng nhất ở phía plugin: một biến `static` là đủ. Bắt plugin cấp phát rồi
///   app giải phóng thì phải thống nhất cả bộ cấp phát, và đó là chỗ đẻ ra lỗi khó nhất.
///
/// ## Vì sao ống chứ không phải `NSXPCConnection`
///
/// FR-PLUG-703 gọi tên "XPC", và ADR-12 đọc nó là "chạy ở tiến trình riêng". Ở đây dùng tiến
/// trình con nói chuyện qua ống, vì ba lý do nói ra được:
///
/// 1. **Đó chính là thứ PoC-H đã ĐO** — 0,010 ms mỗi lần gọi. Con số đứng sau quyết định là
///    con số của hình dạng này.
/// 2. Một XPC service thật phải nằm trong `Contents/XPCServices/*.xpc` và do launchd khởi động,
///    nên nó không chạy được dưới `swift test` — tức là không có bài kiểm tự động nào.
/// 3. Ống không thêm phụ thuộc nào và không cần quyền nào.
///
/// Cái mất: XPC cho `launchd` khởi động lại tiến trình khi nó chết, và cho kiểm quyền theo mã
/// ký. Chưa cần tới, và đổi về sau chỉ chạm tệp này với `NativePluginBridge`.
enum PluginHost {

    static func main() {
        // Đường dẫn dylib truyền qua đối số, không qua biến môi trường: đối số nằm trong lệnh
        // đã chạy nên `ps` thấy được, còn biến môi trường thì thừa hưởng lung tung.
        guard CommandLine.arguments.count >= 2 else {
            fail("cần đường dẫn tới plugin")
        }
        let path = CommandLine.arguments[1]

        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            // `dlerror` là chỗ DUY NHẤT nói vì sao library validation từ chối; nuốt nó đi thì
            // triệu chứng chỉ còn là "plugin không chạy".
            fail("không nạp được plugin: \(String(cString: dlerror() ?? UnsafeMutablePointer(mutating: "")))")
        }
        defer { dlclose(handle) }

        typealias Describe = @convention(c) () -> UnsafePointer<CChar>?
        typealias Run = @convention(c) (
            UnsafePointer<CChar>?, UnsafePointer<CChar>?, Int32, Int32
        ) -> UnsafePointer<CChar>?

        guard let describeSymbol = dlsym(handle, "geditor_plugin_describe") else {
            fail("plugin thiếu geditor_plugin_describe")
        }
        guard let runSymbol = dlsym(handle, "geditor_plugin_run") else {
            fail("plugin thiếu geditor_plugin_run")
        }
        let describe = unsafeBitCast(describeSymbol, to: Describe.self)
        let run = unsafeBitCast(runSymbol, to: Run.self)

        serve(describe: describe, run: run)
    }

    /// Vòng phục vụ: đọc lời gọi, trả lời, lặp cho tới khi app đóng ống.
    ///
    /// App đóng ống là cách kết thúc BÌNH THƯỜNG — không có lệnh "thoát" riêng, vì một lệnh như
    /// thế lại là một đường mã nữa phải đúng, và nó không làm được gì mà việc đóng ống không làm.
    private static func serve(describe: @convention(c) () -> UnsafePointer<CChar>?,
                             run: @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?,
                                                  Int32, Int32) -> UnsafePointer<CChar>?) {
        var buffer = Data()
        let input = FileHandle.standardInput
        let output = FileHandle.standardOutput

        while true {
            // Giải mã hết những thông điệp ĐÃ đủ byte trước khi đọc thêm: một lần đọc có thể
            // mang về nhiều thông điệp, và bỏ sót chúng là treo.
            while true {
                let decoded: (value: NativePluginRequest, consumed: Int)?
                do {
                    decoded = try NativePluginWire.decode(NativePluginRequest.self, from: buffer)
                } catch {
                    respond(.failure("thông điệp hỏng: \(error)"), to: output)
                    return
                }
                guard let decoded else { break }
                buffer.removeFirst(decoded.consumed)
                respond(answer(decoded.value, describe: describe, run: run), to: output)
            }

            let chunk = input.availableData
            if chunk.isEmpty { return }         // app đóng ống — xong việc
            buffer.append(chunk)
        }
    }

    private static func answer(
        _ request: NativePluginRequest,
        describe: @convention(c) () -> UnsafePointer<CChar>?,
        run: @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, Int32, Int32)
            -> UnsafePointer<CChar>?
    ) -> NativePluginResponse {
        switch request {
        case .describe:
            guard let raw = describe() else { return .failure("plugin không tự khai được") }
            let json = Data(String(cString: raw).utf8)
            guard let manifest = try? JSONDecoder().decode(NativePluginManifest.self, from: json)
            else { return .failure("bản khai của plugin không đọc được") }
            return .manifest(manifest)

        case let .run(command, text, selection):
            // Offset vùng chọn kẹp vào chính `text` TRƯỚC khi giao cho plugin. Plugin là mã của
            // người khác; đưa cho nó một cặp offset nằm ngoài chuỗi là mời nó đọc quá biên.
            let bytes = text.utf8.count
            let start = selection.map { Swift.min(Swift.max($0.lowerBound, 0), bytes) } ?? -1
            let end = selection.map { Swift.min(Swift.max($0.upperBound, start), bytes) } ?? -1
            let result = command.withCString { commandPointer in
                text.withCString { textPointer in
                    run(commandPointer, textPointer, Int32(start), Int32(end))
                }
            }
            guard let result else { return .replacement(nil) }
            return .replacement(String(cString: result))
        }
    }

    private static func respond(_ response: NativePluginResponse, to output: FileHandle) {
        guard let data = try? NativePluginWire.encode(response) else { return }
        output.write(data)
    }

    private static func fail(_ message: String) -> Never {
        if let data = try? NativePluginWire.encode(NativePluginResponse.failure(message)) {
            FileHandle.standardOutput.write(data)
        }
        exit(1)
    }
}

PluginHost.main()
