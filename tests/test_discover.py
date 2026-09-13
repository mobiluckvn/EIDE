"""discover.* + target.detect — DISCOVER-01/10/11/12, TARGET-01; TGT-19 §4.

Đọc: CDS-12.3 (hợp đồng bốn năng lực), TGT-19 §4 (bảng VID/PID), POL-17 §3 (`boards` lab),
PLATFORM.md (mã riêng nền tảng).

## Vì sao bộ test này kiểm "trả rỗng" nhiều đến thế

Nhóm `discover.*` chạy trên một máy **không cắm gì cả**, và trong tình huống ấy câu trả lời
đúng là một danh sách rỗng — không phải một lỗi. Phần lớn giá trị của nhóm nằm ở chỗ nó phân
biệt được ba thứ mà một hiện thực cẩu thả sẽ gộp lại: *không có cổng nào*, *có cổng nhưng
không có quyền*, và *nền tảng này không kiểm được*. Ba tình huống, ba việc người dùng phải làm
khác nhau.
"""
from __future__ import annotations

import json

import pytest
import yaml

from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def rt(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl")), Context()


# ---------------------------------------------------------------- bảng VID/PID


def test_bang_probe_sinh_tu_tai_lieu_khong_chep_tay():
    """TGT-19 §4 phải có bản máy đọc được, và nó phải nói rõ mình sinh từ đâu.

    Bài học DEV-043/DEV-046 (mắc hai lần): một bảng chép tay trong mã là bản thứ hai để trôi
    khỏi tài liệu, và không ai thấy lúc nó trôi.
    """
    f = spec_dir() / "isa" / "probes.yaml"
    assert f.exists(), "TGT-19 §4 chưa có bản máy đọc được"
    van = f.read_text(encoding="utf-8")
    assert "KHÔNG sửa tay" in van and "tgt_sim.js" in van, "thiếu dòng nói rõ nguồn sinh"

    ds = yaml.safe_load(van)["probes"]
    assert len(ds) >= 10, f"bảng §4 có 11 dòng, spec chỉ thấy {len(ds)}"
    for p in ds:
        assert {"id", "name", "usb", "kind"} <= set(p), p
        for u in p["usb"]:
            assert len(u) == 9 and u[4] == ":", f"VID:PID phải dạng XXXX:XXXX — {u}"


def test_khop_probe_theo_vid_pid_that():
    """ST-Link V2 = 0483:3748 (TGT-19 §4 dòng 1). Nếu bảng đổi, test này đỏ trước khi một
    người dùng cắm ST-Link vào và thấy nó hiện ra là "serial lạ"."""
    from eide.caps.discover import _khop_probe

    st = _khop_probe("0483", "3748")
    assert st is not None and st["id"] == "stlink-v2"
    assert "probe-rs" in st["tools"]

    # V2-1 có BỐN PID; chọn một cái ở giữa để chắc là đọc cả danh sách, không chỉ cái đầu.
    assert (_khop_probe("0483", "374F") or {}).get("id") == "stlink-v2-1"
    assert _khop_probe("FFFF", "FFFF") is None, "VID lạ phải trả None, không đoán bừa"
    assert _khop_probe("", "") is None


# ---------------------------------------------------------------- discover.ports


def test_ports_chay_duoc_tren_may_khong_co_board(rt):
    """DISCOVER-01: `{}` → `{ports[]}`. Máy không cắm gì thì rỗng, và rỗng là câu trả lời."""
    r, ctx = rt
    out = r.invoke("discover.ports", {}, ctx).result
    assert isinstance(out["ports"], list)
    for c in out["ports"]:
        assert {"dev", "vid", "pid", "kind"} <= set(c), c


def test_ports_phan_biet_ba_trang_thai_cua_driver_ok(monkeypatch):
    """`driver_ok` có ba giá trị, không phải hai: mở được / KHÔNG CÓ QUYỀN / không kiểm được.

    Thiếu nhóm `dialout` trên Linux là lỗi phổ biến nhất của người mới, và nó trông y hệt "không
    có board" nếu ba trạng thái ấy bị gộp.
    """
    from eide.caps import discover

    monkeypatch.setattr(discover, "_cong_pyserial", lambda: [
        {"dev": "/dev/ttyUSB0", "vid": "0483", "pid": "3748", "product": "", "serial": ""},
    ])
    monkeypatch.setattr(discover.os, "access", lambda *a: False)
    ds = discover._liet_ke_cong()
    assert ds[0]["driver_ok"] is False
    assert ds[0]["probe"] == "stlink-v2", "VID/PID biết rồi thì phải nói ra đó là probe gì"
    assert ds[0]["kind"] == "swd"

    # Windows không kiểm được quyền theo kiểu POSIX → None, KHÔNG phải True.
    monkeypatch.setattr(discover.tools, "os_name", lambda: "Windows")
    assert discover._quyen_mo("COM3") is None


def test_ports_loc_cong_ao_cua_macos():
    """`Bluetooth-Incoming-Port` luôn có trên mọi máy Mac. Một danh sách mở đầu bằng nó khiến
    người dùng tưởng board đã hiện ra."""
    from eide.caps.discover import BO_QUA_MAC

    assert BO_QUA_MAC.search("/dev/cu.Bluetooth-Incoming-Port")
    assert BO_QUA_MAC.search("/dev/cu.debug-console")
    assert not BO_QUA_MAC.search("/dev/cu.usbmodem14203"), "cổng thật không được lọc"


# ---------------------------------------------------------------- env.detect


def test_env_detect_tra_cong_that_khong_phai_mang_rong(rt):
    """ENV-01 `steps`: "platform + discover.ports/probe".

    Bản Sprint 1 trả `ports: []` cứng — màn Môi trường hiện "không thấy cổng nào" trên một máy
    đang cắm ba cổng. Một khẳng định về thế giới, phát ra từ chỗ chưa nhìn.
    """
    from eide.caps.discover import _liet_ke_cong

    r, ctx = rt
    env = r.invoke("env.detect", {}, ctx).result["env"]
    assert env["ports"] == _liet_ke_cong(), "env.detect phải hỏi discover.ports, không tự trả rỗng"
    assert env["probes"] == [], "probes vẫn rỗng cho tới khi discover.probe có mặt (M2)"


# ---------------------------------------------------------------- discover.env_hw


def test_env_hw_de_xuat_lenh_sua_chu_khong_chay(rt, monkeypatch):
    """DISCOVER-11 là R0 với `ask_when: "Cài driver (R2)"` — nó chỉ ĐỀ NGHỊ.

    `fixes[]` chứa lệnh có `sudo`, và SEC-25 §2 cấm EIDE chạy `sudo` trong mọi trường hợp. Nên
    chúng phải là chuỗi để người đọc, không phải lệnh được thi hành.
    """
    from eide.caps import discover

    monkeypatch.setattr(discover.tools, "os_name", lambda: "Linux")
    monkeypatch.setattr(discover, "_cong_pyserial", lambda: [
        {"dev": "/dev/ttyUSB0", "vid": "1A86", "pid": "7523", "product": "", "serial": ""},
    ])
    monkeypatch.setattr(discover.os, "access", lambda *a: False)

    r, ctx = rt
    bc = r.invoke("discover.env_hw", {}, ctx).result["report"]
    assert bc["permissions"], "cổng không mở được phải vào `permissions`"
    assert any("dialout" in f for f in bc["fixes"]), bc["fixes"]
    assert all(isinstance(f, str) for f in bc["fixes"]), "fixes là chuỗi gợi ý, không phải lệnh chạy"


def test_env_hw_noi_truoc_cong_cu_nap_con_thieu(rt):
    """Thiếu `probe-rs`/`openocd` không phải lỗi bây giờ, nhưng là lý do `target.flash` sẽ hỏng
    sau — nói trước rẻ hơn nhiều."""
    r, ctx = rt
    bc = r.invoke("discover.env_hw", {}, ctx).result["report"]
    ten = {m.get("cong_cu") for m in bc["drivers_missing"] if m.get("cong_cu")}
    assert ten, "máy này chưa có probe-rs/openocd/avrdude nào — phải nói ra"


# ---------------------------------------------------------------- discover.network


def test_network_chan_quet_ngoai_mang_lab(rt):
    """DISCOVER-10 `errors: [E3000]`, `ask_when: "Quét ngoài mạng lab"`.

    Quét một dải mạng lạ là hành vi của công cụ dò quét; một IDE tự làm điều đó trong mạng công
    ty là chuyện rất khác với việc nó tìm board của chính bạn.
    """
    r, ctx = rt
    run = r.invoke("discover.network", {"subnet": "10.0.0.0/8"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E3000"


def test_network_khong_co_cong_cu_mdns_thi_noi_ra(rt, monkeypatch):
    """Trả `devices: []` như thể đã quét, trong khi chưa quét được, là nói dối bằng im lặng."""
    from eide.caps import discover

    monkeypatch.setattr(discover.tools, "which", lambda n: None)
    r, ctx = rt
    run = r.invoke("discover.network", {}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4001"
    assert "mDNS" in run.error["message"]


# ---------------------------------------------------------------- discover.auto_setup


def test_auto_setup_khong_ghi_gi_khi_chua_biet_chip(rt, tmp_path):
    """DISCOVER-12 `errors: [E4003]`, `grounding: "Có ID chip khớp"`.

    `target.yaml` quyết định firmware được nạp bằng adapter nào lên con chip nào. Viết một cấu
    hình "gần đúng" cho một con chip chưa nhận diện được là cách nạp firmware họ F4 lên một F0.
    """
    r, ctx = rt
    ctx.project_dir = tmp_path
    (tmp_path / ".eide" / "discovery").mkdir(parents=True)
    (tmp_path / ".eide" / "discovery" / "dv_1.json").write_text(
        json.dumps({"ports": [{"dev": "/dev/cu.usbmodem1"}]}), encoding="utf-8")

    run = r.invoke("discover.auto_setup", {"discovery_id": "dv_1"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4003"
    assert not (tmp_path / ".eide" / "target.yaml").exists(), "KHÔNG được ghi khi chưa biết chip"


def test_auto_setup_ghi_target_yaml_va_sao_luu_ban_cu(rt, tmp_path):
    """`undo: restore_config` cần một bản cũ để quay về — sao lưu TRƯỚC khi ghi."""
    r, ctx = rt
    ctx.project_dir = tmp_path
    d = tmp_path / ".eide" / "discovery"
    d.mkdir(parents=True)
    (d / "dv_2.json").write_text(json.dumps({
        "chip_id": {"part": "STM32F411CE"},
        "ports": [{"dev": "/dev/cu.usbmodem1"}],
        "probes": [{"id": "stlink-v2", "kind": "swd"}],
    }), encoding="utf-8")
    cu = tmp_path / ".eide" / "target.yaml"
    cu.write_text("chip: CŨ\n", encoding="utf-8")

    out = r.invoke("discover.auto_setup", {"discovery_id": "dv_2"}, ctx).result
    assert out["target_config"]["chip"] == "STM32F411CE"
    assert out["target_config"]["isa"] == "armv7e-m", "family_patterns của TGT-19 §2"
    assert out["target_config"]["adapter"] == "probe-rs"
    assert out["path"].endswith("target.yaml")
    assert (tmp_path / ".eide" / "target.yaml.bak").read_text().strip() == "chip: CŨ"


def test_auto_setup_chip_khong_isa_nao_nhan_thi_E4003(rt, tmp_path):
    r, ctx = rt
    ctx.project_dir = tmp_path
    d = tmp_path / ".eide" / "discovery"
    d.mkdir(parents=True)
    (d / "dv_3.json").write_text(json.dumps({"chip_id": {"part": "MOT-CON-CHIP-LA"}}),
                                 encoding="utf-8")
    run = r.invoke("discover.auto_setup", {"discovery_id": "dv_3"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4003"


# ---------------------------------------------------------------- target.detect


def test_target_detect_khong_doan_chip_tu_vid_pid(rt, monkeypatch):
    """TARGET-01: `chip_id` để trống cho tới khi `discover.chip_id` có mặt.

    Một cổng với VID `0483` gần như chắc chắn là board ST — nhưng "gần như chắc chắn" ở đây
    nghĩa là nạp firmware họ F4 lên một con F0 khi đoán trượt.
    """
    from eide.caps import discover

    monkeypatch.setattr(discover, "_cong_pyserial", lambda: [
        {"dev": "/dev/ttyACM0", "vid": "0483", "pid": "374B", "product": "", "serial": "SN1"},
    ])
    r, ctx = rt
    ds = r.invoke("target.detect", {}, ctx).result["targets"]
    assert ds[0]["chip_id"] is None, "không được đoán chip từ VID/PID"
    assert ds[0]["probe"] == "stlink-v2-1"
    assert ds[0]["lab"] is False, "chưa khai trong danh sách lab thì KHÔNG được tự nạp"


def test_target_detect_lab_chi_tu_danh_sach_da_ky(rt, monkeypatch):
    """POL-17 §3: board lab mới được tự nạp, và danh sách ấy nằm trong tệp ĐÃ KÝ.

    Một thiết bị vừa cắm vào không thể tự nhận mình là lab — nếu được thế thì cả cơ chế chữ ký
    chẳng bảo vệ điều gì.
    """
    from eide.caps import discover, target

    monkeypatch.setattr(discover, "_cong_pyserial", lambda: [
        {"dev": "/dev/ttyACM0", "vid": "0483", "pid": "374B", "product": "", "serial": "SN9"},
    ])
    monkeypatch.setattr(target, "_boards_lab",
                        lambda: {"nucleo-f411": {"serial": "SN9", "lab": True}})
    r, ctx = rt
    ds = r.invoke("target.detect", {}, ctx).result["targets"]
    assert ds[0]["id"] == "nucleo-f411" and ds[0]["lab"] is True


def test_target_detect_khong_cho_board_khac_thua_huong_quyen(rt, monkeypatch):
    """Hai board cùng loại probe có cùng VID:PID. Khớp theo VID/PID nghĩa là cho một cái thừa
    hưởng quyền tự nạp của cái kia — đúng thứ danh sách lab sinh ra để chặn."""
    from eide.caps import discover, target

    monkeypatch.setattr(discover, "_cong_pyserial", lambda: [
        {"dev": "/dev/ttyACM1", "vid": "0483", "pid": "374B", "product": "", "serial": "SN-LA"},
    ])
    monkeypatch.setattr(target, "_boards_lab",
                        lambda: {"nucleo-f411": {"serial": "SN9", "lab": True}})
    r, ctx = rt
    ds = r.invoke("target.detect", {}, ctx).result["targets"]
    assert ds[0]["lab"] is False, "cùng VID/PID nhưng khác số sê-ri: KHÔNG phải board lab ấy"
