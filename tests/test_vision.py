"""Đường ẢNH — CDS-12.2 EXTRACT-12…15, CDS-12.4 DIAGRAM-12; SDD §6 vai trò `cartographer`.

Hai lớp, hai câu hỏi khác nhau — cùng lối `test_sim.py` và `test_code.py`.

**Phần thuộc về EIDE thì kiểm bằng cổng giả.** Đọc tệp ảnh thành base64, chặn ảnh quá to, chuyển
xuống đúng nhà cung cấp, lọc cạnh treo, hạ `confidence`, ghi `Measurement` thay vì fact — sáu
thứ ấy là mã của ta và không cần một lượt gọi thật nào để kiểm.

**Phần thuộc về mô hình thì có một bài `llm` gọi THẬT.** Nó trả lời câu mà cổng giả không trả
lời được: *đường ảnh có thật sự đi tới hãng và về không*. Chạy bằng `make check-llm` với
`GEMINI_API_KEY`/`ANTHROPIC_API_KEY`; không có khoá thì tự bỏ qua.
"""
from __future__ import annotations

import base64
import json
import os
import struct
import zlib
from pathlib import Path

import pytest

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "ảnh"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


class _Cong:
    """Cổng giả GHI LẠI ảnh — một cổng nuốt mất ảnh thì mọi test đường ảnh đều xanh mà không
    bài nào chứng minh được ảnh đã tới nơi."""

    def __init__(self, data):
        self.data = data
        self.goi: list[dict] = []

    def run(self, role, user, schema, *, system_extra="", anh=None):
        self.goi.append({"role": role, "user": user, "anh": list(anh or [])})

        class R:
            pass
        r = R()
        r.data = self.data
        return r


