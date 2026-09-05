# EIDE — lệnh chuẩn (chạy trên macOS/Linux; Windows dùng `make` qua Git Bash hoặc chạy lệnh tương đương)
PY ?= python3
export PYTHONPATH := src

.PHONY: setup check test lint check-spec spec doctor clean

setup:            ## cài môi trường phát triển (venv .venv)
	$(PY) -m venv .venv && . .venv/bin/activate && pip install -U pip && pip install -e ".[dev]"

test:             ## pytest
	$(PY) -m pytest

lint:             ## ruff
	ruff check src tests scripts && ruff format --check src tests scripts

check-spec:       ## đối chiếu docs/spec nhất quán
	$(PY) scripts/validate_specs.py

check: lint check-spec test   ## tất cả — phải xanh trước khi commit

spec:             ## trạng thái hiện thực so với spec
	$(PY) scripts/spec_status.py

doctor:
	$(PY) -m eide.cli doctor

clean:
	rm -rf .venv .pytest_cache .ruff_cache build dist *.egg-info
