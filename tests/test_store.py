"""WI-002 — SQLite store và di trú.

Spec: DDD-14 §5 (bảng lịch migration, quy trình `eide migrate`), docs/spec/data/schema.sql (DDL),
API-15 §3 E6003 MIGRATION_REQUIRED, API-15 §5 sự kiện ledger `store.migrate` {from_version, to_version}.

Mỗi câu trong §5 thành ít nhất một test: "đọc PRAGMA user_version", "chạy tuần tự các migration
còn thiếu TRONG MỘT GIAO DỊCH", "ghi ledger store.migrate", "sao lưu store.sqlite.bak-<version>
TRƯỚC khi chạy", "migration chỉ thêm bảng/cột (không xóa)".
"""
from __future__ import annotations

import sqlite3

import pytest

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.store import (
    LATEST_VERSION,
    current_version,
    migrate,
    migrations,
    open_index,
    open_store,
)

# Lịch migration đúng như DDD-14 §5. Viết lại ở đây CỐ Ý: nếu ai sửa tệp .sql mà quên sửa tài
# liệu (hoặc ngược lại), test này đỏ. Đó là chỗ duy nhất bắt được sai lệch ấy.
BANG_M0 = {"source", "fact", "passport", "passport_fact", "code_unit", "feature", "tool_report"}
BANG_M1 = {"acq_request", "permission", "decision_log", "capability_run", "intent", "run",
           "error_ledger", "preference", "capability", "requirement", "diagram"}
# `session` KHÔNG ở store.sqlite: DDD-14 §2.25 ghi "Phiên làm việc (session.sqlite, không
# commit)" — cơ sở dữ liệu riêng như rag_chunk ở index.sqlite. Xem DEVIATIONS DEV-006.
BANG_SESSION = {"session"}
BANG_M2 = {"module", "hw_map", "adr", "doc_artifact", "discovery", "measurement"}
BANG_M3 = {"debug_session"}


def tables(conn: sqlite3.Connection) -> set[str]:
    rows = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
    return {r[0] for r in rows if not r[0].startswith("sqlite_")}


def columns(conn: sqlite3.Connection, table: str) -> set[str]:
    return {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}


# ---------- quy trình di trú (DDD-14 §5) ----------

def test_migrate_kho_moi_len_phien_ban_moi_nhat(tmp_path):
    db = tmp_path / "store.sqlite"
    kq = migrate(db)
    assert kq["from_version"] == 0
    assert kq["to_version"] == LATEST_VERSION == 6
    assert [m["name"] for m in kq["applied"]] == ["0001_m0_base", "0002_m1_policy_runtime",
                                                  "0004_m2_engineering_hw",
                                                  "0005_m2_module_layer",
                                                  "0006_m2_fact_conflicts"]
    with sqlite3.connect(db) as c:
        assert tables(c) == BANG_M0 | BANG_M1 | BANG_M2
        assert "session" not in tables(c), "session thuộc session.sqlite, không thuộc store"
        assert current_version(c) == 6


def test_migrate_chay_lai_khong_lam_gi(tmp_path):
    """"chạy tuần tự các migration CÒN THIẾU" — lần hai không còn thiếu gì."""
    db = tmp_path / "store.sqlite"
    migrate(db)
    kq = migrate(db)
    assert kq["applied"] == []
    assert kq["from_version"] == kq["to_version"] == LATEST_VERSION


def test_migrate_sao_luu_truoc_khi_chay(tmp_path):
    """"sao lưu store.sqlite.bak-<version> TRƯỚC khi chạy" — tên mang phiên bản CŨ."""
    db = tmp_path / "store.sqlite"
    migrate(db, target=1)                      # dừng ở v1 để lần sau có việc để làm
    assert not list(tmp_path.glob("*.bak-*"))  # kho mới tinh thì không có gì để sao lưu
    kq = migrate(db)
    bak = tmp_path / "store.sqlite.bak-1"
    assert bak.exists() and kq["backup"] == str(bak)
    with sqlite3.connect(bak) as c:
        assert current_version(c) == 1         # bản sao là trạng thái TRƯỚC khi di trú


