"""Trường `fact.conflicts_with` — DDD-14 §2 v1.4 (DEV-077, chủ sản phẩm duyệt 10/09/2026).

Cạnh `CONFLICTS_WITH` của KAD-07 §6.3 tới nay chỉ SUY được: `kg.mau_thuan` ghép các fact cùng
(subject, predicate) khác giá trị. Nhưng errata phủ định datasheet theo một cách mà phép suy ấy
không thấy — mục errata là `predicate: other` với subject riêng, nên nó không bao giờ trùng cặp
khoá với fact nó phủ định. Cạnh phải KHAI được, và chỗ khai là một trường trên chính fact.

Hai đường sinh cạnh cùng tồn tại sau thay đổi này, và đó là chủ ý: suy vẫn bắt được mâu thuẫn
mà không ai nhận ra, khai bắt được mâu thuẫn mà chỉ người đọc tài liệu mới biết.
"""
from __future__ import annotations

import json
import sqlite3

import pytest

from eide_core import kg as kg_core
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

PART = "st.stm32f411ce"


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án xung đột"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('src_ds','stm32f411-ds.pdf','h1','pdf','silver')")
        c.commit()
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _fact(root, fid, subject, predicate="timing", value='"400kHz"', conflicts=None):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer, conflicts_with) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                  (fid, subject, predicate, value, "src_ds", "parser", "silver", 1.0,
                   "normalized", "C", json.dumps(conflicts) if conflicts else None))
        c.commit()


# ================================================================ schema và migration


