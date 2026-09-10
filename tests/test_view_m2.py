"""Nhóm view.* mốc M2 — CDS-12.4; KAD-07 §6.9 (hiển thị và truy hồi).

Bốn năng lực: `coverage_map` (VIEW-05), `impact_map` (VIEW-06), `rag_compare` (VIEW-10),
`timeline` (VIEW-12).

Cả bốn là **tầng trình bày**: R0, `undo: none`, `errors: []` — không sinh fact, không sửa store.
Bất biến của cả nhóm, và là thứ đáng kiểm nhất: một khung nhìn ghi vào store là một khung nhìn
có thể làm hỏng thứ nó đang hiển thị.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

PART = "st.stm32f411ce"


@pytest.fixture
def du_an(tmp_path, workspace):
    """Hộ chiếu I2C1 (2 thanh ghi, 1 có fact reviewed) + SPI1 (không fact) + 1 yêu cầu thu nhận."""
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án khung nhìn"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    db = store.store_path(root)
    store.migrate(db, ledger=r.ledger)
    with store.open_store(db) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('src_1','stm32f411.svd','h1','svd','gold')")
        c.execute("INSERT INTO passport (id, kind, header, created_at)"
                  f" VALUES ('{PART}@1.0.0','chip','{{\"name\":\"{PART}\"}}','2026-09-10T00:00:00Z')")
        ds = [
            ("f_0001", f"chip:{PART}/periph:I2C1", "base_address", "1073765376", "reviewed"),
            ("f_0002", f"chip:{PART}/periph:I2C1/reg:CR1", "offset", "0", "reviewed"),
            ("f_0003", f"chip:{PART}/periph:I2C1/reg:CR2", "offset", "4", "normalized"),
            ("f_0004", f"chip:{PART}/periph:SPI1", "base_address", "1073819648", "normalized"),
            # Bản CŨ của một thanh ghi đã bị thay. Nó ở lại store để truy nguyên (KAD-07 §5.1),
            # nhưng đếm nó vào bản đồ phủ thì con số nói ta biết nhiều hơn thực tế — và
            # `registers_total` sẽ tăng mỗi lần trích lại cùng một datasheet.
            ("f_0005", f"chip:{PART}/periph:I2C1/reg:CR3", "offset", "8", "superseded"),
        ]
        for fid, subj, vt, gt, st in ds:
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                      " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                      (fid, subj, vt, gt, "src_1", "parser", "gold", 1.0, st, "C"))
            c.execute("INSERT INTO passport_fact (passport_id, fact_id) VALUES (?,?)",
                      (f"{PART}@1.0.0", fid))
        c.execute("INSERT INTO acq_request (id, need, part, peripheral, state, created_at)"
                  " VALUES ('acq_1','bảng thanh ghi SPI1',?, 'SPI1','REQUESTED','2026-09-10')",
                  (PART,))
        c.commit()
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _khong_ghi_store(root: Path):
    """Băm nội dung logic của store — tầng trình bày không được đổi nó."""
    with store.open_store(store.store_path(root)) as c:
        return store.content_digest(c)


# ================================================================ VIEW-05 coverage_map


def test_heatmap_so_khop_store(du_an):
    """tc VIEW-05 nguyên văn: "TC-78 số khớp store". Bản đồ phủ nói *đã biết bao nhiêu về con
    chip này* — nó chỉ có giá trị khi từng con số đếm được lại từ store."""
    r, ctx, root = du_an
    out = r.invoke("view.coverage_map", {"passport": f"{PART}@1.0.0"}, ctx).result

    h = out["heatmap"]
    # CR3 có fact nhưng đã `superseded` — không được tính vào bất kỳ cột nào.
    assert h["I2C1"] == {"registers_total": 2, "with_facts": 2, "reviewed": 1, "requested": 0}
    assert h["SPI1"] == {"registers_total": 0, "with_facts": 0, "reviewed": 0, "requested": 1}


def test_coverage_khong_ghi_store(du_an):
    """R0 + `undo: none`: một khung nhìn ghi vào store là một khung nhìn có thể làm hỏng thứ nó
    đang hiển thị."""
    r, ctx, root = du_an
    truoc = _khong_ghi_store(root)
    r.invoke("view.coverage_map", {"passport": f"{PART}@1.0.0"}, ctx)
    assert _khong_ghi_store(root) == truoc


def test_ho_chieu_khong_co_thi_heatmap_rong(du_an):
    """`errors: []` — hộ chiếu chưa nạp không phải lỗi, nó là "chưa biết gì". Ném lỗi ở đây thì
    màn hình Hộ chiếu chip không mở được cho một dự án mới tinh."""
    r, ctx, root = du_an
    out = r.invoke("view.coverage_map", {"passport": "khong.co@1.0.0"}, ctx).result
    assert out["heatmap"] == {}


# ================================================================ VIEW-06 impact_map


def test_impact_map_khop_kg_impact(du_an):
    """tc VIEW-06 nguyên văn: "Khớp kg.impact". Khung nhìn không được TÍNH LẠI ảnh hưởng theo
    cách riêng — hai câu trả lời khác nhau cho cùng một câu hỏi là thứ tệ hơn không có câu nào."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO code_unit (id, path, symbol, hash, cites, uses)"
                  " VALUES ('cu_1','src/i2c.c','i2c_init','h','[\"f_0002\"]','[]')")
        c.commit()

    goc = r.invoke("kg.impact", {"fact_id": "f_0002"}, ctx).result
    out = r.invoke("view.impact_map", {"delta": {"fact_id": "f_0002"}}, ctx).result

    g = out["graph"]
    assert {n["id"] for n in g["nodes"] if n.get("stale")} == set(goc["stale_code_units"])
    assert "cu_1" in {n["id"] for n in g["nodes"]}


