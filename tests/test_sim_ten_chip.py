"""[DEV-173] `sim.build_platform` phải tra hộ chiếu theo IRI THẬT, không ghép chuỗi.

`extract.atdf`/`extract.svd` sinh IRI chủ thể có TIỀN TỐ HÃNG (`chip:microchip.atmega328p`),
theo KAD-07 §4 — hai hãng có thể đặt trùng tên phần. Nhưng người dùng gõ `atmega328p`, và
`_iri_chip` ghép thẳng `chip:` vào đó cho ra một IRI không tồn tại.

Đo 22/09/2026 trên dự án `nhap-nhay-led-tren-atmega328p`, hộ chiếu đủ 287 fact vàng:
`sim.build_platform {chip: atmega328p}` báo *"Chưa có hộ chiếu vàng: không fact `memory_size`
nào đã duyệt"* — trong khi store có BA fact `memory_size` tầng vàng (FLASH 32768, RAM 2304,
EEPROM 1024). Cùng truy vấn ấy với `chip:microchip.atmega328p` trả 3 dòng.

Nguyên nhân là CÁI TÊN, không phải dữ liệu thiếu — và thông điệp lỗi đẩy người dùng đi chạy
`extract.svd` cho một hộ chiếu đã có sẵn. `project.set_target` thì quy chuẩn được, nên cùng
một cái tên sống ở năng lực này và chết ở năng lực kia.
"""
from __future__ import annotations

import hashlib
import json
import secrets

import pytest

from eide.caps.sim import _facts_nen_tang, iri_chip_trong_store
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

IRI = "chip:microchip.atmega328p"
BO_NHO = {"FLASH": 32768, "RAM": 2304, "EEPROM": 1024}


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "nhấp nháy LED"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


def _ho_chieu(root, pid="microchip.atmega328p@1.0.0", iri=IRI):
    """Hộ chiếu như `extract.atdf` để lại: id có hãng VÀ phiên bản, chủ thể fact chỉ có hãng."""
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO source (id,uri,sha256,kind,tier,license,domain)"
                  " VALUES (?,?,?,?,?,?,?)",
                  ("src_a", "file:///ATmega328P.atdf",
                   hashlib.sha256(pid.encode()).hexdigest(), "atdf", "gold", "vendor-doc",
                   "microchip.com"))
        c.execute("INSERT INTO passport (id, kind, header, created_at)"
                  " VALUES (?, 'chip', ?, '2026-09-22T00:00:00+00:00')",
                  (pid, json.dumps({"name": "ATmega328P"}, ensure_ascii=False)))
        for ten, gt in BO_NHO.items():
            c.execute(
                "INSERT INTO fact (id,subject,predicate,value,unit,source_id,method,tier,"
                "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                ("f_" + secrets.token_hex(8), f"{iri}/mem:{ten}", "memory_size",
                 json.dumps(gt), "byte", "src_a", "parser", "gold", 1.0, "normalized", "A"))
        c.commit()


def test_ten_nguoi_go_quy_chuan_ve_IRI_co_hang(du_an):
    """Phép đo trung tâm: trước bản vá hàm này không tồn tại và `_facts_nen_tang` ghép chuỗi."""
    _r, _ctx, root = du_an
    _ho_chieu(root)
    assert iri_chip_trong_store(root, "atmega328p") == IRI


def test_doc_duoc_ban_do_bo_nho(du_an):
    """Hệ quả thật: không quy chuẩn thì `memory` rỗng và `sim.build_platform` từ chối."""
    _r, _ctx, root = du_an
    _ho_chieu(root)
    assert _facts_nen_tang(root, "atmega328p")["memory"] == BO_NHO


def test_ten_DA_co_hang_thi_khong_doan_lai(du_an):
    """Người gọi đưa IRI đầy đủ là người gọi đã biết mình muốn gì — tra lại bảng có thể đổi nó
    sang một hãng khác cùng tên phần, đúng thứ tiền tố hãng sinh ra để ngăn."""
    _r, _ctx, root = du_an
    _ho_chieu(root)
    assert iri_chip_trong_store(root, "microchip.atmega328p") == IRI
    assert iri_chip_trong_store(root, IRI) == IRI


def test_khong_co_ho_chieu_thi_ghep_thang(du_an):
    """Không có gì để tra thì vẫn phải trả một IRI — người gọi cần nó để NÓI RA trong lỗi."""
    _r, _ctx, root = du_an
    assert iri_chip_trong_store(root, "stm32f411ce") == "chip:stm32f411ce"


def test_phien_ban_bi_cat_khoi_chu_the(du_an):
    """Hộ chiếu có phiên bản vì nó là một BẢN MÔ TẢ; fact thì nói về con chip. Giữ `@1.0.0`
    trong chủ thể sẽ không khớp fact nào."""
    _r, _ctx, root = du_an
    _ho_chieu(root)
    assert "@" not in iri_chip_trong_store(root, "atmega328p")


def test_thong_diep_loi_PHAN_BIET_hai_truong_hop(du_an):
    """Hai trường hợp, hai việc phải làm. Gộp chúng là gửi người dùng đi sai hướng — đúng lỗi
    đã xảy ra: hộ chiếu có 287 fact vàng, thông điệp bảo đi chạy `extract.svd`."""
    r, ctx, root = du_an
    # (a) có hộ chiếu, nhưng fact không dùng được (bạc, chưa duyệt)
    _ho_chieu(root)
    with store.open_store(store.store_path(root)) as c:
        c.execute("UPDATE fact SET tier='silver', status='normalized'")
        c.commit()
    run = r.invoke("sim.build_platform", {"chip": "atmega328p"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert "kg.review_facts" in run.error["candidates"], run.error
    assert IRI in run.error["exists"], run.error

    # (b) chip hoàn toàn lạ — không hộ chiếu nào
    run2 = r.invoke("sim.build_platform", {"chip": "atmega2560"}, ctx)
    assert run2.status == "failed"
    assert "extract.svd" in run2.error["candidates"] and not run2.error["exists"]


def test_dung_duoc_nen_tang_khi_du_fact(du_an):
    """Đường xanh, đo qua Router: hộ chiếu đủ → `sim.build_platform` xong, kèm trích dẫn."""
    r, ctx, root = du_an
    _ho_chieu(root)
    run = r.invoke("sim.build_platform", {"chip": "atmega328p"}, ctx)
    assert run.status == "done", run.error
    pho = run.result["coverage"]
    assert pho["memory"] == BO_NHO
    assert len(pho["cites"]) == 3, "mỗi con số phải truy được về fact sinh ra nó"
    assert (root / "sim" / "platform.json").is_file()


def test_khong_co_store_thi_khong_no(tmp_path):
    from pathlib import Path
    assert iri_chip_trong_store(Path(tmp_path), "atmega328p") == "chip:atmega328p"
