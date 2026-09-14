import io
import json

from eide.daemon.rpc import Daemon, serve_stdio


def test_hello_and_caps_list():
    d = Daemon()
    r = d.handle({"jsonrpc": "2.0", "id": 1, "method": "plane.hello", "params": {"api_version": "1.2"}})
    assert r["result"]["caps"] == 238
    r = d.handle({"jsonrpc": "2.0", "id": 2, "method": "caps.list", "params": {"ns": "tool"}})
    assert len(r["result"]["caps"]) == 10


def test_version_mismatch_E1002():
    r = Daemon().handle({"jsonrpc": "2.0", "id": 1, "method": "plane.hello", "params": {"api_version": "2.0"}})
    assert r["error"]["data"]["eide_code"] == "E1002"


def test_stdio_roundtrip():
    inp = io.StringIO(json.dumps({"jsonrpc": "2.0", "id": 9, "method": "nope"}) + "\nkhông phải json\n")
    out = io.StringIO()
    serve_stdio(inp, out)
    lines = [json.loads(x) for x in out.getvalue().splitlines()]
    assert lines[0]["error"]["code"] == -32601 and lines[1]["error"]["code"] == -32700


# ---------- bề mặt panel (API-15 §1) — 22 phương thức thêm 12/09/2026

import pytest  # noqa: E402

from eide_core import store  # noqa: E402


@pytest.fixture
def du_an_rpc(tmp_path, workspace):
    """Daemon gắn vào một dự án thật — panel luôn nói chuyện trong ngữ cảnh một dự án."""
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "panel"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root))
    return Daemon(project=root), root


def _goi(d, ten, params=None):
    return d.handle({"jsonrpc": "2.0", "id": 1, "method": ten, "params": params or {}})


def test_moi_phuong_thuc_dang_ky_deu_CO_trong_spec():
    """Cổng chặn ngược: daemon không được bịa ra một phương thức ngoài `openrpc.json`.

    Cổng cũ trong `test_specs_consistency` đã canh điều này, nhưng nó dễ bị quên khi thêm hàng
    loạt như hôm nay — nên nhắc lại ở đây, cạnh chỗ người ta thật sự thêm phương thức.
    """
    import json as _json

    from eide_core.paths import spec_dir
    spec = {m["name"] for m in _json.loads(
        (spec_dir() / "api" / "openrpc.json").read_text(encoding="utf-8"))["methods"]}
    assert set(Daemon().methods) <= spec, sorted(set(Daemon().methods) - spec)


def test_alias_view_di_QUA_router_nen_co_ghi_nhat_ky(du_an_rpc):
    """Alias chứ không gọi thẳng handler: mỗi phương thức panel vẫn qua cổng chính sách và vẫn
    vào chuỗi băm. Một đường tắt sẽ nhanh hơn và sẽ bỏ qua cả hai."""
    d, _ = du_an_rpc
    truoc = len(d.ledger.records())
    _goi(d, "view.timeline", {"params": {}})
    sau = [x["kind"] for x in d.ledger.records()[truoc:]]
    assert "cap.run.start" in sau and "gate.decision" in sau


def test_alias_tra_RESULT_chu_khong_tra_ca_ban_ghi_luot_chay(du_an_rpc):
    """Panel gọi `view.*` muốn một đồ thị để vẽ, không muốn một bản ghi lượt chạy."""
    d, _ = du_an_rpc
    r = _goi(d, "view.timeline", {"params": {}})
    assert "result" in r and "status" not in r["result"], r["result"]


def test_sau_alias_LECH_TEN_tro_dung_nang_luc(du_an_rpc):
    """`view.coverage` → `view.coverage_map`. Tên RPC ngắn cho plugin gõ, tên năng lực nói rõ
    nó trả cái gì — bảng ALIAS là chỗ DUY NHẤT giữ ánh xạ ấy."""
    from eide.daemon.rpc import ALIAS
    from eide_core.registry import get_registry

    reg = get_registry()
    for ten_rpc, cap in ALIAS.items():
        assert cap in reg, f"{ten_rpc} → {cap} không phải năng lực nào"
        assert reg.get(cap).implemented, f"{ten_rpc} → {cap} chưa hiện thực"


