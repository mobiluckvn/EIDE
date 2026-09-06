#!/usr/bin/env python3
"""Sinh bảng mã VNI cho GEditor từ file UCM đã vendor (FR-ENC-201).

VNI là bảng mã DUY NHẤT trong FR-ENC-201 mà không bộ chuyển đổi nào trên máy biết đọc —
macOS không có, iconv không có, Python không có. Nên nó không thể suy ra từ hệ thống như các
bảng mã khác, và cũng không được gõ tay.

Cách làm: vendor bảng UCM có truy nguyên tới nhà phát hành (xem `vendor/NGUON.md`), rồi ép nó
đi qua bốn phép kiểm độc lập trước khi cho phép sinh mã. Bảng chép sai một ô sẽ trượt ít nhất
một trong bốn:

  1. Vòng tròn — mọi ánh xạ đều đánh dấu roundtrip (|0), không có ánh xạ một chiều.
  2. Không đụng độ — không hai ký tự nào dùng chung một chuỗi byte.
  3. Nhất quán với Unicode — chữ hai byte phải bằng (byte chữ nền) + (byte cụm dấu), trong đó
     chữ nền và cụm dấu suy ra từ dữ liệu PHÂN RÃ của Unicode chứ không từ chính bảng. Mỗi cụm
     dấu phải ứng với đúng một byte cho chữ HOA và một byte cho chữ thường, và hai byte ấy phải
     cách nhau đúng 0x20 như mọi cặp hoa/thường khác.
  4. Đúng chữ Việt — mọi ký tự ngoài ASCII phải là chữ cái tiếng Việt thật.

Phép kiểm 3 là phép mạnh nhất: nó đối chiếu bảng với một nguồn hoàn toàn khác (bảng phân rã
của Unicode), và một bảng bị xáo trộn không thể tình cờ nhất quán trên 118 ký tự.

    scripts/generate-vni-table.py           sinh file Swift
    scripts/generate-vni-table.py --check   chỉ kiểm, không ghi (dùng trong CI)
"""

import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UCM = ROOT / "Sources/GEditorCore/Encoding/vendor/x-viet-vni.ucm"
TCVN_UCM = ROOT / "Sources/GEditorCore/Encoding/vendor/x-viet-tcvn5712.ucm"
OUT = ROOT / "Sources/GEditorCore/Encoding/VNIEncodingTable.swift"

VIETNAMESE_LETTERS = set(
    "AÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬBCDĐEÈÉẺẼẸÊỀẾỂỄỆFGHIÌÍỈĨỊJKLMNOÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢPQRSTUÙÚỦŨỤƯỪỨỬỮỰVWXYỲÝỶỸỴZ"
)
VIETNAMESE_LETTERS |= {c.lower() for c in VIETNAMESE_LETTERS}


def parse_ucm(path: Path) -> list[tuple[int, list[int], int]]:
    rows = []
    for line in path.read_text(encoding="latin-1").splitlines():
        match = re.match(r"<U([0-9A-Fa-f]{4,6})>\s+((?:\\x[0-9A-Fa-f]{2})+)\s+\|(\d)", line)
        if match:
            codepoint = int(match.group(1), 16)
            data = [int(b, 16) for b in re.findall(r"\\x([0-9A-Fa-f]{2})", match.group(2))]
            rows.append((codepoint, data, int(match.group(3))))
    return rows


