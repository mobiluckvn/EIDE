"""Nhóm code.* — CDS-12.1; PRS-16 §3/§4; STP-05 TC-04, TC-06.

TC-04 (chuẩn nghiệm thu, nguyên văn): *"10 patch mẫu có hằng số không chú thích / chú thích fact
không tồn tại / fact bạc chưa duyệt → chặn 100%; fact vàng → qua"*.
TC-06: *"Fact status=normalized → passport.query trả nhưng đánh dấu unreviewed; ConstantGuard
từ chối"*.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

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


# ---------- CODE-05 build: đường chạy chuỗi công cụ THẬT (mục I7)

ARM_GCC = __import__("shutil").which("arm-none-eabi-gcc")

# Dự án CMake tối thiểu cho Cortex-M4. EIDE **không sinh** những tệp này: `code.build` dựng theo
# `CMakeLists` CỦA DỰ ÁN, và lệnh dựng thì lấy từ `toolchain.build.cmd` của manifest ISA. Nên để
# kiểm đường dựng thật, bài test phải mang theo một dự án thật.
#
# Ba dòng dưới đây trông như chi tiết vặt nhưng mỗi dòng là một lần dựng đã hỏng:
#   - `CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY` — phép thử trình dịch của CMake mặc định
#     LINK một chương trình, việc không làm được khi không có libc khởi động được.
#   - `-ffreestanding` — công thức brew `arm-none-eabi-gcc` KHÔNG kèm newlib, nên `<stdint.h>`
#     của GCC `include_next` sang một libc không tồn tại.
#   - `-nostdlib` — không có nó thì `ld` đi tìm `-lc` và dừng, dù mã không gọi hàm thư viện nào.
CMAKE_ARM = """\
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_C_FLAGS_INIT "-mcpu=cortex-m4 -mthumb -ffreestanding -ffunction-sections")
"""

LINKER_LD = """\
MEMORY { FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 512K
         RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 128K }
ENTRY(Reset_Handler)
SECTIONS {
  .isr_vector : { KEEP(*(.isr_vector)) } > FLASH
  .text : { *(.text*) *(.rodata*) } > FLASH
  .bss  : { *(.bss*) *(COMMON) } > RAM
  _estack = ORIGIN(RAM) + LENGTH(RAM);
}
"""

MAIN_C = """\
/* Hằng số phần cứng có chú thích fact — đúng dạng `code.constant_guard` đòi. */
#define BME280_ADDR 0x76u /* eide:fact f_bme280_addr */
volatile unsigned int dem;
extern unsigned int _estack;
void Reset_Handler(void) { for (;;) { dem += BME280_ADDR; } }
__attribute__((section(".isr_vector"), used))
void *const vectors[2] = { (void *)&_estack, (void *)Reset_Handler };
"""

CMAKELISTS = """\
cmake_minimum_required(VERSION 3.22)
project(fw C)
add_executable(fw.elf src/main.c)
target_link_options(fw.elf PRIVATE
  -T${CMAKE_SOURCE_DIR}/stm32f411.ld -nostartfiles -nostdlib -Wl,--gc-sections
  -Wl,-Map=${CMAKE_BINARY_DIR}/fw.map)