def test_hex_resolve_tra_loi_cau_ai_noi_the(du_an_rpc):
    """Năng lực nhỏ nhất mà đúng tinh thần sản phẩm nhất: một con số trong khung hex trả lời
    được "ai nói thế". Tra theo GIÁ TRỊ chuẩn hoá nên `0x40005400` và `1073763328` cùng kết quả."""
    import hashlib
    import json as _json

    d, root = du_an_rpc
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s_h", "u", hashlib.sha256(b"s_h").hexdigest(), "svd", "gold", "vendor-doc"))
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  ("f_hex00000000aa", "chip:st.stm32f411/periph:I2C1", "base_address",
                   _json.dumps("0x40005400"), "s_h", "parser", "gold", 1.0, "verified", "A"))
        c.commit()

    for dia_chi in ("0x40005400", "1073763328"):
        r = _goi(d, "hex.resolve", {"address": dia_chi})["result"]
        assert r["subject"] == "chip:st.stm32f411/periph:I2C1", (dia_chi, r)
        assert r["facts"][0]["id"] == "f_hex00000000aa"


def test_hex_resolve_khong_tra_fact_CHUA_DUYET(du_an_rpc):
    """Khung hex là chỗ người ta tin ngay. Trả một fact `normalized` ở đó là khẳng định một con
    số chưa ai duyệt — cùng lý do `code.annotate` không gợi ý chúng."""
    import hashlib
    import json as _json

    d, root = du_an_rpc
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s_h2", "u", hashlib.sha256(b"s_h2").hexdigest(), "svd", "bronze", "unknown"))
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  ("f_hex00000000bb", "chip:x", "base_address", _json.dumps("0xDEAD"),
                   "s_h2", "parser", "bronze", 0.4, "normalized", "C"))
        c.commit()
    assert _goi(d, "hex.resolve", {"address": "0xDEAD"})["result"]["facts"] == []


def test_doc_open_tra_muc_LOI_THOI(du_an_rpc):
    """Panel mở tài liệu thì thấy ngay mục nào lỗi thời — không phải đi hỏi một lệnh khác."""
    import json as _json

    d, root = du_an_rpc
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO doc_artifact (id,type,path,lang,sections,stale_sections,at)"
                  " VALUES (?,?,?,?,?,?,?)",
                  ("doc_p", "SRS", "/x/a.md", "vi",
                   _json.dumps([{"heading": "A"}, {"heading": "B"}]),
                   _json.dumps(["B"]), "2026-09-12T00:00:00Z"))
        c.commit()
    r = _goi(d, "doc.open", {"path": "/x/a.md"})["result"]
    assert [s["heading"] for s in r["sections"]] == ["A", "B"] and r["stale"] == ["B"]


def test_doc_open_tep_khong_co_thi_tra_RONG_chu_khong_no(du_an_rpc):
    d, _ = du_an_rpc
    assert _goi(d, "doc.open", {"path": "/khong/co.md"})["result"] == {"sections": [], "stale": []}


def test_diagram_save_khong_co_id_thi_KHONG_bia_sync_diff(du_an_rpc):
    """Lược đồ mới gõ trong editor chưa có id thì không so được với gì — nói ra bằng cách vắng
    mặt trường ấy thật hơn là trả một diff rỗng trông như "không lệch"."""
    d, _ = du_an_rpc
    r = _goi(d, "diagram.save", {"src": "stateDiagram-v2\n  A --> B\n", "lang": "mermaid"})
    assert "sync_diff" not in r["result"], r["result"]


def test_log_stats_alias_tro_dung_debug_log_stats(du_an_rpc):
    d, root = du_an_rpc
    (root / "a.log").write_text("[1.0] INFO x\n[2.0] ERROR y\n", encoding="utf-8")
    r = _goi(d, "log.stats", {"params": {"file": "a.log"}})["result"]
    assert r["stats"]["lines"] == 2 and r["stats"]["levels"] == {"ERROR": 1, "INFO": 1}


