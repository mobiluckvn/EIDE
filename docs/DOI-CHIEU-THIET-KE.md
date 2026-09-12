# Đối chiếu mã ↔ thiết kế

*Đo 12/09/2026 từ `docs/spec/` và `src/`, không gõ tay. Mọi con số dưới đây sinh lại được bằng
cách chạy lại phép đo ghi kèm từng bảng.*

`TIEN-DO.md` trả lời **"đi được bao xa"** bằng một trục duy nhất: số năng lực. Tệp này hỏi khác:
**bộ hồ sơ thiết kế mô tả bao nhiêu THỨ, và mã đã chạm tới bao nhiêu trong số đó** — trên mọi
trục, không riêng trục năng lực.

Lý do tách ra: một sản phẩm có thể đạt 83% năng lực mà vẫn thiếu hẳn một mặt. Bảng §2 dưới đây
cho thấy đúng chuyện ấy đang xảy ra.

---

## 1. Một dòng

**Chín trên mười trục đã trên 60%.** 197/238 năng lực (83%), 34/57 phương thức JSON-RPC (60%),
11/15 công cụ MCP (73%). Trục thấp nhất là mã kiểm thử TC (61%) và quy tắc chính sách (80%) —
và cả hai thấp vì cùng một lý do: **phần cần board thật chưa kiểm được.**

Bản đầu của tệp này (sáng 12/09) ghi RPC 21% và MCP 27%. Cả hai con số ấy SAI, và cách chúng
sai đáng ghi lại: phép đo grep tên phương thức trong mã nguồn, mà `mcp/server.py` ánh xạ
**generic** (`ten.replace("_", ".", 1)`) nên không tên tool nào xuất hiện nguyên văn. Đo lại
bằng cách GỌI `dung_tool()` cho 11, không phải 4. Bài học: *đếm bằng grep thì đo được cái viết
ra, không đo được cái chạy.* Trục RPC thì đúng là 12 lúc ấy — và đã nâng lên 34 cùng ngày.

---

## 2. Bảng tổng — mười trục

| # | Trục thiết kế | Spec mô tả | Mã đạt | % | Nhận xét |
|---|---|---|---|---|---|
| 1 | **Năng lực** (CDS-12) | 238 | **197** | **83%** | 41 còn lại đều chờ vật ở ngoài |
| 2 | **Thực thể dữ liệu** (DDD-14 §2) | 27 | **27** | **100%** | migration 0001–0007 phủ trọn |
| 3 | **Schema JSON** (`data/json/`) | 27 | **27** | **100%** | khớp 1–1 với thực thể |
| 4 | **Kiểu sự kiện ledger** (API-15 §5) | 26 | **23** | 88% | thiếu `autonomy.change`, `discover.result`, `gate.decision` |
| 5 | **Mã lỗi** (API-15 §3) | 29 | **25** | 86% | chưa ném: E1003, E4003, E6002, E7000 |
| 6 | **Quy tắc chính sách** (POL-17 §2) | 49 | **39** | 80% | 10 quy tắc chưa tình huống nào chạm |
| 7 | **Vai trò mô hình** (SDD §6) | 9 | **8** | 89% | thiếu `cartographer` — cần thị giác |
| 8 | **Mã kiểm thử TC** (STP-05) | 72 | **44** | 61% | 28 mã chưa xuất hiện trong test nào |
| 9 | **Công cụ MCP** (API-15) | 15 | **11** | 73% | 4 cái thiếu đều là `target.*`/`discover.*` — chờ board |
| 10 | **Phương thức JSON-RPC** (API-15 §1) | 57 | **34** | 60% | 23 thiếu = 16 `event.*` (chưa có kênh đẩy) + 7 chờ board |

Ngoài mười trục trên, ba trục phụ:

| Trục | Spec | Mã | Ghi chú |
|---|---|---|---|
| Manifest ISA (TGT-19 §2) | 6 họ | **2** (`armv7e-m`, `avr8`) | 4 còn lại là mốc M5, quyết định 07/09 |
| Dàn ý tài liệu (`doc/outlines.json`) | 6 loại | **6** | `doc.generate` đọc động từ spec, không chép tay |
| Màn hình UI (UXD-13, 23 màn) | 23 | **1** | panel EIDEKit 1474 dòng — xem §5 |

---

