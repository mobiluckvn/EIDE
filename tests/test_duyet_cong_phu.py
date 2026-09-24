"""[DEV-176] Tác tử hỏi được, người phải TRẢ LỜI ĐƯỢC.

Cổng do HANDLER chạy — G1 phán lên chính bản kế hoạch `plan.create` vừa sinh — không nằm trong
hàng chờ của Router: lời gọi sinh ra nó đã `done` từ lâu, thứ người duyệt là HIỆN VẬT chứ không
phải một lời gọi đang treo.

Đo 22/09/2026 trên bài nhấp nháy LED: cổng G1-03 "Đổi kiến trúc" trả ASK (bước 1 chạm `clock`
vì đặt `F_CPU` — đúng thứ POL-17 bắt hỏi người). Nhờ [DEV-171] câu hỏi HIỆN ĐƯỢC ở tab Làm rõ
yêu cầu và có dòng `decision_log`. Bấm duyệt thì `quyet_dinh` ném E2000.

Người dùng đọc được câu hỏi và không có đường nào trả lời nó — chuỗi đứng vĩnh viễn ở đúng chỗ
tác tử làm đúng.
"""
from __future__ import annotations

import json

import pytest

from eide import gate_handlers
from eide.caps.plan import doc_plan_feature, ghi_plan
from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

ASK_G1 = {"decision": "ASK", "rule": "G1-03", "gate": "G1",
          "reason": "Đổi kiến trúc (RTOS, clock, linker)", "run_id": "r_abc123"}
KHOA = "r_abc123:G1"


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "nhấp nháy LED"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    gate_handlers.dang_ky(r, ctx)
    ghi_plan(root, "F-01",
             {"steps": [{"id": "s1", "goal": "đặt F_CPU", "cites": ["x"], "touches": ["clock"]}],
              "missing": [], "feature": "F-01"}, dict(ASK_G1))
    return r, ctx, root


def _clar(root, cid, text, status="open"):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO clarification (id, kind, text, status, created_at)"
                  " VALUES (?,'gap',?,?, '2026-09-22T10:00:00+00:00')", (cid, text, status))
        c.commit()


# ---------- duyệt


def test_duyet_lam_ke_hoach_QUA_cong(du_an):
    """Phép đo trung tâm: `code.generate_module` đọc `decision` trong TỆP kế hoạch để thực hiện
    tiền điều kiện của chính nó (CODE-01 grounding "G1 approved"). Nên sau khi người duyệt,
    quyết định phải nằm ở chỗ mã đi tìm, không chỉ ở sổ cái."""
    r, ctx, root = du_an
    run = r.quyet_dinh(KHOA, "approve", by="human", note="bo Uno 16MHz, tôi chịu", ctx_goi_y=ctx)
    assert run.status == "done", run.error
    qd = (doc_plan_feature(root, "F-01") or {}).get("decision") or {}
    assert qd["decision"] == "APPROVE" and qd["by"] == "human"
    assert qd["rule"] == "G1-HUMAN" and "16MHz" in qd["reason"]


def test_giu_lai_may_da_noi_gi(du_an):
    """POLICY-06 (POL-17 §7) học từ "tỷ lệ người APPROVE khi máy ASK" — câu ấy chỉ trả lời được
    nếu còn biết máy đã nói gì."""
    r, ctx, root = du_an
    r.quyet_dinh(KHOA, "approve", ctx_goi_y=ctx)
    truoc = ((doc_plan_feature(root, "F-01") or {}).get("decision") or {}).get("truoc") or {}
    assert truoc["decision"] == "ASK" and truoc["rule"] == "G1-03"


def test_tu_choi_KHONG_xoa_ke_hoach(du_an):
    """Một kế hoạch bị bác vẫn là dữ liệu: người dùng cần đọc lại nó để biết mình vừa bác cái
    gì, và `plan.replan` cần nó làm điểm xuất phát."""
    r, ctx, root = du_an
    run = r.quyet_dinh(KHOA, "reject", note="đừng đụng clock", ctx_goi_y=ctx)
    assert run.status == "rejected" and run.error["code"] == "E3001"
    d = doc_plan_feature(root, "F-01") or {}
    assert d["plan"]["steps"], "kế hoạch bị xoá mất"
    assert d["decision"]["decision"] == "REJECT"


def test_sinh_ma_bi_chan_TRUOC_va_chay_duoc_SAU(du_an):
    """Vòng khép: cổng chặn → người duyệt → cổng mở. Đây là thứ [DEV-176] tồn tại để làm."""
    from eide.caps.code import generate_module  # noqa: F401
    r, ctx, root = du_an

    run = r.invoke("code.generate_module", {"step_ref": "F-01/s1"}, ctx)
    assert run.status == "pending" and run.error["eide_code"] == "E3000"

    r.quyet_dinh(KHOA, "approve", ctx_goi_y=ctx)
    run2 = r.invoke("code.generate_module", {"step_ref": "F-01/s1"}, ctx)
    # Qua được cổng G1 là đủ — bước sau có thể hỏng vì thiếu mô hình, nhưng KHÔNG được là E3000.
    assert not (run2.status == "pending" and run2.error["eide_code"] == "E3000"), run2.error


# ---------- dấu vết


