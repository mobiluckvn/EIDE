"""Danh sách trắng và niêm chữ ký — POL-17 §3. WI-257."""
from __future__ import annotations

import json

import pytest
import yaml

from eide_core import whitelist
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate, _Ns

NGUON_TIN = {"source": {"domain": "st.com", "license": "vendor-doc", "size_mb": 2,
                        "kind": "svd", "hash_match": True}}


@pytest.fixture
def cfg():
    return yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8"))


# ---- niêm


def test_bam_chi_phu_khoa_danh_sach_khong_phu_nguong(cfg):
    """Đổi ngưỡng KHÔNG được làm hỏng niêm, đổi danh sách thì phải.

    `policy.learn_thresholds` đề xuất chỉnh ngưỡng hằng tuần (POL-17 §6). Nếu ngưỡng nằm trong
    niêm thì tuần nào cũng phải ký lại danh sách trắng, và một thao tác ký lặp đi lặp lại là
    một thao tác người ta bấm cho xong mà không đọc.
    """
    goc = whitelist.bam(cfg)
    assert whitelist.bam({**cfg, "thresholds": {**cfg["thresholds"], "fact_silver_auto": 0.5}}) == goc
    assert whitelist.bam({**cfg, "autonomy": "A4"}) == goc
    assert whitelist.bam({**cfg, "trusted_sources": [*cfg["trusted_sources"], "ke-la.com"]}) != goc
    assert whitelist.bam({**cfg, "boards": {"b1": {"lab": True}}}) != goc


def test_ky_roi_kiem_thi_dat(tmp_path, cfg):
    sig = tmp_path / "policy.sig"
    assert whitelist.kiem(cfg, sig) == (False, "danh sách trắng chưa được ký (chạy `eide policy sign`)")
    n = whitelist.ky(cfg, sig, "Vũ Trí Công")
    assert whitelist.kiem(cfg, sig)[0] is True
    assert n.by == "Vũ Trí Công" and n.alg == "sha256"
    assert json.loads(sig.read_text(encoding="utf-8"))["hash"] == n.hash


def test_doi_danh_sach_sau_khi_ky_thi_niem_hong(tmp_path, cfg):
    sig = tmp_path / "policy.sig"
    whitelist.ky(cfg, sig, "Vũ Trí Công")
    dat, ly_do = whitelist.kiem({**cfg, "trusted_packages": [*cfg["trusted_packages"], "cua-sau"]}, sig)
    assert dat is False
    assert "băm không khớp" in ly_do and "Vũ Trí Công" in ly_do


def test_ky_phai_neu_ten_nguoi(tmp_path, cfg):
    with pytest.raises(EideError) as e:
        whitelist.ky(cfg, tmp_path / "p.sig", "   ")
    assert e.value.code == "E1000"


def test_niem_hong_la_loi_chu_khong_phai_coi_nhu_chua_ky(tmp_path, cfg):
    """Tệp niêm hỏng ≠ chưa ký. Nuốt lỗi thành "chưa ký" thì xóa nội dung .sig sẽ là cách êm ả
    để hạ một danh sách đã ký xuống trạng thái không ai để ý."""
    sig = tmp_path / "policy.sig"
    sig.write_text("{ đây không phải json", encoding="utf-8")
    with pytest.raises(EideError) as e:
        whitelist.kiem(cfg, sig)
    assert e.value.code == "E6000"


def test_niem_phai_khop_nhat_ky_chu_khong_chi_khop_chinh_no(tmp_path, cfg):
    """POL-17 §3 đòi ghi vào HAI nơi. Đây là lý do của yêu cầu ấy.

    Kẻ sửa danh sách rồi sửa luôn `.sig` cho khớp sẽ qua được phép so tệp-với-tệp. Nhật ký là
    chuỗi băm nối tiếp nên không sửa lén được, và bước đối chiếu này bắt đúng trường hợp đó.
    """
    sig, led = tmp_path / "policy.sig", Ledger(tmp_path / "ledger.jsonl")
    whitelist.ky(cfg, sig, "Vũ Trí Công", led)
    assert whitelist.kiem(cfg, sig, led)[0] is True

    # Kẻ giả mạo sửa danh sách RỒI sửa luôn `.sig` cho khớp — nhưng không đụng được vào nhật ký
    # (sửa một bản ghi là hỏng chuỗi băm từ đó về sau).
    doi = {**cfg, "trusted_sources": [*cfg["trusted_sources"], "ke-la.com"]}
    sig.write_text(json.dumps({"hash": whitelist.bam(doi), "by": "Vũ Trí Công",
                               "at": "2026-09-06T00:00:00+00:00",
                               "keys": list(whitelist.KHOA_NIEM), "alg": "sha256"}),
                   encoding="utf-8")
    assert whitelist.kiem(doi, sig)[0] is True, "so tệp-với-tệp thì đúng là bị lừa"

    dat, ly_do = whitelist.kiem(doi, sig, Ledger(tmp_path / "ledger.jsonl"))
    assert dat is False and "nhật ký" in ly_do
    assert led.verify()[0] is True, "chuỗi băm nhật ký vẫn nguyên vẹn"


