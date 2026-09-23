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
    # So theo (ref, pin): từ [DEV-212] mỗi nút còn mang `pinfunction` — vai trò chân, thứ mọi
    # luật điện cần. Khẳng định trên dict đầy đủ sẽ đỏ mỗi lần netlist mang thêm một trường.
    assert [(n["ref"], n["pin"]) for n in nets["/I2C1_SCL"]] == [
        ("U1", "42"), ("U2", "4"), ("R1", "1")]

    parts2, nets2 = doc_netlist(_netlist(root, NETLIST_XML, "robot.xml"))
    assert parts2["U2"]["mpn"] == "BME280"
    assert [(n["ref"], n["pin"]) for n in nets2["/SCL"]] == [("U2", "4")]


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


# ---------- BOARD-03 constraints

def _co_pullup(gia_tri="4k7"):
    """Netlist mẫu, đổi giá trị hai điện trở kéo lên."""
    return NETLIST.replace('(comp (ref "R1") (value "4k7"))', f'(comp (ref "R1") (value "{gia_tri}"))') \
                  .replace('(comp (ref "R2") (value "4k7"))', f'(comp (ref "R2") (value "{gia_tri}"))')


def test_TC_I2C1_gioi_han_400kHz_theo_pullup(du_an):
    """tc của BOARD-03, nguyên văn: **"I2C1 limit 400 kHz theo pull-up"**.

    Tốc độ tối đa của một bus I2C không nằm trong datasheet chip mà nằm ở điện trở kéo lên TRÊN
    BOARD NÀY. Không ghi ra thì mã sinh sau đó lấy 400 kHz theo datasheet, và board đọc sai lác
    đác lúc nóng — loại lỗi không tái lập được trên bàn.
    """
    from eide.caps.board import constraints
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    rb = constraints({"board": "robot-main"}, ctx)["constraints"]
    assert rb["bus_limits"]["i2c1"]["max_khz"] == 400
    assert rb["bus_limits"]["i2c1"]["pullup_ohm"] == 4700


def test_pullup_10k_thi_ep_ve_100kHz(du_an):
    """Đối chứng. Không có nó thì `max_khz` có thể là hằng số 400 và test trên vẫn xanh."""
    from eide.caps.board import constraints
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root, _co_pullup("10k"), "g1.net"))}, ctx)
    bus = constraints({"board": "g1"}, ctx)["constraints"]["bus_limits"]["i2c1"]
    assert bus["max_khz"] == 100 and bus["pullup_ohm"] == 10000
    assert "quá" in bus["why"] or "chậm" in bus["why"]


def test_lay_dien_tro_YEU_NHAT_cua_hai_duong(du_an):
    """SCL kéo 4k7 mà SDA kéo 10k thì bus chỉ nhanh bằng đường chậm hơn. Lấy cái nhỏ nhất là tự
    cho mình một tốc độ không có thật."""
    from eide.caps.board import constraints
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    lech = NETLIST.replace('(comp (ref "R2") (value "4k7"))', '(comp (ref "R2") (value "10k"))')
    kicad_netlist({"file": str(_netlist(root, lech, "g2.net"))}, ctx)
    bus = constraints({"board": "g2"}, ctx)["constraints"]["bus_limits"]["i2c1"]
    assert bus["max_khz"] == 100 and bus["pullup_ohm"] == 10000


def test_khong_co_pullup_thi_giu_muc_thap_nhat(du_an):
    from eide.caps.board import constraints
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    khong_r = NETLIST.replace('\n      (node (ref "R1") (pin "1"))', "").replace(
        '\n      (node (ref "R2") (pin "1"))', "")
    kicad_netlist({"file": str(_netlist(root, khong_r, "g3.net"))}, ctx)
    bus = constraints({"board": "g3"}, ctx)["constraints"]["bus_limits"]["i2c1"]
    assert bus["max_khz"] == 100 and bus["pullup_ohm"] is None


