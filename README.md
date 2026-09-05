# EIDE — Embedded IDE có tác tử

Mã nguồn EIDE, viết mới hoàn toàn theo **bộ hồ sơ thiết kế v1.2** (`docs/`). Đề án tốt nghiệp Thạc sĩ ngành Kỹ thuật Điện tử — Học viện Công nghệ Bưu chính Viễn thông (PTIT). Học viên: Vũ Trí Công · GVHD: TS. Nguyễn Trung Hiếu.

**Nguyên tắc phát triển:** đọc tài liệu rồi phát triển; mã khác tài liệu thì ghi `docs/DEVIATIONS.md` và cập nhật tài liệu định kỳ. Hướng dẫn cho Claude Code: `CLAUDE.md`. Quy trình chi tiết: `docs/ho-so/EIDE-DEV-29_Quy_trinh_phat_trien_Claude_Code.docx`.

## Bắt đầu (macOS trước)

```bash
bash scripts/setup-mac.sh          # Homebrew, Python, venv, cài eide
source .venv/bin/activate
eide doctor                        # môi trường máy
eide caps list --ns tool           # 238 năng lực trong registry, nhóm gốc tool.*
eide project new "Tạo cho anh dự án robot hai bánh tự cân bằng" --dir ~/eide
make check                         # ruff + đối chiếu spec + pytest
```

Windows/Linux: `python -m venv .venv && .venv\Scripts\activate` (hoặc `source .venv/bin/activate`) rồi `pip install -e ".[dev]"`; CI chạy cả bốn cấu hình (`.github/workflows/ci.yml`).

## Làm việc với Claude Code

Mở kho bằng `claude`, gõ `/bat-dau`. Các lệnh: `/doc-nang-luc <ns.name>`, `/thuc-hien <ns.name>`, `/sai-khac`, `/kiem-tra`, `/nen-tang`, `/dong-bo-tai-lieu`. Hook trong `.claude/settings.json` chặn sửa docx/cds.json trực tiếp và nhắc quy tắc sai khác.

## Cấu trúc

`src/eide_core/` lõi (registry, PolicyGate, ledger, router, tools) · `src/eide/` CLI, daemon JSON-RPC, `caps/<ns>.py` · `docs/spec/` đặc tả máy đọc được · `docs/ho-so/` 31 tài liệu + 4 Excel · `docs/ui/` mockup · `tests/` · `scripts/` · `plugins/geditor/`.
