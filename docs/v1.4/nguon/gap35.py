#!/usr/bin/env python3
"""Sinh `docs/v1.4/EIDE-GAP-35_Ra_soat_ma_v1.4.xlsx` — báo cáo sai lệch mã ↔ thiết kế v1.4.

Nguồn thiết kế (đọc toàn bộ ngày 24/09/2026):
  * docs/v1.4/goi/README_REVIEW_BRIEF.md
  * docs/v1.4/goi/docs/md/EIDE-AGD-32_Thiet_ke_Tac_tu_Ky_su_Nhung_v1.4.md
  * docs/v1.4/goi/docs/md/EIDE-AAD-33_Kien_truc_Tac_tu_Ky_su_Nhung_v1.0.md
  * docs/v1.4/goi/docs/md/EIDE-UIP-34_Giao_thuc_Dieu_khien_Giao_dien_v1.0.md
  * docs/v1.4/goi/test/Usecase_Test_Agent_Ky_Su_Nhung.xlsx (đo 23/09/2026)

Mọi ô "Bằng chứng trong mã" đã được đối chiếu bằng cách đọc chính tệp đó trong kho ở
commit ed730f8 (24/09/2026). Tài liệu = mã: sửa bảng ở đây rồi chạy lại `python
docs/v1.4/nguon/gap35.py`, không sửa tay tệp .xlsx.
"""
from __future__ import annotations

import json
from pathlib import Path

import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

GOC = Path(__file__).resolve().parents[3]
RA = GOC / "docs/v1.4/EIDE-GAP-35_Ra_soat_ma_v1.4.xlsx"
XLSX_TC = GOC / "docs/v1.4/goi/test/Usecase_Test_Agent_Ky_Su_Nhung.xlsx"

# ─────────────────────────────────────────────────────────────── kiểu hiển thị
XANH = "1F3864"        # đầu bảng
NHAT = "D9E2F3"        # đầu nhóm
VANG = "FFF2CC"        # cảnh báo
DO = "F8CBAD"          # KHÔNG
CAM = "FFE699"         # MỘT PHẦN / KHÁC
LUC = "C6EFCE"         # CÓ

MAU_TRANG_THAI = {"KHÔNG": DO, "MỘT PHẦN": CAM, "KHÁC": CAM, "CÓ": LUC, "XONG Đ1": "A9D08E"}
VIEN = Border(*(Side(style="thin", color="BFBFBF"),) * 4)


def dau_bang(ws, tieu_de: list[str], rong: list[int], cao_dong: int = 15) -> None:
    ws.append(tieu_de)
    for i, (t, w) in enumerate(zip(tieu_de, rong, strict=True), start=1):
        o = ws.cell(row=1, column=i)
        o.font = Font(bold=True, color="FFFFFF", size=10)
        o.fill = PatternFill("solid", fgColor=XANH)
        o.alignment = Alignment(wrap_text=True, vertical="center")
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.row_dimensions[1].height = 30
    ws.freeze_panes = "A2"


def ke_bang(ws, so_cot: int, cot_trang_thai: int | None = None) -> None:
    for r in range(2, ws.max_row + 1):
        for c in range(1, so_cot + 1):
            o = ws.cell(row=r, column=c)
            o.alignment = Alignment(wrap_text=True, vertical="top")
            o.font = Font(size=10)
            o.border = VIEN
        if cot_trang_thai:
            o = ws.cell(row=r, column=cot_trang_thai)
            mau = MAU_TRANG_THAI.get(str(o.value or "").strip())
            if mau:
                o.fill = PatternFill("solid", fgColor=mau)
                o.font = Font(size=10, bold=True)
    ws.auto_filter.ref = f"A1:{get_column_letter(so_cot)}{ws.max_row}"


# ══════════════════════════════════════════════════════════ 1. Hướng dẫn đọc
def sheet_huong_dan(wb) -> None:
    ws = wb.active
    ws.title = "Huong dan"
    ws.column_dimensions["A"].width = 26
    ws.column_dimensions["B"].width = 118
    dong = [
        ("EIDE-GAP-35 — RÀ SOÁT MÃ HIỆN TẠI SO VỚI THIẾT KẾ v1.4", ""),
        ("Ngày lập", "24/09/2026 · Người lập: Claude Code · Kho: EIDE @ ed730f8 (nhánh master)"),
        ("Nhiệm vụ", "README_REVIEW_BRIEF.md §1.2 và §7: mỗi mục thiết kế → CÓ / MỘT PHẦN / "
                     "KHÔNG / KHÁC trong mã, ở tệp nào, dòng nào, sửa ở đợt nào."),
        ("Tài liệu đã đọc",
         "README_REVIEW_BRIEF.md (toàn bộ); EIDE-AGD-32 v1.4 (§1–§10); EIDE-AAD-33 v1.0 "
         "(§1–§14); EIDE-UIP-34 v1.0 (§1–§12); Usecase_Test_Agent_Ky_Su_Nhung.xlsx "
         "(4 sheet, 76 TC, đo 23/09/2026)."),
        ("Thứ tự ưu tiên khi tài liệu mâu thuẫn", "AAD-33 > AGD-32 > UIP-34 > bộ hồ sơ v1.2 "
         "(SRS-02, SAD-03, CDS-12, CXD-10, MEM-11, APD-08, DPS-09, UXD-13). Mâu thuẫn phát hiện "
         "được ghi ở cột \"Ghi chú / DEV\" của sheet \"Ra soat (GAP)\", không tự chọn."),
        ("", ""),
        ("CÁCH ĐỌC", ""),
        ("Sheet \"Ra soat (GAP)\"", "Bảng chính: 1 dòng = 1 mục thiết kế. Lọc theo cột "
         "\"Trạng thái\" để thấy phần KHÔNG có; lọc theo \"Sửa đổi\" (Đ1–Đ6) để thấy việc của "
         "Đợt 1; lọc theo \"Đợt\" để thấy phạm vi từng đợt."),
        ("Sheet \"Dot 1 (D1-D6)\"", "Việc phải làm của Đợt 1, theo thứ tự Đ1→Đ6, kèm tệp phải "
         "tạo/sửa, unit test phải có, ca đo mở khoá. Đây là sheet dùng để giao việc."),
        ("Sheet \"Nang luc moi-doi\"", "12 năng lực mới/đổi của AAD-33 §4 — cái nào đã có, "
         "cái nào phải viết CDS-12 mới."),
        ("Sheet \"Luoc do JSON\"", "14 lược đồ của AAD-33 §10 và chỗ tương đương hiện có."),
        ("Sheet \"Giao thuc UAP\"", "UIP-34: 6 bất biến, 11 HumanAct, 14 UICommand, 12 loại "
         "khối, 6 loại thẻ, 12 ca tuân thủ UP01–UP12 — đối chiếu với 65 phương thức JSON-RPC "
         "hiện có."),
        ("Sheet \"Cong phe duyet\"", "8 cổng của v1.4 ↔ các cổng đang có trong "
         "docs/spec/policy/rules.yaml."),
        ("Sheet \"Ca do 76 TC\"", "76 ca đo 23/09/2026 + sửa đổi nào mở khoá ca nào."),
        ("Sheet \"Thong ke\"", "Đếm theo trạng thái / đợt / nhóm (công thức, tự tính lại)."),
        ("", ""),
        ("QUY ƯỚC TRẠNG THÁI", ""),
        ("CÓ", "Mã làm đúng điều thiết kế nói; chỉ cần test canh để không trôi."),
        ("MỘT PHẦN", "Có một phần hành vi, nhưng thiếu trường, thiếu bước, hoặc chạy sai chỗ "
                     "trong luồng."),
        ("KHÔNG", "Không có dòng mã nào làm việc này."),
        ("KHÁC", "Mã làm việc ấy nhưng theo cách khác thiết kế (tên khác, chỗ khác, cơ chế "
                 "khác) — phải chốt: sửa mã hay cập nhật tài liệu (ghi DEVIATIONS)."),
        ("XONG Đ1", "Đã hiện thực ngày 24/09/2026; cột cuối ghi tệp và BÀI KIỂM canh nó. "
                    "`make check-py` xanh: ruff, 1975 test, check-spec, check-gen."),
        ("", ""),
        ("KẾT LUẬN NGẮN", ""),
        ("Vấn đề kiến trúc lớn nhất",
         "1) Không có tầng NLU xác định (DX, tách kênh) — đường dẫn/chip/số vẫn do mô hình điền. "
         "2) Không có pha S2 (kiểm kê xác định) và S4 (lập kế hoạch có tiền đề): chuỗi lấy "
         "nguyên từ 22 mẫu tĩnh, nút thiếu tiền đề thì chết tại chỗ. 3) Pha S3 (làm rõ) tồn tại "
         "nhưng KHÔNG nằm trên đường sống. 4) Hợp đồng năng lực chưa có requires/produces nên "
         "planner không có gì để suy. 5) Cầu giao diện chưa phải UAP: 65 phương thức JSON-RPC "
         "thay cho một cửa console.act."),
        ("Thứ tự làm",
         "Đ1 (DX + slots.paths mảng + origin) → Đ2 (ingest.classify + quét script) → "
         "Đ3 (passport.propose + G-DATA + manifest armv7-m) → Đ4 (tách kênh) → "
         "Đ5 (requires/produces + planner + Inventory) → Đ6 (nối S3 + ba dải tin cậy). "
         "Đ5 phải đi sau Đ1 vì planner cần slot xác định; nhưng Inventory (S2) phải làm TRƯỚC "
         "Đ3 và Đ6 vì cả hai đọc bảng kiểm kê."),
        ("Ghi sai khác", "Kho này đã dùng tới DEV-219 trong docs/DEVIATIONS.md. Mục mới của "
         "Đợt 1 bắt đầu từ DEV-220. Brief §8 gọi tệp là docs/md/EIDE-DEV-LOG.md — xem dòng "
         "K-05 của sheet GAP."),
    ]
    for a, b in dong:
        ws.append([a, b])
    for r in range(1, ws.max_row + 1):
        ws.cell(row=r, column=1).font = Font(bold=True, size=10)
        ws.cell(row=r, column=1).alignment = Alignment(wrap_text=True, vertical="top")
        ws.cell(row=r, column=2).alignment = Alignment(wrap_text=True, vertical="top")
        ws.cell(row=r, column=2).font = Font(size=10)
    ws["A1"].font = Font(bold=True, size=14, color=XANH)
    for r in (7, 17, 24):
        ws.cell(row=r, column=1).fill = PatternFill("solid", fgColor=NHAT)
        ws.cell(row=r, column=2).fill = PatternFill("solid", fgColor=NHAT)


