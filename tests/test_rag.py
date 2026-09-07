"""RagIndex và MEMORY-03 `memory.retrieve` — WI-012.

Spec: CDS-12.6 MEMORY-03 (tc TC-CX-02); CXD-10 §4.5 Graph-RAG hai bước; DDD-14 §2 RagChunk,
§5 migration 0003 (`index.sqlite` riêng).
"""
from __future__ import annotations

import hashlib
import json

import pytest

from eide_core import store
from eide_core.composer import cau_hinh
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.rag import Doan, RagIndex, tach_tu
from eide_core.router import Context, Router

CHIP = "chip:st.stm32f411ce"
I2C1 = f"{CHIP}/periph:I2C1"
CR1 = f"{I2C1}/reg:CR1"
BME = "part:bosch.bme280"


def _fact(c, subject, predicate, value, *, source="src_a", tier="silver",
          status="reviewed", fid=None):
    fid = fid or f"f_{abs(hash((subject, predicate))) % 10**12:012d}"
    c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
              " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
              (fid, subject, predicate, json.dumps(value, ensure_ascii=False), source,
               "parser", tier, 0.9, status, "A"))
    return fid


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án đo nhiệt độ"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    store.open_index(store.index_path(root)).close()
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id,uri,sha256,kind,tier,license,domain) VALUES (?,?,?,?,?,?,?)",
                  ("src_a", "https://st.com/rm.pdf", hashlib.sha256(b"a").hexdigest(),
                   "pdf_vendor", "gold", "vendor-doc", "st.com"))
        _fact(c, I2C1, "pin_function", "PB6/PB7", fid="f_pin")
        _fact(c, CR1, "offset", 0, fid="f_off")
        _fact(c, CR1, "description", "Control register 1", fid="f_desc")
        _fact(c, BME, "address", "0x76", fid="f_bme")
        _fact(c, CHIP, "package", "LQFP48", tier="gold", fid="f_pkg")
        c.commit()
    store.write_seal(store.store_path(root), r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


# ---------- RagIndex


def test_them_roi_tim_duoc_bang_fts(du_an):
    """`rag_chunk_fts` là bảng NGOÀI (`content='rag_chunk'`) — nó không tự cập nhật.

    Quên chèn theo rowid thì mọi truy vấn FTS trả rỗng trong khi bảng chính đầy dữ liệu, và
    triệu chứng ấy trông y hệt "chưa lập chỉ mục".
    """
    _, _, root = du_an
    idx = RagIndex(root)
    assert idx.them([Doan("rc_1", "src_a", "I2C1 dùng chân PB6 và PB7 ở chế độ AF4",
                          locator={"page": 12}, graph_nodes=[I2C1])]) == 1
    assert idx.dem() == 1
    ra = idx.tim("PB6")
    assert [d["id"] for d in ra] == ["rc_1"]
    assert ra[0]["locator"] == {"page": 12} and 0 < ra[0]["score"] <= 1.0


def test_iri_khong_lam_vo_cu_phap_fts(du_an):
    """FTS5 coi `:` `/` `.` là cú pháp. Đưa thẳng một IRI vào `MATCH` sẽ ném lỗi cú pháp —
    hoặc tệ hơn, khớp nhầm."""
    _, _, root = du_an
    idx = RagIndex(root)
    idx.them([Doan("rc_1", "src_a", "Thanh ghi CR1 của I2C1", graph_nodes=[CR1])])
    assert tach_tu(CR1) == ["chip", "st", "stm32f411ce", "periph", "I2C1", "reg", "CR1"]
    assert idx.tim(CR1), "truy vấn bằng IRI nguyên vẹn phải chạy được"


def test_khop_graph_nodes_duoc_uu_tien_hon_tu_khoa(du_an):
    """Khớp `graph_nodes` là sự thật đã ghi lúc lập chỉ mục; điểm FTS là ước lượng.

    Không trộn hai thang điểm: cột `cach` phải nói rõ bên đọc đang nhìn cái nào.
    """
    _, _, root = du_an
    idx = RagIndex(root)
    idx.them([
        Doan("rc_gan", "src_a", "Đoạn này không nhắc tên nhưng đã gắn nhãn", graph_nodes=[I2C1]),
        Doan("rc_tu", "src_a", f"Đoạn này nhắc {I2C1} trong văn bản", graph_nodes=[]),
    ])
    ra = idx.retrieve([I2C1], k=8)
    assert ra[0]["id"] == "rc_gan" and ra[0]["cach"] == "graph_nodes" and ra[0]["score"] == 1.0
    assert any(d["id"] == "rc_tu" and d["cach"] == "fts" for d in ra), "từ khóa vẫn phải bù vào"


def test_xoa_nguon_don_ca_bang_fts(du_an):
    """Xóa `rag_chunk` mà quên `rag_chunk_fts` để lại dòng mồ côi, và truy vấn sau đó sẽ JOIN
    vào một rowid không còn gì — trả về đoạn rỗng thay vì không trả gì."""
    _, _, root = du_an
    idx = RagIndex(root)
    idx.them([Doan("rc_1", "src_a", "abc", graph_nodes=[]), Doan("rc_2", "src_b", "abc", graph_nodes=[])])
    assert idx.xoa_nguon("src_a") == 1
    assert idx.dem() == 1
    assert [d["id"] for d in idx.tim("abc")] == ["rc_2"]


# ---------- MEMORY-03 memory.retrieve


def test_retrieve_tra_ca_fact_va_snippet_kem_locator(du_an):
    """tc MEMORY-03: TC-CX-02. Bước 2 của hợp đồng: "Trả kèm locator và điểm".

    Không có locator thì không lần về trang nào trong tài liệu gốc được, và một câu trả lời
    không truy nguyên được thì KAD-07 §4.1 không cho vào fact.
    """
    r, ctx, root = du_an
    RagIndex(root).them([Doan("rc_1", "src_a", "I2C1 ở PB6/PB7", locator={"page": 12}, graph_nodes=[I2C1])])
    out = r.invoke("memory.retrieve", {"subjects": [I2C1]}, ctx).result
    assert {f["id"] for f in out["facts"]} >= {"f_pin"}
    assert all("score" in f and "source_id" in f for f in out["facts"])
    assert out["snippets"][0]["locator"] == {"page": 12}


def test_lan_toa_hai_buoc_toi_duoc_thanh_ghi_con(du_an):
    """CXD-10 §4.5: hai bước theo cạnh HAS. `I2C1` → `CR1` là một bước, nên fact của CR1 phải
    vào kết quả khi hỏi về I2C1."""
    r, ctx, _ = du_an
    ids = {f["id"] for f in r.invoke("memory.retrieve", {"subjects": [I2C1], "k": 20}, ctx).result["facts"]}
    assert "f_off" in ids, "không tới được fact của thanh ghi con"
    assert "f_bme" not in ids, "BME280 không nối với I2C1 trong store này"


def test_diem_lay_LON_NHAT_khong_phai_tong(du_an):
    """§4.5: `scored[f] = max(scored.get(f, 0), w)`.

    Cộng dồn sẽ đẩy những nút bậc cao (chip gốc) lên đầu bất kể chúng có liên quan tới tác vụ
    hay không — đúng thứ Graph-RAG sinh ra để tránh.
    """
    r, ctx, _ = du_an
    facts = r.invoke("memory.retrieve", {"subjects": [CR1], "k": 20}, ctx).result["facts"]
    d = {f["id"]: f["score"] for f in facts}
    assert d["f_off"] > d.get("f_pin", 0), "fact của chính hạt giống phải trên fact cách một bước"
    assert all(v <= 1.0 for v in d.values()), "điểm không được cộng dồn vượt 1,0"


def test_trong_so_vi_tu_lam_description_xuong_cuoi(du_an):
    """PRED_W: `offset` = 1,0 còn `description` = 0,3 "(chỉ khi còn ngân sách)".

    Hai fact CÙNG subject nên điểm subject bằng nhau — chênh lệch chỉ đến từ trọng số vị từ.
    """
    r, ctx, _ = du_an
    facts = r.invoke("memory.retrieve", {"subjects": [CR1], "k": 20}, ctx).result["facts"]
    d = {f["id"]: f["score"] for f in facts}
    assert d["f_off"] > d["f_desc"]
    assert cau_hinh()["pred_weight"]["description"] < cau_hinh()["pred_weight"]["offset"]


def test_fact_mau_thuan_luon_co_mat_du_vuot_k(du_an):
    """§4.5 `always_include=[f for f in facts if f.status == "conflict"]`.

    Câu cuối của §4.5 nói vì sao: mô hình phải nói "không xác định" thay vì tự chọn một bên.
    Giấu mâu thuẫn đi là cách chắc chắn nhất để nó chọn bừa.
    """
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, BME, "address", "0x77", status="conflict", fid="f_xung1")
        _fact(c, BME, "timing", {"t_startup_ms": 2}, status="conflict", fid="f_xung2")
        c.commit()
    store.write_seal(store.store_path(root))

    # k=1 với HAI mâu thuẫn: cắt theo k sẽ trả về một, "always_include" phải trả về cả hai.
    # Bản đầu của test này dùng một mâu thuẫn duy nhất — nó vốn đã xếp đầu nên cắt hay không
    # cũng ra như nhau, và một đột biến bỏ hẳn always_include vẫn qua được.
    out = r.invoke("memory.retrieve", {"subjects": [BME], "k": 1}, ctx).result
    ids = [f["id"] for f in out["facts"]]
    assert set(ids) >= {"f_xung1", "f_xung2"}, f"mâu thuẫn bị cắt theo k: {ids}"
    assert all(f["conflict"] for f in out["facts"][:2])
    assert len(ids) > 1, "k=1 nhưng hai mâu thuẫn vẫn phải có mặt"


def test_fact_chua_duyet_khong_vao_ket_qua(du_an):
    """§4.5: "chỉ status reviewed/verified hoặc gold". Một fact `normalized` chưa qua G-FACT mà
    lọt vào ngữ cảnh là tri thức chưa duyệt được mô hình dùng như đã duyệt."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        _fact(c, I2C1, "irq", 31, status="normalized", tier="silver", fid="f_chua")
        c.commit()
    store.write_seal(store.store_path(root))
    ids = {f["id"] for f in r.invoke("memory.retrieve", {"subjects": [I2C1], "k": 20}, ctx).result["facts"]}
    assert "f_chua" not in ids


def test_hops_ngoai_khoang_la_E1000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("memory.retrieve", {"subjects": [I2C1], "hops": 4}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_subject_khong_co_trong_do_thi_tra_rong(du_an):
    r, ctx, _ = du_an
    out = r.invoke("memory.retrieve", {"subjects": ["chip:khong-ton-tai"]}, ctx).result
    assert out["facts"] == [] and out["snippets"] == []
