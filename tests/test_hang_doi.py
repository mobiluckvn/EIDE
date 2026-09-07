"""Hàng đợi: người duyệt mục ASK và hoàn tác việc đã tự làm — API-15 §2, UXD-13 U2, POL-17 §5 §7.

Đây là mảnh khép vòng cho POLICY-06: `human_answer` và `undone_at` của `decision_log` chỉ được
điền ở hai đường này, và không có chúng thì `policy.learn_thresholds` luôn trả rỗng (DEV-048).
"""
from __future__ import annotations

import pytest

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from eide_core.undo import UndoService


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án hàng đợi"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _mot_muc_cho(r, ctx):
    """`kg.resolve_conflict` khai mức T2 nên tác tử gọi là vào hàng đợi (APD-08 §4.1 tầng 5)."""
    run = r.invoke("kg.resolve_conflict",
                   {"conflict_id": "f_a:f_b", "choice": "a", "actor": "agent"}, ctx)
    assert run.status == "pending", run.status
    return run


def _cot(root, decision_id, cot):
    with store.open_store(store.store_path(root)) as c:
        row = c.execute(f"SELECT {cot} FROM decision_log WHERE id=?",  # noqa: S608 — hằng trong test
                        (decision_id,)).fetchone()
    return row[0] if row else None


# ---------- gate.decide


def test_duyet_thi_chay_tiep_khong_hoi_lai(du_an):
    """Duyệt xong phải CHẠY, không quay lại hàng đợi.

    Lời gọi tiếp theo mang `actor="human"`, nên tầng 5 của APD-08 trả APPROVE. Thiếu cờ ấy thì
    mục vừa duyệt sẽ ASK lại và người bấm duyệt mãi không xong.
    """
    r, ctx, _ = du_an
    cho = _mot_muc_cho(r, ctx)
    ra = r.quyet_dinh(cho.run_id, "approve")
    assert ra.status != "pending", "duyệt rồi mà vẫn chờ"
    assert not [x for x in r.queue if x.run_id == cho.run_id], "mục đã duyệt còn trong hàng đợi"


def test_tu_choi_thi_khong_chay_va_bao_E3001(du_an):
    r, ctx, _ = du_an
    cho = _mot_muc_cho(r, ctx)
    ra = r.quyet_dinh(cho.run_id, "reject", note="chưa đủ bằng chứng")
    assert ra.status == "rejected"
    assert ra.error["code"] == "E3001" and "chưa đủ bằng chứng" in ra.error["message"]


def test_tac_tu_khong_duoc_tu_duyet_muc_cua_minh(du_an):
    """Nếu tác tử tự duyệt được mục nó vừa bị chặn thì cả hàng đợi là trang trí."""
    r, ctx, _ = du_an
    cho = _mot_muc_cho(r, ctx)
    with pytest.raises(EideError) as e:
        r.quyet_dinh(cho.run_id, "approve", by="agent")
    assert e.value.code == "E3000"


def test_duyet_mot_muc_khong_ton_tai_la_E2000(du_an):
    r, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        r.quyet_dinh("khong-co", "approve")
    assert e.value.code == "E2000"


def test_quyet_dinh_chi_nhan_approve_hoac_reject(du_an):
    r, ctx, _ = du_an
    cho = _mot_muc_cho(r, ctx)
    with pytest.raises(EideError) as e:
        r.quyet_dinh(cho.run_id, "maybe")
    assert e.value.code == "E1000"


# ---------- decision_log: nửa còn thiếu của POLICY-06


def test_duyet_ghi_human_answer_vao_decision_log(du_an):
    """POL-17 §7 học từ "tỷ lệ người APPROVE khi máy ASK" — cột này là dữ liệu ấy."""
    r, ctx, root = du_an
    cho = _mot_muc_cho(r, ctx)
    assert _cot(root, cho.run_id, "human_answer") is None
    r.quyet_dinh(cho.run_id, "approve")
    assert _cot(root, cho.run_id, "human_answer") == "APPROVE"


