"""Nhóm search.* — CDS-12.2; TGT-19 §8; POL-17 cổng G-SRC; SEC-25 §4.

Đây là lần đầu cổng G-SRC có việc: tám quy tắc của nó nằm trong `rules.yaml` từ Sprint 1 mà
chưa quy tắc nào từng chạy, vì mọi fact tới giờ đều đến từ tệp cục bộ.

**Không test nào gọi mạng thật.** `search.vendor` bị chặn `_head`; `search.fetch` tải từ một máy
chủ HTTP dựng trong tiến trình. Bộ test phải chạy được ngoại tuyến — một test phụ thuộc mạng là
một test sẽ đỏ vì lý do chẳng liên quan gì tới mã, và người ta sẽ học cách bỏ qua nó.
"""
from __future__ import annotations

import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest

from eide.caps.search import (
    _domain_tin_cay,
    _nhan_dien_license,
    _ten_tep,
    bang_hang,
    dac_trung_nguon,
)
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án tìm kiếm"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


@pytest.fixture
def khong_mang(monkeypatch):
    """Chặn HEAD: `search.vendor` phải trả ứng viên kể cả khi không hỏi được máy chủ."""
    import eide.caps.search as m
    monkeypatch.setattr(m, "_head", lambda uri: {"size_est": None, "content_type": None,
                                                 "reachable": False})


class _Handler(BaseHTTPRequestHandler):
    NOI_DUNG: dict[str, bytes] = {}
    PHUONG_THUC: list[str] = []          # ghi lại HEAD/GET để kiểm ở mức giao thức

    def _gui(self, than: bytes | None) -> None:
        if self.path not in self.NOI_DUNG:
            self.send_error(404)
            return
        d = self.NOI_DUNG[self.path]
        self.send_response(200)
        self.send_header("Content-Length", str(len(d)))
        self.send_header("Content-Type", "application/octet-stream")
        self.end_headers()
        if than is not None:
            self.wfile.write(d)

    def do_GET(self):       # noqa: N802
        self.PHUONG_THUC.append("GET")
        self._gui(b"")

    def do_HEAD(self):      # noqa: N802
        self.PHUONG_THUC.append("HEAD")
        self._gui(None)

    def log_message(self, *a):
        pass


