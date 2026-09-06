// geditor_simd.h — quét byte tốc độ cao với dispatch NEON/AVX2 tại runtime.
// SAD §2.3 (SIMDDispatch) · NFR-PORT-01 (một binary, hai kiến trúc) · NFR-PERF-*.

#ifndef GEDITOR_SIMD_H
#define GEDITOR_SIMD_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Tên nhánh mã đang được chọn tại runtime ("neon", "avx2", "scalar").
/// Dùng cho log chẩn đoán và cho test khẳng định đúng nhánh trên từng kiến trúc.
const char *geditor_simd_backend(void);

/// Đếm số byte '\n' trong [buf, buf+len).
size_t geditor_count_newlines(const uint8_t *buf, size_t len);

/// Trả offset của byte `needle` đầu tiên trong [buf, buf+len), hoặc -1 nếu không có.
/// Dùng cho quét delimiter CSV và tìm biên dòng.
///
/// Kiểu trả về là `ptrdiff_t` (có dấu) chứ không phải `size_t` + SIZE_MAX: sentinel
/// không dấu khi import sang Swift dễ bị so sánh nhầm Int/UInt và im lặng sai.
ptrdiff_t geditor_find_byte(const uint8_t *buf, size_t len, uint8_t needle);

/// Trả offset của byte KHÔNG PHẢI ASCII đầu tiên (bit cao bằng 1) trong [buf, buf+len),
/// hoặc -1 nếu toàn bộ là ASCII.
///
/// Dùng cho kiểm tính hợp lệ UTF-8: mọi byte < 0x80 tự nó đã là một ký tự hợp lệ, nên bộ
/// kiểm chỉ cần dừng lại ở những chỗ có byte nhiều byte. Văn bản mã nguồn và log gần như
/// toàn ASCII, nên hàm này biến phép kiểm O(n) scalar thành một lượt quét vector.
ptrdiff_t geditor_find_non_ascii(const uint8_t *buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* GEDITOR_SIMD_H */
