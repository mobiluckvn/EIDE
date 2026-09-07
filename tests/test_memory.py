"""WI-007 · Bộ nhớ M1/M2 và hai năng lực memory.* — MEM-11 §2–§5; CDS-12.6.

M1 WorkingMemory: trạng thái một Run, sống trong RAM + `run.state`/`run.working` để tiếp tục
sau khi tắt máy. M2 SessionMemory: một phiên làm việc, ở `session.sqlite`.
MEMORY-04 memory.progress tc: "Nội dung khớp ledger; không viết tay".
MEMORY-08 memory.summarize_session: ra {done[], waiting[], next[], undo_until}; ghi session.summary.
"""
from __future__ import annotations

import json
import sqlite3

import pytest
import yaml

from eide_core import store
from eide_core.ledger import Ledger
from eide_core.memory import SessionMemory, WorkingMemory
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def _du_an(tmp_path, workspace, text="dự án robot dò đường"):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l0.jsonl"))
    res = r.invoke("project.create", {"text": text}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return root


def _router(tmp_path, ten="ledger.jsonl"):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / ten))


# ---------- M1 WorkingMemory (MEM-11 §3) ----------

def test_working_memory_giu_du_truong_cua_schema(tmp_path, workspace):
    """MEM-11 §3: run_id, intent, grounded, defaults_applied, chain, cursor, vars,
    pending_question, asked_at, scratch."""
    root = _du_an(tmp_path, workspace)
    wm = WorkingMemory(run_id="r_1", intent={"intent": "code.feature", "slots": {}})
    wm.vars["passport_id"] = "P1"
    wm.cursor["n1"] = "running"
    wm.scratch.append("thử I2C1 trước")
    with store.open_store(store.store_path(root)) as c:
        wm.save(c)
        lai = WorkingMemory.load(c, "r_1")
    assert lai.run_id == "r_1"
    assert lai.vars == {"passport_id": "P1"}
    assert lai.cursor == {"n1": "running"}
    assert lai.scratch == ["thử I2C1 trước"]
    assert lai.intent["intent"] == "code.feature"


def test_working_memory_song_qua_tat_may(tmp_path, workspace):
    """MEM-11 §2 M1: "RAM + run.state (SQLite) ĐỂ TIẾP TỤC SAU TẮT MÁY" — nên phải đọc lại
    được từ một kết nối hoàn toàn mới, không dựa vào bất kỳ trạng thái nào trong tiến trình."""
    root = _du_an(tmp_path, workspace)
    db = store.store_path(root)
    with store.open_store(db) as c:
        WorkingMemory(run_id="r_2", intent={"intent": "sim.run"}, vars={"artifact": "a.elf"}).save(c)
    with store.open_store(db) as c2:
        assert WorkingMemory.load(c2, "r_2").vars == {"artifact": "a.elf"}


def test_working_memory_ghi_vao_bang_run(tmp_path, workspace):
    """DDD-14 bảng `run`: cột `state` và `working`."""
    root = _du_an(tmp_path, workspace)
    with store.open_store(store.store_path(root)) as c:
        WorkingMemory(run_id="r_3", intent={"intent": "x"}, state="running").save(c)
        row = c.execute("SELECT state, working FROM run WHERE id='r_3'").fetchone()
    assert row[0] == "running"
    assert json.loads(row[1])["run_id"] == "r_3"


def test_scratch_gioi_han_20_dong():
    """MEM-11 §3: scratch "≤ 20 dòng". Ghi chú của tác tử cho chính nó, không phải một cái sọt."""
    wm = WorkingMemory(run_id="r_4", intent={})
    for i in range(30):
        wm.ghi_chu(f"dòng {i}")
    assert len(wm.scratch) == 20
    assert wm.scratch[0] == "dòng 10"      # giữ 20 dòng MỚI nhất
    assert wm.scratch[-1] == "dòng 29"


def test_xong_run_thi_xoa_working_memory(tmp_path, workspace):
    """MEM-11 §2 M1 cột "Quên": "Xóa khi Run kết thúc; giữ tóm tắt vào M3"."""
    root = _du_an(tmp_path, workspace)
    with store.open_store(store.store_path(root)) as c:
        wm = WorkingMemory(run_id="r_5", intent={"intent": "x"}, state="running")
        wm.save(c)
        wm.ket_thuc(c, "done")
        row = c.execute("SELECT state, working FROM run WHERE id='r_5'").fetchone()
    assert row[0] == "done"
    assert row[1] is None                   # M1 xóa; bằng chứng ở lại trong ledger (M3)


# ---------- M2 SessionMemory (MEM-11 §3) ----------

