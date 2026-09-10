"""Nhóm extract.* mốc M1 — CDS-12.2; KAD-07 §3; DDD-14 §2 Fact.

Bảy năng lực: `edc`, `header_c`, `pdf_layout`, `pdf_register_map`, `pdf_electrical`, `office`,
`code_constants`.

tc: "50 SFR khớp datasheet"; "Lệch cố ý 1 địa chỉ → conflict 1"; "Bảng thanh ghi nhận dạng là
table với bbox"; TC-12 ≥ 90%; "VDD range đúng"; "Bảng trong docx thành block table"; UC-A05.

**PDF trong test là PDF THẬT**, dựng bằng chính pdfplumber/reportlab-free (viết tay cú pháp PDF
tối thiểu). Giả lập khối rồi kiểm sẽ chỉ chứng minh cái giả lập đúng — mà phần dễ sai nhất của
nhóm này nằm đúng ở chỗ đọc bố cục.
"""
from __future__ import annotations

import json
import zlib
from pathlib import Path

import pytest

from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from pdf_gia_lap import pdf_tho, pdf_toi_thieu

pdfplumber = pytest.importorskip("pdfplumber", reason="extract.pdf_* cần pdfplumber")


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án trích"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _gia_lap(monkeypatch, data):
    class _R:
        def __init__(self, d): self.data = d
    class _G:
        def run(self, *a, **k): return _R(data)
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())


# ---------------------------------------------------------------- dựng PDF thật
#
# `pdf_toi_thieu`/`pdf_tho` nay nằm ở `tests/pdf_gia_lap.py` — `test_extract_m2.py` cần đúng
# chúng, và hai bản chép tay của một bộ dựng PDF là hai bản sẽ lệch.


@pytest.fixture
def pdf_thanh_ghi(tmp_path):
    """Một trang có tiêu đề lớn và một bảng thanh ghi xếp theo cột."""
    dong = [(72, 720, "8.4 I2C register map", 16.0)]
    cot = [72, 200, 300, 400]
    bang = [["Register", "Address", "Bits", "Reset"],
            ["CR1", "0x00", "15:0", "0x0000"],
            ["CR2", "0x04", "11:0", "0x0000"],
            ["DR", "0x10", "7:0", "0x0000"]]
    for i, hang in enumerate(bang):
        for j, o in enumerate(hang):
            dong.append((cot[j], 680 - i * 20, o, 10.0))
    return pdf_toi_thieu(tmp_path / "ds.pdf", dong)


# ---------------------------------------------------------------- EXTRACT-05 pdf_layout


def test_doc_duoc_chu_va_bbox(du_an, pdf_thanh_ghi):
    """`bbox` là thứ làm nên giá trị: nó cho `locator` trỏ về ĐÚNG chỗ trong trang, nên người
    kiểm mở datasheet ra là thấy ngay số ấy đến từ đâu. Một fact "trang 47" thì vẫn phải tự dò
    cả trang."""
    r, ctx, _ = du_an
    out = r.invoke("extract.pdf_layout", {"file": str(pdf_thanh_ghi)}, ctx).result
    assert out["blocks"]
    assert all(b["page"] == 1 for b in out["blocks"])
    assert all(b["bbox"] and len(b["bbox"]) == 4 for b in out["blocks"])
    noi = " ".join(str(b["content"]) for b in out["blocks"])
    assert "CR1" in noi and "0x00" in noi


def test_tieu_de_nhan_theo_co_chu_vao_toc(du_an, pdf_thanh_ghi):
    """Nhận tiêu đề bằng CỠ CHỮ chứ không bằng biểu thức chính quy trên nội dung: datasheet đánh
    số mục kiểu "8.4.2" nhưng cũng đầy dòng thân bài bắt đầu bằng số."""
    r, ctx, _ = du_an
    out = r.invoke("extract.pdf_layout", {"file": str(pdf_thanh_ghi)}, ctx).result
    assert any("register map" in x["title"].lower() for x in out["toc"]), out["toc"]
    assert all(x["page"] == 1 for x in out["toc"])


