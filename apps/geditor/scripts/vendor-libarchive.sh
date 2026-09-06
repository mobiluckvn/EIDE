#!/bin/bash
# Nạp mã nguồn libarchive + liblzma vào Sources/LibArchive và Sources/LZMA.
#
# ============================================================================
# VÌ SAO VENDOR, KHI macOS ĐÃ CÓ SẴN libarchive
# ============================================================================
#
# `/usr/lib/libarchive.2.dylib` có thật, và trong SDK còn có cả `libarchive.tbd` để link.
# Nhưng SDK **không kèm `archive.h`**. Không header nghĩa là không có hợp đồng API: muốn gọi
# thì phải tự khai nguyên mẫu hàm, tức tự đoán một ABI mà Apple chưa từng hứa giữ nguyên.
# Đúng lý do đã loại `/usr/lib/libpcre2-8.dylib` ở scripts/vendor-pcre2.sh.
#
# Đường cũ — gọi `/usr/bin/tar` như tiến trình con — thì chạy được, nhưng chỉ ở bản tải trực
# tiếp. Bản App Store phát hành trước, và nó cần ĐỦ tính năng, nên phải tự chứa.
#
# `zlib` và `bzip2` thì KHÔNG vendor: `zlib.h` và `bzlib.h` nằm sẵn trong SDK, tức Apple có
# khai chúng là API công khai. Chỉ cần `-lz -lbz2`.
#
# ============================================================================
# VÌ SAO SCRIPT NÀY KHÔNG CHẠY HỆ BUILD CỦA UPSTREAM
# ============================================================================
#
# Nó chỉ CHÉP tệp `.c` và `.h`. Không `configure`, không `cmake`, không `make`, không đụng
# tới `.m4` hay `.sh` của upstream.
#
# Đây không phải sự cẩn thận chung chung. CVE-2024-3094 — cửa hậu xz 5.6.0/5.6.1 — nằm đúng
# ở đó: mã độc được chèn vào lúc `autoconf` chạy `build-to-host.m4` của gói tarball, chứ
# không nằm trong tệp `.c` nào. Chép nguồn rồi tự biên dịch thì vector ấy không tồn tại.
#
# Hệ quả: hai tệp `config.h` không do script này sinh. Xem phần dưới.
#
# ============================================================================
# HAI TỆP config.h
# ============================================================================
#
# libarchive cần 401 định nghĩa, liblzma cần 197 — quá nhiều để viết tay cho đúng. Chúng nằm
# ở `Sources/LibArchive/config/config.h` và `Sources/LZMA/config/config.h`, là tệp **của
# GEditor** chứ không phải của upstream, nên nằm NGOÀI `vendor/`. Đầu mỗi tệp ghi rõ lệnh đã
# sinh ra nó và từng dòng đã sửa tay sau đó.
#
# Script này không ghi đè chúng; nó chỉ KIỂM phiên bản ghi trong đó có khớp phiên bản đang nạp
# không, và báo đỏ nếu lệch — để một lần nâng phiên bản không lặng lẽ dùng lại cấu hình cũ.
#
#   scripts/vendor-libarchive.sh              nạp phiên bản mặc định
#   scripts/vendor-libarchive.sh 3.7.7 5.6.3  nạp phiên bản chỉ định
set -euo pipefail

cd "$(dirname "$0")/.."

LA_VERSION="${1:-3.7.7}"
XZ_VERSION="${2:-5.6.3}"

LA_URL="https://github.com/libarchive/libarchive/releases/download/v${LA_VERSION}/libarchive-${LA_VERSION}.tar.gz"
XZ_URL="https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/xz-${XZ_VERSION}.tar.gz"

# Băm của đúng hai gói đã dựng và thử. Nếu nâng phiên bản thì đổi cả hai dòng này — và phải
# đối chiếu với con số upstream công bố, chứ không phải với con số máy mình vừa tải về.
LA_SHA256="4cc540a3e9a1eebdefa1045d2e4184831100667e6d7d5b315bb1cbc951f8ddff"
XZ_SHA256="b1d45295d3f71f25a4c9101bd7c8d16cb56348bbef3bbc738da0351e17c73317"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

tai() {  # tai <url> <sha256> <tên tệp>
    local url="$1" want="$2" out="$WORK/$3"
    echo "▸ Tải $(basename "$url")…"
    curl -sSL --fail -o "$out" "$url"
    local got
    got="$(shasum -a 256 "$out" | cut -d' ' -f1)"
    if [ "$got" != "$want" ]; then
        echo "❌ Băm không khớp cho $(basename "$url")" >&2
        echo "   mong đợi: $want" >&2
        echo "   nhận được: $got" >&2
        exit 1
    fi
    tar xzf "$out" -C "$WORK"
}

