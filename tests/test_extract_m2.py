"""Nhóm extract.* mốc M2 — CDS-12.2; KAD-07 §3; DDD-14 §2 Fact.

EXTRACT-09 `extract.pdf_pinout` (tc: **"PB6 có I2C1_SCL AF4"**) và EXTRACT-10
`extract.pdf_errata` (tc: **"Errata I2C → fact có rev"**).

Cả hai đọc một LƯỚI: số AF đến từ vị trí cột `AF0…AF15`, rev bị ảnh hưởng đến từ vị trí cột
`Rev A`/`Rev Z`. Nên phần ấy làm bằng MÃ chứ không gọi mô hình — khác `extract.pdf_register_map`,
nơi cột "Bits" có mười cách viết nên mô hình là đúng chỗ. Hỏi mô hình một thứ đếm được là mở
đường cho nó đếm sai, và chính `tc` của hai hợp đồng ("AF4", "có rev") kiểm đúng cái đó. Văn
xuôi thì ngược lại: cách vòng tránh của một mục errata do mô hình đọc.

PDF trong test là PDF THẬT (`tests/pdf_gia_lap.py`), có đường kẻ khung.
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


# ================================================================ EXTRACT-10 pdf_errata
#
# tc: "Errata I2C → fact có rev". Errata là lớp phủ **K2′** của KAD-07 §5.1: nó KHÔNG ghi đè
# fact lõi (quy tắc R1 — "lõi giữ nguyên để tái lập"), nó nằm cạnh, ở lớp lưu trữ L-B, và mang
# theo ĐIỀU KIỆN áp dụng. Một errata không có rev là một errata không dùng được: người đọc không
# biết con chip trên bàn mình có dính hay không.

BANG_ERRATA = [["Section", "Errata title", "Rev A", "Rev Z"],
               ["2.4.1", "I2C analog filter may provide wrong value", "A", "A"],
               ["2.5.2", "SPI CRC error in slave mode", "A", "-"]]


def _gia_lap_mo_hinh(monkeypatch, data):
    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def run(self, *a, **k): return _R(data)
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())


MO_HINH_HAI_MUC = {"items": [
    {"title": "I2C analog filter may provide wrong value",
     "description": "Bộ lọc tương tự có thể cho giá trị sai khi SCL bị kéo xuống",
     "workaround": "Tắt bộ lọc tương tự, dùng bộ lọc số"},
    {"title": "SPI CRC error in slave mode", "workaround": "Không dùng CRC phần cứng ở chế độ tớ"},
]}


def _fact_vang_I2C1(ctx, root):
    """Một fact vàng như `extract.svd` sinh ra — nền để kiểm hai điều: errata nối vào ĐÚNG nút
    ngoại vi, và lõi K2 không bị lớp phủ ghi đè (KAD-07 R1)."""
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('src_svd','stm32f411.svd','h_svd','svd','gold')")
        c.commit()
    from eide.caps.passport import import_
    import_({"batch": {"facts": [{"subject": f"chip:{PART}/periph:I2C1",
                                  "predicate": "base_address", "value": 1073765376,
                                  "source_id": "src_svd", "method": "parser", "tier": "gold",
                                  "confidence": 1.0}],
                       "passport_id": f"{PART}@1.0.0", "kind": "chip",
                       "header": {"name": PART}}, "actor": "test"}, ctx)


def _chay_errata(r, ctx, file, part=PART):
    """EXTRACT-10 là **T2** và `ask_when` = "Luôn" ⇒ Router XẾP HÀNG CHỜ, không chạy ngay.

    Đó là hợp đồng chứ không phải trở ngại của test, và nó đúng: một mục errata gán nhầm rev
    thay đổi cách người ta chọn con chip cho cả lô sản xuất. Duyệt rồi mới có fact — cùng khuôn
    `extract.pdf_electrical` ở `test_extract_m1.py`.
    """
    run = r.invoke("extract.pdf_errata", {"file": file, "part": part}, ctx)
    assert run.status == "pending", "EXTRACT-10 là T2, phải hỏi người mọi lần"
    return r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)


def test_errata_I2C_ra_fact_co_rev(du_an, monkeypatch, tmp_path):
    """tc EXTRACT-10 nguyên văn: "Errata I2C → fact có rev"."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    out = _chay_errata(r, ctx, p).result
    assert out["batch_id"]

    f = _facts(root, "other")
    i2c = [v for k, v in f.items() if "I2C" in v["value"]["title"]]
    assert len(i2c) == 1
    assert i2c[0]["value"]["conditions"]["rev"] == ["A", "Z"]


def test_rev_lay_tu_o_danh_dau_khong_phai_moi_cot_deu_tinh(du_an, monkeypatch, tmp_path):
    """"-" ở cột Rev Z nghĩa là bản Z đã sửa. Tính cả nó vào là dán nhãn lỗi cho một con chip
    không có lỗi ấy — và người ta sẽ đi tìm cách vòng tránh cho một thứ không tồn tại."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    spi = [v for v in _facts(root, "other").values() if "SPI" in v["value"]["title"]]
    assert spi[0]["value"]["conditions"]["rev"] == ["A"]


def test_rev_khong_hoi_mo_hinh(du_an, monkeypatch, tmp_path):
    """Mô hình trả rev bịa cũng không lọt: rev đến từ VỊ TRÍ CỘT trong bảng tóm tắt, cùng lý do
    với số AF ở EXTRACT-09."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, {"items": [
        {"title": "I2C analog filter may provide wrong value", "rev": ["Y"],
         "conditions": {"rev": ["Y"]}, "workaround": "x"}]})
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    i2c = [v for v in _facts(root, "other").values() if "I2C" in v["value"]["title"]]
    assert i2c[0]["value"]["conditions"]["rev"] == ["A", "Z"]


def test_fact_errata_nam_o_lop_phu_B(du_an, monkeypatch, tmp_path):
    """KAD-07 §5.1: K2′ là **lớp phủ**, lưu ở L-B — `fact.layer = "B"`, không phải "C" mặc định.

    Đây không phải chi tiết hình thức: quy tắc R1 nói lõi K2 (SVD của hãng) **không bao giờ bị
    ghi đè** bởi tầng thấp hơn, và cái phân biệt "lớp phủ" với "fact dự án" chính là cột này.
    """
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    with store.open_store(store.store_path(root)) as c:
        lop = {x[0] for x in c.execute("SELECT DISTINCT layer FROM fact WHERE predicate='other'")}
    assert lop == {"B"}


