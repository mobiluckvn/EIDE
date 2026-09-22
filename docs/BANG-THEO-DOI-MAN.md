# Bảng theo dõi 25 màn — EIDE-UXC-31 §11.1

> **Tệp SINH RA. Đừng sửa tay** — chạy `python scripts/bang_theo_doi_man.py`.
> Nguồn: `EideManHinhDS.swift` (danh mục), `EidePhien.MAN` (đã nối), `git log` (commit).

`TT` — trạng thái: **nối** = đã nối dữ liệu thật · **chặn** = chờ bo mạch ·
**chưa** = trong danh mục mà chưa dựng.

| Màn | Tên | TT | Tệp | Commit | Ngày | Người/tác tử |
|---|---|---|---|---|---|---|
| S1 | Tổng quan | nối | `EideManDauTien.swift` | `2335852` | 2026-09-21 | Vũ Trí Công |
| S2 | Nhật ký | nối | `EideManDauTien.swift` | `2335852` | 2026-09-21 | Vũ Trí Công |
| S3 | Bản đồ luồng | nối | `EideManLuongVaMoPhong.swift` | `f0d3404` | 2026-09-21 | Vũ Trí Công |
| S4 | Nhập tài liệu | nối | `EideManNhapTaiLieu.swift` | `57c9ad0` | 2026-09-20 | Vũ Trí Công |
| S5 | Hộ chiếu chip | nối | `EideManHoChieu.swift` | `04754be` | 2026-09-21 | Vũ Trí Công |
| S6 | Hộ chiếu mạch | nối | `EideManHoChieuMach.swift` | `9c8f839` | 2026-09-21 | Vũ Trí Công |
| S7 | Bản đồ tri thức & hỏi đáp | nối | `EideManBanDoTriThuc.swift` | `7c752e6` | 2026-09-22 | Vũ Trí Công |
| S8 | Xung đột tri thức | nối | `EideManXungDot.swift` | `f88d7d9` | 2026-09-20 | Vũ Trí Công |
| S9 | Làm rõ yêu cầu | nối | `EideManLamRo.swift` | `c3570bc` | 2026-09-22 | Vũ Trí Công |
| S10 | Yêu cầu & kiến trúc | nối | `EideManThietKe.swift` | `718e1d2` | 2026-09-22 | Vũ Trí Công |
| S11 | Lược đồ | nối | `EideManThietKe.swift` | `718e1d2` | 2026-09-22 | Vũ Trí Công |
| S12 | Kế hoạch | nối | `EideManThietKe.swift` | `718e1d2` | 2026-09-22 | Vũ Trí Công |
| S13 | Tài liệu | nối | `EideManThietKe.swift` | `718e1d2` | 2026-09-22 | Vũ Trí Công |
| S14 | Trình soạn thảo | nối | `EideManSoanThao.swift` | `6c7c6ec` | 2026-09-21 | Vũ Trí Công |
| S15 | Diff & cổng merge | nối | `EideManDiffMerge.swift` | `ffddd7f` | 2026-09-21 | Vũ Trí Công |
| S16 | Mô phỏng | nối | `EideManLuongVaMoPhong.swift` | `f0d3404` | 2026-09-21 | Vũ Trí Công |
| S17 | Dò board | nối | `EideManPhanCung.swift` | `—` | — | — |
| S18 | Log & serial | nối | `EideManPhanCung.swift` | `—` | — | — |
| S19 | Gỡ lỗi probe | nối | `EideManPhanCung.swift` | `—` | — | — |
| S20 | Bench | nối | `EideManPhanCung.swift` | `—` | — | — |
| S21 | Môi trường | nối | `EideManHeThong.swift` | `cc5eb97` | 2026-09-21 | Vũ Trí Công |
| S22 | Mô hình & chi phí | nối | `EideManHeThong.swift` | `cc5eb97` | 2026-09-21 | Vũ Trí Công |
| S23 | Công cụ tự tạo | nối | `EideManHeThong.swift` | `cc5eb97` | 2026-09-21 | Vũ Trí Công |
| S24 | Registry | nối | `EideManHeThong.swift` | `cc5eb97` | 2026-09-21 | Vũ Trí Công |
| S25 | Chính sách tự chủ | nối | `EideManDauTien.swift` | `2335852` | 2026-09-21 | Vũ Trí Công |

**25 nối · 0 chặn (chờ bo mạch) · 0 chưa.**

Năm phép kiểm còn lại của §11.1 không nằm trong bảng này vì chúng là BÀI KIỂM, không
phải một ô đánh dấu: header chuẩn 2C.4 và danh sách sự kiện khai báo do
`EideBatBienTests` giữ; trạng thái rỗng hai phần và ảnh chụp từng màn do
`EideApp --tu-kiem` (mục 6c) và `--chup` giữ; trợ năng §9.2 do
`EideTroNangTests.testMoiNutDeuCoNhanDocDuoc` quét cả 21 màn.
