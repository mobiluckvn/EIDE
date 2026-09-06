#!/usr/bin/env python3
"""Sinh bảng §5.3 của `docs/trang-thai.md` — tiến độ theo Phase.

VÌ SAO CÓ TỆP NÀY. `trang-thai.md` §5.3 tự nói rằng bảng ấy "SINH bằng máy từ chính tệp SRS,
không gõ tay". Câu ấy đúng vào ngày nó được viết, nhưng KHÔNG có script nào trong kho làm việc
đó — nên từ đó bảng được sửa tay, và nó trôi: hôm nay cột ✅ cộng lại ra **112** trong khi bảng
nhóm ở §5.2 cộng ra **117**. Năm mã chênh nhau ấy đã nằm im ở đó nhiều phiên.

Đây đúng là loại lỗi mà chính tài liệu ấy cảnh báo ở §5.3: *"đếm tay đã từng cho ra 87 khi con
số thật là 101"*. Một bảng đúng từng dòng vẫn cho ấn tượng sai nếu tổng của nó sai.

CÁCH LÀM. Phase lấy từ SRS (nguồn duy nhất). Trạng thái suy từ DANH SÁCH NGOẠI LỆ bên dưới —
tức là "mọi mã đều xong, TRỪ những mã kê tên ở đây". Kê ngoại lệ thay vì kê thành tựu là có chủ
ý: danh sách ngoại lệ ngắn, đọc được, và khi một mã được làm xong thì việc phải làm là XOÁ một
dòng — thao tác khó quên hơn là thêm một dòng vào một danh sách dài trăm mã.

    python3 scripts/phase-table.py            in bảng Markdown
    python3 scripts/phase-table.py --kiem     chỉ đối chiếu với trang-thai.md, mã thoát 1 nếu lệch
"""
import os
import re
import sys
import zipfile

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRS = os.path.join(
    ROOT, "docs", "GEditor_BoTaiLieu_DuAn_v2.3", "01_SRS_GEditor_macOS_v2.2.docx")
STATUS = os.path.join(ROOT, "docs", "trang-thai.md")

# Mã CHƯA có mã nguồn. Mọi mã không nằm trong đây được coi là ✅.
CHUA_LAM = {
    # Vướng quyết định phạm vi, không vướng mã.
    "FR-DOC-305",           # macOS Versions — hướng (B) cần di cư NSDocument, 413 điểm chạm
}
# Cả cụm chưa chạm.
CUM_CHUA_LAM = {"FR-KNW", "FR-AGT", "FR-PY"}

# Ngoại lệ NGƯỢC: mã đã có mã nguồn dù cụm của nó còn nằm trong CUM_CHUA_LAM.
#
# Có mặt vì cụm lớn được làm dần từng mã. Không có danh sách này thì chọn lựa duy nhất là gỡ cả
# cụm ra khỏi CUM_CHUA_LAM rồi liệt kê 25 mã còn lại — dài hơn, và mỗi mã làm xong lại phải xoá
# một dòng, tức đúng kiểu bảo trì mà bảng §5.3 sinh bằng máy để tránh.
DA_LAM = {
    "FR-KNW-901",           # Chế độ JSONL
    "FR-KNW-923",           # Entity Resolution pipeline
    "FR-KNW-916",           # Tái cấu trúc đồ thị (đổi tên · gộp · tách · trích)
    "FR-KNW-921",           # Nhập & so sánh điểm retrieval ngoài
    "FR-KNW-920",           # Liên kết Chunk ↔ Entity ↔ Graph
    "FR-KNW-924",           # Graph Quality Report
    "FR-KNW-925",           # Hybrid retrieval BM25 × đồ thị
    "FR-KNW-914",           # Thuật toán đồ thị
    "FR-KNW-913",           # Thực thi openCypher tập con
    "FR-KNW-926",           # Golden Set Builder
    "FR-KNW-907",           # Corpus SQL (JSONL/Parquet + thống kê corpus & đồ thị)
    "FR-KNW-906",           # Bảng triple/edge (N-Triples → bảng ba cột qua CSVEngine)
    "FR-KNW-917",           # Schema / Ontology validation (YAML rời, kiểm kiểu và quan hệ)
    "FR-KNW-903",           # Chunking Preview (cắt cố định / theo câu / theo heading + JSONL)
    "FR-KNW-910",           # Chuyển đổi tri thức (JSONL↔CSV↔MD, DOT↔Mermaid↔edge list)
    "FR-KNW-908",           # Đánh dấu entity (nạp CSV/JSON, tô theo loại, thống kê)
    "FR-KNW-912",           # API script jsonl.* và graph.*
    "FR-KNW-904",           # Grammar + thẩm định DOT/Cypher/Turtle/GraphML
    "FR-KNW-909",           # Prompt/tool: frontmatter gấp được, grammar Jinja2, JSON Schema
    "FR-KNW-905",           # Graph Preview
    "FR-KNW-918",           # BM25 Retrieval Lab
    "FR-KNW-919",           # Đánh giá golden set
    "FR-KNW-902",           # Chunk Inspector
    "FR-KNW-922",           # Chunk Quality Report
    "FR-KNW-915",           # Soạn thảo Graph trực quan (kéo · double-click · xoá)
}

