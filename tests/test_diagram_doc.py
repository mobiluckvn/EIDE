"""Nhóm diagram.* và doc.* mốc M1 — CDS-12.4; CON-28 §6; DDD-14 §2 Diagram/DocArtifact.

tc: TC-71 "sáu ngôn ngữ"; TC-72 "nút/cạnh khớp BOM/net"; "Render được; màu đúng"; "Nút không có
trong ModuleGraph → issue"; "Có citations"; "Mọi số liệu có trang"; TC-76.

Hai bất biến xuyên suốt, và cả hai đều về việc KHÔNG bịa:
- lược đồ chỉ vẽ những gì có trong mô hình/BOM (`diagram.lint` bắt nút lạ, `diagram.block` từ
  chối vẽ khi không có BOM);
- tài liệu chỉ nêu số có fact, và mọi số đều kèm trang (`doc.datasheet_summary`), còn
  `doc.style_check` bắt chiều ngược lại.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.diagram import KIND_CU_PHAP, KIND_LA, KIND_MO_COI, TRAN_NUT
from eide.caps.doc import NGUONG_TIENG_ANH, glossary
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án tài liệu"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _gia_lap(monkeypatch, data, mod="doc"):
    class _R:
        def __init__(self, d): self.data = d
    class _G:
        def run(self, *a, **k): return _R(data)
    import importlib
    m = importlib.import_module(f"eide.caps.{mod}")
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())


CHIP = "chip:st.stm32f411"


def nap_fact(root, facts):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1','ds/stm32f411.pdf','h1','pdf','silver')")
        for fid, subj, vt, gt, dv, page in facts:
            c.execute(
                "INSERT OR REPLACE INTO fact (id, subject, predicate, value, unit, source_id,"
                " method, tier, confidence, status, locator)"
                " VALUES (?,?,?,?,?,'s_1','parser','gold',1.0,'normalized',?)",
                (fid, subj, vt, json.dumps(gt), dv,
                 json.dumps({"page": page}) if page else None))
        c.commit()


# ---------- DIAGRAM-04 lint


MERMAID_OK = "flowchart LR\n  mcu[STM32F411] ---|I2C 0x76| bme[BME280]\n"


def test_cu_phap_hop_le_thi_khong_bao(du_an):
    r, ctx, _ = du_an
    out = r.invoke("diagram.lint", {"src": MERMAID_OK, "lang": "mermaid"}, ctx).result
    assert [x for x in out["issues"] if x["kind"] == KIND_CU_PHAP] == []


@pytest.mark.parametrize(("src", "vi_sao"), [
    ("", "rỗng"),
    ("flowchart LR\n  a[--> b\n", "lệch ngoặc"),
    ("khong phai mermaid\n  a --> b\n", "dòng đầu sai"),
])
def test_cu_phap_hong_bi_bat(du_an, src, vi_sao):
    """Kiểm cú pháp NHẸ, không gọi renderer: `lint` chạy TRƯỚC `render` và phải dùng được trên
    máy chưa cài công cụ nào — đúng lúc người dùng cần nó nhất."""
    r, ctx, _ = du_an
    out = r.invoke("diagram.lint", {"src": src, "lang": "mermaid"}, ctx).result
    assert [x for x in out["issues"] if x["kind"] == KIND_CU_PHAP], vi_sao


def test_nut_khong_co_trong_ModuleGraph_thanh_issue(du_an):
    """tc DIAGRAM-04 nguyên văn. Đây là phép kiểm đáng giá nhất: một lược đồ SAI CÚ PHÁP thì
    renderer báo ngay, còn một lược đồ đúng cú pháp mà vẽ sai hệ thống thì không ai báo — nó
    được dán vào tài liệu và trở thành mô tả chính thức của một kiến trúc không tồn tại."""
    from eide.caps.arch import _ghi_module
    r, ctx, root = du_an
    _ghi_module(root, [{"id": "mod_i2c", "name": "i2c", "depends": [], "interfaces": [],
                        "status": "proposed"}])
    src = "flowchart LR\n  mod_i2c --> mod_khong_ton_tai\n"
    la = [x for x in r.invoke("diagram.lint",
                              {"src": src, "lang": "mermaid", "model_ref": "module"},
                              ctx).result["issues"] if x["kind"] == KIND_LA]
    assert [x["message"] for x in la] and "mod_khong_ton_tai" in la[0]["message"]
    assert "mod_i2c" not in " ".join(x["message"] for x in la)


def test_khong_co_model_ref_thi_bo_qua_chu_khong_doan(du_an):
    """Đối chiếu với mô hình SAI còn tệ hơn không đối chiếu: nó báo lỗi ở những chỗ đúng, và
    người dùng học cách bỏ qua cả danh sách."""
    r, ctx, _ = du_an
    out = r.invoke("diagram.lint", {"src": "flowchart LR\n  a --> b\n", "lang": "mermaid"},
                   ctx).result
    assert [x for x in out["issues"] if x["kind"] == KIND_LA] == []


def test_nut_mo_coi_bi_bao(du_an):
    r, ctx, _ = du_an
    src = "flowchart LR\n  a --> b\n  coc[Cô đơn]\n"
    mo = [x for x in r.invoke("diagram.lint", {"src": src, "lang": "mermaid"},
                              ctx).result["issues"] if x["kind"] == KIND_MO_COI]
    assert [x for x in mo if "coc" in x["message"]]


def test_luoc_do_qua_lon_bi_bao(du_an):
    r, ctx, _ = du_an
    src = "flowchart LR\n" + "\n".join(f"  n{i} --> n{i + 1}" for i in range(TRAN_NUT + 5))
    assert [x for x in r.invoke("diagram.lint", {"src": src, "lang": "mermaid"},
                                ctx).result["issues"] if x["kind"] == "size"]


def test_lint_khong_phan_tich_thi_khong_bao_bua(du_an):
    """`plantuml`/`d2`/`wavedrom` chưa phân tích được đồ thị. Báo mồ côi hay nút lạ trên chúng là
    báo bừa, mà một danh sách báo bừa thì người dùng bỏ qua cả những mục đúng.

    Kiểm THẲNG `_doc_do_thi` chứ không kiểm qua danh sách issue: bản đầu tôi dùng một mã plantuml
    mà dù có phân tích nhầm cũng không sinh ra issue nào (Alice và Bob nối nhau nên không mồ
    côi), nên gỡ hẳn phép chặn ra mà test vẫn xanh — nó chứng minh nhầm thứ.
    """
    from eide.caps.diagram import _doc_do_thi
    src = "@startuml\nAlice -> Bob: xin chào\nCharlie -> Dave: chào\n@enduml\n"
    for lang in ("plantuml", "d2", "wavedrom"):
        assert _doc_do_thi(src, lang) == (set(), []), f"{lang} không được phân tích bừa"
    r, ctx, _ = du_an
    out = r.invoke("diagram.lint", {"src": src, "lang": "plantuml"}, ctx).result
    assert [x for x in out["issues"] if x["kind"] in (KIND_MO_COI, KIND_LA)] == []


# ---------- DIAGRAM-01 render


def test_svg_sao_chep_khong_dung_bo_dung(du_an):
    """"svg: sao chép" — đã là ảnh vector, dựng lại là biến đổi thừa và có thể làm mất chữ."""
    r, ctx, _ = du_an
    svg = '<svg xmlns="http://www.w3.org/2000/svg"><text>xin chào</text></svg>'
    p = r.invoke("diagram.render", {"src": svg, "lang": "svg"}, ctx).result["path"]
    from pathlib import Path
    assert Path(p).read_text(encoding="utf-8") == svg


def test_thieu_bo_dung_bao_E4001_nhung_van_tra_ket_qua_lint(du_an, monkeypatch):
    """E4001 kèm tên gói, và `lint` VẪN chạy — người dùng chưa cài gì vẫn biết lược đồ của mình
    có hợp lệ không. Đó là lý do `lint` không được phép cần công cụ ngoài."""
    import eide_core.tools
    monkeypatch.setattr(eide_core.tools, "which", lambda *a, **k: None)
    r, ctx, _ = du_an
    run = r.invoke("diagram.render", {"src": MERMAID_OK, "lang": "mermaid"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4001"
    assert run.error["package"] == "mermaid-cli"
    assert "lint" in run.error and run.error["src_path"].endswith(".mmd")


def test_cu_phap_hong_thi_E4000_truoc_khi_goi_bo_dung(du_an):
    """Bước 1: `diagram.lint` chạy TRƯỚC. Renderer báo lỗi bằng thông điệp của riêng nó (`mmdc`
    in một stack trace JavaScript), còn `lint` nói được "dòng 7, lệch ngoặc"."""
    r, ctx, _ = du_an
    run = r.invoke("diagram.render", {"src": "flowchart LR\n a[--> b", "lang": "mermaid"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4000"


def test_ngon_ngu_la_bi_chan_boi_schema_truoc_ca_handler(du_an):
    """`lang` có enum trong `input_schema`, nên Router chặn ở bước kiểm đầu vào — E1000 NÉM RA
    chứ không thành một run `failed`. Đúng tầng: đối số sai là lỗi của bên gọi, không phải một
    lần chạy hỏng. Nhánh E1000 bên trong `render` vì thế là lớp phòng thủ thứ hai."""
    from eide_core.errors import EideError
    r, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        r.invoke("diagram.render", {"src": "x", "lang": "khong_co"}, ctx)
    assert e.value.code == "E1000"


def test_TC71_sau_ngon_ngu_deu_khai_bo_dung():
    """tc TC-71 "sáu ngôn ngữ": mermaid, plantuml, dot, d2, wavedrom, svg."""
    from eide.caps.diagram import BO_RENDER, DUOI
    assert set(BO_RENDER) | {"svg"} == {"mermaid", "plantuml", "dot", "d2", "wavedrom", "svg"}
    assert set(DUOI) == set(BO_RENDER) | {"svg"}
    assert all(goi for _, goi, _ in BO_RENDER.values()), "mỗi bộ dựng phải có tên gói cho E4001"


# ---------- DIAGRAM-02 block


BOM = [{"ref": "U1", "mpn": "STM32F411CE", "role": "mcu"},
       {"ref": "U2", "mpn": "BME280", "role": "sensor", "bus": "I2C", "address": "0x76"},
       {"ref": "U3", "mpn": "A4988", "role": "driver", "bus": "SPI"}]


def test_TC72_nut_va_canh_khop_BOM(du_an):
    r, ctx, _ = du_an
    d = r.invoke("diagram.block", {"board": "b1", "bom": BOM}, ctx).result["diagram"]
    assert set(d["nodes"]) == {"U1", "U2", "U3"}
    canh = {(e["from"], e["to"]): e["label"] for e in d["edges"]}
    assert canh[("U1", "U2")] == "I2C 0x76"
    assert canh[("U1", "U3")] == "SPI"


def test_tra_ma_luoc_do_khong_tra_anh(du_an):
    """CON-28 §6 định nghĩa "lược đồ" là *sơ đồ ở dạng ngôn ngữ văn bản*. Nguồn sự thật là `src`;
    ảnh là kết quả dựng lại được. Lược đồ vào Git dưới dạng khác biệt đọc được, người xem lại
    được lịch sử "vì sao cạnh này đổi", và `diagram.lint` kiểm được nội dung."""
    r, ctx, _ = du_an
    d = r.invoke("diagram.block", {"board": "b1", "bom": BOM}, ctx).result["diagram"]
    assert d["lang"] == "mermaid" and d["src"].startswith("flowchart LR")
    assert "path" not in d


def test_khong_co_BOM_thi_tu_choi_ve(du_an):
    """Nhờ mô hình vẽ thì nó thêm một cảm biến trông hợp lý mà BOM không có — và sơ đồ khối là
    thứ người ta dùng để ĐẶT HÀNG linh kiện."""
    r, ctx, _ = du_an
    run = r.invoke("diagram.block", {"board": "khong_co"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_luoc_do_sinh_ra_qua_duoc_lint(du_an):
    """Vòng khép: thứ `diagram.block` sinh ra phải qua được chính `diagram.lint`."""
    r, ctx, _ = du_an
    src = r.invoke("diagram.block", {"board": "b1", "bom": BOM}, ctx).result["diagram"]["src"]
    out = r.invoke("diagram.lint", {"src": src, "lang": "mermaid"}, ctx).result
    assert [x for x in out["issues"] if x["severity"] == "high"] == []


# ---------- DIAGRAM-03 kg_view


def test_kg_view_dung_lai_mau_cua_view_kg_map(du_an):
    """Hai bảng màu cho cùng một ý nghĩa là hai bảng sẽ lệch — và lệch màu thì `conflict` đỏ ở
    màn hình này lại xám ở màn hình kia, mà màu là thứ người dùng đọc trước cả chữ."""
    from eide.caps.view import MAU_STATUS
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1','a.svd','h','svd','gold')")
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status) VALUES ('f_1',?,'base_address','1','s_1','parser',"
                  "'gold',1.0,'conflict')", (f"{CHIP}/periph:I2C1",))
        c.commit()
    d = r.invoke("diagram.kg_view", {"query": {}}, ctx).result["diagram"]
    assert d["lang"] == "dot" and d["src"].startswith("digraph")
    assert MAU_STATUS["conflict"] in d["src"], "màu conflict phải giống view.kg_map"


def test_kg_view_qua_300_nut_thi_bao(du_an, monkeypatch):
    import eide.caps.diagram as m
    monkeypatch.setattr(m, "TRAN_NUT", 2)
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1','a.svd','h','svd','gold')")
        for i in range(5):
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method,"
                      " tier, confidence, status) VALUES (?,?,'base_address','1','s_1',"
                      "'parser','gold',1.0,'normalized')", (f"f_{i}", f"{CHIP}/periph:P{i}"))
        c.commit()
    run = r.invoke("diagram.kg_view", {"query": {}}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5000"


# ---------- DOC-08 style_check


def _viet(root, ten, noi):
    p = root / ".eide" / "docs" / ten
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(noi, encoding="utf-8")
    return str(p)


def test_TC76_cau_co_so_lieu_khong_trich_dan_bi_bao(du_an):
    """Nhóm đáng giá nhất. Nó bắt đúng câu kiểu "ADC lấy mẫu ở 2,4 MSPS" đứng một mình — con số
    trông có thẩm quyền mà không truy được về đâu, và đó là thứ người phản biện hỏi đầu tiên."""
    r, ctx, root = du_an
    f = _viet(root, "a.md", "Bộ chuyển đổi lấy mẫu ở 2400 kHz theo thiết kế hiện tại.\n")
    out = r.invoke("doc.style_check", {"doc_id": f}, ctx).result["issues"]
    assert [x for x in out if x["kind"] == "uncited"]


def test_cau_co_trich_dan_thi_khong_bao(du_an):
    r, ctx, root = du_an
    f = _viet(root, "b.md", "Bộ chuyển đổi lấy mẫu ở 2400 kHz [ds.pdf#p12].\n")
    out = r.invoke("doc.style_check", {"doc_id": f}, ctx).result["issues"]
    assert [x for x in out if x["kind"] == "uncited"] == []


def test_so_khong_co_don_vi_khong_bi_coi_la_so_lieu(du_an):
    """"ba bước", "Hình 2", "năm 2026" không cần trích dẫn — bắt chúng thì danh sách đầy nhiễu
    rồi không ai đọc."""
    r, ctx, root = du_an
    f = _viet(root, "c.md", "Quy trình gồm 3 bước chính và hoàn tất trong năm 2026.\n")
    out = r.invoke("doc.style_check", {"doc_id": f}, ctx).result["issues"]
    assert [x for x in out if x["kind"] == "uncited"] == []


def test_thuat_ngu_glossary_khong_giai_nghia_bi_bao(du_an):
    """tc bước 1: "thuật ngữ trong glossary CON-28 xuất hiện lần đầu không kèm giải nghĩa →
    term"."""
    r, ctx, root = du_an
    f = _viet(root, "d.md", "Hệ thống dùng một tác tử để làm việc thay người.\n")
    out = r.invoke("doc.style_check", {"doc_id": f}, ctx).result["issues"]
    assert [x for x in out if x["kind"] == "term" and "tác tử" in x["text"]]


