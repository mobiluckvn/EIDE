#!/bin/bash
# Nạp mã nguồn PCRE2 vào Sources/PCRE2 (ADR-03 · PoC-C).
#
# Vì sao vendor mã nguồn thay vì link thư viện hệ thống:
#   - macOS có /usr/lib/libpcre2-8.dylib nhưng KHÔNG kèm header công khai; đó là phụ thuộc
#     nội bộ của hệ thống, không phải API cho ứng dụng bên thứ ba.
#   - Bản Homebrew chỉ có kiến trúc của máy đang cài (ở đây: arm64), trong khi NFR-PORT-01
#     đòi MỘT bundle chứa native cho cả arm64 lẫn x86_64, không Rosetta.
#   Chỉ có vendor mã nguồn mới cho `swift build --arch arm64 --arch x86_64` ra universal.
#
# Không sửa một dòng nào của upstream. Mọi lựa chọn build (JIT, Unicode, bề rộng code unit)
# nằm trong Package.swift để nhìn thấy được, chứ không giấu trong config.h đã sửa tay.
#
#   scripts/vendor-pcre2.sh              nạp phiên bản mặc định
#   scripts/vendor-pcre2.sh 10.47        nạp phiên bản chỉ định
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-10.47}"
URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${VERSION}/pcre2-${VERSION}.tar.gz"
# Chỉ thư mục `vendor/` là mã upstream. `Sources/PCRE2/include/` là shim của GEditor
# (module map + header bọc) và KHÔNG bị script này đụng tới.
DEST="Sources/PCRE2/vendor"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ Tải PCRE2 ${VERSION}…"
curl -sSL --fail -o "$WORK/pcre2.tar.gz" "$URL"
tar xzf "$WORK/pcre2.tar.gz" -C "$WORK"
SRC="$WORK/pcre2-${VERSION}"

echo "▸ Nạp vào ${DEST}…"
rm -rf "$DEST"
mkdir -p "$DEST/src" "$DEST/include" "$DEST/deps/sljit"

# Chỉ lấy các đơn vị biên dịch của thư viện (COMMON_SOURCES trong Makefile.am).
# KHÔNG lấy pcre2test/pcre2grep/pcre2posix/fuzzsupport/jit_test/dftables/demo — chúng là
# công cụ dòng lệnh, kéo vào chỉ làm SwiftPM biên dịch nhầm và phình repo.
for unit in \
    pcre2_auto_possess pcre2_chkdint pcre2_compile pcre2_compile_cgroup \
    pcre2_compile_class pcre2_config pcre2_context pcre2_convert pcre2_dfa_match \
    pcre2_error pcre2_extuni pcre2_find_bracket pcre2_jit_compile pcre2_maketables \
    pcre2_match pcre2_match_data pcre2_match_next pcre2_newline pcre2_ord2utf \
    pcre2_pattern_info pcre2_script_run pcre2_serialize pcre2_string_utils \
    pcre2_study pcre2_substitute pcre2_substring pcre2_tables pcre2_ucd \
    pcre2_valid_utf pcre2_xclass
do
    cp "$SRC/src/${unit}.c" "$DEST/src/"
done

# Header nội bộ + các file .h chỉ để #include vào đơn vị khác.
cp "$SRC"/src/pcre2_compile.h "$SRC"/src/pcre2_internal.h "$SRC"/src/pcre2_intmodedep.h \
   "$SRC"/src/pcre2_ucp.h "$SRC"/src/pcre2_util.h \
   "$SRC"/src/pcre2_jit_char_inc.h "$SRC"/src/pcre2_jit_match_inc.h \
   "$SRC"/src/pcre2_jit_misc_inc.h "$SRC"/src/pcre2_jit_simd_inc.h \
   "$SRC"/src/pcre2_printint_inc.h "$SRC"/src/pcre2_ucptables_inc.h \
   "$DEST/src/"

# Ba file upstream để sẵn cho bản dựng không dùng autoconf/cmake, chép nguyên xi:
#   config.h.generic       — mọi macro SUPPORT_* ở trạng thái #undef, ta bật bằng -D trong
#                            Package.swift nên file này KHÔNG bị sửa.
#   pcre2.h.generic        — header công khai, đã điền sẵn số phiên bản.
#   pcre2_chartables.c.dist— bảng ký tự mặc định cho locale "C".
cp "$SRC/src/config.h.generic"        "$DEST/src/config.h"
cp "$SRC/src/pcre2.h.generic"         "$DEST/include/pcre2.h"
cp "$SRC/src/pcre2_chartables.c.dist" "$DEST/src/pcre2_chartables.c"

# sljit — trình sinh mã của JIT. pcre2_jit_compile.c #include thẳng sljitLir.c theo đường
# dẫn "../deps/sljit/sljit_src/sljitLir.c", nên phải giữ NGUYÊN cấu trúc thư mục này.
# Package.swift loại cả thư mục khỏi danh sách biên dịch (chúng chỉ được #include).
cp -R "$SRC/deps/sljit/sljit_src" "$DEST/deps/sljit/"
cp "$SRC/deps/sljit/LICENSE" "$DEST/deps/sljit/"

cp "$SRC/LICENCE.md" "$SRC/AUTHORS.md" "$DEST/"

cat > "$DEST/VENDORED.md" <<EOF
# PCRE2 ${VERSION} — mã nguồn nạp vào repo

Nguồn: <${URL}>

Thư mục này do \`scripts/vendor-pcre2.sh\` sinh ra và bị XÓA SẠCH mỗi lần chạy lại.
Shim của GEditor (module map + header bọc) nằm ở \`Sources/PCRE2/include/\`, không nằm ở đây.

**Không sửa một dòng nào của upstream.** Cập nhật bằng \`scripts/vendor-pcre2.sh <phiên bản>\`,
đừng vá tay — mọi thay đổi sẽ mất ở lần nạp sau.

Ba file được đổi tên khi chép (đây là cách upstream dành cho bản dựng không autoconf/cmake,
xem \`NON-AUTOTOOLS-BUILD\`):

| Trong bản phát hành | Trong repo |
|---|---|
| \`src/config.h.generic\` | \`src/config.h\` |
| \`src/pcre2.h.generic\` | \`include/pcre2.h\` |
| \`src/pcre2_chartables.c.dist\` | \`src/pcre2_chartables.c\` |

Mọi lựa chọn build (\`SUPPORT_JIT\`, \`SUPPORT_UNICODE\`, \`PCRE2_CODE_UNIT_WIDTH=8\`…) nằm
trong \`Package.swift\`, không nằm trong \`config.h\` — để nhìn một chỗ là biết đang bật gì.

Giấy phép: BSD 3-Clause, xem \`LICENCE.md\` (PCRE2) và \`deps/sljit/LICENSE\` (sljit).
Lý do vendor thay vì link thư viện hệ thống: xem đầu \`scripts/vendor-pcre2.sh\` và ADR-03.
EOF

echo "▸ Xong:"
echo "   $(find "$DEST" -name '*.c' | wc -l | tr -d ' ') file .c · $(find "$DEST" -name '*.h' | wc -l | tr -d ' ') file .h · $(du -sh "$DEST" | cut -f1)"