# ══════════════════════════════════════════════════════════ 2. Bảng GAP
# (ID, Nhóm, Tài liệu §, Yêu cầu thiết kế, Trạng thái, Bằng chứng trong mã,
#  Ca đo, Hành động đề xuất, Sửa đổi, Đợt, Công, Ghi chú/DEV)
GAP: list[tuple[str, ...]] = [
    # ── A. Kiến trúc tổng thể
    ("G-001", "A. Kiến trúc", "AAD-33 §1.2",
     "Sáu lớp có ranh giới rõ: eide/nlu/*, eide/orchestrator/*, eide/caps/<ns>/, "
     "eide/knowledge/*, eide/llm/*, eide/memory/*, eide/exec/*",
     "KHÁC",
     "src/eide/ chỉ có caps/, daemon/, mcp/, orchestrator.py; toàn bộ L3/L5/L6 nằm phẳng trong "
     "src/eide_core/ (router.py, policy.py, ledger.py, gateway.py, rag.py, memory.py, "
     "sandbox.py, chain.py)",
     "—",
     "Không đổi mã chạy: thêm các gói mới (nlu/, orchestrator/, exec/) cho phần Đợt 1 và ghi "
     "bảng ánh xạ eide_core → L3/L5/L6 vào DEVIATIONS; không tách lại eide_core trong Đợt 1",
     "—", "Đợt 1", "M",
     "Đề nghị DEV-220: AAD-33 §1.2 nói vị trí tệp, kho đang dùng cách chia eide/ ↔ eide_core/ "
     "của SAD-03 v1.2. Cập nhật tài liệu thay vì tái cấu trúc giữa đợt sửa lỗi."),
    ("G-002", "A. Kiến trúc", "AAD-33 §1.3, AGD-32 §6",
     "Một lượt gõ đi trọn S0→S1→S2→S3→S4→S5→S6; mỗi pha ghi sổ cái; ngân sách 300 giây",
     "KHÁC",
     "src/eide/daemon/rpc.py:988 `_chat_send` = chặn xác định (:1014, :1042, :1059, :1066) → "
     "chat.parse_intent (:1069) → chat.ground (:1073) → chat.fill_defaults (:1091) → "
     "chat.orchestrate (:1129). KHÔNG có S2, S3, S4 tách pha. Hạn 300 s có ở rpc.py:937",
     "TC001, TC004, TC009, TC064",
     "Viết lại `_chat_send` thành bảy pha, mỗi pha một hàm thuần có lược đồ vào/ra và một "
     "sự kiện sổ cái (s0.decision … s6.report); giữ nguyên các đường tắt xác định đang đạt",
     "Đ6", "Đợt 1", "L", ""),

    # ── B. L2 — NLU
    ("G-010", "B. NLU (L2)", "AAD-33 §2.1",
     "N0 chuẩn hoá: NFC, nhận ngôn ngữ, tách mệnh đề, sinh bản không dấu; giữ utterance.raw",
     "MỘT PHẦN",
     "src/eide_core/request_ops.py:69 `_bo_dau` (bỏ dấu + gộp khoảng trắng) dùng riêng cho S0; "
     "không có NFC, không tách mệnh đề, không có đối tượng Utterance",
     "TC024, TC028",
     "Tạo src/eide/nlu/normalize.py trả Utterance{raw, normalized, no_accent, clauses[]} + "
     "utterance.schema.json; dùng lại `_bo_dau` cho bản không dấu",
     "Đ1", "Đợt 1", "S", ""),
    ("G-011", "B. NLU (L2)", "AAD-33 §2.2",
     "DX trích paths[] (NHIỀU giá trị) bằng regex TRƯỚC mọi lời gọi mô hình, kiểm os.path.exists, "
     "không tồn tại thì giữ với exists=false để S3 hỏi",
     "MỘT PHẦN",
     "src/eide_core/request_ops.py:258–283 `duong_dan_trong_cau` trả mảng nhưng: chỉ nhận đường "
     "dẫn tuyệt đối/`~` (:258), KHÔNG kiểm tồn tại, và chỉ được gọi MUỘN khi dựng tham số nút "
     "(src/eide/caps/chat.py:895–901) — scalar lấy `dds[0]`, mất tệp thứ hai",
     "TC010, TC011, TC016, TC023, TC043, TC045, TC052, TC072",
     "Chuyển thành src/eide/nlu/dx.py chạy ngay sau N0; thêm đường dẫn tương đối trong dự án, "
     "chuỗi trong nháy/backtick, exists; ghi DXResult vào sổ cái; slots.paths là mảng",
     "Đ1", "Đợt 1", "M",
     "DEV-208 đã ghi nửa việc (regex thay mô hình). Phần còn thiếu là VỊ TRÍ trong luồng và "
     "phép kiểm tồn tại."),
    ("G-012", "B. NLU (L2)", "AAD-33 §2.2",
     "DX trích chips[] theo family_patterns + bí danh (Uno→ATmega328P, Blue Pill→STM32F103C8T6), "
     "tra registry chip để chuẩn hoá mã, không có thì nhãn unknown_chip",
     "MỘT PHẦN",
     "src/eide/caps/project.py:607 `_isa_tu_chip` khớp family_patterns của docs/spec/isa/*.yaml "
     "(3 manifest); src/eide/caps/discover.py:419 cùng cơ chế. KHÔNG có bảng bí danh, KHÔNG có "
     "registry chip (schema.sql không có bảng chip)",
     "TC002, TC008, TC015, TC018, TC046",
     "Đưa phép khớp vào nlu/dx.py; thêm bảng bí danh trong docs/spec/isa/aliases.yaml; dựng "
     "registry chip (Đợt 2) — Đợt 1 chỉ cần chips[] + in_registry=false",
     "Đ1, Đ3", "Đợt 1", "M", ""),
    ("G-013", "B. NLU (L2)", "AAD-33 §2.2",
     "DX trích numbers[] (số + đơn vị V/mA/kΩ/MHz/KB/ms/°C/%, dải \"3,0–4,2 V\") chuẩn hoá về SI",
     "KHÔNG", "—", "TC021, TC056, TC057",
     "nlu/dx.py: bộ trích số + đơn vị, giữ chuỗi gốc, quy về SI; dùng cho calc.* và fact.compare",
     "Đ1", "Đợt 1", "M", ""),
    ("G-014", "B. NLU (L2)", "AAD-33 §2.2",
     "DX trích urls[] (tách domain, nhãn nhà sản xuất theo danh sách tin cậy)",
     "KHÔNG",
     "search.py có danh sách nguồn nhưng không trích URL từ câu người gõ", "TC072, TC010",
     "nlu/dx.py + docs/spec/policy/trusted_sources.yaml", "Đ1", "Đợt 1", "S", ""),
    ("G-015", "B. NLU (L2)", "AAD-33 §2.2",
     "DX trích ids[] (REQ-*, ADR-*, UC*, TC*, run-*, MOD-*) và tra store, không có → nhãn dangling",
     "KHÔNG",
     "src/eide/daemon/rpc.py:184 `la_cau_tro_nguoc` nhận \"làm lại/tiếp tục\" nhưng không trích "
     "mã hiện vật",
     "TC065, TC066, TC074",
     "nlu/dx.py + tra store; dùng cho project.resume và \"làm lại run-0042\"",
     "Đ1", "Đợt 1", "S", ""),
    ("G-016", "B. NLU (L2)", "AAD-33 §2.2",
     "DX nhận back_refs (\"làm lại\", \"tiếp tục\", \"cái vừa rồi\") và giải bằng tra bảng run",
     "CÓ",
     "src/eide/daemon/rpc.py:184–207 + gọi ở :1042 `_tro_nguoc`", "TC065",
     "Giữ hành vi, chuyển vào nlu/dx.py để DXResult có back_refs và có unit test riêng",
     "Đ1", "Đợt 1", "S", "DEV-196 — hồi quy phải giữ."),
    ("G-017", "B. NLU (L2)", "AAD-33 §2.2",
     "DX trích quoted[] (chuỗi trong nháy kép/backtick) để làm dữ liệu, không diễn giải",
     "KHÔNG", "—", "TC017",
     "nlu/dx.py; chuỗi trích được đi kênh DATA của Đ4", "Đ1, Đ4", "Đợt 1", "S", ""),
    ("G-018", "B. NLU (L2)", "AAD-33 §2.2 (bất biến slot)",
     "Slot hợp nhất theo ưu tiên DX > trả lời người ở S3 > mô hình > fill_defaults; mỗi slot có "
     "origin; slot origin=model KHÔNG BAO GIỜ được dùng làm đường dẫn/mã chip để chạy nút",
     "KHÔNG",
     "docs/spec/dialog/intent.schema.json không có `origin`; src/eide/caps/chat.py:90 ghi thẳng "
     "`slots[\"path\"]` từ đính kèm; chat.py:901 `${_path}` = `dds[0] or slots.path` (mô hình) — "
     "không phân biệt nguồn",
     "TC010, TC016, TC023, TC043, TC045, TC072",
     "intent.schema.json v2 (slots.paths là mảng, mỗi slot {value, origin}); hàm hợp nhất slot "
     "trong nlu/merge.py; Router ghi origin vào sổ cái; chặn origin=model làm đường dẫn",
     "Đ1", "Đợt 1", "M", "Đây là mục gốc của 11 ca \"đường dẫn bịa\"."),
    ("G-020", "B. NLU (L2)", "AAD-33 §2.3",
     "S0 là rule engine đọc bộ luật từ tệp YAML kiểm thử độc lập; mỗi luật có mẫu, hành động, "
     "lý do hiển thị và MÃ LUẬT để ghi sổ",
     "KHÁC",
     "Bộ dấu hiệu viết cứng trong Python: src/eide_core/request_ops.py:59 `DAU_HIEU` (G-OPS), "
     ":181 `DAU_HIEU_PHAP_LY`, :189 `DAU_HIEU_AN_TOAN`, :196 `DAU_HIEU_HA_CHUAN`. Chỉ TÊN thao "
     "tác đọc từ docs/spec/policy/rules.yaml (:77 `_op_bi_chan`)",
     "TC007, TC022, TC035, TC036, TC068, TC069 (đang ĐẠT — hồi quy)",
     "Chuyển bảng dấu hiệu sang docs/spec/policy/s0_rules.yaml (STOP/BACKREF/G-OPS/P-SAFE/"
     "P-LAW/P-QUAL/P-INJ) + gate0.schema.json; giữ nguyên hành vi, thêm mã luật vào sổ cái",
     "—", "Đợt 1", "M",
     "Rủi ro hồi quy CAO: 6/16 ca đang đạt là nhờ lớp này. Đổi nơi chứa luật, không đổi luật."),
    ("G-021", "B. NLU (L2)", "AAD-33 §2.3 (P-INJ)",
     "S0 quét mẫu chèn lệnh trong DỮ LIỆU (\"ignore previous instructions\", lệnh shell) → đánh "
     "dấu tài liệu nghi ngờ, cảnh báo, không thực thi, ghi sổ",
     "KHÔNG",
     "Không có bộ quét injection nào trong src/ (grep \"injection|ignore previous\" = 0)",
     "TC014",
     "Thêm luật P-INJ vào s0_rules.yaml + quét ở ingest.index_text và loại đoạn nghi khỏi "
     "khối RAG của prompt",
     "Đ2", "Đợt 1", "M", ""),
    ("G-022", "B. NLU (L2)", "AAD-33 §2.3",
     "Ở ASK/REJECT/STOP lượt kết thúc tại S0, không lời gọi mô hình nào; mục tiêu < 300 ms",
     "CÓ",
     "src/eide/daemon/rpc.py:1014–1068 — bốn đường tắt đứng TRƯỚC chat.parse_intent",
     "TC007, TC035, TC036, TC068, TC069",
     "Giữ; thêm ts từng pha vào sổ cái để đo được 300 ms (hiện không có số)",
     "—", "Đợt 1", "S", "DEV-200, DEV-204."),
    ("G-030", "B. NLU (L2)", "AAD-33 §2.4, AGD-32 Đ4",
     "S1a tách câu thành ba kênh DIRECTIVE / PRODUCT / DATA bằng một lời gọi mô hình nhỏ có "
     "lược đồ; req.elicit CHỈ nhận product_text",
     "KHÔNG",
     "Không có nlu/split_channels; toàn bộ câu gõ đi xuống nút dưới dạng `${_text}` "
     "(src/eide/caps/chat.py:901) và req.elicit nhận nguyên câu",
     "TC003, TC017, TC024, TC028",
     "Tạo nlu/channels.py + channels.schema.json; sửa mẫu chuỗi để req.elicit nhận "
     "product_text, Router nhận directive_text, DATA thành literal slot",
     "Đ4", "Đợt 1", "M", ""),
    ("G-031", "B. NLU (L2)", "AAD-33 §2.4, AGD-32 §2 N7",
     "Rủi ro tác tử tự phát hiện đi vào risk[] của đặc tả, KHÔNG BAO GIỜ thành FR",
     "KHÔNG",
     "src/eide/caps/req.py `req.elicit` không có trường risk; đo 23/09 sinh FR-COM-01 từ một "
     "rủi ro (TC003)",
     "TC003, TC017, TC024, TC028",
     "Thêm risk[] vào lược đồ đặc tả + chặn: mệnh đề kênh DIRECTIVE/rủi ro không được tạo FR; "
     "test canh N7",
     "Đ4", "Đợt 1", "M", ""),
    ("G-040", "B. NLU (L2)", "AAD-33 §2.5.1",
     "Ý định là TÊN một capability hoặc một mẫu chuỗi, chọn từ danh sách đóng sinh tự động từ "
     "caps.json, lọc trước theo DX",
     "KHÁC",
     "docs/spec/dialog/intent.schema.json — enum 23 nhãn tự đặt (knowledge.build, code.feature, "
     "big_command, review.ask…), không trùng tên năng lực nào và không sinh từ caps.json; "
     "danh sách không lọc theo DX",
     "TC001, TC004, TC043",
     "Sinh enum từ caps.json + 22 mẫu chuỗi của chains.json; lọc namespace theo DX "
     "(chips → passport/arch/code; .csv/.sal → analyze; \"nạp\" → target)",
     "Đ1, Đ6", "Đợt 1", "M",
     "Đây là lý do \"xoá option bytes\" từng rơi vào target.flash (DEV-200)."),
    ("G-041", "B. NLU (L2)", "AAD-33 §2.5.2",
     "Lược đồ S1b có slots{...origin}, alt_intents[], coref{}, why",
     "MỘT PHẦN",
     "intent.schema.json có intent/slots/is_big/confidence/lang/mentions; THIẾU origin, "
     "alt_intents, coref, why; slots.path là chuỗi đơn",
     "TC004, TC011, TC043",
     "XONG 24/09: sinh lại từ docs/ho-so/nguon/dps.js — slots.paths/chips là mảng, thêm origins, "
     "alt_intents, coref, why; bỏ hai slot chuỗi đơn path/chip",
     "Đ1", "Đợt 1", "S",
     "src/eide/caps/memory.py:877 KHÔNG phải bản sao lược đồ intent — đó là một lược đồ riêng "
     "cho việc tóm tắt, chỉ dùng lại VAI TRÒ intent. Không phải sửa."),
    ("G-042", "B. NLU (L2)", "AAD-33 §2.5.2",
     "is_big tính bằng MÃ: (mẫu chuỗi ≥ 8 nút) OR (từ khoá \"làm hết/toàn bộ\") OR (> 3 mệnh đề "
     "DIRECTIVE)",
     "KHÁC",
     "is_big do MÔ HÌNH điền (intent.schema.json) và chỉ được ghi sổ: "
     "src/eide/caps/chat.py:95. Không nơi nào dùng nó để quyết định",
     "TC(G-SCOPE), TC001",
     "Tính is_big trong mã sau khi S4 dựng chuỗi; bỏ trường khỏi đầu ra mô hình hoặc chỉ dùng "
     "làm gợi ý; nối vào cổng G-SCOPE",
     "Đ5", "Đợt 1", "S", "Brief §3 nêu đúng: \"is_big được ghi vào ledger rồi không dùng ở đâu\"."),
    ("G-043", "B. NLU (L2)", "AAD-33 §2.5.3, AGD-32 Đ6",
     "Ba dải tin cậy: > 0,85 → S2; 0,60–0,85 → S3 (mục đầu là xác nhận ý định kèm alt_intents); "
     "< 0,60 → S3 hỏi thẳng, không chạy gì",
     "MỘT PHẦN",
     "src/eide/caps/chat.py:35 `NGUONG_UNKNOWN = 0.6` và :87 `< 0,6 → unknown` — hai dải, và "
     "nhánh unknown đi vào mẫu chuỗi chứ không vào S3",
     "TC001, TC004, TC006, TC073",
     "Thêm dải ngờ 0,60–0,85 → S3 với mục đầu là xác nhận ý định; < 0,60 → S3 hỏi thẳng và "
     "KHÔNG tạo dự án",
     "Đ6", "Đợt 1", "S", ""),
    ("G-044", "B. NLU (L2)", "AAD-33 §2.5.3",
     "Hiệu chuẩn confidence theo tập kịch bản (bảng điểm thô → xác suất đúng thực đo), ngưỡng "
     "0,60/0,85 đặt ở mức sai < 5 % và < 20 %",
     "KHÔNG", "—", "toàn bộ P1",
     "Sau khi chạy 76 TC × 5 lần, dựng bảng hiệu chuẩn từ số đo; chưa có số thì giữ ngưỡng tài liệu",
     "—", "Đợt 2", "M", ""),
    ("G-050", "B. NLU (L2)", "AAD-33 §2.6",
     "DST giữ project_id, run_id, pending_question{gap_keys, round}, focus{artefact}, "
     "recent_mentions (10 lượt), last_intents, assumptions_active, autonomy_level",
     "MỘT PHẦN",
     "src/eide_core/memory.py:48 WorkingMemory (M1) có pending_question (:58); :100 SessionMemory "
     "(M2) giữ lượt hội thoại; KHÔNG có focus, recent_mentions, last_intents, assumptions_active",
     "TC006, TC065, TC066",
     "Tạo nlu/dst.py dựng DialogueState trên M1/M2 đang có; lưu khi đóng phiên; in "
     "assumptions_active ở S6",
     "Đ6", "Đợt 1", "M", ""),
    ("G-051", "B. NLU (L2)", "AAD-33 §2.6",
     "Khi có pending_question, câu tiếp theo được thử ghép vào gap_keys trước (mô hình nhỏ, "
     "lược đồ {answers:{key:value}}); ghép được thì trộn slot và quay lại S2, KHÔNG phân loại "
     "lại ý định",
     "MỘT PHẦN",
     "src/eide/daemon/rpc.py:1438 `chat_answer` trả lời theo hàng đợi clarification/cổng, nhưng "
     "câu gõ tự do vào `chat.send` luôn đi lại từ parse_intent",
     "TC004, TC006, TC057",
     "Thêm bước ghép-câu-trả-lời ở đầu S1; đường quay lại S2 không qua S1b",
     "Đ6", "Đợt 1", "M", ""),
    ("G-060", "B. NLU (L2)", "AAD-33 §2.7, AGD-32 Đ6",
     "S3 là MỘT lời gọi mô hình nhận câu gõ + intent + BẢNG KIỂM KÊ (S2) + tiền đề của mẫu "
     "chuỗi, chỉ quyết gap nào ĐÁNG HỎI, không mô tả tình trạng dự án, không điền thay người",
     "KHÁC",
     "src/eide/caps/chat.py:242–292 `chat.clarify` gộp gaps thành MỘT câu hỏi phẳng, tự chọn "
     "mặc định khi hết giờ, KHÔNG nhận Inventory và KHÔNG nhận requires. Nó chỉ được gọi từ "
     "src/eide/orchestrator.py:42 — tệp 69 dòng KHÔNG AI IMPORT (chỉ tests/test_chat.py:359) — "
     "và từ mẫu chuỗi `unknown`",
     "TC001, TC004, TC006, TC057, TC073",
     "Nối S3 vào đường sống `_chat_send`; truyền Inventory + requires vào prompt; xoá/hợp nhất "
     "src/eide/orchestrator.py",
     "Đ6", "Đợt 1", "L", "Brief §3 nêu đúng: chat.clarify đã nối nhưng nối vào mã chết."),
    ("G-061", "B. NLU (L2)", "AAD-33 §2.7",
     "Thẻ S3 là MỘT thẻ NHIỀU MỤC: mục bắt buộc đánh dấu, mục tuỳ chọn có giá trị giả định điền "
     "sẵn, có gia_dinh_neu_bo_qua, tối đa 2 vòng",
     "MỘT PHẦN",
     "src/eide/caps/chat.py:258–269 dựng một `question` phẳng {text, options[], default, "
     "timeout_s}; không có required/why/unit/assumption; không đếm vòng hỏi",
     "TC004, TC057",
     "clarify.schema.json + card.schema.json (kind=clarify); đếm vòng trong DST; hết vòng thì "
     "chạy với giả định và in ở S6",
     "Đ6", "Đợt 1", "M", ""),
    ("G-062", "B. NLU (L2)", "AAD-33 §2.7",
     "Cổng an toàn (G-OPS) KHÔNG BAO GIỜ là một mục trong thẻ S3 — thẻ riêng do Policy engine phát",
     "CÓ",
     "src/eide/daemon/rpc.py:1066 trả thẻ thao tác-không-đảo-ngược riêng trước khi vào chuỗi",
     "TC035, TC068",
     "Giữ; viết test canh bất biến I6 (một chữ \"Có\" không trả lời hai thứ)",
     "—", "Đợt 1", "S", ""),
    ("G-063", "B. NLU (L2)", "AAD-33 §2.7",
     "Hai nút cùng cần một tiền đề chỉ sinh MỘT gap (gộp khoá trùng trước khi gọi mô hình)",
     "KHÔNG",
     "Không có bước gộp gap: mỗi nút tự hỏi khi thiếu tham số (on_ask=wait trong chains.json)",
     "TC004, TC057",
     "Gộp gap theo khoá ở S4 trước khi gọi S3", "Đ5, Đ6", "Đợt 1", "S", ""),

    # ── C. L3 — Điều phối
    ("G-070", "C. Điều phối (L3)", "AAD-33 §3.1, AGD-32 §2 N3",
     "S2 dựng bảng Inventory xác định (project, requirements, options, passports, documents, "
     "design, code, toolchain, sim, target, runs, adrs, assumptions) — 0 token, < 50 ms, cache "
     "theo mtime",
     "KHÔNG",
     "grep \"inventory\" trong src/ = 0 dòng. Thứ gần nhất là src/eide/caps/chat.py:102–141 "
     "`chat.ground`: liệt kê dự án trùng/gần tên + ba ô thiếu (project, board)",
     "TC008, TC065 và mọi ca cần biết \"dự án đang có gì\"",
     "Tạo src/eide/orchestrator/inventory.py + inventory.schema.json đọc store.sqlite một lượt; "
     "dùng chung cho S3, S4, S5, thanh trạng thái",
     "Đ3, Đ5", "Đợt 1", "L",
     "Phải làm TRƯỚC Đ3 và Đ6 — cả hai đều đọc bảng này."),
    ("G-071", "C. Điều phối (L3)", "AAD-33 §3.2.1",
     "Hợp đồng capability khai requires[]{artefact, min_count, tier_min, how_to_get}, "
     "produces[], risk, gate, on_ask, llm, cost_est, idempotent, undo",
     "MỘT PHẦN",
     "docs/spec/caps.json — 246 mục, khoá: code/ns/name/desc/inp/out/risk/tier/ground/ask/ref/"
     "ms/m0. requires = 0 mục, produces = 0 mục. `on_ask` chỉ có ở NÚT trong "
     "docs/spec/dialog/chains.json",
     "TC009, TC013, TC064",
     "Mở rộng caps.json (+ capability.schema.json) với requires/produces/gate/llm/cost_est/"
     "idempotent/undo; sinh lại từ nguồn hồ sơ trong docs/ho-so/nguon/; `make check-spec` kiểm",
     "Đ5", "Đợt 1", "L",
     "Không có bảng này thì planner có tiền đề không thể làm — đây là điều kiện của Đ5."),
    ("G-072", "C. Điều phối (L3)", "AAD-33 §3.2.2, AGD-32 Đ5",
     "Planner đối chiếu requires với Inventory ∪ produces của các nút trước; thiếu + có "
     "how_to_get → chèn nút (đệ quy ≤ 3, phát hiện vòng)",
     "KHÔNG",
     "Chuỗi lấy nguyên từ 22 mẫu tĩnh docs/spec/dialog/chains.json; "
     "src/eide/caps/chat.py:874 BỎ nút chưa hiện thực và nối lại `when`; "
     "src/eide_core/chain.py:199 `kiem` chỉ kiểm deterministic, :289 `tim_chu_trinh`",
     "TC009, TC013, TC064",
     "Tạo orchestrator/planner.py (`plan.with_preconditions`) + plan.schema.json; giữ mẫu chuỗi "
     "làm điểm bắt đầu, chèn tiền đề trước khi kiểm deterministic",
     "Đ5", "Đợt 1", "L", ""),
    ("G-073", "C. Điều phối (L3)", "AAD-33 §3.2.2",
     "Thiếu artefact KHÔNG có how_to_get (đường dẫn, mã chip) → tạo gap cho S3, không chạy nút",
     "KHÔNG",
     "Nút thiếu tham số bị hỏi ở TẦNG NÚT (on_ask=wait) hoặc hỏng E2000 — không có đường về S3",
     "TC009, TC016, TC064",
     "Trả gap từ planner về S3; ghi s3.gaps vào sổ cái", "Đ5", "Đợt 1", "M", ""),
    ("G-074", "C. Điều phối (L3)", "AAD-33 §3.2.2, §3.4 G-SCOPE",
     "is_big HOẶC > 7 nút → phát thẻ kế hoạch (bước, thứ tự, ước lượng token/giây, giả định, "
     "cổng sẽ gặp) và CHỜ GẬT",
     "MỘT PHẦN",
     "src/eide/daemon/rpc.py:1100–1128 `plan_only` bật theo MỨC TỰ CHỦ (A0/A1 thì chờ gật), "
     "không theo is_big hay số nút",
     "TC001, TC073",
     "Thêm điều kiện is_big OR nút > 7 → thẻ kế hoạch kèm cost_est tổng từ hợp đồng",
     "Đ5", "Đợt 1", "M", "DEV-140 đã làm phần chờ-gật; thiếu điều kiện kích hoạt của v1.4."),
    ("G-075", "C. Điều phối (L3)", "AAD-33 §3.3",
     "Router kiểm requires lần nữa trên Inventory tươi TRƯỚC khi chạy và kiểm produces (hiện vật "
     "có thật, đúng lược đồ) SAU khi chạy",
     "KHÔNG",
     "src/eide_core/router.py chạy nút + áp cổng + ghi sổ + hoàn tác; không có phép kiểm hợp "
     "đồng tiền đề/hiện vật",
     "TC013, TC019, TC076",
     "Thêm `check(inv, params) → list[Gap]` theo Capability Protocol (AAD-33 §4) và phép kiểm "
     "produces sau nút",
     "Đ5", "Đợt 1", "M", ""),
    ("G-076", "C. Điều phối (L3)", "AAD-33 §3.3",
     "Nút hỏng E2xxx (thiếu tiền đề) lúc chạy → quay về S3 với gap tương ứng (≤ 2 lần/lượt), "
     "không chết tại chỗ",
     "KHÔNG",
     "E2000 làm nút hỏng; `on_ask: skip` giữ lượt không tụt (DEV-216) nhưng không có đường về S3",
     "TC009, TC064",
     "Thêm nhánh E2xxx → S3 với bộ đếm quay lại", "Đ5", "Đợt 1", "M",
     "Phải GIỮ DEV-216: on_ask=skip không kéo lượt xuống."),
    ("G-077", "C. Điều phối (L3)", "AAD-33 §3.3",
     "Vòng tự sửa ≤ 3 lần cho build.compile / sim.run, mỗi lần ghi diff + lý do; quá N thì dừng "
     "và báo",
     "MỘT PHẦN",
     "src/eide/caps/code.py `code.self_repair` có; chưa nối vào vòng build–sửa–build có đếm",
     "TC017, TC019",
     "Nối vào S5 với N=3 và ghi diff/lý do từng lần", "—", "Đợt 3", "M", ""),
    ("G-078", "C. Điều phối (L3)", "AAD-33 §3.3",
     "Retry lỗi tạm (E5290, mạng) lùi luỹ thừa 2→4→8 s, tối đa 3; lỗi xác định không retry",
     "MỘT PHẦN",
     "docs/spec/models.yaml:37–40 `policy.fallback_on: [rate_limit, timeout, refusal]` (đổi "
     "nhà cung cấp); không có lùi luỹ thừa",
     "TC073",
     "Thêm lùi luỹ thừa trong eide_core/gateway.py trước khi đổi adapter",
     "—", "Đợt 1", "S", ""),
    ("G-079", "C. Điều phối (L3)", "AAD-33 §3.3",
     "Timeout riêng từng nút (build 120 s, flash 60 s) + toàn lượt 300 s; quá hạn thì lưu trạng "
     "thái, thả người dùng, nói thật",
     "MỘT PHẦN",
     "src/eide/daemon/rpc.py:937 `HAN_LUOT_GIAY = 300.0` + :965 thả người dùng và ghi "
     "run.blocked; KHÔNG có timeout theo nút",
     "TC020, UC19",
     "Thêm `timeout` vào hợp đồng từng capability và thi hành ở Router",
     "Đ5", "Đợt 3", "M", "DEV-205 đã làm phần hạn lượt."),
    ("G-080", "C. Điều phối (L3)", "AAD-33 §3.3",
     "Dừng khẩn: cờ cancel kiểm giữa các nút, truyền vào tiến trình con (SIGTERM → SIGKILL sau "
     "5 s); nút đang flash không bị giết giữa chừng",
     "MỘT PHẦN",
     "src/eide/daemon/rpc.py:1014 đường tắt dừng khẩn (DEV-155) + policy.emergency_stop; "
     "src/eide_core/sandbox.py:275 `_giet`; không có cờ cancel kiểm giữa các nút",
     "UC19, TC033",
     "Thêm cancel token vào RunContext; bảo vệ nút flash (chờ verify)",
     "—", "Đợt 1", "M", "Phần bảo vệ nút flash để Đợt 4."),
    ("G-081", "C. Điều phối (L3)", "AAD-33 §3.3",
     "Mỗi nút ghi undo (xoá hiện vật / git revert / không hoàn tác được); S6 báo hoàn tác được "
     "tới nút nào",
     "MỘT PHẦN",
     "src/eide_core/undo.py + src/eide/undo_handlers.py + undo.list/undo.apply (rpc.py); "
     "caps.json chưa khai `undo` theo từng năng lực",
     "TC(UC17)",
     "Khai `undo` trong hợp đồng; S6 in undo_upto", "Đ5", "Đợt 2", "S", ""),
    ("G-090", "C. Điều phối (L3)", "AAD-33 §3.4, AGD-32 §8",
     "Tám cổng v1.4: G-DATA, G-DESIGN, G-SCOPE, G-TOOL, G-QUAL, G-FILE, G-OPS, G-SAFE",
     "KHÁC",
     "docs/spec/policy/rules.yaml dùng G-SRC (6 luật), G-FACT (6), G-WL (3), G-TOOL (6), "
     "G-OPS (7), G1/G3/G4/G5 (17) và `*`",
     "TC022, TC035, TC068, TC069",
     "Lập bảng ánh xạ (xem sheet \"Cong phe duyet\"): G-SRC+G-FACT→G-DATA, G1/G3→G-DESIGN, "
     "G4/G5→?; bổ sung G-SCOPE, G-QUAL, G-FILE, G-SAFE; giữ mã luật cũ trong sổ cái",
     "—", "Đợt 1", "M",
     "Đề nghị DEV-221: chốt tên cổng ở MỘT chỗ. Đổi tên trong rules.yaml là thay đổi spec — "
     "cần chủ sản phẩm duyệt."),
    ("G-091", "C. Điều phối (L3)", "AAD-33 §3.4, AGD-32 §8",
     "Mức tự chủ mặc định A3",
     "KHÁC",
     "docs/spec/policy/defaults.yaml:8–10 `autonomy: A2` — chủ sản phẩm hạ từ A3 ngày 06/09/2026, "
     "có ghi lý do tại chỗ; src/eide/daemon/rpc.py:726 lấy \"A2\" làm mặc định",
     "—",
     "Giữ A2 và cập nhật AAD-33 §3.4/AGD-32 §8 (hoặc chủ sản phẩm chốt nâng lại A3). Không sửa "
     "im lặng",
     "—", "Đợt 1", "S", "Đề nghị DEV-222 — quyết định của người, không của mã."),
    ("G-092", "C. Điều phối (L3)", "AAD-33 §3.4",
     "Cửa sổ hoàn tác 30 giây cho hành động R2 được AUTO ở A3, hiện trên thẻ Run",
     "MỘT PHẦN",
     "src/eide_core/undo.py có hạn hoàn tác theo cấu hình cổng; chưa cố định 30 s và chưa hiện "
     "trên thẻ Run",
     "—", "Đặt 30 s trong policy + hiện đồng hồ trên thẻ Run", "—", "Đợt 2", "S", ""),
    ("G-093", "C. Điều phối (L3)", "AAD-33 §3.4",
     "Học ngưỡng: mỗi lần người bấm \"tin\"/\"luôn hỏi\" cho (capability, nguồn) ghi vào "
     "long-term memory và đổi quyết định lần sau, chỉ trong R0–R2",
     "MỘT PHẦN",
     "preferences (src/eide/caps/project.py) + `_ghi_nho` ở chat.py:295 nhớ câu trả lời của "
     "người; chưa có \"tin\" theo (capability, nguồn)",
     "—", "Thêm decision=trust vào gate.decide và bảng long-term", "—", "Đợt 2", "M", ""),
    ("G-100", "C. Điều phối (L3)", "AAD-33 §3.5",
     "Sổ cái ghi turn.start, s0.decision, s1.intent (kèm origin từng slot), s2.inventory, "
     "s3.gaps, s3.answer, s4.plan, gate.decision, node.*, artefact.write, human.*, undo, "
     "run.end, incident",
     "MỘT PHẦN",
     "docs/spec/api/ledger_events.json — 24 loại: intent/question/answer/report, gate.decision, "
     "gate.human, run.started/step/blocked/done, cap.run.*, model.call, context.bundle, "
     "store.write… THIẾU s0.decision, s2.inventory, s3.gaps, s4.plan, incident, turn.start; "
     "không có origin trong s1.intent",
     "Tiêu chí nghiệm thu Đợt 1 (brief §6)",
     "Thêm loại sự kiện + ledger.schema.json; mỗi pha ghi đúng một sự kiện",
     "Đ1, Đ6", "Đợt 1", "M", ""),
    ("G-101", "C. Điều phối (L3)", "AAD-33 §3.5, §7.2",
     "previous_session.summary sinh bằng MÃ từ sổ cái (ADR + gate.decision + s3.answer + giả "
     "định), mô hình chỉ viết lại thành câu",
     "MỘT PHẦN",
     "src/eide/caps/project.py:268 gắn previous_session từ M2 (session.sqlite); nội dung rỗng "
     "khi M2 rỗng — DEV-196 đã sửa việc GHI lượt, chưa sửa việc DỰNG tóm tắt từ sổ cái",
     "TC065, TC066, TC074",
     "Viết bộ dựng tóm tắt bằng mã đọc sổ cái; mô hình chỉ viết lại 5–8 câu",
     "—", "Đợt 2", "M", ""),
    ("G-102", "C. Điều phối (L3)", "AAD-33 §3.6",
     "S6 nhận {done[], skipped[{node, why}], assumptions[], gates[], undo_upto, cost} từ sổ cái; "
     "mọi giả định phải in ra",
     "MỘT PHẦN",
     "src/eide/caps/chat.py:335–377 `chat.report_back` có done/waiting/ra/undo/cost và câu sản "
     "phẩm; THIẾU skipped kèm lý do, assumptions, gates đã qua",
     "mọi ca",
     "Bổ sung ba trường; lấy assumptions từ DST.assumptions_active",
     "Đ6", "Đợt 1", "S", ""),

    # ── D. L4 — Năng lực
    ("G-110", "D. Năng lực (L4)", "AAD-33 §4",
     "Capability Protocol: contract + check(inv, params) → list[Gap] (xác định, 0 token) + "
     "run(ctx, params) + undo(ctx, result)",
     "MỘT PHẦN",
     "src/eide_core/registry.py `@capability(...)` + hàm `run` duy nhất; không có `check` xác "
     "định, undo nằm ngoài (src/eide/undo_handlers.py)",
     "TC009, TC013",
     "Thêm `check` cho các năng lực của Đợt 1 (archive/ingest/passport/req/arch/diagram)",
     "Đ5", "Đợt 1", "M", ""),
    ("G-111", "D. Năng lực (L4)", "AAD-33 §4",
     "Capability không gọi capability khác trực tiếp (để planner thấy toàn bộ đồ thị tiền đề)",
     "KHÁC",
     "src/eide/caps/code.py:1156 và :1527 gọi thẳng `constant_guard(...)`; src/eide/caps/chat.py:51 "
     "gọi `memory.compose`; nhiều chỗ khác import chéo trong caps/",
     "TC013",
     "Ghi DEVIATIONS cho các lời gọi nội bộ có lý do (constant_guard là phép kiểm bắt buộc, "
     "không phải một bước kế hoạch); phần còn lại chuyển qua Router",
     "—", "Đợt 2", "M", "Đề nghị DEV-223."),
    ("G-112", "D. Năng lực (L4)", "AAD-33 §4 (238 capability / 27 namespace)",
     "Số năng lực khớp danh mục v1.2",
     "KHÁC",
     "docs/spec/caps.json: 246 năng lực / 27 namespace; đã hiện thực 213 (`@capability` trong "
     "src/eide/caps/*.py); còn 33 chưa hiện thực",
     "—",
     "Chốt con số trong tài liệu (238 vs 246) khi cập nhật AAD-33; danh sách 33 năng lực thiếu "
     "ở sheet \"Nang luc moi-doi\"",
     "—", "Đợt 1", "S", "Đề nghị DEV-224 — tài liệu nói 238, spec nói 246."),

    # ── E. L5a — Nền tri thức
    ("G-120", "E. Tri thức (L5a)", "AAD-33 §5.1",
     "Registry chip trong SQLite (640 hạt giống từ SVD/ATDF): code, họ, ISA, gói, bí danh, URL "
     "nhà sản xuất",
     "KHÔNG",
     "docs/spec/data/schema.sql không có bảng chip/registry chip; chỉ có 3 manifest ISA + "
     "probes.yaml trong docs/spec/isa/",
     "TC002, TC015, TC018, TC046",
     "Dựng bảng chip + bộ nạp hạt giống từ SVD/ATDF; DX và passport.propose tra bảng này",
     "Đ3", "Đợt 2", "L", ""),
    ("G-121", "E. Tri thức (L5a)", "AAD-33 §5.1",
     "Kho tài liệu: tệp gốc + text theo trang + metadata (hash, version, tier, approved_by)",
     "MỘT PHẦN",
     "schema.sql:2 bảng `source`, :304 `rag_chunk` (locator theo trang); chưa có version/hash/"
     "approved_by đầy đủ theo luồng G-DATA",
     "TC011, TC042, TC044",
     "Bổ sung cột + `doc.approve` ghi approved_by", "Đ3", "Đợt 2", "M", ""),
    ("G-122", "E. Tri thức (L5a)", "AAD-33 §5.1",
     "Chỉ mục RAG lai: embedding cục bộ (bge-m3) + BM25, đơn vị = đoạn có doc_id + page",
     "MỘT PHẦN",
     "src/eide_core/rag.py:7–15 nói rõ: chỉ FTS5, cột `embedding` có nhưng để trống",
     "TC042, TC043",
     "Thêm embedding cục bộ + trộn điểm; giữ trích trang (đang đạt ở TC042)",
     "—", "Đợt 2", "L", "Phần trộn điểm BM25+embedding có thể để Đợt 3."),
    ("G-123", "E. Tri thức (L5a)", "AAD-33 §5.2",
     "Bản ghi Fact có key, value, unit, min/typ/max, condition, source{doc_id, version, page, "
     "quote, bbox}, tier, origin, approved_by/at, supersedes/superseded_by, errata",
     "MỘT PHẦN",
     "docs/spec/data/json/fact.json: id/subject/predicate/value/unit/source_id/method/tier/"
     "confidence/status/layer. THIẾU min/typ/max, condition, page/quote/bbox trực tiếp, errata",
     "TC008, TC042, TC075",
     "Nâng fact.json (hoặc ghi DEVIATIONS nếu giữ mô hình predicate/subject hiện có) + bảng "
     "ánh xạ key chuẩn (vdd.max, flash.size, pin.<n>.af[])",
     "—", "Đợt 2", "M", "Đề nghị DEV-225: hai mô hình Fact khác nhau (AAD-33 key ↔ DDD-14 predicate)."),
    ("G-124", "E. Tri thức (L5a)", "AAD-33 §5.2, AGD-32 §2 N2",
     "Ba tầng VÀNG/BẠC/ĐỒNG với điều kiện chuyển tầng (Vàng chỉ khi người xác nhận dòng, hoặc "
     "AUTO theo trusted_sources + độ tin cậy ≥ 0,95)",
     "MỘT PHẦN",
     "fact.json: tier ∈ {gold, silver, bronze} + status ∈ {normalized, reviewed, verified, …}; "
     "src/eide/caps/code.py:2025 chỉ cho fact `reviewed`/`verified` vào mã sinh. Không có cổng "
     "thi hành \"Vàng chỉ khi người xác nhận\"",
     "TC013, TC021, TC031",
     "Nối G-DATA vào phép chuyển silver→gold; đếm Bạc còn lại trên thanh trạng thái",
     "Đ3", "Đợt 2", "M", ""),
    ("G-125", "E. Tri thức (L5a)", "AAD-33 §5.3",
     "Đường ống ingest: bóc tách đệ quy ≤ 3 cấp / 500 MB; PDF theo trang; bảng → camelot/"
     "pdfplumber; OCR có điểm tin cậy từng ô; scan mờ → tier tối đa BẠC + bắt buộc rà từng dòng",
     "MỘT PHẦN",
     "src/eide/caps/archive.py `GIOI_HAN` (depth) + ingest.index_text; src/eide/caps/extract.py "
     "(2907 dòng): extract.pdf_layout/pdf_electrical/pdf_pinout/ocr…; chưa có luật \"scan mờ ≤ "
     "BẠC bắt buộc rà\"",
     "TC044",
     "Thêm luật tier theo điểm OCR + hàng đợi rà soát", "—", "Đợt 2", "M", ""),
    ("G-126", "E. Tri thức (L5a)", "AAD-33 §5.3 bước 5",
     "Hai phiên bản cùng tài liệu → chỉ mục riêng + bảng diff theo key",
     "MỘT PHẦN",
     "view.rag_compare + passport.diff có; chưa có fact.diff theo key và doc.select_version",
     "TC011",
     "Thêm fact.diff + doc.select_version; hộ chiếu ghi bản đã dùng", "—", "Đợt 2", "M", ""),
    ("G-127", "E. Tri thức (L5a)", "AAD-33 §5.4",
     "fact.compare(a, b, rule) → {verdict, severity, evidence[2 trích dẫn], unverified}; vế ĐỒNG "
     "→ unverified, severity hạ thành info, planner không dùng làm điều kiện tự động",
     "KHÔNG",
     "Không có namespace fact.*; board.check_pins và arch.memory_budget so sánh theo cách riêng",
     "TC013, TC021, TC031, TC038, TC040, TC045",
     "Viết fact.compare + 8 luật so sánh của AGD-32 §4.3", "—", "Đợt 2", "L", ""),
    ("G-128", "E. Tri thức (L5a)", "AAD-33 §5.4",
     "Constant-guard: sau mỗi nút sinh mã, quét hằng số điện/thời gian (kèm đơn vị hoặc macro "
     "F_CPU/BAUD/I2C_SPEED) và đối chiếu kho Fact; không truy vết được → nút không sạch",
     "CÓ",
     "src/eide/caps/code.py:209 `code.constant_guard`; :1076 vi phạm là E5003 (không chỉ cảnh "
     "báo); chạy lại ở code.merge (:1527)",
     "TC075 (đang đạt), TC013, TC021",
     "Giữ; mở rộng danh sách macro và nối với fact.query khi có fact.*",
     "—", "Đợt 2", "S", "Đóng góp \"LLM-Is-Not-Ground-Truth\" — hồi quy phải giữ."),

    # ── F. L5b — LLM gateway
    ("G-130", "F. Gateway (L5b)", "AAD-33 §6.1",
     "Sáu vai trò: parse, clarify, gen, review, report, embed — mỗi vai trò có yêu cầu, mô hình "
     "mặc định và NGÂN SÁCH (token vào/ra, giây)",
     "KHÁC",
     "docs/spec/models.yaml:23–35 có 9 vai trò khác tên: intent, librarian, cartographer, "
     "planner, coder, reviewer, debugger, architect, writer; không có `embed`; không khai ngân "
     "sách token vào/giây (chỉ max_output)",
     "TC073",
     "Lập bảng ánh xạ vai trò (parse↔intent, clarify↔?, gen↔coder/architect, review↔reviewer, "
     "report↔writer) + thêm ngân sách; ghi DEVIATIONS nếu giữ tên của SDD-04 §6",
     "—", "Đợt 1", "M", "Đề nghị DEV-226 — không có vai trò `clarify` nào để S3 dùng."),
    ("G-131", "F. Gateway (L5b)", "AAD-33 §6.2",
     "Prompt lắp từ 8 khối có thứ tự và ngân sách riêng; khối Fact rỗng phải ghi rõ \"KHÔNG CÓ "
     "DỮ KIỆN — không được bịa\"; nén theo bậc thang thay vì cắt cụt im lặng",
     "MỘT PHẦN",
     "src/eide/caps/memory.py:715 `memory.compose` dựng C0–C7 theo CXD-10 + "
     "docs/spec/context/budgets.json; không có khối Fact nói-thẳng-khi-rỗng, không in \"đã đọc/"
     "chưa đọc\"",
     "TC028, TC075",
     "Ánh xạ C0–C7 ↔ 8 khối của AAD-33 §6.2; thêm khối Fact rỗng và danh sách tệp đã đọc",
     "—", "Đợt 2", "M", ""),
    ("G-132", "F. Gateway (L5b)", "AAD-33 §6.3",
     "Bật structured output của nhà cung cấp; nếu không thì kiểm lược đồ + sửa JSON (1 lần) + "
     "gọi lại (1 lần) rồi báo E5xxx",
     "MỘT PHẦN",
     "src/eide_core/gateway.py truyền schema theo từng adapter (gemini :148, claude :195) và "
     "kiểm lược đồ; chưa có vòng sửa-JSON/gọi-lại có đếm",
     "TC073",
     "Thêm vòng sửa + gọi lại có đếm và mã lỗi đúng", "—", "Đợt 1", "S", ""),
    ("G-133", "F. Gateway (L5b)", "AAD-33 §6.3",
     "Cache kết quả parse/clarify theo hash(câu chuẩn hoá + inventory hash) trong 10 phút — để "
     "chạy lặp kịch bản rẻ và tất định hơn",
     "KHÔNG", "—", "Tiêu chí tất định (brief §6)",
     "Thêm cache có TTL trong gateway; khoá gồm inventory hash (cần S2 trước)",
     "Đ5", "Đợt 1", "M", ""),
    ("G-134", "F. Gateway (L5b)", "AAD-33 §6.3",
     "Nhiệt độ: parse/clarify/report = 0; gen = 0,2; review = 0; seed cố định khi nhà cung cấp "
     "hỗ trợ",
     "MỘT PHẦN",
     "models.yaml chỉ khai temperature cho `intent` và `librarian` (= 0); "
     "src/eide_core/gateway.py:73 mặc định 0.0; KHÔNG có seed",
     "TC004, TC043",
     "Khai temperature cho mọi vai trò; thêm seed vào adapter nào hỗ trợ",
     "Đ6", "Đợt 1", "S", ""),
    ("G-135", "F. Gateway (L5b)", "AAD-33 §6.3",
     "Kế toán mỗi lời gọi {role, model, tokens_in/out, seconds, usd} vào sổ cái; S6 tổng hợp",
     "CÓ",
     "ledger `model.call` (docs/spec/api/ledger_events.json) + tổng chi phí ở "
     "src/eide/caps/chat.py:357",
     "mọi ca", "Giữ; thêm `seconds` nếu còn thiếu", "—", "—", "S", ""),

    # ── G. L5c — Bộ nhớ
    ("G-140", "G. Bộ nhớ (L5c)", "AAD-33 §7.1",
     "Bốn tầng: Working (lượt), Session (phiên), Project store (vĩnh viễn, có git), Long-term "
     "(xuyên dự án)",
     "KHÁC",
     "src/eide_core/memory.py: M1 WorkingMemory (:48, trong run.working), M2 SessionMemory (:100, "
     "session.sqlite); store.sqlite + git (eide_core/git.py) là project store; preferences là "
     "long-term. MEM-11 chia M1–M6 chứ không 4 tầng",
     "TC065, TC066",
     "Bảng ánh xạ M1–M6 ↔ 4 tầng trong DEVIATIONS; không đổi mã", "—", "Đợt 1", "S",
     "Đề nghị DEV-227."),
    ("G-141", "G. Bộ nhớ (L5c)", "AAD-33 §7.2",
     "Khôi phục là ĐỌC: mở dự án → S2 dựng Inventory → dựng tóm tắt quyết định bằng mã → mô hình "
     "viết lại 5–8 câu; câu hỏi về quyết định cũ đi đường fact/ADR query",
     "MỘT PHẦN",
     "src/eide/daemon/rpc.py:1398 `chat_resume`; src/eide/caps/project.py:268 previous_session; "
     "không có Inventory, không có đường ADR query",
     "TC065, TC066, TC074",
     "Làm sau khi có S2 (G-070)", "—", "Đợt 2", "M", ""),
    ("G-142", "G. Bộ nhớ (L5c)", "AAD-33 §7.3",
     "Nén ngữ cảnh 4 bậc; bậc 2 chọn tệp theo đồ thị phụ thuộc + mention và IN danh sách \"đã "
     "đọc / chưa đọc\"",
     "MỘT PHẦN",
     "src/eide/caps/memory.py:832 `memory.compress` + budgets.json; chưa chọn theo đồ thị phụ "
     "thuộc, chưa in danh sách đã đọc",
     "TC028",
     "Thêm bậc 2 và câu \"phạm vi đã đọc\" vào báo cáo", "—", "Đợt 2", "M", ""),

    # ── H. L6 — Thực thi
    ("G-150", "H. Thực thi (L6)", "AAD-33 §8.1, AGD-32 §8",
     "Mọi lệnh chạy qua sandbox: thư mục cho phép, không mạng mặc định (bật theo nút khai "
     "network=true), giới hạn CPU/RAM/thời gian, môi trường sạch",
     "CÓ",
     "src/eide_core/sandbox.py:39 `MUC_CACH_LY = (sandbox-exec, bwrap, rlimit)`, :171–183 "
     "(macOS sandbox-exec / Linux bwrap), :196 `_moi_truong`, :225 `_dat_gioi_han`, :283 "
     "`_kiem_allowed_dirs`",
     "TC070",
     "Giữ; thêm test \"không đường chạy lệnh nào vòng qua sandbox\" (quét subprocess trong src/)",
     "—", "Đợt 1", "S", ""),
    ("G-151", "H. Thực thi (L6)", "AAD-33 §8.1, AGD-32 §8",
     "Script người đưa vào được ingest.classify nhận là \"script\", quét tĩnh (lệnh phá hoại, "
     "đọc khoá riêng) → ASK kèm trích dòng nguy hiểm; chạy vẫn trong sandbox",
     "KHÔNG",
     "src/eide/caps/archive.py:160–199 `_nhan_dang` không có loại `script`/`log`/`capture`; "
     "không có bộ quét tĩnh. TC070 \"an toàn\" chỉ vì .sh bị nhận nhầm là tệp nén",
     "TC070",
     "Thêm loại script/log/capture + bộ quét tĩnh + thẻ ASK", "Đ2", "Đợt 1", "M",
     "An toàn phải do THIẾT KẾ: ca này đang đạt nhờ tai nạn (brief §6)."),
    ("G-152", "H. Thực thi (L6)", "AAD-33 §8.2",
     "Dò 12 công cụ (arm/avr/riscv/xtensa gcc, cmake, ninja, make, openocd, pyocd, esptool, "
     "qemu, renode) + --version → toolchain[] trong Inventory",
     "MỘT PHẦN",
     "src/eide/caps/env.py env.detect/env.check + src/eide_core/tools.py `which`; kết quả không "
     "vào Inventory (chưa có Inventory)",
     "TC015–TC018",
     "Đưa kết quả dò vào Inventory khi có G-070", "Đ5", "Đợt 3", "M", ""),
    ("G-153", "H. Thực thi (L6)", "AAD-33 §8.2, AGD-32 Đ3",
     "Manifest ISA đủ họ: armv6-m, armv7-m, armv7e-m, armv8-m, avr8, rv32imac, xtensa-lx6/lx7",
     "KHÔNG",
     "docs/spec/isa/ chỉ có armv7e-m.yaml, avr8.yaml, rv32imac.yaml (+ probes.yaml). STM32F103 "
     "là armv7-m → env.check trả E2000 \"chưa có manifest\"",
     "TC018, TC015",
     "Thêm docs/spec/isa/armv7-m.yaml (tối thiểu), rồi armv6-m/armv8-m/xtensa-lx6/lx7; "
     "env.check:67 đã nói thẳng nên chỉ cần dữ liệu",
     "Đ3", "Đợt 1", "S",
     "Việc rẻ nhất trong Đợt 1 — mở khoá TC018 mà không sửa mã."),
    ("G-154", "H. Thực thi (L6)", "AAD-33 §8.3",
     "code.scaffold sinh dự án từ Platform Pack: startup, linker script từ Fact flash.size/"
     "ram.size (KHÔNG hard-code), clock/pinmux từ pinout đã duyệt; gcc -fdiagnostics-format=json; "
     "map file → so với Fact",
     "MỘT PHẦN",
     "src/eide/caps/code.py: code.build, code.size, code.static, code.generate_module; chưa sinh "
     "linker/startup từ Fact; chưa đọc diagnostics JSON",
     "TC015–TC021",
     "Đợt 3", "—", "Đợt 3", "L", ""),
    ("G-155", "H. Thực thi (L6)", "AAD-33 §8.4",
     "Trừu tượng SimBackend { supports(chip, peripherals) → {ok[], missing[]}; run(elf, scenario, "
     "timeout) → {log, vcd, exit_reason} } cho QEMU/Renode/simavr",
     "MỘT PHẦN",
     "src/eide/caps/sim.py:122 khớp họ chip theo src/eide/caps/data/renode_models.yaml; "
     "sim.build_platform/sim.run/sim.scenario/sim.mock_peripheral có; chưa có giao diện "
     "supports()/missing[] và chưa có backend chạy thật",
     "TC019, TC020, TC059, TC060, TC076",
     "Đợt 3", "—", "Đợt 3", "L",
     "Bẫy nền tảng đã biết: trên Mac chỉ qemu-system-avr chạy được (xem docs/DEVIATIONS.md)."),
    ("G-156", "H. Thực thi (L6)", "AAD-33 §8.4",
     "sim.define_criteria sinh criteria.yaml {assert: [uart_contains, gpio_toggles, "
     "timing_within, no_hardfault], timeout_s} TRƯỚC khi chạy; đổi sau → G-QUAL",
     "KHÔNG",
     "sim.* hiện có: build_platform, mock_peripheral, model_plant, run, scenario, sweep — không "
     "có define_criteria; không có sim.criteria.schema.json",
     "TC019, TC022, TC076",
     "Đợt 3 (nhưng cổng G-QUAL của S0 đang chặn hạ chuẩn — giữ hành vi đó)",
     "—", "Đợt 3", "M", ""),
    ("G-157", "H. Thực thi (L6)", "AAD-33 §8.4",
     "Bằng chứng mô phỏng: log có dấu thời gian, VCD, exit_reason ∈ {criteria_met, "
     "criteria_failed, timeout, crash}; log rỗng → \"không kết luận được\"",
     "MỘT PHẦN",
     "sim.run trả log; TC076 đang ĐẠT (không tuyên đạt từ log rỗng)",
     "TC076 (đang đạt), TC019",
     "Giữ hành vi; thêm VCD + exit_reason", "—", "Đợt 3", "M", ""),
    ("G-158", "H. Thực thi (L6)", "AAD-33 §8.5",
     "target.detect đọc ID chip (DBGMCU_IDCODE/CHIPID/signature) → đối chiếu hộ chiếu; không "
     "khớp → DỪNG trước khi nạp; không thấy → danh sách kiểm nguồn/cáp/driver/BOOT/NRST",
     "MỘT PHẦN",
     "Chỉ `target.detect` được hiện thực trong 9 năng lực target.* của caps.json; "
     "discover.chip_id chưa hiện thực",
     "TC032, TC034",
     "Đợt 4 (cần board thật — quyết định 08/09/2026 để khối phần cứng cuối)",
     "—", "Đợt 4", "L", ""),
    ("G-159", "H. Thực thi (L6)", "AAD-33 §8.5",
     "target.flash: thẻ tóm tắt \"nạp gì (hash, kích thước) vào đâu (chip, địa chỉ)\" → xác nhận "
     "→ nạp → verify đọc lại; rút cáp giữa chừng → báo trạng thái không nhất quán + hướng khôi phục",
     "KHÔNG",
     "target.flash/verify/log/debug/erase_fuse/reset/serial/probe_read/probe_write đều CHƯA hiện "
     "thực (33 năng lực thiếu — sheet \"Nang luc moi-doi\")",
     "TC029–TC035",
     "Đợt 4; giữ hành vi \"nói thẳng là chưa làm được\" đang giúp TC035 đạt",
     "—", "Đợt 4", "L", ""),
    ("G-160", "H. Thực thi (L6)", "AAD-33 §8.6, brief §5",
     "search.web qua SearXNG cục bộ, truy vấn dựng bằng mã từ chips[], xếp hạng ưu tiên tên miền "
     "nhà sản xuất, tải chỉ sau G-DATA; mất mạng → E3xxx lỗi MẠNG (không phải lỗi tệp), lưu "
     "trạng thái, tiếp tục được",
     "MỘT PHẦN",
     "src/eide/caps/search.py:589 SearXNG là nguồn mặc định + :649 hướng dẫn; Makefile:156 "
     "`make searxng` đã có (Docker). Chưa dựng thật; truy vấn không dựng từ chips[]; TC072 vẫn "
     "báo lỗi TỆP cho một việc TÌM MẠNG",
     "TC072, TC010, TC046",
     "Dựng SearXNG; phân loại lỗi mạng thành E3xxx + incident{resumable:true}; xếp hạng theo "
     "trusted_sources",
     "Đ1, Đ3", "Đợt 1", "M", ""),

    # ── I. Giao thức giao diện
    ("G-170", "I. Giao thức (UAP)", "UIP-34 §1.2 I1",
     "Một cửa vào: lõi chỉ nhận thao tác của người qua console.act mang HumanAct; RPC khác là "
     "máy–máy và bị từ chối E_PROTO_CHANNEL nếu mang hành động",
     "KHÔNG",
     "src/eide/daemon/rpc.py:341–357 đăng ký ~40 phương thức nhận hành động của người: chat.send, "
     "chat.answer, gate.decide, caps.invoke, undo.apply, autonomy.set, diagram.save, "
     "code.human_save…; docs/spec/api/openrpc.json khai 65 phương thức",
     "UP01",
     "Thêm `console.act` làm cửa vào, giữ phương thức cũ làm lớp tương thích (ghi DEVIATIONS) và "
     "định tuyến tất cả về một hàm xử lý HumanAct",
     "—", "Đợt 2", "L",
     "Brief §10: chỉ sửa CẦU giao thức, không đổi giao diện Swift."),
    ("G-171", "I. Giao thức (UAP)", "UIP-34 §1.2 I2",
     "Một dòng hội thoại: mỗi HumanAct sinh đúng một mục \"[Bạn] …\"; transcript là hình chiếu "
     "của sổ cái (phát lại sổ cái tái tạo đúng transcript)",
     "MỘT PHẦN",
     "src/eide/daemon/rpc.py:1035 `_ghi_luot(\"human\", …)` (DEV-196) + chat.history; chỉ câu gõ "
     "vào M2, các thao tác khác (bấm Duyệt, xác nhận Fact) không sinh mục transcript",
     "UP02, UP03",
     "Mọi HumanAct ghi sổ cái TRƯỚC khi xử lý (write-ahead) và sinh mục transcript",
     "—", "Đợt 2", "M", ""),
    ("G-172", "I. Giao thức (UAP)", "UIP-34 §1.2 I3",
     "Giao diện không quyết: chỉ render SurfaceModel + Card do lõi gửi; chạy lõi không giao diện "
     "(--kich-ban) cho cùng hành vi",
     "MỘT PHẦN",
     "apps/eide/Sources/EideApp/KichBan.swift có chế độ kịch bản; nhưng 28 màn "
     "(docs/spec/ui/screens.json) tự dựng nội dung từ nhiều lời gọi RPC, không nhận SurfaceModel",
     "UP04, UP05",
     "Đợt 2: đưa Card từ lõi xuống trước (clarify/gate/plan/report), SurfaceModel sau",
     "—", "Đợt 2", "L", ""),
    ("G-173", "I. Giao thức (UAP)", "UIP-34 §1.2 I5, §7.2–7.3",
     "Envelope {v, id, seq, ts, session, run_id, kind, payload}; hai bộ đếm seq theo chiều; "
     "idempotent theo id; mất kết nối → resume(last_seq_seen) phát lại phần thiếu",
     "KHÔNG",
     "Không có Envelope/seq/session trong daemon; `chat.resume` (rpc.py:1398) tiếp tục theo "
     "run_id, không theo seq; không có tập id đã xử lý",
     "UP06, UP07, UP11",
     "Thêm phong bì + seq + bảng id đã xử lý; resume phát lại UICommand",
     "—", "Đợt 2", "L", ""),
    ("G-174", "I. Giao thức (UAP)", "UIP-34 §1.2 I6, §3.1",
     "Quyết định cổng chỉ nhận từ HumanAct kind=decide có gate_id khớp thẻ đang chờ; gõ \"có\" "
     "bằng text → lõi nhắc bấm Duyệt (không thực hiện)",
     "MỘT PHẦN",
     "src/eide/daemon/rpc.py:1532 `gate_decide` nhận quyết định theo hàng đợi; không có phép "
     "chặn tường minh cho câu \"ok làm đi\" khi thẻ R4 đang chờ",
     "UP08, UP09, TC035, TC068",
     "Thêm luật: có thẻ gate chờ → câu text không được duyệt nó; E_GATE_STALE khi gate_id cũ",
     "—", "Đợt 1", "M",
     "Rẻ và canh trực tiếp một bất biến an toàn — nên làm trong Đợt 1."),
    ("G-175", "I. Giao thức (UAP)", "UIP-34 §3",
     "11 loại HumanAct: say, choose, decide, confirm, edit, upload, stop, undo, resume, attend, set",
     "KHÔNG",
     "Ánh xạ rải rác: chat.send≈say, chat.answer≈choose, gate.decide≈decide, code.human_save≈edit, "
     "undo.apply≈undo, stop≈stop, chat.resume≈resume; KHÔNG có confirm (Fact), upload, attend, set "
     "dưới dạng một thông điệp chung",
     "UP01–UP12",
     "Định nghĩa HumanAct + bảng ánh xạ từ phương thức cũ", "—", "Đợt 2", "M", ""),
    ("G-176", "I. Giao thức (UAP)", "UIP-34 §4",
     "14 UICommand: console.post/stream, card.resolve/expire, surface.set/patch/append/focus/"
     "highlight/lock/unlock, run.update, notice, ui.set",
     "KHÔNG",
     "docs/spec/api/openrpc.json có 20 sự kiện event.* (event.chat.restated, event.chat.question, "
     "event.chat.report, event.run.progress, event.gate.opened…) — hình dạng khác hẳn",
     "UP10, UP11, UP12",
     "Ánh xạ event.* → UICommand; giữ event.* làm lớp tương thích", "—", "Đợt 2", "L", ""),
    ("G-177", "I. Giao thức (UAP)", "UIP-34 §5, §8",
     "SurfaceModel cho 9 bề mặt (console, req, docs, ckm, design, tools, code, sim, target, "
     "ledger) với 12 loại khối",
     "KHÁC",
     "docs/spec/ui/screens.json khai 28 màn (Chat, Main, ReviewQueue, Ingest, Passport, Board, "
     "Graph→RagAsk, NhatKy, XungDot, LamRo, ReqArch, DiagramView, Doc, PlanDiff, Code, Sim, "
     "Discovery, LogAssist, Debug, ToolForge, Bench, Registry, Models, Env, FlowMap, DiffMerge, "
     "ChinhSach, Main shell)",
     "UP10",
     "Lập bảng 28 màn → 9 bề mặt; quyết định: gộp màn hay mở rộng danh sách bề mặt trong UIP-34",
     "—", "Đợt 2", "L", "Đề nghị DEV-228 — mâu thuẫn AGD-32 §7 (9 tab) ↔ UXD-13 v2.0 (28 màn)."),
    ("G-178", "I. Giao thức (UAP)", "UIP-34 §6",
     "Card 6 loại (clarify, proposal, plan, gate, report, criteria) với awaits/expires_at/items/"
     "consequences/actions; thẻ gate đúng 1 mục, không default",
     "MỘT PHẦN",
     "Thẻ do giao diện dựng: apps/eide/Sources/EideGiaoDien/EideTheYHieu.swift, EideTheRun.swift, "
     "EideTheHoi.swift, EideTheXungDot.swift, EideTheKetQua.swift; lõi trả dữ liệu rời "
     "(event.chat.restated, cho_nguoi…) chứ không trả Card",
     "UP08, TC004, TC035",
     "Định nghĩa card.schema.json và cho lõi phát Card; giao diện chỉ render",
     "Đ6", "Đợt 2", "L", ""),
    ("G-179", "I. Giao thức (UAP)", "UIP-34 §11",
     "12 ca tuân thủ UP01–UP12 + bộ lint giao thức chạy trong CI cho cả hai phía",
     "KHÔNG",
     "tests/ (81 tệp) không có ca nào về giao thức UAP", "UP01–UP12",
     "Viết headless UI (Python) nói UAP với lõi thật + 12 ca; thêm vào `make check`",
     "—", "Đợt 2", "L", ""),

    # ── J. Lược đồ
    ("G-190", "J. Lược đồ", "AAD-33 §10, brief §6",
     "14 lược đồ JSON trong schemas/ (utterance, dx, gate0, channels, intent v2, inventory, "
     "clarify, plan, capability, fact, passport, ledger, card, sim.criteria/scenario), kiểm lúc "
     "nạp và trong CI",
     "MỘT PHẦN",
     "Không có thư mục schemas/. Tương đương hiện có: docs/spec/dialog/intent.schema.json (v1), "
     "docs/spec/data/json/{fact,passport,capability,intent,run,session,clarification}.json, "
     "docs/spec/policy/autonomy.schema.json. Kiểm bằng tests/test_specs_consistency.py",
     "Tiêu chí nghiệm thu Đợt 1",
     "Xem sheet \"Luoc do JSON\": bổ sung 9 lược đồ còn thiếu, đặt cạnh spec hiện có "
     "(docs/spec/...) thay vì schemas/ để không có hai nơi — ghi DEVIATIONS về vị trí",
     "Đ1, Đ5, Đ6", "Đợt 1", "L", "Đề nghị DEV-229 — vị trí lược đồ: schemas/ ↔ docs/spec/."),

    # ── K. Kiểm thử & nghiệm thu
    ("G-200", "K. Kiểm thử", "AGD-32 §9.3, brief §5",
     "Mỗi ca chạy 5 lần, ghi tỉ lệ đạt + thời gian + token + số lần hỏi lại; chấm theo lần chạy "
     "đầy đủ, không theo lần đẹp nhất",
     "MỘT PHẦN",
     "scripts/kiem_usecase.py:204 `--lap` (mặc định 1), :247–270 chạy lặp và ghi `lap[]` + "
     "`qua_sang`; chưa ghi token/thời gian/số lần hỏi theo từng lần",
     "toàn bộ 76 TC",
     "Chạy `--lap 5`; bổ sung cột token/giây/số-lần-hỏi vào báo cáo và vào xlsx",
     "—", "Đợt 1", "M", ""),
    ("G-201", "K. Kiểm thử", "AAD-33 §12, brief §6",
     "Tất định: cùng câu + cùng store → cùng DX, S0, S2, S4 (100 %); S1/S3 ≥ 90 % cùng "
     "intent/gaps qua 5 lần",
     "KHÔNG",
     "Ba trong bốn pha xác định (DX, S2, S4) chưa tồn tại nên không đo được",
     "TC001, TC004, TC043",
     "Sau Đ1/Đ5: thêm phép đo tất định vào bộ chạy kịch bản", "Đ1, Đ5", "Đợt 1", "M", ""),
    ("G-202", "K. Kiểm thử", "brief §6",
     "Mỗi ca ĐẠT phải chỉ ra cơ chế thiết kế nào bảo vệ nó (không có ca \"đạt nhờ tai nạn\")",
     "MỘT PHẦN",
     "Cột \"Ghi chú\" của sheet Test case đã có nội dung này cho phần lớn ca; TC070 là ví dụ "
     "đạt-nhờ-tai-nạn còn lại",
     "TC070 và 16 ca đang đạt",
     "Sau mỗi Đ: ghi cơ chế bảo vệ vào cột Ghi chú; TC070 phải đạt nhờ Đ2 + quét script",
     "Đ2", "Đợt 1", "S", ""),
    ("G-203", "K. Kiểm thử", "brief §9.3",
     "Unit test cho từng phần xác định: DX, ingest.classify, planner, S0 YAML",
     "MỘT PHẦN",
     "tests/ có 81 tệp, trong đó tests/test_thao_tac_nguy_hiem.py (639 dòng) canh S0 và "
     "tests/test_archive_m0.py canh classify; chưa có test DX/planner/S0-YAML",
     "—",
     "Mỗi Đ kèm một tệp test mới: test_dx.py, test_classify_v14.py, test_planner_tien_de.py, "
     "test_s0_yaml.py",
     "Đ1–Đ6", "Đợt 1", "M", ""),
    ("G-204", "K. Kiểm thử", "brief §8",
     "Nhật ký sai lệch ghi vào docs/md/EIDE-DEV-LOG.md theo dãy DEV-2xx",
     "KHÁC",
     "Kho dùng docs/DEVIATIONS.md (đã tới DEV-219) + lệnh /sai-khac (scripts/new_deviation.py) "
     "theo CLAUDE.md",
     "—",
     "Tiếp tục dùng docs/DEVIATIONS.md từ DEV-220; nếu chủ sản phẩm cần EIDE-DEV-LOG.md thì "
     "SINH nó từ DEVIATIONS.md, không giữ hai nơi",
     "—", "Đợt 1", "S", "Đề nghị DEV-220 ghi chính việc này."),
    ("G-205", "K. Kiểm thử", "brief §1.4",
     "Cập nhật cột vàng của test/Usecase_Test_Agent_Ky_Su_Nhung.xlsx (Trạng thái, Kết quả thực "
     "tế, Người test, Ngày test, Ghi chú) sau mỗi Đ",
     "MỘT PHẦN",
     "scripts/cap_nhat_usecase_xlsx.py đã có (ghi kết quả vào xlsx)",
     "toàn bộ",
     "Trỏ script vào bản xlsx trong docs/v1.4/goi/test/ hoặc bản kho; chốt MỘT bản làm gốc",
     "—", "Đợt 1", "S", "Hiện có hai bản xlsx (docs/ và docs/v1.4/goi/test/) — dễ lệch."),
]

