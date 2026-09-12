"""memory.error_ledger + memory.forget + passport.diff + passport.upgrade — mốc M2.

CDS-12.6 MEMORY-06/07; CDS-12.2 PASSPORT-04/05; MEM-11 §4.3 và §6; KAD-07 §6.7; UC-B13.

Bốn năng lực này về **quên và nhớ có kiểm soát**. `error_ledger` nhớ cái đã sai để lần sau
không sai lại; `forget` xoá đúng thứ được phép xoá; `diff`/`upgrade` trả lời câu hỏi nặng nhất
của một dự án đang chạy: *nâng hộ chiếu chip lên bản mới thì mã nào phải xem lại*.
"""
from __future__ import annotations

import json

import pytest
import yaml

from eide_core import store
from eide_core.gateway import EchoPort, Gateway
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

PART = "st.stm32f411ce"


@pytest.fixture
def du_an(tmp_path, workspace):
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    echo = EchoPort([{"negative_prompt": "Không dùng HAL_Delay trong ISR của I2C1"}] * 6)
    led = Ledger(tmp_path / "ledger.jsonl")
    r = Router(gate=PolicyGate(), ledger=led)
    res = r.invoke("project.create", {"text": "dự án nhớ quên"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=led)
    ctx = Context(project_dir=root, extra={
        "gate": PolicyGate(), "ledger": led,
        "gateway": Gateway(config=cfg, ledger=led, ports={"gemini": echo, "claude": echo})})
    return r, ctx, root


def _nap_ho_chieu(root, pid, facts):
    """`facts` = [(fid, subject, predicate, value)]."""
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('src_1','stm32f411.svd','h1','svd','gold')")
        c.execute("INSERT OR IGNORE INTO passport (id, kind, header, created_at)"
                  " VALUES (?,'chip',?,'2026-09-10T00:00:00Z')",
                  (pid, json.dumps({"name": pid.split("@")[0]})))
        for fid, subj, vt, gt in facts:
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                      " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                      (fid, subj, vt, json.dumps(gt), "src_1", "parser", "gold", 1.0,
                       "reviewed", "C"))
            c.execute("INSERT INTO passport_fact (passport_id, fact_id) VALUES (?,?)", (pid, fid))
        c.commit()


# ================================================================ MEMORY-06 error_ledger


def test_negative_prompt_vao_C1_cua_coder_lan_sau(du_an):
    """tc MEMORY-06 nguyên văn: "negative_prompt xuất hiện trong C1 của coder lần sau".

    Đây là toàn bộ lý do sổ lỗi tồn tại: ghi một lỗi mà không ai đọc lại thì nó chỉ là một dòng
    nhật ký. Vòng khép kín là *lỗi → negative_prompt → ngữ cảnh lần sau*.
    """
    r, ctx, root = du_an
    out = r.invoke("memory.error_ledger", {
        "role": "coder", "kind": "hallucination", "chip": PART,
        "task_ref": "F-01", "evidence": "gọi HAL_Delay trong ISR"}, ctx).result
    assert out["id"].startswith("e_")
    assert out["negative_prompt"]

    bundle = r.invoke("memory.compose", {"role": "coder", "task_ref": "viết ISR I2C1"},
                      ctx).result["bundle"]
    c1 = "\n".join(b["text"] for b in bundle["blocks"] if b["layer"] == "C1")
    assert out["negative_prompt"] in c1


