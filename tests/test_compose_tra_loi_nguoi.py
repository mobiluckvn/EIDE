"""[DEV-174a] Câu trả lời của NGƯỜI phải vào được ngữ cảnh — nếu không, vòng cộng tác không khép.

Đo 22/09/2026 trên dự án `nhap-nhay-led-tren-atmega328p`: planner hỏi hai câu rất cụ thể, người
dùng trả lời cả hai qua `req.answer_clarification` (cả hai về `answered`), bảo tác tử lập lại kế
hoạch — và **nó hỏi y nguyên câu cũ**. Gói ngữ cảnh vai trò `planner` khi ấy có đúng ba lớp
`['C1','C0','C2']`, 687 token trên ngân sách 9000.

Đây là vế "rồi tôi mới chọn" trong nhịp chủ sản phẩm đặt ra ngày 20/09: người dùng gõ vào một
cái hộp mà tác tử không bao giờ mở.

Kèm nửa thứ hai của cùng một lỗ hổng: `plan.create` nói với mô hình đúng một chuỗi — *"Lập kế
hoạch cho tính năng: F-01"* — trong khi `.eide/FEATURES.json` giữ đủ tiêu đề, kỳ vọng đo được
và ràng buộc. Nên planner hỏi lại *"chưa rõ chu kỳ nhấp nháy (500ms hay 1000ms)"* cho một tính
năng ghi sẵn *"chu kỳ 1 giây (500ms mức cao, 500ms mức thấp)"*.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.memory import _c2_tra_loi_cua_nguoi, _c5_tinh_nang, compose
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

HOI = "Chưa rõ chân GPIO nối với LED"
TRA = "LED nối chân PB5, mức cao là sáng"


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "nhấp nháy LED"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _clar(root, cid, hoi, tra=None, ai="Vũ Trí Công", at="2026-09-22T10:00:00+00:00"):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO clarification (id, kind, text, status, answer, answered_by,"
                  " answered_at, created_at) VALUES (?,'gap',?,?,?,?,?,?)",
                  (cid, hoi, "answered" if tra else "open", tra, ai if tra else None,
                   at if tra else None, at))
        c.commit()


def _feature(root, **k):
    ft = {"id": "F-01", "title": "Nhấp nháy LED trên chân PB5 với chu kỳ 1 giây",
          "expectation": {"kind": "measurement",
                          "detail": "Đo tín hiệu trên PB5 có chu kỳ 1 giây (500ms cao, 500ms thấp)"},
          "constraints": ["PB5 phải là ngõ ra"], "touches": ["PB5", "PORTB", "DDRB"],
          "status": "failing", **k}
    (root / ".eide" / "FEATURES.json").write_text(
        json.dumps({"features": [ft]}, ensure_ascii=False), encoding="utf-8")


def _khoi(b, lop, chua=""):
    return [x for x in b["blocks"] if x["layer"] == lop and chua in x["text"]]


# ---------- (1) câu trả lời vào được ngữ cảnh


def test_cau_tra_loi_vao_goi_ngu_canh(du_an):
    """Phép đo trung tâm: trước bản vá, gói ngữ cảnh không có lớp nào mang câu trả lời."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    b = compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"]
    kh = _khoi(b, "C2", "ĐÃ TRẢ LỜI")
    assert kh, [x["layer"] for x in b["blocks"]]
    assert HOI in kh[0]["text"] and TRA in kh[0]["text"]


def test_noi_ro_day_la_su_that_va_DUNG_HOI_LAI(du_an):
    """Một danh sách hỏi–đáp trần không nói cho mô hình biết phải LÀM GÌ với nó. Câu dẫn là
    phần mang nghĩa: đây là sự thật về dự án, và không hỏi lại."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C2", "ĐÃ TRẢ LỜI")
    assert "KHÔNG hỏi lại" in kh[0]["text"]


def test_diem_CHUA_tra_loi_thi_khong_dua_vao(du_an):
    """Một câu hỏi chưa có đáp án đưa vào ngữ cảnh chỉ là nhắc mô hình hỏi lại."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI)                      # còn `open`
    assert _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"],
                 "C2", "ĐÃ TRẢ LỜI") == []


def test_khoi_RIENG_va_KHONG_cache(du_an):
    """`constraints.yaml` gần như tĩnh nên khối ràng buộc cache được; danh sách câu trả lời đổi
    mỗi lần người gõ một câu. Nhập chung là làm hỏng cache của cả hai."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    c2 = [x for x in compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"]["blocks"]
          if x["layer"] == "C2"]
    assert len(c2) == 2, c2
    assert {x["cacheable"] for x in c2} == {True, False}


def test_KHONG_BAO_GIO_bi_cat(du_an):
    """C2 có `cut_priority = 9`. Một câu người đã trả lời mà bị bỏ lúc ngữ cảnh chật là tệ nhất
    trong các cách quên: người dùng tin rằng họ đã nói rồi."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C2", "ĐÃ TRẢ LỜI")
    assert kh[0]["cut_priority"] >= 9


