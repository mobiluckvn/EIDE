// SINH TỰ ĐỘNG — đừng sửa tay.
//
// Nguồn: docs/spec/api/openrpc.json và errors.json.
// Sinh lại: python3 scripts/gen_rpc_swift.py   ·   Đối chiếu: --kiem (chạy trong CI).
//
// GPI-23 §2 và API-15 §8 (3) đòi plugin dùng bộ mã sinh từ openrpc.json chứ không viết
// tay chuỗi phương thức: 55 chuỗi viết tay là 55 chỗ trình biên dịch không kiểm được.

import Foundation

/// Tên phương thức JSON-RPC của EIDE (API-15 §2).
public enum EideMethod: String, CaseIterable, Sendable {
    /// set là R4 khi nới lỏng → gate
    case autonomyGet = "autonomy.get"
    /// set là R4 khi nới lỏng → gate
    case autonomySet = "autonomy.set"
    case capsDescribe = "caps.describe"
    /// Đường gọi duy nhất; tool nặng trả job_id trong result
    case capsInvoke = "caps.invoke"
    /// Từ registry
    case capsList = "caps.list"
    /// Trả lời câu hỏi gộp
    case chatAnswer = "chat.answer"
    /// Từ session.turns
    case chatHistory = "chat.history"
    /// Đưa lệnh vào Orchestrator; kết quả đến qua sự kiện
    case chatSend = "chat.send"
    /// GEditor tính stats native
    case debugAsk = "debug.ask"
    /// GEditor render
    case diagramOpen = "diagram.open"
    /// GEditor render
    case diagramSave = "diagram.save"
    /// Cập nhật qua event.discover.changed
    case discoverStatus = "discover.status"
    case docOpen = "doc.open"
    /// Kể cả STOP
    case eventAutonomyChanged = "event.autonomy.changed"
    /// Tác tử hiểu ý định thành chuỗi năng lực nào
    case eventChatIntent = "event.chat.intent"
    /// Thẻ câu hỏi gộp
    case eventChatQuestion = "event.chat.question"
    /// Thẻ báo cáo cuối
    case eventChatReport = "event.chat.report"
    /// Thẻ "tôi hiểu là…"
    case eventChatRestated = "event.chat.restated"
    case eventDiagramStale = "event.diagram.stale"
    /// Cắm/rút board
    case eventDiscoverChanged = "event.discover.changed"
    case eventDocStale = "event.doc.stale"
    /// Cổng tự quyết APPROVE/REJECT — không vào hàng đợi
    case eventGateDecided = "event.gate.decided"
    /// Mục ASK mới
    case eventGateOpened = "event.gate.opened"
    case eventJobProgress = "event.job.progress"
    /// Sau extract/review
    case eventKnowledgeChanged = "event.knowledge.changed"
    /// Chi phí; KHÔNG mang nội dung prompt
    case eventModelCall = "event.model.call"
    /// Cảnh báo chung
    case eventNotice = "event.notice"
    /// Đổi dự án hoặc đích đã ghim
    case eventProjectChanged = "event.project.changed"
    case eventQueueChanged = "event.queue.changed"
    /// Dòng tiến độ chuỗi
    case eventRunProgress = "event.run.progress"
    case eventSerialLine = "event.serial.line"
    /// build/size/sim/install chạy xong
    case eventToolReport = "event.tool.report"
    case eventUndoExpired = "event.undo.expired"
    case eventUndoRegistered = "event.undo.registered"
    /// Người quyết định mục ASK
    case gateDecide = "gate.decide"
    case hexResolve = "hex.resolve"
    /// Tool nặng (build, flash, extract, render, install)
    case jobCancel = "job.cancel"
    /// Tool nặng (build, flash, extract, render, install)
    case jobStatus = "job.status"
    /// GEditor tính stats native
    case logRegister = "log.register"
    /// GEditor tính stats native
    case logStats = "log.stats"
    /// < 200 ms
    case passportBrowse = "passport.browse"
    /// < 200 ms
    case passportQuery = "passport.query"
    /// Handshake; từ chối khi major khác
    case planeHello = "plane.hello"
    /// Mở dự án = M2 SessionMemory mới
    case projectClose = "project.close"
    /// Mở dự án = M2 SessionMemory mới
    case projectList = "project.list"
    /// Mở dự án = M2 SessionMemory mới
    case projectOpen = "project.open"
    /// Hàng đợi chờ tôi / đã làm
    case queueList = "queue.list"
    /// Sự kiện serial.line
    case serialClose = "serial.close"
    /// Sự kiện serial.line
    case serialExpect = "serial.expect"
    /// Sự kiện serial.line
    case serialOpen = "serial.open"
    /// Sự kiện serial.line
    case serialWrite = "serial.write"
    /// Đọc M2 của phiên đang mở (MEM-11 §2). `permits`/`board` rỗng cho tới khi SessionMemory lưu chúng — DEV-110
    case sessionState = "session.state"
    /// Dừng khẩn < 1 s
    case stop = "stop"
    /// Hoàn tác việc tự làm
    case undoApply = "undo.apply"
    /// Hoàn tác việc tự làm
    case undoList = "undo.list"
    /// Alias caps.invoke để plugin gọi ngắn
    case viewCoverage = "view.coverage"
    /// Alias caps.invoke để plugin gọi ngắn
    case viewFocus = "view.focus"
    /// Alias caps.invoke để plugin gọi ngắn
    case viewImpact = "view.impact"
    /// Alias caps.invoke để plugin gọi ngắn
    case viewKgMap = "view.kg_map"
    /// Alias caps.invoke để plugin gọi ngắn
    case viewProvenance = "view.provenance"
    case viewRagAsk = "view.rag_ask"
    case viewRagTrace = "view.rag_trace"
    /// Alias caps.invoke để plugin gọi ngắn
    case viewTimeline = "view.timeline"
}

