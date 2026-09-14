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


_NGUON_LA = {"source": {"domain": "raw.githubusercontent.com", "kind": "header",
                        "size_mb": 0.01, "license": "Apache-2.0", "hash_match": True}}


def test_nguoi_duyet_thi_quy_tac_cong_khong_hoi_lai():
    """Người bấm "duyệt" xong thì lời gọi phải CHẠY, không quay lại chính câu hỏi vừa trả lời.

    `Router.quyet_dinh()` duyệt xong chạy lại với `actor="human"`, và nhánh nhường của tầng 5
    nói đó là APPROVE — nhưng tầng 5 chỉ tới khi KHÔNG quy tắc nào khớp, còn mọi mục vào hàng
    đợi thì vào vì một quy tắc ASK vừa khớp ở tầng 3/4. Đo được bằng `search.fetch` +
    `G-SRC-99`: duyệt, bị hỏi lại, duyệt nữa, bị hỏi lại — hàng đợi U2 không đóng được mục nào.

    Test cũ (`test_hang_doi.test_duyet_thi_chay_tiep_khong_hoi_lai`) xanh suốt vì nó dùng
    `kg.resolve_conflict`, một T2 gắn cổng `*` — đúng ca duy nhất rơi xuống tầng 5.
    """
    g = PolicyGate()
    assert g.decide("G-SRC", _NGUON_LA, risk="R1").decision == ASK, "tiền đề: máy thì bị hỏi"
    d = g.decide("G-SRC", _NGUON_LA, risk="R1", actor="human")
    assert d.decision == APPROVE
    assert d.rule_id == "G-SRC-99", "phải mượn id quy tắc, để còn truy được người trả lời câu nào"


def test_nguoi_khong_lat_duoc_mot_lenh_tu_choi():
    """Duyệt là trả lời một câu HỎI. Một quy tắc REJECT không hỏi gì cả — nó nói hành động này
    không được phép, và biến nó thành hỏi-rồi-đồng-ý là bỏ mất ranh giới cứng của POL-17 §1."""
    d = PolicyGate().decide(
        "G-SRC", {"source": {"domain": "st.com", "kind": "svd", "size_mb": 1, "license": "MIT",
                             "hash_match": False, "expected_hash": "abc"}},
        risk="R1", actor="human")
    assert d.decision == REJECT and d.rule_id == "G-SRC-03"


def test_cong_tu_khai_dieu_kien_cho_nguoi_thi_nhanh_chung_khong_chong_len():
    """S48 của POL-17 §8: "người ký nhưng băm không khớp niêm" → vẫn ASK.

    G-WL-01 nói người ký được duyệt *khi niêm khớp*; tức cổng ấy đã khai rằng sự có mặt của
    người là chưa đủ. Nhường chung ở tầng 3/4 mà không đọc điều ấy sẽ mở đường cho một chữ ký
    không còn bảo chứng cho nội dung hiện tại — đúng thứ niêm sinh ra để chặn.
    """
    g = PolicyGate()
    d = g.decide("G-WL", {"actor": "human", "wl": {"verified": False}},
                 risk="R2", autonomy="A3", actor="human")
    assert (d.decision, d.rule_id) == (ASK, "G-WL-99")


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
