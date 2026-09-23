"""Hai bất biến của đợt 1 — [DEV-200].

**BB2 — mọi bảo đảm phải ĐẾN ĐƯỢC.** Một năng lực rủi ro cao mà không đường nào dẫn tới thì
cổng của nó là trang trí. Đo 23/09/2026: 6 trên 7 năng lực R3/R4 không nằm trong một mẫu chuỗi
nào, trong đó có `target.erase_fuse` (R4/T3) — năng lực dựng riêng cho thao tác không đảo
ngược.

**BB3 — an toàn không được nằm sau một phép đoán.** Quy tắc G-OPS-02 đã có, đã đúng, và chưa
một lần nào chạy trong sản phẩm: chuỗi `op` chỉ xuất hiện trong `tests/`. Người dùng gõ "ghi
option bytes bật khoá đọc RDP mức 2" thì việc ấy rơi vào `target.flash` (R3) và cổng R3 duyệt
đúng theo luật của nó.

Hai bài kiểm này tồn tại để cả hai lỗ ấy không mở lại được trong im lặng.
"""

from __future__ import annotations

import json

import pytest

from eide_core.paths import spec_dir
from eide_core.registry import get_registry
from eide_core.request_ops import mo_ta_hau_qua, thao_tac_trong_cau

RULES = spec_dir() / "policy" / "rules.yaml"


# ───────────────────────────────────────────────────────── BB3 — nhận ra thao tác trong câu

@pytest.mark.parametrize("van,cho", [
    ("Xoá toàn bộ flash của chip", "erase_all"),
    ("xóa toàn bộ flash đi", "erase_all"),          # dấu viết kiểu khác vẫn phải bắt được
    ("mass erase cái chip này", "erase_all"),
    ("Ghi option bytes bật khoá đọc RDP mức 2", "option_bytes"),
    ("bật RDP level 2 cho tôi", "readout_protect"),
    ("đốt fuse bit cho ATmega328P", "fuse"),
])
def test_cau_goi_ten_thao_tac_khong_dao_nguoc_thi_phai_nhan_ra(van, cho):
    assert cho in thao_tac_trong_cau(van, RULES), f"không nhận ra `{cho}` trong: {van}"


@pytest.mark.parametrize("van", [
    "Nạp firmware vào mạch qua ST-Link",
    "Viết firmware nhấp nháy LED cho ATmega328P rồi biên dịch",
    "Đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART",
    "Xoá tính năng cũ trong tệp main.c",          # "xoá" nhưng KHÔNG phải xoá flash
    "Khoá dự án này lại giúp tôi",                # "khoá" nhưng KHÔNG phải khoá đọc chip
])
def test_cau_THUONG_thi_khong_duoc_chan(van):
    """Chặn nhầm một câu vô hại đắt hơn vẻ ngoài của nó.

    Một cảnh báo an toàn bật sai vài lần là một cảnh báo người ta bấm qua mà không đọc — đúng
    bài học đã đo được ở [DEV-198] với luật tên gần giống (40/52 dự án bị hỏi).
    """
    assert thao_tac_trong_cau(van, RULES) == [], f"chặn nhầm câu vô hại: {van}"


def test_tu_vung_thao_tac_doc_TU_DAC_TA_chu_khong_chep_tay():
    """Đổi `rules.yaml` thì bộ nhận diện phải đổi theo — không có bản sao thứ hai để lệch."""
    # Chỉ quy tắc KẾT TỘI TỰ THÂN THAO TÁC — điều kiện chỉ nói về `op`, không kèm hoàn cảnh.
    # `G-OPS-03` chặn `flash`/`experiment` CHỈ KHI board có cơ cấu chấp hành, nên nó không
    # thuộc về đây; gom nhầm nó vào là chặn mọi câu "nạp firmware".
    from eide_core.request_ops import _op_bi_chan
    trong_quy_tac = set(_op_bi_chan(str(RULES)))
    assert "erase_all" in trong_quy_tac and "readout_protect" in trong_quy_tac, \
        "G-OPS-02 đã đổi — bài kiểm này phải đổi theo, không được sửa cho xanh"
    # Một thao tác bị chặn mà bộ nhận diện không biết gọi bằng tiếng Việt là một lỗ.
    from eide_core.request_ops import DAU_HIEU
    assert trong_quy_tac <= set(DAU_HIEU), \
        f"quy tắc chặn nhưng không có dấu hiệu ngôn ngữ: {trong_quy_tac - set(DAU_HIEU)}"