"""


def _du_an_cmake(root) -> None:
    (root / "cmake").mkdir(parents=True, exist_ok=True)
    (root / "src").mkdir(parents=True, exist_ok=True)
    (root / "cmake" / "arm.cmake").write_text(CMAKE_ARM, encoding="utf-8")
    (root / "stm32f411.ld").write_text(LINKER_LD, encoding="utf-8")
    (root / "src" / "main.c").write_text(MAIN_C, encoding="utf-8")
    (root / "CMakeLists.txt").write_text(CMAKELISTS, encoding="utf-8")


@pytest.mark.skipif(ARM_GCC is None, reason="cần arm-none-eabi-gcc (brew install arm-none-eabi-gcc)")
def test_dung_THAT_ra_firmware_armv7e_m(du_an):
    """CODE-05 chạy chuỗi công cụ THẬT — không shim.

    Mọi bài `code.build` khác trong tệp này kiểm nhánh HỎNG: thiếu công cụ → E4001, chưa ghim
    ISA → E2000. Nhánh THÀNH CÔNG thì tới 11/09/2026 chưa lần nào được thi hành — `test_code.py`
    dựng shim shell cho `arm-none-eabi-size`, `nghiem_thu_sprint2.sh` không có bước biên dịch, và
    `test_that.py` (lớp gọi thật) không có test nào cho `code.build`. Mà đây là mắt xích trung
    tâm của luận điểm đề án: không có nó, "sinh mã có nối về fact" dừng ở phần tri thức.

    Bài này đi trọn đường: lệnh dựng đọc từ `docs/spec/isa/armv7e-m.yaml` (không từ bảng trong
    mã), chạy trong sandbox KHÔNG MẠNG, và thứ rơi ra là một ELF mà `objdump` đọc được là
    `armv7e-m` — đúng ISA mà manifest khai, không phải kiến trúc của máy đang chạy test.
    """
    import subprocess

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    _du_an_cmake(root)

    from eide.caps.code import build
    rep = build({}, ctx)["report"]

    assert rep["passed"] is True, rep["metrics"]
    assert rep["metrics"]["isa"] == "armv7e-m" and rep["metrics"]["exit_code"] == 0
    assert rep["artifacts"] and rep["artifacts"][0].endswith("fw.elf")
    # `map` của manifest (`build/*.map`) phải trỏ tới tệp có thật — `code.size` và
    # `diagram.memory_map` đều đứng trên nó.
    assert rep["metrics"]["map"] and Path(rep["metrics"]["map"]).exists()

    elf = Path(rep["artifacts"][0])
    assert elf.read_bytes()[:4] == b"\x7fELF"
    mo_ta = subprocess.run(["arm-none-eabi-objdump", "-f", str(elf)],
                           capture_output=True, text=True, check=True).stdout
    assert "elf32-littlearm" in mo_ta, mo_ta
    assert "armv7e-m" in mo_ta, mo_ta


@pytest.mark.skipif(ARM_GCC is None, reason="cần arm-none-eabi-gcc")
def test_size_doc_so_THAT_tu_arm_none_eabi_size(du_an):
    """CODE-06 trên một ELF thật, `arm-none-eabi-size` thật — không shim.

    Các bài `size` khác dựng shim in ra một bảng Berkeley cố định, nên chúng kiểm được phép
    phân tích và ngưỡng 85% mà không kiểm được rằng EIDE gọi đúng công cụ với đúng tham số.
    """
    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    _du_an_cmake(root)
    # STM32F411RE: 512 KB Flash, 128 KB RAM. Không có hai fact này thì `passed` là False dù
    # firmware bé tí — và đó là hành vi ĐÚNG: "chưa biết giới hạn thì không kết luận đạt".
    _flash_ram(root, "STM32F411RE", 512 * 1024, 128 * 1024)

    from eide.caps.code import build, size
    art = build({}, ctx)["report"]["artifacts"][0]
    rep = size({"artifact": art}, ctx)["report"]

    m = rep["metrics"]
    # Firmware tối thiểu: vài chục byte text, 4 byte bss. Khẳng định "có số và số hợp lý" chứ
    # không khẳng định con số chính xác — nó đổi theo phiên bản trình dịch.
    assert m["text"] > 0 and m["text"] < 4096, m
    assert m["bss"] >= 4, m
    assert m["flash"] == m["text"] + m["data"], m
    # Phần trăm tính được ⇒ mới có quyền kết luận. Firmware vài chục byte trên 512 KB thì tỉ lệ
    # gần 0, tức xa ngưỡng 85% — bài này kiểm đường ĐI tới kết luận, không kiểm ngưỡng.
    assert m["flash_pct"] is not None and m["flash_pct"] < 1, m
    assert rep["passed"] is True, m


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
    """Gateway giả. `compose` cần `prompt(role)` cho lớp C1 (CXD-10 §2); `run` trả CodePatch.

    Mang `model_id` và `hang_cua` giống Gateway thật, vì `generate_module` ghi hãng của coder vào
    patch (CODE-11 đòi "≥ 2 hãng", `G3-01` so `reviewer.vendor != coder.vendor`). Một giả lập
    thiếu đúng trường mà mã đọc thì nó giấu lỗi thay vì tìm ra lỗi.
    """

    def __init__(self, patch, model_id="gemini-3.8-flash", vendor="gemini"):
        self.patch = patch
        self.model_id = model_id
        self.vendor = vendor
        self.de_bai = None
        self.vai_tro = None
        # `system_extra` là nơi ngữ cảnh đi qua (C2/C4/C5/C6). Giả lập không giữ nó thì mọi test
        # về "mô hình có THẤY thứ này không" đều kiểm nhầm chỗ và luôn xanh.
        self.ngu_canh = None

    def prompt(self, role):
        return f"# vai trò {role}"

    def hang_cua(self, model_id):
        return self.vendor

    def run(self, role, prompt, schema, system_extra=""):
        self.de_bai, self.vai_tro, self.ngu_canh = prompt, role, system_extra
        gw = self

        class R:
            data = gw.patch
            model_id = gw.model_id
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


# ---------- CODE-09 generate_tests

def _feature(root, fid="F-01", **them):
    ds = [{"id": fid, "title": "đọc nhiệt độ", "status": "failing",
           "expectation": {"kind": "serial_pattern", "detail": "in ra `T=<số>C` mỗi giây"},
           **them}]
    (root / ".eide" / "FEATURES.json").write_text(json.dumps(ds, ensure_ascii=False),
                                                  encoding="utf-8")


def _bo_test(*ds):
    return {"tests": list(ds)}


def test_thieu_kich_ban_thi_E5002(du_an):
    """tc CODE-09: "Có ít nhất 1 test host và 1 kịch bản". Chỉ một loại thì hoặc bỏ trống nửa hệ
    thống, hoặc phải chờ board mới biết mình sai."""
    from eide.caps.code import generate_tests
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _feature(root)
    ctx.extra["gateway"] = _GW(_bo_test({"path": "a.c", "content": "int main(void){return 0;}",
                                         "kind": "host"}))
    with pytest.raises(EideError) as e:
        generate_tests({"feature": "F-01"}, ctx)
    assert e.value.code == "E5002" and e.value.data["kinds"] == ["host"]


def test_thieu_test_host_cung_E5002(du_an):
    from eide.caps.code import generate_tests
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _feature(root)
    ctx.extra["gateway"] = _GW(_bo_test({"path": "s.yaml", "content": "x", "kind": "sim"}))
    with pytest.raises(EideError) as e:
        generate_tests({"feature": "F-01"}, ctx)
    assert e.value.code == "E5002"


def test_du_hai_loai_thi_qua_va_duong_dan_ve_dung_thu_muc(du_an):
    """Mô hình hay trả `test_x.c` trần hoặc `tests/x.c`. Để nguyên thì `code.test_host` không
    tìm thấy, và vòng sinh-dựng-kiểm đứt ở khớp giữa hai năng lực CÙNG MỘT NHÓM."""
    from eide.caps.code import MAU_TEST_HOST, generate_tests

    _, ctx, root = du_an
    _feature(root)
    ctx.extra["gateway"] = _GW(_bo_test(
        {"path": "nhiet.c", "content": "int main(void){return 0;}", "kind": "host"},
        {"path": "tests/kich_ban.yaml", "content": "steps: []", "kind": "sim"}))
    ds = generate_tests({"feature": "F-01"}, ctx)["tests"]
    duong = {t["kind"]: t["path"] for t in ds}
    assert duong["host"] == "tests/host/test_nhiet.c"
    assert duong["sim"] == "tests/sim/kich_ban.yaml"
    from pathlib import PurePosixPath
    assert PurePosixPath(duong["host"]).match(MAU_TEST_HOST), \
        "đường dẫn phải khớp mẫu mà `code.test_host` đi tìm"


def test_de_bai_test_lay_tu_expectation_khong_lay_tu_ma(du_an):
    """Test sinh từ mã chỉ khẳng định mã làm đúng cái nó đang làm; test sinh từ kỳ vọng mới bắt
    được lúc mã làm sai. Đó là cả lý do `plan.define_feature` ép kỳ vọng thành đo được."""
    from eide.caps.code import generate_tests

    _, ctx, root = du_an
    _feature(root)
    gw = _GW(_bo_test({"path": "a.c", "content": "x", "kind": "host"},
                      {"path": "b.yaml", "content": "y", "kind": "hil"}))
    ctx.extra["gateway"] = gw
    generate_tests({"feature": "F-01"}, ctx)
    assert "in ra `T=<số>C` mỗi giây" in gw.de_bai and "serial_pattern" in gw.de_bai


def test_feature_khong_co_thi_bao_ro(du_an):
    from eide.caps.code import generate_tests
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _feature(root)
    with pytest.raises(EideError) as e:
        generate_tests({"feature": "F-99"}, ctx)
    assert e.value.code == "E2000"


# ---------- CODE-11 review

def _rv(verdict="PASS", findings=None):
    return {"verdict": verdict, "findings": findings or []}


def test_review_khac_hang_thi_independent(du_an):
    """Grounding của CODE-11 là "≥ 2 hãng": hai mô hình cùng hãng chia nhau dữ liệu huấn luyện
    và cả những chỗ mù của nhau."""
    from eide.caps.code import review

    _, ctx, root = du_an
    ctx.extra["gateway"] = _GW(_rv(), model_id="claude-sonnet-5", vendor="claude")
    rv = review({"patch": {"id": "patch_1", "by": {"vendor": "gemini"}, "files": []}},
                ctx)["review"]
    assert rv["independent"] is True
    assert rv["vendors"] == {"coder": "gemini", "reviewer": "claude"}
    assert "note" not in rv


def test_review_cung_hang_thi_noi_ra_chu_khong_im(du_an):
    """Một bản review cùng hãng vẫn có ích, nhưng nó KHÔNG thỏa grounding của CODE-11 — và
    người đọc cần biết lý do ngay ở đây, không phải mãi tới lúc `G3-01` từ chối."""
    from eide.caps.code import review

    _, ctx, root = du_an
    ctx.extra["gateway"] = _GW(_rv(), model_id="gemini-3.1-pro-preview", vendor="gemini")
    rv = review({"patch": {"id": "p", "by": {"vendor": "gemini"}, "files": []}}, ctx)["review"]
    assert rv["independent"] is False and "≥ 2 hãng" in rv["note"]


def test_max_severity_la_none_khi_khong_co_finding(du_an):
    """`G3-01` so `review.max_severity in ["minor","nit","none"]`. Trả chuỗi rỗng hay thiếu
    trường thì quy tắc không khớp, và một patch SẠCH lại không merge được."""
    from eide.caps.code import review

    _, ctx, root = du_an
    ctx.extra["gateway"] = _GW(_rv())
    assert review({"patch": {"id": "p", "files": []}}, ctx)["review"]["max_severity"] == "none"


def test_max_severity_lay_muc_NANG_NHAT(du_an):
    from eide.caps.code import review

    _, ctx, root = du_an
    ctx.extra["gateway"] = _GW(_rv("FAIL", [
        {"severity": "nit", "file": "a.c", "line": 1, "message": "x"},
        {"severity": "blocker", "file": "a.c", "line": 2, "message": "y"},
        {"severity": "minor", "file": "a.c", "line": 3, "message": "z"}]))
    assert review({"patch": {"id": "p", "files": []}}, ctx)["review"]["max_severity"] == "blocker"


def test_review_duoc_luu_de_merge_doc_lai(du_an):
    from eide.caps.code import doc_review, review

    _, ctx, root = du_an
    ctx.extra["gateway"] = _GW(_rv())
    rv = review({"patch": {"id": "patch_9", "files": []}}, ctx)["review"]
    luu = doc_review(root, rv["id"])
    assert luu["patch_id"] == "patch_9" and luu["review"]["verdict"] == "PASS"


def test_reviewer_duoc_giao_dung_vai_tro_va_thay_noi_dung_patch(du_an):
    """Bước 1: "Router chọn reviewer khác hãng coder". Gọi nhầm vai `coder` thì mô hình nhận
    prompt "hãy viết mã" và sẽ sửa mã thay vì chấm."""
    from eide.caps.code import review

    _, ctx, root = du_an
    gw = _GW(_rv())
    ctx.extra["gateway"] = gw
    review({"patch": {"id": "p", "rationale": "vì fact f_1",
                      "files": [{"path": "src/a.c", "content": "int x = 0x40;"}]}}, ctx)
    assert gw.vai_tro == "reviewer"
    assert "src/a.c" in gw.de_bai and "int x = 0x40;" in gw.de_bai
    assert "KHÔNG sửa mã" in gw.de_bai


# ---------- CODE-12 merge, CODE-13 revert

def _bao_cao(root, tool, passed=True, metrics=None):
    from eide_core import store as _s
    _s.ghi_tool_report(_s.store_path(root), {
        "tool": tool, "passed": passed, "log_ref": None, "metrics": metrics or {},
        "artifacts": [], "duration_ms": 1, "started_by": "test",
        "at": "2026-09-08T00:00:00+00:00"})
    with _s.open_store(_s.store_path(root)) as c:
        r = c.execute("SELECT id FROM tool_report WHERE tool=? ORDER BY rowid DESC LIMIT 1",
                      (tool,)).fetchone()
    return r[0]


def _luu_rv(root, verdict="PASS", sev="minor", coder="gemini", reviewer="claude"):
    import secrets
    rid = "rv_" + secrets.token_hex(6)
    f = root / ".eide" / "reviews" / f"{rid}.json"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps({"id": rid, "patch_id": "p", "review": {
        "verdict": verdict, "findings": [], "max_severity": sev,
        "vendors": {"coder": coder, "reviewer": reviewer}}}), encoding="utf-8")
    return rid


def _patch_sach(**them):
    return {"id": "patch_1", "by": {"model_id": "gemini-3.8-flash", "vendor": "gemini"},
            "cites": ["f_00000000000000ab"], "rationale": "đọc nhiệt độ qua I2C",
            "files": [{"path": "src/bme280.c",
                       "content": "#define A 0x76 /* eide:fact f_00000000000000ab */\n"}],
            **them}


@pytest.fixture
def san_sang_merge(du_an):
    """Dự án đủ điều kiện S23: 4/4 cổng đạt, CG 0, PASS minor, trong phạm vi, khác hãng."""
    r, ctx, root = du_an
    _fact(root, "f_00000000000000ab", "0x76", status="verified", tier="gold")
    reports = [_bao_cao(root, t) for t in ("build", "size", "static", "test_host")]
    return r, ctx, root, reports, _luu_rv(root)


@pytest.mark.skipif(__import__("shutil").which("git") is None, reason="cần git")
def test_merge_du_bang_chung_thi_commit_vao_nhanh_auto(san_sang_merge):
    """S23: "4/4 cổng; CG 0; PASS minor; trong phạm vi; +2%; khác hãng" → APPROVE G3-01."""
    from eide.caps.code import merge
    from eide_core import git

    r, ctx, root, reports, rid = san_sang_merge
    out = merge({"patch": _patch_sach(), "feature": "F-01", "reports": reports,
                 "review_id": rid}, ctx)
    assert out["branch"] == "auto/F-01" and len(out["commit"]) == 40
    assert (root / "src" / "bme280.c").exists(), "APPROVE mà không ghi tệp"
    log = git.chay(root, "log", "-1", "--format=%B").stdout
    assert log.startswith("feat(F-01): đọc nhiệt độ qua I2C")
    assert "Eide-Facts: f_00000000000000ab" in log
    assert "Eide-Model: gemini-3.8-flash" in log and "Eide-Prompt: sha256:" in log


@pytest.mark.skipif(__import__("shutil").which("git") is None, reason="cần git")
def test_merge_KHONG_gom_tep_nguoi_dung_dang_sua_do(san_sang_merge):
    """`git add -A` sẽ cuốn mọi thứ trong cây làm việc vào một commit mang trailer "do tác tử
    tạo" — và trailer ấy nói dối."""
    from eide.caps.code import merge
    from eide_core import git

    r, ctx, root, reports, rid = san_sang_merge
    git.dam_bao_kho(root)
    (root / "ghi_chu_cua_toi.txt").write_text("việc riêng", encoding="utf-8")
    merge({"patch": _patch_sach(), "feature": "F-01", "reports": reports, "review_id": rid}, ctx)
    tep = git.chay(root, "show", "--name-only", "--format=", "HEAD").stdout.split()
    assert tep == ["src/bme280.c"], tep


