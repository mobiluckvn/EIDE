#!/bin/bash
# PoC-L — WKWebView cho Mermaid Studio (FR-MMD-001…008) có phá ADR-08 không?
#
#   scripts/run-poc-l.sh
#   GEDITOR_MERMAID_JS=/đường/dẫn/mermaid.min.js scripts/run-poc-l.sh
#
# VÌ SAO CÓ PoC NÀY. Khi làm Markdown preview (FR-FMT-506) ta CỐ Ý không dùng WebView, và lý do
# ghi thẳng trong `docs/trang-thai.md` §4: "nạp WebKit kéo cả một engine trình duyệt vào tiến
# trình, đúng thứ ADR-08 đang gỡ khỏi đường khởi động". FR-MMD-001 thì BẮT BUỘC mermaid.js chạy
# trong WKWebView sandboxed. Hai quyết định ấy không thể cùng đúng nếu không đo.
#
# NFR-MMD-01 đã tự đặt điều kiện thoát: "WKWebView CHỈ khởi tạo khi mở preview lần đầu — khởi
# động app và RAM nghỉ không đổi (đo trong CI so baseline)". Nên câu hỏi thật không phải "WebKit
# nặng bao nhiêu" mà là **"nặng ở ĐÂU"**: lúc khởi động, hay lúc người dùng bấm mở preview?
#
# Bốn câu hỏi, mỗi câu một phép đo:
#
#   1. `import WebKit` (liên kết lúc nạp) tốn bao nhiêu ms trước `main()`?   ← câu chặn ADR-08
#   2. Nếu nạp LƯỜI bằng dlopen thì trước `main()` tốn bao nhiêu, và lần đầu dùng tốn bao nhiêu?
#   3. Mở preview lần đầu + render sơ đồ 500 node có ≤ 2 giây không, và RAM tăng bao nhiêu?
#   4. WKWebView có CHẶN được mạng thật không (NFR-MMD-03, NFR-SEC-02)? — có đối chứng âm.
#
# CỐ Ý KHÔNG vendor gì vào kho: mermaid.min.js tải về `.build/poc-l/`, ngoài git.
set -uo pipefail
cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
CACHE=".build/poc-l"
RESULT="benchmarks/results/poc-l-${ARCH}.json"
MERMAID_VERSION="11.4.1"
RUNS=15
mkdir -p "$CACHE" benchmarks/results

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ PoC-L — WKWebView cho Mermaid Studio có phá ADR-08 không?"
echo

# ============================================================================================
# 0. mermaid.js
# ============================================================================================
MERMAID="${GEDITOR_MERMAID_JS:-$CACHE/mermaid.min.js}"
if [ ! -f "$MERMAID" ]; then
    echo "0. Tải mermaid@${MERMAID_VERSION} về $CACHE (một lần)…"
    URL="https://cdn.jsdelivr.net/npm/mermaid@${MERMAID_VERSION}/dist/mermaid.min.js"
    curl -sSL -m 300 -o "$MERMAID" "$URL" || { echo "   ❌ không tải được"; exit 1; }
fi
MERMAID_MB=$(python3 -c "import os;print('%.2f'%(os.path.getsize('$MERMAID')/1048576))")
echo "   mermaid.min.js ${MERMAID_MB} MB — FR-MMD-001 đòi ĐÓNG GÓI OFFLINE, không CDN"
echo

# ============================================================================================
# 1 + 2. Giá của WebKit TRƯỚC main()
# ============================================================================================
#
# Đo đúng đại lượng mà `StartupProbe.preMainMs` của app đo: từ lúc NHÂN tạo tiến trình tới dòng
# đầu của `main()`. Phần ấy là dyld nạp và liên kết framework — mã của ta chưa chạy dòng nào,
# nên nó là giá phải trả ở MỌI lần mở app, kể cả khi người dùng không bao giờ mở preview.
echo "1+2. WebKit tốn bao nhiêu TRƯỚC main() — liên kết lúc nạp vs nạp lười"
cat > "$WORK/pre.c" <<'EOF'
#include <stdio.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <unistd.h>
#include <dlfcn.h>
#include <mach/mach_time.h>

// Cùng phương pháp với StartupProbe.processStartTime(): hỏi NHÂN, không đo từ main().
static double ms_since_launch(void) {
    struct kinfo_proc info;
    size_t size = sizeof(info);
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return -1;
    struct timeval now;
    gettimeofday(&now, NULL);
    return (double)(now.tv_sec - info.kp_proc.p_starttime.tv_sec) * 1000.0
         + ((double)now.tv_usec - (double)info.kp_proc.p_starttime.tv_usec) / 1000.0;
}

