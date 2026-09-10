"""Nhóm extract.* mốc M2 — CDS-12.2; KAD-07 §3; DDD-14 §2 Fact.

EXTRACT-09 `extract.pdf_pinout`. tc nguyên văn: **"PB6 có I2C1_SCL AF4"**.

Bảng "Alternate function mapping" trong datasheet thật là một lưới: số AF đến từ **vị trí cột**,
không từ tên hàm. Nên phần đọc bảng ở đây làm bằng MÃ chứ không gọi mô hình — khác
`extract.pdf_register_map`, nơi cột "Bits" có mười cách viết nên mô hình là đúng chỗ. Hỏi mô
hình một thứ đếm được là mở đường cho nó đếm sai, và chính tc của hợp đồng ("AF4") kiểm cái đó.

PDF trong test là PDF THẬT (`tests/pdf_gia_lap.py`), có đường kẻ khung.
"""
from __future__ import annotations

import json

import pytest

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from pdf_gia_lap import pdf_bang_ke, pdf_toi_thieu

pdfplumber = pytest.importorskip("pdfplumber", reason="extract.pdf_* cần pdfplumber")

PART = "st.stm32f411ce"

BANG_AF = [["Port", "AF0", "AF1", "AF2", "AF3", "AF4", "AF5", "AF6", "AF7"],
           ["PB6", "", "TIM4_CH1", "", "", "I2C1_SCL", "", "", "USART1_TX"],
           ["PB7", "", "TIM4_CH2", "", "", "I2C1_SDA", "", "", "USART1_RX"]]

BANG_CHAN = [["Pin", "Name", "Type", "I/O structure"],
             ["92", "PB6", "I/O", "FT"],
             ["93", "PB7", "I/O", "FT"]]


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án pinout"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


@pytest.fixture
def pdf_af(tmp_path):
    return str(pdf_bang_ke(tmp_path / "ds.pdf", BANG_AF,
                           tieu_de="Table 9. Alternate function mapping"))


def _facts(root, vi_tu="pin_function"):
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute("SELECT subject, value, tier, method, confidence, locator, status"
                         "  FROM fact WHERE predicate=?"
                         "   AND status NOT IN ('superseded','rejected')", (vi_tu,)).fetchall()
    return {s: {"value": json.loads(v), "tier": t, "method": m, "confidence": cf,
                "locator": json.loads(loc) if loc else None, "status": st}
            for s, v, t, m, cf, loc, st in rows}


def _khoi(noi, page=1, bbox=None):
    return {"page": page, "bbox": bbox or [40, 90, 580, 140], "type": "table", "content": noi}


def _khong_mo_hinh(monkeypatch):
    """Nổ nếu năng lực gọi mô hình. Đường bảng phải là mã thuần."""
    import eide.caps.extract as m

    def _no(ctx):
        raise AssertionError("đường bảng KHÔNG được gọi mô hình: số AF là vị trí cột")
    monkeypatch.setattr(m, "_gateway", _no)


def _bo_qua_bo_cuc(monkeypatch, khoi):
    """Thay `pdf_layout` để kiểm phần CHỌN BẢNG mà không phải dựng PDF cho từng biến thể.

    `input_schema` của EXTRACT-09 chỉ có `file` và `part` (`additionalProperties: false`), nên
    không có đường nào truyền `blocks` qua tham số — khác EXTRACT-07. Đó là chủ ý của hợp đồng,
    và test phải tôn trọng nó thay vì nới schema cho dễ kiểm.
    """
    import eide.caps.extract as m
    monkeypatch.setattr(m, "pdf_layout", lambda params, ctx: {"blocks": khoi, "toc": []})


# ---------------------------------------------------------------- tc của hợp đồng


