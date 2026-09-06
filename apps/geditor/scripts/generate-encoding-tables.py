#!/usr/bin/env python3
"""Sinh bảng mã tiếng Việt legacy cho GEditor (FR-ENC-201).

Vì sao SINH chứ không viết tay: bảng sai không làm chương trình hỏng, nó làm hỏng DỮ LIỆU
của người dùng một cách im lặng — mở file TCVN3 ra thấy chữ khác, lưu lại là mất bản gốc.
Một bảng 256 ô gõ từ trí nhớ hoặc chép từ một trang web là không kiểm chứng được.

Nguồn dùng ở đây đều là bộ chuyển đổi CÓ SẴN TRÊN MÁY, và mỗi bảng được suy ra theo HAI
chiều độc lập rồi bắt hai chiều phải khớp nhau:

    TCVN3   iconv "TCVN-5712-1:1993"
    VISCII  iconv "VISCII"
    CP1258  iconv "CP1258" và codec cp1258 của Python — hai hiện thực khác nhau

Lưu ý quan trọng đã phát hiện khi làm: bộ giải mã TCVN của iconv trên macOS HỎNG ở vùng
ASCII — nó trả U+0000 cho mọi chữ cái. Chiều mã hóa thì đúng. Nên bảng TCVN3 được suy từ
chiều MÃ HÓA (duyệt kho ký tự Unicode, xem ký tự nào cho ra đúng một byte), còn vùng ASCII
lấy theo đúng định nghĩa của chuẩn (0x00–0x7F là ASCII). Vùng cao vẫn được đối chiếu ngược
lại bằng chiều giải mã để bắt sai lệch.

    scripts/generate-encoding-tables.py          sinh và ghi đè file Swift
    scripts/generate-encoding-tables.py --check  chỉ kiểm tra, không ghi (dùng trong CI)
"""

import subprocess
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_OUT = ROOT / "Sources/GEditorCore/Encoding/LegacyEncodingTables.swift"
FIXTURE_OUT = ROOT / "Tests/GEditorCoreTests/LegacyEncodingFixtures.swift"

UNASSIGNED = 0xFFFF_FFFF

# Kho ký tự đủ rộng để phủ mọi thứ ba bảng mã này có thể chứa: Latin cơ bản và mở rộng,
# dấu thanh tổ hợp, khối Latin Extended Additional (nơi phần lớn chữ Việt có dấu nằm),
# cùng vài ký hiệu tiền tệ và dấu câu.
# C1 (U+0080–U+009F) bị loại: chúng là ký tự điều khiển, không phải ký tự văn bản, mà VISCII
# lại dùng chính vùng byte 0x80–0x9F cho chữ Việt. Để chúng trong danh sách thì U+0080 giành
# mất byte 0x80 của chữ Ạ — và bảng sẽ sai đúng ở vùng đông chữ nhất.
CANDIDATES = (
    list(range(0x0020, 0x0080))
    + list(range(0x00A0, 0x0250))
    + list(range(0x0300, 0x0370))
    + list(range(0x1E00, 0x1F00))
    + [0x20AB, 0x20AC, 0x2018, 0x2019, 0x201C, 0x201D, 0x2013, 0x2014, 0x2026, 0x02C6, 0x0152, 0x0153]
)


def iconv_encode(encoding: str, text: str) -> bytes | None:
    """UTF-8 → `encoding`. `None` nếu ký tự không biểu diễn được."""
    result = subprocess.run(
        ["iconv", "-f", "UTF-8", "-t", encoding],
        input=text.encode("utf-8"), capture_output=True,
    )
    return result.stdout if result.returncode == 0 and result.stdout else None


def iconv_decode(encoding: str, data: bytes) -> str | None:
    result = subprocess.run(
        ["iconv", "-f", encoding, "-t", "UTF-8"],
        input=data, capture_output=True,
    )
    if result.returncode != 0 or not result.stdout:
        return None
    try:
        return result.stdout.decode("utf-8")
    except UnicodeDecodeError:
        return None


def derive_from_encoding_direction(encoding: str) -> dict[int, int]:
    """byte → điểm mã, suy từ chiều MÃ HÓA.

    Chỉ nhận ký tự cho ra ĐÚNG MỘT byte: bảng của ta là bảng một byte, mọi thứ dài hơn
    nằm ngoài mô hình và phải bị loại ra chứ không được làm tròn.
    """
    table: dict[int, int] = {}
    for code_point in CANDIDATES:
        encoded = iconv_encode(encoding, chr(code_point))
        if encoded is None or len(encoded) != 1:
            continue
        byte = encoded[0]
        # Ký tự đầu tiên thắng: kho ký tự được duyệt theo thứ tự điểm mã tăng dần, nên
        # dạng dựng sẵn (precomposed) luôn được ưu tiên hơn dạng tương đương phía sau.
        table.setdefault(byte, code_point)
    return table


