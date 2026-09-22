"""Namespace memory.* — CDS-12.6 (tập Hội thoại & bộ nhớ); MEM-11 §5; CXD-10."""
from __future__ import annotations

import json
import secrets
import sqlite3
import unicodedata
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import yaml

from eide_core import store
from eide_core.composer import cau_hinh, uoc_token
from eide_core.errors import EideError
from eide_core.memory import SessionMemory
from eide_core.paths import spec_dir
from eide_core.rag import RagIndex
from eide_core.registry import capability, get_registry
from eide_core.router import Context
from eide_core.undo import UndoService

EIDE_DIR = ".eide"


def _goc(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Chưa mở dự án", exists=[], candidates=[], missing=["project"])
    return root


def _features(root: Path) -> list[dict[str, Any]]:
    """FEATURES.json sinh từ bảng `feature` của M3 — MEM-11 §5 "cả hai được sinh từ M3, không viết tay"."""
    db = store.store_path(root)
    if not db.exists():
        return []
    with sqlite3.connect(db) as c:
        rows = c.execute("SELECT id, title, status, evidence, verified, run_id"
                         " FROM feature ORDER BY updated_at, id").fetchall()
    return [{"id": r[0], "title": r[1], "status": r[2],
             "evidence": json.loads(r[3]) if r[3] else [],
             "verified": r[4], "run": r[5], "blocked_by": None} for r in rows]


def _autonomy(root: Path) -> str | None:
    f = root / EIDE_DIR / "autonomy.yaml"
    return (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("autonomy") if f.exists() else None


def _board(root: Path) -> str | None:
    f = root / EIDE_DIR / "constraints.yaml"
    if not f.exists():
        return None
    return ((yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("target") or {}).get("board")


def _tu_ledger(led) -> tuple[list[dict], list[dict]]:
    """(việc đã xong, cổng còn mở) — cả hai từ M3, không từ bộ đếm riêng."""
    recs = led.records() if led is not None else []
    xong, cho = [], {}
    ten = {}
    for r in recs:
        d = r.get("data") or {}
        if r["kind"] == "cap.run.start" and d.get("run_id"):
            ten[d["run_id"]] = d.get("cap", "?")
        elif r["kind"] == "cap.run.finish" and d.get("run_id"):
            if d.get("status") == "done":
                xong.append({"run_id": d["run_id"], "cap": ten.get(d["run_id"], "?"), "at": r["ts"]})
            elif d.get("status") == "pending":
                cho[d["run_id"]] = {"run_id": d["run_id"], "cap": ten.get(d["run_id"], "?"), "at": r["ts"]}
        elif r["kind"] == "gate.human" and d.get("gate_id"):
            cho.pop(d["gate_id"], None)
    return xong, list(cho.values())


@capability("memory.progress")
def progress(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-04 — CDS-12.6; MEM-11 §5 (PROGRESS.md, FEATURES.json sinh từ M3); FR-GOV-03.

    `tc` là "nội dung khớp ledger; KHÔNG VIẾT TAY", nên mọi con số ở đây đến từ ledger (M3) và
    bảng `feature` — không có bộ đếm riêng nào. Đây cũng là lý do hai tệp này được ghi đè mỗi
    lần gọi: chúng là ẢNH CHỤP của M3, không phải tài liệu người sửa. Chỗ duy nhất người nói
    được vào là `entry`.
    """
    root = _goc(ctx)
    led = ctx.extra.get("ledger")
    xong, cho = _tu_ledger(led)
    feats = _features(root)
    dat = sum(1 for f in feats if f["status"] == "passing")
    hong = next((f for f in feats if f["status"] == "failing"), None)
    undo = UndoService(led, getattr(ctx.extra.get("gate"), "config", None)).list() if led else []

    board = _board(root)
    dong = [f"## Trạng thái {datetime.now(UTC).strftime('%d/%m %H:%M')} · dự án {root.name}"
            f" · {_autonomy(root) or '?'}" + (f" · board {board}" if board else "")]
    dong.append(f"- Đã làm: {len(xong)} việc tự động, {len(cho)} chờ anh"
                + (f" ({', '.join(c['cap'] for c in cho[:3])})" if cho else ""))
    if feats:
        d = f"- Feature: {dat}/{len(feats)} passing"
        if hong:
            d += f"; đang làm {hong['id']} {hong['title']}"
            if hong.get("run"):
                d += f" (run {hong['run']})"
        dong.append(d)
    else:
        dong.append("- Feature: chưa có")
    if undo:
        u = undo[0]
        dong.append(f"- Hoàn tác được đến {(u['deadline'] or 'hết phiên')[:16]}: "
                    + ", ".join(f"{x['cap']} ({x['kind']})" for x in undo[:3]))
    if params.get("entry"):
        dong.append(f"- Ghi chú: {params['entry']}")

    md = "\n".join(dong) + "\n"
    features = {"features": feats}
    (root / EIDE_DIR / "PROGRESS.md").write_text(md, encoding="utf-8")
    (root / EIDE_DIR / "FEATURES.json").write_text(
        json.dumps(features, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"progress_md": md, "features": features}


@capability("memory.summarize_session")
def summarize_session(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-08 — CDS-12.6; MEM-11 §5 (thủ tục khởi động phiên, 5 bước); UC-A06.

    Trả {done, waiting, next, undo_until} — thứ `chat.report_back` đọc ra thành câu "lần trước
    đã… còn chờ… tôi đề nghị…". Mục tiêu của §5 là tiếp tục được trong ≤ 15 phút với ≤ 1 câu
    hỏi, nên `next` phải là một ĐỀ NGHỊ cụ thể chứ không phải một danh sách để người tự chọn.

    Giới hạn ≤ 200 token của hợp đồng là thật, không phải lời khuyên: bản tóm tắt này đi vào
    lượt đầu của phiên mới, và một tóm tắt phình ra sẽ đẩy chính thứ nó tóm tắt ra khỏi ngữ cảnh.
    """
    root = _goc(ctx)
    led = ctx.extra.get("ledger")
    xong, cho = _tu_ledger(led)
    feats = _features(root)
    undo = UndoService(led, getattr(ctx.extra.get("gate"), "config", None)).list() if led else []

    done = [f"{c['cap']} ({c['run_id'][:8]})" for c in xong[-5:]]
    waiting = [f"{c['cap']} chờ duyệt ({c['run_id'][:8]})" for c in cho[:5]]

    nxt: list[str] = []
    db = store.store_path(root)
    if db.exists():
        with sqlite3.connect(db) as c:
            do_dang = c.execute("SELECT id, state FROM run WHERE state IN ('running','asked')"
                                " ORDER BY id").fetchall()
        for rid, st in do_dang[:2]:
            nxt.append(f"tiếp tục run {rid} (đang {st})")
    hong = next((f for f in feats if f["status"] == "failing"), None)
    if hong:
        nxt.append(f"làm tiếp {hong['id']} {hong['title']}")
    if not nxt:
        nxt.append("chưa có việc dở — chờ lệnh")

    sid = params.get("session_id")
    phien = SessionMemory.doc(root, sid) if sid else SessionMemory.gan_nhat(root)
    summary = {"done": done, "waiting": waiting, "next": nxt,
               "undo_until": (undo[0]["deadline"] if undo else None)}
    if led is not None:
        led.append("session.summary", {"session_id": phien.session_id if phien else "",
                                       "summary": "; ".join(done[-2:] + nxt[:1])[:400]})
    return {"summary": summary}


# ---------------------------------------------------------------- MEMORY-01, MEMORY-02

def _c0_nang_luc(text: str, role: str, ctx: Context) -> tuple[str, list[str]]:
    """C0 — mô tả ngắn top-k năng lực liên quan (CXD-10 §4.2).

    Điểm = khớp từ khóa với tên/mô tả. §4.2 nói BM25 + trùng nhóm ý định + dùng gần đây; ở
    đây mới có vế đầu, và đó là một xấp xỉ có ý thức chứ không phải quên — hai vế sau cần
    intent đã nhận diện và lịch sử dùng theo dự án, cả hai đến ở M2.

    §4.2 cũng cấm đưa năng lực R4 vào C0 của `intent` trừ khi câu lệnh có từ khóa tương ứng.
    Đó là một ràng buộc AN TOÀN, không phải tối ưu: một danh sách có sẵn `target.erase` làm
    mô hình dễ chọn nó cho một câu mơ hồ.
    """
    from eide_core.composer import cau_hinh
    reg = ctx.extra.get("registry") or get_registry()
    k = int(cau_hinh()["k0"].get(role, 8))
    tu = {w for w in _unaccent(text).split() if len(w) > 2}
    tu_khoa_r4 = {"xoa", "erase", "fuse", "phat", "hanh", "publish", "delete"}
    co_r4 = bool(tu & tu_khoa_r4)

    # Lọc R4 MỘT LẦN, trước cả chấm điểm lẫn nhánh dự phòng. Đặt phép lọc trong vòng chấm
    # điểm rồi lại có một nhánh `if not chon` không lọc là để hở đúng cửa mà §4.2 đóng — và
    # nhánh ấy chạy khi câu lệnh mơ hồ, tức đúng lúc nguy hiểm nhất.
    ung_vien = [c for c in reg.list()
                if not (c.spec.risk_class == "R4" and role == "intent" and not co_r4)]

    diem: list[tuple[float, Any]] = []
    for c in ung_vien:
        mo_ta = _unaccent(f"{c.spec.id} {c.spec.desc}")
        d = sum(1.0 for w in tu if w in mo_ta)
        if d:
            diem.append((d, c))
    diem.sort(key=lambda x: (-x[0], x[1].spec.code))
    chon = [c for _, c in diem[:k]]
    if not chon:
        chon = [c for c in ung_vien if c.implemented][:k]
    dong = [f"- {c.spec.id} — {c.spec.desc[:70]}" for c in chon]
    nguon = [c.spec.id for c in chon]

    # DPS-09 §4.1 đòi HAI thứ cho vai trò `intent`: "danh sách Ý ĐỊNH" VÀ "mô tả ngắn của ≤ 30
    # NĂNG LỰC liên quan nhất". Chúng khác nhau: enum ý định là 19 phân loại mà mô hình phải
    # chọn một; năng lực là 238 hợp đồng để nó biết EIDE làm được gì.
    #
    # Bản đầu của Composer chỉ đưa vế thứ hai, và TC-59 tụt từ 98% xuống 82% — mô hình mất
    # bảng phân biệt `view.ask` với `debug.ask` mà DEV-021 đã dựng. Đo được nhờ chạy mô hình
    # thật; bộ test EchoPort vẫn xanh suốt.
    if role == "intent":
        ds = (spec_dir() / "dialog" / "intents.md").read_text(encoding="utf-8").strip()
        dong = [ds, "", "Năng lực liên quan:", *dong]
        nguon = ["dialog/intents.md", *nguon]
    return "\n".join(dong), nguon


def _c5_tinh_nang(root: Path, task_ref: str) -> tuple[str, list[str]]:
    """C5 — ĐỊNH NGHĨA của chính tính năng đang lập kế hoạch. [DEV-174a]

    CXD-10 §2 đặt C5 là *"tác vụ và mã liên quan"*, và tác vụ ở đây CHÍNH LÀ tính năng. Nhưng
    `plan.create` chỉ nói với mô hình đúng một chuỗi — `"Lập kế hoạch cho tính năng: F-01"` —
    trong khi `.eide/FEATURES.json` giữ đủ tiêu đề, kỳ vọng đo được, ràng buộc và `touches`.

    Đo 22/09/2026: tính năng F-01 ghi *"chu kỳ 1 giây (500ms mức cao, 500ms mức thấp)"*, và
    planner vẫn khai `missing: ["Chưa có yêu cầu cụ thể về chu kỳ nhấp nháy (500ms hay
    1000ms)"]` — nó hỏi lại đúng con số đang nằm trong tệp của dự án. Cổng G1-02 vì thế trả
    ASK, và cả chuỗi đứng vì một câu hỏi không có thật.

    Tác tử lập kế hoạch cho một mã hiệu mà không được đọc mã hiệu ấy nghĩa là gì thì nó chỉ còn
    cách suy từ tên dự án — và suy sai là điều chắc chắn xảy ra, không phải rủi ro.
    """
    from eide.caps.code import _doc_feature

    f = root / EIDE_DIR / "FEATURES.json"
    if not task_ref or not f.exists():
        return "", []
    try:
        # Dùng LẠI bộ đọc của `code.py` chứ không viết bộ thứ hai. `FEATURES.json` tồn tại ở
        # HAI hình dạng trong kho — `{"features": [...]}` (thứ `project.create` và
        # `memory.progress` ghi) và một danh sách trần (thứ vài chỗ khác ghi) — và `_doc_feature`
        # đã xử lý cả hai từ trước. Bản đầu của tôi chỉ biết dạng thứ nhất; `make check` bắt
        # được bằng bốn bài `test_code.py` đỏ vì `'list' object has no attribute 'get'`.
        ft = _doc_feature(root, str(task_ref))
    except (json.JSONDecodeError, AttributeError, TypeError):
        # Tệp hỏng KHÔNG được làm hỏng cả lời gọi: ngữ cảnh thiếu một lớp còn chạy được, một
        # ngoại lệ ở đây chặn mọi việc.
        return "", []
    if ft is None:
        return "", []
    dong = [f"## Tính năng đang lập kế hoạch: {ft.get('id')} — {ft.get('title', '')}"]
    ky_vong = ft.get("expectation") or {}
    if ky_vong.get("detail"):
        # Kỳ vọng ĐO ĐƯỢC là thứ PLAN-01 bắt buộc phải có; đưa nó vào đây là đưa đúng tiêu chí
        # mà kế hoạch phải dẫn tới, thay vì để mô hình tự nghĩ ra một tiêu chí dễ hơn.
        dong.append(f"- Kỳ vọng ({ky_vong.get('kind', '?')}): {ky_vong['detail']}")
    for k, nhan in (("constraints", "Ràng buộc"), ("touches", "Chạm tới")):
        if ft.get(k):
            dong.append(f"- {nhan}: " + "; ".join(str(x) for x in ft[k]))
    if ft.get("status"):
        dong.append(f"- Trạng thái: {ft['status']}")
    return "\n".join(dong), [str(f)]


def _c2_tra_loi_cua_nguoi(root: Path, tran_token: int) -> tuple[str, list[str], int]:
    """C2 — CÂU TRẢ LỜI người đã cho cho từng điểm cần làm rõ. [DEV-174a]

    ## Vì sao lớp này phải có

    Đo 22/09/2026 trên dự án `nhap-nhay-led-tren-atmega328p`: planner hỏi hai câu rất cụ thể
    (*"chưa rõ xung nhịp thực tế của board"*, *"chưa rõ chân GPIO nối với LED"*), người dùng
    trả lời cả hai qua `req.answer_clarification` — cả hai về `answered` — rồi bảo tác tử lập
    lại kế hoạch, và **nó hỏi y nguyên câu cũ**. Không lớp ngữ cảnh nào mang câu trả lời ấy
    vào, nên vòng *hỏi → người trả lời → làm tiếp* không khép được: người dùng gõ vào một cái
    hộp mà tác tử không bao giờ mở.

    ## Vì sao là C2 chứ không phải C5 hay C7

    CXD-10 §2 đặt C2 là **ràng buộc dự án**, và một câu trả lời kiểu "LED nối chân PB5, mức cao
    là sáng" đúng là một ràng buộc — cùng họ với chân cấm và ngân sách RAM. Quan trọng hơn: C2
    có `cut_priority = 9`, tức **không bao giờ bị cắt**. Một câu người đã trả lời mà bị bỏ đi
    lúc ngữ cảnh chật là tệ nhất trong các cách quên: người dùng tin rằng họ đã nói rồi.

    C7 (lịch sử lượt) thì bị cắt đầu tiên, và C5 là "tác vụ và mã liên quan" — câu trả lời của
    người không phải mã.

    ## Khối RIÊNG, không nhập vào khối ràng buộc

    `_c2_rang_buoc` đánh dấu `cacheable=True` vì `constraints.yaml` gần như tĩnh. Danh sách câu
    trả lời thì đổi mỗi lần người gõ một câu, nên nhập chung sẽ làm hỏng cache của cả khối.

    ## Trần token, và nói ra khi cắt

    C2 không cắt được, nên một dự án có trăm câu trả lời sẽ đẩy tổng vượt ngân sách và
    `kiem_tran` từ chối gọi mô hình (E5001) — đổi một lỗi im lặng lấy một lỗi ồn ào. Nên cắt ở
    đây, lấy câu MỚI NHẤT trước, và **ghi rõ đã bỏ bao nhiêu**: một danh sách bị xén âm thầm
    đọc y hệt một danh sách đầy đủ.
    """
    db = store.store_path(root)
    if not db.exists():
        return "", [], 0
    with store.open_store(db) as c:
        try:
            ds = c.execute(
                "SELECT id, text, answer, answered_by, answered_at FROM clarification"
                " WHERE status='answered' AND answer IS NOT NULL AND answer <> ''"
                " ORDER BY answered_at DESC, id DESC").fetchall()
        except sqlite3.OperationalError:
            return "", [], 0          # store cũ chưa có bảng (user_version < 8)
    if not ds:
        return "", [], 0

    dau = ("## Người dùng ĐÃ TRẢ LỜI những điểm sau — coi đây là sự thật về dự án này và "
           "KHÔNG hỏi lại:")
    dong, nguon, bo = [], [], 0
    for cid, hoi, tra, ai, _at in ds:
        d = f"- {str(hoi).strip()}\n  → {str(tra).strip()}" + (f" ({ai})" if ai else "")
        if uoc_token("\n".join([dau, *dong, d])) > tran_token and dong:
            bo = len(ds) - len(dong)
            break
        dong.append(d)
        nguon.append(f"clarification:{cid}")
    if bo:
        dong.append(f"- (còn {bo} câu đã trả lời nữa, cắt vì ngân sách C2 — hỏi lại bằng "
                    "`view.artifacts kind=clarification` nếu cần)")
    return "\n".join([dau, *dong]), nguon, bo


def _c2_rang_buoc(root: Path) -> tuple[str, list[str]]:
    """C2 — constraints.yaml nén thành bảng khóa–giá trị (CXD-10 §4.3)."""
    f = root / EIDE_DIR / "constraints.yaml"
    if not f.exists():
        return "", []
    c = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    dong = []
    for nhom, gia_tri in c.items():
        if isinstance(gia_tri, dict):
            for k, v in gia_tri.items():
                if v not in (None, "", [], {}):
                    dong.append(f"{nhom}.{k}: {v}")
        elif gia_tri not in (None, "", [], {}):
            dong.append(f"{nhom}: {gia_tri}")
    a = root / EIDE_DIR / "autonomy.yaml"
    if a.exists():
        d = yaml.safe_load(a.read_text(encoding="utf-8")) or {}
        # Giữ nguyên các mục AN TOÀN dù có phải cắt (§4.3)
        for k in ("autonomy", "sensitive"):
            if k in d:
                dong.append(f"{k}: {d[k]}")
    return "\n".join(dong), [str(f)]


#: Trần dòng diff gửi NGUYÊN VĂN — UXC-31 §7.6.
#:
#: Trên trần thì tóm tắt bằng mô hình và **ghi rõ là đã tóm tắt**. Con số 200 đến từ tài liệu,
#: không phải từ tôi; ranh giới của nó là ranh giới giữa "tác tử đọc được đúng thứ người sửa"
#: và "một khối chiếm hết ngân sách C5, đẩy fact phần cứng ra ngoài".
TRAN_DONG_DIFF = 200


def _c5_nguoi_sua(root: Path, led: Any) -> tuple[str, list[str], bool] | None:
    """Khối "thay đổi của người từ lượt trước" — §7.5, và phép cắt của §7.6.

    Đọc từ SỔ CÁI chứ không từ `git log`: sổ cái biết lần lưu nào là của NGƯỜI
    (`human.file_save`), còn `git log` chỉ biết một tác giả — và sau [DEV-144] thì tác giả ấy
    phân biệt được, nhưng sổ cái vẫn là nguồn đúng vì nó cũng biết lượt nào đã kể rồi.

    Mốc "từ lượt trước" = bản ghi `run.done` gần nhất. Mọi lần người lưu SAU mốc ấy là thứ tác
    tử chưa từng thấy.

    Trả `None` khi không có gì — khác hẳn trả một khối rỗng. Một khối C5 ghi "người không sửa
    gì" vẫn tốn token và vẫn nói một điều không ai hỏi.
    """
    if led is None:
        return None
    try:
        ban_ghi = list(led.records())
    except Exception:  # noqa: BLE001 — sổ cái hỏng không được làm hỏng cả lượt compose
        return None

    moc = 0
    for r in ban_ghi:
        if r.get("kind") == "run.done":
            moc = int(r.get("seq") or 0)
    luu = [r for r in ban_ghi
           if r.get("kind") == "human.file_save" and int(r.get("seq") or 0) > moc]
    if not luu:
        return None

    from eide_core import git
    dong: list[str] = []
    nguon: list[str] = []
    for r in luu:
        d = r.get("data") or {}
        duong, sha = d.get("path") or "?", d.get("commit") or ""
        nguon.append(f"human.file_save:{sha[:10]}" if sha else f"human.file_save:{duong}")
        dong.append(f"--- {duong} ({d.get('diff_summary') or 'không rõ thay đổi'})")
        if not sha or not git.la_kho(root):
            continue
        p = git.chay(root, "show", "--format=", "--unified=3", sha, kiem=False)
        if p.returncode == 0 and p.stdout.strip():
            dong += p.stdout.rstrip("\n").split("\n")

    if len(dong) <= TRAN_DONG_DIFF:
        return ("Người đã sửa tay từ lượt trước — nền mã đã KHÁC:\n" + "\n".join(dong),
                nguon, False)

    # §7.6 — quá trần thì tóm tắt, và NÓI RA là đã tóm tắt. Không nói thì tác tử đọc một bản
    # rút gọn như thể đó là toàn bộ thay đổi, rồi kết luận rằng phần nó không thấy là không có.
    tom = _tom_tat_diff("\n".join(dong))
    return (f"Người đã sửa tay từ lượt trước — nền mã đã KHÁC. **Diff {len(dong)} dòng, vượt "
            f"trần {TRAN_DONG_DIFF} nên ĐÃ TÓM TẮT** (bản đầy đủ: `git show` các commit ở "
            f"`sources`):\n{tom}", nguon, True)


def _tom_tat_diff(van: str) -> str:
    """Tóm tắt một diff dài. Mô hình hỏng thì lùi về phép cắt XÁC ĐỊNH, không ném.

    Lùi về được là bắt buộc: một lượt chạy không được chết vì phần tóm tắt ngữ cảnh của nó gọi
    mô hình không xong. Bản lùi giữ nguyên các dòng `+++`/`---`/`@@` — tức GIỮ được tệp nào và
    vùng nào đổi, mất phần nội dung — nên nó vẫn nói đúng thứ quan trọng nhất.
    """
    try:
        from eide_core.gateway import Gateway
        r = Gateway().call(
            role="intent",
            messages=[{"role": "user",
                       "content": "Tóm tắt diff sau trong ≤ 15 dòng tiếng Việt. Giữ NGUYÊN tên "
                                  "tệp, tên hàm và mọi hằng số; nói rõ mỗi tệp đổi theo hướng "
                                  f"nào.\n\n{van[:20000]}"}],
            temperature=0)
        d = (r.get("text") or "").strip()
        if d:
            return d
    except Exception:  # noqa: BLE001 — xem docstring
        pass
    giu = [d for d in van.split("\n") if d.startswith(("--- ", "+++ ", "@@"))]
    return ("(không gọi được mô hình để tóm tắt — giữ phần đầu mỗi vùng thay đổi)\n"
            + "\n".join(giu[:60]))


@capability("memory.compose")
def compose(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-01 — CDS-12.6; CXD-10 §4.1 (compose), §5 (cắt), §7 (E5001); API-15 §5.

    Thay cho hàm `_c0()` viết vội trong `chat.py`: một chỗ dựng ngữ cảnh, có ngân sách, có thứ
    tự cắt, có ghi ledger — thay vì mỗi năng lực tự ghép chuỗi theo cách riêng.
    """
    from eide_core.composer import ContextBundle
    from eide_core.gateway import Gateway

    role = params["role"]
    b = ContextBundle(role=role, task_ref=params.get("task_ref", ""))
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    co_du_an = bool(root and (root / EIDE_DIR).is_dir())

    # C1 — prompt vai trò, đứng đầu, cache được (CXD-10 §2). Kèm `negative_prompt` còn hạn của
    # CHÍNH vai trò ấy (MEM-11 §6, MEMORY-06 tc): ghi một lỗi mà không ai đọc lại thì nó chỉ là
    # một dòng nhật ký. Vòng khép kín là *lỗi → negative_prompt → ngữ cảnh lần sau*.
    gw = ctx.extra.get("gateway") or Gateway(ledger=ctx.extra.get("ledger"))
    prompt_vai_tro = gw.prompt(role)
    nhac = _loi_can_tranh(root, role) if co_du_an else []
    if nhac:
        prompt_vai_tro += "\n\nTránh (từ sổ lỗi):\n" + "\n".join(f"- {x}" for x in nhac)
    b.add("C1", prompt_vai_tro, [f"prompts/{role}.md"] + [f"error_ledger:{role}"] * bool(nhac),
          cacheable=True)

    # C0 — chỉ các vai trò CXD-10 §4.1 liệt kê
    if role in ("intent", "planner", "architect", "librarian"):
        text, nguon = _c0_nang_luc(params.get("task_ref", ""), role, ctx)
        b.add("C0", text, nguon)

    # C2 — ràng buộc dự án; với `intent` thì §4.1 dùng C1′ = tóm tắt trạng thái dự án
    if co_du_an:
        if role == "intent":
            f = _features(root)
            hong = next((x for x in f if x["status"] == "failing"), None)
            b.add("C2", f"Dự án đang mở: {root.name}."
                        + (f" Feature đang làm: {hong['id']} {hong['title']}." if hong else ""),
                  [str(root)])
        else:
            text, nguon = _c2_rang_buoc(root)
            b.add("C2", text, nguon, cacheable=True)
            # [DEV-174a] Khối RIÊNG, `cacheable=False`: `constraints.yaml` gần như tĩnh nên
            # khối trên cache được, còn danh sách câu trả lời đổi mỗi lần người gõ một câu.
            # Nhập chung là làm hỏng cache của cả hai.
            #
            # Trần = một nửa ngân sách C2 của vai trò: nửa kia để dành cho ràng buộc dự án, và
            # C2 KHÔNG cắt được nên tràn ở đây thành E5001 "không gọi mô hình".
            tran = max(120, int(b.budget.get("C2") or 600) // 2)
            van, ng, bo = _c2_tra_loi_cua_nguoi(root, tran)
            b.add("C2", van, ng)
            if bo:
                b.compressions.append(f"clarification:drop_{bo}")

    # C5 — **thay đổi của NGƯỜI từ lượt trước** (UXC-31 §7.5). Đặt ở C5 theo CXD-10 §3: lớp ấy
    # là "tác vụ và mã liên quan", và không có mã nào liên quan hơn mã người vừa sửa bằng tay.
    #
    # Thiếu khối này thì tác tử bước vào lượt mới với một bản đồ mã đã cũ: nó đọc tệp từ store
    # hoặc từ trí nhớ về lần nó tự ghi, rồi sinh một patch dựa trên nền đã không còn. Kết quả
    # tốt nhất là một xung đột merge; tệ nhất là một patch trông hợp lý mà đè lên ý người dùng.
    # [DEV-174a] C5 — ĐỊNH NGHĨA của tính năng đang lập kế hoạch. Đứng TRƯỚC khối "người sửa"
    # vì nó là chính tác vụ, còn khối kia là bối cảnh của tác vụ ấy.
    if co_du_an:
        van, ng = _c5_tinh_nang(root, params.get("task_ref", ""))
        b.add("C5", van, ng)

    if co_du_an:
        kh = _c5_nguoi_sua(root, ctx.extra.get("ledger"))
        if kh is not None:
            van, nguon, da_tom_tat = kh
            b.add("C5", van, nguon)
            if da_tom_tat:
                b.compressions.append("human_diff:summarize")

    # C7 — lịch sử lượt, tối đa 2 lượt đã tóm tắt (CXD-10 §2, MEM-11)
    if co_du_an:
        phien = SessionMemory.gan_nhat(root)
        if phien and phien.turns:
            from eide_core.composer import cau_hinh
            n = int(cau_hinh()["history_turns"])
            luot = [t for t in phien.turns if t.get("by") != "summary"][-n:]
            if luot:
                b.add("C7", "\n".join(f"{t['by']}: {t['text'][:200]}" for t in luot),
                      [phien.session_id])

    b.vua_ngan_sach()
    b.kiem_tran()
    b.ghi_ledger(ctx.extra.get("ledger"))
    return {"bundle": b.as_dict()}


@capability("memory.compress")
def compress(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-02 — CDS-12.6; CXD-10 §5; E5000; tc "kết quả ≤ target; MẪU LỖI GIỮ NGUYÊN".

    Bốn kiểu nén, và chỉ `history` gọi mô hình. Ba kiểu còn lại là phép biến đổi XÁC ĐỊNH —
    và với `log` điều đó là bắt buộc: `tc` đòi mẫu lỗi giữ nguyên, mà một mô hình tóm tắt log
    sẽ diễn đạt lại dòng lỗi thành câu văn, làm mất chính chuỗi mà người ta cần grep.
    """
    text = params["text"]
    kind = params.get("kind", "history")
    muc_tieu = int(params.get("target_tokens", 500))
    from eide_core.composer import uoc_token
    if uoc_token(text) <= muc_tieu:
        return {"text": text, "compressions": []}

    if kind == "log":
        # Cửa sổ quanh dòng khớp mẫu lỗi; giữ NGUYÊN VĂN.
        dong = text.splitlines()
        moc = [i for i, x in enumerate(dong)
               if any(k in x.lower() for k in ("error", "fail", "traceback", "hardfault", "assert"))]
        giu: set[int] = set()
        for i in moc:
            giu |= set(range(max(0, i - 2), min(len(dong), i + 3)))
        ra = [dong[i] for i in sorted(giu)] or dong[-40:]
        return {"text": "\n".join(ra), "compressions": ["log:window"]}

    if kind == "facts":
        # Bảng hóa: bỏ dòng trống và khoảng trắng thừa, giữ từng dòng là một fact.
        ra = [" ".join(x.split()) for x in text.splitlines() if x.strip()]
        while uoc_token("\n".join(ra)) > muc_tieu and len(ra) > 1:
            ra.pop()
        return {"text": "\n".join(ra), "compressions": ["facts:tabulate"]}

    if kind == "code":
        # Chỉ giữ dòng chữ ký hàm/lớp — CXD-10 §5 "function_only".
        ra = [x for x in text.splitlines()
              if x.lstrip().startswith(("def ", "class ", "async def ", "//", "#define"))]
        return {"text": "\n".join(ra) or text[: muc_tieu * 4], "compressions": ["code:function_only"]}

    # history — mô hình rẻ, vai trò intent, temperature 0 (CXD-10 §5)
    from eide_core.gateway import Gateway
    gw = ctx.extra.get("gateway") or Gateway(ledger=ctx.extra.get("ledger"))
    resp = gw.run("intent",
                  f"Tóm tắt đoạn sau còn ≤ {muc_tieu // 4} từ, GIỮ quyết định và số liệu, "
                  f"bỏ lời chào và lặp lại:\n\n{text[:8000]}",
                  {"type": "object", "required": ["intent", "slots", "is_big", "confidence",
                                                  "tom_tat"],
                   "properties": {"tom_tat": {"type": "string"},
                                  "intent": {"type": "string"}, "slots": {"type": "object"},
                                  "is_big": {"type": "boolean"},
                                  "confidence": {"type": "number"}}})
    return {"text": resp.data.get("tom_tat", text), "compressions": ["history:summarize"]}


def _unaccent(s: str) -> str:
    t = s.replace("đ", "d").replace("Đ", "D")
    return unicodedata.normalize("NFD", t).encode("ascii", "ignore").decode().lower()


@capability("memory.retrieve")
def retrieve(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-03 — CDS-12.6; CXD-10 §4.5 (Graph-RAG hai bước); DDD-14 RagChunk. tc: TC-CX-02.

    Hai nguồn, hai đường, trả về riêng: `facts` từ đồ thị tri thức, `snippets` từ RagIndex.
    Hợp đồng khai đúng hai mảng ấy, và giữ chúng tách nhau là có lý do — một fact đã qua G-FACT
    là tri thức đã duyệt, còn một đoạn văn bản chỉ là chỗ để người đọc kiểm lại. Trộn hai thứ
    vào một danh sách xếp hạng chung sẽ xóa mất phân biệt ấy đúng lúc nó quan trọng nhất.

    Cả hai đều mang `locator` và `score` như bước 2 của hợp đồng đòi: không có locator thì người
    dùng không lần về trang/dòng nào trong tài liệu gốc được, và một câu trả lời không truy
    nguyên được thì KAD-07 §4.1 không cho phép đưa vào fact.
    """
    subjects = params["subjects"]
    k = int(params.get("k") or 8)
    hops = int(params.get("hops") or 2)
    if hops < 1 or hops > 2:
        raise EideError("E1000", "hops phải là 1 hoặc 2 (CXD-10 §4.5 'Graph-RAG hai bước')")

    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "memory.retrieve cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])

    diem = _lan_toa(root, subjects, hops)
    facts = _fact_theo_diem(root, diem, k)
    snippets = RagIndex(root).retrieve(subjects, k)
    return {"facts": facts, "snippets": snippets}


def _lan_toa(root: Path, seeds: list[str], hops: int) -> dict[str, float]:
    """Lan tỏa điểm trên đồ thị — CXD-10 §4.5.

    `w = EDGE_W[type] / hop`, và điểm của một nút là LỚN NHẤT trong các đường tới nó, không
    phải tổng: một nút nối tới hạt giống bằng hai cạnh yếu không được vượt một nút nối bằng một
    cạnh mạnh. Cộng dồn sẽ làm những nút có bậc cao (chip gốc, chẳng hạn) luôn đứng đầu bất kể
    chúng có liên quan tới tác vụ hay không.
    """
    from eide.caps.kg import _do_thi

    g, _ = _do_thi(Context(project_dir=root))
    trong_so = cau_hinh()["edge_weight"]
    diem: dict[str, float] = {s: 1.0 for s in seeds if s in g.nut}
    bien = set(diem)
    for hop in range(1, hops + 1):
        moi: set[str] = set()
        for n in bien:
            for loai, b, _huong in g.ke.get(n, []):
                w = trong_so.get(loai, 0.0) / hop
                if w <= 0:
                    continue        # cạnh không có trọng số trong §4.5 ⇒ không lan điểm qua nó
                if w > diem.get(b, 0.0):
                    diem[b] = w
                moi.add(b)
        bien = moi - set(seeds)
    return diem


def _fact_theo_diem(root: Path, diem: dict[str, float], k: int) -> list[dict[str, Any]]:
    """Xếp hạng fact: `điểm_subject × PRED_W[predicate] × (1,0 vàng | 0,8 còn lại)` — §4.5.

    Chỉ lấy fact HIỆN HÀNH (`reviewed`/`verified`, hoặc `gold`) đúng như §4.5 ghi. Nhưng fact
    `conflict` LUÔN có mặt bất kể điểm và bất kể ngân sách: §4.5 nói "always_include", và lý do
    nằm ở câu cuối của §4.5 — mô hình phải nói "không xác định" thay vì tự chọn một bên. Giấu
    mâu thuẫn đi là cách chắc chắn nhất để nó chọn bừa.
    """
    if not diem:
        return []
    pw = cau_hinh()["pred_weight"]
    mac_dinh = pw.get("_mac_dinh", 0.5)
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute(
            "SELECT id, subject, predicate, value, unit, tier, status, source_id FROM fact"
        ).fetchall()
    ra = []
    for fid, subject, pred, value, unit, tier, status, src in rows:
        if subject not in diem:
            continue
        hien_hanh = status in ("reviewed", "verified") or tier == "gold"
        if not hien_hanh and status != "conflict":
            continue
        d = diem[subject] * pw.get(pred, mac_dinh) * (1.0 if tier == "gold" else 0.8)
        ra.append({"id": fid, "subject": subject, "predicate": pred,
                   "value": json.loads(value) if isinstance(value, str) else value,
                   "unit": unit, "tier": tier, "source_id": src, "status": status,
                   "score": round(d, 4), "conflict": status == "conflict"})
    ra.sort(key=lambda f: (-f["conflict"], -f["score"], f["id"]))
    mau_thuan = [f for f in ra if f["conflict"]]
    con_lai = [f for f in ra if not f["conflict"]]
    return mau_thuan + con_lai[: max(0, k - len(mau_thuan))]


@capability("memory.ledger")
def ledger(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-05 — CDS-12.6; API-15 §5 (bảng loại sự kiện). tc: "Chuỗi hash liên tục;
    regex khóa bị che".

    Vỏ mỏng quanh `eide_core.ledger.Ledger` — cố ý mỏng. Sổ cái là bất biến nền của cả hệ
    (SEC-25): chuỗi băm phải liên tục, nên chỉ được có MỘT chỗ nối mắt xích. Một năng lực tự
    ghi JSONL riêng sẽ tạo ra hai chuỗi băm, và `ledger.verify()` không phát hiện được đứt gãy
    ở chuỗi mà nó không biết.

    Đổi mã lỗi so với lớp lõi, có chủ ý: `Ledger.append` ném E6001 SCHEMA_VIOLATION cho `kind`
    lạ, nhưng hợp đồng MEMORY-05 khai E1000 và hợp đồng đúng hơn ở đây. Người GỌI truyền sai
    `kind` là đối số không hợp lệ (E1000 INVALID_ARGS), không phải sổ cái vi phạm schema của
    chính nó — phân biệt ấy quan trọng vì E6001 khiến người ta đi kiểm sổ cái thay vì kiểm lời
    gọi của mình.
    """
    from eide_core.ledger import Ledger, event_kinds
    kind = params["kind"]
    if kind not in event_kinds():
        gan = sorted(k for k in event_kinds() if k.split(".")[0] == kind.split(".")[0])
        raise EideError("E1000", f"Loại sự kiện {kind!r} không có trong bảng API-15 §5"
                        + (f" — ý bạn là {gan}?" if gan else ""),
                        kind=kind, candidates=gan)
    led = ctx.extra.get("ledger")
    if led is None:
        root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
        if not root:
            raise EideError("E2000", "memory.ledger cần một dự án đang mở hoặc `ledger` trong ctx",
                            exists=[], candidates=[], missing=["project"])
        led = Ledger(root / ".eide" / "ledger.jsonl")
    return {"hash": led.append(kind, params["data"], actor=ctx.actor)["hash"]}


# ---------------------------------------------------------------- MEMORY-06 error_ledger


TTL_NGAY = 30            # MEM-11 §6: "TTL 30 ngày"
TRAN_TOKEN_NHAC = 40     # "negative_prompt ≤ 40 token"
SO_NHAC_TOI_DA = 5

_SCHEMA_NHAC = {"type": "object", "required": ["negative_prompt"],
                "properties": {"negative_prompt": {"type": "string"}}}


@capability("memory.error_ledger")
def error_ledger(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-06 — CDS-12.6; MEM-11 §6; DDD-14 §2 ErrorLedgerEntry. `undo: none`.
    tc: "negative_prompt xuất hiện trong C1 của coder lần sau".

    Sổ lỗi chỉ có nghĩa nếu có chỗ ĐỌC nó. Ghi một lỗi rồi không ai nhìn lại thì nó là một dòng
    nhật ký; vòng khép kín là *lỗi → negative_prompt → ngữ cảnh lần sau* — và `memory.compose`
    là nơi khép vòng ấy, nên trường này đi thẳng vào C1 của đúng vai trò đã sai.

    **≤ 40 token** là ràng buộc thật, không phải mong muốn: lời nhắc này xuất hiện ở MỌI lượt
    sau đó, nên một câu dài đẩy thứ khác ra khỏi ngân sách ngữ cảnh mãi mãi. Cắt ở đây chứ không
    dặn mô hình — nó rất sẵn lòng viết một đoạn văn.

    **TTL 30 ngày**: không có hạn thì một lỗi của tháng trước còn dạy mô hình tránh một thứ đã
    sửa từ lâu, và nó không bao giờ tự biến mất.
    """
    root = _goc(ctx)
    kind, evidence = params["kind"], params["evidence"]
    role = params.get("role") or ""
    nhac = _sinh_nhac(ctx, role, kind, evidence, params.get("chip"))

    eid = "e_" + secrets.token_hex(6)
    now = datetime.now(UTC)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO error_ledger (id, role, kind, task_ref, chip, evidence,"
                  " negative_prompt, ttl_until, at) VALUES (?,?,?,?,?,?,?,?,?)",
                  (eid, role or None, kind, params.get("task_ref"), params.get("chip"),
                   evidence[:2000], nhac, (now + timedelta(days=TTL_NGAY)).isoformat(),
                   now.isoformat()))
        c.commit()
    store.write_seal(store.store_path(root), ctx.extra.get("ledger"))
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("error", {"id": eid, "role": role, "kind": kind, "task_ref": params.get("task_ref"),
                             "chip": params.get("chip"), "evidence": evidence[:300],
                             "negative_prompt": nhac, "at": now.isoformat()})
    return {"id": eid, "negative_prompt": nhac}


def _sinh_nhac(ctx: Context, role: str, kind: str, evidence: str, chip: str | None) -> str:
    """Một câu "đừng làm X" từ bằng chứng. Mô hình viết, MÃ cắt.

    Không cấu hình được mô hình thì vẫn phải có lời nhắc: rút gọn chính bằng chứng. Một sổ lỗi
    im lặng khi thiếu khóa API là một sổ lỗi rỗng đúng lúc dự án đang chạy ngoại tuyến.
    """
    from eide_core.composer import uoc_token
    from eide_core.gateway import Gateway
    tho = f"Tránh lặp lại: {evidence.strip()}"
    try:
        gw = ctx.extra.get("gateway") or Gateway(ledger=ctx.extra.get("ledger"))
        resp = gw.run("intent",
                      f"Viết MỘT câu ngắn (≤ 40 token) dặn vai trò `{role or 'agent'}` đừng lặp "
                      f"lại lỗi sau. Câu mệnh lệnh, cụ thể, không giải thích.\n"
                      f"Loại lỗi: {kind}\nChip: {chip or '—'}\nBằng chứng: {evidence[:1500]}",
                      _SCHEMA_NHAC)
        tho = (resp.data.get("negative_prompt") or tho).strip() or tho
    except EideError:
        pass
    while uoc_token(tho) > TRAN_TOKEN_NHAC and " " in tho:
        tho = tho.rsplit(" ", 1)[0]
    return tho


def _loi_can_tranh(root: Path, role: str) -> list[str]:
    """`negative_prompt` còn hạn của đúng vai trò ấy, mới nhất trước.

    Lọc theo vai trò vì lỗi của `librarian` không dạy được gì cho `coder` — trộn chúng làm ngữ
    cảnh mỗi vai trò đầy những điều không liên quan, và thứ không liên quan trong C1 thì tốn chỗ
    ở mọi lượt.
    """
    db = store.store_path(root)
    if not db.exists():
        return []
    now = datetime.now(UTC).isoformat()
    try:
        with store.open_store(db) as c:
            rows = c.execute(
                "SELECT negative_prompt FROM error_ledger WHERE role = ?"
                "   AND negative_prompt IS NOT NULL AND (ttl_until IS NULL OR ttl_until > ?)"
                " ORDER BY at DESC LIMIT ?", (role, now, SO_NHAC_TOI_DA)).fetchall()
    except EideError:
        return []
    return [r[0] for r in rows if r[0]]


# ---------------------------------------------------------------- MEMORY-07 forget


PHAM_VI_QUEN = ("cache", "session", "preference", "run")


@capability("memory.forget")
def forget(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-07 — CDS-12.6; MEM-11 §4.3; KAD-07 §6.7. Lỗi E1000; `undo: none`;
    ask "Xóa tri thức đã duyệt (R4)". tc: TC-MM-07.

    **"Không chạm M4"** — bước 1 nói thẳng, và đó là ranh giới của cả năng lực. M4 là tri thức
    đã qua G-FACT: bảng `fact`, `passport`. Một lệnh "quên cache" mà xoá luôn hộ chiếu là mất
    thứ tốn hàng giờ để dựng lại, trong khi người gõ lệnh đang nghĩ tới một thư mục tạm. Bốn
    phạm vi hợp lệ đều là thứ dựng lại được hoặc thuộc về phiên làm việc.

    `run` đang chạy → E1000: xoá nó để lại một tiến trình không còn chỗ ghi kết quả, mà nó vẫn
    đang gây hiệu ứng.
    """
    root = _goc(ctx)
    scope = params["scope"]
    key = params.get("key")
    if scope == "cache":
        return {"removed": _xoa_thu_muc(root / EIDE_DIR / "cache", key)}
    if scope == "session":
        return {"removed": _xoa_thu_muc(root / EIDE_DIR / "session", key)}

    db = store.store_path(root)
    with store.open_store(db) as c:
        if scope == "preference":
            cur = (c.execute("DELETE FROM preference WHERE key = ?", (key,)) if key
                   else c.execute("DELETE FROM preference"))
            n = cur.rowcount
        else:
            dang = c.execute("SELECT COUNT(*) FROM run WHERE state IN ('running','asked')"
                             + (" AND id = ?" if key else ""),
                             (key,) if key else ()).fetchone()[0]
            if dang:
                raise EideError("E1000", f"{dang} run đang chạy — dừng chúng trước khi quên "
                                "(xoá một run đang chạy để lại tiến trình không có chỗ ghi "
                                "kết quả)", running=dang)
            cur = (c.execute("DELETE FROM run WHERE id = ?", (key,)) if key
                   else c.execute("DELETE FROM run"))
            n = cur.rowcount
        c.commit()
    store.write_seal(db, ctx.extra.get("ledger"))
    return {"removed": int(n)}


def _xoa_thu_muc(d: Path, key: str | None) -> int:
    """Xoá TỆP trong thư mục, giữ lại chính thư mục: `.eide/cache/` biến mất thì lần ghi sau
    phải tự tạo lại, và không phải chỗ nào cũng nhớ làm điều đó."""
    if not d.is_dir():
        return 0
    n = 0
    for p in sorted(d.rglob("*"), key=lambda x: len(x.parts), reverse=True):
        if key and key not in p.name:
            continue
        if p.is_file():
            p.unlink()
            n += 1
        elif p.is_dir() and not any(p.iterdir()):
            p.rmdir()
    return n
