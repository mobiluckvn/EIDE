"""`Ledger.theo_doi_tep` — giao diện thấy việc của TIẾN TRÌNH KHÁC (GIAM-SAT-UI §0.1).

Đây là mắt xích làm cho "giám sát" có nghĩa: cùng một dự án có thể có một daemon phục vụ giao
diện, một CLI người dùng gõ, và một tác tử chạy nền — cả ba ghi vào CÙNG một `ledger.jsonl`.
Trước 14/09/2026 daemon chỉ nghe chính nó, nên tác tử chạy 28 lời gọi và ghi 105 sự kiện trong
khi cửa sổ EIDE đang mở không hiện một dòng nào.

Bộ test này chủ yếu là các ca HỎNG, vì thứ đứng giữa sổ cái và giao diện mà dừng lại một lần
thì người dùng nhìn màn hình đứng yên và tưởng tác tử chưa làm gì — một lỗi không kêu.
"""
from __future__ import annotations

import json
import threading
import time

import pytest

from eide_core.ledger import Ledger, TheoDoiTep, _doc_dong


def _cho(dk, han: float = 3.0, nhip: float = 0.02) -> bool:
    """Đợi tới khi `dk()` đúng. Đợi có điều kiện chứ không `sleep` một cục: máy chậm thì test
    hỏng giả, máy nhanh thì test tốn thời gian vô ích."""
    het = time.monotonic() + han
    while time.monotonic() < het:
        if dk():
            return True
        time.sleep(nhip)
    return dk()


@pytest.fixture
def so(tmp_path):
    return Ledger(tmp_path / "ledger.jsonl")


@pytest.fixture
def thu():
    """Người nhận: danh sách có khoá, vì luồng nền ghi còn test đọc."""
    nhan: list[dict] = []
    khoa = threading.Lock()

    def f(rec):
        with khoa:
            nhan.append(rec)

    f.nhan = nhan  # type: ignore[attr-defined]
    f.khoa = khoa  # type: ignore[attr-defined]
    return f


# ---------------------------------------------------------------- đường chính


def test_thay_ban_ghi_do_TIEN_TRINH_KHAC_ghi(tmp_path, thu):
    """Bất biến trung tâm: hai đối tượng `Ledger` trên cùng một tệp — đúng hình dạng
    "daemon của giao diện" và "CLI của tác tử" — và bên theo dõi phải thấy việc của bên kia."""
    duong = tmp_path / "ledger.jsonl"
    giao_dien = Ledger(duong)
    td = giao_dien.theo_doi_tep(thu, chu_ky=0.02)
    try:
        tac_tu = Ledger(duong)            # tiến trình khác, cùng tệp
        tac_tu.append("cap.run.start", {"run_id": "r1", "cap": "extract.atdf"})
        tac_tu.append("cap.run.finish", {"run_id": "r1", "status": "done"})

        assert _cho(lambda: len(thu.nhan) >= 2), f"chỉ nhận {len(thu.nhan)}"
        assert [r["kind"] for r in thu.nhan] == ["cap.run.start", "cap.run.finish"]
        assert thu.nhan[0]["data"]["cap"] == "extract.atdf"
    finally:
        td.dung()


def test_khong_phat_TRUNG_viec_cua_chinh_minh(so, thu):
    """Cùng một daemon vừa ghi qua `append()` (đã phát cho `_quan_sat`) vừa đọc tệp.

    Không lọc theo `seq` thì mọi việc của chính nó lên giao diện HAI lần — và một dòng thời
    gian nhân đôi thì người đọc không còn tin được con số nào trên đó.
    """
    trong_tien_trinh: list[dict] = []
    so.theo_doi(trong_tien_trinh.append)
    td = so.theo_doi_tep(thu, chu_ky=0.02)
    try:
        so.append("store.write", {"table": "fact", "n": 287})
        assert _cho(lambda: len(trong_tien_trinh) == 1)
        # Cho người theo dõi tệp vài vòng để chắc chắn nó ĐÃ đọc rồi mới khẳng định
        time.sleep(0.15)
        seqs = [r["seq"] for r in thu.nhan]
        assert len(seqs) == len(set(seqs)), f"phát trùng: {seqs}"
    finally:
        td.dung()


