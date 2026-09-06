# EIDE — lệnh chuẩn (macOS/Linux; Windows dùng `make` qua Git Bash hoặc chạy lệnh tương đương)
#
# `PY` trỏ vào venv theo kiến trúc chứ không phải `python3` chung: máy Apple Silicon giữ hai
# venv song song (.venv-arm và .venv-x86) vì cả hai kiến trúc đều là nền tảng thứ tự 1 trong
# PLATFORM.md. Xem `scripts/setup-mac.sh --ca-hai` và DEVIATIONS DEV-005.
PY ?= $(shell [ -x .venv-arm/bin/python ] && echo .venv-arm/bin/python || \
              ([ -x .venv-x86/bin/python ] && echo .venv-x86/bin/python || echo python3))
export PYTHONPATH := src

.PHONY: setup setup-ca-hai check check-ca-hai test lint check-spec check-secrets spec doctor geditor clean

setup:            ## cài môi trường phát triển theo kiến trúc máy
	bash scripts/setup-mac.sh

setup-ca-hai:     ## cài cả arm64 và x86_64 (Apple Silicon + Rosetta 2)
	bash scripts/setup-mac.sh --ca-hai

test:             ## pytest
	$(PY) -m pytest

lint:             ## ruff
	$(PY) -m ruff check src tests scripts

check-spec:       ## đối chiếu docs/spec nhất quán
	$(PY) scripts/validate_specs.py

check-secrets:    ## cổng chặn khóa riêng lọt vào kho (SEC-25 / NFR-SEC-01)
	cd apps/geditor && ./scripts/check-no-secrets.sh --tu-kiem && ./scripts/check-no-secrets.sh

check: lint check-spec test check-secrets   ## tất cả — phải xanh trước khi commit

# Một năng lực chỉ được ghi "Xong" khi cột Nền tảng trong SPRINT ghi nền tảng đã chạy test
# THẬT (PLATFORM.md quy tắc 7). Trên máy Apple Silicon, đây là lệnh sinh ra bằng chứng ấy
# cho cả hai kiến trúc Mac.
check-ca-hai:     ## chạy check trên cả arm64 và x86_64
	@echo "######## arm64 ########"
	@$(MAKE) check PY=.venv-arm/bin/python
	@echo "######## x86_64 (Rosetta 2) ########"
	@arch -x86_64 $(MAKE) check PY=.venv-x86/bin/python

spec:             ## trạng thái hiện thực so với spec
	$(PY) scripts/spec_status.py

doctor:
	$(PY) -m eide.cli doctor

geditor:          ## build + test phần Swift (apps/geditor)
	cd apps/geditor && swift build && swift test

clean:
	rm -rf .venv .venv-arm .venv-x86 .pytest_cache .ruff_cache build dist *.egg-info