DAU_GAP = ["ID", "Nhóm", "Tài liệu §", "Yêu cầu thiết kế (1 câu)", "Trạng thái",
           "Bằng chứng trong mã (tệp:dòng)", "Ca đo liên quan", "Hành động đề xuất",
           "Sửa đổi", "Đợt", "Công", "Ghi chú / DEV đề nghị", "Đã làm 24/09/2026"]
RONG_GAP = [8, 18, 16, 52, 12, 58, 24, 52, 9, 8, 6, 44, 62]

#: Mục đã hiện thực trong Đợt 1 — `{ID: (trạng thái mới, đã làm gì)}`.
#:
#: Cột này là chỗ trả lời câu hỏi "ai canh mục này" của brief §6: mỗi mục XONG phải chỉ ra được
#: bài kiểm nào giữ nó, không chỉ tệp nào hiện thực nó.
XONG: dict[str, tuple[str, str]] = {
    "G-010": ("XONG Đ1", "src/eide/nlu/normalize.py (mới) — Utterance{raw, normalized, "
              "no_accent, lang, clauses[]} + docs/spec/dialog/utterance.schema.json. Canh bởi "
              "tests/test_dx.py::test_nfc_va_dau_kieu_cu, ::test_tach_menh_de_khong_cat_duong_dan"),
    "G-011": ("XONG Đ1", "src/eide/nlu/dx.py::_trich_duong_dan — 5 nguồn (đính kèm, tuyệt đối, "
              "nháy, tương đối, tên tệp có đuôi biết), kiểm exists, chạy TRƯỚC parse_intent tại "
              "rpc.py::_chat_send. Canh bởi ::test_hai_duong_dan_trong_mot_cau, "
              "::test_duong_dan_khong_ton_tai_duoc_GIU_voi_exists_false"),
    "G-012": ("XONG Đ1", "src/eide/nlu/dx.py::_trich_chip + docs/spec/dialog/dx_chips.yaml "
              "(12 họ + 2 bí danh của AAD-33 §2.2) + src/eide_core/isa.py (một chỗ duy nhất đọc "
              "family_patterns, [DEV-230]). in_registry vẫn false — registry chip là Đợt 2. "
              "Canh bởi ::test_bi_danh_thanh_ma_chip, ::test_isa_tu_manifest_va_null_khi_thieu"),
    "G-013": ("XONG Đ1", "src/eide/nlu/dx.py::DON_VI (37 đơn vị → SI) + _trich_so; dải "
              "\"3,0–4,2 V\" thành một mục min/max. Canh bởi ::test_so_co_don_vi_quy_ve_si, "
              "::test_dai_gia_tri_thanh_mot_muc, ::test_dung_luong_pin_ve_coulomb ([DEV-233])"),
    "G-014": ("XONG Đ1", "src/eide/nlu/dx.py::_trich_url — nhãn manufacturer đọc từ "
              "trusted_sources của docs/spec/policy/defaults.yaml, không chép tay. Canh bởi "
              "::test_url_va_nhan_nha_san_xuat"),
    "G-015": ("XONG Đ1", "src/eide/nlu/dx.py::_trich_ma (REQ/ADR/MOD/UC/TC/run-*/r_<hex>) + "
              "giai_ma() tra store cho mã run. Canh bởi ::test_ma_hien_vat"),
    "G-016": ("XONG Đ1", "chuyển sang src/eide/nlu/backref.py ([DEV-230]); rpc.py nhập lại nên "
              "tests/test_tro_nguoc.py và tests/test_daemon.py chạy nguyên. Canh thêm bởi "
              "::test_back_ref"),
    "G-017": ("XONG Đ1", "src/eide/nlu/dx.py::_trich_nhay — nháy kép/đơn/backtick, cả nháy cong. "
              "Canh bởi ::test_chuoi_trong_nhay_la_du_lieu"),
    "G-018": ("XONG Đ1", "src/eide/nlu/merge.py — UU_TIEN (dx>user>model>default), NGUON_TIN, "
              "chay_duoc(), duong_chay_duoc(), sinh path/chip số ít CHỈ từ nguồn tin; "
              "rpc.py::_chat_send hợp nhất rồi ghi sổ (pha s1.merge) kèm origin từng slot. "
              "Bảng cạnh bên thay vì bọc {value,origin} — [DEV-231]. Canh bởi "
              "::test_slot_mo_hinh_khong_duoc_dung_de_chay, ::test_dx_thang_mo_hinh, "
              "::test_duong_song_chay_dx_truoc_mo_hinh"),
    "G-041": ("XONG Đ1", "docs/ho-so/nguon/dps.js::INTENT_SCHEMA → sinh lại "
              "docs/spec/dialog/intent.schema.json (node scripts/gen_spec_tu_nguon.js); "
              "`make check-gen` xanh. Canh bởi ::test_luoc_do_intent_v2_khong_con_slot_chuoi_don, "
              "::test_schema_cho_mo_hinh_bo_origins"),
}


