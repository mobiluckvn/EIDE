import Foundation
import GEditorSIMD

/// Thông tin phiên bản và môi trường chạy của lõi.
///
/// `GEditorCore` KHÔNG được import AppKit/SwiftUI/UIKit (NFR-MNT-01) — quy tắc này
/// được `scripts/check-core-no-ui.sh` kiểm tra và CI chặn merge khi vi phạm.
public enum GEditorCore {
    /// Semantic versioning (NFR-MNT-04).
    public static let version = "0.0.1"

    /// Kiến trúc CPU của tiến trình đang chạy.
    public static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    /// Nhánh mã SIMD được chọn tại runtime — "neon" trên Apple Silicon, "avx2"/"scalar"
    /// trên Intel. Hiện ở About và log chẩn đoán để xác nhận đúng nhánh (NFR-PORT-01).
    public static var simdBackend: String {
        String(cString: geditor_simd_backend())
    }

    /// Dòng đầu tiên trong log. Có kênh phát hành ở đây vì đó là thứ đầu tiên cần biết khi đọc
    /// một báo lỗi: bản App Store và bản trực tiếp khác nhau về sandbox, và rất nhiều triệu
    /// chứng "không mở được file" chỉ xảy ra ở một trong hai.
    public static var diagnosticSummary: String {
        "GEditor \(version) · \(architecture) · SIMD: \(simdBackend) · \(Distribution.current.displayName)"
    }
}
