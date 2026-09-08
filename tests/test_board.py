"""Nhóm board.* + EXTRACT-16 — CDS-12.2; STP-05 TC-20, TC-21.

TC-20: hộ chiếu board dựng từ netlist, "BME280 gắn 0x76 từ SDO=GND".
TC-21: "phát hiện PB3 LED+MOSI, PA13".

Cả nhóm làm việc trên BẢN THIẾT KẾ, không trên board thật — nên nó kiểm được đầy đủ mà không
cần phần cứng, và đó cũng là giới hạn của nó.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from eide.caps.board import build_passport, check_pins, doc_net
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

NETLIST = """(export (version "E")
  (components
    (comp (ref "U1") (value "STM32F411CEU6") (footprint "Package_QFP:LQFP-48")
      (fields (field (name "MPN") "STM32F411CEU6")))
    (comp (ref "U2") (value "BME280") (footprint "Sensor:LGA-8"))
    (comp (ref "R1") (value "4k7"))
    (comp (ref "R2") (value "4k7")))
  (nets
    (net (code "1") (name "/I2C1_SCL")
      (node (ref "U1") (pin "42"))
      (node (ref "U2") (pin "4"))
      (node (ref "R1") (pin "1")))
    (net (code "2") (name "/I2C1_SDA")
      (node (ref "U1") (pin "43"))
      (node (ref "U2") (pin "6"))
      (node (ref "R2") (pin "1")))
    (net (code "3") (name "GND")
      (node (ref "U2") (pin "5")))
    (net (code "4") (name "+3V3")
      (node (ref "U1") (pin "1"))
      (node (ref "R1") (pin "2"))
      (node (ref "R2") (pin "2")))))
"""

NETLIST_XML = """<?xml version="1.0" encoding="UTF-8"?>
<export version="E">
  <components>
    <comp ref="U2"><value>BME280</value><footprint>Sensor:LGA-8</footprint>
      <fields><field name="MPN">BME280</field></fields></comp>
  </components>
  <nets>
    <net code="1" name="/SCL"><node ref="U2" pin="4"/></net>
  </nets>