def test_stale_duoc_to_mau(du_an):
    """Bước 1: "đồ thị con tô màu stale". Màu là toàn bộ nội dung của khung nhìn này: một đồ thị
    không phân biệt được cái gì đã cũ thì chỉ là một đồ thị."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO code_unit (id, path, symbol, hash, cites, uses)"
                  " VALUES ('cu_1','src/i2c.c','i2c_init','h','[\"f_0002\"]','[]')")
        c.commit()
    out = r.invoke("view.impact_map", {"delta": {"fact_id": "f_0002"}}, ctx).result
    cu = next(n for n in out["graph"]["nodes"] if n["id"] == "cu_1")
    assert cu["stale"] is True and cu["color"]


def test_delta_theo_req_di_qua_change_impact(du_an, monkeypatch):
    """`delta` có hai dạng (`fact_id` hoặc `req_id/old/new` — REQ-08). Dạng yêu cầu phải đi qua
    `req.change_impact`, không tự dựng lại."""
    r, ctx, root = du_an
    da_goi = []
    import eide.caps.req as m
    monkeypatch.setattr(m, "change_impact",
                        lambda p, c: (da_goi.append(p["delta"]),
                                      {"impact": {"modules": ["m1"], "code_units": ["cu_9"],
                                                  "tests": [], "docs": [], "diagrams": [],
                                                  "features": []}})[1])
    out = r.invoke("view.impact_map", {"delta": {"req_id": "R-01", "old": "a", "new": "b"}},
                   ctx).result
    assert da_goi and da_goi[0]["req_id"] == "R-01"
    assert "cu_9" in {n["id"] for n in out["graph"]["nodes"]}


# ================================================================ VIEW-10 rag_compare


def _gia_lap_rag(monkeypatch, theo_nhom):
    """`rag_ask` giả lập theo `scope`: mỗi nhóm nguồn một câu trả lời khác nhau."""
    import eide.caps.view as v

    def _ask(params, ctx):
        nhom = (params.get("scope") or ["?"])[0]
        return theo_nhom.get(nhom, {"answer": "", "citations": [], "not_found": True,
                                    "trace_id": "tr_x"})
    monkeypatch.setattr(v, "rag_ask", _ask)


def _gia_lap_writer(monkeypatch, data):
    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def run(self, *a, **k): return _R(data)
    import eide.caps.view as v
    monkeypatch.setattr(v, "_gateway", lambda ctx: _G())


def test_chi_ra_errata_khac_datasheet(du_an, monkeypatch):
    """tc VIEW-10 nguyên văn: "Chỉ ra errata khác datasheet".

    Đây là lý do năng lực này tồn tại: hỏi "tần số I2C tối đa" mà chỉ đọc datasheet thì được
    400 kHz, còn errata nói bản rev A không chạy quá 100 kHz. Một câu trả lời gộp sẽ chọn một
    trong hai và giấu cái kia.
    """
    r, ctx, root = du_an
    _gia_lap_rag(monkeypatch, {
        "datasheet": {"answer": "I2C1 chạy tới 400 kHz [1].", "not_found": False,
                      "citations": [{"n": 1, "source_id": "src_1"}], "trace_id": "tr_1"},
        "errata": {"answer": "Rev A giới hạn 100 kHz [1].", "not_found": False,
                   "citations": [{"n": 1, "source_id": "src_2"}], "trace_id": "tr_2"},
    })
    _gia_lap_writer(monkeypatch, {"differences": [
        "Errata giới hạn 100 kHz cho rev A, thấp hơn 400 kHz của datasheet [errata]"]})

    out = r.invoke("view.rag_compare", {"question": "I2C1 chạy tối đa bao nhiêu?"}, ctx).result
    nhom = {c["group"]: c for c in out["comparison"]}
    assert "400 kHz" in nhom["datasheet"]["answer"]
    assert "100 kHz" in nhom["errata"]["answer"]
    # `differences` nằm TRONG từng mục, không ở mức trên: `output_schema` của VIEW-10 khai đúng
    # một khoá `comparison` với `additionalProperties: false`.
    assert any("100 kHz" in d for c in out["comparison"] for d in c["differences"])


def test_nhom_khong_co_tai_lieu_thi_bo_khoi_bang(du_an, monkeypatch):
    """Một nhóm nguồn không có tài liệu nào không phải là một ý kiến — nó là im lặng. Đưa nó vào
    bảng so sánh với ô trống thì người đọc tưởng "cộng đồng không đồng ý"."""
    r, ctx, root = du_an
    _gia_lap_rag(monkeypatch, {
        "datasheet": {"answer": "400 kHz [1].", "not_found": False,
                      "citations": [{"n": 1, "source_id": "src_1"}], "trace_id": "tr_1"}})
    _gia_lap_writer(monkeypatch, {"differences": []})
    out = r.invoke("view.rag_compare", {"question": "x"}, ctx).result
    assert [c["group"] for c in out["comparison"]] == ["datasheet"]


def test_mot_nhom_thi_khong_co_khac_biet(du_an, monkeypatch):
    """Không gọi mô hình khi chỉ có một câu trả lời: hỏi nó "nêu khác biệt" giữa một thứ với
    chính nó là mời nó bịa ra một khác biệt."""
    r, ctx, root = du_an
    _gia_lap_rag(monkeypatch, {
        "datasheet": {"answer": "400 kHz [1].", "not_found": False,
                      "citations": [{"n": 1, "source_id": "src_1"}], "trace_id": "tr_1"}})
    import eide.caps.view as v

    def _no(ctx):
        raise AssertionError("một nhóm thì KHÔNG được hỏi mô hình về khác biệt")
    monkeypatch.setattr(v, "_gateway", _no)
    out = r.invoke("view.rag_compare", {"question": "x"}, ctx).result
    assert all(c["differences"] == [] for c in out["comparison"])


# ================================================================ VIEW-12 timeline


def test_su_kien_khop_ledger(du_an):
    """tc VIEW-12 nguyên văn: "Sự kiện khớp ledger"."""
    r, ctx, root = du_an
    r.ledger.append("gate.human", {"gate_id": "G-FACT", "decision": "approve", "by": "human"})
    out = r.invoke("view.timeline", {}, ctx).result

    kinds = [e["kind"] for e in out["events"]]
    assert "gate.human" in kinds
    assert len(out["events"]) >= len(r.ledger.records())


def test_sap_theo_thoi_gian(du_an):
    r, ctx, root = du_an
    for i in range(3):
        r.ledger.append("report", {"kind": "x", "i": i})
    ts = [e["at"] for e in r.invoke("view.timeline", {}, ctx).result["events"]]
    assert ts == sorted(ts)


def test_loc_theo_nguoi_hay_chinh_sach(du_an):
    """`filter: {by: policy|human, kinds}` của hợp đồng. Câu hỏi thật mà bộ lọc này trả lời là
    "việc gì đã tự chạy, việc gì tôi đã duyệt" — và đó là câu hỏi đầu tiên người ta hỏi khi một
    thứ trong dự án khác với trí nhớ của họ."""
    r, ctx, root = du_an
    r.ledger.append("gate.human", {"gate_id": "G1", "decision": "approve", "by": "human"})
    r.ledger.append("report", {"kind": "tu-dong"}, actor="agent")

    nguoi = r.invoke("view.timeline", {"filter": {"by": "human"}}, ctx).result["events"]
    assert nguoi and all(e["by"] == "human" for e in nguoi)

    theo_kind = r.invoke("view.timeline", {"filter": {"kinds": ["gate.human"]}},
                         ctx).result["events"]
    assert theo_kind and all(e["kind"] == "gate.human" for e in theo_kind)


def test_gom_ca_decision_log_va_store_write(du_an):
    """Bước 1: "Từ ledger/decision_log/capability_run/store.write". Bốn nguồn, vì mỗi nguồn giữ
    một mảnh khác nhau: ledger có chuỗi băm, `decision_log` có câu trả lời của người, còn
    `capability_run` có kết cục của từng lời gọi."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO decision_log (id, gate, action_cap, risk, autonomy_level,"
                  " decision, by, rule, at) VALUES"
                  " ('d1','G-FACT','passport.import','R1','A2','ASK','human','G-FACT-99',"
                  " '2026-09-10T01:00:00Z')")
        c.execute("INSERT INTO capability_run (id, cap, actor, args_hash, status, started_at)"
                  " VALUES ('cr_1','extract.svd','agent','h','done','2026-09-10T02:00:00Z')")
        c.commit()
    ds = r.invoke("view.timeline", {}, ctx).result["events"]
    nguon = {e["source"] for e in ds}
    assert {"ledger", "decision_log", "capability_run"} <= nguon


def test_loc_theo_khoang_thoi_gian(du_an):
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO capability_run (id, cap, actor, args_hash, status, started_at)"
                  " VALUES ('cr_cu','extract.svd','agent','h','done','2020-01-01T00:00:00Z')")
        c.commit()
    ds = r.invoke("view.timeline", {"range": {"from": "2026-01-01T00:00:00Z"}},
                  ctx).result["events"]
    assert all(e["at"] >= "2026-01-01T00:00:00Z" for e in ds)
    assert "cr_cu" not in {e.get("id") for e in ds}


def test_timeline_khong_ghi_store(du_an):
    r, ctx, root = du_an
    truoc = _khong_ghi_store(root)
    r.invoke("view.timeline", {}, ctx)
    assert _khong_ghi_store(root) == truoc
