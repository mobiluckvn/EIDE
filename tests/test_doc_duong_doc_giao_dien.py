"""Hai đường ĐỌC mà giao diện thiếu — DEV-135 (`policy.rules.boards`) và DEV-136 (`kind=tool`).

Cùng một hình dạng hỏng, gặp ba lần trong hai ngày: một mục của UXC-31 §8 đòi màn hiện một thứ,
tầng dưới có đường GHI đầy đủ, và **không có đường đọc**. [DEV-134] là lần đầu, và nó đẻ ra
`archive.sources`; hai mục này là lần thứ hai và thứ ba.
"""
from __future__ import annotations

from eide_core import store
from test_code import _du_an_git


def test_policy_rules_tra_trang_thai_lab_cua_board(tmp_path, workspace):
    """DEV-135 — `board.mark_lab` ghi `boards.<id>`, và trước v1.3 KHÔNG ai đọc ra được.

    Màn S6 có đường ghi đầy đủ (hai ô xác nhận → cổng → niêm ký lại) mà phải nói "trạng thái
    hiện tại chưa đọc lại được" — một màn không đọc lại được thứ chính nó vừa ghi.
    """
    r, ctx, root = _du_an_git(tmp_path, workspace)
    gate = ctx.extra["gate"]
    gate.config = {**(gate.config or {}),
                   "boards": {"nucleo-f411": {"lab": True, "has_actuator": False,
                                              "reason": "bàn thí nghiệm, không cơ cấu chấp hành"}}}
    run = r.invoke("policy.rules", {}, ctx)
    assert run.status == "done", run.error
    b = run.result["boards"]
    assert b["nucleo-f411"]["lab"] is True
    assert b["nucleo-f411"]["has_actuator"] is False
    assert "bàn thí nghiệm" in b["nucleo-f411"]["reason"]


def test_thieu_truong_thi_de_None_chu_khong_doan_la_False(tmp_path, workspace):
    """**`None` ≠ `False`.** Một board khai `{lab: true}` mà thiếu `has_actuator` không được
    hiện thành "không có cơ cấu chấp hành" — đó là hai câu khác nhau, và câu thứ hai NỚI LỎNG
    một cổng an toàn."""
    r, ctx, root = _du_an_git(tmp_path, workspace)
    gate = ctx.extra["gate"]
    gate.config = {**(gate.config or {}), "boards": {"b1": {"lab": True}}}
    run = r.invoke("policy.rules", {}, ctx)
    assert run.result["boards"]["b1"]["has_actuator"] is None


def test_khong_co_board_nao_thi_tra_rong_chu_khong_vang_mat(tmp_path, workspace):
    """Trường LUÔN có mặt: hợp đồng khai `boards` bắt buộc, và một khoá vắng mặt bắt bên gọi
    phân biệt "chưa khai board nào" với "phiên bản cũ không trả trường này"."""
    r, ctx, root = _du_an_git(tmp_path, workspace)
    run = r.invoke("policy.rules", {}, ctx)
    assert run.result["boards"] == {}


def test_view_artifacts_kind_tool_gop_theo_cong_cu(tmp_path, workspace):
    """DEV-136 — `tool_report` là LỊCH SỬ CHẠY, một hàng mỗi lượt; danh mục công cụ phải GỘP.

    Trả `dat`/`tong` chứ không chỉ `passed` của lượt cuối: một công cụ đạt 9/10 và một công cụ
    đạt 1/10 mà lượt cuối may mắn xanh là hai thứ rất khác nhau.
    """
    r, ctx, root = _du_an_git(tmp_path, workspace)
    db = store.store_path(root)
    for i, (ten, dat) in enumerate([("crc16", 1), ("crc16", 1), ("crc16", 0), ("parse_log", 1)]):
        store.ghi_tool_report(db, {"tool": ten, "passed": dat, "log_ref": "",
                                   "at": f"2026-09-21T10:0{i}:00+00:00"})
    run = r.invoke("view.artifacts", {"kind": "tool"}, ctx)
    assert run.status == "done", run.error
    theo = {x["tool"]: x for x in run.result["items"]}
    assert theo["crc16"]["dat"] == 2 and theo["crc16"]["tong"] == 3
    assert theo["parse_log"]["dat"] == 1 and theo["parse_log"]["tong"] == 1
    assert run.result["total"] == 2, "total là SỐ CÔNG CỤ, không phải số lượt chạy"


def test_kind_tool_tren_du_an_chua_chay_gi_thi_rong_chu_khong_loi(tmp_path, workspace):
    """Dự án chưa chạy công cụ nào là trạng thái BÌNH THƯỜNG nhất — bắt bên gọi bắt lỗi để vẽ
    nó là cách chắc chắn để nó nuốt một lỗi thật về sau."""
    r, ctx, root = _du_an_git(tmp_path, workspace)
    run = r.invoke("view.artifacts", {"kind": "tool"}, ctx)
    assert run.status == "done", run.error
    assert run.result == {"items": [], "total": 0, "kind": "tool"}


def test_enum_hop_dong_va_bang_hien_vat_la_MOT_nguon(tmp_path, workspace):
    """Hai danh sách loại hiện vật là hai chỗ sẽ lệch — và lệch im lặng, vì `kind` lạ trả E1000
    trông y hệt người dùng gõ sai."""
    import json
    from pathlib import Path

    from eide.caps.view import BANG_HIEN_VAT
    goc = Path(__file__).resolve().parents[1]
    d = {c["id"]: c for c in json.loads((goc / "docs/spec/cds.json").read_text(encoding="utf-8"))}
    enum = set(d["view.artifacts"]["input_schema"]["properties"]["kind"]["enum"])
    assert enum == set(BANG_HIEN_VAT), f"hợp đồng {sorted(enum)} ≠ mã {sorted(BANG_HIEN_VAT)}"
