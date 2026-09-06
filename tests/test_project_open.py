"""PROJECT-02 · project.open — CDS-12.3.

tc: "Store hợp lệ → summary có feature đầu; store bị ghi ngoài cổng → E6000".
errors: E6003 MIGRATION_REQUIRED · E6000 STORE_INTEGRITY · E2000 không tìm thấy — mỗi mã một test.
Các bước 1–5 của hợp đồng, mỗi bước ít nhất một test; bước phụ thuộc WI-007 xem DEV-008.
"""
from __future__ import annotations

import sqlite3

from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def _router(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))


def _du_an(tmp_path, workspace, text="dự án robot dò đường"):
    """Tạo dự án rồi di trú store — trạng thái bình thường trước khi mở."""
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    res = r.invoke("project.create", {"text": text}, ctx).result
    duong_dan = workspace / res["project_id"]
    store.migrate(store.store_path(duong_dan), ledger=r.ledger)
    return duong_dan


# ---------- bước 5 + tc: đường bình thường ----------

def test_mo_du_an_hop_le_tra_summary(tmp_path, workspace):
    duong_dan = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    run = r.invoke("project.open", {"project": str(duong_dan)}, Context(project_dir=workspace))
    assert run.status == "done", run
    s = run.result["summary"]
    assert s["project"] == "robot-do-duong"
    assert s["path"] == str(duong_dan)
    assert s["user_version"] == store.LATEST_VERSION
    assert run.result["migrated"] is False
    assert run.result["stale_runs"] == []


def test_ghi_ledger_session_open(tmp_path, workspace):
    """Bước 5: "ghi ledger session.open"."""
    duong_dan = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.invoke("project.open", {"project": str(duong_dan)}, Context(project_dir=workspace))
    mo = [x for x in r.ledger.records() if x["kind"] == "session.open"]
    assert len(mo) == 1
    assert mo[0]["data"]["project"] == "robot-do-duong"
    assert mo[0]["data"]["session_id"]
    assert r.ledger.verify() == (True, 0)


def test_summary_co_feature_failing_dau(tmp_path, workspace):
    """tc: "Store hợp lệ → summary CÓ FEATURE ĐẦU" (feature failing đầu tiên)."""
    duong_dan = _du_an(tmp_path, workspace)
    db = store.store_path(duong_dan)
    with sqlite3.connect(db) as c:
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES ('F2','đọc ADC','passing','2026-09-01')")
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES ('F1','nháy LED 1 Hz','failing','2026-09-02')")
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES ('F3','UART echo','failing','2026-09-03')")
    store.write_seal(db)                                  # ghi qua cổng thì niêm lại
    r = _router(tmp_path)
    s = r.invoke("project.open", {"project": str(duong_dan)},
                 Context(project_dir=workspace)).result["summary"]
    assert s["features"] == {"total": 3, "passing": 1, "failing": 2}
    assert s["first_failing"] == {"id": "F1", "title": "nháy LED 1 Hz"}   # cũ nhất trước


def test_summary_co_board_va_ho_chieu(tmp_path, workspace):
    """output_schema mô tả summary: "dự án, board, hộ chiếu, feature failing đầu, mục chờ, undo còn hạn"."""
    r0 = _router(tmp_path)
    res = r0.invoke("project.create", {"text": "dự án đèn giao thông", "board": "nucleo-f411re"},
                    Context(project_dir=workspace)).result
    duong_dan = workspace / res["project_id"]
    db = store.store_path(duong_dan)
    store.migrate(db, ledger=r0.ledger)
    with sqlite3.connect(db) as c:
        c.execute("INSERT INTO passport (id,kind,header,created_at) VALUES ('P1','chip','STM32F411','2026-09-01')")
    store.write_seal(db)
    r = _router(tmp_path)
    s = r.invoke("project.open", {"project": str(duong_dan)},
                 Context(project_dir=workspace)).result["summary"]
    assert s["board"] == "nucleo-f411re"
    assert s["passports"] == 1
    assert s["pending"] == 0 and s["undo_open"] == []


def test_stale_runs_la_run_dang_chay_hoac_dang_hoi(tmp_path, workspace):
    """Bước 4: "đọc run có state running/asked"."""
    duong_dan = _du_an(tmp_path, workspace)
    db = store.store_path(duong_dan)
    with sqlite3.connect(db) as c:
        for rid, st in [("r1", "running"), ("r2", "asked"), ("r3", "done"), ("r4", "failed")]:
            c.execute("INSERT INTO run (id,graph,state) VALUES (?,'{}',?)", (rid, st))
    store.write_seal(db)
    r = _router(tmp_path)
    kq = r.invoke("project.open", {"project": str(duong_dan)}, Context(project_dir=workspace)).result
    assert sorted(kq["stale_runs"]) == ["r1", "r2"]


