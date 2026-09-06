import AppKit
import GEditorCore
import WebKit

/// Biến mã Mermaid thành SVG — FR-MMD-001, NFR-MMD-03.
///
/// ## MỘT bộ render cho cả ba nơi
///
/// Sơ đồ xuất hiện ở ba chỗ: bảng Mermaid Studio, xem trước báo cáo `.greport.md`, và bản HTML
/// xuất ra. Cả ba đều đi qua lớp này, và cả ba nhận về **một chuỗi SVG**. Đó là quyết định
/// kiến trúc quan trọng nhất của cụm:
///
/// - Bảng báo cáo (`ReportPreviewView`) giữ nguyên lời hứa **không JavaScript** — nó chỉ nhận
///   SVG đã vẽ xong, không nhận thư viện nào chạy trong trang.
/// - Bản HTML xuất ra **tự chứa và nhúng SVG** đúng như FR-MMD-003 đòi, thay vì kèm 3,4 MB
///   mermaid.js và bắt máy người nhận chạy nó.
/// - In ra PDF **giữ vector**, vì thứ đi vào trang là SVG chứ không phải ảnh bitmap.
///
/// ## Không mạng, và điều đó đã được ĐO
///
/// NFR-MMD-03 đòi *"WKWebView sandboxed: không network"*. WebKit không có công tắc "tắt mạng",
/// nên hàng rào là `WKContentRuleList` chặn mọi URL. PoC-L (`scripts/run-poc-l.sh`) đã kiểm nó
/// **có đối chứng âm**: cùng một phép thử, bật hàng rào thì "BỊ CHẶN", tắt hàng rào thì "ĐI
/// ĐƯỢC" — nên chữ "BỊ CHẶN" ở đây là một kết luận, không phải một máy không có mạng.
///
/// ## Dựng LƯỜI, đúng một lần
///
/// NFR-MMD-01: *"WKWebView CHỈ khởi tạo khi mở preview lần đầu — khởi động app và RAM nghỉ không
/// đổi"*. PoC-L đo lần mở đầu tốn 830 ms và +35 MB RAM; cả hai chỉ xảy ra với người thật sự mở
/// một sơ đồ. Sau lần đầu, trang được GIỮ LẠI và mỗi lần vẽ chỉ là một lời gọi JavaScript — đó
/// là điều kiện để đạt vế *"cập nhật preview ≤ 500 ms"* của FR-MMD-002.
final class MermaidRenderer: NSObject {

    struct Diagram: Equatable {
        var index: Int
        var source: String

        init(index: Int, source: String) {
            self.index = index
            self.source = source
        }
    }

    struct Rendered: Equatable {
        var index: Int
        /// SVG đã vẽ. `nil` khi sơ đồ hỏng.
        var svg: String?
        /// Câu lỗi của mermaid, đã bỏ phần trang trí.
        var error: String?
        /// Dòng bị lỗi TRONG SƠ ĐỒ, 1-based. `nil` khi mermaid không nói được dòng.
        var line: Int?

        var isFailure: Bool { svg == nil }
    }

    enum Theme: String, CaseIterable {
        case light, dark, brand

        /// Tên theme của mermaid. `brand` dựng trên `base` rồi thay biến màu — đúng đường mà
        /// FR-MMD-007 nói (*"THEME BRAND tùy biến qua %%{init}%%"*).
        var mermaidName: String {
            switch self {
            case .light: return "default"
            case .dark: return "dark"
            case .brand: return "base"
            }
        }

        var vietnamese: String {
            switch self {
            case .light: return L("Sáng")
            case .dark: return L("Tối")
            case .brand: return L("Thương hiệu")
            }
        }
    }

    /// Lý do không dùng được — `nil` khi mọi thứ sẵn sàng.
    private(set) var failureReason: String?

    /// Người dùng bấm vào một phần tử trên sơ đồ — FR-MMD-002.
    ///
    /// Trả về CHỮ trên phần tử ấy chứ không phải `id` nội bộ của mermaid. Xem ghi chú ở
    /// `MermaidPanel.jumpToElement`.
    var onClickElement: ((_ diagramIndex: Int, _ text: String) -> Void)?

