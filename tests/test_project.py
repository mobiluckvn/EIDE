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
    # `gate.decision` nằm GIỮA start và finish: mọi lời gọi đều đi qua cổng, và từ 12/09/2026
    # quyết định ấy vào chuỗi băm chứ không chỉ vào bảng `decision_log`. Điều đó là bắt buộc
    # chứ không phải thêm cho đủ: `store.BANG_VAN_HANH` loại `decision_log` khỏi niêm phong với
    # lý do "mọi quyết định cũng vào nhật ký `gate.decision`" — mà tới hôm ấy câu này chưa đúng.
    # `undo.register` đi sau `cap.run.finish`: project.create có undo=delete_created_files nên
    # Router đưa nó vào cửa sổ hoàn tác ngay (POL-17 §5, xem test_policy_undo_escalate.py).
    assert kinds == ["cap.run.start", "gate.decision", "cap.run.finish", "undo.register"]
    assert run.undo == "delete_created_files"


def test_trung_ten_thi_DUNG_LAI_chu_khong_giet_chuoi(tmp_path, workspace):
    """Gõ lần hai cùng tên → DÙNG LẠI dự án ấy, không E2001. [DEV-242]

    Đo 24/09/2026, chạy thật daemon: câu *"tạo dự án bộ đếm xung cho ATmega328P"* gõ lần hai làm
    nút 1 của chuỗi Z-01 hỏng E2001 và 13 nút còn lại không bao giờ chạy. Trong `~/eide` của chủ
    sản phẩm có 52 dự án, nên đây là ca THƯỜNG, không phải ca hiếm.

    AGD-32 Đ6: slug đã tồn tại nghĩa là đây không phải tình huống "tạo" — việc đúng là MỞ nó.
    Chính hợp đồng cũ cũng đã ghi `options=["reuse", …]` với `reuse` đứng đầu, chỉ là danh sách
    ấy nằm trong một ngoại lệ nên không ai đọc.
    """
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    dau = r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx)
    assert dau.status == "done" and dau.result["created"] is True
    lai = r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx)
    assert lai.status == "done", "nút không được hỏng — cả chuỗi sau nó phụ thuộc chỗ này"
    assert lai.result["created"] is False and lai.result["reused"] is True
    assert lai.result["path"] == dau.result["path"], "phải trỏ về CHÍNH dự án đã có"
    assert lai.result["next"] == ["req.elicit"]