def test_doc_duoc_ky_hieu_dien_tro_chen_chu():
    """`4k7` là cách ghi phổ biến nhất trên sơ đồ vì nó không có dấu chấm để mất khi in mờ hay
    khi qua OCR — nên nó phải đọc được, không chỉ dạng `4.7k`."""
    from eide.caps.board import doc_ohm

    assert doc_ohm("4k7") == 4700
    assert doc_ohm("4.7k") == 4700
    assert doc_ohm("2.2k") == 2200
    assert doc_ohm("10k") == 10000
    assert doc_ohm("470") == 470
    assert doc_ohm("1M") == 1_000_000
    assert doc_ohm("DNP") is None and doc_ohm(None) is None


def test_dien_ap_IO_lay_muc_THAP_NHAT(du_an):
    """Nối một chân 3V3 vào net 5 V làm hỏng chip, và cái hỏng ấy xảy ra trước khi có gì để gỡ."""
    from eide.caps.board import constraints
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    hai_muc = NETLIST.replace('(net (code "3") (name "GND")',
                              '(net (code "5") (name "+5V")\n      (node (ref "U1") (pin "9")))\n'
                              '    (net (code "3") (name "GND")')
    kicad_netlist({"file": str(_netlist(root, hai_muc, "g4.net"))}, ctx)
    dv = constraints({"board": "g4"}, ctx)["constraints"]["voltage"]
    assert dv["rails"] == {"+3V3": 3.3, "+5V": 5.0} and dv["io_v"] == 3.3


def test_chua_co_fact_current_thi_None_chu_khong_bia_mot_con_so(du_an):
    """Một ngân sách dòng bịa ra còn tệ hơn không có: mã sinh ra sẽ bật đồng thời mọi thứ vì
    "còn trong hạn mức"."""
    from eide.caps.board import constraints
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    dong = constraints({"board": "robot-main"}, ctx)["constraints"]["current"]
    assert dong["budget_ma"] is None and "extract." in dong["why"]


def test_constraints_ghi_vao_constraints_yaml_va_dung_chung_bang_chan_giu(du_an):
    """Ràng buộc phải NẰM TRONG `constraints.yaml`: mã sinh ra không đọc danh sách cảnh báo, nó
    đọc tệp này. Và bảng chân giữ phải là cùng một bảng với `check_pins` — một chân bị cấm ở
    phép kiểm mà không bị cấm ở ràng buộc thì phát hiện muộn đúng một vòng."""
    import yaml as _yaml

    from eide.caps.board import CHAN_GIU, constraints
    from eide.caps.extract import kicad_netlist

    r, ctx, root = du_an
    r.invoke("project.set_target", {"chip": "STM32F411RE"}, ctx)
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    constraints({"board": "robot-main"}, ctx)

    d = _yaml.safe_load((root / ".eide" / "constraints.yaml").read_text(encoding="utf-8"))
    rb = d["board"]["robot-main"]
    assert rb["bus_limits"]["i2c1"]["max_khz"] == 400
    assert {p["pin"] for p in rb["reserved_pins"]} == set(CHAN_GIU["armv7e-m"])


def test_constraints_chua_co_net_thi_bao_ro(du_an):
    from eide.caps.board import constraints
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        constraints({"board": "khong-co"}, ctx)
    assert e.value.code == "E2000"


# ---------- BOARD-04 propose_fix

def _pin_function(root, chan, fs, fid):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES ('s_pin','ds.pdf',?,'pdf_vendor','gold','vendor-doc')",
                  (hashlib.sha256(b"p").hexdigest(),))
        c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                  " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, f"chip:stm32f411/pin:{chan}", "pin_function",
                   json.dumps({"pin": chan, "functions": fs}), "s_pin", "parser", "gold",
                   1.0, "verified", "A"))
        c.commit()


def test_TC_moi_loai_xung_dot_deu_cho_it_nhat_hai_phuong_an(du_an):
    """tc của BOARD-04: **≥ 2 phương án**. Một phương án duy nhất không phải là lựa chọn — nó là
    một mệnh lệnh đội lốt."""
    from eide.caps.board import propose_fix

    _, ctx, _ = du_an
    for loai in ("af_conflict", "reserved", "address_clash", "missing_pullup", "gi_do_la"):
        ds = propose_fix({"conflict": {"pin": "PB3", "kind": loai}}, ctx)["options"]
        assert len(ds) >= 2, loai
        assert all({"change", "cost", "touches_code"} <= set(o) for o in ds), loai


