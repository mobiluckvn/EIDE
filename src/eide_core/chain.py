"""Chuỗi năng lực và phép kiểm deterministic — DPS-09 §4.4; CDS-12.6 CHAT-06. WI-CHAT-06.

    Orchestrator lập đồ thị chuỗi bằng mô hình lập kế hoạch (vai trò planner) có output_schema
    `Chain{nodes[]: {id, cap, args, when?, on_ask}}` và kiểm tra deterministic sau đó: mọi `cap`
    tồn tại trong registry; tham số khớp input schema; không có chu trình; số nút ≤ ngưỡng; ước
    lượng chi phí ≤ ngân sách.

## Vì sao phép kiểm nằm ở đây chứ không ở prompt

Mô hình lập kế hoạch có thể sinh ra một chuỗi trông hợp lý mà gọi một năng lực không tồn tại,
truyền sai tham số, hay tự vòng lại chính nó. Nhờ prompt dặn "đừng làm thế" là một biện pháp
không kiểm được; còn năm phép kiểm dưới đây thì hoặc đạt hoặc không, và khi không đạt thì nói
được HỎNG Ở NÚT NÀO.

Đây cũng là ranh giới mà DPS-09 §1 vạch ra: tầng hiểu lệnh là deterministic, phần sinh mới dùng
mô hình. Một chuỗi do mô hình đề xuất chỉ trở thành kế hoạch sau khi qua tầng deterministic.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any

from eide_core.errors import EideError
from eide_core.paths import spec_dir

# DPS-09 §4.4: `on_ask` quyết định nhánh làm gì khi một nút rơi vào ASK.
ON_ASK = ("wait", "parallel", "skip")
TRAN_NUT = 24          # "số nút ≤ ngưỡng" — xem `kiem()` về chỗ lấy con số này


@lru_cache(maxsize=1)
def mau() -> list[dict[str, Any]]:
    """Năm chuỗi mẫu của §4.4, sinh từ `dps.js` (`dialog/chains.json`)."""
    f = spec_dir() / "dialog" / "chains.json"
    return json.loads(f.read_text(encoding="utf-8")) if f.exists() else []


def chon_mau(intent: str) -> dict[str, Any] | None:
    """Chuỗi mẫu theo ý định — CHAT-06 bước 1 "theo trigger_intents".

    Bám mẫu TRƯỚC khi nhờ mô hình: rẻ hơn, đoán được hơn, và DPS-09 §4.4 nói thẳng lý do — "để
    mô hình bám theo thay vì sáng tác". Không có mẫu nào khớp thì mới tới lượt planner.
    """
    for c in mau():
        if intent in c.get("trigger_intents", []):
            return c
    return None


@dataclass
class Nut:
    """Một nút của Chain — DPS-09 §4.4 `{id, cap, args, when?, on_ask}`."""

    id: str
    cap: str
    args: dict[str, Any] = field(default_factory=dict)
    when: str | None = None            # id nút phải xong trước (rỗng = chạy ngay)
    on_ask: str = "wait"

    @classmethod
    def tu_dict(cls, d: dict[str, Any]) -> Nut:
        return cls(id=str(d.get("id", "")), cap=str(d.get("cap", "")),
                   args=d.get("args") or {}, when=d.get("when"),
                   on_ask=str(d.get("on_ask") or "wait"))

    def as_dict(self) -> dict[str, Any]:
        return {"id": self.id, "cap": self.cap, "args": self.args,
                "when": self.when, "on_ask": self.on_ask}


@dataclass
class Chain:
    nodes: list[Nut] = field(default_factory=list)

    @classmethod
    def tu_dict(cls, d: dict[str, Any]) -> Chain:
        return cls([Nut.tu_dict(n) for n in (d.get("nodes") or [])])

    def as_dict(self) -> dict[str, Any]:
        return {"nodes": [n.as_dict() for n in self.nodes]}


#: Tham chiếu tới ĐẦU RA của một nút chạy trước — `${n7.patch}`, `${n6.plan.steps[0].id}`.
#:
#: Vì sao phải có. §4.4 kiểm CẢ chuỗi ngay lúc lập kế hoạch, trong khi một chuỗi thật là một
#: dây chuyền: `code.review` cần `patch` mà `code.integrate` mới sinh ra, `sim.run` cần
#: `artifact` của bước dựng. Trước 17/09/2026 `Nut.args` chỉ nhận giá trị NGUYÊN, nên không có
#: chỗ nào viết được "tham số này lấy từ nút n7" — và hệ quả là MỌI chuỗi dài hơn một bước đều
#: trượt phép kiểm của chính nó: gõ một câu tiếng Việt cho tác tử trả về một bức tường E5002
#: liệt kê bảy nút thiếu tham số bắt buộc. Đường đi trung tâm của sản phẩm không chạy được.
#:
#: Tham chiếu được kiểm ở BA điểm lúc lập kế hoạch — nút được trỏ có thật, nó chạy TRƯỚC, và
#: tên đầu ra có khai trong `output_schema` — nên một tham chiếu viết sai hỏng ngay lúc lập chứ
#: không hỏng ở phút thứ ba của một lượt chạy đã ghi vào store.
THAM_CHIEU = re.compile(r"^\$\{([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z0-9_]+(?:[.\[][^}]*)?)\}$")

#: Một chặng của đường đọc: `steps`, `[0]`, `[*]`.
_CHANG = re.compile(r"\[(\*|\d+)\]|([A-Za-z_][A-Za-z0-9_]*)")


def tach_tham_chieu(v: Any) -> tuple[str, str] | None:
    """`"${n7.patch}"` → `("n7", "patch")`. Không phải tham chiếu thì `None`."""
    if not isinstance(v, str):
        return None
    m = THAM_CHIEU.match(v.strip())
    return (m.group(1), m.group(2)) if m else None


def duyet_tham_chieu(args: Any) -> list[tuple[str, str]]:
    """Mọi tham chiếu trong `args`, kể cả nằm sâu trong dict/list lồng nhau.

    Duyệt SÂU chứ không chỉ tầng một: `{"modules": ["${n7.patch}"]}` là cách tự nhiên để gom đầu
    ra nhiều nút, và bỏ sót nó nghĩa là một tham chiếu không được kiểm lúc lập kế hoạch rồi lặng
    lẽ đi thẳng xuống năng lực dưới dạng chuỗi `"${n7.patch}"`.
    """
    ra: list[tuple[str, str]] = []
    if (tc := tach_tham_chieu(args)) is not None:
        return [tc]
    if isinstance(args, dict):
        for v in args.values():
            ra += duyet_tham_chieu(v)
    elif isinstance(args, list):
        for v in args:
            ra += duyet_tham_chieu(v)
    return ra


def doc_duong(goc: Any, duong: str) -> Any:
    """Đọc `plan.steps[0].id` trong một kết quả. `[*]` = lấy trường ấy của MỌI phần tử.

    Ném `KeyError` với đúng chặng hỏng thay vì trả `None`: `None` đi tiếp xuống năng lực và hỏng
    ở đó, cách chỗ sai vài nút, dưới một thông báo nói về chuyện khác.
    """
    cur = goc
    for m in _CHANG.finditer(duong):
        chi_so, ten = m.group(1), m.group(2)
        if ten is not None:
            if not isinstance(cur, dict) or ten not in cur:
                raise KeyError(f"`{duong}`: không có `{ten}`")
            cur = cur[ten]
        elif chi_so == "*":
            if not isinstance(cur, list):
                raise KeyError(f"`{duong}`: `[*]` cần một mảng")
            con = duong[m.end():].lstrip(".")
            return [doc_duong(x, con) for x in cur] if con else list(cur)
        else:
            if not isinstance(cur, list) or int(chi_so) >= len(cur):
                raise KeyError(f"`{duong}`: không có phần tử [{chi_so}]")
            cur = cur[int(chi_so)]
    return cur


def giai_tham_chieu(args: Any, ket_qua: dict[str, Any]) -> Any:
    """Thay mọi tham chiếu bằng giá trị thật, ngay trước khi gọi năng lực."""
    if (tc := tach_tham_chieu(args)) is not None:
        nut, duong = tc
        if nut not in ket_qua:
            raise EideError("E5002", f"tham chiếu `${{{nut}.{duong}}}`: nút `{nut}` chưa có kết quả")
        try:
            return doc_duong(ket_qua[nut], duong)
        except KeyError as e:
            raise EideError("E5002", f"tham chiếu `${{{nut}.{duong}}}` không đọc được: {e}") from e
    if isinstance(args, dict):
        return {k: giai_tham_chieu(v, ket_qua) for k, v in args.items()}
    if isinstance(args, list):
        return [giai_tham_chieu(v, ket_qua) for v in args]
    return args


def _kiem_args(registry: Any, cap: str, args: dict[str, Any]) -> tuple[list[str], list[str]]:
    """→ (lỗi cấu trúc, tham số bắt buộc còn THIẾU).

    Hai loại khác nhau và phải đi hai đường. Một tham số SAI KIỂU là chuỗi hỏng — mô hình lập kế
    hoạch viết sai, và chạy nó là chạy một kế hoạch sai. Một tham số THIẾU là chuỗi chưa đủ dữ
    kiện — `sim.run` cần `scenario`, `target.flash` cần `target`, và không nút nào trong chuỗi
    sinh ra chúng vì chúng đến từ NGƯỜI. Gộp cả hai vào E5002 nghĩa là một câu hỏi đáng lẽ hỏi
    người lại giết cả chuỗi, kể cả phần mười nút đầu đã đủ dữ kiện để chạy.
    """
    import jsonschema
    schema = dict(getattr(registry.get(cap).spec, "input_schema", None) or {})
    buoc = list(schema.get("required") or [])
    thieu = [k for k in buoc if k not in args]
    # Bỏ các khoá là THAM CHIẾU khỏi phép kiểm kiểu: giá trị của chúng chưa tồn tại lúc này, và
    # chuỗi `"${n7.patch}"` thì không bao giờ khớp `type: object`.
    cu_the = {k: v for k, v in args.items() if tach_tham_chieu(v) is None}
    schema["required"] = [k for k in buoc if k in cu_the]
    try:
        jsonschema.validate(cu_the, schema)
    except jsonschema.ValidationError as e:
        return [f"tham số không khớp input_schema của `{cap}` — {e.message}"], thieu
    except jsonschema.SchemaError:
        return [], thieu
    return [], thieu


def kiem(chain: Chain, registry: Any, *, tran_nut: int = TRAN_NUT,
         chi_phi_uoc: float = 0.0, ngan_sach: float | None = None) -> list[dict[str, Any]]:
    """Năm phép kiểm của §4.4. Ném E5002 ở lỗi cấu trúc, E3003 ở lỗi ngân sách.

    Gom TẤT CẢ lỗi cấu trúc rồi mới ném, không dừng ở lỗi đầu: một chuỗi do mô hình sinh thường
    sai vài chỗ cùng lúc, và trả về từng lỗi một sẽ tốn đúng số lần gọi mô hình bằng số lỗi.
    """
    loi: list[str] = []
    thieu_tat: list[dict[str, Any]] = []
    if not chain.nodes:
        loi.append("chuỗi rỗng")

    ids = [n.id for n in chain.nodes]
    if len(set(ids)) != len(ids):
        trung = sorted({i for i in ids if ids.count(i) > 1})
        loi.append(f"id nút trùng: {trung}")
    if any(not i for i in ids):
        loi.append("có nút không có id")

    if len(chain.nodes) > tran_nut:
        loi.append(f"{len(chain.nodes)} nút vượt ngưỡng {tran_nut}")

    # Thứ tự chạy, để biết một tham chiếu có trỏ NGƯỢC không. Tính một lần cho cả chuỗi.
    thu_tu = {n.id: i for i, n in enumerate(thu_tu_chay(chain))}
    for n in chain.nodes:
        truoc = thu_tu.get(n.id, 0)
        if n.cap not in registry:
            loi.append(f"{n.id}: năng lực `{n.cap}` không có trong registry")
            continue
        if not registry.get(n.cap).implemented:
            loi.append(f"{n.id}: năng lực `{n.cap}` chưa hiện thực")
        else:
            sai, thieu = _kiem_args(registry, n.cap, n.args)
            loi += [f"{n.id}: {s}" for s in sai]
            if thieu:
                thieu_tat.append({"id": n.id, "cap": n.cap, "thieu": thieu})
        loi += _kiem_tham_chieu(n, chain, registry, truoc)
        if n.on_ask not in ON_ASK:
            loi.append(f"{n.id}: on_ask=`{n.on_ask}` không thuộc {list(ON_ASK)}")
        if n.when and n.when not in ids:
            loi.append(f"{n.id}: phụ thuộc nút `{n.when}` không có trong chuỗi")

    if (chu_trinh := tim_chu_trinh(chain)):
        loi.append(f"chuỗi có chu trình: {' → '.join(chu_trinh)}")

    if loi:
        raise EideError("E5002", "Chuỗi không qua được phép kiểm deterministic (DPS-09 §4.4): "
                        + "; ".join(loi), loi=loi, so_loi=len(loi))
    if ngan_sach is not None and chi_phi_uoc > ngan_sach:
        raise EideError("E3003", f"Ước lượng chi phí {chi_phi_uoc:.2f} USD vượt ngân sách "
                        f"{ngan_sach:.2f} USD", uoc=chi_phi_uoc, ngan_sach=ngan_sach)
    return thieu_tat


def _kiem_tham_chieu(n: Nut, chain: Chain, registry: Any, thu_tu_nut: int) -> list[str]:
    """Ba phép kiểm cho mỗi `${nX.field}` trong tham số của một nút.

    Cả ba đều làm được lúc LẬP KẾ HOẠCH, và đó là lý do chúng ở đây: một tham chiếu trỏ nhầm nút
    hay trỏ tới một đầu ra không tồn tại thì hỏng ngay, chứ không hỏng ở phút thứ ba của một lượt
    chạy đã ghi vào store và đã tiêu tiền gọi mô hình.

    Chỉ kiểm CHẶNG ĐẦU của đường đọc. `output_schema` của phần lớn năng lực khai đầu ra là
    `{"type": "object"}` kèm một câu mô tả, nên hình dạng bên trong không có gì để đối chiếu —
    khẳng định `plan.steps[0].id` tồn tại sẽ là một lời nói chắc chắn dựa trên không gì cả. Chặng
    sâu được kiểm lúc chạy, ở `doc_duong`, nơi có dữ liệu thật để nói.
    """
    ra: list[str] = []
    thu_tu = {x.id: i for i, x in enumerate(thu_tu_chay(chain))}
    for nut_nguon, duong in duyet_tham_chieu(n.args):
        if nut_nguon == n.id:
            ra.append(f"{n.id}: tham chiếu `${{{nut_nguon}.{duong}}}` trỏ vào chính nó")
            continue
        nguon = next((x for x in chain.nodes if x.id == nut_nguon), None)
        if nguon is None:
            ra.append(f"{n.id}: tham chiếu `${{{nut_nguon}.{duong}}}` trỏ nút không có trong chuỗi")
            continue
        if thu_tu.get(nut_nguon, 0) >= thu_tu_nut:
            ra.append(f"{n.id}: tham chiếu `${{{nut_nguon}.{duong}}}` trỏ nút chạy SAU nó")
            continue
        if nguon.cap in registry:
            khai = ((getattr(registry.get(nguon.cap).spec, "output_schema", None)
                     or {}).get("properties") or {})
            dau = _CHANG.search(duong)
            ten = dau.group(2) if dau else None
            if khai and ten and ten not in khai:
                ra.append(f"{n.id}: `{nguon.cap}` không khai đầu ra `{ten}` "
                          f"(có: {', '.join(sorted(khai))})")
    return ra


def tim_chu_trinh(chain: Chain) -> list[str]:
    """Trả về một chu trình nếu có, rỗng nếu không.

    Trả về ĐƯỜNG ĐI chứ không phải True/False: người đọc lỗi cần biết ba nút nào vòng vào nhau,
    không phải biết rằng "có chu trình ở đâu đó trong hai mươi nút".
    """
    cha = {n.id: n.when for n in chain.nodes if n.when}
    for bat_dau in cha:
        tham, cur = [], bat_dau
        while cur in cha:
            if cur in tham:
                return [*tham[tham.index(cur):], cur]
            tham.append(cur)
            cur = cha[cur]
    return []


def thu_tu_chay(chain: Chain) -> list[Nut]:
    """Sắp nút theo phụ thuộc `when` — sắp xếp tô-pô ổn định.

    Ổn định nghĩa là: cùng một chuỗi luôn cho cùng một thứ tự. Một bộ lập lịch chạy hai lần ra
    hai thứ tự khác nhau thì lỗi tái hiện được một lần rồi biến mất, và không ai gỡ được.
    """
    con_lai = list(chain.nodes)
    xong: set[str] = set()
    ra: list[Nut] = []
    while con_lai:
        san = [n for n in con_lai if not n.when or n.when in xong]
        if not san:
            break               # phần còn lại phụ thuộc vòng — `kiem()` đã bắt trước đó
        for n in san:
            ra.append(n)
            xong.add(n.id)
            con_lai.remove(n)
    return ra + con_lai