def test_dac_trung_G3_tinh_lai_KHONG_nhan_tu_ben_goi(san_sang_merge):
    """Một cổng đọc con số do bên xin cấp phép tự khai thì không phải là cổng."""
    from eide.caps.code import dac_trung_G3

    r, ctx, root, reports, rid = san_sang_merge
    # bên gọi "khai" toàn số đẹp trong chính patch — phải bị bỏ qua hoàn toàn
    d = dac_trung_G3(root, _patch_sach(tools_passed=4, constant_guard_violations=0),
                     reports[:2], rid, ctx)
    assert d["patch"]["tools_passed"] == 2, "đếm theo báo cáo có thật, không theo lời khai"


def test_G3_03_hang_so_khong_nguon_thi_REJECT(san_sang_merge):
    """S25: "CG 2 vi phạm" → REJECT G3-03. `constant_guard` chạy LẠI ở merge dù generate_module
    đã chạy: patch nằm trên đĩa giữa hai lần gọi và có thể đã bị sửa."""
    from eide.caps.code import merge
    from eide_core.errors import EideError

    r, ctx, root, reports, rid = san_sang_merge
    ban = _patch_sach()
    ban["files"][0]["content"] = "#define A 0x76\n#define B 0x77\n"
    with pytest.raises(EideError) as e:
        merge({"patch": ban, "feature": "F-01", "reports": reports, "review_id": rid}, ctx)
    assert e.value.code == "E3001" and e.value.data["rule"] == "G3-03"
    assert not (root / "src" / "bme280.c").exists(), "REJECT mà vẫn ghi tệp"