def test_ghi_cau_tra_loi_TRUOC_khi_chay(du_an):
    """Người đã duyệt là một sự thật ĐỘC LẬP với kết quả lần chạy sau đó.

    Phép thử phải là một lần chạy NÉM ngoại lệ, không phải một lần chạy trả `failed`: Router bắt
    lỗi của handler và trả về bình thường, nên ghi sau `invoke` vẫn qua được — test kiểu ấy
    không chứng minh được thứ tự nào cả. Ném ngoại lệ mới tách được hai thứ tự.
    """
    r, ctx, root = du_an
    cho = _mot_muc_cho(r, ctx)
    goc = r.invoke
    r.invoke = lambda *a, **k: (_ for _ in ()).throw(RuntimeError("hỏng giữa chừng"))
    try:
        with pytest.raises(RuntimeError):
            r.quyet_dinh(cho.run_id, "approve")
    finally:
        r.invoke = goc
    assert _cot(root, cho.run_id, "human_answer") == "APPROVE", \
        "câu trả lời của người phải còn lại kể cả khi lần chạy sau đó nổ"


def test_chay_that_van_ghi_cau_tra_loi(du_an):
    """Nhánh bình thường: chạy xong (dù thất bại) thì câu trả lời vẫn ở đó."""
    r, ctx, root = du_an
    cho = _mot_muc_cho(r, ctx)
    ra = r.quyet_dinh(cho.run_id, "approve")
    assert ra.status == "failed", "hai fact không tồn tại thì phải hỏng"
    assert _cot(root, cho.run_id, "human_answer") == "APPROVE"


def test_tu_choi_cung_duoc_ghi(du_an):
    r, ctx, root = du_an
    cho = _mot_muc_cho(r, ctx)
    r.quyet_dinh(cho.run_id, "reject")
    assert _cot(root, cho.run_id, "human_answer") == "REJECT"


# ---------- undo.apply


def test_hoan_tac_chua_hien_thuc_thi_NOI_RA_chu_khong_bao_thanh_cong(du_an):
    """Một nút "hoàn tác" bấm xong mà không hoàn tác gì là thứ tệ hơn không có nút.

    Các loại hoàn tác của POL-17 §5 (git revert, nạp lại known-good, xóa tệp đã tạo) cần năng
    lực chưa hiện thực, nên phải trả `applied: false` kèm lý do.
    """
    r, ctx, _ = du_an
    UndoService(r.ledger).register("cr_x", "git_revert", cap="code.merge")
    ra = r.hoan_tac("cr_x", ctx=ctx)
    assert ra["applied"] is False
    assert "git_revert" in ra["reason"] and "code.merge" in ra["reason"]


def test_hoan_tac_that_thi_ghi_undone_at(du_an):
    """Nửa còn lại của tín hiệu POLICY-06: "tỷ lệ người UNDO khi máy APPROVE" (POL-17 §7)."""
    r, ctx, root = du_an
    xong = r.invoke("kg.build", {}, ctx)
    UndoService(r.ledger).register(xong.run_id, "delete_created_files", cap="kg.build")
    r.undo_handlers["delete_created_files"] = lambda muc: {"da_xoa": 0}
    ra = r.hoan_tac(xong.run_id, ctx=ctx)
    assert ra["applied"] is True and ra["da_xoa"] == 0
    assert _cot(root, xong.run_id, "undone_at")


def test_hoan_tac_luon_ghi_ledger_du_chua_hien_thuc(du_an):
    """Người đã BẤM hoàn tác là một sự kiện, dù việc hoàn tác chưa làm được — nếu không ghi thì
    sau này không ai biết người đã muốn rút lại việc ấy."""
    r, ctx, _ = du_an
    UndoService(r.ledger).register("cr_y", "git_revert", cap="code.merge")
    r.hoan_tac("cr_y", ctx=ctx)
    ap = [x for x in r.ledger.records() if x["kind"] == "undo.apply"]
    assert ap and ap[-1]["data"]["undo_ref"] == "cr_y"
    assert ap[-1]["data"]["result"]["applied"] is False


