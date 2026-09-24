"""Tra ISA của một mã chip từ manifest. Spec: TGT-19 §2 (`family_patterns`); AAD-33 §2.2, §8.2.

Một chỗ duy nhất đọc `family_patterns`, và đó là toàn bộ lý do tệp này tồn tại. Trước [DEV-230]
phép khớp ấy có ở `eide.caps.project._isa_tu_chip`; DX (AAD-33 §2.2) cần đúng phép khớp đó để
điền `chips[].isa`, và tầng L2 không được nhập từ tầng L4 — nên bản thứ hai sẽ xuất hiện ngay ở
lần viết DX. Hai bản của cùng một bảng là lỗi mà DEV-043 và DEV-046 đã ghi hai lần.

Manifest là NGUỒN SỰ THẬT cho ISA. Bảng bí danh và các họ chip chưa có manifest nằm ở
`docs/spec/dialog/dx_chips.yaml` — tệp ấy nói *người gọi con chip bằng tên gì*, tệp này nói
*con chip chạy tập lệnh nào*. Không trộn hai việc: thiếu manifest thì trả `None` để `env.check`
**nói thẳng** thay vì đưa ba lựa chọn đều sai (TC018).
"""
from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

import yaml

from eide_core.paths import spec_dir


@lru_cache(maxsize=1)
def _bang() -> tuple[tuple[re.Pattern[str], str], ...]:
    ra: list[tuple[re.Pattern[str], str]] = []
    for f in sorted((spec_dir() / "isa").glob("*.yaml")):
        d = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
        for pat in (d.get("family_patterns") or []):
            ra.append((re.compile(pat, re.I), str(d.get("id") or f.stem)))
    return tuple(ra)


def isa_cua_chip(chip: str) -> str | None:
    """ISA của `chip`, hoặc `None` nếu không manifest nào nhận.

    Thử CẢ HAI dạng tên mà bộ hồ sơ dùng cho cùng một con chip. `family_patterns` neo đầu chuỗi
    (`^STM32F[2-4]`) nên nó khớp `STM32F411CE` — dạng ví dụ của PROJECT-06 — nhưng không khớp
    `st.stm32f411ce`, vốn là dạng IRI mà `extract.svd` sinh ra cho mọi hộ chiếu chip và cũng là
    dạng ví dụ của SIM-01. Trước khi thử cả hai, ghim một chip bằng dạng IRI cho ra `isa: null`
    trong `constraints.yaml` mà không báo gì, rồi `code.build` sau đó dừng ở "chưa ghim ISA" —
    một câu đúng về triệu chứng và sai về nguyên nhân.
    """
    ten = chip[len("chip:"):] if chip.startswith("chip:") else chip
    for ung_vien in (ten, ten.rsplit(".", 1)[-1]):
        for pat, isa in _bang():
            if pat.search(ung_vien):
                return isa
    return None


def isa_da_co() -> list[str]:
    """Các ISA có manifest trong `docs/spec/isa/` — để nói thẳng kho đang thiếu gì (TC018)."""
    return sorted({isa for _, isa in _bang()} |
                  {f.stem for f in (spec_dir() / "isa").glob("*.yaml")
                   if f.stem not in ("probes",)})


def xoa_cache() -> None:
    """Bỏ cache bảng — cho test thêm manifest tạm rồi tra lại."""
    _bang.cache_clear()


def duong_manifest(isa: str) -> Path:
    return spec_dir() / "isa" / f"{isa}.yaml"
