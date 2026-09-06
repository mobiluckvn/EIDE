# Kế hoạch build sản phẩm EIDE trên macOS

Đề án tốt nghiệp Thạc sĩ Kỹ thuật Điện tử — Học viện Công nghệ Bưu chính Viễn thông (PTIT)
Học viên: **Vũ Trí Công** · Người hướng dẫn: **TS. Nguyễn Trung Hiếu**
Lập 06/09/2026 · Nguồn: EIDE-DEV-29, PLN-27 (backlog), DEP-26 (phát hành), PLATFORM.md

---

## 0. Vì sao macOS trước, và "Intel" nghĩa là gì ở đây

PLATFORM.md xếp macOS Intel và Apple Silicon **cùng thứ tự 1** — cả hai bắt buộc, Windows và
Linux xếp sau. Nhưng "hỗ trợ Intel" là một câu dễ nói và khó kiểm: EIDE thuần Python nên phần
lớn mã không phân biệt kiến trúc, và chính vì thế chỗ nào có phân biệt lại càng dễ lọt.

Chỉ ba chỗ thật sự khác nhau giữa hai kiến trúc:

| Chỗ | Apple Silicon | Intel |
|---|---|---|
| Prefix Homebrew mà `eide_core.tools.which()` phải dò | `/opt/homebrew` | `/usr/local` |
| Binary ngoài chọn theo `platform.machine()` (TGT-19, `spec/isa/*.yaml`) | bản arm64 | bản x86_64 |
| Phần Swift của `apps/geditor` | dựng gốc | cross-compile, kiểm bằng `lipo` |

Runner `macos-13` (Intel) của GitHub Actions đã ngừng phục vụ, nên ma trận CI trong bộ hồ sơ
không còn chạy được như viết (DEVIATIONS **DEV-005**). Cách thay thế đã được kiểm chứng
06/09/2026: chạy x86_64 qua **Rosetta 2** trên runner arm64 và trên máy chủ sản phẩm.

**Trạng thái hôm nay** — `make check-ca-hai` xanh cả hai kiến trúc trên máy chủ sản phẩm:

```
######## arm64 ########                 ######## x86_64 (Rosetta 2) ########
ruff: All checks passed                 ruff: All checks passed
spec: 238 năng lực, 55 RPC, OK          spec: 238 năng lực, 55 RPC, OK
36 passed                               36 passed
NFR-SEC-01: không có khóa riêng         NFR-SEC-01: không có khóa riêng
```

`eide caps invoke env.detect` trả đúng `arch: arm64` / `arch: x86_64`, đi qua PolicyGate
(APPROVE theo TIER-T1) và được ghi vào ledger — tức là **trọn vòng lặp** *lệnh → cổng → năng
lực → nhật ký* đã chạy thật trên cả hai kiến trúc Mac, không phải chỉ import được.

---

## 1. Kho mã sau khi dựng

```
EIDE/                       git@github.com:mobiluckvn/EIDE.git
├── CLAUDE.md               hướng dẫn cho Claude Code — nguyên tắc "đọc tài liệu rồi mới code"
├── .gitmessage             mẫu commit: Đọc / Sai khác / Nền tảng + tên học viên và GVHD
├── .env / .env.example     khóa mô hình (GEMINI_API_KEY…) — .env không bao giờ vào git
├── Makefile                make check · make check-ca-hai · make geditor
├── docs/
│   ├── INDEX.md            bản đồ "việc → tài liệu phải đọc trước"
│   ├── DEVIATIONS.md       nhật ký sai khác — DEV-001…005
│   ├── SPRINT-01.md        bảng việc, có cột Nền tảng đã kiểm thật
│   ├── PLATFORM.md         7 quy tắc viết mã đa nền tảng
│   ├── PLAN-MAC.md         tệp này
│   ├── ho-so/              31 docx + 4 Excel + nguon/ (tài liệu = mã, sinh lại được)
│   ├── spec/               ĐẶC TẢ MÁY ĐỌC ĐƯỢC — chuẩn để test đối chiếu
│   └── ui/                 35 mockup
├── src/eide_core/          registry · policy · ledger · router · paths · tools
├── src/eide/               cli.py · daemon/rpc.py · caps/{project,env,policy}.py
├── tests/                  36 test, gồm test_specs_consistency (mã ≡ spec)
├── apps/geditor/           GEditor (Swift) — nay là thành phần trong kho (DEV-004)
└── _incoming/              hiện vật gốc chủ sản phẩm nạp vào (không vào git)
```

