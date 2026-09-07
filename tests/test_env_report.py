"""ENV-05 · env.lock và REPORT-01 · report.progress — CDS-12.3, CDS-12.5.

ENV-05 tc: "Đổi phiên bản gcc → drift 1"; steps: "Ghi tools.lock {tool, version, path, hash?};
so với lock cũ → drift". REPORT-01 tc: "Số liệu khớp ledger"; steps: "Từ ledger/decision_log/
undo: việc tự làm, chờ người, hoàn tác được, chi phí, lỗi; ≤ 40 dòng".
"""
from __future__ import annotations

import json

import pytest
import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def _router(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))


def _du_an(tmp_path, workspace, text="dự án đèn giao thông"):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l0.jsonl"))
    res = r.invoke("project.create", {"text": text}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return root


# ---------- ENV-05 env.lock ----------

def test_ghi_tools_lock(tmp_path, workspace):
    """steps: "Ghi tools.lock {tool, version, path, hash?}"."""
    root = _du_an(tmp_path, workspace)
    out = _router(tmp_path).invoke("env.lock", {}, Context(project_dir=root)).result
    assert out["drift"] == []                       # lần đầu chưa có gì để so
    assert out["lock"]["tools"]
    f = root / ".eide" / "tools.lock"
    assert f.exists()
    mot = out["lock"]["tools"][0]
    assert set(mot) >= {"tool", "version", "path"}


def test_lan_hai_khong_doi_thi_khong_drift(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.invoke("env.lock", {}, Context(project_dir=root))
    assert r.invoke("env.lock", {}, Context(project_dir=root)).result["drift"] == []


def test_doi_phien_ban_thi_drift_1(tmp_path, workspace):
    """tc từng chữ: "Đổi phiên bản gcc → drift 1"."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.invoke("env.lock", {}, Context(project_dir=root))
    f = root / ".eide" / "tools.lock"
    d = yaml.safe_load(f.read_text(encoding="utf-8"))
    d["tools"][0]["version"] = "phiên-bản-cũ-khác-hẳn"
    ten = d["tools"][0]["tool"]
    f.write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")

    out = r.invoke("env.lock", {}, Context(project_dir=root)).result
    assert len(out["drift"]) == 1
    assert out["drift"][0]["tool"] == ten
    assert out["drift"][0]["was"] == "phiên-bản-cũ-khác-hẳn"
    assert out["drift"][0]["now"] != "phiên-bản-cũ-khác-hẳn"


def test_cong_cu_bien_mat_cung_la_drift(tmp_path, workspace):
    """Trôi không chỉ là đổi số: một công cụ biến mất thì bản dựng cũng không lặp lại được."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.invoke("env.lock", {}, Context(project_dir=root))
    f = root / ".eide" / "tools.lock"
    d = yaml.safe_load(f.read_text(encoding="utf-8"))
    d["tools"].append({"tool": "cong-cu-khong-he-ton-tai", "version": "1.0", "path": "/khong/co"})
    f.write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")
    out = r.invoke("env.lock", {}, Context(project_dir=root)).result
    mat = [x for x in out["drift"] if x["tool"] == "cong-cu-khong-he-ton-tai"]
    assert len(mat) == 1 and mat[0]["now"] is None


def test_env_lock_can_du_an(tmp_path, workspace):
    run = _router(tmp_path).invoke("env.lock", {}, Context(project_dir=workspace))
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_env_lock_co_undo_restore_config(tmp_path, workspace):
    """Hợp đồng khai `undo: restore_config` — ghi đè tools.lock phải hoàn tác được."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    run = r.invoke("env.lock", {}, Context(project_dir=root))
    assert run.undo == "restore_config"
    refs = [x["undo_ref"] for x in r.invoke("policy.undo_window", {}, Context()).result["items"]]
    assert run.run_id in refs


# ---------- REPORT-01 report.progress ----------

def test_bao_cao_so_lieu_khop_ledger(tmp_path, workspace):
    """tc: "Số liệu khớp ledger"."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)
    r.ledger.append("model.call", {"role": "coder", "model_id": "gemini-3.8-flash",
                                   "cost_usd": 0.0123, "tokens_in": 100, "tokens_out": 50})
    r.ledger.append("cap.run.start", {"run_id": "rx", "cap": "target.flash", "actor": "agent"})
    r.ledger.append("cap.run.finish", {"run_id": "rx", "status": "pending", "error": "E3000"})
    md = r.invoke("report.progress", {"period": "day"}, ctx).result["md"]
    assert "0.0123" in md or "0,0123" in md
    assert "target.flash" in md
    assert "chờ anh" in md or "chờ người" in md


def test_bao_cao_khong_qua_40_dong(tmp_path, workspace):
    """steps: "≤ 40 dòng". Báo cáo hằng ngày dài hơn một màn hình thì không ai đọc."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)
    for i in range(60):
        r.ledger.append("cap.run.start", {"run_id": f"r{i}", "cap": f"cap.so{i}", "actor": "agent"})
        r.ledger.append("cap.run.finish", {"run_id": f"r{i}", "status": "done"})
    md = r.invoke("report.progress", {}, ctx).result["md"]
    assert len(md.splitlines()) <= 40, f"{len(md.splitlines())} dòng"


def test_bao_cao_neu_muc_hoan_tac_va_loi(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)
    r.invoke("project.preferences", {"op": "set", "key": "k", "scope": "project",
                                     "value": "v"}, ctx)
    r.ledger.append("error", {"kind": "tool_fail", "role": "coder", "evidence": "build hỏng"})
    md = r.invoke("report.progress", {}, ctx).result["md"]
    assert "hoàn tác" in md.lower()
    assert "tool_fail" in md


def test_period_week_gom_nhieu_ngay_hon_day(tmp_path, workspace, monkeypatch):
    """`period` enum {day, week} phải thật sự đổi phạm vi, không phải nhãn trang trí."""
    from datetime import UTC, datetime, timedelta
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)

    class BaNgayTruoc:
        @staticmethod
        def now(tz=None):
            return datetime.now(UTC) - timedelta(days=3)

    monkeypatch.setattr("eide_core.ledger.datetime", BaNgayTruoc)
    r.ledger.append("model.call", {"role": "coder", "model_id": "m", "cost_usd": 7.0})
    monkeypatch.undo()

    ngay = r.invoke("report.progress", {"period": "day"}, ctx).result["md"]
    tuan = r.invoke("report.progress", {"period": "week"}, ctx).result["md"]
    assert "7.0" not in ngay
    assert "7.0" in tuan


def test_period_la_bi_schema_chan(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    with pytest.raises(EideError) as ei:
        _router(tmp_path).invoke("report.progress", {"period": "thang"}, Context(project_dir=root))
    assert ei.value.code == "E1000"


def test_bao_cao_chay_duoc_khi_chua_co_du_an(tmp_path):
    """REPORT-01 không khai `grounding` và không khai lỗi nào — nó phải báo cáo được ở mức
    người dùng, nơi các việc liên-dự-án (project.create) được ghi. Xem DEV-014."""
    run = _router(tmp_path).invoke("report.progress", {}, Context())
    assert run.status == "done", run
    assert run.result["md"]


def test_json_hop_le_khong_lot_bi_mat(tmp_path, workspace):
    """Báo cáo đọc từ ledger, mà ledger đã che khóa (DEV-016) — kiểm lại ở đầu ra."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.ledger.append("error", {"kind": "tool_fail", "role": "coder",
                              "evidence": "curl -H 'Bearer sk-abcdef0123456789xyz'"})
    md = r.invoke("report.progress", {}, Context(project_dir=root)).result["md"]
    assert "sk-abcdef0123456789xyz" not in md
    assert json.dumps(md)          # không có ký tự phá JSON-RPC
