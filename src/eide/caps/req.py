"""Namespace req.* — CDS-12.1 (tập Kỹ nghệ); DDD-14 §2 Requirement; PRS-16 vai trò `architect`.

Tám năng lực, và như nhóm `plan.*`, ranh giới deterministic ↔ có sinh là điểm chính:

**Deterministic** — `detect_conflict` (một phần), `ground_hw`, `prioritize`, `trace_matrix`,
`change_impact`. Đối chiếu ngưỡng với fact là số học; tìm câu thiếu đơn vị là biểu thức chính
quy; nối truy vết là tra bảng. Bước 1 của REQ-04 nói thẳng "quy tắc deterministic" trước khi
nhắc tới mô hình.

**Có sinh** — `elicit`, `classify`, `acceptance`, và phần đề xuất câu chữ của `detect_conflict`.

## Vì sao "câu đo được" là bất biến của cả nhóm

DDD-14 §2 chú thích cột `text` của Requirement đúng ba chữ: **"Câu đo được"**. Một yêu cầu ghi
"phản hồi nhanh" không kiểm được, không sinh test được, và không ai biết khi nào nó xong — nên
nó sẽ được đánh dấu `accepted` bằng cảm tính. `req.detect_conflict` bắt đúng loại câu ấy bằng
quy tắc, không nhờ mô hình nhận xét.
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# REQ-02: "bảng nhóm (SNS cảm biến, CTL điều khiển, COM giao tiếp, PWR nguồn, SAF an toàn, UI…)".
NHOM = {
    "SNS": ("cảm biến", "sensor", "đo", "nhiệt độ", "adc", "bme", "mpu", "imu"),
    "CTL": ("điều khiển", "control", "pid", "motor", "động cơ", "servo", "pwm"),
    "COM": ("giao tiếp", "uart", "i2c", "spi", "can", "usb", "wifi", "ble", "truyền"),
    "PWR": ("nguồn", "pin", "battery", "dòng", "công suất", "ngủ", "sleep"),
    "SAF": ("an toàn", "safety", "watchdog", "dừng khẩn", "lỗi", "fault"),
    "UI": ("màn hình", "led", "nút", "hiển thị", "display", "button"),
}

# REQ-04: "từ mơ hồ (nhanh, đủ, tốt)". Danh sách này là quy tắc, không phải gợi ý cho mô hình.
TU_MO_HO = ("nhanh", "chậm", "đủ", "tốt", "ổn định", "hợp lý", "phù hợp", "tối ưu", "mượt",
            "chính xác", "đáng tin", "dễ dùng", "kịp thời", "thấp", "cao")

# Đại lượng có thể so ngưỡng — REQ-04 "cùng đại lượng ngưỡng trái nhau".
#
# Bảng này ghi TƯỜNG MINH `đơn vị → (đại lượng, hệ số về đơn vị gốc)`. Suy hệ số từ tiền tố
# ("m" = milli) là bẫy: trong "MSPS" và "MHz" thì "M" là mega, còn trong "ms" và "mA" thì "m" là
# milli — cùng một chữ cái, lệch 10⁹ lần. Một bảng dài mà đúng hơn một quy tắc ngắn mà sai.
DON_VI: dict[str, tuple[str, float]] = {
    "hz": ("tần số", 1), "khz": ("tần số", 1e3), "mhz": ("tần số", 1e6),
    "ghz": ("tần số", 1e9),
    "s": ("thời gian", 1), "giây": ("thời gian", 1), "ms": ("thời gian", 1e-3),
    "us": ("thời gian", 1e-6), "µs": ("thời gian", 1e-6), "ns": ("thời gian", 1e-9),
    "phút": ("thời gian", 60),
    "byte": ("bộ nhớ", 1), "kb": ("bộ nhớ", 1e3), "mb": ("bộ nhớ", 1e6),
    "kib": ("bộ nhớ", 1024), "mib": ("bộ nhớ", 1048576),
    "a": ("dòng", 1), "ma": ("dòng", 1e-3), "ua": ("dòng", 1e-6), "µa": ("dòng", 1e-6),
    "v": ("điện áp", 1), "mv": ("điện áp", 1e-3),
    "sps": ("tốc độ lấy mẫu", 1), "ksps": ("tốc độ lấy mẫu", 1e3),
    "msps": ("tốc độ lấy mẫu", 1e6),
}

DAI_LUONG = {q for q, _ in DON_VI.values()}


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm req.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _gateway(ctx: Context) -> Any:
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    return gw


def _ngu_canh(ctx: Context, task: str) -> str:
    from eide.caps.memory import compose
    b = compose({"role": "architect", "task_ref": task}, ctx)["bundle"]
    return "\n\n".join(x["text"] for x in b["blocks"] if x["layer"] != "C1")


# ---------------------------------------------------------------- đo lường (dùng chung)


def do_duoc(text: str) -> tuple[float, str] | None:
    """Rút (giá trị, đơn vị chuẩn hóa) từ một câu — nền của cả `detect_conflict` và `ground_hw`.

    Chuẩn hóa về đơn vị gốc (Hz, s, byte…) ngay tại đây: "400 kHz" và "0,4 MHz" là CÙNG một
    ngưỡng, và so chuỗi thì chúng khác nhau. Đó chính là loại mâu thuẫn giả mà REQ-04 sẽ báo nếu
    không chuẩn hóa — và một cảnh báo giả lặp lại làm người ta thôi đọc cảnh báo thật.

    Duyệt HẾT các cụm số+chữ rồi lấy cụm đầu tiên có đơn vị NHẬN RA ĐƯỢC. Lấy cụm đầu tiên bất kể
    đơn vị thì "bus I2C chạy 400 kHz" rút ra `2C` — tên ngoại vi nuốt mất ngưỡng thật.
    """
    for m in re.finditer(r"(\d+(?:[.,]\d+)?)\s*([a-zA-ZµμΩ]{1,4})\b", text):
        if (dv := DON_VI.get(m.group(2).lower())):
            return float(m.group(1).replace(",", ".")) * dv[1], dv[0]
    return None


# ---------------------------------------------------------------- có sinh


@capability("req.elicit")
def elicit(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-01 — CDS-12.1. tc: "README robot → ≥ 15 yêu cầu thô có locator".

    Mỗi câu yêu cầu GIỮ `locator` — nguồn và vị trí trong nguồn. Không có nó thì sau này không
    ai trả lời được "yêu cầu này từ đâu ra", và một yêu cầu không truy nguyên được thì không
    tranh luận được: người viết README nói một đằng, tác tử nhớ một nẻo, và không có bản gốc để
    đối chiếu.
    """
    nguon = list(params.get("sources") or [])
    # Hợp đồng để `required: []` — cả ba ô đều có thể trống. Nhưng trống HẾT thì không có gì để
    # tách, và ask_when nói đúng trường hợp ấy: "Ô trống không có mặc định".
    text = params.get("text") or params.get("feature") or ""
    if not text and not nguon:
        raise EideError("E5002", "req.elicit không có đầu vào: cần `text`, `feature` hoặc "
                        "`sources` (REQ-01 ask: Ô trống không có mặc định)",
                        thieu=["text", "feature", "sources"])
    if not text:
        text = "Đọc các nguồn sau và tách yêu cầu: " + ", ".join(nguon)
    resp = _gateway(ctx).run(
        "architect",
        f"Tách yêu cầu thô từ mô tả sau. Mỗi CÂU một yêu cầu, giữ nguyên văn.\n\n{text}",
        _SCHEMA_RAW, system_extra=_ngu_canh(ctx, text))
    raw = list(resp.data.get("raw") or [])
    for i, r in enumerate(raw):
        r.setdefault("source", nguon[0] if nguon else "lệnh")
        r.setdefault("locator", {"index": i})
    gaps = list(resp.data.get("gaps") or [])
    ghi_clarification(_root(ctx), gaps, cap="req.elicit", ctx=ctx)
    return {"raw": raw, "gaps": gaps}


