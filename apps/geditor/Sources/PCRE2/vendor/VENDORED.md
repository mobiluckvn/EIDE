# PCRE2 10.47 — mã nguồn nạp vào repo

Nguồn: <https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/pcre2-10.47.tar.gz>

Thư mục này do `scripts/vendor-pcre2.sh` sinh ra và bị XÓA SẠCH mỗi lần chạy lại.
Shim của GEditor (module map + header bọc) nằm ở `Sources/PCRE2/include/`, không nằm ở đây.

**Không sửa một dòng nào của upstream.** Cập nhật bằng `scripts/vendor-pcre2.sh <phiên bản>`,
đừng vá tay — mọi thay đổi sẽ mất ở lần nạp sau.

Ba file được đổi tên khi chép (đây là cách upstream dành cho bản dựng không autoconf/cmake,
xem `NON-AUTOTOOLS-BUILD`):

| Trong bản phát hành | Trong repo |
|---|---|
| `src/config.h.generic` | `src/config.h` |
| `src/pcre2.h.generic` | `include/pcre2.h` |
| `src/pcre2_chartables.c.dist` | `src/pcre2_chartables.c` |

Mọi lựa chọn build (`SUPPORT_JIT`, `SUPPORT_UNICODE`, `PCRE2_CODE_UNIT_WIDTH=8`…) nằm
trong `Package.swift`, không nằm trong `config.h` — để nhìn một chỗ là biết đang bật gì.

Giấy phép: BSD 3-Clause, xem `LICENCE.md` (PCRE2) và `deps/sljit/LICENSE` (sljit).
Lý do vendor thay vì link thư viện hệ thống: xem đầu `scripts/vendor-pcre2.sh` và ADR-03.