def test_hoan_tac_muc_het_han_la_E2000(du_an):
    r, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        r.hoan_tac("khong-co", ctx=ctx)
    assert e.value.code == "E2000"


# ---------- vòng khép: POLICY-06 học được từ vận hành THẬT


def test_policy_06_hoc_duoc_tu_hanh_vi_that(du_an):
    """Đây là lý do cả tệp này tồn tại (DEV-048).

    Trước khi có `gate.decide`, hai cột `human_answer`/`undone_at` không bao giờ được điền, nên
    `policy.learn_thresholds` luôn trả rỗng — mà rỗng trông y hệt "không có gì để đề xuất".
    """
    r, ctx, root = du_an
    for _ in range(N := 22):
        cho = _mot_muc_cho(r, ctx)
        r.quyet_dinh(cho.run_id, "approve")

    with store.open_store(store.store_path(root)) as c:
        n = c.execute("SELECT count(*) FROM decision_log WHERE decision='ASK'"
                      " AND human_answer='APPROVE'").fetchone()[0]
    assert n == N, f"chỉ {n}/{N} lần duyệt được ghi lại"

    de_xuat = r.invoke("policy.learn_thresholds", {"days": 30}, ctx).result["proposals"]
    assert de_xuat, "22 lần người duyệt sau khi máy hỏi mà không đề xuất nới gì"
    assert all(p["huong"] == "noi" for p in de_xuat)
    assert all(p["ap_dung"] is False for p in de_xuat), "POLICY-06 chỉ đề xuất, không áp dụng"


# ---------- mục chờ sống qua lần khởi động lại (DEV-049)


def test_muc_cho_song_qua_lan_khoi_dong_lai(du_an):
    """UXD-13 U2 dựng hàng đợi làm nơi "người vào xem việc đang chờ" — nên nó phải BỀN.

    Người thấy một việc chờ hôm nay, tắt máy, mở lại thì nó vẫn phải ở đó. Router thứ hai ở đây
    là một tiến trình daemon mới: nó không thấy gì trong RAM, chỉ đọc được từ store.
    """
    r, ctx, root = du_an
    cho = _mot_muc_cho(r, ctx)

    moi = Router(gate=PolicyGate(), ledger=Ledger(root / ".eide" / "store" / "l2.jsonl"))
    assert moi.queue == [], "Router mới không được thừa hưởng RAM của cái cũ"
    ds = moi.cho_con_lai(ctx)
    assert [x["run_id"] for x in ds] == [cho.run_id]
    assert ds[0]["cap"] == "kg.resolve_conflict"
    assert ds[0]["asked_at"]


def test_duyet_duoc_muc_cua_phien_TRUOC(du_an):
    """Đây mới là điều làm cho hàng đợi bền có ích: không chỉ NHÌN thấy mục cũ mà còn duyệt được."""
    r, ctx, root = du_an
    cho = _mot_muc_cho(r, ctx)

    moi = Router(gate=PolicyGate(), ledger=Ledger(root / ".eide" / "store" / "l2.jsonl"))
    ra = moi.quyet_dinh(cho.run_id, "approve", ctx_goi_y=ctx)
    assert ra.cap == "kg.resolve_conflict", "phải khôi phục đúng năng lực và tham số"
    assert ra.status != "pending"
    assert _cot(root, cho.run_id, "human_answer") == "APPROVE"
    assert moi.cho_con_lai(ctx) == [], "duyệt xong thì mục phải rời hàng đợi"