def test_moi_muc_errata_mot_subject_rieng(du_an, monkeypatch, tmp_path):
    """Hai mục errata của cùng một chip phải có subject KHÁC nhau.

    `passport._gop_mot` gộp theo (subject, predicate): dồn mọi mục vào một subject thì mục thứ
    hai vào store với `status = conflict` — một xung đột tự tạo, và G-FACT sẽ hỏi người một câu
    hỏi vô nghĩa ("hai errata này cái nào đúng?") trong khi cả hai đều đúng.
    """
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    f = _facts(root, "other")
    assert len(f) == 2
    assert all(v["status"] != "conflict" for v in f.values())


def test_subject_nam_duoi_ngoai_vi_khi_store_da_biet_no(du_an, monkeypatch, tmp_path):
    """Nối errata vào ĐÚNG nút ngoại vi khi store đã có nó — nhờ vậy `kg.neighborhood` hỏi
    "biết gì về I2C1" là thấy cả errata.

    Ngoại vi lấy từ chính store chứ không đoán bằng biểu thức chính quy trên tiêu đề: đoán thì
    một dòng "Note on ADC and DMA" sinh ra hai ngoại vi, một trong hai có thể không tồn tại trên
    con chip này.
    """
    r, ctx, root = du_an
    _fact_vang_I2C1(ctx, root)

    _gia_lap_mo_hinh(monkeypatch, {"items": [{"title": "I2C1 analog filter may provide wrong value",
                                              "workaround": "tắt bộ lọc"}]})
    bang = [["Section", "Errata title", "Rev A"],
            ["2.4.1", "I2C1 analog filter may provide wrong value", "A"]]
    p = str(pdf_bang_ke(tmp_path / "er.pdf", bang, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    assert any(k.startswith(f"chip:{PART}/periph:I2C1/errata:") for k in _facts(root, "other"))


def test_khong_ghi_de_fact_loi_cua_hang(du_an, monkeypatch, tmp_path):
    """KAD-07 §5.2 R1: "Fact tầng vàng của hãng (K1, K2) **không bao giờ bị ghi đè**". Sau khi
    nạp errata, fact vàng của SVD phải còn nguyên và vẫn hiện hành."""
    r, ctx, root = du_an
    _fact_vang_I2C1(ctx, root)
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)

    g = _facts(root, "base_address")
    assert g[f"chip:{PART}/periph:I2C1"]["tier"] == "gold"
    assert g[f"chip:{PART}/periph:I2C1"]["value"] == 1073765376


def test_workaround_tu_mo_hinh_ghep_theo_tieu_de(du_an, monkeypatch, tmp_path):
    """Bảng tóm tắt cho điều kiện áp dụng; cách vòng tránh nằm ở VĂN XUÔI, nơi mô hình là đúng
    chỗ — đúng ranh giới đã dùng ở `pdf_register_map`."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    i2c = [v for v in _facts(root, "other").values() if "I2C" in v["value"]["title"]]
    assert "bộ lọc số" in i2c[0]["value"]["workaround"]


def test_mo_hinh_khong_tra_gi_van_con_fact_co_rev(du_an, monkeypatch, tmp_path):
    """Điều kiện áp dụng là phần KHÔNG được mất. Mô hình im lặng (hoặc chưa cấu hình) thì mục
    errata vẫn vào store với tiêu đề và rev — thiếu workaround là thiếu tiện lợi, thiếu rev là
    fact vô dụng."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, {"items": []})
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    f = _facts(root, "other")
    assert len(f) == 2
    assert all(v["value"]["conditions"]["rev"] for v in f.values())
    assert all(v["method"] == "parser" for v in f.values())


def test_bang_khong_phai_errata_thi_bo_qua(du_an, monkeypatch, tmp_path):
    """Không có cột rev thì không phải bảng tóm tắt errata — bỏ, không đoán."""
    r, ctx, _ = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_toi_thieu(tmp_path / "k.pdf", [(72, 700, "x", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [_khoi([["Section", "Errata title"],
                                        ["2.4.1", "I2C analog filter"]])])
    run = _chay_errata(r, ctx, p)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_khong_co_bang_errata_bao_E2000(du_an, monkeypatch, tmp_path):
    r, ctx, _ = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_toi_thieu(tmp_path / "m.pdf", [(72, 700, "khong co bang", 10.0)]))
    _bo_qua_bo_cuc(monkeypatch, [])
    run = _chay_errata(r, ctx, p)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_trich_errata_hai_lan_khong_nhan_doi(du_an, monkeypatch, tmp_path):
    """`undo: supersede_facts` — bản sau thay bản trước. Errata sheet lên rev mới là chuyện
    thường xuyên hơn cả datasheet."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, MO_HINH_HAI_MUC)
    p = str(pdf_bang_ke(tmp_path / "er.pdf", BANG_ERRATA, tieu_de="Device limitations"))
    _chay_errata(r, ctx, p)
    _chay_errata(r, ctx, p)
    assert len(_facts(root, "other")) == 2


@pytest.mark.parametrize(("o", "ap_dung"), [
    ("A", True), ("X", True), ("x", True), ("yes", True),
    ("-", False), ("", False), ("n/a", False), ("fixed", False), ("no", False),
])
def test_o_nao_nghia_la_ap_dung(o, ap_dung):
    """Bốn cách viết "có" và năm cách viết "không" — đều gặp trong errata sheet thật."""
    from eide.caps.extract import _co_danh_dau
    assert _co_danh_dau(o) is ap_dung


# ================================================================ EXTRACT-20 readme_goal
#
# tc: "Z-07 sinh F-01…F-08". README là thứ ĐẦU TIÊN đọc được trong một zip dự án lạ, và nó nói
# thứ mà không tệp SVD nào nói: dự án này ĐỂ LÀM GÌ. R0 vì nó không ghi gì vào store — nó đề
# xuất, còn `plan.define_feature` mới là chỗ cấp id và ghi FEATURES.json.

README_ROBOT = """# Balancing robot
Robot hai bánh tự cân bằng dùng STM32F411 và MPU-6050.

## Tính năng
- Đọc góc nghiêng từ IMU qua I2C ở 200 Hz
- Vòng PID giữ thân robot thẳng đứng
- Điều khiển hai động cơ bước qua driver A4988
- Báo trạng thái qua UART 115200
- Dừng khẩn khi nghiêng quá 45 độ
"""

GOAL_MO_HINH = {
    "goal": "Robot hai bánh tự cân bằng trên STM32F411 với IMU MPU-6050",
    "features": [
        {"title": "Đọc góc nghiêng từ IMU 200 Hz",
         "expectation": {"kind": "serial_pattern", "detail": "angle=.* xuất hiện 200 lần/giây"},
         "priority_guess": "must"},
        {"title": "Vòng PID giữ thăng bằng",
         "expectation": {"kind": "measurement", "detail": "|góc| < 5 độ trong 30 giây"},
         "priority_guess": "must"},
        {"title": "Điều khiển hai động cơ bước",
         "expectation": {"kind": "probe_reg", "detail": "TIM2_CR1.CEN = 1 khi chạy"},
         "priority_guess": "must"},
        {"title": "Báo trạng thái qua UART",
         "expectation": {"kind": "serial_pattern", "detail": "^STATUS "},
         "priority_guess": "should"},
        {"title": "Dừng khẩn khi nghiêng quá 45 độ",
         "expectation": {"kind": "serial_pattern", "detail": "^EMERGENCY_STOP"},
         "priority_guess": "must"},
    ],
    "bom_hints": ["STM32F411", "MPU-6050", "A4988", "MPU-6050"],
}


def _gia_lap_theo_schema(monkeypatch, ctx, goal, feature=None):
    """Một gateway giả trả lời theo SCHEMA được hỏi — `readme_goal` và `plan.define_feature` gọi
    hai schema khác nhau, và test nối hai năng lực phải đi qua cả hai."""
    class _R:
        def __init__(self, d): self.data = d

    class _G:
        def run(self, role, prompt, schema=None, **k):
            props = (schema or {}).get("properties") or {}
            if "expectation" in props:
                return _R(feature or {"title": prompt[-40:],
                                      "expectation": {"kind": "serial_pattern", "detail": "x"}})
            return _R(goal)

        def prompt(self, role):        # `memory.compose` dựng lớp C1 từ prompt vai trò
            return f"# {role}"
    import eide.caps.extract as m
    monkeypatch.setattr(m, "_gateway", lambda c: _G())
    ctx.extra["gateway"] = _G()


def test_readme_thanh_goal_va_feature_quan_sat_duoc(du_an, monkeypatch):
    """tc EXTRACT-20: 5–10 Feature, mỗi cái có kỳ vọng QUAN SÁT ĐƯỢC."""
    r, ctx, _ = du_an
    _gia_lap_theo_schema(monkeypatch, ctx, GOAL_MO_HINH)
    out = r.invoke("extract.readme_goal", {"text": README_ROBOT}, ctx).result
    assert "cân bằng" in out["goal"]
    assert 5 <= len(out["features"]) <= 10
    from eide.caps.plan import DANG_KY_VONG
    assert all(f["expectation"]["kind"] in DANG_KY_VONG for f in out["features"])


def test_Z07_sinh_F01_den_F08(du_an, monkeypatch):
    """tc nguyên văn: "Z-07 sinh F-01…F-08". Id do `plan.define_feature` cấp, không phải năng
    lực này — nên đây là test NỐI hai đầu: đề xuất từ README đi qua được cổng "kỳ vọng phải máy
    quan sát được" của PLAN-01 mà không phải sửa tay."""
    r, ctx, root = du_an
    tam = dict(GOAL_MO_HINH)
    tam["features"] = GOAL_MO_HINH["features"] * 2      # 10 đề xuất
    _gia_lap_theo_schema(monkeypatch, ctx, tam)
    out = r.invoke("extract.readme_goal", {"text": README_ROBOT}, ctx).result

    ids = []
    for f in out["features"][:8]:
        _gia_lap_theo_schema(monkeypatch, ctx, tam, feature=f)
        ids.append(r.invoke("plan.define_feature", {"text": f["title"]}, ctx).result["feature"]["id"])
    assert ids == [f"F-{i:02d}" for i in range(1, 9)]


def test_ky_vong_khong_quan_sat_duoc_thi_bo(du_an, monkeypatch):
    """Mô hình rất sẵn lòng viết một câu nghe như đo được mà không đo được. Giữ nó lại thì
    `plan.define_feature` mới là chỗ nổ — xa chỗ sai, và người đọc lỗi ở đó không biết nó đến từ
    một dòng trong README."""
    r, ctx, _ = du_an
    xau = {**GOAL_MO_HINH, "features": [
        *GOAL_MO_HINH["features"],
        {"title": "Robot trông mượt mà", "expectation": {"kind": "cam_nhan", "detail": "mượt"}},
        {"title": "Không có kỳ vọng"},
    ]}
    _gia_lap_theo_schema(monkeypatch, ctx, xau)
    out = r.invoke("extract.readme_goal", {"text": README_ROBOT}, ctx).result
    assert len(out["features"]) == 5
    assert all("trông mượt" not in f["title"] for f in out["features"])


def test_bom_hints_bo_trung_giu_thu_tu(du_an, monkeypatch):
    """`bom_hints` đi thẳng vào `extract.bom` làm gợi ý tra cứu. Trùng lặp ở đó thành hai dòng
    BOM cho cùng một linh kiện."""
    r, ctx, _ = du_an
    _gia_lap_theo_schema(monkeypatch, ctx, GOAL_MO_HINH)
    out = r.invoke("extract.readme_goal", {"text": README_ROBOT}, ctx).result
    assert out["bom_hints"] == ["STM32F411", "MPU-6050", "A4988"]


def test_khong_ghi_gi_vao_store(du_an, monkeypatch):
    """`undo: none` vì không có gì để hoàn tác: năng lực này ĐỀ XUẤT, không khẳng định. Một câu
    trong README không phải một fact phần cứng — nó là ý định của người viết."""
    r, ctx, root = du_an
    _gia_lap_theo_schema(monkeypatch, ctx, GOAL_MO_HINH)
    r.invoke("extract.readme_goal", {"text": README_ROBOT}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM fact").fetchone()[0] == 0


def test_mo_hinh_khong_ra_goal_bao_E5002(du_an, monkeypatch):
    r, ctx, _ = du_an
    _gia_lap_theo_schema(monkeypatch, ctx, {"goal": "", "features": [], "bom_hints": []})
    run = r.invoke("extract.readme_goal", {"text": README_ROBOT}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_text_rong_khong_goi_mo_hinh(du_an, monkeypatch):
    """Không có gì để đọc thì không hỏi mô hình: nó sẽ bịa ra một dự án, và bịa có sức thuyết
    phục vì không có gì để đối chiếu."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    run = r.invoke("extract.readme_goal", {"text": "   "}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


# ================================================================ EXTRACT-05 dt_binding
#
# tc: "Thuộc tính required đúng". Binding device tree là hộ chiếu của **K4 — ngoại vi ngoài**
# (cảm biến, driver): nó nói con BME280 cần những thuộc tính nào để khai trong devicetree, và
# thiếu một thuộc tính bắt buộc thì bản dựng Zephyr đỏ ở chỗ chẳng liên quan gì tới nó.

BINDING_ZEPHYR = """
description: Bosch BME280 temperature and humidity sensor
compatible: "bosch,bme280"
include: [sensor-device.yaml, i2c-device.yaml]
properties:
  reg:
    type: array
    required: true
    description: Địa chỉ I2C
  odr:
    type: string
    required: false
    enum:
      - "1"
      - "2"
      - "4"
  int-gpios:
    type: phandle-array
    required: false
"""

BINDING_LINUX = """
$id: http://devicetree.org/schemas/iio/bosch,bme280.yaml#
title: Bosch BME280
properties:
  compatible:
    enum:
      - bosch,bme280
  reg:
    maxItems: 1
  vdd-supply:
    description: nguồn 3V3
required:
  - compatible
  - reg
"""


def _binding(tmp_path, noi, ten="bosch,bme280.yaml"):
    p = tmp_path / ten
    p.write_text(noi, encoding="utf-8")
    return str(p)


def test_thuoc_tinh_required_dung_zephyr(du_an, monkeypatch, tmp_path):
    """tc EXTRACT-05 nguyên văn: "Thuộc tính required đúng" — dạng Zephyr, `required` nằm TRONG
    từng thuộc tính."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.dt_binding", {"file": _binding(tmp_path, BINDING_ZEPHYR)}, ctx)
    f = _facts(root, "other")
    assert f["chip:bosch.bme280/dtprop:reg"]["value"]["required"] is True
    assert f["chip:bosch.bme280/dtprop:int-gpios"]["value"]["required"] is False


def test_thuoc_tinh_required_dung_linux(du_an, monkeypatch, tmp_path):
    """Dạng dt-schema của Linux: `required` là một DANH SÁCH ở cấp cao, không nằm trong thuộc
    tính. Hai định dạng, cùng một ý — đọc được một cái mà không đọc được cái kia thì năng lực
    chỉ dùng được cho nửa số binding ngoài đời."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.dt_binding", {"file": _binding(tmp_path, BINDING_LINUX)}, ctx)
    f = _facts(root, "other")
    assert f["chip:bosch.bme280/dtprop:reg"]["value"]["required"] is True
    assert f["chip:bosch.bme280/dtprop:vdd-supply"]["value"]["required"] is False
    # `compatible` LÀ chủ thể, không phải một thuộc tính của chủ thể. Ở dạng Linux nó nằm trong
    # `properties`, nên không loại ra thì hộ chiếu có một thuộc tính tên `compatible` trỏ về
    # chính mình — và `required: [compatible, reg]` làm nó trông như một thứ phải khai.
    assert "chip:bosch.bme280/dtprop:compatible" not in f


def test_compatible_thanh_IRI_theo_quy_uoc_ns_part(du_an, monkeypatch, tmp_path):
    """`bosch,bme280` → `chip:bosch.bme280`: đúng khuôn `<ns.part>` mà KAD-07 §6.1 quy định cho
    subject IRI. Giữ nguyên dấu phẩy thì cùng một cảm biến có hai IRI khác nhau tuỳ nó được nạp
    từ binding hay từ datasheet, và không câu truy vấn nào nối được hai bên."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.dt_binding", {"file": _binding(tmp_path, BINDING_ZEPHYR)}, ctx)
    assert all(k.startswith("chip:bosch.bme280/") for k in _facts(root, "other"))


def test_enum_giu_nguyen_trong_fact(du_an, monkeypatch, tmp_path):
    """Bước 1 nêu "thuộc tính bắt buộc/enum": tập giá trị hợp lệ là thứ `code.generate_module`
    cần để không sinh ra một `odr = 3` mà driver từ chối."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.dt_binding", {"file": _binding(tmp_path, BINDING_ZEPHYR)}, ctx)
    assert _facts(root, "other")["chip:bosch.bme280/dtprop:odr"]["value"]["enum"] == ["1", "2", "4"]


def test_khong_co_compatible_bao_E2000(du_an, monkeypatch, tmp_path):
    """Không có `compatible` thì không biết binding này nói về THIẾT BỊ NÀO — và một fact không
    biết chủ thể của nó thì không tra được bằng gì."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = _binding(tmp_path, "description: x\nproperties:\n  reg:\n    type: array\n")
    run = r.invoke("extract.dt_binding", {"file": p}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_yaml_hong_bao_E4004(du_an, monkeypatch, tmp_path):
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = _binding(tmp_path, "compatible: [khong dong ngoac\n  - x\n")
    run = r.invoke("extract.dt_binding", {"file": p}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4004"


def test_binding_la_tang_bac_khong_phai_vang(du_an, monkeypatch, tmp_path):
    """KAD-07 §5.1: K4 (ngoại vi ngoài) là **bạc** — binding do cộng đồng/hệ điều hành soạn, không
    phải tài liệu hãng, nên nó qua G-FACT chứ không tự duyệt như SVD."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.dt_binding", {"file": _binding(tmp_path, BINDING_ZEPHYR)}, ctx)
    v = _facts(root, "other")["chip:bosch.bme280/dtprop:reg"]
    assert v["tier"] == "silver" and v["method"] == "parser"


def test_trich_binding_hai_lan_khong_nhan_doi(du_an, monkeypatch, tmp_path):
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    p = _binding(tmp_path, BINDING_ZEPHYR)
    r.invoke("extract.dt_binding", {"file": p}, ctx)
    r.invoke("extract.dt_binding", {"file": p}, ctx)
    assert len(_facts(root, "other")) == 3


# ================================================================ EXTRACT-17 bom
#
# tc: "BOM 12 linh kiện đúng ref/MPN". BOM là danh sách MUA: một dòng sai gói là một lô hàng
# không hàn được. Nên năng lực này gộp theo MPN ĐẦY ĐỦ chứ không theo phần gốc — xem DEV-078.

NETLIST_XML = """<?xml version="1.0" encoding="UTF-8"?>
<export version="E">
  <components>
    <comp ref="U1"><value>STM32F411CEU6</value><footprint>UFQFPN-48</footprint>
      <fields><field name="MPN">STM32F411CEU6</field></fields></comp>
    <comp ref="U2"><value>BME280</value><footprint>LGA-8</footprint>
      <fields><field name="MPN">BME280</field></fields></comp>
    <comp ref="U3"><value>A4988</value><footprint>QFN-28</footprint>
      <fields><field name="MPN">A4988SETTR-T</field></fields></comp>
    <comp ref="U4"><value>A4988</value><footprint>QFN-28</footprint>
      <fields><field name="MPN">A4988SETTR-T</field></fields></comp>
    <comp ref="R1"><value>10k</value><footprint>0603</footprint></comp>
    <comp ref="R2"><value>10k</value><footprint>0603</footprint></comp>
    <comp ref="C1"><value>100n</value><footprint>0402</footprint></comp>
  </components>
  <nets><net code="1" name="SCL"><node ref="U1" pin="92"/><node ref="U2" pin="6"/></net></nets>
</export>
"""

CSV_BOM = """Supplier Ref Description,Reference,MPN,Value,Qty,Footprint
vi dieu khien chinh,U1,STM32F411CEU6,STM32F411,1,UFQFPN-48
cam bien,U2,BME280,Sensor,1,LGA-8
dien tro keo,"R3,R4",RC0603FR-0710KL,10k,2,0603
chua ro,X9,,,1,
"""


def _tep(tmp_path, ten, noi):
    p = tmp_path / ten
    p.write_text(noi, encoding="utf-8")
    return str(p)


def test_bom_tu_netlist_dung_ref_va_MPN(du_an, monkeypatch, tmp_path):
    """tc EXTRACT-17: "BOM … đúng ref/MPN". Bảy linh kiện, năm dòng sau khi gộp trùng."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = _tep(tmp_path, "robot.net", NETLIST_XML)
    out = r.invoke("extract.bom", {"sources": [p], "kind": "schematic"}, ctx).result

    theo_ref = {tuple(d["ref"]): d for d in out["bom"]}
    assert theo_ref[("U1",)]["mpn"] == "STM32F411CEU6"
    assert theo_ref[("U3", "U4")]["qty"] == 2        # hai con A4988 gộp một dòng
    assert theo_ref[("R1", "R2")]["value"] == "10k"  # không có MPN thì gộp theo value+footprint
    assert len(out["bom"]) == 5


def test_gop_theo_MPN_day_du_khong_theo_phan_goc(du_an, monkeypatch, tmp_path):
    """DEV-078: hợp đồng nói "chuẩn hóa MPN (bỏ hậu tố gói), gộp trùng", nhưng gộp theo phần gốc
    thì `STM32F411CEU6` (UFQFPN) và `STM32F411CET6` (LQFP) thành MỘT dòng đặt hàng — và lô hàng
    về không hàn được lên mạch. Phần gốc vẫn được tính, để riêng ở `mpn_base` cho `bom_enrich`
    tra cứu."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    hai_goi = NETLIST_XML.replace(
        '<comp ref="C1"><value>100n</value><footprint>0402</footprint></comp>',
        '<comp ref="U5"><value>A4988</value><footprint>QFN-28</footprint>'
        '<fields><field name="MPN">A4988SETTR</field></fields></comp>')
    out = r.invoke("extract.bom", {"sources": [_tep(tmp_path, "b.net", hai_goi)],
                                   "kind": "schematic"}, ctx).result
    # `A4988SETTR-T` (băng cuộn) và `A4988SETTR` (khay) có CÙNG `mpn_base` — gộp theo phần gốc
    # thì hai mã đặt hàng khác nhau thành một dòng, và bên mua nhận về dạng đóng gói mình không
    # dùng được. Đây là chỗ duy nhất `_mpn_goc` chạm tới, nên nó là chỗ duy nhất kiểm được.
    mpn = sorted(d["mpn"] for d in out["bom"] if d.get("mpn"))
    assert mpn == ["A4988SETTR", "A4988SETTR-T", "BME280", "STM32F411CEU6"]
    assert len({d["mpn_base"] for d in out["bom"] if d.get("mpn")}) == 3
    a4988 = next(d for d in out["bom"] if d["mpn"] == "A4988SETTR-T")
    assert a4988["mpn_base"] == "A4988SETTR"


def test_bom_tu_csv_nhan_cot_theo_ten_gan_dung(du_an, monkeypatch, tmp_path):
    """"Reference" không phải "ref", "Qty" không phải "qty" — mọi BOM ngoài đời đặt tên cột một
    kiểu. Khớp gần đúng ở đây là bắt buộc, không phải tiện nghi."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    out = r.invoke("extract.bom", {"sources": [_tep(tmp_path, "bom.csv", CSV_BOM)]}, ctx).result
    d = {tuple(x["ref"]): x for x in out["bom"]}
    assert d[("U1",)]["mpn"] == "STM32F411CEU6"
    assert d[("R3", "R4")]["qty"] == 2       # ô "R3,R4" là HAI ref trong một ô
    assert "X9" in " ".join(out["unmatched"])


def test_locator_tung_dong(du_an, monkeypatch, tmp_path):
    """Bước 3 của hợp đồng: "Gắn locator từng dòng". Một BOM 200 dòng mà không nói dòng nào đến
    từ đâu thì lúc hai nguồn lệch nhau không ai truy được."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    out = r.invoke("extract.bom", {"sources": [_tep(tmp_path, "bom.csv", CSV_BOM)]}, ctx).result
    loc = out["bom"][0]["source_locator"]
    assert loc["file"] == "bom.csv" and loc["row"] == 2      # dòng 1 là tiêu đề


def test_hai_nguon_gop_lai(du_an, monkeypatch, tmp_path):
    """`sources` là một MẢNG: BOM thật hay đến từ sơ đồ cộng thêm một bảng mua hàng."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    out = r.invoke("extract.bom", {"sources": [_tep(tmp_path, "robot.net", NETLIST_XML),
                                               _tep(tmp_path, "bom.csv", CSV_BOM)]}, ctx).result
    u1 = next(d for d in out["bom"] if "U1" in d["ref"])
    assert u1["ref"] == ["U1"]
    assert u1["qty"] == 1                       # cùng ref + cùng MPN ở hai nguồn: KHÔNG cộng dồn
    assert len(u1["source_locator"]["also"]) == 1
    # `qty` = số ký hiệu DUY NHẤT. Cộng thêm mỗi lần một nguồn nhắc lại nó thì một BOM đọc từ
    # sơ đồ + bảng mua hàng sẽ đặt gấp đôi số linh kiện.
    assert all(d["qty"] == len(d["ref"]) for d in out["bom"] if d["ref"])


def test_readme_di_qua_mo_hinh(du_an, monkeypatch, tmp_path):
    """README không có bảng: đó là chỗ mô hình đúng việc — khác netlist và csv vốn đã có cấu
    trúc."""
    r, ctx, _ = du_an
    _gia_lap_mo_hinh(monkeypatch, {"items": [{"mpn": "MPU-6050", "qty": 1, "ref": "U7"},
                                             {"mpn": "A4988", "qty": 2}]})
    p = _tep(tmp_path, "README.md", "# Robot\nDùng MPU-6050 và hai driver A4988.\n")
    out = r.invoke("extract.bom", {"sources": [p], "kind": "readme"}, ctx).result
    assert {d["mpn"] for d in out["bom"]} == {"MPU-6050", "A4988"}
    assert next(d for d in out["bom"] if d["mpn"] == "A4988")["qty"] == 2


def test_anh_chua_lam_duoc_bao_E2000(du_an, monkeypatch, tmp_path):
    """Đường ảnh cần `extract.image_board`/`ocr` (M2, chưa hiện thực) — DEV-079. Nói thẳng ra
    thay vì trả BOM rỗng như thể tấm ảnh không có linh kiện nào."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = tmp_path / "board.png"
    p.write_bytes(b"\x89PNG\r\n\x1a\n")
    run = r.invoke("extract.bom", {"sources": [str(p)], "kind": "image"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert "extract.image_board" in run.error["candidates"]


def test_khong_nguon_nao_doc_duoc_bao_E5002(du_an, monkeypatch, tmp_path):
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = _tep(tmp_path, "rong.csv", "cot_la,cot_khac\n1,2\n")
    run = r.invoke("extract.bom", {"sources": [p]}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_bom_ghi_fact_de_hoan_tac_duoc(du_an, monkeypatch, tmp_path):
    """`undo: supersede_facts` chỉ có nghĩa nếu có fact để thay. Mỗi ref một fact dưới
    `board:<tên>/part:<ref>` — cùng IRI mà `extract.kicad_netlist` dùng, nên hai nguồn nói về
    cùng một linh kiện gặp nhau ở một chỗ thay vì hai."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    r.invoke("extract.bom", {"sources": [_tep(tmp_path, "robot.net", NETLIST_XML)],
                             "kind": "schematic"}, ctx)
    f = _facts(root, "other")
    assert f["board:robot/part:U1"]["value"]["mpn"] == "STM32F411CEU6"
    assert f["board:robot/part:U1"]["value"]["kind"] == "bom"