int main(int argc, char **argv) {
    double pre = ms_since_launch();
    double lazy = -1;
    if (argc > 1 && argv[1][0] == 'l') {
        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        uint64_t t0 = mach_absolute_time();
        void *h = dlopen("/System/Library/Frameworks/WebKit.framework/WebKit", RTLD_LAZY);
        uint64_t t1 = mach_absolute_time();
        lazy = h ? (double)(t1 - t0) * tb.numer / tb.denom / 1e6 : -1;
    }
    printf("{\"preMainMs\": %.2f, \"lazyDlopenMs\": %.2f}\n", pre, lazy);
    return 0;
}
EOF

# `base` và `linked` khác nhau ĐÚNG một thứ: -framework WebKit. Mọi thứ khác giữ nguyên, nếu
# không thì phép so đo lẫn cả những khác biệt khác.
clang -O2 -framework Foundation -framework AppKit -o "$WORK/base" "$WORK/pre.c" 2>/dev/null
clang -O2 -framework Foundation -framework AppKit -framework WebKit \
    -o "$WORK/linked" "$WORK/pre.c" 2>/dev/null
cp "$WORK/base" "$WORK/lazy"
for f in base linked lazy; do
    [ -f "$WORK/$f" ] || { echo "   ❌ không biên dịch được $f"; exit 1; }
    codesign -f -s - "$WORK/$f" 2>/dev/null
done

# Mỗi lần đo là một BẢN SAO MỚI — đúng cách run-startup-kpi.sh mô phỏng "nguội". Chạy lại chính
# một file thì nó đã nằm trong page cache và con số nói về lần thứ hai, không phải lần đầu.
measure() {   # $1 = tên binary · $2 = tham số
    local out=""
    for i in $(seq 1 "$RUNS"); do
        cp "$WORK/$1" "$WORK/$1-$i"
        out="$out $("$WORK/$1-$i" ${2:-} 2>/dev/null)"
        rm -f "$WORK/$1-$i"
    done
    echo "$out"
}
BASE_JSON="$(measure base)"
LINKED_JSON="$(measure linked)"
LAZY_JSON="$(measure lazy lazy)"
echo

# ============================================================================================
# 3 + 4. Mở preview lần đầu, render, RAM, và chặn mạng
# ============================================================================================
echo "3+4. Mở preview lần đầu · render 500 node · RAM · chặn mạng"
cat > "$WORK/preview.swift" <<'SWIFT'
import AppKit
import WebKit
import Darwin

// Đo ĐÚNG thứ người dùng chờ: từ lúc quyết định mở preview tới lúc sơ đồ hiện ra. Không đo
// riêng "khởi tạo WKWebView" rồi kết luận, vì WKWebView khởi tạo xong vẫn chưa vẽ gì cả —
// tiến trình WebContent dựng ở phía sau và JS chưa chạy.

func rssMB() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : -1
}

func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000 }

let mermaidPath = CommandLine.arguments[1]
let mermaidSource = (try? String(contentsOfFile: mermaidPath, encoding: .utf8)) ?? ""

// Sơ đồ 500 node — đúng cỡ NFR-MMD-01 nói tới.
var big = "flowchart TD\n"
for i in 0 ..< 500 {
    big += "  n\(i)[\"Nút \(i)\"]\n"
    if i > 0 { big += "  n\(i - 1) --> n\(i)\n" }
}
let small = "flowchart LR\n  A[Bắt đầu] --> B{Kiểm tra}\n  B -->|đúng| C[Xong]\n  B -->|sai| A\n"

final class Harness: NSObject, WKScriptMessageHandler {
    var results: [String: Any] = [:]
    var web: WKWebView!
    var startedAt = 0.0
    let blockNetwork: Bool
    init(blockNetwork: Bool) { self.blockNetwork = blockNetwork }