def test_thuat_ngu_kem_tieng_anh_thi_khong_bao(du_an):
    r, ctx, root = du_an
    f = _viet(root, "e.md", "Hệ thống dùng một tác tử (agent) để làm việc thay người.\n")
    out = r.invoke("doc.style_check", {"doc_id": f}, ctx).result["issues"]
    assert [x for x in out if x["kind"] == "term" and "tác tử" in x["text"]] == []


def test_thieu_muc_bat_buoc_bi_bao(du_an):
    r, ctx, root = du_an
    f = _viet(root, "f.md", "Một tài liệu không có gì cả.\n")
    kinds = {x["text"] for x in r.invoke("doc.style_check", {"doc_id": f},
                                         ctx).result["issues"] if x["kind"] == "format"}
    assert any("lịch sử" in x for x in kinds)
    assert any("Nguồn" in x for x in kinds)


def test_glossary_doc_tu_spec_khong_chep_tay():
    """Lần thứ tư gặp khuôn DEV-025/029/043/046 — nên lần này đặt tên literal trong
    `sec_dep_con.js` và sinh ra `doc/glossary.json` ngay từ đầu."""
    g = glossary()
    assert len(g) >= 30
    assert {"vi", "en", "nghia"} <= set(g[0])
    assert any(x["vi"] == "tác tử" and x["en"] == "agent" for x in g)


def test_nguong_tieng_anh_dung_gia_tri_hop_dong():
    assert NGUONG_TIENG_ANH == 0.10


def test_doc_la_bao_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("doc.style_check", {"doc_id": "khong_co.md"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- DOC-07 datasheet_summary


def test_moi_so_lieu_co_trang(du_an):
    """tc nguyên văn. Bản tóm tắt bị giới hạn bởi những gì đã trích được — nó SẼ THIẾU so với
    datasheet gốc, và điều đó đúng. Một bản tóm tắt đầy đủ hơn dữ liệu là bản có phần bịa."""
    r, ctx, root = du_an
    nap_fact(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 0x40005400, None, 47),
                    ("f_2", f"{CHIP}/param:VDD", "voltage_range", {"min": 1.7}, "V", 92)])
    p = r.invoke("doc.datasheet_summary", {"part": "st.stm32f411"}, ctx).result["path"]
    from pathlib import Path
    t = Path(p).read_text(encoding="utf-8")
    for dong in t.splitlines():
        if dong.startswith("- `"):
            assert "#p" in dong, f"dòng số liệu thiếu trang: {dong}"
    assert "#p47" in t and "#p92" in t


def test_noi_ro_la_khong_thay_the_datasheet_goc(du_an):
    r, ctx, root = du_an
    nap_fact(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, None, 5)])
    p = r.invoke("doc.datasheet_summary", {"part": "st.stm32f411"}, ctx).result["path"]
    from pathlib import Path
    assert "KHÔNG thay thế datasheet gốc" in Path(p).read_text(encoding="utf-8")


def test_loc_theo_scope(du_an):
    r, ctx, root = du_an
    nap_fact(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, None, 5),
                    ("f_2", f"{CHIP}/param:VDD", "voltage_range", {"min": 1.7}, "V", 9)])
    p = r.invoke("doc.datasheet_summary",
                 {"part": "st.stm32f411", "scope": ["electrical"]}, ctx).result["path"]
    from pathlib import Path
    t = Path(p).read_text(encoding="utf-8")
    assert "VDD" in t and "base_address" not in t


def test_chua_co_fact_thi_bao_E5002(du_an):
    r, ctx, _ = du_an
    run = r.invoke("doc.datasheet_summary", {"part": "chua.co"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_ghi_doc_artifact(du_an):
    r, ctx, root = du_an
    nap_fact(root, [("f_1", f"{CHIP}/periph:I2C1", "base_address", 1, None, 5)])
    r.invoke("doc.datasheet_summary", {"part": "st.stm32f411"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM doc_artifact WHERE type='datasheet_summary'"
                         ).fetchone()[0] == 1


# ---------- DOC-05 section


def test_neu_so_lieu_ma_khong_citations_thi_tu_choi(du_an, monkeypatch):
    """tc: "Có citations". Một mục tài liệu kỹ thuật không truy được nguồn thì người phản biện
    hỏi ngay câu đầu tiên."""
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"markdown": "Khối I2C1 chạy ở 400 kHz và dùng 2 chân.",
                           "citations": []})
    run = r.invoke("doc.section", {"target": "I2C1"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_cau_tra_loi_TRUNG_THUC_khong_du_lieu_thi_khong_bi_coi_la_loi(du_an, monkeypatch):
    """Một câu "chưa có dữ liệu trong ngữ cảnh" thì KHÔNG THỂ có trích dẫn.

    Đây là test sinh ra từ một lần gọi mô hình THẬT: hỏi về một module chưa có fact nào, mô
    hình trả lời đúng điều ta muốn — từ chối bịa — rồi bị E5002. Bắt nó phải có trích dẫn là
    dạy nó bịa cho đủ. Trích dẫn tồn tại để chống lưng cho KHẲNG ĐỊNH; không khẳng định gì thì
    không cần chống lưng.
    """
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {
        "markdown": "Chưa có dữ liệu về mô-đun này trong ngữ cảnh được cung cấp.",
        "citations": []})
    out = r.invoke("doc.section", {"target": "mod_la"}, ctx).result
    assert out["citations"] == []
    assert "Chưa có dữ liệu" in out["markdown"]


def test_co_citations_thi_tra_markdown(du_an, monkeypatch):
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"markdown": "Khối I2C1 nằm ở địa chỉ nền [f_1].",
                           "citations": ["f_1"]})
    out = r.invoke("doc.section", {"target": "I2C1"}, ctx).result
    assert out["citations"] == ["f_1"] and "I2C1" in out["markdown"]


