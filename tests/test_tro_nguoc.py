"""«làm lại» / «tiếp tục» — giải tham chiếu về lượt trước. [DEV-196]

## Vì sao bài kiểm này tồn tại

Chủ sản phẩm dùng app 23/09/2026: một việc hỏng, bảo *"làm lại"*, và tác tử **không biết làm
lại việc gì**. Ba lỗ chồng nhau — không trí nhớ hội thoại (M2 `turns` luôn rỗng), không lớp C6,
và bảng 19 ý định không có giá trị nào cho "làm lại".

Bài kiểm đi qua **daemon**, không gọi thẳng hàm trong: đường người dùng thật là `chat.send`, và
một bài kiểm gọi tắt sẽ xanh kể cả khi đường tắt không được nối vào `chat_send`.

Không lời gọi nào ở đây chạm mô hình: `la_cau_tro_nguoc` và `_tro_nguoc` đều xác định, và đó
chính là điểm — xem DEV-196 về lý do không để mô hình đoán tham chiếu.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from eide.daemon.rpc import Daemon, la_cau_tro_nguoc  # noqa: E402
from eide_core import store  # noqa: E402


@pytest.fixture
def du_an_rpc(tmp_path, workspace):
    """Daemon gắn vào một dự án THẬT — cùng khuôn `test_rpc.py`.

    Dựng lại ở đây thay vì đưa vào `conftest.py`: hai tệp dùng cùng một khuôn nhưng không cùng
    một nhu cầu, và một fixture dùng chung sẽ kéo cả hai theo mỗi lần một bên đổi.
    """
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "tro nguoc"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root))
    return Daemon(project=root), root


# ---------------------------------------------------------------- nhận câu


@pytest.mark.parametrize("van,mong", [
    ("làm lại", "lam_lai"),
    ("Làm lại!", "lam_lai"),
    ("lam lai di", "lam_lai"),
    ("chạy lại", "lam_lai"),
    ("thử lại", "lam_lai"),
    ("retry", "lam_lai"),
    ("tiếp tục", "tiep_tuc"),
    ("tiep tuc di", "tiep_tuc"),
    ("làm tiếp", "tiep_tuc"),
    ("continue", "tiep_tuc"),
])
def test_cau_TRO_NGUOC_nhan_duoc_ca_khi_go_khong_dau(van, mong):
    """Người gõ vội thì gõ không dấu, và lúc ấy là lúc cần nó chạy nhất."""
    assert la_cau_tro_nguoc(van) == mong


@pytest.mark.parametrize("van", [
    "làm lại phần giao tiếp I2C thôi",
    "tiếp tục theo dõi log rồi báo tôi",
    "chạy lại mô phỏng với kịch bản mới",
    "đừng làm lại nữa",
    "dừng",
    "",
])
def test_cau_DAI_la_yeu_cau_MOI_chu_khong_phai_lenh_tro_nguoc(van):
    """**Khớp TRỌN, không `in`.**

    "làm lại phần giao tiếp I2C thôi" là một yêu cầu MỚI có chữ "làm lại" trong đó. Bắt nó bằng
    `in` là biến một câu CỤ THỂ thành một lệnh mơ hồ — rồi chạy lại một việc khác hẳn việc người
    vừa mô tả. Cùng lập luận với `la_cau_dung` của [DEV-155].
    """
    assert la_cau_tro_nguoc(van) is None


# ---------------------------------------------------------------- giải tham chiếu


def _ghi_luot_chay(root: Path, run_id: str, state: str, text: str,
                   report: dict | None = None) -> None:
    """Dựng một lượt chạy trong store — đúng hình dạng `chat._ghi_run` ghi ra."""
    with store.open_store(store.store_path(root)) as c:
        c.execute(
            "INSERT INTO run (id, graph, state, working, report, started_at)"
            " VALUES (?,?,?,?,?,?)",
            (run_id, json.dumps({"nodes": []}), state,
             json.dumps({"nodes": [], "intent": {}, "text": text}, ensure_ascii=False),
             json.dumps(report or {}, ensure_ascii=False), "2026-09-23T00:00:00+00:00"))
        c.commit()


def test_KHONG_co_luot_do_thi_noi_thang_chu_khong_doan(du_an_rpc):
    """Đây là chỗ bản cũ im lặng rồi để mô hình bịa ra một việc.

    Không có gì để làm lại thì câu trả lời đúng là "không có gì để làm lại" — kèm cách đi tiếp.
    """
    d, _ = du_an_rpc
    r = d.chat_send({"text": "làm lại"})
    assert r["intent_id"] == "unknown"
    assert "không có lượt chạy nào đang dở" in r["loi"].lower()


def test_luot_HONG_thi_chay_lai_dung_CAU_GOC(du_an_rpc, monkeypatch):
    """Chạy lại CÂU GÕ GỐC, không dựng lại chuỗi cũ.

    Lượt mới phải đi qua `ground` + `fill_defaults` một lần nữa để thấy những gì đã đổi kể từ
    lần trước — kể cả câu trả lời người vừa cho ở tab Làm rõ.
    """
    d, root = du_an_rpc
    _ghi_luot_chay(root, "r_hong01", "failed", "đọc cảm biến BME280 qua I2C",
                   {"failed": [{"cap": "code.write", "ma": "E4001"}]})

    da_goi: list[str] = []

    def gia_lap(p):
        da_goi.append(p["text"])
        return {"intent_id": "code.feature", "state": "running", "run_id": "r_moi"}

    # Thay CHÍNH `chat_send` sau lần gọi đầu: đường trỏ ngược gọi lại nó với câu gốc, và đó là
    # thứ cần đo — không phải kết quả của mô hình.
    that = d.chat_send
    monkeypatch.setattr(d, "chat_send",
                        lambda p: gia_lap(p) if da_goi or "làm lại" not in p["text"]
                        else that(p))
    r = d.chat_send({"text": "làm lại"})

    assert da_goi == ["đọc cảm biến BME280 qua I2C"], f"chạy lại sai câu: {da_goi}"
    assert r["lam_lai_cua"] == "r_hong01"
    assert "code.write" in r["loi_dan"], "không nói lần trước hỏng ở đâu"


def test_luot_DANG_CHO_thi_noi_dang_cho_chu_khong_chay_lai(du_an_rpc):
    """**"làm lại" trên một lượt CHƯA HỎNG phải đổi hướng.**

    Chuỗi `asked` không hỏng — nó đang đợi người. Chạy lại từ đầu là vứt bỏ phần đã chạy đúng
    và hỏi lại y hệt câu cũ; thứ người dùng cần là biết mình phải trả lời gì.
    """
    d, root = du_an_rpc
    _ghi_luot_chay(root, "r_cho01", "asked", "dựng firmware nháy LED",
                   {"waiting": [{"cap": "env.check", "thieu": ["isa"]}]})
    r = d.chat_send({"text": "làm lại"})

    assert r["intent_id"] == "chat.resume"
    assert r["run_id"] == "r_cho01"
    assert "isa" in r["loi"], "không nói thiếu gì"
    assert "dựng firmware nháy LED" in r["loi"], "không nhắc lại việc gốc"


def test_luot_MOI_NHAT_thang__khong_phai_luot_hong_dau_tien(du_an_rpc):
    """Trỏ vào lượt GẦN NHẤT chưa xong, không phải lượt hỏng cũ nhất.

    "làm lại" nói về việc VỪA XẢY RA. Một lượt hỏng từ hôm kia đã được người bỏ qua từ lâu, và
    chạy lại nó là làm một việc không ai yêu cầu.
    """
    d, root = du_an_rpc
    _ghi_luot_chay(root, "r_cu", "failed", "việc CŨ")
    _ghi_luot_chay(root, "r_moi", "asked", "việc MỚI",
                   {"waiting": [{"cap": "env.check", "thieu": ["isa"]}]})
    r = d.chat_send({"text": "tiếp tục"})
    assert r["run_id"] == "r_moi", "trỏ nhầm vào lượt cũ"


# ---------------------------------------------------------------- báo cáo khởi động phiên


def test_MO_DU_AN_noi_ngay_viec_dang_do_va_cach_tiep(du_an_rpc):
    """MEM-11 §5 bước 5 — *"lần trước đã… còn chờ… tôi đề nghị…"*, đích ≤ 1 câu hỏi.

    Đề nghị phải là một câu **GÕ ĐƯỢC**. Người đọc "anh nên tiếp tục việc dở" vẫn phải tự nghĩ
    ra cách nói; "gõ: tiếp tục" thì không — và đó là khác biệt giữa 15 phút với 15 giây.
    """
    d, root = du_an_rpc
    _ghi_luot_chay(root, "r_do01", "asked", "nối LAN cho máy CNC",
                   {"waiting": [{"cap": "env.check", "thieu": ["isa"]}]})
    kq = d.router.invoke("project.open", {"project": str(root)}, d.ctx)
    assert kq.status == "done", kq.error

    tt = kq.result["summary"]["tiep_tuc"]
    van = "\n".join(tt["dong"])
    assert tt["run_id"] == "r_do01"
    assert tt["de_nghi"] == "tiếp tục"
    assert "isa" in van, f"không nói còn chờ gì — {van}"
    assert "nối LAN cho máy CNC" in van, f"không nhắc việc gốc — {van}"
    assert "tiếp tục" in van, f"không nêu câu gõ được — {van}"
    assert len(tt["dong"]) <= 10, "§5 giới hạn 10 dòng"


def test_DU_AN_SACH_thi_khong_bia_ra_viec_dang_do(du_an_rpc):
    """Không có việc dở thì báo cáo RỖNG — im còn hơn dựng một việc không có."""
    d, root = du_an_rpc
    kq = d.router.invoke("project.open", {"project": str(root)}, d.ctx)
    tt = kq.result["summary"]["tiep_tuc"]
    assert tt["run_id"] is None and tt["de_nghi"] is None
    assert not [x for x in tt["dong"] if "Việc dở" in x or "Còn chờ" in x]


# ---------------------------------------------------------------- trí nhớ hội thoại


def test_cau_NGUOI_GO_duoc_ghi_vao_M2_ke_ca_khi_luot_ay_hong(du_an_rpc):
    """Ghi TRƯỚC khi hiểu — [DEV-196].

    Một câu gõ ra rồi thì nó đã xảy ra, bất kể lượt hiểu có thành hay không. Ghi sau thì mọi
    câu làm `parse_intent` hỏng sẽ biến mất khỏi lịch sử — đúng những câu cần xem lại nhất.
    """
    from eide_core.memory import SessionMemory

    d, root = du_an_rpc
    d.router.invoke("project.open", {"project": str(root)}, d.ctx)
    d.chat_send({"text": "làm lại"})        # không có lượt dở → trả lỗi, nhưng PHẢI ghi lượt

    phien = SessionMemory.gan_nhat(root)
    assert phien is not None
    nguoi = [t for t in phien.turns if t["by"] == "human"]
    assert any("làm lại" in t["text"] for t in nguoi), f"không ghi lượt người: {phien.turns}"


# ---------------------------------------------------------------- chống tràn ngữ cảnh


def test_TOM_TAT_LUOT_khong_phinh_vo_han_va_dem_lai_van_dung(du_an_rpc):
    """**Nén nhiều tầng, và con số phải bất biến qua mọi tầng.** [DEV-197]

    §3 nói "3 lượt cũ gộp thành một TurnSummary" mà không nói gì về gộp chính các bản tóm tắt,
    nên bản đầu để chúng tích lại: đo 1 000 lượt ra **331 bản tóm tắt, tệp phiên 160 KB**.

    Ranh giới của cả cơ chế nén nằm ở phép khẳng định thứ hai: nén được phép làm mất CHI TIẾT,
    không được phép làm sai CON SỐ — câu "lần trước đã trao đổi N lượt" của §5 dựa vào nó.
    """
    from eide_core.memory import TOM_TAT_TRAN, SessionMemory

    d, root = du_an_rpc
    d.router.invoke("project.open", {"project": str(root)}, d.ctx)
    phien = SessionMemory.gan_nhat(root)
    N = 600
    for i in range(N):
        phien.them_luot("human" if i % 2 else "agent", f"lượt {i} " + "x" * 100)

    tt = [t for t in phien.turns if t["by"] == "summary"]
    assert len(tt) <= TOM_TAT_TRAN, f"tóm tắt phình tới {len(tt)}"
    assert len(phien.turns) < 30, f"turns phình tới {len(phien.turns)}"
    dem = (sum(int(t.get("n") or 1) for t in tt)
           + len([t for t in phien.turns if t["by"] != "summary"]))
    assert dem == N, f"nén làm SAI con số: đếm lại {dem}, thật {N}"


def test_NGU_CANH_khong_tran_du_du_an_rat_nhieu_diem_lam_ro(du_an_rpc):
    """Gói ngữ cảnh phải vừa ngân sách kể cả trên dự án đã chạy rất lâu.

    Đây là phép kiểm cho chính cơ chế chống tràn: C2 tự chặn trần, mọi lớp khác cắt được, nên
    `memory.compose` KHÔNG được ném E5001. Nếu bài này đỏ thì một dự án dùng lâu sẽ không gọi
    được mô hình nữa — hỏng ở chỗ khó chẩn đoán nhất.
    """
    from datetime import UTC, datetime

    d, root = du_an_rpc
    now = datetime.now(UTC).isoformat()
    with store.open_store(store.store_path(root)) as c:
        for i in range(800):
            c.execute("INSERT OR REPLACE INTO clarification"
                      " (id,kind,text,status,answer,answered_by,created_at,answered_at)"
                      " VALUES (?,?,?,?,?,?,?,?)",
                      (f"CL{i:05d}", "gap", f"Câu hỏi {i} về thông số phần cứng của mô-đun",
                       "answered", f"Trả lời {i}: {i * 7} kHz theo datasheet", "human", now, now))
        c.commit()

    k = d.router.invoke("memory.compose", {"role": "planner", "task_ref": "x"}, d.ctx)
    assert k.status == "done", f"ngữ cảnh TRÀN: {k.error}"
    b = k.result["bundle"]
    assert b["total_tokens"] <= b["budget"]["total"]
    # và nó phải NÓI RA đã bỏ bao nhiêu — quên im lặng là thứ tệ hơn cả tràn
    assert any(x.startswith("clarification:drop_") for x in b["compressions"]), b["compressions"]