def test_PB6_co_I2C1_SCL_AF4(du_an, monkeypatch, pdf_af):
    """tc EXTRACT-09 nguyên văn: "PB6 có I2C1_SCL AF4"."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    out = r.invoke("extract.pdf_pinout", {"file": pdf_af, "part": PART}, ctx).result
    assert out["batch_id"]

    f = _facts(root)[f"chip:{PART}/pin:PB6"]["value"]
    assert f["pin"] == "PB6"
    assert "I2C1_SCL" in f["functions"]
    assert f["af"]["I2C1_SCL"] == 4


def test_so_AF_lay_tu_vi_tri_cot_khong_tu_ten(du_an, monkeypatch, pdf_af):
    """USART1_TX ở cột AF7 của cùng một hàng: nếu số AF đến từ tên hàm hay từ thứ tự xuất hiện
    thì cái thứ hai này sai, còn cái đầu vẫn đúng."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.pdf_pinout", {"file": pdf_af, "part": PART}, ctx)
    af = _facts(root)[f"chip:{PART}/pin:PB6"]["value"]["af"]
    assert af == {"TIM4_CH1": 1, "I2C1_SCL": 4, "USART1_TX": 7}


def test_doi_cho_cot_thi_so_AF_doi_theo(du_an, monkeypatch, tmp_path):
    """Đối chứng của test trên: cùng tên hàm, đặt ở cột khác thì số phải khác. Không có test này
    thì một hiện thực tra bảng tên→AF cứng vẫn xanh."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    lech = [["Port", "AF0", "AF1", "AF2", "AF3", "AF4", "AF5", "AF6"],
            ["PB6", "", "", "", "", "", "", "I2C1_SCL"]]
    p = str(pdf_bang_ke(tmp_path / "lech.pdf", lech, tieu_de="Alternate function mapping"))
    r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)
    assert _facts(root)[f"chip:{PART}/pin:PB6"]["value"]["af"] == {"I2C1_SCL": 6}


# ---------------------------------------------------------------- chọn bảng, không đoán


def test_bang_khong_nhan_ra_tieu_de_thi_bo_qua(du_an, monkeypatch, tmp_path):
    """Không nhận ra tiêu đề cột thì BỎ bảng, không đoán.

    Bảng đặc tính điện dưới đây có "PB6" ngay ở cột đầu — nhìn từ nội dung thì không phân biệt
    được với một bảng pinout. Chỉ HÀNG TIÊU ĐỀ mới nói nó là bảng gì. Bỏ phép kiểm ấy đi thì
    năng lực sinh ra một chân PB6 có `type` = "input leakage current", và cái sai đó trông hoàn
    toàn hợp lệ trong hộ chiếu.

    (Bản test đầu của tôi dùng bảng đặt hàng, và kiểm đột biến cho thấy nó xanh cả khi phép kiểm
    tiêu đề bị gỡ bỏ — vì `_ten_chan` chặn "STM32F411CEU6" trước. Nó kiểm nhầm khẳng định.)
    """
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_toi_thieu(tmp_path / "x.pdf", [(72, 700, "x", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [_khoi([["Symbol", "Parameter", "Min", "Max"],
                                        ["PB6", "input leakage current", "-1", "1"]])])
    run = r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_khong_co_bang_pinout_bao_E2000_va_chi_duong_hinh(du_an, monkeypatch, tmp_path):
    """`ask_when` của hợp đồng là "Từ hình", nhưng đường hình cần `extract.ocr`/`image_*` (M2,
    chưa hiện thực) — xem DEV-076. Lỗi phải NÓI RA điều đó thay vì trả rỗng như thể tài liệu
    không có pinout."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_toi_thieu(tmp_path / "y.pdf", [(72, 700, "khong co bang nao", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [])
    run = r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert "extract.ocr" in run.error["candidates"]