def sheet_gap(wb) -> None:
    ws = wb.create_sheet("Ra soat (GAP)")
    dau_bang(ws, DAU_GAP, RONG_GAP)
    for r in GAP:
        assert len(r) == 12, r[0]
        moi = XONG.get(r[0])
        ws.append([*r[:4], moi[0] if moi else r[4], *r[5:], moi[1] if moi else ""])
    ke_bang(ws, 13, cot_trang_thai=5)


# ══════════════════════════════════════════════════════════ 3. Đợt 1 theo Đ1–Đ6
DOT1 = [
    ("Đ1", "1.1", "Tạo src/eide/nlu/ (normalize.py, dx.py, merge.py) — 0 token",
     "src/eide/nlu/normalize.py (mới), src/eide/nlu/dx.py (mới); chuyển "
     "eide_core/request_ops.py:258 `duong_dan_trong_cau` vào dx.py và giữ hàm cũ làm bí danh",
     "tests/test_dx.py: paths tuyệt đối/tương đối/nháy/backtick; exists=false; 2 đường dẫn trong "
     "một câu; chips (STM32F103, Uno, Blue Pill); numbers (3,0–4,2 V; 2000 mAh); urls; ids "
     "(run-0042); quoted",
     "TC010, TC011, TC016, TC020, TC023, TC043, TC045, TC047, TC052, TC054, TC058, TC070, TC072",
     "Không có DX thì mọi Đ sau đều xây trên slot do mô hình điền"),
    ("Đ1", "1.2", "Nâng intent.schema.json lên v2: slots.paths là MẢNG, mỗi slot có origin, thêm "
     "alt_intents/coref/why",
     "docs/spec/dialog/intent.schema.json; bản sao ở src/eide/caps/memory.py:877 (PHẢI sửa cả "
     "hai); src/eide/caps/chat.py:90 (bỏ gán slots[\"path\"] trực tiếp)",
     "tests/test_specs_consistency.py bổ sung phép kiểm hai bản lược đồ intent giống nhau",
     "TC011, TC043", "Hai bản lược đồ lệch nhau là lỗi im lặng"),
    ("Đ1", "1.3", "Hợp nhất slot theo ưu tiên DX > S3 > mô hình > fill_defaults; chặn "
     "origin=model làm đường dẫn/mã chip; Router ghi origin vào sổ cái",
     "src/eide/nlu/merge.py (mới); src/eide/caps/chat.py:895–955 (`_thay_goc`, `${_path}`); "
     "src/eide_core/router.py (ghi origin)",
     "tests/test_dx.py: slot origin=model không bao giờ chạy tới archive.list",
     "TC016, TC023, TC072", "Gốc của 11 ca \"đường dẫn bịa\""),
    ("Đ1", "1.4", "DX chạy TRƯỚC chat.parse_intent trong đường sống",
     "src/eide/daemon/rpc.py:1035–1069 (chèn N0 + DX trước parse_intent)",
     "tests/test_rpc.py: DX có kết quả kể cả khi Gateway hỏng",
     "toàn bộ nhóm Đ1", "DX sau mô hình thì không sửa được gì"),
    ("Đ2", "2.1", "ingest.classify thêm loại script/log/capture; archive.list CHỈ nhận kind=archive",
     "src/eide/caps/archive.py:114–199 (`classify`, `_nhan_dang`, `BANG_KIND`), :453 "
     "(`archive.list` — kiểm kind trước khi mở), :160 `_khong_phai_kho_nen` (giữ câu của DEV-210)",
     "tests/test_classify_v14.py: .net/.c/.sh/.PcbDoc/.sal/.csv/log cụt → đúng loại + đúng câu lỗi",
     "TC023, TC025, TC026, TC062, TC070", "Sai lý do lỗi làm người đi tìm sai chỗ"),
    ("Đ2", "2.2", "Bộ quét tĩnh script (lệnh phá hoại, đọc khoá riêng) → ASK kèm trích dòng",
     "src/eide/exec/quet_script.py (mới); nối vào ingest.classify và Router trước khi chạy",
     "tests/test_classify_v14.py: don-dep.sh có `rm -rf ~` và đọc ~/.ssh → ASK, trích đúng dòng",
     "TC070", "TC070 đang \"đạt\" nhờ tai nạn — brief §6 không nhận loại đạt này"),
    ("Đ2", "2.3", "Luật P-INJ: quét mẫu chỉ thị trong nội dung tài liệu, loại đoạn nghi khỏi prompt",
     "docs/spec/policy/s0_rules.yaml (mới, nhóm P-INJ); src/eide/caps/archive.py "
     "(ingest.index_text); src/eide/caps/memory.py:715 (compose — loại đoạn nghi)",
     "tests/test_s0_yaml.py + một PDF mẫu có câu \"ignore previous instructions\"",
     "TC014", "Nội dung tải về là DỮ LIỆU, không bao giờ là lệnh"),
    ("Đ3", "3.1", "Bổ sung manifest ISA armv7-m (rồi armv6-m, armv8-m, xtensa-lx6/lx7)",
     "docs/spec/isa/armv7-m.yaml (mới) — theo đúng hình dạng armv7e-m.yaml",
     "tests/test_env.py: env.check(\"armv7-m\") ok; `_isa_tu_chip(\"STM32F103C8T6\")` → armv7-m",
     "TC018, TC015", "Việc rẻ nhất của Đợt 1: dữ liệu, không phải mã"),
    ("Đ3", "3.2", "passport.propose: từ chips[] của DX → thẻ đề nghị 3 lựa chọn; KHÔNG tự ghim "
     "tên chip trần",
     "src/eide/caps/passport.py (thêm `passport.propose`); docs/spec/caps.json (+ hợp đồng); "
     "docs/spec/capabilities/passport.yaml",
     "tests/test_ingest_passport.py: chip đã nêu + chưa có datasheet → thẻ proposal, KHÔNG chặn "
     "chuỗi; các nút không cần Fact vẫn chạy",
     "TC002, TC008, TC015, TC027, TC046, TC048", "Thay câu chặn \"chip nào?\" — 6 ca"),
    ("Đ3", "3.3", "doc.search_web + doc.approve (G-DATA): SearXNG, ưu tiên tên miền nhà sản "
     "xuất, thu metadata + hash, chờ người duyệt",
     "src/eide/caps/search.py:589 (search.web — dựng truy vấn từ chips[]); "
     "src/eide/caps/doc.py (thêm doc.approve); docs/spec/policy/rules.yaml (G-DATA); "
     "Makefile:156 `make searxng` (dựng thật)",
     "tests/test_search.py: mất mạng → E3xxx lỗi MẠNG + incident resumable, không phải lỗi tệp",
     "TC072, TC010, TC046", "TC072 hiện báo lỗi TỆP cho một việc TÌM MẠNG"),
    ("Đ4", "4.1", "nlu/channels.py — tách DIRECTIVE / PRODUCT / DATA bằng một lời gọi mô hình "
     "nhỏ có lược đồ",
     "src/eide/nlu/channels.py (mới); docs/spec/dialog/channels.schema.json (mới); "
     "docs/spec/models.yaml (vai trò parse)",
     "tests/test_channels.py: câu trộn ba kênh của AAD-33 §2.4 tách đúng 4 mệnh đề",
     "TC003, TC017, TC024, TC028", "4 ca — và canh nguyên tắc N7"),
    ("Đ4", "4.2", "req.elicit CHỈ nhận product_text; rủi ro → risk[], không bao giờ thành FR",
     "src/eide/caps/req.py (`req.elicit`); src/eide/caps/chat.py:901 (`${_text}` → "
     "`${_product_text}` trong mẫu chuỗi); docs/spec/dialog/chains.json",
     "tests/test_req.py: \"hãy cố tình gây lỗi cú pháp\" KHÔNG sinh FR; rủi ro TV/USB vào risk[]",
     "TC003, TC017, TC024, TC028", "N7 là nguyên tắc bất biến"),
    ("Đ5", "5.1", "S2 — Inventory xác định (0 token, < 50 ms, cache theo mtime)",
     "src/eide/orchestrator/inventory.py (mới); docs/spec/data/json/inventory.json (mới); "
     "src/eide/daemon/rpc.py (pha S2 trong `_chat_send`)",
     "tests/test_inventory.py: cùng store → cùng bảng (100 %); thời gian < 50 ms; không gọi Gateway",
     "TC008, TC065 + điều kiện của Đ3/Đ6", "N3: mô hình không bao giờ tự mô tả tình trạng dự án"),
    ("Đ5", "5.2", "Hợp đồng capability có requires[]/produces[] (+ gate, on_ask, llm, cost_est, "
     "idempotent, undo)",
     "docs/spec/caps.json (246 mục — bổ sung dần, ưu tiên nhóm của 22 mẫu chuỗi); "
     "docs/spec/data/json/capability.json; docs/ho-so/nguon/ (nguồn sinh)",
     "tests/test_specs_consistency.py: mọi cap trong chains.json có requires/produces",
     "TC009, TC013, TC064", "Không có bảng này thì planner không có gì để suy"),
    ("Đ5", "5.3", "plan.with_preconditions — chèn nút tiền đề (đệ quy ≤ 3, phát hiện vòng), gộp "
     "gap, is_big OR > 7 nút → thẻ kế hoạch",
     "src/eide/orchestrator/planner.py (mới); src/eide_core/chain.py:199 (kiểm sau khi chèn); "
     "src/eide/caps/chat.py:560–880 (`orchestrate` — dùng planner thay vì chỉ mẫu)",
     "tests/test_planner_tien_de.py: diagram.architecture khi modules = 0 → chuỗi "
     "[arch.decompose, diagram.architecture]; vòng bị phát hiện; đệ quy dừng ở 3",
     "TC009, TC013, TC064", "Ví dụ TC009 nằm sẵn trong AAD-33 §3.2.2"),
    ("Đ5", "5.4", "Nút hỏng E2xxx → quay về S3 (≤ 2 lần/lượt), giữ DEV-216 (on_ask=skip không "
     "kéo lượt xuống)",
     "src/eide_core/router.py; src/eide/caps/chat.py (vòng chạy chuỗi)",
     "tests/test_orchestrate.py: E2000 ở nút giữa → S3 hỏi, lượt không failed",
     "TC009, TC064", "Hồi quy: DEV-216 phải còn đúng"),
    ("Đ6", "6.1", "Nối S3 vào đường sống theo máy trạng thái S0→S6; xoá/hợp nhất "
     "src/eide/orchestrator.py (mã chết 69 dòng)",
     "src/eide/daemon/rpc.py:988–1140; src/eide/caps/chat.py:242 (`clarify` nhận Inventory + "
     "requires); xoá src/eide/orchestrator.py (cập nhật tests/test_chat.py:359)",
     "tests/test_rpc.py: câu \"làm cái mạch thông minh\" → thẻ clarify, KHÔNG tạo dự án",
     "TC001, TC004, TC006, TC073", "Brief §3: clarify đã nối — vào mã chết"),
    ("Đ6", "6.2", "Ba dải tin cậy (> 0,85 / 0,60–0,85 / < 0,60); dải ngờ đưa xác nhận ý định + "
     "alt_intents vào thẻ",
     "src/eide/caps/chat.py:35 (`NGUONG_UNKNOWN`), :74–98 (`parse_intent`)",
     "tests/test_chat.py: confidence 0,7 → S3 xác nhận ý định; 0,5 → hỏi thẳng, không chạy gì",
     "TC001, TC004", "Cùng một câu cho hai hành vi khác hẳn (TC004)"),
    ("Đ6", "6.3", "project.create chỉ khi Inventory thấy CHƯA có dự án đang mở; câu mô tả ý "
     "tưởng trong dự án đang mở → UC01 (req.elicit)",
     "src/eide/caps/project.py:133–150 (`create`); src/eide/orchestrator/planner.py (chọn mẫu)",
     "tests/test_project.py: trong dự án mach-thong-minh, câu ý tưởng KHÔNG tạo "
     "mach-thong-minh/cai-mach-thong-minh",
     "TC001, TC006", "Dự án lồng: 37/52 dự án trong workspace có tên kiểu này (project.py:77)"),
    ("Đ6", "6.4", "Thẻ clarify nhiều mục + gia_dinh_neu_bo_qua + tối đa 2 vòng; nhiệt độ "
     "parse/clarify/report = 0, seed cố định",
     "src/eide/caps/chat.py:242–292; docs/spec/dialog/clarify.schema.json (mới); "
     "docs/spec/models.yaml:23–35 (temperature cho mọi vai trò)",
     "tests/test_chat.py: hết 2 vòng → chạy với giả định và IN giả định ở S6",
     "TC004, TC057", "N4: hỏi một cụm, tối đa hai vòng, nói ra giả định"),
    ("Cả đợt", "7.1", "Sổ cái ghi đủ s0.decision, s1.intent (kèm origin), s2.inventory, s3.gaps, "
     "s4.plan, gate.decision cho MỌI lượt",
     "docs/spec/api/ledger_events.json; src/eide_core/ledger.py; từng pha trong rpc.py",
     "tests/test_rpc.py: một lượt đủ 6 loại sự kiện",
     "tiêu chí nghiệm thu brief §6", "Không ghi sổ thì không chấm được ca nào"),
    ("Cả đợt", "7.2", "Chạy lại 76 TC × 5 lần, cập nhật xlsx (Trạng thái, Kết quả thực tế, "
     "Người test, Ngày test, Ghi chú = cơ chế bảo vệ)",
     "scripts/kiem_usecase.py --lap 5; scripts/cap_nhat_usecase_xlsx.py",
     "16 ca đang đạt phải còn đạt (hồi quy bắt buộc)",
     "toàn bộ 76 TC", "Chấm theo lần chạy đầy đủ, không theo lần đẹp nhất"),
    ("Cả đợt", "7.3", "Ghi DEVIATIONS từ DEV-220 cho mọi chỗ mã buộc phải khác tài liệu",
     "docs/DEVIATIONS.md (lệnh /sai-khac)",
     "make check-spec", "—",
     "Các mục đã thấy sẵn: DEV-220 vị trí lược đồ/DEV-LOG, 221 tên cổng, 222 A2↔A3, "
     "223 cap gọi cap, 224 238↔246 năng lực, 225 mô hình Fact, 226 vai trò LLM, 227 M1–M6↔4 "
     "tầng, 228 9 tab↔28 màn"),
]


