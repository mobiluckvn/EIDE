"""Sáu năng lực M3 cuối cùng làm được trên máy này — CDS-12.1 CODE-15/16, CDS-12.4 DOC-09/11/12,
DIAGRAM-14.

Điểm chung của cả sáu: mỗi cái có đúng MỘT bất biến đáng giá, và test ở đây tồn tại để bất biến
ấy không im lặng biến mất.

- `doc.sync`   — mục lỗi thời phải được NÊU RA kể cả khi không tự sửa được.
- `doc.translate` — bản dịch mất một hàng bảng là bản dịch không giao được.
- `doc.slides` — thiếu pptx thì vẫn phải còn đường lui, không mất cả hai.
- `diagram.sync` — lệch LỚN thì hỏi người, và ranh giới đo bằng TỈ LỆ.
- `code.docs`  — README không tra ngược được là một nguồn sự thật thứ hai.
- `code.refactor` — "không đổi hành vi" được KIỂM, không được hứa.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "m3"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


class _G:
    def __init__(self, data):
        self.data = data
        self.prompts: list[str] = []

    def run(self, role, user, schema, **kw):
        self.prompts.append(user)
        d = self.data(user) if callable(self.data) else self.data

        class R:
            pass
        r = R()
        r.data = d
        return r


def _doc(root: Path, did: str, path: str, sections, citations=()) -> None:
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO doc_artifact (id,type,path,lang,sections,citations,at)"
                  " VALUES (?,?,?,?,?,?,?)",
                  (did, "SRS", path, "vi", json.dumps(sections, ensure_ascii=False),
                   json.dumps(list(citations)), "2026-09-12T00:00:00Z"))
        c.commit()


# ---------------------------------------------------------------- DOC-12 sync


def test_sync_neu_ra_muc_lien_quan_toi_fact_da_doi(du_an):
    """tc DOC-12: "TC-77 mục liên quan stale"."""
    from eide.caps.doc import sync

    _, ctx, root = du_an
    _doc(root, "doc_1", str(root / "a.md"),
         [{"heading": "Giao tiếp I2C", "citations": ["f_aaa"]},
          {"heading": "Nguồn điện", "citations": ["f_bbb"]}])
    kq = sync({"delta": {"fact_id": "f_aaa"}}, ctx)
    assert [s["heading"] for s in kq["stale"]] == ["Giao tiếp I2C"]
    assert kq["stale"][0]["citations"] == ["f_aaa"]


def test_sync_ghi_stale_vao_store_de_lan_mo_sau_con_thay(du_an):
    """Một cảnh báo chỉ sống trong một lời gọi thì lần mở tài liệu sau không ai thấy."""
    from eide.caps.doc import sync

    _, ctx, root = du_an
    _doc(root, "doc_2", str(root / "b.md"), [{"heading": "X", "citations": ["f_ccc"]}])
    sync({"delta": {"fact_id": "f_ccc"}}, ctx)
    with store.open_store(store.store_path(root)) as c:
        (v,) = c.execute("SELECT stale_sections FROM doc_artifact WHERE id='doc_2'").fetchone()
    assert json.loads(v) == ["X"]


def test_sync_delta_rong_thi_E1000(du_an):
    """Không nêu cái gì đổi thì không có cách nào biết mục nào lỗi thời."""
    from eide.caps.doc import sync

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        sync({"delta": {}}, ctx)
    assert e.value.code == "E1000"


def test_sync_niem_store_con_khop(du_an):
    from eide.caps.doc import sync

    _, ctx, root = du_an
    _doc(root, "doc_3", str(root / "c.md"), [{"heading": "Y", "citations": ["f_d"]}])
    sync({"delta": {"fact_id": "f_d"}}, ctx)
    assert store.verify_seal(store.store_path(root))[0]


# ---------------------------------------------------------------- DOC-09 translate


def test_translate_mat_mot_hang_bang_thi_E5002(du_an, monkeypatch):
    """tc DOC-09 nguyên văn: "Số hình/bảng bằng nhau". Đây là chỗ một bản dịch trôi chảy sai
    lặng lẽ nhất — mô hình dịch bảng thành văn xuôi và bản đích đọc vẫn hay."""
    import eide.caps.doc as m

    _, ctx, root = du_an
    f = root / ".eide" / "docs" / "t.md"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("# T\n\n| a | b |\n|---|---|\n| 1 | 2 |\n", encoding="utf-8")
    _doc(root, "doc_t", str(f), [])
    monkeypatch.setattr(m, "_gateway", lambda c: _G({"text": "# T\n\nMột bảng hai cột.\n"}))

    with pytest.raises(EideError) as e:
        m.translate({"doc_id": "doc_t", "lang": "en"}, ctx)
    assert e.value.code == "E5002" and e.value.data["kind"] == "hàng bảng"


def test_translate_giu_trich_dan_nguyen_van(du_an, monkeypatch):
    """Trích dẫn là ID. Một id được "dịch" thì không tra ngược được nữa."""
    import eide.caps.doc as m

    _, ctx, root = du_an
    f = root / ".eide" / "docs" / "u.md"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("# U\n\nĐịa chỉ là 0x76 [f_abc123].\n", encoding="utf-8")
    _doc(root, "doc_u", str(f), [])
    monkeypatch.setattr(m, "_gateway",
                        lambda c: _G({"text": "# U\n\nThe address is 0x76 [f_abc123].\n"}))

    p = m.translate({"doc_id": "doc_u", "lang": "en"}, ctx)["path"]
    assert "[f_abc123]" in (root / p).read_text(encoding="utf-8")


def test_translate_dich_THEO_MUC(du_an, monkeypatch):
    """Dịch cả tệp một lượt thì phần đuôi — phụ lục và mục Nguồn — bị cắt lặng lẽ."""
    import eide.caps.doc as m

    _, ctx, root = du_an
    f = root / ".eide" / "docs" / "v.md"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("# A\n\nmột\n\n# B\n\nhai\n\n# Nguồn\n\nba\n", encoding="utf-8")
    _doc(root, "doc_v", str(f), [])
    g = _G(lambda u: {"text": u.split("\n\n")[-1]})
    monkeypatch.setattr(m, "_gateway", lambda c: g)

    m.translate({"doc_id": "doc_v", "lang": "en"}, ctx)
    assert len(g.prompts) == 3, "ba mục thì ba lượt, không gộp một"


# ---------------------------------------------------------------- DOC-11 slides


def test_slides_thieu_pptx_van_con_duong_lui(du_an, monkeypatch):
    """Từ chối thẳng thì người dùng mất cả hai. Bản Markdown vẫn trình bày được và vẫn giữ
    đủ phần nguồn."""
    import builtins

    from eide.caps.doc import slides

    _, ctx, root = du_an
    that = builtins.__import__

    def gia(ten, *a, **k):
        if ten == "pptx":
            raise ImportError("không có")
        return that(ten, *a, **k)

    monkeypatch.setattr(builtins, "__import__", gia)
    with pytest.raises(EideError) as e:
        slides({"scope": "đề án"}, ctx)
    assert e.value.code == "E4001"
    md = root / e.value.data["alternative"]
    assert md.exists() and "marp: true" in md.read_text(encoding="utf-8")


def test_slides_dan_y_dung_tu_STORE_khong_tu_nghi(du_an):
    """Một slide "Kết quả" với con số mô hình tự nhớ là đúng thứ không được mang đi bảo vệ."""
    from eide.caps.doc import _dan_y_slide

    _, _, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO requirement (id,kind,text,status) VALUES (?,?,?,?)",
                  ("FR-01", "FR", "đo nhiệt độ mỗi giây", "accepted"))
        c.commit()
    dy = _dan_y_slide(root, "đề án", 12)
    yc = next(s for s in dy if s["title"] == "Yêu cầu")
    assert "FR-01" in yc["sources"] and "đo nhiệt độ" in yc["bullets"][0]


# ---------------------------------------------------------------- DIAGRAM-14 sync


def _luoc_do(root: Path, did: str, src: str, kind: str = "state") -> None:
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO diagram (id,kind,lang,src,at) VALUES (?,?,?,?,?)",
                  (did, kind, "mermaid", src, "2026-09-12T00:00:00Z"))
        c.commit()


def _ma_c(root: Path, noi_dung: str) -> None:
    (root / "src").mkdir(parents=True, exist_ok=True)
    (root / "src" / "fsm.c").write_text(noi_dung, encoding="utf-8")


def test_diagram_sync_bat_trang_thai_co_trong_MA_ma_khong_co_trong_HINH(du_an):
    """Đây là chỗ một tài liệu kỹ thuật nói dối êm ái nhất: lược đồ vẽ đúng hồi thiết kế, mã đi
    tiếp, không ai sửa hình."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_1", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n")
    _ma_c(root, "switch(s){case ST_IDLE: break; case ST_RUN: break; case ST_ERR: break;}")
    d = sync({"diagram_id": "dg_1", "direction": "check"}, ctx)["diff"]
    assert d["in_code_only"] == ["ST_ERR"] and d["in_diagram_only"] == []
    assert d["stale"] is True


