"""CHAT-06 `chat.orchestrate` và lõi chuỗi — CDS-12.6; DPS-09 §4.4, §1. tc: TC-63.

§4.4 đòi NĂM phép kiểm deterministic sau khi có chuỗi: mọi `cap` tồn tại; tham số khớp input
schema; không có chu trình; số nút ≤ ngưỡng; ước lượng chi phí ≤ ngân sách. Phần lớn tệp này
kiểm đúng năm điều ấy, vì đó là ranh giới mà DPS-09 §1 vạch: tầng hiểu lệnh deterministic, chỉ
phần sinh mới dùng mô hình.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.chat import _noi_dau_ra, doc_bao_cao
from eide_core import store
from eide_core.chain import (
    Chain,
    Nut,
    chon_mau,
    doc_duong,
    giai_tham_chieu,
    kiem,
    mau,
    thu_tu_chay,
    tim_chu_trinh,
)
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.registry import get_registry
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án chuỗi"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _c(*nut) -> Chain:
    return Chain([Nut.tu_dict(n) for n in nut])


# ---------- chuỗi mẫu (§4.4)


def test_nam_chuoi_mau_sinh_tu_tai_lieu():
    """§4.4 có đúng năm chuỗi mẫu, và chúng phải máy đọc được.

    Trước WI-CHAT-06 bảng ấy chỉ nằm trong văn xuôi, nên phần mã phải chép tay — cùng khuôn
    DEV-025/029/043/046. Nay sinh ra `dialog/chains.json`.
    """
    ds = mau()
    assert len(ds) == 5
    assert all(c["buoc"] and c["trigger_intents"] for c in ds)


def test_chon_mau_theo_y_dinh():
    """CHAT-06 bước 1: "theo trigger_intents". Mẫu trước, planner sau — §4.4 nói thẳng lý do:
    "để mô hình bám theo thay vì sáng tác"."""
    assert chon_mau("project.create")["ten"].startswith("Dự án mới từ ý tưởng")
    assert chon_mau("code.feature")["ten"].startswith("Thêm tính năng")
    assert chon_mau("khong-co-y-dinh-nay") is None


# ---------- năm phép kiểm deterministic (§4.4)


def test_nang_luc_khong_ton_tai_bi_bat():
    with pytest.raises(EideError) as e:
        kiem(_c({"id": "n1", "cap": "khong.co.that"}), get_registry())
    assert e.value.code == "E5002" and "không có trong registry" in str(e.value)


def test_tham_so_sai_input_schema_bi_bat():
    """Một chuỗi gọi đúng năng lực nhưng sai tham số vẫn hỏng — chỉ hỏng muộn hơn, ở giữa chừng,
    sau khi vài nút trước đã ghi vào store."""
    with pytest.raises(EideError) as e:
        kiem(_c({"id": "n1", "cap": "kg.neighborhood", "args": {"node": 123}}), get_registry())
    assert e.value.code == "E5002" and "input_schema" in str(e.value)


def test_chu_trinh_bi_bat_va_NEU_RO_duong_di():
    """Trả về đường đi chứ không phải True/False: người đọc lỗi cần biết ba nút nào vòng vào
    nhau, không phải biết rằng "có chu trình ở đâu đó trong hai mươi nút"."""
    c = _c({"id": "a", "cap": "kg.build", "when": "b"},
           {"id": "b", "cap": "kg.build", "when": "c"},
           {"id": "c", "cap": "kg.build", "when": "a"})
    assert set(tim_chu_trinh(c)) == {"a", "b", "c"}
    with pytest.raises(EideError) as e:
        kiem(c, get_registry())
    assert "chu trình" in str(e.value)


def test_vuot_nguong_so_nut_bi_bat():
    c = Chain([Nut(id=f"n{i}", cap="kg.build") for i in range(30)])
    with pytest.raises(EideError) as e:
        kiem(c, get_registry(), tran_nut=12)
    assert "vượt ngưỡng 12" in str(e.value)


def test_vuot_ngan_sach_la_E3003_khong_phai_E5002():
    """Hai loại lỗi khác nhau: E5002 là chuỗi SAI, E3003 là chuỗi ĐÚNG nhưng quá đắt. Gộp một mã
    thì bên gọi không biết nên sửa kế hoạch hay nới ngân sách."""
    with pytest.raises(EideError) as e:
        kiem(_c({"id": "n1", "cap": "kg.build"}), get_registry(),
             chi_phi_uoc=5.0, ngan_sach=1.0)
    assert e.value.code == "E3003"


def test_gom_HET_loi_roi_moi_nem():
    """Một chuỗi do mô hình sinh thường sai vài chỗ cùng lúc; trả từng lỗi một sẽ tốn đúng số
    lần gọi mô hình bằng số lỗi."""
    with pytest.raises(EideError) as e:
        kiem(_c({"id": "n1", "cap": "khong.co"},
                {"id": "n1", "cap": "cung.khong.co"},
                {"id": "n3", "cap": "kg.build", "on_ask": "bay-bong"}), get_registry())
    assert e.value.data["so_loi"] >= 3, e.value.data["loi"]


def test_on_ask_ngoai_ba_gia_tri_bi_bat():
    with pytest.raises(EideError) as e:
        kiem(_c({"id": "n1", "cap": "kg.build", "on_ask": "cho-mai"}), get_registry())
    assert "on_ask" in str(e.value)


def test_phu_thuoc_nut_khong_ton_tai_bi_bat():
    with pytest.raises(EideError) as e:
        kiem(_c({"id": "n1", "cap": "kg.build", "when": "n99"}), get_registry())
    assert "không có trong chuỗi" in str(e.value)


# ---------- thứ tự chạy


def test_thu_tu_on_dinh():
    """Một bộ lập lịch chạy hai lần ra hai thứ tự khác nhau thì lỗi tái hiện được một lần rồi
    biến mất, và không ai gỡ được."""
    c = _c({"id": "c", "cap": "kg.build", "when": "b"},
           {"id": "a", "cap": "kg.build"},
           {"id": "b", "cap": "kg.build", "when": "a"})
    assert [n.id for n in thu_tu_chay(c)] == ["a", "b", "c"]
    assert [n.id for n in thu_tu_chay(c)] == [n.id for n in thu_tu_chay(c)]


# ---------- chạy thật (TC-63)


def test_orchestrate_chay_chuoi_qua_ROUTER(du_an):
    """CHAT-06 bước 4: "mỗi nút Router.invoke".

    Cùng đường đi với mọi lời gọi khác, nên cùng chính sách, cùng nhật ký, cùng hoàn tác —
    Orchestrator KHÔNG có đường tắt. Kiểm bằng cách soi ledger: mỗi nút phải để lại một
    `cap.run.start` như một lời gọi bình thường.
    """
    r, ctx, _ = du_an
    truoc = len([x for x in r.ledger.records() if x["kind"] == "cap.run.start"])
    out = r.invoke("chat.orchestrate",
                   {"intent": {"intent": "kg.build", "slots": {}}, "grounded": {}}, ctx).result
    assert set(out) == {"run_id"}, "hợp đồng trả ĐÚNG {run_id} — CHAT-06 là bất đồng bộ"
    bc = doc_bao_cao(ctx.project_dir, out["run_id"])
    assert bc["state"] == "done", bc
    assert [n["cap"] for n in bc["done"]] == ["kg.build"]
    sau = len([x for x in r.ledger.records() if x["kind"] == "cap.run.start"])
    assert sau > truoc + 1, "nút của chuỗi phải đi qua Router, không gọi tắt handler"


def test_ghi_run_graph_de_tiep_tuc_sau_tat_may(du_an):
    """CHAT-06 bước 3 và 5: "Run planned→running … tiếp tục sau tắt máy".

    Kế hoạch phải xuống store TRƯỚC khi chạy: một chuỗi đang chạy dở mà máy tắt thì phần đã làm
    vẫn phải đọc lại được, và `run.graph` là chỗ duy nhất giữ được điều đó.
    """
    r, ctx, root = du_an
    out = r.invoke("chat.orchestrate", {"intent": {"intent": "kg.build"}, "grounded": {}}, ctx).result
    with store.open_store(store.store_path(root)) as c:
        row = c.execute("SELECT graph, state FROM run WHERE id=?", (out["run_id"],)).fetchone()
    assert row is not None, "không ghi run.graph thì chuỗi không tiếp tục được sau tắt máy"
    assert json.loads(row[0])["nodes"], "graph rỗng"
    assert row[1] == "done"


def test_nut_ASK_lam_chuoi_dung_khi_on_ask_wait(du_an):
    """§4.4: `wait` dừng nhánh. Các nút sau phụ thuộc chỗ này nên chạy tiếp là chạy trên một
    tiền đề chưa ai duyệt."""
    r, ctx, _ = du_an
    out = r.invoke("chat.orchestrate",
                   {"intent": {"intent": "kg.resolve_conflict",
                               "slots": {"conflict_id": "f_a:f_b", "choice": "a",
                                         "actor": "agent"}}, "grounded": {}}, ctx).result
    bc = doc_bao_cao(ctx.project_dir, out["run_id"])
    assert bc["state"] == "asked"
    assert [n["cap"] for n in bc["waiting"]] == ["kg.resolve_conflict"]


def test_chuoi_rong_khi_khong_co_mau_va_y_dinh_khong_phai_nang_luc(du_an):
    """Nói ra là rỗng chứ không giả vờ đã làm gì: `unknown` không ánh xạ sang năng lực nào."""
    r, ctx, _ = du_an
    run = r.invoke("chat.orchestrate", {"intent": {"intent": "unknown"}, "grounded": {}}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"
    assert "chuỗi rỗng" in run.error["message"]


def test_planner_vao_cuoc_khi_khong_mau_nao_khop(du_an, monkeypatch):
    """DEV-051 đóng: `chat.orchestrate` gọi vai trò `planner` qua `plan.create`.

    Gọi QUA ROUTER chứ không gọi thẳng hàm — `plan.create` là T1* và hỏi cổng G1 bên trong, nên
    một kế hoạch thiếu tri thức hay đổi kiến trúc dừng ở đó chứ không lặng lẽ thành chuỗi.

    **Ý định phải KHÔNG trùng tên một năng lực nào**, vì `_chuoi_toi_thieu` xét "ý định-là-năng-
    lực" TRƯỚC planner. Bản đầu bài này dùng `code.refactor` làm ví dụ cho "không mẫu nào khớp"
    — đúng, cho tới 12/09/2026 khi `code.refactor` được hiện thực: từ lúc ấy lối tắt kia bắt
    được nó, planner không vào cuộc nữa, và bài đỏ vì một tiền đề đã bốc hơi chứ không vì mã
    hỏng. Nay dùng một tên KHÔNG BAO GIỜ là năng lực, nên tiền đề không hết hạn được nữa.
    """
    class _GW:
        def prompt(self, role): return f"# {role}"

        def run(self, role, prompt, schema, system_extra=""):
            class R:
                data = {"steps": [{"id": "s1", "goal": "dựng đồ thị", "cap": "kg.build"},
                                  {"id": "s2", "goal": "tìm mâu thuẫn", "cap": "kg.conflicts"},
                                  {"id": "s3", "goal": "việc của người", "cap": "khong.co"}]}
            return R()

    r, ctx, root = du_an
    ctx.extra["gateway"] = _GW()
    out = r.invoke("chat.orchestrate",
                   {"intent": {"intent": "lam_gon_ma_i2c", "slots": {"feature": "gọn lại I2C"}},
                    "grounded": {}}, ctx).result
    from eide_core.registry import get_registry
    assert "lam_gon_ma_i2c" not in get_registry(), "tiền đề của bài này: KHÔNG phải năng lực"
    bc = doc_bao_cao(root, out["run_id"])
    assert bc["nguon_chuoi"] == "planner", bc["nguon_chuoi"]
    # Bước có `cap` chưa hiện thực bị bỏ — nhưng chuỗi vẫn chạy phần làm được.
    assert [n["cap"] for n in bc["done"]] == ["kg.build", "kg.conflicts"]


def test_khong_dung_duoc_chuoi_thi_NOI_RA(du_an):
    """Trả "không dựng được chuỗi" rồi để `kiem()` báo chuỗi rỗng — thật thà hơn là im lặng trả
    một run_id cho một việc chưa hề bắt đầu."""
    r, ctx, _ = du_an
    run = r.invoke("chat.orchestrate", {"intent": {"intent": "unknown"}, "grounded": {}}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


# ---------- nối dữ liệu giữa các nút: `${nX.field}` (DEV-121)


def test_tham_chieu_doc_dung_gia_tri_long_nhau():
    """Đường đọc phải đi được vào trong: một `patch` hay một `plan` là object nhiều tầng, và
    tham số nút sau thường là MỘT TRƯỜNG của nó chứ không phải cả cục."""
    goc = {"plan": {"steps": [{"id": "s1", "cap": "code.generate_module"},
                              {"id": "s2", "cap": "code.review"}]}}
    assert doc_duong(goc, "plan.steps[0].id") == "s1"
    assert doc_duong(goc, "plan.steps[*].id") == ["s1", "s2"]
    assert doc_duong(goc, "plan.steps[*].cap") == ["code.generate_module", "code.review"]


def test_duong_doc_hong_NOI_RO_chang_nao_chu_khong_tra_None():
    """`None` đi tiếp xuống năng lực rồi hỏng ở đó — cách chỗ sai vài nút, dưới một thông báo nói
    về chuyện khác. Đây là đúng hình dạng của một lỗi im lặng."""
    with pytest.raises(KeyError, match="khong_co"):
        doc_duong({"plan": {}}, "plan.khong_co.id")
    with pytest.raises(KeyError, match=r"\[3\]"):
        doc_duong({"a": [1, 2]}, "a[3]")


def test_tham_chieu_duoc_giai_bang_ket_qua_nut_truoc():
    args = {"patch": "${n7.patch}", "ghi_chu": "giữ nguyên",
            "gom": ["${n7.cites}", "hằng"]}
    ra = giai_tham_chieu(args, {"n7": {"patch": {"diff": "..."}, "cites": ["f_1"]}})
    assert ra == {"patch": {"diff": "..."}, "ghi_chu": "giữ nguyên",
                  "gom": [["f_1"], "hằng"]}


def test_tham_chieu_toi_nut_CHAY_SAU_bi_bat_luc_LAP_KE_HOACH():
    """Ba phép kiểm tham chiếu đều làm được lúc lập, nên phải làm lúc lập: hỏng ở phút thứ ba của
    một lượt chạy đã ghi vào store và đã tiêu tiền gọi mô hình là quá muộn."""
    c = _c({"id": "n1", "cap": "kg.build", "args": {}},
           {"id": "n2", "cap": "kg.neighborhood", "args": {"node": "${n3.x}"}, "when": "n1"},
           {"id": "n3", "cap": "kg.conflicts", "args": {}, "when": "n2"})
    with pytest.raises(EideError) as e:
        kiem(c, get_registry())
    assert e.value.code == "E5002" and "chạy SAU" in str(e.value)


def test_tham_chieu_toi_DAU_RA_KHONG_KHAI_bi_bat():
    """`output_schema` là chỗ duy nhất nói được một năng lực sinh ra cái gì. Trỏ vào một tên nó
    không khai là một lỗi đánh máy sẽ hỏng lúc chạy — bắt được từ lúc lập thì bắt."""
    c = _c({"id": "n1", "cap": "kg.conflicts", "args": {}},
           {"id": "n2", "cap": "kg.neighborhood",
            "args": {"node": "${n1.khong_he_co}"}, "when": "n1"})
    with pytest.raises(EideError) as e:
        kiem(c, get_registry())
    assert e.value.code == "E5002" and "không khai đầu ra" in str(e.value)


def test_tham_chieu_vao_CHINH_NO_bi_bat():
    c = _c({"id": "n1", "cap": "kg.neighborhood", "args": {"node": "${n1.x}"}})
    with pytest.raises(EideError) as e:
        kiem(c, get_registry())
    assert e.value.code == "E5002" and "trỏ vào chính nó" in str(e.value)


def test_THIEU_tham_so_KHONG_phai_loi_chuoi_ma_la_cau_hoi_cho_nguoi():
    """Ranh giới của DEV-121, và là lý do nó tồn tại.

    Một tham số SAI KIỂU là chuỗi hỏng — mô hình lập kế hoạch viết sai. Một tham số THIẾU là
    chuỗi chưa đủ dữ kiện: `sim.run` cần `scenario`, `target.flash` cần `target`, và không nút
    nào sinh ra chúng vì chúng đến từ NGƯỜI. Trước 17/09/2026 cả hai cùng là E5002, nên một câu
    hỏi đáng lẽ hỏi người lại giết cả chuỗi ngay lúc lập — kể cả phần đầu đã đủ dữ kiện để chạy.
    """
    c = _c({"id": "n1", "cap": "kg.neighborhood", "args": {}})
    thieu = kiem(c, get_registry())          # KHÔNG ném
    assert thieu == [{"id": "n1", "cap": "kg.neighborhood", "thieu": ["node"]}]


def test_SAI_KIEU_van_la_E5002_chu_khong_thanh_cau_hoi():
    """Ranh giới phải cắt đúng chỗ: nới lỏng phép kiểm thiếu tham số mà nới cả sai kiểu thì
    DPS-09 §4.4 mất phép kiểm quan trọng nhất của nó."""
    with pytest.raises(EideError) as e:
        kiem(_c({"id": "n1", "cap": "kg.neighborhood", "args": {"node": 123}}), get_registry())
    assert e.value.code == "E5002" and "input_schema" in str(e.value)


def test_noi_dau_ra_CHI_noi_khi_spec_KHAI_dung_ten_ay():
    """Chỉ nối khi `output_schema` của một nút trước khai đúng cái tên nút này đòi.

    Bảng ánh xạ kiểu `req.classify.reqset` → `req.ground_hw.reqset_ids` đúng với mắt người đọc,
    nhưng nó là tri thức KHÔNG có trong tài liệu nào của kho — viết vào mã là tự nghĩ ra hành vi.
    Chỗ ấy để trống và thành câu hỏi cho người.
    """
    reg = get_registry()
    nut = [Nut(id="n1", cap="req.elicit"),
           Nut(id="n2", cap="req.classify", when="n1"),
           Nut(id="n3", cap="req.ground_hw", when="n2")]
    _noi_dau_ra(nut, reg)
    assert nut[1].args["raw"] == "${n1.raw}", "req.elicit KHAI `raw`, req.classify ĐÒI `raw`"
    assert "reqset_ids" not in nut[2].args, "không nút nào khai `reqset_ids` — không được đoán"


def test_chuoi_CHAY_PHAN_LAM_DUOC_roi_moi_dung_hoi(du_an):
    """Đo trên đường đi chính của sản phẩm. Trước DEV-121 chuỗi `code.feature` trả về một bức
    tường E5002 và KHÔNG một nút nào chạy; nay phần đủ dữ kiện chạy, rồi dừng đúng chỗ thiếu."""
    from eide.caps.chat import _args_cho
    reg = get_registry()
    nut = [Nut(id=f"n{i + 1}", cap=c, when=f"n{i}" if i else None,
               args=_args_cho(c, {"intent": "code.feature"}, {}, "r_abc"))
           for i, c in enumerate(["chat.ground", "req.elicit", "req.classify", "req.ground_hw"])]
    _noi_dau_ra(nut, reg)
    thieu = kiem(Chain(nut), reg)
    assert [x["id"] for x in thieu] == ["n4"], "ba nút đầu đủ dữ kiện"
    assert set(thieu[0]["thieu"]) == {"reqset_ids", "passport"}
