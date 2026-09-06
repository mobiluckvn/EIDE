"""WI-009 · Sandbox và ENV-07 env.sandbox — SEC-25 §2; CDS-12.3; STP-05 TC-SE-03.

SEC-25 §2 từng câu: giới hạn CPU/RAM/tệp mở/kích thước ghi, wall-clock 300 s, thư mục làm việc
tạm riêng, chỉ đọc `allowed_dirs`, biến môi trường tối thiểu (không PATH người dùng, không khóa
API), macOS dùng `sandbox-exec` khi có, ghi ledger MỨC CÁCH LY.
TC-SE-03: "Extractor thử mở socket và đọc biến khóa → thất bại; ledger ghi vi phạm E8000".
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from eide_core.sandbox import MUC_CACH_LY, Sandbox

PY = sys.executable


def _sb(tmp_path, **kw):
    return Sandbox(out_dir=tmp_path / "out", **kw)


def _router(tmp_path):
    return Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))


def doc(p) -> str:
    return Path(p).read_text(encoding="utf-8")


# ---------- chạy bình thường ----------

def test_chay_lenh_va_tra_ref_khong_tra_noi_dung(tmp_path):
    """output_schema trả `stdout_ref`/`stderr_ref` — ĐƯỜNG DẪN, không phải nội dung.

    Extractor có thể in hàng trăm MB; nhét vào kết quả năng lực là nhét vào cả ledger
    (result_hash) lẫn ngữ cảnh mô hình.
    """
    kq = _sb(tmp_path).run([PY, "-c", "print('xin chào')"])
    assert kq.exit_code == 0
    assert kq.violations == []
    assert doc(kq.stdout_ref).strip() == "xin chào"
    assert doc(kq.stderr_ref) == ""


def test_ma_thoat_khac_khong_phai_vi_pham(tmp_path):
    """Lệnh trả mã khác 0 là kết quả bình thường; chỉ vượt GIỚI HẠN mới là vi phạm."""
    kq = _sb(tmp_path).run([PY, "-c", "import sys; sys.exit(3)"])
    assert kq.exit_code == 3 and kq.violations == []


# ---------- TC-SE-03: không mạng, không khóa ----------

@pytest.mark.skipif(sys.platform != "darwin", reason="sandbox-exec chỉ có trên macOS")
def test_khong_mo_duoc_socket(tmp_path):
    """TC-SE-03 vế 1. Trên macOS `sandbox-exec` chặn thật — đã đo, không phải giả định."""
    ma = ("import socket\n"
          "try:\n"
          "    socket.create_connection(('8.8.8.8', 53), timeout=5)\n"
          "    print('MO_DUOC')\n"
          "except Exception as e:\n"
          "    print('BI_CHAN', type(e).__name__)\n")
    kq = _sb(tmp_path).run([PY, "-c", ma])
    assert "MO_DUOC" not in doc(kq.stdout_ref), "sandbox không chặn được mạng"
    assert "BI_CHAN" in doc(kq.stdout_ref)


def test_khong_thay_khoa_api(tmp_path, monkeypatch):
    """TC-SE-03 vế 2: "đọc biến khóa → thất bại".

    SEC-25 §3: khóa "không bao giờ ghi vào .eide/, ledger, log". Tiến trình con thừa kế môi
    trường của cha nếu không ai chặn — nên môi trường phải được DỰNG LẠI, không phải lọc bớt.
    """
    monkeypatch.setenv("GEMINI_API_KEY", "AIzaSyD-khoa-that-khong-duoc-lo-ra-0123")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-khong-duoc-lo-0123456789")
    ma = ("import os\n"
          "print('KEYS=', [k for k in os.environ if 'KEY' in k.upper() or 'TOKEN' in k.upper()])\n")
    out = doc(_sb(tmp_path).run([PY, "-c", ma]).stdout_ref)
    assert "AIzaSyD" not in out and "sk-ant" not in out
    assert "KEYS= []" in out


def test_khong_thua_ke_PATH_cua_nguoi_dung(tmp_path, monkeypatch):
    """SEC-25 §2: "biến môi trường tối thiểu (không PATH của người dùng)".

    PATH của người dùng là một đường đưa mã lạ vào: một thư mục ~/bin bị ghi đè là đủ để
    `docling` thành một thứ khác.
    """
    monkeypatch.setenv("PATH", "/duong-dan-rieng-cua-nguoi-dung:" + os.environ.get("PATH", ""))
    out = doc(_sb(tmp_path).run([PY, "-c", "import os; print(os.environ.get('PATH'))"]).stdout_ref)
    assert "/duong-dan-rieng-cua-nguoi-dung" not in out


# ---------- giới hạn tài nguyên ----------

def test_qua_wall_clock_thi_E4004(tmp_path):
    """`errors` của hợp đồng có E4004 TIMEOUT — quá thời gian là lỗi riêng, không phải E8000."""
    with pytest.raises(EideError) as ei:
        _sb(tmp_path).run([PY, "-c", "import time; time.sleep(30)"], limits={"wall_s": 1})
    assert ei.value.code == "E4004"
    assert "wall" in ei.value.data["violations"]


def test_qua_cpu_thi_bi_giet(tmp_path):
    """SEC-25 §2: giới hạn CPU. Vòng lặp bận bị SIGXCPU (mã thoát âm)."""
    kq = _sb(tmp_path).run([PY, "-c", "i=0\nwhile True: i+=1"],
                           limits={"cpu_s": 1, "wall_s": 30})
    assert kq.exit_code != 0
    assert "cpu" in kq.violations


def test_qua_kich_thuoc_ghi(tmp_path):
    """SEC-25 §2: "kích thước ghi 2 GB" — ở đây hạ xuống 1 KB để kiểm nhanh."""
    ma = "open('to.bin','wb').write(b'x' * (1024*1024))"
    kq = _sb(tmp_path).run([PY, "-c", ma], limits={"fsize_b": 1024})
    assert kq.exit_code != 0 and "fsize" in kq.violations


def test_qua_so_tep_mo(tmp_path):
    kq = _sb(tmp_path).run([PY, "-c", "fs=[open('/dev/null') for _ in range(200)]"],
                           limits={"nofile": 16})
    assert kq.exit_code != 0 and "nofile" in kq.violations


# ---------- thư mục làm việc và đường dẫn ----------

def test_thu_muc_lam_viec_la_tam_rieng(tmp_path):
    """SEC-25 §2: "thư mục làm việc tạm riêng". Không được chạy trong thư mục dự án."""
    out = doc(_sb(tmp_path).run([PY, "-c", "import os; print(os.getcwd())"]).stdout_ref)
    assert out.strip() != str(Path.cwd())
    assert "eide-sandbox" in out


def test_moi_lan_chay_mot_thu_muc_khac(tmp_path):
    sb = _sb(tmp_path)
    a = doc(sb.run([PY, "-c", "import os; print(os.getcwd())"]).stdout_ref).strip()
    b = doc(sb.run([PY, "-c", "import os; print(os.getcwd())"]).stdout_ref).strip()
    assert a != b


def test_duong_dan_ngoai_allowed_dirs_bi_tu_choi(tmp_path):
    """SEC-25 §2: "chuẩn hóa đường dẫn và TỪ CHỐI `..`/tuyệt đối/symlink ra ngoài"."""
    with pytest.raises(EideError) as ei:
        _sb(tmp_path).run([PY, "-c", "pass"], allowed_dirs=["../../../etc"])
    assert ei.value.code == "E8000"


# ---------- mức cách ly ghi vào ledger ----------

def test_ghi_muc_cach_ly_vao_ledger(tmp_path):
    """SEC-25 §2: khi phải lui về tiến trình con + `resource`, "ghi ledger MỨC CÁCH LY".

    Ghi cả khi đạt mức cao nhất, không chỉ khi lui: người đọc nhật ký cần biết lệnh này chạy
    dưới lớp bảo vệ nào, chứ không phải suy ra từ chỗ vắng một dòng.
    """
    led = Ledger(tmp_path / "l.jsonl")
    Sandbox(out_dir=tmp_path / "out", ledger=led).run([PY, "-c", "print(1)"])
    rec = [x for x in led.records() if x["kind"] == "tool.report"]
    assert len(rec) == 1
    assert rec[0]["data"]["isolation"] in MUC_CACH_LY
    assert led.verify() == (True, 0)


@pytest.mark.skipif(sys.platform != "darwin", reason="macOS")
def test_macos_dat_muc_cach_ly_sandbox_exec(tmp_path):
    led = Ledger(tmp_path / "l.jsonl")
    Sandbox(out_dir=tmp_path / "out", ledger=led).run([PY, "-c", "print(1)"])
    assert [x for x in led.records()][0]["data"]["isolation"] == "sandbox-exec"


def test_mang_bat_tuong_minh_thi_ha_muc_cach_ly(tmp_path):
    """SEC-25 §5: lệnh cài đặt là "ngoại lệ duy nhất có mạng" — và điều đó phải hiện ra trong
    nhật ký, vì nó là một lớp bảo vệ ít hơn."""
    led = Ledger(tmp_path / "l.jsonl")
    Sandbox(out_dir=tmp_path / "out", ledger=led).run([PY, "-c", "print(1)"], network=True)
    assert led.records()[0]["data"]["network"] is True


# ---------- năng lực env.sandbox ----------

def test_nang_luc_tra_dung_output_schema(tmp_path, workspace):
    r = _router(tmp_path)
    run = r.invoke("env.sandbox", {"cmd": [PY, "-c", "print('chào')"]}, Context())
    assert run.status == "done", run
    assert set(run.result) == {"exit_code", "stdout_ref", "stderr_ref", "violations"}
    assert run.result["exit_code"] == 0
    assert doc(run.result["stdout_ref"]).strip() == "chào"


def test_nang_luc_qua_han_bao_E4004(tmp_path):
    r = _router(tmp_path)
    run = r.invoke("env.sandbox", {"cmd": [PY, "-c", "import time; time.sleep(20)"],
                                   "limits": {"wall_s": 1}}, Context())
    assert run.status == "failed" and run.error["eide_code"] == "E4004"


def test_vi_du_trong_hop_dong_qua_duoc_schema(tmp_path):
    """"Ví dụ gọi" của CDS phải qua input_schema — DEV-009 đã cho thấy điều này không hiển nhiên."""
    import json

    import jsonschema

    from eide_core.registry import get_registry
    spec = get_registry().get("env.sandbox").spec
    jsonschema.validate(json.loads(spec.example), spec.input_schema)
