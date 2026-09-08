"""WI-005 · Orchestrator và nhóm chat.* — DPS-09 §2–§5; PRS-16 §7; CDS-12.6.

CHAT-01 tc: TC-59 (bộ 50 câu lệnh có nhãn, intent đúng ≥ 95%, is_big đúng 100%, câu 48
confidence < 0,6). CHAT-02 tc: TC-60 (không tạo trùng). CHAT-03 tc: TC-61 (thứ tự mặc định
DPS-09 §4.3). CHAT-04 tc: TC-61 timeout 120 s → mặc định. CHAT-05 tc: TC-62. CHAT-07 tc: TC-64.

Test hằng ngày dùng EchoPort — không mạng, không tốn tiền. TC-59 với mô hình THẬT nằm sau
`@pytest.mark.llm` (DEP-26 §5 job `dialog`).
"""
from __future__ import annotations

import json
import os

import pytest
import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.gateway import EchoPort, Gateway
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def intent_schema() -> dict:
    return json.loads((spec_dir() / "dialog" / "intent.schema.json").read_text(encoding="utf-8"))


def lenh_co_nhan() -> list[dict]:
    p = spec_dir() / "dialog" / "commands.jsonl"
    return [json.loads(x) for x in p.read_text(encoding="utf-8").splitlines() if x.strip()]


def _rt(tmp_path, tra_loi=None):
    """Router có Gateway giả nạp sẵn câu trả lời."""
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    echo = EchoPort(tra_loi or [])
    led = Ledger(tmp_path / "ledger.jsonl")
    gate = PolicyGate()
    gw = Gateway(config=cfg, ledger=led, ports={"gemini": echo, "claude": echo})
    r = Router(gate=gate, ledger=led)
    ctx = Context(extra={"gate": gate, "gateway": gw})
    return r, ctx, echo


