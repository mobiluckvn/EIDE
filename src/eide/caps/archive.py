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

from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# Bảng `kind → (tier, extractor)` của INGEST-01 bước 2, nguyên văn: "svd/atdf/edc/binding/header:
# gold; pdf hãng: silver; ảnh: silver-vision; readme/md: context".
#
# `kind` phải thuộc enum của DDD-14 §2 Source — không được đặt thêm tên mới ở đây, vì cột ấy có
# ràng buộc và vì `search.*`/`extract.*` sau này lọc theo đúng enum ấy.
BANG_KIND: dict[str, tuple[str, str | None]] = {
    "svd":      ("gold", "extract.svd"),
    "atdf":     ("gold", "extract.atdf"),
    "edc":      ("gold", "extract.edc"),
    "binding":  ("gold", "extract.binding"),
    "header":   ("gold", "extract.header"),
    "pdf":      ("silver", "extract.pdf_layout"),
    "image":    ("silver", "extract.image"),
    "kicad":    ("silver", "extract.kicad"),
    "netlist":  ("silver", "extract.netlist"),
    "csv":      ("bronze", "extract.csv"),
    "html":     ("bronze", "extract.html"),
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
    """Spec: INGEST-01 — CDS-12.2. tc: TC-01 "≥ 95% đúng trên bộ 10 tệp".

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
    """Spec: INGEST-02 — CDS-12.2; DDD-14 §2 Source (`sha256 TEXT UNIQUE`). tc: "Tệp đã có →
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
    """Spec: INGEST-03 — CDS-12.2. tc: "Truy vấn từ khóa tìm thấy".

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