## 3. Trục 1 chi tiết — năng lực

### 3.1 Theo nhóm

| Nhóm | Đạt | Nhóm | Đạt | Nhóm | Đạt |
|---|---|---|---|---|---|
| `arch` | 11/11 ✅ | `kg` | 9/9 ✅ | `diagram` | 13/14 |
| `archive` | 7/7 ✅ | `memory` | 8/8 ✅ | `sim` | 6/7 |
| `board` | 5/5 ✅ | `plan` | 7/7 ✅ | `extract` | 17/21 |
| `chat` | 8/8 ✅ | `policy` | 7/7 ✅ | `search` | 7/9 |
| `code` | 16/16 ✅ | `project` | 9/9 ✅ | `passport` | 6/8 |
| `debug` | 6/6 ✅ | `report` | 4/4 ✅ | `registry` | 1/5 |
| `doc` | 12/12 ✅ | `req` | 8/8 ✅ | `bench` | 0/3 |
| `env` | 7/7 ✅ | `tool` | 10/10 ✅ | `discover` | 0/12 |
| | | `view` | 13/13 ✅ | `measure` | 0/3 |
| | | | | `target` | 0/9 |

**17 nhóm đủ.** 10 nhóm chưa đủ, và cả 10 chờ một vật ở ngoài.

### 3.2 Theo mốc

| Mốc | Đạt | Ý nghĩa |
|---|---|---|
| M0 | **22/22 · 100%** | Nền: dự án, store, chính sách, thu nhận tri thức |
| M1 | **74/75 · 99%** | Hiểu lệnh, tra cứu, lập kế hoạch, viết tài liệu |
| M2 | 80/99 · 81% | Sinh mã, board, mô phỏng nền, tài liệu đầy đủ |
| M3 | **19/29 · 66%** | Mô phỏng và gỡ lỗi |
| M4 | 2/9 · 22% | Registry chia sẻ, benchmark |
| M5 | 0/4 | ISA mở rộng |

### 3.3 Theo lớp rủi ro — đây là chỗ đọc kỹ

| Lớp | Đạt | Vì sao lệch |
|---|---|---|
| R0 | 118/140 · 84% | |
| R1 | 58/70 · 83% | |
| R2 | **19/19 · 100%** | |
| **R3** | **1/6 · 17%** | R3 = chạm phần cứng. Năm cái chưa có đều cần board |
| R4 | 0/1 | `env.install` biến thể sudo — cố ý không làm |

**Phần rủi ro cao gần như chưa được hiện thực, và đó là đúng kế hoạch** — không phải nợ kỹ
thuật. Quyết định của chủ sản phẩm 08/09: board thật để cuối cùng. Nhưng nó có hệ quả cần nói:
**những cổng chính sách nguy hiểm nhất (G-OPS-01…06, chặn nạp firmware) chưa bao giờ được thi
hành trên một thao tác thật** — chúng mới chỉ chạy qua 48 tình huống mô phỏng.

### 3.4 Theo mức tự chủ

| Tier | Đạt | Nghĩa |
|---|---|---|
| T1 | 174/206 · 84% | tự chạy |
| T1* | 11/15 · 73% | tự chạy phần hẹp, hỏi phần rộng |
| T2 | 10/14 · 71% | luôn hỏi người |
| T3 | 2/3 | chỉ người gọi |

---

## 4. Trục 10 — JSON-RPC, từ 12 lên 34 trong một ngày

Sáng 12/09 daemon phục vụ **12/57**. Chiều cùng ngày: **34/57**. 22 phương thức thêm vào đều là
**lớp vỏ mỏng trên năng lực đã có** — không một dòng logic nghiệp vụ mới.

```
Alias qua Router (12):  project.open · view.kg_map · view.focus · view.provenance
                        view.coverage · view.impact · view.timeline · view.rag_ask
                        view.rag_trace · passport.query · passport.browse · log.stats
Có logic riêng (10):    project.close · diagram.open · diagram.save · doc.open
                        hex.resolve · chat.send · chat.answer · chat.history
                        debug.ask · log.register
```

**Alias đi QUA `Router.invoke`, không gọi thẳng handler.** Đường tắt sẽ nhanh hơn và sẽ bỏ qua
cổng chính sách, nhật ký, và cửa sổ hoàn tác — cả ba. Test
`test_alias_view_di_QUA_router_nen_co_ghi_nhat_ky` canh đúng điều đó.

