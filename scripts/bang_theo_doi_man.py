#!/usr/bin/env python3
"""Sinh `docs/BANG-THEO-DOI-MAN.md` — bảng theo dõi 25 màn của UXC-31 §11.1.

§11.1 đòi "một dòng trong bảng theo dõi: mã màn, commit, ngày, người/tác tử làm" cho mỗi màn.
Bảng ấy **không được chép tay**. Một bảng chép tay đứng yên trong khi mã đi tiếp, và nó đứng yên
im lặng: dòng vẫn đọc trôi chảy, chỉ là commit nó ghi đã cũ ba tuần và màn ấy đã đổi hai lần.

Nguồn sự thật là MÃ và GIT, không phải trí nhớ:

- danh mục màn → `EideManHinhDS.swift` (`ma`, `tien`, `nhan`, `canBoard`);
- màn đã nối dữ liệu → `EidePhien.MAN`;
- tệp của mỗi màn → lớp nào khai `class var tien { "<tiền tố>" }`;
- commit/ngày/người → `git log -1` trên chính tệp ấy.

`--kiem` so bản sinh với tệp đang có và trả mã thoát khác 0 nếu lệch — để CI bắt được lúc ai đó
sửa màn mà quên sinh lại bảng.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

GOC = Path(__file__).resolve().parents[1]
NGUON = GOC / "apps/eide/Sources/EideGiaoDien"
DICH = GOC / "docs/BANG-THEO-DOI-MAN.md"


def doc_danh_muc() -> list[dict[str, str | bool]]:
    """25 màn, đúng thứ tự khai trong `EideManHinhDS`."""
    van = (NGUON / "EideManHinhDS.swift").read_text(encoding="utf-8")
    mau = re.compile(
        r'\.init\(ma:\s*"([^"]+)",\s*tien:\s*"([^"]+)",\s*nhan:\s*"([^"]+)",'
        r'\s*canBoard:\s*(true|false)\)')
    ra = [{"ma": m[0], "tien": m[1], "nhan": m[2], "canBoard": m[3] == "true"}
          for m in mau.findall(van)]
    if len(ra) != 25:
        sys.exit(f"Đọc được {len(ra)} màn, phải là 25 — `EideManHinhDS` đổi hình dạng?")
    return ra


def lop_sang_tien() -> dict[str, str]:
    """Tên lớp màn → tiền tố nó khai.

    `EidePhien.MAN` viết khoá bằng `EideManTongQuan.tien`, tức TÊN LỚP; còn danh mục màn viết
    bằng TIỀN TỐ (`"Main"`). Bản đầu của bộ sinh so thẳng hai thứ ấy với nhau và ra "0 nối ·
    21 chưa" — một bảng sai toàn tập, đọc vẫn trôi chảy. Bắt được vì đọc bản in ra, không vì
    bài kiểm nào.
    """
    ra: dict[str, str] = {}
    for f in sorted(NGUON.glob("*.swift")):
        van = f.read_text(encoding="utf-8")
        # Cắt theo từng khai báo lớp rồi lấy `tien` ĐẦU TIÊN trong mỗi khúc: một tệp có thể chứa
        # nhiều màn (`EideManThietKe.swift` có bốn).
        khuc = re.split(r"\bclass\s+(\w+)\s*:", van)
        for i in range(1, len(khuc) - 1, 2):
            m = re.search(r'class var tien:\s*String\s*\{\s*"([^"]+)"\s*\}', khuc[i + 1])
            if m:
                ra[khuc[i]] = m.group(1)
    return ra


def da_noi() -> set[str]:
    """Tiền tố các màn đã nối dữ liệu — khoá của `EidePhien.MAN`."""
    van = (NGUON / "EidePhien.swift").read_text(encoding="utf-8")
    khoi = van.split("public static let MAN: [String: () -> EideManCoSo] = [", 1)
    if len(khoi) < 2:
        sys.exit("Không tìm thấy bảng `EidePhien.MAN`.")
    bang = lop_sang_tien()
    lop = re.findall(r"(\w+)\.tien:", khoi[1].split("\n    ]", 1)[0])
    thieu = [x for x in lop if x not in bang]
    if thieu:
        sys.exit(f"Không tra được tiền tố của: {thieu} — lớp màn đổi hình dạng?")
    return {bang[x] for x in lop}


def tep_cua_man() -> dict[str, Path]:
    """Tiền tố → tệp khai lớp màn ấy."""
    ra: dict[str, Path] = {}
    for f in sorted(NGUON.glob("*.swift")):
        for tien in re.findall(r'class var tien:\s*String\s*\{\s*"([^"]+)"\s*\}',
                               f.read_text(encoding="utf-8")):
            ra[tien] = f
    return ra


def git1(tep: Path) -> tuple[str, str, str]:
    """`(commit ngắn, ngày, người)` của lần sửa gần nhất — hoặc ba gạch nếu chưa có."""
    r = subprocess.run(["git", "log", "-1", "--format=%h|%ad|%an", "--date=short", "--", str(tep)],
                       cwd=GOC, capture_output=True, text=True, check=False)
    d = r.stdout.strip()
    if r.returncode != 0 or not d:
        return ("—", "—", "—")
    a, b, c = d.split("|", 2)
    return (a, b, c)


def dung() -> str:
    noi = da_noi()
    tep = tep_cua_man()
    d = ["# Bảng theo dõi 25 màn — EIDE-UXC-31 §11.1",
         "",
         "> **Tệp SINH RA. Đừng sửa tay** — chạy `python scripts/bang_theo_doi_man.py`.",
         "> Nguồn: `EideManHinhDS.swift` (danh mục), `EidePhien.MAN` (đã nối), `git log` (commit).",
         "",
         "`TT` — trạng thái: **nối** = đã nối dữ liệu thật · **chặn** = chờ bo mạch ·",
         "**chưa** = trong danh mục mà chưa dựng.",
         "",
         "| Màn | Tên | TT | Tệp | Commit | Ngày | Người/tác tử |",
         "|---|---|---|---|---|---|---|"]
    dem = {"nối": 0, "chặn": 0, "chưa": 0}
    for m in doc_danh_muc():
        tien = str(m["tien"])
        tt = "nối" if tien in noi else ("chặn" if m["canBoard"] else "chưa")
        dem[tt] += 1
        f = tep.get(tien)
        if f is None:
            d.append(f"| {m['ma']} | {m['nhan']} | {tt} | — | — | — | — |")
            continue
        sha, ngay, ai = git1(f)
        d.append(f"| {m['ma']} | {m['nhan']} | {tt} | `{f.name}` | `{sha}` | {ngay} | {ai} |")
    d += ["",
          f"**{dem['nối']} nối · {dem['chặn']} chặn (chờ bo mạch) · {dem['chưa']} chưa.**",
          "",
          "Năm phép kiểm còn lại của §11.1 không nằm trong bảng này vì chúng là BÀI KIỂM, không",
          "phải một ô đánh dấu: header chuẩn 2C.4 và danh sách sự kiện khai báo do",
          "`EideBatBienTests` giữ; trạng thái rỗng hai phần và ảnh chụp từng màn do",
          "`EideApp --tu-kiem` (mục 6c) và `--chup` giữ; trợ năng §9.2 do",
          "`EideTroNangTests.testMoiNutDeuCoNhanDocDuoc` quét cả 21 màn.",
          ""]
    return "\n".join(d)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--kiem", action="store_true", help="chỉ so, không ghi")
    a = ap.parse_args()
    moi = dung()
    if a.kiem:
        cu = DICH.read_text(encoding="utf-8") if DICH.exists() else ""
        if cu != moi:
            print(f"LỆCH: {DICH.relative_to(GOC)} không khớp mã — chạy lại không có `--kiem`.")
            return 1
        print(f"khớp: {DICH.relative_to(GOC)}")
        return 0
    DICH.write_text(moi, encoding="utf-8")
    print(f"đã sinh {DICH.relative_to(GOC)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