</export>
"""


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án board"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


def _netlist(root, noi_dung=NETLIST, ten="robot-main.net"):
    f = root / ten
    f.write_text(noi_dung, encoding="utf-8")
    return f


def _fact_dia_chi_bme280(root):
    """Hộ chiếu LINH KIỆN khai hai địa chỉ khả dĩ kèm điều kiện — đúng như datasheet nói."""
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s_bme", "bme280.pdf", hashlib.sha256(b"b").hexdigest(), "pdf_vendor",
                   "gold", "vendor-doc"))
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  ("f_bme280addr", "part:bosch.bme280", "address",
                   json.dumps({"sdo=gnd": "0x76", "sdo=vdd": "0x77"}),
                   "s_bme", "parser", "gold", 1.0, "verified", "A"))
        c.commit()


# ---------- EXTRACT-16

def test_doc_duoc_ca_hai_dang_netlist(du_an):
    """`.net` s-expression và kicadxml là hai dạng của cùng một thứ. Bắt cài cả bộ KiCad để đọc
    một tệp s-expression là dựng một rào cản không có lý do."""
    from eide.caps.extract import doc_netlist

    _, _, root = du_an
    parts, nets = doc_netlist(_netlist(root))
    assert set(parts) == {"U1", "U2", "R1", "R2"}
    assert parts["U1"]["mpn"] == "STM32F411CEU6"
    assert nets["/I2C1_SCL"] == [{"ref": "U1", "pin": "42"}, {"ref": "U2", "pin": "4"},
                                 {"ref": "R1", "pin": "1"}]

    parts2, nets2 = doc_netlist(_netlist(root, NETLIST_XML, "robot.xml"))
    assert parts2["U2"]["mpn"] == "BME280" and nets2["/SCL"] == [{"ref": "U2", "pin": "4"}]


def test_netlist_sinh_fact_net_va_package(du_an):
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    out = kicad_netlist({"file": str(_netlist(root))}, ctx)
    assert out["nets"] == 4 and out["parts"] == 4
    assert doc_net(root, "robot-main")["/I2C1_SCL"][0]["ref"] == "U1"


def test_so_do_nguon_khong_co_kicad_cli_thi_E4001(du_an, monkeypatch):
    """Nói rõ đường ra: có sẵn `.net` thì không cần cài gì."""
    from eide.caps.extract import kicad_netlist
    from eide_core.errors import EideError

    _, ctx, root = du_an
    (root / "robot.kicad_sch").write_text("(kicad_sch)", encoding="utf-8")
    monkeypatch.setattr("eide_core.tools.which", lambda _t: None)
    with pytest.raises(EideError) as e:
        kicad_netlist({"file": str(root / "robot.kicad_sch")}, ctx)
    assert e.value.code == "E4001" and "kicad-cli" in e.value.data["missing"]


def test_tep_khong_phai_netlist_thi_bao_ro(du_an):
    from eide.caps.extract import kicad_netlist
    from eide_core.errors import EideError

    _, ctx, root = du_an
    (root / "a.txt").write_text("xin chào", encoding="utf-8")
    with pytest.raises(EideError) as e:
        kicad_netlist({"file": str(root / "a.txt")}, ctx)
    assert e.value.code == "E6001"


# ---------- BOARD-01

def test_TC20_dia_chi_BME280_suy_tu_SDO_noi_GND(du_an):
    """tc của BOARD-01, nguyên văn: **"BME280 gắn 0x76 từ SDO=GND"**.

    Đây là chỗ đáng giá nhất của cả năng lực. Datasheet nói CẢ HAI địa chỉ khả dĩ; chỉ netlist
    của board NÀY mới nói được cái nào đúng. Không suy ra thì mã sinh sau đó phải đoán, và một
    nửa số board sẽ im lặng không trả lời.
    """
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    _fact_dia_chi_bme280(root)
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    build_passport({"sources": [], "name": "robot-main"}, ctx)

    with store.open_store(store.store_path(root)) as c:
        r = c.execute("SELECT value, locator FROM fact WHERE predicate='address'"
                      " AND subject LIKE 'board:robot-main/part:U2'").fetchone()
    assert r is not None, "không suy được địa chỉ cho U2"
    assert json.loads(r[0]) == "0x76"
    assert "gnd" in r[1].lower()


def test_dia_chi_doi_theo_net_ma_SDO_noi_vao(du_an):
    """Đối chứng: cùng linh kiện, cùng datasheet, SDO nối lên 3V3 → 0x77. Nếu không thì phép suy
    này chỉ là chép hằng số đầu tiên trong danh sách."""
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    _fact_dia_chi_bme280(root)
    bien = NETLIST.replace('(net (code "3") (name "GND")\n      (node (ref "U2") (pin "5")))',
                           '(net (code "3") (name "GND"))')
    bien = bien.replace('(net (code "4") (name "+3V3")\n      (node (ref "U1") (pin "1"))',
                        '(net (code "4") (name "+3V3")\n      (node (ref "U2") (pin "5"))\n      (node (ref "U1") (pin "1"))')
    kicad_netlist({"file": str(_netlist(root, bien, "b1.net"))}, ctx)
    build_passport({"sources": [], "name": "b1"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        r = c.execute("SELECT value FROM fact WHERE predicate='address'"
                      " AND subject LIKE 'board:b1/part:U2'").fetchone()
    assert r and json.loads(r[0]) == "0x77"


def test_bus_I2C_nhan_dang_kem_pullup(du_an):
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    out = build_passport({"sources": [], "name": "robot-main"}, ctx)
    assert out["nets"] == 4 and out["board_passport_id"] == "robot-main@1.0.0"
    with store.open_store(store.store_path(root)) as c:
        r = c.execute("SELECT value FROM fact WHERE subject='board:robot-main/bus:i2c1'"
                      " AND predicate='net'").fetchone()
    v = json.loads(r[0])
    assert v["kind"] == "i2c" and v["pullup"] is True
    assert set(v["lines"]) == {"scl", "sda"}


def test_thieu_pullup_thanh_canh_bao(du_an):
    """I2C không có điện trở kéo lên thì bus im lặng, và triệu chứng giống hệt cảm biến hỏng."""
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    khong_r = NETLIST.replace('\n      (node (ref "R1") (pin "1"))', "").replace(
        '\n      (node (ref "R2") (pin "1"))', "")
    kicad_netlist({"file": str(_netlist(root, khong_r, "c1.net"))}, ctx)
    out = build_passport({"sources": [], "name": "c1"}, ctx)
    assert any("kéo lên" in w for w in out["warnings"]), out["warnings"]


def test_tier_lay_theo_nguon_THAP_NHAT(du_an):
    """Bước 2 của hợp đồng. Một kết luận rút từ nhiều nguồn chỉ chắc bằng nguồn yếu nhất — lấy
    tier cao nhất là tự nâng hạng cho một suy luận."""
    from eide.caps.board import _tier_thap_nhat

    _, _, root = du_an
    with store.open_store(store.store_path(root)) as c:
        for sid, tier in (("s_g", "gold"), ("s_b", "bronze")):
            c.execute("INSERT INTO source (id,uri,sha256,kind,tier,license) VALUES (?,?,?,?,?,?)",
                      (sid, sid, hashlib.sha256(sid.encode()).hexdigest(), "pdf", tier, "MIT"))
        c.commit()
    tier, canh = _tier_thap_nhat(root, ["s_g", "s_b"])
    assert tier == "bronze" and canh and "bronze" in canh[0]
    assert _tier_thap_nhat(root, ["s_g"]) == ("gold", [])


def test_chua_co_net_thi_bao_ro_chu_khong_tao_ho_chieu_rong(du_an):
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        build_passport({"sources": [], "name": "khong-co"}, ctx)
    assert e.value.code == "E2000"


# ---------- BOARD-02

def test_TC21_chan_hai_chuc_nang_bi_phat_hien(du_an):
    """TC-21: "phát hiện PB3 LED+MOSI". Một chân nối vào hai net khác nhau là chuyện ĐẾM ĐƯỢC —
    hỏi mô hình chỉ thêm một cơ hội để nó bỏ sót."""
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    hai = NETLIST.replace('(net (code "3") (name "GND")\n      (node (ref "U2") (pin "5")))',
                          '(net (code "3") (name "/LED")\n      (node (ref "U1") (pin "42")))')
    kicad_netlist({"file": str(_netlist(root, hai, "d1.net"))}, ctx)
    ds = check_pins({"board": "d1"}, ctx)["conflicts"]
    af = [x for x in ds if x["kind"] == "af_conflict"]
    assert af and af[0]["pin"] == "U1.42" and af[0]["severity"] == "blocker"
    assert "/I2C1_SCL" in af[0]["detail"] and "/LED" in af[0]["detail"]


def test_TC21_chan_giu_PA13_bi_phat_hien(du_an):
    """TC-21 nêu đích danh PA13 (SWDIO). Mức `major` chứ không `blocker`: dùng SWO cho một LED là
    chuyện làm được và người ta vẫn làm — đánh blocker cho mọi trường hợp thì phép kiểm này chặn
    cả thiết kế cố ý, và người ta sẽ tắt nó."""
    from eide.caps.extract import kicad_netlist

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    pa13 = NETLIST.replace('(net (code "3") (name "GND")\n      (node (ref "U2") (pin "5")))',
                           '(net (code "3") (name "PA13")\n      (node (ref "U1") (pin "34")))')
    kicad_netlist({"file": str(_netlist(root, pa13, "e1.net"))}, ctx)
    ds = check_pins({"board": "e1"}, ctx)["conflicts"]
    giu = [x for x in ds if x["kind"] == "reserved"]
    assert giu and giu[0]["pin"] == "PA13" and giu[0]["severity"] == "major"
    assert "SWDIO" in giu[0]["detail"]


def test_hai_module_cung_xin_mot_chan_trong_ke_hoach(du_an):
    """Xét cả HwMap DỰ KIẾN — phát hiện xung đột sau khi đã sinh mã và đã nạp thì cái giá là một
    lần gỡ lỗi trên phần cứng; phát hiện lúc còn là kế hoạch thì cái giá là đổi một dòng."""
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    ds = check_pins({"board": "robot-main", "plan": {"hw_map": [
        {"module_id": "mod_led", "pin": "PB3"},
        {"module_id": "mod_spi", "pin": "PB3"}]}}, ctx)["conflicts"]
    af = [x for x in ds if x["kind"] == "af_conflict" and x["pin"] == "PB3"]
    assert af and "mod_led" in af[0]["detail"] and "mod_spi" in af[0]["detail"]


def test_trung_dia_chi_tren_cung_bus(du_an):
    """Hai thiết bị cùng địa chỉ thì bus trả dữ liệu của con nào không ai đoán được, và triệu
    chứng là "cảm biến đọc ra số lạ" chứ không phải một lỗi rõ ràng."""
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES ('s_bme','x',?,'pdf','gold','MIT')", (hashlib.sha256(b"x").hexdigest(),))
        for ref in ("U2", "U3"):
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                      " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                      (f"f_dc{ref}", f"board:robot-main/part:{ref}", "address",
                       json.dumps("0x76"), "s_bme", "rule", "gold", 1.0, "normalized", "A"))
        c.commit()
    ds = check_pins({"board": "robot-main"}, ctx)["conflicts"]
    trung = [x for x in ds if x["kind"] == "address_clash"]
    assert trung and "U2" in trung[0]["detail"] and "U3" in trung[0]["detail"]


def test_board_sach_thi_khong_bao_gi(du_an):
    """Đối chứng cho cả bốn quy tắc: một board đúng phải im lặng, nếu không thì mọi cảnh báo ở
    trên chỉ là nhiễu."""
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    assert check_pins({"board": "robot-main"}, ctx)["conflicts"] == []


def test_check_pins_cung_bao_thieu_pullup(du_an):
    """Cùng một vấn đề xuất hiện ở hai chỗ với hai vai khác nhau: `build_passport` nêu nó như
    một CẢNH BÁO lúc dựng hộ chiếu, `check_pins` nêu nó như một CONFLICT lúc rà thiết kế. Bản
    đầu chỉ có test cho chỗ thứ nhất, nên nhánh ở `check_pins` gỡ ra không test nào đỏ.
    """
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    khong_r = NETLIST.replace('\n      (node (ref "R1") (pin "1"))', "").replace(
        '\n      (node (ref "R2") (pin "1"))', "")
    kicad_netlist({"file": str(_netlist(root, khong_r, "f1.net"))}, ctx)
    ds = check_pins({"board": "f1"}, ctx)["conflicts"]
    thieu = [x for x in ds if x["kind"] == "missing_pullup"]
    assert {x["pin"] for x in thieu} == {"/I2C1_SCL", "/I2C1_SDA"}
    assert thieu[0]["severity"] == "major"


# ---------- DOC-05 bringup_guide (đóng chuỗi Z-07)

def test_bringup_guide_co_du_sau_muc_va_so_that(du_an):
    """tc TC-77. Tài liệu viết cho người ngồi trước một board CHƯA TỪNG CHẠY, nên nó phải trả
    lời đúng thứ tự các câu hỏi thật — không phải là một bản tóm tắt đẹp."""
    from eide.caps.doc import bringup_guide
    from eide.caps.extract import kicad_netlist

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    md = Path(bringup_guide({"board": "robot-main"}, ctx)["path"]).read_text(encoding="utf-8")

    for muc in ("Cấp nguồn", "Cắm probe", "Nạp firmware", "Kiểm đúng chip", "Xem UART",
                "xem chỗ này trước"):
        assert muc in md, muc
    # số THẬT từ manifest armv7e-m, không phải chữ chung chung
    assert "probe-rs" in md and "115200" in md and "4000 kHz" in md
    assert "+3V3" in md and "GND" in md


def test_bringup_guide_NOI_RO_cho_chua_co_du_lieu(du_an):
    """Một hướng dẫn bringup nghe trôi chảy mà thiếu số thật là thứ dẫn người ta đi sai rồi mới
    biết. Chưa ghim ISA thì phải nói là chưa, kèm năng lực cần chạy."""
    from eide.caps.doc import bringup_guide
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    md = Path(bringup_guide({"board": "robot-main"}, ctx)["path"]).read_text(encoding="utf-8")
    assert md.count("Chưa có dữ liệu") >= 3
    assert "project.set_target" in md


def test_bringup_guide_lay_loi_tu_SO_LOI_cua_du_an(du_an):
    """Một mục "lỗi thường gặp" chép từ Internet thì ai cũng đã đọc rồi. Cái có ích là lỗi mà
    DỰ ÁN NÀY đã gặp — nó nói đúng board này, đúng toolchain này."""
    from eide.caps.doc import bringup_guide
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO error_ledger (id, role, kind, negative_prompt, at)"
                  " VALUES (?,?,?,?,?)",
                  ("el_1", "coder", "link", "thiếu -lm khi dùng sqrt", "2026-09-08T00:00:00Z"))
        c.commit()
    md = Path(bringup_guide({"board": "robot-main"}, ctx)["path"]).read_text(encoding="utf-8")
    assert "thiếu -lm khi dùng sqrt" in md and "**link**" in md


def test_chuoi_Z07_du_nang_luc():
    """Z-07 "dự án mới từ zip" là chuỗi đầu tiên đủ năng lực cho MỌI bước. Test này giữ điều đó
    khỏi tụt đi trong im lặng khi ai đó đổi `chains.json` hoặc gỡ một năng lực."""
    import importlib
    import json as _json
    import pkgutil

    import eide.caps
    from eide_core.paths import spec_dir
    from eide_core.registry import get_registry

    chains = _json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    z07 = next(c for c in chains if "Z-07" in c["ten"])
    can = {n["cap"] for n in z07["nodes"]}

    for m in pkgutil.iter_modules(eide.caps.__path__):
        importlib.import_module(f"eide.caps.{m.name}")
    co = {c.spec.id for c in get_registry().list() if c.implemented}
    assert not (can - co), f"Z-07 tụt lại: thiếu {sorted(can - co)}"