def test_ghi_gate_human_vao_so_cai(du_an):
    """Quyết định của NGƯỜI phải vào sổ cái — nó là nửa còn lại của tín hiệu POLICY-06."""
    r, ctx, _root = du_an
    r.quyet_dinh(KHOA, "approve", note="ok", ctx_goi_y=ctx)
    gh = [x for x in r.ledger.records() if x["kind"] == "gate.human"]
    assert gh and gh[-1]["data"] == {"gate_id": KHOA, "decision": "APPROVE",
                                     "by": "human", "note": "ok"}
    assert r.ledger.verify() == (True, 0)


def test_dien_human_answer_vao_dung_dong(du_an):
    """`_ghi_cong_phu` ([DEV-171]) ghi dòng dưới khoá `<run_id>:<gate>`; câu trả lời của người
    phải rơi vào ĐÚNG dòng ấy, không phải dòng chính của lời gọi."""
    _r, ctx, root = du_an
    r2 = Router(gate=PolicyGate(), ledger=Ledger(root / "l2.jsonl"))
    gate_handlers.dang_ky(r2, ctx)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO decision_log (id, gate, action_cap, risk, autonomy_level,"
                  " decision, by, rule, reason, at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (KHOA, "G1", "plan.create", "R1", "A2", "ASK", "agent", "G1-03", "x",
                   "2026-09-22T10:00:00+00:00"))
        c.commit()
    r2.quyet_dinh(KHOA, "approve", ctx_goi_y=ctx)
    with store.open_store(store.store_path(root)) as c:
        tl = c.execute("SELECT human_answer FROM decision_log WHERE id=?", (KHOA,)).fetchone()
    assert tl and tl[0] == "APPROVE"


def test_dong_diem_can_lam_ro_do_chinh_cong_sinh_ra(du_an):
    """Để nó `open` là bắt người dùng nhìn mãi một câu họ vừa trả lời xong."""
    r, ctx, root = du_an
    _clar(root, "CL-cong", "Kế hoạch `F-01` đang chờ: Kế hoạch `F-01` cần anh duyệt: Cổng G1 …")
    _clar(root, "CL-khac", "Chưa rõ chân GPIO nối với LED")
    r.quyet_dinh(KHOA, "approve", note="bo Uno", ctx_goi_y=ctx)
    with store.open_store(store.store_path(root)) as c:
        ds = dict(c.execute("SELECT id, status FROM clarification").fetchall())
    assert ds["CL-cong"] == "answered", "điểm của cổng còn treo"
    assert ds["CL-khac"] == "open", "đóng nhầm điểm không liên quan"


def test_cau_tra_loi_cua_nut_Duyet_HOAN_TAC_duoc(du_an):
    """Ghi cả vào `clarification_answer` chứ không chỉ đổi `status`: lịch sử chỉ-thêm là nền của
    `restore_answer` ([DEV-151]). Người bấm Duyệt nhầm phải có đường lùi."""
    from eide.caps.req import hoan_tac_cau_tra_loi
    r, ctx, root = du_an
    _clar(root, "CL-cong", "Kế hoạch `F-01` đang chờ: Cổng G1 cần anh duyệt")
    r.quyet_dinh(KHOA, "approve", ctx_goi_y=ctx)
    kq = hoan_tac_cau_tra_loi(root, "CL-cong")
    assert kq["status"] == "open" and "Người duyệt" in kq["da_go"]


# ---------- biên


def test_cong_KHONG_dang_ky_thi_noi_ro(du_an):
    """Quên đăng ký là nút chết. Thông điệp phải nói cổng nào và cổng nào thì duyệt được."""
    r, ctx, _root = du_an
    r.cong_phu_handlers.clear()
    with pytest.raises(EideError) as e:
        r.quyet_dinh(KHOA, "approve", ctx_goi_y=ctx)
    assert e.value.code == "E2000" and "G1" in str(e.value)


def test_khoa_khong_co_hai_cham_van_bao_nhu_cu(du_an):
    """Mục thường không được đi nhầm vào nhánh cổng phụ."""
    r, ctx, _root = du_an
    with pytest.raises(EideError) as e:
        r.quyet_dinh("khong_co_that", "approve", ctx_goi_y=ctx)
    assert e.value.code == "E2000" and "đang chờ" in str(e.value)


def test_khong_tra_duoc_ke_hoach_thi_E2000(du_an):
    r, ctx, root = du_an
    for f in (root / ".eide" / "plans").glob("*.json"):
        f.unlink()
    with pytest.raises(EideError) as e:
        r.quyet_dinh(KHOA, "approve", ctx_goi_y=ctx)
    assert e.value.code == "E2000"


def test_ke_hoach_ghi_TRUOC_ban_va_van_duyet_duoc(du_an):
    """Kế hoạch cũ chưa có `run_id` trong `decision`. Một dự án đang chạy dở không được mất
    đường duyệt vì một lần nâng cấp — lùi về bản mới nhất."""
    r, ctx, root = du_an
    f = next((root / ".eide" / "plans").glob("*.json"))
    d = json.loads(f.read_text(encoding="utf-8"))
    d["decision"].pop("run_id")
    f.write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")
    assert r.quyet_dinh(KHOA, "approve", ctx_goi_y=ctx).status == "done"


def test_chi_NGUOI_duoc_duyet(du_an):
    """APD-08 §1: duyệt mục chờ là quyết định của người."""
    r, ctx, _root = du_an
    with pytest.raises(EideError) as e:
        r.quyet_dinh(KHOA, "approve", by="agent", ctx_goi_y=ctx)
    assert e.value.code == "E3000"
