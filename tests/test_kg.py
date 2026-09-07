"""Nhóm kg.* — CDS-12.2; KAD-07 §6.3 (cạnh), §6.5 (chính sách xung đột).

tc của hợp đồng: KG-01 "Đổi store → rebuild"; KG-02 TC-13/TC-21; KG-03 TC-17; KG-04 "Có PB6/PB7
và BME280"; KG-07 TC-16; KG-05 S09…S17; KG-06 "TC-13 nhánh"; KG-08 "Request xuất hiện trong queue".
"""
from __future__ import annotations

import hashlib
import json
import secrets

import pytest

from eide_core import store
from eide_core.errors import EideError
from eide_core.kg import to_tien
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

CHIP = "chip:st.stm32f411ce"
I2C1 = f"{CHIP}/periph:I2C1"


def _rt(tmp_path, workspace, ten="dự án đo nhiệt độ"):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": ten}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    gate = PolicyGate()
    ctx = Context(project_dir=root, extra={"gate": gate, "ledger": r.ledger})
    return r, ctx, root


def _fact(c, subject, predicate, value, *, source="src_a", tier="silver", conf=0.9,
          status="normalized", method="parser", fid=None):
    fid = fid or "f_" + secrets.token_hex(8)
    c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
              " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
              (fid, subject, predicate, json.dumps(value, ensure_ascii=False), source,
               method, tier, conf, status, "A"))
    return fid


def _nguon(c, sid="src_a", domain="st.com"):
    # `source.sha256` là UNIQUE (DDD-14 §2 Source): hai nguồn khác nhau không thể cùng băm, vì
    # băm CHÍNH LÀ định danh nội dung — hai tệp cùng băm là một tệp. Fixture phải tôn trọng điều
    # ấy, không thì nó dựng một trạng thái store không bao giờ xảy ra thật.
    c.execute("INSERT INTO source (id, uri, sha256, kind, tier, license, domain) "
              "VALUES (?,?,?,?,?,?,?)",
              (sid, f"https://{domain}/d.pdf", hashlib.sha256(sid.encode()).hexdigest(),
               "pdf_vendor", "gold", "vendor-doc", domain))


@pytest.fixture
def du_an(tmp_path, workspace):
    """Một store nhỏ nhưng đủ hình dạng: chip → periph → reg, hai nguồn, một code_unit."""
    r, ctx, root = _rt(tmp_path, workspace)
    with store.open_store(store.store_path(root)) as c:
        _nguon(c, "src_a", "st.com")
        _nguon(c, "src_b", "bosch-sensortec.com")
        f_pin = _fact(c, I2C1, "pin_function", "PB6/PB7", fid="f_pin")
        _fact(c, f"{I2C1}/reg:CR1", "offset", 0, fid="f_off")
        _fact(c, "part:bosch.bme280", "address", "0x76", source="src_b", fid="f_bme")
        c.execute("INSERT INTO code_unit (id, path, hash, cites, uses) VALUES (?,?,?,?,?)",
                  ("cu_1", "src/i2c.c", "h1", json.dumps([f_pin]), json.dumps([I2C1])))
        c.commit()
    # Ghi thẳng vào store là ghi NGOÀI CỔNG, và `project.open` bước 2 bắt đúng điều đó bằng
    # E6000 (DEV-007). Fixture đóng niêm lại để dựng một dự án hợp lệ — chứ không phải để tránh
    # phép kiểm: `tests/test_store.py` mới là nơi kiểm chính nhánh E6000 ấy.
    store.write_seal(store.store_path(root), r.ledger)
    return r, ctx, root


# ---------- KG-01 kg.build


def test_build_dem_dung_nut_va_canh(du_an):
    r, ctx, _ = du_an
    out = r.invoke("kg.build", {}, ctx).result
    assert out["nodes"] > 0 and out["edges"] > 0
    assert out["cached"] is False, "lần đầu phải dựng, không lấy từ cache"


def test_doi_store_thi_dung_lai_khong_doi_thi_dung_cache(du_an):
    """tc KG-01: "Đổi store → rebuild".

    Cache theo băm NỘI DUNG LOGIC chứ không theo băm byte: SQLite ở chế độ WAL đổi byte tệp sau
    mỗi lần mở, nên cache theo byte sẽ dựng lại đồ thị mỗi lần — tức không phải cache.
    """
    r, ctx, root = du_an
    a = r.invoke("kg.build", {}, ctx).result
    assert r.invoke("kg.build", {}, ctx).result["cached"] is True, "store không đổi mà vẫn dựng lại"

    with store.open_store(store.store_path(root)) as c:
        _fact(c, f"{CHIP}/periph:SPI1", "irq", 35)
        c.commit()
    b = r.invoke("kg.build", {}, ctx).result
    assert b["cached"] is False, "store đã đổi mà vẫn lấy cache"
    assert b["nodes"] > a["nodes"]


