// Dispatch nhánh mã tối ưu theo kiến trúc CPU tại runtime (SRS §3.1.2, SAD §2.3).
//
// Nguyên tắc: cùng một binary universal chứa cả hai nhánh; lựa chọn xảy ra lúc chạy,
// không phải lúc build. Nhánh scalar luôn tồn tại và là chuẩn đối chứng đúng-sai
// cho các nhánh vector (xem GEditorCoreTests/SIMDDispatchTests).

#include "include/geditor_simd.h"

#include <string.h>

#if defined(__aarch64__)
#include <arm_neon.h>
#elif defined(__x86_64__)
#include <immintrin.h>
#endif

// ---------------------------------------------------------------- scalar

static size_t count_newlines_scalar(const uint8_t *buf, size_t len) {
    size_t n = 0;
    for (size_t i = 0; i < len; i++) {
        if (buf[i] == (uint8_t)'\n') n++;
    }
    return n;
}

// ------------------------------------------------------------------ NEON

#if defined(__aarch64__)
// NEON là baseline của arm64 — không cần kiểm tra runtime.
static size_t count_newlines_neon(const uint8_t *buf, size_t len) {
    size_t i = 0;
    uint64_t total = 0;
    const uint8x16_t nl = vdupq_n_u8((uint8_t)'\n');

    // Mỗi vòng cộng dồn tối đa 16 khối × giá trị 1 → an toàn trong uint8 lane.
    while (i + 16 * 16 <= len) {
        uint8x16_t acc = vdupq_n_u8(0);
        for (int k = 0; k < 16; k++) {
            uint8x16_t chunk = vld1q_u8(buf + i + (size_t)k * 16);
            // vceqq trả 0xFF khi khớp; trừ đi (tức cộng 1) để đếm.
            acc = vsubq_u8(acc, vceqq_u8(chunk, nl));
        }
        total += vaddlvq_u8(acc);
        i += 16 * 16;
    }
    while (i + 16 <= len) {
        uint8x16_t chunk = vld1q_u8(buf + i);
        uint8x16_t m = vceqq_u8(chunk, nl);
        total += vaddlvq_u8(vsubq_u8(vdupq_n_u8(0), m));
        i += 16;
    }
    return (size_t)total + count_newlines_scalar(buf + i, len - i);
}
#endif

// ------------------------------------------------------------------ AVX2

#if defined(__x86_64__)
__attribute__((target("avx2")))
static size_t count_newlines_avx2(const uint8_t *buf, size_t len) {
    size_t i = 0;
    size_t total = 0;
    const __m256i nl = _mm256_set1_epi8('\n');

    while (i + 32 <= len) {
        __m256i chunk = _mm256_loadu_si256((const __m256i *)(buf + i));
        __m256i m = _mm256_cmpeq_epi8(chunk, nl);
        total += (size_t)__builtin_popcount((unsigned)_mm256_movemask_epi8(m));
        i += 32;
    }
    return total + count_newlines_scalar(buf + i, len - i);
}

static int has_avx2(void) {
    static int cached = -1;
    if (cached < 0) {
        __builtin_cpu_init();
        cached = __builtin_cpu_supports("avx2") ? 1 : 0;
    }
    return cached;
}
#endif

// -------------------------------------------------------------- công khai

const char *geditor_simd_backend(void) {
#if defined(__aarch64__)
    return "neon";
#elif defined(__x86_64__)
    return has_avx2() ? "avx2" : "scalar";
#else
    return "scalar";
#endif
}

size_t geditor_count_newlines(const uint8_t *buf, size_t len) {
    if (buf == NULL || len == 0) return 0;
#if defined(__aarch64__)
    return count_newlines_neon(buf, len);
#elif defined(__x86_64__)
    if (has_avx2()) return count_newlines_avx2(buf, len);
    return count_newlines_scalar(buf, len);
#else
    return count_newlines_scalar(buf, len);
#endif
}

static ptrdiff_t find_non_ascii_scalar(const uint8_t *buf, size_t len, size_t from) {
    for (size_t i = from; i < len; i++) {
        if (buf[i] & 0x80) return (ptrdiff_t)i;
    }
    return -1;
}

#if defined(__x86_64__)
// Phải là hàm RIÊNG có target("avx2"): dùng __m256i trong một hàm biên dịch cho baseline
// x86_64 làm đổi ABI truyền tham số, và clang từ chối biên dịch. Lỗi này chỉ lộ ra khi build
// universal — bản arm64 biên dịch bỏ cả nhánh đi.
__attribute__((target("avx2")))
static ptrdiff_t find_non_ascii_avx2(const uint8_t *buf, size_t len) {
    size_t i = 0;
    while (i + 32 <= len) {
        __m256i chunk = _mm256_loadu_si256((const __m256i *)(buf + i));
        // movemask gom thẳng bit cao của từng byte — đúng thứ cần, không cần so sánh.
        int mask = _mm256_movemask_epi8(chunk);
        if (mask != 0) return (ptrdiff_t)(i + (size_t)__builtin_ctz((unsigned)mask));
        i += 32;
    }
    return find_non_ascii_scalar(buf, len, i);
}
#endif

ptrdiff_t geditor_find_non_ascii(const uint8_t *buf, size_t len) {
    if (buf == NULL || len == 0) return -1;

#if defined(__aarch64__)
    size_t i = 0;
    // NEON không có movemask; vmaxvq_u8 cho biết khối 16 byte có byte nào ≥ 0x80 hay không,
    // và chỉ khi CÓ mới phải quét scalar trong đúng khối đó.
    while (i + 16 <= len) {
        uint8x16_t chunk = vld1q_u8(buf + i);
        if (vmaxvq_u8(chunk) >= 0x80) {
            return find_non_ascii_scalar(buf, i + 16, i);
        }
        i += 16;
    }
    return find_non_ascii_scalar(buf, len, i);
#elif defined(__x86_64__)
    if (has_avx2()) return find_non_ascii_avx2(buf, len);
    return find_non_ascii_scalar(buf, len, 0);
#else
    return find_non_ascii_scalar(buf, len, 0);
#endif
}

ptrdiff_t geditor_find_byte(const uint8_t *buf, size_t len, uint8_t needle) {
    if (buf == NULL || len == 0) return -1;
    // memchr của libc trên macOS đã là bản vector hóa theo kiến trúc.
    const void *p = memchr(buf, needle, len);
    return p == NULL ? -1 : (ptrdiff_t)((const uint8_t *)p - buf);
}
