

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