`docs/spec/` là tài sản trung tâm: 238 hợp đồng năng lực (`cds.json`), 46 quy tắc chính sách
(`policy/rules.yaml` + 45 tình huống fixture), 55 phương thức JSON-RPC (`api/openrpc.json`),
27 thực thể dữ liệu (`data/`), 9 prompt vai trò, bảng ISA. Registry nạp nó lúc khởi động và
`tests/test_specs_consistency.py` làm cho mã **không thể** lệch spec mà CI vẫn xanh.

---

## 2. Ba việc phải làm trước khi viết dòng năng lực tiếp theo

| # | Việc | Ai | Vì sao chặn |
|---|---|---|---|
| 1 | **Đổi khóa ký Sparkle của GEditor** | Chủ sản phẩm | `secrets/sparkle_eddsa_private.txt` đã nằm trong lịch sử kho `mobiluckvn/Geditor`. Khóa ấy không phải mật khẩu — nó là *quyền chạy mã* trên máy mọi người dùng GEditor. Chi tiết ở §6. |
| 2 | **WI-257** — ký danh sách trắng nguồn/gói/board lab, đặt `autonomy.yaml` ban đầu | Chủ sản phẩm | PolicyGate đang chạy bằng `defaults.yaml` tạm (DEV-001). Không có danh sách trắng thật thì mọi cổng G-SRC/G-PKG chỉ là giả định. |
| 3 | **WI-258** — xác nhận mã màu PTIT và ngôn ngữ lược đồ GEditor hỗ trợ | Chủ sản phẩm | Chặn phần giao diện (UXD-13 U7). |

**Mô hình** — `GEMINI_API_KEY` đã được điền vào `.env` (06/09/2026) và kiểm bằng lời gọi thật.
Mặc định phát triển và kiểm thử: **`gemini-3.8-flash`** — chủ sản phẩm chốt vì chi phí phù hợp
với vòng lặp test dày mà chất lượng vẫn đủ. Lưu ý thứ tự trong tên: API dùng
`gemini-3.8-flash`, không phải `gemini-flash-3.8`. Khi WI-013 dựng Gateway LLM, giá trị này
vào `models.yaml` theo PRS-16 §1, và vai trò nào cần suy luận dài hơn thì nâng riêng vai trò
ấy chứ không đổi mặc định.

---

## 3. Sprint 1 — "xương sống chạy được trên Mac" (2 tuần)

Đã xong (nay có bằng chứng nền tảng thật trên cả hai kiến trúc): WI-001 khởi tạo kho,
WI-003 Registry + Router, WI-004 PolicyGate 46 quy tắc, WI-008 ledger chuỗi hash,
WI-010 JSON-RPC 9/55 + CLI; sáu năng lực `project.create/list`, `env.detect/check`,
`policy.emergency_stop/set_autonomy`.

Còn lại, theo thứ tự phụ thuộc:

