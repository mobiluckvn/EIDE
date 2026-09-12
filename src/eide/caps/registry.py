"""Namespace registry.* — CDS-12.5; KAD-07 §3; BEN-21.

Hiện thực ở đây: `registry.seed` (REGISTRY-01, M0) — nạp hàng loạt hộ chiếu từ một thư mục
`cmsis-svd-data` hoặc thư mục packs của hãng.

## Vì sao round-robin theo hãng

Bước 1 kết thúc bằng "round-robin theo hãng (M0 seed)", và đó không phải chi tiết trang trí.
Thư mục `cmsis-svd-data` có hơn 600 tệp, phần lớn là STMicroelectronics; nạp tuần tự theo tên
thư mục nghĩa là nếu người dùng dừng giữa chừng (Ctrl-C, hết đĩa, hết pin) thì họ có 400 hộ
chiếu ST và **không cái nào** của Nordic, Atmel, NXP. Xen kẽ theo hãng thì dừng ở đâu cũng còn
một tập đại diện dùng được.

Cùng lý do với việc `report` trả `per_vendor`: người chạy seed cần biết hãng nào hỏng, chứ
"n_fail: 37" thì không nói được gì.
"""
from __future__ import annotations

import itertools
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

DUOI = {"svd": (".svd",), "atdf": (".atdf",)}


