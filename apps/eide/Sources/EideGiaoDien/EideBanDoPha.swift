import AppKit
import EideLoi

/// **Bản đồ tám pha P0–P7** — EIDE-BPD §3–§9.
///
/// ## Tám pha đến TỪ TÀI LIỆU, không do màn nào nghĩ ra
///
/// `EIDE-BPD` định nghĩa tám quy trình vận hành và ghi rõ năng lực nào được gọi ở bước nào.
/// Bảng dưới rút ra từ chính `docs/ho-so/nguon/bpd.js`, và có một bài kiểm Python đọc lại tệp
/// ấy để đối chiếu — tài liệu đổi mà bảng này không đổi thì phía Python đỏ trước.
///
/// Tự gán pha theo tên nhóm năng lực (`code.* → P3`) nghe hợp lý và **sai**: `code.human_save`
/// là việc của người ở P5, `doc.*` nằm ở P7 chứ không P6. Một sơ đồ luồng gán sai pha tệ hơn
/// không có — nó nói với người dùng rằng dự án đang ở một chỗ khác chỗ nó đang ở.
public struct EidePha: Equatable {
    public let ma: String
    public let ten: String
    public let caps: [String]

    public init(ma: String, ten: String, caps: [String]) {
        self.ma = ma
        self.ten = ten
        self.caps = caps
    }
}

public enum EideBanDoPha {
    public static let PHA: [EidePha] = [
        .init(ma: "P0", ten: "Tiếp nhận lệnh ngôn ngữ tự nhiên (mới v1.1)",
              caps: ["chat.clarify", "chat.command", "chat.fill_defaults", "chat.ground", "chat.orchestrate", "chat.parse_intent", "chat.report_back", "chat.restate", "policy.decide"]),
        .init(ma: "P1", ten: "Nhận tri thức phần cứng",
              caps: ["archive.explore", "bench.verify_passport", "discover.chip_id", "kg.build", "kg.resolve_conflict", "kg.review_facts", "passport.build", "policy.decide", "search.fetch", "search.missing", "search.rank", "search.registry", "view.doc_side_by_side", "view.rag_index"]),
        .init(ma: "P2", ten: "Lập kế hoạch có trích dẫn",
              caps: ["kg.conflicts", "policy.decide"]),
        .init(ma: "P3", ten: "Sinh mã từ hộ chiếu",
              caps: ["code.merge", "policy.decide"]),
        .init(ma: "P4", ten: "Xác minh trên mô phỏng và phần cứng",
              caps: ["discover.ports", "policy.decide", "sim.build", "target.flash", "target.observe", "target.serial"]),
        .init(ma: "P5", ten: "Gỡ lỗi có chứng cứ",
              caps: ["debug.experiment", "log.stats", "policy.decide"]),
        .init(ma: "P6", ten: "Bàn giao, đóng gói và phát hành",
              caps: ["policy.decide", "registry.publish"]),
        .init(ma: "P7", ten: "Yêu cầu → kiến trúc → lược đồ → tài liệu (mới v1.1)",
              caps: ["arch.adr", "arch.compare", "arch.decompose", "arch.interface_spec", "arch.map_hw", "arch.memory_budget", "arch.review", "arch.state_machine", "arch.style_select", "arch.timing_budget", "arch.to_plan", "board.check_pins", "diagram.block", "diagram.lint", "diagram.render", "diagram.stale", "diagram.sync", "doc.embed_diagram", "doc.generate", "doc.style_check", "doc.sync", "doc_artifact.stale_sections", "req.change_impact", "req.classify", "req.detect_conflict", "req.elicit", "req.ground_hw", "req.prioritize", "req.trace_matrix", "view.impact_map"]),
    ]

    /// Pha của một năng lực. `nil` = năng lực không nằm trong quy trình nào của BPD — và đó là
    /// một câu trả lời, không phải chỗ trống: 68 trong 244 năng lực có mặt trong tám quy trình,
    /// phần còn lại là năng lực phụ trợ mà tài liệu không xếp vào pha nào.
    public static func phaCua(_ cap: String) -> String? {
        PHA.first { $0.caps.contains(cap) }?.ma
    }
}
