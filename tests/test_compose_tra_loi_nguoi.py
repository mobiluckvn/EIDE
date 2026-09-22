"""[DEV-174a] Câu trả lời của NGƯỜI phải vào được ngữ cảnh — nếu không, vòng cộng tác không khép.

Đo 22/09/2026 trên dự án `nhap-nhay-led-tren-atmega328p`: planner hỏi hai câu rất cụ thể, người
dùng trả lời cả hai qua `req.answer_clarification` (cả hai về `answered`), bảo tác tử lập lại kế
hoạch — và **nó hỏi y nguyên câu cũ**. Gói ngữ cảnh vai trò `planner` khi ấy có đúng ba lớp
`['C1','C0','C2']`, 687 token trên ngân sách 9000.

Đây là vế "rồi tôi mới chọn" trong nhịp chủ sản phẩm đặt ra ngày 20/09: người dùng gõ vào một
cái hộp mà tác tử không bao giờ mở.

Kèm nửa thứ hai của cùng một lỗ hổng: `plan.create` nói với mô hình đúng một chuỗi — *"Lập kế
hoạch cho tính năng: F-01"* — trong khi `.eide/FEATURES.json` giữ đủ tiêu đề, kỳ vọng đo được
và ràng buộc. Nên planner hỏi lại *"chưa rõ chu kỳ nhấp nháy (500ms hay 1000ms)"* cho một tính
năng ghi sẵn *"chu kỳ 1 giây (500ms mức cao, 500ms mức thấp)"*.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.memory import _c2_tra_loi_cua_nguoi, _c5_tinh_nang, compose
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

HOI = "Chưa rõ chân GPIO nối với LED"
TRA = "LED nối chân PB5, mức cao là sáng"


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "nhấp nháy LED"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _clar(root, cid, hoi, tra=None, ai="Vũ Trí Công", at="2026-09-22T10:00:00+00:00"):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO clarification (id, kind, text, status, answer, answered_by,"
                  " answered_at, created_at) VALUES (?,'gap',?,?,?,?,?,?)",
                  (cid, hoi, "answered" if tra else "open", tra, ai if tra else None,
                   at if tra else None, at))
        c.commit()


def _feature(root, **k):
    ft = {"id": "F-01", "title": "Nhấp nháy LED trên chân PB5 với chu kỳ 1 giây",
          "expectation": {"kind": "measurement",
                          "detail": "Đo tín hiệu trên PB5 có chu kỳ 1 giây (500ms cao, 500ms thấp)"},
          "constraints": ["PB5 phải là ngõ ra"], "touches": ["PB5", "PORTB", "DDRB"],
          "status": "failing", **k}
    (root / ".eide" / "FEATURES.json").write_text(
        json.dumps({"features": [ft]}, ensure_ascii=False), encoding="utf-8")


def _khoi(b, lop, chua=""):
    return [x for x in b["blocks"] if x["layer"] == lop and chua in x["text"]]


# ---------- (1) câu trả lời vào được ngữ cảnh


def test_cau_tra_loi_vao_goi_ngu_canh(du_an):
    """Phép đo trung tâm: trước bản vá, gói ngữ cảnh không có lớp nào mang câu trả lời."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    b = compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"]
    kh = _khoi(b, "C2", "ĐÃ TRẢ LỜI")
    assert kh, [x["layer"] for x in b["blocks"]]
    assert HOI in kh[0]["text"] and TRA in kh[0]["text"]


def test_noi_ro_day_la_su_that_va_DUNG_HOI_LAI(du_an):
    """Một danh sách hỏi–đáp trần không nói cho mô hình biết phải LÀM GÌ với nó. Câu dẫn là
    phần mang nghĩa: đây là sự thật về dự án, và không hỏi lại."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C2", "ĐÃ TRẢ LỜI")
    assert "KHÔNG hỏi lại" in kh[0]["text"]


def test_diem_CHUA_tra_loi_thi_khong_dua_vao(du_an):
    """Một câu hỏi chưa có đáp án đưa vào ngữ cảnh chỉ là nhắc mô hình hỏi lại."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI)                      # còn `open`
    assert _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"],
                 "C2", "ĐÃ TRẢ LỜI") == []


def test_khoi_RIENG_va_KHONG_cache(du_an):
    """`constraints.yaml` gần như tĩnh nên khối ràng buộc cache được; danh sách câu trả lời đổi
    mỗi lần người gõ một câu. Nhập chung là làm hỏng cache của cả hai."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    c2 = [x for x in compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"]["blocks"]
          if x["layer"] == "C2"]
    assert len(c2) == 2, c2
    assert {x["cacheable"] for x in c2} == {True, False}


def test_KHONG_BAO_GIO_bi_cat(du_an):
    """C2 có `cut_priority = 9`. Một câu người đã trả lời mà bị bỏ lúc ngữ cảnh chật là tệ nhất
    trong các cách quên: người dùng tin rằng họ đã nói rồi."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C2", "ĐÃ TRẢ LỜI")
    assert kh[0]["cut_priority"] >= 9


def test_truy_nguon_ve_tung_diem(du_an):
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C2", "ĐÃ TRẢ LỜI")
    assert kh[0]["sources"] == ["clarification:CL-1"]