def test_section_chay_style_check_tren_muc_vua_viet(du_an, monkeypatch):
    """Bước 1 nói "style_check mục". Dùng lại đúng một hiện thực thay vì viết bản kiểm thứ hai
    cho chuỗi trong bộ nhớ — hai bản kiểm cho cùng một quy tắc là hai bản sẽ lệch."""
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"markdown": "Bus chạy ở 400 kHz theo cấu hình hiện tại.",
                           "citations": ["f_1"]})
    run = r.invoke("doc.section", {"target": "I2C1"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"
    assert run.error["style_issues"][0]["kind"] == "uncited"


# ================================================================ khối C — chuỗi P7
#
# DIAGRAM-04 architecture · DIAGRAM-06 state · DOC-01 generate · DOC-07 embed_diagram.
# Bốn năng lực này khép chuỗi P7 "bộ tài liệu": req.trace_matrix → diagram.* → doc.generate →
# doc.embed_diagram → doc.style_check → report.


def nap_module(root, ds):
    from eide.caps.arch import _ghi_module
    _ghi_module(root, [{"interfaces": [], "depends": [], "status": "proposed", **d} for d in ds])


def nap_req(root, ds):
    with store.open_store(store.store_path(root)) as c:
        for rid, kind, txt, ưu, acc, tr in ds:
            c.execute("INSERT OR REPLACE INTO requirement (id, kind, text, priority, acceptance,"
                      " trace, source, status) VALUES (?,?,?,?,?,?,?,'generated')",
                      (rid, kind, txt, ưu, json.dumps(acc) if acc else None,
                       json.dumps(tr) if tr else None, "s_1"))
        c.commit()


# ---------- DIAGRAM-04 architecture

def test_kien_truc_muc_component_ve_tu_ModuleGraph(du_an):
    """Sinh từ ModuleGraph ĐÃ CÓ, không hỏi mô hình: `arch.decompose` đã kiểm hai bất biến rồi.
    Vẽ lại bằng mô hình là mở đường cho lược đồ nói khác thiết kế."""
    from eide.caps.diagram import architecture

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_hal", "name": "HAL I2C", "depends": []},
                      {"id": "mod_drv", "name": "Driver BME280", "depends": ["mod_hal"]},
                      {"id": "mod_app", "name": "App", "depends": ["mod_drv"]}])
    dg = architecture({"level": "component"}, ctx)["diagram"]
    assert dg["lang"] == "mermaid" and dg["model_ref"] == "module"
    assert set(dg["nodes"]) == {"mod_hal", "mod_drv", "mod_app"}
    assert {(e["from"], e["to"]) for e in dg["edges"]} == {("mod_drv", "mod_hal"),
                                                          ("mod_app", "mod_drv")}
    assert "flowchart" in dg["src"] and "Driver BME280" in dg["src"]


def test_kien_truc_node_ids_la_ID_khong_phai_TEN(du_an):
    """Bước 1: `node_ids = module id để sync`. Lấy tên làm id thì đổi tên một module sẽ làm mọi
    lược đồ cũ thành không đối chiếu được."""
    from eide.caps.diagram import architecture

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_a", "name": "Tên Có Dấu Và Khoảng Trắng", "depends": []}])
    dg = architecture({}, ctx)["diagram"]
    assert dg["nodes"] == ["mod_a"]


def test_kien_truc_chua_co_module_thi_bao_ro(du_an):
    from eide.caps.diagram import architecture
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        architecture({"level": "component"}, ctx)
    assert e.value.code == "E2000" and "arch.decompose" in str(e.value)


def test_kien_truc_muc_context_lay_tu_constraints(du_an):
    """Mức context C4: hệ thống, chip, board, người — từ `constraints.yaml`, không bịa tên."""
    from eide.caps.diagram import architecture

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    dg = architecture({"level": "context"}, ctx)["diagram"]
    assert "chip" in dg["nodes"] and "nguoi" in dg["nodes"]
    assert "STM32F411RE" in dg["src"]


def test_lop_kien_truc_SONG_QUA_mot_vong_ghi_doc(du_an):
    """DEV-069, DDD-14 v1.3. Trước migration 0005, `layer` được tính, được dùng để kiểm bất biến
    "phụ thuộc chỉ đi xuống lớp dưới", rồi MẤT lúc ghi — nên bất biến ấy chỉ kiểm được đúng một
    lần và mọi năng lực đọc ModuleGraph lại từ store đều không dựng được gì theo lớp."""
    from eide.caps.arch import _doc_module

    _, _, root = du_an
    nap_module(root, [{"id": "mod_h", "name": "HAL", "layer": "hal", "depends": []}])
    assert _doc_module(root)[0]["layer"] == "hal"


def test_kien_truc_muc_container_gom_theo_LOP(du_an):
    """Mức container của C4 trong firmware là các LỚP, không phải tiến trình hay dịch vụ."""
    from eide.caps.diagram import architecture

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_h", "name": "HAL", "layer": "hal", "depends": []},
                      {"id": "mod_d", "name": "Driver", "layer": "driver", "depends": ["mod_h"]},
                      {"id": "mod_d2", "name": "Driver 2", "layer": "driver", "depends": ["mod_h"]},
                      {"id": "mod_a", "name": "App", "layer": "app", "depends": ["mod_d"]}])
    dg = architecture({"level": "container"}, ctx)["diagram"]
    assert dg["nodes"] == ["hal", "driver", "app"], "chỉ lớp CÓ module, và đúng thứ tự lớp"
    assert "driver\\n2 module" in dg["src"]


def test_canh_NGUOC_LOP_bi_danh_dau_chu_khong_bi_giau(du_an):
    """Lược đồ giấu một vi phạm là lược đồ nói dối, và đây là chỗ duy nhất người đọc còn có cơ
    hội thấy nó — `arch.decompose` chỉ kiểm được lúc phân rã."""
    from eide.caps.diagram import architecture

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_h", "name": "HAL", "layer": "hal", "depends": ["mod_a"]},
                      {"id": "mod_a", "name": "App", "layer": "app", "depends": []}])
    dg = architecture({"level": "component"}, ctx)["diagram"]
    nguoc = [e for e in dg["edges"] if e["label"]]
    assert len(nguoc) == 1 and nguoc[0]["from"] == "mod_h" and "ngược lớp" in nguoc[0]["label"]


def test_khong_module_nao_co_lop_thi_noi_thang(du_an):
    """`layer` NULL nghĩa là "chưa biết" — migration 0005 cố ý không suy ngược cho dữ liệu cũ.
    Gộp bừa mọi module vào `service` còn tệ hơn không có sơ đồ, vì nó TRÔNG ĐÚNG."""
    from eide.caps.diagram import architecture
    from eide_core.errors import EideError

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_a", "name": "A", "depends": []}])
    with pytest.raises(EideError) as e:
        architecture({"level": "container"}, ctx)
    assert e.value.code == "E2000" and e.value.data["missing"] == ["module.layer"]
    assert "arch.decompose" in str(e.value)


def test_kien_truc_ba_ngon_ngu_cung_mot_do_thi(du_an):
    """Một hàm dựng mã cho cả ba ngôn ngữ. Ba bản sao thì sửa hình dạng nút ở một chỗ và hai
    chỗ kia lặng lẽ khác đi."""
    from eide.caps.diagram import architecture

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_a", "name": "A", "depends": []},
                      {"id": "mod_b", "name": "B", "depends": ["mod_a"]}])
    ra = {lg: architecture({"lang": lg}, ctx)["diagram"]["src"] for lg in
          ("mermaid", "plantuml", "d2")}
    assert "flowchart" in ra["mermaid"] and "@startuml" in ra["plantuml"]
    for src in ra.values():
        assert "mod_a" in src and "mod_b" in src


# ---------- DIAGRAM-06 state

FSM = {"states": ["IDLE", "DO", "LOI"], "events": ["bat", "xong", "hong"], "initial": "IDLE",
       "transitions": [
           {"from": "IDLE", "event": "bat", "to": "DO", "guard": "nguon_on", "action": "khoi_dong"},
           {"from": "IDLE", "event": "xong", "ignore": True},
           {"from": "IDLE", "event": "hong", "to": "LOI"},
           {"from": "DO", "event": "xong", "to": "IDLE"},
           {"from": "DO", "event": "bat", "ignore": True},
           {"from": "DO", "event": "hong", "to": "LOI"},
           {"from": "LOI", "event": "bat", "to": "IDLE"},
           {"from": "LOI", "event": "xong", "ignore": True},
           {"from": "LOI", "event": "hong", "ignore": True}]}


def test_TC73_so_do_trang_thai_tu_module_fsm(du_an):
    """tc TC-73. Vẽ từ `module.fsm` — cùng cấu trúc `arch.state_machine` đã kiểm đầy đủ, nên
    lược đồ này là một CÁCH ĐỌC của máy trạng thái, không phải bản vẽ song song."""
    from eide.caps.diagram import state

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_m", "name": "Motor", "fsm": FSM}])
    dg = state({"module_id": "mod_m"}, ctx)["diagram"]
    assert dg["nodes"] == ["IDLE", "DO", "LOI"] and dg["initial"] == "IDLE"
    assert "stateDiagram-v2" in dg["src"] and "[*] --> IDLE" in dg["src"]
    assert "IDLE --> DO : bat [nguon_on] / khoi_dong" in dg["src"]
    assert len(dg["edges"]) == 5, "chỉ chuyển THẬT thành cạnh"


def test_su_kien_bo_qua_thanh_GHI_CHU_khong_thanh_canh(du_an):
    """ARCH-07 buộc khai cả cặp `ignore`. Vẽ hết thành cạnh tự-lặp thì lược đồ đặc kín; bỏ hẳn
    thì mất một QUYẾT ĐỊNH — "đã nghĩ tới rồi" khác "quên mất"."""
    from eide.caps.diagram import state

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_m", "name": "Motor", "fsm": FSM}])
    dg = state({"module_id": "mod_m"}, ctx)["diagram"]
    assert dg["ignored"] == {"IDLE": ["xong"], "DO": ["bat"], "LOI": ["xong", "hong"]}
    assert "note right of LOI" in dg["src"] and "bỏ qua: hong, xong" in dg["src"]
    assert "LOI --> LOI" not in dg["src"]


def test_trang_thai_plantuml_cung_mot_noi_dung(du_an):
    from eide.caps.diagram import state

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_m", "name": "Motor", "fsm": FSM}])
    src = state({"module_id": "mod_m", "lang": "plantuml"}, ctx)["diagram"]["src"]
    assert src.startswith("@startuml") and src.rstrip().endswith("@enduml")
    assert "IDLE --> DO : bat [nguon_on] / khoi_dong" in src and "note right of LOI" in src


def test_module_chua_co_fsm_thi_chi_sang_arch_state_machine(du_an):
    from eide.caps.diagram import state
    from eide_core.errors import EideError

    _, ctx, root = du_an
    nap_module(root, [{"id": "mod_m", "name": "Motor"}])
    with pytest.raises(EideError) as e:
        state({"module_id": "mod_m"}, ctx)
    assert e.value.code == "E2000" and "arch.state_machine" in str(e.value)


# ---------- DIAGRAM-03 pinmap
#
# tc: "PB6→SCL BME280 đúng". Bước 1: "Từ HwMap + BoardPassport: bảng chân (MCU pin, AF, net,
# linh kiện, hướng); SVG chip outline (package từ fact) với nhãn chân; xung đột tô đỏ".
#
# Bảng chân là chỗ người ta cầm đi hàn. Một dòng sai ở đây tốn một buổi dò mạch, nên mọi ô đều
# phải truy được về một fact — chân nào không tra được thì để trống, không đoán.

BOARD = "robot-main"


