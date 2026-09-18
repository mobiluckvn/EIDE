import Foundation

/// **Danh mục màn hình — 6 nhóm, 25 màn.** Nguồn DUY NHẤT của điều hướng, tab và bảng lệnh.
///
/// Sao chép đúng bảng `NAV` của `docs/EIDE_UI_Demo_v2.html` và mục 8 của UXC-31. Bản cũ giữ ba
/// bản sao của danh sách này ở ba nơi, và cả ba đã lệch nhau ít nhất một lần.
public enum EideManHinhDS {

    public struct Man: Equatable {
        public let ma: String          // S1…S25 — mã trong UXC-31 §8
        public let tien: String        // tiền tố kỹ thuật, dùng cho `/lệnh` và tra năng lực
        public let nhan: String        // nhãn tiếng Việt hiện trên điều hướng và tab
        public let canBoard: Bool      // cần một vật ngoài máy tính
    }

    public struct Nhom: Equatable {
        public let ten: String
        public let cauHoi: String      // câu hỏi người dùng tự hỏi — lý do nhóm tồn tại
        public let man: [Man]
    }

    public static let nhom: [Nhom] = [
        .init(ten: "DỰ ÁN", cauHoi: "dự án tôi thế nào?", man: [
            .init(ma: "S1", tien: "Main", nhan: "Tổng quan", canBoard: false),
            .init(ma: "S2", tien: "NhatKy", nhan: "Nhật ký", canBoard: false),
            .init(ma: "S3", tien: "FlowMap", nhan: "Bản đồ luồng", canBoard: false),
        ]),
        .init(ten: "TRI THỨC", cauHoi: "máy biết gì, tin được không?", man: [
            .init(ma: "S4", tien: "Ingest", nhan: "Nhập tài liệu", canBoard: false),
            .init(ma: "S5", tien: "Passport", nhan: "Hộ chiếu chip", canBoard: false),
            .init(ma: "S6", tien: "Board", nhan: "Hộ chiếu mạch", canBoard: false),
            .init(ma: "S7", tien: "Graph", nhan: "Bản đồ tri thức & hỏi đáp", canBoard: false),
            .init(ma: "S8", tien: "XungDot", nhan: "Xung đột tri thức", canBoard: false),
        ]),
        .init(ten: "THIẾT KẾ", cauHoi: "làm cái gì, làm thế nào?", man: [
            .init(ma: "S9", tien: "LamRo", nhan: "Làm rõ yêu cầu", canBoard: false),
            .init(ma: "S10", tien: "ReqArch", nhan: "Yêu cầu & kiến trúc", canBoard: false),
            .init(ma: "S11", tien: "DiagramView", nhan: "Lược đồ", canBoard: false),
            .init(ma: "S12", tien: "PlanDiff", nhan: "Kế hoạch", canBoard: false),
            .init(ma: "S13", tien: "Doc", nhan: "Tài liệu", canBoard: false),
        ]),
        .init(ten: "MÃ NGUỒN", cauHoi: "mã đâu, merge được chưa?", man: [
            .init(ma: "S14", tien: "Code", nhan: "Trình soạn thảo", canBoard: false),
            .init(ma: "S15", tien: "DiffMerge", nhan: "Diff & cổng merge", canBoard: false),
        ]),
        .init(ten: "CHẠY THỬ", cauHoi: "chạy có đúng không?", man: [
            .init(ma: "S16", tien: "Sim", nhan: "Mô phỏng", canBoard: false),
            .init(ma: "S17", tien: "Discovery", nhan: "Dò board", canBoard: true),
            .init(ma: "S18", tien: "LogAssist", nhan: "Log & serial", canBoard: true),
            .init(ma: "S19", tien: "Debug", nhan: "Gỡ lỗi probe", canBoard: true),
            .init(ma: "S20", tien: "Bench", nhan: "Bench", canBoard: true),
        ]),
        .init(ten: "HỆ THỐNG", cauHoi: "công cụ, tiền, quyền", man: [
            .init(ma: "S21", tien: "Env", nhan: "Môi trường", canBoard: false),
            .init(ma: "S22", tien: "Models", nhan: "Mô hình & chi phí", canBoard: false),
            .init(ma: "S23", tien: "ToolForge", nhan: "Công cụ tự tạo", canBoard: false),
            .init(ma: "S24", tien: "Registry", nhan: "Registry", canBoard: false),
            .init(ma: "S25", tien: "ChinhSach", nhan: "Chính sách tự chủ", canBoard: false),
        ]),
    ]

    public static var tatCa: [Man] { nhom.flatMap(\.man) }

    public static func man(_ tien: String) -> Man? {
        tatCa.first { $0.tien == tien }
    }

    public static func nhan(_ tien: String) -> String {
        man(tien)?.nhan ?? tien
    }
}