# Mã bị một ADR THAY THẾ — cố ý không làm, và đó là một quyết định chứ không phải một khoảng nợ.
#
# Hạng này ra đời 28/08/2026 vì hai hạng cũ đều nói dối về `FR-KNW-911`:
#   · ✅ thì sai hẳn — không có mã nào làm việc ấy;
#   · ⛔ thì đúng chữ mà sai nghĩa — nó hàm ý "chưa làm, rồi sẽ làm", trong khi đây là "đã cân
#     nhắc, đã đo, và quyết định KHÔNG làm".
#
# Khác biệt ấy không phải chuyện chữ nghĩa: một mục ⛔ nằm mãi trong bảng sẽ được người sau đọc
# thành việc còn tồn, và có ngày ai đó đi làm nó — rồi phát hiện nó mâu thuẫn với một ADR đã
# chốt. Một hạng riêng nói thẳng ra điều đó, và bắt mỗi mục phải chỉ tên ADR đã thay nó.
THAY_THE = {
    "FR-KNW-911": "ADR-15 — Knowledge Pack nằm TRONG lõi; đặc tả đòi đóng gói thành plugin",
}

# Mã làm được MỘT PHẦN — đếm riêng, không tính là xong.
MOT_PHAN = {
    "FR-DOC-305": "hướng (A) duyệt và khôi phục bản đã lưu đã có; hướng (B) còn treo",
}
# FR-FMT-503 từng nằm ở `MOT_PHAN` đúng một ngày (28/08/2026): soát lại thì thấy đặc tả đòi BA
# thao tác — "Fold All / Unfold All / fold theo cấp" — mà vế thứ ba không có ở đâu cả. Nay đã
# có (`FoldRanges.ranges(atLevel:in:)` + submenu "Gấp theo cấp" ⌥⌘1…⌥⌘8), nên nó về lại ✅ và
# Phase 1 khép lại. Giữ ghi chú này vì bài học thì không hết hạn: mã ấy là mã ✅ DUY NHẤT không
# grep ra được ở bất kỳ đâu trong kho, và đúng nó là mã bị ghi quá.


def doc_text(path):
    with zipfile.ZipFile(path) as archive:
        xml = archive.read("word/document.xml").decode("utf8")
    paragraphs = re.findall(r"<w:p[ >].*?</w:p>", xml, re.S)
    return [
        "".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", p, re.S)).strip()
        for p in paragraphs
    ]


def requirements():
    """[(mã, ưu tiên, phase)] theo đúng thứ tự trong SRS."""
    lines = doc_text(SRS)
    out = []
    for index, line in enumerate(lines):
        match = re.fullmatch(r"(FR-[A-Z]+-\d+)", line)
        if not match:
            continue
        priority = phase = None
        # Ưu tiên rồi Phase là hai ô CUỐI của hàng; chúng đứng trong vòng vài đoạn sau mã.
        for probe in lines[index + 1: index + 7]:
            if re.fullmatch(r"P[0-2]\*?", probe):
                priority = probe
            elif priority and re.fullmatch(r"[1-6](–[1-6])?", probe):
                phase = probe
                break
        out.append((match.group(1), priority, phase))
    return out


def status_of(code):
    if code in THAY_THE:
        return "⊘"
    if code in MOT_PHAN:
        return "◐"
    if code in DA_LAM:
        return "✅"
    if code in CHUA_LAM or code.rsplit("-", 1)[0] in CUM_CHUA_LAM:
        return "⛔"
    return "✅"


