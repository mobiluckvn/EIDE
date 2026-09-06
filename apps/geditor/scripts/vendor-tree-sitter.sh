#!/bin/bash
# Nạp mã nguồn tree-sitter và các grammar vào Sources/TreeSitter (ADR-04 · PoC-D).
#
# Vì sao vendor mã nguồn, cùng lý do đã dùng cho PCRE2:
#   - Bản Homebrew chỉ có kiến trúc của máy đang cài, trong khi NFR-PORT-01 đòi MỘT bundle
#     chứa native cho cả arm64 lẫn x86_64.
#   - SAD ADR-04 ghi rõ hệ quả phải quản: "ABI grammar .dylib universal". Vendor mã nguồn làm
#     biến mất vấn đề lệch ABI — grammar và lõi luôn dựng từ cùng một cây nguồn.
#
# CẢ HAI MƯƠI grammar đi vào Sources/TreeSitterHeavy, không vào Sources/TreeSitter: chúng
# thành một dylib nằm trong bundle, nạp bằng `dlopen` khi mở file đầu tiên cần tô màu (ADR-08
# §2.13). Sources/TreeSitter chỉ còn LÕI. Vẫn cùng một cây nguồn, vẫn ký cùng bundle — chỉ
# khác chỗ đặt.
#
# Không sửa một dòng nào của upstream.
#
#   scripts/vendor-tree-sitter.sh              nạp phiên bản mặc định
#   scripts/vendor-tree-sitter.sh 0.26.12      nạp phiên bản chỉ định
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.26.12}"
URL="https://codeload.github.com/tree-sitter/tree-sitter/tar.gz/refs/tags/v${VERSION}"

# Hai mươi ngôn ngữ của Phase 1 (FR-FMT-501).
#
# Dạng ghi: tên:org/repo:tag[:thư-mục-con]
#
#   - GHIM THEO TAG, không dùng nhánh master. Bản dựng phải tái lập được, và grammar sinh bằng
#     CLI đời khác lõi sẽ lệch ABI. Đã gặp: parser.c của nhánh master đòi `TSMapSlice` và
#     `TSLexerMode` mà lõi 0.26.12 chưa có, biên dịch hỏng ngay.
#   - Vài repo chứa NHIỀU grammar trong các thư mục con (php, typescript, xml); thư mục con
#     ghi ở trường thứ tư.
GRAMMARS=(
    bash:tree-sitter/tree-sitter-bash:v0.25.1
    c:tree-sitter/tree-sitter-c:v0.24.2
    cpp:tree-sitter/tree-sitter-cpp:v0.23.4
    csharp:tree-sitter/tree-sitter-c-sharp:v0.23.5
    css:tree-sitter/tree-sitter-css:v0.25.0
    go:tree-sitter/tree-sitter-go:v0.25.0
    html:tree-sitter/tree-sitter-html:v0.23.2
    java:tree-sitter/tree-sitter-java:v0.23.5
    javascript:tree-sitter/tree-sitter-javascript:v0.25.0
    json:tree-sitter/tree-sitter-json:v0.24.8
    lua:tree-sitter-grammars/tree-sitter-lua:v0.5.0
    php:tree-sitter/tree-sitter-php:v0.24.2:php
    python:tree-sitter/tree-sitter-python:v0.25.0
    ruby:tree-sitter/tree-sitter-ruby:v0.23.1
    rust:tree-sitter/tree-sitter-rust:v0.24.2
    toml:tree-sitter-grammars/tree-sitter-toml:v0.7.0
    typescript:tree-sitter/tree-sitter-typescript:v0.23.2:typescript
    xml:tree-sitter-grammars/tree-sitter-xml:v0.7.0:xml
    yaml:tree-sitter-grammars/tree-sitter-yaml:v0.7.2
    regex:tree-sitter/tree-sitter-regex:v0.25.0
)

DEST="Sources/TreeSitter/vendor"

# Mọi grammar tách sang dylib (ADR-08 §2.13): bảng tra chiếm 70,5 % binary đã liên kết, và
# `dlopen` gần như không phụ thuộc kích thước (~440 ms cố định + ~7 ms mỗi MB) nên dồn tất cả
# vào MỘT dylib rẻ hơn hẳn tách nhỏ theo từng ngôn ngữ.
#
# Danh sách này phải khớp `sources` của target TreeSitterHeavy trong Package.swift và
# `GrammarLibrary.symbolNames` trong lõi. Có bài kiểm canh cả ba khớp nhau.
DEST_HEAVY="Sources/TreeSitterHeavy"
HEAVY=(bash c cpp csharp css go html java javascript json lua php python regex ruby rust toml typescript xml yaml)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ Tải tree-sitter ${VERSION}…"
curl -sSL --fail -o "$WORK/ts.tar.gz" "$URL"
tar xzf "$WORK/ts.tar.gz" -C "$WORK"
SRC="$WORK/tree-sitter-${VERSION}"

echo "▸ Nạp lõi vào ${DEST}/lib…"
rm -rf "$DEST" "$DEST_HEAVY/grammars"
mkdir -p "$DEST/lib" "$DEST/grammars" "$DEST/queries" "$DEST_HEAVY/grammars"

# Toàn bộ lib/src và lib/include. Chỉ `lib.c` được biên dịch — nó `#include` thẳng mọi .c
# còn lại (amalgamation), nên biên dịch riêng từng file sẽ trùng ký hiệu.
cp -R "$SRC/lib/src" "$DEST/lib/src"
cp -R "$SRC/lib/include" "$DEST/lib/include"
cp "$SRC/LICENSE" "$DEST/LICENSE-tree-sitter"

