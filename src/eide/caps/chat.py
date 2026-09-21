"""Namespace chat.* — tầng hiểu lệnh. CDS-12.6; DPS-09 §2–§5; PRS-16 §7.

Bốn trách nhiệm của DPS-09 §2 chia ra thành các năng lực có hợp đồng, chứ không gộp thành một
hàm lớn: ① hiểu và đối chiếu = `parse_intent` + `ground`; ③ đủ thông tin = `fill_defaults` +
`clarify`; ④ chính sách và báo cáo = `report_back` (chính sách đã do Router lo). Tách như thế
để tầng hiểu lệnh kiểm thử được bằng kịch bản xác định, độc lập với chất lượng sinh của mô
hình — đó là câu cuối của §2 và cũng là lý do TC-59 chạy được.

② lập chuỗi = `orchestrate` (CHAT-06): chọn chuỗi mẫu theo ý định, kiểm deterministic,
rồi chạy từng nút qua Router — cùng đường đi với mọi lời gọi khác, nên cùng chính sách và nhật ký.
"""
from __future__ import annotations

import json
import secrets
import sqlite3
import time
import unicodedata
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide.caps.project import EIDE_DIR, slugify
from eide_core import chain as chain_mod
from eide_core import store
from eide_core.errors import EideError
from eide_core.gateway import Gateway
from eide_core.paths import spec_dir
from eide_core.registry import capability, get_registry
from eide_core.router import Context
from eide_core.undo import UndoService

NGUONG_UNKNOWN = 0.6      # DPS-09 §4.1
MAX_DONG_REPORT = 10      # CHAT-07 steps


def _schema_intent() -> dict[str, Any]:
    return json.loads((spec_dir() / "dialog" / "intent.schema.json").read_text(encoding="utf-8"))


def _ngu_canh(ctx: Context, text: str) -> str:
    """Dựng ngữ cảnh cho vai trò `intent` qua `memory.compose` (CXD-10 §4.1).

    Trước đây đây là một hàm `_c0()` ghép chuỗi tại chỗ: nó chạy, nhưng không có ngân sách,
    không có thứ tự cắt, không ghi `context.bundle` vào ledger — nên không ai đo được ngữ cảnh
    đang tốn bao nhiêu, và §9 của CXD-10 (đo lường và tinh chỉnh) không có dữ liệu để làm việc.
    Nay đi qua Composer như mọi vai trò khác.
    """
    from eide.caps.memory import compose
    return _ghep(compose({"role": "intent", "task_ref": text}, ctx)["bundle"])


def _ghep(bundle: dict[str, Any]) -> str:
    """Ghép các khối NGOÀI C1: C1 đã là `system` của Gateway, đưa lại lần nữa là lặp."""
    thu_tu = {"C2": 0, "C0": 1, "C3": 2, "C4": 3, "C5": 4, "C6": 5, "C7": 6}
    kh = [b for b in bundle["blocks"] if b["layer"] != "C1"]
    kh.sort(key=lambda b: thu_tu.get(b["layer"], 9))
    return "\n\n".join(b["text"] for b in kh)


def _gateway(ctx: Context) -> Gateway:
    gw = ctx.extra.get("gateway")
    if gw is None:
        gw = Gateway(ledger=ctx.extra.get("ledger"))
        ctx.extra["gateway"] = gw
    return gw


# ---------------------------------------------------------------- ① hiểu

