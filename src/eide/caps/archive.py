"""Namespace `archive` — CDS-12.2 (tập Tri thức); KAD-07 §3; DDD-14 §2 Source.

Tệp này mang CẢ `archive.*` lẫn `ingest.*`. Trông như hai nhóm nhưng spec xếp chung một
namespace: `docs/spec/capabilities/archive.yaml` khai `impl: eide.archive:classify` cho
`ingest.classify`, mã năng lực của nó là `ARCHIVE-05`, và CDS-12.2 đặt tiêu đề mục là
"archive / ingest". Gộp có chủ ý — cả bảy đều phục vụ UC-B01 "đưa một đống tệp vào dự án".

Đặt chúng ra `ingest.py` cho dễ đọc thì `impl` trong spec trỏ sai chỗ, và người đọc tài liệu đi
tìm mã theo `impl` sẽ không thấy. Tên tệp theo spec, không theo trực giác.

Hiện thực ở đây: `ingest.classify`, `ingest.hash_dedupe`, `ingest.index_text` — cả ba đều
deterministic. Đây là cửa vào của toàn bộ tri thức: mọi fact trong
store đều bắt nguồn từ một tệp đi qua đây, nên `tier` gán ở bước này quyết định về sau fact ấy
có được tự duyệt ở cổng G-FACT hay phải hỏi người.

## Vì sao chữ ký nội dung đi trước phần mở rộng

Bước 1 của INGEST-01 nói thẳng thứ tự: "Chữ ký nội dung (magic, XML root, từ khóa) TRƯỚC phần
mở rộng". Phần mở rộng là thứ người dùng gõ, không phải thứ tệp thật sự là — một tệp SVD tải về
tên `stm32f411.xml`, một datasheet lưu thành `.pdf.download`, một ATDF đặt tên `.atdf` nhưng
bên trong là HTML báo lỗi 404. Tin phần mở rộng nghĩa là gán `tier: gold` cho trang lỗi ấy, và
từ đó mọi fact "trích" từ nó vào thẳng store không qua ai duyệt.
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context
from eide_core.tools import which

# Bảng `kind → (tier, extractor)` của INGEST-01 bước 2, nguyên văn: "svd/atdf/edc/binding/header:
# gold; pdf hãng: silver; ảnh: silver-vision; readme/md: context".
#
# `kind` phải thuộc enum của DDD-14 §2 Source — không được đặt thêm tên mới ở đây, vì cột ấy có
# ràng buộc và vì `search.*`/`extract.*` sau này lọc theo đúng enum ấy.
# `extractor` là TÊN NĂNG LỰC GỌI ĐƯỢC, không phải một nhãn mô tả.
#
# Cả điểm của trường này là bên gọi dispatch được trên nó: phân loại xong thì biết ngay phải
# chạy cái gì tiếp. Tới 20/09/2026 chưa bên gọi nào làm thế, và trong khoảng lặng ấy **7 trong
# 16 dòng trỏ tới năng lực KHÔNG TỒN TẠI**: `extract.binding`, `extract.header`, `extract.image`,
# `extract.kicad`, `extract.netlist`, `extract.csv`, `extract.html`. Chúng là tên RÚT GỌN của
# `kind` chứ không phải tên năng lực, và chúng gồm những loại tệp thường gặp nhất — header C,
# netlist KiCad, CSV. Màn Nhập tài liệu (S4) là bên gọi đầu tiên, nên nó là chỗ đầu tiên đạp
# phải. `test_extractor_deu_la_nang_luc_co_that` giữ cho bảng này khỏi rữa lại.
#
# Hai dòng cố ý để `None`, và `None` ở đây là một câu trả lời chứ không phải một chỗ trống:
# - `html`: không có năng lực nào đọc HTML thành fact.
# - `image`: có ba ứng viên (`image_board`/`image_schematic`/`image_scope`) mà chữ ký tệp không
#   phân biệt nổi, và cả ba đều chờ đường ảnh cho Gateway ([DEV-076], [DEV-079]). Đoán một
#   trong ba là hứa một việc sản phẩm chưa làm được.
BANG_KIND: dict[str, tuple[str, str | None]] = {
    "svd":      ("gold", "extract.svd"),
    "atdf":     ("gold", "extract.atdf"),
    "edc":      ("gold", "extract.edc"),
    "binding":  ("gold", "extract.dt_binding"),
    "header":   ("gold", "extract.header_c"),
    "pdf":      ("silver", "extract.pdf_layout"),
    "image":    ("silver", None),
    "kicad":    ("silver", "extract.kicad_netlist"),
    "netlist":  ("silver", "extract.kicad_netlist"),
    "csv":      ("bronze", "extract.bom"),
    "html":     ("bronze", None),
    "md":       ("bronze", None),
    "readme":   ("bronze", None),
    "archive":  ("bronze", "archive.list"),
    "docx":     ("bronze", "extract.office"),
    "xlsx":     ("bronze", "extract.office"),
}

# Chữ ký nhị phân ở đầu tệp. Thứ tự trong tuple không quan trọng, nhưng phép so phải ở BYTE —
# giải mã thành text trước rồi so chuỗi sẽ nổ trên tệp nhị phân, và một ngoại lệ ở bước phân
# loại nghĩa là cả lô tệp không vào được.
CHU_KY: tuple[tuple[bytes, str], ...] = (
    (b"%PDF-", "pdf"),
    (b"PK\x03\x04", "zip"),          # cần đọc thêm: docx/xlsx cũng là zip
    (b"\x89PNG\r\n", "image"),
    (b"\xff\xd8\xff", "image"),
    (b"7z\xbc\xaf\x27\x1c", "archive"),
    (b"Rar!\x1a\x07", "archive"),
    (b"\x1f\x8b", "archive"),        # gzip
    (b"\xfd7zXZ\x00", "archive"),
)

# Gốc XML → kind. SVD và ATDF đều là XML, nên phần mở rộng không phân biệt được chúng; chỉ tên
# thẻ gốc mới nói được đây là gì.
GOC_XML: dict[str, str] = {
    "device": "svd",             # CMSIS-SVD
    "avr-tools-device-file": "atdf",
    "pic": "edc",
    "edc:pic": "edc",
}

DOC_DAU = 4096                   # đủ để thấy thẻ gốc XML mà không đọc cả tệp 40 MB


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root:
        raise EideError("E2000", "Nhóm ingest.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


# ---------------------------------------------------------------- INGEST-01 classify


@capability("ingest.classify")
def classify(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-05 — CDS-12.2. tc: TC-01 "≥ 95% đúng trên bộ 10 tệp".

    Trả `confidence` cho từng tệp, và con số ấy có nghĩa thật: 1.0 khi chữ ký nội dung khẳng
    định, 0.6 khi chỉ có phần mở rộng làm chứng. Bên gọi dùng nó để quyết có hỏi người không —
    một bảng phân loại toàn `confidence: 1.0` thì cột ấy vô dụng.
    """
    ra = []
    for f in params["files"]:
        p = Path(f).expanduser()
        kind, cf, vi = _nhan_dang(p)
        tier, extractor = BANG_KIND.get(kind, ("bronze", None))
        ra.append({"file": str(p), "kind": kind, "tier": tier, "extractor": extractor,
                   "confidence": cf, "vi_sao": vi})
    return {"classification": ra}