def nap_net(root, board, nets):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('s_net','robot.net','h_net','netlist','gold')")
        for i, (ten, nodes) in enumerate(nets.items()):
            c.execute("INSERT OR REPLACE INTO fact (id, subject, predicate, value, source_id,"
                      " method, tier, confidence, status)"
                      " VALUES (?,?,?,?,'s_net','parser','gold',1.0,'verified')",
                      (f"f_net_{i}", f"board:{board}/net:{ten}", "net",
                       json.dumps({"name": ten, "nodes": nodes})))
        c.commit()


def nap_part(root, board, parts):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('s_net','robot.net','h_net','netlist','gold')")
        for ref, v in parts.items():
            c.execute("INSERT OR REPLACE INTO fact (id, subject, predicate, value, source_id,"
                      " method, tier, confidence, status)"
                      " VALUES (?,?,?,?,'s_net','parser','gold',1.0,'verified')",
                      (f"f_part_{ref}", f"board:{board}/part:{ref}", "package", json.dumps(v)))
        c.commit()


def nap_pin_function(root, bang):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('s_pin','ds/stm32f411.pdf','h_pin','pdf_vendor','gold')")
        for chan, fs in bang.items():
            c.execute("INSERT OR REPLACE INTO fact (id, subject, predicate, value, source_id,"
                      " method, tier, confidence, status)"
                      " VALUES (?,?,?,?,'s_pin','parser','gold',1.0,'verified')",
                      (f"f_pin_{chan}", f"chip:stm32f411/pin:{chan}", "pin_function",
                       json.dumps({"pin": chan, "functions": fs})))
        c.commit()


def _board_day_du(du_an):
    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411CEU6"}, ctx)
    nap_net(root, BOARD, {
        "/I2C1_SCL": [{"ref": "U1", "pin": "42"}, {"ref": "U2", "pin": "4"},
                      {"ref": "R1", "pin": "1"}],
        "/I2C1_SDA": [{"ref": "U1", "pin": "43"}, {"ref": "U2", "pin": "6"},
                      {"ref": "R2", "pin": "1"}],
        "GND": [{"ref": "U2", "pin": "5"}]})
    nap_part(root, BOARD, {"U1": {"ref": "U1", "value": "STM32F411CEU6", "mpn": "STM32F411CEU6",
                                  "footprint": "Package_QFP:LQFP-48"},
                           "U2": {"ref": "U2", "value": "BME280", "mpn": "BME280",
                                  "footprint": "Sensor:LGA-8"},
                           "R1": {"ref": "R1", "value": "4k7"},
                           "R2": {"ref": "R2", "value": "4k7"}})
    nap_pin_function(root, {"PB6": ["I2C1_SCL", "TIM4_CH1"], "PB7": ["I2C1_SDA", "TIM4_CH2"]})


def test_TC_PB6_SCL_BME280_dung(du_an):
    """tc DIAGRAM-03, nguyên văn. Ba mảnh dữ liệu ở ba chỗ khác nhau — net từ netlist, tên chân
    từ hộ chiếu chip, tên linh kiện từ fact `package` — và giá trị của bảng này nằm đúng ở chỗ
    nối được cả ba lại."""
    r, ctx, root = du_an
    _board_day_du(du_an)
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result

    scl = next(x for x in out["table"] if x["af"] == "I2C1_SCL")
    assert scl["pin"] == "PB6"
    assert scl["net"] == "/I2C1_SCL"
    assert "BME280" in scl["part"]
    assert scl["fact_ids"], "mỗi dòng phải truy được về fact"


def test_chan_khong_tra_duoc_ten_thi_DE_TRONG_chu_khong_doan(du_an):
    """Không có hộ chiếu chân thì không biết chân 42 tên là gì. Bảng vẫn có dòng — kết nối là
    thật — nhưng ô `pin` ghi số chân vật lý và `af` để trống. Đoán một tên chân ở đây là làm
    người ta hàn nhầm."""
    r, ctx, root = du_an
    _board_day_du(du_an)
    with store.open_store(store.store_path(root)) as c:
        c.execute("DELETE FROM fact WHERE predicate='pin_function'")
        c.commit()
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result

    scl = next(x for x in out["table"] if x["net"] == "/I2C1_SCL")
    assert scl["pin"] == "U1.42" and scl["af"] == ""


def test_net_nguon_va_dat_khong_vao_bang_chan_tin_hieu(du_an):
    """`GND` không phải một chân chức năng — để nó lẫn vào bảng thì bảng dài gấp đôi mà không
    thêm thông tin nào, và người đọc mất chỗ cần nhìn."""
    r, ctx, root = du_an
    _board_day_du(du_an)
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result

    assert "GND" not in [x["net"] for x in out["table"]]


def test_huong_suy_tu_VAI_TRO_trong_HwMap_khong_tu_ten_tin_hieu(du_an):
    """SCL do bên CHỦ phát; MCU là chủ hay tớ thì `hw_map.role` mới biết. Suy hướng chỉ từ tên
    tín hiệu là đúng trong đa số thiết kế và sai lặng lẽ trong số còn lại."""
    r, ctx, root = du_an
    _board_day_du(du_an)
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result
    assert all(x["dir"] == "" for x in out["table"]), "chưa có HwMap mà đã dám nói hướng"

    nap_module(root, [{"id": "mod_i2c", "name": "i2c_bus", "depends": []}])
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO hw_map (module_id, resource, role, fact_ids)"
                  " VALUES ('mod_i2c','chip:stm32f411/periph:I2C1','master',?)",
                  (json.dumps(["f_pin_PB6"]),))
        c.commit()
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result

    scl = next(x for x in out["table"] if x["af"] == "I2C1_SCL")
    assert scl["dir"] == "ra" and scl["module"] == "mod_i2c"
    sda = next(x for x in out["table"] if x["af"] == "I2C1_SDA")
    assert sda["dir"] == "hai chiều", "SDA hai chiều kể cả khi MCU là chủ"


def test_xung_dot_TO_DO_chu_khong_bi_bo(du_an):
    """"xung đột tô đỏ" của bước 1 — và xung đột lấy từ chính `board.check_pins`, không viết
    một phép kiểm thứ hai: hai phép kiểm cùng một việc sẽ nói khác nhau đúng lúc quan trọng."""
    r, ctx, root = du_an
    _board_day_du(du_an)
    nap_net(root, BOARD, {"/I2C1_SCL": [{"ref": "U1", "pin": "42"}, {"ref": "U2", "pin": "4"}],
                          "/LED": [{"ref": "U1", "pin": "42"}]})
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result

    xd = [x for x in out["table"] if x["conflict"]]
    assert xd, "chân 42 nằm trên hai net mà bảng không đánh dấu"
    assert "red" in out["diagram"]["src"]


def test_luoc_do_la_SVG_va_qua_duoc_lint(du_an):
    """CON-28 §6: lược đồ là văn bản. SVG *là* văn bản — nó vào git dưới dạng khác biệt đọc
    được và `diagram.lint` kiểm được — nên "SVG chip outline" của bước 1 không mâu thuẫn với
    bất biến của nhóm."""
    from eide.caps.diagram import lint

    r, ctx, root = du_an
    _board_day_du(du_an)
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result

    assert out["diagram"]["lang"] == "svg"
    assert out["diagram"]["src"].lstrip().startswith("<svg")
    assert "PB6" in out["diagram"]["src"] and "BME280" in out["diagram"]["src"]
    assert lint({"src": out["diagram"]["src"], "lang": "svg"}, ctx)["issues"] == []


def test_package_tu_FACT_chu_khong_mac_dinh(du_an):
    """"package từ fact" của bước 1: số chân của hình vẽ lấy từ footprint đã trích, không phải
    một hình 48 chân vẽ sẵn cho mọi chip."""
    r, ctx, root = du_an
    _board_day_du(du_an)
    out = r.invoke("diagram.pinmap", {"board": BOARD}, ctx).result
    assert "LQFP-48" in out["diagram"]["src"]


