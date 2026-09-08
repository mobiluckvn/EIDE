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


# ---------- CODE-05 build: lệnh đến từ manifest, lỗi được phân loại

def test_tach_lenh_tu_manifest_khong_dung_shell():
    """PLATFORM.md quy tắc 3 cấm gọi lệnh dạng chuỗi, `Sandbox.run` chỉ nhận danh sách. Manifest
    thì viết lệnh dựng thành chuỗi shell vì đó là dạng người đọc — tách ở một chỗ."""
    from eide.caps.code import manifest_isa, tach_lenh

    cmd = manifest_isa("armv7e-m")["toolchain"]["build"]["cmd"]
    assert tach_lenh(cmd) == [["cmake", "-S", ".", "-B", "build", "-G", "Ninja",
                               "-DCMAKE_TOOLCHAIN_FILE=cmake/arm.cmake"],
                              ["cmake", "--build", "build"]]


def test_lenh_can_shell_bi_tu_choi():
    """Một lệnh dựng cần ống dẫn là một lệnh cần shell, mà chạy shell trong sandbox là mở lại
    đúng cánh cửa vừa đóng."""
    from eide.caps.code import tach_lenh

    for xau in ("make | tee log", "make > out.txt", "make; echo xong", "make $(pwd)"):
        with pytest.raises(Exception, match="shell"):
            tach_lenh(xau)


@pytest.mark.parametrize(("log", "loai"), [
    ("src/i2c.c:12:5: error: expected ';' before '}' token", "compile"),
    ("/usr/bin/ld: undefined reference to `i2c_init'", "link"),
    ("/usr/bin/ld: region `FLASH' overflowed by 1234 bytes", "size"),
    ("ninja: build stopped: subcommand failed.", "unknown"),
])
def test_phan_loai_loi_dung_ba_loai_cua_hop_dong(log, loai):
    """Bước 1 của CODE-05: "phân loại lỗi (compile/link/size)". Ba loại dẫn tới ba hành động khác
    nhau — sửa mã, sửa liên kết, cắt bớt — nên gộp là vứt đi thứ `code.self_repair` cần."""
    from eide.caps.code import phan_loai_loi

    assert phan_loai_loi(log)["kind"] == loai


def test_tran_flash_khong_bi_doc_nham_thanh_loi_lien_ket():
    """Một bản dựng tràn Flash CŨNG in dòng của `ld`. Xét `link` trước thì mọi lỗi tràn bộ nhớ
    bị dán nhãn "lỗi liên kết", và tác tử sẽ đi sửa khai báo hàm thay vì đi cắt mã."""
    from eide.caps.code import phan_loai_loi

    log = ("/usr/bin/ld: /tmp/fw.elf section `.text' will not fit in region `FLASH'\n"
           "/usr/bin/ld: region `FLASH' overflowed by 2048 bytes\n"
           "collect2: error: ld returned 1 exit status\n")
    assert phan_loai_loi(log)["kind"] == "size"


def test_build_thieu_cong_cu_tra_E4001_kem_danh_sach(du_an, monkeypatch):
    """Để `cmake` tự báo "command not found" thì người dùng nhận một dòng lỗi shell thay vì câu
    "cài arm-none-eabi-gcc rồi chạy lại", và self_repair sẽ tưởng mã sai mà đi sửa mã."""
    from eide.caps.code import build
    from eide_core.errors import EideError

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    with pytest.raises(EideError) as e:
        build({}, ctx)
    assert e.value.code == "E4001" and "arm-none-eabi-gcc" in e.value.data["missing"]


def test_build_chua_ghim_ISA_thi_noi_ro(du_an):
    """Mọi lệnh dựng nằm trong manifest của một ISA cụ thể — không ghim thì không có gì để chạy."""
    from eide.caps.code import build
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        build({}, ctx)
    assert e.value.code == "E2000" and "isa" in e.value.data.get("missing", [])


# ---------- CODE-06 size

def _shim(d, ten, than):
    import stat as _stat
    d.mkdir(parents=True, exist_ok=True)
    f = d / ten
    f.write_text(f"#!/bin/sh\n{than}\n", encoding="utf-8")
    f.chmod(f.stat().st_mode | _stat.S_IEXEC | _stat.S_IXGRP | _stat.S_IXOTH)
    return f


