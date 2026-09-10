"""Namespace search.* — CDS-12.2 (tập Tri thức); TGT-19 §8 (bảng nguồn hãng); POL-17 cổng G-SRC.

Hiện thực ở đây: `search.vendor`, `search.rank`, `search.fetch`, `search.verify_match`,
`search.missing`. `search.web` hoãn — nó cần một API tìm kiếm cấu hình được, còn `search.vendor`
tra thẳng trang hãng đã phủ phần lớn nhu cầu thật (STM32, AVR/PIC, nRF, ESP, RP2040, và các cảm
biến Bosch/InvenSense/Allegro mà tài liệu nêu đích danh).

## Nhóm này là lần đầu cổng G-SRC có việc

Tám quy tắc G-SRC nằm trong `rules.yaml` từ Sprint 1 và **chưa quy tắc nào từng chạy** — mọi
fact trong store tới giờ đều đến từ tệp cục bộ. `search.fetch` là năng lực đầu tiên đi qua cổng
ấy, và nó canh đúng thứ đáng canh: tải cái gì, từ tên miền nào, giấy phép gì, to bao nhiêu.

Thứ tự trong `search.fetch` không đảo được: **hỏi cổng TRƯỚC khi tải**. Tải rồi mới hỏi thì byte
đã qua mạng, đã nằm trên đĩa, và câu trả lời "không được phép" đến sau khi việc cần ngăn đã xảy
ra. Đó cũng là lý do `search.vendor` chỉ HEAD chứ không GET: biết kích thước để cổng quyết, mà
chưa tải gì.
"""
from __future__ import annotations

import hashlib
import json
import re
import urllib.error
import urllib.request
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import yaml

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.paths import spec_dir
from eide_core.registry import capability
from eide_core.router import Context

# SEARCH-03 bước 1, nguyên văn: "tier dự kiến (gold 3, silver 2, bronze 1) + domain tin cậy (+2)
# + hash/signature (+2) + license rõ (+1) + khớp mã linh kiện trong tiêu đề (+2) + mới hơn
# (+0,5)". Đặt tên cho từng số để đổi trọng số là sửa MỘT chỗ, không phải dò trong biểu thức.
DIEM_TIER = {"gold": 3.0, "silver": 2.0, "bronze": 1.0}
DIEM = {"domain": 2.0, "hash": 2.0, "license": 1.0, "khop_ma": 2.0, "moi_hon": 0.5}

TIMEOUT_S = 20
# CHỈ ASCII: header HTTP mã hóa latin-1, nên một chữ có dấu làm `http.client` ném
# UnicodeEncodeError trước cả khi gói tin rời máy — mọi lời gọi mạng hỏng, không riêng test.
UA = "EIDE/0.1 (PTIT master thesis project)"

