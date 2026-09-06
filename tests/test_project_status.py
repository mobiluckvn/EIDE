"""PROJECT-08 · project.status — CDS-12.3.

tc: "Số liệu khớp ledger". Bước duy nhất: "Tổng hợp từ FEATURES, queue, undo, ledger chi phí, session".
output_schema mô tả report: features, gates_open, undo_items, cost_today, autonomy, target.
"""
from __future__ import annotations

import sqlite3
from datetime import UTC, datetime, timedelta

import pytest
import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def _du_an(tmp_path, workspace, text="dự án đèn giao thông", **kw):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l0.jsonl"))
    res = r.invoke("project.create", {"text": text, **kw}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return root


def _router(tmp_path, ten="ledger.jsonl"):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / ten))


def test_report_co_du_sau_truong_cua_hop_dong(tmp_path, workspace):
    root = _du_an(tmp_path, workspace, chip="STM32F411", board="nucleo-f411re")
    r = _router(tmp_path)
    run = r.invoke("project.status", {}, Context(project_dir=root))
    assert run.status == "done", run
    rep = run.result["report"]
    assert set(rep) == {"features", "gates_open", "undo_items", "cost_today", "autonomy", "target"}
    assert rep["target"] == {"chip": "STM32F411", "board": "nucleo-f411re"}
    assert rep["autonomy"]


def test_features_khop_store(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    db = store.store_path(root)
    with sqlite3.connect(db) as c:
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES ('F1','nháy LED','failing','2026-09-01')")
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES ('F2','đọc ADC','passing','2026-09-02')")
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES ('F3','UART','passing','2026-09-03')")
    store.write_seal(db)
    rep = _router(tmp_path).invoke("project.status", {}, Context(project_dir=root)).result["report"]
    assert rep["features"] == {"total": 3, "passing": 2, "failing": 1, "first_failing": "F1"}


def test_cost_today_khop_ledger(tmp_path, workspace, monkeypatch):
    """tc "Số liệu khớp ledger": chi phí cộng từ sự kiện `model.call` của HÔM NAY.

    Bản ghi "hôm qua" được tạo bằng cách lùi đồng hồ của chính Ledger, không phải sửa tệp —
    sửa tệp sẽ làm gãy chuỗi hash và test không còn nói lên điều gì về hành vi thật.
    """
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)

    class HomQua:
        @staticmethod
        def now(tz=None):
            return datetime.now(UTC) - timedelta(days=1)

    monkeypatch.setattr("eide_core.ledger.datetime", HomQua)
    r.ledger.append("model.call", {"role": "writer", "model_id": "gemini-3.8-flash", "cost_usd": 9.99})
    monkeypatch.undo()

    r.ledger.append("model.call", {"role": "coder", "model_id": "gemini-3.8-flash", "cost_usd": 0.02})
    r.ledger.append("model.call", {"role": "planner", "model_id": "gemini-3.8-flash", "cost_usd": 0.005})
    rep = r.invoke("project.status", {}, Context(project_dir=root)).result["report"]
    assert rep["cost_today"] == 0.025          # 9.99 của hôm qua không được cộng vào
    assert r.ledger.verify() == (True, 0)


def test_cost_today_bang_khong_khi_chua_goi_mo_hinh(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    rep = _router(tmp_path).invoke("project.status", {}, Context(project_dir=root)).result["report"]
    assert rep["cost_today"] == 0.0


def test_gates_open_khop_ledger(tmp_path, workspace):
    """"queue" = lời gọi đang chờ người quyết. Số liệu lấy từ ledger, đúng như tc đòi."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    # Hai lời gọi rơi vào ASK, một lời gọi xong bình thường
    for rid in ("r1", "r2"):
        r.ledger.append("cap.run.start", {"run_id": rid, "cap": "target.flash", "actor": "agent"})
        r.ledger.append("cap.run.finish", {"run_id": rid, "status": "pending", "error": "E3000"})
    r.ledger.append("cap.run.start", {"run_id": "r3", "cap": "project.list", "actor": "agent"})
    r.ledger.append("cap.run.finish", {"run_id": "r3", "status": "done"})
    rep = r.invoke("project.status", {}, Context(project_dir=root)).result["report"]
    assert rep["gates_open"] == 2


def test_gate_da_duoc_nguoi_tra_loi_thi_khong_con_mo(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.ledger.append("cap.run.start", {"run_id": "r1", "cap": "target.flash", "actor": "agent"})
    r.ledger.append("cap.run.finish", {"run_id": "r1", "status": "pending", "error": "E3000"})
    r.ledger.append("gate.human", {"gate_id": "r1", "decision": "approve", "by": "human", "note": ""})
    rep = r.invoke("project.status", {}, Context(project_dir=root)).result["report"]
    assert rep["gates_open"] == 0


def test_autonomy_theo_autonomy_yaml(tmp_path, workspace):
    """Đọc `.eide/autonomy.yaml` — nguồn sự thật của mức tự chủ (POL-17 §4, SDD-04 §6).

    Đổi mức đi qua `policy.set_autonomy`, một năng lực T2, nên PolicyGate hỏi người trước; ở
    đây ta ghi thẳng tệp vì thứ đang kiểm là project.status ĐỌC đúng chỗ, không phải luồng duyệt.
    """
    root = _du_an(tmp_path, workspace)
    f = root / ".eide" / "autonomy.yaml"
    cfg = yaml.safe_load(f.read_text(encoding="utf-8"))
    cfg["autonomy"] = "A1"
    f.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")
    rep = _router(tmp_path).invoke("project.status", {}, Context(project_dir=root)).result["report"]
    assert rep["autonomy"] == "A1"


def test_chua_mo_du_an_la_E2000(tmp_path, workspace):
    run = _router(tmp_path).invoke("project.status", {}, Context(project_dir=workspace))
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_khong_nhan_tham_so(tmp_path, workspace):
    """input_schema: properties rỗng, additionalProperties=false → E1000 nếu truyền thừa.

    E1000 được Router ném ra TRƯỚC khi hỏi cổng và trước khi ghi cap.run.start (router.py) —
    tham số sai thì chưa có gì để quyết định, nên nó không thành một CapabilityRun "failed".
    """
    root = _du_an(tmp_path, workspace)
    with pytest.raises(EideError) as ei:
        _router(tmp_path).invoke("project.status", {"project": "x"}, Context(project_dir=root))
    assert ei.value.code == "E1000"


def test_chay_duoc_khi_chua_migrate(tmp_path, workspace):
    """project.status không có grounding và không khai E6003 — nó phải báo cáo được cả kho chưa di trú."""
    r0 = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l0.jsonl"))
    res = r0.invoke("project.create", {"text": "dự án chưa di trú"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    run = _router(tmp_path).invoke("project.status", {}, Context(project_dir=root))
    assert run.status == "done", run
    assert run.result["report"]["features"]["total"] == 0
