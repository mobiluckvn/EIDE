# libduckdb — bản dựng sẵn của upstream

**Phiên bản:** v1.5.5
**Nguồn:** https://github.com/duckdb/duckdb/releases/download/v1.5.5/libduckdb-osx-universal.zip
**Kiến trúc:** x86_64 arm64 
**SHA-256 (bản tải về, TRƯỚC khi strip):** b9027d18ef3e8d960568f77e946a83ca68009cb22d71cf7f94de842afdd094d8
**Cỡ:** 111 MB tải về → 94 MB sau strip

Nạp lại: `scripts/vendor-duckdb.sh v1.5.5`

Khác với PCRE2 / tree-sitter / Scintilla, thư mục này chứa **binary dựng sẵn**, không phải mã
nguồn. Nó NẰM TRONG kho nhưng đi qua **Git LFS** (`.gitattributes`), nên bản clone chỉ kéo
phiên bản đang dùng. Lý do và cái giá: xem đầu `scripts/vendor-duckdb.sh` và
`docs/adr/ADR-14-duckdb-va-nap-luoi.md` §6.1.

Máy chưa cài Git LFS sẽ thấy file này chỉ 133 byte — khi ấy chạy `git lfs install && git lfs pull`.

Không sửa một byte nào của upstream ngoài `strip -x -S` (bỏ ký hiệu cục bộ) và ký lại ad-hoc.