def table():
    rows = {}
    order = []
    for code, _, phase in requirements():
        if phase not in rows:
            rows[phase] = {"✅": 0, "◐": 0, "⊘": 0, "⛔": 0}
            order.append(phase)
        rows[phase][status_of(code)] += 1

    # Thứ tự đọc được: theo số phase đầu tiên, rồi theo độ dài (`1` trước `1–2`).
    order.sort(key=lambda p: (int(p[0]), len(p)))
    lines = ["| Phase | ✅ | ◐ | ⊘ | ⛔ | Tổng |", "|---|---|---|---|---|---|"]
    for phase in order:
        counts = rows[phase]
        total = counts["✅"] + counts["◐"] + counts["⊘"] + counts["⛔"]
        # ⊘ KHÔNG cản một phase được coi là khép: nó là việc đã quyết định không làm.
        closed = counts["⛔"] == 0 and counts["◐"] == 0
        note = f"**{total} — khép**" if closed else str(total)
        done = f"**{counts['✅']}**" if counts["✅"] and not closed else str(counts["✅"])
        lines.append(
            f"| {phase} | {done} | {counts['◐']} | {counts['⊘']} | {counts['⛔']} | {note} |")
    return lines, rows


def priority_line():
    """Dòng "Theo ưu tiên" của §5.

    CÓ MẶT VÌ nó đã trôi đúng kiểu §5.3 từng trôi. Sáng 28/08/2026 dòng ấy còn ghi
    "P1 62/75 · P2 17/54" — số của hôm trước — trong khi dòng TỔNG ngay phía trên đã lên 132.
    Cổng cũ không bắt được vì nó chỉ soi bảng §5.3 và dòng tổng, nên dòng ưu tiên lặng lẽ quay
    về chế độ gõ tay. Sinh cả nó ở đây thì hai dòng không thể nói khác nhau nữa.
    """
    counts = {}
    for code, priority, _ in requirements():
        counts.setdefault(priority, {"✅": 0, "◐": 0, "⊘": 0, "⛔": 0})[status_of(code)] += 1

    parts = []
    for priority in sorted(counts):
        row = counts[priority]
        total = row["✅"] + row["◐"] + row["⛔"]
        # ⊘ ra khỏi MẪU SỐ: hỏi "bao nhiêu phần trăm việc CẦN LÀM đã xong" thì một mục đã
        # quyết định không làm không còn là việc cần làm nữa. Giữ nó trong mẫu số sẽ khiến tỷ lệ
        # không bao giờ chạm 100% dù không còn gì để viết.
        can_lam = total - row["⊘"]
        text = f"{priority} {row['✅']}/{can_lam} ({round(row['✅'] * 100 / max(can_lam, 1))}%)"
        # Bôi đậm nhóm đã trọn vẹn, và nhóm chỉ còn một vài mã — chúng là chỗ mắt cần dừng lại.
        parts.append(f"**{text}**" if row["✅"] + row["◐"] >= can_lam - 1 else text)
    return "Theo ưu tiên: " + " · ".join(parts) + "."


def main():
    lines, rows = table()
    done = sum(r["✅"] for r in rows.values())
    partial = sum(r["◐"] for r in rows.values())
    superseded = sum(r["⊘"] for r in rows.values())
    todo = sum(r["⛔"] for r in rows.values())
    total = done + partial + superseded + todo

    if "--kiem" in sys.argv:
        with open(STATUS, encoding="utf8") as handle:
            text = handle.read()
        problems = []
        for line in lines[2:]:
            if line not in text:
                problems.append(line)
        expected = (f"**Xong {done} · một phần {partial} · thay thế {superseded} · "
                    f"chưa có mã {todo}**")
        if expected not in text:
            problems.append(expected)
        if priority_line() not in text:
            problems.append(priority_line())
        if problems:
            print("❌ §5.3 lệch với SRS — dòng đúng phải là:", file=sys.stderr)
            for problem in problems:
                print("   " + problem, file=sys.stderr)
            return 1
        print(f"✅ §5.3 khớp SRS — {done} xong · {partial} một phần · {superseded} thay thế "
              f"· {todo} chưa có mã trên {total}")
        return 0

    print("\n".join(lines))
    print()
    print(f"**Xong {done} · một phần {partial} · thay thế {superseded} · "
          f"chưa có mã {todo}** — tổng {total}.")
    print()
    print(priority_line())
    return 0


if __name__ == "__main__":
    sys.exit(main())