def test_negative_prompt_khong_qua_40_token(du_an, monkeypatch):
    """MEM-11 §6: "≤ 40 token". Một "lời nhắc đừng làm" dài hơn cả prompt vai trò sẽ đẩy thứ
    khác ra khỏi ngân sách — và nó xuất hiện ở MỌI lượt sau đó.

    Mô hình ở đây trả một câu DÀI có chủ ý: cắt là việc của MÃ, không phải của lời dặn trong
    prompt. Kiểm đột biến cho thấy bản test đầu (mô hình giả luôn trả câu ngắn) xanh cả khi
    phép cắt bị gỡ — nó chưa bao giờ chạy tới đó.
    """
    from eide_core.composer import uoc_token
    r, ctx, root = du_an

    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def prompt(self, role): return f"# {role}"

        def run(self, *a, **k):
            return _R({"negative_prompt": "Đừng bao giờ " + "lặp lại lỗi này " * 40})
    ctx.extra["gateway"] = _G()

    out = r.invoke("memory.error_ledger", {
        "role": "coder", "kind": "tool_fail", "evidence": "x" * 500}, ctx).result
    assert uoc_token(out["negative_prompt"]) <= 40
    assert out["negative_prompt"].startswith("Đừng bao giờ")


def test_ghi_ErrorLedgerEntry_co_TTL(du_an):
    """Bước 2: "TTL 30 ngày". Không có hạn thì một lỗi của tháng trước còn dạy mô hình tránh
    một thứ đã sửa từ lâu — và nó không bao giờ tự biến mất."""
    r, ctx, root = du_an
    r.invoke("memory.error_ledger", {"role": "coder", "kind": "refusal", "evidence": "x"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        (kind, ttl) = c.execute("SELECT kind, ttl_until FROM error_ledger").fetchone()
    assert kind == "refusal" and ttl > "2026-09-10"


def test_loi_het_han_khong_con_vao_ngu_canh(du_an):
    """TTL chỉ có nghĩa nếu chỗ ĐỌC tôn trọng nó."""
    r, ctx, root = du_an
    out = r.invoke("memory.error_ledger", {"role": "coder", "kind": "undo",
                                           "evidence": "hết hạn rồi"}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        c.execute("UPDATE error_ledger SET ttl_until='2020-01-01T00:00:00Z'")
        c.commit()
    bundle = r.invoke("memory.compose", {"role": "coder", "task_ref": "x"}, ctx).result["bundle"]
    c1 = "\n".join(b["text"] for b in bundle["blocks"] if b["layer"] == "C1")
    assert out["negative_prompt"] not in c1


def test_chi_lay_loi_cung_vai_tro(du_an):
    """Lỗi của `librarian` không dạy được gì cho `coder`: hai vai trò làm hai việc khác nhau, và
    trộn chúng làm ngữ cảnh mỗi vai trò đầy những điều không liên quan."""
    r, ctx, root = du_an
    out = r.invoke("memory.error_ledger", {"role": "librarian", "kind": "hallucination",
                                           "evidence": "bịa số trang"}, ctx).result
    bundle = r.invoke("memory.compose", {"role": "coder", "task_ref": "x"}, ctx).result["bundle"]
    c1 = "\n".join(b["text"] for b in bundle["blocks"] if b["layer"] == "C1")
    assert out["negative_prompt"] not in c1


# ================================================================ MEMORY-07 forget


def test_quen_cache(du_an):
    """tc MEMORY-07: TC-MM-07. `scope: cache` — thứ dựng lại được, xoá không mất gì."""
    r, ctx, root = du_an
    c = root / ".eide" / "cache"
    c.mkdir(parents=True, exist_ok=True)
    (c / "a.bin").write_bytes(b"x")
    (c / "b.bin").write_bytes(b"y")
    out = r.invoke("memory.forget", {"scope": "cache"}, ctx).result
    assert out["removed"] == 2
    assert not list(c.glob("*.bin"))


def test_quen_preference_theo_key(du_an):
    r, ctx, root = du_an
    r.invoke("project.preferences", {"op": "set", "key": "probe",
                                     "value": {"value": "stlink"}, "scope": "project"}, ctx)
    out = r.invoke("memory.forget", {"scope": "preference", "key": "probe"}, ctx).result
    assert out["removed"] == 1
    # Kiểm thẳng BẢNG `preference` của store, không qua `project.preferences list`: lệnh ấy gộp
    # cả phạm vi `user` từ `preferences.yaml` trong thư mục cấu hình người dùng (DDD-14 §6), mà
    # `memory.forget` cố ý không đụng tới — quên một tuỳ chọn ở dự án này không được xoá nó ở
    # mọi dự án khác.
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM preference WHERE key='probe'").fetchone()[0] == 0


def test_khong_cham_M4(du_an):
    """Bước 1 nguyên văn: "không chạm M4". M4 là tri thức đã duyệt — `fact`, `passport`. Một
    lệnh "quên cache" mà xoá luôn hộ chiếu là mất thứ tốn hàng giờ để dựng lại, và người gõ lệnh
    ấy đang nghĩ tới một thư mục tạm.
    """
    r, ctx, root = du_an
    _nap_ho_chieu(root, f"{PART}@1.0.0", [("f_1", f"chip:{PART}/periph:I2C1", "base_address", 1)])
    (root / ".eide" / "cache").mkdir(parents=True, exist_ok=True)
    (root / ".eide" / "cache" / "x.bin").write_bytes(b"x")

    r.invoke("memory.forget", {"scope": "cache"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM fact").fetchone()[0] == 1
        assert c.execute("SELECT COUNT(*) FROM passport").fetchone()[0] == 1


def test_run_dang_chay_bao_E1000(du_an):
    """Bước 1: "run đang chạy → E1000". Xoá một `run` đang chạy để lại một tiến trình không có
    chỗ ghi kết quả — và nó vẫn đang gây hiệu ứng."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO run (id, graph, state, started_at)"
                  " VALUES ('r_1','{}','running','2026-09-10T00:00:00Z')")
        c.commit()
    run = r.invoke("memory.forget", {"scope": "run"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_quen_run_da_xong_thi_duoc(du_an):
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO run (id, graph, state, started_at)"
                  " VALUES ('r_2','{}','done','2026-09-10T00:00:00Z')")
        c.commit()
    assert r.invoke("memory.forget", {"scope": "run"}, ctx).result["removed"] == 1


# ================================================================ PASSPORT-04 diff


def test_doi_mot_offset_thi_changed_bang_1(du_an):
    """tc PASSPORT-04 nguyên văn: "Đổi 1 offset → changed 1"."""
    r, ctx, root = du_an
    _nap_ho_chieu(root, f"{PART}@1.0.0", [
        ("f_a1", f"chip:{PART}/periph:I2C1/reg:CR1", "offset", 0),
        ("f_a2", f"chip:{PART}/periph:I2C1/reg:CR2", "offset", 4)])
    _nap_ho_chieu(root, f"{PART}@1.1.0", [
        ("f_b1", f"chip:{PART}/periph:I2C1/reg:CR1", "offset", 0),
        ("f_b2", f"chip:{PART}/periph:I2C1/reg:CR2", "offset", 8)])

    out = r.invoke("passport.diff", {"a": f"{PART}@1.0.0", "b": f"{PART}@1.1.0"}, ctx).result
    assert len(out["changed"]) == 1
    assert out["changed"][0]["subject"].endswith("reg:CR2")
    assert (out["changed"][0]["old"], out["changed"][0]["new"]) == (4, 8)
    assert out["added"] == [] and out["removed"] == []


def test_them_va_bot(du_an):
    r, ctx, root = du_an
    _nap_ho_chieu(root, f"{PART}@2.0.0", [("f_c1", f"chip:{PART}/periph:I2C1", "irq", 31)])
    _nap_ho_chieu(root, f"{PART}@2.1.0", [("f_d1", f"chip:{PART}/periph:SPI1", "irq", 35)])
    out = r.invoke("passport.diff", {"a": f"{PART}@2.0.0", "b": f"{PART}@2.1.0"}, ctx).result
    assert [x["subject"] for x in out["added"]] == [f"chip:{PART}/periph:SPI1"]
    assert [x["subject"] for x in out["removed"]] == [f"chip:{PART}/periph:I2C1"]


def test_ho_chieu_khong_co_bao_E2000(du_an):
    r, ctx, root = du_an
    _nap_ho_chieu(root, f"{PART}@3.0.0", [("f_e1", f"chip:{PART}/periph:I2C1", "irq", 31)])
    run = r.invoke("passport.diff", {"a": f"{PART}@3.0.0", "b": "khong.co@9.9.9"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ================================================================ PASSPORT-05 upgrade


def _chay_upgrade(r, ctx, pid, ver):
    """PASSPORT-05 là **T2**, ask "Luôn (ảnh hưởng mã)" ⇒ Router xếp hàng chờ. Nâng hộ chiếu là
    việc làm cũ đi một phần mã đang chạy, nên nó không bao giờ tự động."""
    run = r.invoke("passport.upgrade", {"id": pid, "version": ver}, ctx)
    assert run.status == "pending", "PASSPORT-05 là T2, phải hỏi người mọi lần"
    return r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)


def test_feature_dung_fact_doi_thanh_failing(du_an):
    """tc PASSPORT-05 nguyên văn: "Feature dùng fact đổi → failing".

    Một feature đang `passing` dựa trên một hằng số vừa đổi thì nó KHÔNG còn passing — nó chỉ
    chưa được kiểm lại. Để nguyên nhãn cũ là nói dối đúng chỗ người ta tin nhất.
    """
    r, ctx, root = du_an
    _nap_ho_chieu(root, f"{PART}@1.0.0", [
        ("f_g1", f"chip:{PART}/periph:I2C1/reg:CR1", "offset", 0)])
    _nap_ho_chieu(root, f"{PART}@1.1.0", [
        ("f_h1", f"chip:{PART}/periph:I2C1/reg:CR1", "offset", 16)])
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO code_unit (id, path, symbol, hash, cites, uses)"
                  " VALUES ('cu_1','src/i2c.c','i2c_init','h','[\"f_g1\"]','[]')")
        c.commit()
    (root / ".eide" / "FEATURES.json").write_text(json.dumps({"features": [
        {"id": "F-01", "title": "đọc IMU", "status": "passing", "evidence": ["cu_1"]}]}),
        encoding="utf-8")

    out = _chay_upgrade(r, ctx, f"{PART}@1.0.0", "1.1.0").result
    assert "cu_1" in out["impact"]["stale_code_units"]
    assert "F-01" in out["impact"]["features_to_recheck"]

    f = json.loads((root / ".eide" / "FEATURES.json").read_text(encoding="utf-8"))["features"]
    assert f[0]["status"] == "failing"


def test_ghim_phien_ban_moi(du_an):
    """Bước 1: "ghim mới". Nâng mà không ghim thì lần mở dự án sau vẫn đọc bản cũ — và bảng ảnh
    hưởng vừa tính ra chẳng thay đổi gì."""
    r, ctx, root = du_an
    _nap_ho_chieu(root, f"{PART}@1.0.0", [("f_i1", f"chip:{PART}/periph:I2C1", "irq", 31)])
    _nap_ho_chieu(root, f"{PART}@1.2.0", [("f_j1", f"chip:{PART}/periph:I2C1", "irq", 32)])
    _chay_upgrade(r, ctx, f"{PART}@1.0.0", "1.2.0")

    cfg = yaml.safe_load((root / ".eide" / "constraints.yaml").read_text(encoding="utf-8"))
    assert f"{PART}@1.2.0" in json.dumps(cfg, ensure_ascii=False)


def test_khong_co_ban_moi_bao_E2000(du_an):
    """`registry.pull` là mốc M4 nên chưa tải được bản mới. Nói thẳng ra kèm năng lực cần chạy,
    đừng nâng lên một phiên bản không có trong store."""
    r, ctx, root = du_an
    _nap_ho_chieu(root, f"{PART}@1.0.0", [("f_k1", f"chip:{PART}/periph:I2C1", "irq", 31)])
    run = r.invoke("passport.upgrade", {"id": f"{PART}@1.0.0", "version": "9.9.9"}, ctx)
    assert run.status == "pending"
    sau = r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)
    assert sau.status == "failed" and sau.error["eide_code"] == "E2000"
    assert "registry.pull" in sau.error.get("candidates", [])


# ---------- PASSPORT-08 resolve_address (M3): địa chỉ → ngoại vi/thanh ghi

def test_resolve_address_khop_CHINH_XAC(du_an):
    """tc PASSPORT-08: TC-40. `0x40005400`, `1073763328`, `0x40005400u` là cùng một địa chỉ —
    bắt người hover phải gõ đúng ký pháp của fact là bắt sai chỗ."""
    from eide.caps.passport import resolve_address

    _, ctx, root = du_an
    _fact_dc(root, "f_ra00000000001", "chip:st.stm32f411/periph:I2C1", "base_address",
             "0x40005400")
    for dang in ("0x40005400", "1073763328", "0x40005400u"):
        kq = resolve_address({"address": dang}, ctx)
        assert kq["subject"] == "chip:st.stm32f411/periph:I2C1", dang
        assert kq["facts"][0]["id"] == "f_ra00000000001"


def test_resolve_address_suy_ra_ngoai_vi_GAN_NHAT(du_an):
    """Một địa chỉ rơi giữa vùng thanh ghi phải suy ra ngoại vi chứa nó — đó là cách người ta
    đọc một bản đồ bộ nhớ. Kèm `offset` để người đọc biết đây là SUY RA."""
    from eide.caps.passport import resolve_address

    _, ctx, root = du_an
    _fact_dc(root, "f_ra00000000002", "chip:x/periph:I2C1", "base_address", "0x40005400")
    kq = resolve_address({"address": "0x40005410"}, ctx)
    assert kq["subject"] == "chip:x/periph:I2C1"
    assert kq["facts"][0]["offset"] == 0x10 and kq["facts"][0]["match"] == "nearest_base"


def test_resolve_address_KHONG_suy_qua_xa(du_an):
    """Đoán xa hơn một trang thì một địa chỉ RAM bất kỳ sẽ "thuộc về" ngoại vi cuối cùng trước
    nó — và một câu trả lời sai ở đây tệ hơn im lặng."""
    from eide.caps.passport import resolve_address

    _, ctx, root = du_an
    _fact_dc(root, "f_ra00000000003", "chip:x/periph:I2C1", "base_address", "0x40005400")
    assert resolve_address({"address": "0x20000000"}, ctx) == {"subject": None, "facts": []}


def test_resolve_address_KHONG_tra_fact_chua_duyet(du_an):
    """Hover chuột là chỗ người ta tin ngay, không ai dừng lại đọc `status`."""
    from eide.caps.passport import resolve_address

    _, ctx, root = du_an
    _fact_dc(root, "f_ra00000000004", "chip:x", "base_address", "0xDEAD", status="normalized")
    assert resolve_address({"address": "0xDEAD"}, ctx)["facts"] == []


def test_resolve_address_khong_tra_duoc_KHONG_phai_loi(du_an):
    """`errors: []` — người ta hover lên đủ thứ."""
    from eide.caps.passport import resolve_address

    _, ctx, _ = du_an
    assert resolve_address({"address": "0x12345678"}, ctx) == {"subject": None, "facts": []}


def _fact_dc(root, fid, subject, pred, val, status="verified"):
    import hashlib
    import json as _json

    from eide_core import store
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s_ra", "u", hashlib.sha256(b"s_ra").hexdigest(), "svd", "gold", "vendor-doc"))
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, subject, pred, _json.dumps(val), "s_ra", "parser", "gold", 1.0,
                   status, "A"))
        c.commit()
