"""Test GỌI THẬT — mạng, mô hình, công cụ ngoài. Không nằm trong `make check`.

    make check-net    # chỉ mạng, không cần khóa, không tốn tiền
    make check-llm    # gọi mô hình thật, cần khóa và tốn token

## Vì sao cần nhóm này

Giả lập chứng minh **mã của tôi đúng với giả định của tôi**. Nó không chứng minh giả định đúng
với đời thật. Ba loại giả định trong kho này chỉ đúng nếu thế giới bên ngoài còn như tài liệu
mô tả:

1. **Mẫu URL hãng** (TGT-19 §8) — đo lần đầu: **4/11 sai**. `STM32F411CE.svd` không tồn tại vì
   tệp SVD theo *die* chứ không theo mã vỏ; `nrfx/mdk` không còn tệp `.svd` nào. Cả hai trông
   hoàn toàn hợp lý trong YAML, và `search.vendor` vẫn trả về ứng viên — chỉ là mọi ứng viên
   đều 404.
2. **Hình dạng mô hình trả về** — giả lập luôn trả đúng khuôn. Mô hình thật trả JSON bọc trong
   dấu nháy ba, thiếu trường bắt buộc, lồng sai một tầng, hoặc từ chối. Mã đọc
   `resp.data["modules"]` thì im lặng ra rỗng.
3. **Tham số công cụ ngoài** — `mmdc -i x -o y` đúng thứ tự không? Không cài thì không ai biết.

## Vì sao KHÔNG để chúng trong `make check`

Máy chủ hãng có lúc chặn (403) hoặc hết giờ; gọi mô hình tốn tiền. Một test đỏ vì st.com giới
hạn tần suất là test người ta học cách bỏ qua — và khi đã học bỏ qua thì nó không còn bảo vệ
gì nữa. Nên nhóm này chạy theo lệnh riêng, và nó phân biệt **mẫu sai** (404 — lỗi của ta) với
**máy chủ chặn** (403/timeout — không phải lỗi của ta).
"""
from __future__ import annotations

import os
import urllib.error
import urllib.request

import pytest

from eide.caps.search import UA, _die, _dien, bang_hang

# ---------------------------------------------------------------- mạng: mẫu URL hãng

# Mẫu ĐÃ KIỂM đạt 200 ngày 08/09/2026. Đây là bộ chống trôi: hãng đổi đường dẫn thì test đỏ và
# ta biết ngay, thay vì biết khi một người dùng báo "tải cái gì cũng 404".
#
# Không đưa vào đây những mẫu mà máy chủ CHẶN (Microchip 403, ST 403/timeout theo lúc): chúng
# có thể đúng, ta chỉ không kiểm được. Đưa vào thì test đỏ vì lý do không phải lỗi của ta.
MAU_DA_KIEM = [
    ("st", "STM32F411CE", "svd"),
    ("nordic", "nRF52840", "svd"),
    ("espressif", "esp32c3", "svd"),
    ("raspberrypi", "RP2040", "pdf"),
    ("allegro", "A4988", "pdf"),
]

# Mẫu CHƯA kiểm được và vì sao. Danh sách này là tài liệu, không phải test — nó tồn tại để lần
# sau ai đó không mất công tra lại.
CHUA_KIEM = {
    "microchip": "403 — packs.download và ww1.microchip.com chặn client không phải trình duyệt",
    "st": "403/timeout tùy lúc — st.com giới hạn tần suất cho HEAD",
    "bosch": "200 lúc đo đầu, URLError lúc đo lại — máy chủ chập chờn",
    "invensense": "404 — TDK đổi đường dẫn; giữ nguyên mẫu TGT-19 §8 thay vì đoán bừa",
}


def _head(uri: str, timeout: float = 15) -> int | str:
    req = urllib.request.Request(uri, method="HEAD", headers={"User-Agent": UA})  # noqa: S310
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:  # noqa: S310
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:                                        # noqa: BLE001
        return type(e).__name__


def _uri(vendor: str, part: str, kind: str) -> str:
    v = next(x for x in bang_hang() if x["id"] == vendor)
    u = next(x for x in v["urls"] if x["kind"] == kind)
    return _dien(u["template"], part, v)


