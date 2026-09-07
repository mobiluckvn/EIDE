#!/usr/bin/env python3
"""Báo cáo chỗ ĐỨT của năm chuỗi chuẩn Z-01/Z-05/Z-07/Z-10/P7.

    scripts/kiem_chuoi_chuan.py [--json]

Suy từ `docs/spec/dialog/chains.json` cộng registry, KHÔNG chép tay danh sách bước. Chép tay
thì báo cáo này đúng đúng một ngày: mỗi lần hiện thực thêm một năng lực là một lần phải nhớ sửa
hai chỗ, và chỗ thứ hai sẽ quên.

Mục 1 trong "định nghĩa xong" của SPRINT-02 nói chuỗi Z-01…Z-10 phải chạy qua Orchestrator. Câu
hỏi thực dụng là *chuỗi nào còn thiếu gì* — và câu trả lời phải là số đo, không phải suy luận.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

GOC = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GOC / "src"))

from eide_core.paths import spec_dir  # noqa: E402
from eide_core.registry import get_registry  # noqa: E402

# Một "bước" trong chains.json là văn xuôi, không phải id năng lực: `arch.style_select/decompose`
# gộp ba, `[template? registry.pull : req.elicit]` là rẽ nhánh, `extract.*` là cả nhóm. Rút id
# bằng biểu thức và đối chiếu với registry — bước nào không rút được id nào thì nói rõ là vậy,
# đừng lặng lẽ coi như đã xong.
RE_CAP = re.compile(r"\b([a-z_]+)\.([a-z_]+|\*)\b")


def cac_id(buoc: str, moi_id: set[str]) -> list[str]:
    """Id năng lực trong một bước. `ns.*` giãn thành mọi năng lực của namespace."""
    ra: list[str] = []
    for ns, ten in RE_CAP.findall(buoc):
        if ten == "*":
            ra += sorted(x for x in moi_id if x.startswith(ns + "."))
        elif f"{ns}.{ten}" in moi_id:
            ra.append(f"{ns}.{ten}")
        else:
            ra.append(f"{ns}.{ten}")          # giữ lại để báo "không có trong spec"
    # `arch.style_select/decompose/map_hw` — hai tên sau không có tiền tố namespace.
    if (m := re.match(r"^([a-z_]+)\.([a-z_]+)((?:/[a-z_]+)+)", buoc)):
        ra += [f"{m.group(1)}.{x}" for x in m.group(3).lstrip("/").split("/")]
    return list(dict.fromkeys(ra))


def main() -> int:
    reg = get_registry()
    moi = {c.spec.id: c for c in reg.list()}
    chains = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))

    bao = []
    for ch in chains:
        buoc_ra = []
        for b in ch["buoc"]:
            ids = cac_id(b, set(moi))
            thieu = [i for i in ids if i not in moi or not moi[i].implemented]
            la = [i for i in ids if i not in moi]
            buoc_ra.append({"buoc": b, "caps": ids, "thieu": thieu, "ngoai_spec": la,
                            "xong": bool(ids) and not thieu})
        n_xong = sum(1 for x in buoc_ra if x["xong"])
        dut = next((x for x in buoc_ra if not x["xong"]), None)
        bao.append({"ten": ch["ten"], "tong": len(buoc_ra), "xong": n_xong,
                    "dut_tai": dut["buoc"] if dut else None,
                    "thieu_dau_tien": dut["thieu"] if dut else [],
                    "buoc": buoc_ra})

    if "--json" in sys.argv:
        print(json.dumps(bao, ensure_ascii=False, indent=2))
        return 0

    print("Năm chuỗi chuẩn — chỗ đứt hiện tại\n")
    for c in bao:
        vach = "█" * c["xong"] + "░" * (c["tong"] - c["xong"])
        print(f"  {c['ten']}")
        print(f"    {vach}  {c['xong']}/{c['tong']} bước đủ năng lực")
        if c["dut_tai"]:
            print(f"    đứt tại: {c['dut_tai']}")
            print(f"    thiếu:   {', '.join(c['thieu_dau_tien']) or '(bước không nêu năng lực nào)'}")
        else:
            print("    ✓ mọi bước đã có năng lực")
        print()

    can = sorted({i for c in bao for b in c["buoc"] for i in b["thieu"]})
    theo_ns: dict[str, list[str]] = {}
    for i in can:
        theo_ns.setdefault(i.split(".")[0], []).append(i)
    print(f"Tổng cộng {len(can)} năng lực còn thiếu để năm chuỗi chạy đủ:")
    for ns, ds in sorted(theo_ns.items(), key=lambda kv: -len(kv[1])):
        moc = {moi[i].spec.milestone for i in ds if i in moi} or {"?"}
        print(f"  {ns:<10} {len(ds):>2}  (mốc {'/'.join(sorted(moc))})  {', '.join(x.split('.')[1] for x in ds)}")

    ngoai = sorted({i for c in bao for b in c["buoc"] for i in b["ngoai_spec"]})
    if ngoai:
        print(f"\n⚠ {len(ngoai)} tên trong chains.json KHÔNG có trong danh mục 238 năng lực:")
        for i in ngoai:
            print(f"  {i}")
        print("  (chuỗi tham chiếu một năng lực không tồn tại — cần một mục DEVIATIONS)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