def test_tham_so_duoc_CHE_BI_MAT_truoc_khi_luu(du_an):
    """API-15 §7: cùng bộ lọc dùng cho nhật ký.

    Tham số của một lời gọi có thể mang khóa API, và một mục chờ nằm trong store hàng tuần là
    chỗ tệ nhất để một khóa nằm lại. Đây cũng là điểm khác biệt với phương án "thêm cột `args`
    vào capability_run": ở đó không có bước lọc nào.
    """
    r, ctx, root = du_an
    run = r.invoke("kg.resolve_conflict",
                   {"conflict_id": "f_a:f_b", "choice": "a",
                    "actor": "agent", "condition": "khóa AIzaSyD-gia-dinh-lo-ra-0123456789"}, ctx)
    assert run.status == "pending"
    with store.open_store(store.store_path(root)) as c:
        w = c.execute("SELECT working FROM run WHERE id=?", (run.run_id,)).fetchone()[0]
    assert "AIzaSyD-gia-dinh-lo-ra-0123456789" not in w, "khóa API bị ghi thẳng vào store"
    assert "AIza" in w, "vẫn giữ đủ đầu chuỗi để truy được là khóa nào"


def test_duyet_xong_thi_nang_luc_CHAY_that(du_an):
    """Quyền theo `ctx.actor`, TÊN theo `params["actor"]` — hai thứ khác nhau.

    Một mục ASK do tác tử tạo mang `params["actor"]="agent"`. Khi người duyệt, Router chạy lại
    với `ctx.actor="human"` nhưng THAM SỐ vẫn là bản gốc. Năng lực nào kiểm quyền theo tham số
    sẽ từ chối chính lệnh người vừa duyệt — nút "duyệt" bấm xong không làm gì, và đúng ở những
    năng lực cần người duyệt nhất (`kg.resolve_conflict` ask "Luôn").

    Phát hiện bằng cách chạy thật qua CLI ở hai tiến trình, không phải bằng đọc mã.
    """
    import hashlib

    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        # `fact.source_id` là khoá ngoại sang `source` — mọi fact phải có nguồn, đó là bất biến
        # của KAD-07 §4.1 và schema cưỡng chế nó.
        c.execute("INSERT INTO source (id,uri,sha256,kind,tier,license) VALUES (?,?,?,?,?,?)",
                  ("src", "u", hashlib.sha256(b"s").hexdigest(), "pdf_vendor", "gold", "MIT"))
        for fid in ("f_a", "f_b"):
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                      " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                      (fid, "part:x", "address", '"0x76"', "src", "parser", "silver", 0.9,
                       "normalized", "A"))
        c.commit()
    store.write_seal(store.store_path(root))

    cho = _mot_muc_cho(r, ctx)
    ra = r.quyet_dinh(cho.run_id, "approve")
    assert ra.status == "done", f"duyệt rồi mà vẫn không chạy: {ra.error}"
    with store.open_store(store.store_path(root)) as c:
        st = dict(c.execute("SELECT id, status FROM fact WHERE id IN ('f_a','f_b')").fetchall())
    assert st == {"f_a": "verified", "f_b": "superseded"}


def test_daemon_thay_VA_duyet_duoc_muc_cua_phien_truoc(du_an):
    """Thấy được mà không duyệt được là trạng thái TỆ HƠN không thấy.

    `queue.list` đọc từ store nên daemon mới thấy mục cũ; nhưng nếu `gate.decide` không truyền
    ngữ cảnh dự án thì Router không biết đọc store nào và trả E2000 cho một mục đang hiện ngay
    trước mắt người dùng. Hai đầu phải khớp nhau.
    """
    from eide.daemon.rpc import Daemon

    r, ctx, root = du_an
    cho = _mot_muc_cho(r, ctx)

    d = Daemon(root)
    assert [x["run_id"] for x in d.queue_list({})["items"]] == [cho.run_id]
    ra = d.gate_decide({"gate_id": cho.run_id, "decision": "approve"})
    assert ra["status"] != "pending", "duyệt qua daemon mà vẫn chờ"
    assert d.queue_list({})["items"] == []
    assert _cot(root, cho.run_id, "human_answer") == "APPROVE"
