# EIDE — lệnh chuẩn (macOS/Linux; Windows dùng `make` qua Git Bash hoặc chạy lệnh tương đương)
#
# `PY` trỏ vào venv theo kiến trúc chứ không phải `python3` chung: máy Apple Silicon giữ hai
# venv song song (.venv-arm và .venv-x86) vì cả hai kiến trúc đều là nền tảng thứ tự 1 trong
# PLATFORM.md. Xem `scripts/setup-mac.sh --ca-hai` và DEVIATIONS DEV-005.
PY ?= $(shell [ -x .venv-arm/bin/python ] && echo .venv-arm/bin/python || \
              ([ -x .venv-x86/bin/python ] && echo .venv-x86/bin/python || echo python3))
export PYTHONPATH := src

.PHONY: setup setup-ca-hai check check-py check-ca-hai test lint check-spec check-secrets check-swift spec doctor geditor clean

setup:            ## cài môi trường phát triển theo kiến trúc máy
	bash scripts/setup-mac.sh

setup-ca-hai:     ## cài cả arm64 và x86_64 (Apple Silicon + Rosetta 2)
	bash scripts/setup-mac.sh --ca-hai

test:             ## pytest
	$(PY) -m pytest

check-net:        ## test GỌI MẠNG THẬT — mẫu URL hãng, bộ dựng lược đồ (không cần khóa)
	$(PY) -m pytest -m net -v

check-llm:        ## test GỌI MÔ HÌNH THẬT — cần GEMINI_API_KEY/ANTHROPIC_API_KEY, tốn token
	$(PY) -m pytest -m llm -v

lint:             ## ruff
	$(PY) -m ruff check src tests scripts

check-spec:       ## đối chiếu docs/spec nhất quán
	$(PY) scripts/validate_specs.py

check-secrets:    ## cổng chặn khóa riêng lọt vào kho (SEC-25 / NFR-SEC-01)
	cd apps/geditor && ./scripts/check-no-secrets.sh --tu-kiem && ./scripts/check-no-secrets.sh

# docs/spec/ là bản SINH từ docs/ho-so/nguon/ (CLAUDE.md §"Đồng bộ tài liệu"). Không có cổng
# này thì một lần sửa tay rules.yaml sẽ sống sót im lặng, và lần sinh lại sau đó âm thầm nuốt
# mất nó. `node` không phải phụ thuộc bắt buộc để chạy EIDE nên thiếu node thì bỏ qua, có báo.
check-gen:        ## bản sinh trong docs/spec/ còn khớp nguồn không
	$(PY) scripts/gen_rpc_swift.py --kiem
	$(PY) scripts/gen_ui_swift.py --kiem
	@command -v node >/dev/null && node scripts/gen_spec_tu_nguon.js --kiem \
	 || echo "bỏ qua check-gen: không có node (cần để đối chiếu docs/spec với docs/ho-so/nguon)"

# Phần Swift nằm trong `check` chứ không đứng riêng. Từ 06/09 tới 11/09/2026 nó đỏ hai bài mà
# không ai thấy, vì `make check` chỉ gọi phía Python còn `make geditor` thì phải nhớ gõ tay —
# và "xanh" của dự án khi ấy là một câu nói về nửa kho. Cùng lý do với `check-gen`: một cổng
# phải tự chạy thì mới là cổng. Thiếu `swift` (Windows, máy CI không có Xcode) thì bỏ qua có
# báo, không làm đỏ — cùng khuôn với cách `check-gen` xử lý khi thiếu `node`.
check-swift:      ## build + test phần Swift, bỏ qua có báo nếu máy không có swift
	@command -v swift >/dev/null \
	 && $(MAKE) geditor \
	 || echo "bỏ qua check-swift: không có swift (cần Xcode/toolchain để dựng apps/geditor)"

check-py: lint check-spec test check-secrets check-gen   ## chỉ phía Python — phần phụ thuộc venv theo kiến trúc

check: check-py check-swift   ## tất cả — phải xanh trước khi commit

# Một năng lực chỉ được ghi "Xong" khi cột Nền tảng trong SPRINT ghi nền tảng đã chạy test
# THẬT (PLATFORM.md quy tắc 7). Trên máy Apple Silicon, đây là lệnh sinh ra bằng chứng ấy
# cho cả hai kiến trúc Mac.
#
# Chạy `check-py` hai lần nhưng `check-swift` MỘT lần: hai lượt ở đây là để kiểm hai venv
# Python theo kiến trúc (DEV-005), còn gói Swift thì `swift build` tự chọn kiến trúc máy —
# ép nó qua Rosetta chỉ dựng lại 2699 bài bằng một trình dịch khác để hỏi một câu không ai hỏi.
check-ca-hai:     ## chạy check trên cả arm64 và x86_64
	@echo "######## arm64 ########"
	@$(MAKE) check-py PY=.venv-arm/bin/python
	@echo "######## x86_64 (Rosetta 2) ########"
	@arch -x86_64 $(MAKE) check-py PY=.venv-x86/bin/python
	@echo "######## Swift (một lượt, không theo kiến trúc venv) ########"
	@$(MAKE) check-swift

spec:             ## trạng thái hiện thực so với spec
	$(PY) scripts/spec_status.py

doctor:
	$(PY) -m eide.cli doctor

geditor:          ## build + test phần Swift (apps/geditor)
	cd apps/geditor && swift build && swift test

eidekit:          ## chỉ EIDEKit — client JSON-RPC của panel GEditor (WI-021)
	cd apps/geditor && swift build --target EIDEKit && swift test --filter EIDEKitTests

clean:
	rm -rf .venv .venv-arm .venv-x86 .pytest_cache .ruff_cache build dist *.egg-info