@pytest.mark.net
@pytest.mark.parametrize(("vendor", "part", "kind"), MAU_DA_KIEM)
def test_mau_url_hang_van_giai_duoc(vendor, part, kind):
    """Mẫu URL trong `sources/vendors.yaml` phải còn trỏ tới tệp có thật.

    404 là **lỗi của ta** (mẫu sai). 403 hay hết giờ là **máy chủ chặn** — báo skip chứ không
    báo đỏ, vì đỏ vì lý do ấy sẽ dạy người ta bỏ qua cả nhóm test này.
    """
    uri = _uri(vendor, part, kind)
    st = _head(uri)
    if st in (403, 429) or isinstance(st, str):
        pytest.skip(f"máy chủ chặn hoặc không tới được ({st}): {uri}")
    assert st == 200, f"mẫu URL sai — {vendor}/{kind} trả {st}: {uri}"


@pytest.mark.net
def test_ma_die_khong_phai_ma_vo():
    """`STM32F411CE.svd` KHÔNG tồn tại; `STM32F411.svd` thì có.

    Tệp SVD mô tả một **die**, không mô tả một mã hàng: `STM32F411CE` (LQFP48) và `STM32F411RE`
    (LQFP64) dùng chung một tệp. Đây là phát hiện của lần gọi thật đầu tiên, và không có cách
    nào suy ra nó từ tài liệu — TGT-19 §8 chỉ ghi mẫu URL.
    """
    v = next(x for x in bang_hang() if x["id"] == "st")
    mau = next(x for x in v["urls"] if x["kind"] == "svd")["template"]
    assert "{part_base}" in mau, "mẫu ST phải dùng mã die, không dùng mã hàng"
    assert _die("STM32F411CE") == "STM32F411"
    assert _head(_dien(mau, "STM32F411CE", v)) == 200
    assert _head(mau.replace("{part_base}", "STM32F411CE")) == 404, \
        "nếu mã vỏ cũng giải được thì phép cắt là thừa — kiểm lại giả định"


@pytest.mark.net
def test_moi_mau_chua_kiem_deu_co_ly_do_ghi_lai():
    """Mọi hãng không nằm trong `MAU_DA_KIEM` phải có một dòng trong `CHUA_KIEM`.

    Không có ràng buộc này thì một mẫu hỏng chỉ cần bị bỏ khỏi danh sách đã kiểm là biến mất
    khỏi tầm nhìn — và đó đúng là cách một lỗi đã biết trở thành một lỗi bị quên.
    """
    da_kiem = {v for v, _, _ in MAU_DA_KIEM}
    for v in bang_hang():
        if v["id"] == "community" or not v.get("urls"):
            continue
        assert v["id"] in da_kiem or v["id"] in CHUA_KIEM, \
            f"hãng `{v['id']}` chưa kiểm và cũng chưa ghi lý do"


# ---------------------------------------------------------------- công cụ ngoài


def _co(exe: str) -> bool:
    from eide_core.tools import which
    return which(exe) is not None


@pytest.mark.net
@pytest.mark.skipif(not _co("dot"), reason="cần graphviz — `brew install graphviz`")
def test_diagram_render_dot_that(tmp_path, workspace):
    """Nhánh `subprocess` của `diagram.render` — thứ tự tham số chỉ đúng nếu chạy thật.

    Giả lập `which` trả None chỉ kiểm được nhánh E4001. Nhánh CÒN LẠI — dựng lệnh, gọi, đọc
    tệp ra — chưa từng chạy trên máy chưa cài bộ dựng nào, tức phần lớn máy.
    """
    from pathlib import Path

    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "thử render"},
                   Context(project_dir=workspace)).result
    ctx = Context(project_dir=workspace / res["project_id"])
    src = "digraph G {\n  a [label=\"A\"];\n  b [label=\"B\"];\n  a -> b;\n}\n"
    out = r.invoke("diagram.render", {"src": src, "lang": "dot", "fmt": "svg"}, ctx).result
    t = Path(out["path"]).read_text(encoding="utf-8")
    assert t.lstrip().startswith(("<?xml", "<svg")), t[:120]
    assert "A" in t and "B" in t