FAILED=()
for entry in "${GRAMMARS[@]}"; do
    IFS=':' read -r name repo tag subdir <<< "$entry"
    short="${repo##*/}"
    echo "▸ Tải grammar ${name} (${repo} ${tag})…"
    if ! curl -sSL --fail -o "$WORK/g-$name.tar.gz" \
        "https://codeload.github.com/${repo}/tar.gz/refs/tags/${tag}"; then
        FAILED+=("$name: không tải được")
        continue
    fi
    tar xzf "$WORK/g-$name.tar.gz" -C "$WORK"
    ROOT="$WORK/${short}-${tag#v}"
    GSRC="$ROOT${subdir:+/$subdir}"

    if [ ! -f "$GSRC/src/parser.c" ]; then
        FAILED+=("$name: không thấy src/parser.c")
        continue
    fi

    # GIỮ NGUYÊN ĐÚNG SỐ BẬC thư mục của upstream.
    #
    # Bộ quét của typescript và xml `#include "../../common/scanner.h"` — header dùng chung
    # nằm ở GỐC REPO, trên thư mục grammar con một bậc. Nên cây ở đây phải là
    # `<tên>/g/src/scanner.c` cạnh `<tên>/common/scanner.h`, để `../../common` trỏ đúng chỗ.
    #
    # Hai lần sai trước khi đúng: chép phẳng vào một thư mục (mất hẳn common), rồi chép vào
    # `<tên>/src/` (đường `../../common` trỏ ra `grammars/common`, dùng chung giữa mọi grammar
    # — vừa không có file, vừa sẽ đụng nhau nếu có).
    # Grammar nặng đi sang target khác; truy vấn tô màu thì KHÔNG — chúng sinh vào
    # HighlightQueries.swift dùng chung, và chỗ đặt mã nguồn không đổi điều đó.
    target="$DEST"
    for heavy in "${HEAVY[@]}"; do
        [ "$name" = "$heavy" ] && target="$DEST_HEAVY"
    done

    mkdir -p "$target/grammars/$name/g"
    # Chép NGUYÊN thư mục src, không chọn lọc file.
    #
    # Chọn lọc là sai ba lần liên tiếp: bộ quét của yaml `#include "schema.core.c"`, và
    # `common/scanner.h` lại `#include "tree_sitter/parser.h"`. Không có cách nào đoán trước
    # grammar nào cần thêm file gì — upstream ship cả thư mục thì ta lấy cả thư mục.
    cp -R "$GSRC/src" "$target/grammars/$name/g/src"
    # Bỏ file mô tả grammar: chúng không phải mã nguồn, và để lại thì SwiftPM kêu ca về
    # "tài nguyên chưa khai báo".
    rm -f "$target/grammars/$name/g/src"/*.json

    # Header dùng chung của bộ quét, nếu repo có. Kèm một bản parser.h RIÊNG cho nó, vì
    # `common/scanner.h` cũng include `tree_sitter/parser.h`.
    if [ -d "$GSRC/../common" ]; then
        mkdir -p "$target/grammars/$name/common/tree_sitter"
        cp "$GSRC/../common"/*.h "$target/grammars/$name/common/" 2>/dev/null || true
        # Chép MỌI header trong src/tree_sitter, không riêng parser.h: common/scanner.h của
        # php còn cần `array.h`. Lại một lần nữa, chọn lọc là đoán.
        cp "$GSRC/src/tree_sitter"/*.h "$target/grammars/$name/common/tree_sitter/" 2>/dev/null || true
    fi

    # Truy vấn tô màu do chính upstream cung cấp — không tự viết lại, và không sửa.
    # Tìm ở thư mục con trước, rồi tới gốc repo.
    if [ -f "$GSRC/queries/highlights.scm" ]; then
        cp "$GSRC/queries/highlights.scm" "$DEST/queries/${name}.scm"
    elif [ -f "$ROOT/queries/highlights.scm" ]; then
        cp "$ROOT/queries/highlights.scm" "$DEST/queries/${name}.scm"
    elif [ -f "$ROOT/queries/${name}/highlights.scm" ]; then
        cp "$ROOT/queries/${name}/highlights.scm" "$DEST/queries/${name}.scm"
    else
        FAILED+=("$name: không thấy queries/highlights.scm")
    fi

    for license in LICENSE LICENSE.md LICENSE.txt; do
        [ -f "$ROOT/$license" ] && cp "$ROOT/$license" "$DEST/LICENSE-${name}" && break
    done
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "▸ CÓ VẤN ĐỀ:" >&2
    printf '   %s\n' "${FAILED[@]}" >&2
fi

cat > "$DEST/VENDORED.md" <<EOF
# tree-sitter ${VERSION} — mã nguồn nạp vào repo

Nguồn lõi: <${URL}>
Grammar (tên:repo:tag[:thư mục con]):
$(printf '  %s\n' "${GRAMMARS[@]}")

Nạp lại bằng \`scripts/vendor-tree-sitter.sh\`. KHÔNG sửa tay bất kỳ file nào trong thư mục
này — mọi lựa chọn biên dịch nằm ở Package.swift để nhìn thấy được.

Chỉ \`lib/src/lib.c\` được biên dịch: nó \`#include\` mọi đơn vị còn lại của lõi.
EOF

echo "▸ Xong. $(find "$DEST" -name '*.c' | wc -l | tr -d ' ') file .c, $(du -sh "$DEST" | cut -f1)"
