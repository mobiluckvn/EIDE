# Nền tảng — ma trận và quy tắc

| Nền tảng | Thứ tự | CI | Trạng thái Sprint 1 |
|---|---|---|---|
| macOS 13+ Intel (x86_64) | 1 | `arch -x86_64` trên runner arm64 (xem dưới) | bắt buộc xanh |
| macOS 14+ Apple Silicon (arm64) | 1 | `macos-14` | bắt buộc xanh |
| Windows 11 (x64) | 2 | `windows-latest` (allow-failure) | chạy được `eide doctor`, `eide caps list` |
| Linux Ubuntu 22.04+ (x64/arm64) | 3 | `ubuntu-latest` (allow-failure) | như Windows |

**Vì sao Intel không có runner riêng.** Runner `macos-13` (Intel) của GitHub Actions đã ngừng
phục vụ và không còn runner Intel miễn phí nào. Nhưng macOS Intel vẫn là nền tảng thứ tự 1, nên
phải chứng minh bằng đường khác — hai đường, cả hai đang chạy thật:

- **Python**: `arch -x86_64` trên runner arm64 và trên máy chủ sản phẩm. Rosetta 2 dịch, và
  Python universal2 ở `/usr/local` cho một môi trường x86_64 thật. `make check-ca-hai` chạy toàn
  bộ bộ test hai lần, một lần mỗi kiến trúc — đây là phép kiểm dùng trước mỗi commit.
- **Swift**: cross-compile `x86_64-apple-macosx` rồi kiểm bằng `lipo -info` rằng binary có đủ
  hai lát, như `apps/geditor/scripts/build-universal.sh` đang làm.

Điều đường này KHÔNG phủ: lỗi chỉ xuất hiện trên phần cứng Intel thật mà Rosetta che mất — chủ
yếu là hành vi thời gian và thứ tự bộ nhớ. Với một sản phẩm gọi công cụ ngoài và nói chuyện
serial thì rủi ro ấy nhỏ, nhưng nó không bằng không. Xem DEVIATIONS DEV-005.

## Quy tắc viết mã đa nền tảng

1. Đường dẫn: `pathlib.Path`; thư mục người dùng qua `platformdirs` (`eide_core.paths`): cấu hình, cache, dữ liệu, log không hard-code `~/Library` hay `%APPDATA%`.
2. Tiến trình con: `subprocess.run([...])` dạng danh sách, không `shell=True`; tìm công cụ bằng `eide_core.tools.which()` (đọc thêm đường dẫn thường gặp theo OS: Homebrew `/opt/homebrew/bin`, `/usr/local/bin`; Windows `Program Files`; Linux `/usr/bin`).
3. Cổng nối tiếp / USB: chỉ qua `pyserial` và `pyusb` với bảng VID/PID trong `spec/isa/`; tên cổng do lớp `platform/<os>.py` chuẩn hóa (`/dev/cu.*`, `COMn`, `/dev/ttyACM*`).
4. Dịch vụ nền (daemon): launchd (Mac), Task Scheduler/Service (Windows), systemd (Linux) — theo DEP-26; Sprint 1 chỉ chạy foreground `eide daemon`.
5. Không phụ thuộc kiến trúc CPU máy chủ trong mã Python; binary ngoài (toolchain, renode, probe-rs) chọn theo `platform.machine()` trong `spec/isa/*.yaml`.
6. Kiểm thử: mọi test phải chạy trên cả ba OS; test cần phần cứng đánh dấu `@pytest.mark.hardware` và bị bỏ qua trên CI.
7. Khi một năng lực chỉ hoạt động trên Mac tại thời điểm hoàn thành, ghi `Nền tảng: mac` vào SPRINT-01.md và tạo WI cho Win/Linux.