def test_phuong_an_KHONG_cham_ma_dung_truoc(du_an):
    """"Xếp theo ít thay đổi nhất" — thêm một điện trở rẻ hơn sửa mã, và thứ tự phải nói ra điều
    đó chứ không để người đọc tự xếp."""
    from eide.caps.board import propose_fix

    _, ctx, _ = du_an
    ds = propose_fix({"conflict": {"pin": "/I2C1_SCL", "kind": "missing_pullup"}}, ctx)["options"]
    assert ds[0]["touches_code"] is False and "kéo lên" in ds[0]["change"]
    assert [o["touches_code"] for o in ds] == sorted(o["touches_code"] for o in ds)


def test_cham_ma_PASSING_thi_danh_dau_ask(du_an):
    """`ask_when` của hợp đồng là "Chạm mã passing" — không phải "chạm mã"."""
    from eide.caps.board import propose_fix

    _, ctx, root = du_an
    truoc = propose_fix({"conflict": {"pin": "PB3", "kind": "af_conflict"}}, ctx)["options"]
    assert not any(o["ask"] for o in truoc), "chưa có test xanh nào mà đã bắt hỏi"

    store.ghi_tool_report(store.store_path(root), {"tool": "test_host", "passed": True,
                                                   "at": "2026-09-08T00:00:00Z"})
    sau = propose_fix({"conflict": {"pin": "PB3", "kind": "af_conflict"}}, ctx)["options"]
    assert [o["ask"] for o in sau] == [o["touches_code"] for o in sau]
    assert any(o["ask"] for o in sau)


def test_test_do_thi_khong_bat_hoi(du_an):
    """Đối chứng: có ToolReport nhưng KHÔNG đạt thì mã không "passing", nên không đánh dấu ask.
    Bắt hỏi ở đó chỉ dạy người ta bấm Đồng ý cho nhanh."""
    from eide.caps.board import propose_fix

    _, ctx, root = du_an
    store.ghi_tool_report(store.store_path(root), {"tool": "test_host", "passed": False,
                                                   "at": "2026-09-08T00:00:00Z"})
    ds = propose_fix({"conflict": {"pin": "PB3", "kind": "af_conflict"}}, ctx)["options"]
    assert not any(o["ask"] for o in ds)


def test_chan_thay_the_lay_tu_fact_pin_function(du_an):
    """Mô hình không có bảng chân trong đầu; hỏi nó thì được một tên chân nghe rất đúng cho tới
    lúc nạp. Sinh từ fact thì phương án hoặc có thật, hoặc nói thẳng là chưa tra được."""
    from eide.caps.board import propose_fix

    _, ctx, root = du_an
    chua = propose_fix({"conflict": {"pin": "PB3", "kind": "af_conflict"}}, ctx)["options"]
    assert chua[0]["alternatives"] == [] and "extract.pdf_pinout" in chua[0]["change"]

    _pin_function(root, "PB3", ["SPI1_MOSI", "SWO"], "f_pb3")
    _pin_function(root, "PB5", ["SPI1_MOSI"], "f_pb5")
    _pin_function(root, "PA7", ["SPI1_MOSI"], "f_pa7")
    _pin_function(root, "PC13", ["GPIO"], "f_pc13")
    co = propose_fix({"conflict": {"pin": "PB3", "kind": "af_conflict"}}, ctx)["options"]
    assert co[0]["alternatives"] == ["PA7", "PB5"], "chỉ chân cùng chức năng, và không có chính nó"


# ---------- BOARD-05 mark_lab

NETLIST_DONG_CO = NETLIST.replace(
    '(comp (ref "R2") (value "4k7")))',
    '(comp (ref "R2") (value "4k7"))\n    (comp (ref "U5") (value "DRV8833")))')

XAC_NHAN = {"no_actuator": True, "current_limited": True, "by": "cong"}


