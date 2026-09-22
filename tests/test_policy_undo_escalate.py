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
    """Mỗi loại hoàn tác phải ánh xạ vào một cửa sổ của `undo_window` — POL-17 §5.

    Sáu loại từ v1.3: năm loại của §5 cộng `restore_answer` ([DEV-151]). Năm loại cũ hoàn tác
    một tệp, một commit, hay cả dự án; không loại nào lùi được MỘT DÒNG trong store — mà câu
    trả lời của người cho một điểm cần làm rõ đúng là một dòng như thế.

    Bảng này viết lại NGUYÊN VĂN ở đây cố ý: thêm một loại vào `KIND_WINDOW` mà quên `pol.js`
    thì tài liệu và mã nói hai thứ khác nhau, và test này là chỗ duy nhất bắt được.
    """
    assert KIND_WINDOW == {"supersede_facts": "facts", "git_revert": "merge",
                           "reflash_known_good": "flash", "delete_created_files": "files",
                           "restore_config": "files", "restore_answer": "files"}


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
    # `chain` là dấu lượt chạy mà `Ledger.append` đóng lên MỌI bản ghi ([DEV-156]) — so tập
    # con thay vì so bằng, vì nội dung của mục này mới là thứ test muốn đo.
    assert {k: v for k, v in q[0]["data"].items() if k != "chain"} == {
        "ref": "run_3", "reason": "budget_low",
        "channels": ["queue", "chat", "notify"], "level": "notify"}
    assert (q[0]["data"].get("chain") or {}).get("cap") == "policy.escalate", \
        "bản ghi phải truy được về lời gọi đã sinh ra nó"
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


# ---------- POLICY-02 policy.permit