def test_chua_co_board_nao_thi_bao_E2000(du_an):
    """Vẽ bản đồ chân của một board chưa có netlist là vẽ từ hư không."""
    r, ctx, _ = du_an
    run = r.invoke("diagram.pinmap", {"board": "khong-co"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert "extract.kicad_netlist" in str(run.error)


# ---------- DIAGRAM-09 memory_map
#
# tc: "Vùng đúng địa chỉ". Bước 1: "Bản đồ bộ nhớ từ fact memory_size/base_address; vùng linker
# (.text/.data/.bss) từ .map (code.size); SVG có tỷ lệ".

HO_CHIEU = "stm32f411"

MAP_FILE = """\
Memory Configuration

Linker script and memory map

.text           0x0000000008000000     0x1a2c
 *(.text*)
 .text.i2c_init
                0x0000000008000180       0x9c build/i2c.c.obj
.data           0x0000000020000000       0x10
.bss            0x0000000020000010      0x400
"""


def nap_bo_nho(root, vung):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('s_mem','ds/stm32f411.pdf','h_mem','pdf_vendor','gold')")
        for i, (ten, kich, don_vi, goc) in enumerate(vung):
            c.execute("INSERT OR REPLACE INTO fact (id, subject, predicate, value, unit,"
                      " source_id, method, tier, confidence, status)"
                      " VALUES (?,?,?,?,?,'s_mem','parser','gold',1.0,'verified')",
                      (f"f_mem_{i}", f"chip:{HO_CHIEU}/{ten}", "memory_size",
                       json.dumps(kich), don_vi))
            if goc:
                c.execute("INSERT OR REPLACE INTO fact (id, subject, predicate, value,"
                          " source_id, method, tier, confidence, status)"
                          " VALUES (?,?,?,?,'s_mem','parser','gold',1.0,'verified')",
                          (f"f_goc_{i}", f"chip:{HO_CHIEU}/{ten}", "base_address",
                           json.dumps(goc)))
        c.commit()


# `KiB`, không phải `kB`: bảng đơn vị của kho (`req.DON_VI`) đọc `kb` là 1000 byte. Một hộ
# chiếu ghi "512 kB" cho 512 KiB lệch 12 kB — đủ để một firmware vừa khít báo là vừa khít.
CHIP_512K = [("flash", 512, "KiB", "0x08000000"), ("ram", 128, "KiB", "0x20000000")]


def test_TC_vung_dung_dia_chi(du_an):
    """tc DIAGRAM-09, nguyên văn. Một bản đồ bộ nhớ sai địa chỉ gốc thì mọi thứ vẽ trên nó đều
    sai, mà nhìn thì không thấy — các hình chữ nhật vẫn xếp đẹp."""
    r, ctx, root = du_an
    nap_bo_nho(root, CHIP_512K)
    dg = r.invoke("diagram.memory_map", {"passport": HO_CHIEU}, ctx).result["diagram"]

    flash = next(v for v in dg["regions"] if v["name"] == "flash")
    assert flash["base"] == 0x08000000 and flash["size"] == 512 * 1024
    ram = next(v for v in dg["regions"] if v["name"] == "ram")
    assert ram["base"] == 0x20000000 and ram["size"] == 128 * 1024
    assert "0x08000000" in dg["src"] and "0x20000000" in dg["src"]


def test_moi_vung_truy_duoc_ve_fact(du_an):
    """grounding của hợp đồng là "Hộ chiếu": mỗi vùng phải chỉ được ra fact đã dựng nó."""
    r, ctx, root = du_an
    nap_bo_nho(root, CHIP_512K)
    dg = r.invoke("diagram.memory_map", {"passport": HO_CHIEU}, ctx).result["diagram"]
    assert all(v["fact_ids"] for v in dg["regions"])


def test_SVG_co_TY_LE_that(du_an):
    """"SVG có tỷ lệ" của bước 1. Vẽ flash 512 kB và ram 128 kB bằng nhau là biến một bản đồ
    thành một bảng — mà cái người ta nhìn bản đồ để thấy chính là "còn bao nhiêu chỗ"."""
    r, ctx, root = du_an
    nap_bo_nho(root, CHIP_512K)
    dg = r.invoke("diagram.memory_map", {"passport": HO_CHIEU}, ctx).result["diagram"]

    cao = {v["name"]: v["px"] for v in dg["regions"]}
    assert cao["flash"] == pytest.approx(cao["ram"] * 4, rel=0.05)


def test_vung_linker_dat_dung_vung_theo_DIA_CHI(du_an):
    """`.text` ở `0x08000000` thuộc flash, `.bss` ở `0x20000010` thuộc ram — xếp theo ĐỊA CHỈ
    chứ không theo tên quy ước, vì `.data` nằm ở cả hai nơi tùy chip."""
    r, ctx, root = du_an
    nap_bo_nho(root, CHIP_512K)
    (root / "build").mkdir(parents=True, exist_ok=True)
    (root / "build" / "fw.map").write_text(MAP_FILE, encoding="utf-8")
    dg = r.invoke("diagram.memory_map",
                  {"passport": HO_CHIEU, "linker": "build/fw.map"}, ctx).result["diagram"]

    theo = {s["name"]: s for s in dg["sections"]}
    assert theo[".text"]["region"] == "flash" and theo[".text"]["size"] == 0x1A2C
    assert theo[".bss"]["region"] == "ram" and theo[".bss"]["base"] == 0x20000010
    assert ".text" in dg["src"]


def test_vung_linker_ngoai_moi_vung_thi_NOI_RA(du_an):
    """Một section ở địa chỉ không thuộc vùng nào là dấu hiệu linker script sai hoặc hộ chiếu
    thiếu vùng. Bỏ nó đi thì bản đồ trông đầy đủ trong khi có một mảnh không biết nằm đâu."""
    r, ctx, root = du_an
    nap_bo_nho(root, [("flash", 512, "kB", "0x08000000")])
    (root / "build").mkdir(parents=True, exist_ok=True)
    (root / "build" / "fw.map").write_text(MAP_FILE, encoding="utf-8")
    dg = r.invoke("diagram.memory_map",
                  {"passport": HO_CHIEU, "linker": "build/fw.map"}, ctx).result["diagram"]

    lac = [s for s in dg["sections"] if not s["region"]]
    assert {s["name"] for s in lac} == {".data", ".bss"}
    assert "ngoài mọi vùng" in dg["src"]


def test_khong_co_map_thi_van_ve_ban_do_chip(du_an):
    """`linker` là tùy chọn. Chưa dựng lần nào thì bản đồ chip vẫn có ích — nó trả lời "chip này
    có bao nhiêu chỗ", câu hỏi đứng trước "đã dùng bao nhiêu"."""
    r, ctx, root = du_an
    nap_bo_nho(root, CHIP_512K)
    dg = r.invoke("diagram.memory_map", {"passport": HO_CHIEU}, ctx).result["diagram"]

    assert dg["sections"] == [] and len(dg["regions"]) == 2
    assert "chưa có" in dg["src"]


def test_chua_co_fact_bo_nho_thi_E2000(du_an):
    """Không có `memory_size` thì không có bản đồ nào để vẽ — và nói ra tên năng lực cần chạy
    thì người dùng đi tiếp được ngay."""
    r, ctx, _ = du_an
    run = r.invoke("diagram.memory_map", {"passport": "khong-co"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert "extract.svd" in str(run.error)


def test_memory_map_qua_duoc_lint(du_an):
    from eide.caps.diagram import lint

    r, ctx, root = du_an
    nap_bo_nho(root, CHIP_512K)
    dg = r.invoke("diagram.memory_map", {"passport": HO_CHIEU}, ctx).result["diagram"]
    assert dg["lang"] == "svg"
    assert lint({"src": dg["src"], "lang": "svg"}, ctx)["issues"] == []


# ---------- DOC-01 generate

VAN = {"markdown": "Mục này mô tả phạm vi và cách đọc bảng bên dưới.", "citations": ["f_1"]}


def test_TC75_sinh_SRS_co_thuoc_tinh_lich_su_va_muc_Nguon(du_an, monkeypatch):
    """tc TC-75. Bước 2 đòi "thuộc tính, lịch sử, bảng, hình đánh số, mục Nguồn" — và mục Nguồn
    là mục người phản biện đọc đầu tiên."""
    from eide.caps.doc import generate

    _, ctx, root = du_an
    _gia_lap(monkeypatch, VAN)
    nap_fact(root, [("f_1", CHIP, "base_address", "0x40005400", None, 12)])
    nap_req(root, [("FR-01", "FR", "Đọc nhiệt độ mỗi giây", "M", ["đọc được 10 lần liên tiếp"],
                    ["UR-TT-01"])])
    out = generate({"type": "SRS"}, ctx)
    md = __import__("pathlib").Path(out["path"]).read_text(encoding="utf-8")

    assert out["doc_id"].startswith("doc_") and isinstance(out["style_issues"], int)
    assert "| Thuộc tính | Giá trị |" in md
    assert "## Lịch sử sửa đổi" in md
    assert "## Nguồn" in md
    for tieu_de in ("3. Yêu cầu chức năng", "7. Ma trận truy vết UR → FR"):
        assert f"## {tieu_de}" in md, tieu_de
    assert "FR-01" in md and "Đọc nhiệt độ mỗi giây" in md


def test_bang_so_lieu_do_MA_dung_khong_phai_mo_hinh(du_an, monkeypatch):
    """Ranh giới của cả năng lực: mô hình viết văn xuôi, MÃ dựng bảng. Ở đây mô hình trả về một
    con số SAI hẳn; nó phải không lọt vào bảng."""
    from eide.caps.doc import generate

    _, ctx, root = du_an
    _gia_lap(monkeypatch, {"markdown": "Giá trị là 0xDEADBEEF theo tôi nhớ.", "citations": ["f_1"]})
    nap_req(root, [("FR-01", "FR", "Đọc nhiệt độ", "M", None, None)])
    md = __import__("pathlib").Path(generate({"type": "SRS"}, ctx)["path"]).read_text(encoding="utf-8")

    bang = [d for d in md.splitlines() if d.startswith("| FR-01")]
    assert bang and "0xDEADBEEF" not in bang[0], "số của mô hình lọt vào bảng số liệu"


def test_muc_khong_co_du_lieu_thi_NOI_LA_CHUA_CO(du_an, monkeypatch):
    """Một tài liệu đầy đủ hơn dữ liệu là một tài liệu có phần bịa, mà người đọc không phân biệt
    được phần nào. Mục rỗng KHÔNG gọi mô hình."""
    from eide.caps.doc import generate

    _, ctx, root = du_an
    goi: list[int] = []

    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def run(self, *a, **k):
            goi.append(1)
            return _R(VAN)

    import eide.caps.doc as m
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())
    nap_req(root, [("FR-01", "FR", "Đọc nhiệt độ", "M", None, None)])
    md = __import__("pathlib").Path(generate({"type": "SRS"}, ctx)["path"]).read_text(encoding="utf-8")

    assert "Chưa có dữ liệu cho mục này" in md
    assert "arch.map_hw" in md, "phải nêu năng lực cần chạy để có dữ liệu"
    from eide.caps.doc import outlines
    n_muc = len(outlines()["SRS"]["sections"])
    assert len(goi) < n_muc, f"gọi mô hình {len(goi)}/{n_muc} lần — mục rỗng không được gọi"


def test_thieu_fact_BAT_BUOC_thi_E3000_chu_khong_sinh_tai_lieu_rong(du_an, monkeypatch):
    """`ask_when` của DOC-01: "Thiếu fact bắt buộc". Một SRS không có yêu cầu chức năng nào
    không phải SRS mỏng, nó là SRS rỗng — sinh rồi nộp đi là cách tệ nhất để phát hiện."""
    from eide.caps.doc import generate
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    _gia_lap(monkeypatch, VAN)
    with pytest.raises(EideError) as e:
        generate({"type": "SRS"}, ctx)
    assert e.value.code == "E3000" and e.value.data["missing"] == ["req:FR"]
    assert "req.elicit" in str(e.value)


def test_moi_loai_tai_lieu_dung_mot_muc_luc_khac_nhau(du_an, monkeypatch):
    """Mục lục lấy đúng đề mục H1 của chính bộ hồ sơ EIDE (DEV-070) — mỗi loại một bộ khác."""
    from eide.caps.doc import generate, outlines

    _, ctx, root = du_an
    _gia_lap(monkeypatch, VAN)
    nap_module(root, [{"id": "mod_a", "name": "A", "depends": []}])
    nap_req(root, [("UR-01", "UR", "Kỹ sư muốn đọc nhiệt độ", "M", None, None)])
    for loai in ("URD", "SAD", "SDD"):
        md = __import__("pathlib").Path(
            generate({"type": loai}, ctx)["path"]).read_text(encoding="utf-8")
        for s in outlines()[loai]["sections"]:
            assert f"## {s['heading']}" in md, f"{loai} thiếu {s['heading']}"
    # và ba loại phải KHÁC nhau — một mục lục dùng chung thì bảng nguồn là thừa
    assert len({tuple(s["heading"] for s in outlines()[x]["sections"])
                for x in ("URD", "SAD", "SDD")}) == 3


def test_bringup_va_test_report_uy_quyen_cho_nang_luc_rieng(du_an, monkeypatch):
    """Sinh lại lần thứ hai ở đây là hai bản tài liệu cùng tên khác nội dung."""
    from eide.caps.doc import generate
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    _gia_lap(monkeypatch, VAN)
    with pytest.raises(EideError) as e:
        generate({"type": "bringup"}, ctx)
    assert e.value.data["candidates"] == ["doc.bringup_guide"]


def test_style_check_chay_va_dem_duoc_ghi_vao_DocArtifact(du_an, monkeypatch):
    """Bước 2: "doc.style_check; lưu DocArtifact". Đếm phải khớp giữa kết quả trả về và store."""
    from eide.caps.doc import generate

    _, ctx, root = du_an
    _gia_lap(monkeypatch, VAN)
    nap_req(root, [("FR-01", "FR", "Đọc nhiệt độ", "M", None, None)])
    out = generate({"type": "SRS"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        r = c.execute("SELECT type, sections, citations, style_issues FROM doc_artifact"
                      " WHERE id=?", (out["doc_id"],)).fetchone()
    assert r[0] == "SRS"
    from eide.caps.doc import outlines
    assert len(json.loads(r[1])) == len(outlines()["SRS"]["sections"]), \
        "mỗi mục một bản ghi sections"
    assert len(json.loads(r[3])) == out["style_issues"]


def test_sinh_lai_cung_tai_lieu_cho_cung_doc_id(du_an, monkeypatch):
    """Id băm từ ĐƯỜNG DẪN: sinh lại phải cho cùng id, nếu không thì hình đã chèn thành mồ côi."""
    from eide.caps.doc import generate

    _, ctx, root = du_an
    _gia_lap(monkeypatch, VAN)
    nap_req(root, [("FR-01", "FR", "Đọc nhiệt độ", "M", None, None)])
    assert generate({"type": "SRS"}, ctx)["doc_id"] == generate({"type": "SRS"}, ctx)["doc_id"]


# ---------- DOC-07 embed_diagram

def _tai_lieu(du_an, monkeypatch):
    from eide.caps.doc import generate
    _, ctx, root = du_an
    _gia_lap(monkeypatch, VAN)
    nap_req(root, [("FR-01", "FR", "Đọc nhiệt độ", "M", None, None)])
    return generate({"type": "SRS"}, ctx), ctx, root


def _luu_diagram(root, did="dg_1", stale=0):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO diagram (id, kind, lang, src, stale, at)"
                  " VALUES (?,?,?,?,?,?)",
                  (did, "architecture", "mermaid", "flowchart LR\n  a --> b\n", stale,
                   "2026-09-08T00:00:00Z"))
        c.commit()


def test_tc_danh_so_hinh_LIEN_TUC(du_an, monkeypatch):
    """tc của DOC-07, nguyên văn: **"Đánh số liên tục"**. Số đọc từ CHÍNH tài liệu, nên nó không
    lệch được kể cả khi tài liệu bị sửa tay hay sinh lại (DEV-071)."""
    from eide.caps.doc import embed_diagram

    out, ctx, root = _tai_lieu(du_an, monkeypatch)
    _luu_diagram(root)
    so = [embed_diagram({"doc_id": out["doc_id"], "diagram_id": "dg_1",
                         "caption": f"Hình thứ {i}"}, ctx)["figure_no"] for i in range(1, 4)]
    assert so == [1, 2, 3]
    md = __import__("pathlib").Path(out["path"]).read_text(encoding="utf-8")
    assert md.count("**Hình 1.**") == 1 and "**Hình 3.** Hình thứ 3" in md


def test_thieu_bo_dung_thi_chen_MA_LUOC_DO_chu_khong_bo_hinh(du_an, monkeypatch):
    """CON-28 §6: lược đồ là "sơ đồ ở dạng ngôn ngữ văn bản"; ảnh chỉ là sản phẩm phụ dựng lại
    được. Bỏ hình vì máy chưa cài `mmdc` là để một chi tiết cài đặt quyết định nội dung."""
    from eide.caps.doc import embed_diagram

    out, ctx, root = _tai_lieu(du_an, monkeypatch)
    _luu_diagram(root)
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    n = embed_diagram({"doc_id": out["doc_id"], "diagram_id": "dg_1",
                       "caption": "Kiến trúc firmware"}, ctx)["figure_no"]
    md = __import__("pathlib").Path(out["path"]).read_text(encoding="utf-8")
    assert n == 1 and "```mermaid" in md and "flowchart LR" in md
    assert "**Hình 1.** Kiến trúc firmware" in md


def test_luoc_do_cu_thi_gan_NHAN_chu_khong_tu_choi_chen(du_an, monkeypatch):
    """Một hình cũ vẫn nói được phần lớn sự thật; một tài liệu thiếu hình thì mất hẳn một cách
    hiểu. Nhưng nó phải nói ra là mình cũ."""
    from eide.caps.doc import embed_diagram

    out, ctx, root = _tai_lieu(du_an, monkeypatch)
    _luu_diagram(root, stale=1)
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    embed_diagram({"doc_id": out["doc_id"], "diagram_id": "dg_1", "caption": "Kiến trúc"}, ctx)
    md = __import__("pathlib").Path(out["path"]).read_text(encoding="utf-8")
    assert "lược đồ đã cũ" in md and "diagram.sync" in md


def test_chen_TRUOC_de_muc_ke_tiep(du_an, monkeypatch):
    """Chèn ngay sau dòng tiêu đề thì hình đẩy đoạn mở đầu xuống dưới, và người đọc gặp hình
    trước khi biết nó vẽ cái gì."""
    from eide.caps.doc import embed_diagram

    out, ctx, root = _tai_lieu(du_an, monkeypatch)
    _luu_diagram(root)
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    embed_diagram({"doc_id": out["doc_id"], "diagram_id": "dg_1", "caption": "Sơ đồ",
                   "after_heading": "3. Yêu cầu chức năng"}, ctx)
    dong = __import__("pathlib").Path(out["path"]).read_text(encoding="utf-8").splitlines()
    i_muc3 = dong.index("## 3. Yêu cầu chức năng")
    i_hinh = next(i for i, d in enumerate(dong) if d.startswith("**Hình 1."))
    i_muc4 = dong.index("## 4. Yêu cầu phi chức năng")
    assert i_muc3 < i_hinh < i_muc4


def test_luoc_do_khong_co_thi_bao_ro(du_an, monkeypatch):
    from eide.caps.doc import embed_diagram
    from eide_core.errors import EideError

    out, ctx, _ = _tai_lieu(du_an, monkeypatch)
    with pytest.raises(EideError) as e:
        embed_diagram({"doc_id": out["doc_id"], "diagram_id": "khong-co", "caption": "x"}, ctx)
    assert e.value.code == "E2000"


# ================================================================ DOC-03 api_ref
#
# tc: "Mọi hàm public có mục"; lỗi E4001; undo `delete_created_files`.
#
# Bất biến của cả nhóm lặp lại ở đây dưới dạng thứ ba: chữ ký đọc từ MÃ NGUỒN, mô hình chỉ
# thêm ví dụ dùng — và ví dụ có số liệu kỹ thuật mà không neo được vào fact nào thì bị bỏ.

HEADER = """\
/**
 * @file bme280.h
 * @brief Trình điều khiển cảm biến BME280.
 */
#ifndef BME280_H
#define BME280_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BME280_ADDR_MAX 0x77

/**
 * @brief Khởi tạo cảm biến qua I2C.
 * @param addr Địa chỉ I2C 7 bit.
 * @return 0 nếu thành công, âm nếu lỗi bus.
 */
int bme280_init(uint8_t addr);

/** @brief Đọc nhiệt độ đã bù.
 *  @param out Nơi ghi kết quả, đơn vị 0.01 độ C.
 *  @retval -1 lỗi bus.
 */
int bme280_read_temp(int32_t *out);

void bme280_reset(void);

BME280_API int bme280_set_mode(uint8_t mode) BME280_DEPRECATED("dùng bme280_mode");

typedef int (*bme280_delay_t)(uint32_t ms);

static inline int bme280_crc(uint8_t b) { return b ^ 0xFF; }

#ifdef __cplusplus
}
#endif
#endif /* BME280_H */
"""

VI_DU = {"examples": [{"symbol": "bme280_init", "code": "bme280_init(0x76);",
                       "fact_ids": ["f_1"]}]}


def _viet_nguon(root, ten, noi):
    f = root / "src" / ten
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(noi, encoding="utf-8")
    return f


def nap_code_unit(root, duong, cites):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO code_unit (id, path, symbol, hash, cites)"
                  " VALUES (?,?,?,?,?)",
                  (f"cu_{abs(hash(duong)) % 10**6}", duong, None, "h", json.dumps(cites)))
        c.commit()


def test_tc_moi_ham_public_co_muc(du_an, monkeypatch):
    """tc DOC-03: "Mọi hàm public có mục". `static` không public; `typedef` con trỏ hàm và
    `#define` không phải hàm — ba thứ hay bị một regex ngây thơ nhặt nhầm."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, VI_DU)
    _viet_nguon(root, "bme280.h", HEADER)
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    for ten in ("bme280_init", "bme280_read_temp", "bme280_reset", "bme280_set_mode"):
        assert f"### `{ten}`" in md, f"thiếu mục cho {ten}"
    assert "bme280_crc" not in md, "hàm static không public"
    assert "bme280_delay_t" not in md, "typedef con trỏ hàm không phải hàm"
    assert "BME280_ADDR_MAX" not in md, "macro không phải hàm"


def test_chu_ky_lay_tu_MA_NGUON_khong_phai_tu_mo_hinh(du_an, monkeypatch):
    """Cùng ranh giới với `doc.generate`: mô hình viết ví dụ, MÃ đọc chữ ký. Ở đây mô hình trả
    về một chữ ký sai hẳn; nó không được lọt vào khối chữ ký."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, {"examples": [{"symbol": "bme280_init",
                                         "code": "int bme280_init(char *ten, int cong);",
                                         "fact_ids": []}]})
    _viet_nguon(root, "bme280.h", HEADER)
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    chu_ky = md.split("### `bme280_init`")[1].split("```")[1]
    assert "uint8_t addr" in chu_ky and "char *ten" not in chu_ky


