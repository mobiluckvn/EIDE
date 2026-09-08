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
