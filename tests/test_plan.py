"""Nhóm plan.* — CDS-12.1; PRS-16 §4 (vai trò planner); POL-17 G1.

tc của hợp đồng: PLAN-04 "Thứ tự đúng phụ thuộc"; PLAN-05 "So với ngân sách ngày"; PLAN-07
"Thiếu timing → sufficient=false"; PLAN-01 "expectation là serial pattern đo được"; PLAN-06
"Bước xong không đổi"; PLAN-03 S18…S22.

Ba năng lực deterministic (`order`, `estimate`, `sufficiency`) kiểm được không cần mô hình — và
đó là điểm của việc tách chúng ra khỏi bốn năng lực có sinh.
"""
from __future__ import annotations

import hashlib
import json

import pytest

from eide.caps.plan import BUOC_TOI_DA, BUOC_TOI_THIEU, _kiem_plan
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án kế hoạch"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


# ---------- PLAN-04 plan.order


def test_sap_theo_BAC_phan_cung_khi_khong_khai_phu_thuoc(du_an):
    """tc: "Thứ tự đúng phụ thuộc". Bậc clock → GPIO → bus → cảm biến → điều khiển → app không
    phải quy ước mà là ràng buộc VẬT LÝ: cấu hình I2C trước khi bật clock cho nó thì thanh ghi
    ghi vào hư không."""
    r, ctx, _ = du_an
    out = r.invoke("plan.order", {"features": ["app_main", "i2c_driver", "clock_init",
                                               "bme280_sensor"]}, ctx).result
    assert out["order"] == ["clock_init", "i2c_driver", "bme280_sensor", "app_main"]
    assert out["cycles"] == []


def test_cung_bac_thi_giu_thu_tu_dau_vao(du_an):
    """Ổn định: hai module cùng bậc không được đảo chỗ giữa hai lần chạy."""
    r, ctx, _ = du_an
    ds = ["gpio_b", "gpio_a"]
    a = r.invoke("plan.order", {"features": ds}, ctx).result["order"]
    assert a == ds == r.invoke("plan.order", {"features": ds}, ctx).result["order"]


