from eide_core.ledger import Ledger


def test_hash_chain_and_verify(tmp_path):
    lg = Ledger(tmp_path / "ledger.jsonl")
    lg.append("cap.run.start", {"run_id": "a", "cap": "project.create"})
    lg.append("cap.run.finish", {"run_id": "a", "status": "done"})
    ok, bad = lg.verify()
    assert ok and bad == 0 and len(lg.records()) == 2
    # giả mạo dòng 1 → chuỗi vỡ
    lines = (tmp_path / "ledger.jsonl").read_text(encoding="utf-8").splitlines()
    lines[0] = lines[0].replace('"project.create"', '"project.archive"')
    (tmp_path / "ledger.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    ok, bad = Ledger(tmp_path / "ledger.jsonl").verify()
    assert not ok and bad == 1


def test_unknown_kind_rejected(tmp_path):
    import pytest

    from eide_core.errors import EideError

    with pytest.raises(EideError) as e:
        Ledger(tmp_path / "l.jsonl").append("weird.event", {})
    assert e.value.code == "E6001"


# ---------- gate.decision: lời hứa mà niêm phong đang dựa vào (lỗi im lặng số 12)

def test_moi_quyet_dinh_cong_deu_vao_CHUOI_BAM(tmp_path, workspace):
    """`store.BANG_VAN_HANH` loại `decision_log` khỏi niêm phong, và lý do ghi trong `store.py`
    là: *"mọi quyết định cũng vào nhật ký `gate.decision`, và nhật ký là chuỗi băm nối tiếp —
    mạnh hơn một niêm phong đơn. Ai sửa `decision_log` để giấu một quyết định vẫn lộ khi đối
    chiếu bảng với nhật ký."*

    Tới 12/09/2026 câu ấy KHÔNG đúng: không chỗ nào phát sự kiện ấy. `decision_log` vừa nằm
    ngoài niêm, vừa vắng khỏi nhật ký — nên sửa bảng để giấu một quyết định thì không cơ chế
    nào phát hiện, đúng thứ mà lý do loại trừ kia hứa là phát hiện được.

    Bài này canh lời hứa đó. Nó phải đỏ nếu ai đó bỏ phần phát nhật ký đi.
    """
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    ctx = Context(project_dir=workspace)
    r.invoke("project.create", {"text": "dự án đo nhiệt"}, ctx)

    qd = [x for x in r.ledger.records() if x["kind"] == "gate.decision"]
    assert qd, "không có gate.decision nào — niêm phong đang dựa vào một cơ chế không tồn tại"
    d = qd[0]["data"]
    # Đủ trường để ĐỐI CHIẾU với một dòng `decision_log`: thiếu `run_id` hay `rule` thì phép đối
    # chiếu mà `store.py` viện dẫn không thực hiện được, và lời hứa lại thành câu nói suông.
    for truong in ("run_id", "gate", "action_cap", "risk", "decision", "by", "rule"):
        assert truong in d, f"gate.decision thiếu `{truong}` — không đối chiếu được với bảng"
    assert r.ledger.verify() == (True, 0)


def test_so_quyet_dinh_trong_NHAT_KY_khop_voi_BANG(tmp_path, workspace):
    """Phép đối chiếu mà `store.py` hứa: đếm hai bên phải bằng nhau.

    Đây là bài kiểm biến lời hứa thành thứ chạy được. Một quyết định bị xoá khỏi bảng làm hai
    con số lệch; một quyết định không vào nhật ký cũng thế.
    """
    import sqlite3

    from eide_core import store
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án hai bánh"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    for _ in range(3):
        r.invoke("project.status", {}, ctx)

    with sqlite3.connect(store.store_path(root)) as c:
        trong_bang = c.execute("SELECT count(*) FROM decision_log").fetchone()[0]
    trong_nhat_ky = sum(1 for x in r.ledger.records()
                        if x["kind"] == "gate.decision" and x["data"].get("action_cap")
                        in ("project.status",))
    assert trong_bang == trong_nhat_ky == 3, (trong_bang, trong_nhat_ky)


def test_append_dong_thoi_KHONG_gay_chuoi_bam(tmp_path):
    """Sổ cái là một CHUỖI BĂM; ghi đồng thời từ hai luồng phải không làm gãy nó. [DEV-162]

    Tới [DEV-154] daemon còn đơn luồng nên `append` không cần khoá. Từ khi chuỗi chạy ở luồng
    nền, có HAI người ghi sổ cùng lúc: luồng chuỗi và vòng lặp chính phục vụ `view.timeline`,
    `queue.list`… `self._seq += 1` không nguyên tử và `_last_hash` bị ghi đè chéo.

    Đo 22/09/2026 bằng ảnh chụp cửa sổ thật giữa một lượt CNC: giao diện treo biển "thiếu 1 bản
    ghi sổ cái (seq 22…22)". Thứ hỏng không phải một badge — `verify()` sẽ báo chuỗi băm gãy,
    và bằng chứng của cả phiên làm việc mất giá trị.
    """
    import threading

    led = Ledger(tmp_path / "l.jsonl")
    loi: list[Exception] = []

    def ghi(n: int) -> None:
        try:
            for i in range(60):
                led.append("session.open", {"luong": n, "i": i})
        except Exception as e:  # noqa: BLE001
            loi.append(e)

    ts = [threading.Thread(target=ghi, args=(n,)) for n in range(4)]
    for t in ts:
        t.start()
    for t in ts:
        t.join()

    assert not loi, loi
    recs = led.records()
    assert len(recs) == 240, f"mất bản ghi: {len(recs)}/240"
    assert [r["seq"] for r in recs] == list(range(1, 241)), "seq trùng hoặc nhảy cóc"
    assert led.verify() == (True, 0), "chuỗi băm gãy"