def test_tom_tat_neu_ca_khoa_rong(cfg):
    """Người xác nhận phải thấy MỌI khóa nằm trong niêm. `boards` rỗng vẫn được niêm, nên giấu
    nó đi là để người ký tưởng thêm board sau này không cần ký lại."""
    t = whitelist.tom_tat(cfg)
    for k in whitelist.KHOA_NIEM:
        assert k in t, f"tóm tắt thiếu {k}"


# ---- PolicyGate hỏng an toàn


def test_chua_ky_thi_bo_han_danh_sach_chu_khong_nap_rong(tmp_path, cfg):
    """POL-17 §3: "PolicyGate từ chối nạp danh sách có băm không khớp chữ ký".

    Cả hai cách đều ra ASK, nên test này soi LÝ DO chứ không soi quyết định. Nạp danh sách rỗng
    làm `license in []` sai ⇒ G-OPS/G-SRC-05 bắt trước ⇒ decision_log ghi "License không rõ"
    trong khi license hợp lệ và thứ hỏng là chữ ký. Người duyệt đọc dòng đó rồi đi sửa nhầm chỗ.
    """
    g = PolicyGate(sig_path=tmp_path / "khong-co.sig")
    assert g.danh_sach_da_ky is False
    d = g.decide("G-SRC", NGUON_TIN, risk="R1")
    assert d.decision == "ASK"
    assert d.rule_id == "G-SRC-99", f"lý do sai chỗ: {d.rule_id} {d.reason}"

    rong = PolicyGate(config={"trusted_sources": [], "allowed_licenses": []},
                      sig_path=tmp_path / "khong-co.sig")
    assert rong.decide("G-SRC", NGUON_TIN, risk="R1").rule_id == "G-SRC-99"


def test_da_ky_thi_nap_va_duyet(cfg):
    """Bản cài kèm sẵn `defaults.sig`, nên out-of-box vẫn chạy được."""
    g = PolicyGate()
    assert g.danh_sach_da_ky is True, g.ly_do_chua_ky
    assert g.decide("G-SRC", NGUON_TIN, risk="R1").rule_id == "G-SRC-01"


def test_defaults_sig_di_kem_ban_cai_van_khop():
    """Sửa tay `defaults.yaml` mà quên ký lại thì test này đổ — đó là điều mong muốn."""
    cfg = PolicyGate().config
    dat, ly_do = whitelist.kiem(cfg, spec_dir() / "policy" / "defaults.sig")
    assert dat, f"{ly_do} — chạy: eide policy sign --by '<tên>'"


# ---- niêm cấp dự án


def _du_an(tmp_path, workspace, text="bộ đo độ ẩm ESP32"):
    from eide_core.router import Context, Router
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l0.jsonl"))
    res = r.invoke("project.create", {"text": text}, Context(project_dir=workspace)).result
    return workspace / res["project_id"]


def _gate_du_an(root):
    return PolicyGate(config=yaml.safe_load((root / ".eide" / "autonomy.yaml").read_text(encoding="utf-8")),
                      sig_path=root / ".eide" / "policy.sig")


def test_du_an_moi_ke_thua_niem_cua_ban_cai(tmp_path, workspace):
    """Danh sách của dự án mới giống hệt bản mặc định đã ký, nên bắt ký lại là bắt ký một thứ
    vừa ký — và một cơ chế bắt ký chuyện hiển nhiên là cơ chế người ta gõ cho xong."""
    root = _du_an(tmp_path, workspace)
    n = whitelist.doc_nien(root / ".eide" / "policy.sig")
    assert n is not None and "kế thừa" in n.by
    assert _gate_du_an(root).danh_sach_da_ky is True


