"""Nhóm arch.* — CDS-12.1; DDD-14 §2 Module/HwMap/ADR.

tc của hợp đồng: ARCH-01 TC-69 "robot → rtos hoặc event_driven có lý do"; ARCH-02 "Không chu
trình; mọi FR có module"; ARCH-03 TC-69 "xung đột = 0"; ARCH-04 "Tổng ≤ 85% Flash"; ARCH-05 "U
tính đúng"; ARCH-06 "Chữ ký biên dịch được"; ARCH-07 "FSM đầy đủ"; ARCH-08 "ADR có ≥ 1 phương
án bị loại và citations"; ARCH-09 TC-70 "ISR dài → finding"; ARCH-10 TC-70 "bảng có trọng số";
ARCH-11 "FEATURES.json có đủ module".

Phần deterministic ở nhóm này kiểm được sạch, và đó là điểm: một hệ không lập lịch được thì
không ai nhận ra bằng mắt.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.arch import (
    NGUONG_FLASH,
    RAM_TOI_THIEU_RTOS,
    _chu_ky_hong,
    _ghi_module,
    _kiem_do_thi,
    _kiem_fsm,
    _kieu_theo_quy_tac,
    _tim_chu_trinh,
)
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án kiến trúc"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def _gia_lap(monkeypatch, data):
    class _R:
        def __init__(self, d): self.data = d
    class _G:
        def run(self, *a, **k): return _R(data)
    import eide.caps.arch as m
    monkeypatch.setattr(m, "_gateway", lambda ctx: _G())
    monkeypatch.setattr(m, "_ngu_canh", lambda ctx, t: "")


def them_module(root, ds):
    _ghi_module(root, [{"interfaces": [], "depends": [], "status": "proposed", **d} for d in ds])
    return [d["id"] for d in ds]


def them_fact(root, subject, value, unit, predicate="memory_size", fid="f_1"):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_ds','ds.pdf','x','datasheet','gold')")
        c.execute("INSERT OR REPLACE INTO fact (id, subject, predicate, value, unit, source_id,"
                  " method, tier, confidence, status) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, subject, predicate, json.dumps(value), unit, "s_ds", "parser",
                   "gold", 1.0, "verified"))
        c.commit()


# ---------- ARCH-01 style_select: ba mệnh đề của bước 1


def test_RAM_duoi_4KB_thi_khong_bao_gio_ra_rtos():
    """Mệnh đề 1 là điều kiện LOẠI TRỪ. RAM 2 KB thì không nhét được kernel RTOS, bất kể có bao
    nhiêu tín hiệu đòi lập lịch — đây là ràng buộc vật lý, không phải sở thích thiết kế."""
    dk = {"ram_bytes": 2048, "so_chu_ky_khac_nhau": 5, "so_deadline_duoi_10ms": 3,
          "so_giao_tiep_chan": 4, "facts": []}
    loai, vi_sao = _kieu_theo_quy_tac(dk)
    assert loai != "rtos"
    assert loai == "event_driven"
    assert any("RAM" in x for x in vi_sao)


def test_TC69_nhieu_giao_tiep_chan_va_du_RAM_thi_rtos():
    """TC-69: "robot → rtos hoặc event_driven có lý do". Mệnh đề 3."""
    dk = {"ram_bytes": 128 * 1024, "so_chu_ky_khac_nhau": 1, "so_deadline_duoi_10ms": 0,
          "so_giao_tiep_chan": 3, "facts": []}
    loai, vi_sao = _kieu_theo_quy_tac(dk)
    assert loai == "rtos"
    assert vi_sao, "TC-69 đòi CÓ LÝ DO, không chỉ có kết luận"


def test_ba_chu_ky_va_deadline_ngan_thi_uu_tien_lap_lich():
    """Mệnh đề 2."""
    dk = {"ram_bytes": 64 * 1024, "so_chu_ky_khac_nhau": 3, "so_deadline_duoi_10ms": 1,
          "so_giao_tiep_chan": 0, "facts": []}
    assert _kieu_theo_quy_tac(dk)[0] == "rtos"


def test_khong_tin_hieu_gi_thi_super_loop():
    dk = {"ram_bytes": 64 * 1024, "so_chu_ky_khac_nhau": 0, "so_deadline_duoi_10ms": 0,
          "so_giao_tiep_chan": 0, "facts": []}
    assert _kieu_theo_quy_tac(dk)[0] == "super_loop"


def test_chua_biet_RAM_thi_khong_loai_rtos():
    """`ram_bytes = None` nghĩa là CHƯA BIẾT, không phải 0. Coi None là 0 thì mọi dự án chưa nạp
    hộ chiếu đều bị đẩy về super_loop — một mặc định sai một cách lặng lẽ."""
    dk = {"ram_bytes": None, "so_chu_ky_khac_nhau": 0, "so_deadline_duoi_10ms": 0,
          "so_giao_tiep_chan": 3, "facts": []}
    loai, vi_sao = _kieu_theo_quy_tac(dk)
    assert loai == "rtos"
    assert any("chưa có fact" in x for x in vi_sao)


def test_mo_hinh_khong_duoc_doi_style(du_an, monkeypatch):
    """Bước 1 chạy TRƯỚC bước 2 và thắng. Nếu mô hình đổi được kết luận thì thỉnh thoảng nó sẽ
    viết một lý do thuyết phục cho một phương án bất khả thi — mà lý do thuyết phục thì khó cãi
    hơn là không có lý do."""
    r, ctx, root = du_an
    them_fact(root, "chip:st.stm32f411ce/mem:RAM", 2, "kb")
    from eide.caps.req import _ghi_requirement
    _ghi_requirement(root, [{"id": "FR-COM-01", "kind": "FR",
                             "text": "Giao tiếp UART và I2C đồng thời"}])
    _gia_lap(monkeypatch, {"reasons": ["nên dùng RTOS"], "style": "rtos"})
    out = r.invoke("arch.style_select",
                   {"reqset_ids": ["FR-COM-01"], "passport": "st.stm32f411ce@1.0.0"},
                   ctx).result["decision"]
    assert out["style"] != "rtos", f"RAM 2 KB < {RAM_TOI_THIEU_RTOS} B mà vẫn ra rtos"


# ---------- ARCH-02 decompose: hai bất biến của tc


def test_chu_trinh_tra_ve_duong_di_chu_khong_phai_True():
    """"Có chu trình" thì người dùng vẫn phải tự dò mười module; "app → service → driver → app"
    thì họ sửa được ngay."""
    duong = _tim_chu_trinh({"app": ["service"], "service": ["driver"], "driver": ["app"]})
    assert duong[0] == duong[-1]
    assert set(duong) == {"app", "service", "driver"}


def test_do_thi_khong_chu_trinh_thi_rong():
    assert _tim_chu_trinh({"app": ["driver"], "driver": ["hal"], "hal": []}) == []


def test_kiem_do_thi_gom_HET_loi_chu_khong_dung_o_loi_dau():
    """Một phân rã do mô hình sinh thường sai vài chỗ cùng lúc; báo từng cái một buộc người dùng
    chạy lại năm lần."""
    mods = [{"id": "mod_a", "layer": "hal", "depends": ["mod_x"], "req_ids": []},
            {"id": "mod_b", "layer": "driver", "depends": [], "req_ids": []}]
    ds = [{"id": "FR-01", "kind": "FR"}]
    loi = _kiem_do_thi(mods, ds)
    assert len(loi) >= 2
    assert any("không tồn tại" in x for x in loi)
    assert any("FR-01" in x for x in loi)


def test_phu_thuoc_nguoc_lop_bi_bat():
    """"hal → driver → service → control → app": lớp dưới không được phụ thuộc lớp trên. Một HAL
    gọi ngược lên service là thứ làm cả tầng kiến trúc mất nghĩa."""
    mods = [{"id": "mod_hal_gpio", "layer": "hal", "depends": ["mod_app_main"], "req_ids": []},
            {"id": "mod_app_main", "layer": "app", "depends": [], "req_ids": []}]
    loi = _kiem_do_thi(mods, [])
    assert any("ngược lên" in x for x in loi)


def test_moi_FR_phai_co_module(du_an, monkeypatch):
    """tc: "mọi FR có module". Một FR không module nào nhận thì im lặng tuyệt đối — nó chỉ lộ ra
    ở req.trace_matrix, sau khi đã lập kế hoạch và viết mã."""
    r, ctx, root = du_an
    from eide.caps.req import _ghi_requirement
    _ghi_requirement(root, [{"id": "FR-SNS-01", "kind": "FR", "text": "Đọc nhiệt độ"},
                            {"id": "FR-CTL-01", "kind": "FR", "text": "Điều khiển PID"}])
    _gia_lap(monkeypatch, {"modules": [
        {"id": "sensor", "name": "sensor", "responsibility": "đọc cảm biến",
         "layer": "driver", "depends": [], "req_ids": ["FR-SNS-01"]}]})
    run = r.invoke("arch.decompose",
                   {"reqset_ids": ["FR-SNS-01", "FR-CTL-01"], "style": "super_loop"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"
    assert "FR-CTL-01" in str(run.error)


def test_decompose_noi_module_vao_requirement_trace(du_an, monkeypatch):
    """`requirement.trace` là thứ `req.trace_matrix` đọc để báo lỗ hổng — không nối thì mọi yêu
    cầu đều trông như "chưa ai hiện thực" dù đã có module."""
    r, ctx, root = du_an
    from eide.caps.req import _ghi_requirement
    _ghi_requirement(root, [{"id": "FR-SNS-01", "kind": "FR", "text": "Đọc nhiệt độ"}])
    _gia_lap(monkeypatch, {"modules": [
        {"id": "sensor", "name": "sensor", "responsibility": "đọc cảm biến",
         "layer": "driver", "depends": [], "req_ids": ["FR-SNS-01"]}]})
    r.invoke("arch.decompose", {"reqset_ids": ["FR-SNS-01"], "style": "super_loop"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        (tr,) = c.execute("SELECT trace FROM requirement WHERE id='FR-SNS-01'").fetchone()
    assert "mod_sensor" in json.loads(tr)


# ---------- ARCH-03 map_hw


def test_hai_module_doi_cung_tai_nguyen_thi_ASK(du_an):
    """tc TC-69 "xung đột = 0"; ask "Xung đột chân/timer không tự giải". Hai module cùng đòi I2C
    là một sự thật về tập hợp, không phải một nhận định — nên nó deterministic."""
    r, ctx, root = du_an
    ids = them_module(root, [
        {"id": "mod_a", "name": "cảm biến i2c", "responsibility": "đọc qua i2c"},
        {"id": "mod_b", "name": "eeprom i2c", "responsibility": "lưu qua i2c"}])
    run = r.invoke("arch.map_hw", {"module_ids": ids, "passport": "st.stm32f411ce@1.0.0"}, ctx)
    assert run.status == "pending" and run.error["eide_code"] == "E3000"


def test_khong_xung_dot_thi_ghi_hw_map(du_an):
    r, ctx, root = du_an
    ids = them_module(root, [
        {"id": "mod_a", "name": "cảm biến i2c", "responsibility": "đọc qua i2c"},
        {"id": "mod_b", "name": "log uart", "responsibility": "ghi log qua uart"}])
    out = r.invoke("arch.map_hw", {"module_ids": ids, "passport": "st.stm32f411ce@1.0.0"},
                   ctx).result
    assert out["conflicts"] == []
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM hw_map").fetchone()[0] == 2


def test_khong_suy_dien_ngoai_vi_khong_duoc_neu_ten(du_an):
    """"module cảm biến chắc dùng I2C" là loại phỏng đoán tạo ra một HwMap trông đầy đủ nhưng
    sai — và một bản đồ chân sai tệ hơn một bản đồ trống, vì người ta tin nó rồi hàn theo."""
    r, ctx, root = du_an
    ids = them_module(root, [{"id": "mod_a", "name": "cảm biến nhiệt độ",
                              "responsibility": "đọc nhiệt độ môi trường"}])
    out = r.invoke("arch.map_hw", {"module_ids": ids, "passport": "st.stm32f411ce@1.0.0"},
                   ctx).result
    assert out["hw_map"] == []


# ---------- ARCH-04 memory_budget


def test_vuot_85_phan_tram_flash_thi_ASK(du_an):
    """tc: "Tổng ≤ 85% Flash". Phần còn lại phải đủ cho bootloader, vùng cấu hình, và lần cập
    nhật sau — firmware lấp đầy 99% Flash là firmware không vá được tại hiện trường."""
    r, ctx, root = du_an
    them_fact(root, "chip:tiny/mem:FLASH", 8, "kb", fid="f_flash")
    ids = them_module(root, [{"id": f"mod_app_{i}", "name": f"app {i}"} for i in range(3)])
    run = r.invoke("arch.memory_budget", {"module_ids": ids, "passport": "tiny@1.0.0"}, ctx)
    assert run.status == "pending" and run.error["eide_code"] == "E3000"


def test_vua_du_flash_nhung_qua_85_phan_tram_van_khong_dat(du_an):
    """ĐÂY mới là test chứng minh ngưỡng 85%, không phải test trên.

    Ba module app = 12 288 B; Flash 13 000 B. Tổng VỪA nằm trong Flash (94%) nhưng vượt 85%.
    Nếu bỏ hệ số `NGUONG_FLASH` mà so thẳng với dung lượng Flash thì trường hợp này "đạt" — và
    đó chính là firmware lấp gần đầy, không còn chỗ cho bootloader hay lần cập nhật sau. Test
    cũ vượt ngân sách quá xa nên đỏ cả khi ngưỡng bị gỡ: nó chứng minh nhầm thứ.
    """
    r, ctx, root = du_an
    them_fact(root, "chip:vua/mem:FLASH", 13, "kb", fid="f_flash")
    ids = them_module(root, [{"id": f"mod_app_{i}", "name": f"app {i}"} for i in range(3)])
    run = r.invoke("arch.memory_budget", {"module_ids": ids, "passport": "vua@1.0.0"}, ctx)
    assert run.status == "pending" and run.error["eide_code"] == "E3000"
    b = run.error["budget"]
    assert b["total"]["flash"] < b["limits"]["flash"], "phải là trường hợp CÒN chỗ trong Flash"


def test_duoi_nguong_thi_ok(du_an):
    r, ctx, root = du_an
    them_fact(root, "chip:big/mem:FLASH", 512, "kb", fid="f_flash")
    them_fact(root, "chip:big/mem:RAM", 128, "kb", fid="f_ram")
    ids = them_module(root, [{"id": "mod_driver_i2c", "name": "i2c"}])
    b = r.invoke("arch.memory_budget", {"module_ids": ids, "passport": "big@1.0.0"},
                 ctx).result["budget"]
    assert b["ok"] is True
    assert b["threshold_flash"] == NGUONG_FLASH


def test_chua_co_fact_bo_nho_thi_ok_la_None(du_an):
    """Không có giới hạn mà trả True thì bản ngân sách nói "đạt" trong khi chưa so với gì cả;
    trả False thì mọi dự án chưa nạp hộ chiếu đều bị chặn. Cả hai đều sai."""
    r, ctx, root = du_an
    ids = them_module(root, [{"id": "mod_driver_i2c", "name": "i2c"}])
    b = r.invoke("arch.memory_budget", {"module_ids": ids, "passport": "chua_co@1.0.0"},
                 ctx).result["budget"]
    assert b["ok"] is None


def test_stack_duoc_cong_vao_RAM(du_an):
    """Stack nằm cùng vùng và cạnh tranh cùng chỗ với biến toàn cục. Cộng riêng rồi so RAM mà
    quên stack là cách phổ biến nhất để một bản ngân sách "đạt" rồi tràn lúc chạy."""
    r, ctx, root = du_an
    ids = them_module(root, [{"id": "mod_driver_i2c", "name": "i2c"}])
    b = r.invoke("arch.memory_budget", {"module_ids": ids, "passport": "x@1.0.0"},
                 ctx).result["budget"]
    assert b["total"]["ram_gom_stack"] == b["total"]["ram"] + b["total"]["stack"]
    assert b["total"]["stack"] > 0


def test_so_do_thang_so_uoc_luong(du_an):
    """Bước 1: "+ lịch sử code.size các dự án". Và bảng phải nói rõ dòng nào là đo, dòng nào là
    ước lượng — trộn hai loại mà không phân biệt thì cả bảng được đọc như đã đo hết."""
    r, ctx, root = du_an
    ids = them_module(root, [{"id": "mod_driver_i2c", "name": "i2c"}])
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO measurement (id, kind, target, value, at) VALUES "
                  "('m_1','custom','mod_driver_i2c',?,'2026-01-01T00:00:00Z')",
                  (json.dumps({"flash": 111, "ram": 22, "stack": 33}),))
        c.commit()
    b = r.invoke("arch.memory_budget", {"module_ids": ids, "passport": "x@1.0.0"},
                 ctx).result["budget"]
    assert b["per_module"][0] == {"module_id": "mod_driver_i2c", "flash": 111, "ram": 22,
                                 "stack": 33, "nguon": "đo"}


# ---------- ARCH-05 timing_budget


def test_U_tinh_dung_va_so_voi_can_Liu_Layland(du_an):
    """tc: "U tính đúng". Hai tác vụ: 1000 µs/10 ms + 1000 µs/20 ms = 0,10 + 0,05 = 0,15.
    Cận với n=2 là 2(√2−1) ≈ 0,8284."""
    r, ctx, root = du_an
    them_module(root, [
        {"id": "mod_a", "name": "a", "budget": {"period_ms": 10, "wcet_us": 1000}},
        {"id": "mod_b", "name": "b", "budget": {"period_ms": 20, "wcet_us": 1000}}])
    b = r.invoke("arch.timing_budget", {"module_ids": ["mod_a", "mod_b"]}, ctx).result["budget"]
    assert b["utilization"] == pytest.approx(0.15)
    assert b["bound"] == pytest.approx(2 * (2 ** 0.5 - 1), abs=1e-4)
    assert b["schedulable"] is True


def test_vuot_can_thi_ASK_va_noi_ro_la_dieu_kien_du(du_an):
    """Liu–Layland là điều kiện ĐỦ, không phải điều kiện cần. Báo "không lập lịch được" khi mới
    chỉ là "chưa chứng minh được" sẽ đẩy người ta đi làm lại một thiết kế vốn đúng."""
    r, ctx, root = du_an
    them_module(root, [
        {"id": "mod_a", "name": "a", "budget": {"period_ms": 10, "wcet_us": 6000}},
        {"id": "mod_b", "name": "b", "budget": {"period_ms": 20, "wcet_us": 8000}}])
    run = r.invoke("arch.timing_budget", {"module_ids": ["mod_a", "mod_b"]}, ctx)
    assert run.status == "pending" and run.error["eide_code"] == "E3000"
    assert "CHƯA CHỨNG MINH" in run.error["budget"]["note"]


def test_uu_tien_theo_chu_ky_ngan_hon(du_an):
    """Đơn điệu theo chu kỳ: chu kỳ ngắn hơn ⇒ ưu tiên cao hơn. Đó là định nghĩa của RMS."""
    r, ctx, root = du_an
    them_module(root, [
        {"id": "mod_cham", "name": "chậm", "budget": {"period_ms": 100, "wcet_us": 100}},
        {"id": "mod_nhanh", "name": "nhanh", "budget": {"period_ms": 5, "wcet_us": 100}}])
    b = r.invoke("arch.timing_budget", {"module_ids": ["mod_cham", "mod_nhanh"]},
                 ctx).result["budget"]
    uu = {t["module_id"]: t["prio"] for t in b["tasks"]}
    assert uu["mod_nhanh"] < uu["mod_cham"]


def test_module_khong_co_chu_ky_thi_khong_vao_phep_tinh(du_an):
    """Nhét nó vào với một chu kỳ bịa sẽ làm sai U theo hướng bi quan — và một cảnh báo bi quan
    giả cũng làm hỏng niềm tin y như một cảnh báo lạc quan giả."""
    r, ctx, root = du_an
    them_module(root, [{"id": "mod_a", "name": "a", "budget": {"period_ms": 10, "wcet_us": 100}},
                       {"id": "mod_b", "name": "b"}])
    b = r.invoke("arch.timing_budget", {"module_ids": ["mod_a", "mod_b"]}, ctx).result["budget"]
    assert b["n"] == 1
    assert [t["module_id"] for t in b["tasks"]] == ["mod_a"]


# ---------- ARCH-06 interface_spec


@pytest.mark.parametrize(("sig", "hong"), [
    # Hợp lệ — lấy từ dạng thật trong mã nhúng, không phải ví dụ tự nghĩ.
    ("int bme280_read(struct bme280 *dev, float *out)", False),
    ("void i2c_init(void)", False),
    ("uint8_t crc8(const uint8_t *buf, size_t n)", False),
    ("char *ten_loi(int ma)", False),                        # con trỏ ở kiểu trả về
    ("uint8_t* buf_get(void)", False),                       # sao dính kiểu, cách viết khác
    ("static inline void delay(uint32_t ms)", False),        # static/inline
    ("int reg_isr(uint8_t irq, void (*h)(void), void *arg)", False),   # con trỏ hàm
    ("void f(int a[8])", False),                             # tham số mảng
    ("esp_err_t i2c_write(i2c_port_t p, const uint8_t *b, size_t n)", False),
    # Hỏng
    ("bme280_read(dev)", True),                       # thiếu kiểu trả về
    ("int f(", True),                                 # ngoặc lệch
    ("int f()", True),                                # C cần `void` khi không tham số
    ("int 9bad(void)", True),                         # tên bắt đầu bằng số
    ("int f(void, )", True),                          # tham số rỗng sau dấu phẩy
    ("", True),
])
def test_chu_ky_C_kiem_duoc(sig, hong):
    """tc: "Chữ ký biên dịch được (kiểm bằng header stub)".

    Hai chiều đều quan trọng, và chiều BÁO NHẦM nguy hiểm hơn: `arch.interface_spec` ném E5002
    khi thấy chữ ký hỏng, nên một phép kiểm quá chặt sẽ chặn hẳn lời gọi vì mã C hoàn toàn hợp
    lệ. Con trỏ hàm và `static inline` từng bị loại oan đúng như vậy — chúng ở đây để không tái
    diễn.
    """
    assert (_chu_ky_hong(sig) is not None) is hong, _chu_ky_hong(sig)


def test_chu_ky_hong_neu_ro_ly_do():
    """"Chữ ký không hợp lệ" thì người sửa vẫn phải tự dò."""
    assert "ngoặc" in _chu_ky_hong("int f(")
    assert "void" in _chu_ky_hong("int f()")


def test_interface_spec_tu_choi_chu_ky_hong(du_an, monkeypatch):
    r, ctx, root = du_an
    them_module(root, [{"id": "mod_a", "name": "a"}])
    _gia_lap(monkeypatch, {"interfaces": [
        {"module": "mod_a", "functions": [{"sig": "khong_phai_chu_ky"}]}]})
    run = r.invoke("arch.interface_spec", {"module_ids": ["mod_a"]}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


# ---------- ARCH-07 state_machine


def test_FSM_thieu_cap_trang_thai_su_kien_thi_bao():
    """Một cặp không khai là hành vi KHÔNG XÁC ĐỊNH — trong firmware nghĩa là sự kiện đến vào
    đúng lúc sai thì thiết bị kẹt ở một trạng thái không ai lường."""
    loi = _kiem_fsm({"states": ["idle", "run"], "events": ["start", "stop"], "initial": "idle",
                     "transitions": [{"from": "idle", "event": "start", "to": "run"}]})
    assert any("không khai" in x for x in loi)


def test_FSM_day_du_thi_qua():
    fsm = {"states": ["idle", "run"], "events": ["start", "stop"], "initial": "idle",
           "transitions": [
               {"from": "idle", "event": "start", "to": "run"},
               {"from": "idle", "event": "stop", "ignore": True},
               {"from": "run", "event": "start", "ignore": True},
               {"from": "run", "event": "stop", "to": "idle"}]}
    assert _kiem_fsm(fsm) == []


def test_FSM_trang_thai_khong_toi_duoc_thi_bao():
    """Thường là dấu hiệu THIẾU một chuyển tiếp, chứ không phải thừa một trạng thái."""
    fsm = {"states": ["idle", "run", "loi"], "events": ["start"], "initial": "idle",
           "transitions": [{"from": "idle", "event": "start", "to": "run"},
                           {"from": "run", "event": "start", "ignore": True},
                           {"from": "loi", "event": "start", "ignore": True}]}
    assert any("không tới được" in x for x in _kiem_fsm(fsm))


def test_FSM_initial_khong_thuoc_states_thi_bao():
    assert any("initial" in x for x in _kiem_fsm(
        {"states": ["a"], "events": [], "initial": "b", "transitions": []}))


# ---------- ARCH-08 adr


def test_ADR_khong_co_phuong_an_bi_loai_thi_tu_choi(du_an, monkeypatch):
    """tc: "ADR có ≥ 1 phương án bị loại". Một quyết định không có phương án thay thế là một lời
    tuyên bố — sáu tháng sau không ai biết những gì đã được cân nhắc rồi bỏ."""
    r, ctx, root = du_an
    them_fact(root, "chip:x", 1, "kb", fid="f_1")
    _gia_lap(monkeypatch, {"title": "Chọn RTOS", "context": "c", "consequences": "h",
                           "decision": "FreeRTOS",
                           "options": [{"name": "FreeRTOS"}], "citations": ["f_1"]})
    run = r.invoke("arch.adr", {"decision": {"title": "Chọn RTOS"}}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_ADR_trich_dan_bia_bi_loai(du_an, monkeypatch):
    """Một trích dẫn bịa tệ hơn không trích dẫn: nó tạo vẻ đã kiểm chứng."""
    r, ctx, root = du_an
    _gia_lap(monkeypatch, {"title": "t", "context": "c", "consequences": "h",
                           "decision": "A", "options": [{"name": "A"}, {"name": "B"}],
                           "citations": ["f_khong_ton_tai"]})
    run = r.invoke("arch.adr", {"decision": {"title": "t"}}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5002"


def test_ADR_hop_le_thi_ghi_file_va_bang(du_an, monkeypatch):
    r, ctx, root = du_an
    them_fact(root, "chip:x", 1, "kb", fid="f_1")
    _gia_lap(monkeypatch, {"title": "Chọn RTOS", "context": "RAM đủ", "consequences": "phức tạp",
                           "decision": "FreeRTOS",
                           "options": [{"name": "FreeRTOS", "pros": "ổn"},
                                       {"name": "super loop", "cons": "khó mở rộng"}],
                           "citations": ["f_1", "f_bia"]})
    out = r.invoke("arch.adr", {"decision": {"title": "Chọn RTOS"}}, ctx).result
    assert out["adr_id"] == "ADR-01"
    from pathlib import Path
    md = Path(out["path"]).read_text(encoding="utf-8")
    assert "super loop" in md and "`f_1`" in md
    assert "f_bia" not in md, "trích dẫn không có thật phải bị lọc khỏi tài liệu"
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM adr").fetchone()[0] == 1


def test_ma_ADR_tang_dan(du_an, monkeypatch):
    r, ctx, root = du_an
    them_fact(root, "chip:x", 1, "kb", fid="f_1")
    _gia_lap(monkeypatch, {"title": "t", "context": "c", "consequences": "h", "decision": "A",
                           "options": [{"name": "A"}, {"name": "B"}], "citations": ["f_1"]})
    a = r.invoke("arch.adr", {"decision": {}}, ctx).result["adr_id"]
    b = r.invoke("arch.adr", {"decision": {}}, ctx).result["adr_id"]
    assert (a, b) == ("ADR-01", "ADR-02")


# ---------- ARCH-09 review


def test_TC70_ISR_dai_thanh_finding(du_an, monkeypatch):
    """tc TC-70: "ISR dài → finding". Một hàm khai `isr_safe` mà bên trong có vòng lặp hoặc chờ
    là mâu thuẫn tự thân — và là nguyên nhân kinh điển của trễ ngắt không giải thích được."""
    r, ctx, root = du_an
    _ghi_module(root, [{"id": "mod_a", "name": "a", "depends": [], "status": "proposed",
                        "interfaces": [{"sig": "void isr_handler(void)", "isr_safe": True,
                                        "timing": "while chờ cờ bus"}]}])
    _gia_lap(monkeypatch, {"findings": []})
    fs = r.invoke("arch.review", {"module_ids": ["mod_a"]}, ctx).result["findings"]
    assert any(f["rule"] == "isr_dai" and f["severity"] == "high" for f in fs)


def test_driver_bus_khong_khai_ma_loi_thanh_finding(du_an, monkeypatch):
    r, ctx, root = du_an
    _ghi_module(root, [{"id": "mod_a", "name": "a", "depends": [], "status": "proposed",
                        "interfaces": [{"sig": "int i2c_read(uint8_t addr)"}]}])
    _gia_lap(monkeypatch, {"findings": []})
    fs = r.invoke("arch.review", {"module_ids": ["mod_a"]}, ctx).result["findings"]
    assert any(f["rule"] == "loi_bus" for f in fs)


def test_moi_finding_deu_noi_ro_nguon(du_an, monkeypatch):
    """Quy tắc hay mô hình — người đọc cần biết, vì một finding từ quy tắc thì lặp lại được,
    còn một finding từ mô hình thì lần sau có thể biến mất."""
    r, ctx, root = du_an
    _ghi_module(root, [{"id": "mod_a", "name": "a", "depends": [], "status": "proposed",
                        "interfaces": []}])
    _gia_lap(monkeypatch, {"findings": [
        {"module": "mod_a", "rule": "khac", "message": "m", "severity": "low"}]})
    fs = r.invoke("arch.review", {"module_ids": ["mod_a"]}, ctx).result["findings"]
    assert fs and all(f["nguon"] in ("quy tắc", "mô hình") for f in fs)
    assert {f["nguon"] for f in fs} == {"quy tắc", "mô hình"}


def test_mo_hinh_khong_lap_lai_finding_cua_quy_tac(du_an, monkeypatch):
    r, ctx, root = du_an
    _ghi_module(root, [{"id": "mod_a", "name": "a", "depends": [], "status": "proposed",
                        "interfaces": [{"sig": "int i2c_read(uint8_t addr)"}]}])
    _gia_lap(monkeypatch, {"findings": [
        {"module": "mod_a", "rule": "loi_bus", "message": "trùng", "severity": "high"}]})
    fs = r.invoke("arch.review", {"module_ids": ["mod_a"]}, ctx).result["findings"]
    assert len([f for f in fs if f["rule"] == "loi_bus"]) == 1


# ---------- ARCH-10 compare


def test_TC70_bang_co_trong_so(du_an, monkeypatch):
    """tc TC-70: "bảng có trọng số". Cộng điểm do MÃ, không do mô hình — một mô hình được yêu
    cầu "chấm rồi chọn" hay chọn trước rồi chấm ngược lại cho khớp."""
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"scores": [
        {"option": "A", "by_criterion": {"ram": 5, "flash": 1}},
        {"option": "B", "by_criterion": {"ram": 1, "flash": 5}}]})
    out = r.invoke("arch.compare", {
        "options": [{"name": "A"}, {"name": "B"}],
        "criteria": [{"name": "ram", "weight": 3}, {"name": "flash", "weight": 1}]},
        ctx).result["comparison"]
    # A: (5·3 + 1·1)/4 = 4,0 ; B: (1·3 + 5·1)/4 = 2,0
    assert out["scores"] == {"A": 4.0, "B": 2.0}
    assert out["recommendation"] == "A"


def test_trong_so_that_su_doi_ket_qua(du_an, monkeypatch):
    """Đảo trọng số phải đảo kết luận — nếu không thì cột trọng số chỉ là trang trí."""
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"scores": [
        {"option": "A", "by_criterion": {"ram": 5, "flash": 1}},
        {"option": "B", "by_criterion": {"ram": 1, "flash": 5}}]})
    out = r.invoke("arch.compare", {
        "options": [{"name": "A"}, {"name": "B"}],
        "criteria": [{"name": "ram", "weight": 1}, {"name": "flash", "weight": 3}]},
        ctx).result["comparison"]
    assert out["recommendation"] == "B"


def test_compare_chi_de_cu_chu_khong_chot(du_an, monkeypatch):
    """ask "Chọn phương án cuối" ở mức T1*: chốt phương án là việc của người."""
    r, ctx, _ = du_an
    _gia_lap(monkeypatch, {"scores": [{"option": "A", "by_criterion": {}}]})
    out = r.invoke("arch.compare", {"options": [{"name": "A"}]}, ctx).result["comparison"]
    assert "quyết định của người" in out["note"]


# ---------- ARCH-11 to_plan


def test_FEATURES_json_co_du_module(du_an):
    """tc: "FEATURES.json có đủ module"."""
    r, ctx, root = du_an
    ids = them_module(root, [{"id": "mod_app", "name": "app", "depends": ["mod_hal_clock"]},
                             {"id": "mod_hal_clock", "name": "clock"}])
    out = r.invoke("arch.to_plan", {"module_ids": ids}, ctx).result
    assert set(out["features"]) == set(ids)
    from pathlib import Path
    d = json.loads((Path(root) / ".eide" / "FEATURES.json").read_text(encoding="utf-8"))
    assert {f["id"] for f in d["features"]} == set(ids)


def test_thu_tu_do_plan_order_quyet_dinh(du_an):
    """Ủy quyền cho `plan.order`, không tự sắp lại: hai chỗ cùng biết thứ tự bậc phần cứng là
    hai chỗ sẽ trôi khỏi nhau, và khi ấy không ai biết cái nào đúng."""
    r, ctx, root = du_an
    ids = them_module(root, [{"id": "mod_app", "name": "app", "depends": ["mod_hal_clock"]},
                             {"id": "mod_hal_clock", "name": "clock"}])
    out = r.invoke("arch.to_plan", {"module_ids": ids}, ctx).result
    assert out["order"].index("mod_hal_clock") < out["order"].index("mod_app")


def test_to_plan_ghi_feature_trang_thai_failing(du_an):
    """`failing` chứ không `blocked`: chưa có bằng chứng nào nói nó chạy, và đó đúng nghĩa của
    `failing` trong DDD-14 §2 Feature."""
    r, ctx, root = du_an
    them_module(root, [{"id": "mod_a", "name": "a"}])
    r.invoke("arch.to_plan", {"module_ids": ["mod_a"]}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT status FROM feature WHERE id='mod_a'").fetchone()[0] == "failing"


def test_chon_kieu_kien_truc_KHONG_doi_ho_chieu_chip(du_an, monkeypatch):
    """Chọn kiểu kiến trúc KHÔNG phụ thuộc mã chip — [DEV-211].

    `passport` chỉ nuôi MỘT tín hiệu trong bốn của quy tắc ARCH-01: RAM. Ba tín hiệu còn lại —
    số chu kỳ khác nhau, số deadline dưới 10 ms, số giao tiếp chặn — đến từ chính các YÊU CẦU.

    Và người ta chọn kiến trúc RỒI mới chọn chip, không ngược lại. Bắt ghim hộ chiếu trước là
    đảo ngược thứ tự thiết kế. Đo 23/09/2026: bốn ca (TC002, TC008, TC027, TC041) dừng ở
    *"Chưa ghim hộ chiếu chip — chip nào?"* cho một quyết định không cần biết chip.

    Hiện thực đã lường trước từ lâu: `_ram_tu_passport` trả `None` nghĩa "chưa biết" và
    `_kieu_theo_quy_tac` nói "quy tắc RAM không áp dụng". Chỉ hợp đồng ép hỏi.
    """
    r, ctx, root = du_an
    from eide.caps.req import _ghi_requirement
    _ghi_requirement(root, [
        {"id": "FR-COM-01", "kind": "FR", "text": "Đọc cảm biến qua I2C và chờ phản hồi"},
        {"id": "FR-COM-02", "kind": "FR", "text": "Nhận lệnh qua UART và chờ dữ liệu về"}])
    _gia_lap(monkeypatch, {"reasons": ["hai giao tiếp chặn"], "style": "rtos"})
    # KHÔNG truyền `passport` — đó chính là thứ bài này đo.
    run = r.invoke("arch.style_select", {"reqset_ids": ["FR-COM-01", "FR-COM-02"]}, ctx)
    assert run.status == "done", f"vẫn đòi hộ chiếu: {run.error}"
    qd = run.result["decision"]
    assert qd.get("style"), "không chọn được kiểu kiến trúc nào"
    # Phải NÓI RA rằng quy tắc RAM chưa áp dụng được — im lặng là giấu một phần cơ sở quyết định.
    assert any("RAM" in str(x) for x in (qd.get("reasons") or [])), \
        f"không nói rõ quy tắc RAM chưa áp dụng: {qd.get('reasons')}"


def test_cau_nhac_ADR_co_rang_buoc_DO_DAI():
    """Một câu nhắc không giới hạn độ dài sẽ tràn MỌI cái trần. [DEV-216]

    Đo 24/09/2026: `arch.adr` tràn trần 4096 token; nâng lên 12288 thì VẪN TRÀN. Nâng trần là
    đuổi theo một đầu ra không có giới hạn.

    Và ràng buộc này không phải mẹo lách trần — nó là yêu cầu thật của chính hiện vật: ADR tồn
    tại để sáu tháng sau người ta biết đã cân nhắc gì rồi bỏ gì, mà một tài liệu hai chục trang
    thì không ai đọc.
    """
    import inspect

    from eide.caps import arch

    src = inspect.getsource(arch.adr)
    assert "NGẮN GỌN" in src, "câu nhắc ADR không ràng buộc độ dài"
    assert "tối đa" in src.lower(), "không nêu giới hạn cụ thể cho từng phần"