def test_migrate_ghi_ledger_store_migrate(tmp_path):
    """API-15 §5: sự kiện `store.migrate` với trường {from_version, to_version}."""
    led = Ledger(tmp_path / "ledger.jsonl")
    migrate(tmp_path / "store.sqlite", ledger=led)
    recs = [r for r in led.records() if r["kind"] == "store.migrate"]
    assert len(recs) == 1
    assert recs[0]["data"] == {"from_version": 0, "to_version": 6,
                               "applied": ["0001_m0_base", "0002_m1_policy_runtime",
                                           "0004_m2_engineering_hw",
                                           "0005_m2_module_layer",
                                           "0006_m2_fact_conflicts"]}
    assert led.verify() == (True, 0)


def test_migrate_mot_giao_dich_hong_thi_khong_doi_gi(tmp_path, monkeypatch):
    """"chạy ... TRONG MỘT GIAO DỊCH" — 0002 hỏng thì user_version phải vẫn là 0, không phải 1."""
    db = tmp_path / "store.sqlite"
    that = migrations()

    def hong():
        xau = [dict(m) for m in that]
        xau[1] = {**xau[1], "sql": "CREATE TABLE khong_hop_le ("}
        return xau

    monkeypatch.setattr("eide_core.store.migrations", hong)
    with pytest.raises(sqlite3.Error):
        migrate(db)
    with sqlite3.connect(db) as c:
        assert current_version(c) == 0
        assert tables(c) == set()


def test_migrate_chi_them_khong_xoa(tmp_path):
    """"migration chỉ thêm bảng/cột (không xóa) cho tới v1.0"."""
    db = tmp_path / "store.sqlite"
    migrate(db, target=1)
    with sqlite3.connect(db) as c:
        sau_0001 = tables(c)
    migrate(db)
    with sqlite3.connect(db) as c:
        assert sau_0001 <= tables(c)


# ---------- hai chỗ cố ý khác schema.sql, do §5 quy định ----------

def test_fact_layer_them_o_0002(tmp_path):
    """§5: cột `fact.layer` thuộc 0002, không phải 0001."""
    db = tmp_path / "store.sqlite"
    migrate(db, target=1)
    with sqlite3.connect(db) as c:
        assert "layer" not in columns(c, "fact")
    migrate(db)
    with sqlite3.connect(db) as c:
        assert "layer" in columns(c, "fact")
        c.execute("INSERT INTO source (id,uri,kind,tier) VALUES ('s1','file:///a','pdf','T1')")
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,confidence,status)"
                  " VALUES ('f1','stm32','vdd','3.3','s1','extract','T1',0.9,'confirmed')")
        assert c.execute("SELECT layer FROM fact WHERE id='f1'").fetchone()[0] == "C"


def test_code_unit_chua_co_module_id_o_m1(tmp_path):
    """§5 xếp `code_unit.module_id` vào 0004 (M2) cùng bảng `module` mà nó tham chiếu.

    Dừng ở `target=2` để kiểm ĐÚNG điều §5 nói: cột và bảng ấy KHÔNG thuộc M1. Đổi test thành
    "sau khi migrate đầy đủ thì có module_id" sẽ mất mất khẳng định về mốc — mà mốc mới là thứ
    §5 quy định, còn việc cuối cùng cột ấy tồn tại thì test dưới đã nói rồi.
    """
    db = tmp_path / "store.sqlite"
    migrate(db, target=2)
    with sqlite3.connect(db) as c:
        assert "module_id" not in columns(c, "code_unit")
        assert "module" not in tables(c)


def test_code_unit_co_module_id_sau_0004(tmp_path):
    """Vế còn lại: khóa ngoại `code_unit.module_id → module(id)` chỉ dựng được sau khi có bảng
    `module`, nên thứ tự trong 0004 (module trước ALTER) là ràng buộc chứ không phải sở thích."""
    db = tmp_path / "store.sqlite"
    migrate(db)
    with sqlite3.connect(db) as c:
        assert "module_id" in columns(c, "code_unit")
        assert {"module", "hw_map", "adr"} <= tables(c)


# ---------- mã ≡ spec ----------

