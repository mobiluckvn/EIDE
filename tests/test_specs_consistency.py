"""Mã ≡ spec: mọi mã lỗi trong mã có trong errors.json; mọi phương thức RPC có trong openrpc.json;
mọi @capability trỏ tới id trong cds.json; capabilities/*.yaml khớp cds.json; docstring có `Spec:`."""
import json
import re
import tempfile

import pytest
import yaml

from eide_core.paths import repo_root, spec_dir
from eide_core.registry import get_registry

SRC = repo_root() / "src"


def test_error_codes_used_exist():
    known = {e["code"] for e in json.loads((spec_dir() / "api" / "errors.json").read_text(encoding="utf-8"))}
    used = set()
    for f in SRC.rglob("*.py"):
        used |= set(re.findall(r'EideError\("(E\d{4})"', f.read_text(encoding="utf-8")))
    assert used <= known, used - known


def test_rpc_methods_exist_in_openrpc():
    from eide.daemon.rpc import Daemon

    names = {m["name"] for m in json.loads((spec_dir() / "api" / "openrpc.json").read_text(encoding="utf-8"))["methods"]}
    assert set(Daemon().methods) <= names


def test_capability_decorators_point_to_spec_ids():
    reg = get_registry()
    for f in (SRC / "eide" / "caps").glob("*.py"):
        for cid in re.findall(r'@capability\("([a-z_.]+)"', f.read_text(encoding="utf-8")):
            assert cid in reg, cid
            assert reg.get(cid).implemented


def test_yaml_matches_cds():
    cds = {c["id"]: c for c in json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))}
    for f in (spec_dir() / "capabilities").glob("*.yaml"):
        for row in yaml.safe_load(f.read_text(encoding="utf-8")):
            assert row["id"] in cds and row["code"] == cds[row["id"]]["code"], row["id"]


def test_handlers_cite_spec_in_docstring():
    reg = get_registry()
    for c in reg.list(implemented=True):
        assert c.handler.__doc__ and c.handler.__doc__.lstrip().startswith("Spec:"), c.spec.id


def test_deviations_have_status():
    text = (repo_root() / "docs" / "DEVIATIONS.md").read_text(encoding="utf-8")
    rows = [line for line in text.splitlines() if line.startswith("| DEV-")]
    for r in rows:
        assert r.rstrip("| ").split("|")[-1].strip() in {"Mở", "Đã duyệt", "Bác"} or "Đã cập nhật tài liệu" in r, r


def test_vi_du_cua_hop_dong_phai_qua_noi_input_schema_cua_chinh_no():
    """Mỗi hợp đồng CDS-12 có `input_schema` và `example`; ví dụ phải hợp lệ theo schema ấy.

    Router kiểm input theo `input_schema` và chặn bằng E1000 trước khi vào handler (API-15 §3).
    Nên một ví dụ không qua nổi schema của chính nó là một lời hướng dẫn sai: người đọc tài liệu
    gõ theo ví dụ và nhận lỗi, hoặc tệ hơn — người hiện thực đọc ví dụ rồi viết mã theo hình
    dạng ấy, và mâu thuẫn chỉ lộ ra ở chỗ khác.

    Phép kiểm này tìm ra HAI lỗi trong 238 hợp đồng mà trước đó không ai thấy (DEV-009
    PROJECT-09, và KG-07 thiếu `actor` trong ví dụ), nên nó ở lại làm cổng thường trực.
    """
    jsonschema = pytest.importorskip("jsonschema")
    caps = json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))
    loi = []
    for c in caps:
        ex, sch = c.get("example"), c.get("input_schema")
        if not ex or not isinstance(sch, dict):
            continue
        try:
            val = json.loads(ex) if isinstance(ex, str) else ex
        except json.JSONDecodeError:
            continue                      # ví dụ viết dạng dòng lệnh, không phải JSON
        if not isinstance(val, dict):
            continue
        for e in jsonschema.Draft202012Validator(sch).iter_errors(val):
            loi.append(f"{c['code']} {c['id']}: {list(e.path) or '(gốc)'} — {e.message}")
    assert not loi, "ví dụ mâu thuẫn với input_schema:\n  " + "\n  ".join(loi)


