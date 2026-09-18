#!/usr/bin/env python3
"""Sinh EideRpcGenerated.swift từ docs/spec/api/openrpc.json — WI-021.

Spec: GPI-23 §2 (plugin dùng bộ mã sinh từ openrpc.json, KHÔNG viết tay chuỗi phương thức);
API-15 §8 test hợp đồng mục (3); DEP-26 §1 (`eide-geditor` sinh mã từ openrpc.json).

VÌ SAO PHẢI SINH. Tên phương thức JSON-RPC viết tay trong Swift là 55 chuỗi mà trình biên dịch
không kiểm được: đổi tên một phương thức ở API-15 thì phía Python đỏ ngay
(test_specs_consistency), còn phía Swift im lặng cho tới khi người dùng bấm nút. Sinh ra thì
cả hai bên cùng gãy vào một lúc, và `--kiem` bắt được ngay ở CI.

    python scripts/gen_rpc_swift.py            ghi apps/geditor/Sources/EIDEKit/
    python scripts/gen_rpc_swift.py --kiem     so với tệp hiện có, không ghi (dùng ở CI)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OPENRPC = ROOT / "docs" / "spec" / "api" / "openrpc.json"
ERRORS = ROOT / "docs" / "spec" / "api" / "errors.json"
# Hai đích — xem ghi chú cùng loại ở `gen_ui_swift.py`.
DICH_DS = [
    ROOT / "apps" / "geditor" / "Sources" / "EIDEKit" / "EideRpcGenerated.swift",
    ROOT / "apps" / "eide" / "Sources" / "EideLoi" / "EideRpcGenerated.swift",
]


def ten_swift(rpc: str) -> str:
    """`caps.invoke` → `capsInvoke`. Chuỗi RPC gốc giữ nguyên ở `rawValue` bên cạnh."""
    phan = [p for p in re.split(r"[._\s]+", rpc) if p]
    return phan[0].lower() + "".join(p[:1].upper() + p[1:].lower() for p in phan[1:])


def main() -> int:
    spec = json.loads(OPENRPC.read_text(encoding="utf-8"))
    loi = json.loads(ERRORS.read_text(encoding="utf-8"))
    methods = sorted(spec["methods"], key=lambda m: m["name"])

    d = [
        "// SINH TỰ ĐỘNG — đừng sửa tay.",
        "//",
        "// Nguồn: docs/spec/api/openrpc.json và errors.json.",
        "// Sinh lại: python3 scripts/gen_rpc_swift.py   ·   Đối chiếu: --kiem (chạy trong CI).",
        "//",
        "// GPI-23 §2 và API-15 §8 (3) đòi plugin dùng bộ mã sinh từ openrpc.json chứ không viết",
        "// tay chuỗi phương thức: 55 chuỗi viết tay là 55 chỗ trình biên dịch không kiểm được.",
        "",
        "import Foundation",
        "",
        "/// Tên phương thức JSON-RPC của EIDE (API-15 §2).",
        "public enum EideMethod: String, CaseIterable, Sendable {",
    ]
    for m in methods:
        tom = (m.get("summary") or "").replace("\n", " ").strip()
        if tom:
            d.append(f"    /// {tom}")
        d.append(f'    case {ten_swift(m["name"])} = "{m["name"]}"')
    d += [
        "}",
        "",
        "/// Mã lỗi EIDE (API-15 §3). `rawValue` là phần SỐ trong JSON-RPC error.code;",
        "/// `ma` giữ dạng `Exxxx` để đối chiếu với tài liệu và với ledger.",
        "public enum EideErrorCode: Int, Error, CaseIterable, Sendable {",
    ]
    for e in loi:
        d.append(f'    /// {e["name"]} — {e["meaning"]}')
        d.append(f'    case {ten_swift(e["name"])} = {int(e["code"][1:])}')
    d += [
        "",
        '    public var ma: String { String(format: "E%04d", rawValue) }',
        "",
        "    /// Cách xử lý mà API-15 §3 khuyến nghị — hiện ra cùng thông báo lỗi, vì một mã lỗi",
        "    /// không kèm việc phải làm thì chỉ là một con số.",
        "    public var cachXuLy: String {",
        "        switch self {",
    ]
    for e in loi:
        xu_ly = (e.get("handling") or "").replace("\\", "\\\\").replace('"', '\\"')
        d.append(f'        case .{ten_swift(e["name"])}: return "{xu_ly}"')
    d += [
        "        }",
        "    }",
        "}",
        "",
        "/// Số phương thức và mã lỗi lúc sinh — test hợp đồng đối chiếu với spec (API-15 §8).",
        f"public let eideSoPhuongThuc = {len(methods)}",
        f"public let eideSoMaLoi = {len(loi)}",
        "",
    ]
    noi_dung = "\n".join(d)

    ra = 0
    for DICH in DICH_DS:
        ra |= _ghi(DICH, noi_dung, len(methods), len(loi))
    return ra


def _ghi(DICH, noi_dung, so_pt, so_loi):
    cu = DICH.read_text(encoding="utf-8") if DICH.exists() else None
    if "--kiem" in sys.argv:
        if cu != noi_dung:
            print(f"✗ {DICH.relative_to(ROOT)} lệch openrpc.json — chạy scripts/gen_rpc_swift.py")
            return 1
        print(f"✓ EideRpcGenerated.swift khớp openrpc.json "
              f"({so_pt} phương thức, {so_loi} mã lỗi)")
        return 0
    DICH.parent.mkdir(parents=True, exist_ok=True)
    DICH.write_text(noi_dung, encoding="utf-8")
    print(f"{'=' if cu == noi_dung else 'đã ghi'} {DICH.relative_to(ROOT)} "
          f"({so_pt} phương thức, {so_loi} mã lỗi)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