def _flash_ram(root, chip: str, flash_b: int, ram_b: int) -> None:
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s2", "u2", hashlib.sha256(b"s2").hexdigest(), "svd", "gold", "vendor-doc"))
        for i, (ten, so) in enumerate((("flash", flash_b), ("ram", ram_b))):
            c.execute("INSERT INTO fact (id, subject, predicate, value, unit, source_id, method,"
                      " tier, confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                      (f"f_ffffffffffffff0{i}", f"chip:{chip}/{ten}", "memory_size", str(so),
                       "B", "s2", "parser", "gold", 1.0, "verified", "A"))
        c.commit()


@pytest.fixture
def du_an_size(du_an, tmp_path, monkeypatch):
    """Dự án đã ghim ISA, có `size` giả in ra một dòng Berkeley cố định."""
    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    bin_gia = tmp_path / "bin"
    monkeypatch.setenv("PATH", f"{bin_gia}{__import__('os').pathsep}{__import__('os').environ['PATH']}")
    (root / "build").mkdir(exist_ok=True)
    (root / "build" / "fw.elf").write_bytes(b"\x7fELF")
    return r, ctx, root, bin_gia


def test_size_trong_ngan_sach_thi_passed(du_an_size):
    from eide.caps.code import size

    r, ctx, root, bin_gia = du_an_size
    _shim(bin_gia, "arm-none-eabi-size",
          "echo '   text\tdata\t bss\t dec\t hex\tfilename'; echo '  10000\t 100\t2000\t12100\t2f44\tfw.elf'")
    _flash_ram(root, "STM32F411RE", 512 * 1024, 128 * 1024)
    rep = size({"artifact": "build/fw.elf"}, ctx)["report"]
    assert rep["passed"] is True
    assert rep["metrics"]["flash"] == 10100 and rep["metrics"]["ram"] == 2100
    assert rep["metrics"]["reason"] is None


def test_size_vuot_ngan_sach_thi_passed_false_KHONG_nem_loi(du_an_size):
    """tc của CODE-06: "Vượt ngân sách → passed=false". Ném lỗi thì thứ duy nhất
    `code.self_repair` nhận được là "thất bại" — nó cần con số để biết phải cắt bao nhiêu."""
    from eide.caps.code import size

    r, ctx, root, bin_gia = du_an_size
    _shim(bin_gia, "arm-none-eabi-size",
          "echo 'text data bss dec hex filename'; echo '  12000\t 288\t2000\t14288\t37d0\tfw.elf'")
    _flash_ram(root, "STM32F411RE", 13000, 128 * 1024)     # 12288/13000 = 94,5% > 85%
    rep = size({"artifact": "build/fw.elf"}, ctx)["report"]
    assert rep["passed"] is False
    assert "vượt ngưỡng" in rep["metrics"]["reason"]
    assert rep["metrics"]["flash_pct"] == pytest.approx(94.52, abs=0.05)


def test_data_tinh_vao_ca_flash_lan_ram(du_an_size):
    """`.data` nằm trong ảnh nạp rồi được chép sang RAM lúc khởi động — nó chiếm chỗ ở CẢ HAI.
    Bỏ nó khỏi Flash là báo thiếu đúng phần hay tràn nhất ở một firmware nhiều bảng tra."""
    from eide.caps.code import size

    r, ctx, root, bin_gia = du_an_size
    _shim(bin_gia, "arm-none-eabi-size",
          "echo 'text data bss dec hex f'; echo ' 1000\t5000\t 100\t6100\t17d4\tfw.elf'")
    _flash_ram(root, "STM32F411RE", 512 * 1024, 128 * 1024)
    m = size({"artifact": "build/fw.elf"}, ctx)["report"]["metrics"]
    assert m["flash"] == 6000 and m["ram"] == 5100


def test_chua_biet_dung_luong_chip_thi_KHONG_ket_luan_dat(du_an_size):
    """Một `passed=true` vì thiếu số liệu đọc y hệt một `passed=true` vì vừa vặn."""
    from eide.caps.code import size

    r, ctx, root, bin_gia = du_an_size
    _shim(bin_gia, "arm-none-eabi-size",
          "echo 'text data bss dec hex f'; echo ' 100\t0\t0\t100\t64\tfw.elf'")
    rep = size({"artifact": "build/fw.elf"}, ctx)["report"]        # không nạp fact memory_size
    assert rep["passed"] is False and "chưa biết dung lượng" in rep["metrics"]["reason"]