def test_cot_conflicts_with_co_trong_store(du_an):
    """Migration phải tạo cột — `test_migration_khop_schema_sql` giữ nó khớp `schema.sql`, còn
    test này giữ nó tồn tại thật trong một store vừa dựng."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        cot = {x[1] for x in c.execute("PRAGMA table_info(fact)").fetchall()}
    assert "conflicts_with" in cot


def test_store_cu_di_tru_len_khong_mat_du_lieu(tmp_path):
    """Store đã có dữ liệu ở phiên bản trước phải lên được phiên bản mới mà giữ nguyên fact.

    `ALTER TABLE ADD COLUMN` là phép an toàn, nhưng "an toàn về lý thuyết" và "đã chạy trên một
    store có dữ liệu" là hai điều khác nhau — và store của người dùng là thứ không có bản sao.
    """
    db = tmp_path / "store.sqlite"
    store.migrate(db, target=5)
    # sqlite3 trực tiếp, không `open_store`: hàm ấy TỪ CHỐI một store chưa di trú tới bản mới
    # nhất (E6003) — đúng thiết kế, và đây chính là cái ta đang dựng lại để thử.
    with sqlite3.connect(db) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('s1','x','h','pdf','silver')")
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES"
                  " ('f_a','chip:x/periph:I2C1','timing','\"400kHz\"','s1','parser','silver',"
                  " 1.0,'normalized','C')")
        c.commit()

    store.migrate(db)
    with store.open_store(db) as c:
        assert c.execute("SELECT COUNT(*) FROM fact").fetchone()[0] == 1
        assert c.execute("SELECT conflicts_with FROM fact WHERE id='f_a'").fetchone()[0] is None
        assert store.current_version(c) == store.LATEST_VERSION


# ================================================================ kg: cạnh khai tay


def test_canh_CONFLICTS_WITH_tu_truong_khai(du_an):
    """Điều cả thay đổi này sinh ra để làm được: hai fact KHÁC (subject, predicate) vẫn nối được
    với nhau khi một bên khai rõ nó phủ định bên kia."""
    r, ctx, root = du_an
    _fact(root, "f_ds", f"chip:{PART}/periph:I2C1", "timing", '"400kHz"')
    _fact(root, "f_er", f"chip:{PART}/periph:I2C1/errata:2.4.1", "other",
          '{"kind":"errata","title":"I2C tối đa 100 kHz ở rev A"}', conflicts=["f_ds"])

    with store.open_store(store.store_path(root)) as c:
        g = kg_core.dung(c)
    canh = {(a, b) for a, k, b in g.canh if k == "CONFLICTS_WITH"}
    assert ("f_er", "f_ds") in canh


def test_van_giu_duong_suy_tu_du_lieu(du_an):
    """Đường SUY (cùng subject + predicate, khác giá trị) không được mất: nó bắt loại mâu thuẫn
    mà không ai khai — hai lần trích cùng một thanh ghi ra hai địa chỉ khác nhau."""
    r, ctx, root = du_an
    _fact(root, "f_1", f"chip:{PART}/periph:I2C1", "base_address", "1073765376")
    _fact(root, "f_2", f"chip:{PART}/periph:I2C1", "base_address", "999")

    with store.open_store(store.store_path(root)) as c:
        g = kg_core.dung(c)
    canh = {frozenset((a, b)) for a, k, b in g.canh if k == "CONFLICTS_WITH"}
    assert frozenset(("f_1", "f_2")) in canh


def test_khong_nhan_id_khong_ton_tai(du_an):
    """Một `conflicts_with` trỏ vào fact không có trong store là một cạnh treo. Vẽ nó ra thì đồ
    thị có một nút không ai mở được, và `kg.conflicts` báo một xung đột không kiểm được."""
    r, ctx, root = du_an
    _fact(root, "f_er", f"chip:{PART}/errata:x", "other", '{"kind":"errata"}',
          conflicts=["f_khong_co"])
    with store.open_store(store.store_path(root)) as c:
        g = kg_core.dung(c)
    assert not [1 for a, k, b in g.canh if k == "CONFLICTS_WITH"]


def test_khong_nhan_fact_da_bi_thay(du_an):
    """Fact `superseded` ở lại store để truy nguyên nhưng không vào đồ thị (KAD-07 §6.3). Nối
    một cạnh tới nó là dựng lại đúng thứ mà phép lọc ấy loại ra."""
    r, ctx, root = du_an
    _fact(root, "f_cu", f"chip:{PART}/periph:I2C1", "timing", '"400kHz"')
    with store.open_store(store.store_path(root)) as c:
        c.execute("UPDATE fact SET status='superseded' WHERE id='f_cu'")
        c.commit()
    _fact(root, "f_er", f"chip:{PART}/errata:x", "other", '{"kind":"errata"}',
          conflicts=["f_cu"])
    with store.open_store(store.store_path(root)) as c:
        g = kg_core.dung(c)
    assert not [1 for a, k, b in g.canh if k == "CONFLICTS_WITH"]


def test_kg_conflicts_liet_ke_ca_cap_khai(du_an):
    """`kg.conflicts` (KG-02) đọc cạnh CONFLICTS_WITH, nên nó phải thấy cả hai đường mà không
    cần sửa gì — đó là kiểm chứng rằng cạnh khai đi đúng vào cơ chế đã có."""
    r, ctx, root = du_an
    _fact(root, "f_ds", f"chip:{PART}/periph:I2C1", "timing", '"400kHz"')
    _fact(root, "f_er", f"chip:{PART}/errata:2.4.1", "other", '{"kind":"errata"}',
          conflicts=["f_ds"])
    ds = r.invoke("kg.conflicts", {}, ctx).result["conflicts"]
    # `nodes` mang object đầy đủ từ 15/09/2026 (xem `kg._hai_ben`): màn "Xung đột tri thức" dựng
    # hai cột cạnh nhau và cần giá trị, nguồn, tầng — với id trần thì cả hai cột chỉ hiện một mã
    # băm. `id` vẫn nằm trong mỗi node nên phép kiểm này vẫn hỏi đúng câu nó vốn hỏi.
    assert any({n["id"] for n in x["nodes"]} == {"f_er", "f_ds"} for x in ds)
    # Và `conflict_id` phải có mặt: `kg.resolve_conflict` đòi nó, còn `kg.conflicts` trước đây
    # không phát ra — nút "Chọn A" trên giao diện vì thế luôn gửi một id rỗng.
    assert all(x["id"].count(":") == 1 and all(x["id"].split(":")) for x in ds)


# ================================================================ passport.import ghi trường


def test_passport_import_ghi_conflicts_with(du_an):
    """Cổng ghi DUY NHẤT của store là `passport.import` (KAD-07 §5.1). Trường mới phải đi qua
    đó, nếu không thì mọi năng lực trích xuất đều không khai được cạnh nào."""
    r, ctx, root = du_an
    _fact(root, "f_ds", f"chip:{PART}/periph:I2C1", "timing", '"400kHz"')
    from eide.caps.passport import import_
    import_({"batch": {"facts": [{
        "subject": f"chip:{PART}/errata:2.4.1", "predicate": "other",
        "value": {"kind": "errata", "title": "x"}, "source_id": "src_ds", "method": "parser",
        "tier": "silver", "confidence": 0.8, "layer": "B", "conflicts_with": ["f_ds"]}],
        "passport_id": f"{PART}@1.0.0", "kind": "chip", "header": {"name": PART}},
        "actor": "test"}, ctx)

    with store.open_store(store.store_path(root)) as c:
        (gt,) = c.execute("SELECT conflicts_with FROM fact WHERE predicate='other'").fetchone()
    assert json.loads(gt) == ["f_ds"]


# ================================================================ EXTRACT-10 nối cạnh


def test_errata_noi_cach_CONFLICTS_WITH_voi_fact_bi_phu_dinh(du_an, monkeypatch, tmp_path):
    """Bước 1 của EXTRACT-10 nguyên văn: "liên kết CONFLICTS_WITH nếu mâu thuẫn datasheet".

    Mô hình chọn fact bị phủ định TRONG DANH SÁCH mã đưa cho nó — không tự nghĩ ra id. Đó là
    khác biệt giữa một cạnh có thật và một cạnh trông giống thật: id fact là chuỗi hex, và mô
    hình sinh ra chuỗi hex hợp lệ dễ như sinh ra một câu.
    """
    from pdf_gia_lap import pdf_bang_ke
    r, ctx, root = du_an
    _fact(root, "f_ds", f"chip:{PART}/periph:I2C1", "timing", '{"max": 400000}')

    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def __init__(self): self.prompt_cuoi = ""

        def run(self, role, prompt, schema=None, **k):
            self.prompt_cuoi = prompt
            return _R({"items": [{"title": "I2C1 analog filter may provide wrong value",
                                  "workaround": "tắt bộ lọc", "contradicts": ["f_ds"]}]})
    gw = _G()
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_gateway", lambda c: gw)

    bang = [["Section", "Errata title", "Rev A"],
            ["2.4.1", "I2C1 analog filter may provide wrong value", "A"]]
    p = str(pdf_bang_ke(tmp_path / "er.pdf", bang, tieu_de="Device limitations"))
    run = r.invoke("extract.pdf_errata", {"file": p, "part": PART}, ctx)
    r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)

    with store.open_store(store.store_path(root)) as c:
        (gt,) = c.execute("SELECT conflicts_with FROM fact WHERE predicate='other'").fetchone()
        g = kg_core.dung(c)
    assert json.loads(gt) == ["f_ds"]
    assert any(k == "CONFLICTS_WITH" and b == "f_ds" for _a, k, b in g.canh)
    # Danh sách ứng viên phải nằm trong prompt: mô hình không đoán id, nó CHỌN.
    assert "f_ds" in gw.prompt_cuoi


def test_id_mo_hinh_bia_ra_bi_bo(du_an, monkeypatch, tmp_path):
    """Mô hình trả một id không có trong danh sách ứng viên: bỏ, không ghi. Một cạnh treo trong
    hộ chiếu tệ hơn không có cạnh nào — nó làm `kg.conflicts` báo một xung đột không tra được."""
    from pdf_gia_lap import pdf_bang_ke
    r, ctx, root = du_an
    _fact(root, "f_ds", f"chip:{PART}/periph:I2C1", "timing", '{"max": 400000}')

    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def run(self, *a, **k):
            return _R({"items": [{"title": "I2C1 analog filter may provide wrong value",
                                  "contradicts": ["f_deadbeef"]}]})
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_gateway", lambda c: _G())

    bang = [["Section", "Errata title", "Rev A"],
            ["2.4.1", "I2C1 analog filter may provide wrong value", "A"]]
    p = str(pdf_bang_ke(tmp_path / "er.pdf", bang, tieu_de="Device limitations"))
    run = r.invoke("extract.pdf_errata", {"file": p, "part": PART}, ctx)
    r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)

    with store.open_store(store.store_path(root)) as c:
        (gt,) = c.execute("SELECT conflicts_with FROM fact WHERE predicate='other'").fetchone()
    assert gt is None


def test_khong_co_fact_ung_vien_thi_khong_hoi(du_an, monkeypatch, tmp_path):
    """Store chưa có fact nào của con chip ấy: không đưa danh sách rỗng rồi hỏi mô hình "cái nào
    bị phủ định" — đó là một câu hỏi không có câu trả lời đúng, và mô hình sẽ tìm cách trả lời."""
    from pdf_gia_lap import pdf_bang_ke
    r, ctx, root = du_an

    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def __init__(self): self.prompt_cuoi = ""

        def run(self, role, prompt, schema=None, **k):
            self.prompt_cuoi = prompt
            return _R({"items": [{"title": "I2C1 analog filter may provide wrong value"}]})
    gw = _G()
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_gateway", lambda c: gw)

    bang = [["Section", "Errata title", "Rev A"],
            ["2.4.1", "I2C1 analog filter may provide wrong value", "A"]]
    p = str(pdf_bang_ke(tmp_path / "er.pdf", bang, tieu_de="Device limitations"))
    run = r.invoke("extract.pdf_errata", {"file": p, "part": PART}, ctx)
    r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)
    assert "fact ứng viên" not in gw.prompt_cuoi