def test_chu_thich_doxygen_thanh_bang_tham_so_va_muc_tra_ve(du_an, monkeypatch):
    """Bước 1: "chữ ký + chú thích". Chú thích Doxygen đã là dữ liệu có cấu trúc — xếp lại
    thành bảng chứ không nhờ mô hình diễn giải, vì diễn giải thì sai được."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, VI_DU)
    _viet_nguon(root, "bme280.h", HEADER)
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    muc = md.split("### `bme280_init`")[1].split("### ")[0]
    assert "Khởi tạo cảm biến qua I2C." in muc
    assert "`addr`" in muc and "Địa chỉ I2C 7 bit" in muc
    assert "0 nếu thành công" in muc


def test_ham_khong_co_doxygen_van_co_muc(du_an, monkeypatch):
    """"Mọi hàm public" — kể cả hàm chưa ai chú thích. Bỏ nó đi thì bản tham chiếu im lặng về
    một phần API, và người đọc không có cách nào biết là nó thiếu."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, VI_DU)
    _viet_nguon(root, "bme280.h", HEADER)
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    muc = md.split("### `bme280_reset`")[1]
    assert "chưa có chú thích Doxygen" in muc


def test_than_ham_trong_tep_c_khong_sinh_muc_ma(du_an, monkeypatch):
    """Lời gọi hàm trong thân hàm trông giống hệt một khai báo với một regex đủ ngây thơ."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, VI_DU)
    _viet_nguon(root, "bme280.c", "#include \"bme280.h\"\n"
                "static int ghi(uint8_t r, uint8_t v) { return 0; }\n"
                "int bme280_init(uint8_t addr) {\n"
                "    if (addr > 0x77) return -1;\n"
                "    return ghi(0xF4, 0x27);\n"
                "}\n")
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.c"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    assert "### `bme280_init`" in md
    assert "### `ghi`" not in md and "### `if`" not in md and "### `return`" not in md


def test_vi_du_dung_theo_ho_chieu_neu_duoc_fact_id(du_an, monkeypatch):
    """Bước 1: "writer thêm ví dụ dùng theo hộ chiếu (fact id)". Fact id có thật thì ví dụ được
    giữ VÀ được nêu nguồn — người đọc lần ngược được về datasheet."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, VI_DU)
    nap_fact(root, [("f_1", CHIP, "i2c_address", "0x76", None, 27)])
    _viet_nguon(root, "bme280.h", HEADER)
    nap_code_unit(root, "src/bme280.h", ["f_1"])
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    assert "bme280_init(0x76);" in md
    assert "f_1" in md and "## Nguồn" in md and "stm32f411.pdf" in md


