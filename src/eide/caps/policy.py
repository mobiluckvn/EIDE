"""Namespace policy.* — CDS-12.5; APD-08 §2, §5; POL-17."""
from __future__ import annotations

import secrets
from collections import defaultdict
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.policy import LEVELS, PolicyGate
from eide_core.registry import capability
from eide_core.router import Context
from eide_core.undo import UndoService

EIDE_DIR = ".eide"
_STATE: dict[str, Any] = {"stopped": False}


@capability("policy.decide")
def decide(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-01 — CDS-12.5; APD-08 §4.1 bốn tầng; POL-17 §1–2 rules.yaml; DDD-14 decision_log.

    Bọc PolicyGate thành năng lực để chính sách gọi được qua Router, MCP và JSON-RPC — không chỉ
    từ bên trong tiến trình. Không quyết định lại điều gì: cùng một `PolicyGate.decide`, cùng
    thứ tự tầng, nên hai đường gọi không thể cho hai câu trả lời khác nhau.

    `action` = {cap, gate, risk, features}; `ctx` = {autonomy, board, tier, actor}. Trả DecisionLog
    (DDD-14) rút gọn: quyết định, quy tắc đã thắng, lý do, cổng.
    """
    action = params["action"]
    c = params.get("ctx") or {}
    gate = ctx.extra.get("gate") or PolicyGate()
    features = dict(action.get("features") or {})
    if action.get("cap"):
        features.setdefault("cap", {"id": action["cap"], "risk": action.get("risk", "R1")})
    d = gate.decide(
        action.get("gate", "*"), features,
        risk=action.get("risk", "R1"),
        autonomy=c.get("autonomy") or ctx.autonomy,
        board=c.get("board") or ctx.board,
        tier=c.get("tier", "T2"),
        actor=c.get("actor") or ctx.actor,
    )
    return {"decision": {"decision": d.decision, "rule": d.rule_id, "reason": d.reason,
                         "gate": d.gate, "autonomy": gate._effective_level(
                             c.get("autonomy") or ctx.autonomy, c.get("board") or ctx.board)}}


@capability("policy.undo_window")
def undo_window(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-03 — CDS-12.5; POL-17 §5 (loại undo × cửa sổ), §6; API-15 §5 undo.*.

    Một bước: "UndoService.list; hết hạn → expire". Danh sách này là thứ ReviewQueue hiển thị ở
    cột "đã làm — hoàn tác được" (UXD-13 U2), nên nó phải nói đúng: mục quá hạn bị ghi
    `undo.expire` rồi mới loại ra, không biến mất lặng lẽ.
    """
    led = ctx.extra.get("ledger")
    if led is None:
        return {"items": []}
    gate = ctx.extra.get("gate")
    return {"items": UndoService(led, getattr(gate, "config", None)).list()}


# POL-17 §6: "queue (luôn) → chat (ASK sau timeout/2) → notify (R3/R4 hoặc ngân sách < warn_pct
# hoặc board lệch hộ chiếu)". Bậc thang TÍCH LŨY: một việc gấp hơn không được bỏ qua kênh nhẹ hơn.
BAC_THANG = ["queue", "chat", "notify"]
LY_DO_MUC = {
    "ask_timeout": "chat",       # ASK quá nửa thời gian chờ
    "budget_low": "notify",      # ngân sách < budget_warn_pct
    "board_mismatch": "notify",  # ID chip lệch hộ chiếu
    "risk_r3": "notify",
    "risk_r4": "notify",
}


@capability("policy.escalate")
def escalate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-04 — CDS-12.5; POL-17 §6 (kênh theo mức); STP-05 TC-54; API-15 §5.

    Lý do không có trong bảng §6 vẫn lên `queue`: im lặng là kết cục tệ nhất của một cơ chế leo
    thang. `escalation.channels` trong autonomy.yaml có thể tắt bớt kênh, nhưng không tắt được
    hàng đợi vì đó là nơi người vào xem việc đang chờ.
    """
    muc = params.get("level") or LY_DO_MUC.get(params["reason"], "queue")
    gate = ctx.extra.get("gate")
    cho_phep = ((getattr(gate, "config", None) or {}).get("escalation") or {}).get("channels") or BAC_THANG
    kenh = [k for k in BAC_THANG[: BAC_THANG.index(muc) + 1] if k in cho_phep]
    led = ctx.extra.get("ledger")
    if led is not None:
        # API-15 §7 v1.3 `policy.escalate {ref, reason, channels[], level}`. Trước v1.3 phải
        # mượn kiểu `question` với cờ `escalated`, và khi đó chỉ số "bao nhiêu việc phải leo
        # thang" không tách được khỏi câu hỏi thường. Xem DEVIATIONS DEV-013.
        led.append("policy.escalate", {"ref": params["ref"], "reason": params["reason"],
                                       "channels": kenh, "level": muc})
    return {"notified": kenh}


@capability("policy.emergency_stop")
def emergency_stop(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-05 — CDS-12.5; APD-08 §5: session.stopped=true, về A0, hủy job EXECUTING lớp ≥ R3 (< 1 s)."""
    _STATE["stopped"] = True
    gate = ctx.extra.get("gate")
    if gate is not None:
        gate.stop()
    cancelled = list(ctx.extra.get("cancel_running", lambda: [])())

    # VÀO SỔ CÁI. API-15 §5 khai kiểu `stop`, và tới 12/09/2026 không chỗ nào phát nó — nên
    # thao tác AN TOÀN QUAN TRỌNG NHẤT của cả sản phẩm là thao tác duy nhất không để lại dấu
    # vết. Ai đó bấm dừng khẩn cấp lúc 2 giờ sáng, ba việc R3 bị huỷ giữa chừng, và sáng hôm sau
    # không có cách nào biết chuyện đã xảy ra: `_STATE` là bộ nhớ tiến trình, `gate.stop()`
    # không ghi gì, và những việc bị huỷ thì chỉ còn một `cap.run.finish` trạng thái `cancelled`
    # không nói vì sao.
    #
    # Ghi SAU khi đã dừng, không phải trước: dừng là việc gấp, và một lần ghi đĩa hỏng không
    # được phép chắn nó. Sổ cái thiếu một dòng thì tệ; tác tử không dừng được thì tệ hơn.
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("stop", {"cancelled": cancelled, "n_cancelled": len(cancelled),
                            "by": ctx.actor or "human"},
                   actor=ctx.actor or "human")
    return {"stopped": True, "cancelled": cancelled}


@capability("policy.set_autonomy")
def set_autonomy(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-07 — CDS-12.5; APD-08 §2: nới lỏng là R4 → ASK trừ by=human; siết → tức thì; ghi autonomy.yaml; undo restore_config."""
    level, by = params["level"], params["by"]
    if level not in LEVELS:
        raise EideError("E1000", f"Mức không hợp lệ: {level}")
    if not ctx.project_dir:
        raise EideError("E2000", "Chưa mở dự án")
    f = Path(ctx.project_dir) / ".eide" / "autonomy.yaml"
    cfg = yaml.safe_load(f.read_text(encoding="utf-8")) if f.exists() else {"autonomy": "A3"}
    current = cfg.get("autonomy", "A3")
    if LEVELS.index(level) > LEVELS.index(current) and by != "human":
        raise EideError("E3000", f"Nới lỏng {current}→{level} cần người xác nhận", gate="*")
    if params.get("board"):
        cfg.setdefault("boards", {}).setdefault(params["board"], {})["autonomy"] = level
    else:
        cfg["autonomy"] = level
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")

    # VÀO SỔ CÁI. API-15 §5 khai `autonomy.change {from, to, by, reason}`, và tới 12/09/2026
    # không chỗ nào phát nó: mức tự chủ đổi bằng một lần ghi tệp YAML, không để lại dấu vết nào
    # trong chuỗi băm.
    #
    # Đó là lỗ hổng cùng họ với `gate.decision` (lỗi im lặng số 12) và nghiêm trọng vì cùng lý
    # do: `autonomy.yaml` KHÔNG nằm trong `content_digest` của niêm phong. Nâng A2 → A4 rồi hạ
    # lại là một thao tác không cơ chế nào ghi lại — trong khi đó chính là thao tác cho phép
    # tác tử tự nạp firmware. Một dòng trong sổ cái là thứ duy nhất làm nó truy được.
    if (led := ctx.extra.get("ledger")) is not None:
        # Không có trường `reason`: POLICY-01 `input_schema` khai `additionalProperties: false`
        # với đúng ba khoá `level`/`board`/`by`, nên đọc thêm một khoá là viết một nhánh mà
        # Router chặn bằng E1000 trước khi tới đây.
        led.append("autonomy.change",
                   {"from": current, "to": level, "by": by,
                    **({"board": params["board"]} if params.get("board") else {})},
                   actor=by if by == "human" else "agent")
    return {"effective": level}


@capability("policy.permit")
def permit(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-02 — CDS-12.5; DDD-14 §2 Permission. tc: TC-03; ask "Luôn (R4)".

    Quyền theo PHIÊN cho một thao tác R3/R4: người cấp một lần, tác tử dùng trong phiên ấy mà
    không phải hỏi lại từng lần. Ba ràng buộc, mỗi cái chặn một cách hỏng khác nhau:

    · `by=human` bắt buộc (E3000). Một tác tử tự cấp quyền cho chính nó thì cả cơ chế thành
      trang trí — cùng lý do `eide policy sign` là lệnh chứ không phải năng lực.
    · Hết hạn khi đóng phiên, kể cả khi `ttl_s` còn dài. Bước 1 của hợp đồng ghi "hết hạn khi
      đóng phiên", và đó là điều làm cho "quyền theo phiên" đúng nghĩa: mở lại máy ngày hôm sau
      thì mọi quyền phải xin lại, vì hoàn cảnh đã khác.
    · Ghi vào store của dự án, không vào bộ nhớ tiến trình: quyền phải đọc lại được sau khi
      daemon khởi động lại, và phải kiểm được bằng mắt.
    """
    if params["by"] != "human" and ctx.actor != "human":
        raise EideError("E3000", "Cấp quyền là quyết định của người (POLICY-02: chỉ by=human)",
                        rule="POLICY-02", gate="*")
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "policy.permit cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    ttl = int(params.get("ttl_s") or 0)
    now = datetime.now(UTC)
    het = (now + timedelta(seconds=ttl)).isoformat() if ttl > 0 else None
    pid = "perm_" + secrets.token_hex(6)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO permission (id, session_id, op, target, granted_by, granted_at,"
                  " expires_at) VALUES (?,?,?,?,?,?,?)",
                  (pid, ctx.session_id, params["op"], params.get("target"), params["by"],
                   now.isoformat(), het))
        c.commit()
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("gate.human", {"gate_id": "*", "decision": "APPROVE", "by": params["by"],
                                  "note": f"policy.permit {params['op']}"
                                          + (f" trên {params['target']}" if params.get("target") else "")
                                          + (f", ttl {ttl}s" if ttl else ", tới hết phiên")})
    return {"permission_id": pid, "expires_at": het}


def quyen_con_hieu_luc(root: Path, session_id: str, op: str, target: str | None = None) -> bool:
    """Phiên này đã được cấp quyền cho `op` chưa? — dùng bởi PolicyGate ở Sprint sau.

    Lọc theo session_id ngay trong truy vấn: một quyền của phiên trước còn hạn theo đồng hồ vẫn
    KHÔNG được dùng cho phiên này (POLICY-02 bước 1 "hết hạn khi đóng phiên").
    """
    db = store.store_path(root)
    if not db.exists():
        return False
    now = datetime.now(UTC).isoformat()
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT target, expires_at FROM permission WHERE session_id=? AND op=?",
            (session_id, op)).fetchall()
    return any((t is None or t == target) and (e is None or e > now) for t, e in rows)


# POL-17 §7: "Đề xuất chỉ khi n ≥ 20 và tỷ lệ ≥ 0,9 (nới) hoặc ≥ 0,2 (siết)".
N_TOI_THIEU = 20
TY_LE_NOI = 0.9
TY_LE_SIET = 0.2
NGAY_MAC_DINH = 30

# Cổng → ngưỡng mà đề xuất sẽ chạm tới. Ánh xạ này CẦN nói ra: một đề xuất "nới G-FACT" mà không
# nêu chỉnh con số nào thì người duyệt không có gì để duyệt.
NGUONG_THEO_CONG = {
    "G-FACT": "fact_silver_auto",
    "G-SRC": "source_match_min",
    "G-OPS": "flash_per_hour",
    "G3": "bench_bc_min",
    "*": "fail_retries",
}


@capability("policy.learn_thresholds")
def learn_thresholds(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-06 — CDS-12.5; POL-17 §7. tc: TC-55; ask "Luôn".

    Bước duy nhất của hợp đồng kết thúc bằng ba chữ quan trọng nhất: **"không áp dụng"**. Năng
    lực này chỉ ĐỀ XUẤT; đổi ngưỡng là việc của `policy.set_autonomy` sau khi người xác nhận, và
    một hệ thống tự nới ngưỡng cho chính nó dựa trên thống kê hành vi của chính nó là vòng lặp
    mà cả APD-08 dựng lên để tránh.

    Hai tín hiệu, ngược chiều nhau (POL-17 §7):
      · người APPROVE khi máy ASK  → máy đang hỏi quá nhiều  → gợi ý NỚI (cần tỷ lệ ≥ 0,9)
      · người UNDO khi máy APPROVE → máy đang tự làm quá tay → gợi ý SIẾT (cần tỷ lệ ≥ 0,2)

    Ngưỡng cho hai chiều KHÁC NHAU rất xa, và cố ý: nới là bỏ bớt một lần hỏi, chỉ nên làm khi
    gần như chắc chắn; siết là thêm một lần hỏi, và một phần năm số lần phải hoàn tác đã đủ để
    nói rằng mức tự chủ hiện tại đang sai.
    """
    ngay = int(params.get("days") or NGAY_MAC_DINH)
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not store.store_path(root).exists():
        raise EideError("E2000", "policy.learn_thresholds cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    moc = (datetime.now(UTC) - timedelta(days=ngay)).isoformat()
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute(
            "SELECT gate, decision, human_answer, undone_at FROM decision_log WHERE at >= ?",
            (moc,)).fetchall()

    thong_ke: dict[str, dict[str, int]] = defaultdict(lambda: {"ask": 0, "ask_approve": 0,
                                                               "approve": 0, "approve_undo": 0})
    for gate, quyet, tra_loi, hoan_tac in rows:
        t = thong_ke[gate or "*"]
        if quyet == "ASK":
            t["ask"] += 1
            t["ask_approve"] += int((tra_loi or "").upper() == "APPROVE")
        elif quyet == "APPROVE":
            t["approve"] += 1
            t["approve_undo"] += int(bool(hoan_tac))

    nguong_hien = (ctx.extra.get("gate").config if ctx.extra.get("gate") else {}).get("thresholds", {})
    de_xuat = []
    for gate, t in sorted(thong_ke.items()):
        ten = NGUONG_THEO_CONG.get(gate)
        if ten is None:
            continue
        hien = nguong_hien.get(ten)
        if t["ask"] >= N_TOI_THIEU and t["ask_approve"] / t["ask"] >= TY_LE_NOI:
            de_xuat.append(_de_xuat(gate, ten, hien, "noi", t["ask_approve"], t["ask"]))
        if t["approve"] >= N_TOI_THIEU and t["approve_undo"] / t["approve"] >= TY_LE_SIET:
            de_xuat.append(_de_xuat(gate, ten, hien, "siet", t["approve_undo"], t["approve"]))
    return {"proposals": de_xuat}


def _de_xuat(gate: str, ten: str, hien: Any, huong: str, k: int, n: int) -> dict[str, Any]:
    """Một bản ghi {threshold, from, to, evidence_n, rate} — POL-17 §7.

    `to` là `None` khi ngưỡng không phải số: đề xuất vẫn có ích (nó nói cổng nào đang lệch và
    bằng chứng bao nhiêu), nhưng đoán bừa một con số mới thì người duyệt sẽ tin nó là kết quả
    tính toán. Thà để trống và nói rõ.
    """
    buoc = 0.05 if isinstance(hien, float) else (1 if isinstance(hien, int) else None)
    moi = None
    if buoc is not None and hien is not None:
        moi = round(hien - buoc, 4) if huong == "noi" else round(hien + buoc, 4)
        if isinstance(hien, int):
            moi = int(moi)
    return {"gate": gate, "threshold": ten, "from": hien, "to": moi,
            "huong": huong, "evidence_n": n, "rate": round(k / n, 3),
            "ly_do": (f"người APPROVE {k}/{n} lần máy hỏi" if huong == "noi"
                      else f"người hoàn tác {k}/{n} lần máy tự làm"),
            "ap_dung": False}


@capability("policy.rules")
def rules(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-08 — CDS-12.5; POL-17 §1–2; UXC-31 §8 S25.

    Trả bảng quy tắc mà PolicyGate ĐANG NẠP, không phải nội dung tệp `rules.yaml`.

    Hai thứ ấy khác nhau ở đúng lúc quan trọng nhất: khi niêm danh sách trắng không khớp,
    `whitelist.kiem` bỏ `trusted_sources`/`trusted_packages`/`allowed_licenses` khỏi biểu thức,
    nên các quy tắc dựa vào chúng không khớp nữa và lời gọi rơi xuống quy tắc bắt hết. Một màn
    đọc thẳng tệp sẽ hiện một chính sách không ai đang chạy — và người dùng ngồi đối chiếu với
    hành vi thật rồi kết luận hệ thống hỏng, trong khi thứ hỏng là chữ ký.
    """
    gate = ctx.extra.get("gate") or PolicyGate()
    # BỎ mọi khoá riêng tư (`_code`: biểu thức `when` đã biên dịch).
    #
    # Một đối tượng code không tuần tự hoá được sang JSON, và daemon phát hiện điều đó ở tầng
    # ghi ống — tức là SAU khi đã trả lời xong: ống vỡ, và MỌI lời gọi sau đó hỏng theo. Đo
    # 17/09/2026 bằng bài quét toàn bộ năng lực: `policy.rules` chết, rồi chín năng lực tiếp
    # theo cùng chết với thông điệp "daemon đóng ống" — một lỗi ở một năng lực đọc thuần tuý
    # kéo sập cả phiên làm việc.
    #
    # `output_schema` KHÔNG bắt được: nó khai `arr<obj>` và một dict có `_code` vẫn là một dict.
    # Khớp schema không có nghĩa là gửi được.
    sach = [{k: v for k, v in r.items() if not k.startswith("_")}
            for r in getattr(gate, "rules", [])]
    return {
        "rules": sach,
        "signed": bool(getattr(gate, "danh_sach_da_ky", False)),
        "reason": str(getattr(gate, "ly_do_chua_ky", "") or ""),
        # v1.3 — `boards` (DEV-135). Đọc từ CÙNG `gate.config` mà `G-OPS-01` dùng để quyết
        # định, không mở lại `autonomy.yaml`: hai đường đọc là hai chỗ có thể lệch, và lệch ở
        # đây nghĩa là màn S6 hiện một trạng thái lab khác trạng thái cổng đang thi hành.
        "boards": _boards(gate),
    }


def _boards(gate: Any) -> dict[str, Any]:
    """`{<board_id>: {lab, has_actuator, reason}}` từ cấu hình đang có hiệu lực.

    `board.mark_lab` ghi khoá này vào `autonomy.yaml`, và trước v1.3 **không năng lực nào trong
    244 cái đọc ra được nó**: S6 có đường GHI đầy đủ (hai ô xác nhận → cổng → niêm ký lại) mà
    không có đường ĐỌC, nên nó phải nói "trạng thái hiện tại chưa đọc lại được".

    Chuẩn hoá về đúng ba trường, kể cả khi tệp ghi thiếu: một board khai `{lab: true}` mà thiếu
    `has_actuator` không được hiện thành "không có cơ cấu chấp hành" — đó là hai câu khác nhau,
    và câu thứ hai nới lỏng một cổng an toàn.
    """
    d = (getattr(gate, "config", None) or {}).get("boards") or {}
    if not isinstance(d, dict):
        return {}
    ra: dict[str, Any] = {}
    for ma, v in d.items():
        if not isinstance(v, dict):
            continue
        ra[str(ma)] = {
            "lab": v.get("lab"),
            "has_actuator": v.get("has_actuator"),
            "reason": str(v.get("reason") or ""),
        }
    return ra
