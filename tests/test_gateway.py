"""WI-013 · Gateway LLM — PRS-16 §1-§4; SDD-04 §4.3, §6; API-15 §5 `model.call`.

Test hằng ngày KHÔNG ra mạng: dùng `EchoPort` (DEP-26 §5 gọi job này là `contract` —
"adapter LLM với bản ghi/phát lại"). Gọi mô hình thật là việc của job `dialog` chạy ban đêm,
ở đây nằm sau dấu `@pytest.mark.llm` và bị loại khỏi `make check`.
"""
from __future__ import annotations

import json
import os

import pytest
import yaml

from eide_core.errors import EideError
from eide_core.gateway import EchoPort, Gateway, GatewayError
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir

# Schema Intent theo DPS-09 §4.1, rút gọn về bốn trường bắt buộc. Enum là phần QUAN TRỌNG chứ
# không phải trang trí: không có nó, mô hình thật trả "create_project" — hợp lý với người, vô
# nghĩa với registry. Có enum thì nhà cung cấp ép về đúng một trong các mã năng lực.
INTENT_ENUM = ["project.create", "project.open", "knowledge.build", "env.setup", "sim.run",
               "code.feature", "target.flash", "debug.ask", "req.analyze", "arch.design",
               "diagram.draw", "doc.write", "view.ask", "discover.scan", "policy.stop",
               "policy.set", "big_command", "unknown"]
S_INTENT = {
    "type": "object",
    "required": ["intent", "confidence"],
    "properties": {"intent": {"type": "string", "enum": INTENT_ENUM},
                   "confidence": {"type": "number"},
                   "slots": {"type": "object"}},
}


def _gw(tmp_path, tra_loi=None, **cfg_override):
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    for k, v in cfg_override.items():
        cfg[k] = {**cfg.get(k, {}), **v} if isinstance(v, dict) else v
    echo = EchoPort(tra_loi or [])
    gw = Gateway(config=cfg, ledger=Ledger(tmp_path / "ledger.jsonl"),
                 ports={"gemini": echo, "claude": echo})
    return gw, echo


# ---------- models.yaml và bí danh (SDD-04 §6, PRS-16 §2) ----------

def test_du_chin_vai_tro_cua_prs16():
    """PRS-16 §2 liệt kê đúng 9 vai trò; thiếu một vai trò là thiếu một phần sản phẩm."""
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    assert set(cfg["roles"]) == {"intent", "librarian", "cartographer", "planner", "coder",
                                 "reviewer", "debugger", "architect", "writer"}


def test_moi_vai_tro_co_prompt_va_moi_prompt_co_vai_tro():
    """PRS-16 §3: `prompts/<role>.md` cho từng vai trò. Hai chiều, để không có prompt mồ côi."""
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    tep = {p.stem for p in (spec_dir() / "prompts").glob("*.md")}
    assert tep == set(cfg["roles"])


def test_prompt_khong_qua_400_token():
    """PRS-16 §1 quy tắc (3): "prompt hệ thống ≤ 400 token — tri thức vào C2–C6, không nhét
    vào prompt". Đếm thô bằng từ; vượt xa ngưỡng nghĩa là tri thức đang bị nhét nhầm chỗ."""
    for p in (spec_dir() / "prompts").glob("*.md"):
        tu = len(p.read_text(encoding="utf-8").split())
        assert tu <= 400, f"{p.name}: {tu} từ"


def test_prompt_co_du_bon_phan(tmp_path):
    """PRS-16 §3: "Mỗi prompt gồm bốn phần cố định: NHIỆM VỤ, KHÔNG ĐƯỢC, PHẢI, ĐẦU RA"."""
    gw, _ = _gw(tmp_path)
    for role in yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))["roles"]:
        t = gw.prompt(role)
        for phan in ("NHIỆM VỤ:", "KHÔNG ĐƯỢC:", "PHẢI:", "ĐẦU RA:"):
            assert phan in t, f"{role} thiếu {phan}"


def test_khong_duoc_dung_truoc_phai(tmp_path):
    """PRS-16 §1 quy tắc (4): "nêu rõ KHÔNG ĐƯỢC LÀM GÌ TRƯỚC phải làm gì (mô hình tuân thủ
    cấm tốt hơn khi đứng đầu)". Thứ tự ở đây là một yêu cầu, không phải trình bày."""
    gw, _ = _gw(tmp_path)
    for role in yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))["roles"]:
        t = gw.prompt(role)
        assert t.index("KHÔNG ĐƯỢC:") < t.index("PHẢI:"), role


