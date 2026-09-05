# -*- coding: utf-8 -*-
"""EIDE-PLN-27 — Kế hoạch phát triển và backlog theo mốc (Excel), sinh từ Danh mục năng lực + tài liệu + TC."""
import openpyxl, json, re
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.worksheet.datavalidation import DataValidation
from collections import defaultdict
caps = json.load(open("/home/claude/eide-docs/caps.json"))
cds = {r["id"]: r for r in json.load(open("/home/claude/eide-docs/cds.json"))}
RED, SLATE, ZEBRA = "B8121F", "2F4858", "F2F6FB"
thin = Side(style="thin", color="D0D5DD"); BORDER = Border(left=thin, right=thin, top=thin, bottom=thin)
HF = Font(bold=True, color="FFFFFF", name="Arial", size=10); BODY = Font(name="Arial", size=10); WRAP = Alignment(wrap_text=True, vertical="top")
wb = openpyxl.Workbook()
def sheet(title, header, rows, widths, freeze="B2", table=None):
    ws = wb.create_sheet(title); ws.append(header)
    for c in ws[1]: c.font = HF; c.fill = PatternFill("solid", fgColor=RED); c.border = BORDER; c.alignment = Alignment(wrap_text=True, vertical="center")
    for i, r in enumerate(rows, 2):
        ws.append(list(r))
        for c in ws[i]:
            c.font = BODY; c.alignment = WRAP; c.border = BORDER
            if i % 2 == 0: c.fill = PatternFill("solid", fgColor=ZEBRA)
    for col, w in zip("ABCDEFGHIJKLMNOP", widths): ws.column_dimensions[col].width = w
    ws.freeze_panes = freeze
    if table and rows:
        t = Table(displayName=table, ref=f"A1:{chr(64 + len(header))}{len(rows) + 1}"); t.tableStyleInfo = TableStyleInfo(name="TableStyleLight1", showRowStripes=False); ws.add_table(t)
    return ws

# ---- Sheet 0
ws0 = wb.active; ws0.title = "0. Hướng dẫn"
for i, (t, b) in enumerate([
 ("EIDE-PLN-27 — KẾ HOẠCH PHÁT TRIỂN VÀ BACKLOG THEO MỐC (v1.0)", True),
 ("Đề án tốt nghiệp Thạc sĩ ngành Kỹ thuật Điện tử — PTIT · Học viên: Vũ Trí Công · Người hướng dẫn: TS. Nguyễn Trung Hiếu · 05/09/2026", False),
 ("Sheet 1 Mốc: phạm vi, tiêu chí xong, số việc (công thức). Sheet 2 Backlog: một dòng cho mỗi việc (hạ tầng, năng lực, UI, tài liệu, test) với mốc, ưu tiên, ước lượng, phụ thuộc, ai làm (người/AI), tài liệu tham chiếu, trạng thái. Sheet 3 Truy vết hợp nhất: UR → FR/năng lực → thiết kế → TC → màn hình. Sheet 4 Phân công Người–AI: theo loại việc. Sheet 5 Thống kê (công thức).", False),
 ("Quy ước: ước lượng theo ngày công có AI hỗ trợ (tác tử coder viết phần lớn mã dưới sự duyệt của người); 'AI làm' = tác tử làm trọn, 'AI làm/người duyệt' = AI viết người review, 'Người' = quyết định/thiết kế/kiểm phần cứng.", False),
 ("Cột Trạng thái có danh sách chọn (Chưa · Đang · Xong · Bỏ). Lọc theo Mốc để lấy backlog của sprint.", False),
], 1):
    c = ws0.cell(row=i, column=1, value=t); c.alignment = WRAP; c.font = Font(name="Arial", size=14 if i == 1 else 10, bold=b, color=RED if i == 1 else "000000")
ws0.column_dimensions["A"].width = 160

# ---- Backlog rows
rows = []; n = 0
def add(kind, title, ms, prio, days, deps, who, ref, cap=""):
    global n; n += 1
    rows.append([f"WI-{n:03d}", kind, title, ms, prio, days, deps, who, ref, cap, "Chưa"])