tai "$LA_URL" "$LA_SHA256" "libarchive.tar.gz"
tai "$XZ_URL" "$XZ_SHA256" "xz.tar.gz"

LA_SRC="$WORK/libarchive-${LA_VERSION}/libarchive"
XZ_SRC="$WORK/xz-${XZ_VERSION}/src"

# ============================================================================
# liblzma — CHỈ phần giải mã
# ============================================================================
#
# Danh sách này là các đơn vị biên dịch mà chính hệ build của xz chọn khi cấu hình:
#
#   --disable-encoders
#   --enable-decoders=lzma1,lzma2,delta,x86,powerpc,ia64,arm,armthumb,sparc,arm64,riscv
#   --enable-checks=crc32,crc64,sha256
#   --disable-threads
#
# GEditor chỉ ĐỌC kho nén, nên không cần một dòng mã nén nào. Bỏ chúng đi vừa nhỏ bundle vừa
# bớt đúng ngần ấy bề mặt tấn công.

LZ_DEST="Sources/LZMA/vendor/src"
echo "▸ Nạp liblzma ${XZ_VERSION} vào ${LZ_DEST}…"
rm -rf "$LZ_DEST"

LZ_UNITS=(
    check/check.c check/crc32_fast.c check/crc32_table.c
    check/crc64_fast.c check/crc64_table.c check/sha256.c
    common/alone_decoder.c common/auto_decoder.c common/block_buffer_decoder.c
    common/block_decoder.c common/block_header_decoder.c common/block_util.c
    common/common.c common/easy_decoder_memusage.c common/easy_preset.c
    common/file_info.c common/filter_buffer_decoder.c common/filter_common.c
    common/filter_decoder.c common/filter_flags_decoder.c common/hardware_physmem.c
    common/index.c common/index_decoder.c common/index_hash.c
    common/lzip_decoder.c common/microlzma_decoder.c common/stream_buffer_decoder.c
    common/stream_decoder.c common/stream_flags_common.c common/stream_flags_decoder.c
    common/string_conversion.c common/vli_decoder.c common/vli_size.c
    delta/delta_common.c delta/delta_decoder.c
    lz/lz_decoder.c
    lzma/lzma2_decoder.c lzma/lzma_decoder.c lzma/lzma_encoder_presets.c
    simple/arm.c simple/arm64.c simple/armthumb.c simple/ia64.c simple/powerpc.c
    simple/riscv.c simple/simple_coder.c simple/simple_decoder.c simple/sparc.c
    simple/x86.c
)

for unit in "${LZ_UNITS[@]}"; do
    mkdir -p "$LZ_DEST/liblzma/$(dirname "$unit")"
    cp "$XZ_SRC/liblzma/$unit" "$LZ_DEST/liblzma/$unit"
done

# `lzma_encoder_presets.c` nằm trong danh sách dù ta không nén: `lzma_lzma_preset()` là thứ
# `common/easy_preset.c` và bộ giải mã `.lzma` cũ gọi để dựng tham số cửa sổ. Nó chỉ điền một
# struct, không chứa mã nén.

# `tuklib_physmem.c` nằm ở src/common, NGOÀI thư mục liblzma — nên phải chép riêng.
# `hardware_physmem.c` gọi nó để giới hạn bộ nhớ giải nén theo RAM thật của máy.
mkdir -p "$LZ_DEST/common"
cp "$XZ_SRC/common/tuklib_physmem.c" "$LZ_DEST/common/"

# Toàn bộ header. Chỉ tệp .c mới được biên dịch, nên chép dư header không sinh mã dư — mà
# thiếu một header thì bản dựng đứt ở chỗ khó đoán.
( cd "$XZ_SRC" && find liblzma common -name "*.h" -print0 ) |
    while IFS= read -r -d '' h; do
        mkdir -p "$LZ_DEST/$(dirname "$h")"
        cp "$XZ_SRC/$h" "$LZ_DEST/$h"
    done