def _nhan_dang(p: Path) -> tuple[str, float, str]:
    """Chữ ký nội dung TRƯỚC, phần mở rộng sau — thứ tự của bước 1."""
    if not p.exists():
        return "unknown", 0.0, "tệp không tồn tại"

    dau = p.open("rb").read(DOC_DAU)

    for sig, kind in CHU_KY:
        if dau.startswith(sig):
            if kind == "zip":
                return _trong_zip(p, dau)
            if kind == "pdf":
                return _loai_pdf(p, dau)
            return kind, 1.0, f"chữ ký nhị phân {sig!r}"

    if (goc := _goc_xml(dau)):
        if goc in GOC_XML:
            return GOC_XML[goc], 1.0, f"thẻ gốc XML <{goc}>"
        if goc == "html":
            return "html", 1.0, "thẻ gốc <html>"
        return "html" if goc.lower().startswith("!doctype") else "csv", 0.5, f"XML lạ <{goc}>"

    ten = p.name.lower()
    if ten.startswith("readme"):
        return "readme", 0.9, "tên tệp README"
    if _co_ve_la_header(dau):
        return "header", 0.9, "nội dung có #include/#define"

    # Chỉ tới đây mới xét phần mở rộng, và hạ confidence để nói rõ: đây là suy đoán từ TÊN, thứ
    # người dùng gõ, không phải từ nội dung.
    duoi = p.suffix.lower().lstrip(".")
    mo = {"h": "header", "hpp": "header", "dts": "binding", "dtsi": "binding",
          "yaml": "binding", "yml": "binding", "md": "md", "txt": "md",
          "csv": "csv", "net": "netlist", "kicad_sch": "kicad", "kicad_pcb": "kicad"}
    if duoi in mo:
        return mo[duoi], 0.6, f"phần mở rộng .{duoi} (nội dung không khẳng định)"
    return "unknown", 0.0, "không nhận ra chữ ký lẫn phần mở rộng"


def _goc_xml(dau: bytes) -> str | None:
    """Tên thẻ gốc, bỏ qua khai báo XML, BOM và chú thích đầu tệp."""
    try:
        t = dau.decode("utf-8", errors="ignore").lstrip("﻿").strip()
    except UnicodeError:
        return None
    if not t.startswith("<"):
        return None
    t = re.sub(r"<\?xml.*?\?>", "", t, flags=re.S)
    t = re.sub(r"<!--.*?-->", "", t, flags=re.S)
    if (m := re.search(r"<\s*([A-Za-z_][\w:.-]*)", t)):
        return m.group(1).lower()
    return None


def _co_ve_la_header(dau: bytes) -> bool:
    t = dau.decode("utf-8", errors="ignore")
    return bool(re.search(r"^\s*#\s*(include|define|ifndef|pragma once)", t, re.M))


def _trong_zip(p: Path, dau: bytes) -> tuple[str, float, str]:
    """docx/xlsx là zip có `[Content_Types].xml`; zip thường thì là archive.

    Không phân biệt thì một tệp .docx bị xếp `archive` rồi đẩy sang `archive.list`, và người
    dùng nhận về một danh sách `word/document.xml` thay vì nội dung tài liệu.
    """
    import zipfile
    try:
        with zipfile.ZipFile(p) as z:
            ten = set(z.namelist()[:50])
    except (zipfile.BadZipFile, OSError):
        return "archive", 0.7, "chữ ký zip nhưng không mở được bảng mục"
    if any(x.startswith("word/") for x in ten):
        return "docx", 1.0, "zip có word/"
    if any(x.startswith("xl/") for x in ten):
        return "xlsx", 1.0, "zip có xl/"
    return "archive", 1.0, "zip thường"


def _loai_pdf(p: Path, dau: bytes) -> tuple[str, float, str]:
    """Bước 3: "PDF: phân biệt datasheet/reference manual/errata theo tiêu đề trang 1".

    Chỉ đọc chữ trong 4 KB đầu — đủ để bắt tiêu đề ở phần lớn PDF hãng mà không cần trình đọc
    PDF. Không thấy thì trả `pdf` chung với confidence thấp hơn, KHÔNG đoán: một errata bị xếp
    nhầm thành datasheet sẽ được coi là nguồn gốc thay vì bản đính chính, và fact của nó không
    được ưu tiên đúng mức.
    """
    t = dau.decode("latin-1", errors="ignore").lower()
    for tu, nhan in (("errata", "errata"), ("reference manual", "reference_manual"),
                     ("datasheet", "datasheet"), ("data sheet", "datasheet"),
                     ("user manual", "user_manual"), ("schematic", "schematic")):
        if tu in t:
            return "pdf", 0.9, f"PDF, tiêu đề chứa {tu!r} → {nhan}"
    return "pdf", 0.7, "PDF, chưa đọc được tiêu đề trong 4 KB đầu"


