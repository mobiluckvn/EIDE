"""Đóng mốc M0: archive.list/unpack, memory.ledger, project.set_target, registry.seed.

Spec: CDS-12.2 ARCHIVE-01/02, CDS-12.6 MEMORY-05, CDS-12.3 PROJECT-02, CDS-12.5 REGISTRY-01;
SEC-25 (sandbox); API-15 §5 (bảng loại sự kiện ledger).

tc: TC-11, TC-SE-02 (giải nén an toàn); "Zip lồng 3 cấp liệt kê đủ; rar → E4001"; "Chuỗi hash
liên tục; regex khóa bị che"; "Ghim st.stm32f411ce@x; chip lạ → missing"; TC-42.

`archive.unpack` là bề mặt tấn công thật của EIDE: người dùng tải một "SDK" từ diễn đàn rồi bảo
tác tử mở ra. Phần lớn test trong tệp này là về việc KHÔNG làm gì — không ghi ra ngoài thư mục
đích, không theo liên kết mềm, không giải nén một quả bom.
"""
from __future__ import annotations

import io
import tarfile
import zipfile
from pathlib import Path

import pytest

from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án m0"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


def zip_voi(p: Path, muc: dict[str, bytes]) -> Path:
    with zipfile.ZipFile(p, "w", zipfile.ZIP_DEFLATED) as z:
        for ten, noi in muc.items():
            z.writestr(ten, noi)
    return p


def zip_long(p: Path, sau: int) -> Path:
    """Zip lồng `sau` cấp, tệp trong cùng tên `day.svd`."""
    trong = b"<device><name>X</name></device>"
    for i in range(sau):
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as z:
            z.writestr("day.svd" if i == 0 else f"muc{i}.zip", trong)
        trong = buf.getvalue()
    p.write_bytes(trong)
    return p


# ---------- ARCHIVE-01 archive.list


def test_liet_ke_zip_long_3_cap(tmp_path, du_an):
    """tc: "Zip lồng 3 cấp liệt kê đủ". Đọc BẢNG MỤC, không giải nén: một SDK vendor thường là
    zip 800 MB chứa đúng một tệp SVD cần dùng."""
    r, ctx, _ = du_an
    p = zip_long(tmp_path / "sdk.zip", 3)
    e = r.invoke("archive.list", {"path": str(p), "depth": 3}, ctx).result["entries"]
    # cấp 1 → muc2.zip → muc1.zip → day.svd
    sau = e
    for _ in range(2):
        assert sau[0]["nested"], f"thiếu cấp lồng: {sau}"
        sau = sau[0]["nested"]
    assert sau[0]["path"] == "day.svd" and sau[0]["kind_guess"] == "svd"


def test_depth_nguoi_goi_duoc_ton_trong(tmp_path, du_an):
    """`depth` là ý người gọi."""
    r, ctx, _ = du_an
    p = zip_long(tmp_path / "sau.zip", 4)
    e = r.invoke("archive.list", {"path": str(p), "depth": 1}, ctx).result["entries"]
    assert e[0]["nested"] is not None
    assert e[0]["nested"][0]["nested"] is None, "depth=1 mà vẫn đi xuống cấp 2"


def _sau_nhat(e: list[dict]) -> int:
    """Số cấp lồng thực sự đi xuống."""
    n = 0
    while e and e[0].get("nested"):
        n += 1
        e = e[0]["nested"]
    return n


def test_tran_cung_depth_chan_ca_khi_nguoi_goi_xin_nhieu(tmp_path, du_an):
    """`GIOI_HAN["depth"]` là TRẦN CỨNG, độc lập với `depth` người gọi truyền.

    Đây là test tôi thiếu ở lần đầu: bản trước dùng `depth=1` — dưới trần — nên nó chỉ chứng
    minh phần "tôn trọng ý người gọi", còn trần thì gỡ đi vẫn xanh. Không có trần, một kho lồng
    50 cấp làm cạn stack, và đó là cách gây từ chối dịch vụ rẻ nhất có thể: một tệp vài KB.
    """
    from eide.caps.archive import GIOI_HAN
    r, ctx, _ = du_an
    p = zip_long(tmp_path / "rat_sau.zip", GIOI_HAN["depth"] + 3)
    e = r.invoke("archive.list", {"path": str(p), "depth": 99}, ctx).result["entries"]
    assert _sau_nhat(e) <= GIOI_HAN["depth"]