# SEC-25 §4: nhận diện giấy phép từ nội dung. Chỉ vài mẫu chắc chắn — đoán bừa giấy phép còn
# tệ hơn `unknown`, vì `unknown` rơi vào G-SRC-05 (ASK) còn đoán sai thì tự duyệt.
MAU_LICENSE = (
    (r"\bApache License,?\s+Version 2\.0", "Apache-2.0"),
    (r"\bMIT License\b", "MIT"),
    (r"Redistribution and use in source and binary forms.{0,400}?3\. Neither the name", "BSD-3-Clause"),
    (r"Redistribution and use in source and binary forms", "BSD-2-Clause"),
    (r"Creative Commons Attribution 4\.0", "CC-BY-4.0"),
)


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm search.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def bang_hang() -> list[dict[str, Any]]:
    """Bảng nguồn hãng, sinh từ TGT-19 §8 ra `docs/spec/sources/vendors.yaml`.

    Đọc từ spec chứ không khai trong Python: bảng ấy đã in trong tài liệu, và một bản chép tay
    thứ hai sẽ trôi khỏi bản in ngay lần hãng đổi đường dẫn — đúng loại lỗi mà DEV-043 và
    DEV-046 đã ghi hai lần.
    """
    f = spec_dir() / "sources" / "vendors.yaml"
    if not f.exists():
        raise EideError("E2000", "Thiếu docs/spec/sources/vendors.yaml (sinh từ TGT-19 §8) — "
                        "chạy `scripts/sinh_tai_lieu.sh tgt_sim`",
                        exists=[], candidates=[], missing=[str(f)])
    return (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("vendors") or []


# ---------------------------------------------------------------- SEARCH-02 vendor


@capability("search.vendor")
def vendor(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SEARCH-02 — CDS-12.2; TGT-19 §8. Trả `uri, kind, domain, size_est, license_hint`.

    Bước 2 nói rõ: "HEAD để lấy kích thước; KHÔNG tải". Ràng buộc ấy là lý do năng lực này tách
    khỏi `search.fetch`: liệt kê ứng viên phải rẻ và không có hệ quả, để tác tử chạy được tự do
    ở mọi mức tự chủ. Trộn tải vào đây thì mỗi lần "xem có gì" là một lần tải 40 MB — và cổng
    G-SRC mất chỗ đứng, vì nó chỉ có nghĩa khi có một bước riêng để chặn.

    Không gọi được mạng thì vẫn TRẢ ứng viên, `size_est = None`. Danh sách URL suy từ mã linh
    kiện có ích cả khi ngoại tuyến — người dùng chép đường dẫn và tự tải.
    """
    part = params["part"]
    ra = []
    for v in bang_hang():
        if not any(re.match(p, part, re.I) for p in (v.get("prefixes") or [])):
            continue
        for u in v.get("urls") or []:
            uri = _dien(u["template"], part, v)
            ra.append({"uri": uri, "kind": u["kind"], "domain": urlparse(uri).netloc,
                       "vendor": v["id"], "tier_expected": u["tier"],
                       # Giấy phép lấy từ BẢNG, không suy từ tầng: cmsis-svd-data là
                       # Apache-2.0, tài liệu hãng là vendor-doc — hai thứ khác nhau, và
                       # suy sai thì G-SRC-05 hỏi người ở đúng đường phổ biến nhất.
                       "license_hint": u.get("license"),
                       "note": u.get("note"), **_head(uri)})
    return {"candidates": ra}


def _dien(mau: str, part: str, v: dict[str, Any]) -> str:
    """Điền chỗ trống trong mẫu URL.

    Giữ CẢ `{part_upper}` lẫn `{part_lower}` vì hãng không thống nhất: ST dùng chữ thường trong
    đường dẫn PDF nhưng chữ hoa trong tên tệp SVD. Chuẩn hóa về một kiểu ở đây sẽ làm hỏng một
    nửa số mẫu, và triệu chứng là 404 — trông y hệt "hãng bỏ tài liệu này".
    """
    ho = re.match(r"^([A-Za-z]+)", part)
    return (mau.replace("{part_base}", _die(part))
               .replace("{part_upper}", part.upper())
               .replace("{part_lower}", part.lower())
               .replace("{part}", part)
               .replace("{family}", (ho.group(1) if ho else part).upper())
               .replace("{vendor}", v.get("name", v["id"]).split()[0]))


def _die(part: str) -> str:
    """Mã DIE — cắt hậu tố mã vỏ/dải nhiệt. `STM32F411CE` → `STM32F411`.

    Tệp SVD mô tả một die, không mô tả một mã hàng: `STM32F411CE` (LQFP48) và `STM32F411RE`
    (LQFP64) dùng chung `STM32F411.svd`. Dùng thẳng mã hàng thì 404 — đo được bằng test `net`,
    và đó là lý do test ấy tồn tại: một mẫu URL sai vẫn trông hoàn toàn hợp lý trong YAML.

    Cắt tối đa hai chữ cái cuối SAU một cụm số, không cắt chữ trong tên họ (`nRF52840` giữ
    nguyên vì nó kết thúc bằng số).
    """
    return re.sub(r"(?<=\d)[A-Za-z]{1,2}$", "", part).upper()


def _head(uri: str) -> dict[str, Any]:
    """HEAD: kích thước và kiểu nội dung, không tải thân. `size_est=None` = chưa hỏi được."""
    req = urllib.request.Request(uri, method="HEAD", headers={"User-Agent": UA})  # noqa: S310
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as r:  # noqa: S310
            n = int(r.headers.get("Content-Length") or 0)
            return {"size_est": n or None, "content_type": r.headers.get("Content-Type"),
                    "reachable": True}
    except (urllib.error.URLError, OSError, ValueError):
        return {"size_est": None, "content_type": None, "reachable": False}


# ---------------------------------------------------------------- SEARCH-05 rank


@capability("search.rank")
def rank(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SEARCH-05 — CDS-12.2. Công thức chấm điểm nguyên văn ở bước 1.

    Trả `reasons` cho từng ứng viên, không chỉ con số. Bảng xếp hạng chỉ có điểm thì khi nó chọn
    sai, người dùng không biết sửa gì — còn "+2 vì tên miền tin cậy; KHÔNG được +2 vì tiêu đề
    không chứa mã linh kiện" thì họ thấy ngay là mình gõ nhầm mã.
    """
    part = (params.get("part") or "").lower()
    tin_cay = _trusted(ctx)
    ra = []
    for c in params["candidates"]:
        diem = DIEM_TIER.get(c.get("tier_expected", "bronze"), 1.0)
        vi = [f"+{diem:g} tầng dự kiến {c.get('tier_expected', 'bronze')}"]
        for co, khoa, ly in (
            (_domain_tin_cay(c.get("domain") or "", tin_cay), "domain", "tên miền tin cậy"),
            (bool(c.get("sha256") or c.get("signature_valid")), "hash", "có hash/chữ ký"),
            (bool(c.get("license") or c.get("license_hint")), "license", "giấy phép rõ"),
            (bool(part) and part in (c.get("title") or c.get("uri") or "").lower(),
             "khop_ma", "khớp mã linh kiện"),
            (bool(c.get("newer")), "moi_hon", "mới hơn bản đang có"),
        ):
            if co:
                diem += DIEM[khoa]
                vi.append(f"+{DIEM[khoa]:g} {ly}")
        ra.append({**c, "score": round(diem, 2), "reasons": vi})
    ra.sort(key=lambda x: -x["score"])
    return {"ranked": ra}


def _domain_tin_cay(domain: str, tin_cay: list[str]) -> bool:
    """Khớp theo HẬU TỐ tên miền, không so bằng — nhưng chặn ở biên dấu chấm.

    So bằng thì `raw.githubusercontent.com` và `www.st.com` đều trượt, và mọi tải về rơi vào
    G-SRC-99 (ASK): người dùng bấm duyệt liên tục rồi thôi đọc, đúng thứ POL-17 muốn tránh.

    Nhưng hậu tố ngây thơ (`endswith("st.com")`) thì `evil-st.com` cũng khớp — lỗ hổng kinh
    điển. Phải là `== t` hoặc `endswith("." + t)`.
    """
    d = domain.lower().removeprefix("www.")
    for t in tin_cay:
        t = t.lower().split("/")[0]          # `github.com/cmsis-svd` → `github.com`
        if d == t or d.endswith("." + t):
            return True
    return False


def _trusted(ctx: Context) -> list[str]:
    g = ctx.extra.get("gate")
    cfg = getattr(g, "config", None) if g is not None else None
    if isinstance(cfg, dict) and cfg.get("trusted_sources"):
        return list(cfg["trusted_sources"])
    d = yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8")) or {}
    return list(d.get("trusted_sources") or [])


def _chuan_hoa_domain(uri: str) -> str:
    return (urlparse(uri).hostname or "").lower().removeprefix("www.")


def _kind_chinh_sach(candidate: dict[str, Any]) -> str | None:
    """Đổi `kind` sang từ vựng CỦA CHÍNH SÁCH. Hai bảng, hai mục đích, và chúng KHÔNG trùng nhau.

    - `Source.kind` (DDD-14 §2) mô tả ĐỊNH DẠNG: `svd`, `atdf`, `pdf`, `html`, `image`…
    - `G-SRC-01` khai `source.kind in ["svd","atdf","edc","binding","pdf_vendor"]` — `pdf_vendor`
      không phải một định dạng mà là một PHÁN XÉT: "PDF lấy từ chính trang hãng".

    Phân biệt ấy có lý: một PDF từ st.com và một PDF từ diễn đàn cùng định dạng nhưng khác hẳn
    mức tin cậy, và chính sách quan tâm cái sau. Dùng thẳng `pdf` cho cả hai thì mọi datasheet
    hãng đều rơi vào G-SRC-99 (ASK) — tôi mất một lúc mới thấy, vì đặc trưng nào cũng trông đúng.

    Ghi vào store vẫn là `pdf`: bảng `source` theo enum của DDD-14, không theo từ vựng chính sách.
    """
    k = candidate.get("kind")
    if k == "pdf" and candidate.get("vendor"):
        return "pdf_vendor"
    return k


def dac_trung_nguon(candidate: dict[str, Any]) -> dict[str, Any]:
    """Đặc trưng `source.*` cho cổng G-SRC, dựng từ một ứng viên.

    **G-SRC là cổng do ROUTER áp**, không phải do năng lực tự gọi — cùng lý do với G-OPS, G3,
    G5: hiện vật (`source`) đã tồn tại TRƯỚC lời gọi, nên cổng quyết được mà không cần chạy
    năng lực. Ngược lại G-FACT và G1 canh thứ năng lực SINH RA, nên chúng được hỏi bên trong.
    Bản đầu tôi gọi `gate.decide` ngay trong `search.fetch` — thành gác hai lần, và lần của
    Router chạy trước với đặc trưng rỗng nên mọi lời gọi đều rơi vào G-SRC-99 (ASK).

    Bên gọi truyền kết quả hàm này qua `router.invoke(..., features=...)`. Đặt ở đây để chỉ có
    MỘT cách dựng: hai chỗ tự map `candidate → source.*` là hai chỗ sẽ quên một trường, và
    trường quên thì `_Ns` trả None ⇒ không khớp quy tắc APPROVE nào ⇒ hỏi người. An toàn, nhưng
    hỏi vì lý do sai thì người duyệt học cách bấm bừa.

    Không truyền gì cũng an toàn: mọi đặc trưng là None thì G-SRC-99 bắt hết và ra ASK.
    """
    uri = candidate.get("uri") or candidate.get("url") or ""
    kt = candidate.get("size_est")
    return {"source": {
        # `hostname` chứ không `netloc`: netloc mang cả cổng, nên `st.com:443` trượt khỏi
        # `trusted_sources` — mà quy tắc G-SRC-01 khớp CHÍNH XÁC (`domain in trusted_sources`),
        # không khớp hậu tố. Bỏ `www.` cùng lý do: danh sách trắng ghi `st.com`, không ghi cả
        # hai biến thể, và bắt người ký liệt kê từng biến thể là mời họ liệt kê thiếu.
        "domain": _chuan_hoa_domain(uri),
        "size_mb": round(kt / 1024**2, 4) if kt else None,
        "license": candidate.get("license") or candidate.get("license_hint"),
        "kind": _kind_chinh_sach(candidate),
        "expected_hash": candidate.get("expected_hash"),
        "hash_match": candidate.get("hash_match"),
        "match_score": candidate.get("match_score"),
        "signature_valid": candidate.get("signature_valid"),
        "requires_upload": candidate.get("requires_upload"),
    }}


# ---------------------------------------------------------------- SEARCH-06 fetch


@capability("search.fetch")
def fetch(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SEARCH-06 — CDS-12.2; POL-17 G-SRC; SEC-25 §4. Lỗi: E3000, E3001, E8001, E4004.

    Ba bước, và **thứ tự không đảo được**:

    1. `policy.decide(G-SRC)` với đặc trưng domain/size/license/kind/hash.
    2. Tải vào `cache/`, băm, so `expected_hash`.
    3. Nhận diện giấy phép, tạo `Source`, ghi ledger.

    Hỏi cổng TRƯỚC khi tải là điểm chính. Tải rồi mới hỏi thì byte đã qua mạng, đã nằm trên đĩa,
    và câu trả lời "không được phép" tới sau khi việc cần ngăn đã xảy ra — cổng thành một thủ
    tục ghi sổ thay vì một phép chặn.

    `expected_hash` lệch thì XÓA tệp rồi mới báo E3001. Giữ lại "để người xem" nghe hợp lý nhưng
    sai: một tệp không đúng băm là một tệp không rõ nguồn gốc, và để nó trong cache là mời bước
    sau nhặt nhầm.
    """
    from eide_core.policy import PolicyGate
    c = params["candidate"]
    uri = c.get("uri") or c.get("url")
    if not uri:
        raise EideError("E1000", "candidate thiếu `uri`", candidate=c)
    root = _root(ctx)
    gate = ctx.extra.get("gate") or PolicyGate()

    cache = root / EIDE_DIR / "cache" / "downloads"
    cache.mkdir(parents=True, exist_ok=True)
    f = cache / _ten_tep(uri)
    n, h = _tai(uri, f, gate)

    if (mong := c.get("expected_hash")) and mong != h:
        f.unlink(missing_ok=True)
        raise EideError("E3001", f"Băm lệch: chờ {mong[:16]}…, nhận {h[:16]}… — tệp đã xóa",
                        uri=uri, expected=mong, got=h)

    lic = c.get("license") or _nhan_dien_license(f) or c.get("license_hint") or "unknown"
    sid = _ghi_source(root, f, uri, h, n, c.get("kind"), lic, c.get("tier_expected"))
    if (led := ctx.extra.get("ledger")) is not None:
        # Không chép lại `rule` của quyết định: Router đã ghi nó vào `decision_log` và vào sự
        # kiện `cap.run.start` cùng `run_id`. Chép sang đây là bản thứ hai của cùng một sự thật,
        # và bản thứ hai chỉ có giá trị khi nó không bao giờ lệch — điều không ai bảo đảm được.
        # `store.write` chứ không `source.add`: API-15 §5 khai một bảng ĐÓNG các loại sự kiện,
        # và `Ledger.append` từ chối loại lạ (E6001). Bịa thêm loại là làm hỏng khả năng đọc
        # nhật ký bằng công cụ — mọi bên đọc đều phải biết trước tập loại.
        led.append("store.write", {"batch_id": sid, "n_facts": 0, "n_conflicts": 0,
                                   "actor": ctx.actor, "reason": f"search.fetch {uri}",
                                   "hash": h})
    return {"source_id": sid, "sha256": h, "license": lic, "size_bytes": n}


def _ten_tep(uri: str) -> str:
    """Tên tệp trong cache, làm sạch. KHÔNG dùng thẳng phần cuối URL: một máy chủ ác ý trả
    `Content-Disposition: ../../x` hay đường dẫn có `/` là ghi ra ngoài cache — cùng lỗ hổng
    zip-slip, đường khác."""
    ten = Path(urlparse(uri).path).name or "tai_ve"
    ten = re.sub(r"[^0-9A-Za-z._-]+", "_", ten)[:120]
    return f"{hashlib.sha256(uri.encode()).hexdigest()[:10]}_{ten}"


def _tai(uri: str, dich: Path, gate: Any) -> tuple[int, str]:
    """Tải theo khối, dừng ngay khi vượt ngưỡng — không tin `Content-Length`.

    Máy chủ khai 1 MB rồi gửi 4 GB là chuyện có thật, và cổng đã quyết dựa trên con số khai ấy.
    Nên phải đếm byte THỰC trong lúc tải: đây là chỗ duy nhất biết sự thật.
    """
    tran = int(((getattr(gate, "config", None) or {}).get("thresholds") or {})
               .get("download_max_mb", 50)) * 1024**2
    h = hashlib.sha256()
    n = 0
    req = urllib.request.Request(uri, headers={"User-Agent": UA})  # noqa: S310
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as r, dich.open("wb") as w:  # noqa: S310
            while (b := r.read(1 << 16)):
                n += len(b)
                if n > tran:
                    w.close()
                    dich.unlink(missing_ok=True)
                    raise EideError("E8001", f"Tải vượt ngưỡng {tran // 1024**2} MB tại {uri} "
                                    "(máy chủ gửi nhiều hơn Content-Length đã khai)",
                                    uri=uri, limit_mb=tran // 1024**2)
                h.update(b)
                w.write(b)
    except urllib.error.URLError as e:
        dich.unlink(missing_ok=True)
        raise EideError("E4004", f"Không tải được {uri}: {e}", uri=uri) from e
    except TimeoutError as e:
        dich.unlink(missing_ok=True)
        raise EideError("E4004", f"Quá hạn {TIMEOUT_S}s khi tải {uri}", uri=uri) from e
    return n, h.hexdigest()


def _nhan_dien_license(f: Path) -> str | None:
    """SEC-25 §4. Chỉ nhận vài mẫu chắc chắn; không thấy thì trả None chứ không đoán.

    `None` chảy về `unknown`, và `unknown` rơi vào G-SRC-05 (ASK) — tức người xem. Đoán sai một
    giấy phép thì nguồn ấy được tự duyệt, và giấy phép là thứ không sửa lại được sau khi đã
    phát tán tài liệu kèm sản phẩm.
    """
    try:
        t = f.open("rb").read(200_000).decode("utf-8", errors="ignore")
    except OSError:
        return None
    for mau, ten in MAU_LICENSE:
        if re.search(mau, t, re.I | re.S):
            return ten
    return None


def _ghi_source(root: Path, f: Path, uri: str, h: str, n: int, kind: str | None,
                lic: str, tier: str | None) -> str:
    db = store.store_path(root)
    if not db.exists():
        return "src_" + h[:16]
    with store.open_store(db) as c:
        if (r := c.execute("SELECT id FROM source WHERE sha256=?", (h,)).fetchone()):
            return r[0]
        sid = "src_" + h[:16]
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier, license, domain,"
                  " fetched_at, size_bytes, meta) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (sid, uri, h, kind or "web", tier or "bronze", lic,
                   urlparse(uri).netloc, datetime.now(UTC).isoformat(), n,
                   json.dumps({"cache": str(f)}, ensure_ascii=False)))
        c.commit()
    store.write_seal(db)
    return sid


# ---------------------------------------------------------------- SEARCH-07 verify_match


@capability("search.verify_match")
def verify_match(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SEARCH-07 — CDS-12.2. Trả `match_score` 0–1 và `reasons`.

    Năng lực này canh một lỗi rất dễ xảy ra và rất khó thấy: **tải nhầm tài liệu**. Mẫu URL của
    ST cho STM32F411 và STM32F401 chỉ khác một ký tự; tải nhầm thì mọi fact trích ra đều đúng
    định dạng, đúng tầng vàng, và sai chip. Không có gì ở phía sau bắt được — `passport.import`
    chỉ biết fact nói gì, không biết fact đáng lẽ nói về ai.

    Bước 1 của hợp đồng dùng `extract.pdf_layout` để đọc 3 trang đầu; năng lực ấy chưa có. Nên
    ở đây dùng **bằng chứng yếu hơn nhưng thật**: mã linh kiện trong URI, trong tên tệp, và
    trong văn bản đọc được nếu tệp là văn bản. `reasons` ghi rõ đã dùng bằng chứng nào, và
    `match_score` KHÔNG bao giờ đạt 1.0 khi chưa đọc được nội dung — điểm cao giả là cách chắc
    chắn nhất để G-SRC-06 (`match_score < ngưỡng` → ASK) trở thành quy tắc chết.
    """
    root = _root(ctx)
    part = params["part"]
    ban = params.get("version")
    with store.open_store(store.store_path(root)) as c:
        r = c.execute("SELECT uri, meta, kind FROM source WHERE id=?",
                      (params["source_id"],)).fetchone()
    if r is None:
        raise EideError("E2000", f"Không có nguồn {params['source_id']}",
                        exists=[], candidates=[], missing=[params["source_id"]])
    uri, meta, kind = r
    duong = (json.loads(meta) if meta else {}).get("cache")

    diem, vi = 0.0, []
    ma = part.lower()
    if ma in (uri or "").lower():
        diem += 0.5
        vi.append(f"mã {part} xuất hiện trong URI")
    else:
        vi.append(f"mã {part} KHÔNG có trong URI — dấu hiệu tải nhầm linh kiện")

    noi_dung = _van_ban(Path(duong)) if duong else None
    if noi_dung is None:
        vi.append("chưa đọc được nội dung (cần extract.pdf_layout, EXTRACT-03) — điểm bị chặn "
                  "ở 0,6 vì mới chỉ đối chiếu được đường dẫn")
        return {"match_score": round(min(diem + 0.1, 0.6), 2), "reasons": vi}

    if ma in noi_dung.lower():
        diem += 0.4
        vi.append(f"mã {part} xuất hiện trong nội dung")
    else:
        vi.append(f"mã {part} KHÔNG có trong nội dung đã đọc")
    ver = _ban_tai_lieu(noi_dung)
    if ban and ver and ban.lower() in ver.lower():
        diem += 0.1
        vi.append(f"khớp phiên bản tài liệu {ver}")
    return {"match_score": round(min(diem, 1.0), 2), "reasons": vi,
            **({"doc_version": ver} if ver else {})}


def _van_ban(f: Path) -> str | None:
    """Đọc văn bản nếu tệp là văn bản. PDF trả None — đó là việc của `extract.pdf_layout`.

    Không cố bóc chữ từ PDF bằng biểu thức chính quy: PDF nén luồng nội dung, nên cách ấy lúc
    được lúc không, và một phép kiểm lúc được lúc không thì tệ hơn không có — nó cho điểm cao
    ngẫu nhiên và làm G-SRC-06 im lặng đúng những lần không nên im.
    """
    if not f.is_file():
        return None
    try:
        dau = f.open("rb").read(8)
    except OSError:
        return None
    if dau.startswith(b"%PDF-"):
        return None
    try:
        return f.open("rb").read(400_000).decode("utf-8", errors="ignore")
    except OSError:
        return None


def _ban_tai_lieu(t: str) -> str | None:
    for mau in (r"\b(Rev(?:ision)?\.?\s*[0-9]+(?:\.[0-9]+)?)\b",
                r"\b(DS[0-9]{4,6})\b", r"\b(RM[0-9]{4,6})\b", r"\bv([0-9]+\.[0-9]+)\b"):
        if (m := re.search(mau, t[:20_000], re.I)):
            return m.group(1)
    return None


# ---------------------------------------------------------------- SEARCH-08 missing


@capability("search.missing")
def missing(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SEARCH-08 — CDS-12.2. Trả `requests` với `subject, kind, why`.

    Trả lời câu hỏi "để làm được việc này, tôi còn thiếu tri thức gì" — và đó là năng lực làm
    cho tác tử biết mình không biết. Không có nó, tác tử đi tới bước cần `base_address` của I2C1,
    không thấy, rồi hoặc đoán hoặc dừng; cả hai đều tệ hơn là nói trước "tôi cần bản đồ thanh
    ghi I2C của chip này".

    Bước 2 gộp theo NGUỒN CÓ THỂ ĐÁP ỨNG, không liệt kê từng subject rời: mười thanh ghi thiếu
    của cùng một chip là **một** yêu cầu tải SVD, không phải mười. Danh sách mười dòng khiến
    người đọc tưởng có mười việc phải làm.
    """
    root = _root(ctx)
    can = _vi_tu_can(root, params["task_ref"])
    if not can:
        return {"requests": []}

    db = store.store_path(root)
    with store.open_store(db) as c:
        co = {r[0] for r in c.execute(
            "SELECT DISTINCT subject FROM fact WHERE status NOT IN ('superseded','rejected')")}

    thieu = [s for s in can if not any(x == s or x.startswith(s + "/") for x in co)]
    theo_chip: dict[str, list[str]] = {}
    for s in thieu:
        theo_chip.setdefault(s.split("/")[0], []).append(s)

    return {"requests": [
        {"subject": chip, "kind": "svd" if chip.startswith("chip:") else "pdf",
         "why": f"thiếu {len(ds)} chủ thể cho `{params['task_ref']}`: "
                + ", ".join(x.split("/", 1)[-1] for x in sorted(ds)[:5])
                + ("…" if len(ds) > 5 else ""),
         "subjects": sorted(ds)}
        for chip, ds in sorted(theo_chip.items())]}


def _vi_tu_can(root: Path, task_ref: str) -> list[str]:
    """Chủ thể IRI mà một bước kế hoạch cần. Lấy từ `plan.sufficiency` — nó đã trả lời đúng câu
    hỏi này cho `plan.*`, và hỏi hai chỗ khác nhau cùng một câu là mời hai câu trả lời khác
    nhau."""
    from eide.caps.plan import _vi_tu_can as vi_tu
    ds = sorted(vi_tu(task_ref))
    db = store.store_path(root)
    if not db.exists():
        return ds
    with store.open_store(db) as c:
        chip = c.execute("SELECT id FROM passport WHERE kind='chip' ORDER BY id LIMIT 1").fetchone()
    goc = f"chip:{chip[0].split('@')[0]}" if chip else "chip:?"
    return [f"{goc}/{x}" if ":" not in x else x for x in ds]


# ---------------------------------------------------------------- SEARCH-04 web


# Bước 2: "loại trang không phải tài liệu". Đây là phần deterministic đáng giá nhất của năng
# lực này — một trang bán hàng hay một bài blog trông giống kết quả hợp lệ với mọi công cụ tìm
# kiếm, và nếu để lọt thì `search.fetch` tải về rồi `extract.*` sinh ra fact từ quảng cáo.
DUOI_TAI_LIEU = (".pdf", ".svd", ".atdf", ".xml", ".zip", ".h", ".hpp", ".txt", ".md", ".json")
TU_KHOA_TAI_LIEU = ("datasheet", "reference manual", "user manual", "errata", "application note",
                    "programming manual", "technical reference", "schematic", "svd", "atdf")

# Tên miền KHÔNG PHẢI nguồn tài liệu: chợ điện tử, mạng xã hội, hỏi đáp chung. Chúng có thể
# hữu ích cho người, nhưng làm nguồn fact thì không — và `search.rank` sẽ xếp chúng cao nếu
# tiêu đề tình cờ chứa mã linh kiện.
MIEN_LOAI = ("amazon.", "ebay.", "aliexpress.", "alibaba.", "taobao.", "shopee.", "lazada.",
             "facebook.", "twitter.", "x.com", "linkedin.", "pinterest.", "youtube.",
             "reddit.com", "quora.com", "medium.com", "wikipedia.org")

# Diễn đàn: KHÔNG loại, nhưng hạ tầng xuống `bronze`. TGT-19 §8 xếp "forum → đồng (chỉ ứng
# viên)" — một câu trả lời trên diễn đàn có thể đúng và có khi là nguồn duy nhất cho một con
# chip cũ, nhưng nó không bao giờ được tự duyệt ở cổng G-FACT.
MIEN_DIEN_DAN = ("stackoverflow.com", "stackexchange.com", "electronics.stackexchange.com",
                 "forum.", "forums.", "community.", "discuss.", "github.com/issues",
                 "edaboard.com", "eevblog.com", "avrfreaks.net", "esp32.com")

KIND_TU_KHOA = {
    "datasheet": ("datasheet", "data sheet", "ds"),
    "svd": ("svd", "cmsis"),
    "repo": ("github.com", "gitlab.com", "bitbucket.org", "sourceforge"),
    "errata": ("errata", "erratum", "es0"),
    "forum": MIEN_DIEN_DAN,
    "schematic": ("schematic", "sch", "kicad", "eagle"),
}


@capability("search.web")
def web(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SEARCH-04 — CDS-12.2; TGT-19 §8. tc: "allegromicro.com xếp trên forum"; lỗi E4004.

    Hợp đồng chỉ nói *"công cụ tìm kiếm (API cấu hình)"* — cố ý không nêu nhà cung cấp. Nên ở
    đây nhà cung cấp là **cấu hình**, không phải mã: `models.yaml → search.providers` liệt kê
    ứng viên theo thứ tự, và năng lực dùng cái đầu tiên có đủ khóa/địa chỉ. Đổi nhà cung cấp
    hoặc thêm một cái mới là sửa YAML.

    SearXNG đứng đầu danh sách mặc định vì nó tự dựng được, không cần khóa và không tốn tiền —
    hoàn thiện mốc M1 không nên buộc ai phải mua gì.

    Bước 2 — *"loại trang không phải tài liệu"* — là phần deterministic đáng giá nhất. Một trang
    bán hàng hay một bài blog trông giống kết quả hợp lệ với mọi công cụ tìm kiếm; để lọt thì
    `search.fetch` tải về và `extract.*` sinh fact từ quảng cáo. Diễn đàn thì KHÔNG loại nhưng
    hạ xuống tầng đồng: có khi nó là nguồn duy nhất cho một con chip cũ, nhưng không bao giờ
    được tự duyệt ở G-FACT.

    "không tải" — chỉ trả ứng viên. Tải là việc của `search.fetch`, nơi cổng G-SRC quyết.
    """
    q = params["query"]
    part = params.get("part")
    kinds = list(params.get("kinds") or [])
    cfg = _cau_hinh_tim_kiem()
    nha_cc = _chon_nha_cung_cap(cfg)

    truy_van = " ".join(x for x in [q, part, *(f"{k}" for k in kinds)] if x)
    tho = _goi(nha_cc, truy_van, int(cfg.get("max_results") or 20),
               float(cfg.get("timeout_s") or TIMEOUT_S))

    ra = []
    for r in tho:
        uri = r.get("url") or ""
        dom = _chuan_hoa_domain(uri)
        if not dom or _bi_loai(uri, dom):
            continue
        kind = _doan_kind(uri, r.get("title") or "", dom)
        ra.append({"uri": uri, "title": r.get("title") or "", "snippet": r.get("snippet") or "",
                   "domain": dom, "kind": kind, "tier_expected": _tang_du_kien(dom, kind),
                   "license_hint": None, "provider": nha_cc["id"],
                   "size_est": None, "reachable": None})
        if len(ra) >= int(cfg.get("max_results") or 20):
            break
    return {"candidates": ra}


def _cau_hinh_tim_kiem() -> dict[str, Any]:
    d = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8")) or {}
    return d.get("search") or {}


def _chon_nha_cung_cap(cfg: dict[str, Any]) -> dict[str, Any]:
    """Ứng viên đầu tiên có đủ cấu hình. Không có cái nào ⇒ E4001 kèm HƯỚNG DẪN CỤ THỂ.

    Liệt kê từng lựa chọn với biến môi trường của nó, thay vì một câu "chưa cấu hình": người
    đọc thông báo lỗi ấy cần biết mình có những đường nào và rẻ nhất là đường nào.
    """
    import os
    for p in (cfg.get("providers") or []):
        if p.get("key_env") and os.environ.get(p["key_env"]):
            return p
        if p.get("base_url_env") and os.environ.get(p["base_url_env"]):
            return p
    goi_y = "; ".join(
        f"{p['id']}: đặt {p.get('key_env') or p.get('base_url_env')}"
        + (f" và {p['cx_env']}" if p.get("cx_env") else "")
        for p in (cfg.get("providers") or []))
    raise EideError("E4001", "Chưa cấu hình công cụ tìm kiếm nào cho `search.web`. Các lựa "
                    f"chọn trong `models.yaml → search.providers` — {goi_y}. Rẻ nhất: dựng một "
                    "SearXNG cục bộ rồi đặt SEARXNG_URL, không cần khóa và không tốn tiền. "
                    "Trong lúc chờ, `search.vendor` tra thẳng trang hãng theo TGT-19 §8 và đã "
                    "phủ phần lớn nhu cầu.",
                    tool="search provider", providers=[p["id"] for p in (cfg.get("providers") or [])],
                    alternative="search.vendor")


def _goi(p: dict[str, Any], q: str, n: int, timeout: float) -> list[dict[str, Any]]:
    """Gọi nhà cung cấp. Mỗi `kind` là một bộ chuyển đổi nhỏ: dựng URL, đọc kết quả.

    Tách theo `kind` chứ không theo `id` để hai người dùng đặt tên khác nhau cho cùng một dịch
    vụ vẫn dùng chung một bộ chuyển đổi.
    """
    import json as _json
    import os
    import urllib.parse
    ky = p.get("kind")
    hdr = {"User-Agent": UA, "Accept": "application/json"}
    if ky == "searxng":
        goc = os.environ[p["base_url_env"]].rstrip("/")
        url = f"{goc}/search?{urllib.parse.urlencode({'q': q, 'format': 'json'})}"
    elif ky == "brave":
        url = ("https://api.search.brave.com/res/v1/web/search?"
               + urllib.parse.urlencode({"q": q, "count": min(n, 20)}))
        hdr["X-Subscription-Token"] = os.environ[p["key_env"]]
    elif ky == "tavily":
        url = "https://api.tavily.com/search"
        hdr["Authorization"] = "Bearer " + os.environ[p["key_env"]]
    elif ky == "google_cse":
        url = ("https://www.googleapis.com/customsearch/v1?"
               + urllib.parse.urlencode({"key": os.environ[p["key_env"]],
                                         "cx": os.environ[p["cx_env"]], "q": q,
                                         "num": min(n, 10)}))
    else:
        raise EideError("E1000", f"Loại nhà cung cấp tìm kiếm lạ: {ky}", kind=ky)

    than = _json.dumps({"query": q, "max_results": min(n, 20)}).encode() if ky == "tavily" else None
    req = urllib.request.Request(url, data=than, headers=hdr)  # noqa: S310
    if than is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:  # noqa: S310
            d = _json.loads(r.read().decode("utf-8", errors="ignore"))
    except (urllib.error.URLError, OSError, TimeoutError, ValueError) as e:
        raise EideError("E4004", f"Công cụ tìm kiếm `{p['id']}` không trả lời: {e}",
                        provider=p["id"]) from e
    return _doc_ket_qua(ky, d)


def _doc_ket_qua(ky: str, d: dict[str, Any]) -> list[dict[str, Any]]:
    """Chuẩn hóa về `{url, title, snippet}`. Mỗi dịch vụ đặt tên trường một kiểu."""
    if ky == "searxng":
        return [{"url": x.get("url"), "title": x.get("title"),
                 "snippet": x.get("content")} for x in (d.get("results") or [])]
    if ky == "brave":
        return [{"url": x.get("url"), "title": x.get("title"),
                 "snippet": x.get("description")}
                for x in ((d.get("web") or {}).get("results") or [])]
    if ky == "tavily":
        return [{"url": x.get("url"), "title": x.get("title"),
                 "snippet": x.get("content")} for x in (d.get("results") or [])]
    if ky == "google_cse":
        return [{"url": x.get("link"), "title": x.get("title"),
                 "snippet": x.get("snippet")} for x in (d.get("items") or [])]
    return []


def _bi_loai(uri: str, dom: str) -> bool:
    """Trang KHÔNG phải nguồn tài liệu. Diễn đàn không bị loại — nó chỉ bị hạ tầng."""
    return any(x in dom for x in MIEN_LOAI)


def _doan_kind(uri: str, title: str, dom: str) -> str:
    t = f"{uri} {title}".lower()
    if any(x in dom for x in MIEN_DIEN_DAN):
        return "forum"
    for k, tu in KIND_TU_KHOA.items():
        if k == "forum":
            continue
        if any(x in t for x in tu):
            return k
    return "pdf" if uri.lower().endswith(".pdf") else "web"


def _tang_du_kien(dom: str, kind: str) -> str:
    """Tầng dự kiến theo TGT-19 §8: trang hãng → bạc (PDF) hoặc vàng (SVD/ATDF); diễn đàn → đồng.

    Đây là chỗ tc "allegromicro.com xếp trên forum" được quyết: cùng một mã linh kiện xuất hiện
    ở trang hãng và trên diễn đàn thì trang hãng phải thắng, và nó thắng vì TẦNG khác nhau chứ
    không vì thứ tự công cụ tìm kiếm trả về — thứ tự ấy là của nhà cung cấp, không phải của ta.
    """
    if any(x in dom for x in MIEN_DIEN_DAN):
        return "bronze"
    if _la_trang_hang(dom):
        return "gold" if kind in ("svd", "atdf", "edc") else "silver"
    return "bronze"


def _la_trang_hang(dom: str) -> bool:
    """Tên miền có trong bảng nguồn hãng TGT-19 §8 (`sources/vendors.yaml`).

    Đọc từ spec, không chép tay — cùng bảng mà `search.vendor` dùng, nên thêm một hãng là hai
    năng lực cùng biết.
    """
    for v in bang_hang():
        for d in (v.get("domains") or []):
            d = d.split("/")[0].lower()
            if dom == d or dom.endswith("." + d):
                return True
    return False


# ---------------------------------------------------------------- SEARCH-03 docs_mcp


TRAN_DOAN = 5           # bước 1: "giới hạn 5 đoạn"
HANG_CO_DOCS_MCP = ("espressif", "nordic")


@capability("search.docs_mcp")
def docs_mcp(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SEARCH-03 — CDS-12.2; KAD-07 §5.3 E9 (Docs MCP của hãng); SEC-25 §3 (dự án nhạy
    cảm); API-15 §MCP. R0, `undo: none`; lỗi E4004, E8002. tc: TC-19.

    **Năm đoạn, không hơn.** Ngữ cảnh là tài nguyên có hạn (CXD-10 §3): mười đoạn tài liệu hãng
    đẩy chính fact của dự án ra khỏi ngân sách, và fact của dự án mới là thứ không thay được.

    **E8002 khi dự án nhạy cảm VÀ truy vấn chứa nội dung dự án** — hai vế, không phải một. Chặn
    mọi truy vấn của một dự án nhạy cảm là tắt hẳn năng lực, mà hỏi "esp_timer dùng thế nào"
    thì không rò rỉ gì. Cái phải chặn là gửi tên module nội bộ, tên dự án, tên feature ra ngoài.

    Mỗi đoạn lưu thành `Source` kind `docs_mcp`, tầng **bạc** (KAD-07 §5.3 E9): tài liệu hãng
    qua MCP là nguồn tốt nhưng không phải tệp máy đọc được đã ký, nên nó không tự duyệt ở G-FACT.
    Không có `source` thì fact rút từ đoạn ấy sau này chẳng trỏ về đâu được.
    """
    q = params["query"]
    vendor = params.get("vendor")
    root = _root(ctx)
    _kiem_nhay_cam(root, q)

    client = _docs_mcp_client(ctx, vendor)
    if client is None:
        raise EideError("E4004", "Chưa cấu hình docs MCP server nào — thêm `docs_mcp` vào "
                        "`models.yaml` (hoặc `.eide/models.yaml`) với lệnh khởi động server của "
                        f"hãng ({', '.join(HANG_CO_DOCS_MCP)})",
                        candidates=["search.vendor", "search.web"], vendor=vendor)
    try:
        doan = client.tim(q, vendor)[:TRAN_DOAN]
    except EideError:
        raise
    except Exception as e:                                        # noqa: BLE001
        raise EideError("E4004", f"Docs MCP không trả lời: {e}", vendor=vendor) from e

    ra = []
    for d in doan:
        sid = _ghi_source_mcp(root, d, vendor, ctx)
        ra.append({"text": str(d.get("text") or "")[:4000], "url": d.get("url"),
                   "date": d.get("date"), "sdk_version": d.get("sdk_version"),
                   "source_id": sid})
    return {"snippets": ra}


def _kiem_nhay_cam(root: Path, q: str) -> None:
    """SEC-25 §3: dự án `sensitive` không được gửi nội dung của chính nó ra ngoài."""
    import yaml as _yaml
    p = root / ".eide" / "constraints.yaml"
    if not p.is_file():
        return
    cfg = _yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    if not cfg.get("sensitive"):
        return
    du_an = (cfg.get("project") or {})
    tu_rieng = {str(du_an.get("name") or ""), str(du_an.get("id") or "")}
    tu_rieng |= {str(x) for x in (cfg.get("modules") or [])}
    ql = q.lower()
    lo = sorted({t for t in tu_rieng if t and len(t) > 3 and t.lower() in ql})
    if lo:
        raise EideError("E8002", "Dự án đánh dấu nhạy cảm và truy vấn chứa nội dung của nó "
                        f"({', '.join(lo)}) — hỏi bằng thuật ngữ chung của hãng, đừng gửi tên "
                        "nội bộ ra ngoài", leaked=lo)


def _docs_mcp_client(ctx: Context, vendor: str | None) -> Any:
    """Client MCP tới docs server của hãng, dựng từ cấu hình.

    Trả `None` khi chưa cấu hình — bên gọi biến nó thành E4004 kèm cách cấu hình. Đọc cấu hình
    chứ không viết cứng địa chỉ: hãng đổi endpoint là chuyện của họ, và sửa YAML rẻ hơn sửa mã.
    """
    import yaml as _yaml
    cfg: dict[str, Any] = {}
    for p in (Path(ctx.project_dir or ".") / ".eide" / "models.yaml", spec_dir() / "models.yaml"):
        if p.is_file():
            cfg = _yaml.safe_load(p.read_text(encoding="utf-8")) or {}
            if cfg.get("docs_mcp"):
                break
    khai = (cfg.get("docs_mcp") or {}).get(vendor or "", None)
    if not khai:
        return None
    return _McpStdio(khai, ledger=ctx.extra.get("ledger"))


class _McpStdio:
    """MCP client tối thiểu qua stdio: `initialize` → `tools/call`.

    Đủ cho SEARCH-03 và không hơn — một client MCP đầy đủ là việc của một thư viện, còn ở đây
    ta chỉ cần gọi đúng một tool tìm kiếm và đọc kết quả.
    """

    def __init__(self, khai: dict[str, Any], ledger: Any = None) -> None:
        self.cmd = list(khai.get("command") or [])
        self.tool = khai.get("tool") or "search"
        self.ledger = ledger

    def tim(self, query: str, vendor: str | None) -> list[dict[str, Any]]:
        import subprocess
        if not self.cmd:
            raise EideError("E4004", "Cấu hình `docs_mcp` thiếu `command`")
        goi = [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize",
             "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                        "clientInfo": {"name": "eide", "version": "1"}}},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
             "params": {"name": self.tool, "arguments": {"query": query}}},
        ]
        p = subprocess.run(self.cmd, input="\n".join(json.dumps(x) for x in goi) + "\n",  # noqa: S603
                           capture_output=True, text=True, timeout=60, check=False)
        if p.returncode != 0:
            raise EideError("E4004", f"docs MCP thoát mã {p.returncode}: {p.stderr[:300]}")
        for dong in reversed(p.stdout.splitlines()):
            try:
                d = json.loads(dong)
            except json.JSONDecodeError:
                continue
            if d.get("id") == 2:
                noi = (d.get("result") or {}).get("content") or []
                return [x for x in noi if isinstance(x, dict)]
        raise EideError("E4004", "docs MCP không trả kết quả cho `tools/call`")


def _ghi_source_mcp(root: Path, d: dict[str, Any], vendor: str | None, ctx: Context) -> str:
    import hashlib
    noi = str(d.get("text") or "")
    h = hashlib.sha256(noi.encode("utf-8")).hexdigest()
    sid = "src_" + h[:16]
    db = store.store_path(root)
    with store.open_store(db) as c:
        if c.execute("SELECT 1 FROM source WHERE id=?", (sid,)).fetchone():
            return sid
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier, domain, fetched_at, meta)"
                  " VALUES (?,?,?,?,?,?,?,?)",
                  (sid, d.get("url") or f"mcp://{vendor}/{h[:8]}", h, "docs_mcp", "silver",
                   vendor, datetime.now(UTC).isoformat(),
                   json.dumps({"date": d.get("date"), "sdk_version": d.get("sdk_version")},
                              ensure_ascii=False)))
        c.commit()
    store.write_seal(db, ctx.extra.get("ledger"))
    return sid