def test_migration_khop_schema_sql(tmp_path):
    """Mọi bảng và cột dựng bởi migration phải khớp docs/spec/data/schema.sql.

    schema.sql là ảnh chụp mô hình ĐẦY ĐỦ (sau mọi migration), nên phép so là: tập bảng M0+M1
    phải là con của schema.sql, và với từng bảng ấy, cột phải khớp — trừ hai chỗ §5 dời sang
    migration sau, đã có test riêng ở trên.
    """
    db = tmp_path / "store.sqlite"
    migrate(db)
    ref = tmp_path / "ref.sqlite"
    with sqlite3.connect(ref) as c:
        c.executescript((spec_dir() / "data" / "schema.sql").read_text(encoding="utf-8"))
    doi_sau: set[tuple[str, str]] = set()    # 0004 đã chạy: không còn cột nào dời sang sau
    with sqlite3.connect(db) as a, sqlite3.connect(ref) as b:
        assert tables(a) <= tables(b)
        for t in sorted(tables(a)):
            thieu = columns(b, t) - columns(a, t)
            assert thieu == {c for tb, c in doi_sau if tb == t}, f"bảng {t}: lệch cột {thieu}"
            assert not (columns(a, t) - columns(b, t)), f"bảng {t}: có cột không nằm trong spec"


def test_lich_migration_phu_het_schema_sql(tmp_path):
    """Không bảng nào trong schema.sql bị bỏ quên giữa các mốc.

    Đây là test đã bắt được DEV-006: `session` có trong schema.sql và DDD-14 §2.25 ("từ M1")
    nhưng bảng lịch §5 không xếp nó vào migration nào.
    """
    ref = tmp_path / "ref.sqlite"
    with sqlite3.connect(ref) as c:
        c.executescript((spec_dir() / "data" / "schema.sql").read_text(encoding="utf-8"))
        # Ba nhóm ra khỏi store chính: rag_chunk* ở index.sqlite (§5 migration 0003),
        # session ở session.sqlite (§2.25)
        het = {t for t in tables(c) if not t.startswith("rag_chunk")} - BANG_SESSION
    assert het == BANG_M0 | BANG_M1 | BANG_M2 | BANG_M3


# ---------- mở store ----------

def test_open_store_bao_E6003_khi_user_version_cu(tmp_path):
    """API-15 E6003 MIGRATION_REQUIRED — "user_version cũ", cách xử lý: `eide migrate`."""
    db = tmp_path / "store.sqlite"
    migrate(db, target=1)
    with pytest.raises(EideError) as ei:
        open_store(db)
    assert ei.value.code == "E6003"
    assert ei.value.data == {"found": 1, "expected": LATEST_VERSION, "remedy": "eide migrate"}


def test_open_store_bao_E6003_khi_chua_co_kho(tmp_path):
    with pytest.raises(EideError) as ei:
        open_store(tmp_path / "chua-co.sqlite")
    assert ei.value.code == "E6003"


def test_open_store_bat_wal_va_foreign_keys(tmp_path):
    """DDD-14 §5 dòng đầu schema.sql: PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON."""
    db = tmp_path / "store.sqlite"
    migrate(db)
    with open_store(db) as c:
        assert c.execute("PRAGMA journal_mode").fetchone()[0].lower() == "wal"
        assert c.execute("PRAGMA foreign_keys").fetchone()[0] == 1
        with pytest.raises(sqlite3.IntegrityError):   # khóa ngoại được cưỡng chế thật
            c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                      "confidence,status) VALUES ('f','s','p','v','KHONG-CO','m','T1',0.5,'new')")


# ---------- index.sqlite riêng (§5, 0003) ----------

def test_index_db_co_rag_chunk_va_fts5(tmp_path):
    idx = tmp_path / "index.sqlite"
    with open_index(idx) as c:
        assert {"rag_chunk", "rag_chunk_fts"} <= tables(c)
        c.execute("INSERT INTO rag_chunk (id,source_id,text) VALUES ('c1','s1','thanh ghi GPIO ODR')")
        c.execute("INSERT INTO rag_chunk_fts (rowid,text) SELECT rowid,text FROM rag_chunk")
        hit = c.execute("SELECT rowid FROM rag_chunk_fts WHERE rag_chunk_fts MATCH 'GPIO'").fetchall()
        assert len(hit) == 1


def test_index_db_khong_nam_trong_day_user_version(tmp_path):
    """§5: "không migration trong store chính" — 0003 không được lọt vào dãy của store."""
    assert all(not m["name"].startswith("index") for m in migrations())