def test_truy_nguon_ve_tung_diem(du_an):
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C2", "ĐÃ TRẢ LỜI")
    assert kh[0]["sources"] == ["clarification:CL-1"]


def test_cat_theo_tran_va_NOI_RA_da_bo_bao_nhieu(du_an):
    """C2 không cắt được, nên tràn ở đây thành E5001 "không gọi mô hình". Cắt tại chỗ, lấy câu
    MỚI NHẤT trước — và một danh sách bị xén âm thầm đọc y hệt một danh sách đầy đủ."""
    _r, _ctx, root = du_an
    for i in range(40):
        _clar(root, f"CL-{i:02d}", f"{HOI} số {i} " + "x" * 120, f"{TRA} {i}",
              at=f"2026-09-22T10:{i:02d}:00+00:00")
    van, nguon, bo = _c2_tra_loi_cua_nguoi(root, 300)
    assert bo > 0 and f"còn {bo} câu" in van
    assert len(nguon) + bo == 40
    # Mới nhất trước: CL-39 phải có mặt, CL-00 thì không.
    assert "clarification:CL-39" in nguon and "clarification:CL-00" not in nguon


def test_khong_co_bang_thi_khong_no(tmp_path, workspace):
    """Store cũ (user_version < 8) chưa có bảng `clarification`."""
    (workspace / "x" / ".eide").mkdir(parents=True)
    assert _c2_tra_loi_cua_nguoi(workspace / "x", 300) == ("", [], 0)


# ---------- (2) định nghĩa TÍNH NĂNG đang lập kế hoạch


def test_tinh_nang_dang_lap_ke_hoach_vao_C5(du_an):
    """`plan.create` nói với mô hình đúng chuỗi "F-01". Tác tử lập kế hoạch cho một mã hiệu mà
    không được đọc mã hiệu ấy nghĩa là gì thì nó chỉ còn cách suy từ tên dự án."""
    _r, ctx, root = du_an
    _feature(root)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C5", "F-01")
    assert kh, [x["layer"] for x in compose({"role": "planner", "task_ref": "F-01"},
                                            ctx)["bundle"]["blocks"]]
    t = kh[0]["text"]
    assert "500ms" in t, "kỳ vọng ĐO ĐƯỢC là thứ PLAN-01 bắt buộc — thiếu nó thì mô hình tự nghĩ"
    assert "PB5 phải là ngõ ra" in t and "PORTB" in t


def test_tinh_nang_khac_thi_khong_lay_nham(du_an):
    _r, ctx, root = du_an
    _feature(root)
    assert _khoi(compose({"role": "planner", "task_ref": "F-99"}, ctx)["bundle"], "C5", "F-01") == []


def test_doc_duoc_CA_HAI_hinh_dang_cua_FEATURES_json(du_an):
    """`FEATURES.json` tồn tại ở HAI hình dạng trong kho: `{"features": [...]}` (thứ
    `project.create` và `memory.progress` ghi) và một DANH SÁCH TRẦN (thứ vài chỗ khác ghi).

    Bản đầu của tôi chỉ biết dạng thứ nhất, và `make check` bắt được bằng bốn bài `test_code.py`
    đỏ: `'list' object has no attribute 'get'`. Nên phép đo này giữ cả hai dạng — dùng lại
    `code.py::_doc_feature` thay vì viết bộ đọc thứ hai."""
    _r, _ctx, root = du_an
    ft = {"id": "F-01", "title": "Nháy LED",
          "expectation": {"kind": "measurement", "detail": "chu kỳ 500ms"}}
    for shape in ({"features": [ft]}, [ft]):
        (root / ".eide" / "FEATURES.json").write_text(
            json.dumps(shape, ensure_ascii=False), encoding="utf-8")
        van, nguon = _c5_tinh_nang(root, "F-01")
        assert "Nháy LED" in van and "chu kỳ 500ms" in van, shape
        assert nguon


def test_khong_co_FEATURES_json_thi_khong_no(du_an):
    _r, _ctx, root = du_an
    assert _c5_tinh_nang(root, "F-01") == ("", [])


