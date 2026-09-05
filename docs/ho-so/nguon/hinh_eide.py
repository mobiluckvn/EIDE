# -*- coding: utf-8 -*-
import json, matplotlib, textwrap
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from collections import Counter
plt.rcParams["font.family"] = "DejaVu Sans"
NAVY, RED, GOLD, SLATE, LIGHT, GREY = "#1F3864", "#B8121F", "#F2B705", "#2F4858", "#F2F6FB", "#7F7F7F"
caps = json.load(open("caps.json"))
cnt = Counter(c["ns"] for c in caps)

def box(ax, x, y, w, h, text, fc=LIGHT, ec=NAVY, fs=8.5, bold=False, tc="black", lw=1.2):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.15", fc=fc, ec=ec, lw=lw))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=fs, weight="bold" if bold else "normal", color=tc, wrap=True)

def arrow(ax, x1, y1, x2, y2, color=NAVY, ls="-", lw=1.3):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=12, color=color, lw=lw, linestyle=ls))

# ---------- Hình 1: kiến trúc năng lực ----------
fig, ax = plt.subplots(figsize=(12, 8.3)); ax.set_xlim(0, 12); ax.set_ylim(0, 8.3); ax.axis("off")
box(ax, 0.3, 7.35, 11.4, 0.75, "KỸ SƯ — ra lệnh bằng ngôn ngữ tự nhiên (chat là màn hình mặc định)\nxem kết quả ở màn hình hộ chiếu / bản đồ tri thức / mã / mô phỏng / log", fc="#FFF4D6", ec=GOLD, fs=8.8, bold=True)
box(ax, 0.3, 5.75, 11.4, 1.35, "", fc="#FDECEE", ec=RED)
ax.text(0.5, 6.95, "TÁC TỬ ĐIỀU PHỐI (Orchestrator) — bốn trách nhiệm", fontsize=9.5, weight="bold", color=RED)
for i, (t, s) in enumerate([("① Hiểu và đối chiếu", "chat.parse_intent · chat.ground\n(D1: cái người nói đã tồn tại chưa?)"),
                            ("② Lập chuỗi năng lực", "chat.orchestrate · plan.*\n(lệnh lớn → chuỗi gọi có nhánh)"),
                            ("③ Đủ thông tin? Mặc định trước", "chat.fill_defaults · chat.clarify\n(D2–D3: một câu hỏi gộp, có timeout)"),
                            ("④ Chính sách và báo cáo", "policy.decide · chat.report_back\n(APPROVE/ASK/REJECT,\nlàm rồi báo cáo)")]):
    box(ax, 0.5 + i * 2.82, 5.82, 2.65, 1.02, t + "\n" + s, fc="white", ec=RED, fs=7.1)
box(ax, 0.3, 4.95, 11.4, 0.65, "CAPABILITY REGISTRY — 238 năng lực, 27 nhóm\nmỗi năng lực là một hợp đồng {vào, ra, lớp rủi ro R0–R4, mức T1/T1*/T2/T3, grounding, hỏi khi, hoàn tác}", fc=NAVY, ec=NAVY, fs=8.2, bold=True, tc="white")
rows = [
    ("Kỹ nghệ", ["req", "arch", "diagram", "doc", "plan"], "#E8F0FE"),
    ("Tri thức", ["archive", "search", "extract", "passport", "kg", "board", "view", "memory"], "#E6F4EA"),
    ("Hiện thực\n& xác minh", ["env", "code", "sim", "discover", "target", "debug", "measure", "bench"], "#FFF4D6"),
    ("Quản trị", ["project", "policy", "registry", "report", "chat"], "#F3E8FD"),
    ("Gốc", ["tool"], "#FFE5E5"),
]
y = 4.2
for title, nss, fc in rows:
    box(ax, 0.3, y - 0.05, 1.6, 0.7, title, fc=fc, ec=SLATE, fs=8.5, bold=True)
    x = 2.05; w = (11.7 - 2.05) / len(nss) - 0.08
    for ns in nss:
        box(ax, x, y, w, 0.6, f"{ns}\n({cnt[ns]})", fc="white", ec=SLATE, fs=7.8)
        x += w + 0.08
    y -= 0.85
box(ax, 0.3, 0.15, 11.4, 0.8, "KNOWLEDGE PLANE\nPassport Store · Knowledge Graph · Ledger · PolicyGate/Undo · LLM Gateway (Claude/Gemini/OpenAI-compatible)\nTarget/Discovery adapters · GEditor plugin (JSON-RPC) · MCP server/client", fc=LIGHT, ec=NAVY, fs=8, bold=True)
arrow(ax, 6, 7.35, 6, 7.12); arrow(ax, 6, 5.75, 6, 5.57); arrow(ax, 6, 5.0, 6, 4.82); arrow(ax, 6, 0.95, 6, 0.82)
ax.text(11.65, 4.86, "gọi theo hợp đồng", fontsize=7, color=GREY, ha="right")
fig.savefig("hinh/eide_caps_arch.png", dpi=200, bbox_inches="tight"); plt.close(fig)

