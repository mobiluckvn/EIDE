

def test_luat_muc_nao_thi_dung_cho_gat_dau():
    """§2D.6 nguyên văn: A1 hỏi trước, A2–A3 tự chạy nhưng vẫn in ý hiểu.

    Mức LẠ thì không dừng — mặc định an toàn ở đây là chạy tiếp, vì một mức gõ sai làm treo mọi
    lệnh sẽ trông y hệt sản phẩm hỏng.
    """
    from eide.daemon.rpc import cho_nguoi_gat
    assert cho_nguoi_gat("A0") and cho_nguoi_gat("A1")
    assert not cho_nguoi_gat("A2")
    assert not cho_nguoi_gat("A3")
    assert not cho_nguoi_gat("A4")
    assert not cho_nguoi_gat("khong-phai-muc")