def test_G3_02_finding_major_thi_hoi_nguoi(san_sang_merge):
    """S24: "như S23 nhưng major" → ASK G3-02."""
    from eide.caps.code import merge
    from eide_core.errors import EideError

    r, ctx, root, reports, _ = san_sang_merge
    with pytest.raises(EideError) as e:
        merge({"patch": _patch_sach(), "feature": "F-01", "reports": reports,
               "review_id": _luu_rv(root, sev="major")}, ctx)
    assert e.value.code == "E3000" and e.value.data["rule"] == "G3-02"


def test_G3_04_cung_hang_thi_hoi_nguoi(san_sang_merge):
    """S26: "như S23 nhưng cùng hãng" → ASK G3-04."""
    from eide.caps.code import merge
    from eide_core.errors import EideError

    r, ctx, root, reports, _ = san_sang_merge
    with pytest.raises(EideError) as e:
        merge({"patch": _patch_sach(), "feature": "F-01", "reports": reports,
               "review_id": _luu_rv(root, reviewer="gemini")}, ctx)
    assert e.value.code == "E3000" and e.value.data["rule"] == "G3-04"


def test_S27_cham_ISR_thi_khong_tu_duyet(san_sang_merge):
    """S27: "như S23 nhưng chạm ISR" → ASK G3-99."""
    from eide.caps.code import merge
    from eide_core.errors import EideError

    r, ctx, root, reports, rid = san_sang_merge
    ban = _patch_sach()
    ban["files"][0]["content"] = ("#define A 0x76 /* eide:fact f_00000000000000ab */\n"
                                  "void TIM2_IRQHandler(void) { dat_co(); }\n")
    with pytest.raises(EideError) as e:
        merge({"patch": ban, "feature": "F-01", "reports": reports, "review_id": rid}, ctx)
    assert e.value.code == "E3000"
    assert e.value.data["features"]["patch"]["touches_isr_linker"] is True