def test_top_symbols_doc_tu_tep_map(du_an_size):
    from eide.caps.code import size

    r, ctx, root, bin_gia = du_an_size
    _shim(bin_gia, "arm-none-eabi-size",
          "echo 'text data bss dec hex f'; echo ' 100\t0\t0\t100\t64\tfw.elf'")
    _flash_ram(root, "STM32F411RE", 512 * 1024, 128 * 1024)
    (root / "build" / "fw.map").write_text(
        " .text.bang_tra   0x08000200  0x400  CMakeFiles/fw.dir/src/tra.c.obj\n"
        " .text.i2c_init   0x08000180  0x9c   CMakeFiles/fw.dir/src/i2c.c.obj\n"
        " .text.rong       0x08000100  0x0    CMakeFiles/fw.dir/src/rong.c.obj\n", encoding="utf-8")
    ks = size({"artifact": "build/fw.elf"}, ctx)["report"]["metrics"]["top_symbols"]
    assert [k["symbol"] for k in ks] == [".text.bang_tra", ".text.i2c_init"], \
        "phải sắp giảm dần theo kích thước và bỏ ký hiệu rỗng"
    assert ks[0]["bytes"] == 0x400


def test_size_khong_co_artifact_tra_E4000(du_an_size):
    from eide.caps.code import size
    from eide_core.errors import EideError

    r, ctx, root, _ = du_an_size
    with pytest.raises(EideError) as e:
        size({"artifact": "build/khong-co.elf"}, ctx)
    assert e.value.code == "E4000"


# ---------- CODE-07 static: ba quy tắc Pack

QUY_TAC = ["no_delay_in_isr", "no_malloc", "no_float_isr_without_fpu"]


def _pack(src: str, rules=None, co_fpu=None, duong="src/a.c"):
    from pathlib import Path as _P

    from eide.caps.code import _quet_pack
    return _quet_pack(_P(duong), src, QUY_TAC if rules is None else rules, co_fpu)


def test_delay_trong_ISR_bi_bat_delay_ngoai_ISR_thi_khong():
    """tc CODE-07: "Lỗi cố ý bị bắt". Ca phân biệt nằm ở chỗ CÙNG một lời gọi: `HAL_Delay` trong
    ISR là lỗi chặn, còn trong `main` là chuyện bình thường. Quy tắc không phân biệt được thân
    hàm thì hoặc bắt cả hai (vô dụng) hoặc bỏ cả hai."""
    src = ("void TIM2_IRQHandler(void) {\n    HAL_Delay(10);\n}\n"
           "void app_main(void) {\n    HAL_Delay(100);\n}\n")
    ds = [f for f in _pack(src) if f["rule"] == "no_delay_in_isr"]
    assert [f["line"] for f in ds] == [2]
    assert ds[0]["severity"] == "blocker" and "TIM2_IRQHandler" in ds[0]["message"]


def test_dem_ngoac_khong_bi_dau_ngoac_trong_chuoi_cat_som():
    """`printf("}")` giữa ISR: đếm ngoặc thô sẽ tưởng thân hàm kết thúc ở đó, và nửa sau của ISR
    không được quét — đúng nửa mà lập trình viên hay để lời gọi chặn."""
    src = ('void TIM2_IRQHandler(void) {\n'
           '    printf("}");\n'
           '    /* } trong chú thích nữa */\n'
           '    HAL_Delay(1);\n'
           '}\n')
    assert [f["line"] for f in _pack(src) if f["rule"] == "no_delay_in_isr"] == [4]


@pytest.mark.parametrize("ten", ["TIM2_IRQHandler", "SysTick_Handler", "adc_isr", "uart_ISR"])
def test_cac_quy_uoc_dat_ten_ISR_deu_nhan_ra(ten):
    src = f"void {ten}(void) {{\n    HAL_Delay(1);\n}}\n"
    assert [f["rule"] for f in _pack(src)] == ["no_delay_in_isr"], ten


def test_thuoc_tinh_interrupt_cung_la_ISR():
    """AVR và vài trình dịch không dùng hậu tố tên mà dùng thuộc tính."""
    src = "__attribute__((interrupt)) void xu_ly(void) {\n    HAL_Delay(1);\n}\n"
    assert [f["rule"] for f in _pack(src)] == ["no_delay_in_isr"]