def pdf_co_ke(p: Path) -> Path:
    """PDF có bảng KẺ KHUNG — dạng phổ biến của bảng thanh ghi trong datasheet hãng.

    Bản test đầu của tôi chỉ có chữ căn cột, không có đường kẻ. `find_tables()` mặc định dò
    theo đường kẻ nên trả về 0 bảng — tức tc "bảng thanh ghi nhận dạng là table với bbox" chưa
    bao giờ được kiểm, và nhánh lọc chữ-trong-bảng là mã chết trong bộ test.
    """
    cot, hang_y = [72, 200, 300, 400, 500], [700, 680, 660]
    lenh = ["0.5 w"]
    for x in cot:
        lenh.append(f"{x} {hang_y[-1] - 12} m {x} {hang_y[0] + 12} l S")
    for y in [*hang_y, hang_y[-1] - 12]:
        lenh.append(f"{cot[0]} {y + 12} m {cot[-1]} {y + 12} l S")
    bang = [["Register", "Address", "Bits", "Reset"],
            ["CR1", "0x00", "15:0", "0x0001"],
            ["DR", "0x10", "7:0", "0x0000"]]
    for i, r in enumerate(bang):
        for j, o in enumerate(r):
            an = o.replace("(", r"\(").replace(")", r"\)")
            lenh.append(f"BT /F1 9 Tf {cot[j] + 3} {hang_y[i] + 2} Td ({an}) Tj ET")
    lenh.append("BT /F1 16 Tf 72 740 Td (8.4 I2C register map) Tj ET")
    return pdf_tho(p, "\n".join(lenh).encode("latin-1"))


def test_bang_co_ke_nhan_dang_la_table_co_bbox(du_an, tmp_path):
    """tc EXTRACT-05 nguyên văn: "Bảng thanh ghi nhận dạng là table với bbox"."""
    r, ctx, _ = du_an
    out = r.invoke("extract.pdf_layout", {"file": str(pdf_co_ke(tmp_path / "ke.pdf"))},
                   ctx).result
    bang = [b for b in out["blocks"] if b["type"] == "table"]
    assert bang, [b["type"] for b in out["blocks"]]
    assert bang[0]["bbox"] and len(bang[0]["bbox"]) == 4
    o = " ".join(str(x) for hang in bang[0]["content"] for x in hang)
    assert "CR1" in o and "0x00" in o and "Register" in o


def test_chu_trong_bang_khong_lap_lai_o_khoi_text(du_an, tmp_path):
    """Để lại thì mỗi ô xuất hiện HAI lần, và `pdf_register_map` thấy cùng một giá trị ở hai
    chỗ rồi coi đó là "nguồn thứ hai" — một sự trùng khớp tự tạo."""
    r, ctx, _ = du_an
    out = r.invoke("extract.pdf_layout", {"file": str(pdf_co_ke(tmp_path / "ke.pdf"))},
                   ctx).result
    text = " ".join(str(b["content"]) for b in out["blocks"] if b["type"] == "text")
    assert "CR1" not in text, f"ô bảng lặp lại trong khối text: {text!r}"


def test_tieu_de_van_vao_toc_o_trang_co_bang(du_an, tmp_path):
    """Chiến lược `text` hay nuốt cả dòng tiêu đề vào vùng bảng. Lọc tiêu đề theo bbox sẽ làm
    `toc` rỗng ở đúng những trang CÓ bảng — tức mất mục lục ở phần đáng tra cứu nhất."""
    r, ctx, _ = du_an
    out = r.invoke("extract.pdf_layout", {"file": str(pdf_co_ke(tmp_path / "ke.pdf"))},
                   ctx).result
    assert any("register map" in x["title"].lower() for x in out["toc"]), out["toc"]