def test_chu_trinh_tra_ve_chu_khong_nem(du_an):
    """Hợp đồng khai CẢ HAI trường `order` và `cycles`. Một đồ thị phụ thuộc vòng là thứ người
    cần NHÌN THẤY để gỡ, không phải một ngoại lệ chặn cả lời gọi."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO module (id, name, depends) VALUES ('a', 'A', '[\"b\"]')")
        c.execute("INSERT INTO module (id, name, depends) VALUES ('b', 'B', '[\"a\"]')")
        c.commit()
    out = r.invoke("plan.order", {"features": ["a", "b"]}, ctx).result
    assert out["order"] == []
    assert out["cycles"] and set(out["cycles"][0]) == {"a", "b"}


# ---------- PLAN-05 plan.estimate


def test_khong_co_lich_su_thi_dung_mac_dinh_va_NOI_RA(du_an):
    """Người đọc con số phải biết nó chắc đến đâu — "mặc định theo bước" và "lịch sử ledger" là
    hai mức tin cậy rất khác nhau."""
    r, ctx, _ = du_an
    out = r.invoke("plan.estimate", {"plan": {"steps": [{}, {}, {}]}}, ctx).result
    assert out["estimate"]["nguon"] == "mặc định theo bước"
    assert out["estimate"]["steps"] == 3


def test_duoi_ba_luot_thi_chua_dung_lich_su(du_an):
    """Trung bình của một hai mẫu chỉ là một con số ngẫu nhiên đội lốt ước lượng."""
    r, ctx, _ = du_an
    for _ in range(2):
        ctx.extra["ledger"].append("model.call", {"role": "planner", "model_id": "m",
                                                  "tokens_in": 100, "tokens_out": 50,
                                                  "cost_usd": 0.001})
    assert r.invoke("plan.estimate", {"plan": {"steps": [{}]}}, ctx
                    ).result["estimate"]["nguon"] == "mặc định theo bước"


def test_du_lich_su_thi_uoc_tu_chi_phi_THAT(du_an):
    r, ctx, _ = du_an
    for _ in range(4):
        ctx.extra["ledger"].append("model.call", {"role": "planner", "model_id": "m",
                                                  "tokens_in": 1000, "tokens_out": 200,
                                                  "cost_usd": 0.6})
    out = r.invoke("plan.estimate", {"plan": {"steps": [{}, {}]}}, ctx).result
    assert out["estimate"]["nguon"] == "lịch sử ledger"
    assert out["estimate"]["cost_usd"] == pytest.approx(1.2)
    # §4.4 viết "≤ ngân sách", nên BẰNG ngưỡng là trong ngưỡng. 1,2 > 1,0 mới là vượt.
    assert out["within_budget"] is False


def test_bang_dung_nguong_van_la_TRONG_ngan_sach(du_an):
    """Biên "≤": một kế hoạch tốn đúng bằng ngân sách không bị chặn. Ranh giới này phải có test
    riêng — nó là chỗ dễ lệch một đơn vị nhất, và lệch về phía chặn thì người dùng bị hỏi một
    câu không cần thiết mỗi lần chạm trần."""
    r, ctx, _ = du_an
    tran = ctx.extra["gate"].config["thresholds"]["plan_max_cost_usd"]
    for _ in range(4):
        ctx.extra["ledger"].append("model.call", {"role": "planner", "model_id": "m",
                                                  "tokens_in": 10, "tokens_out": 10,
                                                  "cost_usd": tran})
    out = r.invoke("plan.estimate", {"plan": {"steps": [{}]}}, ctx).result
    assert out["estimate"]["cost_usd"] == pytest.approx(tran)
    assert out["within_budget"] is True


def test_so_voi_ngan_sach_cua_chinh_sach(du_an):
    """tc: "So với ngân sách ngày" — ngưỡng lấy từ `thresholds.plan_max_cost_usd`, không viết cứng."""
    r, ctx, _ = du_an
    tran = ctx.extra["gate"].config["thresholds"]["plan_max_cost_usd"]
    out = r.invoke("plan.estimate", {"plan": {"steps": [{}]}}, ctx).result
    assert out["within_budget"] is (out["estimate"]["cost_usd"] <= tran)


# ---------- PLAN-07 plan.sufficiency


def test_thieu_timing_thi_khong_du(du_an):
    """tc của hợp đồng, từng chữ. Cấu hình I2C mà không biết thời gian setup/hold thì mã vẫn
    biên dịch, vẫn chạy, và chỉ sai khi gặp thiết bị chậm — đúng loại lỗi mà phép kiểm này tồn
    tại để chặn trước."""
    r, ctx, _ = du_an
    out = r.invoke("plan.sufficiency", {"task_ref": "cấu hình I2C1 400 kHz"}, ctx).result
    assert out["sufficient"] is False
    assert any(m.get("predicate") == "timing" for m in out["missing"])


def test_thieu_duoc_TACH_theo_loai(du_an):
    """Gộp thành một cờ `sufficient=false` thì tác tử biết mình thiếu mà không biết thiếu GÌ, và
    bước tiếp theo chỉ còn cách hỏi người. Ba loại dẫn tới ba hành động khác nhau."""
    r, ctx, _ = du_an
    out = r.invoke("plan.sufficiency", {"task_ref": "đọc thanh ghi CR1 qua I2C"}, ctx).result
    loai = {m["loai"] for m in out["missing"]}
    assert "tri_thuc" in loai
    assert all("hanh_dong" in m for m in out["missing"]), "mỗi mục thiếu phải nói làm gì tiếp"


def test_co_fact_roi_thi_khong_bao_thieu(du_an):
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id,uri,sha256,kind,tier,license) VALUES (?,?,?,?,?,?)",
                  ("s", "u", hashlib.sha256(b"s").hexdigest(), "pdf_vendor", "gold", "MIT"))
        for vt in ("timing", "pin_function"):
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                      " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                      (f"f_{vt}", "chip:x/periph:I2C1", vt, '"x"', "s", "parser", "gold",
                       1.0, "verified", "A"))
        c.commit()
    store.write_seal(store.store_path(root))
    out = r.invoke("plan.sufficiency", {"task_ref": "cấu hình I2C1"}, ctx).result
    assert not [m for m in out["missing"] if m.get("predicate") in ("timing", "pin_function")]


# ---------- phép kiểm deterministic của PLAN-03


def test_ke_hoach_trich_dan_fact_KHONG_CO_bi_bat(du_an):
    """PRS-16 §4 cấm planner "giả định tri thức chắc có". Một kế hoạch trích dẫn `f_khong_co_that`
    trông y hệt một kế hoạch đúng — đây là chỗ duy nhất bắt được."""
    _, _, root = du_an
    plan = {"steps": [{"id": "s1", "goal": "a", "cites": ["f_0000000000000001"]},
                      {"id": "s2", "goal": "b"}, {"id": "s3", "goal": "c"}]}
    loi = _kiem_plan(plan, root)
    assert any("không có trong store" in x for x in loi), loi


def test_so_buoc_ngoai_khoang_bi_bat(du_an):
    """PRS-16 §4: "chia bước quá nhỏ (< 3) hoặc quá lớn (> 12 bước)"."""
    _, _, root = du_an
    assert any("ngoài khoảng" in x for x in _kiem_plan({"steps": [{"id": "s1", "goal": "a"}]}, root))
    nhieu = {"steps": [{"id": f"s{i}", "goal": "x"} for i in range(BUOC_TOI_DA + 1)]}
    assert any("ngoài khoảng" in x for x in _kiem_plan(nhieu, root))
    vua = {"steps": [{"id": f"s{i}", "goal": "x"} for i in range(BUOC_TOI_THIEU)]}
    assert not [x for x in _kiem_plan(vua, root) if "ngoài khoảng" in x]


def test_fact_co_that_thi_khong_bao_loi(du_an):
    _, _, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id,uri,sha256,kind,tier,license) VALUES (?,?,?,?,?,?)",
                  ("s", "u", hashlib.sha256(b"s2").hexdigest(), "pdf_vendor", "gold", "MIT"))
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  ("f_00000000000000ab", "chip:x", "offset", "0", "s", "parser", "gold",
                   1.0, "verified", "A"))
        c.commit()
    plan = {"steps": [{"id": "s1", "goal": "a", "cites": ["f_00000000000000ab"]},
                      {"id": "s2", "goal": "b"}, {"id": "s3", "goal": "c"}]}
    assert _kiem_plan(plan, root) == []


# ---------- PLAN-01: kỳ vọng phải MÁY quan sát được


def test_ky_vong_khong_do_duoc_bi_tu_choi(du_an, monkeypatch):
    """tc: "expectation là serial pattern đo được".

    Một feature ghi "LED nháy đúng" thì không test nào kiểm được, và nó sẽ nằm `failing` mãi
    hoặc được đánh dấu `passing` bằng mắt người — cả hai đều làm FEATURES.json mất nghĩa. Kiểm ở
    MÃ chứ không dặn trong prompt: mô hình rất sẵn lòng viết một câu nghe như đo được.
    """
    import eide.caps.plan as P

    class _GW:
        """Gateway giả: `compose` cần `prompt(role)` cho lớp C1 (CXD-10 §2)."""

        def prompt(self, role): return f"# vai trò {role}"

        def run(self, role, prompt, schema, system_extra=""):
            class R:
                data = {"title": "LED nháy", "expectation": {"kind": "cam_giac",
                                                             "detail": "nhìn thấy nháy"}}
            return R()

    r, ctx, _ = du_an
    ctx.extra["gateway"] = _GW()
    monkeypatch.setattr(P, "sufficiency", lambda p, c: {"sufficient": True, "missing": []})
    run = r.invoke("plan.define_feature", {"text": "cho LED nháy"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


# ---------- PLAN-06: bước đã xong không đổi


def test_replan_giu_nguyen_buoc_da_xong(du_an):
    """tc: "Bước xong không đổi".

    Mã đã viết, fact đã duyệt, firmware đã nạp — một kế hoạch mới bỏ qua chúng sẽ làm lại từ đầu
    một cách lãng phí, hoặc tệ hơn, làm lại một thao tác R3 lên phần cứng.
    """
    class _GW:
        def prompt(self, role): return f"# vai trò {role}"

        def run(self, role, prompt, schema, system_extra=""):
            class R:
                data = {"steps": [{"id": "s1", "goal": "LÀM LẠI"},
                                  {"id": "s9", "goal": "bước mới"}]}
            return R()

    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO run (id, graph, state, report) VALUES (?,?,?,?)",
                  ("r_1", "{}", "failed", json.dumps(
                      {"steps": [{"id": "s1", "goal": "đã xong", "status": "done"},
                                 {"id": "s2", "goal": "chưa xong"}]})))
        c.commit()
    ctx.extra["gateway"] = _GW()
    out = r.invoke("plan.replan", {"plan_id": "r_1", "reason": "tool_fail"}, ctx).result
    b = {x["id"]: x for x in out["plan"]["steps"]}
    assert b["s1"]["goal"] == "đã xong", "bước đã xong bị lập lại"
    assert "s9" in b, "bước mới phải được thêm"
    assert out["plan"]["replan_count"] == 1


def test_lap_lai_lan_ba_thi_hoi_nguoi(du_an):
    """ask "Lần 3": hai lần đầu là điều chỉnh, lần thứ ba nghĩa là giả định gốc sai — và tác tử
    không phải bên nên tự quyết điều đó."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO run (id, graph, state, report) VALUES (?,?,?,?)",
                  ("r_2", "{}", "failed", json.dumps({"steps": [], "replan_count": 2})))
        c.commit()
    run = r.invoke("plan.replan", {"plan_id": "r_2", "reason": "conflict"}, ctx)
    assert run.status == "pending" and run.error["eide_code"] == "E3000"


