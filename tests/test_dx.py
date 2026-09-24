"""Tầng NLU xác định — N0, DX, hợp nhất slot. Spec: AAD-33 §2.1, §2.2, §2.5.2; AGD-32 Đ1.

Mọi bài kiểm ở đây chạy KHÔNG mạng, KHÔNG khoá API, KHÔNG store. Đó không phải tiện nghi mà là
chính điều cần canh: AAD-33 §1.1 đặt DX ở phía "xác định" của ranh giới, và một bài kiểm cần
mô hình để chạy sẽ không bao giờ chứng minh được rằng phép trích là tất định.

Tiêu chí nghiệm thu Đợt 1 (brief §6): *"cùng câu + cùng store → cùng DX (100 %)"* — xem
`test_tat_dinh_qua_nhieu_lan`.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import jsonschema
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from eide.nlu import extract, normalize  # noqa: E402
from eide.nlu.merge import (  # noqa: E402
    chay_duoc,
    de_ghi_so,
    duong_chay_duoc,
    hop_nhat,
    schema_cho_mo_hinh,
)
from eide_core.paths import spec_dir  # noqa: E402


def _schema(ten: str) -> dict:
    return json.loads((spec_dir() / "dialog" / ten).read_text(encoding="utf-8"))


# ──────────────────────────────────────────────────────────── N0

def test_nfc_va_dau_kieu_cu():
    """`hoà` và `hòa` phải ra cùng một chuỗi — nếu không, luật S0 bật theo bàn phím."""
    assert normalize("khoá đọc").normalized == normalize("khóa đọc").normalized
    assert normalize("thuỳ").normalized == "thùy"


def test_ban_khong_dau():
    u = normalize("Nạp firmware rồi kết nối lại")
    assert u.no_accent == "nap firmware roi ket noi lai"
    assert u.raw == "Nạp firmware rồi kết nối lại"          # bản gốc không bị đổi


def test_tach_menh_de_khong_cat_duong_dan():
    """Dấu chấm trong `/docs/ds_v1.pdf` KHÔNG được tách mệnh đề.

    Nếu tách, mọi thứ dựng trên mệnh đề (tách kênh ở Đ4, `product_text` của `req.elicit`) nhận
    một nửa đường dẫn làm một câu.
    """
    u = normalize("So /docs/ds_v1.pdf với /docs/ds_v2.pdf rồi cho tôi biết khác gì")
    assert [c["text"] for c in u.clauses] == [
        "So /docs/ds_v1.pdf với /docs/ds_v2.pdf", "cho tôi biết khác gì"]


def test_tach_menh_de_khong_cat_lien_tu_trong_danh_tu():
    """"TV và USB" là một liệt kê, không phải hai mệnh đề — hai vế phải đủ dài mới tách."""
    u = normalize("Bộ chuyển đổi cho TV và USB")
    assert len(u.clauses) == 1


def test_ngon_ngu():
    assert normalize("tạo dự án robot").lang == "vi"
    assert normalize("build the firmware for this board").lang == "en"


# ──────────────────────────────────────────────────────────── DX: đường dẫn

def test_hai_duong_dan_trong_mot_cau(tmp_path):
    """TC011 — `slots.path` chuỗi đơn mất một vế; `paths` mảng giữ cả hai."""
    a, b = tmp_path / "ds_v1.pdf", tmp_path / "ds_v2.pdf"
    a.write_text("a", encoding="utf-8")
    b.write_text("b", encoding="utf-8")
    dx = extract(f"so {a} với {b}", root=tmp_path)
    assert [p["value"] for p in dx.paths] == [str(a), str(b)]
    assert all(p["exists"] for p in dx.paths)
    assert dx.duong_chay_duoc() == [str(a), str(b)]


def test_duong_dan_khong_ton_tai_duoc_GIU_voi_exists_false():
    """TC016/TC023 — không xoá, không đoán: giữ lại để S3 hỏi một câu CÓ NỘI DUNG."""
    dx = extract("rà soát mã trong /Users/khong/co/that/firmware")
    assert [p["value"] for p in dx.paths] == ["/Users/khong/co/that/firmware"]
    assert dx.paths[0]["exists"] is False
    assert dx.duong_chay_duoc() == []                       # không chạy nút trên tệp không có
    assert dx.duong_de_hoi() == ["/Users/khong/co/that/firmware"]


def test_duong_dan_tuong_doi_trong_du_an(tmp_path):
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "app.c").write_text("int main(){}", encoding="utf-8")
    dx = extract("xem src/app.c", root=tmp_path)
    assert dx.duong_chay_duoc() == ["src/app.c"]
    assert dx.paths[0]["in_project"] is True


def test_ten_tep_tran_theo_duoi_biet(tmp_path):
    (tmp_path / "dem_xung.c").write_text("//", encoding="utf-8")
    dx = extract("Sửa tệp dem_xung.c rồi biên dịch lại", root=tmp_path)
    assert dx.duong_chay_duoc() == ["dem_xung.c"]
    assert dx.paths[0]["source"] == "ten_tep"


def test_khong_nhan_so_phien_ban_lam_ten_tep():
    """`v1.2` không phải một tệp — chỉ đuôi trong `DUOI_BIET` được nhận từ một tên trần."""
    assert extract("nâng hộ chiếu lên v1.2").paths == []


def test_dinh_kem_dung_truoc_va_mang_origin_dx(tmp_path):
    t = tmp_path / "board.zip"
    t.write_bytes(b"PK\x03\x04")
    dx = extract("đây là bộ tài liệu board", root=tmp_path, attachments=[str(t)])
    assert dx.paths[0]["source"] == "dinh_kem"
    assert dx.paths[0]["exists"] is True


# ──────────────────────────────────────────────────────────── DX: chip

@pytest.mark.parametrize(("cau", "ma"), [
    ("viết firmware cho STM32F103", "STM32F103"),
    ("dùng ATmega328P ở 16MHz", "ATmega328P"),
    ("nạp cho ESP32-C3", "ESP32-C3"),
    ("board RP2040 của tôi", "RP2040"),
])
def test_ma_chip_trong_cau(cau, ma):
    assert extract(cau).ma_chip() == [ma]


def test_bi_danh_thanh_ma_chip():
    """AAD-33 §2.2: Uno → ATmega328P, Blue Pill → STM32F103C8T6."""
    assert extract("nạp lên con Arduino Uno").ma_chip() == ["ATmega328P"]
    d = extract("blue pill của tôi không kết nối")
    assert d.ma_chip() == ["STM32F103C8T6"] and d.chips[0]["alias_of"] == "blue pill"


def test_isa_tu_manifest_va_null_khi_thieu():
    """`isa=null` là câu trả lời ĐÚNG khi kho chưa có manifest — TC018 (STM32F103 là armv7-m)."""
    assert extract("dùng ATmega328P").chips[0]["isa"] == "avr8"
    assert extract("dùng STM32F103").chips[0]["isa"] is None


def test_khong_bia_chip_tu_url_hay_duong_dan():
    """Chuỗi đã là một URL/đường dẫn thì không được mang thêm nghĩa "mã chip"."""
    assert extract("tải https://st.com/ds/stm32f103c8.pdf").chips == []
    assert extract("xem /opt/stm32f411/build.log").chips == []


# ──────────────────────────────────────────────────────────── DX: số, URL, mã, nháy

def test_so_co_don_vi_quy_ve_si():
    ds = {n["unit"]: n for n in extract("cấp 5V, 500mA, flash 32KB, xung 16MHz").numbers}
    assert ds["V"]["si"] == 5.0
    assert ds["mA"]["si"] == 0.5
    assert ds["KB"]["si"] == 32000.0
    assert ds["MHz"]["si"] == 16000000.0


def test_dai_gia_tri_thanh_mot_muc():
    n = extract("chạy bằng pin 3,0–4,2 V").numbers
    assert len(n) == 1 and n[0]["min"] == 3.0 and n[0]["max"] == 4.2
    assert n[0]["value"] is None and n[0]["si_unit"] == "V"


def test_dung_luong_pin_ve_coulomb():
    """2000 mAh = 7200 C. AAD-33 §2.2 ghi ví dụ `si: 7.2` — lệch 1000 lần, xem [DEV-233]."""
    n = extract("pin 2000mAh").numbers[0]
    assert n["si"] == 7200.0 and n["si_unit"] == "C"


def test_url_va_nhan_nha_san_xuat():
    u = extract("lấy ở https://www.st.com/resource/ds.pdf").urls[0]
    assert u["domain"] == "st.com" and u["manufacturer"] is True and u["kind"] == "pdf"
    assert extract("xem https://blog.ai-random.xyz/x").urls[0]["manufacturer"] is False


def test_ma_hien_vat():
    ids = {x["value"]: x["kind"] for x in extract("làm lại run-0042, xem REQ-017 và TC043").ids}
    assert ids == {"run-0042": "run", "REQ-017": "req", "TC043": "testcase"}


def test_chuoi_trong_nhay_la_du_lieu():
    """TC017 — `'void main'` là DỮ LIỆU, giữ nguyên chữ, không diễn giải thành ý định."""
    assert extract("thay 'void main' bằng int main").quoted == ["void main"]
    assert extract('ví dụ về lệnh "rm -rf /" trong tài liệu').quoted == ["rm -rf /"]


def test_back_ref():
    assert extract("làm lại").back_refs == ["lam_lai"]
    assert extract("tiếp tục").back_refs == ["tiep_tuc"]
    assert extract("làm lại phần giao tiếp I2C thôi").back_refs == []   # yêu cầu MỚI


# ──────────────────────────────────────────────────────────── lược đồ và tất định

def test_dau_ra_hop_luoc_do(tmp_path):
    u = normalize("so /a.pdf với b.pdf cho blue pill 3,0–4,2 V, xem https://st.com/x.pdf, "
                  "làm lại run-0042, thay 'void main'")
    jsonschema.validate(u.to_dict(), _schema("utterance.schema.json"))
    jsonschema.validate(extract(u, root=tmp_path).to_dict(), _schema("dx.schema.json"))


def test_tat_dinh_qua_nhieu_lan(tmp_path):
    """Tiêu chí brief §6: cùng câu + cùng store → cùng DX, 100 % qua 5 lần."""
    cau = "so /docs/a.pdf với /docs/b.pdf cho STM32F103 ở 3,3 V"
    ra = [json.dumps(extract(cau, root=tmp_path).to_dict(), sort_keys=True) for _ in range(5)]
    assert len(set(ra)) == 1


def test_bo_dau_giong_request_ops():
    """Hai lớp có hai hàm bỏ dấu; phép biến đổi phải giống nhau từng ký tự."""
    from eide.nlu.normalize import bo_dau
    from eide_core.request_ops import _bo_dau
    for s in ("Xoá toàn bộ Flash", "ĐỪNG nạp", "khoá đọc RDP mức 2", "Điện lưới 220 V"):
        assert bo_dau(s) == _bo_dau(s)


# ──────────────────────────────────────────────────────────── hợp nhất slot

def test_dx_thang_mo_hinh(tmp_path):
    """Bất biến §2.2: mô hình KHÔNG được ghi đè slot do DX điền."""
    t = tmp_path / "that.pdf"
    t.write_text("x", encoding="utf-8")
    dx = extract(f"đọc {t}", root=tmp_path)
    it = hop_nhat({"intent": "view.ask", "slots": {"paths": ["/mo/hinh/bia.pdf"]}}, dx)
    assert it["slots"]["paths"] == [str(t)]
    assert it["origins"]["paths"] == "dx"


def test_slot_mo_hinh_khong_duoc_dung_de_chay():
    """Đường dẫn do mô hình điền chỉ để ĐIỀN SẴN CÂU HỎI, không để chạy nút."""
    it = hop_nhat({"intent": "view.ask", "slots": {"paths": ["/mo/hinh/bia.pdf"]}}, None)
    assert it["origins"]["paths"] == "model"
    assert chay_duoc(it, "paths") == []
    assert "path" not in it["slots"]                        # không sinh khoá số ít từ nguồn lạ


def test_khoa_so_it_sinh_tu_mang_cho_hop_dong_cu(tmp_path):
    """213 năng lực khai `path`/`chip` số ít — khoá ấy được SINH từ mảng, chỉ từ nguồn tin."""
    t = tmp_path / "a.pdf"
    t.write_text("x", encoding="utf-8")
    it = hop_nhat({"intent": "view.ask", "slots": {}},
                  extract(f"đọc {t} cho ATmega328P", root=tmp_path))
    assert it["slots"]["path"] == str(t) and it["slots"]["chip"] == "ATmega328P"
    assert it["origins"]["path"] == "dx"


def test_thu_tu_uu_tien_day_du(tmp_path):
    """DX > câu trả lời người (S3) > mô hình > fill_defaults."""
    it = hop_nhat({"intent": "sim.run", "slots": {"level": "mo_hinh"}}, None,
                  tra_loi={"level": "nguoi"}, mac_dinh={"level": "mac_dinh", "board": "uno"})
    assert it["slots"]["level"] == "nguoi" and it["origins"]["level"] == "user"
    assert it["slots"]["board"] == "uno" and it["origins"]["board"] == "default"


def test_duong_chay_duoc_bo_tep_khong_ton_tai(tmp_path):
    """Câu nêu đường dẫn mà không tệp nào có thật → [] để nút HỎI, không để nó chạy rồi E2000."""
    it = hop_nhat({"intent": "view.ask", "slots": {}},
                  extract("đọc /khong/co/that.pdf", root=tmp_path))
    assert duong_chay_duoc(it) == []


def test_duong_lui_cho_ben_goi_cu():
    """Ý định không có `dx` lẫn `origins` (CLI, test cũ) vẫn trích được từ câu gốc — [DEV-208]."""
    assert duong_chay_duoc({"intent": "view.ask", "slots": {}},
                           "đọc /docs/rm.md") == ["/docs/rm.md"]


def test_schema_cho_mo_hinh_bo_origins():
    """Mô hình không được tự khai nguồn của slot — đó là kết luận của phép hợp nhất."""
    s = schema_cho_mo_hinh(_schema("intent.schema.json"))
    assert "origins" not in s["properties"]
    assert "origins" in _schema("intent.schema.json")["properties"]     # bản gốc không bị sửa


def test_luoc_do_intent_v2_khong_con_slot_chuoi_don():
    """Điểm khoá của Đ1: `paths` là mảng, `path`/`chip` chuỗi đơn không còn trong lược đồ."""
    sl = _schema("intent.schema.json")["properties"]["slots"]["properties"]
    assert sl["paths"]["type"] == "array" and sl["chips"]["type"] == "array"
    assert "path" not in sl and "chip" not in sl


def test_de_ghi_so_co_origin_tung_slot():
    """Tiêu chí brief §6: sổ cái ghi `s1.intent` KÈM origin từng slot."""
    d = de_ghi_so(hop_nhat({"intent": "view.ask", "slots": {"question": "x"}}, None))
    assert d["origins"] == {"question": "model"} and "slots" in d


# ──────────────────────────────────────────────────────────── đường sống (daemon)

def test_duong_song_chay_dx_truoc_mo_hinh(tmp_path):
    """DX phải chạy TRƯỚC `chat.parse_intent` trong `_chat_send`, và kết quả vào sổ cái.

    Đây là canary của cả Đ1: nếu ai đó dời lời gọi DX xuống sau mô hình, bản ghi `s1.merge` vẫn
    có nhưng `origins.paths` sẽ thành `model` — và 11 ca "đường dẫn bịa" quay lại mà không bài
    kiểm nào đỏ.
    """
    from eide.daemon.rpc import Daemon
    from eide.nlu.merge import duong_chay_duoc
    from eide_core.gateway import EchoPort, Gateway

    that = tmp_path / "rm.md"
    that.write_text("# reference manual", encoding="utf-8")
    d = Daemon(project=tmp_path)
    # Mô hình TRẢ VỀ một đường dẫn khác hẳn thứ người gõ — đúng hành vi đo được 23/09/2026.
    echo = EchoPort([{"intent": "view.ask", "confidence": 0.9, "is_big": False,
                      "slots": {"paths": ["/Users/bia/dat/ra.pdf"], "question": "bit nào bật DMA"}}])
    d.ctx.extra["gateway"] = Gateway(ledger=d.ledger, ports={"gemini": echo, "claude": echo})

    d._chat_send({"text": f"Đọc {that} rồi cho tôi biết bit nào bật DMA cho SPI2 TX",
                  "attachments": []})

    ghi = [x["data"] for x in d.ledger.records()
           if x["kind"] == "intent" and (x["data"] or {}).get("pha") == "s1.merge"]
    assert ghi, "không có bản ghi s1.merge trong sổ cái"
    assert ghi[0]["origins"]["paths"] == "dx"                # DX thắng mô hình
    assert ghi[0]["slots"]["paths"] == [str(that)]
    assert ghi[0]["dx"]["paths"][0]["exists"] is True
    it = {"slots": ghi[0]["slots"], "origins": ghi[0]["origins"], "dx": ghi[0]["dx"]}
    assert duong_chay_duoc(it) == [str(that)]               # đường dẫn bịa không đi vào nút nào
