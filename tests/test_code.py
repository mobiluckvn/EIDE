"""Nhóm code.* — CDS-12.1; PRS-16 §3/§4; STP-05 TC-04, TC-06.

TC-04 (chuẩn nghiệm thu, nguyên văn): *"10 patch mẫu có hằng số không chú thích / chú thích fact
không tồn tại / fact bạc chưa duyệt → chặn 100%; fact vàng → qua"*.
TC-06: *"Fact status=normalized → passport.query trả nhưng đánh dấu unreviewed; ConstantGuard
từ chối"*.
"""
from __future__ import annotations

import hashlib

import pytest

from eide.caps.code import constant_guard
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án mã"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


def _fact(root, fid: str, value: str, *, status: str, tier: str) -> None:
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s1", "u", hashlib.sha256(b"s1").hexdigest(), "svd", tier, "vendor-doc"))
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, "chip:x", "reg.addr", value, "s1", "parser", tier, 1.0, status, "A"))
        c.commit()


def _patch(noi_dung: str, duong: str = "src/drv.c") -> dict:
    return {"patch": {"files": [{"path": duong, "content": noi_dung}]}}


# ---------- TC-04: bốn nhánh chặn, một nhánh qua

def test_hang_so_khong_chu_thich_bi_chan(du_an):
    _, ctx, _ = du_an
    kq = constant_guard(_patch("#define BME280_ADDR 0x76\n"), ctx)
    assert kq["verdict"] == "block"
    assert [v["reason"] for v in kq["violations"]] == ["no_fact"]
    assert kq["violations"][0]["line"] == 1 and kq["violations"][0]["literal"] == "0x76"


def test_chu_thich_tro_fact_khong_ton_tai_bi_chan(du_an):
    _, ctx, _ = du_an
    kq = constant_guard(_patch("#define A 0x76 /* eide:fact f_00000000000000ff */\n"), ctx)
    assert [v["reason"] for v in kq["violations"]] == ["fact_not_found"]


def test_fact_bac_CHUA_DUYET_bi_chan(du_an):
    """TC-06 nguyên văn: "Fact status=normalized → … ConstantGuard từ chối"."""
    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="normalized", tier="silver")
    kq = constant_guard(_patch("#define A 0x76 /* eide:fact f_00000000000000ab */\n"), ctx)
    assert kq["verdict"] == "block"
    assert [v["reason"] for v in kq["violations"]] == ["fact_not_reviewed"]


def test_fact_bac_DA_DUYET_thi_qua(du_an):
    """Đối chứng của test trên: chặn là vì CHƯA DUYỆT, không phải vì tầng bạc."""
    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="reviewed", tier="silver")
    assert constant_guard(_patch("#define A 0x76 /* eide:fact f_00000000000000ab */\n"),
                          ctx)["verdict"] == "pass"


def test_fact_vang_chua_duyet_van_qua(du_an):
    """TC-04: "fact vàng → qua". CODE-04 bước 1 cho hai lối: status đã duyệt HOẶC tầng gold —
    tài liệu chính hãng đã phân tích cú pháp thì không cần người bấm duyệt lại."""
    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="normalized", tier="gold")
    assert constant_guard(_patch("#define A 0x76 /* eide:fact f_00000000000000ab */\n"),
                          ctx)["verdict"] == "pass"


def test_gia_tri_lech_bi_chan_du_fact_da_duyet(du_an):
    """CODE-04 bước 1 đòi "giá trị khớp". Một chú thích trỏ đúng fact nhưng mã ghi sai số là ca
    NGUY HIỂM NHẤT: nó vượt mọi phép kiểm nhìn-bằng-mắt vì trông hoàn toàn có nguồn."""
    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="verified", tier="gold")
    kq = constant_guard(_patch("#define A 0x77 /* eide:fact f_00000000000000ab */\n"), ctx)
    assert [v["reason"] for v in kq["violations"]] == ["value_mismatch"]
    assert "need" not in kq["violations"][0], \
        "lệch giá trị là lỗi của mã, không phải chỗ thiếu tri thức — đi tìm tài liệu là sai đường"


def test_ky_phap_khac_nhau_van_la_cung_gia_tri(du_an):
    """`0x76`, `118`, `0b1110110` là một. Bắt mã viết đúng ký pháp của fact là bắt sai chỗ."""
    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="verified", tier="gold")
    for lit in ("0x76", "0b1110110", "0X76"):
        assert constant_guard(_patch(f"#define A {lit} /* eide:fact f_00000000000000ab */\n"),
                              ctx)["verdict"] == "pass", lit


# ---------- không được chặn nhầm

def test_chu_thich_nhieu_dong_khong_thanh_vi_pham(du_an):
    """Khối giấy phép đầu tệp chứa số hex là chuyện thường. Guard kêu ở đó thì người ta tắt nó."""
    _, ctx, _ = du_an
    src = ("/* Driver BME280\n"
           " * Bản quyền 0xDEADBEEF, mã lỗi 0x1234\n"
           " * Tần số tham chiếu 400000\n"
           " */\n"
           "int f(void) { return 0; }\n")
    assert constant_guard(_patch(src), ctx) == {"verdict": "pass", "violations": []}


