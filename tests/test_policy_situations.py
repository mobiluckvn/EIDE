"""POLICY-01 · policy.decide — CDS-12.5; STP-05 TC-51.

tc của hợp đồng là "TC-51 40 tình huống"; `docs/spec/policy/situations.jsonl` có 45. Test này
chạy CẢ 45 qua PolicyGate thật, qua bảng dịch `tests/situations.py`.

Ba tình huống KHÔNG cho ra đúng quy tắc mà fixture ghi. Chúng được liệt kê tường minh dưới đây
chứ không bị bỏ qua lặng lẽ — một fixture chính sách mà test tự nới cho vừa thì không còn là
fixture. Xem DEVIATIONS DEV-011 (lỗi thật) và DEV-012 (cấu trúc bốn tầng).
"""
from __future__ import annotations

import json
import re

import pytest

from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from situations import SITUATIONS


def tinh_huong() -> list[dict]:
    p = spec_dir() / "policy" / "situations.jsonl"
    return [json.loads(x) for x in p.read_text(encoding="utf-8").splitlines() if x.strip()]


def chay(sid: str) -> tuple[str, str]:
    gate, features, kw = SITUATIONS[sid]
    kw = dict(kw)
    g = PolicyGate()
    if kw.pop("stopped", False):
        g.stop()
    d = g.decide(gate, features, **kw)
    return d.decision, d.rule_id


def mong_doi(s: dict) -> tuple[str, str | None]:
    """"APPROVE G-SRC-01" → (APPROVE, G-SRC-01); "ASK (T3 LEVEL)" → (ASK, None)."""
    phan = s["expected"].split()
    rule = phan[1] if len(phan) > 1 and not phan[1].startswith("(") else None
    return phan[0], rule


@pytest.mark.parametrize("s", tinh_huong(), ids=lambda s: s["id"])
def test_45_tinh_huong(s):
    """CẢ 45 khớp fixture từng chữ — quyết định và mã quy tắc.

    Trước 06/09/2026 có ba chỗ lệch (DEV-011, DEV-012); cả ba đã được sửa ở nguồn `pol.js` và
    ở `eide_core/policy.py`, nên bảng miễn trừ đã bị xóa. Không thêm lại: một fixture chính
    sách mà test tự nới cho vừa thì không còn là fixture.
    """
    that = chay(s["id"])
    exp_dec, exp_rule = mong_doi(s)
    assert that[0] == exp_dec, f"{s['id']} ({s['situation']}): mong {exp_dec}, thật {that}"
    if exp_rule is not None:
        assert that[1] == exp_rule, f"{s['id']} ({s['situation']}): mong {exp_rule}, thật {that[1]}"


def test_khong_con_tinh_huong_nao_lech():
    """Chốt con số 0. Một tình huống lệch là một quyết định, không phải một tai nạn."""
    lech = {s["id"] for s in tinh_huong()
            if (lambda t, e: t[0] != e[0] or (e[1] is not None and t[1] != e[1]))(chay(s["id"]), mong_doi(s))}
    assert lech == set(), f"đã có tình huống lệch trở lại: {sorted(lech)}"


def test_nguong_cung_van_neu_ly_do_cu_the(tmp_path):
    """DEV-012: ngưỡng cứng ép ASK nhưng vẫn lấy mã quy tắc cổng để nhật ký nói được điều gì
    sắp xảy ra, không chỉ nói lớp rủi ro.

    Và nó chỉ được SIẾT: một quy tắc APPROVE gặp ngưỡng cứng vẫn phải ra ASK, nếu không thì
    ngưỡng cứng đã bị quy tắc cổng vượt mặt.
    """
    g = PolicyGate()
    d = g.decide("G-OPS", {"op": "erase_all", "board": {"lab": True}}, risk="R4", autonomy="A4")
    assert (d.decision, d.rule_id) == ("ASK", "G-OPS-02")
    assert "Không hoàn tác" in d.reason

    # G-OPS-04 là APPROVE ("cài gói tin cậy"), nhưng ở A1 lớp R2 vượt mức tự chủ → phải ASK
    d = g.decide("G-OPS", {"op": "install", "package": "renode"}, risk="R2", autonomy="A1")
    assert d.decision == "ASK", f"ngưỡng cứng bị quy tắc cổng vượt mặt: {d}"

    # REJECT mạnh hơn ASK nên được giữ nguyên
    d = g.decide("G3", {"patch": {"constant_guard_violations": 2}}, risk="R4", autonomy="A4")
    assert (d.decision, d.rule_id) == ("REJECT", "G3-03")


