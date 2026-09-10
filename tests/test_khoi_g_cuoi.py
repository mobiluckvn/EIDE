"""Bốn năng lực cuối của khối G — KG-09, REPORT-04, ENV-06, SEARCH-03.

CDS-12.2 KG-09 và SEARCH-03; CDS-12.5 REPORT-04; CDS-12.3 ENV-06; TGT-19 §8; SEC-25 §3.

Điểm chung: cả bốn trả lời câu hỏi *"lấy ở đâu ra"* — bằng chứng của một feature, lý do của một
quyết định, gói ISA của một kiến trúc, đoạn tài liệu của một hãng. Không cái nào sinh tri thức
mới; chúng chỉ nối những gì đã có lại cho người đọc.
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


@pytest.fixture
def du_an(tmp_path, workspace):
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    echo = EchoPort([{"text": "Cổng G-FACT tự duyệt fact f_0001 theo quy tắc G-FACT-01 "
                              "vì nó ở tầng vàng [G-FACT-01] [f_0001]."}] * 4)
    led = Ledger(tmp_path / "ledger.jsonl")
    r = Router(gate=PolicyGate(), ledger=led)
    res = r.invoke("project.create", {"text": "dự án khối G"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=led)
    ctx = Context(project_dir=root, extra={
        "gate": PolicyGate(), "ledger": led,
        "gateway": Gateway(config=cfg, ledger=led, ports={"gemini": echo, "claude": echo})})
    return r, ctx, root


# ================================================================ KG-09 evidence


def test_feature_passing_co_it_nhat_mot_evidence(du_an):
    """tc KG-09 nguyên văn: "Feature passing có ≥ 1 evidence".

    Một feature `passing` không có bằng chứng là một lời khẳng định không kiểm được — và cả
    FEATURES.json tồn tại để tránh đúng điều đó.
    """
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO tool_report (id, tool, passed, log_ref, at)"
                  " VALUES ('tr_1','test',1,'.eide/logs/t.log','2026-09-10T00:00:00Z')")
        c.execute("INSERT INTO measurement (id, kind, target, value, unit, at)"
                  " VALUES ('m_1','serial_expect','board','\"OK\"','','2026-09-10T00:00:00Z')")
        c.execute("INSERT INTO feature (id, title, status, evidence)"
                  " VALUES ('F-01','đọc IMU','passing','[\"tr_1\",\"m_1\"]')")
        c.commit()

    out = r.invoke("kg.evidence", {"id": "F-01"}, ctx).result
    loai = {e["kind"] for e in out["evidence"]}
    assert {"tool_report", "measurement"} <= loai
    assert any(e["id"] == "tr_1" and e["detail"]["tool"] == "test" for e in out["evidence"])


def test_evidence_cua_mot_fact(du_an):
    """`id` nhận cả `feature` lẫn `fact` (input_schema nói vậy). Bằng chứng của một fact là
    NGUỒN của nó — đó là câu trả lời cho "sao biết điều này"."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('src_1','stm32f411.svd','h1','svd','gold')")
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES"
                  " ('f_0001','chip:st.x/periph:I2C1','base_address','1073765376','src_1',"
                  " 'parser','gold',1.0,'reviewed','C')")
        c.commit()
    out = r.invoke("kg.evidence", {"id": "f_0001"}, ctx).result
    assert [e["kind"] for e in out["evidence"]] == ["source"]
    assert out["evidence"][0]["id"] == "src_1"