def test_so_trong_chuoi_khong_thanh_vi_pham(du_an):
    _, ctx, _ = du_an
    assert constant_guard(_patch('const char *S = "addr=0x76, baud=115200";\n'),
                          ctx)["verdict"] == "pass"


def test_can_vong_lap_khong_phai_hang_so_phan_cung(du_an):
    """`for (int i = 0; i < 1000; i++)` — không chữ hoa, không `->`, không từ khóa tần số. Đây là
    ranh giới "ngữ cảnh phần cứng" của CODE-04 bước 1, và cũng là ranh giới giữa một guard dùng
    được với một guard bị tắt."""
    _, ctx, _ = du_an
    assert constant_guard(_patch("void f(void){ for (int i = 0; i < 1000; i++) {} }\n"),
                          ctx)["verdict"] == "pass"


def test_tan_so_gan_cho_bien_thuong_van_bi_bat(du_an):
    """Đối chứng: cùng con số ấy nhưng trong ngữ cảnh phần cứng thì phải bắt. Ba dấu hiệu, mỗi
    cái một dòng — bỏ dấu hiệu nào thì dòng ấy lọt."""
    _, ctx, _ = du_an
    for src in ("#define I2C_SPEED 400000\n",
                "  h->Init.ClockSpeed = 400000;\n",
                "  uint32_t baud = 115200;\n",
                "  RCC_CFGR = 16000000;\n"):
        kq = constant_guard(_patch(src), ctx)
        assert kq["verdict"] == "block", src


def test_tep_khong_phai_ma_C_bi_bo_qua(du_an):
    """CODE-04 nói "ngữ cảnh phần cứng". Một `README.md` hay `CMakeLists.txt` có số hex thì
    không phải hằng số phần cứng của firmware."""
    _, ctx, _ = du_an
    assert constant_guard(_patch("phiên bản 0xDEADBEEF\n", "docs/README.md"),
                          ctx)["verdict"] == "pass"


def test_chu_thich_o_dong_ngay_tren_van_tinh(du_an):
    """`#define` dài thường để chú thích ở dòng trên. Chỉ chấp nhận cùng dòng thì mô hình bị
    phạt vì một quy ước trình bày."""
    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="verified", tier="gold")
    src = "/* eide:fact f_00000000000000ab */\n#define BME280_ADDR 0x76\n"
    assert constant_guard(_patch(src), ctx)["verdict"] == "pass"


def test_nhieu_hang_so_mot_dong_moi_cai_deu_phai_khop(du_an):
    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="verified", tier="gold")
    _fact(root, "f_00000000000000cd", "0x77", status="verified", tier="gold")
    ok = "  W(0x76, 0x77); /* eide:fact f_00000000000000ab eide:fact f_00000000000000cd */\n"
    assert constant_guard(_patch(ok), ctx)["verdict"] == "pass"
    # bỏ một fact đi: hằng số còn lại không còn ai bảo chứng
    thieu = "  W(0x76, 0x78); /* eide:fact f_00000000000000ab eide:fact f_00000000000000cd */\n"
    kq = constant_guard(_patch(thieu), ctx)
    assert kq["verdict"] == "block" and kq["violations"][0]["literal"] == "0x78"


# ---------- hợp đồng

def test_R0_khong_ghi_gi_vao_store(du_an):
    """CODE-04 là lớp R0, mà APD-08 định nghĩa R0 là CHỈ ĐỌC — `PolicyGate` dựa hẳn vào đó để cho
    R0 đi thẳng không qua quy tắc cổng. Bước 2 của hợp đồng nói guard tự tạo `kg.request`; làm
    thế là biến lối tắt ấy thành lỗ hổng. Xem DEV-062."""
    _, ctx, root = du_an
    db = store.store_path(root)
    with store.open_store(db) as c:
        truoc = c.execute("SELECT COUNT(*) FROM acq_request").fetchone()[0]
    kq = constant_guard(_patch("#define A 0x76\n"), ctx)
    with store.open_store(db) as c:
        assert c.execute("SELECT COUNT(*) FROM acq_request").fetchone()[0] == truoc
    assert kq["violations"][0]["need"], "phải nêu `need` để bên gọi (R2) tạo yêu cầu"


def test_qua_router_khong_bi_cong_hoi(du_an):
    """R0/T1 sau cổng `*` phải chạy thẳng — đây là năng lực được gọi trong mọi vòng sinh mã."""
    r, ctx, _ = du_an
    run = r.invoke("code.constant_guard", {"patch": {"files": []}}, ctx)
    assert run.status == "done" and run.result == {"verdict": "pass", "violations": []}