def _ctx_nguoi(ctx):
    from eide_core.router import Context as _C

    return _C(project_dir=ctx.project_dir, actor="human", extra=ctx.extra)


def test_by_policy_thi_E3000(du_an):
    """Hợp đồng nêu đích danh. Đánh dấu lab là chỗ một người nhận trách nhiệm."""
    from eide.caps.board import mark_lab
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        mark_lab({**XAC_NHAN, "board": "b", "by": "policy"}, _ctx_nguoi(ctx))
    assert e.value.code == "E3000"


def test_actor_khong_phai_nguoi_thi_E3000(du_an):
    """`by` chỉ là một chuỗi; tác tử điền được. Kiểm mỗi `by` thì tác tử tự cấp cho mình quyền
    tự nạp — đúng thứ mà `eide policy sign` cố ý không làm thành năng lực."""
    from eide.caps.board import mark_lab
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        mark_lab({**XAC_NHAN, "board": "b"}, ctx)          # ctx.actor mặc định là "agent"
    assert e.value.code == "E3000" and "người gọi" in str(e.value)


def test_thieu_mot_trong_hai_xac_nhan_thi_E1000(du_an):
    """Board không có cơ cấu chấp hành nhưng chưa hạn dòng thì vẫn cháy được."""
    from eide.caps.board import mark_lab
    from eide_core.errors import EideError

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        mark_lab({**XAC_NHAN, "board": "b", "current_limited": False}, _ctx_nguoi(ctx))
    assert e.value.code == "E1000" and e.value.data["missing"] == ["current_limited"]


def test_TC_board_co_dong_co_thi_KHONG_lab(du_an):
    """tc của BOARD-05: **"board có động cơ → không lab"**.

    Lời khai của người có thể sai vì người khai không phải người vẽ mạch. Thấy mạch lái động cơ
    trong netlist thì ghi `lab: false` kèm tên linh kiện — người đọc thấy ngay vì sao.
    """
    import yaml as _yaml

    from eide.caps.board import mark_lab
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root, NETLIST_DONG_CO, "h1.net"))}, ctx)
    assert mark_lab({**XAC_NHAN, "board": "h1"}, _ctx_nguoi(ctx)) == {"lab": False}

    d = _yaml.safe_load((root / ".eide" / "autonomy.yaml").read_text(encoding="utf-8"))
    assert d["boards"]["h1"] == {"lab": False, "has_actuator": True,
                                 "reason": d["boards"]["h1"]["reason"]}
    assert "U5" in d["boards"]["h1"]["reason"] and "DRV8833" in d["boards"]["h1"]["reason"]


def test_board_sach_thi_lab_true(du_an):
    """Đối chứng: không có đối chứng thì `lab` có thể là hằng số False và test trên vẫn xanh."""
    import yaml as _yaml

    from eide.caps.board import mark_lab
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    assert mark_lab({**XAC_NHAN, "board": "robot-main"}, _ctx_nguoi(ctx)) == {"lab": True}
    d = _yaml.safe_load((root / ".eide" / "autonomy.yaml").read_text(encoding="utf-8"))
    assert d["boards"]["robot-main"]["lab"] is True
    assert d["boards"]["robot-main"]["has_actuator"] is False


def test_ghi_boards_xong_phai_KY_LAI_niem(du_an):
    """`boards` là một trong bốn khóa `whitelist.KHOA_NIEM`. Ghi vào nó mà không ký lại thì niêm
    vỡ và MỌI phê duyệt dựa trên danh sách trắng ngừng hoạt động — kể cả chính `G-OPS-01` mà
    năng lực này phục vụ."""
    from eide.caps.board import mark_lab
    from eide.caps.extract import kicad_netlist
    from eide_core import whitelist
    from eide_core.paths import spec_dir
    from eide_core.policy import PolicyGate

    _, ctx, root = du_an
    kicad_netlist({"file": str(_netlist(root))}, ctx)
    mark_lab({**XAC_NHAN, "board": "robot-main"}, _ctx_nguoi(ctx))

    import yaml as _yaml
    cfg = {**_yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8")),
           **_yaml.safe_load((root / ".eide" / "autonomy.yaml").read_text(encoding="utf-8"))}
    dat, ly_do = whitelist.kiem(cfg, root / ".eide" / "policy.sig", ctx.extra.get("ledger"))
    assert dat, ly_do

    # và cổng ĐANG CHẠY phải thấy ngay, không đợi phiên sau
    g = ctx.extra["gate"]
    assert isinstance(g, PolicyGate) and g.danh_sach_da_ky
    assert (g.config["boards"] or {})["robot-main"]["lab"] is True


