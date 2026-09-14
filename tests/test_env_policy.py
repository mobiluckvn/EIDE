from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


def test_env_detect_platform(tmp_path):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    env = r.invoke("env.detect", {}, Context()).result["env"]
    assert env["os"] in {"Darwin", "Windows", "Linux"} and env["python"]


def test_env_check_unknown_isa_E2000(tmp_path):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    run = r.invoke("env.check", {"isa": "z80"}, Context())
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_env_check_reports_missing_with_hint(tmp_path):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    rep = r.invoke("env.check", {"isa": "armv7e-m"}, Context()).result["report"]
    assert rep[0]["tool"] == "arm-none-eabi-gcc"
    for row in rep:
        if not row["found"]:
            assert row["ok"] is False and row["install_hint"] is not None


def test_emergency_stop_then_reject(tmp_path):
    gate = PolicyGate()
    r = Router(gate=gate, ledger=Ledger(tmp_path / "l.jsonl"))
    ctx = Context(extra={"gate": gate}, actor="human")  # dừng khẩn là T3: người bấm, hiệu lực tức thì
    assert r.invoke("policy.emergency_stop", {}, ctx).result["stopped"] is True
    run = r.invoke("env.detect", {}, ctx)
    assert run.status == "rejected" and run.error["code"] == "E3001"


def test_set_autonomy_relax_needs_human(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    ctx = Context(project_dir=workspace)
    r.invoke("project.create", {"text": "dự án test", "name": "test"}, ctx)
    # tác tử gọi năng lực T2 → PolicyGate đưa vào hàng đợi (pending), không chạy
    assert r.invoke("policy.set_autonomy", {"level": "A4", "by": "agent"}, Context(project_dir=workspace / "test")).status == "pending"
    pctx = Context(project_dir=workspace / "test", actor="human")
    run = r.invoke("policy.set_autonomy", {"level": "A4", "by": "agent"}, pctx)
    assert run.status == "failed" and run.error["eide_code"] == "E3000"
    assert r.invoke("policy.set_autonomy", {"level": "A4", "by": "human"}, pctx).result["effective"] == "A4"
    assert r.invoke("policy.set_autonomy", {"level": "A1", "by": "agent"}, pctx).result["effective"] == "A1"


# ---- đọc phiên bản công cụ (DEV-106, 14/09/2026)


def test_phien_ban_khong_doc_tu_duong_dan_cai_dat():
    """`_ver_ok` không được tìm số trong đường dẫn.

    Đo trên avrdude 8 thật (chỉ nhận `-v`): `version_of` trả về thông báo lỗi
    `"…/avrdude/8.0.0-arduino1/bin/avrdude: illegal option -- -"`, và `_ver_ok` tìm thấy
    `8.0.0` — **trong tên thư mục cài đặt** — rồi kết luận đạt. Lần ấy con số tình cờ đúng;
    lần sau ai cài một avrdude 6.3 vào thư mục tên `8.0.0` thì nó vẫn "đạt", và EIDE khẳng
    định một phiên bản nó chưa bao giờ hỏi được.
    """
    from eide.caps.env import _ver_ok

    loi = "/Users/x/Arduino15/packages/arduino/tools/avrdude/8.0.0-arduino1/bin/avrdude: illegal option -- -"
    assert not _ver_ok(loi, "7.0"), "số trong đường dẫn KHÔNG phải phiên bản công cụ"
    assert _ver_ok("avr-gcc (GCC) 7.3.0", "7.3"), "dòng phiên bản thật vẫn phải đạt"
    assert _ver_ok("Avrdude version 8.0-arduino.1", "7.0")


def test_version_of_chon_theo_NOI_DUNG_khong_theo_ma_thoat(tmp_path):
    """Mã thoát không phải tín hiệu phiên bản — đo trên avrdude 8 (14/09/2026).

    `avrdude --version` trả mã **0** nhưng in `"…/avrdude: illegal option -- -"`, còn
    `avrdude -v` trả mã **1** nhưng in đúng `"Avrdude version 8.0-arduino.1"`. Lọc theo mã
    thoát là nhận chuỗi rác và bỏ chuỗi thật — ngược hẳn. Kịch bản giả dưới đây dựng lại đúng
    cặp hành vi ấy, vì một fixture "hỏng thì mã khác 0" sẽ xanh cho một hàm vẫn sai.
    """
    import os
    import stat

    from eide_core.tools import version_of

    gia = tmp_path / "cong-cu-gia"
    gia.write_text("#!/bin/sh\n"
                   'if [ "$1" = "-v" ]; then echo "cong-cu-gia 8.0-arduino.1"; exit 1; fi\n'
                   'echo "$0: illegal option -- -"; exit 0\n', encoding="utf-8")
    gia.chmod(gia.stat().st_mode | stat.S_IXUSR)
    assert os.access(gia, os.X_OK)

    assert version_of(gia) == "cong-cu-gia 8.0-arduino.1", \
        "phải bỏ dòng chỉ có đường dẫn (mã 0) và lấy dòng phiên bản thật (mã 1)"

    cam = tmp_path / "khong-noi-phien-ban"
    cam.write_text("#!/bin/sh\necho 'khong noi gi ve phien ban'\nexit 0\n", encoding="utf-8")
    cam.chmod(cam.stat().st_mode | stat.S_IXUSR)
    assert version_of(cam) is None, "không dòng nào trông như phiên bản thì là KHÔNG BIẾT"


def test_khong_thu_co_V_tren_cong_cu_nap_firmware():
    """`-V` của avrdude nghĩa là **bỏ qua verify sau khi ghi**, không phải "in phiên bản".

    Thử một cờ đoán chừng trên công cụ nạp firmware là đúng loại việc không được phép làm, kể
    cả khi lần này nó vô hại vì không có `-U` đi kèm. Bài test này giữ điều đó khỏi trôi lại
    khi ai đó thêm "quy ước BSD" vào danh sách cho đủ.
    """
    from eide_core.tools import CO_PHIEN_BAN

    assert ("-V",) not in CO_PHIEN_BAN