def sheet_dot1(wb) -> None:
    ws = wb.create_sheet("Dot 1 (D1-D6)")
    dau = ["Sửa đổi", "Việc", "Nội dung", "Tệp phải tạo / sửa", "Unit test phải có",
           "Ca đo mở khoá", "Vì sao không bỏ được"]
    dau_bang(ws, dau, [9, 7, 56, 62, 56, 34, 48])
    for r in DOT1:
        ws.append(list(r))
    ke_bang(ws, 7)
    # tô nhóm theo Đ
    mau = {"Đ1": "E2F0D9", "Đ2": "FFF2CC", "Đ3": "DEEBF7", "Đ4": "FCE4D6",
           "Đ5": "E4DFEC", "Đ6": "D9E2F3", "Cả đợt": "F2F2F2"}
    for r in range(2, ws.max_row + 1):
        o = ws.cell(row=r, column=1)
        o.fill = PatternFill("solid", fgColor=mau.get(str(o.value), "FFFFFF"))
        o.font = Font(size=10, bold=True)


# ══════════════════════════════════════════════════════════ 4. Năng lực mới/đổi
CAPS = [
    ("nlu.extract_deterministic", "Mới", "DX §2.2 — trích paths/chips/numbers/urls/ids/"
     "back_refs/quoted, 0 token", "KHÔNG",
     "một phần trong eide_core/request_ops.py:258 (chỉ paths)", "Đ1", "13 ca",
     "Viết CDS-12 mới + capability.yaml; hợp đồng: không gọi mô hình"),
    ("nlu.split_channels", "Mới", "S1a §2.4 — tách DIRECTIVE/PRODUCT/DATA", "KHÔNG", "—", "Đ4",
     "4 ca", "Viết CDS-12 mới; llm=parse, temperature 0"),
    ("ingest.classify", "Đổi", "Magic bytes + đuôi → archive|netlist|source|script|log|capture|"
     "pdf|image|unknown; mỗi loại một bộ đọc; lỗi đúng lý do", "MỘT PHẦN",
     "src/eide/caps/archive.py:114 (có magic bytes, câu lỗi đã sửa DEV-210); thiếu script/log/"
     "capture và chưa chặn archive.list", "Đ2", "5 ca",
     "Cập nhật CDS-12.2 ARCHIVE-05 + hợp đồng produces"),
    ("passport.propose", "Mới", "Từ chips[] → thẻ đề nghị 3 lựa chọn; nút không cần Fact vẫn "
     "chạy; nút cần Fact đánh dấu chờ", "KHÔNG",
     "passport.* hiện có: list/query/diff/export/import/upgrade/resolve_address", "Đ3", "6 ca",
     "Viết CDS-12 mới; KHÔNG tự ghim tên chip trần (DEV-183)"),
    ("passport.pin", "Mới", "Ghim ns.part@semver sau khi có tài liệu; đối chiếu ISA manifest",
     "MỘT PHẦN", "board.build_passport ghim hộ chiếu bo; không có luồng 7 bước của AGD-32 §5",
     "Đ3", "TC018, TC027", "Viết CDS-12 mới; chỉ chạy sau bước 5 (hàng đợi rà soát)"),
    ("doc.search_web / doc.approve", "Mới/Đổi", "Tìm datasheet qua SearXNG ưu tiên nhà sản "
     "xuất; thu metadata + hash; chờ G-DATA", "MỘT PHẦN",
     "src/eide/caps/search.py search.web (:589) + search.vendor; không có doc.approve", "Đ3",
     "TC010, TC046, TC072", "Cổng G-DATA phải có trong rules.yaml trước"),
    ("fact.extract / review / query / compare", "Mới", "Bảng thông số → Fact ứng viên; hàng đợi "
     "rà soát; truy vấn xác định; so sánh hai vế ≥ Bạc", "MỘT PHẦN",
     "bảng fact (schema.sql:15) + extract.pdf_* sinh fact; kg.review_facts CHƯA hiện thực; "
     "không có namespace fact.*", "—", "TC008, TC013, TC021, TC031, TC075",
     "Đợt 2 — nền của N1/N2"),
    ("plan.with_preconditions", "Mới", "S4 §3.2 — planner có tiền đề", "KHÔNG",
     "chuỗi lấy từ 22 mẫu tĩnh (chains.json); plan.* hiện có là kế hoạch SẢN PHẨM, không phải "
     "kế hoạch LƯỢT", "Đ5", "TC009, TC013, TC064",
     "Chú ý trùng tên: namespace plan.* đang là plan.create/decompose/order (kế hoạch tính năng)"),
    ("env.check", "Đổi", "Đối chiếu ISA của chip với manifest; không khớp → nói thẳng thay vì "
     "đưa 3 lựa chọn đều sai", "MỘT PHẦN",
     "src/eide/caps/env.py:67 đã nói thẳng (E2000) khi thiếu manifest — thứ thiếu là DỮ LIỆU "
     "manifest armv7-m", "Đ3", "TC018",
     "DEV-203 đã sửa việc hỏi ISA khi câu đã nêu chip"),
    ("sim.define_criteria", "Mới", "Tiêu chí chấp nhận nêu TRƯỚC khi chạy; đổi tiêu chí qua "
     "G-QUAL", "KHÔNG", "sim.*: build_platform/mock_peripheral/model_plant/run/scenario/sweep",
     "—", "TC019, TC022, TC076", "Đợt 3 — canh nguyên tắc N6"),
    ("nlu.merge_slots (đề xuất)", "Mới", "Hợp nhất slot theo ưu tiên DX > S3 > mô hình > "
     "fill_defaults", "KHÔNG", "—", "Đ1", "toàn bộ nhóm Đ1",
     "Tài liệu nói là \"quy tắc\" (§2.2) chứ không là năng lực — có thể để trong nlu/, không "
     "cần hợp đồng riêng"),
    ("orchestrator.inventory (S2)", "Mới", "Bảng kiểm kê xác định", "KHÔNG",
     "gần nhất: chat.ground (src/eide/caps/chat.py:102)", "Đ5", "TC008, TC065",
     "Tài liệu gọi là PHA, không là capability — nhưng cần hợp đồng để S3/S4/S5 dùng chung"),
]