def test_trung_ten_van_E2001_khi_chinh_sach_la_error(tmp_path, workspace):
    """`create_when_exists: error` thì giữ nguyên hành vi cũ — chính sách là của người."""
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace, extra={"create_when_exists": "error"})
    assert r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx).status == "done"
    run = r.invoke("project.create", {"text": "dự án đèn LED nhấp nháy"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2001"


def test_go_nham_van_bao_existing_nhung_KHONG_dung_chuoi(tmp_path, workspace):
    """Gõ NHẦM vẫn được BÁO qua `existing` (CDS PROJECT-01 bước 2) — nhưng nút vẫn tạo. [DEV-247]

    Bản trước bài kiểm này đòi `created is False`, tức nút `project.create` thành một no-op. Đo
    24/09/2026: đúng cái no-op ấy làm `req.elicit` ngay sau đó chết với "cần một dự án đang mở",
    và cả chuỗi 14 nút mất vì một phép so tên.

    Điều bài kiểm canh vẫn nguyên: phép nhận gõ nhầm phải NỔ và phải nói giống dự án nào. Thứ đổi
    là hệ quả — báo mà không chặn.
    """
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    r.invoke("project.create", {"text": "robot cân bằng hai bánh"}, ctx)
    run = r.invoke("project.create", {"text": "robot cân bằng hai bnáh"}, ctx)
    assert run.status == "done" and run.result["existing"], "gõ nhầm phải được báo"
    assert run.result["created"] is True, "báo thì báo, nhưng không được làm nút thành no-op"


def test_hau_to_v2_la_mot_LOAT_nen_tao_that(tmp_path, workspace):
    """`… v2` sau một dự án đã có thì TẠO, không hỏi — cùng hình dạng với `congvt1` → `congvt2`."""
    r = _router(tmp_path)
    ctx = Context(project_dir=workspace)
    r.invoke("project.create", {"text": "robot cân bằng hai bánh"}, ctx)
    run = r.invoke("project.create", {"text": "robot cân bằng hai bánh v2"}, ctx)
    assert run.status == "done" and run.result["created"] is True


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


# ---------------------------------------------------------------- tên gần giống [DEV-198]


import pytest  # noqa: E402


@pytest.mark.parametrize("a,b", [
    ("congvt2", "congvt1"),
    ("cnc-v3", "cnc-v2"),
    ("toan-canh-v8", "toan-canh-v7"),
    ("hoan-tac5", "hoan-tac"),
    ("nhat-ky-test-3", "nhat-ky-test-1"),
    ("cnc-A2", "cnc-B2"),      # loạt đánh chỉ mục bằng CHỮ, không chỉ bằng số
    ("cnc-A7", "cnc-B1"),
    ("thiet-ke-v4", "thiet-ke-v2"),
])
def test_ten_khac_nhau_o_SO_CUOI_la_mot_LOAT_chu_khong_phai_go_nham(a, b):
    """**Đánh số là chủ ý, không phải lỗi.**

    Levenshtein ≤ 2 của PROJECT-01 bước 2 sinh ra để bắt gõ nhầm, nhưng `congvt1` ↔ `congvt2`
    cũng lệch đúng một ký tự. Đo 23/09/2026 trên workspace chủ sản phẩm: **37 trên 52 dự án có
    tên kết thúc bằng số**. Với luật cũ, gần như MỌI lần tạo dự án mới đều bị hỏi "có nhầm
    không" — và một lời hỏi hỏi mãi là lời hỏi người ta bấm qua mà không đọc.
    """
    from eide.caps.project import _similar
    assert not _similar(a, b), f"{a} vs {b} bị coi là gõ nhầm"


@pytest.mark.parametrize("a,b", [
    ("robot-hai-bnah", "robot-hai-banh"),
    ("may-cnv", "may-cnc"),
    ("den-lde", "den-led"),
    ("may-cnc-lan-usb", "may-cnc-lan"),
])
def test_GO_NHAM_that_thi_van_bat_duoc(a, b):
    """Nới luật cho loạt đánh số KHÔNG được làm mất phép bắt gõ nhầm — đó là việc gốc của nó."""
    from eide.caps.project import _similar
    assert _similar(a, b), f"{a} vs {b} lọt lưới gõ nhầm"


def test_ten_gan_giong_VAN_TAO_va_hoi_sau(workspace):
    """Tên gần giống thì TẠO rồi hỏi sau, không dừng cả chuỗi. [DEV-247]

    Nhánh cũ trả `created: False` — một nút `done` mà KHÔNG LÀM GÌ. Đo 24/09/2026 trên câu
    *"làm bộ đo độ ẩm đất dùng ATmega328P"*: `project.create` báo xong, thư mục không tồn tại, và
    `req.elicit` ngay sau đó chết với "cần một dự án đang mở" — cả chuỗi 14 nút mất vì một phép
    so tên.

    Lời cảnh báo KHÔNG bị bỏ: nó thành một điểm cần làm rõ trong chính dự án mới, nơi người dùng
    sẽ đọc nó cùng những điểm khác. Tạo thêm một dự án thì hoàn tác được; làm chết một chuỗi 14
    nút thì không.
    """
    from eide_core import store
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=Ledger(workspace / "l.jsonl"))
    r.invoke("project.create", {"text": "may cnc lan"}, Context(project_dir=workspace))

    ctx = Context(project_dir=workspace)
    moi_ra = r.invoke("project.create", {"text": "may cnc lan usb"}, ctx)
    assert moi_ra.result["created"] is True, "tên gần giống không được làm nút thành no-op"
    assert moi_ra.result["existing"], "tạo rồi vẫn phải nói giống dự án nào"
    root = workspace / moi_ra.result["project_id"]
    assert (root / ".eide").is_dir(), "thư mục dự án phải CÓ THẬT — nút sau đọc nó"

    # Lời cảnh báo đi về chỗ người tìm, không biến mất.
    with store.open_store(store.store_path(root)) as c:
        van = " ".join(str(x[0]) for x in c.execute("SELECT text FROM clarification"))
    assert "gần giống" in van and "may-cnc-lan" in van


def test_bo_so_cuoi_khong_duoc_NUOT_chu_cai_cua_mot_tu_that():
    """`hoan-tac5` → `hoan-tac`, KHÔNG phải `hoan-ta`.

    Luật bỏ chỉ mục phải nhận cả loạt đánh bằng chữ (`cnc-A2` ↔ `cnc-B2`), nhưng nếu bỏ chữ cái
    trước số mà không đòi có gạch nối đứng trước thì `hoan-tac5` mất luôn chữ `c` cuối của một
    TỪ THẬT. Khi ấy phép "so gốc" đang so hai thứ không phải gốc, và nó sai âm thầm — `hoan-tac5`
    ↔ `hoan-tac` quay lại bị hỏi, đúng cái lỗi vừa sửa.
    """
    from eide.caps.project import _goc_khong_so, _similar
    assert _goc_khong_so("hoan-tac5") == "hoan-tac"
    assert _goc_khong_so("cnc-A2") == _goc_khong_so("cnc-B2") == "cnc"
    assert _goc_khong_so("may-cnc") == "may-cnc", "không có số thì không bỏ gì"
    assert not _similar("hoan-tac5", "hoan-tac")
