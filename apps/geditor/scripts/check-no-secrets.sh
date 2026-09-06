#!/usr/bin/env bash
#
# Cổng chặn KHOÁ RIÊNG lọt vào kho mã.
#
# VÌ SAO CÓ TỆP NÀY. Commit một khoá vào git là thao tác KHÔNG HOÀN TÁC ĐƯỢC: xoá ở commit sau
# không xoá khỏi lịch sử, và muốn sạch thật thì phải viết lại lịch sử *và vẫn phải đổi khoá*.
# Với kho này còn một vế nữa — CI chạy trên runner `macos-14` của GitHub với `actions/checkout`,
# nên mỗi lần push là một lần chép toàn bộ kho lên một máy ảo không ai trong nhóm kiểm soát.
# "Kho private" nói về ai đọc được trang web, không nói về nơi tệp đi tới.
#
# Và khoá EdDSA của Sparkle không phải một mật khẩu — nó là QUYỀN CHẠY MÃ trên máy mọi người
# dùng: ai giữ nó cũng ký được một binary bất kỳ thành "GEditor 1.1", và mọi bản đã cài sẽ tự
# nuốt, im lặng. Đó đúng hình dạng tấn công mà `PluginTrust` (NFR-SEC-03) từ chối theo thiết kế.
# Cổng này giữ đúng lập luận ấy ở tầng trên nó một bậc.
#
#   ./scripts/check-no-secrets.sh              soi các tệp git đang theo dõi
#   ./scripts/check-no-secrets.sh --staged     soi phần đã `git add` (dùng cho móc pre-commit)
#   ./scripts/check-no-secrets.sh --tu-kiem    đối chứng ÂM: đòi bộ dò bắt được khoá giả
#
# Cách cài móc pre-commit ở `docs/khoa-va-ky.md`.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/check_no_secrets.py "$@"
