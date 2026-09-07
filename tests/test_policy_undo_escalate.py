"""POLICY-03 · policy.undo_window và POLICY-04 · policy.escalate — CDS-12.5; POL-17 §5, §6.

POLICY-03 tc: "Sau 24 h merge không còn trong danh sách"; steps: "UndoService.list; hết hạn → expire".
POLICY-04 tc: TC-54 — "Năng lực thất bại 2 lần; ngân sách < 20%; ID chip lệch hộ chiếu → mục ASK
trong hàng đợi + thông báo"; steps: "POL-17 §6 kênh theo mức; ghi ledger".
"""
from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from eide_core.undo import KIND_WINDOW, UndoService, doc_cua_so


def _router(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))


def _luc(gio_truoc: float) -> str:
    return (datetime.now(UTC) - timedelta(hours=gio_truoc)).isoformat()


# ---------- cửa sổ theo loại (POL-17 §5) ----------

def test_moi_loai_undo_cua_hop_dong_deu_co_cua_so():
    """POL-17 §5 liệt kê 5 loại hoàn tác; mỗi loại phải ánh xạ vào một cửa sổ của undo_window."""
    assert KIND_WINDOW == {"supersede_facts": "facts", "git_revert": "merge",
                           "reflash_known_good": "flash", "delete_created_files": "files",
                           "restore_config": "files"}


@pytest.mark.parametrize("chuoi,gio", [("72h", 72), ("24h", 24), ("30m", 0.5), ("7d", 168)])
def test_doc_cua_so(chuoi, gio):
    assert doc_cua_so(chuoi) == timedelta(hours=gio)


def test_cua_so_session_khong_phai_thoi_luong():
    """undo_window.flash = "session" — hết hạn theo PHIÊN, không theo đồng hồ (POL-17 §5)."""
    assert doc_cua_so("session") is None


# ---------- POLICY-03 ----------

def test_dang_ky_roi_liet_ke(tmp_path):
    r = _router(tmp_path)
    u = UndoService(r.ledger)
    u.register("cr_1", "delete_created_files", cap="project.create")
    items = r.invoke("policy.undo_window", {}, Context()).result["items"]
    assert len(items) == 1
    assert items[0]["undo_ref"] == "cr_1"
    assert items[0]["kind"] == "delete_created_files"
    assert items[0]["window"] == "files"
    assert items[0]["cap"] == "project.create"


def test_sau_24h_merge_khong_con_trong_danh_sach(tmp_path):
    """tc của hợp đồng, từng chữ: cửa sổ `merge` là 24h."""
    r = _router(tmp_path)
    u = UndoService(r.ledger)
    u.register("cr_moi", "git_revert", cap="code.merge", at=_luc(23))
    u.register("cr_cu", "git_revert", cap="code.merge", at=_luc(25))
    items = r.invoke("policy.undo_window", {}, Context()).result["items"]
    assert [i["undo_ref"] for i in items] == ["cr_moi"]


def test_het_han_thi_ghi_undo_expire(tmp_path):
    """steps: "hết hạn → expire". Hết hạn là một SỰ KIỆN, không phải một phép lọc thầm lặng —
    nếu chỉ lọc thì nhật ký không bao giờ nói được vì sao một việc không còn hoàn tác được."""
    r = _router(tmp_path)
    UndoService(r.ledger).register("cr_cu", "git_revert", cap="code.merge", at=_luc(25))
    r.invoke("policy.undo_window", {}, Context())
    het = [x for x in r.ledger.records() if x["kind"] == "undo.expire"]
    assert len(het) == 1 and het[0]["data"]["undo_ref"] == "cr_cu"
    assert r.ledger.verify() == (True, 0)


def test_khong_ghi_expire_hai_lan(tmp_path):
    """Gọi lại không được sinh thêm sự kiện — nhật ký là bằng chứng, không phải bộ đếm lần gọi."""
    r = _router(tmp_path)
    UndoService(r.ledger).register("cr_cu", "git_revert", cap="code.merge", at=_luc(25))
    r.invoke("policy.undo_window", {}, Context())
    r.invoke("policy.undo_window", {}, Context())
    assert len([x for x in r.ledger.records() if x["kind"] == "undo.expire"]) == 1


