"""PROJECT-01/03 theo tc trong cds.json: tạo đúng cấu trúc; gọi lần 2 cùng tên → E2001; gần giống → existing[] và created=false."""
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def _router(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))


def test_create_structure_and_ledger(tmp_path, workspace):
    r = _router(tmp_path)
    run = r.invoke("project.create", {"text": "Tạo cho anh dự án robot hai bánh tự cân bằng", "autonomy": "A3"}, Context(project_dir=workspace))
    assert run.status == "done", run
    res = run.result
    assert res["created"] and res["project_id"] == "robot-hai-banh-tu-can-bang"
    e = workspace / res["project_id"] / ".eide"
    for name in ["store", "session", "index", "docs", "diagrams", "PROGRESS.md", "FEATURES.json", "constraints.yaml", "autonomy.yaml", "models.yaml", ".gitignore"]:
        assert (e / name).exists(), name
    kinds = [x["kind"] for x in r.ledger.records()]
    # `undo.register` đi sau `cap.run.finish`: project.create có undo=delete_created_files nên
    # Router đưa nó vào cửa sổ hoàn tác ngay (POL-17 §5, xem test_policy_undo_escalate.py).
    assert kinds == ["cap.run.start", "cap.run.finish", "undo.register"]
    assert run.undo == "delete_created_files"


def test_duplicate_is_E2001(tmp_path, workspace):
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    assert r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx).status == "done"
    run = r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2001"


def test_similar_name_returns_existing(tmp_path, workspace):
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    r.invoke("project.create", {"text": "robot cân bằng hai bánh"}, ctx)
    run = r.invoke("project.create", {"text": "robot cân bằng hai bánh v2"}, ctx)
    assert run.status == "done" and run.result["created"] is False and run.result["existing"]


def test_list_orders_by_last_open(tmp_path, workspace):
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    for t in ["đèn giao thông", "máy đo nhiệt độ phòng", "cửa cuốn điều khiển xa"]:
        r.invoke("project.create", {"text": t, "name": t}, ctx)
    run = r.invoke("project.list", {"workspace": str(workspace)}, ctx)
    assert run.status == "done" and len(run.result["projects"]) == 3


def test_invalid_args_E1000(tmp_path, workspace):
    import pytest

    from eide_core.errors import EideError

    with pytest.raises(EideError) as e:
        _router(tmp_path).invoke("project.create", {}, Context(project_dir=workspace))
    assert e.value.code == "E1000"


def test_slug_giu_chu_d_gach_ngang(tmp_path, workspace):
    """`đ`/`Đ` phải thành `d`/`D`, không được biến mất.

    UXD-13 U8 đặt tiếng Việt lên trước, và slug là ĐỊNH DANH dự án: nó vào đường dẫn thư mục
    và là khóa để bước 2 của PROJECT-01 phát hiện trùng (E2001). Chuẩn hóa NFD tách được dấu
    khỏi nguyên âm (ệ → e), nhưng `đ` là một CHỮ CÁI riêng trong bảng chữ cái tiếng Việt chứ
    không phải `d` cộng dấu — NFD không tách nó, nên `encode('ascii','ignore')` xóa hẳn.

    Hậu quả không chỉ là slug xấu: hai tên khác nhau cho ra cùng một slug, và khi ấy dự án
    thứ hai bị từ chối bằng E2001 "đã tồn tại" cho một dự án mà người dùng chưa hề tạo.
    """
    from eide.caps.project import slugify

    assert slugify("máy đo nhiệt độ dùng STM32F411") == "may-do-nhiet-do-dung-stm32f411"
    assert slugify("Đèn giao thông") == "den-giao-thong"
    assert slugify("robot dò đường") == "robot-do-duong"
    assert slugify("đo điện áp") == "do-dien-ap"
    # Hai tên khác nhau thì slug phải khác nhau
    assert slugify("máy đo nhiệt độ") != slugify("máy o nhiệt o")


def test_hai_du_an_khac_dau_khong_va_cham(tmp_path, workspace):
    """Hệ quả của lỗi `đ`: dự án thứ hai bị E2001 oan."""
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    assert r.invoke("project.create", {"text": "dự án đo điện áp"}, ctx).status == "done"
    run = r.invoke("project.create", {"text": "dự án o ien ap"}, ctx)
    assert run.status == "done", "tên khác nhau không được va chạm slug"