@pytest.mark.parametrize(("mpn", "goc"), [
    ("A4988SETTR-T", "A4988SETTR"),          # hậu tố băng, tách bằng dấu — bỏ được
    ("STM32F411CEU6-TR", "STM32F411CEU6"),
    ("BME280", "BME280"),
    ("LM358DR2G", "LM358DR2G"),              # dính liền: KHÔNG cắt, xem dưới
    ("RC0603FR-0710KL", "RC0603FR-0710KL"),  # `-0710KL` là phần mã hàng, không phải hậu tố
    ("", ""),
])
def test_bo_hau_to_dong_goi_chi_khi_tach_bang_dau(mpn, goc):
    """Chỉ bỏ hậu tố TÁCH BẰNG DẤU. `LM358DR2G` có `G` là mã mạ chân, nhưng cắt nó đi thì cũng
    cắt luôn chữ cái cuối của một mã hàng bất kỳ kết thúc bằng G — và một MPN cắt cụt tra ra
    linh kiện khác, hoặc không ra gì. Xem DEV-078."""
    from eide.caps.extract import _mpn_goc
    assert _mpn_goc(mpn) == goc


# ================================================================ EXTRACT-18 bom_enrich
#
# tc: "A4988 gắn datasheet Allegro". Một BOM chỉ có mã hàng thì mua được nhưng không LẬP TRÌNH
# được: bước này nối mỗi dòng với hộ chiếu đã có hoặc với datasheet của hãng, và cái gì không
# tra ra thì thành một yêu cầu thu nhận có tên chứ không im lặng biến mất.