@pytest.fixture
def may_chu():
    """Máy chủ HTTP trong tiến trình. Trả (base_url, dict nội dung) để test tự nạp."""
    _Handler.NOI_DUNG = {}
    _Handler.PHUONG_THUC = []
    srv = HTTPServer(("127.0.0.1", 0), _Handler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    yield f"http://127.0.0.1:{srv.server_port}", _Handler.NOI_DUNG
    srv.shutdown()


# ---------- bảng nguồn hãng sinh từ TGT-19 §8


def test_bang_hang_doc_tu_spec_khong_khai_trong_python():
    """Bài học DEV-043/DEV-046 đã ghi hai lần: bảng in trong tài liệu mà chép tay sang Python
    thì hai bản trôi khỏi nhau ngay lần hãng đổi đường dẫn."""
    ds = bang_hang()
    assert len(ds) >= 8
    assert {v["id"] for v in ds} >= {"st", "microchip", "nordic", "espressif", "bosch"}
    assert all(v.get("urls") for v in ds if v["id"] != "community")


def test_moi_hang_deu_co_tien_to_khop_duoc():
    """Một hãng khai `prefixes` mà không mẫu nào khớp mã thật là một hàng chết trong bảng."""
    import re
    mau = {"st": "STM32F411CE", "microchip": "ATmega328P", "nordic": "nRF52840",
           "espressif": "ESP32C3", "raspberrypi": "RP2040", "bosch": "BME280",
           "invensense": "MPU6050", "allegro": "A4988"}
    for v in bang_hang():
        if v["id"] in mau:
            assert any(re.match(p, mau[v["id"]], re.I) for p in v["prefixes"]), v["id"]


# ---------- SEARCH-02 search.vendor


def test_vendor_suy_URL_tu_ma_linh_kien(du_an, khong_mang):
    r, ctx, _ = du_an
    ds = r.invoke("search.vendor", {"part": "STM32F411CE"}, ctx).result["candidates"]
    assert ds
    assert all(c["vendor"] == "st" for c in ds)
    assert any(c["kind"] == "svd" and c["tier_expected"] == "gold" for c in ds)
    assert any(c["kind"] == "pdf" and c["tier_expected"] == "silver" for c in ds)


def test_vendor_giu_ca_hai_kieu_chu(du_an, khong_mang):
    """ST dùng chữ thường trong đường dẫn PDF nhưng chữ hoa trong tên tệp SVD. Chuẩn hóa về một
    kiểu sẽ làm hỏng một nửa số mẫu, và triệu chứng là 404 — trông y hệt "hãng bỏ tài liệu"."""
    r, ctx, _ = du_an
    uris = [c["uri"] for c in
            r.invoke("search.vendor", {"part": "STM32F411CE"}, ctx).result["candidates"]]
    assert any("STM32F411CE" in u for u in uris), "thiếu biến thể chữ hoa"
    assert any("stm32f411ce" in u for u in uris), "thiếu biến thể chữ thường"


def test_vendor_cam_bien_khong_phai_vi_dieu_khien(du_an, khong_mang):
    """BME280/MPU6050/A4988 là những linh kiện tài liệu nêu đích danh, và chúng CHỈ có PDF —
    không có SVD/ATDF. Đây là lý do `extract.pdf_layout` là việc tiếp theo."""
    r, ctx, _ = du_an
    for part, hang in (("BME280", "bosch"), ("MPU6050", "invensense"), ("A4988", "allegro")):
        ds = r.invoke("search.vendor", {"part": part}, ctx).result["candidates"]
        assert ds and {c["vendor"] for c in ds} == {hang}, part
        assert all(c["kind"] == "pdf" for c in ds), part


def test_vendor_truyen_giay_phep_tu_bang(du_an, khong_mang):
    """Giấy phép lấy từ BẢNG chứ không suy từ tầng: cmsis-svd-data là Apache-2.0, tài liệu hãng
    là vendor-doc — hai thứ khác nhau.

    Đây là test tôi thiếu ở lượt đầu: helper `_ung_vien` tự gán `license_hint`, nên gỡ hẳn phần
    đọc giấy phép khỏi `search.vendor` mà bộ test vẫn xanh. Không có trường này thì mọi tải về
    tầng vàng đều rơi vào G-SRC-05 (ASK) — người dùng bấm duyệt ở đúng đường phổ biến nhất, rồi
    học cách bấm bừa.
    """
    r, ctx, _ = du_an
    ds = r.invoke("search.vendor", {"part": "STM32F411CE"}, ctx).result["candidates"]
    assert all(c["license_hint"] for c in ds), "ứng viên thiếu giấy phép"
    theo_kind = {c["kind"]: c["license_hint"] for c in ds}
    assert theo_kind["svd"] == "Apache-2.0"
    assert theo_kind["pdf"] == "vendor-doc"


def test_giay_phep_tu_vendor_du_qua_cong(du_an, khong_mang):
    """Hệ quả cuối: ứng viên do `search.vendor` sinh ra phải đủ đặc trưng để G-SRC-01 duyệt được
    khi tên miền nằm trong danh sách trắng — không phải đi vòng qua người."""
    from eide.caps.search import dac_trung_nguon
    r, ctx, _ = du_an
    c = next(x for x in r.invoke("search.vendor", {"part": "STM32F411CE"},
                                 ctx).result["candidates"] if x["kind"] == "pdf")
    c["size_est"] = 1024
    for g in (r.gate, ctx.extra["gate"]):
        g.config = {**(g.config or {}),
                    "trusted_sources": [*(g.config.get("trusted_sources") or []), "st.com"]}
    d = r.gate.decide("G-SRC", dac_trung_nguon(c), risk="R1", tier="T1", actor="agent")
    assert d.decision == "APPROVE" and d.rule_id == "G-SRC-01", (d.decision, d.rule_id, d.reason)


def test_vendor_ma_la_tra_rong_chu_khong_nem(du_an, khong_mang):
    """Mã không thuộc hãng nào là chuyện thường (linh kiện lạ, gõ sai). Rỗng là câu trả lời
    đúng; ném lỗi thì Orchestrator phải bắt ngoại lệ cho một tình huống bình thường."""
    r, ctx, _ = du_an
    assert r.invoke("search.vendor", {"part": "ZZZ9999"}, ctx).result["candidates"] == []


def test_vendor_khong_goi_duoc_mang_van_tra_ung_vien(du_an, khong_mang):
    """Danh sách URL suy từ mã linh kiện có ích cả khi ngoại tuyến — người dùng chép được đường
    dẫn và tự tải."""
    r, ctx, _ = du_an
    ds = r.invoke("search.vendor", {"part": "nRF52840"}, ctx).result["candidates"]
    assert ds and all(c["size_est"] is None and c["reachable"] is False for c in ds)


def test_vendor_dung_HEAD_chu_khong_GET(du_an, may_chu, monkeypatch):
    """Bước 2: "HEAD để lấy kích thước; KHÔNG tải".

    Kiểm ở mức giao thức, không kiểm bằng cách đọc mã: nếu năng lực này GET thì mỗi lần "xem có
    gì" là một lần tải 40 MB, và cổng G-SRC mất chỗ đứng vì không còn bước riêng để chặn.
    """
    base, noi = may_chu
    noi["/x.svd"] = b"A" * 4096
    _Handler.PHUONG_THUC.clear()

    import eide.caps.search as m
    monkeypatch.setattr(m, "bang_hang", lambda: [
        {"id": "test", "name": "Test", "prefixes": ["^TT"], "domains": ["127.0.0.1"],
         "urls": [{"kind": "svd", "tier": "gold", "template": base + "/x.svd"}]}])
    r, ctx, _ = du_an
    ds = r.invoke("search.vendor", {"part": "TT123"}, ctx).result["candidates"]
    assert ds[0]["size_est"] == 4096, "HEAD phải lấy được Content-Length"
    assert set(_Handler.PHUONG_THUC) == {"HEAD"}, f"đã gọi {_Handler.PHUONG_THUC}"


# ---------- SEARCH-05 search.rank


def _uv(**kw):
    return {"uri": "https://x/y.svd", "kind": "svd", "domain": "x", "tier_expected": "bronze",
            **kw}


def test_diem_theo_dung_cong_thuc_buoc_1(du_an):
    """"tier (gold 3) + domain tin cậy (+2) + hash (+2) + license (+1) + khớp mã (+2)" = 10."""
    r, ctx, _ = du_an
    c = _uv(tier_expected="gold", domain="www.st.com", sha256="a" * 64, license="MIT",
            uri="https://www.st.com/stm32f411ce.svd")
    out = r.invoke("search.rank", {"candidates": [c], "part": "STM32F411CE"},
                   ctx).result["ranked"]
    assert out[0]["score"] == 10.0
    assert len(out[0]["reasons"]) == 5


def test_xep_hang_giam_dan(du_an):
    r, ctx, _ = du_an
    out = r.invoke("search.rank", {"candidates": [
        _uv(tier_expected="bronze"), _uv(tier_expected="gold"), _uv(tier_expected="silver")]},
        ctx).result["ranked"]
    assert [c["tier_expected"] for c in out] == ["gold", "silver", "bronze"]


def test_reasons_noi_ro_tung_diem(du_an):
    """Bảng xếp hạng chỉ có điểm thì khi nó chọn sai, người dùng không biết sửa gì."""
    r, ctx, _ = du_an
    out = r.invoke("search.rank", {"candidates": [_uv(domain="st.com")]}, ctx).result["ranked"]
    assert any("tên miền tin cậy" in x for x in out[0]["reasons"])


@pytest.mark.parametrize(("domain", "tin"), [
    ("st.com", True),
    ("www.st.com", True),
    ("raw.githubusercontent.com", False),      # không nằm trong trusted_sources mặc định
    ("github.com", True),
    ("evil-st.com", False),                    # hậu tố ngây thơ sẽ nhận nhầm cái này
    ("st.com.evil.net", False),
    ("notst.com", False),
])
def test_hau_to_ten_mien_chan_o_bien_dau_cham(domain, tin):
    """So bằng thì `www.st.com` trượt và mọi tải về rơi vào G-SRC-99 (ASK) — người dùng bấm
    duyệt liên tục rồi thôi đọc. Nhưng hậu tố ngây thơ thì `evil-st.com` khớp `st.com`: lỗ hổng
    kinh điển. Phải là `== t` hoặc `endswith("." + t)`."""
    assert _domain_tin_cay(domain, ["st.com", "github.com/cmsis-svd"]) is tin


# ---------- SEARCH-06 search.fetch: cổng G-SRC lần đầu chạy


def _ung_vien(base, ten="/a.svd", **kw):
    return {"uri": base + ten, "kind": "svd", "domain": "127.0.0.1", "size_est": 100,
            "tier_expected": "gold", "license_hint": "Apache-2.0", **kw}


def test_ten_mien_la_thi_G_SRC_hoi_nguoi(du_an, may_chu):
    """`127.0.0.1` không nằm trong `trusted_sources`, nên rơi vào G-SRC-99 (ASK) → E3000.
    Đây chính là quy tắc chưa từng chạy trước nhóm này."""
    base, noi = may_chu
    noi["/a.svd"] = b"<device/>"
    r, ctx, _ = du_an
    c = _ung_vien(base)
    run = r.invoke("search.fetch", {"candidate": c}, ctx, features=dac_trung_nguon(c))
    assert run.status == "pending", "ASH ở G-SRC phải vào hàng đợi, không phải ném lỗi"
    assert run.decision["gate"] == "G-SRC"
    assert run.decision["rule"].startswith("G-SRC")


def _cho_phep(r, ctx, base):
    """Thêm 127.0.0.1 vào trusted_sources — mô phỏng danh sách trắng đã ký.

    Sửa CẢ `r.gate` lẫn `ctx.extra["gate"]`: Router gác cổng bằng `self.gate`, còn năng lực đọc
    ngưỡng từ `ctx.extra["gate"]`. Hai đối tượng khác nhau, và bản đầu tôi chỉ sửa cái thứ hai
    nên cổng vẫn từ chối — một tiếng đồng hồ đi tìm lỗi ở chỗ không có lỗi.
    """
    for g in (r.gate, ctx.extra["gate"]):
        g.config = {**(g.config or {}),
                    "trusted_sources": [*(g.config.get("trusted_sources") or []), "127.0.0.1"]}
    return ctx.extra["gate"]


def test_khong_tai_gi_khi_cong_tu_choi(du_an, may_chu):
    """Điểm chính của nhóm: hỏi cổng TRƯỚC khi tải. Tải rồi mới hỏi thì byte đã qua mạng, đã
    nằm trên đĩa, và câu trả lời "không được phép" đến sau khi việc cần ngăn đã xảy ra."""
    base, noi = may_chu
    noi["/a.svd"] = b"<device/>"
    r, ctx, root = du_an
    r.invoke("search.fetch", {"candidate": (c := _ung_vien(base))}, ctx,
                     features=dac_trung_nguon(c))
    cache = root / ".eide" / "cache" / "downloads"
    assert not cache.exists() or list(cache.iterdir()) == []


def test_tai_duoc_khi_cong_duyet_va_ghi_source(du_an, may_chu):
    import hashlib
    base, noi = may_chu
    noi["/a.svd"] = b"<device><name>X</name></device>"
    r, ctx, root = du_an
    _cho_phep(r, ctx, base)
    out = r.invoke("search.fetch", {"candidate": (c := _ung_vien(base))}, ctx,
                     features=dac_trung_nguon(c)).result
    assert out["sha256"] == hashlib.sha256(noi["/a.svd"]).hexdigest()
    assert out["size_bytes"] == len(noi["/a.svd"])
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM source WHERE id=?",
                         (out["source_id"],)).fetchone()[0] == 1