/// Mã lỗi EIDE (API-15 §3). `rawValue` là phần SỐ trong JSON-RPC error.code;
/// `ma` giữ dạng `Exxxx` để đối chiếu với tài liệu và với ledger.
public enum EideErrorCode: Int, Error, CaseIterable, Sendable {
    /// INVALID_ARGS — Tham số không khớp input_schema
    case invalidArgs = 1000
    /// UNKNOWN_CAPABILITY — id không có trong registry
    case unknownCapability = 1001
    /// API_VERSION — Phiên bản plugin/daemon không tương thích
    case apiVersion = 1002
    /// UNAUTHORIZED — Token REST sai
    case unauthorized = 1003
    /// OUTPUT_SCHEMA — Kết quả năng lực không khớp output_schema (lỗi hiện thực)
    case outputSchema = 1004
    /// GROUNDING_FAILED — Tiền điều kiện không thỏa: dự án chưa mở, nguồn không tồn tại, hộ chiếu thiếu
    case groundingFailed = 2000
    /// ALREADY_EXISTS — Tạo trùng (dự án, feature)
    case alreadyExists = 2001
    /// POLICY_ASK — Cần người (không phải lỗi; status pending)
    case policyAsk = 3000
    /// POLICY_REJECT — Chính sách từ chối
    case policyReject = 3001
    /// STOPPED — Phiên đang dừng khẩn
    case stopped = 3002
    /// BUDGET_EXCEEDED — Vượt ngân sách ngày
    case budgetExceeded = 3003
    /// TOOL_FAILED — Công cụ ngoài thất bại (build, flash, render…)
    case toolFailed = 4000
    /// TOOL_MISSING — Thiếu công cụ
    case toolMissing = 4001
    /// TARGET_NOT_FOUND — Không có board/probe phù hợp
    case targetNotFound = 4002
    /// CHIP_ID_MISMATCH — ID chip không khớp hộ chiếu
    case chipIdMismatch = 4003
    /// TIMEOUT — Quá thời gian job/serial/probe
    case timeout = 4004
    /// MODEL_ERROR — Lỗi gọi mô hình (rate limit, refusal, schema)
    case modelError = 5000
    /// CONTEXT_OVERFLOW — Không nén được về ngân sách (CXD-10 §7)
    case contextOverflow = 5001
    /// OUTPUT_INVALID — Đầu ra mô hình sai schema sau 1 lần sửa
    case outputInvalid = 5002
    /// CONSTANT_GUARD — Hằng số không nguồn trong mã
    case constantGuard = 5003
    /// STORE_INTEGRITY — Hash store lệch / ghi ngoài cổng
    case storeIntegrity = 6000
    /// SCHEMA_VIOLATION — Ghi sai JSON Schema (DDD-14)
    case schemaViolation = 6001
    /// CONFLICT — Fact mâu thuẫn cần người
    case conflict = 6002
    /// MIGRATION_REQUIRED — user_version cũ
    case migrationRequired = 6003
    /// UNDO_EXPIRED — Quá cửa sổ hoàn tác
    case undoExpired = 7000
    /// UNDO_FAILED — Hoàn tác không thành (revert xung đột…)
    case undoFailed = 7001
    /// SANDBOX_VIOLATION — Extractor/công cụ vượt giới hạn
    case sandboxViolation = 8000
    /// LICENSE_BLOCKED — License không cho phép
    case licenseBlocked = 8001
    /// SENSITIVE_UPLOAD — Dự án nhạy cảm cần xác nhận gửi ra ngoài
    case sensitiveUpload = 8002

    public var ma: String { String(format: "E%04d", rawValue) }

    /// Cách xử lý mà API-15 §3 khuyến nghị — hiện ra cùng thông báo lỗi, vì một mã lỗi
    /// không kèm việc phải làm thì chỉ là một con số.
    public var cachXuLy: String {
        switch self {
        case .invalidArgs: return "Trả chi tiết trường sai; không ghi run"
        case .unknownCapability: return ""
        case .apiVersion: return "Handshake"
        case .unauthorized: return ""
        case .outputSchema: return "Registry kiểm sau mỗi lời gọi"
        case .groundingFailed: return "Payload {exists[], candidates[], missing[]} để Orchestrator hỏi/dùng luôn"
        case .alreadyExists: return "Kèm phương án reuse|clone|new"
        case .policyAsk: return "gate_id"
        case .policyReject: return "rule, reason"
        case .stopped: return ""
        case .budgetExceeded: return ""
        case .toolFailed: return "ToolReport ref"
        case .toolMissing: return "Gợi ý env.install_tool"
        case .targetNotFound: return "Gợi ý discover.scan"
        case .chipIdMismatch: return "Leo thang"
        case .timeout: return ""
        case .modelError: return "Router fallback trước khi ném"
        case .contextOverflow: return "Báo cáo lớp"
        case .outputInvalid: return ""
        case .constantGuard: return "violations[]"
        case .storeIntegrity: return "Yêu cầu rebuild"
        case .schemaViolation: return ""
        case .conflict: return ""
        case .migrationRequired: return "eide migrate"
        case .undoExpired: return ""
        case .undoFailed: return "Leo thang"
        case .sandboxViolation: return "SEC-25"
        case .licenseBlocked: return ""
        case .sensitiveUpload: return ""
        }
    }
}

/// Số phương thức và mã lỗi lúc sinh — test hợp đồng đối chiếu với spec (API-15 §8).
public let eideSoPhuongThuc = 63
public let eideSoMaLoi = 29
