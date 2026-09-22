"""Khung JSON-RPC của daemon — API-15 §1.

Những bài ở đây đo tầng VỎ, không đo năng lực: một lời gọi hỏng có giết daemon không, một lệnh
dừng có đi qua mô hình không. Chúng ra đời từ các lỗi đo được trên giao diện thật ngày 22/09,
mà không bài nào ở mức năng lực bắt được — vì cả hai chỗ hỏng đều nằm GIỮA các bộ phận.
"""
from __future__ import annotations

from pathlib import Path

from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def test_mot_loi_goi_hong_KHONG_giet_daemon(tmp_path):
    """Một ngoại lệ ngoài ba loại được bắt từng làm vòng phục vụ thoát và daemon chết.

    Người dùng khi ấy mất TOÀN BỘ giao diện vì một lời gọi hỏng: màn hình chỉ hiện "Dữ liệu cũ
    — không nghe được daemon 6 giây qua", và không chỗ nào nói lời gọi nào đã làm nó chết.

    Đo 22/09/2026: sửa một migration ĐÃ ÁP nên store thiếu một cột, câu INSERT nổ, cả phiên đứt.
    """
    from eide.daemon.rpc import Daemon
    d = Daemon(project=None)
    d.methods["thu.no"] = lambda p: (_ for _ in ()).throw(RuntimeError("nổ giữa chừng"))
    r = d.handle({"jsonrpc": "2.0", "id": 9, "method": "thu.no", "params": {}})
    assert r["error"]["code"] == -32603
    assert "RuntimeError" in r["error"]["message"] and "nổ giữa chừng" in r["error"]["message"]
    # KHÔNG gắn `eide_code`: bảng 30 mã không có mã nào cho lỗi nội bộ, và mượn một mã sẵn có
    # là nói dối phía giao diện về loại sự cố. Xem [DEV-153].
    assert "data" not in r["error"], r["error"]
    # Daemon vẫn phục vụ được lời gọi kế tiếp — đó là toàn bộ điểm của bài này.
    assert d.handle({"jsonrpc": "2.0", "id": 10, "method": "plane.hello",
                    "params": {}})["result"]


# ---------- [DEV-155] DỪNG KHẨN phải xác định, không qua mô hình

def test_cau_dung_nhan_dung_ca_HAI_CHIEU():
    """Nhận sai hai chiều KHÔNG cân nhau.

    Dừng nhầm thì bật lại bằng một lần bấm; không dừng được thì tác tử chạy tiếp trên một việc
    người ta vừa bảo nó thôi. Nên quy tắc nghiêng về phía NHẬN — nhưng chỉ với câu NGẮN và đứng
    một mình, để một câu NÓI VỀ việc dừng không bị hiểu thành LỆNH dừng.
    """
    from eide.daemon.rpc import la_cau_dung
    for t in ["dừng", "Dừng khẩn!", "dung ngay", "stop", "STOP", "DỪNG LẠI", "thôi", "abort"]:
        assert la_cau_dung(t), t
    for t in ["không dừng lại ở đó", "dừng khi nào xong thì báo tôi", "tạo dự án mới",
              "dừng lại đi anh ơi vì tôi thấy nó sai rồi", ""]:
        assert not la_cau_dung(t), t


def test_go_dung_KHONG_goi_mo_hinh_lan_nao(tmp_path, workspace):
    """Bắt người đang muốn cắt một việc sai phải đợi một lượt gọi mô hình là đặt phép dừng lên
    trên chính thứ cần dừng — và khi mạng hỏng thì không dừng được.

    Trước [DEV-155] còn tệ hơn: `policy.stop` không có chuỗi mẫu và không trùng tên năng lực
    nào (`policy.emergency_stop` mới là tên thật), nên nó rơi xuống planner — HAI lượt gọi mô
    hình cho một lệnh dừng.
    """
    from eide.daemon.rpc import Daemon
    from eide_core.gateway import EchoPort, Gateway
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    root = Path(r.invoke("project.create", {"text": "thử dừng"},
                         Context(project_dir=workspace)).result["path"])
    d = Daemon(project=root)
    echo = EchoPort([])
    d.ctx.extra["gateway"] = Gateway(ledger=d.router.ledger,
                                     ports={"gemini": echo, "claude": echo})
    ra = d.chat_send({"text": "dừng khẩn"})
    assert echo.goi == [], "lệnh dừng KHÔNG được đi qua mô hình"
    assert ra["intent_id"] == "policy.stop" and ra["state"] == "done", ra
    assert ra["dung_khan"].get("stopped") is True, ra


def test_y_dinh_policy_co_chuoi_mau_khong_roi_xuong_planner():
    """Vế thứ hai: cả khi mô hình phân loại ra `policy.stop`, nó vẫn phải có đường đi xác định."""
    import json as _json

    from eide_core.paths import spec_dir
    ds = _json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    kich = {t: m for m in ds for t in (m.get("trigger_intents") or [])}
    assert [n["cap"] for n in kich["policy.stop"]["nodes"]] == ["policy.emergency_stop"]
    assert [n["cap"] for n in kich["policy.set"]["nodes"]] == ["policy.set_autonomy"]