def test_diagram_sync_khong_lech_thi_khong_stale(du_an):
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_2", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n")
    _ma_c(root, "switch(s){case ST_IDLE: break; case ST_RUN: break;}")
    kq = sync({"diagram_id": "dg_2"}, ctx)
    assert kq["diff"]["stale"] is False and kq["applied"] is False


def test_diagram_sync_lech_LON_thi_E3000(du_an):
    """Ranh giới đo bằng TỈ LỆ: thiếu 2 trạng thái trong FSM 3 trạng thái là viết lại cả máy
    trạng thái, còn trong FSM 30 trạng thái là quên hai nhánh."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_3", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n")
    _ma_c(root, "switch(s){case ST_A: case ST_B: case ST_C: case ST_D:}")
    with pytest.raises(EideError) as e:
        sync({"diagram_id": "dg_3", "direction": "to_code"}, ctx)
    assert e.value.code == "E3000" and e.value.data["diff"]["drift_ratio"] > 0.34


def test_diagram_sync_check_la_MAC_DINH(du_an):
    """Mặc định vào một hướng GHI là để một lời gọi thiếu tham số đi sửa mã."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_4", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n")
    _ma_c(root, "switch(s){case ST_IDLE: case ST_RUN:}")
    assert sync({"diagram_id": "dg_4"}, ctx)["applied"] is False