def test_facts_72h_dai_hon_merge_24h(tmp_path):
    r = _router(tmp_path)
    u = UndoService(r.ledger)
    u.register("f1", "supersede_facts", cap="kg.review_facts", at=_luc(30))   # còn hạn (72h)
    u.register("m1", "git_revert", cap="code.merge", at=_luc(30))             # hết hạn (24h)
    items = r.invoke("policy.undo_window", {}, Context()).result["items"]
    assert [i["undo_ref"] for i in items] == ["f1"]


def test_flash_het_han_khi_mo_phien_moi(tmp_path):
    """undo_window.flash = "session": nạp lại known-good chỉ hoàn tác được TRONG phiên ấy."""
    r = _router(tmp_path)
    u = UndoService(r.ledger)
    u.register("fl_1", "reflash_known_good", cap="target.flash")
    assert [i["undo_ref"] for i in r.invoke("policy.undo_window", {}, Context()).result["items"]] == ["fl_1"]
    r.ledger.append("session.open", {"session_id": "s2", "project": "p"})
    assert r.invoke("policy.undo_window", {}, Context()).result["items"] == []


def test_da_hoan_tac_thi_khong_con_trong_danh_sach(tmp_path):
    r = _router(tmp_path)
    u = UndoService(r.ledger)
    u.register("cr_1", "delete_created_files", cap="project.create")
    r.ledger.append("undo.apply", {"undo_ref": "cr_1", "by": "human", "result": "ok"})
    assert r.invoke("policy.undo_window", {}, Context()).result["items"] == []


def test_router_tu_dang_ky_undo_sau_khi_chay(tmp_path, workspace):
    """Vòng khép: một năng lực có `undo` khác `none` chạy xong thì phải xuất hiện trong danh sách.

    Không có bước này thì UndoService chỉ là một sổ trống — UXD U2 ("mỗi việc tự làm có nút
    hoàn tác") không có gì để hiển thị.
    """
    r = _router(tmp_path)
    run = r.invoke("project.create", {"text": "dự án đèn giao thông"}, Context(project_dir=workspace))
    assert run.undo == "delete_created_files"
    items = r.invoke("policy.undo_window", {}, Context()).result["items"]
    assert [i["undo_ref"] for i in items] == [run.run_id]
    assert items[0]["cap"] == "project.create"


def test_nang_luc_undo_none_khong_vao_danh_sach(tmp_path):
    r = _router(tmp_path)
    r.invoke("policy.decide", {"action": {"gate": "G-SRC", "risk": "R1"}}, Context())
    assert r.invoke("policy.undo_window", {}, Context()).result["items"] == []


def test_undo_window_khong_nhan_tham_so(tmp_path):
    from eide_core.errors import EideError
    with pytest.raises(EideError) as ei:
        _router(tmp_path).invoke("policy.undo_window", {"x": 1}, Context())
    assert ei.value.code == "E1000"


# ---------- POLICY-04 (TC-54) ----------

def test_queue_luon_co(tmp_path):
    """POL-17 §6: "queue (luôn)"."""
    r = _router(tmp_path)
    out = r.invoke("policy.escalate", {"reason": "fail_retries", "ref": "cr_9"}, Context()).result
    assert out["notified"] == ["queue"]


def test_ngan_sach_thap_thi_thong_bao(tmp_path):
    """TC-54: "ngân sách < 20% → mục ASK trong hàng đợi + THÔNG BÁO"."""
    r = _router(tmp_path)
    out = r.invoke("policy.escalate", {"reason": "budget_low", "ref": "run_3"}, Context()).result
    assert out["notified"] == ["queue", "chat", "notify"]