def test_khong_module_nao_dinh_nghia_trung_ten_o_muc_cao_nhat():
    """Hai `def` cùng tên trong một module: cái sau che cái trước, im lặng tuyệt đối.

    Xảy ra thật khi thêm `doc.generate`: `_muc_nguon` đã có nghĩa **cấp nguồn điện** cho
    `doc.bringup_guide`, và mục "Nguồn" (tài liệu tham khảo) của `doc.generate` vô tình lấy
    đúng cái tên ấy. Python không kêu một tiếng nào; ba test của bringup guide đỏ ở một tệp
    KHÁC hẳn tệp vừa sửa, nên dấu vết đầu tiên trỏ sai chỗ.

    Lần ấy có test bắt được. Một hàm nội bộ chưa có test thì không — nó chỉ đơn giản gọi nhầm
    hàm cho tới lúc ai đó đọc kỹ. Phép kiểm này rẻ và bắt cả lớp ấy.
    """
    import ast
    from collections import Counter

    loi = []
    for f in sorted(SRC.rglob("*.py")):
        than = ast.parse(f.read_text(encoding="utf-8")).body
        ten = [n.name for n in than
               if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))]
        loi += [f"{f.relative_to(SRC)}: `{k}` định nghĩa {v} lần"
                for k, v in Counter(ten).items() if v > 1]
    assert not loi, "định nghĩa trùng tên, cái sau che cái trước:\n  " + "\n  ".join(loi)


def test_ma_hop_dong_trong_docstring_phai_dung_ma_trong_cds():
    """`Spec: DOC-05` ở đầu một handler phải là mã CỦA CHÍNH nó trong cds.json.

    `test_handlers_cite_spec_in_docstring` chỉ kiểm docstring có bắt đầu bằng `Spec:` — nó
    không kiểm mã ấy có đúng không. Nên 25 handler trỏ sang một hợp đồng KHÁC mà mọi phép kiểm
    vẫn xanh: đánh số CDS đã đổi (`INGEST-01` → `ARCHIVE-05`, `DOC-05` → `DOC-02`, cả loạt
    `SEARCH-*` và `VIEW-*` lệch một hai số) còn docstring thì giữ số cũ.

    Hậu quả không phải thẩm mỹ. Nguyên tắc số 1 của kho này là "mọi hành vi truy vết được về
    một tài liệu"; một mã sai gửi người đọc — và gửi chính tôi ở phiên sau — sang đúng hợp đồng
    của một năng lực khác. `doc.section` trỏ `DOC-05`, mà DOC-05 là `doc.bringup_guide`: hai
    năng lực có thật, hai hợp đồng có thật, và cái sai không tự lộ ra bao giờ.
    """
    import inspect

    from eide.cli import main  # noqa: F401 — nạp mọi module caps để registry đầy đủ

    cds = {c["id"]: c["code"] for c in
           json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))}
    loi = []
    for c in get_registry().list(implemented=True):
        doc = (c.handler.__doc__ or "").lstrip()
        m = re.match(r"Spec:\s*([A-Z][A-Z0-9_]*-\d+)", doc)
        if not m:
            loi.append(f"{c.spec.id}: docstring không nêu mã hợp đồng nào")
        elif m.group(1) != cds[c.spec.id]:
            loi.append(f"{c.spec.id}: docstring nói `{m.group(1)}`, cds.json nói "
                       f"`{cds[c.spec.id]}`")
        _ = inspect
    assert not loi, "docstring trỏ sai hợp đồng:\n  " + "\n  ".join(loi)