def test_malloc_bi_bat_o_moi_noi_khong_rieng_ISR():
    """`no_malloc` là quy tắc CẢ DỰ ÁN, không phải quy tắc ISR: phân mảnh heap không quan tâm
    chỗ gọi. Manifest xếp nó ngang hàng với hai quy tắc kia chứ không lồng vào."""
    src = "void app_main(void) {\n    char *p = malloc(16);\n    free(p);\n}\n"
    assert {f["rule"] for f in _pack(src)} == {"no_malloc"}
    assert len([f for f in _pack(src) if f["rule"] == "no_malloc"]) == 2


def test_so_thuc_trong_ISR_muc_do_theo_viec_CO_BIET_fpu_hay_khong():
    """`None` (chưa biết) khác `False` (chắc chắn không có FPU) ở MỨC ĐỘ, không ở việc có báo
    hay không. Gộp hai thứ lại thì hoặc dự án chưa ghim hộ chiếu bị báo lỗi nặng oan, hoặc chip
    thật sự không FPU được cho qua."""
    src = "void TIM2_IRQHandler(void) {\n    float x = 1.5f;\n}\n"
    assert [f["severity"] for f in _pack(src, co_fpu=None)
            if f["rule"] == "no_float_isr_without_fpu"] == ["minor"]
    assert [f["severity"] for f in _pack(src, co_fpu=False)
            if f["rule"] == "no_float_isr_without_fpu"] == ["major"]
    assert [f for f in _pack(src, co_fpu=True) if f["rule"] == "no_float_isr_without_fpu"] == []


def test_quy_tac_khong_co_trong_manifest_thi_khong_chay():
    """Bật một quy tắc mà Pack của ISA này không khai là áp luật của ISA khác lên nó."""
    src = "void app_main(void) {\n    char *p = malloc(16);\n}\n"
    assert _pack(src, rules=["no_delay_in_isr"]) == []


def test_doc_cppcheck_tu_stderr_khong_tu_stdout(tmp_path):
    """cppcheck in ra **stderr**. Đọc nhầm luồng thì mọi dự án đều "sạch" — một phép kiểm luôn
    xanh là một phép kiểm không tồn tại."""
    from eide.caps.code import _doc_cppcheck

    err = tmp_path / "e.txt"
    err.write_text("src/i2c.c:42:5: error: Null pointer dereference: p [nullPointer]\n"
                   "src/i2c.c:50:1: style: Unused variable: x [unusedVariable]\n", encoding="utf-8")
    ds = _doc_cppcheck(err, tmp_path / "khong-co.txt")
    assert [(f["line"], f["rule"], f["severity"]) for f in ds] == [
        (42, "nullPointer", "major"), (50, "unusedVariable", "minor")]


def test_static_thieu_cppcheck_van_giu_phat_hien_cua_Pack(du_an, monkeypatch):
    """Ném lỗi trắng thì các phát hiện của quy tắc Pack — vốn chạy được mà không cần công cụ nào
    — bị vứt đi cùng, và người dùng mất thông tin chỉ vì máy thiếu một gói."""
    from eide.caps.code import static
    from eide_core.errors import EideError

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "irq.c").write_text("void TIM2_IRQHandler(void) {\n  HAL_Delay(1);\n}\n",
                                        encoding="utf-8")
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    with pytest.raises(EideError) as e:
        static({}, ctx)
    assert e.value.code == "E4001"
    assert [f["rule"] for f in e.value.data["partial_findings"]] == ["no_delay_in_isr"]


# ---------- CODE-08 test_host

def test_khong_co_tep_test_thi_KHONG_bao_dat(du_an):
    """Một dự án chưa viết test và một dự án có test đều xanh phải đọc khác nhau."""
    from eide.caps.code import test_host

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    rep = test_host({}, ctx)["report"]
    assert rep["passed"] is False and rep["metrics"]["total"] == 0
    assert "không có tệp nào khớp" in rep["metrics"]["reason"]


@pytest.fixture
def du_an_test_host(du_an):
    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    (root / "tests" / "host").mkdir(parents=True)
    (root / "tests" / "mock").mkdir(parents=True)
    (root / "tests" / "mock" / "hal_mock.c").write_text(
        "int hal_doc_nhiet_do(void) { return 25; }\n", encoding="utf-8")
    return r, ctx, root


