"""Namespace plan.* — CDS-12.1 (tập Kỹ nghệ); PRS-16 §4 (vai trò planner); POL-17 G1.

Bảy năng lực, chia làm hai loại và ranh giới giữa chúng là điểm chính của cả nhóm:

**Deterministic** — `order`, `estimate`, `sufficiency`. Không một lời gọi mô hình nào. Sắp thứ tự
phụ thuộc là thuật toán; ước lượng chi phí là số học trên nhật ký; kiểm đủ tri thức là tra store.
Hỏi mô hình những việc ấy là mời ảo giác vào chỗ có câu trả lời đúng.

**Có sinh** — `define_feature`, `decompose`, `create`, `replan`. Mô hình đề xuất, rồi phần
deterministic kiểm lại: fact được trích dẫn phải TỒN TẠI, tài nguyên phần cứng phải nằm trong
HwMap, số bước phải trong ngưỡng. DPS-09 §1 vạch đúng ranh giới ấy, và PRS-16 §4 nói thẳng điều
planner KHÔNG ĐƯỢC làm — "giả định tri thức chắc có".
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.paths import spec_dir
from eide_core.registry import capability
from eide_core.router import Context

# PRS-16 §4: "chia bước quá nhỏ (< 3) hoặc quá lớn (> 12 bước)".
BUOC_TOI_THIEU = 3
BUOC_TOI_DA = 12

# PLAN-04: "clock → GPIO → bus → cảm biến → điều khiển → app". Bậc thấp hơn chạy trước; hai
# module cùng bậc thì giữ thứ tự đầu vào.
BAC_MODULE = ["clock", "power", "gpio", "bus", "i2c", "spi", "uart", "sensor", "actuator",
              "control", "service", "app"]

# PLAN-05: mặc định khi chưa có lịch sử. Con số thô — mục đích là chặn một kế hoạch 200 bước,
# không phải dự báo hóa đơn (xem `estimate`).
MAC_DINH_BUOC = {"tokens": 4000, "cost_usd": 0.02, "tool_rounds": 2, "minutes": 3}


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm plan.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


# ---------------------------------------------------------------- deterministic


@capability("plan.order")
def order(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PLAN-04 — CDS-12.1. tc: "Thứ tự đúng phụ thuộc".

    Sắp tô-pô theo `depends` của module; module không khai phụ thuộc thì xếp theo BẬC phần cứng
    (clock → GPIO → bus → cảm biến → điều khiển → app) — thứ tự ấy không phải quy ước mà là ràng
    buộc vật lý: cấu hình I2C trước khi bật clock cho nó thì thanh ghi ghi vào hư không.

    Chu trình KHÔNG ném lỗi mà trả về trong `cycles`: hợp đồng khai cả hai trường, và một đồ thị
    phụ thuộc vòng là thứ người cần NHÌN THẤY để gỡ, không phải một ngoại lệ chặn cả lời gọi.
    """
    ds = list(params["features"])
    phu_thuoc = _doc_phu_thuoc(_root(ctx), ds)

    xong: list[str] = []
    con_lai = list(ds)
    while con_lai:
        san = [m for m in con_lai if all(d in xong or d not in ds for d in phu_thuoc.get(m, []))]
        if not san:
            break
        san.sort(key=lambda m: (_bac(m), ds.index(m)))
        for m in san:
            xong.append(m)
            con_lai.remove(m)
    return {"order": xong, "cycles": _chu_trinh(con_lai, phu_thuoc) if con_lai else []}


def _bac(ten: str) -> int:
    t = ten.lower()
    for i, b in enumerate(BAC_MODULE):
        if b in t:
            return i
    return len(BAC_MODULE)