def test_force_bo_qua_cache(du_an):
    r, ctx, _ = du_an
    r.invoke("kg.build", {}, ctx)
    assert r.invoke("kg.build", {"force": True}, ctx).result["cached"] is False


# ---------- KG-04 kg.neighborhood


def test_lan_can_cua_periph_toi_duoc_fact_ve_no(du_an):
    """tc KG-04: "Có PB6/PB7 và BME280".

    Đây là phép thử cho cạnh `ABOUT` mà KAD-07 §6.3 không có (DEV-038): thiếu nó thì fact chỉ
    nối tới Source và CodeUnit, còn câu hỏi "biết gì về I2C1" không trả lời được bằng duyệt đồ
    thị — tức KG-04 mất đúng việc của nó.
    """
    r, ctx, _ = du_an
    sg = r.invoke("kg.neighborhood", {"node": I2C1}, ctx).result["subgraph"]
    ids = {n["id"] for n in sg["nodes"]}
    assert "f_pin" in ids, "không tới được fact nói về I2C1"
    assert CHIP in ids, "không tới được chip cha qua cạnh HAS"
    assert f"{I2C1}/reg:CR1" in ids, "không tới được thanh ghi con"
    assert any(e["kind"] == "ABOUT" for e in sg["edges"])


def test_lan_can_khong_qua_hai_buoc(du_an):
    r, ctx, _ = du_an
    sg = r.invoke("kg.neighborhood", {"node": I2C1, "depth": 1}, ctx).result["subgraph"]
    assert max(n["buoc"] for n in sg["nodes"]) == 1
    assert all(n["buoc"] <= 2 for n in
               r.invoke("kg.neighborhood", {"node": I2C1}, ctx).result["subgraph"]["nodes"])


