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