THIEU_33 = ("bench.run · code.merge · debug.experiment · diagram.sync · discover.board_match · "
            "discover.bus_scan · discover.chip_id · discover.clock_measure · "
            "discover.firmware_probe · discover.link_speed · discover.power · discover.probe · "
            "doc.sync · env.install · kg.review_facts · measure.capture_signal · measure.power · "
            "measure.sync · passport.verify_on_board · plan.create · project.create · "
            "registry.publish · search.fetch · sim.compare_hil · target.diagnose_fault · "
            "target.erase_fuse · target.flash · target.observe · target.probe_read · "
            "target.probe_write · target.reset · target.serial · tool.run")


def sheet_caps(wb) -> None:
    ws = wb.create_sheet("Nang luc moi-doi")
    dau = ["Năng lực (AAD-33 §4)", "Mới/Đổi", "Việc", "Trạng thái trong mã",
           "Chỗ gần nhất hiện có", "Sửa đổi", "Ca đo", "Việc phải làm với hồ sơ"]
    dau_bang(ws, dau, [30, 10, 50, 14, 56, 9, 26, 48])
    for r in CAPS:
        ws.append(list(r))
    ke_bang(ws, 8, cot_trang_thai=4)
    ws.append([])
    ws.append(["33 năng lực trong docs/spec/caps.json CHƯA hiện thực (đo 24/09/2026: "
               "213/246 có @capability)"])
    ws.cell(row=ws.max_row, column=1).font = Font(bold=True, size=10)
    ws.append([THIEU_33])
    o = ws.cell(row=ws.max_row, column=1)
    o.alignment = Alignment(wrap_text=True, vertical="top")
    o.font = Font(size=10)
    ws.merge_cells(start_row=ws.max_row, start_column=1, end_row=ws.max_row, end_column=8)
    ws.row_dimensions[ws.max_row].height = 60


