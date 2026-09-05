#!/usr/bin/env bash
# Cài môi trường phát triển EIDE trên macOS (Intel và Apple Silicon). Chạy: bash scripts/setup-mac.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH=$(uname -m); echo "macOS $(sw_vers -productVersion 2>/dev/null || echo ?) · $ARCH"
if ! command -v brew >/dev/null; then echo "Cần Homebrew: https://brew.sh"; exit 1; fi
brew list python@3.12 >/dev/null 2>&1 || brew install python@3.12
brew list git >/dev/null 2>&1 || brew install git
# Công cụ nhúng (tùy chọn Sprint 1; bắt buộc từ Sprint 2 — TGT-19)
for f in cmake ninja; do brew list $f >/dev/null 2>&1 || brew install $f; done
brew list --cask gcc-arm-embedded >/dev/null 2>&1 || echo "Gợi ý: brew install --cask gcc-arm-embedded   (toolchain ARM Cortex-M)"
command -v probe-rs >/dev/null || echo "Gợi ý: brew install probe-rs-tools                (nạp/debug qua probe)"
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -U pip >/dev/null
pip install -e ".[dev]"
eide doctor || true
echo "Xong. Kích hoạt: source .venv/bin/activate · Kiểm tra: make check"
