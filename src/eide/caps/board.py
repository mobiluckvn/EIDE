"""Namespace board.* — CDS-12.2 (BOARD-01…05); POL-17 §3 (danh sách board lab);
APD-08 §3 (G-OPS); DDD-14 (passport kind=board, fact `net`/`address`).

Nhóm này làm việc trên **bản thiết kế**, không trên board thật: netlist, BOM, hộ chiếu linh
kiện. Đó là lý do nó chạy được trước khi có phần cứng — và cũng là giới hạn của nó: nó nói được
"hai module cùng đòi PB3" nhưng không nói được "chân PB3 trên board này có chập không".
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import yaml

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# Tên net theo quy ước sơ đồ. Không đoán bằng mô hình: tên net là do người thiết kế đặt và
# những cái dưới đây là quy ước gần như phổ quát trong KiCad/Altium.
RE_NGUON = re.compile(r"^/?(\+?[0-9]V[0-9]?|VCC|VDD|VBAT|VIN|3V3|5V|1V8)$", re.IGNORECASE)
RE_DAT = re.compile(r"^/?(GND|AGND|DGND|VSS|GNDA)$", re.IGNORECASE)
RE_I2C = {"scl": re.compile(r"(^|[/_])SCL", re.IGNORECASE),
          "sda": re.compile(r"(^|[/_])SDA", re.IGNORECASE)}
RE_SPI = {"sck": re.compile(r"(^|[/_])(SCK|SCLK)", re.IGNORECASE),
          "mosi": re.compile(r"(^|[/_])(MOSI|SDO|COPI)", re.IGNORECASE),
          "miso": re.compile(r"(^|[/_])(MISO|SDI|CIPO)", re.IGNORECASE)}
RE_DIEN_TRO = re.compile(r"^R\d+$")

# Chân KHÔNG được dùng lại — TC-21 gọi tên hai trong số này (PA13 là SWDIO, BOOT0 chọn chế độ
# khởi động). Dùng chúng cho việc khác thì hoặc mất đường gỡ lỗi, hoặc board không boot.
CHAN_GIU = {
    "armv7e-m": {"PA13": "SWDIO", "PA14": "SWCLK", "PB3": "SWO (JTAG TDO)",
                 "PB4": "NJTRST", "BOOT0": "chọn chế độ khởi động", "NRST": "reset"},
}


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm board.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _bid(board: str) -> str:
    return f"board:{re.sub(r'[^A-Za-z0-9_.-]+', '-', board).lower()}"


def doc_net(root: Path, board: str) -> dict[str, list[dict[str, str]]]:
    """Các net của một board, từ fact `net` mà `extract.kicad_netlist` đã ghi."""
    db = store.store_path(root)
    if not db.exists():
        return {}
    with store.open_store(db) as c:
        rows = c.execute("SELECT subject, value FROM fact WHERE predicate='net'"
                         " AND subject LIKE ? AND status NOT IN ('superseded','rejected')",
                         (f"{_bid(board)}/net:%",)).fetchall()
    ra: dict[str, list[dict[str, str]]] = {}
    for _subj, gt in rows:
        try:
            v = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            continue
        if isinstance(v, dict) and v.get("name"):
            ra[str(v["name"])] = list(v.get("nodes") or [])
    return ra


def _cac_board(root: Path) -> list[str]:
    """Tên các board đã có ít nhất một fact `net` trong store."""
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        rows = c.execute("SELECT DISTINCT subject FROM fact WHERE predicate='net'"
                         " AND subject LIKE 'board:%/net:%'"
                         " AND status NOT IN ('superseded','rejected')").fetchall()
    return sorted({str(s).split("/", 1)[0].split(":", 1)[1] for (s,) in rows})


def doc_part(root: Path, board: str) -> dict[str, dict[str, Any]]:
    db = store.store_path(root)
    if not db.exists():
        return {}
    with store.open_store(db) as c:
        rows = c.execute("SELECT subject, value FROM fact WHERE predicate='package'"
                         " AND subject LIKE ? AND status NOT IN ('superseded','rejected')",
                         (f"{_bid(board)}/part:%",)).fetchall()
    ra: dict[str, dict[str, Any]] = {}
    for subj, gt in rows:
        try:
            v = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            continue
        ra[str(subj).rsplit(":", 1)[-1]] = v if isinstance(v, dict) else {}
    return ra


# ---------------------------------------------------------------- BOARD-01 build_passport


@capability("board.build_passport")
def build_passport(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: BOARD-01 — CDS-12.2; DDD-14 (passport kind=board). tc: TC-20, "BME280 gắn 0x76 từ
    SDO=GND"; ask "Từ ảnh"; undo `supersede_facts`.

    Hợp nhất net và linh kiện thành một **hộ chiếu board**, rồi suy ba thứ mà bản thân netlist
    không nói ra: đâu là bus, đâu là nguồn, và **địa chỉ I2C thật của từng cảm biến**.

    Địa chỉ là chỗ đáng giá nhất. Một BME280 có hai địa chỉ khả dĩ, `0x76` hay `0x77`, tùy chân
    SDO nối xuống GND hay lên VDD. Datasheet nói cả hai; chỉ **netlist của board này** mới nói
    được cái nào đúng. Không suy ra thì mã sinh sau đó phải đoán, và một nửa số board sẽ im
    lặng không trả lời.

    `tier` của fact suy ra lấy theo **nguồn thấp nhất** đã dùng (bước 2): một địa chỉ suy từ
    netlist vàng cộng datasheet bạc thì chỉ chắc bằng phần bạc.
    """
    root = _root(ctx)
    ten = params.get("name") or _ten_tu_nguon(root, params["sources"])
    nets = doc_net(root, ten)
    parts = doc_part(root, ten)
    if not nets:
        # `candidates` là các board ĐÃ có net, không phải linh kiện. Chỗ này sai nhất là khi
        # `extract.kicad_netlist` đặt tên board theo tên tệp (`robot`) còn người gọi hỏi tên
        # board (`robot-main`): nghe như "chưa trích netlist" trong khi netlist đã có, chỉ khác
        # tên. Liệt kê tên đang có thì người đọc thấy ngay chuyện đó. Xem DEV-066.
        co = _cac_board(root)
        raise EideError("E2000", f"Chưa có net nào cho board `{ten}` — chạy "
                        "`extract.kicad_netlist` trước"
                        + (f" (board đang có net: {', '.join(co)})" if co else ""),
                        exists=co, candidates=co, missing=[f"net:{ten}"])

    tier, canh_bao = _tier_thap_nhat(root, params["sources"])
    facts: list[dict[str, Any]] = []
    sid = _sid_dau(root, params["sources"])

    bus = _suy_bus(nets)
    for ten_bus, chi_tiet in sorted(bus.items()):
        facts.append({"subject": f"{_bid(ten)}/bus:{ten_bus}", "predicate": "net",
                      "value": chi_tiet, "source_id": sid, "method": "rule", "tier": tier,
                      "confidence": 0.9, "locator": f"bus:{ten_bus}"})

    for ref, dia_chi, ly_do in _suy_dia_chi(root, nets, parts):
        facts.append({"subject": f"{_bid(ten)}/part:{ref}", "predicate": "address",
                      "value": dia_chi, "source_id": sid, "method": "rule", "tier": tier,
                      "confidence": 0.9, "locator": ly_do})

    thieu_pullup = [b for b, d in bus.items() if d.get("kind") == "i2c" and not d.get("pullup")]
    canh_bao += [f"bus `{b}` là I2C nhưng không thấy điện trở kéo lên trên SCL/SDA" for b in thieu_pullup]
    if not parts:
        canh_bao.append("không có linh kiện nào — netlist chỉ có net, không suy được địa chỉ")

    from eide.caps.passport import import_
    pid = f"{_bid(ten).split(':', 1)[1]}@1.0.0"
    if facts:
        import_({"batch": {"facts": facts, "passport_id": pid, "kind": "board",
                           "reason": "board.build_passport",
                           "header": {"name": ten, "nets": len(nets), "parts": len(parts)}},
                 "actor": ctx.actor}, ctx)
    return {"board_passport_id": pid, "nets": len(nets), "warnings": canh_bao}


