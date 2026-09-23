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
    """`board:<tên>` — BỎ hậu tố `@phiên-bản`. [DEV-212]

    `extract.kicad_netlist` trả `board_passport_id` dạng `mach-co-loi@1.0.0`, còn fact `net`
    và `package` được ghi theo TÊN board trần (`board:mach-co-loi`). Truyền id hộ chiếu vào
    `doc_net` vì thế tra ra rỗng — và `board.check_pins` trả `0 conflicts` cho một bo mạch có
    bốn lỗi cài sẵn.

    Đo 23/09/2026 trên TC038: `doc_net(root, "mach-co-loi@1.0.0")` → 0 net;
    `doc_net(root, "mach-co-loi")` → 6 net. Cùng một bo mạch, hai cách gọi tên.
    """
    return f"board:{re.sub(r'[^A-Za-z0-9_.-]+', '-', board.split('@')[0]).lower()}"


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
    # KHÔNG CÓ DỮ LIỆU ≠ KHÔNG CÓ LỖI. [DEV-212]
    #
    # Trả `{"conflicts": []}` khi chưa tra được net nào là nói "bo mạch này sạch" cho một bo
    # mạch chưa hề được đọc. Đo 23/09/2026 trên TC038: `check_pins` báo 0 xung đột cho netlist
    # có bốn lỗi cài sẵn, chỉ vì tên board truyền vào mang hậu tố `@1.0.0`.
    #
    # Đây đúng khuôn hỏng của [DEV-183] — cột "✓ có ngưỡng đo" hiện cho MỌI yêu cầu vì lời gọi
    # bên dưới hỏng và bị nuốt. Một câu trả lời trấn an rút từ hư không nguy hiểm hơn một ô
    # trống: người đọc tin nó và thôi kiểm.
    if not nets:
        co = _cac_board(root)
        raise EideError("E2000", f"Chưa tra được net nào cho board `{board}` — chưa chạy "
                        "`extract.kicad_netlist`, hoặc tên board không khớp"
                        + (f" (board đang có net: {', '.join(co)})" if co else "")
                        + ". KHÔNG kết luận bo mạch sạch khi chưa đọc được nó.",
                        exists=co, candidates=co, missing=[f"net:{board}"])
    du_kien = _hw_map_du_kien(params.get("plan") or {})

    xung_dot: list[dict[str, Any]] = []
    xung_dot += _chan_hai_chuc_nang(nets, du_kien)
    xung_dot += _chan_giu(root, nets, du_kien)
    xung_dot += _trung_dia_chi(root, board, nets)
    xung_dot += _thieu_pullup(nets)
    xung_dot += _qua_ap_mien_nguon(nets)
    xung_dot += _reset_tha_noi(nets)
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


#: Tên net gợi ý miền 5 V. Không đoán theo giá trị — netlist không mang điện áp, chỉ mang TÊN,
#: và tên là thứ người thiết kế cố ý đặt.
RE_NET_5V = re.compile(r"(^|[_+\-])(5V|5V0|VBUS|VUSB|VIN)($|[_\-])", re.I)

#: Chân nguồn của một IC. `VDDIO`/`VCCIO` là chân nhạy nhất: nó cấp cho tầng đệm I/O và thường
#: có trần thấp hơn cả `VDD` lõi.
RE_CHAN_NGUON = re.compile(r"^(VDD|VDDIO|VCC|VCCIO|AVDD|VDDA)", re.I)

#: Chân reset. `NRST`/`RESET#`/`~RESET` — cùng một thứ, ba cách viết.
RE_CHAN_RESET = re.compile(r"(^|[_/])~?(N?RST|RESET)#?($|[_/])", re.I)