def test_khong_co_bang_chung_thi_tra_rong_khong_phai_loi(du_an):
    """`errors: []` — một feature chưa có bằng chứng là trạng thái BÌNH THƯỜNG (nó đang
    `failing`), không phải lỗi. Ném ở đây thì màn hình tiến độ không mở được."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO feature (id, title, status) VALUES ('F-02','chưa làm','failing')")
        c.commit()
    assert r.invoke("kg.evidence", {"id": "F-02"}, ctx).result["evidence"] == []


def test_bang_chung_khong_ton_tai_bi_bo(du_an):
    """`feature.evidence` là JSON tự do — một id trỏ vào hư không vẫn ghi được vào đó. Trả nó ra
    thì màn hình có một dòng bằng chứng không mở được, mà đó đúng là thứ khiến người ta thôi tin
    cả bảng."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO feature (id, title, status, evidence)"
                  " VALUES ('F-03','x','passing','[\"tr_khong_co\"]')")
        c.commit()
    assert r.invoke("kg.evidence", {"id": "F-03"}, ctx).result["evidence"] == []


# ================================================================ REPORT-04 explain


def test_co_ma_quy_tac_va_fact_id(du_an):
    """tc REPORT-04 nguyên văn: "Có mã quy tắc và fact id"."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO decision_log (id, gate, action_cap, risk, autonomy_level,"
                  " decision, by, rule, reason, at) VALUES"
                  " ('d_1','G-FACT','passport.import','R1','A2','APPROVE','policy','G-FACT-01',"
                  " 'fact tầng vàng','2026-09-10T00:00:00Z')")
        c.commit()
    out = r.invoke("report.explain", {"id": "d_1"}, ctx).result
    assert "G-FACT-01" in out["text"]


def test_khong_qua_150_tu(du_an):
    """Bước 1: "≤ 150 từ". Một lời giải thích dài hơn thứ nó giải thích thì không ai đọc — và
    câu hỏi "vì sao nó làm thế" là câu người ta hỏi khi đang vội."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO decision_log (id, gate, action_cap, risk, autonomy_level,"
                  " decision, by, rule, at) VALUES"
                  " ('d_2','G1','code.merge','R2','A2','ASK','human','G1-03',"
                  " '2026-09-10T00:00:00Z')")
        c.commit()
    out = r.invoke("report.explain", {"id": "d_2"}, ctx).result
    assert len(out["text"].split()) <= 150


