"""Nhóm sim.* (khối F1, mốc M3) — CDS-12.4 SIM-01…SIM-06; SIM-20 §1–§5;
STP-05 TC-SM-01…TC-SM-04, TC-34.

Hai loại test trong tệp này, và chúng trả lời hai câu khác nhau.

**Mô hình đối tượng thì chạy thật.** `sim.model_plant` sinh ra một mô-đun Python, và test nạp
đúng mô-đun ấy rồi tích phân nó: "không điều khiển đổ < 1 s" và "PID tham chiếu ổn định ≤ 1,5 s"
của TC-SM-03 được ĐO, không được giả lập. Đó là chỗ duy nhất trong nhóm mà giá trị số có thể
sai một cách im lặng, nên nó là chỗ phải đo.

**Engine mô phỏng thì thay bằng shim.** Máy này không có Renode lẫn simavr (cả hai không có
công thức brew), và `qemu-system-arm` thì không có máy ảo nào cho STM32F4 — nên không engine nào
chạy được firmware Cortex-M ở đây. Điều đó KHÔNG làm `sim.run` mất khả năng kiểm: thứ thuộc về
EIDE là dựng dòng lệnh, chạy trong sandbox, đọc UART và chấm bảng expect, và một shim in ra đúng
những dòng UART mà kịch bản chờ kiểm được cả bốn. Xem DEV-086 cho đường chạy engine thật.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import stat
import struct
from pathlib import Path

import pytest
import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

CHIP = "st.stm32f411ce"


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "robot cân bằng"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


def _shim(d: Path, ten: str, than: str) -> Path:
    d.mkdir(parents=True, exist_ok=True)
    f = d / ten
    f.write_text(f"#!/bin/sh\n{than}\n", encoding="utf-8")
    f.chmod(f.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    return f


def _dat_path(monkeypatch, d: Path) -> None:
    import os
    monkeypatch.setenv("PATH", f"{d}{os.pathsep}{os.environ['PATH']}")


def _nguon(c, sid="s_svd"):
    c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license) VALUES (?,?,?,?,?,?)",
              (sid, "STM32F411.svd", hashlib.sha256(sid.encode()).hexdigest(), "svd", "gold",
               "vendor-doc"))


def _fact(c, fid, subject, predicate, value, *, tier="gold", status="verified", sid="s_svd",
          unit=None):
    c.execute("INSERT INTO fact (id, subject, predicate, value, unit, source_id, method, tier,"
              " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
              (fid, subject, predicate, json.dumps(value), unit, sid, "parser", tier, 1.0,
               status, "A"))


def _ho_chieu_chip(root, *, ngoai_vi=("I2C1", "USART2", "CRC")):
    """Hộ chiếu vàng tối thiểu của STM32F411: bộ nhớ + vài ngoại vi có địa chỉ thật."""
    dia_chi = {"I2C1": 0x40005400, "USART2": 0x40004400, "CRC": 0x40023000,
               "GPIOA": 0x40020000, "TIM2": 0x40000000}
    irq = {"I2C1": 31, "USART2": 38}
    with store.open_store(store.store_path(root)) as c:
        _nguon(c)
        _fact(c, "f_flash", f"chip:{CHIP}/mem:FLASH", "memory_size", 512 * 1024, unit="byte")
        _fact(c, "f_ram", f"chip:{CHIP}/mem:RAM", "memory_size", 128 * 1024, unit="byte")
        for i, ten in enumerate(ngoai_vi):
            _fact(c, f"f_pe{i}", f"chip:{CHIP}/periph:{ten}", "base_address", dia_chi[ten])
            if ten in irq:
                _fact(c, f"f_irq{i}", f"chip:{CHIP}/periph:{ten}", "irq", irq[ten])
        c.commit()


# ================================================================ SIM-01 build_platform


def test_khong_co_ho_chieu_vang_thi_khong_dung_nen_tang(du_an, tmp_path, monkeypatch):
    """Grounding của SIM-01 là "Hộ chiếu vàng". Dựng `.repl` từ một store rỗng cho ra một nền
    tảng có kích thước bộ nhớ bằng 0 — chạy được, và sai ngay từ lệnh nạp đầu tiên."""
    from eide.caps.sim import build_platform

    _, ctx, _ = du_an
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "exit 0")
    with pytest.raises(EideError) as e:
        build_platform({"chip": CHIP}, ctx)
    assert e.value.code == "E2000"
    assert "extract.svd" in e.value.data["candidates"]


def test_sinh_repl_tu_ho_chieu_va_ke_ngoai_vi_khong_mo_phong(du_an, tmp_path, monkeypatch):
    """TC-SM-01: "STM32F411 → platform.repl nạp được; coverage liệt kê ngoại vi không mô hình"."""
    from eide.caps.sim import build_platform

    _, ctx, root = du_an
    _ho_chieu_chip(root)
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "exit 0")

    out = build_platform({"chip": CHIP, "board": "blackpill-f411"}, ctx)
    assert out["engine"] == "renode" and out["platform_dir"] == "sim"
    repl = (root / "sim" / "platform.repl").read_text(encoding="utf-8")
    assert "cpu: CPU.CortexM @ sysbus" in repl
    assert f"flash: Memory.MappedMemory @ sysbus 0x08000000 {{ size: {hex(512 * 1024)} }}" in repl
    assert "i2c1: I2C.STM32F4_I2C @ sysbus 0x40005400 -> nvic@31" in repl
    assert "usart2: UART.STM32_UART @ sysbus 0x40004400 -> nvic@38" in repl

    cov = out["coverage"]
    assert set(cov["modeled"]) == {"I2C1", "USART2"}
    assert [p["name"] for p in cov["unsupported"]] == ["CRC"]
    assert cov["mock_needed"] == ["CRC"]
    assert sorted(cov["cites"]) and all(f.startswith("f_") for f in cov["cites"])
    assert cov["memory"] == {"FLASH": 512 * 1024, "RAM": 128 * 1024}


def test_ngoai_vi_khong_co_mo_hinh_van_hien_trong_repl_chu_khong_bien_mat(du_an, tmp_path,
                                                                         monkeypatch):
    """Một `.repl` thiếu ngoại vi trông y hệt một `.repl` đủ. Dòng chú thích là chỗ duy nhất
    người đọc tệp biết CRC đã bị bỏ ra và vì sao."""
    from eide.caps.sim import build_platform

    _, ctx, root = du_an
    _ho_chieu_chip(root)
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "exit 0")
    build_platform({"chip": CHIP}, ctx)
    repl = (root / "sim" / "platform.repl").read_text(encoding="utf-8")
    assert "// KHÔNG mô phỏng: CRC @ 0x40023000" in repl


def test_thieu_ca_engine_chinh_lan_duong_lui_thi_E4001(du_an, tmp_path, monkeypatch):
    """`armv7e-m.yaml` khai `sim: {engine: renode, fallback: qemu}`. Không có renode, mà qemu
    thì không có máy ảo nào cho STM32F4 — nên cả hai đều không dùng được."""
    from eide.caps.sim import build_platform

    _, ctx, root = du_an
    _ho_chieu_chip(root)
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    with pytest.raises(EideError) as e:
        build_platform({"chip": CHIP}, ctx)
    assert e.value.code == "E4001"
    assert e.value.data["missing"] == ["renode", "qemu"]


def test_khong_tu_lui_ve_native_khi_thieu_engine(du_an, tmp_path, monkeypatch):
    """SIM-20 §1 xếp `native` là một chế độ có chủ đích ("chip không hỗ trợ"), không phải lưới
    an toàn: lui về nó trong im lặng thì `sim.run` báo ĐẠT cho một firmware chưa chạy trên mô
    hình chip nào, và `defaults.sim_first` mất hết ý nghĩa."""
    from eide.caps.sim import build_platform

    _, ctx, root = du_an
    _ho_chieu_chip(root)
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    with pytest.raises(EideError) as e:
        build_platform({"chip": CHIP}, ctx)
    assert e.value.code == "E4001"
    assert not (root / "sim" / "platform.json").exists()


def test_qemu_khong_co_may_ao_cho_chip_thi_khong_duoc_chon(du_an, tmp_path, monkeypatch):
    """Có `qemu-system-arm` KHÔNG có nghĩa là chạy được STM32F411: QEMU chỉ chạy những bo mạch
    đã biên dịch sẵn vào nó. Gán tạm `netduinoplus2` (vốn là STM32F405) thì firmware chạy trên
    một con chip khác chip nó được dịch cho — rồi báo ĐẠT."""
    from eide.caps.sim import _may_qemu, chon_engine

    _, _ctx, _root = du_an
    assert _may_qemu(CHIP) is None
    assert _may_qemu("atmel.atmega328p")["machine"] == "arduino-uno"

    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "qemu-system-arm", "exit 0")
    man = yaml.safe_load("sim: {engine: renode, fallback: qemu}")
    with pytest.raises(EideError) as e:
        chon_engine("armv7e-m", man, CHIP)
    assert e.value.code == "E4001"
    # Cùng qemu ấy, chip ATmega328P thì có `arduino-uno` thật — nên "không dùng được" là kết
    # luận về CẶP (engine, chip), không phải về engine.
    assert chon_engine("avr8", yaml.safe_load("sim: {engine: simavr, fallback: qemu}"),
                       "atmel.atmega328p")["engine"] == "qemu"


def test_ten_chip_dang_IRI_ho_chieu_van_suy_ra_ISA():
    """Ví dụ của SIM-01 là `st.stm32f411ce`, ví dụ của PROJECT-06 là `STM32F411CE` — cùng một
    con chip, hai dạng tên sống cạnh nhau trong cùng bộ hồ sơ. `family_patterns` neo đầu chuỗi
    nên chỉ khớp dạng thứ hai; trước khi vá, ghim chip bằng dạng IRI cho `isa: null` im lặng."""
    from eide.caps.sim import isa_cua_chip

    assert isa_cua_chip("st.stm32f411ce") == "armv7e-m"
    assert isa_cua_chip("chip:st.stm32f411ce") == "armv7e-m"
    assert isa_cua_chip("STM32F411CE") == "armv7e-m"
    assert isa_cua_chip("atmel.atmega328p") == "avr8"
    assert isa_cua_chip("KHONG_CO_CHIP_NAY") is None


def test_ghim_dich_bang_dang_IRI_khong_con_mat_ISA(du_an):
    """Hệ quả thật của cùng chỗ vá: `project.set_target` ghim `st.stm32f411ce` từng cho ra
    `isa: null` trong constraints.yaml, rồi `code.build` dừng ở "chưa ghim ISA" — một câu đúng
    về triệu chứng và sai về nguyên nhân."""
    r, ctx, _root = du_an
    out = r.invoke("project.set_target", {"chip": "st.stm32f411ce"}, ctx).result
    assert out["pins"]["isa"] == "armv7e-m"
    assert not [m for m in out["missing"] if "ISA cho" in m]


# ================================================================ SIM-02 mock_peripheral

BME = "part:bosch.bme280"


def _ho_chieu_bme280(root, *, status="verified", tier="gold"):
    with store.open_store(store.store_path(root)) as c:
        _nguon(c, "s_bme")
        _fact(c, "f_addr", BME, "address", {"sdo=gnd": 118, "sdo=vdd": 119}, sid="s_bme",
              tier=tier, status=status)
        for i, (ten, off, rv) in enumerate([("ID", 0xD0, 0x60), ("CTRL_MEAS", 0xF4, 0x00),
                                            ("TEMP_MSB", 0xFA, 0x80)]):
            _fact(c, f"f_r{i}o", f"{BME}/periph:REG/reg:{ten}", "offset", off, sid="s_bme",
                  tier=tier, status=status)
            _fact(c, f"f_r{i}v", f"{BME}/periph:REG/reg:{ten}", "reset_value", rv, sid="s_bme",
                  tier=tier, status=status)
        c.commit()


def _nap(p: Path):
    import importlib.util
    spec = importlib.util.spec_from_file_location(f"mock_{p.stem}", p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_mock_doc_ID_tra_0x60(du_an):
    """TC-SM-02, nửa đầu: "Firmware đọc ID 0x60". Test NẠP mô-đun sinh ra rồi nói chuyện với nó
    đúng giao thức I2C của datasheet — ghi con trỏ thanh ghi rồi đọc burst."""
    from eide.caps.sim import mock_peripheral

    _, ctx, root = du_an
    _ho_chieu_bme280(root)
    out = mock_peripheral({"part": "bosch.bme280"}, ctx)
    assert out["mock_path"] == "sim/mocks/bosch_bme280.py"
    assert out["params"]["address"] == {"sdo=gnd": 118, "sdo=vdd": 119}
    assert out["params"]["registers"] == 3

    mod = _nap(root / out["mock_path"])
    m = mod.BoschBme280Mock()
    m.Write([0xD0])
    assert m.Read(1) == [0x60]
    m.Write([0xF4, 0x27])
    m.Write([0xF4])
    assert m.Read(1) == [0x27]


def test_chi_doc_den_tu_fact_access_chu_khong_tu_phong_doan(du_an):
    """Thanh ghi ID của BME280 là chỉ-đọc — nhưng KHÔNG fact nào trong store nói thế trừ khi
    có `access`. Đoán "thanh ghi tên ID chắc là chỉ-đọc" đúng với con này và sai với con sau.

    Không có `access` thì mock cho ghi, và hệ quả phải nói ra: nó không bắt được lỗi firmware
    ghi vào vùng chỉ-đọc. Có `access` thì nó bắt."""
    from eide.caps.sim import mock_peripheral

    _, ctx, root = du_an
    _ho_chieu_bme280(root)
    out = mock_peripheral({"part": "bosch.bme280"}, ctx)
    m = _nap(root / out["mock_path"]).BoschBme280Mock()
    m.Write([0xD0, 0x00])
    m.Write([0xD0])
    assert m.Read(1) == [0x00], "chưa có fact access thì mock KHÔNG được tự cấm ghi"

    with store.open_store(store.store_path(root)) as c:
        _fact(c, "f_ro", f"{BME}/periph:REG/reg:ID", "access", "ro", sid="s_bme")
        c.commit()
    out = mock_peripheral({"part": "bosch.bme280"}, ctx)
    m = _nap(root / out["mock_path"]).BoschBme280Mock()
    m.Write([0xD0, 0x00])
    m.Write([0xD0])
    assert m.Read(1) == [0x60]


def test_mock_khong_co_fact_thi_E2000(du_an):
    from eide.caps.sim import mock_peripheral

    _, ctx, _root = du_an
    with pytest.raises(EideError) as e:
        mock_peripheral({"part": "bosch.bme280"}, ctx)
    assert e.value.code == "E2000"
    assert "extract.pdf_register_map" in e.value.data["candidates"]


def test_fact_chua_duyet_thanh_nhan_tam(du_an):
    """SIM-20 §3: "Tham số không có fact → provisional". Một fact tầng bạc chưa ai duyệt cũng là
    tham số không có nguồn đủ chắc — nó vẫn dùng được, nhưng phải mang nhãn."""
    from eide.caps.sim import mock_peripheral

    _, ctx, root = du_an
    _ho_chieu_bme280(root, status="normalized", tier="silver")
    out = mock_peripheral({"part": "bosch.bme280"}, ctx)
    assert "address" in out["params"]["provisional"]
    assert "reg:ID" in out["params"]["provisional"]


def test_khong_co_cong_thuc_thi_nhan_tam_formula(du_an):
    from eide.caps.sim import mock_peripheral

    _, ctx, root = du_an
    _ho_chieu_bme280(root)
    out = mock_peripheral({"part": "bosch.bme280"}, ctx)
    assert out["params"]["formula"] is None
    assert "formula" in out["params"]["provisional"]
    assert "dữ liệu đo thì KHÔNG" in (root / out["mock_path"]).read_text(encoding="utf-8")


class _GW:
    """Gateway giả — `run(role, prompt, schema, system_extra)` trả `data` đã định trước."""

    def __init__(self, data):
        self.data, self.vai_tro, self.de_bai = data, None, None

    def prompt(self, role):
        return f"# vai trò {role}"

    def run(self, role, prompt, schema, system_extra=""):
        self.vai_tro, self.de_bai = role, prompt
        gw = self

        class R:
            data = gw.data
            model_id = "gemini-3.8-flash"
        return R()


def _skill_cong_thuc(root: Path):
    d = root / ".eide" / "skills"
    d.mkdir(parents=True, exist_ok=True)
    (d / "bme280-comp.md").write_text(
        "---\n" + yaml.safe_dump({"title": "Bù nhiệt", "applies_to": ["part:bosch.bme280"],
                                  "kind": "skill"}, allow_unicode=True) + "---\n\n"
        "# Bù nhiệt\n\n```c\nint32_t comp_t(int32_t adc) { return adc / 5120; }\n```\n",
        encoding="utf-8")


def test_cong_thuc_sai_cu_phap_Python_thi_E5002(du_an):
    """E5002 là mã lỗi DUY NHẤT của SIM-02, và đây là đường tới nó: mô hình dịch công thức C
    sang Python mà trả ra thứ không phân tích cú pháp được."""
    from eide.caps.sim import mock_peripheral

    _, ctx, root = du_an
    _ho_chieu_bme280(root)
    _skill_cong_thuc(root)
    ctx.extra["gateway"] = _GW({"name": "comp_t", "python": "def comp_t(adc) return adc"})
    with pytest.raises(EideError) as e:
        mock_peripheral({"part": "bosch.bme280"}, ctx)
    assert e.value.code == "E5002"


def test_cong_thuc_khai_ten_ham_khong_co_trong_ma_thi_E5002(du_an):
    """Mã chạy được nhưng không định nghĩa hàm đã khai: mock sẽ import thành công rồi ném
    AttributeError ở giữa một lượt mô phỏng — xa chỗ hỏng nhất có thể."""
    from eide.caps.sim import mock_peripheral

    _, ctx, root = du_an
    _ho_chieu_bme280(root)
    _skill_cong_thuc(root)
    ctx.extra["gateway"] = _GW({"name": "comp_t", "python": "def khac(adc):\n    return adc\n"})
    with pytest.raises(EideError) as e:
        mock_peripheral({"part": "bosch.bme280"}, ctx)
    assert e.value.code == "E5002" and e.value.data["functions"] == ["khac"]


def test_cong_thuc_hop_le_vao_ma_mock_va_go_nhan_tam(du_an):
    from eide.caps.sim import mock_peripheral

    _, ctx, root = du_an
    _ho_chieu_bme280(root)
    _skill_cong_thuc(root)
    gw = _GW({"name": "comp_t", "python": "def comp_t(self, adc):\n    return adc // 5120\n"})
    ctx.extra["gateway"] = gw
    out = mock_peripheral({"part": "bosch.bme280"}, ctx)
    assert gw.vai_tro == "coder"
    assert out["params"]["formula"] == "comp_t"
    assert "formula" not in out["params"]["provisional"]
    mod = _nap(root / out["mock_path"])
    assert mod.BoschBme280Mock().comp_t(51200) == 10


# ================================================================ SIM-03 model_plant


def _plant(ctx, root, **p):
    from eide.caps.sim import model_plant
    out = model_plant(p, ctx)
    return out, _nap(root / out["model_path"])


def test_khong_dieu_khien_thi_do_duoi_mot_giay(du_an):
    """TC-SM-03, nửa đầu. Đo trên chính mô-đun sinh ra, không giả lập: một mô hình động lực học
    luôn trả ra số đẹp, nên chỗ duy nhất phát hiện được nó sai là tích phân nó thật."""
    _, ctx, root = du_an
    _out, mod = _plant(ctx, root, template="balancing-robot")
    kq = mod.run(theta0_deg=5.0, duration_s=2.0, controlled=False)
    assert kq["fallen_s"] is not None and kq["fallen_s"] < 1.0


def test_PID_tham_chieu_on_dinh_duoi_mot_giay_ruoi(du_an):
    """TC-SM-03, nửa sau: "PID chuẩn tham chiếu → ổn định ≤ 1,5 s sau nhiễu 5°"."""
    _, ctx, root = du_an
    _out, mod = _plant(ctx, root)
    kq = mod.run(theta0_deg=5.0, duration_s=3.0)
    assert kq["fallen_s"] is None
    assert kq["settle_s"] is not None and kq["settle_s"] <= 1.5


def test_tham_so_nguoi_truyen_khong_mang_nhan_tam(du_an):
    """Z-09: "nhãn tạm cho khối lượng". Nhãn nói về NGUỒN của con số, không về giá trị — nên
    truyền đúng giá trị mặc định cũng gỡ được nhãn, vì lúc ấy đã có người chịu trách nhiệm."""
    _, ctx, root = du_an
    out, _mod = _plant(ctx, root, params={"M": 0.8, "l": 0.075})
    assert out["params_used"]["M"] == 0.8 and out["params_used"]["l"] == 0.075
    assert "M" not in out["provisional"] and "l" not in out["provisional"]
    assert out["provisional"] == ["I", "J", "m", "r"]


def test_g_va_dt_khong_phai_tham_so_cho_ai_do(du_an):
    """Gia tốc trọng trường không chờ ai đo, và bước tích phân là lựa chọn của mô hình chứ không
    phải thuộc tính của robot. Để chúng trong `provisional` làm nhãn tạm mất nghĩa."""
    _, ctx, root = du_an
    out, _mod = _plant(ctx, root)
    assert "g" not in out["provisional"] and "dt" not in out["provisional"]
    assert out["params_used"]["g"] == 9.81


def test_mau_plant_la_thi_E2000(du_an):
    from eide.caps.sim import model_plant

    _, ctx, _root = du_an
    with pytest.raises(EideError) as e:
        model_plant({"template": "drone"}, ctx)
    assert e.value.code == "E2000" and "balancing-robot" in e.value.data["candidates"]


def test_tham_so_khong_thuoc_mau_thi_E1000(du_an):
    """Nhận một tham số mẫu không có nghĩa là ghi nó vào `params_used` rồi không ai dùng — và
    người truyền `mass` thay vì `M` sẽ tin rằng mình đã đặt khối lượng."""
    from eide.caps.sim import model_plant

    _, ctx, _root = du_an
    with pytest.raises(EideError) as e:
        model_plant({"params": {"mass": 1.2}}, ctx)
    assert e.value.code == "E1000"


# ================================================================ SIM-04 scenario


def _feature(root: Path, kind="serial_pattern", detail="in `IMU ok` trong 1 giây đầu"):
    f = root / ".eide" / "FEATURES.json"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps([{"id": "F-04", "title": "đọc IMU", "status": "failing",
                              "expectation": {"kind": kind, "detail": detail},
                              "constraints": ["chu kỳ 10 ms"]}], ensure_ascii=False),
                 encoding="utf-8")


def _nen_tang_gia(root: Path, engine="renode", exe="/bin/echo"):
    d = root / "sim"
    d.mkdir(parents=True, exist_ok=True)
    (d / "platform.json").write_text(json.dumps({
        "chip": f"chip:{CHIP}", "board": None, "isa": "armv7e-m", "engine": engine, "exe": exe,
        "memory": {"FLASH": 524288, "RAM": 131072},
        "modeled": [{"name": "USART2", "base": 0x40004400, "model": "UART.STM32_UART",
                     "kind": "uart"}],
        "unsupported": [], "files": []}, ensure_ascii=False), encoding="utf-8")
    return d


def test_kich_ban_sinh_tu_ky_vong_feature(du_an):
    """SIM-04 bước 1. `init` lấy từ những gì ĐÃ dựng trong `sim/` chứ không hỏi mô hình: mock nào
    tồn tại là sự thật của thư mục, và mô hình rất sẵn lòng kê ra `mpu6050` cho một dự án chưa
    trích datasheet nào."""
    from eide.caps.sim import mock_peripheral, model_plant, scenario

    _, ctx, root = du_an
    _ho_chieu_bme280(root)
    _nen_tang_gia(root)
    _feature(root)
    mock_peripheral({"part": "bosch.bme280"}, ctx)
    model_plant({}, ctx)
    gw = _GW({"expect": [{"kind": "uart", "pattern": "IMU ok", "within_s": 1.0}],
              "inject": [{"t": 0.5, "mock": "bosch_bme280", "fault": "nack"}],
              "duration_s": 5})
    ctx.extra["gateway"] = gw

    out = scenario({"feature": "F-04"}, ctx)
    assert out["scenario_path"] == "sim/f-04.yaml"
    kb = yaml.safe_load((root / out["scenario_path"]).read_text(encoding="utf-8"))
    assert kb["id"] == "F-04-basic" and kb["engine"] == "renode" and kb["feature"] == "F-04"
    assert kb["expect"] == [{"kind": "uart", "pattern": "IMU ok", "within_s": 1.0}]
    assert kb["init"]["mocks"] == ["bosch_bme280"]
    assert kb["init"]["plant"] == "balancing_robot"
    assert kb["init"]["uart"] == {"port": "USART2", "baud": 115200}
    assert gw.vai_tro == "planner" and "chu kỳ 10 ms" in gw.de_bai


def test_ky_vong_probe_reg_thanh_expect_var(du_an):
    """Bảng ánh xạ PLAN-01 → SIM-20 §5 là một bảng, không phải một phán đoán của mô hình."""
    from eide.caps.sim import scenario

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _feature(root, kind="probe_reg", detail="g_theta < 0.02 sau 2 s")
    ctx.extra["gateway"] = _GW({"expect": [{"kind": "var", "symbol": "g_theta",
                                            "abs_lt": 0.02, "after_s": 2.0}]})
    out = scenario({"feature": "F-04"}, ctx)
    kb = yaml.safe_load((root / out["scenario_path"]).read_text(encoding="utf-8"))
    assert kb["expect"][0]["kind"] == "var"


def test_mo_hinh_tra_sai_loai_expect_thi_E5002(du_an):
    from eide.caps.sim import scenario

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _feature(root, kind="probe_reg", detail="g_theta < 0.02")
    ctx.extra["gateway"] = _GW({"expect": [{"kind": "uart", "pattern": "ok"}]})
    with pytest.raises(EideError) as e:
        scenario({"feature": "F-04"}, ctx)
    assert e.value.code == "E5002" and e.value.data["expected"] == "var"


def test_expect_thieu_truong_bat_buoc_thi_E5002(du_an):
    """Một dòng `expect` kind=uart mà không có `pattern` vẫn chạy được ở `sim.run` và vẫn cho ra
    một bảng kết quả — chỉ là bảng ấy không kiểm gì."""
    from eide.caps.sim import scenario

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _feature(root)
    ctx.extra["gateway"] = _GW({"expect": [{"kind": "uart", "within_s": 1.0}]})
    with pytest.raises(EideError) as e:
        scenario({"feature": "F-04"}, ctx)
    assert e.value.code == "E5002" and e.value.data["missing"] == ["pattern"]


def test_chua_co_feature_thi_E2000(du_an):
    from eide.caps.sim import scenario

    _, ctx, root = du_an
    _nen_tang_gia(root)
    with pytest.raises(EideError) as e:
        scenario({"feature": "F-04"}, ctx)
    assert e.value.code == "E2000" and "plan.define_feature" in e.value.data["candidates"]


def test_chua_dung_nen_tang_thi_khong_sinh_kich_ban(du_an):
    from eide.caps.sim import scenario

    _, ctx, root = du_an
    _feature(root)
    with pytest.raises(EideError) as e:
        scenario({"feature": "F-04"}, ctx)
    assert e.value.code == "E2000" and "sim.build_platform" in e.value.data["candidates"]


# ================================================================ SIM-05 run


def _kich_ban(root: Path, expect, duration_s=1):
    d = root / "sim"
    d.mkdir(parents=True, exist_ok=True)
    p = d / "f-04.yaml"
    p.write_text(yaml.safe_dump({"id": "F-04-basic", "engine": "renode", "duration_s": duration_s,
                                 "init": {"mocks": []}, "inject": [], "expect": expect,
                                 "record": ["uart"], "feature": "F-04"},
                                allow_unicode=True, sort_keys=False), encoding="utf-8")
    return p


def _artifact(root: Path):
    (root / "build").mkdir(parents=True, exist_ok=True)
    f = root / "build" / "fw.elf"
    f.write_bytes(b"\x7fELF")
    return f


def test_chay_va_cham_expect_uart(du_an, tmp_path, monkeypatch):
    """TC-34. Shim đứng thay Renode: thứ thuộc về EIDE là dựng dòng lệnh, chạy trong sandbox,
    đọc UART và chấm bảng — bốn thứ ấy kiểm được mà không cần engine thật."""
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "IMU ok"}])
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo 'boot'; echo 'IMU ok'; exit 0")

    rep = run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)["report"]
    assert rep["passed"] is True
    assert rep["captured"]["uart"] == ["boot", "IMU ok"]
    assert rep["metrics"]["expect"][0]["status"] == "passed"
    assert rep["metrics"]["engine"] == "renode" and rep["metrics"]["feature"] == "F-04"
    assert rep["artifacts"] == ["build/fw.elf"]


def test_resc_duoc_dien_artifact_va_thoi_luong(du_an, tmp_path, monkeypatch):
    """`run.resc` là bản mẫu; lượt chạy điền artifact và thời lượng thật vào `.run.resc`. Không
    điền thì Renode nạp chuỗi `${artifact}` như một tên tệp."""
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    (root / "sim" / "run.resc").write_text(
        "mach create\nsysbus LoadELF ${artifact}\nemulation RunFor \"${duration}\"\nquit\n",
        encoding="utf-8")
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "ok"}], duration_s=7)
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo ok; exit 0")
    run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)

    resc = (root / "sim" / ".run.resc").read_text(encoding="utf-8")
    assert f"sysbus LoadELF @{root / 'build' / 'fw.elf'}" in resc
    assert 'emulation RunFor "7.0"' in resc


def test_expect_khong_co_kenh_quan_sat_thi_unverified_va_keo_ca_luot_xuong(du_an, tmp_path,
                                                                          monkeypatch):
    """Bất biến của cả nhóm. `unverified` tồn tại vì "firmware làm sai" và "EIDE chưa nhìn thấy
    được" là hai câu khác nhau: gộp thành `failed` thì người ta đi sửa một chỗ không hỏng, gộp
    thành `passed` thì một firmware chưa ai quan sát đi thẳng lên board."""
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "IMU ok"},
                     {"kind": "var", "symbol": "g_theta", "abs_lt": 0.02}])
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo 'IMU ok'; exit 0")

    rep = run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)["report"]
    assert rep["passed"] is False
    trang_thai = [d["status"] for d in rep["metrics"]["expect"]]
    assert trang_thai == ["passed", "unverified"]
    assert "DEV-083" in rep["metrics"]["expect"][1]["reason"]
    assert rep["metrics"]["n_unverified"] == 1


def test_within_s_nho_hon_thoi_luong_thi_chua_ket_luan_duoc(du_an, tmp_path, monkeypatch):
    """Log console không mang mốc thời gian theo dòng. `within_s ≥ duration_s` thì mọi dòng đều
    trong hạn và kết luận chắc chắn; nhỏ hơn thì chưa biết — và chưa biết phải nói là chưa biết
    chứ không làm tròn thành ĐẠT."""
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "IMU ok", "within_s": 0.5}], duration_s=5)
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo 'IMU ok'; exit 0")

    rep = run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)["report"]
    assert rep["metrics"]["expect"][0]["status"] == "unverified"
    assert rep["passed"] is False


def test_within_s_bang_thoi_luong_thi_ket_luan_duoc(du_an, tmp_path, monkeypatch):
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "IMU ok", "within_s": 2}], duration_s=2)
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo 'IMU ok'; exit 0")
    rep = run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)["report"]
    assert rep["metrics"]["expect"][0]["status"] == "passed" and rep["passed"] is True


def test_khong_thay_mau_uart_thi_failed_chu_khong_unverified(du_an, tmp_path, monkeypatch):
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "IMU ok"}])
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo 'I2C NACK'; exit 0")
    rep = run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)["report"]
    assert rep["metrics"]["expect"][0]["status"] == "failed"


def test_engine_tra_ma_khac_khong_thi_E4000(du_an, tmp_path, monkeypatch):
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "ok"}])
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo 'không nạp được platform' >&2; exit 3")
    with pytest.raises(EideError) as e:
        run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)
    assert e.value.code == "E4000" and e.value.data["exit_code"] == 3


def test_engine_khong_tu_dung_thi_het_gio_la_ket_thuc_binh_thuong(du_an, tmp_path, monkeypatch):
    """Firmware nhúng không thoát — đó là điểm của nó. Với qemu/simavr, hết giờ CHÍNH LÀ cách
    lượt chạy kết thúc, nên biến nó thành E4004 là báo lỗi cho một lượt chạy bình thường."""
    from eide.caps import sim

    _, ctx, root = du_an
    _nen_tang_gia(root, engine="qemu")
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "IMU ok"}])
    monkeypatch.setitem(sim.QEMU_MACHINE, "^stm32f411", {"machine": "gia-lap", "nap": "-kernel"})
    # Biên 0 cho cả lượt chạy đúng `duration_s` = 1 giây, và bài này thỉnh thoảng đỏ khi chạy
    # cùng cả bộ: dưới tải, tiến trình chưa kịp qua `sandbox-exec` + khởi động shell để chạy
    # `echo` thì đã bị giết, nên `captured.uart` rỗng và dòng expect trượt. Thứ bài này kiểm là
    # "hết giờ KHÔNG phải lỗi", không phải "hết giờ nhanh cỡ nào" — nên 3 giây vẫn kiểm đúng
    # điều ấy (`sleep 30` vẫn bị cắt) mà không còn đua với bộ lập lịch.
    monkeypatch.setattr(sim, "BIEN_THOI_GIAN_S", 2)
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "qemu-system-arm", "echo 'IMU ok'; sleep 30")

    rep = sim.run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)["report"]
    assert rep["metrics"]["terminated_by"] == "timeout"
    assert rep["passed"] is True


def test_khong_co_artifact_thi_E4000(du_an, tmp_path, monkeypatch):
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "ok"}])
    with pytest.raises(EideError) as e:
        run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)
    assert e.value.code == "E4000"


def test_tool_report_vao_store(du_an, tmp_path, monkeypatch):
    """Một lượt mô phỏng là dữ liệu, không phải thứ đọc rồi bỏ: `feature.evidence` và
    `sim.compare_hil` (M4) đều trỏ về `tool_report.id`."""
    from eide.caps.sim import run

    _, ctx, root = du_an
    _nen_tang_gia(root)
    _artifact(root)
    _kich_ban(root, [{"kind": "uart", "pattern": "ok"}])
    _dat_path(monkeypatch, tmp_path / "bin")
    _shim(tmp_path / "bin", "renode", "echo ok; exit 0")
    run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute("SELECT tool, passed FROM tool_report WHERE tool='sim.run'").fetchall()
    assert rows == [("sim.run", 1)]


# ================================================================ SIM-06 sweep


def _kich_ban_pid(root: Path, duration_s=2.0):
    d = root / "sim"
    d.mkdir(parents=True, exist_ok=True)
    p = d / "pid.yaml"
    p.write_text(yaml.safe_dump({"id": "pid", "engine": "renode", "duration_s": duration_s,
                                 "init": {"plant": "balancing_robot", "mocks": []},
                                 "expect": [], "record": []},
                                allow_unicode=True, sort_keys=False), encoding="utf-8")
    return p


def test_luoi_du_o():
    """Ví dụ của SIM-06: `{"kp": [1, 10, 1]}` — mười ô, không phải chín."""
    from eide.caps.sim import luoi

    o = luoi({"kp": [1, 10, 1]})
    assert len(o) == 10 and o[0] == {"kp": 1.0} and o[-1] == {"kp": 10.0}
    assert len(luoi({"kp": [1, 4, 1], "kd": {"values": [0.1, 0.2]}})) == 8
    with pytest.raises(EideError):
        luoi({"kp": [1, 10, 0]})


def test_sweep_chon_o_on_dinh_som_nhat(du_an):
    """tc của SIM-06: "Bảng đủ ô; best hợp lý"."""
    from eide.caps.sim import model_plant, sweep

    _, ctx, root = du_an
    model_plant({}, ctx)
    _kich_ban_pid(root)
    out = sweep({"scenario": "sim/pid.yaml", "ranges": {"kp": [2, 10, 2]}}, ctx)
    assert len(out["table"]) == 5
    assert out["best"]["ok"] is True
    assert out["best"]["settle_s"] == min(d["settle_s"] for d in out["table"] if d["ok"])


def test_o_do_khong_bao_gio_la_best(du_an):
    """"Tốt nhất trong những cái đều hỏng" là một câu nói dối có hình dạng của một kết luận."""
    from eide.caps.sim import model_plant, sweep

    _, ctx, root = du_an
    model_plant({}, ctx)
    _kich_ban_pid(root)
    out = sweep({"scenario": "sim/pid.yaml", "ranges": {"kp": {"values": [0.0, 0.1]}}}, ctx)
    assert all(d["fallen_s"] is not None for d in out["table"])
    assert out["best"] == {}


def test_quet_tham_so_firmware_thi_noi_ro_can_nang_luc_nao(du_an):
    """Một tham số nằm trong mã firmware chỉ đổi được bằng cách dịch lại firmware cho từng ô —
    đó là một chuỗi, không phải một năng lực. Quét một thứ rồi báo cáo như thể đã quét thứ khác
    là chỗ hỏng đắt nhất mà một bảng nhiệt có thể gây ra."""
    from eide.caps.sim import model_plant, sweep

    _, ctx, root = du_an
    model_plant({}, ctx)
    _kich_ban_pid(root)
    with pytest.raises(EideError) as e:
        sweep({"scenario": "sim/pid.yaml", "ranges": {"i2c_speed_khz": [100, 400, 100]}}, ctx)
    assert e.value.code == "E2000" and "code.modify" in e.value.data["candidates"]


def test_kich_ban_khong_co_plant_thi_chua_quet_duoc(du_an):
    from eide.caps.sim import sweep

    _, ctx, root = du_an
    _kich_ban(root, [])
    with pytest.raises(EideError) as e:
        sweep({"scenario": "sim/f-04.yaml", "ranges": {"kp": [1, 2, 1]}}, ctx)
    assert e.value.code == "E2000" and e.value.data["missing"] == ["init.plant"]


# ============================================ đường chạy engine THẬT (DEV-086)

QEMU_AVR = shutil.which("qemu-system-avr")

# ELF AVR dựng BẰNG TAY, vì máy phát triển không có `avr-gcc` và cả nhóm `sim.*` thì không
# được phép chờ một chuỗi công cụ để có lấy một lượt chạy engine thật. 98 byte, và mọi thứ
# trong đó đều là thứ QEMU thật sự đọc: ELF32 little-endian, `e_machine = 0x53` (EM_AVR), một
# đoạn PT_LOAD nạp tại địa chỉ 0.
#
# Firmware làm đúng ba việc, viết thẳng bằng mã máy ATmega328P:
#
#   ldi r17, 0x08        18 E0          TXEN0 — bật bộ phát
#   sts 0xC1, r17        10 93 C1 00    UCSR0B
#   ldi r16, 'E'         05 E4
#   sts 0xC6, r16        00 93 C6 00    UDR0 — một ký tự ra UART
#   rjmp .-2             FF CF          lặp vô hạn; firmware nhúng không thoát
MA_AVR = bytes.fromhex("18E0" "1093C100" "05E4" "0093C600" "FFCF")


def _elf_avr(ma: bytes = MA_AVR) -> bytes:
    ehdr, phdr = 52, 32
    return (
        b"\x7fELF" + bytes([1, 1, 1, 0]) + bytes(8)
        + struct.pack("<HHIIIIIHHHHHH", 2, 0x53, 1, 0, ehdr, 0, 5, ehdr, phdr, 1, 40, 0, 0)
        + struct.pack("<IIIIIIII", 1, ehdr + phdr, 0, 0, len(ma), len(ma), 5, 2)
        + ma)


@pytest.mark.skipif(QEMU_AVR is None, reason="cần qemu-system-avr (brew install qemu)")
def test_duong_engine_THAT_chay_firmware_AVR_that(du_an, monkeypatch):
    """DEV-086 — lượt chạy đầu tiên của nhóm `sim.*` KHÔNG dùng shim.

    Mọi bài `sim.run` khác trong tệp này thay engine bằng một script shell in ra đúng dòng
    UART mà kịch bản chờ. Chúng kiểm được phần thuộc về EIDE — dựng dòng lệnh, chạy trong
    sandbox, đọc log, chấm bảng expect — nhưng chúng không thể sai theo cách một engine thật
    sai được, vì shim luôn ngoan. Bài này chạy `qemu-system-avr` thật trên máy ảo `arduino-uno`
    (= ATmega328P) với một ELF AVR thật, và ký tự trong `captured.uart` là ký tự firmware ghi
    vào UDR0 chứ không phải chuỗi một script `echo` ra.

    Trước 11/09/2026 bài này không viết được: `avr8.yaml` khai `sim: {engine: simavr}` mà
    simavr không có công thức brew, và không có `fallback` thì EIDE không được phép dùng
    `qemu-system-avr` vốn có sẵn. Một dòng trong manifest là khác nhau giữa "44 test xanh trên
    một đường chưa ai chạy" và "đường ấy đã chạy".
    """
    from eide.caps import sim as sim_mod
    from eide.caps.sim import run

    _, ctx, root = du_an
    # Biên 20 s là chỗ cho Renode khởi động. QEMU lên trong chớp mắt, mà nó KHÔNG tự dừng nên
    # cả lượt chạy dài đúng bằng hạn — để nguyên thì bài này một mình chiếm 21 s của `make
    # check`. Hạ biên không đổi thứ đang kiểm: bài này kiểm engine chạy được, không kiểm hằng số.
    monkeypatch.setattr(sim_mod, "BIEN_THOI_GIAN_S", 3)

    d = root / "sim"
    d.mkdir(parents=True, exist_ok=True)
    (d / "platform.json").write_text(json.dumps({
        "chip": "chip:atmel.atmega328p", "board": None, "isa": "avr8",
        "engine": "qemu", "exe": QEMU_AVR,
        "memory": {"FLASH": 32768, "RAM": 2048},
        "modeled": [{"name": "USART0", "base": 0xC0, "model": "qemu.avr-usart", "kind": "uart"}],
        "unsupported": [], "files": []}, ensure_ascii=False), encoding="utf-8")

    (root / "build").mkdir(parents=True, exist_ok=True)
    (root / "build" / "fw.elf").write_bytes(_elf_avr())
    _kich_ban(root, [{"kind": "uart", "pattern": "E"}], duration_s=1)

    rep = run({"artifact": "build/fw.elf", "scenario": "sim/f-04.yaml"}, ctx)["report"]

    assert rep["metrics"]["engine"] == "qemu"
    # QEMU không tự dừng (`TU_DUNG["qemu"] = False`): hết giờ LÀ cách lượt chạy kết thúc, không
    # phải E4004. Đây là chỗ duy nhất nhánh ấy được một engine thật chứng minh.
    assert rep["metrics"]["terminated_by"] == "timeout"
    # Khẳng định trên DÒNG chứ không phải "có chữ E ở đâu đó": một lượt chạy thật in cả biểu
    # ngữ lẫn lời than của engine, và `"E" in " ".join(...)` thì xanh cho gần như mọi thứ.
    assert "E" in rep["captured"]["uart"], rep["captured"]["uart"]
    assert rep["metrics"]["expect"][0]["status"] == "passed"
    assert rep["passed"] is True


@pytest.mark.skipif(QEMU_AVR is None, reason="cần qemu-system-avr (brew install qemu)")
def test_manifest_avr8_that_cho_qemu_lam_duong_lui(du_an):
    """`fallback` đọc từ `docs/spec/isa/avr8.yaml` THẬT, không từ một bản chép trong test.

    Và đường lui ấy chỉ mở cho chip QEMU thật sự mang máy ảo: ATmega328P đi tiếp, ATtiny1616
    thì E4001. "Engine dùng được" là kết luận về CẶP (engine, chip) — gán một máy ảo gần giống
    thì firmware chạy trên một con chip khác chip nó được dịch cho, rồi báo ĐẠT.
    """
    from eide.caps.sim import chon_engine

    man = yaml.safe_load(Path("docs/spec/isa/avr8.yaml").read_text(encoding="utf-8"))
    assert man["sim"] == {"engine": "simavr", "fallback": "qemu"}

    eng = chon_engine("avr8", man, "ATmega328P")
    assert eng["engine"] == "qemu" and eng["requested"] == "simavr" and eng["fallback"] is True
    assert Path(eng["exe"]).name == "qemu-system-avr"

    with pytest.raises(EideError) as e:
        chon_engine("avr8", man, "ATtiny1616")
    assert e.value.code == "E4001"


# ================================================================ hợp đồng nhóm


def test_ca_sau_nang_luc_M3_da_gan_hien_thuc():
    """SIM-07 `compare_hil` thuộc mốc M4 và cố ý chưa có — nó cần một báo cáo HIL thật, tức cần
    board. Sáu năng lực còn lại là toàn bộ phần M3 của nhóm."""
    from eide.cli import main  # noqa: F401 — nạp registry đầy đủ
    from eide_core.registry import get_registry

    reg = get_registry()
    xong = {c.spec.id for c in reg.list(ns="sim", implemented=True)}
    assert xong == {"sim.build_platform", "sim.mock_peripheral", "sim.model_plant",
                    "sim.scenario", "sim.run", "sim.sweep"}
    assert reg.get("sim.compare_hil").spec.milestone == "M4"


# ---------------------------------------------------------------- rv32imac (M5, 14/09/2026)


def test_manifest_rv32imac_khop_ho_risc_v():
    """TGT-19 §2 mở phần đầu của mốc M5: manifest `rv32imac`.

    `family_patterns` phải bắt được ESP32-C3 ở CẢ HAI cách viết — Espressif dùng "ESP32-C3" trên
    tài liệu thương mại và "esp32c3" trong tên tệp SVD, và một dự án gõ theo cách nào cũng phải
    ghim được ISA. Đo 14/09: `project.set_target` với `chip: "esp32-c3"` cho `isa: rv32imac`.
    """
    import re

    from eide_core.paths import spec_dir

    d = yaml.safe_load((spec_dir() / "isa" / "rv32imac.yaml").read_text(encoding="utf-8"))
    assert d["id"] == "rv32imac"
    mau = d["family_patterns"]
    for chip in ("ESP32-C3", "esp32c3", "ESP32-C6", "GD32VF103", "CH32V307"):
        assert any(re.search(p, chip, re.I) for p in mau), f"{chip} không khớp manifest nào"
    # KHÔNG được bắt nhầm họ Xtensa: ESP32 và ESP32-S3 là Xtensa, không phải RISC-V, và ghim
    # nhầm ISA nghĩa là dựng firmware bằng trình dịch của kiến trúc khác.
    for chip in ("ESP32", "ESP32-S3"):
        assert not any(re.search(p, chip, re.I) for p in mau), f"{chip} là Xtensa, không rv32"


def test_manifest_rv32imac_khai_dung_thu_chay_duoc():
    """Manifest phải khai thứ CÓ THẬT trên máy, không khai thứ mong muốn.

    Bảng §2 trước đây ghi `riscv-none-elf-gcc` — không có công thức brew nào. `riscv64-elf-gcc`
    (multilib) thì có, và dựng được rv32imac bằng `-march=rv32imac_zicsr -mabi=ilp32`. Cùng hình
    dạng với DEV-086: khai `fallback: qemu` cho avr8 mới dùng được engine duy nhất chạy được.
    """
    from eide_core.paths import spec_dir

    d = yaml.safe_load((spec_dir() / "isa" / "rv32imac.yaml").read_text(encoding="utf-8"))
    assert d["toolchain"]["compiler"]["name"] == "riscv64-elf-gcc"
    b = d["toolchain"]["build"]
    assert b["march"] == "rv32imac_zicsr" and b["mabi"] == "ilp32"
    # `code.build` chạy lệnh NGUYÊN VĂN (chỉ giải argv[0] thành đường tuyệt đối), nên một
    # placeholder `{march}` sẽ đi thẳng vào dòng lệnh dưới dạng chữ.
    assert "{" not in b["cmd"], f"build.cmd còn placeholder chưa giải: {b['cmd']}"
    assert d["sim"]["engine"] == "qemu"


def test_qemu_co_may_ao_cho_risc_v_va_noi_ro_gioi_han():
    """`QEMU_MACHINE` phải có mục RISC-V, và nó là `virt` — máy ảo CHUNG.

    Khác `arduino-uno`: `virt` chỉ có CPU, bộ nhớ và một UART 16550, không có I2C của ESP32-C3.
    Mọi `expect` chạm ngoại vi thật sẽ ra `unverified`, và đó là câu trả lời ĐÚNG. Bài test chốt
    điều đó để không ai đổi `virt` thành `esp32c3` mà quên rằng bản QEMU của Homebrew không có
    máy ấy — `sim.run` sẽ chết sau khi đã dựng xong nền tảng.
    """
    import re

    from eide.caps.sim import QEMU_MACHINE, QEMU_THEO_ISA

    assert QEMU_THEO_ISA["rv32imac"] == "qemu-system-riscv32"
    khop = [v for k, v in QEMU_MACHINE.items() if re.search(k, "ESP32-C3", re.I)]
    assert khop and khop[0]["machine"] == "virt"
    assert khop[0]["nap"] == "-kernel", "virt nạp bằng -kernel, không phải -bios"


def test_lenh_qemu_lay_tu_manifest_chu_khong_dung_lai_bang_tay(tmp_path):
    """`sim.cmd` của manifest LÀ dòng lệnh, không phải một gợi ý mã dựng lại theo trí nhớ.

    Với rv32imac, chỗ khác nhau giữa hai đường là `-bios none`. Thiếu nó, máy `virt` nạp OpenSBI
    mặc định ở 0x80000000 — đúng địa chỉ linker script đặt firmware — và qemu chết với "Some ROM
    regions are overlapping". Đo được 14/09/2026 trên dự án ESP32-C3 thật: nền tảng dựng xong,
    firmware dịch xong, lượt chạy vẫn chết bằng một lỗi trông như lỗi của người viết firmware.

    Không ai thấy sớm hơn vì armv7e-m và avr8 không khai `sim.cmd`, nên với chúng đường dựng tay
    và đường manifest trùng nhau.
    """
    from eide.caps.sim import _argv

    argv = _argv({"engine": "qemu", "isa": "rv32imac", "chip": "chip:espressif.esp32c3"},
                 "/opt/homebrew/bin/qemu-system-riscv32", tmp_path / "fw.elf", {}, tmp_path)
    assert argv[0] == "/opt/homebrew/bin/qemu-system-riscv32", "argv[0] là exe đã dò được"
    assert "-bios" in argv and argv[argv.index("-bios") + 1] == "none"
    assert argv[-2:] == ["-kernel", str(tmp_path / "fw.elf")]


def test_isa_khong_khai_cmd_thi_van_dung_duong_cu(tmp_path):
    """armv7e-m/avr8 không khai `sim.cmd`; bỏ nhánh dựng tay là làm hỏng hai ISA đang chạy được."""
    from eide.caps.sim import _argv

    argv = _argv({"engine": "simavr", "isa": "avr8", "chip": "chip:atmel.atmega328p",
                  "mcu": "atmega328p"}, "/usr/bin/simavr", tmp_path / "fw.elf", {}, tmp_path)
    assert argv == ["/usr/bin/simavr", "-m", "atmega328p", str(tmp_path / "fw.elf")]