def test_vi_du_co_so_lieu_ma_fact_id_bia_thi_bi_bo(du_an, monkeypatch):
    """Cùng bất biến với `doc.datasheet_summary`: không có số nào không có nguồn. `0x76` trong
    một ví dụ là một khẳng định về phần cứng, và một fact id bịa không chống lưng được cho nó."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, {"examples": [{"symbol": "bme280_init",
                                         "code": "bme280_init(0x99);", "fact_ids": ["f_bia"]}]})
    nap_fact(root, [("f_1", CHIP, "i2c_address", "0x76", None, 27)])
    _viet_nguon(root, "bme280.h", HEADER)
    nap_code_unit(root, "src/bme280.h", ["f_1"])
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    assert "0x99" not in md and "f_bia" not in md
    assert "### `bme280_init`" in md, "bỏ ví dụ chứ không bỏ mục"


def test_khong_co_ho_chieu_thi_KHONG_goi_mo_hinh(du_an, monkeypatch):
    """Không có fact thì không có gì để neo ví dụ vào — nhờ mô hình viết là dạy nó bịa. Cùng
    cách xử lý với mục rỗng của `doc.generate`."""
    goi: list[int] = []

    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def run(self, *a, **k):
            goi.append(1)
            return _R(VI_DU)

    import eide.caps.doc as m
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())
    r, ctx, root = du_an
    _viet_nguon(root, "bme280.h", HEADER)
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    assert goi == [], "không có hộ chiếu mà vẫn gọi mô hình"
    assert "passport.import" in md, "phải nêu năng lực cần chạy để có ví dụ"


def test_macro_bao_bi_bo_khoi_chu_ky_nhung_kieu_tra_ve_thi_khong(du_an, monkeypatch):
    """Header nhúng gói khai báo trong macro xuất khẩu (`BME280_API`) và macro thuộc tính đuôi.
    Chúng là chi tiết của bộ dịch; in chúng ra thì người đọc không biết phải gõ gì."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, VI_DU)
    _viet_nguon(root, "bme280.h", HEADER)
    md = __import__("pathlib").Path(
        r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    ).read_text(encoding="utf-8")

    assert "int bme280_set_mode(uint8_t mode);" in md
    assert "BME280_API" not in md and "BME280_DEPRECATED" not in md


@pytest.mark.parametrize("ret,mong", [
    ("__BEGIN_DECLS int ", "int"),                              # macro trần bao ngoài
    ("__API_AVAILABLE(macos(10.4), ios(2.0)) int ", "int"),     # macro có đối số
    ("DIR *", "DIR *"),                                         # KIỂU viết hoa, không phải macro
    ("ESP_ERR ", "ESP_ERR"),
    ("_Pragma( ) __BEGIN_DECLS ", ""),                          # cả câu chỉ là chuỗi macro
])
def test_kieu_tra_ve_VIET_HOA_khong_bi_nham_la_macro(ret, mong):
    """Năm trường hợp này lấy từ `pthread.h`, `dirent.h`, `sys/stat.h` của SDK macOS — bộ đọc
    chạy sai cả năm ở bản đầu. `DIR *opendir(…)` là chỗ nguy hiểm nhất: bỏ `DIR` đi thì chữ ký
    vẫn in ra được, chỉ là không còn kiểu trả về, và không có gì báo."""
    from eide.caps.doc import _bo_macro_bao
    assert _bo_macro_bao(ret) == mong


def test_ngon_ngu_chua_co_bo_phan_tich_thi_E4001(du_an):
    """Lỗi duy nhất của hợp đồng. Bộ phân tích nội bộ chỉ đọc họ C; ngôn ngữ khác cần
    Doxygen/tree-sitter mà kho chưa khai — [DEV-072]. Nói ra bằng E4001 kèm năng lực gỡ, chứ
    không im lặng sinh một bản tham chiếu rỗng."""
    r, ctx, root = du_an
    _viet_nguon(root, "driver.rs", "pub fn init(addr: u8) -> i32 { 0 }\n")
    run = r.invoke("doc.api_ref", {"src": ["src/driver.rs"]}, ctx)

    assert run.status == "failed" and run.error["eide_code"] == "E4001"
    assert "env.guide_install" in run.error["candidates"]
    assert run.error["lang"] == ".rs"


def test_tep_khong_co_thi_E2000_truoc_khi_ghi_gi(du_an):
    """Kiểm mọi tệp TRƯỚC khi ghi: một tài liệu nửa vời tệ hơn không có tài liệu, vì nó trông
    như đã xong."""
    r, ctx, root = du_an
    run = r.invoke("doc.api_ref", {"src": ["src/khong-co.h"]}, ctx)

    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert run.error["missing"] == ["src/khong-co.h"]
    assert not list((root / ".eide" / "docs").glob("api_ref*"))


