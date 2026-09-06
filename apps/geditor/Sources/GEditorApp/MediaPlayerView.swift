import AVFoundation
import AVKit
import AppKit
import GEditorCore

/// Khung phát nhạc và phim.
///
/// ## Dùng bộ phát của hệ điều hành — quyết định đã chốt 02/09/2026
///
/// Phương án libVLC được cân nhắc và **loại**. Nó phát được nhiều định dạng hơn hẳn — `.mkv`,
/// `.webm`, `.avi`, `.wmv` — và miễn phí về tiền, nhưng vướng đúng hai ràng buộc đã chốt của
/// dự án:
///
/// 1. **Giấy phép chặn đường App Store.** libVLC là LGPL-2.1+, và LGPL đòi người dùng cuối phải
///    liên kết lại được ứng dụng với một bản thư viện khác. Điều khoản App Store không cho phép
///    điều đó — chính VLC đã bị gỡ khỏi App Store vì đúng chuyện này. Mà lên App Store là mục
///    tiêu phát hành đã chốt của sản phẩm.
/// 2. **Cỡ bundle.** VLCKit là vài chục MB kèm hàng trăm plugin nạp lúc chạy, trong khi App
///    Sandbox cộng library validation cấm nạp dylib không cùng chữ ký. DuckDB đã tốn +94 MB;
///    khoản thứ hai cùng cỡ cho một tính năng phụ là một đánh đổi khác hẳn.
///
/// Cái giá của quyết định này phải nói ra, và nó nằm ngay trên màn hình: bốn định dạng kể trên
/// **không phát được**, và khung này nói thẳng lý do thay vì hiện một ô đen. Xem `showFallback`.
///
/// ## Không đoán bằng danh sách đuôi tệp
///
/// Câu "AVFoundation phát được `.mp4`" đúng cho phần lớn tệp `.mp4` và sai cho một tệp `.mp4`
/// chứa luồng AV1 trên máy cũ. Nên câu trả lời lấy từ **chính AVFoundation lúc chạy**
/// (`playable`), không lấy từ một bảng tra sẽ trôi khỏi thực tế theo từng bản macOS.
final class MediaPlayerView: NSView {

    var onStatus: ((String) -> Void)?
    /// Người dùng bấm "Xem nhị phân" trong khung không phát được.
    var onRequestHexView: (() -> Void)?