def test_tep_khong_co_bao_E2000(du_an, monkeypatch, tmp_path):
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    run = r.invoke("extract.pdf_pinout", {"file": str(tmp_path / "khong-co.pdf"), "part": PART},
                   ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------------------------------------------------------------- hình dạng fact


def test_bang_dinh_nghia_chan_cho_type_va_gop_voi_bang_AF(du_an, monkeypatch, tmp_path):
    """Hai loại bảng nói về cùng một chân thì phải ra MỘT fact, không phải hai.

    Hai fact cùng subject + cùng vị từ với value khác nhau là một mâu thuẫn tự tạo: G-FACT-04
    đưa nó vào hàng đợi hỏi người, cho một câu hỏi mà không ai trả lời được vì cả hai đều đúng.
    """
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_toi_thieu(tmp_path / "z.pdf", [(72, 700, "x", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [_khoi(BANG_CHAN, page=41), _khoi(BANG_AF, page=47)])
    r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)

    f = _facts(root)
    assert len([k for k in f if k.endswith("/pin:PB6")]) == 1
    v = f[f"chip:{PART}/pin:PB6"]["value"]
    assert v["type"] == "I/O" and v["af"]["I2C1_SCL"] == 4


def test_functions_la_mang_chuoi(du_an, monkeypatch, pdf_af):
    """`board._chan_thay_the` và `diagram._chan_chuc_nang` đều đọc `v["functions"]` rồi lặp trên
    nó. Đổi kiểu của trường này là làm hỏng hai chỗ ấy trong im lặng."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.pdf_pinout", {"file": pdf_af, "part": PART}, ctx)
    fs = _facts(root)[f"chip:{PART}/pin:PB6"]["value"]["functions"]
    assert isinstance(fs, list) and all(isinstance(x, str) for x in fs)


def test_board_tra_duoc_chan_thay_the_sau_khi_trich(du_an, monkeypatch, tmp_path):
    """Lý do năng lực này đi trước cả khối D: `board.propose_fix` hiện trả "chưa tra được chân
    thay thế". Sau khi có fact `pin_function` nó phải tra ra PB8 cho một xung đột ở PB6.

    PB8 chứ không phải PB7: chân thay thế là chân mang CÙNG chức năng, và trên F411 thật thì
    PB6/PB8 cùng là `I2C1_SCL` còn PB7 là `I2C1_SDA` — nửa kia của cùng một bus.
    """
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    bang = [*BANG_AF, ["PB8", "", "TIM4_CH3", "", "", "I2C1_SCL", "", "", ""]]
    p = str(pdf_bang_ke(tmp_path / "b.pdf", bang, tieu_de="Alternate function mapping"))
    r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)
    from eide.caps.board import _chan_thay_the
    assert "PB8" in _chan_thay_the(root, "PB6")


def test_package_thanh_fact_rieng(du_an, monkeypatch, tmp_path):
    """Tên vỏ là thứ quyết định chân nào TỒN TẠI trên con chip đang cầm — `package` nằm sẵn
    trong enum vị từ của DDD-14, không phải xin thêm."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_bang_ke(tmp_path / "pk.pdf", BANG_AF,
                        tieu_de="Table 9. Pinouts and pin description LQFP48"))
    r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)
    pk = _facts(root, "package")
    assert pk[f"chip:{PART}"]["value"] == {"name": "LQFP48", "pins": 48}


def test_locator_tro_dung_bang_khong_hoi_mo_hinh(du_an, monkeypatch, tmp_path):
    """Một fact "trang 47" thì vẫn phải tự dò cả trang; `bbox` cho người kiểm mở đúng ô."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_toi_thieu(tmp_path / "l.pdf", [(72, 700, "x", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [_khoi(BANG_AF, page=47, bbox=[1, 2, 3, 4])])
    r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)
    assert _facts(root)[f"chip:{PART}/pin:PB6"]["locator"] == {"page": 47, "bbox": [1, 2, 3, 4]}


def test_tier_silver_va_method_parser(du_an, monkeypatch, pdf_af):
    """`silver` vì nguồn là PDF (không phải SVD của hãng), `parser` vì không mô hình nào tham
    gia — G-FACT-02 loại riêng `vision_llm`, nên method phải nói đúng cách fact được rút."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.pdf_pinout", {"file": pdf_af, "part": PART}, ctx)
    f = _facts(root)[f"chip:{PART}/pin:PB6"]
    assert f["tier"] == "silver" and f["method"] == "parser"


