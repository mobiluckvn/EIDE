#!/usr/bin/env python3
"""Nhúng truy vấn tô màu của tree-sitter vào mã nguồn Swift (FR-FMT-501, ADR-04).

Vì sao SINH MÃ chứ không đọc file lúc chạy: PoC-D đọc `highlights.scm` thẳng từ thư mục
nguồn, và bản phát hành trên máy người dùng sẽ không tìm thấy gì ở đó. Đưa vào tài nguyên
bundle thì được, nhưng lại buộc mọi chỗ dùng phải qua `Bundle.module` — kể cả test và công cụ
dòng lệnh, nơi bundle không phải lúc nào cũng có. Chuỗi hằng trong mã nguồn thì không có chỗ
nào để hỏng.

Đây cũng là nếp đã dùng cho bảng bảng mã (`generate-vni-table.py`).

    scripts/generate-highlight-queries.py
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
QUERIES = ROOT / "Sources/TreeSitter/vendor/queries"
OUT = ROOT / "Sources/GEditorCore/Syntax/HighlightQueries.swift"


def swift_literal(text: str) -> str:
    """Chuỗi Swift nhiều dòng. Dùng dấu ngoặc mở rộng để khỏi phải thoát gì cả.

    Truy vấn tô màu đầy dấu ngoặc kép, gạch chéo ngược và ký tự đặc biệt của regex — thoát tay
    là cách chắc chắn để một dấu lọt lưới và cả truy vấn hỏng lặng lẽ."""
    # Chọn số dấu # đủ nhiều để không đụng nội dung.
    hashes = "#"
    while '"' + hashes in text or hashes + '"' in text:
        hashes += "#"
    return f'{hashes}"""\n{text}\n"""{hashes}'


def main() -> int:
    if not QUERIES.is_dir():
        print(f"không thấy {QUERIES} — chạy scripts/vendor-tree-sitter.sh trước", file=sys.stderr)
        return 1

    files = sorted(QUERIES.glob("*.scm"))
    if not files:
        print("không có file .scm nào", file=sys.stderr)
        return 1

    lines = [
        "// SINH TỰ ĐỘNG bởi scripts/generate-highlight-queries.py — KHÔNG sửa tay.",
        "//",
        "// Nguồn: Sources/TreeSitter/vendor/queries/*.scm, do chính upstream của mỗi grammar",
        "// phát hành. Sửa ở đây sẽ bị mất ở lần sinh lại; sửa grammar thì chạy lại script.",
        "",
        "enum HighlightQueries {",
        "",
        "    static let byLanguage: [String: String] = [",
    ]
    for path in files:
        text = path.read_text(encoding="utf-8").rstrip()
        lines.append(f'        "{path.stem}": {swift_literal(text)},')
    lines += ["    ]", "}", ""]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    total = sum(len(p.read_text(encoding="utf-8")) for p in files)
    print(f"▸ {len(files)} ngôn ngữ, {total // 1024} KB truy vấn → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