def test_bang_khong_ke_van_nhan_ra(du_an, pdf_thanh_ghi):
    """Nhiều tài liệu chỉ căn cột bằng khoảng trắng. Ở đó chiến lược đường kẻ trả rỗng, và cả
    bảng thanh ghi trôi vào khối `text` — nơi `pdf_register_map` không tìm."""
    r, ctx, _ = du_an
    out = r.invoke("extract.pdf_layout", {"file": str(pdf_thanh_ghi)}, ctx).result
    assert any(b["type"] == "table" for b in out["blocks"]), [b["type"] for b in out["blocks"]]


def test_loc_theo_trang(du_an, tmp_path):
    r, ctx, _ = du_an
    p = pdf_toi_thieu(tmp_path / "a.pdf", [(72, 700, "chi mot trang", 10.0)])
    assert r.invoke("extract.pdf_layout", {"file": str(p), "pages": "2-5"},
                    ctx).result["blocks"] == []
    assert r.invoke("extract.pdf_layout", {"file": str(p), "pages": "1"}, ctx).result["blocks"]


def test_pdf_hong_bao_E4004(du_an, tmp_path):
    r, ctx, _ = du_an
    p = tmp_path / "hong.pdf"
    p.write_bytes(b"%PDF-1.4\nkhong phai PDF that")
    run = r.invoke("extract.pdf_layout", {"file": str(p)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4004"


def test_thieu_ca_hai_thu_vien_bao_E4001(du_an, pdf_thanh_ghi, monkeypatch):
    """Hợp đồng cho E4001 khi thiếu công cụ — nhưng chỉ khi thiếu CẢ docling lẫn pdfplumber.
    Bắt buộc docling là bắt người dùng tải 2 GB (PyTorch) cho việc pdfplumber làm đủ tốt."""
    import builtins
    that = builtins.__import__

    def chan(ten, *a, **k):
        if ten in ("pdfplumber", "docling", "docling.document_converter"):
            raise ImportError(ten)
        return that(ten, *a, **k)

    monkeypatch.setattr(builtins, "__import__", chan)
    r, ctx, _ = du_an
    run = r.invoke("extract.pdf_layout", {"file": str(pdf_thanh_ghi)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4001"
    assert "pdfplumber" in str(run.error)


# ---------------------------------------------------------------- EXTRACT-06 pdf_register_map


def _bang_khoi(noi, page=1, bbox=None):
    return {"page": page, "bbox": bbox or [70, 100, 500, 200], "type": "table", "content": noi}


BANG_TG = [["Register", "Address", "Bits", "Reset"],
           ["CR1", "0x00", "15:0", "0x0001"]]


@pytest.fixture
def tep_pdf(tmp_path):
    """`extract.pdf_register_map` ghi `source` với sha256 của tệp, nên tệp phải có thật — dù
    `blocks` được truyền sẵn. Đó là chủ ý: fact phải trỏ về một nguồn tồn tại."""
    return str(pdf_toi_thieu(tmp_path / "reg.pdf", [(72, 700, "x", 10.0)]))


def test_chon_bang_la_viec_cua_ma_khong_phai_cua_mo_hinh(du_an, monkeypatch, tep_pdf):
    """Một datasheet 900 trang có hàng trăm bảng. Đưa hết cho mô hình vừa tốn vừa làm nó lẫn
    bảng đặt hàng với bảng thanh ghi."""
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"registers": [{"name": "CR1", "peripheral": "I2C1",
                                          "offset": "0x00", "reset_value": "0x0001"}]})
    khoi = [_bang_khoi([["Part number", "Package", "Price"], ["X", "QFN", "1"]]),
            _bang_khoi(BANG_TG)]
    out = r.invoke("extract.pdf_register_map",
                   {"file": tep_pdf, "blocks": khoi, "part": "st.stm32f411"}, ctx).result
    assert out["n_facts"] == 2       # offset + reset_value, chỉ từ bảng thanh ghi


def test_khong_co_bang_dang_thanh_ghi_bao_E5002(du_an, monkeypatch, tep_pdf):
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"registers": []})
    khoi = [_bang_khoi([["Part number", "Package"], ["X", "QFN"]])]
    run = r.invoke("extract.pdf_register_map",
                   {"file": tep_pdf, "blocks": khoi, "part": "st.x"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_locator_lay_tu_khoi_khong_hoi_mo_hinh(du_an, monkeypatch, tep_pdf):
    """Mô hình bịa số trang là chuyện thường, và một trích dẫn sai còn tệ hơn không trích dẫn —
    nó tạo vẻ đã kiểm chứng."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, {"registers": [{"name": "CR1", "peripheral": "I2C1",
                                          "offset": "0x00", "page": 999}]})
    r.invoke("extract.pdf_register_map",
             {"file": tep_pdf, "blocks": [_bang_khoi(BANG_TG, page=47, bbox=[1, 2, 3, 4])],
              "part": "st.x"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        (loc,) = c.execute("SELECT locator FROM fact WHERE predicate='offset'").fetchone()
    assert json.loads(loc) == {"page": 47, "bbox": [1, 2, 3, 4]}


def test_fact_tu_pdf_luon_la_silver(du_an, monkeypatch, tep_pdf):
    """Trích từ PDF bằng mô hình không bao giờ ngang hàng với parser SVD, dù bảng rõ đến đâu —
    và tầng bạc nghĩa là G-FACT xét chứ không tự duyệt."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, {"registers": [{"name": "CR1", "peripheral": "I2C1", "offset": "0x00"}]})
    r.invoke("extract.pdf_register_map",
             {"file": tep_pdf, "blocks": [_bang_khoi(BANG_TG)], "part": "st.x"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert {x[0] for x in c.execute("SELECT DISTINCT tier, method FROM fact")} == {"silver"}


def test_confidence_tinh_tu_diem_bang_khong_nhan_so_mo_hinh_tu_cham(du_an, monkeypatch, tep_pdf):
    """Mô hình tự chấm điểm tin cậy cho chính nó thì con số ấy không mang thông tin."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, {"registers": [{"name": "CR1", "peripheral": "I2C1",
                                          "offset": "0x00", "confidence": 1.0}]})
    # bảng NGHÈO cột (chỉ Register + Address) phải cho confidence thấp hơn bảng đủ bốn cột
    ngheo = [["Register", "Address"], ["CR1", "0x00"]]
    r.invoke("extract.pdf_register_map",
             {"file": tep_pdf, "blocks": [_bang_khoi(ngheo)], "part": "st.a"}, ctx)
    r.invoke("extract.pdf_register_map",
             {"file": tep_pdf, "blocks": [_bang_khoi(BANG_TG)], "part": "st.b"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        a = c.execute("SELECT confidence FROM fact WHERE subject LIKE 'chip:st.a%'").fetchone()[0]
        b = c.execute("SELECT confidence FROM fact WHERE subject LIKE 'chip:st.b%'").fetchone()[0]
    assert a < b < 1.0


@pytest.mark.parametrize(("viet", "dai"), [
    ("[7:4]", [4, 7]), ("7:4", [4, 7]), ("7-4", [4, 7]), ("3", [3, 3]), ("", None),
    ("khong phai", None),
])
def test_bon_cach_viet_dai_bit(viet, dai):
    """`[7:4]`, `7:4`, `7-4`, `7` — bốn cách viết cùng một ý, đều gặp trong datasheet thật."""
    from eide.caps.extract import _dai_bit
    kq = _dai_bit(viet)
    assert (list(kq) if kq else None) == dai


def test_enum_co_confidence_thap_hon_de_G_FACT_hoi(du_an, monkeypatch, tep_pdf):
    """Enum trong PDF hay bị đọc lệch dòng. Nó vẫn vào store nhưng dưới ngưỡng ⇒ người xem."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, {"registers": [{
        "name": "CR1", "peripheral": "I2C1", "offset": "0x00",
        "fields": [{"name": "PE", "bits": "0:0",
                    "enum": [{"name": "Enabled", "value": "1"}]}]}]})
    r.invoke("extract.pdf_register_map",
             {"file": tep_pdf, "blocks": [_bang_khoi(BANG_TG)], "part": "st.x"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        e = c.execute("SELECT confidence FROM fact WHERE predicate='enum'").fetchone()[0]
        b = c.execute("SELECT confidence FROM fact WHERE predicate='bit_range'").fetchone()[0]
    assert e < b


# ---------------------------------------------------------------- EXTRACT-07 pdf_electrical


def test_VDD_range_chuan_hoa_ve_don_vi_goc(du_an, monkeypatch, tmp_path):
    """tc: "VDD range đúng; timing có min/typ/max". Dùng chung bảng `DON_VI` với `req.*`: hai
    bảng đơn vị trong một kho là hai bảng sẽ lệch, và lệch đơn vị thì sai một nghìn lần mà con
    số vẫn trông hợp lý."""
    r, ctx, root = du_an
    p = pdf_toi_thieu(tmp_path / "e.pdf",
                      [(72, 700, "Electrical characteristics", 10.0),
                       (72, 680, "Symbol Min Typ Max Unit", 10.0),
                       (72, 660, "VDD 1710 1800 3600 mV", 10.0)])
    _gia_lap(monkeypatch, {"params": [{"name": "Supply voltage", "symbol": "VDD",
                                       "min": 1710, "typ": 1800, "max": 3600, "unit": "mV"}]})
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_co_dien", lambda b: True)
    monkeypatch.setattr(m, "pdf_layout", lambda pr, cx: {
        "blocks": [_bang_khoi([["Symbol", "Min", "Typ", "Max", "Unit"],
                               ["VDD", "1710", "1800", "3600", "mV"]])], "toc": []})
    # T2 + ask "Luôn (an toàn)" ⇒ Router XẾP HÀNG CHỜ, không chạy ngay. Đó là hợp đồng, không
    # phải trở ngại của test: fact `voltage_range` sai là con đường ngắn nhất tới một board
    # cháy, nên nhóm này không bao giờ tự chạy. Duyệt rồi mới có fact.
    run = r.invoke("extract.pdf_electrical", {"file": str(p), "part": "st.x"}, ctx)
    assert run.status == "pending", "EXTRACT-07 là T2, phải hỏi người mọi lần"
    r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)
    with store.open_store(store.store_path(root)) as c:
        gt, dv, tier = c.execute(
            "SELECT value, unit, tier FROM fact WHERE predicate='voltage_range'").fetchone()
    d = json.loads(gt)
    assert (d["min"], d["max"]) == (1.71, 3.6)      # mV → V
    assert dv == "V" and tier == "silver"


def test_don_vi_khong_nhan_ra_thi_khong_sinh_fact(du_an, monkeypatch, tmp_path):
    """Không đoán: một fact điện sai là con đường ngắn nhất tới một board cháy."""
    r, ctx, root = du_an
    p = pdf_toi_thieu(tmp_path / "e.pdf", [(72, 700, "x", 10.0)])
    _gia_lap(monkeypatch, {"params": [{"name": "X", "symbol": "X", "min": 1, "unit": "furlong"}]})
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_co_dien", lambda b: True)
    monkeypatch.setattr(m, "pdf_layout", lambda pr, cx: {"blocks": [_bang_khoi([["a"]])],
                                                         "toc": []})
    run = r.invoke("extract.pdf_electrical", {"file": str(p), "part": "st.x"}, ctx)
    assert run.status == "pending"
    sau = r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)
    assert sau.status == "failed" and sau.error["eide_code"] == "E5002"
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM fact").fetchone()[0] == 0