def test_bi_danh_duoc_giai_thanh_model_that(tmp_path):
    gw, _ = _gw(tmp_path)
    uv = gw.ung_vien("intent")
    assert [x["alias"] for x in uv] == ["gemini-flash", "claude-haiku"]
    assert uv[0]["model"] == "gemini-3.8-flash"     # chủ sản phẩm chốt 06/09/2026
    assert uv[0]["provider"] == "gemini"


def test_moi_bi_danh_deu_co_gia():
    """Thiếu giá thì `daily_budget_usd` không cưỡng chế được và cost_usd luôn bằng 0."""
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    for a in cfg["aliases"].values():
        assert a["model"] in cfg["pricing"], a["model"]


def test_vai_tro_la_bao_E1001(tmp_path):
    gw, _ = _gw(tmp_path)
    with pytest.raises(EideError) as ei:
        gw.run("khong-co-vai-tro-nay", "xin chào", S_INTENT)
    assert ei.value.code == "E1001"


# ---------- gọi và đầu ra có cấu trúc ----------

def test_chay_mot_vai_tro(tmp_path):
    gw, echo = _gw(tmp_path, [{"intent": "project.create", "confidence": 0.9, "slots": {}}])
    r = gw.run("intent", "tạo dự án robot hai bánh", S_INTENT)
    assert r.data["intent"] == "project.create"
    assert r.model_id == "gemini-3.8-flash"
    assert echo.goi[0]["system"].startswith("# Vai trò: intent")


def test_dau_ra_sai_schema_la_E5002(tmp_path):
    """PRS-16 §1 (2): đầu ra theo schema là bắt buộc. Trả văn xuôi là LỖI, không phải biến thể."""
    gw, _ = _gw(tmp_path, [{"intent": "project.create"}])       # thiếu `confidence`
    with pytest.raises(EideError) as ei:
        gw.run("intent", "tạo dự án", S_INTENT)
    assert ei.value.code == "E5002"


def test_system_extra_noi_vao_cuoi_prompt(tmp_path):
    """PRS-16 §1 (6): prompt phủ định từ sổ lỗi "được nối vào CUỐI C1"."""
    gw, echo = _gw(tmp_path, [{"intent": "unknown", "confidence": 0.5}])
    gw.run("intent", "câu lệnh", S_INTENT, system_extra="KHÔNG suy ra bit CTRL_MEAS từ trí nhớ.")
    s = echo.goi[0]["system"]
    assert s.startswith("# Vai trò: intent")
    assert s.rstrip().endswith("KHÔNG suy ra bit CTRL_MEAS từ trí nhớ.")


# ---------- đường lui (SDD-04 §6 policy.fallback_on) ----------

def test_lui_sang_ung_vien_sau_khi_gap_rate_limit(tmp_path):
    gw, echo = _gw(tmp_path, [GatewayError("rate_limit", "429"),
                              {"intent": "project.open", "confidence": 0.8}])
    r = gw.run("intent", "mở dự án", S_INTENT)
    assert r.data["intent"] == "project.open"
    assert [g["model"] for g in echo.goi] == ["gemini-3.8-flash", "claude-haiku-4-5-20251001"]


def test_khong_lui_khi_loi_khong_thuoc_fallback_on(tmp_path):
    """`fallback_on: [rate_limit, timeout, refusal]` — lỗi khác thì dừng ngay.

    Lui vô điều kiện sẽ biến một lỗi cấu hình (thiếu khóa) thành hai lời gọi hỏng và một
    thông báo nói về nhà cung cấp thứ hai, che mất nguyên nhân thật.
    """
    gw, echo = _gw(tmp_path, [GatewayError("no_key", "thiếu khóa"),
                              {"intent": "unknown", "confidence": 0.5}])
    with pytest.raises(EideError) as ei:
        gw.run("intent", "lệnh", S_INTENT)
    assert ei.value.code == "E5000" and ei.value.data["kind"] == "no_key"
    assert len(echo.goi) == 1


def test_het_ung_vien_thi_bao_E5000(tmp_path):
    gw, _ = _gw(tmp_path, [GatewayError("rate_limit", "429"), GatewayError("rate_limit", "429")])
    with pytest.raises(EideError) as ei:
        gw.run("intent", "lệnh", S_INTENT)
    assert ei.value.code == "E5000"


# ---------- ledger model.call (API-15 §5) ----------

def test_ghi_du_truong_model_call(tmp_path):
    gw, _ = _gw(tmp_path, [{"intent": "unknown", "confidence": 0.5}])
    gw.run("intent", "lệnh", S_INTENT)
    rec = [r for r in gw.ledger.records() if r["kind"] == "model.call"]
    assert len(rec) == 1
    assert set(rec[0]["data"]) >= {"role", "model_id", "request_hash", "prompt_hash", "tokens_in",
                                  "tokens_out", "cache_read_tokens", "latency_ms", "cost_usd",
                                  "stop_reason"}
    assert rec[0]["data"]["role"] == "intent"
    assert gw.ledger.verify() == (True, 0)


