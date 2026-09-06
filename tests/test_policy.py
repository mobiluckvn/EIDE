"""PolicyGate theo POL-17 rules.yaml + situations.jsonl (45 tình huống) và APD-08 tầng cứng."""
import json

import pytest

from eide_core.paths import spec_dir
from eide_core.policy import APPROVE, ASK, REJECT, PolicyGate, compile_rule


def test_all_rules_compile():
    """Mọi quy tắc biên dịch được, mã không trùng, và mỗi cổng có quy tắc mặc định.

    Không đếm cứng số quy tắc: thêm quy tắc vào POL-17 §2 là việc hợp lệ (v1.2 thêm cổng G-WL).
    Ba bất biến dưới đây mới là thứ vỡ ra thành lỗi thật — nhất là cái cuối: một cổng không có
    quy tắc bắt hết sẽ trả về "không khớp quy tắc nào" cho một hành động nó lẽ ra phải chặn.
    """
    g = PolicyGate()
    assert g.version
    ids = [r["id"] for r in g.rules]
    assert len(ids) == len(set(ids)), f"mã quy tắc trùng: {sorted({i for i in ids if ids.count(i) > 1})}"
    # `*` không phải một cổng mà là dải quy tắc chung áp cho mọi hành động; chỗ bắt hết của nó
    # là tầng năng lực (APD-08 §4.1 tầng 5), không phải một dòng `when: True` trong bảng này.
    cong = {r["gate"] for r in g.rules} - {"*"}
    thieu = [c for c in cong if not any(r["gate"] == c and r["when"] == "True" for r in g.rules)]
    assert not thieu, f"cổng không có quy tắc mặc định: {sorted(thieu)}"


def test_unsafe_expression_rejected():
    with pytest.raises(ValueError):
        compile_rule("__import__('os').system('x')")


def test_trusted_source_auto_approved():
    g = PolicyGate()
    d = g.decide("G-SRC", {"source": {"domain": "st.com", "kind": "svd", "size_mb": 2, "license": "MIT", "hash_match": True}}, risk="R1")
    assert d.decision == APPROVE and d.rule_id == "G-SRC-01"


def test_big_file_asks():
    g = PolicyGate()
    d = g.decide("G-SRC", {"source": {"domain": "st.com", "kind": "pdf_vendor", "size_mb": 80, "license": "vendor-doc"}}, risk="R1")
    assert d.decision == ASK and d.rule_id == "G-SRC-04"


def test_hash_mismatch_rejects():
    g = PolicyGate()
    d = g.decide("G-SRC", {"source": {"domain": "st.com", "kind": "svd", "size_mb": 1, "license": "MIT", "hash_match": False, "expected_hash": "abc"}}, risk="R1")
    assert d.decision == REJECT and d.rule_id == "G-SRC-03"


def test_r4_always_asks_even_at_A4():
    d = PolicyGate().decide("G-OPS", {}, risk="R4", autonomy="A4")
    assert d.decision == ASK and d.rule_id == "HARD-R4"


def test_T1_capability_auto_approves_without_rule():
    d = PolicyGate().decide("*", {}, risk="R2", tier="T1")
    assert d.decision == APPROVE and d.rule_id == "TIER-T1"
    assert PolicyGate().decide("*", {}, risk="R2", tier="T2").decision == ASK


def test_A0_asks_everything():
    d = PolicyGate().decide("G-SRC", {"source": {"domain": "st.com", "kind": "svd", "size_mb": 1, "license": "MIT"}}, risk="R1", autonomy="A0")
    assert d.decision == ASK


def test_board_override_lowers_level():
    g = PolicyGate(config={"boards": {"robot-ctrl": {"autonomy": "A1", "has_actuator": True}}})
    assert g._effective_level("A3", "robot-ctrl") == "A1"
    assert g._effective_level("A3", "nucleo") == "A3"


def test_emergency_stop_blocks():
    g = PolicyGate()
    g.stop()
    d = g.decide("G-SRC", {}, risk="R0")
    assert d.decision == REJECT and d.rule_id == "STOP"


def test_situations_file_parses_and_expected_rules_exist():
    g = PolicyGate()
    ids = {r["id"] for r in g.rules}
    rows = [json.loads(x) for x in (spec_dir() / "policy" / "situations.jsonl").read_text(encoding="utf-8").splitlines() if x.strip()]
    assert len(rows) >= 40
    import re

    for s in rows:
        assert s["expected"].split()[0] in {"APPROVE", "ASK", "REJECT"}, s
        for rule in re.findall(r"\b(?:G-?[A-Z0-9]+-\d+|TOOL-\d+|GEN-\d+)\b", s["expected"]):
            assert rule in ids, s
