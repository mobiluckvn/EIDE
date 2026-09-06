"""Danh sách trắng và niêm chữ ký — POL-17 §3. WI-257.

    Ba danh sách trong autonomy.yaml [...]. Mỗi thay đổi danh sách là hành động R4 theo cổng
    riêng: người ký bằng lệnh `eide policy sign` (ghi băm nội dung + user + thời điểm vào
    decision_log và tệp `.eide/policy.sig`); PolicyGate từ chối nạp danh sách có băm không
    khớp chữ ký.

## "Chữ ký" ở đây là NIÊM, không phải mật mã

POL-17 §3 định nghĩa nội dung chữ ký là "băm nội dung + user + thời điểm" — không có khóa,
không có bên thứ ba. Vậy nên nó phát hiện được sửa đổi (vô tình hay cẩu thả), chứ KHÔNG chống
được người đã ghi được vào `.eide/`: người ấy sửa danh sách rồi sửa luôn `policy.sig`.

Điều làm nó không rỗng nghĩa là §3 đòi ghi vào HAI nơi: `policy.sig` *và* decision_log. Nhật ký
là chuỗi băm nối tiếp (`ledger.py`), nên muốn giả mạo êm thấm thì phải băm lại toàn chuỗi từ
điểm đó về sau. `kiem()` vì thế đối chiếu `.sig` với lần ký mới nhất trong nhật ký, chứ không
chỉ tự đối chiếu với chính nó — nếu chỉ so `.sig` với tệp cấu hình thì sửa cả hai tệp cạnh nhau
là xong, và cả cơ chế thành hình thức.

Tôi ghi rõ giới hạn này ở đây, và đặt tên hàm là `kiem`/`ky` chứ không phải `verify_signature`,
để không gợi ý nhiều hơn thứ nó làm được.

## Niêm phủ danh sách CÓ HIỆU LỰC, không phủ nội dung tệp

`PolicyGate` hợp nhất `{**defaults.yaml, **autonomy.yaml}`. Một dự án bỏ trống `allowed_licenses`
vẫn chạy bằng danh sách của tệp mặc định. Nếu niêm chỉ phủ tệp dự án thì người ký đặt tên mình
lên `trusted_sources` trong khi `allowed_licenses` đang có hiệu lực lại đến từ một tệp không ai
niêm — đúng lỗ hổng §3 muốn bịt. Nên `bam()` nhận cấu hình SAU hợp nhất.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.ledger import Ledger

# POL-17 §3 nói "ba danh sách", §4 cho schema bốn khóa. Niêm phủ cả bốn: `allowed_licenses`
# quyết định G-SRC-04/05 và `boards` quyết định G-OPS — bỏ chúng ra ngoài niêm thì ký xong vẫn
# còn hai đường sửa được chính sách mà không ai hay. Xem DEVIATIONS DEV-030.
KHOA_NIEM = ("trusted_sources", "trusted_packages", "allowed_licenses", "boards")

# POL-17 §3 bảo ghi việc ký "vào decision_log", nhưng API-15 §5 (ledger_events.json) không có
# loại sự kiện nào cho nó, và §2 cũng không định nghĩa "cổng riêng" mà §3 nhắc tới — trong 46
# quy tắc không có cổng danh sách trắng. Hai khoảng trống ấy ở DEVIATIONS DEV-031.
#
# `gate.human` {gate_id, decision, by, note} là loại gần nhất đã có và đúng nghĩa: ký là một
# người quyết định tại một cổng. Thêm khóa `hash` vì `kiem()` phải đối chiếu được — để băm
# trong `note` dạng văn xuôi thì bước đối chiếu thành ra phân tích chuỗi tự do.
KIND = "gate.human"
GATE_WL = "G-WL"


@dataclass(frozen=True)
class Nien:
    """Nội dung `.eide/policy.sig` — POL-17 §3 "băm nội dung + user + thời điểm"."""

    hash: str
    by: str
    at: str
    keys: list[str]
    alg: str = "sha256"

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


def bam(cfg: dict[str, Any]) -> str:
    """SHA-256 trên dạng chuẩn tắc của RIÊNG các khóa danh sách trắng.

    Chỉ các khóa danh sách, không phải cả tệp: `thresholds` và `autonomy` đổi thường xuyên
    (policy.learn_thresholds đề xuất hằng tuần, set_autonomy đổi theo phiên) và có đường kiểm
    soát riêng. Gộp chúng vào niêm thì mỗi lần chỉnh ngưỡng lại bắt ký lại danh sách trắng,
    và một cơ chế bắt người ký quá thường xuyên là một cơ chế người ta bấm qua cho xong.

    KHÔNG sắp xếp lại phần tử trong danh sách. Đảo thứ tự sẽ đổi băm và bắt ký lại — hơi phiền,
    nhưng chuẩn hóa quá tay thì có ngày một thay đổi thật lọt qua vì trông giống một lần đảo
    thứ tự.
    """
    goi = {k: cfg[k] for k in KHOA_NIEM if k in cfg}
    raw = json.dumps(goi, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def doc_nien(p: Path) -> Nien | None:
    if not p.exists():
        return None
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
        return Nien(hash=d["hash"], by=d["by"], at=d["at"],
                    keys=list(d.get("keys", KHOA_NIEM)), alg=d.get("alg", "sha256"))
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        raise EideError("E6000", f"Tệp niêm hỏng, không đọc được: {p} ({e})", path=str(p)) from e


def _nien_moi_nhat(led: Ledger | None) -> dict[str, Any] | None:
    if led is None:
        return None
    ra = [r for r in led.records()
          if r.get("kind") == KIND and r.get("data", {}).get("gate_id") == GATE_WL]
    return ra[-1] if ra else None


def kiem(cfg: dict[str, Any], sig_path: Path, led: Ledger | None = None) -> tuple[bool, str]:
    """Trả (đạt, lý do). Lý do rỗng khi đạt — chuỗi này đi thẳng vào decision_log."""
    n = doc_nien(sig_path)
    if n is None:
        return False, "danh sách trắng chưa được ký (chạy `eide policy sign`)"
    if n.alg != "sha256":
        return False, f"thuật toán băm lạ trong niêm: {n.alg}"
    hien = bam(cfg)
    if hien != n.hash:
        return False, f"băm không khớp niêm — danh sách đã đổi sau khi {n.by} ký lúc {n.at}"
    rec = _nien_moi_nhat(led)
    if rec is not None and rec.get("data", {}).get("hash") != n.hash:
        # §3 đòi ghi cả hai nơi chính là để có bước đối chiếu này.
        return False, "niêm không khớp lần ký mới nhất trong nhật ký"
    return True, ""


def ky(cfg: dict[str, Any], sig_path: Path, by: str, led: Ledger | None = None) -> Nien:
    """Ký danh sách trắng đang có hiệu lực. Chỉ người mới được gọi — xem cli.py."""
    if not by.strip():
        raise EideError("E1000", "Ký danh sách trắng phải nêu tên người ký (POL-17 §3)")
    n = Nien(hash=bam(cfg), by=by.strip(),
             at=datetime.now(UTC).isoformat(timespec="seconds"),
             keys=[k for k in KHOA_NIEM if k in cfg])
    if led is not None:
        # Ghi nhật ký TRƯỚC khi ghi tệp: nếu chỉ một trong hai kịp ghi thì phải là nhật ký.
        # Có nhật ký mà thiếu `.sig` ⇒ `kiem()` trả "chưa ký" ⇒ hỏi người, an toàn. Ngược lại,
        # có `.sig` mà nhật ký thiếu thì niêm trông hợp lệ nhưng không có gì chứng thực nó.
        led.append(KIND, {"gate_id": GATE_WL, "decision": "APPROVE", "by": n.by,
                          "note": f"ký danh sách trắng ({', '.join(n.keys)})",
                          "hash": n.hash}, actor="human")
    sig_path.parent.mkdir(parents=True, exist_ok=True)
    sig_path.write_text(json.dumps(n.as_dict(), ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")
    return n


def tom_tat(cfg: dict[str, Any]) -> str:
    """Bản tóm tắt người đọc được, in ra trước khi hỏi xác nhận ký.

    Liệt kê MỌI khóa mà `bam()` niêm, kể cả khóa rỗng. Bỏ khóa rỗng đi cho gọn thì người xác
    nhận không thấy `boards` trong danh sách và tưởng nó không nằm trong chữ ký — trong khi
    `bam()` có niêm nó, và một mục board thêm vào sau này sẽ làm hỏng niêm.
    """
    d = []
    for k in KHOA_NIEM:
        if k not in cfg:
            d.append(f"  {k:18}  (không có trong cấu hình — không nằm trong niêm)")
            continue
        v = cfg[k] or []
        mau = list(v)[:4]
        d.append(f"  {k:18} {len(v):3} mục   {', '.join(map(str, mau))}"
                 f"{' …' if len(v) > 4 else ''}")
    return "\n".join(d)
