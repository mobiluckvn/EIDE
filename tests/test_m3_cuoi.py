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


# ---------------------------------------------------------------- ba món nợ, đóng 12/09


def test_doi_muc_tu_chu_VAO_so_cai(du_an):
    """`autonomy.yaml` KHÔNG nằm trong `content_digest` của niêm phong. Nâng A2 → A4 rồi hạ lại
    là thao tác cho phép tác tử tự nạp firmware — mà tới 12/09 nó không để lại dấu vết nào
    trong chuỗi băm. Cùng họ với `gate.decision` (lỗi im lặng số 12)."""
    from eide.caps.policy import set_autonomy

    r, ctx, _ = du_an
    set_autonomy({"level": "A1", "by": "human"}, ctx)
    ds = [x for x in r.ledger.records() if x["kind"] == "autonomy.change"]
    assert ds, "đổi mức tự chủ phải vào sổ cái"
    assert ds[-1]["data"]["to"] == "A1" and ds[-1]["data"]["by"] == "human"
    assert r.ledger.verify() == (True, 0)


def test_roles_yaml_duoc_SINH_RA_khi_tao_du_an(du_an):
    """DDD-14 §yaml khai `roles.yaml` ở mốc M0 nhưng tới 12/09 không chỗ nào sinh ra."""
    import yaml as _yaml

    _, _, root = du_an
    f = root / ".eide" / "roles.yaml"
    assert f.is_file()
    d = _yaml.safe_load(f.read_text(encoding="utf-8"))["roles"]
    assert "coder" in d and "librarian" in d
    for ten, c in d.items():
        assert set(c) == {"skills_max", "tools", "budget", "prompt"}, (ten, sorted(c))


def test_roles_yaml_ghep_tu_SPEC_chu_khong_go_tay(du_an):
    """Gõ tay ở đây nghĩa là một bản chép thứ hai của ba bảng spec, và nó sẽ trôi khỏi bản gốc
    ngay lần đầu ai đó sửa một con số — đúng loại lỗi DEV-043 và DEV-046 đã ghi."""
    import yaml as _yaml

    from eide_core.composer import cau_hinh

    _, _, root = du_an
    d = _yaml.safe_load((root / ".eide" / "roles.yaml").read_text(encoding="utf-8"))["roles"]
    ns = cau_hinh()["budget"]
    for ten, c in d.items():
        assert c["budget"]["input"] == ns[ten]["total"], ten


def test_du_an_NOI_duoc_ngan_sach_ma_khong_dung_spec(du_an):
    """Đây là lý do `roles.yaml` tồn tại: một dự án muốn cho `librarian` nhiều chỗ hơn thì
    không phải sửa `docs/spec/`, tức sửa thứ dùng chung cho mọi dự án."""
    import yaml as _yaml

    from eide_core.composer import ContextBundle, cau_hinh

    _, _, root = du_an
    f = root / ".eide" / "roles.yaml"
    d = _yaml.safe_load(f.read_text(encoding="utf-8"))
    goc = cau_hinh()["budget"]["librarian"]["total"]
    d["roles"]["librarian"]["budget"]["input"] = goc + 5000
    f.write_text(_yaml.safe_dump(d, allow_unicode=True), encoding="utf-8")

    assert ContextBundle(role="librarian").budget["total"] == goc, "không có dự án thì dùng bản cài"
    assert ContextBundle(role="librarian", project_dir=root).budget["total"] == goc + 5000


def test_roles_yaml_HONG_khong_lam_hong_luot_goi(du_an):
    """Ngân sách là thứ tinh chỉnh; chạy được hay không thì không nên phụ thuộc vào nó."""
    from eide_core.composer import ContextBundle, cau_hinh

    _, _, root = du_an
    (root / ".eide" / "roles.yaml").write_text("{{{ không phải yaml", encoding="utf-8")
    assert (ContextBundle(role="coder", project_dir=root).budget["total"]
            == cau_hinh()["budget"]["coder"]["total"])


