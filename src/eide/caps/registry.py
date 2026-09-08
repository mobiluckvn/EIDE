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
