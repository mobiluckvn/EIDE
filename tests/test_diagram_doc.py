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


def test_khong_co_citations_thi_tu_choi(du_an, monkeypatch):
    """tc: "Có citations". Một mục tài liệu kỹ thuật không truy được nguồn thì người phản biện
    hỏi ngay câu đầu tiên."""
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"markdown": "Một đoạn văn nghe rất hợp lý.", "citations": []})
    run = r.invoke("doc.section", {"target": "I2C1"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


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
