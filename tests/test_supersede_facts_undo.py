"""POL-17 §5 `supersede_facts` — loại hoàn tác ĐÔNG NGƯỜI KHAI NHẤT mà lâu nhất không chạy.

18 năng lực khai loại này (`extract.*` ×12, `passport.import`, `kg.review_facts`,
`kg.resolve_conflict`, `kg.supersede`, `board.build_passport`, `registry.pull`) — nhiều hơn bất
kỳ loại nào khác trong bảng POL-17 §5. Tới 22/09/2026 không cái nào hoàn tác được, và lý do
không nằm ở thủ tục: bảng `fact` không có cột nào nói fact đến từ LƯỢT CHẠY nào, nên câu đầu
tiên của thủ tục — "với mỗi fact tự duyệt **của lượt này**" — không có chỗ để hỏi. DEV-170.
"""
from __future__ import annotations

import json

from eide import undo_handlers
from eide_core import store
from eide_core.undo import UndoService
from test_kg import _fact, _nguon, _rt


def _kho(tmp_path, workspace):
    r, ctx, root = _rt(tmp_path, workspace, "dự án hoàn tác fact")
    undo_handlers.dang_ky(r, ctx)
    with store.open_store(store.store_path(root)) as c:
        _nguon(c, "src_a", "st.com")
        _fact(c, "chip:st.stm32f411ce/periph:I2C1", "pin_function", "PB6/PB7", fid="f_pin")
        c.commit()
    return r, ctx, root


def _fact_row(root, fid):
    with store.open_store(store.store_path(root)) as c:
        return c.execute("SELECT status, confirmed_by, supersedes, run_id, confidence"
                         " FROM fact WHERE id=?", (fid,)).fetchone()


def test_fact_mang_dau_luot_chay_da_tao_ra_no(tmp_path, workspace):
    """Mắt xích thiếu. `source_id` nói fact rút từ TÀI LIỆU nào; nó không nói lượt trích xuất
    nào đã rút — và một tài liệu đúng vẫn có thể bị một lượt đọc sai."""
    r, ctx, root = _kho(tmp_path, workspace)
    run = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata rev B", "actor": "policy"}, ctx)
    assert run.status == "done", run.error
    assert _fact_row(root, run.result["new_id"])[3] == run.run_id


def test_hoan_tac_rut_fact_cua_luot_va_tra_fact_truoc_ve_hien_hanh(tmp_path, workspace):
    """Cả ba mệnh đề của POL-17 §5 trong một phép đo.

    Mệnh đề thứ ba là mệnh đề dễ quên nhất và tốn nhất khi quên: nếu lượt chạy đã thay một fact
    cũ, rút lượt chạy đi mà không trả fact cũ về hiện hành thì store mất trắng một tri thức vốn
    có TRƯỚC khi tác tử chạy — hoàn tác phá nhiều hơn thứ nó hoàn tác.
    """
    r, ctx, root = _kho(tmp_path, workspace)
    run = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata rev B", "actor": "policy"}, ctx)
    moi = run.result["new_id"]
    assert _fact_row(root, "f_pin")[0] == "superseded"

    # `project.create` cũng đăng ký một mục (`delete_created_files`), nên danh sách có hai —
    # điều cần đo là mục của lượt này có mặt VÀ mang đúng loại.
    muc = {m["undo_ref"]: m for m in UndoService(r.ledger, {}).list()}
    assert muc[run.run_id]["kind"] == "supersede_facts", muc
    kq = r.hoan_tac(run.run_id, ctx=ctx)
    assert kq["applied"] and kq["kind"] == "supersede_facts", kq

    assert kq["superseded"] == [moi] and kq["restored"] == ["f_pin"], kq
    assert _fact_row(root, moi)[0] == "superseded"
    # Fact TRƯỚC về hiện hành — `normalized` vì chưa ai duyệt nó.
    assert _fact_row(root, "f_pin")[0] == "normalized"

    # Bia mộ: trỏ về fact bị rút, mang lý do `undo:<decision_id>`, và KHÔNG khẳng định gì.
    with store.open_store(store.store_path(root)) as c:
        bia = c.execute("SELECT status, confirmed_by, confidence FROM fact WHERE supersedes=?",
                        (moi,)).fetchone()
    assert bia == ("superseded", f"undo:{run.run_id}", 0.0), bia


