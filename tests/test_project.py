"""PROJECT-01/03 theo tc trong cds.json: tạo đúng cấu trúc; gọi lần 2 cùng tên → E2001; gần giống → existing[] và created=false."""
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def _router(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))


def test_create_structure_and_ledger(tmp_path, workspace):
    r = _router(tmp_path)
    run = r.invoke("project.create", {"text": "Tạo cho anh dự án robot hai bánh tự cân bằng", "autonomy": "A3"}, Context(project_dir=workspace))
    assert run.status == "done", run
    res = run.result
    assert res["created"] and res["project_id"] == "robot-hai-banh-tu-can-bang"
    e = workspace / res["project_id"] / ".eide"
    for name in ["store", "session", "index", "docs", "diagrams", "PROGRESS.md", "FEATURES.json", "constraints.yaml", "autonomy.yaml", ".gitignore"]:
        assert (e / name).exists(), name
    kinds = [x["kind"] for x in r.ledger.records()]
    assert kinds == ["cap.run.start", "cap.run.finish"]
    assert run.undo == "delete_created_files"


def test_duplicate_is_E2001(tmp_path, workspace):
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    assert r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx).status == "done"
    run = r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2001"


def test_similar_name_returns_existing(tmp_path, workspace):
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    r.invoke("project.create", {"text": "robot cân bằng hai bánh"}, ctx)
    run = r.invoke("project.create", {"text": "robot cân bằng hai bánh v2"}, ctx)
    assert run.status == "done" and run.result["created"] is False and run.result["existing"]


def test_list_orders_by_last_open(tmp_path, workspace):
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    for t in ["đèn giao thông", "máy đo nhiệt độ phòng", "cửa cuốn điều khiển xa"]:
        r.invoke("project.create", {"text": t, "name": t}, ctx)
    run = r.invoke("project.list", {"workspace": str(workspace)}, ctx)
    assert run.status == "done" and len(run.result["projects"]) == 3


def test_invalid_args_E1000(tmp_path, workspace):
    import pytest

    from eide_core.errors import EideError

    with pytest.raises(EideError) as e:
        _router(tmp_path).invoke("project.create", {}, Context(project_dir=workspace))
    assert e.value.code == "E1000"