# ---------------------------------------------------------------- EXTRACT-08 office


def test_bang_trong_docx_thanh_block_table(du_an, tmp_path):
    """tc nguyên văn. Trả CÙNG dạng khối như `pdf_layout` để `pdf_register_map` nhận được bất kể
    khối từ đâu — hai dạng khối thì phải có hai nhánh, và nhánh thứ hai không bao giờ được kiểm
    kỹ bằng nhánh thứ nhất."""
    docx = pytest.importorskip("docx")
    d = docx.Document()
    d.add_heading("Bảng thanh ghi", level=1)
    d.add_paragraph("Mô tả ngắn.")
    t = d.add_table(rows=2, cols=2)
    t.cell(0, 0).text = "Register"
    t.cell(0, 1).text = "Address"
    t.cell(1, 0).text = "CR1"
    t.cell(1, 1).text = "0x00"
    p = tmp_path / "a.docx"
    d.save(str(p))

    r, ctx, _ = du_an
    ds = r.invoke("extract.office", {"file": str(p)}, ctx).result["blocks"]
    bang = [b for b in ds if b["type"] == "table"]
    assert bang and bang[0]["content"] == [["Register", "Address"], ["CR1", "0x00"]]
    assert any(b["type"] == "heading" for b in ds)


def test_khoi_docx_dung_duoc_cho_pdf_register_map(du_an, tmp_path, monkeypatch):
    """Hệ quả của việc dùng chung dạng khối: một bảng thanh ghi dán vào Word đi đúng đường ấy."""
    docx = pytest.importorskip("docx")
    d = docx.Document()
    t = d.add_table(rows=2, cols=4)
    for j, o in enumerate(["Register", "Address", "Bits", "Reset"]):
        t.cell(0, j).text = o
    for j, o in enumerate(["CR1", "0x00", "15:0", "0x1"]):
        t.cell(1, j).text = o
    p = tmp_path / "a.docx"
    d.save(str(p))

    r, ctx, _ = du_an
    khoi = r.invoke("extract.office", {"file": str(p)}, ctx).result["blocks"]
    _gia_lap(monkeypatch, {"registers": [{"name": "CR1", "peripheral": "I2C1",
                                          "offset": "0x00"}]})
    out = r.invoke("extract.pdf_register_map",
                   {"file": str(p), "blocks": khoi, "part": "st.x"}, ctx).result
    assert out["n_facts"] >= 1