def test_board_lech_ho_chieu_thi_thong_bao(tmp_path):
    """TC-54: "ID chip lệch hộ chiếu → ... + thông báo"."""
    r = _router(tmp_path)
    out = r.invoke("policy.escalate", {"reason": "board_mismatch", "ref": "disc_1"}, Context()).result
    assert "notify" in out["notified"]


@pytest.mark.parametrize("ly_do", ["risk_r3", "risk_r4"])
def test_lop_rui_ro_cao_thi_thong_bao(tmp_path, ly_do):
    """POL-17 §6: "notify (R3/R4 hoặc ngân sách < warn_pct hoặc board lệch hộ chiếu)"."""
    r = _router(tmp_path)
    out = r.invoke("policy.escalate", {"reason": ly_do, "ref": "cr_1"}, Context()).result
    assert "notify" in out["notified"]


def test_ask_qua_nua_thoi_gian_thi_len_chat(tmp_path):
    """POL-17 §6: "chat (ASK sau timeout/2)"."""
    r = _router(tmp_path)
    out = r.invoke("policy.escalate", {"reason": "ask_timeout", "ref": "q_1"}, Context()).result
    assert out["notified"] == ["queue", "chat"]


def test_level_tuong_minh_de_len_bac_thang(tmp_path):
    """`level` trong input_schema ép mức, và các kênh là bậc thang tích lũy chứ không rời rạc:
    một việc gấp hơn không được BỎ QUA kênh nhẹ hơn."""
    r = _router(tmp_path)
    out = r.invoke("policy.escalate", {"reason": "fail_retries", "ref": "cr_9", "level": "notify"},
                   Context()).result
    assert out["notified"] == ["queue", "chat", "notify"]


def test_du_an_tat_bot_kenh_thi_ton_trong(tmp_path):
    """`escalation.channels` trong autonomy.yaml (POL-17 §5 schema) giới hạn kênh được dùng."""
    gate = PolicyGate(config={"escalation": {"channels": ["queue"]}})
    r = Router(gate=gate, ledger=Ledger(tmp_path / "ledger.jsonl"))
    out = r.invoke("policy.escalate", {"reason": "budget_low", "ref": "x"},
                   Context(extra={"gate": gate})).result
    assert out["notified"] == ["queue"]


def test_escalate_ghi_ledger(tmp_path):
    """steps: "ghi ledger" — kiểu riêng `policy.escalate` (API-15 §7 v1.3, DEV-013).

    Trước v1.3 phải mượn kiểu `question` với cờ `escalated: True`. Dùng chung một kiểu thì chỉ
    số "bao nhiêu việc phải leo thang" của POL-17 §6 không tách được khỏi câu hỏi thường, mà đó
    lại đúng là con số cho biết mức tự chủ đang đặt quá cao hay quá thấp.
    """
    r = _router(tmp_path)
    r.invoke("policy.escalate", {"reason": "budget_low", "ref": "run_3"}, Context())
    q = [x for x in r.ledger.records() if x["kind"] == "policy.escalate"]
    assert len(q) == 1
    assert q[0]["data"] == {"ref": "run_3", "reason": "budget_low",
                            "channels": ["queue", "chat", "notify"], "level": "notify"}
    assert not [x for x in r.ledger.records() if x["kind"] == "question"], "không mượn kiểu nữa"
    assert r.ledger.verify() == (True, 0)


def test_thieu_ref_la_E1000(tmp_path):
    from eide_core.errors import EideError
    with pytest.raises(EideError) as ei:
        _router(tmp_path).invoke("policy.escalate", {"reason": "fail_retries"}, Context())
    assert ei.value.code == "E1000"


def test_ly_do_la_van_len_queue(tmp_path):
    """Lý do không có trong bảng §6 vẫn phải vào hàng đợi — im lặng là kết cục tệ nhất."""
    r = _router(tmp_path)
    out = r.invoke("policy.escalate", {"reason": "chuyen-gi-do-chua-tung-gap", "ref": "x"},
                   Context()).result
    assert out["notified"] == ["queue"]