BOM_ROBOT = [
    {"ref": ["U3", "U4"], "mpn": "A4988SETTR-T", "mpn_base": "A4988SETTR", "value": "A4988",
     "footprint": "QFN-28", "qty": 2, "source_locator": {"file": "robot.net", "row": 3}},
    {"ref": ["R1", "R2"], "mpn": "", "mpn_base": "", "value": "10k", "footprint": "0603",
     "qty": 2, "source_locator": {"file": "robot.net", "row": 5}},
]


def _khong_goi_mang(monkeypatch):
    """`search.vendor` gọi HEAD để ước lượng kích thước. Danh sách ứng viên KHÔNG phụ thuộc vào
    nó (hợp đồng SEARCH-02: "không gọi được mạng thì vẫn trả ứng viên"), nên test chặn ở đây."""
    import eide.caps.search as s
    monkeypatch.setattr(s, "_head", lambda uri: {})


def test_A4988_gan_datasheet_Allegro(du_an, monkeypatch):
    """tc EXTRACT-18 nguyên văn: "A4988 gắn datasheet Allegro"."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    _khong_goi_mang(monkeypatch)
    out = r.invoke("extract.bom_enrich", {"bom": BOM_ROBOT}, ctx).result

    a = next(d for d in out["bom"] if d["mpn"] == "A4988SETTR-T")
    assert "allegromicro.com" in a["datasheet"]["domain"]
    assert a["datasheet"]["kind"] == "pdf"


def test_tra_theo_mpn_base_khong_theo_ma_dat_hang(du_an, monkeypatch):
    """Tra bằng `mpn_base`, không bằng mã đặt hàng đầy đủ: hậu tố băng (`-T`) là chuyện của kho
    hàng, không có trang tài liệu nào mang nó. Đây là lý do EXTRACT-17 giữ `mpn_base` lại sau
    khi gộp — xem DEV-078.

    (Việc rút tiếp mã die từ `A4988SETTR` là của `search.vendor` và bảng nguồn TGT-19 §8, không
    phải của bước này — nên test kiểm THAM SỐ truyền đi, không kiểm URL trả về.)
    """
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    _khong_goi_mang(monkeypatch)
    da_hoi = []
    import eide.caps.search as s
    that = s.vendor
    monkeypatch.setattr(s, "vendor", lambda p, c: (da_hoi.append(p["part"]), that(p, c))[1])

    r.invoke("extract.bom_enrich", {"bom": BOM_ROBOT}, ctx)
    assert da_hoi == ["A4988SETTR"]         # không phải "A4988SETTR-T", và không hỏi cho R1/R2


def test_dong_khong_co_MPN_khong_sinh_yeu_cau(du_an, monkeypatch):
    """Một điện trở 10k/0603 không có datasheet để đi tìm. Sinh yêu cầu thu nhận cho nó là làm
    ngập hàng đợi của người bằng những việc không ai làm được."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    _khong_goi_mang(monkeypatch)
    out = r.invoke("extract.bom_enrich", {"bom": BOM_ROBOT}, ctx).result
    assert out["requests"] == []
    rr = next(d for d in out["bom"] if d["ref"] == ["R1", "R2"])
    assert "datasheet" not in rr