@capability("registry.seed")
def seed(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REGISTRY-05 — CDS-12.5. tc: TC-42; undo `delete_created_files`.

    Một tệp hỏng KHÔNG dừng cả lô. Bộ `cmsis-svd-data` có vài chục tệp sai cú pháp hoặc thiếu
    thẻ, và dừng ở tệp thứ 12 nghĩa là 600 hộ chiếu còn lại không bao giờ được nạp vì một tệp
    mà người dùng chẳng cần. Ghi vào `per_vendor.fail` rồi đi tiếp — đó cũng là lý do `report`
    có `n_fail` chứ không phải một ngoại lệ.
    """
    d = Path(params["dir"]).expanduser()
    if not d.is_dir():
        raise EideError("E2000", f"Không có thư mục {d}", exists=[], candidates=[],
                        missing=[str(d)])
    loai = list(params.get("kinds") or ("svd", "atdf"))

    theo_hang: dict[str, list[tuple[Path, str]]] = {}
    for k in loai:
        for p in sorted(d.rglob("*")):
            if p.is_file() and p.suffix.lower() in DUOI[k]:
                theo_hang.setdefault(_hang(p, d), []).append((p, k))
    if not theo_hang:
        raise EideError("E2000", f"Không thấy tệp {'/'.join(loai)} nào trong {d}",
                        exists=[], candidates=[], missing=loai)

    from eide.caps.extract import atdf, svd
    ham = {"svd": svd, "atdf": atdf}
    bao: dict[str, dict[str, Any]] = {h: {"ok": 0, "fail": 0, "errors": []} for h in theo_hang}

    for hang, p, k in _xen_ke(theo_hang):
        try:
            ham[k]({"file": str(p)}, ctx)
            bao[hang]["ok"] += 1
        except (EideError, OSError, ValueError) as e:
            bao[hang]["fail"] += 1
            if len(bao[hang]["errors"]) < 5:      # giữ vài mẫu, không giữ 600 dòng giống nhau
                bao[hang]["errors"].append({"file": p.name, "error": str(e)[:160]})

    return {"report": {"n_ok": sum(v["ok"] for v in bao.values()),
                       "n_fail": sum(v["fail"] for v in bao.values()),
                       "per_vendor": bao}}


def _hang(p: Path, goc: Path) -> str:
    """Hãng = thư mục con đầu tiên dưới gốc. `cmsis-svd-data/data/STMicro/…` → `STMicro`.

    Đoán từ cấu trúc thư mục chứ không mở tệp: `<vendor>` bên trong SVD chính xác hơn nhưng đọc
    600 tệp XML chỉ để xếp lịch thì tốn hơn cả việc nạp. Xếp nhầm một hãng chỉ làm thứ tự xen kẽ
    lệch đi, không làm sai hộ chiếu nào.
    """
    try:
        rel = p.relative_to(goc).parts
    except ValueError:
        return "khác"
    for x in rel[:-1]:
        if x.lower() not in ("data", "packs", "svd", "atdf", "cmsis"):
            return x
    return "khác"


def _xen_ke(theo_hang: dict[str, list[tuple[Path, str]]]) -> list[tuple[str, Path, str]]:
    """Round-robin: lấy một tệp mỗi hãng, xoay vòng cho tới hết.

    `zip_longest` với `fillvalue=None` rồi lọc — hãng ít tệp cạn trước, hãng nhiều tệp chạy
    tiếp, và thứ tự vẫn xen kẽ tối đa có thể.
    """
    ds = sorted(theo_hang)
    return [(h, p, k)
            for hang_row in itertools.zip_longest(*(theo_hang[h] for h in ds))
            for h, x in zip(ds, hang_row, strict=True) if x is not None
            for p, k in (x,)]


# ================================================================ M4 — registry CỤC BỘ
#
# PKG-22 mô tả một registry là nơi "git push" gói lên. Hiện thực ở đây dựng nó thành một THƯ
# MỤC — mặc định `<user_data>/registry`, đổi được bằng `EIDE_REGISTRY`.
#
# Vì sao thế là đủ, và vì sao nó không phải một bản giả:
#
# - Định dạng `.hkp` là THẬT: cùng `manifest.json` + `manifest.sig` mà `env.install_pack` đã
#   đọc từ Sprint 2. Một gói đóng ở đây cài được bằng năng lực đã có, không qua đường riêng.
# - Chữ ký là THẬT: băm nội dung các tệp trong manifest, cùng phép kiểm của `_kiem_chu_ky`.
# - Cái duy nhất "cục bộ" là VẬN CHUYỂN. Thay một thư mục bằng một git remote thì bốn năng lực
#   này không đổi một dòng — chỉ `_kho()` đổi.
#
# Làm ngược lại — chờ có registry thật rồi mới viết — thì bốn năng lực M4 nằm chờ một hạ tầng
# ngoài phạm vi đề án, và phần đáng kiểm nhất của chúng (chữ ký, license, không rò K3/K6) không
# bao giờ được kiểm.

TEP_MANIFEST = "manifest.json"
TEP_CHU_KY = "manifest.sig"
TEP_INDEX = "index.json"

# Khoá K3/K6 KHÔNG được rời dự án. K3 là ngữ cảnh riêng, K6 là ràng buộc dự án — một gói mang
# chúng đi là mang bí mật của một dự án sang máy người khác. REGISTRY-03 bước 1 nói thẳng
# "không chứa K3/K6 dự án", và đây là chỗ phép kiểm ấy sống.
KHOA_CAM = ("constraints", "autonomy", "preferences", "target", "secrets", "tools.lock")

# License cho phép đóng gói. Ngoài danh sách này thì E8001 — không phải vì chúng "xấu", mà vì
# gói đi ra ngoài mang theo nghĩa vụ pháp lý mà người nhận không đọc.
LICENSE_DONG_GOI = ("MIT", "BSD-2-Clause", "BSD-3-Clause", "Apache-2.0", "CC-BY-4.0",
                    "vendor-doc")


def _kho() -> Path:
    import os

    from eide_core.paths import user_data
    return Path(os.environ.get("EIDE_REGISTRY") or (user_data() / "registry")).expanduser()


def _doc_index() -> list[dict[str, Any]]:
    f = _kho() / TEP_INDEX
    if not f.is_file():
        return []
    import json
    try:
        d = json.loads(f.read_text(encoding="utf-8"))
    except ValueError:
        return []
    return d.get("packages", d) if isinstance(d, dict) else list(d)


def _ghi_index(ds: list[dict[str, Any]]) -> None:
    import json
    kho = _kho()
    kho.mkdir(parents=True, exist_ok=True)
    (kho / TEP_INDEX).write_text(
        json.dumps({"packages": sorted(ds, key=lambda x: x.get("id", ""))},
                   ensure_ascii=False, indent=1), encoding="utf-8")


def _bam_goi(thu_muc: Path, files: list[str]) -> str:
    import hashlib
    h = hashlib.sha256()
    for ten in sorted(files):
        p = thu_muc / ten
        if p.is_file():
            h.update(p.read_bytes())
    return h.hexdigest()


@capability("registry.search")
def search(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REGISTRY-01 — CDS-12.5. R0, `errors: []`, `undo: none`.
    tc: "Tìm thấy passport + skill".

    Registry không tới được → trả RỖNG, không ném. Một máy chưa từng `registry.publish` thì
    chưa có `index.json`, và đó là trạng thái bình thường chứ không phải lỗi — cùng lý do
    SEARCH-01 ghi "registry không tới được → trả rỗng + cảnh báo".

    Xếp theo BADGE trước rồi mới tới điểm khớp chuỗi: một hộ chiếu `verified_on_board` đáng tin
    hơn một hộ chiếu trùng tên hơn một ký tự. Badge là thứ đắt nhất để có được trong cả hệ
    thống — nó đòi một lần nạp firmware lên board thật.
    """
    q = str(params["q"]).lower().strip()
    ra = []
    for g in _doc_index():
        diem = _diem_khop(q, g)
        if diem > 0:
            ra.append({**g, "score": diem})
    ra.sort(key=lambda x: (-len(x.get("badges") or []), -x["score"], x.get("id", "")))
    return {"packages": ra}


def _diem_khop(q: str, g: dict[str, Any]) -> float:
    if not q:
        return 1.0
    ten = str(g.get("id", "")).lower()
    tu = " ".join([ten, str(g.get("mpn", "")), " ".join(g.get("keywords") or [])]).lower()
    if q == ten.split("@")[0]:
        return 3.0
    if q in ten:
        return 2.0
    return 1.0 if q in tu else 0.0


@capability("registry.pack")
def pack(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REGISTRY-03 — CDS-12.5; PKG-22 (manifest, chữ ký). R1, `errors: [E8001]`,
    `undo: none`. tc: TC-41.

    **Con trỏ nguồn, KHÔNG phải PDF.** Bước 1 của hợp đồng nói thế, và lý do là giấy phép: một
    datasheet của hãng thường cấm phát tán lại, còn một `source.uri` kèm `sha256` thì không
    mang theo nội dung nào cả — người nhận tự tải từ hãng và kiểm băm. Gói vì thế nhỏ và hợp
    pháp, đổi lại người nhận phải online một lần.

    **Không rò K3/K6.** `constraints.yaml` mang ràng buộc dự án, `autonomy.yaml` mang mức tự chủ
    và danh sách trắng ĐÃ KÝ — một gói mang chúng đi là mang cấu hình an toàn của một dự án sang
    máy người khác. E8001 nếu chạm phải, và phép kiểm chạy trên TÊN TỆP đã gom chứ không trên ý
    định của người gọi.

    License ngoài danh sách → E8001. Không phải vì chúng xấu, mà vì một gói đi ra ngoài mang
    theo nghĩa vụ pháp lý mà người nhận không đọc.
    """
    import json

    from eide.caps.project import EIDE_DIR, _root

    root = _root(ctx)
    pid = str(params["id"])
    gom = list(params.get("include") or ["passport"])

    files: list[str] = []
    tam = root / EIDE_DIR / "packs" / "_build" / pid.replace("/", "_").replace("@", "_")
    tam.mkdir(parents=True, exist_ok=True)

    facts, nguon, lic = _gom_fact(root, pid)
    if not facts:
        raise EideError("E2000", f"Không có fact nào thuộc `{pid}` để đóng gói",
                        exists=[], candidates=["extract.svd", "passport.import"], missing=[pid])
    xau = sorted(x for x in lic if x and x not in LICENSE_DONG_GOI)
    if xau:
        raise EideError("E8001", f"Không đóng gói được: {len(xau)} nguồn có license ngoài danh "
                        f"sách cho phép ({xau[:3]}). Gói đi ra ngoài mang theo nghĩa vụ pháp lý "
                        "mà người nhận không đọc.", licenses=xau)

    if "passport" in gom:
        (tam / "facts.json").write_text(
            json.dumps({"facts": facts, "sources": nguon}, ensure_ascii=False, indent=1),
            encoding="utf-8")
        files.append("facts.json")
    if "skills" in gom:
        n = _chep(root / EIDE_DIR / "skills", tam / "skills", files, "skills")
        if not n:
            files = [f for f in files if not f.startswith("skills/")]
    if "bench" in gom:
        _chep(root / EIDE_DIR / "bench", tam / "bench", files, "bench")

    ro = [f for f in files if any(k in Path(f).name.lower() for k in KHOA_CAM)]
    if ro:
        raise EideError("E8001", f"Gói chứa cấu hình riêng của dự án (K3/K6): {ro} — "
                        "REGISTRY-03 cấm mang chúng ra ngoài", files=ro)

    # Phiên bản lấy từ HỘ CHIẾU trong store, không nhận qua tham số: REGISTRY-03 `input_schema`
    # chỉ cho `id` và `include` (`additionalProperties: false`), nên một tham số `version` sẽ bị
    # Router chặn bằng E1000 trước khi tới đây — một nhánh chết trông như một tính năng.
    man = {"id": pid, "version": _ban(root, pid), "kind": "passport",
           "license": sorted({x for x in lic if x}), "files": sorted(files),
           "n_facts": len(facts), "badges": _badge(root, pid),
           "created_at": datetime.now(UTC).isoformat()}
    (tam / TEP_MANIFEST).write_text(json.dumps(man, ensure_ascii=False, indent=1),
                                    encoding="utf-8")
    (tam / TEP_CHU_KY).write_text(_bam_goi(tam, man["files"]), encoding="utf-8")

    if (led := ctx.extra.get("ledger")) is not None:
        led.append("store.write", {"batch_id": pid, "n_facts": len(facts), "n_conflicts": 0,
                                   "actor": ctx.actor or "agent",
                                   "reason": f"registry.pack {pid}"})
    return {"file": str(tam), "manifest": man}


def _chep(nguon: Path, dich: Path, files: list[str], tien_to: str) -> int:
    if not nguon.is_dir():
        return 0
    n = 0
    for p in sorted(nguon.rglob("*")):
        if p.is_file():
            ra = dich / p.relative_to(nguon)
            ra.parent.mkdir(parents=True, exist_ok=True)
            ra.write_bytes(p.read_bytes())
            files.append(f"{tien_to}/{p.relative_to(nguon)}")
            n += 1
    return n


def _gom_fact(root: Path, pid: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], set[str]]:
    """Fact của một hộ chiếu + CON TRỎ nguồn (uri + sha256), không kèm nội dung nguồn."""
    import json

    from eide_core import store
    db = store.store_path(root)
    if not db.exists():
        return [], [], set()
    goc = pid.split("@")[0]
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT id, subject, predicate, value, unit, source_id, method, tier, confidence,"
            " status FROM fact WHERE status IN ('reviewed','verified')"
            "   AND (subject = ? OR subject LIKE ?) ORDER BY id", (goc, f"%{goc}%")).fetchall()
        facts = [{"id": r[0], "subject": r[1], "predicate": r[2],
                  "value": json.loads(r[3]) if r[3] else None, "unit": r[4],
                  "source_id": r[5], "method": r[6], "tier": r[7], "confidence": r[8],
                  "status": r[9]} for r in rows]
        sids = sorted({f["source_id"] for f in facts if f["source_id"]})
        nguon, lic = [], set()
        if sids:
            q = ",".join("?" * len(sids))
            for sid, uri, sha, kind, tier, li in c.execute(
                    f"SELECT id, uri, sha256, kind, tier, license FROM source WHERE id IN ({q})",
                    sids).fetchall():
                nguon.append({"id": sid, "uri": uri, "sha256": sha, "kind": kind, "tier": tier,
                              "license": li})
                lic.add(li)
    return facts, nguon, lic


def _ban(root: Path, pid: str) -> str:
    """Phiên bản hộ chiếu trong store (`ns.part@semver`), mặc định `1.0.0`."""
    from eide_core import store
    if "@" in pid:
        return pid.split("@", 1)[1]
    db = store.store_path(root)
    if not db.exists():
        return "1.0.0"
    with store.open_store(db) as c:
        r = c.execute("SELECT id FROM passport WHERE id LIKE ? ORDER BY id DESC LIMIT 1",
                      (f"{pid}@%",)).fetchone()
    return r[0].split("@", 1)[1] if r and "@" in r[0] else "1.0.0"


def _badge(root: Path, pid: str) -> list[str]:
    import json

    from eide_core import store
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        r = c.execute("SELECT badges FROM passport WHERE id = ? OR id LIKE ?",
                      (pid, f"{pid.split('@')[0]}%")).fetchone()
    return json.loads(r[0]) if r and r[0] else []


@capability("registry.publish", features=["op", "scope"])
def publish(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REGISTRY-04 — CDS-12.5; POL-17 G5. **R2/R4**, tier T1*, `errors: [E3000, E4004]`,
    `undo: none`. tc: S38/S39.

    **`internal` tự động, `public` HỎI NGƯỜI** — bước 1 của hợp đồng, và ranh giới ấy là toàn bộ
    lý do năng lực này là T1* chứ không phải T1. Phát hành nội bộ là chia sẻ trong nhóm; phát
    hành công khai là một hành động không rút lại được, vì người khác đã tải về rồi.

    Gói chưa `pack` → E4004 kèm năng lực cần chạy. Không tự pack hộ: `registry.pack` có phép
    kiểm license và K3/K6 riêng, và chạy nó ngầm bên trong đây sẽ làm một lần phát hành bỏ qua
    hai phép kiểm ấy mà không ai thấy.
    """
    import json

    thu_muc = Path(params["pkg"]).expanduser()
    if not (thu_muc / TEP_MANIFEST).is_file():
        raise EideError("E4004", f"`{thu_muc}` chưa phải một gói — chạy `registry.pack` trước",
                        candidates=["registry.pack"], missing=[TEP_MANIFEST], exists=[])
    man = json.loads((thu_muc / TEP_MANIFEST).read_text(encoding="utf-8"))

    if params["scope"] == "public" and ctx.actor != "human":
        raise EideError("E3000", f"Phát hành CÔNG KHAI gói `{man['id']}` — không rút lại được "
                        "khi người khác đã tải. Cần người xác nhận.",
                        gate_id="G5", scope="public", pkg=man["id"])

    dich = _kho() / f"{man['id'].replace('/', '_')}@{man['version']}"
    dich.mkdir(parents=True, exist_ok=True)
    for ten in [TEP_MANIFEST, TEP_CHU_KY, *man.get("files", [])]:
        src = thu_muc / ten
        if src.is_file():
            (dich / ten).parent.mkdir(parents=True, exist_ok=True)
            (dich / ten).write_bytes(src.read_bytes())

    idx = [g for g in _doc_index() if g.get("id") != f"{man['id']}@{man['version']}"]
    idx.append({"id": f"{man['id']}@{man['version']}", "kind": man.get("kind", "passport"),
                "badges": man.get("badges") or [], "license": man.get("license") or [],
                "n_facts": man.get("n_facts", 0), "scope": params["scope"],
                "path": str(dich), "published_at": datetime.now(UTC).isoformat()})
    _ghi_index(idx)

    if (led := ctx.extra.get("ledger")) is not None:
        led.append("store.write", {"batch_id": man["id"], "n_facts": 0, "n_conflicts": 0,
                                   "actor": ctx.actor or "agent",
                                   "reason": f"registry.publish scope={params['scope']}"})
    return {"published": True, "url": dich.as_uri()}


@capability("registry.pull")
def pull(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REGISTRY-02 — CDS-12.5; PKG-22. R1, `errors: [E8001, E4004, E6001]`,
    `undo: none`. tc: TC-43.

    **Kiểm chữ ký TRƯỚC khi nạp một fact nào.** Một gói đã bị sửa mang theo những con số mà mã
    sinh ra sẽ trích dẫn — nạp nửa chừng rồi mới phát hiện thì store đã có fact bẩn mang nhãn
    `verified`. Đó là lý do phép kiểm đứng trước vòng lặp chứ không trong nó.

    Fact nạp vào giữ nguyên `source_id` và con trỏ nguồn, nhưng **hạ `status` xuống
    `reviewed`**: chúng đã được ai đó duyệt, ở một dự án khác, trên một con chip có thể khác
    lô. Giữ `verified` là mượn lòng tin của người khác cho ngữ cảnh của mình — mà `verified`
    trong KAD-07 nghĩa là "đã đo trên board này".
    """
    import json

    from eide.caps.project import _root
    from eide_core import store

    pid = str(params["id"])
    thu_muc = _kho() / pid.replace("/", "_")
    if not (thu_muc / TEP_MANIFEST).is_file():
        co = [p.name for p in _kho().glob("*")] if _kho().is_dir() else []
        raise EideError("E4004", f"Registry không có gói `{pid}` (kho: {_kho()})",
                        candidates=["registry.search"], missing=[pid], exists=co)
    man = json.loads((thu_muc / TEP_MANIFEST).read_text(encoding="utf-8"))

    sig = thu_muc / TEP_CHU_KY
    if not sig.is_file():
        raise EideError("E8001", f"Gói `{pid}` không có chữ ký — không kiểm được toàn vẹn",
                        pkg=pid)
    if _bam_goi(thu_muc, man.get("files") or []) != sig.read_text(encoding="utf-8").strip():
        raise EideError("E8001", f"Chữ ký gói `{pid}` không khớp nội dung — gói đã bị sửa sau "
                        "khi ký. Không nạp fact nào.", pkg=pid)

    xau = [x for x in (man.get("license") or []) if x and x not in LICENSE_DONG_GOI]
    if xau:
        raise EideError("E8001", f"Gói `{pid}` có license ngoài danh sách cho phép: {xau}",
                        licenses=xau)

    root = _root(ctx)
    f = thu_muc / "facts.json"
    if not f.is_file():
        raise EideError("E6001", f"Gói `{pid}` khai `passport` nhưng không có `facts.json`",
                        pkg=pid)
    noi_dung = json.loads(f.read_text(encoding="utf-8"))
    n = 0
    with store.open_store(store.store_path(root)) as c:
        for s in noi_dung.get("sources") or []:
            c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                      " VALUES (?,?,?,?,?,?)",
                      (s["id"], s["uri"], s["sha256"], s.get("kind"), s.get("tier"),
                       s.get("license")))
        for x in noi_dung.get("facts") or []:
            c.execute(
                "INSERT OR IGNORE INTO fact (id,subject,predicate,value,unit,source_id,method,"
                "tier,confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (x["id"], x["subject"], x["predicate"], json.dumps(x["value"]), x.get("unit"),
                 x.get("source_id"), x.get("method"), x.get("tier"), x.get("confidence"),
                 "reviewed", "B"))
            n += c.total_changes and 1 or 0
        c.commit()
    store.write_seal(store.store_path(root), ctx.extra.get("ledger"))

    from eide.caps.passport import _ghim_moi
    goc, _, ban = pid.partition("@")
    _ghim_moi(root, goc, ban or man.get("version", "1.0.0"))
    return {"pinned": pid, "facts": len(noi_dung.get("facts") or [])}
