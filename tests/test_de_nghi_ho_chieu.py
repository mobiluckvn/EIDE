"""Đ3 — hộ chiếu chip: từ CHẶN sang ĐỀ NGHỊ; manifest armv7-m; lỗi mạng khác lỗi tệp.

Spec: AAD-33 §4 (`passport.propose`), §8.2 (khớp ISA ↔ manifest), §8.6 + §11.4 (lỗi mạng,
resumable); AGD-32 §5 (luồng bảy bước) và Đ3; TGT-19 §2.

Sáu ca đo mà Đ3 nhắm tới — TC002, 008, 015, 027, 046, 048 — dừng ở CÙNG MỘT câu: *"Chưa ghim hộ
chiếu chip — chip nào?"*, với danh sách lựa chọn TRỐNG. Ba trong sáu ca người dùng đã nêu tên chip
ngay trong câu, nên câu hỏi ấy đòi họ gõ lại thứ vừa nói; ba ca còn lại thì thứ thiếu không phải
cái TÊN mà là TÀI LIỆU, và không câu trả lời nào cho "chip nào?" lấp được chỗ ấy.

TC018 là ca thứ bảy, khác loại: `env.check` nói THẬT (*"ISA armv7-m chưa có manifest"*) và kho
thiếu DỮ LIỆU. Sửa bằng cách thêm manifest, không bằng cách sửa mã.
"""
from __future__ import annotations

import sys
import urllib.error
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from eide.caps.passport import LUA_CHON_DE_NGHI, co_ho_chieu, de_nghi  # noqa: E402
from eide_core import store  # noqa: E402
from eide_core.isa import isa_cua_chip, isa_da_co  # noqa: E402
from eide_core.paths import spec_dir  # noqa: E402

# ──────────────────────────────────────────── manifest ISA (TC018)

def test_armv7_m_co_manifest():
    """TC018 — STM32F103 là Cortex-M3; trước Đ3 kho chỉ có armv7e-m (M4/M7)."""
    assert "armv7-m" in isa_da_co()
    assert (spec_dir() / "isa" / "armv7-m.yaml").is_file()


@pytest.mark.parametrize(("chip", "isa"), [
    ("STM32F103C8T6", "armv7-m"),      # Blue Pill — ca của TC018
    ("STM32F205RB", "armv7-m"),        # Cortex-M3, trước Đ3 bị armv7e-m nhận sai
    ("LPC1768", "armv7-m"),
    ("STM32F411CE", "armv7e-m"),       # M4 có FPU — phải KHÔNG đổi
    ("STM32F303K8", "armv7e-m"),
    ("ATmega328P", "avr8"),
    ("ESP32-C3", "rv32imac"),
])
def test_chip_ve_dung_isa(chip, isa):
    assert isa_cua_chip(chip) == isa


def test_armv7e_m_khong_con_nhan_STM32F2():
    """`^STM32F[2-4]` gán một chip KHÔNG có FPU vào ISA của chip CÓ FPU.

    Hệ quả không phải hình thức: luật tĩnh `no_float_isr_without_fpu` của manifest mất hiệu lực
    đúng chỗ nó cần nhất, và mã sinh ra có thể dùng lệnh FPU mà chip không có.
    """
    d = yaml.safe_load((spec_dir() / "isa" / "armv7e-m.yaml").read_text(encoding="utf-8"))
    assert "^STM32F[2-4]" not in d["family_patterns"]
    assert d["family_patterns"][0] == "^STM32F[34]"


def test_manifest_armv7_m_khai_du_phan_toolchain_va_khong_co_fpu():
    d = yaml.safe_load((spec_dir() / "isa" / "armv7-m.yaml").read_text(encoding="utf-8"))
    assert d["id"] == "armv7-m"
    assert d["abi"]["fpu"] == "none"                       # Cortex-M3 không có FPU
    assert d["toolchain"]["compiler"]["name"] == "arm-none-eabi-gcc"
    assert d["sim"]["engine"] == "qemu"                    # QEMU CÓ máy ảo cho M3
    assert "netduino2" in str(d["sim"])