def test_mo_phien_ghi_session_sqlite_va_ledger(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    led = Ledger(tmp_path / "l1.jsonl")
    sm = SessionMemory.mo(root, project=root.name, autonomy="A3", ledger=led)
    assert sm.session_id.startswith("s_")   # DDD-14 §2.25: id = s_<hex>
    with sqlite3.connect(store.session_path(root)) as c:
        row = c.execute("SELECT project, autonomy_effective, closed_at FROM session").fetchone()
    assert row == (root.name, "A3", None)
    assert [x["kind"] for x in led.records()] == ["session.open"]


def test_session_sqlite_khong_nam_trong_git(tmp_path, workspace):
    """MEM-11 §2: "session.sqlite (không commit)" — project.create đã ghi `session/` vào
    .eide/.gitignore, và đó là thứ giữ lịch sử chat khỏi lọt vào kho mã."""
    root = _du_an(tmp_path, workspace)
    bo_qua = (root / ".eide" / ".gitignore").read_text(encoding="utf-8").split()
    assert "session/" in bo_qua


def test_luot_chat_duoc_giu_va_tom_tat(tmp_path, workspace):
    """MEM-11 §3 M2: "turns[]; ≥ 3 lượt cũ được thay bằng TurnSummary"."""
    root = _du_an(tmp_path, workspace)
    sm = SessionMemory.mo(root, project=root.name, autonomy="A3")
    for i in range(8):
        sm.them_luot("human" if i % 2 == 0 else "agent", f"lượt {i}")
    assert sm.turns[0]["by"] == "summary"
    assert sm.turns[0]["n"] == 3            # đúng 3 lượt cũ nhất bị gộp
    assert len([t for t in sm.turns if t["by"] != "summary"]) == 5
    assert sm.turns[-1]["text"] == "lượt 7"


def test_phien_doc_lai_duoc_sau_khi_dong(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    sm = SessionMemory.mo(root, project=root.name, autonomy="A3")
    sm.them_luot("human", "nháy LED giúp anh")
    sid = sm.session_id
    sm.dong(summary="đã tạo dự án")
    lai = SessionMemory.doc(root, sid)
    assert lai.turns[-1]["text"] == "nháy LED giúp anh"
    assert lai.closed_at and lai.summary == "đã tạo dự án"


def test_phien_gan_nhat_la_phien_chua_dong(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    s1 = SessionMemory.mo(root, project=root.name, autonomy="A3")
    s1.dong(summary="xong")
    s2 = SessionMemory.mo(root, project=root.name, autonomy="A3")
    assert SessionMemory.gan_nhat(root).session_id == s2.session_id


# ---------- MEMORY-04 memory.progress ----------

def test_progress_sinh_tu_ledger_khong_viet_tay(tmp_path, workspace):
    """tc: "Nội dung khớp ledger; không viết tay"."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)
    r.invoke("project.preferences", {"op": "set", "key": "probe", "scope": "project",
                                     "value": "stlink"}, ctx)
    # Đếm TRƯỚC khi gọi: một năng lực không thể đếm chính lần chạy của nó, vì `cap.run.finish`
    # của nó chỉ được Router ghi sau khi handler trả về.
    xong = len([x for x in r.ledger.records()
                if x["kind"] == "cap.run.finish" and (x["data"] or {}).get("status") == "done"])
    out = r.invoke("memory.progress", {}, ctx).result
    md = out["progress_md"]
    assert md.startswith("## Trạng thái")
    assert root.name in md
    # Mức tự chủ đọc từ `.eide/autonomy.yaml` của dự án, không phải một hằng số chép vào test:
    # mức mặc định là quyết định cấu hình của người dùng (A3 → A2 ngày 2026-09-06), đổi nó không
    # được làm đổ một test đang kiểm chuyện khác.
    assert yaml.safe_load((root / ".eide" / "autonomy.yaml").read_text(encoding="utf-8"))["autonomy"] in md
    # số việc tự động phải khớp ledger, không phải một con số nghĩ ra
    assert f"{xong} việc tự động" in md


def test_progress_ghi_ra_dia(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.invoke("memory.progress", {}, Context(project_dir=root))
    assert (root / ".eide" / "PROGRESS.md").read_text(encoding="utf-8").startswith("## Trạng thái")
    assert "features" in json.loads((root / ".eide" / "FEATURES.json").read_text(encoding="utf-8"))


def test_features_sinh_tu_bang_feature(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    with sqlite3.connect(store.store_path(root)) as c:
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES "
                  "('F-04','Đọc MPU6050 qua I2C1','failing','2026-09-01')")
        c.execute("INSERT INTO feature (id,title,status,evidence,verified,updated_at) VALUES "
                  "('F-03','BME280 forced mode','passing','[\"log:sha256:ab\"]','auto','2026-09-02')")
    store.write_seal(store.store_path(root))
    out = _router(tmp_path).invoke("memory.progress", {}, Context(project_dir=root)).result
    f = out["features"]["features"]
    assert {x["id"] for x in f} == {"F-04", "F-03"}
    assert next(x for x in f if x["id"] == "F-03")["evidence"] == ["log:sha256:ab"]
    assert "1/2 passing" in out["progress_md"]
    assert "F-04" in out["progress_md"]     # feature failing đầu được nêu tên


def test_entry_cua_nguoi_duoc_them(tmp_path, workspace):
    """input_schema: `entry` tùy chọn — "thêm ghi chú của người"."""
    root = _du_an(tmp_path, workspace)
    out = _router(tmp_path).invoke("memory.progress", {"entry": "nhớ kiểm nguồn 3V3"},
                                   Context(project_dir=root)).result
    assert "nhớ kiểm nguồn 3V3" in out["progress_md"]


def test_progress_neu_muc_hoan_tac_con_han(tmp_path, workspace):
    """PROGRESS.md mẫu của MEM-11 §5 có dòng "Hoàn tác được đến ..."."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)
    r.invoke("project.preferences", {"op": "set", "key": "k", "scope": "project",
                                     "value": "v"}, ctx)
    md = r.invoke("memory.progress", {}, ctx).result["progress_md"]
    assert "Hoàn tác được" in md and "project.preferences" in md


def test_progress_can_du_an(tmp_path, workspace):
    run = _router(tmp_path).invoke("memory.progress", {}, Context(project_dir=workspace))
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- MEMORY-08 memory.summarize_session ----------

def test_tom_tat_phien_du_bon_truong(tmp_path, workspace):
    """output_schema: summary {done[], waiting[], next[], undo_until}."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)
    SessionMemory.mo(root, project=root.name, autonomy="A3", ledger=r.ledger)
    r.invoke("project.preferences", {"op": "set", "key": "k", "scope": "project",
                                     "value": "v"}, ctx)
    s = r.invoke("memory.summarize_session", {}, ctx).result["summary"]
    assert set(s) == {"done", "waiting", "next", "undo_until"}
    assert "project.preferences" in " ".join(s["done"])
    assert s["undo_until"]


def test_waiting_lay_tu_gate_dang_mo(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    r.ledger.append("cap.run.start", {"run_id": "rx", "cap": "target.flash", "actor": "agent"})
    r.ledger.append("cap.run.finish", {"run_id": "rx", "status": "pending", "error": "E3000"})
    s = r.invoke("memory.summarize_session", {}, Context(project_dir=root)).result["summary"]
    assert any("target.flash" in w for w in s["waiting"])


def test_next_de_nghi_feature_failing_dau(tmp_path, workspace):
    """MEM-11 §5 bước 2: "đọc FEATURES.json, chọn feature failing đầu"."""
    root = _du_an(tmp_path, workspace)
    with sqlite3.connect(store.store_path(root)) as c:
        c.execute("INSERT INTO feature (id,title,status,updated_at) VALUES ('F-04','Đọc MPU6050','failing','2026-09-01')")
    store.write_seal(store.store_path(root))
    s = _router(tmp_path).invoke("memory.summarize_session", {}, Context(project_dir=root)).result["summary"]
    assert any("F-04" in n for n in s["next"])


def test_run_dang_do_duoc_de_nghi_tiep_tuc(tmp_path, workspace):
    """MEM-11 §5 bước 3: "đọc run.state có trạng thái running/asked → đề nghị tiếp tục"."""
    root = _du_an(tmp_path, workspace)
    with store.open_store(store.store_path(root)) as c:
        WorkingMemory(run_id="r_9", intent={"intent": "code.feature"}, state="running").save(c)
    store.write_seal(store.store_path(root))
    s = _router(tmp_path).invoke("memory.summarize_session", {}, Context(project_dir=root)).result["summary"]
    assert any("r_9" in n for n in s["next"])


def test_tom_tat_ghi_session_summary_vao_ledger(tmp_path, workspace):
    """steps: "ghi session.summary"."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    SessionMemory.mo(root, project=root.name, autonomy="A3", ledger=r.ledger)
    r.invoke("memory.summarize_session", {}, Context(project_dir=root))
    tt = [x for x in r.ledger.records() if x["kind"] == "session.summary"]
    assert len(tt) == 1 and tt[0]["data"]["session_id"]
    assert r.ledger.verify() == (True, 0)


def test_tom_tat_khong_qua_200_token(tmp_path, workspace):
    """steps: "tóm tắt ≤ 200 token". Đếm thô bằng từ — đủ để chặn một bản tóm tắt phình ra."""
    root = _du_an(tmp_path, workspace)
    r = _router(tmp_path)
    ctx = Context(project_dir=root)
    for i in range(30):
        r.invoke("project.preferences", {"op": "set", "key": f"k{i}", "scope": "project",
                                         "value": "v"}, ctx)
    s = r.invoke("memory.summarize_session", {}, ctx).result["summary"]
    tu = len(" ".join(s["done"] + s["waiting"] + s["next"]).split())
    assert tu <= 200, f"tóm tắt {tu} từ — vượt ngưỡng MEM-11 §8"


@pytest.mark.parametrize("cap", ["memory.progress", "memory.summarize_session"])
def test_khong_nhan_tham_so_la(tmp_path, workspace, cap):
    from eide_core.errors import EideError
    root = _du_an(tmp_path, workspace)
    with pytest.raises(EideError) as ei:
        _router(tmp_path).invoke(cap, {"khong_co_that": 1}, Context(project_dir=root))
    assert ei.value.code == "E1000"
