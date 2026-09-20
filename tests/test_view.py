"""Nhóm view.* mốc M1 — CDS-12.4; UXD-13; KAD-07 §6; CXD-10 §4.5.

tc: TC-78 "< 3 s"; "Có đường tới SVD và bme280.c"; "Nhấp → mở đúng trang"; "Duyệt trên bảng cập
nhật store"; TC-79 "≥ 90%, 100% citations"; "Hiển thị đủ 3 điểm"; TC-DD-05 "tái dựng"; "Vùng bôi
sáng đúng bbox"; "Mermaid render được".

Nhóm trình bày rất dễ có test trông xanh mà không kiểm gì — gọi hàm, thấy không ném lỗi, xong.
Nên phần lớn test ở đây kiểm những **bất biến có thể sai một cách im lặng**: màu phụ thuộc thứ
tự dòng, đồ thị bị cắt mà không ai biết, câu trả lời không trích dẫn, chỉ mục lập lại từ đầu
mỗi lần.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.view import NGUONG_DIEM, TRAN_MERMAID, _moi_cau_co_trich_dan
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án xem"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _gia_lap(monkeypatch, data):
    class _R:
        def __init__(self, d): self.data = d
    class _G:
        def run(self, *a, **k): return _R(data)
    import eide.caps.view as m
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())


CHIP = "chip:st.stm32f411"


def nap(root, facts, sources=(("s_svd", "a.svd", "svd", "gold"),)):
    """Nạp fact thẳng vào store. `facts` = [(id, subject, predicate, value, tier, status)]."""
    with store.open_store(store.store_path(root)) as c:
        for sid, uri, kind, tier in sources:
            c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier) "
                      "VALUES (?,?,?,?,?)", (sid, uri, "h_" + sid, kind, tier))
        for fid, subj, vt, gt, tier, st in facts:
            c.execute(
                "INSERT OR REPLACE INTO fact (id, subject, predicate, value, source_id, method,"
                " tier, confidence, status, locator) VALUES (?,?,?,?,?,'parser',?,1.0,?,?)",
                (fid, subj, vt, json.dumps(gt), sources[0][0], tier, st,
                 json.dumps({"page": 47, "bbox": [10, 20, 30, 40]})))
        c.commit()


# ---------- VIEW-01 kg_map


def test_mau_theo_tier_va_status(du_an):
    """"tô màu theo tier (vàng/bạc/đồng), status (conflict đỏ, superseded xám)"."""
    from eide.caps.view import MAU_STATUS, MAU_TIER
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 0x40005400, "gold", "normalized"),
               ("f_2", f"{CHIP}/periph:SPI1", "base_address", 0x40013000, "silver", "conflict")])
    g = r.invoke("view.kg_map", {}, ctx).result["graph"]
    theo = {n["id"]: n for n in g["nodes"]}
    assert theo["f_1"]["color"] == MAU_TIER["gold"]
    assert theo["f_2"]["color"] == MAU_STATUS["conflict"], "status phải thắng tier"


def test_nhan_nut_fact_doc_duoc_chu_khong_phai_ma_bam(du_an):
    """Id của fact không phải IRI, nên nhãn "đoạn cuối của IRI" trả về nguyên mã băm.

    Đo 20/09/2026 trên màn Bản đồ tri thức (S7) với một store nhỏ: sáu trong mười một nút hiện
    ra là sáu chuỗi hex, và cả màn ấy tồn tại để trả lời "máy biết những gì". Một nhãn không ai
    đọc được thì đồ thị chỉ còn là hình trang trí.

    Nút CHỦ THỂ giữ nguyên nhãn IRI của nó: gán nhãn của một fact cho chủ thể sẽ làm
    `periph:I2C1` hiện ra là tên của một trong nhiều fact của nó, chọn theo thứ tự dòng SQL.
    """
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 0x40005400, "gold", "normalized")])
    theo = {n["id"]: n for n in r.invoke("view.kg_map", {}, ctx).result["graph"]["nodes"]}
    assert theo["f_1"]["label"] == "periph:I2C1·base_address"
    assert theo[f"{CHIP}/periph:I2C1"]["label"] == "periph:I2C1"


def test_mau_khong_phu_thuoc_thu_tu_dong(du_an):
    """Một IRI có MỘT fact mâu thuẫn thì nút ấy phải đỏ, dù chín fact còn lại bình thường.

    Lấy fact cuối cùng đọc được sẽ cho màu phụ thuộc thứ tự dòng SQL — tức ngẫu nhiên, và một
    lỗi ngẫu nhiên trong màu là lỗi không ai tái hiện được để báo.
    """
    from eide.caps.view import MAU_STATUS
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "conflict"),
               ("f_2", f"{CHIP}/periph:I2C1", "irq", 31, "gold", "normalized"),
               ("f_3", f"{CHIP}/periph:I2C1", "clock", 1, "gold", "normalized")])
    g = r.invoke("view.kg_map", {}, ctx).result["graph"]
    nut = next(n for n in g["nodes"] if n["id"] == f"{CHIP}/periph:I2C1")
    assert nut["color"] == MAU_STATUS["conflict"]


def test_giu_ca_tier_va_status_nguyen_van(du_an):
    """Trả mã màu mà bỏ trạng thái thì giao diện phải suy ngược từ màu — và bản mù màu, bản in
    đen trắng, bản xuất `graphml` đều mất thông tin."""
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "silver", "conflict")])
    n = next(x for x in r.invoke("view.kg_map", {}, ctx).result["graph"]["nodes"]
             if x["id"] == "f_1")
    assert (n["tier"], n["status"]) == ("silver", "conflict")


def test_loc_theo_tier(du_an):
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:A", "base_address", 1, "gold", "normalized"),
               ("f_2", f"{CHIP}/periph:B", "base_address", 2, "bronze", "normalized")])
    g = r.invoke("view.kg_map", {"filter": {"tier": ["gold"]}}, ctx).result["graph"]
    assert "f_2" not in {n["id"] for n in g["nodes"]}
    assert "f_1" in {n["id"] for n in g["nodes"]}


def test_do_thi_nho_thi_khong_gom_cum(du_an):
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:A", "base_address", 1, "gold", "normalized")])
    assert r.invoke("view.kg_map", {}, ctx).result["graph"]["clustered"] is False


def test_gom_cum_chu_khong_cat_bot(du_an, monkeypatch):
    """Cắt thì người xem thấy một đồ thị TRÔNG đầy đủ nhưng thiếu, và không có gì báo cho họ
    biết. Gom thì mỗi cụm ghi rõ `n` — họ thấy ngay "I2C1 (312 nút)"."""
    import eide.caps.view as m
    monkeypatch.setattr(m, "NGUONG_GOM", 3)
    r, ctx, root = du_an
    nap(root, [(f"f_{i}", f"{CHIP}/periph:I2C1/reg:R{i}", "offset", i, "gold", "normalized")
               for i in range(6)])
    g = r.invoke("view.kg_map", {}, ctx).result["graph"]
    assert g["clustered"] is True
    cum = [n for n in g["nodes"] if n.get("cluster")]
    assert cum, g["nodes"]
    assert sum(n.get("n", 1) for n in g["nodes"]) >= 6, "tổng số nút phải được giữ, không cắt"


def test_vuot_tran_50000_thi_bao_E5000(du_an, monkeypatch):
    import eide.caps.view as m
    monkeypatch.setattr(m, "TRAN_NUT", 2)
    r, ctx, root = du_an
    nap(root, [(f"f_{i}", f"{CHIP}/periph:P{i}", "base_address", i, "gold", "normalized")
               for i in range(5)])
    run = r.invoke("view.kg_map", {}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5000"


# ---------- VIEW-02 kg_focus


def test_duong_toi_nguon_va_toi_ma(du_an):
    """tc: "Có đường tới SVD và bme280.c". `paths_to_sources` mới là phần đáng giá — nó trả lời
    câu người dùng thật sự hỏi khi nhấp: "cái này ở đâu ra, và chỗ nào trong mã đang dùng nó?"
    """
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO code_unit (id, path, hash, cites) VALUES "
                  "('cu_1','src/bme280.c','h', ?)", (json.dumps(["f_1"]),))
        c.commit()
    out = r.invoke("view.kg_focus", {"node": f"{CHIP}/periph:I2C1"}, ctx).result
    duong = [" → ".join(d) for d in out["paths_to_sources"]]
    assert any("a.svd" in d for d in duong), duong
    assert any("bme280.c" in d for d in duong), duong


# ---------- VIEW-03 provenance


def test_chuoi_supersede_day_du(du_an):
    """Một fact đã bị thay thế vẫn là một phần của câu trả lời "vì sao ta tin con số này": nó
    cho biết trước đây ta tin gì và dựa vào nguồn nào — thứ người ta cần khi con số MỚI cũng
    sai."""
    r, ctx, root = du_an
    nap(root, [("f_cu", f"{CHIP}/periph:I2C1", "base_address", 1, "silver", "superseded"),
               ("f_moi", f"{CHIP}/periph:I2C1", "base_address", 2, "gold", "normalized")])
    with store.open_store(store.store_path(root)) as c:
        c.execute("UPDATE fact SET supersedes='f_cu' WHERE id='f_moi'")
        c.commit()
    chain = r.invoke("view.provenance", {"fact_id": "f_moi"}, ctx).result["chain"]
    assert [x["fact_id"] for x in chain] == ["f_moi", "f_cu"]
    assert chain[0]["source"]["uri"] == "a.svd"
    assert chain[0]["locator"] == {"page": 47, "bbox": [10, 20, 30, 40]}


def test_fact_la_bao_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("view.provenance", {"fact_id": "f_khong_co"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- VIEW-04 conflict_board


def test_bang_mau_thuan_co_hai_ve_va_hanh_dong(du_an):
    """`actions` khai tên NĂNG LỰC, không phải nhãn nút: giao diện tự nghĩ ra hành động là giao
    diện sẽ lệch khỏi những gì chính sách cho phép."""
    r, ctx, root = du_an
    nap(root, [("f_a", f"{CHIP}/periph:I2C1", "base_address", 0x1000, "gold", "normalized"),
               ("f_b", f"{CHIP}/periph:I2C1", "base_address", 0x2000, "gold", "conflict")])
    rows = r.invoke("view.conflict_board", {}, ctx).result["rows"]
    assert rows, "hai fact cùng subject+predicate khác giá trị phải thành một hàng"
    h = rows[0]
    assert h["a"]["value"] != h["b"]["value"]
    assert h["sources"] == ["a.svd", "a.svd"]
    assert "kg.review_facts" in h["actions"]


# ---------- VIEW-05 rag_ask


def _nap_rag(root, doan):
    from eide_core.rag import Doan, RagIndex
    idx = RagIndex(root)
    idx.them([Doan(id=f"rc_{i}", source_id="s_svd", text=t,
                   locator={"page": 47}, graph_nodes=nodes)
              for i, (t, nodes) in enumerate(doan)])
    return idx


def test_khong_du_diem_thi_not_found_chu_khong_bia(du_an, monkeypatch):
    """Đây là chỗ DUY NHẤT trong cả sản phẩm mà trả về rỗng là kết quả ĐÚNG chứ không phải thất
    bại. Thà nói không biết."""
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    _nap_rag(root, [("Thanh ghi CR1 nằm ở offset 0x00 của khối I2C1.", [])])
    _gia_lap(monkeypatch, {"answer": "Câu trả lời bịa ra [1]."})
    # Câu hỏi không chia từ khóa nào với đoạn duy nhất trong kho. Bản đầu tôi hỏi "… không có
    # trong tài liệu" — và đoạn mồi CÓ chữ "tài liệu", nên nó khớp thật: test sai vì câu hỏi
    # sai, không phải vì mã sai.
    out = r.invoke("view.rag_ask", {"question": "xyzzy plugh qwerty"}, ctx).result
    assert out["not_found"] is True
    assert out["answer"] == "" and out["citations"] == []


def test_khop_mot_phan_nhung_diem_thap_thi_van_not_found(du_an, monkeypatch):
    """ĐÂY mới là trường hợp ngưỡng 0,35 sinh ra để chặn, và là test tôi thiếu ở lượt đầu.

    Test `not_found` trên kia dùng câu hỏi KHÔNG khớp gì cả, nên `tim()` trả rỗng và ngưỡng
    không bao giờ được chạm tới — gỡ hẳn phép lọc đi mà bộ test vẫn xanh. Ở đây đoạn CÓ được
    truy hồi (một từ khóa trùng) nhưng độ phủ thấp, nên điểm dưới ngưỡng: tác tử phải nói không
    biết thay vì trả lời dựa trên một đoạn gần như không liên quan.
    """
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    _nap_rag(root, [("Thanh ghi CR1 nằm ở offset 0x00.", [])])
    _gia_lap(monkeypatch, {"answer": "Bịa ra từ một đoạn không liên quan [1]."})
    out = r.invoke("view.rag_ask",
                   {"question": "CR1 nhiệt độ cảm biến ngoài trời buổi sáng"}, ctx).result
    assert out["not_found"] is True, out


def test_do_phu_cao_thi_diem_cao_hon(du_an):
    """Thang điểm phải ĐỒNG BIẾN với độ khớp. Bản đầu của `RagIndex.tim` chuẩn hóa
    `1/(1+|bm25|)` — đảo ngược, vì `bm25()` càng ÂM càng khớp. Thứ tự vẫn đúng nhờ `ORDER BY`
    trong SQL nên lỗi im lặng suốt, cho tới khi `view.rag_ask` dùng điểm làm ngưỡng.
    """
    _, _, root = du_an
    _nap_rag(root, [("Thanh ghi CR1 nằm ở offset 0x00 của khối I2C1.", []),
                    ("Một đoạn nói về chủ đề CR1 và không có gì khác.", [])])
    from eide_core.rag import RagIndex
    ds = {d["id"]: d for d in RagIndex(root).tim("CR1 offset khối I2C1", 5)}
    assert len(ds) == 2
    assert ds["rc_0"]["score"] > ds["rc_1"]["score"], "đoạn phủ nhiều từ khóa hơn phải điểm cao hơn"
    assert ds["rc_0"]["coverage"] > ds["rc_1"]["coverage"]


def test_tra_loi_kem_trich_dan_va_trace_id(du_an, monkeypatch):
    """tc TC-79: "100% citations"."""
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    _nap_rag(root, [("Thanh ghi I2C1 CR1 nằm ở offset 0x00 của khối I2C1.", [])])
    _gia_lap(monkeypatch, {"answer": "CR1 nằm ở offset 0x00 [1]."})
    out = r.invoke("view.rag_ask", {"question": "I2C1 CR1 offset"}, ctx).result
    assert out["not_found"] is False
    assert out["citations"] and out["citations"][0]["source_id"] == "s_svd"
    assert out["trace_id"].startswith("tr_")


def test_cau_khong_trich_dan_thi_tu_choi(du_an, monkeypatch):
    """Bước 1 đòi "mọi câu có [n]". Đặt một `[1]` ở cuối ba đoạn văn là hình thức: người đọc
    không biết câu nào đến từ đâu."""
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    _nap_rag(root, [("Thanh ghi I2C1 CR1 nằm ở offset 0x00.", [])])
    _gia_lap(monkeypatch, {"answer": "CR1 ở offset 0x00 [1]. Ngoài ra chip này rất phổ biến."})
    run = r.invoke("view.rag_ask", {"question": "I2C1 CR1 offset"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


@pytest.mark.parametrize(("t", "ok"), [
    ("Một câu có trích dẫn đầy đủ ở đây [1].", True),
    ("Câu một có nguồn [1]. Câu hai cũng có nguồn [2].", True),
    ("Câu một có nguồn [1]. Câu hai thì không có gì cả.", False),
    ("Điện áp là 3.3 V theo tài liệu [1].", True),      # dấu chấm trong số không phải kết câu
    ("", False),
])
def test_kiem_trich_dan_theo_cau(t, ok):
    assert _moi_cau_co_trich_dan(t) is ok


def test_chua_lap_chi_muc_thi_bao_E5002(du_an):
    r, ctx, _ = du_an
    run = r.invoke("view.rag_ask", {"question": "gì đó"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"
    assert "view.rag_index" in str(run.error)


def test_nguong_diem_dung_gia_tri_hop_dong():
    """"< 0,35 → not_found" — con số của hợp đồng, không phải con số tôi chọn."""
    assert NGUONG_DIEM == 0.35


# ---------- VIEW-06 rag_trace


def test_tra_du_ba_diem_thanh_phan(du_an, monkeypatch):
    """tc: "Hiển thị đủ 3 điểm". Khi câu trả lời sai, người sửa cần biết đoạn ấy lọt vào vì
    trùng từ khóa hay vì lan tỏa đồ thị — hai nguyên nhân sửa bằng hai cách khác nhau."""
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    _nap_rag(root, [("Thanh ghi I2C1 CR1 offset 0x00.", [f"{CHIP}/periph:I2C1"])])
    _gia_lap(monkeypatch, {"answer": "CR1 ở offset 0x00 [1]."})
    tid = r.invoke("view.rag_ask", {"question": "I2C1 CR1 offset"}, ctx).result["trace_id"]
    tr = r.invoke("view.rag_trace", {"trace_id": tid}, ctx).result
    assert tr["chunks"]
    for diem in tr["scores"].values():
        assert {"bm25", "vector", "graph"} <= set(diem)
        # `coverage` là thành phần thứ tư, thêm sau khi phát hiện bm25 suy biến trên kho nhỏ:
        # một từ có mặt trong MỌI tài liệu thì IDF = 0, nên kho một tài liệu luôn ra bm25 = 0.
        assert "coverage" in diem


def test_trace_la_bao_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("view.rag_trace", {"trace_id": "tr_khongco"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- VIEW-07 rag_index


def test_tang_dan_theo_sha256(du_an, tmp_path):
    """tc TC-DD-05. Lập lại chỉ mục cho một datasheet 900 trang tốn hàng phút và tốn tiền
    embedding; làm lại mỗi lần mở dự án thì không ai bật tính năng này lần thứ hai."""
    r, ctx, root = du_an
    f = tmp_path / "note.md"
    f.write_text("# Ghi chú\n\nI2C1 dùng chân PB6 và PB7.\n", encoding="utf-8")
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1', ?, 'sha_1', 'md', 'bronze')", (str(f),))
        c.commit()
    a = r.invoke("view.rag_index", {}, ctx).result
    assert a["chunks"] >= 1 and "lập lại" in a["status"]["s_1"]
    b = r.invoke("view.rag_index", {}, ctx).result
    assert b["chunks"] == 0 and "bỏ qua" in b["status"]["s_1"]


def test_rebuild_ep_lap_lai(du_an, tmp_path):
    r, ctx, root = du_an
    f = tmp_path / "note.md"
    f.write_text("# Ghi chú\n\nnội dung\n", encoding="utf-8")
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1', ?, 'sha_1', 'md', 'bronze')", (str(f),))
        c.commit()
    r.invoke("view.rag_index", {}, ctx)
    assert r.invoke("view.rag_index", {"rebuild": True}, ctx).result["chunks"] >= 1


def test_gan_IRI_luc_lap_chi_muc(du_an, tmp_path):
    """Gắn IRI ngay lúc lập chỉ mục, không tra lúc truy vấn: đó là thứ cho `theo_iri` khớp CHÍNH
    XÁC thay vì đoán bằng từ khóa."""
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    f = tmp_path / "note.md"
    f.write_text("Khối I2C1 nằm trên bus APB1.\n", encoding="utf-8")
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_2', ?, 'sha_2', 'md', 'bronze')", (str(f),))
        c.commit()
    r.invoke("view.rag_index", {}, ctx)
    from eide_core.rag import RagIndex
    assert RagIndex(root).theo_iri([f"{CHIP}/periph:I2C1"]), "IRI chưa được gắn vào graph_nodes"


def test_chunk_khong_cat_giua_cau(du_an, monkeypatch):
    """Cắt giữa câu thì đoạn trả cho `rag_ask` mất chủ ngữ hoặc mất con số, và mô hình trả lời
    dựa trên nửa câu ấy sẽ sai theo cách rất khó thấy."""
    import eide.caps.view as m
    monkeypatch.setattr(m, "DAI_CHUNK", 60)
    cau = "Thanh ghi CR1 nằm ở offset 0x00. Thanh ghi CR2 nằm ở offset 0x04. Xong."
    ds = m._chia(cau)
    assert len(ds) > 1
    for d in ds:
        assert not d.endswith(("offse", "0x0", "Thanh gh")), d
    assert "".join(ds).replace(" ", "") == cau.replace(" ", "")


# ---------- VIEW-08 doc_side_by_side


def test_bbox_tra_nguyen_van(du_an):
    """tc: "Vùng bôi sáng đúng bbox". Quy đổi sang toạ độ màn hình ở đây là đoán một con số mà
    chỉ phía kia biết."""
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 0x40005400, "gold", "normalized")])
    out = r.invoke("view.doc_side_by_side", {"ref": "f_1"}, ctx).result
    assert out["left"]["page"] == 47
    assert out["left"]["bbox"] == [10, 20, 30, 40]
    assert out["right"]["kind"] == "fact" and out["right"]["value"] == 0x40005400


def test_ref_la_code_unit(du_an):
    r, ctx, root = du_an
    nap(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, "gold", "normalized")])
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO code_unit (id, path, hash, cites) VALUES "
                  "('cu_1','src/i2c.c','h', ?)", (json.dumps(["f_1"]),))
        c.commit()
    out = r.invoke("view.doc_side_by_side", {"ref": "cu_1"}, ctx).result
    assert out["right"]["path"] == "src/i2c.c"
    assert out["left"]["page"] == 47, "code_unit có trích dẫn thì bên trái phải là nguồn của nó"


def test_ref_la_bao_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("view.doc_side_by_side", {"ref": "khong_co"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- VIEW-09 export_map


def _view_nho():
    return {"graph": {"nodes": [{"id": "chip:x/periph:I2C1", "label": "I2C1", "tier": "gold",
                                 "status": "normalized", "kind": "periph", "color": "#D4A017"},
                                {"id": "f_1", "label": "f_1", "tier": "gold",
                                 "status": "conflict", "kind": "fact", "color": "#C5221F"}],
                      "edges": [{"from": "chip:x/periph:I2C1", "type": "HAS", "to": "f_1"}]}}


def test_mermaid_render_duoc(du_an):
    """tc nguyên văn: "Mermaid render được"."""
    r, ctx, _ = du_an
    f = r.invoke("view.export_map", {"view": _view_nho(), "format": "mermaid"},
                 ctx).result["file"]
    from pathlib import Path
    t = Path(f).read_text(encoding="utf-8")
    assert t.startswith("graph LR")
    assert "-->|HAS|" in t
    assert "I2C1" in t and "style" in t
    assert ":" not in t.split("\n")[1].split("[")[0], "định danh mermaid không được chứa ':'"


def test_mermaid_qua_300_nut_thi_bao(du_an):
    r, ctx, _ = du_an
    v = {"graph": {"nodes": [{"id": f"n{i}", "label": f"n{i}"} for i in range(TRAN_MERMAID + 1)],
                   "edges": []}}
    run = r.invoke("view.export_map", {"view": v, "format": "mermaid"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5000"


def test_graphml_khong_bi_gioi_han_300(du_an):
    """Trần 300 chỉ áp cho mermaid vì đó là ngưỡng nó còn vẽ ra thứ người nhìn được. `graphml`
    50.000 nút vẫn hợp lệ — chỉ là không ai mở bằng mắt."""
    r, ctx, _ = du_an
    v = {"graph": {"nodes": [{"id": f"n{i}", "label": f"n{i}"} for i in range(TRAN_MERMAID + 50)],
                   "edges": []}}
    assert r.invoke("view.export_map", {"view": v, "format": "graphml"}, ctx).result["file"]


def test_graphml_hop_le_va_thoat_ky_tu(du_an):
    r, ctx, _ = du_an
    v = {"graph": {"nodes": [{"id": "a", "label": "A & <B>", "tier": "gold"}], "edges": []}}
    f = r.invoke("view.export_map", {"view": v, "format": "graphml"}, ctx).result["file"]
    import xml.etree.ElementTree as ET
    from pathlib import Path
    goc = ET.parse(f).getroot()          # nạp được = XML hợp lệ, tức đã thoát ký tự
    assert goc.tag.endswith("graphml")
    assert "A &amp; &lt;B&gt;" in Path(f).read_text(encoding="utf-8")


def test_dot_xuat_duoc(du_an):
    r, ctx, _ = du_an
    f = r.invoke("view.export_map", {"view": _view_nho(), "format": "dot"}, ctx).result["file"]
    from pathlib import Path
    t = Path(f).read_text(encoding="utf-8")
    assert t.startswith("digraph KG {") and t.rstrip().endswith("}")
    assert "->" in t


def test_svg_thieu_graphviz_thi_bao_E4001(du_an, monkeypatch):
    """Không lặng lẽ trả `dot` với phần mở rộng `.svg` — một tệp mang đuôi sai là thứ hỏng ở chỗ
    khác, muộn hơn, và khó lần."""
    import eide_core.tools
    monkeypatch.setattr(eide_core.tools, "which", lambda *a, **k: None)
    r, ctx, _ = du_an
    run = r.invoke("view.export_map", {"view": _view_nho(), "format": "svg"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4001"
    assert run.error["package"] == "graphviz"