# ---------- PLAN-03 / cổng G1: `touches` (PRS-16 §4) và ba đặc trưng từng chết

def _ke_hoach_sach(**them):
    """Kế hoạch thoả MỌI vế của G1-01: 3 bước, mọi bước có trích dẫn, không tài nguyên mới."""
    b = [{"id": f"s{i}", "goal": "x", "cap": "code.build", "done_when": "xong",
          "cites": ["f_00000000000000ab"], **them} for i in range(1, 4)]
    return {"steps": b, "citations": ["f_00000000000000ab"], "missing": [],
            "estimate": {"cost_usd": 0.01}}


def test_schema_plan_doc_tu_PRS16_khong_chep_tay():
    """Mọi trường của Plan (trừ hai cái đổi tên có ghi DEV-061) phải đến từ
    `prompts/out_schemas.json`. Chép tay là cách `touches` biến mất lần trước."""
    from eide.caps.plan import _SCHEMA_PLAN, schema_vai_tro

    goc = schema_vai_tro("Plan")["properties"]["steps"]["items"]
    ma = _SCHEMA_PLAN["properties"]["steps"]["items"]
    assert ma == goc, "Plan.steps trong mã đã trôi khỏi PRS-16 §4"
    assert goc["required"] == ["id", "goal", "cap", "done_when"], \
        "DEV-061 đã đưa `id`/`cap` vào tài liệu — không còn phép đổi tên nào trong mã"
    ma = ma["properties"]
    assert ma["touches"]["items"]["enum"] == ["isr", "linker", "clock", "dma", "power",
                                              "actuator", "none"]