# Hạ tầng M1
for t, d, dep, ref in [
 ("Đổi tên kho hkw-core → eide; alias import; .hkw → .eide symlink", 1, "", "DEP-26, CON-28"),
 ("Migration 0002_m1 (bảng policy/runtime) + eide migrate", 1.5, "WI-001", "DDD-14 §5"),
 ("Capability Registry + Router (nạp capabilities/*.yaml, invoke, grounding, ledger, undo)", 4, "WI-002", "SDD-04 §4.0, CDS-12"),
 ("PolicyGate + rules.yaml + autonomy.yaml + UndoService + decision_log", 4, "WI-003", "POL-17"),
 ("Orchestrator (intent, ground, defaults, clarify, chain, runner, report) + chains/*.yaml", 6, "WI-003, WI-004", "DPS-09, PRS-16"),
 ("Composer + Compressor (ContextBundle, Graph-RAG 2 bước, ngân sách, cache marks)", 4, "WI-003", "CXD-10"),
 ("Memory: WorkingMemory/Session/ErrorLedger/Preference; PROGRESS/FEATURES sinh tự động; resume", 3, "WI-002", "MEM-11"),
 ("Ledger chuỗi hash + bộ lọc bí mật + api/errors.json", 1.5, "", "API-15 §6–7, SEC-25"),
 ("Sandbox (tiến trình con, giới hạn, giám sát hiệu ứng, audit hook)", 3, "", "SEC-25 §2"),
 ("JSON-RPC server + OpenRPC + REST nội bộ + CLI eide \"<lệnh>\"", 4, "WI-003, WI-005", "API-15"),
 ("MCP server sinh tool từ registry (caps_*, chat_command, 12 tool nhanh)", 2, "WI-003", "API-15 §3"),
 ("RagIndex (chunk, embedding qua Gateway, FTS5, gắn IRI, truy hồi lai)", 3, "WI-002", "KAD-07 §6.9, CDS view.rag_index"),
 ("Prompt 9 vai trò + roles/models.yaml + 50 câu lệnh + test L2b", 2, "WI-005", "PRS-16"),
]:
    add("Hạ tầng", t, "M1", "M", d, dep, "AI làm/người duyệt", ref)
# Hạ tầng M2/M3
for t, ms, d, dep, ref in [
 ("Migration 0004_m2 (module, hw_map, adr, doc_artifact, discovery, measurement)", "M2", 1, "WI-002", "DDD-14"),
 ("Bộ render lược đồ (mmdc/plantuml/dot/d2/wavedrom) trong sandbox + lint", "M2", 2, "WI-009", "CDS diagram.render"),
 ("Mẫu docx Python (port eaa_doc) + style_check", "M2", 2, "", "CDS doc.generate"),
 ("Adapter target theo ISA (probe-rs, openocd, avrdude, esptool) + serial daemon", "M2", 4, "WI-009", "TGT-19"),
 ("Discovery (ports/probe/chip_id/link_speed/auto_setup) + bảng VID/PID + id_tables", "M2", 4, "WI-017", "TGT-19 §4–6"),
 ("Sim: Renode .repl từ hộ chiếu + mock BME280/MPU6050/A4988 + plant robot + kịch bản", "M2", 6, "WI-017", "SIM-20"),
 ("ToolForge: tool.need/search/write/test/run/register/repair (+ G-TOOL)", "M1", 4, "WI-003, WI-004, WI-009", "CDS-12 tập 3 tool.*"),
 ("Plugin GEditor: RpcClient sinh từ openrpc + ChatPanel + AutonomyBar + QueuePanel", "M1", 6, "WI-010", "GPI-23, UXD-13"),
 ("Plugin GEditor: KnowledgeMap/RagAsk/ReqArch/DiagramView/Doc/Discovery/ToolForge panels", "M2", 8, "WI-021", "UXD-13"),
 ("Plugin GEditor: LogAssist/Debug/Sim panels + providers", "M3", 5, "WI-022", "UXD-13, GPI-23"),
 ("Registry lớp: index.json, pack/sign/publish/pull, template K5′ balancing-robot", "M4", 4, "WI-003", "PKG-22"),
 ("Installer + daemon launchd/systemd + CI (test/contract/dialog/hil/release/docs)", "M2", 3, "WI-010", "DEP-26"),
 ("Bộ benchmark 20 tác vụ + firmware kiểm định + runner board", "M2", 4, "WI-017", "BEN-21"),
]:
    add("Hạ tầng", t, ms, "M", d, dep, "AI làm/người duyệt" if "Plugin" not in t else "AI làm/người duyệt (Swift)", ref)
