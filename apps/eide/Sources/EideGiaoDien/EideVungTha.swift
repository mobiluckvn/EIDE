import AppKit
import EideLoi

/// **Vùng kéo-thả tệp.** UXC-31 §8 S4.
///
/// Một ô viền đứt, và nó là cả giao diện của bước đầu tiên trong đời một dự án: người ta có sẵn
/// datasheet trong Finder, và thứ tự nhiên nhất là kéo nó vào. Không có ô này thì bước ấy phải
/// đi qua một hộp thoại chọn tệp — thêm ba cú bấm cho việc người dùng làm nhiều lần nhất.
@MainActor
public final class EideVungTha: NSView {

    /// Người thả tệp vào. Đường dẫn TUYỆT ĐỐI, vì lõi chạy trong một tiến trình khác với thư
    /// mục làm việc khác.
    public var onTha: (([String]) -> Void)?

    private let nhan = NSTextField(labelWithString: "")
    private var dangKeo = false { didSet { _veLai() } }

    public init(loiMoi: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = EideToken.radius[1]
        nhan.stringValue = loiMoi
        nhan.font = EideToken.fontUI
        nhan.alignment = .center
        nhan.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nhan)
        NSLayoutConstraint.activate([
            nhan.centerXAnchor.constraint(equalTo: centerXAnchor),
            nhan.centerYAnchor.constraint(equalTo: centerYAnchor),
            nhan.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            heightAnchor.constraint(equalToConstant: 84),
        ])
        registerForDraggedTypes([.fileURL])
        _veLai()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    /// Viền đứt vẽ bằng `CAShapeLayer` chứ không bằng `layer.borderWidth` — AppKit không có
    /// viền đứt sẵn, và một ô viền liền trông như một khung trang trí chứ không như một chỗ
    /// thả được.
    private var vien: CAShapeLayer?

    public override func layout() {
        super.layout()
        vien?.removeFromSuperlayer()
        let v = CAShapeLayer()
        v.path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                        cornerWidth: EideToken.radius[1], cornerHeight: EideToken.radius[1],
                        transform: nil)
        v.fillColor = nil
        v.lineWidth = dangKeo ? 2 : 1
        v.lineDashPattern = [5, 4]
        v.strokeColor = (dangKeo ? EideToken.Mau.primary : EideToken.Mau.border2).cgColor
        layer?.addSublayer(v)
        vien = v
    }

    private func _veLai() {
        layer?.backgroundColor = (dangKeo ? EideToken.Mau.okBg : EideToken.Mau.surface).cgColor
        nhan.textColor = dangKeo ? EideToken.Mau.text : EideToken.Mau.muted
        needsLayout = true
    }

    // MARK: - nhận thả

    public override func draggingEntered(_ s: any NSDraggingInfo) -> NSDragOperation {
        dangKeo = !Self.duongDan(s).isEmpty
        return dangKeo ? .copy : []
    }

    public override func draggingExited(_ s: (any NSDraggingInfo)?) { dangKeo = false }

    public override func performDragOperation(_ s: any NSDraggingInfo) -> Bool {
        dangKeo = false
        let ds = Self.duongDan(s)
        guard !ds.isEmpty else { return false }
        onTha?(ds)
        return true
    }

    /// Đường dẫn TỆP trong một thao tác kéo. Thư mục bị bỏ: `ingest.classify` đọc chữ ký ở
    /// byte đầu của một tệp, nên một thư mục đi vào đó sẽ thành `unknown` kèm lý do vô nghĩa.
    public static func duongDan(_ s: any NSDraggingInfo) -> [String] {
        let ds = s.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return ds.filter { u in
            var thuMuc: ObjCBool = false
            let co = FileManager.default.fileExists(atPath: u.path, isDirectory: &thuMuc)
            return co && !thuMuc.boolValue
        }.map(\.path)
    }

    /// Cho test đẩy tệp vào mà không cần dựng một thao tác kéo thật của AppKit.
    public func thaDeTest(_ ds: [String]) { onTha?(ds) }
}