def test_khong_tra_ra_thi_mo_kg_request(du_an, monkeypatch):
    """"thiếu → kg.request" của bước 1: cái gì không tra ra phải thành một yêu cầu CÓ TÊN trong
    hàng đợi, không phải một dòng BOM lặng lẽ thiếu nguồn."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    _khong_goi_mang(monkeypatch)
    la = [{"ref": ["U9"], "mpn": "ZZZ9999", "mpn_base": "ZZZ9999", "value": "?", "footprint": "",
           "qty": 1, "source_locator": {"file": "x.csv", "row": 2}}]
    out = r.invoke("extract.bom_enrich", {"bom": la}, ctx).result
    assert len(out["requests"]) == 1
    with store.open_store(store.store_path(root)) as c:
        row = c.execute("SELECT part, state FROM acq_request").fetchone()
    assert row == ("ZZZ9999", "REQUESTED")


def test_khong_mo_hai_yeu_cau_cho_cung_mot_MPN(du_an, monkeypatch):
    """Chạy lại `bom_enrich` sau khi thêm một dòng BOM là chuyện thường. Mở thêm một yêu cầu
    trùng mỗi lần thì hàng đợi "chờ anh" thành một danh sách không ai đọc nữa."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    _khong_goi_mang(monkeypatch)
    la = [{"ref": ["U9"], "mpn": "ZZZ9999", "mpn_base": "ZZZ9999", "value": "?", "footprint": "",
           "qty": 1, "source_locator": {"file": "x.csv", "row": 2}}]
    r.invoke("extract.bom_enrich", {"bom": la}, ctx)
    out = r.invoke("extract.bom_enrich", {"bom": la}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM acq_request").fetchone()[0] == 1
    assert out["requests"] == []


def test_ho_chieu_da_co_thi_gan_thang(du_an, monkeypatch):
    """Hộ chiếu trong store thắng mọi ứng viên tải về: nó đã qua G-FACT, còn ứng viên mới chỉ là
    một URL."""
    r, ctx, root = du_an
    _khong_mo_hinh(monkeypatch)
    _khong_goi_mang(monkeypatch)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO passport (id, kind, header, created_at)"
                  " VALUES ('a4988@1.0.0','chip','{\"name\":\"A4988\"}','2026-09-10T00:00:00Z')")
        c.commit()
    out = r.invoke("extract.bom_enrich", {"bom": BOM_ROBOT}, ctx).result
    a = next(d for d in out["bom"] if d["mpn"] == "A4988SETTR-T")
    assert a["passport"] == "a4988@1.0.0"