def test_touches_suy_ra_hai_dac_trung_cua_G1():
    from eide.caps.plan import _dac_trung_G1

    sach = _dac_trung_G1(_ke_hoach_sach(touches=["none"]), Context())["plan"]
    assert sach["touches_forbidden"] is False and sach["arch_change"] is False

    linker = _dac_trung_G1(_ke_hoach_sach(touches=["linker"]), Context())["plan"]
    assert linker["touches_forbidden"] is True and linker["arch_change"] is True

    # DMA không phải "đổi kiến trúc", nhưng vẫn là thứ G1-01 không được tự duyệt. Cách đọc hẹp
    # ("chỉ isr với linker") sẽ cho qua đúng ở đây — nên đây là ca phân biệt hai cách đọc.
    dma = _dac_trung_G1(_ke_hoach_sach(touches=["dma"]), Context())["plan"]
    assert dma["touches_forbidden"] is True and dma["arch_change"] is False


def test_G1_khong_tu_duyet_ke_hoach_cham_ISR():
    """Đây là lỗ hổng thật trước 08/09: `touches_forbidden` đọc từ một khóa mức kế hoạch mà
    schema gửi cho mô hình không có và không chỗ nào tính, nên nó LUÔN false — G1-01 tự duyệt
    được một kế hoạch sửa vector ngắt, còn G1-03 ("Đổi kiến trúc") là quy tắc chết. Xem DEV-061.
    """
    from eide.caps.plan import _dac_trung_G1

    gate = PolicyGate()
    sach = gate.decide("G1", _dac_trung_G1(_ke_hoach_sach(touches=["none"]), Context()),
                       risk="R1", tier="T1*")
    assert sach.decision == "APPROVE" and sach.rule_id == "G1-01", \
        "kế hoạch sạch phải tự duyệt được — nếu không thì test dưới không chứng minh gì"

    isr = gate.decide("G1", _dac_trung_G1(_ke_hoach_sach(touches=["isr"]), Context()),
                      risk="R1", tier="T1*")
    assert isr.decision == "ASK", f"kế hoạch chạm ISR vẫn được duyệt bởi {isr.rule_id}"

    clock = gate.decide("G1", _dac_trung_G1(_ke_hoach_sach(touches=["clock"]), Context()),
                        risk="R1", tier="T1*")
    assert clock.decision == "ASK" and clock.rule_id == "G1-03", \
        f"đổi clock phải rơi vào G1-03, không phải {clock.rule_id}"