def test_bang_markdown(du_an, tmp_path):
    r, ctx, _ = du_an
    p = tmp_path / "a.md"
    p.write_text("# Tiêu đề\n\nvăn bản\n\n| A | B |\n|---|---|\n| 1 | 2 |\n", encoding="utf-8")
    ds = r.invoke("extract.office", {"file": str(p)}, ctx).result["blocks"]
    assert [b["content"] for b in ds if b["type"] == "table"] == [[["A", "B"], ["1", "2"]]]
    assert any(b["type"] == "heading" for b in ds)


def test_bang_html(du_an, tmp_path):
    r, ctx, _ = du_an
    p = tmp_path / "a.html"
    p.write_text("<h1>T</h1><p>x</p><table><tr><th>A</th><th>B</th></tr>"
                 "<tr><td>1</td><td>2</td></tr></table>", encoding="utf-8")
    ds = r.invoke("extract.office", {"file": str(p)}, ctx).result["blocks"]
    assert [b["content"] for b in ds if b["type"] == "table"] == [[["A", "B"], ["1", "2"]]]


def test_dinh_dang_la_bao_E1000(du_an, tmp_path):
    r, ctx, _ = du_an
    p = tmp_path / "a.xyz"
    p.write_text("x", encoding="utf-8")
    run = r.invoke("extract.office", {"file": str(p)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


# ---------------------------------------------------------------- EXTRACT-03 edc


EDC = """<?xml version="1.0"?>
<edc:PIC xmlns:edc="http://crownking/edc" edc:name="PIC16F18855">
  <edc:SFRDef edc:cname="PORTA" edc:_addr="0x00C" edc:_por="0x00">
    <edc:SFRFieldDef edc:cname="RA0" edc:_mask="0x01"/>
    <edc:SFRFieldDef edc:cname="RA1" edc:_mask="0x02"/>
  </edc:SFRDef>
  <edc:SFRDef edc:cname="TRISA" edc:_addr="0x08C"/>
</edc:PIC>
"""


def test_edc_doc_duoc_qua_namespace(du_an, tmp_path):
    """`ElementTree` giữ nguyên tiền tố dạng `{uri}SFRDef` trong `tag`, nên tìm theo tên trần sẽ
    không khớp gì — và "không khớp gì" trông y hệt "tệp không có thanh ghi nào"."""
    r, ctx, root = du_an
    p = tmp_path / "pic.PIC"
    p.write_text(EDC, encoding="utf-8")
    out = r.invoke("extract.edc", {"file": str(p)}, ctx).result
    assert out["n_facts"] >= 5
    with store.open_store(store.store_path(root)) as c:
        gt = {x[0]: json.loads(x[1]) for x in c.execute(
            "SELECT subject, value FROM fact WHERE predicate='address'")}
    assert gt["chip:microchip.pic16f18855/periph:SFR/reg:PORTA"] == 0x00C
    assert gt["chip:microchip.pic16f18855/periph:SFR/reg:TRISA"] == 0x08C


def test_edc_the_goc_sai_bao_E6001(du_an, tmp_path):
    r, ctx, _ = du_an
    p = tmp_path / "x.PIC"
    p.write_text("<device/>", encoding="utf-8")
    run = r.invoke("extract.edc", {"file": str(p)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E6001"


# ---------------------------------------------------------------- EXTRACT-04 header_c


HEADER = """
/** @file stm32f411xe.h */
#define STM32F411xE
#define I2C1_BASE            (0x40005400UL)
#define USART2_BASE          (0x40004400UL)
#define I2C_CR1_PE_Msk       (0x1UL)
#define I2C_CR1_PE_Pos       (0U)
#define I2C_CR1_SMBUS_Msk    (0x2UL)
"""


def test_header_rut_base_va_bit(du_an, tmp_path):
    r, ctx, root = du_an
    p = tmp_path / "stm32f411xe.h"
    p.write_text(HEADER, encoding="utf-8")
    out = r.invoke("extract.header_c", {"file": str(p)}, ctx).result
    assert out["n_facts"] >= 3
    with store.open_store(store.store_path(root)) as c:
        gt = {x[0]: json.loads(x[1]) for x in c.execute("SELECT subject, value FROM fact")}
    assert gt["chip:st.stm32f411xe/periph:I2C1"] == 0x40005400
    assert gt["chip:st.stm32f411xe/periph:I2C/reg:CR1/field:PE"] == [0, 0]


def test_lech_dia_chi_thi_conflict_1(du_an, tmp_path):
    """tc nguyên văn: "Lệch cố ý 1 địa chỉ → conflict 1". Bước 2 ("đối chiếu SVD") mới là lý do
    năng lực này đáng làm: header hãng và SVD hãng mô tả CÙNG con chip từ hai đường, và chỗ
    chúng bất đồng là chỗ một trong hai sai."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_svd','a.svd','h1','svd','gold')")
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status) VALUES ('f_1','chip:st.stm32f411xe/periph:I2C1',"
                  "'base_address','1094861824','s_svd','parser','gold',1.0,'normalized')")
        c.commit()                       # 0x40400000 — lệch cố ý so với header
    p = tmp_path / "stm32f411xe.h"
    p.write_text(HEADER, encoding="utf-8")
    out = r.invoke("extract.header_c", {"file": str(p)}, ctx).result
    assert out["conflicts"] == 1, out


def test_iri_header_khop_iri_svd(du_an, tmp_path):
    """Nếu hai nguồn sinh IRI khác nhau cho cùng một trường thì chúng KHÔNG gặp nhau, và bước
    đối chiếu mất tác dụng — chính là bước làm nên giá trị của năng lực này."""
    from eide.caps.extract import _iri_field
    assert _iri_field("chip:st.x", "I2C_CR1_PE") == "chip:st.x/periph:I2C/reg:CR1/field:PE"
    assert _iri_field("chip:st.x", "I2C_CR1") == "chip:st.x/periph:I2C/reg:CR1"


# ---------------------------------------------------------------- EXTRACT-09 code_constants


def test_hang_so_khong_ro_nguon_bi_liet_ke(du_an, tmp_path):
    """Một `0x40005400` viết tay trong driver có thể đúng, có thể là số của con chip người viết
    dùng lần trước. Không phân biệt được thì cả hai trông giống nhau tới lúc nạp lên board."""
    r, ctx, _ = du_an
    repo = tmp_path / "src"
    repo.mkdir()
    (repo / "i2c.c").write_text(
        "void f(void){ *(volatile int*)0x40009999 = 1; for(int i=0;i<10;i++){} }\n",
        encoding="utf-8")
    out = r.invoke("extract.code_constants", {"repo": str(repo)}, ctx).result
    assert out["code_units"] == 1
    assert [x["literal"] for x in out["unsourced"]] == ["0x40009999"]


def test_hang_so_khop_fact_thi_khong_bao(du_an, tmp_path):
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1','a.svd','h','svd','gold')")
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status) VALUES ('f_1','chip:x/periph:I2C1','base_address',"
                  "'1073763328','s_1','parser','gold',1.0,'normalized')")
        c.commit()                       # 0x40005400
    repo = tmp_path / "src"
    repo.mkdir()
    (repo / "a.c").write_text("#define I2C1 0x40005400\n", encoding="utf-8")
    assert r.invoke("extract.code_constants", {"repo": str(repo)}, ctx).result["unsourced"] == []


def test_chu_thich_eide_fact_duoc_ton_trong(du_an, tmp_path):
    r, ctx, _ = du_an
    repo = tmp_path / "src"
    repo.mkdir()
    (repo / "a.c").write_text("#define X 0x40009999  // eide:fact f_abc123\n", encoding="utf-8")
    assert r.invoke("extract.code_constants", {"repo": str(repo)}, ctx).result["unsourced"] == []


def test_so_nho_khong_vao_danh_sach(du_an, tmp_path):
    """Số nhỏ là chỉ số vòng lặp và kích thước mảng — đưa chúng vào `unsourced` thì danh sách
    toàn nhiễu, và một danh sách toàn nhiễu là danh sách không ai đọc."""
    r, ctx, _ = du_an
    repo = tmp_path / "src"
    repo.mkdir()
    (repo / "a.c").write_text("int a[16]; for(int i=0;i<8;i++){ a[i]=2; }\n", encoding="utf-8")
    assert r.invoke("extract.code_constants", {"repo": str(repo)}, ctx).result["unsourced"] == []


def test_bo_qua_thu_muc_build(du_an, tmp_path):
    r, ctx, _ = du_an
    repo = tmp_path / "src"
    (repo / "build").mkdir(parents=True)
    (repo / "build" / "gen.c").write_text("int x = 0x40009999;\n", encoding="utf-8")
    (repo / "a.c").write_text("int y = 1;\n", encoding="utf-8")
    out = r.invoke("extract.code_constants", {"repo": str(repo)}, ctx).result
    assert out["code_units"] == 1 and out["unsourced"] == []


_ = zlib, Path