def test_bam_lech_thi_xoa_tep_va_bao_E3001(du_an, may_chu):
    """Giữ lại "để người xem" nghe hợp lý nhưng sai: một tệp không đúng băm là tệp không rõ
    nguồn gốc, và để nó trong cache là mời bước sau nhặt nhầm."""
    base, noi = may_chu
    noi["/a.svd"] = b"noi dung that"
    r, ctx, root = du_an
    _cho_phep(r, ctx, base)
    c = _ung_vien(base, expected_hash="b" * 64)
    run = r.invoke("search.fetch", {"candidate": c}, ctx, features=dac_trung_nguon(c))
    assert run.status == "failed" and run.error["eide_code"] == "E3001"
    cache = root / ".eide" / "cache" / "downloads"
    assert not cache.exists() or list(cache.iterdir()) == []


def test_may_chu_gui_nhieu_hon_khai_thi_dung_giua_chung(du_an, may_chu, monkeypatch):
    """Máy chủ khai 1 MB rồi gửi 4 GB là chuyện có thật, và cổng đã quyết dựa trên con số khai
    ấy. Phải đếm byte THỰC trong lúc tải — đây là chỗ duy nhất biết sự thật."""
    base, noi = may_chu
    noi["/to.bin"] = b"x" * (3 * 1024 * 1024)
    r, ctx, root = du_an
    _cho_phep(r, ctx, base)
    for g in (r.gate, ctx.extra["gate"]):
        g.config = {**g.config, "thresholds": {**(g.config.get("thresholds") or {}),
                                               "download_max_mb": 1}}
    c = _ung_vien(base, "/to.bin", size_est=100)
    run = r.invoke("search.fetch", {"candidate": c}, ctx, features=dac_trung_nguon(c))
    assert run.status == "failed" and run.error["eide_code"] == "E8001"
    cache = root / ".eide" / "cache" / "downloads"
    assert not cache.exists() or list(cache.iterdir()) == []