def test_giai_thich_mot_fact(du_an):
    """`id` nhận `decision|commit|fact|plan`. Với một fact, câu trả lời phải nêu NGUỒN và tầng —
    đó là toàn bộ cơ sở để tin nó."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('src_2','stm32f411.svd','h2','svd','gold')")
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES"
                  " ('f_0002','chip:st.x/periph:I2C1','base_address','1073765376','src_2',"
                  " 'parser','gold',1.0,'reviewed','C')")
        c.commit()
    out = r.invoke("report.explain", {"id": "f_0002"}, ctx).result
    assert "f_0002" in out["text"] and "src_2" in out["text"]


def test_id_khong_biet_thi_noi_ro(du_an):
    """`errors: []` nên không ném — nhưng cũng KHÔNG được bịa. "Không tra được id này" là một
    câu trả lời hợp lệ; một đoạn văn trôi chảy về một quyết định không tồn tại thì không."""
    r, ctx, root = du_an
    out = r.invoke("report.explain", {"id": "khong_biet_gi"}, ctx).result
    assert "khong_biet_gi" in out["text"]
    assert "không tra được" in out["text"].lower() or "không tìm thấy" in out["text"].lower()


# ================================================================ ENV-06 install_pack


def _pack(tmp_path, isa="rv32imac", ky=True):
    d = tmp_path / "packs" / isa
    d.mkdir(parents=True, exist_ok=True)
    man = {"id": isa, "kind": "isa", "version": "1.0.0",
           "files": ["isa.yaml", "skills/i2c.md"], "license": "Apache-2.0"}
    (d / "manifest.json").write_text(json.dumps(man, ensure_ascii=False), encoding="utf-8")
    (d / "isa.yaml").write_text(yaml.safe_dump({"id": isa, "family_patterns": ["^CH32V"]}),
                                encoding="utf-8")
    (d / "skills").mkdir(exist_ok=True)
    (d / "skills" / "i2c.md").write_text("# I2C\n", encoding="utf-8")
    if ky:
        import hashlib
        h = hashlib.sha256()
        for f in sorted(man["files"]):
            h.update((d / f).read_bytes())
        (d / "manifest.sig").write_text(h.hexdigest(), encoding="utf-8")
    return d


def test_them_ISA_khong_sua_core(du_an, tmp_path, monkeypatch):
    """tc ENV-06 nguyên văn: "TC-48 thêm ISA không sửa core".

    Đây là bài kiểm về KIẾN TRÚC, không phải về một lệnh cài: một ISA mới phải vào được hệ
    thống bằng cách thả gói vào thư mục pack, không bằng cách sửa một bảng trong mã. Nếu phải
    sửa `src/` thì mọi ISA cộng đồng đều chờ một bản phát hành của EIDE.
    """
    import hashlib

    r, ctx, root = du_an
    d = _pack(tmp_path)
    import eide.caps.env as m
    monkeypatch.setattr(m, "_kho_pack", lambda: tmp_path / "packs")

    truoc = hashlib.sha256(
        b"".join(sorted(p.read_bytes() for p in (spec_dir() / "isa").glob("*.yaml")))).hexdigest()
    out = r.invoke("env.install_pack", {"isa": "rv32imac"}, ctx).result

    assert "isa.yaml" in json.dumps(out["installed"], ensure_ascii=False)
    sau = hashlib.sha256(
        b"".join(sorted(p.read_bytes() for p in (spec_dir() / "isa").glob("*.yaml")))).hexdigest()
    assert sau == truoc, "cài pack đã sửa docs/spec/isa — ISA mới phải vào bằng gói, không bằng sửa core"
    assert d.exists()


def test_chu_ky_sai_bao_E4004(du_an, tmp_path, monkeypatch):
    """Bước 1: "kiểm chữ ký". Một gói ISA quyết định lệnh dựng và cách nạp chip — chạy một gói
    đã bị sửa là để người khác chọn tham số cho `target.flash`."""
    r, ctx, root = du_an
    d = _pack(tmp_path)
    (d / "isa.yaml").write_text("id: rv32imac\nfamily_patterns: ['^HACKED']\n", encoding="utf-8")
    import eide.caps.env as m
    monkeypatch.setattr(m, "_kho_pack", lambda: tmp_path / "packs")

    run = r.invoke("env.install_pack", {"isa": "rv32imac"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4004"


def test_chua_co_pack_thi_chi_sang_registry_pull(du_an, tmp_path, monkeypatch):
    """`registry.pull` là mốc M4 nên chưa tải được gói. Nói thẳng kèm năng lực cần chạy, đừng
    im lặng trả rỗng như thể đã cài xong."""
    r, ctx, root = du_an
    import eide.caps.env as m
    monkeypatch.setattr(m, "_kho_pack", lambda: tmp_path / "packs")
    run = r.invoke("env.install_pack", {"isa": "xtensa"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4004"
    assert "registry.pull" in run.error.get("candidates", [])


def test_cai_lai_khong_nhan_doi(du_an, tmp_path, monkeypatch):
    r, ctx, root = du_an
    _pack(tmp_path)
    import eide.caps.env as m
    monkeypatch.setattr(m, "_kho_pack", lambda: tmp_path / "packs")
    r.invoke("env.install_pack", {"isa": "rv32imac"}, ctx)
    out = r.invoke("env.install_pack", {"isa": "rv32imac"}, ctx).result
    dich = root / ".eide" / "packs" / "rv32imac"
    assert len(list(dich.rglob("isa.yaml"))) == 1
    assert out["installed"]


# ================================================================ SEARCH-03 docs_mcp


class _McpGia:
    """Một docs server MCP tối thiểu, trả lời trong tiến trình — đủ để kiểm hợp đồng mà không
    cần dịch vụ ngoài."""

    def __init__(self, n=8):
        self.n = n
        self.da_hoi = []

    def tim(self, query, vendor):
        self.da_hoi.append((query, vendor))
        return [{"text": f"đoạn {i} về {query}", "url": f"https://docs/{i}",
                 "date": "2026-01-01", "sdk_version": "v5.2"} for i in range(self.n)]


def test_gioi_han_5_doan(du_an, monkeypatch):
    """Bước 1: "giới hạn 5 đoạn". Ngữ cảnh là tài nguyên có hạn (CXD-10 §3): mười đoạn tài liệu
    hãng đẩy fact của chính dự án ra khỏi ngân sách."""
    r, ctx, root = du_an
    gia = _McpGia()
    import eide.caps.search as m
    monkeypatch.setattr(m, "_docs_mcp_client", lambda ctx, vendor: gia)
    out = r.invoke("search.docs_mcp", {"query": "esp_timer", "vendor": "espressif"}, ctx).result
    assert len(out["snippets"]) == 5


def test_luu_Source_kind_docs_mcp(du_an, monkeypatch):
    """Bước 1: "lưu Source kind=docs_mcp". Một đoạn tài liệu không có `source` thì fact rút từ
    nó sau này không trỏ về đâu được — và `passport.query` mất phần trích dẫn."""
    r, ctx, root = du_an
    import eide.caps.search as m
    monkeypatch.setattr(m, "_docs_mcp_client", lambda ctx, vendor: _McpGia(2))
    r.invoke("search.docs_mcp", {"query": "nrf_gpio", "vendor": "nordic"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute("SELECT kind, uri, tier FROM source WHERE kind='docs_mcp'").fetchall()
    assert len(rows) == 2 and all(x[2] == "silver" for x in rows)


def test_du_an_sensitive_bao_E8002(du_an, monkeypatch):
    """`errors`: "E8002 nếu sensitive và query chứa nội dung dự án". Gửi tên module nội bộ tới
    một dịch vụ ngoài là rò rỉ — và với dự án đánh dấu nhạy cảm thì đó là điều SEC-25 §3 cấm."""
    r, ctx, root = du_an
    import eide.caps.search as m
    monkeypatch.setattr(m, "_docs_mcp_client", lambda ctx, vendor: _McpGia())
    cfg = yaml.safe_load((root / ".eide" / "constraints.yaml").read_text(encoding="utf-8"))
    cfg["sensitive"] = True
    (root / ".eide" / "constraints.yaml").write_text(
        yaml.safe_dump(cfg, allow_unicode=True), encoding="utf-8")

    run = r.invoke("search.docs_mcp", {"query": "dự án khối G dùng gpio thế nào",
                                       "vendor": "espressif"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E8002"


def test_sensitive_nhung_query_chung_chung_thi_duoc(du_an, monkeypatch):
    """Vế thứ hai của điều kiện: "và query chứa nội dung dự án". Chặn MỌI truy vấn của một dự án
    nhạy cảm là tắt hẳn năng lực — mà hỏi "esp_timer dùng thế nào" không rò rỉ gì cả."""
    r, ctx, root = du_an
    import eide.caps.search as m
    monkeypatch.setattr(m, "_docs_mcp_client", lambda ctx, vendor: _McpGia(1))
    cfg = yaml.safe_load((root / ".eide" / "constraints.yaml").read_text(encoding="utf-8"))
    cfg["sensitive"] = True
    (root / ".eide" / "constraints.yaml").write_text(
        yaml.safe_dump(cfg, allow_unicode=True), encoding="utf-8")

    out = r.invoke("search.docs_mcp", {"query": "esp_timer_create", "vendor": "espressif"},
                   ctx).result
    assert len(out["snippets"]) == 1


def test_khong_cau_hinh_server_bao_E4004(du_an):
    """Chưa cấu hình docs server nào: E4004 kèm cách cấu hình. Trả rỗng thì bên gọi đọc thành
    "hãng không có tài liệu về cái này"."""
    r, ctx, root = du_an
    run = r.invoke("search.docs_mcp", {"query": "x", "vendor": "espressif"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4004"
