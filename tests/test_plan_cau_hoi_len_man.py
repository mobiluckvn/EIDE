"""[DEV-171] Kế hoạch bị cổng G1 chặn — câu hỏi của tác tử phải LÊN ĐƯỢC MÀN HÌNH.

Đo 22/09/2026 trên dự án `nhap-nhay-led-tren-atmega328p`, hộ chiếu đủ (287 fact vàng từ
`ATmega328P.atdf`). Planner nêu hai câu đáng hỏi — *"chưa rõ tần số thạch anh (F_CPU) thực tế
trên board"* và *"chưa rõ chân GPIO nối với LED"* — cổng G1-02 trả ASK, `code.generate_module`
từ chối bằng E3000, và:

* `plan.sufficiency` (thứ màn S12 gọi lúc vẽ) trả `{"sufficient": true, "missing": []}`;
* `decision_log` không có dòng ASK nào, `acq_request` rỗng, `clarification` rỗng.

Tức tác tử có hai câu hỏi, đang chờ người, và không câu nào lên được màn hình. Người dùng nhìn
một kế hoạch trông bình thường rồi không hiểu vì sao không sinh nổi mã.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.plan import (
    _hoi_nguoi_ve_ke_hoach,
    _thieu_co_ban,
    ghi_plan,
    sufficiency,
)
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

HAI_CAU = ["Chưa rõ tần số thạch anh (F_CPU) thực tế trên board mạch của người dùng",
           "Chưa rõ chân GPIO chính xác nối với LED"]
ASK_G1 = {"decision": "ASK", "rule": "G1-02", "gate": "G1",
          "reason": "Thiếu tri thức → mở P1 trước"}


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "nhấp nháy LED"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _ke_hoach_bi_chan(root):
    ghi_plan(root, "F-01",
             {"steps": [{"id": "s1", "goal": "a", "cites": ["project.text"]}],
              "missing": list(HAI_CAU), "feature": "F-01"}, dict(ASK_G1))


def _clars(root):
    with store.open_store(store.store_path(root)) as c:
        return c.execute("SELECT text, status, source_cap FROM clarification"
                         " ORDER BY created_at, id").fetchall()


# ---------- (1) plan.sufficiency phải nói THẬT


def test_sufficiency_noi_du_trong_khi_ke_hoach_dang_bi_chan(du_an):
    """Phép đo trung tâm của DEV-171: trước bản vá, hàm này trả `sufficient: true` cho đúng
    cái kế hoạch mà cổng vừa chặn — và S12 vẽ theo nó."""
    _r, ctx, root = du_an
    _ke_hoach_bi_chan(root)
    kq = sufficiency({"task_ref": "F-01"}, ctx)
    assert kq["sufficient"] is False, "kế hoạch đang ASK mà màn hình báo ĐỦ"
    van = [m.get("text", "") for m in kq["missing"]]
    for cau in HAI_CAU:
        assert any(cau in v for v in van), f"mất câu hỏi: {cau}"


def test_sufficiency_noi_ca_QUYET_DINH_cua_cong(du_an):
    """Hai câu hỏi cho biết THIẾU GÌ; quyết định cổng cho biết HẬU QUẢ. Thiếu vế sau thì người
    dùng trả lời xong vẫn không biết vì sao nãy giờ không sinh được mã."""
    _r, ctx, root = du_an
    _ke_hoach_bi_chan(root)
    cong = [m for m in sufficiency({"task_ref": "F-01"}, ctx)["missing"]
            if m.get("loai") == "cong"]
    assert len(cong) == 1, cong
    assert "G1-02" in cong[0]["text"] and "ASK" in cong[0]["text"]
    # Đứng CUỐI: nó là hệ quả của những dòng trên.
    assert sufficiency({"task_ref": "F-01"}, ctx)["missing"][-1]["loai"] == "cong"


def test_ke_hoach_da_duyet_thi_khong_bia_ra_thieu(du_an):
    """Cổng APPROVE và planner không khai thiếu gì → `missing` phải rỗng. Một cảnh báo luôn
    hiện là một cảnh báo người ta tắt đi."""
    _r, ctx, root = du_an
    ghi_plan(root, "F-02", {"steps": [{"id": "s1", "goal": "a", "cites": ["x"]}], "missing": []},
             {"decision": "APPROVE", "rule": "G1-01", "gate": "G1", "reason": "ok"})
    assert sufficiency({"task_ref": "F-02"}, ctx) == {"sufficient": True, "missing": []}


def test_khong_co_ke_hoach_thi_khong_no(du_an):
    _r, ctx, _root = du_an
    assert sufficiency({"task_ref": "F-99"}, ctx)["sufficient"] is True


# ---------- (2) không được tự nuôi: `plan.create` chỉ dùng phần suy được


def test_plan_create_KHONG_hut_missing_cua_lan_truoc(du_an):
    """Vòng tự nuôi. `plan.create` ghép kết quả `sufficiency` vào `missing` rồi ghi xuống tệp.
    Nếu `sufficiency` cũng ĐỌC tệp ấy thì `missing` của lần trước chảy vào lần này, ghi xuống,
    rồi lần sau lại chảy tiếp — danh sách không bao giờ rỗng đi được, kể cả sau khi người đã
    trả lời. Đó là lý do `plan.create` gọi `_thieu_co_ban`, không gọi cả bộ."""
    _r, _ctx, root = du_an
    _ke_hoach_bi_chan(root)
    van = [m.get("text", "") for m in _thieu_co_ban(root, "F-01")]
    for cau in HAI_CAU:
        assert not any(cau in v for v in van), "phần suy được đã hút `missing` của lần trước"


# ---------- (3) câu hỏi phải thành ĐIỂM CẦN LÀM RÕ (tab S9)


def test_moi_cau_hoi_thanh_MOT_dong_rieng(du_an):
    """Ghi riêng từng dòng chứ không gộp: người trả lời được câu F_CPU mà chưa tra ra chân LED,
    và một dòng gộp buộc họ hoặc trả lời cả hai hoặc không gì cả."""
    _r, ctx, root = du_an
    plan = {"missing": list(HAI_CAU)}
    _hoi_nguoi_ve_ke_hoach(root, "F-01", plan, _D(ASK_G1), ctx)
    ds = _clars(root)
    assert len(ds) == 2, ds
    assert all(r[1] == "open" and r[2] == "plan.create" for r in ds)
    assert any("F_CPU" in r[0] for r in ds) and any("GPIO" in r[0] for r in ds)


def test_ASK_khong_kem_missing_van_phai_noi_ra(du_an):
    """G1-03 (đổi kiến trúc) và G1-99 (mặc định) trả ASK mà không có `missing` nào. Im lặng ở
    nhánh hiếm vẫn là im lặng."""
    _r, ctx, root = du_an
    d = _D({"decision": "ASK", "rule": "G1-03", "gate": "G1", "reason": "Đổi kiến trúc"})
    _hoi_nguoi_ve_ke_hoach(root, "F-01", {"missing": []}, d, ctx)
    ds = _clars(root)
    assert len(ds) == 1 and "Đổi kiến trúc" in ds[0][0], ds


def test_cong_duyet_thi_KHONG_hoi_gi(du_an):
    _r, ctx, root = du_an
    d = _D({"decision": "APPROVE", "rule": "G1-01", "gate": "G1", "reason": "ok"})
    _hoi_nguoi_ve_ke_hoach(root, "F-01", {"missing": list(HAI_CAU)}, d, ctx)
    assert _clars(root) == []


def test_lap_lai_ke_hoach_khong_de_ra_ban_sao(du_an):
    """Mã điểm cần làm rõ băm theo NỘI DUNG (DEV-151), nên lập lại kế hoạch hai lần với cùng
    hai câu hỏi vẫn chỉ là hai dòng."""
    _r, ctx, root = du_an
    for _ in range(3):
        _hoi_nguoi_ve_ke_hoach(root, "F-01", {"missing": list(HAI_CAU)}, _D(ASK_G1), ctx)
    assert len(_clars(root)) == 2


# ---------- (4) cổng PHỤ phải vào sổ quyết định


def test_cong_G1_cua_handler_vao_decision_log(du_an):
    """`plan.create` chạy cổng G1 BÊN TRONG handler — Router đã xét xong `plan.create` trước
    đó và không biết cổng thứ hai vừa chạy. Trước bản vá, quyết định ASK ấy không sinh dòng
    `decision_log` nào: một quyết định chặn cả việc sinh mã mà không để lại dấu vết."""

    class _GW:
        def prompt(self, role): return f"# vai trò {role}"

        def run(self, role, prompt, schema, system_extra=""):
            class R:
                data = {"steps": [{"id": "s1", "goal": "a", "cites": ["project.text"]},
                                  {"id": "s2", "goal": "b", "cites": ["project.text"]},
                                  {"id": "s3", "goal": "c", "cites": ["project.text"]}],
                        "missing": list(HAI_CAU)}
            return R()

    r, ctx, root = du_an
    ctx.extra["gateway"] = _GW()
    run = r.invoke("plan.create", {"feature": "F-01"}, ctx)
    assert run.status == "done", run.error
    assert run.result["decision"]["decision"] == "ASK", run.result["decision"]

    with store.open_store(store.store_path(root)) as c:
        ds = c.execute("SELECT id, gate, action_cap, decision, rule FROM decision_log"
                       " WHERE gate='G1'").fetchall()
    assert len(ds) == 1, f"cổng G1 không vào sổ: {ds}"
    assert ds[0][0] == f"{run.run_id}:G1", "khoá phải tách khỏi dòng chính của lời gọi"
    assert ds[0][2] == "plan.create" and ds[0][3] == "ASK" and ds[0][4] == "G1-02"

    # Và vào CẢ nhật ký — sổ cái là chuỗi băm, nó mới chứng minh được không dòng nào bị xoá.
    gd = [x for x in r.ledger.records()
          if x["kind"] == "gate.decision" and (x["data"] or {}).get("gate") == "G1"]
    assert gd and gd[-1]["data"]["decision"] == "ASK"
    assert r.ledger.verify() == (True, 0)

    # Và hai câu hỏi có mặt ở tab Làm rõ yêu cầu.
    assert len(_clars(root)) == 2, _clars(root)


def test_dong_chinh_cua_loi_goi_khong_bi_de(du_an):
    """Dòng `decision_log` của chính lời gọi mang khoá `run_id`, và `_cap_nhat_decision_log`
    điền `human_answer`/`undone_at` theo khoá ấy. Cổng phụ trùng khoá sẽ vừa hỏng chèn vừa làm
    hai quyết định khác nhau đè lên nhau."""
    import eide.caps.plan as P  # noqa: F401

    class _GW:
        def prompt(self, role): return f"# vai trò {role}"

        def run(self, role, prompt, schema, system_extra=""):
            class R:
                data = {"steps": [{"id": f"s{i}", "goal": "a", "cites": ["x"]}
                                  for i in range(3)], "missing": []}
            return R()

    r, ctx, root = du_an
    ctx.extra["gateway"] = _GW()
    run = r.invoke("plan.create", {"feature": "F-01"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        ds = dict(c.execute("SELECT id, action_cap FROM decision_log").fetchall())
    assert run.run_id in ds and f"{run.run_id}:G1" in ds, ds


def test_khong_co_cong_phu_thi_khong_ghi_gi_them(du_an):
    """Năng lực bình thường không khai cổng phụ — Router không được đẻ ra dòng thừa."""
    r, ctx, root = du_an
    r.invoke("plan.order", {"features": ["a", "b"]}, ctx)
    with store.open_store(store.store_path(root)) as c:
        n = c.execute("SELECT count(*) FROM decision_log WHERE id LIKE '%:%'").fetchone()[0]
    assert n == 0
    assert "cong_phu" not in ctx.extra, "Router phải RÚT khóa ấy ra, không để nó tích lại"


class _D:
    """Quyết định cổng dạng đối tượng, đúng hình dạng `PolicyGate.decide` trả về."""

    def __init__(self, d):
        self.decision, self.rule_id = d["decision"], d["rule"]
        self.gate, self.reason = d["gate"], d["reason"]


def test_vet_quyet_dinh_doc_lai_duoc_tu_te_p(du_an):
    """Tệp kế hoạch vẫn là nguồn cho `code.generate_module` (CODE-01 đòi "G1 approved"), nên
    bản vá không được làm mất nó."""
    _r, _ctx, root = du_an
    _ke_hoach_bi_chan(root)
    from eide.caps.plan import doc_plan_feature
    d = doc_plan_feature(root, "F-01")
    assert d["decision"] == ASK_G1
    assert json.loads(json.dumps(d["plan"]["missing"])) == HAI_CAU