# ================================================================ spec ≡ mã


def test_schema_json_va_sql_deu_khai_truong_moi():
    """`docs/spec/data/json/fact.json` và `schema.sql` đều sinh từ `ddd_model.py`. Sửa tay một
    bên là để hai bên trôi khỏi nhau — `make check-gen` chặn điều đó, còn test này bắt trường
    hợp cả hai chưa được sinh lại."""
    from eide_core.paths import spec_dir
    d = json.loads((spec_dir() / "data" / "json" / "fact.json").read_text(encoding="utf-8"))
    assert "conflicts_with" in d["properties"]
    assert "conflicts_with" not in d["required"]
    assert "conflicts_with" in (spec_dir() / "data" / "schema.sql").read_text(encoding="utf-8")


def test_migration_va_schema_sql_cung_kieu(tmp_path):
    """Kiểu cột phải khớp: `TEXT` chứa JSON, cùng khuôn `cites`/`uses` của CodeUnit. Một cột
    khai `TEXT` ở spec mà migration dựng kiểu khác sẽ chỉ lộ ra khi có dữ liệu thật."""
    from eide_core.paths import spec_dir
    db = tmp_path / "store.sqlite"
    store.migrate(db)
    ref = tmp_path / "ref.sqlite"
    with sqlite3.connect(ref) as c:
        c.executescript((spec_dir() / "data" / "schema.sql").read_text(encoding="utf-8"))
    with sqlite3.connect(db) as a, sqlite3.connect(ref) as b:
        ta = {x[1]: x[2] for x in a.execute("PRAGMA table_info(fact)")}
        tb = {x[1]: x[2] for x in b.execute("PRAGMA table_info(fact)")}
    assert ta["conflicts_with"] == tb["conflicts_with"] == "TEXT"