def test_ten_tep_plan_khong_thoat_ra_khoi_thu_muc_du_an(tmp_path):
    """`feature` đến từ câu người dùng gõ — một dấu `/` trong đó không được trỏ ra ngoài.

    Không cần ai cố tình: một câu tiếng Việt bình thường như "vào/ra qua LAN" đã đủ.
    """
    from eide.caps.plan import ten_tep_plan
    for doc in ["../../../etc/passwd", "vào/ra qua LAN", "a/b", "..", "/tuyet/doi"]:
        t = ten_tep_plan(doc)
        assert "/" not in t and ".." not in t, f"{doc!r} → {t!r}"
        assert (tmp_path / f"{t}.json").resolve().parent == tmp_path.resolve()


def test_ten_tep_plan_bi_chan_do_dai_nhung_khong_dung_hang(tmp_path):
    """Cắt trần thôi thì hai feature khác nhau cùng đầu sẽ ghi đè kế hoạch của nhau.

    Mất một kế hoạch là mất luôn quyết định cổng G1 gắn với nó — nên phải có hậu tố băm.
    """
    from eide.caps.plan import ten_tep_plan
    dau = "thiết bị cắm vào cổng USB của bộ điều khiển và đóng vai một ổ USB, còn phía kia "
    a, b = ten_tep_plan(dau + "nối LAN"), ten_tep_plan(dau + "nối Wi-Fi")
    assert a != b, "hai feature khác nhau không được ra cùng một tên tệp"
    assert len(a) < 64 and len(b) < 64, (a, b)


def test_doc_plan_feature_van_doc_duoc_ke_hoach_ghi_truoc_ban_va(tmp_path):
    """Một dự án đang chạy dở không được mất lịch sử vì một lần nâng cấp."""
    import json as _json

    from eide.caps.plan import EIDE_DIR, THU_MUC_PLAN, doc_plan_feature
    thu = tmp_path / EIDE_DIR / THU_MUC_PLAN
    thu.mkdir(parents=True)
    (thu / "gateway.json").write_text(_json.dumps({"feature": "gateway", "plan": {"x": 1}}),
                                      encoding="utf-8")
    assert (doc_plan_feature(tmp_path, "gateway") or {}).get("plan") == {"x": 1}