def test_phat_lai_N_ban_ghi_cuoi_khi_mo_giao_dien(tmp_path, thu):
    """Mở giao diện SAU khi tác tử đã chạy thì vẫn phải thấy nó vừa làm gì.

    Phát lại xảy ra trong `bat_dau()` chứ không trong luồng nền: người gọi vì thế chắc chắn
    thấy đủ quá khứ trước bản ghi mới đầu tiên. Làm trong luồng nền thì hai nguồn đua nhau và
    dòng thời gian ra sai thứ tự.
    """
    duong = tmp_path / "ledger.jsonl"
    cu = Ledger(duong)
    for i in range(10):
        cu.append("cap.run.start", {"run_id": f"r{i}"})

    moi = Ledger(duong)
    td = moi.theo_doi_tep(thu, phat_lai=3, chu_ky=0.02)
    try:
        assert [r["data"]["run_id"] for r in thu.nhan] == ["r7", "r8", "r9"]
    finally:
        td.dung()


def test_phat_lai_0_thi_chi_nghe_tu_nay(tmp_path, thu):
    duong = tmp_path / "ledger.jsonl"
    cu = Ledger(duong)
    cu.append("cap.run.start", {"run_id": "cu"})

    moi = Ledger(duong)
    td = moi.theo_doi_tep(thu, chu_ky=0.02)
    try:
        time.sleep(0.1)
        assert thu.nhan == []
        Ledger(duong).append("cap.run.start", {"run_id": "moi"})
        assert _cho(lambda: len(thu.nhan) == 1)
        assert thu.nhan[0]["data"]["run_id"] == "moi"
    finally:
        td.dung()


# ---------------------------------------------------------------- ca hỏng


def test_tep_chua_ton_tai_thi_doi_chu_khong_no(tmp_path, thu):
    """Dự án mới chưa có sổ cái, và mở giao diện trước lời gọi đầu tiên là chuyện thường."""
    duong = tmp_path / "chua-co" / "ledger.jsonl"
    duong.parent.mkdir()
    td = TheoDoiTep(duong, thu, chu_ky=0.02)
    td.bat_dau()
    try:
        time.sleep(0.1)
        assert thu.nhan == []
        Ledger(duong).append("cap.run.start", {"run_id": "r1"})
        assert _cho(lambda: len(thu.nhan) == 1), "phải bắt được ngay khi tệp xuất hiện"
    finally:
        td.dung()


def test_dong_viet_do_khong_bi_doc_nua_chung(tmp_path, thu):
    """`append()` ghi một lần `write` nhưng hệ tệp không hứa nguyên tử.

    Đọc phải phần đầu một bản ghi rồi parse là ra JSON hỏng; tệ hơn, nếu bỏ qua luôn thì bản
    ghi ấy MẤT HẲN khỏi giao diện dù nó có thật trong sổ. Phần đuôi phải được giữ lại cho vòng
    sau, và bản ghi phải xuất hiện đúng MỘT lần khi đã đủ.
    """
    duong = tmp_path / "ledger.jsonl"
    duong.write_text("", encoding="utf-8")
    td = TheoDoiTep(duong, thu, chu_ky=0.02)
    td.bat_dau()
    try:
        ban_ghi = json.dumps({"seq": 1, "ts": "t", "kind": "cap.run.start",
                              "actor": "agent", "data": {"run_id": "r1"},
                              "prev_hash": "0" * 64, "hash": "a" * 64}, ensure_ascii=False)
        with duong.open("a", encoding="utf-8") as f:
            f.write(ban_ghi[:30])        # nửa dòng
            f.flush()
        time.sleep(0.1)
        assert thu.nhan == [], "nửa dòng KHÔNG được phát"

        with duong.open("a", encoding="utf-8") as f:
            f.write(ban_ghi[30:] + "\n")  # phần còn lại
            f.flush()
        assert _cho(lambda: len(thu.nhan) == 1), "đủ dòng rồi thì phải phát"
        assert thu.nhan[0]["data"]["run_id"] == "r1"
        time.sleep(0.1)
        assert len(thu.nhan) == 1, "và phát đúng một lần"
    finally:
        td.dung()


def test_dong_hong_khong_dung_viec_doc(tmp_path, thu):
    """Sổ cái là chỉ-thêm nên một dòng hỏng là dấu hiệu ghi dở hoặc đĩa lỗi — những dòng SAU nó
    vẫn đọc được, và dừng lại ở đó là mất phần còn lại của phiên làm việc."""
    duong = tmp_path / "ledger.jsonl"
    duong.write_text("", encoding="utf-8")
    td = TheoDoiTep(duong, thu, chu_ky=0.02)
    td.bat_dau()
    try:
        with duong.open("a", encoding="utf-8") as f:
            f.write("{ đây không phải JSON\n")
            f.write(json.dumps({"seq": 2, "kind": "cap.run.finish",
                                "data": {"status": "done"}}) + "\n")
        assert _cho(lambda: len(thu.nhan) == 1)
        assert thu.nhan[0]["kind"] == "cap.run.finish"
    finally:
        td.dung()