# ============================================================================
# libarchive — CHỈ phần đọc, và chỉ những định dạng đã chọn
# ============================================================================
#
# Ba nhóm bị bỏ, mỗi nhóm một lý do khác nhau:
#
# 1. `archive_write*` — GEditor không tạo kho nén. Bỏ nguyên nửa thư viện.
#
# 2. `archive_read_support_filter_program.c` + `filter_fork_posix.c` + `archive_cmdline.c` —
#    bộ lọc này SINH TIẾN TRÌNH CON để giải nén (gọi `gzip -d`, `unlzma`…). Nó chính là thứ
#    cả lượt vendor này sinh ra để bỏ đi; giữ lại thì bản App Store vẫn còn đường spawn.
#    Kéo theo: bỏ luôn lz4/zstd/lzop/grzip/lrzip — trên macOS chúng KHÔNG có gì ngoài đường
#    gọi chương trình ngoài.
#
# 3. `archive_read_support_filter_all.c` và `..._format_all.c` — chúng đăng ký MỌI bộ lọc và
#    định dạng, kể cả nhóm 2. GEditor gọi thẳng từng hàm `archive_read_support_*` mình cần
#    (xem LibArchiveReader.swift), nên danh sách bật là một danh sách đọc được, không phải
#    "tất cả trừ những thứ tình cờ không link được".
#
# `archive_read_support_format_raw.c` cũng bị bỏ, vì nó nhận BẤT KỲ byte nào là một kho một
# mục. Có nó thì một tệp hỏng sẽ mở ra thành "kho hợp lệ có đúng một mục" thay vì báo lỗi.

LA_DEST="Sources/LibArchive/vendor/src"
echo "▸ Nạp libarchive ${LA_VERSION} vào ${LA_DEST}…"
rm -rf "$LA_DEST"
mkdir -p "$LA_DEST"

LA_UNITS=(
    # Hạ tầng
    archive_acl archive_check_magic archive_entry archive_entry_copy_stat
    archive_entry_sparse archive_entry_stat archive_entry_strmode archive_entry_xattr
    archive_options archive_rb archive_string archive_string_sprintf archive_util
    archive_version_details archive_virtual
    # Mật mã — kho zip/7z/rar có mật khẩu cần chúng để nhận ra và báo lỗi cho đúng
    archive_cryptor archive_digest archive_hmac archive_random
    archive_blake2s_ref archive_blake2sp_ref
    # Bộ giải nén dùng chung của 7z, rar và zip
    archive_ppmd7 archive_ppmd8
    # Khung đọc
    archive_read archive_read_add_passphrase archive_read_open_filename
    archive_read_open_memory archive_read_set_options
    # Bộ lọc — không cái nào gọi chương trình ngoài
    archive_read_support_filter_bzip2 archive_read_support_filter_compress
    archive_read_support_filter_gzip archive_read_support_filter_none
    archive_read_support_filter_xz
    # Định dạng
    archive_read_support_format_7zip archive_read_support_format_ar
    archive_read_support_format_cab archive_read_support_format_cpio
    archive_read_support_format_empty archive_read_support_format_iso9660
    archive_read_support_format_lha archive_read_support_format_rar
    archive_read_support_format_rar5 archive_read_support_format_tar
    archive_read_support_format_xar archive_read_support_format_zip
)

for unit in "${LA_UNITS[@]}"; do
    cp "$LA_SRC/${unit}.c" "$LA_DEST/"
done

# Header: chép hết, cùng lý do như liblzma.
cp "$LA_SRC"/*.h "$LA_DEST/"

# ============================================================================
# Kiểm phiên bản của hai tệp config.h
# ============================================================================

kiem_config() {  # kiem_config <đường dẫn> <phiên bản mong đợi> <tên>
    local path="$1" want="$2" ten="$3"
    if [ ! -f "$path" ]; then
        echo "❌ Thiếu $path" >&2
        exit 1
    fi
    if ! grep -q "GEDITOR_VENDOR_VERSION \"$want\"" "$path"; then
        local got
        got="$(grep -o 'GEDITOR_VENDOR_VERSION "[^"]*"' "$path" | head -1)"
        echo "❌ $ten: vừa nạp nguồn ${want}, nhưng $path còn ghi ${got:-không có dấu phiên bản}." >&2
        echo "   config.h phải sinh lại cho phiên bản mới — lệnh sinh ghi ở đầu chính tệp đó." >&2
        exit 1
    fi
    echo "   ✓ $ten config.h khớp phiên bản $want"
}

kiem_config "Sources/LZMA/config/config.h"       "$XZ_VERSION" "liblzma"
kiem_config "Sources/LibArchive/config/config.h" "$LA_VERSION" "libarchive"

echo
echo "✅ Đã nạp libarchive ${LA_VERSION} ($(ls "$LA_DEST"/*.c | wc -l | tr -d ' ') đơn vị)"
echo "   và liblzma ${XZ_VERSION} ($(find "$LZ_DEST" -name '*.c' | wc -l | tr -d ' ') đơn vị)."
echo "   Không tệp nào của upstream bị sửa; không script build nào của upstream được chạy."
