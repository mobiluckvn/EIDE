// Header bọc để Swift `import LibArchive`.
//
// Hai header công khai của libarchive nằm trong `vendor/`, và `vendor/` là mã upstream
// KHÔNG được đụng tới — nên không thể chép chúng sang `include/`. Include theo đường dẫn
// tương đối là cách giữ được cả hai: module map trỏ vào đúng một tệp của GEditor, còn tệp
// ấy trỏ ngược vào nguyên bản upstream.
//
// Chỉ hai header này là API công khai; mọi `archive_*_private.h` còn lại trong vendor/ là
// nội bộ và cố ý không lộ ra Swift.

#include "../vendor/src/archive.h"
#include "../vendor/src/archive_entry.h"

// `AE_IFDIR` và họ hàng của nó là macro có ép kiểu — `#define AE_IFDIR ((__LA_MODE_T)0040000)`.
// Trình nhập C của Swift bỏ qua mọi macro như vậy, nên chúng không tồn tại ở phía Swift.
//
// Khai lại thành hằng có kiểu ngay tại đây, chứ KHÔNG viết `0o040000` rải rác trong mã Swift:
// một hằng bát phân trần trong câu lệnh so sánh thì không ai đọc ra nó là gì, và khi upstream
// đổi giá trị thì chỗ sai nằm im.
static const mode_t GEDITOR_AE_IFDIR = AE_IFDIR;
static const mode_t GEDITOR_AE_IFREG = AE_IFREG;
static const mode_t GEDITOR_AE_IFLNK = AE_IFLNK;