    /// Người dùng vừa làm một cử chỉ SOẠN trên hình — FR-KNW-915.
    ///
    /// `op` là `"edge"` (kéo từ node này sang node kia) hoặc `"label"` (double-click). Hai đối
    /// số là CHỮ trên phần tử, không phải tên node: chỗ nhận phải tự đổi qua
    /// `GraphEdit.resolveNode`, vì chỉ nó mới biết đồ thị nào đang mở.
    var onGraphEdit: ((_ op: String, _ from: String, _ to: String, _ index: Int) -> Void)?

    /// Bật/tắt soạn trực quan trong trang.
    ///
    /// Nhớ lại trạng thái ở đây chứ không chỉ ở bảng: trang được nạp LƯỜI, nên lần bật đầu tiên
    /// có thể xảy ra trước khi trang tồn tại — và khi ấy lời gọi JavaScript rơi vào khoảng không.
    var isVisualEditing = false {
        didSet { pushEditingFlag() }
    }

    private func pushEditingFlag() {
        guard isReady, let web else { return }
        web.evaluateJavaScript("window.__geditorSetEditing(\(isVisualEditing))")
    }

    /// Chính `WKWebView` — bảng Mermaid Studio gắn nó lên màn hình để hiện sơ đồ.
    ///
    /// Trả ra ngoài thay vì dựng một web view THỨ HAI để hiện: mỗi WKWebView tốn ~35 MB (PoC-L
    /// đo), và hai cái cho cùng một việc là trả hai lần. Nó cũng là điều kiện của FR-MMD-002 —
    /// bấm vào sơ đồ chỉ bắt được nếu thứ trên màn hình là chính trang đã vẽ ra nó.
    var displayView: NSView? { web }

    /// Trang đã nạp xong mermaid chưa.
    private(set) var isReady = false

    /// Số lượt vẽ đã hoàn tất — bài tự kiểm chờ theo con số này thay vì ngủ một khoảng cố định.
    private(set) var renderCount = 0

    private var web: WKWebView?
    private var pending: [([Rendered]) -> Void] = []
    private var queue: [(
        diagrams: [Diagram], theme: Theme, display: Bool, done: ([Rendered]) -> Void)] = []
    private var isRendering = false
    private var readyHandlers: [() -> Void] = []

    // MARK: - Dựng trang

    /// Dựng WKWebView và nạp mermaid. Gọi nhiều lần cũng chỉ dựng một lần.
    func prepare(_ then: (() -> Void)? = nil) {
        if isReady {
            then?()
            return
        }
        if let then { readyHandlers.append(then) }
        guard web == nil else { return }   // đang nạp dở

        guard let script = MermaidAsset.source() else {
            failureReason = MermaidAsset.failureReason
            finishReady()
            return
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(Bridge(owner: self), name: "geditor")
        // Hàng rào mạng phải có TRƯỚC khi trang nạp, nên trang chỉ được nạp trong callback.
        let rules = #"[{"trigger": {"url-filter": ".*"}, "action": {"type": "block"}}]"#
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: "geditor-mermaid-block-all", encodedContentRuleList: rules
        ) { [weak self] list, error in
            guard let self else { return }
            if let list {
                configuration.userContentController.add(list)
            } else {
                // Không dựng được hàng rào thì KHÔNG nạp trang.
                //
                // Cách khác — nạp trang rồi thôi — cho một sơ đồ vẫn vẽ ra, và người dùng không
                // có cách nào biết rằng cam kết "nội dung sơ đồ không rời máy" vừa mất hiệu lực.
                // Một tính năng không chạy thì thấy được; một hàng rào không chạy thì không.
                self.failureReason = L("không dựng được hàng rào chặn mạng cho WKWebView")
                    + (error.map { " (\($0.localizedDescription))" } ?? "")
                self.finishReady()
                return
            }
            self.load(script: script, configuration: configuration)
        }
    }

    private func load(script: String, configuration: WKWebViewConfiguration) {
        let view = WKWebView(frame: .zero, configuration: configuration)
        web = view
        // `baseURL: nil` → trang không có gốc để giải đường dẫn tương đối, tức không đọc được
        // tệp nào trên máy. Cùng lý do đã ghi ở `ReportPreviewView`.
        view.loadHTMLString(Self.page(script: script), baseURL: nil)
    }