def test_bang_dich_phu_het_tinh_huong_cua_spec():
    """Bảng dịch phải phủ ĐÚNG tập tình huống trong spec — không thiếu, không thừa.

    Bất biến là sự phủ nhau, không phải con số: thêm một tình huống vào POL-17 §8 là việc hợp
    lệ và thường xuyên (v1.2 thêm S46–S48 cho cổng G-WL). Viết cứng "== 45" biến mỗi lần mở
    rộng đặc tả thành một test đổ ở chỗ không liên quan, và cái giá của việc ấy là người ta sửa
    con số cho qua mà không đọc xem tình huống mới có được dịch đúng không.
    """
    ids = {s["id"] for s in tinh_huong()}
    assert ids == set(SITUATIONS), f"bảng dịch lệch: thiếu {ids - set(SITUATIONS)}, thừa {set(SITUATIONS) - ids}"
    assert len(ids) >= 45, f"spec chỉ còn {len(ids)} tình huống — TC-51 đòi tối thiểu 45"


def test_moi_quy_tac_fixture_nhac_toi_deu_ton_tai():
    ids = {r["id"] for r in PolicyGate().rules}
    for s in tinh_huong():
        for rule in re.findall(r"\b(?:G-?[A-Z0-9]+-\d+|TOOL-\d+|GEN-\d+)\b", s["expected"]):
            assert rule in ids, s


def test_bao_cao_quy_tac_khong_duoc_tinh_huong_nao_cham():
    """Khoảng trống của fixture phải nhìn thấy được, không nằm im.

    45 tình huống chạm tới 38/46 quy tắc (trước khi sửa DEV-011/DEV-012 là 35). Tám quy tắc
    còn lại chưa từng được chứng minh là chạy đúng — trong đó `G-SRC-05` (license không rõ) và
    `GEN-03` (xóa/ghi đè dự án) là những cái đáng có tình huống nhất, vì cả hai đều chặn thứ
    khó hoàn tác. Test này KHÔNG đỏ; nó giữ con số ấy khỏi tụt đi trong im lặng.
    """
    het = {r["id"] for r in PolicyGate().rules}
    cham = {chay(sid)[1] for sid in SITUATIONS}
    thieu = het - cham
    assert thieu == {"G-SRC-05", "G4-02", "G5-03", "G5-99",
                     "GEN-01", "GEN-02", "GEN-03", "TOOL-04"}, (
        f"độ phủ fixture đã đổi — nay thiếu: {sorted(thieu)}")


# ---------- năng lực policy.decide ----------

def _router(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))


def test_nang_luc_tra_dung_nhu_goi_truc_tiep(tmp_path):
    """Gọi qua Router phải cho cùng câu trả lời với gọi PolicyGate trực tiếp — nếu không thì
    có hai chính sách trong một sản phẩm."""
    r = _router(tmp_path)
    for sid, (gate, features, kw) in SITUATIONS.items():
        if kw.get("stopped"):
            continue
        run = r.invoke("policy.decide", {
            "action": {"cap": "search.fetch", "gate": gate, "risk": kw["risk"], "features": features},
            # `actor` phải đi cùng, không chỉ `autonomy`/`tier`. Hai đường chỉ so được với nhau
            # khi nhận CÙNG đầu vào; bỏ `actor` thì đường Router luôn chạy như tác tử, và bài
            # này im lặng không kiểm được bất kỳ quy tắc nào nói về người (G-WL-01, P-EDIT-02).
            "ctx": {"autonomy": kw.get("autonomy"), "tier": kw.get("tier", "T2"),
                    "actor": kw.get("actor", "agent")},
        }, Context())
        assert run.status == "done", (sid, run)
        d = run.result["decision"]
        assert (d["decision"], d["rule"]) == chay(sid), sid


def test_vi_du_trong_hop_dong_chay_duoc(tmp_path):
    """"Ví dụ gọi" của CDS phải qua được input_schema và cho ra quyết định."""
    import json as _json

    from eide_core.registry import get_registry
    vd = _json.loads(get_registry().get("policy.decide").spec.example)
    run = _router(tmp_path).invoke("policy.decide", vd, Context())
    assert run.status == "done", run
    assert run.result["decision"]["decision"] in ("APPROVE", "ASK", "REJECT")