def test_bom_rong_khong_phai_loi(du_an, monkeypatch):
    """`errors: []` — không có gì để làm giàu thì không có gì sai."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    _khong_goi_mang(monkeypatch)
    out = r.invoke("extract.bom_enrich", {"bom": []}, ctx).result
    assert out == {"bom": [], "requests": []}


# ================================================================ EXTRACT-11 pdf_formula
#
# tc: "skill có mã C tham chiếu và trang". Công thức bù nhiệt của một cảm biến KHÔNG phải fact
# phần cứng — nó là một thủ tục. Bước 1 nói thẳng "không thành fact": đưa một đoạn thuật toán
# vào bảng `fact` thì `passport.query` trả về một khối văn bản không có `subject` nào tra được.

PDF_CONG_THUC = [
    (72, 740, "4.2.3 Temperature compensation", 14.0),
    (72, 700, "The output must be compensated using the calibration data:", 9.0),
    (72, 680, "var1 = (t_fine / 2.0) - 64000.0", 9.0),
    (72, 660, "p = 1048576.0 - adc_P", 9.0),
    (72, 640, "p = (p - (var2 / 4096.0)) * 6250.0 / var1", 9.0),
]

SKILL_MO_HINH = {
    "title": "Bù nhiệt cho BME280",
    "summary": "Chuyển giá trị ADC thô thành áp suất bằng dữ liệu hiệu chuẩn trong NVM.",
    "code_c": ("double bme280_compensate_P(int32_t adc_P, int32_t t_fine)\n"
               "{\n"
               "    double var1 = ((double)t_fine / 2.0) - 64000.0;\n"
               "    return (1048576.0 - adc_P) * 6250.0 / var1;\n"
               "}"),
    "notes": ["var1 = 0 thì phải trả 0, chia cho 0 làm treo vòng đọc"],
}


def test_skill_co_ma_C_tham_chieu_va_trang(du_an, monkeypatch, tmp_path):
    """tc EXTRACT-11 nguyên văn: "skill có mã C tham chiếu và trang"."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, SKILL_MO_HINH)
    p = str(pdf_toi_thieu(tmp_path / "bme280.pdf", PDF_CONG_THUC))
    out = r.invoke("extract.pdf_formula",
                   {"file": p, "section": "Temperature compensation", "part": "bosch.bme280"},
                   ctx).result

    sp = Path(out["skill_path"])
    assert sp.is_file()
    noi = sp.read_text(encoding="utf-8")
    assert "```c" in noi and "bme280_compensate_P" in noi
    assert "trang 1" in noi        # trích dẫn trang, không phải "xem datasheet"