def test_hien_thuc_khong_doc_tham_so_ma_input_schema_khong_cho_phep():
    """Mọi khoá `params["x"]` / `params.get("x")` trong hiện thực phải nằm trong `input_schema`.

    Cả 238 hợp đồng đều đóng `additionalProperties`, nên router chặn bằng E1000 **trước khi**
    vào handler (API-15 §3). Một tham số handler đọc mà schema không khai là tham số **không ai
    truyền được**: nó chỉ chạy khi test gọi thẳng hàm, và im lặng biến mất trên đường thật.

    Đó là một lỗi khó thấy đúng vì test vẫn xanh — test gọi thẳng hàm thì không qua router. Đã
    hỏng thật một lần: `extract.kicad_netlist` nhận `name` để đặt tên board, có test xanh, mà
    qua router thì E1000; tên board rơi về tên tệp và `board.build_passport` không tìm thấy net.
    Xem DEV-066. Phép kiểm này là phần làm được ngay của WI-253.
    """
    import inspect

    from eide.cli import main  # noqa: F401 — nạp mọi module caps để registry đầy đủ

    cds = {c["id"]: c for c in json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))}
    loi = []
    for c in get_registry().list(implemented=True):
        try:
            src = inspect.getsource(c.handler)
        except OSError:                       # handler dựng lúc chạy, không có mã nguồn
            continue
        doc = set(re.findall(r'params\[\s*"([A-Za-z_]\w*)"\s*\]', src))
        doc |= set(re.findall(r'params\.get\(\s*"([A-Za-z_]\w*)"', src))
        sch = cds[c.spec.id]["input_schema"]
        if sch.get("additionalProperties") is not False:
            continue
        if (thua := doc - set(sch.get("properties") or {})):
            loi.append(f"{c.spec.id}: đọc {sorted(thua)} — input_schema chỉ cho "
                       f"{sorted(sch.get('properties') or {})}")
    assert not loi, "tham số router sẽ chặn bằng E1000 trước khi handler thấy:\n  " + "\n  ".join(loi)


def test_ket_qua_sai_output_schema_la_E1004_khong_phai_E6001():
    """API-15 §3 v1.5: lỗi hiện thực có mã RIÊNG, không mượn mã của lỗi dữ liệu (DEV-002).

    E6001 SCHEMA_VIOLATION nói về việc GHI sai schema dữ liệu DDD-14 — một lỗi của dữ liệu.
    Một năng lực trả sai hình dạng là lỗi của MÃ. Lẫn hai thứ vào một mã làm người đọc nhật ký
    đi soi store trong khi chỗ hỏng là một hàm.
    """
    from eide_core.errors import EideError

    reg = get_registry()
    with pytest.raises(EideError) as e:
        # `project.list` khai `projects` là mảng bắt buộc; trả về một chuỗi là sai hình dạng.
        reg.validate_output("project.list", {"projects": "không phải mảng"})
    assert e.value.code == "E1004", f"đang là {e.value.code}"
    assert e.value.name == "OUTPUT_SCHEMA"


