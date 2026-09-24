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


def test_bo_qua_nha_cung_cap_chua_cau_hinh(tmp_path, monkeypatch):
    """Nhà cung cấp không có khóa thì VẮNG MẶT, không phải hỏng.

    Vai trò `planner` có ứng viên đầu là claude-opus. Với một máy chỉ có khóa Gemini — đúng
    tình huống thật của chủ sản phẩm — nếu coi thiếu khóa là lỗi thì planner, architect,
    reviewer, debugger, writer đều chết, dù Gemini đứng ngay sau và dùng được.
    """
    from eide_core.gateway import ClaudePort, GeminiPort
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.setenv("GEMINI_API_KEY", "AIza-gia-lam")
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    echo = EchoPort([{"steps": [], "citations": [], "missing": []}])
    gw = Gateway(config=cfg, ledger=Ledger(tmp_path / "l.jsonl"),
                 ports={"gemini": echo, "claude": ClaudePort()})
    gw.run("planner", "lập kế hoạch", {"type": "object"})
    # Đi thẳng tới gemini-pro, KHÔNG thử claude-opus rồi mới lui
    assert [g["model"] for g in echo.goi] == ["gemini-3.1-pro-preview"]
    assert not [r for r in gw.ledger.records()
                if (r["data"] or {}).get("error_kind") == "no_key"], "không được ghi như một lỗi"
    assert GeminiPort().co_khoa() and not ClaudePort().co_khoa()