def test_mo_bang_id_khong_can_duong_dan(tmp_path, workspace):
    """input_schema: project là "id hoặc đường dẫn"."""
    _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    run = r.invoke("project.open", {"project": "robot-do-duong"}, Context(project_dir=workspace))
    assert run.status == "done", run
    assert run.result["summary"]["project"] == "robot-do-duong"


# ---------- ba mã lỗi của hợp đồng ----------

def test_khong_tim_thay_la_E2000(tmp_path, workspace):
    r = _router(tmp_path)
    run = r.invoke("project.open", {"project": "khong-he-co"}, Context(project_dir=workspace))
    assert run.status == "failed"
    assert run.error["eide_code"] == "E2000"
    # E2000 handling (API-15 §3): "Payload {exists[], candidates[], missing[]}"
    assert set(run.error) >= {"exists", "candidates", "missing"}


def test_user_version_cu_la_E6003(tmp_path, workspace):
    """Bước 1: "PRAGMA user_version → nếu cũ: E6003 (Orchestrator gọi eide migrate)" — KHÔNG tự di trú."""
    r0 = _router(tmp_path)
    res = r0.invoke("project.create", {"text": "dự án đo điện áp"}, Context(project_dir=workspace)).result
    duong_dan = workspace / res["project_id"]
    db = store.store_path(duong_dan)
    store.migrate(db, target=1, ledger=r0.ledger)          # dừng ở phiên bản cũ
    r = _router(tmp_path)
    run = r.invoke("project.open", {"project": str(duong_dan)}, Context(project_dir=workspace))
    assert run.status == "failed"
    assert run.error["eide_code"] == "E6003"
    assert run.error["remedy"] == "eide migrate"
    with sqlite3.connect(db) as c:                          # và store vẫn nguyên phiên bản cũ
        assert store.current_version(c) == 1


def test_ghi_ngoai_cong_la_E6000(tmp_path, workspace):
    """tc: "store bị ghi NGOÀI CỔNG → E6000". Ghi thẳng vào sqlite, không qua Router, không niêm lại."""
    duong_dan = _du_an(tmp_path, workspace)
    db = store.store_path(duong_dan)
    with sqlite3.connect(db) as c:
        c.execute("INSERT INTO feature (id,title,status) VALUES ('X','chèn lén','passing')")
    # cố ý KHÔNG gọi write_seal — đó chính là "ghi ngoài cổng"
    r = _router(tmp_path)
    run = r.invoke("project.open", {"project": str(duong_dan)}, Context(project_dir=workspace))
    assert run.status == "failed"
    assert run.error["eide_code"] == "E6000"
    assert run.error["handling"] == "rebuild"


def test_mat_niem_phong_cung_la_E6000(tmp_path, workspace):
    """Store hợp lệ luôn được niêm lúc di trú, nên thiếu niêm = có người đụng vào ngoài cổng."""
    duong_dan = _du_an(tmp_path, workspace)
    store.seal_path(store.store_path(duong_dan)).unlink()
    r = _router(tmp_path)
    run = r.invoke("project.open", {"project": str(duong_dan)}, Context(project_dir=workspace))
    assert run.error["eide_code"] == "E6000"


def test_chua_migrate_bao_E6003_chu_khong_no(tmp_path, workspace):
    """Dự án vừa tạo, chưa `eide migrate` — store chưa tồn tại."""
    r0 = _router(tmp_path)
    res = r0.invoke("project.create", {"text": "dự án chưa di trú"}, Context(project_dir=workspace)).result
    r = _router(tmp_path)
    run = r.invoke("project.open", {"project": str(workspace / res["project_id"])},
                   Context(project_dir=workspace))
    assert run.status == "failed" and run.error["eide_code"] == "E6003"


# ---------- niêm phong: đọc không được coi là ghi ----------

def test_mo_nhieu_lan_khong_bao_lech(tmp_path, workspace):
    """WAL và checkpoint đổi tệp mà không đổi dữ liệu — vân tay LOGIC phải bỏ qua chuyện đó."""
    duong_dan = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    for _ in range(3):
        run = r.invoke("project.open", {"project": str(duong_dan)}, Context(project_dir=workspace))
        assert run.status == "done", run


def test_vacuum_khong_lam_lech_van_tay(tmp_path, workspace):
    """VACUUM viết lại toàn bộ tệp. Băm byte thô sẽ báo động giả; băm nội dung thì không."""
    duong_dan = _du_an(tmp_path, workspace)
    db = store.store_path(duong_dan)
    con = sqlite3.connect(db)
    con.execute("VACUUM")
    con.close()
    ok, _ = store.verify_seal(db)
    assert ok