def test_session_db_rieng_khong_nam_trong_store(tmp_path):
    """DDD-14 §2.25: "Phiên làm việc (session.sqlite, không commit)".

    Đây là bản sửa của DEV-006. Bảng lịch migration §5 không xếp `session` vào migration nào
    của store chính KHÔNG phải vì bỏ sót, mà vì nó thuộc một cơ sở dữ liệu khác — đúng như
    `rag_chunk` thuộc index.sqlite.
    """
    db = tmp_path / "store.sqlite"
    migrate(db)
    with sqlite3.connect(db) as c:
        assert "session" not in tables(c)
    with store.open_session_db(tmp_path / "session.sqlite") as s:
        assert tables(s) == {"session"}
        s.execute("INSERT INTO session (id,project,opened_at) VALUES ('s_1','robot','2026-09-06T00:00:00Z')")
        assert s.execute("SELECT project FROM session").fetchone()[0] == "robot"


def test_session_db_khong_nam_trong_day_user_version():
    assert all(not m["name"].startswith("session") for m in migrations())


# ---------- niêm store sau khi năng lực ghi (tìm ra bằng scripts/nghiem_thu_sprint2.sh) ----------


def test_niem_van_khop_sau_khi_nang_luc_R0_ghi_store(tmp_path, workspace):
    """Niêm phải khớp sau MỌI năng lực ghi hợp lệ, kể cả năng lực lớp R0.

    Bản đầu để từng năng lực tự gọi `store.write_seal`; `req.*`, `arch.*`, `extract.*` quên, và
    không có gì báo vì `verify_seal` chỉ chạy lúc mở dự án. Bộ test cũng không thấy: mỗi test
    dùng store riêng và không ai kiểm niêm sau đó. Chỉ `scripts/nghiem_thu_sprint2.sh` chạy
    chuỗi thật bằng CLI mới lộ ra.

    Lần sửa thứ nhất lọc theo lớp rủi ro ("R0 chỉ đọc" — APD-08 §4.1) và VẪN sai: `req.ground_hw`
    là R0 mà có ghi `requirement.feasibility`. Nên bộ lọc cuối cùng dựa trên `mtime` của tệp
    store — không lớp rủi ro nào lách được, và rẻ hơn `content_digest` (~90 ms trên 20.000 fact).
    """
    from eide.caps.req import _ghi_requirement
    from eide_core.ledger import Ledger as _L
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=_L(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án niêm"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})

    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1','a.svd','h1','svd','gold')")
        c.execute("INSERT INTO fact (id, subject, predicate, value, unit, source_id, method,"
                  " tier, confidence, status) VALUES ('f_1','chip:x/mem:RAM','memory_size',"
                  "'131072','byte','s_1','parser','gold',1.0,'verified')")
        c.commit()
    _ghi_requirement(root, [{"id": "UR-01", "kind": "HW", "text": "RAM tối thiểu 64 kb"}])
    store.write_seal(store.store_path(root), r.ledger)      # niêm sạch trước khi thử

    run = r.invoke("req.ground_hw", {"reqset_ids": ["UR-01"], "passport": "x@1.0.0"}, ctx)
    assert run.status == "done"
    ok, ly_do = store.verify_seal(store.store_path(root))
    assert ok, f"niêm lệch sau req.ground_hw (R0 nhưng có ghi): {ly_do}"


def test_khong_niem_lai_khi_khong_ai_ghi(tmp_path, workspace, monkeypatch):
    """Vế còn lại: `content_digest` mất ~90 ms trên hộ chiếu lớn, mà `passport.query` có hợp
    đồng "< 200 ms". Niêm sau MỌI lời gọi thì một năng lực chỉ đọc cũng phải trả giá ấy."""
    from eide_core.ledger import Ledger as _L
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=_L(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án đọc"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    migrate(store.store_path(root), ledger=r.ledger)
    store.write_seal(store.store_path(root), r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})

    dem = {"n": 0}
    that = store.content_digest
    monkeypatch.setattr(store, "content_digest",
                        lambda c: (dem.__setitem__("n", dem["n"] + 1), that(c))[1])
    r.invoke("passport.query", {"part": "khong-co"}, ctx)
    assert dem["n"] == 0, "lời gọi chỉ đọc không được tính lại vân tay nội dung"
