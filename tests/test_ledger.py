from eide_core.ledger import Ledger


def test_hash_chain_and_verify(tmp_path):
    lg = Ledger(tmp_path / "ledger.jsonl")
    lg.append("cap.run.start", {"run_id": "a", "cap": "project.create"})
    lg.append("cap.run.finish", {"run_id": "a", "status": "done"})
    ok, bad = lg.verify()
    assert ok and bad == 0 and len(lg.records()) == 2
    # giả mạo dòng 1 → chuỗi vỡ
    lines = (tmp_path / "ledger.jsonl").read_text(encoding="utf-8").splitlines()
    lines[0] = lines[0].replace('"project.create"', '"project.archive"')
    (tmp_path / "ledger.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    ok, bad = Ledger(tmp_path / "ledger.jsonl").verify()
    assert not ok and bad == 1


def test_unknown_kind_rejected(tmp_path):
    import pytest

    from eide_core.errors import EideError

    with pytest.raises(EideError) as e:
        Ledger(tmp_path / "l.jsonl").append("weird.event", {})
    assert e.value.code == "E6001"
