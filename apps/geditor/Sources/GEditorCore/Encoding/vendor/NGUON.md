# Nguồn bảng mã VNI

`x-viet-vni.ucm` và `x-viet-tcvn5712.ucm` lấy từ **Encode-VN 0.06** trên CPAN
(tác giả John Wang, giấy phép MIT — xem `LICENSE-Encode-VN`).

    https://cpan.metacpan.org/authors/id/J/JW/JWANG/Encode-VN-0.06.tar.gz

Vì sao vendor thay vì tự dựng bảng: macOS **không có** bộ chuyển đổi VNI, iconv cũng không, và
Python cũng không. Đây là bảng mã duy nhất trong FR-ENC-201 mà không máy nào trên hệ thống
biết đọc.

Chuỗi truy nguyên của bảng này: tài liệu của Encode::VN ghi bảng VNI được sinh từ **`vnichar.htm`
của chính VNI Software Company** (http://vnisoft.com/english/vnichar.htm — nay đã chết). Tức là
nó bắt nguồn từ nhà phát hành bảng mã, không phải từ một trang chép tay.

`x-viet-tcvn5712.ucm` KHÔNG dùng để sinh mã. Nó ở đây làm **nguồn thứ hai độc lập** để đối
chiếu bảng TCVN3 vốn đã sinh từ iconv — hai nguồn không liên quan gì đến nhau mà khớp thì mới
đáng tin.

Bảng được kiểm bằng `scripts/generate-vni-table.py`, không chép tay dòng nào.
