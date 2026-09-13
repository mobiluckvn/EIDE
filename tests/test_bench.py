"""bench.badge, bench.suggest_skill_fix — BENCH-02/03 (CDS-12.5); BEN-24 (CF/BF/BC); PKG-22.

Đọc: CDS-12.5 BENCH-02 (`tc`: "Badge có hash kiểm được") và BENCH-03 (`tc`: "Đề xuất không tự
áp dụng", tier T2, `ask_when: "Luôn"`).

Hai `tc` ấy là toàn bộ nội dung của bộ test này, và cả hai nói về cùng một thứ: **một khẳng
định phải chỉ ra được bằng chứng, và một đề xuất không được tự biến thành thay đổi.**
"""
from __future__ import annotations

import json

import pytest

from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def rt(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl")), Context()


# ---------------------------------------------------------------- bench.badge


def test_badge_tu_choi_khi_khong_co_bang_chung(rt):
    """BENCH-02 `tc`: "Badge có hash kiểm được".

    Huy hiệu đi theo gói vào registry, nơi người khác thấy nó mà KHÔNG thấy lần chạy sinh ra
    nó. Một nhãn `verified` không kèm `log_ref` nói "tin tôi đi" và không đưa ra cách nào để
    kiểm — đó là lý do năng lực này tồn tại thay vì để người ta ghi thẳng vào `passport.badges`.
    """
    r, ctx = rt
    run = r.invoke("bench.badge",
                   {"id": "eide.stm32f4", "result": {"CF": 0.9, "BF": 0.8, "BC": 0.7}}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"
    assert "log_ref" in run.error["message"]


def test_badge_co_hash_kiem_duoc_va_bam_chinh_ket_qua(rt):
    """Băm KẾT QUẢ, không băm tệp log: tệp log mất được, bị xoay vòng, bị chép đi nơi khác;
    con số trong `result` thì đi cùng huy hiệu mãi mãi."""
    import hashlib

    kq = {"CF": 0.95, "BF": 0.9, "BC": 0.82, "log_ref": "tr_a91f"}
    r, ctx = rt
    ds = r.invoke("bench.badge", {"id": "eide.stm32f4", "result": kq}, ctx).result["badges"]
    assert len(ds) == 1
    b = ds[0]
    assert b["badge"] == "verified" and b["log_ref"] == "tr_a91f"
    assert b["CF"] == 0.95 and b["BC"] == 0.82

    mong = hashlib.sha256(
        json.dumps(kq, ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:16]
    assert b["result_hash"] == mong, "băm phải kiểm lại được từ chính `result`"


def test_badge_thieu_mot_chi_so_thi_khong_goi_la_verified(rt):
    """BEN-24 có BA chỉ số, và một huy hiệu `verified` chỉ có nghĩa khi đủ cả ba.

    Một gói dịch được 100% (CF) mà không nạp nổi (BF) thì vô dụng — nên thiếu một chỉ số là
    `bench-partial`, và huy hiệu phải NÓI RA chỉ số nào thiếu. Người đọc nó trong registry
    không có cách nào khác để biết nó nói về một phần hay toàn bộ.
    """
    r, ctx = rt
    ds = r.invoke("bench.badge",
                  {"id": "g", "result": {"CF": 0.9, "log_ref": "l1"}}, ctx).result["badges"]
    assert ds[0]["badge"] == "bench-partial"
    assert set(ds[0]["missing"]) == {"BF", "BC"}


def test_badge_ghi_vao_passport_va_thay_ban_cu_cung_loai(rt, tmp_path):
    """Hai `verified` cho cùng một gói thì cái cũ chỉ làm người đọc phải tự đoán cái nào còn
    đúng."""
    r, ctx = rt
    ctx.project_dir = tmp_path
    db = store.store_path(tmp_path)
    store.migrate(db, ledger=r.ledger)
    with store.open_store(db) as c:
        c.execute("INSERT INTO passport (id, kind, header, created_at) VALUES (?,?,?,?)",
                  ("eide.stm32f4", "chip", "{}", "2026-09-14T00:00:00Z"))
        c.commit()

    r.invoke("bench.badge", {"id": "eide.stm32f4",
                             "result": {"CF": 1, "BF": 1, "BC": 1, "log_ref": "l1"}}, ctx)
    ds = r.invoke("bench.badge", {"id": "eide.stm32f4",
                                  "result": {"CF": 1, "BF": 1, "BC": 0.5, "log_ref": "l2"}},
                  ctx).result["badges"]
    assert len(ds) == 1, "huy hiệu cùng loại phải THAY, không chồng thêm"
    assert ds[0]["log_ref"] == "l2"

    with store.open_store(db) as c:
        luu = json.loads(c.execute("SELECT badges FROM passport WHERE id = ?",
                                   ("eide.stm32f4",)).fetchone()[0])
    assert luu[0]["log_ref"] == "l2", "phải ghi xuống store, không chỉ trả về"


def test_badge_khong_co_passport_van_tra_ve_huy_hieu(rt, tmp_path):
    """`registry.pack` đọc huy hiệu từ KẾT QUẢ chứ không từ store, nên gói vẫn mang nó kể cả
    khi hộ chiếu chưa nạp vào dự án này."""
    r, ctx = rt
    ctx.project_dir = tmp_path
    ds = r.invoke("bench.badge",
                  {"id": "chua-co", "result": {"CF": 1, "BF": 1, "BC": 1, "log_ref": "l"}},
                  ctx).result["badges"]
    assert len(ds) == 1 and ds[0]["package"] == "chua-co"


# ---------------------------------------------------------------- suggest_skill_fix


def test_de_xuat_khong_tu_ap_dung_VI_CONG_CHAN_NO(rt):
    """BENCH-03 `tc`: "Đề xuất không tự áp dụng"; tier T2, `ask_when: "Luôn"`.

    Điều giữ `tc` ấy KHÔNG nằm trong mã của năng lực mà nằm ở CỔNG: T2 nghĩa là PolicyGate trả
    ASK trước khi hàm chạy một dòng nào. Bài test gọi qua Router chính vì thế — kiểm bằng cách
    gọi thẳng hàm sẽ bỏ qua đúng cơ chế đang bảo vệ điều này.

    Một skill là quy tắc sinh mã cho cả một họ chip. Sửa nó theo vài ca lỗi mà không ai duyệt
    là để một mẫu hỏng cục bộ viết lại cách EIDE sinh mã cho mọi dự án sau này.
    """
    r, ctx = rt
    ds = [{"skill": "armv7e-m/i2c", "kind": "timeout", "detail": f"ca {i}"} for i in range(4)]
    run = r.invoke("bench.suggest_skill_fix", {"failures": ds}, ctx)
    assert run.status == "pending", "T2 phải dừng ở cổng, không tự chạy"
    assert run.decision["decision"] == "ASK"


def _dx(ds):
    """Gọi thẳng hàm — sau khi bài trên đã chứng minh cổng chặn được nó."""
    from eide.caps.bench import suggest_skill_fix

    return suggest_skill_fix({"failures": ds}, Context())["proposal"]


def test_ket_qua_luon_mang_co_cho_nguoi_duyet():
    r"""Ngay cả khi đã qua cổng, kết quả vẫn phải tự nói rằng nó chưa được áp dụng — người đọc
    nó ở một chỗ khác (hàng đợi, registry) không thấy cổng nào cả."""
    dx = _dx([{"skill": "armv7e-m/i2c", "kind": "timeout"} for _ in range(4)])
    assert dx["applied"] is False and dx["needs_owner"] is True
    assert dx["patterns"][0]["skill"] == "armv7e-m/i2c"
    assert dx["patterns"][0]["count"] == 4


def test_mot_lan_hong_la_nhieu_khong_phai_quy_tac_sai():
    """Dưới ngưỡng lặp thì KHÔNG đề xuất — và nói ra vì sao.

    Im lặng ở đây khiến người gọi tưởng không có gì đáng xem, trong khi thật ra có lỗi nhưng
    chưa đủ thành mẫu.
    """
    dx = _dx([{"skill": "a", "kind": "x"}, {"skill": "b", "kind": "y"}])
    assert dx["patterns"] == []
    assert "nhiễu" in dx["note"]


def test_gom_theo_skill_va_lay_kieu_loi_pho_bien_nhat():
    """Ba ca `timeout` trên cùng một skill là dấu hiệu quy tắc sai; một ca `nack` lẫn vào thì
    không đổi được kết luận ấy."""
    dx = _dx([{"skill": "s1", "kind": "timeout"}] * 3
             + [{"skill": "s1", "kind": "nack"}]
             + [{"skill": "s2", "kind": "timeout"}])
    assert len(dx["patterns"]) == 1, "chỉ s1 đủ ngưỡng lặp"
    p = dx["patterns"][0]
    assert p["skill"] == "s1" and p["kind"] == "timeout"
    assert p["count"] == 3 and p["total"] == 4


def test_ca_loi_khong_ghi_skill_van_duoc_gom():
    """Một ca lỗi không nói nó thuộc skill nào vẫn là dữ liệu — gộp im lặng vào skill đầu tiên
    mới là thứ làm hỏng kết luận."""
    dx = _dx([{"kind": "build"} for _ in range(3)])
    assert dx["patterns"][0]["skill"] == "(không rõ skill)"
