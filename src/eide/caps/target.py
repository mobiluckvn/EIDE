"""Namespace target.* — CDS-12.3 (TARGET-01…09); TGT-19 §2/§4; POL-17 §3 (`boards` lab).

Tám trong chín năng lực của nhóm này **chạm vào phần cứng thật**: nạp firmware, reset, đọc/ghi
thanh ghi qua probe, xoá fuse. Chúng ở mốc sau vì không có board thì không có gì để kiểm — và
một `target.flash` viết xong mà chưa từng nạp lên con chip nào là một năng lực xanh trong test
vì lý do khác với lý do nó được viết ra.

`target.detect` là ngoại lệ, và đó không phải may mắn: nó chỉ HỎI máy tính xem đang thấy gì.
Câu trả lời "không thấy board nào" có giá trị đúng bằng câu "thấy một nucleo-f411" — nó là thứ
người dùng cần khi cắm cáp mà panel vẫn trống.
"""
from __future__ import annotations

from typing import Any

import yaml

from eide.caps.discover import _liet_ke_cong
from eide_core.paths import spec_dir
from eide_core.registry import capability
from eide_core.router import Context


def _boards_lab() -> dict[str, Any]:
    """`boards` của `defaults.yaml` — POL-17 §3/§4 (DEV-030 ghi hai tên cho cùng một danh sách).

    Board nằm trong danh sách này là board **được phép tự nạp firmware** (G-OPS). Đọc từ tệp đã
    KÝ, không từ một bản chép: cả cơ chế chữ ký của POL-17 sinh ra để danh sách này không tự
    dài ra được.
    """
    f = spec_dir() / "policy" / "defaults.yaml"
    if not f.exists():
        return {}
    d = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    return d.get("boards") or {}


@capability("target.detect")
def detect(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TARGET-01 (CDS-12.3) — `steps`: "discover.ports + probe + chip_id; đối chiếu
    boards trong autonomy.yaml". `{}` → `{targets[]{id, kind, port, probe, chip_id, lab}}`.

    **`chip_id` là `None` cho tới khi `discover.chip_id` có mặt, và nó KHÔNG được đoán.**
    Một cổng `/dev/cu.usbmodem` với VID `0483` gần như chắc chắn là một board ST — nhưng "gần
    như chắc chắn" ở đây nghĩa là nạp firmware của họ F4 lên một con F0 khi đoán trượt. Nên
    trường ấy để trống và `lab` là `False`: chưa biết chip thì chưa board nào được tự nạp.

    **`lab` đối chiếu với danh sách ĐÃ KÝ.** POL-17 §3 nói board lab mới được tự nạp, và danh
    sách ấy nằm trong `defaults.yaml` có chữ ký. Một thiết bị vừa cắm vào không thể tự nhận
    mình là lab — nếu được thế thì cả cơ chế chữ ký chẳng bảo vệ điều gì.
    """
    lab = _boards_lab()
    ra: list[dict[str, Any]] = []
    for c in _liet_ke_cong():
        bid = _khop_board(c, lab)
        ra.append({
            "id": bid or c["dev"],
            "kind": c.get("kind", "serial"),
            "port": c["dev"],
            "probe": c.get("probe"),
            "chip_id": None,        # cần `discover.chip_id` — không đoán từ VID/PID
            "lab": bool(bid and (lab.get(bid) or {}).get("lab", True)),
            "vid": c.get("vid", ""),
            "pid": c.get("pid", ""),
            "driver_ok": c.get("driver_ok"),
        })
    return {"targets": ra}


def _khop_board(cong: dict[str, Any], lab: dict[str, Any]) -> str | None:
    """Cổng → id board trong danh sách lab, theo `port` hoặc `serial` đã khai.

    Khớp theo thứ gì CỤ THỂ đã ghi trong danh sách, không theo VID/PID: hai board cùng một loại
    probe có cùng VID:PID, và cho phép một trong hai thừa hưởng quyền tự nạp của cái kia là
    đúng thứ danh sách lab sinh ra để chặn.
    """
    for bid, mo in (lab or {}).items():
        if not isinstance(mo, dict):
            continue
        if mo.get("port") and mo["port"] == cong.get("dev"):
            return bid
        if mo.get("serial") and cong.get("serial") and mo["serial"] == cong["serial"]:
            return bid
    return None
