from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def test_env_detect_platform(tmp_path):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    env = r.invoke("env.detect", {}, Context()).result["env"]
    assert env["os"] in {"Darwin", "Windows", "Linux"} and env["python"]


def test_env_check_unknown_isa_E2000(tmp_path):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    run = r.invoke("env.check", {"isa": "z80"}, Context())
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_env_check_reports_missing_with_hint(tmp_path):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    rep = r.invoke("env.check", {"isa": "armv7e-m"}, Context()).result["report"]
    assert rep[0]["tool"] == "arm-none-eabi-gcc"
    for row in rep:
        if not row["found"]:
            assert row["ok"] is False and row["install_hint"] is not None


def test_emergency_stop_then_reject(tmp_path):
    gate = PolicyGate()
    r = Router(gate=gate, ledger=Ledger(tmp_path / "l.jsonl"))
    ctx = Context(extra={"gate": gate}, actor="human")  # dừng khẩn là T3: người bấm, hiệu lực tức thì
    assert r.invoke("policy.emergency_stop", {}, ctx).result["stopped"] is True
    run = r.invoke("env.detect", {}, ctx)
    assert run.status == "rejected" and run.error["code"] == "E3001"


def test_set_autonomy_relax_needs_human(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    ctx = Context(project_dir=workspace)
    r.invoke("project.create", {"text": "dự án test", "name": "test"}, ctx)
    # tác tử gọi năng lực T2 → PolicyGate đưa vào hàng đợi (pending), không chạy
    assert r.invoke("policy.set_autonomy", {"level": "A4", "by": "agent"}, Context(project_dir=workspace / "test")).status == "pending"
    pctx = Context(project_dir=workspace / "test", actor="human")
    run = r.invoke("policy.set_autonomy", {"level": "A4", "by": "agent"}, pctx)
    assert run.status == "failed" and run.error["eide_code"] == "E3000"
    assert r.invoke("policy.set_autonomy", {"level": "A4", "by": "human"}, pctx).result["effective"] == "A4"
    assert r.invoke("policy.set_autonomy", {"level": "A1", "by": "agent"}, pctx).result["effective"] == "A1"
