"""Namespace bench.* — CDS-12.5 (BENCH-01…03); BEN-24 (ba chỉ số CF/BF/BC); PKG-22 (huy hiệu
đi theo gói); DDD-14 (`passport.badges`).

`bench.run` cần board lab (grounding của hợp đồng ghi thẳng "Board lab") nên nó ở mốc sau. Hai
năng lực còn lại thì không: một cái GẮN huy hiệu từ kết quả đã có, một cái ĐỌC các ca lỗi đã
ghi. Cả hai làm việc trên dữ liệu, không trên phần cứng.

## Bất biến của nhóm: huy hiệu phải truy lại được

Huy hiệu đi theo gói vào registry, nơi người khác thấy nó mà **không thấy lần chạy sinh ra
nó**. Một nhãn `verified` không kèm băm log là một nhãn tự chứng thực — nó nói "tin tôi đi" và
không đưa ra cách nào để kiểm. Nên `bench.badge` từ chối gắn huy hiệu không có `log_hash`.
"""
from __future__ import annotations

import hashlib
import json
from collections import Counter
from datetime import UTC, datetime
from typing import Any

from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# Ba chỉ số của BEN-24. Một huy hiệu `bench` chỉ có nghĩa khi đủ cả ba: `CF` (dịch được),
# `BF` (dựng + nạp được), `BC` (chạy đúng trên board). Thiếu một cái thì hai cái kia không
# nói lên điều gì — một gói dịch được 100% mà không nạp nổi thì vô dụng.
CHI_SO = ("CF", "BF", "BC")

# Số ca lỗi tối thiểu để gọi là MỘT MẪU LẶP. Dưới mức này thì đó là một lần hỏng, và đề xuất
# sửa skill dựa trên một lần hỏng là đề xuất dựa trên nhiễu.
TOI_THIEU_LAP = 3