def verify(rows) -> dict[str, str]:
    """Bốn phép kiểm. Ném SystemExit ngay khi trượt — thà không có VNI còn hơn có bảng sai."""
    problems = []

    # 1. Vòng tròn
    one_way = [hex(cp) for cp, _, flag in rows if flag != 0]
    if one_way:
        problems.append(f"{len(one_way)} ánh xạ không phải hai chiều: {one_way[:5]}")

    # 2. Đụng độ
    by_bytes = defaultdict(list)
    for codepoint, data, _ in rows:
        by_bytes[tuple(data)].append(chr(codepoint))
    clashes = {k: v for k, v in by_bytes.items() if len(v) > 1}
    if clashes:
        problems.append(f"{len(clashes)} chuỗi byte bị nhiều ký tự dùng chung")

    # 3. Nhất quán với bảng phân rã của Unicode
    single = {cp: data[0] for cp, data, _ in rows if len(data) == 1}
    clusters: dict[tuple[str, bool], set[int]] = defaultdict(set)
    inconsistent = []
    for codepoint, data, _ in rows:
        if len(data) != 2:
            if len(data) > 2:
                inconsistent.append((hex(codepoint), "dài hơn 2 byte"))
            continue
        decomposed = unicodedata.normalize("NFD", chr(codepoint))
        # Chữ nền là phần dài nhất mà bảng có mã MỘT byte — với ơ/ư thì đó là chính "ơ",
        # còn với â/ă thì là "a" và cả cụm dấu nằm ở byte thứ hai.
        base_length = None
        for length in range(len(decomposed) - 1, 0, -1):
            candidate = unicodedata.normalize("NFC", decomposed[:length])
            if len(candidate) == 1 and ord(candidate) in single:
                base_length = length
                break
        if base_length is None:
            inconsistent.append((hex(codepoint), "không tìm được chữ nền có mã một byte"))
            continue
        base = unicodedata.normalize("NFC", decomposed[:base_length])
        if data[0] != single[ord(base)]:
            inconsistent.append((hex(codepoint), f"byte chữ nền {data[0]:02X} lệch"))
            continue
        clusters[(decomposed[base_length:], base.isupper())].add(data[1])

    for (marks, is_upper), byte_set in clusters.items():
        if len(byte_set) != 1:
            names = "+".join(unicodedata.name(c) for c in marks)
            inconsistent.append((names, f"một cụm dấu ứng với nhiều byte: {sorted(byte_set)}"))
    # HOA và thường của cùng cụm dấu phải cách nhau đúng 0x20.
    for marks in {m for m, _ in clusters}:
        upper = clusters.get((marks, True))
        lower = clusters.get((marks, False))
        if upper and lower and next(iter(lower)) - next(iter(upper)) != 0x20:
            inconsistent.append((marks, "khoảng cách HOA/thường không phải 0x20"))
    if inconsistent:
        problems.append(f"{len(inconsistent)} chỗ không nhất quán với Unicode: {inconsistent[:5]}")

    # 4. Đúng chữ Việt
    strangers = [
        chr(cp) for cp, _, _ in rows
        if cp > 0x7F and chr(cp) not in VIETNAMESE_LETTERS
    ]
    if strangers:
        problems.append(f"{len(strangers)} ký tự ngoài ASCII không phải chữ Việt: {strangers[:10]}")

    if problems:
        raise SystemExit("❌ Bảng VNI không qua kiểm:\n  - " + "\n  - ".join(problems))

    return {
        "một byte": str(len(single)),
        "hai byte": str(sum(1 for _, d, _ in rows if len(d) == 2)),
        "cụm dấu": str(len({m for m, _ in clusters})),
    }


