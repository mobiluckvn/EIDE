/*
 * config.h cho liblzma 5.6.3 trong GEditor.
 *
 * GEDITOR_VENDOR_VERSION "5.6.3"   ← scripts/vendor-libarchive.sh kiểm dòng này
 *
 * ============================================================================
 * ĐÂY LÀ TỆP CỦA GEDITOR, VIẾT TAY — KHÔNG PHẢI SẢN PHẨM CỦA ./configure
 * ============================================================================
 *
 * `./configure` của xz sinh ra 197 định nghĩa. liblzma chỉ thật sự ĐỌC 42 trong số đó, và
 * 42 dòng thì soát tay được từng dòng một. Đó là lý do thứ nhất.
 *
 * Lý do thứ hai nặng hơn: CVE-2024-3094 — cửa hậu xz 5.6.0/5.6.1 — được chèn vào lúc
 * `autoconf` chạy, qua `build-to-host.m4` của gói tarball, chứ không nằm trong tệp `.c` nào.
 * 5.6.3 đã sạch, nhưng cách chắc chắn nhất để vector ấy không tồn tại là KHÔNG chạy hệ build
 * của upstream. scripts/vendor-libarchive.sh vì thế chỉ chép `.c` và `.h`.
 *
 * Danh sách 42 macro dưới đây rút ra bằng cách quét toàn bộ nguồn liblzma tìm mọi tên macro
 * cấu hình được tham chiếu, rồi đối chiếu với cấu hình:
 *
 *   --disable-encoders
 *   --enable-decoders=lzma1,lzma2,delta,x86,powerpc,ia64,arm,armthumb,sparc,arm64,riscv
 *   --enable-checks=crc32,crc64,sha256
 *   --disable-threads --disable-nls
 *
 * Mọi macro KHÔNG có ở đây đều ở trạng thái chưa định nghĩa, và đó là chủ ý.
 */

#ifndef GEDITOR_LZMA_CONFIG_H
#define GEDITOR_LZMA_CONFIG_H

/* ---- Header chuẩn mà sysdefs.h hỏi tới ---- */
#define HAVE_INTTYPES_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDBOOL_H 1
#define HAVE__BOOL 1
#define HAVE_SYS_PARAM_H 1

/* ---- Bộ giải mã. KHÔNG có HAVE_ENCODER_* nào: GEditor chỉ đọc kho nén ---- */
#define HAVE_DECODERS 1
#define HAVE_DECODER_LZMA1 1
#define HAVE_DECODER_LZMA2 1
#define HAVE_DECODER_DELTA 1

/*
 * Bộ lọc "simple" — chúng đảo lại phép biến đổi lệnh nhảy mà bộ nén đã áp lên mã máy.
 * Phải bật ĐỦ CẢ MƯỜI, không phải chỉ hai kiến trúc macOS chạy: một kho .7z do người khác
 * tạo trên Linux ARM hay đóng gói firmware RISC-V vẫn phải mở được trên máy Mac. Bộ lọc
 * chạy trên luồng byte, nó không cần CPU cùng loại.
 */
#define HAVE_DECODER_X86 1
#define HAVE_DECODER_ARM 1
#define HAVE_DECODER_ARM64 1
#define HAVE_DECODER_ARMTHUMB 1
#define HAVE_DECODER_POWERPC 1
#define HAVE_DECODER_IA64 1
#define HAVE_DECODER_SPARC 1
#define HAVE_DECODER_RISCV 1

/* Định dạng .lz của lzip — cùng bộ giải mã LZMA1, gần như không tốn thêm mã. */
#define HAVE_LZIP_DECODER 1

/* ---- Phép kiểm toàn vẹn ---- */
#define HAVE_CHECK_CRC32 1
#define HAVE_CHECK_CRC64 1
#define HAVE_CHECK_SHA256 1

/*
 * Lệnh CRC32 của ARMv8. Chỉ được bật khi ĐANG dựng cho arm64.
 *
 * `swift build --arch arm64 --arch x86_64` chạy trình biên dịch HAI lượt trên cùng tệp
 * config.h này. Đặt macro vô điều kiện thì lượt x86_64 sẽ kéo vào `crc32_arm64.h` và đứt.
 * Đây là khác biệt duy nhất giữa hai kiến trúc trong cả tệp.
 */
#if defined(__aarch64__)
#define HAVE_ARM64_CRC32 1
#endif

/* ---- Thuộc tính và built-in của trình biên dịch (clang có đủ) ---- */
#define HAVE_VISIBILITY 1
#define HAVE_FUNC_ATTRIBUTE_CONSTRUCTOR 1
#define HAVE___BUILTIN_ASSUME_ALIGNED 1
#define HAVE___BUILTIN_BSWAPXX 1

/* ---- Hàm hệ thống ---- */
#define HAVE_CLOCK_GETTIME 1
#define HAVE_CLOCK_MONOTONIC 1
#define HAVE_MBRTOWC 1
#define HAVE_WCWIDTH 1
#define HAVE_SYSCTLBYNAME 1

/*
 * macOS là LP64 ở CẢ arm64 lẫn x86_64, nên một con số đúng cho cả hai lượt dựng universal.
 * NFR-PORT-02 chốt macOS 12 trở lên — không còn bản 32-bit nào để lệch.
 */
#define SIZEOF_SIZE_T 8

/* Truy cập không căn lề: cả arm64 lẫn x86_64 đều làm được bằng phần cứng. */
#define TUKLIB_FAST_UNALIGNED_ACCESS 1
#define TUKLIB_PHYSMEM_SYSCONF 1
#define TUKLIB_CPUCORES_SYSCTL 1

/*
 * KHÔNG định nghĩa MYTHREAD_*: liblzma dựng ở chế độ một luồng. GEditor giải nén trên hàng
 * đợi nền của chính mình, thêm một tầng luồng nữa bên trong thư viện chỉ làm khó việc huỷ
 * giữa chừng.
 *
 * KHÔNG định nghĩa NDEBUG: bản dựng debug phải giữ `assert` của liblzma. SwiftPM tự thêm
 * -DNDEBUG cho bản release, nên chốt cứng ở đây là tắt luôn cả ở bản debug.
 *
 * KHÔNG định nghĩa ENABLE_NLS: liblzma không dịch chuỗi lỗi; GEditor tự viết câu tiếng Việt.
 */

/* Chuỗi định danh — `lzma_version_string()` trả về PACKAGE_VERSION. */
#define PACKAGE "xz"
#define PACKAGE_NAME "XZ Utils"
#define PACKAGE_TARNAME "xz"
#define PACKAGE_VERSION "5.6.3"
#define PACKAGE_STRING "XZ Utils 5.6.3"
#define PACKAGE_URL "https://tukaani.org/xz/"
#define PACKAGE_BUGREPORT "xz@tukaani.org"

#endif /* GEDITOR_LZMA_CONFIG_H */