def test_FEATURES_json_hong_thi_khong_no(du_an):
    """Tệp hỏng KHÔNG được làm hỏng cả lời gọi — ngữ cảnh thiếu một lớp còn chạy được, một
    ngoại lệ ở đây chặn mọi việc."""
    _r, _ctx, root = du_an
    (root / ".eide" / "FEATURES.json").write_text("{ hỏng", encoding="utf-8")
    assert _c5_tinh_nang(root, "F-01") == ("", [])


def test_vai_tro_intent_khong_doi(du_an):
    """`intent` dùng C2 cho việc KHÁC (§4.1: C1′ = tóm tắt trạng thái dự án) và ngân sách chỉ
    400 token. Không nhét câu trả lời vào đó."""
    _r, ctx, root = du_an
    _clar(root, "CL-1", HOI, TRA)
    assert _khoi(compose({"role": "intent", "task_ref": ""}, ctx)["bundle"],
                 "C2", "ĐÃ TRẢ LỜI") == []


def test_van_trong_ngan_sach(du_an):
    """Thêm hai khối mà vượt tổng thì `kiem_tran` ném E5001 và không lời gọi nào chạy được."""
    _r, ctx, root = du_an
    _feature(root)
    for i in range(6):
        _clar(root, f"CL-{i}", f"{HOI} {i}", f"{TRA} {i}", at=f"2026-09-22T10:0{i}:00+00:00")
    b = compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"]
    assert b["total_tokens"] <= b["budget"]["total"]


# ---------- (3) [DEV-175] C4 — fact phần cứng, Graph-RAG hai bước (CXD-10 §4.5)


def _fact(root, fid, subject, vi_tu="offset", gt=1, tier="gold", status="normalized",
          src="src_a", unit=None):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?, 'file:///x', ?, 'atdf', 'gold', 'vendor-doc')",
                  (src, src + "hash"))
        c.execute("INSERT INTO fact (id,subject,predicate,value,unit,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?, 'parser', ?, 1.0, ?, 'A')",
                  (fid, subject, vi_tu, json.dumps(gt), unit, src, tier, status))
        c.commit()


CHIP = "chip:microchip.atmega328p"
PORTB = f"{CHIP}/periph:PORT/reg:PORTB"
DDRB = f"{CHIP}/periph:PORT/reg:DDRB"
ADC = f"{CHIP}/periph:ADC/reg:ADCSRA"


def test_C4_co_mat_va_mang_dung_thanh_ghi_tac_vu_cham(du_an):
    """Phép đo trung tâm của [DEV-175]: trước bản vá, C4 được cấp 2500 token và dùng 0 — tác tử
    lập kế hoạch cho con chip mà không đọc một dòng nào của hộ chiếu nó vừa trích ra."""
    _r, ctx, root = du_an
    _feature(root)                                  # touches: PB5, PORTB, DDRB
    _fact(root, "f_portb", PORTB, gt=37)
    _fact(root, "f_adc", ADC, gt=122)
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C4")
    assert kh, "C4 vẫn rỗng"
    assert "f_portb" in kh[0]["text"]
    assert kh[0]["sources"] == ["fact:f_portb"], "ADC không dính tới việc bật một chân"


def test_hai_buoc_DI_DUOC_hai_buoc(du_an):
    """Mã giả CXD-10 §4.5 viết `frontier = nxt - set(scored) | frontier`, mà `scored` vừa cập
    nhật ngay trong vòng lặp nên phép trừ luôn rỗng: biên đứng yên ở hạt giống và "hai bước"
    đi được đúng MỘT bước. Đây là phép đo giữ bản sửa."""
    from eide.caps.kg import _do_thi_tu_store
    from eide.caps.memory import _cham_diem
    _r, _ctx, root = du_an
    _fact(root, "f_portb", PORTB, gt=37)
    _fact(root, "f_portc", f"{CHIP}/periph:PORT/reg:PORTC", gt=40)
    g = _do_thi_tu_store(root)
    mot = _cham_diem(g, [PORTB], sau=1)
    hai = _cham_diem(g, [PORTB], sau=2)
    assert len(hai) > len(mot), (len(mot), len(hai))
    # PORTC là anh em của PORTB qua `periph:PORT` — đúng hai bước.
    assert f"{CHIP}/periph:PORT/reg:PORTC" in hai


