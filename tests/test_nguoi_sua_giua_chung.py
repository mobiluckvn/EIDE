"""UXC-31 §7.5 và §7.6 — người sửa tay giữa một lượt chạy của tác tử.

Đây là tình huống mà cả hai bên cùng viết vào một kho, và nó là lý do tồn tại của phần lớn
những phép chặn trong sản phẩm. Hai câu hỏi tách bạch:

- §7.5: lượt sau của tác tử có **nhìn thấy** thứ người vừa sửa không, và kế hoạch đang chạy có
  **lập lại** khi người chạm vào vùng của nó không;
- §7.6: khối diff đưa vào ngữ cảnh có bị cắt đúng luật không, và lần cắt ấy có **nói ra** không.
"""
from __future__ import annotations

from dataclasses import replace

from eide.caps.memory import TRAN_DONG_DIFF, _c5_nguoi_sua
from eide_core import git
from test_code import _du_an_git


def _du_an(tmp_path, workspace):
    r, ctx, root = _du_an_git(tmp_path, workspace)
    (root / "src").mkdir(exist_ok=True)
    return r, ctx, root


def _nguoi_luu(r, ctx, root, ten, cu, moi):
    (root / "src" / ten).write_text(cu, encoding="utf-8")
    git.commit(root, f"chore(x): nền {ten}", [f"src/{ten}"])
    run = r.invoke("code.human_save",
                   {"path": f"src/{ten}", "content": moi, "base_content": cu},
                   replace(ctx, actor="human"))
    assert run.status == "done", run.error
    return run


# ---------------------------------------------------------------- §7.5 khối C5

def test_khong_ai_sua_gi_thi_KHONG_co_khoi(tmp_path, workspace):
    """`None`, không phải một khối rỗng.

    Một khối C5 ghi "người không sửa gì" vẫn tốn token của ngân sách và vẫn nói một điều không
    ai hỏi — trong khi ngân sách ấy đang phải chia cho fact phần cứng.
    """
    r, ctx, root = _du_an(tmp_path, workspace)
    assert _c5_nguoi_sua(root, r.ledger) is None


def test_nguoi_sua_thi_khoi_C5_noi_ra_nen_ma_DA_KHAC(tmp_path, workspace):
    r, ctx, root = _du_an(tmp_path, workspace)
    _nguoi_luu(r, ctx, root, "a.c", "int x = 1;\n", "int x = 999;\n")

    kq = _c5_nguoi_sua(root, r.ledger)
    assert kq is not None, "người vừa lưu mà khối C5 vẫn rỗng"
    van, nguon, da_tom_tat = kq
    assert "nền mã đã KHÁC" in van, van
    assert "src/a.c" in van, van
    assert "999" in van, "diff không mang nội dung thật — tác tử sẽ không biết người đổi gì"
    assert da_tom_tat is False
    assert nguon and nguon[0].startswith("human.file_save:"), nguon


def test_chi_lay_lan_luu_SAU_luot_chay_gan_nhat(tmp_path, workspace):
    """Mốc "từ lượt trước" = `run.done` gần nhất. Lấy cả những lần đã kể là kể lại."""
    r, ctx, root = _du_an(tmp_path, workspace)
    _nguoi_luu(r, ctx, root, "cu.c", "cu\n", "CU DA KE\n")
    r.ledger.append("run.done", {"run_id": "r_x", "state": "done"})
    _nguoi_luu(r, ctx, root, "moi.c", "moi\n", "MOI CHUA KE\n")

    van, _, _ = _c5_nguoi_sua(root, r.ledger)
    assert "src/moi.c" in van, van
    assert "src/cu.c" not in van, "kể lại một lần sửa đã nằm trong lượt trước"


# ---------------------------------------------------------------- §7.6 trần 200 dòng

def test_duoi_tran_thi_gui_NGUYEN_VAN(tmp_path, workspace):
    r, ctx, root = _du_an(tmp_path, workspace)
    _nguoi_luu(r, ctx, root, "a.c", "x\n", "".join(f"dong {i}\n" for i in range(20)))
    van, _, da_tom_tat = _c5_nguoi_sua(root, r.ledger)
    assert da_tom_tat is False
    assert "dong 19" in van, "diff ngắn mà vẫn bị cắt"


def test_vuot_tran_thi_tom_tat_VA_NOI_RA_la_da_tom_tat(tmp_path, workspace):
    """**Nói ra là quan trọng ngang việc cắt.** Không nói thì tác tử đọc một bản rút gọn như thể
    đó là toàn bộ thay đổi, rồi kết luận rằng phần nó không thấy là không có."""
    r, ctx, root = _du_an(tmp_path, workspace)
    _nguoi_luu(r, ctx, root, "to.c", "x\n",
               "".join(f"dong rat dai so {i}\n" for i in range(TRAN_DONG_DIFF + 80)))
    van, _, da_tom_tat = _c5_nguoi_sua(root, r.ledger)
    assert da_tom_tat is True, "diff vượt trần mà không tóm tắt"
    assert "ĐÃ TÓM TẮT" in van, van
    assert str(TRAN_DONG_DIFF) in van, "không nói trần là bao nhiêu"