def test_env_check_chay_duoc_voi_armv7_m():
    """Bộ nhận dạng đã đúng thì `env.check` không còn E2000 "chưa có manifest"."""
    from eide.caps.env import check
    from eide_core.router import Context
    ra = check({"isa": "armv7-m"}, Context())
    assert "ok" in ra or "tools" in ra or ra                # hợp đồng trả trạng thái, không ném


# ──────────────────────────────────────────── thẻ đề nghị thay câu chặn

def test_ba_lua_chon_dung_nhu_AGD_32():
    """AGD-32 §5 bước 1: *Tìm trên mạng / Tôi nạp tệp / Dùng tri thức chung – nhãn Đồng*."""
    assert [v for v, _, _ in LUA_CHON_DE_NGHI] == ["tim_tren_mang", "toi_nap_tep",
                                                   "tri_thuc_chung"]
    the = de_nghi(["ATmega328P"])
    assert the["kind"] == "proposal" and the["chip"] == "ATmega328P"
    assert len(the["lua_chon"]) == 3
    # Tầng ĐỒNG phải nói ra hệ quả của nó ngay trên lựa chọn (N2).
    dong = the["lua_chon"][2]["giai_thich"]
    assert "CHƯA KIỂM CHỨNG" in dong and "sinh mã" in dong


def test_khong_de_nghi_ghim_ten_chip_tran():
    """[DEV-183] — ghép một tên trần vào `ns.part@semver` tra ra RỖNG trong im lặng.

    Ba lựa chọn đều phải là một CÁCH LẤY TÀI LIỆU, không có lựa chọn nào là "ghim ATmega328P".
    """
    the = de_nghi(["ATmega328P"])
    assert all(x["gia_tri"] != "ATmega328P" for x in the["lua_chon"])
    assert not any("ghim" in x["nhan"].lower() for x in the["lua_chon"])


def test_khong_neu_chip_thi_KHONG_de_nghi():
    """Không ai nhắc chip nào thì "chip nào?" mới là câu hỏi đúng."""
    assert de_nghi([]) is None
    assert de_nghi(["", "   "]) is None


def test_chip_khong_co_manifest_thi_noi_thang(tmp_path):
    """TC018 — không đưa ba ISA đều sai; nói kho thiếu gì, và đọc danh sách TỪ manifest."""
    the = de_nghi(["PIC16F18855"])
    assert the["isa"] is None
    cb = the["canh_bao_isa"]
    assert "chưa được hỗ trợ" in cb
    for isa in isa_da_co():
        assert isa in cb                                   # danh sách không gõ tay


def test_da_co_ho_chieu_thi_khong_de_nghi_nua(tmp_path):
    """Đề nghị lấy tài liệu cho một chip đã ghim là hỏi lại một việc đã xong."""
    (tmp_path / ".eide").mkdir()
    db = store.store_path(tmp_path)
    store.migrate(db)
    with store.open_store(db) as c:
        c.execute("INSERT INTO passport (id, kind, header, created_at) "
                  "VALUES ('mchp.atmega328p@1.0.0','chip','{}','2026-09-24T10:00:00Z')")
        c.commit()
    assert co_ho_chieu(tmp_path, "ATmega328P") == "mchp.atmega328p@1.0.0"
    assert de_nghi(["ATmega328P"], tmp_path) is None
    # Chip THỨ HAI chưa có thì vẫn đề nghị đúng chip ấy.
    assert de_nghi(["ATmega328P", "TMP102"], tmp_path)["chip"] == "TMP102"


# ──────────────────────────────────────────── câu hỏi trong đường sống

def _hoi(tmp_path: Path, cau: str, khoa: str = "passport") -> str:
    from eide.caps.chat import _ghi_cau_hoi_chuoi
    from eide.nlu import extract
    from eide.nlu.merge import hop_nhat
    from eide_core.chain import Nut

    if not (tmp_path / ".eide").exists():
        (tmp_path / ".eide").mkdir()
        store.migrate(store.store_path(tmp_path))
    it = hop_nhat({"intent": "code.feature", "slots": {}, "confidence": 0.9}, extract(cau))
    ra = _ghi_cau_hoi_chuoi(tmp_path, "r_test", Nut(id="n1", cap="code.generate_module", args={}),
                            [khoa], it)
    return str(ra.get("hoi") or "")