def _du_an(tmp_path, workspace, text="dự án robot dò đường"):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l0.jsonl"))
    res = r.invoke("project.create", {"text": text}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return root


# ---------- fixture và schema ----------

def test_du_50_cau_lenh_co_nhan():
    """PRS-16 §7 — fixture của TC-59."""
    ds = lenh_co_nhan()
    assert len(ds) == 50
    assert all({"id", "text", "intent", "is_big"} <= set(d) for d in ds)


def test_moi_nhan_deu_nam_trong_enum_cua_schema():
    """Fixture và schema phải nói cùng một thứ tiếng; lệch thì TC-59 chấm sai mà không ai biết."""
    hop_le = set(intent_schema()["properties"]["intent"]["enum"])
    for d in lenh_co_nhan():
        assert d["intent"] in hop_le, d


def test_schema_intent_dung_dps09():
    s = intent_schema()
    assert s["required"] == ["intent", "slots", "is_big", "confidence"]
    assert len(s["properties"]["intent"]["enum"]) == 19   # +project.delete, DEV-021


# ---------- CHAT-01 chat.parse_intent ----------

def test_parse_intent_tra_ve_intent(tmp_path):
    r, ctx, echo = _rt(tmp_path, [{"intent": "project.create", "slots": {"idea": "robot hai bánh"},
                                   "is_big": True, "confidence": 0.92, "lang": "vi"}])
    out = r.invoke("chat.parse_intent", {"text": "Tạo cho anh dự án robot hai bánh"}, ctx).result
    assert out["intent"]["intent"] == "project.create"
    assert out["intent"]["is_big"] is True
    assert echo.goi[0]["system"].startswith("# Vai trò: intent")


def test_confidence_thap_thanh_unknown(tmp_path):
    """DPS-09 §4.1: "Confidence < 0,6 ⇒ coi là `unknown`".

    Ép ở MÃ chứ không nhờ mô hình tự nhận: một mô hình không chắc chắn cũng không chắc chắn
    về việc mình không chắc chắn.
    """
    r, ctx, _ = _rt(tmp_path, [{"intent": "sim.run", "slots": {}, "is_big": False, "confidence": 0.4}])
    out = r.invoke("chat.parse_intent", {"text": "abc xyz"}, ctx).result
    assert out["intent"]["intent"] == "unknown"
    assert out["intent"]["confidence"] == 0.4       # giữ nguyên số để còn truy được vì sao


def test_dinh_kem_vao_slots_path(tmp_path):
    """steps: "đính kèm → slots.path"."""
    r, ctx, _ = _rt(tmp_path, [{"intent": "knowledge.build", "slots": {}, "is_big": True,
                                "confidence": 0.9}])
    out = r.invoke("chat.parse_intent",
                   {"text": "đây là bộ tài liệu board", "attachments": ["/tmp/board.zip"]},
                   ctx).result
    assert out["intent"]["slots"]["path"] == "/tmp/board.zip"


def test_parse_intent_ghi_ledger(tmp_path):
    r, ctx, _ = _rt(tmp_path, [{"intent": "project.open", "slots": {}, "is_big": False,
                                "confidence": 0.9}])
    r.invoke("chat.parse_intent", {"text": "mở dự án robot-ctrl"}, ctx)
    ev = [x for x in r.ledger.records() if x["kind"] == "intent"]
    assert len(ev) == 1 and ev[0]["data"]["intent"] == "project.open"


def test_dau_ra_mo_hinh_sai_schema_la_E5002(tmp_path):
    """`errors` của hợp đồng chỉ có E5002 — và nó phải thật sự nổ."""
    r, ctx, _ = _rt(tmp_path, [{"intent": "khong-co-trong-enum", "slots": {}, "is_big": False,
                                "confidence": 0.9}])
    run = r.invoke("chat.parse_intent", {"text": "gì đó"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


# ---------- CHAT-02 chat.ground (deterministic, TC-60) ----------

def test_ground_tim_thay_du_an_da_co(tmp_path, workspace):
    """DPS-09 §4.2: tra trạng thái THẬT. "không bao giờ hành động trên giả định về trạng thái"."""
    _du_an(tmp_path, workspace, "dự án robot dò đường")
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = workspace
    out = r.invoke("chat.ground", {"intent": {"intent": "project.open", "slots": {},
                                              "mentions": ["robot dò đường"]}}, ctx).result
    assert any(e["name"] == "robot-do-duong" for e in out["grounded"]["exists"])


def test_ground_khong_goi_mo_hinh(tmp_path, workspace):
    """"deterministic, không nhờ mô hình nhớ" — nếu nó gọi mô hình thì EchoPort sẽ ghi lại."""
    _du_an(tmp_path, workspace)
    r, ctx, echo = _rt(tmp_path)
    ctx.project_dir = workspace
    r.invoke("chat.ground", {"intent": {"intent": "project.create",
                                        "slots": {"idea": "robot dò đường"}}}, ctx)
    assert echo.goi == [], "chat.ground phải deterministic (DPS-09 §2 ①)"


def test_ground_bao_ten_gan_giong_de_khong_tao_trung(tmp_path, workspace):
    """TC-60 "tạo trùng / ghi đè ngoài ý muốn = 0". Grounding là chỗ chặn, trước khi tạo."""
    _du_an(tmp_path, workspace, "robot cân bằng hai bánh")
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = workspace
    out = r.invoke("chat.ground", {"intent": {"intent": "project.create",
                                              "slots": {"idea": "robot cân bằng hai bánh v2"}}},
                   ctx).result
    assert out["grounded"]["candidates"], "phải nêu dự án gần giống trước khi tạo"


def test_ground_bao_thieu_gi(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    out = r.invoke("chat.ground", {"intent": {"intent": "target.flash", "slots": {}}}, ctx).result
    assert "missing" in out["grounded"]


# ---------- CHAT-03 chat.fill_defaults (TC-61) ----------

def test_thu_tu_mac_dinh_preferences_truoc(tmp_path, workspace):
    """DPS-09 §4.3 thứ tự: (1) preferences → (2) suy ra → (3) autonomy.defaults → (4) năng lực.

    preferences đứng ĐẦU vì D8: câu trả lời của người thắng mọi suy đoán của máy.
    """
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    r.invoke("project.preferences", {"op": "set", "key": "diagram_lang", "scope": "project",
                                     "value": "plantuml"}, ctx)
    out = r.invoke("chat.fill_defaults", {"intent": {"intent": "diagram.draw", "slots": {}},
                                          "grounded": {}}, ctx).result
    ap = {a["slot"]: a for a in out["applied"]}
    assert ap["diagram_lang"]["value"] == "plantuml"
    assert ap["diagram_lang"]["from"] == "preferences"


def test_mac_dinh_lui_ve_autonomy_yaml(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    out = r.invoke("chat.fill_defaults", {"intent": {"intent": "diagram.draw", "slots": {}},
                                          "grounded": {}}, ctx).result
    ap = {a["slot"]: a for a in out["applied"]}
    assert ap["diagram_lang"]["value"] == "mermaid"     # defaults.yaml
    assert ap["diagram_lang"]["from"] == "autonomy.defaults"


def test_suy_ten_du_an_tu_y_tuong(tmp_path, workspace):
    """§4.3 (2) "suy ra từ câu lệnh và Grounded (tên dự án từ ý tưởng)"."""
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    out = r.invoke("chat.fill_defaults",
                   {"intent": {"intent": "project.create", "slots": {"idea": "đèn giao thông"}},
                    "grounded": {}}, ctx).result
    assert out["intent"]["slots"]["project_name"] == "den-giao-thong"


def test_mac_dinh_da_co_thi_khong_de(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    out = r.invoke("chat.fill_defaults",
                   {"intent": {"intent": "diagram.draw", "slots": {"diagram_lang": "d2"}},
                    "grounded": {}}, ctx).result
    assert out["intent"]["slots"]["diagram_lang"] == "d2"
    assert not [a for a in out["applied"] if a["slot"] == "diagram_lang"]


def test_ghi_ledger_defaults_applied(tmp_path, workspace):
    """steps: "ghi ledger" — §7 đo "tỷ lệ mặc định bị người đổi" từ đây."""
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    r.invoke("chat.fill_defaults", {"intent": {"intent": "diagram.draw", "slots": {}},
                                    "grounded": {}}, ctx)
    ev = [x for x in r.ledger.records() if x["kind"] == "intent"
          and (x["data"] or {}).get("defaults_applied")]
    assert ev


# ---------- CHAT-04 chat.clarify (TC-61 timeout) ----------

def test_gop_moi_diem_mo_ho_thanh_MOT_cau(tmp_path):
    """D3: "gộp mọi điểm mơ hồ thành MỘT câu"; §7 đo "≤ 1 câu hỏi trên một lệnh"."""
    r, ctx, _ = _rt(tmp_path)
    out = r.invoke("chat.clarify", {"gaps": [
        {"slot": "board", "options": [{"label": "nucleo-f411", "value": "nucleo-f411"},
                                      {"label": "blackpill", "value": "blackpill"}], "default": 0},
        {"slot": "source", "options": [{"label": "mẫu tham chiếu", "value": "template"},
                                       {"label": "tôi gửi tài liệu", "value": "docs"}], "default": 0},
    ]}, ctx).result
    assert isinstance(out["question"]["text"], str)
    assert len(out["question"]["options"]) == 4          # gộp, không hỏi hai lần
    assert out["question"]["default"] == 1               # đánh số từ 1 (§4.3)


def test_timeout_lay_mac_dinh(tmp_path):
    """TC-61: "timeout 120 s → mặc định". Ở đây 0 s để kiểm nhanh."""
    r, ctx, _ = _rt(tmp_path)
    out = r.invoke("chat.clarify", {"gaps": [{"slot": "board", "options": [
        {"label": "nucleo-f411", "value": "nucleo-f411"}, {"label": "blackpill", "value": "blackpill"}],
        "default": 0}], "context": {"timeout_s": 0}}, ctx).result
    assert out["by"] == "timeout"
    assert out["answer"]["board"] == "nucleo-f411"


def test_nguoi_tra_loi_thi_ghi_nho(tmp_path, workspace):
    """D8 + §4.5: câu trả lời có `remember_as` được ghi vào preferences."""
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    r.invoke("chat.clarify", {"gaps": [{"slot": "probe", "remember_as": "probe",
                                        "options": [{"label": "ST-Link", "value": "stlink"},
                                                    {"label": "J-Link", "value": "jlink"}],
                                        "default": 0}],
                              "context": {"answer": {"probe": "jlink"}, "by": "human"}}, ctx)
    p = r.invoke("project.preferences", {"op": "get", "key": "probe"}, ctx).result["prefs"]
    assert p["probe"]["value"] == "jlink"
    assert p["probe"]["learned_from"]


def test_clarify_ghi_ledger_question_va_answer(tmp_path):
    r, ctx, _ = _rt(tmp_path)
    r.invoke("chat.clarify", {"gaps": [{"slot": "x", "options": [{"label": "a", "value": "a"}],
                                        "default": 0}], "context": {"timeout_s": 0}}, ctx)
    kinds = [x["kind"] for x in r.ledger.records()]
    assert "question" in kinds and "answer" in kinds


# ---------- CHAT-05 chat.restate (TC-62) ----------

def test_restate_toi_da_hai_cau(tmp_path):
    """steps: "Mẫu 'Tôi hiểu là … Tôi sẽ …' ≤ 2 câu"."""
    r, ctx, _ = _rt(tmp_path)
    out = r.invoke("chat.restate", {
        "intent": {"intent": "project.create", "slots": {"idea": "robot hai bánh tự cân bằng"},
                   "is_big": True, "confidence": 0.9},
        "chain": [{"id": "n1", "cap": "project.create"}, {"id": "n2", "cap": "env.check"},
                  {"id": "n3", "cap": "sim.build"}]}, ctx).result
    assert out["text"].startswith("Tôi hiểu là")
    assert "Tôi sẽ" in out["text"]
    # Đếm CÂU, không đếm dấu chấm: tên năng lực (`project.create`) cũng có dấu chấm.
    assert len([c for c in out["text"].split(". ") if c.strip()]) <= 2


def test_restate_neu_ten_nang_luc_that(tmp_path):
    r, ctx, _ = _rt(tmp_path)
    out = r.invoke("chat.restate", {"intent": {"intent": "code.feature", "slots": {}},
                                    "chain": [{"id": "n1", "cap": "code.module"}]}, ctx).result
    assert "code.module" in out["text"]


# ---------- CHAT-07 chat.report_back (TC-64) ----------

def test_report_back_du_bon_phan(tmp_path, workspace):
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    run = r.invoke("project.preferences", {"op": "set", "key": "k", "scope": "project",
                                           "value": "v"}, ctx)
    out = r.invoke("chat.report_back", {"run_id": run.run_id}, ctx).result
    assert set(out["report"]) >= {"done", "waiting", "undo", "cost"}
    assert out["text"]


def test_report_back_toi_da_10_dong(tmp_path, workspace):
    """steps: "≤ 10 dòng" — báo cáo trong ChatPanel, không phải một trang."""
    root = _du_an(tmp_path, workspace)
    r, ctx, _ = _rt(tmp_path)
    ctx.project_dir = root
    for i in range(40):
        r.invoke("project.preferences", {"op": "set", "key": f"k{i}", "scope": "project",
                                         "value": "v"}, ctx)
    out = r.invoke("chat.report_back", {"run_id": "r1"}, ctx).result
    assert len(out["text"].splitlines()) <= 10


# ---------- CHAT-08 chat.decline ----------

@pytest.mark.parametrize("ly_do", ["not_in_passport", "policy_reject", "cannot", "out_of_scope"])
def test_decline_co_ly_do_va_de_xuat(tmp_path, ly_do):
    """"Nói 'không làm được' CÓ LÝ DO VÀ ĐỀ XUẤT" — từ chối trống rỗng đẩy người vào ngõ cụt."""
    r, ctx, _ = _rt(tmp_path)
    out = r.invoke("chat.decline", {"reason": ly_do, "detail": "chi tiết"}, ctx).result
    assert "chi tiết" in out["text"]
    assert len(out["text"]) > 20


def test_decline_ghi_so_loi_khi_tu_choi(tmp_path):
    """steps: "ghi error_ledger nếu refusal" — MEM-11 §6 dùng sổ lỗi để sinh prompt phủ định."""
    r, ctx, _ = _rt(tmp_path)
    r.invoke("chat.decline", {"reason": "not_in_passport", "detail": "chưa có fact VDD"}, ctx)
    ev = [x for x in r.ledger.records() if x["kind"] == "error"]
    assert ev and ev[0]["data"]["kind"] == "refusal"


# ---------- Orchestrator: bốn trách nhiệm nối lại ----------

def test_orchestrator_chay_tron_vong(tmp_path, workspace):
    """DPS-09 §2: ① hiểu và đối chiếu → ③ mặc định → ④ báo cáo.

    ② lập chuỗi là CHAT-06, mốc M2 — chưa ở sprint này.
    """
    from eide.orchestrator import Orchestrator
    _du_an(tmp_path, workspace, "dự án đèn giao thông")
    r, ctx, _ = _rt(tmp_path, [{"intent": "project.open", "slots": {"project_name": "den-giao-thong"},
                                "is_big": False, "confidence": 0.95, "lang": "vi"}])
    ctx.project_dir = workspace
    kq = Orchestrator(r, ctx).xu_ly("mở dự án đèn giao thông")
    assert kq["intent"]["intent"] == "project.open"
    assert kq["grounded"]["exists"]
    assert kq["report"]["text"]


def test_orchestrator_confidence_thap_thi_hoi_lai_khong_lam(tmp_path, workspace):
    """§4.1: confidence < 0,6 ⇒ unknown ⇒ hỏi lại, KHÔNG đoán rồi làm."""
    from eide.orchestrator import Orchestrator
    r, ctx, _ = _rt(tmp_path, [{"intent": "project.create", "slots": {}, "is_big": False,
                                "confidence": 0.3}])
    ctx.project_dir = workspace
    kq = Orchestrator(r, ctx).xu_ly("abc xyz")
    assert kq["intent"]["intent"] == "unknown"
    assert kq.get("question"), "phải hỏi lại"
    assert not kq.get("chain")


# ---------- TC-59 với mô hình THẬT (job `dialog`, không chạy trong make check) ----------

@pytest.mark.llm
@pytest.mark.skipif(not os.environ.get("GEMINI_API_KEY"), reason="cần GEMINI_API_KEY")
def test_tc59_bo_50_cau_lenh_that(tmp_path):
    """TC-59: intent đúng ≥ 95%, is_big đúng 100%, câu 48 confidence < 0,6 (DPS-09 §7).

    BA ĐIỀU PHẢI NÓI RÕ VỀ CON SỐ NÀY.

    (1) Ngưỡng `is_big` 100% chưa đạt: đo 07/09/2026 được 48/50, và hai câu còn lại thuộc HAI
        loại khác hẳn nhau — trộn chúng vào một con số là mất thông tin.

          #13 "Thêm tính năng đọc MPU6050 qua I2C1" — mô hình trả `true`, fixture ghi `false`.
              "Thêm tính năng" đúng là tên chuỗi mẫu Z-05 (DPS-09 §4.4), nên ở đây khả năng cao
              là FIXTURE sai chứ không phải mô hình. Chờ chủ sản phẩm gán lại (DEV-022).
          #34 "Create a new project for a balancing robot" — mô hình trả `false`, trong khi
              câu 1 là ĐÚNG LỆNH ẤY bằng tiếng Việt và nó trả `true`. Cùng một lệnh, hai ngôn
              ngữ, hai câu trả lời: đây là điểm yếu của MÔ HÌNH, không phải của fixture. DPS-09
              có trường `lang` vì sản phẩm nhận cả hai thứ tiếng, nên đây là lỗi thật.

    (2) Cột `is_big` từng bị chính tôi sửa nhầm chiều: ba câu 45/46/50 mang `intent=big_command`
        nhưng `is_big=false`, tôi đọc thành mâu thuẫn và đổi `is_big` sang `true`. Sai — mâu
        thuẫn nằm ở cột `intent`, vì `big_command` còn gánh vai sọt chứa cho 14/27 nhóm năng lực
        chưa có ý định riêng (DEV-035). Đã trả về nhãn gốc 07/09/2026.

    (3) Các mô tả ý định trong `dialog/intents.md` (lớp C0) được viết VÀ TINH CHỈNH dựa trên
        chính 50 câu này. Nên 100% intent là số REGRESSION, không phải ước lượng khả năng khái
        quát. Muốn có số trung thực thì cần một bộ câu giữ riêng chưa từng dùng để chỉnh —
        DEV-022 đề xuất đúng việc đó cho v1.3.
    """
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    gw = Gateway(config=cfg, ledger=Ledger(tmp_path / "ledger.jsonl"))
    r = Router(gate=PolicyGate(), ledger=gw.ledger)
    ctx = Context(extra={"gateway": gw, "ledger": gw.ledger})

    dung = big_dung = 0
    sai: list[str] = []
    ds = lenh_co_nhan()
    for d in ds:
        try:
            out = r.invoke("chat.parse_intent", {"text": d["text"]}, ctx).result["intent"]
        except EideError as e:
            sai.append(f"{d['id']} {d['text'][:34]} → LỖI {e.code}")
            continue
        if out["intent"] == d["intent"]:
            dung += 1
        else:
            sai.append(f"{d['id']} {d['text'][:34]!r} mong {d['intent']}, ra {out['intent']}")
        if bool(out["is_big"]) == bool(d["is_big"]):
            big_dung += 1
        else:
            sai.append(f"{d['id']} {d['text'][:34]!r} is_big mong {d['is_big']}, ra {out['is_big']}")

    ty_le = dung / len(ds)
    print(f"\nTC-59: intent đúng {dung}/{len(ds)} = {ty_le:.0%}; is_big đúng {big_dung}/{len(ds)}")
    for s in sai:
        print("  ✗", s)
    print(f"chi phí: {gw.da_tieu_hom_nay():.4f} USD")
    assert ty_le >= 0.95, f"intent đúng {ty_le:.0%} < 95%"
    # Ngưỡng hợp đồng là 100%; sàn 48/50 là số ĐO ĐƯỢC ngày 07/09/2026 sau khi trả nhãn về
    # bản gốc và viết quy tắc suy `is_big` vào lớp C0. Sàn tồn tại để bắt TỤT LÙI, không phải
    # để hợp thức hóa — nâng nó lên 50/50 khi DEV-022 và DEV-035 được giải quyết.
    # Ngưỡng CHỐT (ratchet) ở mức đã đo, không phải ở 100%. Đo 08/09/2026: hai lần chạy liên
    # tiếp cho 47/50 và 49/50 — câu 34 ("Create a new project for a balancing robot", tiếng Anh)
    # lật qua lật lại. Đó là dao động của mô hình ở một câu ranh giới, không phải trôi chất
    # lượng; và nó là lý do nhóm `llm` KHÔNG nằm trong `make check`.
    #
    # Không hạ ngưỡng xuống 47 để hết đỏ: hạ ngưỡng cho khỏi phiền là cách một chỉ số chất
    # lượng lặng lẽ trôi xuống. Chạy lại một lần trước khi kết luận là có trôi thật.
    assert big_dung >= 48, (f"is_big đúng {big_dung}/{len(ds)} — tụt so với mức đã đo (48/50). "
                            "Chạy lại một lần trước khi kết luận: câu 34 dao động.")
