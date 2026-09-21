"""UXC-31 §6.4 hoàn tác ba mức (tiêu chí N4) và §6.5 phủ định N5.

Trước bản này `Router.undo_handlers` rỗng: mọi lần bấm Hoàn tác trả `applied: false` kèm lý do.
Câu trả lời ấy trung thực và có chủ ý, nhưng nó vẫn là một nút không làm gì.
"""
from __future__ import annotations

from dataclasses import replace

from eide import undo_handlers
from eide_core import git
from eide_core.undo import UndoService
from test_code import _du_an_git


def _nap(tmp_path, workspace):
    r, ctx, root = _du_an_git(tmp_path, workspace)
    undo_handlers.dang_ky(r, ctx)
    (root / "src").mkdir(exist_ok=True)
    return r, ctx, root


def _ghi(root, ten, noi):
    (root / "src" / ten).write_text(noi, encoding="utf-8")


def _commit_tac_tu(root, ten, noi, run_id, buoc):
    """Một commit mang đúng tác giả máy-đọc-được mà `git.tac_gia` mô tả."""
    _ghi(root, ten, noi)
    return git.commit(root, f"feat(x): tác tử ghi {ten}", [f"src/{ten}"],
                      ai=f"agent:run-{run_id}/step-{buoc}")


def _commit_nguoi(root, ten, noi):
    _ghi(root, ten, noi)
    return git.commit(root, f"chore(x): người sửa {ten}", [f"src/{ten}"], ai="human:congvt")


# ---------------------------------------------------------------- mức 1

def test_muc_1_hoan_tac_mot_commit(tmp_path, workspace):
    """Mức 1 — và nó phải ĐẢO ĐƯỢC THẬT, không chỉ báo `applied: true`."""
    r, ctx, root = _nap(tmp_path, workspace)
    _ghi(root, "a.c", "int x = 1;\n")
    git.commit(root, "chore(x): nền", ["src/a.c"])
    sha = _commit_tac_tu(root, "a.c", "int x = 2;\n", "r_aaa", 1)

    UndoService(r.ledger, {}).register(f"commit:{sha}", "git_revert", cap="code.merge")
    kq = r.hoan_tac(f"commit:{sha}", by="human", ctx=ctx)

    assert kq["applied"] is True, kq
    assert (root / "src" / "a.c").read_text(encoding="utf-8") == "int x = 1;\n"


# ---------------------------------------------------------------- mức 2 (N4)

def test_muc_2_revert_ca_run_GIU_commit_cua_nguoi(tmp_path, workspace):
    """**Tiêu chí N4** — khác biệt giữa "hoàn tác việc của máy" và "xoá luôn buổi chiều của tôi".

    Dàn cảnh đúng thứ tự thật: tác tử ghi hai tệp trong một lượt, người sửa một tệp thứ ba XEN
    GIỮA. Hoàn tác cả lượt phải đảo đúng hai tệp đầu và **không chạm** tệp của người.
    """
    r, ctx, root = _nap(tmp_path, workspace)
    for t in ("a.c", "b.c", "nguoi.c"):
        _ghi(root, t, "nền\n")
    git.commit(root, "chore(x): nền", ["src/a.c", "src/b.c", "src/nguoi.c"])

    _commit_tac_tu(root, "a.c", "tác tử A\n", "r_bbb", 1)
    _commit_nguoi(root, "nguoi.c", "NGƯỜI SỬA — không được mất\n")
    _commit_tac_tu(root, "b.c", "tác tử B\n", "r_bbb", 2)

    UndoService(r.ledger, {}).register("run:r_bbb", "git_revert", cap="chat.orchestrate")
    kq = r.hoan_tac("run:r_bbb", by="human", ctx=ctx)

    assert kq["applied"] is True, kq
    assert kq["reverted"] == 2, kq
    assert (root / "src" / "a.c").read_text(encoding="utf-8") == "nền\n"
    assert (root / "src" / "b.c").read_text(encoding="utf-8") == "nền\n"
    assert (root / "src" / "nguoi.c").read_text(encoding="utf-8") == \
        "NGƯỜI SỬA — không được mất\n", "revert cả lượt đã cuốn theo commit của người (N4)"


def test_chon_dung_lot_chay_khong_dung_lot_khac(tmp_path, workspace):
    """Hai lượt chạy khác nhau thì không được lẫn — `--author` phải khớp ĐÚNG mã lượt."""
    r, ctx, root = _nap(tmp_path, workspace)
    for t in ("a.c", "b.c"):
        _ghi(root, t, "nền\n")
    git.commit(root, "chore(x): nền", ["src/a.c", "src/b.c"])
    _commit_tac_tu(root, "a.c", "lượt 1\n", "r_111", 1)
    _commit_tac_tu(root, "b.c", "lượt 2\n", "r_222", 1)

    assert len(git.commit_cua_run(root, "r_111")) == 1
    assert len(git.commit_cua_run(root, "r_222")) == 1

    UndoService(r.ledger, {}).register("run:r_111", "git_revert", cap="chat.orchestrate")
    r.hoan_tac("run:r_111", by="human", ctx=ctx)
    assert (root / "src" / "a.c").read_text(encoding="utf-8") == "nền\n"
    assert (root / "src" / "b.c").read_text(encoding="utf-8") == "lượt 2\n", "đảo nhầm lượt khác"