# ---------------------------------------------------------------- CODE-15 docs


def test_docs_bo_sung_muc_Nguon_khi_mo_hinh_quen_trich_dan(du_an, monkeypatch):
    """Một README nói "địa chỉ 0x76" mà không nêu fact nào thì nó vừa tạo ra một nguồn sự thật
    thứ hai, cạnh tranh với store."""
    import eide.caps.doc as md
    from eide.caps.code import docs

    _, ctx, root = du_an
    (root / "src" / "bme280").mkdir(parents=True, exist_ok=True)
    (root / "src" / "bme280" / "bme280.h").write_text(
        "#define ADDR 0x76 /* eide:fact f_ab00000000000c */\n"
        "int bme280_init(void);\n", encoding="utf-8")
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES ('s1','u','h','pdf','gold','vendor-doc')")
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  ("f_ab00000000000c", "part:bme280", "address", '"0x76"', "s1", "parser",
                   "gold", 1.0, "verified", "A"))
        c.commit()
    monkeypatch.setattr(md, "_gateway", lambda c: _G({"markdown": "# bme280\n\nDriver.\n"}))
    monkeypatch.setattr(md, "style_check", lambda p, c: {"issues": []})

    p = docs({"module": "bme280"}, ctx)["path"]
    van = (root / p).read_text(encoding="utf-8")
    assert "f_ab00000000000c" in van, van