### 23 phương thức còn thiếu

| Nhóm | Số | Vì sao |
|---|---|---|
| **Sự kiện đẩy** (`event.*`) | 16 | Daemon là stdio request/response; chưa có kênh đẩy. Đây là việc HẠ TẦNG, không phải việc năng lực |
| `serial.*` · `discover.status` | 5 | Chờ board |
| `job.status` · `job.cancel` | 2 | Chờ hàng đợi chạy nền — hôm nay mọi lời gọi là đồng bộ |

> **Bất đối xứng vẫn còn, chỉ nhỏ đi:** `EideRpcGenerated.swift` có đủ 57 phương thức và
> `make check` xác nhận nó khớp spec, trong khi daemon trả lời 34. Cổng `check-gen` không bắt
> được vì nó so *bản sinh với spec*, không so *daemon với spec*. Từ 12/09 có
> `test_moi_phuong_thuc_dang_ky_deu_CO_trong_spec` canh chiều ngược lại (daemon không bịa ra
> phương thức ngoài spec), nhưng chiều "spec có mà daemon thiếu" vẫn là một con số đọc bằng tay.

### 4.1 Công cụ MCP — 11/15

`mcp_tools.json` khai 15; server phơi ra **11**. Bốn cái thiếu — `target_flash`,
`target_probe_read`, `target_serial`, `discover_ports` — đều chờ board, và server **cố ý bỏ
chúng**: một tool trỏ tới năng lực chưa hiện thực sẽ trả E1001 cho mọi lời gọi nhưng vẫn ăn một
suất trong trần 20 tool và vẫn chiếm chỗ trong phần mô tả mà mô hình phải đọc. `bo_qua()` cho
biết cái nào bị bỏ, để không ai tưởng danh sách đã đủ.

Nghĩa là **một tác tử ngoài (Claude Code, Cursor) hôm nay đã dùng được toàn bộ tầng tri thức của
EIDE**: tra hộ chiếu, xem xung đột, hỏi RAG có trích dẫn, soát mã, xuất báo cáo.

---

## 5. Trục UI — 23 màn hình, 1 panel

UXD-13 mô tả 23 màn hình và kho có 24 mockup HTML trong `docs/ui/`. Phía Swift, `EIDEKit` có
**1474 dòng / 8 tệp**: `EidePanel`, `EideClient`, `EideCommandBox`, `EideQuestionCard`,
`EideViews`, cộng hai tệp sinh tự động.

Đó là **màn hình số 1 (Chat)** của UXD-13 — ô lệnh, thẻ ý hiểu, thẻ câu hỏi, khung trả lời. 22
màn còn lại (Main, Knowledge, Code, Board, Debug, Bench, Docs…) chưa có.

**Đánh giá thẳng:** với một đề án thạc sĩ, một panel chạy thật cộng 24 mockup là đủ để chứng
minh luận điểm — luận điểm nằm ở tầng tác tử, không ở tầng giao diện. Nhưng nếu bảo vệ có câu
hỏi "sản phẩm dùng thế nào", thì thứ trình diễn được hôm nay là **CLI và MCP**, không phải IDE.

---

## 6. Năm chuỗi chuẩn (DPS-09 §4.4)

| Chuỗi | Bước đủ năng lực | Đứt tại |
|---|---|---|
| **Z-07** dự án từ zip | **23/23** ✅ | — |
| **P7** bộ tài liệu | **8/8** ✅ | — |
| **Z-05** thêm tính năng | 14/16 | `target.flash` — phần cứng |
| **Z-01** dự án từ ý tưởng | 12/14 | `search.reference_projects` — registry |
| **Z-10** dò board và nạp | 1/10 | `discover.ports` — phần cứng |

Hai chuỗi trọn vẹn, ba chuỗi đứt ở đúng chỗ dự kiến. **Không chuỗi nào còn đứt vì thiếu phần
mềm.**

---

## 7. Những chỗ spec có mà mã chưa chạm