def test_hau_qua_noi_bang_TIENG_NGUOI_chu_khong_bang_ten_thao_tac():
    """Một câu xác nhận chỉ có nghĩa nếu người đọc hiểu mình đang đồng ý với điều gì."""
    for op in ("erase_all", "fuse", "option_bytes", "readout_protect"):
        v = mo_ta_hau_qua(op).lower()
        assert v != op, f"`{op}`: mô tả hậu quả chỉ là tên máy"
        assert len(v) > 30, f"`{op}`: mô tả quá ngắn để người quyết định được"
        # Phải nói MẤT GÌ, không chỉ nói LÀM GÌ. ("fuse" vẫn được xuất hiện — đó là từ người
        # dùng cũng dùng; cái không được phép là dừng lại ở tên thao tác.)
        assert any(t in v for t in ("không", "mất", "vĩnh viễn", "hỏng")), \
            f"`{op}`: mô tả không nói người dùng mất gì"


# ───────────────────────────────────────────────────────── BB2 — bảo đảm phải đến được

#: Năng lực R3/R4 CỐ Ý không đi qua đường hội thoại, kèm lý do.
#:
#: Danh sách này là một lời khai, không phải một chỗ để giấu. Mỗi dòng phải trả lời được:
#: *nếu người dùng gõ câu yêu cầu việc này, họ nhận lại gì?*
KHONG_QUA_HOI_THOAI: dict[str, str] = {
    "target.erase_fuse":
        "Thao tác không đảo ngược. KHÔNG mở đường hội thoại; câu yêu cầu nó bị chặn ở tầng "
        "deterministic bởi `thao_tac_trong_cau` + G-OPS-02, và người dùng nhận một câu nói rõ "
        "hậu quả. Khi năng lực được hiện thực, mở một mẫu chuỗi riêng có cổng — không gộp vào "
        "mẫu nạp firmware.",
    "bench.run":
        "Chạy bộ tác vụ đo hiệu năng — việc của dòng lệnh và CI, không phải của một lượt trao "
        "đổi. Chưa hiện thực.",
}

#: Năng lực R3 ĐÁNG LẼ đến được nhưng chưa, vì mẫu chuỗi tương ứng chưa dựng.
#:
#: Đây là NỢ được ghi ra, không phải ngoại lệ được miễn. Khác `KHONG_QUA_HOI_THOAI` ở chỗ:
#: những mục kia là quyết định, những mục này là việc chưa làm xong — và mỗi mục phải nói rõ
#: đợt nào đóng nó, để danh sách này chỉ có thể ngắn đi.
CHO_MAU_CHUOI: dict[str, str] = {
    "target.reset":
        "Reset board — thao tác gỡ lỗi thường ngày, thuộc mẫu chuỗi phần cứng. Mở đường ở "
        "đợt 2 (BB1) cùng lúc với mẫu `sim.run` và `debug.ask`.",
    "target.probe_write":
        "Ghi bộ nhớ/RTT khi gỡ lỗi — thuộc mẫu chuỗi gỡ lỗi trên mạch thật. Đợt 2 (BB1).",
    "passport.verify_on_board":
        "Đối chiếu hộ chiếu chip với board thật — thuộc mẫu dò board Z-10. Đợt 2 (BB1).",
    "debug.experiment":
        "Chạy thí nghiệm gỡ lỗi theo chính sách. Năng lực ĐÃ hiện thực nhưng ý định "
        "`debug.ask` chưa có mẫu chuỗi nào, nên không đường nào gọi tới. Đợt 2 (BB1).",
}


