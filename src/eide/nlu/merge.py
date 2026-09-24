"""Hợp nhất slot theo nguồn. Spec: AAD-33 §2.2 (bất biến của slot), §2.5.2; AGD-32 Đ1.

## Một bất biến, và nó là lý do cả tệp này tồn tại

    slots được hợp nhất theo thứ tự ưu tiên DX > câu trả lời người ở S3 > mô hình S1b >
    fill_defaults. Mỗi slot mang origin, và **slot có origin=model không bao giờ được dùng làm
    đường dẫn tệp hay mã chip để chạy nút** — chỉ được dùng để điền sẵn câu hỏi.

Đo ngày 23/09/2026: 11 trong 51 ca không đạt chết vì đúng điều ngược lại. Mô hình đọc câu *"rà
soát toàn bộ mã trong /Users/…/firmware"*, điền `slots.path` bằng một đường dẫn TRÔNG NHƯ THẬT
nhưng không tồn tại, rồi `archive.list` báo E2000 "không có tệp". Người dùng nhận một câu lỗi về
tệp cho một việc họ không hề nhờ mở tệp, và đường dẫn trong câu lỗi là đường dẫn máy tự nghĩ ra.

## Vì sao `origins` là một bảng CẠNH BÊN, không phải bọc từng giá trị

Ví dụ của AAD-33 §2.5.2 bọc mỗi slot thành `{"value": …, "origin": …}`. Làm đúng như thế thì
mọi năng lực nhận slot phải mở bọc trước khi dùng — 213 năng lực đang khai `chip: string`,
`path: string` trong `input_schema`, và `chat._args_cho` lọc tham số BẰNG PHÉP KIỂM KIỂU. Một
dict rơi vào chỗ đòi string sẽ bị `_args_cho` loại bỏ im lặng, tức mọi nút mất tham số cùng lúc.

Bảng `origins: {khoá: nguồn}` giữ đúng bất biến (ai điền, và slot nào không được tin) mà không
đổi kiểu của bất kỳ tham số nào. Ghi sai khác ở DEV-231.

## Hai slot phái sinh

`paths`/`chips` là mảng (v2), nhưng hợp đồng của 213 năng lực nói `path`/`chip` số ít. Hai khoá
số ít vì thế được SINH RA từ mảng — và chỉ từ những giá trị đáng tin (`dx`, `user`), không bao
giờ từ `model`. Nhờ vậy phép nối tham số cũ chạy nguyên như trước, còn đường dẫn mô hình bịa ra
thì dừng lại ở chỗ nó được sinh: trong câu hỏi của S3, không trong tham số của một nút.
"""
from __future__ import annotations

import copy
from typing import Any

from eide.nlu.dx import DXResult

#: Thứ tự ưu tiên. Chỉ số nhỏ THẮNG.
UU_TIEN: tuple[str, ...] = ("dx", "user", "model", "default")

#: Nguồn được phép dùng để CHẠY một nút với một đường dẫn / mã chip.
NGUON_TIN = frozenset({"dx", "user"})

#: Slot dạng mảng ở v2, kèm khoá số ít phái sinh cho các hợp đồng cũ.
MANG_SO_IT: dict[str, str] = {"paths": "path", "chips": "chip"}


def schema_cho_mo_hinh(schema: dict[str, Any]) -> dict[str, Any]:
    """Bản lược đồ gửi cho mô hình: bỏ những trường do MÃ điền.

    `origins` là kết luận của phép hợp nhất, không phải một câu trả lời của mô hình — để nó
    trong lược đồ là mời mô hình tự khai "đường dẫn này do DX trích", tức mời nó vượt qua chính
    phép kiểm dựng ra để chặn nó.
    """
    ra = copy.deepcopy(schema)
    (ra.get("properties") or {}).pop("origins", None)
    return ra


def tu_dx(dx: DXResult) -> tuple[dict[str, Any], dict[str, str]]:
    """`(slots, origins)` mà DX điền được. Không có gì thì trả hai dict rỗng."""
    slots: dict[str, Any] = {}
    origins: dict[str, str] = {}
    if dx.paths:
        slots["paths"] = dx.duong_de_hoi()
        origins["paths"] = "dx"
    if dx.chips:
        slots["chips"] = dx.ma_chip()
        origins["chips"] = "dx"
    return slots, origins