def _ten_tu_nguon(root: Path, sources: list[str]) -> str:
    """Tên board suy từ hộ chiếu board đã có. Không có thì lỗi rõ ràng — đoán một cái tên rồi
    tạo hộ chiếu thứ hai cho cùng một board là cách sinh ra hai sự thật."""
    db = store.store_path(root)
    if db.exists():
        with store.open_store(db) as c:
            r = c.execute("SELECT id FROM passport WHERE kind='board' ORDER BY created_at DESC"
                          " LIMIT 1").fetchone()
        if r:
            return str(r[0]).split("@")[0]
    raise EideError("E1000", "Không suy được tên board — truyền `name`", sources=list(sources))


def _sid_dau(root: Path, sources: list[str]) -> str:
    """Nguồn để gắn cho fact suy ra. Ưu tiên nguồn bên gọi nêu; không có thì nguồn netlist."""
    db = store.store_path(root)
    if db.exists():
        with store.open_store(db) as c:
            for s in sources:
                if c.execute("SELECT 1 FROM source WHERE id=?", (s,)).fetchone():
                    return s
            r = c.execute("SELECT id FROM source WHERE kind='netlist' ORDER BY fetched_at DESC"
                          " LIMIT 1").fetchone()
            if r:
                return str(r[0])
    raise EideError("E2000", "Không có nguồn nào để gắn cho fact suy ra",
                    exists=[], candidates=list(sources), missing=["source"])