# ══════════════════════════════════════════════════════════ 5. Lược đồ JSON
SCHEMA = [
    ("Utterance", "utterance.schema.json", "N0 → DX", "raw, normalized, no_accent, clauses[]",
     "KHÔNG", "—", "Đ1"),
    ("DXResult", "dx.schema.json", "DX → S0/S1/S3",
     "paths[] (MẢNG), chips[], numbers[], urls[], ids[], back_refs[], quoted[]", "KHÔNG", "—",
     "Đ1"),
    ("Gate0Decision", "gate0.schema.json", "S0", "decision, rule_ids[], message", "KHÔNG",
     "docs/spec/policy/rules.yaml có luật nhưng không có lược đồ quyết định S0", "Đ1/Đ2"),
    ("Channels", "channels.schema.json", "S1a",
     "clauses[{id,text,channel}], product_text, directive_text", "KHÔNG", "—", "Đ4"),
    ("Intent v2", "intent.schema.json", "S1b",
     "intent (enum từ caps), confidence, is_big, slots{…origin}, alt_intents[]", "MỘT PHẦN",
     "docs/spec/dialog/intent.schema.json (v1: path chuỗi đơn, không origin/alt_intents) + bản "
     "sao ở src/eide/caps/memory.py:877", "Đ1/Đ6"),
    ("Inventory", "inventory.schema.json", "S2", "§3.1 — 13 nhóm trường", "KHÔNG", "—", "Đ5"),
    ("ClarifyResult", "clarify.schema.json", "S3",
     "du_thong_tin, gaps[{khoa, cau_hoi, lua_chon, vi_sao, bat_buoc}], gia_dinh_neu_bo_qua",
     "MỘT PHẦN",
     "docs/spec/data/json/clarification.json + clarification_answer.json (mô hình khác: một câu "
     "hỏi + options phẳng)", "Đ6"),
    ("Plan", "plan.schema.json", "S4",
     "nodes[{cap, params, gate, on_ask, timeout, undo}], is_big, cost_est, assumptions[]",
     "MỘT PHẦN",
     "docs/spec/dialog/chains.json (mẫu chuỗi) + run.graph trong store; không có lược đồ kế "
     "hoạch một lượt", "Đ5"),
    ("CapabilityContract", "capability.schema.json", "caps.json",
     "requires/produces/risk/gate/llm/cost_est", "MỘT PHẦN",
     "docs/spec/data/json/capability.json + docs/spec/capabilities/<ns>.yaml (không có requires/"
     "produces)", "Đ5"),
    ("Fact", "fact.schema.json", "Kho Fact",
     "key, min/typ/max, condition, source{doc_id, version, page, quote, bbox}, tier, supersedes",
     "MỘT PHẦN", "docs/spec/data/json/fact.json (mô hình subject/predicate/value, thiếu min/typ/"
     "max/condition/page/quote/bbox)", "Đợt 2"),
    ("Passport", "passport.schema.json", "Hộ chiếu", "ns.part@semver, isa, docs[], facts[]",
     "CÓ", "docs/spec/data/json/passport.json + passport_fact.json", "—"),
    ("LedgerEvent", "ledger.schema.json", "Sổ cái", "§3.5 — 16 loại kind", "MỘT PHẦN",
     "docs/spec/api/ledger_events.json (24 loại, khác tên; thiếu s0/s2/s3/s4/incident)", "Đ1/Đ6"),
    ("Card", "card.schema.json", "Giao diện", "§9.3 / UIP-34 §6 — 6 loại thẻ", "KHÔNG",
     "thẻ dựng phía Swift (apps/eide/Sources/EideGiaoDien/EideThe*.swift)", "Đợt 2"),
    ("Criteria / Scenario", "sim.criteria.schema.json, sim.scenario.schema.json", "Mô phỏng",
     "assert[], timeout_s; stimuli[]", "KHÔNG",
     "src/eide/caps/sim.py sim.scenario dựng kịch bản không theo lược đồ công bố", "Đợt 3"),
    ("UAP (bổ sung UIP-34 §12)", "uap.schema.json", "Cầu giao diện",
     "Envelope, HumanAct, UICommand, SurfaceModel/Block, Card, ui.status", "KHÔNG",
     "docs/spec/api/openrpc.json (65 phương thức, hình dạng khác)", "Đợt 2"),
]


def sheet_schema(wb) -> None:
    ws = wb.create_sheet("Luoc do JSON")
    dau = ["Lược đồ", "Tệp theo AAD-33 §10", "Dùng ở", "Điểm khoá", "Trạng thái",
           "Chỗ tương đương hiện có", "Sửa đổi / Đợt"]
    dau_bang(ws, dau, [24, 34, 14, 56, 12, 62, 14])
    for r in SCHEMA:
        ws.append(list(r))
    ke_bang(ws, 7, cot_trang_thai=5)
    ws.append([])
    ws.append(["Ghi chú vị trí: tài liệu nói `schemas/*.json` ở gốc kho. Kho đang đặt lược đồ "
               "trong `docs/spec/` (data/json, dialog, policy, api) và `tests/"
               "test_specs_consistency.py` kiểm mã ≡ spec từ đó. Đề nghị giữ MỘT nơi "
               "(docs/spec/) và ghi DEV-229 thay vì tạo thư mục thứ hai."])
    o = ws.cell(row=ws.max_row, column=1)
    o.font = Font(size=10, italic=True)
    o.alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=ws.max_row, start_column=1, end_row=ws.max_row, end_column=7)
    ws.row_dimensions[ws.max_row].height = 44


# ══════════════════════════════════════════════════════════ 6. Giao thức UAP
UAP = [
    ("Bất biến", "I1 — một cửa vào console.act (HumanAct)", "KHÔNG",
     "~40 phương thức nhận hành động người (rpc.py:341–357); openrpc.json: 65 phương thức",
     "UP01", "Đợt 2"),
    ("Bất biến", "I2 — một dòng hội thoại, transcript là hình chiếu sổ cái", "MỘT PHẦN",
     "rpc.py:1035 `_ghi_luot` + chat.history; bấm nút không sinh mục transcript", "UP02, UP03",
     "Đợt 2"),
    ("Bất biến", "I3 — giao diện không quyết", "MỘT PHẦN",
     "có --kich-ban (KichBan.swift) nhưng 28 màn tự dựng nội dung", "UP04, UP05", "Đợt 2"),
    ("Bất biến", "I4 — lõi không thấy sự kiện chuột/phím", "CÓ",
     "daemon chỉ nhận tham số nghiệp vụ", "—", "—"),
    ("Bất biến", "I5 — có thứ tự, không trùng, khôi phục được (seq, id, resume)", "KHÔNG",
     "không có Envelope/seq/session; chat.resume theo run_id (rpc.py:1398)", "UP06, UP07, UP11",
     "Đợt 2"),
    ("Bất biến", "I6 — cổng là thẻ riêng, chỉ nhận decide có gate_id khớp", "MỘT PHẦN",
     "gate.decide (rpc.py:1532); chưa chặn câu text duyệt thay thẻ", "UP08, UP09", "Đợt 1"),
    ("HumanAct", "say", "CÓ (khác tên)", "chat.send (rpc.py:353)", "—", "Đợt 2"),
    ("HumanAct", "choose", "MỘT PHẦN", "chat.answer (rpc.py:1438) — theo hàng đợi, không theo "
     "card_id + answers{}", "UP08", "Đợt 2"),
    ("HumanAct", "decide", "CÓ (khác tên)", "gate.decide (rpc.py:1532)", "UP09", "Đợt 2"),
    ("HumanAct", "confirm (Fact / nguồn)", "KHÔNG",
     "kg.resolve_conflict + kg.review_facts (chưa hiện thực); không có đường xác nhận một dòng Fact",
     "UP02", "Đợt 2"),
    ("HumanAct", "edit (người sửa hiện vật rồi lưu)", "CÓ (khác tên)",
     "code.human_save (src/eide/caps/code.py) + ledger human.file_save", "—", "Đợt 2"),
    ("HumanAct", "upload (kéo thả tệp)", "MỘT PHẦN",
     "chat.send attachments (src/eide/caps/chat.py:82) + EideVungTha.swift", "—", "Đợt 2"),
    ("HumanAct", "stop", "CÓ", "\"stop\" + đường tắt dừng khẩn (rpc.py:1014)", "—", "Đợt 2"),
    ("HumanAct", "undo", "CÓ (khác tên)", "undo.apply / undo.list", "—", "Đợt 2"),
    ("HumanAct", "resume", "CÓ (khác tên)", "chat.resume (rpc.py:1398)", "UP07", "Đợt 2"),
    ("HumanAct", "attend (chuyển tab / chọn hiện vật)", "KHÔNG",
     "lõi không biết người đang xem gì → DST thiếu focus", "—", "Đợt 2"),
    ("HumanAct", "set (đổi thiết lập vận hành)", "CÓ (khác tên)", "autonomy.set", "—", "Đợt 2"),
    ("UICommand", "console.post / console.stream", "MỘT PHẦN",
     "event.chat.restated + event.chat.report (openrpc.json) — không có ack/card/stream", "—",
     "Đợt 2"),
    ("UICommand", "card.resolve / card.expire", "KHÔNG", "—", "UP09", "Đợt 2"),
    ("UICommand", "surface.set / patch / append", "KHÔNG",
     "giao diện tự hỏi lại bằng view.*/caps.invoke", "UP11", "Đợt 2"),
    ("UICommand", "surface.focus / highlight", "KHÔNG", "—", "UP12", "Đợt 2"),
    ("UICommand", "surface.lock / unlock", "MỘT PHẦN",
     "soft-lock trong code.human_save/merge (G-FILE) nhưng không phát lệnh khoá cho giao diện",
     "—", "Đợt 2"),
    ("UICommand", "run.update", "MỘT PHẦN", "event.run.progress + thẻ Run (EideTheRun.swift)",
     "—", "Đợt 2"),
    ("UICommand", "notice", "MỘT PHẦN", "event.notice + EideToast.swift", "—", "Đợt 2"),
    ("UICommand", "ui.set", "KHÔNG", "cỡ chat/thanh trạng thái do giao diện tự quyết", "—",
     "Đợt 2"),
    ("Card", "clarify / proposal / plan / gate / report / criteria", "MỘT PHẦN",
     "EideTheYHieu/TheRun/TheHoi/TheXungDot/TheKetQua.swift dựng thẻ từ dữ liệu rời của lõi",
     "UP08", "Đợt 2"),
    ("Bề mặt", "9 bề mặt (console…ledger) × 12 loại khối", "KHÁC",
     "docs/spec/ui/screens.json — 28 màn", "UP10", "Đợt 2"),
    ("Kiểm thử", "UP01–UP12 + lint giao thức trong CI", "KHÔNG", "tests/ không có ca giao thức",
     "UP01–UP12", "Đợt 2"),
]