def test_depth_ngoai_khoang_la_E1000(du_an):
    """KG-04 ghi "BFS ≤ 2 bước". Nhận depth=5 rồi âm thầm cắt về 2 là nói dối bên gọi."""
    r, ctx, _ = du_an
    run = r.invoke("kg.neighborhood", {"node": I2C1, "depth": 5}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_nut_khong_ton_tai_tra_rong_chu_khong_no(du_an):
    r, ctx, _ = du_an
    sg = r.invoke("kg.neighborhood", {"node": "chip:khong-co"}, ctx).result["subgraph"]
    assert sg["nodes"] == [] and sg["edges"] == []


# ---------- KG-02 kg.conflicts


def test_hai_fact_khac_gia_tri_la_mau_thuan(du_an):
    """tc KG-02: TC-13. Cùng subject + predicate, khác giá trị ⇒ CONFLICTS_WITH (KAD §6.3)."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, I2C1, "pin_function", "PB8/PB9", source="src_b", fid="f_pin2")
        c.commit()
    out = r.invoke("kg.conflicts", {}, ctx).result
    cap = [set(x["nodes"]) for x in out["conflicts"] if x["type"] == "fact"]
    assert {"f_pin", "f_pin2"} in cap
    d = next(x["detail"] for x in out["conflicts"] if set(x["nodes"]) == {"f_pin", "f_pin2"})
    assert "PB6/PB7" in d and "PB8/PB9" in d, "chi tiết phải nêu HAI giá trị để người quyết được"


def test_cung_gia_tri_khac_thu_tu_khoa_khong_phai_mau_thuan(du_an):
    """`{"a":1,"b":2}` và `{"b":2,"a":1}` là cùng một giá trị.

    Báo chúng mâu thuẫn là báo động giả ngay ở lần trích xuất thứ hai của cùng một tài liệu —
    và cảnh báo giả lặp lại là cách nhanh nhất khiến người ta thôi đọc cảnh báo thật.
    """
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, "part:x", "timing", {"a": 1, "b": 2}, fid="f_t1")
        _fact(c, "part:x", "timing", {"b": 2, "a": 1}, source="src_b", fid="f_t2")
        c.commit()
    cap = [set(x["nodes"]) for x in r.invoke("kg.conflicts", {}, ctx).result["conflicts"]]
    assert {"f_t1", "f_t2"} not in cap


def test_fact_da_bi_thay_khong_gay_mau_thuan_gia(du_an):
    """Fact `superseded` ở lại store để truy nguyên, nhưng không được vào đồ thị: nếu vào thì
    mỗi lần thay một fact sẽ sinh ngay một "mâu thuẫn" giữa nó và bản cũ của chính nó."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, I2C1, "pin_function", "PB8/PB9", status="superseded", fid="f_cu")
        c.commit()
    cap = [set(x["nodes"]) for x in r.invoke("kg.conflicts", {}, ctx).result["conflicts"]]
    assert {"f_pin", "f_cu"} not in cap


def test_xung_dot_tai_nguyen_noi_ro_la_chua_kiem_duoc(du_an):
    """`hw_map` là bảng mốc M2. Trả mảng rỗng mà không nói gì thì bên gọi đọc thành "đã kiểm và
    sạch" — hai điều rất khác nhau."""
    r, ctx, _ = du_an
    assert r.invoke("kg.conflicts", {}, ctx).result["resource_ready"] is False


# ---------- KG-03 kg.impact


def test_impact_lan_nguoc_toi_code_unit(du_an):
    """tc KG-03: TC-17. CodeUnit `cites` fact ⇒ fact đổi thì CodeUnit stale."""
    r, ctx, _ = du_an
    out = r.invoke("kg.impact", {"fact_id": "f_pin"}, ctx).result
    assert out["stale_code_units"] == ["cu_1"]
    assert r.invoke("kg.impact", {"fact_id": "f_bme"}, ctx).result["stale_code_units"] == []


def test_impact_fact_khong_co_la_E2000(du_an):
    """Router BẮT lỗi ném từ handler và trả `status=failed` kèm `error.eide_code`; chỉ lỗi
    kiểm schema ĐẦU VÀO mới ném thẳng ra ngoài (API-15 §3). Test phải soi đúng đường ấy."""
    r, ctx, _ = du_an
    run = r.invoke("kg.impact", {"fact_id": "f_khong-co"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- KG-07 kg.supersede


def test_supersede_giu_lai_fact_cu_va_noi_hai_ban(du_an):
    """tc KG-07: TC-16. KAD-07 §4.1: fact là bản ghi BẤT BIẾN — thay chứ không xóa."""
    r, ctx, root = du_an
    out = r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                                    "reason": "errata rev B", "actor": "Vũ Trí Công"}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        cu = c.execute("SELECT status FROM fact WHERE id='f_pin'").fetchone()[0]
        moi = c.execute("SELECT status, supersedes, subject, predicate, value FROM fact WHERE id=?",
                        (out["new_id"],)).fetchone()
    assert cu == "superseded", "fact cũ phải ở lại store, chỉ đổi trạng thái"
    assert moi[1] == "f_pin", "fact mới phải trỏ về fact cũ — đường truy nguyên duy nhất"
    assert (moi[2], moi[3]) == (I2C1, "pin_function"), "subject/predicate kế thừa khi không nêu"
    assert json.loads(moi[4]) == "PB8/PB9"


def test_supersede_danh_dau_code_unit_thanh_stale(du_an):
    """Bước 2 của hợp đồng là `kg.impact`, và mục đích là ĐÁNH DẤU: `code_unit.stale` được
    DDD-14 §2 chú thích đúng hai chữ "Fact đổi".

    Chạy phép tính impact rồi trả nó ra ngoài mà không ghi vào store thì cột `stale` không ai
    đặt bao giờ, và `project.status` sẽ mãi báo không có mã nào cần xem lại.
    """
    r, ctx, root = du_an
    r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "PB8/PB9"},
                              "reason": "x", "actor": "người"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT stale FROM code_unit WHERE id='cu_1'").fetchone()[0] == 1
        assert c.execute("SELECT stale FROM code_unit WHERE id='cu_1'").fetchone()[0] == 1


def test_supersede_ghi_ledger_co_hash(du_an):
    """API-15 §7 v1.4: `store.write` mang trường `hash` nối với niêm phong (DEV-007)."""
    r, ctx, _ = du_an
    r.invoke("kg.supersede", {"old": "f_pin", "new": {"value": "X"}, "reason": "x",
                              "actor": "người"}, ctx)
    w = [x for x in ctx.extra["ledger"].records() if x["kind"] == "store.write"]
    assert w and w[-1]["data"]["hash"], "thiếu hash thì niêm phong không nối được với nhật ký"


def test_supersede_fact_khong_co_la_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("kg.supersede", {"old": "f_x", "new": {"value": 1}, "reason": "x",
                                    "actor": "người"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- KG-05 kg.review_facts


def test_review_theo_chinh_sach_duyet_fact_vang(du_an):
    """S09…S17: `decision=policy` chạy PolicyGate cho từng fact và làm đúng ba nhánh."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, "part:y", "package", "LQFP48", tier="gold", conf=1.0, fid="f_vang")
        c.commit()
    out = r.invoke("kg.review_facts", {"group": "normalized", "decision": "policy",
                                       "actor": "agent"}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        st = c.execute("SELECT status, confirmed_by FROM fact WHERE id='f_vang'").fetchone()
    assert st == ("reviewed", "policy")
    assert out["reviewed"] >= 1


def test_review_tang_dong_bi_tu_choi(du_an):
    """G-FACT-05: "Tầng đồng không vào fact (KAD E8)" — REJECT, không phải ASK."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, "part:z", "note", "đoán", tier="bronze", conf=0.3, fid="f_dong")
        c.commit()
    r.invoke("kg.review_facts", {"group": "normalized", "decision": "policy", "actor": "agent"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT status FROM fact WHERE id='f_dong'").fetchone()[0] == "rejected"


def test_tac_tu_khong_duoc_tu_accept(du_an):
    """KG-05 ask: "confidence thấp; mâu thuẫn". `accept` là quyết định của người; một tác tử tự
    accept fact của chính nó thì cả cổng G-FACT thành trang trí."""
    r, ctx, _ = du_an
    run = r.invoke("kg.review_facts", {"group": "normalized", "decision": "accept",
                                       "actor": "agent"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E3000"


def test_review_theo_nhom_prefix_subject(du_an):
    """`group` là "batch_id | subject prefix | status" — ba loại, phân biệt bằng hình dạng."""
    r, ctx, root = du_an
    # `ctx.actor` là QUYỀN, `params["actor"]` là TÊN ghi vào store. `accept` cần quyền của người.
    ctx.actor = "human"
    out = r.invoke("kg.review_facts", {"group": CHIP, "decision": "accept",
                                       "actor": "Vũ Trí Công"}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT status FROM fact WHERE id='f_bme'").fetchone()[0] == "normalized"
    assert out["reviewed"] == 2, "chỉ hai fact thuộc tiền tố chip:st…, không phải part:bosch…"


# ---------- KG-06 kg.resolve_conflict


def test_giai_quyet_xung_dot_luon_can_nguoi(du_an):
    """KG-06 ask "Luôn", lỗi "E3000 nếu actor=policy".

    Một tác tử tự chọn giữa hai fact mâu thuẫn chính là cách một sai lệch tri thức trở thành sự
    thật trong store — và nó mang nhãn "đã duyệt" từ đó về sau.

    Chặn HAI tầng, và cả hai đều cần: PolicyGate dừng ở cửa vì năng lực khai mức T2 (tầng 5 của
    APD-08 §4.1 trả ASK cho tác tử, APPROVE cho người); còn phép kiểm trong handler bắt lời gọi
    trực tiếp không qua Router — `kg.supersede` gọi `impact()` như một hàm Python bình thường,
    nên đường ấy có thật.
    """
    r, ctx, _ = du_an
    run = r.invoke("kg.resolve_conflict", {"conflict_id": "f_pin:f_bme", "choice": "a",
                                           "actor": "policy"}, ctx)
    assert run.status == "pending", "tác tử phải bị dừng ở cổng"

    from eide.caps.kg import resolve_conflict
    with pytest.raises(EideError) as e:
        resolve_conflict({"conflict_id": "f_pin:f_bme", "choice": "a", "actor": "policy"}, ctx)
    assert e.value.code == "E3000"


def test_chon_mot_ben_thi_ben_kia_thanh_superseded(du_an):
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, I2C1, "pin_function", "PB8/PB9", source="src_b", fid="f_pin2")
        c.commit()
    ctx.actor = "human"
    out = r.invoke("kg.resolve_conflict", {"conflict_id": "f_pin:f_pin2", "choice": "a",
                                           "actor": "Vũ Trí Công"}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        st = dict(c.execute("SELECT id, status FROM fact WHERE id IN ('f_pin','f_pin2')").fetchall())
    assert out["current"] == "f_pin"
    assert st == {"f_pin": "verified", "f_pin2": "superseded"}


def test_both_conditional_giu_ca_hai_va_doi_dieu_kien(du_an):
    """KAD-07 §6.5: "both: giữ hai với điều kiện (errata rev)". Không có điều kiện thì "giữ cả
    hai" chỉ là hoãn quyết định, và mâu thuẫn ở lại nguyên vẹn."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, I2C1, "pin_function", "PB8/PB9", source="src_b", fid="f_pin2")
        c.commit()
    ctx.actor = "human"
    run = r.invoke("kg.resolve_conflict", {"conflict_id": "f_pin:f_pin2",
                                           "choice": "both_conditional", "actor": "người"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"

    r.invoke("kg.resolve_conflict", {"conflict_id": "f_pin:f_pin2", "choice": "both_conditional",
                                     "condition": "errata rev B", "actor": "người"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        st = dict(c.execute("SELECT id, status FROM fact WHERE id IN ('f_pin','f_pin2')").fetchall())
    assert st == {"f_pin": "verified", "f_pin2": "verified"}


# ---------- KG-08 kg.request


def test_request_vao_queue_o_trang_thai_REQUESTED(du_an):
    """tc KG-08: "Request xuất hiện trong queue". DDD-14 AcquisitionRequest.state."""
    r, ctx, root = du_an
    rid = r.invoke("kg.request", {"need": "datasheet BME280", "part": "bosch.bme280"},
                   ctx).result["request_id"]
    with store.open_store(store.store_path(root)) as c:
        row = c.execute("SELECT need, part, state FROM acq_request WHERE id=?", (rid,)).fetchone()
    assert row == ("datasheet BME280", "bosch.bme280", "REQUESTED")
    assert [x for x in ctx.extra["ledger"].records()
            if x["kind"] == "acq.state" and x["data"]["acq_id"] == rid]


# ---------- lõi đồ thị


def test_iri_cat_theo_gach_cheo_khong_cat_theo_hai_cham():
    """KAD-07 §6.1: `chip:st.stm32f411ce/periph:I2C1/reg:CR1`.

    Tên sau dấu hai chấm CÓ dấu chấm (`st.stm32f411ce`) nhưng không có `/`. Cắt nhầm theo `:`
    sẽ tách `chip` khỏi `st.stm32f411ce` và mọi cạnh HAS đều sai gốc.
    """
    assert to_tien("chip:st.stm32f411ce/periph:I2C1/reg:CR1") == [
        "chip:st.stm32f411ce", "chip:st.stm32f411ce/periph:I2C1",
        "chip:st.stm32f411ce/periph:I2C1/reg:CR1"]
    assert to_tien("part:bosch.bme280") == ["part:bosch.bme280"]


# ---------- PROJECT-02 bước 3 (DEV-008)


def test_mo_du_an_tai_dung_kg(du_an):
    """CDS-12.3 PROJECT-02 bước 3: "Tái dựng KG từ cache (hash khớp) hoặc từ store".

    Dựng lúc mở dự án chứ không để lần gọi `kg.*` đầu tiên tự dựng: mở dự án là lúc người dùng
    đang chờ sẵn, còn một câu hỏi giữa chừng thì không.
    """
    r, ctx, _ = du_an
    s = r.invoke("project.open", {"project": str(ctx.project_dir)}, ctx).result["summary"]
    assert s["kg"]["ok"] is True
    assert s["kg"]["nodes"] > 0 and s["kg"]["edges"] > 0


def test_kg_hong_khong_lam_hong_viec_mo_du_an(du_an, monkeypatch):
    """Đồ thị là khung nhìn DỰNG LẠI ĐƯỢC, không phải dữ liệu.

    Một store lạ làm nó dựng hỏng thì người dùng vẫn phải mở được dự án để đi sửa — nên báo
    `ok: false` kèm lý do, không ném lên và chặn cả lời gọi.
    """
    import eide.caps.kg as nkg

    r, ctx, _ = du_an
    monkeypatch.setattr(nkg, "_do_thi", lambda *a, **k: (_ for _ in ()).throw(RuntimeError("store lạ")))
    s = r.invoke("project.open", {"project": str(ctx.project_dir)}, ctx).result["summary"]
    assert s["kg"]["ok"] is False and "store lạ" in s["kg"]["reason"]
    assert s["project"], "phần còn lại của summary vẫn phải dùng được"
