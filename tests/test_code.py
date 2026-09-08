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