def test_sync_from_code_THEM_trang_thai_thieu_va_GIU_phan_nguoi_ve(du_an):
    """DEV-090, hướng rẻ hơn. Một lược đồ người vẽ mang thông tin mã không có — nhãn tiếng Việt
    trên cạnh, thứ tự đọc. Sinh lại tất cả là ném đi phần người làm để lấy phần máy đọc được."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_fc", "stateDiagram-v2\n  ST_IDLE --> ST_RUN : bấm nút\n")
    _ma_c(root, "switch(s){case ST_IDLE: case ST_RUN: case ST_ERR:}")

    kq = sync({"diagram_id": "dg_fc", "direction": "from_code"}, ctx)
    assert kq["applied"] is True
    assert "bấm nút" in kq["src"], "nhãn người viết phải còn"
    assert "ST_ERR" in kq["src"], "trạng thái mã có mà hình thiếu phải được thêm"


def test_sync_from_code_KHONG_tu_xoa_trang_thai_hinh_co_ma_khong_co(du_an):
    """Nó có thể là một nhánh CHƯA viết chứ không phải một nhánh đã bỏ. Xoá tự động là để một
    lần chạy `from_code` lặng lẽ làm mất phần thiết kế đi trước mã."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_fc2", "stateDiagram-v2\n  ST_IDLE --> ST_SAP_LAM\n  ST_IDLE --> ST_RUN\n")
    _ma_c(root, "switch(s){case ST_IDLE: case ST_RUN:}")
    kq = sync({"diagram_id": "dg_fc2", "direction": "from_code"}, ctx)
    assert "ST_SAP_LAM" in kq["src"]
    assert "ST_SAP_LAM" in kq["diff"]["in_diagram_only"], "nhưng phải NÊU nó trong diff"


