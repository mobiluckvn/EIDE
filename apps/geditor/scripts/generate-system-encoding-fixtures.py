#!/usr/bin/env python3
"""Sinh fixture kiểm chéo cho các bảng mã do HỆ ĐIỀU HÀNH chuyển đổi (FR-ENC-201).

Cùng nguyên tắc với generate-encoding-tables.py: một bảng mã chỉ được tin khi HAI hiện thực
độc lập cho ra cùng một kết quả. Ở đây là:

    codec của Python   ←→   CoreFoundation của macOS

Python sinh ra cặp (chuỗi, byte); test Swift bắt CoreFoundation phải cho ra đúng cặp ấy theo
cả hai chiều. Hai bên không dùng chung dòng mã nào, nên trùng nhau là bằng chứng thật.

Vì sao không tự dựng bảng như TCVN3/VISCII: những bảng mã này có tới hàng chục nghìn ô
(GB18030, Big5, Shift-JIS) và macOS đã có bộ chuyển đổi được bảo trì. Tự gõ bảng ở quy mô đó
là tự rước lỗi hỏng dữ liệu. Ba bảng mã Việt legacy phải tự dựng chỉ vì hệ thống KHÔNG có.

    scripts/generate-system-encoding-fixtures.py
    scripts/generate-system-encoding-fixtures.py --check   chỉ kiểm, không ghi (dùng trong CI)
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Tests/GEditorCoreTests/SystemEncodingFixtures.swift"

# (case Swift, codec Python, chuỗi mẫu). Chuỗi mẫu phải dùng ĐÚNG chữ viết của bảng mã đó —
# thử tiếng Nga trên Big5 thì chỉ kiểm được đường thất bại, không kiểm được đường đúng.
SAMPLES = [
    ("windows1250", "cp1250", "Příliš žluťoučký kůň — ŽŠČŘĎ"),
    ("windows1251", "cp1251", "Съешь ещё этих мягких булок"),
    ("windows1252", "cp1252", "Français \u2014 naïve façade «cœur»"),
    ("windows1253", "cp1253", "Καλημέρα κόσμε"),
    ("windows1254", "cp1254", "Pijamalı hasta yağız şoföre"),
    ("windows1255", "cp1255", "שלום עולם"),
    ("windows1256", "cp1256", "مرحبا بالعالم"),
    ("windows1257", "cp1257", "Įlinkdama fripanėlė"),
    # windows1258 KHÔNG nằm ở đây: nó đòi dấu tổ hợp ("ế" = ê + dấu sắc rời) nên codec Python
    # từ chối chuỗi dựng sẵn. Bảng mã ấy đã có bộ kiểm riêng do generate-encoding-tables.py sinh.
    ("isoLatin1", "iso8859-1", "Grüße aus München, àéîõü"),
    ("isoLatin2", "iso8859-2", "Příliš žluťoučký kůň"),
    ("isoLatin3", "iso8859-3", "Ċetta ħadet ġelat"),
    ("isoLatin4", "iso8859-4", "Kalju sõi kõõma"),
    ("isoCyrillic", "iso8859-5", "Съешь ещё булок"),
    ("isoArabic", "iso8859-6", "مرحبا بالعالم"),
    ("isoGreek", "iso8859-7", "Καλημέρα κόσμε"),
    ("isoHebrew", "iso8859-8", "שלום עולם"),
    ("isoLatin5", "iso8859-9", "Pijamalı hasta şoföre"),
    ("isoLatin6", "iso8859-10", "Áðalbjörg Þórsdóttir"),
    ("isoThai", "iso8859-11", "สวัสดีชาวโลก"),
    ("isoLatin7", "iso8859-13", "Įlinkdama fripanėlė"),
    ("isoLatin8", "iso8859-14", "Ẁelcome i Gymru"),
    ("isoLatin9", "iso8859-15", "Français, 20 € naïve"),
    ("isoLatin10", "iso8859-16", "Măgură cu șerpi și țapi"),
    ("shiftJIS", "shift_jis", "こんにちは世界 カタカナ 漢字"),
    ("gb18030", "gb18030", "你好世界 简体中文 测试"),
    ("eucKR", "euc_kr", "안녕하세요 세계 한국어"),
    ("big5", "big5", "你好世界 繁體中文 測試"),
]


def build() -> str:
    lines = [
        "// SINH TỰ ĐỘNG bởi scripts/generate-system-encoding-fixtures.py — ĐỪNG SỬA TAY.",
        "//",
        "// Byte ở đây do codec của PYTHON sinh ra. Test bắt CoreFoundation của macOS phải cho",
        "// ra đúng như vậy theo cả hai chiều. Hai hiện thực độc lập khớp nhau mới là bằng chứng.",
        "",
        "@testable import GEditorCore",
        "",
        "enum SystemEncodingFixtures {",
        "    struct Sample {",
        "        let encoding: TextEncoding",
        "        let text: String",
        "        let bytes: [UInt8]",
        "    }",
        "",
        "    static let all: [Sample] = [",
    ]
    for case_name, codec, text in SAMPLES:
        try:
            raw = text.encode(codec)
        except LookupError:
            print(f"⚠️  Python không có codec {codec}, bỏ {case_name}", file=sys.stderr)
            continue
        except UnicodeEncodeError as error:
            raise SystemExit(f"Chuỗi mẫu của {case_name} không mã hoá được bằng {codec}: {error}")
        # Đi ngược lại ngay tại đây: chuỗi mẫu sai thì hỏng ngay ở khâu sinh, không để lọt
        # xuống test rồi mới lộ ra dưới dạng một lỗi khó hiểu.
        assert raw.decode(codec) == text, f"{case_name}: Python không round-trip được"
        byte_list = ", ".join(f"0x{b:02X}" for b in raw)
        escaped = text.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'        Sample(encoding: .{case_name}, text: "{escaped}",')
        lines.append(f"                bytes: [{byte_list}]),")
    lines += ["    ]", "}", ""]
    return "\n".join(lines)


def main() -> int:
    generated = build()
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != generated:
            print(f"❌ {OUT.relative_to(ROOT)} lệch với nguồn sinh — chạy lại script.")
            return 1
        print(f"✅ {OUT.relative_to(ROOT)} khớp")
        return 0
    OUT.write_text(generated, encoding="utf-8")
    print(f"▸ Đã ghi {OUT.relative_to(ROOT)} ({len(SAMPLES)} bảng mã)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