def test_dong_JSON_hop_le_nhung_khong_phai_doi_tuong_thi_bo_qua():
    """`"[1,2,3]"` và `"12"` đều là JSON hợp lệ. Một bản ghi sổ cái thì phải là đối tượng —
    thả một danh sách xuống hàm nhận sẽ nổ ở chỗ nó đọc `rec["kind"]`."""
    assert _doc_dong("[1,2,3]") is None
    assert _doc_dong("12") is None
    assert _doc_dong('"chuoi"') is None
    assert _doc_dong("   ") is None
    assert _doc_dong('{"seq": 1}') == {"seq": 1}


def test_tep_ngan_di_thi_doc_lai_tu_dau(tmp_path, thu):
    """Ai đó xoay vòng, xoá hay chép đè sổ cái. Giữ nguyên vị trí cũ là trượt vào GIỮA một bản
    ghi, và từ đó mọi dòng đọc ra đều hỏng — người theo dõi câm vĩnh viễn mà không báo gì."""
    duong = tmp_path / "ledger.jsonl"
    goc = Ledger(duong)
    for i in range(5):
        goc.append("cap.run.start", {"run_id": f"cu{i}"})

    td = TheoDoiTep(duong, thu, chu_ky=0.02)
    td.bat_dau()
    try:
        time.sleep(0.08)
        assert thu.nhan == []
        # Thay bằng một tệp NGẮN hơn hẳn, seq mới
        duong.write_text(json.dumps({"seq": 99, "kind": "cap.run.start",
                                     "data": {"run_id": "sau-khi-cat"}}) + "\n",
                         encoding="utf-8")
        assert _cho(lambda: len(thu.nhan) == 1), "phải phát hiện tệp ngắn đi và đọc lại"
        assert thu.nhan[0]["data"]["run_id"] == "sau-khi-cat"
    finally:
        td.dung()


def test_ham_nhan_nem_loi_thi_van_di_tiep(tmp_path):
    """Panel đóng ống, JSON không tuần tự hoá được — không lý do nào đáng để mất những bản ghi
    CÒN LẠI. Đúng nguyên tắc mà `append()` đã áp cho `_quan_sat`."""
    duong = tmp_path / "ledger.jsonl"
    nhan: list[dict] = []

    def hong(rec):
        nhan.append(rec)
        if len(nhan) == 1:
            raise RuntimeError("panel đóng ống")

    td = TheoDoiTep(duong, hong, chu_ky=0.02)
    td.bat_dau()
    try:
        so = Ledger(duong)
        so.append("cap.run.start", {"run_id": "r1"})
        so.append("cap.run.start", {"run_id": "r2"})
        assert _cho(lambda: len(nhan) == 2), "bản ghi sau lỗi vẫn phải tới"
    finally:
        td.dung()


def test_ban_ghi_khong_co_seq_van_duoc_phat(tmp_path, thu):
    """Lọc trùng dựa vào `seq`, nhưng một bản ghi thiếu `seq` thì KHÔNG được im lặng bỏ đi —
    thà hiện một dòng lạ còn hơn giấu một việc đã xảy ra."""
    duong = tmp_path / "ledger.jsonl"
    duong.write_text("", encoding="utf-8")
    td = TheoDoiTep(duong, thu, chu_ky=0.02)
    td.bat_dau()
    try:
        with duong.open("a", encoding="utf-8") as f:
            f.write(json.dumps({"kind": "error", "data": {"message": "không có seq"}}) + "\n")
        assert _cho(lambda: len(thu.nhan) == 1)
    finally:
        td.dung()


def test_dung_roi_thi_thoi_phat(tmp_path, thu):
    """`dung()` phải thật sự dừng: một luồng còn sống sau khi cửa sổ đóng là một luồng ghi vào
    một panel không còn ai đọc."""
    duong = tmp_path / "ledger.jsonl"
    so = Ledger(duong)
    td = so.theo_doi_tep(thu, chu_ky=0.02)
    so.append("cap.run.start", {"run_id": "truoc"})
    assert _cho(lambda: len(thu.nhan) == 1)

    td.dung()
    assert not td._luong.is_alive(), "luồng phải dừng hẳn"
    so.append("cap.run.start", {"run_id": "sau"})
    time.sleep(0.1)
    assert len(thu.nhan) == 1, "dừng rồi thì không phát nữa"