    /// Trang chủ nhà: nạp mermaid MỘT lần, rồi chờ lệnh vẽ.
    ///
    /// `deterministicIds` bật: cùng một mã sơ đồ cho ra SVG giống hệt từng byte giữa hai lần
    /// chạy. Không có nó thì mỗi lần vẽ sinh một bộ `id` ngẫu nhiên, và một tệp `.greport.md`
    /// xuất ra hai lần cho hai tệp HTML khác nhau — `git diff` của thư mục báo cáo sẽ đầy những
    /// thay đổi không có nghĩa, đúng thứ NFR-MIN-02 gọi là "tái lập được".
    private static func page(script: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <style>
          html,body{margin:0;padding:0;background:transparent;
            font:14px -apple-system,"Helvetica Neue",sans-serif;color:#1a1a1a}
          #out{padding:14px}
          #sandbox{position:absolute;left:-99999px;top:0;visibility:hidden}
          figure{margin:0 0 20px}
          figure svg{max-width:100%;height:auto}
          .gm-error{margin:0 0 20px;padding:10px 12px;border-radius:6px;
            background:#fdf1ee;border:1px solid #e8b4a6;color:#7d2f16;
            font-family:ui-monospace,Menlo,monospace;font-size:12px;white-space:pre-wrap}
          .gm-caption{font-size:12px;color:#666;margin-top:4px}
          /* Phần tử ứng với dòng đang đứng con nháy — FR-MMD-002.
             Tô bằng VIỀN chứ không bằng nền: nền đè lên màu của node và người dùng mất thông
             tin mà chính sơ đồ đang mã hoá bằng màu. */
          .gm-hit > rect, .gm-hit > circle, .gm-hit > polygon, .gm-hit > path,
          .gm-hit > ellipse {
            stroke:#d97706 !important; stroke-width:3px !important;
          }
          .gm-hit { filter: drop-shadow(0 0 4px rgba(217,119,6,.55)); }
          /* Soạn trực quan — FR-KNW-915. Con trỏ đổi hình để cử chỉ KÉO thấy được: một thao
             tác chỉ có trong tài liệu là một thao tác không ai tìm ra. */
          body.gm-edit #out svg g { cursor: crosshair; }
          body.gm-edit .gm-drag > rect, body.gm-edit .gm-drag > circle,
          body.gm-edit .gm-drag > polygon, body.gm-edit .gm-drag > path,
          body.gm-edit .gm-drag > ellipse {
            stroke:#2563eb !important; stroke-width:3px !important; stroke-dasharray:5 3;
          }
          @media (prefers-color-scheme: dark) {
            html,body{color:#e8e8e8}
            .gm-error{background:#3a201a;border-color:#7d3f2c;color:#f0b5a2}
            .gm-caption{color:#aaa}
          }
        </style>
        <script>\(script)</script></head><body><div id="out"></div><div id="sandbox"></div>
        <script>
        (function () {
          // Chữ hiện cho người đọc đi từ Swift sang, KHÔNG viết thẳng vào JavaScript: mọi
          // chuỗi giao diện phải qua `L()` để bản tiếng Anh có nó, và cổng đếm nợ dịch trong
          // `check-core-no-ui.sh` soi cả tệp này.
          window.__geditorEmpty = \(jsString(
              "<p class=\"gm-caption\">" + L("Tài liệu chưa có khối mermaid nào.") + "</p>"));
          function send(o) { window.webkit.messageHandlers.geditor.postMessage(o); }
          function escapeHTML(s) {
            return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
              .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
          }
          var currentTheme = null;

          // Bấm vào sơ đồ → gửi CHỮ của phần tử về Swift (FR-MMD-002).
          //
          // Bắt ở `document` chứ không gắn vào từng node: SVG được thay mới sau mỗi lượt vẽ,
          // nên mọi handler gắn vào node cũ sẽ chết theo, và cái chết ấy im lặng.
          document.addEventListener('click', function (event) {
            var figure = event.target.closest ? event.target.closest('figure[data-index]') : null;
            if (!figure) { return; }
            var node = event.target.closest('.node, .nodeLabel, .actor, .task, .er, .statediagram-state, text, tspan, g');
            var text = node ? (node.textContent || '') : '';
            send({ kind: 'click', index: parseInt(figure.getAttribute('data-index'), 10),
                   text: text.trim().slice(0, 200) });
          }, true);

          // --- Soạn trực quan (FR-KNW-915) -----------------------------------------------
          //
          // TẮT mặc định, và bật bằng một công tắc thấy được. Không có công tắc thì mọi cú kéo
          // để bôi đen chữ trên sơ đồ đều thành một cạnh mới trong tệp của người dùng — một
          // thao tác họ không định làm, trên một tệp họ không nhìn thấy lúc ấy.
          var editing = false;
          var dragFrom = null, dragNode = null;

          function elementText(target) {
            var node = target.closest ? target.closest(
              '.node, .nodeLabel, .actor, .task, .er, .statediagram-state, text, tspan, g') : null;
            return node ? { node: node, text: (node.textContent || '').trim().slice(0, 200) }
                        : null;
          }

          window.__geditorSetEditing = function (on) {
            editing = !!on;
            document.body.classList.toggle('gm-edit', editing);
            clearDrag();
          };

          function clearDrag() {
            if (dragNode) { dragNode.classList.remove('gm-drag'); }
            dragFrom = null; dragNode = null;
          }

          document.addEventListener('mousedown', function (event) {
            if (!editing) { return; }
            if (!event.target.closest || !event.target.closest('figure[data-index]')) { return; }
            var hit = elementText(event.target);
            if (!hit || !hit.text) { return; }
            dragFrom = hit.text;
            dragNode = hit.node;
            dragNode.classList.add('gm-drag');
          }, true);

          document.addEventListener('mouseup', function (event) {
            if (!editing || dragFrom === null) { return; }
            var start = dragFrom;
            var hit = elementText(event.target);
            clearDrag();
            // Thả trên CHÍNH node vừa nhấn là một cú bấm, không phải một cú kéo — và một cạnh
            // tự trỏ vào mình gần như luôn là nhầm.
            if (!hit || !hit.text || hit.text === start) { return; }
            var figure = event.target.closest('figure[data-index]');
            if (!figure) { return; }
            send({ kind: 'graphedit', op: 'edge',
                   index: parseInt(figure.getAttribute('data-index'), 10),
                   from: start, to: hit.text });
          }, true);

          // Double-click → sửa nhãn. Đặc tả gọi đích danh cử chỉ này.
          document.addEventListener('dblclick', function (event) {
            if (!editing) { return; }
            var figure = event.target.closest ? event.target.closest('figure[data-index]') : null;
            if (!figure) { return; }
            var hit = elementText(event.target);
            if (!hit || !hit.text) { return; }
            send({ kind: 'graphedit', op: 'label',
                   index: parseInt(figure.getAttribute('data-index'), 10),
                   from: hit.text, to: '' });
          }, true);

          // Tô sáng phần tử ứng với dòng đang đứng con nháy — FR-MMD-002.
          //
          // So khớp theo CHỮ, cùng lý do với chiều ngược lại (bấm sơ đồ → con nháy): mermaid
          // không trả cây phân tích ra, nên chữ hiện trên phần tử là chỗ nối duy nhất còn lại.
          //
          // Chỉ giữ phần tử TRONG CÙNG: mọi `<g>` cha đều chứa chữ của con nó, nên không lọc
          // thì một dòng làm sáng cả sơ đồ.
          window.__geditorFocus = function (payload) {
            var words = JSON.parse(payload);
            var old = document.querySelectorAll('.gm-hit');
            for (var i = 0; i < old.length; i++) { old[i].classList.remove('gm-hit'); }
            if (!words.length) { return; }
            var groups = document.querySelectorAll('#out svg g');
            var hits = [];
            for (var i = 0; i < groups.length; i++) {
              var text = (groups[i].textContent || '').trim();
              if (!text) { continue; }
              for (var j = 0; j < words.length; j++) {
                if (text === words[j]) { hits.push(groups[i]); break; }
              }
            }
            for (var i = 0; i < hits.length; i++) {
              var inner = false;
              for (var j = 0; j < hits.length; j++) {
                if (i !== j && hits[i].contains(hits[j])) { inner = true; break; }
              }
              if (!inner) { hits[i].classList.add('gm-hit'); }
            }
          };

          window.__geditorRender = function (payload) {
            var request = JSON.parse(payload);
            // So bằng CHUỖI cấu hình, không so riêng tên theme: đổi màu thương hiệu mà giữ
            // nguyên `theme: 'base'` thì tên không đổi, và bản đầu bỏ qua lượt `initialize` —
            // người dùng sửa màu xong không thấy gì đổi.
            var signature = JSON.stringify([request.theme, request.themeVariables]);
            if (currentTheme !== signature) {
              currentTheme = signature;
              mermaid.initialize({
                startOnLoad: false,
                theme: request.theme,
                themeVariables: request.themeVariables || {},
                securityLevel: 'strict',
                deterministicIds: true,
                deterministicIDSeed: 'geditor',
                fontFamily: '-apple-system, "Helvetica Neue", sans-serif'
              });
            }
            var out = [];
            var chain = Promise.resolve();
            request.diagrams.forEach(function (item, position) {
              chain = chain.then(function () {
                // `id` theo vị trí trong LƯỢT VẼ, không theo chỉ số khối: hai khối cùng nội
                // dung phải cho hai phần tử khác nhau trong DOM, nếu không mermaid trả về SVG
                // của khối trước.
                return mermaid.render('gm' + request.pass + '_' + position, item.source)
                  .then(function (r) {
                    out.push({ index: item.index, svg: r.svg });
                  })
                  .catch(function (e) {
                    // Một sơ đồ hỏng KHÔNG được giết những sơ đồ khác — FR-MMD-001 đòi đúng
                    // câu ấy. Nên lỗi được BẮT tại đây rồi đi tiếp, chứ không ném ra ngoài
                    // chuỗi promise.
                    var line = null;
                    if (e && e.hash && typeof e.hash.line === 'number') { line = e.hash.line; }
                    var text = (e && e.message) ? String(e.message) : String(e);
                    var m = text.match(/[Pp]arse error on line (\\d+)/);
                    if (line === null && m) { line = parseInt(m[1], 10); }
                    out.push({ index: item.index, error: text, line: line });
                  });
              });
            });
            chain.then(function () {
              // mermaid chèn một thẻ lỗi vào cuối `body` khi sơ đồ hỏng. Không dọn thì sau vài
              // lần gõ sai, trang đầy những sơ đồ ma của các lần trước.
              var ghosts = document.querySelectorAll('body > div[id^="dgm"], body > svg[id^="dgm"]');
              for (var i = 0; i < ghosts.length; i++) { ghosts[i].remove(); }
              if (request.display) {
                out.sort(function (a, b) { return a.index - b.index; });
                var html = '';
                for (var i = 0; i < out.length; i++) {
                  var item = out[i];
                  if (item.svg) {
                    html += '<figure data-index="' + item.index + '">' + item.svg + '</figure>';
                  } else {
                    // Sơ đồ hỏng hiện thành một hộp lỗi TẠI CHỖ, giữ nguyên vị trí của nó
                    // trong dãy — sơ đồ khác trong cùng tệp vẫn vẽ (FR-MMD-001).
                    html += '<figure data-index="' + item.index + '"><div class="gm-error">'
                      + (item.line ? ('dòng ' + item.line + ': ') : '')
                      + escapeHTML(item.error || '') + '</div></figure>';
                  }
                }
                document.getElementById('out').innerHTML = html || window.__geditorEmpty;
              }
              send({ kind: 'rendered', pass: request.pass, results: out });
            });
          };
          send({ kind: 'ready', version: (mermaid && mermaid.version) ? mermaid.version() : '' });
        })();
        </script></body></html>
        """
    }

    // MARK: - Vẽ

    /// Vẽ một loạt sơ đồ. Gọi lại trên luồng chính.
    ///
    /// - Parameter display: `true` thì đổ luôn kết quả lên trang để bảng Mermaid Studio hiện.
    ///   `false` là đường của báo cáo — chỉ cần chuỗi SVG.
    /// Bộ màu áp cho theme `brand` — FR-MMD-007. `nil` = để mermaid dùng màu mặc định.
    var brand: MermaidBrand?

    func render(
        _ diagrams: [Diagram], theme: Theme = .light, display: Bool = false,
        completion: @escaping ([Rendered]) -> Void
    ) {
        guard !diagrams.isEmpty else {
            // Tài liệu không còn khối nào thì trang phải TRỐNG theo. Không dọn thì sơ đồ của
            // lần gõ trước ở lại trên màn hình và người dùng tưởng nó vẫn còn trong tệp.
            if display, isReady, let web {
                web.evaluateJavaScript(
                    "document.getElementById('out').innerHTML = window.__geditorEmpty")
            }
            return completion([])
        }
        queue.append((diagrams, theme, display, completion))
        prepare { [weak self] in self?.drain() }
    }

    private func drain() {
        guard !isRendering, isReady, let web, !queue.isEmpty else {
            // Không dựng được trang thì trả lời NGAY, và trả lời bằng lý do — chứ không để lời
            // gọi treo mãi. Một preview quay tròn vô hạn là cách tệ nhất để báo lỗi.
            if failureReason != nil {
                let stuck = queue
                queue.removeAll()
                for item in stuck {
                    item.done(item.diagrams.map {
                        Rendered(index: $0.index, svg: nil, error: failureReason, line: nil)
                    })
                }
            }
            return
        }
        // Chỉ giữ lượt vẽ MỚI NHẤT: người dùng gõ nhanh hơn mermaid vẽ, và vẽ đủ mọi trạng thái
        // trung gian là xếp hàng những kết quả không ai còn muốn xem.
        if queue.count > 1 {
            let dropped = queue.dropLast()
            queue = [queue[queue.count - 1]]
            for item in dropped { item.done([]) }
        }
        // Lấy `next` SAU khi bỏ bớt, không phải trước.
        //
        // Bản đầu bắt `next = queue.first` ngay ở dòng `guard`, tức TRƯỚC phép bỏ bớt — nên nó
        // vẽ đúng lượt vừa bị bỏ, còn lượt mới nhất nằm lại trong hàng đợi và khi kết quả về
        // thì `queue.removeFirst()` lấy nhầm nó ra rồi trao cho nó kết quả của lượt CŨ. Hậu quả
        // ở phía người dùng: sửa tài liệu trong lúc một lượt vẽ đang chạy thì preview đứng lại
        // ở nội dung cũ cho tới lần sửa sau — im lặng, và chỉ xảy ra khi gõ nhanh.
        //
        // Bắt được nhờ FR-MMD-008: sửa tệp `.mmd` rời trong lúc lượt vẽ sau khi tách còn đang
        // chạy, và sơ đồ không bao giờ đổi theo.
        let next = queue[0]
        isRendering = true
        pass += 1
        // `themeVariables` CHỈ đi cùng theme `brand`: mermaid áp chúng lên cả `default` và
        // `dark`, nên gửi kèm ở mọi theme sẽ làm hai lựa chọn kia mất màu riêng của chúng.
        var variables: [String: String] = [:]
        if next.theme == .brand, let brand {
            for pair in brand.themeVariables { variables[pair.key] = pair.value }
        }
        let payload: [String: Any] = [
            "pass": pass,
            "theme": next.theme.mermaidName,
            "themeVariables": variables,
            "display": next.display,
            "diagrams": next.diagrams.map { ["index": $0.index, "source": $0.source] },
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            isRendering = false
            return
        }
        // Truyền qua một chuỗi JSON đã thoát, KHÔNG nội suy mã sơ đồ thẳng vào JavaScript: nội
        // dung sơ đồ là văn bản của người dùng, và một dấu nháy trong nhãn node sẽ vừa phá câu
        // lệnh vừa mở đúng cái cửa mà `securityLevel: 'strict'` đang đóng.
        web.evaluateJavaScript(
            "window.__geditorRender(\(Self.jsString(json)))") { [weak self] _, error in
            guard let self, let error else { return }
            self.isRendering = false
            let stuck = self.queue
            self.queue.removeAll()
            for item in stuck {
                item.done(item.diagrams.map {
                    Rendered(index: $0.index, svg: nil,
                             error: error.localizedDescription, line: nil)
                })
            }
        }
    }

    /// Tô sáng phần tử mang một trong những chữ này; danh sách rỗng thì xoá hết tô sáng.
    ///
    /// Không đi qua hàng đợi vẽ: đây là một lời gọi JavaScript vài chục micro-giây trên trang
    /// ĐÃ có sẵn, còn hàng đợi tồn tại để bỏ bớt những lượt VẼ tốn kém. Xếp nó vào đó thì mỗi
    /// lần dời con nháy lại huỷ một lượt vẽ đang chạy.
    func focus(on words: [String]) {
        guard isReady, let web else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: words),
              let json = String(data: data, encoding: .utf8) else { return }
        lastFocus = words
        web.evaluateJavaScript("window.__geditorFocus(\(Self.jsString(json)))")
    }

    /// Chữ của lần tô sáng gần nhất — bài tự kiểm đọc để biết đã gửi đúng chưa.
    private(set) var lastFocus: [String] = []

    /// Diễn một cú KÉO thật trên trang: `mousedown` ở node này, `mouseup` ở node kia.
    ///
    /// Bài tự kiểm gọi hàm này chứ không gọi thẳng `onGraphEdit`. Khác biệt là cả giá trị của
    /// bài kiểm: gọi thẳng callback thì phần JavaScript — chỗ có công tắc `editing`, chỗ bỏ cú
    /// thả-tại-chỗ, chỗ đọc `data-index` — không hề được chạy, và một bài kiểm không chạy thứ
    /// nó nói mình kiểm thì luôn xanh.
    ///
    /// Trả về chữ mô tả kết quả tìm phần tử, để bài kiểm phân biệt "không tìm thấy node" với
    /// "đã gửi cử chỉ nhưng chỗ nhận bỏ qua".
    func dispatchDragForSelfTest(
        from: String, to: String, then: @escaping (String?) -> Void
    ) {
        guard isReady, let web else { return then("page not ready") }
        let script = """
        (function () {
          function find(want) {
            var groups = document.querySelectorAll('#out svg g');
            var best = null;
            for (var i = 0; i < groups.length; i++) {
              if ((groups[i].textContent || '').trim() !== want) { continue; }
              if (!best || best.contains(groups[i])) { best = groups[i]; }
            }
            return best;
          }
          var a = find(\(Self.jsString(from))), b = find(\(Self.jsString(to)));
          if (!a) { return 'không thấy node nguồn'; }
          if (!b) { return 'không thấy node đích'; }
          a.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
          b.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
          return 'đã gửi';
        })()
        """
        web.evaluateJavaScript(script) { value, error in
            then(value as? String ?? error?.localizedDescription)
        }
    }

    /// Diễn một cú BẤM thật trên trang — cùng lý do với `dispatchDragForSelfTest`.
    ///
    /// Đi qua chính bộ nghe `click` trong trang, nên nó chạy cả phép leo lên tìm phần tử mang
    /// `data-index` và phép rút chữ của phần tử. Gọi thẳng `onClickElement` thì hai phép ấy
    /// không chạy, và bài kiểm sẽ xanh cả khi trang không gửi gì.
    func dispatchClickForSelfTest(on text: String, then: @escaping (String?) -> Void) {
        guard isReady, let web else { return then("page not ready") }
        let script = """
        (function () {
          var groups = document.querySelectorAll('#out svg g');
          for (var i = 0; i < groups.length; i++) {
            if ((groups[i].textContent || '').trim() === \(Self.jsString(text))) {
              groups[i].dispatchEvent(new MouseEvent('click', { bubbles: true }));
              return 'đã gửi';
            }
          }
          return 'không thấy node';
        })()
        """
        web.evaluateJavaScript(script) { value, error in
            then(value as? String ?? error?.localizedDescription)
        }
    }

    /// Diễn một cú DOUBLE-CLICK thật trên trang — cùng lý do với `dispatchDragForSelfTest`.
    func dispatchDoubleClickForSelfTest(on text: String, then: @escaping (String?) -> Void) {
        guard isReady, let web else { return then("page not ready") }
        let script = """
        (function () {
          var groups = document.querySelectorAll('#out svg g');
          for (var i = 0; i < groups.length; i++) {
            if ((groups[i].textContent || '').trim() === \(Self.jsString(text))) {
              groups[i].dispatchEvent(new MouseEvent('dblclick', { bubbles: true }));
              return 'đã gửi';
            }
          }
          return 'không thấy node';
        })()
        """
        web.evaluateJavaScript(script) { value, error in
            then(value as? String ?? error?.localizedDescription)
        }
    }

    /// Đếm phần tử đang mang lớp tô sáng TRONG TRANG — móc cho bài tự kiểm.
    func countHighlighted(_ then: @escaping (Int?) -> Void) {
        guard isReady, let web else { return then(nil) }
        web.evaluateJavaScript("document.querySelectorAll('.gm-hit').length") { value, _ in
            then(value as? Int)
        }
    }

    /// CHỮ của những phần tử đang sáng — mạnh hơn phép đếm một bậc.
    ///
    /// Đếm chỉ trả lời "có bao nhiêu cái sáng", còn câu hỏi thật là "cái nào". Một tài liệu ba
    /// node mà tô nhầm sang node bên cạnh vẫn cho ra đúng con số 1. Và danh sách chữ ĐÃ GỬI thì
    /// không thay được cho câu trả lời này: nó chứa cả định danh (`B`, `C`) vốn không khớp phần
    /// tử nào, vì mermaid vẽ NHÃN chứ không vẽ định danh.
    func highlightedTexts(_ then: @escaping ([String]?) -> Void) {
        guard isReady, let web else { return then(nil) }
        let script = """
        Array.from(document.querySelectorAll('.gm-hit'))
             .map(function (e) { return (e.textContent || '').trim(); })
        """
        web.evaluateJavaScript(script) { value, _ in then(value as? [String]) }
    }

    private var pass = 0

    private func finishReady() {
        isReady = failureReason == nil
        let handlers = readyHandlers
        readyHandlers.removeAll()
        for handler in handlers { handler() }
        if failureReason != nil { drain() }
    }

    fileprivate func handle(message body: Any) {
        guard let object = body as? [String: Any],
              let kind = object["kind"] as? String else { return }
        switch kind {
        case "ready":
            version = object["version"] as? String
            finishReady()
            // Trang vừa có mặt: đẩy lại trạng thái soạn trực quan. Bật công tắc TRƯỚC khi mở
            // preview lần đầu là chuyện thường, và không có dòng này thì công tắc hiện "bật"
            // trong khi trang vẫn tắt.
            pushEditingFlag()
            drain()
        case "click":
            guard let index = object["index"] as? Int,
                  let text = object["text"] as? String, !text.isEmpty else { return }
            onClickElement?(index, text)

        case "graphedit":
            guard let op = object["op"] as? String,
                  let from = object["from"] as? String, !from.isEmpty else { return }
            onGraphEdit?(op, from, object["to"] as? String ?? "",
                         object["index"] as? Int ?? 0)

        case "rendered":
            isRendering = false
            let results = (object["results"] as? [[String: Any]] ?? []).map { entry in
                Rendered(
                    index: entry["index"] as? Int ?? 0,
                    svg: entry["svg"] as? String,
                    error: entry["error"] as? String,
                    line: entry["line"] as? Int)
            }
            renderCount += 1
            if let item = queue.first {
                queue.removeFirst()
                // Trả về theo ĐÚNG thứ tự khối trong tài liệu, không theo thứ tự vẽ xong.
                item.done(results.sorted { $0.index < $1.index })
            }
            drain()
        default:
            break
        }
    }

    /// Phiên bản mermaid mà chính trang báo về — để đối chiếu với bản kê (NFR-MMD-02).
    private(set) var version: String?

    static func jsString(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\u{2028}": out += "\\u2028"   // JS coi hai ký tự này là XUỐNG DÒNG
            case "\u{2029}": out += "\\u2029"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }

    /// Cầu nhận tin từ trang.
    ///
    /// Lớp riêng, giữ `owner` YẾU: `WKUserContentController` giữ chặt handler của nó, nên để
    /// `MermaidRenderer` tự làm handler là dựng một vòng giữ khiến cả `WKWebView` không bao giờ
    /// được giải phóng — đúng mẫu rò rỉ mà bộ chạy dài `--soak` sinh ra để bắt.
    private final class Bridge: NSObject, WKScriptMessageHandler {
        weak var owner: MermaidRenderer?
        init(owner: MermaidRenderer) { self.owner = owner }

        func userContentController(
            _ controller: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            owner?.handle(message: message.body)
        }
    }
}