def test_dung_khan_chan_moi_thu_qua_nang_luc(tmp_path):
    """S40 đi qua Router: emergency_stop rồi decide phải ra REJECT STOP.

    `actor="human"` không phải mẹo cho test qua: policy.emergency_stop là T3 — theo APD-08 mức
    T3 nghĩa là NGƯỜI làm. Nút "■ Dừng khẩn" (UXD U6, phím ⌘⇧.) là người bấm, và PolicyGate
    duyệt thẳng vì lời gọi của người chính là quyết định của người. Nếu gọi với actor="agent"
    thì tầng 5 trả ASK — tác tử phải xin phép để dừng, đúng như thiết kế.
    """
    r = _router(tmp_path)
    ctx = Context(actor="human", extra={"gate": r.gate})
    assert r.invoke("policy.emergency_stop", {}, ctx).result == {"stopped": True, "cancelled": []}

    # S40 nói "bất kỳ", và nó có nghĩa đen: sau dừng khẩn, chính `policy.decide` cũng bị Router
    # chặn ở tầng 1 trước khi handler chạy. Không có ngoại lệ cho năng lực "chỉ đọc" — nếu có
    # thì "dừng" đã không còn là một câu trả lời dứt khoát.
    run = r.invoke("policy.decide", {"action": {"gate": "G-SRC", "risk": "R0"}}, ctx)
    assert run.status == "rejected"
    assert run.decision["decision"] == "REJECT" and run.decision["rule"] == "STOP"
    assert run.result is None


def test_decide_khong_tu_no_khi_thieu_dac_trung(tmp_path):
    """Đặc trưng chưa biết ⇒ không được khớp nhánh APPROVE (POL-17 §2, lớp _Ns)."""
    r = _router(tmp_path)
    d = r.invoke("policy.decide", {"action": {"gate": "G-SRC", "risk": "R1", "features": {}}},
                 Context()).result["decision"]
    assert d["decision"] == "ASK"


# ---------- 10 quy tắc KHÔNG tình huống nào của POL-17 §8 chạm tới (đo 12/09/2026)
#
# Bảng 48 tình huống của §8 là bộ kiểm của TÀI LIỆU, và nó không phủ hết 49 quy tắc. Mười quy
# tắc dưới đây vì thế chưa bao giờ được chạy — không phải vì chúng sai, mà vì không ai hỏi tới.
#
# Một quy tắc chưa bao giờ chạy là một quy tắc chưa ai biết có khớp được không: `when` của nó là
# một biểu thức, và một biểu thức sai chính tả (`board.lab` vs `boards.lab`) thì lặng lẽ không
# bao giờ đúng — quy tắc thành quy tắc chết, y hệt `G-OPS-04` trong lỗi im lặng số 5.
#
# Test ở đây gọi thẳng `PolicyGate.decide` với đúng đặc trưng mà `when` cần, nên nó không đụng
# `docs/spec/` — thêm tình huống vào bảng §8 là sửa tài liệu, cần chủ sản phẩm duyệt.

import pytest  # noqa: E402


@pytest.mark.parametrize(("quy_tac", "cong", "dac_trung", "rui_ro", "mong"), [
    # Giấy phép lạ → hỏi người. Không có nó thì một nguồn `unknown` tự tải về.
    ("G-SRC-05", "G-SRC",
     {"source": {"domain": "st.com", "license": "GPL-3.0", "size_mb": 1,
                 "kind": "svd", "hash_match": True}}, "R1", "ASK"),
    # Xoá toàn chip / đốt fuse — ưu tiên 1, tức thắng mọi quy tắc APPROVE khác.
    ("G-OPS-02", "G-OPS", {"op": "erase_all"}, "R3", "ASK"),
    ("G-OPS-02", "G-OPS", {"op": "fuse"}, "R3", "ASK"),
    # Board chưa đánh dấu lab thì mọi thao tác chạm phần cứng đều hỏi.
    ("G-OPS-06", "G-OPS", {"op": "flash", "board": {"lab": False}}, "R3", "ASK"),
    # Kỳ vọng QUAN SÁT ĐƯỢC mà không đạt → REJECT, không phải ASK: máy đã nhìn thấy nó sai.
    ("G4-02", "G4", {"expect": {"machine_observable": True, "all_passed": False}}, "R1",
     "REJECT"),
    # Gói mang tri thức dự án → hỏi trước khi phát hành.
    ("G5-03", "G5", {"pkg": {"contains_project_knowledge": True}}, "R2", "ASK"),
    # Quy tắc bắt hết của G5.
    ("G5-99", "G5", {"pkg": {}}, "R2", "ASK"),
    # Xoá/ghi đè cả dự án — ưu tiên 1.
    ("GEN-03", "*", {"action": {"is_delete_project": True}}, "R2", "ASK"),
    ("GEN-03", "*", {"action": {"is_overwrite_project": True}}, "R2", "ASK"),
])
def test_quy_tac_chua_tinh_huong_nao_cham_van_KHOP_duoc(quy_tac, cong, dac_trung, rui_ro, mong):
    """Mỗi quy tắc phải khớp được ít nhất một lần. Không khớp = quy tắc chết."""
    g = PolicyGate()
    d = g.decide(cong, dac_trung, risk=rui_ro, autonomy="A3", actor="agent")
    assert d.rule_id == quy_tac, f"mong {quy_tac}, nhận {d.rule_id}: {d.reason}"
    assert d.decision == mong