def test_name_dat_ten_board_KHAC_ten_tep_va_qua_duoc_router(du_an):
    """EXTRACT-16 v1.3 (DEV-066). Tên tệp netlist thường là tên bản vẽ, tên board là thứ khác —
    không thống nhất được thì hộ chiếu dựng xong mà `board.build_passport` báo "chưa có net".

    Gọi QUA ROUTER chứ không gọi thẳng hàm: bản đầu nhận `name` và có test xanh, nhưng test gọi
    thẳng nên không ai thấy `additionalProperties: false` chặn nó bằng E1000 ở cửa.
    """
    r, ctx, root = du_an
    run = r.invoke("extract.kicad_netlist",
                   {"file": str(_netlist(root, NETLIST, "ban-ve-v3.net")), "name": "robot-main"},
                   ctx)
    assert run.status == "done", run.error
    assert run.result["board_passport_id"] == "robot-main@1.0.0"
    assert doc_net(root, "robot-main")["/I2C1_SCL"][0]["ref"] == "U1"
    assert doc_net(root, "ban-ve-v3") == {}, "tên tệp không được dùng khi đã nêu `name`"


def test_bang_co_cau_chap_hanh_doc_tu_SPEC_khong_nhung_trong_ma(du_an, monkeypatch):
    """DEV-068 duyệt 08/09: bảng ra `docs/spec/policy/actuators.yaml`, sinh từ POL-17 §3.

    Thêm một họ mạch lái động cơ mới phải là sửa một tệp dữ liệu, không phải sửa và phát hành
    lại mã. Test đổi bảng rồi xác nhận hành vi đổi theo — nếu mẫu còn nhúng trong Python thì
    board có `L298` vẫn bị bắt và test này đỏ.
    """
    from eide.caps import board as m
    from eide.caps.extract import kicad_netlist

    _, ctx, root = du_an
    assert {g["id"] for g in m.cac_co_cau()} == {"motor_driver", "actuator", "power_switch"}

    kicad_netlist({"file": str(_netlist(root, NETLIST_DONG_CO, "i1.net"))}, ctx)
    monkeypatch.setattr(m, "cac_co_cau",
                        lambda: [{"id": "x", "name": "chỉ rơ-le", "patterns": ["RELAY"]}])
    assert m.mark_lab({**XAC_NHAN, "board": "i1"}, _ctx_nguoi(ctx)) == {"lab": True}, \
        "DRV8833 không còn trong bảng thì không được bắt nữa"


# ---------- [DEV-212] Luật điện: bắt được lỗi thật, KHÔNG bịa lỗi trên mạch sạch

def _nap_netlist(r, ctx, ten_tep: str) -> str:
    from pathlib import Path as _P
    f = _P("docs/test/usecase/du-lieu") / ten_tep
    run = r.invoke("extract.kicad_netlist", {"file": str(f.resolve())}, ctx)
    assert run.status == "done", run.error
    return run.result["board_passport_id"]