def test_loi_cung_duoc_ghi_kem_error_kind(tmp_path):
    """Một lời gọi hỏng vẫn là một lời gọi — nếu không ghi thì chi phí và tỷ lệ lỗi đều sai."""
    gw, _ = _gw(tmp_path, [GatewayError("rate_limit", "429"), {"intent": "unknown", "confidence": 0.5}])
    gw.run("intent", "lệnh", S_INTENT)
    rec = [r["data"] for r in gw.ledger.records() if r["kind"] == "model.call"]
    assert len(rec) == 2
    assert rec[0]["error_kind"] == "rate_limit" and rec[0]["stop_reason"] == "error"
    assert "error_kind" not in rec[1]


def test_cost_usd_tinh_theo_bang_gia(tmp_path):
    gw, _ = _gw(tmp_path, [{"intent": "unknown", "confidence": 0.5}])
    r = gw.run("intent", "lệnh", S_INTENT)
    # EchoPort trả 10 token vào, 20 ra; gemini-3.8-flash = 0.30/2.50 USD mỗi 1M
    assert r.cost_usd == pytest.approx(10 / 1e6 * 0.30 + 20 / 1e6 * 2.50)


# ---------- ngân sách (SDD-04 §6 policy.daily_budget_usd) ----------

def test_vuot_ngan_sach_thi_chan_TRUOC_khi_goi(tmp_path):
    """Kiểm sau khi gọi thì tiền đã tiêu rồi — ngân sách chỉ có nghĩa nếu nó chặn được."""
    gw, echo = _gw(tmp_path, [{"intent": "unknown", "confidence": 0.5}], policy={"daily_budget_usd": 0.001})
    gw.ledger.append("model.call", {"role": "coder", "model_id": "m", "cost_usd": 0.5})
    with pytest.raises(EideError) as ei:
        gw.run("intent", "lệnh", S_INTENT)
    assert ei.value.code == "E3003"          # BUDGET_EXCEEDED, không phải lỗi mô hình
    assert echo.goi == []                    # và KHÔNG có lời gọi nào ra ngoài


def test_offline_mode_khong_goi_mo_hinh(tmp_path):
    gw, echo = _gw(tmp_path, [{"intent": "unknown", "confidence": 0.5}], policy={"offline_mode": True})
    with pytest.raises(EideError) as ei:
        gw.run("intent", "lệnh", S_INTENT)
    assert ei.value.code == "E5000" and echo.goi == []


# ---------- bí mật không lọt vào ledger (API-15 §7) ----------

def test_khoa_api_khong_bao_gio_vao_ledger(tmp_path):
    """Ledger là append-only và chống sửa: một khóa lọt vào thì không gỡ ra được nữa."""
    led = Ledger(tmp_path / "l.jsonl")
    led.append("error", {"kind": "tool_fail", "evidence": "curl -H 'Bearer sk-abcdef0123456789xyz'"})
    led.append("model.call", {"role": "intent", "model_id": "m",
                              "stop_reason": "AIzaSyD-khoa-that-0123456789abcdef"})
    noi_dung = (tmp_path / "l.jsonl").read_text(encoding="utf-8")
    assert "sk-abcdef0123456789xyz" not in noi_dung
    assert "AIzaSyD-khoa-that-0123456789abcdef" not in noi_dung
    assert "<đã che>" in noi_dung
    assert led.verify() == (True, 0)          # che TRƯỚC khi băm nên chuỗi vẫn liền


# ---------- mô hình thật (job `dialog` của DEP-26 §5; không chạy trong make check) ----------

@pytest.mark.llm
@pytest.mark.skipif(not os.environ.get("GEMINI_API_KEY"), reason="cần GEMINI_API_KEY")
def test_gemini_that_tra_dung_schema(tmp_path):
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    gw = Gateway(config=cfg, ledger=Ledger(tmp_path / "ledger.jsonl"))
    r = gw.run("intent", "tạo cho anh dự án robot hai bánh tự cân bằng dùng STM32F411", S_INTENT)
    # Enum được nhà cung cấp cưỡng chế, nên đầu ra dùng được NGAY với registry — không cần
    # một lớp đoán ý ở giữa. Đó là toàn bộ lý do PRS-16 §1 (2) đòi schema mẫu số chung.
    assert r.data["intent"] in INTENT_ENUM
    assert r.data["intent"] == "project.create"
    assert 0 <= r.data["confidence"] <= 1
    assert r.tokens_in > 0 and r.cost_usd > 0
    print("\nGemini thật →", json.dumps(r.data, ensure_ascii=False))