| Thứ tự | Việc | Đọc trước | Chặn cái gì |
|---|---|---|---|
| 1 | **WI-002** SQLite store + migration 0001 + `eide migrate` | DDD-14 §DDL, `spec/data/schema.sql` | `project.open`, `project.status`, decision_log, mọi thứ có trạng thái |
| 2 | **PROJECT-02/08/09** `project.open`, `.status`, `.preferences` | CDS-12.3 | kịch bản demo đầu-cuối |
| 3 | **POLICY-01** `policy.decide` + chạy đủ 45 tình huống `situations.jsonl` | CDS-12.5, POL-17 | biến PolicyGate từ "có mã" thành "đã chứng minh" |
| 4 | **WI-007** Memory M1/M2 + PROGRESS/FEATURES tự sinh | MEM-11 §2–4 | `memory.*`, resume phiên |
| 5 | **POLICY-03/04** `undo_window`, `escalate` · **REPORT-01** `report.progress` | CDS-12.5 | vòng "làm rồi báo cáo, hoàn tác được" (UXD U2) |
| 6 | **WI-009** sandbox tiến trình con · **ENV-05/07** `env.lock`, `env.sandbox` | SEC-25 §4 | nền cho `tool.*` ở Sprint 2 |
| 7 | **WI-013** prompt 9 vai trò + `models.yaml` + Gateway LLM (Gemini/Claude) | PRS-16, CXD-10 | mọi năng lực cần suy luận |

**Định nghĩa xong của sprint**: `make check-ca-hai` xanh; CI xanh cả `mac-arm64` và
`mac-x86_64`; chuỗi thật `eide project new` → `caps invoke project.open` → `project list`
chạy trên cả hai kiến trúc; không mục DEVIATIONS `Mở` quá 7 ngày.

Mỗi việc đi đúng vòng lặp bảy bước của DEV-29: `/doc-nang-luc` → viết test từ `tc` và `errors`
→ hiện thực `@capability` → kiểm đa nền tảng → `make check-ca-hai` → `/sai-khac` nếu cần →
cập nhật SPRINT-01 rồi commit theo `.gitmessage`.

---

## 4. Sprint 2 — tác tử thật

WI-005 Orchestrator (intent → ground → defaults → clarify → chain → runner → report, theo
DPS-09), WI-020 ToolForge `tool.need/search/write/test/run/register` (phụ thuộc WI-009 sandbox),
WI-011 MCP server sinh tool từ registry. Đây là lúc `GEMINI_API_KEY` được dùng thật và là lúc
kịch bản Z-01…Z-10 của mốc M1 chạy được đầu-cuối.

---

## 5. Giao diện — GEditor nay nằm trong kho

Chủ sản phẩm quyết định 06/09/2026: GEditor được **chuyển hẳn** vào `apps/geditor/`, hai kho đi
hai hướng phát triển khác nhau (DEVIATIONS **DEV-004**).

Điều này thay đổi hẳn bài toán so với GPI-23. Tài liệu ấy viết như thể EIDE là *bên thứ ba* xin
GEditor mở API: 12 yêu cầu GP-01…GP-12, trong đó 9 mang nhãn `[GE?]` chưa xác nhận. Đối chiếu
với mã thật:

- `NativePlugin` API v1 của GEditor **cố ý hẹp**: chỉ `describe` và
  `run(command, text, selection) → replacement(String?)`. Đó là phép biến đổi văn bản, không có
  panel, không có sidebar, không có thanh trạng thái.
- ADR-12 của GEditor chốt plugin chạy **ngoài tiến trình** qua XPC, chỉ có ở bản tải trực tiếp,
  và ghi thẳng ở §5 rằng *"API mà plugin nhìn thấy — chưa thiết kế"*.
- Nhưng GEditor **đã có sẵn** hạ tầng mà UXD-13 cần: hơn 20 panel SwiftUI trong `GEditorApp`,
  bộ render Mermaid đầy đủ (`GEditorCore/Mermaid`), engine tệp lớn, `ScintillaCocoa`.

Vì hai kho nay là một, đường rẻ nhất **không** phải là thiết kế plugin API v2 rồi đi qua XPC —
mà là dựng các màn hình EIDE **thẳng trong `GEditorApp`** như một panel nữa, nói JSON-RPC với
`eided`. Bỏ được toàn bộ phần ký Developer ID, XPC và thiết kế API mà ADR-12 nói là chưa có.