# ---------- kênh sự kiện (API-15 §1 `event.*`) — thêm 12/09/2026

def test_thong_bao_di_CUNG_ong_dan_va_khong_co_id():
    """JSON-RPC 2.0 phân biệt trả lời và thông báo bằng trường `id`. Một ống dẫn là đủ — điều
    quan trọng với một daemon chạy làm tiến trình con của editor."""
    inp = io.StringIO(json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": "caps.list", "params": {"ns": "tool"}}) + "\n")
    out = io.StringIO()
    serve_stdio(inp, out)
    dong = [json.loads(x) for x in out.getvalue().splitlines()]
    tb = [x for x in dong if "id" not in x]
    tl = [x for x in dong if "id" in x]
    assert tl, "phải có câu trả lời"
    for x in tb:
        assert x["method"].startswith("event.") and "params" in x


def test_moi_su_kien_deu_CO_trong_so_cai(tmp_path, workspace):
    """Bất biến của kênh này, và là lý do nó phái sinh từ SỔ CÁI chứ không rắc lời gọi vào từng
    năng lực: **không có đường nào để giao diện hiện một việc mà sổ cái không có.**

    Cách kia — mỗi năng lực tự phát sự kiện — thì một năng lực mới là một chỗ có thể quên, và
    panel im lặng bỏ sót đúng việc vừa thêm.
    """
    thu = []
    d = Daemon(project=None, phat=lambda ten, p: thu.append((ten, p)))
    d.ctx.project_dir = workspace
    d.router.invoke("project.create", {"text": "kênh sự kiện"}, d.ctx)

    assert thu, "không sự kiện nào phát ra"
    seqs = {x["seq"] for _, x in thu if "seq" in x}
    so_cai = {r["seq"] for r in d.ledger.records()}
    assert seqs <= so_cai, sorted(seqs - so_cai)


def test_quyet_dinh_APPROVE_KHONG_bao_la_muc_cho_NHUNG_van_len_dong_thoi_gian(tmp_path, workspace):
    """`gate.decision` chỉ thành `event.gate.opened` khi nó THẬT SỰ mở một mục chờ.

    Báo một việc máy đã tự làm xong như "có mục cần anh duyệt" sẽ dạy người dùng bỏ qua thông
    báo — đúng thứ hỏng mà cả POL-17 lo.

    Nhưng "không phải mục chờ" KHÁC "không đáng cho người biết": ở mức tự chủ cao, thứ người cần
    giám sát nhất chính là những gì tác tử **tự duyệt**. Nên APPROVE/REJECT đi lên bằng
    `event.gate.decided` — cùng dữ liệu, khác tên, và giao diện xếp chúng vào dòng thời gian
    thay vì vào hàng đợi. Trước 14/09/2026 chúng bị bỏ hẳn (GIAM-SAT-UI, khoảng trống #6).
    """
    thu = []
    d = Daemon(project=None, phat=lambda ten, p: thu.append((ten, p)))
    d.ctx.project_dir = workspace
    d.router.invoke("project.create", {"text": "duyệt thẳng"}, d.ctx)

    cong = [p for ten, p in thu if ten == "event.gate.opened"]
    assert cong == [], f"APPROVE không được báo là mục chờ: {cong}"
    assert any(ten == "event.run.progress" for ten, _ in thu)

    quyet = [p for ten, p in thu if ten == "event.gate.decided"]
    assert quyet, "APPROVE phải lên dòng thời gian, không được biến mất"
    assert quyet[0]["decision"] == "APPROVE"
    assert quyet[0].get("rule"), "phải nói quy tắc nào đã quyết, để người còn truy lại được"


def test_nguoi_quan_sat_HONG_khong_lam_hong_so_cai(tmp_path):
    """Sổ cái là bằng chứng; thông báo cho giao diện thì không. Một panel đã đóng ống dẫn không
    được làm mất một dòng sổ cái."""
    from eide_core.ledger import Ledger

    led = Ledger(tmp_path / "l.jsonl")

    def no(_rec):
        raise BrokenPipeError("panel đã đóng")

    led.theo_doi(no)
    led.append("report", {"x": 1})
    assert len(led.records()) == 1 and led.verify() == (True, 0)


def test_noi_dung_gui_cho_mo_hinh_KHONG_len_giao_dien():
    """`model.call` nay LÊN giao diện — người phải thấy tác tử tiêu bao nhiêu token — nhưng
    **không mang theo nội dung**.

    Sổ cái đã che khoá API (`che_bi_mat`), nhưng che khoá khác với không gửi mã nguồn của người
    dùng ra một cửa sổ có thể đang chia sẻ màn hình. Màn chi phí cần con số và vai trò.
    `context.bundle` thì bị chặn ở mức bản ghi vì nó KHÔNG có gì ngoài nội dung.
    """
    from eide.daemon.rpc import KHONG_LEN_UI, SU_KIEN
    from eide_core.ledger import event_kinds

    assert SU_KIEN["model.call"] == "event.model.call"
    assert "context.bundle" in KHONG_LEN_UI
    assert set(SU_KIEN) <= event_kinds(), sorted(set(SU_KIEN) - event_kinds())

    thu = []
    d = Daemon(project=None, phat=lambda ten, p: thu.append((ten, p)))
    d.ledger.append("model.call", {"role": "librarian", "model": "x", "tokens_in": 900,
                                   "cost_usd": 0.01,
                                   "prompt": "mã nguồn riêng của người dùng"})
    goi = [p for ten, p in thu if ten == "event.model.call"]
    assert goi and goi[0]["tokens_in"] == 900 and goi[0]["cost_usd"] == 0.01
    assert "prompt" not in goi[0], "nội dung gửi mô hình không được ra giao diện"

    thu.clear()
    d.ledger.append("context.bundle", {"chunks": ["mã nguồn"]})
    assert thu == [], "`context.bundle` không có gì ngoài nội dung — chặn cả bản ghi"


def test_KHONG_phat_lai_lich_su_khi_KHONG_co_du_an(workspace):
    """Không có dự án thì sổ cái là `~/.eide/ledger.jsonl` — dùng chung cho MỌI dự án.

    Phát lại 200 dòng của nó là đổ lịch sử dự án khác vào cửa sổ vừa mở, và đổ trước cả phản
    hồi RPC đầu tiên. Đo được ngay khi thêm tính năng phát lại: `serve_stdio` trả ba dòng
    `event.*` của phiên trước rồi mới tới câu trả lời cho lời gọi hiện tại.
    """
    from eide.daemon.rpc import PHAT_LAI_KHI_MO

    thu = []
    d = Daemon(project=None, phat=lambda ten, p: thu.append((ten, p)))
    assert thu == [], f"daemon không dự án phát lại {len(thu)} sự kiện cũ"
    assert d._tail is not None and d._tail.phat_lai == 0

    co = Daemon(project=workspace, phat=lambda ten, p: None)
    assert co._tail is not None and co._tail.phat_lai == PHAT_LAI_KHI_MO


def test_moi_ten_su_kien_phat_ra_deu_CO_trong_openrpc():
    """Cổng chặn: daemon không được bịa ra một tên `event.*` ngoài spec."""
    from eide.daemon.rpc import SU_KIEN
    from eide_core.paths import spec_dir

    spec = {m["name"] for m in json.loads(
        (spec_dir() / "api" / "openrpc.json").read_text(encoding="utf-8"))["methods"]}
    assert set(SU_KIEN.values()) <= spec, sorted(set(SU_KIEN.values()) - spec)


def test_queue_changed_bat_muc_cho_sinh_ra_GIUA_chuoi(tmp_path, workspace):
    """Mục chờ sinh ra từ `caps.invoke`, từ `chat.send`, hay từ một nút giữa chuỗi đều đi qua
    cùng một hàng đợi — nên so trước/sau là phép đo duy nhất không bỏ sót đường nào."""
    from eide_core.policy import PolicyGate

    thu = []
    d = Daemon(project=None, phat=lambda ten, p: thu.append((ten, p)))
    d.ctx.project_dir = workspace
    # Ép một mục ASK: mức tự chủ A0 thì mọi thứ đều hỏi người. `project.create` là R2 nên nó
    # dừng ở cổng — và dừng khi CHƯA CÓ store để ghi hàng đợi vào, đúng tình huống mà `_id_cho`
    # phải hợp hai nguồn mới thấy.
    d.gate = PolicyGate(config={"autonomy": "A0"})
    d.router.gate = d.gate
    d.ctx.extra["gate"] = d.gate
    _goi(d, "caps.invoke", {"id": "project.create", "params": {"text": "hàng đợi"}})

    doi = [p for ten, p in thu if ten == "event.queue.changed"]
    assert doi and doi[0]["added"], thu


def test_ba_su_kien_phai_sinh_tu_KET_QUA_deu_co_trong_spec():
    """`doc.stale`, `diagram.stale`, `queue.changed` không suy được từ sổ cái — sổ cái biết CÓ
    ghi vào store, nhưng không biết MỤC NÀO vừa thành lỗi thời."""
    from eide_core.paths import spec_dir

    spec = {m["name"] for m in json.loads(
        (spec_dir() / "api" / "openrpc.json").read_text(encoding="utf-8"))["methods"]}
    for t in ("event.doc.stale", "event.diagram.stale", "event.queue.changed"):
        assert t in spec


# ---------- việc chạy nền (API-15: "tool nặng trả job_id trong result")

def test_nang_luc_NANG_tra_job_id_thay_vi_cho(du_an_rpc, monkeypatch):
    """Một panel treo vài chục giây là một panel người dùng nghĩ là đã chết."""
    import time

    d, root = du_an_rpc
    thu = []
    d.phat = lambda ten, p: thu.append((ten, p))
    (root / "a.log").write_text("INFO x\n", encoding="utf-8")

    import eide.daemon.rpc as m
    monkeypatch.setattr(m, "CAP_NANG", frozenset({"debug.log_stats"}))
    r = _goi(d, "caps.invoke", {"id": "debug.log_stats", "params": {"file": "a.log"}})["result"]
    assert r["status"] == "running" and r["job_id"].startswith("job_")

    for _ in range(100):
        st = _goi(d, "job.status", {"job_id": r["job_id"]})["result"]
        if st["state"] != "running":
            break
        time.sleep(0.02)
    assert st["state"] == "done" and st["progress"] == 100
    assert any(t == "event.job.progress" for t, _ in thu)


def test_KHONG_co_kenh_day_thi_van_dong_bo(du_an_rpc, monkeypatch):
    """Trả một `job_id` mà người gọi phải tự hỏi vòng là tệ hơn chờ. CLI và test gọi `handle()`
    trực tiếp vì thế vẫn đồng bộ như cũ."""
    import eide.daemon.rpc as m

    d, root = du_an_rpc
    (root / "b.log").write_text("INFO x\n", encoding="utf-8")
    monkeypatch.setattr(m, "CAP_NANG", frozenset({"debug.log_stats"}))
    assert d.phat is None
    r = _goi(d, "caps.invoke", {"id": "debug.log_stats", "params": {"file": "b.log"}})["result"]
    assert "job_id" not in r and r["status"] == "done"


def test_huy_la_HOP_TAC_va_noi_thang_the(du_an_rpc, monkeypatch):
    """Python không giết an toàn được một luồng đang chạy, còn giết tiến trình con giữa chừng
    thì để lại một `build/` nửa vời mà lần dựng sau tưởng là hợp lệ. Nói thẳng quan trọng hơn
    giả vờ ngược lại."""

    d, _ = du_an_rpc
    d.phat = lambda ten, p: None
    with d._khoa:
        d._jobs["job_test01"] = {"state": "running", "progress": 0, "log_tail": [],
                                 "cap": "code.build", "result": None, "cancel": False,
                                 "at": "2026-09-12T00:00:00Z"}
    st = _goi(d, "job.cancel", {"job_id": "job_test01"})["result"]
    assert st["state"] == "running", "vẫn đang chạy — hủy là xin, không phải giết"
    assert any("xin hủy" in x for x in st["log_tail"])


def test_viec_DA_XONG_thi_khong_gia_vo_da_huy(du_an_rpc):
    d, _ = du_an_rpc
    d.phat = lambda ten, p: None
    with d._khoa:
        d._jobs["job_test02"] = {"state": "done", "progress": 100, "log_tail": [],
                                 "cap": "x", "result": {"ok": 1}, "cancel": False,
                                 "at": "2026-09-12T00:00:00Z"}
    assert _goi(d, "job.cancel", {"job_id": "job_test02"})["result"]["state"] == "done"


def test_job_khong_ton_tai_thi_E2000(du_an_rpc):
    d, _ = du_an_rpc
    r = _goi(d, "job.status", {"job_id": "job_khongco"})
    assert r["error"]["data"]["eide_code"] == "E2000"


def test_moi_cap_NANG_deu_la_nang_luc_co_that():
    """Một id gõ sai trong `CAP_NANG` thì năng lực ấy lặng lẽ chạy đồng bộ mãi mãi — và không
    ai thấy, vì nó vẫn trả kết quả đúng."""
    from eide.daemon.rpc import CAP_NANG
    from eide_core.registry import get_registry

    reg = get_registry()
    la = [c for c in CAP_NANG if c not in reg]
    assert not la, la


def test_GIAO_DIEN_thay_viec_cua_TIEN_TRINH_KHAC(workspace):
    """Bất biến của cả tính năng giám sát (GIAM-SAT-UI §0.1).

    Dựng đúng hình dạng thật: một `Daemon` đóng vai cửa sổ EIDE đang mở, và một `Router` riêng
    đóng vai tác tử chạy qua CLI — hai đối tượng khác nhau, cùng một tệp `ledger.jsonl`. Trước
    14/09/2026 daemon chỉ nghe chính nó, nên phiên AVR chạy 28 lời gọi và ghi 105 sự kiện trong
    khi giao diện không hiện một dòng nào.
    """
    import time

    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    thu = []
    giao_dien = Daemon(project=workspace, phat=lambda ten, p: thu.append((ten, p)))
    try:
        so_tac_tu = Ledger(workspace / ".eide" / "store" / "ledger.jsonl")
        tac_tu = Router(gate=PolicyGate(), ledger=so_tac_tu)
        tac_tu.invoke("kg.conflicts", {}, Context(project_dir=workspace))

        het = time.monotonic() + 5
        while time.monotonic() < het and not any(t == "event.run.progress" for t, _ in thu):
            time.sleep(0.05)

        tien_do = [p for t, p in thu if t == "event.run.progress"]
        assert tien_do, "giao diện phải thấy việc tác tử chạy ở tiến trình khác"
        assert any(p.get("cap") == "kg.conflicts" for p in tien_do), [p.get("cap") for p in tien_do]
    finally:
        if giao_dien._tail is not None:
            giao_dien._tail.dung()


def test_moi_ten_su_kien_trong_SU_KIEN_deu_CO_trong_openrpc():
    """Năm sự kiện giám sát mới (`event.gate.decided`, `event.model.call`, `event.tool.report`,
    `event.project.changed`, `event.chat.intent`) phải có trong `openrpc.json`.

    CLAUDE.md cấm thêm tên phương thức JSON-RPC mà không qua spec; và một sự kiện daemon phát ra
    nhưng spec không khai là một sự kiện không plugin nào biết mà đón.
    """
    import json

    from eide.daemon.rpc import SU_KIEN
    from eide_core.paths import spec_dir

    khai = {m["name"] for m in json.loads(
        (spec_dir() / "api" / "openrpc.json").read_text(encoding="utf-8"))["methods"]}
    phat = set(SU_KIEN.values()) | {"event.gate.decided"}
    assert phat <= khai, sorted(phat - khai)