def _png(root: Path, ten: str = "a.png", w: int = 8, h: int = 8) -> str:
    """PNG hợp lệ nhỏ nhất có thể — dựng bằng tay, không cần Pillow."""
    raw = b"".join(b"\x00" + b"\xff\xff\xff" * w for _ in range(h))

    def khoi(loai: bytes, d: bytes) -> bytes:
        return (struct.pack(">I", len(d)) + loai + d
                + struct.pack(">I", zlib.crc32(loai + d) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + khoi(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + khoi(b"IDAT", zlib.compress(raw))
           + khoi(b"IEND", b""))
    (root / ten).write_bytes(png)
    return ten


# ---------------------------------------------------------------- đọc ảnh


def test_doc_anh_thanh_base64_dung_media_type(du_an):
    from eide.caps.extract import _doc_anh

    _, _, root = du_an
    a = _doc_anh(root, _png(root))
    assert a["media_type"] == "image/png"
    assert base64.b64decode(a["data"])[:8] == b"\x89PNG\r\n\x1a\n"


def test_anh_qua_TO_thi_chan_TRUOC_khi_goi(du_an):
    """Hãng đặt trần ~5 MB cho ảnh inline. Gửi 20 MB đi chỉ để nhận lỗi HTTP là một lượt gọi
    tốn tiền mà không ai học được gì."""
    from eide.caps.extract import TRAN_ANH_MB, _doc_anh

    _, _, root = du_an
    (root / "to.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * (TRAN_ANH_MB * 1024 * 1024))
    with pytest.raises(EideError) as e:
        _doc_anh(root, "to.png")
    assert e.value.code == "E1000" and "vượt trần" in str(e.value)


def test_khong_phai_anh_thi_E1000(du_an):
    from eide.caps.extract import _doc_anh

    _, _, root = du_an
    (root / "x.txt").write_text("không phải ảnh", encoding="utf-8")
    with pytest.raises(EideError) as e:
        _doc_anh(root, "x.txt")
    assert e.value.code == "E1000"


# ---------------------------------------------------------------- Gateway


def test_vai_tro_KHONG_nhin_duoc_ma_nhan_anh_thi_NEM(du_an):
    """Một vai trò văn bản nhận ảnh sẽ hoặc bị hãng từ chối, hoặc TỆ HƠN: lặng lẽ bỏ qua ảnh
    rồi trả lời như thể đã nhìn. Cái thứ hai là lý do phép kiểm này ném chứ không cảnh báo."""
    from eide_core.gateway import Gateway, GatewayError

    g = Gateway()
    with pytest.raises(GatewayError) as e:
        g.run("writer", "xem hình", {"type": "object"},
              anh=[{"media_type": "image/png", "data": "AA=="}])
    assert "inputs: [image]" in str(e.value)


def test_cartographer_la_vai_tro_DUY_NHAT_khai_nhin_duoc():
    """Nếu có vai trò thứ hai khai `inputs: [image]`, bài này đỏ và người viết phải quyết định
    có thật sự muốn hai vai trò cùng tốn token thị giác không."""
    import yaml

    from eide_core.paths import spec_dir
    d = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    nhin = [t for t, c in (d.get("roles") or {}).items()
            if "image" in (c.get("inputs") or [])]
    assert nhin == ["cartographer"], nhin


# ---------------------------------------------------------------- EXTRACT-13 schematic


def test_schematic_luon_la_DE_XUAT_chua_duyet(du_an):
    """T2 + `method=vision_llm` + `status=normalized`. G-FACT-02 loại riêng `vision_llm` khỏi
    tự duyệt: một tên chân đọc nhầm từ ảnh trông y hệt một tên chân đọc đúng."""
    from eide.caps.extract import image_schematic

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({"nets": [{"name": "SDA", "pins": ["U1.PB7", "U2.4"],
                                            "confidence": 0.8}], "unreadable": []})
    kq = image_schematic({"image": _png(root)}, ctx)
    n = kq["nets"][0]
    assert n["method"] == "vision_llm" and n["status"] == "normalized"
    assert kq["proposal_id"].startswith("prop_")


def test_schematic_gui_ANH_xuong_cong(du_an):
    from eide.caps.extract import image_schematic

    _, ctx, root = du_an
    ctx.extra["gateway"] = c = _Cong({"nets": [{"name": "X", "pins": []}], "unreadable": []})
    image_schematic({"image": _png(root)}, ctx)
    assert c.goi[0]["role"] == "cartographer"
    assert len(c.goi[0]["anh"]) == 1 and c.goi[0]["anh"][0]["media_type"] == "image/png"


def test_schematic_khong_doc_duoc_gi_VA_khong_noi_gi_thi_E5002(du_an):
    """Một schematic mờ trả về 0 net rồi im lặng thì người đọc tưởng bo mạch không có net nào."""
    from eide.caps.extract import image_schematic

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({"nets": [], "unreadable": []})
    with pytest.raises(EideError) as e:
        image_schematic({"image": _png(root)}, ctx)
    assert e.value.code == "E5002"


def test_schematic_noi_ra_cho_KHONG_doc_duoc_thi_khong_nem(du_an):
    from eide.caps.extract import image_schematic

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({"nets": [], "unreadable": [{"reason": "vùng dưới bị mờ"}]})
    kq = image_schematic({"image": _png(root)}, ctx)
    assert kq["nets"] == [] and kq["unreadable"][0]["reason"] == "vùng dưới bị mờ"


# ---------------------------------------------------------------- EXTRACT-15 scope


def test_scope_tao_MEASUREMENT_chu_khong_tao_fact(du_an):
    """Ranh giới quan trọng nhất của nhóm. Một giá trị đọc từ ảnh màn hình dao động ký là một
    QUAN SÁT — đúng cho lần đo ấy, trên board ấy. Thành fact thì `code.constant_guard` sẽ cho
    phép mã trích dẫn nó như thể datasheet nói thế."""
    from eide.caps.extract import image_scope

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({"values": [{"name": "Vpp", "value": 3.3, "unit": "V"}],
                                  "scales": {"volt_per_div": "1V"}})
    kq = image_scope({"image": _png(root), "kind": "oscilloscope"}, ctx)
    assert kq["measurement"]["kind"] == "custom" and kq["measurement"]["confidence"] == 0.3

    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT count(*) FROM measurement").fetchone()[0] == 1
        assert c.execute("SELECT count(*) FROM fact").fetchone()[0] == 0, "KHÔNG được thành fact"


# ---------------------------------------------------------------- DIAGRAM-12 from_image


def test_from_image_sinh_ma_bang_MA_nen_luon_phan_tich_duoc(du_an):
    """Mô hình trả `{nodes, edges}` — cấu trúc nó khó sai — còn cú pháp Mermaid thì ta dựng."""
    from eide.caps.diagram import from_image

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({
        "nodes": [{"id": "a", "label": "Cảm biến"}, {"id": "b", "label": "MCU"}],
        "edges": [{"from": "a", "to": "b", "label": "I2C"}], "confidence": 0.9})
    kq = from_image({"image": _png(root)}, ctx)
    src = kq["diagram"]["src"]
    assert src.startswith("flowchart LR") and "-->|I2C|" in src
    assert kq["confidence"] == 0.9 and kq["diagram"]["needs_review"] is False


def test_from_image_canh_TREO_bi_bo_va_HA_diem_tin(du_an):
    """Cạnh trỏ tới một nút không tồn tại là dấu hiệu rõ nhất của một lượt đọc hỏng — bỏ nó và
    hạ điểm, chứ không im lặng sửa."""
    from eide.caps.diagram import NGUONG_TIN, from_image

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({
        "nodes": [{"id": "a", "label": "A"}],
        "edges": [{"from": "a", "to": "khong_co"}], "confidence": 0.95})
    kq = from_image({"image": _png(root)}, ctx)
    assert kq["diagram"]["dangling_edges"] and kq["confidence"] < NGUONG_TIN
    assert kq["diagram"]["needs_review"] is True


def test_from_image_diem_tin_THAP_thi_luoc_do_vao_trang_thai_cho_duyet(du_an):
    from eide.caps.diagram import from_image

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({"nodes": [{"id": "a", "label": "A"}], "edges": [],
                                  "confidence": 0.3})
    did = from_image({"image": _png(root)}, ctx)["diagram"]["id"]
    with store.open_store(store.store_path(root)) as c:
        (stale,) = c.execute("SELECT stale FROM diagram WHERE id=?", (did,)).fetchone()
    assert stale == 1


def test_from_image_dot_cung_phan_tich_duoc(du_an):
    from eide.caps.diagram import from_image

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({"nodes": [{"id": "a", "label": 'có "nháy"'}],
                                  "edges": [], "confidence": 0.9})
    src = from_image({"image": _png(root), "target_lang": "dot"}, ctx)["diagram"]["src"]
    assert src.startswith("digraph G {") and src.rstrip().endswith("}")


# ---------------------------------------------------------------- gọi THẬT


@pytest.mark.llm
@pytest.mark.skipif(not (os.environ.get("GEMINI_API_KEY") or os.environ.get("ANTHROPIC_API_KEY")),
                    reason="cần GEMINI_API_KEY hoặc ANTHROPIC_API_KEY")
def test_duong_anh_di_toi_HANG_va_ve(du_an):
    """Câu hỏi mà cổng giả không trả lời được: **đường ảnh có thật sự đi tới hãng và về không.**

    Cùng lối `sim.*` và `code.build`: một đường mã chưa lần nào chạy thật là một đường mã chưa
    ai biết có đúng không, bất kể bao nhiêu test giả lập xanh. Ở đây thứ chỉ lộ khi gọi thật là
    hình dạng payload — `inlineData` của Gemini và `source.base64` của Claude khác nhau, và một
    bên sai thì hãng trả 400 chứ không trả lời sai.

    Ảnh dựng tại chỗ: một hình vuông TRẮNG 64×64. Không khẳng định mô hình nhìn thấy GÌ — một
    ảnh trắng thì không có gì để thấy — chỉ khẳng định lượt gọi đi và về đúng schema.
    """
    from eide.caps.diagram import from_image

    _, ctx, root = du_an
    _png(root, "trang.png", 64, 64)
    kq = from_image({"image": "trang.png"}, ctx)
    assert "confidence" in kq and 0.0 <= kq["confidence"] <= 1.0
    assert kq["diagram"]["lang"] == "mermaid"
    assert kq["diagram"]["src"].startswith("flowchart LR")
    # Ảnh trắng: mô hình trung thực sẽ chấm điểm tin THẤP. Đây là chỗ duy nhất bài này nói về
    # chất lượng câu trả lời, và nó nói rất nhẹ — một mô hình chấm 0,9 cho một ảnh trắng là một
    # mô hình đang bịa, nhưng đó là chuyện của `make check-llm`, không phải của cổng CI.
    print(f"   điểm tin cho ảnh trắng: {kq['confidence']}")


# ---------------------------------------------------------------- EXTRACT-12 ocr


def test_ocr_tru_confidence_0_1(du_an, monkeypatch):
    """Bước 1 của EXTRACT-12: "confidence −0,1". Chữ đọc từ ảnh luôn kém chắc hơn chữ đọc từ
    PDF có lớp text, và trừ ở đây là chỗ duy nhất phép trừ ấy không bị quên."""
    from eide.caps.extract import ocr

    _, ctx, root = du_an
    monkeypatch.setattr("eide_core.tools.which", lambda t: None)   # ép đường vision
    ctx.extra["gateway"] = _Cong({"text_blocks": [{"text": "STM32F411", "confidence": 0.9}]})
    b = ocr({"file": _png(root)}, ctx)["text_blocks"][0]
    assert b["confidence"] == 0.8 and b["method"] == "vision_llm"


def test_ocr_uu_tien_TESSERACT_de_khong_gui_anh_ra_ngoai(du_an, monkeypatch, tmp_path):
    """OCR cục bộ không tốn token và KHÔNG GỬI ẢNH RA NGOÀI — một trang datasheet scan là tài
    liệu có thể đang dưới NDA."""
    import stat

    from eide.caps.extract import ocr

    _, ctx, root = du_an
    b = tmp_path / "bin"
    b.mkdir()
    (b / "tesseract").write_text(
        '#!/bin/sh\nprintf "level\\tleft\\ttop\\twidth\\theight\\tconf\\ttext\\n'
        '5\\t10\\t20\\t30\\t40\\t95\\tSTM32\\n"\n', encoding="utf-8")
    (b / "tesseract").chmod((b / "tesseract").stat().st_mode | stat.S_IEXEC)
    monkeypatch.setenv("PATH", f"{b}{os.pathsep}{os.environ['PATH']}")
    ctx.extra["gateway"] = c = _Cong({"text_blocks": []})

    kq = ocr({"file": _png(root)}, ctx)["text_blocks"]
    assert kq[0]["text"] == "STM32" and kq[0]["method"] == "parser"
    assert kq[0]["confidence"] == 0.85, "0,95 − 0,1"
    assert c.goi == [], "có tesseract thì KHÔNG gọi mô hình"


# ---------------------------------------------------------------- EXTRACT-14 image_board


def test_image_board_doi_chieu_voi_HO_CHIEU_da_co(du_an):
    """Nhãn trên chip thật thường bị cắt. Trùng hộ chiếu trong dự án thì tin hơn nhiều: người
    dùng đã trích datasheet của đúng con chip ấy."""
    from eide.caps.extract import image_board

    _, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO passport (id,kind,header,created_at) VALUES (?,?,?,?)",
                  ("st.stm32f411ce@1.0.0", "chip", json.dumps({}), "2026-09-12T00:00:00Z"))
        c.commit()
    ctx.extra["gateway"] = _Cong({"parts": [
        {"label": "STM32F411", "mpn_guess": "STM32F411CE", "confidence": 0.7},
        {"label": "lạ hoắc", "mpn_guess": "XYZ999"}]})

    ds = image_board({"image": _png(root)}, ctx)["parts"]
    assert ds[0]["matched_passport"] == "st.stm32f411ce@1.0.0"
    assert ds[1]["matched_passport"] is None


def test_image_board_khong_doc_duoc_gi_thi_E5002(du_an):
    from eide.caps.extract import image_board

    _, ctx, root = du_an
    ctx.extra["gateway"] = _Cong({"parts": []})
    with pytest.raises(EideError) as e:
        image_board({"image": _png(root)}, ctx)
    assert e.value.code == "E5002"


def test_ca_nam_nang_luc_thi_giac_da_gan_hien_thuc():
    from eide.cli import main  # noqa: F401
    from eide_core.registry import get_registry

    reg = get_registry()
    for cid in ("extract.ocr", "extract.image_schematic", "extract.image_board",
                "extract.image_scope", "diagram.from_image"):
        assert reg.get(cid).implemented, cid
