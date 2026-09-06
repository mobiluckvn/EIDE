#!/bin/bash
# Độ phủ của TẦNG APP — câu hỏi mà `run-coverage.sh` cố ý không trả lời.
#
#   scripts/run-app-coverage.sh              đo và áp cổng chốt
#   scripts/run-app-coverage.sh --report     in bảng theo từng file, không áp cổng
#
# ## Vì sao có script thứ hai thay vì gộp vào cái đã có
#
# `run-coverage.sh` chỉ đo `GEditorCore`, và nó nói rõ lý do: lớp app không chạy dưới
# `swift test` — nó cần một `NSApplication` thật. Con số 94,07% vì thế trả lời "phần LÕI đã
# được kiểm tới đâu", và **không** trả lời "cả sản phẩm đã được kiểm tới đâu".
#
# Câu thứ hai chưa ai trả lời. 24 nghìn dòng `GEditorApp` — thanh tab, panel, bảng CSV, cầu nối
# AppleScript, đường in ấn — chỉ được 188 bài tự kiểm giao diện chạm tới, và không ai biết
# chúng chạm tới bao nhiêu phần. Script này chạy đúng bộ tự kiểm ấy dưới bộ đếm độ phủ.
#
# ## Đọc con số cho đúng
#
# Bốn tệp chỉ sống dưới một cờ dòng lệnh KHÁC `--self-test`: `SoakTest` (`--soak`),
# `WindowCapture` (`--capture`), `IdleProbe` (`--measure-idle`), `StartupProbe`
# (`--measure-startup`). Chúng sẽ mãi mãi 0% ở phép đo này, và chúng không phải mã sản phẩm —
# chúng là công cụ đo. Nên báo cáo in HAI con số: cả tầng app, và phần trừ bốn tệp ấy ra.
#
# Không con số nào trong hai cái là "đúng hơn". Cái thứ nhất là thứ NFR-MNT-02 sẽ đòi nếu ngày
# nào đó chỉ tiêu ấy mở rộng sang tầng app; cái thứ hai là thứ nói được "phần người dùng chạm
# vào đã được kiểm tới đâu".
set -uo pipefail
cd "$(dirname "$0")/.."

# Cổng CHỐT HAI CHIỀU, cùng khuôn `scan-untranslated.py --tran`: đỏ khi tụt, và cũng đỏ khi
# tăng mà quên nâng mốc. Chỉ chặn chiều tụt thì mốc đứng yên kể cả khi độ phủ đã khá lên, và
# một con số không còn đúng thì không ai tin nó nữa.
#
# ĐẶT MỐC VÀO GIỮA DẢI, KHÔNG SÁT SỐ ĐO. Phép đo này KHÔNG tất định: ba lượt liên tiếp ngày
# 26/08/2026 cho 71,92% · 72,03% · 72,03%, tức biên độ khoảng 0,1 điểm phần trăm (≈ 7 dòng trên
# hơn 7.000). Bộ tự kiểm chạm vào những đường phụ thuộc thời gian — hạn giờ plugin, banner tạm —
# nên vài dòng được chạy hay không tuỳ lượt.
#
# Dải chấp nhận rộng đúng 1,0 điểm (`floor ≤ x < floor + 1`). Đặt mốc bằng đúng số vừa đo là
# đứng sát một mép: lượt sau lệch 0,1 là đỏ, mà đỏ vì nhiễu đo thì người ta bắt đầu bỏ qua cổng.
# Nên mốc đặt ở 71,5 — quan sát 71,9…72,0 nằm giữa dải, còn margin cả hai phía.
#
# NÂNG LÊN 75,0 ngày 28/08/2026, sau khi bốn bài tự kiểm mới chạm vào hai panel vốn 0%
# (`ColumnEditorPanel`, `SearchResultsView`): quan sát nhảy lên 75,59%. Giữ nguyên cách đặt mốc
# — dưới quan sát một quãng đủ cho nhiễu, chứ không sát nút — vì mốc sát nút biến mỗi lần chạy
# thành một lần tung đồng xu, và một cổng thỉnh thoảng đỏ vô cớ là cổng sắp bị `|| true`.
FLOOR=75.0
REPORT_ONLY=false
[ "${1:-}" = "--report" ] && REPORT_ONLY=true

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ Dựng bản có bộ đếm độ phủ…"
swift build -c debug --product GEditorApp --enable-code-coverage >/dev/null 2>&1 || {
    echo "❌ build hỏng"; exit 1; }
# Dylib grammar nặng phải nằm cạnh binary, y như `run-startup-kpi.sh`: thiếu nó thì các bài
# kiểm tô màu C++/Ruby đỏ, và con số độ phủ đo một sản phẩm khác với sản phẩm ta giao.
swift build -c debug --product TreeSitterHeavy --enable-code-coverage >/dev/null 2>&1
BINDIR="$(swift build -c debug --product GEditorApp --enable-code-coverage --show-bin-path)"