def test_tep_linker_cung_tinh_la_cham(san_sang_merge):
    from eide.caps.code import _cham_isr_linker

    for d in ("STM32F411.ld", "cmake/../link.icf", "src/startup_stm32.s", "src/vector_table.c"):
        assert _cham_isr_linker({"files": [{"path": d, "content": ""}]}) is True, d
    assert _cham_isr_linker({"files": [{"path": "src/i2c.c", "content": "int f(void){return 0;}"}]}) is False


def test_thieu_mot_cong_thi_khong_tu_duyet(san_sang_merge):
    """`tools_passed == 4` — bốn cái CỤ THỂ, không phải bốn cái bất kỳ."""
    from eide.caps.code import merge
    from eide_core.errors import EideError

    r, ctx, root, _, rid = san_sang_merge
    ba = [_bao_cao(root, t) for t in ("build", "size", "static")]
    with pytest.raises(EideError) as e:
        merge({"patch": _patch_sach(), "feature": "F-01", "reports": ba, "review_id": rid}, ctx)
    assert e.value.code == "E3000" and e.value.data["features"]["patch"]["tools_passed"] == 3


def test_cong_bao_KHONG_dat_thi_khong_duoc_tinh(san_sang_merge):
    from eide.caps.code import dac_trung_G3

    r, ctx, root, _, rid = san_sang_merge
    ds = [_bao_cao(root, t, passed=(t != "static")) for t in
          ("build", "size", "static", "test_host")]
    assert dac_trung_G3(root, _patch_sach(), ds, rid, ctx)["patch"]["tools_passed"] == 3


def test_size_ghi_moc_flash_lan_truoc_cho_merge(du_an_size):
    """`size_growth_pct` của `G3-01` cần một mốc. Không ghi lúc ĐO thì lúc merge không còn chỗ
    nào biết, và ngưỡng `merge_size_growth_pct` thành quy tắc không bao giờ khớp."""
    from eide.caps.code import _tang_kich_thuoc, size

    r, ctx, root, bin_gia = du_an_size
    _flash_ram(root, "STM32F411RE", 512 * 1024, 128 * 1024)
    _shim(bin_gia, "arm-none-eabi-size",
          "echo 'text data bss dec hex f'; echo ' 10000\t0\t0\t10000\t2710\tfw.elf'")
    assert size({"artifact": "build/fw.elf"}, ctx)["report"]["metrics"]["flash_truoc"] is None
    _shim(bin_gia, "arm-none-eabi-size",
          "echo 'text data bss dec hex f'; echo ' 10500\t0\t0\t10500\t2904\tfw.elf'")
    m = size({"artifact": "build/fw.elf"}, ctx)["report"]["metrics"]
    assert m["flash_truoc"] == 10000
    assert _tang_kich_thuoc([{"tool": "size", "metrics": m}]) == 5.0


@pytest.mark.skipif(__import__("shutil").which("git") is None, reason="cần git")
def test_revert_giu_lich_su_khong_viet_lai(san_sang_merge):
    """`git revert` chứ không `git reset`: ai đọc `git log` sau này cần thấy CẢ hai việc — đã
    merge, rồi đã hoàn tác vì lý do gì — chứ không thấy một khoảng trống."""
    from eide.caps.code import merge, revert
    from eide_core import git

    r, ctx, root, reports, rid = san_sang_merge
    sha = merge({"patch": _patch_sach(), "feature": "F-01", "reports": reports,
                 "review_id": rid}, ctx)["commit"]
    out = revert({"commit": sha, "reason": "sai địa chỉ"}, ctx)
    assert out["revert_commit"] != sha
    assert not (root / "src" / "bme280.c").exists(), "revert mà tệp vẫn còn"
    log = git.chay(root, "log", "--format=%s").stdout.splitlines()
    assert len(log) == 2 and log[0].startswith("fix(revert):")
    assert "sai địa chỉ" in git.chay(root, "log", "-1", "--format=%B").stdout


@pytest.mark.skipif(__import__("shutil").which("git") is None, reason="cần git")
def test_revert_commit_khong_co_thi_E7001(du_an):
    from eide.caps.code import revert
    from eide_core import git
    from eide_core.errors import EideError

    _, ctx, root = du_an
    git.dam_bao_kho(root)
    with pytest.raises(EideError) as e:
        revert({"commit": "0" * 40, "reason": "x"}, ctx)
    assert e.value.code == "E7001"


def test_git_chi_cho_phep_con_lenh_trong_danh_sach(du_an):
    """Thêm `git push` hay `git clean -fdx` vào đây phải là một thay đổi PHẢI ĐỌC — cả hai đều
    không hoàn tác được, và cả hai đều rất dễ viết ra trong lúc sửa một lỗi khác."""
    from eide_core import git
    from eide_core.errors import EideError

    _, _, root = du_an
    for xau in ("push", "clean", "reset"):
        with pytest.raises(EideError) as e:
            git.chay(root, xau)
        assert e.value.code == "E8000"


# ---------- CODE-02 modify

def test_modify_dua_noi_dung_HIEN_TAI_cho_mo_hinh(du_an):
    """Không đưa thì mô hình viết lại cả tệp theo trí nhớ về "một driver BME280 trông như thế
    nào", và mọi thứ người khác đã sửa trong đó biến mất mà không ai thấy trong diff — vì diff
    so với bản mới chứ không so với ý định."""
    from eide.caps.code import modify

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "bme280.c").write_text("int doc(void){ return 0; } /* cua nguoi khac */\n",
                                            encoding="utf-8")
    gw = _GW({"files": [{"path": "src/bme280.c", "content": "int doc(void){ return 1; }\n"}],
              "cites": [], "rationale": "thêm timeout"})
    ctx.extra["gateway"] = gw
    modify({"file": "src/bme280.c", "intent": "thêm timeout"}, ctx)
    assert "cua nguoi khac" in gw.ngu_canh, "nội dung hiện tại không tới được mô hình"
    assert "C5" in gw.ngu_canh