def _doc_phu_thuoc(root: Path, ds: list[str]) -> dict[str, list[str]]:
    """`module.depends` — bảng của migration 0004 (mốc M2).

    Chưa có bảng thì trả rỗng và việc sắp xếp lùi về BẬC phần cứng. Nói ra ở đây thay vì bọc
    try/except câm: thiếu `depends` nghĩa là thứ tự dựa trên tên module, và đó là một mức độ tin
    cậy khác — người đọc kết quả nên biết.
    """
    db = store.store_path(root)
    if not db.exists():
        return {}
    with store.open_store(db) as c:
        if not c.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='module'").fetchone():
            return {}
        rows = c.execute("SELECT id, depends FROM module").fetchall()
    ra: dict[str, list[str]] = {}
    for mid, dep in rows:
        if mid in ds and dep:
            try:
                ra[mid] = [str(x) for x in json.loads(dep)]
            except json.JSONDecodeError:
                pass
    return ra


def _chu_trinh(con_lai: list[str], phu_thuoc: dict[str, list[str]]) -> list[list[str]]:
    """Các vòng còn lại sau khi sắp — trả ĐƯỜNG ĐI để người gỡ được, không chỉ báo có vòng."""
    ra: list[list[str]] = []
    for bat_dau in con_lai:
        tham, cur = [], bat_dau
        while cur in phu_thuoc and phu_thuoc[cur]:
            if cur in tham:
                vong = [*tham[tham.index(cur):], cur]
                if sorted(set(vong)) not in [sorted(set(x)) for x in ra]:
                    ra.append(vong)
                break
            tham.append(cur)
            cur = phu_thuoc[cur][0]
    return ra


@capability("plan.estimate")
def estimate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PLAN-05 — CDS-12.1; POL-17 `plan_max_cost_usd`. tc: "So với ngân sách ngày".

    Ước lượng từ LỊCH SỬ trước, mặc định sau — bước 1 của hợp đồng. Lịch sử ở đây là các sự kiện
    `model.call` trong nhật ký: chúng mang `cost_usd` thật của những lượt đã chạy, nên một dự án
    chạy nhiều rồi sẽ ước đúng dần. Không có lịch sử thì dùng số mặc định và NÓI RA nguồn, để
    người đọc biết con số này chắc đến đâu.
    """
    plan = params["plan"] or {}
    so_buoc = max(1, len(plan.get("steps") or []))
    tu_lich_su = _trung_binh_lich_su(ctx)
    don_vi = tu_lich_su or MAC_DINH_BUOC
    uoc = {k: round(v * so_buoc, 4) if isinstance(v, float) else v * so_buoc
           for k, v in don_vi.items()}
    uoc["nguon"] = "lịch sử ledger" if tu_lich_su else "mặc định theo bước"
    uoc["steps"] = so_buoc

    gate = ctx.extra.get("gate")
    nguong = ((getattr(gate, "config", None) or {}).get("thresholds") or {})
    tran = float(nguong.get("plan_max_cost_usd") or 0) or None
    return {"estimate": uoc,
            "within_budget": tran is None or uoc["cost_usd"] <= tran}


def _trung_binh_lich_su(ctx: Context) -> dict[str, Any] | None:
    led = ctx.extra.get("ledger")
    if led is None:
        return None
    goi = [x["data"] for x in led.records() if x["kind"] == "model.call"]
    if len(goi) < 3:        # dưới ba lượt thì "trung bình" chỉ là một con số ngẫu nhiên
        return None
    n = len(goi)
    tk = sum(int(g.get("tokens_in", 0)) + int(g.get("tokens_out", 0)) for g in goi) / n
    cp = sum(float(g.get("cost_usd", 0) or 0) for g in goi) / n
    return {"tokens": int(tk), "cost_usd": round(cp, 6),
            "tool_rounds": MAC_DINH_BUOC["tool_rounds"], "minutes": MAC_DINH_BUOC["minutes"]}


@capability("plan.sufficiency")
def sufficiency(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PLAN-07 — CDS-12.1 (mốc M1). tc: "Thiếu timing → sufficient=false".

    Ba loại thiếu, và tách chúng ra là điểm chính: thiếu TRI THỨC (fact), thiếu CÔNG CỤ
    (toolchain), thiếu KỸ NĂNG (skill/ISA pack) dẫn tới ba hành động khác nhau — đi tìm tài liệu,
    cài đặt, hay xin người. Gộp thành một cờ `sufficient=false` thì tác tử biết mình thiếu mà
    không biết thiếu gì, và bước tiếp theo chỉ còn cách hỏi người.
    """
    root = _root(ctx)
    task = params["task_ref"]
    thieu: list[dict[str, Any]] = []

    # (a) tri thức: vị từ mà một tác vụ phần cứng thường cần nhưng store chưa có fact hiện hành.
    can = _vi_tu_can(task)
    db = store.store_path(root)
    if can and db.exists():
        with store.open_store(db) as c:
            co = {r[0] for r in c.execute(
                "SELECT DISTINCT predicate FROM fact WHERE status IN ('reviewed','verified')"
                " OR tier='gold'").fetchall()}
        for v in sorted(can - co):
            thieu.append({"loai": "tri_thuc", "predicate": v,
                          "hanh_dong": "search.missing hoặc kg.request"})

    # (b) công cụ: ISA của dự án cần toolchain nào (TGT-19), máy có chưa.
    for t in _cong_cu_can(root):
        thieu.append({"loai": "cong_cu", "ten": t, "hanh_dong": "env.install"})

    return {"sufficient": not thieu, "missing": thieu}