def test_autonomy_yaml_cua_du_an_co_du_bon_khoa_duoc_niem(tmp_path, workspace):
    """Niêm phủ bốn khóa; tệp dự án phải nêu đủ cả bốn.

    `PolicyGate` hợp nhất `{**defaults, **autonomy}` nên thiếu khóa vẫn CHẠY ĐÚNG — thừa kế từ
    tệp mặc định. Nhưng lúc ký thì người đặt tên mình lên một tệp không nói hết chính sách đang
    có hiệu lực, và đó mới là chỗ hỏng.
    """
    a = yaml.safe_load(((_du_an(tmp_path, workspace)) / ".eide" / "autonomy.yaml").read_text(encoding="utf-8"))
    assert all(k in a for k in whitelist.KHOA_NIEM), [k for k in whitelist.KHOA_NIEM if k not in a]


def test_tu_them_nguon_tin_cay_ma_khong_ky_lai_thi_khong_co_tac_dung(tmp_path, workspace):
    """Đây là điều WI-257 mua được: danh sách trắng không còn sửa được bằng một lần sửa tệp."""
    root = _du_an(tmp_path, workspace)
    f = root / ".eide" / "autonomy.yaml"
    d = yaml.safe_load(f.read_text(encoding="utf-8"))
    d["trusted_sources"].append("nguon-la.example")
    f.write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")

    g = _gate_du_an(root)
    assert g.danh_sach_da_ky is False and "băm không khớp" in g.ly_do_chua_ky
    r = g.decide("G-SRC", {"source": {"domain": "nguon-la.example", "license": "MIT",
                                      "size_mb": 1, "kind": "svd", "hash_match": True}}, risk="R1")
    assert (r.decision, r.rule_id) == ("ASK", "G-SRC-99")


# ---- DEV-033: tên trần vắng mặt


def test_dac_trung_vang_mat_la_sai_du_viet_kieu_nao():
    """`_Ns` tự hứa "đặc trưng chưa biết ⇒ không khớp APPROVE" nhưng chỉ giữ lời ở nhánh thuộc
    tính; nhánh tên trần mang tính đúng mặc định của object."""
    assert bool(_Ns({}).chua_biet) is False
    assert bool(_Ns({})) is False, "tên trần vắng mặt vẫn phải là SAI"
    assert bool(_Ns({"co": 1})) is True


def test_G_OPS_04_khong_phai_quy_tac_chet():
    """`needs_sudo` mang tính đúng làm G-OPS-05 (ưu tiên 5, ASK) che G-OPS-04 (ưu tiên 10,
    APPROVE) trong MỌI lần cài — `trusted_packages` thành ra không duyệt được gì.

    Cùng họ với DEV-012: bảng quy tắc nói một đằng, động cơ làm một nẻo, và 45 tình huống §7
    vẫn xanh suốt vì không tình huống nào bỏ trống `needs_sudo`.
    """
    g = PolicyGate()
    d = g.decide("G-OPS", {"op": "install", "package": "openocd"}, risk="R2")
    assert (d.decision, d.rule_id) == ("APPROVE", "G-OPS-04")
    assert g.decide("G-OPS", {"op": "install", "package": "openocd", "needs_sudo": True},
                    risk="R2").rule_id == "G-OPS-05"
    assert g.decide("G-OPS", {"op": "install", "package": "kẻ-lạ"}, risk="R2").rule_id == "G-OPS-05"


# ---- schema POL-17 §4


def test_defaults_yaml_hop_le_theo_schema_POL17_muc4(cfg):
    """§4 đặt `additionalProperties: false`. Trước WI-257 không ai kiểm điều đó, nên một khóa gõ
    sai — hay khóa `lab_boards` mà §3 nhắc tới nhưng §4 không có (DEV-030) — sẽ im lặng bị bỏ
    qua và chính sách chạy khác điều người viết tưởng."""
    jsonschema = pytest.importorskip("jsonschema")
    s = json.loads((spec_dir() / "policy" / "autonomy.schema.json").read_text(encoding="utf-8"))
    loi = list(jsonschema.Draft202012Validator(s).iter_errors(cfg))
    assert not loi, [f"{list(e.path)}: {e.message}" for e in loi]


def test_lab_boards_cua_muc3_bi_schema_muc4_tu_choi(cfg):
    """Chốt DEV-030 để không ai "sửa" theo văn xuôi §3 nữa."""
    jsonschema = pytest.importorskip("jsonschema")
    s = json.loads((spec_dir() / "policy" / "autonomy.schema.json").read_text(encoding="utf-8"))
    v = jsonschema.Draft202012Validator(s)
    assert list(v.iter_errors({**cfg, "lab_boards": ["b1"]})), "§4 phải từ chối tên của §3"