@pytest.mark.net
@pytest.mark.skipif(not _co("dot"), reason="cần graphviz")
def test_view_export_map_png_that(tmp_path, workspace):
    """`view.export_map` format=png cũng đi qua Graphviz — và PNG là nhị phân, nên lỗi ở đây
    không lộ ra bằng cách đọc tệp như SVG."""
    from pathlib import Path

    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "thử png"}, Context(project_dir=workspace)).result
    ctx = Context(project_dir=workspace / res["project_id"])
    v = {"graph": {"nodes": [{"id": "a", "label": "A", "color": "#D4A017"}], "edges": []}}
    f = r.invoke("view.export_map", {"view": v, "format": "png"}, ctx).result["file"]
    assert Path(f).read_bytes()[:8] == b"\x89PNG\r\n\x1a\n", "không phải PNG hợp lệ"


# ---------------------------------------------------------------- mô hình thật


CO_KHOA = bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("ANTHROPIC_API_KEY"))
can_khoa = pytest.mark.skipif(not CO_KHOA, reason="cần GEMINI_API_KEY hoặc ANTHROPIC_API_KEY")


@pytest.fixture
def du_an_that(tmp_path, workspace):
    from eide_core import store
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án gọi thật"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


@pytest.mark.llm
@can_khoa
def test_req_classify_voi_mo_hinh_that(du_an_that):
    """Mô hình thật có trả về đúng hình dạng mà `req.classify` đọc không?

    Giả lập luôn trả `{"reqset": [{"kind": ..., "text": ...}]}`. Mô hình thật có thể lồng thêm
    một tầng, đổi tên trường, hoặc bọc JSON trong dấu nháy ba. Mã đọc `resp.data["reqset"]` thì
    im lặng ra rỗng — và `req.classify` trả `codes_assigned: 0` mà không lỗi gì.
    """
    r, ctx, _ = du_an_that
    raw = [{"text": "Đọc nhiệt độ từ cảm biến BME280 mỗi 1 giây"},
           {"text": "Dừng động cơ trong 100 ms khi mất tín hiệu điều khiển"},
           {"text": "Thiết bị khởi động trong vòng 2 giây"}]
    out = r.invoke("req.classify", {"raw": raw}, ctx).result
    assert out["codes_assigned"] == 3, out
    kinds = {x["kind"] for x in out["reqset"]}
    assert kinds <= {"FR", "NFR", "HW", "SAFETY", "RT", "CR"}, kinds
    assert any(x["kind"] == "SAFETY" for x in out["reqset"]), \
        f"câu 'dừng động cơ khi mất tín hiệu' phải là SAFETY: {[x['kind'] for x in out['reqset']]}"
    assert all(x["id"] and x["text"] for x in out["reqset"])


@pytest.mark.llm
@can_khoa
def test_arch_decompose_voi_mo_hinh_that(du_an_that):
    """`arch.decompose` kiểm hai bất biến ở MÃ (không chu trình, mọi FR có module) rồi mới ghi.

    Với mô hình thật, câu hỏi là: nó có sinh ra thứ QUA ĐƯỢC hai phép kiểm ấy không? Nếu không
    thì E5002 mỗi lần, và năng lực này vô dụng dù mã đúng — đó là lỗi của PROMPT, và chỉ gọi
    thật mới thấy.
    """
    from eide.caps.req import _ghi_requirement
    r, ctx, root = du_an_that
    _ghi_requirement(root, [
        {"id": "FR-SNS-01", "kind": "FR", "text": "Đọc nhiệt độ từ BME280 qua I2C mỗi 1 s"},
        {"id": "FR-CTL-01", "kind": "FR", "text": "Điều khiển quạt theo ngưỡng nhiệt độ"},
        {"id": "FR-UI-01", "kind": "FR", "text": "Hiển thị nhiệt độ lên LED 7 đoạn"}])
    run = r.invoke("arch.decompose",
                   {"reqset_ids": ["FR-SNS-01", "FR-CTL-01", "FR-UI-01"],
                    "style": "super_loop"}, ctx)
    assert run.status == "done", f"mô hình sinh phân rã không qua được phép kiểm: {run.error}"
    g = run.result["module_graph"]
    assert len(g["modules"]) >= 3
    phu = {q for m in g["modules"] for q in m["req_ids"]}
    assert phu >= {"FR-SNS-01", "FR-CTL-01", "FR-UI-01"}


