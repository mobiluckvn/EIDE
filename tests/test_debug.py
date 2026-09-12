"""Nhóm debug.* (khối F2, mốc M3) — CDS-12.4 DEBUG-01…06; DDD-14 §2 DebugSession.

Hai loại test, trả lời hai câu khác nhau — cùng lối `test_sim.py`.

**Thống kê log thì ĐO THẬT.** `debug.log_stats` tính bằng mã, nên nó là chỗ duy nhất trong nhóm
mà một con số có thể sai lặng lẽ: mẫu gộp nhầm, khoảng lặng bỏ sót, mức log đếm trùng. Test
dựng log thật rồi khẳng định từng con số.

**Hai năng lực gọi mô hình thì thay Gateway bằng một cổng giả.** Thứ thuộc về EIDE ở đó là:
ghép ngữ cảnh từ bốn nguồn, LỌC id bịa ra khỏi `supports`, xếp hạng theo p rồi tới giá thí
nghiệm, và lưu phiên. Bốn thứ ấy kiểm được mà không tốn token — và một cổng giả trả về đúng thứ
ta muốn kiểm thì kiểm được cả trường hợp mô hình trả id không tồn tại, điều mô hình thật không
chịu làm theo yêu cầu.
"""
from __future__ import annotations

import json
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
    res = r.invoke("project.create", {"text": "gỡ lỗi I2C"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


class _CongGia:
    """Gateway giả — trả đúng `data` đã dựng sẵn, ghi lại prompt để test soi ngữ cảnh."""

    def __init__(self, data):
        self.data = data
        self.prompts: list[str] = []

    def run(self, role, user, schema, **kw):
        self.prompts.append(user)

        class R:
            pass
        r = R()
        r.data = self.data
        return r


def _log(root: Path, ten: str, dong: list[str]) -> str:
    f = root / ten
    f.write_text("\n".join(dong) + "\n", encoding="utf-8")
    return ten


# ---------------------------------------------------------------- DEBUG-01 log_stats


def test_mau_gop_theo_hinh_dang_chu_khong_theo_tung_dong(du_an):
    """Không gộp số thì `top_patterns` là danh sách các dòng khác nhau đúng một chữ số."""
    from eide.caps.debug import log_stats

    _, ctx, root = du_an
    ten = _log(root, "a.log", [f"[{i}.000] INFO i2c write 0x{i:02x} ok" for i in range(1, 21)])
    st = log_stats({"file": ten}, ctx)["stats"]

    assert st["lines"] == 20
    assert len(st["top_patterns"]) == 1, st["top_patterns"]
    assert st["top_patterns"][0]["count"] == 20
    assert "#" in st["top_patterns"][0]["pattern"]


def test_dem_muc_log_moi_dong_MOT_lan(du_an):
    """`WARNING` và `WARN` là một mức, và một dòng chứa cả `INFO` lẫn `ERROR` chỉ đếm một lần."""
    from eide.caps.debug import log_stats

    _, ctx, root = du_an
    ten = _log(root, "b.log", ["INFO a", "WARNING b", "WARN c", "ERROR d", "ERROR e",
                               "INFO nhắc lại ERROR trước đó"])
    muc = log_stats({"file": ten}, ctx)["stats"]["levels"]
    assert muc == {"ERROR": 2, "INFO": 2, "WARN": 2}, muc


def test_khoang_lang_do_theo_TRUNG_VI_chu_khong_trung_binh(du_an):
    """Bất biến của DEBUG-01.

    Log này có 20 dòng cách nhau 0,1 s và MỘT khoảng lặng 30 s. Trung bình các khoảng cách bị
    chính khoảng lặng ấy kéo lên ~1,5 s, nên ngưỡng theo trung bình (×5 = 7,5 s) vẫn bắt được —
    nhưng thêm một khoảng lặng thứ hai thì trung bình lên tới mức che mất cả hai. Trung vị
    (0,1 s) không bị kéo, nên ngưỡng giữ nguyên 0,5 s dù có bao nhiêu khoảng lặng.
    """
    from eide.caps.debug import log_stats

    _, ctx, root = du_an
    t, dong = 0.0, []
    for i in range(20):
        dong.append(f"[{t:.3f}] INFO tick {i}")
        t += 30.0 if i in (9, 14) else 0.1
    ten = _log(root, "c.log", dong)

    gaps = log_stats({"file": ten}, ctx)["stats"]["gaps"]
    assert len(gaps) == 2, gaps
    assert all(g["gap_s"] > 29 for g in gaps), gaps
    # Số DÒNG hai đầu, để người đọc mở đúng chỗ — không chỉ có mốc thời gian.
    assert gaps[0]["after_line"] == 10 and gaps[0]["before_line"] == 11, gaps[0]


def test_log_khong_co_moc_thi_noi_khong_biet_chu_khong_doan(du_an):
    from eide.caps.debug import log_stats

    _, ctx, root = du_an
    ten = _log(root, "d.log", ["ERROR khong co moc", "ERROR cung the"])
    st = log_stats({"file": ten}, ctx)["stats"]
    assert st["time_span"] is None and st["gaps"] == []


def test_range_thu_hep_vung_doc(du_an):
    from eide.caps.debug import log_stats

    _, ctx, root = du_an
    ten = _log(root, "e.log", [f"INFO dòng {i}" for i in range(1, 101)])
    st = log_stats({"file": ten, "range": {"start": 10, "end": 19}}, ctx)["stats"]
    assert st["lines"] == 10 and st["range"] == {"start": 10, "end": 19}


def test_thieu_tep_log_thi_E4004(du_an):
    from eide.caps.debug import log_stats

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        log_stats({"file": "khong-co.log"}, ctx)
    assert e.value.code == "E4004"


# ---------------------------------------------------------------- DEBUG-03 hypothesize


def _tool_report(root: Path, tid: str, passed: bool = False) -> str:
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO tool_report (id, tool, passed, metrics, at)"
                  " VALUES (?,?,?,?,?)",
                  (tid, "sim", int(passed), json.dumps({"engine": "qemu"}), "2026-09-12T00:00:00Z"))
        c.commit()
    return tid


def test_chung_cu_rong_thi_E5002_va_KHONG_goi_mo_hinh(du_an):
    """Hỏi "vì sao hỏng" mà không đưa dữ kiện nào thì thứ nhận lại chỉ có thể là danh sách
    nguyên nhân phổ biến của Internet — nghe hợp lý, không liên quan gì tới con chip này."""
    from eide.caps.debug import hypothesize

    _, ctx, _ = du_an
    cong = _CongGia({"summary": "x", "hypotheses": []})
    ctx.extra["gateway"] = cong
    with pytest.raises(EideError) as e:
        hypothesize({"evidence_ids": []}, ctx)
    assert e.value.code == "E5002"
    assert cong.prompts == [], "không được gọi mô hình khi chưa có dữ kiện"


def test_id_chung_cu_BIA_bi_loc_khoi_supports(du_an):
    """Bất biến: một giả thuyết tựa trên chứng cứ không tồn tại thì không bác được, nên nó sống
    mãi. Mô hình bịa id trông rất giống thật là chuyện thường."""
    from eide.caps.debug import hypothesize

    _, ctx, root = du_an
    _tool_report(root, "tr_that00000001")
    ctx.extra["gateway"] = _CongGia({
        "summary": "I2C NACK",
        "hypotheses": [{"text": "bus quá nhanh", "p": 0.7,
                        "supports": ["tr_that00000001", "tr_bia000000bia"]}]})

    d = hypothesize({"evidence_ids": ["tr_that00000001"]}, ctx)["diagnosis"]
    assert d["hypotheses"][0]["supports"] == ["tr_that00000001"]


def test_xep_theo_p_roi_toi_thi_nghiem_RE_NHAT(du_an):
    """Hợp đồng đòi "thí nghiệm rẻ nhất". Hai giả thuyết cùng p thì cái kiểm bằng một lệnh đọc
    thanh ghi phải đứng trên cái phải hàn lại board."""
    from eide.caps.debug import hypothesize

    _, ctx, root = du_an
    _tool_report(root, "tr_that00000001")
    ctx.extra["gateway"] = _CongGia({"summary": "s", "hypotheses": [
        {"text": "đắt", "p": 0.5, "supports": [],
         "experiment": {"cap": "target.probe_read", "expect": "x", "cost": "đắt"}},
        {"text": "rẻ", "p": 0.5, "supports": [],
         "experiment": {"cap": "target.probe_read", "expect": "x", "cost": "rẻ"}},
        {"text": "p cao nhất", "p": 0.9, "supports": []},
    ]})
    gt = hypothesize({"evidence_ids": ["tr_that00000001"]}, ctx)["diagnosis"]["hypotheses"]
    assert [h["text"] for h in gt] == ["p cao nhất", "rẻ", "đắt"]


def test_khong_tra_duoc_chung_cu_nao_thi_E5002(du_an):
    from eide.caps.debug import hypothesize

    _, ctx, _ = du_an
    ctx.extra["gateway"] = _CongGia({"summary": "", "hypotheses": []})
    with pytest.raises(EideError) as e:
        hypothesize({"evidence_ids": ["tr_khongcoo0000"]}, ctx)
    assert e.value.code == "E5002"


# ---------------------------------------------------------------- DEBUG-05 save_session


def test_luu_ca_gia_thuyet_da_bi_BAC(du_an):
    """Cám dỗ là chỉ giữ cái đúng cho gọn. Nhưng lần sau gặp lại triệu chứng ấy, thứ đáng giá
    nhất là biết hướng nào đã đi và đã sai."""
    from eide.caps.debug import _doc_phien, save_session

    _, ctx, root = du_an
    chan = {"summary": "bus quá nhanh", "hypotheses": [{"text": "a", "p": 0.6},
                                                       {"text": "b", "p": 0.2}],
            "log_ref": "x.log", "range": {"start": 3, "end": 9}, "fact_ids": ["f_1"]}
    sid = save_session({"diagnosis": chan, "outcome": "refuted"}, ctx)["id"]

    p = _doc_phien(root, sid)
    assert p["outcome"] == "refuted"
    assert [h["text"] for h in p["hypotheses"]] == ["a", "b"]
    assert p["range_start"] == 3 and p["range_end"] == 9
    assert p["fact_ids"] == ["f_1"]


def test_phien_open_KHONG_ghi_so_loi(du_an):
    """Chưa biết đúng sai thì chưa có bài học; ghi sớm là dạy lần sau tránh một hướng chưa ai
    chứng minh là sai."""
    from eide.caps.debug import save_session

    _, ctx, root = du_an
    save_session({"diagnosis": {"summary": "chưa rõ"}, "outcome": "open"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT count(*) FROM error_ledger").fetchone()[0] == 0


def test_phien_dong_lai_thi_GHI_so_loi(du_an):
    from eide.caps.debug import save_session

    _, ctx, root = du_an
    save_session({"diagnosis": {"summary": "thiếu chờ ACK"}, "outcome": "confirmed"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute("SELECT kind, role, evidence FROM error_ledger").fetchall()
    assert len(rows) == 1
    assert rows[0][0] == "tool_fail" and rows[0][1] == "debugger"
    assert "thiếu chờ ACK" in rows[0][2]


def test_niem_store_con_khop_sau_khi_luu_phien(du_an):
    """Cùng lỗi im lặng số 1: ghi vào bảng có niêm mà không niêm lại thì cảnh báo "store bị sửa
    ngoài EIDE" luôn đỏ, và một cảnh báo luôn đỏ thì người ta tắt đi."""
    from eide.caps.debug import save_session

    _, ctx, root = du_an
    save_session({"diagnosis": {"summary": "x"}, "outcome": "open"}, ctx)
    ok, _ = store.verify_seal(store.store_path(root))
    assert ok


# ---------------------------------------------------------------- DEBUG-02 ask_at


def test_ask_at_neo_vao_RANGE_va_luu_phien_open(du_an):
    """tc DEBUG-02 nguyên văn: "Answer neo range"."""
    from eide.caps.debug import _doc_phien, ask_at

    _, ctx, root = du_an
    ten = _log(root, "f.log", [f"[{i}.0] INFO I2C1 tick {i}" for i in range(1, 51)])
    ctx.extra["gateway"] = cong = _CongGia({"answer": "Bus treo ở L12", "cites": ["L12", "f_9"]})

    kq = ask_at({"file": ten, "range": {"start": 10, "end": 14}, "question": "vì sao?"}, ctx)
    assert kq["diagnosis"]["range"] == {"start": 10, "end": 14}
    # Ngữ cảnh gửi đi chỉ chứa vùng đã chọn, không phải cả tệp.
    assert "tick 12" in cong.prompts[0] and "tick 40" not in cong.prompts[0]
    p = _doc_phien(root, kq["session_id"])
    assert p["outcome"] == "open", "chưa thí nghiệm nào xác nhận thì chưa phải kết luận"
    assert p["fact_ids"] == ["f_9"]


def test_ask_at_chan_range_lo_tay(du_an):
    """`range` 1..900000 không được kéo cả tệp vào mô hình."""
    from eide.caps.debug import TRAN_DONG, ask_at

    _, ctx, root = du_an
    ten = _log(root, "g.log", [f"INFO dòng {i}" for i in range(1, 1001)])
    ctx.extra["gateway"] = cong = _CongGia({"answer": "x", "cites": []})
    kq = ask_at({"file": ten, "range": {"start": 1, "end": 900000}, "question": "?"}, ctx)
    assert kq["diagnosis"]["range"]["end"] == TRAN_DONG
    assert "dòng 1000" not in cong.prompts[0]


# ---------------------------------------------------------------- DEBUG-04 experiment


def test_board_khong_co_trong_cau_hinh_thi_E4002(du_an):
    from eide.caps.debug import experiment

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        experiment({"experiment": {"cap": "target.probe_read", "expect": "x"},
                    "target": "board-la"}, ctx)
    assert e.value.code == "E4002" and e.value.data["remedy"] == "discover.scan"


def test_thi_nghiem_GHI_tren_board_chua_lab_thi_E3000_pending(du_an):
    """tc DEBUG-04: "không lab → pending". E3000 là POLICY_ASK, không phải lỗi — một thí nghiệm
    chưa chạy thì chưa có chứng cứ, và trả `evidence` rỗng kèm passed là dựng chứng cứ cho một
    việc chưa xảy ra."""
    from eide.caps.debug import experiment

    _, ctx, _ = du_an
    ctx.extra["gate"] = PolicyGate(config={"boards": {"b1": {"lab": False}}})
    with pytest.raises(EideError) as e:
        experiment({"experiment": {"cap": "target.flash", "expect": "ok"}, "target": "b1"}, ctx)
    assert e.value.code == "E3000" and e.value.data["risk"] == "R3"


def test_thi_nghiem_CHI_DOC_khong_doi_board_lab(du_an):
    """Lớp rủi ro theo năng lực BÊN TRONG: `probe_read` là R0. Gán cứng R3 cho mọi thí nghiệm
    thì một lệnh đọc thanh ghi cũng phải hỏi người."""
    from eide.caps.debug import experiment

    _, ctx, _ = du_an
    ctx.extra["gate"] = PolicyGate(config={"boards": {"b1": {"lab": False}}})
    with pytest.raises(EideError) as e:
        experiment({"experiment": {"cap": "target.probe_read", "expect": "x"}, "target": "b1"},
                   ctx)
    # Không phải E3000: nó đi tiếp và dừng ở chỗ `target.*` chưa hiện thực (cần board thật).
    assert e.value.code == "E4002" and "chưa hiện thực" in str(e.value)


# ---------------------------------------------------------------- DEBUG-06 propose_fix


@pytest.mark.parametrize(("cau", "loai"), [
    ("I2C NACK vì bus chạy 400 kHz quá nhanh cho dây dài", "constraint"),
    ("thiếu điện trở kéo lên trên SDA", "hardware"),
    ("quên chờ cờ ACK trước khi gửi byte kế", "code"),
])
def test_phan_loai_ba_huong_sua(du_an, cau, loai):
    """tc DEBUG-06 nguyên văn: "NACK → giảm bus 100 kHz là constraint".

    Cùng một triệu chứng dẫn tới ba việc khác hẳn nhau, và `constraint` là loại hay bị bỏ sót
    nhất vì nó không trông giống "một lỗi".
    """
    from eide.caps.debug import propose_fix, save_session

    _, ctx, _ = du_an
    sid = save_session({"diagnosis": {"summary": cau, "hypotheses": [{"text": cau, "p": 0.9}]},
                        "outcome": "confirmed"}, ctx)["id"]
    p = propose_fix({"session_id": sid}, ctx)["proposal"]
    assert p["kind"] == loai, p
    assert p["needs_confirmation"] is False


def test_constraint_rut_duoc_con_so_tu_chan_doan(du_an):
    from eide.caps.debug import propose_fix, save_session

    _, ctx, _ = du_an
    sid = save_session({"diagnosis": {"hypotheses": [{"text": "hạ bus xuống 100 kHz", "p": 1}]},
                        "outcome": "confirmed"}, ctx)["id"]
    p = propose_fix({"session_id": sid}, ctx)["proposal"]
    assert p["k6_change"]["value"] == 100
    assert p["k6_change"]["path"] == "bus_limits.i2c_khz"


def test_phien_chua_confirmed_van_tra_de_xuat_nhung_NOI_RO(du_an):
    """Từ chối thẳng thì người dùng mất luôn manh mối mà phiên ấy đã có."""
    from eide.caps.debug import propose_fix, save_session

    _, ctx, _ = du_an
    sid = save_session({"diagnosis": {"hypotheses": [{"text": "chưa rõ", "p": 0.3}]},
                        "outcome": "open"}, ctx)["id"]
    p = propose_fix({"session_id": sid}, ctx)["proposal"]
    assert p["needs_confirmation"] is True and p["outcome"] == "open"


def test_phien_khong_ton_tai_thi_noi_ra(du_an):
    from eide.caps.debug import propose_fix

    _, ctx, _ = du_an
    p = propose_fix({"session_id": "ds_khongcoo"}, ctx)["proposal"]
    assert p["kind"] == "unknown" and "Không tra được" in p["step_text"]


# ---------------------------------------------------------------- hợp đồng nhóm


def test_ca_sau_nang_luc_M3_da_gan_hien_thuc():
    from eide.cli import main  # noqa: F401 — nạp registry đầy đủ
    from eide_core.registry import get_registry

    reg = get_registry()
    xong = {c.spec.id for c in reg.list(ns="debug", implemented=True)}
    assert xong == {"debug.log_stats", "debug.ask_at", "debug.hypothesize",
                    "debug.experiment", "debug.save_session", "debug.propose_fix"}