def test_doan_loai_theo_ten(tmp_path, du_an):
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "a.zip", {"x/a.svd": b"<device/>", "x/ds.pdf": b"%PDF",
                                     "x/note.txt": b"hi"})
    e = {x["path"]: x["kind_guess"] for x in
         r.invoke("archive.list", {"path": str(p)}, ctx).result["entries"]}
    assert e["x/a.svd"] == "svd" and e["x/ds.pdf"] == "pdf"


def test_tar_liet_ke_duoc(tmp_path, du_an):
    """m0 của hợp đồng ghi "zip/tar có" — cả hai phải chạy, không chỉ zip."""
    r, ctx, _ = du_an
    p = tmp_path / "a.tar.gz"
    with tarfile.open(p, "w:gz") as t:
        d = tmp_path / "a.svd"
        d.write_bytes(b"<device/>")
        t.add(d, arcname="pack/a.svd")
    e = r.invoke("archive.list", {"path": str(p)}, ctx).result["entries"]
    assert [x["path"] for x in e] == ["pack/a.svd"]


def test_rar_thieu_cong_cu_bao_E4001_kem_goi_y(tmp_path, du_an, monkeypatch):
    """tc: "rar cần công cụ → E4001 kèm gợi ý env.install". Báo "thiếu công cụ" mà không nói
    cài gì thì người dùng phải tự tra."""
    import eide_core.tools
    monkeypatch.setattr(eide_core.tools, "which", lambda *a, **k: None)
    r, ctx, _ = du_an
    p = tmp_path / "a.rar"
    p.write_bytes(b"Rar!\x1a\x07\x00" + b"\x00" * 64)
    run = r.invoke("archive.list", {"path": str(p)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E4001"
    assert "env install" in str(run.error) and run.error["package"] == "unrar"


def test_ti_le_nen_bat_thuong_bao_E8000(tmp_path, du_an):
    """Zip bomb: 42 KB giãn thành 4,5 PB. Ngưỡng 100:1 theo bước 2 của ARCHIVE-02."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "bom.zip", {"big": b"\x00" * (8 * 1024 * 1024)})
    run = r.invoke("archive.list", {"path": str(p)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E8000"


def test_tep_nho_ti_le_cao_khong_bi_bao_nham(tmp_path, du_an):
    """Văn bản lặp lại bình thường dễ vượt 100:1 ở kích thước nhỏ. Báo nhầm ở đây nghĩa là công
    cụ từ chối mở những kho hoàn toàn vô hại."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "ok.zip", {"a.txt": b"x" * 5000})
    assert r.invoke("archive.list", {"path": str(p)}, ctx).result["entries"]


# ---------- ARCHIVE-02 archive.unpack: ba lớp phòng thủ (TC-11, TC-SE-02)


def test_TCSE02_zip_slip_bi_chan(tmp_path, du_an):
    """Entry `../../thoat.txt` phải bị bỏ, và KHÔNG ghi ra ngoài thư mục đích."""
    r, ctx, root = du_an
    p = zip_voi(tmp_path / "ac.zip", {"../../thoat.txt": b"xin chao", "ok.txt": b"binh thuong"})
    out = r.invoke("archive.unpack", {"path": str(p)}, ctx).result
    assert len(out["files"]) == 1 and out["files"][0].endswith("ok.txt")
    assert [s["rule"] for s in out["skipped"]] == ["traversal"]
    assert not (tmp_path / "thoat.txt").exists()
    assert not (root.parent / "thoat.txt").exists()


def test_duong_dan_tuyet_doi_bi_chan(tmp_path, du_an):
    """Lọc chuỗi `../` là cách sai kinh điển — nó bỏ sót đường dẫn tuyệt đối."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "abs.zip", {"/tmp/xau.txt": b"x", "ok.txt": b"y"})
    out = r.invoke("archive.unpack", {"path": str(p)}, ctx).result
    assert [s["rule"] for s in out["skipped"]] == ["absolute"]
    assert len(out["files"]) == 1


def test_symlink_trong_zip_bi_bo(tmp_path, du_an):
    """Liên kết mềm trỏ ra `/etc`, rồi entry SAU ghi "qua" nó — đó là cách thoát sandbox mà một
    phép kiểm đường dẫn đơn thuần không bắt được, vì bản thân đường dẫn thì hợp lệ."""
    r, ctx, _ = du_an
    p = tmp_path / "sym.zip"
    with zipfile.ZipFile(p, "w") as z:
        info = zipfile.ZipInfo("link")
        info.external_attr = (0o120777 << 16)       # S_IFLNK
        z.writestr(info, "/etc/passwd")
        z.writestr("ok.txt", b"y")
    out = r.invoke("archive.unpack", {"path": str(p)}, ctx).result
    assert [s["rule"] for s in out["skipped"]] == ["symlink"]
    assert not Path(out["files"][0]).parent.joinpath("link").exists()


def test_symlink_trong_tar_bi_bo(tmp_path, du_an):
    """tar khai symlink tường minh — cùng mối đe dọa, đường khác."""
    r, ctx, _ = du_an
    p = tmp_path / "sym.tar"
    with tarfile.open(p, "w") as t:
        li = tarfile.TarInfo("link")
        li.type, li.linkname = tarfile.SYMTYPE, "/etc/passwd"
        t.addfile(li)
        d = tmp_path / "ok.txt"
        d.write_bytes(b"y")
        t.add(d, arcname="ok.txt")
    out = r.invoke("archive.unpack", {"path": str(p)}, ctx).result
    assert [s["rule"] for s in out["skipped"]] == ["symlink"]


def test_vuot_tong_dung_luong_thi_bo_phan_con_lai(tmp_path, du_an):
    """Giới hạn 2 GB theo bước 2; test hạ ngưỡng qua `limits` để chạy nhanh."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "to.zip", {f"f{i}.bin": b"x" * 1000 for i in range(5)})
    out = r.invoke("archive.unpack", {"path": str(p), "limits": {"total_bytes": 2500}},
                   ctx).result
    assert len(out["files"]) == 2
    assert all(s["rule"] == "total_bytes" for s in out["skipped"])


def test_mot_entry_doc_hai_khong_chan_ca_lo(tmp_path, du_an):
    """Bỏ qua chứ không ném: một kho 5 000 tệp có một entry độc hại vẫn còn 4 999 tệp dùng
    được, và chặn cả lô vì một entry là biến một cảnh báo thành một bức tường."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "hon_hop.zip",
                {"../thoat": b"x", **{f"tot{i}.txt": b"y" for i in range(4)}})
    out = r.invoke("archive.unpack", {"path": str(p)}, ctx).result
    assert len(out["files"]) == 4 and len(out["skipped"]) == 1


def test_skipped_noi_ro_ly_do(tmp_path, du_an):
    """Người dùng giải nén một SDK rồi thấy thiếu tệp mình cần sẽ nghĩ kho hỏng."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "a.zip", {"../x": b"1"})
    s = r.invoke("archive.unpack", {"path": str(p)}, ctx).result["skipped"][0]
    assert s["path"] == "../x" and "thoát" in s["reason"] and s["rule"] == "traversal"


def test_TC11_giai_nen_de_quy_kho_con(tmp_path, du_an):
    """Bước 3: "Giải nén đệ quy các archive con"."""
    r, ctx, _ = du_an
    p = zip_long(tmp_path / "sdk.zip", 2)
    out = r.invoke("archive.unpack", {"path": str(p)}, ctx).result
    assert any(f.endswith("day.svd") for f in out["files"]), out["files"]


def test_giai_nen_dung_o_do_sau_gioi_han(tmp_path, du_an):
    """Cùng lỗ hổng test như trên, ở phía `unpack`: bản đầu tôi chỉ giải nén 2 cấp — dưới ngưỡng
    — nên phép chặn độ sâu gỡ đi vẫn xanh. Zip lồng sâu là zip bomb dạng khác: mỗi cấp nhân đôi
    công việc, và cái tốn không phải đĩa mà là ngăn xếp."""
    r, ctx, _ = du_an
    p = zip_long(tmp_path / "sau.zip", 3)     # ngoài → muc2.zip → muc1.zip → day.svd
    out = r.invoke("archive.unpack", {"path": str(p), "limits": {"depth": 1}}, ctx).result
    assert not any(f.endswith("day.svd") for f in out["files"]), out["files"]
    assert any(s["rule"] == "depth" for s in out["skipped"]), out["skipped"]


def test_members_loc_dung_tep_can(tmp_path, du_an):
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "a.zip", {"x/a.svd": b"<device/>", "x/b.pdf": b"%PDF",
                                     "y/c.svd": b"<device/>"})
    out = r.invoke("archive.unpack", {"path": str(p), "members": ["**/*.svd", "*/*.svd"]},
                   ctx).result
    assert len(out["files"]) == 2 and all(f.endswith(".svd") for f in out["files"])


def test_cung_kho_giai_hai_lan_ra_cung_cho(tmp_path, du_an):
    """Băm nội dung làm tên thư mục: không sinh ra ba bản sao của một SDK 800 MB."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "a.zip", {"a.txt": b"x"})
    a = r.invoke("archive.unpack", {"path": str(p)}, ctx).result["files"]
    b = r.invoke("archive.unpack", {"path": str(p)}, ctx).result["files"]
    assert a == b


def test_unpack_dang_ky_undo(tmp_path, du_an):
    """Hợp đồng khai `undo: delete_created_files`. Không đăng ký thì người dùng không hoàn tác
    được một thao tác vừa đổ vài nghìn tệp lên đĩa."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "a.zip", {"a.txt": b"x"})
    r.invoke("archive.unpack", {"path": str(p)}, ctx)
    assert [x for x in r.ledger.records() if x["kind"] == "undo.register"]


# ---------- MEMORY-05 memory.ledger


def test_kind_la_bao_E1000_khong_phai_E6001(du_an):
    """Hợp đồng khai E1000. `Ledger.append` ném E6001 SCHEMA_VIOLATION, nhưng người GỌI truyền
    sai `kind` là đối số không hợp lệ — E6001 khiến người ta đi kiểm sổ cái thay vì kiểm lời gọi
    của mình."""
    r, ctx, _ = du_an
    run = r.invoke("memory.ledger", {"kind": "khong.co.loai.nay", "data": {}}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_kind_gan_giong_thi_goi_y(du_an):
    r, ctx, _ = du_an
    run = r.invoke("memory.ledger", {"kind": "store.khong_co", "data": {}}, ctx)
    assert "store.write" in str(run.error) or "store.migrate" in str(run.error)


def test_chuoi_hash_lien_tuc(du_an):
    """tc: "Chuỗi hash liên tục". Sổ cái là bất biến nền của cả hệ (SEC-25) — chỉ được có MỘT
    chỗ nối mắt xích, nếu không `ledger.verify()` không thấy đứt gãy ở chuỗi nó không biết."""
    r, ctx, _ = du_an
    h1 = r.invoke("memory.ledger", {"kind": "intent", "data": {"a": 1}}, ctx).result["hash"]
    h2 = r.invoke("memory.ledger", {"kind": "intent", "data": {"a": 2}}, ctx).result["hash"]
    assert h1 != h2
    assert r.ledger.verify() == (True, 0)


def test_regex_khoa_bi_che(du_an):
    """tc: "regex khóa bị che". Che TRƯỚC khi băm — che sau thì khóa thật đã nằm trong chuỗi
    băm và không gỡ ra được nữa."""
    r, ctx, _ = du_an
    r.invoke("memory.ledger",
             {"kind": "intent", "data": {"note": "khóa sk-abcdefghijklmnop123456"}}, ctx)
    t = "".join(str(x) for x in r.ledger.records())
    assert "sk-abcdefghijklmnop123456" not in t
    assert "đã che" in t


# ---------- PROJECT-02 project.set_target


def test_ghim_chip_va_suy_ISA(du_an):
    """tc: "Ghim st.stm32f411ce@x; constraints.yaml cập nhật". ISA suy từ `family_patterns`
    trong `docs/spec/isa/*.yaml`, KHÔNG từ một bảng chép lại trong Python."""
    import yaml
    r, ctx, root = du_an
    out = r.invoke("project.set_target", {"chip": "STM32F411CE"}, ctx).result
    assert out["pins"]["isa"] == "armv7e-m"
    c = yaml.safe_load((root / ".eide" / "constraints.yaml").read_text(encoding="utf-8"))
    assert c["target"]["isa"] == "armv7e-m"
    assert c["target"]["pins"]["chip"].startswith("STM32F411CE@")


def test_chip_AVR_suy_dung_avr8(du_an):
    """Bảng ISA là dữ liệu: thêm `avr8.yaml` là đủ, không sửa mã. Test này chứng minh điều ấy
    thực sự đúng cho ISA thứ hai."""
    r, ctx, _ = du_an
    assert r.invoke("project.set_target", {"chip": "ATmega328P"},
                    ctx).result["pins"]["isa"] == "avr8"


def test_chip_la_vao_missing_chu_khong_nem(du_an):
    """tc: "chip lạ → missing". Hợp đồng khai `missing` như một trường bình thường; dự án vẫn
    lập kế hoạch được trong lúc chờ tài liệu về."""
    r, ctx, _ = du_an
    out = r.invoke("project.set_target", {"chip": "CHIP_KHONG_TON_TAI_99"}, ctx).result
    assert out["missing"]
    assert out["pins"]["chip"] == "CHIP_KHONG_TON_TAI_99@?"


def test_ghim_ban_da_co_trong_store(du_an):
    """Ghim PHIÊN BẢN hộ chiếu, không chỉ tên chip: `chip: stm32f411` nói dùng chip gì, còn
    `st.stm32f411ce@1.2.0` nói dùng BẢN MÔ TẢ NÀO — không ghim thì mã sinh tháng trước không
    tái lập được."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO passport (id, kind, header, created_at) VALUES "
                  "('st.stm32f411ce@1.2.0','chip','{}','2026-01-01T00:00:00Z')")
        c.commit()
    out = r.invoke("project.set_target", {"chip": "st.stm32f411ce"}, ctx).result
    assert out["pins"]["chip"] == "st.stm32f411ce@1.2.0"
    assert not [m for m in out["missing"] if "hộ chiếu cho" in m]


def test_khong_co_chip_lan_board_thi_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("project.set_target", {}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- REGISTRY-01 registry.seed (TC-42)


SVD_NHO = b"""<?xml version="1.0"?>
<device><vendor>%s</vendor><name>%s</name><peripherals>
<peripheral><name>P1</name><baseAddress>0x40000000</baseAddress></peripheral>
</peripherals></device>"""


def _kho_svd(d: Path, hang_va_chip: dict[str, list[str]]) -> Path:
    for hang, chips in hang_va_chip.items():
        (d / "data" / hang).mkdir(parents=True, exist_ok=True)
        for ch in chips:
            (d / "data" / hang / f"{ch}.svd").write_bytes(
                SVD_NHO % (hang.encode(), ch.encode()))
    return d


def test_TC42_seed_nap_nhieu_hang(tmp_path, du_an):
    r, ctx, root = du_an
    d = _kho_svd(tmp_path / "cmsis", {"ST": ["a", "b"], "Nordic": ["c"], "Atmel": ["d"]})
    rep = r.invoke("registry.seed", {"dir": str(d)}, ctx).result["report"]
    assert rep["n_ok"] == 4 and rep["n_fail"] == 0
    assert set(rep["per_vendor"]) == {"ST", "Nordic", "Atmel"}
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM passport").fetchone()[0] == 4


def test_round_robin_xen_ke_theo_hang(tmp_path):
    """Bước 1: "round-robin theo hãng". Nạp tuần tự nghĩa là dừng giữa chừng thì có 400 hộ
    chiếu ST và KHÔNG cái nào của Nordic. Xen kẽ thì dừng ở đâu cũng còn tập đại diện."""
    from eide.caps.registry import _xen_ke
    ds = _xen_ke({"ST": [(Path("s1"), "svd"), (Path("s2"), "svd"), (Path("s3"), "svd")],
                  "Nordic": [(Path("n1"), "svd")]})
    assert [h for h, _, _ in ds][:2] == ["Nordic", "ST"]
    assert "Nordic" in [h for h, _, _ in ds[:2]], "hãng ít tệp phải xuất hiện sớm"


def test_mot_tep_hong_khong_dung_ca_lo(tmp_path, du_an):
    """Bộ `cmsis-svd-data` có vài chục tệp sai cú pháp; dừng ở tệp thứ 12 nghĩa là 600 hộ chiếu
    còn lại không bao giờ được nạp vì một tệp người dùng chẳng cần."""
    r, ctx, _ = du_an
    d = _kho_svd(tmp_path / "cmsis", {"ST": ["a"], "Nordic": ["c"]})
    (d / "data" / "ST" / "hong.svd").write_bytes(b"<device><peripherals>")
    rep = r.invoke("registry.seed", {"dir": str(d)}, ctx).result["report"]
    assert rep["n_ok"] == 2 and rep["n_fail"] == 1
    assert rep["per_vendor"]["ST"]["errors"][0]["file"] == "hong.svd"


def test_per_vendor_noi_hang_nao_hong(tmp_path, du_an):
    """"n_fail: 37" thì không nói được gì; người chạy seed cần biết hãng nào hỏng."""
    r, ctx, _ = du_an
    d = _kho_svd(tmp_path / "cmsis", {"ST": ["a"], "Nordic": ["c"]})
    (d / "data" / "Nordic" / "x.svd").write_bytes(b"khong phai xml")
    rep = r.invoke("registry.seed", {"dir": str(d)}, ctx).result["report"]
    assert rep["per_vendor"]["Nordic"]["fail"] == 1
    assert rep["per_vendor"]["ST"]["fail"] == 0


def test_thu_muc_rong_bao_E2000(tmp_path, du_an):
    r, ctx, _ = du_an
    d = tmp_path / "rong"
    d.mkdir()
    run = r.invoke("registry.seed", {"dir": str(d)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_kinds_loc_dung_loai(tmp_path, du_an):
    r, ctx, _ = du_an
    d = _kho_svd(tmp_path / "cmsis", {"ST": ["a"]})
    (d / "data" / "ST" / "b.atdf").write_bytes(b"<avr-tools-device-file/>")
    rep = r.invoke("registry.seed", {"dir": str(d), "kinds": ["svd"]}, ctx).result["report"]
    assert rep["n_ok"] == 1 and rep["n_fail"] == 0


# ---------- mốc M0 đã đóng


def test_moc_M0_khong_con_nang_luc_nao_chua_hien_thuc():
    """Đây là bất biến của cả sprint, không phải của một năng lực. Viết thành test để lần sau
    ai đó thêm một mục M0 mới vào spec thì biết ngay là còn nợ, thay vì phải nhớ đi đếm."""
    from eide_core.registry import get_registry
    con = sorted(c.spec.id for c in get_registry().list()
                 if c.spec.milestone == "M0" and not c.implemented)
    assert con == [], f"còn {len(con)} năng lực M0 chưa hiện thực: {con}"


# ---------- ARCHIVE-03 extract_one · ARCHIVE-04 query (mốc M1)


def zip_long_co_svd(p: Path) -> Path:
    """SDK giả: `sdk.zip` → `pack/inner.zip` → `svd/stm32f411.svd` + một tệp header.

    Dựng đúng hình dạng gây khó: thứ cần tìm nằm ở TẦNG TRONG. Đó là tc của ARCHIVE-04 —
    "tìm thấy trong header nằm trong zip con".
    """
    trong = io.BytesIO()
    with zipfile.ZipFile(trong, "w") as z:
        z.writestr("svd/stm32f411.svd", b"<device><name>STM32F411</name></device>")
        z.writestr("inc/stm32f4xx.h", b"#define I2C_CR1 0x40005400\n#define SPI_CR1 0x40013000\n")
        z.writestr("doc/readme.txt", b"khong lien quan")
    with zipfile.ZipFile(p, "w") as z:
        z.writestr("pack/inner.zip", trong.getvalue())
        z.writestr("top.txt", b"tep o tang ngoai")
    return p


def test_lay_dung_tep_khong_giai_nen_phan_con_lai(tmp_path, du_an):
    """tc ARCHIVE-03 nguyên văn. Một SDK vendor là zip 800 MB chứa đúng một tệp SVD cần dùng;
    `unpack` trả 800 MB lên đĩa, còn đây trả một tệp. Đó là khác biệt giữa "dùng được trên máy
    xách tay" và "không"."""
    r, ctx, root = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    f = r.invoke("archive.extract_one",
                 {"path": str(p), "member": "**/stm32f411.svd"}, ctx).result["file"]
    assert Path(f).read_bytes().startswith(b"<device>")
    # Thư mục cách ly chỉ được có ĐÚNG tệp ấy — không có readme, không có header.
    d = Path(f).parent
    while d.name != "unpacked" and d.parent != d:
        goc = d
        d = d.parent
    ra = [x for x in goc.rglob("*") if x.is_file()]
    assert len(ra) == 1, [str(x.relative_to(goc)) for x in ra]


def test_glob_tim_qua_zip_long(tmp_path, du_an):
    """SDK hãng hay đóng gói zip trong zip. Tìm một tầng thì trả rỗng — mà "không tìm thấy"
    không phân biệt được với "không có", nên người dùng kết luận sai rằng SDK thiếu tệp."""
    r, ctx, _ = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    f = r.invoke("archive.extract_one", {"path": str(p), "member": "stm32f4xx.h"},
                 ctx).result["file"]
    assert b"I2C_CR1" in Path(f).read_bytes()


def test_member_khong_co_thi_E2000_kem_goi_y(tmp_path, du_an):
    """`exists` liệt kê mục CÓ THẬT: người gõ sai tên cần thấy danh sách, không phải một câu
    "không tìm thấy"."""
    r, ctx, _ = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    run = r.invoke("archive.extract_one", {"path": str(p), "member": "**/khong_co.svd"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"
    assert run.error["exists"], "phải liệt kê mục có thật để người dùng đối chiếu"


def test_extract_one_van_chan_zip_slip(tmp_path, du_an):
    """Một đường ghi thứ hai vào đĩa mà bỏ qua phép chặn thì cả tám lớp phòng thủ kia thành
    trang trí."""
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "ac.zip", {"../../thoat.txt": b"x"})
    run = r.invoke("archive.extract_one", {"path": str(p), "member": "*thoat.txt"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E8000"
    assert not (tmp_path / "thoat.txt").exists()


def test_extract_one_dang_ky_undo(tmp_path, du_an):
    r, ctx, _ = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    r.invoke("archive.extract_one", {"path": str(p), "member": "**/*.svd"}, ctx)
    assert [x for x in r.ledger.records()
            if x["kind"] == "undo.register" and "extract_one" in str(x["data"])]


def test_query_theo_ten(tmp_path, du_an):
    r, ctx, _ = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    m = r.invoke("archive.query", {"path": str(p), "pattern": "*.svd", "mode": "name"},
                 ctx).result["matches"]
    assert [x["path"] for x in m] == ["pack/inner.zip!svd/stm32f411.svd"]
    assert m[0]["depth"] == 1


def test_TC_query_content_tim_thay_trong_zip_con(tmp_path, du_an):
    """tc ARCHIVE-04 nguyên văn: "Tìm thấy trong header nằm trong zip con"."""
    r, ctx, _ = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    m = r.invoke("archive.query", {"path": str(p), "pattern": "I2C_CR1", "mode": "content"},
                 ctx).result["matches"]
    assert m, "không tìm thấy trong zip con"
    assert m[0]["path"].endswith("!inc/stm32f4xx.h")
    assert m[0]["line"] == 1 and "0x40005400" in m[0]["text"]


def test_query_signature_doc_512_byte_dau(tmp_path, du_an):
    r, ctx, _ = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    m = r.invoke("archive.query", {"path": str(p), "pattern": "<device>", "mode": "signature"},
                 ctx).result["matches"]
    assert [x["path"] for x in m] == ["pack/inner.zip!svd/stm32f411.svd"]
    assert m[0]["kind_guess"] == "svd"


def test_query_vuot_200MB_thi_NOI_RO_la_chua_du(tmp_path, du_an, monkeypatch):
    """Trả một danh sách cụt mà im lặng là tệ hơn: bên gọi tưởng đã quét hết.

    Grep cả một SDK 800 MB là đọc giải nén toàn bộ — đúng việc mà cả nhóm `archive.*` sinh ra
    để tránh.
    """
    import eide.caps.archive as m
    monkeypatch.setattr(m, "TRAN_GREP", 2048)
    r, ctx, _ = du_an
    p = zip_voi(tmp_path / "to.zip", {f"f{i}.txt": b"noi dung " * 200 for i in range(6)})
    kq = r.invoke("archive.query", {"path": str(p), "pattern": "noi dung", "mode": "content"},
                  ctx).result["matches"]
    cut = [x for x in kq if x.get("truncated")]
    assert cut, "phải báo rõ là đã dừng giữa chừng"
    assert "CHƯA đủ" in cut[0]["note"]


def test_query_khong_tim_thay_thi_rong(tmp_path, du_an):
    r, ctx, _ = du_an
    p = zip_long_co_svd(tmp_path / "sdk.zip")
    assert r.invoke("archive.query", {"path": str(p), "pattern": "xyzzy", "mode": "content"},
                    ctx).result["matches"] == []