def test_moi_nang_luc_rui_ro_cao_phai_den_duoc_hoac_duoc_khai_ro():
    """**Một cái cổng đúng trên một năng lực không ai gọi tới thì không bảo vệ được gì.**

    Đây là bất biến bắt được lỗ hổng `target.erase_fuse` một cách TỰ ĐỘNG, không cần ai nghĩ ra
    nó trước. Đo 23/09/2026 trước khi có bài kiểm này: 6 trên 7 năng lực R3/R4 không đường nào
    dẫn tới, trong đó có đúng năng lực mà POL-17 §2 dựng quy tắc G-OPS-02 để canh.

    Một năng lực nguy hiểm thêm vào sau này chỉ có hai chỗ đi: vào một mẫu chuỗi, hoặc vào
    `KHONG_QUA_HOI_THOAI` kèm lý do. Không có cửa thứ ba.
    """
    cds = json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))
    caps = cds["capabilities"] if isinstance(cds, dict) and "capabilities" in cds else cds
    ds = list(caps.values() if isinstance(caps, dict) else caps)
    cao = {x["name"] for x in ds if x.get("risk") in ("R3", "R4")}

    ch = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    mau = ch["chains"] if isinstance(ch, dict) and "chains" in ch else ch
    trong_mau: set[str] = set()
    for m in (mau.values() if isinstance(mau, dict) else mau):
        trong_mau |= {n.get("cap") for n in (m.get("nodes") or [])}
        trong_mau |= {b.split("(")[0].strip() for b in (m.get("buoc") or [])}

    lac = sorted(cao - trong_mau - set(KHONG_QUA_HOI_THOAI) - set(CHO_MAU_CHUOI))
    assert not lac, (
        "Năng lực rủi ro cao không đến được từ mẫu chuỗi nào và cũng không được khai là cố ý: "
        f"{lac}. Hoặc đưa vào một mẫu, hoặc khai vào KHONG_QUA_HOI_THOAI kèm lý do — "
        "cổng đặt trên một năng lực không ai gọi tới không bảo vệ được gì.")


def test_khai_KHONG_QUA_HOI_THOAI_phai_tro_toi_nang_luc_co_that():
    """Một lời khai trỏ vào năng lực không tồn tại là một lời khai che mất lỗ thật."""
    reg = get_registry()
    for ten in {**KHONG_QUA_HOI_THOAI, **CHO_MAU_CHUOI}:
        assert ten in reg, f"`{ten}` không có trong registry"
    for ten, ly in KHONG_QUA_HOI_THOAI.items():
        assert len(ly) > 60, f"`{ten}`: lý do quá sơ sài để rà lại"


def test_moi_mon_NO_phai_noi_ro_dot_nao_dong_no():
    """`CHO_MAU_CHUOI` là nợ ghi ra, không phải ngoại lệ được miễn.

    Không ràng buộc này thì danh sách ấy thành chỗ nhét mọi năng lực chưa nối xong, và bất
    biến BB2 mất hết tác dụng — nó sẽ xanh mãi trong khi lỗ vẫn nguyên.
    """
    for ten, ly in CHO_MAU_CHUOI.items():
        assert "đợt" in ly.lower() or "DEV-" in ly, \
            f"`{ten}`: món nợ không nói đợt nào đóng — xem lại hoặc chuyển sang quyết định"


# ──────────────────────────────────────────── BB3 đầu-cuối — G-OPS-02 thôi là quy tắc chết

@pytest.fixture
def daemon_du_an(tmp_path, workspace):
    """Daemon gắn vào một dự án thật — cùng khuôn `test_tro_nguoc.py`."""
    from eide.daemon.rpc import Daemon
    from eide_core import store
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "thao tac nguy hiem"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root))
    return Daemon(project=root), root


