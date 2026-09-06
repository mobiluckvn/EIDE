#!/usr/bin/env python3
"""Sinh EideTokensGenerated.swift từ docs/spec/ui/tokens.json — WI-021.

Spec: UXD-13 §7 (token thiết kế PTIT), U7 (mật độ kỹ thuật, nền sáng), U10 (tương phản
≥ 4,5:1 theo WCAG 2.2 AA).

VÌ SAO SINH. Cùng bộ token phục vụ ba chỗ: 23 mockup HTML, panel EIDE trong GEditor, và tài
liệu UXD-13. Chép tay màu vào Swift nghĩa là lần đổi nhận diện tiếp theo (WI-258 xác nhận đỏ
PTIT chính thức) phải sửa hai nơi và một nơi sẽ bị quên — mà "quên" ở đây là một sản phẩm có
hai sắc đỏ khác nhau trên cùng màn hình.

    python scripts/gen_ui_swift.py            ghi apps/geditor/Sources/EIDEKit/
    python scripts/gen_ui_swift.py --kiem     so với tệp hiện có (dùng ở CI)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKENS = ROOT / "docs" / "spec" / "ui" / "tokens.json"
DICH = ROOT / "apps" / "geditor" / "Sources" / "EIDEKit" / "EideTokensGenerated.swift"


def main() -> int:
    t = json.loads(TOKENS.read_text(encoding="utf-8"))
    mau = t["color"]
    d = [
        "// SINH TỰ ĐỘNG — đừng sửa tay.",
        "//",
        "// Nguồn: docs/spec/ui/tokens.json (sinh từ docs/ho-so/nguon/uxd.js §7).",
        "// Sinh lại: python3 scripts/gen_ui_swift.py   ·   Đối chiếu: --kiem (chạy trong CI).",
        "//",
        "// UXD-13 §7 và U7: đỏ PTIT cho điều hướng và hành động chính, vàng cho việc CẦN NGƯỜI,",
        "// xám xanh cho hành động phụ và cho tác tử. Ba màu ấy mang nghĩa, không phải trang trí:",
        "// người dùng đọc màu để biết việc nào máy tự làm và việc nào đang chờ mình.",
        "",
        "import AppKit",
        "",
        "/// Token thiết kế PTIT (UXD-13 §7).",
        "public enum EideToken {",
        "",
        "    public enum Mau {",
    ]
    for k, v in mau.items():
        d.append(f'        public static let {k} = NSColor(hex: "{v}")')
    d += [
        "    }",
        "",
        f'    public static let fontUI = NSFont(name: "{t["font"]["ui"]}", size: {t["font"]["uiSize"]})',
        f'        ?? NSFont.systemFont(ofSize: {t["font"]["uiSize"]})',
        f'    public static let fontMono = NSFont(name: "{t["font"]["mono"]}", size: {t["font"]["monoSize"]})',
        f'        ?? NSFont.monospacedSystemFont(ofSize: {t["font"]["monoSize"]}, weight: .regular)',
        "",
        f'    public static let space: [CGFloat] = {t["space"]}',
        f'    public static let radius: [CGFloat] = {t["radius"]}',
        f'    public static let sidebarWidth: CGFloat = {t["layout"]["sidebar"]}',
        f'    public static let topbarHeight: CGFloat = {t["layout"]["topbar"]}',
        f'    public static let statusbarHeight: CGFloat = {t["layout"]["statusbar"]}',
        f'    public static let contentGap: CGFloat = {t["layout"]["contentGap"]}',
        "",
        "    /// UXD-13 U10 / WCAG 2.2 AA. Ghi ra thành hằng số để TEST đo được, chứ không để nó",
        "    /// thành một câu trong tài liệu mà không ai kiểm.",
        f'    public static let tuongPhanToiThieu: Double = {t["contrastMin"]}',
        f'    public static let hoTroNenToi = {str(t["darkMode"]).lower()}',
        "}",
        "",
        "extension NSColor {",
        "    /// `#RRGGBB` → NSColor trong không gian sRGB.",
        "    ///",
        "    /// Dùng sRGB chứ không phải `deviceRGB`: token là mã màu của bộ nhận diện, và nó",
        "    /// phải ra đúng một màu trên mọi màn hình, không phụ thuộc màn hình đang cắm.",
        "    public convenience init(hex: String) {",
        '        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex',
        "        let n = UInt32(s, radix: 16) ?? 0",
        "        self.init(srgbRed: CGFloat((n >> 16) & 0xFF) / 255,",
        "                  green: CGFloat((n >> 8) & 0xFF) / 255,",
        "                  blue: CGFloat(n & 0xFF) / 255, alpha: 1)",
        "    }",
        "",
        "    /// Độ sáng tương đối theo WCAG 2.2 — để `tuongPhan(_:)` đo được U10.",
        "    var doSangTuongDoi: Double {",
        "        guard let c = usingColorSpace(.sRGB) else { return 0 }",
        "        func k(_ v: CGFloat) -> Double {",
        "            let d = Double(v)",
        "            return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)",
        "        }",
        "        return 0.2126 * k(c.redComponent) + 0.7152 * k(c.greenComponent) + 0.0722 * k(c.blueComponent)",
        "    }",
        "",
        "    /// Tỉ số tương phản với một màu khác (WCAG 2.2). ≥ 4,5 là đạt AA cho chữ thường.",
        "    public func tuongPhan(_ khac: NSColor) -> Double {",
        "        let a = doSangTuongDoi, b = khac.doSangTuongDoi",
        "        return (max(a, b) + 0.05) / (min(a, b) + 0.05)",
        "    }",
        "}",
        "",
    ]
    noi_dung = "\n".join(d)

    cu = DICH.read_text(encoding="utf-8") if DICH.exists() else None
    if "--kiem" in sys.argv:
        if cu != noi_dung:
            print(f"✗ {DICH.relative_to(ROOT)} lệch ui/tokens.json — chạy scripts/gen_ui_swift.py")
            return 1
        print(f"✓ EideTokensGenerated.swift khớp ui/tokens.json ({len(mau)} màu)")
        return 0
    DICH.parent.mkdir(parents=True, exist_ok=True)
    DICH.write_text(noi_dung, encoding="utf-8")
    print(f"{'=' if cu == noi_dung else 'đã ghi'} {DICH.relative_to(ROOT)} ({len(mau)} màu)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
