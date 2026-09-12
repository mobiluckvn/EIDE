"""Composer — dựng ContextBundle theo lớp C0–C7. WI-006.

Spec: CXD-10 §2 (tám lớp), §2.1 (schema ContextBundle), §3 (ngân sách theo vai trò, thứ tự
cắt), §4.1 (thuật toán compose), §5 (nén và cắt), §7 (tràn → E5001); PRS-16 §1 (prompt vai
trò); MEM-11 §6 (prompt phủ định); API-15 §5 sự kiện `context.bundle`.

Ngân sách, thứ tự cắt và hằng ước lượng token đọc từ `docs/spec/context/budgets.json` — sinh
từ `cxd.js`, không viết cứng ở đây (DEVIATIONS DEV-029).

## Vì sao cắt chứ không "tóm tắt cho vừa"

CXD-10 §3 đặt thứ tự cắt rõ ràng và để C1, C2 ở ngoài. Đó không phải một chi tiết kỹ thuật:
C1 là prompt vai trò (gồm cả các câu KHÔNG ĐƯỢC), C2 là ràng buộc dự án (chân cấm, ngân sách
RAM/Flash, cờ nhạy cảm). Một bộ nén "thông minh" tự quyết định bỏ bớt hai lớp ấy khi chật chỗ
sẽ lấy đi đúng phần giữ cho mô hình không làm bậy — và nó sẽ làm thế vào đúng lúc ngữ cảnh
đang căng, tức lúc tác vụ khó nhất.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir

LOP = ("C0", "C1", "C2", "C3", "C4", "C5", "C6", "C7")


@lru_cache(maxsize=1)
def cau_hinh() -> dict[str, Any]:
    return json.loads((spec_dir() / "context" / "budgets.json").read_text(encoding="utf-8"))


def uoc_token(text: str) -> int:
    """CXD-10 §3: "1 token ≈ 3,5 ký tự tiếng Việt có dấu, 4 ký tự tiếng Anh".

    Đây là ƯỚC LƯỢNG dùng khi adapter không có `count_tokens`. Lấy 3,5 (mức tiếng Việt) chứ
    không phải 4: ước THẤP hơn thực tế sẽ để ngân sách bị vượt mà không ai báo, và lỗi ấy chỉ
    lộ ra ở phía nhà cung cấp, sau khi đã tốn tiền.
    """
    return max(1, round(len(text) / cau_hinh()["chars_per_token"])) if text else 0


@dataclass
class Khoi:
    """Một khối ngữ cảnh — CXD-10 §2.1."""

    layer: str
    text: str
    sources: list[str] = field(default_factory=list)
    cacheable: bool = False

    @property
    def tokens(self) -> int:
        return uoc_token(self.text)

    @property
    def cut_priority(self) -> int:
        return int(cau_hinh()["cut_priority"].get(self.layer, 5))

    @property
    def hash(self) -> str:
        return hashlib.sha256(self.text.encode("utf-8")).hexdigest()[:16]

    def as_dict(self) -> dict[str, Any]:
        return {"layer": self.layer, "text": self.text, "tokens": self.tokens,
                "sources": list(self.sources), "cut_priority": self.cut_priority,
                "cacheable": self.cacheable, "hash": self.hash}


@dataclass
class ContextBundle:
    role: str
    task_ref: str = ""
    blocks: list[Khoi] = field(default_factory=list)
    compressions: list[str] = field(default_factory=list)
    model_id: str = ""

    project_dir: Path | None = None

    @property
    def budget(self) -> dict[str, Any]:
        """Ngân sách của vai trò — bản của DỰ ÁN thắng bản của bản cài.

        `.eide/roles.yaml` (DDD-14 §yaml) là chỗ một dự án nới ngân sách cho một vai trò mà
        KHÔNG đụng vào `docs/spec/` — thứ dùng chung cho mọi dự án. Cùng khuôn với `models.yaml`
        đã làm từ M0: chép bản mặc định vào dự án, rồi đọc bản dự án trước.

        Ghi đè chỉ trường `total`: các lớp C0…C7 là cấu trúc của CXD-10 §3, không phải chỗ để
        mỗi dự án tự nghĩ ra một cách chia khác — nới TỔNG thì hợp lý, đổi tỉ lệ giữa các lớp
        thì làm `vua_ngan_sach` cắt sai thứ tự.
        """
        b = cau_hinh()["budget"].get(self.role)
        if b is None:
            raise EideError("E1001", f"Vai trò {self.role} không có ngân sách trong CXD-10 §3")
        rieng = _ngan_sach_du_an(self.project_dir, self.role)
        return {**b, "total": rieng} if rieng else b

    @property
    def total_tokens(self) -> int:
        return sum(k.tokens for k in self.blocks)

    @property
    def hash(self) -> str:
        h = hashlib.sha256()
        for k in self.blocks:
            h.update(f"{k.layer}:{k.hash}".encode())
        return h.hexdigest()[:16]

    def add(self, layer: str, text: str, sources: list[str] | None = None,
            cacheable: bool = False) -> None:
        if layer not in LOP:
            raise EideError("E1000", f"Lớp ngữ cảnh không có trong CXD-10 §2: {layer}")
        if not text:
            return
        self.blocks.append(Khoi(layer, text, sources or [], cacheable))

    def per_layer(self) -> dict[str, int]:
        ra: dict[str, int] = {}
        for k in self.blocks:
            ra[k.layer] = ra.get(k.layer, 0) + k.tokens
        return ra

    def sources(self) -> list[str]:
        ra: list[str] = []
        for k in self.blocks:
            for s in k.sources:
                if s not in ra:
                    ra.append(s)
        return ra

    def as_dict(self) -> dict[str, Any]:
        return {"role": self.role, "task_ref": self.task_ref, "model_id": self.model_id,
                "blocks": [k.as_dict() for k in self.blocks], "budget": self.budget,
                "total_tokens": self.total_tokens, "hash": self.hash,
                "compressions": list(self.compressions)}

    def text(self) -> str:
        """Ghép thành một chuỗi theo THỨ TỰ LỚP, không theo thứ tự thêm vào.

        C1 phải đứng đầu (CXD-10 §2: "tĩnh; ĐỨNG ĐẦU; cache") vì PRS-16 §1 quy tắc (4) dựa
        vào đó: mô hình tuân thủ điều cấm tốt hơn khi điều cấm đứng trước.
        """
        thu_tu = {c: i for i, c in enumerate(("C1", "C2", "C0", "C3", "C4", "C5", "C6", "C7"))}
        sap = sorted(self.blocks, key=lambda k: thu_tu.get(k.layer, 99))
        return "\n\n".join(k.text for k in sap)

    # ---- §5 nén và cắt
    def vua_ngan_sach(self) -> ContextBundle:
        """Cắt theo `cut_priority` tăng dần cho tới khi vừa tổng ngân sách (CXD-10 §3, §5).

        Cắt CẢ KHỐI chứ không cắt giữa chừng: một bảng fact bị cắt đôi vẫn trông như một bảng
        fact, và mô hình sẽ dùng nửa còn lại như thể đó là tất cả. Thà thiếu hẳn một lớp và
        ghi vào `compressions` để người đọc nhật ký biết.
        """
        tran = int(self.budget["total"])
        while self.total_tokens > tran:
            co_the_cat = [k for k in self.blocks if k.cut_priority < 9]
            if not co_the_cat:
                break                                  # chỉ còn C1/C2 — không bao giờ cắt
            # `cut_priority` nhỏ = cắt TRƯỚC (CXD-10 §3). Cùng mức thì bỏ khối NẶNG nhất, để
            # mỗi lần cắt lấy lại được nhiều chỗ nhất và số lần cắt là ít nhất.
            bo = min(co_the_cat, key=lambda k: (k.cut_priority, -k.tokens))
            self.blocks.remove(bo)
            self.compressions.append(f"cut:{bo.layer}")
        return self

    def kiem_tran(self) -> None:
        """CXD-10 §7: vượt ngân sách sau khi đã cắt ⇒ KHÔNG GỌI mô hình (E5001).

        Không gọi chứ không phải gọi rồi mong nhà cung cấp bỏ qua: một lượt vượt cửa sổ sẽ bị
        cắt ở đầu kia theo cách ta không kiểm soát — thường là cắt phần cuối, tức phần động và
        quan trọng nhất — rồi trả về một câu trả lời trông hợp lý mà thiếu dữ kiện.
        """
        tran = int(self.budget["total"])
        if self.total_tokens > tran:
            raise EideError("E5001", f"Ngữ cảnh {self.total_tokens} token vượt ngân sách {tran} "
                                     f"của vai trò {self.role} sau khi đã cắt",
                            role=self.role, tokens=self.total_tokens, budget=tran,
                            per_layer=self.per_layer())

    def ghi_ledger(self, led: Ledger | None) -> None:
        if led is None:
            return
        led.append("context.bundle", {"role": self.role, "hash": self.hash,
                                      "tokens": self.per_layer(), "sources": self.sources(),
                                      "compressions": list(self.compressions),
                                      "model_id": self.model_id})


def output_max(role: str) -> int:
    c = cau_hinh()["output_max"]
    return int(c.get(role, c["_mac_dinh"]))

def _ngan_sach_du_an(root: Path | None, role: str) -> int | None:
    """`budget.input` của vai trò trong `.eide/roles.yaml`, hoặc None.

    Không có tệp, tệp hỏng, hay không có vai trò ấy → None và dùng bản cài. Một tệp cấu hình
    sai cú pháp KHÔNG được làm hỏng mọi lượt gọi mô hình: ngân sách là thứ tinh chỉnh, còn chạy
    được hay không thì không nên phụ thuộc vào nó.
    """
    if root is None:
        return None
    f = Path(root) / ".eide" / "roles.yaml"
    if not f.is_file():
        return None
    try:
        import yaml
        d = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    except Exception:  # noqa: BLE001 — xem giải thích ngay trên
        return None
    v = ((d.get("roles") or {}).get(role) or {}).get("budget") or {}
    n = v.get("input")
    return int(n) if isinstance(n, (int, float)) and n > 0 else None