@pytest.mark.parametrize("van,op", [
    ("Xoá toàn bộ flash của chip", "erase_all"),
    ("Ghi option bytes bật khoá đọc RDP mức 2", "option_bytes"),
])
def test_chat_send_DUNG_LAI_truoc_thao_tac_khong_dao_nguoc(daemon_du_an, van, op):
    """Đây là bài kiểm đo đúng thứ TC035 và TC068 đo, và đo qua đúng đường ấy.

    Trước [DEV-200], hai câu này đi vào `chat.parse_intent` → ý định `target.flash` (R3) →
    `discover.auto_setup`, rồi tác tử hỏi người dùng mã bộ nạp. Ba tầng an toàn — lớp rủi ro
    R4, tier T3, quy tắc G-OPS-02 — đều đúng và đều bị đi vòng qua.

    Khẳng định ở đây cố ý KHÔNG kiểm câu chữ, mà kiểm ba tính chất: có dừng lại không, có nói
    hậu quả không, và có nói thật về việc làm được hay không.
    """
    d, _ = daemon_du_an
    ra = d.chat_send({"text": van})

    assert ra["state"] == "done"
    loi = ra["loi"]
    assert "KHÔNG ĐẢO NGƯỢC" in loi, "không cảnh báo tính không đảo ngược"
    assert "G-OPS-02" in loi, "không dẫn ra quy tắc để người tra lại được"
    assert "CHƯA được hiện thực" in loi, \
        "không nói thật rằng năng lực chưa có — hứa một việc không tồn tại"
    # KHÔNG được âm thầm đổi sang một việc KHÁC — đó chính là lỗi cũ (rơi vào `target.flash`
    # rồi đi hỏi mã bộ nạp). Kiểm bằng dấu hiệu của việc bị đổi, không bằng chữ "bộ nạp":
    # câu mô tả hậu quả của RDP có nhắc "kể cả bằng bộ nạp", và đó là một câu ĐÚNG.
    assert "discovery_id" not in loi, "vẫn đi hỏi tham số của một việc khác"
    assert "target.flash" not in loi, "vẫn định tuyến sang nạp firmware"


def test_lenh_nap_firmware_THUONG_van_di_tiep_nhu_cu(daemon_du_an, monkeypatch):
    """Lớp chặn mới không được chắn ngang đường đi thường ngày.

    Không có khẳng định này thì một phép chặn quá tay sẽ làm hỏng mọi lượt nạp firmware, và
    bài kiểm an toàn phía trên vẫn xanh — lỗi tệ nhất mà một lớp bảo vệ có thể gây ra.
    """
    from eide_core.request_ops import thao_tac_trong_cau as t
    assert t("Nạp firmware vào mạch qua ST-Link", RULES) == []
    assert t("Reset board rồi đọc log UART", RULES) == []


def test_lượt_bi_chan_duoc_GHI_SO(daemon_du_an):
    """Một thao tác nguy hiểm bị chặn mà không để lại dấu thì không rà lại được sau sự cố."""
    d, root = daemon_du_an
    d.chat_send({"text": "Xoá toàn bộ flash của chip"})
    dong = [x for x in (d.ledger.records() if d.ledger is not None else [])
            if x.get("kind") == "gate.decision" and (x.get("data") or {}).get("op")]
    assert dong, "không ghi sổ quyết định cổng cho lượt bị chặn"
    assert dong[-1]["data"]["op"] == "erase_all"
    assert dong[-1]["data"]["rule_id"] == "G-OPS-02"
    assert dong[-1]["data"]["decision"] == "ASK", "cổng phải HỎI, không được tự duyệt"


# ──────────────────────────────────────────── BB1 — bảng ý định → mẫu chuỗi phải TOÀN PHẦN

