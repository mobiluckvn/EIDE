#!/usr/bin/env bash
# Cài môi trường phát triển EIDE trên macOS.
#
#   bash scripts/setup-mac.sh              dựng .venv-arm hoặc .venv-x86 theo kiến trúc máy
#   bash scripts/setup-mac.sh --ca-hai      dựng CẢ HAI trên máy Apple Silicon có Rosetta 2
#
# VÌ SAO CÓ `--ca-hai`. PLATFORM.md xếp macOS Intel và Apple Silicon CÙNG thứ tự 1 — cả hai
# đều bắt buộc. Runner `macos-13` (Intel) của GitHub đã ngừng phục vụ (DEVIATIONS DEV-005),
# nên chỗ duy nhất còn chạy được x86_64 thật là máy Apple Silicon qua Rosetta 2. Bỏ vế ấy
# thì "hỗ trợ Intel" là một câu chưa ai kiểm.
#
# Hai kiến trúc KHÔNG dùng chung venv: gói có phần biên dịch sẽ nạp nhầm .so và hỏng lúc
# chạy chứ không phải lúc cài — nên tách hẳn `.venv-arm` và `.venv-x86`.
set -euo pipefail
cd "$(dirname "$0")/.."

CA_HAI=0
[ "${1:-}" = "--ca-hai" ] && CA_HAI=1

ARCH=$(uname -m)
echo "macOS $(sw_vers -productVersion 2>/dev/null || echo ?) · $ARCH"

command -v brew >/dev/null || { echo "Cần Homebrew: https://brew.sh"; exit 1; }
brew list python@3.12 >/dev/null 2>&1 || brew install python@3.12
brew list git >/dev/null 2>&1 || brew install git
# Công cụ nhúng (tùy chọn Sprint 1; bắt buộc từ Sprint 2 — TGT-19)
for f in cmake ninja; do brew list "$f" >/dev/null 2>&1 || brew install "$f"; done
brew list --cask gcc-arm-embedded >/dev/null 2>&1 || echo "Gợi ý: brew install --cask gcc-arm-embedded   (toolchain ARM Cortex-M)"
command -v probe-rs >/dev/null || echo "Gợi ý: brew install probe-rs-tools                (nạp/debug qua probe)"
# GEditor (apps/geditor) có libduckdb 94 MB đi qua Git LFS — thiếu nó thì clone ra file con trỏ
command -v git-lfs >/dev/null || { echo "Cài git-lfs cho apps/geditor"; brew install git-lfs; }
git lfs install --local >/dev/null 2>&1 || true

dung_venv() {   # $1 = thư mục venv, $2 = python, $3 = tiền tố arch
    echo "── $1 ($3)"
    $3 "$2" -m venv "$1"
    $3 "$1/bin/pip" install -q -U pip
    $3 "$1/bin/pip" install -q -e ".[dev]"
    $3 "$1/bin/python" -c "import platform; print('   kiến trúc thật:', platform.machine())"
}

if [ "$ARCH" = "arm64" ]; then
    dung_venv .venv-arm "$(brew --prefix)/bin/python3.12" ""
    if [ "$CA_HAI" = 1 ]; then
        # Rosetta 2 và một Python universal2/x86_64 ở /usr/local là điều kiện cần.
        if ! /usr/bin/pgrep -q oahd; then
            echo "Rosetta 2 chưa cài — chạy: softwareupdate --install-rosetta --agree-to-license"; exit 1
        fi
        PY_X86=""
        for c in /usr/local/bin/python3.12 /usr/local/bin/python3; do [ -x "$c" ] && PY_X86="$c" && break; done
        if [ -z "$PY_X86" ]; then
            echo "Không thấy Python x86_64 ở /usr/local — cài Homebrew Intel hoặc python.org universal2"; exit 1
        fi
        dung_venv .venv-x86 "$PY_X86" "arch -x86_64"
    fi
else
    dung_venv .venv-x86 "$(brew --prefix)/bin/python3.12" ""
fi

[ -f .env ] || { cp .env.example .env; echo "Đã tạo .env từ mẫu — điền GEMINI_API_KEY trước khi dùng năng lực cần mô hình."; }

echo
echo "Xong. Kiểm tra:  make check          (kiến trúc máy)"
[ "$CA_HAI" = 1 ] && echo "                 make check-ca-hai   (cả arm64 và x86_64)"
exit 0