def hop_nhat(intent: dict[str, Any], dx: DXResult | None = None, *,
             tra_loi: dict[str, Any] | None = None,
             mac_dinh: dict[str, Any] | None = None) -> dict[str, Any]:
    """Trả BẢN MỚI của `intent` với `slots` đã hợp nhất và `origins` đã ghi.

    Không sửa tham số của người gọi: một ý định là thứ được ghi vào sổ cái, và sửa nó tại chỗ
    làm bản ghi "trước khi hợp nhất" biến mất — đúng thứ cần để truy vì sao một nút nhận tham
    số ấy.
    """
    ra = copy.deepcopy(intent or {})
    slots: dict[str, Any] = dict(ra.get("slots") or {})
    origins: dict[str, str] = dict(ra.get("origins") or {})

    # Mọi thứ mô hình đã điền đều mang nhãn `model` — trừ khoá nào đã có nguồn tin cậy hơn.
    for k in slots:
        origins.setdefault(k, "model")

    for nguon, them in (("default", mac_dinh), ("user", tra_loi),
                        ("dx", tu_dx(dx)[0] if dx is not None else None)):
        for k, v in (them or {}).items():
            if v is None or v == [] or v == "":
                continue
            if UU_TIEN.index(nguon) <= UU_TIEN.index(origins.get(k, "default")):
                slots[k], origins[k] = v, nguon

    _sinh_so_it(slots, origins)
    ra["slots"], ra["origins"] = slots, origins
    if dx is not None:
        # Giữ NGUYÊN kết quả DX trên ý định, không chỉ phần đã thành slot.
        #
        # `slots.paths` là danh sách để HỎI (có cả tệp không tồn tại, §2.2); `exists` của từng
        # tệp chỉ có ở đây. Không giữ thì `duong_chay_duoc` không phân biệt được "tệp có thật"
        # với "tệp người dùng gõ sai" — và đó đúng là chỗ 11 ca chết: chạy `archive.list` trên
        # một đường dẫn không tồn tại thay vì hỏi lại một câu.
        ra["dx"] = dx.to_dict()
    return ra


def _sinh_so_it(slots: dict[str, Any], origins: dict[str, str]) -> None:
    """`paths` → `path`, `chips` → `chip` — CHỈ từ nguồn tin cậy, và không đè khoá đã có.

    Một `path` số ít do mô hình điền từ lượt trước vẫn được giữ (S3 cần nó để điền sẵn câu hỏi),
    nhưng nó không được SINH RA ở đây từ một mảng không đáng tin: `chay_duoc()` là chỗ duy nhất
    quyết định cái gì đi vào tham số của nút.
    """
    for mang, so_it in MANG_SO_IT.items():
        gia_tri = slots.get(mang)
        if not isinstance(gia_tri, list) or not gia_tri:
            continue
        if origins.get(mang) not in NGUON_TIN or slots.get(so_it):
            continue
        slots[so_it], origins[so_it] = gia_tri[0], origins[mang]


def chay_duoc(intent: dict[str, Any], khoa: str) -> list[str]:
    """Giá trị của slot `khoa` được phép dùng để CHẠY một nút; `[]` nếu nguồn không đáng tin.

    Đây là chỗ bất biến của §2.2 được thi hành. Bên gọi KHÔNG tự đọc `slots[khoa]` khi định chạy
    một nút — đọc qua đây, để chỉ có một chỗ phải đúng.
    """
    slots = (intent or {}).get("slots") or {}
    origins = (intent or {}).get("origins") or {}
    if origins.get(khoa) not in NGUON_TIN:
        return []
    v = slots.get(khoa)
    if isinstance(v, list):
        return [str(x) for x in v if x]
    return [str(v)] if v else []


def duong_chay_duoc(intent: dict[str, Any], van_goc: str = "") -> list[str]:
    """Đường dẫn được phép đưa vào tham số của một nút đang chạy.

    Ba tầng, theo đúng thứ tự:

    1. **Có `intent["dx"]`** (đường sống của v1.4): chỉ những đường dẫn `exists=true`. Câu có nêu
       đường dẫn mà không tệp nào có thật → trả `[]`, và bên gọi bỏ khoá tham số để nút HỎI
       người. Một câu hỏi trả lời được tốt hơn một E2000 về một tệp máy tự nghĩ ra.
    2. **Không có `dx` nhưng `origins` nói slot đáng tin** (bên gọi đã tự hợp nhất): dùng luôn.
    3. **Không có cả hai** — bên gọi cũ (CLI, test, `chat.orchestrate` gọi trực tiếp): trích tại
       chỗ từ câu gốc, đúng hành vi [DEV-208]. Giữ đường lùi này để một lời gọi không đi qua
       daemon không mất phần đã chạy được từ 23/09/2026.
    """
    if (dxd := (intent or {}).get("dx")):
        return [p["value"] for p in (dxd.get("paths") or []) if p.get("exists")]
    if (co := chay_duoc(intent, "paths")):
        return co
    if (intent or {}).get("origins"):
        return []
    from eide.nlu.dx import extract
    return extract(van_goc).duong_de_hoi() if van_goc else []


def nguon_cua(intent: dict[str, Any], khoa: str) -> str | None:
    return ((intent or {}).get("origins") or {}).get(khoa)


def de_ghi_so(intent: dict[str, Any]) -> dict[str, Any]:
    """Phần của ý định đi vào sổ cái `s1.intent` — kèm origin từng slot (tiêu chí brief §6)."""
    return {"intent": intent.get("intent"),
            "confidence": intent.get("confidence"),
            "is_big": bool(intent.get("is_big")),
            "slots": intent.get("slots") or {},
            "origins": intent.get("origins") or {},
            "alt_intents": intent.get("alt_intents") or [],
            "why": intent.get("why") or ""}