def test_khong_tai_duoc_bao_E4004(du_an, may_chu):
    base, _ = may_chu
    r, ctx, _ = du_an
    _cho_phep(r, ctx, base)
    c = _ung_vien(base, "/khong_co.svd")
    run = r.invoke("search.fetch", {"candidate": c}, ctx, features=dac_trung_nguon(c))
    assert run.status == "failed" and run.error["eide_code"] == "E4004"


def test_fetch_ghi_ledger(du_an, may_chu):
    """API-15 §5 khai một bảng ĐÓNG các loại sự kiện, và `Ledger.append` từ chối loại lạ. Bản
    đầu tôi dùng `source.add` — nghe hợp lý, không có trong bảng, và E6001 bắt ngay."""
    base, noi = may_chu
    noi["/a.svd"] = b"<device/>"
    r, ctx, _ = du_an
    _cho_phep(r, ctx, base)
    r.invoke("search.fetch", {"candidate": (c := _ung_vien(base))}, ctx,
                     features=dac_trung_nguon(c))
    recs = [x for x in r.ledger.records()
            if x["kind"] == "store.write" and "search.fetch" in x["data"].get("reason", "")]
    assert recs, "search.fetch phải ghi ledger"
    assert r.ledger.verify() == (True, 0)


def test_ten_tep_cache_khong_thoat_thu_muc():
    """Một máy chủ ác ý trả đường dẫn có `/` hay `..` là ghi ra ngoài cache — cùng lỗ hổng
    zip-slip, đường khác."""
    for uri in ("http://x/../../etc/passwd", "http://x/a/b/../../../c",
                "http://x/" + "a" * 500):
        ten = _ten_tep(uri)
        assert "/" not in ten and ".." not in ten and len(ten) < 140


