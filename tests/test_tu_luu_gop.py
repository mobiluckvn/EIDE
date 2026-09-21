"""UXC-31 §5.7 — tự lưu: mặc định TẮT, bật thì các lần liên tiếp gộp thành một commit."""
from __future__ import annotations

from dataclasses import replace

from eide.caps.code import PREF_TU_LUU
from eide_core import git
from test_code import _du_an_git


def _du_an(tmp_path, workspace, tu_luu: bool):
    r, ctx, root = _du_an_git(tmp_path, workspace)
    (root / "src").mkdir(exist_ok=True)
    if tu_luu:
        run = r.invoke("project.preferences",
                       {"key": PREF_TU_LUU, "value": True, "op": "set", "scope": "project"},
                       replace(ctx, actor="human"))
        assert run.status == "done", run.error
    return r, ctx, root


def _luu(r, ctx, root, ten, noi, nen):
    run = r.invoke("code.human_save",
                   {"path": f"src/{ten}", "content": noi, "base_content": nen},
                   replace(ctx, actor="human"))
    assert run.status == "done", run.error
    return run.result["commit"]


def _so_commit(root):
    return len(git.chay(root, "log", "--format=%H").stdout.split())


def test_mac_dinh_TAT_moi_lan_luu_la_mot_commit(tmp_path, workspace):
    """**Mặc định TẮT** — không có khoá `autosave` thì không gộp gì.

    Mặc định bật sẽ commit thay người dùng vào một kho họ chưa kịp hiểu cách EIDE dùng git.
    """
    r, ctx, root = _du_an(tmp_path, workspace, tu_luu=False)
    (root / "src" / "a.c").write_text("v0\n", encoding="utf-8")
    git.commit(root, "chore(x): nền", ["src/a.c"])
    n0 = _so_commit(root)

    _luu(r, ctx, root, "a.c", "v1\n", "v0\n")
    _luu(r, ctx, root, "a.c", "v2\n", "v1\n")
    assert _so_commit(root) == n0 + 2, "tắt tự lưu mà vẫn gộp"


def test_bat_thi_cac_lan_lien_tiep_GOP_thanh_mot(tmp_path, workspace):
    r, ctx, root = _du_an(tmp_path, workspace, tu_luu=True)
    (root / "src" / "a.c").write_text("v0\n", encoding="utf-8")
    git.commit(root, "chore(x): nền", ["src/a.c"])
    n0 = _so_commit(root)

    _luu(r, ctx, root, "a.c", "v1\n", "v0\n")
    _luu(r, ctx, root, "a.c", "v2\n", "v1\n")
    _luu(r, ctx, root, "a.c", "v3\n", "v2\n")

    assert _so_commit(root) == n0 + 1, "ba lần tự lưu liên tiếp phải là MỘT commit"
    assert (root / "src" / "a.c").read_text(encoding="utf-8") == "v3\n"


def test_ROI_TEP_thi_ket_thuc_mach_gop(tmp_path, workspace):
    """"Khi người rời tệp" của §5.7 = lúc điều kiện "chạm đúng một tệp, và là tệp này" hỏng.

    Mạch gộp tự kết thúc mà không cần ai báo — không có sự kiện "rời tệp" nào phải phát đi, và
    không có trạng thái nào phải nhớ giữa hai lời gọi.
    """
    r, ctx, root = _du_an(tmp_path, workspace, tu_luu=True)
    for t in ("a.c", "b.c"):
        (root / "src" / t).write_text("v0\n", encoding="utf-8")
    git.commit(root, "chore(x): nền", ["src/a.c", "src/b.c"])
    n0 = _so_commit(root)

    _luu(r, ctx, root, "a.c", "a1\n", "v0\n")
    _luu(r, ctx, root, "a.c", "a2\n", "a1\n")     # gộp
    _luu(r, ctx, root, "b.c", "b1\n", "v0\n")     # rời tệp → commit MỚI
    _luu(r, ctx, root, "b.c", "b2\n", "b1\n")     # gộp tiếp

    assert _so_commit(root) == n0 + 2, "mỗi tệp một commit, không hơn không kém"
    assert (root / "src" / "a.c").read_text(encoding="utf-8") == "a2\n"
    assert (root / "src" / "b.c").read_text(encoding="utf-8") == "b2\n"


def test_khong_gop_vao_commit_cua_NGUOI_KHAC(tmp_path, workspace):
    """Commit ở đầu nhánh không mang trailer `Eide-Autosave` thì tuyệt đối không gộp vào.

    Gộp nhầm vào một commit thường là **xoá** commit ấy khỏi lịch sử — và nó là commit của một
    người không hề bật tự lưu.
    """
    r, ctx, root = _du_an(tmp_path, workspace, tu_luu=True)
    (root / "src" / "a.c").write_text("v0\n", encoding="utf-8")
    moc = git.commit(root, "feat(x): mốc quan trọng của người khác", ["src/a.c"])

    _luu(r, ctx, root, "a.c", "v1\n", "v0\n")
    assert git.chay(root, "rev-parse", "--verify", "--quiet", f"{moc}^{{commit}}",
                    kiem=False).returncode == 0, "đã nuốt mất commit của người khác"


def test_gop_thi_HUY_muc_hoan_tac_cu(tmp_path, workspace):
    """Commit cũ không còn tồn tại sau khi gộp.

    Để nguyên mục hoàn tác trỏ vào nó là để lại một nút bấm vào sẽ trả E7001 "không có commit"
    — tệ hơn không có nút, vì người dùng tưởng mình còn đường lui.
    """
    r, ctx, root = _du_an(tmp_path, workspace, tu_luu=True)
    (root / "src" / "a.c").write_text("v0\n", encoding="utf-8")
    git.commit(root, "chore(x): nền", ["src/a.c"])

    sha1 = _luu(r, ctx, root, "a.c", "v1\n", "v0\n")
    _luu(r, ctx, root, "a.c", "v2\n", "v1\n")

    het = [x for x in r.ledger.records()
           if x.get("kind") == "undo.expire"
           and (x.get("data") or {}).get("undo_ref") == f"commit:{sha1}"]
    assert het, "gộp xong mà mục hoàn tác cũ vẫn trỏ vào một commit đã biến mất"