def derive_from_decoding_direction(encoding: str) -> dict[int, int]:
    """byte → điểm mã, suy từ chiều GIẢI MÃ. Chỉ dùng để ĐỐI CHIẾU."""
    table: dict[int, int] = {}
    for byte in range(0x00, 0x100):
        decoded = iconv_decode(encoding, bytes([byte]))
        if decoded is None or len(decoded) != 1:
            continue
        table[byte] = ord(decoded)
    return table


# Ba byte này PHẢI giữ nguyên nghĩa điều khiển trong mọi bảng mã, nếu không trình soạn thảo
# không tách được dòng và không có tab. TCVN3 đặt chữ hoa vào vùng C0 nhưng né đúng ba byte
# này — và bộ sinh phải khẳng định điều đó chứ không được cho là hiển nhiên.
PROTECTED_CONTROLS = {0x00, 0x09, 0x0A, 0x0D}


def build_table(name: str, encoding: str, trust_ascii: bool = True) -> list[int]:
    """Dựng bảng byte → điểm mã, có kiểm chứng.

    Chiều GIẢI MÃ là bên có thẩm quyền, vì đó đúng là câu hỏi đang hỏi: "byte này trong file
    nghĩa là chữ gì". Chiều mã hóa chỉ dùng để lấp chỗ và để KIỂM CHỨNG — bộ mã hóa thường
    nhận thêm ký tự thay thế (VISCII nhận cả U+00A4 ¤ vào byte 0xA4 vốn là chữ "ấ"), nên tin
    nó làm nguồn chính sẽ đặt ký hiệu Latin-1 vào đúng vùng đông chữ Việt nhất.
    """
    forward = derive_from_encoding_direction(encoding)
    backward = derive_from_decoding_direction(encoding)

    table = [UNASSIGNED] * 256
    notes = []

    for byte, code_point in backward.items():
        # Bộ giải mã TCVN của macOS trả U+0000 cho mọi chữ cái ASCII — dấu hiệu hỏng, không
        # phải dữ liệu. Bỏ qua để phần ASCII bên dưới điền lại cho đúng.
        if code_point == 0x0000 and byte != 0x00:
            continue
        table[byte] = code_point

    if trust_ascii:
        # 0x20–0x7E là ASCII trong cả ba bảng mã, và ba byte điều khiển phải giữ nguyên nghĩa
        # nếu không trình soạn thảo mất khả năng tách dòng.
        for byte in list(range(0x20, 0x7F)) + sorted(PROTECTED_CONTROLS):
            if table[byte] != UNASSIGNED and table[byte] != byte:
                notes.append(f"ASCII {byte:#04x} bị bảng mã gán cho U+{table[byte]:04X}")
            table[byte] = byte

    # Vùng C0 còn lại: bộ giải mã không nói gì đáng tin về từng byte điều khiển đơn lẻ, nên
    # lấy từ chiều mã hóa. Đây là chỗ TCVN3 giấu 12 chữ HOA có dấu.
    control_letters = []
    for byte, code_point in forward.items():
        if byte >= 0x20 or byte in PROTECTED_CONTROLS:
            continue
        table[byte] = code_point
        control_letters.append((byte, code_point))

    if control_letters:
        letters = " ".join(f"{b:#04x}={chr(c)}" for b, c in sorted(control_letters))
        print(f"      {name} đặt {len(control_letters)} chữ trong vùng C0: {letters}")
    for note in notes:
        print(f"      ⚠️  {name}: {note}")

    # KIỂM CHỨNG — bất biến duy nhất thật sự quan trọng: mã hóa lại ký tự vừa giải mã ra phải
    # cho lại đúng byte ban đầu. Nếu không thì mở file rồi lưu lại sẽ đổi nội dung.
    broken = []
    for byte in range(0x00, 0x100):
        code_point = table[byte]
        if code_point == UNASSIGNED:
            continue
        encoded = iconv_encode(encoding, chr(code_point))
        if encoded != bytes([byte]):
            got = encoded.hex() if encoded else "không mã hóa được"
            broken.append((byte, code_point, got))

    assigned = sum(1 for value in table if value != UNASSIGNED)
    print(f"  {name:12s} {assigned:3d}/256 byte có nghĩa · {len(broken)} byte không khứ hồi được")
    for byte, code_point, got in broken[:10]:
        print(f"      {byte:#04x} → U+{code_point:04X} → {got}")
    if broken:
        raise SystemExit(f"❌ {name}: bảng không khứ hồi được, KHÔNG ghi ra file")

    return table