def test_khong_nha_cung_cap_nao_cau_hinh_thi_bao_ro(tmp_path, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    from eide_core.gateway import ClaudePort, GeminiPort
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    gw = Gateway(config=cfg, ledger=Ledger(tmp_path / "l.jsonl"),
                 ports={"gemini": GeminiPort(), "claude": ClaudePort()})
    with pytest.raises(EideError) as ei:
        gw.run("intent", "lệnh", S_INTENT)
    assert ei.value.code == "E5000"
    assert "chưa cấu hình" in str(ei.value) or "cần khóa" in str(ei.value)


# ---------- [DEV-216] Đầu ra bị cắt phải NÓI LÀ BỊ CẮT

def test_dau_ra_bi_cat_thi_noi_dung_ly_do_chu_khong_noi_sai_dinh_dang():
    """Câu lỗi sai hướng đắt hơn câu lỗi cộc lốc. [DEV-216]

    Cả hai cổng ĐỀU đọc `finishReason`/`stop_reason` — nhưng ở vị trí đối số đứng SAU
    `_doc_json(text)`, mà Python tính đối số từ trái sang phải. Nên khi đầu ra bị cắt giữa
    chừng, `_doc_json` ném trước và thông tin "bị cắt" đang nằm ngay đó bị vứt đi.

    Người dùng nhận *"Đầu ra không phải JSON: {\\"title\\":\\"ADR: Chọn kiến trúc…"* — một câu
    nói rằng mô hình trả sai định dạng, trong khi phần in ra BẮT ĐẦU BẰNG JSON HỢP LỆ. Nó đẩy
    người đọc đi tìm lỗi định dạng ở một chỗ không có lỗi nào.
    """
    import pytest

    from eide_core.gateway import GatewayError, _kiem_cat

    with pytest.raises(GatewayError) as e:
        _kiem_cat("MAX_TOKENS", "gemini-pro", 4096)
    assert "BỊ CẮT" in str(e.value) and "4096" in str(e.value)
    assert "max_output" in str(e.value), "không chỉ ra chỗ sửa"
    assert e.value.kind == "truncated"

    # Dừng bình thường thì không được kêu.
    _kiem_cat("stop", "gemini-pro", 4096)
    _kiem_cat("end_turn", "claude-sonnet", 8192)


def test_cat_vi_PHAN_NGHI_phai_noi_khac_cat_vi_cau_tra_loi_dai():
    """Hai nguyên nhân đòi hai cách chữa NGƯỢC NHAU, nên câu lỗi phải phân biệt được. [DEV-216]

    Token "nghĩ" của mô hình suy luận cũng tính vào `maxOutputTokens`. Khi phần nghĩ ăn hết
    ngân sách, lời khuyên "nới `max_output`" là SAI — nới trần thì phần nghĩ giãn theo và lần
    sau vẫn cắt. Đo 24/09/2026: một câu hỏi tầm thường tiêu 1037 token nghĩ cho 186 token trả
    lời. Câu lỗi khuyên sai hướng ở đây đắt gấp đôi: nó vừa không chữa được, vừa tốn một vòng
    thử nữa mới biết là không chữa được.
    """
    from eide_core.gateway import GatewayError, _kiem_cat

    with pytest.raises(GatewayError) as e:
        _kiem_cat("MAX_TOKENS", "gemini-pro", 12288, 9000)
    assert "NGHĨ" in str(e.value), "không chỉ ra thủ phạm là phần nghĩ"
    assert "không cứu được" in str(e.value).lower() or "KHÔNG cứu" in str(e.value)

    # Phần nghĩ nhỏ thì thủ phạm là câu trả lời — vẫn khuyên nới trần.
    with pytest.raises(GatewayError) as e2:
        _kiem_cat("MAX_TOKENS", "gemini-pro", 12288, 300)
    assert "max_output" in str(e2.value) and "NGHĨ" not in str(e2.value)


def test_tran_phan_nghi_luon_chua_mot_nua_ngan_sach_cho_cau_tra_loi():
    """`thinkingBudget` không đặt thì mô hình nghĩ tuỳ ý và chạm trần trước khi kịp trả lời.

    Chia đôi chứ không cắt sạch: bỏ hẳn phần nghĩ làm hỏng chất lượng của đúng những vai trò
    cần nó nhất (`architect`, `planner`). Nửa còn lại là phần LUÔN dành cho JSON.
    """
    from eide_core.gateway import NGHI_TOI_THIEU, _han_nghi

    assert _han_nghi(12288) == 6144
    assert _han_nghi(12288) < 12288, "phần nghĩ được phép ăn cả ngân sách"
    # Trần quá nhỏ thì sàn giữ cho mô hình suy luận vẫn nghĩ được.
    assert _han_nghi(256) == NGHI_TOI_THIEU


def test_token_NGHI_phai_vao_chi_phi_vi_no_bi_tinh_tien():
    """Bỏ token nghĩ khỏi `tokens_out` thì `cost_usd` — và trần `daily_budget_usd` dựng trên
    nó — hụt đúng phần đắt nhất. Đo 24/09/2026: 1037/1223 token đầu ra (85%) vô hình với ngân
    sách, tức ngân sách ngày cho tiêu gấp gần bảy lần con số chủ sản phẩm đặt ra.
    """
    import eide_core.gateway as gw

    goi: dict[str, object] = {}

    def gia_post(url, body, headers):
        goi["body"] = body
        return {"candidates": [{"finishReason": "STOP",
                                "content": {"parts": [{"text": '{"ok": true}'}]}}],
                "usageMetadata": {"promptTokenCount": 26, "candidatesTokenCount": 186,
                                  "thoughtsTokenCount": 1037}}

    that = gw._post
    gw._post = gia_post
    try:
        r = gw.GeminiPort(api_key="x").generate(
            "gemini-pro", "hệ thống", "câu hỏi", {"type": "object"}, max_output=12288)
    finally:
        gw._post = that

    assert r.tokens_out == 1223, f"token nghĩ bị bỏ khỏi chi phí (được {r.tokens_out})"
    # Và trần phần nghĩ phải thật sự được gửi đi, không chỉ tính ra rồi bỏ đó.
    cfg = goi["body"]["generationConfig"]           # type: ignore[index]
    assert cfg["thinkingConfig"]["thinkingBudget"] == 6144


def test_CAT_khong_duoc_coi_la_refusal_de_khoi_lui_vo_ich():
    """`policy.fallback_on` có `refusal`. Gọi một lần bị cắt là refusal thì Gateway lặng lẽ thử
    ứng viên kế — mà ứng viên kế cũng chạm đúng cái trần ấy.

    Lui sang một mô hình khác không chữa được một cái trần đặt quá thấp; nó chỉ tốn thêm một
    lời gọi và giấu mất nguyên nhân thật.
    """
    import yaml

    from eide_core.gateway import GatewayError, _kiem_cat
    from eide_core.paths import spec_dir

    with pytest.raises(GatewayError) as e:
        _kiem_cat("length", "m", 1024)
    pol = (yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
           .get("policy") or {})
    assert e.value.kind not in (pol.get("fallback_on") or []), \
        "lỗi cắt rơi vào danh sách lui — Gateway sẽ thử lại vô ích"


def test_vai_tro_SINH_VAN_BAN_DAI_deu_co_max_output_rieng():
    """`architect` viết ADR — tài liệu dài theo bản chất. Không khai `max_output` thì nó rơi về
    mặc định 4096 của Gateway và hỏng MỌI LẦN, không ngẫu nhiên.

    Đo 24/09/2026: TC002, TC008, TC048 đều chết ở `arch.adr` E5000.
    """
    import yaml

    from eide_core.paths import spec_dir

    roles = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))["roles"]
    for ten in ("architect", "coder", "writer"):
        assert roles[ten].get("max_output", 0) >= 8192, \
            f"vai trò `{ten}` sinh văn bản dài mà dùng trần mặc định 4096"