def _tier_thap_nhat(root: Path, sources: list[str]) -> tuple[str, list[str]]:
    """Bước 2: "tier theo nguồn thấp nhất". Một kết luận rút từ nhiều nguồn chỉ chắc bằng nguồn
    yếu nhất trong số đó — lấy tier cao nhất là tự nâng hạng cho một suy luận."""
    thu_tu = ["bronze", "silver", "gold"]
    db = store.store_path(root)
    co: list[str] = []
    if db.exists() and sources:
        with store.open_store(db) as c:
            co = [str(r[0]) for r in c.execute(
                f"SELECT tier FROM source WHERE id IN ({','.join('?' * len(sources))})",  # noqa: S608
                list(sources)).fetchall()]
    if not co:
        return "gold", []
    thap = min(co, key=lambda t: thu_tu.index(t) if t in thu_tu else 0)
    canh = ([] if thap == "gold" else
            [f"tier của kết luận hạ xuống `{thap}` theo nguồn thấp nhất trong {sorted(set(co))}"])
    return thap, canh


def _suy_bus(nets: dict[str, list[dict[str, str]]]) -> dict[str, dict[str, Any]]:
    """Nhận dạng bus từ TÊN net và từ việc có điện trở kéo lên hay không."""
    ra: dict[str, dict[str, Any]] = {}
    for ten, nodes in nets.items():
        refs = [n.get("ref", "") for n in nodes]
        for vai, mau in RE_I2C.items():
            if mau.search(ten):
                d = ra.setdefault(_ten_bus(ten, "i2c"), {"kind": "i2c", "lines": {}})
                d["lines"][vai] = {"net": ten, "nodes": nodes}
                if any(RE_DIEN_TRO.fullmatch(r) for r in refs):
                    d["pullup"] = True
        for vai, mau in RE_SPI.items():
            if mau.search(ten):
                d = ra.setdefault(_ten_bus(ten, "spi"), {"kind": "spi", "lines": {}})
                d["lines"][vai] = {"net": ten, "nodes": nodes}
        if RE_NGUON.match(ten):
            ra.setdefault("power", {"kind": "power", "lines": {}})["lines"][ten] = {"nodes": nodes}
        elif RE_DAT.match(ten):
            ra.setdefault("ground", {"kind": "ground", "lines": {}})["lines"][ten] = {"nodes": nodes}
    return ra


def _ten_bus(ten_net: str, loai: str) -> str:
    """`/I2C1_SCL` → `i2c1`; không có tiền tố thì gộp về `i2c`."""
    m = re.search(r"(I2C|SPI)\s*(\d+)", ten_net, re.IGNORECASE)
    return f"{loai}{m.group(2)}" if m else loai


def _suy_dia_chi(root: Path, nets: dict[str, list[dict[str, str]]],
                 parts: dict[str, dict[str, Any]]) -> list[tuple[str, Any, str]]:
    """Địa chỉ I2C thật của từng linh kiện, từ chân chọn địa chỉ nối đi đâu.

    tc của BOARD-01 nói thẳng một ca: **"BME280 gắn 0x76 từ SDO=GND"**. Cách suy chung: hộ chiếu
    của linh kiện khai các địa chỉ khả dĩ kèm ĐIỀU KIỆN (`sdo=gnd` → 0x76, `sdo=vdd` → 0x77);
    netlist nói chân ấy nối vào net nào; ghép hai thứ lại ra một địa chỉ duy nhất.
    """
    ten_dat = {t for t in nets if RE_DAT.match(t)}
    ten_nguon = {t for t in nets if RE_NGUON.match(t)}
    ra: list[tuple[str, Any, str]] = []
    for ref, pt in sorted(parts.items()):
        ung_vien = _dia_chi_kha_di(root, pt)
        if not ung_vien:
            continue
        noi = _chan_chon_dia_chi(ref, nets)
        if noi is None:
            continue
        muc = "gnd" if noi in ten_dat else ("vdd" if noi in ten_nguon else None)
        if muc is None:
            continue
        for dieu_kien, gt in ung_vien.items():
            if dieu_kien.endswith(muc):
                ra.append((ref, gt, f"{dieu_kien} (net `{noi}`)"))
                break
    return ra


