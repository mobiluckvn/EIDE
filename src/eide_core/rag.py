"""RagIndex — chỉ mục đoạn văn bản trong `index.sqlite`. WI-012; DDD-14 §2 RagChunk, §5 migration 0003.

`index.sqlite` là cơ sở dữ liệu THỨ HAI, tách khỏi `store.sqlite` có chủ ý (DDD-14 §5): chỉ mục
dựng lại được từ nguồn, còn store thì không. Xóa `index/` là thao tác an toàn; xóa `store/` là
mất tri thức. Vì thế ở đây không có thao tác nào không hoàn tác được.

## Vì sao FTS5 chứ chưa phải embedding

`RagChunk` có cột `embedding` (DDD-14: "float32[] qua Gateway") và CXD-10 §4.5 gọi bước này là
Graph-RAG. Nhưng đường vào của mọi truy vấn ở M1 là một **IRI** — `chip:st.stm32f411ce/periph:I2C1`
— chứ không phải một câu hỏi ngôn ngữ tự nhiên. Với đầu vào ấy, `graph_nodes` (khớp chính xác)
và FTS5 (khớp từ khóa) trả lời đúng và rẻ; nhúng thêm một lời gọi mô hình cho mỗi đoạn chỉ để
so cosine với một chuỗi định danh là tốn tiền mà không thêm thông tin.

Cột `embedding` vẫn ở đó và `them()` nhận nó, để `view.rag_ask` (câu hỏi ngôn ngữ tự nhiên, mốc
M2) dùng cùng bảng mà không phải di trú. Xem DEVIATIONS DEV-042.
"""
from __future__ import annotations

import json
import re
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from eide_core import store

# FTS5 coi các ký tự này là cú pháp truy vấn, không phải chữ. Một IRI có đủ cả `:` lẫn `/` lẫn
# `.`, nên đưa thẳng vào `MATCH` sẽ ném `fts5: syntax error` — hoặc tệ hơn, khớp nhầm.
_TACH = re.compile(r"[^0-9A-Za-zÀ-ỹ_]+")


def tach_tu(s: str) -> list[str]:
    return [t for t in _TACH.split(s) if t]


@dataclass
class Doan:
    """Một RagChunk — DDD-14 §2."""

    id: str
    source_id: str
    text: str
    locator: dict[str, Any] | None = None
    keywords: str = ""
    graph_nodes: list[str] = field(default_factory=list)
    embedding: bytes | None = None
    model: str = ""