def _viet_test(root, ten: str, than: str) -> None:
    (root / "tests" / "host" / f"test_{ten}.c").write_text(
        "int hal_doc_nhiet_do(void);\nint main(void) {\n" + than + "\n}\n", encoding="utf-8")


def test_test_dat_thi_passed(du_an_test_host):
    from eide.caps.code import test_host

    r, ctx, root = du_an_test_host
    _viet_test(root, "nhiet", "  return hal_doc_nhiet_do() == 25 ? 0 : 1;")
    rep = test_host({}, ctx)["report"]
    assert rep["passed"] is True, rep["metrics"]
    assert rep["metrics"]["cases"][0]["status"] == "passed"


def test_test_hong_thi_passed_false(du_an_test_host):
    """tc CODE-08 nguyên văn: "Test fail → passed=false"."""
    from eide.caps.code import test_host

    r, ctx, root = du_an_test_host
    _viet_test(root, "sai", "  return hal_doc_nhiet_do() == 99 ? 0 : 1;")
    rep = test_host({}, ctx)["report"]
    assert rep["passed"] is False
    assert rep["metrics"]["cases"][0]["status"] == "failed"
    assert rep["metrics"]["cases"][0]["exit_code"] == 1


def test_loi_DICH_khac_loi_CHAY(du_an_test_host):
    """Hai kết quả khác nhau, không gộp: cái đầu là mã không biên dịch được, cái sau là hành vi
    sai — hai việc phải sửa khác nhau, và `code.self_repair` rẽ theo đó."""
    from eide.caps.code import test_host

    r, ctx, root = du_an_test_host
    _viet_test(root, "khong_dich_duoc", "  thieu_dau_cham_phay()")
    rep = test_host({}, ctx)["report"]
    assert rep["metrics"]["cases"][0]["status"] == "compile_error"


def test_bo_loc_chon_dung_tep(du_an_test_host):
    from eide.caps.code import test_host

    r, ctx, root = du_an_test_host
    _viet_test(root, "mot", "  return 0;")
    _viet_test(root, "hai", "  return 1;")
    rep = test_host({"filter": "mot"}, ctx)["report"]
    assert rep["metrics"]["total"] == 1 and rep["passed"] is True


def test_doc_junit_khi_co_va_noi_ro_khi_khong(tmp_path):
    from eide.caps.code import _junit

    f = tmp_path / "o.txt"
    f.write_text('<testsuite name="t" tests="7" failures="2" errors="1"></testsuite>\n',
                 encoding="utf-8")
    assert _junit(f) == {"tests": 7, "failures": 2, "errors": 1, "detail": "JUnit XML"}
    f.write_text("chay xong\n", encoding="utf-8")
    assert "mã thoát" in _junit(f)["detail"]


def test_nhac_HAL_Delay_trong_chu_thich_khong_phai_vi_pham():
    """Quét thân ISR cũng phải bỏ chú thích và chuỗi. Không bỏ thì một dòng ghi chú *cấm* dùng
    delay lại bị báo là dùng delay — và người sửa sẽ xóa chính lời cảnh báo ấy đi."""
    src = ('void TIM2_IRQHandler(void) {\n'
           '    /* Không được gọi HAL_Delay ở đây — xem ADR-03 */\n'
           '    const char *s = "HAL_Delay(1)";\n'
           '    dat_co();\n'
           '}\n')
    assert [f for f in _pack(src) if f["rule"] == "no_delay_in_isr"] == []


def test_cau_if_trong_ISR_khong_bi_dem_thanh_mot_ISR_nua():
    """Một câu `if` cùng dòng với `__attribute__` là ca dễ thành ISR thứ hai: phép nhìn-lui hai
    dòng sẽ thấy thuộc tính. Cùng một `HAL_Delay` bị báo hai lần thì người đọc đi tìm một ISR
    không tồn tại. Bất biến giữ được nhờ chính khuôn nhận diện hàm — nó đòi một token KIỂU trước
    tên, mà `if` chỉ có một token trước ngoặc."""
    src = ('__attribute__((interrupt)) void h(void) {\n'
           '    if (co_du_lieu) { HAL_Delay(1); }\n'
           '}\n')
    ds = [f for f in _pack(src) if f["rule"] == "no_delay_in_isr"]
    assert len(ds) == 1, f"báo trùng: {ds}"
    assert "`h`" in ds[0]["message"]