@capability("chat.parse_intent")
def parse_intent(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-01 — CDS-12.6; DPS-09 §4.1; PRS-16 §2 vai trò `intent`; TC-59; E5002.

    `confidence < 0,6 ⇒ unknown` được ép ở MÃ chứ không nhờ mô hình tự nhận: một mô hình không
    chắc chắn thì cũng không chắc chắn về việc mình không chắc chắn. Giữ nguyên con số
    confidence để sau còn truy được vì sao một câu bị coi là không hiểu.
    """
    text = params["text"]
    dinh_kem = params.get("attachments") or []
    lenh = text if not dinh_kem else f"{text}\n(đính kèm: {', '.join(dinh_kem)})"
    resp = _gateway(ctx).run("intent", lenh, _schema_intent(), system_extra=_ngu_canh(ctx, text))
    intent = dict(resp.data)

    if float(intent.get("confidence", 0)) < NGUONG_UNKNOWN:
        intent["intent"] = "unknown"
    if dinh_kem:
        intent.setdefault("slots", {})["path"] = dinh_kem[0]

    led = ctx.extra.get("ledger")
    if led is not None:
        led.append("intent", {"text": text[:200], "intent": intent["intent"],
                              "is_big": bool(intent.get("is_big")),
                              "confidence": intent.get("confidence"),
                              "slots": intent.get("slots", {})})
    return {"intent": intent}


@capability("chat.ground")
def ground(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-02 — CDS-12.6; DPS-09 §4.2; TC-60 (tạo trùng = 0).

    DETERMINISTIC — không một lời gọi mô hình nào. §2 ① nói thẳng "tra store trực tiếp
    (deterministic), không nhờ mô hình nhớ": trạng thái thật là thứ đọc được, và hỏi mô hình về
    nó là mời ảo giác vào đúng chỗ nguy hiểm nhất. Test `test_ground_khong_goi_mo_hinh` giữ
    chỗ này bằng cách kiểm rằng Gateway không hề được gọi.
    """
    intent = params["intent"]
    slots = intent.get("slots") or {}
    ten = slots.get("project_name") or slots.get("idea") or ""
    nhac = list(intent.get("mentions") or [])
    ws = Path(ctx.project_dir).expanduser() if ctx.project_dir else None

    exists: list[dict[str, Any]] = []
    candidates: list[dict[str, Any]] = []
    if ws and ws.is_dir():
        # Nếu ctx trỏ thẳng vào một dự án thì workspace là thư mục cha của nó.
        goc = ws.parent if (ws / EIDE_DIR).is_dir() else ws
        for p in sorted(goc.iterdir()):
            if not (p / EIDE_DIR).is_dir():
                continue
            mo_ta = _tom_tat_du_an(p)
            khoa = {slugify(x) for x in [ten, *nhac] if x}
            if p.name in khoa or any(slugify(x) == p.name for x in nhac):
                exists.append(mo_ta)
            elif ten and _gan_giong(p.name, slugify(ten)):
                candidates.append(mo_ta)

    thieu: list[str] = []
    goc_da = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    co_du_an = bool(goc_da and (goc_da / EIDE_DIR).is_dir())
    if intent.get("intent") in ("target.flash", "sim.run", "code.feature", "debug.ask") and not co_du_an:
        thieu.append("project")
    if intent.get("intent") == "target.flash" and not slots.get("board"):
        thieu.append("board")
    if intent.get("intent") == "project.open" and not exists:
        thieu.append("project")

    return {"grounded": {"exists": exists, "candidates": candidates, "missing": thieu}}


def _tom_tat_du_an(p: Path) -> dict[str, Any]:
    e = p / EIDE_DIR
    c = yaml.safe_load((e / "constraints.yaml").read_text(encoding="utf-8")) if (e / "constraints.yaml").exists() else {}
    f = json.loads((e / "FEATURES.json").read_text(encoding="utf-8")) if (e / "FEATURES.json").exists() else {"features": []}
    ds = f.get("features", [])
    return {"name": p.name, "path": str(p),
            "created": (c.get("project") or {}).get("created"),
            "board": (c.get("target") or {}).get("board"),
            "passing": sum(1 for x in ds if x.get("status") == "passing"), "total": len(ds)}


def _gan_giong(a: str, b: str) -> bool:
    """§4.2: "khớp gần đúng theo từ khóa (robot, cân bằng, balance)"."""
    if not a or not b:
        return False
    ta, tb = set(a.split("-")), set(b.split("-"))
    chung = ta & tb - {"du", "an", "va", "cho"}
    return len(chung) >= 2 or a in b or b in a


# ---------------------------------------------------------------- ③ đủ thông tin

# §4.3 thứ tự tìm mặc định. `preferences` đứng ĐẦU vì D8: câu trả lời của người thắng mọi
# suy đoán của máy — và đó là cơ chế làm số câu hỏi giảm dần theo thời gian (§7).
NGUON_MAC_DINH = ("preferences", "suy ra", "autonomy.defaults", "năng lực")

# Ô trống nào cần điền cho mỗi ý định. Bảng này là deterministic, không nhờ mô hình.
O_CAN_DIEN = {
    "project.create": ["project_name", "project_dir", "create_when_exists"],
    "diagram.draw": ["diagram_lang"],
    "doc.write": ["doc_lang"],
    "sim.run": ["sim_first"],
    "code.feature": ["sim_first"],
    "target.flash": ["sim_first"],
}


@capability("chat.fill_defaults")
def fill_defaults(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-03 — CDS-12.6; DPS-09 §4.3, D2, D8; TC-61.

    Trả cả `applied[]` kèm NGUỒN của từng mặc định, không chỉ giá trị: §7 đo "tỷ lệ mặc định
    bị người đổi ≤ 20%", và không biết mặc định đến từ đâu thì con số ấy không sửa được gì.
    """
    intent = json.loads(json.dumps(params["intent"]))     # không sửa tham số của người gọi
    slots = intent.setdefault("slots", {})
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    co_du_an = bool(root and (root / EIDE_DIR).is_dir())

    prefs = _doc_preferences(root) if co_du_an else {}
    auto = {}
    if co_du_an:
        f = root / EIDE_DIR / "autonomy.yaml"
        if f.exists():
            auto = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("defaults") or {}
    if not auto:
        auto = (yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8"))
                or {}).get("defaults") or {}

    applied: list[dict[str, Any]] = []
    for o in O_CAN_DIEN.get(intent.get("intent", ""), []):
        if slots.get(o) is not None:
            continue                                        # người đã nói rồi thì không đè
        gia_tri, tu = None, None
        if o in prefs:                                       # (1) preferences — D8
            gia_tri, tu = prefs[o].get("value"), "preferences"
        elif (suy := _suy_ra(o, intent, params.get("grounded") or {})) is not None:   # (2)
            gia_tri, tu = suy, "suy ra"
        elif o in auto:                                      # (3) autonomy.defaults
            gia_tri, tu = auto[o], "autonomy.defaults"
        if gia_tri is None:
            continue
        slots[o] = gia_tri
        applied.append({"slot": o, "value": gia_tri, "from": tu})

    led = ctx.extra.get("ledger")
    if led is not None and applied:
        led.append("intent", {"intent": intent.get("intent"), "defaults_applied": applied})
    return {"intent": intent, "applied": applied}


def _suy_ra(o: str, intent: dict[str, Any], grounded: dict[str, Any]) -> Any:
    """§4.3 (2): suy từ câu lệnh và Grounded."""
    slots = intent.get("slots") or {}
    if o == "project_name" and slots.get("idea"):
        return slugify(slots["idea"])
    if o == "board":
        for e in grounded.get("exists") or []:
            if e.get("board"):
                return e["board"]
    return None


def _doc_preferences(root: Path) -> dict[str, Any]:
    from eide.caps.project import _pref_db_all, _pref_yaml_all
    return {**_pref_yaml_all(), **_pref_db_all(root)}


@capability("chat.clarify")
def clarify(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-04 — CDS-12.6; DPS-09 D3, §4.3; TC-61 (timeout 120 s → mặc định).

    D3 đòi MỘT câu hỏi cho mọi điểm mơ hồ, và §7 đo "≤ 1 câu hỏi trên một lệnh". Nên `gaps[]`
    được gộp thành một Question duy nhất, đánh số phương án liên tục từ 1 — nếu hỏi từng ô một
    thì chỉ số ấy không bao giờ đạt được, dù mỗi câu hỏi riêng lẻ đều hợp lý.

    Hết giờ thì lấy mặc định chứ không treo: một tác tử đứng chờ vô hạn là một tác tử đã hỏng,
    và mặc định đã được chọn là "phương án an toàn nhất" (§4.3).
    """
    gaps = params["gaps"]
    if not gaps:
        raise EideError("E1000", "clarify cần ít nhất một gap")
    ngu_canh = params.get("context") or {}

    options: list[dict[str, Any]] = []
    mac_dinh_n = 1
    for g in gaps:
        for i, op in enumerate(g.get("options") or []):
            options.append({"n": len(options) + 1, "label": op["label"], "value": op["value"],
                            "slot": g["slot"]})
            if i == int(g.get("default", 0)) and g is gaps[0]:
                mac_dinh_n = len(options)
    cau = " ".join(f"{g['slot']}?" for g in gaps)
    question = {"text": f"Anh chọn giúp: {cau}", "options": options, "default": mac_dinh_n,
                "timeout_s": int(ngu_canh.get("timeout_s", 120)),
                "remember_as": [g.get("remember_as") for g in gaps if g.get("remember_as")]}

    led = ctx.extra.get("ledger")
    if led is not None:
        led.append("question", {"question_id": f"q_{int(time.time() * 1000) % 10**9}",
                                "text": question["text"], "n_options": len(options)})

    tra_loi = ngu_canh.get("answer")
    by = ngu_canh.get("by", "human") if tra_loi else "timeout"
    if not tra_loi:
        if question["timeout_s"] > 0:
            time.sleep(min(question["timeout_s"], 0.01))     # chờ thật, nhưng test không đợi 120 s
        chon = options[mac_dinh_n - 1]
        tra_loi = {chon["slot"]: chon["value"]}

    if led is not None:
        led.append("answer", {"answer": tra_loi, "by": by})
    # D8: câu trả lời của người được ghi nhớ; của timeout thì KHÔNG — nó không phải lựa chọn
    # của ai cả, và ghi nhớ nó sẽ biến một lần im lặng thành một tùy chọn vĩnh viễn.
    if by == "human":
        for g in gaps:
            if g.get("remember_as") and g["slot"] in tra_loi:
                _ghi_nho(ctx, g["remember_as"], tra_loi[g["slot"]], question["text"])
    return {"question": question, "answer": tra_loi, "by": by}


def _ghi_nho(ctx: Context, key: str, value: Any, tu_dau: str) -> None:
    from eide.caps.project import preferences
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    scope = "project" if root and (root / EIDE_DIR).is_dir() else "user"
    preferences({"op": "set", "key": key, "scope": scope, "value": value,
                 "learned_from": f"chat.clarify: {tu_dau[:60]}"}, ctx)


@capability("chat.restate")
def restate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-05 — CDS-12.6; DPS-09 D4; TC-62.

    Nói lại bằng MẪU CỐ ĐỊNH, không nhờ mô hình diễn đạt: câu này tồn tại để người bắt lỗi hiểu
    sai TRƯỚC khi chuỗi chạy, nên nó phải phản ánh đúng thứ máy sắp làm — một câu văn hay do mô
    hình viết lại có thể mượt hơn mà lệch khỏi `chain` thật.
    """
    intent = params["intent"]
    chain = params["chain"]
    slots = intent.get("slots") or {}
    caps = [n["cap"] for n in chain]
    tom = ", ".join(caps[:4]) + (f" và {len(caps) - 4} bước nữa" if len(caps) > 4 else "")
    doi_tuong = (slots.get("project_name") or slots.get("idea") or slots.get("feature")
                 or slots.get("question"))
    if not doi_tuong:
        # KHÔNG in dấu gạch ngang. Đo 21/09/2026, chặng A bài CNC bước 3: thẻ Ý hiểu ghi
        # "Tôi hiểu là req.analyze: —." cho câu "bộ điều khiển đó chỉ đọc được USB, nó không có
        # cổng mạng…" — một câu ràng buộc rõ ràng mà `chat.parse_intent` không rút ra slot nào.
        #
        # §2D.6 dựng thẻ này để người bắt được một lệnh bị HIỂU SAI trước khi nó ghi tệp. Một
        # dấu gạch ngang không cho người ta bắt gì cả: nó trông như một trường trống vô hại,
        # trong khi thứ nó đang nói là "tôi không rút được đối tượng nào từ câu của anh" —
        # đúng lúc cần người đọc dừng lại và kiểm.
        return {"text": f"Tôi hiểu là {intent.get('intent')}, nhưng KHÔNG rút được đối tượng "
                        f"cụ thể nào từ câu của anh — hãy đọc kỹ các bước dưới trước khi để "
                        f"tôi chạy. Tôi sẽ {tom}."}
    return {"text": f"Tôi hiểu là {intent.get('intent')}: {doi_tuong}. Tôi sẽ {tom}."}


# ---------------------------------------------------------------- ④ báo cáo

@capability("chat.report_back")
def report_back(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-07 — CDS-12.6; DPS-09 §2 ④; TC-64.

    Khác `report.progress` (REPORT-01) ở chỗ đứng: cái kia là báo cáo một KỲ cho người xem lại;
    cái này là câu trả lời cho MỘT lệnh vừa chạy, hiện trong ChatPanel — nên ≤ 10 dòng.
    """
    led = ctx.extra.get("ledger")
    recs = led.records() if led is not None else []
    ten: dict[str, str] = {}
    done: list[str] = []
    waiting: list[str] = []
    cost = 0.0
    for r in recs:
        d = r.get("data") or {}
        if r["kind"] == "cap.run.start" and d.get("run_id"):
            ten[d["run_id"]] = d.get("cap", "?")
        elif r["kind"] == "cap.run.finish" and d.get("run_id"):
            if d.get("status") == "done":
                done.append(ten.get(d["run_id"], "?"))
            elif d.get("status") == "pending":
                waiting.append(ten.get(d["run_id"], "?"))
        elif r["kind"] == "model.call":
            cost += float(d.get("cost_usd") or 0)
    undo = UndoService(led, getattr(ctx.extra.get("gate"), "config", None)).list() if led else []

    report = {"run_id": params["run_id"], "done": done, "waiting": waiting,
              "undo": [u["undo_ref"] for u in undo], "cost": round(cost, 6)}
    dong = [f"Đã làm {len(done)} việc" + (f": {', '.join(dict.fromkeys(done))}" if done else ".")]
    if waiting:
        dong.append(f"Đang chờ anh: {', '.join(dict.fromkeys(waiting))}.")
    if undo:
        dong.append(f"Hoàn tác được {len(undo)} mục đến {(undo[0]['deadline'] or 'hết phiên')[:16]}.")
    if cost:
        dong.append(f"Chi phí mô hình: {cost:.4f} USD.")
    return {"report": report, "text": "\n".join(dong[:MAX_DONG_REPORT])}


LY_DO_VI = {
    "not_in_passport": "Điều này chưa có trong hộ chiếu chip của dự án",
    "policy_reject": "Chính sách tự chủ từ chối việc này",
    "cannot": "Tôi chưa làm được việc này",
    "out_of_scope": "Việc này nằm ngoài phạm vi EIDE",
}
DE_XUAT_MAC_DINH = {
    "not_in_passport": ["gửi datasheet để tôi trích fact", "kg.request tạo yêu cầu nhận tri thức"],
    "policy_reject": ["nâng mức tự chủ nếu anh đồng ý", "duyệt tay trong hàng đợi"],
    "cannot": ["mô tả rõ hơn điều anh muốn"],
    "out_of_scope": ["nêu việc gần nhất trong phạm vi để tôi làm"],
}


@capability("chat.decline")
def decline(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-08 — CDS-12.6; DPS-09 D6; UC-H04; MEM-11 §6 (sổ lỗi → prompt phủ định).

    Từ chối phải mang LÝ DO và ĐỀ XUẤT. Một câu "không làm được" trống rỗng đẩy người vào ngõ
    cụt, và tệ hơn: nó dạy người dùng ngừng hỏi. Ghi vào sổ lỗi để MEM-11 §6 sinh prompt phủ
    định — mỗi lần từ chối là một dữ kiện về chỗ tri thức đang thiếu.
    """
    ly_do = params["reason"]
    chi_tiet = params.get("detail", "")
    de_xuat = params.get("suggestions") or DE_XUAT_MAC_DINH.get(ly_do, [])
    text = f"{LY_DO_VI.get(ly_do, ly_do)}"
    if chi_tiet:
        text += f": {chi_tiet}"
    text += "." + ("" if not de_xuat else " Anh có thể: " + "; ".join(de_xuat) + ".")

    led = ctx.extra.get("ledger")
    if led is not None:
        led.append("error", {"kind": "refusal", "role": "orchestrator",
                             "evidence": f"{ly_do}: {chi_tiet}"[:200], "task_ref": ly_do})
    return {"text": text}


def _unaccent(s: str) -> str:
    t = s.replace("đ", "d").replace("Đ", "D")
    return unicodedata.normalize("NFD", t).encode("ascii", "ignore").decode().lower()


@capability("chat.orchestrate")
def orchestrate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CHAT-06 — CDS-12.6; DPS-09 §4.4 (lập chuỗi), §1 (ranh giới deterministic ↔ sinh);
    POL-17 §6 (leo thang). tc: TC-63.

    Năm bước của hợp đồng, và bước nào cũng có một lý do cụ thể để không làm khác:

    1. **Chọn chuỗi mẫu theo `trigger_intents` trước, planner sau.** §4.4 nói thẳng: mẫu tồn tại
       "để mô hình bám theo thay vì sáng tác". Một chuỗi sáng tác lại mỗi lần thì hai lần chạy
       cùng một lệnh cho hai kế hoạch khác nhau, và không ai gỡ được lỗi trong đó.
    2. **Kiểm deterministic SAU khi có chuỗi**, kể cả chuỗi từ mẫu. Mẫu cũng có thể trỏ tới năng
       lực chưa hiện thực ở mốc hiện tại — đó là trạng thái bình thường giữa chừng, không phải
       lỗi của mẫu.
    3. **Run planned → running**, ghi `run.graph` xuống store để "tiếp tục sau tắt máy".
    4. **Mỗi nút một `Router.invoke`** — cùng đường đi với mọi lời gọi khác, nên cùng chính sách,
       cùng nhật ký, cùng hoàn tác. Orchestrator KHÔNG có đường tắt.
    5. **`on_ask` quyết định nhánh làm gì khi một nút chờ người**; hỏng ≥ 2 lần thì leo thang
       (POL-17 §6 `fail_retries`), không thử mãi.
    """
    intent = params["intent"]
    ten_y_dinh = intent.get("intent", "unknown") if isinstance(intent, dict) else str(intent)
    grounded = params.get("grounded") or {}

    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None

    # v1.3 — chạy tiếp một lượt đang `planned` (DEV-140). Dùng LẠI đồ thị đã ghi và giữ nguyên
    # `run_id`: người vừa đọc danh sách bước ấy rồi gật đầu, nên lập lại kế hoạch ở đây là chạy
    # một chuỗi khác chuỗi họ đồng ý.
    tiep = str(params.get("resume_of") or "")
    if tiep:
        kh = doc_ke_hoach(root, tiep) if root is not None else None
        if kh is None or kh["state"] != "planned":
            raise EideError("E2000", f"`{tiep}` không phải một lượt đang `planned`"
                            + (f" (đang `{kh['state']}`)" if kh else ""),
                            exists=[kh["state"]] if kh else [], candidates=["planned"],
                            missing=[tiep])
        run_id = tiep
        chuoi = chain_mod.Chain([chain_mod.Nut.tu_dict(n)
                                 for n in (kh["graph"].get("nodes") or [])])
        nguon = "chạy tiếp kế hoạch đã duyệt"
        intent = kh["intent"] or intent
        ten_y_dinh = intent.get("intent", ten_y_dinh) if isinstance(intent, dict) else ten_y_dinh
    else:
        run_id = "r_" + secrets.token_hex(6)
        # Bước 1 — mẫu trước, planner sau.
        mau = chain_mod.chon_mau(ten_y_dinh)
        chuoi, nguon = _dung_chuoi(mau, intent, grounded, ctx, run_id)

    # Bước 2 — kiểm deterministic. Ném E5002 (cấu trúc) hoặc E3003 (ngân sách).
    gate = ctx.extra.get("gate")
    nguong = ((getattr(gate, "config", None) or {}).get("thresholds") or {})
    thieu_du_kien = chain_mod.kiem(
        chuoi, get_registry(),
        tran_nut=int(nguong.get("plan_max_steps") or chain_mod.TRAN_NUT),
        chi_phi_uoc=_uoc_chi_phi(chuoi),
        ngan_sach=float(nguong.get("plan_max_cost_usd") or 0) or None)
    can_nguoi = {x["id"]: x["thieu"] for x in thieu_du_kien}

    # Bước 3 — ghi kế hoạch xuống store TRƯỚC khi chạy: một chuỗi đang chạy dở mà máy tắt thì
    # phần đã làm vẫn phải đọc lại được, và `run.graph` là chỗ duy nhất giữ được điều đó.
    so_run = _so_run(root)
    buoc_ds = [{"id": n.id, "cap": n.cap} for n in chain_mod.thu_tu_chay(chuoi)]
    led = ctx.extra.get("ledger")

    # v1.3 — `plan_only` (DEV-140, UXC-31 §2D.6). Dừng ở ĐÂY: kế hoạch đã ghi, chưa nút nào
    # chạy. Đó là trạng thái trung gian mà §2D.6 cần để hai nút "Đúng — làm đi" / "Sửa ý hiểu"
    # có nghĩa; tới v1.2 không có nó, nên hai nút ấy sẽ nằm trên một chuỗi đã giao đi.
    #
    # KHÔNG ghi `run.started`: chưa có gì bắt đầu. Một thẻ Run hiện lên cho một lượt đang chờ
    # người gật đầu là nói rằng tác tử đang làm việc trong khi nó đang đợi.
    if params.get("plan_only"):
        _ghi_run(root, run_id, chuoi, "planned", intent)
        if led is not None:
            led.append("intent", {"run_id": run_id, "n": so_run, "state": "planned",
                                  "intent": ten_y_dinh, "steps": buoc_ds,
                                  "text": str(params.get("text") or "")[:120]})
        return {"run_id": run_id, "state": "planned", "steps": buoc_ds}

    _ghi_run(root, run_id, chuoi, "running", intent)
    # `run.started` TRƯỚC hành động đầu tiên — quy tắc P-RUN-01 của UXD-13 v2.0. Thẻ Run phải
    # tồn tại trước khi có việc để hiển thị; ngược lại thì bước đầu chạy xong rồi giao diện mới
    # biết có một lượt chạy, và người dùng thấy tiến độ bắt đầu từ giữa chừng.
    if led is not None:
        # Câu NGƯỜI GÕ, không phải tên ý định. "Run #17 · code.feature" đúng nhưng vô nghĩa
        # với người vừa gõ "đọc cảm biến BME280 qua I2C" — họ nhận ra việc của mình bằng chính
        # câu mình viết. Lùi về tên ý định khi không có câu gốc (chuỗi do planner dựng).
        van = str(params.get("text") or "").strip() or str(ten_y_dinh)
        led.append("run.started", {"run_id": run_id, "n": so_run,
                                   "text": van[:120], "steps": buoc_ds})

    # Bước 4–5 — chạy từng nút.
    ket_qua, cho, bo_qua, hong = [], [], [], []
    # Đầu ra từng nút, để nút sau đọc bằng `${nX.field}`. Giữ trong bộ nhớ của lượt chạy này:
    # `run.graph` dưới store giữ KẾ HOẠCH, không giữ kết quả, và một kết quả có thể là cả một
    # CodePatch — thứ không nên đi vòng qua đĩa giữa hai nút liền nhau.
    dau_ra: dict[str, Any] = {}
    router = ctx.extra.get("router")
    xong: set[str] = set()
    for nut in chain_mod.thu_tu_chay(chuoi):
        if nut.when and nut.when not in xong:
            # Nhánh cha đang chờ hoặc đã hỏng. `wait` dừng nhánh này; `parallel` để nhánh khác
            # chạy tiếp (chính là việc không làm gì ở đây); `skip` bỏ qua và ghi chú.
            (bo_qua if nut.on_ask == "skip" else cho).append(
                {"id": nut.id, "cap": nut.cap, "vi": f"chờ nút {nut.when}"})
            continue
        if router is None:
            cho.append({"id": nut.id, "cap": nut.cap, "vi": "không có router trong ngữ cảnh"})
            continue
        # Nút thiếu dữ kiện thì CHỜ NGƯỜI, không làm hỏng chuỗi. `scenario` của `sim.run` và
        # `target` của `target.flash` không nút nào sinh ra được — chúng đến từ người dùng. Trước
        # 17/09/2026 chúng nằm chung rổ với lỗi cấu trúc, nên một câu hỏi đáng lẽ hỏi người lại
        # giết cả chuỗi NGAY LÚC LẬP, kể cả phần đầu đã đủ dữ kiện để chạy.
        if nut.id in can_nguoi:
            cho.append({"id": nut.id, "cap": nut.cap, "on_ask": nut.on_ask,
                        "thieu": can_nguoi[nut.id],
                        "vi": "cần anh cho biết: " + ", ".join(can_nguoi[nut.id])})
            if led is not None:
                led.append("run.blocked", {"run_id": run_id, "node_id": nut.id, "cap": nut.cap,
                                           "reason": "thiếu tham số", "missing": can_nguoi[nut.id]})
            if nut.on_ask == "wait":
                break
            continue
        try:
            tham_so = chain_mod.giai_tham_chieu(dict(nut.args), dau_ra)
        except EideError as e:
            hong.append({"id": nut.id, "cap": nut.cap, "error": {"eide_code": e.code, "message": str(e)}})
            continue
        # §7.5 — người vừa sửa một tệp thuộc kế hoạch này. Lập lại TRƯỚC khi chạy nút kế tiếp:
        # nút ấy sắp sinh mã trên một nền đã khác, và một patch dựa trên nền cũ hoặc xung đột
        # merge, hoặc — tệ hơn — trông hợp lý mà đè lên ý người dùng.
        _lap_lai_neu_nguoi_sua(run_id, led, router, ctx)
        i_buoc = next((k for k, b in enumerate(buoc_ds, 1) if b["id"] == nut.id), 0)
        # Ngữ cảnh chuỗi đi CÙNG lời gọi: Router ghi nó vào `cap.run.*`, nên mọi bước của một
        # Run gộp về một thẻ ở giao diện mà không cần bên nhận tự đoán.
        ctx.extra["chain"] = {"run_id": run_id, "node_id": nut.id, "i": i_buoc, "of": len(buoc_ds)}
        if led is not None:
            led.append("run.step_started", {"run_id": run_id, "node_id": nut.id, "cap": nut.cap,
                                            "i": i_buoc, "of": len(buoc_ds)})
        try:
            run = router.invoke(nut.cap, tham_so, ctx)
        finally:
            ctx.extra.pop("chain", None)
        if led is not None:
            led.append("run.step_done", {"run_id": run_id, "node_id": nut.id, "cap": nut.cap,
                                         "i": i_buoc, "of": len(buoc_ds), "status": run.status,
                                         **({"error": run.error} if run.error else {})})
        if run.status == "done":
            xong.add(nut.id)
            dau_ra[nut.id] = run.result or {}
            ket_qua.append({"id": nut.id, "cap": nut.cap, "run_id": run.run_id})
        elif run.status == "pending":
            cho.append({"id": nut.id, "cap": nut.cap, "run_id": run.run_id, "on_ask": nut.on_ask})
            if nut.on_ask == "wait":
                break           # dừng cả chuỗi: các nút sau phụ thuộc chỗ này
        else:
            hong.append({"id": nut.id, "cap": nut.cap, "error": run.error})
            if len(hong) >= int(nguong.get("fail_retries") or 2):
                # POL-17 §6: thất bại lặp → leo thang, không thử mãi.
                if router is not None:
                    router.invoke("policy.escalate",
                                  {"reason": "fail_retries", "ref": run_id}, ctx)
                break

    # `cancelled` đứng TRƯỚC mọi trạng thái khác: một chuỗi bị người dừng giữa chừng cũng có
    # nút chờ và nút hỏng, nên nếu xét theo thứ tự cũ thì nó bị gọi là "asked" — tức giao diện
    # nói tác tử đang đợi người, trong khi chính người vừa bảo nó dừng.
    bi_huy = any((x.get("error") or {}).get("eide_code") == "E3002" for x in hong) or any(
        x.get("status") == "cancelled" for x in ket_qua)
    trang_thai = ("cancelled" if bi_huy
                  else "done" if not cho and not hong else ("asked" if cho else "failed"))
    # Hợp đồng trả ĐÚNG `{run_id}` — CHAT-06 là bất đồng bộ theo thiết kế: tiến độ đi qua sự kiện
    # `cap.run.start`/`cap.run.finish` của từng nút (đã có sẵn vì mỗi nút đi qua Router), còn
    # báo cáo cuối nằm ở `run.report` (DDD-14 §2 Run, cột "JSON Report"). Trả cả báo cáo ra
    # ngoài sẽ buộc bên gọi CHỜ hết chuỗi mới nhận được gì — mà một chuỗi 12 nút có thể dừng ở
    # nút thứ ba để hỏi người, và lúc ấy "chờ hết chuỗi" nghĩa là chờ vô hạn.
    _ghi_run(root, run_id, chuoi, trang_thai, intent,
             report={"nguon_chuoi": nguon, "state": trang_thai, "done": ket_qua,
                     "waiting": cho, "skipped": bo_qua, "failed": hong})
    if led is not None:
        if trang_thai == "cancelled":
            led.append("run.cancelled", {"run_id": run_id, "by": "human"})
        else:
            led.append("run.done", {"run_id": run_id, "state": trang_thai, "done": len(ket_qua),
                                    "waiting": len(cho), "failed": len(hong)})
        _dang_ky_undo_run(root, run_id, led, ctx)
    return {"run_id": run_id, "state": trang_thai, "steps": buoc_ds}


def _dang_ky_undo_run(root: Path | None, run_id: str, led: Any, ctx: Context) -> None:
    """Mục hoàn tác **mức lượt chạy** — UXC-31 §6.4 mức 2, tiêu chí N4.

    Chỉ đăng ký khi lượt chạy THẬT SỰ để lại commit. Một mục "hoàn tác cả lượt" trên một lượt
    không ghi gì là một nút bấm vào để nhận E2000 — và người dùng học được rằng nút hoàn tác
    thỉnh thoảng hỏng, chứ không học được rằng lượt ấy vốn không đổi gì.

    Lỗi ở đây KHÔNG được làm hỏng lượt chạy: chuỗi đã chạy xong, kết quả đã ghi. Mất mục hoàn
    tác là mất một tiện nghi; ném lỗi từ đây là mất cả `run_id` của một lượt đã hoàn thành.
    """
    if root is None:
        return
    try:
        from eide_core import git
        from eide_core.undo import UndoService
        if not git.commit_cua_run(root, run_id):
            return
        gate = ctx.extra.get("gate")
        UndoService(led, (getattr(gate, "config", None) or {})).register(
            f"run:{run_id}", "git_revert", cap="chat.orchestrate")
    except Exception:  # noqa: BLE001 — xem docstring
        return


def _dung_chuoi(mau: dict[str, Any] | None, intent: dict[str, Any],
                grounded: dict[str, Any], ctx: Context,
                run_id: str = "") -> tuple[Any, str]:
    """Chuỗi từ mẫu, hoặc từ mô hình lập kế hoạch nếu không mẫu nào khớp.

    Mẫu của §4.4 là chuỗi RÚT GỌN viết cho người đọc ("project.create → search.reference_projects
    → [template? registry.pull : req.elicit] → …"), không phải Chain máy chạy được: nó có nhánh
    điều kiện viết bằng văn xuôi và có `extract.*` là cả một nhóm. Nên ở đây mẫu được dùng làm
    KHUNG — lấy các bước là năng lực có thật và đã hiện thực — còn phần còn lại để planner lo.

    Nói ra giới hạn ấy thay vì im lặng bỏ bớt: một chuỗi 12 bước rút còn 3 mà không ai biết thì
    người dùng tưởng tác tử đã làm cả 12.
    """
    reg = get_registry()
    if mau is not None:
        nut = _tu_nodes(mau, intent, grounded, ctx, run_id, reg) or \
              _tu_buoc(mau, intent, grounded, run_id, reg)
        if nut:
            _noi_dau_ra(nut, reg)
            return chain_mod.Chain(nut), f"mẫu: {mau['ten']}"
    if (mot := _chuoi_toi_thieu(intent, grounded, reg)):
        return chain_mod.Chain(mot), "ý định là năng lực"
    tu_planner = _chuoi_tu_planner(intent, grounded, ctx)
    return chain_mod.Chain(tu_planner), "planner" if tu_planner else "không dựng được chuỗi"


def _tu_nodes(mau: dict[str, Any], intent: dict[str, Any], grounded: dict[str, Any],
              ctx: Context, run_id: str, reg: Any) -> list[Any]:
    """Dựng chuỗi từ trường `nodes` — dạng MÁY DÙNG ĐƯỢC của mẫu (DPS-09 §4.4 v1.3).

    `nodes` có từ DEV-059 và mang `{id, cap, when, on_ask}`; v1.3 mang thêm `args` với tham
    chiếu `${nX.field}` (DEV-121). Tới 21/09 mã vẫn dựng nút từ `buoc` — bản VĂN XUÔI — nên ba
    thứ của `nodes` bị bỏ qua hết: `when` thật (chuỗi bị ép thành một dây thẳng), `on_ask`
    (mọi nhánh điều kiện thành `wait`, tức một nút bỏ qua được lại chặn cả chuỗi), và `args`.
    Phần nối vừa viết vào mẫu vì thế sẽ không bao giờ chạy.

    Tham số của mẫu THẮNG `_args_cho`: mẫu nói "lấy từ nút n8", còn `_args_cho` chỉ biết đọc
    slots của ý định. Một tham chiếu bị một giá trị suy từ slots đè lên là mất đúng phép nối.

    Nút chưa hiện thực bị BỎ, và `when` nối lại theo các nút còn giữ — bỏ bước 3 mà vẫn để bước
    4 phụ thuộc `n3` thì cả chuỗi treo ở một nút không tồn tại.
    """
    ds = mau.get("nodes") or []
    if not ds:
        return []
    giu = [n for n in ds if (n.get("cap") in reg and reg.get(n["cap"]).implemented)]
    if not giu:
        return []
    con = {n["id"] for n in giu}
    ra = []
    for n in giu:
        args = dict(_args_cho(n["cap"], intent, grounded, run_id))
        args.update(n.get("args") or {})
        # Tham chiếu tới một nút ĐÃ BỊ BỎ là một tham chiếu không bao giờ giải được — và nó
        # sẽ giết cả chuỗi ở phép kiểm deterministic. Bỏ nó đi, để nút rơi về "thiếu tham số"
        # và hỏi người: một câu hỏi người trả lời được tốt hơn một chuỗi chết.
        args = {k: v for k, v in args.items()
                if not (isinstance(v, str)
                        and (m := chain_mod.tach_tham_chieu(v)) and m[0] not in con)}
        ra.append(chain_mod.Nut(id=n["id"], cap=n["cap"], args=args,
                                when=n.get("when") if n.get("when") in con else None,
                                on_ask=n.get("on_ask") or "wait"))
    return ra


def _tu_buoc(mau: dict[str, Any], intent: dict[str, Any], grounded: dict[str, Any],
             run_id: str, reg: Any) -> list[Any]:
    """Đường LÙI: dựng từ bản văn xuôi khi mẫu chưa có `nodes`.

    Giữ lại vì `chains.json` là bản sinh — một mẫu mới thêm vào `dps.js` mà quên `nodes` thì
    vẫn chạy được, chỉ mất phần nối. Mất một tiện nghi khác hẳn mất cả chuỗi.
    """
    nut = []
    for i, b in enumerate(mau.get("buoc") or []):
        ten = b.split("(")[0].strip()
        if ten in reg and reg.get(ten).implemented:
            nut.append(chain_mod.Nut(id=f"n{i + 1}", cap=ten,
                                     args=_args_cho(ten, intent, grounded, run_id),
                                     when=None, on_ask="wait"))
    for k, n in enumerate(nut):
        n.when = nut[k - 1].id if k else None
    return nut


def _noi_dau_ra(nut: list[Any], reg: Any) -> None:
    """Nối tham số bắt buộc còn trống của một nút vào ĐẦU RA của nút chạy trước gần nhất.

    Mẫu của §4.4 chỉ liệt kê các BƯỚC; nó không nói bước nào lấy dữ liệu của bước nào. Chỗ duy
    nhất nói được điều ấy mà không phải phỏng đoán là `output_schema`: nếu một nút trước khai ra
    đúng cái tên mà nút này đòi, thì đó là cùng một thứ — trong một bộ đặc tả, một cái tên là
    một khái niệm.

    **Chỉ nối khi tên TRÙNG**, và cố ý dừng ở đó. Bảng ánh xạ kiểu `req.classify.reqset` →
    `req.ground_hw.reqset_ids` thì đúng với mắt người đọc, nhưng nó là tri thức KHÔNG có trong
    bất kỳ tài liệu nào của kho — viết nó vào mã là tự nghĩ ra hành vi. Những chỗ ấy để lại
    trống, và nút thiếu dữ kiện sẽ CHỜ NGƯỜI với câu hỏi nói rõ thiếu gì. Xem DEV-121: đề nghị
    mẫu chuỗi trong `dps.js` tự mang phần nối, vì chỉ mẫu mới có quyền nói điều đó.
    """
    khai: dict[str, list[str]] = {}
    for n in nut:
        if n.cap not in reg:
            continue
        spec = reg.get(n.cap).spec
        for k in ((spec.input_schema or {}).get("required") or []):
            if k in n.args:
                continue
            nguon = [nid for nid, ten in khai.items() if k in ten]
            if nguon:
                n.args[k] = "${" + f"{nguon[-1]}.{k}" + "}"
        khai[n.id] = list(((spec.output_schema or {}).get("properties") or {}).keys())


def _chuoi_toi_thieu(intent: dict[str, Any], grounded: dict[str, Any], reg: Any) -> list[Any]:
    """Chuỗi khi không mẫu nào khớp: ý định-là-năng-lực trước, planner sau.

    Thứ tự ấy không phải để tiết kiệm mà vì độ tin cậy: nếu ý định TRÙNG TÊN một năng lực đã
    hiện thực thì đó là câu trả lời chắc chắn, còn nhờ mô hình lập kế hoạch cho một việc một
    bước là mời ảo giác vào chỗ không cần. Planner chỉ vào cuộc khi thật sự không biết làm gì.
    """
    ten = intent.get("intent", "") if isinstance(intent, dict) else str(intent)
    if ten in reg and reg.get(ten).implemented:
        return [chain_mod.Nut(id="n1", cap=ten, args=_args_cho(ten, intent, grounded))]
    return []


def _chuoi_tu_planner(intent: dict[str, Any], grounded: dict[str, Any],
                      ctx: Context) -> list[Any]:
    """Chuỗi từ vai trò `planner` qua `plan.create` — DPS-09 §4.4, DEV-051 đóng.

    Gọi qua Router chứ không gọi thẳng hàm: `plan.create` là T1* và hỏi cổng G1 bên trong, nên
    một kế hoạch thiếu tri thức hay đổi kiến trúc sẽ dừng ở đó chứ không lặng lẽ thành chuỗi.
    Kế hoạch chờ người thì trả rỗng — và `kiem()` sẽ nói "chuỗi rỗng", đúng sự thật.

    Bước của Plan nào có `cap` là năng lực đã hiện thực thì thành nút; bước không có `cap` là
    việc của người hoặc của một năng lực chưa có, và bỏ chúng đi mà không nói thì người dùng
    tưởng tác tử đã làm cả kế hoạch — nên `nguon_chuoi` ghi rõ số bước giữ lại trên tổng số.
    """
    router = ctx.extra.get("router")
    ten = intent.get("intent", "") if isinstance(intent, dict) else str(intent)
    mo_ta = (intent.get("slots") or {}).get("idea") or (intent.get("slots") or {}).get("feature") or ten
    if router is None or not mo_ta:
        return []
    run = router.invoke("plan.create", {"feature": str(mo_ta)}, ctx)
    if run.status != "done" or not run.result:
        return []
    reg = get_registry()
    buoc = (run.result.get("plan") or {}).get("steps") or []
    nut = []
    for b in buoc:
        cap = b.get("cap")
        if cap and cap in reg and reg.get(cap).implemented:
            nut.append(chain_mod.Nut(id=b.get("id") or f"n{len(nut) + 1}", cap=cap,
                                     args=_args_cho(cap, intent, grounded),
                                     when=nut[-1].id if nut else None, on_ask="wait"))
    return nut


def _args_cho(cap: str, intent: dict[str, Any], grounded: dict[str, Any],
              run_id: str = "") -> dict[str, Any]:
    """Ghép tham số cho một nút từ slots của ý định và kết quả grounding.

    Chỉ lấy khóa CÓ TRONG input_schema của năng lực: thừa một khóa là E1000 ở Router, và phép
    kiểm deterministic ở bước 2 sẽ bắt nó — nhưng bắt ở đây thì thông điệp nói được vì sao.

    Hai thứ KHÔNG nằm trong slots mà chuỗi vẫn biết chắc, và bỏ sót chúng thì chuỗi dừng ngay ở
    nút đầu để hỏi một câu đã có sẵn câu trả lời:

    * `intent` — chính ý định đang xử lý. `chat_send` gọi thẳng `chat.ground` với `{"intent":
      intent}` (rpc.py), nên đây là cùng một phép nối, chỉ là chuỗi mẫu chưa được hưởng.
    * `run_id` — mã lượt chạy của chính chuỗi này, thứ `chat.report_back` cần để tổng kết.
    """
    reg = get_registry()
    if cap not in reg:
        return {}
    thuoc_tinh = reg.get(cap).spec.input_schema.get("properties") or {}
    cho_phep = set(thuoc_tinh)
    nguon: dict[str, Any] = {"intent": intent}
    if run_id:
        nguon["run_id"] = run_id
    nguon.update({**(grounded or {}), **((intent or {}).get("slots") or {})})
    ra: dict[str, Any] = {}
    for k, v in nguon.items():
        if k not in cho_phep or v is None:
            continue
        # KIỂM KIỂU trước khi gán. Một cái TÊN trùng nhau không có nghĩa là cùng một KIỂU, và
        # `intent` là chỗ hai nghĩa ấy va nhau: ở đây nó là dict ý định của `chat.parse_intent`,
        # còn `code.modify` khai `intent: string` — "sửa cái gì", một câu tiếng Việt.
        #
        # Đo 21/09/2026 trên bài CNC, bước 5: cả chuỗi chết với E5002 "step4: tham số không khớp
        # input_schema của `code.modify` — {'intent': 'arch.design', 'slots': {...}} is not of
        # type 'string'". Người dùng nhận một câu lỗi jsonschema cho một câu họ gõ bằng tiếng
        # Việt, và không có gì họ làm được với nó.
        #
        # Dict rơi vào chỗ đòi string thì rút phần dùng được (`intent["intent"]`) thay vì bỏ
        # hẳn: bỏ hẳn làm nút rơi về "thiếu tham số" và đi hỏi người một câu mà chuỗi đã biết.
        if (kieu := thuoc_tinh[k].get("type")) and not _hop_kieu(v, kieu):
            if kieu == "string" and k == "intent" and isinstance(v, dict) and v.get("intent"):
                ra[k] = str(v["intent"])
            continue
        ra[k] = v
    return ra


# JSON type → kiểu Python. `int` KHÔNG nằm trong `boolean` dù `bool` là con của `int` trong
# Python: một `True` lọt vào chỗ đòi số là thứ jsonschema bắt được còn `isinstance` thì không.
_KIEU_JSON: dict[str, Any] = {
    "string": str, "object": dict, "array": list, "boolean": bool,
    "number": (int, float), "integer": int,
}


def _hop_kieu(v: Any, kieu: Any) -> bool:
    """Giá trị có khớp `type` mà input_schema khai không.

    `type` có thể là một danh sách (`["string", "null"]`) — khớp một cái là đủ. Kiểu lạ thì trả
    `True`: không biết thì đừng chặn, để jsonschema ở `kiem()` nói lời cuối.
    """
    if isinstance(kieu, list):
        return any(_hop_kieu(v, k) for k in kieu)
    if kieu == "null":
        return v is None
    if kieu in ("number", "integer") and isinstance(v, bool):
        return False
    t = _KIEU_JSON.get(kieu)
    return True if t is None else isinstance(v, t)


def _uoc_chi_phi(chuoi: Any) -> float:
    """Ước lượng thô: số nút × chi phí trung bình một lượt gọi mô hình.

    Thô có chủ ý — phép kiểm ngân sách của §4.4 để chặn một chuỗi 200 nút, không để dự báo hóa
    đơn. Con số chính xác chỉ có sau khi chạy, và `model.call.cost_usd` mới là nơi ghi nó.
    """
    return len(chuoi.nodes) * 0.01


def _so_run(root: Path | None) -> int:
    """Số thứ tự của lượt chạy sắp bắt đầu, trong phạm vi một dự án — "Run #7".

    Người dùng cần một cái tên NGẮN để gọi một lượt chạy khi nói chuyện với nhau và với tác tử.
    `r_9f3c1a2b4e5d` thì đúng nhưng không ai đọc to lên được, và hai mã băm cạnh nhau trông
    giống hệt nhau. Đếm từ bảng `run` của chính dự án chứ không giữ một bộ đếm riêng: thêm một
    chỗ giữ trạng thái là thêm một chỗ lệch, và bảng ấy vốn đã là nơi mọi lượt chạy được ghi.
    """
    if root is None:
        return 1
    db = store.store_path(root)
    if not db.exists():
        return 1
    try:
        with store.open_store(db) as c:
            return int(c.execute("SELECT COUNT(*) FROM run").fetchone()[0]) + 1
    except sqlite3.Error:
        return 1


def _ghi_run(root: Path | None, run_id: str, chuoi: Any, state: str,
             intent: dict[str, Any], report: dict[str, Any] | None = None) -> None:
    """Ghi `run.graph` và `run.report` — CHAT-06 bước 3 và 5.

    `graph` ghi TRƯỚC khi chạy để chuỗi tiếp tục được sau khi tắt máy; `report` ghi sau, và đó
    là chỗ bên gọi đọc kết quả (DDD-14 §2 Run).
    """
    if root is None:
        return
    db = store.store_path(root)
    if not db.exists():
        return
    try:
        with store.open_store(db) as c:
            c.execute(
                "INSERT INTO run (id, intent_id, graph, state, report, started_at)"
                " VALUES (?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET graph=excluded.graph,"
                " state=excluded.state, report=COALESCE(excluded.report, run.report)",
                # `intent_id` là KHÓA NGOẠI sang bảng `intent`, không phải tên ý định. Chưa mã
                # nào ghi bảng ấy (`chat.parse_intent` chỉ ghi sự kiện nhật ký), nên để NULL —
                # truyền "kg.build" vào đây làm cả câu chèn hỏng vì ràng buộc khóa ngoại.
                # `intent`/`text` đi CÙNG đồ thị. `chat.resume` cần cả hai để chạy tiếp mà
                # không phải lập kế hoạch lần thứ hai — lập lại có thể ra một chuỗi KHÁC chuỗi
                # người vừa đọc và vừa gật đầu. Giữ `nodes` nguyên chỗ cũ nên `run_dang_chay`
                # không đổi.
                (run_id, None,
                 json.dumps({**chuoi.as_dict(), "intent": intent,
                             "text": str((intent or {}).get("_text") or "")},
                            ensure_ascii=False), state,
                 json.dumps(report, ensure_ascii=False) if report else None,
                 datetime.now(UTC).isoformat()))
            c.commit()
    except sqlite3.OperationalError:
        # CHỈ nuốt lỗi "store cũ chưa có bảng/cột" — đó là trạng thái thật khi user_version thấp.
        # Nuốt cả `sqlite3.Error` thì một lỗi lập trình (sai cột, sai khóa ngoại) trông y hệt
        # "chưa migrate", và nó đã che đúng lỗi khóa ngoại ở trên cho tới khi chạy tay câu SQL.
        pass


def _lap_lai_neu_nguoi_sua(run_id: str, led: Any, router: Any, ctx: Context) -> None:
    """Đọc cờ `plan.replan_needed` của `code.human_save` và gọi `plan.replan` — UXC-31 §7.5.

    Cờ được ĂN: sau khi lập lại thì ghi `plan.replan_done` cùng `seq` của cờ, để vòng lặp sau
    không lập lại mãi một lần sửa. Không ăn cờ thì mỗi nút còn lại của chuỗi đều gọi planner
    một lần — một chuỗi 12 nút thành 12 lượt gọi mô hình cho cùng một lần người bấm ⌘S.

    Hỏng thì ghi chú và chạy tiếp. Lập lại kế hoạch là một cải thiện; không lập được không
    phải lý do để giết một chuỗi đang chạy dở.
    """
    if led is None or router is None:
        return
    try:
        ban_ghi = list(led.records())
    except Exception:  # noqa: BLE001
        return
    da_an = {int((r.get("data") or {}).get("for_seq") or 0) for r in ban_ghi
             if r.get("kind") == "report"
             and (r.get("data") or {}).get("cap") == "plan.replan"}
    co = [r for r in ban_ghi
          if r.get("kind") == "human.file_save"
          and run_id in ((r.get("data") or {}).get("replan_for") or [])
          and int(r.get("seq") or 0) not in da_an]
    if not co:
        return
    cuoi = co[-1]
    d = cuoi.get("data") or {}
    duong = d.get("path") or "một tệp"
    try:
        r = router.invoke(
            "plan.replan",
            {"plan_id": run_id, "reason": "human_change",
             "detail": f"người sửa `{duong}` ({d.get('diff_summary') or 'không rõ thay đổi'}); "
                       "tệp này nằm trong kế hoạch đang chạy"}, ctx)
        tt = r.status
        loi = None
    except Exception as e:  # noqa: BLE001 — xem docstring
        tt, loi = "failed", str(e)[:200]
    led.append("report", {"cap": "plan.replan", "run_id": run_id,
                          "for_seq": int(cuoi.get("seq") or 0), "status": tt,
                          "path": d.get("path"), **({"error": loi} if loi else {})})


def doc_ke_hoach(root: Path, run_id: str) -> dict[str, Any] | None:
    """`{state, intent, graph, text}` của một lượt chạy, hoặc `None` nếu không có.

    Dùng cho `chat.resume` (UXC-31 §2D.6): người bấm "Đúng — làm đi" thì lượt ấy phải chạy tiếp
    CHÍNH đồ thị đã ghi, không dựng lại. Dựng lại là lập kế hoạch lần thứ hai — có thể ra một
    chuỗi khác chuỗi người vừa đọc và vừa gật đầu.
    """
    db = store.store_path(root)
    if not db.exists():
        return None
    try:
        with store.open_store(db) as c:
            row = c.execute("SELECT state, graph, report FROM run WHERE id=?",
                            (run_id,)).fetchone()
    except sqlite3.OperationalError:
        return None
    if not row:
        return None
    try:
        g = json.loads(row[1]) if row[1] else {}
    except (TypeError, ValueError):
        g = {}
    return {"state": row[0], "graph": g, "intent": g.get("intent") or {},
            "text": g.get("text") or ""}


def huy_ke_hoach(root: Path, run_id: str, led: Any) -> None:
    """Huỷ một lượt đang `planned` — người bấm "Sửa ý hiểu".

    HUỶ chứ không để nguyên: một lượt `planned` bị bỏ lại sẽ nằm trong hàng đợi ở lần mở dự án
    sau như một việc đang chờ, và người dùng phải nhớ rằng chính mình đã từ chối nó.
    """
    db = store.store_path(root)
    if db.exists():
        try:
            with store.open_store(db) as c:
                c.execute("UPDATE run SET state='cancelled' WHERE id=? AND state='planned'",
                          (run_id,))
                c.commit()
        except sqlite3.OperationalError:
            pass
    if led is not None:
        led.append("run.cancelled", {"run_id": run_id, "by": "human",
                                     "reason": "người sửa ý hiểu (UXC-31 §2D.6)"})


def run_dang_chay(root: Path) -> list[tuple[str, set[str]]]:
    """`(run_id, tệp kế hoạch chạm tới)` cho mọi lượt chạy còn `running` — UXC-31 §7.5.

    Đọc từ `graph`, KHÔNG từ `report`: một lượt đang chạy chưa có `report` (nó được ghi lúc
    kết thúc), nên hỏi báo cáo ở đây luôn trả rỗng — và rỗng trông y hệt "kế hoạch này không
    chạm tệp nào", tức luật §7.5 sẽ im lặng không bao giờ kích hoạt.

    Tên tệp nằm rải trong `args` của từng nút dưới nhiều khoá (`path`, `file`, `files`), vì mỗi
    năng lực đặt tên tham số theo hợp đồng riêng. Quét mọi khoá ấy thay vì chỉ một: bỏ sót một
    khoá nghĩa là bỏ sót đúng nhóm năng lực dùng nó.
    """
    db = store.store_path(root)
    if not db.exists():
        return []
    try:
        with store.open_store(db) as c:
            rows = c.execute("SELECT id, graph FROM run WHERE state='running'").fetchall()
    except sqlite3.OperationalError:
        return []
    ra: list[tuple[str, set[str]]] = []
    for rid, g in rows:
        tep: set[str] = set()
        try:
            d = json.loads(g) if g else {}
        except (TypeError, ValueError):
            d = {}
        for nut in (d.get("nodes") or d.get("nut") or []):
            args = (nut or {}).get("args") or {}
            for k in ("path", "file", "target"):
                if isinstance(args.get(k), str):
                    tep.add(args[k])
            for x in (args.get("files") or []):
                if isinstance(x, str):
                    tep.add(x)
                elif isinstance(x, dict) and isinstance(x.get("path"), str):
                    tep.add(x["path"])
        ra.append((str(rid), tep))
    return ra


def doc_bao_cao(root: Path, run_id: str) -> dict[str, Any]:
    """Báo cáo của một chuỗi — `run.report`. Dùng bởi test và bởi `chat.report_back`."""
    with store.open_store(store.store_path(root)) as c:
        row = c.execute("SELECT report FROM run WHERE id=?", (run_id,)).fetchone()
    return json.loads(row[0]) if row and row[0] else {}