#: Ý định CỐ Ý không có mẫu chuỗi, kèm lý do. Hiện trống — và nên giữ trống.
Y_DINH_KHONG_MAU: dict[str, str] = {}


def test_moi_y_dinh_deu_co_mau_chuoi():
    """**Mọi giá trị của một bảng điều phối phải có người nhận.**

    Đo 23/09/2026 trước bài kiểm này: 19 ý định, 10 mẫu, phủ 12 giá trị. Bảy ý định rơi xuống
    planner — và planner phác chuỗi từ văn xuôi nên hoặc bắt đầu từ giữa quy trình, hoặc trả
    về chuỗi rỗng rồi lượt bị bác bỏ bằng E5002. Nặng nhất: `view.ask` là ý định của MỌI CÂU
    HỎI, nên **sản phẩm không trả lời được một câu hỏi nào**.

    Đây là lần thứ TƯ cùng một lớp lỗi được vá từng dòng: DEV-147, DEV-155, DEV-158, DEV-201.
    Ba lần trước đều sửa đúng thể hiện và để nguyên cái lớp. Bài kiểm này đóng lớp: một ý định
    thêm vào sau này không lọt qua được.
    """
    import re

    ints = json.loads((spec_dir() / "dialog" / "intent.schema.json").read_text(encoding="utf-8"))
    gia_tri = set(json.loads(re.findall(r'"enum"\s*:\s*(\[[^\]]*\])', json.dumps(ints))[0]))

    ch = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    ms = ch["chains"] if isinstance(ch, dict) and "chains" in ch else ch
    nhan: set[str] = set()
    for m in (ms.values() if isinstance(ms, dict) else ms):
        nhan |= set(m.get("trigger_intents") or [])

    thieu = sorted(gia_tri - nhan - set(Y_DINH_KHONG_MAU))
    assert not thieu, (
        f"Ý định không mẫu chuỗi nào nhận: {thieu}. Không mẫu thì rơi xuống planner, và một "
        "chuỗi ứng tác giao cho người dùng dưới dạng câu hỏi tham số khó hiểu hoặc mã lỗi. "
        "Hoặc thêm mẫu vào `docs/ho-so/nguon/dps.js`, hoặc khai vào Y_DINH_KHONG_MAU kèm lý do.")


def test_mau_chuoi_khong_tro_toi_nang_luc_khong_co_that():
    """Một mẫu trỏ tới năng lực không tồn tại là một mẫu sẽ rụng hết nút lúc chạy.

    `_tu_nodes` bỏ lặng lẽ mọi nút chưa hiện thực, nên một tên gõ sai không gây lỗi — nó chỉ
    làm chuỗi ngắn đi, và người dùng nhận một việc làm dở mà không ai báo.
    """
    reg = get_registry()
    ch = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    ms = ch["chains"] if isinstance(ch, dict) and "chains" in ch else ch
    la: list[str] = []
    for m in (ms.values() if isinstance(ms, dict) else ms):
        for n in (m.get("nodes") or []):
            if n.get("cap") and n["cap"] not in reg:
                la.append(f"{m.get('ten', '?')}/{n['id']}: {n['cap']}")
    assert not la, f"mẫu trỏ tới năng lực không có trong danh mục: {la}"


def test_moi_mau_moi_phai_chay_duoc_it_nhat_MOT_nut():
    """Mẫu mà mọi nút đều chưa hiện thực thì bằng không có mẫu — chuỗi rỗng, E5002 như cũ."""
    reg = get_registry()
    ch = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    ms = ch["chains"] if isinstance(ch, dict) and "chains" in ch else ch
    rong: list[str] = []
    for m in (ms.values() if isinstance(ms, dict) else ms):
        nut = [n.get("cap") for n in (m.get("nodes") or [])]
        if nut and not any(c in reg and reg.get(c).implemented for c in nut):
            rong.append(str(m.get("ten") or m.get("trigger_intents")))
    assert not rong, f"mẫu không có nút nào chạy được: {rong}"