def _dia_chi_kha_di(root: Path, pt: dict[str, Any]) -> dict[str, Any]:
    """Fact `address` của hộ chiếu LINH KIỆN, dạng `{"sdo=gnd": "0x76", "sdo=vdd": "0x77"}`."""
    ten = str(pt.get("mpn") or pt.get("value") or "").strip()
    if not ten:
        return {}
    db = store.store_path(root)
    if not db.exists():
        return {}
    with store.open_store(db) as c:
        rows = c.execute("SELECT value FROM fact WHERE predicate='address'"
                         "  AND status NOT IN ('superseded','rejected')"
                         "  AND (subject LIKE ? OR subject LIKE ?)",
                         (f"%{ten.lower()}%", f"%{ten.upper()}%")).fetchall()
    for (gt,) in rows:
        try:
            v = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            continue
        if isinstance(v, dict) and any("=" in k for k in v):
            return v
    return {}


RE_CHAN_DIA_CHI = re.compile(r"(SDO|ADDR|AD0|A0|SA0)", re.IGNORECASE)


def _chan_chon_dia_chi(ref: str, nets: dict[str, list[dict[str, str]]]) -> str | None:
    """Net mà chân chọn địa chỉ của linh kiện `ref` nối vào — tìm theo TÊN NET.

    Chỉ dùng được khi người thiết kế đặt tên net theo chân (`/BME280_SDO`, `SDO`). Không có thì
    trả `None` và địa chỉ không được suy — đúng hơn là đoán một trong hai rồi ghi thành fact.
    """
    for ten, nodes in nets.items():
        if RE_CHAN_DIA_CHI.search(ten) and any(n.get("ref") == ref for n in nodes):
            noi_khac = [t for t, nd in nets.items()
                        if t != ten and any(n.get("ref") == ref and n.get("pin") ==
                                            next((x.get("pin") for x in nodes
                                                  if x.get("ref") == ref), None) for n in nd)]
            return noi_khac[0] if noi_khac else ten
    # Chân SDO nối THẲNG vào GND/VDD thì net mang tên nguồn, không mang tên chân. Tìm ngược:
    # linh kiện có mặt trên một net nguồn/đất mà chỉ có ít node → nhiều khả năng là chân chọn.
    for ten, nodes in nets.items():
        if (RE_DAT.match(ten) or RE_NGUON.match(ten)) and any(n.get("ref") == ref for n in nodes):
            return ten
    return None


# ---------------------------------------------------------------- BOARD-02 check_pins