Thứ tự đề nghị: (1) `EIDEPanel` + client JSON-RPC sinh từ `openrpc.json`; (2) ChatPanel — màn
hình mặc định theo UXD U1; (3) AutonomyBar + nút Dừng khẩn ⌘⇧. (U2, U6); (4) ReviewQueue hai
danh sách; (5) tái dùng `MermaidRenderer` cho `diagram.*`. Việc này nằm ở M2, sau khi
Orchestrator chạy.

---

## 6. An toàn — một việc cần quyết ngay

Trong lúc chuyển mã đã phát hiện: `secrets/sparkle_eddsa_private.txt` — **hạt giống khóa riêng
EdDSA 32 byte** dùng ký cập nhật Sparkle — được commit vào kho `mobiluckvn/Geditor` và được đưa
vào danh sách ngoại lệ của chính `check_no_secrets.py`, nên cổng NFR-SEC-01 của GEditor vẫn báo
xanh.

Chính tệp `check-no-secrets.sh` của anh đã viết ra vì sao điều này nghiêm trọng: *"khoá EdDSA
của Sparkle không phải một mật khẩu — nó là QUYỀN CHẠY MÃ trên máy mọi người dùng: ai giữ nó
cũng ký được một binary bất kỳ thành 'GEditor 1.1', và mọi bản đã cài sẽ tự nuốt, im lặng."*

Đã làm trong kho EIDE: khóa riêng **không** được mang sang; `.gitignore` chặn `secrets/*_private*`;
ngoại lệ tương ứng đã gỡ khỏi `check_no_secrets.py`; `make check` chạy cổng ấy mỗi lần.

Còn phải quyết cho kho `Geditor` gốc — ngoài phạm vi EIDE, cần chủ sản phẩm:
1. **Đổi khóa** — xóa ở commit sau không xóa khỏi lịch sử; đây là bước duy nhất thật sự có tác dụng.
2. Sinh cặp khóa mới, để khóa riêng **chỉ** trong Keychain (đúng như `Info.plist` đã mô tả), cập
   nhật `SUPublicEDKey`.
3. Cân nhắc viết lại lịch sử kho, và cài móc pre-commit mà `docs/khoa-va-ky.md` đã dự trù.

---

## 7. Đóng gói (DEP-26 §1–2)

Bản đầu: `pipx install eide` + `eide setup` (tạo `~/.eide/`, cài launchd agent
`ai.code247.eided`, kiểm Python 3.11+, hỏi cài toolchain theo ISA). Thuần Python nên một gói
chạy cả hai kiến trúc; `eide doctor` là cổng nghiệm thu (TC-DP-01). Homebrew tap và `.pkg` ký
notarize để sau — `.pkg` cần tài khoản Apple Developer, mà đó cũng đúng thứ đang chặn câu hỏi
§2.1 của ADR-12 GEditor.

Phần `apps/geditor` giữ nguyên `build-universal.sh`: một bundle `.app` chứa cả arm64 và x86_64,
không phụ thuộc Rosetta, CI kiểm bằng `lipo`.

---

## 8. Tiêu chí chấp nhận quy trình (DEV-29 §8)

1. Mọi commit trong `src/` có thân `Đọc: …` và `Sai khác: DEV-xxx | không`.
2. `tests/test_specs_consistency.py` xanh liên tục: mã lỗi ⊆ `errors.json`, phương thức RPC ⊆
   `openrpc.json`, `@capability` ⊆ `cds.json`, docstring có `Spec:`.
3. Không mục DEVIATIONS `Mở` quá 7 ngày; sau mỗi đồng bộ, phiên bản tài liệu tăng và
   `docs/spec/` được sinh lại từ `ho-so/nguon/`.
4. CI xanh trên `mac-arm64` và `mac-x86_64` cho mọi PR; Windows/Linux không đỏ quá một sprint.
5. SPRINT-xx ghi nền tảng thật cho từng dòng "Xong".