# ---------- CODE-01 generate_module

class _GW:
    """Gateway giả. `compose` cần `prompt(role)` cho lớp C1 (CXD-10 §2); `run` trả CodePatch."""

    def __init__(self, patch):
        self.patch = patch
        self.de_bai = None

    def prompt(self, role):
        return f"# vai trò {role}"

    def run(self, role, prompt, schema, system_extra=""):
        self.de_bai = prompt
        assert role == "coder", role

        class R:
            data = self.patch
        return R()


def _ke_hoach(root, feature="F-01", quyet_dinh="APPROVE", buoc=None):
    from eide.caps.plan import ghi_plan
    plan = {"steps": buoc or [{"id": "step-2", "goal": "đọc nhiệt độ qua I2C",
                               "cap": "code.generate_module", "done_when": "trả về mã lỗi 0",
                               "cites": ["f_00000000000000ab"], "touches": ["none"]}]}
    ghi_plan(root, feature, plan, {"decision": quyet_dinh, "rule": "G1-01", "reason": "x",
                                   "gate": "G1"})


def _cp(content="int f(void){ return 0; }\n", path="src/i2c.c", **them):
    return {"files": [{"path": path, "content": content, "mode": "create"}],
            "cites": ["f_00000000000000ab"], "rationale": "theo bước step-2", **them}


def test_chua_co_ke_hoach_thi_khong_sinh_ma(du_an):
    """Grounding của CODE-01 là "G1 approved". Không có kế hoạch thì không có gì đã được duyệt."""
    from eide.caps.code import generate_module
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    ctx.extra["gateway"] = _GW(_cp())
    with pytest.raises(EideError) as e:
        generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert e.value.code == "E2000" and "plan/F-01" in e.value.data["missing"]


def test_ke_hoach_chua_qua_cong_G1_thi_khong_sinh_ma(du_an):
    """Sinh mã cho một kế hoạch đang chờ người là làm ngược thứ tự mà cả APD-08 dựng ra."""
    from eide.caps.code import generate_module
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _ke_hoach(root, quyet_dinh="ASK")
    ctx.extra["gateway"] = _GW(_cp())
    with pytest.raises(EideError) as e:
        generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert e.value.code == "E3000" and e.value.data["gate"] == "G1"


def test_hang_so_khong_nguon_thi_E5003_va_patch_KHONG_duoc_luu(du_an):
    """tc CODE-01: "Mọi hằng số có eide:fact"; TC-04. Lưu patch rồi mới chặn thì cái đã lưu là
    một patch chưa qua guard, và `code.merge` sau này chỉ thấy một tệp trông hợp lệ."""
    from eide.caps.code import generate_module
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _ke_hoach(root)
    ctx.extra["gateway"] = _GW(_cp("#define BME280_ADDR 0x76\n"))
    with pytest.raises(EideError) as e:
        generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert e.value.code == "E5003"
    assert e.value.data["violations"][0]["rule" if "rule" in e.value.data["violations"][0]
                                        else "reason"] == "no_fact"
    assert not (root / ".eide" / "patches").exists(), "patch bị chặn mà vẫn được lưu"


def test_hang_so_co_fact_da_duyet_thi_qua_va_luu_patch(du_an):
    from eide.caps.code import doc_patch, generate_module

    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="verified", tier="gold")
    _ke_hoach(root)
    ctx.extra["gateway"] = _GW(_cp("#define A 0x76 /* eide:fact f_00000000000000ab */\n"))
    out = generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert out["cites"] == ["f_00000000000000ab"]
    luu = doc_patch(root, out["patch"]["id"])
    assert luu["step_ref"] == "F-01/step-2"
    assert luu["patch"]["files"][0]["path"] == "src/i2c.c"


def test_KHONG_ghi_vao_repo_truoc_khi_merge(du_an):
    """Sinh mã và ghi mã là hai quyết định khác nhau, và chỉ quyết định thứ hai mới cần reviewer
    khác hãng qua cổng G3."""
    from eide.caps.code import generate_module

    _, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="verified", tier="gold")
    _ke_hoach(root)
    ctx.extra["gateway"] = _GW(_cp("#define A 0x76 /* eide:fact f_00000000000000ab */\n"))
    generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert not (root / "src" / "i2c.c").exists(), "patch đã ghi thẳng vào repo"