def test_bat_duoc_ba_lop_loi_dien_cai_san(du_an):
    """Ba lớp lỗi điện trên netlist mẫu — [DEV-212].

    Hợp đồng BOARD-02 đã ghi *"thiếu pull-up I2C"* trong danh sách quy tắc từ đầu; hai luật kia
    (quá áp miền nguồn, reset thả nổi) thêm vào cùng tinh thần. Đây là những lỗi mà mắt người
    dễ bỏ qua nhất: trên sơ đồ, một dây nối tới `VBUS` trông y hệt một dây nối tới `+3V3`.
    """
    r, ctx, _ = du_an
    bid = _nap_netlist(r, ctx, "mach-co-loi.net")
    kq = r.invoke("board.check_pins", {"board": bid}, ctx)
    assert kq.status == "done", kq.error
    loai = {x["kind"] for x in kq.result["conflicts"]}
    assert "missing_pullup" in loai, "không thấy I2C thiếu trở kéo"
    assert "overvoltage" in loai, "không thấy chân nguồn IC nằm trên net 5 V"
    assert "floating_reset" in loai, "không thấy chân reset thả nổi"
    qa = [x for x in kq.result["conflicts"] if x["kind"] == "overvoltage"]
    assert qa[0]["severity"] == "blocker", "quá áp phải là blocker — hỏng ngay lần cắm đầu"


def test_mach_SACH_thi_KHONG_bao_loi_nao(du_an):
    """Nới luật để bắt được lỗi KHÔNG được đổi lấy báo động giả.

    Một bộ rà soát báo lỗi trên mạch đúng thì người dùng thôi đọc nó — và khi ấy nó không còn
    bảo vệ được gì. Đây là vế thứ hai, và là vế dễ quên.

    Chính bài kiểm này đã bắt được một lỗi trong BỘ DỮ LIỆU MẪU: bản đầu của `mach-khong-loi`
    có `C4` pin 1 nằm trên cả `+3V3` lẫn `NRST` — một tụ không thể có một chân trên hai net.
    Nếu không phát hiện thì TC040 (đo báo động giả) sẽ đo trên một mạch không sạch.
    """
    r, ctx, _ = du_an
    bid = _nap_netlist(r, ctx, "mach-khong-loi.net")
    kq = r.invoke("board.check_pins", {"board": bid}, ctx)
    assert kq.status == "done", kq.error
    assert kq.result["conflicts"] == [], \
        f"báo động giả trên mạch sạch: {[x['kind'] for x in kq.result['conflicts']]}"


def test_KHONG_TRA_DUOC_NET_thi_bao_loi_chu_khong_noi_mach_sach(du_an):
    """**Không có dữ liệu ≠ không có lỗi.** [DEV-212]

    Trả `conflicts: []` khi chưa tra được net nào là nói "bo mạch này sạch" cho một bo mạch
    chưa hề được đọc. Đo 23/09/2026: `check_pins` báo 0 xung đột cho netlist có bốn lỗi cài
    sẵn, chỉ vì tên board truyền vào mang hậu tố `@1.0.0` còn fact ghi theo tên trần.

    Đúng khuôn hỏng của [DEV-183] — một câu trả lời trấn an rút từ hư không nguy hiểm hơn một
    ô trống, vì người đọc tin nó và thôi kiểm.
    """
    r, ctx, _ = du_an
    kq = r.invoke("board.check_pins", {"board": "board-khong-ton-tai"}, ctx)
    assert kq.status == "failed" and kq.error["eide_code"] == "E2000"
    assert "KHÔNG kết luận bo mạch sạch" in kq.error["message"]


def test_id_ho_chieu_va_ten_board_tra_ra_CUNG_MOT_bo_mach(du_an):
    """`extract.kicad_netlist` trả `mach-co-loi@1.0.0`; fact ghi `board:mach-co-loi`."""
    from eide.caps.board import doc_net
    r, ctx, root = du_an
    _nap_netlist(r, ctx, "mach-co-loi.net")
    assert len(doc_net(root, "mach-co-loi@1.0.0")) == len(doc_net(root, "mach-co-loi")) > 0


def test_netlist_GIU_vai_tro_chan(du_an):
    """Không có `pinfunction` thì không luật điện nào suy được gì."""
    from eide.caps.board import doc_net
    r, ctx, root = du_an
    _nap_netlist(r, ctx, "mach-co-loi.net")
    nodes = doc_net(root, "mach-co-loi")["VBUS_5V"]
    assert any(n.get("pinfunction") == "VDDIO" for n in nodes), \
        f"vai trò chân bị vứt mất khi rút netlist: {nodes}"