def test_chip_chi_la_DUONG_LUI(du_an):
    """`if not seeds:` của §4.5. Cho nút chip vào hạt giống LUÔN LUÔN thì hai bước chạm tới mọi
    thanh ghi, và C4 đầy 2500 token bằng ACSR/FUSE/WDTCSR — đo được trên bài nhấp nháy LED."""
    from eide.caps.kg import _do_thi_tu_store
    from eide.caps.memory import _doc_feature_an_toan, _nut_hat_giong
    _r, _ctx, root = du_an
    _fact(root, "f_portb", PORTB, gt=37)
    _fact(root, "f_adc", ADC, gt=122)
    g = _do_thi_tu_store(root)

    _feature(root)                                    # CÓ touches
    assert _nut_hat_giong(g, root, _doc_feature_an_toan(root, "F-01")) == [PORTB, DDRB] or \
           set(_nut_hat_giong(g, root, _doc_feature_an_toan(root, "F-01"))) == {PORTB}
    _feature(root, touches=[])                        # KHÔNG touches → lùi về chip
    hat = _nut_hat_giong(g, root, _doc_feature_an_toan(root, "F-01"))
    assert hat == [] or hat == [CHIP], hat


def test_khop_theo_DOAN_IRI_khong_theo_chuoi_con(du_an):
    """`PB5` là chuỗi con của `PB50`, mà hai chân ấy không liên quan gì nhau."""
    from eide.caps.kg import _do_thi_tu_store
    from eide.caps.memory import _nut_hat_giong
    _r, _ctx, root = du_an
    _fact(root, "f_a", f"{CHIP}/periph:PORT/reg:PORTB/field:PB50", gt=1)
    g = _do_thi_tu_store(root)
    hat = _nut_hat_giong(g, root, {"touches": ["PB5"]})
    assert all("PB50" not in h for h in hat), hat


def test_fact_mau_thuan_LUON_co_mat_va_co_nhan(du_an):
    """§4.5: "Fact mâu thuẫn luôn có mặt kèm nhãn CONFLICT để mô hình không tự chọn (phải nói
    'không xác định')". Cắt bớt một vế vì hết ngân sách là để nó tự chọn — và nó sẽ chọn, im
    lặng, không nói rằng có hai."""
    _r, ctx, root = du_an
    _feature(root)
    for i in range(30):
        _fact(root, f"f_pad{i}", PORTB, vi_tu="description", gt="x" * 60)
    _fact(root, "f_xung_dot", DDRB, gt=99, status="conflict")
    kh = _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C4")
    t = kh[0]["text"]
    assert "f_xung_dot" in t and "⚠CONFLICT" in t
    # Đứng trên mọi fact thường.
    assert t.index("f_xung_dot") < t.index("f_pad0")


def test_cat_theo_ngan_sach_va_NOI_RA(du_an):
    """Một bảng bị xén âm thầm đọc y hệt một bảng đầy đủ."""
    from eide.caps.memory import _c4_fact_phan_cung
    _r, _ctx, root = du_an
    _feature(root)
    for i in range(60):
        _fact(root, f"f_{i:03d}", PORTB, gt=i)
    van, nguon, bo = _c4_fact_phan_cung(root, "F-01", 200)
    assert bo > 0 and f"còn {bo} fact nữa" in van
    assert len(nguon) + bo == 60


def test_fact_da_bi_thay_KHONG_vao_ngu_canh(du_an):
    """Đưa bản đã bị thay vào là đưa đúng con số vừa bị bác bỏ."""
    from eide.caps.memory import _c4_fact_phan_cung
    _r, _ctx, root = du_an
    _feature(root)
    _fact(root, "f_cu", PORTB, gt=1, status="superseded")
    _fact(root, "f_moi", PORTB, gt=37)
    van, nguon, _bo = _c4_fact_phan_cung(root, "F-01", 2500)
    assert "f_moi" in van and "f_cu" not in van and nguon == ["fact:f_moi"]


def test_vi_tu_quan_trong_len_truoc(du_an):
    """PRED_W của §4.5: `offset` = 1,0 còn `description` = 0,3 ("chỉ khi còn ngân sách")."""
    from eide.caps.memory import _c4_fact_phan_cung
    _r, _ctx, root = du_an
    _feature(root)
    _fact(root, "f_mota", PORTB, vi_tu="description", gt="cổng B")
    _fact(root, "f_offset", PORTB, vi_tu="offset", gt=37)
    van, _n, _b = _c4_fact_phan_cung(root, "F-01", 2500)
    assert van.index("f_offset") < van.index("f_mota")


def test_vai_tro_khong_co_ngan_sach_C4_thi_khong_co_lop(du_an):
    """`intent` khai `C4: null` trong CXD-10 §3."""
    _r, ctx, root = du_an
    _feature(root)
    _fact(root, "f_portb", PORTB, gt=37)
    assert _khoi(compose({"role": "intent", "task_ref": "F-01"}, ctx)["bundle"], "C4") == []


