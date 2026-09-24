"""Sáu chỗ đứt làm sản phẩm KHÔNG chạy được — tìm ra bằng cách chạy thật, canh bằng bài kiểm.

Ngày 24/09/2026 tôi lái daemon thật (JSON-RPC qua stdio, mô hình Gemini thật) với hai câu mà một
người dùng mới sẽ gõ đầu tiên:

    "tạo dự án bộ đếm xung cho ATmega328P"
    "viết firmware đọc nhiệt độ qua I2C cho ATmega328P"

Cả hai đều chết trước nút thứ năm, và không một bài kiểm nào trong 2 038 ca lúc ấy đỏ — vì mỗi
năng lực chạy đúng phần của mình, chỗ hỏng nằm ở CHỖ NỐI giữa chúng. Đó là lý do tệp này tồn tại:
nó kiểm đường đi của cả một lượt, không kiểm một năng lực.

| Chỗ đứt | Triệu chứng khi chạy thật | DEV |
|---|---|---|
| `ctx.project_dir` không đổi sau `project.create` | tạo dự án xong, nút sau báo "cần một dự án đang mở" | 241 |
| trùng tên slug → E2001 | gõ lần hai là chuỗi chết ở nút 1 | 242 |
| không có đường nhận câu trả lời | tác tử hỏi, người trả lời, không gì xảy ra | 243 |
| chưa có dự án thì mọi chuỗi chết | câu đầu tiên của người dùng mới → E2000 | 244 |
| ba lựa chọn thẻ đề nghị bị coi là giá trị | `passport = "tri_thuc_chung"` | 245 |
| nút thiếu tiền đề mà không ai chèn | hỏi người một câu tác tử tự trả lời được (TC009) | 246 |
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from eide.caps.chat import (  # noqa: E402
    HANH_DONG_DE_NGHI,
    TIEN_DE_SINH_RA,
    _chen_tien_de,
    _chen_tien_de_du_an,
    _da_chay_xong,
    _du_an_tu_ket_qua,
    danh_dau_bo_qua_theo_nguoi,
    ghi_tra_loi_vao_intent,
    tra_loi_cau_hoi_chuoi,
)
from eide_core import chain as chain_mod  # noqa: E402
from eide_core import store  # noqa: E402
from eide_core.router import Context  # noqa: E402


def _du_an(tmp_path: Path, ten: str = "du-an-x") -> Path:
    root = tmp_path / ten
    (root / ".eide").mkdir(parents=True)
    store.migrate(store.store_path(root))
    return root


def _chuoi(*cap: str) -> chain_mod.Chain:
    nut = [chain_mod.Nut(id=f"n{i}", cap=c, args={}, when=(f"n{i - 1}" if i > 1 else None),
                         on_ask="wait") for i, c in enumerate(cap, start=1)]
    return chain_mod.Chain(nut)


# ──────────────────────────────── DEV-241: nút project.* đổi dự án đang mở

def test_nut_project_doi_du_an_dang_mo(tmp_path):
    """`project.create` xong thì `ctx.project_dir` phải trỏ vào dự án ấy.

    Không có nhánh này thì `req.elicit` ngay sau đó báo "Nhóm req.* cần một dự án đang mở" —
    tác tử vừa tạo dự án và không thấy dự án nào.
    """
    root = _du_an(tmp_path)
    assert _du_an_tu_ket_qua("project.create", {"path": str(root)}) == root
    assert _du_an_tu_ket_qua("project.open", {"summary": {"path": str(root)}}) == root


def test_khong_doi_du_an_theo_mot_duong_dan_bat_ky(tmp_path):
    """Chỉ nút `project.*`, và chỉ khi `.eide/` CÓ THẬT.

    `archive.unpack` cũng trả `path`; đổi dự án theo nó sẽ đưa cả chuỗi còn lại đi làm việc ở một
    chỗ khác chỗ người dùng đang làm. `project.create` trả `path` kèm `created: false` khi nó dừng
    để hỏi — lúc ấy thư mục có thể chưa tồn tại.
    """
    root = _du_an(tmp_path)
    assert _du_an_tu_ket_qua("archive.unpack", {"path": str(root)}) is None
    assert _du_an_tu_ket_qua("project.create", {"path": str(tmp_path / "chua-co")}) is None
    assert _du_an_tu_ket_qua("project.create", None) is None


# ──────────────────────────────── DEV-244: chèn project.create khi chưa có dự án

def test_chen_project_create_khi_chua_co_du_an(tmp_path):
    """Câu ĐẦU TIÊN của một người dùng mới không được trả về một mã lỗi."""
    c = _chuoi("chat.ground", "req.elicit", "req.classify")
    moi = _chen_tien_de_du_an(c, {"intent": "code.feature", "slots": {}}, {},
                              Context(project_dir=tmp_path), "r_test")
    assert [n.cap for n in moi.nodes][0] == "project.create"
    assert moi.nodes[0].id == "n0" and moi.nodes[0].when is None
    assert moi.nodes[1].when == "n0", "nút gốc cũ phải treo vào nút tiền đề, không chạy song song"


def test_khong_chen_khi_da_co_du_an_dang_mo(tmp_path):
    root = _du_an(tmp_path)
    c = _chuoi("req.elicit")
    assert _chen_tien_de_du_an(c, {}, {}, Context(project_dir=root), "r") is c


def test_khong_chen_khi_chuoi_da_co_nut_project(tmp_path):
    """Mẫu Z-01 mở đầu bằng `project.create` — chèn bản thứ hai là tạo dự án hai lần."""
    c = _chuoi("project.create", "req.elicit")
    assert _chen_tien_de_du_an(c, {}, {}, Context(project_dir=tmp_path), "r") is c


def test_khong_chen_khi_khong_nut_nao_can_du_an(tmp_path):
    c = _chuoi("chat.parse_intent", "policy.emergency_stop")
    assert _chen_tien_de_du_an(c, {}, {}, Context(project_dir=tmp_path), "r") is c


# ──────────────────────────────── DEV-246: chèn nút sinh ra ô trống (TC009)

def test_chen_nut_sinh_ra_o_trong(tmp_path):
    """Ví dụ TC009 của AAD-33 §3.2.2: `arch.map_hw` thiếu `module_ids` → chèn `arch.decompose`."""
    root = _du_an(tmp_path)
    c = _chuoi("req.classify", "arch.map_hw")
    moi, da_chen = _chen_tien_de(c, {"n2": ["module_ids"]}, {"intent": "code.feature", "slots": {}},
                                 {}, Context(project_dir=root), "r")
    assert "arch.decompose" in da_chen
    caps = [n.cap for n in moi.nodes]
    assert caps.index("arch.decompose") < caps.index("arch.map_hw"), "phải đứng TRƯỚC nút thiếu"
    nut_moi = next(n for n in moi.nodes if n.cap == "arch.decompose")
    nut_can = next(n for n in moi.nodes if n.cap == "arch.map_hw")
    assert nut_can.when == nut_moi.id


def test_khong_chen_nang_luc_da_co_trong_chuoi(tmp_path):
    root = _du_an(tmp_path)
    c = _chuoi("arch.decompose", "arch.map_hw")
    _, da_chen = _chen_tien_de(c, {"n2": ["module_ids"]}, {}, {}, Context(project_dir=root), "r")
    assert not any(x == "arch.decompose" for x in da_chen)


def test_muon_phep_noi_tu_mau_khac(tmp_path):
    """[DEV-121]: ánh xạ `reqset` → `reqset_ids` là tri thức chỉ MẪU có quyền nói.

    Nút do bộ chèn dựng ra không có mẫu nào nói hộ, nên nó MƯỢN phép nối từ mẫu khác đã khai
    cùng năng lực (Z-01 khai `arch.decompose` với `reqset_ids: "${nX.reqset[*].id}"`), và đổi tên
    nút được trỏ tới sang id trong chuỗi của mình.
    """
    root = _du_an(tmp_path)
    c = _chuoi("req.classify", "arch.map_hw")
    moi, _ = _chen_tien_de(c, {"n2": ["module_ids"]}, {"intent": "code.feature", "slots": {}},
                           {}, Context(project_dir=root), "r")
    nut = next(n for n in moi.nodes if n.cap == "arch.decompose")
    tham = nut.args.get("reqset_ids")
    assert isinstance(tham, str) and tham.startswith("${n1."), \
        f"phải trỏ vào nút req.classify của CHÍNH chuỗi này, không phải id của mẫu: {tham!r}"


def test_bang_tien_de_chi_ghi_cap_truy_duoc_ve_hop_dong():
    """Một cặp sai thêm một nút tốn token rồi ô trống vẫn trống."""
    from eide_core.registry import get_registry
    reg = get_registry()
    for o, cap in TIEN_DE_SINH_RA.items():
        assert cap in reg, f"`{cap}` (tiền đề của `{o}`) không có trong danh mục năng lực"


# ──────────────────────────────── DEV-243: trả lời rồi chạy tiếp

def test_doc_lai_nut_da_xong_de_khong_chay_lai(tmp_path):
    """Chạy lại `req.elicit` vừa tốn token vừa nâng phiên bản đặc tả lần thứ hai."""
    root = _du_an(tmp_path)
    c = _chuoi("req.elicit", "req.classify")
    from eide.caps.chat import _ghi_run
    _ghi_run(root, "r_1", c, "asked", {"intent": "x"},
             {"done": [{"id": "n1", "cap": "req.elicit", "dau_ra": {"raw": 1}}],
              "waiting": [{"id": "n2", "cap": "req.classify", "clar_id": "CL-abc",
                           "thieu": ["style"], "truong": [{"khoa": "style"}]}]})
    xong, ra = _da_chay_xong(root, "r_1")
    assert xong == {"n1"} and ra == {"n1": {"raw": 1}}


def test_nut_co_dau_ra_bi_cat_thi_chay_lai(tmp_path):
    """`_cat_dau_ra` thay đầu ra quá lớn bằng một dấu; nối `${nX.field}` vào dấu ấy là nối vào
    chỗ rỗng, và nút sau sẽ hỏng ở một chỗ khác hẳn nguyên nhân."""
    root = _du_an(tmp_path)
    from eide.caps.chat import _ghi_run
    _ghi_run(root, "r_2", _chuoi("code.generate_module"), "asked", {},
             {"done": [{"id": "n1", "cap": "code.generate_module",
                        "dau_ra": {"_cat": True, "_khoa": ["patch"]}}]})
    xong, _ = _da_chay_xong(root, "r_2")
    assert xong == set(), "nút có đầu ra bị cắt KHÔNG được coi là xong"


def test_tra_loi_tim_duoc_luot_va_o_trong(tmp_path):
    """Trước [DEV-243] không có đường nào đi từ mã `CL-…` về lượt đang chờ."""
    root = _du_an(tmp_path)
    from eide.caps.chat import _ghi_run
    _ghi_run(root, "r_3", _chuoi("req.elicit", "arch.map_hw"), "asked",
             {"intent": "code.feature", "slots": {}},
             {"done": [], "waiting": [{"id": "n2", "cap": "arch.map_hw", "clar_id": "CL-xyz",
                                       "thieu": ["passport"],
                                       "truong": [{"khoa": "passport"}]}]})
    ngu_canh = tra_loi_cau_hoi_chuoi(root, "CL-xyz", "avr8")
    assert ngu_canh["run_id"] == "r_3" and ngu_canh["khoa"] == ["passport"]
    assert ngu_canh["node_id"] == "n2" and ngu_canh["cap"] == "arch.map_hw"


def test_tra_loi_gia_tri_vao_slot_mang_origin_user(tmp_path):
    """Câu trả lời của người thắng mô hình, nhường bộ trích xác định (AAD-33 §2.2)."""
    root = _du_an(tmp_path)
    from eide.caps.chat import _ghi_run
    _ghi_run(root, "r_4", _chuoi("env.check"), "asked",
             {"intent": "env.setup", "slots": {"isa": "doan-tu-mo-hinh"},
              "origins": {"isa": "model"}}, {"done": [], "waiting": []})
    it = ghi_tra_loi_vao_intent(root, "r_4", {"isa": "avr8"})
    assert it["slots"]["isa"] == "avr8" and it["origins"]["isa"] == "user"


# ──────────────────────────────── DEV-245: ba lựa chọn là HÀNH ĐỘNG

def test_ba_lua_chon_la_hanh_dong_khong_phai_gia_tri():
    """Nhét `"tri_thuc_chung"` vào slot `passport` là đẩy một mã hộ chiếu không tồn tại xuống
    `req.ground_hw` — đúng lỗi "câu trả lời sai tệ hơn ô trống" ([DEV-183])."""
    assert set(HANH_DONG_DE_NGHI) == {"tri_thuc_chung", "toi_nap_tep", "tim_tren_mang"}
    assert HANH_DONG_DE_NGHI["tri_thuc_chung"] == "bo_qua_nut"


def test_danh_dau_bo_qua_song_qua_tien_trinh(tmp_path):
    """Quyết định của người phải sống lâu hơn một tiến trình: lượt nối lại có thể chạy ở chỗ khác."""
    root = _du_an(tmp_path)
    from eide.caps.chat import _ghi_run, doc_ke_hoach
    _ghi_run(root, "r_5", _chuoi("arch.map_hw"), "asked", {}, {"done": [], "waiting": []})
    danh_dau_bo_qua_theo_nguoi(root, "r_5", "n1")
    kh = doc_ke_hoach(root, "r_5")
    assert kh["graph"]["bo_qua_theo_nguoi"] == ["n1"]