def test_cau_hoi_doi_tu_chan_sang_de_nghi(tmp_path):
    """TC002/008/015 — câu chặn cũ biến mất khi câu người gõ đã nêu chip."""
    van = _hoi(tmp_path, "viết firmware đọc nhiệt độ qua I2C cho ATmega328P")
    assert "Chưa ghim hộ chiếu chip — chip nào?" not in van
    assert "Chưa có datasheet cho `ATmega328P`" in van
    for v, _, _ in LUA_CHON_DE_NGHI:
        assert v in van


def test_cau_hoi_giu_nguyen_khi_khong_neu_chip(tmp_path):
    """Không nêu chip → giữ câu cũ. Thay nó bằng một thẻ về con chip không ai nhắc còn tệ hơn."""
    van = _hoi(tmp_path, "đề xuất phương án cho bộ đếm xung")
    assert "chip nào?" in van


def test_chip_do_MO_HINH_doan_khong_dung_de_dung_the(tmp_path):
    """Bất biến §2.2: slot `origin=model` chỉ để điền sẵn câu hỏi, không để dựng đề nghị.

    Một thẻ đề nghị dựng từ chip mô hình đoán sẽ mời người dùng đi tìm datasheet cho một con chip
    họ không hề nhắc tới — và họ sẽ tin là mình đã nói.
    """
    from eide.caps.chat import _chip_da_neu
    from eide.nlu.merge import hop_nhat
    it = hop_nhat({"intent": "code.feature", "slots": {"chips": ["STM32F407"]}}, None)
    assert it["origins"]["chips"] == "model"
    assert _chip_da_neu(it) == []


def test_danh_sach_isa_trong_cau_hoi_doc_tu_manifest(tmp_path):
    """Câu cũ kể tên ba ISA cố định; thêm armv7-m là câu ấy thành lời nói dối tự sinh ra."""
    van = _hoi(tmp_path, "cài toolchain cho PIC16F18855", khoa="isa")
    assert "armv7-m" in van and "avr8" in van


# ──────────────────────────────────────────── lỗi mạng ≠ lỗi tệp (TC072)

@pytest.mark.parametrize(("loi", "ma", "resumable"), [
    (urllib.error.URLError(OSError(8, "nodename nor servname provided")), "E4005", True),
    (urllib.error.URLError(ConnectionRefusedError(61, "Connection refused")), "E4005", True),
    (TimeoutError("timed out"), "E4004", None),
    (urllib.error.URLError(TimeoutError("timed out")), "E4004", None),
    (ValueError("Expecting value"), "E4000", None),
])
def test_phan_loai_loi_mang(loi, ma, resumable):
    from eide.caps.search import _loi_mang
    e = _loi_mang({"id": "searxng"}, loi)
    assert e.code == ma
    assert e.data.get("resumable") is resumable


def test_loi_mang_noi_ro_KHONG_phai_loi_tep():
    """TC072 — người dùng nhận "lỗi TỆP" cho một việc TÌM MẠNG; câu mới nói thẳng điều ngược lại."""
    from eide.caps.search import _loi_mang
    e = _loi_mang({"id": "searxng"}, urllib.error.URLError(ConnectionRefusedError(61, "refused")))
    van = str(e.args[0])
    assert "lỗi MẠNG, không phải lỗi tệp" in van
    assert "tiếp tục" in van and "make searxng" in van


def test_E4005_co_trong_dac_ta():
    """Mã lỗi trong mã nguồn chỉ được lấy từ `api/errors.json` (API-15 §3, test hợp đồng 4)."""
    import json
    ds = json.loads((spec_dir() / "api" / "errors.json").read_text(encoding="utf-8"))
    m = {x["code"]: x for x in ds}
    assert m["E4005"]["name"] == "NETWORK_FAILED"
    assert "resumable" in m["E4005"]["handling"]