def _du_an(tmp_path, workspace):
    from eide_core import store
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "lp.jsonl"))
    res = r.invoke("project.create", {"text": "dự án quyền"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, actor="human",
                  extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def test_permit_ghi_vao_store_chu_khong_vao_bo_nho(tmp_path, workspace):
    """tc POLICY-02: TC-03. Quyền phải đọc lại được sau khi daemon khởi động lại."""
    from eide_core import store
    r, ctx, root = _du_an(tmp_path, workspace)
    out = r.invoke("policy.permit", {"op": "flash", "target": "nucleo-f411",
                                     "by": "human", "ttl_s": 900}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        row = c.execute("SELECT op, target, granted_by, expires_at FROM permission WHERE id=?",
                        (out["permission_id"],)).fetchone()
    assert row[:3] == ("flash", "nucleo-f411", "human")
    assert out["expires_at"] == row[3] and row[3] is not None


def test_tac_tu_khong_tu_cap_quyen_cho_minh(tmp_path, workspace):
    """POLICY-02 lỗi "E3000 nếu by≠human".

    Một tác tử tự cấp quyền R3/R4 cho chính nó thì cả cơ chế thành trang trí — cùng lý do
    `eide policy sign` là lệnh CLI chứ không phải năng lực.
    """
    r, ctx, _ = _du_an(tmp_path, workspace)
    ctx.actor = "agent"
    run = r.invoke("policy.permit", {"op": "flash", "by": "agent"}, ctx)
    assert run.status in ("failed", "pending")
    if run.status == "failed":
        assert run.error["eide_code"] == "E3000"


def test_quyen_cua_phien_khac_khong_dung_duoc(tmp_path, workspace):
    """Bước 1: "hết hạn khi đóng phiên". Một quyền còn hạn theo ĐỒNG HỒ nhưng thuộc phiên trước
    vẫn không được dùng — mở lại máy hôm sau thì hoàn cảnh đã khác, phải xin lại."""
    from eide.caps.policy import quyen_con_hieu_luc

    r, ctx, root = _du_an(tmp_path, workspace)
    ctx.session_id = "s_hom_qua"
    r.invoke("policy.permit", {"op": "flash", "by": "human", "ttl_s": 86400}, ctx)
    assert quyen_con_hieu_luc(root, "s_hom_qua", "flash") is True
    assert quyen_con_hieu_luc(root, "s_hom_nay", "flash") is False


def test_quyen_het_han_theo_dong_ho(tmp_path, workspace):
    from eide.caps.policy import quyen_con_hieu_luc

    r, ctx, root = _du_an(tmp_path, workspace)
    r.invoke("policy.permit", {"op": "erase", "by": "human", "ttl_s": -1}, ctx)
    # ttl âm ⇒ coi như không đặt hạn (tới hết phiên), không phải "đã hết hạn ngay".
    assert quyen_con_hieu_luc(root, ctx.session_id, "erase") is True


# ---------- POLICY-06 policy.learn_thresholds


def _quyet_dinh(root, gate, decision, n, *, human_answer=None, undone=False):
    """Bơm n dòng decision_log. `id` là khóa chính nên phải duy nhất qua NHIỀU lần gọi — một
    fixture tự đụng khóa chính là một fixture dựng ra trạng thái store không bao giờ xảy ra."""
    import secrets
    from datetime import UTC, datetime

    from eide_core import store
    with store.open_store(store.store_path(root)) as c:
        for _ in range(n):
            c.execute("INSERT INTO decision_log (id, gate, action_cap, risk, autonomy_level,"
                      " decision, by, rule, reason, human_answer, undone_at, at)"
                      " VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                      (secrets.token_hex(8), gate, "x.y", "R1", "A2", decision,
                       "agent", "R1", "", human_answer,
                       datetime.now(UTC).isoformat() if undone else None,
                       datetime.now(UTC).isoformat()))
        c.commit()


def test_hoc_nguong_chi_DE_XUAT_khong_ap_dung(tmp_path, workspace):
    """tc POLICY-06: TC-55. Bước duy nhất kết thúc bằng "không áp dụng".

    Một hệ thống tự nới ngưỡng cho chính nó dựa trên thống kê hành vi của chính nó là đúng vòng
    lặp mà cả APD-08 dựng lên để tránh.
    """
    r, ctx, root = _du_an(tmp_path, workspace)
    truoc = (ctx.project_dir / ".eide" / "autonomy.yaml").read_text(encoding="utf-8")
    _quyet_dinh(root, "G-FACT", "ASK", 25, human_answer="APPROVE")
    out = r.invoke("policy.learn_thresholds", {"days": 30}, ctx).result
    assert out["proposals"], "25/25 người duyệt sau khi máy hỏi mà không đề xuất gì"
    assert all(p["ap_dung"] is False for p in out["proposals"])
    assert (ctx.project_dir / ".eide" / "autonomy.yaml").read_text(encoding="utf-8") == truoc


def test_duoi_20_mau_thi_khong_de_xuat(tmp_path, workspace):
    """§7: "chỉ khi n ≥ 20". Đề xuất đổi chính sách dựa trên 5 lần là đoán, không phải học."""
    r, ctx, root = _du_an(tmp_path, workspace)
    _quyet_dinh(root, "G-FACT", "ASK", 19, human_answer="APPROVE")
    assert r.invoke("policy.learn_thresholds", {}, ctx).result["proposals"] == []


def test_hai_nguong_khac_nhau_cho_noi_va_siet(tmp_path, workspace):
    """§7: nới cần ≥ 0,9; siết cần ≥ 0,2. Chênh lệch ấy có chủ ý — nới là bỏ bớt một lần hỏi,
    chỉ nên làm khi gần như chắc chắn; siết là thêm một lần hỏi, và một phần năm số lần phải
    hoàn tác đã đủ để nói mức tự chủ hiện tại đang sai."""
    r, ctx, root = _du_an(tmp_path, workspace)
    # 24/30 = 0,80 — chưa đủ để NỚI
    _quyet_dinh(root, "G-FACT", "ASK", 24, human_answer="APPROVE")
    _quyet_dinh(root, "G-FACT", "ASK", 6, human_answer="REJECT")
    # 6/25 = 0,24 — đã đủ để SIẾT
    _quyet_dinh(root, "G-SRC", "APPROVE", 6, undone=True)
    _quyet_dinh(root, "G-SRC", "APPROVE", 19)
    huong = {p["gate"]: p["huong"] for p in r.invoke("policy.learn_thresholds", {}, ctx).result["proposals"]}
    assert "G-FACT" not in huong, "0,80 chưa tới ngưỡng nới 0,9"
    assert huong.get("G-SRC") == "siet"


def test_de_xuat_neu_ro_nguong_nao_va_bang_chung_bao_nhieu(tmp_path, workspace):
    """§7: "mỗi đề xuất là một bản ghi {threshold, from, to, evidence_n, rate}".

    Một đề xuất "nới G-FACT" mà không nêu chỉnh con số nào thì người duyệt không có gì để duyệt.
    """
    r, ctx, root = _du_an(tmp_path, workspace)
    _quyet_dinh(root, "G-FACT", "ASK", 25, human_answer="APPROVE")
    p = r.invoke("policy.learn_thresholds", {}, ctx).result["proposals"][0]
    assert p["threshold"] == "fact_silver_auto"
    assert p["from"] == 0.85 and p["to"] == 0.8, "nới = hạ ngưỡng tự duyệt"
    assert p["evidence_n"] == 25 and p["rate"] == 1.0
    assert "25" in p["ly_do"]


# ---------- E7000: "quá cửa sổ" KHÁC "chưa từng có" (đóng 12/09/2026)

def test_qua_cua_so_hoan_tac_thi_E7000_chu_khong_phai_E2000(tmp_path, workspace):
    """Hai trường hợp khác nhau, và gộp chúng làm một là gửi người dùng đi sai hướng.

    `E7000`: việc ĐÃ xảy ra, đã từng hoàn tác được, cửa sổ đã đóng — người dùng cần biết để đi
    tìm cách sửa khác (revert tay, nạp lại bản cũ), chứ không phải để kiểm lại xem mình gõ đúng
    id chưa. `E2000`: id chưa từng có — lúc ấy mới nên bảo họ xem lại danh sách.

    Tới 12/09/2026 cả hai đều là E2000, và `E7000` khai trong API-15 §3 không chỗ nào ném —
    cùng họ với ba kiểu sự kiện sổ cái vừa vá (lỗi im lặng 12–14).
    """
    from eide_core.errors import EideError
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router
    from eide_core.undo import UndoService

    led = Ledger(tmp_path / "l.jsonl")
    r = Router(gate=PolicyGate(), ledger=led)

    # Một mục đã đăng ký rồi HẾT HẠN: `list()` phát `undo.expire` khi quá hạn.
    u = UndoService(led, {"undo_window": {"facts": "1h"}})
    u.register("r_het_han", "supersede_facts", cap="kg.add_fact",
               at="2020-01-01T00:00:00+00:00")
    assert u.list() == [], "mục quá hạn phải rụng khỏi danh sách"

    with pytest.raises(EideError) as e:
        r.hoan_tac("r_het_han", by="human", ctx=Context(project_dir=workspace))
    assert e.value.code == "E7000" and e.value.data["undo_ref"] == "r_het_han"

    # Id chưa từng có thì vẫn là E2000 — phân biệt được mới có nghĩa.
    with pytest.raises(EideError) as e2:
        r.hoan_tac("r_chua_tung_co", by="human", ctx=Context(project_dir=workspace))
    assert e2.value.code == "E2000"


def test_ban_ghi_undo_CU_khong_lam_chet_ca_danh_sach(tmp_path):
    """Sổ cái là chỉ-thêm: bản ghi do một phiên bản CŨ hơn ghi sẽ nằm đó mãi mãi.

    `cap` được thêm vào `undo.register` sau ngày đầu. Một bản ghi thiếu nó làm `list()` ném
    `KeyError`, và **cả danh sách hoàn tác chết vì một dòng cũ** — đo 15/09/2026 trên dự án
    AVR: `undo.list` trả E1000 "Tham số sai: 'cap'", vùng "Hoàn tác được" của giao diện rỗng
    vĩnh viễn trong khi sáu việc vẫn đang trong hạn.

    Đây là lớp lỗi mà mọi hàm đọc sổ cái đều phải chịu được: dữ liệu cũ không sửa được.
    """
    from datetime import UTC, datetime, timedelta

    from eide_core.ledger import Ledger
    from eide_core.undo import UndoService

    led = Ledger(tmp_path / "l.jsonl")
    han = (datetime.now(UTC) + timedelta(hours=20)).isoformat()
    # Bản ghi CŨ — không có `cap`, đúng hình dạng trước khi trường ấy ra đời.
    led.append("undo.register", {"undo_ref": "r_cu", "kind": "supersede_facts", "window": "facts",
                                 "at": datetime.now(UTC).isoformat(), "deadline": han})
    # Bản ghi MỚI — đủ trường.
    UndoService(led, None).register("r_moi", "supersede_facts", cap="extract.svd")

    ds = UndoService(led, None).list()
    assert len(ds) == 2, f"một bản ghi cũ làm mất cả danh sách: {ds}"
    assert {d["undo_ref"] for d in ds} == {"r_cu", "r_moi"}
    assert next(d for d in ds if d["undo_ref"] == "r_cu")["cap"] is None
    assert next(d for d in ds if d["undo_ref"] == "r_moi")["cap"] == "extract.svd"


def test_ban_ghi_thieu_ca_at_van_sap_xep_duoc(tmp_path):
    """`at` cũng có thể vắng ở bản ghi cũ, và `sort` theo None thì ném TypeError."""
    from eide_core.ledger import Ledger
    from eide_core.undo import UndoService

    led = Ledger(tmp_path / "l.jsonl")
    led.append("undo.register", {"undo_ref": "r1", "kind": "supersede_facts",
                                 "deadline": None})
    UndoService(led, None).register("r2", "supersede_facts", cap="x")
    assert len(UndoService(led, None).list()) >= 1