@pytest.mark.parametrize(("noi_dung", "lic"), [
    (b"Apache License, Version 2.0", "Apache-2.0"),
    (b"The MIT License (MIT)", "MIT"),
    (b"Creative Commons Attribution 4.0 International", "CC-BY-4.0"),
    (b"khong co giay phep nao o day", None),
])
def test_nhan_dien_license(tmp_path, noi_dung, lic):
    """SEC-25 §4. Không thấy thì trả None chứ không đoán: `None` chảy về `unknown`, và `unknown`
    rơi vào G-SRC-05 (ASK) — tức người xem. Đoán sai thì nguồn ấy được tự duyệt, mà giấy phép là
    thứ không sửa lại được sau khi đã phát tán tài liệu kèm sản phẩm."""
    f = tmp_path / "a.txt"
    f.write_bytes(noi_dung)
    assert _nhan_dien_license(f) == lic


# ---------- SEARCH-07 search.verify_match


def _them_source(root, sid, uri, cache=None):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier, meta) "
                  "VALUES (?,?,?,'pdf','silver',?)",
                  (sid, uri, sid, json.dumps({"cache": str(cache)} if cache else {})))
        c.commit()


def test_ma_khong_co_trong_URI_thi_diem_thap(du_an):
    """Mẫu URL của ST cho STM32F411 và STM32F401 chỉ khác một ký tự. Tải nhầm thì mọi fact trích
    ra đều đúng định dạng, đúng tầng vàng, và SAI CHIP — không gì ở phía sau bắt được."""
    r, ctx, root = du_an
    _them_source(root, "s_1", "https://st.com/stm32f401.pdf")
    out = r.invoke("search.verify_match", {"source_id": "s_1", "part": "STM32F411"}, ctx).result
    assert out["match_score"] < 0.7        # dưới thresholds.source_match_min
    assert any("KHÔNG có trong URI" in x for x in out["reasons"])