def test_docs_module_khong_co_tep_thi_E2000(du_an, monkeypatch):
    from eide.caps.code import docs

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        docs({"module": "khong-ton-tai"}, ctx)
    assert e.value.code == "E2000"


# ---------------------------------------------------------------- CODE-16 refactor


def test_refactor_KHONG_co_test_nen_thi_E5003(du_an):
    """Tái cấu trúc mà không có lưới an toàn thì thứ duy nhất ta biết sau đó là mã đã khác đi."""
    from eide.caps.code import refactor

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "a.c").write_text("int f(void){return 1;}\n", encoding="utf-8")
    with pytest.raises(EideError) as e:
        refactor({"scope": ["src/a.c"]}, ctx)
    assert e.value.code == "E5003" and e.value.data["reason"] == "no_baseline"


def test_refactor_doi_ket_qua_test_thi_E5003_va_TRA_LAI_ma_goc(du_an, monkeypatch):
    """Bất biến của CODE-16. So theo TỪNG BÀI: hai bài đổi ngược chiều nhau giữ nguyên tổng —
    và đó đúng là hình dạng của một lỗi tái cấu trúc."""
    import eide.caps.code as mc
    import eide.caps.doc as md

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    f = root / "src" / "a.c"
    f.write_text(goc := "int f(void){return 1;}\n", encoding="utf-8")

    lan = {"n": 0}

    def _kq(ctx_):
        lan["n"] += 1
        return {"t1": "passed", "t2": "passed"} if lan["n"] == 1 \
            else {"t1": "failed", "t2": "passed"}

    monkeypatch.setattr(mc, "_ket_qua_test", _kq)
    monkeypatch.setattr(md, "_gateway",
                        lambda c: _G({"files": [{"path": "src/a.c",
                                                 "content": "int f(void){return 2;}\n"}]}))
    with pytest.raises(EideError) as e:
        refactor_ = mc.refactor
        refactor_({"scope": ["src/a.c"]}, ctx)
    assert e.value.code == "E5003" and e.value.data["reason"] == "behaviour_changed"
    assert e.value.data["changed"] == ["t1"]
    assert f.read_text(encoding="utf-8") == goc, "phải trả lại mã gốc dù kết quả thế nào"


def test_refactor_giu_nguyen_hanh_vi_thi_tra_patch(du_an, monkeypatch):
    import eide.caps.code as mc
    import eide.caps.doc as md

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "a.c").write_text("int f(void){return 1;}\n", encoding="utf-8")
    monkeypatch.setattr(mc, "_ket_qua_test", lambda c: {"t1": "passed"})
    monkeypatch.setattr(md, "_gateway",
                        lambda c: _G({"files": [{"path": "src/a.c",
                                                 "content": "int f(void) { return 1; }\n"}],
                                      "rationale": "đặt lại khoảng trắng"}))
    p = mc.refactor({"scope": ["src/a.c"]}, ctx)["patch"]
    assert p["files"][0]["path"] == "src/a.c" and p["tests_unchanged"] == ["t1"]


def test_refactor_cham_tep_ngoai_scope_thi_E5003(du_an, monkeypatch):
    import eide.caps.code as mc
    import eide.caps.doc as md

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "a.c").write_text("int f(void){return 1;}\n", encoding="utf-8")
    monkeypatch.setattr(mc, "_ket_qua_test", lambda c: {"t1": "passed"})
    monkeypatch.setattr(md, "_gateway",
                        lambda c: _G({"files": [{"path": "src/b.c", "content": "x\n"}]}))
    with pytest.raises(EideError) as e:
        mc.refactor({"scope": ["src/a.c"]}, ctx)
    assert e.value.data["reason"] == "out_of_scope"
