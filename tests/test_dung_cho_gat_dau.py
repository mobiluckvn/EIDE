"""UXC-31 §2D.6 — chỗ dừng để người gật đầu trước khi chuỗi chạy ([DEV-140]).

Tới v1.2 `chat.orchestrate` dựng chuỗi VÀ chạy nó trong cùng một lời gọi, nên không có trạng
thái trung gian nào giữa "chuỗi đã dựng" và "bước đầu tiên đã chạy" — và hai nút *Đúng — làm
đi* / *Sửa ý hiểu* của §2D.6 sẽ nằm trên một chuỗi đã giao đi.
"""
from __future__ import annotations

import pytest

from eide.caps.chat import doc_ke_hoach
from eide_core.errors import EideError
from test_code import _du_an_git


def _du_an(tmp_path, workspace):
    return _du_an_git(tmp_path, workspace)


def _lap(r, ctx, plan_only: bool):
    return r.invoke("chat.orchestrate",
                    {"intent": {"intent": "kg.build", "slots": {}}, "grounded": {},
                     "text": "dựng đồ thị tri thức", "plan_only": plan_only}, ctx)


def test_plan_only_DUNG_LAI_va_khong_chay_nut_nao(tmp_path, workspace):
    """**Không nút nào chạy, và KHÔNG ghi `run.started`.**

    Một thẻ Run hiện lên cho một lượt đang chờ người gật đầu là nói rằng tác tử đang làm việc
    trong khi nó đang đợi — đúng thứ §2D.6 sinh ra để tránh.
    """
    r, ctx, root = _du_an(tmp_path, workspace)

    run = _lap(r, ctx, plan_only=True)
    assert run.status == "done", run.error
    assert run.result["state"] == "planned", run.result
    assert run.result["steps"], "không trả danh sách bước dự kiến"

    # Đếm lời gọi của các NÚT, không đếm tổng `cap.run.start`: chính `chat.orchestrate` cũng
    # đi qua Router nên nó tự ghi một bản. Đếm tổng thì bài này đỏ vì phép đo sai chứ không vì
    # `plan_only` hỏng.
    nut = {n["cap"] for n in run.result["steps"]}
    da_chay = {(x["data"] or {}).get("cap") for x in r.ledger.records()
               if x["kind"] == "cap.run.start"}
    assert not (nut & da_chay), f"plan_only mà vẫn chạy nút: {nut & da_chay}"
    assert not [x for x in r.ledger.records() if x["kind"] == "run.started"], \
        "ghi `run.started` cho một lượt chưa bắt đầu"

    kh = doc_ke_hoach(root, run.result["run_id"])
    assert kh["state"] == "planned" and kh["graph"].get("nodes")


def test_resume_chay_TIEP_chinh_do_thi_da_duyet(tmp_path, workspace):
    """**Giữ nguyên `run_id` và đồ thị.** Lập lại kế hoạch ở bước này có thể ra một chuỗi khác
    chuỗi người vừa đọc và vừa gật đầu — tức họ duyệt một thứ và máy chạy một thứ khác."""
    r, ctx, root = _du_an(tmp_path, workspace)
    lap = _lap(r, ctx, plan_only=True).result
    truoc = [n["id"] for n in lap["steps"]]

    tiep = r.invoke("chat.orchestrate",
                    {"intent": {}, "grounded": {}, "resume_of": lap["run_id"]}, ctx)
    assert tiep.status == "done", tiep.error
    assert tiep.result["run_id"] == lap["run_id"], "chạy tiếp mà đẻ ra một lượt mới"
    assert [n["id"] for n in tiep.result["steps"]] == truoc, "đồ thị đổi giữa duyệt và chạy"
    assert doc_ke_hoach(root, lap["run_id"])["state"] != "planned"


def test_resume_mot_lot_KHONG_o_planned_thi_tu_choi(tmp_path, workspace):
    """Chạy tiếp một lượt đã chạy rồi là chạy HAI LẦN cùng một chuỗi."""
    r, ctx, root = _du_an(tmp_path, workspace)
    xong = _lap(r, ctx, plan_only=False).result

    with pytest.raises(EideError) as e:
        r.invoke("chat.orchestrate", {"intent": {}, "grounded": {},
                                      "resume_of": xong["run_id"]}, ctx).raise_for_status() \
            if False else _raise(r, ctx, xong["run_id"])
    assert "planned" in str(e.value)


def _raise(r, ctx, run_id):
    run = r.invoke("chat.orchestrate",
                   {"intent": {}, "grounded": {}, "resume_of": run_id}, ctx)
    raise EideError((run.error or {}).get("eide_code", "E2000"),
                    (run.error or {}).get("message", ""))


def test_resume_mot_run_KHONG_CO_thi_noi_ra(tmp_path, workspace):
    r, ctx, root = _du_an(tmp_path, workspace)
    run = r.invoke("chat.orchestrate",
                   {"intent": {}, "grounded": {}, "resume_of": "r_khong_co"}, ctx)
    assert run.status != "done"
    assert (run.error or {}).get("eide_code") == "E2000", run.error


def test_huy_ke_hoach_doi_trang_thai_chu_khong_de_nguyen(tmp_path, workspace):
    """Người bấm *Sửa ý hiểu* là người nói chuỗi này sai.

    Để nó ở `planned` thì lần mở dự án sau nó vẫn nằm trong hàng đợi như một việc đang chờ, và
    người dùng phải nhớ rằng chính mình đã từ chối nó.
    """
    from eide.caps.chat import huy_ke_hoach
    r, ctx, root = _du_an(tmp_path, workspace)
    lap = _lap(r, ctx, plan_only=True).result

    huy_ke_hoach(root, lap["run_id"], r.ledger)
    assert doc_ke_hoach(root, lap["run_id"])["state"] == "cancelled"
    huy = [x for x in r.ledger.records() if x["kind"] == "run.cancelled"]
    assert huy and "sửa ý hiểu" in (huy[-1]["data"] or {}).get("reason", "")


def test_luat_muc_nao_thi_dung_cho_gat_dau():
    """§2D.6 nguyên văn: A1 hỏi trước, A2–A3 tự chạy nhưng vẫn in ý hiểu.

    Mức LẠ thì không dừng — mặc định an toàn ở đây là chạy tiếp, vì một mức gõ sai làm treo mọi
    lệnh sẽ trông y hệt sản phẩm hỏng.
    """
    from eide.daemon.rpc import cho_nguoi_gat
    assert cho_nguoi_gat("A0") and cho_nguoi_gat("A1")
    assert not cho_nguoi_gat("A2")
    assert not cho_nguoi_gat("A3")
    assert not cho_nguoi_gat("A4")
    assert not cho_nguoi_gat("khong-phai-muc")