@capability("bench.badge")
def badge(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: BENCH-02 (CDS-12.5) — `steps`: "Gắn badge vào Passport/skill với log hash".
    `{id, result}` → `{badges[]}`; `tc`: "Badge có hash kiểm được".

    **Không có `log_ref` thì không gắn.** Đó là toàn bộ nội dung của `tc`, và nó là lý do năng
    lực này tồn tại thay vì để người ta ghi thẳng một chuỗi vào `passport.badges`: huy hiệu là
    một lời khẳng định về phần cứng, và lời khẳng định nào cũng phải chỉ ra được bằng chứng.

    Băm ở đây băm CHÍNH kết quả, không băm tệp log. Tệp log có thể mất, bị xoay vòng, bị chép
    đi nơi khác; con số trong `result` thì đi cùng huy hiệu mãi mãi, nên băm nó là cách duy
    nhất để về sau còn kiểm được huy hiệu này nói về lần chạy nào.
    """
    hid = params["id"]
    kq = params["result"]
    log = kq.get("log_ref") or kq.get("log_hash")
    if not log:
        raise EideError("E1000", "Huy hiệu phải kèm `result.log_ref` — một nhãn `verified` "
                                 "không có bằng chứng là một nhãn tự chứng thực (BENCH-02 tc)")

    thieu = [c for c in CHI_SO if kq.get(c) is None and kq.get(c.lower()) is None]
    loai = "verified" if not thieu else "bench-partial"

    bam = hashlib.sha256(
        json.dumps(kq, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()[:16]
    hh = {
        "badge": loai,
        "package": hid,
        "at": datetime.now(UTC).isoformat(),
        "log_ref": log,
        "result_hash": bam,
        **{c: (kq.get(c) if kq.get(c) is not None else kq.get(c.lower())) for c in CHI_SO},
    }
    if thieu:
        # Nói ra chỉ số nào thiếu ngay trong huy hiệu: người đọc nó trong registry không có
        # cách nào khác để biết nó nói về một phần hay toàn bộ.
        hh["missing"] = thieu

    ds = _gan_vao_passport(hid, hh, ctx)
    return {"badges": ds}


def _gan_vao_passport(hid: str, hh: dict[str, Any], ctx: Context) -> list[dict[str, Any]]:
    """Ghi vào `passport.badges` nếu hộ chiếu ấy có trong store; không thì chỉ trả về.

    Hợp đồng nói "Gắn badge vào Passport/skill" — hai đích, và cái thứ hai (skill) chưa có bảng
    trong store. Trả huy hiệu về cho người gọi trong mọi trường hợp: `registry.pack` đọc nó từ
    kết quả chứ không đọc từ store, nên gói vẫn mang huy hiệu kể cả khi hộ chiếu chưa nạp.
    """
    if not ctx.project_dir:
        return [hh]
    db = store.store_path(ctx.project_dir)
    if not db.exists():
        return [hh]
    with store.open_store(db) as c:
        r = c.execute("SELECT badges FROM passport WHERE id = ?", (hid,)).fetchone()
        if r is None:
            return [hh]
        ds = json.loads(r[0]) if r[0] else []
        # Thay huy hiệu cùng loại thay vì chồng thêm: hai `verified` cho cùng một gói thì cái
        # cũ chỉ làm người đọc phải tự đoán cái nào còn đúng.
        ds = [b for b in ds if b.get("badge") != hh["badge"]] + [hh]
        c.execute("UPDATE passport SET badges = ? WHERE id = ?",
                  (json.dumps(ds, ensure_ascii=False), hid))
        c.commit()
        return ds


@capability("bench.suggest_skill_fix")
def suggest_skill_fix(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: BENCH-03 (CDS-12.5) — `steps`: "Gom lỗi lặp theo skill; librarian đề xuất sửa quy
    tắc; chờ Pack owner (T2)". `{failures[]}` → `{proposal}`; `tc`: "Đề xuất không tự áp dụng".

    **Đề xuất, không phải thay đổi.** Hợp đồng đặt năng lực này ở tầng tự chủ T2 với
    `ask_when: "Luôn"`, và `tc` nói thẳng "đề xuất không tự áp dụng". Một skill là quy tắc sinh
    mã cho cả một họ chip; sửa nó theo vài ca lỗi mà không ai duyệt là để một mẫu hỏng cục bộ
    viết lại cách EIDE sinh mã cho mọi dự án sau này.

    **Chỉ đề xuất cho mẫu LẶP.** Một ca lỗi là một ca lỗi; ba ca cùng một skill với cùng một
    loại lỗi mới là dấu hiệu quy tắc sai. Dưới ngưỡng thì trả đề xuất rỗng kèm lý do — im lặng
    ở đây khiến người gọi tưởng không có gì đáng xem.
    """
    ds = params["failures"]
    theo_skill: dict[str, list[dict[str, Any]]] = {}
    for f in ds:
        k = f.get("skill") or f.get("skill_id") or "(không rõ skill)"
        theo_skill.setdefault(k, []).append(f)

    mau: list[dict[str, Any]] = []
    for skill, ca in sorted(theo_skill.items(), key=lambda x: -len(x[1])):
        loai = Counter((c.get("kind") or c.get("error") or "?") for c in ca)
        pho_bien, n = loai.most_common(1)[0]
        if n < TOI_THIEU_LAP:
            continue
        mau.append({
            "skill": skill,
            "kind": pho_bien,
            "count": n,
            "total": len(ca),
            "examples": [c.get("detail") or c.get("message") or "" for c in ca[:3]],
            "suggestion": f"Xem lại quy tắc của `{skill}` cho trường hợp `{pho_bien}` "
                          f"— {n}/{len(ca)} ca lỗi cùng một kiểu.",
        })

    return {"proposal": {
        "patterns": mau,
        "applied": False,          # T2: chờ Pack owner — năng lực này không tự áp dụng
        "needs_owner": True,
        "note": (f"{len(ds)} ca lỗi, không mẫu nào lặp đủ {TOI_THIEU_LAP} lần — "
                 "một lần hỏng là nhiễu, không phải quy tắc sai."
                 if not mau else
                 f"{len(mau)} mẫu lặp; Pack owner duyệt trước khi sửa skill."),
    }}
