// Header bọc để Swift `import LZMA`.
//
// GEditor không gọi liblzma trực tiếp — libarchive gọi. Module này tồn tại vì hai lý do:
// SwiftPM cần mỗi target C có một thư mục header công khai, và bài kiểm cần đọc được
// `lzma_version_string()` để chứng minh bản đang liên kết đúng là bản script vendor đã nạp.
#include "../vendor/src/liblzma/api/lzma.h"