def test_lot_chay_khong_ghi_gi_thi_NOI_RA_chu_khong_bao_thanh_cong(tmp_path, workspace):
    """Một lượt không để lại commit nào: nói rõ, đừng báo "đã hoàn tác 0 commit"."""
    import pytest

    from eide_core.errors import EideError
    r, ctx, root = _nap(tmp_path, workspace)
    _ghi(root, "a.c", "x\n")
    git.commit(root, "chore(x): nền", ["src/a.c"])
    UndoService(r.ledger, {}).register("run:r_trong", "git_revert", cap="chat.orchestrate")
    with pytest.raises(EideError) as e:
        r.hoan_tac("run:r_trong", by="human", ctx=ctx)
    assert "chưa ghi gì" in str(e.value)


# ---------------------------------------------------------------- mức 3

def test_muc_3_ve_known_good(tmp_path, workspace):
    """Mức 3 — `project.rollback`. Tag `known-good/*` do `code.merge` đặt."""
    r, ctx, root = _nap(tmp_path, workspace)
    _ghi(root, "a.c", "tốt\n")
    git.commit(root, "chore(x): bản tốt", ["src/a.c"])
    git.dat_tag(root, "known-good/2026-09-21")
    _commit_tac_tu(root, "a.c", "HỎNG\n", "r_ccc", 1)

    UndoService(r.ledger, {}).register("known-good", "restore_config", cap="project.rollback")
    kq = r.hoan_tac("known-good", by="human", ctx=ctx)

    assert kq["applied"] is True, kq
    assert (root / "src" / "a.c").read_text(encoding="utf-8") == "tốt\n"


# ---------------------------------------------------------------- §6.5 phủ định N5

def test_N5_khong_duong_nao_ghi_de_ma_khong_qua_merge_hay_xung_dot(tmp_path, workspace):
    """**§6.5** — dàn cảnh hai bên sửa cùng một vùng, rồi bịt mọi lối ghi đè.

    Không chứng minh được "KHÔNG tồn tại nhánh nào" theo nghĩa tuyệt đối — đó là một mệnh đề
    phủ định mọi đường, cùng hình dạng với B1. Nhưng ba lối ghi mà giao diện và tác tử THỰC SỰ
    dùng thì kiểm được, và cả ba phải từ chối:

    1. người lưu khi tệp đã đổi trên đĩa → `E6004`, tệp giữ nguyên bản của người khác;
    2. tác tử gọi `code.human_save` → `rejected` (P-EDIT-04), tệp không đổi;
    3. `code.modify` ngoài phạm vi → `E8000`.

    Lối ĐÚNG duy nhất còn lại là merge 3 bên (§6.2) hoặc màn xung đột (§6.3).
    """
    r, ctx, root = _nap(tmp_path, workspace)
    tep = root / "src" / "chung.c"
    tep.write_text("goc\n", encoding="utf-8")
    git.commit(root, "chore(x): nền", ["src/chung.c"])

    nguoi = replace(ctx, actor="human")
    # Ai đó (tác tử, hoặc một trình soạn thảo khác) ghi trong lúc người đang gõ.
    tep.write_text("ban cua BEN KIA\n", encoding="utf-8")

    # (1) người lưu với `base_content` cũ → E6004, KHÔNG ghi đè.
    run1 = r.invoke("code.human_save",
                    {"path": "src/chung.c", "content": "ban cua TOI\n",
                     "base_content": "goc\n"}, nguoi)
    assert run1.status != "done", run1
    assert (run1.error or {}).get("eide_code") == "E6004", run1.error
    assert tep.read_text(encoding="utf-8") == "ban cua BEN KIA\n", "đã ghi đè ở lối (1)"

    # (2) tác tử KHÔNG được dùng đường lưu của người.
    tac_tu = replace(ctx, actor="agent", autonomy="A3")
    run = r.invoke("code.human_save",
                   {"path": "src/chung.c", "content": "TAC TU GHI\n", "base_content": "goc\n"},
                   tac_tu)
    assert run.status == "rejected", run
    assert tep.read_text(encoding="utf-8") == "ban cua BEN KIA\n", "đã ghi đè ở lối (2)"

    # (3) `code.modify` ngoài phạm vi cho phép — tham số theo ĐÚNG hợp đồng CODE-02, vì gọi
    #     sai schema thì bài kiểm xanh vì E1000 chứ không vì phép chặn phạm vi.
    #     `Router.invoke` bắt `EideError` và trả một run `failed` — lỗi schema (E1000) thì
    #     ném thẳng vì nó xảy ra TRƯỚC khi có run. Hai đường khác nhau, nên bài này đọc `run`.
    run3 = r.invoke("code.modify", {"file": "../ngoai.c", "intent": "sửa gì đó"}, tac_tu)
    assert run3.status != "done", run3
    assert (run3.error or {}).get("eide_code") in ("E8000", "E2000"), run3.error
    assert tep.read_text(encoding="utf-8") == "ban cua BEN KIA\n", "đã ghi đè ở lối (3)"