def test_ghi_DocArtifact_va_sinh_lai_cho_cung_id(du_an, monkeypatch):
    """DDD-14 §2 DocArtifact. Id băm từ đường dẫn nên sinh lại cho cùng một id — cùng khuôn với
    `doc.generate`, và nhờ vậy `doc.embed_diagram` trỏ vào được qua nhiều lần sinh."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, VI_DU)
    _viet_nguon(root, "bme280.h", HEADER)
    p1 = r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]
    p2 = r.invoke("doc.api_ref", {"src": ["src/bme280.h"]}, ctx).result["path"]

    assert p1 == p2
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute("SELECT id, type, sections FROM doc_artifact WHERE path=?", (p1,)).fetchall()
    assert len(rows) == 1 and rows[0][1] == "api_ref"
    assert [s["heading"] for s in json.loads(rows[0][2])] == ["src/bme280.h"]


# ================================================================ DOC-06 test_report
#
# tc: "Mỗi kết quả có bằng chứng". Bước 1: "Bảng TC ↔ kết quả ↔ bằng chứng (hash); tóm tắt;
# mục Nguồn".
#
# Bằng chứng ở đây là BĂM CỦA TỆP LOG, không phải bản ghi trong store: bản ghi nói "đã chạy",
# còn băm nói "đây đúng là tệp ấy". Người phản biện một đề án hỏi câu thứ hai.


def _log(root, ten, noi):
    f = root / ".eide" / "logs" / ten
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(noi, encoding="utf-8")
    return str(f)


def nap_tool_report(root, ds):
    with store.open_store(store.store_path(root)) as c:
        for rid, tool, dat, log_ref, metrics in ds:
            c.execute("INSERT OR REPLACE INTO tool_report (id, tool, passed, log_ref, metrics,"
                      " artifacts, at) VALUES (?,?,?,?,?,'[]','2026-09-09T10:00:00+00:00')",
                      (rid, tool, int(dat), log_ref, json.dumps(metrics)))
        c.commit()


def nap_measurement(root, ds):
    with store.open_store(store.store_path(root)) as c:
        for mid, kind, target, value, unit, file_ref, bam in ds:
            c.execute("INSERT OR REPLACE INTO measurement (id, kind, target, value, unit,"
                      " file_ref, hash, at) VALUES (?,?,?,?,?,?,?,'2026-09-09T10:00:00+00:00')",
                      (mid, kind, target, json.dumps(value), unit, file_ref, bam))
        c.commit()


def _bao_cao(du_an, ket_qua):
    r, ctx, root = du_an
    return __import__("pathlib").Path(
        r.invoke("doc.test_report", {"results": ket_qua}, ctx).result["path"]
    ).read_text(encoding="utf-8")


def test_tc_moi_ket_qua_co_bang_chung(du_an):
    """tc DOC-06. Mỗi dòng của bảng phải có một băm — không có băm thì "đã chạy và đạt" chỉ là
    một câu khẳng định, và một báo cáo kiểm thử không có gì ngoài khẳng định thì vô dụng."""
    _, _, root = du_an
    lg = _log(root, "build.log", "arm-none-eabi-gcc … 0 errors\n")
    nap_tool_report(root, [("tr_1", "build", True, lg, {"size_bytes": 20480})])
    nap_measurement(root, [("m_2", "current", "VDD", 12.5, "mA", "cap/i.csv", "b" * 64)])
    md = _bao_cao(du_an, ["tr_1", "m_2"])

    import hashlib
    bam = hashlib.sha256(__import__("pathlib").Path(lg).read_bytes()).hexdigest()[:16]
    assert bam in md, "kết quả tool_report thiếu băm của log"
    assert ("b" * 64)[:16] in md, "kết quả đo thiếu băm của chính bản ghi"
    assert "thiếu bằng chứng" not in md


def test_mot_dong_moi_CA_TEST_chu_khong_mot_dong_moi_lan_chay(du_an):
    """"Bảng TC ↔ kết quả": TC là ca test, không phải lần chạy. Một `tool_report` của
    `code.test_host` gói nhiều ca; gộp chúng thành một dòng "đạt/không đạt" là giấu đúng thứ
    người đọc cần — ca NÀO hỏng."""
    _, _, root = du_an
    l1, l2 = _log(root, "t1.log", "ok\n"), _log(root, "t2.log", "assert failed\n")
    nap_tool_report(root, [("tr_1", "test_host", False, l1, {"total": 2, "failed": 1, "cases": [
        {"name": "test_crc", "file": "tests/test_crc.c", "status": "passed", "log_ref": l1},
        {"name": "test_filter", "file": "tests/test_filter.c", "status": "failed",
         "log_ref": l2}]})])
    md = _bao_cao(du_an, ["tr_1"])

    assert "test_crc" in md and "test_filter" in md
    dong = [d for d in md.splitlines() if d.startswith("| test_filter")]
    assert dong and "KHÔNG ĐẠT" in dong[0]
    assert [d for d in md.splitlines() if d.startswith("| test_crc")][0].count("ĐẠT")


def test_tom_tat_dem_dung_va_noi_ro_bao_nhieu_khong_dat(du_an):
    """"tóm tắt" của bước 1. Người đọc một báo cáo kiểm thử đọc dòng này trước mọi thứ khác."""
    _, _, root = du_an
    lg = _log(root, "t.log", "x\n")
    nap_tool_report(root, [("tr_1", "test_host", False, lg, {"cases": [
        {"name": "a", "status": "passed", "log_ref": lg},
        {"name": "b", "status": "failed", "log_ref": lg},
        {"name": "c", "status": "compile_error", "log_ref": lg}]})])
    md = _bao_cao(du_an, ["tr_1"])

    assert "1/3" in md and "không đạt" in md.lower()


def test_phep_do_khong_duoc_dem_la_DAT(du_an):
    """Một phép đo cho ra GIÁ TRỊ, không cho ra phán định — ngưỡng nằm ở `arch.memory_budget`
    và `bench.*`. Đếm nó vào mẫu số "đạt" cho ra một tỷ lệ đẹp hơn sự thật, đúng kiểu con số mà
    không ai kiểm lại."""
    _, _, root = du_an
    lg = _log(root, "t.log", "x\n")
    nap_tool_report(root, [("tr_1", "test_host", False, lg, {"cases": [
        {"name": "a", "status": "passed", "log_ref": lg},
        {"name": "b", "status": "failed", "log_ref": lg}]})])
    nap_measurement(root, [("m_2", "current", "VDD", 12.5, "mA", "cap/i.csv", "b" * 64)])
    md = _bao_cao(du_an, ["tr_1", "m_2"])

    assert "1/2 ca đạt" in md, "phép đo bị đếm vào mẫu số đạt/không đạt"
    assert "1 phép đo không có ngưỡng" in md
    dong = [d for d in md.splitlines() if d.startswith("| current/VDD")]
    assert dong and "ĐẠT" not in dong[0] and "12.5 mA" in dong[0]


def test_bang_chung_mat_thi_NOI_RA_chu_khong_bo_dong(du_an):
    """Tệp log đã bị xóa thì KHÔNG có băm — và cách xử lý đúng là nói ra, không phải bỏ dòng ấy
    đi cũng không phải băm bản ghi để lấp chỗ trống. Băm một bản ghi rồi gọi nó là bằng chứng
    thì con số trông y hệt một bằng chứng thật, mà không ai phân biệt được nữa."""
    _, _, root = du_an
    nap_tool_report(root, [("tr_1", "build", True, str(root / ".eide" / "logs" / "mat.log"), {})])
    md = _bao_cao(du_an, ["tr_1"])

    assert "thiếu bằng chứng" in md
    assert "| build" in md, "bỏ dòng là giấu, không phải sạch"
    assert "1/1" in md.split("thiếu bằng chứng")[0][-120:] or "1 kết quả" in md


def test_id_khong_co_thi_E2000_truoc_khi_ghi_gi(du_an):
    """Kiểm cả danh sách trước: một báo cáo thiếu một kết quả trông y như một báo cáo đủ."""
    r, ctx, root = du_an
    run = r.invoke("doc.test_report", {"results": ["tr_khong_co"]}, ctx)

    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert run.error["missing"] == ["tr_khong_co"]
    assert not list((root / ".eide" / "docs").glob("test_report*"))


def test_docx_uy_quyen_cho_report_export(du_an):
    """`format: docx` có trong `input_schema` của DOC-06, nhưng REPORT-02 v1.3 nói nó là "chỗ
    DUY NHẤT dựng docx/pdf" ([DEV-070]). Hai tài liệu nói khác nhau — [DEV-073]. Dựng docx ở đây
    nữa là hai bản dựng cùng một báo cáo, và chúng sẽ lệch."""
    r, ctx, root = du_an
    lg = _log(root, "b.log", "x\n")
    nap_tool_report(root, [("tr_1", "build", True, lg, {})])
    run = r.invoke("doc.test_report", {"results": ["tr_1"], "format": "docx"}, ctx)

    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert run.error["candidates"] == ["report.export"]


def test_muc_Nguon_liet_ke_tep_bang_chung(du_an):
    """"mục Nguồn" của một báo cáo kiểm thử là danh sách tệp bằng chứng, không phải danh sách
    datasheet: thứ người phản biện muốn mở ra xem là chính cái log."""
    _, _, root = du_an
    lg = _log(root, "build.log", "ok\n")
    nap_tool_report(root, [("tr_1", "build", True, lg, {})])
    md = _bao_cao(du_an, ["tr_1"])

    nguon = md.split("## Nguồn")[1]
    assert "build.log" in nguon and "tr_1" in nguon


def test_ghi_DocArtifact_loai_test_report(du_an):
    """DDD-14 §2 DocArtifact — và `doc.generate` đã ủy quyền loại `test_report` sang đây, nên
    hai bên phải ghi cùng một loại vào store."""
    r, ctx, root = du_an
    lg = _log(root, "b.log", "x\n")
    nap_tool_report(root, [("tr_1", "build", True, lg, {})])
    p = r.invoke("doc.test_report", {"results": ["tr_1"]}, ctx).result["path"]

    with store.open_store(store.store_path(root)) as c:
        rows = c.execute("SELECT type, citations FROM doc_artifact WHERE path=?", (p,)).fetchall()
    assert rows and rows[0][0] == "test_report"
    assert json.loads(rows[0][1]) == ["tr_1"]


def test_khong_goi_mo_hinh(du_an, monkeypatch):
    """Cùng lý do với `doc.bringup_guide`: mọi thứ trong báo cáo này đều đã có trong store, và
    nhờ mô hình viết lại chúng chỉ thêm một cơ hội để một con số bị đổi."""
    class _G:
        def run(self, *a, **k):
            raise AssertionError("không được gọi mô hình")

    import eide.caps.doc as m
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())
    _, _, root = du_an
    lg = _log(root, "b.log", "x\n")
    nap_tool_report(root, [("tr_1", "build", True, lg, {})])
    assert "# Báo cáo kiểm thử" in _bao_cao(du_an, ["tr_1"])


# ================================================================ DOC-10 changelog
#
# tc: TC-77 ("changelog từ 10 commit"). Bước 1: "git log + ledger (merge, supersede, badge) →
# nhóm feat/fix/knowledge; liên kết run_id".
#
# Nhóm lấy từ CHÍNH loại commit của CON-28 §4 (`feat|fix|docs|refactor|test|chore|knowledge`),
# không đoán từ chữ trong tiêu đề.


def _commit(root, loai, mo_ta, trailer=None, ten_tep=None):
    from eide_core import git
    f = ten_tep or f"src/{abs(hash(mo_ta)) % 10**6}.c"
    (root / f).parent.mkdir(parents=True, exist_ok=True)
    (root / f).write_text(mo_ta + "\n", encoding="utf-8")
    return git.commit(root, git.thong_diep(loai, "bme280", mo_ta, trailer or {}), [f])


@pytest.fixture
def kho(du_an):
    from eide_core import git
    r, ctx, root = du_an
    if git.co_git() is None:
        pytest.skip("máy chưa có git")
    git.dam_bao_kho(root)
    _commit(root, "chore", "khởi tạo", ten_tep="src/khoi_tao.c")
    return r, ctx, root


def _cl(kho, pham_vi):
    r, ctx, _ = kho
    return r.invoke("doc.changelog", {"range": pham_vi}, ctx).result["markdown"]


def test_TC77_changelog_tu_10_commit(kho):
    """tc TC-77: "changelog từ 10 commit". Mười commit vào thì mười dòng ra — không gộp, không
    bỏ cái nào vì trông giống nhau."""
    _, _, root = kho
    for i in range(10):
        _commit(root, "feat", f"thêm hàm số {i}")
    md = _cl(kho, "HEAD~10..HEAD")

    for i in range(10):
        assert f"thêm hàm số {i}" in md, f"thiếu commit {i}"


def test_nhom_theo_LOAI_COMMIT_cua_CON28(kho):
    """`feat|fix|knowledge` là ba loại commit có thật trong CON-28 §4, không phải ba từ khóa
    đoán từ tiêu đề. Loại còn lại (`docs`, `refactor`, `test`, `chore`) gom vào "Khác" chứ không
    biến mất."""
    _, _, root = kho
    _commit(root, "feat", "đọc nhiệt độ")
    _commit(root, "fix", "sai dấu bù nhiệt")
    _commit(root, "knowledge", "nhập hộ chiếu BME280")
    _commit(root, "refactor", "tách hàm crc")
    md = _cl(kho, "HEAD~4..HEAD")

    for tieu_de, noi in [("Tính năng", "đọc nhiệt độ"), ("Sửa lỗi", "sai dấu bù nhiệt"),
                         ("Tri thức", "nhập hộ chiếu BME280"), ("Khác", "tách hàm crc")]:
        muc = md.split(f"## {tieu_de}")[1].split("## ")[0]
        assert noi in muc, f"{noi} không nằm dưới {tieu_de}"


def test_lien_ket_run_id_tu_trailer_Eide_Run(kho):
    """"liên kết run_id" của bước 1. `Eide-Run` là trailer CON-28 §4 mà `code.merge` đã ghi —
    nhờ nó một dòng changelog lần ngược được về đúng lần chạy đã sinh ra nó."""
    _, _, root = kho
    _commit(root, "feat", "đọc độ ẩm", {"Eide-Run": "run_abc123", "Eide-Facts": ["f_1", "f_2"]})
    md = _cl(kho, "HEAD~1..HEAD")

    assert "run_abc123" in md
    assert "f_1" in md, "trailer Eide-Facts là chỗ duy nhất nói dòng mã ấy dựa trên fact nào"


def test_tri_thuc_lay_ca_tu_LEDGER_chu_khong_chi_tu_git(kho):
    """Bước 1 nói "git log + ledger". Một mẻ fact nhập vào không sinh commit nào — nó chỉ có
    trong sổ cái, và bỏ nó ra ngoài thì changelog kể thiếu đúng phần tri thức."""
    r, ctx, root = kho
    _commit(root, "feat", "đọc áp suất")
    r.ledger.append("store.write", {"batch_id": "b_9", "n_facts": 12, "n_conflicts": 1,
                                    "actor": "agent", "reason": "nhập SVD STM32F411",
                                    "hash": "a" * 16})
    md = _cl(kho, "HEAD~1..HEAD")

    tri = md.split("## Tri thức")[1].split("## ")[0]
    assert "12" in tri and "b_9" in tri
    assert "nhập SVD STM32F411" in tri
    assert "1" in tri, "số xung đột phải nêu — một mẻ có xung đột không giống một mẻ sạch"


def test_range_khong_dung_dinh_dang_thi_E1000(kho):
    """`range` có đúng hai dạng trong hợp đồng: `tag..tag` và `since date`. Dạng thứ ba là lỗi
    của bên gọi, và nói ra ngay tốt hơn là đưa một chuỗi lạ cho git rồi in lại lỗi của git."""
    r, ctx, _ = kho
    run = r.invoke("doc.changelog", {"range": "hôm qua tới giờ"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"
    assert "since" in run.error["message"] and run.error["field"] == "range"


def test_since_ngay_cung_chay(kho):
    """Dạng thứ hai của hợp đồng: `since <ngày>`."""
    _, _, root = kho
    _commit(root, "feat", "đọc điểm sương")
    assert "đọc điểm sương" in _cl(kho, "since 2000-01-01")


def test_chua_phai_kho_git_thi_NOI_RO(du_an):
    """Một changelog rỗng và một dự án chưa có kho git đọc phải khác nhau. Trả chuỗi rỗng là để
    người dùng đi tìm xem mình gõ sai chỗ nào."""
    r, ctx, _ = du_an
    md = r.invoke("doc.changelog", {"range": "since 2000-01-01"}, ctx).result["markdown"]
    assert "chưa phải một kho git" in md


def test_khong_ghi_tep_nao(kho):
    """`undo: none` và đầu ra là `markdown`, không phải `path` — nên năng lực này không được để
    lại gì trên đĩa. Hai năng lực cùng nhóm ghi tệp; cái này thì không."""
    _, _, root = kho
    _commit(root, "feat", "đọc gió")
    _cl(kho, "HEAD~1..HEAD")
    assert not list((root / ".eide" / "docs").glob("changelog*"))


def test_chuoi_P7_du_nang_luc():
    """P7 "bộ tài liệu" là chuỗi thứ hai đủ năng lực cho mọi bước. Giữ điều đó khỏi tụt đi trong
    im lặng khi ai đó đổi `chains.json` hoặc gỡ một năng lực."""
    import importlib
    import pkgutil

    import eide.caps
    from eide_core.paths import spec_dir
    from eide_core.registry import get_registry

    chains = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    p7 = next(c for c in chains if "P7" in c["ten"])
    can = {n["cap"] for n in p7["nodes"]}
    for m in pkgutil.iter_modules(eide.caps.__path__):
        importlib.import_module(f"eide.caps.{m.name}")
    co = {c.spec.id for c in get_registry().list() if c.implemented}
    assert not (can - co), f"P7 tụt lại: thiếu {sorted(can - co)}"