echo "▸ Chạy 188 bài tự kiểm giao diện dưới bộ đếm…"
LLVM_PROFILE_FILE="$WORK/app-%p.profraw" "$BINDIR/GEditorApp" --self-test > "$WORK/selftest.log" 2>&1
SELFTEST_STATUS=$?
tail -1 "$WORK/selftest.log"
if [ "$SELFTEST_STATUS" != "0" ]; then
    # Bộ tự kiểm đỏ thì con số độ phủ vô nghĩa: nó đo một lượt chạy đã hỏng giữa chừng.
    #
    # In ĐÚNG TÊN bài đỏ và giữ lại nhật ký. Bản đầu của script chỉ in "TRƯỢT 1/188" rồi xoá
    # thư mục tạm — và lần đầu nó đỏ thật (một bài CHẬP CHỜN, không tái hiện trong bảy lượt sau)
    # thì không còn gì để truy. Một bài kiểm chập chờn ở cổng chặn merge là chuyện phải tìm ra,
    # nên phép đo không được nuốt bằng chứng của chính nó.
    KEEP="benchmarks/results/app-coverage-selftest-failure.log"
    cp "$WORK/selftest.log" "$KEEP" 2>/dev/null
    echo "❌ bộ tự kiểm TRƯỢT — không đo độ phủ trên một lượt chạy hỏng:"
    grep -A3 "❌" "$WORK/selftest.log" | head -12 | sed 's/^/   /'
    echo "   Nhật ký đầy đủ: $KEEP"
    exit 1
fi

xcrun llvm-profdata merge -sparse "$WORK"/*.profraw -o "$WORK/app.profdata" 2>/dev/null || {
    echo "❌ không gộp được dữ liệu độ phủ"; exit 1; }

xcrun llvm-cov report "$BINDIR/GEditorApp" -instr-profile="$WORK/app.profdata" \
    Sources/GEditorApp > "$WORK/report.txt" 2>/dev/null

xcrun llvm-cov export "$BINDIR/GEditorApp" -instr-profile="$WORK/app.profdata" \
    -format=text Sources/GEditorApp > "$WORK/export.json" 2>/dev/null

python3 - "$WORK/export.json" "$FLOOR" "$REPORT_ONLY" <<'PY'
import json, sys

export_path, floor, report_only = sys.argv[1], float(sys.argv[2]), sys.argv[3] == "true"
data = json.load(open(export_path))

# Bốn tệp chỉ chạy dưới cờ KHÁC `--self-test`. Xem đầu script.
# `MermaidKPI.swift` thêm 28/08/2026: nó chỉ sống dưới `--mermaid-kpi`, đúng cùng họ với bốn
# tệp kia. Trước đó nó nằm im ở 0% trong danh sách "mỏng nhất" và trông như một khoảng nợ,
# trong khi nó là công cụ đo — đúng loại hiểu nhầm mà danh sách này sinh ra để tránh.
TOOLING = {"SoakTest.swift", "WindowCapture.swift", "IdleProbe.swift", "StartupProbe.swift",
           "MermaidKPI.swift"}

files = []
for export in data.get("data", []):
    for entry in export.get("files", []):
        name = entry["filename"].split("/")[-1]
        lines = entry["summary"]["lines"]
        files.append((name, lines["count"], lines["covered"]))

def percent(rows):
    total = sum(r[1] for r in rows)
    covered = sum(r[2] for r in rows)
    return (covered / total * 100) if total else 0.0, total, covered

all_pct, all_total, all_covered = percent(files)
product = [f for f in files if f[0] not in TOOLING]
prod_pct, prod_total, prod_covered = percent(product)

print()
print("  ── Độ phủ tầng app, đo bằng chính bộ tự kiểm giao diện ──")
print("    cả GEditorApp        %6.2f%%   (%d/%d dòng)" % (all_pct, all_covered, all_total))
print("    trừ %d tệp công cụ   %6.2f%%   (%d/%d dòng)" % (len(TOOLING), prod_pct, prod_covered, prod_total))
print("      ↳ bỏ ra: %s" % ", ".join(sorted(TOOLING)))
print()
print("    So sánh: lõi GEditorCore 94,07% (scripts/run-coverage.sh).")
print("    Hai con số đo hai thứ khác nhau và KHÔNG cộng lại được — nhưng đặt cạnh nhau thì")
print("    thấy rõ chỗ mỏng: tầng app có gấp đôi số dòng của lõi và chưa tới ba phần tư độ phủ.")

worst = sorted((f for f in product if f[1] >= 100), key=lambda f: f[2] / f[1])[:8]
print()
print("  ── Tám tệp sản phẩm mỏng nhất (≥100 dòng) ──")
for name, total, covered in worst:
    print("    %-34s %6.2f%%   (%d/%d)" % (name, covered / total * 100, covered, total))

if report_only:
    sys.exit(0)

print()
if all_pct < floor:
    print("❌ độ phủ tầng app %.2f%% < mốc %.2f%% — có mã mới chưa ai chạm tới." % (all_pct, floor))
    print("   Thêm bài tự kiểm, hoặc hạ mốc kèm lý do trong scripts/run-app-coverage.sh.")
    sys.exit(1)
if all_pct >= floor + 1.0:
    print("❌ độ phủ tầng app đã lên %.2f%% mà mốc vẫn ghi %.2f%% — nâng mốc lên %.1f."
          % (all_pct, floor, int(all_pct)))
    print("   Cổng chốt hai chiều: mốc đứng yên là mốc thôi nói thật.")
    sys.exit(1)
print("✅ độ phủ tầng app %.2f%%, mốc %.2f%%" % (all_pct, floor))
PY
