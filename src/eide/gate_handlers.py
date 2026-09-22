"""Người duyệt một cổng do HANDLER chạy — [DEV-176]. POL-17 §2, APD-08 §4.1, UXD-13 U2.

## Cổng phụ là gì, và vì sao nó cần một đường duyệt riêng

Router xét cổng của một lời gọi TRƯỚC khi handler chạy, trên tham số đầu vào. Vài cổng lại
phán lên thứ chỉ ra đời SAU đó: G1 phán lên chính bản kế hoạch mà `plan.create` vừa sinh, và
không có cách nào xét nó trước khi nó tồn tại. [DEV-171] đưa những quyết định ấy vào
`decision_log` và lên tab Làm rõ yêu cầu, dưới khoá `<run_id>:<gate>`.

Nhưng `Router.quyet_dinh()` chỉ biết chạy tiếp một LỜI GỌI đang treo — nó còn giữ
`(cap, params, ctx)` trong hàng chờ. Cổng phụ không có gì để chạy tiếp: lời gọi sinh ra nó đã
`done` từ lâu. Thứ người duyệt ở đây là **hiện vật**, không phải một lời gọi.

Đo 22/09/2026 trên bài nhấp nháy LED: cổng G1-03 "Đổi kiến trúc" trả ASK (bước 1 chạm `clock`
vì đặt `F_CPU` — đúng thứ POL-17 bắt hỏi người). Câu hỏi hiện ra, có dòng sổ, và bấm duyệt thì
nhận E2000. Người dùng đọc được câu hỏi và không có đường nào trả lời nó; chuỗi đứng vĩnh viễn
ở đúng chỗ tác tử làm đúng.
"""
from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core.errors import EideError


def dang_ky(router: Any, ctx: Any) -> None:
    """Nối cách duyệt từng cổng vào `router.cong_phu_handlers`.

    Gọi ở mọi chỗ dựng `Router` — daemon, CLI, MCP — cùng khuôn `undo_handlers.dang_ky`. Quên
    một chỗ thì nút Duyệt chết ở đúng bề mặt ấy, và chết im lặng vì `quyet_dinh` vẫn trả một
    thông điệp hợp lệ ("không có cách duyệt cổng `G1`").
    """
    router.cong_phu_handlers["G1"] = lambda khoa, quyet, note, c: _duyet_ke_hoach(
        router, c or ctx, khoa, quyet, note)


def _du_an(ctx: Any) -> Path:
    if not getattr(ctx, "project_dir", None):
        raise EideError("E2000", "Chưa mở dự án nào — không biết duyệt kế hoạch của dự án nào",
                        exists=[], candidates=["project.open"], missing=["project_dir"])
    return Path(str(ctx.project_dir)).expanduser()


def _duyet_ke_hoach(router: Any, ctx: Any, khoa: str, quyet: str, note: str) -> dict[str, Any]:
    """Cổng G1 phán lên KẾ HOẠCH, nên duyệt G1 là sửa `decision` trong tệp kế hoạch.

    `code.generate_module` đọc đúng trường ấy để thực hiện tiền điều kiện của chính nó —
    CODE-01 ghi grounding là **"G1 approved"**. Nên sau khi người duyệt, quyết định phải nằm ở
    chỗ mã đi tìm, không chỉ ở sổ cái.

    Ghi `by: human` và giữ nguyên `rule` cũ trong `truoc`: POLICY-06 (POL-17 §7) học từ "tỷ lệ
    người APPROVE khi máy ASK", và câu ấy chỉ trả lời được nếu còn biết máy đã nói gì.

    **Từ chối KHÔNG xoá kế hoạch.** Một kế hoạch bị bác vẫn là dữ liệu: người dùng cần đọc lại
    nó để biết mình vừa bác cái gì, và `plan.replan` cần nó làm điểm xuất phát.
    """
    from eide.caps.plan import doc_plan_feature, ghi_plan

    run_id, _, cong = khoa.partition(":")
    root = _du_an(ctx)
    feature = _feature_cua_run(root, run_id)
    if feature is None:
        raise EideError("E2000", f"Không tìm được kế hoạch nào của lượt chạy `{run_id}`",
                        exists=[], candidates=["plan.create"], missing=[khoa])
    d = doc_plan_feature(root, feature) or {}
    truoc = dict(d.get("decision") or {})
    moi = {"decision": "APPROVE" if quyet == "approve" else "REJECT",
           "rule": f"{cong}-HUMAN", "gate": cong,
           "reason": note or ("người duyệt" if quyet == "approve" else "người từ chối"),
           "by": "human", "at": datetime.now(UTC).isoformat(), "truoc": truoc}
    ghi_plan(root, feature, d.get("plan") or {}, moi)

    # Điểm cần làm rõ do chính cổng này sinh ra ([DEV-171]) nay đã có câu trả lời — để nó `open`
    # là bắt người dùng nhìn mãi một câu họ vừa trả lời xong.
    n = _dong_diem_cua_cong(root, feature, cong, quyet, note)
    return {"cap": "plan.create", "feature": feature, "decision": moi,
            "clarification_closed": n}


def _feature_cua_run(root: Path, run_id: str) -> str | None:
    """Kế hoạch nào do lượt chạy `run_id` sinh ra.

    Khoá cổng phụ mang `run_id` chứ không mang tên tính năng — `_ghi_cong_phu` của Router dựng
    nó từ mã lượt chạy, và Router không biết gì về tính năng. Nên phải tra ngược ở đây.

    Quét thư mục thay vì giữ một bảng ánh xạ: số kế hoạch của một dự án là hàng chục, còn một
    bảng thứ hai là một chỗ nữa để lệch.
    """
    import json

    thu = root / ".eide" / "plans"
    if not thu.is_dir():
        return None
    ung: list[tuple[str, str]] = []
    for f in sorted(thu.glob("*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if (d.get("decision") or {}).get("run_id") == run_id:
            return str(d.get("feature") or f.stem)
        ung.append((str(d.get("feature") or f.stem), str(d.get("at") or "")))
    # Chưa có `run_id` trong tệp (kế hoạch ghi trước bản vá này) thì lấy bản MỚI NHẤT — một dự
    # án đang chạy dở không được mất đường duyệt vì một lần nâng cấp.
    return max(ung, key=lambda x: x[1])[0] if ung else None


def _dong_diem_cua_cong(root: Path, feature: str, cong: str, quyet: str, note: str) -> int:
    """Đánh dấu điểm cần làm rõ mà cổng này sinh ra là ĐÃ TRẢ LỜI.

    Khớp theo NỘI DUNG (`Cổng <G>` + tên tính năng) chứ không giữ thêm một cột khoá: mã điểm
    cần làm rõ băm theo chính nội dung ấy ([DEV-151]), nên nội dung đã là khoá.
    """
    from eide.caps.req import ghi_tra_loi

    van = ("Người duyệt" if quyet == "approve" else "Người từ chối") + \
          (f": {note}" if note else ".")
    return ghi_tra_loi(root, lambda t: f"Cổng {cong}" in t and f"`{feature}`" in t, van)