def test_missing_facts_cua_coder_duoc_ton_trong(du_an):
    """PRS-16 §3 dạy coder "dừng và trả missing_facts[]" thay vì bịa. Phạt nó vì trung thực thì
    lần sau nó bịa cho đủ — cùng bài học với `doc.section`."""
    from eide.caps.code import generate_module
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _ke_hoach(root)
    ctx.extra["gateway"] = _GW(_cp(missing_facts=["địa chỉ I2C của BME280"]))
    with pytest.raises(EideError) as e:
        generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert e.value.code == "E5003"
    assert e.value.data["missing_facts"] == ["địa chỉ I2C của BME280"]


@pytest.mark.parametrize("duong", [
    "cmake/arm.cmake", "/etc/passwd", "../ngoai.c", ".eide/policy.sig",
    "src/../.eide/policy.sig",
])
def test_tep_ngoai_pham_vi_bi_chan(du_an, duong):
    """`src/../.eide/policy.sig` bắt đầu bằng `src/`, nên một phép so tiền tố thô cho nó qua —
    và tác tử ghi đè được chữ ký chính sách bằng một patch trông hoàn toàn trong phạm vi."""
    from eide.caps.code import generate_module
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _ke_hoach(root)
    ctx.extra["gateway"] = _GW(_cp(path=duong))
    with pytest.raises(EideError) as e:
        generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert e.value.code == "E8000" and duong in e.value.data["files"]


def test_files_allowed_cua_ben_goi_thay_pham_vi_mac_dinh(du_an):
    from eide.caps.code import generate_module

    _, ctx, root = du_an
    _ke_hoach(root)
    ctx.extra["gateway"] = _GW(_cp(path="drivers/i2c.c"))
    out = generate_module({"step_ref": "F-01/step-2", "files_allowed": ["drivers/"]}, ctx)
    assert out["patch"]["files"][0]["path"] == "drivers/i2c.c"


def test_de_bai_mang_theo_muc_tieu_va_dieu_kien_xong(du_an):
    """Mô hình phải thấy `goal` và `done_when` của bước, không chỉ thấy mã bước. Gửi mỗi
    "F-01/step-2" là bắt nó đoán việc cần làm."""
    from eide.caps.code import generate_module

    _, ctx, root = du_an
    _ke_hoach(root)
    gw = _GW(_cp())
    ctx.extra["gateway"] = gw
    generate_module({"step_ref": "F-01/step-2"}, ctx)
    assert "đọc nhiệt độ qua I2C" in gw.de_bai and "trả về mã lỗi 0" in gw.de_bai
    assert "src/" in gw.de_bai


def test_schema_gui_cho_coder_la_CodePatch_cua_PRS16():
    from eide.caps.code import _schema_codepatch
    from eide.caps.plan import schema_vai_tro

    assert _schema_codepatch() == schema_vai_tro("CodePatch")
    assert _schema_codepatch()["required"] == ["files", "cites", "rationale"]


def test_tep_kiem_thu_khong_bi_constant_guard_quet(du_an):
    """Một test khẳng định `bme280_dia_chi() == 0x76` đang KIỂM giá trị, không KHAI nó. Bắt nó
    trích dẫn cùng fact mà mã đang kiểm cũng trích dẫn thì cả hai lấy số từ một chỗ, và test
    không còn kiểm gì — nó chỉ xác nhận hai bản sao của cùng một biến bằng nhau.

    Tìm ra bằng gọi mô hình THẬT: coder chú thích đúng trong `src/` rồi bị chặn vì ba lần `0x76`
    trong tệp test nó tự viết. Xem DEV-064.
    """
    _, ctx, _ = du_an
    assert constant_guard(_patch("int main(void){ return dia_chi() == 0x76 ? 0 : 1; }\n",
                                 "tests/host/test_bme280.c"), ctx)["verdict"] == "pass"
    # đối chứng: CÙNG nội dung ấy trong src/ vẫn bị chặn
    assert constant_guard(_patch("int main(void){ return dia_chi() == 0x76 ? 0 : 1; }\n",
                                 "src/bme280.c"), ctx)["verdict"] == "block"
