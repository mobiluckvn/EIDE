// Header bọc PCRE2 cho GEditor — điểm vào DUY NHẤT của phía Swift.
//
// GEditor làm việc trên byte UTF-8 (hợp đồng offset byte của toàn bộ lõi: piece table,
// line index, chỉ mục CSV), nên chỉ dựng thư viện ở bề rộng code unit 8 bit. Bản 16/32 bit
// không được biên dịch — xem danh sách đơn vị biên dịch trong scripts/vendor-pcre2.sh.
//
// Hệ quả cần biết khi viết Swift: pcre2.h định nghĩa `pcre2_compile` như MACRO trỏ tới
// `pcre2_compile_8`. Swift không import macro kiểu đó, nên mã Swift gọi thẳng tên có hậu tố
// `_8`. Đó là chủ ý, không phải thiếu sót — tên có hậu tố nói rõ đang dùng bề rộng nào.

#ifndef GEDITOR_PCRE2_H
#define GEDITOR_PCRE2_H

#define PCRE2_CODE_UNIT_WIDTH 8
#define PCRE2_STATIC

// Đường dẫn tương đối chứ không phải <pcre2.h>: `headerSearchPath` trong Package.swift chỉ
// áp cho việc biên dịch chính target PCRE2, KHÔNG áp khi Swift dựng module cho bên nhập.
// Thư mục header công khai vì thế phải tự đủ.
#include "../vendor/include/pcre2.h"

// `PCRE2_SIZE` là MACRO đặt tên kiểu, mà Swift chỉ import được macro giãn ra hằng số
// nguyên/chuỗi. Bí danh dưới đây cho phía Swift gọi tên nó tường minh.
//
// Sentinel `PCRE2_UNSET` (mọi bit 1) KHÔNG được đưa sang đây: Swift import `size_t` thành
// `Int` có dấu, nên hằng số đó tràn kiểu khi import. Phía Swift so sánh bằng bit pattern,
// xem `PCRE2Pattern.unsetOffset`.
typedef PCRE2_SIZE GEditorPCRE2Size;

#endif /* GEDITOR_PCRE2_H */