def test_chua_doc_duoc_noi_dung_thi_diem_bi_chan(du_an):
    """`match_score` KHÔNG bao giờ đạt 1.0 khi chưa đọc được nội dung. Điểm cao giả là cách chắc
    chắn nhất để G-SRC-06 (`match_score < ngưỡng` → ASK) trở thành quy tắc chết."""
    r, ctx, root = du_an
    _them_source(root, "s_1", "https://st.com/stm32f411.pdf")
    out = r.invoke("search.verify_match", {"source_id": "s_1", "part": "STM32F411"}, ctx).result
    assert out["match_score"] <= 0.6
    assert any("extract.pdf_layout" in x for x in out["reasons"])


def test_doc_duoc_noi_dung_thi_diem_cao(du_an, tmp_path):
    r, ctx, root = du_an
    f = tmp_path / "ds.txt"
    f.write_text("STM32F411 datasheet Rev 5\nI2C1 base address...", encoding="utf-8")
    _them_source(root, "s_1", "https://st.com/stm32f411.pdf", cache=f)
    out = r.invoke("search.verify_match", {"source_id": "s_1", "part": "STM32F411"}, ctx).result
    assert out["match_score"] >= 0.9
    assert out.get("doc_version")


def test_nguon_la_bao_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("search.verify_match", {"source_id": "khong_co", "part": "X"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- SEARCH-08 search.missing


def test_gop_theo_nguon_co_the_dap_ung(du_an):
    """Bước 2: gộp theo NGUỒN, không liệt kê từng subject rời. Mười thanh ghi thiếu của cùng một
    chip là MỘT yêu cầu tải SVD, không phải mười — danh sách mười dòng khiến người đọc tưởng có
    mười việc phải làm."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO passport (id, kind, header, created_at) VALUES "
                  "('st.stm32f411@1.0.0','chip','{}','2026-01-01T00:00:00Z')")
        c.commit()
    out = r.invoke("search.missing", {"task_ref": "đọc cảm biến nhiệt độ qua i2c mỗi 1 s"},
                   ctx).result["requests"]
    assert len(out) == 1, out
    assert out[0]["subject"].startswith("chip:")
    assert out[0]["kind"] == "svd"
    assert "thiếu" in out[0]["why"]


def test_da_co_fact_thi_khong_yeu_cau_nua(du_an):
    """Không có phép trừ này thì `search.missing` báo thiếu mọi thứ mãi mãi, kể cả sau khi đã
    tải đủ — và một danh sách không bao giờ ngắn đi là danh sách không ai đọc."""
    r, ctx, root = du_an
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO passport (id, kind, header, created_at) VALUES "
                  "('st.x@1.0.0','chip','{}','2026-01-01T00:00:00Z')")
        c.commit()
    truoc = r.invoke("search.missing", {"task_ref": "cấu hình i2c"}, ctx).result["requests"]
    assert truoc
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier) "
                  "VALUES ('s_1','x','h','svd','gold')")
        for s in truoc[0]["subjects"]:
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method,"
                      " tier, confidence, status) VALUES (?,?,'offset','1','s_1','parser',"
                      "'gold',1.0,'normalized')", ("f_" + s[-12:].replace(":", "_"), s))
        c.commit()
    assert r.invoke("search.missing", {"task_ref": "cấu hình i2c"}, ctx).result["requests"] == []


def test_task_khong_can_gi_thi_tra_rong(du_an):
    r, ctx, _ = du_an
    assert r.invoke("search.missing", {"task_ref": "viết tài liệu"}, ctx).result["requests"] == []
