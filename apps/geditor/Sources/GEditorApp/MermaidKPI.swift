import AppKit
import Foundation
import GEditorCore

/// Đo NFR-MMD-01 trên ĐÚNG đường sản phẩm — `GEditorApp --mermaid-kpi`.
///
/// ## Vì sao không đo lại bằng một bộ đo riêng như PoC-L
///
/// PoC-L trả lời câu hỏi *"WKWebView có phá ADR-08 không"*, nên nó dựng một harness riêng và
/// điều đó đúng: lúc ấy chưa có mã sản phẩm nào để đo. Giờ thì có, và một bộ đo dựng harness
/// riêng sẽ đo **một đường không ai chạy** — nó bỏ qua hàng rào chặn mạng, bỏ qua `deterministicIds`,
/// bỏ qua hàng đợi bỏ-lượt-cũ. Con số ấy đẹp hơn sự thật.
///
/// Nên bộ đo này gọi thẳng `MermaidRenderer` mà bảng Mermaid Studio dùng.
///
/// Ba chỉ tiêu của NFR-MMD-01, mỗi cái một cột:
///   1. sơ đồ 500 node ≤ 2 giây (tính CẢ lần mở đầu: dựng WKWebView + nạp mermaid),
///   2. cập nhật sau khi sửa ≤ 500 ms (lượt vẽ THỨ HAI trở đi, trang đã sẵn),
///   3. WKWebView chỉ khởi tạo khi mở preview — đo bằng RAM trước/sau.
enum MermaidKPI {

    static func run(arguments: [String]) {
        let renderer = MermaidRenderer()
        let rssBefore = residentMB()

        // Sơ đồ 500 node — đúng cỡ NFR-MMD-01 nói tới.
        var big = "flowchart TD\n"
        for index in 0..<500 {
            big += "  n\(index)[\"Nút \(index)\"]\n"
            if index > 0 { big += "  n\(index - 1) --> n\(index)\n" }
        }
        let small = "flowchart LR\n  A[Bắt đầu] --> B{Kiểm tra}\n"
            + "  B -->|đúng| C[Xong]\n  B -->|sai| A\n"

        var firstMs = 0.0
        var updateMs: [Double] = []
        var rssAfter = 0.0
        var svgBytes = 0
        var failure: String?
        var done = false

        // --- 1. Lần mở đầu: dựng web view + nạp mermaid + vẽ 500 node -------------------
        let started = DispatchTime.now().uptimeNanoseconds
        renderer.render([.init(index: 0, source: big)]) { results in
            firstMs = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            rssAfter = residentMB()
            svgBytes = results.first?.svg?.utf8.count ?? 0
            failure = results.first?.error ?? renderer.failureReason
            if failure != nil { done = true; return }

            // --- 2. Cập nhật: năm lượt vẽ liên tiếp trên trang ĐÃ sẵn ------------------
            //
            // Lấy TRUNG VỊ chứ không lấy lần nhanh nhất: người dùng gặp lần điển hình, không
            // gặp lần may mắn.
            func again(_ remaining: Int) {
                guard remaining > 0 else { done = true; return }
                let mark = DispatchTime.now().uptimeNanoseconds
                renderer.render([.init(index: 0, source: small)]) { _ in
                    updateMs.append(
                        Double(DispatchTime.now().uptimeNanoseconds - mark) / 1_000_000)
                    again(remaining - 1)
                }
            }
            again(5)
        }

        let deadline = Date().addingTimeInterval(60)
        while !done, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        let sorted = updateMs.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let firstPass = failure == nil && firstMs <= 2_000
        let updatePass = failure == nil && !sorted.isEmpty && median <= 500

        var out: [String: Any] = [
            "kpi": "NFR-MMD-01 — 500 node ≤ 2 s · cập nhật ≤ 500 ms",
            "architecture": machineArchitecture(),
            "mermaidVersion": MermaidAsset.manifest?.version ?? "?",
            "firstRenderMs": firstMs,
            "firstBudgetMs": 2_000,
            "updateMedianMs": median,
            "updateMs": updateMs,
            "updateBudgetMs": 500,
            "rssBeforeMB": rssBefore,
            "rssAfterMB": rssAfter,
            "svgBytes": svgBytes,
            "pass": firstPass && updatePass,
            "notes": [
                "Đo bằng CHÍNH `MermaidRenderer` mà bảng Mermaid Studio dùng — kể cả hàng rào "
                    + "chặn mạng và `deterministicIds`, hai thứ một harness riêng sẽ bỏ qua.",
                "Cột «lần đầu» tính CẢ dựng WKWebView và nạp 3,4 MB JavaScript. Người dùng trả "
                    + "khoản ấy đúng một lần cho mỗi phiên, và chỉ khi họ mở một sơ đồ.",
                "RAM: chênh lệch trước/sau là giá của WKWebView. NFR-PERF-05 nói về RAM NGHỈ, "
                    + "nên nó không đụng chỉ tiêu ấy — miễn là bộ render dựng lười.",
            ],
        ]
        if let failure { out["failure"] = failure }

        let json = (try? JSONSerialization.data(
            withJSONObject: out, options: [.prettyPrinted, .sortedKeys]))
            .map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        print(json)

        let folder = "benchmarks/results"
        try? FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try? json.write(
            toFile: folder + "/mermaid-kpi-\(machineArchitecture()).json",
            atomically: true, encoding: .utf8)

        FileHandle.standardError.write(Data((
            failure.map { "❌ \($0)\n" }
                ?? String(format: """
                    %@ NFR-MMD-01 — lần đầu %.0f ms / trần 2000 · cập nhật (trung vị) %.0f ms \
                    / trần 500 · RAM %.0f → %.0f MB

                    """, firstPass && updatePass ? "✅" : "❌", firstMs, median,
                    rssBefore, rssAfter)).utf8))
        exit(firstPass && updatePass ? 0 : 1)
    }

    private static func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576
    }

    private static func machineArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