| Hạng mục | Spec | Trạng thái | Chặn bởi |
|---|---|---|---|
| `roles.yaml` (ngân sách vai trò) | DDD-14 §yaml | **mã chưa sinh ra tệp này** | không — nợ nhỏ |
| `target.yaml` (cấu hình đích) | DDD-14 §yaml | mã chưa sinh | board |
| `manifest.json` (.hkp registry) | PKG-22 | chỉ đọc, chưa xuất | registry M4 |
| 10 quy tắc chính sách | POL-17 §2 | chưa tình huống nào chạm: `G-OPS-02/06`, `G-SRC-05`, `G4-02`, `G5-03/99`, `GEN-01/02/03`, `TOOL-04` | phần lớn cần phần cứng |
| 28 mã TC | STP-05 | chưa xuất hiện trong test nào | phần lớn cần board/đo |
| 4 mã lỗi | API-15 §3 | E1003, E4003, E6002, E7000 chưa có chỗ ném | E4003 cần board |
| 3 kiểu sự kiện ledger | API-15 §5 | `autonomy.change`, `discover.result`, `gate.decision` | hai cái cần board; `gate.decision` là **nợ thật** |

**`gate.decision` đáng chú ý riêng.** API-15 §5 khai kiểu sự kiện ấy và `store.py` có chú thích
viện dẫn nó (*"mọi quyết định cũng vào nhật ký `gate.decision`"*), nhưng không chỗ nào phát ra.
Quyết định cổng hiện chỉ vào bảng `decision_log`, không vào ledger — nên **chuỗi băm liên tục
không phủ chúng**, trong khi chú thích kia nói là có. Cùng hình dạng với các lỗi im lặng đã ghi:
một cơ chế trông như đang có hiệu lực.

---

## 8. Những chỗ mã có mà spec chưa nói

Ba thứ, cả ba đã ghi DEVIATIONS:

| Hạng mục | Mã làm | Mục |
|---|---|---|
| `Sandbox.run(cwd=…, them_path=…)` | Hai tham số ngoài SEC-25 §2/§3 — không có chúng thì `code.build` không chạy được trên bất kỳ máy nào | [DEV-088] |
| `trusted_packages` phân biệt tên gói theo OS | POL-17 §3 giả định ba hệ sinh thái đặt tên giống nhau | [DEV-089] |
| Bảng máy ảo QEMU trong `sim.py` | TGT-19 khai `sim.engine` là tên HỌ, không phải tên chương trình | [DEV-082] |

---

## 9. Chất lượng — đối chiếu với STP-05

| Chỉ số | Giá trị |
|---|---|
| Test Python | **1414** xanh (arm64 + x86_64) |
| Test Swift | **2699** xanh |
| Test gọi THẬT | 10 mạng · 7 mô hình · 1 engine mô phỏng · 2 chuỗi công cụ ARM |
| Nghiệm thu Sprint 1 / 2 / 3 | 17/17 · 18/18 · **13/13** |
| Tài liệu bộ hồ sơ | 32 docx + 4 xlsx |
| DEVIATIONS | 90 mục · **10 Mở** (8 nợ hiện thực, 2 chờ chủ sản phẩm) |
| Lỗi im lặng đã ghi | 11 |

---

## 10. Kết luận — ba câu

1. **Tầng tri thức và tầng tác tử: xong.** M0 100%, M1 99%, 17/27 nhóm năng lực đủ, hai chuỗi
   chuẩn trọn vẹn, và cả ba mắt xích trung tâm (`code.build`, `sim.run`, `constant_guard`) đã
   chạy THẬT chứ không chỉ xanh trong test.
2. **Tầng giao tiếp: đã dùng được, trừ kênh sự kiện.** 34/57 RPC (22 cái thêm trong ngày 12/09),
   11/15 MCP, 1/23 màn hình. Thứ còn thiếu đáng kể duy nhất là **16 phương thức `event.*`** —
   một việc hạ tầng (kênh đẩy), không phải việc năng lực. Tác tử ngoài qua MCP thì đã dùng được
   trọn tầng tri thức — đây là việc rẻ nhất còn
   lại và là việc duy nhất còn lại **không cần vật gì ở ngoài**.
3. **Tầng phần cứng: chưa bắt đầu, đúng kế hoạch.** 29 năng lực, 5/6 lớp R3, 10 quy tắc cổng và
   28 mã TC đều nằm chờ một bo mạch. Đây không phải nợ — đây là quyết định 08/09 — nhưng nó có
   nghĩa là **những cổng an toàn quan trọng nhất chưa lần nào gác một thao tác thật.**