def sheet_uap(wb) -> None:
    ws = wb.create_sheet("Giao thuc UAP")
    dau = ["Nhóm", "Mục UIP-34", "Trạng thái", "Chỗ tương đương trong mã hiện tại",
           "Ca tuân thủ", "Đợt"]
    dau_bang(ws, dau, [12, 48, 14, 72, 16, 8])
    for r in UAP:
        ws.append(list(r))
    ke_bang(ws, 6, cot_trang_thai=3)


# ══════════════════════════════════════════════════════════ 7. Cổng phê duyệt
CONG = [
    ("G-DATA", "R1", "doc.approve, fact.review — nguồn tài liệu và Fact ứng viên",
     "AUTO nếu tên miền ∈ trusted_sources; Fact vẫn BẠC", "MỘT PHẦN",
     "rules.yaml: G-SRC (6 luật) cho nguồn + G-FACT (6 luật) cho fact",
     "Gộp/đổi tên G-SRC + G-FACT → G-DATA, hoặc cập nhật tài liệu; cần danh sách "
     "trusted_sources", "Đ3"),
    ("G-DESIGN", "R1", "Chọn phương án; chốt thiết kế; mã ≠ schematic", "ASK", "MỘT PHẦN",
     "rules.yaml: G1 (4 luật), G3 (5 luật) — tên theo APD-08 v1.2",
     "Ánh xạ G1/G3 → G-DESIGN; TC027 (mã ≠ schematic) cần luật riêng", "—"),
    ("G-SCOPE", "R1", "is_big HOẶC chuỗi > 7 nút → thẻ kế hoạch chờ gật", "ASK", "KHÔNG",
     "không có luật nào theo is_big/số nút; plan_only bật theo mức tự chủ (rpc.py:1100)",
     "Thêm luật G-SCOPE + tính is_big bằng mã", "Đ5"),
    ("G-TOOL", "R2", "tool.install / env.install", "ASK lần đầu, AUTO cùng gói/nguồn nếu người "
     "chọn \"tin\"", "CÓ", "rules.yaml: G-TOOL (6 luật)",
     "Thêm decision=trust ghi vào long-term memory", "—"),
    ("G-QUAL", "R2", "sim.define_criteria (sửa), test.* xoá — bắt buộc nêu từ–đến–vì sao",
     "ASK, luôn hỏi", "MỘT PHẦN",
     "S0 P-QUAL chặn câu hạ chuẩn (request_ops.py:196) — TC022 ĐANG ĐẠT; nhưng không có cổng "
     "G-QUAL trong rules.yaml",
     "Thêm cổng G-QUAL cho nút sửa tiêu chí; giữ lớp S0 đang đạt", "Đợt 3"),
    ("G-FILE", "R2", "code.write vào tệp có human edit chưa merge — soft-lock + 3-way merge",
     "Soft-lock; ghi đè → ASK", "MỘT PHẦN",
     "code.human_save + code.merge_conflict_resolve + EideManDiffMerge.swift; không có tên cổng "
     "G-FILE trong rules.yaml",
     "Đặt tên cổng cho luật đang có", "—"),
    ("G-OPS", "R4", "erase_all, option_bytes, RDP, eFuse, bootloader", "Luôn hỏi, thẻ riêng, "
     "nêu hậu quả; KHÔNG AUTO ở mọi mức A0–A4", "CÓ",
     "rules.yaml: G-OPS (7 luật, G-OPS-02 priority=1) + request_ops.py:59 nhận diện trong câu "
     "(DEV-200) — TC035/TC068 ĐANG ĐẠT",
     "Giữ nguyên; chỉ chuyển bảng dấu hiệu sang YAML (G-020)", "—"),
    ("G-SAFE", "R4", "Điện lưới; chip nóng/khói; dòng bất thường — \"NGẮT NGUỒN NGAY\" là câu "
     "đầu tiên", "Cảnh báo trước mọi thứ, không tắt được", "MỘT PHẦN",
     "S0 P-SAFE (request_ops.py:189 + :224 `loi_khuyen_an_toan`) — TC036/TC069 ĐANG ĐẠT; "
     "không có cổng G-SAFE trong rules.yaml",
     "Đặt tên cổng; giữ nguyên hành vi (DEV-204)", "—"),
    ("(cổng hiện có không có trong v1.4)", "—", "G-WL (3 luật — danh sách trắng công cụ tự "
     "viết), G4 (3), G5 (4)", "—", "KHÁC",
     "rules.yaml: G-WL cho tool.write/sandbox (SEC-25), G4/G5 theo APD-08 v1.2",
     "Giữ; nêu trong bản cập nhật AAD-33 §3.4 để bảng cổng không bị hiểu là đầy đủ", "—"),
]


def sheet_cong(wb) -> None:
    ws = wb.create_sheet("Cong phe duyet")
    dau = ["Cổng v1.4", "Lớp rủi ro", "Kích hoạt khi", "Ở mức mặc định", "Trạng thái",
           "Cổng / mã đang có trong kho", "Việc phải làm", "Sửa đổi"]
    dau_bang(ws, dau, [16, 10, 46, 40, 12, 58, 46, 9])
    for r in CONG:
        ws.append(list(r))
    ke_bang(ws, 8, cot_trang_thai=5)


# ══════════════════════════════════════════════════════════ 8. 76 ca đo
DEN_D = {
    "Đ1": "TC010 TC011 TC016 TC020 TC023 TC043 TC045 TC047 TC052 TC054 TC058 TC070 TC072".split(),
    "Đ2": "TC023 TC025 TC026 TC062 TC070".split(),
    "Đ3": "TC002 TC008 TC015 TC027 TC046 TC048".split(),
    "Đ4": "TC003 TC017 TC024 TC028".split(),
    "Đ5": "TC009 TC013 TC064".split(),
    "Đ6": "TC001 TC004 TC006 TC073".split(),
}
HOI_QUY = ("TC005 TC007 TC022 TC031 TC032 TC035 TC036 TC037 TC038 TC040 TC042 TC063 TC068 "
           "TC069 TC075 TC076").split()
DOT2 = "TC021 TC065 TC066 TC074 TC044".split()
DOT3 = ("TC015 TC016 TC017 TC018 TC019 TC020 TC021 TC022 TC052 TC055 TC058 TC059 TC060").split()
DOT4 = "TC029 TC030 TC031 TC032 TC033 TC034 TC047 TC049 TC050 TC053 TC054 TC056".split()


def sua_o_dau(tc: str, trang_thai: str) -> tuple[str, str]:
    """(sửa đổi, đợt) cho một ca — Đ1–Đ6 trước, rồi đợt sau."""
    ds = [d for d, xs in DEN_D.items() if tc in xs]
    if trang_thai == "Đạt":
        return (", ".join(ds), "Hồi quy — phải giữ") if ds else ("—", "Hồi quy — phải giữ")
    if ds:
        return ", ".join(ds), "Đợt 1"
    if tc in DOT2:
        return "—", "Đợt 2"
    if tc in DOT4:
        return "—", "Đợt 4"
    if tc in DOT3:
        return "—", "Đợt 3"
    return "—", "chưa xếp"


def sheet_ca_do(wb) -> None:
    import openpyxl as op
    wbtc = op.load_workbook(XLSX_TC, data_only=False)
    wstc = wbtc["Test case"]
    ws = wb.create_sheet("Ca do 76 TC")
    dau = ["Mã TC", "UC", "Loại", "Tên kịch bản", "Ưu tiên", "Trạng thái 23/09",
           "Nguyên nhân đo được (rút gọn)", "Sửa đổi", "Đợt"]
    dau_bang(ws, dau, [9, 7, 9, 46, 8, 14, 74, 10, 20])
    for r in wstc.iter_rows(min_row=2, values_only=True):
        if not r[0]:
            continue
        tc, uc, loai, ten, uu, tt, tte = r[0], r[1], r[2], r[3], r[7], r[8], (r[9] or "")
        d, dot = sua_o_dau(str(tc), str(tt))
        ws.append([tc, uc, loai, ten, uu, tt, str(tte)[:300], d, dot])
    ke_bang(ws, 9)
    for row in range(2, ws.max_row + 1):
        o = ws.cell(row=row, column=6)
        mau = {"Đạt": LUC, "Không đạt": DO, "Bị chặn": CAM, "Bỏ qua": "F2F2F2"}.get(
            str(o.value or "").strip())
        if mau:
            o.fill = PatternFill("solid", fgColor=mau)
    return wbtc


# ══════════════════════════════════════════════════════════ 9. Thống kê
def sheet_thong_ke(wb) -> None:
    ws = wb.create_sheet("Thong ke")
    ws.column_dimensions["A"].width = 52
    ws.column_dimensions["B"].width = 14
    n = len(GAP) + 1
    hang = [
        ("BẢNG RÀ SOÁT", None),
        ("Tổng số mục thiết kế đã rà", f"=COUNTA('Ra soat (GAP)'!A2:A{n})"),
        ("KHÔNG có trong mã", f"=COUNTIF('Ra soat (GAP)'!E2:E{n},\"KHÔNG\")"),
        ("MỘT PHẦN", f"=COUNTIF('Ra soat (GAP)'!E2:E{n},\"MỘT PHẦN\")"),
        ("KHÁC (mã làm theo cách khác)", f"=COUNTIF('Ra soat (GAP)'!E2:E{n},\"KHÁC\")"),
        ("CÓ (đúng thiết kế)", f"=COUNTIF('Ra soat (GAP)'!E2:E{n},\"CÓ\")"),
        ("XONG Đ1 (đã sửa 24/09/2026)", f"=COUNTIF('Ra soat (GAP)'!E2:E{n},\"XONG Đ1\")"),
        ("", None),
        ("THEO ĐỢT", None),
        ("Đợt 1", f"=COUNTIF('Ra soat (GAP)'!J2:J{n},\"Đợt 1\")"),
        ("Đợt 2", f"=COUNTIF('Ra soat (GAP)'!J2:J{n},\"Đợt 2\")"),
        ("Đợt 3", f"=COUNTIF('Ra soat (GAP)'!J2:J{n},\"Đợt 3\")"),
        ("Đợt 4", f"=COUNTIF('Ra soat (GAP)'!J2:J{n},\"Đợt 4\")"),
        ("", None),
        ("THEO SỬA ĐỔI (Đợt 1)", None),
        ("Mục có liên quan Đ1", f"=COUNTIF('Ra soat (GAP)'!I2:I{n},\"*Đ1*\")"),
        ("Mục có liên quan Đ2", f"=COUNTIF('Ra soat (GAP)'!I2:I{n},\"*Đ2*\")"),
        ("Mục có liên quan Đ3", f"=COUNTIF('Ra soat (GAP)'!I2:I{n},\"*Đ3*\")"),
        ("Mục có liên quan Đ4", f"=COUNTIF('Ra soat (GAP)'!I2:I{n},\"*Đ4*\")"),
        ("Mục có liên quan Đ5", f"=COUNTIF('Ra soat (GAP)'!I2:I{n},\"*Đ5*\")"),
        ("Mục có liên quan Đ6", f"=COUNTIF('Ra soat (GAP)'!I2:I{n},\"*Đ6*\")"),
        ("", None),
        ("CA ĐO 23/09/2026", None),
        ("Tổng ca", "=COUNTA('Ca do 76 TC'!A2:A200)"),
        ("Đạt", "=COUNTIF('Ca do 76 TC'!F2:F200,\"Đạt\")"),
        ("Không đạt", "=COUNTIF('Ca do 76 TC'!F2:F200,\"Không đạt\")"),
        ("Bị chặn", "=COUNTIF('Ca do 76 TC'!F2:F200,\"Bị chặn\")"),
        ("Bỏ qua", "=COUNTIF('Ca do 76 TC'!F2:F200,\"Bỏ qua\")"),
        ("Ca Đợt 1 nhắm tới (Đ1–Đ6)", "=COUNTIF('Ca do 76 TC'!I2:I200,\"Đợt 1\")"),
        ("Ca hồi quy phải giữ", "=COUNTIF('Ca do 76 TC'!I2:I200,\"Hồi quy — phải giữ\")"),
        ("", None),
        ("MÃ NGUỒN (đo 24/09/2026)", None),
        ("Năng lực trong docs/spec/caps.json", 246),
        ("Năng lực đã hiện thực (@capability)", 213),
        ("Năng lực chưa hiện thực", 33),
        ("Mẫu chuỗi trong docs/spec/dialog/chains.json", 22),
        ("Manifest ISA trong docs/spec/isa/", 3),
        ("Phương thức JSON-RPC trong openrpc.json", 65),
        ("Loại sự kiện sổ cái", 24),
        ("Tệp test trong tests/", 81),
        ("Mục DEVIATIONS đã dùng", "DEV-001 … DEV-233 (220–229 mâu thuẫn tài liệu, 230–233 từ Đ1)"),
    ]
    for a, b in hang:
        ws.append([a, b])
    for r in range(1, ws.max_row + 1):
        o = ws.cell(row=r, column=1)
        o.font = Font(size=10, bold=ws.cell(row=r, column=2).value is None)
        o.alignment = Alignment(wrap_text=True, vertical="center")
        if ws.cell(row=r, column=2).value is None and o.value:
            o.fill = PatternFill("solid", fgColor=NHAT)
        ws.cell(row=r, column=2).font = Font(size=10, bold=True)


def main() -> None:
    wb = openpyxl.Workbook()
    sheet_huong_dan(wb)
    sheet_gap(wb)
    sheet_dot1(wb)
    sheet_caps(wb)
    sheet_schema(wb)
    sheet_uap(wb)
    sheet_cong(wb)
    sheet_ca_do(wb)
    sheet_thong_ke(wb)
    RA.parent.mkdir(parents=True, exist_ok=True)
    wb.save(RA)
    print(f"đã ghi {RA.relative_to(GOC)} — {len(wb.sheetnames)} sheet, "
          f"{len(GAP)} mục rà soát")
    # bản JSON để máy đọc / kiểm lại
    js = RA.with_suffix(".json")
    js.write_text(json.dumps(
        [dict(zip(DAU_GAP, [*r[:4], XONG.get(r[0], (r[4], ""))[0], *r[5:],
                            XONG.get(r[0], ("", ""))[1]], strict=True)) for r in GAP],
        ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"đã ghi {js.relative_to(GOC)}")


if __name__ == "__main__":
    main()