def test_modify_tep_khong_ton_tai_thi_bao_ro(du_an):
    from eide.caps.code import modify
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    ctx.extra["gateway"] = _GW(_cp())
    with pytest.raises(EideError) as e:
        modify({"file": "src/chua_co.c", "intent": "x"}, ctx)
    assert e.value.code == "E2000"


def test_modify_cham_ISR_thi_hoi_nguoi(du_an):
    """`ask_when` của CODE-02 là "Chạm ISR/linker", và phép kiểm chạy trên KẾT QUẢ chứ không
    trên yêu cầu: xin "thêm timeout" mà mô hình sửa luôn vector ngắt thì ý định vô hại, hậu quả
    thì không."""
    from eide.caps.code import modify
    from eide_core.errors import EideError

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "bme280.c").write_text("int doc(void){ return 0; }\n", encoding="utf-8")
    ctx.extra["gateway"] = _GW({"files": [{"path": "src/bme280.c",
                                           "content": "void TIM2_IRQHandler(void){ doc(); }\n"}],
                                "cites": [], "rationale": "thêm timeout"})
    with pytest.raises(EideError) as e:
        modify({"file": "src/bme280.c", "intent": "thêm timeout"}, ctx)
    assert e.value.code == "E3000" and e.value.data["rule"] == "CODE-02"


def test_modify_findings_vao_de_bai(du_an):
    from eide.caps.code import modify

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "a.c").write_text("int f(void){return 0;}\n", encoding="utf-8")
    gw = _GW({"files": [{"path": "src/a.c", "content": "int f(void){return 0;}\n"}],
              "cites": [], "rationale": "x"})
    ctx.extra["gateway"] = gw
    modify({"file": "src/a.c", "intent": "sửa", "findings": [
        {"file": "src/a.c", "line": 1, "severity": "major", "message": "thiếu kiểm lỗi"}]}, ctx)
    assert "thiếu kiểm lỗi" in gw.de_bai and "src/a.c:1" in gw.de_bai


# ---------- CODE-03 integrate

def _module(root, mid, depends=None, interfaces=None, resource=None):
    from eide_core import store as _s
    with _s.open_store(_s.store_path(root)) as c:
        c.execute("INSERT INTO module (id, name, responsibility, depends, interfaces, status)"
                  " VALUES (?,?,?,?,?,?)",
                  (mid, mid, "x", json.dumps(depends or []),
                   json.dumps(interfaces or []), "proposed"))
        if resource:
            c.execute("INSERT INTO hw_map (module_id, resource, role, fact_ids) VALUES (?,?,?,?)",
                      (mid, resource, "bus", "[]"))
        c.commit()


def test_integrate_thu_tu_khoi_tao_tu_plan_order_khong_hoi_mo_hinh(du_an):
    """Thứ tự khởi tạo là ràng buộc VẬT LÝ — cấu hình I2C trước khi bật clock cho nó thì thanh
    ghi ghi vào hư không. Hỏi mô hình là mời ảo giác vào chỗ có câu trả lời đúng."""
    from eide.caps.code import integrate

    _, ctx, root = du_an
    _module(root, "mod_app", depends=["mod_i2c"])
    _module(root, "mod_i2c")
    gw = _GW({"files": [{"path": "src/main.c", "content": "int main(void){return 0;}\n"}],
              "cites": [], "rationale": "ghép nối"})
    ctx.extra["gateway"] = gw
    out = integrate({"modules": ["mod_app", "mod_i2c"]}, ctx)
    assert out["init_order"] == ["mod_i2c", "mod_app"]
    assert "mod_i2c → mod_app" in gw.de_bai


def test_integrate_xung_dot_tai_nguyen_thi_hoi_TRUOC_khi_goi_mo_hinh(du_an):
    """Sinh mã glue cho hai module cùng đòi một chân rồi mới phát hiện là tiêu một lượt gọi để
    tạo ra thứ chắc chắn phải bỏ đi."""
    from eide.caps.code import integrate
    from eide_core.errors import EideError

    _, ctx, root = du_an
    _module(root, "mod_a", resource="chip:x/periph:I2C1")
    _module(root, "mod_b", resource="chip:x/periph:I2C1")
    gw = _GW(_cp())
    ctx.extra["gateway"] = gw
    with pytest.raises(EideError) as e:
        integrate({"modules": ["mod_a", "mod_b"]}, ctx)
    assert e.value.code == "E3000" and e.value.data["rule"] == "CODE-03"
    assert e.value.data["conflicts"][0]["modules"] == ["mod_a", "mod_b"]
    assert gw.de_bai is None, "đã gọi mô hình dù đã biết là xung đột"


def test_integrate_chu_ky_giao_dien_da_chot_vao_de_bai(du_an):
    from eide.caps.code import integrate

    _, ctx, root = du_an
    _module(root, "mod_i2c", interfaces=[{"sig": "int i2c_init(uint32_t hz);"}])
    gw = _GW({"files": [{"path": "src/main.c", "content": "int main(void){return 0;}\n"}],
              "cites": [], "rationale": "x"})
    ctx.extra["gateway"] = gw
    integrate({"modules": ["mod_i2c"]}, ctx)
    assert "int i2c_init(uint32_t hz);" in gw.de_bai


# ---------- CODE-10 self_repair

