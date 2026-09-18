"""view.timeline: `range.days` và `limit` — DEV-132.

Hai phép kiểm cho hai lỗi khác nhau. `days` từng có trong VÍ DỤ của hợp đồng mà không có mã nào
đọc tới, nên bài kiểm phải khẳng định nó LỌC THẬT chứ không chỉ chạy không nổ. `limit` phải cắt
từ ĐUÔI — cắt nhầm đầu thì màn Nhật ký hiện những việc cũ nhất và không ai nhận ra, vì cả hai
đầu đều là dữ liệu thật.
"""
from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from eide.caps.view import timeline
from eide_core.errors import EideError


class _So:
    def __init__(self, ban_ghi):
        self._r = ban_ghi

    def records(self):
        return self._r


def _ctx(monkeypatch, tmp_path, ban_ghi):
    from eide_core.router import Context
    # `.eide/` phải có thật: `view.*` đòi một dự án đang mở, và một ctx trỏ vào thư mục trống
    # ném E2000 trước khi chạm tới bộ lọc — bài kiểm sẽ "đỏ vì đúng lý do sai".
    (tmp_path / ".eide").mkdir(exist_ok=True)
    ctx = Context(project_dir=str(tmp_path))
    ctx.extra["ledger"] = _So(ban_ghi)
    return ctx


def _ghi(n: int, ngay_truoc: float = 0.0):
    t = (datetime.now(UTC) - timedelta(days=ngay_truoc)).isoformat()
    return {"ts": t, "kind": f"k{n}", "actor": "agent", "hash": f"h{n:04d}", "data": {"i": n}}


def test_limit_cat_tu_duoi_va_total_la_so_truoc_khi_cat(tmp_path, monkeypatch):
    ds = [_ghi(i, ngay_truoc=100 - i) for i in range(50)]
    r = timeline({"limit": 5}, _ctx(monkeypatch, tmp_path, ds))
    assert r["total"] == 50
    assert [e["data"]["i"] for e in r["events"]] == [45, 46, 47, 48, 49]


def test_days_loc_that_chu_khong_chi_chay_khong_no(tmp_path, monkeypatch):
    ds = [_ghi(0, ngay_truoc=30), _ghi(1, ngay_truoc=3), _ghi(2, ngay_truoc=1)]
    r = timeline({"range": {"days": 7}}, _ctx(monkeypatch, tmp_path, ds))
    assert [e["data"]["i"] for e in r["events"]] == [1, 2]
    assert r["total"] == 2


def test_tham_so_sai_bao_E1000_chu_khong_im_lang(tmp_path, monkeypatch):
    ctx = _ctx(monkeypatch, tmp_path, [_ghi(0)])
    for tham in ({"limit": 0}, {"limit": "5"}, {"range": {"days": -1}}):
        with pytest.raises(EideError) as e:
            timeline(tham, ctx)
        assert e.value.code == "E1000"