def _qua_ap_mien_nguon(nets: dict[str, list[dict[str, str]]]) -> list[dict[str, Any]]:
    """Chân nguồn của IC nằm trên net 5 V — [DEV-212].

    Đây là lỗi đắt nhất trong bốn lỗi mẫu, vì nó **hỏng ngay lần cắm đầu tiên** và hỏng vĩnh
    viễn: `VDDIO` của một cảm biến 3,6 V nối thẳng vào VBUS thì chip chết trước khi ai kịp đọc
    một dòng log. Và nó là loại lỗi mắt người dễ bỏ qua nhất — trên sơ đồ, một dây nối tới
    `VBUS` trông y hệt một dây nối tới `+3V3`.

    KHÔNG đọc trị số điện áp từ đâu cả: netlist không mang điện áp, nó mang TÊN NET. Tên là thứ
    người thiết kế cố ý đặt, nên `VBUS_5V` là một tuyên bố, không phải một phỏng đoán. Bộ ổn áp
    thì được miễn — `VIN` của một LDO nằm trên 5 V là đúng việc của nó.
    """
    ra: list[dict[str, Any]] = []
    for ten, nodes in sorted(nets.items()):
        if not RE_NET_5V.search(ten):
            continue
        for n in nodes:
            cn = (n.get("pinfunction") or "")
            if not RE_CHAN_NGUON.match(cn):
                continue
            if cn.upper().startswith("VIN"):        # LDO/DC-DC: đầu vào ở 5 V là đúng
                continue
            ra.append({
                "pin": f"{n.get('ref')}.{n.get('pin')}", "kind": "overvoltage",
                "severity": "blocker",
                "detail": f"chân `{cn}` của `{n.get('ref')}` nằm trên net `{ten}` — miền 5 V. "
                          f"Chân nguồn của IC thường có trần 3,6 V; cấp 5 V là hỏng ngay lần "
                          f"cắm đầu tiên. Kiểm datasheet, và nếu cần 5 V thì thêm bộ chuyển mức."})
    return ra


def _reset_tha_noi(nets: dict[str, list[dict[str, str]]]) -> list[dict[str, Any]]:
    """Net reset chỉ có ĐÚNG MỘT nút — [DEV-212].

    Một chân reset không có gì níu thì nó là một ăng-ten: board tự khởi động lại khi có nhiễu,
    lúc có lúc không, và người ta đi tìm lỗi trong firmware suốt nhiều ngày. Đúng loại lỗi mà
    TC037 mô tả — "thỉnh thoảng tự khởi động lại, không tái hiện được".

    Một nút nghĩa là chỉ có chính chân MCU: không trở kéo lên, không tụ, không nút bấm.
    """
    ra: list[dict[str, Any]] = []
    for ten, nodes in sorted(nets.items()):
        co_reset = any(RE_CHAN_RESET.search(n.get("pinfunction") or "") for n in nodes) \
            or RE_CHAN_RESET.search(ten)
        if co_reset and len(nodes) == 1:
            n = nodes[0]
            ra.append({
                "pin": f"{n.get('ref')}.{n.get('pin')}", "kind": "floating_reset",
                "severity": "major",
                "detail": f"net reset `{ten}` chỉ có một nút (`{n.get('ref')}.{n.get('pin')}`) "
                          f"— không trở kéo lên, không tụ. Chân reset thả nổi là một ăng-ten: "
                          f"board tự khởi động lại khi có nhiễu, lúc có lúc không."})
    return ra


def _isa(root: Path) -> str:
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    return str(((cu.get("target") or {}).get("isa")) or "")


# ---------------------------------------------------------------- BOARD-03 constraints

# Ngưỡng điện trở kéo lên cho I2C Fast-mode. Chuẩn I2C đòi sườn lên `tr ≤ 300 ns` ở 400 kHz và
# `tr ≤ 1000 ns` ở 100 kHz; với điện dung bus cỡ 100–200 pF của một board nhỏ, 4k7 là ngưỡng
# thực tế. Kéo lên 10k vẫn chạy 100 kHz nhưng không đủ nhanh cho 400 kHz — và cái sai khi ấy
# KHÔNG phải là bus chết hẳn, mà là đọc sai lác đác dưới nhiệt độ cao. Đó là loại lỗi tốn nhiều
# ngày nhất, nên nó đáng thành một ràng buộc ghi ra chứ không phải một lời nhắc.
PULLUP_400K_OHM = 4700
I2C_STANDARD_KHZ, I2C_FAST_KHZ = 100, 400

RE_GIA_TRI_R = re.compile(r"^(\d+(?:[.,]\d+)?)\s*([kKmMrR])?\s*(\d*)\s*(?:ohm|Ω)?$")
RE_DIEN_AP = re.compile(r"^/?\+?(\d+)V(\d*)$", re.IGNORECASE)