# ---------- Hình 2: vòng lệnh ngôn ngữ tự nhiên ----------
fig, ax = plt.subplots(figsize=(12, 6.2)); ax.set_xlim(0, 12); ax.set_ylim(0, 6.2); ax.axis("off")
steps = [("Lệnh ngôn ngữ tự nhiên", "\"Tạo dự án robot hai bánh tự cân bằng\"", "#FFF4D6", GOLD),
         ("1. Hiểu lệnh", "chat.parse_intent: ý định + tham số (slot); nhận diện lệnh lớn", "white", NAVY),
         ("2. Đối chiếu trạng thái (D1)", "chat.ground: dự án / hộ chiếu / board / mẫu tham chiếu đã tồn tại chưa?", "white", NAVY),
         ("3. Điền mặc định (D2)", "chat.fill_defaults: mức A3, mô hình, tên, đường dẫn; ghi ledger", "white", NAVY),
         ("4. Hỏi gộp nếu cần (D3)", "chat.clarify: một câu, phương án đánh số, mặc định, timeout", "#FDECEE", RED),
         ("5. Nói lại ý hiểu (D6)", "chat.restate: 1–2 câu rồi làm; người sửa bất cứ lúc nào", "white", NAVY),
         ("6. Chuỗi năng lực", "chat.orchestrate: project.create → search.reference_projects → req.elicit → arch.* → …", "white", NAVY),
         ("7. Chính sách (D7)", "policy.decide theo lớp rủi ro và mức tự chủ: APPROVE / ASK / REJECT; làm rồi báo cáo", "#FDECEE", RED),
         ("8. Báo cáo và ghi nhớ (D8)", "chat.report_back: đã làm · chờ anh · hoàn tác được · chi phí; memory.* lưu lựa chọn", "#E6F4EA", "#2E7D32")]
w, h, gx, gy = 3.6, 1.15, 0.35, 0.3
for i, (t, s, fc, ec) in enumerate(steps):
    r, cidx = divmod(i, 3); x = 0.3 + cidx * (w + gx); y = 4.75 - r * (h + gy)
    box(ax, x, y, w, h, t + "\n" + textwrap.fill(s, 48), fc=fc, ec=ec, fs=7.6)
    if cidx < 2: arrow(ax, x + w, y + h / 2, x + w + gx, y + h / 2)
    elif r < 2: arrow(ax, x + w, y + h / 2, x + w + 0.15, y + h / 2); ax.plot([x + w + 0.15, x + w + 0.15, 0.15, 0.15, 0.3], [y + h / 2, y - gy / 2, y - gy / 2, y - gy - h / 2, y - gy - h / 2], color=NAVY, lw=1.2)
box(ax, 0.3, 0.3, 11.5, 0.95, "Hai chế độ của một năng lực: người bấm trên giao diện (UI gọi năng lực) hoặc tác tử gọi trong chuỗi\n(Orchestrator gọi năng lực) — cùng một hợp đồng, cùng một chính sách, cùng một nhật ký", fc=LIGHT, ec=NAVY, fs=8.6, bold=True)
fig.savefig("hinh/eide_nl_loop.png", dpi=200, bbox_inches="tight"); plt.close(fig)

# ---------- Hình 3: phân bố năng lực ----------
fig, ax = plt.subplots(figsize=(11, 4.2))
ns = [n for n in ["project","memory","archive","search","extract","passport","kg","board","env","plan","code","sim","target","debug","measure","bench","registry","report","policy","chat","req","arch","diagram","doc","view","discover","tool"]]
new = {"req","arch","diagram","doc","view","discover"}
vals = [cnt[n] for n in ns]
cols = ["#F2B705" if n == "tool" else RED if n in new else NAVY for n in ns]
ax.bar(ns, vals, color=cols)
for i, v in enumerate(vals): ax.text(i, v + 0.3, str(v), ha="center", fontsize=8)
ax.set_ylabel("Số năng lực"); ax.set_title("238 năng lực theo 27 nhóm (đỏ: bổ sung v1.1; vàng: tool.* gốc v1.2)", fontsize=10, weight="bold", color=NAVY)
ax.spines[["top", "right"]].set_visible(False); plt.xticks(rotation=45, ha="right", fontsize=8)
fig.savefig("hinh/eide_caps_dist.png", dpi=200, bbox_inches="tight"); plt.close(fig)
print("ok")
