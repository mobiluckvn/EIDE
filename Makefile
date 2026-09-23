# EIDE — lệnh chuẩn (macOS/Linux; Windows dùng `make` qua Git Bash hoặc chạy lệnh tương đương)
#
# `PY` trỏ vào venv theo kiến trúc chứ không phải `python3` chung: máy Apple Silicon giữ hai
# venv song song (.venv-arm và .venv-x86) vì cả hai kiến trúc đều là nền tảng thứ tự 1 trong
# PLATFORM.md. Xem `scripts/setup-mac.sh --ca-hai` và DEVIATIONS DEV-005.
PY ?= $(shell [ -x .venv-arm/bin/python ] && echo .venv-arm/bin/python || \
              ([ -x .venv-x86/bin/python ] && echo .venv-x86/bin/python || echo python3))
export PYTHONPATH := src

.PHONY: setup setup-ca-hai check check-py check-ca-hai test lint check-spec check-secrets check-swift spec doctor geditor eide-ui eide-ui-nut eide-noi-dung eidekit clean

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
	$(PY) scripts/bang_theo_doi_man.py --kiem
	$(PY) scripts/kiem_checklist.py
	$(PY) scripts/gen_man_can_hien.py --kiem
	@command -v node >/dev/null && node scripts/gen_spec_tu_nguon.js --kiem \
	 || echo "bỏ qua check-gen: không có node (cần để đối chiếu docs/spec với docs/ho-so/nguon)"

# Phần Swift nằm trong `check` chứ không đứng riêng. Từ 06/09 tới 11/09/2026 nó đỏ hai bài mà
# không ai thấy, vì `make check` chỉ gọi phía Python còn `make geditor` thì phải nhớ gõ tay —
# và "xanh" của dự án khi ấy là một câu nói về nửa kho. Cùng lý do với `check-gen`: một cổng
# phải tự chạy thì mới là cổng. Thiếu `swift` (Windows, máy CI không có Xcode) thì bỏ qua có
# báo, không làm đỏ — cùng khuôn với cách `check-gen` xử lý khi thiếu `node`.
# `apps/geditor` KHÔNG còn nằm trong cổng — [DEV-187], chủ sản phẩm chốt 22/09/2026:
# *"Chúng ta thống nhất bỏ GEditor rồi mà. Chúng ta viết lại và chỉ copy phần code có thể tận
# dụng được của GEditor thôi."*
#
# Giữ nó trong `make check` có một cái giá đo được: 22/09/2026 một bài kiểm của geditor TREO 36
# phút ở trạng thái `U`, giữ khoá SwiftPM, và mọi lượt `make check` sau đó đứng im chờ nó — cổng
# của gói ĐANG PHÁT TRIỂN bị chặn bởi gói đã ngừng phát triển. Một cổng chỉ nên canh thứ mình
# đang làm; canh thêm một kho bảo trì là mua rủi ro mà không mua được thông tin.
#
# `make geditor` vẫn còn để chạy tay khi cần lấy lại một phần mã cũ.
check-swift:      ## build + test apps/eide, bỏ qua có báo nếu máy không có swift
	@command -v swift >/dev/null \
	 && $(MAKE) eide-ui \
	 || echo "bỏ qua check-swift: không có swift (cần Xcode/toolchain để dựng apps/eide)"

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

geditor:          ## (BẢN DUY TRÌ — ngoài cổng) build + test apps/geditor, chạy tay khi cần
	cd apps/geditor && swift build && swift test

# apps/eide là GIAO DIỆN MỚI (18/09/2026); apps/geditor chỉ còn là bản duy trì. Tới 22/09 nó
# nằm NGOÀI `make check`: `check-swift` chỉ gọi `geditor`, nên 307 bài của gói mới và hai bộ
# dò nút chỉ chạy khi có người nhớ gõ tay. Một cổng phải tự chạy thì mới là cổng — đúng câu đã
# viết ở `check-swift` cho `make geditor`, mà rồi quên áp cho gói kế tiếp.
#
# Ba tầng đo, và tầng sau bắt thứ tầng trước mù:
#   swift test   — từng bộ phận
#   --tu-kiem    — một PHIÊN, 70 phép đo, tự dựng dự án tạm (không chạm workspace thật)
#   --do-nut     — nút nào KHÔNG nối vào đâu
#   --bam-thu    — nút có nối nhưng BẤM XONG màn hình không đổi gì: chết theo nghĩa người dùng
#
# Hai bộ dò cuối cần một dự án có thật để mở, nên tạo một dự án dùng-một-lần rồi xoá. `--do-nut`
# và `--bam-thu` đều `exit 1` khi có nút chết, nên make tự đỏ.
eide-ui:          ## build + test + dò nút chết + dò NỘI DUNG của GIAO DIỆN MỚI (apps/eide)
	cd apps/eide && swift build && swift test
	@$(MAKE) eide-ui-nut
	@$(MAKE) eide-noi-dung