def test_front_matter_applies_to(du_an, monkeypatch, tmp_path):
    """K5 trong gói có front-matter `applies_to` (BEN/PKG/GPI §gói). Thiếu nó thì skill không
    bao giờ được chọn vào ngữ cảnh cho đúng con chip."""
    r, ctx, _ = du_an
    _gia_lap_mo_hinh(monkeypatch, SKILL_MO_HINH)
    p = str(pdf_toi_thieu(tmp_path / "bme280.pdf", PDF_CONG_THUC))
    out = r.invoke("extract.pdf_formula",
                   {"file": p, "section": "Temperature compensation", "part": "bosch.bme280"},
                   ctx).result
    import yaml
    fm = yaml.safe_load(Path(out["skill_path"]).read_text(encoding="utf-8").split("---")[1])
    assert fm["applies_to"] == ["chip:bosch.bme280"]
    assert fm["source"]["file"] == "bme280.pdf" and fm["source"]["pages"] == [1]


def test_khong_sinh_fact(du_an, monkeypatch, tmp_path):
    """Bước 1: "không thành fact". Một thủ tục không có `subject` để tra, và nhét nó vào bảng
    `fact` là làm hỏng chính thứ làm nên giá trị của bảng ấy."""
    r, ctx, root = du_an
    _gia_lap_mo_hinh(monkeypatch, SKILL_MO_HINH)
    p = str(pdf_toi_thieu(tmp_path / "bme280.pdf", PDF_CONG_THUC))
    r.invoke("extract.pdf_formula",
             {"file": p, "section": "Temperature compensation", "part": "bosch.bme280"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM fact").fetchone()[0] == 0


def test_dang_ky_undo_xoa_tep(du_an, monkeypatch, tmp_path):
    """`undo: delete_created_files` — skill là tệp sinh ra, nên phải gỡ lại được."""
    r, ctx, _ = du_an
    _gia_lap_mo_hinh(monkeypatch, SKILL_MO_HINH)
    p = str(pdf_toi_thieu(tmp_path / "bme280.pdf", PDF_CONG_THUC))
    r.invoke("extract.pdf_formula",
             {"file": p, "section": "Temperature compensation", "part": "bosch.bme280"}, ctx)
    # Lọc theo `undo_ref` chứ không chỉ theo `kind`: `project.create` cũng đăng ký
    # `delete_created_files`, nên đếm theo kind thì test này xanh cả khi năng lực không đăng ký
    # gì — kiểm đột biến bắt được đúng chỗ ấy.
    ref = [(e.get("data") or {}).get("undo_ref", "") for e in r.ledger.records()
           if (e.get("data") or {}).get("kind") == "delete_created_files"]
    assert any(x.startswith("skill:") for x in ref), ref


def test_khong_thay_muc_bao_E2000(du_an, monkeypatch, tmp_path):
    """Không tìm thấy mục thì báo, không đưa cả tài liệu cho mô hình: một skill "bù nhiệt" viết
    từ chương đặt hàng trông vẫn rất thuyết phục."""
    r, ctx, _ = du_an
    _khong_mo_hinh(monkeypatch)
    p = str(pdf_toi_thieu(tmp_path / "bme280.pdf", PDF_CONG_THUC))
    run = r.invoke("extract.pdf_formula",
                   {"file": p, "section": "Chuong khong ton tai", "part": "bosch.bme280"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_mo_hinh_khong_ra_ma_C_bao_E5002(du_an, monkeypatch, tmp_path):
    """Một skill không có mã thì không dùng được: `code.generate_module` không có gì để chép,
    và người đọc vẫn phải mở datasheet. Xem DEV-080 (hợp đồng khai `errors: []`)."""
    r, ctx, _ = du_an
    _gia_lap_mo_hinh(monkeypatch, {**SKILL_MO_HINH, "code_c": ""})
    p = str(pdf_toi_thieu(tmp_path / "bme280.pdf", PDF_CONG_THUC))
    run = r.invoke("extract.pdf_formula",
                   {"file": p, "section": "Temperature compensation", "part": "bosch.bme280"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_chay_lai_ghi_de_cung_mot_tep(du_an, monkeypatch, tmp_path):
    """Cùng (part, section) → cùng một skill. Sinh `…-2.md` mỗi lần chạy lại thì thư mục skill
    đầy những bản gần giống nhau và không ai biết bản nào đang được nạp."""
    r, ctx, _ = du_an
    _gia_lap_mo_hinh(monkeypatch, SKILL_MO_HINH)
    p = str(pdf_toi_thieu(tmp_path / "bme280.pdf", PDF_CONG_THUC))
    a = r.invoke("extract.pdf_formula",
                 {"file": p, "section": "Temperature compensation", "part": "bosch.bme280"},
                 ctx).result["skill_path"]
    b = r.invoke("extract.pdf_formula",
                 {"file": p, "section": "Temperature compensation", "part": "bosch.bme280"},
                 ctx).result["skill_path"]
    assert a == b
    assert len(list(Path(a).parent.glob("*.md"))) == 1
