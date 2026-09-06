"""WI-006 · Composer và MEMORY-01/02 — CXD-10 §2, §3, §4, §5, §7.

Ngân sách và thứ tự cắt đọc từ `docs/spec/context/budgets.json`; các test dưới đây kiểm rằng
mã DÙNG chúng, chứ không chỉ có chúng.
"""
from __future__ import annotations

import pytest
import yaml

from eide_core import store
from eide_core.composer import ContextBundle, cau_hinh, output_max, uoc_token
from eide_core.errors import EideError
from eide_core.gateway import EchoPort, Gateway
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def _rt(tmp_path, workspace, tra_loi=None):
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    echo = EchoPort(tra_loi or [])
    led = Ledger(tmp_path / "ledger.jsonl")
    gate = PolicyGate()
    r = Router(gate=gate, ledger=led)
    res = r.invoke("project.create", {"text": "dự án đèn giao thông", "chip": "STM32F411"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=led)
    ctx = Context(project_dir=root, extra={
        "gate": gate, "ledger": led,
        "gateway": Gateway(config=cfg, ledger=led, ports={"gemini": echo, "claude": echo})})
    return r, ctx, root, echo


# ---------------------------------------------------------------- §3 ngân sách

def test_du_chin_vai_tro_co_ngan_sach():
    """CXD-10 §3 có bảng cho cả chín vai trò của PRS-16 §2."""
    b = cau_hinh()["budget"]
    assert set(b) == {"intent", "librarian", "cartographer", "planner", "coder",
                      "reviewer", "debugger", "architect", "writer"}


def test_tong_ngan_sach_khop_bang_tai_lieu():
    b = cau_hinh()["budget"]
    assert b["intent"]["total"] == 2200
    assert b["coder"]["total"] == 8000
    assert b["architect"]["total"] == 9300


def test_vai_tro_sinh_khong_vuot_8000():
    """§3: "Tổng của vai trò SINH không vượt 8.000 (NFR-10)"; planner/architect được 12.000."""
    b = cau_hinh()["budget"]
    for vai in ("coder", "reviewer", "debugger", "writer"):
        assert b[vai]["total"] <= 8000, vai
    for vai in ("planner", "architect"):
        assert b[vai]["total"] <= 12000, vai


def test_gioi_han_dau_ra():
    """§3: "coder ≤ 16.000, writer ≤ 12.000, các vai trò khác ≤ 4.000"."""
    assert output_max("coder") == 16000
    assert output_max("writer") == 12000
    assert output_max("debugger") == 4000


def test_uoc_token_theo_tieng_viet():
    """§3: "1 token ≈ 3,5 ký tự tiếng Việt có dấu". Ước THẤP hơn thực tế sẽ để ngân sách bị
    vượt mà không ai báo, nên lấy 3,5 chứ không phải 4."""
    assert cau_hinh()["chars_per_token"] == 3.5
    assert uoc_token("") == 0
    assert uoc_token("a" * 350) == 100


# ---------------------------------------------------------------- §2 lớp và thứ tự

def test_lop_la_bi_tu_choi():
    b = ContextBundle(role="coder")
    with pytest.raises(EideError) as ei:
        b.add("C9", "gì đó")
    assert ei.value.code == "E1000"


def test_vai_tro_la_khong_co_ngan_sach():
    with pytest.raises(EideError) as ei:
        _ = ContextBundle(role="khong-co").budget
    assert ei.value.code == "E1001"


def test_C1_dung_dau_du_them_sau_cung():
    """CXD-10 §2: C1 "tĩnh; ĐỨNG ĐẦU; cache". PRS-16 §1 (4) dựa vào đó — mô hình tuân thủ
    điều cấm tốt hơn khi điều cấm đứng trước."""
    b = ContextBundle(role="coder")
    b.add("C7", "lịch sử")
    b.add("C4", "bảng fact")
    b.add("C1", "VAI TRÒ")
    b.add("C2", "ràng buộc")
    assert b.text().startswith("VAI TRÒ")
    assert b.text().index("ràng buộc") < b.text().index("bảng fact")


def test_khoi_rong_khong_vao_bundle():
    b = ContextBundle(role="coder")
    b.add("C4", "")
    assert b.blocks == []


# ---------------------------------------------------------------- §3, §5 cắt

def test_cat_theo_dung_thu_tu_uu_tien():
    """§3: "C7 (1) → C6 (2) → C5 (3) → C4 (4) → C3 (5) → C0 (6)"; C1 và C2 KHÔNG BAO GIỜ cắt."""
    b = ContextBundle(role="intent")            # tổng 2.200 token
    b.add("C1", "x" * 700)                      # 200 token
    b.add("C2", "y" * 700)                      # 200
    b.add("C0", "z" * 3500)                     # 1000
    b.add("C7", "t" * 7000)                     # 2000 → tổng 3400, vượt
    b.vua_ngan_sach()
    con = {k.layer for k in b.blocks}
    assert "C7" not in con, "C7 phải bị cắt trước"
    assert {"C1", "C2"} <= con
    assert b.compressions == ["cut:C7"]


def test_C1_va_C2_khong_bao_gio_bi_cat():
    """Không phải chi tiết kỹ thuật: C1 chứa các câu KHÔNG ĐƯỢC, C2 chứa chân cấm và cờ nhạy
    cảm. Một bộ nén tự bỏ hai lớp ấy khi chật chỗ sẽ lấy đi đúng phần giữ cho mô hình không
    làm bậy — vào đúng lúc ngữ cảnh căng nhất."""
    b = ContextBundle(role="intent")
    b.add("C1", "x" * 20000)
    b.add("C2", "y" * 20000)
    b.vua_ngan_sach()
    assert {k.layer for k in b.blocks} == {"C1", "C2"}
    assert b.total_tokens > b.budget["total"]     # vẫn vượt, và §7 sẽ chặn


def test_vuot_sau_khi_cat_thi_E5001_va_KHONG_goi_mo_hinh():
    """§7: tràn ⇒ không gọi. Gọi rồi mong nhà cung cấp bỏ qua là tệ hơn: nó sẽ cắt ở đầu kia
    theo cách ta không kiểm soát — thường là phần cuối, tức phần động và quan trọng nhất."""
    b = ContextBundle(role="intent")
    b.add("C1", "x" * 20000)
    b.vua_ngan_sach()
    with pytest.raises(EideError) as ei:
        b.kiem_tran()
    assert ei.value.code == "E5001"
    assert ei.value.data["role"] == "intent"
    assert "C1" in ei.value.data["per_layer"]


def test_cat_ca_khoi_chu_khong_cat_giua_chung():
    """Một bảng fact bị cắt đôi vẫn TRÔNG như một bảng fact, và mô hình sẽ dùng nửa còn lại
    như thể đó là tất cả."""
    b = ContextBundle(role="intent")
    b.add("C1", "x" * 350)
    b.add("C4", "F1|3.3V\nF2|8MHz\n" * 500)
    truoc = len(b.blocks)
    b.vua_ngan_sach()
    assert len(b.blocks) < truoc
    for k in b.blocks:
        assert k.text and not k.text.endswith("…")    # không có khối nào bị xén


# ---------------------------------------------------------------- MEMORY-01

def test_compose_dung_du_lop_cho_intent(tmp_path, workspace):
    """§4.1: vai trò `intent` có C0, C1, C1′ (trạng thái dự án) và C7 — không có C3…C6."""
    r, ctx, root, echo = _rt(tmp_path, workspace)
    b = r.invoke("memory.compose", {"role": "intent", "task_ref": "mở dự án đèn giao thông"},
                 ctx).result["bundle"]
    lop = {k["layer"] for k in b["blocks"]}
    assert "C1" in lop and "C0" in lop
    assert not (lop & {"C3", "C4", "C5", "C6"}), f"intent không dùng các lớp này: {lop}"
    assert echo.goi == [], "compose là deterministic, không gọi mô hình"


def test_compose_khong_dua_nang_luc_R4_vao_C0_cua_intent(tmp_path, workspace):
    """§4.2: "Không đưa năng lực lớp R4 vào C0 của intent trừ khi câu lệnh chứa từ khóa tương
    ứng (xóa, fuse, phát hành)". Ràng buộc AN TOÀN: một danh sách có sẵn `target.erase` làm
    mô hình dễ chọn nó cho một câu mơ hồ."""
    r, ctx, root, _ = _rt(tmp_path, workspace)
    from eide_core.registry import get_registry
    r4 = {c.spec.id for c in get_registry().list() if c.spec.risk_class == "R4"}
    assert r4, "phải có năng lực R4 để bài kiểm này có nghĩa"

    b = r.invoke("memory.compose", {"role": "intent", "task_ref": "mở dự án"}, ctx).result["bundle"]
    c0 = next((k for k in b["blocks"] if k["layer"] == "C0"), None)
    if c0:
        assert not (set(c0["sources"]) & r4), f"R4 lọt vào C0: {set(c0['sources']) & r4}"

    b2 = r.invoke("memory.compose", {"role": "intent", "task_ref": "xóa dự án này đi"},
                  ctx).result["bundle"]
    c0b = next((k for k in b2["blocks"] if k["layer"] == "C0"), None)
    assert c0b is not None


def test_compose_ghi_ledger_context_bundle(tmp_path, workspace):
    """API-15 §5 `context.bundle` {role, hash, tokens{C0..C7}, sources[], compressions[]}."""
    r, ctx, root, _ = _rt(tmp_path, workspace)
    r.invoke("memory.compose", {"role": "coder", "task_ref": "nháy LED"}, ctx)
    ev = [x for x in r.ledger.records() if x["kind"] == "context.bundle"]
    assert len(ev) == 1
    d = ev[0]["data"]
    assert d["role"] == "coder" and d["hash"]
    assert isinstance(d["tokens"], dict) and "C1" in d["tokens"]


def test_compose_dua_rang_buoc_du_an_vao_C2(tmp_path, workspace):
    r, ctx, root, _ = _rt(tmp_path, workspace)
    b = r.invoke("memory.compose", {"role": "coder", "task_ref": "nháy LED"}, ctx).result["bundle"]
    c2 = next(k for k in b["blocks"] if k["layer"] == "C2")
    assert "STM32F411" in c2["text"]
    assert "autonomy" in c2["text"]        # §4.3: giữ nguyên các mục an toàn
    assert c2["cacheable"] is True         # §2: C2 tĩnh theo dự án, cache


def test_bundle_dung_schema_cua_CXD_2_1(tmp_path, workspace):
    r, ctx, root, _ = _rt(tmp_path, workspace)
    b = r.invoke("memory.compose", {"role": "coder", "task_ref": "x"}, ctx).result["bundle"]
    assert set(b) >= {"role", "task_ref", "blocks", "budget", "total_tokens", "hash"}
    for k in b["blocks"]:
        assert set(k) >= {"layer", "text", "tokens", "sources", "cut_priority"}
        assert 1 <= k["cut_priority"] <= 9


# ---------------------------------------------------------------- MEMORY-02

def test_nen_log_GIU_NGUYEN_mau_loi(tmp_path, workspace):
    """tc: "kết quả ≤ target; MẪU LỖI GIỮ NGUYÊN".

    `log` không gọi mô hình, và đó là điều kiện chứ không phải tối ưu: một mô hình tóm tắt log
    sẽ diễn đạt lại dòng lỗi thành câu văn, làm mất chính chuỗi mà người ta cần grep.
    """
    r, ctx, root, echo = _rt(tmp_path, workspace)
    log = "\n".join([f"[{i}] ok bình thường" for i in range(300)]
                    + ["HardFault at 0x0800_1234 CFSR=0x00008200"]
                    + [f"[{i}] sau đó" for i in range(50)])
    out = r.invoke("memory.compress", {"text": log, "kind": "log", "target_tokens": 200},
                   ctx).result
    assert "HardFault at 0x0800_1234 CFSR=0x00008200" in out["text"]
    assert out["compressions"] == ["log:window"]
    assert echo.goi == [], "nén log không được gọi mô hình"


def test_nen_code_chi_giu_chu_ky(tmp_path, workspace):
    r, ctx, root, _ = _rt(tmp_path, workspace)
    ma = "import os\n\ndef doc_adc(kenh):\n    x = 1\n    return x\n\nclass Bo:\n    pass\n" * 40
    out = r.invoke("memory.compress", {"text": ma, "kind": "code", "target_tokens": 100},
                   ctx).result
    assert "def doc_adc" in out["text"] and "x = 1" not in out["text"]
    assert out["compressions"] == ["code:function_only"]


def test_du_ngan_thi_khong_nen(tmp_path, workspace):
    r, ctx, root, echo = _rt(tmp_path, workspace)
    out = r.invoke("memory.compress", {"text": "ngắn thôi", "kind": "history",
                                       "target_tokens": 500}, ctx).result
    assert out["text"] == "ngắn thôi" and out["compressions"] == []
    assert echo.goi == []


def test_nen_history_goi_mo_hinh_re(tmp_path, workspace):
    """§5: lượt cũ được tóm tắt "bởi mô hình rẻ (vai trò intent, temperature 0)"."""
    r, ctx, root, echo = _rt(tmp_path, workspace, [
        {"intent": "unknown", "slots": {}, "is_big": False, "confidence": 0.5,
         "tom_tat": "Đã tạo dự án và chọn ST-Link."}])
    out = r.invoke("memory.compress", {"text": "lượt rất dài " * 500, "kind": "history",
                                       "target_tokens": 60}, ctx).result
    assert out["text"] == "Đã tạo dự án và chọn ST-Link."
    assert out["compressions"] == ["history:summarize"]
    assert echo.goi and echo.goi[0]["model"] == "gemini-3.8-flash"   # mô hình rẻ


def test_nhanh_du_phong_cua_C0_cung_chan_R4(tmp_path, workspace):
    """Nhánh dự phòng chạy khi câu lệnh KHÔNG khớp năng lực nào — tức lúc mơ hồ nhất, và cũng
    là lúc một `target.erase` nằm sẵn trong danh sách nguy hiểm nhất."""
    r, ctx, root, _ = _rt(tmp_path, workspace)
    from eide_core.registry import get_registry
    r4 = {c.spec.id for c in get_registry().list() if c.spec.risk_class == "R4"}
    b = r.invoke("memory.compose", {"role": "intent", "task_ref": "zzzz qqqq"},
                 ctx).result["bundle"]
    c0 = next((k for k in b["blocks"] if k["layer"] == "C0"), None)
    assert c0 is not None, "nhánh dự phòng phải cho ra một C0 khác rỗng"
    assert not (set(c0["sources"]) & r4)


def test_C0_cua_intent_CO_CA_danh_sach_y_dinh_lan_nang_luc(tmp_path, workspace):
    """DPS-09 §4.1 đòi HAI thứ, và thiếu một thứ là một hồi quy ĐO ĐƯỢC.

    Bản đầu của Composer chỉ đưa mô tả năng lực, bỏ mất `dialog/intents.md`. TC-59 tụt từ 98%
    xuống 82% — mô hình mất bảng phân biệt `view.ask` với `debug.ask` mà DEV-021 dựng ra.
    Toàn bộ test dùng EchoPort vẫn xanh suốt, nên chỗ này cần một cái chốt riêng.
    """
    r, ctx, root, _ = _rt(tmp_path, workspace)
    b = r.invoke("memory.compose", {"role": "intent", "task_ref": "mở dự án"},
                 ctx).result["bundle"]
    c0 = next(k for k in b["blocks"] if k["layer"] == "C0")
    assert "dialog/intents.md" in c0["sources"], "thiếu danh sách ý định"
    assert "`view.ask` hỏi tri thức TĨNH" in c0["text"], "thiếu bảng phân biệt"
    assert "Năng lực liên quan:" in c0["text"], "thiếu mô tả năng lực"