# Ba bộ đo dưới đây DỰNG CỬA SỔ THẬT, nên chúng cần một phiên đồ hoạ. Trên máy CI không có
# `launchctl managername` = Aqua (ssh, Linux, runner headless) thì bỏ qua có báo — cùng khuôn
# với cách `check-gen` xử lý khi thiếu `node`. Bỏ qua IM LẶNG mới là thứ phải tránh: nó biến
# một cổng không chạy được thành một cổng "đã xanh".
eide-ui-nut:      ## chỉ ba bộ dò giao diện — cần phiên đồ hoạ (Aqua)
	@[ "$$(launchctl managername 2>/dev/null)" = "Aqua" ] || \
	 { echo "bỏ qua dò nút: không có phiên đồ hoạ (cần Aqua; ssh/CI headless không dựng NSWindow được)"; exit 0; }; \
	 apps/eide/.build/debug/EideApp --tu-kiem || exit 1; \
	 goc=$$(mktemp -d); \
	 duan=$$($(PY) -m eide.cli project new "đo nút giao diện" --dir $$goc/ws --chip atmega328p \
	         | $(PY) -c 'import sys,json;s=sys.stdin.read();print(json.loads(s[s.index("{"):])["path"])'); \
	 echo "dự án dùng một lần: $$duan"; \
	 apps/eide/.build/debug/EideApp --do-nut "$$duan" && \
	 apps/eide/.build/debug/EideApp --bam-thu "$$duan"; \
	 ma=$$?; rm -rf $$goc; exit $$ma

# Bộ dò NỘI DUNG hỏi một câu khác hẳn hai bộ trên: "màn này có hiện thứ nó PHẢI hiện không".
# Hợp đồng nội dung ở `docs/spec/ui/man_can_hien.json`, sinh từ cột "DỮ LIỆU PHẢI HIỆN" của
# `docs/EIDE-VUNG-MAN-HINH.xlsx` (chủ sản phẩm duyệt 22/09/2026).
#
# 23/09/2026 nó ĐẠT 77/77 trên dự án mẫu, nên từ nay nó NẰM TRONG CỔNG ([DEV-193]). Khi còn
# 28/77 thì nó là thước đo khoảng cách và phải đứng ngoài — một cổng luôn đỏ là một cổng bị
# tắt. Đủ rồi thì ngược lại: để ngoài cổng nghĩa là mục đầu tiên rụng đi sẽ không ai thấy.
#
# Cần một dự án CÓ DỮ LIỆU THẬT: màn rỗng thì mọi mục đều "thiếu" và con số mất nghĩa. `DUAN`
# bỏ trống thì tự dựng dự án mẫu — xem `scripts/du_an_mau.py` và giới hạn của nó ghi ở đó.
eide-noi-dung:    ## đo màn có hiện đủ dữ liệu không — DUAN=<dự án>, bỏ trống thì dựng dự án mẫu
	@[ "$$(launchctl managername 2>/dev/null)" = "Aqua" ] || \
	 { echo "bỏ qua: không có phiên đồ hoạ"; exit 0; }
	$(PY) scripts/gen_man_can_hien.py
	@D="$(DUAN)"; \
	 if [ -z "$$D" ]; then $(PY) scripts/du_an_mau.py >/dev/null || exit 1; \
	    D=$$($(PY) -c "import pathlib;print(sorted(pathlib.Path.home().joinpath('eide').glob('mau-do-giao-dien*'))[-1])"); \
	 fi; \
	 apps/eide/.build/debug/EideApp --do-noi-dung "$$D"

eidekit:          ## chỉ EIDEKit — client JSON-RPC của panel GEditor (WI-021)
	cd apps/geditor && swift build --target EIDEKit && swift test --filter EIDEKitTests

clean:
	rm -rf .venv .venv-arm .venv-x86 .pytest_cache .ruff_cache build dist *.egg-info
