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
            "ctx": {"autonomy": kw.get("autonomy"), "tier": kw.get("tier", "T2")},
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