def test_confidence_tinh_tu_do_day_cua_bang(du_an, monkeypatch, tmp_path):
    """Bảng AF đủ cột đáng tin hơn một bảng chỉ có Pin + Name, và con số phải phản ánh điều đó
    thay vì là một hằng số chép tay."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_toi_thieu(tmp_path / "c.pdf", [(72, 700, "x", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [_khoi(BANG_AF)])
    r.invoke("extract.pdf_pinout", {"file": p, "part": "st.a"}, ctx)
    _bo_qua_bo_cuc(monkeypatch, [_khoi([["Pin", "Name"], ["92", "PB6"]])])
    r.invoke("extract.pdf_pinout", {"file": p, "part": "st.b"}, ctx)

    f = _facts(root)
    assert f["chip:st.b/pin:PB6"]["confidence"] < f["chip:st.a/pin:PB6"]["confidence"] < 1.0


def test_trich_hai_lan_khong_nhan_doi_fact(du_an, monkeypatch, pdf_af):
    """`undo: supersede_facts` — bản trích sau thay bản trước, không nằm cạnh nó. Trích lại một
    datasheet là việc thường (bản Rev 8 thay Rev 7), và mỗi lần thêm một bộ fact song song thì
    `passport.query` trả hai câu trả lời cho cùng một câu hỏi."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.pdf_pinout", {"file": pdf_af, "part": PART}, ctx)
    r.invoke("extract.pdf_pinout", {"file": pdf_af, "part": PART}, ctx)
    with store.open_store(store.store_path(root)) as c:
        (n,) = c.execute("SELECT COUNT(*) FROM fact WHERE predicate='pin_function'"
                         " AND subject=? AND status NOT IN ('superseded','rejected')",
                         (f"chip:{PART}/pin:PB6",)).fetchone()
    assert n == 1


# ---------------------------------------------------------------- đơn vị: đọc bảng


@pytest.mark.parametrize(("hang", "cho"), [
    (["PB6", "", "I2C1_SCL"], {"I2C1_SCL": 2}),
    (["PB6", "SYS_MCO", "I2C1_SCL/TIM4_CH1"], {"SYS_MCO": 1, "I2C1_SCL": 2, "TIM4_CH1": 2}),
    (["PB6", "-", "I2C1_SCL"], {"I2C1_SCL": 2}),
])
def test_o_nhieu_ham_va_o_rong(hang, cho):
    """Một ô AF thật có thể chứa hai hàm ngăn bằng `/`, và ô trống hay được in là `-`."""
    from eide.caps.extract import _hang_af
    assert _hang_af(hang, {1: 1, 2: 2}) == cho


def test_ten_chan_phai_dung_dang_moi_nhan(du_an, monkeypatch, tmp_path):
    """Hàng "Reserved" hay hàng ghi chú không phải một chân. Nhận bừa thì hộ chiếu có một chân
    tên "Note" và `board.check_pins` đi tìm nó trên board thật."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_toi_thieu(tmp_path / "n.pdf", [(72, 700, "x", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [_khoi([["Port", "AF0", "AF1", "AF2", "AF3", "AF4"],
                                        ["Reserved", "", "", "", "", "x"],
                                        ["PB6", "", "", "", "", "I2C1_SCL"]])])
    r.invoke("extract.pdf_pinout", {"file": p, "part": PART}, ctx)
    assert set(_facts(root)) == {f"chip:{PART}/pin:PB6"}


def test_khong_ghi_de_hop_dong_input_schema(du_an, monkeypatch, pdf_af):
    """`additionalProperties: false` — Router chặn tham số lạ bằng E1000 trước khi vào handler."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    with pytest.raises(EideError) as e:
        r.invoke("extract.pdf_pinout", {"file": pdf_af, "part": PART, "blocks": []}, ctx)
    assert e.value.code == "E1000"