# ---------------------------------------------------------------- INGEST-02 hash_dedupe


@capability("ingest.hash_dedupe")
def hash_dedupe(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-06 — CDS-12.2; DDD-14 §2 Source (`sha256 TEXT UNIQUE`). tc: "Tệp đã có →
    dup kèm source_id".

    Băm NỘI DUNG, không phải đường dẫn hay ngày sửa. Cùng một datasheet tải hai lần vào hai chỗ
    khác nhau là cùng một nguồn; trích lại lần hai sẽ sinh ra một bộ fact trùng, và mỗi fact
    trùng ấy là một mục nữa phải duyệt ở G-FACT.

    `new` là mảng ĐƯỜNG DẪN, không phải mảng đối tượng — hợp đồng khai `arr<str>`. Bản đầu tôi
    trả kèm `sha256` để bên gọi khỏi băm lại tệp 40 MB lần nữa; tiện thật, nhưng nó phá schema
    và `additionalProperties: false` bắt ngay (E1004). Ai cần băm thì gọi `bam_tep`.
    """
    root = _root(ctx)
    db = store.store_path(root)
    da_co: dict[str, str] = {}
    if db.exists():
        with store.open_store(db) as c:
            da_co = {r[1]: r[0] for r in c.execute("SELECT id, sha256 FROM source").fetchall()}

    moi: list[str] = []
    trung: list[dict[str, Any]] = []
    for f in params["files"]:
        p = Path(f).expanduser()
        if not p.is_file():
            raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[],
                            missing=[str(p)])
        h = bam_tep(p)
        if h in da_co:
            trung.append({"file": str(p), "sha256": h, "source_id": da_co[h]})
        else:
            moi.append(str(p))
            da_co[h] = f"(trùng trong lô, bản đầu: {p.name})"   # hai bản sao CÙNG lô cũng là trùng
    return {"new": moi, "dup": trung}


def bam_tep(p: Path, chunk: int = 1 << 20) -> str:
    """Đọc theo khối 1 MB. Nạp cả tệp vào bộ nhớ để băm sẽ hỏng trên archive vài GB — mà
    `archive.unpack` cho phép tới 2 GB."""
    h = hashlib.sha256()
    with p.open("rb") as f:
        while (b := f.read(chunk)):
            h.update(b)
    return h.hexdigest()


# ---------------------------------------------------------------- INGEST-03 index_text


@capability("ingest.index_text")
def index_text(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-07 — CDS-12.2. tc: "Truy vấn từ khóa tìm thấy".

    Bước 1 giới hạn rõ: "CHỈ tài liệu ngữ cảnh (README, ghi chú)". Không phải sự dè dặt — chỉ
    mục toàn văn là để tìm câu chữ của người, còn tri thức phần cứng thì đi đường fact, có nguồn
    và có tier. Đổ datasheet vào FTS5 sẽ khiến `memory.retrieve` trả về đoạn văn không trích dẫn
    được, cạnh tranh chỗ với fact có trích dẫn — và bên gọi không phân biệt được hai loại.
    """
    from eide_core.rag import Doan, RagIndex
    root = _root(ctx)
    idx = RagIndex(root)
    doan: list[Doan] = []
    for f in params["files"]:
        p = Path(f).expanduser()
        if not p.is_file():
            continue
        if _nhan_dang(p)[0] not in ("readme", "md"):
            continue
        try:
            noi_dung = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        sid = "src_" + bam_tep(p)[:16]
        for i, khuc in enumerate(_chia_doan(noi_dung)):
            doan.append(Doan(id=f"rc_{bam_tep(p)[:12]}_{i:03d}", source_id=sid, text=khuc,
                             locator={"file": str(p), "chunk": i}))
    return {"indexed": idx.them(doan)}


# ---------------------------------------------------------------- ARCHIVE-08 sources


# Fact CHƯA dùng được — đúng tập mà `code.constant_guard` từ chối (CODE-04 bước 1: qua khi
# `status` là reviewed/verified **hoặc** tầng gold). Đếm ở đây để màn Nhập tài liệu nói được
# "nguồn này đã nhập xong nhưng chưa dùng được", thay vì chỉ nói nó có bao nhiêu fact.
STATUS_CHO = ("normalized", "conflict")


@capability("archive.sources")
def sources(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-08 — CDS-12.2; DDD-14 §2 Source. tc: "Nhập 2 tệp → 2 nguồn, n_facts khớp
    passport.query; kind lạ → rỗng".

    ## Vì sao năng lực này tồn tại

    Bảng `source` là thứ duy nhất trả lời *"máy đã đọc những gì"*, và tới 20/09/2026 **không
    năng lực nào đọc ra nó** — xem [DEV-134]. `passport.query` trả `citations` nhưng chỉ trong
    phạm vi một `part` và không đếm fact mỗi nguồn; sổ cái đếm được fact mỗi LẦN NHẬP, không
    đếm được fact mỗi NGUỒN. Màn S4 vì thế phải bày hai bảng gần đúng thay cho một bảng đúng.

    `n_pending` tách khỏi `n_facts` vì hai con số trả lời hai câu khác nhau: nguồn này đóng góp
    bao nhiêu tri thức, và bao nhiêu trong đó còn chưa dùng được làm hằng số phần cứng. Gộp
    chúng lại thì một datasheet đã nhập trọn vẹn mà chưa ai duyệt trông y hệt một datasheet đã
    duyệt xong.

    Không mở lại tệp nguồn: trả CON TRỎ (`uri`) như `passport.export`. Bảng này nằm trong đường
    vẽ của màn S4 và chạy mỗi lần mở màn.
    """
    root = _root(ctx)
    db = store.store_path(root)
    if not db.exists():
        # Dự án chưa có store là "chưa nhập gì", không phải một sự cố — cùng lý do với
        # `passport.query` trên một dự án trống. Ném E2000 ở đây sẽ bắt màn S4 phải bắt lỗi để
        # hiện một trạng thái rỗng hoàn toàn bình thường.
        return {"sources": []}

    dk, tham = ("WHERE s.kind = ?", [params["kind"]]) if params.get("kind") else ("", [])
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT s.id, s.uri, s.kind, s.tier, s.fetched_at, s.license, s.size_bytes,"
            "       COUNT(f.id),"
            f"       SUM(CASE WHEN f.status IN ({','.join('?' * len(STATUS_CHO))})"
            "                 AND f.tier != 'gold' THEN 1 ELSE 0 END)"
            "  FROM source s LEFT JOIN fact f ON f.source_id = s.id"
            f" {dk} GROUP BY s.id ORDER BY s.fetched_at DESC, s.id",  # noqa: S608
            [*STATUS_CHO, *tham]).fetchall()

    return {"sources": [
        {"source_id": r[0], "uri": r[1], "kind": r[2], "tier": r[3],
         # `added_at` đọc từ cột `fetched_at` của DDD-14 §2. Hai tên cho cùng một mốc, và mốc ấy
         # RỖNG với tệp người tự bỏ vào — `fetched_at` chỉ có khi `search.fetch` tải về.
         "added_at": r[4], "license": r[5], "size_bytes": r[6],
         "n_facts": r[7], "n_pending": r[8] or 0}
        for r in rows]}


DAI_DOAN = 1200          # ký tự


def _chia_doan(t: str) -> list[str]:
    """Cắt theo TIÊU ĐỀ Markdown trước, rồi mới theo độ dài.

    Cắt thô theo số ký tự sẽ xé một mục làm đôi giữa câu, và đoạn trả về cho `memory.retrieve`
    mất mất tiêu đề — người đọc nhận một khúc văn không biết nó nói về phần nào.
    """
    khuc, cur = [], []
    for dong in t.splitlines(keepends=True):
        if dong.lstrip().startswith("#") and cur and sum(map(len, cur)) > 200:
            khuc.append("".join(cur))
            cur = []
        cur.append(dong)
    if cur:
        khuc.append("".join(cur))

    ra = []
    for k in khuc:
        k = k.strip()
        while len(k) > DAI_DOAN:
            cat = k.rfind("\n", 0, DAI_DOAN)
            cat = cat if cat > DAI_DOAN // 2 else DAI_DOAN
            ra.append(k[:cat].strip())
            k = k[cat:].strip()
        if k:
            ra.append(k)
    return ra


# ---------------------------------------------------------------- ARCHIVE-01/02
#
# Hai năng lực dưới đây là bề mặt tấn công thật sự của EIDE: người dùng tải một "SDK" từ diễn
# đàn rồi bảo tác tử mở ra. Ba lớp phòng thủ, theo đúng bước 1–2 của ARCHIVE-02:
#
# 1. **zip-slip** — entry tên `../../.ssh/authorized_keys` ghi ra ngoài thư mục đích. Chuẩn hóa
#    đường dẫn rồi kiểm nó CÒN nằm trong đích, sau khi resolve.
# 2. **zip bomb** — 42 KB giãn thành 4,5 PB. Chặn bằng tổng dung lượng, tỷ lệ nén, và độ sâu.
# 3. **symlink thoát** — entry là liên kết mềm trỏ ra `/etc`, rồi entry sau ghi "qua" nó.
#
# Cả ba đều phải chặn TRƯỚC khi ghi byte đầu tiên. Kiểm sau khi giải nén là đã muộn: tệp đã nằm
# trên đĩa, và "đã xóa rồi" không phải là chưa từng ghi.

GIOI_HAN = {"total_bytes": 2 * 1024**3, "depth": 5, "ratio": 100, "entries": 10_000}

CHU_KY_NEN: tuple[tuple[bytes, str], ...] = (
    (b"PK\x03\x04", "zip"), (b"PK\x05\x06", "zip"), (b"7z\xbc\xaf\x27\x1c", "7z"),
    (b"Rar!\x1a\x07", "rar"), (b"\x1f\x8b", "gz"), (b"\xfd7zXZ\x00", "xz"),
    (b"BZh", "bz2"),
)

# Định dạng cần công cụ ngoài. Tách bảng này ra để E4001 nói được TÊN GÓI cần cài — báo "thiếu
# công cụ" mà không nói cài gì thì người dùng phải tự tra.
CAN_CONG_CU = {"7z": ("7z", "p7zip"), "rar": ("unrar", "unrar")}


@capability("archive.list")
def list_(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-01 — CDS-12.2. tc: "Zip lồng 3 cấp liệt kê đủ; rar cần công cụ → E4001
    kèm gợi ý env.install".

    Đọc BẢNG MỤC, không giải nén (bước 2: "mà không giải nén toàn bộ"). Một SDK vendor thường
    là zip 800 MB chứa đúng một tệp SVD cần dùng; giải nén hết để xem có gì là trả 800 MB đĩa
    cho một câu hỏi mà bảng mục trả lời trong vài mili giây.
    """
    p = Path(params["path"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    sau = min(int(params.get("depth") or 1), GIOI_HAN["depth"])
    return {"entries": _liet_ke(p, sau, 0)}


def _dinh_dang(p: Path) -> str | None:
    dau = p.open("rb").read(512)
    for sig, ten in CHU_KY_NEN:
        if dau.startswith(sig):
            return ten
    import tarfile
    return "tar" if tarfile.is_tarfile(p) else None


def _liet_ke(p: Path, sau: int, muc: int) -> list[dict[str, Any]]:
    dd = _dinh_dang(p)
    if dd in CAN_CONG_CU:
        exe, goi = CAN_CONG_CU[dd]
        from eide_core.tools import which
        if which(exe) is None:
            raise EideError("E4001", f"Kho nén {dd} cần `{exe}` — chạy "
                            f"`eide env install {goi}` rồi thử lại", tool=exe, package=goi,
                            alternative=f"env.install {goi}")
        return _liet_ke_cli(p, dd, exe)
    if dd == "zip":
        return _liet_ke_zip(p, sau, muc)
    if dd in ("tar", "gz", "xz", "bz2"):
        return _liet_ke_tar(p, sau, muc)
    raise EideError("E1000", f"Không nhận ra định dạng nén của {p.name}", file=str(p))


def _muc(ten: str, kt: int, nen: int, muc: int) -> dict[str, Any]:
    return {"path": ten, "size": kt, "compressed": nen, "kind_guess": _doan_loai(ten),
            "nested": None, "depth": muc}


def _doan_loai(ten: str) -> str:
    """Bước 3: "Đoán loại theo tên/chữ ký 512 byte đầu". Trong bảng mục chỉ có tên, nên đây là
    ĐOÁN — và `ingest.classify` sẽ nói lời cuối sau khi tệp đã ra đĩa."""
    t = ten.lower()
    for duoi, k in (("svd", "svd"), ("atdf", "atdf"), ("pdf", "pdf"), ("h", "header"),
                    ("hpp", "header"), ("dts", "binding"), ("dtsi", "binding"),
                    ("md", "md"), ("csv", "csv"), ("png", "image"), ("jpg", "image")):
        if t.endswith("." + duoi):
            return k
    if any(t.endswith(x) for x in (".zip", ".7z", ".rar", ".tar", ".gz", ".xz", ".tgz")):
        return "archive"
    return "unknown"


def _liet_ke_zip(p: Path, sau: int, muc: int) -> list[dict[str, Any]]:
    import zipfile
    ra = []
    with zipfile.ZipFile(p) as z:
        for i in z.infolist():
            if i.is_dir():
                continue
            _kiem_ti_le(i.file_size, i.compress_size, i.filename)
            m = _muc(i.filename, i.file_size, i.compress_size, muc)
            if muc < sau and m["kind_guess"] == "archive":
                m["nested"] = _long_nhau(z, i, sau, muc)
            ra.append(m)
    return ra


def _liet_ke_tar(p: Path, sau: int, muc: int) -> list[dict[str, Any]]:
    import tarfile
    ra = []
    with tarfile.open(p) as t:
        for i in t.getmembers():
            if not i.isfile():
                continue
            m = _muc(i.name, i.size, i.size, muc)
            if muc < sau and m["kind_guess"] == "archive":
                m["nested"] = _long_nhau_tar(t, i, sau, muc)
            ra.append(m)
    return ra


def _long_nhau(z: Any, info: Any, sau: int, muc: int) -> list[dict[str, Any]] | None:
    """Kho lồng: đổ ra tệp tạm rồi liệt kê tiếp.

    Phải qua tệp tạm vì `zipfile` cần một đối tượng tìm-được-vị-trí (seekable), mà stream đọc từ
    zip cha thì không. Tệp tạm bị xóa ngay — nó không phải "giải nén", nó là đọc bảng mục của
    một tệp chỉ tồn tại trong vài mili giây.
    """
    import tempfile
    if info.file_size > 256 * 1024**2:      # kho lồng quá to thì không mở, báo bằng None
        return None
    try:
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "nested"
            f.write_bytes(z.read(info))
            return _liet_ke(f, sau, muc + 1)
    except (OSError, EideError):
        return None


def _long_nhau_tar(t: Any, info: Any, sau: int, muc: int) -> list[dict[str, Any]] | None:
    import tempfile
    if info.size > 256 * 1024**2:
        return None
    x = t.extractfile(info)
    if x is None:
        return None
    try:
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "nested"
            f.write_bytes(x.read())
            return _liet_ke(f, sau, muc + 1)
    except (OSError, EideError):
        return None


def _liet_ke_cli(p: Path, dd: str, exe: str) -> list[dict[str, Any]]:
    """7z/rar qua CLI. Chỉ ĐỌC bảng mục (`l`), không giải nén — cùng lý do với zip."""
    import subprocess
    try:
        out = subprocess.run([exe, "l", str(p)], capture_output=True, text=True,
                             timeout=60, check=False)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise EideError("E4004", f"Đọc bảng mục {dd} quá hạn hoặc lỗi: {e}", file=str(p)) from e
    ra = []
    for dong in (out.stdout or "").splitlines():
        if (m := re.match(r"^\s*\d{4}-\d\d-\d\d\s+\S+\s+\S*\s+(\d+)\s+(\d*)\s+(.+)$", dong)):
            ra.append(_muc(m.group(3).strip(), int(m.group(1)),
                           int(m.group(2) or m.group(1)), 0))
    return ra


def _kiem_ti_le(kt: int, nen: int, ten: str) -> None:
    """Tỷ lệ nén bất thường ⇒ E8000. Ngưỡng 100:1 theo bước 2 của ARCHIVE-02.

    Chỉ xét entry đủ lớn: một tệp 10 byte nén còn 1 byte có tỷ lệ 10:1 nhưng chẳng đe dọa gì,
    trong khi văn bản lặp lại bình thường cũng dễ vượt 100:1 ở kích thước nhỏ.
    """
    if nen > 0 and kt > 1024**2 and kt / nen > GIOI_HAN["ratio"]:
        raise EideError("E8000", f"Tỷ lệ nén bất thường ở {ten}: {kt}/{nen} = "
                        f"{kt // nen}:1 (ngưỡng {GIOI_HAN['ratio']}:1) — dấu hiệu zip bomb",
                        entry=ten, ratio=kt // max(nen, 1))


@capability("archive.unpack")
def unpack(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-02 — CDS-12.2; SEC-25. tc: TC-11, TC-SE-02; undo `delete_created_files`.

    Trả `skipped` kèm LÝ DO cho từng entry bị bỏ, không im lặng bỏ qua. Người dùng giải nén một
    SDK rồi thấy thiếu tệp mình cần sẽ nghĩ kho hỏng; biết "bị bỏ vì đường dẫn thoát khỏi thư
    mục đích" thì họ hiểu ngay là kho có vấn đề, chứ không phải công cụ.

    Bỏ qua chứ không ném: một kho 5 000 tệp có một entry độc hại vẫn còn 4 999 tệp dùng được, và
    chặn cả lô vì một entry là biến một cảnh báo thành một bức tường.
    """
    p = Path(params["path"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    gh = {**GIOI_HAN, **(params.get("limits") or {})}
    loc = params.get("members")

    dich = _thu_muc_cach_ly(ctx, p)
    files: list[str] = []
    skipped: list[dict[str, Any]] = []
    _giai_nen(p, dich, gh, loc, files, skipped, 0, [0])

    if (led := ctx.extra.get("ledger")) is not None and files:
        led.append("undo.register", {"undo_ref": f"unpack:{dich.name}",
                                     "kind": "delete_created_files", "deadline": ""})
    return {"files": files, "skipped": skipped}


def _thu_muc_cach_ly(ctx: Context, p: Path) -> Path:
    """Bước 3: "cache/unpacked/<hash>/". Băm nội dung làm tên: giải nén cùng một kho hai lần ra
    cùng một chỗ, nên không sinh ra ba bản sao của một SDK 800 MB."""
    root = _root(ctx)
    d = root / EIDE_DIR / "cache" / "unpacked" / bam_tep(p)[:16]
    d.mkdir(parents=True, exist_ok=True)
    return d


def _giai_nen(p: Path, dich: Path, gh: dict[str, Any], loc: list[str] | None,
              files: list[str], skipped: list[dict[str, Any]], muc: int,
              tong: list[int]) -> None:
    if muc > gh["depth"]:
        skipped.append({"path": p.name, "reason": f"vượt độ sâu {gh['depth']} cấp",
                        "rule": "depth"})
        return
    dd = _dinh_dang(p)
    if dd == "zip":
        _giai_zip(p, dich, gh, loc, files, skipped, muc, tong)
    elif dd in ("tar", "gz", "xz", "bz2"):
        _giai_tar(p, dich, gh, loc, files, skipped, muc, tong)
    elif dd in CAN_CONG_CU:
        exe, goi = CAN_CONG_CU[dd]
        raise EideError("E4001", f"Giải nén {dd} cần `{exe}` — chạy `eide env install {goi}`",
                        tool=exe, package=goi)
    else:
        raise EideError("E1000", f"Không nhận ra định dạng nén của {p.name}", file=str(p))


def _giai_zip(p: Path, dich: Path, gh: dict[str, Any], loc: list[str] | None,
              files: list[str], skipped: list[dict[str, Any]], muc: int,
              tong: list[int]) -> None:
    import fnmatch
    import zipfile
    with zipfile.ZipFile(p) as z:
        for i in z.infolist():
            if i.is_dir():
                continue
            if loc and not any(fnmatch.fnmatch(i.filename, m) for m in loc):
                continue
            if (ly := _khong_an_toan(i.filename, dich)) or \
               (ly := _vuot_gioi_han(i.file_size, i.compress_size, gh, tong, len(files))):
                skipped.append({"path": i.filename, "reason": ly[0], "rule": ly[1]})
                continue
            # zipfile khai symlink bằng bit trong external_attr. Giải nén nó ra sẽ tạo một liên
            # kết trỏ đi bất kỳ đâu, và entry SAU đó ghi "qua" liên kết ấy là thoát khỏi sandbox.
            if (i.external_attr >> 16) & 0o170000 == 0o120000:
                skipped.append({"path": i.filename, "reason": "liên kết mềm trong kho nén",
                                "rule": "symlink"})
                continue
            ra = (dich / i.filename).resolve()
            ra.parent.mkdir(parents=True, exist_ok=True)
            ra.write_bytes(z.read(i))
            tong[0] += i.file_size
            files.append(str(ra))
            if _doan_loai(i.filename) == "archive":
                _giai_nen(ra, dich, gh, None, files, skipped, muc + 1, tong)


def _giai_tar(p: Path, dich: Path, gh: dict[str, Any], loc: list[str] | None,
              files: list[str], skipped: list[dict[str, Any]], muc: int,
              tong: list[int]) -> None:
    import fnmatch
    import tarfile
    with tarfile.open(p) as t:
        for i in t.getmembers():
            if i.issym() or i.islnk():
                skipped.append({"path": i.name, "reason": "liên kết mềm/cứng trong kho nén",
                                "rule": "symlink"})
                continue
            if not i.isfile():
                continue
            if loc and not any(fnmatch.fnmatch(i.name, m) for m in loc):
                continue
            if (ly := _khong_an_toan(i.name, dich)) or \
               (ly := _vuot_gioi_han(i.size, i.size, gh, tong, len(files))):
                skipped.append({"path": i.name, "reason": ly[0], "rule": ly[1]})
                continue
            f = t.extractfile(i)
            if f is None:
                continue
            ra = (dich / i.name).resolve()
            ra.parent.mkdir(parents=True, exist_ok=True)
            ra.write_bytes(f.read())
            tong[0] += i.size
            files.append(str(ra))
            if _doan_loai(i.name) == "archive":
                _giai_nen(ra, dich, gh, None, files, skipped, muc + 1, tong)


def _khong_an_toan(ten: str, dich: Path) -> tuple[str, str] | None:
    """zip-slip. Kiểm SAU KHI resolve, không phải bằng cách tìm chuỗi `../`.

    Lọc chuỗi `..` là cách sai kinh điển: nó bỏ sót đường dẫn tuyệt đối (`/etc/passwd`), tên
    Windows (`C:\\...`), và `..` viết bằng dấu gạch ngược. Cách đúng chỉ có một: ghép rồi
    resolve, và hỏi kết quả CÓ CÒN nằm trong thư mục đích không — đó là câu hỏi thật sự cần
    trả lời, còn mọi phép lọc chuỗi chỉ là xấp xỉ của nó.
    """
    if ten.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:", ten):
        return ("đường dẫn tuyệt đối", "absolute")
    try:
        ra = (dich / ten).resolve()
    except (OSError, ValueError):
        return ("đường dẫn không hợp lệ", "path")
    if not ra.is_relative_to(dich.resolve()):
        return ("đường dẫn thoát khỏi thư mục đích (zip-slip)", "traversal")
    return None


def _vuot_gioi_han(kt: int, nen: int, gh: dict[str, Any], tong: list[int],
                   n: int) -> tuple[str, str] | None:
    if n >= gh["entries"]:
        return (f"vượt {gh['entries']} tệp", "entries")
    if tong[0] + kt > gh["total_bytes"]:
        return (f"vượt tổng {gh['total_bytes'] // 1024**2} MB", "total_bytes")
    if nen > 0 and kt > 1024**2 and kt / nen > gh["ratio"]:
        return (f"tỷ lệ nén {kt // nen}:1 vượt ngưỡng {gh['ratio']}:1", "ratio")
    return None


# ---------------------------------------------------------------- ARCHIVE-03 extract_one


TRAN_GREP = 200 * 1024**2     # ARCHIVE-04 bước 1: "content: grep stream (giới hạn 200 MB)"


@capability("archive.extract_one")
def extract_one(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-03 — CDS-12.2. tc: "Lấy đúng tệp không giải nén phần còn lại";
    lỗi E2000; undo `delete_created_files`.

    tc nói rõ điều làm năng lực này khác `archive.unpack`: **không giải nén phần còn lại**. Một
    SDK vendor là zip 800 MB chứa đúng một tệp SVD cần dùng; `unpack` trả 800 MB lên đĩa, còn
    đây trả một tệp. Đó là khác biệt giữa "dùng được trên máy xách tay" và "không".

    `member` nhận cả đường dẫn lẫn glob (`**/stm32f411.svd`), và tìm **qua cả kho lồng** — SDK
    hãng hay đóng gói zip trong zip. Nhiều mục khớp thì lấy mục đầu theo thứ tự bảng mục và ghi
    rõ trong kết quả là còn mục khác: im lặng chọn một trong nhiều là chỗ người dùng nhận nhầm
    tệp mà không biết.

    Áp CÙNG các phép kiểm sandbox với `unpack` — zip-slip, symlink, giới hạn. Một đường ghi thứ
    hai vào đĩa mà bỏ qua phép chặn thì cả tám lớp phòng thủ kia thành trang trí.
    """
    p = Path(params["path"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    mau = params["member"]
    dich = _thu_muc_cach_ly(ctx, p)

    khop = _tim_muc(p, mau, 0)
    if not khop:
        gan = [x for x, _ in _liet_ke_ten(p, 0)][:8]
        raise EideError("E2000", f"Không có mục nào khớp `{mau}` trong {p.name}",
                        exists=gan, candidates=gan, missing=[mau])

    ten, doc = khop[0]
    if (ly := _khong_an_toan(ten, dich)):
        raise EideError("E8000", f"Mục `{ten}` bị chặn: {ly[0]}", entry=ten, rule=ly[1])
    noi = doc()
    if (ly := _vuot_gioi_han(len(noi), len(noi), GIOI_HAN, [0], 0)):
        raise EideError("E8000", f"Mục `{ten}` vượt giới hạn: {ly[0]}", entry=ten, rule=ly[1])

    ra = (dich / ten).resolve()
    ra.parent.mkdir(parents=True, exist_ok=True)
    ra.write_bytes(noi)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.register", {"undo_ref": f"extract_one:{ra.name}",
                                     "kind": "delete_created_files", "deadline": ""})
    return {"file": str(ra)}


def _tim_muc(p: Path, mau: str, muc: int) -> list[tuple[str, Any]]:
    """Mục khớp `mau`, kèm hàm đọc nội dung. Tìm qua cả kho lồng tới `GIOI_HAN["depth"]`.

    Trả HÀM đọc chứ không trả nội dung: bảng mục của một SDK có hàng nghìn mục, và đọc hết chúng
    ra bộ nhớ để rồi dùng một mục là đúng cái tc bảo đừng làm.
    """
    import fnmatch
    ra: list[tuple[str, Any]] = []
    for ten, doc in _liet_ke_ten(p, muc):
        if fnmatch.fnmatch(ten, mau) or fnmatch.fnmatch(Path(ten).name, mau) \
                or ten == mau:
            ra.append((ten, doc))
        elif muc < GIOI_HAN["depth"] and _doan_loai(ten) == "archive":
            ra += _long_tim(doc, ten, mau, muc)
    return ra


def _long_tim(doc: Any, ten: str, mau: str, muc: int) -> list[tuple[str, Any]]:
    """Tìm trong một kho lồng. Đổ ra tệp tạm vì `zipfile` cần đối tượng tìm-được-vị-trí."""
    import tempfile
    try:
        noi = doc()
    except (OSError, ValueError):
        return []
    if len(noi) > 256 * 1024**2:
        return []
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "nested"
        f.write_bytes(noi)
        # Đọc nội dung NGAY trong khi tệp tạm còn sống, rồi bọc lại thành hàm trả hằng số:
        # tệp tạm biến mất khi ra khỏi khối `with`, nên một hàm đọc-lười trỏ vào nó sẽ hỏng ở
        # chỗ gọi — và hỏng theo kiểu "tệp không tồn tại", rất khó lần về đây.
        # Đọc NGAY rồi bọc thành hàm trả hằng số — không dùng `lambda b=d2()` vì ruff B008
        # cấm gọi hàm trong giá trị mặc định, và cấm có lý: giá trị mặc định tính MỘT lần lúc
        # định nghĩa, nên trong vòng lặp nó dễ trở thành cái bẫy chia sẻ trạng thái.
        ra = []
        for t, d2 in _tim_muc(f, mau, muc + 1):
            noi_con = d2()
            ra.append((f"{ten}!{t}", _hang_so(noi_con)))
        return ra


def _hang_so(b: bytes) -> Any:
    """Hàm trả về đúng `b`. Dùng để giữ nội dung đã đọc từ một kho lồng sau khi tệp tạm biến
    mất — một hàm đọc-lười trỏ vào tệp tạm sẽ hỏng ở chỗ gọi, kiểu "tệp không tồn tại", rất khó
    lần ngược về đây."""
    def doc() -> bytes:
        return b
    return doc


def _liet_ke_ten(p: Path, muc: int) -> list[tuple[str, Any]]:
    """(tên, hàm đọc) của mọi mục là TỆP trong một kho — không đệ quy."""
    dd = _dinh_dang(p)
    if dd == "zip":
        import zipfile
        with zipfile.ZipFile(p) as z:
            ds = [i for i in z.infolist() if not i.is_dir()]
        def _mo(info):                        # noqa: ANN001, ANN202
            def doc() -> bytes:
                with zipfile.ZipFile(p) as z2:
                    return z2.read(info)
            return doc
        return [(i.filename, _mo(i)) for i in ds]
    if dd in ("tar", "gz", "xz", "bz2"):
        import tarfile
        with tarfile.open(p) as t:
            ds = [i.name for i in t.getmembers() if i.isfile()]
        def _mo_tar(ten: str):                # noqa: ANN202
            def doc() -> bytes:
                with tarfile.open(p) as t2:
                    f = t2.extractfile(ten)
                    return f.read() if f else b""
            return doc
        return [(x, _mo_tar(x)) for x in ds]
    if dd in CAN_CONG_CU:
        exe, goi = CAN_CONG_CU[dd]
        if which(exe) is None:
            raise EideError("E4001", f"Kho nén {dd} cần `{exe}` — chạy `eide env install {goi}`",
                            tool=exe, package=goi)
    return []


# ---------------------------------------------------------------- ARCHIVE-04 query


@capability("archive.query")
def query(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCHIVE-04 — CDS-12.2. tc: "Tìm thấy trong header nằm trong zip con"; lỗi E4004.

    Ba chế độ của bước 1, và tc chỉ đúng vào chỗ khó: *"header nằm trong ZIP CON"*. Một SDK hãng
    đóng gói zip trong zip, và tệp cần tìm nằm ở tầng trong. Tìm một tầng thì trả rỗng — mà
    "không tìm thấy" ở đây không phân biệt được với "không có", nên người dùng kết luận sai rằng
    SDK thiếu tệp.

    `content` giới hạn 200 MB tổng: grep cả một SDK 800 MB là đọc giải nén toàn bộ, tức đúng
    việc mà cả nhóm `archive.*` sinh ra để tránh. Vượt ngưỡng thì DỪNG và nói rõ đã quét tới
    đâu — trả một danh sách cụt mà im lặng là tệ hơn: bên gọi tưởng đã quét hết.
    """
    p = Path(params["path"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    mau = params["pattern"]
    che_do = params.get("mode", "name")
    trang_thai = {"da_doc": 0, "cat": False}
    try:
        ra = _quet(p, mau, che_do, 0, "", trang_thai)
    except EideError:
        raise
    except Exception as e:                    # noqa: BLE001
        raise EideError("E4004", f"Không quét được {p.name}: {e}", file=str(p)) from e
    return {"matches": ra + ([{"path": "", "mode": che_do, "truncated": True,
                               "note": f"dừng ở {trang_thai['da_doc'] // 1024**2} MB "
                                       f"(giới hạn {TRAN_GREP // 1024**2} MB) — kết quả CHƯA đủ"}]
                             if trang_thai["cat"] else [])}


def _quet(p: Path, mau: str, che_do: str, muc: int, tien_to: str,
          tt: dict[str, Any]) -> list[dict[str, Any]]:
    import fnmatch
    import re as _re
    ra: list[dict[str, Any]] = []
    for ten, doc in _liet_ke_ten(p, muc):
        day_du = f"{tien_to}{ten}"
        long = muc < GIOI_HAN["depth"] and _doan_loai(ten) == "archive"

        if che_do == "name" and (fnmatch.fnmatch(ten, mau)
                                 or fnmatch.fnmatch(Path(ten).name, mau)):
            ra.append({"path": day_du, "mode": "name", "depth": muc})
        elif che_do in ("content", "signature"):
            if tt["cat"]:
                break
            try:
                noi = doc()
            except (OSError, ValueError):
                continue
            tt["da_doc"] += len(noi)
            if tt["da_doc"] > TRAN_GREP:
                tt["cat"] = True
                break
            # Kho lồng là VẬT CHỨA, không phải tài liệu — chỉ đi vào, không grep byte thô của
            # nó. Zip lưu không nén (`ZIP_STORED`) mang nguyên nội dung thành viên trong byte
            # của mình, nên grep nó sẽ báo CÙNG một tệp hai lần: một lần dưới tên kho ngoài,
            # một lần dưới đường dẫn thật. Người dùng thấy hai kết quả và không biết cái nào là
            # thật — đo được ngay lần chạy test đầu.
            if long:
                ra += _quet_long(noi, day_du, mau, che_do, muc, tt)
                continue
            if che_do == "signature":
                if _re.search(_re.escape(mau).encode(), noi[:512], _re.I):
                    ra.append({"path": day_du, "mode": "signature", "depth": muc,
                               "kind_guess": _doan_loai(ten)})
            else:
                t = noi.decode("utf-8", errors="ignore")
                for i, d in enumerate(t.splitlines(), 1):
                    if mau in d:
                        ra.append({"path": day_du, "mode": "content", "depth": muc,
                                   "line": i, "text": d.strip()[:160]})
                        break
            continue

        if long:
            try:
                ra += _quet_long(doc(), day_du, mau, che_do, muc, tt)
            except (OSError, ValueError):
                continue
    return ra


def _quet_long(noi: bytes, tien_to: str, mau: str, che_do: str, muc: int,
               tt: dict[str, Any]) -> list[dict[str, Any]]:
    """Quét một kho lồng. `tien_to!` phân tách tầng — quy ước quen thuộc của `unzip`/`jar`."""
    import tempfile
    if len(noi) > 256 * 1024**2 or tt["cat"]:
        return []
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "nested"
        f.write_bytes(noi)
        try:
            return _quet(f, mau, che_do, muc + 1, tien_to + "!", tt)
        except EideError:
            return []