def test_cat_theo_tran_va_NOI_RA_da_bo_bao_nhieu(du_an):
    """C2 không cắt được, nên tràn ở đây thành E5001 "không gọi mô hình". Cắt tại chỗ, lấy câu
    MỚI NHẤT trước — và một danh sách bị xén âm thầm đọc y hệt một danh sách đầy đủ."""
    _r, _ctx, root = du_an
    for i in range(40):
        _clar(root, f"CL-{i:02d}", f"{HOI} số {i} " + "x" * 120, f"{TRA} {i}",
              at=f"2026-09-22T10:{i:02d}:00+00:00")
    van, nguon, bo = _c2_tra_loi_cua_nguoi(root, 300)
    assert bo > 0 and f"còn {bo} câu" in van
    assert len(nguon) + bo == 40
    # Mới nhất trước: CL-39 phải có mặt, CL-00 thì không.
    assert "clarification:CL-39" in nguon and "clarification:CL-00" not in nguon


def test_khong_co_bang_thi_khong_no(tmp_path, workspace):
    """Store cũ (user_version < 8) chưa có bảng `clarification`."""
    (workspace / "x" / ".eide").mkdir(parents=True)
    assert _c2_tra_loi_cua_nguoi(workspace / "x", 300) == ("", [], 0)


# ---------- (2) định nghĩa TÍNH NĂNG đang lập kế hoạch


def test_tinh_nang_dang_lap_ke_hoach_vao_C5(du_an):
    """`plan.create` nói với mô hình đúng chuỗi "F-01". Tác tử lập kế hoạch cho một mã hiệu mà
    không được đọc mã hiệu ấy nghĩa là gì thì nó chỉ còn cách suy từ tên dự án."""
    _r, ctx, root = du_an
    _feature(root)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C5", "F-01")
    assert kh, [x["layer"] for x in compose({"role": "planner", "task_ref": "F-01"},
                                            ctx)["bundle"]["blocks"]]
    t = kh[0]["text"]
    assert "500ms" in t, "kỳ vọng ĐO ĐƯỢC là thứ PLAN-01 bắt buộc — thiếu nó thì mô hình tự nghĩ"
    assert "PB5 phải là ngõ ra" in t and "PORTB" in t


def test_tinh_nang_khac_thi_khong_lay_nham(du_an):
    _r, ctx, root = du_an
    _feature(root)
    assert _khoi(compose({"role": "planner", "task_ref": "F-99"}, ctx)["bundle"], "C5", "F-01") == []


def test_doc_duoc_CA_HAI_hinh_dang_cua_FEATURES_json(du_an):
    """`FEATURES.json` tồn tại ở HAI hình dạng trong kho: `{"features": [...]}` (thứ
    `project.create` và `memory.progress` ghi) và một DANH SÁCH TRẦN (thứ vài chỗ khác ghi).

    Bản đầu của tôi chỉ biết dạng thứ nhất, và `make check` bắt được bằng bốn bài `test_code.py`
    đỏ: `'list' object has no attribute 'get'`. Nên phép đo này giữ cả hai dạng — dùng lại
    `code.py::_doc_feature` thay vì viết bộ đọc thứ hai."""
    _r, _ctx, root = du_an
    ft = {"id": "F-01", "title": "Nháy LED",
          "expectation": {"kind": "measurement", "detail": "chu kỳ 500ms"}}
    for shape in ({"features": [ft]}, [ft]):
        (root / ".eide" / "FEATURES.json").write_text(
            json.dumps(shape, ensure_ascii=False), encoding="utf-8")
        van, nguon = _c5_tinh_nang(root, "F-01")
        assert "Nháy LED" in van and "chu kỳ 500ms" in van, shape
        assert nguon


def test_khong_co_FEATURES_json_thi_khong_no(du_an):
    _r, _ctx, root = du_an
    assert _c5_tinh_nang(root, "F-01") == ("", [])


def test_FEATURES_json_hong_thi_khong_no(du_an):
    """Tệp hỏng KHÔNG được làm hỏng cả lời gọi — ngữ cảnh thiếu một lớp còn chạy được, một
    ngoại lệ ở đây chặn mọi việc."""
    _r, _ctx, root = du_an
    (root / ".eide" / "FEATURES.json").write_text("{ hỏng", encoding="utf-8")
    assert _c5_tinh_nang(root, "F-01") == ("", [])


def test_vai_tro_intent_khong_doi(du_an):
    """`intent` dùng C2 cho việc KHÁC (§4.1: C1′ = tóm tắt trạng thái dự án) và ngân sách chỉ
    400 token. Không nhét câu trả lời vào đó."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    assert _khoi(compose({"role": "intent", "task_ref": ""}, ctx)["bundle"],
                 "C2", "ĐÃ TRẢ LỜI") == []


def test_van_trong_ngan_sach(du_an):
    """Thêm hai khối mà vượt tổng thì `kiem_tran` ném E5001 và không lời gọi nào chạy được."""
    _r, ctx, root = du_an
    _feature(root)
    for i in range(6):
        _clar(root, f"CL-{i}", f"{HOI} {i}", f"{TRA} {i}", at=f"2026-09-22T10:0{i}:00+00:00")
    b = compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"]
    assert b["total_tokens"] <= b["budget"]["total"]