def test_luong_la_daemon_nen_khong_giu_tien_trinh(tmp_path, thu):
    """Quên `dung()` là chuyện sẽ xảy ra. Luồng daemon nghĩa là tiến trình vẫn thoát được —
    một `eide daemon` không chịu chết vì còn một luồng theo dõi là thứ người dùng phải `kill`."""
    td = TheoDoiTep(tmp_path / "l.jsonl", thu, chu_ky=0.02)
    td.bat_dau()
    try:
        assert td._luong is not None and td._luong.daemon
    finally:
        td.dung()


def test_nhieu_ban_ghi_mot_luot_van_dung_thu_tu(tmp_path, thu):
    """`extract.svd` ghi hàng nghìn `store.write` trong vài giây, nên một vòng đọc thường bắt
    được nhiều dòng cùng lúc. Thứ tự trên dòng thời gian phải là thứ tự trong sổ."""
    duong = tmp_path / "ledger.jsonl"
    duong.write_text("", encoding="utf-8")
    td = TheoDoiTep(duong, thu, chu_ky=0.05)
    td.bat_dau()
    try:
        so = Ledger(duong)
        for i in range(200):
            so.append("store.write", {"table": "fact", "i": i})
        assert _cho(lambda: len(thu.nhan) == 200), f"chỉ nhận {len(thu.nhan)}/200"
        assert [r["data"]["i"] for r in thu.nhan] == list(range(200))
    finally:
        td.dung()


def test_khoa_API_da_bi_che_truoc_khi_len_giao_dien(tmp_path, thu):
    """`che_bi_mat` chạy trong `append()`, nên thứ người theo dõi đọc được là thứ đã che.

    Bài test này canh một đường RÒ cụ thể: giao diện nhận dữ liệu từ tệp chứ không từ lời gọi,
    nên nếu có ngày ai đó ghi thẳng vào tệp mà bỏ qua `append()`, khoá sẽ đi tiếp ra màn hình.
    """
    duong = tmp_path / "ledger.jsonl"
    so = Ledger(duong)
    td = so.theo_doi_tep(thu, chu_ky=0.02)
    try:
        so.append("model.call", {"prompt": "khoá là sk-abcdef1234567890 nhé"})
        assert _cho(lambda: len(thu.nhan) == 1)
        assert "sk-abcdef1234567890" not in json.dumps(thu.nhan[0], ensure_ascii=False)
        assert "đã che" in json.dumps(thu.nhan[0], ensure_ascii=False)
    finally:
        td.dung()


def test_tep_bi_xoa_giua_chung_thi_doi_chu_khong_chet(tmp_path, thu):
    """Xoá cả tệp trong lúc theo dõi — hiếm, nhưng `rm -rf .eide` thì có thật."""
    duong = tmp_path / "ledger.jsonl"
    so = Ledger(duong)
    so.append("cap.run.start", {"run_id": "r1"})
    td = TheoDoiTep(duong, thu, chu_ky=0.02)
    td.bat_dau()
    try:
        duong.unlink()
        time.sleep(0.1)
        assert td._luong.is_alive(), "mất tệp không được giết luồng"
        Ledger(duong).append("cap.run.start", {"run_id": "r2"})
        assert _cho(lambda: any(r["data"].get("run_id") == "r2" for r in thu.nhan))
    finally:
        td.dung()


def test_UTF8_nhieu_byte_khong_bi_cat_giua_ky_tu(tmp_path, thu):
    """Tiếng Việt có dấu là 2–3 byte một ký tự, và người theo dõi đọc theo BYTE.

    Cắt giữa một ký tự rồi decode sẽ ra ký tự thay thế, và bản ghi mang tên dự án tiếng Việt
    hiện lên giao diện thành chữ hỏng. Bản ghi phải tới nguyên vẹn.
    """
    duong = tmp_path / "ledger.jsonl"
    so = Ledger(duong)
    td = so.theo_doi_tep(thu, chu_ky=0.02)
    try:
        ten = "Đọc cảm biến DHT22 — nhấp nháy LED trên Arduino Uno"
        so.append("project.state", {"name": ten})
        assert _cho(lambda: len(thu.nhan) == 1)
        assert thu.nhan[0]["data"]["name"] == ten
    finally:
        td.dung()