def test_self_repair_vong_4_thi_give_up_va_ghi_error_ledger(du_an):
    """tc: "lỗi thiết kế → give_up ở vòng 3". Một mô hình sửa mãi không dừng sẽ tiêu hết ngân
    sách đi vòng quanh cùng một lỗi thiết kế — và mỗi vòng lại trông như có tiến triển vì thông
    điệp lỗi đổi."""
    from eide.caps.code import self_repair
    from eide_core import store as _s

    _, ctx, root = du_an
    rid = _bao_cao(root, "build", passed=False,
                   metrics={"error_kind": "link", "error_lines": ["undefined reference"]})
    gw = _GW(_cp())
    ctx.extra["gateway"] = gw
    out = self_repair({"report_id": rid, "patch": _cp(), "round": 4}, ctx)
    assert out["give_up"] is True and gw.de_bai is None, "give_up mà vẫn gọi mô hình"
    with _s.open_store(_s.store_path(root)) as c:
        rows = c.execute("SELECT kind, negative_prompt FROM error_ledger").fetchall()
    assert rows and rows[0][0] == "link" and "thiết kế" in rows[0][1]


def test_self_repair_trong_han_thi_sinh_patch_moi(du_an):
    from eide.caps.code import self_repair

    _, ctx, root = du_an
    rid = _bao_cao(root, "build", passed=False,
                   metrics={"error_kind": "compile",
                            "error_lines": ["src/a.c:3:1: error: expected ';'"]})
    gw = _GW(_cp("int f(void){ return 0; }\n"))
    ctx.extra["gateway"] = gw
    out = self_repair({"report_id": rid, "patch": _cp(), "round": 1}, ctx)
    assert out["give_up"] is False and out["patch"]["id"].startswith("patch_")
    assert "Vòng tự sửa 1/3" in gw.de_bai


def test_C6_la_loi_DA_LOC_khong_phai_ca_nhat_ky(du_an):
    """Một bản dựng hỏng in ra hàng trăm dòng, trong đó lỗi thật là hai dòng đầu và phần còn
    lại là hệ quả; đưa hết vào ngữ cảnh thì mô hình đi sửa hệ quả."""
    from eide.caps.code import _tom_tat_loi

    tom = _tom_tat_loi({"tool": "static", "metrics": {"findings": [
        {"file": "src/a.c", "line": 9, "rule": "no_malloc", "message": "cấp phát động"}]}})
    assert "no_malloc" in tom and "src/a.c:9" in tom
    tom2 = _tom_tat_loi({"tool": "test_host", "metrics": {"cases": [
        {"file": "tests/host/test_a.c", "status": "failed", "exit_code": 1},
        {"file": "tests/host/test_b.c", "status": "passed", "exit_code": 0}]}})
    assert "test_a.c" in tom2 and "test_b.c" not in tom2, "ca ĐẠT không được vào C6"


def test_self_repair_report_khong_co_thi_bao_ro(du_an):
    from eide.caps.code import self_repair
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    ctx.extra["gateway"] = _GW(_cp())
    with pytest.raises(EideError) as e:
        self_repair({"report_id": "tr_khong_co", "patch": {}, "round": 1}, ctx)
    assert e.value.code == "E2000"


def test_bon_nang_luc_sinh_deu_di_qua_constant_guard(du_an):
    """Bốn bản sao của cùng ba phép kiểm là bốn chỗ để quên một phép, và cái bị quên sẽ là
    `constant_guard`: nó là phép duy nhất mà bỏ đi thì mọi test khác vẫn xanh."""
    from eide.caps.code import integrate, modify, self_repair
    from eide_core.errors import EideError

    _, ctx, root = du_an
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "a.c").write_text("int f(void){return 0;}\n", encoding="utf-8")
    ban = _cp("#define A 0x76\n", path="src/a.c")
    rid = _bao_cao(root, "build", passed=False, metrics={})
    _module(root, "mod_x")

    for goi in (lambda: modify({"file": "src/a.c", "intent": "x"}, ctx),
                lambda: integrate({"modules": ["mod_x"]}, ctx),
                lambda: self_repair({"report_id": rid, "patch": {}, "round": 1}, ctx)):
        ctx.extra["gateway"] = _GW(ban)
        with pytest.raises(EideError) as e:
            goi()
        assert e.value.code == "E5003", goi


# ---------- CODE-14 annotate: chiều ngược của constant_guard

def _fact_duyet(root, fid: str, subject: str, predicate: str, value, status="verified") -> None:
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s_ann", "u", hashlib.sha256(b"s_ann").hexdigest(), "svd", "gold",
                   "vendor-doc"))
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, subject, predicate, json.dumps(value), "s_ann", "parser", "gold",
                   1.0, status, "A"))
        c.commit()


def _viet(root, ten: str, noi_dung: str) -> str:
    (root / "src").mkdir(parents=True, exist_ok=True)
    (root / "src" / ten).write_text(noi_dung, encoding="utf-8")
    return f"src/{ten}"


def test_annotate_tc_dia_chi_ra_dung_fact(du_an):
    """tc CODE-14 nguyên văn: "0x40005400 → f_1a2b"."""
    from eide.caps.code import annotate

    _, ctx, root = du_an
    _fact_duyet(root, "f_1a2b0000000000", "chip:st.stm32f411/periph:I2C1", "base_address",
                "0x40005400")
    f = _viet(root, "a.c", "#define I2C1_BASE 0x40005400\n")
    g = annotate({"file": f}, ctx)["suggestions"]
    assert len(g) == 1
    assert g[0]["fact_id"] == "f_1a2b0000000000" and g[0]["line"] == 1
    assert g[0]["annotation"] == "/* eide:fact f_1a2b0000000000 */"


def test_annotate_khop_TEN_thi_tin_hon_khop_moi_gia_tri(du_an):
    """Một địa chỉ `0x40` khớp giá trị với hàng chục fact trong cùng một chip; chỉ khi TÊN trong
    mã cũng chạm vào subject thì gợi ý mới gần như chắc chắn."""
    from eide.caps.code import annotate

    _, ctx, root = du_an
    _fact_duyet(root, "f_aa00000000000a", "chip:st.stm32f411/periph:I2C1", "base_address",
                "0x40005400")
    f = _viet(root, "b.c", "#define I2C1_BASE 0x40005400\n#define KHAC 0x40005400\n")
    g = annotate({"file": f}, ctx)["suggestions"]
    assert [s["confidence"] for s in g] == [0.95, 0.4], g
    assert g[0]["match"] == "gia_tri+ten" and g[1]["match"] == "gia_tri"