def test_GEN_02_qua_so_lan_thu_lai_thi_hoi_nguoi():
    """`action.fail_count >= thresholds.fail_retries` — một tác tử thử mãi một việc hỏng là một
    tác tử đang đốt token vào một chỗ không tự sửa được."""
    g = PolicyGate()
    n = int((g.config.get("thresholds") or {}).get("fail_retries", 2))
    d = g.decide("*", {"action": {"fail_count": n}}, risk="R1", autonomy="A3", actor="agent")
    assert d.rule_id == "GEN-02" and d.decision == "ASK"
    # Dưới ngưỡng thì KHÔNG chặn — nếu không, lần thử thứ nhất đã phải hỏi người.
    assert g.decide("*", {"action": {"fail_count": n - 1}}, risk="R1", autonomy="A3",
                    actor="agent").rule_id != "GEN-02"


def test_GEN_01_nang_luc_khai_ask_when_thi_hoi():
    """`cap.ask_when_matched` — hợp đồng của từng năng lực tự nói khi nào phải hỏi, và cổng phải
    tôn trọng điều ấy mà không cần biết năng lực nào.

    **Ở R0 thì KHÔNG hỏi**, và đó không phải lỗ hổng: APD-08 §4.1 tầng 2 cho R0 (chỉ đọc) tự
    chạy TRƯỚC khi bảng quy tắc được hỏi tới. Một năng lực chỉ đọc mà khai `ask_when` thì hoặc
    nó không thật sự chỉ đọc — và lớp rủi ro mới là chỗ sai — hoặc `ask_when` của nó nói về một
    thứ không đáng chặn. Bài này ghim cả hai vế để lần sau ai đổi ngưỡng cứng còn thấy.
    """
    g = PolicyGate()
    assert g.decide("*", {"cap": {"ask_when_matched": True}}, risk="R0", autonomy="A3",
                    actor="agent").rule_id == "R0"
    for rr in ("R1", "R2"):
        d = g.decide("*", {"cap": {"ask_when_matched": True}}, risk=rr, autonomy="A3",
                     actor="agent")
        assert d.rule_id == "GEN-01" and d.decision == "ASK", rr


def test_TOOL_04_cong_cu_R3_da_dung_nhieu_lan_tren_board_lab_thi_tu_chay():
    """Quy tắc APPROVE duy nhất trong mười cái — và nó cần BA điều kiện cùng lúc. Thiếu một
    điều kiện mà vẫn duyệt là chỗ một công cụ tự viết được chạy lên phần cứng."""
    g = PolicyGate()
    tool = {"risk": "R3", "uses_ok": 3, "tested": True, "effects_ok": True}
    du = {"tool": tool, "board": {"lab": True}}
    assert g.decide("G-TOOL", du, risk="R3", autonomy="A3",
                    actor="agent").rule_id == "TOOL-04"
    for thieu in ({"tool": {**tool, "uses_ok": 2}, "board": {"lab": True}},
                  {"tool": tool, "board": {"lab": False}},
                  # Chưa test / chưa soát hiệu ứng thì TOOL-03 (ưu tiên 1) REJECT trước — một
                  # công cụ tác tử tự viết chưa ai chạy thử không được chạm phần cứng, dù nó đã
                  # dùng trót lọt bao nhiêu lần trên board lab.
                  {"tool": {**tool, "tested": False}, "board": {"lab": True}}):
        assert g.decide("G-TOOL", thieu, risk="R3", autonomy="A3",
                        actor="agent").rule_id != "TOOL-04"


def test_MOI_quy_tac_trong_rules_yaml_deu_khop_duoc_it_nhat_mot_lan():
    """Cổng chặn cho cả lớp: một quy tắc không bao giờ khớp là một quy tắc chết, và nó chết
    LẶNG LẼ — bảng vẫn có nó, báo cáo vẫn đếm nó.

    Bài này không tự dựng đặc trưng cho từng quy tắc (bất khả); nó kiểm rằng mọi quy tắc đều
    được MỘT trong hai nguồn chạm tới: 48 tình huống của POL-17 §8, hoặc các bài ngay trên.
    """
    import json
    import pathlib

    import yaml

    from eide_core.paths import spec_dir

    rl = yaml.safe_load((spec_dir() / "policy" / "rules.yaml").read_text(encoding="utf-8"))["rules"]
    sit = [json.loads(x) for x in
           (spec_dir() / "policy" / "situations.jsonl").read_text(encoding="utf-8").splitlines()
           if x.strip()]
    phu = {s["expected"].split()[-1] for s in sit}
    ma_test = pathlib.Path(__file__).read_text(encoding="utf-8")
    thieu = [r["id"] for r in rl
             if r["id"] not in phu and f'"{r["id"]}"' not in ma_test]
    assert not thieu, f"quy tắc không tình huống NÀO và không test nào chạm: {thieu}"