def test_khong_muc_DEVIATIONS_nao_roi_khoi_bao_cao_dong_bo():
    """Mọi mục `Mở`/`Đã duyệt` phải xuất hiện trong báo cáo đồng bộ — bất biến của cả quy trình.

    Chủ sản phẩm duyệt danh sách ấy và tin rằng nó đầy đủ; một mục lặng lẽ rơi ra là hỏng đúng
    chỗ quy trình sinh ra để chống.

    Đã hỏng thật một lần: DEV-058 nói về công thức `1/(1+|bm25|)`, mà `|` là dấu ngăn cột của
    bảng Markdown — dòng vỡ thành 14 mảnh, bộ phân giải lấy `c[7]` làm trạng thái nên đọc ra
    rác, và mục ấy bị lọc mất. Không cảnh báo gì.

    **Hai nửa, và nửa thứ hai mới là nửa chắc chắn.** Nửa đầu kiểm các mục Mở đang có thật trong
    kho. Nhưng số mục Mở về 0 sau mỗi đợt đồng bộ — và ngày 08/09 nó về 0 thật, làm phiên bản
    trước của test này đỏ vì chính giả định "phải có ít nhất một mục Mở". Một phép kiểm chỉ có
    nghĩa khi kho đang nợ là một phép kiểm tắt đúng lúc vừa dọn xong. Nên nửa sau dựng một bảng
    DEVIATIONS GIẢ có `|` trong nội dung và kiểm bộ phân giải trực tiếp: nó không phụ thuộc kho
    nợ bao nhiêu mục, và nó kiểm đúng cái đã hỏng.
    """
    import subprocess
    import sys
    from pathlib import Path

    # --- nửa 1: mục Mở thật (nếu có) phải có mặt trong báo cáo
    t = Path("docs/DEVIATIONS.md").read_text(encoding="utf-8")
    mo = {d.split("|")[1].strip() for d in t.splitlines()
          if d.startswith("| DEV-") and d.rstrip().split("|")[-2].strip() in ("Mở", "Đã duyệt")}
    if mo:
        out = subprocess.run([sys.executable, "scripts/dong_bo_tai_lieu.py", "--tom-tat"],
                             capture_output=True, text=True, check=False).stdout
        thieu = sorted(x for x in mo if x not in out)
        assert thieu == [], f"mục Mở không xuất hiện trong báo cáo đồng bộ: {thieu}"

    # --- nửa 2: bộ phân giải phải đọc đúng trạng thái dù nội dung có `|`
    sys.path.insert(0, "scripts")
    import dong_bo_tai_lieu as dbt

    goc = dbt.ROOT
    with tempfile.TemporaryDirectory() as d:
        gia = Path(d) / "docs"
        gia.mkdir()
        (gia / "DEVIATIONS.md").write_text(
            "| Mã | Ngày | Tài liệu | Mã nguồn | Sai khác | Lý do | Đề xuất | Trạng thái |\n"
            "|---|---|---|---|---|---|---|---|\n"
            "| DEV-900 | 2026-01-01 | POL-17 §2 | a.py | công thức `1/(1+|bm25|)` sai dấu "
            "| vì `|` là dấu ngăn cột | sửa | Mở |\n"
            "| DEV-901 | 2026-01-01 | CDS-12.1 CODE-01 | b.py | không có ký tự lạ | vì thế "
            "| sửa | Đã cập nhật tài liệu v1.3 |\n"
            # Dấu ống ĐÃ THOÁT (`\\|`) là ký tự văn bản, không phải dấu ngăn cột. Nó có thật
            # trong kho (DEV-073: enum `docx\\|md`), và cắt ở đó làm LỆCH mọi cột phía sau —
            # trạng thái vẫn đọc đúng vì lấy từ cột cuối, nên phiên bản trước của test này xanh
            # trong khi báo cáo gửi chủ sản phẩm ghi nửa câu vào ô "Tài liệu" và nửa còn lại vào
            # ô "Mã nguồn".
            "| DEV-902 | 2026-01-01 | CDS-12.1 DOC-06 enum `docx\\|md` | c.py | sai khác 902 "
            "| lý do 902 | đề xuất 902 | Mở |\n", encoding="utf-8")
        dbt.ROOT = Path(d)
        try:
            ds = {r["ma"]: r["trang_thai"] for r in dbt.doc_deviations()}
            cot = {r["ma"]: r for r in dbt.doc_deviations()}
        finally:
            dbt.ROOT = goc
    assert ds == {"DEV-900": "Mở", "DEV-901": "Đã cập nhật tài liệu v1.3", "DEV-902": "Mở"}, \
        f"`|` trong nội dung làm lệch cột trạng thái: {ds}"

    d902 = cot["DEV-902"]
    assert d902["tai_lieu"] == "CDS-12.1 DOC-06 enum `docx|md`", d902["tai_lieu"]
    assert d902["ma_nguon"] == "c.py", d902["ma_nguon"]
    assert d902["de_xuat"] == "đề xuất 902", d902["de_xuat"]