def _vi_tu_can(task: str) -> set[str]:
    """Vị từ cần theo loại tác vụ — bảng deterministic, không hỏi mô hình.

    Bảng nhỏ và cố ý nhỏ: nó chỉ cần bắt được những trường hợp mà thiếu tri thức dẫn tới mã sai
    lặng lẽ. `timing` cho một bus là ví dụ trong tc của hợp đồng — cấu hình I2C mà không biết
    thời gian setup/hold thì mã vẫn biên dịch, vẫn chạy, và chỉ sai khi gặp thiết bị chậm.
    """
    t = task.lower()
    ra: set[str] = set()
    if any(k in t for k in ("i2c", "spi", "uart", "bus")):
        ra |= {"timing", "pin_function"}
    if any(k in t for k in ("adc", "dac", "analog", "điện áp")):
        ra |= {"voltage_range"}
    if any(k in t for k in ("ngắt", "irq", "interrupt")):
        ra |= {"irq"}
    if any(k in t for k in ("thanh ghi", "register", "reg")):
        ra |= {"base_address", "offset"}
    return ra


def _cong_cu_can(root: Path) -> list[str]:
    """Công cụ bắt buộc còn thiếu trên máy — `eide_core.tools` là nguồn duy nhất (PLATFORM.md)."""
    from eide_core import tools

    return [ten for ten, bat_buoc in tools.COMMON_TOOLS if bat_buoc and not tools.which(ten)]


# ---------------------------------------------------------------- có sinh


@capability("plan.create", features=["steps", "all_cited", "new_resources", "touches_forbidden",
                                     "est_cost_usd", "missing", "arch_change", "needs_review"])