@capability("board.check_pins")
def check_pins(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: BOARD-02 — CDS-12.2; ARCH-03 (HwMap). tc: TC-21 "phát hiện PB3 LED+MOSI, PA13".

    Năm quy tắc của bước 1, và tất cả đều **deterministic**: đây là việc của một phép kiểm, không
    của một mô hình. Một chân bị dùng hai lần là chuyện đếm được; hỏi mô hình chỉ thêm một cơ hội
    để nó bỏ sót.

    Xét cả `HwMap` **dự kiến** trong `plan` chứ không chỉ board hiện tại — đó là chỗ phép kiểm
    này có ích nhất. Phát hiện xung đột sau khi đã sinh mã và đã nạp thì cái giá là một lần gỡ
    lỗi trên phần cứng; phát hiện lúc còn là kế hoạch thì cái giá là đổi một dòng.
    """
    root = _root(ctx)
    board = str(params["board"])
    nets = doc_net(root, board)
    du_kien = _hw_map_du_kien(params.get("plan") or {})

    xung_dot: list[dict[str, Any]] = []
    xung_dot += _chan_hai_chuc_nang(nets, du_kien)
    xung_dot += _chan_giu(root, nets, du_kien)
    xung_dot += _trung_dia_chi(root, board, nets)
    xung_dot += _thieu_pullup(nets)
    return {"conflicts": xung_dot}


def _hw_map_du_kien(plan: dict[str, Any]) -> dict[str, list[str]]:
    """`{chân: [module dùng nó]}` từ HwMap dự kiến trong kế hoạch."""
    ra: dict[str, list[str]] = {}
    for m in (plan.get("hw_map") or []):
        for c in (m.get("pins") or ([m.get("pin")] if m.get("pin") else [])):
            ra.setdefault(str(c).upper(), []).append(str(m.get("module_id") or m.get("module")))
    return ra


def _chan_theo_net(nets: dict[str, list[dict[str, str]]]) -> dict[tuple[str, str], list[str]]:
    """`{(ref, pin): [tên net]}` — một chân trên nhiều net là một chân hai chức năng."""
    ra: dict[tuple[str, str], list[str]] = {}
    for ten, nodes in nets.items():
        for n in nodes:
            if n.get("ref") and n.get("pin"):
                ra.setdefault((n["ref"], n["pin"]), []).append(ten)
    return ra


def _chan_hai_chuc_nang(nets: dict[str, list[dict[str, str]]],
                        du_kien: dict[str, list[str]]) -> list[dict[str, Any]]:
    ra: list[dict[str, Any]] = []
    for (ref, pin), ds in sorted(_chan_theo_net(nets).items()):
        if len(set(ds)) > 1:
            ra.append({"pin": f"{ref}.{pin}", "kind": "af_conflict", "severity": "blocker",
                       "detail": f"chân {ref}.{pin} nối vào {len(set(ds))} net khác nhau: "
                                 + ", ".join(sorted(set(ds)))})
    for chan, mods in sorted(du_kien.items()):
        if len(set(mods)) > 1:
            ra.append({"pin": chan, "kind": "af_conflict", "severity": "blocker",
                       "detail": f"{len(set(mods))} module cùng xin chân {chan}: "
                                 + ", ".join(sorted(set(mods)))})
    return ra


def _chan_giu(root: Path, nets: dict[str, list[dict[str, str]]],
              du_kien: dict[str, list[str]]) -> list[dict[str, Any]]:
    """Chân dành riêng cho gỡ lỗi và khởi động. TC-21 nêu đích danh PA13 (SWDIO).

    Nghiêm trọng là `major` chứ không `blocker`: dùng SWO cho một LED là chuyện làm được và
    người ta vẫn làm, chỉ là mất một đường gỡ lỗi. Đánh `blocker` cho mọi trường hợp thì phép
    kiểm này chặn cả những thiết kế cố ý, và người ta sẽ tắt nó.
    """
    isa = _isa(root)
    bang = CHAN_GIU.get(isa, {})
    ra: list[dict[str, Any]] = []
    dung = {c.upper() for c in du_kien}
    for ten, nodes in nets.items():
        for n in nodes:
            if (t := str(n.get("pin", "")).upper()) in bang:
                dung.add(t)
        if (t := ten.strip("/").upper()) in bang:
            dung.add(t)
    for chan in sorted(dung & set(bang)):
        ra.append({"pin": chan, "kind": "reserved", "severity": "major",
                   "detail": f"{chan} là chân dành riêng ({bang[chan]}) — dùng cho việc khác thì "
                             "mất đường gỡ lỗi hoặc board không khởi động đúng chế độ"})
    return ra


def _trung_dia_chi(root: Path, board: str, nets: dict[str, list[dict[str, str]]]) -> list[dict[str, Any]]:
    """Hai thiết bị cùng địa chỉ trên cùng một bus — bus sẽ trả dữ liệu của con nào không ai
    đoán được, và triệu chứng là "cảm biến đọc ra số lạ" chứ không phải một lỗi rõ ràng."""
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        rows = c.execute("SELECT subject, value FROM fact WHERE predicate='address'"
                         "  AND subject LIKE ? AND status NOT IN ('superseded','rejected')",
                         (f"{_bid(board)}/part:%",)).fetchall()
    theo: dict[str, list[str]] = {}
    for subj, gt in rows:
        try:
            v = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            continue
        if isinstance(v, (str, int)):
            theo.setdefault(str(v).lower(), []).append(str(subj).rsplit(":", 1)[-1])
    return [{"pin": "-", "kind": "address_clash", "severity": "blocker",
             "detail": f"{len(set(refs))} thiết bị cùng địa chỉ {dc}: " + ", ".join(sorted(set(refs)))}
            for dc, refs in sorted(theo.items()) if len(set(refs)) > 1]


def _thieu_pullup(nets: dict[str, list[dict[str, str]]]) -> list[dict[str, Any]]:
    """I2C không có điện trở kéo lên thì bus im lặng — và triệu chứng giống hệt "cảm biến hỏng"."""
    ra: list[dict[str, Any]] = []
    for ten, nodes in sorted(nets.items()):
        if not any(m.search(ten) for m in RE_I2C.values()):
            continue
        if not any(RE_DIEN_TRO.fullmatch(n.get("ref", "")) for n in nodes):
            ra.append({"pin": ten, "kind": "missing_pullup", "severity": "major",
                       "detail": f"net I2C `{ten}` không có điện trở kéo lên — bus sẽ im lặng, "
                                 "và triệu chứng giống hệt cảm biến hỏng"})
    return ra


def _isa(root: Path) -> str:
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    return str(((cu.get("target") or {}).get("isa")) or "")
