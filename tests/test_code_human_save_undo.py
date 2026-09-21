"""UXC-31 §2F.5 — mục của NGƯỜI nằm trong khối HOÀN TÁC ĐƯỢC như mục của tác tử."""
from __future__ import annotations

from dataclasses import replace

from eide_core.undo import UndoService
from test_code import _du_an_git


def test_nguoi_luu_tep_thi_hoan_tac_duoc(tmp_path, workspace):
    """**Cùng cơ chế, không phân biệt** — §2F.5.

    Trước bản sửa 21/09, `code.human_save` ghi `human.file_save` vào sổ cái và KHÔNG gọi
    `undo.register`, nên khối "Hoàn tác được" ở cột phải chỉ chứa việc của máy. Đó đúng là sự
    phân biệt §2F.5 cấm: người sửa nhầm một tệp thì không có nút nào đảo lại, trong khi tác tử
    sửa nhầm thì có — và hai lần sửa ấy đều là một commit git y hệt nhau.

    Mục này trước đó được ghi "chưa đo được" trong checklist. Nó đo được; câu trả lời là KHÔNG
    ĐẠT, và một mục chưa đo khác hẳn một mục đã đo và trượt.
    """
    r, ctx, root = _du_an_git(tmp_path, workspace)
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "main.c").write_text("int x = 1;\n", encoding="utf-8")

    nguoi = replace(ctx, actor="human")
    run = r.invoke("code.human_save",
                   {"path": "src/main.c", "content": "int x = 2;\n"}, nguoi)
    assert run.status == "done", run.error
    sha = run.result["commit"]

    muc = UndoService(r.ledger, {}).list()
    ref = [m for m in muc if m.get("undo_ref") == f"commit:{sha}"]
    assert ref, f"lần người lưu không vào được khối hoàn tác: {muc}"
    # Nhãn phải là năng lực THẬT. `code.merge` dán lên một lần người bấm Lưu khiến người dùng
    # đọc thấy tác tử vừa merge, trong khi chính họ vừa sửa một tệp.
    assert ref[0]["cap"] == "code.human_save", ref[0]
    assert ref[0]["kind"] == "git_revert", ref[0]


def test_hoan_tac_cua_nguoi_tra_loi_GIONG_HET_cua_tac_tu(tmp_path, workspace):
    """**Cùng cơ chế nghĩa là cùng cả câu trả lời khi cơ chế ấy chưa xong.**

    `Router.undo_handlers` hiện rỗng theo đúng thiết kế đã ghi trong `hoan_tac()`: chưa có hiện
    thực đảo nào, nên mọi lần bấm trả `applied: false` KÈM LÝ DO thay vì im lặng báo thành công.
    Điều §2F.5 đòi là mục của người đi qua đúng đường ấy — không phải một đường thứ hai đảo được
    thật, cũng không phải một đường thứ ba im lặng.

    Bài này cố ý KHÔNG đòi tệp quay về nội dung cũ. Đòi thế là đòi hệ thống hứa một thứ nó đang
    nói thẳng là chưa làm, và một bài kiểm như vậy ép mã đi nói dối cho nó xanh.
    """
    r, ctx, root = _du_an_git(tmp_path, workspace)
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "main.c").write_text("int x = 1;\n", encoding="utf-8")

    nguoi = replace(ctx, actor="human")
    run = r.invoke("code.human_save",
                   {"path": "src/main.c", "content": "int x = 2;\n"}, nguoi)
    kq = r.hoan_tac(f"commit:{run.result['commit']}", by="human", ctx=nguoi)

    assert kq["applied"] is False, "báo hoàn tác thành công trong khi chưa đảo gì"
    assert kq["kind"] == "git_revert"
    assert "chưa có hiện thực" in kq["reason"], kq
    # Lý do phải trỏ đúng năng lực của NGƯỜI, không phải `code.merge`.
    assert "code.human_save" in kq["reason"], kq
