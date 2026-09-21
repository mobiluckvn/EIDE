"""Hiện thực hoàn tác — UXC-31 §6.4 "hoàn tác 3 mức", POL-17 §5, tiêu chí N4.

Ba mức, và chúng khác nhau ở thứ người dùng đang hối tiếc:

1. **một commit** — `undo_ref = "commit:<sha>"`. Tác tử ghi một tệp sai, mọi thứ khác vẫn đúng.
2. **cả một lượt chạy** — `undo_ref = "run:<id>"`. Chuỗi đi sai hướng từ bước ba, và người dùng
   muốn xoá dấu vết của cả lượt **mà giữ nguyên những gì chính họ sửa xen giữa** (N4).
3. **về known-good** — `undo_ref = "known-good"` hoặc `"known-good:<tag>"`. Mọi thứ hỏng và
   người dùng muốn về một chỗ từng chạy được.

## Vì sao ở đây chứ không trong `Router`

`Router.hoan_tac()` viết sẵn `self.undo_handlers` rỗng kèm ghi chú "đăng ký từ ngoài để
`undo.apply` không phải biết về từng nhóm năng lực". Lõi không được phụ thuộc vào `eide.caps`:
`eide_core` là gói dùng chung, còn hoàn tác THẬT phải đi qua `code.revert` và `project.rollback`
— tức qua Router, qua cổng chính sách, qua sổ cái, y như mọi lời gọi khác.

Đó cũng là lý do mọi mức ở đây **gọi năng lực** chứ không tự chạy `git`. Một đường `git revert`
đi tắt sẽ ghi vào kho của người dùng mà không qua cổng nào — đúng thứ B2 cấm.

## Trước bản này

`undo_handlers` rỗng suốt, nên mọi lần bấm "Hoàn tác" trả `applied: false` kèm lý do. Câu trả
lời ấy TRUNG THỰC và đã được viết có chủ ý, nhưng nó vẫn là một nút không làm gì.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from eide_core import git
from eide_core.errors import EideError


def dang_ky(router: Any, ctx: Any) -> None:
    """Nối ba hiện thực vào `router.undo_handlers`.

    Gọi ở mọi chỗ dựng `Router` — daemon, CLI, MCP. Quên một chỗ nghĩa là nút Hoàn tác chết ở
    đúng bề mặt ấy, và chết im lặng vì `Router` vẫn trả một câu trả lời hợp lệ.
    """
    router.undo_handlers["git_revert"] = lambda m: _git_revert(router, ctx, m)
    router.undo_handlers["restore_config"] = lambda m: _rollback(router, ctx, m)
    # `delete_created_files` dùng chung đường với `git_revert`: mọi tệp tác tử tạo ra đều nằm
    # trong một commit, nên đảo commit ấy là xoá chúng — và làm thế thì thao tác vẫn nằm trong
    # lịch sử, thay vì một lệnh `rm` không ai truy lại được.
    router.undo_handlers["delete_created_files"] = lambda m: _git_revert(router, ctx, m)
    # [DEV-151] Hoàn tác MỘT LẦN trả lời điểm cần làm rõ. Không đi qua git vì dữ liệu nằm trong
    # store, và không đi qua `restore_config` vì loại ấy đưa CẢ DỰ ÁN về known-good — hoàn tác
    # một câu trả lời bằng cách lùi cả dự án là một phương thuốc tệ hơn bệnh.
    router.undo_handlers["restore_answer"] = lambda m: _go_cau_tra_loi(ctx, m)


def _du_an(ctx: Any) -> Path:
    if not getattr(ctx, "project_dir", None):
        raise EideError("E2000", "Chưa mở dự án nào — không biết hoàn tác trong kho nào",
                        exists=[], candidates=["project.open"], missing=["project_dir"])
    return Path(str(ctx.project_dir)).expanduser()


def _git_revert(router: Any, ctx: Any, muc: dict[str, Any]) -> dict[str, Any]:
    """Mức 1 và mức 2 — phân biệt bằng TIỀN TỐ của `undo_ref`."""
    ref = str(muc.get("undo_ref") or "")
    ly_do = f"hoàn tác theo yêu cầu người dùng ({muc.get('cap') or 'không rõ năng lực'})"
    if ref.startswith("run:"):
        return _revert_ca_run(router, ctx, ref[4:], ly_do)
    if ref.startswith("commit:"):
        return _revert_mot(router, ctx, ref[7:], ly_do)
    raise EideError("E2000", f"Không đọc được `undo_ref` `{ref}` — cần `commit:<sha>` hoặc "
                    "`run:<id>`", exists=[], candidates=["commit:", "run:"], missing=[ref])


def _vi_sao(r: Any) -> str:
    """Lý do THẬT một lời gọi không `done`.

    Bản đầu chỉ ghi `r.status` — "failed" — và nuốt mất `r.error`. Người bấm Hoàn tác khi ấy
    nhận đúng một từ, trong khi lõi đã nói rõ "working tree còn thay đổi chưa commit". Một lớp
    trung gian làm mỏng đi thông điệp của lớp dưới là một lớp làm cho lỗi khó sửa hơn.
    """
    e = getattr(r, "error", None) or {}
    ma = e.get("code") or e.get("ma") or ""
    tin = e.get("message") or e.get("thong_diep") or ""
    if ma or tin:
        return f"{r.status} — {ma} {tin}".strip()
    dec = (getattr(r, "decision", None) or {})
    if dec.get("decision") not in (None, "APPROVE"):
        return f"{r.status} — cổng {dec.get('gate') or '?'} {dec.get('decision')}: " \
               f"{dec.get('reason') or ''}".strip()
    return str(r.status)


def _revert_mot(router: Any, ctx: Any, sha: str, ly_do: str) -> dict[str, Any]:
    r = router.invoke("code.revert", {"commit": sha, "reason": ly_do}, ctx)
    if r.status != "done":
        raise EideError("E7001", f"`code.revert` không chạy được: {_vi_sao(r)}",
                        run=r.run_id, cap="code.revert")
    return {"muc": "commit", "commit": sha,
            "revert_commit": (r.result or {}).get("revert_commit")}


def _revert_ca_run(router: Any, ctx: Any, run_id: str, ly_do: str) -> dict[str, Any]:
    """Mức 2 — **tiêu chí N4**.

    Revert đúng những commit do `agent:run-<id>/*` tạo, theo thứ tự MỚI NHẤT TRƯỚC. Thứ tự ấy
    không phải chi tiết: revert từ cũ trước thì mỗi lần đảo lại làm những commit sau nó xung
    đột, vì chúng sửa tiếp trên nền vừa bị rút đi.

    Commit của NGƯỜI xen giữa không nằm trong danh sách, nên chúng ở nguyên — đó là toàn bộ nội
    dung của N4, và là khác biệt giữa "hoàn tác việc của máy" với "xoá luôn buổi chiều của tôi".

    Một commit revert lỗi thì **dừng ngay và nói ra đã làm tới đâu**. Chạy tiếp sẽ để kho ở một
    trạng thái nửa vời mà không ai biết nửa nào.
    """
    root = _du_an(ctx)
    ds = git.commit_cua_run(root, run_id)
    if not ds:
        raise EideError("E2000", f"Không có commit nào của `agent:run-{run_id}/*` trong kho — "
                        "lượt chạy này chưa ghi gì, hoặc nó chạy trước khi commit của tác tử "
                        "mang tác giả máy-đọc-được",
                        exists=[], candidates=[], missing=[f"run:{run_id}"])
    da: list[str] = []
    for sha in ds:
        try:
            r = _revert_mot(router, ctx, sha, f"{ly_do} — cả lượt chạy {run_id}")
        except EideError as e:
            raise EideError(
                "E7001",
                f"Đảo được {len(da)}/{len(ds)} commit của lượt `{run_id}` rồi dừng ở "
                f"`{sha[:8]}`: {e}. Kho đang ở trạng thái nửa chừng — xem `git log` trước khi "
                "làm tiếp.", done=da, failed=sha, total=len(ds)) from e
        da.append(str(r.get("revert_commit") or ""))
    return {"muc": "run", "run_id": run_id, "reverted": len(da), "revert_commits": da}


def _rollback(router: Any, ctx: Any, muc: dict[str, Any]) -> dict[str, Any]:
    """Mức 3 — về known-good. `undo_ref` có dạng `known-good` hoặc `known-good:<tag>`."""
    ref = str(muc.get("undo_ref") or "")
    tham: dict[str, Any] = {}
    if ":" in ref:
        tham["tag"] = ref.split(":", 1)[1]
    r = router.invoke("project.rollback", tham, ctx)
    if r.status != "done":
        raise EideError("E7001", f"`project.rollback` không chạy được: {_vi_sao(r)}",
                        run=r.run_id, cap="project.rollback")
    return {"muc": "known-good", **(r.result or {}).get("state", {})}


def _go_cau_tra_loi(ctx: Any, muc: dict[str, Any]) -> dict[str, Any]:
    """`restore_answer` — `undo_ref` dạng `clar:<id>`.

    Lịch sử trong `clarification_answer` chỉ thêm, nên hoàn tác nhiều lần thì lùi dần từng bước
    và câu trả lời TRƯỚC đó quay lại — không phải rỗng. Đó là điều "rollback theo từng lần thay
    đổi" thật sự đòi hỏi, và là lý do bảng lịch sử tồn tại.
    """
    from eide.caps.req import hoan_tac_cau_tra_loi
    # `undo_ref` ở đây là MÃ LƯỢT CHẠY — Router đăng ký mọi mục hoàn tác bằng nó. Chấp nhận cả
    # dạng `clar:<id>` cho các mục đăng ký tay hoặc từ bản cũ.
    return hoan_tac_cau_tra_loi(_du_an(ctx), str(muc.get("undo_ref") or ""))