def create(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PLAN-03 — CDS-12.1; PRS-16 §4; POL-17 G1. tc: S18…S22; ask "Đổi kiến trúc; tài nguyên mới".

    Bốn bước của hợp đồng, và bước thứ ba là chỗ cả năng lực này có ích:

    1. `memory.compose(planner)` — ngữ cảnh có ngân sách, không phải một chuỗi ghép tay.
    2. Mô hình sinh Plan theo schema `{steps[], citations[], missing[], risks[], estimate}`.
    3. **Kiểm deterministic**: mọi `citations` phải là fact CÓ THẬT trong store; số bước trong
       khoảng 3–12 của PRS-16 §4. Đây là chỗ bắt đúng điều mà §4 cấm planner làm — "giả định tri
       thức chắc có". Một kế hoạch trích dẫn `f_khong_co_that` trông y hệt một kế hoạch đúng.
    4. `plan.sufficiency`, rồi `policy.decide(G1)` với bảy đặc trưng mà G1-01 hỏi.

    Trả cả `decision` để bên gọi biết kế hoạch đã được duyệt hay đang chờ — G1-02/03 hỏi người
    khi thiếu tri thức hoặc đổi kiến trúc, và đó là hai lần hỏi đáng giá nhất trong cả quy trình.
    """
    from eide.caps.memory import compose

    feature = params["feature"]
    root = _root(ctx)
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    bundle = compose({"role": "planner", "task_ref": feature}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    resp = gw.run("planner", f"Lập kế hoạch cho tính năng: {feature}", _SCHEMA_PLAN,
                  system_extra=ngu_canh)
    plan = dict(resp.data)

    loi = _kiem_plan(plan, root)
    if loi:
        raise EideError("E5002", "Kế hoạch không qua được phép kiểm deterministic (PRS-16 §4): "
                        + "; ".join(loi), loi=loi)

    du = sufficiency({"task_ref": feature}, ctx)
    plan.setdefault("missing", [])
    plan["missing"] += [m for m in du["missing"] if m not in plan["missing"]]

    dac_trung = _dac_trung_G1(plan, ctx)
    gate = ctx.extra.get("gate")
    d = gate.decide("G1", dac_trung, risk="R1", autonomy=ctx.autonomy,
                    tier="T1*", actor=ctx.actor) if gate else None
    return {"plan": plan,
            "decision": {"decision": d.decision, "rule": d.rule_id, "reason": d.reason,
                         "gate": d.gate} if d else {}}


def schema_vai_tro(ten: str) -> dict[str, Any]:
    """Schema đầu ra của một vai trò, đọc từ PRS-16 §4.

    `docs/spec/prompts/out_schemas.json` do `scripts/gen_spec_tu_nguon.js` rút ra từ khối §4 của
    `prs.js`. Đọc thay vì chép tay là điều kiện để schema không trôi — bản chép trước của Plan
    thiếu hẳn `touches`, và thiếu một trường thì hai quy tắc cổng thành quy tắc chết mà không ai
    thấy. Cùng khuôn với PRED_W (DEV-043), màn hình UI (DEV-046), bảng thuật ngữ CON-28.
    """
    d = json.loads((spec_dir() / "prompts" / "out_schemas.json").read_text(encoding="utf-8"))
    if ten not in d:
        raise EideError("E2000", f"PRS-16 §4 không có schema `{ten}` (có: {sorted(d)})")
    return copy.deepcopy(d[ten])


def _schema_plan() -> dict[str, Any]:
    """Plan theo PRS-16 §4, đổi tên hai trường của mỗi bước.

    `n` → `id` và `by` → `cap`, và đây là chỗ DUY NHẤT áp phép đổi tên ấy. Lý do giữ tên của mã
    chứ không theo tài liệu: `cap` là một mã năng lực có thật, đối chiếu được với registry, còn
    `by` của tài liệu là chuỗi tự do; `id` là chuỗi nên đặt được `s1`/`step-2` mà `code.*` tham
    chiếu qua `step_ref`, còn `n` là số nguyên. Ghi lại ở DEV-061 để tài liệu theo sau.

    Mọi trường khác — kể cả `touches` — đi thẳng từ tài liệu, không chép.
    """
    s = schema_vai_tro("Plan")
    b = s["properties"]["steps"]["items"]
    b["properties"]["id"] = {"type": "string"}
    b["properties"]["cap"] = b["properties"].pop("by", {"type": "string"})
    b["properties"].pop("n", None)
    b["required"] = ["id" if x == "n" else "cap" if x == "by" else x for x in b.get("required", [])]
    # `citations`/`missing` ở mức kế hoạch: tài liệu đòi bắt buộc, nhưng `plan.create` bổ sung
    # `missing` từ `plan.sufficiency` SAU khi mô hình trả lời, nên ép mô hình phải có sẵn là ép
    # nó đoán. Giữ `steps` là trường bắt buộc duy nhất; `_kiem_plan` mới là chỗ kiểm nội dung.
    s["required"] = ["steps"]
    return s


_SCHEMA_PLAN = _schema_plan()


def _kiem_plan(plan: dict[str, Any], root: Path) -> list[str]:
    """Phép kiểm deterministic của bước 3. Gom hết lỗi rồi trả — như `chain.kiem`."""
    loi: list[str] = []
    buoc = plan.get("steps") or []
    if not BUOC_TOI_THIEU <= len(buoc) <= BUOC_TOI_DA:
        loi.append(f"{len(buoc)} bước, ngoài khoảng {BUOC_TOI_THIEU}–{BUOC_TOI_DA} của PRS-16 §4")

    trich = {c for c in (plan.get("citations") or [])}
    for b in buoc:
        trich |= {c for c in (b.get("cites") or [])}
    fid = {c for c in trich if re.fullmatch(r"f_[0-9a-f]+", str(c))}
    if fid:
        db = store.store_path(root)
        co: set[str] = set()
        if db.exists():
            with store.open_store(db) as c:
                co = {r[0] for r in c.execute(
                    f"SELECT id FROM fact WHERE id IN ({','.join('?' * len(fid))})",  # noqa: S608
                    sorted(fid)).fetchall()}
        if (ma := sorted(fid - co)):
            # PRS-16 §4 cấm planner "giả định tri thức chắc có". Một kế hoạch trích dẫn fact
            # không tồn tại trông y hệt một kế hoạch đúng — đây là chỗ duy nhất bắt được.
            loi.append(f"trích dẫn fact không có trong store: {ma}")
    return loi


# PRS-16 §4 cho `touches` một enum đóng: isr, linker, clock, dma, power, actuator, none.
#
# `none` là giá trị "bước này không chạm gì nhạy cảm"; sáu giá trị còn lại đều nhạy cảm, nên
# `touches_forbidden` của G1-01 = "có bước nào chạm bất kỳ cái nào trong sáu". POL-17 không định
# nghĩa chữ "forbidden", và cách đọc hẹp hơn — chỉ isr với linker — làm G1-01 tự duyệt một kế
# hoạch động vào clock, DMA hay cơ cấu chấp hành, tức đúng loại việc mà cả cổng sinh ra để hỏi.
# Xem DEV-061.
CHAM_NHAY_CAM = frozenset({"isr", "linker", "clock", "dma", "power", "actuator"})

# G1-03 ("Đổi kiến trúc") tự nêu ba thứ trong chính lý do của nó: "RTOS, clock, linker". RTOS
# không có trong enum `touches`; hai cái còn lại thì có.
CHAM_DOI_KIEN_TRUC = frozenset({"linker", "clock"})


def _cham(buoc: list[dict[str, Any]]) -> set[str]:
    return {t for b in buoc for t in (b.get("touches") or [])}


def _dac_trung_G1(plan: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Bảy đặc trưng mà G1-01 hỏi (POL-17 §2).

    `touches_forbidden` và `arch_change` được SUY TỪ `touches` của từng bước, không đọc từ hai
    khóa cùng tên ở mức kế hoạch. Bản trước đọc `plan["touches_forbidden"]` và
    `plan["arch_change"]` — hai khóa mà schema gửi cho mô hình không hề có và không chỗ nào
    tính, nên cả hai luôn `False`: G1-03 là quy tắc chết, và G1-01 tự duyệt được một kế hoạch
    sửa linker. Xem DEV-061.
    """
    buoc = plan.get("steps") or []
    est = plan.get("estimate") or {}
    cham = _cham(buoc)
    return {
        "plan": {
            "steps": len(buoc),
            "all_cited": all(b.get("cites") for b in buoc) if buoc else False,
            "new_resources": bool(plan.get("new_resources")),
            "touches_forbidden": bool(cham & CHAM_NHAY_CAM),
            "est_cost_usd": float(est.get("cost_usd") or 0),
            "missing": bool(plan.get("missing")),
            "arch_change": bool(cham & CHAM_DOI_KIEN_TRUC),
        },
        "feature": {"needs_review": any(b.get("needs_review") for b in buoc)},
    }


@capability("plan.define_feature")
def define_feature(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PLAN-01 — CDS-12.1. tc: "expectation là serial pattern đo được".

    Điểm duy nhất của năng lực này là ép `expectation` thành thứ MÁY QUAN SÁT ĐƯỢC. Một feature
    ghi "LED nháy đúng" thì không test nào kiểm được, và nó sẽ nằm `failing` mãi hoặc được đánh
    dấu `passing` bằng mắt người — cả hai đều làm FEATURES.json mất nghĩa.

    Ba dạng hợp lệ theo hợp đồng: `serial pattern`, `probe reg`, `measurement`. Kiểm ở mã chứ
    không dặn trong prompt: mô hình rất sẵn lòng viết một câu nghe như đo được mà không đo được.
    """
    from eide.caps.memory import compose

    text = params["text"]
    root = _root(ctx)
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    bundle = compose({"role": "planner", "task_ref": text}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    resp = gw.run("planner", f"Chuẩn hóa yêu cầu sau thành Feature: {text}", _SCHEMA_FEATURE,
                  system_extra=ngu_canh)
    f = dict(resp.data)

    if (kind := (f.get("expectation") or {}).get("kind")) not in DANG_KY_VONG:
        raise EideError("E5002", f"expectation.kind=`{kind}` không thuộc {list(DANG_KY_VONG)} — "
                        "kỳ vọng phải MÁY quan sát được (PLAN-01)", kind=kind)

    f["id"] = _ma_feature_moi(root)
    f["status"] = "failing"      # bước 3: FEATURES.json failing
    _ghi_features(root, f)
    return {"feature": f}


DANG_KY_VONG = ("serial_pattern", "probe_reg", "measurement")

_SCHEMA_FEATURE = {
    "type": "object",
    "required": ["title", "expectation"],
    "properties": {
        "title": {"type": "string"},
        "expectation": {
            "type": "object", "required": ["kind", "detail"],
            "properties": {"kind": {"type": "string", "enum": list(DANG_KY_VONG)},
                           "detail": {"type": "string"}}},
        "constraints": {"type": "array", "items": {"type": "string"}},
        "touches": {"type": "array", "items": {"type": "string"}},
    },
}


def _ma_feature_moi(root: Path) -> str:
    """`F-nn` liên tiếp. Đọc từ FEATURES.json chứ không đếm lại: một id đã phát ra thì không được
    tái sử dụng, kể cả khi feature ấy đã bị xóa — nhật ký còn nhắc tới nó."""
    ds = _doc_features(root)
    so = [int(m.group(1)) for f in ds if (m := re.fullmatch(r"F-(\d+)", str(f.get("id", ""))))]
    return f"F-{max(so, default=0) + 1:02d}"


def _doc_features(root: Path) -> list[dict[str, Any]]:
    f = root / EIDE_DIR / "FEATURES.json"
    if not f.exists():
        return []
    return (json.loads(f.read_text(encoding="utf-8")) or {}).get("features", [])


def _ghi_features(root: Path, moi: dict[str, Any]) -> None:
    f = root / EIDE_DIR / "FEATURES.json"
    ds = _doc_features(root)
    ds.append(moi)
    f.write_text(json.dumps({"features": ds}, ensure_ascii=False, indent=2), encoding="utf-8")


@capability("plan.decompose")
def decompose(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PLAN-02 — CDS-12.1. tc: "Z-07: 8 feature".

    "mỗi feature ≤ 1 module chính" là ràng buộc kiểm được, nên kiểm: một feature chạm ba module
    không test riêng được, không giao cho một người được, và khi nó hỏng thì không biết hỏng ở
    đâu. Thứ tự trả về đi qua `plan.order` để tầng driver → HAL → service → app đúng chiều.
    """
    from eide.caps.memory import compose

    goal = params["goal"]
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    bundle = compose({"role": "planner", "task_ref": goal}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    resp = gw.run("planner", f"Tách mục tiêu sau thành feature: {goal}", _SCHEMA_DECOMPOSE,
                  system_extra=ngu_canh)
    ds = list(resp.data.get("features") or [])

    if (nhieu := [f.get("title", "?") for f in ds if len(f.get("modules") or []) > 1]):
        raise EideError("E5002", f"Feature chạm nhiều hơn một module chính: {nhieu} "
                        "(PLAN-02: mỗi feature ≤ 1 module chính)", features=nhieu)

    ten = [f.get("module") or (f.get("modules") or [""])[0] or f.get("title", "") for f in ds]
    thu_tu = order({"features": ten}, ctx)["order"] if ten else []
    vi_tri = {t: i for i, t in enumerate(thu_tu)}
    ds.sort(key=lambda f: vi_tri.get(f.get("module") or (f.get("modules") or [""])[0]
                                     or f.get("title", ""), 999))
    return {"features": ds}


_SCHEMA_DECOMPOSE = {
    "type": "object", "required": ["features"],
    "properties": {"features": {"type": "array", "items": {
        "type": "object", "required": ["title"],
        "properties": {"title": {"type": "string"}, "module": {"type": "string"},
                       "modules": {"type": "array", "items": {"type": "string"}},
                       "layer": {"type": "string"}}}}},
}


@capability("plan.replan")
def replan(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PLAN-06 — CDS-12.1. tc: "Bước xong không đổi"; ask "Lần 3".

    Bước đã xong được GIỮ NGUYÊN, không lập lại. Đó là tc của hợp đồng và cũng là điều làm việc
    lập lại kế hoạch khác việc vứt đi làm lại: mã đã viết, fact đã duyệt, firmware đã nạp —
    những thứ ấy vẫn còn đó, và một kế hoạch mới bỏ qua chúng sẽ làm lại từ đầu một cách lãng
    phí, hoặc tệ hơn, làm lại một thao tác R3 lên phần cứng.

    Lập lại lần thứ ba thì hỏi người (ask "Lần 3"): hai lần đầu là điều chỉnh, lần thứ ba nghĩa
    là giả định gốc sai, và tác tử không phải bên nên tự quyết điều đó.
    """
    root = _root(ctx)
    plan_id, ly_do = params["plan_id"], params["reason"]
    cu = _doc_plan(root, plan_id)
    xong = [b for b in (cu.get("steps") or []) if b.get("status") == "done"]

    lan = int(cu.get("replan_count", 0)) + 1
    if lan >= 3:
        raise EideError("E3000", f"Lập lại kế hoạch lần {lan} — giả định gốc có thể sai, "
                        "cần người xem lại (PLAN-06 ask: Lần 3)", rule="PLAN-06", gate="G1",
                        plan_id=plan_id, lan=lan)

    from eide.caps.memory import compose
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    # C6 = lý do thất bại (bước 1 của hợp đồng): mô hình phải thấy CÁI GÌ hỏng, không chỉ biết
    # rằng có gì đó hỏng — nếu không nó sẽ đề xuất lại đúng bước vừa thất bại.
    bundle = compose({"role": "planner", "task_ref": plan_id}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    ngu_canh += f"\n\n## C6 — vì sao phải lập lại\nlý do: {ly_do}\n{params.get('detail', '')}"
    resp = gw.run("planner", f"Lập lại kế hoạch {plan_id}; giữ nguyên các bước đã xong.",
                  _SCHEMA_PLAN, system_extra=ngu_canh)

    moi = dict(resp.data)
    id_xong = {b.get("id") for b in xong}
    moi["steps"] = xong + [b for b in (moi.get("steps") or []) if b.get("id") not in id_xong]
    moi["replan_count"] = lan
    moi["replan_reason"] = ly_do
    return {"plan": moi}


def _doc_plan(root: Path, plan_id: str) -> dict[str, Any]:
    db = store.store_path(root)
    if not db.exists():
        return {}
    with store.open_store(db) as c:
        row = c.execute("SELECT report FROM run WHERE id=?", (plan_id,)).fetchone()
    return json.loads(row[0]) if row and row[0] else {}