# Năng lực (mỗi năng lực chưa có M0 = 1 việc)
EST = {"R0": 0.5, "R1": 0.75, "R2": 1.0, "R3": 1.0, "R4": 0.75}
for c in caps:
    if "có" in c["m0"] and "một phần" not in c["m0"]: continue
    d = EST[c["risk"][:2]] * (1.5 if c["ns"] in ("extract", "sim", "discover", "diagram", "doc", "arch") else 1.0)
    who = "AI làm" if c["tier"] == "T1" else "AI làm/người duyệt"
    add("Năng lực", f"{c['code']} {c['name']} — {c['desc'][:70]}", c["ms"].split("–")[0] if "–" in c["ms"] else c["ms"], "M" if c["ms"] in ("M0", "M1", "M2") else "S", d, "WI-003", who, f"CDS-12 tập {cds[c['name']]['volume']}", c["name"])
# Tài liệu còn lại
for t, ms, d, ref in [("Cập nhật URD/SRS/SAD/SDD/STP/BPD/KAD/APD v1.2 (tool.*, tham chiếu tài liệu mới)", "M1", 1, "Bộ v1.2"), ("Cập nhật Danh mục v1.2 và Use case v1.2 khi thêm năng lực", "M1", 0.5, "PLN-27"), ("Sinh lại tài liệu tự động trong CI (docs job)", "M2", 1, "DEP-26 §5"), ("Chương thực nghiệm đề án từ benchmark và ma trận Người–AI", "M3", 3, "BEN-21, report.human_ai_matrix")]:
    add("Tài liệu", t, ms, "S", d, "", "AI làm/người duyệt", ref)
# Test
for t, ms, d, ref in [("TC-01…08 bất biến + TC-66 registry + TC-51…57 tự chủ", "M1", 2, "STP-05, POL-17"), ("TC-59…65 hội thoại (L2b) + Z-01…Z-10 + 50 câu lệnh", "M1", 2, "DPS-09, PRS-16"), ("TC-CX/TC-MM/TC-SE/TC-DD", "M1", 2, "CXD, MEM, SEC, DDD"), ("TC hợp đồng sinh tự động cho 238 năng lực", "M1", 1.5, "STP-05 §1"), ("TC-67…82 kỹ nghệ/tri thức/dò board + TC-TG/TC-SM (L3 trên Nucleo/Uno)", "M2", 4, "STP-05, TGT-19, SIM-20"), ("TC-UX-01…08 + TC-DP + kịch bản chuẩn ≤ 5 bấm (TC-58)", "M2", 2, "UXD-13, DEP-26"), ("TC-TL-01…03 công cụ tự tạo", "M1", 1, "CDS tool.*")]:
    add("Kiểm thử", t, ms, "M", d, "", "AI làm/người duyệt", ref)
# Người
for t, ms, d, ref in [("Ký danh sách trắng (nguồn, gói, board lab) và đặt autonomy.yaml ban đầu", "M1", 0.5, "POL-17 §3"), ("Xác nhận mã màu PTIT chính thức và ngôn ngữ lược đồ GEditor hỗ trợ", "M1", 0.5, "UXD-13, GPI-23"), ("Chốt API plugin GEditor còn thiếu (GP-01…12)", "M2", 2, "GPI-23 §6"), ("Đo tham số vật lý robot (khối lượng, tâm khối) thay nhãn tạm", "M2", 0.5, "SIM-20 §4"), ("Duyệt tool.promote và pack đầu tiên; ý kiến pháp lý license registry công khai", "M4", 1, "PKG-22")]:
    add("Người", t, ms, "M", d, "", "Người", ref)

H = ["Mã việc", "Loại", "Việc", "Mốc", "Ưu tiên", "Ước lượng (ngày)", "Phụ thuộc", "Ai làm", "Tài liệu tham chiếu", "Năng lực", "Trạng thái"]
ws2 = sheet("2. Backlog", H, rows, [9, 10, 70, 7, 8, 10, 16, 20, 24, 22, 10], "C2", "Backlog")
dv = DataValidation(type="list", formula1='"Chưa,Đang,Xong,Bỏ"', allow_blank=True); ws2.add_data_validation(dv); dv.add(f"K2:K{len(rows) + 1}")