def test_annotate_bo_qua_dong_DA_co_chu_thich(du_an):
    """Gợi ý lại một dòng đã nối rồi là nhiễu — và nếu fact ta gợi ý khác fact đang có, người
    đọc sẽ tưởng có mâu thuẫn trong khi chỉ là ta chưa nhìn."""
    from eide.caps.code import annotate

    _, ctx, root = du_an
    _fact_duyet(root, "f_bb00000000000b", "chip:x/periph:I2C1", "base_address", "0x40005400")
    f = _viet(root, "c.c", "#define I2C1_BASE 0x40005400 /* eide:fact f_bb00000000000b */\n")
    assert annotate({"file": f}, ctx)["suggestions"] == []


def test_annotate_KHONG_goi_y_fact_chua_duyet(du_an):
    """Gợi ý một fact `normalized` là bảo người ta viết đúng dòng mà `constant_guard` sẽ chặn
    ngay lần sau."""
    from eide.caps.code import annotate

    _, ctx, root = du_an
    _fact_duyet(root, "f_cc00000000000c", "chip:x/periph:I2C1", "base_address", "0x40005400",
                status="normalized")
    f = _viet(root, "d.c", "#define I2C1_BASE 0x40005400\n")
    assert annotate({"file": f}, ctx)["suggestions"] == []


def test_annotate_KHONG_sua_tep(du_an):
    """Hợp đồng: "người/coder áp dụng qua code.modify". `undo: none` là hệ quả, không phải
    thiếu sót — tự chèn chú thích là thay người khẳng định con số ấy ĐÚNG LÀ fact kia."""
    from eide.caps.code import annotate

    _, ctx, root = du_an
    _fact_duyet(root, "f_dd00000000000d", "chip:x/periph:I2C1", "base_address", "0x40005400")
    f = _viet(root, "e.c", goc := "#define I2C1_BASE 0x40005400\n")
    annotate({"file": f}, ctx)
    assert (root / f).read_text(encoding="utf-8") == goc


# ---- placeholder trong build.cmd (DEV-104, 14/09/2026)


def test_build_cmd_giai_placeholder_cua_manifest(tmp_path):
    """`make -C . MCU={mcu} F_CPU={f_cpu}` phải thành giá trị thật của dự án.

    TGT-19 dùng placeholder xuyên suốt — `flash.cmd`, `id_read.cmd`, `sim.cmd` đều có, và mỗi
    chỗ dùng đều tự giải. `build.cmd` là chỗ duy nhất chạy chuỗi NGUYÊN VĂN, nên `avr8` truyền
    cho `make` một biến `MCU` mang đúng bảy ký tự `{mcu}`. Không ai thấy vì `armv7e-m` và
    `rv32imac` viết lệnh cmake không placeholder, và chưa ai dựng AVR bao giờ.
    """
    import yaml

    from eide.caps.code import _giai_placeholder
    from eide.caps.project import EIDE_DIR

    (tmp_path / EIDE_DIR).mkdir(parents=True)
    (tmp_path / EIDE_DIR / "constraints.yaml").write_text(yaml.safe_dump(
        {"target": {"chip": "microchip.atmega328p@1.0.0", "board": "arduino-uno",
                    "isa": "avr8", "f_cpu": 16000000}}), encoding="utf-8")

    ra = _giai_placeholder("make -C . MCU={mcu} F_CPU={f_cpu}", tmp_path, "avr8")
    assert ra == "make -C . MCU=atmega328p F_CPU=16000000"


def test_thieu_gia_tri_thi_dung_chu_khong_doan(tmp_path):
    """Arduino Uno chạy 16 MHz và ai cũng biết — nhưng không fact nào trong dự án nói thế.

    Điền theo trí nhớ là gieo một hằng số không nguồn vào tận dòng lệnh dựng, nơi không cổng nào
    của EIDE còn nhìn thấy nó. Và sai `F_CPU` thì UART ra ký tự rác trong khi mọi thứ khác trông
    vẫn đúng — đúng lớp lỗi mà cả tầng tri thức sinh ra để chặn.
    """
    import yaml

    from eide.caps.code import _giai_placeholder
    from eide.caps.project import EIDE_DIR

    (tmp_path / EIDE_DIR).mkdir(parents=True)
    (tmp_path / EIDE_DIR / "constraints.yaml").write_text(yaml.safe_dump(
        {"target": {"chip": "microchip.atmega328p", "isa": "avr8"}}), encoding="utf-8")

    from eide_core.errors import EideError

    with pytest.raises(EideError) as e:
        _giai_placeholder("make MCU={mcu} F_CPU={f_cpu}", tmp_path, "avr8")
    assert e.value.code == "E2000"
    assert e.value.data["missing"] == ["target.f_cpu"], "phải nói THIẾU CÁI GÌ"
    assert "mcu" in e.value.data["exists"], "và nói cái gì đã có, để người biết còn thiếu mỗi một"


def test_lenh_khong_placeholder_di_qua_nguyen_ven(tmp_path):
    """`armv7e-m` và `rv32imac` viết lệnh cmake không placeholder — không được đụng vào chúng."""
    import yaml

    from eide.caps.code import _giai_placeholder
    from eide.caps.project import EIDE_DIR

    (tmp_path / EIDE_DIR).mkdir(parents=True)
    (tmp_path / EIDE_DIR / "constraints.yaml").write_text(yaml.safe_dump(
        {"target": {"chip": "espressif.esp32c3", "isa": "rv32imac"}}), encoding="utf-8")

    cmd = "cmake -S . -B build && cmake --build build"
    assert _giai_placeholder(cmd, tmp_path, "rv32imac") == cmd