@pytest.mark.llm
@can_khoa
def test_view_rag_ask_khong_bia_khi_khong_co_du_lieu(du_an_that):
    """Bất biến quan trọng nhất của `view.rag_ask`, và là thứ giả lập KHÔNG kiểm được: mô hình
    thật có chịu nói "không biết" không, hay nó viết một câu nghe hợp lý?

    Ngưỡng 0,35 chặn ở tầng truy hồi. Test này kiểm tầng sau: đoạn CÓ điểm nhưng không chứa câu
    trả lời — mô hình phải nói rõ là không có, không được suy từ kiến thức nền.
    """
    from eide_core.rag import Doan, RagIndex
    r, ctx, root = du_an_that
    RagIndex(root).them([Doan(
        id="rc_1", source_id="s_1",
        text="Thanh ghi CR1 của khối I2C1 nằm ở offset 0x00. Bit PE bật khối.",
        locator={"page": 1})])
    out = r.invoke("view.rag_ask",
                   {"question": "Thanh ghi CR1 của I2C1 nằm ở offset nào"}, ctx).result
    assert out["not_found"] is False
    assert "0x00" in out["answer"] or "0" in out["answer"]
    assert out["citations"]

    out2 = r.invoke("view.rag_ask",
                    {"question": "Điện áp cấp tối đa của I2C1 CR1 là bao nhiêu vôn"}, ctx).result
    if not out2["not_found"]:
        assert not any(x in out2["answer"] for x in ("3.3", "3,3", "5V", "5 V")), \
            f"mô hình bịa điện áp không có trong đoạn: {out2['answer']}"


@pytest.mark.llm
@can_khoa
def test_doc_section_khong_bia_khi_khong_co_du_lieu(du_an_that):
    """Lần chạy đầu của test này TÌM RA MỘT LỖI THIẾT KẾ, và đáng ghi lại vì sao.

    Bản đầu đòi `doc.section` luôn trả `citations`. Gọi mô hình thật với một module chưa có
    fact nào: mô hình trả lời *"chưa có dữ liệu chi tiết về mô-đun này trong ngữ cảnh được cung
    cấp"* — tức làm ĐÚNG điều ta muốn, từ chối bịa — rồi bị E5002. Một câu trung thực "không có
    dữ liệu" thì không thể có trích dẫn, và bắt nó phải có là **dạy mô hình bịa cho đủ**.

    Không giả lập nào bắt được: giả lập trả cái tôi bảo nó trả. Đây là câu hỏi về hành vi của
    mô hình thật trước một prompt thật.
    """
    from eide.caps.arch import _ghi_module
    r, ctx, root = du_an_that
    _ghi_module(root, [{"id": "mod_i2c", "name": "i2c", "responsibility": "đọc cảm biến qua I2C",
                        "depends": [], "interfaces": [], "status": "proposed"}])
    run = r.invoke("doc.section", {"target": "mod_i2c"}, ctx)
    assert run.status == "done", f"module không có fact vẫn phải viết được: {run.error}"
    md = run.result["markdown"]
    if not run.result["citations"]:
        # Không trích dẫn thì phải là câu THỪA NHẬN thiếu dữ liệu, không phải khẳng định trơn.
        assert any(x in md.lower() for x in ("chưa có", "không có", "không đủ", "thiếu")), \
            f"không trích dẫn mà cũng không nói rõ là thiếu dữ liệu: {md[:200]}"



# --------------------------------------------------------------------------------------------
# ENV-03 — trình quản lý gói THẬT chạy được bên trong sandbox
# --------------------------------------------------------------------------------------------