# ---- Sheet 1 Mốc (công thức)
MS = [
 ("M0", "Khung: schema, store, KG, SVD/ATDF, gateway, CLI — ĐÃ XONG (hkw-core)", "24 test đạt; 640 chip seed; 100/100 truy vấn"),
 ("M1", "Lõi tác tử: registry năng lực, chính sách, orchestrator, ngữ cảnh, bộ nhớ, tool.*, extract PDF/ảnh/zip, RAG, plugin chat cơ bản, prompt", "Kịch bản Z-01…Z-10 chạy; ≤ 5 bấm với sim; TC M1 đạt"),
 ("M2", "Mạch, kiến trúc, mã/merge tự động, lược đồ, tài liệu, dò board, target, sim, benchmark, installer, panel còn lại", "Kịch bản chuẩn 17 bước đầu-cuối trên Nucleo + Uno với 2 mô hình; tài liệu SRS/SAD sinh tự động"),
 ("M3", "Quan sát: log lớn, probe, debug, sync lược đồ/tài liệu, measure", "Kịch bản C log ≥ 1 GB; HardFault chẩn đoán đúng ≥ 80%"),
 ("M4", "Registry lớp, template, gói công cụ, ký, publish", "≥ 500 gói hạt giống + 20 kiểm định; tool.promote hoạt động"),
 ("M5", "Mở rộng: PIC, chế độ cục bộ, đa người dùng, sigrok, Windows/Linux UI", "Theo nhu cầu"),
]
ws1 = wb.create_sheet("1. Mốc", 1); ws1.append(["Mốc", "Phạm vi", "Tiêu chí xong", "Số việc", "Ngày ước lượng", "Đã xong", "Tiến độ"])
for c in ws1[1]: c.font = HF; c.fill = PatternFill("solid", fgColor=RED); c.border = BORDER
B = "'2. Backlog'!"
for i, (m, s, d) in enumerate(MS, 2):
    ws1.append([m, s, d, f'=COUNTIF({B}D:D,"{m}")', f'=SUMIF({B}D:D,"{m}",{B}F:F)', f'=COUNTIFS({B}D:D,"{m}",{B}K:K,"Xong")', f'=IF(D{i}=0,0,F{i}/D{i})'])
    for c in ws1[i]: c.font = BODY; c.alignment = WRAP; c.border = BORDER
    ws1.cell(row=i, column=7).number_format = "0%"
for col, w in zip("ABCDEFG", [7, 70, 50, 9, 12, 9, 9]): ws1.column_dimensions[col].width = w

# ---- Sheet 3 Truy vết hợp nhất
UR2NS = {"TT": ["archive", "search", "extract", "passport", "kg"], "MC": ["board"], "MA": ["plan", "code", "memory"], "XM": ["sim", "target", "measure", "bench"], "GL": ["debug"], "QS": ["view", "debug"], "MH": ["memory", "policy"], "RG": ["registry"], "QT": ["policy", "env", "project"], "HT": ["bench", "report"], "NL": ["chat", "policy", "memory", "tool"], "KN": ["req", "arch", "diagram", "doc"], "TQ": ["view", "kg"], "DT": ["discover", "target"]}
SCREEN = {"archive": "Ingest", "search": "Ingest", "extract": "Ingest/Passport", "passport": "Passport", "kg": "RagAsk/ReviewQueue", "board": "Board", "plan": "PlanDiff", "code": "Code/PlanDiff", "memory": "Chat", "sim": "Sim", "target": "Discovery/Debug", "measure": "Debug", "bench": "Bench", "debug": "LogAssist/Debug", "view": "RagAsk", "policy": "ReviewQueue/Main", "registry": "Registry", "env": "Env", "project": "Main", "report": "Doc", "chat": "Chat", "tool": "ToolForge", "req": "ReqArch", "arch": "ReqArch", "diagram": "DiagramView", "doc": "Doc", "discover": "Discovery"}
TC = {"archive": "TC-11, TC-SE-02", "search": "TC-07, S01…S07", "extract": "TC-09, TC-10, TC-12, TC-22", "passport": "TC-15, TC-16, TC-18", "kg": "TC-13, TC-17, S09…S17", "board": "TC-20, TC-21", "plan": "TC-26, S18…S22", "code": "TC-04, TC-31, S23…S28", "memory": "TC-MM-01…09, TC-CX-01…08", "sim": "TC-34, TC-SM-01…06", "target": "TC-32, TC-33, TC-36, TC-TG-05", "measure": "TC-06 (F)", "bench": "TC-47", "debug": "TC-37, TC-38", "view": "TC-78, TC-79", "policy": "TC-51…57", "registry": "TC-41…43, TC-PK", "env": "TC-46, TC-TG-02", "project": "TC-60, TC-45", "report": "TC-75", "chat": "TC-59…64", "tool": "TC-TL-01…03, S41…S45", "req": "TC-67, TC-68", "arch": "TC-69, TC-70", "diagram": "TC-71…74", "doc": "TC-75…77", "discover": "TC-80…82, TC-TG-03/04"}
rows3 = []
for ur, nss in UR2NS.items():
    for ns in nss:
        rows3.append([f"UR-{ur}-*", ns, f"FR-{ns.upper()}-01…{sum(1 for c in caps if c['ns'] == ns):02d}", f"CDS-12 tập {cds[next(c['name'] for c in caps if c['ns'] == ns)]['volume']}; SDD-04 §4", TC[ns], SCREEN[ns]])
