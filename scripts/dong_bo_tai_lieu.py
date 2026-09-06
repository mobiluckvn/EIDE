#!/usr/bin/env python3
"""Gom DEVIATIONS thành bản nháp cập nhật tài liệu — bước 1-2 của `/dong-bo-tai-lieu`.

Quy trình (CLAUDE.md §"Đồng bộ tài liệu", DEV-29 §4): cuối mỗi sprint hoặc khi có ≥ 5 mục
`Mở`, gom các mục theo TÀI LIỆU bị ảnh hưởng thành `docs/sync/<ngày>-<DOC>.md` để chủ sản
phẩm duyệt. Script này KHÔNG sửa docx và KHÔNG sửa `docs/spec/` — đó là bước sau, và nó đi
qua `scripts/sinh_tai_lieu.sh` sau khi có người duyệt.

Viết thành script chứ không làm tay vì bản nháp phải sinh LẠI ĐƯỢC: mỗi lần rà là một ảnh
chụp của DEVIATIONS tại thời điểm đó, và hai người chạy phải ra cùng một kết quả.

    python scripts/dong_bo_tai_lieu.py            sinh bản nháp vào docs/sync/
    python scripts/dong_bo_tai_lieu.py --tom-tat  chỉ in tóm tắt, không ghi tệp
"""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Mã tài liệu → tệp nguồn sinh phải sửa. Có tệp thì bản nháp chỉ ra đúng chỗ; không có thì
# nói rõ là chưa biết, thay vì đoán.
NGUON = {
    "PDA": "pda.js", "URD": "urd.js", "SRS": "srs.js", "SAD": "sad.js", "SDD": "sdd.js",
    "STP": "stp.js", "BPD": "bpd.js", "KAD": "kad.js", "APD": "apd.js", "DPS": "dps.js",
    "CXD": "cxd.js", "MEM": "mem.js", "CDS": "cds.js + cds_data_*.py", "UXD": "uxd.js",
    "DDD": "ddd.js + ddd_model.py", "API": "api.js", "PRS": "prs.js", "POL": "pol.js",
    "TGT": "tgt_sim.js", "SIM": "tgt_sim.js", "BEN": "ben_pkg_gpi.js",
    "PKG": "ben_pkg_gpi.js", "GPI": "ben_pkg_gpi.js", "SEC": "sec_dep_con.js",
    "DEP": "sec_dep_con.js", "CON": "sec_dep_con.js", "DEV": "dev.js",
    "PLN": "excel/build_plan.py",
}
# Mục nhắm vào tệp trong kho chứ không vào tài liệu — không cần bản nháp đồng bộ.
KHONG_PHAI_TAI_LIEU = {"PLATFORM.md", "CLAUDE.md"}


def doc_deviations() -> list[dict]:
    t = (ROOT / "docs" / "DEVIATIONS.md").read_text(encoding="utf-8")
    ra = []
    for dong in t.splitlines():
        if not dong.startswith("| DEV-"):
            continue
        c = [x.strip() for x in dong.strip("|").split("|")]
        if len(c) < 8:
            continue
        ra.append({"ma": c[0], "ngay": c[1], "tai_lieu": c[2], "ma_nguon": c[3],
                   "sai_khac": c[4], "ly_do": c[5], "de_xuat": c[6], "trang_thai": c[7]})
    return ra


def ma_tai_lieu(s: str) -> list[str]:
    """Rút mã tài liệu từ cột "Tài liệu / mục". Một mục có thể chạm nhiều tài liệu."""
    ra = []
    for m in re.findall(r"\b([A-Z]{3})-\d{2}\b", s):
        if m in NGUON and m not in ra:
            ra.append(m)
    if not ra:
        for k in KHONG_PHAI_TAI_LIEU:
            if k in s:
                return ["(kho mã)"]
    return ra or ["(chưa rõ)"]


def main() -> int:
    chi_tom_tat = "--tom-tat" in sys.argv
    muc = [d for d in doc_deviations() if d["trang_thai"] in ("Mở", "Đã duyệt")]
    nhom: dict[str, list[dict]] = defaultdict(list)
    for d in muc:
        for m in ma_tai_lieu(d["tai_lieu"]):
            nhom[m].append(d)

    ngay = datetime.now(UTC).date().isoformat()
    thu_muc = ROOT / "docs" / "sync"
    if not chi_tom_tat:
        thu_muc.mkdir(parents=True, exist_ok=True)

    for doc, ds in sorted(nhom.items()):
        if doc.startswith("("):
            continue
        p = thu_muc / f"{ngay}-{doc}.md"
        dong = [
            f"# Đồng bộ tài liệu {doc} — bản nháp {ngay}",
            "",
            f"Nguồn sinh phải sửa: `docs/ho-so/nguon/{NGUON.get(doc, '?')}`  ·  phiên bản đích: **v1.3**",
            "",
            "Bản nháp này do `scripts/dong_bo_tai_lieu.py` sinh từ `docs/DEVIATIONS.md`. "
            "Nó **không** sửa docx và **không** sửa `docs/spec/`. Sau khi chủ sản phẩm duyệt: "
            "sửa nguồn sinh → `scripts/sinh_tai_lieu.sh "
            f"{NGUON.get(doc, '?').split('.')[0].split(' ')[0]}` → đổi trạng thái mục thành "
            "`Đã cập nhật tài liệu v1.3`.",
            "",
        ]
        for d in sorted(ds, key=lambda x: x["ma"]):
            dong += [
                f"## {d['ma']} — {d['trang_thai']}",
                "",
                f"**Mục bị ảnh hưởng:** {d['tai_lieu']}",
                "",
                f"**Hiện tại (điều mã buộc phải khác):** {d['sai_khac']}",
                "",
                f"**Vì sao:** {d['ly_do']}",
                "",
                f"**Nội dung đề xuất cho v1.3:** {d['de_xuat']}",
                "",
                f"**Mã liên quan:** {d['ma_nguon']}",
                "",
                "---",
                "",
            ]
        if not chi_tom_tat:
            p.write_text("\n".join(dong), encoding="utf-8")

    # Bước 4: tóm tắt, và nêu rõ mục nào cần NGƯỜI quyết
    print(f"Đồng bộ tài liệu {ngay} — {len(muc)} mục ({sum(1 for d in muc if d['trang_thai'] == 'Mở')} Mở)")
    for doc, ds in sorted(nhom.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        ma_ds = ", ".join(sorted(d["ma"] for d in ds))
        print(f"  {doc:10} {len(ds):2}  {ma_ds}")
    can_nguoi = [d for d in muc if d["trang_thai"] == "Mở"
                 and re.search(r"chủ sản phẩm|cần người|người quyết|quyền của", d["de_xuat"], re.I)]
    if can_nguoi:
        print("\nCần quyết định của người:")
        for d in can_nguoi:
            print(f"  {d['ma']}: {d['de_xuat'][:100]}")
    if not chi_tom_tat:
        print(f"\nBản nháp: docs/sync/{ngay}-*.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