@pytest.mark.net
@pytest.mark.skipif(not _co("brew") and not _co("apt-get"), reason="cần brew hoặc apt-get")
def test_trinh_quan_ly_goi_chay_duoc_trong_sandbox(tmp_path):
    """`env.install` giả định hai điều mà không giả lập nào kiểm được, vì cả hai đều là câu hỏi
    về HỆ ĐIỀU HÀNH chứ không về mã của ta.

    1. Gọi được trình quản lý gói bằng đường dẫn tuyệt đối, dù `PATH` trong sandbox bị dựng lại
       thành `/usr/bin:/bin:/usr/sbin:/sbin` — Homebrew nằm ở `/opt/homebrew/bin`.
    2. Nó CHẠY được dưới hồ sơ `sandbox-exec`. Đây là chỗ đã hỏng thật: `brew` tạo
       `$HOME/Library` ngay đầu mỗi lệnh, và trước 08/09/2026 hồ sơ sandbox chặn cả `$HOME` lẫn
       thư mục làm việc của chính nó (đường dẫn trong hồ sơ chưa giải liên kết mềm). Test giả
       lập dùng shim `/bin/sh` không thấy, vì `/bin/sh` không đụng tới `$HOME`.

    Lệnh dùng ở đây là lệnh CHỈ ĐỌC (`--version`, `list`): test không được cài gì lên máy ai.
    """
    from pathlib import Path

    from eide_core import tools
    from eide_core.sandbox import Sandbox

    mgr = tools.which("brew") or tools.which("apt-get")
    sb = Sandbox(out_dir=tmp_path / "sb")

    kq = sb.run([str(mgr), "--version"], limits={"wall_s": 120}, network=True)
    assert kq.exit_code == 0, Path(kq.stderr_ref).read_text(encoding="utf-8")[:500]
    assert Path(kq.stdout_ref).read_text(encoding="utf-8").strip()

    if mgr.name == "brew":
        # `list` đọc cả prefix lẫn cache trong $HOME — nặng hơn `--version` một bậc, và chính là
        # nhánh đã ném "Operation not permitted" khi hồ sơ sandbox còn sai.
        kq = sb.run([str(mgr), "list", "--versions"], limits={"wall_s": 300}, network=True)
        err = Path(kq.stderr_ref).read_text(encoding="utf-8")
        assert "not permitted" not in err, err[:500]
        assert kq.exit_code == 0, err[:500]


@pytest.mark.llm
@can_khoa
def test_coder_that_co_ghi_eide_fact_cho_hang_so_khong(du_an_that):
    """tc của CODE-01 là **"Mọi hằng số có eide:fact"** — và đó là một câu hỏi về HÀNH VI CỦA
    MÔ HÌNH, không phải về mã của ta.

    Giả lập trả đúng cái tôi bảo nó trả, nên nó chứng minh `constant_guard` chạy được, chứ không
    chứng minh prompt PRS-16 §3 dạy được mô hình làm điều nó đòi. Câu duy nhất đáng hỏi ở đây:
    cho một fact có thật trong ngữ cảnh, coder có chú thích `/* eide:fact f_… */` đúng dạng
    không, hay nó viết `0x76` trần rồi bị chặn?

    Test chấp nhận HAI kết quả, và cả hai đều đúng:
      · patch qua được guard — mô hình chú thích đúng;
      · E5003 kèm `missing_facts` — mô hình dừng và nói thiếu, đúng như prompt dạy.
    Chỉ một kết quả bị coi là hỏng: viết hằng số trần mà không khai gì, tức bịa cho đủ.
    """
    import hashlib

    from eide.caps.code import generate_module
    from eide.caps.plan import ghi_plan
    from eide_core import store
    from eide_core.errors import EideError

    r, ctx, root = du_an_that
    fid = "f_00000000000000ab"
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s1", "bme280.pdf", hashlib.sha256(b"s1").hexdigest(), "pdf_vendor",
                   "gold", "vendor-doc"))
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, "part:bosch.bme280", "i2c.addr", "0x76", "s1", "parser", "gold",
                   1.0, "verified", "A"))
        c.commit()
    ghi_plan(root, "F-01", {"steps": [{
        "id": "step-1", "goal": "viết hàm bme280_init đặt địa chỉ I2C của cảm biến",
        "cap": "code.generate_module", "done_when": "hàm trả 0 khi thành công",
        "cites": [fid], "touches": ["none"]}]},
        {"decision": "APPROVE", "rule": "G1-01", "reason": "kế hoạch nhỏ", "gate": "G1"})

    try:
        out = generate_module({"step_ref": "F-01/step-1"}, ctx)
    except EideError as e:
        assert e.code == "E5003", f"lỗi ngoài dự kiến: {e.code} {e}"
        assert e.data.get("missing_facts"), \
            ("mô hình viết hằng số phần cứng KHÔNG chú thích nguồn và cũng không khai thiếu — "
             f"tức bịa cho đủ: {e.data.get('violations')}")
        return
    noi_dung = "\n".join(f["content"] for f in out["patch"]["files"])
    assert "eide:fact" in noi_dung, f"patch qua guard nhưng không có chú thích nào:\n{noi_dung[:400]}"