class RagIndex:
    """Đóng gói `index.sqlite`. Mở/đóng theo từng thao tác, không giữ kết nối lâu."""

    def __init__(self, project_dir: Path | str) -> None:
        self.path = store.index_path(project_dir)

    def _mo(self) -> sqlite3.Connection:
        return store.open_index(self.path)

    # ---- ghi
    def them(self, doan: list[Doan]) -> int:
        """Thêm đoạn và đồng bộ bảng FTS5.

        `rag_chunk_fts` là bảng ngoài (`content='rag_chunk'`), nên nó KHÔNG tự cập nhật khi
        `rag_chunk` đổi — phải chèn tay theo rowid. Bỏ bước này thì mọi truy vấn FTS trả rỗng
        trong khi bảng chính đầy dữ liệu, và triệu chứng ấy trông y hệt "chưa lập chỉ mục".
        """
        if not doan:
            return 0
        with self._mo() as c:
            for d in doan:
                kw = d.keywords or " ".join(sorted({*tach_tu(d.text), *(t for n in d.graph_nodes
                                                                        for t in tach_tu(n))}))
                c.execute(
                    "INSERT OR REPLACE INTO rag_chunk (id, source_id, locator, text, embedding,"
                    " keywords, graph_nodes, model) VALUES (?,?,?,?,?,?,?,?)",
                    (d.id, d.source_id, json.dumps(d.locator, ensure_ascii=False) if d.locator else None,
                     d.text, d.embedding, kw, json.dumps(d.graph_nodes, ensure_ascii=False), d.model))
                rid = c.execute("SELECT rowid FROM rag_chunk WHERE id=?", (d.id,)).fetchone()[0]
                c.execute("INSERT INTO rag_chunk_fts (rowid, text, keywords) VALUES (?,?,?)",
                          (rid, d.text, kw))
            c.commit()
        return len(doan)

    def xoa_nguon(self, source_id: str) -> int:
        with self._mo() as c:
            rids = [r[0] for r in c.execute("SELECT rowid FROM rag_chunk WHERE source_id=?",
                                            (source_id,)).fetchall()]
            for rid in rids:
                c.execute("DELETE FROM rag_chunk_fts WHERE rowid=?", (rid,))
            c.execute("DELETE FROM rag_chunk WHERE source_id=?", (source_id,))
            c.commit()
        return len(rids)

    def dem(self) -> int:
        with self._mo() as c:
            return c.execute("SELECT count(*) FROM rag_chunk").fetchone()[0]

    # ---- đọc
    def theo_iri(self, iris: list[str], k: int = 8) -> list[dict[str, Any]]:
        """Đoạn có IRI trong `graph_nodes` — khớp CHÍNH XÁC, điểm 1,0.

        Đây là đường chính của MEMORY-03: đầu vào là IRI, và một đoạn đã được đánh dấu nói về
        IRI ấy thì không cần đoán bằng từ khóa nữa.
        """
        if not iris:
            return []
        ra: dict[str, dict[str, Any]] = {}
        with self._mo() as c:
            for r in c.execute("SELECT id, source_id, locator, text, graph_nodes FROM rag_chunk"):
                nodes = json.loads(r[4] or "[]")
                khop = [i for i in iris if i in nodes]
                if khop:
                    ra[r[0]] = {"id": r[0], "source_id": r[1],
                                "locator": json.loads(r[2]) if r[2] else None,
                                "text": r[3], "score": 1.0, "cach": "graph_nodes",
                                "khop": khop}
        return sorted(ra.values(), key=lambda x: x["id"])[:k]

    def tim(self, truy_van: str, k: int = 8) -> list[dict[str, Any]]:
        """FTS5 theo từ khóa. Điểm chuẩn hóa về (0, 1] từ `bm25()` (nhỏ hơn = khớp hơn)."""
        tu = tach_tu(truy_van)
        if not tu:
            return []
        # Nối bằng OR: một IRI tách ra thành `chip st stm32f411ce periph I2C1`, và đòi đủ mọi
        # thành phần thì một đoạn nói về I2C1 mà không nhắc tên chip sẽ trượt.
        q = " OR ".join(f'"{t}"' for t in tu)
        with self._mo() as c:
            rows = c.execute(
                "SELECT r.id, r.source_id, r.locator, r.text, bm25(rag_chunk_fts) AS s"
                " FROM rag_chunk_fts f JOIN rag_chunk r ON r.rowid = f.rowid"
                " WHERE rag_chunk_fts MATCH ? ORDER BY s LIMIT ?", (q, k)).fetchall()
        return [{"id": r[0], "source_id": r[1], "locator": json.loads(r[2]) if r[2] else None,
                 "text": r[3], "score": round(1.0 / (1.0 + abs(r[4])), 4), "cach": "fts"}
                for r in rows]

    def retrieve(self, iris: list[str], k: int = 8) -> list[dict[str, Any]]:
        """`RagIndex.retrieve theo IRI` (MEMORY-03 bước 1): khớp chính xác trước, từ khóa bù sau.

        Không trộn điểm của hai cách vào một thang: khớp `graph_nodes` là sự thật đã ghi lúc lập
        chỉ mục, còn điểm FTS là ước lượng. Xếp nhóm chính xác lên trước và giữ nguyên cột `cach`
        để bên đọc biết mình đang nhìn cái nào.
        """
        chinh_xac = self.theo_iri(iris, k)
        if len(chinh_xac) >= k:
            return chinh_xac
        da_co = {d["id"] for d in chinh_xac}
        bu = [d for d in self.tim(" ".join(iris), k * 2) if d["id"] not in da_co]
        return chinh_xac + bu[: k - len(chinh_xac)]
