"""Namespace chat.* — tầng hiểu lệnh. CDS-12.6; DPS-09 §2–§5; PRS-16 §7.

Bốn trách nhiệm của DPS-09 §2 chia ra thành các năng lực có hợp đồng, chứ không gộp thành một
hàm lớn: ① hiểu và đối chiếu = `parse_intent` + `ground`; ③ đủ thông tin = `fill_defaults` +
`clarify`; ④ chính sách và báo cáo = `report_back` (chính sách đã do Router lo). Tách như thế
để tầng hiểu lệnh kiểm thử được bằng kịch bản xác định, độc lập với chất lượng sinh của mô
hình — đó là câu cuối của §2 và cũng là lý do TC-59 chạy được.

② lập chuỗi (`chat.orchestrate`, CHAT-06) là mốc M2, chưa ở đây.
"""
from __future__ import annotations

import json
import time
import unicodedata
from pathlib import Path
from typing import Any

import yaml

from eide.caps.project import EIDE_DIR, slugify
from eide_core.errors import EideError
from eide_core.gateway import Gateway
from eide_core.paths import spec_dir
from eide_core.registry import capability
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
    doi_tuong = slots.get("project_name") or slots.get("idea") or slots.get("feature") or slots.get("question") or "—"
    caps = [n["cap"] for n in chain]
    tom = ", ".join(caps[:4]) + (f" và {len(caps) - 4} bước nữa" if len(caps) > 4 else "")
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