def test_khong_co_fact_nao_thi_khong_them_lop_rong(du_an):
    _r, ctx, root = du_an
    _feature(root)
    assert _khoi(compose({"role": "planner", "task_ref": "F-01"}, ctx)["bundle"], "C4") == []


# ---------- (4) [DEV-177] Đa dòng chip: ARM/RISC-V không giống AVR


I2C1 = "chip:st.stm32f411ce/periph:I2C1"
SPI1 = "chip:st.stm32f411ce/periph:SPI1"


def test_ten_thanh_ghi_TRUNG_NHAU_giua_cac_ngoai_vi(du_an):
    """Trên AVR tên thanh ghi là DUY NHẤT TOÀN CỤC (`PORTB` chỉ có một), nên khớp một từ là đủ.
    Trên ARM thì KHÔNG: `CR1` có trong I2C1, SPI1, ADC, TIM… — hàng chục ngoại vi.

    Đo với `touches: ["I2C1","CR1"]`: phép khớp một-từ gieo cả `SPI1/reg:CR1`, và trên SVD thật
    của STM32F411 (~50 ngoại vi) một chữ `CR1` sẽ gieo ~40 nút — hai bước từ đó làm ngập C4,
    đúng kiểu pha loãng đã phải sửa cho nút chip.
    """
    from eide.caps.kg import _do_thi_tu_store
    from eide.caps.memory import _nut_hat_giong
    _r, _ctx, root = du_an
    _fact(root, "f_i2c", I2C1, vi_tu="base_address", gt=0x40005400)
    _fact(root, "f_i2c_cr1", f"{I2C1}/reg:CR1", gt=0)
    _fact(root, "f_spi_cr1", f"{SPI1}/reg:CR1", gt=0)
    g = _do_thi_tu_store(root)
    hat = _nut_hat_giong(g, root, {"touches": ["I2C1", "CR1"]})
    assert all("SPI1" not in h for h in hat), hat
    assert any(h.endswith("periph:I2C1/reg:CR1") for h in hat), hat


def test_AVR_khop_MOT_tu_van_giu_nguyen(du_an):
    """Khi MỌI nút chỉ khớp một từ — đúng trường hợp AVR — hạng cao nhất là 1 và tập giữ nguyên.
    Phép xếp hạng không được làm hẹp cái vốn đã đúng."""
    from eide.caps.kg import _do_thi_tu_store
    from eide.caps.memory import _nut_hat_giong
    _r, _ctx, root = du_an
    _fact(root, "f_portb", PORTB, gt=37)
    _fact(root, "f_ddrb", DDRB, gt=36)
    g = _do_thi_tu_store(root)
    hat = _nut_hat_giong(g, root, {"touches": ["PORTB", "DDRB", "PB5"]})
    assert {h.rsplit(":", 1)[-1] for h in hat} == {"PORTB", "DDRB"}


def test_IRI_SAU_bon_tang_cua_SVD(du_an):
    """AVR có IRI ba tầng (`chip/periph/reg`); SVD của ARM có BỐN (`…/field:PE`). Thuật toán hai
    bước phải với tới thanh ghi ở cả hai hình dạng cây."""
    from eide.caps.memory import _c4_fact_phan_cung
    _r, _ctx, root = du_an
    _fact(root, "f_cr1", f"{I2C1}/reg:CR1", gt=0)
    _fact(root, "f_pe", f"{I2C1}/reg:CR1/field:PE", vi_tu="bit_range", gt="0:0")
    _fact(root, "f_cr2", f"{I2C1}/reg:CR2", gt=4)
    _feature(root, touches=["I2C1", "CR1"])
    van, nguon, _b = _c4_fact_phan_cung(root, "F-01", 2500)
    assert len(nguon) == 3, van
    assert "field:PE" in van and "reg:CR2" in van


def test_quy_chuan_ten_chip_cho_moi_hang(du_an):
    """`project.set_target` và C4 phải nói cùng một thứ tiếng về cùng con chip, bất kể hãng:
    `st.`, `sifive.`, `microchip.` — tiền tố do `extract.*` sinh theo KAD-07 §4."""
    from eide.caps.sim import iri_chip_trong_store
    _r, _ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        for pid in ("st.stm32f411ce@1.2.0", "sifive.fe310@1.0.0"):
            c.execute("INSERT INTO passport (id,kind,header,created_at)"
                      " VALUES (?,'chip',?, '2026-09-22T00:00:00+00:00')",
                      (pid, json.dumps({"name": pid})))
        c.commit()
    assert iri_chip_trong_store(root, "stm32f411ce") == "chip:st.stm32f411ce"
    assert iri_chip_trong_store(root, "fe310") == "chip:sifive.fe310"