def test_sync_from_code_bo_co_stale(du_an):
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_fc3", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n")
    _ma_c(root, "switch(s){case ST_IDLE: case ST_RUN: case ST_X:}")
    sync({"diagram_id": "dg_fc3", "direction": "from_code"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        (st, sw) = c.execute("SELECT stale, synced_with FROM diagram WHERE id='dg_fc3'").fetchone()
    assert st == 0 and sw == "code"


def test_dung_KHAN_CAP_vao_so_cai(du_an):
    """Thao tác an toàn quan trọng nhất của cả sản phẩm là thao tác duy nhất không để lại dấu
    vết — tới 12/09. Ai đó bấm dừng lúc 2 giờ sáng, ba việc R3 bị huỷ, và sáng hôm sau không có
    cách nào biết chuyện đã xảy ra."""
    from eide.caps.policy import emergency_stop

    r, ctx, _ = du_an
    ctx.extra["cancel_running"] = lambda: ["cr_1", "cr_2"]
    emergency_stop({}, ctx)

    ds = [x for x in r.ledger.records() if x["kind"] == "stop"]
    assert ds, "dừng khẩn cấp phải vào sổ cái"
    assert ds[-1]["data"]["n_cancelled"] == 2 and ds[-1]["data"]["cancelled"] == ["cr_1", "cr_2"]
    assert r.ledger.verify() == (True, 0)


def test_moi_kieu_su_kien_API15_deu_co_cho_phat_TRU_thu_can_board():
    """Cổng chặn cho cả lớp lỗi này. Ba lần liên tiếp — `gate.decision`, `autonomy.change`,
    `stop` — một kiểu sự kiện được khai trong API-15 §5 mà không chỗ nào phát, và cả ba đều
    nằm đúng chỗ truy vết quan trọng nhất. Bài này để lần thứ tư đỏ ngay."""
    import re as _re
    from pathlib import Path as _P

    from eide_core.ledger import event_kinds

    ma = "\n".join(p.read_text(encoding="utf-8", errors="replace")
                   for p in _P("src").rglob("*.py"))
    can_board = {"discover.result"}
    thieu = []
    for k in sorted(event_kinds()):
        if k in can_board:
            continue
        e = _re.escape(k)
        mau = rf"""append\(\s*["']{e}["']|_log\(\s*["']{e}["']|KIND\s*=\s*["']{e}["']"""
        if not _re.search(mau, ma):
            thieu.append(k)
    assert not thieu, f"kiểu sự kiện khai trong API-15 §5 mà không chỗ nào phát: {thieu}"


# ---------------------------------------------------------------- DEV-090: to_code


def test_to_code_sinh_patch_bang_CAY_CU_PHAP(du_an):
    """DIAGRAM-14 `to_code`. Chèn TRƯỚC `default:` — đặt sau nó là viết một nhánh không bao giờ
    chạy tới, mà trình dịch không báo và người đọc thì tin là nó có tác dụng."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    # Lược đồ 4 trạng thái, mã có 3 → lệch 1/4 = 25%, dưới ngưỡng 34% của `TI_LE_LECH_LON`.
    # Lệch lớn hơn thì E3000 chặn trước, và đó là hành vi đúng — xem test riêng ở trên.
    _luoc_do(root, "dg_tc", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n  ST_RUN --> ST_WAIT\n"
                            "  ST_WAIT --> ST_ERR\n")
    _ma_c(root, "void f(void){\n    switch (state) {\n"
                "        case ST_IDLE:\n            break;\n"
                "        case ST_RUN:\n            break;\n"
                "        case ST_WAIT:\n            break;\n"
                "        default:\n            break;\n    }\n}\n")

    kq = sync({"diagram_id": "dg_tc", "direction": "to_code"}, ctx)
    assert kq["applied"] is False, "patch phải đi qua code.modify và cổng G3, không tự áp"
    noi_dung = kq["patch"]["files"][0]["content"]
    assert "case ST_ERR:" in noi_dung
    assert noi_dung.index("case ST_ERR:") < noi_dung.index("default:"), "phải chèn TRƯỚC default"
    assert "TODO" in noi_dung, "thân bịa ra trông y hệt thân đã viết — phải đánh dấu"


def test_to_code_KHONG_cham_switch_khong_phai_may_trang_thai(du_an):
    """Một `switch` trên mã lỗi hay trên ký tự không phải máy trạng thái. Chèn `case ST_…` vào
    đó là làm hỏng một hàm không liên quan."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    # `switch` trên mã lỗi, KHÔNG phải máy trạng thái. Mã vẫn có ba nhãn ST_ (ngoài switch) để
    # lệch ở dưới ngưỡng — bài này kiểm chỗ CHÈN, không kiểm cổng lệch.
    _luoc_do(root, "dg_tc2", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n  ST_RUN --> ST_WAIT\n"
                             "  ST_WAIT --> ST_X\n")
    # Ba phép GÁN trạng thái (thứ `_trang_thai_tu_ma` đọc được — nó không đọc phép so sánh),
    # để lệch ở dưới ngưỡng; `switch` duy nhất thì trên `err`.
    _ma_c(root, "int g(int err){\n    state = ST_IDLE;\n    state = ST_RUN;\n"
                "    state = ST_WAIT;\n"
                "    switch (err) {\n        case 1: return 2;\n    }\n    return 0;\n}\n")
    kq = sync({"diagram_id": "dg_tc2", "direction": "to_code"}, ctx)
    assert "patch" not in kq and "Không tìm thấy" in kq["reason"]


def test_to_code_giu_THUT_LE_cua_ma_quanh_no(du_an):
    """Patch phải trông như phần mã quanh nó — nếu không, lần `code.review` sau sẽ báo lỗi văn
    phong cho một thay đổi EIDE tự sinh."""
    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_tc3", "stateDiagram-v2\n  ST_A --> ST_C\n  ST_C --> ST_D\n"
                             "  ST_D --> ST_B\n")
    _ma_c(root, "void f(void){\n  switch (fsm_mode) {\n    case ST_A:\n      break;\n"
                "    case ST_C:\n      break;\n    case ST_D:\n      break;\n  }\n}\n")
    noi_dung = sync({"diagram_id": "dg_tc3", "direction": "to_code"}, ctx)["patch"]["files"][0]["content"]
    assert "\n    case ST_B:\n" in noi_dung, noi_dung


def test_to_code_patch_van_PHAN_TICH_duoc_bang_tree_sitter(du_an):
    """Bất biến cuối: mã sau khi vá phải còn là C hợp lệ. Một bộ sinh patch làm hỏng cú pháp thì
    tệ hơn hẳn không có nó."""
    import tree_sitter_c
    from tree_sitter import Language, Parser

    from eide.caps.diagram import sync

    _, ctx, root = du_an
    _luoc_do(root, "dg_tc4", "stateDiagram-v2\n  ST_IDLE --> ST_RUN\n  ST_RUN --> ST_WAIT\n"
                             "  ST_WAIT --> ST_ERR\n")
    _ma_c(root, "void f(void){\n    switch (state) {\n        case ST_IDLE:\n"
                "            break;\n        case ST_RUN:\n            break;\n"
                "        case ST_WAIT:\n            break;\n    }\n}\n")
    noi_dung = sync({"diagram_id": "dg_tc4", "direction": "to_code"}, ctx)["patch"]["files"][0]["content"]
    cay = Parser(Language(tree_sitter_c.language())).parse(noi_dung.encode())
    assert not cay.root_node.has_error, noi_dung
