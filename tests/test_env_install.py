"""ENV-03 `env.install` + ENV-04 `env.guide_install` — CDS-12.3; TGT-19; POL-17 G-OPS-04/05;
SEC-25 §2/§5. Kèm hồi quy cho lỗi quyền ghi của sandbox tìm ra trong lúc làm ENV-03.
"""
from __future__ import annotations

import os
import platform
import shutil
import stat
from pathlib import Path

import pytest

from eide.caps.env import (
    CONG_CU_DONG,
    TRINH_QUAN_LY,
    dac_trung_cai,
    guide_install,
    install,
)
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from eide_core.sandbox import Sandbox

# --------------------------------------------------------------------- hồi quy sandbox

@pytest.mark.skipif(platform.system() != "Darwin", reason="hồ sơ sandbox-exec chỉ có trên macOS")
def test_sandbox_ghi_duoc_vao_thu_muc_lam_viec(tmp_path):
    """SEC-25 §2 nói tiến trình trong sandbox GHI ĐƯỢC vào thư mục làm việc tạm của nó.

    Trước 08/09/2026 thì không: hồ sơ `sandbox-exec` ghi `(subpath "/var/folders/…")` trong khi
    `subpath` so khớp trên đường dẫn đã giải liên kết mềm (`/private/var/folders/…`), nên với
    mọi `out_dir` nằm dưới thư mục tạm — tức mọi test — sandbox không ghi được vào đâu cả, kể cả
    `./a.txt`. Không test nào thấy vì chưa test nào GHI: tất cả chỉ xem mã thoát của lệnh
    chỉ-đọc.
    """
    kq = Sandbox(out_dir=tmp_path / "sb").run(
        ["/bin/sh", "-c", "echo xin_chao > ./a.txt && cat ./a.txt"], limits={"timeout_s": 30})
    assert kq.exit_code == 0, Path(kq.stderr_ref).read_text(encoding="utf-8")
    assert "xin_chao" in Path(kq.stdout_ref).read_text(encoding="utf-8")


@pytest.mark.skipif(platform.system() != "Darwin", reason="hồ sơ sandbox-exec chỉ có trên macOS")
def test_sandbox_home_ghi_duoc(tmp_path):
    """`$HOME` phải là thư mục ghi được, và nó nằm NGOÀI `cwd` — `brew` tạo `$HOME/Library` ngay
    đầu mỗi lệnh, nên đây là thứ quyết định lệnh cài chạy hay hỏng.

    Tên thư mục thử phải DUY NHẤT mỗi lần chạy. Bản đầu dùng thẳng `$HOME/Library`: nó tồn tại
    sẵn từ lần chạy trước nên `mkdir -p` trả 0 mà không cần quyền ghi nào, và test xanh kể cả
    khi hồ sơ sandbox chặn sạch — một test có trạng thái là một test tự nói dối.
    """
    kq = Sandbox(out_dir=tmp_path / "sb").run(
        ["/bin/sh", "-c", 'd="$HOME/probe-$$-'f'{os.getpid()}"'"; mkdir \"$d\" && echo home_ok"],
        limits={"timeout_s": 30})
    assert kq.exit_code == 0, Path(kq.stderr_ref).read_text(encoding="utf-8")


@pytest.mark.skipif(platform.system() != "Darwin", reason="hồ sơ sandbox-exec chỉ có trên macOS")
def test_sandbox_ghi_duoc_khi_out_dir_qua_lien_ket_mem(tmp_path):
    """Cùng lỗi ấy, ở dạng còn lại: `out_dir` KHÔNG nằm dưới thư mục tạm, nhưng đi qua một liên
    kết mềm. Đây là hình dạng thật trên máy người dùng — `.eide/cache/sandbox` của một dự án nằm
    dưới thư mục nhà, và thư mục nhà có thể là liên kết mềm (`/tmp` → `/private/tmp` trên macOS,
    hoặc một `~/Documents` được đưa lên iCloud).

    Gốc thử nằm trong kho mã chứ không trong `tmp_path`: SEC-25 §2 mở quyền ghi cho cả thư mục
    tạm, nên một đường dẫn dưới `tmp_path` được luật ấy che và không kiểm được luật `cwd`.
    """
    goc = Path(__file__).resolve().parent / ".probe-sandbox-dir"
    shutil.rmtree(goc, ignore_errors=True)
    that = goc / "that"
    that.mkdir(parents=True)
    lien_ket = goc / "lien-ket"
    lien_ket.symlink_to(that)
    try:
        kq = Sandbox(out_dir=lien_ket / "sb").run(
            ["/bin/sh", "-c", "echo qua_lien_ket > ./a.txt && cat ./a.txt"], limits={"timeout_s": 30})
        assert kq.exit_code == 0, Path(kq.stderr_ref).read_text(encoding="utf-8")
        assert "qua_lien_ket" in Path(kq.stdout_ref).read_text(encoding="utf-8")
    finally:
        shutil.rmtree(goc, ignore_errors=True)


