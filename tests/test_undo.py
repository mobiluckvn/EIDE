

def test_hoan_tac_ghi_vao_store_thi_NIEM_LAI(tmp_path, workspace):
    """Đường hoàn tác ghi thẳng vào store phải niêm lại, như mọi lời gọi khác.

    `Router.hoan_tac` gọi thẳng hàm xử lý chứ không qua `invoke`, nên `_niem_lai` không chạy cho
    đường này. Với ba loại cũ điều đó vô hại — chúng đều gọi lại một NĂNG LỰC (`code.revert`,
    `project.rollback`) nên lời gọi bên trong tự niêm. `restore_answer` ghi thẳng vào store, và
    nó là loại đầu tiên làm thế.

    Đo 22/09/2026 qua giao diện: hoàn tác một câu trả lời xong, lần mở dự án kế tiếp hỏng với
    E6000 "store bị ghi ngoài cổng" — phép kiểm toàn vẹn tố cáo chính EIDE.
    """
    from pathlib import Path

    import eide.caps  # noqa: F401
    from eide.caps.req import ghi_clarification
    from eide.undo_handlers import dang_ky
    from eide_core import store
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router
    from eide_core.undo import UndoService

    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    root = Path(r.invoke("project.create", {"text": "niêm sau hoàn tác"},
                         Context(project_dir=workspace)).result["path"])
    ctx = Context(project_dir=root, actor="human:x",
                  extra={"gate": PolicyGate(), "ledger": r.ledger, "router": r})
    dang_ky(r, ctx)
    ghi_clarification(root, [{"kind": "gap", "text": "bao nhiêu MB?"}], cap="req.elicit")
    with store.open_store(store.store_path(root)) as c:
        ma = c.execute("SELECT id FROM clarification").fetchone()[0]
    r.invoke("req.answer_clarification", {"clar_id": ma, "answer": "8 MB"}, ctx)
    ref = [m["undo_ref"] for m in UndoService(r.ledger).list()
           if m.get("cap") == "req.answer_clarification"][0]

    assert r.hoan_tac(ref, by="human", ctx=ctx)["applied"] is True
    ok, chi_tiet = store.verify_seal(store.store_path(root))
    assert ok, f"niêm lệch sau khi hoàn tác: {chi_tiet}"