sheet("3. Truy vết hợp nhất", ["Nhóm UR", "Nhóm năng lực", "FR (năng lực)", "Thiết kế", "Test case", "Màn hình"], rows3, [12, 14, 22, 26, 30, 22], "C2", "TruyVet")

# ---- Sheet 4 Phân công Người–AI
rows4 = [
 ["Thiết kế và quyết định kiến trúc", "Người (chủ sản phẩm) + AI đề xuất", "ADR, danh sách trắng, ngưỡng chính sách, mức tự chủ"],
 ["Viết mã năng lực T1 (R0/R1)", "AI làm (coder) — người review theo mẫu", "Test hợp đồng sinh tự động; reviewer AI khác hãng"],
 ["Viết mã hạ tầng (Router, PolicyGate, Orchestrator, Sandbox)", "AI viết / người duyệt kỹ", "Bất biến an toàn phải có test cưỡng chế"],
 ["Plugin Swift", "AI viết / người duyệt + chạy trên GEditor thật", "Mã RPC sinh từ openrpc"],
 ["Prompt và skill", "AI dự thảo / người duyệt + benchmark", "PRS-16 §8"],
 ["Kiểm phần cứng (L3), đo tham số, board lab", "Người", "Runner có board; ký danh sách trắng"],
 ["Tài liệu", "AI sinh từ mô hình / người duyệt", "docs job trong CI"],
 ["Pháp lý license registry công khai", "Người", "PKG-22"],
]
sheet("4. Phân công Người–AI", ["Loại việc", "Ai làm", "Ghi chú"], rows4, [40, 40, 50], "B2", "PhanCong")

# ---- Sheet 5 Thống kê
ws5 = wb.create_sheet("5. Thống kê")
ws5["A1"] = "THỐNG KÊ BACKLOG (công thức)"; ws5["A1"].font = Font(bold=True, size=12, color=RED, name="Arial")
ws5["A3"] = "Tổng việc"; ws5["B3"] = f"=COUNTA({B}A:A)-1"
ws5["A4"] = "Tổng ngày ước lượng"; ws5["B4"] = f"=SUM({B}F:F)"
ws5["A5"] = "Đã xong"; ws5["B5"] = f'=COUNTIF({B}K:K,"Xong")'
ws5["A6"] = "Tiến độ"; ws5["B6"] = "=B5/B3"; ws5["B6"].number_format = "0.0%"
r = 8
for h in ["Theo loại", "Theo ai làm"]:
    ws5.cell(row=r, column=1, value=h).font = Font(bold=True, name="Arial", size=10, color="FFFFFF"); ws5.cell(row=r, column=1).fill = PatternFill("solid", fgColor=SLATE); r += 1
    col = "B" if h == "Theo loại" else "H"
    for v in (["Hạ tầng", "Năng lực", "Tài liệu", "Kiểm thử", "Người"] if col == "B" else ["AI làm", "AI làm/người duyệt", "AI làm/người duyệt (Swift)", "Người"]):
        ws5.cell(row=r, column=1, value=v); ws5.cell(row=r, column=2, value=f'=COUNTIF({B}{col}:{col},"{v}")'); ws5.cell(row=r, column=3, value=f'=SUMIF({B}{col}:{col},"{v}",{B}F:F)'); r += 1
    r += 1
ws5.column_dimensions["A"].width = 32; ws5.column_dimensions["B"].width = 10; ws5.column_dimensions["C"].width = 12
wb.save("EIDE-PLN-27_Ke_hoach_backlog.xlsx"); print("items", len(rows))