@capability("board.constraints")
def constraints(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: BOARD-03 — CDS-12.2; DDD-14 (constraints.yaml). tc: "I2C1 limit 400 kHz theo
    pull-up"; undo `restore_config`.

    Dịch bản thiết kế thành **ràng buộc mà Coder đọc được**. `board.check_pins` nói "có vấn đề";
    năng lực này nói "được phép làm gì" — và khác biệt ấy quan trọng vì mã sinh ra không đọc
    danh sách cảnh báo, nó đọc `constraints.yaml`.

    Chỗ đáng giá là `bus_limits`. tc nói thẳng: **I2C1 limit 400 kHz theo pull-up**. Tốc độ tối
    đa của một bus I2C không nằm trong datasheet chip mà nằm ở **điện trở kéo lên trên board
    này**: 4k7 chạy được 400 kHz, 10k thì không. Không ghi ra thì mã sinh sau đó lấy 400 kHz
    theo datasheet, board chạy được lúc mát và đọc sai lác đác lúc nóng — loại lỗi tốn nhiều
    ngày nhất, vì nó không tái lập được trên bàn.
    """
    root = _root(ctx)
    board = str(params["board"])
    nets, parts = doc_net(root, board), doc_part(root, board)
    if not nets:
        co = _cac_board(root)
        raise EideError("E2000", f"Chưa có net nào cho board `{board}`"
                        + (f" (board đang có net: {', '.join(co)})" if co else ""),
                        exists=co, candidates=co, missing=[f"net:{board}"])

    rb = {"reserved_pins": _chan_giu_rb(root),
          "bus_limits": _gioi_han_bus(nets, parts),
          "voltage": _dien_ap(nets),
          "current": _dong(root, board, parts)}

    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    cu["board"] = {**(cu.get("board") or {}), board: rb}
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(yaml.safe_dump(cu, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"constraints": rb}


def _chan_giu_rb(root: Path) -> list[dict[str, str]]:
    """Cùng bảng `CHAN_GIU` mà `check_pins` dùng — hai chỗ không được phép lệch nhau, vì một
    chân bị cấm ở phép kiểm mà không bị cấm ở ràng buộc thì mã sinh ra sẽ dùng nó rồi mới bị
    phép kiểm bắt, tức phát hiện muộn đúng một vòng."""
    return [{"pin": p, "why": v} for p, v in sorted((CHAN_GIU.get(_isa(root)) or {}).items())]


def doc_ohm(gt: str | None) -> float | None:
    """`4k7` → 4700, `10k` → 10000, `2.2k` → 2200, `470` → 470, `1M` → 1e6.

    Ký hiệu chen chữ (`4k7`) là cách ghi phổ biến nhất trên sơ đồ vì nó không có dấu chấm để
    mất khi in mờ hay khi qua OCR — nên nó phải đọc được, không chỉ dạng `4.7k`.
    """
    if not gt:
        return None
    m = RE_GIA_TRI_R.match(str(gt).strip())
    if not m:
        return None
    nguyen, don_vi, thap_phan = m.group(1).replace(",", "."), (m.group(2) or "").lower(), m.group(3)
    so = float(f"{nguyen}.{thap_phan}") if thap_phan else float(nguyen)
    return so * {"k": 1e3, "m": 1e6, "r": 1.0, "": 1.0}[don_vi]


def _gioi_han_bus(nets: dict[str, list[dict[str, str]]],
                  parts: dict[str, dict[str, Any]]) -> dict[str, Any]:
    ra: dict[str, Any] = {}
    for ten_bus, ct in sorted(_suy_bus(nets).items()):
        if ct.get("kind") != "i2c":
            continue
        ohm = _ohm_keo_len(ct, parts)
        if ohm is None:
            ra[ten_bus] = {"max_khz": I2C_STANDARD_KHZ, "pullup_ohm": None,
                           "why": "không thấy điện trở kéo lên trên SCL/SDA — bus có thể không "
                                  "chạy được ở bất kỳ tốc độ nào; giữ mức thấp nhất cho tới khi "
                                  "đo được"}
        elif ohm <= PULLUP_400K_OHM:
            ra[ten_bus] = {"max_khz": I2C_FAST_KHZ, "pullup_ohm": ohm,
                           "why": f"kéo lên {ohm:.0f} Ω ≤ {PULLUP_400K_OHM} Ω — đủ nhanh cho "
                                  "Fast-mode 400 kHz"}
        else:
            ra[ten_bus] = {"max_khz": I2C_STANDARD_KHZ, "pullup_ohm": ohm,
                           "why": f"kéo lên {ohm:.0f} Ω > {PULLUP_400K_OHM} Ω — sườn lên quá "
                                  "chậm cho 400 kHz; ép về 100 kHz"}
    return ra


def _ohm_keo_len(ct: dict[str, Any], parts: dict[str, dict[str, Any]]) -> float | None:
    """Điện trở kéo lên YẾU NHẤT (giá trị lớn nhất) trên hai đường của bus.

    Lấy cái lớn nhất chứ không phải cái nhỏ nhất: SCL kéo 4k7 mà SDA kéo 10k thì bus vẫn chỉ
    nhanh bằng đường chậm hơn. Lấy cái nhỏ nhất là tự cho mình một tốc độ không có thật.
    """
    ds: list[float] = []
    for duong in (ct.get("lines") or {}).values():
        for n in (duong.get("nodes") or []):
            if RE_DIEN_TRO.fullmatch(n.get("ref", "")) and \
                    (o := doc_ohm((parts.get(n["ref"]) or {}).get("value"))) is not None:
                ds.append(o)
    return max(ds) if ds else None


def _dien_ap(nets: dict[str, list[dict[str, str]]]) -> dict[str, Any]:
    """Mức điện áp từ TÊN net nguồn: `+3V3` → 3.3 V, `5V` → 5.0, `1V8` → 1.8."""
    muc: dict[str, float] = {}
    for ten in nets:
        if RE_NGUON.match(ten) and (m := RE_DIEN_AP.match(ten.strip("/"))):
            muc[ten] = float(f"{m.group(1)}.{m.group(2) or '0'}")
    if not muc:
        return {"rails": {}, "io_v": None,
                "why": "không suy được mức nào từ tên net nguồn — mã sinh ra không được giả định "
                       "mức I/O"}
    # Mức I/O là mức THẤP NHẤT có trên board: nối một chân 3V3 vào một net 5 V làm hỏng chip, và
    # cái hỏng ấy xảy ra trước khi có gì để gỡ.
    return {"rails": muc, "io_v": min(muc.values()),
            "why": f"mức I/O lấy theo nguồn thấp nhất trong {sorted(muc)}"}


def _dong(root: Path, board: str, parts: dict[str, dict[str, Any]]) -> dict[str, Any]:
    """Ngân sách dòng, từ fact `current` của các linh kiện trên board.

    Chưa có fact nào thì trả `None` kèm năng lực cần chạy, KHÔNG trả một con số mặc định. Một
    ngân sách dòng bịa ra còn tệ hơn không có: mã sinh ra sẽ bật đồng thời mọi thứ vì "còn
    trong hạn mức".
    """
    db = store.store_path(root)
    ds: list[tuple[str, float]] = []
    if db.exists() and parts:
        with store.open_store(db) as c:
            for subj, gt in c.execute(
                    "SELECT subject, value FROM fact WHERE predicate IN ('current','current_max')"
                    "  AND subject LIKE ? AND status NOT IN ('superseded','rejected')",
                    (f"{_bid(board)}/part:%",)).fetchall():
                try:
                    v = json.loads(gt)
                except (json.JSONDecodeError, TypeError):
                    continue
                if isinstance(v, dict) and isinstance(v.get("value"), (int, float)):
                    ma = float(v["value"]) * (1000.0 if str(v.get("unit", "")).lower() == "a" else 1.0)
                    ds.append((str(subj).rsplit(":", 1)[-1], ma))
    if not ds:
        return {"budget_ma": None, "parts": {},
                "why": "chưa có fact `current` cho linh kiện nào trên board — chạy "
                       "`extract.bom_enrich` hoặc `extract.pdf_register_map` để có"}
    return {"budget_ma": round(sum(m for _, m in ds), 3), "parts": dict(sorted(ds)),
            "why": f"tổng dòng khai báo của {len(ds)} linh kiện có fact `current`"}


# ---------------------------------------------------------------- BOARD-04 propose_fix


@capability("board.propose_fix")
def propose_fix(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: BOARD-04 — CDS-12.2; ARCH-03 (`map_hw` trỏ tới đây khi xung đột không tự giải).
    tc: "≥ 2 phương án; phương án chạm mã passing đánh dấu ASK"; ask "Chạm mã passing".

    Bốn loại phương án mà bước 1 của hợp đồng liệt kê — remap AF, đổi chân, đổi địa chỉ (chân
    ADDR), thêm điện trở — sinh **bằng mã, không bằng mô hình**, và đây là một lựa chọn có lý do
    chứ không phải cho tiện.

    Một phương án đổi chân chỉ có ích khi nó nêu được **chân thay thế cụ thể**, và chân nào thay
    được cho chân nào là chuyện tra fact `pin_function` của hộ chiếu chip. Mô hình không có bảng
    ấy trong đầu; hỏi nó thì được một tên chân nghe rất đúng cho tới lúc nạp. Sinh từ fact thì
    phương án hoặc có thật, hoặc nói thẳng là chưa tra được. Xem [DEV-067].

    **`touches_code` không phải cờ trang trí.** Một phương án chạm vào mã đang qua test là một
    phương án có thể làm hỏng thứ đang chạy, nên nó được đánh `ask` — đúng `ask_when` của hợp
    đồng. Chạm mã CHƯA có test nào xanh thì không đánh: bắt hỏi ở đó chỉ dạy người ta bấm Đồng ý
    cho nhanh, và đến lúc cần hỏi thật thì cái nút ấy đã mất nghĩa.
    """
    root = _root(ctx)
    xd = dict(params["conflict"])
    loai = str(xd.get("kind") or "af_conflict")
    chan = str(xd.get("pin") or "")
    co_test_xanh = _co_test_xanh(root)

    ds = _PHUONG_AN.get(loai, _phuong_an_chung)(root, xd, chan)
    # "xếp theo ít thay đổi nhất": không chạm mã trước, rồi tới chi phí.
    ds.sort(key=lambda o: (o["touches_code"], THU_TU_CHI_PHI.index(o["cost"])))
    for o in ds:
        o["ask"] = bool(o["touches_code"] and co_test_xanh)
        if o["ask"]:
            o["ask_reason"] = ("chạm mã đang qua test — sửa xong phải chạy lại `code.test_host` "
                               "trước khi coi là xong")
    return {"options": ds}


THU_TU_CHI_PHI = ["low", "medium", "high"]


def _co_test_xanh(root: Path) -> bool:
    """Dự án có lần chạy test nào ĐẠT chưa — điều kiện của "mã passing" trong `ask_when`."""
    db = store.store_path(root)
    if not db.exists():
        return False
    with store.open_store(db) as c:
        r = c.execute("SELECT 1 FROM tool_report WHERE tool IN ('test','test_host')"
                      "  AND passed=1 LIMIT 1").fetchone()
    return r is not None


def _chan_thay_the(root: Path, chan: str) -> list[str]:
    """Chân khác cùng chức năng, từ fact `pin_function` của hộ chiếu chip.

    Trả rỗng khi chưa có hộ chiếu chân — và khi ấy phương án vẫn được nêu, chỉ là nó nói "chưa
    tra được chân thay thế" thay vì bịa một cái tên.
    """
    db = store.store_path(root)
    if not db.exists() or not chan:
        return []
    goc = chan.split(".")[-1].upper()
    with store.open_store(db) as c:
        rows = c.execute("SELECT subject, value FROM fact WHERE predicate='pin_function'"
                         "  AND status NOT IN ('superseded','rejected')").fetchall()
    chuc_nang: set[str] = set()
    theo_chan: dict[str, set[str]] = {}
    for subj, gt in rows:
        try:
            v = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            continue
        ten = str((v.get("pin") if isinstance(v, dict) else None)
                  or str(subj).rsplit(":", 1)[-1]).upper()
        fs = {str(x).upper() for x in
              ((v.get("functions") or v.get("af") or []) if isinstance(v, dict) else [])}
        theo_chan.setdefault(ten, set()).update(fs)
        if ten == goc:
            chuc_nang |= fs
    if not chuc_nang:
        return []
    return sorted(p for p, fs in theo_chan.items() if p != goc and (fs & chuc_nang))


def _pa(change: str, cost: str, touches_code: bool, **them: Any) -> dict[str, Any]:
    return {"change": change, "cost": cost, "touches_code": touches_code, **them}


def _pa_af(root: Path, xd: dict[str, Any], chan: str) -> list[dict[str, Any]]:
    thay = _chan_thay_the(root, chan)
    ds = [_pa("Chuyển một trong hai chức năng sang chân khác cùng AF: "
              + (", ".join(thay[:4]) if thay else
                 f"chưa tra được chân thay thế cho {chan} — chạy `extract.pdf_pinout` để có "
                 "fact `pin_function` rồi hỏi lại"),
              "low" if thay else "medium", True,
              alternatives=thay[:4], kind="remap_af"),
          _pa(f"Đổi hẳn ngoại vi cho một trong hai module (ví dụ SPI1 → SPI2) để thôi tranh "
              f"{chan}", "medium", True, kind="change_peripheral"),
          _pa(f"Dùng chung {chan} theo thời gian: chỉ một module giữ chân tại một thời điểm, "
              "chuyển qua lại bằng cấu hình lại chân", "high", True, kind="time_share",
              note="rẻ về phần cứng, đắt về mã và là nguồn lỗi ngắt — chỉ nên khi hai module "
                   "không bao giờ chạy cùng lúc")]
    return ds


def _pa_reserved(root: Path, xd: dict[str, Any], chan: str) -> list[dict[str, Any]]:
    vi_sao = str(xd.get("detail") or "")
    thay = _chan_thay_the(root, chan)
    return [_pa(f"Chuyển chức năng khỏi {chan} sang chân thường: "
                + (", ".join(thay[:4]) if thay else "chưa tra được chân thay thế"),
                "low" if thay else "medium", True, alternatives=thay[:4], kind="move_off_reserved"),
            _pa(f"Giữ nguyên và chấp nhận mất chức năng dành riêng của {chan} ({vi_sao[:80]})",
                "high", False, kind="accept",
                note="không chạm mã, nhưng đổi lại là mất đúng đường mà lúc board không chạy "
                     "người ta cần nhất")]


def _pa_dia_chi(root: Path, xd: dict[str, Any], chan: str) -> list[dict[str, Any]]:
    return [_pa("Đổi chân chọn địa chỉ (SDO/ADDR/A0) của một thiết bị sang mức còn lại — "
                "một mối hàn, địa chỉ đổi theo", "low", True, kind="change_address",
                note="chạm mã vì hằng số địa chỉ trong driver phải đổi theo; sau đó chạy "
                     "`board.build_passport` để fact `address` khớp lại"),
            _pa("Tách hai thiết bị ra hai bus I2C khác nhau", "medium", True, kind="split_bus"),
            _pa("Thêm bộ ghép kênh I2C (TCA9548A) nếu buộc phải giữ cùng địa chỉ", "high", True,
                kind="mux", note="thêm linh kiện và thêm một lớp mã — chỉ đáng khi không đổi "
                                 "được địa chỉ")]


def _pa_pullup(root: Path, xd: dict[str, Any], chan: str) -> list[dict[str, Any]]:
    return [_pa(f"Thêm điện trở kéo lên {PULLUP_400K_OHM} Ω lên nguồn cho `{chan}`", "low", False,
                kind="add_pullup",
                note="không chạm mã — đây là lý do nó đứng đầu danh sách"),
            _pa("Bật điện trở kéo lên trong chip cho chân I2C", "low", True, kind="internal_pullup",
                note="kéo lên trong chip cỡ 20–50 kΩ, chỉ đủ cho 100 kHz và bus ngắn; dùng được "
                     "để thử, không nên để trong bản chạy thật"),
            _pa(f"Hạ tốc độ bus xuống {I2C_STANDARD_KHZ} kHz", "medium", True, kind="lower_speed",
                note="không sửa được nguyên nhân: thiếu kéo lên thì bus vẫn không có mức cao")]


def _phuong_an_chung(root: Path, xd: dict[str, Any], chan: str) -> list[dict[str, Any]]:
    return [_pa(f"Đổi chân/ngoại vi liên quan tới {chan or 'xung đột này'}", "medium", True,
                kind="generic_remap"),
            _pa("Giữ nguyên và ghi lại quyết định (ADR) kèm lý do chấp nhận", "high", False,
                kind="accept", note="`arch.adr` để quyết định này không mất khi người khác đọc lại")]


_PHUONG_AN = {"af_conflict": _pa_af, "reserved": _pa_reserved,
              "address_clash": _pa_dia_chi, "missing_pullup": _pa_pullup}


# ---------------------------------------------------------------- BOARD-05 mark_lab

def cac_co_cau() -> list[dict[str, Any]]:
    """Bảng nhận dạng cơ cấu chấp hành, sinh ra `docs/spec/policy/actuators.yaml` (POL-17 §3).

    Đọc từ spec chứ không nhúng mẫu vào Python — DEV-068 duyệt 08/09: thêm một họ mạch lái động
    cơ mới là sửa một tệp dữ liệu, không phải sửa và phát hành lại mã. Cùng khuôn `isa/*.yaml`
    và `doc/glossary.json`.

    Là lưới chặn MỘT CHIỀU: bắt được thì chắc chắn không phải board lab, còn không bắt được thì
    không kết luận gì — lời khai của người vẫn là điều kiện bắt buộc. Đặt ngược lại (tự cho lab
    khi không thấy động cơ) thì một con MOSFET lái van sẽ lọt, và cái lọt ấy chuyển động.
    """
    from eide_core.paths import spec_dir
    f = spec_dir() / "policy" / "actuators.yaml"
    if not f.exists():
        return []
    return list((yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("groups") or [])


def _re_co_cau() -> re.Pattern[str]:
    mau = [m for g in cac_co_cau() for m in (g.get("patterns") or [])]
    return re.compile("(" + "|".join(mau) + ")", re.IGNORECASE) if mau else re.compile(r"(?!)")

# `by` không được là một cái tên máy. Hợp đồng nêu `E3000 nếu by=policy`; ba tên còn lại là cùng
# một chuyện — chúng là actor của hệ, không phải người chịu trách nhiệm.
BY_KHONG_PHAI_NGUOI = {"policy", "agent", "eide", "system", "auto"}


@capability("board.mark_lab")
def mark_lab(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: BOARD-05 — CDS-12.2; POL-17 §3 (niêm danh sách trắng); APD-08 §3 (G-OPS).
    tc: "Z-10; board có động cơ → không lab"; lỗi E3000 nếu `by=policy`, E1000 thiếu xác nhận;
    undo `restore_config`.

    Đánh dấu lab là **cách duy nhất** để `target.flash` chạy mà không hỏi người từng lần
    (`G-OPS-01`). Nên nó không phải một cờ tiện tay — nó là chỗ một người nhận trách nhiệm rằng
    board này không làm gì nguy hiểm khi mã chạy sai.

    Ba lớp, và cả ba đều cần thiết:

    1. **`ctx.actor` phải là người.** `by` chỉ là một chuỗi; tác tử điền được. Nếu chỉ kiểm `by`
       thì tác tử tự cấp cho mình quyền tự nạp — đúng thứ mà `eide policy sign` cố ý không làm
       thành năng lực (xem `cli.py::cmd_policy_sign`).
    2. **Cả hai lời khai phải `true`.** Thiếu một cái là E1000: hợp đồng đòi cả `no_actuator` lẫn
       `current_limited`, và "board không có cơ cấu chấp hành nhưng chưa hạn dòng" vẫn cháy được.
    3. **Đối chiếu với netlist.** tc nói "board có động cơ → không lab". Lời khai của người có
       thể sai vì người khai không phải người vẽ mạch. Thấy mạch lái động cơ trong netlist thì
       ghi `lab: false` kèm lý do và tên linh kiện — không im lặng bỏ qua, cũng không ném lỗi:
       schema autonomy.yaml có sẵn `has_actuator` và `reason` đúng cho việc ấy, và một board đã
       xét rồi kết luận "không lab" là thông tin đáng giữ hơn một lần gọi thất bại.

    **Ký lại niêm sau khi ghi.** `boards` là một trong bốn khóa `whitelist.KHOA_NIEM`, nên ghi
    vào nó mà không ký lại thì niêm vỡ và MỌI phê duyệt dựa trên danh sách trắng ngừng hoạt động
    — bao gồm chính `G-OPS-01` mà năng lực này phục vụ. Ký ở đây hợp lệ vì lớp 1 đã bảo đảm
    người đang ngồi trước máy.
    """

    root = _root(ctx)
    board = str(params["board"])
    by = str(params["by"]).strip()

    if not by or by.lower() in BY_KHONG_PHAI_NGUOI:
        raise EideError("E3000", f"`by={by or '(rỗng)'}` không phải một người — đánh dấu lab là "
                        "chỗ một người nhận trách nhiệm, không phải một bước tự động",
                        gate="G-OPS", rule="BOARD-05")
    if ctx.actor != "human":
        raise EideError("E3000", f"Đánh dấu board `{board}` là lab phải do người gọi "
                        f"(actor hiện tại: {ctx.actor})", gate="G-OPS", rule="BOARD-05")
    thieu = [k for k in ("no_actuator", "current_limited") if not params.get(k)]
    if thieu:
        raise EideError("E1000", f"Thiếu xác nhận: {', '.join(thieu)} phải là `true`. "
                        "Board chưa hạn dòng vẫn cháy được dù không có cơ cấu chấp hành.",
                        missing=thieu)

    cc = _co_cau_chap_hanh(root, board)
    lab = not cc
    ly_do = (f"{by} xác nhận không có cơ cấu chấp hành và đã hạn dòng" if lab else
             "netlist có " + "; ".join(f"{r} ({v})" for r, v in cc)
             + f" — trái với lời khai `no_actuator=true` của {by}")

    f = root / EIDE_DIR / "autonomy.yaml"
    cfg = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    cfg.setdefault("boards", {})[board] = {**(cfg["boards"].get(board) or {}),
                                           "lab": lab, "has_actuator": bool(cc), "reason": ly_do}
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")

    _ky_lai(ctx, cfg, root / EIDE_DIR / "policy.sig", by)
    return {"lab": lab}


def _co_cau_chap_hanh(root: Path, board: str) -> list[tuple[str, str]]:
    """`[(ref, giá trị)]` của các linh kiện trông như cơ cấu chấp hành, từ netlist board này."""
    mau = _re_co_cau()
    ra = []
    for ref, pt in sorted(doc_part(root, board).items()):
        van = " ".join(str(pt.get(k) or "") for k in ("mpn", "value", "footprint"))
        if mau.search(van):
            ra.append((ref, str(pt.get("mpn") or pt.get("value") or "?")))
    return ra


def _ky_lai(ctx: Context, cfg: dict[str, Any], sig: Path, by: str) -> None:
    """Ký lại niêm trên cấu hình SAU hợp nhất, rồi cập nhật luôn cổng đang chạy.

    Ký trên `{**defaults, **autonomy.yaml}` chứ không trên riêng tệp dự án — `whitelist.bam()`
    nhận cấu hình sau hợp nhất, nên ký trên tệp dự án thôi sẽ ra một băm không bao giờ khớp.

    Cập nhật `gate.config` sau khi ký vì `PolicyGate` đọc cấu hình một lần lúc dựng. Không cập
    nhật thì đánh dấu lab xong, ngay lời gọi `target.flash` tiếp theo trong cùng phiên vẫn thấy
    board chưa lab — người dùng đọc ra là "đánh dấu không ăn", rồi đánh dấu lại.
    """
    from eide_core import whitelist
    from eide_core.paths import spec_dir

    defaults = yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8"))
    hop_nhat = {**defaults, **cfg}
    led = ctx.extra.get("ledger")
    whitelist.ky(hop_nhat, sig, by=by, led=led)
    if (gate := ctx.extra.get("gate")) is not None and hasattr(gate, "config"):
        gate.config = hop_nhat
        gate.danh_sach_da_ky, gate.ly_do_chua_ky = whitelist.kiem(hop_nhat, sig, led)