    private let playerView = AVPlayerView()
    private let fallback = NSStackView()
    private let fallbackTitle = NSTextField(labelWithString: "")
    private let fallbackDetail = NSTextField(labelWithString: "")
    private var player: AVPlayer?
    private var path = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        // Dừng hẳn khi khung biến mất. Không có dòng này thì đóng tab xong nhạc VẪN CHẠY, và
        // người dùng không còn cửa sổ nào để mà tắt nó.
        player?.pause()
    }

    /// Dừng phát — gọi khi tab đổi hoặc khung bị gỡ.
    func stop() {
        player?.pause()
        player = nil
        playerView.player = nil
    }

    private func build() {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        playerView.videoGravity = .resizeAspect

        fallback.translatesAutoresizingMaskIntoConstraints = false
        fallback.orientation = .vertical
        fallback.alignment = .centerX
        fallback.spacing = 10
        fallback.isHidden = true

        fallbackTitle.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        fallbackTitle.alignment = .center
        fallbackDetail.font = Tokens.Font.ui
        fallbackDetail.textColor = Tokens.Color.secondaryInk
        fallbackDetail.alignment = .center
        fallbackDetail.lineBreakMode = .byWordWrapping
        fallbackDetail.maximumNumberOfLines = 0
        fallbackDetail.preferredMaxLayoutWidth = 460

        let hexButton = NSButton(title: L("Xem nhị phân"), target: self,
                                 action: #selector(requestHexView))
        hexButton.bezelStyle = .rounded
        let openButton = NSButton(title: L("Mở bằng ứng dụng khác…"), target: self,
                                  action: #selector(openElsewhere))
        openButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [hexButton, openButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        fallback.addArrangedSubview(fallbackTitle)
        fallback.addArrangedSubview(fallbackDetail)
        fallback.addArrangedSubview(buttons)

        addSubview(playerView)
        addSubview(fallback)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fallback.centerXAnchor.constraint(equalTo: centerXAnchor),
            fallback.centerYAnchor.constraint(equalTo: centerYAnchor),
            fallback.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40),
        ])
    }

    // MARK: - Nạp

    func load(path: String, kind: MediaKind) {
        self.path = path
        stop()

        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        // API bất đồng bộ của macOS 12. Bản `load(_:)` gọn hơn nhiều nhưng chỉ có từ macOS 13,
        // mà sàn của sản phẩm là macOS 12 (NFR-PORT-02).
        asset.loadValuesAsynchronously(forKeys: ["playable", "duration", "tracks"]) {
            [weak self] in
            DispatchQueue.main.async {
                guard let self, self.path == path else { return }
                self.finishLoading(asset: asset, kind: kind)
            }
        }
    }

    private func finishLoading(asset: AVURLAsset, kind: MediaKind) {
        var error: NSError?
        let status = asset.statusOfValue(forKey: "playable", error: &error)
        guard status == .loaded, asset.isPlayable else {
            showFallback(kind: kind, reason: error?.localizedDescription)
            return
        }

        fallback.isHidden = true
        playerView.isHidden = false
        // Gác lời hứa "AVPlayerView vẫn lười" bằng một móc, không bằng một câu trong chú thích:
        // `LazyLoadAudit` so danh sách này với ảnh chụp lúc khởi động, nên một ngày nào đó có ai
        // vô tình dựng bộ phát ở đường khởi động thì cổng đỏ, chứ không phải người dùng phát hiện.
        LazyLoadAudit.activate("AVPlayer")
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        self.player = player
        playerView.player = player
        onStatus?(summary(of: asset, kind: kind))
    }

    /// Một dòng mô tả kỹ thuật cho thanh trạng thái.
    private func summary(of asset: AVURLAsset, kind: MediaKind) -> String {
        var parts: [String] = [kind.displayName]

        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite, seconds > 0 {
            parts.append(Self.durationText(seconds))
        }
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            parts.append("\(Int(abs(size.width)))×\(Int(abs(size.height)))")
            if track.nominalFrameRate > 0 {
                parts.append(String(format: "%.0f fps", track.nominalFrameRate))
            }
        }
        if let track = asset.tracks(withMediaType: .audio).first,
           let description = track.formatDescriptions.first {
            // swiftlint:disable:next force_cast
            let format = description as! CMFormatDescription
            if let basic = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee {
                parts.append(LF("%d kênh", Int(basic.mChannelsPerFrame)))
                if basic.mSampleRate > 0 {
                    parts.append(String(format: "%.1f kHz", basic.mSampleRate / 1000))
                }
            }
        }
        return parts.joined(separator: " · ")
    }

    static func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Không phát được

    /// Nói RA vì sao không phát được, và đưa hai đường đi tiếp.
    ///
    /// Một khung phát đen thui không có nút nào là cách hỏng tệ nhất: người dùng không biết tệp
    /// hỏng, máy thiếu bộ giải mã, hay ứng dụng lỗi.
    private func showFallback(kind: MediaKind, reason: String?) {
        playerView.isHidden = true
        player = nil
        playerView.player = nil
        fallback.isHidden = false

        let name = (path as NSString).lastPathComponent
        let ext = (path as NSString).pathExtension.uppercased()
        fallbackTitle.stringValue = LF("Không phát được «%@»", name)

        var lines: [String] = []
        lines.append(LF("macOS không có bộ giải mã sẵn cho định dạng %@ — đây là giới hạn của hệ điều hành, không phải tệp hỏng.",
                        ext.isEmpty ? kind.displayName : ext))
        if let reason, !reason.isEmpty { lines.append(reason) }
        lines.append(L("Nội dung tệp vẫn xem được ở chế độ nhị phân, hoặc mở bằng một ứng dụng có bộ giải mã riêng."))
        fallbackDetail.stringValue = lines.joined(separator: "\n\n")
        onStatus?(LF("Không phát được — %@", ext))
    }

    @objc private func requestHexView(_ sender: Any?) { onRequestHexView?() }

    @objc private func openElsewhere(_ sender: Any?) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: - Cửa cho bộ tự kiểm

    var isPlayingForSelfTest: Bool { (player?.rate ?? 0) > 0 }
    var hasPlayerForSelfTest: Bool { player != nil }
    var isFallbackVisibleForSelfTest: Bool { !fallback.isHidden }
    var fallbackTextForSelfTest: String { fallbackTitle.stringValue }

    func playForSelfTest() { player?.play() }
    func pauseForSelfTest() { player?.pause() }
}