    func begin() {
        results["rssBeforeMB"] = rssMB()

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "poc")
        // NFR-MMD-03: không JS ngoài bundle, không mạng. Không có API "tắt mạng" nên chặn bằng
        // content rule list — và mục 4 dưới đây kiểm rằng nó chặn THẬT, có đối chứng âm.
        //
        // Biên dịch BẤT ĐỒNG BỘ. Bản đầu của bộ đo này chờ bằng DispatchSemaphore ngay trên
        // main queue, mà callback của WebKit cũng về main queue — nên nó tự khoá chính mình
        // đúng 10 giây rồi hết hạn, và con số "tới lúc sơ đồ hiện ra" báo 11 GIÂY. Sai số ấy
        // không trông giống lỗi: nó trông giống một kết luận.
        guard blockNetwork else { proceed(config: config, compileMs: 0); return }
        let rules = """
        [{"trigger": {"url-filter": ".*"}, "action": {"type": "block"}}]
        """
        let t0 = now()
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: "poc-l-block-all", encodedContentRuleList: rules
        ) { [weak self] list, _ in
            guard let self else { return }
            if let list { config.userContentController.add(list) }
            self.results["ruleListCompiled"] = (list != nil)
            self.proceed(config: config, compileMs: now() - t0)
        }
    }

    /// Đồng hồ của mục 3 bắt đầu Ở ĐÂY, không phải ở `begin()`.
    ///
    /// Biên dịch content rule list là chi phí MỘT LẦN của cả máy — `WKContentRuleListStore`
    /// giữ lại bản đã biên dịch giữa các lần chạy app, nên tính nó vào "thời gian mở preview"
    /// là tính cho người dùng một khoản họ chỉ trả một lần trong đời. Ghi riêng ra một cột.
    func proceed(config: WKWebViewConfiguration, compileMs: Double) {
        results["ruleListCompileMs"] = compileMs
        startedAt = now()
        let t0 = now()
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1200, height: 900), configuration: config)
        results["allocWebViewMs"] = now() - t0
        results["rssAfterAllocMB"] = rssMB()

        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>body{margin:0}</style>
        <script>\(mermaidSource)</script></head><body><div id="out"></div><script>
        (function () {
          function send(o) { window.webkit.messageHandlers.poc.postMessage(o); }
          try {
            mermaid.initialize({ startOnLoad: false });
            var t0 = performance.now();
            mermaid.render('g1', \(jsString(small))).then(function (r) {
              var tSmall = performance.now() - t0;
              document.getElementById('out').innerHTML = r.svg;
              var t1 = performance.now();
              return mermaid.render('g2', \(jsString(big))).then(function (r2) {
                var tBig = performance.now() - t1;
                var nodes = (r2.svg.match(/class="node/g) || []).length;
                // Đối chứng mạng: tải một ẢNH ra ngoài, KHÔNG dùng fetch.
                //
                // Bản đầu dùng fetch() và cho "BỊ CHẶN" ở CẢ HAI lượt — vì trang nạp bằng
                // loadHTMLString(baseURL: nil) có origin null, nên CORS chặn fetch bất kể có
                // hàng rào hay không. Một phép đo luôn cho cùng một chữ thì nó không đo gì.
                // <img> không đi qua CORS nên nó phân biệt được hai trường hợp.
                var done = false;
                function finish(state) {
                  if (done) return; done = true;
                  send({ ok: true, small: tSmall, big: tBig, nodes: nodes, net: state });
                }
                var probe = new Image();
                probe.onload = function () { finish('ĐI ĐƯỢC'); };
                probe.onerror = function () { finish('BỊ CHẶN'); };
                setTimeout(function () { finish('HẾT GIỜ'); }, 15000);
                probe.src = 'https://www.google.com/favicon.ico?poc-l=' + Date.now();
              });
            }).catch(function (e) { send({ ok: false, error: String(e) }); });
          } catch (e) { send({ ok: false, error: String(e) }); }
        })();
        </script></body></html>
        """
        results["htmlBytes"] = html.utf8.count
        let tLoad = now()
        results["loadStartedAt"] = tLoad
        web.loadHTMLString(html, baseURL: nil)
    }

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        results["firstPaintMs"] = now() - startedAt
        results["rssAfterRenderMB"] = rssMB()
        if let body = message.body as? [String: Any] {
            for (k, v) in body { results[k] = v }
        }
        emit()
        exit(0)
    }

    func emit() {
        let data = try! JSONSerialization.data(withJSONObject: results, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

func jsString(_ s: String) -> String {
    let data = try! JSONSerialization.data(withJSONObject: [s], options: [])
    var text = String(decoding: data, as: UTF8.self)
    text.removeFirst(); text.removeLast()
    return text
}

let block = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "block"
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let harness = Harness(blockNetwork: block)
DispatchQueue.main.async { harness.begin() }
DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
    harness.results["ok"] = false
    harness.results["error"] = "quá 60 giây"
    harness.emit()
    exit(1)
}
app.run()
SWIFT

swiftc -O -o "$WORK/preview" "$WORK/preview.swift" 2>"$WORK/swiftc.log"
if [ ! -f "$WORK/preview" ]; then
    echo "   ❌ không biên dịch được bộ đo preview:"; head -20 "$WORK/swiftc.log"; exit 1
fi
codesign -f -s - "$WORK/preview" 2>/dev/null

BLOCKED_JSON="$("$WORK/preview" "$MERMAID" block 2>/dev/null)"
OPEN_JSON="$("$WORK/preview" "$MERMAID" 2>/dev/null)"
echo

# ============================================================================================
# Tổng hợp
# ============================================================================================
python3 - "$RESULT" <<PY
import json, statistics, sys

def runs(raw):
    decoder = json.JSONDecoder()
    out, i = [], 0
    while True:
        i = raw.find("{", i)
        if i < 0:
            return out
        try:
            value, end = decoder.raw_decode(raw, i)
        except ValueError:
            i += 1; continue
        out.append(value); i = end

base = [r["preMainMs"] for r in runs("""$BASE_JSON""") if r.get("preMainMs", -1) >= 0]
linked = [r["preMainMs"] for r in runs("""$LINKED_JSON""") if r.get("preMainMs", -1) >= 0]
lazy_runs = runs("""$LAZY_JSON""")
lazy_pre = [r["preMainMs"] for r in lazy_runs if r.get("preMainMs", -1) >= 0]
lazy_open = [r["lazyDlopenMs"] for r in lazy_runs if r.get("lazyDlopenMs", -1) >= 0]

def med(xs): return statistics.median(xs) if xs else None

print("  ── 1+2. Trước main(): giá phải trả ở MỌI lần mở app ──")
rows = [
    ("KHÔNG có WebKit (mốc)", base),
    ("-framework WebKit (= import WebKit)", linked),
    ("chỉ AppKit, WebKit nạp lười", lazy_pre),
]
for label, xs in rows:
    if xs:
        print("    %-38s min %6.1f ms   trung vị %6.1f ms" % (label, min(xs), med(xs)))
    else:
        print("    %-38s (không đo được)" % label)
delta = (med(linked) - med(base)) if base and linked else None

# THƯỚC ĐO NHIỄU, có sẵn mà không phải dựng thêm gì: binary "lazy" là BẢN SAO Y HỆT của
# "base" — cùng byte, chỉ khác tham số dòng lệnh. Nên chênh lệch giữa hai cột ấy KHÔNG thể là
# hiệu ứng của WebKit; nó là nhiễu của chính phép đo. Không có con số này thì "+6,9 ms" đọc
# như một kết luận, trong khi nó có thể nhỏ hơn sai số.
noise = abs(med(lazy_pre) - med(base)) if base and lazy_pre else None
if noise is not None:
    print()
    print("    sàn nhiễu (lazy là BẢN SAO của base, chênh lệch này chỉ có thể là nhiễu): %.1f ms"
          % noise)
if delta is not None:
    print()
    print("    → LIÊN KẾT WebKit đắt thêm %+.1f ms trước main()" % delta)
    if noise is not None and delta <= noise * 2:
        print("      CHƯA PHÂN BIỆT ĐƯỢC VỚI NHIỄU (sàn nhiễu %.1f ms) — kết luận đúng là"
              " 'không quá ~%.0f ms', không phải con số chính xác ở trên." % (noise, delta + noise))
    print("      Ngân sách ADR-08 còn lại: 500 − 465 = 35 ms.")
    print("      %s" % ("VỪA — nhưng ăn %.0f%% ngân sách còn lại" % (delta / 35 * 100)
                        if delta <= 35 else "KHÔNG VỪA — vượt cả phần ngân sách còn lại"))
if lazy_open:
    print("    → NẠP LƯỜI: trước main() KHÔNG tốn gì; dlopen lúc dùng lần đầu"
          " %.1f ms (trung vị)" % med(lazy_open))

blocked = json.loads('''$BLOCKED_JSON''' or "{}")
opened = json.loads('''$OPEN_JSON''' or "{}")

print()
print("  ── 3. Mở preview lần đầu (WKWebView + mermaid + render) ──")
if blocked.get("ok"):
    print("    dựng WKWebView                    %8.1f ms" % blocked["allocWebViewMs"])
    print("    tới lúc sơ đồ đầu tiên hiện ra    %8.1f ms   ← thứ người dùng chờ" % blocked["firstPaintMs"])
    print("    render sơ đồ 500 node             %8.1f ms   (trần NFR-MMD-01: 2000 ms)"
          % blocked["big"])
    print("    đếm được %d node trong SVG — bằng chứng nó VẼ THẬT chứ không trả chuỗi rỗng"
          % blocked.get("nodes", -1))
    print("    RAM: %.1f MB → %.1f MB (sau khi dựng) → %.1f MB (sau khi render)"
          % (blocked["rssBeforeMB"], blocked["rssAfterAllocMB"], blocked["rssAfterRenderMB"]))
    print("    tăng thêm %+.1f MB — chỉ tính KHI đã mở preview; NFR-PERF-05 nói về RAM NGHỈ"
          % (blocked["rssAfterRenderMB"] - blocked["rssBeforeMB"]))
else:
    print("    ❌ không render được: %s" % blocked.get("error", "?"))

print()
print("  ── 4. Chặn mạng (NFR-MMD-03 · NFR-SEC-02) — có đối chứng âm ──")
print("    CÓ content rule list chặn:    fetch ra ngoài %s" % blocked.get("net", "?"))
print("    KHÔNG chặn (đối chứng âm):    fetch ra ngoài %s" % opened.get("net", "?"))
control_ok = blocked.get("net") == "BỊ CHẶN" and opened.get("net") == "ĐI ĐƯỢC"
if control_ok:
    print("    → Bài đo tự chứng minh nó đo được: bỏ hàng rào ra thì mạng ĐI ĐƯỢC ngay.")
elif blocked.get("net") == "BỊ CHẶN":
    print("    ⚠️  đối chứng âm KHÔNG kết luận được (máy này có thể đang không có mạng)")
    print("       — 'BỊ CHẶN' ở dòng trên chưa chứng minh hàng rào có tác dụng.")

report = {
  "poc": "PoC-L — WKWebView cho Mermaid Studio (FR-MMD)",
  "architecture": "$ARCH",
  "mermaidVersion": "$MERMAID_VERSION",
  "mermaidMB": float("$MERMAID_MB"),
  "preMain": {"baseMs": base, "linkedMs": linked, "lazyMs": lazy_pre,
              "lazyDlopenMs": lazy_open, "linkDeltaMedianMs": delta,
              "noiseFloorMs": noise},
  "firstOpen": blocked,
  "networkControl": {"withBlocker": blocked.get("net"), "withoutBlocker": opened.get("net"),
                     "controlConclusive": control_ok},
  "notes": [
    "Giá của WebKit đo TRƯỚC main() bằng đúng phương pháp StartupProbe dùng (hỏi nhân qua"
    " kinfo_proc), nên nó so được với ngân sách 465/500 ms của ADR-08.",
    "Ba binary chỉ khác nhau ĐÚNG một cờ -framework WebKit; mỗi lần đo là một bản sao mới để"
    " mô phỏng 'nguội' như run-startup-kpi.sh.",
    "RAM tăng thêm chỉ xảy ra KHI người dùng mở preview. NFR-PERF-05 (80 MB) nói về RAM NGHỈ,"
    " nên con số ấy không đụng chỉ tiêu — miễn là WKWebView khởi tạo lười.",
    "Đối chứng âm của mục 4 cần máy CÓ mạng; không có mạng thì kết quả 'BỊ CHẶN' không chứng"
    " minh được điều gì và báo cáo phải nói ra như vậy.",
  ],
}
json.dump(report, open(sys.argv[1], "w"), ensure_ascii=False, indent=2, sort_keys=True)

print()
print("▸ Kết luận cần anh đọc")
if delta is not None:
    if delta > 35:
        print("  1. KHÔNG được dùng 'import WebKit' ở GEditorApp: đắt thêm %.0f ms trước main(),"
              " vượt cả 35 ms ngân sách ADR-08 còn lại." % delta)
    else:
        print("  1. 'import WebKit' đắt thêm %.0f ms trước main() — vừa ngân sách 35 ms còn"
              " lại của ADR-08, nhưng ăn %.0f%% của nó." % (delta, delta / 35 * 100))
if lazy_open:
    print("  2. Nạp LƯỜI thì trước main() không tốn gì, và lần đầu dùng tốn %.0f ms."
          " Đây là hình dạng NFR-MMD-01 đã đặt điều kiện." % med(lazy_open))
if blocked.get("ok"):
    verdict = "ĐẠT" if blocked["big"] <= 2000 else "KHÔNG ĐẠT"
    print("  3. Sơ đồ 500 node render %.0f ms — %s so trần 2 giây của NFR-MMD-01."
          % (blocked["big"], verdict))
    print("     Lần mở đầu tiên tốn %.0f ms và +%.0f MB RAM, và chỉ tốn KHI mở."
          % (blocked["firstPaintMs"], blocked["rssAfterRenderMB"] - blocked["rssBeforeMB"]))
print("  4. Chặn mạng: %s" % ("chặn được, và đối chứng âm chứng minh hàng rào có tác dụng"
      if control_ok else "chưa kết luận được — xem mục 4 ở trên"))
print()
print("  Ghi ở: $RESULT")
PY