def build_cp1258() -> list[int]:
    """CP1258 có hai hiện thực độc lập trên máy — dùng cả hai và bắt chúng khớp."""
    table = build_table("CP1258", "CP1258")
    for byte in range(0x00, 0x100):
        try:
            python_cp = ord(bytes([byte]).decode("cp1258"))
        except (UnicodeDecodeError, TypeError):
            python_cp = UNASSIGNED
        if table[byte] != python_cp:
            raise SystemExit(
                f"❌ CP1258 byte {byte:#04x}: iconv cho U+{table[byte]:04X}, "
                f"Python cho U+{python_cp:04X}"
            )
    print("  CP1258       iconv và Python cho kết quả giống hệt trên cả 256 byte")
    return table


def build_composition(tables: dict[str, list[int]]) -> list[tuple[int, int, int]]:
    """Bảng kết hợp (chữ nền, dấu tổ hợp) → chữ dựng sẵn.

    Vì sao cần: TCVN3 và CP1258 mã hóa "ế" thành hai byte — chữ nền rồi dấu thanh. Giải mã
    thô ra chuỗi tổ hợp, trong khi người dùng gõ "ế" bằng bàn phím tiếng Việt ra dạng dựng
    sẵn. Hai dạng khác byte nhau ⇒ tìm kiếm trượt, diff báo khác, khóa CSV so sai. Nên codec
    phải kết hợp NGAY LÚC GIẢI MÃ.

    Bảng suy từ chính chuẩn hóa NFC của Unicode (qua `unicodedata` của Python), không gõ tay.
    """
    import unicodedata

    marks = sorted({
        cp for table in tables.values() for cp in table
        if cp != UNASSIGNED and unicodedata.combining(chr(cp))
    })
    bases = sorted({
        cp for table in tables.values() for cp in table
        if cp != UNASSIGNED and not unicodedata.combining(chr(cp)) and chr(cp).isalpha()
    })

    pairs = []
    for base in bases:
        for mark in marks:
            composed = unicodedata.normalize("NFC", chr(base) + chr(mark))
            if len(composed) == 1:
                pairs.append((base, mark, ord(composed)))
    print(f"  kết hợp      {len(pairs)} cặp (chữ nền × dấu) từ {len(bases)} chữ nền, {len(marks)} dấu")
    return pairs


def swift_composition(pairs: list[tuple[int, int, int]]) -> str:
    lines = [
        "    /// (chữ nền, dấu tổ hợp) → chữ dựng sẵn. Sắp theo khóa để tra bằng tìm nhị phân.",
        "    static let composition: [(base: UInt32, mark: UInt32, composed: UInt32)] = [",
    ]
    for base, mark, composed in sorted(pairs):
        lines.append(f"        (0x{base:04X}, 0x{mark:04X}, 0x{composed:04X}),")
    lines.append("    ]")
    return "\n".join(lines)


def swift_table(name: str, table: list[int]) -> str:
    lines = [f"    static let {name}: [UInt32] = ["]
    for start in range(0, 256, 8):
        row = ", ".join(
            "unassigned" if value == UNASSIGNED else f"0x{value:04X}"
            for value in table[start:start + 8]
        )
        lines.append(f"        {row},  // {start:#04x}")
    lines.append("    ]")
    return "\n".join(lines)


SAMPLES = [
    "Tiếng Việt",
    "Cộng hòa Xã hội Chủ nghĩa Việt Nam",
    "Thừa Thiên Huế",
    "Đà Nẵng, Quảng Ngãi, Bà Rịa – Vũng Tàu",
    "công ty anh đào",
    "ĐƠN HÀNG DH-0091",
    "abcdef 0123456789",
]


