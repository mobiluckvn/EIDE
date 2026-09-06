#!/bin/bash
# PoC-J — FR-DOC-305 (macOS Versions) có THẬT SỰ cần chuyển sang `NSDocument` không?
#
# §4bis ghi mục này là "cần chuyển sang NSDocument, đổi cả kiến trúc quản lý tài liệu". Trước
# khi đi chốt một cuộc viết lại, đo xem tiền đề có đúng không — đúng lối PoC-I đã làm với
# libxml2, và lối ấy đã một lần lật ngược kết luận.
#
# Hai câu hỏi:
#   1. `NSFileVersion` có tự giữ và khôi phục bản cũ được không, KHÔNG cần `NSDocument`?
#   2. Nếu chuyển sang `NSDocument` thì phạm vi thay đổi rộng bao nhiêu — đếm bằng số, không
#      bằng cảm giác.
set -uo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ PoC-J — FR-DOC-305 cần NSDocument không?"
echo
echo "1. NSFileVersion, KHÔNG có NSDocument:"

cat > "$WORK/ver.swift" <<'EOF'
import Foundation
let dir = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("geditor-pocj-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let file = dir.appendingPathComponent("thu.txt")
try! "bản 1 — Nguyễn".write(to: file, atomically: true, encoding: .utf8)
for n in 2 ... 4 {
    _ = try? NSFileVersion.addOfItem(at: file, withContentsOf: file)
    try! "bản \(n) — Nguyễn".write(to: file, atomically: true, encoding: .utf8)
}
let others = NSFileVersion.otherVersionsOfItem(at: file) ?? []
print("   giữ được \(others.count) bản cũ")
for v in others.prefix(3) {
    print("   · \((try? String(contentsOf: v.url, encoding: .utf8)) ?? "?")")
}
if let old = others.last {
    print("   khôi phục được: \((try? String(contentsOf: old.url, encoding: .utf8)) ?? "?")")
}
try? FileManager.default.removeItem(at: dir)
EOF
swift "$WORK/ver.swift" 2>&1 | grep -E "giữ được|·|khôi phục"

echo
echo "2. Phạm vi nếu chuyển sang NSDocument (đếm trong mã hiện tại):"
echo "   chỗ chạm tới tài liệu ở lớp app: $(grep -rn 'editorDocument\|\.document\b' Sources/GEditorApp/*.swift | wc -l | tr -d ' ')"
echo "   chỗ chỉ mục tabs[] (N tài liệu / MỘT cửa sổ): $(grep -c 'tabs\[' Sources/GEditorApp/MainWindowController.swift)"
echo "   Document.swift: $(wc -l < Sources/GEditorCore/Session/Document.swift | tr -d ' ') dòng"
echo "   SessionStore + SnapshotStore + CLIBridge: $(( $(wc -l < Sources/GEditorCore/Session/SessionStore.swift) + $(wc -l < Sources/GEditorCore/Session/SnapshotStore.swift) + $(wc -l < Sources/GEditorCore/Session/CLIBridge.swift) )) dòng"
echo "   chỗ trong bộ tự kiểm chạm tài liệu/tab/phiên: $(grep -c 'prepareSelfTestDocument\|resetTabsForSelfTest\|tabCountForSelfTest\|sessionStore' Sources/GEditorApp/SelfTest.swift)"
echo
cat <<'NOTE'
▸ Điều PoC này KHÔNG trả lời: giao diện lịch sử NGUYÊN BẢN của hệ điều hành
  (NSDocument.browseVersions) chỉ có khi dùng NSDocument. NSFileVersion cho DỮ LIỆU phiên bản,
  không cho cái giao diện ấy — nên câu chữ "theo giao diện lịch sử của hệ điều hành" trong
  FR-DOC-305 là chỗ cần anh chốt, không phải chỗ đo được.
NOTE