def cross_check_tcvn() -> str:
    """Đối chiếu bảng TCVN3 đang dùng với một nguồn thứ hai không liên quan.

    Bảng TCVN3 của GEditor sinh từ iconv của macOS; bảng này đến từ Encode-VN. Hai nguồn khác
    hẳn nhau, nên chỗ nào lệch là chỗ đáng đi soi — kể cả khi cuối cùng iconv mới là đúng.
    """
    if not TCVN_UCM.exists():
        return "không có bảng TCVN thứ hai để đối chiếu"
    table = ROOT / "Sources/GEditorCore/Encoding/LegacyEncodingTables.swift"
    if not table.exists():
        return "chưa có bảng TCVN3 để đối chiếu"
    text = table.read_text(encoding="utf-8")
    match = re.search(r"static let tcvn3: \[UInt32\] = \[(.*?)\n    \]", text, re.S)
    if not match:
        return "không đọc được bảng TCVN3 hiện có"
    # Bỏ chú thích cuối dòng TRƯỚC khi bóc số: mỗi hàng kết thúc bằng "// 0x08" và số ấy
    # cũng là hex, nuốt phải nó là toàn bộ mảng lệch chỉ số — lần đầu chạy đã dính đúng lỗi này
    # và báo "lệch 74/128 ô" hoàn toàn giả.
    body = re.sub(r"//[^\n]*", "", match.group(1))
    ours = [int(v, 0) for v in re.findall(r"0x[0-9A-Fa-f]+", body)]
    theirs = {}
    for codepoint, data, flag in parse_ucm(TCVN_UCM):
        if len(data) == 1 and flag == 0:
            theirs[data[0]] = codepoint
    differences = [
        f"{b:02X}: ta={ours[b]:04X} họ={theirs[b]:04X}"
        for b in range(0x80, 0x100)
        if b in theirs and b < len(ours) and ours[b] != theirs[b]
    ]
    if differences:
        return f"TCVN3 lệch {len(differences)}/128 ô so với Encode-VN: {differences[:4]}"
    return "TCVN3 khớp hoàn toàn với nguồn thứ hai (Encode-VN)"


def build(rows) -> str:
    single = sorted((data[0], cp) for cp, data, _ in rows if len(data) == 1)
    double = sorted((tuple(data), cp) for cp, data, _ in rows if len(data) == 2)

    decode = [0xFFFD] * 256
    for byte, codepoint in single:
        decode[byte] = codepoint

    lines = [
        "// SINH TỰ ĐỘNG bởi scripts/generate-vni-table.py — ĐỪNG SỬA TAY.",
        "//",
        "// Nguồn: Sources/GEditorCore/Encoding/vendor/x-viet-vni.ucm (xem vendor/NGUON.md).",
        "// Bảng chỉ được sinh sau khi qua bốn phép kiểm trong script; xem tài liệu ở đầu script.",
        "",
        "enum VNIEncodingTable {",
        "",
        "    /// byte đơn → scalar Unicode. 0xFFFD = byte không dùng trong bảng mã.",
        "    static let singleByte: [UInt32] = [",
    ]
    for start in range(0, 256, 8):
        row = ", ".join(f"0x{decode[b]:04X}" for b in range(start, start + 8))
        lines.append(f"        {row},")
    lines += [
        "    ]",
        "",
        "    /// (byte chữ nền, byte cụm dấu) → scalar Unicode.",
        "    ///",
        "    /// VNI ghép chữ có dấu bằng HAI byte: chữ nền rồi tới cụm dấu. Đó là lý do file VNI",
        "    /// to hơn file TCVN3 cùng nội dung, và là lý do bảng mã này không phải codec một byte.",
        "    static let doubleByte: [(base: UInt8, mark: UInt8, scalar: UInt32)] = [",
    ]
    for (base, mark), codepoint in double:
        name = unicodedata.name(chr(codepoint), "")
        lines.append(f"        (0x{base:02X}, 0x{mark:02X}, 0x{codepoint:04X}),  // {chr(codepoint)}  {name}")
    lines += ["    ]", "}", ""]
    return "\n".join(lines)


def main() -> int:
    rows = parse_ucm(UCM)
    if not rows:
        raise SystemExit(f"❌ Không đọc được ánh xạ nào từ {UCM}")
    stats = verify(rows)
    generated = build(rows)

    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != generated:
            print(f"❌ {OUT.relative_to(ROOT)} lệch với nguồn sinh — chạy lại script.")
            return 1
        print(f"✅ {OUT.relative_to(ROOT)} khớp")
        return 0

    OUT.write_text(generated, encoding="utf-8")
    print(f"▸ Đã ghi {OUT.relative_to(ROOT)}")
    print("  " + " · ".join(f"{k}: {v}" for k, v in stats.items()))
    print("  bốn phép kiểm: ✅ vòng tròn · ✅ không đụng độ · ✅ nhất quán Unicode · ✅ đúng chữ Việt")
    print("  đối chiếu chéo: " + cross_check_tcvn())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