def build_fixtures(encodings: dict[str, str]) -> str:
    """Sinh fixture test: chuỗi mẫu + byte tương ứng, do chính iconv cho ra.

    Đây là bên đối chứng ĐỘC LẬP với bảng: test Swift so kết quả codec của ta với byte mà
    bộ chuyển đổi hệ thống sinh ra, chứ không so bảng với chính nó.
    """
    lines = [
        "// SINH TỰ ĐỘNG bởi scripts/generate-encoding-tables.py — đừng sửa tay.",
        "//",
        "// Mỗi mục là một chuỗi tiếng Việt cùng dãy byte mà `iconv` của hệ thống sinh ra cho",
        "// bảng mã tương ứng. Test dùng nó làm bên đối chứng độc lập với bảng trong sản phẩm.",
        "",
        "enum LegacyEncodingFixtures {",
        "    struct Sample {",
        "        let text: String",
        "        let bytes: [UInt8]",
        "    }",
        "",
    ]
    for swift_name, encoding in encodings.items():
        entries = []
        for sample in SAMPLES:
            encoded = iconv_encode(encoding, sample)
            if encoded is None:
                continue
            # Loại mẫu mà iconv âm thầm THAY ký tự: nó đổi gạch ngang dài "–" thành "-" khi
            # bảng mã không có ký tự đó. Mẫu như vậy sẽ bắt codec của ta bắt chước một phép
            # thay thế thầm lặng — đúng thứ ta cố ý KHÔNG làm.
            #
            # Kiểm theo TỪNG KÝ TỰ và so ở dạng NFC, vì hai lý do:
            #   · ASCII luôn đúng theo định nghĩa, mà bộ giải mã TCVN của macOS lại làm hỏng
            #     nó — kiểm cả câu sẽ loại nhầm mọi mẫu có chữ cái ASCII.
            #   · CP1258 giải mã ra dạng tổ hợp; khác dạng chuẩn hóa không phải là mất dữ liệu.
            substituted = next(
                (
                    character for character in sample
                    if ord(character) >= 0x80 and (
                        (single := iconv_encode(encoding, character)) is None
                        or unicodedata.normalize("NFC", iconv_decode(encoding, single) or "")
                        != unicodedata.normalize("NFC", character)
                    )
                ),
                None,
            )
            if substituted is not None:
                print(f"      bỏ mẫu chứa ký tự {encoding} không có ({substituted!r}): {sample[:40]}")
                continue
            byte_list = ", ".join(f"0x{b:02X}" for b in encoded)
            entries.append(f'        Sample(text: "{sample}", bytes: [{byte_list}]),')
        lines.append(f"    static let {swift_name}: [Sample] = [")
        lines.extend(entries)
        lines.append("    ]")
        lines.append("")
    lines.append("}")
    return "\n".join(lines)


def main() -> None:
    check_only = "--check" in sys.argv

    print("▸ Suy bảng mã từ bộ chuyển đổi của hệ thống…")
    tables = {
        "tcvn3": build_table("TCVN3", "TCVN-5712-1:1993"),
        "viscii": build_table("VISCII", "VISCII"),
        "windows1258": build_cp1258(),
    }

    header = '''// SINH TỰ ĐỘNG bởi scripts/generate-encoding-tables.py — đừng sửa tay.
//
// Bảng mã tiếng Việt legacy (FR-ENC-201). Mỗi bảng ánh xạ 256 giá trị byte sang điểm mã
// Unicode; `unassigned` nghĩa là byte đó không có nghĩa trong bảng mã ấy.
//
// Bảng được SUY RA từ bộ chuyển đổi có sẵn trên máy (iconv, và với CP1258 thì thêm codec
// của Python), theo hai chiều độc lập rồi bắt hai chiều khớp nhau — không ô nào gõ tay.
// Lý do và cách kiểm chứng: xem đầu scripts/generate-encoding-tables.py.

enum LegacyEncodingTables {

    /// Byte không có nghĩa trong bảng mã.
    static let unassigned: UInt32 = 0xFFFF_FFFF

'''
    composition = build_composition(tables)
    body = "\n\n".join(swift_table(name, table) for name, table in tables.items())
    body += "\n\n" + swift_composition(composition)
    swift = header + body + "\n}\n"

    fixtures = build_fixtures({
        "tcvn3": "TCVN-5712-1:1993",
        "viscii": "VISCII",
        "windows1258": "CP1258",
    })

    if check_only:
        current = SWIFT_OUT.read_text() if SWIFT_OUT.exists() else ""
        if current != swift:
            raise SystemExit("❌ LegacyEncodingTables.swift đã lệch so với bảng sinh lại")
        print("✅ Bảng trong repo khớp với bộ chuyển đổi của hệ thống")
        return

    SWIFT_OUT.write_text(swift)
    FIXTURE_OUT.write_text(fixtures + "\n")
    print(f"▸ Đã ghi {SWIFT_OUT.relative_to(ROOT)}")
    print(f"▸ Đã ghi {FIXTURE_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