def test_hoan_tac_khong_xoa_dong_nao(tmp_path, workspace):
    """KAD-07 §4.1: fact là bản ghi BẤT BIẾN. Hoàn tác xoá dòng thì sau này không ai trả lời
    được vì sao con số ấy từng có mặt — đúng câu người ta hỏi khi đọc lại một quyết định cũ."""
    r, ctx, root = _kho(tmp_path, workspace)
    run = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata", "actor": "policy"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        truoc = c.execute("SELECT count(*) FROM fact").fetchone()[0]
    r.hoan_tac(run.run_id, ctx=ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT count(*) FROM fact").fetchone()[0] == truoc + 1


def test_hoan_tac_chua_fact_NGUOI_da_xac_nhan(tmp_path, workspace):
    """"Với mỗi fact TỰ DUYỆT" — POL-17 §5 nói rõ hai chữ ấy.

    Người xác nhận xong thì lượt chạy không còn là tác giả duy nhất của fact nữa. Rút nó ra
    nhân danh "hoàn tác việc của máy" là xoá một lần người đã quyết.
    """
    r, ctx, root = _kho(tmp_path, workspace)
    run = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata", "actor": "policy"}, ctx)
    moi = run.result["new_id"]
    with store.open_store(store.store_path(root)) as c:
        c.execute("UPDATE fact SET status='verified', confirmed_by='Vũ Trí Công' WHERE id=?",
                  (moi,))
        c.commit()

    kq = r.hoan_tac(run.run_id, ctx=ctx)
    assert kq["superseded"] == [] and kq["restored"] == [], kq
    assert kq["kept"] == [{"fact": moi, "vi_sao": "người đã xác nhận — không phải fact tự duyệt"}]
    assert _fact_row(root, moi)[0] == "verified"
    # Và fact cũ KHÔNG được sống lại: bản người đã duyệt vẫn là bản hiện hành.
    assert _fact_row(root, "f_pin")[0] == "superseded"


def test_hoan_tac_chua_fact_mot_luot_SAU_da_thay(tmp_path, workspace):
    """Rút một fact đã bị lượt sau thay là can thiệp vào một thay đổi MỚI HƠN mà người dùng
    không hề yêu cầu hoàn tác."""
    r, ctx, root = _kho(tmp_path, workspace)
    a = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                  "reason": "errata B", "actor": "policy"}, ctx)
    b = r.invoke("kg.supersede", {"old": a.result["new_id"], "new": {"value": "PB10/PB11"},
                                  "reason": "errata C", "actor": "policy"}, ctx)
    assert b.status == "done", b.error

    kq = r.hoan_tac(a.run_id, ctx=ctx)
    assert kq["superseded"] == [], kq
    assert kq["kept"] == [{"fact": a.result["new_id"], "vi_sao": "một lượt sau đã thay fact này"}]
    assert _fact_row(root, b.result["new_id"])[0] == "reviewed"


def test_hoan_tac_ghi_so_cai_va_nien_lai_store(tmp_path, workspace):
    """`supersede_facts` là loại thứ HAI ghi thẳng vào store (sau `restore_answer`), nên nó phải
    đi qua đúng đường niêm lại — 22/09/2026 chính lỗi ấy làm lần mở dự án kế tiếp hỏng với
    E6000 "store bị ghi ngoài cổng", tức phép kiểm toàn vẹn tố cáo chính EIDE."""
    r, ctx, root = _kho(tmp_path, workspace)
    run = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata", "actor": "policy"}, ctx)
    r.hoan_tac(run.run_id, ctx=ctx)

    ap = [x for x in r.ledger.records() if x["kind"] == "undo.apply"]
    assert ap and ap[-1]["data"]["result"]["applied"] is True
    assert ap[-1]["data"]["result"]["reason"] == f"undo:{run.run_id}"
    assert r.ledger.verify() == (True, 0)
    # Niêm phong còn khớp: mở lại dự án không được kêu E6000.
    ok, chi_tiet = store.verify_seal(store.store_path(root))
    assert ok, chi_tiet


def test_hai_lan_hoan_tac_cung_mot_luot_la_E2000(tmp_path, workspace):
    """Mục đã hoàn tác rời khỏi danh sách (UndoService ghi `undo.apply` rồi loại ra). Lần bấm
    thứ hai phải nói "không còn mục nào", không phải rút thêm một lớp fact nữa."""
    r, ctx, _ = _kho(tmp_path, workspace)
    run = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata", "actor": "policy"}, ctx)
    assert r.hoan_tac(run.run_id, ctx=ctx)["applied"] is True
    from eide_core.errors import EideError
    try:
        r.hoan_tac(run.run_id, ctx=ctx)
    except EideError as e:
        assert e.code == "E2000", e
    else:
        raise AssertionError("bấm hoàn tác lần hai phải báo không còn mục nào")


def test_gia_tri_bia_mo_giu_nguyen_gia_tri_da_rut(tmp_path, workspace):
    """Bia mộ chép lại GIÁ TRỊ bị rút. Một dòng `supersedes` trỏ về đâu đó mà không mang nội
    dung thì đọc lại chuỗi vẫn không biết cái gì vừa bị lấy đi."""
    r, ctx, root = _kho(tmp_path, workspace)
    run = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata", "actor": "policy"}, ctx)
    r.hoan_tac(run.run_id, ctx=ctx)
    with store.open_store(store.store_path(root)) as c:
        gt = c.execute("SELECT value FROM fact WHERE supersedes=?",
                       (run.result["new_id"],)).fetchone()[0]
    assert json.loads(gt) == "PB8/PB9"