@pytest.mark.skipif(platform.system() != "Darwin", reason="hồ sơ sandbox-exec chỉ có trên macOS")
def test_sandbox_van_chan_ghi_ngoai_vung(tmp_path):
    """Đối chứng của hai test trên: nới quyền ghi cho `cwd` KHÔNG được nới cho cả máy.

    Đích thử nằm trong chính kho mã, không nằm dưới thư mục tạm: SEC-25 §2 cho ghi cả `/tmp`,
    nên một đích trong `tmp_path` không chứng minh được gì.
    """
    ngoai = Path(__file__).resolve().parent / ".probe-sandbox.tmp"
    ngoai.unlink(missing_ok=True)
    kq = Sandbox(out_dir=tmp_path / "sb").run(
        ["/bin/sh", "-c", f"echo x > {ngoai}"], limits={"timeout_s": 30})
    ton_tai = ngoai.exists()
    ngoai.unlink(missing_ok=True)
    assert kq.exit_code != 0 and not ton_tai


# --------------------------------------------------------------------- cổng G-OPS

def test_dac_trung_cai_du_cho_G_OPS_05():
    """Đặc trưng phải phủ đúng `features` mà G-OPS-04/05 khai — thiếu một khóa là rơi G-OPS-99."""
    d = dac_trung_cai({"tool": "renode"})
    assert d == {"op": "install", "package": "renode", "needs_sudo": False}
    assert dac_trung_cai({"tool": "x"}, needs_sudo=True)["needs_sudo"] is True


def test_install_goi_tin_cay_van_hoi_nguoi(tmp_path):
    """`renode` NẰM TRONG `trusted_packages` và `G-OPS-04` là quy tắc APPROVE — nhưng APD-08 §2
    đặt ngưỡng cứng "mọi R4 luôn hỏi người" ở tầng trước quy tắc cổng, nên vẫn `pending`.

    Test này ghim thực tế ấy chứ không ghim mong muốn: ngày nào chủ sản phẩm quyết cho danh sách
    trắng thắng ngưỡng cứng (DEV-060), test này đỏ và đó đúng là lúc cần đọc lại nó.
    """
    gate = PolicyGate()
    r = Router(gate=gate, ledger=Ledger(tmp_path / "l.jsonl"))
    ctx = Context(project_dir=tmp_path, extra={"gate": gate})
    run = r.invoke("env.install", {"tool": "renode"}, ctx, features=dac_trung_cai({"tool": "renode"}))
    assert run.status == "pending"
    assert "renode" in str(gate.config["trusted_packages"])


def test_install_goi_la_bi_hoi_kem_ly_do_cu_the(tmp_path):
    """Gói lạ phải mượn lý do của `G-OPS-05` (ưu tiên 5, trong dải chặn) chứ không phải câu
    chung "Mặc định" — người duyệt cần đọc được ĐIỀU GÌ sắp xảy ra, không chỉ lớp rủi ro."""
    gate = PolicyGate()
    d = gate.decide("G-OPS", dac_trung_cai({"tool": "mot-goi-la-hoac"}), risk="R4", tier="T1")
    assert d.decision == "ASK" and d.rule_id == "G-OPS-05"


# --------------------------------------------------------------------- ENV-03

def test_install_cong_cu_dong_tra_E4001_kem_loi_ra(tmp_path):
    """`ask_when` của ENV-03 nêu "toolchain đóng". Cổng hỏi người là đúng, nhưng kể cả khi được
    duyệt thì EIDE vẫn không cài được — nên phải nói thẳng và chỉ sang ENV-04."""
    with pytest.raises(EideError) as e:
        install({"tool": "XC8"}, Context(project_dir=tmp_path))
    assert e.value.code == "E4001"
    assert e.value.data["alternative"] == "env.guide_install"
    assert "microchip.com" in e.value.data["link"]