_SCHEMA_RAW = {
    "type": "object", "required": ["raw"],
    "properties": {
        "raw": {"type": "array", "items": {
            "type": "object", "required": ["text"],
            "properties": {"text": {"type": "string"}, "source": {"type": "string"},
                           "locator": {"type": "object"},
                           "kind_guess": {"type": "string"}}}},
        "gaps": {"type": "array", "items": {"type": "object"}},
    },
}


@capability("req.classify")
def classify(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-02 — CDS-12.1; DDD-14 §2 Requirement. tc: "Mỗi yêu cầu có mã duy nhất".

    Mã do MÃ NGUỒN gán, không do mô hình: `UR-SNS-01` phải duy nhất và liên tiếp, mà một mô hình
    sinh mã sẽ trùng lặp ngay khi chạy hai lần trên hai tập yêu cầu khác nhau. Mô hình chỉ phân
    loại `kind` và viết lại câu cho đo được — hai việc nó làm tốt.
    """
    raw = params["raw"]
    root = _root(ctx)
    LOI_NHAC = ("Phân loại từng yêu cầu và viết lại thành CÂU ĐO ĐƯỢC "
                "(có đơn vị và ngưỡng khi có thể).\n")
    resp = _gateway(ctx).run(
        "architect", LOI_NHAC + json.dumps(raw, ensure_ascii=False),
        _SCHEMA_CLASSIFY, system_extra=_ngu_canh(ctx, "phân loại yêu cầu"))

    # HỎI LẠI MỘT LẦN nếu câu yêu cầu bị mất dấu. [DEV-168]
    #
    # Lời nhắc vai trò `architect` nay đòi tiếng Việt CÓ DẤU, nhưng một lời nhắc là bảo đảm
    # MỀM — đo 22/09/2026 trên bài CNC: trong cùng một dự án, ba yêu cầu mất dấu và hai yêu cầu
    # có dấu. Câu yêu cầu là thứ người dùng đọc và ký duyệt, và chữ không dấu vừa khó đọc vừa
    # mơ hồ ("can" là *cần* hay *căn* hay *cân*).
    #
    # Một lần, không lặp: cùng khuôn với phép sửa schema của Gateway ("sai schema sau 1 lần
    # sửa" → E5002). Hỏi mãi thì một mô hình không làm được sẽ đốt tiền của người dùng cho tới
    # khi hết ngân sách.
    #
    # Lần hai vẫn hỏng thì GIỮ NGUYÊN bản hỏng chứ không tự thêm dấu: khôi phục dấu tiếng Việt
    # là việc của một mô hình, và đoán sai một dấu làm đổi nghĩa câu yêu cầu — tệ hơn để nguyên
    # chữ không dấu mà người đọc biết là chưa chuẩn.
    hong = [r.get("text", "") for r in (resp.data.get("reqset") or [])
            if thieu_dau_tieng_viet(r.get("text", ""))]
    if hong:
        lai = _gateway(ctx).run(
            "architect",
            LOI_NHAC
            + "LƯU Ý: lần trước bạn viết tiếng Việt KHÔNG DẤU. Viết lại CÓ DẤU đầy đủ; "
              "định danh kỹ thuật (USB, FAT32, CRC32) giữ nguyên.\n"
            + json.dumps(raw, ensure_ascii=False),
            _SCHEMA_CLASSIFY, system_extra=_ngu_canh(ctx, "phân loại yêu cầu"))
        con = [r.get("text", "") for r in (lai.data.get("reqset") or [])
               if thieu_dau_tieng_viet(r.get("text", ""))]
        led = ctx.extra.get("ledger")
        if led is not None:
            led.append("model.call", {"cap": "req.classify", "vi": "viết lại vì thiếu dấu",
                                      "truoc": len(hong), "sau": len(con)})
        # Chỉ nhận bản mới khi nó THẬT SỰ tốt hơn: một lần viết lại tệ hơn vẫn là một lần đổi.
        if len(con) < len(hong):
            resp = lai

    dem = _dem_theo_nhom(root)
    reqset = []
    for i, r in enumerate(resp.data.get("reqset") or []):
        goc = raw[i] if i < len(raw) else {}
        kind = r.get("kind", "FR")
        # DDD-14 §2 cho ĐÚNG ba dạng mã: `UR-xx-nn | FR-xx-nn | NFR-nn`. NFR không mang nhóm —
        # một yêu cầu phi chức năng ("khởi động ≤ 2 s") thường cắt ngang nhiều nhóm, gán nó vào
        # SNS hay CTL đều sai.
        if kind == "NFR":
            khoa, ma = "NFR", "NFR-{:02d}"
        else:
            khoa = _nhom_cua(r.get("text", "") or goc.get("text", ""))
            ma = ("UR" if kind in ("HW", "SAFETY") else "FR") + f"-{khoa}-" + "{:02d}"
        dem[khoa] = dem.get(khoa, 0) + 1
        reqset.append({
            "id": ma.format(dem[khoa]), "kind": kind,
            "text": r.get("text") or goc.get("text", ""),
            "source": goc.get("source", "lệnh"),
            "locator": goc.get("locator"), "status": "generated",
        })
    _ghi_requirement(root, reqset)
    return {"reqset": reqset, "codes_assigned": len(reqset)}


_SCHEMA_CLASSIFY = {
    "type": "object", "required": ["reqset"],
    "properties": {"reqset": {"type": "array", "items": {
        "type": "object", "required": ["kind", "text"],
        "properties": {"kind": {"type": "string",
                                "enum": ["FR", "NFR", "HW", "SAFETY", "RT", "CR"]},
                       "text": {"type": "string"}}}}},
}


def _nhom_cua(text: str) -> str:
    t = text.lower()
    for ma, tu in NHOM.items():
        if any(x in t for x in tu):
            return ma
    return "GEN"


def _dem_theo_nhom(root: Path) -> dict[str, int]:
    """Số thứ tự tiếp theo của mỗi nhóm, đọc từ store.

    Đếm từ những mã ĐÃ PHÁT RA, không đếm lại từ đầu: một mã đã dùng thì không được tái sử dụng
    kể cả khi yêu cầu ấy bị bỏ — nhật ký, tài liệu và ma trận truy vết còn nhắc tới nó.
    """
    db = store.store_path(root)
    if not db.exists():
        return {}
    with store.open_store(db) as c:
        ids = [r[0] for r in c.execute("SELECT id FROM requirement").fetchall()]
    dem: dict[str, int] = {}
    for i in ids:
        if (m := re.fullmatch(r"(?:UR|FR)-([A-Z]+)-(\d+)", str(i))):
            dem[m.group(1)] = max(dem.get(m.group(1), 0), int(m.group(2)))
        elif (m := re.fullmatch(r"NFR-(\d+)", str(i))):
            dem["NFR"] = max(dem.get("NFR", 0), int(m.group(1)))
    return dem


#: Từ tiếng Việt CHỈ tồn tại khi có dấu. Gặp chúng viết trần là dấu chắc chắn đã mất dấu, không
#: phải người dùng cố ý viết tiếng Anh. Danh sách ngắn và chọn từ rất phổ biến trong câu yêu cầu.
_TU_MAT_DAU = frozenset("""
he thong phai duoc khong va cua cho voi tu den trong ngoai truoc sau khi neu thi ma
thoi gian toi da thieu bao nhieu dung sai gia tri muc nguong ket noi thanh cong
""".split())


def thieu_dau_tieng_viet(van: str) -> bool:
    """Câu này có phải tiếng Việt BỊ MẤT DẤU không. [DEV-168]

    Đo 22/09/2026 trên bài CNC: trong cùng một dự án, ba yêu cầu mất dấu ("He thong phai cung
    cap giao dien mang…") và hai yêu cầu có dấu. Câu yêu cầu là thứ người dùng đọc và ký duyệt;
    chữ không dấu vừa khó đọc vừa MƠ HỒ — "can" là *cần* hay *căn* hay *cân*.

    Nhận diện bằng TỪ, không bằng phép đếm dấu: một câu tiếng Anh hợp lệ ("USB Mass Storage
    Class") cũng không có dấu nào, và chặn nó là chặn nhầm. Chỉ khi thấy những từ CHỈ TỒN TẠI
    trong tiếng Việt viết trần mới kết luận.

    Không tự sửa: khôi phục dấu tiếng Việt là việc của một mô hình, và đoán sai một dấu làm đổi
    nghĩa câu yêu cầu — tệ hơn để nguyên chữ không dấu mà người đọc biết là chưa chuẩn.
    """
    tu = {t.strip(".,;:()[]") for t in van.lower().split()}
    return len(tu & _TU_MAT_DAU) >= 3


def ghi_clarification(root: Path, ds: list[dict[str, Any]], *, cap: str,
                      ctx: Context | None = None) -> int:
    """Ghi các điểm CẦN LÀM RÕ xuống store — [DEV-151].

    Tới 21/09/2026 `req.elicit.gaps` và `req.detect_conflict.issues` được tính rồi vứt đi ngay:
    không bảng nào giữ chúng, nên tab "Làm rõ yêu cầu" không có gì để hiện và lấp chỗ trống bằng
    lịch sử trò chuyện. Tác tử tìm ra đúng thứ người cần biết, rồi quên nó trong cùng một nhịp.

    Mã ổn định theo NỘI DUNG (`CL-<băm>`), không theo thứ tự: `req.detect_conflict` chạy lại sau
    mỗi lần tập yêu cầu đổi, và một mã chạy theo thứ tự sẽ đẻ ra bản sao của cùng một điểm sau
    mỗi lần chạy — người dùng trả lời một câu rồi thấy nó quay lại dưới mã khác.

    KHÔNG ghi đè câu trả lời đã có: `INSERT OR IGNORE`, vì một điểm người đã trả lời mà bị dựng
    lại thành `open` là xoá công của người.
    """
    db = store.store_path(root)
    if not db.exists() or not ds:
        return 0
    now = datetime.now(UTC).isoformat()
    run_id = ((ctx.extra.get("chain") or {}) if ctx is not None else {}).get("run_id")
    n = 0
    with store.open_store(db) as c:
        for d in ds:
            van = str(d.get("text") or d.get("question") or "").strip()
            if not van:
                continue
            ma = "CL-" + hashlib.sha256(
                f"{d.get('kind') or 'gap'}|{van}".encode()).hexdigest()[:10]
            c.execute(
                "INSERT OR IGNORE INTO clarification (id, kind, text, req_ids, suggestion,"
                " source_cap, run_id, status, created_at) VALUES (?,?,?,?,?,?,?, 'open', ?)",
                (ma, d.get("kind") or "gap", van,
                 json.dumps(d.get("req_ids") or [], ensure_ascii=False),
                 d.get("suggestion"), cap, run_id, now))
            n += c.total_changes and 1 or 0
        c.commit()
    return n


def _ghi_requirement(root: Path, ds: list[dict[str, Any]]) -> None:
    db = store.store_path(root)
    if not db.exists():
        return
    now = datetime.now(UTC).isoformat()
    with store.open_store(db) as c:
        for r in ds:
            c.execute("INSERT OR REPLACE INTO requirement (id, kind, text, priority, acceptance,"
                      " trace, source, feasibility, status, updated_at)"
                      " VALUES (?,?,?,?,?,?,?,?,?,?)",
                      (r["id"], r["kind"], r["text"], r.get("priority"),
                       json.dumps(r.get("acceptance") or [], ensure_ascii=False),
                       json.dumps(r.get("trace") or [], ensure_ascii=False),
                       r.get("source"),
                       json.dumps(r.get("feasibility")) if r.get("feasibility") else None,
                       r.get("status", "generated"), now))
        c.commit()


@capability("req.acceptance")
def acceptance(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-07 — CDS-12.1. tc: "Mỗi yêu cầu ≥ 1 AC; AC có kind quan sát".

    Cùng bất biến với `plan.define_feature`: kỳ vọng phải MÁY quan sát được. Ở đây kiểm bằng
    cách đòi `observable` thuộc ba dạng, và một tiêu chí chấp nhận không quan sát được thì
    `req.trace_matrix` sẽ báo nó là lỗ hổng — vì không test nào nối vào được.
    """
    ids = params["reqset_ids"]
    root = _root(ctx)
    ds = _doc_requirement(root, ids)
    if not ds:
        raise EideError("E2000", f"Không có yêu cầu nào trong {ids}",
                        exists=[], candidates=[], missing=list(ids))
    resp = _gateway(ctx).run(
        "architect",
        "Sinh tiêu chí chấp nhận Given–When–Then cho từng yêu cầu.\n"
        + json.dumps([{"id": r["id"], "text": r["text"]} for r in ds], ensure_ascii=False),
        _SCHEMA_AC, system_extra=_ngu_canh(ctx, "tiêu chí chấp nhận"))

    ac = list(resp.data.get("acceptance") or [])
    thieu = {r["id"] for r in ds} - {a.get("req_id") for a in ac}
    if thieu:
        raise EideError("E5002", f"Yêu cầu không có tiêu chí chấp nhận nào: {sorted(thieu)} "
                        "(REQ-07: mỗi yêu cầu ≥ 1 AC)", thieu=sorted(thieu))
    theo_req: dict[str, list[dict[str, Any]]] = {}
    for a in ac:
        theo_req.setdefault(a["req_id"], []).append(a)
    for r in ds:
        r["acceptance"] = theo_req.get(r["id"], [])
    _ghi_requirement(root, ds)
    return {"acceptance": ac}


_SCHEMA_AC = {
    "type": "object", "required": ["acceptance"],
    "properties": {"acceptance": {"type": "array", "items": {
        "type": "object", "required": ["req_id", "given", "when", "then", "observable"],
        "properties": {"req_id": {"type": "string"}, "given": {"type": "string"},
                       "when": {"type": "string"}, "then": {"type": "string"},
                       "observable": {"type": "string",
                                      "enum": ["serial_pattern", "probe_reg", "measurement"]}}}}},
}


def _doc_requirement(root: Path, ids: list[str]) -> list[dict[str, Any]]:
    db = store.store_path(root)
    if not db.exists() or not ids:
        return []
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT id, kind, text, priority, acceptance, trace, source, feasibility, status"
            f" FROM requirement WHERE id IN ({','.join('?' * len(ids))})",  # noqa: S608
            list(ids)).fetchall()
    ten = ["id", "kind", "text", "priority", "acceptance", "trace", "source", "feasibility", "status"]
    ra = []
    for r in rows:
        d = dict(zip(ten, r, strict=True))
        for k in ("acceptance", "trace", "feasibility"):
            if isinstance(d[k], str):
                d[k] = json.loads(d[k])
        ra.append(d)
    return ra


# ---------------------------------------------------------------- deterministic


@capability("req.detect_conflict")
def detect_conflict(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-04 — CDS-12.1. tc: TC-68; ask "Mâu thuẫn không tự giải được".

    Bước 1 của hợp đồng nói thẳng "quy tắc deterministic", và ba quy tắc ấy làm được hết mà
    không cần mô hình: cùng đại lượng ngưỡng trái nhau; thiếu đơn vị/số; từ mơ hồ.

    Điểm dễ sai nhất là quy tắc thứ nhất — phải CHUẨN HÓA ĐƠN VỊ trước khi so. "400 kHz" và
    "0,4 MHz" là cùng một ngưỡng; báo chúng mâu thuẫn là một cảnh báo giả, và cảnh báo giả lặp
    lại làm người ta thôi đọc cảnh báo thật.
    """
    root = _root(ctx)
    ds = _doc_requirement(root, params["reqset_ids"])
    issues: list[dict[str, Any]] = []

    # (a) từ mơ hồ
    for r in ds:
        t = (r.get("text") or "").lower()
        if (mo := [x for x in TU_MO_HO if re.search(rf"\b{x}\b", t)]):
            issues.append({"kind": "ambiguous", "req_ids": [r["id"]], "text": r["text"],
                           "suggestion": f"thay {mo} bằng một ngưỡng có đơn vị",
                           "tu_mo_ho": mo})

    # (b) thiếu số/đơn vị ở những yêu cầu đáng lẽ phải đo được
    for r in ds:
        if r.get("kind") in ("NFR", "RT", "HW") and do_duoc(r.get("text") or "") is None:
            issues.append({"kind": "unmeasurable", "req_ids": [r["id"]], "text": r["text"],
                           "suggestion": "nêu ngưỡng kèm đơn vị (ví dụ ≤ 50 ms, ≥ 100 kHz)"})

    # (c) cùng đại lượng, ngưỡng trái nhau — sau khi chuẩn hóa
    theo_dl: dict[str, list[tuple[str, float, str]]] = {}
    for r in ds:
        if (dv := do_duoc(r.get("text") or "")):
            theo_dl.setdefault(dv[1], []).append((r["id"], dv[0], r["text"]))
    for dl, muc in theo_dl.items():
        for i in range(len(muc)):
            for j in range(i + 1, len(muc)):
                a, b = muc[i], muc[j]
                if a[1] != b[1] and _cung_chu_de(a[2], b[2]):
                    issues.append({"kind": "conflict", "req_ids": [a[0], b[0]],
                                   "text": f"{dl}: {a[2]!r} ≠ {b[2]!r}",
                                   "suggestion": "chọn một ngưỡng, hoặc nêu điều kiện áp dụng "
                                                 "cho từng ngưỡng"})
    ghi_clarification(root, issues, cap="req.detect_conflict", ctx=ctx)
    return {"issues": issues}


# Từ quá phổ biến để chứng minh hai câu nói về cùng một thứ. "Bus I2C … chạy" và "Bus SPI …
# chạy" chung nhau {bus, chạy} — đếm chúng thì mọi cặp yêu cầu cùng đơn vị đều thành mâu thuẫn.
TU_CHUNG = frozenset("""bus chạy của phải hệ thống được trong với cho các một khi thì này
    những đó và hoặc tại từ đến mỗi phải nhất tối thiểu đa giá trị mức khi cần dùng sử dụng
    thiết bị board mạch chương trình""".split())


def _cung_chu_de(a: str, b: str) -> bool:
    """Hai câu có nói về cùng một thứ không — chặn báo mâu thuẫn giữa hai yêu cầu không liên quan.

    "I2C 400 kHz" và "SPI 8 MHz" đều là tần số nhưng nói về hai bus khác nhau; báo chúng mâu
    thuẫn là báo động giả. Đòi ≥ 2 từ chung KHÔNG PHẢI từ phổ thông, sau khi bỏ số và đơn vị.
    """
    def tu(x: str) -> set[str]:
        x = re.sub(r"\d+(?:[.,]\d+)?\s*[a-zA-ZµμΩ]{1,4}\b", " ", x.lower())
        return {w for w in re.split(r"[^0-9a-zA-ZÀ-ỹ]+", x) if len(w) > 2} - TU_CHUNG
    return len(tu(a) & tu(b)) >= 2


@capability("req.ground_hw")
def ground_hw(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-03 — CDS-12.1. tc: TC-67 "ADC 1 MSPS vs fact 2,4 MSPS → ok; 5 MSPS → không ok".

    So ngưỡng yêu cầu với fact hộ chiếu — số học, không hỏi mô hình. Không có fact thì ghi
    "chưa xác định" và đề nghị `kg.request`, KHÔNG đoán: một yêu cầu được đánh dấu "khả thi" dựa
    trên phỏng đoán sẽ đi tiếp vào kiến trúc, vào mã, và chỉ lộ ra khi board đã đặt về.
    """
    root = _root(ctx)
    ds = _doc_requirement(root, params["reqset_ids"])
    db = store.store_path(root)
    # DDD-14: passport.id là `ns.part@semver`, fact.subject là IRI `chip:ns.part/periph:…`.
    # LỌC THEO HỘ CHIẾU là bắt buộc, không phải tối ưu: fact của một chip khác mà dùng để kết
    # luận "khả thi" cho board này thì tệ hơn không có fact nào — nó sai một cách tự tin.
    part = str(params["passport"]).split("@")[0]
    facts: list[tuple] = []
    if db.exists():
        with store.open_store(db) as c:
            facts = c.execute(
                "SELECT id, subject, predicate, value, unit FROM fact"
                " WHERE (status IN ('reviewed','verified') OR tier='gold')"
                "   AND (subject = ? OR subject LIKE ? OR subject LIKE ?)",
                (part, f"%:{part}", f"%:{part}/%")).fetchall()

    report = []
    for r in ds:
        can = do_duoc(r.get("text") or "")
        if can is None:
            report.append({"req_id": r["id"], "ok": None, "facts": [],
                           "note": "yêu cầu không nêu ngưỡng đo được — chưa đối chiếu được"})
            continue
        khop = [f for f in facts if _cung_chu_de(f[1] + " " + str(f[3]), r["text"])
                or _cung_don_vi(f, can[1])]
        if not khop:
            report.append({"req_id": r["id"], "ok": None, "facts": [],
                           "note": "chưa xác định — hộ chiếu không có số liệu tương ứng",
                           "alternative": "kg.request để xin số liệu"})
            continue
        # Fact là NĂNG LỰC của phần cứng, yêu cầu là NHU CẦU; khả thi khi năng lực ≥ nhu cầu.
        tot = [f for f in khop if (fv := do_duoc(f"{f[3]} {f[4] or ''}")) and fv[0] >= can[0]]
        report.append({"req_id": r["id"], "ok": bool(tot),
                       "facts": [f[0] for f in (tot or khop)],
                       "note": ("đạt" if tot else "vượt khả năng phần cứng theo hộ chiếu"),
                       **({} if tot else {"alternative": "giảm ngưỡng, hoặc chọn linh kiện khác "
                                                         "(search.registry)"})})
    for r, rep in zip(ds, report, strict=False):
        r["feasibility"] = {"ok": rep["ok"], "facts": rep["facts"], "note": rep["note"]}
    _ghi_requirement(root, ds)
    return {"report": report}


def _cung_don_vi(fact: tuple, dai_luong: str) -> bool:
    """Fact có đơn vị cùng ĐẠI LƯỢNG với ngưỡng yêu cầu — MSPS khớp kSPS, không khớp MHz."""
    return (DON_VI.get((fact[4] or "").lower()) or ("", 0))[0] == dai_luong


@capability("req.prioritize")
def prioritize(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-05 — CDS-12.1. tc: "SAFETY luôn M"; ask "Đổi ưu tiên M↔S".

    `SAFETY` luôn `M` là quy tắc CỨNG, không phải gợi ý: một yêu cầu an toàn bị hạ xuống
    "Should" là một yêu cầu sẽ bị cắt khi hết thời gian, và đó đúng là lúc người ta cần nó nhất.
    Ép ở mã nên không lời gọi mô hình nào đổi được.

    Mức T1* ("làm rồi báo cáo") kèm ask "Đổi ưu tiên M↔S": tự gán lần đầu thì được, nhưng đổi
    một yêu cầu ĐÃ có ưu tiên từ M sang S là quyết định phạm vi — việc của người.
    """
    root = _root(ctx)
    ds = _doc_requirement(root, params["reqset_ids"])
    goal = params.get("goal") or ""
    lat = []
    for r in ds:
        cu = r.get("priority")
        # Tính lại TỪ ĐẦU, không phải `cu or mặc_định`: nếu đã có ưu tiên là bỏ qua thì lời gọi
        # thứ hai không bao giờ đổi gì, và ask "M↔S" là quy tắc chết — không đường nào chạm tới.
        moi = "M" if r.get("kind") == "SAFETY" else _uu_tien_theo(r, goal)
        if cu and {cu, moi} == {"M", "S"}:
            lat.append({"req_id": r["id"], "tu": cu, "sang": moi})
        r["priority"] = moi
    if lat and ctx.actor != "human":
        raise EideError("E3000", f"Đổi ưu tiên M↔S của {[x['req_id'] for x in lat]} là quyết "
                        "định phạm vi, cần người xác nhận (REQ-05 ask: Đổi ưu tiên M↔S)",
                        rule="REQ-05", gate="*", changes=lat)
    _ghi_requirement(root, ds)
    return {"reqset": ds}


# MoSCoW theo loại — SAFETY và HW là ràng buộc không thương lượng; NFR thường co giãn được.
UU_TIEN_LOAI = {"SAFETY": "M", "HW": "M", "RT": "S", "FR": "S", "NFR": "C", "CR": "C"}
THANG = ["W", "C", "S", "M"]


def _uu_tien_theo(r: dict[str, Any], goal: str) -> str:
    """Bước 1 nêu bốn căn cứ; ở mức deterministic dùng được hai: loại, và độ liên quan mục tiêu.

    "Phụ thuộc" và "rủi ro phần cứng" cần đồ thị module và kết quả `ground_hw` — sẽ nối khi
    `arch.*` có. Chúng KHÔNG được đoán ở đây: một ưu tiên bịa ra từ câu chữ còn khó sửa hơn một
    ưu tiên để trống, vì nó trông như đã có người cân nhắc.
    """
    p = UU_TIEN_LOAI.get(r.get("kind", "FR"), "C")
    if goal and _cung_chu_de(goal, r.get("text") or ""):
        p = THANG[min(THANG.index(p) + 1, len(THANG) - 1)]
    if (r.get("feasibility") or {}).get("ok") is False:
        p = THANG[max(THANG.index(p) - 1, 0)]     # không khả thi trên board thì chưa thể là M
    return p


@capability("req.trace_matrix")
def trace_matrix(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-06 — CDS-12.1. tc: TC-68 "lỗ hổng liệt kê".

    Giá trị nằm ở cột `gaps`, không ở ma trận: một yêu cầu KHÔNG có module hay KHÔNG có test là
    một yêu cầu sẽ được tuyên bố hoàn thành mà chưa ai kiểm. Ma trận đầy đủ chỉ là cách nhìn ra
    những chỗ trống ấy.
    """
    root = _root(ctx)
    # Hợp đồng KHÔNG nhận `reqset_ids` — ma trận truy vết là của TOÀN dự án. Cho lọc tập con thì
    # sẽ có người xuất ma trận "không lỗ hổng" bằng cách chọn đúng những yêu cầu đã xong.
    ds = _doc_requirement(root, _moi_requirement(root))
    dinh_dang = params.get("format", "md")
    hang, gaps = [], []
    for r in ds:
        trace = r.get("trace") or []
        co_module = [t for t in trace if str(t).startswith(("mod_", "M-"))]
        co_test = [t for t in trace if str(t).startswith(("TC-", "tc_"))]
        co_ac = bool(r.get("acceptance"))
        hang.append({"req_id": r["id"], "kind": r["kind"], "priority": r.get("priority"),
                     "modules": co_module, "tests": co_test, "acceptance": len(r.get("acceptance") or [])})
        if not co_module:
            gaps.append({"req_id": r["id"], "thieu": "module", "vi": "chưa ai hiện thực"})
        if not co_test and not co_ac:
            gaps.append({"req_id": r["id"], "thieu": "test",
                         "vi": "không có cách kiểm — sẽ được tuyên bố xong mà chưa ai kiểm"})

    f = root / EIDE_DIR / "docs" / f"trace_matrix.{'xlsx' if dinh_dang == 'xlsx' else 'md'}"
    f.parent.mkdir(parents=True, exist_ok=True)
    if dinh_dang == "xlsx":
        _xuat_xlsx(f, hang, gaps)
    else:
        f.write_text(_xuat_md(hang, gaps), encoding="utf-8")
    return {"file": str(f), "gaps": gaps}


def _moi_requirement(root: Path) -> list[str]:
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        return [r[0] for r in c.execute("SELECT id FROM requirement ORDER BY id").fetchall()]


def _xuat_md(hang: list[dict[str, Any]], gaps: list[dict[str, Any]]) -> str:
    d = ["# Ma trận truy vết yêu cầu", "",
         "| Yêu cầu | Loại | Ưu tiên | Module | Test | AC |",
         "| --- | --- | --- | --- | --- | --- |"]
    for h in hang:
        d.append(f"| {h['req_id']} | {h['kind']} | {h['priority'] or '—'} | "
                 f"{', '.join(h['modules']) or '—'} | {', '.join(h['tests']) or '—'} | "
                 f"{h['acceptance']} |")
    d += ["", f"## Lỗ hổng ({len(gaps)})", ""]
    d += [f"- **{g['req_id']}** thiếu {g['thieu']} — {g['vi']}" for g in gaps] or ["Không có."]
    return "\n".join(d) + "\n"


def _xuat_xlsx(f: Path, hang: list[dict[str, Any]], gaps: list[dict[str, Any]]) -> None:
    from openpyxl import Workbook
    wb = Workbook()
    ws = wb.active
    ws.title = "Truy vết"
    ws.append(["Yêu cầu", "Loại", "Ưu tiên", "Module", "Test", "AC"])
    for h in hang:
        ws.append([h["req_id"], h["kind"], h["priority"], ", ".join(h["modules"]),
                   ", ".join(h["tests"]), h["acceptance"]])
    wg = wb.create_sheet("Lỗ hổng")
    wg.append(["Yêu cầu", "Thiếu", "Vì"])
    for g in gaps:
        wg.append([g["req_id"], g["thieu"], g["vi"]])
    wb.save(f)


@capability("req.change_impact")
def change_impact(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-08 — CDS-12.1. tc: "Đổi yêu cầu → module/test/tài liệu liên quan stale";
    ask "Tác động > ngưỡng (≥ 3 module)".

    Dùng `kg.impact` cho phần fact, `requirement.trace` cho phần thiết kế. Ngưỡng ba module
    không phải con số tùy tiện: một thay đổi chạm ba module trở lên không còn là sửa cục bộ mà
    là đổi thiết kế, và đó là lúc người nên xem lại trước khi tác tử đi tiếp.
    """
    delta = params["delta"]
    root = _root(ctx)
    ids = list(delta.get("req_ids") or []) if isinstance(delta, dict) else [str(delta)]
    ds = _doc_requirement(root, ids)

    modules: set[str] = set()
    tests: set[str] = set()
    for r in ds:
        for t in (r.get("trace") or []):
            (modules if str(t).startswith(("mod_", "M-")) else tests).add(str(t))

    code_units: set[str] = set()
    for fid in (delta.get("fact_ids") or [] if isinstance(delta, dict) else []):
        from eide.caps.kg import impact
        code_units |= set(impact({"fact_id": fid}, ctx)["stale_code_units"])

    ra = {"modules": sorted(modules), "code_units": sorted(code_units), "tests": sorted(tests),
          "docs": [], "diagrams": [], "features": []}
    if len(modules) >= 3 and ctx.actor != "human":
        raise EideError("E3000", f"Thay đổi chạm {len(modules)} module — không còn là sửa cục bộ "
                        "mà là đổi thiết kế (REQ-08 ask: tác động > ngưỡng)", rule="REQ-08",
                        gate="*", impact=ra)
    return {"impact": ra}


@capability("req.answer_clarification")
def answer_clarification(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REQ-09 — CDS-12.1; UXC-31 §8 S9; DPS-09 D3; undo `restore_answer`. [DEV-151]

    **Vế NGƯỜI của việc làm rõ yêu cầu.** Tác tử tìm ra điểm mờ (`req.elicit.gaps`) và chỗ mâu
    thuẫn (`req.detect_conflict.issues`); tới 21/09/2026 không có đường nào cho người trả lời
    chúng, nên bảng ở tab "Làm rõ yêu cầu" là bảng chỉ đọc và cuộc cộng tác dừng một chiều.

    **Chỉ THÊM, không ghi đè.** Mỗi lần trả lời là một dòng mới trong `clarification_answer`;
    `clarification.answer` chỉ là bản hiện hành cho đọc nhanh. Chủ sản phẩm đòi "rollback lại
    theo TỪNG LẦN thay đổi", và một cột bị ghi đè không làm được điều đó — sổ cái cũng không,
    vì `cap.run.start` chỉ giữ `args_hash`.

    `actor` là `human:<tên>` chứ không phải `agent`: đây là việc của người, và một thay đổi của
    người mang nhãn tác tử sẽ làm mọi phép truy trách nhiệm sau này sai.
    """
    root = _root(ctx)
    ma = str(params["clar_id"]).strip()
    van = str(params["answer"]).strip()
    if not van:
        raise EideError("E1000", "Câu trả lời rỗng — không ghi gì cả", missing=["answer"])
    db = store.store_path(root)
    now = datetime.now(UTC).isoformat()
    ai = str(getattr(ctx, "actor", "") or "human")
    with store.open_store(db) as c:
        d = c.execute("SELECT status FROM clarification WHERE id=?", (ma,)).fetchone()
        if d is None:
            co = [r[0] for r in c.execute(
                "SELECT id FROM clarification WHERE status='open' LIMIT 20")]
            raise EideError("E2000", f"Không có điểm cần làm rõ nào mang mã `{ma}`",
                            exists=co, candidates=[], missing=[ma])
        so = int(c.execute("SELECT COUNT(*) FROM clarification_answer WHERE clar_id=?",
                           (ma,)).fetchone()[0]) + 1
        c.execute("INSERT INTO clarification_answer (id, clar_id, answer, answered_by, at,"
                  " run_id) VALUES (?,?,?,?,?,?)",
                  (f"{ma}#{so}", ma, van, ai, now, ctx.extra.get("cap_run_id")))
        c.execute("UPDATE clarification SET answer=?, answered_by=?, answered_at=?,"
                  " status='answered' WHERE id=?", (van, ai, now, ma))
        c.commit()
    led = ctx.extra.get("ledger")
    if led is not None:
        led.append("human.file_save", {"clar_id": ma, "revision": so, "by": ai,
                                       "cap": "req.answer_clarification"})
        # KHÔNG tự đăng ký mục hoàn tác ở đây. Router đã đăng ký một mục với `undo_ref` là mã
        # lượt chạy, cho MỌI năng lực khai một loại hoàn tác — thêm một mục nữa ở đây làm cột
        # phải hiện HAI nút Hoàn tác cho cùng một việc, và mục trên cùng lại là mục Router
        # đăng ký nên nút người bấm là nút bộ hoàn tác không đọc được.
        #
        # Đo 22/09/2026 qua giao diện: bấm Hoàn tác trả về "Không đọc được `undo_ref`
        # `fdfafbb4e45f` — cần `clar:<id>`". Thay vì dựng một mã song song, `clarification_answer`
        # nay ghi `run_id`, nên mã của Router trỏ thẳng vào ĐÚNG bản trả lời.
    return {"clar_id": ma, "status": "answered", "answer": van, "revision": so}


def hoan_tac_cau_tra_loi(root: Path, khoa: str) -> dict[str, Any]:
    """Gỡ MỘT bản trả lời, khôi phục bản trước đó — bộ hoàn tác `restore_answer`.

    `khoa` là mã lượt chạy đã ghi bản ấy (Router đăng ký mục hoàn tác bằng `run_id`), hoặc mã
    một điểm cần làm rõ — khi ấy gỡ bản mới nhất của điểm ấy.

    Gỡ ĐÚNG BẢN mà mã trỏ tới chứ không phải "bản mới nhất": đó là khác biệt giữa "hoàn tác
    theo từng lần thay đổi" và "hoàn tác lần cuối". Người trả lời ba điểm rồi muốn rút lại câu
    thứ nhất thì hai câu kia phải ở nguyên.

    Đánh dấu `undone_at` chứ không xoá dòng: một lần hoàn tác cũng là một sự kiện, và xoá nó đi
    thì lần sau không ai biết câu trả lời ấy từng tồn tại.
    """
    db = store.store_path(root)
    now = datetime.now(UTC).isoformat()
    with store.open_store(db) as c:
        r = c.execute("SELECT id, answer, clar_id FROM clarification_answer WHERE run_id=?"
                      " AND undone_at IS NULL LIMIT 1", (khoa,)).fetchone()
        if r is None:
            ma = khoa[5:] if khoa.startswith("clar:") else khoa
            r = c.execute("SELECT id, answer, clar_id FROM clarification_answer WHERE clar_id=?"
                          " AND undone_at IS NULL ORDER BY at DESC, id DESC LIMIT 1",
                          (ma.split("#", 1)[0],)).fetchone()
        if r is None:
            raise EideError("E2000", f"`{khoa}` không trỏ tới bản trả lời nào còn hiệu lực",
                            exists=[], candidates=[], missing=[khoa])
        clar_id = r[2]
        c.execute("UPDATE clarification_answer SET undone_at=? WHERE id=?", (now, r[0]))
        truoc = c.execute("SELECT answer, answered_by FROM clarification_answer WHERE clar_id=?"
                          " AND undone_at IS NULL ORDER BY at DESC, id DESC LIMIT 1",
                          (clar_id,)).fetchone()
        if truoc is None:
            c.execute("UPDATE clarification SET answer=NULL, answered_by=NULL,"
                      " answered_at=NULL, status='open' WHERE id=?", (clar_id,))
        else:
            c.execute("UPDATE clarification SET answer=?, answered_by=?, answered_at=?,"
                      " status='answered' WHERE id=?", (truoc[0], truoc[1], now, clar_id))
        c.commit()
    return {"clar_id": clar_id, "da_go": r[1],
            "quay_ve": truoc[0] if truoc else None,
            "status": "answered" if truoc else "open"}