def test_compose_ghi_nhan_lan_tom_tat_vao_compressions(tmp_path, workspace):
    """`compressions` là chỗ CXD-10 §5 ghi mọi phép nén đã áp — một phép nén không ghi vào đó
    là một phép nén không ai truy được khi ngữ cảnh ra kết quả lạ."""
    r, ctx, root = _du_an(tmp_path, workspace)
    _nguoi_luu(r, ctx, root, "to.c", "x\n",
               "".join(f"dong {i}\n" for i in range(TRAN_DONG_DIFF + 80)))
    run = r.invoke("memory.compose", {"role": "coder", "task_ref": "t1"},
                   replace(ctx, extra={**ctx.extra, "ledger": r.ledger}))
    assert run.status == "done", run.error
    b = run.result["bundle"]
    assert "human_diff:summarize" in (b.get("compressions") or []), b.get("compressions")
    assert any(k.get("layer") == "C5" for k in b.get("blocks") or []), b.get("blocks")


# ---------------------------------------------------------------- §7.5 kích replan

def test_nguoi_sua_trung_vung_ke_hoach_thi_ghi_co_lap_lai(tmp_path, workspace):
    """Đánh dấu trên CHÍNH bản ghi lưu, không phải một kiểu sự kiện mới và không phải một lời
    gọi thẳng.

    API-15 khai 34 kiểu sự kiện sổ cái; `plan.replan_needed` không nằm trong đó, và thêm một
    kiểu là sửa hợp đồng cho một dữ kiện vốn thuộc về sự việc đã có. Lần lưu LÀ sự việc.

    `code.human_save` không có Router trong tay; gọi thẳng `plan.replan` từ đó là đi vòng qua
    cổng chính sách. Và lập lại kế hoạch giữa một lần bấm Lưu nghĩa là người dùng bấm ⌘S rồi
    phải chờ một lượt gọi mô hình xong mới thấy chữ "đã lưu".
    """
    import json

    from eide_core import store
    r, ctx, root = _du_an(tmp_path, workspace)

    # Một lượt chạy đang dở, kế hoạch của nó chạm `src/trong-ke-hoach.c`.
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO run (id, intent_id, graph, state, started_at) VALUES (?,?,?,?,?)",
                  ("r_dangchay", None,
                   json.dumps({"nodes": [{"id": "n1", "cap": "code.modify",
                                          "args": {"file": "src/trong-ke-hoach.c"}}]}),
                   "running", "2026-09-21T10:00:00+00:00"))
        c.commit()

    _nguoi_luu(r, ctx, root, "trong-ke-hoach.c", "cu\n", "NGUOI SUA\n")
    co = [x for x in r.ledger.records()
          if x.get("kind") == "human.file_save" and (x.get("data") or {}).get("replan_for")]
    assert co, "người sửa trúng vùng kế hoạch mà bản ghi không đánh dấu gì"
    assert (co[-1]["data"] or {})["replan_for"] == ["r_dangchay"], co[-1]


def test_sua_tep_NGOAI_ke_hoach_thi_khong_ghi_co(tmp_path, workspace):
    """Nửa còn lại của luật. Thiếu nó thì mọi lần lưu đều kích lập lại kế hoạch — và một
    planner chạy mỗi lần bấm ⌘S là cách nhanh nhất để người dùng thôi bấm ⌘S."""
    import json

    from eide_core import store
    r, ctx, root = _du_an(tmp_path, workspace)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO run (id, intent_id, graph, state, started_at) VALUES (?,?,?,?,?)",
                  ("r_dangchay", None,
                   json.dumps({"nodes": [{"id": "n1", "cap": "code.modify",
                                          "args": {"file": "src/khac.c"}}]}),
                   "running", "2026-09-21T10:00:00+00:00"))
        c.commit()

    _nguoi_luu(r, ctx, root, "ngoai.c", "cu\n", "NGUOI SUA\n")
    assert not [x for x in r.ledger.records()
                if x.get("kind") == "human.file_save" and (x.get("data") or {}).get("replan_for")]


def test_doc_duoc_tep_cua_ke_hoach_DANG_CHAY_tu_graph(tmp_path, workspace):
    """Đọc `graph`, không đọc `report`: lượt đang chạy CHƯA có `report`, nên hỏi báo cáo ở đây
    luôn trả rỗng — và rỗng trông y hệt "kế hoạch này không chạm tệp nào"."""
    import json

    from eide.caps.chat import run_dang_chay
    from eide_core import store
    r, ctx, root = _du_an(tmp_path, workspace)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO run (id, intent_id, graph, state, started_at) VALUES (?,?,?,?,?)",
                  ("r1", None,
                   json.dumps({"nodes": [
                       {"id": "n1", "cap": "code.modify", "args": {"file": "a.c"}},
                       {"id": "n2", "cap": "code.merge",
                        "args": {"files": [{"path": "b.c"}, "c.c"]}}]}),
                   "running", "2026-09-21T10:00:00+00:00"))
        c.commit()
    ds = run_dang_chay(root)
    assert ds and ds[0][0] == "r1"
    assert ds[0][1] == {"a.c", "b.c", "c.c"}, ds[0][1]