def test_install_khong_co_trinh_quan_ly_goi_ten_da_thu(tmp_path, monkeypatch):
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    with pytest.raises(EideError) as e:
        install({"tool": "renode"}, Context(project_dir=tmp_path))
    assert e.value.code == "E4001"
    assert e.value.data["tried"] == [m for m, _ in TRINH_QUAN_LY[
        {"Darwin": "macos", "Windows": "windows", "Linux": "linux"}[platform.system()]]]


def _shim(thu_muc: Path, ten: str, than: str) -> Path:
    """Tạo một tệp thực thi giả trong `thu_muc`."""
    thu_muc.mkdir(parents=True, exist_ok=True)
    f = thu_muc / ten
    f.write_text(f"#!/bin/sh\n{than}\n", encoding="utf-8")
    f.chmod(f.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    return f


@pytest.fixture
def bin_gia(tmp_path, monkeypatch):
    """Thư mục `bin` giả đứng đầu PATH, để `tools.which` thấy trước brew/apt thật của máy."""
    d = tmp_path / "bin"
    d.mkdir()
    monkeypatch.setenv("PATH", f"{d}{os.pathsep}{os.environ['PATH']}")
    return d


def _ten_mgr() -> str:
    return TRINH_QUAN_LY[{"Darwin": "macos", "Windows": "windows",
                          "Linux": "linux"}[platform.system()]][0][0]


def test_install_thanh_cong_ghi_lock_va_tool_report(tmp_path, bin_gia, workspace):
    """Đường thành công đầy đủ: chạy trình quản lý gói → `which` thấy công cụ → ToolReport +
    `tools.lock`. Trình cài giả không cài gì thật; thứ đang kiểm là phần ghi sổ."""
    _shim(bin_gia, _ten_mgr(), "exit 0")
    _shim(bin_gia, "cong-cu-gia", "echo v9.9")

    du_an = workspace / "d"
    (du_an / ".eide").mkdir(parents=True)
    ctx = Context(project_dir=du_an)
    rep = install({"tool": "cong-cu-gia"}, ctx)["report"]

    assert rep["passed"] is True and rep["tool"] == "install"
    assert rep["metrics"]["package"] == "cong-cu-gia" and rep["metrics"]["exit_code"] == 0
    assert rep["metrics"]["found"].endswith("cong-cu-gia")

    import yaml
    khoa = yaml.safe_load((du_an / ".eide" / "tools.lock").read_text(encoding="utf-8"))
    ghi = [t for t in khoa["tools"] if t["tool"] == "cong-cu-gia"]
    assert ghi and ghi[0]["installed_by"] == "env.install"


def test_install_ma_thoat_khac_0_tra_E4000(tmp_path, bin_gia):
    _shim(bin_gia, _ten_mgr(), "echo 'khong tim thay cong thuc' >&2; exit 3")
    with pytest.raises(EideError) as e:
        install({"tool": "cong-cu-khong-co"}, Context(project_dir=tmp_path))
    assert e.value.code == "E4000" and e.value.data["exit_code"] == 3


def test_install_ma_thoat_0_nhung_khong_goi_duoc_van_la_that_bai(tmp_path, bin_gia):
    """Trình quản lý gói trả 0 KHÔNG có nghĩa là công cụ dùng được — nó có thể cài vào một tiền
    tố ngoài PATH. Báo "đã cài" cho một thứ gọi không được là tệ hơn báo lỗi."""
    _shim(bin_gia, _ten_mgr(), "exit 0")            # thành công, nhưng không tạo ra công cụ nào
    with pytest.raises(EideError) as e:
        install({"tool": "cong-cu-khong-ton-tai-o-dau-ca"}, Context(project_dir=tmp_path))
    assert e.value.code == "E4000" and e.value.data["exit_code"] == 0
    assert "ngoài PATH" in str(e.value)


def test_install_khong_ghim_duoc_ban_thi_bao_chu_khong_cai_ban_khac(tmp_path, bin_gia,
                                                                     monkeypatch):
    """Xin `renode@1.14` mà nhận bản mới nhất là dựng ra một môi trường không lặp lại được, và
    không ai biết cho tới lúc kết quả lệch. Thà báo lỗi."""
    monkeypatch.setattr("eide.caps.env.TRINH_QUAN_LY",
                        {k: [("pipx", ["pipx", "install", "{pkg}"])] for k in TRINH_QUAN_LY})
    _shim(bin_gia, "pipx", "exit 0")
    with pytest.raises(EideError) as e:
        install({"tool": "renode", "version": "1.14"}, Context(project_dir=tmp_path))
    assert e.value.code == "E4001" and e.value.data["version"] == "1.14"


def test_install_khong_dung_sudo_o_bat_ky_lenh_nao():
    """SEC-25 §2: EIDE không tự nâng quyền. Kiểm cả bảng chứ không kiểm một nhánh."""
    for os_key, ds in TRINH_QUAN_LY.items():
        for ten, mau in ds:
            assert "sudo" not in mau, f"{os_key}/{ten} có sudo trong lệnh cài"


def test_install_khong_tin_danh_sach_trang_chua_ky(tmp_path, bin_gia):
    """Danh sách trắng chỉ có giá trị khi niêm `defaults.sig` còn đạt — đọc thẳng YAML mà bỏ qua
    chữ ký thì ai sửa được tệp là tự cho mình quyền cài gói."""
    _shim(bin_gia, _ten_mgr(), "exit 0")
    _shim(bin_gia, "renode", "echo v1")

    class GateHong:
        danh_sach_da_ky = False
        config = {"trusted_packages": ["renode"]}

    rep = install({"tool": "renode"}, Context(project_dir=tmp_path, extra={"gate": GateHong()}))
    assert rep["report"]["metrics"]["trusted"] is False


# --------------------------------------------------------------------- ENV-04

def test_guide_install_cong_cu_dong_co_buoc_va_link_chinh_hang():
    """tc của ENV-04: "Có bước và link chính hãng"."""
    kq = guide_install({"tool": "iar"}, Context())
    assert len(kq["steps"]) >= 3 and kq["links"] == ["https://www.iar.com/products/architectures/"]
    assert any("license" in b for b in kq["steps"])


def test_guide_install_moi_cong_cu_dong_deu_co_link_hang():
    """Không cái nào trỏ mirror hay bản đóng gói lại: một trình dịch tải từ nguồn thứ ba là một
    trình dịch không ai bảo đảm nội dung, mà nó sinh ra firmware chạy trên thiết bị thật."""
    hang = ("microchip.com", "iar.com", "keil.com")
    for ten in CONG_CU_DONG:
        links = guide_install({"tool": ten}, Context())["links"]
        assert links and any(h in links[0] for h in hang), ten


def test_guide_install_lay_lenh_tu_manifest_isa_khong_chep_tay():
    """`arm-none-eabi-gcc` không phải công cụ đóng, nhưng manifest ISA đã có sẵn lệnh cài —
    nguồn duy nhất. Chép bảng lệnh sang mã thì có hai bản, và bản trong mã là bản không ai sinh
    lại (cùng lỗi với PRED_W/DEV-043)."""
    import yaml

    from eide_core.paths import spec_dir
    man = yaml.safe_load((spec_dir() / "isa" / "armv7e-m.yaml").read_text(encoding="utf-8"))
    os_key = {"Darwin": "macos", "Windows": "windows", "Linux": "linux"}[platform.system()]
    mong = (man["toolchain"].get("install") or {})[os_key]

    steps = guide_install({"tool": "arm-none-eabi-gcc"}, Context())["steps"]
    for lenh in mong:
        assert any(lenh in b for b in steps), lenh


def test_guide_install_cong_cu_la_khong_bia_link():
    kq = guide_install({"tool": "mot-cong-cu-khong-ai-biet"}, Context())
    assert kq["links"] == [] and kq["steps"]


def test_guide_install_khong_bi_cong_hoi_vi_la_R0_T3(tmp_path):
    """ENV-04 là R0/T3 — hướng dẫn thì không đụng vào máy, nên phải chạy thẳng."""
    gate = PolicyGate()
    r = Router(gate=gate, ledger=Ledger(tmp_path / "l.jsonl"))
    run = r.invoke("env.guide_install", {"tool": "xc8"}, Context(extra={"gate": gate}))
    assert run.status == "done" and run.result["links"]
